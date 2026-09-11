#!/usr/bin/env python3

from pathlib import Path
import json
import os
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

# The commit being proposed/published must avoid a real email address.
# On pull_request runs GitHub checks out a synthetic merge commit, so inspect
# the actual PR head SHA from the event payload instead.
allowed_git_email = re.compile(r"^(?:[0-9]+\+[^@]+@users\.noreply\.github\.com|noreply@github\.com)$", re.I)
target_commit = "HEAD"
event_path = os.environ.get("GITHUB_EVENT_PATH")
if event_path and Path(event_path).is_file():
    try:
        event = json.loads(Path(event_path).read_text())
        target_commit = event.get("pull_request", {}).get("head", {}).get("sha") or target_commit
    except (json.JSONDecodeError, OSError):
        pass
head_emails = subprocess.check_output(
    ["git", "log", "-1", target_commit, "--format=%ae%n%ce"], text=True
).splitlines()
bad_head_emails = sorted({e for e in head_emails if e and not allowed_git_email.fullmatch(e)})
if bad_head_emails:
    for email in bad_head_emails:
        print(f"PUBLIC_HYGIENE_FAIL HEAD: non-noreply author/committer email: {email}")
    raise SystemExit(1)

print("PUBLIC_HEAD_IDENTITY=PASS")
print("PUBLIC_HYGIENE=PASS")
