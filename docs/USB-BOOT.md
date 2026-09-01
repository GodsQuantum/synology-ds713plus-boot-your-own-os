# USB boot on the DS713+

[← README](../README.md) · [Français](USB-BOOT.fr.md) · [Quick start](QUICKSTART.md)

## Two different results must not be confused

### F400 firmware patch only

The verified v0.1.0 experiment removed the Synology `F400:F400` VID/PID restriction. With the internal DOM disconnected, an ordinary `abcd:1234` Debian 13 UEFI drive booted from the **front USB 2.0** port to userspace, network and SSH.

The same drive was then tested on **both rear Etron EJ168A ports** after complete AC power cycles. Neither rear port booted. That negative result remains valid for the **F400-only firmware patch**.

### F400 patch + DS713Bridge v9.1

A later experiment placed the bridge in the front port and the Debian OS medium behind the Etron controller. DS713Bridge v9.1 loaded the validated `XhciDxe`, discovered a rear filesystem below Etron and chainloaded the standard `\EFI\BOOT\BOOTX64.EFI`. Debian reached network/SSH.

This proves rear-controller boot through the bridge. The implementation contains no rear-port hard-code, but this repository does not claim that both physical rear connectors were independently re-run A-to-Z with v9.1.

## Valid test media

Use an x86-64 UEFI installation with a GPT/ESP and preferably the standard fallback loader:

```text
\EFI\BOOT\BOOTX64.EFI
```

A legacy-only GRUB/MBR installation is not a valid negative test of the EFI path.

## Bridge layout

```text
front USB 2.0 : DS713Bridge v9.1
rear Etron    : OS medium with \EFI\BOOT\BOOTX64.EFI
```

Create the bridge with:

```bash
sudo SDX=sdb ./scripts/10-create-usb3-bridge.sh
```

See [Rear USB3 bridge](USB3-BRIDGE.md) for architecture, hashes and measured performance.

### DS713Bridge v9.4 FULL-STACK R2

The F400 firmware patch alone still does not initialize the rear Etron controller for boot. The physically validated v9.4 path is separate: a v9.4 bridge key on the front USB port loads a modern EDK2 xHCI/USB/storage/filesystem stack and successfully boots the existing Linux system SSD from the rear Etron controller to userspace, network and SSH.

Use `scripts/12-create-usb3-bridge-v94.sh` for the current recommended rear-SSD bridge. DS713Bridge v9.1 remains the historical minimal-stack Debian reference.
