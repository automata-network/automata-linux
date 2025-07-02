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
| `tee_type`                      | `"snp"`                        | Specifies AMD SEV-SNP as the Trusted Execution Environment (TEE).  Ohter possible options include **TDX**|
| `emulation_data_path`           | `"./emulation_mode_data"`      | Path to get data used for emulation (attestation report, TPM quote etc.,). |
| `enable_emulation_data_update`  | `true`                         | Allows updates the data used for emulation mode. |

---

## 2. HTTPS Server (`https_server`)

Defines HTTP(S) server settings to manage workload updates and VM maintenance:

| Field                              | Value     | Explanation                                                  |
|------------------------------------|-----------|--------------------------------------------------------------|
| `enable_workload_update_endpoint`  | `true`    | Enables the endpoint for workload updates via HTTP(S).       |
| `enable_maintenance_endpoint`      | `true`    | Activates the maintenance endpoint for administrative tasks (i.e., ssh into the container). |
| `enable_tls`                       | `false`   | TLS encryption is currently **disabled**, resulting in insecure HTTP communications (**not recommended for production**). |
| `enable_workload_update_auth`      | `false`   | Authentication for management APIs (i.e., workload_update and maintenance mode) of the agent. It is now **disabled**. (**Not recommended for production environments.**) |

---

## 3. Container API (`container_api`)

Configuration related to container management within the CVM:

| Field                | Value           | Explanation                                                      |
|----------------------|-----------------|------------------------------------------------------------------|
| `container_engine`   | `"podman"`      | Specifies **Podman** as the container runtime for managing containers. |
| `container_owner`    | `"automata"`   | User context under which containers run, affecting permissions and security contexts.  By default, Podman runs all containers under **automata** namespace|

---

## 4. Maintenance Mode (`maintenance_mode`)

Settings that govern VM maintenance activities:

| Field               | Value       | Explanation                                                  |
|---------------------|-------------|--------------------------------------------------------------|
| `signal`            | `"SIGUSR2"` | Specifies the signal (`SIGUSR2`) used to notify the containers that the maintenance mode is enabled or disabled.  Containers thus need to implement the signal handler for receiving the notification from the agent|
| `ssh_port_on_host`  | `"2223"`    | SSH port on the VM host for accessing a ssh server running in a container during maintenance periods. |

---

## Usage Notes

- **Emulation Mode** is suitable for controlled development or test scenarios.
- **TLS** and **Workload Authentication** should be enabled in production environments for security.
- Maintenance settings allow straightforward administration and troubleshooting.

---

## Security Recommendations

- Ensure to enable `enable_tls` and `enable_workload_update_auth` for secure communications and authenticated updates in production deployments.

