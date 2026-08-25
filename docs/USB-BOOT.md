# USB boot test

For the clearest post-flash test on DS713+:

1. verify and reboot DSM once after flashing;
2. shut down cleanly;
3. disconnect AC power long enough to fully reset the platform;
4. temporarily disconnect the internal Synology DOM;
5. insert a known-good **x86-64 UEFI** USB device in the front USB2 port;
6. power on and look for DHCP/SSH or other OS-specific evidence.

A legacy-only GRUB/MBR installation is not a valid negative test of the EFI patch. Prefer a GPT/ESP install containing `EFI/BOOT/BOOTX64.EFI` or another boot path the firmware can resolve.

## Rear Etron USB3 result

Both rear USB3 ports on the verified DS713+ were tested with the same ordinary `abcd:1234` Debian 13 UEFI flash drive that successfully boots from the front USB2 port. Each rear-port test was performed after a clean OS shutdown followed by complete AC power removal. Neither rear port showed the normal USB read activity seen during front-port boot, and no Debian DHCP/SSH boot appeared. A subsequent cold boot from the front port succeeded again.

This is therefore a **negative rear-boot result for the current F400-only patch**, not a failure of the F400 unlock itself. The rear ports are attached to an Etron EJ168A xHCI controller; Linux can use that controller through `xhci_hcd` after the kernel is already running. The current BIOS patch only removes the F400 VID/PID rejection and does **not** add an `XhciDxe` firmware driver. Adding/testing an EFI xHCI driver is a separate future experiment.
