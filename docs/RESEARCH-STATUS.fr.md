# État actuel de la recherche DS713+

| Couche | État |
|---|---|
| Bypass `F400:F400` | ✅ Validé |
| USB2 façade non-F400 | ✅ Validé |
| Etron arrière avec patch F400 seul | ❌ Non bootable |
| Etron arrière via v9.1 | ✅ Validé Debian |
| Etron arrière via v9.4 | ✅ Validé SSD Linux |
| Etron arrière via v9.5 | ✅ Validé |
| SATA power pré-OS | ✅ Validé avec v9.5 |
| GPIO baie 1 / baie 2 | ✅ GPIO16 / GPIO20 |
| J2/DOM avec v9.4 | ❌ Test négatif |
| J2/DOM avec v9.5 | ❌ Test négatif |
| Cause exacte J2 | 🔬 Inconnue |
| xHCI intégré directement au firmware | 🔬 Recherche |
| Suppression de la clé bridge | 🔬 Recherche |

Les contributions prioritaires concernent J2 VBUS/reset/enable, logs série UEFI, ordre d'énumération DXE/BDS, éventuel chemin de boot DOM interne distinct, et intégration native xHCI/SATA-power.
