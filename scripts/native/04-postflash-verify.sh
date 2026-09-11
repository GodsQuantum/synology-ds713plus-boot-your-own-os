#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/scripts/lib/common.sh"
need_remote

STATE="$(ssh "$SSH_TARGET" "cat '$REMOTE_WORK/NATIVE-N3-FLASH-STATUS.txt' 2>/dev/null")"
[[ "$STATE" == 'FINAL_STATUS=SUCCESS_CANDIDATE_VERIFIED_TWICE' ]] || die "Candidate is not in verified-success state: $STATE"
ssh "$SSH_TARGET" "printf '%s\n' '00011000:00210fff bios' > '$REMOTE_WORK/native-layout-bios-full.txt'"
set +e
ssh -tt "$SSH_TARGET" "sudo sh -c '
F=/root/flashrom-d2700; L=\"$REMOTE_WORK/native-layout-bios-full.txt\"; N=\"$REMOTE_WORK/native-candidate-4MiB.bin\"
\"\$F\" -p internal:ich_spi_mode=hwseq -l \"\$L\" -i bios -N -v \"\$N\" -V; R1=\$?
\"\$F\" -p internal:ich_spi_mode=hwseq -l \"\$L\" -i bios -N -v \"\$N\" -V; R2=\$?
echo FULL_BIOS_VERIFY_1_RC=\$R1
echo FULL_BIOS_VERIFY_2_RC=\$R2
if [ \"\$R1\" -eq 0 ] && [ \"\$R2\" -eq 0 ]; then echo READY_FOR_REBOOT=YES; exit 0; fi
echo READY_FOR_REBOOT=NO; exit 1
'" | tee "$ARTIFACTS/native-postflash-verify.log"
rc=${PIPESTATUS[0]}
set -e
[[ $rc -eq 0 ]] || die 'Full BIOS verification failed. DO NOT REBOOT.'
grep -q 'READY_FOR_REBOOT=YES' "$ARTIFACTS/native-postflash-verify.log" || die 'No reboot clearance.'
echo 'READY_FOR_REBOOT=YES'
