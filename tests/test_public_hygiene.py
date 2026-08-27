#!/usr/bin/env python3

from pathlib import Path
import re
import subprocess

patterns = {
    "absolute user-home path": re.compile(
        r"/(?:home|Users)/[A-Za-z0-9._-]+/"
    ),
    "numeric private IPv4 address": re.compile(
        r"(?<![\d.])(?:"
        r"10(?:\.\d{1,3}){3}|"
        r"192\.168(?:\.\d{1,3}){2}|"
        r"172\.(?:1[6-9]|2\d|3[01])(?:\.\d{1,3}){2}"
        r")(?![\d.])"
    ),
    "MAC address": re.compile(
        r"(?i)(?<![0-9a-f])(?:[0-9a-f]{2}:){5}[0-9a-f]{2}(?![0-9a-f])"
    ),
    "private-key header": re.compile(
        r"-----BEGIN (?:OPENSSH |RSA |EC |DSA )?PRIVATE KEY-----"
    ),
}

paths = subprocess.check_output(
    ["git", "ls-files", "-co", "--exclude-standard", "-z"]
).split(b"\0")

failures = []

for raw in paths:
    if not raw:
        continue

    path = Path(raw.decode())

    try:
        text = path.read_text()
    except (UnicodeDecodeError, IsADirectoryError):
        continue

    for lineno, line in enumerate(text.splitlines(), 1):
        for kind, rx in patterns.items():
            if rx.search(line):
                failures.append((str(path), lineno, kind))

if failures:
    for path, line, kind in failures:
        print(f"PUBLIC_HYGIENE_FAIL {path}:{line}: {kind}")
    raise SystemExit(1)

print("PUBLIC_HYGIENE=PASS")
