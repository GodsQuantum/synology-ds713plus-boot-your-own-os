#!/usr/bin/env bash
set -Eeuo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ARTIFACTS="${ARTIFACTS:-$REPO_ROOT/artifacts}"
WORK="${WORK:-$REPO_ROOT/work}"
PROFILE="${PROFILE:-$REPO_ROOT/profiles/ds713plus.env}"
mkdir -p "$ARTIFACTS" "$WORK"
# shellcheck disable=SC1090
source "$PROFILE"

die(){ printf 'ERROR: %s\n' "$*" >&2; exit 1; }
info(){ printf '==> %s\n' "$*"; }
need(){ command -v "$1" >/dev/null 2>&1 || die "Missing command: $1"; }
sha(){ sha256sum "$1" | awk '{print $1}'; }
size(){ stat -c %s "$1"; }
need_remote(){ : "${NAS_HOST:?export NAS_HOST=...}"; : "${NAS_USER:?export NAS_USER=...}"; SSH_TARGET="${NAS_USER}@${NAS_HOST}"; REMOTE_WORK="${REMOTE_WORK:-/var/services/homes/${NAS_USER}/ds713-f400-unlock}"; }
raw_copy(){ local src="$1" dst="$2"; cat "$src" | ssh "$SSH_TARGET" "cat > '$dst'"; }
assert_file_size(){ [[ -f "$1" ]] || die "Missing file: $1"; [[ "$(size "$1")" == "$2" ]] || die "Unexpected size for $1: $(size "$1"), expected $2"; }
