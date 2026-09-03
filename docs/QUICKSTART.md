# DS713+ quick start

This is the practical path. Reverse-engineering details are in `RESEARCH-HANDOFF.md`.

## A. Download

On a Linux workstation:

```bash
git clone https://github.com/GodsQuantum/synology-ds713plus-boot-your-own-os.git
cd synology-ds713plus-boot-your-own-os
```

## B. Unlock DS713+ firmware once

Requirements: bootable DSM, DSM admin SSH, Linux workstation with Docker or Podman, stable power.

```bash
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

Stop on the first failure.

The actual SPI write remains deliberately separated:

```bash
./scripts/07-flash.sh prepare
./scripts/07-flash.sh status

# only if STATUS=WAITING_FOR_ARM:
./scripts/07-flash.sh arm
./scripts/07-flash.sh status

# mandatory before reboot:
./scripts/08-postflash-verify.sh
```

Reboot only if `READY_FOR_REBOOT=YES`.

## C. Create the DS713Bridge v9.5 key

From the repository directory:

```bash
./scripts/13-create-usb3-bridge-v95.sh
```

The script:

1. lists usable whole USB disks;
2. shows size, model, serial and stable identity;
3. asks for the key number;
4. keeps the target through `/dev/disk/by-id/usb-*`;
5. builds and validates before erasing;
6. asks for explicit destructive confirmation;
7. writes and verifies the key.

## D. Layout

```text
front USB      : DS713Bridge v9.5 key
rear USB       : SSD / flash medium containing the OS
internal SATA  : powered automatically by v9.5 before Linux
```

The rear OS medium must expose:

```text
\EFI\BOOT\BOOTX64.EFI
```

## E. Actual status

- firmware `F400:F400` bypass: verified;
- ordinary front USB boot: verified;
- rear-Etron Linux SSD boot with v9.5: verified;
- pre-Linux SATA power GPIO16 -> 200 ms -> GPIO20: verified;
- internal J2/DOM: tested with v9.4/v9.5, unresolved.

To continue research: `docs/RESEARCH-HANDOFF.md`.
