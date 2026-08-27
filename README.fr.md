# Synology DS713+ — Bootez l'OS de votre choix

[![lint](https://github.com/GodsQuantum/synology-ds713plus-boot-your-own-os/actions/workflows/lint.yml/badge.svg)](https://github.com/GodsQuantum/synology-ds713plus-boot-your-own-os/actions/workflows/lint.yml)
[![Licence : MIT](https://img.shields.io/badge/Licence-MIT-yellow.svg)](LICENSE)

**[🇬🇧 English version](README.md)** ·
[Démarrage rapide](docs/QUICKSTART.fr.md) ·
[Bridge USB3 arrière](docs/USB3-BRIDGE.fr.md) ·
[Choisir un OS](docs/OS-OPTIONS.fr.md) ·
[Upgrade RAM](docs/RAM-UPGRADE.fr.md) ·
[Matériel validé](docs/VERIFIED-HARDWARE.fr.md) ·
[Sécurité](docs/SAFETY.fr.md)

> **Redonnez une vraie vie à un Synology DS713+ en fin de support.** Supprimez la restriction USB `F400:F400` de Synology et bootez un OS Linux/NAS x86-64 compatible depuis une clé USB normale.

Le **DS713+ reste un petit serveur x86-64 tout à fait exploitable** : deux baies SATA, deux ports Gigabit, USB 3.0, eSATA. En 2026, son principal problème est surtout logiciel.

Synology classe aujourd'hui le DS713+ comme **produit arrêté**, avec **mises à jour DSM en fin de vie** et **support technique limité**. Sa dernière branche DSM officiellement accessible est **DSM 7.1**, et le Download Center Synology s'arrête actuellement à **DSM 7.1.1**.

L'idée du projet est donc simple : garder le hardware, enlever le verrou USB spécifique à Synology, et utiliser la machine comme un petit serveur/NAS x86-64 normal.

---

## Commencer ici

Il y a **deux étapes distinctes**. Ne les mélangez pas :

1. **Déverrouillage firmware (une seule fois, obligatoire) :** tant que le NAS tourne encore sous DSM, utilisez un poste Linux + un compte admin DSM en SSH pour supprimer la restriction `F400:F400`. Le workflow double-dumpe le BIOS, valide le profil exact du DS713+, calcule la patchzone physique, exige une étape d'armement séparée, tente un rollback si la vérification échoue et ne donne l'autorisation de reboot qu'après deux vérifications complètes de la région BIOS.
2. **Bridge USB3 arrière (optionnel, recommandé si l'OS doit vivre derrière) :** créez une petite clé bridge façade/DOM avec `sudo SDX=sdb ./scripts/10-create-usb3-bridge.sh`. Elle initialise le chemin xHCI validé puis chaîne le `\EFI\BOOT\BOOTX64.EFI` standard du média arrière.

**Chemin le plus simple :** suivez **[Démarrage rapide](docs/QUICKSTART.fr.md)** de haut en bas. Lisez **[Sécurité](docs/SAFETY.fr.md)** avant toute écriture firmware.

```text
DSM encore actif
  -> 00..06 audit/build/preflight
  -> 07 prepare -> status -> arm -> status
  -> 08 double vérification BIOS -> READY_FOR_REBOOT=YES
  -> reboot/test d'une clé non-F400 normale
  -> optionnel : 10-create-usb3-bridge.sh pour booter via l'Etron arrière
```

---

## Avant → après

| | DS713+ stock | Après ce projet |
|---|---|---|
| OS officiel | DSM uniquement | OS Linux/NAS x86-64 compatible |
| Plafond DSM | DSM 7.1 / téléchargements 7.1.1 | Plus de plafond DSM si vous quittez DSM |
| Mises à jour DSM | ❌ Fin de vie | Selon l'OS choisi |
| Boot sur clé USB normale | ❌ Firmware limité à `F400:F400` | ✅ Boot non-F400 validé |
| Debian 13 | Pas un chemin de boot Synology normal | ✅ **Validé A à Z** |
| OpenMediaVault 8 | Pas proposé par Synology | 🟢 Très bon candidat |
| Ubuntu Server 26.04 LTS | Pas proposé par Synology | 🟢 Candidat plausible |
| TrueNAS actuel | Pas proposé par Synology | 🔴 Mauvaise cible : 8 Go de RAM minimum |
| Hardware | NAS de 2012 encore fonctionnel | Même machine, mais sous votre contrôle |

**Important :** « l'OS de votre choix » signifie **un OS compatible avec ce hardware**. Le patch enlève la whitelist USB de Synology ; il n'ajoute pas magiquement des drivers et ne change pas les limites du CPU ou de la RAM.

---

## Vieux, oui. Inutile, non.

Synology a lancé le DS713+ en 2012 comme NAS deux baies plutôt musclé pour l'époque.

Hardware de référence :

```text
CPU           Intel Atom D2700 / Cedarview
              2 cœurs / 4 threads @ 2,13 GHz
Architecture  Intel 64 / x86-64
RAM d'origine 1 Go DDR3
RAM max CPU   4 Go DDR3-800/1066
Stockage      2 × baies SATA 2,5"/3,5", hot-swap
Réseau        2 × Gigabit Ethernet
Façade        1 × USB 2.0
Arrière       2 × USB 3.0 + eSATA
```

Pour un NAS léger, une cible de sauvegarde, SMB/NFS, rsync, un petit serveur Debian, du monitoring ou d'autres services raisonnables, ça reste utilisable.

La vraie limite matérielle à garder en tête est le **plafond de 4 Go de RAM** du contrôleur mémoire de l'Atom D2700. Voir [Upgrade RAM](docs/RAM-UPGRADE.fr.md).

---

## ✅ Ce qui est réellement validé

Ici, « devrait fonctionner » n'est pas transformé en « fonctionne ».

| Test | Statut |
|---|---|
| Dump BIOS → patch → flash → vérification complète | ✅ Validé |
| DSM redémarre après le patch | ✅ Validé |
| Clé USB normale VID:PID `abcd:1234` | ✅ Acceptée |
| Boot UEFI par USB 2.0 frontal | ✅ Validé |
| Debian 13 amd64 | ✅ Validé |
| Linux + DHCP/réseau + SSH | ✅ Validé |
| USB 3.0 arrière Etron avec patch F400 seul | ❌ Non bootable |
| USB 3.0 arrière via DS713Bridge v9.1 | ✅ Debian 13 → réseau/SSH validé |
| USB 3.0 arrière après lancement Linux | ✅ Fonctionne via `xhci_hcd` |

Boot de référence :

```text
USB VID:PID   abcd:1234
Partition     GPT + EFI System Partition
Boot          UEFI x86-64
OS            Debian 13
Port          USB 2.0 façade
Résultat      UEFI → Linux → réseau → SSH
```

Ça valide le but réel de la modification :

> **Un DS713+ patché peut booter une clé USB complètement normale et non-F400 depuis son port USB 2.0 frontal.**

---

## Quel OS utiliser ?

### ✅ Debian 13 — validé

C'est l'OS utilisé pour la validation hardware finale.

Si vous voulez la base la plus simple et la plus proche de ce qui a réellement été testé, Debian est le point de départ connu.

### 🟢 OpenMediaVault 8 — probablement la cible NAS la plus intéressante

OMV 8 repose sur **Debian 13**, supporte AMD64, et sa documentation indique qu'une configuration légère peut fonctionner à partir de **1 Gio de RAM**.

Pour un DS713+, surtout avec 2 ou 4 Go de RAM, c'est donc une cible très logique.

Le repo n'a **pas encore validé son installation A à Z**, donc OMV reste volontairement marqué « candidat », pas « validé ».

### 🟢 Ubuntu Server 26.04 LTS — plausible

Ubuntu Server 26.04 fournit une image amd64 et peut démarrer autour de 1,5 Go de RAM selon le scénario d'installation.

Le D2700 est Intel 64, donc l'architecture de base correspond. L'installation spécifique sur DS713+ n'a pas encore été validée ici.

### 🔴 TrueNAS actuel — à éviter sur ce hardware

La documentation TrueNAS actuelle demande **8 Go de RAM minimum**.

Le contrôleur mémoire du D2700 est limité à **4 Go**.

Même si TrueNAS est x86-64, ce n'est donc pas une recommandation sérieuse pour cette machine.

Comparatif complet : **[Choisir un OS](docs/OS-OPTIONS.fr.md)**.

---

## RAM : 1 Go d'origine, jusqu'à 4 Go côté CPU

Synology livrait le DS713+ avec **1 Go de DDR3**.

Intel donne pour le D2700 un maximum de **4 Go DDR3-800/1066**, single-channel, non-ECC.

Des retours communautaires documentent des DS713+ fonctionnant avec **2 Go** et **4 Go**, notamment avec la Kingston `KVR13S9S8/4` 4 Go sous DSM 6 et DSM 7.

Mais ce n'est **pas un upgrade officiellement supporté par Synology**, et sur ce vieux Cedarview l'organisation/densité de la barrette compte.

En pratique :

| RAM | Recommandation |
|---|---|
| 1 Go | ✅ Stock ; Debian léger / OMV très léger |
| 2 Go | 🟢 Upgrade conservateur |
| 4 Go | 🟠 Maximum CPU ; retours positifs sur DS713+, mais barrette à choisir soigneusement |
| 8 Go | ❌ Hors spécification D2700 |

Voir **[Upgrade RAM et limites hardware](docs/RAM-UPGRADE.fr.md)** avant d'acheter une barrette.

---

## Pourquoi une clé USB normale ne boote pas d'origine

Le firmware du DS713+ contient un module USB DXE qui vérifie explicitement le couple VID/PID Synology :

```text
F400:F400
```

Une clé USB normale peut être parfaitement valide et néanmoins être rejetée par le firmware avant même que l'OS ne démarre.

Module ciblé :

```text
Module       UsbBusDxe
GUID FFS     240612B7-A063-11D4-9A3A-0090273FC14D
Section      PE32 / 0x10
```

Les deux branches de rejet :

```text
+0x2991  0F 85 17 03 00 00  ->  90 90 90 90 90 90
+0x299B  0F 85 0D 03 00 00  ->  90 90 90 90 90 90
```

La modification sémantique ne fait que **12 octets**.

Mais la section est compressée en LZMA : après reconstruction, la différence physique dans l'image BIOS est beaucoup plus grande. Le projet calcule donc la vraie zone SPI modifiée et l'aligne sur la granularité d'effacement réelle.

Détails : [Fonctionnement du verrou F400](docs/THEORY.fr.md).

---

## 🚀 Workflow

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

Puis, avant reboot :

```bash
./scripts/08-postflash-verify.sh
```

Ne redémarrez pas tant que la vérification finale ne renvoie pas :

```text
READY_FOR_REBOOT=YES
```

Le workflow de flash ne redémarre jamais automatiquement le NAS.

Lire **[Sécurité](docs/SAFETY.fr.md)** et **[Récupération](docs/RECOVERY.fr.md)** avant l'écriture.

---

## USB 3.0 arrière : ce qui est réellement validé

Le **patch firmware F400 seul** n'initialise toujours pas le contrôleur xHCI Etron EJ168A arrière. Les deux ports avaient donné un résultat négatif lors des cold boots de l'expérience v0.1.0.

L'expérience ultérieure **DS713Bridge v9.1** résout ce problème distinct sans modifier le média OS :

```text
firmware Synology patché
  -> clé bridge en façade
  -> DS713Bridge v9.1 + XhciDxe validé
  -> Etron EJ168A
  -> média UEFI arrière
  -> \EFI\BOOT\BOOTX64.EFI
  -> Debian 13 -> réseau -> SSH
```

Le bridge ne code en dur ni OS, ni UUID, ni serial disque, ni numéro de port arrière, ni `BootOrder`, ni `BootNext`. Il découvre les filesystems descendants de l'Etron et chaîne uniquement le loader amovible standard.

**La preuve physique est au niveau du contrôleur arrière :** un boot Debian via Etron jusqu'au réseau/SSH est validé. Le code est agnostique du port, mais le dépôt ne prétend pas que les deux connecteurs physiques ont chacun été retestés A à Z avec v9.1.

Voir **[Bridge USB3 arrière](docs/USB3-BRIDGE.fr.md)** pour les hashes, chronos et expériences négatives.

---

## 📁 Où aller ensuite

| Besoin | Guide |
|---|---|
| Choisir Debian / OMV / Ubuntu / autre | [Options OS](docs/OS-OPTIONS.fr.md) |
| Upgrader la RAM | [Upgrade RAM](docs/RAM-UPGRADE.fr.md) |
| Voir le matériel réellement validé | [Matériel validé](docs/VERIFIED-HARDWARE.fr.md) |
| Comprendre le patch firmware | [Théorie](docs/THEORY.fr.md) |
| Voir hashes et offsets de référence | [Résultats de référence](docs/REFERENCE-RESULTS.fr.md) |
| Tester correctement le boot USB | [Boot USB](docs/USB-BOOT.fr.md) |
| Comprendre les garde-fous | [Sécurité](docs/SAFETY.fr.md) |
| Gérer un échec de vérification | [Récupération](docs/RECOVERY.fr.md) |
| Vérifier les sources | [Sources](docs/SOURCES.md) |

---

## Et les autres Synology ?

**Ça peut être intéressant — mais ne flashez jamais le profil DS713+ tel quel sur un autre modèle.**

Cibles de recherche particulièrement intéressantes de la génération Cedarview / Granite Well :

| Famille | Dernière branche DSM Synology | Statut ici |
|---|---:|---|
| DS713+ | DSM 7.1 | ✅ Firmware + boot USB frontal validés |
| DS1513+ / DS1813+ / DS2413+ | DSM 7.1 | ❓ Apparentés / non validés |
| DS412+ / DS1512+ / DS1812+ | DSM 6.2 | ❓ Apparentés / non validés |
| RS812+ / x12 apparentés | DSM 6.2 | ❓ Apparentés / non validés |

Une génération CPU proche ne garantit **ni le même BIOS, ni les mêmes octets, ni les mêmes permissions SPI, ni la même géométrie d'effacement**.

Sur un autre modèle : commencez uniquement par **probe + double dump**, puis ouvrez un hardware report. Ne passez pas directement au flash.

---

## Licence / firmware

Les scripts et la documentation propres au repo sont sous licence MIT.

Le repo ne redistribue pas :

- de firmware Synology ;
- de BIOS Synology modifié ;
- de binaire flashrom ;
- de binaire UEFITool.

Vous dumpez et patchez le firmware de votre propre matériel.

## Crédits

Ce travail s'appuie sur les recherches Granite Well publiées par **Orefie** et d'autres contributeurs SynoForum, ainsi que sur [flashrom](https://flashrom.org/) et [UEFITool](https://github.com/LongSoft/UEFITool).

Les sources officielles Synology, Intel, OMV, Ubuntu, TrueNAS et communautaires utilisées pour les affirmations hardware/OS sont regroupées dans **[Sources](docs/SOURCES.md)**.
