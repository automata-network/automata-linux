## Troubleshooting

### AZURE Cloud

#### Failed to deploy cvm on Azure due to network error

Q: Help! I got the following error when deploying the CVM on Azure:

```bash
$ ./cvm-cli deploy-azure \
  --additional_ports "80,443,2222" \
  --vm_name "tdx-cvm-demo" \
  --resource_group "$RG" \
  --vm_type "Standard_DC2es_v5" \
  --storage_account "$STORAGE_ACCOUNT" \
  --gallery_name "$GALLERY_NAME"
Deploying azure_disk.vhd with the following parameters:
🔹VM Name: tdx-cvm-demo
🔹Resource Group: cvm_testRg
🔹VM Type: Standard_DC2es_v5
🔹Additional Ports: 80,443,2222
🔹Storage Account: tdxcvm123
🔹Shared Image Gallery: tdxGallery
......
......
......
++ echo '⏳ Image replication + gallery image version in progress... this might take a while (8+ mins). Time to grab a coffee and chill ☕🙂'
⏳ Image replication + gallery image version in progress... this might take a while (8+ mins). Time to grab a coffee and chill ☕🙂
++ true
+++ az sig image-version show --resource-group cvm_testRg --gallery-name tdxGallery --gallery-image-definition tdx-cvm-demo-def --gallery-image-version 1.0.0 --query provisioningState -o tsv
++ state=Creating
++ [[ Creating == \S\u\c\c\e\e\d\e\d ]]
++ echo '⏳ Still provisioning... (state: Creating)'
⏳ Still provisioning... (state: Creating)
++ sleep 30
++ true
+++ az sig image-version show --resource-group cvm_testRg --gallery-name tdxGallery --gallery-image-definition tdx-cvm-demo-def --gallery-image-version 1.0.0 --query provisioningState -o tsv
++ state=Failed
++ [[ Failed == \S\u\c\c\e\e\d\e\d ]]
++ echo '⏳ Still provisioning... (state: Failed)'
⏳ Still provisioning... (state: Failed)
++ sleep 30
++ true
```

A: The error is due to network issues. To fix it, delete the resource group on Azure and redeploy the CVM again.


### AWS
#### Failed to deploy cvm on Azure due to network error

Q: Help! I got the following error when deploying the CVM on AWS:
```bash
$ ./cvm-cli deploy-aws 
ℹ️  No bucket provided. Using generated bucket name: cvmtesteq1vv4
⌛ Double-checking the VM type and region for CSP...
⌛ Checking whether disk image exists...
⌛ Adding API token to disk...
    (100.00/100%)
NAME      MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
loop0       7:0    0    2G  0 loop 
├─loop0p1 259:0    0  511M  0 part 
├─loop0p2 259:1    0  512M  0 part 
└─loop0p3 259:2    0 1023M  0 part 
ℹ️  Generating API token...
✅ Done! API token generated!
    (100.00/100%)
Deploying aws_disk.vmdk with the following parameters:
🔹VM Name: cvm-test
🔹Region: us-east-2
🔹VM Type: m6a.large
🔹Bucket : cvmtesteq1vv4
🔹Additional Ports: 
++ set -e
++ aws s3api head-bucket --bucket cvmtesteq1vv4
++ echo 'Bucket '\''cvmtesteq1vv4'\'' does not exist. Creating...'
Bucket 'cvmtesteq1vv4' does not exist. Creating...
++ aws s3api create-bucket --bucket cvmtesteq1vv4 --region us-east-2 --create-bucket-configuration LocationConstraint=us-east-2
 
An error occurred (InvalidAccessKeyId) when calling the CreateBucket operation: The AWS Access Key Id you provided does not exist in our records.
++ echo '❌ Error: Failed to create bucket in us-east-2'
❌ Error: Failed to create bucket in us-east-2
++ exit 1
```

A: The error is due to wrong aws credentials. To fix it, update the aws credential `aws_access_key_id` and `aws_secret_access_key` in `~/.aws/credentials` and redeploy the CVM again:
```bash
$ cat  ~/.aws/credentials 
[default]
aws_access_key_id = bdea299cb2e013216137e874e99c640c6f002e033adffa227f61c29e10cefff1
aws_secret_access_key = bdea299cb2e013216137e874e99c640c6f002e033adffa227f61c29e10cefff
```