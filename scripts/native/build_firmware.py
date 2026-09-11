#!/usr/bin/env python3
import hashlib
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / 'artifacts'
TMP = ART / 'native-bios-work'
BUILD_ENV = ART / 'native-build.env'
UEFIEXTRACT = ART / 'UEFIExtract'

def load_build_env():
    if not BUILD_ENV.is_file():
        raise RuntimeError('Run scripts/native/00-prepare-loader.sh first')
    return dict(line.strip().split('=', 1) for line in BUILD_ENV.read_text().splitlines() if '=' in line)

_BUILD = load_build_env()
BASETOOLS = Path(_BUILD['EDK2_CACHE']) / 'BaseTools' / 'Source' / 'C' / 'bin'
GENSEC = BASETOOLS / 'GenSec'
GENFFS = BASETOOLS / 'GenFfs'
LZMA = BASETOOLS / 'LzmaCompress'
SHELL_GUID = 'C57AD6B7-0515-40A8-9D21-551652854E37'
OUTER_GUID = '9E21FD93-9C72-4C15-8C4B-E77F1DB2D792'
GUIDED_GUID = 'EE4E5898-3914-4259-9D6E-DC7BD79403CF'
FV_GUID = '30D9ED01-38D2-418A-90D5-C561750BF80F'
BIOS_BASE = 0x11000
BIOS_SIZE = 0x200000
BLOCK = 0x1000


def run(*args, cwd=None):
    subprocess.run([str(x) for x in args], cwd=cwd, check=True)


def unique_dir(root, suffix):
    hits = [p for p in root.rglob('*') if p.is_dir() and p.name.upper().endswith(suffix.upper())]
    if len(hits) != 1:
        raise RuntimeError(f'{suffix}: expected 1 directory, got {len(hits)}')
    return hits[0]


def whole(node):
    return (node / 'header.bin').read_bytes() + (node / 'body.bin').read_bytes()


def patch_state(path, state):
    b = bytearray(path.read_bytes())
    if len(b) < 24:
        raise RuntimeError('FFS too small')
    b[23] = state
    path.write_bytes(b)


def patch_guid_data_offset(path, data_offset):
    b = bytearray(path.read_bytes())
    b[20:22] = int(data_offset).to_bytes(2, 'little')
    path.write_bytes(b)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def extract_all(image, stem):
    local = TMP / f'{stem}.bin'
    shutil.copy2(image, local)
    for p in [TMP / f'{stem}.bin.dump', TMP / f'{stem}.bin.report.txt']:
        if p.is_dir(): shutil.rmtree(p)
        elif p.exists(): p.unlink()
    run(UEFIEXTRACT, local.name, 'all', cwd=TMP)
    return TMP / f'{stem}.bin.dump', TMP / f'{stem}.bin.report.txt'


def verify_f400_unlock(dump_root):
    anchor = bytes.fromhex('B900F4000033F6448ACA663B4808')
    mid = bytes.fromhex('663B480A')
    nop = b'\x90' * 6
    hits = []
    for path in Path(dump_root).rglob('body.bin'):
        if 'PE32 image section' not in str(path.parent):
            continue
        try:
            data = path.read_bytes()
        except OSError:
            continue
        off = data.find(anchor)
        if off < 0 or data.find(anchor, off + 1) >= 0:
            continue
        pos1 = off + len(anchor)
        posmid = pos1 + 6
        pos2 = posmid + len(mid)
        if data[pos1:pos1+6] == nop and data[posmid:posmid+4] == mid and data[pos2:pos2+6] == nop:
            hits.append(path)
    if len(hits) != 1:
        raise RuntimeError(f'F400 unlock: expected exactly one patched UsbBusDxe PE, got {len(hits)}')
    return hits[0]

