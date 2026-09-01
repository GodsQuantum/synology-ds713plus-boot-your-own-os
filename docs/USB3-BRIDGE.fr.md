# Bridge de boot USB 3.0 arrière — DS713Bridge v9.4

[← Retour au README](../README.fr.md) · [English](USB3-BRIDGE.md) · [Détails v9.4](USB3-BRIDGE-V94.fr.md)

## Bridge recommandé

**DS713Bridge v9.4 FULL-STACK R2 est désormais le bridge physiquement validé recommandé pour le chemin Etron EJ168A arrière.** Le 1er septembre 2026, une clé v9.4 en USB façade du DS713+ a démarré avec succès le SSD système Linux placé sur un port Etron arrière.

v9.4 charge avant l'OS une pile EDK2 USB/storage/filesystem moderne complète :

```text
firmware patché -> clé v9.4 façade
  -> XhciDxe -> UsbBusDxe -> UsbMassStorageDxe
  -> DiskIoDxe -> PartitionDxe -> EnglishDxe -> Fat
  -> Etron EJ168A -> filesystem arrière
  -> \EFI\BOOT\BOOTX64.EFI -> OS
```

Création :

```bash
chmod +x scripts/12-create-usb3-bridge-v94.sh
./scripts/12-create-usb3-bridge-v94.sh
```

SHA-256 du script exact validé physiquement :

```text
6af4b3291f058093a9d2673a51596bb0525b57d5a818587166575f86709f206b
```

Voir [DS713Bridge v9.4 FULL-STACK R2](USB3-BRIDGE-V94.fr.md) pour l'architecture, les hashes, les protections, les commits EDK2 et le contenu exact de la clé.

## Référence historique v9.1

v9.1 reste la référence minimal-stack historique ayant démarré physiquement Debian 13 derrière l'Etron jusqu'au réseau/SSH. Son `XhciDxe` validé reste :

```text
20c3dbda0e0720fe171a7c0b06c995c4fe319f7338acfb75e9b5ee271a3092b3
```

L'ancien writer `scripts/10-create-usb3-bridge.sh` reste disponible pour reproduction/recherche.

## Vérification runtime

Le succès du bridge UEFI ne suffit pas à prouver les propriétés Linux après `ExitBootServices()`. Il faut mesurer sous Linux : chemin sysfs derrière l'Etron, vitesse USB négociée, driver `uas`/`usb-storage`, SMART/TRIM, temps réseau/SSH et état Docker/cgroups/storage driver.
