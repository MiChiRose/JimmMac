#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ICON_WORK="${BUILD_DIR:-$PROJECT_ROOT/build}/icon-work"
mkdir -p "$ICON_WORK"
xcrun clang -fobjc-arc -Wno-deprecated-declarations -framework Cocoa "$PROJECT_ROOT/scripts/IconBuilder.m" -o "$ICON_WORK/IconBuilder"
"$ICON_WORK/IconBuilder" "$PROJECT_ROOT/Resources/ICQFlower.png" "$ICON_WORK/JimmMac.iconset"
iconutil -c icns "$ICON_WORK/JimmMac.iconset" -o "$PROJECT_ROOT/Resources/JimmMac.icns"
