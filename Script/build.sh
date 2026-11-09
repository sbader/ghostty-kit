#!/bin/bash

set -euo pipefail

cd "$(dirname "$0")/.."

usage() {
    cat <<'EOF'
Usage: Script/build.sh [options]

Options:
  --source <path>          Use an existing Ghostty checkout at Ghostty.ref.
  --platforms <csv>        Build platform groups (macos, ios). Default: macos,ios
  -h, --help               Show this help.

Outputs .build/GhosttyKit.xcframework and .build/GhosttyKit.xcframework.zip.
EOF
}

ROOT_DIR=$(pwd)
SOURCE_DIR="$ROOT_DIR/.build/ghostty"
PLATFORMS="macos,ios"
GHOSTTY_REF=$(tr -d '[:space:]' < Ghostty.ref)

while [ $# -gt 0 ]; do
    case "$1" in
        --source)
            SOURCE_DIR="$2"
            shift 2
            ;;
        --platforms)
            PLATFORMS="$2"
            shift 2
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            echo "[!] unknown argument: $1"
            usage
            exit 1
            ;;
    esac
done

if ! command -v zig >/dev/null 2>&1; then
    echo "[!] Zig not found. Install it and try again."
    exit 1
fi

if ! xcrun -sdk macosx metal --version >/dev/null 2>&1; then
    echo "[!] Metal toolchain not found. Run: xcodebuild -downloadComponent MetalToolchain"
    exit 1
fi

if [ "$SOURCE_DIR" = "$ROOT_DIR/.build/ghostty" ]; then
    ./Script/fetch-ghostty.sh "$SOURCE_DIR"
elif [ "$(git -C "$SOURCE_DIR" rev-parse HEAD)" != "$GHOSTTY_REF" ]; then
    echo "[!] $SOURCE_DIR is not at Ghostty.ref ($GHOSTTY_REF)"
    exit 1
fi

ARTIFACTS_DIR="$ROOT_DIR/.build/artifacts"
XCFRAMEWORK_PATH="$ROOT_DIR/.build/GhosttyKit.xcframework"
XCFRAMEWORK_ZIP="$ROOT_DIR/.build/GhosttyKit.xcframework.zip"

rm -rf "$ARTIFACTS_DIR" "$XCFRAMEWORK_PATH" "$XCFRAMEWORK_ZIP"
mkdir -p "$ARTIFACTS_DIR"

echo "[*] zig version: $(zig version)"
echo "[*] Ghostty source: $SOURCE_DIR"
echo "[*] platform groups: $PLATFORMS"

IFS=',' read -ra PLATFORM_GROUPS <<<"$PLATFORMS"

# :- yields one empty word for an empty array, which the guard below drops.
# Without it, macOS bash 3.2 aborts on "${PLATFORM_GROUPS[@]}" under set -u.
for platform_group in "${PLATFORM_GROUPS[@]:-}"; do
    platform_group=$(echo "$platform_group" | xargs)
    [ -n "$platform_group" ] || continue
    ./Script/build-platform.sh "$SOURCE_DIR" "$platform_group" "$ARTIFACTS_DIR"
done

./Script/merge-xcframework.sh \
    "$ARTIFACTS_DIR" \
    "$XCFRAMEWORK_PATH" \
    "$XCFRAMEWORK_ZIP"

echo "[*] xcframework: $XCFRAMEWORK_PATH"
echo "[*] zip: $XCFRAMEWORK_ZIP"
