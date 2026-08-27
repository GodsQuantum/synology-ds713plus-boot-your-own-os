# Choisir un OS pour le DS713+

[← Retour au README](../README.fr.md) · [English](OS-OPTIONS.md)

Le patch F400 donne au DS713+ un **chemin de boot USB UEFI normal via le port USB 2.0 frontal**. Le DS713Bridge v9.1 optionnel fournit en plus un chemin validé vers un média OS derrière le contrôleur Etron arrière.

Ça ne veut pas dire que tous les OS x86-64 sont de bonnes cibles. La vraie question est :

> Est-ce que l'OS supporte un vieux x86-64, tient sous un plafond de 4 Go de RAM et contient les drivers nécessaires au hardware du DS713+ ?

## Recommandations rapides

| OS | Pertinence | Pourquoi |
|---|---|---|
| **Debian 13** | ✅ Validé | Réellement booté sur le DS713+ jusqu'à Linux + réseau + SSH |
| **OpenMediaVault 8** | 🟢 Très bon candidat | Base Debian 13, AMD64, faible RAM minimale, UI NAS |
| **Ubuntu Server 26.04 LTS** | 🟢 Plausible | Image amd64, RAM compatible, LTS moderne |
| **Autre Linux léger** | 🟡 Au cas par cas | Architecture possible, mais drivers/installer/kernel à vérifier |
| **TrueNAS actuel** | 🔴 Déconseillé | 8 Go minimum alors que le D2700 est limité à 4 Go |

## Debian 13 — base connue fonctionnelle

Debian 13 amd64 est le seul OS physiquement validé A à Z dans ce repo.

Test de référence :

```text
UEFI            oui
USB             clé normale abcd:1234
Port            USB 2.0 frontal
Root            stockage USB
Userspace       atteint
Réseau          atteint
SSH             atteint
```

C'est donc le meilleur point de départ pour diagnostiquer un autre DS713+.

## OpenMediaVault 8 — probablement la meilleure cible NAS

En 2026, OpenMediaVault 8 repose sur Debian 13.

La documentation OMV indique notamment :

- support AMD64 ;
- base Debian 13 ;
- 1 Gio de RAM comme minimum ;
- 4 Gio comme cible plus confortable ;
- installation depuis USB supportée.

Ça colle particulièrement bien au DS713+ :

```text
CPU DS713+       x86-64 / Intel 64
RAM d'origine    1 Go
RAM max CPU      4 Go
Base validée      Debian 13
```

Pour convertir réellement la machine en NAS moderne, OMV est donc la prochaine cible logique à valider complètement.

### Approche conservatrice recommandée

Comme Debian 13 est déjà connu fonctionnel :

1. installer/booter d'abord un Debian 13 minimal ;
2. vérifier les deux disques SATA et au moins une interface Ethernet ;
3. vérifier plusieurs cold boots stables depuis l'USB frontal ;
4. installer OMV 8 sur cette base Debian connue.

L'ISO OMV officiel est une autre possibilité, mais son chemin de boot exact n'est pas encore validé sur ce firmware.

## Ubuntu Server 26.04 LTS

Ubuntu 26.04 LTS fournit une image Server amd64.

Canonical documente un besoin minimal pouvant démarrer autour de 1,5 Go de RAM selon le scénario. Un DS713+ équipé de 2 à 4 Go rentre donc au moins dans cette enveloppe générale.

Pas encore validé ici :

- boot de l'installeur Ubuntu sur ce firmware ;
- comportement exact des drivers Ethernet/stockage ;
- power management avec l'ancien ACPI Synology.

À considérer comme plausible, pas confirmé.

## TrueNAS

La documentation TrueNAS actuelle demande environ :

```text
CPU       x86-64 double cœur
RAM       8 Go minimum
Boot      périphérique ~16 Go ou plus
```

Le contrôleur mémoire de l'Atom D2700 est limité par Intel à :

```text
4 Go maximum
```

Ça suffit pour écarter TrueNAS actuel comme recommandation sérieuse sur cette machine.

D'anciennes versions historiques de TrueNAS/FreeNAS sont une autre question, mais installer un OS de stockage lui-même ancien et non maintenu ferait perdre une grande partie de l'intérêt de quitter un DSM EOL.

## Autres distributions Linux

Une distro mérite d'être testée si elle :

- conserve le support x86-64 de base sans exiger AVX/SSE4 ;
- fonctionne correctement sous 4 Go de RAM ;
- fournit les drivers Intel ICH10, Intel 82574L et Etron EJ168A nécessaires ;
- sait booter en UEFI par le chemin USB 2.0 frontal.

Le patch ne change pas la compatibilité Linux. Il supprime seulement le rejet USB VID/PID propre à Synology.

## Support de boot

Deux chemins sont validés et doivent être distingués :

- **USB 2.0 frontal directement après unlock F400** ;
- **stockage arrière Etron via DS713Bridge v9.1**.

Le patch F400 seul n'initialise pas l'Etron. Le bridge constitue une couche xHCI amovible séparée et chaîne le `\EFI\BOOT\BOOTX64.EFI` standard du média arrière.

Le boot SATA arbitraire et le remplacement arbitraire du DOM restent des sujets séparés.

## Sources

Voir [SOURCES.md](SOURCES.md) pour les références officielles OMV, Ubuntu, TrueNAS, Intel et Synology.
