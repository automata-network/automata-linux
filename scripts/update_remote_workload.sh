#!/bin/bash

CSP=$1
VM_NAME=$2

# Ensure all arguments are provided
if [[ $# -lt 2 ]]; then
    echo "❌ Error: Arguments are missing! (update_remote_workload.sh)"
    exit 1
fi

IP_FILE="_artifacts/${CSP}_${VM_NAME}_ip"
API_TOKEN_FILE="_artifacts/${CSP}_${VM_NAME}_token"

# quit when any error occurs
set -Eeuo pipefail

if [[ ! -f "$IP_FILE" ]]; then
  echo "❌ Error: '$IP_FILE' does not exist. (update_remote_workload.sh)"
  exit 1
fi
if [[ ! -f "$API_TOKEN_FILE" ]]; then
  echo "❌ Error: '$API_TOKEN_FILE' does not exist. (update_remote_workload.sh)"
  exit 1
fi

VM_IP=$(<"$IP_FILE")  # Load IP from file
PASSWORD=$(<"$API_TOKEN_FILE")  # Load API token from file

if [[ ! -f output.zip ]]; then
  echo "Zipping up the workload/ folder..."
  zip -r output.zip workload/
fi
echo "ℹ️  Sending the zip file to the CVM's agent..."

response=$(curl -s -w "\n%{http_code}" -X POST -F "file=@output.zip" -H "Authorization: Bearer $PASSWORD" -k "https://$VM_IP:8000/update-workload")

# Split response and status code
body=$(echo "$response" | sed '$d')
code=$(echo "$response" | tail -n1)

if [[ "$code" -ne 200 ]]; then
    echo "❌ Error (status $code):"
    echo "$body"
    exit 1
else
    echo "✅ Done!"
    echo "$body"
    rm -f output.zip
fi

set +e
