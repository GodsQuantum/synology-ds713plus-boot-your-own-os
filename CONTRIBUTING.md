# Contributing

Hardware reports and patches are welcome.

- Never attach Synology firmware dumps or patched proprietary BIOS images.
- Include exact model, board/revision if known, DSM version, chipset, flashrom version, `FREG`, `PR0..PR4`, `BIOS_CNTL`, `FLOCKDN`, erase geometry, and relevant **redacted** logs.
- A new model is not marked verified until probe/read evidence is distinguished from actual successful write/reboot/boot-device evidence.
- Changes to `scripts/07-flash.sh` or safety gates should include a clear failure-mode analysis.
- Run `make lint` before opening a PR.

- Bridge changes should preserve the distinction between **F400-only rear negative results** and **rear-controller boot through DS713Bridge v9.1**. Do not infer that both physical rear connectors were independently validated unless you have that evidence.
- Run the repository consistency and Markdown-link tests through `make lint` before opening a PR.

## v9.5 / SATA / J2 evidence

Reports should include bridge version, physical placement, SATA-power result, serial UEFI evidence when available, and whether the exact same media was retested in the known-good front USB position. Negative J2 results are useful evidence; do not label J2 supported until a real boot succeeds.
