#!/usr/bin/env python3
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]

def read(p): return (root / p).read_text()

def need(cond, msg):
    if not cond: raise SystemExit(msg)

profile = read('profiles/ds713plus.env')
need('BIOS_START=0x011000' in profile and 'BIOS_END=0x210fff' in profile, 'profile BIOS bounds changed')
need('ERASE_BLOCK_BYTES=4096' in profile, 'profile erase size changed')

need(read('VERSION').strip() == '0.2.0', 'VERSION must be 0.2.0')
need('version: 0.2.0' in read('CITATION.cff'), 'CITATION version mismatch')

required = [
    'README.md','README.fr.md','docs/QUICKSTART.md','docs/QUICKSTART.fr.md',
    'docs/USB3-BRIDGE.md','docs/USB3-BRIDGE.fr.md','docs/USB-BOOT.md','docs/USB-BOOT.fr.md',
    'docs/VERIFIED-HARDWARE.md','docs/VERIFIED-HARDWARE.fr.md',
    'bridge/DS713Bridge-v9.1.c','scripts/10-create-usb3-bridge.sh'
]
for p in required: need((root/p).is_file(), f'missing {p}')

for p in ['README.md','docs/USB-BOOT.md','docs/VERIFIED-HARDWARE.md','docs/OS-OPTIONS.md']:
    s=read(p)
    need('F400-only' in s or 'F400 patch only' in s or 'F400 patch alone' in s or 'F400 firmware patch alone' in s, f'{p}: F400-only distinction missing')
    need('DS713Bridge v9.1' in s, f'{p}: v9.1 result missing')

for p in ['README.fr.md','docs/USB-BOOT.fr.md','docs/VERIFIED-HARDWARE.fr.md','docs/OS-OPTIONS.fr.md']:
    s=read(p)
    need('F400' in s and 'DS713Bridge v9.1' in s, f'{p}: distinction/result missing')

for stale in [
    'Rear USB 3.0 port #1 | ❌ Does not boot',
    'Rear USB 3.0 port #2 | ❌ Does not boot',
    'USB 3.0 arrière Etron #1 | ❌ Ne boote pas',
    'USB 3.0 arrière Etron #2 | ❌ Ne boote pas',
    'Adding/testing an EFI xHCI driver is a separate future experiment',
    "L'ajout/test d'un driver EFI xHCI constitue une expérience future séparée",
]:
    for p in required[:2] + ['docs/USB-BOOT.md','docs/USB-BOOT.fr.md']:
        need(stale not in read(p), f'stale statement in {p}: {stale}')

bridge = read('docs/USB3-BRIDGE.md')
need('2c5a336e52a3d89bcf8029c85818ecbeb2a9477c6dd8367227c7027b5cc833ac' in bridge, 'v9.1 known-good hash missing')
need('20c3dbda0e0720fe171a7c0b06c995c4fe319f7338acfb75e9b5ee271a3092b3' in bridge, 'Xhci known-good hash missing')
need('both physical rear connectors were not independently re-run A-to-Z' in bridge, 'port-evidence caveat missing')

writer=read('scripts/10-create-usb3-bridge.sh')
for token in ['SDX','REFUS: TARGET = disque système','cible non USB','REAR_PORT_HARDCODE=ZERO','NVRAM_BOOT_POLICY_WRITES=ZERO']:
    need(token in writer, f'writer invariant missing: {token}')

build=read('scripts/00-build-flashrom.sh')
need('08ed5ccde46679998fa4ae21346e755b4451617f70348bacdf872b636f55b708' in build, 'pciutils source hash missing')
need('89a7ff5beb08c89b8795bbd253a51b9453547a864c31793302296b56bbc56d65' in build, 'flashrom source hash missing')

print('REPO_CONSISTENCY_TESTS=PASS')
