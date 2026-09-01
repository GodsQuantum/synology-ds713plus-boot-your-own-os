from pathlib import Path

p = Path(__file__).resolve().parents[1] / "scripts" / "11-create-usb3-bridge-v93.sh"
assert p.exists(), "v9.3 writer missing"
s = p.read_text()

required = (
    "AUTONOMOUS BRIDGE KEY CREATOR",
    "DS713Bridge v9.3 candidate",
    "V93_SOURCE_GZ_B64",
    "base64 -d | gzip -dc",
    'V93_SOURCE_SHA="85a7d6961825b1e9775d015727ac28aef2d2301517b9220f9eb874e4e911af6a"',
    'XHCI_VALIDATED_SHA="20c3dbda0e0720fe171a7c0b06c995c4fe319f7338acfb75e9b5ee271a3092b3"',
    'XHCI_NORMALIZED_SHA="ecb9726a4ecd6ce1fe39874b6b8a0e9374bfdcaa08da77fbb3de827bae258e30"',
    'EDK_TAG="edk2-stable202605"',
    'EDK_COMMIT="b03a21a63e3bd001f52c527e5a57feddb53a690b"',
    "Numéro OU chemin (/dev/sdX)",
    "recover_xhci_from_target",
    "build_xhci",
    "ERASE-$TARGET",
    "DOM_DESIGN_SUPPORT=YES",
    "DOM_PHYSICAL_VALIDATION=PENDING",
    "--self-test",
)
for token in required:
    assert token in s, token

for forbidden in (
    'BRIDGE_SOURCE="$HERE/../bridge/',
    'V93_TEST="$HERE/../bridge/',
    "test_v93_static.py",
    "/home/",
    "/Users/",
    "192.168.",
    "10.0.",
    "TARGET=/dev/sdb",
):
    assert forbidden not in s, forbidden

assert "(( size > 0 )) || continue" in s
print("V93_WRITER_AUTONOMOUS_TESTS=PASS")
