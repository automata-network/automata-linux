# cvm-base-image

## Prerequisites

1. This repo requires a Linux environment, preferably Ubuntu.

2. For all cloud providers, you need to install these dependencies:
```
sudo apt install zip
```

3. You also need the cli for the cloud provider you want to deploy on (either az cli, gcloud cli or aws cli)
- az cli:
  - Download: [Guide](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)
  - Login: [Guide](https://learn.microsoft.com/en-us/cli/azure/authenticate-azure-cli)
- gcloud cli:
  - Download: [Guide](https://cloud.google.com/sdk/docs/install)
  - Login: [Guide](https://cloud.google.com/sdk/docs/initializing)
- aws cli:
  - Download: [Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
  - Login: [Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-quickstart.html)

4. Additional dependencies if deploying to AWS:
- Service Role: You need a service role called [vmimport](https://docs.aws.amazon.com/vm-import/latest/userguide/required-permissions.html#vmimport-role)
- An S3 bucket to store the disk: [Guide](https://docs.aws.amazon.com/AmazonS3/latest/userguide/create-bucket-overview.html)

5. Additional dependencies if deploying to GCP:
- A GCP bucket to store the disk: [Guide](https://cloud.google.com/storage/docs/creating-buckets#console)

6. Additional dependencies if deploying to Azure:
- A resource group, a storage account, and image gallery
  - Note: Resource group, storage account, and shared image gallery must be in the same region as the VM you want to create. Please see the next section for details on the CVM types available in each region.
  - Note: SEV-SNP VMs may not be supported in the same region as TDX, so you may need to create separate resource groups, storage account and shared image gallery if you wish to support both CVM types on Azure.
  - Note: storage account name and shared image gallery name must be unique.
```bash
# Fill up the variables with a name of your choice.
RG="<resource group name>"
REGION="<region>"
STORAGE_ACCOUNT="<storage account name>" # lowercase letters and numbers only, length 3-24.
GALLERY_NAME="<gallery name>"

# Example virialble could be
# RG="cvm_testRg"
# REGION="East US 2"
# STORAGE_ACCOUNT="tdxcvm123"
# GALLERY_NAME="tdxGallery"

# Create a resource groups
az group create --name "$RG" --location "$REGION"

# Create a storage account
az storage account create --resource-group "$RG" --name "$STORAGE_ACCOUNT" --location "$REGION" --sku "Standard_LRS"

# Create a shared image gallery
az sig create --resource-group "$RG" --gallery-name "$GALLERY_NAME"
```

## CVM Information for each Cloud Provider 
This section outlines the confidential computing capabilities offered by major cloud providers, specifying supported CVM technologies—SEV-SNP and TDX—along with their corresponding instance families and available regions.

### AWS

- SEV-SNP:
  - Instance Family: [m6a, c6a, r6a](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/sev-snp.html#snp-requirements)
  - Region: us-east-2, eu-west-1
- TDX:
  - Not supported.


### Azure

- SEV-SNP:
  - Instance Family: [DCasV5](https://learn.microsoft.com/en-us/azure/virtual-machines/sizes/general-purpose/dcasv5-series?tabs=sizebasic)
  - Region: East US, West US, Switzerland North, Italy North, North Europe, West Europe, Germany West Central, UAE North, Japan East, Central India, East Asia, Southeast Asia

- TDX:
  - Instance Family: [DCesv5/DCedsv5](https://learn.microsoft.com/en-us/azure/virtual-machines/sizes/general-purpose/dcedsv5-series?tabs=sizebasic), [DCesv6](https://learn.microsoft.com/en-us/azure/virtual-machines/sizes/general-purpose/dcesv6-series?tabs=sizebasic)
  - Region:
    - DCesv5/DCedsv5: East US 2, Central US, West Europe, North Europe
    - DCesv6: West Europe, East US, West US, and West US 3

### GCP

- SEV-SNP:
  - Instance Family: [n2d-standard](https://cloud.google.com/compute/docs/general-purpose-machines#n2d_machine_types)
  - Region: asia-southeast1-a/b/c, europe-west3-a/b/c, europe-west4-a/b/c, us-central1-a/b/c
- TDX:
  - Instance Family: [c3-standard](https://cloud.google.com/compute/docs/general-purpose-machines#c3_machine_types)
  - Region: asia-southeast1-a/b/c, europe-west4-a/b/c, us-central1-a/b/c


## Download the cvm disk image
Please download a cvm disk image into the root of this repository. Please pick the disk according to the cloud provider you wish to deploy on:

```
# GCP Image
wget https://f004.backblazeb2.com/file/cvm-base-images/disk.raw

# AWS Image
wget https://f004.backblazeb2.com/file/cvm-base-images/disk.vmdk

# Azure Image
wget https://f004.backblazeb2.com/file/cvm-base-images/disk.vhd
```
> Note: Please ensure the the disk names are kept as is, as the scripts below assume that the disk names have not been changed.


## Deploying the disk and creating the CVM
Run the CLI to deploy the disk to the cloud provider.

1. To deploy to Azure:
```bash
./cvm-cli deploy-azure --resource_group <group> --storage_account <storage_account> --gallery_name <gallery_name> --additional_ports "80,443" --vm_name <name> --vm_type "<type>"
```
The following **must** be provided:
- storage_account: The name of the storage account to upload the cvm disk into.
- gallery_name: The name of the shared image gallery to use.
- resource_group: The name of the resource group to deploy the VM into. It must also contain the storage account and shared image gallery.

The following parameters are optional, and default to:
- vm_name: cvm_test
- vm_type: Standard_DC2es_v5 (Note: If the region used by your resource group does not support this VM type, creation of this VM will fail.)
- additional_ports: “”


2. To deploy to GCP:
```bash
./cvm-cli deploy-gcp --additional_ports "80,443" --vm_name <name> --region "<region>" --project_id <project id> --bucket <bucket_name> --vm_type "<type>"
```

The following **must** be provided:
- project_id: Name of the project to deploy into
- bucket : Name of the GCP bucket which will be used to temporarily store the disk image.

The following parameters are optional, and default to:
- vm_name: cvm-test
- region: asia-southeast1-b
- vm_type: c3-standard-4
- additional_ports: “”

3. To deploy to AWS:
```bash
./cvm-cli deploy-aws --additional_ports "80,443" --vm_name <name> --region "<region>" --bucket <bucket_name> --vm_type "<type>"
```

The following **must** be provided:
- bucket : Name of the S3 bucket which will be used to temporarily store the disk image. This **must** be in the same region as the VM.

The following parameters are optional, and default to:
- vm_name: cvm-test
- region: us-east-2
- vm_type: m6a.large
- additional_ports: “”

## Uploading workload to the CVM

### How to modify the `workload/` folder:
- In the folder, there are 3 things - a file called `docker-compose.yml` and 2 folders called `config/` and `secrets/`.
  - `docker-compose.yml` : This is a standard docker compose file that can be used to specify your workload. However, do note that podman-compose will run this file instead of docker-compose. While this generally works fine, there are some caveats:
    - Please see this [issue](https://github.com/containers/podman-compose/issues/575) regarding podman-compose and specific options in `depends_on`.
    - Images that are hosted on docker's official registry must be prefixed with `docker.io/`.
  - `config/` : Use this folder to store any files that will be mounted and used by the container. All the files in this folder will be measured by the init script before the container runs.
  - `secrets/`: Use this folder to store any files that will be mounted and used by the container, but should not be measured. Examples include cert private keys, or database credentials.
- Additionally, if you wish to load local images, simply put the `.tar` files for the container images into the `workload/` directory itself. This will be automatically detected and loaded.

### Upload the workload
Run the following command to upload your `workload/` folder to your deployed CVM:
```bash
./cvm-cli <VM IP> <API TOKEN>
```

## Creating the golden measurements
Now, you will also need to create the golden measurements for your CVM. This golden measurement will be used by verifiers to ensure that the CVM that they are interacting with can be trusted. The API that you can call depends on whether you intend to do off-chain verification or on-chain verification.

1. Once the VM ip is available and the VM has completely booted, query the attestation_agent on the CVM to get collaterals.

For off-chain:
```bash
curl --insecure https://8000/golden-measurement > collaterals.json
```

For on-chain:
```bash
TODO.
```

2. Publish the golden measurements for verifiers to reference.

For off-chain: the golden measurements can be stored anywhere that the workload can retrieve them, for example, on S3 storage.


For on-chain: TODO.


## Verifying the image and workload
To verify that the workload is running a CVM with the expected measurements, the verifier can undertake the following steps:
1. Retrieve the published golden measurements.
2. Use the cvm-agent to retrieve the collaterals required during verification: 
```
curl 127.0.0.1:7999/collaterals
```
3. Use the cvm-agent to verify the collaterals against the golden measurements:

For off-chain:
```
curl -X POST 127.0.0.1:7999/offchain-verify -H "Content-Type: application/json" \
  -d '{"collaterals": <string>, "golden_measurement": <string> }'
```

For on-chain:
```
TODO.
```

For more details on the APIs available on the cvm-agent, please check out [this document](docs/cvm-agent-api.md).

## Architecture

### Trust Architecture

![Chain of trust starting from the TEE hardware](docs/trust-architecture.png "Chain of Trust")

The diagram illustrates the trust architecture of our CVM Design from the lowest levels (hardware) all the way up to the highest levels (the workload). The vTPM is also cryptographically bound to the underlying Trusted Execution Environment (TEE) hardware in order to prevent replay attacks from malicious CVMs operating outside the trusted environment.

### Measured Boot
![Measured boot into TPM](docs/measured-boot.png "Measured Boot")

Measured boot captures and records cryptographic measurements of each step in the boot sequence, from VM launch all the way to workload initialization. Additionally, it securely extends these measurements into the TPM's Platform Configuration Registers (PCRs). The values extended into the PCRs can then be used to verify the integrity and trustworthiness of the entire boot process.

### Workload Architecture
![Workload architecture - the cvm agent is a sidecar to the main workload](docs/workload-architecture.png "Workload Architecture")

Within the CVM, two primary programs run concurrently: the cvm-agent and the workload. The workload may leverage the cvm-agent to retrieve and verify attestations and measurements, as well as dynamically update itself when new versions become available. In this design, the cvm-agent functions similarly to a sidecar, providing optional services for attestation and verification without tightly coupling itself to the primary workload. 

The cvm-agent provides a HTTP API as a means of communication, and more details of its API can be found in [this document](docs/cvm-agent-api.md).


### Workflow from Image Build -> Deployment -> Measurement

```mermaid
flowchart LR
  subgraph BuildPhase [Build Phase]
    direction TB
    A1[Files from rootfs/ are copied into the image rootfs partition]
    A2[veritysetup is used to generate the verity hash tree for the rootfs/]
    A3[verity hash is stored in initrd/, initramfs.cpio is generated]
    A4[Unified kernel image is generated and placed into image esp partition]
    A5[workload/ is copied to image data partition]

    A1 --> A2 --> A3 --> A4 --> A5
  end

  subgraph DeployPhase [Deploy Phase]
    direction TB
    C1[Upload image to a disk on Cloud Provider]
    C2[VM is created with this disk]

    C1 --> C2
  end

  subgraph RuntimePhase [Runtime Phase]
    direction TB
    B1[Verify correctness of rootfs partition with veritysetup]
    B2[Rootfs mounted]
    B3[Essential services loaded]
    B4[attestation_agent is started]
    B5[podman pulls the workload images]
    B6[tpm2_pcrextend pcr23 is executed on:
      - workload images
      - docker-compose.yml
      - config files used by workload]
    B7[podman-compose runs the workload]

    B1 --> B2 --> B3 --> B4 --> B5 --> B6 --> B7
  end

  subgraph GoldenMeasurementPhase [Generate Golden Measurements Phase]
    direction TB
    E1[curl service.com:8000/golden-measurement]
  end

  subgraph VerificationPhase [Verification Phase]
    direction TB
    D1[curl service.com:8000/collaterals]
    D2[curl service.com:8000/verify]

    D1 --> D2
  end

  BuildPhase --> DeployPhase --> RuntimePhase --> GoldenMeasurementPhase --> VerificationPhase
```


## Project Reference 
For the attesation agent, we currently use: 
https://github.com/automata-network/pom-sdk/tree/DEV-4072-dyn-container

For building cvm agent, we currently use: 
https://github.com/automata-network/cvm-uki/tree/DEV-4072-dynamic-containers




## Trouble Shoot