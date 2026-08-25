# Matrice du matériel validé

[← Retour au README](../README.fr.md) · [English](VERIFIED-HARDWARE.md)

## DS713+ de référence

| Plateforme / port | Statut | Preuve |
|---|---|---|
| Dump / patch / flash firmware DS713+ | **✅ VALIDÉ** | Double dump, validation candidat, écriture ICH10R hwseq, vérification candidat, double vérification région BIOS complète, reboot réussi. |
| DS713+ — USB 2.0 frontal | **✅ VALIDÉ** | Clé non-F400 `abcd:1234`, Debian 13 UEFI, DOM interne retiré, réseau + SSH atteints. |
| DS713+ — chemin USB/DOM interne | ⚠️ REMPLACEMENT NON VALIDÉ | Chemin Intel USB2 apparenté, mais boot d'un DOM/périphérique de remplacement arbitraire non testé séparément. |
| DS713+ — USB3 Etron EJ168A arrière port 1 | **❌ NON BOOTABLE AVEC LE PATCH ACTUEL** | Même clé Debian connue fonctionnelle, cold boot secteur complet, aucune lecture normale / aucun DHCP / SSH. |
| DS713+ — USB3 Etron EJ168A arrière port 2 | **❌ NON BOOTABLE AVEC LE PATCH ACTUEL** | Même résultat sur le deuxième port ; retest frontal après cold boot réussi. |
| DS713+ — Etron USB3 après boot Linux | **✅ FONCTIONNE SOUS LINUX** | Debian utilise le contrôleur via `xhci_hcd` ; ça ne prouve pas un support firmware au boot. |

## Statut des OS

| OS | Statut sur DS713+ |
|---|---|
| Debian 13 amd64 | **✅ VALIDÉ** en USB frontal jusqu'à Linux + réseau + SSH |
| OpenMediaVault 8 | 🟢 Très bon candidat ; base Debian 13 ; pas encore testé A à Z ici |
| Ubuntu Server 26.04 LTS | 🟢 Candidat plausible ; pas encore testé ici |
| TrueNAS actuel | 🔴 Déconseillé ; le minimum actuel de 8 Go dépasse les 4 Go max du D2700 |

## Autres Synology à étudier

Ces modèles ne sont **pas validés par ce repo**.

| Modèle(s) | Dernière branche OS Synology | Statut repo |
|---|---:|---|
| DS1513+ / DS1813+ / DS2413+ | DSM 7.1 | ❓ Cibles de recherche Granite Well/Cedarview |
| DS412+ / DS1512+ / DS1812+ | DSM 6.2 | ❓ Génération apparentée / prior art communautaire |
| RS812+ / x12 apparentés | DSM 6.2 | ❓ Génération apparentée / non validée |

Un nom de plateforme proche ne suffit jamais à autoriser un flash.

Chaque modèle/révision doit avoir ses propres :

1. identification chipset / PCI ;
2. taille de flash et descriptor map ;
3. permissions BIOS ;
4. géométrie d'effacement ;
5. double dump firmware ;
6. validation sémantique du module/patch ;
7. profil de sécurité spécifique.

Utilisez le formulaire hardware report pour partager les résultats probe/dump.

## Hashes de référence

Le DS713+ validé a produit deux lectures BIOS 2 Mio strictement identiques :

```text
<reference-unit-sha256-redacted>
```

C'est **une preuve historique, pas un hash universel de compatibilité**.

Le premier candidat audité manuellement avait pour SHA-256 :

```text
<reference-unit-sha256-redacted>
```

Une reconstruction valide peut différer au niveau des octets compressés. La validation sémantique/structurelle et le calcul correct de la patchzone physique sont plus importants que l'égalité avec ce hash candidat.
