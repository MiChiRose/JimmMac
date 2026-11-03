#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-$ROOT/build}"
mkdir -p "$BUILD_DIR"
xcrun --sdk macosx clang -arch x86_64 -mmacosx-version-min=10.8 -fobjc-arc -fblocks \
  -Wall -Wextra -Wno-unused-parameter -Wno-deprecated-declarations -framework Foundation -framework Security \
  -I "$ROOT/Sources" "$ROOT/Tests/HTTPTests.m" "$ROOT/Sources/JMHTTPClient.m" "$ROOT/Sources/JMGitHubTrust.m" -o "$BUILD_DIR/HTTPTests"
"$BUILD_DIR/HTTPTests"
