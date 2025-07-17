# Detailed Walkthrough

## 📑 Table of Contents <!-- omit in toc -->
- [Configure the `workload/` folder](#configure-the-workload-folder)
  - [1. Create asymmetric keypairs](#1-create-asymmetric-keypairs)
  - [2. Sign the docker images that will be used](#2-sign-the-docker-images-that-will-be-used)
  - [3. Modify the `workload/` folder:](#3-modify-the-workload-folder)
  - [4. Configure the cvm-agent and Security Policy](#4-configure-the-cvm-agent-and-security-policy)
- [Deploying the workload onto the Cloud Provider](#deploying-the-workload-onto-the-cloud-provider)
  - [Deploying to Azure](#deploying-to-azure)
    - [Examples](#examples)
  - [Deploying to GCP](#deploying-to-gcp)
  - [Deploying to AWS](#deploying-to-aws)
- [Signing and Publishing the Golden Measurements](#signing-and-publishing-the-golden-measurements)
  - [1. Sign the golden measurements](#1-sign-the-golden-measurements)
  - [2. Publish the golden measurements](#2-publish-the-golden-measurements)
- [Verifying the image and workload](#verifying-the-image-and-workload)
  - [Off-chain verification](#off-chain-verification)
  - [On-chain verification](#on-chain-verification)
  - [Example: Peer Node Verification Workflow (Off-chain)](#example-peer-node-verification-workflow-off-chain)
    - [🧩 Components](#-components)
    - [🔄 Attestation Flow](#-attestation-flow)
    - [✅ Outcome](#-outcome)
- [Updating the workload](#updating-the-workload)
  - [1. Remember to sign the docker images that will be used](#1-remember-to-sign-the-docker-images-that-will-be-used)
  - [2. Update the `workload/` folder:](#2-update-the-workload-folder)
  - [3. Update the workload](#3-update-the-workload)



## Configure the `workload/` folder

### 1. Create asymmetric keypairs

Create one or more asymmetric keypairs, which will be used for the following steps:
  - [Signing the docker images](#2-sign-the-docker-images-that-will-be-used)
  - [Signing the golden measurements](#2-sign-the-golden-measurements)
```bash
# ECC key
openssl ecparam -genkey -name prime256v1 -noout -out private.pem
openssl ec -in private.pem -pubout -out public.pem

# RSA key
openssl genpkey -algorithm RSA -out private.pem -pkeyopt rsa_keygen_bits:2048
openssl rsa -in private.pem -pubout -out public.pem
```

### 2. Sign the docker images that will be used

TODO

### 3. Modify the `workload/` folder:
- In the folder, there are 3 things - a file called `docker-compose.yml` and 2 folders called `config/` and `secrets/`.
  - `docker-compose.yml` : This is a standard docker compose file that can be used to specify your workload. However, do note that podman-compose will run this file instead of docker-compose. While this generally works fine, there are some caveats:
    - Please see this [issue](https://github.com/containers/podman-compose/issues/575) regarding podman-compose and specific options in `depends_on`.
    - Images that are hosted on docker's official registry must be prefixed with `docker.io/`.
  - `config/` : Use this folder to store any files that will be mounted and used by the container. All the files in this folder will be measured by the cvm-agent into the TPM PCR before the container runs.
  - `secrets/`: Use this folder to store any files that will be mounted and used by the container, but should not be measured. Examples include cert private keys, or database credentials.
  > ⚠️ **Security Implication**  
  > Files in `secrets/` are **not measured** and are embedded into the disk image **before deployment**.  
  > This means they are **visible to the Cloud Service Provider (CSP)** and **not protected by the hardware execution enviroment (TEE)**.  
  >  
  > 🔐 **Mitigation:** If confidentiality from the CSP is required:  
  > - **Avoid placing long-lived or highly sensitive secrets in `secrets/`.**
  > - Use a **remote secret management service**, such as:
  >   - [Key Broker Service](https://docs.trustauthority.intel.com/main/articles/articles/ita/key-broker-service.html?tabs=passport-verification-mode)
  > - Fetch secrets at runtime **only after attestation is verified**.
- Additionally, if you wish to load local images, simply put the `.tar` files for the container images into the `workload/` directory itself. This will be automatically detected and loaded.



> [!IMPORTANT]
> If you have created any asymmetric keypairs in [Step 1](#1-create-asymmetric-keypairs), please also place the public keys into `workload/config/`.
> This is to ensure that the public keys will also be measured into the TPM PCR, and prevents against tampering.


### 4. Configure the cvm-agent and Security Policy
The CVM agent runs inside the CVM and is responsible for VM management, workload measurement, and related tasks. The tasks that it is allowed to perform depends on a security policy, which can be configured by the user.

The default security policy can be found in [workload/config/cvm_agent/cvm_agent_policy.json](workload/config/cvm_agent/cvm_agent_policy.json):
```json
{
    "cvm_config": {
        "emulation_mode" :{
            "enable": false,
            "cloud_provider": "azure",
            "tee_type": "snp" ,
            "emulation_data_path": "./emulation_mode_data",
            "enable_emulation_data_update": true
        },

        "firewall": {
            "allowed_ports": [
                {
                    "name": "allow_agent_local",
                    "protocol": "tcp",
                    "port": "7999"
                },
                {
                    "name": "allow_agent_external",
                    "protocol": "tcp",
                    "port": "8000"
                }
            ],
            "maintenance_mode_host_port": "2222"
        },

        "https_server" :{
            "enable_workload_update_endpoint": true,
            "enable_maintenance_endpoint": false,
            "enable_tls": true,
            "enable_workload_update_auth": true
        },

        "container_api" : {
            "container_engine": "podman",
            "container_owner": "automata"
        },

        "maintenance_mode" : {
            "signal" : "SIGUSR2"
        }
    }
}
```
The default policy is conservative, prioritizes security and can be used as it is. However, if you wish to change any settings, a detailed description of each policy option can be found in [this document](docs/cvm-agent-policy.md).

## Deploying the workload onto the Cloud Provider
Run the CLI to deploy the disk to the cloud provider.

### Deploying to Azure
```bash
./cvm-cli deploy-azure --vm_name <name> --vm_type "<type>" --region "<region>" --additional_ports "80,443"
```
The following parameters are optional, and default to:
- vm_name: cvm_test
- vm_type: Standard_DC2es_v5
- region: East US 2
- additional_ports: “”

> [!NOTE]
> `--vm_name` the name of the vm is used to automatically derive the following Azure resources:
>  - `resource_group`: `<vm_name>_rg`
>  - `storage_account`: Lowercase alphanumeric version of `<vm_name>` (max 24 characters)
>  - `gallery_name`: Lowercase alphanumeric + hyphens version of `<vm_name>` (max 80 characters)
>  To ensure valid derived names, vm_nameL:
>    - Must start with a **letter**
>    - Use only **letters**, **numbers**, and **hyphens**
>    - Avoid special characters (e.g., `_`, `!`, `@`) — they will be stripped or sanitized
>    - Keep it short — recommended ≤ 20 characters to avoid downstream name truncation

#### Examples

| `--vm_name` | Derived `resource_group` | Derived `storage_account` | Derived `gallery_name` |
|-------------|---------------------------|----------------------------|--------------------------|
| `tdx-demo`  | `tdx-demo_rg`             | `tdxdemo`                  | `tdx-demo`               |
| `MyCvm01`   | `MyCvm01_rg`              | `mycvm01`                  | `mycvm01`                |
| `a!@`       | `a!@_rg`                  | `a00`                      | `a`                      |



### Deploying to GCP
```bash
./cvm-cli deploy-gcp --additional_ports "80,443" --vm_name <name> --region "<region>" --project_id <project id> --bucket <bucket_name> --vm_type "<type>"
```

The following **must** be provided:
- project_id: Name of the project to deploy into
- bucket : Name of the GCP bucket which will be used to temporarily store the disk image.
  - **The name must be globally unique across GCP. The scripts will create it if it does not exist.**

The following parameters are optional, and default to:
- vm_name: cvm-test
- region: asia-southeast1-b
- vm_type: c3-standard-4
- additional_ports: “”

### Deploying to AWS
```bash
./cvm-cli deploy-aws --additional_ports "80,443" --vm_name <name> --region "<region>" --bucket <bucket_name> --vm_type "<type>"
```

The following **must** be provided:
- bucket : Name of the S3 bucket which will be used to temporarily store the disk image.
  - **The name must be globally unique across AWS. The scripts will create it if it does not exist.**

The following parameters are optional, and default to:
- vm_name: cvm-test
- region: us-east-2
- vm_type: m6a.large
- additional_ports: “”

> [!Warning]
> AWS currently has a known issue where the [boot process may intermittently hang for an SEV-SNP VM](https://bugs.launchpad.net/cloud-images/+bug/2076217). Please reboot the VM if you do not see a file called `_artifacts/golden-measurement.json` after the deployment script has completed. Once the VM has been rebooted, you can manually run `./scripts/get_golden_measurements.sh` to get the golden measurement.


## Signing and Publishing the Golden Measurements
> [!IMPORTANT]
> The golden measurements are required for the [verification phase](#verifying-the-image-and-workload), as they serve as the reference against which verifiers compare an attester's collaterals to confirm alignment with a known, expected state. The publisher of the workload should create and publish the golden measurement for verifiers to reference.

- Off-chain: After you have deployed the CVM on the cloud provider in the previous step, you should now have a file `_artifacts/golden-measurement.json`.
- On-chain: TODO


### 1. Sign the golden measurements

> [!NOTE]
> This step is optional, and depends on where the golden measurement will be hosted. For off-chain verification, it is recommended to sign the golden measurement if it will be hosted somewhere untrusted, like on a cloud provider's S3 bucket.

- For off-chain:
  - Step 1: Sign the golden measurement. A reference helper script has been provided in this repo:
   ```bash
   ./json_sig_tool.py sign _artifacts/golden-measurement.json private.pem -o signed-golden-measurement.json
   ```
  - Step 2: (Optional, Sanity check) Verify the signature
   ```bash
   ./json_sig_tool.py verify signed-golden-measurement.json public.pem
   ```
- For on-chain: TODO

### 2. Publish the golden measurements
Publish the golden measurements for verifiers to reference.

- For off-chain:
  - The golden measurements can be stored anywhere that a verifier can retrieve them, for example, on S3 storage.
  - If the verifier is hosted externally from a TEE environment, the golden measurement can be hosted there as well.


- For on-chain: TODO.


## Verifying the image and workload
### Off-chain verification
To verify that the workload is running a CVM with the expected measurements, the verifier should undertake the following steps in general:
1. Retrieve the published golden measurements from remote.
   - Verify the signature on the golden measurement to ensure it can be trusted, if needed.
2. Retrieve collaterals from the workload running on the attester CVM.
   - As an example, the workload on the attester CVM can query the cvm-agent locally as follows:
     ```bash
     curl 127.0.0.1:7999/collaterals/1234
     ```
3. Verify the collaterals against the published golden measurements.
   - If the verifier runs within a TEE environment that is created from our cvm-image, the verifier can use the cvm-agent to verify the collaterals against the published golden measurements:
     ```bash
     # Assuming that the verifier saves the collaterals as collaterals.json:
     jq -s '{ golden_measurement: (.[1].golden_measurement | @json), collaterals: (.[0] | @json) }' collaterals.json signed-golden-measurement.json | curl -X POST 127.0.0.1:7999/offchain-verify -H "Content-Type: application/json" -d @-
     ```
   - If the verifier runs outside of a TEE environment, the [cvm-verifier SDK](https://github.com/automata-network/cvm-verifier) can be used to verify the collaterals against the golden-measurement:
     ```bash
     # Run the verifier. Assuming the verifier saves the collaterals as collaterals.json:
     cargo run --release --bin cvm-verifier collaterals.json golden-measurement.json
     ```


For a more concrete example of the verification workflow, please check out the [peer node verification workflow below](#example-peer-node-verification-workflow-off-chain).


### On-chain verification
```
TODO.
```

For more details on the APIs available on the cvm-agent, please check out [this document](docs/cvm-agent-api.md).


### Example: Peer Node Verification Workflow (Off-chain)
![Example - Peer Node Verification Workflow](docs/automata_cvm_peer_node_verification.png "Peer Node Verification Workflow")

This use-case describes the remote attestation flow between two **Confidential Virtual Machines (VMs)**—an **attester** and a **verifier**—using **attestation agents** and optional **remote storage** for verification.


#### 🧩 Components

##### 🔐 Confidential VM (Attester)
- **Workload (attester):** Application that provides collaterals to **verifier** for verification.
- **Attestation Agent:** Retrieves attestation reports and platform-specific collateral (e.g., TCB info, certificates).

##### 🔎 Confidential VM (Verifier)
- **Workload (verifier):** Application that receives collaterals from **attester** and verifies the collaterals using its local **Attestation Agent**.
- **Attestation Agent:** Validates the integrity of the attester's collaterals using cryptographic operations.

##### 🗄️ Remote Storage
- Stores known-good reference values used by the verifier to compare against collaterals of **attester** (ie, the golden measurement).


#### 🔄 Attestation Flow
1. **Get Golden Value**  
  The **verifier workload** gets golden value of **attester workload** from **remote storage**.

2. **Initiates attestation request**  
   The **verifier workload** send the attestation req to **attester workload**.

3. **Collect Evidence**  
   The **attester workload** get the collaterals from its local **attestation agent** via `/collateral` endpoint.

4. **Respond to the attestation request**  
   The **attester workload** replies the verifier workload with its collaterals.

5. **Verify Evidence**  
   The **verifier workload** calls its **attestation agent** using `/offchain-verify` to perform cryptographic validation and verify trustworthiness.

#### ✅ Outcome

If verification succeeds, the **verifier** can trust the **attester's VM** and proceed with sensitive operations such as key sharing or secure computation.


## Updating the workload

If the workload requires an update (eg. such as a new image version), the following steps can be taken:
>[!Note]
> If the podman runtime is selected in the agent policy, volume and network cannot be updated using this method.


### 1. Remember to sign the docker images that will be used

Please refer to [this step](#2-sign-the-docker-images-that-will-be-used) for details.

### 2. Update the `workload/` folder:
Please refer to [this step](#3-modify-the-workload-folder) for details.

### 3. Update the workload
Run the following command to upload your updated workload to your deployed CVM:
```bash
./cvm-cli update-workload
```
