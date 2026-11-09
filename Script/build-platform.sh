#!/bin/bash

set -euo pipefail

cd "$(dirname "$0")/.."

SOURCE_DIR=${1:-}
PLATFORM_GROUP=${2:-}
OUTPUT_DIR=${3:-}

if [ -z "$SOURCE_DIR" ] || [ -z "$PLATFORM_GROUP" ] || [ -z "$OUTPUT_DIR" ]; then
    echo "Usage: $0 <source_dir> <platform_group> <output_dir>"
    exit 1
fi

if [ ! -d "$SOURCE_DIR" ]; then
    echo "[!] Ghostty source directory not found: $SOURCE_DIR"
    exit 1
fi

build_variant() {
    local variant_name="$1"
    shift

    local variant_dir="$OUTPUT_DIR/$variant_name"
    local intermediate_dir="$OUTPUT_DIR/.intermediates/$variant_name"
    local first_headers=
    local libraries=()
    local target_spec=
    local target=
    local cpu=

    rm -rf "$variant_dir" "$intermediate_dir"
    mkdir -p "$variant_dir/lib" "$variant_dir/include" "$intermediate_dir"

    for target_spec in "$@"; do
        target=${target_spec%%@*}
        cpu=
        if [ "$target_spec" != "$target" ]; then
            cpu=${target_spec#*@}
        fi

        local target_dir="$intermediate_dir/$target"
        if [ -n "$cpu" ]; then
            env ZIG_CPU="$cpu" ./Script/build-ghostty.sh "$SOURCE_DIR" "$target" "$target_dir"
        else
            ./Script/build-ghostty.sh "$SOURCE_DIR" "$target" "$target_dir"
        fi
        libraries+=("$target_dir/lib/libghostty.a")
        if [ -z "$first_headers" ]; then
            first_headers="$target_dir/include"
        fi
    done

    if [ -z "$first_headers" ]; then
        echo "[!] no libraries were built for variant: $variant_name"
        exit 1
    fi

    cp -R "$first_headers/." "$variant_dir/include/"

    if [ "${#libraries[@]}" -eq 1 ]; then
        cp "${libraries[0]}" "$variant_dir/lib/libghostty.a"
    else
        lipo -create "${libraries[@]}" -output "$variant_dir/lib/libghostty.a"
    fi

    echo "[*] assembled variant: $variant_name"
}

mkdir -p "$OUTPUT_DIR"

case "$PLATFORM_GROUP" in
    macos)
        build_variant "macosx" \
            "aarch64-macos"
        ;;
    ios)
        build_variant "iphoneos" \
            "aarch64-ios"
        build_variant "iphonesimulator" \
            "aarch64-ios-simulator@apple_a17"
        ;;
    *)
        echo "[!] unknown platform group: $PLATFORM_GROUP. Expected one of: macos, ios"
        exit 1
        ;;
esac

echo "[*] built platform group: $PLATFORM_GROUP"
