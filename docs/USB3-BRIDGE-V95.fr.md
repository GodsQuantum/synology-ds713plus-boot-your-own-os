# DS713Bridge v9.5 — alimentation SATA pré-OS

> **Statut : physiquement validé sur DS713+.** v9.5 est désormais la version recommandée pour un nouveau déploiement.

## Pourquoi v9.5

Sur DS713+, un Linux générique peut charger `ahci` et `sata_sil24` correctement tout en laissant les deux baies internes hors tension. Les sources noyau Synology Cedarview montrent que l'alimentation des disques est une fonction spécifique à la plateforme, absente d'un noyau Linux générique.

Pour Cedarview, le mapping Synology est :

- disque/baie 1 : GPIO 16 ;
- disque/baie 2 : GPIO 20 ;
- lors d'une activation globale sur DS713+, Synology active la première baie puis attend 200 ms avant la seconde.

Ce mapping a été confirmé sur matériel DS713+ : l'activation des lignes 16 et 20 via `gpio_ich` a fait démarrer physiquement les deux HDD et les liens SATA ont ensuite été énumérés par Linux.

## Principe

v9.5 conserve le payload USB/storage/filesystem **v9.4 FULL-STACK R2 inchangé** et modifie uniquement l'application `BOOTX64.EFI` de la clé bridge.

Ordre de démarrage :

```text
UEFI Synology
  -> DS713Bridge v9.5
     -> localise l'Intel LPC/ISA 0000:00:1f.0
     -> lit GPIOBASE (PCI config 0x48)
     -> vérifie/active GPIO I/O decode (PCI config 0x4c, bit 0x10)
     -> vérifie que GPIO16 et GPIO20 sont déjà sélectionnés comme GPIO
     -> GPIO16 = sortie haute
     -> attente 200 ms
     -> GPIO20 = sortie haute
  -> initialise le payload EDK2 v9.4 FULL-STACK R2
  -> découvre l'Etron EJ168A
  -> chainload \\EFI\\BOOT\\BOOTX64.EFI sur le média arrière
  -> Linux démarre avec les HDD internes déjà alimentés
```

## Garde-fous

La v9.5 ne force pas arbitrairement un multiplexage de broche : si `GPIO_USE_SEL` n'indique pas déjà que GPIO16/20 sont des GPIO, elle refuse l'opération. Elle valide également l'emplacement PCI `0000:00:1f.0`, le vendor Intel et la classe ISA bridge avant d'accéder aux registres GPIO.

Aucune variable UEFI persistante (`BootOrder`, `BootNext`, etc.) n'est écrite. Si la phase GPIO échoue ou refuse un pin mux inattendu, la bridge reste **fail-open** pour le boot : elle poursuit le chemin v9.4 afin de ne pas transformer une anomalie SATA en panne de démarrage du NAS.

## Implémentation

Sources :

```text
bridge/DS713Bridge-v9.5.c
bridge/test_v95_static.py
scripts/13-create-usb3-bridge-v95.sh
```

Le créateur v9.5 appelle d'abord le créateur v9.4 existant afin de reconstruire le payload FULL-STACK R2 validé. Il compile ensuite uniquement l'application v9.5 avec `IoLib` et remplace `EFI/BOOT/BOOTX64.EFI`. Les drivers restent sous `EFI/DS713V94/drivers/` pour garantir qu'ils sont identiques au payload v9.4 validé.

## Critères utilisés pour la validation matérielle

La promotion de v9.5 en version recommandée exige un vrai cold boot avec :

1. les deux HDD physiquement installés ;
2. aucun service Linux de GPIO installé ;
3. boot via la clé v9.5 ;
4. les deux HDD visibles immédiatement par `lsblk` en SATA ;
5. GPIO16/20 déjà à l'état haut sous Linux ;
6. boot arrière USB identique à v9.4 ;
7. aucun changement NVRAM.

Ces critères ont servi de base à la validation physique. La v9.5 est désormais marquée **validée** pour le chemin testé.


## Validation physique obtenue — 2026-09-03

```text
clé bridge             v9.5 sur USB façade
média OS               SSD système Linux via Etron arrière
boot                    Linux / réseau / SSH
alimentation SATA       automatique avant Linux
séquence                GPIO16 -> 200 ms -> GPIO20
commande GPIO Linux     aucune nécessaire pour faire apparaître les baies
```

SHA-256 du `BOOTX64.EFI` de la clé testée :

```text
eae1c93e208495fe81b279b1663a1747367548a7735076e25fa9266097515fa6
```

Les essais J2/DOM sont documentés séparément : v9.4 et v9.5 n'ont pas booté depuis J2, alors que la même v9.5 fonctionne depuis l'USB frontal. Le firmware utilisé était déjà patché contre la restriction `F400:F400`; l'échec J2 ne doit donc pas être expliqué simplement par cette whitelist.
