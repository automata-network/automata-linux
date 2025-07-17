#!/bin/bash
VM_NAME=$1

# quit when any error occurs
set -Eeuo pipefail

# Ensure all arguments are provided
if [[ $# -lt 1 ]]; then
    echo "❌ Error: Arguments are missing! (cleanup_azure_vm.sh)"
    exit 1
fi

RG_FILE="_artifacts/azure_${VM_NAME}_resource_group"
RG=$(<"$RG_FILE")  # Load RG from file

# Delete everything in the resource group
echo "ℹ️  Deleting resource group '$RG'..."
az group delete --name "$RG" --yes

# Remove the artifacts related to this Azure VM
echo "ℹ️  Removing artifacts for Azure VM '$VM_NAME'..."
rm -f _artifacts/azure_"${VM_NAME}"_*

echo "✅ Cleanup completed for Azure VM '$VM_NAME'."

set +e