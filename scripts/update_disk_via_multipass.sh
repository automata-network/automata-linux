#!/bin/bash

set -euo pipefail

VM_NAME="cvm-vm"
DISK_FILE="$1"
DISK_FILENAME=$(basename "$DISK_FILE")
PROJECT_DIR=$(dirname "$DISK_FILE")
VM_PROJECT_DIR="cvm-tmp"
UPDATED_DISK="$PROJECT_DIR/$DISK_FILENAME"

echo "🔁 Using Multipass to update workload..."

# Step 1: Install multipass if missing
if ! command -v multipass &>/dev/null; then
  echo "🔧 Installing Multipass..."
  brew install --cask multipass
fi

# Step 2: Launch VM if it doesn't exist
if ! multipass info "$VM_NAME" &>/dev/null; then
  echo "🚀 Launching VM '$VM_NAME'..."
  multipass launch jammy --name "$VM_NAME" --disk 10G --memory 4G --cpus 2
else
  echo "⚠️ VM '$VM_NAME' already exists"
fi

# Step 3: Validate disk exists
if [[ ! -f "$DISK_FILE" ]]; then
  echo "❌ Disk file not found: $DISK_FILE"
  exit 1
fi

# Step 4: Create clean temp copy (excluding .git)
echo "🧹 Creating clean temp copy (excluding .git)..."
TMP_DIR=$(mktemp -d)
TMP_NAME=$(basename "$TMP_DIR")
rsync -a --exclude=".git" "$PROJECT_DIR/" "$TMP_DIR/$VM_PROJECT_DIR"

# Step 5: Checksum before update
echo "🔍 Calculating checksum before update..."
BEFORE_SUM=$(shasum -a 256 "$DISK_FILE" | awk '{print $1}')
echo "Before: $BEFORE_SUM"

# Step 6: Transfer to VM
echo "📤 Transferring project to VM..."
multipass transfer -r "$TMP_DIR" "$VM_NAME:"

VM_TMP_NAME=$(basename "$TMP_DIR")
VM_PROJECT_PATH="$VM_TMP_NAME/$VM_PROJECT_DIR"

# Step 7: Run update logic inside VM
echo "🛠️ Running update logic inside VM..."
multipass exec "$VM_NAME" -- bash -c "
  set -euo pipefail
  cd ~/$VM_PROJECT_PATH
  chmod +x ./scripts/copy_workload_to_existing_disk.sh
  chmod +x ./cvm-cli
  echo '▶️ Running: ./cvm-cli update-disk $DISK_FILENAME'
  ./cvm-cli update-disk $DISK_FILENAME
"

# Step 8: Retrieve updated disk
echo "📥 Retrieving updated disk..."
multipass transfer "$VM_NAME:$VM_PROJECT_PATH/$DISK_FILENAME" "$UPDATED_DISK"

# Step 9: Checksum after update
echo "🔍 Calculating checksum after update..."
AFTER_SUM=$(shasum -a 256 "$UPDATED_DISK" | awk '{print $1}')
echo "After:  $AFTER_SUM"

# Step 10: Compare
if [[ "$BEFORE_SUM" == "$AFTER_SUM" ]]; then
  echo "❌ No change — update failed!"
else
  echo "✅ Disk successfully updated!"
fi

# Step 11: Cleanup
rm -rf "$TMP_DIR"

echo "🧹 Cleaning up Multipass VM..."
multipass delete "$VM_NAME"
multipass purge
