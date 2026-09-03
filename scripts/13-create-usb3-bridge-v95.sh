#!/usr/bin/env bash
set -Eeuo pipefail
export LC_ALL=C

# DS713Bridge v9.5 — DS713+ SATA-power bring-up layered on the physically
# validated v9.4 FULL-STACK R2 rear-USB payload.
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
V94_WRITER="$ROOT/scripts/12-create-usb3-bridge-v94.sh"
V95_SOURCE="$ROOT/bridge/DS713Bridge-v9.5.c"
V95_SOURCE_SHA='e7e86ff27ceb9ae23639f3d85897285454d2b41f070e5983ffd8c3ec5f7ca4b8'
LABEL='DS713V95'
PROFILE='202605'
TARGET=''
SELF_TEST=0

EDK_202605_TAG='edk2-stable202605'
EDK_202605_COMMIT='b03a21a63e3bd001f52c527e5a57feddb53a690b'
EDK_202608_TAG='edk2-stable202608'
EDK_202608_COMMIT='2970e5699ba6267f3384ffab20f96647578aebc8'

usage() {
  cat <<'USAGE'
Usage: ./scripts/13-create-usb3-bridge-v95.sh [--latest] [/dev/disk/by-id/usb-*]
       ./scripts/13-create-usb3-bridge-v95.sh --self-test

Creates a complete v9.4 FULL-STACK R2 bridge key first, then replaces only the
front BOOTX64 application with v9.5. The v9.5 application powers DS713+
internal SATA bays through Cedarview/ICH10 GPIO16 and GPIO20 before loading the
unchanged v9.4 rear-USB driver stack.
USAGE
}

