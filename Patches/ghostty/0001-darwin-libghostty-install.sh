#!/bin/bash

set -euo pipefail

SOURCE_DIR=${1:-}

if [ -z "$SOURCE_DIR" ]; then
    echo "[-] missing source_dir"
    exit 1
fi

BUILD_ZIG="$SOURCE_DIR/build.zig"
MARKER="libghostty static install for Darwin"

if [ ! -f "$BUILD_ZIG" ]; then
    echo "[-] build.zig not found: $BUILD_ZIG"
    exit 1
fi

if grep -Fq "$MARKER" "$BUILD_ZIG"; then
    echo "[+] patch already applied: 0001-darwin-libghostty-install"
    exit 0
fi

# Replaces upstream's non-Darwin guard, from its comment through the guard's
# closing brace, so Darwin installs the static archive too.
perl -0pi -e '
    s{        // We shouldn\x27t have this guard but we don\x27t currently\n.*?\n        \}\n}{        // libghostty static install for Darwin:
        // upstream only wires this for non-Darwin today, but we need the
        // static archive for our own XCFramework assembly pipeline.
        lib_shared.installHeader();
        if (config.target.result.os.tag.isDarwin()) {
            lib_static.install("libghostty.a");
        } else if (config.target.result.os.tag == .windows) {
            lib_shared.install("ghostty-internal.dll");
            lib_static.install("ghostty-internal-static.lib");
        } else {
            lib_shared.install("ghostty-internal.so");
            lib_static.install("ghostty-internal.a");
        }
}s
' "$BUILD_ZIG"

if ! grep -Fq "$MARKER" "$BUILD_ZIG"; then
    echo "[-] failed to apply patch: 0001-darwin-libghostty-install"
    exit 1
fi

echo "[+] applied patch: 0001-darwin-libghostty-install"
