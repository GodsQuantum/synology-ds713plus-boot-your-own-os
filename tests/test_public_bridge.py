#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts/10-create-usb3-bridge.sh"
if not SCRIPT.exists():
    SCRIPT = ROOT / "create-ds713-usb3-bridge.sh"
SRC = ROOT / "bridge/DS713Bridge-v9.1.c"
if not SRC.exists():
    SRC = ROOT / "DS713Bridge-v9.1.c"


def require(cond, msg):
    if not cond:
        raise AssertionError(msg)


def main():
    require(SCRIPT.exists(), "writer script missing")
    require(SRC.exists(), "V9.1 source missing")

    s = SCRIPT.read_text()
    c = SRC.read_text()

    require('TARGET="${TARGET:-${SDX:-${1:-}}}"' in s, "TARGET=/dev/sdX, SDX=sdb or argv support missing")
    require('TARGET="/dev/$TARGET"' in s, "bare SDX name normalization missing")
    require('EXPECTED_SERIAL=' not in s, "public writer must not hardcode one USB serial")
    require('TRAN' in s and 'usb' in s, "USB transport safety guard missing")
    require('ROOTDISK' in s and 'REFUS' in s, "root-disk safety guard missing")
    require('STABLE-V91.EFI' in s, "must recover exact stable V9.1 from harness media")
    require('XhciDxe.efi' in s, "XhciDxe installation missing")
    require('2c5a336e52a3d89bcf8029c85818ecbeb2a9477c6dd8367227c7027b5cc833ac' in s,
            "validated V9.1 hash missing")
    require('20c3dbda0e0720fe171a7c0b06c995c4fe319f7338acfb75e9b5ee271a3092b3' in s,
            "validated Xhci hash missing")
    require('ecb9726a4ecd6ce1fe39874b6b8a0e9374bfdcaa08da77fbb3de827bae258e30' in s,
            "normalized Xhci reproducibility hash missing")
    require('edk2-stable202605' in s and 'b03a21a63e3bd001f52c527e5a57feddb53a690b' in s,
            "pinned EDK2 fallback build missing")
    require('wipefs --all --force "$TARGET"' in s, "destructive phase missing")
    require('\"$MKFS_FAT\" -F 32' in s, "FAT32 creation missing")
    require('startup.nsh' in s, "DOM shell fallback missing")
    require('test_v91_static.py' in s, "public writer must run the V9.1 invariant test when installed from the repo")
    require('START_DIR=' in s and 'cd "$START_DIR"' in s, "fallback EDK2 build must return to a valid working directory")
    require('sudo umount' not in s and 'sudo mount' not in s, "root script must not depend on sudo being installed")
    require('# shellcheck disable=SC1090' in s, "dynamic edksetup source needs ShellCheck suppression")
    require('MKFS_FAT=' in s and 'mkfs.fat' in s and 'mkfs.vfat' in s, "cross-distro mkfs FAT fallback missing")
    require('FSCK_FAT=' in s and 'fsck.fat' in s and 'fsck.vfat' in s, "cross-distro fsck FAT fallback missing")
    first_dep = s.split('===== 1. SECURITE CIBLE =====', 1)[0]
    require('for cmd in gcc ' not in first_dep, "compiler must not be mandatory when exact binaries are recoverable")
    require('BootOrder' not in c and 'BootNext' not in c, "V9.1 source must not depend on BootOrder/BootNext")
    require('ETRON_VENDOR_ID' in c and 'ETRON_EJ168_DEVICE_ID' in c, "Etron discovery missing")
    import re
    calls = re.findall(r'uefi_call_wrapper\(BS->ConnectController,\s*4,.*?\);', c, re.S)
    require(len(calls) == 2, f'V9.1 must preserve exactly two ConnectController calls, got {len(calls)}')
    require('FALSE' in c, "non-recursive connect invariant missing")
    require('\\\\EFI\\\\BOOT\\\\BOOTX64.EFI' in c, "standard removable loader path missing")
    require('DS713_FRONT_USB_PORT' in c, "front/DOM location policy missing")

    print('PUBLIC_BRIDGE_STATIC_TESTS=PASS')


if __name__ == '__main__':
    main()
