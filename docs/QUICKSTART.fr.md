# Démarrage rapide DS713+ — déverrouillage F400 + bridge USB3 arrière

[← README](../README.fr.md) · [English](QUICKSTART.md) · [Sécurité](SAFETY.fr.md)

C'est le chemin supporté le plus court pour le **profil DS713+ validé**. Un flash firmware peut briquer le matériel. Ne sautez aucun garde-fou.

## Phase A — autoriser les périphériques USB ordinaires dans le firmware

### Prérequis

- un **Synology DS713+** qui démarre encore DSM ;
- un poste Linux avec `git`, `ssh`, `python3`, `bash` et Docker ou Podman ;
- un compte administrateur DSM capable d'exécuter `sudo` ;
- une alimentation stable ; onduleur fortement recommandé ;
- ce dépôt cloné sur le poste Linux.

Les scripts firmware ciblent volontairement **DSM tant que DSM fonctionne encore**. N'exécutez pas les étapes 00–08 contre l'installation Debian/OMV installée ensuite.

```bash
git clone https://github.com/GodsQuantum/synology-ds713plus-boot-your-own-os.git
cd synology-ds713plus-boot-your-own-os

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

Arrêtez-vous au premier échec. `02-probe.sh` doit valider `PROBE_SAFE_PROFILE=YES` et `06-preflight.sh` doit réussir complètement.

### Écriture SPI réelle

L'écriture est volontairement séparée de la préparation :

```bash
./scripts/07-flash.sh prepare
./scripts/07-flash.sh status

# Continuer uniquement si le statut vaut exactement STATUS=WAITING_FOR_ARM
./scripts/07-flash.sh arm

# Répéter jusqu'à obtenir un FINAL_STATUS
./scripts/07-flash.sh status

# Obligatoire avant reboot
./scripts/08-postflash-verify.sh
```

Ne **redémarrez pas** tant que la dernière commande n'affiche pas :

```text
READY_FOR_REBOOT=YES
```

Si le statut devient `FINAL_STATUS=CRITICAL_DO_NOT_REBOOT`, laissez le NAS allumé et consultez [Récupération](RECOVERY.fr.md).

## Phase B — créer la clé bridge USB3 arrière

Le patch F400 permet au firmware d'accepter une clé ordinaire en façade. Il ne sait pas, à lui seul, initialiser le contrôleur xHCI Etron EJ168A arrière.

Pour placer le média OS derrière, créez une deuxième petite clé bridge depuis un poste Linux :

```bash
lsblk -o NAME,PATH,TRAN,SIZE,FSTYPE,LABEL,MODEL,SERIAL,MOUNTPOINTS

# Exemple uniquement : remplacez sdb par la clé USB que vous acceptez d'EFFACER.
sudo SDX=sdb ./scripts/10-create-usb3-bridge.sh
```

Le writer refuse le disque système, les cibles non USB et les cibles qui ne sont pas un disque entier, puis exige une confirmation destructive exacte.

### Disposition physique

```text
USB 2.0 façade : clé DS713Bridge v9.1
Etron arrière  : média contenant votre OS
```

Le média arrière doit booter en UEFI x86-64 et exposer le chemin amovible standard :

```text
\EFI\BOOT\BOOTX64.EFI
```

Le bridge est agnostique du bootloader : GRUB, systemd-boot, Limine, rEFInd et les autres loaders UEFI standards peuvent fonctionner derrière lui.

## Ce qui est validé

- déverrouillage F400 : Debian 13 non-F400 en façade jusqu'au réseau/SSH ;
- arrière avec patch F400 seul : résultat négatif sur les deux ports ;
- DS713Bridge v9.1 : Debian 13 via contrôleur Etron arrière jusqu'au réseau/SSH ;
- code du bridge : aucun UUID OS, serial disque, numéro de port arrière, `BootOrder` ou `BootNext` codé en dur.

Voir [Matériel validé](VERIFIED-HARDWARE.fr.md) et [Bridge USB3 arrière](USB3-BRIDGE.fr.md) pour les preuves et hashes exacts.
