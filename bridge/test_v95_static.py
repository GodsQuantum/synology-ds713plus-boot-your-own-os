#!/usr/bin/env python3
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parent
SRC = ROOT / "DS713Bridge-v9.5.c"
assert SRC.exists(), "DS713Bridge-v9.5.c missing"
s = SRC.read_text()

required = (
    "DS713Bridge v9.5 SATA-POWER + FULL-STACK R2",
    "INTEL_VENDOR_ID             0x8086",
    "LPC_GPIOBASE_OFFSET         0x48",
    "LPC_GPIOCTRL_OFFSET         0x4C",
    "LPC_GPIOCTRL_ENABLE         0x10",
    "GPIO_USE_SEL_OFFSET         0x00",
    "GPIO_IO_SEL_OFFSET          0x04",
    "GPIO_LVL_OFFSET             0x0C",
    "GPO_BLINK_OFFSET            0x18",
    "HDD1_GPIO                   16",
    "HDD2_GPIO                   20",
    "HDD_POWER_STAGGER_US        200000",
    "PciIo->GetLocation",
    "IoRead32",
    "IoWrite32",
    "EnableInternalHddPower",
    "ETRON_VENDOR_ID             0x1B6F",
    "ETRON_EJ168_DEVICE_ID       0x7023",
    "EFI_DRIVER_BINDING_PROTOCOL",
    "Binding->Supported",
    "Binding->Start",
    r"\\EFI\\DS713V94\\drivers\\XhciDxe.efi",
    r"\\EFI\\BOOT\\BOOTX64.EFI",
    "TryRearFilesystems",
    "gBS->LoadImage (TRUE",
    "gBS->SetWatchdogTimer (300",
)
for token in required:
    assert token in s, token

# The DS713+ hardware sequence must happen before rear USB discovery/chainload.
main = re.search(r"UefiMain\s*\(.*?^}", s, re.S | re.M)
assert main, "UefiMain missing"
body = main.group(0)
assert body.index("(VOID)EnableInternalHddPower ()") < body.index("FindEtron (&Etron)")
assert body.index("FindEtron (&Etron)") < body.index("LoadFullStack")
assert "return Status" not in body[body.index("(VOID)EnableInternalHddPower ()"):body.index("FindEtron (&Etron)")]

power = re.search(r"EnableInternalHddPower\s*\(.*?^}", s, re.S | re.M)
assert power, "EnableInternalHddPower missing"
p = power.group(0)
assert p.index("HDD1_GPIO") < p.index("HDD_POWER_STAGGER_US") < p.index("HDD2_GPIO")

# Safety: never repurpose pins whose USE_SEL is not already GPIO.
assert "if ((UseSel & Mask) == 0U)" in s
assert "return EFI_UNSUPPORTED" in s

# Preserve v9.4's full modern stack and avoid persistent boot policy changes.
assert "ConnectController" not in s
for forbidden in (
    "BootOrder", "BootNext", "shimx64", "grubx64", "bootmgfw",
    "systemd-boot", "limine", "refind", "SetVariable", "192.168.",
    "/home/", "/Users/"
):
    assert forbidden.lower() not in s.lower(), forbidden

start = re.search(r"StartOsLoader\s*\(.*?^}", s, re.S | re.M)
assert start, "StartOsLoader missing"
loader = start.group(0)
assert "gBS->LoadImage (TRUE" in loader
assert "gBS->SetWatchdogTimer (300" in loader
post_start = loader.split("gBS->StartImage", 1)[1]
assert "UnloadImage" not in post_start
assert "gBS->SetWatchdogTimer (0" in post_start

print("V95_STATIC_TESTS=PASS")
