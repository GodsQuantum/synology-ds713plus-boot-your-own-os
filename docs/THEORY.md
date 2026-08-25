# How the F400 restriction works

The verified DS713+ firmware contains `UsbBusDxe` PE32 under FFS GUID `240612B7-A063-11D4-9A3A-0090273FC14D`. The code loads `0xF400`, compares it with USB descriptor vendor and product IDs, and branches to `EFI_NOT_FOUND` when either differs. NOPing those two six-byte `JNE` instructions keeps normal USB enumeration instead of enforcing the Synology VID/PID pair.

The module lives inside a GUID-defined LZMA-compressed firmware structure. Consequently, a 12-byte semantic patch can cause a hundreds-of-KiB compressed binary diff. This is why erase geometry and physical diff alignment matter.

On the verified ICH10R, `BERASE=1` and flashrom hwseq independently reports 1024 erase blocks of 4096 bytes. The first reference rebuild differed physically from `0x011058` to `0x095d28`, yielding the safe aligned write range `0x011000-0x095fff`, fully within the BIOS region. The scripts recompute this range rather than hard-code it.
