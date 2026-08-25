# Recovery states

- `FINAL_STATUS=SUCCESS_CANDIDATE_VERIFIED` — candidate independently verified; still run `08-postflash-verify.sh` before reboot.
- `FINAL_STATUS=ROLLBACK_ORIGINAL_VERIFIED` — candidate failed, original patchzone restored and verified.
- `FINAL_STATUS=CRITICAL_DO_NOT_REBOOT` — neither candidate nor rollback verified. **Do not reboot or remove power.** Preserve the running system and logs.

Hardware recovery with an external SPI programmer remains the universal last resort and is strongly recommended for anyone who cannot tolerate loss of the device, even though the verified experiment was performed software-only.
