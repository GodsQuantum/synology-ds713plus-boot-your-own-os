# Rear USB 3.0 boot bridge — DS713Bridge v9.1

[← Back to README](../README.md) · [Français](USB3-BRIDGE.fr.md)

## Status

**DS713Bridge v9.1 is the current physically validated removable bridge for booting an operating system through the DS713+ rear Etron EJ168A controller.**

The distinction matters:

- the F400 firmware patch **alone** does not make the rear ports bootable;
- Linux can use the Etron controller after kernel startup;
- loading a modern `XhciDxe` before boot makes a rear USB boot device visible to UEFI;
- DS713Bridge v9.1 automates that process headlessly and chainloads the standard removable-media loader.

```text
Synology firmware -> front bridge -> DS713Bridge v9.1
                   -> XhciDxe -> Etron EJ168A
                   -> rear USB filesystem
                   -> \EFI\BOOT\BOOTX64.EFI
                   -> Debian 13 -> network -> SSH
```

The physical validation is controller-level: a rear-Etron Debian boot reached network/SSH. The code contains no rear-port hard-code, but both physical rear connectors were not independently re-run A-to-Z with v9.1.

The bridge is bootloader-agnostic: the rear OS may use GRUB, systemd-boot, Limine, rEFInd, or another x86-64 UEFI loader as long as the medium exposes the standard fallback path `\EFI\BOOT\BOOTX64.EFI`.

## Create a bridge key

```bash
sudo SDX=sdb ./scripts/10-create-usb3-bridge.sh
# alternatively: sudo TARGET=/dev/sdb ./scripts/10-create-usb3-bridge.sh
```

The writer refuses the current system disk, non-USB targets, and anything that is not a whole `/dev/sdX` disk. Unless `YES=1` is supplied it requires an exact destructive confirmation.

The final key contains only:

```text
EFI/BOOT/BOOTX64.EFI       DS713Bridge v9.1
EFI/DS713/XhciDxe.efi      xHCI driver
startup.nsh                 Internal Shell fallback for DOM placement
```

### Exact known-good hashes

```text
DS713Bridge v9.1 BOOTX64.EFI
2c5a336e52a3d89bcf8029c85818ecbeb2a9477c6dd8367227c7027b5cc833ac

XhciDxe.efi
20c3dbda0e0720fe171a7c0b06c995c4fe319f7338acfb75e9b5ee271a3092b3
```

If those exact files already exist on the target, including in an older experimental harness, the writer preserves and reuses them byte-for-byte before erasing the key.

For a fresh user who does not already possess the exact tested binaries, the writer rebuilds from pinned source. A rebuild is reported as source/normalization-equivalent rather than mislabeled as the exact physically tested PE.

If the exact Xhci binary is absent, the writer can rebuild EDK2 `edk2-stable202605` at commit `b03a21a63e3bd001f52c527e5a57feddb53a690b`. The raw PE hash can differ because of build metadata. The validated and rebuilt drivers were proven byte-identical after `GenFw -z` normalization, with normalized SHA-256 `ecb9726a4ecd6ce1fe39874b6b8a0e9374bfdcaa08da77fbb3de827bae258e30`.

## Boot policy

**Bridge in front:** skip front-device scanning, initialize Etron immediately, then boot the first standard loader below the rear controller.

**Bridge in the internal DOM position:** the source implements front-recovery-first, then rear. This placement policy has not been separately validated A-to-Z in the reference physical deployment.

No rear-port number, disk serial, filesystem UUID, OS name, `Boot####`, `BootOrder`, or `BootNext` is hard-coded.

## v9.1 invariants

- find Etron PCI `1b6f:7023` once;
- register `SimpleFileSystem` notification before starting xHCI;
- load/start the proven `XhciDxe`;
- exactly two non-recursive `ConnectController()` calls;
- event-driven discovery with `WaitForEvent()`;
- 30 s failure ceiling only;
- accept only filesystems below Etron;
- chainload only `\EFI\BOOT\BOOTX64.EFI`;
- self-recursion blocked by source handle and exact device-path equality;
- no persistent NVRAM boot-policy writes.

## Measured performance

| Configuration | Loader / pre-kernel observation | Power → network |
|---|---:|---:|
| Original shim/GRUB | baseline | ~232 s |
| Limine + full initrd | ~169.6 s loader | ~220 s |
| **v9.1 + Limine + minimal initrd** | **56.477 s loader** | **117 s** |
| Native front firmware + same Limine payload | ~359.5 s loader | ~423 s |
| Experimental V10 full modern stack | 95.131 s firmware + 71.316 s loader | ~199 s |

The best v9.1 run loaded about **25.71 MiB** before the kernel. Effective UEFI throughput was about **0.453 MiB/s**, while Linux read the same rear device at about **18.6 MiB/s** after kernel takeover. The reference flash drive itself negotiated only 480 Mbit/s under Linux, so this does not demonstrate SuperSpeed for that specific drive.

## Negative experiments worth preserving

### Full modern EDK2 storage stack

A V10 experiment replaced the upper stack with `XhciDxe`, `UsbBusDxe`, `UsbMassStorageDxe`, `DiskIoDxe`, `PartitionDxe`, `EnglishDxe`, and `EnhancedFatDxe`. It booted but regressed to about **199 s power-to-network**, so it is not the recommended bridge.

### Direct UKI

A direct UKI did not reach the network after more than seven minutes. The cause was not proven; old Tiano PE/LoadImage compatibility and systemd-stub compatibility remain hypotheses only.

### Diagnostic A/B harnesses

Later timing/benchmark harnesses did not boot reliably on this firmware. They are research artifacts, not deployment candidates.

## Long-term direction

The bridge should stay minimal. The next research target is firmware-native xHCI support: insert or otherwise dispatch an xHCI driver during DXE, before BDS/Boot Manager, so the DS713+ sees rear storage as a normal firmware boot device. The existing F400 workflow already provides a verified dump → rebuild → patch-zone → flash → readback path on the reference machine.

A parallel research path is comparing contemporary 2011–2012 UEFI firmware using the Etron EJ168 with modern EDK2 `XhciDxe` to identify controller-specific initialization or quirks.

## External references

- TianoCore EDK2 XhciDxe: https://github.com/tianocore/edk2/tree/master/MdeModulePkg/Bus/Pci/XhciDxe
- UEFI specifications / Boot Manager: https://uefi.org/specifications
- Limine disk implementation: https://github.com/Limine-Bootloader/Limine/blob/v12.x/common/drivers/disk.s2.c
- OpenCore old-firmware XhciDxe guidance: https://dortania.github.io/OpenCore-Install-Guide/installer-guide/opencore-efi.html
