#!/bin/bash
# Pins Ghostty.ref to a Ghostty ref (default: main) and checks the patch
# queues against it.

set -euo pipefail

cd "$(dirname "$0")/.."

REF=${1:-main}

if [[ "$REF" =~ ^[0-9a-f]{40}$ ]]; then
    SHA=$REF
else
    SHA=$(git ls-remote https://github.com/ghostty-org/ghostty "$REF" | awk 'NR == 1 { print $1 }')
fi
if [ -z "$SHA" ]; then
    echo "[!] no Ghostty ref named $REF"
    exit 1
fi

PREVIOUS=$(tr -d '[:space:]' < Ghostty.ref)
if [ "$SHA" = "$PREVIOUS" ]; then
    echo "[*] already on Ghostty $SHA"
else
    echo "$SHA" > Ghostty.ref
    echo 1 > Ghostty.build
    echo "[*] Ghostty $PREVIOUS -> $SHA"
fi

./Script/fetch-ghostty.sh "$PWD/.build/ghostty"

# The workflows' setup-zig version must meet Ghostty's minimum.
REQUIRED=$(sed -nE 's/.*\.minimum_zig_version = "([^"]+)".*/\1/p' .build/ghostty/build.zig.zon)
PINNED=$(sed -nE 's/^ +version: ([0-9.]+)$/\1/p' .github/workflows/test.yml)
if [ "$(printf '%s\n' "$REQUIRED" "$PINNED" | sort -V | head -1)" != "$REQUIRED" ]; then
    echo "[!] Ghostty needs Zig ${REQUIRED}; the workflows pin $PINNED"
fi

./Script/test.sh
