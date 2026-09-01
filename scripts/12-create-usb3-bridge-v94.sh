#!/usr/bin/env bash
set -Eeuo pipefail
export LC_ALL=C

# DS713Bridge v9.4 FULL-STACK R2 — autonomous rear-USB bridge creator
LABEL="${LABEL:-DS713V94}"
TARGET="${TARGET:-}"
YES="${YES:-0}"
PROFILE="202605"
SELF_TEST=0
EDK_202605_TAG="edk2-stable202605"
EDK_202605_COMMIT="b03a21a63e3bd001f52c527e5a57feddb53a690b"
EDK_202608_TAG="edk2-stable202608"
EDK_202608_COMMIT="2970e5699ba6267f3384ffab20f96647578aebc8"
XHCI_VALIDATED_SHA="20c3dbda0e0720fe171a7c0b06c995c4fe319f7338acfb75e9b5ee271a3092b3"
XHCI_202605_NORMALIZED_SHA="ecb9726a4ecd6ce1fe39874b6b8a0e9374bfdcaa08da77fbb3de827bae258e30"
V94_SOURCE_SHA="75e00a082b11dbb9684eb240f77dbdbe3cfde952b90f7e4f8274020432a0ba39"

for arg in "$@"; do
  case "$arg" in
    --latest) PROFILE="202608" ;;
    --self-test) SELF_TEST=1 ;;
    /dev/*) TARGET="$arg" ;;
    --help|-h)
      cat <<'EOF'
Usage: ./Bridge-Key-Creator-v94-FULLSTACK.sh [--latest] [/dev/sdX]
Default: pinned EDK2 stable202605 full modern USB/storage stack.
--latest: pinned stable202608 experimental stack.
--self-test: no disk access or writes.
EOF
      exit 0 ;;
    *) printf 'ERREUR: argument inconnu: %s\n' "$arg" >&2; exit 2 ;;
  esac
done

fail(){ printf '\nERREUR: %s\n' "$*" >&2; exit 1; }
need(){ command -v "$1" >/dev/null 2>&1; }
USER_NAME="${SUDO_USER:-${USER:-$(id -un)}}"
USER_HOME="$(getent passwd "$USER_NAME" 2>/dev/null | cut -d: -f6 || true)"
[[ -n "$USER_HOME" ]] || USER_HOME="$HOME"
CACHE="${XDG_CACHE_HOME:-$USER_HOME/.cache}/ds713plus-bridge-v94"
STATE="${XDG_STATE_HOME:-$USER_HOME/.local/state}/ds713plus-bridge-v94"
mkdir -p "$CACHE" "$STATE"
WORK="$(mktemp -d /tmp/ds713-v94-fullstack.XXXXXX)"
MNT="$(mktemp -d /tmp/ds713-v94-mnt.XXXXXX)"
WS_LINK=""
cleanup(){
  if mountpoint -q "$MNT" 2>/dev/null; then sudo umount "$MNT" 2>/dev/null || true; fi
  [[ -z "$WS_LINK" ]] || rm -f "$WS_LINK" 2>/dev/null || true
  rm -rf "$WORK" "$MNT"
}
trap cleanup EXIT
V94_SOURCE="$WORK/DS713Bridge-v9.4-fullstack.c"
extract_source(){
  cat <<'V94_SOURCE_GZ_B64' | base64 -d | gzip -dc > "$V94_SOURCE"
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
l2rqij8oKDV2U/PKsGZTYuz+A6tqvIx+NAAA
V94_SOURCE_GZ_B64
}
source_gate(){
  local got
  got="$(sha256sum "$V94_SOURCE" | awk '{print $1}')"
  [[ "$got" == "$V94_SOURCE_SHA" ]] || fail "source v9.4 embarquée corrompue: $got"
  python3 - "$V94_SOURCE" <<'PYTEST'
from pathlib import Path
import sys,re
s=Path(sys.argv[1]).read_text()
req=('DS713Bridge v9.4 FULL-STACK','0x1B6F','0x7023','EFI_DRIVER_BINDING_PROTOCOL','Binding->Supported','Binding->Start','UsbBusDxe.efi','UsbMassStorageDxe.efi','DiskIoDxe.efi','PartitionDxe.efi','EnglishDxe.efi','Fat.efi',r'\\EFI\\BOOT\\BOOTX64.EFI','LoadImage (TRUE','SetWatchdogTimer (300','TryRearFilesystems')
for t in req: assert t in s,t
for t in ('ConnectController','BootOrder','BootNext','shimx64','grubx64','bootmgfw'): assert t not in s,t
m=re.search(r'StartOsLoader\s*\(.*?\n\}',s,re.S); assert m
suffix=m.group(0).split('gBS->StartImage',1)[1]; assert 'UnloadImage' not in suffix
print('V94_EMBEDDED_SOURCE_GATE=PASS')
PYTEST
}
extract_source
if (( SELF_TEST )); then
  for c in bash base64 gzip sha256sum python3; do need "$c" || fail "commande manquante: $c"; done
  source_gate
  echo "V94_SOURCE_SHA=$V94_SOURCE_SHA"
  echo "PROFILE_DEFAULT=202605"
  echo "FULL_STACK=XhciDxe,UsbBusDxe,UsbMassStorageDxe,DiskIoDxe,PartitionDxe,EnglishDxe,Fat"
  echo 'STANDARD_CHAINLOAD=\EFI\BOOT\BOOTX64.EFI'
  echo "NVRAM_WRITES=ZERO"
  echo "SELF_TEST=PASS"
  exit 0
fi
install_dependencies_if_needed(){
  local missing=() c
  for c in lsblk findmnt readlink awk sed grep sort xargs sha256sum mount umount mountpoint wipefs sfdisk udevadm install find file python3 sync base64 gzip git make nproc cmp; do need "$c" || missing+=("$c"); done
  if ((${#missing[@]}==0)) && (need mkfs.fat || need mkfs.vfat) && (need fsck.fat || need fsck.vfat); then return 0; fi
  echo "Installation des dépendances requises..."
  if need pacman; then sudo pacman -S --needed --noconfirm base-devel git python util-linux dosfstools gcc make binutils
  elif need apt-get; then sudo apt-get update; sudo apt-get install -y build-essential git python3 util-linux dosfstools gcc make binutils uuid-dev
  else fail "gestionnaire de paquets non supporté automatiquement"; fi
}
sudo -v
install_dependencies_if_needed
source_gate
root_disk(){
  local src dev disk
  src="$(findmnt -n -o SOURCE /)"; dev="${src%%\[*}"
  disk="$(lsblk -s -nrpo PATH,TYPE "$dev" 2>/dev/null | awk '$2=="disk"{print $1;exit}')"
  [[ -n "$disk" ]] || fail "impossible d'identifier le disque système"
  readlink -f "$disk"
}
choose_target(){
  local root="$1" disk size type tran i choice
  if [[ -n "$TARGET" ]]; then TARGET="$(readlink -f "$TARGET")"
  else
    mapfile -t USB_DISKS < <(lsblk -dpno PATH,TRAN,TYPE | awk '$2=="usb" && $3=="disk"{print $1}')
    FILTERED=()
    for disk in "${USB_DISKS[@]}"; do
      disk="$(readlink -f "$disk")"; [[ "$disk" == "$root" ]] && continue
      size="$(lsblk -bdn -o SIZE "$disk" | xargs)"; [[ "$size" =~ ^[0-9]+$ ]] || continue; (( size > 0 )) || continue
      FILTERED+=("$disk")
    done
    ((${#FILTERED[@]})) || fail "aucun disque USB entier disponible"
    echo; echo "===== DISQUES USB DISPONIBLES ====="; i=1
    for disk in "${FILTERED[@]}"; do printf '\n[%d] %s\n' "$i" "$disk"; lsblk -dn -o SIZE,MODEL,SERIAL "$disk" | sed 's/^/    /'; ((i++)); done
    echo; read -r -p "Numéro OU chemin (/dev/sdX) : " choice
    if [[ "$choice" =~ ^[0-9]+$ ]]; then (( choice>=1 && choice<=${#FILTERED[@]} )) || fail "choix invalide"; TARGET="${FILTERED[$((choice-1))]}"
    else TARGET="$(readlink -f "$choice")"; fi
  fi
  [[ -b "$TARGET" ]] || fail "cible inexistante: $TARGET"
  type="$(lsblk -dn -o TYPE "$TARGET" | xargs)"; [[ "$type" == disk ]] || fail "cible non-disque entier"
  tran="$(lsblk -dn -o TRAN "$TARGET" | xargs)"; [[ "$tran" == usb ]] || fail "cible non USB: $tran"
  [[ "$TARGET" != "$root" ]] || fail "REFUS: cible = disque système"
  size="$(lsblk -bdn -o SIZE "$TARGET" | xargs)"; [[ "$size" =~ ^[0-9]+$ ]] && (( size>0 )) || fail "taille cible invalide"
}
ROOTDISK="$(root_disk)"; choose_target "$ROOTDISK"
echo; echo "============================================================"; echo " CIBLE : $TARGET"; echo " PROFIL: EDK2 $PROFILE FULL-STACK"; echo "============================================================"
lsblk -o NAME,PATH,TRAN,SIZE,FSTYPE,LABEL,MODEL,SERIAL,MOUNTPOINTS "$TARGET"
RECOVERED_XHCI=""
if [[ "$PROFILE" == 202605 ]]; then
  while read -r part; do
    [[ -b "$part" ]] || continue; [[ "$(lsblk -n -o FSTYPE "$part" | xargs)" == vfat ]] || continue
    mp="$(findmnt -n -o TARGET --source "$part" 2>/dev/null || true)"; own=0
    if [[ -z "$mp" ]]; then sudo mount -o ro,nosuid,nodev,noexec "$part" "$MNT" || continue; mp="$MNT"; own=1; fi
    for oldpath in "$mp/EFI/DS713/XhciDxe.efi" "$mp/EFI/DS713V94/drivers/XhciDxe.efi"; do
      if [[ -f "$oldpath" ]]; then h="$(sha256sum "$oldpath" | awk '{print $1}')"; if [[ "$h" == "$XHCI_VALIDATED_SHA" ]]; then RECOVERED_XHCI="$WORK/XhciDxe.exact.efi"; cp "$oldpath" "$RECOVERED_XHCI"; break; fi; fi
    done
    ((own)) && sudo umount "$MNT"; [[ -n "$RECOVERED_XHCI" ]] && break
  done < <(lsblk -lnpo NAME,TYPE "$TARGET" | awk '$2=="part"{print $1}')
fi
if [[ "$PROFILE" == 202605 ]]; then EDK_TAG="$EDK_202605_TAG"; EDK_COMMIT="$EDK_202605_COMMIT"; else EDK_TAG="$EDK_202608_TAG"; EDK_COMMIT="$EDK_202608_COMMIT"; fi
EDK="$CACHE/$EDK_TAG"
if [[ ! -d "$EDK/.git" ]]; then echo "Téléchargement EDK2 $EDK_TAG..."; rm -rf "$EDK"; git clone --depth 1 --branch "$EDK_TAG" https://github.com/tianocore/edk2.git "$EDK"; fi
git -C "$EDK" submodule update --init --depth 1 BaseTools/Source/C/BrotliCompress/brotli
[[ "$(git -C "$EDK" rev-parse HEAD)" == "$EDK_COMMIT" ]] || fail "commit EDK2 inattendu"
if [[ ! -x "$EDK/BaseTools/Source/C/bin/GenFw" ]]; then
  echo "Compilation BaseTools..."
  make -C "$EDK/BaseTools" -j"$(nproc)"
else
  echo "BaseTools déjà compilés: réutilisation du cache."
fi
WS_LINK="/tmp/ds713-v94-edk2-$$"; rm -f "$WS_LINK"; ln -s "$EDK" "$WS_LINK"
export WORKSPACE="$WS_LINK" PACKAGES_PATH="$WS_LINK" EDK_TOOLS_PATH="$WS_LINK/BaseTools" PYTHON_COMMAND=python3 SOURCE_DATE_EPOCH=0
pushd "$WS_LINK" >/dev/null
set +u
# shellcheck disable=SC1091
source "$WS_LINK/edksetup.sh" BaseTools >/dev/null
rc=$?
set -u
((rc==0)) || fail "edksetup rc=$rc"
BUILD="$WS_LINK/BaseTools/BinWrappers/PosixLike/build"
PKG="$WS_LINK/DS713V94Pkg"; MOD="$PKG/DS713BridgeV94"; rm -rf "$PKG"; mkdir -p "$MOD"; cp "$V94_SOURCE" "$MOD/DS713BridgeV94.c"
cat > "$MOD/DS713BridgeV94.inf" <<'INF'
[Defines]
  INF_VERSION = 0x00010005
  BASE_NAME = DS713BridgeV94
  FILE_GUID = 7D1F86A4-124E-4D2D-A794-5C5A94D37130
  MODULE_TYPE = UEFI_APPLICATION
  VERSION_STRING = 9.4
  ENTRY_POINT = UefiMain
[Sources]
  DS713BridgeV94.c
[Packages]
  MdePkg/MdePkg.dec
  MdeModulePkg/MdeModulePkg.dec
[LibraryClasses]
  UefiApplicationEntryPoint
  UefiBootServicesTableLib
  BaseMemoryLib
  MemoryAllocationLib
  DevicePathLib
[Protocols]
  gEfiDevicePathProtocolGuid
  gEfiDriverBindingProtocolGuid
  gEfiLoadedImageProtocolGuid
  gEfiPciIoProtocolGuid
  gEfiSimpleFileSystemProtocolGuid
INF
cat > "$PKG/DS713V94.dsc" <<'DSC'
[Defines]
  PLATFORM_NAME = DS713V94
  PLATFORM_GUID = 1A3ABFCA-5575-4B23-A506-94E34AB18AE5
  PLATFORM_VERSION = 0.1
  DSC_SPECIFICATION = 0x00010005
  OUTPUT_DIRECTORY = Build/DS713V94
  SUPPORTED_ARCHITECTURES = X64
  BUILD_TARGETS = RELEASE
  SKUID_IDENTIFIER = DEFAULT
[LibraryClasses]
  UefiApplicationEntryPoint|MdePkg/Library/UefiApplicationEntryPoint/UefiApplicationEntryPoint.inf
  UefiLib|MdePkg/Library/UefiLib/UefiLib.inf
  UefiBootServicesTableLib|MdePkg/Library/UefiBootServicesTableLib/UefiBootServicesTableLib.inf
  UefiRuntimeServicesTableLib|MdePkg/Library/UefiRuntimeServicesTableLib/UefiRuntimeServicesTableLib.inf
  StackCheckLib|MdePkg/Library/StackCheckLibNull/StackCheckLibNull.inf
  BaseLib|MdePkg/Library/BaseLib/BaseLib.inf
  BaseMemoryLib|MdePkg/Library/BaseMemoryLib/BaseMemoryLib.inf
  MemoryAllocationLib|MdePkg/Library/UefiMemoryAllocationLib/UefiMemoryAllocationLib.inf
  DevicePathLib|MdePkg/Library/UefiDevicePathLib/UefiDevicePathLib.inf
  PrintLib|MdePkg/Library/BasePrintLib/BasePrintLib.inf
  PcdLib|MdePkg/Library/BasePcdLibNull/BasePcdLibNull.inf
  DebugLib|MdePkg/Library/BaseDebugLibNull/BaseDebugLibNull.inf
  RegisterFilterLib|MdePkg/Library/RegisterFilterLibNull/RegisterFilterLibNull.inf
  CpuLib|MdePkg/Library/BaseCpuLib/BaseCpuLib.inf
  IoLib|MdePkg/Library/BaseIoLibIntrinsic/BaseIoLibIntrinsic.inf
[Components]
  DS713V94Pkg/DS713BridgeV94/DS713BridgeV94.inf
DSC

echo
echo "===== PREFLIGHT METADATA EDK2 ====="
grep -q '^  UefiRuntimeServicesTableLib|' "$PKG/DS713V94.dsc" || fail "DSC: UefiRuntimeServicesTableLib absent"
grep -q '^  StackCheckLib|' "$PKG/DS713V94.dsc" || fail "DSC: StackCheckLib absent"
if grep -q '^  UefiLib$' "$MOD/DS713BridgeV94.inf"; then fail "INF: UefiLib inutile encore déclaré"; fi
echo "EDK2_METADATA_GATE=PASS"

echo "===== BUILD DS713Bridge v9.4 FULL-STACK R2 ====="
"$BUILD" -a X64 -t GCC -b RELEASE -p DS713V94Pkg/DS713V94.dsc -m DS713V94Pkg/DS713BridgeV94/DS713BridgeV94.inf
V94_EFI="$(find "$WS_LINK/Build/DS713V94" -type f -name DS713BridgeV94.efi -path '*RELEASE_GCC*' -print | head -n1)"; [[ -f "$V94_EFI" ]] || fail "BOOTX64 v9.4 introuvable"
build_mod(){ echo; echo "--- BUILD $3 ---"; "$BUILD" -a X64 -t GCC -b RELEASE -p "$1" -m "$2"; }
build_mod MdeModulePkg/MdeModulePkg.dsc MdeModulePkg/Bus/Pci/XhciDxe/XhciDxe.inf XhciDxe
build_mod MdeModulePkg/MdeModulePkg.dsc MdeModulePkg/Bus/Usb/UsbBusDxe/UsbBusDxe.inf UsbBusDxe
build_mod MdeModulePkg/MdeModulePkg.dsc MdeModulePkg/Bus/Usb/UsbMassStorageDxe/UsbMassStorageDxe.inf UsbMassStorageDxe
build_mod MdeModulePkg/MdeModulePkg.dsc MdeModulePkg/Universal/Disk/DiskIoDxe/DiskIoDxe.inf DiskIoDxe
build_mod MdeModulePkg/MdeModulePkg.dsc MdeModulePkg/Universal/Disk/PartitionDxe/PartitionDxe.inf PartitionDxe
build_mod MdeModulePkg/MdeModulePkg.dsc MdeModulePkg/Universal/Disk/UnicodeCollation/EnglishDxe/EnglishDxe.inf EnglishDxe
build_mod FatPkg/FatPkg.dsc FatPkg/EnhancedFatDxe/Fat.inf Fat
OUT="$WORK/payload"; mkdir -p "$OUT/drivers"; cp "$V94_EFI" "$OUT/BOOTX64.EFI"
find_efi(){ local n="$1" p; p="$(find "$WS_LINK/Build" -type f -name "$n.efi" -path '*RELEASE_GCC*' -print | head -n1)"; [[ -f "$p" ]] || fail "$n.efi introuvable"; printf '%s\n' "$p"; }
for n in XhciDxe UsbBusDxe UsbMassStorageDxe DiskIoDxe PartitionDxe EnglishDxe Fat; do cp "$(find_efi "$n")" "$OUT/drivers/$n.efi"; done
popd >/dev/null
if [[ "$PROFILE" == 202605 ]]; then
  GENFW=""; for g in "$EDK/BaseTools/Source/C/bin/GenFw" "$EDK/BaseTools/BinWrappers/PosixLike/GenFw"; do [[ -x "$g" ]] && GENFW="$g" && break; done; [[ -n "$GENFW" ]] || fail "GenFw introuvable"
  "$GENFW" -z -o "$WORK/Xhci.normalized.efi" "$OUT/drivers/XhciDxe.efi"
  norm="$(sha256sum "$WORK/Xhci.normalized.efi" | awk '{print $1}')"; echo "XHCI_202605_NORMALIZED_SHA=$norm"; [[ "$norm" == "$XHCI_202605_NORMALIZED_SHA" ]] || fail "XhciDxe 202605 diffère de l'oracle normalisé"
  if [[ -n "$RECOVERED_XHCI" ]]; then cp "$RECOVERED_XHCI" "$OUT/drivers/XhciDxe.efi"; XHCI_PROVENANCE="EXACT_VALIDATED_RECOVERED"; else XHCI_PROVENANCE="REBUILT_NORMALIZED_EQUIVALENT"; fi
else XHCI_PROVENANCE="PINNED_202608_EXPERIMENTAL"; fi
for f in "$OUT/BOOTX64.EFI" "$OUT"/drivers/*.efi; do file "$f" | grep -q 'PE32+ executable for EFI' || fail "PE EFI invalide: $f"; done
BACKUP="$STATE/prewrite-$(date +%Y%m%d-%H%M%S)"; mkdir -p "$BACKUP"; sfdisk -d "$TARGET" > "$BACKUP/sfdisk.txt" 2>/dev/null || true; lsblk -f "$TARGET" > "$BACKUP/lsblk.txt" || true
echo
echo "===== BUILD COMPLET VALIDÉ — PHASE DESTRUCTIVE ====="
ls -lh "$OUT/BOOTX64.EFI" "$OUT"/drivers/*.efi
if [[ "$YES" != 1 ]]; then
  echo
  echo "TOUT LE CONTENU DE $TARGET SERA MAINTENANT EFFACÉ."
  read -r -p "Tape exactement ERASE-$TARGET : " ANSWER
  [[ "$ANSWER" == "ERASE-$TARGET" ]] || fail "confirmation refusée"
fi
while read -r mp; do [[ -n "$mp" ]] && sudo umount "$mp"; done < <(lsblk -nrpo MOUNTPOINT "$TARGET" | awk 'NF')
sudo wipefs --all --force "$TARGET"
printf '%s\n' 'label: gpt' ',,C12A7328-F81F-11D2-BA4B-00A0C93EC93B,*' | sudo sfdisk "$TARGET"
sudo udevadm settle; PART=""; for _ in {1..30}; do PART="$(lsblk -lnpo NAME,TYPE "$TARGET" | awk '$2=="part"{print $1;exit}')"; [[ -b "$PART" ]] && break; sleep .2; sudo udevadm settle || true; done; [[ -b "$PART" ]] || fail "partition ESP non détectée"
MKFS="$(command -v mkfs.fat || command -v mkfs.vfat)"; FSCK="$(command -v fsck.fat || command -v fsck.vfat)"; sudo "$MKFS" -F 32 -n "$LABEL" "$PART"
sudo mount -o rw,nosuid,nodev,noexec "$PART" "$MNT"; sudo mkdir -p "$MNT/EFI/BOOT" "$MNT/EFI/DS713V94/drivers"; sudo install -m 0644 "$OUT/BOOTX64.EFI" "$MNT/EFI/BOOT/BOOTX64.EFI"
for f in "$OUT"/drivers/*.efi; do sudo install -m 0644 "$f" "$MNT/EFI/DS713V94/drivers/$(basename "$f")"; done
cat > "$WORK/startup.nsh" <<'NSH'
@echo -off
fs0:\EFI\BOOT\BOOTX64.EFI
fs1:\EFI\BOOT\BOOTX64.EFI
fs2:\EFI\BOOT\BOOTX64.EFI
fs3:\EFI\BOOT\BOOTX64.EFI
fs4:\EFI\BOOT\BOOTX64.EFI
fs5:\EFI\BOOT\BOOTX64.EFI
fs6:\EFI\BOOT\BOOTX64.EFI
fs7:\EFI\BOOT\BOOTX64.EFI
fs8:\EFI\BOOT\BOOTX64.EFI
fs9:\EFI\BOOT\BOOTX64.EFI
exit
NSH
sudo install -m 0644 "$WORK/startup.nsh" "$MNT/startup.nsh"; sync
for rel in EFI/BOOT/BOOTX64.EFI EFI/DS713V94/drivers/XhciDxe.efi EFI/DS713V94/drivers/UsbBusDxe.efi EFI/DS713V94/drivers/UsbMassStorageDxe.efi EFI/DS713V94/drivers/DiskIoDxe.efi EFI/DS713V94/drivers/PartitionDxe.efi EFI/DS713V94/drivers/EnglishDxe.efi EFI/DS713V94/drivers/Fat.efi startup.nsh; do [[ -f "$MNT/$rel" ]] || fail "fichier manquant après copie: $rel"; done
BOOT_SHA="$(sudo sha256sum "$MNT/EFI/BOOT/BOOTX64.EFI" | awk '{print $1}')"; XHCI_SHA="$(sudo sha256sum "$MNT/EFI/DS713V94/drivers/XhciDxe.efi" | awk '{print $1}')"
echo; sudo find "$MNT" -type f -printf '%P\t%s bytes\n' | sort; sudo umount "$MNT"; sudo "$FSCK" -n "$PART"
echo; echo "============================================================"; echo " DS713Bridge v9.4 FULL-STACK R2 KEY READY"; echo "============================================================"
echo "TARGET=$TARGET"; echo "PART=$PART"; echo "LABEL=$LABEL"; echo "PROFILE=$PROFILE"; echo "EDK2_TAG=$EDK_TAG"; echo "EDK2_COMMIT=$EDK_COMMIT"; echo "BOOTX64_SHA=$BOOT_SHA"; echo "XHCIDXE_SHA=$XHCI_SHA"; echo "XHCI_PROVENANCE=$XHCI_PROVENANCE"
echo "FULL_MODERN_STACK=YES"; echo "DRIVERS=XhciDxe,UsbBusDxe,UsbMassStorageDxe,DiskIoDxe,PartitionDxe,EnglishDxe,Fat"; echo "EFI_DRIVER_BINDING_PROTOCOL=YES"; echo "Binding->Supported + Binding->Start = YES"; echo "OS_LoadImage (TRUE) = YES"; echo "SetWatchdogTimer (300) = YES"; echo 'STANDARD_CHAINLOAD=\EFI\BOOT\BOOTX64.EFI'; echo "NVRAM_WRITES=ZERO"; echo "READY_FOR_FRONT_BRIDGE_REAR_SSD_TEST=YES"; echo "BACKUP_METADATA=$BACKUP"
