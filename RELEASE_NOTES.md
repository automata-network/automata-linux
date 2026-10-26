# Automata Linux v0.3.5

Non-debug confidential VM base image. This release requires workload manifest
format **15** and **atakit CLI v0.7.4 or later with format 15 support**. The CLI
release remains private and requires repository access.

## Release identity

- Publisher fingerprint: `0xaef8fc89416f01494ec6534de68d30aab26d7598db8a05967b0ba7d3ecb259d2`.
- Base-image ID: `0x84653d0c72d636af1b339ecc24011088690b6398d32c113a639d13137d9cc7b8`.
- Public registry: Hoodi, chain ID `560048`, BaseImageRegistry `0x6b837e4Cc2A7BDaA1d938CEE7fa0b82458dA0b14`.
- Image registration transaction: `0x114f602a270221b674d155266786a7be27bec6b759ad67079b0eef11775c6670`.
- Kernel: `7.2.12-automata-splicefix`. Portal build profile: `production`.
- Exact original build source revisions and recorded binary hashes are in `release-provenance.json`.

## Supported hardware profiles

| Profile | Supported variants |
| --- | --- |
| AWS SEV-SNP | `m6a.large`, `m6a.xlarge`, `m6a.2xlarge` |
| Azure SEV-SNP | `Standard_DC2as_v5`, with two separately signed firmware variants |
| Azure TDX | `Standard_DC2es_v6` |
| GCP SEV-SNP | `n2d-standard-4` |
| GCP TDX | `c3-standard-4`, `c3-standard-8`, `c3-standard-22`, `c3-standard-44`, `c3-standard-88`, `c3-standard-176` |

The exact variant names, PCR policies, and security attributes are in the signed
measurement packs. Azure SEV-SNP uses CPUID-specific minimum TCB values for
`0x190101` and `0x191101`. Each pack describes the same five profiles and thirteen
variants and binds them to its specific archive SHA-256. The QEMU archive is
for local emulation; signing its hash does not provide hardware attestation.

## Security and workload behavior

- This is the non-debug image. Its kernel command line uses `console=null`,
  and Atakit system logging is `off`. It provides no host SSH service.
- Format 15 makes baby-container log access explicit in the signed workload
  policy. A permitted logging sidecar can read workload logs; log export
  requires a workload that grants the corresponding access.
- Baby-container private roots support package installation, program execution,
  and persistence when the signed policy selects persistent storage. Host `/tmp`
  is non-executable; use `TMPDIR` in the baby's private writable root for Go.
- Successful workload startup does **not** authorize secret release. Before
  provisioning secrets, independently verify fresh hardware evidence and the
  publisher-signed image/workload policies against trusted measurements. Trust
  the measurement publisher independently of the machine requesting secrets.

## Validation and limits

All thirteen hardware variants passed current-image first-boot and reboot
canaries against the controlled Hoodi fork, including independent hardware and
session verification. Fresh representative measurements were combined with
previously measured variant rules; every copied variant passed a current-image
canary. This was not three new measurement samples for every machine size.

On public Hoodi, GCP TDX `c3-standard-8` passed 57 independent checks per boot.
Azure SEV-SNP `Standard_DC2as_v5`, CPUID `0x191101`, passed 61 per boot with
report version 5, TCB `0x581c000c`, and launch/current mitigation vectors `0x7`.
Both public canaries registered distinct sessions after reboot.

Exact-image GCP tests also covered baby SSH/SFTP, package installation, Go
run/build, Python environments, signed parent/sidecar log access including
stdout and stderr, parent network allow/block, stop/start, and reboot
persistence. QEMU runtime validation is not claimed by this cloud campaign.

The private ROCm prover previously crashed with AMD GPU page faults. Subsequent
canaries passed after a host reboot, and dead-worker detection was deployed.
The underlying GPU fault remains unresolved. Future Azure firmware may differ
from the two published variants and require new publisher-approved policy.

## Download and verify

The release has 23 files: five `.atabi` archives, fifteen measurement-pack
JSON/signature/public-key files, `RELEASE-NOTES.md`, `release-provenance.json`,
and `SHA256SUMS`. The checksum file covers the other 22 files.

Download all 23 release files into an empty directory. Obtain the publisher
public key through a source you trust independently. The supplied `.pubkey`
files are copies for convenience and do not establish that trust. From the
public repository, verify the signed `v0.3.5` tag using a Git signing identity
you trust, then run from that tag's checkout:

```sh
python3 scripts/verify-release.py /path/to/downloaded-assets \
  --publisher-key "$trusted_publisher_key"
```

The script requires Python 3.11+ and OpenSSL. It verifies the exact file list,
checksums, detached secp256k1/SHA-256 signatures, archive bindings, profile consistency, and agreement with the checked-out
release documentation. This file verification does not attest a running machine. CLI
v0.7.4 can also consume the packs through `atakit trust-pack build workload`.

| Archive | SHA-256 |
| --- | --- |
| `automata-linux-v0.3.5-all.atabi` | `3099c07ea9916c6d45599e0f6b0062b4582330a4179a05b8c63a0ca8ec12ed97` |
| `automata-linux-v0.3.5-aws.atabi` | `695b8587701ce20522173b35e666c4ee953291691cedfc71f6a728bfa82fe749` |
| `automata-linux-v0.3.5-azure.atabi` | `6ccac60226120a5cf5a5de0364fb1a636639ba98a49b9ff7424561e545d89054` |
| `automata-linux-v0.3.5-gcp.atabi` | `98986b47ec19b5008175c6f71b430dd3b59b6267aa640bd84b5557e0332ccea3` |
| `automata-linux-v0.3.5-qemu.atabi` | `f148f24edb30ae5cc14d383c54a485575d5a8c8a810c3dc5dff8eb4a97757381` |

To pull the GCP image using a compatible CLI:

```sh
atakit image pull automata-linux:v0.3.5 gcp
```

## Release correction — 2026-10-27

The initial 2026-10-26 publication contained the five image archives only.
This correction adds the signed measurement files, provenance, checksum file,
and standalone notes. The image archives retain their original bytes and hashes.
The base-image ID above corrects a typo in the original release description.

The original `v0.3.5` tag pointed to
`e3d79496c5fd0022d055e3227a126927efff0b27`, whose README and provenance described
v0.3.1-debug. The corrected signed tag identifies the v0.3.5 release-documentation
commit. Its exact target is recorded in the GitHub release correction notice.
That documentation commit is separate from the original image build sources,
which are listed in the provenance file. Earlier release tags are unchanged.
