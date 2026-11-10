#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${1:-$ROOT/build/JimmMac.app}"
OUTPUT="${2:-$ROOT/dist}"
PYTHON="${DMGBUILD_PYTHON:-python3}"
APP="$(cd "$(dirname "$APP")" && pwd)/$(basename "$APP")"
[[ "$(basename "$APP")" == JimmMac.app ]] || { echo 'Expected JimmMac.app'; exit 1; }
[[ -x "$APP/Contents/MacOS/JimmMac" ]] || { echo 'Build JimmMac first'; exit 1; }
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Invalid bundle version'; exit 1; }
MINIMUM="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$APP/Contents/Info.plist")"
BINARY="$APP/Contents/MacOS/JimmMac"
ARCHS="$(lipo -archs "$BINARY")"
case "$MINIMUM:$ARCHS" in
    '10.8:x86_64') SUFFIX='macos10.8-10.13-x86_64' ;;
    '10.13:x86_64 arm64'|'10.13:arm64 x86_64')
        [[ "$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersionByArchitecture:x86_64' "$APP/Contents/Info.plist")" == 10.13 ]]
        [[ "$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersionByArchitecture:arm64' "$APP/Contents/Info.plist")" == 11.0 ]]
        codesign --verify --strict "$APP"
        SUFFIX='macos10.13plus-universal'
        ;;
    *) echo "Unsupported deployment target or architectures: $MINIMUM ($ARCHS)" >&2; exit 1 ;;
esac
"$PYTHON" -c 'import dmgbuild, ds_store, mac_alias' || { echo 'Install scripts/requirements-dmg.txt into a Python 3 virtualenv; set DMGBUILD_PYTHON.'; exit 1; }
mkdir -p "$OUTPUT"
OUTPUT="$(cd "$OUTPUT" && pwd)"
STAGE="$(mktemp -d /tmp/jimmmac-installer.XXXXXX)"
trap 'rm -rf "$STAGE"' EXIT
xcrun clang -fobjc-arc -Wno-deprecated-declarations -framework Cocoa "$ROOT/scripts/InstallerArtwork.m" -o "$STAGE/artwork"
"$STAGE/artwork" "$ROOT/Resources/ICQFlower.png" "$STAGE/InstallerBackground.png" 1
"$STAGE/artwork" "$ROOT/Resources/ICQFlower.png" "$STAGE/InstallerBackground@2x.png" 2
"$PYTHON" -m dmgbuild -s "$ROOT/scripts/dmg-settings.py" -D "app=$APP" -D "artwork=$STAGE/InstallerBackground.png" "JimmMac $VERSION" "$STAGE/JimmMac.dmg"
hdiutil verify "$STAGE/JimmMac.dmg"
NAME="JimmMac-$VERSION-$SUFFIX.dmg"
mv "$STAGE/JimmMac.dmg" "$OUTPUT/$NAME"
(cd "$OUTPUT" && shasum -a 256 "$NAME" > "$NAME.sha256")
echo "Created $OUTPUT/$NAME"
