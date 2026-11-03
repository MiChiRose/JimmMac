#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-$PROJECT_ROOT/build}"
mkdir -p "$BUILD_DIR"
xcrun --sdk macosx clang -arch x86_64 -mmacosx-version-min=10.9 -fobjc-arc -fblocks \
    -Wall -Wextra -Wno-unused-parameter -Wno-deprecated-declarations -framework Cocoa -framework Carbon -framework ImageIO -framework Security -lsqlite3 \
    -I "$PROJECT_ROOT/Sources" "$PROJECT_ROOT/Tests/UISmoke.m" \
    "$PROJECT_ROOT/Sources/JMAppDelegate.m" "$PROJECT_ROOT/Sources/JMKeyboard.m" "$PROJECT_ROOT/Sources/JMInformationController.m" "$PROJECT_ROOT/Sources/JMUpdateChecker.m" "$PROJECT_ROOT/Sources/JMEmoticons.m" "$PROJECT_ROOT/Sources/JMProtocol.m" \
    "$PROJECT_ROOT/Sources/JMHistory.m" "$PROJECT_ROOT/Sources/JMDraftStore.m" "$PROJECT_ROOT/Sources/JMLoginStore.m" "$PROJECT_ROOT/Sources/JMAPIClient.m" "$PROJECT_ROOT/Sources/JMHTTPClient.m" "$PROJECT_ROOT/Sources/JMGitHubTrust.m" "$PROJECT_ROOT/Sources/JMStyle.m" "$PROJECT_ROOT/Sources/JMAvatarStore.m" "$PROJECT_ROOT/Sources/JMAudioAlerts.m" \
    "$PROJECT_ROOT/Sources/JMTextTools.m" "$PROJECT_ROOT/Sources/JMChatPreferences.m" "$PROJECT_ROOT/Sources/JMNotificationAlerts.m" "$PROJECT_ROOT/Sources/JMOwnProfileController.m" \
    -o "$BUILD_DIR/UISmoke"
"$BUILD_DIR/UISmoke" "$BUILD_DIR"
