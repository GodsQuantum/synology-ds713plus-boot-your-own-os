# Rear USB 3.0 boot bridge — DS713Bridge v9.4

[← Back to README](../README.md) · [Français](USB3-BRIDGE.fr.md) · [v9.4 details](USB3-BRIDGE-V94.md)

## Recommended bridge

**DS713Bridge v9.4 FULL-STACK R2 is the current physically validated bridge for the rear Etron EJ168A path.** On 2026-09-01, a v9.4 key on the DS713+ front USB port successfully booted the current Linux system SSD from a rear Etron port.

v9.4 loads a complete modern EDK2 USB/storage/filesystem stack before chainloading the rear medium:

```text
patched firmware -> front v9.4 key
  -> XhciDxe -> UsbBusDxe -> UsbMassStorageDxe
  -> DiskIoDxe -> PartitionDxe -> EnglishDxe -> Fat
  -> Etron EJ168A -> rear filesystem
  -> \EFI\BOOT\BOOTX64.EFI -> OS
```

Create it with:

```bash
chmod +x scripts/12-create-usb3-bridge-v94.sh
./scripts/12-create-usb3-bridge-v94.sh
```

Exact physically tested writer SHA-256:

```text
6af4b3291f058093a9d2673a51596bb0525b57d5a818587166575f86709f206b
```

See [DS713Bridge v9.4 FULL-STACK R2](USB3-BRIDGE-V94.md) for architecture, hashes, safety gates, EDK2 pins and the on-media layout.

## Historical v9.1 baseline

v9.1 remains the minimal-stack historical reference. It physically booted Debian 13 through the rear Etron controller to network/SSH. The exact known-good v9.1 bridge and XhciDxe hashes remain:

```text
DS713Bridge v9.1 BOOTX64.EFI
2c5a336e52a3d89bcf8029c85818ecbeb2a9477c6dd8367227c7027b5cc833ac

XhciDxe.efi
20c3dbda0e0720fe171a7c0b06c995c4fe319f7338acfb75e9b5ee271a3092b3
```

The v9.1 physical evidence remains controller-level: both physical rear connectors were not independently re-run A-to-Z with v9.1.

That result remains valid and is not overwritten by v9.4. The old writer remains at `scripts/10-create-usb3-bridge.sh` for reproduction/research.

## Runtime verification

A successful UEFI bridge boot and Linux runtime USB behavior are separate layers. After boot, verify from Linux:

- rear SSD sysfs path contains the Etron PCI controller;
- negotiated USB speed is SuperSpeed if the SSD bridge/device supports it;
- current Linux driver is `uas` or `usb-storage` as actually negotiated;
- SMART/TRIM capability;
- network and SSH timing;
- Docker/cgroup/storage-driver readiness.

Do not infer those runtime properties only from the UEFI boot success.
