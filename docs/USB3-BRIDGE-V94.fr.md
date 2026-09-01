# DS713Bridge v9.4 FULL-STACK R2

[← Guide principal du bridge USB arrière](USB3-BRIDGE.fr.md) · [English](USB3-BRIDGE-V94.md)

## Statut

**Validé physiquement sur DS713+ le 1er septembre 2026 :** une clé bridge v9.4 en USB façade a démarré avec succès le SSD système Linux placé derrière le contrôleur Etron EJ168A arrière.

Cette validation établit le chemin de boot du bridge. La vitesse USB négociée après boot, le choix UAS/BOT, SMART/TRIM et le temps alimentation→SSH sont des propriétés Linux distinctes à mesurer sur le système démarré.

## Pourquoi v9.4

v9.1 avait prouvé le boot arrière avec un `XhciDxe` moderne, mais la pile USB/storage/filesystem supérieure restait celle du vieux firmware Granite Well. Le média Debian de référence fonctionnait, alors qu'un montage SSD/JMicron ultérieur était lu par l'UEFI sans terminer le démarrage de l'OS.

v9.4 charge donc explicitement une pile EDK2 moderne complète :

```text
firmware Synology patché
  -> clé bridge façade
  -> DS713Bridge v9.4
  -> XhciDxe
  -> UsbBusDxe
  -> UsbMassStorageDxe
  -> DiskIoDxe
  -> PartitionDxe
  -> EnglishDxe
  -> Fat
  -> Etron EJ168A 1b6f:7023
  -> filesystem arrière
  -> \EFI\BOOT\BOOTX64.EFI
  -> OS
```

Les drivers sont démarrés directement via `EFI_DRIVER_BINDING_PROTOCOL` (`Supported()` + `Start()`), sans dépendre du comportement `ConnectController()` du vieux firmware.

## Créer la clé

```bash
chmod +x scripts/12-create-usb3-bridge-v94.sh
./scripts/12-create-usb3-bridge-v94.sh
```

Script exact validé physiquement :

```text
SHA-256  6af4b3291f058093a9d2673a51596bb0525b57d5a818587166575f86709f206b
```

Source bridge embarquée :

```text
SHA-256  75e00a082b11dbb9684eb240f77dbdbe3cfde952b90f7e4f8274020432a0ba39
```

Le build et les contrôles EFI sont terminés **avant** la confirmation destructive `ERASE-/dev/sdX`. Un échec de compilation ne touche donc pas à la clé existante.

Protections : disque USB entier uniquement, disque système refusé, périphériques de taille nulle refusés, confirmation destructive exacte, commit EDK2 épinglé, hash de source vérifié, validation PE32+ de chaque EFI et `fsck.fat -n` après écriture.

## Profils EDK2

Défaut :

```text
edk2-stable202605
b03a21a63e3bd001f52c527e5a57feddb53a690b
```

`XhciDxe.efi` exact validé :

```text
20c3dbda0e0720fe171a7c0b06c995c4fe319f7338acfb75e9b5ee271a3092b3
```

Oracle normalisé :

```text
ecb9726a4ecd6ce1fe39874b6b8a0e9374bfdcaa08da77fbb3de827bae258e30
```

Profil expérimental uniquement :

```bash
./scripts/12-create-usb3-bridge-v94.sh --latest
```

qui épingle `edk2-stable202608` au commit `2970e5699ba6267f3384ffab20f96647578aebc8`.

## Contenu de la clé

```text
EFI/BOOT/BOOTX64.EFI
EFI/DS713V94/drivers/XhciDxe.efi
EFI/DS713V94/drivers/UsbBusDxe.efi
EFI/DS713V94/drivers/UsbMassStorageDxe.efi
EFI/DS713V94/drivers/DiskIoDxe.efi
EFI/DS713V94/drivers/PartitionDxe.efi
EFI/DS713V94/drivers/EnglishDxe.efi
EFI/DS713V94/drivers/Fat.efi
startup.nsh
```

Le seul chemin loader OS est `\EFI\BOOT\BOOTX64.EFI`.

## Politique

Aucun probing Debian/Ubuntu/Windows/GRUB/shim, UUID disque, numéro de série, numéro de port arrière, `BootOrder` ou `BootNext` n'est codé dans v9.4.

Le loader OS est chargé avec `BootPolicy=TRUE`, un watchdog UEFI de 300 s entoure `StartImage()`, et le bridge n'effectue aucune écriture persistante de variable EFI.

Après `ExitBootServices()`, le contrôleur xHCI et le stockage appartiennent à l'OS. Il faut donc mesurer sous Linux la vitesse négociée, UAS/BOT, TRIM et le temps jusqu'à SSH.

## Référence historique

v9.1 reste la référence minimal-stack ayant démarré physiquement Debian 13 derrière l'Etron jusqu'au réseau/SSH. v9.4 est la solution full-stack plus récente validée pour le cas SSD arrière.
