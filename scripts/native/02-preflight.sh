#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/scripts/lib/common.sh"
need_remote

[[ -f "$ARTIFACTS/probe.env" ]] && grep -q 'PROBE_SAFE_PROFILE=YES' "$ARTIFACTS/probe.env" || die 'Run 02-probe.sh successfully first.'
[[ -f "$ARTIFACTS/native-bios-layout.env" ]] || die 'Run scripts/native/01-build-firmware.sh first.'
# shellcheck disable=SC1090
source "$ARTIFACTS/native-bios-layout.env"
CURRENT="$ARTIFACTS/native-current-4MiB.bin"
CANDIDATE="$ARTIFACTS/candidate-4MiB.bin"
LAYOUT="$ARTIFACTS/native-patch.layout"
cp "$ARTIFACTS/used-regions-read1.bin" "$CURRENT"
assert_file_size "$CURRENT" 4194304
assert_file_size "$CANDIDATE" 4194304
[[ -s "$LAYOUT" ]] || die 'Native patch layout missing.'
[[ "$(sha "$CURRENT")" == "$SOURCE_CARRIER_SHA" ]] || die 'Stock carrier hash changed since build.'
[[ "$(sha "$CANDIDATE")" == "$CANDIDATE_CARRIER_SHA" ]] || die 'Final candidate hash changed since build.'

LAYOUT_SHA="$(sha "$LAYOUT")"
ssh "$SSH_TARGET" "mkdir -p '$REMOTE_WORK'"
raw_copy "$CURRENT" "$REMOTE_WORK/native-current-4MiB.bin"
raw_copy "$CANDIDATE" "$REMOTE_WORK/native-candidate-4MiB.bin"
raw_copy "$LAYOUT" "$REMOTE_WORK/native-patch.layout"

R="$WORK/native-preflight-remote.sh"
cat > "$R" <<REMOTE
set -eu
D="\$1"; F=/root/flashrom-d2700
CUR="\$D/native-current-4MiB.bin"; NEW="\$D/native-candidate-4MiB.bin"; L="\$D/native-patch.layout"
"\$F" -p internal:ich_spi_mode=hwseq --flash-size -VV > "\$D/native-live-probe.log" 2>&1
grep -Eq '^4194304\r?\$' "\$D/native-live-probe.log" || exit 20
grep -q '1024 erase blocks with 4096 B each' "\$D/native-live-probe.log" || exit 21
grep -q 'BIOS region (0x00011000-0x00210fff) is read-write' "\$D/native-live-probe.log" || exit 22
grep -q 'BIOS Write Enable: enabled' "\$D/native-live-probe.log" || exit 23
grep -q 'BERASE=1.*FLOCKDN=0' "\$D/native-live-probe.log" || exit 24
for n in 0 1 2 3 4; do grep -q "(PR\$n is unused)" "\$D/native-live-probe.log" || exit \$((30+n)); done
"\$F" -p internal:ich_spi_mode=hwseq -l "\$L" -i n3patch -N -v "\$CUR" -VV
ORC=\$?; echo ORIGINAL_VERIFY_RC=\$ORC; [ "\$ORC" -eq 0 ] || exit 40
set +e
"\$F" -p internal:ich_spi_mode=hwseq -l "\$L" -i n3patch -N -v "\$NEW" -VV
CRC=\$?
set -e
echo CANDIDATE_VERIFY_RC=\$CRC
[ "\$CRC" -ne 0 ] || { echo 'Candidate already matches flash; refusing first-write workflow.'; exit 41; }
echo DRY_RUN_COMPLETE=YES
REMOTE
raw_copy "$R" "$REMOTE_WORK/native-preflight.sh"
set +e
ssh -tt "$SSH_TARGET" "sudo sh '$REMOTE_WORK/native-preflight.sh' '$REMOTE_WORK'" | tee "$ARTIFACTS/native-preflight-live.log"
rc=${PIPESTATUS[0]}
set -e
[[ $rc -eq 0 ]] || die "Native preflight failed rc=$rc"
grep -q 'DRY_RUN_COMPLETE=YES' "$ARTIFACTS/native-preflight-live.log" || die 'Native dry-run did not complete.'
cat > "$ARTIFACTS/native-preflight.env" <<EOF
PREFLIGHT_SAFE=YES
READY_TO_FLASH=YES
SPI_WRITE=ZERO
SOURCE_CARRIER_SHA=$SOURCE_CARRIER_SHA
CANDIDATE_CARRIER_SHA=$CANDIDATE_CARRIER_SHA
LAYOUT_SHA=$LAYOUT_SHA
EOF
echo 'READY_TO_FLASH=YES'
