# Changelog

## 0.1.0 — 2026-08-25

- First stable release.
- DS713+ software SPI write path documented and scripted.
- Front USB2 boot from non-F400 `abcd:1234` device confirmed with Debian 13 UEFI and SSH.
- Both rear Etron EJ168A USB3 ports physically tested after complete AC power cycles: neither boots the same known-good Debian USB drive with the current F400-only patch.
- Confirmed that Linux can still use the rear Etron controller through `xhci_hcd` after booting from the front USB2 port.
- Documented `XhciDxe` as a separate future experiment rather than part of the verified F400 unlock.

## 0.1.0-rc1 — 2026-08-25

- First public-ready draft.
- DS713+ software SPI write path documented and scripted.
- Front USB2 boot from non-F400 `abcd:1234` device confirmed with Debian 13 UEFI and SSH.
- Rear Etron USB3 remained pending physical test.
