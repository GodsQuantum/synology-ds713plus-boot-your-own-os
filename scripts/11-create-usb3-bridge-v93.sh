#!/usr/bin/env bash
set -Eeuo pipefail
export LC_ALL=C

TARGET="${TARGET:-${SDX:-${1:-}}}"
LABEL="${LABEL:-DS713V93}"
YES="${YES:-0}"
XHCI_EFI="${XHCI_EFI:-}"

V93_SOURCE_SHA="85a7d6961825b1e9775d015727ac28aef2d2301517b9220f9eb874e4e911af6a"
XHCI_VALIDATED_SHA="20c3dbda0e0720fe171a7c0b06c995c4fe319f7338acfb75e9b5ee271a3092b3"
XHCI_NORMALIZED_SHA="ecb9726a4ecd6ce1fe39874b6b8a0e9374bfdcaa08da77fbb3de827bae258e30"
EDK_TAG="edk2-stable202605"
EDK_COMMIT="b03a21a63e3bd001f52c527e5a57feddb53a690b"

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BRIDGE_SOURCE="$HERE/../bridge/DS713Bridge-v9.3.c"
V93_TEST="$HERE/../bridge/test_v93_static.py"

fail(){ echo "ERREUR: $*" >&2; exit 1; }
need(){ command -v "$1" >/dev/null 2>&1 || fail "commande manquante: $1"; }

for cmd in lsblk findmnt readlink awk xargs sha256sum mount umount mountpoint wipefs sfdisk udevadm install find grep sed file objdump gcc ld objcopy python3 sync; do need "$cmd"; done
MKFS_FAT="$(command -v mkfs.fat || command -v mkfs.vfat || true)"
FSCK_FAT="$(command -v fsck.fat || command -v fsck.vfat || true)"
[[ -n "$MKFS_FAT" && -n "$FSCK_FAT" ]] || fail "dosfstools requis"
[[ -f "$BRIDGE_SOURCE" ]] || fail "DS713Bridge-v9.3.c absent"
[[ -f "$V93_TEST" ]] || fail "test_v93_static.py absent"

printf '%s\n' '============================================================'
printf '%s\n' ' DS713+ — CREATE USB3 REAR BRIDGE V9.3 CANDIDATE'
printf '%s\n' ' v9.1 fast path preserved; v9.3 not yet hardware-validated'
printf '%s\n' '============================================================'

if [[ -z "$TARGET" ]]; then
    echo
    echo 'Disques USB détectés :'
    lsblk -dpno NAME,TRAN,SIZE,MODEL,SERIAL | awk '$2=="usb" {print "  "$0}'
    echo
    read -r -p "Chemin du disque USB à transformer en bridge (ex. /dev/sdX): " TARGET
