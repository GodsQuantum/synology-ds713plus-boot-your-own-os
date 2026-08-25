# Matrice matériel validé

| Plateforme / port | Statut | Preuve |
|---|---|---|
| Synology DS713+ — USB2 frontal | **✅ VALIDÉ** | Clé non-F400 `abcd:1234`, Debian 13 UEFI démarré DOM interne retiré, SSH accessible après patch BIOS. |
| Synology DS713+ — USB/DOM interne | ⚠️ Attendu | Même chemin USB2 Intel ciblé, mais pas encore documenté avec un périphérique non-F400 arbitraire. |
| Synology DS713+ — USB3 arrière Etron EJ168A, deux ports | **❌ NON BOOTABLE AVEC LE PATCH ACTUEL** | Même clé Debian 13 UEFI `abcd:1234` connue fonctionnelle, testée sur les deux ports après coupure secteur complète. Pas d'activité de lecture normale de la clé, pas de DHCP/SSH. La même clé redémarre en USB2 frontal après cold boot. Linux exploite néanmoins l'EJ168A via `xhci_hcd` une fois le noyau démarré depuis un autre support. |
| DS412+/DS1512+/DS1812+/DS1513+/DS1813+/DS2413+/apparentés | ❓ NON VALIDÉS PAR CE DÉPÔT | Parenté Granite Well / retours communautaires uniquement. Probe et validation firmware spécifiques obligatoires. |

Le BIOS 2 Mio de référence a été lu deux fois à l'identique : SHA-256 `<reference-unit-sha256-redacted>`. Ce hash est une preuve historique, **pas une condition de compatibilité**.
