# Test de boot USB

Test le plus propre sur DS713+ :

1. après flash et double vérification, redémarrer une fois DSM ;
2. arrêt propre ;
3. débrancher l'alimentation assez longtemps pour réinitialiser complètement la plateforme ;
4. DOM Synology interne temporairement retiré ;
5. clé **UEFI x86-64** connue fonctionnelle sur l'USB2 frontal ;
6. rallumer et chercher DHCP/SSH ou toute preuve de démarrage de l'OS.

Une installation GRUB legacy/MBR uniquement n'est pas un test négatif valable du patch EFI. Préférer GPT + ESP avec `EFI/BOOT/BOOTX64.EFI` ou un chemin EFI résolvable.

## Résultat USB3 arrière Etron

Les deux ports USB3 arrière du DS713+ validé ont été testés avec la même clé Debian 13 UEFI ordinaire `abcd:1234` qui démarre correctement en USB2 frontal. Chaque essai arrière a été effectué après arrêt propre de l'OS puis coupure complète de l'alimentation. Aucun des deux ports arrière n'a montré l'activité de lecture USB normale observée pendant le boot frontal, et aucun boot Debian DHCP/SSH n'est apparu. Un cold boot suivant sur le port frontal a de nouveau réussi.

Il s'agit donc d'un **résultat négatif pour le boot arrière avec le patch F400 seul**, et non d'un échec du déverrouillage F400. Les ports arrière dépendent du contrôleur xHCI Etron EJ168A ; Linux sait l'utiliser via `xhci_hcd` une fois le noyau déjà démarré. Le patch BIOS actuel supprime uniquement le rejet VID/PID F400 et **n'ajoute pas** de driver firmware `XhciDxe`. L'ajout/test d'un driver EFI xHCI constitue une expérience future séparée.
