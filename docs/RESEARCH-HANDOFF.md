# DS713+ reverse-engineering handoff

This file is deliberately dense so another engineer or a new agent session can continue from the current evidence.

## Platform

```text
Synology DS713+
Intel Atom D2700 / Cedarview
Intel ICH10 AHCI
rear USB3 controller: Etron EJ168A 1b6f:7023
```

## Firmware unlock already established

Target module:

```text
UsbBusDxe
FFS GUID 240612B7-A063-11D4-9A3A-0090273FC14D
```

Validated rejection-branch patch:

```text
+0x2991  0F 85 17 03 00 00 -> 90 90 90 90 90 90
+0x299B  0F 85 0D 03 00 00 -> 90 90 90 90 90 90
```

The repository never distributes a proprietary Synology BIOS image.

## Physical boot evidence

```text
F400 patch + front ordinary USB     -> PASS
F400 patch alone + rear Etron       -> FAIL
v9.1 front bridge + rear Debian     -> PASS
v9.4 front bridge + rear Linux SSD  -> PASS
v9.5 front bridge + rear Linux SSD  -> PASS
v9.4 on internal J2/DOM             -> FAIL
v9.5 on internal J2/DOM             -> FAIL
same v9.5 returned to front USB     -> PASS
```

## v9.5 SATA-power evidence

Synology Cedarview source:

```text
CONFIG_SYNO_CEDARVIEW=y
CONFIG_SYNO_ICH_GPIO_CTRL=y
CONFIG_SYNO_ATA_PWR_CTRL=y
HddEnPinMap[] = {16, 20, 21, 32}
HW_DS713p handled by SYNO_CTRL_HDD_POWERON
```

Reference DS713+ mapping:

```text
bay 1 -> GPIO16
bay 2 -> GPIO20
```

Manual Linux GPIO testing proved the two lines power their corresponding bays.

v9.5 performs before OS handoff:

```text
ICH10 LPC discovery
GPIOBASE from PCI config offset 0x48
GPIO16 HIGH
wait 200 ms
GPIO20 HIGH
```

Then it preserves the v9.4 FULL-STACK R2 EDK2 rear-USB path.

Pinned EDK2:

```text
edk2-stable202605
b03a21a63e3bd001f52c527e5a57feddb53a690b
```

Physically tested v9.5 BOOTX64 SHA-256:

```text
eae1c93e208495fe81b279b1663a1747367548a7735076e25fa9266097515fa6
```

## Writer safety finding

During a real USB-key build, USB re-enumeration changed a `/dev/sdX` assignment.

The public writers must therefore preserve a stable identity and re-check it just before destruction:

```text
select whole USB disk
derive /dev/disk/by-id/usb-* identity
keep stable identity through build
re-resolve before destructive phase
re-check whole disk / USB / non-zero size / not system disk
```

## Internal J2 / DOM

Tested wiring:

```text
pin 2  = +5 V
pin 4  = D-
pin 6  = D+
pin 8  = GND
pin 10 = unused for this USB channel
```

Because the tested firmware already contains the F400 bypass, the J2 failure must not be explained simply as a non-F400 VID/PID problem.

Priority questions:

1. Is J2 VBUS present early enough for firmware enumeration?
2. Is there a J2-specific reset/enable line?
3. Is the internal DOM enumerated before or separately from patched `UsbBusDxe`?
4. Is there a distinct BDS/internal-DOM boot policy?
5. Can serial output distinguish electrically absent from enumerated/rejected?
6. Can xHCI and SATA-power support be integrated directly in firmware?

Evidence labels:

```text
VERIFIED   physically observed
NEGATIVE   physically tested and failed
SOURCE     established from source/code inspection
HYPOTHESIS plausible but not established
```
