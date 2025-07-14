#!/bin/bash

CSP="$1"
export AWS_PAGER=""

# quit when any error occurs
set -Eeuo pipefail

# Ensure all arguments are provided
if [[ $# -lt 1 ]]; then
  echo "❌ Error: Arguments are missing! (check_deps.sh)"
  exit 1
fi

check_python_version() {
    if ! command -v python3 >/dev/null 2>&1; then
        echo "❌ python3 is not installed. Please install a version between 3.9 and 3.13."
        exit 1
    fi

    PYVER=$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:2])))')
    PYMAJOR=$(echo "$PYVER" | cut -d. -f1)
    PYMINOR=$(echo "$PYVER" | cut -d. -f2)

    if [ "$PYMAJOR" -eq 3 ] && [ "$PYMINOR" -ge 9 ] && [ "$PYMINOR" -le 13 ]; then
        echo "✅ Python version $PYVER is between 3.9 and 3.13."
        return 0
    else
        echo "❌ Python version $PYVER is not between 3.9 and 3.13. Please install a compatible version."
        exit 1
    fi
}

install_gcloud() {
    echo "🔽 Downloading and installing gcloud CLI..."

    OS="$(uname -s)"
    ARCH="$(uname -m)"
    if [ "$OS" = "Darwin" ]; then
        if [ "$ARCH" = "x86_64" ]; then
            URL="https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-darwin-x86_64.tar.gz"
        elif [ "$ARCH" = "arm64" ] || [ "$ARCH" = "aarch64" ]; then
            URL="https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-darwin-arm.tar.gz"
        else
            echo "❌ Unsupported architecture: $ARCH"
            exit 1
        fi
    elif [ "$OS" = "Linux" ]; then
        # First check if python is installed for Linux
        check_python_version
        # Now get the URL based on architecture
        if [ "$ARCH" = "x86_64" ]; then
            URL="https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-x86_64.tar.gz"
        elif [ "$ARCH" = "arm64" ] || [ "$ARCH" = "aarch64" ]; then
            URL="https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-arm.tar.gz"
        else
            echo "❌ Unsupported architecture: $ARCH"
            exit 1
        fi
    else
        echo "❌ Unsupported OS: $OS"
        exit 1
    fi

    # Change to home directory to install gcloud
    pushd $HOME
    echo "📦 Downloading from $URL"
    curl -sSL "$URL" -o gcloud.tar.gz

    tar -xzf gcloud.tar.gz
    ./google-cloud-sdk/install.sh --usage-reporting false --screen-reader false --quiet

    rm gcloud.tar.gz
    for tool in bq gsutil gcloud; do
        sudo ln -sf "$HOME/google-cloud-sdk/bin/$tool" /usr/local/bin/$tool
    done
    echo "✅ gcloud installed successfully."
    popd
}

# Function to trigger gcloud login
gcloud_init_login() {
    echo "🔐 Logging in to gcloud..."
    gcloud init --console-only --no-launch-browser
}

if [ "$CSP" = "aws" ]; then
    # Check if AWS CLI is installed, otherwise install it.
    if ! command -v aws &> /dev/null; then
        # 1. Install aws cli. TODO.
        echo "TODO"
    fi
    # 2. Check if vmimport role exists, otherwise create it.
    ROLE_NAME="vmimport"
    # Check if the role exists
    if aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1; then
        echo "Role '$ROLE_NAME' already exists. Not re-creating."
    else
        echo "Role '$ROLE_NAME' does not exist. Creating..."

        aws iam create-role --role-name "$ROLE_NAME" --assume-role-policy-document '{
            "Version": "2012-10-17",
            "Statement": [{
                "Effect": "Allow",
                "Principal": { "Service": "vmie.amazonaws.com" },
                "Action": "sts:AssumeRole",
                "Condition": {
                    "StringEquals": {
                        "sts:Externalid": "vmimport"
                    }
                }
            }]
        }'

        echo "Attaching policy to '$ROLE_NAME'..."

        aws iam put-role-policy --role-name "$ROLE_NAME" --policy-name "$ROLE_NAME" --policy-document '{
            "Version": "2012-10-17",
            "Statement": [{
                "Effect": "Allow",
                "Action": [
                    "s3:GetBucketLocation",
                    "s3:GetObject",
                    "s3:ListBucket"
                ],
                "Resource": [
                        "arn:aws:s3:::*",
                        "arn:aws:s3:::*/*"
                    ]
            },
            {
                "Effect": "Allow",
                "Action": [
                    "ec2:ModifySnapshotAttribute",
                    "ec2:CopySnapshot",
                    "ec2:RegisterImage",
                    "ec2:Describe*"
                ],
                "Resource": "*"
            }]
        }'

        echo "Role '$ROLE_NAME' created and configured."
    fi
elif [ "$CSP" = "gcp" ]; then
    # Check if gcloud CLI is installed
    if ! command -v gcloud &> /dev/null; then
        # 1. Install gcloud CLI.
        install_gcloud
        # 2. Initialize gcloud CLI
        gcloud_init_login
        # 3. Enable compute engine API
        gcloud services enable compute.googleapis.com
    fi
elif [ "$CSP" = "azure" ]; then
    # Check if Azure CLI is installed
    if ! command -v az &> /dev/null; then
        # 1. Install Azure CLI. TODO.
        echo "TODO: Install Azure CLI"
    fi
else
    echo "❌ Error: Unsupported CSP '$CSP'. Supported CSPs are 'aws', 'gcp', and 'azure'."
    exit 1
fi


set +e