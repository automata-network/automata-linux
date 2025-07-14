#!/bin/bash

IP_FILE="_artifacts/vm_ip"
GOLDEN_MEASUREMENT_FILE="_artifacts/golden-measurement.json"

# quit when any error occurs
set -Eeuo pipefail

if [[ ! -f "$IP_FILE" ]]; then
  echo "❌ Error: '$IP_FILE' does not exist. (get_golden_measurements.sh)"
  exit 1
fi

VM_IP=$(<"$IP_FILE")  # Load IP from file

echo "ℹ️  Waiting for $VM_IP to be ready..."
sleep 20 # Wait a while for the API to be ready
echo "ℹ️  Getting golden measurements from $VM_IP..."

MAX_RETRIES=5
RETRY_DELAY=30
URL="https://$VM_IP:8000/golden-measurement"

for attempt in $(seq 1 $MAX_RETRIES); do
  echo "Attempt $attempt: Fetching $URL..."

  set -e
  HTTP_CODE=$(curl --max-time 10 -k -s -o "$GOLDEN_MEASUREMENT_FILE" -w "%{http_code}" "$URL")
  set +e

  if [[ "$HTTP_CODE" == "200" ]]; then
    echo "✅ Golden measurements saved to $GOLDEN_MEASUREMENT_FILE"
    exit 0
  else
    echo "⚠️ Failed: HTTP $HTTP_CODE"
    if [[ "$attempt" -lt "$MAX_RETRIES" ]]; then
      echo "⌛ Retrying in $RETRY_DELAY seconds..."
      sleep $RETRY_DELAY
    else
      echo "❌ Error: Failed to fetch golden measurement after $MAX_RETRIES attempts."
      exit 1
    fi
  fi
done

set +e
