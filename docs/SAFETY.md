# Safety model

1. **No firmware binaries are shipped.** Dump your own unit twice.
2. **Probe before reading or writing.** The write path only accepts the tested ICH10R/4 MiB/4 KiB/RW layout invariants.
3. **Never full-chip write.** The tested DS713+ faults at physical `0x211000`; the upper part of the 4 MiB address space is not a trustworthy dump.
4. **Dynamic patchzone.** Recompression changes many physical bytes. The patchzone is calculated from stock vs candidate and aligned to the chipset-reported erase size.
5. **Two-stage write.** `prepare` starts a detached root worker which stops at `WAITING_FOR_ARM`; `arm` is a separate explicit operation.
6. **Automatic rollback attempt.** If candidate verification fails while Linux is still alive, the worker writes the original carrier back over the same patchzone and verifies it.
7. **No automatic reboot.** A complete 2 MiB BIOS verify must pass twice after flashing.
8. **Stable power strongly recommended.** Prefer a UPS. Software cannot recover from every power-loss or flash-chip failure.

If the status ever becomes `FINAL_STATUS=CRITICAL_DO_NOT_REBOOT`, keep the NAS powered and collect the complete log. Do not power-cycle it.

## Bridge-key safety

`scripts/10-create-usb3-bridge.sh` is destructive to the selected USB disk. It accepts only a whole `/dev/sdX` USB disk, rejects the current system disk and non-USB targets, prints model/serial and requires an exact destructive confirmation unless explicitly automated with `YES=1`.

For fresh bridge builds, exact raw binary identity and source-equivalent rebuilds are reported separately. Do not describe a fresh rebuild as the exact physically tested PE binary unless its SHA-256 matches the known-good reference.

## v9.5 stable USB identity

A real USB re-enumeration changed a `/dev/sdX` assignment during development. v9.5 therefore selects a whole USB disk, derives `/dev/disk/by-id/usb-*`, and the v9.4 writer re-resolves/revalidates that stable identity immediately before destructive writes.
