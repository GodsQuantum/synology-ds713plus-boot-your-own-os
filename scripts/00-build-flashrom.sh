#!/usr/bin/env bash
source "$(dirname "$0")/lib/common.sh"
need curl
RUNTIME=""
if command -v podman >/dev/null; then RUNTIME=podman; elif command -v docker >/dev/null; then RUNTIME=docker; else die 'Install podman or docker first.'; fi
BUILD="$WORK/flashrom-build"; rm -rf "$BUILD"; mkdir -p "$BUILD"
info 'Building flashrom 1.2.1 in Debian 11 for generic x86-64 (D2700-safe baseline)'
"$RUNTIME" run --rm -v "$BUILD:/work" docker.io/library/debian:11 /bin/bash -ceu '
 export DEBIAN_FRONTEND=noninteractive
 apt-get update
 apt-get install -y build-essential curl ca-certificates bzip2 pkg-config file
 cd /work
 curl -fL -o pciutils.tar.gz https://mj.ucw.cz/download/linux/pci/pciutils-3.10.0.tar.gz
 printf "%s  %s\n" "08ed5ccde46679998fa4ae21346e755b4451617f70348bacdf872b636f55b708" "pciutils.tar.gz" | sha256sum -c -
 tar xf pciutils.tar.gz
 mkdir -p /work/pciroot
 make -C pciutils-3.10.0 CC=gcc OPT="-O2 -march=x86-64 -mtune=generic" SHARED=no ZLIB=no DNS=no HWDB=no LIBKMOD=no PREFIX=/work/pciroot install-lib
 curl -fL -o flashrom.tar.bz2 https://download.flashrom.org/releases/flashrom-v1.2.1.tar.bz2
 printf "%s  %s\n" "89a7ff5beb08c89b8795bbd253a51b9453547a864c31793302296b56bbc56d65" "flashrom.tar.bz2" | sha256sum -c -
 tar xf flashrom.tar.bz2
 make -C flashrom-v1.2.1 CONFIG_NOTHING=yes CONFIG_INTERNAL=yes CONFIG_INTERNAL_DMI=yes CONFIG_STATIC=yes LIBS_BASE=/work/pciroot CFLAGS="-O2 -march=x86-64 -mtune=generic" WARNERROR=no -j"$(nproc)"
 cp flashrom-v1.2.1/flashrom /work/flashrom-d2700
 chmod 755 /work/flashrom-d2700
 file /work/flashrom-d2700
'
cp "$BUILD/flashrom-d2700" "$ARTIFACTS/flashrom-d2700"
chmod 755 "$ARTIFACTS/flashrom-d2700"
sha256sum "$ARTIFACTS/flashrom-d2700"
