#!/usr/bin/env bash
source "$(dirname "$0")/lib/common.sh"
ORIG="${1:-$ARTIFACTS/bios-read1.bin}"
PATCHER="$ARTIFACTS/UEFIPatch"; EXTRACT="$ARTIFACTS/UEFIExtract"; PATCHFILE="$REPO_ROOT/patches/ds713plus-f400-unlock.txt"; OUT="$ARTIFACTS/candidate-bios.bin"
assert_file_size "$ORIG" 2097152
[[ -x "$PATCHER" && -x "$EXTRACT" ]] || die 'Run 04-build-uefi-tools.sh first.'
"$PATCHER" "$ORIG" "$PATCHFILE" -o "$OUT"
assert_file_size "$OUT" 2097152
TMP="$WORK/uefi-verify"; rm -rf "$TMP"; mkdir -p "$TMP/orig" "$TMP/cand"
cp "$ORIG" "$TMP/orig/orig.bin"
cp "$OUT"  "$TMP/cand/cand.bin"
(cd "$TMP/orig" && "$EXTRACT" orig.bin >/dev/null)
(cd "$TMP/cand" && "$EXTRACT" cand.bin >/dev/null)
python3 - "$TMP/orig/orig.bin.dump" "$TMP/cand/cand.bin.dump" <<'PY'
import pathlib,sys
stock=bytes.fromhex('B900F40000663B4808')
j1=bytes.fromhex('0F8517030000'); mid=bytes.fromhex('663B480A'); j2=bytes.fromhex('0F850D030000'); nop=b'\x90'*6

def hit(root, patched):
    matches=[]
    for p in pathlib.Path(root).rglob('*'):
        if not p.is_file(): continue
        try: b=p.read_bytes()
        except: continue
        if len(b) < 0x29a1: continue
        if b[0x2983:0x298c] != stock: continue
        if b[0x2997:0x299b] != mid: continue
        expected1=nop if patched else j1; expected2=nop if patched else j2
        if b[0x2991:0x2997]==expected1 and b[0x299b:0x29a1]==expected2: matches.append(p)
    if len(matches)!=1: raise SystemExit(f'Expected exactly one UsbBusDxe PE match in {root}, got {len(matches)}')
    return matches[0]
print('STOCK_PE=',hit(sys.argv[1],False)); print('PATCHED_PE=',hit(sys.argv[2],True))
PY
cmp -s "$ORIG" "$OUT" && die 'Candidate is identical to stock.'
sha256sum "$ORIG" "$OUT" | tee "$ARTIFACTS/patch-sha256.txt"
info 'Candidate structurally parses and the two exact UsbBusDxe branches are NOPed.'
