# Changelog

## 0.4.0 — 2026-09-03

- Promoted physically validated **DS713Bridge v9.5 SATA-POWER**.
- Verified front-v9.5 -> rear-Etron Linux boot with pre-OS SATA power GPIO16 -> 200 ms -> GPIO20.
- Integrated the real standalone v9.5 source/tests/writer.
- Added beginner-friendly USB selection with stable `/dev/disk/by-id/usb-*` identity.
- Fixed v9.4 host-side target handling so stable identities are revalidated immediately before destructive writes.
- Recorded negative v9.4/v9.5 J2/DOM tests without claiming an unproven cause.
- Added beginner quick starts plus research status/handoff documentation.


## 0.3.0 — 2026-09-01

- Added **DS713Bridge v9.4 FULL-STACK R2**, physically validated on a DS713+ with the bridge key on the front USB port and a Linux system SSD on the rear Etron controller.
- v9.4 deliberately starts a complete modern EDK2 storage path (`XhciDxe`, `UsbBusDxe`, `UsbMassStorageDxe`, `DiskIoDxe`, `PartitionDxe`, `EnglishDxe`, `Fat`) through `EFI_DRIVER_BINDING_PROTOCOL`, avoiding dependency on the 2011 Granite Well upper USB/storage stack.
- Added the autonomous `scripts/12-create-usb3-bridge-v94.sh`. The exact physically tested script has SHA-256 `6af4b3291f058093a9d2673a51596bb0525b57d5a818587166575f86709f206b`; its embedded v9.4 C source has SHA-256 `75e00a082b11dbb9684eb240f77dbdbe3cfde952b90f7e4f8274020432a0ba39`.
- The writer builds and validates the complete EFI payload **before** destructive confirmation or `wipefs`, rejects the system disk/non-USB/non-whole-disk/zero-size targets, and preserves the exact validated 202605 `XhciDxe` when recoverable.
- Kept EDK2 `edk2-stable202605` commit `b03a21a63e3bd001f52c527e5a57feddb53a690b` as the default profile; `edk2-stable202608` commit `2970e5699ba6267f3384ffab20f96647578aebc8` remains an explicit `--latest` experiment.
- Added v9.4 source/writer static gates while preserving all v9.1 and v9.3 historical tests.
- DS713Bridge v9.1 remains the historical minimal-stack Debian rear-Etron validation reference; v9.4 is the recommended bridge for broader rear-SSD compatibility.

## 0.2.0 — 2026-08-27

- Added physically validated **DS713Bridge v9.1** rear-Etron boot support: Debian 13 reached network/SSH from storage behind the Etron controller.
- Added `scripts/10-create-usb3-bridge.sh` with explicit `SDX=sdX` selection, system-disk/non-USB/whole-disk guards, destructive confirmation, exact known-good binary recovery and pinned source rebuild fallback.
- Added English/French quick starts that clearly separate the DSM firmware-flash phase from the later Linux/bridge phase.
- Updated all USB boot, hardware, OS, reference-result, theory, safety and recovery docs so the F400-only rear negative result is not confused with the later bridge success.
- Preserved measured V9.1 performance and negative V10/full-stack, direct-UKI and diagnostic-harness results as research evidence rather than deployment recommendations.
- Added repository-consistency and relative-Markdown-link tests; made the post-migration health check work both as root and through sudo.
- Added SHA-256 verification for the pinned pciutils 3.10.0 and flashrom 1.2.1 source tarballs used by the D2700-safe flashrom build.
- Repositioned the project around giving an EOL DS713+ a second life with a compatible modern Linux/NAS OS, with Debian 13 verified and OMV/Ubuntu documented as candidates.
- Repository renamed to `synology-ds713plus-boot-your-own-os`; v0.1.0 remains the historical F400/front-USB firmware-unlock release.

## 0.1.0 — 2026-08-25

- First stable firmware-unlock release.
- DS713+ software SPI write path documented and scripted.
- Front USB2 boot from non-F400 `abcd:1234` device confirmed with Debian 13 UEFI and SSH.
- Both rear Etron EJ168A USB3 ports physically tested after complete AC power cycles: neither boots the same known-good Debian USB drive with the F400-only patch.
- Confirmed that Linux can still use the rear Etron controller through `xhci_hcd` after booting from the front USB2 port.
- Documented `XhciDxe` as a separate experiment; rear bridge success was established later in v0.2.0.
