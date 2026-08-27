from pathlib import Path
import re

ROOT = Path(__file__).resolve().parent
s = (ROOT / "DS713Bridge-v9.1.c").read_text()

# Controller/loader invariants.
for token in (
    "0x1B6F", "0x7023",
    r'\\EFI\\DS713\\XhciDxe.efi',
    r'\\EFI\\BOOT\\BOOTX64.EFI',
    "RegisterProtocolNotify", "ByRegisterNotify", "WaitForEvent",
    "PciIoProtocol", "FileSystemProtocol", "LoadedImageProtocol",
):
    assert token in s, token

# Same key must distinguish front USB(1,...) from DOM USB(0,...).
for token in (
    "DS713_EHCI_PCI_DEVICE    0x1D",
    "DS713_EHCI_PCI_FUNCTION  0x07",
    "DS713_FRONT_USB_PORT     0x01",
    "is_ds713_front_usb",
    "bridge_on_front",
    "if (!bridge_on_front)",
    "try_front_bootable",
):
    assert token in s, token

# Self recursion is blocked by handle OR exact device-path equality.
assert "static BOOLEAN\nsame_device" in s
assert "if (a == b)" in s
assert "a_size != b_size" in s
assert "bytes_equal((const UINT8 *)a_path" in s
assert "same_device(handle, bridge_device)" in s

# Broad 'any visible USB filesystem' policy is gone.
assert "device_path_has_usb_node" not in s
assert "try_visible_usb_bootables" not in s

# Rear ports remain dynamic; no rear port child is hard-coded.
for forbidden in (
    "REAR_PORT", "USB_PORT_1", "USB_PORT_2",
    "RemainingDevicePathUsb", "DEBIAN", "shimx64",
):
    assert forbidden not in s, forbidden

# Validated fast xHCI connection invariant: exactly two, never recursive.
calls = re.findall(r"uefi_call_wrapper\(BS->ConnectController,\s*4,.*?\);", s, re.S)
assert len(calls) == 2, len(calls)
for call in calls:
    assert re.search(r",\s*FALSE\s*\)\s*;", call), call
    assert "TRUE" not in call

# Event driven, no polling, 30 s failure ceiling only.
assert "ENUM_TIMEOUT_100NS       300000000ULL" in s
for forbidden in ("BS->Stall", "LocateHandleBuffer", "POLL_COUNT", "POLL_INTERVAL"):
    assert forbidden not in s, forbidden

# Broken device on one rear port must not block the other.
for status in (
    "EFI_NOT_FOUND", "EFI_NO_MEDIA", "EFI_MEDIA_CHANGED", "EFI_DEVICE_ERROR",
    "EFI_LOAD_ERROR", "EFI_UNSUPPORTED", "EFI_SECURITY_VIOLATION", "EFI_ACCESS_DENIED",
):
    assert status in s, status

# Debug timings are volatile only; never write persistent boot policy.
assert "DS713V91Timing" in s
assert "EFI_VARIABLE_NON_VOLATILE" not in s
assert "BootOrder" not in s
assert "BootNext" not in s

print("V91_STATIC_TESTS=PASS")
