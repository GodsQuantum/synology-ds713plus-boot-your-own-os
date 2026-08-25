#!/usr/bin/env bash
source "$(dirname "$0")/lib/common.sh"
need_remote
[[ -f "$ARTIFACTS/probe.env" ]] || die 'Run 02-probe.sh first.'
grep -q 'PROBE_SAFE_PROFILE=YES' "$ARTIFACTS/probe.env" || die 'Probe not validated.'
LOCAL="$WORK/dump-remote.sh"
cat > "$LOCAL" <<'REMOTE'
set -eu
FLASH=/root/flashrom-d2700
D=/var/services/homes/${SUDO_USER:-admin}/ds713-f400-unlock
# D is overridden by first argument so this works with any DSM admin user.
D="$1"
mkdir -p "$D"
cat > "$D/read.layout" <<'LAYOUT'
00000000:00000fff fd
00001000:00010fff gbe
00011000:00210fff bios
LAYOUT
for n in 1 2; do
  "$FLASH" -p internal:ich_spi_mode=hwseq -l "$D/read.layout" -i fd -i gbe -i bios -V -r "$D/used$n.bin"
  test "$(wc -c < "$D/used$n.bin")" -eq 4194304
  dd if="$D/used$n.bin" of="$D/bios$n.bin" bs=4096 skip=17 count=512 2>/dev/null
  test "$(wc -c < "$D/bios$n.bin")" -eq 2097152
done
cmp -s "$D/used1.bin" "$D/used2.bin"
cmp -s "$D/bios1.bin" "$D/bios2.bin"
sha256sum "$D/used1.bin" "$D/used2.bin" "$D/bios1.bin" "$D/bios2.bin"
REMOTE
ssh "$SSH_TARGET" "mkdir -p '$REMOTE_WORK'"
raw_copy "$LOCAL" "$REMOTE_WORK/dump.sh"
ssh -tt "$SSH_TARGET" "sudo sh '$REMOTE_WORK/dump.sh' '$REMOTE_WORK'"
for spec in 'used1.bin:used-regions-read1.bin' 'used2.bin:used-regions-read2.bin' 'bios1.bin:bios-read1.bin' 'bios2.bin:bios-read2.bin'; do
  r=${spec%%:*}; l=${spec##*:}; ssh "$SSH_TARGET" "sudo cat '$REMOTE_WORK/$r'" > "$ARTIFACTS/$l"
done
assert_file_size "$ARTIFACTS/used-regions-read1.bin" 4194304
assert_file_size "$ARTIFACTS/used-regions-read2.bin" 4194304
assert_file_size "$ARTIFACTS/bios-read1.bin" 2097152
assert_file_size "$ARTIFACTS/bios-read2.bin" 2097152
cmp -s "$ARTIFACTS/used-regions-read1.bin" "$ARTIFACTS/used-regions-read2.bin" || die 'Used-region reads differ.'
cmp -s "$ARTIFACTS/bios-read1.bin" "$ARTIFACTS/bios-read2.bin" || die 'BIOS reads differ.'
sha256sum "$ARTIFACTS"/*read*.bin | tee "$ARTIFACTS/dump-sha256.txt"
info 'These files are private firmware dumps. Do not commit them.'
