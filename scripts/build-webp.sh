#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="$ROOT/Vendor/libwebp"
OUTPUT="$1"
shift
WORK="$(mktemp -d "${TMPDIR:-/tmp}/jimmmac-webp.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
(
    cd "$WORK"
    xcrun --sdk macosx clang "$@" -std=c99 -O2 -DHAVE_CONFIG_H -I"$SOURCE" -c \
        "$SOURCE"/src/{dec,dsp,utils}/*.c
)
xcrun --sdk macosx libtool -static -o "$OUTPUT" "$WORK"/*.o
