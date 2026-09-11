# DS713NativeBoot N3

N3 est le chargeur UEFI désormais utilisé par le workflow principal du projet.

Il remplace l'ancien **Internal Shell** du firmware DS713+ en conservant son GUID FFS `C57AD6B7-0515-40A8-9D21-551652854E37`. Le but n'est pas de remplacer tout le firmware Intel/Tiano : on réutilise un point d'entrée déjà connu de BDS et on limite la modification au conteneur UEFI concerné.

## Politique de boot

```text
GPIO16 HIGH
attente 200 ms
GPIO20 HIGH

USB façade
  ↓ si aucun OS ne démarre
USB arrière Etron EJ168 + pile EDK2 embarquée
  ↓ si aucun OS ne démarre
SATA interne
```

Pour chaque contrôleur, N3 essaie d'abord les `Boot####` compatibles puis `\EFI\BOOT\BOOTX64.EFI` sur les filesystems découverts.

Aucun UUID, numéro de série de disque, nom d'OS ou numéro de port arrière n'est codé en dur.

## Payload validé

```text
Fichier   native/validated/DS713NativeBoot-N3.efi
SHA-256   63037d646791ddfc133840ecd5b4c80151213c61e8ce34862b7483799734d6a3
Taille    315392 octets
```

Ce binaire exact a cold-booté le DS713+ de validation sans clé bridge, depuis le SSD USB arrière, jusqu'à Ubuntu 26.04.1 + réseau + SSH.

Les sept EFI incorporés sont conservés sous `native/validated/drivers/` avec leurs hashes contrôlés par `scripts/native/00-prepare-loader.sh`.

Le source est fourni dans `native/DS713NativeBoot.c`, `.inf` et `.dsc`. `00-prepare-loader.sh --rebuild` permet de vérifier qu'un environnement de développement donné reproduit byte-for-byte le payload validé ; si le hash diffère, le script refuse de promouvoir le rebuild à la place du binaire validé.
