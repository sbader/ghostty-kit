#!/bin/bash
# Prints the hash of every input that changes the built archive, so an
# xcframework can be matched to the checkout that produced it.
set -euo pipefail
cd "$(dirname "$0")/.."
{
    cat Ghostty.ref
    shasum -a 256 Patches/ghostty/* Patches/zig/* Script/prepare-zig-lib.sh Script/support/*.py Script/support/*.zig Script/build-ghostty.sh
} | shasum -a 256 | cut -d' ' -f1
