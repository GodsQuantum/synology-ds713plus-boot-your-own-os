# Modèle de sécurité

1. **Aucun firmware n'est fourni.** Deux dumps indépendants de votre NAS sont obligatoires.
2. **Probe avant toute opération.** Le write n'accepte que les invariants ICH10R / 4 Mio / blocs 4 Kio / région BIOS RW validés.
3. **Jamais de full-chip write.** Le DS713+ testé échoue à `0x211000` ; la partie supérieure n'est pas un dump physique fiable.
4. **Patchzone dynamique.** La recompression modifie de nombreux octets physiques ; la plage est calculée et alignée sur la géométrie d'effacement réelle.
5. **Écriture en deux temps.** `prepare` démarre un worker détaché bloqué sur `WAITING_FOR_ARM`; `arm` est une action séparée.
6. **Rollback automatique tenté** si le candidat ne se vérifie pas tant que Linux fonctionne encore.
7. **Aucun reboot automatique.** Toute la région BIOS de 2 Mio doit être vérifiée deux fois.
8. **Alimentation stable / onduleur fortement conseillé.** Aucun logiciel ne peut éliminer tous les risques matériels.

Si `FINAL_STATUS=CRITICAL_DO_NOT_REBOOT`, ne coupez pas le NAS et récupérez le log complet.

## Sécurité de la clé bridge

`scripts/10-create-usb3-bridge.sh` efface entièrement le disque USB sélectionné. Il n'accepte qu'un disque USB entier `/dev/sdX`, refuse le disque système courant et les cibles non USB, affiche modèle/serial puis exige une confirmation destructive exacte sauf automatisation explicite avec `YES=1`.

Pour un build bridge neuf, le script distingue l'identité binaire brute exacte des rebuilds équivalents par source/normalisation. Ne présentez pas un rebuild frais comme le PE physiquement testé exact si son SHA-256 ne correspond pas à la référence connue.

## v9.5 : identité USB stable

Une vraie réénumération USB a changé un nom `/dev/sdX` pendant le développement. v9.5 sélectionne donc un disque USB entier, dérive `/dev/disk/by-id/usb-*`, puis le writer v9.4 résout/revalide cette identité juste avant les écritures destructives.
