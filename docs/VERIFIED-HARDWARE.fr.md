# Matrice du matériel validé

[← README](../README.fr.md) · [English](VERIFIED-HARDWARE.md)

## DS713+ de référence

| Plateforme / chemin | Statut | Preuve |
|---|---|---|
| Dump → patch → flash firmware | **✅ VALIDÉ** | Double dump, profil ICH10R exact, patchzone dynamique, vérification candidat, double vérification complète BIOS, reboot réussi. |
| USB 2.0 frontal après unlock F400 | **✅ VALIDÉ** | Debian 13 UEFI non-F400 `abcd:1234` → Linux → réseau → SSH. |
| Etron arrière, patch F400 seul | **❌ NON BOOTABLE** | Les deux ports physiques arrière ont été testés séparément après cold boot secteur complet avec la même clé Debian connue fonctionnelle. |
| Etron arrière via DS713Bridge v9.1 | **✅ VALIDÉ** | Bridge en façade + média Debian derrière Etron → loader EFI standard → Debian 13 → réseau/SSH. |
| Couverture des connecteurs avec v9.1 | **⚠️ PREUVE AU NIVEAU CONTRÔLEUR** | Le code est agnostique du port arrière ; les deux connecteurs n'ont pas chacun été retestés A à Z avec v9.1. |
| Etron après prise en charge Linux | **✅ VALIDÉ** | Linux utilise l'EJ168A via `xhci_hcd`. La clé de référence négociait 480 Mbit/s ; elle ne prouve pas le SuperSpeed. |
| Remplacement/placement bridge en DOM interne | **⚠️ POLITIQUE IMPLÉMENTÉE, PAS VALIDÉE A À Z SÉPARÉMENT** | v9.1 contient la politique recovery façade puis arrière pour le DOM ; la preuve actuelle est bridge façade → OS arrière. |

## Statut des OS

| OS | Statut sur DS713+ |
|---|---|
| Debian 13 amd64 | **✅ VALIDÉ** en USB2 façade et via l'Etron arrière avec bridge v9.1 |
| OpenMediaVault 8 | 🟢 Très bon candidat ; base Debian 13 ; pas encore validé A à Z par ce dépôt |
| Ubuntu Server 26.04 LTS | 🟢 Candidat plausible ; pas encore validé ici |
| TrueNAS actuel | 🔴 Déconseillé ; les 8 Go actuels dépassent les 4 Go maximum du D2700 |

## Autres Synology

DS1513+/DS1813+/DS2413+, DS412+/DS1512+/DS1812+, RS812+ et apparentés Cedarview/Granite Well restent **des cibles de recherche uniquement**. Une plateforme similaire n'autorise pas l'utilisation du profil DS713+.

Chaque modèle/révision doit avoir sa propre identification chipset, map flash, permissions, géométrie d'effacement, double dump, validation sémantique et profil de sécurité.

## Hashes de référence

Les empreintes BIOS et candidat de l'unité de référence ne sont volontairement pas publiées : elles sont propres à cette unité et ne constituent pas des constantes de compatibilité.

Binaires bridge connus fonctionnels lors de l'expérience v9.1 :

```text
DS713Bridge v9.1  2c5a336e52a3d89bcf8029c85818ecbeb2a9477c6dd8367227c7027b5cc833ac
XhciDxe            20c3dbda0e0720fe171a7c0b06c995c4fe319f7338acfb75e9b5ee271a3092b3
```

Les hashes du bridge ci-dessus identifient des artefacts logiciels reproductibles ; la compatibilité matérielle reste déterminée par les probes de sécurité et les preuves de boot.
