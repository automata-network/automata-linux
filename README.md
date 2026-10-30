# Automata Linux

The latest stable image is [v0.3.5](https://github.com/automata-network/automata-linux/releases/tag/v0.3.5).
This tag documents the [v0.3.5-debug development image](https://github.com/automata-network/automata-linux/releases/tag/v0.3.5-debug).

The debug image has serial diagnostics and a root shell. Anyone with console
access can inspect workload data and secrets. Use the non-debug image for
production secrets. Hardware debug mode remains disabled; the serial shell is
an image feature. Portal's `production` build-profile label describes the
binary build and does not make the debug image a non-debug image.

Use workload manifest format 15 and Atakit CLI 0.7.4 or a compatible later
version. The CLI release is private and requires repository access.

```sh
atakit image pull automata-linux:v0.3.5-debug
```

The release provides combined and per-provider .atabi archives for AWS, Azure,
GCP and QEMU. Each archive has an archive-bound signed measurement pack. QEMU
does not provide hardware attestation. See [release notes](RELEASE_NOTES.md)
for supported machines, features and limitations.

C4 deployment requires a CLI build with C4 target support; released CLI v0.7.4 does not accept C4 targets.

## Verify downloaded files

Download all 23 release files into an otherwise empty directory. Verify the
signed Git tag and its documentation through a trusted Git signing identity.
Then run:

```sh
sha256sum --check SHA256SUMS
python3 /path/to/checked-out-tag/scripts/verify-release.py /path/to/downloads \
  --publisher-key <independently-trusted-publisher-public-key> \
  --scratch-dir /path/to/private-scratch
```

The publisher fingerprint is `0xaef8fc89416f01494ec6534de68d30aab26d7598db8a05967b0ba7d3ecb259d2`.
The image ID is `0x446fb3f67743277dd21a92f5d6ff6dedb7668ed198a0fc384178c9c39e70cf6f`.
Obtain the publisher key through an independent trusted channel. A key supplied
beside an archive does not establish trust by itself. The verifier checks file
inventory, checksums, signatures, archive bindings and signed documentation.
It does not attest a running VM.

Successful workload startup does not authorize secret provisioning. Before
releasing secrets, independently verify fresh hardware evidence and the
publisher-signed workload and base-image policies against a trusted measurement
source. The debug image deliberately gives its operator a serial root shell.

[provenance.json](provenance.json) records image build revisions, binary and
archive hashes and measurement policies. The public tag records release
documentation, not the private image source. Build timestamps normalized to
Unix epoch do not represent the actual build time.
