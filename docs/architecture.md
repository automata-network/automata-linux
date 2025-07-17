## Architecture

### Trust Architecture

![Chain of trust starting from the TEE hardware](trust-architecture.png "Chain of Trust")

The diagram illustrates the trust architecture of our CVM Design from the lowest levels (hardware) all the way up to the highest levels (the workload). The vTPM is also cryptographically bound to the underlying Trusted Execution Environment (TEE) hardware in order to prevent replay attacks from malicious CVMs operating outside the trusted environment.

### Measured Boot
![Measured boot into TPM](measured-boot.png "Measured Boot")

Measured boot captures and records cryptographic measurements of each step in the boot sequence, from VM launch all the way to workload initialization. Additionally, it securely extends these measurements into the TPM's Platform Configuration Registers (PCRs). The values extended into the PCRs can then be used to verify the integrity and trustworthiness of the entire boot process.

### Workload Architecture
![Workload architecture - the cvm agent is a sidecar to the main workload](workload-architecture.png "Workload Architecture")

Within the CVM, two primary programs run concurrently: the cvm-agent and the workload. The workload may leverage the cvm-agent to retrieve and verify attestations and measurements, as well as dynamically update itself when new versions become available. In this design, the cvm-agent functions similarly to a sidecar, providing optional services for attestation and verification without tightly coupling itself to the primary workload. 

The cvm-agent provides a HTTP API as a means of communication, and more details of its API can be found in [this document](cvm-agent-api.md).


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
    B4[cvm-agent is started]
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
    D1[Get attester's collaterals]
    D2[Verify attester's collaterals against golden measurement]

    D1 --> D2
  end

  BuildPhase --> DeployPhase --> RuntimePhase --> GoldenMeasurementPhase --> VerificationPhase
```