#!/usr/bin/env bash
set -Eeuo pipefail
export LC_ALL=C

TARGET="${TARGET:-${SDX:-${1:-}}}"
[[ -z "$TARGET" || "$TARGET" == /dev/* ]] || TARGET="/dev/$TARGET"
LABEL="${LABEL:-DS713V91}"
YES="${YES:-0}"

V91_VALIDATED_SHA="2c5a336e52a3d89bcf8029c85818ecbeb2a9477c6dd8367227c7027b5cc833ac"
V91_SOURCE_SHA="5d033908f18eb2849bf41f1160894cff372bb96a556e7001ad4892632b860fed"
XHCI_VALIDATED_SHA="20c3dbda0e0720fe171a7c0b06c995c4fe319f7338acfb75e9b5ee271a3092b3"
XHCI_NORMALIZED_SHA="ecb9726a4ecd6ce1fe39874b6b8a0e9374bfdcaa08da77fbb3de827bae258e30"
EDK_TAG="edk2-stable202605"
EDK_COMMIT="b03a21a63e3bd001f52c527e5a57feddb53a690b"

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
V91_TEST=""
if [[ -f "$HERE/../bridge/DS713Bridge-v9.1.c" ]]; then
    BRIDGE_SOURCE="$HERE/../bridge/DS713Bridge-v9.1.c"
    [[ -f "$HERE/../bridge/test_v91_static.py" ]] && V91_TEST="$HERE/../bridge/test_v91_static.py"
elif [[ -f "$HERE/DS713Bridge-v9.1.c" ]]; then
    BRIDGE_SOURCE="$HERE/DS713Bridge-v9.1.c"
    [[ -f "$HERE/test_v91_static.py" ]] && V91_TEST="$HERE/test_v91_static.py"
else
    echo "ERREUR: DS713Bridge-v9.1.c introuvable à côté du script ou dans ../bridge" >&2
    exit 2
fi

START_DIR="$(pwd -P)"
WORK="$(mktemp -d /tmp/ds713-bridge-create.XXXXXX)"
MNT="$(mktemp -d /tmp/ds713-bridge-mnt.XXXXXX)"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/ds713plus-bridge"
mkdir -p "$CACHE"

cleanup() {
    mountpoint -q "$MNT" 2>/dev/null && umount "$MNT" || true
    rm -rf "$WORK" "$MNT"
}
trap cleanup EXIT

fail() {
    echo >&2
    echo "ERREUR: $*" >&2
    exit 1
}

need() {
    command -v "$1" >/dev/null 2>&1 || fail "commande manquante: $1"
}

printf '%s\n' '============================================================'
printf '%s\n' ' DS713+ — USB3 REAR BRIDGE V9.1'
printf '%s\n' ' Stable, bootloader-agnostic, no BootOrder/BootNext dependency'
printf '%s\n' '============================================================'

[[ $EUID -eq 0 ]] || fail "lancer en root: sudo SDX=sdb $0 (ou TARGET=/dev/sdb)"
[[ -n "$TARGET" ]] || fail "cible absente. Exemple: sudo SDX=sdb $0"

TARGET="$(readlink -f "$TARGET")"
[[ "$TARGET" =~ ^/dev/sd[a-z]+$ ]] || fail "TARGET attendu sous forme /dev/sdX (ex: /dev/sdb): $TARGET"
[[ -b "$TARGET" ]] || fail "cible inexistante: $TARGET"
[[ "$(lsblk -dn -o TYPE "$TARGET" | xargs)" == "disk" ]] || fail "TARGET doit être un disque entier"

for cmd in file python3 lsblk findmnt mount umount wipefs sfdisk sha256sum udevadm install awk sed grep find; do
    need "$cmd"
done

MKFS_FAT="$(command -v mkfs.fat || command -v mkfs.vfat || true)"
FSCK_FAT="$(command -v fsck.fat || command -v fsck.vfat || true)"
[[ -n "$MKFS_FAT" ]] || fail "mkfs.fat/mkfs.vfat manquant (paquet dosfstools)"
[[ -n "$FSCK_FAT" ]] || fail "fsck.fat/fsck.vfat manquant (paquet dosfstools)"

printf '\n===== 1. SECURITE CIBLE =====\n'
ROOTSRC="$(findmnt -n -o SOURCE /)"
ROOTDEV="${ROOTSRC%%\[*}"
ROOTDISK="$({ lsblk -s -nrpo PATH,TYPE "$ROOTDEV" 2>/dev/null || true; } | awk '$2=="disk" {print $1; exit}')"
[[ -n "$ROOTDISK" ]] || fail "impossible d'identifier le disque système"
[[ "$(readlink -f "$TARGET")" != "$(readlink -f "$ROOTDISK")" ]] || fail "REFUS: TARGET = disque système"

TRAN="$(lsblk -dn -o TRAN "$TARGET" | xargs)"
[[ "$TRAN" == "usb" ]] || fail "REFUS: cible non USB (TRAN=$TRAN)"

lsblk -o NAME,PATH,TRAN,SIZE,FSTYPE,LABEL,MODEL,SERIAL,MOUNTPOINTS "$TARGET"
echo "TARGET=$TARGET"
echo "ROOTDISK=$ROOTDISK"
echo "USB_TARGET_SAFETY=PASS"

if [[ "$YES" != "1" ]]; then
    echo
    echo "Cette opération EFFACE entièrement $TARGET."
    read -r -p "Tape exactement ERASE-$TARGET pour continuer: " ANSWER
    [[ "$ANSWER" == "ERASE-$TARGET" ]] || fail "confirmation refusée"
fi

printf '\n===== 2. SOURCE V9.1 =====\n'
SRC_SHA="$(sha256sum "$BRIDGE_SOURCE" | awk '{print $1}')"
echo "V91_SOURCE=$BRIDGE_SOURCE"
echo "V91_SOURCE_SHA=$SRC_SHA"
[[ "$SRC_SHA" == "$V91_SOURCE_SHA" ]] || fail "source V9.1 différente de la source validée"

if [[ -n "$V91_TEST" ]]; then
    python3 "$V91_TEST"
    echo "V91_SOURCE_STATIC_TEST=PASS"
else
    echo "V91_SOURCE_STATIC_TEST=SKIPPED_SOURCE_HASH_ONLY"
fi

STABLE="$WORK/STABLE-V91.EFI"
XHCI="$WORK/XhciDxe.efi"
STABLE_EXACT=0
XHCI_EXACT=0

printf '\n===== 3. RECUPERATION DES BINAIRES VALIDES SI PRESENTS =====\n'

# Prefer exact physically validated files already present on the target.
while read -r PART; do
    [[ -b "$PART" ]] || continue
    FSTYPE="$(lsblk -n -o FSTYPE "$PART" | xargs)"
    [[ "$FSTYPE" == "vfat" ]] || continue

    mount -o ro "$PART" "$MNT" || continue

    for C in \
        "$MNT/EFI/DS713/Harness/STABLE-V91.EFI" \
        "$MNT/EFI/BOOT/BOOTX64.EFI"
    do
        [[ -f "$C" ]] || continue
        SHA="$(sha256sum "$C" | awk '{print $1}')"
        if [[ "$SHA" == "$V91_VALIDATED_SHA" ]]; then
            cp -f "$C" "$STABLE"
            STABLE_EXACT=1
            echo "RECOVERED_EXACT_V91=$C"
            break
        fi
    done

    if [[ -f "$MNT/EFI/DS713/XhciDxe.efi" ]]; then
        SHA="$(sha256sum "$MNT/EFI/DS713/XhciDxe.efi" | awk '{print $1}')"
        if [[ "$SHA" == "$XHCI_VALIDATED_SHA" ]]; then
            cp -f "$MNT/EFI/DS713/XhciDxe.efi" "$XHCI"
            XHCI_EXACT=1
            echo "RECOVERED_EXACT_XHCI=$MNT/EFI/DS713/XhciDxe.efi"
        fi
    fi

    umount "$MNT"

    [[ "$STABLE_EXACT" -eq 1 && "$XHCI_EXACT" -eq 1 ]] && break
done < <(lsblk -lnpo NAME,TYPE "$TARGET" | awk '$2=="part" {print $1}')

printf '\n===== 4. BUILD V9.1 SI NECESSAIRE =====\n'
if [[ "$STABLE_EXACT" -ne 1 ]]; then
    for cmd in gcc ld objcopy objdump; do need "$cmd"; done
    [[ -f /usr/include/efi/efi.h ]] || fail "gnu-efi requis pour reconstruire V9.1 (Arch: gnu-efi ; Debian/Ubuntu: gnu-efi)"
    CRT0="$(find /usr/lib /usr/lib64 -maxdepth 4 -name crt0-efi-x86_64.o -print -quit 2>/dev/null)"
    LDS="$(find /usr/lib /usr/lib64 -maxdepth 4 -name elf_x86_64_efi.lds -print -quit 2>/dev/null)"
    [[ -n "$CRT0" && -f "$CRT0" ]] || fail "crt0-efi-x86_64.o introuvable"
    [[ -n "$LDS" && -f "$LDS" ]] || fail "elf_x86_64_efi.lds introuvable"
    LIBDIR="$(dirname "$CRT0")"
    [[ -f "$LIBDIR/libefi.a" ]] || LIBDIR=/usr/lib
    [[ -f "$LIBDIR/libefi.a" && -f "$LIBDIR/libgnuefi.a" ]] || fail "libefi/libgnuefi introuvables"

    cp "$BRIDGE_SOURCE" "$WORK/DS713Bridge-v9.1.c"
    LIBGCC="$(gcc -print-libgcc-file-name)"

    gcc \
      -isystem /usr/include/efi \
      -isystem /usr/include/efi/x86_64 \
      -isystem /usr/include/efi/protocol \
      -DCONFIG_x86_64 -DGNU_EFI_USE_MS_ABI \
      -maccumulate-outgoing-args -mno-red-zone -mno-avx \
      -std=c11 -O2 -Wall -Wextra -Wstrict-prototypes -Werror \
      -fshort-wchar -fno-strict-aliasing -ffreestanding \
      -fno-stack-protector -fno-stack-check -fno-merge-all-constants -fpic \
      -c "$WORK/DS713Bridge-v9.1.c" -o "$WORK/DS713Bridge-v9.1.o"

    ld -nostdlib --warn-common --no-undefined --fatal-warnings \
      --build-id=sha1 -z norelro -z nocombreloc \
      -T "$LDS" -shared -Bsymbolic \
      "$CRT0" "$WORK/DS713Bridge-v9.1.o" \
      -L"$LIBDIR" -lefi -lgnuefi "$LIBGCC" \
      -o "$WORK/DS713Bridge-v9.1.so"

    objcopy \
      -j .text -j .sdata -j .data -j .dynamic -j .dynsym -j .rodata \
      -j .rel -j .rela -j '.rel.*' -j '.rela.*' -j .reloc \
      -O pei-x86-64 --subsystem efi-app \
      --section-alignment 0x1000 --file-alignment 0x200 \
      "$WORK/DS713Bridge-v9.1.so" "$STABLE"

    file "$STABLE" | grep -q 'PE32+ executable for EFI (application)' || fail "V9.1 reconstruite invalide"
    objdump -p "$STABLE" | grep -q 'Subsystem.*EFI application' || fail "subsystem V9.1 invalide"
    echo "V91_REBUILT_FROM_VALIDATED_SOURCE=YES"
else
    echo "V91_EXACT_PHYSICALLY_VALIDATED_BINARY=YES"
fi

printf '\n===== 5. XHCIDXE SI NECESSAIRE =====\n'
if [[ "$XHCI_EXACT" -ne 1 ]]; then
    for cmd in git make gcc python3; do need "$cmd"; done
    EDK="${EDK2_DIR:-$CACHE/$EDK_TAG}"
    if [[ ! -d "$EDK/.git" ]]; then
        rm -rf "$EDK"
        git clone --depth 1 --branch "$EDK_TAG" https://github.com/tianocore/edk2.git "$EDK"
        git -C "$EDK" submodule update --init --depth 1
    fi

    HEAD="$(git -C "$EDK" rev-parse HEAD)"
    echo "EDK2_COMMIT=$HEAD"
    [[ "$HEAD" == "$EDK_COMMIT" ]] || fail "commit EDK2 inattendu"
    git -C "$EDK" submodule update --init --depth 1
    make -C "$EDK/BaseTools" -j"$(nproc)"

    WS="/tmp/ds713-edk2-bridge-$$"
    ln -s "$EDK" "$WS"
    export WORKSPACE="$WS"
    export PACKAGES_PATH="$WS"
    export EDK_TOOLS_PATH="$WS/BaseTools"
    export PYTHON_COMMAND=python3
    export SOURCE_DATE_EPOCH=0

    cd "$WS"
    set +u
    # shellcheck disable=SC1090
    source "$WS/edksetup.sh" BaseTools >/dev/null
    RC=$?
    set -u
    [[ "$RC" -eq 0 ]] || fail "edksetup rc=$RC"

    BUILD="$WS/BaseTools/BinWrappers/PosixLike/build"
    "$BUILD" -a X64 -t GCC -b RELEASE \
      -p MdeModulePkg/MdeModulePkg.dsc \
      -m MdeModulePkg/Bus/Pci/XhciDxe/XhciDxe.inf

    BUILT="$(find "$WS/Build" -type f -name XhciDxe.efi -path '*RELEASE_GCC*' -print | head -n1)"
    [[ -f "$BUILT" ]] || fail "XhciDxe.efi reconstruit introuvable"
    cp -f "$BUILT" "$XHCI"

    GENFW=""
    for G in "$EDK/BaseTools/Source/C/bin/GenFw" "$EDK/BaseTools/BinWrappers/PosixLike/GenFw"; do
        [[ -x "$G" ]] && GENFW="$G" && break
    done
    [[ -n "$GENFW" ]] || fail "GenFw introuvable"

    "$GENFW" -z -o "$WORK/XhciDxe.normalized.efi" "$XHCI"
    NORM_SHA="$(sha256sum "$WORK/XhciDxe.normalized.efi" | awk '{print $1}')"
    echo "XHCI_NORMALIZED_SHA=$NORM_SHA"
    [[ "$NORM_SHA" == "$XHCI_NORMALIZED_SHA" ]] || fail "XhciDxe reconstruit différent de l'oracle normalisé"
    cd "$START_DIR"
    rm -f "$WS"
    echo "XHCI_REBUILT_REPRODUCIBLE=YES"
else
    echo "XHCI_EXACT_PHYSICALLY_VALIDATED_BINARY=YES"
fi

file "$STABLE"
file "$XHCI"
STABLE_SHA="$(sha256sum "$STABLE" | awk '{print $1}')"
XHCI_SHA="$(sha256sum "$XHCI" | awk '{print $1}')"
echo "FINAL_STABLE_SHA=$STABLE_SHA"
echo "FINAL_XHCI_SHA=$XHCI_SHA"

printf '\n===== 6. DEMONTAGE / BACKUP TABLE =====\n'
BACKUP="$START_DIR/ds713-bridge-prewrite-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP"
sfdisk -d "$TARGET" > "$BACKUP/sfdisk.txt" 2>/dev/null || true
lsblk -f "$TARGET" > "$BACKUP/lsblk.txt" || true
while read -r MP; do
    [[ -z "$MP" ]] || umount "$MP"
done < <(lsblk -nrpo MOUNTPOINT "$TARGET" | awk 'NF')
echo "BACKUP_METADATA=$BACKUP"

printf '\n===== 7. RECREATION GPT + FAT32 =====\n'
wipefs --all --force "$TARGET"
printf '%s\n' 'label: gpt' ',,C12A7328-F81F-11D2-BA4B-00A0C93EC93B,*' | sfdisk "$TARGET"
udevadm settle
PART="${TARGET}1"
[[ -b "$PART" ]] || fail "partition non recréée: $PART"
"$MKFS_FAT" -F 32 -n "$LABEL" "$PART"

printf '\n===== 8. INSTALLATION BRIDGE =====\n'
mount -o rw,nosuid,nodev,noexec "$PART" "$MNT"
mkdir -p "$MNT/EFI/BOOT" "$MNT/EFI/DS713"
install -m 0644 "$STABLE" "$MNT/EFI/BOOT/BOOTX64.EFI"
install -m 0644 "$XHCI" "$MNT/EFI/DS713/XhciDxe.efi"

{
    printf '@echo -off\r\n'
    for n in 0 1 2 3 4 5 6 7 8 9; do
        printf 'fs%s:\\EFI\\BOOT\\BOOTX64.EFI\r\n' "$n"
    done
    printf 'exit\r\n'
} > "$MNT/startup.nsh"

sync

printf '\n===== 9. VERIFICATION =====\n'
find "$MNT" -type f -printf '%P\t%s bytes\n' | sort
[[ "$(find "$MNT" -type f | wc -l)" -eq 3 ]] || fail "la clé doit contenir exactement 3 fichiers"
cmp -s "$STABLE" "$MNT/EFI/BOOT/BOOTX64.EFI" || fail "BOOTX64 différent après copie"
cmp -s "$XHCI" "$MNT/EFI/DS713/XhciDxe.efi" || fail "XhciDxe différent après copie"

USB_STABLE_SHA="$(sha256sum "$MNT/EFI/BOOT/BOOTX64.EFI" | awk '{print $1}')"
USB_XHCI_SHA="$(sha256sum "$MNT/EFI/DS713/XhciDxe.efi" | awk '{print $1}')"

umount "$MNT"
"$FSCK_FAT" -n "$PART"

printf '\n============================================================\n'
echo ' DS713+ USB3 BRIDGE READY'
echo '============================================================'
echo "TARGET=$TARGET"
echo "PART=$PART"
echo "LABEL=$LABEL"
echo "BOOTX64_SHA=$USB_STABLE_SHA"
echo "XHCIDXE_SHA=$USB_XHCI_SHA"
echo "PHYSICALLY_VALIDATED_V91=$([[ "$USB_STABLE_SHA" == "$V91_VALIDATED_SHA" ]] && echo YES || echo SOURCE_EQUIVALENT_BUILD)"
echo "PHYSICALLY_VALIDATED_XHCI=$([[ "$USB_XHCI_SHA" == "$XHCI_VALIDATED_SHA" ]] && echo YES || echo NORMALIZED_EQUIVALENT_BUILD)"
echo 'BOOT_POLICY=bridge-front:rear-direct ; bridge-DOM:front-then-rear'
echo 'BOOTLOADER_AGNOSTIC=YES'
echo 'STANDARD_CHAINLOAD=\\EFI\\BOOT\\BOOTX64.EFI'
echo 'NVRAM_BOOT_POLICY_WRITES=ZERO'
echo 'REAR_PORT_HARDCODE=ZERO'
echo 'SELF_RECURSION_GUARD=YES'
lsblk -o NAME,PATH,TRAN,SIZE,FSTYPE,LABEL,MODEL,SERIAL "$TARGET"
