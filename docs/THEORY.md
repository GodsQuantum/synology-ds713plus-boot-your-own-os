# How the F400 restriction works

The verified DS713+ firmware contains `UsbBusDxe` PE32 under FFS GUID `240612B7-A063-11D4-9A3A-0090273FC14D`. The code loads `0xF400`, compares it with USB descriptor vendor and product IDs, and branches to `EFI_NOT_FOUND` when either differs. NOPing those two six-byte `JNE` instructions keeps normal USB enumeration instead of enforcing the Synology VID/PID pair.

The module lives inside a GUID-defined LZMA-compressed firmware structure. Consequently, a 12-byte semantic patch can cause a hundreds-of-KiB compressed binary diff. This is why erase geometry and physical diff alignment matter.

On the verified ICH10R, `BERASE=1` and flashrom hwseq independently reports 1024 erase blocks of 4096 bytes. The first reference rebuild differed physically from `0x011058` to `0x095d28`, yielding the safe aligned write range `0x011000-0x095fff`, fully within the BIOS region. The scripts recompute this range rather than hard-code it.

## Rear xHCI bridge layer

The F400 patch and the rear bridge solve different layers. F400 changes `UsbBusDxe` policy for USB devices the firmware can already enumerate. The Etron EJ168A rear controller lacks a usable native xHCI boot path in the stock Granite Well firmware.

DS713Bridge v9.1 therefore runs before the rear OS loader, starts the validated `XhciDxe`, filters newly visible filesystems by device-path ancestry below Etron, and chainloads only `\EFI\BOOT\BOOTX64.EFI`. The deployment bridge deliberately avoids replacing the whole storage stack; a later full-stack experiment was slower.

Long-term research aims to dispatch xHCI natively during DXE before BDS, so the firmware itself can enumerate rear storage without a removable bridge.

## v9.5: separate SATA-power layer

Keep these layers separate: the F400 firmware bypass, the v9.4 rear-Etron full stack, the v9.5 SATA-power step, and the still-unresolved J2/DOM path.
