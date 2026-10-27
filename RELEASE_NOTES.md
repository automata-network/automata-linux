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

## Supported hardware profiles

| Profile | Variants |
| --- | --- |
| aws-sev-snp | `m6a.2xlarge`, `m6a.large`, `m6a.xlarge` |
| azure-sev-snp | `Standard_DC2as_v5@firmware-5f6d23087f48a6b7e90ba879f5a7de06590630ac09c78a4106458a5e125a1993`, `Standard_DC2as_v5@firmware-f3030fc3d76d09ef2e7e51fd04c27bedf38d46ea430409e119a834fe5a361c7b` |
| azure-tdx | `Standard_DC2es_v6` |
| gcp-sev-snp | `n2d-standard-4` |
| gcp-tdx | `c3-standard-176`, `c3-standard-22`, `c3-standard-4`, `c3-standard-44`, `c3-standard-8`, `c3-standard-88` |

Exact firmware variants, PCR policies, and security attributes are included
in the signed measurement packs. Baby containers support package installation,
program execution, persistent private storage, and parent-controlled network
access. The signed workload policy controls parent and sidecar access to logs.

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

## Known limitations

- Concurrent session registrations using the same owner can fail during startup. Run registrations sequentially until this issue is resolved.
- Azure firmware can vary by placement. Only firmware covered by the published signed measurements is supported.
- QEMU provides local emulation without hardware attestation.
