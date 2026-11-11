# Automata Linux v0.3.7

Release notes for the v0.3.7 normal image and v0.3.7-debug image. Use Atakit CLI
0.7.7. Both images accept workload manifest format 16 only.

## Unmeasured-data updates

The instance owner can replace a workload's unmeasured-data folder while keeping
the VM and disks. Supply a complete local folder with the same layout used at
deployment. Files missing from the replacement disappear after the next VM
reboot. Services continue to receive read-only views.

Deployment and update share file and environment-variable validation. The CLI
ignores undeclared local files; Portal rejects undeclared uploaded files. Preview
checks the local folder against the verified workload manifest. The API reveals
no stored values, content IDs or changed/unchanged comparison.


## Cloud disks

Operators can select a reusable creation profile per workload disk and for the
boot disk. Cloud-specific disk type names identify the provider. Supported
profiles cover AWS gp3, GCP Persistent Disk, GCP Hyperdisk Balanced and supported
GCP C3 Local SSD targets. Azure retains its existing disk creation settings.
Editing a profile does not modify an existing disk.

Newly created, verified empty workload disks initialize automatically. Existing
disks retain the explicit initialization checks. Cleanup records completed steps,
continues independent cleanup after failures, and reports retained resources.
GCP cleanup also recovers a boot disk after interrupted VM creation.

GCP Local SSD devices can form one workload disk. Multiple devices use RAID 0
before the existing filesystem and encryption setup. Local SSD data is temporary,
and RAID 0 provides no redundancy. Device discovery retains the GCP metadata checks.

LUKS keeps AES-256-XTS. Owners may select encryption workqueue `bypass` per data
disk; the default remains `default`. Queue choices activate on the next VM reboot.


## Runtime settings and kernel

CPU settings, disk queue choices and transparent huge pages (THP) now use the same
configuration flow and the existing `runtime-cpu.json` file. Omitted scopes keep
their saved choices. `--check` validates without saving; `--reset` clears owner
choices across all three scopes, while publisher-fixed CPU limits still apply.

Linux is `7.3.4-automata-v037`. The module-signature, splice and haltpoll patches
remain included. The haltpoll governor honors disabled idle states and requires
the kernel capability check. CPU permissions remain part of the signed workload.

THP is disabled by default. Owners can opt into `madvise`, allowing applications
to request large anonymous pages. Portal applies and checks the fixed THP policy
before starting containers. THP and disk queues activate on VM reboot; CPU
choices activate at full workload startup. Performance depends on the workload.


## Reliability and image behavior

`atakit cloud verify-session` resolves the current cloud IP and checks the saved
VM identity. Verification continues to work after a stop/start changes the IP.

Container log reads handle incomplete records and NUL gaps after a crash, with
bounded reads and warnings for discarded data. Cancelling an API caller no longer
leaves its supervisor reply for a later caller to consume.

Shutdown stops containers and confirms the worker process group is empty before
the final sync and poweroff. Normal and debug images use the same shutdown helper.

The normal image keeps the guest console and Portal diagnostics disabled. The
debug image exposes a serial root shell and diagnostics. Console access can reveal
workload data and secrets; use the debug image for debugging only.

Verify image publisher signatures and measurements before supplying secrets.
Normal and debug images have separate identities and measurement packs.

## Measurement coverage

The signed profiles contain 34 machine variants across five hardware profiles. Some machine sizes share measurement rules with a measured representative; this does not claim a separate runtime test of every size.

| Hardware profile | Included machine variants |
| --- | --- |
| aws-sev-snp | `c6a.12xlarge`, `c6a.16xlarge`, `c6a.2xlarge`, `c6a.4xlarge`, `c6a.8xlarge`, `c6a.large`, `c6a.xlarge`, `m6a.2xlarge`, `m6a.4xlarge`, `m6a.8xlarge`, `m6a.large`, `m6a.xlarge` |
| azure-sev-snp | `Standard_DC2as_v5@firmware-5f6d23087f48a6b7e90ba879f5a7de06590630ac09c78a4106458a5e125a1993`, `Standard_DC2as_v5@firmware-f3030fc3d76d09ef2e7e51fd04c27bedf38d46ea430409e119a834fe5a361c7b` |
| azure-tdx | `Standard_DC2es_v6` |
| gcp-sev-snp | `n2d-standard-4` |
| gcp-tdx | `c3-standard-176`, `c3-standard-22`, `c3-standard-4`, `c3-standard-4-lssd`, `c3-standard-44`, `c3-standard-44-lssd`, `c3-standard-8`, `c3-standard-88`, `c4-standard-144`, `c4-standard-16`, `c4-standard-192`, `c4-standard-2`, `c4-standard-24`, `c4-standard-32`, `c4-standard-4`, `c4-standard-48`, `c4-standard-8`, `c4-standard-96` |

`provenance.json` identifies measured representatives and derived size variants. The Local SSD entries cover only `c3-standard-4-lssd` and `c3-standard-44-lssd`. QEMU has an archive but no hardware-attestation profile in this release.
