#!/bin/bash

DISK_FILE=$1
CSP=$2
VM_NAME=$3

# quit when any error occurs
set -Eeuo pipefail

# Ensure all arguments are provided
if [[ $# -lt 3 ]]; then
    echo "❌ Error: Arguments are missing! (generate_api_token.sh)"
    exit 1
fi

os_type="$(uname)"
if [[ "$os_type" == "Linux" ]]; then
    echo "⌛ Adding API token to disk..."
    ./scripts/generate_api_token_locally.sh "$DISK_FILE" "$CSP" "$VM_NAME"
elif [[ "$os_type" == "Darwin" ]]; then
    echo "🔁 Using Multipass to add API token to disk..."
    bash "./scripts/generate_api_token_multipass.sh" "$DISK_FILE" "$CSP" "$VM_NAME"
else
    echo "Unsupported OS: $os_type"
    exit 1
fi

set +e
