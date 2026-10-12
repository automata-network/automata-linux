# Automata Linux

Automata Linux is the public base-image release channel for atakit workloads.
It provides a minimal Confidential VM guest with Portal, a container runtime,
attestation support, and a verified read-only root filesystem.

Current prerelease: [automata-linux:v0.3.4-debug](https://github.com/automata-network/automata-linux/releases/tag/v0.3.4-debug).
Use atakit CLI **0.7.3** with this release.

This is a debug image. Its test results do not establish sealed-platform
compliance. See [release notes](RELEASE_NOTES.md) for behavior and test coverage.

## Highlights

- Workload manifest format 14 defines explicit `read`, `write`, and `execute`
  access for workload, dependency, and baby-container storage mounts.
- Baby `parent-access` limits access through overlapping parent mounts and
  defaults to no parent access.
- Disk-based Python virtual environments, native extensions, and saved data
  passed tests across VM reboots.
- Portal accepts compiled workload formats 11–14. Earlier formats keep their
  existing storage fields and behavior.
- Both observed Azure SEV-SNP firmware variants have fresh boot measurements.
  Unknown measurement variants still fail verification.

## Release assets

The release includes four image archives:

- `automata-linux-v0.3.4-debug-aws-azure-gcp.atabi`
- `automata-linux-v0.3.4-debug-aws.atabi`
- `automata-linux-v0.3.4-debug-azure.atabi`
- `automata-linux-v0.3.4-debug-gcp.atabi`

Each archive has a corresponding signed measurement pack (`.json`, `.sig`,
and `.pubkey`). The release also includes `SHA256SUMS`, `RELEASE-NOTES.md`,
and `measurement-provenance.json`. Verify the archive checksums and measurement
pack signatures using a publisher key you trust independently.

The base-image identity is
`0x0968613bd4f33a5f5eb32e857f6c99299d03ee83d73b47f2f2434c8b01fd6bad`.

The release's image policies were published on public Hoodi: five platform
profiles and thirteen measurement variants. Workload policy must also permit
this image when using registry-based verification.

[provenance.json](provenance.json) is an exact copy of the published
`measurement-provenance.json` asset. It records source commits, artifact hashes,
and which measurement rules came from fresh boots or prior validated evidence.
The files in this branch describe the release; image binaries are release assets.

## Use with atakit

Configure the image repository:

```toml
[image.repositories]
automata = { repo = "automata-network/automata-linux" }
```

```sh
atakit image pull automata-linux:v0.3.4-debug gcp
atakit image ls
```

Choose a workload whose policy permits this publisher-qualified image.
Cloud account, machine type, attestation authority, and chain settings must
match your deployment.

## Measurement and test coverage

| Platform | Fresh v0.3.4-debug boot measurements | Additional published variants using prior evidence |
|---|---|---|
| GCP TDX | `c3-standard-4` | `c3-standard-8`, `c3-standard-22`, `c3-standard-44`, `c3-standard-88`, `c3-standard-176` |
| GCP SEV-SNP | `n2d-standard-4` | None |
| Azure TDX | `Standard_DC2es_v6` | None |
| Azure SEV-SNP | Both observed `Standard_DC2as_v5` firmware variants | None |
| AWS SEV-SNP | `m6a.large` | `m6a.xlarge`, `m6a.2xlarge` |

The additional GCP sizes use previously verified equal measurement rules.
The additional AWS sizes retain their separately measured PCR 0 firmware rules.
All image-dependent rules come from fresh v0.3.4-debug measurements. The
additional sizes were not booted in this release campaign.

Functional storage and reboot tests passed on all five platforms. GCP TDX and
SEV-SNP also passed required registration and independent session verification
on `hoodi-fork`. AWS and Azure used registration off with attested TLS
verification. The Azure SEV-SNP functional test used the `f303` firmware variant;
both firmware variants received fresh boot-measurement coverage.

Use Portal status and cloud serial output for host diagnosis. A workload may
expose its own SSH service. Use `atakit cloud destroy` for deployment cleanup.
Reusable provider images are preserved unless image deletion is explicitly
requested.
