#!/bin/bash

DISK_FILE=$1

# quit when any error occurs
set -Eeuo pipefail

# Ensure all arguments are provided
if [[ $# -lt 1 ]]; then
  echo "❌ Error: Arguments are missing! (update_disk.sh)"
  exit 1
fi

has_changes=false

# Check for unstaged changes
if ! git diff --quiet -- workload/; then
  has_changes=true
fi

# Check for untracked files
if [[ -n $(git ls-files --others --exclude-standard workload/) ]]; then
  has_changes=true
fi

if ! $has_changes; then
  echo "ℹ️  No changes detected in workload/, skipping disk update."
  exit 0
fi


os_type="$(uname)"
if [[ "$os_type" == "Linux" ]]; then
    echo "Reloading workload onto an existing disk..."
    ./scripts/update_disk_locally.sh $DISK_FILE
elif [[ "$os_type" == "Darwin" ]]; then
    echo "🔁 Using Multipass to update workload..."
    bash "./scripts/update_disk_via_multipass.sh" "$DISK_FILE"
else
    echo "Unsupported OS: $os_type"
    exit 1
fi

set +e
