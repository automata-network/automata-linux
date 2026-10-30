# Automata Linux

Automata Linux is the public base-image release channel for Atakit workloads.
Current release: [automata-linux:v0.3.5](https://github.com/automata-network/automata-linux/releases/tag/v0.3.5).

v0.3.5 is a **non-debug** image with a verified read-only root filesystem,
Portal, confidential-VM attestation support, and container runtimes. It uses
kernel `7.2.12-automata-splicefix`, disables its configured serial console,
and sets Atakit system logging to `off`. It provides no host SSH service.
Workload-authorized services may expose their own interfaces and export logs.

Use **atakit CLI v0.7.4 or later with format 15 support**. v0.3.5 requires
workload manifest format **15** and rejects older manifests. The CLI release
is private; repository access is required to download its binaries.

C4 deployment requires a CLI build with C4 target support; released CLI v0.7.4 does not accept C4 targets.

## Identity and supported platforms

- Publisher fingerprint: `0xaef8fc89416f01494ec6534de68d30aab26d7598db8a05967b0ba7d3ecb259d2`.
- Base-image ID: `0x84653d0c72d636af1b339ecc24011088690b6398d32c113a639d13137d9cc7b8`.
- Registered on public Hoodi, chain ID `560048`.

| Platform | Supported machines |
| --- | --- |
| AWS SEV-SNP | `m6a.large`, `m6a.xlarge`, `m6a.2xlarge`, `m6a.4xlarge`, `m6a.8xlarge`, `c6a.large`, `c6a.xlarge`, `c6a.2xlarge`, `c6a.4xlarge`, `c6a.8xlarge`, `c6a.12xlarge`, `c6a.16xlarge` |
| Azure SEV-SNP | `Standard_DC2as_v5`, two firmware variants |
| Azure TDX | `Standard_DC2es_v6` |
| GCP SEV-SNP | `n2d-standard-4` |
| GCP TDX | `c3-standard-4`, `c3-standard-8`, `c3-standard-22`, `c3-standard-44`, `c3-standard-88`, `c3-standard-176`, `c4-standard-2`, `c4-standard-4`, `c4-standard-8`, `c4-standard-16`, `c4-standard-24`, `c4-standard-32`, `c4-standard-48`, `c4-standard-96`, `c4-standard-144`, `c4-standard-192` |

Exact variant names and policies are in the signed measurement packs. QEMU is
included for local emulation and provides no hardware attestation.

## Download and verify

The release provides five archives (`all`, `aws`, `azure`, `gcp`, `qemu`), a
signed measurement pack for each archive, release notes, provenance, and a
checksum file: **23 files** in total. Each pack binds the archive hash to the
publisher's signature and includes the same five hardware profiles.

Download all release files into an empty directory. Set `trusted_publisher_key`
to a publisher public key obtained through a source you trust independently.
Do not establish trust from a `.pubkey` file downloaded beside the archive.
Verify the signed `v0.3.5` Git tag using a Git signing identity you trust,
then run the verifier from that tag's checkout (Python 3.11+ and OpenSSL):

```sh
python3 scripts/verify-release.py /path/to/downloaded-assets \
  --publisher-key "$trusted_publisher_key"
```

Configure a compatible CLI with this image repository:

```toml
[image.repositories]
automata = { repo = "automata-network/automata-linux" }
```

```sh
atakit image pull automata-linux:v0.3.5 gcp
atakit image ls
```

Choose a signed workload whose measured policy permits this publisher-qualified
base image. Successful startup alone is **not verified hardware evidence or
authorization to release secrets**. A provisioner must independently verify
fresh hardware evidence and signed policies against trusted measurements.

See [release notes](RELEASE_NOTES.md) for features and limitations,
[provenance](provenance.json) for original build revisions and hashes.
The public release tag identifies documentation; the provenance records the
private image build sources separately.