fi
[[ -n "$TARGET" ]] || fail "aucune cible choisie"
[[ "$TARGET" == /dev/* ]] || TARGET="/dev/$TARGET"
TARGET="$(readlink -f "$TARGET")"

[[ $EUID -eq 0 ]] || fail "relancer avec sudo/root"
[[ -b "$TARGET" ]] || fail "cible inexistante: $TARGET"
[[ "$(lsblk -dn -o TYPE "$TARGET" | xargs)" == disk ]] || fail "la cible doit être un disque entier"
TRAN="$(lsblk -dn -o TRAN "$TARGET" | xargs)"
[[ "$TRAN" == usb ]] || fail "REFUS: cible non USB (TRAN=$TRAN)"

ROOTSRC="$(findmnt -n -o SOURCE /)"
ROOTDEV="${ROOTSRC%%\[*}"
ROOTDISK="$({ lsblk -s -nrpo PATH,TYPE "$ROOTDEV" 2>/dev/null || true; } | awk '$2=="disk" {print $1; exit}')"
[[ -n "$ROOTDISK" ]] || fail "disque système impossible à identifier"
[[ "$(readlink -f "$ROOTDISK")" != "$TARGET" ]] || fail "REFUS: TARGET est le disque système"

printf '\n===== 1. CIBLE =====\n'
lsblk -o NAME,PATH,TRAN,SIZE,FSTYPE,LABEL,MODEL,SERIAL,MOUNTPOINTS "$TARGET"
echo "TARGET=$TARGET"
echo "ROOTDISK=$ROOTDISK"
echo "USB_TARGET_SAFETY=PASS"

printf '\n===== 2. SOURCE V9.3 =====\n'
SRC_SHA="$(sha256sum "$BRIDGE_SOURCE" | awk '{print $1}')"
[[ "$SRC_SHA" == "$V93_SOURCE_SHA" ]] || fail "source v9.3 inattendue: $SRC_SHA"
python3 "$V93_TEST"
echo "V93_SOURCE_SHA=$SRC_SHA"

WORK="$(mktemp -d /tmp/ds713-v93-create.XXXXXX)"
MNT="$(mktemp -d /tmp/ds713-v93-mnt.XXXXXX)"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/ds713plus-bridge"
mkdir -p "$CACHE"
cleanup(){ mountpoint -q "$MNT" 2>/dev/null && umount "$MNT" || true; rm -rf "$WORK" "$MNT"; }
trap cleanup EXIT

V93="$WORK/DS713Bridge-v9.3.efi"
XHCI="$WORK/XhciDxe.efi"
XHCI_PROVENANCE=""

printf '\n===== 3. BUILD V9.3 =====\n'
[[ -f /usr/include/efi/efi.h ]] || fail "gnu-efi requis"
CRT0="$(find /usr/lib /usr/lib64 -maxdepth 4 -name crt0-efi-x86_64.o -print -quit 2>/dev/null)"
LDS="$(find /usr/lib /usr/lib64 -maxdepth 4 -name elf_x86_64_efi.lds -print -quit 2>/dev/null)"
[[ -n "$CRT0" && -n "$LDS" ]] || fail "fichiers gnu-efi introuvables"
LIBDIR="$(dirname "$CRT0")"
[[ -f "$LIBDIR/libefi.a" ]] || LIBDIR=/usr/lib
[[ -f "$LIBDIR/libefi.a" && -f "$LIBDIR/libgnuefi.a" ]] || fail "libefi/libgnuefi introuvables"
LIBGCC="$(gcc -print-libgcc-file-name)"
gcc -isystem /usr/include/efi -isystem /usr/include/efi/x86_64 -isystem /usr/include/efi/protocol \
  -DCONFIG_x86_64 -DGNU_EFI_USE_MS_ABI -maccumulate-outgoing-args -mno-red-zone -mno-avx \
  -std=c11 -O2 -Wall -Wextra -Wstrict-prototypes -Werror -fshort-wchar -fno-strict-aliasing \
  -ffreestanding -fno-stack-protector -fno-stack-check -fno-merge-all-constants -fpic \
  -c "$BRIDGE_SOURCE" -o "$WORK/v93.o"
ld -nostdlib --warn-common --no-undefined --fatal-warnings --build-id=sha1 -z norelro -z nocombreloc \
  -T "$LDS" -shared -Bsymbolic "$CRT0" "$WORK/v93.o" -L"$LIBDIR" -lefi -lgnuefi "$LIBGCC" -o "$WORK/v93.so"
objcopy -j .text -j .sdata -j .data -j .dynamic -j .dynsym -j .rodata -j .rel -j .rela \
  -j '.rel.*' -j '.rela.*' -j .reloc -O pei-x86-64 --subsystem efi-app \
  --section-alignment 0x1000 --file-alignment 0x200 "$WORK/v93.so" "$V93"
file "$V93" | grep -q 'PE32+ executable for EFI (application)' || fail "PE v9.3 invalide"
objdump -p "$V93" | grep -q 'Subsystem.*EFI application' || fail "subsystem EFI invalide"
V93_SHA="$(sha256sum "$V93" | awk '{print $1}')"
echo "V93_EFI_SHA=$V93_SHA"

printf '\n===== 4. XHCIDXE VALIDE =====\n'
if [[ -n "$XHCI_EFI" ]]; then
    [[ -f "$XHCI_EFI" ]] || fail "XHCI_EFI introuvable"
    cp "$XHCI_EFI" "$XHCI"
    [[ "$(sha256sum "$XHCI" | awk '{print $1}')" == "$XHCI_VALIDATED_SHA" ]] || fail "XHCI_EFI explicite doit être le binaire exact validé"
    XHCI_PROVENANCE="exact-explicit"
fi
if [[ ! -f "$XHCI" ]]; then
    while read -r PART; do
        [[ -b "$PART" ]] || continue
        [[ "$(lsblk -n -o FSTYPE "$PART" | xargs)" == vfat ]] || continue
        mount -o ro "$PART" "$MNT" || continue
        if [[ -f "$MNT/EFI/DS713/XhciDxe.efi" ]] && [[ "$(sha256sum "$MNT/EFI/DS713/XhciDxe.efi" | awk '{print $1}')" == "$XHCI_VALIDATED_SHA" ]]; then
            cp "$MNT/EFI/DS713/XhciDxe.efi" "$XHCI"
            XHCI_PROVENANCE="exact-recovered"
        fi
        umount "$MNT"
        [[ -f "$XHCI" ]] && break
    done < <(lsblk -lnpo NAME,TYPE "$TARGET" | awk '$2=="part" {print $1}')
fi
if [[ ! -f "$XHCI" ]]; then
    for cmd in git make; do need "$cmd"; done
    EDK="${EDK2_DIR:-$CACHE/$EDK_TAG}"
    if [[ ! -d "$EDK/.git" ]]; then
        git clone --depth 1 --branch "$EDK_TAG" https://github.com/tianocore/edk2.git "$EDK"
        git -C "$EDK" submodule update --init --depth 1
    fi
    [[ "$(git -C "$EDK" rev-parse HEAD)" == "$EDK_COMMIT" ]] || fail "commit EDK2 inattendu"
    make -C "$EDK/BaseTools" -j"$(nproc)"
    WS="/tmp/ds713-edk2-v93-$$"; ln -s "$EDK" "$WS"
    export WORKSPACE="$WS" PACKAGES_PATH="$WS" EDK_TOOLS_PATH="$WS/BaseTools" PYTHON_COMMAND=python3 SOURCE_DATE_EPOCH=0
    pushd "$WS" >/dev/null
    set +u; source "$WS/edksetup.sh" BaseTools >/dev/null; set -u
    "$WS/BaseTools/BinWrappers/PosixLike/build" -a X64 -t GCC -b RELEASE -p MdeModulePkg/MdeModulePkg.dsc -m MdeModulePkg/Bus/Pci/XhciDxe/XhciDxe.inf
    BUILT="$(find "$WS/Build" -type f -name XhciDxe.efi -path '*RELEASE_GCC*' -print | head -n1)"
    [[ -f "$BUILT" ]] || fail "XhciDxe.efi absent"
    cp "$BUILT" "$XHCI"
    GENFW="$(find "$EDK/BaseTools" -type f -name GenFw -perm -111 -print | head -n1)"
    [[ -n "$GENFW" ]] || fail "GenFw absent"
    "$GENFW" -z -o "$WORK/XhciDxe.normalized.efi" "$XHCI"
    [[ "$(sha256sum "$WORK/XhciDxe.normalized.efi" | awk '{print $1}')" == "$XHCI_NORMALIZED_SHA" ]] || fail "XhciDxe non équivalent à l'oracle"
    XHCI_PROVENANCE="rebuilt-normalized-equivalent"
    popd >/dev/null; rm -f "$WS"
fi
XHCI_SHA="$(sha256sum "$XHCI" | awk '{print $1}')"
[[ -n "$XHCI_PROVENANCE" ]] || fail "provenance XhciDxe non prouvée"
if [[ "$XHCI_PROVENANCE" != "rebuilt-normalized-equivalent" ]]; then
    [[ "$XHCI_SHA" == "$XHCI_VALIDATED_SHA" ]] || fail "XhciDxe exact attendu"
fi
echo "XHCI_SHA=$XHCI_SHA"
echo "XHCI_PROVENANCE=$XHCI_PROVENANCE"

if [[ "$YES" != 1 ]]; then
    echo
    echo "ATTENTION: cette opération EFFACE entièrement $TARGET"
    read -r -p "Tape exactement ERASE-$TARGET pour continuer: " ANSWER
    [[ "$ANSWER" == "ERASE-$TARGET" ]] || fail "confirmation refusée"
fi

printf '\n===== 5. SAUVEGARDE METADONNEES =====\n'
BACKUP="${PWD}/ds713-v93-prewrite-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP"
sfdisk -d "$TARGET" > "$BACKUP/sfdisk.txt" 2>/dev/null || true
lsblk -f "$TARGET" > "$BACKUP/lsblk.txt" || true
while read -r MP; do [[ -z "$MP" ]] || umount "$MP"; done < <(lsblk -nrpo MOUNTPOINT "$TARGET" | awk 'NF')
echo "BACKUP_METADATA=$BACKUP"

printf '\n===== 6. GPT + FAT32 =====\n'
wipefs --all --force "$TARGET"
printf '%s\n' 'label: gpt' ',,C12A7328-F81F-11D2-BA4B-00A0C93EC93B,*' | sfdisk "$TARGET"
udevadm settle
PART="${TARGET}1"
[[ -b "$PART" ]] || fail "partition non créée: $PART"
"$MKFS_FAT" -F 32 -n "$LABEL" "$PART"

printf '\n===== 7. INSTALLATION =====\n'
mount -o rw,nosuid,nodev,noexec "$PART" "$MNT"
mkdir -p "$MNT/EFI/BOOT" "$MNT/EFI/DS713"
install -m 0644 "$V93" "$MNT/EFI/BOOT/BOOTX64.EFI"
install -m 0644 "$XHCI" "$MNT/EFI/DS713/XhciDxe.efi"
{
  printf '@echo -off\r\n'
  for n in 0 1 2 3 4 5 6 7 8 9; do printf 'fs%s:\\EFI\\BOOT\\BOOTX64.EFI\r\n' "$n"; done
  printf 'exit\r\n'
} > "$MNT/startup.nsh"
sync

printf '\n===== 8. VERIFICATION =====\n'
[[ "$(find "$MNT" -type f | wc -l)" -eq 3 ]] || fail "la clé doit contenir exactement 3 fichiers"
cmp -s "$V93" "$MNT/EFI/BOOT/BOOTX64.EFI" || fail "BOOTX64 copie invalide"
cmp -s "$XHCI" "$MNT/EFI/DS713/XhciDxe.efi" || fail "XhciDxe copie invalide"
USB_V93_SHA="$(sha256sum "$MNT/EFI/BOOT/BOOTX64.EFI" | awk '{print $1}')"
USB_XHCI_SHA="$(sha256sum "$MNT/EFI/DS713/XhciDxe.efi" | awk '{print $1}')"
find "$MNT" -type f -printf '%P\t%s bytes\n' | sort
umount "$MNT"
"$FSCK_FAT" -n "$PART"

printf '\n============================================================\n'
echo ' DS713+ V9.3 CANDIDATE BRIDGE READY'
echo '============================================================'
echo "TARGET=$TARGET"
echo "PART=$PART"
echo "LABEL=$LABEL"
echo "BOOTX64_SHA=$USB_V93_SHA"
echo "XHCIDXE_SHA=$USB_XHCI_SHA"
echo 'HARDWARE_VALIDATION=REQUIRED_BEFORE_PROMOTION'
echo 'BOOT_POLICY=FRONT:rear-direct ; DOM:front-then-rear ; UNKNOWN:rear-direct'
echo 'STANDARD_CHAINLOAD=\\EFI\\BOOT\\BOOTX64.EFI'
echo 'NVRAM_BOOT_POLICY_WRITES=ZERO'
lsblk -o NAME,PATH,TRAN,SIZE,FSTYPE,LABEL,MODEL,SERIAL "$TARGET"
