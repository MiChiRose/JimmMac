#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO="MiChiRose/JimmMac"
PUBLISH=false
if [[ "${1:-}" == --publish ]]; then
    PUBLISH=true
    shift
fi
if [[ $# != 3 ]]; then
    echo 'Usage: bash scripts/release.sh [--publish] /path/to/legacy/JimmMac.app /path/to/modern/JimmMac.app notes.md' >&2
    exit 2
fi
LEGACY="$1"
MODERN="$2"
NOTES="$3"
fail() { echo "$*" >&2; exit 1; }
plist() { /usr/libexec/PlistBuddy -c "Print :$2" "$1"; }
minimum() {
    xcrun vtool -arch "$2" -show-build "$1" |
        awk '$1 == "minos" || $1 == "version" { print $2; exit }'
}

[[ -s "$NOTES" ]] || fail 'Release notes are missing or empty.'
[[ -z "$(git -C "$ROOT" status --porcelain)" ]] || fail 'Build and package the release from a clean source checkout.'
REVISION="$(git -C "$ROOT" rev-parse HEAD)"
VERSION="$(plist "$ROOT/Resources/Info.plist" CFBundleShortVersionString)"
BUILD="$(plist "$ROOT/Resources/Info.plist" CFBundleVersion)"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail 'Invalid release version.'
for app in "$LEGACY" "$MODERN"; do
    info="$app/Contents/Info.plist"
    [[ -x "$app/Contents/MacOS/JimmMac" && -f "$info" ]] || fail "Missing built app: $app"
    [[ "$(plist "$info" CFBundleShortVersionString)" == "$VERSION" &&
       "$(plist "$info" CFBundleVersion)" == "$BUILD" &&
       "$(plist "$info" JimmMacSourceRevision)" == "$REVISION" ]] ||
        fail "Build does not match version $VERSION ($BUILD) at $REVISION: $app"
done
legacy_binary="$LEGACY/Contents/MacOS/JimmMac"
modern_binary="$MODERN/Contents/MacOS/JimmMac"
[[ "$(lipo -archs "$legacy_binary")" == x86_64 && "$(minimum "$legacy_binary" x86_64)" == 10.8 ]] ||
    fail 'Legacy build must contain only x86_64, targeting OS X 10.8.'
[[ "$(minimum "$modern_binary" x86_64)" == 10.13 && "$(minimum "$modern_binary" arm64)" == 11.0 ]] ||
    fail 'Universal build must target macOS 10.13 on Intel and macOS 11.0 on Apple Silicon.'

if $PUBLISH; then
    remote_refs="$(git ls-remote "https://github.com/$REPO.git" refs/heads/main "refs/tags/v$VERSION")"
    remote_revision="$(awk '$2 == "refs/heads/main" { print $1 }' <<< "$remote_refs")"
    [[ "$remote_revision" == "$REVISION" ]] || fail "Push commit $REVISION to GitHub main before publishing."
    [[ -z "$(awk '$2 ~ /^refs\/tags\// { print $1 }' <<< "$remote_refs")" ]] ||
        fail "Tag v$VERSION already exists. Use a new release version."
fi

STAGE="$(mktemp -d "${TMPDIR:-/tmp}/jimmmac-release.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
bash "$ROOT/scripts/package-dmg.sh" "$LEGACY" "$STAGE"
bash "$ROOT/scripts/package-dmg.sh" "$MODERN" "$STAGE"
legacy_name="JimmMac-$VERSION-macos10.8-10.13-x86_64"
modern_name="JimmMac-$VERSION-macos10.13plus-universal"
ditto -c -k --sequesterRsrc --keepParent "$LEGACY" "$STAGE/$legacy_name.zip"
ditto -c -k --sequesterRsrc --keepParent "$MODERN" "$STAGE/$modern_name.zip"
source="JimmMac-source-$VERSION.zip"
checksums="JimmMac-$VERSION-SHA256SUMS.txt"
git -C "$ROOT" archive --format=zip --prefix="JimmMac-$VERSION/" -o "$STAGE/$source" "$REVISION"
assets=("$legacy_name.dmg" "$legacy_name.zip" "$modern_name.dmg" "$modern_name.zip" "$source")
(cd "$STAGE" && shasum -a 256 "${assets[@]}" > "$checksums" && shasum -a 256 -c "$checksums")
assets+=("$checksums")
DIST="${RELEASE_DIR:-$ROOT/dist/v$VERSION}"
mkdir -p "$DIST"
uploads=()
for asset in "${assets[@]}"; do
    cp "$STAGE/$asset" "$DIST/$asset"
    uploads+=("$STAGE/$asset")
done
echo "Prepared both builds in $DIST"

if $PUBLISH; then
    gh release create "v$VERSION" --repo "$REPO" --target "$REVISION" \
        --title "JimmMac $VERSION" --notes-file "$NOTES" --latest "${uploads[@]}"
fi
