<div align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/automata-network/automata-brand-kit/main/PNG/ATA_White%20Text%20with%20Color%20Logo.png">
    <source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/automata-network/automata-brand-kit/main/PNG/ATA_Black%20Text%20with%20Color%20Logo.png">
    <img src="https://raw.githubusercontent.com/automata-network/automata-brand-kit/main/PNG/ATA_White%20Text%20with%20Color%20Logo.png" width="50%">
  </picture>
</div>

# Automata Linux

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![GitHub Release](https://img.shields.io/github/v/release/automata-network/automata-linux)](https://github.com/automata-network/automata-linux/releases)

Automata Linux is a minimal Confidential VM base image for running atakit
workloads. It provides the guest-side portal, container runtime, attestation
support, and a verified read-only root filesystem used by atakit deployments.

Current release: `automata-linux:v0.2.1-debug`

Release page:

```text
https://github.com/automata-network/automata-linux/releases/tag/v0.2.1-debug
```

## What It Provides

- Minimal Linux guest image for Confidential VM workloads
- Guest portal used by atakit to initialize workloads
- Podman-based container runtime
- TPM-backed attestation support
- UEFI Secure Boot and dm-verity verified root filesystem
- GCP, AWS, Azure, and QEMU image archives

The base image does not expose SSH. Access a deployment through the workload's
declared ports, atakit status commands, and cloud serial output when needed. If
a workload exposes SSH, that SSH server belongs to the workload container, not
to the base image.

## Release Assets

The `v0.2.1-debug` release contains:

- `automata-linux-v0.2.1-debug-all.atabi`
- `automata-linux-v0.2.1-debug-gcp.atabi`
- `automata-linux-v0.2.1-debug-aws.atabi`
- `automata-linux-v0.2.1-debug-azure.atabi`
- `automata-linux-v0.2.1-debug-qemu.atabi`

## Install atakit

Install the public atakit CLI from
[`automata-network/atakit`](https://github.com/automata-network/atakit):

```sh
git clone https://github.com/automata-network/atakit.git
cd atakit
cargo install --path crates/atakit-cli
```

Confirm it is available:

```sh
atakit --help
```

## Configure The Image Repository

Add the public Automata Linux image repository to
`~/.config/atakit/config.toml`:

```toml
[image.repositories]
automata = { repo = "automata-network/automata-linux" }
```

## Pull The Base Image

Pull the GCP archive:

```sh
atakit image pull automata-linux:v0.2.1-debug gcp
```

Pull multiple platform archives:

```sh
atakit image pull automata-linux:v0.2.1-debug gcp,aws,azure,qemu
```

List local images:

```sh
atakit image ls
```

## Use With Workload Examples

The public workload examples are available at
[`melynx/cvm-workload-examples`](https://github.com/melynx/cvm-workload-examples):

```text
https://github.com/melynx/cvm-workload-examples
```

Configure both public repositories:

```toml
[image.repositories]
automata = { repo = "automata-network/automata-linux" }

[workload.repositories]
examples = { type = "github", repo = "melynx/cvm-workload-examples" }
```

Pull an example workload and deploy it with this base image:

```sh
atakit workload pull fedora-oci:v0.0.13 --verify

atakit cloud deploy fedora-oci:v0.0.13 \
  --target <configured-target> \
  --image automata-linux:v0.2.1-debug \
  --name fedora-oci-demo \
  --yes
```

See the workload examples repository for complete deployment guides and
per-example usage.

## Supported Platforms

The release includes archives for:

- `gcp`
- `aws`
- `azure`
- `qemu`

The cloud target and confidential-computing type are selected by your atakit
cloud configuration.

## Cleanup

Destroying a workload deployment removes the VM and workload resources. The
uploaded provider image is reusable and is not removed unless image cleanup is
explicitly requested.
