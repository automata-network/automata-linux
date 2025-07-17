#!/bin/bash
VM_NAME=$1

# quit when any error occurs
set -Eeuo pipefail

# Ensure all arguments are provided
if [[ $# -lt 1 ]]; then
    echo "❌ Error: Arguments are missing! (cleanup_aws_vm.sh)"
    exit 1
fi

export AWS_PAGER=""
BUCKET=$(<"_artifacts/aws_${VM_NAME}_bucket")
AMI_ID=$(<"_artifacts/aws_${VM_NAME}_image")
REGION=$(<"_artifacts/aws_${VM_NAME}_region")
SECGRP_ID=$(<"_artifacts/aws_${VM_NAME}_secgrp")
INSTANCE_ID=$(<"_artifacts/aws_${VM_NAME}_vmid")

# First delete the EC2 instance
aws ec2 terminate-instances --instance-ids "$INSTANCE_ID" --region "$REGION"
aws ec2 wait instance-terminated --instance-ids "$INSTANCE_ID" --region "$REGION"
echo "✅ EC2 instance '$INSTANCE_ID' terminated."

# Delete the security group
aws ec2 delete-security-group --group-id "$SECGRP_ID" --region "$REGION"
echo "✅ Security group deleted."

# Get Snapshots associated with the AMI
SNAPSHOTS=$(aws ec2 describe-images --image-ids "$AMI_ID" --region "$REGION" \
  --query 'Images[0].BlockDeviceMappings[*].Ebs.SnapshotId' \
  --output text)
# Delete the AMI
aws ec2 deregister-image --image-id "$AMI_ID" --region "$REGION"
echo "✅ AMI '$AMI_ID' deregistered."
# Delete the snapshots
for SNAP_ID in $SNAPSHOTS; do
  echo "Deleting snapshot $SNAP_ID"
  aws ec2 delete-snapshot --snapshot-id "$SNAP_ID" --region "$REGION"
done

# Delete S3 bucket
aws s3 rb s3://$BUCKET --force

# Remove the artifacts related to this AWS VM
echo "ℹ️  Removing artifacts for AWS VM '$VM_NAME'..."
rm -f _artifacts/aws_"${VM_NAME}"_*

echo "✅ Cleanup completed for AWS VM '$VM_NAME'."

set +e