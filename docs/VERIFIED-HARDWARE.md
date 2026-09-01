# Verified hardware matrix

[← README](../README.md) · [Français](VERIFIED-HARDWARE.fr.md)

## DS713+ reference unit

| Platform / path | Status | Evidence |
|---|---|---|
| Firmware dump → patch → flash | **✅ VERIFIED** | Double dump, exact ICH10R profile, dynamic patchzone, candidate verify, two full BIOS-region verifies, successful reboot. |
| Front USB 2.0 after F400 unlock | **✅ VERIFIED** | Ordinary non-F400 `abcd:1234` Debian 13 UEFI drive → userspace → network → SSH. |
| Rear Etron, F400 patch only | **❌ NOT BOOTABLE** | Both physical rear ports tested independently after full AC cold boots with the same known-good Debian drive. |
| Rear Etron through DS713Bridge v9.1 | **✅ VERIFIED** | Bridge in front + Debian medium behind Etron → standard EFI loader → Debian 13 → network/SSH. |
| Rear Etron through DS713Bridge v9.4 FULL-STACK R2 | **✅ VERIFIED** | Bridge in front + existing Ubuntu/Linux system SSD behind Etron → full modern EDK2 xHCI/USB/storage stack → network/SSH. |
| v9.1 physical connector coverage | **⚠️ CONTROLLER-LEVEL EVIDENCE** | Bridge code is rear-port agnostic; both rear connectors were not independently re-run A-to-Z with v9.1. |
| Etron after Linux takeover | **✅ VERIFIED** | Linux uses EJ168A through `xhci_hcd`. Reference flash medium negotiated 480 Mbit/s; that medium does not prove SuperSpeed. |
| Internal DOM replacement / bridge placement | **⚠️ POLICY IMPLEMENTED, NOT SEPARATELY A-TO-Z VERIFIED** | v9.1 contains front-recovery-then-rear policy for DOM placement; current deployment evidence is front bridge → rear OS. |

## OS status

| OS | Status on DS713+ |
|---|---|
| Debian 13 amd64 | **✅ VERIFIED** from front USB2 and via rear Etron using v9.1 bridge |
| OpenMediaVault 8 | 🟢 Strong candidate; Debian 13 based; not yet A-to-Z validated by this repository |
| Ubuntu Server 26.04 LTS | **✅ Existing installed system boot verified** via rear Etron with v9.4; installer path not separately validated |
| Current TrueNAS | 🔴 Not recommended; current 8 GB RAM baseline exceeds the D2700 4 GB maximum |

## Related Synology research targets

DS1513+/DS1813+/DS2413+, DS412+/DS1512+/DS1812+, RS812+ and related Cedarview/Granite Well machines are **research targets only**. A similar platform name does not authorize flashing a DS713+ profile.

Each model/revision needs its own chipset identification, flash map, permissions, erase geometry, double dump, semantic patch validation and safe profile.

## Reference hashes

Reference-unit BIOS and candidate digests are intentionally not published because they are unit-specific evidence, not compatibility constants.

Known-good bridge artifacts from the physical v9.1 and v9.4 experiments:

```text
DS713Bridge v9.1  2c5a336e52a3d89bcf8029c85818ecbeb2a9477c6dd8367227c7027b5cc833ac
XhciDxe            20c3dbda0e0720fe171a7c0b06c995c4fe319f7338acfb75e9b5ee271a3092b3
DS713Bridge v9.4 writer  6af4b3291f058093a9d2673a51596bb0525b57d5a818587166575f86709f206b
DS713Bridge v9.4 source  75e00a082b11dbb9684eb240f77dbdbe3cfde952b90f7e4f8274020432a0ba39
```

The bridge hashes above identify reproducible software artifacts; hardware compatibility still comes from the safety probes and actual boot evidence.
