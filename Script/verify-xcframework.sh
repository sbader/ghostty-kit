#!/bin/bash

set -euo pipefail

cd "$(dirname "$0")/.."
INPUT_PATH=${1:-}

if [ -z "$INPUT_PATH" ]; then
    echo "Usage: $0 <xcframework_or_zip>"
    exit 1
fi

if [ ! -e "$INPUT_PATH" ]; then
    echo "[!] not found: $INPUT_PATH"
    exit 1
fi

TEMP_DIR=
XCFRAMEWORK_PATH="$INPUT_PATH"

cleanup() {
    if [ -n "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}
trap cleanup EXIT

if [[ "$INPUT_PATH" == *.zip ]]; then
    TEMP_DIR=$(mktemp -d)
    ditto -x -k "$INPUT_PATH" "$TEMP_DIR"
    XCFRAMEWORK_PATH=$(find "$TEMP_DIR" -maxdepth 1 -name "*.xcframework" -type d | head -1)
fi

if [ ! -d "$XCFRAMEWORK_PATH" ]; then
    echo "[!] xcframework not found in input: $INPUT_PATH"
    exit 1
fi

EXPECTED_IDENTITY="$(./Script/artifact-identity.sh)"
if [ "$(cat "$XCFRAMEWORK_PATH/Ghostty.identity" 2>/dev/null)" != "$EXPECTED_IDENTITY" ]; then
    echo "[!] Ghostty.identity does not match this checkout; rebuild the xcframework."
    exit 1
fi

python3 - "$XCFRAMEWORK_PATH" <<'PY'
import os
import plistlib
import subprocess
import sys

xcframework = sys.argv[1]
info_path = os.path.join(xcframework, "Info.plist")

if not os.path.isfile(info_path):
    raise SystemExit(f"[!] missing xcframework Info.plist: {info_path}")

for root, dirs, _ in os.walk(xcframework):
    for directory in dirs:
        if directory.endswith(".framework"):
            raise SystemExit(f"[!] framework wrapper is not allowed in static-library xcframework: {os.path.join(root, directory)}")

with open(info_path, "rb") as handle:
    info = plistlib.load(handle)

# Functions the patch queue adds to the C API.
REQUIRED_SYMBOLS = (
    "ghostty_surface_apply_host_resize",
    "ghostty_surface_clear_tracked_selection",
    "ghostty_surface_frame_capture",
    "ghostty_surface_frame_capture_free",
    "ghostty_surface_frame_clear",
    "ghostty_surface_frame_submit",
    "ghostty_surface_link_at",
    "ghostty_surface_process_exit",
    "ghostty_surface_restore_snapshot",
    "ghostty_surface_select_word_at",
    "ghostty_surface_selection_viewport",
    "ghostty_surface_set_bottom_anchored",
    "ghostty_surface_set_host_authoritative_resize",
    "ghostty_surface_terminal_state",
    "ghostty_surface_track_selection",
    "ghostty_surface_tracked_selection",
    "ghostty_surface_write_buffer",
    "ghostty_surface_write_buffer_replay",
    "ghostty_surface_write_buffer_restoration",
)
seen_slices = set()

libraries = info.get("AvailableLibraries")
if not isinstance(libraries, list) or not libraries:
    raise SystemExit("[!] AvailableLibraries is empty or missing")

for library in libraries:
    identifier = library.get("LibraryIdentifier")
    library_path = library.get("LibraryPath")
    binary_path = library.get("BinaryPath")
    headers_path = library.get("HeadersPath")
    platform = library.get("SupportedPlatform")
    platform_variant = library.get("SupportedPlatformVariant")
    declared_architectures = set(library.get("SupportedArchitectures", []))

    if not identifier:
        raise SystemExit("[!] library entry missing LibraryIdentifier")
    if platform not in {"ios", "macos"}:
        raise SystemExit(f"[!] unsupported platform in {identifier}: {platform}")
    if library_path != "libghostty.a" or binary_path != "libghostty.a":
        raise SystemExit(f"[!] {identifier} must reference libghostty.a, got LibraryPath={library_path!r} BinaryPath={binary_path!r}")
    if headers_path != "Headers":
        raise SystemExit(f"[!] {identifier} must use HeadersPath=Headers, got {headers_path!r}")

    variant_dir = os.path.join(xcframework, identifier)
    archive_path = os.path.join(variant_dir, library_path)
    headers_dir = os.path.join(variant_dir, headers_path)
    header_path = os.path.join(headers_dir, "libghostty", "ghostty.h")
    modulemap_path = os.path.join(headers_dir, "libghostty", "module.modulemap")

    for required_path in (archive_path, header_path, modulemap_path):
        if not os.path.exists(required_path):
            raise SystemExit(f"[!] {identifier} missing required file: {required_path}")

    with open(header_path, encoding="utf-8") as handle:
        header = handle.read()
    for symbol in REQUIRED_SYMBOLS:
        if symbol + "(" not in header:
            raise SystemExit(f"[!] {identifier} header missing {symbol}")

    actual_architectures = set(
        subprocess.check_output(["lipo", "-archs", archive_path], text=True).split()
    )
    if actual_architectures != declared_architectures:
        raise SystemExit(
            f"[!] {identifier} architecture metadata mismatch: "
            f"plist={sorted(declared_architectures)} archive={sorted(actual_architectures)}"
        )

    expected_architectures = {
        ("macos", None): {"arm64"},
        ("ios", None): {"arm64"},
        ("ios", "simulator"): {"arm64"},
    }.get((platform, platform_variant))
    if expected_architectures is None:
        raise SystemExit(f"[!] unexpected slice {identifier}: {platform} {platform_variant}")
    seen_slices.add((platform, platform_variant))
    if actual_architectures != expected_architectures:
        raise SystemExit(
            f"[!] {identifier} architectures must be {sorted(expected_architectures)}, "
            f"got {sorted(actual_architectures)}"
        )

    for architecture in actual_architectures:
        symbols = subprocess.check_output(
            ["nm", "-arch", architecture, "-gU", archive_path], text=True
        )
        defined = {line.split()[-1] for line in symbols.splitlines() if line.split()}
        for symbol in REQUIRED_SYMBOLS:
            if "_" + symbol not in defined:
                raise SystemExit(f"[!] {identifier}/{architecture} archive missing {symbol}")
        # libintl is LGPL; 0021 and -Di18n=false keep it out of the archive.
        libintl = sorted(symbol for symbol in defined if "libintl_" in symbol)
        if libintl:
            raise SystemExit(f"[!] {identifier}/{architecture} archive links GNU libintl: {', '.join(libintl[:5])}")

    with open(modulemap_path, "r", encoding="utf-8") as handle:
        modulemap = handle.read()
    if "framework module libghostty" in modulemap:
        raise SystemExit(f"[!] {identifier} module map must not declare a framework module")
    if "module libghostty" not in modulemap:
        raise SystemExit(f"[!] {identifier} module map does not declare module libghostty")

expected_slices = {("macos", None), ("ios", None), ("ios", "simulator")}
if seen_slices != expected_slices:
    raise SystemExit(f"[!] slices must be {sorted(map(str, expected_slices))}, got {sorted(map(str, seen_slices))}")

print(f"[*] verified static-library xcframework layout and architectures: {xcframework}")
PY
