# DS713+ reference experiment — 2026-08-25

These values document the first fully verified DS713+ experiment. They are **not** generic compatibility requirements unless explicitly enforced by `profiles/ds713plus.env`.

## Firmware reads

```text
BIOS read #1/#2, 2 MiB:
<reference-unit-sha256-redacted>

IFD-defined-region carrier read #1/#2, 4 MiB container:
<reference-unit-sha256-redacted>
```

The 4 MiB container is **not a physical full-chip dump**. Hardware sequencing faults at `0x211000`, after the defined BIOS region.

## Manually audited first candidate

```text
2 MiB candidate SHA-256:
<reference-unit-sha256-redacted>

4 MiB carrier SHA-256:
<reference-unit-sha256-redacted>
```

Physical diff after LZMA reconstruction:

```text
DIFF_BYTES_TOTAL=541738
DIFF_FIRST_PHYSICAL=0x011058
DIFF_LAST_PHYSICAL=0x095d28
PATCH_START=0x011000
PATCH_END=0x095fff
PATCH_SIZE=544768
PATCH_INSIDE_BIOS=YES
```

The repository recalculates these values for every user's dump. A different valid compressed reconstruction may have different physical bytes and therefore a different safe patchzone.

## Write verification

The first write completed with `FINAL_STATUS=SUCCESS_CANDIDATE_VERIFIED`. The selected patchzone verified independently, then the complete BIOS region `0x011000-0x210fff` (2 MiB) verified twice before reboot.

After reboot DSM operated normally. With the internal DOM disconnected, an ordinary UEFI Debian 13 USB flash drive with VID:PID `abcd:1234` booted from the front USB2 port and became reachable by SSH.

## Physical USB boot matrix

Using the same Debian 13 UEFI flash drive (`abcd:1234`) with the internal DOM disconnected:

- **Front USB2:** booted successfully to Debian userspace and SSH.
- **Rear USB3 port 1 (Etron EJ168A):** no normal USB read activity and no Debian DHCP/SSH boot after a complete AC power cycle.
- **Rear USB3 port 2 (Etron EJ168A):** same negative result after a complete AC power cycle.
- **Front USB2 retest:** successful again after a cold boot, confirming the drive and Debian installation remained bootable.

The rear-port negative result is specific to the current **F400-only** firmware modification. The Etron controller is visible and usable from Debian through `xhci_hcd` after Linux has booted from the front port. No `XhciDxe` firmware driver was added by this patch.
