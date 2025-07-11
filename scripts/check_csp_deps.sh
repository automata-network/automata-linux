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
        # 1. Install gcloud CLI. TODO.
        echo "TODO: Install gcloud CLI"

        # 2. Enable compute engine API
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