# cvm-base-image

## 📑 Table of Contents <!-- omit in toc -->
- [Prerequisites](#prerequisites)
- [Quickstart](#quickstart)
- [Deploying the CVM with your workload](#deploying-the-cvm-with-your-workload)
- [Detailed Walkthrough](#detailed-walkthrough)
- [Architecture](#architecture)
- [Troubleshooting](#troubleshooting)


## Prerequisites

- Ensure that you have enough permissions on your account on either GCP, AWS or Azure to create virtual machines, disks, networks, firewall rules, buckets/storage accounts and service roles.

## Quickstart

### 1. Deploying the CVM <!-- omit in toc -->
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

### 2. Get logs from the CVM <!-- omit in toc -->

At the end of the previous step, you should have the following output:
```bash
✅ Golden measurements saved to _artifacts/golden-measurements/gcp-cvm-test.json
✨ Deployment complete! Your VM Name: cvm-test
```

Using the provided VM name, you can retrieve logs from the VM like this:

```bash
# ./cvm-cli get-logs <cloud-provider> <vm-name>
# <cloud-provider> = "aws" or "gcp" or "azure"
./cvm-cli get-logs aws cvm-test
```

### 3. Destroy the VM <!-- omit in toc -->
Finally, when you're ready to delete the VM and remove all the components that are deployed with it, you can run the following command:
```bash
# ./cvm-cli cleanup <cloud-provider> <vm-name>
# <cloud-provider> = "aws" or "gcp" or "azure"
./cvm-cli cleanup gcp cvm-test
```

## Deploying the CVM with your Workload

### 1. Add your workload to `workload/` <!-- omit in toc -->

In this folder, you will see 3 things - a file called `docker-compose.yml`, and 2 folders called `config/` and `secrets/`.

- `docker-compose.yml` : This is a standard docker compose file that can be used to specify your workload. Most standard docker compose files will work fine and you do not need to do anything special. However, as podman-compose will be used to run this file, do take note of the following caveats:
  - Container images that are hosted on docker's official registry must be prefixed with `docker.io/`.
  - Podman does not support `depends_on.condition = service_completed_successfully`.
- `config/` : Use this folder to store any files that will be mounted and used by the container. All the files in this folder will be measured by the cvm-agent into the TPM PCR before the container runs.
- `secrets/`: Use this folder to store any files that will be mounted and used by the container, but should not be measured. Examples include cert private keys, or database credentials.

> [!Caution]
> Remember to build your container images for X86_64, especially if you're using an ARM64 machine!

> [!Note]
> If you wish to load container images that are not published to any container registry, simply put the `.tar` files for the container images into the `workload/` directory itself. This will be automatically detected and loaded at runtime.

### 2. Edit the Security Policy <!-- omit in toc -->
The CVM agent runs inside the CVM and is responsible for VM management, workload measurement, and related tasks. The tasks that it is allowed to perform depends on a security policy, which can be configured by the user.

By default, the CVM will use the default security policy found in [workload/config/cvm_agent/cvm_agent_policy.json](workload/config/cvm_agent/cvm_agent_policy.json). There are 2 settings that you **must** configure:

- `firewall.allowed_ports`: By default, all incoming traffic on all ports are blocked by nftables, except for CVM agent ports 7999 and 8000. If your workload requires incoming traffic on other ports (eg. you need a p2p port on 30000), please follow the given example and add the ports you require.
- `workload_config.workload.update_white_list`: This list specifies which services in your docker-compose.yml are allowed to be updated remotely via the cvm-agent API `/update-workload`. **You must list the names of your services in your docker-compose.yml if you wish to allow remote updates. Otherwise, set it to an empty list `[]` to disallow remote updates.**

The other settings not mentioned can be left as its default values. If you wish to modify the other settings, a detailed description of each policy option can be found in [this document](docs/cvm-agent-policy.md).

### 3. Deploy the CVM <!-- omit in toc -->

In this example, we assume that you're deploying a workload that needs a p2p port on port 30000. If your workload does not need the additional port, feel free to omit `--additional_ports "30000"`. Note that the `--additional_ports` option is for the cloud provider firewall, not the nftables firewall used by the security policy we defined above.

```bash
# Option 1. Deploy to GCP
./cvm-cli deploy-gcp --add-workload --additional_ports "30000"

# Option 2. Deploy to AWS
./cvm-cli deploy-aws --add-workload --additional_ports "30000"

# Option 3. Deploy to Azure
./cvm-cli deploy-azure --add-workload --additional_ports "30000"
```

At the end of the deployment, you should be able to see the name of the deployed CVM in the shell, and the location where the golden measurement of this CVM is stored:

```bash
✅ Golden measurements saved to _artifacts/golden-measurements/gcp-cvm-test.json
✨ Deployment complete! Your VM Name: cvm-test
```

> [!Note]
> Please see the [detailed walkthrough](#detailed-walkthrough) if you wish to do the following:
> - Customise other settings, like the vm name, or where the vm is deployed.
> - Check on best practices regarding the golden measurement, or how to use it in remote attestation.
> - If you only want to build a disk with your workload and distribute it to others.

### 4. Managing the CVM <!-- omit in toc -->
We've scripted some convenience commands that you can run to manage your CVM.

#### Get Logs <!-- omit in toc -->
Use this command to get all logs from all running containers in the CVM.

```bash
# ./cvm-cli get-logs <vm-name>
./cvm-cli get-logs cvm-test
```

#### Update the workload <!-- omit in toc -->
In the scenario where you have updated the your app version and made a new container image for it, you can update your workload in the `workload/` folder, and upload this folder onto the existing CVM using this command:

```bash
# ./cvm-cli update-workload <cloud-provider> <vm-name>
# <cloud-provider> = "aws" or "gcp" or "azure"
./cvm-cli update-workload gcp cvm-test
```

When the script is finished, the golden measurements will be automatically regenerated for you.

> [!Note]
> If you are having troubles updating the workload, you might have forgotten to set the `workload_config.workload.update_white_list`. Please see the above section on [editing the security policy](#2-edit-the-security-policy).

#### Deleting the VM: <!-- omit in toc -->
Use this command to delete the VM once you no longer need it.

```bash
# ./cvm-cli cleanup <cloud-provider> <vm-name>
# <cloud-provider> = "aws" or "gcp" or "azure"
./cvm-cli cleanup gcp cvm-test
```

## Detailed Walkthrough
A detailed walkthrough of what can be customized and any other features available can be found in [this doc](docs/detailed-cvm-walkthrough.md).

## Architecture
Details of our CVM trust chain and attestation architecture can be found in [this doc](docs/architecture.md).

## Troubleshooting
Running into trouble deploying the CVM? We have some common Q&A in [this doc](docs/troubleshooting.md).