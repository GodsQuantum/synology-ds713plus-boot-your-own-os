# Verified hardware matrix

[← Back to README](../README.md) · [Français](VERIFIED-HARDWARE.fr.md)

## DS713+ reference unit

| Platform / port | Status | Evidence |
|---|---|---|
| DS713+ firmware dump / patch / flash | **✅ VERIFIED** | Double dump, candidate validation, ICH10R hwseq write, candidate verify, two full BIOS-region verifies, successful reboot. |
| DS713+ — front USB 2.0 | **✅ VERIFIED** | Non-F400 `abcd:1234` drive; Debian 13 UEFI booted with internal DOM disconnected; network + SSH reached. |
| DS713+ — internal USB/DOM path | ⚠️ UNVERIFIED REPLACEMENT | Related Intel USB2 path, but arbitrary replacement DOM/device boot has not been separately validated. |
| DS713+ — rear USB3 Etron EJ168A, port 1 | **❌ NOT BOOTABLE WITH CURRENT PATCH** | Same known-good Debian USB, full AC cold boot, no normal read activity / DHCP / SSH boot. |
| DS713+ — rear USB3 Etron EJ168A, port 2 | **❌ NOT BOOTABLE WITH CURRENT PATCH** | Same negative result on the second rear port; front-port cold retest succeeded. |
| DS713+ — Etron USB3 after Linux boot | **✅ WORKS IN LINUX** | Debian sees/uses the controller through `xhci_hcd`; this does not imply firmware boot support. |

## OS status

| OS | Status on DS713+ |
|---|---|
| Debian 13 amd64 | **✅ VERIFIED** from front USB2 to userspace + network + SSH |
| OpenMediaVault 8 | 🟢 Strong candidate; Debian 13 based; not yet A-to-Z tested by this repo |
| Ubuntu Server 26.04 LTS | 🟢 Plausible candidate; not yet tested by this repo |
| Current TrueNAS | 🔴 Not recommended; current 8 GB RAM baseline exceeds D2700 4 GB maximum |

## Related Synology research targets

These models are **not verified by this repository**.

| Model(s) | Synology last OS branch | Repo status |
|---|---:|---|
| DS1513+ / DS1813+ / DS2413+ | DSM 7.1 | ❓ Granite Well/Cedarview-era research targets |
| DS412+ / DS1512+ / DS1812+ | DSM 6.2 | ❓ Related generation / community prior art |
| RS812+ / related x12 units | DSM 6.2 | ❓ Related generation / unverified |

A related platform name is not enough to authorize a write.

Each model/revision needs its own:

1. chipset / PCI identification;
2. flash size and descriptor map;
3. BIOS permissions;
4. erase geometry;
5. double firmware dump;
6. module/patch semantic validation;
7. model-specific safe profile.

Use the hardware-report issue form for probe/dump evidence.

## Reference hashes

The verified DS713+ unit produced two byte-identical 2 MiB BIOS reads:

```text
<reference-unit-sha256-redacted>
```

This is **historical evidence, not a universal compatibility hash**.

The manually audited first candidate had SHA-256:

```text
<reference-unit-sha256-redacted>
```

A valid rebuild can differ at compressed-byte level. Semantic/structural verification and a correctly calculated physical patchzone matter more than matching this candidate hash.
