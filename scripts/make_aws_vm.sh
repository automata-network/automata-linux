VM_NAME=$1
REGION=$2
VM_TYPE=$3
BUCKET=$4
ADDITIONAL_PORTS=$5
DISK_FILE=aws_disk.vmdk
UPLOADED_DISK_FILE="${VM_NAME}.vmdk"
IMAGE_NAME="${VM_NAME}-image"
export AWS_PAGER=""

# Ensure all arguments are provided
if [[ $# -lt 5 ]]; then
    echo "❌ Error: Arguments are missing! (make_aws_vm.sh)"
    exit 1
fi

set -x
set -e

# Create S3 bucket if it does not exist
if ! aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
  echo "Bucket '$BUCKET' does not exist. Creating..."
  if aws s3api create-bucket \
    --bucket "$BUCKET" \
    --region "$REGION" \
    --create-bucket-configuration LocationConstraint="$REGION"; then
    echo "Bucket created successfully in $REGION"
  else
    echo "❌ Error: Failed to create bucket in $REGION"
    exit 1
  fi
fi

# Import disk into S3
aws s3 cp $DISK_FILE s3://$BUCKET/vms/$UPLOADED_DISK_FILE

# Create the container.json file
cat <<EOF > container.json
{
  "Description": "Minimal CVM Image",
  "Format": "vmdk",
  "UserBucket": {
    "S3Bucket": "$BUCKET",
    "S3Key":   "vms/$UPLOADED_DISK_FILE"
  }
}
EOF

# Import the vmdk disk in S3 into EC2 as a snapshot
IMPORT_JSON=$(aws ec2 import-snapshot \
    --region $REGION \
    --description "Minimal CVM Image" \
    --disk-container file://container.json)

TASK_ID=$(echo "$IMPORT_JSON" | jq -r '.ImportTaskId')
echo "✔ Import task id = $TASK_ID"

# Check State transitions: active → completed
SNAPSHOT_ID=""
while true; do
  STATUS_JSON=$(aws ec2 describe-import-snapshot-tasks       \
                    --region "$REGION"                    \
                    --import-task-ids "$TASK_ID")

  STATUS=$(echo "$STATUS_JSON"   | jq -r '.ImportSnapshotTasks[0].SnapshotTaskDetail.Status')
  PROGRESS=$(echo "$STATUS_JSON" | jq -r '.ImportSnapshotTasks[0].SnapshotTaskDetail.Progress')
  SNAPSHOT_ID=$(echo "$STATUS_JSON" | jq -r '.ImportSnapshotTasks[0].SnapshotTaskDetail.SnapshotId')

  printf '%s  %s (%s%%)\n' "$(date '+%T')" "$STATUS" "${PROGRESS:-0}"

  case "$STATUS" in
    completed)
      echo "🎉  Import finished.";
      break
      ;;
    deleted|deleting|deleted_failed)
      echo "❌  Task ended in failure.";
      echo $STATUS_JSON
      exit 1
      ;;
  esac
  sleep 60
done

rm container.json

# Create UEFI Data block to use with the image.
# first check whether the blob exists, otherwise create it.
UEFI_BLOB="secure_boot/aws-uefi-blob.bin"
if [ -f "$UEFI_BLOB" ]; then
  echo "$UEFI_BLOB exists. Continuing..."
else
  echo "$UEFI_BLOB does not exist! Panicking and quitting!"
  exit 1
fi

# First delete any old AMI with the same name
OLD_AMIS=$(aws ec2 describe-images \
  --region "$REGION" \
  --owners self \
  --filters "Name=name,Values=$IMAGE_NAME" \
  --query 'Images[*].ImageId' \
  --output text)

if [[ -n "$OLD_AMIS" ]]; then
  for AMI in $OLD_AMIS; do
    # collect snapshots the old AMI uses
    SNAP_IDS=$(aws ec2 describe-images \
      --region "$REGION" \
      --image-ids "$AMI" \
      --query 'Images[0].BlockDeviceMappings[*].Ebs.SnapshotId' \
      --output text)
    aws ec2 deregister-image --region "$REGION" --image-id "$AMI"
    echo "✔ Deleted old AMI $AMI"
    for SID in $SNAP_IDS; do
      echo "🗑️ Deleting snapshot $SID"
      aws ec2 delete-snapshot --region "$REGION" --snapshot-id "$SID" || true
    done
  done
fi

# Register the snapshot as AMI
IMAGE_ID=$(aws ec2 register-image \
  --name $IMAGE_NAME \
  --region $REGION \
  --root-device-name /dev/xvda \
  --block-device-mappings DeviceName=/dev/xvda,Ebs=\{SnapshotId=$SNAPSHOT_ID,DeleteOnTermination=true\} \
  --virtualization-type hvm \
  --architecture x86_64 \
  --tpm-support v2.0 \
  --ena-support \
  --boot-mode uefi \
  --uefi-data $(cat $UEFI_BLOB) | jq -r '.ImageId')

echo "✔ Image ID = $IMAGE_ID"

# Check if the security group already exists
EXISTING_GROUP_ID=$(aws ec2 describe-security-groups \
  --region "$REGION" \
  --filters Name=group-name,Values="${VM_NAME}-secgrp" \
  --query "SecurityGroups[0].GroupId" \
  --output text 2>/dev/null)

# If it exists, delete it
if [[ "$EXISTING_GROUP_ID" != "None" ]]; then
  echo "Security group $SECGRP_NAME exists (GroupId: $EXISTING_GROUP_ID), deleting..."
  aws ec2 delete-security-group \
    --region "$REGION" \
    --group-id "$EXISTING_GROUP_ID"
  echo "Deleted existing security group."
fi

# Create the security group
SECGRP_ID=$(aws ec2 create-security-group \
  --region "$REGION" \
  --group-name "${VM_NAME}-secgrp" \
  --description "Security group for SEV-SNP CVM" \
  --query "GroupId" --output text)

# Add inbound rules to the security group
ALLOW_PORTS="8000"
if [ -n "$ADDITIONAL_PORTS" ]; then
  ALLOW_PORTS="$ALLOW_PORTS,$ADDITIONAL_PORTS"
fi

IFS=',' read -ra PORT_ARRAY <<< "$ALLOW_PORTS"
for P in "${PORT_ARRAY[@]}"; do
  echo "⬅️  Adding ingress rule for TCP $P"
  aws ec2 authorize-security-group-ingress \
       --region "$REGION" \
       --group-id "$SECGRP_ID" \
       --protocol tcp \
       --port "$P" \
       --cidr 0.0.0.0/0 \
       >/dev/null 2>&1 || true # skip “rule exists” errors
done

# Create the instance
INSTANCE_ID=$(aws ec2 run-instances \
  --region "$REGION" \
  --image-id "$IMAGE_ID" \
  --instance-type "$VM_TYPE" \
  --security-group-ids "$SECGRP_ID" \
  --cpu-options AmdSevSnp=enabled \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value='"$VM_NAME"'}]' \
  --query 'Instances[0].InstanceId' \
  --output text)

aws ec2 wait instance-running --region "$REGION" --instance-ids "$INSTANCE_ID"

PUBLIC_IP=$(aws ec2 describe-instances \
  --region "$REGION" \
  --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)

echo "VM Public IP: $PUBLIC_IP"

# Save artifacts for later use
mkdir -p _artifacts
echo "$PUBLIC_IP" > _artifacts/aws_${VM_NAME}_ip
echo "$BUCKET" > _artifacts/aws_${VM_NAME}_bucket
echo "$REGION" > _artifacts/aws_${VM_NAME}_region
echo "$IMAGE_ID" > _artifacts/aws_${VM_NAME}_image
echo "$SECGRP_ID" > _artifacts/aws_${VM_NAME}_secgrp
echo "$INSTANCE_ID" > _artifacts/aws_${VM_NAME}_vmid

set +x
set +e
