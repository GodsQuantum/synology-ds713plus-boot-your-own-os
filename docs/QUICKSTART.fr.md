# DS713+ — démarrage rapide

Ce document donne le chemin pratique. Les détails de reverse engineering sont dans `RESEARCH-HANDOFF.md`.

## A. Télécharger le projet

Sur un PC Linux :

```bash
git clone https://github.com/GodsQuantum/synology-ds713plus-boot-your-own-os.git
cd synology-ds713plus-boot-your-own-os
```

## B. Déverrouiller le firmware du DS713+ une seule fois

Prérequis : DSM encore bootable, compte admin SSH, PC Linux avec Docker ou Podman, alimentation stable.

```bash
export NAS_HOST='192.168.1.x'
export NAS_USER='votre-admin-dsm'

./scripts/00-build-flashrom.sh
./scripts/01-install-flashrom.sh
./scripts/02-probe.sh
./scripts/03-dump.sh
./scripts/04-build-uefi-tools.sh
./scripts/05-patch-bios.sh artifacts/bios-read1.bin
./scripts/06-preflight.sh
```

Arrêtez-vous au premier échec.

La vraie écriture SPI reste volontairement séparée :

```bash
./scripts/07-flash.sh prepare
./scripts/07-flash.sh status

# uniquement si STATUS=WAITING_FOR_ARM :
./scripts/07-flash.sh arm
./scripts/07-flash.sh status

# obligatoire avant reboot :
./scripts/08-postflash-verify.sh
```

Ne redémarrez que si `READY_FOR_REBOOT=YES`.

## C. Créer la clé DS713Bridge v9.5

Depuis le dossier du projet :

```bash
./scripts/13-create-usb3-bridge-v95.sh
```

Le script :

1. liste uniquement les disques USB entiers utilisables ;
2. affiche taille, modèle, numéro de série et identité stable ;
3. demande simplement le numéro de la clé ;
4. conserve la cible via `/dev/disk/by-id/usb-*` ;
5. compile et vérifie avant l'effacement ;
6. demande une confirmation destructive explicite ;
7. écrit puis vérifie la clé.

## D. Brancher

```text
USB façade     : clé DS713Bridge v9.5
USB arrière    : SSD / clé contenant l'OS
baies SATA     : alimentées automatiquement par v9.5 avant Linux
```

Le média OS arrière doit fournir :

```text
\EFI\BOOT\BOOTX64.EFI
```

## E. État réel

- bypass firmware `F400:F400` : validé ;
- boot USB normal en façade : validé ;
- boot du SSD Linux via Etron arrière avec v9.5 : validé ;
- alimentation SATA GPIO16 -> 200 ms -> GPIO20 avant Linux : validée ;
- J2/DOM interne : testé avec v9.4/v9.5, non résolu.

Pour poursuivre la recherche : `docs/RESEARCH-HANDOFF.md`.
