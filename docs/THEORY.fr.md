# Fonctionnement du verrou F400

Dans le firmware DS713+ validé, le PE32 `UsbBusDxe` (GUID FFS `240612B7-A063-11D4-9A3A-0090273FC14D`) charge `0xF400`, compare cette valeur au VID puis au PID USB et saute vers `EFI_NOT_FOUND` dès qu'une valeur diffère. Remplacer les deux `JNE` de six octets par des NOP conserve le chemin normal d'énumération.

Le module est encapsulé dans une structure firmware compressée LZMA. Une modification sémantique de 12 octets entraîne donc une différence physique de plusieurs centaines de Kio après reconstruction. La géométrie d'effacement et l'alignement réel sont essentiels.

Sur l'ICH10R validé, `BERASE=1` et flashrom hwseq annonce 1024 blocs de 4096 octets. Le premier candidat de référence différait physiquement de `0x011058` à `0x095d28`, soit `0x011000-0x095fff` une fois aligné 4 Kio. Les scripts recalculent cette plage.
