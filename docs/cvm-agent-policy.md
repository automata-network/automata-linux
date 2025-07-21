# Confidential VM (CVM) Policy Configuration

This document provides an explanation of the policy configuration JSON for managing a Confidential VM (CVM). The policy outlines settings related to emulation mode, HTTPS server configuration, container management, and maintenance operations.

---

## 1. Emulation Mode (`emulation_mode`)
Emulation mode is used to run the agent on platforms that don't have TPM and TEEs support. This mode is used for agent development and testing. 

The following settings manage the use of emulated mode of the agent:

| Field                           | Value                          | Explanation                                           |
|---------------------------------|--------------------------------|-------------------------------------------------------|
| `enable`                        | `false`                        | Emulation mode is currently **disabled**, indicating execution on actual hardware. |
| `cloud_provider`                | `"azure"`                      | Indicates Azure as the cloud provider being targeted.  Ohter possible options include **google** and **amazon**|
| `tee_type`                      | `"snp"`                        | Specifies AMD SEV-SNP as the Trusted Execution Environment (TEE).  Ohter possible options include **tdx**|
| `emulation_data_path`           | `"./emulation_mode_data"`      | Path to get data used for emulation (attestation report, TPM quote etc.,). |
| `enable_emulation_data_update`  | `true`                         | Allows updates the data used for emulation mode. |

---

## 2. Firewall (`firewall`)

By default, all incoming traffic on all ports are blocked. This setting allows you to define ports that should be allowed through the firewall.

| Field               | Value       | Explanation                                                  |
|---------------------|-------------|--------------------------------------------------------------|
| `allowed_ports`     | `list[ PortConfig , ... ]` | List of allowed ports |
| `maintenance_mode_host_port`  | `"2222"`    | SSH port on the VM host for accessing a ssh server running in a container during maintenance periods. |


### Port Config Struct

| Field               | Value       | Explanation                                                  |
|---------------------|-------------|--------------------------------------------------------------|
| `name`     | `string` | Label for user to identify what the port will be used for |
| `protocol` | `string` | `"tcp"` or `"udp"` |
| `port`     | `string` | Port number to allow through the firewall |

---

## 3. HTTPS Server (`https_server`)

Defines HTTP(S) server settings to manage workload updates and VM maintenance:

| Field                              | Value     | Explanation                                                  |
|------------------------------------|-----------|--------------------------------------------------------------|
| `enable_workload_update_endpoint`  | `true`    | Enables the endpoint for workload updates via HTTP(S).       |
| `enable_maintenance_endpoint`      | `true`    | Activates the maintenance endpoint for administrative tasks (i.e., ssh into the container). |
| `enable_tls`                       | `false`   | TLS encryption is currently **disabled**, resulting in insecure HTTP communications (**not recommended for production**). |
| `enable_workload_update_auth`      | `false`   | Authentication for management APIs (i.e., workload_update and maintenance mode) of the agent. It is now **disabled**. (**Not recommended for production environments.**) |

---

## 4. Container API (`container_api`)

Configuration related to container management within the CVM:

| Field                | Value           | Explanation                                                      |
|----------------------|-----------------|------------------------------------------------------------------|
| `container_engine`   | `"podman"`      | Specifies **Podman** as the container runtime for managing containers. |
| `container_owner`    | `"automata"`   | User context under which containers run, affecting permissions and security contexts.  By default, Podman runs all containers under **automata** namespace|

---

## 5. Maintenance Mode (`maintenance_mode`)

Settings that govern VM maintenance activities:

| Field               | Value       | Explanation                                                  |
|---------------------|-------------|--------------------------------------------------------------|
| `signal`            | `"SIGUSR2"` | Specifies the signal (`SIGUSR2`) used to notify the containers that the maintenance mode is enabled or disabled.  Containers thus need to implement the signal handler for receiving the notification from the agent|

Note that users should add their public key to the appropriate location (i.e., `~/.ssh/authorized_keys`) within the container and enable port mapping for the SSH server. Example can be found at **Q&A**.  Also, for the proper signal handling, the application process must have **PID 1** in the container (This is very common in containerized applications such as redis and nginx). Otherwise, application may not be able to receive the signal sent by the cvm_agent.

---

## 6. Workload Configuration (`workload_config`)

### `workload` Rules
Defines worload update rules during cvm runtime

