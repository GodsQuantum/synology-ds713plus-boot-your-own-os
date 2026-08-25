# Verified hardware matrix

| Platform / port | Status | Evidence |
|---|---|---|
| Synology DS713+ — front USB2 | **✅ VERIFIED** | Non-F400 `abcd:1234` flash drive; Debian 13 UEFI booted with internal DOM disconnected; SSH reached successfully after BIOS patch. |
| Synology DS713+ — internal USB/DOM path | ⚠️ Expected | Same Intel USB2 firmware path is targeted, but an arbitrary non-F400 replacement has not been separately documented yet. |
| Synology DS713+ — rear USB3 (Etron EJ168A), both ports | **❌ NOT BOOTABLE WITH CURRENT PATCH** | Same known-good `abcd:1234` Debian 13 UEFI drive tested on both rear ports after full AC power removal. No normal USB read activity and no DHCP/SSH boot. The drive still boots from front USB2 after a cold boot. Linux does operate the EJ168A through `xhci_hcd` once the kernel has booted from another device. |
| DS412+/DS1512+/DS1812+/DS1513+/DS1813+/DS2413+/related | ❓ UNVERIFIED BY THIS REPO | Granite Well family relationship/community research only. Require model-specific probe + firmware validation. |

## Tested DS713+ reference values

The verified unit produced two byte-identical 2 MiB BIOS reads with SHA-256 `<reference-unit-sha256-redacted>`. This hash is **reference evidence, not a compatibility requirement**; firmware revisions can legitimately differ.

The manually verified reference candidate used during the first successful experiment had SHA-256 `<reference-unit-sha256-redacted>`. An automated UEFIPatch rebuild can produce different compressed bytes; semantic and structural verification is more important than matching the reference hash.
