#!/bin/bash
# Stages a copy of Zig's lib/ with Patches/zig/<zig version>-ios-std.patch
# applied and prints its path for ZIG_LIB_DIR. The toolchain is never edited.
#
# Zig 0.17.0's `Io.Threaded` does not compile for iOS: `processReplace`
# reaches `getDevNullFd`, and `NullFile` has no `fd` there. The patch sets
# `process.can_replace` false on those tags, as `can_spawn` already is.

set -euo pipefail

cd "$(dirname "$0")/.."

CACHE_ROOT=${1:?Usage: $0 <cache_root>}
ZIG_VERSION=$(zig version)
PATCH_FILE="$(pwd)/Patches/zig/$ZIG_VERSION-ios-std.patch"

if [ ! -f "$PATCH_FILE" ]; then
    echo "[!] no std patch for Zig $ZIG_VERSION: $PATCH_FILE" >&2
    exit 1
fi

# `zig env` prints ZON.
SOURCE_LIB_DIR=$(zig env | sed -n -E 's/^ *\.lib_dir *= *"([^"]+)".*$/\1/p' | head -n 1)
if [ -z "$SOURCE_LIB_DIR" ] || [ ! -d "$SOURCE_LIB_DIR/std" ]; then
    echo "[!] could not locate the Zig lib directory (lib_dir=$SOURCE_LIB_DIR)" >&2
    exit 1
fi

STAGED_LIB_DIR="$CACHE_ROOT/zig-lib/$ZIG_VERSION-ios-std"
STAMP="$STAGED_LIB_DIR/.ghostty-kit-patch"

if [ -f "$STAMP" ] && cmp -s "$STAMP" "$PATCH_FILE"; then
    echo "[*] patched Zig lib already staged: $STAGED_LIB_DIR" >&2
    echo "$STAGED_LIB_DIR"
    exit 0
fi

rm -rf "$STAGED_LIB_DIR"
mkdir -p "$(dirname "$STAGED_LIB_DIR")"
cp -R "$SOURCE_LIB_DIR" "$STAGED_LIB_DIR"
if ! patch -p1 --batch --fuzz=0 -d "$STAGED_LIB_DIR" <"$PATCH_FILE" >/dev/null; then
    echo "[!] Zig std patch does not apply to $SOURCE_LIB_DIR: $PATCH_FILE" >&2
    rm -rf "$STAGED_LIB_DIR"
    exit 1
fi
cp "$PATCH_FILE" "$STAMP"

echo "[*] staged patched Zig $ZIG_VERSION lib: $STAGED_LIB_DIR" >&2
echo "$STAGED_LIB_DIR"
