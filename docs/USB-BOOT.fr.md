# Boot USB sur le DS713+

[← README](../README.fr.md) · [English](USB-BOOT.md) · [Démarrage rapide](QUICKSTART.fr.md)

## Deux résultats différents à ne pas confondre

### Patch firmware F400 seul

L'expérience v0.1.0 a supprimé la restriction VID/PID Synology `F400:F400`. DOM interne retiré, une clé Debian 13 UEFI ordinaire `abcd:1234` a booté par **l'USB 2.0 frontal** jusqu'à Linux, réseau et SSH.

La même clé a ensuite été testée sur **les deux ports Etron EJ168A arrière** après coupure secteur complète. Aucun n'a booté. Ce résultat négatif reste valide pour le **patch firmware F400 seul**.

### Patch F400 + DS713Bridge v9.1

Une expérience ultérieure a placé le bridge en façade et le média Debian derrière l'Etron. DS713Bridge v9.1 a chargé le `XhciDxe` validé, découvert un filesystem arrière descendant de l'Etron puis chainloadé `\EFI\BOOT\BOOTX64.EFI`. Debian a atteint le réseau/SSH.

Cela prouve le boot via le contrôleur arrière au travers du bridge. L'implémentation ne code aucun port arrière en dur, mais le dépôt ne prétend pas que les deux connecteurs physiques aient chacun été retestés A à Z avec v9.1.

## Média de test valide

Utilisez une installation UEFI x86-64 avec GPT/ESP et de préférence le loader fallback standard :

```text
\EFI\BOOT\BOOTX64.EFI
```

Une installation GRUB legacy/MBR uniquement n'est pas un test négatif valable du chemin EFI.

## Disposition bridge

```text
USB 2.0 façade : DS713Bridge v9.1
Etron arrière  : média OS avec \EFI\BOOT\BOOTX64.EFI
```

Création :

```bash
sudo SDX=sdb ./scripts/10-create-usb3-bridge.sh
```

Voir [Bridge USB3 arrière](USB3-BRIDGE.fr.md) pour l'architecture, les hashes et les performances mesurées.

### DS713Bridge v9.4 FULL-STACK R2

Le patch firmware F400 seul n'initialise toujours pas le contrôleur Etron arrière pour le boot. Le chemin v9.4 physiquement validé est distinct : une clé bridge v9.4 en USB façade charge une pile EDK2 xHCI/USB/storage/filesystem moderne et démarre avec succès le SSD système Linux existant via l'Etron arrière jusqu'à Linux, au réseau et à SSH.

Utilisez `scripts/12-create-usb3-bridge-v94.sh` comme bridge arrière recommandé actuel. DS713Bridge v9.1 reste la référence historique minimal-stack Debian.
