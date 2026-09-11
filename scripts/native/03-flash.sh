#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/scripts/lib/common.sh"
need_remote

MODE="${1:-status}"
TOKEN='DS713_NATIVE_N3_FLASH_ARM_V1'
PREFLIGHT="$ARTIFACTS/native-preflight.env"
CURRENT="$ARTIFACTS/native-current-4MiB.bin"
CANDIDATE="$ARTIFACTS/candidate-4MiB.bin"
LAYOUT="$ARTIFACTS/native-patch.layout"

[[ -f "$PREFLIGHT" ]] || die 'Run scripts/native/02-preflight.sh first.'
# shellcheck disable=SC1090
source "$PREFLIGHT"
[[ "${PREFLIGHT_SAFE:-}" == YES && "${READY_TO_FLASH:-}" == YES && "${SPI_WRITE:-}" == ZERO ]] || die 'Native preflight gate is not clean.'
assert_file_size "$CURRENT" 4194304
assert_file_size "$CANDIDATE" 4194304
[[ "$(sha "$CURRENT")" == "$SOURCE_CARRIER_SHA" ]] || die 'Current source artifact hash mismatch.'
[[ "$(sha "$CANDIDATE")" == "$CANDIDATE_CARRIER_SHA" ]] || die 'Candidate artifact hash mismatch.'
[[ "$(sha "$LAYOUT")" == "$LAYOUT_SHA" ]] || die 'Patch layout hash mismatch.'

case "$MODE" in
prepare)
  ssh "$SSH_TARGET" "mkdir -p '$REMOTE_WORK'"
  raw_copy "$CURRENT" "$REMOTE_WORK/native-current-4MiB.bin"
  raw_copy "$CANDIDATE" "$REMOTE_WORK/native-candidate-4MiB.bin"
  raw_copy "$LAYOUT" "$REMOTE_WORK/native-patch.layout"
  W="$WORK/native-flash-worker.sh"
  L="$WORK/native-flash-launcher.sh"
  cat > "$W" <<REMOTE
set -u
D="\$1"; F=/root/flashrom-d2700
CUR="\$D/native-current-4MiB.bin"; NEW="\$D/native-candidate-4MiB.bin"; L="\$D/native-patch.layout"
STATUS="\$D/NATIVE-N3-FLASH-STATUS.txt"; ARM="\$D/NATIVE-N3-ARM-WRITE"; TOKEN='$TOKEN'
status(){ printf '%s\n' "\$1" > "\$STATUS"; sync; }
abort(){ echo "ABORT: \$1"; status 'FINAL_STATUS=ABORTED_BEFORE_WRITE'; exit 10; }
status 'STATUS=PREFLIGHT'
[ "\$(wc -c < "\$CUR")" -eq 4194304 ] || abort 'source size mismatch'
[ "\$(wc -c < "\$NEW")" -eq 4194304 ] || abort 'candidate size mismatch'
[ "\$(sha256sum "\$CUR" | awk '{print \$1}')" = '$SOURCE_CARRIER_SHA' ] || abort 'source hash mismatch'
[ "\$(sha256sum "\$NEW" | awk '{print \$1}')" = '$CANDIDATE_CARRIER_SHA' ] || abort 'candidate hash mismatch'
[ "\$(sha256sum "\$L" | awk '{print \$1}')" = '$LAYOUT_SHA' ] || abort 'layout hash mismatch'
"\$F" -p internal:ich_spi_mode=hwseq --flash-size -VV > "\$D/native-flash-live-probe.log" 2>&1 || abort 'flashrom probe failed'
grep -Eq '^4194304\r?\$' "\$D/native-flash-live-probe.log" || abort 'SPI size mismatch'
grep -q '1024 erase blocks with 4096 B each' "\$D/native-flash-live-probe.log" || abort 'erase geometry mismatch'
grep -q 'BIOS region (0x00011000-0x00210fff) is read-write' "\$D/native-flash-live-probe.log" || abort 'BIOS region not writeable'
grep -q 'BIOS Write Enable: enabled' "\$D/native-flash-live-probe.log" || abort 'BIOSWE disabled'
grep -q 'BERASE=1.*FLOCKDN=0' "\$D/native-flash-live-probe.log" || abort 'lock state mismatch'
for n in 0 1 2 3 4; do grep -q "(PR\$n is unused)" "\$D/native-flash-live-probe.log" || abort "PR\$n active"; done
"\$F" -p internal:ich_spi_mode=hwseq -l "\$L" -i n3patch -N -v "\$CUR" -VV || abort 'fresh source verification failed'
status 'STATUS=WAITING_FOR_ARM'
n=0
while [ "\$n" -lt 1800 ]; do
  if [ -f "\$ARM" ] && [ "\$(cat "\$ARM" 2>/dev/null)" = "\$TOKEN" ]; then break; fi
  sleep 1; n=\$((n+1))
