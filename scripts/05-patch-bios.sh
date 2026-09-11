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
anchor=bytes.fromhex('B900F4000033F6448ACA663B4808')
j1=bytes.fromhex('0F8517030000')
mid=bytes.fromhex('663B480A')
j2=bytes.fromhex('0F850D030000')
nop=b'\x90'*6

def hit(root, patched):
    matches=[]
    for p in pathlib.Path(root).rglob('body.bin'):
        if 'PE32 image section' not in str(p.parent):
            continue
        try: b=p.read_bytes()
        except OSError: continue
        off=b.find(anchor)
        if off < 0 or b.find(anchor, off+1) >= 0:
            continue
        expected1=nop if patched else j1
        expected2=nop if patched else j2
        pos1=off+len(anchor)
        posmid=pos1+6
        pos2=posmid+len(mid)
        if b[pos1:pos1+6]==expected1 and b[posmid:posmid+4]==mid and b[pos2:pos2+6]==expected2:
            matches.append(p)
    if len(matches)!=1:
        raise SystemExit(f'Expected exactly one UsbBusDxe PE match in {root}, got {len(matches)}')
    return matches[0]
print('STOCK_PE=',hit(sys.argv[1],False))
print('PATCHED_PE=',hit(sys.argv[2],True))
PY
cmp -s "$ORIG" "$OUT" && die 'Candidate is identical to stock.'
sha256sum "$ORIG" "$OUT" | tee "$ARTIFACTS/patch-sha256.txt"
info 'Candidate structurally parses and the two exact UsbBusDxe branches are NOPed.'
