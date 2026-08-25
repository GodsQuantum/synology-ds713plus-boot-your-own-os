# DS713+ RAM upgrade and hardware limits

[← Back to README](../README.md) · [Français](RAM-UPGRADE.fr.md)

The DS713+ shipped with **1 GB DDR3**.

Synology did not market this model as a user-upgradable-memory NAS, but community teardown/upgrade reports show a replaceable SO-DIMM and long-running DS713+ systems with 2 GB and 4 GB modules.

The important hard limit comes from the CPU.

## Intel Atom D2700 memory controller

Intel specifies:

```text
Maximum memory     4 GB
Memory type        DDR3-800 / DDR3-1066
Channels           1
Maximum bandwidth  6.4 GB/s
ECC                no
```

So **8 GB is outside the D2700 specification**, regardless of whether a module physically fits.

## Practical choices

| Capacity | Status | Comment |
|---|---|---|
| **1 GB** | ✅ Official stock configuration | Works; tight for modern services |
| **2 GB** | 🟢 Conservative community upgrade | Good low-risk target for a lightweight OS |
| **4 GB** | 🟠 D2700 maximum | Community-proven on DS713+, but module compatibility matters |
| **8 GB** | ❌ Outside CPU specification | Do not treat 64-bit OS support as proof of 8 GB memory support |

## Known community examples

Historical DS713+ reports include:

- 2 GB Kingston `KVR1333D3S8S9/2G` reported working;
- 4 GB PNY `SOD104GBN/10660/3-BX` reported working;
- 4 GB Kingston `KVR13S9S8/4` repeatedly reported compatible, including DSM 6 and DSM 7 use.

These are **community reports, not Synology certification and not validation by this repository**.

Old memory controllers can care about:

- voltage;
- rank;
- chip density;
- module organization;
- SPD data.

A random “4 GB DDR3 SO-DIMM” is therefore not guaranteed to behave like a known-good module.

## What I would choose

For a DS713+ being repurposed today:

- **2 GB** if you want the conservative option;
- **4 GB** if you want OMV/Ubuntu headroom and can source a module with a known DS713+ track record.

For OpenMediaVault 8 specifically, 4 GB is a much nicer target even though OMV documents 1 GiB as its lower bound.

## CPU limits that also matter

The D2700 is:

```text
2 cores / 4 threads
2.13 GHz
Intel 64
SSE2 / SSE3 / SSSE3
no SSE4
no AVX
no VT-x
no VT-d
10 W TDP
```

That means:

- modern lightweight server Linux is realistic;
- CPU-heavy containers/services are not the point of this machine;
- hardware virtualization is not a useful target;
- software requiring AVX or SSE4 will not run.

## Storage/network hardware

Synology's original datasheet lists:

```text
2 × SATA bays
2 × Gigabit Ethernet
2 × rear USB 3.0
1 × front USB 2.0
1 × eSATA
hot-swappable internal drives
```

The original datasheet's “8 TB maximum” was based on the drive sizes available/certified at the time, not a statement that the SATA controller fundamentally cannot address larger modern disks. Any modern-drive use should still be tested with the chosen OS/filesystem.

## Sources

See [SOURCES.md](SOURCES.md) for Intel's D2700 specification, Synology's DS713+ datasheet, and the community RAM reports.
