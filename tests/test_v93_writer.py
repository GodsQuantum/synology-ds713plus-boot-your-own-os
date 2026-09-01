from pathlib import Path

p = Path(__file__).resolve().parents[1] / "scripts" / "11-create-usb3-bridge-v93.sh"
assert p.exists(), "v9.3 writer missing"
s = p.read_text()
for token in (
    "DS713Bridge-v9.3.c", "DS713V93", "Chemin du disque USB", "lsblk",
    "findmnt", "wipefs", "sfdisk", "fsck.fat", "ERASE-$TARGET",
):
    assert token in s, token
assert 'TARGET="${TARGET:-${SDX:-${1:-}}}"' in s
assert 'read -r -p "Chemin du disque USB' in s
assert 'XHCI_VALIDATED_SHA="20c3dbda0e0720fe171a7c0b06c995c4fe319f7338acfb75e9b5ee271a3092b3"' in s
for forbidden in ("/home/", "/Users/", "192.168.", "10.0.", "TARGET=/dev/sdb"):
    assert forbidden not in s, forbidden
print("V93_WRITER_STATIC_TESTS=PASS")
