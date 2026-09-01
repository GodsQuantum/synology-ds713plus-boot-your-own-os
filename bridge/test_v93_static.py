from pathlib import Path
import re

ROOT = Path(__file__).resolve().parent
src = ROOT / 'DS713Bridge-v9.3.c'
assert src.exists(), 'DS713Bridge-v9.3.c missing'
s = src.read_text()

# Preserve validated v9.1 fast path invariants.
for token in (
    '0x1B6F', '0x7023',
    r'\\EFI\\DS713\\XhciDxe.efi',
    r'\\EFI\\BOOT\\BOOTX64.EFI',
    'RegisterProtocolNotify', 'ByRegisterNotify', 'WaitForEvent',
    'PciIoProtocol', 'FileSystemProtocol', 'LoadedImageProtocol',
):
    assert token in s, token

calls = re.findall(r'uefi_call_wrapper\(BS->ConnectController,\s*4,.*?\);', s, re.S)
assert len(calls) == 2, len(calls)
for call in calls:
    assert re.search(r',\s*FALSE\s*\)\s*;', call), call
    assert 'TRUE' not in call

assert 'ENUM_TIMEOUT_100NS       300000000ULL' in s
for forbidden in ('BS->Stall', 'LocateHandleBuffer', 'POLL_COUNT', 'POLL_INTERVAL'):
    assert forbidden not in s, forbidden

# v9.3 topology policy: explicit FRONT / DOM / UNKNOWN.
for token in ('BRIDGE_LOCATION_FRONT', 'BRIDGE_LOCATION_DOM', 'BRIDGE_LOCATION_UNKNOWN',
              'classify_bridge_location', 'if (bridge_location == BRIDGE_LOCATION_DOM)'):
    assert token in s, token
assert 'if (!bridge_on_front)' not in s

# UNKNOWN is conservative rear-direct, never silently treated as DOM.
assert 'bridge_location == BRIDGE_LOCATION_DOM' in s

# Existing SimpleFS handles below Etron are scanned once after connection,
# then protocol notification remains the event-driven path for later handles.
assert 'scan_existing_rear_filesystems' in s
assert re.search(r'connect_rear_stack\(etron, xhci_driver\).*?scan_existing_rear_filesystems', s, re.S)

# If LoadImage creates a child despite SECURITY_VIOLATION, unload it.
assert 'if (st == EFI_SECURITY_VIOLATION && child != NULL)' in s
assert 'BS->UnloadImage' in s

# A returned bootloader never counts as successful handoff: try another candidate.
assert 'EFI_ABORTED' in s
assert 'StartImage returned' in s

# Candidate-local failures include EFI_ABORTED so one bad loader/port cannot block another.
assert re.search(r'candidate_failure_is_local.*?EFI_ABORTED', s, re.S)

# Still no persistent boot policy or arbitrary EFI scans.
assert 'EFI_VARIABLE_NON_VOLATILE' not in s
assert 'BootOrder' not in s
assert 'BootNext' not in s
for forbidden in ('shimx64', 'grubx64', 'systemd-bootx64', 'REAR_PORT', 'USB_PORT_1', 'USB_PORT_2'):
    assert forbidden not in s, forbidden

print('V93_STATIC_TESTS=PASS')
