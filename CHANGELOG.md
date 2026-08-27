# Changelog

## Unreleased

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
