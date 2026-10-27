# Automata Linux v0.3.5-debug

This debug release uses the same kernel, Portal and prover as v0.3.5. It enables
serial boot output, Portal diagnostics and a root shell. An operator with serial
access can inspect workload data and secrets. Use the non-debug v0.3.5 image for
production secrets.

The kernel is 7.2.12-automata-splicefix. Workloads must use manifest format 15;
format 14 is rejected before startup. Use Atakit CLI 0.7.4 or a compatible later
version. The CLI release remains private.

The image includes publisher-signed workload and base-image policy checks,
Azure SEV-SNP minimum TCB values selected by signed CPUID, baby-container
stdout/stderr handling, explicit signed log-access policy, encrypted persistent
baby roots, and the updated certificate bundle.

Image ID: `0x446fb3f67743277dd21a92f5d6ff6dedb7668ed198a0fc384178c9c39e70cf6f`.
Publisher fingerprint: `0xaef8fc89416f01494ec6534de68d30aab26d7598db8a05967b0ba7d3ecb259d2`.

## Verified platforms

| Profile | Variants |
| --- | --- |
| aws-sev-snp | `m6a.2xlarge`, `m6a.large`, `m6a.xlarge` |
| azure-sev-snp | `Standard_DC2as_v5@firmware-5f6d23087f48a6b7e90ba879f5a7de06590630ac09c78a4106458a5e125a1993`, `Standard_DC2as_v5@firmware-f3030fc3d76d09ef2e7e51fd04c27bedf38d46ea430409e119a834fe5a361c7b` |
| azure-tdx | `Standard_DC2es_v6` |
| gcp-sev-snp | `n2d-standard-4` |
| gcp-tdx | `c3-standard-176`, `c3-standard-22`, `c3-standard-4`, `c3-standard-44`, `c3-standard-8`, `c3-standard-88` |

All 13 machine/firmware rows have three fresh measurement samples: first boot,
same-VM reboot and a separate VM. Strict profile generation passed. Every row
also passed independent first-boot and reboot hardware/session verification on
the controlled fork. Public Hoodi checks are recorded in release-provenance.json.

The exact image passed baby SSH/SFTP, package installation, Go and Python
execution, parent network blocking/restoration, signed parent and sidecar log
access, stdout/stderr capture, and persistence after stop/start and VM reboot.
Serial-shell commands ran as UID 0, as intended. A workload restricted to the
non-debug image rejected this debug image. All campaign VMs were removed.

## Release files and verification

The release has five .atabi archives, one signed measurement-pack triple per
archive, these notes, release-provenance.json and SHA256SUMS: 23 files in total.
Each pack signs its archive hash and the full five-profile measurement set.
The QEMU archive has no hardware-attestation claim.

Verify the files with scripts/verify-release.py from this signed tag and an
independently trusted publisher public key. See README.md for the command.
The public tag identifies release documentation. Private image source and
component revisions are listed separately in release-provenance.json.

Successful startup alone is not verification or permission to release secrets.
A provisioner must verify fresh hardware evidence and publisher-signed policies
using an independently trusted measurement source. The default /tmp is
non-executable; Go tools in a baby container need a writable private TMPDIR.
Concurrent registrations under one owner can hit a registration-counter race
and stop startup. The affected test was repeated with registrations serialized;
this image does not fix that retry gap.
The private prover's known GPU page-fault issue remains unresolved; this image
release does not claim to fix it.
