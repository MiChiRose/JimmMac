#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ "${JIMMMAC_NATIVE_TESTS:-0}" == 1 ]]; then
    TARGET=(-arch "$(uname -m)" -mmacosx-version-min=11.0)
    DEFAULT_BUILD_DIR="$PROJECT_ROOT/build/native-tests"
else
    TARGET=(-arch x86_64 -mmacosx-version-min=10.8)
    DEFAULT_BUILD_DIR="$PROJECT_ROOT/build"
fi
BUILD_DIR="${BUILD_DIR:-$DEFAULT_BUILD_DIR}"
mkdir -p "$BUILD_DIR"
xcrun --sdk macosx clang "${TARGET[@]}" -fobjc-arc -fblocks \
    -Wall -Wextra -Wno-unused-parameter -Wno-deprecated-declarations -framework Foundation -framework Security -lsqlite3 \
    -I "$PROJECT_ROOT/Sources" "$PROJECT_ROOT/Tests/ProtocolTests.m" \
    "$PROJECT_ROOT/Sources/JMProtocol.m" "$PROJECT_ROOT/Sources/JMHistory.m" "$PROJECT_ROOT/Sources/JMAccountData.m" "$PROJECT_ROOT/Sources/JMLocalization.m" "$PROJECT_ROOT/Sources/JMDraftStore.m" "$PROJECT_ROOT/Sources/JMLoginStore.m" \
    "$PROJECT_ROOT/Sources/JMAutoAway.m" "$PROJECT_ROOT/Sources/JMDiagnostics.m" "$PROJECT_ROOT/Sources/JMAPIClient.m" "$PROJECT_ROOT/Sources/JMHTTPClient.m" "$PROJECT_ROOT/Sources/JMGitHubTrust.m" "$PROJECT_ROOT/Sources/JMTextTools.m" "$PROJECT_ROOT/Sources/JMUpdateChecker.m" -o "$BUILD_DIR/ProtocolTests"
"$BUILD_DIR/ProtocolTests"
JIMMMAC_TEST_LEGACY_TRANSPORT=1 "$BUILD_DIR/ProtocolTests"
BUILD_DIR="$BUILD_DIR" bash "$PROJECT_ROOT/scripts/test-http.sh"
