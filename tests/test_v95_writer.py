#!/usr/bin/env python3
from pathlib import Path

p = (Path(__file__).resolve().parents[1] / 'scripts/13-create-usb3-bridge-v95.sh')
s = p.read_text()
req = (
    '12-create-usb3-bridge-v94.sh',
    'DS713Bridge-v9.5.c',
    'V95_SOURCE_SHA=',
    'IoLib',
    'DS713BridgeV95.inf',
    'DS713V95.dsc',
    'EFI/DS713V94/drivers/XhciDxe.efi',
    'FULL_STACK_PAYLOAD=UNCHANGED_V94_R2',
    'SATA_POWER=GPIO16 -> 200ms -> GPIO20',
    'fatlabel',
    '--self-test',
)
for token in req:
    assert token in s, token
for forbidden in ('/dev/sda', '/dev/sdb', 'BootOrder', 'BootNext'):
    assert forbidden not in s, forbidden

for token in (
    'stable_usb_id()',
    'choose_stable_target()',
    '/dev/disk/by-id/usb-*',
    'Number of the USB key to ERASE:',
    'Type exactly ERASE to destroy this USB key',
    'TARGET_STABLE_ID=',
    'YES=1 "$V94_WRITER"',
):
    assert token in s, token
assert "FORWARD_ARGS+=(\"$TARGET\")" in s

print('V95_WRITER_STATIC_TESTS=PASS')
