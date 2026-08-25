# Synology DS713+ — normal USB boot (F400 bypass)

[![lint](https://github.com/GodsQuantum/synology-ds713plus-f400-unlock/actions/workflows/lint.yml/badge.svg)](https://github.com/GodsQuantum/synology-ds713plus-f400-unlock/actions/workflows/lint.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**[🇫🇷 Version française](README.fr.md)** ·
[Verified hardware](docs/VERIFIED-HARDWARE.md) ·
[Safety](docs/SAFETY.md) ·
[Recovery](docs/RECOVERY.md) ·
[Sources](docs/SOURCES.md)

Synology's Granite Well/Tiano firmware on the **DS713+** expects USB boot devices with the hard-coded VID:PID `F400:F400`.

So a normal USB stick can work perfectly once Linux is running, yet still be ignored by the firmware at boot.

This repo is the complete **A-to-Z workflow I used on a real DS713+** to remove that restriction, flash only the SPI erase blocks that actually changed, verify the result, and boot Debian 13 from an ordinary USB stick.

> **Short version:** patch `UsbBusDxe`, remove the two F400 checks, rebuild, flash the real changed area, verify twice, boot.

---

## ✅ What actually works

| Test | Result |
|---|---|
| DS713+ boots DSM after the BIOS flash | ✅ Verified |
| Ordinary non-`F400:F400` USB stick | ✅ Accepted |
| Front USB 2.0 boot | ✅ Verified |
| Debian 13 amd64 / UEFI | ✅ Verified |
| Linux userspace + network + SSH | ✅ Verified |
| Rear USB 3.0 port #1 | ❌ Does not boot |
| Rear USB 3.0 port #2 | ❌ Does not boot |
| Rear USB 3.0 once Linux is running | ✅ Works through `xhci_hcd` |
| Other Cedarview / Granite Well Synology models | ⚠️ Not validated |

Final boot test:

```text
USB VID:PID   abcd:1234
Boot mode     UEFI x86_64
OS            Debian 13
Port          front USB 2.0
Result        boot → network → SSH
```

So the useful conclusion is simple:

> **Once the F400 check is removed, the DS713+ can boot a normal USB drive from the front USB 2.0 port.**

### Rear USB 3.0

I tested **both** rear Etron EJ168A ports with the exact same known-good USB stick, each time after a complete electrical cold boot.

Neither rear port booted it. Moving the same stick back to the front USB 2.0 port after a cold start worked again.

Linux can use the Etron controller normally once the kernel is running, but the current firmware patch only removes the F400 VID/PID restriction. It does **not** add EFI xHCI support.

So rear USB 3.0 boot is **not supported by this F400-only patch**.

---

## Why this repo exists

The old Granite Well research was enough to show that Synology checks for `F400:F400`.

What it did **not** give me was a workflow I was comfortable running on a headless NAS with no convenient recovery path.

Before writing anything, I wanted clear answers to these questions:

- did I dump the correct BIOS region?
- are both dumps identical?
- is this really the hardware profile I expect?
- is the BIOS region writable?
- what is the actual erase size?
- did the firmware rebuild correctly?
- which physical SPI blocks really changed?
- does the write stay entirely inside the BIOS region?
- can the candidate be verified immediately?
- can the script roll back if verification fails?
- can the full BIOS region be checked again before reboot?

The scripts in this repo are built around those checks.

---

## ⚠️ Before flashing

Firmware flashing can brick hardware.

The automated write path here is verified on **one DS713+ hardware/firmware profile**. Related Synology models are research candidates, not automatically supported targets.

Do not skip the probe/dump stages and do not reuse someone else's firmware image.

**No Synology BIOS or modified BIOS image is distributed in this repo.**

Read [docs/SAFETY.md](docs/SAFETY.md) before the write stage.

---

## 🔧 What the patch changes

Target module:

```text
Module       UsbBusDxe
FFS GUID     240612B7-A063-11D4-9A3A-0090273FC14D
Section      PE32 / 0x10
```

The stock firmware contains two conditional jumps that reject USB devices whose VID or PID is not `0xF400`:

```text
+0x2991  0F 85 17 03 00 00  ->  90 90 90 90 90 90
+0x299B  0F 85 0D 03 00 00  ->  90 90 90 90 90 90
```

At PE level the semantic change is only **12 bytes**.

The catch is that `UsbBusDxe` sits inside an LZMA-compressed firmware section. Rebuilding it changes the compressed byte stream, so the final BIOS image differs over a much larger area.

This repo therefore computes the **real physical diff**, aligns it to the chipset erase size, checks that it stays inside the BIOS region, and only writes that aligned zone.

Reference result on the tested DS713+:

```text
Semantic patch        12 bytes

Physical diff
first changed byte    0x011058
last changed byte     0x095d28

4 KiB aligned zone
start                 0x011000
end                   0x095fff
size                  544768 bytes
```

---

## 🧱 Verified DS713+ SPI profile

```text
Platform         Synology DS713+ / Granite Well
Chipset          Intel ICH10R 8086:3a16
SPI flash        4 MiB

Descriptor       0x000000 - 0x000fff
GbE              0x001000 - 0x010fff
BIOS             0x011000 - 0x210fff (2 MiB)

BIOS region      read/write
FLOCKDN          0
PR0..PR4         unused
BIOSWE           enabled
Erase block      4096 bytes
```

One important detail: physical space `0x211000-0x3fffff` is not readable through ICH hardware sequencing on the tested unit.

A 4 MiB carrier assembled for flashrom is therefore **not a trustworthy full physical chip dump**. The workflow keeps read/write/verify operations constrained by an explicit layout.

---

## 🚀 Quick start

Run this from a Linux machine with SSH access to DSM:

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

At this point, **nothing has been flashed yet**.

The real write is deliberately split into explicit stages:

```bash
./scripts/07-flash.sh prepare
./scripts/07-flash.sh arm
./scripts/07-flash.sh status
```

Then verify before rebooting:

```bash
./scripts/08-postflash-verify.sh
```

Do not reboot unless the final result is:

```text
READY_FOR_REBOOT=YES
```

The scripts never reboot the NAS automatically.

---

## 📁 Repo map

| Path | Purpose |
|---|---|
| `scripts/` | build, probe, dump, patch, preflight, flash, verify |
| `scripts/lib/` | shared shell helpers |
| `profiles/` | verified hardware invariants |
| `patches/` | patch description — **no firmware binaries** |
| `docs/SAFETY.md` | read before flashing |
| `docs/RECOVERY.md` | rollback / recovery |
| `docs/USB-BOOT.md` | USB boot validation |
| `docs/VERIFIED-HARDWARE.md` | tested hardware status |
| `docs/REFERENCE-RESULTS.md` | reference values from the working DS713+ |
| `docs/THEORY.md` | deeper technical notes |
| `docs/SOURCES.md` | upstream research / references |

---

## Related Synology models

DS412+, DS1512+, DS1812+, DS1513+, DS1813+, DS2413+, RS812+ and other Cedarview/Granite Well systems are useful research candidates.

They are **not automatically compatible**.

Firmware contents, SPI permissions, erase geometry, module bytes and rebuild output can differ. Start with probe + dump and open a hardware report before attempting a write.

---

## License / firmware

Repository-authored scripts and documentation are MIT licensed.

This repo does **not** redistribute Synology firmware, a modified Synology BIOS, flashrom binaries or UEFITool binaries.

## Credits

Built on the Granite Well BIOS research shared by **Orefie** and other SynoForum contributors, plus [flashrom](https://flashrom.org/) and [UEFITool](https://github.com/LongSoft/UEFITool).

See [docs/SOURCES.md](docs/SOURCES.md) for the references used.