done
[ "\$n" -lt 1800 ] || { status 'FINAL_STATUS=TIMEOUT_NO_WRITE'; exit 0; }
rm -f "\$ARM"
status 'STATUS=WRITING_CANDIDATE'
set +e
"\$F" -p internal:ich_spi_mode=hwseq -l "\$L" -i n3patch -N -w "\$NEW" -VV
WRC=\$?
set -e
echo FLASHROM_WRITE_RC=\$WRC
status 'STATUS=VERIFYING_CANDIDATE'
set +e
"\$F" -p internal:ich_spi_mode=hwseq -l "\$L" -i n3patch -N -v "\$NEW" -VV; V1=\$?
"\$F" -p internal:ich_spi_mode=hwseq -l "\$L" -i n3patch -N -v "\$NEW" -VV; V2=\$?
set -e
echo CANDIDATE_VERIFY_1_RC=\$V1
echo CANDIDATE_VERIFY_2_RC=\$V2
if [ "\$WRC" -eq 0 ] && [ "\$V1" -eq 0 ] && [ "\$V2" -eq 0 ]; then
  status 'FINAL_STATUS=SUCCESS_CANDIDATE_VERIFIED_TWICE'; exit 0
fi
status 'STATUS=ROLLBACK'
set +e
"\$F" -p internal:ich_spi_mode=hwseq -l "\$L" -i n3patch -N -w "\$CUR" -VV; RWR=\$?
"\$F" -p internal:ich_spi_mode=hwseq -l "\$L" -i n3patch -N -v "\$CUR" -VV; RV1=\$?
"\$F" -p internal:ich_spi_mode=hwseq -l "\$L" -i n3patch -N -v "\$CUR" -VV; RV2=\$?
set -e
echo ROLLBACK_WRITE_RC=\$RWR
echo ROLLBACK_VERIFY_1_RC=\$RV1
echo ROLLBACK_VERIFY_2_RC=\$RV2
if [ "\$RWR" -eq 0 ] && [ "\$RV1" -eq 0 ] && [ "\$RV2" -eq 0 ]; then
  status 'FINAL_STATUS=ROLLBACK_ORIGINAL_VERIFIED_TWICE'; exit 2
fi
status 'FINAL_STATUS=CRITICAL_DO_NOT_POWER_CYCLE'; exit 99
REMOTE
  cat > "$L" <<'REMOTE'
D="$1"
rm -f "$D/NATIVE-N3-ARM-WRITE" "$D/NATIVE-N3-FLASH-STATUS.txt" "$D/NATIVE-N3-FLASH.log" "$D/NATIVE-N3-FLASH.pid"
nohup sh "$D/native-flash-worker.sh" "$D" > "$D/NATIVE-N3-FLASH.log" 2>&1 < /dev/null &
echo $! > "$D/NATIVE-N3-FLASH.pid"
sleep 1
cat "$D/NATIVE-N3-FLASH.pid"
cat "$D/NATIVE-N3-FLASH-STATUS.txt" 2>/dev/null || true
REMOTE
  raw_copy "$W" "$REMOTE_WORK/native-flash-worker.sh"
  raw_copy "$L" "$REMOTE_WORK/native-flash-launcher.sh"
  ssh -tt "$SSH_TARGET" "sudo sh '$REMOTE_WORK/native-flash-launcher.sh' '$REMOTE_WORK'"
  echo "PREPARED_NO_WRITE=YES"
  echo "When status is WAITING_FOR_ARM, run: ./scripts/native/03-flash.sh arm $TOKEN"
  ;;
arm)
  [[ "${2:-}" == "$TOKEN" ]] || die "Explicit token required: $TOKEN"
  STATE="$(ssh "$SSH_TARGET" "cat '$REMOTE_WORK/NATIVE-N3-FLASH-STATUS.txt' 2>/dev/null; P=\$(cat '$REMOTE_WORK/NATIVE-N3-FLASH.pid' 2>/dev/null); ps -p \"\$P\" -o pid=,user=,stat=,cmd= 2>/dev/null")"
  printf '%s\n' "$STATE"
  grep -q '^STATUS=WAITING_FOR_ARM$' <<<"$STATE" || die 'Worker is not waiting for arm.'
  grep -q 'native-flash-worker.sh' <<<"$STATE" || die 'Flash worker is not alive.'
  printf '%s\n' "$TOKEN" | ssh "$SSH_TARGET" "cat > '$REMOTE_WORK/NATIVE-N3-ARM-WRITE'"
  echo 'REAL_SPI_WRITE_ARMED=YES'
  ;;
status)
  ssh "$SSH_TARGET" "echo STATUS=; cat '$REMOTE_WORK/NATIVE-N3-FLASH-STATUS.txt' 2>/dev/null || true; echo; echo LOG_TAIL=; tail -n 120 '$REMOTE_WORK/NATIVE-N3-FLASH.log' 2>/dev/null || true"
  ;;
*) die 'Usage: 03-flash.sh prepare | arm DS713_NATIVE_N3_FLASH_ARM_V1 | status' ;;
esac
