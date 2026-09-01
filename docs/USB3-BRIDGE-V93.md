# DS713Bridge v9.3 candidate

DS713Bridge v9.3 is a conservative candidate successor to the physically validated v9.1 bridge. It deliberately preserves the v9.1 Etron/XhciDxe fast path and does **not** replace v9.1 as the reference until a real DS713+ cold-boot validation succeeds.

## Changes from v9.1

- explicit bridge-source classification: `FRONT`, `DOM`, or `UNKNOWN`;
- `UNKNOWN` uses the conservative rear-direct path instead of being treated implicitly as DOM;
- a loader that returns from `StartImage()` is treated as a failed candidate, so another eligible filesystem can be tried;
- `EFI_SECURITY_VIOLATION` with a returned image handle is cleaned up correctly;
- synchronous protocol notifications are drained and already-existing rear SimpleFS handles are scanned once before the event-driven wait loop;
- the validated xHCI connection invariant remains exactly two non-recursive `ConnectController()` calls;
- no `BootOrder`, `BootNext`, persistent NVRAM policy, rear-port number, OS name, UUID, or arbitrary EFI-file scan is introduced.

## Create the bridge key

Run as root. If no target is supplied, the script lists detected USB disks and asks for the whole-disk device path.

```bash
sudo ./scripts/11-create-usb3-bridge-v93.sh
```

Non-interactive target selection is also supported:

```bash
sudo TARGET=/dev/sdX ./scripts/11-create-usb3-bridge-v93.sh
sudo SDX=sdX ./scripts/11-create-usb3-bridge-v93.sh
sudo ./scripts/11-create-usb3-bridge-v93.sh /dev/sdX
```

The chosen disk is erased only after the script verifies that it is a whole USB disk, rejects the current system disk, displays its identity, and receives the exact destructive confirmation (unless `YES=1` is explicitly supplied).

The final key contains exactly:

```text
EFI/BOOT/BOOTX64.EFI       DS713Bridge v9.3 candidate
EFI/DS713/XhciDxe.efi      validated or normalization-equivalent XhciDxe
startup.nsh                 shell fallback
```

The XhciDxe oracle remains EDK2 `edk2-stable202605`, commit `b03a21a63e3bd001f52c527e5a57feddb53a690b`, exact validated SHA-256 `20c3dbda0e0720fe171a7c0b06c995c4fe319f7338acfb75e9b5ee271a3092b3`, normalized SHA-256 `ecb9726a4ecd6ce1fe39874b6b8a0e9374bfdcaa08da77fbb3de827bae258e30`.

## Promotion gate

Do not relabel v9.3 as physically validated until a cold boot from the intended bridge placement reaches the rear OS and network/SSH, with failure-path testing on the alternate rear medium where practical.
