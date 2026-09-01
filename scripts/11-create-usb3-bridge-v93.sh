#!/usr/bin/env bash
set -Eeuo pipefail
export LC_ALL=C

# DS713+ Bridge Key Creator — self-contained DS713Bridge v9.3 candidate
# No local repository, bundle or cache payload is required.
#
# It embeds the exact DS713Bridge-v9.3.c source, validates its SHA-256,
# compiles it locally, recovers the physically validated XhciDxe from an
# existing bridge key when possible, or rebuilds it from pinned EDK2.

LABEL="${LABEL:-DS713V93}"
XHCI_EFI="${XHCI_EFI:-}"

V93_SOURCE_SHA="85a7d6961825b1e9775d015727ac28aef2d2301517b9220f9eb874e4e911af6a"
XHCI_VALIDATED_SHA="20c3dbda0e0720fe171a7c0b06c995c4fe319f7338acfb75e9b5ee271a3092b3"
XHCI_NORMALIZED_SHA="ecb9726a4ecd6ce1fe39874b6b8a0e9374bfdcaa08da77fbb3de827bae258e30"
EDK_TAG="edk2-stable202605"
EDK_COMMIT="b03a21a63e3bd001f52c527e5a57feddb53a690b"

fail() {
    printf '\nERREUR: %s\n' "$*" >&2
    exit 1
}

need() {
    command -v "$1" >/dev/null 2>&1
}

USER_NAME="${SUDO_USER:-${USER:-$(id -un)}}"
USER_HOME="$(getent passwd "$USER_NAME" 2>/dev/null | cut -d: -f6 || true)"
[[ -n "$USER_HOME" ]] || USER_HOME="$HOME"
CACHE="${XDG_CACHE_HOME:-$USER_HOME/.cache}/ds713plus-bridge"
STATE="${XDG_STATE_HOME:-$USER_HOME/.local/state}/ds713plus-bridge"
mkdir -p "$CACHE" "$STATE"

WORK="$(mktemp -d /tmp/ds713-v93-key.XXXXXX)"
MNT="$(mktemp -d /tmp/ds713-v93-mnt.XXXXXX)"
WS_LINK=""

cleanup() {
    if mountpoint -q "$MNT" 2>/dev/null; then
        sudo umount "$MNT" 2>/dev/null || true
    fi
    [[ -z "$WS_LINK" ]] || rm -f "$WS_LINK"
    rm -rf "$WORK" "$MNT"
}
trap cleanup EXIT

BRIDGE_SOURCE="$WORK/DS713Bridge-v9.3.c"

extract_embedded_source() {
    cat <<'V93_SOURCE_GZ_B64' | base64 -d | gzip -dc > "$BRIDGE_SOURCE"
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
V93_SOURCE_GZ_B64

    local sha
    sha="$(sha256sum "$BRIDGE_SOURCE" | awk '{print $1}')"
    [[ "$sha" == "$V93_SOURCE_SHA" ]] ||
        fail "source v9.3 embarquée corrompue: $sha"
}

source_static_gate() {
    python3 - "$BRIDGE_SOURCE" <<'PY'
from pathlib import Path
import sys

s = Path(sys.argv[1]).read_text()

required = [
    "DS713Bridge v9.3",
    "BRIDGE_LOCATION_FRONT",
    "BRIDGE_LOCATION_DOM",
    "BRIDGE_LOCATION_UNKNOWN",
    "scan_existing_rear_filesystems",
    "StartImage returned: the child did not permanently take control.",
    "EFI_ABORTED",
    "DS713V93Timing",
    r"\\EFI\\BOOT\\BOOTX64.EFI",
]

missing = [item for item in required if item not in s]
if missing:
    raise SystemExit("V93_STATIC_GATE=FAIL missing=" + repr(missing))

if s.count("BS->ConnectController") != 2:
    raise SystemExit(
        f"V93_STATIC_GATE=FAIL ConnectController_count={s.count('BS->ConnectController')}"
    )

if "BootOrder" in s or "BootNext" in s:
    raise SystemExit("V93_STATIC_GATE=FAIL persistent_boot_policy")

print("V93_STATIC_GATE=PASS")
PY
}

