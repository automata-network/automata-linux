# automata-linux v0.3.4-debug

Adds workload manifest format 14 storage access lists. Use CLI 0.7.3.

## Storage access lists (format 14)

Source and compiled format 14 replace `read-only` / `read_only`, `executable`,
and baby `permissions` with explicit access lists. CLI 0.7.3 builds this format;
automata-linux v0.3.4-debug implements it. Existing formats 11–13 retain their
original fields and behavior. A new Portal accepts compiled formats 11–14.

```toml
format = 14

[workload.storage.app]
disk = "data"
base-path = "/app"
mount-path = "/root/app"
access = ["read", "write", "execute"]

[baby-container.slots.dev.storage.app]
disk = "baby-data"
base-path = "/app"
mount-path = "/root/app"
scope = "instance"
retention = "disk"
access = ["read", "write", "execute"]
parent-access = []
```

`access` is required for every workload, dependency and baby storage mount.
Only `read`, `write`, and `execute` are accepted. `read` is required; unknown,
duplicate, empty or write-only/execute-only lists are rejected. `write` permits
writes through this mount; its absence makes the mount read-only. `execute`
permits executable mappings through this mount; its absence applies `noexec`.
Unix ownership and file modes still apply. `nosuid` and `nodev` always remain.
Reading a script and passing its contents to an interpreter is not prevented by
`noexec`; these are mount rights, not a guarantee that mutable code cannot run.

Baby `parent-access` defaults to `[]` (no parent access). A nonempty list must
include `read`. It limits separately declared overlapping storage mounts of the
owning parent service; it does not create a parent mount. Such mounts must not
exceed the grant in read, write or execute rights. Baby creation requests cannot
override either list. Storage scope, retention, paths, quotas, encryption and
lifecycle policies are unchanged.

Format 14 rejects the old fields even if explicitly set to false. Earlier
formats reject the new fields. The builder sorts both lists in read/write/execute
order before measuring the manifest, so list ordering does not alter PCR23.
Compiled JSON uses `access` and `parent_access`; it omits the old fields.
An omitted source `parent-access` becomes an explicit empty compiled list.


Cloud acceptance passed on GCP TDX, GCP SEV-SNP, AWS SEV-SNP, Azure TDX and
Azure SEV-SNP. Tests covered workload, dependency and baby storage mounts;
disk-based Python virtual environments and NumPy native extensions; executable
and non-executable mounts; read-only mounts; restricted parent sharing; and
saved data after VM reboot. `nosuid` and `nodev` remained enforced.

GCP TDX and SEV-SNP also passed required on-chain registration and independent
session verification before and after reboot on `hoodi-fork`. AWS and Azure
used registration off with attested TLS verification. Both Azure SEV-SNP
firmware variants received fresh boot-measurement coverage; the functional
workload test completed on the `f303` firmware variant.

This is a debug image. These tests do not establish sealed-platform compliance.

## Measurement coverage

Fresh boots covered c3-standard-4, n2d-standard-4, m6a.large, Standard_DC2es_v6 and both Standard_DC2as_v5 firmware variants. Five additional regular C3 sizes use previously verified equal measurement rules. AWS m6a.xlarge and m6a.2xlarge retain their separately measured PCR0 firmware values from the previous release. All image-dependent rules come from fresh v0.3.4-debug measurements. These additional machine sizes were not booted in this campaign.
