# cvm-base-image

## 📑 Table of Contents <!-- omit in toc -->
- [Prerequisites](#prerequisites)
- [Quickstart](#quickstart)
- [Detailed Walkthrough](#detailed-walkthrough)
- [Architecture](#architecture)
- [Troubleshooting](#troubleshooting)


## Prerequisites

- Ensure that you have enough permissions on your account on either GCP, AWS or Azure to create virtual machines, disks, networks, firewall rules, buckets/storage accounts and service roles.

## Quickstart

### 1. Deploying the CVM
To quickly deploy the CVM with the **default** workload, you can run the following command:

```bash
# Option 1. Deploy to GCP
./cvm-cli deploy-gcp

# Option 2. Deploy to AWS
./cvm-cli deploy-aws

# Option 3. Deploy to Azure
./cvm-cli deploy-azure
```

> [!Note]
> The script will automatically download a default disk to use. <br/>
> If another developer has given you a custom disk, you can use it instead of the default disk. To do so, simply:
> - Place the custom disk file in the root of this folder.
> - Make sure the file is named exactly as follows, depending on which cloud provider you plan to deploy on:
>   - GCP: gcp_disk.tar.gz
>   - AWS: aws_disk.vmdk
>   - Azure: azure_disk.vhd

### 2. Measurements & Artifacts
Once the VM is up, you can find your golden-measurements in the `_artifacts/golden-measurements/` folder. There will also be some files related to your vm deployment in the `_artifacts` folder. For example, if you deployed on GCP with the default VM name of `cvm-test`, you should see files like `gcp_cvm-test_ip`, `gcp_cvm-test_bucket`, etc. The artifacts vary per cloud provider.

### 3. Updating the workload
If you wish to update the workload on your deployed CVM, you can run the following command:

```bash
# ./cvm-cli update-workload <Cloud Provider> <VM Name>
# <Cloud Provider> = "aws" or "gcp" or "azure"
./cvm-cli update-workload gcp cvm-test
```

This command will upload the sample workload in `workload/` onto your existing VM, and also re-generate the golden-measurements for that specific VM.

### 4. Cleaning up
Finally, when you're ready to delete the VM and remove all the components that are deployed with it, you can run the following command:
```bash
# ./cvm-cli cleanup <Cloud Provider> <VM Name>
# <Cloud Provider> = "aws" or "gcp" or "azure"
./cvm-cli cleanup gcp cvm-test
```

## Detailed Walkthrough
To see a more detailed walkthrough of what can be customized, please check out [this doc](docs/detailed-cvm-walkthrough.md).

## Architecture
Details of our CVM trust chain and attestation architecture can be found in [this doc](docs/architecture.md).

## Troubleshooting
Running into trouble deploying the CVM? We have some common Q&A in [this doc](docs/troubleshooting.md).