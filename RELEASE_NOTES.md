# Automata Linux v0.3.6

Non-debug confidential VM base image. Atakit system logging is off, and the image provides no serial shell or host SSH service.

Requires workload manifest **format 16** and **Atakit CLI v0.7.6**. Workloads
using formats 14 or 15 cannot start on this image. The CLI release remains private.

## Changes

- Adds signed CPU placement settings for the main workload, dependencies and
  baby containers. Equivalent CPU lists produce the same manifest bytes.
- Adds workload CPU idle and CPU frequency policies. Operators can tune only
  settings that the workload publisher explicitly allows. Authenticated changes
  apply on the next full workload startup, not immediately to running containers.
- Adds optional `nofile` limits for the main workload, dependencies and baby
  containers. An omitted limit uses the base-image default of 1,048,576; the
  base-image ceiling is also 1,048,576. No broad SYS_RESOURCE privilege is added.
- Uses the TDX V2 proof format and checks bundled prover capabilities during
  image builds.
- Writes explicit JSON defaults and normalizes equivalent manifest values.

## Supported machines

| Platform | Confidential VM type | Machine types |
| --- | --- | --- |
| AWS | AMD SEV-SNP | `m6a.large`, `m6a.xlarge`, `m6a.2xlarge`, `m6a.4xlarge`, `m6a.8xlarge` |
| AWS | AMD SEV-SNP | `c6a.large`, `c6a.xlarge`, `c6a.2xlarge`, `c6a.4xlarge`, `c6a.8xlarge`, `c6a.12xlarge`, `c6a.16xlarge` |
| Azure | Intel TDX | `Standard_DC2es_v6` |
| Azure | AMD SEV-SNP | `Standard_DC2as_v5`, with the two firmware groups listed in the signed measurement pack |
| GCP | AMD SEV-SNP | `n2d-standard-4` |
| GCP | Intel TDX | `c3-standard-{4,8,22,44,88,176}` |
| GCP | Intel TDX | `c4-standard-{2,4,8,16,24,32,48,96,144,192}` |

The signed measurement pack contains 32 variants across five profiles. A matching
machine name alone is insufficient: hardware evidence, PCR measurements and
security attributes must also satisfy the signed policy. Availability depends on
the provider region, quota and capacity. QEMU archives support local development
and do not establish hardware-backed confidentiality.

## CPU control limits

CPU placement selects guest CPUs. CPU idle and frequency controls depend on
interfaces exposed by the cloud platform. Unsupported optional settings are
skipped; required settings reject startup. GCP c4-standard-8 TDX exposes idle
controls but no CPU-frequency policy interface. Guest idle settings do not
establish physical-host C-state residency. The operator idle preset permits
`menu` and `teo`; it does not permit `ladder` or `haltpoll`.

## Secret provisioning

Successful workload startup does not authorize secret release. Independently
verify fresh hardware evidence and the publisher-signed image and workload
policies against measurements obtained from a trusted publisher before providing
secrets. A public key supplied by the requesting VM does not establish trust.
