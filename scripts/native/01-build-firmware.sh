#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/scripts/lib/common.sh"

assert_file_size "$ARTIFACTS/bios-read1.bin" 2097152
assert_file_size "$ARTIFACTS/bios-read2.bin" 2097152
assert_file_size "$ARTIFACTS/used-regions-read1.bin" 4194304
assert_file_size "$ARTIFACTS/used-regions-read2.bin" 4194304
[[ "$(sha "$ARTIFACTS/bios-read1.bin")" == "$(sha "$ARTIFACTS/bios-read2.bin")" ]] || die 'The two BIOS dumps differ.'
[[ "$(sha "$ARTIFACTS/used-regions-read1.bin")" == "$(sha "$ARTIFACTS/used-regions-read2.bin")" ]] || die 'The two 4 MiB SPI dumps differ.'

"$ROOT/scripts/05-patch-bios.sh" "$ARTIFACTS/bios-read1.bin"
python3 "$ROOT/scripts/native/build_firmware.py" | tee "$ARTIFACTS/native-firmware-build.log"
grep -Fxq 'FINAL_F400_UNLOCK=PASS' "$ARTIFACTS/native-firmware-build.log" || die 'F400 gate missing from final candidate.'
grep -Fxq 'FINAL_N3_LOADER=PASS' "$ARTIFACTS/native-firmware-build.log" || die 'N3 gate missing from final candidate.'
assert_file_size "$ARTIFACTS/candidate-4MiB.bin" 4194304
[[ -s "$ARTIFACTS/native-patch.layout" ]] || die 'Native patch layout missing.'
echo 'NATIVE_FIRMWARE_BUILD=PASS'
