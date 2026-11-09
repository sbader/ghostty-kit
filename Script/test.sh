#!/bin/bash
# Applies both patch queues to Ghostty at Ghostty.ref and runs the Zig tests
# the queue carries. Runs on Linux and macOS.

set -euo pipefail

cd "$(dirname "$0")/.."

ROOT_DIR=$(pwd)
SOURCE_DIR="$ROOT_DIR/.build/ghostty"
GHOSTTY_REF=$(tr -d '[:space:]' < Ghostty.ref)

if [ "${1:-}" = "--source" ]; then
    SOURCE_DIR="$2"
fi

if [ "$SOURCE_DIR" = "$ROOT_DIR/.build/ghostty" ]; then
    ./Script/fetch-ghostty.sh "$SOURCE_DIR"
elif [ "$(git -C "$SOURCE_DIR" rev-parse HEAD)" != "$GHOSTTY_REF" ]; then
    echo "[!] $SOURCE_DIR is not at Ghostty.ref ($GHOSTTY_REF)"
    exit 1
fi

# sandbox-manager applies Patches/vt to a clean tree with patch(1).
CLEAN_DIR=$(mktemp -d)
trap 'rm -rf "$CLEAN_DIR"' EXIT
git -C "$SOURCE_DIR" archive "$GHOSTTY_REF" | tar -x -C "$CLEAN_DIR"
for patch_file in Patches/vt/*.patch; do
    patch --dry-run --batch --forward --fuzz=0 -d "$CLEAN_DIR" -p1 < "$patch_file" >/dev/null
    echo "[+] applies cleanly: $patch_file"
done

export ZIG_GLOBAL_CACHE_DIR="${ZIG_GLOBAL_CACHE_DIR:-$ROOT_DIR/.build/cache/zig-global}"
./Script/apply-patches.sh "$SOURCE_DIR"

# Every patch is idempotent; a second run must leave the tree unchanged.
before=$({ git -C "$SOURCE_DIR" status --porcelain; git -C "$SOURCE_DIR" diff; } | shasum -a 256)
./Script/apply-patches.sh "$SOURCE_DIR" >/dev/null
after=$({ git -C "$SOURCE_DIR" status --porcelain; git -C "$SOURCE_DIR" diff; } | shasum -a 256)
if [ "$before" != "$after" ]; then
    echo "[!] a second apply-patches run changed the source tree"
    exit 1
fi
echo "[+] patch queue is idempotent"

(
    cd "$SOURCE_DIR"
    zig build test \
        -Dtest-filter='replay response' \
        -Dtest-filter='DesktopNotification init' \
        -Dtest-filter='synchronized output' \
        -Dtest-filter='semantic prompt' \
        -Dtest-filter='prompt redraw hold' \
        -Dtest-filter='restoration effects' \
        -Dapp-runtime=none \
        -Demit-exe=false \
        -Demit-xcframework=false \
        -Demit-macos-app=false \
        -Dsentry=false \
        -Dcustom-shaders=false \
        -Dinspector=false \
        -Dsimd=false \
        --summary failures
)
echo "[+] zig tests passed"
