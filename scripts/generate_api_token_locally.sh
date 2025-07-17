#!/bin/bash

DISK_FILE=$1
CSP=$2
VM_NAME=$3

# quit when any error occurs
set -Eeuo pipefail

# Ensure all arguments are provided
if [[ $# -lt 3 ]]; then
    echo "❌ Error: Arguments are missing! (update_disk_locally.sh)"
    exit 1
fi

# --- CLEANUP ---------------------------------------------------------------
cleanup() {
  for mp in /tmp/data; do
    mountpoint -q "$mp" && sudo umount "$mp" || true
  done
  [[ -n "${LOOP_DEV:-}" && -e "$LOOP_DEV" ]] && sudo losetup -d "$LOOP_DEV" || true
}
trap cleanup EXIT
trap 'echo "❌  Failure on line $LINENO"; exit 1' ERR
trap 'exit 1' INT HUP TERM
# --------------------------------------------------------------------------

populate() {
    local DISK="$1"
    # Mount the disk onto a loop device
    sudo losetup -fP $DISK
    LOOP_DEV=$(losetup -j $DISK | awk -F: '{print $1}')
    lsblk $LOOP_DEV

    # Check that disk has the right partitioning before reloading workload
    PART_COUNT=$(lsblk -l $LOOP_DEV | grep -E "^\s*$(basename "$LOOP_DEV")p[0-9]+" | wc -l)
    if [ "$PART_COUNT" -eq 3 ]; then
        # Mount partition 3
        mkdir -p /tmp/data
        sudo mount ${LOOP_DEV}p3 /tmp/data

        # Generate API token
        API_TOKEN_FILE="_artifacts/${CSP}_${VM_NAME}_token"
        echo "ℹ️  Generating API token..."
        mkdir -p $(dirname $API_TOKEN_FILE)
        openssl rand -hex 16 | tr -d '\n' > $API_TOKEN_FILE

        tr -d '\n' < $API_TOKEN_FILE | sha256sum | cut -d ' ' -f1 > _artifacts/token_hash
        sudo cp _artifacts/token_hash /tmp/data/token_hash
        sudo chown 1000:1000 /tmp/data/token_hash
        sync
        #Remove temporary file.
        rm -f _artifacts/token_hash
        # Unmount partition
        sudo umount ${LOOP_DEV}p3

        echo "✅ Done! API token generated!"
    else
        echo "❌ Disk does not have the right partitioning scheme!"
    fi
}

if [ -f $DISK_FILE ]; then
    if [[ "$DISK_FILE" == *.vmdk ]]; then
        # Check if qemu-img is installed, otherwise install it.
        if ! command -v qemu-img &> /dev/null; then
            echo "qemu-img not found. Installing..."
            # Detect package manager and install
            if [ -x "$(command -v apt)" ]; then
                sudo apt update && sudo apt install -y qemu-utils
            elif [ -x "$(command -v yum)" ]; then
                sudo yum install -y qemu-img
            elif [ -x "$(command -v dnf)" ]; then
                sudo dnf install -y qemu-img
            elif [ -x "$(command -v pacman)" ]; then
                sudo pacman -Sy --noconfirm qemu
            else
                echo "Unsupported package manager. Please install qemu-img manually."
                exit 1
            fi
        fi
        qemu-img convert -p -f vmdk -O raw $DISK_FILE tmp.raw
        populate tmp.raw
        qemu-img convert -p -f raw tmp.raw -O vmdk -o subformat=streamOptimized,compat6 aws_disk.vmdk
        rm tmp.raw
    elif [[ "$DISK_FILE" == *.tar.gz ]]; then
        # unzip the disk and zip it back again later
        tar -xzvf "$DISK_FILE"
        populate disk.raw
        tar -czvf "$DISK_FILE" disk.raw
        rm disk.raw
    else
        # raw disk and VHD.
        populate $DISK_FILE
    fi
else
    echo "❌ Error: $DISK_FILE does not exist!"
fi

set +e
