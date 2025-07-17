## Troubleshooting

### Failed to deploy cvm on Azure due to network error

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
