#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-$PROJECT_ROOT/build}"
PROFILE="${1:-legacy}"
SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
APP="$BUILD_DIR/JimmMac.app"
REVISION="${JIMMMAC_SOURCE_REVISION:-}"
case "$PROFILE" in
    legacy|modern) ;;
    *) echo 'Usage: bash scripts/build.sh [legacy|modern]' >&2; exit 2 ;;
esac
if command -v git >/dev/null &&
   [[ "$(git -C "$PROJECT_ROOT" rev-parse --show-toplevel 2>/dev/null || true)" == "$PROJECT_ROOT" ]]; then
    [[ -z "$REVISION" ]] || { echo 'Use JIMMMAC_SOURCE_REVISION only with a source archive.' >&2; exit 2; }
    if [[ -z "$(git -C "$PROJECT_ROOT" status --porcelain)" ]]; then
        REVISION="$(git -C "$PROJECT_ROOT" rev-parse HEAD)"
    fi
fi
if [[ -n "$REVISION" && ! "$REVISION" =~ ^[0-9a-f]{40}$ ]]; then
    echo 'Expected a full Git commit SHA' >&2
    exit 2
fi
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
build_slice() {
    local arch="$1" minimum="$2" binary="$3"
    xcrun --sdk macosx clang -arch "$arch" "-mmacosx-version-min=$minimum" -isysroot "$SDK_PATH" \
    -fobjc-arc -fblocks -Wall -Wextra -Wno-unused-parameter -Wno-deprecated-declarations \
    -framework Cocoa -framework Carbon -framework ImageIO -framework Security -lsqlite3 \
    "$PROJECT_ROOT/Sources/main.m" "$PROJECT_ROOT/Sources/JMAppDelegate.m" "$PROJECT_ROOT/Sources/JMKeyboard.m" "$PROJECT_ROOT/Sources/JMInformationController.m" "$PROJECT_ROOT/Sources/JMUpdateChecker.m" "$PROJECT_ROOT/Sources/JMEmoticons.m" \
    "$PROJECT_ROOT/Sources/JMAutoAway.m" "$PROJECT_ROOT/Sources/JMDiagnostics.m" "$PROJECT_ROOT/Sources/JMAPIClient.m" "$PROJECT_ROOT/Sources/JMHTTPClient.m" "$PROJECT_ROOT/Sources/JMGitHubTrust.m" "$PROJECT_ROOT/Sources/JMProtocol.m" \
    "$PROJECT_ROOT/Sources/JMHistory.m" "$PROJECT_ROOT/Sources/JMAccountData.m" "$PROJECT_ROOT/Sources/JMLocalization.m" "$PROJECT_ROOT/Sources/JMDraftStore.m" "$PROJECT_ROOT/Sources/JMLoginStore.m" "$PROJECT_ROOT/Sources/JMStyle.m" "$PROJECT_ROOT/Sources/JMTheme.m" "$PROJECT_ROOT/Sources/JMAvatarStore.m" "$PROJECT_ROOT/Sources/JMAudioAlerts.m" \
    "$PROJECT_ROOT/Sources/JMTextTools.m" "$PROJECT_ROOT/Sources/JMChatPreferences.m" "$PROJECT_ROOT/Sources/JMNotificationAlerts.m" "$PROJECT_ROOT/Sources/JMOwnProfileController.m" -o "$binary"
}
if [[ "$PROFILE" == modern ]]; then
    SLICES="$(mktemp -d "${TMPDIR:-/tmp}/jimmmac-slices.XXXXXX")"
    trap 'rm -rf "$SLICES"' EXIT
    build_slice x86_64 10.13 "$SLICES/JimmMac-x86_64"
    build_slice arm64 11.0 "$SLICES/JimmMac-arm64"
    xcrun lipo -create "$SLICES/JimmMac-x86_64" "$SLICES/JimmMac-arm64" -output "$APP/Contents/MacOS/JimmMac"
else
    build_slice x86_64 10.8 "$APP/Contents/MacOS/JimmMac"
fi
cp "$PROJECT_ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
if [[ -n "$REVISION" ]]; then
    /usr/libexec/PlistBuddy -c "Add :JimmMacSourceRevision string $REVISION" "$APP/Contents/Info.plist"
fi
cp "$PROJECT_ROOT/Resources/ICQFlower.png" "$PROJECT_ROOT/Resources/JimmMac.icns" "$APP/Contents/Resources/"
cp "$PROJECT_ROOT/Resources/SectigoPublicServerAuthenticationRootE46.der" "$PROJECT_ROOT/Resources/USERTrustECCCertificationAuthority.der" "$APP/Contents/Resources/"
cp "$PROJECT_ROOT/Resources/JimmStatusSprite.png" "$APP/Contents/Resources/"
mkdir -p "$APP/Contents/Resources/Sounds"
ditto "$PROJECT_ROOT/Resources/Retro" "$APP/Contents/Resources/Retro"
cp "$PROJECT_ROOT/Resources/ASSET-SOURCES.md" "$APP/Contents/Resources/Retro/SOURCES.md"
cp "$PROJECT_ROOT/Resources/Sounds/"*.mp3 "$APP/Contents/Resources/Sounds/"
if [[ "$PROFILE" == modern ]]; then
    /usr/libexec/PlistBuddy \
        -c 'Set :LSMinimumSystemVersion 10.13' \
        -c 'Add :LSMinimumSystemVersionByArchitecture dict' \
        -c 'Add :LSMinimumSystemVersionByArchitecture:x86_64 string 10.13' \
        -c 'Add :LSMinimumSystemVersionByArchitecture:arm64 string 11.0' \
        "$APP/Contents/Info.plist"
    codesign --force --sign - --timestamp=none "$APP"
fi
plutil -lint "$APP/Contents/Info.plist"
# Launch Services uses the bundle's modification time to notice updated icons.
touch "$APP"
echo "Built: $APP"
