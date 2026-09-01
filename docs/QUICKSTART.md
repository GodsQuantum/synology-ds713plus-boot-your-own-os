# DS713+ quick start — F400 unlock + rear USB3 bridge

[← README](../README.md) · [Français](QUICKSTART.fr.md) · [Safety](SAFETY.md)

This is the shortest supported path for the **verified DS713+ profile**. Firmware flashing can brick hardware. Do not skip safety gates.

## Phase A — unlock ordinary USB devices in firmware

### Prerequisites

- a **Synology DS713+** that still boots DSM;
- a Linux workstation with `git`, `ssh`, `python3`, `bash`, and Docker or Podman;
- a DSM administrator account that can run `sudo`;
- stable power; a UPS is strongly recommended;
- this repository cloned on the Linux workstation.

The firmware scripts intentionally target **DSM while DSM is still running**. Do not run steps 00–08 against the later Debian/OMV installation.

```bash
git clone https://github.com/GodsQuantum/synology-ds713plus-boot-your-own-os.git
cd synology-ds713plus-boot-your-own-os

export NAS_HOST='192.168.1.x'
export NAS_USER='your-dsm-admin'

./scripts/00-build-flashrom.sh
./scripts/01-install-flashrom.sh
./scripts/02-probe.sh
./scripts/03-dump.sh
./scripts/04-build-uefi-tools.sh
./scripts/05-patch-bios.sh artifacts/bios-read1.bin
./scripts/06-preflight.sh
```

Stop if any command fails. `02-probe.sh` must report `PROBE_SAFE_PROFILE=YES`; `06-preflight.sh` must complete successfully.

### Real SPI write

The write is deliberately separated from preparation:

```bash
./scripts/07-flash.sh prepare
./scripts/07-flash.sh status

# Continue only when the status is exactly STATUS=WAITING_FOR_ARM
./scripts/07-flash.sh arm

# Repeat until a FINAL_STATUS appears
./scripts/07-flash.sh status

# Required before reboot
./scripts/08-postflash-verify.sh
```

Do **not** reboot until the final command prints:

```text
READY_FOR_REBOOT=YES
```

If a status says `FINAL_STATUS=CRITICAL_DO_NOT_REBOOT`, keep the NAS powered and read [Recovery](RECOVERY.md).

## Phase B — create the rear USB3 bridge

The F400 patch makes an ordinary front USB boot device acceptable. It does **not**, by itself, initialize the rear Etron EJ168A xHCI controller.

If you want the OS medium on a rear port, create a second small USB key as the bridge from a Linux workstation:

```bash
lsblk -o NAME,PATH,TRAN,SIZE,FSTYPE,LABEL,MODEL,SERIAL,MOUNTPOINTS

# Example only: replace sdb with the USB key you intend to ERASE.
sudo SDX=sdb ./scripts/12-create-usb3-bridge-v94.sh
```

The writer refuses the current system disk, non-USB targets and non-whole-disk targets, then asks for an exact destructive confirmation.

### Physical layout

```text
front USB 2.0 : DS713Bridge v9.1 key
rear Etron    : your OS medium
```

The rear medium must boot as x86-64 UEFI and expose the standard fallback path:

```text
\EFI\BOOT\BOOTX64.EFI
```

This is bootloader-agnostic: GRUB, systemd-boot, Limine, rEFInd and other standard UEFI loaders can work behind the bridge.

## What is verified

- F400 firmware unlock: front non-F400 Debian 13 boot to network/SSH.
- F400-only rear boot: negative on both rear ports.
- DS713Bridge v9.1: rear-Etron Debian 13 boot to network/SSH.
- Bridge code: no OS UUID, disk serial, rear-port number, `BootOrder` or `BootNext` hard-code.

See [Verified hardware](VERIFIED-HARDWARE.md) and [Rear USB3 bridge](USB3-BRIDGE.md) for the exact evidence and hashes.
