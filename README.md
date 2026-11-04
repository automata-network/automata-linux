# Automata Linux v0.3.6-debug

This is the debug image. It provides serial diagnostics and a root shell. Anyone with console access can inspect workload data and secrets. Hardware debug mode remains disabled.

Use workload manifest **format 16** and **Atakit CLI v0.7.6**. The CLI is
private and requires repository access. This image rejects formats 14 and 15.

```sh
atakit image pull automata-linux:v0.3.6-debug
```

Combined and per-provider `.atabi` archives cover AWS, Azure, GCP and QEMU.
Each archive has a signed measurement pack bound to its exact SHA-256.
QEMU does not provide hardware attestation. See [release notes](RELEASE_NOTES.md)
for supported machines, CPU controls, open-file limits and known limits.

## Verify downloaded files

Download all 23 release files into an otherwise empty directory. Verify the
signed Git tag through a Git signing identity you trust. Then run:

```sh
sha256sum --check SHA256SUMS
python3 /path/to/checked-out-tag/scripts/verify-release.py /path/to/downloads \
  --publisher-key <independently-trusted-publisher-public-key> \
  --scratch-dir /path/to/private-scratch
```

Obtain the publisher key through an independent trusted channel. A key supplied
with an archive does not establish trust. The script checks the file inventory,
checksums, signatures, archive bindings and release metadata. It does not attest
a running VM.

Successful workload startup does not authorize secret provisioning. Verify
fresh hardware evidence and publisher-signed workload and base-image policies
against trusted measurements before releasing secrets.

[provenance.json](provenance.json) records image build revisions, binary and
archive hashes, and measurement policies. The public tag identifies release
documentation. Image source remains private. Build timestamps normalized to
Unix epoch do not represent the actual build time.
