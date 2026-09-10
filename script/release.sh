#!/bin/bash
set -euo pipefail

fail() {
  echo "release.sh: $1" >&2
  exit 1
}

is_release_version() {
  [[ "$1" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]
}

if [[ $# -ne 1 ]]; then
  echo "Usage: ONECLICK_TEAM_ID=... ONECLICK_SIGNING_IDENTITY=... ONECLICK_NOTARY_PROFILE=... $0 VERSION" >&2
  echo "release.sh: version is required" >&2
  exit 2
fi

VERSION="$1"
MISSING=()
[[ -n "${ONECLICK_TEAM_ID:-}" ]] || MISSING+=("ONECLICK_TEAM_ID")
[[ -n "${ONECLICK_SIGNING_IDENTITY:-}" ]] || MISSING+=("ONECLICK_SIGNING_IDENTITY")
[[ -n "${ONECLICK_NOTARY_PROFILE:-}" ]] || MISSING+=("ONECLICK_NOTARY_PROFILE")
if (( ${#MISSING[@]} > 0 )); then
  printf 'release.sh: missing required input: %s\n' "${MISSING[@]}" >&2
  exit 2
fi

is_release_version "$VERSION" || fail "version must be a release version such as 1.2.3 (without a v prefix)"
[[ "$ONECLICK_TEAM_ID" =~ ^[A-Z0-9]{10}$ ]] || fail "ONECLICK_TEAM_ID must be a 10-character Apple Team ID"
[[ "$ONECLICK_SIGNING_IDENTITY" == "Developer ID Application: "* ]] || fail "ONECLICK_SIGNING_IDENTITY must name a Developer ID Application identity"

for required_command in xcodebuild lipo codesign xcrun ditto spctl shasum; do
  command -v "$required_command" >/dev/null 2>&1 || fail "required command is unavailable: $required_command"
done

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA_PATH="${ONECLICK_DERIVED_DATA_PATH:-$ROOT/.build/ReleaseDerivedData}"
DIST_DIR="${ONECLICK_DIST_DIR:-$ROOT/dist}"
RELEASE_WORK_DIR="$(dirname "$DERIVED_DATA_PATH")"
APP="$DERIVED_DATA_PATH/Build/Products/Release/OneClick.app"
EXTENSION="$APP/Contents/PlugIns/OneClickFinder.appex"
APP_EXECUTABLE="$APP/Contents/MacOS/OneClick"
EXTENSION_EXECUTABLE="$EXTENSION/Contents/MacOS/OneClickFinder"
NOTARY_ARCHIVE="$RELEASE_WORK_DIR/OneClick-$VERSION-notarization.zip"
FINAL_ARCHIVE="$DIST_DIR/OneClick-$VERSION.zip"
FINAL_ARCHIVE_TEMP="$DIST_DIR/.OneClick-$VERSION.zip.in-progress"
APP_GROUP="$ONECLICK_TEAM_ID.local.oneclick.shared"

mkdir -p "$DERIVED_DATA_PATH" "$DIST_DIR"
rm -f "$NOTARY_ARCHIVE" "$FINAL_ARCHIVE_TEMP"

xcodebuild \
  -project "$ROOT/OneClick.xcodeproj" \
  -scheme OneClick \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  clean build \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=NO \
  "DEVELOPMENT_TEAM=$ONECLICK_TEAM_ID" \
  CODE_SIGN_STYLE=Manual \
  "CODE_SIGN_IDENTITY=$ONECLICK_SIGNING_IDENTITY" \
  "ONECLICK_APP_GROUP=$APP_GROUP" \
  "MARKETING_VERSION=$VERSION"

[[ -d "$APP" ]] || fail "Release build did not produce $APP"
[[ -d "$EXTENSION" ]] || fail "Release build did not embed $EXTENSION"
[[ -x "$APP_EXECUTABLE" ]] || fail "main executable is missing: $APP_EXECUTABLE"
[[ -x "$EXTENSION_EXECUTABLE" ]] || fail "Finder extension executable is missing: $EXTENSION_EXECUTABLE"

for bundle in "$APP" "$EXTENSION"; do
  bundle_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$bundle/Contents/Info.plist")"
  [[ "$bundle_version" == "$VERSION" ]] || fail "$bundle has version $bundle_version; expected $VERSION"
done

for executable in "$APP_EXECUTABLE" "$EXTENSION_EXECUTABLE"; do
  architectures="$(lipo -archs "$executable")"
  [[ "$architectures" == "arm64" ]] || fail "$executable contains '$architectures'; expected arm64 only"
done

codesign --verify --deep --strict --verbose=2 "$APP"

ditto -c -k --keepParent "$APP" "$NOTARY_ARCHIVE"
xcrun notarytool submit "$NOTARY_ARCHIVE" \
  --keychain-profile "$ONECLICK_NOTARY_PROFILE" \
  --wait
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
spctl --assess --type execute --verbose=2 "$APP"

ditto -c -k --keepParent "$APP" "$FINAL_ARCHIVE_TEMP"
mv -f "$FINAL_ARCHIVE_TEMP" "$FINAL_ARCHIVE"

HASH_OUTPUT="$(shasum -a 256 -- "$FINAL_ARCHIVE")"
SHA256="${HASH_OUTPUT%% *}"
[[ "$SHA256" =~ ^[0-9a-f]{64}$ ]] || fail "could not calculate the final archive SHA-256"

printf 'Prepared notarized release archive: %s\n' "$FINAL_ARCHIVE"
printf 'SHA-256: %s\n' "$SHA256"
