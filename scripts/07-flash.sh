#!/usr/bin/env bash
source "$(dirname "$0")/lib/common.sh"
need_remote
MODE="${1:-status}"; TOKEN='DS713_F400_UNLOCK_ARM_V1'
[[ -f "$ARTIFACTS/preflight.env" ]] && grep -q 'PREFLIGHT_SAFE=YES' "$ARTIFACTS/preflight.env" || die 'Run successful 06-preflight.sh first.'

CURRENT="$ARTIFACTS/current-4MiB.bin"
CANDIDATE="$ARTIFACTS/candidate-4MiB.bin"
LAYOUT="$ARTIFACTS/layout-patchzone.txt"
assert_file_size "$CURRENT" 4194304
assert_file_size "$CANDIDATE" 4194304
[[ -s "$LAYOUT" ]] || die 'Missing patchzone layout.'

case "$MODE" in
prepare)
  CUR_SHA="$(sha "$CURRENT")"; NEW_SHA="$(sha "$CANDIDATE")"; LAY_SHA="$(sha "$LAYOUT")"
  W="$WORK/flash-worker.sh"; L="$WORK/flash-launcher.sh"
  cat > "$W" <<REMOTE
set -u
D="\$1"; F=/root/flashrom-d2700; CUR="\$D/current-4MiB.bin"; NEW="\$D/candidate-4MiB.bin"; L="\$D/layout-patchzone.txt"; STATUS="\$D/FLASH-STATUS.txt"; ARM="\$D/ARM-WRITE"; TOKEN='$TOKEN'
CUR_SHA_EXPECTED='$CUR_SHA'; NEW_SHA_EXPECTED='$NEW_SHA'; LAY_SHA_EXPECTED='$LAY_SHA'
status(){ echo "\$1" > "\$STATUS"; sync; }
abort(){ echo "ABORT: \$1"; status FINAL_STATUS=ABORTED_BEFORE_WRITE; exit 10; }
status STATUS=PREFLIGHT

[ -x "\$F" ] || abort 'flashrom missing'
[ "\$(wc -c < "\$CUR")" -eq 4194304 ] || abort 'current carrier size mismatch'
[ "\$(wc -c < "\$NEW")" -eq 4194304 ] || abort 'candidate carrier size mismatch'
[ "\$(sha256sum "\$CUR" | awk '{print \$1}')" = "\$CUR_SHA_EXPECTED" ] || abort 'current carrier hash mismatch'
[ "\$(sha256sum "\$NEW" | awk '{print \$1}')" = "\$NEW_SHA_EXPECTED" ] || abort 'candidate carrier hash mismatch'
[ "\$(sha256sum "\$L" | awk '{print \$1}')" = "\$LAY_SHA_EXPECTED" ] || abort 'layout hash mismatch'

LINE="\$(cat "\$L")"; RANGE="\${LINE%% *}"; START="\${RANGE%%:*}"; END="\${RANGE##*:}"
[ "\${LINE##* }" = patchzone ] || abort 'layout name mismatch'
START_DEC=\$((0x\$START)); END_DEC=\$((0x\$END))
[ "\$START_DEC" -ge \$((0x11000)) ] || abort 'patchzone begins before BIOS'
[ "\$END_DEC" -le \$((0x210fff)) ] || abort 'patchzone ends after BIOS'
[ \$((START_DEC % 4096)) -eq 0 ] || abort 'patchzone start not 4K aligned'
[ \$(((END_DEC + 1) % 4096)) -eq 0 ] || abort 'patchzone end not 4K aligned'

"\$F" -p internal:ich_spi_mode=hwseq --flash-size -VV > "\$D/flash-live-probe.log" 2>&1 || abort 'hwseq probe failed'
grep -Eq '^4194304\r?\$' "\$D/flash-live-probe.log" || abort 'SPI size is not 4 MiB'
grep -q '1024 erase blocks with 4096 B each' "\$D/flash-live-probe.log" || abort '4 KiB erase geometry not confirmed'
grep -q 'BIOS region (0x00011000-0x00210fff) is read-write' "\$D/flash-live-probe.log" || abort 'BIOS region not read-write'
grep -q 'BIOS Write Enable: enabled' "\$D/flash-live-probe.log" || abort 'BIOSWE not enabled'
grep -q 'BERASE=1.*FLOCKDN=0' "\$D/flash-live-probe.log" || abort 'BERASE/FLOCKDN invariant failed'
for n in 0 1 2 3 4; do grep -q "(PR\$n is unused)" "\$D/flash-live-probe.log" || abort "PR\$n active"; done

