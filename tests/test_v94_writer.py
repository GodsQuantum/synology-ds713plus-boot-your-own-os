#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "12-create-usb3-bridge-v94.sh"
SRC = ROOT / "bridge" / "DS713Bridge-v9.4.c"
assert SCRIPT.exists(), "v9.4 writer missing"
assert SRC.exists(), "v9.4 source missing"
s = SCRIPT.read_text()
c = SRC.read_text()

required = (
    "DS713Bridge v9.4 FULL-STACK R2",
    'EDK_202605_TAG="edk2-stable202605"',
    'EDK_202605_COMMIT="b03a21a63e3bd001f52c527e5a57feddb53a690b"',
    'EDK_202608_TAG="edk2-stable202608"',
    'EDK_202608_COMMIT="2970e5699ba6267f3384ffab20f96647578aebc8"',
    'XHCI_VALIDATED_SHA="20c3dbda0e0720fe171a7c0b06c995c4fe319f7338acfb75e9b5ee271a3092b3"',
    'XHCI_202605_NORMALIZED_SHA="ecb9726a4ecd6ce1fe39874b6b8a0e9374bfdcaa08da77fbb3de827bae258e30"',
    'V94_SOURCE_SHA="75e00a082b11dbb9684eb240f77dbdbe3cfde952b90f7e4f8274020432a0ba39"',
    "V94_SOURCE_GZ_B64",
    "V94_EMBEDDED_SOURCE_GATE=PASS",
    "BUILD COMPLET VALIDÉ — PHASE DESTRUCTIVE",
    "ERASE-$TARGET",
    "--self-test",
    "--latest",
    "XHCI_PROVENANCE=",
    "READY_FOR_FRONT_BRIDGE_REAR_SSD_TEST=YES",
)
for token in required:
    assert token in s, token

for forbidden in (
    "/home/", "/Users/", "192.168.", "10.0.", "EXPECTED_SERIAL=",
    "TARGET=/dev/sdb",
):
    assert forbidden not in s, forbidden

# Build/preflight must happen before the first destructive write and before the
# ERASE confirmation; a build failure must leave the existing key untouched.
build_gate = s.index("===== BUILD COMPLET VALIDÉ — PHASE DESTRUCTIVE =====")
confirm = s.index('read -r -p "Tape exactement ERASE-$TARGET')
wipe = s.index('sudo wipefs --all --force "$TARGET"')
assert build_gate < confirm < wipe

# Whole USB disk, root-disk, and zero-size guards are mandatory.
assert '[[ "$type" == disk ]]' in s
assert '[[ "$tran" == usb ]]' in s
assert '[[ "$TARGET" != "$root" ]]' in s
assert "(( size > 0 )) || continue" in s

# Repository source and embedded source are exact matches by declared SHA.
import hashlib
assert hashlib.sha256(c.encode()).hexdigest() == "75e00a082b11dbb9684eb240f77dbdbe3cfde952b90f7e4f8274020432a0ba39"

print("V94_WRITER_TESTS=PASS")
