# Annexe — DS713Bridge

**DS713Bridge est l'ancienne méthode de boot USB 3.0 arrière.** Elle est conservée parce qu'elle a servi à comprendre le DS713+, à valider l'Etron EJ168 et à construire N3. Elle n'est plus nécessaire pour le workflow recommandé.

Le chemin actuel est : **firmware F400 + N3 → média OS directement**. Voir [le démarrage rapide](../docs/QUICKSTART.fr.md).

## Quand le bridge reste utile

- vous voulez expérimenter sans installer N3 dans le firmware ;
- vous voulez une clé de secours amovible ;
- vous diagnostiquez le contrôleur Etron ou la pile UEFI ;
- vous reproduisez l'historique de recherche du projet.

## Versions

| Version | Rôle | État |
|---|---|---|
| v9.1 | première preuve de boot arrière via XhciDxe | historique, validée |
| v9.3 | itération de recherche | historique |
| v9.4 FULL-STACK R2 | pile xHCI + USB + storage + filesystem complète | validée |
| v9.5 SATA-POWER | v9.4 + GPIO16 → 200 ms → GPIO20 | validée |

Pour recréer la dernière clé :

```bash
./scripts/13-create-usb3-bridge-v95.sh
```

Le script sélectionne uniquement un disque USB entier, exige une identité stable `/dev/disk/by-id/usb-*`, construit la pile EDK2 avant l'effacement puis demande une confirmation destructive explicite.

## Documentation historique

- [Vue d'ensemble USB3](../docs/USB3-BRIDGE.fr.md)
- [v9.4 FULL-STACK](../docs/USB3-BRIDGE-V94.fr.md)
- [v9.5 SATA-POWER](../docs/USB3-BRIDGE-V95.fr.md)
- [État de la recherche](../docs/RESEARCH-STATUS.fr.md)
- [Handoff recherche](../docs/RESEARCH-HANDOFF.md)

Les sources restent ici (`DS713Bridge-v9.x.c`) avec leurs tests statiques. Elles ne sont pas supprimées : N3 réutilise directement les leçons et les drivers validés par ce travail.
