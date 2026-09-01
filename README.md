# Synology DS713+ — Boot Your OS of Choice

[![lint](https://github.com/GodsQuantum/synology-ds713plus-boot-your-own-os/actions/workflows/lint.yml/badge.svg)](https://github.com/GodsQuantum/synology-ds713plus-boot-your-own-os/actions/workflows/lint.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**[🇫🇷 Version française](README.fr.md)** ·
[Quick start](docs/QUICKSTART.md) ·
[Rear USB3 bridge](docs/USB3-BRIDGE.md) ·
[Choose an OS](docs/OS-OPTIONS.md) ·
[RAM upgrade](docs/RAM-UPGRADE.md) ·
[Verified hardware](docs/VERIFIED-HARDWARE.md) ·
[Safety](docs/SAFETY.md)

> **Give an EOL Synology DS713+ a second life.** Remove Synology's `F400:F400` USB boot restriction and boot a compatible modern x86-64 Linux/NAS OS from a normal USB drive.

The **DS713+ is still useful hardware**: Intel x86-64 CPU, two SATA bays, dual Gigabit Ethernet, USB 3.0 and eSATA. The problem in 2026 is mostly software support.

Synology now lists the DS713+ as **Discontinued**, **DSM Update End of Life**, with **Limited** technical support. Its last upgradable DSM branch is **DSM 7.1**, and Synology's Download Center currently tops out at **DSM 7.1.1**.

This project takes a different route: keep the hardware, remove the firmware's Synology-only USB VID/PID check, and use the machine as a normal small x86-64 server/NAS.

---

## Start here

There are **two separate stages**. Do not mix them:

1. **Firmware unlock (required once):** while the NAS still runs DSM, use a Linux workstation + DSM admin SSH to remove the `F400:F400` restriction. The scripts double-dump, validate the exact DS713+ profile, calculate the physical patch zone, require a separate arm step, attempt rollback on verification failure, and refuse reboot clearance until the whole BIOS region verifies twice.
2. **Rear USB3 bridge (optional, but recommended if the OS lives on a rear port):** create the physically validated v9.4 full-stack bridge with `./scripts/12-create-usb3-bridge-v94.sh`. It loads a modern EDK2 xHCI/USB/storage/filesystem stack and chainloads the rear medium's standard `\EFI\BOOT\BOOTX64.EFI`. The v9.1 writer remains available for historical reproduction.

**Fastest route:** follow **[Quick start](docs/QUICKSTART.md)** from top to bottom. Read **[Safety](docs/SAFETY.md)** before the firmware write.

```text
DSM still running
  -> 00..06 audit/build/preflight
  -> 07 prepare -> status -> arm -> status
  -> 08 full BIOS verify -> READY_FOR_REBOOT=YES
  -> reboot/test normal non-F400 USB
  -> optional 12-create-usb3-bridge-v94.sh for rear Etron boot
```

---

## Before → after

| | Stock DS713+ | After this project |
|---|---|---|
| Official OS path | DSM only | Compatible x86-64 Linux/NAS OS |
| DSM ceiling | DSM 7.1 / 7.1.1 downloads | No DSM ceiling if you leave DSM |
| DSM update status | ❌ End of Life | Depends on the OS you choose |
| Normal USB boot | ❌ Firmware expects `F400:F400` | ✅ Normal non-F400 USB boot verified |
| Debian 13 | Not a normal supported boot path | ✅ **Verified A-to-Z** |
| OpenMediaVault 8 | Not a Synology-supported option | 🟢 Strong candidate |
| Ubuntu Server 26.04 LTS | Not a Synology-supported option | ✅ Existing Ubuntu system SSD boot verified via rear Etron with v9.4; installer path not separately validated |
| Current TrueNAS | Not a Synology-supported option | 🔴 Not a sensible target: 8 GB minimum RAM |
| Hardware | Same 2012 NAS | Same hardware, under your control |

**Important:** “Boot your OS of choice” means **a compatible OS that fits this hardware**. This patch removes the Synology USB whitelist; it does not magically add drivers or increase the CPU/RAM limits.

---

## The hardware is old — but not useless

Synology launched the DS713+ in 2012 as a fairly capable 2-bay business NAS.

Reference hardware:

```text
CPU           Intel Atom D2700 / Cedarview
              2 cores / 4 threads @ 2.13 GHz
Architecture  Intel 64 / x86-64
RAM stock     1 GB DDR3
CPU RAM max   4 GB DDR3-800/1066
Storage       2 × 2.5"/3.5" SATA bays, hot-swap
Network       2 × Gigabit Ethernet
Front         1 × USB 2.0
Rear          2 × USB 3.0 + eSATA
```

For a lightweight NAS, backup box, SMB/NFS server, rsync target, small Docker-free server, monitoring node, or general Debian box, that can still be perfectly useful.

The important limitation is the **4 GB RAM ceiling** of the Atom D2700 memory controller. See [RAM upgrade](docs/RAM-UPGRADE.md).

---

## ✅ What is actually verified

This repo does not mark “should work” as “works”.

| Test | Status |
|---|---|
| BIOS dump → patch → flash → full verification | ✅ Verified |
| DSM boots normally after patch | ✅ Verified |
| Ordinary USB drive with VID:PID `abcd:1234` | ✅ Accepted |
| Front USB 2.0 UEFI boot | ✅ Verified |
| Debian 13 amd64 | ✅ Verified |
| Linux userspace + DHCP/network + SSH | ✅ Verified |
| Rear Etron USB 3.0 with F400 patch only | ❌ Not bootable |
| Rear Etron USB 3.0 through DS713Bridge v9.1 | ✅ Debian 13 → network/SSH verified |
| Rear Etron USB 3.0 through DS713Bridge v9.4 FULL-STACK R2 | ✅ Ubuntu/Linux system SSD → network/SSH verified |
| Rear USB 3.0 once Linux is running | ✅ Works via `xhci_hcd` |

Reference boot:

```text
USB VID:PID   abcd:1234
Partitioning  GPT + EFI System Partition
Boot mode     UEFI x86-64
OS            Debian 13
Port          front USB 2.0
Result        UEFI → Linux → network → SSH
```

That proves the actual goal of the firmware modification:

> **A patched DS713+ can boot a completely ordinary non-F400 USB device from its front USB 2.0 port.**

---

## What OS should I use?

### ✅ Debian 13 — verified

This is the reference OS used for the final hardware test.

If you want the simplest base, Debian is the known-good starting point.

### 🟢 OpenMediaVault 8 — probably the most interesting NAS target

OMV 8 is based on **Debian 13**, supports AMD64, and its documentation allows operation from **1 GiB RAM** at the low end.

That makes it a very natural candidate for the DS713+, especially after a 2 GB or 4 GB RAM upgrade.

It has **not yet been installed A-to-Z by this repository**, so it is deliberately marked as a candidate rather than verified.

### ✅ Ubuntu Server 26.04 LTS — existing system boot verified

Ubuntu Server 26.04 has an amd64 installer and can start around 1.5 GB RAM depending on installation/use case.

The D2700 is Intel 64, and an existing Ubuntu Server 26.04 system SSD has now booted through the rear Etron controller using DS713Bridge v9.4 to network/SSH. The Ubuntu installer path itself has not been separately validated.

### 🔴 Current TrueNAS — skip it on this machine

Current TrueNAS documentation calls for **8 GB RAM minimum**.

The Atom D2700 memory controller tops out at **4 GB**.

So even though TrueNAS is x86-64, current TrueNAS is not a sensible recommendation for this NAS.

See the fuller comparison in **[Choosing an OS](docs/OS-OPTIONS.md)**.

---

## RAM: 1 GB stock, up to 4 GB at the CPU level

Synology shipped the DS713+ with **1 GB DDR3**.

Intel specifies the D2700 for a maximum of **4 GB DDR3-800/1066**, single-channel, non-ECC.

Community reports show DS713+ units successfully running both **2 GB** and **4 GB** SO-DIMMs, including reports of the Kingston `KVR13S9S8/4` 4 GB module working under DSM 6 and DSM 7.

But this is **not an official Synology-supported upgrade**, and module layout/density matters on old Cedarview hardware.

Practical framing:

| RAM | Recommendation |
|---|---|
| 1 GB | ✅ Stock; enough for lean Debian / very light OMV |
| 2 GB | 🟢 Conservative upgrade |
| 4 GB | 🟠 CPU maximum; community-proven on DS713+, but choose the module carefully |
| 8 GB | ❌ Outside the D2700 specification |

See **[RAM upgrade and hardware limits](docs/RAM-UPGRADE.md)** before buying a module.

---

## Why a normal USB stick does not boot stock firmware

The DS713+ firmware contains a USB DXE module that explicitly checks for Synology's USB VID/PID pair:

```text
F400:F400
```

A normal USB drive can be perfectly valid, yet the firmware rejects it before your OS gets a chance to run.

The target module is:

```text
Module       UsbBusDxe
FFS GUID     240612B7-A063-11D4-9A3A-0090273FC14D
Section      PE32 / 0x10
```

The two rejection branches are:

```text
+0x2991  0F 85 17 03 00 00  ->  90 90 90 90 90 90
+0x299B  0F 85 0D 03 00 00  ->  90 90 90 90 90 90
```

Only **12 semantic bytes** are changed.

The firmware section is LZMA-compressed, though, so the rebuilt physical BIOS differs over a much larger region. That is why this project calculates the real changed SPI area and aligns it to the hardware erase size instead of pretending that a 12-byte patch means a 12-byte SPI write.

Deep dive: [How the F400 restriction works](docs/THEORY.md).

---

## 🚀 Workflow

Run the tooling from a Linux machine with SSH access to DSM.

```bash
export NAS_HOST='192.168.1.x'
export NAS_USER='your-admin-user'

./scripts/00-build-flashrom.sh
./scripts/01-install-flashrom.sh
./scripts/02-probe.sh
./scripts/03-dump.sh
./scripts/04-build-uefi-tools.sh
./scripts/05-patch-bios.sh artifacts/bios-read1.bin
./scripts/06-preflight.sh
```

At this point **nothing has been flashed yet**.

The real write is intentionally split into explicit stages:

```bash
./scripts/07-flash.sh prepare
./scripts/07-flash.sh arm
./scripts/07-flash.sh status
```

Before rebooting:

```bash
./scripts/08-postflash-verify.sh
```

Do not reboot unless the final verification reports:

```text
READY_FOR_REBOOT=YES
```

The flashing workflow never reboots the NAS automatically.

Read **[Safety](docs/SAFETY.md)** and **[Recovery](docs/RECOVERY.md)** before writing.

---

## Rear USB 3.0: what is actually verified

**Current recommended deployment: DS713Bridge v9.4 FULL-STACK R2.** On 2026-09-01, a v9.4 key in the front USB port successfully booted the existing Ubuntu/Linux system SSD through the rear Etron controller to network/SSH. Unlike the minimal v9.1 path, v9.4 loads `XhciDxe`, `UsbBusDxe`, `UsbMassStorageDxe`, `DiskIoDxe`, `PartitionDxe`, `EnglishDxe`, and `Fat` and binds them through `EFI_DRIVER_BINDING_PROTOCOL`. See [the v9.4 guide](docs/USB3-BRIDGE-V94.md).

The **F400 firmware patch alone** still does not initialize the rear Etron EJ168A xHCI controller. Both rear ports produced negative cold-boot results in the original v0.1.0 experiment.

The later **DS713Bridge v9.1** experiment solved that separate problem without modifying the OS medium:

```text
patched Synology firmware
  -> bridge key in front USB
  -> DS713Bridge v9.1 + validated XhciDxe
  -> Etron EJ168A
  -> rear UEFI medium
  -> \EFI\BOOT\BOOTX64.EFI
  -> Debian 13 -> network -> SSH
```

The bridge does not hard-code an OS, filesystem UUID, disk serial, rear-port number, `BootOrder`, or `BootNext`. The implementation discovers filesystems below the Etron controller and chainloads only the standard removable-media loader.

**Physical evidence is controller-level:** a rear-Etron Debian boot to network/SSH is verified. The code is rear-port agnostic, but this repository does not claim that both physical rear connectors were independently re-run A-to-Z with v9.1.

See **[Rear USB3 bridge](docs/USB3-BRIDGE.md)** for exact hashes, measured timings, and negative experiments.

---

## 📁 Where to go next

| If you want to… | Read |
|---|---|
| Pick Debian / OMV / Ubuntu / another OS | [OS options](docs/OS-OPTIONS.md) |
| Upgrade the RAM | [RAM upgrade](docs/RAM-UPGRADE.md) |
| See exactly what hardware was verified | [Verified hardware](docs/VERIFIED-HARDWARE.md) |
| Understand the firmware patch | [Theory](docs/THEORY.md) |
| See hashes / reference offsets | [Reference results](docs/REFERENCE-RESULTS.md) |
| Test USB boot correctly | [USB boot](docs/USB-BOOT.md) |
| Understand the safety gates | [Safety](docs/SAFETY.md) |
| Recover from a failed verification | [Recovery](docs/RECOVERY.md) |
| Check upstream references | [Sources](docs/SOURCES.md) |

---

## Could this work on other Synology models?

**Possibly — but do not flash a DS713+ profile onto another model.**

The following Cedarview / Granite Well-era systems are especially interesting research targets:

| Model family | Last Synology OS branch | Status in this repo |
|---|---:|---|
| DS713+ | DSM 7.1 | ✅ Firmware + front USB boot verified |
| DS1513+ / DS1813+ / DS2413+ | DSM 7.1 | ❓ Related / unverified |
| DS412+ / DS1512+ / DS1812+ | DSM 6.2 | ❓ Related / unverified |
| RS812+ / related x12 units | DSM 6.2 | ❓ Related / unverified |

A related CPU generation does **not** guarantee the same BIOS image, module bytes, flash permissions or erase geometry.

For another model, start with **probe + double dump only**, then open a hardware report. Do not jump directly to the write stage.

---

## License / firmware

Repository-authored scripts and documentation are MIT licensed.

This repository does **not** redistribute:

- Synology firmware;
- a modified Synology BIOS;
- flashrom binaries;
- UEFITool binaries.

You dump and patch firmware from hardware you control.

## Credits

This work builds on Granite Well BIOS research shared by **Orefie** and other SynoForum contributors, plus [flashrom](https://flashrom.org/) and [UEFITool](https://github.com/LongSoft/UEFITool).

The official Synology, Intel, OMV, Ubuntu, TrueNAS and community references used for the hardware/OS claims are listed in **[Sources](docs/SOURCES.md)**.
