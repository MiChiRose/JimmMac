#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-$PROJECT_ROOT/build}"
SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
APP="$BUILD_DIR/JimmMac.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
xcrun --sdk macosx clang -arch x86_64 -mmacosx-version-min=10.8 -isysroot "$SDK_PATH" \
    -fobjc-arc -fblocks -Wall -Wextra -Wno-unused-parameter -Wno-deprecated-declarations \
    -framework Cocoa -framework Carbon -framework ImageIO -framework Security -lsqlite3 \
    "$PROJECT_ROOT/Sources/main.m" "$PROJECT_ROOT/Sources/JMAppDelegate.m" "$PROJECT_ROOT/Sources/JMKeyboard.m" "$PROJECT_ROOT/Sources/JMInformationController.m" "$PROJECT_ROOT/Sources/JMUpdateChecker.m" "$PROJECT_ROOT/Sources/JMEmoticons.m" \
    "$PROJECT_ROOT/Sources/JMAPIClient.m" "$PROJECT_ROOT/Sources/JMHTTPClient.m" "$PROJECT_ROOT/Sources/JMGitHubTrust.m" "$PROJECT_ROOT/Sources/JMProtocol.m" \
    "$PROJECT_ROOT/Sources/JMHistory.m" "$PROJECT_ROOT/Sources/JMAccountData.m" "$PROJECT_ROOT/Sources/JMLocalization.m" "$PROJECT_ROOT/Sources/JMDraftStore.m" "$PROJECT_ROOT/Sources/JMLoginStore.m" "$PROJECT_ROOT/Sources/JMStyle.m" "$PROJECT_ROOT/Sources/JMTheme.m" "$PROJECT_ROOT/Sources/JMAvatarStore.m" "$PROJECT_ROOT/Sources/JMAudioAlerts.m" \
    "$PROJECT_ROOT/Sources/JMTextTools.m" "$PROJECT_ROOT/Sources/JMChatPreferences.m" "$PROJECT_ROOT/Sources/JMNotificationAlerts.m" "$PROJECT_ROOT/Sources/JMOwnProfileController.m" -o "$APP/Contents/MacOS/JimmMac"
cp "$PROJECT_ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$PROJECT_ROOT/Resources/ICQFlower.png" "$PROJECT_ROOT/Resources/JimmMac.icns" "$APP/Contents/Resources/"
cp "$PROJECT_ROOT/Resources/SectigoPublicServerAuthenticationRootE46.der" "$PROJECT_ROOT/Resources/USERTrustECCCertificationAuthority.der" "$APP/Contents/Resources/"
cp "$PROJECT_ROOT/Resources/JimmStatusSprite.png" "$APP/Contents/Resources/"
mkdir -p "$APP/Contents/Resources/Sounds"
cp "$PROJECT_ROOT/Resources/Sounds/"*.mp3 "$APP/Contents/Resources/Sounds/"
plutil -lint "$APP/Contents/Info.plist"
# Launch Services uses the bundle's modification time to notice updated icons.
touch "$APP"
echo "Built: $APP"
