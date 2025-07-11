IP=$1
PASSWORD=$2

# quit when any error occurs
set -Eeuo pipefail

# Ensure all arguments are provided
if [[ $# -lt 2 ]]; then
    echo "❌ Error: Arguments are missing! [update-remote-workload.sh]"
    exit 1
fi

if [[ ! -f output.zip ]]; then
  echo "Zipping up the workload/ folder..."
  zip -r output.zip workload/
fi
echo "Sending the zip file to the CVM's agent..."

response=$(curl -s -w "\n%{http_code}" -X POST -F "file=@output.zip" -H "Authorization: Bearer $PASSWORD" -k "https://$IP:8000/update-workload")

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
