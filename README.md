# Automata Linux

Automata Linux is the public base-image release channel for atakit workloads.
It provides a minimal Confidential VM guest with Portal, a container runtime,
attestation support, and a verified read-only root filesystem.

Current pre-release: [automata-linux:v0.3.1-debug](https://github.com/automata-network/automata-linux/releases/tag/v0.3.1-debug).

The `debug` release name does not disable verification. The bundled Portal was
built with the production profile, and measurement checks remain enforced.

## Highlights

- Operator-selected initialization authentication using a provisioned public key.
- Per-disk passphrase delivery on first boot and reboot through the same API.
- Explicit permission for disk formatting and overwrite.
- GCP boot policies allow a dynamic writable partition while checking the
  remaining selected boot events.
- AWS session-key preservation during TPM access and corrected verification
  after key rotation.
- Registration and lifecycle retries when another operation advances the
  same owner's operation counter.

## Known Azure SEV-SNP limitation

Some Azure SEV-SNP deployments have different firmware and boot measurements
from the published profile. They fail PCR 0 and PCR 2 verification before
initialization. Both checks remain enforced. The rejected deployment in the
release rehearsal did not complete its workload and reboot tests; this is an
accepted deployment limitation, not a passing result for that boot variant.

## Release assets

The release includes `automata-linux-v0.3.1-debug-{all,gcp,aws,azure,qemu}.atabi`,
a signed measurement pack (`.json`, `.sig`, and `.pubkey`), `SHA256SUMS`, its
signature, and source/artifact provenance. Verify the checksums and signatures
against a publisher or signing key you trust independently.

The base-image identity is
`0xdc22f0710de7d5da51dca3a3e1ad39d63f0bf00289b4f0562b041dc204baf5df`.

The rehearsal used a controlled Hoodi fork. GitHub asset publication does not
register this identity on a public network or update public-network policy.
Use the signed measurement pack for offline verification, or ensure your
selected chain has the required image and workload records.

## Use with atakit

Use a compatible CLI supporting ATAWL format 8 and the per-boot disk-unlock API.
The release was tested with CLI version 0.6.0; provenance records its exact source.

Configure the image repository:

```toml
[image.repositories]
automata = { repo = "automata-network/automata-linux" }
```

```sh
atakit image pull automata-linux:v0.3.1-debug gcp
atakit image ls
```

Choose a workload whose measured policy permits this publisher-qualified image.
Cloud account, machine type, attestation authority, and chain settings must
match your deployment. The measured cloud variants in this release are:

| Platform | Machine type |
|---|---|
| GCP TDX | c3-standard-4 |
| GCP SEV-SNP | n2d-standard-4 |
| Azure TDX | Standard_DC2es_v6 |
| Azure SEV-SNP | Standard_DC2as_v5 |
| AWS SEV-SNP | m6a.large |

The base image does not expose host SSH. Use Portal status and cloud serial
output for host diagnosis. A workload may expose its own SSH service.

Use `atakit cloud destroy` for deployment cleanup. Reusable provider images
are preserved unless image deletion is explicitly requested.