fail() { printf '\nERROR: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1; }

root_disk() {
  local src dev disk
  src="$(findmnt -n -o SOURCE /)"
  dev="${src%%\[*}"
  disk="$(lsblk -s -nrpo PATH,TYPE "$dev" 2>/dev/null | awk '$2=="disk"{print $1; exit}')"
  [[ -n "$disk" ]] || fail 'cannot identify system disk'
  readlink -f "$disk"
}

stable_usb_id() {
  local disk="$1" id resolved
  for id in /dev/disk/by-id/usb-*; do
    [[ -L "$id" ]] || continue
    [[ "$id" == *-part* ]] && continue
    resolved="$(readlink -f "$id" 2>/dev/null || true)"
    [[ "$resolved" == "$disk" ]] || continue
    printf '%s\n' "$id"
    return 0
  done
  return 1
}

choose_stable_target() {
  local root disk node size type tran id i choice answer
  root="$(root_disk)"

  if [[ -n "$TARGET" ]]; then
    node="$(readlink -f "$TARGET" 2>/dev/null || true)"
    [[ -n "$node" && -b "$node" ]] || fail "target does not exist: $TARGET"
    type="$(lsblk -dn -o TYPE "$node" | xargs)"
    tran="$(lsblk -dn -o TRAN "$node" | xargs)"
    size="$(lsblk -bdn -o SIZE "$node" | xargs)"
    [[ "$type" == disk ]] || fail "target is not a whole disk: $TARGET"
    [[ "$tran" == usb ]] || fail "target is not USB: $tran"
    [[ "$node" != "$root" ]] || fail 'REFUS: target is the system disk'
    [[ "$size" =~ ^[0-9]+$ ]] && (( size > 0 )) || fail 'target has invalid/zero size'
    id="$(stable_usb_id "$node" || true)"
    [[ -n "$id" ]] || fail 'target has no stable /dev/disk/by-id/usb-* identity'
    TARGET="$id"
  else
    mapfile -t USB_NODES < <(lsblk -dpno PATH,TRAN,TYPE | awk '$2=="usb" && $3=="disk"{print $1}')
    USB_IDS=()
    USB_GOOD_NODES=()

    for disk in "${USB_NODES[@]}"; do
      node="$(readlink -f "$disk")"
      [[ "$node" == "$root" ]] && continue
      size="$(lsblk -bdn -o SIZE "$node" | xargs)"
      [[ "$size" =~ ^[0-9]+$ ]] && (( size > 0 )) || continue
      id="$(stable_usb_id "$node" || true)"
      [[ -n "$id" ]] || continue
      USB_GOOD_NODES+=("$node")
      USB_IDS+=("$id")
    done

    ((${#USB_IDS[@]})) || fail 'no whole USB disk with stable /dev/disk/by-id identity found'

    echo
    echo '===== USB KEYS AVAILABLE ====='
    i=1
    for id in "${USB_IDS[@]}"; do
      node="${USB_GOOD_NODES[$((i-1))]}"
      printf '\n[%d] %s\n' "$i" "$node"
      printf '    stable-id: %s\n' "$id"
      lsblk -dn -o SIZE,MODEL,SERIAL "$node" | sed 's/^/    /'
      ((i++))
    done

    echo
    read -r -p 'Number of the USB key to ERASE: ' choice
    [[ "$choice" =~ ^[0-9]+$ ]] || fail 'invalid selection'
    (( choice >= 1 && choice <= ${#USB_IDS[@]} )) || fail 'selection out of range'
    TARGET="${USB_IDS[$((choice-1))]}"
  fi

  node="$(readlink -f "$TARGET")"
  echo
  echo '===== SELECTED USB KEY ====='
  echo "TARGET_STABLE_ID=$TARGET"
  echo "TARGET_RESOLVED=$node"
  lsblk -o NAME,PATH,TRAN,SIZE,FSTYPE,LABEL,MODEL,SERIAL,MOUNTPOINTS "$TARGET"

  echo
  read -r -p 'Type exactly ERASE to destroy this USB key and create DS713Bridge v9.5: ' answer
  [[ "$answer" == ERASE ]] || fail 'confirmation refused'

  # Rebuild forwarded args from the stable identity, never from an old /dev/sdX.
  FORWARD_ARGS=()
  [[ "$PROFILE" == 202608 ]] && FORWARD_ARGS+=(--latest)
  FORWARD_ARGS+=("$TARGET")
}


FORWARD_ARGS=()
for arg in "$@"; do
  case "$arg" in
    --latest)
      PROFILE='202608'
      FORWARD_ARGS+=("$arg")
      ;;
    --self-test)
      SELF_TEST=1
      ;;
    /dev/*)
      [[ -z "$TARGET" ]] || fail 'multiple target disks supplied'
      TARGET="$arg"
      FORWARD_ARGS+=("$arg")
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      fail "unknown argument: $arg"
      ;;
  esac
done

source_gate() {
  [[ -f "$V95_SOURCE" ]] || fail "missing source: $V95_SOURCE"
  local got
  got="$(sha256sum "$V95_SOURCE" | awk '{print $1}')"
  [[ "$got" == "$V95_SOURCE_SHA" ]] || fail "unexpected v9.5 source sha: $got"
  python3 "$ROOT/bridge/test_v95_static.py"
}

if (( SELF_TEST )); then
  for c in bash sha256sum python3; do need "$c" || fail "missing command: $c"; done
  [[ -x "$V94_WRITER" ]] || fail "missing v9.4 writer: $V94_WRITER"
  source_gate
  "$V94_WRITER" --self-test
  echo 'V95_LAYER=v9.5-sata-power-on-v9.4-full-stack-r2'
  echo 'HDD_POWER_SEQUENCE=GPIO16,200ms,GPIO20'
  echo 'DRIVER_PAYLOAD_REUSED=DS713V94'
  echo 'SELF_TEST=PASS'
  exit 0
fi

for c in lsblk findmnt readlink awk sed xargs; do
  need "$c" || fail "missing command: $c"
done
choose_stable_target
[[ -x "$V94_WRITER" ]] || fail "missing v9.4 writer: $V94_WRITER"
source_gate

# Phase 1: build the already validated full rear-USB stack and key layout.
YES=1 "$V94_WRITER" "${FORWARD_ARGS[@]}"

TARGET="$(readlink -f "$TARGET")"
[[ -b "$TARGET" ]] || fail "target disappeared after v9.4 creation: $TARGET"
PART="$(lsblk -lnpo NAME,TYPE "$TARGET" | awk '$2=="part"{print $1; exit}')"
[[ -b "$PART" ]] || fail 'bridge ESP not found after v9.4 creation'
[[ "$(lsblk -n -o FSTYPE "$PART" | xargs)" == 'vfat' ]] || fail 'bridge ESP is not vfat'

USER_NAME="${SUDO_USER:-${USER:-$(id -un)}}"
USER_HOME="$(getent passwd "$USER_NAME" 2>/dev/null | cut -d: -f6 || true)"
[[ -n "$USER_HOME" ]] || USER_HOME="$HOME"
CACHE="${XDG_CACHE_HOME:-$USER_HOME/.cache}/ds713plus-bridge-v94"
STATE="${XDG_STATE_HOME:-$USER_HOME/.local/state}/ds713plus-bridge-v95"
mkdir -p "$STATE"

if [[ "$PROFILE" == '202605' ]]; then
  EDK_TAG="$EDK_202605_TAG"
  EDK_COMMIT="$EDK_202605_COMMIT"
else
  EDK_TAG="$EDK_202608_TAG"
  EDK_COMMIT="$EDK_202608_COMMIT"
fi
EDK="$CACHE/$EDK_TAG"
[[ -d "$EDK/.git" ]] || fail "v9.4 EDK2 cache missing: $EDK"
[[ "$(git -C "$EDK" rev-parse HEAD)" == "$EDK_COMMIT" ]] || fail 'cached EDK2 commit mismatch'

WORK="$(mktemp -d /tmp/ds713-v95.XXXXXX)"
MNT="$(mktemp -d /tmp/ds713-v95-mnt.XXXXXX)"
WS_LINK="/tmp/ds713-v95-edk2-$$"
PKG=''
cleanup() {
  if mountpoint -q "$MNT" 2>/dev/null; then sudo umount "$MNT" 2>/dev/null || true; fi
  [[ -z "$PKG" ]] || rm -rf "$PKG" 2>/dev/null || true
  rm -f "$WS_LINK" 2>/dev/null || true
  rm -rf "$WORK" "$MNT"
}
trap cleanup EXIT

ln -s "$EDK" "$WS_LINK"
export WORKSPACE="$WS_LINK" PACKAGES_PATH="$WS_LINK" EDK_TOOLS_PATH="$WS_LINK/BaseTools"
export PYTHON_COMMAND=python3 SOURCE_DATE_EPOCH=0

pushd "$WS_LINK" >/dev/null
set +u
# shellcheck disable=SC1091
source "$WS_LINK/edksetup.sh" BaseTools >/dev/null
rc=$?
set -u
(( rc == 0 )) || fail "edksetup rc=$rc"

BUILD="$WS_LINK/BaseTools/BinWrappers/PosixLike/build"
[[ -x "$BUILD" ]] || fail 'EDK2 build wrapper missing'
PKG="$WS_LINK/DS713V95Pkg"
MOD="$PKG/DS713BridgeV95"
rm -rf "$PKG"
mkdir -p "$MOD"
cp "$V95_SOURCE" "$MOD/DS713BridgeV95.c"

cat > "$MOD/DS713BridgeV95.inf" <<'INF'
[Defines]
  INF_VERSION = 0x00010005
  BASE_NAME = DS713BridgeV95
  FILE_GUID = 1A80AFB2-4499-4D37-8BDE-713095A0C016
  MODULE_TYPE = UEFI_APPLICATION
  VERSION_STRING = 9.5
  ENTRY_POINT = UefiMain
[Sources]
  DS713BridgeV95.c
[Packages]
  MdePkg/MdePkg.dec
  MdeModulePkg/MdeModulePkg.dec
[LibraryClasses]
  UefiApplicationEntryPoint
  UefiBootServicesTableLib
  BaseMemoryLib
  MemoryAllocationLib
  DevicePathLib
  IoLib
[Protocols]
  gEfiDevicePathProtocolGuid
  gEfiDriverBindingProtocolGuid
  gEfiLoadedImageProtocolGuid
  gEfiPciIoProtocolGuid
  gEfiSimpleFileSystemProtocolGuid
INF

cat > "$PKG/DS713V95.dsc" <<'DSC'
[Defines]
  PLATFORM_NAME = DS713V95
  PLATFORM_GUID = 05676767-2D28-4EEF-976D-713095B0C020
  PLATFORM_VERSION = 0.1
  DSC_SPECIFICATION = 0x00010005
  OUTPUT_DIRECTORY = Build/DS713V95
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
  DS713V95Pkg/DS713BridgeV95/DS713BridgeV95.inf
DSC

"$BUILD" -a X64 -t GCC -b RELEASE \
  -p DS713V95Pkg/DS713V95.dsc \
  -m DS713V95Pkg/DS713BridgeV95/DS713BridgeV95.inf

V95_EFI="$(find "$WS_LINK/Build/DS713V95" -type f -name DS713BridgeV95.efi -path '*RELEASE_GCC*' -print | head -1)"
[[ -f "$V95_EFI" ]] || fail 'DS713BridgeV95.efi not found'
file "$V95_EFI" | grep -q 'PE32+ executable for EFI' || fail 'v9.5 EFI output is invalid'
popd >/dev/null

sudo mount -o rw,nosuid,nodev,noexec "$PART" "$MNT"
for rel in \
  EFI/DS713V94/drivers/XhciDxe.efi \
  EFI/DS713V94/drivers/UsbBusDxe.efi \
  EFI/DS713V94/drivers/UsbMassStorageDxe.efi \
  EFI/DS713V94/drivers/DiskIoDxe.efi \
  EFI/DS713V94/drivers/PartitionDxe.efi \
  EFI/DS713V94/drivers/EnglishDxe.efi \
  EFI/DS713V94/drivers/Fat.efi
  do
    [[ -f "$MNT/$rel" ]] || fail "validated v9.4 driver payload missing: $rel"
  done

BACKUP="$STATE/BOOTX64-v94-$(date +%Y%m%d-%H%M%S).EFI"
sudo cp "$MNT/EFI/BOOT/BOOTX64.EFI" "$BACKUP"
sudo install -m 0644 "$V95_EFI" "$MNT/EFI/BOOT/BOOTX64.EFI"
sync

BOOT_SHA="$(sudo sha256sum "$MNT/EFI/BOOT/BOOTX64.EFI" | awk '{print $1}')"
sudo umount "$MNT"
sudo fatlabel "$PART" "$LABEL"

FSCK="$(command -v fsck.fat || command -v fsck.vfat || true)"
[[ -n "$FSCK" ]] || fail 'fsck.fat/fsck.vfat missing'
sudo "$FSCK" -n "$PART"

echo
echo '============================================================'
echo ' DS713Bridge v9.5 SATA-POWER KEY READY'
echo '============================================================'
echo "TARGET=$TARGET"
echo "PART=$PART"
echo "LABEL=$LABEL"
echo "PROFILE=$PROFILE"
echo "EDK2_TAG=$EDK_TAG"
echo "EDK2_COMMIT=$EDK_COMMIT"
echo "BOOTX64_SHA=$BOOT_SHA"
echo 'SATA_POWER=GPIO16 -> 200ms -> GPIO20'
echo 'GPIO_IMPLEMENTATION=ICH10_LPC_GPIOBASE_0x48'
echo 'FULL_STACK_PAYLOAD=UNCHANGED_V94_R2'
echo 'STANDARD_CHAINLOAD=\\EFI\\BOOT\\BOOTX64.EFI'
echo 'NVRAM_WRITES=ZERO'
echo "V94_BOOT_BACKUP=$BACKUP"
echo 'READY_FOR_PHYSICAL_TEST=YES'
