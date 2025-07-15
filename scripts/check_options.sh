#!/bin/bash

CSP="$1"
VM_TYPE="$2"
REGION="$3"

# quit when any error occurs
set -Eeuo pipefail

# Ensure all arguments are provided
if [[ $# -lt 3 ]]; then
  echo "❌ Error: Arguments are missing! (check_options.sh)"
  exit 1
fi

GCP_SNP_REGIONS=(
  "asia-southeast1-a" "asia-southeast1-b" "asia-southeast1-c"
  "europe-west3-a" "europe-west3-b" "europe-west3-c"
  "europe-west4-a" "europe-west4-b" "europe-west4-c"
  "us-central1-a" "us-central1-b" "us-central1-c"
)

GCP_TDX_REGIONS=(
  "asia-southeast1-a" "asia-southeast1-b" "asia-southeast1-c"
  "europe-west4-a" "europe-west4-b" "europe-west4-c"
  "us-central1-a" "us-central1-b" "us-central1-c"
)

AWS_SNP_REGIONS=("us-east-2" "eu-west-1")

AZURE_TDX_V5_REGIONS=(
  "East US 2" "Central US" "West Europe" "North Europe"
)

AZURE_TDX_V6_REGIONS=(
  "West Europe" "East US" "West US" "West US 3"
)

AZURE_SNP_REGIONS=(
  "East US" "West US" "Switzerland North" "Italy North"
  "North Europe" "West Europe" "Germany West Central"
  "UAE North" "Japan East" "Central India" "East Asia"
  "Southeast Asia"
)

contains() {
  local value="$1"; shift
  for item; do
    [[ "$item" == "$value" ]] && return 0
  done
  return 1
}

echo "⌛ Double-checking the VM type and region for CSP..."

if [ "$CSP" = "aws" ]; then
  if ! [[ $VM_TYPE =~ ^(m6a\.(large|xlarge|2xlarge|4xlarge|8xlarge)|c6a\.(large|xlarge|2xlarge|4xlarge|8xlarge|12xlarge|16xlarge)|r6a\.(large|xlarge|2xlarge|4xlarge))$ ]]; then
    echo "❌ Error: The selected VM type '$VM_TYPE' is not supported for AWS."
    echo "Please choose a VM type that supports SEV-SNP."
    echo "Supported types for SEV-SNP: m6a, c6a, r6a"
    echo "Reference: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/sev-snp.html#snp-requirements"
    exit 1
  else
    if ! contains "$REGION" "${AWS_SNP_REGIONS[@]}"; then
      echo "❌ Error: The selected region '$REGION' does not support SEV-SNP VMs."
      echo "Please choose a region that supports SEV-SNP VMs: ${AWS_SNP_REGIONS[*]}"
      exit 1
    fi
  fi

elif [ "$CSP" = "gcp" ]; then
  if [[ $VM_TYPE == *"n2d-standard-"* ]]; then
    if ! contains "$REGION" "${GCP_SNP_REGIONS[@]}"; then
      echo "❌ Error: The selected region '$REGION' does not support SEV-SNP VMs."
      echo "Please choose a region that supports SEV-SNP VMs: ${GCP_SNP_REGIONS[*]}"
      exit 1
    fi
  elif [[ $VM_TYPE == *"c3-standard-"* ]]; then
    if ! contains "$REGION" "${GCP_TDX_REGIONS[@]}"; then
      echo "❌ Error: The selected region '$REGION' does not support TDX VMs."
      echo "Please choose a region that supports TDX VMs: ${GCP_TDX_REGIONS[*]}"
      exit 1
    fi
  else
    echo "Unsupported VM type: $VM_TYPE"
    echo "Please use a supported VM type 'n2d-standard-*' or 'c3-standard-*'."
    echo "Reference1: https://cloud.google.com/compute/docs/general-purpose-machines#n2d_machine_types"
    echo "Reference2: https://cloud.google.com/compute/docs/general-purpose-machines#c3_machine_types"
    exit 1
  fi

elif [ "$CSP" = "azure" ]; then
  if [[ $VM_TYPE =~ ^Standard_DC(2|4|8|16|32|64|96|128)es_v5$ ]]; then
    if ! contains "$REGION" "${AZURE_TDX_V5_REGIONS[@]}"; then
      echo "❌ Error: The selected region '$REGION' does not support TDX DCesv5 VMs."
      echo "Please choose a region that supports TDX DCesv5 VMs: ${AZURE_TDX_V5_REGIONS[*]}"
      exit 1
    fi
  elif [[ $VM_TYPE =~ ^Standard_DC(2|4|8|16|32|64|96|128)es_v6$ ]]; then
    if ! contains "$REGION" "${AZURE_TDX_V6_REGIONS[@]}"; then
      echo "❌ Error: The selected region '$REGION' does not support TDX DCesv6 VMs."
      echo "Please choose a region that supports TDX DCesv6 VMs: ${AZURE_TDX_V6_REGIONS[*]}"
      exit 1
    fi
  elif [[ $VM_TYPE =~ ^Standard_DC(2|4|8|16|32|64|96|128)as_v(5|6)$ ]]; then
    if ! contains "$REGION" "${AZURE_SNP_REGIONS[@]}"; then
      echo "❌ Error: The selected region '$REGION' does not support SEV-SNP DCasv5/v6 VMs."
      echo "Please choose a region that supports SEV-SNP DCasv5/v6 VMs: ${AZURE_SNP_REGIONS[*]}"
      exit 1
    fi
  else
    echo "❌ Error: The selected VM type '$VM_TYPE' is not supported for Azure."
    echo "Please choose a VM type that supports SEV-SNP or TDX."
    echo "Supported types for SEV-SNP: Standard_DC*as_v5, Standard_DC*as_v6"
    echo "Supported types for TDX: Standard_DC*es_v5, Standard_DC*es_v6"
    exit 1
  fi
else
  echo "Invalid CSP: $CSP"
  exit 1
fi

set +e
