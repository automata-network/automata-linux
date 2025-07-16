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
    echo "✅ gcloud cli installed successfully."
    popd
}

# Function to trigger gcloud login
gcloud_init_login() {
    echo "🔐 Logging in to gcloud..."
    gcloud init --console-only --no-launch-browser
}

detect_package_manager() {
    if command -v apt >/dev/null 2>&1; then
        echo "apt"
    elif command -v dnf >/dev/null 2>&1; then
        echo "dnf"
    elif command -v pacman >/dev/null 2>&1; then
        echo "pacman"
    else
        echo "unknown"
    fi
}

detect_rhel_variant() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            rhel)
                if [ "$VERSION_ID" = "8" ]; then
                    echo "rhel8"
                elif [ "$VERSION_ID" = "9" ]; then
                    echo "rhel9"
                else
                    echo "rhel_unknown"
                fi
                ;;
            centos)
                if grep -q "Stream" /etc/centos-release 2>/dev/null; then
                    echo "centos_stream"
                fi
                ;;
            *)
                echo "unknown_distro"
                ;;
        esac
    fi
    echo "unsupported_distro"
}

install_azcli() {
    echo "🔽 Downloading and installing az cli..."

    OS="$(uname -s)"
    ARCH="$(uname -m)"
    if [ "$OS" = "Darwin" ]; then
        brew update && brew install azure-cli
    elif [ "$OS" = "Linux" ]; then
        PM=$(detect_package_manager)
        case "$PM" in
            apt)
                echo "Detected apt. Installing Azure CLI..."
                curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
                ;;
            dnf)
                echo "Detected dnf. Installing Azure CLI..."
                sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
                RHEL_VARIANT=$(detect_rhel_variant)
                case "$RHEL_VARIANT" in
                    rhel8)
                        sudo dnf install -y https://packages.microsoft.com/config/rhel/8/packages-microsoft-prod.rpm
                        ;;
                    rhel9|centos_stream)
                        sudo dnf install -y https://packages.microsoft.com/config/rhel/9.0/packages-microsoft-prod.rpm
                        ;;
                    *)
                        echo "❌ Unsupported RHEL variant: $RHEL_VARIANT"
                        exit 1
                        ;;
                esac
                sudo dnf install -y azure-cli
                ;;
            *)
                echo "❌ No supported package manager found. Cannot install Azure CLI."
                exit 1
                ;;
        esac
    else
        echo "❌ Unsupported OS: $OS"
        exit 1
    fi
    echo "✅ azcli installed successfully."
}

install_other_az_deps() {
    OS="$(uname -s)"
    if ! command -v jq >/dev/null 2>&1; then
        if [ "$OS" = "Darwin" ]; then
            brew update && brew install jq
        elif [ "$OS" = "Linux" ]; then
            PM=$(detect_package_manager)
            case "$PM" in
                apt)
                    sudo apt install -y jq
                    ;;
                dnf)
                    sudo dnf install jq
                    ;;
            esac
        else
            echo "❌ Unsupported OS: $OS"
            exit 1
        fi
    fi
}

install_aws_cli() {
    echo "🔽 Downloading and installing aws cli..."

    OS="$(uname -s)"
    ARCH="$(uname -m)"
    if [ "$OS" = "Darwin" ]; then
        brew update && brew install awscli
    elif [ "$OS" = "Linux" ]; then
        TMP_DIR=$(mktemp -d)
        pushd "$TMP_DIR"

        if [ "$ARCH" = "x86_64" ]; then
            curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
        elif [ "$ARCH" = "arm64" ] || [ "$ARCH" = "aarch64" ]; then
            curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"
        else
            echo "❌ Unsupported architecture: $ARCH"
            exit 1
        fi
        unzip awscliv2.zip
        sudo ./aws/install

        popd
        rm -rf "$TMP_DIR"
    else
        echo "❌ Unsupported OS: $OS"
        exit 1
    fi
    echo "✅ AWS CLI installed successfully."
}

aws_login() {
    echo "🔐 Logging in to AWS..."
    echo "Enter your AWS Access Key ID:"
    read -r AWS_ACCESS_KEY_ID
    aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
    echo "Enter your AWS Secret Access Key:"
    read -r AWS_SECRET_ACCESS_KEY
    aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY
    aws configure set region us-east-2
    echo "✅ AWS CLI configured successfully."
}

if [ "$CSP" = "aws" ]; then
    # Check if AWS CLI is installed, otherwise install it.
    if ! command -v aws &> /dev/null; then
        # 1. Install aws cli.
        install_aws_cli
        # 2. Configure AWS CLI
        aws_login
        # 3. Check if vmimport role exists, otherwise create it.
        ROLE_NAME="vmimport"
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

            echo "✅ Role '$ROLE_NAME' created and configured."
        fi
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
    install_other_az_deps
    # Check if Azure CLI is installed
    if ! command -v az &> /dev/null; then
        # 1. Install Azure CLI.
        install_azcli
        # 2. Login to Azure CLI
        az login --use-device-code
    fi
else
    echo "❌ Error: Unsupported CSP '$CSP'. Supported CSPs are 'aws', 'gcp', and 'azure'."
    exit 1
fi


set +e
