#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ "${JIMMMAC_NATIVE_TESTS:-0}" == 1 ]]; then
    TARGET=(-arch "$(uname -m)" -mmacosx-version-min=11.0)
    DEFAULT_BUILD_DIR="$PROJECT_ROOT/build/native-tests"
else
    TARGET=(-arch x86_64 -mmacosx-version-min=10.9)
    DEFAULT_BUILD_DIR="$PROJECT_ROOT/build"
fi
BUILD_DIR="${BUILD_DIR:-$DEFAULT_BUILD_DIR}"
mkdir -p "$BUILD_DIR"
TEST_BINARY="$BUILD_DIR/UISmoke"
if [[ "${JIMMMAC_NATIVE_TESTS:-0}" == 1 ]]; then
    mkdir -p "$BUILD_DIR/ui-runner/bin"
    ln -sfn "$PROJECT_ROOT/Resources" "$BUILD_DIR/ui-runner/Resources"
    TEST_BINARY="$BUILD_DIR/ui-runner/bin/UISmoke"
fi
xcrun --sdk macosx clang "${TARGET[@]}" -fobjc-arc -fblocks \
    -Wall -Wextra -Wno-unused-parameter -Wno-deprecated-declarations -framework Cocoa -framework Carbon -framework ImageIO -framework Security -lsqlite3 \
    -I "$PROJECT_ROOT/Sources" "$PROJECT_ROOT/Tests/UISmoke.m" \
    "$PROJECT_ROOT/Sources/JMAppDelegate.m" "$PROJECT_ROOT/Sources/JMKeyboard.m" "$PROJECT_ROOT/Sources/JMInformationController.m" "$PROJECT_ROOT/Sources/JMUpdateChecker.m" "$PROJECT_ROOT/Sources/JMEmoticons.m" "$PROJECT_ROOT/Sources/JMProtocol.m" \
    "$PROJECT_ROOT/Sources/JMHistory.m" "$PROJECT_ROOT/Sources/JMAccountData.m" "$PROJECT_ROOT/Sources/JMLocalization.m" "$PROJECT_ROOT/Sources/JMDraftStore.m" "$PROJECT_ROOT/Sources/JMLoginStore.m" "$PROJECT_ROOT/Sources/JMAutoAway.m" "$PROJECT_ROOT/Sources/JMDiagnostics.m" "$PROJECT_ROOT/Sources/JMAPIClient.m" "$PROJECT_ROOT/Sources/JMHTTPClient.m" "$PROJECT_ROOT/Sources/JMGitHubTrust.m" "$PROJECT_ROOT/Sources/JMStyle.m" "$PROJECT_ROOT/Sources/JMTheme.m" "$PROJECT_ROOT/Sources/JMAvatarStore.m" "$PROJECT_ROOT/Sources/JMAudioAlerts.m" \
    "$PROJECT_ROOT/Sources/JMTextTools.m" "$PROJECT_ROOT/Sources/JMChatPreferences.m" "$PROJECT_ROOT/Sources/JMNotificationAlerts.m" "$PROJECT_ROOT/Sources/JMOwnProfileController.m" \
    -o "$TEST_BINARY"
"$TEST_BINARY" "$BUILD_DIR"
