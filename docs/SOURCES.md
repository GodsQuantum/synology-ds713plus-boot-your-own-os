# Sources and prior art

This repository separates **verified project results**, **official vendor facts**, and **community reports**.

## Synology DS713+ lifecycle / hardware

- [Synology — Product Support Status](https://www.synology.com/en-us/products/status?status=Phase+Out) — current DS713+ status: Discontinued / DSM Update End of Life / Technical Support Limited.
- [Synology Knowledge Center — Last upgradable software version](https://kb.synology.com/en-global/DSM/tutorial/What_is_the_last_upgradable_software_version_for_my_Synology_product) — DS713+: DSM 7.1. It also distinguishes the related x13 models at DSM 7.1 from older x12 models such as DS412+/DS1512+/DS1812+/RS812+ at DSM 6.2.
- [Synology Download Center — DS713+](https://www.synology.com/en-global/support/download/DS713%2B) — current DS713+ OS downloads shown by Synology: DSM 7.1 Series / DSM 7.1.1.
- [Synology DS713+ original datasheet (English PDF)](https://global.download.synology.com/download/Document/Hardware/DataSheet/DiskStation/13-year/DS713%2B/enu/Synology_DS713_Plus_Data_Sheet_enu.pdf) — dual-core 2.13 GHz CPU, 1 GB DDR3, 2 SATA bays, 2× Gigabit LAN, 2× USB 3.0, 1× USB 2.0, eSATA, hot-swap.
- [Synology launch announcement — DS713+ (2012)](https://www.synology.com/en-uk/company/news/article/Synology_Launches_DiskStation_DS713_) — historical context for the platform.

## CPU / RAM limits

- [Intel — Atom D2700 specifications](https://www.intel.com/content/www/us/en/products/sku/59683/intel-atom-processor-d2700-1m-cache-2-13-ghz/specifications.html) — Intel 64; 2 cores / 4 threads; 2.13 GHz; max 4 GB; DDR3-800/1066; single-channel; no ECC; SSE2/SSE3/SSSE3; no VT-x/VT-d.

### Community DS713+ RAM reports

These are **not official Synology certification**.

- [NAS-Forum — DS713+ RAM upgrade discussion](https://www.nas-forum.com/forum/topic/37351-ds-713-ajout-de-ram/) — historical 2 GB and 4 GB user reports.
- [NAS-Forum — RAM compatibility thread, DS713+ examples](https://www.nas-forum.com/forum/topic/13929-m%C3%A9moire-vive-ram/page/17/) — includes a DS713+ report for Kingston `KVR13S9S8/4` 4 GB under DSM 6/7.
- [NAS-Forum — older RAM compatibility page](https://www.nas-forum.com/forum/topic/13929-m%C3%A9moire-vive-ram/page/5/) — includes a DS713+ report for PNY `SOD104GBN/10660/3-BX` 4 GB.

## Modern OS candidates

- [OpenMediaVault 8 prerequisites](https://docs.openmediavault.org/en/8.x/prerequisites.html) — AMD64 supported, Debian 13 base, 1 GiB minimum RAM in the documented low-end configuration.
- [OpenMediaVault 8 releases](https://docs.openmediavault.org/en/8.x/releases.html) — OMV 8 “Synchrony”: Debian 13, stable.
- [OpenMediaVault installation on Debian 13](https://docs.openmediavault.org/en/8.x/installation/on_debian.html).
- [Ubuntu Server 26.04 LTS release notes](https://documentation.ubuntu.com/release-notes/26.04/) — Ubuntu 26.04 LTS; Server requirements can start around 1.5 GB RAM depending on scenario.
- [Ubuntu Server system requirements](https://ubuntu.com/server/docs/reference/installation/system-requirements/) — amd64 supported; current documented server memory requirements.
- [TrueNAS hardware guidance](https://www.truenas.com/docs/scale/gettingstarted/scalehardwareguide/) — check the current guide before installation; current guidance uses an 8 GB RAM baseline, which exceeds the D2700 4 GB maximum.

## Firmware / F400 prior art

- [SynoForum — DS412+ rebuild BIOS (Orefie and community)](https://www.synoforum.com/threads/ds412-rebuild-bios.16095/)
- [flashrom](https://flashrom.org/)
- [flashrom 1.2.1 source/manual](https://chromium.googlesource.com/external/coreboot.org/flashrom/+/refs/tags/v1.2.1/)
- [LongSoft UEFITool](https://github.com/LongSoft/UEFITool)
- UEFIPatch editing engine pinned by this repo: LongSoft/UEFITool `old_engine` commit `8d6fa6539b1e52236b0905f3ad889a7590af6fb9`; post-patch parsing uses the official UEFIExtract A75 Linux release with its published SHA-256.
- Intel I/O Controller Hub 10 (ICH10) family datasheet — BIOS control, SPI hardware sequencing and erase geometry.

## What this repository itself proves

The source links above do **not** prove the firmware patch works.

The repository's own reference experiment proves, on one DS713+ profile:

- two identical BIOS reads;
- audited `UsbBusDxe` patch;
- successful in-circuit write through ICH10R hardware sequencing;
- candidate verification;
- two complete BIOS-region verifies before reboot;
- normal DSM reboot;
- Debian 13 UEFI boot from a normal non-F400 `abcd:1234` USB drive through the front USB 2.0 port;
- negative boot result on both rear Etron EJ168A USB 3.0 ports with the **F400-only** firmware path after complete cold-power tests;
- later positive rear-controller boot through **DS713Bridge v9.1 + XhciDxe**, reaching Debian 13 network/SSH.

See [REFERENCE-RESULTS.md](REFERENCE-RESULTS.md) and [VERIFIED-HARDWARE.md](VERIFIED-HARDWARE.md).


## Rear USB3 bridge / xHCI sources

- [TianoCore EDK2 XhciDxe](https://github.com/tianocore/edk2/tree/master/MdeModulePkg/Bus/Pci/XhciDxe) — upstream xHCI DXE used by the bridge experiment; the reference build is pinned to `edk2-stable202605`, commit `b03a21a63e3bd001f52c527e5a57feddb53a690b`.
- [UEFI specifications](https://uefi.org/specifications) — Driver Binding, device paths, Simple File System and standard removable-media boot path.
- [OpenCore install guide — XhciDxe](https://dortania.github.io/OpenCore-Install-Guide/installer-guide/opencore-efi.html) — useful prior art for old firmware lacking xHCI support.

The repository's bridge timings and success/failure outcomes are project measurements, not claims made by those upstream sources.

## DS713+ SATA-power evidence

Project-derived evidence from Synology Cedarview GPL source plus physical DS713+ tests:

```text
CONFIG_SYNO_CEDARVIEW=y
CONFIG_SYNO_ICH_GPIO_CTRL=y
CONFIG_SYNO_ATA_PWR_CTRL=y
HddEnPinMap[] = {16, 20, 21, 32}
HW_DS713p handled by SYNO_CTRL_HDD_POWERON
```

See `USB3-BRIDGE-V95.md` and `RESEARCH-HANDOFF.md`.
