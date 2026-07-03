# Automata Linux

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![GitHub Release](https://img.shields.io/github/v/release/automata-network/automata-linux)](https://github.com/automata-network/automata-linux/releases)

Automata Linux is the public base-image release channel for atakit workloads.
It provides minimal Confidential VM guest images with the portal, container
runtime, attestation support, and verified root filesystem required by atakit
deployments.

Current release: `automata-linux:v0.2.4-debug`

Release page:

```text
https://github.com/automata-network/automata-linux/releases/tag/v0.2.4-debug
```

Hoodi base image ID:

```text
0xc1beb88ace5e6ed3d617779e5c77fe89777387b578c92f9a60ae18edc217beb2
```

## What This Repository Contains

This repository is intentionally small. It hosts public release metadata and
GitHub release assets for Automata Linux images. The release assets are pulled
by the atakit CLI; the repository is not an atakit source tree and does not
build or package the atakit CLI.

The base image does not expose SSH. Access a deployment through the workload's
declared ports, atakit status commands, and cloud serial output when needed. If
a workload exposes SSH, that SSH server belongs to the workload container, not
to the base image.

## Release Assets

The `v0.2.4-debug` release contains:

- `automata-linux-v0.2.4-debug-all.atabi`
- `automata-linux-v0.2.4-debug-gcp.atabi`
- `automata-linux-v0.2.4-debug-aws.atabi`
- `automata-linux-v0.2.4-debug-azure.atabi`
- `automata-linux-v0.2.4-debug-qemu.atabi`

This release includes the rootlessport upload splice fix. The kernel release
string inside the guest is `7.0.6-automata-splicefix`.

Supported platforms:

- `gcp`
- `aws`
- `azure`
- `qemu`

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
atakit image pull automata-linux:v0.2.4-debug gcp
```

Pull multiple platform archives:

```sh
atakit image pull automata-linux:v0.2.4-debug gcp,aws,azure,qemu
```

List local images:

```sh
atakit image ls
```

## Use With Workload Examples

The public workload examples are available at
[`melynx/cvm-workload-examples`](https://github.com/melynx/cvm-workload-examples):

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
  --image automata-linux:v0.2.4-debug \
  --name fedora-oci-demo \
  --yes
```

See the workload examples repository for complete deployment guides and
per-example usage.

## Published Measurement Profiles

The cloud target and confidential-computing type are selected by your atakit
cloud configuration.

| Platform | Variants |
|----------|----------|
| `gcp-tdx` | `c3-standard-4`, `c3-standard-8`, `c3-standard-22`, `c3-standard-44` |
| `gcp-sev-snp` | `n2d-standard-2`, `n2d-standard-4`, `n2d-standard-8`, `n2d-standard-16` |
| `azure-tdx` | `Standard_DC2es_v6`, `Standard_DC4es_v6`, `Standard_DC8es_v6`, `Standard_DC16es_v6` |
| `azure-sev-snp` | `Standard_DC2as_v5`, `Standard_DC4as_v5`, `Standard_DC8as_v5`, `Standard_DC16as_v5` |

## Cleanup

Destroying a workload deployment removes the VM and workload resources. The
uploaded provider image is reusable and is not removed unless image cleanup is
explicitly requested.
