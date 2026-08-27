#!/usr/bin/env python3

from hashlib import sha256
from pathlib import Path
import subprocess

paths = sorted(
    raw.decode()
    for raw in subprocess.check_output(
        ["git", "ls-files", "-co", "--exclude-standard", "-z"]
    ).split(b"\0")
    if raw and raw.decode() != "MANIFEST.sha256"
)

actual = "".join(
    f"{sha256(Path(path).read_bytes()).hexdigest()}  {path}\n"
    for path in paths
)

expected = Path("MANIFEST.sha256").read_text()

if actual != expected:
    raise SystemExit("MANIFEST_SHA256=FAIL")

print("MANIFEST_SHA256=PASS")
