#!/bin/bash
VM_NAME=$1

# quit when any error occurs
set -Eeuo pipefail

# Ensure all arguments are provided
if [[ $# -lt 1 ]]; then
    echo "❌ Error: Arguments are missing! (cleanup_gcp_vm.sh)"
    exit 1
fi

BUCKET=$(<"_artifacts/gcp_${VM_NAME}_bucket")
ZONE=$(<"_artifacts/gcp_${VM_NAME}_region")
PROJECT_ID=$(<"_artifacts/gcp_${VM_NAME}_project")

# Delete the VM
gcloud compute instances delete $VM_NAME --zone="$ZONE" --project="$PROJECT_ID" --delete-disks=all --quiet
# Delete the ingress
gcloud compute firewall-rules delete "${VM_NAME}-ingress" --project="$PROJECT_ID" --quiet
# Delete the image
gcloud compute images delete "${VM_NAME}-image" --project="$PROJECT_ID" --quiet
# Delete the bucket
gsutil -m rm -r gs://$BUCKET

# Remove the artifacts related to this GCP VM
echo "ℹ️  Removing artifacts for GCP VM '$VM_NAME'..."
rm -f _artifacts/gcp_"${VM_NAME}"_*

echo "✅ Cleanup completed for GCP VM '$VM_NAME'."

set +e