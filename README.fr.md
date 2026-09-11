# Synology DS713+ — Bootez l'OS de votre choix

[![lint](https://github.com/GodsQuantum/synology-ds713plus-boot-your-own-os/actions/workflows/lint.yml/badge.svg)](https://github.com/GodsQuantum/synology-ds713plus-boot-your-own-os/actions/workflows/lint.yml)
[![Licence : MIT](https://img.shields.io/badge/Licence-MIT-yellow.svg)](LICENSE)

**[🇬🇧 English version](README.md)** ·
[Démarrage rapide](docs/QUICKSTART.fr.md) ·
[Firmware N3](native/README.fr.md) ·
[Bridge USB3 — annexe](bridge/README.fr.md) ·
[Choisir un OS](docs/OS-OPTIONS.fr.md) ·
[Upgrade RAM](docs/RAM-UPGRADE.fr.md) ·
[Matériel validé](docs/VERIFIED-HARDWARE.fr.md) ·
[Sécurité](docs/SAFETY.fr.md) ·
[État de la recherche](docs/RESEARCH-STATUS.fr.md)

> **Redonnez une vraie vie à un Synology DS713+ en fin de support.** Supprimez la restriction USB `F400:F400` de Synology et bootez un OS Linux/NAS x86-64 compatible depuis une clé USB normale.

Le **DS713+ reste un petit serveur x86-64 tout à fait exploitable** : deux baies SATA, deux ports Gigabit, USB 3.0, eSATA. En 2026, son principal problème est surtout logiciel.

Synology classe aujourd'hui le DS713+ comme **produit arrêté**, avec **mises à jour DSM en fin de vie** et **support technique limité**. Sa dernière branche DSM officiellement accessible est **DSM 7.1**, et le Download Center Synology s'arrête actuellement à **DSM 7.1.1**.

L'idée du projet est donc simple : garder le hardware, enlever le verrou USB spécifique à Synology, et utiliser la machine comme un petit serveur/NAS x86-64 normal.

---

## Commencer ici

Le chemin recommandé ne demande plus de clé bridge permanente. À partir d'un **DS713+ retail encore sous DSM**, un PC Linux prépare un unique firmware qui :

1. supprime la restriction USB Synology `F400:F400` ;
2. remplace l'ancien Internal Shell par **DS713NativeBoot N3** ;
3. conserve le reste du firmware et ne touche ni Intel ME ni le descriptor.

N3 alimente les baies SATA puis essaie, dans cet ordre, l'USB façade, l'USB 3.0 arrière via l'Etron EJ168, puis le SATA interne. Il utilise les `Boot####` compatibles et le fallback UEFI standard `\EFI\BOOT\BOOTX64.EFI`.

Le N3 livré dans le dépôt est **le binaire exact qui a cold-booté le DS713+ de validation sans clé bridge**, depuis le SSD USB arrière jusqu'à Ubuntu 26.04.1 + réseau + SSH.

**Chemin pratique :** suivez [Démarrage rapide](docs/QUICKSTART.fr.md). Le lanceur principal est :

```text
./scripts/open-ds713plus.sh audit
./scripts/open-ds713plus.sh build
./scripts/open-ds713plus.sh prepare
./scripts/open-ds713plus.sh status
./scripts/open-ds713plus.sh arm
./scripts/open-ds713plus.sh status
./scripts/open-ds713plus.sh verify
```

`audit`, `build` et `prepare` n'écrivent rien dans la SPI. `arm` est volontairement séparé. Le projet n'autorise le reboot qu'après `READY_FOR_REBOOT=YES`.

La clé **DS713Bridge v9.5** reste conservée comme fallback, outil de diagnostic et documentation historique : [annexe bridge](bridge/README.fr.md).

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
| Ubuntu Server 26.04 LTS | Pas proposé par Synology | ✅ SSD système validé en boot arrière direct via firmware N3, sans clé bridge |
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
| USB 3.0 arrière via DS713Bridge v9.4 FULL-STACK R2 | ✅ SSD système Ubuntu/Linux → réseau/SSH validé |
| USB 3.0 arrière via DS713Bridge v9.5 SATA-POWER | ✅ SSD système Linux → réseau/SSH + SATA pré-OS validés |
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

### ✅ Ubuntu Server 26.04 LTS — boot système existant validé

Ubuntu Server 26.04 fournit une image amd64 et peut démarrer autour de 1,5 Go de RAM selon le scénario d'installation.

Le D2700 est Intel 64 et un SSD système Linux existant boote désormais via l'Etron arrière avec DS713Bridge v9.5 jusqu'au réseau/SSH. Le chemin de boot de l'installateur Ubuntu n'a pas été validé séparément.

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

Depuis un PC Linux ayant accès à DSM en SSH :

```bash
export NAS_HOST='192.168.1.x'
export NAS_USER='votre-utilisateur-admin'

./scripts/open-ds713plus.sh audit
./scripts/open-ds713plus.sh build
./scripts/open-ds713plus.sh prepare
```

Les trois étapes ci-dessus sont **sans écriture SPI**. Après `prepare`, vérifiez :

```bash
./scripts/open-ds713plus.sh status
```

N'armez que si le worker affiche `STATUS=WAITING_FOR_ARM` :

```bash
./scripts/open-ds713plus.sh arm
./scripts/open-ds713plus.sh status
```

Après `FINAL_STATUS=SUCCESS_CANDIDATE_VERIFIED_TWICE`, lancez la vérification complète de la région BIOS :

```bash
./scripts/open-ds713plus.sh verify
```

Ne redémarrez jamais tant que la sortie ne contient pas :

```text
READY_FOR_REBOOT=YES
```

Le détail, les prérequis et les sorties attendues sont dans [Démarrage rapide](docs/QUICKSTART.fr.md).

---

## USB 3.0 arrière : N3 remplace désormais la clé bridge

Le patch F400 seul ne suffisait pas à initialiser l'Etron EJ168 avant l'OS. C'est la raison pour laquelle les premières versions du projet utilisaient une clé **DS713Bridge** en façade.

**DS713NativeBoot N3 intègre maintenant directement dans le firmware la pile validée** : `XhciDxe`, `UsbBusDxe`, `UsbMassStorageDxe`, `DiskIoDxe`, `PartitionDxe`, `EnglishDxe` et `Fat`. Il exécute aussi la séquence d'alimentation SATA GPIO16 → 200 ms → GPIO20.

Validation hardware du 10 septembre 2026 :

```text
clé bridge physiquement retirée
  → firmware N3
  → Etron EJ168 initialisé
  → filesystem du SSD arrière trouvé
  → \EFI\BOOT\BOOTX64.EFI
  → Ubuntu 26.04.1
  → réseau
  → SSH
```

Le breadcrumb UEFI observé est `0x277`, ce qui confirme notamment `GPIO_OK`, `REAR_CTRL`, `REAR_STACK_OK`, `REAR_FS` et `CHAINLOAD`. Un reboot suivant a atteint `graphical.target` en 46,16 s côté Linux après le handoff firmware.

La clé bridge n'est donc plus un prérequis. Elle reste disponible dans [l'annexe DS713Bridge](bridge/README.fr.md) pour le fallback et la reproduction des recherches v9.1 → v9.5.

---

## 📁 Où aller ensuite

| Besoin | Guide |
|---|---|
| Choisir Debian / OMV / Ubuntu / autre | [Options OS](docs/OS-OPTIONS.fr.md) |
| Upgrader la RAM | [Upgrade RAM](docs/RAM-UPGRADE.fr.md) |
| Voir le matériel réellement validé | [Matériel validé](docs/VERIFIED-HARDWARE.fr.md) |
| Flasher le firmware natif F400 + N3 | [Démarrage rapide](docs/QUICKSTART.fr.md) |
| Comprendre N3 | [DS713NativeBoot N3](native/README.fr.md) |
| Ancienne méthode bridge | [Annexe DS713Bridge](bridge/README.fr.md) |
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
