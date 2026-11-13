# Automata Linux v0.3.8

Use Atakit CLI 0.7.8. Workloads require manifest format 16.

- Large unmeasured-data files stream through CLI archive creation, upload, Portal extraction and stored-data checks. The CLI keeps its archive on disk; Portal uses the existing boot partition. Owner signatures, read-only service views and activation after reboot remain in force.
- Adds AWS io2 and Azure Premium SSD v2, Ultra Disk and local SSD groups. Multiple local SSDs form RAID 0 before the existing encryption and filesystem setup. Local storage is temporary and RAID 0 has no redundancy.
- Older deployment cleanup asks before deleting disks without saved creation IDs. The `--yes` flag does not approve those disks.

The kernel and prover are unchanged. Security requirements, default AES-256-XTS encryption, default disk workqueues and THP defaults are unchanged. Azure AMD v6 hosts must still meet the existing firmware security requirements.

Expected boot measurements are derived from these exact image bytes and saved firmware evidence. They are identified as derived, rather than newly collected cloud measurements. Normal and debug image values are calculated separately.

Logging and console output are disabled in this image. Public registry and release publication are separate from preparing this bundle.
