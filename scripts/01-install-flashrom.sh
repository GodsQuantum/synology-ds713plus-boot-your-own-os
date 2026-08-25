#!/usr/bin/env bash
source "$(dirname "$0")/lib/common.sh"
need_remote
BIN="$ARTIFACTS/flashrom-d2700"; [[ -x "$BIN" ]] || die 'Run 00-build-flashrom.sh first.'
info 'Streaming flashrom over SSH (no scp/SFTP dependency)'
raw_copy "$BIN" /tmp/flashrom-d2700
ssh -tt "$SSH_TARGET" "sudo sh -c 'cp /tmp/flashrom-d2700 /root/flashrom-d2700 && chmod 700 /root/flashrom-d2700 && /root/flashrom-d2700 --version'"
