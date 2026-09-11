# DS713+ — démarrage rapide

Le chemin recommandé transforme un **DS713+ retail encore sous DSM** en machine capable de démarrer un OS UEFI x86-64 normal sans clé bridge permanente.

Le firmware final fait deux choses en une seule écriture SPI :

- supprime le verrou USB Synology `F400:F400` ;
- remplace l'ancien Internal Shell par **DS713NativeBoot N3**, le chargeur validé sur le vrai DS713+.

N3 alimente les deux baies SATA, essaie d'abord l'USB façade, initialise ensuite le contrôleur USB 3.0 Etron arrière, puis essaie le stockage SATA interne. Le fallback OS est le chemin UEFI standard `\EFI\BOOT\BOOTX64.EFI`.

> ⚠️ Le flash firmware comporte un risque réel. Lisez [SAFETY.fr.md](SAFETY.fr.md) et [RECOVERY.fr.md](RECOVERY.fr.md) avant `arm`.

## 1. Prérequis

- DS713+ encore bootable sous DSM ;
- SSH activé sur DSM ;
- compte administrateur DSM ;
- PC Linux sur le même réseau ;
- alimentation stable ;
- aucun reboot forcé pendant le flash.

Sur le PC :

```bash
git clone https://github.com/GodsQuantum/synology-ds713plus-boot-your-own-os.git
cd synology-ds713plus-boot-your-own-os

export NAS_HOST='192.168.1.x'
export NAS_USER='votre-admin-dsm'
```

## 2. Audit + double dump — aucune écriture SPI

```bash
./scripts/open-ds713plus.sh audit
```

Cette étape :

1. construit le `flashrom` utilisé par le projet ;
2. l'installe côté DSM ;
3. vérifie le chipset, la taille SPI, les protections et la géométrie d'effacement ;
4. lit deux fois le BIOS et les régions SPI utilisées ;
5. refuse de continuer si les deux lectures diffèrent ;
6. construit les outils UEFI nécessaires à la reconstruction.

## 3. Construire le firmware F400 + N3 — toujours aucune écriture SPI

```bash
./scripts/open-ds713plus.sh build
```

Le build utilise par défaut le **N3 exactement validé sur hardware** :

```text
SHA-256  63037d646791ddfc133840ecd5b4c80151213c61e8ce34862b7483799734d6a3
Taille   315392 octets
```

Le source complet est dans `native/`. Le binaire validé et les sept drivers EDK2 incorporés sont dans `native/validated/`.

Le script part de vos propres dumps, applique le patch F400, insère N3 dans le slot Internal Shell, reconstruit le conteneur UEFI compressé, reparse le résultat et calcule la plus petite patchzone 4 KiB contiguë.

## 4. Preflight live + préparation — encore aucune écriture SPI

```bash
./scripts/open-ds713plus.sh prepare
```

Le NAS revérifie immédiatement que la zone actuellement en flash correspond bien au dump qui a servi à construire le candidat. Le worker distant s'arrête ensuite sur :

```text
STATUS=WAITING_FOR_ARM
```

À ce stade, rien n'a été écrit dans la SPI.

## 5. Armer explicitement le flash

Relisez le statut :

```bash
./scripts/open-ds713plus.sh status
```

Uniquement si vous voyez `STATUS=WAITING_FOR_ARM` :

```bash
./scripts/open-ds713plus.sh arm
```

Le worker écrit seulement la patchzone calculée, vérifie le candidat **deux fois**, et tente automatiquement un rollback vers les octets d'origine si une vérification échoue. Le worker tourne côté NAS : une coupure du terminal PC ne doit pas interrompre le processus en plein milieu.

Suivez :

```bash
./scripts/open-ds713plus.sh status
```

Le succès attendu est :

```text
FINAL_STATUS=SUCCESS_CANDIDATE_VERIFIED_TWICE
```

## 6. Vérification BIOS complète avant reboot

```bash
./scripts/open-ds713plus.sh verify
```

Cette étape revérifie deux fois **toute la région BIOS** contre le candidat final.

Ne redémarrez que si la sortie finit par :

```text
READY_FOR_REBOOT=YES
```

## 7. Préparer le média OS

Pour le chemin le plus portable, le disque ou la clé UEFI doit proposer :

```text
\EFI\BOOT\BOOTX64.EFI
```

N3 sait aussi réutiliser des `Boot####` valides lorsqu'ils correspondent au contrôleur exploré.

Priorité physique N3 :

```text
1. USB 2.0 façade
2. USB 3.0 arrière / Etron EJ168
3. SATA interne
```

Les deux baies SATA sont alimentées avant la recherche de boot : GPIO16 HIGH, attente 200 ms, puis GPIO20 HIGH.

## 8. Premier boot

Après `READY_FOR_REBOOT=YES`, arrêtez DSM proprement, retirez la clé bridge si vous en utilisiez une, branchez le média OS et démarrez.

Le N3 validé a effectué un cold boot sans bridge jusqu'à Ubuntu 26.04.1 + réseau + SSH depuis le SSD USB arrière. Le breadcrumb UEFI observé était `0x277`, soit : GPIO OK, contrôleur façade vu, Etron vu, pile arrière chargée, filesystem arrière trouvé et chainload effectué.

Le second boot de validation a atteint `graphical.target` en **46,16 s côté Linux**. Cette mesure commence après le handoff firmware ; elle n'est pas une mesure du temps électrique total power-on → SSH.

## Et la clé DS713Bridge ?

Elle n'est plus nécessaire pour le chemin principal.

Elle reste utile comme :

- fallback amovible ;
- outil de diagnostic ;
- méthode historique ne nécessitant pas N3 en firmware ;
- base de recherche pour les contrôleurs Etron/UEFI.

Toute la méthode est conservée dans **[bridge/README.fr.md](../bridge/README.fr.md)**.
