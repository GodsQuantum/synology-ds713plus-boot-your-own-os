#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
s = (ROOT / "scripts/12-create-usb3-bridge-v94.sh").read_text()

required = (
    "preserve stable /dev/disk/by-id target",
    'target_real="$(readlink -f "$TARGET"',
    '[[ "$target_real" != "$root" ]]',
    'TARGET_NOW="$(readlink -f "$TARGET"',
    "stable target unavailable before write",
    "stable target has zero/invalid size before write",
    "stable target is no longer a whole disk",
    "stable target is no longer USB",
    'TARGET_STABLE_ID=$TARGET',
    'TARGET_RESOLVED_NOW=$TARGET_NOW',
)
for token in required:
    assert token in s, token

# Regression guard: an explicit stable ID must not be canonicalized early.
assert 'if [[ -n "$TARGET" ]]; then TARGET="$(readlink -f "$TARGET")"' not in s

print("V94_STABLE_TARGET_TESTS=PASS")
