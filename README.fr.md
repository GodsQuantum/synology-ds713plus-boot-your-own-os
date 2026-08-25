# Synology DS713+ — booter sur une clé USB normale (bypass F400)

[![lint](https://github.com/GodsQuantum/synology-ds713plus-f400-unlock/actions/workflows/lint.yml/badge.svg)](https://github.com/GodsQuantum/synology-ds713plus-f400-unlock/actions/workflows/lint.yml)
[![Licence : MIT](https://img.shields.io/badge/Licence-MIT-yellow.svg)](LICENSE)

**[🇬🇧 English version](README.md)** ·
[Matériel validé](docs/VERIFIED-HARDWARE.fr.md) ·
[Sécurité](docs/SAFETY.fr.md) ·
[Récupération](docs/RECOVERY.fr.md) ·
[Sources](docs/SOURCES.md)

Le firmware Granite Well/Tiano du **DS713+** attend au boot un périphérique USB avec le VID:PID codé en dur `F400:F400`.

Donc une clé USB parfaitement normale peut fonctionner sous Linux ou DSM… tout en étant ignorée par le firmware au moment de démarrer dessus.

Ce repo contient le **workflow A à Z que j'ai réellement utilisé sur un DS713+** pour supprimer cette restriction, ne flasher que les blocs SPI réellement modifiés, tout revérifier, puis booter Debian 13 depuis une clé USB ordinaire.

> **Version courte :** patch de `UsbBusDxe`, suppression des deux contrôles F400, reconstruction, flash de la vraie zone modifiée, double vérification, boot.

---

## ✅ Ce qui fonctionne réellement

| Test | Résultat |
|---|---|
| DSM après le flash BIOS | ✅ Démarre normalement |
| Clé USB normale non-`F400:F400` | ✅ Acceptée |
| Boot USB 2.0 en façade | ✅ Validé |
| Debian 13 amd64 / UEFI | ✅ Validé |
| Linux + réseau + SSH | ✅ Validé |
| USB 3.0 arrière #1 | ❌ Ne boote pas |
| USB 3.0 arrière #2 | ❌ Ne boote pas |
| USB 3.0 arrière une fois Linux lancé | ✅ Fonctionne via `xhci_hcd` |
| Autres Synology Cedarview / Granite Well | ⚠️ Non validés |

Test de boot final :

```text
USB VID:PID   abcd:1234
Boot          UEFI x86_64
OS            Debian 13
Port          USB 2.0 façade
Résultat      boot → réseau → SSH
```

La conclusion utile est simple :

> **Une fois le contrôle F400 supprimé, le DS713+ peut booter une clé USB normale depuis le port USB 2.0 frontal.**

### USB 3.0 arrière

J'ai testé **les deux ports Etron EJ168A** avec exactement la même clé connue comme fonctionnelle en façade, à chaque fois après une vraie coupure électrique complète.

Aucun des deux n'a booté. Après cold boot, la même clé remise en façade démarrait toujours Debian normalement.

Une fois Linux lancé, l'Etron fonctionne via `xhci_hcd`. Mais le patch actuel ne fait **qu'enlever la restriction VID/PID F400** : il n'ajoute pas de support EFI xHCI.

Le boot USB 3.0 arrière n'est donc **pas pris en charge par ce patch F400 seul**.

---

## Pourquoi ce repo existe

Les anciennes recherches Granite Well suffisaient à montrer que Synology vérifie `F400:F400`.

Ce qui me manquait, c'était un workflow que j'accepte réellement de lancer sur un NAS headless sans moyen de récupération confortable.

Avant d'écrire quoi que ce soit, je voulais pouvoir répondre clairement à ça :

- est-ce que j'ai dumpé la bonne région BIOS ?
- est-ce que mes deux dumps sont strictement identiques ?
- est-ce bien le profil matériel attendu ?
- est-ce que la région BIOS est writable ?
- quelle est la vraie granularité d'effacement ?
- est-ce que le firmware reconstruit est cohérent ?
- quels blocs physiques ont réellement changé ?
- est-ce que l'écriture reste entièrement dans la région BIOS ?
- est-ce que le candidat est vérifiable immédiatement ?
- est-ce qu'un rollback est possible si la vérification échoue ?
- est-ce que toute la région BIOS peut être revérifiée avant le reboot ?

Les scripts de ce repo sont construits autour de ces contrôles.

---

## ⚠️ Avant de flasher

Flasher un firmware peut briquer une machine.

Le chemin d'écriture automatisé est validé sur **un profil précis de DS713+**. Les modèles proches sont des candidats de recherche, pas des cibles automatiquement compatibles.

Ne saute pas les étapes probe/dump et ne réutilise pas le firmware de quelqu'un d'autre.

**Aucun BIOS Synology ni BIOS modifié n'est distribué dans ce repo.**

Lis [docs/SAFETY.fr.md](docs/SAFETY.fr.md) avant la phase d'écriture.

---

## 🔧 Ce que le patch modifie

Module ciblé :

```text
Module       UsbBusDxe
GUID FFS     240612B7-A063-11D4-9A3A-0090273FC14D
Section      PE32 / 0x10
```

Le firmware stock contient deux sauts conditionnels qui rejettent les périphériques dont le VID ou le PID n'est pas `0xF400` :

```text
+0x2991  0F 85 17 03 00 00  ->  90 90 90 90 90 90
+0x299B  0F 85 0D 03 00 00  ->  90 90 90 90 90 90
```

Au niveau du PE, la modification sémantique fait seulement **12 octets**.

Le piège : `UsbBusDxe` se trouve dans une section firmware compressée en LZMA. La reconstruction modifie donc le flux compressé sur une zone beaucoup plus grande.

Le repo calcule la **vraie diff physique**, l'aligne sur la granularité d'effacement du chipset, vérifie qu'elle reste dans la région BIOS, puis n'écrit que cette zone.

Résultat de référence sur le DS713+ testé :

```text
Patch sémantique       12 octets

Diff physique
premier octet          0x011058
dernier octet          0x095d28

Zone alignée 4 Kio
début                  0x011000
fin                    0x095fff
taille                 544768 octets
```

---

## 🧱 Profil SPI DS713+ validé

```text
Plateforme        Synology DS713+ / Granite Well
Chipset           Intel ICH10R 8086:3a16
Flash SPI         4 Mio

Descriptor        0x000000 - 0x000fff
GbE               0x001000 - 0x010fff
BIOS              0x011000 - 0x210fff (2 Mio)

Région BIOS       lecture/écriture
FLOCKDN           0
PR0..PR4          inutilisés
BIOSWE            activé
Bloc effacement   4096 octets
```

Détail important : l'espace physique `0x211000-0x3fffff` n'est pas lisible via le hardware sequencing de l'ICH sur la machine testée.

Un carrier de 4 Mio assemblé pour flashrom **n'est donc pas un vrai full dump physique fiable de la puce**. Toutes les opérations restent bornées par un layout explicite.

---

## 🚀 Démarrage rapide

Depuis une machine Linux ayant accès à DSM en SSH :

```bash
export NAS_HOST='192.168.1.x'
export NAS_USER='votre-utilisateur-admin'

./scripts/00-build-flashrom.sh
./scripts/01-install-flashrom.sh
./scripts/02-probe.sh
./scripts/03-dump.sh
./scripts/04-build-uefi-tools.sh
./scripts/05-patch-bios.sh artifacts/bios-read1.bin
./scripts/06-preflight.sh
```

À ce stade, **rien n'a encore été flashé**.

L'écriture réelle est volontairement séparée :

```bash
./scripts/07-flash.sh prepare
./scripts/07-flash.sh arm
./scripts/07-flash.sh status
```

Puis vérification avant reboot :

```bash
./scripts/08-postflash-verify.sh
```

Ne redémarre pas tant que le résultat final n'est pas :

```text
READY_FOR_REBOOT=YES
```

Les scripts ne redémarrent jamais automatiquement le NAS.

---

## 📁 Organisation du repo

| Chemin | Contenu |
|---|---|
| `scripts/` | build, probe, dump, patch, preflight, flash, vérification |
| `scripts/lib/` | fonctions shell communes |
| `profiles/` | invariants hardware validés |
| `patches/` | description du patch — **aucun firmware** |
| `docs/SAFETY.fr.md` | à lire avant de flasher |
| `docs/RECOVERY.fr.md` | rollback / récupération |
| `docs/USB-BOOT.fr.md` | validation du boot USB |
| `docs/VERIFIED-HARDWARE.fr.md` | statut du matériel testé |
| `docs/REFERENCE-RESULTS.fr.md` | valeurs de référence du DS713+ fonctionnel |
| `docs/THEORY.fr.md` | détails techniques |
| `docs/SOURCES.md` | recherches et références |

---

## Modèles Synology proches

DS412+, DS1512+, DS1812+, DS1513+, DS1813+, DS2413+, RS812+ et les autres systèmes Cedarview/Granite Well sont de bons candidats de recherche.

Ils ne sont **pas automatiquement compatibles**.

Firmware, permissions SPI, géométrie d'effacement, octets du module et résultat de reconstruction peuvent différer. Commence par probe + dump et ouvre un hardware report avant toute écriture.

---

## Licence / firmware

Les scripts et la documentation propres au repo sont sous licence MIT.

Le repo ne redistribue ni firmware Synology, ni BIOS Synology modifié, ni binaire flashrom, ni binaire UEFITool.

## Crédits

Ce travail s'appuie sur les recherches Granite Well publiées par **Orefie** et d'autres contributeurs SynoForum, ainsi que sur [flashrom](https://flashrom.org/) et [UEFITool](https://github.com/LongSoft/UEFITool).

Voir [docs/SOURCES.md](docs/SOURCES.md) pour les références utilisées.
