#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TOKEN='DS713_NATIVE_N3_FLASH_ARM_V1'

usage(){
  cat <<EOF
Usage: ./scripts/open-ds713plus.sh STAGE

Stages from a Linux PC with DSM still reachable by SSH:
  audit    Build/install flashrom tools, probe the DS713+, double-dump SPI, build UEFI tools. No SPI write.
  build    Verify the hardware-tested N3 payload and build one combined F400+N3 firmware candidate. No SPI write.
  prepare  Run the live preflight and start the remote flash worker in WAITING_FOR_ARM. No SPI write.
  arm      Explicitly arm the real SPI write. Requires prepare first.
  status   Show the remote flash status and log tail.
  verify   Double-verify the full BIOS after a successful flash; only this can print READY_FOR_REBOOT=YES.

Required environment:
  NAS_HOST=192.168.1.x
  NAS_USER=your-dsm-admin
EOF
}

stage="${1:-}"
case "$stage" in
  audit)
    "$ROOT/scripts/00-build-flashrom.sh"
    "$ROOT/scripts/01-install-flashrom.sh"
    "$ROOT/scripts/02-probe.sh"
    "$ROOT/scripts/03-dump.sh"
    "$ROOT/scripts/04-build-uefi-tools.sh"
    ;;
  build)
    "$ROOT/scripts/native/00-prepare-loader.sh" validated
    "$ROOT/scripts/native/01-build-firmware.sh"
    ;;
  prepare)
    "$ROOT/scripts/native/02-preflight.sh"
    "$ROOT/scripts/native/03-flash.sh" prepare
    ;;
  arm)
    "$ROOT/scripts/native/03-flash.sh" arm "$TOKEN"
    ;;
  status)
    "$ROOT/scripts/native/03-flash.sh" status
    ;;
  verify)
    "$ROOT/scripts/native/04-postflash-verify.sh"
    ;;
  -h|--help|help|'') usage ;;
  *) usage >&2; exit 2 ;;
esac
