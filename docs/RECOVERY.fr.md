# États de récupération

- `FINAL_STATUS=SUCCESS_CANDIDATE_VERIFIED` : candidat relu correctement ; exécuter quand même `08-postflash-verify.sh` avant reboot.
- `FINAL_STATUS=ROLLBACK_ORIGINAL_VERIFIED` : candidat en échec, zone originale restaurée et vérifiée.
- `FINAL_STATUS=CRITICAL_DO_NOT_REBOOT` : ni candidat ni rollback vérifiés. **Ne pas redémarrer ni couper l'alimentation.** Conserver la machine allumée et les logs.

Un programmateur SPI externe reste le moyen de récupération universel recommandé pour toute personne qui ne peut accepter la perte du matériel, même si l'expérience validée ici a été réalisée uniquement par logiciel.

## Récupération de la clé bridge

Le bridge est amovible et ne modifie pas le média OS arrière. Si une expérience bridge échoue, recréez la dernière v9.1 connue fonctionnelle depuis une autre machine Linux avec `scripts/10-create-usb3-bridge.sh`. Si les fichiers v9.1/Xhci validés exacts sont déjà présents sur la clé choisie, le writer les sauvegarde avant repartitionnement et les réutilise byte-for-byte.

## Clé bridge actuelle

Recréez le bridge actuel avec :

```bash
./scripts/13-create-usb3-bridge-v95.sh
```

v9.4 et v9.1 restent des références historiques/de recherche.
