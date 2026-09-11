#!/usr/bin/env bash
set -Eeuo pipefail
export LC_ALL=C
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/scripts/lib/common.sh"

MODE="${1:-validated}"
EDK_TAG='edk2-stable202605'
EDK_COMMIT='b03a21a63e3bd001f52c527e5a57feddb53a690b'
N3_SHA='63037d646791ddfc133840ecd5b4c80151213c61e8ce34862b7483799734d6a3'
VALIDATED="$ROOT/native/validated/DS713NativeBoot-N3.efi"
DRIVERS="$ROOT/native/validated/drivers"
CACHE_ROOT="${XDG_CACHE_HOME:-$HOME/.cache}/ds713plus-native"
EDK="$CACHE_ROOT/$EDK_TAG"

for c in git make gcc python3 sha256sum file objdump; do need "$c"; done
[[ "$MODE" == validated || "$MODE" == --rebuild ]] || die 'Usage: 00-prepare-loader.sh [validated|--rebuild]'

[[ -f "$VALIDATED" ]] || die 'Validated N3 payload missing.'
[[ "$(sha "$VALIDATED")" == "$N3_SHA" ]] || die 'Validated N3 payload hash mismatch.'
file "$VALIDATED" | grep -q 'PE32+ executable for EFI' || die 'Validated N3 payload is not EFI x64.'

declare -A EXPECTED=(
  [XhciDxe.efi]=20c3dbda0e0720fe171a7c0b06c995c4fe319f7338acfb75e9b5ee271a3092b3
  [UsbBusDxe.efi]=3799a88c3ee3167a3967dd8f27b9e5dfae83a3a9e451da9cc020dea9348fd929
  [UsbMassStorageDxe.efi]=1e4e7ed863b4fceb5841547a99aea5562021775c54df27fa43a7a7f44d9cd278
  [DiskIoDxe.efi]=9eef97a63b89a1dfdd027f65548ee11ad84a77f6667d963ca9c3e12eab0a66a6
  [PartitionDxe.efi]=66a132dd3d3320d9e266baa97a97a5fa3c60bbebcbf64bd8655d82d5479804aa
  [EnglishDxe.efi]=a6fd4d29191f1619471d963ff7f6f312805d7919243873849919c977432b9602
  [Fat.efi]=abe7f70fd82533eda88c1e62a69bf464b86ee74e8ed08f0ce80db930cfa77679
)
for f in "${!EXPECTED[@]}"; do
  [[ -f "$DRIVERS/$f" ]] || die "Validated driver missing: $f"
  [[ "$(sha "$DRIVERS/$f")" == "${EXPECTED[$f]}" ]] || die "Validated driver hash mismatch: $f"
done

mkdir -p "$CACHE_ROOT" "$ARTIFACTS"
if [[ ! -d "$EDK/.git" ]]; then
  git clone --depth 1 --branch "$EDK_TAG" https://github.com/tianocore/edk2.git "$EDK"
fi
git -C "$EDK" submodule update --init --depth 1 BaseTools/Source/C/BrotliCompress/brotli
[[ "$(git -C "$EDK" rev-parse HEAD)" == "$EDK_COMMIT" ]] || die 'Unexpected EDK2 commit.'
if [[ ! -x "$EDK/BaseTools/Source/C/bin/GenFfs" ]]; then
  make -C "$EDK/BaseTools" -j"$(nproc)"
fi

cp "$VALIDATED" "$ARTIFACTS/DS713NativeBoot.efi"
cat > "$ARTIFACTS/native-build.env" <<EOF
EDK2_COMMIT=$EDK_COMMIT
EDK2_CACHE=$EDK
NATIVE_SHA256=$N3_SHA
NATIVE_SIZE=$(size "$VALIDATED")
VALIDATED_PAYLOAD=YES
EOF

if [[ "$MODE" == --rebuild ]]; then
  WS="/tmp/ds713-native-edk2-$$"
  PKG="$EDK/DS713N3Pkg"
  trap 'rm -f "$WS"; rm -rf "$PKG"' EXIT
  rm -f "$WS"; ln -s "$EDK" "$WS"
  rm -rf "$PKG"; mkdir -p "$PKG"
  cp "$ROOT/native/DS713NativeBoot.c" "$PKG/"
  cp "$ROOT/native/DS713NativeBoot.inf" "$PKG/"
  cp "$ROOT/native/DS713NativeBoot.dsc" "$PKG/DS713N3.dsc"
  python3 "$ROOT/scripts/native/embed_binary.py" "$DRIVERS/XhciDxe.efi" XhciDxeBlob "$PKG/XhciDxeBlob.c"
  python3 "$ROOT/scripts/native/embed_binary.py" "$DRIVERS/UsbBusDxe.efi" UsbBusDxeBlob "$PKG/UsbBusDxeBlob.c"
  python3 "$ROOT/scripts/native/embed_binary.py" "$DRIVERS/UsbMassStorageDxe.efi" UsbMassStorageDxeBlob "$PKG/UsbMassStorageDxeBlob.c"
  python3 "$ROOT/scripts/native/embed_binary.py" "$DRIVERS/DiskIoDxe.efi" DiskIoDxeBlob "$PKG/DiskIoDxeBlob.c"
  python3 "$ROOT/scripts/native/embed_binary.py" "$DRIVERS/PartitionDxe.efi" PartitionDxeBlob "$PKG/PartitionDxeBlob.c"
  python3 "$ROOT/scripts/native/embed_binary.py" "$DRIVERS/EnglishDxe.efi" EnglishDxeBlob "$PKG/EnglishDxeBlob.c"
  python3 "$ROOT/scripts/native/embed_binary.py" "$DRIVERS/Fat.efi" FatDxeBlob "$PKG/FatDxeBlob.c"
  pushd "$WS" >/dev/null
  set +u; source edksetup.sh BaseTools >/dev/null; set -u
  export WORKSPACE="$WS" PACKAGES_PATH="$WS" EDK_TOOLS_PATH="$WS/BaseTools" PYTHON_COMMAND=python3 SOURCE_DATE_EPOCH=0
  "$EDK_TOOLS_PATH/BinWrappers/PosixLike/build" -a X64 -t GCC -b RELEASE -p DS713N3Pkg/DS713N3.dsc
  popd >/dev/null
  REBUILT="$(find "$EDK/Build/DS713NativeBoot/RELEASE_GCC/X64" -type f -name DS713NativeBoot.efi | head -1)"
  [[ -f "$REBUILT" ]] || die 'Rebuilt N3 payload not found.'
  GOT="$(sha "$REBUILT")"
  echo "REBUILT_SHA256=$GOT"
  [[ "$GOT" == "$N3_SHA" ]] || die 'Rebuild is not byte-identical to the hardware-validated N3. Default validated payload remains authoritative.'
  echo 'REBUILD_MATCH_VALIDATED=YES'
fi

objdump -f "$ARTIFACTS/DS713NativeBoot.efi" | grep -q 'pei-x86-64' || die 'Validated N3 payload has unexpected PE/COFF format.'
printf 'NATIVE_SHA256=%s\nNATIVE_PAYLOAD=PASS\n' "$N3_SHA"