"\$F" -p internal:ich_spi_mode=hwseq -l "\$L" -i patchzone -N -v "\$CUR" -V || abort 'live stock verification failed'
status STATUS=WAITING_FOR_ARM
n=0
while [ "\$n" -lt 1800 ]; do
  if [ -f "\$ARM" ] && [ "\$(cat "\$ARM" 2>/dev/null)" = "\$TOKEN" ]; then break; fi
  sleep 1; n=\$((n+1))
done
[ "\$n" -lt 1800 ] || { status FINAL_STATUS=TIMEOUT_NO_WRITE; exit 0; }
rm -f "\$ARM"; status STATUS=WRITING_CANDIDATE
"\$F" -p internal:ich_spi_mode=hwseq -l "\$L" -i patchzone -N -w "\$NEW" -VV; WRC=\$?; echo FLASHROM_WRITE_RC=\$WRC
status STATUS=VERIFYING_CANDIDATE
"\$F" -p internal:ich_spi_mode=hwseq -l "\$L" -i patchzone -N -v "\$NEW" -VV; VRC=\$?; echo CANDIDATE_VERIFY_RC=\$VRC
if [ "\$VRC" -eq 0 ]; then status FINAL_STATUS=SUCCESS_CANDIDATE_VERIFIED; exit 0; fi
status STATUS=ROLLBACK_IN_PROGRESS
"\$F" -p internal:ich_spi_mode=hwseq -l "\$L" -i patchzone -N -w "\$CUR" -VV; echo ROLLBACK_WRITE_RC=\$?
"\$F" -p internal:ich_spi_mode=hwseq -l "\$L" -i patchzone -N -v "\$CUR" -VV; RRC=\$?; echo ROLLBACK_VERIFY_RC=\$RRC
if [ "\$RRC" -eq 0 ]; then status FINAL_STATUS=ROLLBACK_ORIGINAL_VERIFIED; exit 2; fi
status FINAL_STATUS=CRITICAL_DO_NOT_REBOOT; exit 99
REMOTE
  cat > "$L" <<'REMOTE'
D="$1"; rm -f "$D/ARM-WRITE" "$D/FLASH-STATUS.txt" "$D/FLASH.log" "$D/FLASH.pid"
nohup sh "$D/flash-worker.sh" "$D" > "$D/FLASH.log" 2>&1 < /dev/null & echo $! > "$D/FLASH.pid"
sleep 1; cat "$D/FLASH.pid"; cat "$D/FLASH-STATUS.txt" 2>/dev/null || true
REMOTE
  ssh "$SSH_TARGET" "mkdir -p '$REMOTE_WORK'"
  # Refresh the exact artifacts that were validated locally; DSM's old SSH does not need SFTP/scp.
  raw_copy "$CURRENT" "$REMOTE_WORK/current-4MiB.bin"
  raw_copy "$CANDIDATE" "$REMOTE_WORK/candidate-4MiB.bin"
  raw_copy "$LAYOUT" "$REMOTE_WORK/layout-patchzone.txt"
  raw_copy "$W" "$REMOTE_WORK/flash-worker.sh"; raw_copy "$L" "$REMOTE_WORK/flash-launcher.sh"
  ssh -tt "$SSH_TARGET" "sudo sh '$REMOTE_WORK/flash-launcher.sh' '$REMOTE_WORK'"
  info 'Worker launched but NOT armed. Wait until STATUS=WAITING_FOR_ARM; inspect with status mode.'
  ;;
arm)
  STATE="$(ssh "$SSH_TARGET" "cat '$REMOTE_WORK/FLASH-STATUS.txt' 2>/dev/null; P=\$(cat '$REMOTE_WORK/FLASH.pid' 2>/dev/null); ps -p \"\$P\" -o pid=,ppid=,user=,stat=,cmd= 2>/dev/null")"
  printf '%s\n' "$STATE"
  grep -q '^STATUS=WAITING_FOR_ARM$' <<<"$STATE" || die 'Worker is not waiting for arm.'
  grep -q 'flash-worker.sh' <<<"$STATE" || die 'Worker process is not alive.'
  printf '%s\n' "$TOKEN" | ssh "$SSH_TARGET" "cat > '$REMOTE_WORK/ARM-WRITE'"
  info 'REAL SPI WRITE ARMED. Do not power off. Use status mode until a FINAL_STATUS appears.'
  ;;
status)
  ssh "$SSH_TARGET" "echo STATUS=; cat '$REMOTE_WORK/FLASH-STATUS.txt' 2>/dev/null || true; echo; echo LOG_TAIL=; tail -n 160 '$REMOTE_WORK/FLASH.log' 2>/dev/null || true"
  ;;
*) die 'Usage: 07-flash.sh prepare|arm|status';;
esac
