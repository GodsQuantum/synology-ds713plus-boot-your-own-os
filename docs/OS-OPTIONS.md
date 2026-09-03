# Choosing an OS for the DS713+

[← Back to README](../README.md) · [Français](OS-OPTIONS.fr.md)

The F400 firmware patch gives the DS713+ a **normal UEFI USB boot path through the front USB 2.0 port**. The recommended DS713Bridge v9.4 additionally provides a physically verified full-stack path to an OS medium behind the rear Etron controller; v9.1 remains the historical minimal-stack Debian reference.

It does not mean every x86-64 operating system is a good fit. The useful question is:

> Does the OS support old x86-64 hardware, fit within a 4 GB RAM ceiling, and include drivers for the DS713+ storage/network controllers?

## Quick recommendations

| OS | Fit | Why |
|---|---|---|
| **Debian 13** | ✅ Verified | Actually booted on the reference DS713+ to userspace + network + SSH |
| **OpenMediaVault 8** | 🟢 Strong candidate | Debian 13 base, AMD64, low minimum RAM, NAS-focused UI |
| **Ubuntu Server 26.04 LTS** | ✅ Existing system boot verified | Existing Ubuntu system SSD booted through rear Etron with v9.4 to network/SSH; installer path still separate |
| **Other lightweight Linux** | 🟡 Case-by-case | Architecture may fit; drivers/installer/kernel still need validation |
| **Current TrueNAS** | 🔴 Not recommended | 8 GB minimum RAM exceeds the D2700 4 GB maximum |

## Debian 13 — known-good baseline

Debian 13 amd64 remains the fully documented baseline. An existing Ubuntu Server 26.04 system SSD has also now booted through the rear Etron controller with v9.4 to network/SSH; that does not by itself validate the Ubuntu installer path.

Reference test:

```text
UEFI            yes
USB             ordinary abcd:1234 device
Port            front USB 2.0
Root            USB storage
Userspace       reached
Network         reached
SSH             reached
```

This makes Debian the best diagnostic baseline when bringing up another DS713+.

## OpenMediaVault 8 — best NAS-oriented candidate

As of 2026, OpenMediaVault 8 is based on Debian 13.

OMV's own prerequisites document:

- AMD64 support;
- Debian 13 base;
- 1 GiB RAM as a minimal configuration;
- 4 GiB as a more comfortable target;
- installation from USB is supported.

That aligns unusually well with the DS713+:

```text
DS713+ CPU       x86-64 / Intel 64
DS713+ stock RAM 1 GB
DS713+ CPU max   4 GB
Verified base    Debian 13
```

For a practical NAS conversion, OMV is therefore the most obvious next full validation target.

### Recommended approach on this machine

Because Debian 13 is already known to boot, the conservative route is:

1. boot/install a minimal Debian 13 system first;
2. confirm both SATA disks and at least one Ethernet interface;
3. confirm stable cold boots from the front USB port;
4. install OMV 8 on top of that known-good Debian base.

The official OMV installer ISO is another option, but this repository has not yet validated its exact firmware boot path on DS713+.

## Ubuntu Server 26.04 LTS

Ubuntu 26.04 LTS provides an amd64 server image.

Canonical documents a low-end Server requirement around 1.5 GB RAM depending on installation scenario, so a DS713+ with 2–4 GB RAM is at least within the broad resource range.

Now physically verified:

- an existing Ubuntu Server 26.04 system SSD boots through the rear Etron controller with DS713Bridge v9.4;
- userspace, network and SSH are reached.

Still separate/unverified:

- the Ubuntu installer boot path itself;
- exhaustive power-management validation on Synology's old ACPI implementation.

## TrueNAS

Current TrueNAS hardware guidance calls for:

```text
CPU       dual-core x86-64
RAM       8 GB minimum
Boot      16+ GB class device
```

The Atom D2700 memory controller is limited by Intel to:

```text
4 GB maximum
```

That alone is enough to make modern TrueNAS a poor target for this NAS.

Older historical TrueNAS/FreeNAS versions are a different question, but running an old unsupported storage OS would defeat much of the point of escaping an EOL DSM installation.

## Other Linux distributions

A distribution may be worth trying if it:

- still supports baseline x86-64 CPUs without requiring AVX/SSE4;
- can run comfortably below 4 GB RAM;
- ships a kernel with the relevant Intel ICH10, Intel 82574L and Etron EJ168A support;
- can boot in UEFI mode from the front USB 2.0 path.

The patch does not alter Linux compatibility. It only removes the firmware's Synology-specific USB VID/PID rejection.


### Bridge compatibility history

DS713Bridge v9.1 remains the historical physically validated minimal-stack
Debian rear-Etron reference. DS713Bridge v9.4 FULL-STACK R2 is the current
physically validated rear-SSD deployment path.

## Boot media

Two paths are verified and must be distinguished:

- **front USB 2.0 directly after the F400 unlock**;
- **rear Etron storage through DS713Bridge v9.4 FULL-STACK R2**; v9.1 remains the historical minimal-stack Debian reference.

The F400 patch alone does not initialize Etron. The bridge is a separate removable xHCI pre-boot layer and chainloads the rear medium's standard `\EFI\BOOT\BOOTX64.EFI`.

Arbitrary SATA boot and arbitrary internal-DOM replacement remain separate questions.

## Sources

See [SOURCES.md](SOURCES.md) for official OMV, Ubuntu, TrueNAS, Intel and Synology references.

## DS713Bridge v9.5 deployment update

The currently recommended bridge is v9.5 SATA-POWER: the existing Linux system SSD boots through rear Etron and the internal SATA bays are powered before Linux.
