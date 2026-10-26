# Release completion checks

A release is complete only after these checks pass on the files downloaded
from the published GitHub release.

1. Select the exact tested image archives and original build source revisions.
   Verify archive and disk-content hashes against the accepted test evidence.
   Regenerating an archive can change its bytes; sign the bytes being published.
2. Generate a signed, archive-bound measurement pack for each image archive.
   Verify its key against the independently trusted publisher identity. Compare
   every PCR rule, bank selection, security attribute, profile, and variant with
   the selected chain and accepted measurements. Record the comparison block.
3. Prepare the exact asset inventory in `release-provenance.json`. This release
   family has five archives, fifteen measurement-pack files, release notes,
   provenance, and `SHA256SUMS`: 23 files. The checksum file covers the other 22.
4. Verify packs with the selected released CLI. Reject a modified pack or
   substituted signing key. Run `scripts/verify-release.py` against the complete
   bundle using an independently trusted publisher public key.
5. Update README, release notes, and provenance to the selected image version,
   image identifier, publisher, manifest format, and compatible CLI. Record
   original build commits separately from the public documentation commit.
6. Commit with a verified signature and publish a verified signed tag pointing
   to the reviewed documentation. Preserve published tags unless correcting one
   is explicitly authorized. Disclose any authorized tag change, including its
   old and new commit targets, in the release notice.
7. Publish all reviewed assets. Download every asset into a fresh directory and
   run the verifier again. Check names, sizes, SHA-256 values, release status,
   tag target, signatures, and documentation against the prepared bundle.
8. Report completion only after all checks pass. Record exact test coverage and
   open limitations. Workload startup alone never authorizes secret release.

Check CLI distribution permissions separately. A public image release does not
make a private CLI release public.
