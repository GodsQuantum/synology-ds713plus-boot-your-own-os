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