| Field                      | Value                            | Explanation |
|----------------------------|----------------------------------|-------------|
| `allow_remove`             | `false`                          | Services cannot be removed at runtime. |
| `allow_update`             | `true`                           | Existing services can be updated. |
| `allow_add_new_service`    | `true`                           | New services can be deployed. |
| `update_white_list`        | `["prometheus", "node-exporter", "metrics-proxy"]` | Only these services are allowed to be updated at runtime if `allow_update` is enabled. |

### `image_signature_verification`

Controls the verification of container images before execution.

| Field                        | Description |
|-----------------------------|-------------|
| `image_signature_verification` | Enables signature checking logic. If disabled, unsigned containers will run. |

**`image_signature_verification` structure**:

| Field                             | Value    | Description |
|----------------------------------|----------|-------------|
| `enable`                         | `false`  | If true, enforce signature verification. |
| `auth_info.user_name`            | `""`     | Optional auth user for pulling signed images from private repo. |
| `auth_info.password`             | `""`     | Optional password for above user. |
| `signature_verification_policy_path` | `"/data/workload/config/cvm_agent/sample_image_verify_policy.json"` | Path to JSON policy file defining valid signing keys and rules. |

You can pre-configure the policy even if enforcement is currently disabled.

>[!Note]
> Before executing this step, please ensure that you have already done the following:
> If pulling from a public registry, ensure both `auth_info.user_name` and `auth_info.password` remain empty.
> Populate `auth_info` only when accessing private registries. 
> **Warning**: Credentials provided in this section are subject to measurement by `cvm-agent` and may be exposed in attestation. Use **minimal-privilege accounts** or **short-lived tokens** to mitigate risk.




The `signature_verification_policy_path` points to a policy file that defines rules for which images are allowed to run.
For more detail of the image verification policy, please check out [this document](./cvm-agent-image-signature-policy.md)

---

## Usage Notes

- **Emulation Mode** is suitable for controlled development or test scenarios.
- Maintenance settings allow straightforward administration and troubleshooting.

---

## Security Recommendations for Production Environments

- Enable `enable_tls` and `enable_workload_update_auth` for secure communications and authenticated updates in production deployments.
- Disable `enable_maintenance_endpoint` unless it is required.
- **TLS** and **Workload Authentication** should be enabled.



---

## Q&A

### How to add your public key to the Docker container:

#### Step 1: Prepare Your Public Key
Make sure you have your SSH public key (id_rsa.pub) in your local directory (e.g., alongside your Dockerfile):

```bash
.
├── Dockerfile
└── id_rsa.pub
Generate it if needed:
```

Generate it if needed:
```bash
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
```

#### Step 2: Dockerfile (Minimal Example)

Your Dockerfile correctly sets up the environment. Ensure the public key is copied correctly into the container:

```yaml
FROM ubuntu:22.04

RUN apt-get update && \
    apt-get install -y openssh-server sudo && \
    apt-get clean

# Create new group to avoid "group operator exists" issue
RUN groupadd sshusers && useradd -m -s /bin/bash -g sshusers operator

# Prepare SSH server and authorized_keys
RUN mkdir -p /home/operator/.ssh && \
    mkdir -p /var/run/sshd && \
    echo "AllowUsers operator" >> /etc/ssh/sshd_config && \
    echo "PasswordAuthentication no" >> /etc/ssh/sshd_config && \
    echo "PermitRootLogin no" >> /etc/ssh/sshd_config

# Copy your public key
COPY id_rsa.pub /home/operator/.ssh/authorized_keys

# Set permissions
RUN chown -R operator:sshusers /home/operator/.ssh && \
    chmod 700 /home/operator/.ssh && \
    chmod 600 /home/operator/.ssh/authorized_keys

EXPOSE 22
CMD ["/usr/sbin/sshd", "-D"]
```

#### Step 3: Build the Docker Image

Run the following command in your terminal (in the directory with Dockerfile and id_rsa.pub):
```bash
docker build -t ssh-container-example .
```

#### Step 4: Push your image to remote repo

```bash
docker tag ssh-container-example mydockeruser/ssh-container-example:latest
docker login
docker push mydockeruser/ssh-container-example:latest
```

### How to enable the port mapping for the target container that runs ssh:
User can use the **ports** keyword to enable the ssh access to the container. 
In particular, please make sure that the port **2222** match the port specified in the policy

```yaml
version: '3.8'

services:
  operator:
    image: docker.io/mydockeruser/ssh-container-example:latest
    container_name: operator
    restart: unless-stopped
    ports:
      - "2222:22"
```
