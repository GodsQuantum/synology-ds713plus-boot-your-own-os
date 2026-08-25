# Expérience DS713+ de référence — 25/08/2026

Ces valeurs documentent le premier test DS713+ entièrement validé. Ce ne sont **pas** des exigences génériques de compatibilité sauf lorsque `profiles/ds713plus.env` les impose explicitement.

## Lectures firmware

```text
BIOS 2 Mio, lectures #1/#2 :
<reference-unit-sha256-redacted>

Conteneur 4 Mio des régions définies IFD, lectures #1/#2 :
<reference-unit-sha256-redacted>
```

Le conteneur 4 Mio **n'est pas un dump physique complet** : le hardware sequencing échoue à `0x211000`, juste après la région BIOS définie.

## Premier candidat audité manuellement

```text
Candidat BIOS 2 Mio :
<reference-unit-sha256-redacted>

Conteneur candidat 4 Mio :
<reference-unit-sha256-redacted>
```

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
