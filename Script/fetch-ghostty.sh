#!/bin/bash
# Puts <dir> at Ghostty.ref with tracked files pristine, ready for the patch
# queue. Only for checkouts this repo owns: local changes are discarded.

set -euo pipefail

cd "$(dirname "$0")/.."

SOURCE_DIR=${1:?Usage: $0 <dir>}
GHOSTTY_REF=$(tr -d '[:space:]' < Ghostty.ref)

if [ ! -d "$SOURCE_DIR/.git" ]; then
    mkdir -p "$SOURCE_DIR"
    git -C "$SOURCE_DIR" init -q
    git -C "$SOURCE_DIR" remote add origin https://github.com/ghostty-org/ghostty
fi

if [ "$(git -C "$SOURCE_DIR" rev-parse -q --verify HEAD || true)" != "$GHOSTTY_REF" ]; then
    echo "[*] fetching Ghostty ${GHOSTTY_REF}…"
    git -C "$SOURCE_DIR" fetch -q --depth 1 origin "$GHOSTTY_REF"
    git -C "$SOURCE_DIR" checkout -q --force --detach FETCH_HEAD
fi

# zig-pkg/ is gitignored and kept: its packages are patched in place (0017).
git -C "$SOURCE_DIR" reset -q --hard
git -C "$SOURCE_DIR" clean -q -fd
