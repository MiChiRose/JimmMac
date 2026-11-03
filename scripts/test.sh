#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-$PROJECT_ROOT/build}"
mkdir -p "$BUILD_DIR"
xcrun --sdk macosx clang -arch x86_64 -mmacosx-version-min=10.8 -fobjc-arc -fblocks \
    -Wall -Wextra -Wno-unused-parameter -Wno-deprecated-declarations -framework Foundation -framework Security -lsqlite3 \
    -I "$PROJECT_ROOT/Sources" "$PROJECT_ROOT/Tests/ProtocolTests.m" \
    "$PROJECT_ROOT/Sources/JMProtocol.m" "$PROJECT_ROOT/Sources/JMHistory.m" "$PROJECT_ROOT/Sources/JMAccountData.m" "$PROJECT_ROOT/Sources/JMLocalization.m" "$PROJECT_ROOT/Sources/JMDraftStore.m" "$PROJECT_ROOT/Sources/JMLoginStore.m" \
    "$PROJECT_ROOT/Sources/JMAPIClient.m" "$PROJECT_ROOT/Sources/JMHTTPClient.m" "$PROJECT_ROOT/Sources/JMGitHubTrust.m" "$PROJECT_ROOT/Sources/JMTextTools.m" "$PROJECT_ROOT/Sources/JMUpdateChecker.m" -o "$BUILD_DIR/ProtocolTests"
"$BUILD_DIR/ProtocolTests"
JIMMMAC_TEST_LEGACY_TRANSPORT=1 "$BUILD_DIR/ProtocolTests"
BUILD_DIR="$BUILD_DIR" bash "$PROJECT_ROOT/scripts/test-http.sh"
