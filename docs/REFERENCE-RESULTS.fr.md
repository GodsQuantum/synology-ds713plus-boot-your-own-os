# Expérience DS713+ de référence — 25/08/2026

Ces valeurs documentent le premier test DS713+ entièrement validé. Ce ne sont **pas** des exigences génériques de compatibilité sauf lorsque `profiles/ds713plus.env` les impose explicitement.

## Lectures firmware

Les SHA-256 de l'unité de référence ne sont volontairement pas publiés. Ce sont des preuves propres à cette unité, pas des constantes de compatibilité ; chaque utilisateur doit valider localement son propre double dump.

Le conteneur 4 Mio **n'est pas un dump physique complet** : le hardware sequencing échoue à `0x211000`, juste après la région BIOS définie.

## Premier candidat audité manuellement

Les empreintes du candidat et du conteneur de l'unité de référence ne sont volontairement pas publiées. Le dépôt dérive et vérifie le candidat de chaque utilisateur à partir de son propre dump firmware.

Diff physique après reconstruction LZMA :

```text
DIFF_BYTES_TOTAL=541738
DIFF_FIRST_PHYSICAL=0x011058
DIFF_LAST_PHYSICAL=0x095d28
PATCH_START=0x011000
PATCH_END=0x095fff
PATCH_SIZE=544768
PATCH_INSIDE_BIOS=YES
```

Le dépôt recalcule ces valeurs à partir du dump de chaque utilisateur. Une reconstruction compressée valide différente peut donner une autre plage physique sûre.

## Validation d'écriture

Le premier flash a terminé en `FINAL_STATUS=SUCCESS_CANDIDATE_VERIFIED`. La patchzone a été vérifiée indépendamment, puis toute la région BIOS `0x011000-0x210fff` (2 Mio) a été vérifiée deux fois avant reboot.

DSM a redémarré normalement. DOM interne retiré, une clé Debian 13 UEFI ordinaire VID:PID `abcd:1234` a démarré depuis l'USB2 frontal et a été jointe en SSH.

## Matrice physique de boot USB

Avec la même clé Debian 13 UEFI (`abcd:1234`) et le DOM interne débranché :

- **USB2 frontal :** démarrage réussi jusqu'à Debian et SSH.
- **USB3 arrière port 1 (Etron EJ168A) :** pas d'activité de lecture USB normale et aucun boot Debian DHCP/SSH après cycle secteur complet.
- **USB3 arrière port 2 (Etron EJ168A) :** même résultat négatif après cycle secteur complet.
- **Retest USB2 frontal :** de nouveau réussi après cold boot, confirmant que la clé et l'installation Debian restaient bootables.

Le résultat négatif arrière concerne spécifiquement la modification firmware **F400 seule** actuelle. Le contrôleur Etron est visible et utilisable sous Debian via `xhci_hcd` une fois Linux démarré depuis le port frontal. Aucun driver firmware `XhciDxe` n'a été ajouté par ce patch.

## Expérience bridge — 27/08/2026

L'expérience de boot arrière ultérieure a conservé le patch firmware F400 tel quel et ajouté uniquement un bridge amovible en façade.

```text
DS713Bridge v9.1 BOOTX64.EFI
2c5a336e52a3d89bcf8029c85818ecbeb2a9477c6dd8367227c7027b5cc833ac

XhciDxe.efi
20c3dbda0e0720fe171a7c0b06c995c4fe319f7338acfb75e9b5ee271a3092b3
```

Résultat : **Debian 13 a booté depuis un stockage derrière le contrôleur Etron jusqu'au réseau/SSH.** Le bridge lui-même prenait environ 3–4 s avant de passer la main au loader OS arrière.

Meilleure référence mesurée avec Limine + initrd réduit :

```text
firmware   14,600 s
loader     56,477 s
kernel      5,483 s
userspace  21,203 s
systemd     1m37,765s total
power-to-network externe  ~117 s
```

Environ 25,71 Mio étaient lus avant le kernel. Le débit UEFI pré-kernel effectif était ~0,453 Mio/s ; Linux lisait ensuite le même média arrière à ~18,6 Mio/s. Le chargement Limine natif par le port frontal était pire (~359,5 s loader / ~423 s power-to-network) : « natif frontal » n'était donc pas une solution de vitesse.

Une pile stockage EDK2 moderne complète a booté mais régressé à ~199 s jusqu'au réseau. UKI direct et harness diagnostics ultérieurs n'ont pas fourni de voie de déploiement fiable. Ce sont des résultats de recherche, pas des recommandations.

## DS713Bridge v9.4 FULL-STACK R2 — validation physique (2026-09-01)

- USB façade : clé bridge v9.4 ;
- Etron arrière : SSD système Ubuntu/Linux existant ;
- résultat : Linux, réseau et SSH atteints ;
- SHA-256 creator exact : `6af4b3291f058093a9d2673a51596bb0525b57d5a818587166575f86709f206b` ;
- SHA-256 source embarquée : `75e00a082b11dbb9684eb240f77dbdbe3cfde952b90f7e4f8274020432a0ba39` ;
- profil EDK2 par défaut : `edk2-stable202605` / `b03a21a63e3bd001f52c527e5a57feddb53a690b` ;
- pile complète : `XhciDxe`, `UsbBusDxe`, `UsbMassStorageDxe`, `DiskIoDxe`, `PartitionDxe`, `EnglishDxe`, `Fat` ;
- vitesse USB/UAS/TRIM et temps alimentation→SSH exact sont mesurés séparément après boot Linux.
