#!/usr/bin/env bash
source "$(dirname "$0")/lib/common.sh"
need_remote
LOG="$ARTIFACTS/probe.log"; TMP="$WORK/probe-remote.sh"
cat > "$TMP" <<'REMOTE'
FLASH=/root/flashrom-d2700
"$FLASH" -p internal:ich_spi_mode=hwseq --flash-name -VV
"$FLASH" -p internal:ich_spi_mode=hwseq --flash-size -VV
REMOTE
ssh "$SSH_TARGET" "mkdir -p '$REMOTE_WORK'"
raw_copy "$TMP" "$REMOTE_WORK/probe.sh"
ssh -tt "$SSH_TARGET" "sudo sh '$REMOTE_WORK/probe.sh'" | tee "$LOG"
info 'Validating the exact safety invariants of the tested DS713+ profile'
grep -Eq 'Found chipset "Intel ICH10R" with PCI ID 8086:3a16' "$LOG" || die 'ICH10R 8086:3a16 not confirmed.'
grep -Eq 'BIOS_CNTL = .*BIOS Write Enable: enabled' "$LOG" || die 'BIOS write-enable not confirmed.'
grep -Eq 'BERASE=1.*FLOCKDN=0' "$LOG" || die 'Expected BERASE=1/FLOCKDN=0 not confirmed.'
grep -Fq 'BIOS region (0x00011000-0x00210fff) is read-write' "$LOG" || die 'Expected BIOS region/layout not confirmed.'
for n in 0 1 2 3 4; do grep -Fq "(PR$n is unused)" "$LOG" || die "PR$n is not unused."; done
grep -Fq 'density of 4096 kB' "$LOG" || die '4 MiB opaque flash not confirmed.'
grep -Fq '1024 erase blocks with 4096 B each' "$LOG" || die '4 KiB erase geometry not confirmed.'
grep -Eq '^4194304\r?$' "$LOG" || die 'flashrom --flash-size did not report 4194304.'
printf 'PROBE_SAFE_PROFILE=YES\n' | tee "$ARTIFACTS/probe.env"
