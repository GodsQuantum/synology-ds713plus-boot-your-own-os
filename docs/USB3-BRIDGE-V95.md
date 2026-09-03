# DS713Bridge v9.5 — pre-OS SATA power

> **Status: physically validated on DS713+.** v9.5 is now the recommended bridge for new deployments.

## Why v9.5 exists

On the DS713+, a generic Linux kernel can load `ahci` and `sata_sil24` correctly while both internal bays remain electrically off. Synology's Cedarview kernel sources show that HDD power is platform-specific behavior that a generic kernel does not reproduce.

Synology's Cedarview mapping uses GPIO16 for disk/bay 1 and GPIO20 for disk/bay 2. For the DS713+ all-disk power-on path, the first bay is enabled and the second follows after a 200 ms stagger.

This mapping has been confirmed on DS713+ hardware: asserting lines 16 and 20 through `gpio_ich` physically spun up both HDDs and Linux then enumerated their SATA links.

## Design

v9.5 preserves the physically validated **v9.4 FULL-STACK R2 USB/storage/filesystem payload unchanged** and changes only the bridge-key `BOOTX64.EFI` application.

```text
Synology UEFI
  -> DS713Bridge v9.5
     -> locate Intel LPC/ISA at 0000:00:1f.0
     -> read GPIOBASE (PCI config 0x48)
     -> verify/enable GPIO I/O decode (PCI config 0x4c, bit 0x10)
     -> require GPIO16/GPIO20 to already be selected as GPIO
     -> GPIO16 output high
     -> wait 200 ms
     -> GPIO20 output high
  -> initialize unchanged v9.4 FULL-STACK R2 EDK2 payload
  -> discover Etron EJ168A
  -> chainload rear-media \\EFI\\BOOT\\BOOTX64.EFI
  -> Linux starts with both internal HDDs already powered
```

## Safety properties

v9.5 does not blindly repurpose pin muxing. If `GPIO_USE_SEL` does not already expose GPIO16/20 as GPIO, the application refuses the operation. It also checks PCI location, Intel vendor ID and ISA-bridge class before touching legacy GPIO I/O registers.

No persistent UEFI variables (`BootOrder`, `BootNext`, etc.) are written. If the GPIO stage fails or refuses unexpected pin muxing, the bridge is **fail-open for boot** and continues through the v9.4 path so a SATA-power anomaly cannot turn into a NAS boot failure.

## Files

```text
bridge/DS713Bridge-v9.5.c
bridge/test_v95_static.py
scripts/13-create-usb3-bridge-v95.sh
```

The v9.5 creator first invokes the existing v9.4 creator so the validated FULL-STACK R2 payload is rebuilt unchanged. It then builds only the v9.5 application with `IoLib` and replaces `EFI/BOOT/BOOTX64.EFI`. Driver files remain under `EFI/DS713V94/drivers/` so their provenance stays exactly v9.4.

## Hardware validation criteria

A v9.5 promotion requires a true cold boot with both HDDs installed, no Linux GPIO helper, both HDDs immediately visible over SATA, GPIO16/20 observed high after boot, rear-USB boot behavior unchanged from v9.4, and no NVRAM changes.


## Physical validation obtained — 2026-09-03

```text
bridge key              v9.5 on front USB
OS medium               existing Linux system SSD behind rear Etron
boot                    Linux / network / SSH
SATA power              automatic before Linux
sequence                GPIO16 -> 200 ms -> GPIO20
manual Linux GPIO       not required to make the bays appear
```

SHA-256 of the tested key's `BOOTX64.EFI`:

```text
eae1c93e208495fe81b279b1663a1747367548a7735076e25fa9266097515fa6
```

J2/DOM was tested separately: v9.4 and v9.5 did not boot from J2, while the same v9.5 media works from front USB. The tested firmware already contained the validated `F400:F400` bypass, so J2 failure must not be reduced to that whitelist.
