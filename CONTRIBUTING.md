# Contributing

Hardware reports and patches are welcome.

- Never attach Synology firmware dumps or patched proprietary BIOS images.
- Include exact model, board/revision if known, DSM version, chipset, flashrom version, `FREG`, `PR0..PR4`, `BIOS_CNTL`, `FLOCKDN`, erase geometry, and relevant **redacted** logs.
- A new model is not marked verified until probe/read evidence is distinguished from actual successful write/reboot/boot-device evidence.
- Changes to `scripts/07-flash.sh` or safety gates should include a clear failure-mode analysis.
- Run `make lint` before opening a PR.
