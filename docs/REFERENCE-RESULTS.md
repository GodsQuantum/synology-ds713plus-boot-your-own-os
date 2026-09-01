# DS713+ reference experiment — 2026-08-25

These values document the first fully verified DS713+ experiment. They are **not** generic compatibility requirements unless explicitly enforced by `profiles/ds713plus.env`.

## Firmware reads

The reference-unit SHA-256 digests are intentionally not published. They are unit-specific evidence, not compatibility constants; each user must validate their own double dump locally.

The 4 MiB container is **not a physical full-chip dump**. Hardware sequencing faults at `0x211000`, after the defined BIOS region.

## Manually audited first candidate

The reference-unit candidate and carrier digests are intentionally not published. The repository derives and verifies each user's candidate from that user's own firmware dump.

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

## Bridge experiment — 2026-08-27

The later rear-boot experiment kept the F400 firmware modification unchanged and added a removable front bridge only.

```text
DS713Bridge v9.1 BOOTX64.EFI
2c5a336e52a3d89bcf8029c85818ecbeb2a9477c6dd8367227c7027b5cc833ac

XhciDxe.efi
20c3dbda0e0720fe171a7c0b06c995c4fe319f7338acfb75e9b5ee271a3092b3
```

Result: **Debian 13 booted from storage behind the Etron controller to network/SSH.** The bridge itself took roughly 3–4 s before handing off to the rear OS loader.

Best measured reference with Limine + reduced initrd:

```text
firmware   14.600 s
loader     56.477 s
kernel      5.483 s
userspace  21.203 s
systemd     1m37.765s total
external power-to-network  ~117 s
```

About 25.71 MiB was loaded before the kernel. Effective pre-kernel UEFI throughput was ~0.453 MiB/s; Linux read the same rear medium at ~18.6 MiB/s after takeover. Native front-firmware Limine loading was worse (~359.5 s loader / ~423 s power-to-network), so “native front” was not a speed solution.

An experimental full modern EDK2 storage stack booted but regressed to ~199 s power-to-network. Direct UKI and later diagnostic harnesses did not produce a reliable deployment path. They remain research results, not recommendations.

## DS713Bridge v9.4 FULL-STACK R2 — physical validation (2026-09-01)

- front USB: v9.4 bridge key;
- rear Etron: existing Ubuntu/Linux system SSD;
- result: OS reached userspace, network and SSH;
- exact creator SHA-256: `6af4b3291f058093a9d2673a51596bb0525b57d5a818587166575f86709f206b`;
- embedded source SHA-256: `75e00a082b11dbb9684eb240f77dbdbe3cfde952b90f7e4f8274020432a0ba39`;
- default EDK2 profile: `edk2-stable202605` / `b03a21a63e3bd001f52c527e5a57feddb53a690b`;
- full stack: `XhciDxe`, `UsbBusDxe`, `UsbMassStorageDxe`, `DiskIoDxe`, `PartitionDxe`, `EnglishDxe`, `Fat`;
- negotiated USB speed/UAS/TRIM and exact power-to-SSH timing are measured separately after Linux boot.
