# Changelog

## Unreleased

- Repositioned the project around the practical goal: giving an EOL DS713+ a second life with a compatible modern Linux/NAS OS.
- Added clear “stock vs unlocked” lifecycle and capability framing.
- Added OS guidance for Debian 13, OpenMediaVault 8, Ubuntu Server 26.04 LTS and current TrueNAS.
- Added a DS713+ RAM upgrade / D2700 hardware-limits guide.
- Added official Synology lifecycle, Intel CPU, OMV, Ubuntu and TrueNAS references.
- Expanded related-model guidance while keeping every non-DS713+ model explicitly unverified.
- Repository renamed to `synology-ds713plus-boot-your-own-os`; the v0.1.0 firmware result itself is unchanged.

## 0.1.0 — 2026-08-25

- First stable firmware-unlock release.
- DS713+ software SPI write path documented and scripted.
- Front USB2 boot from non-F400 `abcd:1234` device confirmed with Debian 13 UEFI and SSH.
- Both rear Etron EJ168A USB3 ports physically tested after complete AC power cycles: neither boots the same known-good Debian USB drive with the current F400-only patch.
- Confirmed that Linux can still use the rear Etron controller through `xhci_hcd` after booting from the front USB2 port.
- Documented `XhciDxe` as a separate future experiment rather than part of the verified F400 unlock.
