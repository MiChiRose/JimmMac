#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ "${JIMMMAC_NATIVE_TESTS:-0}" == 1 ]]; then
    TARGET=(-arch "$(uname -m)" -mmacosx-version-min=11.0)
    DEFAULT_BUILD_DIR="$ROOT/build/native-tests"
else
    TARGET=(-arch x86_64 -mmacosx-version-min=10.8)
    DEFAULT_BUILD_DIR="$ROOT/build"
fi
BUILD_DIR="${BUILD_DIR:-$DEFAULT_BUILD_DIR}"
mkdir -p "$BUILD_DIR"
xcrun --sdk macosx clang "${TARGET[@]}" -fobjc-arc -fblocks \
  -Wall -Wextra -Wno-unused-parameter -Wno-deprecated-declarations -framework Foundation -framework Security \
  -I "$ROOT/Sources" "$ROOT/Tests/HTTPTests.m" "$ROOT/Sources/JMHTTPClient.m" "$ROOT/Sources/JMGitHubTrust.m" -o "$BUILD_DIR/HTTPTests"
"$BUILD_DIR/HTTPTests"
