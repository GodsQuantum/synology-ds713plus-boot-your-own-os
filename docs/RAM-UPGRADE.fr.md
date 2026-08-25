# Upgrade RAM du DS713+ et limites hardware

[← Retour au README](../README.fr.md) · [English](RAM-UPGRADE.md)

Le DS713+ était livré avec **1 Go de DDR3**.

Synology ne le vendait pas comme un NAS à mémoire officiellement extensible, mais les démontages et retours communautaires montrent une SO-DIMM remplaçable et des DS713+ utilisés pendant des années avec 2 ou 4 Go.

La limite dure vient surtout du CPU.

## Contrôleur mémoire de l'Intel Atom D2700

Intel spécifie :

```text
Mémoire maximum     4 Go
Type                 DDR3-800 / DDR3-1066
Canaux               1
Bande passante max   6,4 Go/s
ECC                  non
```

Donc **8 Go sont hors spécification D2700**, même si une barrette rentre physiquement.

## Choix pratiques

| Capacité | Statut | Commentaire |
|---|---|---|
| **1 Go** | ✅ Configuration Synology d'origine | Fonctionne ; serré pour des services modernes |
| **2 Go** | 🟢 Upgrade communautaire conservateur | Bonne cible pour un OS léger |
| **4 Go** | 🟠 Maximum D2700 | Retours DS713+ positifs, mais compatibilité de la barrette importante |
| **8 Go** | ❌ Hors spécification CPU | Le fait d'avoir un OS 64 bits ne prouve pas un support 8 Go |

## Exemples communautaires documentés

Les retours historiques DS713+ incluent notamment :

- Kingston `KVR1333D3S8S9/2G` 2 Go rapportée fonctionnelle ;
- PNY `SOD104GBN/10660/3-BX` 4 Go rapportée fonctionnelle ;
- Kingston `KVR13S9S8/4` 4 Go rapportée compatible à plusieurs reprises, y compris sous DSM 6 et DSM 7.

Ce sont des **retours communautaires, pas une certification Synology ni une validation de ce repo**.

Sur ce type de vieux contrôleur mémoire, plusieurs détails peuvent compter :

- tension ;
- rank ;
- densité des puces ;
- organisation de la barrette ;
- données SPD.

Une barrette quelconque marquée « 4 Go DDR3 SO-DIMM » n'est donc pas garantie équivalente à une référence connue fonctionnelle.

## Ce que je choisirais

Pour recycler un DS713+ aujourd'hui :

- **2 Go** pour l'option conservatrice ;
- **4 Go** pour avoir plus de marge avec OMV/Ubuntu, à condition de choisir une référence ayant déjà un historique positif sur DS713+.

Pour OpenMediaVault 8, 4 Go est nettement plus confortable même si OMV documente 1 Gio comme minimum bas.

## Autres limites CPU importantes

Le D2700 :

```text
2 cœurs / 4 threads
2,13 GHz
Intel 64
SSE2 / SSE3 / SSSE3
pas de SSE4
pas d'AVX
pas de VT-x
pas de VT-d
TDP 10 W
```

Conséquences :

- Linux serveur moderne et léger : réaliste ;
- grosses charges CPU : ce n'est pas le but de cette machine ;
- virtualisation hardware : mauvaise cible ;
- logiciels exigeant AVX ou SSE4 : incompatibles.

## Stockage / réseau

La fiche Synology d'origine indique :

```text
2 × baies SATA
2 × Gigabit Ethernet
2 × USB 3.0 arrière
1 × USB 2.0 frontal
1 × eSATA
disques internes hot-swap
```

Le « maximum 8 To » de la fiche de 2012 correspondait aux tailles de disques commercialisées/certifiées à l'époque ; ce n'est pas une preuve que le contrôleur SATA serait physiquement incapable d'adresser tout disque moderne plus grand. Il faut néanmoins tester les disques choisis avec l'OS et le système de fichiers retenus.

## Sources

Voir [SOURCES.md](SOURCES.md) pour la fiche Intel D2700, la datasheet Synology DS713+ et les retours communautaires RAM.