def main():
    stock_bios = ART / 'bios-read1.bin'
    src_bios = ART / 'candidate-bios.bin'  # output of 05-patch-bios.sh: F400 unlock applied
    src_carrier = ART / 'used-regions-read1.bin'  # exact stock live 4 MiB carrier
    native = ART / 'DS713NativeBoot.efi'
    validated_native = ROOT / 'native' / 'validated' / 'DS713NativeBoot-N3.efi'
    for path, expected in ((stock_bios, BIOS_SIZE), (src_bios, BIOS_SIZE), (src_carrier, 0x400000)):
        if not path.is_file() or path.stat().st_size != expected:
            raise RuntimeError(f'source size gate failed: {path}')
    if src_carrier.read_bytes()[BIOS_BASE:BIOS_BASE+BIOS_SIZE] != stock_bios.read_bytes():
        raise RuntimeError('stock carrier BIOS slice does not equal bios-read1.bin')
    build_env = load_build_env()
    expected_native = build_env.get('NATIVE_SHA256')
    if not validated_native.is_file() or sha(validated_native) != expected_native:
        raise RuntimeError('validated DS713NativeBoot-N3.efi provenance hash mismatch')
    if not expected_native or sha(native) != expected_native or native.read_bytes() != validated_native.read_bytes():
        raise RuntimeError('N3 loader does not match the hardware-validated payload')
    if TMP.exists(): shutil.rmtree(TMP)
    TMP.mkdir(parents=True)

    dump, source_report = extract_all(src_bios, 'source')
    verify_f400_unlock(dump)
    outer = unique_dir(dump, OUTER_GUID)
    guided = unique_dir(outer, GUIDED_GUID)
    fv = unique_dir(guided, FV_GUID)
    shell = unique_dir(fv, SHELL_GUID)
    pe_hits = list(shell.glob('* PE32 image section/body.bin'))
    if len(pe_hits) != 1: raise RuntimeError('source shell PE32 ambiguity')
    source_fv = (fv / 'header.bin').read_bytes() + (fv / 'body.bin').read_bytes()
    # UEFIExtract volume header+body is the exact 0x1B8000 FV.
    if len(source_fv) != 0x1B8000: raise RuntimeError('inner FV size changed')
    (ART / 'native-source-inner-fv.bin').write_bytes(source_fv)
    old_shell = whole(shell)
    if len(old_shell) != 0xB87DC: raise RuntimeError('source shell size changed')
    shell_state = old_shell[23]

    # Oracle 1: recreate original Shell FFS exactly (state byte adjusted for erase polarity).
    run(GENSEC, '-s', 'EFI_SECTION_PE32', '-o', TMP/'oracle-shell.sec', pe_hits[0])
    run(GENFFS, '-t', 'EFI_FV_FILETYPE_APPLICATION', '-g', SHELL_GUID,
        '-i', TMP/'oracle-shell.sec', '-o', TMP/'oracle-shell.ffs')
    patch_state(TMP/'oracle-shell.ffs', shell_state)
    if (TMP/'oracle-shell.ffs').read_bytes() != old_shell:
        raise RuntimeError('Shell FFS reconstruction oracle failed')

    # N3 Shell: exact built PE + RAW filler, preserving original FFS length.
    run(GENSEC, '-s', 'EFI_SECTION_PE32', '-o', TMP/'native.sec', native)
    base = 24 + (TMP/'native.sec').stat().st_size
    raw_total = len(old_shell) - base
    if raw_total <= 4: raise RuntimeError('not enough Shell space')
    (TMP/'filler.bin').write_bytes(b'\xff' * (raw_total - 4))
    run(GENSEC, '-s', 'EFI_SECTION_RAW', '-o', TMP/'filler.sec', TMP/'filler.bin')
    run(GENFFS, '-t', 'EFI_FV_FILETYPE_APPLICATION', '-g', SHELL_GUID,
        '-i', TMP/'native.sec', '-i', TMP/'filler.sec', '-o', TMP/'native-shell.ffs')
    patch_state(TMP/'native-shell.ffs', shell_state)
    new_shell = (TMP/'native-shell.ffs').read_bytes()
    if len(new_shell) != len(old_shell):
        raise RuntimeError(f'new Shell size {len(new_shell):#x} != {len(old_shell):#x}')

    shell_off = source_fv.find(old_shell)
    if shell_off < 0 or source_fv.find(old_shell, shell_off + 1) >= 0:
        raise RuntimeError('source Shell FFS not unique in inner FV')
    candidate_fv = source_fv[:shell_off] + new_shell + source_fv[shell_off + len(old_shell):]
    if candidate_fv[:shell_off] != source_fv[:shell_off] or candidate_fv[shell_off+len(old_shell):] != source_fv[shell_off+len(old_shell):]:
        raise RuntimeError('inner FV changed outside Shell span')
    (ART/'native-candidate-inner-fv.bin').write_bytes(candidate_fv)

    unc = (guided/'unc_data.bin').read_bytes()
    if len(unc) != 16 + len(source_fv) or unc[16:] != source_fv:
        raise RuntimeError('guided uncompressed layout changed')
    new_unc = unc[:16] + candidate_fv
    (TMP/'candidate.unc').write_bytes(new_unc)
    run(LZMA, '-e', '-o', TMP/'candidate.lzma', TMP/'candidate.unc')
    run(LZMA, '-d', '-o', TMP/'candidate.roundtrip', TMP/'candidate.lzma')
    if (TMP/'candidate.roundtrip').read_bytes() != new_unc:
        raise RuntimeError('LZMA roundtrip failed')

    # Oracle 2: package original compressed stream and reproduce the exact original outer FFS.
    guided_header = (guided/'header.bin').read_bytes()
    original_data_off = int.from_bytes(guided_header[20:22], 'little')
    run(GENSEC, '-s', 'EFI_SECTION_GUID_DEFINED', '-g', GUIDED_GUID, '-l', '24',
        '-r', 'PROCESSING_REQUIRED', '-o', TMP/'oracle-guided.sec', guided/'body.bin')
    patch_guid_data_offset(TMP/'oracle-guided.sec', original_data_off)
    if (TMP/'oracle-guided.sec').read_bytes() != whole(guided):
        raise RuntimeError('GUID section reconstruction oracle failed')
    run(GENFFS, '-t', 'EFI_FV_FILETYPE_FIRMWARE_VOLUME_IMAGE', '-g', OUTER_GUID,
        '-i', TMP/'oracle-guided.sec', '-o', TMP/'oracle-outer.ffs')
    patch_state(TMP/'oracle-outer.ffs', whole(outer)[23])
    if (TMP/'oracle-outer.ffs').read_bytes() != whole(outer):
        raise RuntimeError('outer FFS reconstruction oracle failed')

    run(GENSEC, '-s', 'EFI_SECTION_GUID_DEFINED', '-g', GUIDED_GUID, '-l', '24',
        '-r', 'PROCESSING_REQUIRED', '-o', TMP/'native-guided.sec', TMP/'candidate.lzma')
    patch_guid_data_offset(TMP/'native-guided.sec', original_data_off)
    run(GENFFS, '-t', 'EFI_FV_FILETYPE_FIRMWARE_VOLUME_IMAGE', '-g', OUTER_GUID,
        '-i', TMP/'native-guided.sec', '-o', TMP/'native-outer.ffs')
    patch_state(TMP/'native-outer.ffs', whole(outer)[23])
    new_outer = (TMP/'native-outer.ffs').read_bytes()
    old_outer = whole(outer)
    if len(new_outer) > len(old_outer): raise RuntimeError('new outer FFS grew beyond original')

    bios = src_bios.read_bytes()
    outer_off = bios.find(old_outer)
    if outer_off < 0 or bios.find(old_outer, outer_off + 1) >= 0:
        raise RuntimeError('outer FFS not unique in BIOS')
    candidate = bytearray(bios)
    candidate[outer_off:outer_off+len(old_outer)] = new_outer + b'\xff' * (len(old_outer)-len(new_outer))
    cand_bios = ART/'native-bios-2MiB.bin'
    cand_bios.write_bytes(candidate)

    carrier = src_carrier.read_bytes()
    if carrier[BIOS_BASE:BIOS_BASE+BIOS_SIZE] != stock_bios.read_bytes():
        raise RuntimeError('carrier BIOS slice no longer equals stock BIOS source')
    cand_carrier = bytearray(carrier)
    cand_carrier[BIOS_BASE:BIOS_BASE+BIOS_SIZE] = candidate
    (ART/'candidate-4MiB.bin').write_bytes(cand_carrier)

    cand_dump, cand_report = extract_all(cand_bios, 'candidate')
    verify_f400_unlock(cand_dump)
    cand_shell = unique_dir(cand_dump, SHELL_GUID)
    cand_pe = list(cand_shell.glob('* PE32 image section/body.bin'))
    if len(cand_pe) != 1: raise RuntimeError('candidate Shell PE32 ambiguity')
    shutil.copy2(cand_pe[0], ART/'native-candidate-shell.efi')
    if (ART/'native-candidate-shell.efi').read_bytes() != native.read_bytes():
        raise RuntimeError('candidate does not contain exact built loader')
    shutil.copy2(cand_report, ART/'native-bios-structural-report.txt')

    diffs = [i for i,(a,b) in enumerate(zip(carrier, cand_carrier)) if a != b]
    if not diffs: raise RuntimeError('candidate has no changes')
    first, last = diffs[0], diffs[-1]
    pstart = first // BLOCK * BLOCK
    pend = ((last // BLOCK) + 1) * BLOCK - 1
    changed_blocks = [o for o in range(0, len(carrier), BLOCK) if carrier[o:o+BLOCK] != cand_carrier[o:o+BLOCK]]
    contiguous = changed_blocks == list(range(changed_blocks[0], changed_blocks[-1]+BLOCK, BLOCK))
    if not contiguous: raise RuntimeError('changed erase blocks are not contiguous')

    env = ART/'native-bios-layout.env'
    env.write_text('\n'.join([
        f'SOURCE_BIOS_SHA={sha(stock_bios)}', f'F400_BIOS_SHA={sha(src_bios)}', f'SOURCE_CARRIER_SHA={sha(src_carrier)}',
        f'NATIVE_LOADER_SHA={sha(native)}', f'CANDIDATE_BIOS_SHA={sha(cand_bios)}',
        f'CANDIDATE_CARRIER_SHA={sha(ART/"candidate-4MiB.bin")}',
        f'SHELL_FV_OFFSET={shell_off:#x}', f'SHELL_ORIGINAL_SIZE={len(old_shell):#x}',
        f'SHELL_NEW_SIZE={len(new_shell):#x}', f'OUTER_BIOS_OFFSET={outer_off:#x}',
        f'OUTER_OLD_SIZE={len(old_outer):#x}', f'OUTER_NEW_SIZE={len(new_outer):#x}',
        f'DIFF_BYTES={len(diffs)}', f'FIRST_DIFF_PHYS={first:#x}', f'LAST_DIFF_PHYS={last:#x}',
        f'PATCH_START_PHYS={pstart:#x}', f'PATCH_END_PHYS={pend:#x}',
        f'PATCH_BLOCK_COUNT={len(changed_blocks)}', 'CHANGED_BLOCKS_CONTIGUOUS=YES',
        'COLD_TEST_REQUIRED=YES', 'BIOS_WRITE=ZERO', ''
    ]))
    (ART/'native-patch.layout').write_text(f'{pstart:08x}:{pend:08x} n3patch\n')
    print(env.read_text(), end='')
    print('FINAL_F400_UNLOCK=PASS')
    print('FINAL_N3_LOADER=PASS')
    print('NATIVE_BIOS_BUILD=PASS')

if __name__ == '__main__':
    main()
