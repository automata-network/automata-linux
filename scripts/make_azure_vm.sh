VM_NAME="$1"
RG="$2"
VM_TYPE="$3"
ADDITIONAL_PORTS="$4"
STORAGE_ACC="$5"
GALLERY_NAME="$6"
REGION=$(az group show --name "$RG" --query location -o tsv)
VHD=azure_disk.vhd 
IMAGE_DEF="${VM_NAME}-def"
SKU_NAME="${VM_NAME}-sku"
GALLERY_IMAGE_VERSION="1.0.0"
PUBLISHER="automata"
STORAGE_CONTAINER="cvm-image-storage"
blob_url="https://${STORAGE_ACC}.blob.core.windows.net/$STORAGE_CONTAINER/$VHD"

# Ensure all arguments are provided
if [[ $# -lt 6 ]]; then
    echo "❌ Error: Arguments are missing!"
    exit 1
fi

set -x
set -e

# -- Cleanup existing SIG resources --------------------------------------------------------------
echo "ℹ️  Checking for existing Azure Compute Gallery resources..."

# Delete existing image version if present and wait for full deletion
if az sig image-version show --resource-group "$RG" --gallery-name "$GALLERY_NAME" \
   --gallery-image-definition "$IMAGE_DEF" --gallery-image-version "$GALLERY_IMAGE_VERSION" &>/dev/null; then
    echo "⚠️  Existing image version $GALLERY_IMAGE_VERSION found. Deleting..."
    az sig image-version delete --resource-group "$RG" --gallery-name "$GALLERY_NAME" \
        --gallery-image-definition "$IMAGE_DEF" --gallery-image-version "$GALLERY_IMAGE_VERSION"

    echo "⏳ Waiting for image version to be fully deleted..."
    az sig image-version wait --resource-group "$RG" --gallery-name "$GALLERY_NAME" \
        --gallery-image-definition "$IMAGE_DEF" --gallery-image-version "$GALLERY_IMAGE_VERSION" --deleted
    echo "✅ Image version fully deleted."
fi

# Delete existing image definition if present (must be done after versions are removed)
if az sig image-definition show --resource-group "$RG" --gallery-name "$GALLERY_NAME" \
   --gallery-image-definition "$IMAGE_DEF" &>/dev/null; then
    echo "⚠️  Existing image definition $IMAGE_DEF found. Deleting..."
    az sig image-definition delete --resource-group "$RG" --gallery-name "$GALLERY_NAME" \
        --gallery-image-definition "$IMAGE_DEF"
    az sig image-definition wait --resource-group "$RG" --gallery-name "$GALLERY_NAME" \
        --gallery-image-definition "$IMAGE_DEF" --deleted
    echo "✅ Image definition fully deleted."
fi

# -------------------------------------------------------------------------------------------------

# create a container in the storage account
az storage container create --name "$STORAGE_CONTAINER" --account-name "$STORAGE_ACC" --resource-group "$RG"

#get account key so we can upload vhd to container
ACCOUNT_KEY=$(az storage account keys list \
  --resource-group "$RG" \
  --account-name "$STORAGE_ACC" \
  --query '[0].value' -o tsv)

# upload custom image to the container as blob
az storage blob upload \
  --account-name "$STORAGE_ACC" \
  --account-key "$ACCOUNT_KEY" \
  --container-name "$STORAGE_CONTAINER" \
  --name "$VHD" \
  --file "$VHD" \
  --type page \
  --overwrite

# create a cvm definition
az sig image-definition create --resource-group "$RG" --location "$REGION" --gallery-name "$GALLERY_NAME" \
  --gallery-image-definition "$IMAGE_DEF" --publisher "$PUBLISHER" --offer ubuntu --sku "$SKU_NAME" \
  --os-type Linux --os-state specialized --hyper-v-generation V2 --features SecurityType=TrustedLaunchAndConfidentialVmSupported

# get storage acc id
storageAccountId=$(az storage account show --name "$STORAGE_ACC" --resource-group "$RG" | jq -r .id)

# v2: create sig image version (with support for secure boot)
PK_B64=$(openssl base64 -in secure_boot/PK.crt -A)
KEK_B64=$(openssl base64 -in secure_boot/KEK.crt -A)
DB_B64=$(openssl base64 -in secure_boot/db.crt -A)

IMG_VER_BODY=$(jq -n \
  --arg region "$REGION" \
  --arg saId "$storageAccountId" \
  --arg uri "$blob_url" \
  --arg pk "$PK_B64" \
  --arg kek "$KEK_B64" \
  --arg db "$DB_B64" '
{
  location: $region,
  properties: {
    publishingProfile: {
      targetRegions: [{ name: $region, regionalReplicaCount: 1 }]
    },
    storageProfile: {
      osDiskImage: {
        hostCaching: "ReadOnly",
        source: {
          storageAccountId: $saId,
          uri: $uri
        }
      }
    },
    securityProfile: {
      uefiSettings: {
        signatureTemplateNames: ["NoSignatureTemplate"],
        additionalSignatures: {
          pk: { type: "x509", value: [$pk] },
          kek: [{ type: "x509", value: [$kek] }],
          db: [{ type: "x509", value: [$db] }]
        }
      }
    }
  }
}')

# Get the default subscription
SUB=$(az account show --query id -o tsv)

# create sig image version
az rest --method PUT \
  --url "/subscriptions/$SUB/resourceGroups/$RG/providers/Microsoft.Compute/galleries/$GALLERY_NAME/images/$IMAGE_DEF/versions/$GALLERY_IMAGE_VERSION?api-version=2024-03-03" \
  --body "$IMG_VER_BODY"

echo "⏳ Image replication + gallery image version in progress... this might take a while (8+ mins). Time to grab a coffee and chill ☕🙂"

while true; do
  state=$(az sig image-version show \
    --resource-group "$RG" \
    --gallery-name "$GALLERY_NAME" \
    --gallery-image-definition "$IMAGE_DEF" \
    --gallery-image-version "$GALLERY_IMAGE_VERSION" \
    --query "provisioningState" -o tsv)

  if [[ "$state" == "Succeeded" ]]; then
    echo "✅ Image version provisioning complete."
    break
  fi

  echo "⏳ Still provisioning... (state: $state)"
  sleep 30
done

# get id of sig image version
galleryImageId=$(az sig image-version show --gallery-image-definition "$IMAGE_DEF" \
  --gallery-image-version "$GALLERY_IMAGE_VERSION" --gallery-name "$GALLERY_NAME" \
  --resource-group "$RG" | jq -r .id)

# Create NSG with base rules
echo "ℹ️  Creating network security group..."
az network nsg create --name "$VM_NAME" --resource-group "$RG" --location "$REGION"

# Add attestation_agent ports
az network nsg rule create --nsg-name "$VM_NAME" --resource-group "$RG" \
    --name "attestation_agent" --priority 100 \
    --destination-port-ranges 8000 --access Allow --protocol Tcp

# Add additional port rules if specified
if [[ -n "${ADDITIONAL_PORTS}" ]]; then
    IFS=',' read -ra PORTS <<< "${ADDITIONAL_PORTS}"
    priority=200
    for port in "${PORTS[@]}"; do
        az network nsg rule create --nsg-name "${VM_NAME}" --resource-group "${RG}" \
            --name "Workload_${port}" --priority ${priority} \
            --destination-port-ranges "$port" --access Allow --protocol Tcp
        ((priority+=1))
    done
fi

az vm create \
  --resource-group "$RG" \
  --name "$VM_NAME" \
  --size "$VM_TYPE" \
  --enable-vtpm true \
  --enable-secure-boot true \
  --image "$galleryImageId" \
  --public-ip-sku Standard \
  --nsg "$VM_NAME" \
  --security-type ConfidentialVM \
  --os-disk-security-encryption-type VMGuestStateOnly \
  --specialized \
  --admin-username dummyuser \
  --admin-password DummyPassword123

set +x
set +e
