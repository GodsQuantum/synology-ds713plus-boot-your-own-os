# Recovery states

- `FINAL_STATUS=SUCCESS_CANDIDATE_VERIFIED` — candidate independently verified; still run `08-postflash-verify.sh` before reboot.
- `FINAL_STATUS=ROLLBACK_ORIGINAL_VERIFIED` — candidate failed, original patchzone restored and verified.
- `FINAL_STATUS=CRITICAL_DO_NOT_REBOOT` — neither candidate nor rollback verified. **Do not reboot or remove power.** Preserve the running system and logs.

Hardware recovery with an external SPI programmer remains the universal last resort and is strongly recommended for anyone who cannot tolerate loss of the device, even though the verified experiment was performed software-only.

## Bridge-key recovery

The bridge is removable and does not alter the rear OS medium. If a bridge experiment fails, recreate the last known-good v9.1 key on another Linux machine with `scripts/10-create-usb3-bridge.sh`. When the exact validated v9.1/Xhci files are already present on the selected key, the writer preserves them before repartitioning and reuses them byte-for-byte.

## Current bridge key

Recreate the current bridge with:

```bash
./scripts/13-create-usb3-bridge-v95.sh
```

v9.4 and v9.1 remain historical/research baselines.
