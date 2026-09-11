#!/usr/bin/env python3

from pathlib import Path
import re
import subprocess

patterns = {
    "absolute user-home path": re.compile(
        r"/(?:home|Users)/[A-Za-z0-9._-]+/"
    ),
    "concrete IPv4 address": re.compile(
        r"(?<![\d.])(?:\d{1,3}\.){3}\d{1,3}(?![\d.])"
    ),
    "email address": re.compile(
        r"(?i)\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b"
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

# The current published commit must also avoid a real email address.
allowed_git_email = re.compile(r"^(?:[0-9]+\+[^@]+@users\.noreply\.github\.com|noreply@github\.com)$", re.I)
head_emails = subprocess.check_output(
    ["git", "log", "-1", "HEAD", "--format=%ae%n%ce"], text=True
).splitlines()
bad_head_emails = sorted({e for e in head_emails if e and not allowed_git_email.fullmatch(e)})
if bad_head_emails:
    for email in bad_head_emails:
        print(f"PUBLIC_HYGIENE_FAIL HEAD: non-noreply author/committer email: {email}")
    raise SystemExit(1)

print("PUBLIC_HEAD_IDENTITY=PASS")
print("PUBLIC_HYGIENE=PASS")
