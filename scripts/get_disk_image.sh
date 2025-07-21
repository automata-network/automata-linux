#!/bin/bash

CSP="$1"

# quit when any error occurs
set -Eeuo pipefail

# Ensure all arguments are provided
if [[ $# -lt 1 ]]; then
  echo "❌ Error: Arguments are missing! (get_disk_image.sh)"
  exit 1
fi

echo "⌛ Checking whether disk image exists..."

if [ "$CSP" = "aws" ]; then
  if [[ ! -f "aws_disk.vmdk" ]]; then
    echo "⌛ Downloading aws_disk.vmdk..."
    curl -O https://f004.backblazeb2.com/file/cvm-base-images/20250721/aws_disk.vmdk
  fi
elif [ "$CSP" = "azure" ]; then
  if [[ ! -f "azure_disk.vhd" ]]; then
    echo "⌛ Downloading azure_disk.vhd..."
    curl -O https://f004.backblazeb2.com/file/cvm-base-images/20250721/azure_disk.vhd
  fi
elif [ "$CSP" = "gcp" ]; then
  if [[ ! -f "gcp_disk.tar.gz" ]]; then
    echo "⌛ Downloading gcp_disk.tar.gz..."
    curl -O https://f004.backblazeb2.com/file/cvm-base-images/20250721/gcp_disk.tar.gz
  fi
else
    echo "❌ Error: Unsupported CSP '$CSP'. Supported CSPs are: aws, azure, gcp."
    exit 1
fi

set +e
