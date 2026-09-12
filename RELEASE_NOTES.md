# Automata Linux v0.3.1-debug

This pre-release adds operator-selected initialization authentication, per-boot
disk unlock, explicit disk-formatting permission, and session-verification fixes.
Portal uses the production build profile. The `debug` name does not bypass
attestation or measurement checks.

## Changes

- Authenticated initialization by default in `cloud deploy`; operators can
  select `--unauthenticated-init`. Portal enforces a provisioned public key.
- A single per-disk unlock API on port 2024 for first boot and reboot. Disk
  passphrases are not stored in initialization configuration.
- Explicit `--disk-setup` permissions and `--overwrite-all-disks` for workload
  disks. Overwrite permission is not replayed after reboot.
- GCP TDX and SEV-SNP boot policies skip only the dynamic GPT digest at its
  reviewed event position, retaining other selected boot-event checks.
- AWS TPM signing keys survive TLS-attestation device handoff. Off-chain
  verification checks retained provider evidence correctly after key rotation.
- Registration and lifecycle operations rebuild evidence only after confirming
  that the owner's operation counter advanced.
- Bounded measurement-read retries before disk unlock, deployment JSON output,
  early prover-configuration checks, streamed remote ATAWL delivery, and
  deterministic workload dependency startup.

Use a compatible CLI supporting ATAWL format 8 and the per-boot unlock API.
The tested CLI reports version 0.6.0; `provenance.json` identifies exact sources.

## Accepted Azure SEV-SNP limitation

Some Azure SEV-SNP deployments have different firmware and boot measurements
from the published profile and fail PCR 0/PCR 2 verification before initialization.
Both checks remain enforced. The final rehearsal passed six of seven cloud
disk/reboot rows; the rejected Azure SEV-SNP deployment did not complete its
workload and reboot checks. This known deployment limitation was accepted for
the pre-release. It is not a passing result for the rejected boot variant.

The other workload, lifecycle, remote-log, and rebuilt verifier/dashboard checks
passed. Test VMs were removed and reusable provider images preserved. QEMU is
packaged but no QEMU end-to-end pass is claimed by this cloud rehearsal.

## Assets and verification

Five image archives are supplied: all platforms, GCP, AWS, Azure, and QEMU.
The signed measurement pack binds the all-platform archive SHA-256. Its
`.pubkey` must match a publisher key you trust independently.

`SHA256SUMS` covers the image archives, measurement pack files, provenance, and
release metadata. `SHA256SUMS.sig` is an SSH signature in namespace `file`.
The release signer fingerprint is
`SHA256:mhFRHkeVuncPB5PIKf0zO+FmFtekbtxnP1qn2TXOQLA`.
Trust the signer independently before using the supplied public key:

```sh
ssh-keygen -Y verify -f /path/to/trusted_allowed_signers \
  -I melynx@gmail.com -n file -s SHA256SUMS.sig < SHA256SUMS
sha256sum --check SHA256SUMS
```

The rehearsal ran on a controlled Hoodi fork. This GitHub release does not
register the image or workloads on public Hoodi or alter public-network policy.
Use the signed measurement pack offline, or configure a chain with the required
image, workload, and verifier records.
