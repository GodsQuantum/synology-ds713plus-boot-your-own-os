#!/usr/bin/env bash
source "$(dirname "$0")/lib/common.sh"
RUNTIME=""
if command -v podman >/dev/null; then RUNTIME=podman; elif command -v docker >/dev/null; then RUNTIME=docker; else die 'Install podman or docker.'; fi

B="$WORK/uefi-tools"; rm -rf "$B"; mkdir -p "$B"
# UEFIPatch editing still requires LongSoft/UEFITool's unsupported old_engine.
# Pin the exact old_engine commit used by this repository.
UEFIPATCH_COMMIT=8d6fa6539b1e52236b0905f3ad889a7590af6fb9
# Use the current parser for post-build validation rather than the old parser.
UEFIEXTRACT_RELEASE=A75
UEFIEXTRACT_URL="https://github.com/LongSoft/UEFITool/releases/download/${UEFIEXTRACT_RELEASE}/UEFIExtract_NE_A75_x64_linux.zip"
UEFIEXTRACT_ZIP_SHA256=5ee05d0da0c235626de67959d6cd97767e0d7ac67d42c8839e5972e8c23fd5a5

"$RUNTIME" run --rm -v "$B:/work" docker.io/library/debian:11 /bin/bash -ceu "
 export DEBIAN_FRONTEND=noninteractive
 apt-get update
 apt-get install -y git build-essential qt5-qmake qtbase5-dev qtbase5-dev-tools curl ca-certificates unzip
 cd /work
 git clone https://github.com/LongSoft/UEFITool.git old
 cd old
 git checkout '$UEFIPATCH_COMMIT'
 test \"\$(git rev-parse HEAD)\" = '$UEFIPATCH_COMMIT'
 mkdir /work/build-patch && cd /work/build-patch
 qmake /work/old/UEFIPatch/uefipatch.pro
 make -j\"\$(nproc)\"

 cd /work
 curl -fL -o UEFIExtract.zip '$UEFIEXTRACT_URL'
 echo '$UEFIEXTRACT_ZIP_SHA256  UEFIExtract.zip' | sha256sum -c -
 mkdir extract-bin
 unzip -q UEFIExtract.zip -d extract-bin
"

PATCH_BIN="$(find "$B/build-patch" -type f -name UEFIPatch -perm -111 | head -n1)"
EXTRACT_BIN="$(find "$B/extract-bin" -type f -iname 'UEFIExtract*' -perm -111 | head -n1)"
[[ -n "$PATCH_BIN" && -n "$EXTRACT_BIN" ]] || die 'Could not locate UEFIPatch/UEFIExtract.'
cp "$PATCH_BIN" "$ARTIFACTS/UEFIPatch"
cp "$EXTRACT_BIN" "$ARTIFACTS/UEFIExtract"
chmod 755 "$ARTIFACTS/UEFIPatch" "$ARTIFACTS/UEFIExtract"
sha256sum "$ARTIFACTS/UEFIPatch" "$ARTIFACTS/UEFIExtract"
info 'UEFITool upstream explicitly labels old_engine editing as outdated/unsupported; current UEFIExtract A75 is used to parse both stock and rebuilt images after patching.'
