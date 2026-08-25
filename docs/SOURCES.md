# Sources and prior art

- SynoForum — **DS412+ rebuild BIOS** (Orefie and community): https://www.synoforum.com/threads/ds412-rebuild-bios.16095/
- flashrom: https://flashrom.org/
- flashrom 1.2.1 source/manual: https://chromium.googlesource.com/external/coreboot.org/flashrom/+/refs/tags/v1.2.1/
- LongSoft UEFITool: https://github.com/LongSoft/UEFITool
- UEFIPatch editing engine pinned by this repo: LongSoft/UEFITool `old_engine` commit `8d6fa6539b1e52236b0905f3ad889a7590af6fb9`; post-patch parsing uses the official UEFIExtract A75 Linux release with its published SHA-256.
- Intel I/O Controller Hub 10 (ICH10) family datasheet — BIOS control, SPI hardware sequencing and erase geometry.

## Attribution

Community work identified the Granite Well family and F400 behavior. This repository adds a fully logged **DS713+ software-write experiment**, conservative 4 KiB-aligned patchzone workflow, automatic rollback attempt, full BIOS post-write verification, and confirmed non-F400 front-USB boot.
