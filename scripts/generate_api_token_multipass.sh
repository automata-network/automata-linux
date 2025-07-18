#!/bin/bash
DISK_FILE="$1"
CSP="$2"
CSP_VM_NAME="$3"

# Ensure all arguments are provided
if [[ $# -lt 3 ]]; then
  echo "❌ Error: Arguments are missing! (generate_api_token_multipass.sh)"
  exit 1
fi

set -euo pipefail

VM_NAME="cvm-vm"
DISK_FILENAME=$(basename "$DISK_FILE")
PROJECT_DIR=$(dirname "$DISK_FILE")
VM_PROJECT_DIR="cvm-tmp"
UPDATED_DISK="$PROJECT_DIR/$DISK_FILENAME"

# Step 1: Install multipass if missing
if ! command -v multipass &>/dev/null; then
  echo "🔧 Installing Multipass..."
  brew install --cask multipass
fi

# Step 2: Launch VM if it doesn't exist or is stopped
STATUS=$(multipass info "$VM_NAME" 2>/dev/null | grep '^State:' | awk '{print $2}')

if [[ "$STATUS" == "Stopped" ]]; then
  echo "🔌 Instance '$VM_NAME' exists but is stopped. Starting it..."
  multipass start "$VM_NAME"
elif [[ -z "$STATUS" ]]; then
  echo "🚀 Launching VM '$VM_NAME'..."
  multipass launch jammy --name "$VM_NAME" --disk 10G --memory 4G --cpus 2
fi

# Step 3: Validate disk exists
if [[ ! -f "$DISK_FILE" ]]; then
  echo "❌ Disk file not found: $DISK_FILE"
  exit 1
fi

# Step 4: Checksum before update
echo "🔍 Calculating checksum before update..."
BEFORE_SUM=$(shasum -a 256 "$DISK_FILE" | awk '{print $1}')
echo "Before: $BEFORE_SUM"

# Step 5: Transfer to VM
echo "📤 Transferring project to VM..."
VM_PROJECT_PATH="/tmp/$VM_PROJECT_DIR"
multipass exec "$VM_NAME" -- bash -c "
  mkdir -p $VM_PROJECT_PATH
"
multipass transfer -r "scripts/" "$DISK_FILE" "$VM_NAME:$VM_PROJECT_PATH"

# Step 6: Add API token to VM.
echo "🛠️ Running update logic inside VM..."
multipass exec "$VM_NAME" -- bash -c "
  set -euo pipefail
  cd $VM_PROJECT_PATH
  chmod +x ./scripts/generate_api_token_locally.sh
  echo '▶️ Running: ./scripts/generate_api_token_locally.sh $DISK_FILENAME $CSP $CSP_VM_NAME'
  ./scripts/generate_api_token_locally.sh $DISK_FILENAME $CSP $CSP_VM_NAME
"

# Step 7: Retrieve updated disk
echo "📥 Retrieving updated disk..."
multipass transfer "$VM_NAME:$VM_PROJECT_PATH/$DISK_FILENAME" "$UPDATED_DISK"

# Step 8: Retrieve api_token
echo "📥 Retrieving API token..."
API_TOKEN_FILE="_artifacts/${CSP}_${CSP_VM_NAME}_token"
mkdir -p "$(dirname "$API_TOKEN_FILE")"
multipass transfer "$VM_NAME:$VM_PROJECT_PATH/$API_TOKEN_FILE" "$API_TOKEN_FILE"

# Step 9: Checksum after update
echo "🔍 Calculating checksum after update..."
AFTER_SUM=$(shasum -a 256 "$UPDATED_DISK" | awk '{print $1}')
echo "After:  $AFTER_SUM"

# Step 10: Compare
if [[ "$BEFORE_SUM" == "$AFTER_SUM" ]]; then
  echo "❌ No change — Failed to add API token!"
else
  echo "✅ API token successfully added to disk!"
fi

# Step 11: Cleanup
echo "🧹 Stopping Multipass VM..."
multipass stop "$VM_NAME"
# multipass delete "$VM_NAME"
# multipass purge
