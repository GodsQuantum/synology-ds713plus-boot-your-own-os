# Fonctionnement du verrou F400

Dans le firmware DS713+ validé, le PE32 `UsbBusDxe` (GUID FFS `240612B7-A063-11D4-9A3A-0090273FC14D`) charge `0xF400`, compare cette valeur au VID puis au PID USB et saute vers `EFI_NOT_FOUND` dès qu'une valeur diffère. Remplacer les deux `JNE` de six octets par des NOP conserve le chemin normal d'énumération.

Le module est encapsulé dans une structure firmware compressée LZMA. Une modification sémantique de 12 octets entraîne donc une différence physique de plusieurs centaines de Kio après reconstruction. La géométrie d'effacement et l'alignement réel sont essentiels.

Sur l'ICH10R validé, `BERASE=1` et flashrom hwseq annonce 1024 blocs de 4096 octets. Le premier candidat de référence différait physiquement de `0x011058` à `0x095d28`, soit `0x011000-0x095fff` une fois aligné 4 Kio. Les scripts recalculent cette plage.

## Couche bridge xHCI arrière

Le patch F400 et le bridge arrière corrigent deux couches différentes. F400 change la politique de `UsbBusDxe` pour les périphériques que le firmware sait déjà énumérer. Le contrôleur arrière Etron EJ168A ne dispose pas d'un chemin xHCI de boot natif utilisable dans le firmware Granite Well stock.

DS713Bridge v9.1 s'exécute donc avant le loader OS arrière, démarre le `XhciDxe` validé, filtre les nouveaux filesystems par ascendance device-path sous Etron et chaîne uniquement `\EFI\BOOT\BOOTX64.EFI`. Le bridge de déploiement évite volontairement de remplacer toute la pile stockage ; une expérience full-stack ultérieure était plus lente.

La recherche long terme vise un dispatch xHCI natif pendant DXE avant BDS afin que le firmware lui-même puisse énumérer l'arrière sans bridge amovible.

## v9.5 : couche SATA-power séparée

Il faut distinguer le bypass firmware F400, la pile Etron arrière v9.4, l'alimentation SATA v9.5 et le chemin J2/DOM toujours non résolu.
