# Bridge de boot USB 3.0 arrière — DS713Bridge v9.1

[← Retour au README](../README.fr.md) · [English](USB3-BRIDGE.md)

## Statut

**DS713Bridge v9.1 est actuellement le bridge amovible physiquement validé pour booter un OS via le contrôleur arrière Etron EJ168A du DS713+.**

Il faut distinguer :

- le patch F400 **seul** ne rend pas les ports arrière bootables ;
- Linux sait utiliser l'Etron après démarrage du kernel ;
- charger `XhciDxe` avant le boot rend un périphérique arrière visible à l'UEFI ;
- v9.1 automatise cela en headless puis chaîne le loader standard du média.

```text
Firmware Synology -> bridge façade -> DS713Bridge v9.1
                   -> XhciDxe -> Etron EJ168A
                   -> filesystem USB arrière
                   -> \EFI\BOOT\BOOTX64.EFI
                   -> Debian 13 -> réseau -> SSH
```

La validation physique est au niveau du contrôleur : un boot Debian via l'Etron arrière a atteint le réseau/SSH. Le code ne contient aucun numéro de port arrière, mais les deux connecteurs physiques n'ont pas chacun été retestés A à Z avec v9.1.

Le bridge est agnostique du bootloader : GRUB, systemd-boot, Limine, rEFInd ou un autre chargeur UEFI x86-64 conviennent dès lors que le média expose `\EFI\BOOT\BOOTX64.EFI`.

## Créer une clé bridge

```bash
sudo SDX=sdb ./scripts/10-create-usb3-bridge.sh
# alternatively: sudo TARGET=/dev/sdb ./scripts/10-create-usb3-bridge.sh
```

Le writer refuse le disque système, une cible non USB et toute cible qui n'est pas un disque entier `/dev/sdX`. Sans `YES=1`, une confirmation destructive exacte est exigée.

La clé finale contient uniquement :

```text
EFI/BOOT/BOOTX64.EFI       DS713Bridge v9.1
EFI/DS713/XhciDxe.efi      driver xHCI
startup.nsh                 fallback Internal Shell si bridge en DOM
```

### Hashes exacts connus fonctionnels

```text
DS713Bridge v9.1 BOOTX64.EFI
2c5a336e52a3d89bcf8029c85818ecbeb2a9477c6dd8367227c7027b5cc833ac

XhciDxe.efi
20c3dbda0e0720fe171a7c0b06c995c4fe319f7338acfb75e9b5ee271a3092b3
```

Si ces fichiers exacts sont déjà présents sur la cible, y compris dans un ancien harness expérimental, le script les conserve avant effacement et les réutilise byte-for-byte.

Pour un nouvel utilisateur qui ne possède pas déjà les binaires exacts testés, le writer reconstruit depuis les sources pinnées. Le résultat est annoncé comme équivalent par source/normalisation, et non comme le PE physiquement testé exact.

Sinon, `XhciDxe` peut être reconstruit depuis EDK2 `edk2-stable202605`, commit `b03a21a63e3bd001f52c527e5a57feddb53a690b`. Le hash PE brut peut différer par métadonnées de build. Après `GenFw -z`, le binaire validé et le rebuild ont été prouvés identiques, SHA-256 normalisé `ecb9726a4ecd6ce1fe39874b6b8a0e9374bfdcaa08da77fbb3de827bae258e30`.

## Politique de boot

**Bridge en façade :** aucun scan d'un second périphérique façade ; initialisation directe de l'Etron puis boot du premier loader standard sous le contrôleur arrière.

**Bridge en DOM interne :** le source implémente recovery façade d'abord puis arrière. Cette politique de placement n'a pas été validée séparément A à Z sur le déploiement physique de référence.

Aucun numéro de port arrière, serial disque, UUID filesystem, nom d'OS, `Boot####`, `BootOrder` ou `BootNext` n'est codé en dur.

## Invariants v9.1

- recherche unique de l'Etron PCI `1b6f:7023` ;
- notification `SimpleFileSystem` enregistrée avant xHCI ;
- chargement du `XhciDxe` validé ;
- exactement deux `ConnectController()` non récursifs ;
- découverte événementielle `WaitForEvent()` ;
- plafond d'échec 30 s uniquement ;
- seuls les filesystems descendants de l'Etron sont acceptés ;
- chainload uniquement de `\EFI\BOOT\BOOTX64.EFI` ;
- anti-récursion par handle source et égalité exacte du device path ;
- aucune écriture persistante de politique de boot NVRAM.

## Performances mesurées

| Configuration | Observation loader / pré-kernel | Power → réseau |
|---|---:|---:|
| shim/GRUB original | baseline | ~232 s |
| Limine + initrd complet | ~169,6 s loader | ~220 s |
| **v9.1 + Limine + initrd minimal** | **56,477 s loader** | **117 s** |
| Firmware façade natif + même payload Limine | ~359,5 s loader | ~423 s |
| V10 expérimental full stack moderne | 95,131 s firmware + 71,316 s loader | ~199 s |

Le meilleur run v9.1 chargeait environ **25,71 Mio** avant kernel. Le débit UEFI effectif était d'environ **0,453 Mio/s**, alors que Linux lisait le même périphérique arrière à environ **18,6 Mio/s** après prise en charge par le kernel. La clé de référence négociait seulement 480 Mbit/s sous Linux ; cela ne démontre donc pas le SuperSpeed de cette clé précise.

## Expériences négatives à conserver

### Full stack EDK2 moderne

Le V10 remplaçait la pile supérieure par `XhciDxe`, `UsbBusDxe`, `UsbMassStorageDxe`, `DiskIoDxe`, `PartitionDxe`, `EnglishDxe` et `EnhancedFatDxe`. Il a booté mais a régressé à environ **199 s** jusqu'au réseau : ce n'est pas le bridge recommandé.

### UKI direct

Un UKI direct n'a pas atteint le réseau après plus de sept minutes. La cause n'est pas prouvée ; compatibilité PE/LoadImage du vieux Tiano et compatibilité systemd-stub restent des hypothèses.

### Harness A/B diagnostics

Les harness de timing/benchmark suivants n'ont pas booté de manière fiable. Ce sont des artefacts de recherche et non des solutions de déploiement.

## Direction long terme

Le bridge doit rester minimal. La prochaine cible est un support xHCI natif firmware : dispatcher un driver xHCI en DXE avant BDS/Boot Manager afin que le DS713+ voie les périphériques arrière comme des disques de boot normaux. La chaîne F400 offre déjà sur la machine de référence un workflow validé dump → rebuild → patch-zone → flash → readback.

En parallèle, il est pertinent de comparer les BIOS UEFI 2011–2012 utilisant eux aussi l'Etron EJ168 avec le `XhciDxe` EDK2 moderne afin d'identifier d'éventuelles initialisations/quirks spécifiques.

## Références externes

- TianoCore EDK2 XhciDxe : https://github.com/tianocore/edk2/tree/master/MdeModulePkg/Bus/Pci/XhciDxe
- Spécifications UEFI / Boot Manager : https://uefi.org/specifications
- Implémentation disque Limine : https://github.com/Limine-Bootloader/Limine/blob/v12.x/common/drivers/disk.s2.c
- OpenCore / XhciDxe sur anciens firmwares : https://dortania.github.io/OpenCore-Install-Guide/installer-guide/opencore-efi.html
