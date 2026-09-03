# Current DS713+ research status

| Layer | Status |
|---|---|
| `F400:F400` bypass | ✅ Verified |
| non-F400 front USB2 | ✅ Verified |
| rear Etron with F400 patch only | ❌ Not bootable |
| rear Etron through v9.1 | ✅ Debian verified |
| rear Etron through v9.4 | ✅ Linux SSD verified |
| rear Etron through v9.5 | ✅ Verified |
| pre-OS SATA power | ✅ Verified with v9.5 |
| bay 1 / bay 2 GPIO | ✅ GPIO16 / GPIO20 |
| J2/DOM with v9.4 | ❌ Negative test |
| J2/DOM with v9.5 | ❌ Negative test |
| exact J2 cause | 🔬 Unknown |
| xHCI integrated directly in firmware | 🔬 Research |
| eliminating the bridge key | 🔬 Research |

Priority contributions: J2 VBUS/reset/enable, serial UEFI logs, DXE/BDS enumeration order, possible separate internal-DOM boot path, and native xHCI/SATA-power integration.