install_dependencies_if_needed() {
    local missing=()
    local cmd

    for cmd in \
        lsblk findmnt readlink awk xargs sha256sum mount umount mountpoint \
        wipefs sfdisk udevadm install find grep sed file objdump gcc ld objcopy \
        python3 sync base64 gzip git make nproc cmp
    do
        need "$cmd" || missing+=("$cmd")
    done

    need mkfs.fat || need mkfs.vfat || missing+=("mkfs.fat")
    need fsck.fat || need fsck.vfat || missing+=("fsck.fat")
    [[ -f /usr/include/efi/efi.h ]] || missing+=("gnu-efi")

    if (( ${#missing[@]} == 0 )); then
        echo "DEPENDENCIES=PASS"
        return
    fi

    echo "Dépendances manquantes: ${missing[*]}"
    echo "Installation automatique des paquets nécessaires..."

    # shellcheck disable=SC1091
    source /etc/os-release 2>/dev/null || true

    if need pacman; then
        sudo pacman -S --needed --noconfirm \
            util-linux systemd dosfstools gnu-efi gcc binutils git make python \
            coreutils findutils grep sed file gzip
    elif need apt-get; then
        sudo apt-get update
        sudo apt-get install -y \
            util-linux udev dosfstools gnu-efi build-essential binutils git \
            make python3 coreutils findutils grep sed file gzip
    else
        fail "gestionnaire de paquets non supporté automatiquement; installer: gnu-efi dosfstools gcc binutils git make python3 util-linux"
    fi

    for cmd in \
        lsblk findmnt readlink awk xargs sha256sum mount umount mountpoint \
        wipefs sfdisk udevadm install find grep sed file objdump gcc ld objcopy \
        python3 sync base64 gzip git make nproc cmp
    do
        need "$cmd" || fail "commande toujours manquante après installation: $cmd"
    done

    [[ -f /usr/include/efi/efi.h ]] || fail "gnu-efi toujours absent"
    echo "DEPENDENCIES=INSTALLED"
}

root_disk() {
    local rootsrc rootdev disk
    rootsrc="$(findmnt -n -o SOURCE /)"
    rootdev="${rootsrc%%\[*}"
    disk="$(
        { lsblk -s -nrpo PATH,TYPE "$rootdev" 2>/dev/null || true; } |
        awk '$2=="disk" {print $1; exit}'
    )"
    [[ -n "$disk" ]] || fail "impossible d'identifier le disque système"
    readlink -f "$disk"
}

list_usb_disks() {
    local root="$1"
    local path size type

    USB_DISKS=()

    while read -r path; do
        [[ -n "$path" ]] || continue
        path="$(readlink -f "$path")"
        [[ "$path" != "$root" ]] || continue
        type="$(lsblk -dn -o TYPE "$path" | xargs)"
        [[ "$type" == "disk" ]] || continue
        size="$(lsblk -bdn -o SIZE "$path" | xargs)"
        [[ "$size" =~ ^[0-9]+$ ]] || continue
        (( size > 0 )) || continue
        USB_DISKS+=("$path")
    done < <(lsblk -dpno PATH,TRAN | awk '$2=="usb" {print $1}')
}

choose_target() {
    local root="$1"
    local choice candidate i

    list_usb_disks "$root"

    echo
    echo "===== DISQUES USB DISPONIBLES ====="
    (( ${#USB_DISKS[@]} > 0 )) || fail "aucun disque USB exploitable détecté"

    i=1
    for candidate in "${USB_DISKS[@]}"; do
        printf '\n[%d] %s\n' "$i" "$candidate"
        lsblk -dn -o SIZE,MODEL,SERIAL "$candidate" | sed 's/^/    /'
        lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINTS "$candidate" | sed 's/^/    /'
        ((i++))
    done
    printf '\n[0] Annuler\n'

    while true; do
        echo
        read -r -p "Numéro OU chemin (/dev/sdX) de la clé à transformer : " choice

        if [[ "$choice" == "0" ]]; then
            exit 0
        fi

        candidate=""
        if [[ "$choice" =~ ^[0-9]+$ ]]; then
            if (( choice >= 1 && choice <= ${#USB_DISKS[@]} )); then
                candidate="${USB_DISKS[$((choice-1))]}"
            fi
        elif [[ "$choice" == /dev/* ]]; then
            candidate="$(readlink -f "$choice" 2>/dev/null || true)"
            for allowed in "${USB_DISKS[@]}"; do
                [[ "$candidate" == "$allowed" ]] && break 2
            done
            candidate=""
        fi

        if [[ -n "$candidate" ]]; then
            TARGET="$candidate"
            return
        fi

        echo "Choix invalide ou disque non USB."
    done

    TARGET="$candidate"
}

build_v93() {
    local crt0 lds libdir libgcc

    V93="$WORK/DS713Bridge-v9.3.efi"

    crt0="$(find /usr/lib /usr/lib64 -maxdepth 4 -name crt0-efi-x86_64.o -print -quit 2>/dev/null)"
    lds="$(find /usr/lib /usr/lib64 -maxdepth 4 -name elf_x86_64_efi.lds -print -quit 2>/dev/null)"

    [[ -n "$crt0" && -f "$crt0" ]] || fail "crt0-efi-x86_64.o introuvable"
    [[ -n "$lds" && -f "$lds" ]] || fail "elf_x86_64_efi.lds introuvable"

    libdir="$(dirname "$crt0")"
    [[ -f "$libdir/libefi.a" ]] || libdir=/usr/lib
    [[ -f "$libdir/libefi.a" && -f "$libdir/libgnuefi.a" ]] ||
        fail "libefi/libgnuefi introuvables"

    libgcc="$(gcc -print-libgcc-file-name)"

    gcc \
      -isystem /usr/include/efi \
      -isystem /usr/include/efi/x86_64 \
      -isystem /usr/include/efi/protocol \
      -DCONFIG_x86_64 -DGNU_EFI_USE_MS_ABI \
      -maccumulate-outgoing-args -mno-red-zone -mno-avx \
      -std=c11 -O2 -Wall -Wextra -Wstrict-prototypes -Werror \
      -fshort-wchar -fno-strict-aliasing -ffreestanding \
      -fno-stack-protector -fno-stack-check -fno-merge-all-constants -fpic \
      -c "$BRIDGE_SOURCE" -o "$WORK/v93.o"

    ld -nostdlib --warn-common --no-undefined --fatal-warnings \
      --build-id=sha1 -z norelro -z nocombreloc \
      -T "$lds" -shared -Bsymbolic \
      "$crt0" "$WORK/v93.o" -L"$libdir" -lefi -lgnuefi "$libgcc" \
      -o "$WORK/v93.so"

    objcopy \
      -j .text -j .sdata -j .data -j .dynamic -j .dynsym -j .rodata \
      -j .rel -j .rela -j '.rel.*' -j '.rela.*' -j .reloc \
      -O pei-x86-64 --subsystem efi-app \
      --section-alignment 0x1000 --file-alignment 0x200 \
      "$WORK/v93.so" "$V93"

    file "$V93" | grep -q 'PE32+ executable for EFI (application)' ||
        fail "PE v9.3 invalide"
    objdump -p "$V93" | grep -q 'Subsystem.*EFI application' ||
        fail "subsystem EFI invalide"

    V93_SHA="$(sha256sum "$V93" | awk '{print $1}')"
    echo "V93_EFI_SHA=$V93_SHA"
}

recover_xhci_from_target() {
    local part existing_mp sha
    XHCI="$WORK/XhciDxe.efi"
    XHCI_PROVENANCE=""

    while read -r part; do
        [[ -b "$part" ]] || continue
        [[ "$(lsblk -n -o FSTYPE "$part" | xargs)" == "vfat" ]] || continue

        existing_mp="$(findmnt -n -o TARGET --source "$part" 2>/dev/null || true)"

        if [[ -n "$existing_mp" ]]; then
            if [[ -f "$existing_mp/EFI/DS713/XhciDxe.efi" ]]; then
                sha="$(sha256sum "$existing_mp/EFI/DS713/XhciDxe.efi" | awk '{print $1}')"
                if [[ "$sha" == "$XHCI_VALIDATED_SHA" ]]; then
                    cp "$existing_mp/EFI/DS713/XhciDxe.efi" "$XHCI"
                    XHCI_PROVENANCE="exact-recovered-existing-key"
                    return 0
                fi
            fi
        else
            sudo mount -o ro,nosuid,nodev,noexec "$part" "$MNT" || continue
            if [[ -f "$MNT/EFI/DS713/XhciDxe.efi" ]]; then
                sha="$(sha256sum "$MNT/EFI/DS713/XhciDxe.efi" | awk '{print $1}')"
                if [[ "$sha" == "$XHCI_VALIDATED_SHA" ]]; then
                    cp "$MNT/EFI/DS713/XhciDxe.efi" "$XHCI"
                    XHCI_PROVENANCE="exact-recovered-existing-key"
                fi
            fi
            sudo umount "$MNT"
            [[ -f "$XHCI" ]] && return 0
        fi
    done < <(lsblk -lnpo NAME,TYPE "$TARGET" | awk '$2=="part" {print $1}')

    return 1
}

build_xhci() {
    local edk built genfw normalized_sha

    XHCI="$WORK/XhciDxe.efi"
    edk="${EDK2_DIR:-$CACHE/$EDK_TAG}"

    if [[ ! -d "$edk/.git" ]]; then
        echo "Téléchargement EDK2 épinglé..."
        rm -rf "$edk"
        git clone --depth 1 --branch "$EDK_TAG" https://github.com/tianocore/edk2.git "$edk"
        git -C "$edk" submodule update --init --depth 1
    fi

    [[ "$(git -C "$edk" rev-parse HEAD)" == "$EDK_COMMIT" ]] ||
        fail "commit EDK2 inattendu"
    git -C "$edk" submodule update --init --depth 1

    make -C "$edk/BaseTools" -j"$(nproc)"

    WS_LINK="/tmp/ds713-edk2-v93-$$"
    rm -f "$WS_LINK"
    ln -s "$edk" "$WS_LINK"

    export WORKSPACE="$WS_LINK"
    export PACKAGES_PATH="$WS_LINK"
    export EDK_TOOLS_PATH="$WS_LINK/BaseTools"
    export PYTHON_COMMAND=python3
    export SOURCE_DATE_EPOCH=0

    pushd "$WS_LINK" >/dev/null
    set +u
    # shellcheck disable=SC1091
    source "$WS_LINK/edksetup.sh" BaseTools >/dev/null
    local rc=$?
    set -u
    (( rc == 0 )) || fail "edksetup rc=$rc"

    "$WS_LINK/BaseTools/BinWrappers/PosixLike/build" \
      -a X64 -t GCC -b RELEASE \
      -p MdeModulePkg/MdeModulePkg.dsc \
      -m MdeModulePkg/Bus/Pci/XhciDxe/XhciDxe.inf

    built="$(
        find "$WS_LINK/Build" -type f -name XhciDxe.efi \
            -path '*RELEASE_GCC*' -print | head -n1
    )"
    [[ -f "$built" ]] || fail "XhciDxe.efi reconstruit introuvable"
    cp "$built" "$XHCI"

    genfw="$(
        find "$edk/BaseTools" -type f -name GenFw -perm -111 -print |
        head -n1
    )"
    [[ -n "$genfw" ]] || fail "GenFw introuvable"

    "$genfw" -z -o "$WORK/XhciDxe.normalized.efi" "$XHCI"
    normalized_sha="$(sha256sum "$WORK/XhciDxe.normalized.efi" | awk '{print $1}')"
    [[ "$normalized_sha" == "$XHCI_NORMALIZED_SHA" ]] ||
        fail "XhciDxe reconstruit différent de l'oracle normalisé"

    XHCI_PROVENANCE="rebuilt-normalized-equivalent"
    popd >/dev/null

    rm -f "$WS_LINK"
    WS_LINK=""
}

prepare_xhci() {
    local sha

    XHCI="$WORK/XhciDxe.efi"
    XHCI_PROVENANCE=""

    if [[ -n "$XHCI_EFI" ]]; then
        [[ -f "$XHCI_EFI" ]] || fail "XHCI_EFI introuvable: $XHCI_EFI"
        cp "$XHCI_EFI" "$XHCI"
        sha="$(sha256sum "$XHCI" | awk '{print $1}')"
        [[ "$sha" == "$XHCI_VALIDATED_SHA" ]] ||
            fail "XHCI_EFI explicite n'est pas le binaire exact validé"
        XHCI_PROVENANCE="exact-explicit"
    elif recover_xhci_from_target; then
        :
    else
        build_xhci
    fi

    sha="$(sha256sum "$XHCI" | awk '{print $1}')"

    if [[ "$XHCI_PROVENANCE" != "rebuilt-normalized-equivalent" ]]; then
        [[ "$sha" == "$XHCI_VALIDATED_SHA" ]] ||
            fail "XhciDxe exact attendu"
    fi

    echo "XHCI_SHA=$sha"
    echo "XHCI_PROVENANCE=$XHCI_PROVENANCE"
}

unmount_target() {
    local mp
    while read -r mp; do
        [[ -n "$mp" ]] || continue
        sudo umount "$mp"
    done < <(lsblk -nrpo MOUNTPOINT "$TARGET" | awk 'NF')
}

first_partition() {
    local part i
    for i in {1..30}; do
        part="$(
            lsblk -lnpo NAME,TYPE "$TARGET" 2>/dev/null |
            awk '$2=="part" {print $1; exit}'
        )"
        if [[ -n "$part" && -b "$part" ]]; then
            printf '%s\n' "$part"
            return 0
        fi
        sleep 0.2
        sudo udevadm settle || true
    done
    return 1
}

write_key() {
    local backup part startup usb_v93_sha usb_xhci_sha

    backup="$STATE/prewrite-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup"

    sfdisk -d "$TARGET" > "$backup/sfdisk.txt" 2>/dev/null || true
    lsblk -f "$TARGET" > "$backup/lsblk.txt" || true
    echo "BACKUP_METADATA=$backup"

    unmount_target

    echo
    echo "===== EFFACEMENT + GPT + FAT32 ====="
    sudo wipefs --all --force "$TARGET"
    printf '%s\n' \
      'label: gpt' \
      ',,C12A7328-F81F-11D2-BA4B-00A0C93EC93B,*' |
      sudo sfdisk "$TARGET"

    sudo udevadm settle
    part="$(first_partition)" || fail "partition ESP non détectée après création"

    MKFS_FAT="$(command -v mkfs.fat || command -v mkfs.vfat)"
    FSCK_FAT="$(command -v fsck.fat || command -v fsck.vfat)"

    sudo "$MKFS_FAT" -F 32 -n "$LABEL" "$part"

    echo
    echo "===== INSTALLATION ====="
    sudo mount -o rw,nosuid,nodev,noexec "$part" "$MNT"
    sudo mkdir -p "$MNT/EFI/BOOT" "$MNT/EFI/DS713"
    sudo install -m 0644 "$V93" "$MNT/EFI/BOOT/BOOTX64.EFI"
    sudo install -m 0644 "$XHCI" "$MNT/EFI/DS713/XhciDxe.efi"

    startup="$WORK/startup.nsh"
    {
        printf '@echo -off\r\n'
        for n in 0 1 2 3 4 5 6 7 8 9; do
            printf 'fs%s:\\EFI\\BOOT\\BOOTX64.EFI\r\n' "$n"
        done
        printf 'exit\r\n'
    } > "$startup"
    sudo install -m 0644 "$startup" "$MNT/startup.nsh"

    sync

    echo
    echo "===== VERIFICATION ====="
    [[ "$(sudo find "$MNT" -type f | wc -l)" -eq 3 ]] ||
        fail "la clé doit contenir exactement 3 fichiers"

    sudo cmp -s "$V93" "$MNT/EFI/BOOT/BOOTX64.EFI" ||
        fail "BOOTX64 différent après copie"
    sudo cmp -s "$XHCI" "$MNT/EFI/DS713/XhciDxe.efi" ||
        fail "XhciDxe différent après copie"

    usb_v93_sha="$(sudo sha256sum "$MNT/EFI/BOOT/BOOTX64.EFI" | awk '{print $1}')"
    usb_xhci_sha="$(sudo sha256sum "$MNT/EFI/DS713/XhciDxe.efi" | awk '{print $1}')"

    sudo find "$MNT" -type f -printf '%P\t%s bytes\n' | sort
    sudo umount "$MNT"
    sudo "$FSCK_FAT" -n "$part"

    echo
    echo "============================================================"
    echo " DS713+ V9.3 BRIDGE KEY READY"
    echo "============================================================"
    echo "TARGET=$TARGET"
    echo "PART=$part"
    echo "LABEL=$LABEL"
    echo "BOOTX64_SHA=$usb_v93_sha"
    echo "XHCIDXE_SHA=$usb_xhci_sha"
    echo "XHCI_PROVENANCE=$XHCI_PROVENANCE"
    echo "BOOT_POLICY=FRONT:rear-direct ; DOM:front-then-rear ; UNKNOWN:rear-direct"
    echo "STANDARD_CHAINLOAD=\\EFI\\BOOT\\BOOTX64.EFI"
    echo "NVRAM_BOOT_POLICY_WRITES=ZERO"
    echo "DOM_DESIGN_SUPPORT=YES"
    echo "DOM_PHYSICAL_VALIDATION=PENDING"
    lsblk -o NAME,PATH,TRAN,SIZE,FSTYPE,LABEL,MODEL,SERIAL "$TARGET"
}

echo "============================================================"
echo " DS713+ — AUTONOMOUS BRIDGE KEY CREATOR"
echo " DS713Bridge v9.3 candidate"
echo "============================================================"

extract_embedded_source

if [[ "${1:-}" == "--self-test" ]]; then
    need python3 || fail "python3 requis pour self-test"
    need sha256sum || fail "sha256sum requis pour self-test"
    source_static_gate
    echo "EMBEDDED_SOURCE_SHA=$V93_SOURCE_SHA"
    echo "SELF_TEST=PASS"
    exit 0
fi

sudo -v
install_dependencies_if_needed

extract_embedded_source
source_static_gate
echo "EMBEDDED_SOURCE_SHA=$V93_SOURCE_SHA"

ROOTDISK="$(root_disk)"
echo "SYSTEM_DISK=$ROOTDISK"

choose_target "$ROOTDISK"

echo
echo "============================================================"
echo " CIBLE CHOISIE : $TARGET"
echo "============================================================"
lsblk -o NAME,PATH,TRAN,SIZE,FSTYPE,LABEL,MODEL,SERIAL,MOUNTPOINTS "$TARGET"

echo
echo "TOUT LE CONTENU DE $TARGET SERA EFFACÉ."
read -r -p "Tape exactement ERASE-$TARGET pour continuer : " ANSWER
[[ "$ANSWER" == "ERASE-$TARGET" ]] || fail "confirmation refusée"

echo
echo "===== BUILD DS713BRIDGE V9.3 ====="
build_v93

echo
echo "===== XHCIDXE ====="
prepare_xhci

write_key
