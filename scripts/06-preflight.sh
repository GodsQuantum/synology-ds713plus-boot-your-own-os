#!/usr/bin/env bash
source "$(dirname "$0")/lib/common.sh"
need_remote
[[ -f "$ARTIFACTS/probe.env" ]] && grep -q 'PROBE_SAFE_PROFILE=YES' "$ARTIFACTS/probe.env" || die 'Validated probe missing.'
USED="$ARTIFACTS/used-regions-read1.bin"; BIOS="$ARTIFACTS/candidate-bios.bin"; CURRENT="$ARTIFACTS/current-4MiB.bin"; CAND="$ARTIFACTS/candidate-4MiB.bin"; LAYOUT="$ARTIFACTS/layout-patchzone.txt"
assert_file_size "$USED" 4194304; assert_file_size "$BIOS" 2097152
cp "$USED" "$CURRENT"; cp "$USED" "$CAND"
dd if="$BIOS" of="$CAND" bs=4096 seek=17 conv=notrunc status=none
python3 "$REPO_ROOT/scripts/calc_patchzone.py" "$CURRENT" "$CAND" --erase 4096 --bios-base 0x11000 --bios-end 0x210fff --layout "$LAYOUT" | tee "$ARTIFACTS/preflight-diff.txt"
ssh "$SSH_TARGET" "mkdir -p '$REMOTE_WORK'"
for f in "$CURRENT" "$CAND" "$LAYOUT"; do raw_copy "$f" "$REMOTE_WORK/$(basename "$f")"; done
sha256sum "$CURRENT" "$CAND" "$LAYOUT" | tee "$ARTIFACTS/preflight-sha256.txt"
R="$WORK/preflight-remote.sh"
cat > "$R" <<'REMOTE'
set -u
D="$1"; F=/root/flashrom-d2700; CUR="$D/current-4MiB.bin"; NEW="$D/candidate-4MiB.bin"; L="$D/layout-patchzone.txt"
"$F" -p internal:ich_spi_mode=hwseq --flash-size -VV 2>&1 | tee "$D/live-probe.log"
grep -q '1024 erase blocks with 4096 B each' "$D/live-probe.log" || exit 20
grep -q 'BIOS region (0x00011000-0x00210fff) is read-write' "$D/live-probe.log" || exit 21
"$F" -p internal:ich_spi_mode=hwseq -l "$L" -i patchzone -N -v "$CUR" -VV; ORC=$?; echo ORIGINAL_VERIFY_RC=$ORC; [ "$ORC" -eq 0 ] || exit 30
"$F" -p internal:ich_spi_mode=hwseq -l "$L" -i patchzone -N -v "$NEW" -VV; CRC=$?; echo CANDIDATE_VERIFY_RC=$CRC
[ "$CRC" -ne 0 ] || { echo 'Candidate already matches flash; refusing first-write workflow.'; exit 31; }
echo DRY_RUN_COMPLETE=YES
REMOTE
raw_copy "$R" "$REMOTE_WORK/preflight.sh"
set +e
ssh -tt "$SSH_TARGET" "sudo sh '$REMOTE_WORK/preflight.sh' '$REMOTE_WORK'" | tee "$ARTIFACTS/preflight-live.log"
rc=${PIPESTATUS[0]}; set -e
[[ $rc -eq 0 ]] || die "Preflight failed rc=$rc"
grep -q 'DRY_RUN_COMPLETE=YES' "$ARTIFACTS/preflight-live.log" || die 'Dry run did not complete.'
printf 'PREFLIGHT_SAFE=YES\n' > "$ARTIFACTS/preflight.env"
