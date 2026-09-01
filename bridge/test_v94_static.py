#!/usr/bin/env python3
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parent
SRC = ROOT / "DS713Bridge-v9.4.c"
assert SRC.exists(), "DS713Bridge-v9.4.c missing"
s = SRC.read_text()

required = (
    "DS713Bridge v9.4 FULL-STACK R2",
    "ETRON_VENDOR_ID           0x1B6F",
    "ETRON_EJ168_DEVICE_ID     0x7023",
    "EFI_DRIVER_BINDING_PROTOCOL",
    "Binding->Supported",
    "Binding->Start",
    r"\\EFI\\DS713V94\\drivers\\XhciDxe.efi",
    r"\\EFI\\DS713V94\\drivers\\UsbBusDxe.efi",
    r"\\EFI\\DS713V94\\drivers\\UsbMassStorageDxe.efi",
    r"\\EFI\\DS713V94\\drivers\\DiskIoDxe.efi",
    r"\\EFI\\DS713V94\\drivers\\PartitionDxe.efi",
    r"\\EFI\\DS713V94\\drivers\\EnglishDxe.efi",
    r"\\EFI\\DS713V94\\drivers\\Fat.efi",
    r"\\EFI\\BOOT\\BOOTX64.EFI",
    "TryRearFilesystems",
    "gBS->LoadImage (TRUE",
    "gBS->SetWatchdogTimer (300",
)
for token in required:
    assert token in s, token

# v9.4 deliberately bypasses the old Granite Well upper USB/storage stack by
# starting modern EDK2 Driver Binding instances itself. Do not regress to the
# v9.1 ConnectController-only model here.
assert "ConnectController" not in s

# Full stack composition is intentional and physically validated with a rear SSD.
for name in (
    "XhciDxe", "UsbBusDxe", "UsbMassStorageDxe", "DiskIoDxe",
    "PartitionDxe", "EnglishDxe", "Fat"
):
    assert name in s, name

# No persistent boot policy or OS-specific loader probing.
for forbidden in (
    "BootOrder", "BootNext", "shimx64", "grubx64", "bootmgfw",
    "systemd-boot", "limine", "refind", "192.168.", "/home/", "/Users/"
):
    assert forbidden.lower() not in s.lower(), forbidden

# OS LoadImage uses BootPolicy=TRUE and a returned loader is not manually
# unloaded after StartImage returns.
start = re.search(r"StartOsLoader\s*\(.*?^}", s, re.S | re.M)
assert start, "StartOsLoader missing"
body = start.group(0)
assert "gBS->LoadImage (TRUE" in body
assert "gBS->SetWatchdogTimer (300" in body
assert "gBS->StartImage" in body
post_start = body.split("gBS->StartImage", 1)[1]
assert "UnloadImage" not in post_start
assert "gBS->SetWatchdogTimer (0" in post_start

print("V94_STATIC_TESTS=PASS")
