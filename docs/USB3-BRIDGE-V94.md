# DS713Bridge v9.4 FULL-STACK R2

[← Main rear-USB bridge guide](USB3-BRIDGE.md) · [Français](USB3-BRIDGE-V94.fr.md)

## Status

**Physically validated on DS713+ on 2026-09-01:** a v9.4 bridge key on the front USB port successfully booted the current Linux system SSD through the rear Etron EJ168A controller.

This validation establishes the bridge path itself. Post-boot negotiated USB speed, UAS/BOT selection, SMART/TRIM behavior and power-to-SSH timing are separate Linux runtime properties and should be measured on the running system rather than inferred from the successful UEFI boot.

## Why v9.4 exists

v9.1 proved that rear boot is possible with a modern `XhciDxe`, but the old Granite Well firmware still supplies the upper USB/storage/filesystem stack. That minimal path booted the Debian reference medium, while a later SSD/JMicron setup could be read by UEFI without completing the OS boot.

v9.4 therefore makes one deliberate architectural change: it loads and directly starts a complete modern EDK2 USB/storage/filesystem stack before looking for the rear OS loader.

```text
patched Synology firmware
  -> front bridge key
  -> DS713Bridge v9.4
  -> XhciDxe
  -> UsbBusDxe
  -> UsbMassStorageDxe
  -> DiskIoDxe
  -> PartitionDxe
  -> EnglishDxe
  -> Fat
  -> Etron EJ168A 1b6f:7023
  -> rear filesystem
  -> \EFI\BOOT\BOOTX64.EFI
  -> OS
```

The bridge starts the EDK2 drivers through `EFI_DRIVER_BINDING_PROTOCOL` (`Supported()` + `Start()`) instead of depending on the old firmware's `ConnectController()` behavior.

## Create the bridge key

```bash
chmod +x scripts/12-create-usb3-bridge-v94.sh
./scripts/12-create-usb3-bridge-v94.sh
```

The exact physically tested writer is:

```text
SHA-256  6af4b3291f058093a9d2673a51596bb0525b57d5a818587166575f86709f206b
```

Embedded bridge source:

```text
SHA-256  75e00a082b11dbb9684eb240f77dbdbe3cfde952b90f7e4f8274020432a0ba39
```

The script builds and validates all EFI components before it asks for the destructive `ERASE-/dev/sdX` confirmation. A compilation failure therefore leaves the existing key untouched.

Safety gates include:

- whole USB disk only;
- current system disk rejected;
- zero-size USB devices rejected;
- exact destructive confirmation;
- pinned EDK2 commit verification;
- embedded-source hash verification;
- PE32+ EFI validation of every output;
- read-only FAT fsck after writing.

## Default and experimental EDK2 profiles

Default, physically grounded profile:

```text
edk2-stable202605
b03a21a63e3bd001f52c527e5a57feddb53a690b
```

Validated `XhciDxe.efi` SHA-256:

```text
20c3dbda0e0720fe171a7c0b06c995c4fe319f7338acfb75e9b5ee271a3092b3
```

Normalized rebuild oracle:

```text
ecb9726a4ecd6ce1fe39874b6b8a0e9374bfdcaa08da77fbb3de827bae258e30
```

Experimental only:

```bash
./scripts/12-create-usb3-bridge-v94.sh --latest
```

which pins:

```text
edk2-stable202608
2970e5699ba6267f3384ffab20f96647578aebc8
```

`--latest` is not the default merely because it is newer.

## On-media layout

```text
EFI/BOOT/BOOTX64.EFI
EFI/DS713V94/drivers/XhciDxe.efi
EFI/DS713V94/drivers/UsbBusDxe.efi
EFI/DS713V94/drivers/UsbMassStorageDxe.efi
EFI/DS713V94/drivers/DiskIoDxe.efi
EFI/DS713V94/drivers/PartitionDxe.efi
EFI/DS713V94/drivers/EnglishDxe.efi
EFI/DS713V94/drivers/Fat.efi
startup.nsh
```

The only OS loader path is the standard removable-media path `\EFI\BOOT\BOOTX64.EFI`.

## Policy and boundaries

v9.4 contains no Debian/Ubuntu/Windows/GRUB/shim-specific probing, disk UUID, disk serial, rear-port number, `BootOrder`, or `BootNext` policy.

OS images are loaded with `BootPolicy=TRUE`; a 300-second UEFI watchdog is armed around OS `StartImage()`. The bridge performs no persistent EFI-variable writes.

Once the OS calls `ExitBootServices()`, xHCI/storage ownership belongs to the OS. Therefore a successful v9.4 UEFI boot does not itself prove that Linux negotiated 5 Gbit/s, selected UAS, enabled TRIM, or reached SSH at a particular time. Measure those properties from the running OS.

## Historical baseline

DS713Bridge v9.1 remains important: it is the minimal-stack reference that physically booted Debian 13 behind the Etron controller to network/SSH. v9.4 does not rewrite that history; it is the newer full-stack solution validated for the rear SSD case.
