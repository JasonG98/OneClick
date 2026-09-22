#!/bin/bash
set -euo pipefail

ONECLICK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ONECLICK_MODE="${1:-run}"
ONECLICK_BUILD="$ONECLICK_ROOT/.build/DerivedData"
ONECLICK_APP="$ONECLICK_BUILD/Build/Products/Debug/OneClick.app"
case "$ONECLICK_MODE" in
  run|--build-only) ;;
  *)
    echo "usage: $0 [--build-only]" >&2
    echo "  (no argument)  build, then launch the app and re-register the extension" >&2
    echo "  --build-only   build with ad hoc signing, without launching or touching Finder" >&2
    exit 2 ;;
esac
cd "$ONECLICK_ROOT"
ONECLICK_SIGNING_ARGS=(CODE_SIGNING_ALLOWED=YES CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM=)
if [[ "$ONECLICK_MODE" != "--build-only" ]]; then
  ONECLICK_APPEX="$ONECLICK_APP/Contents/PlugIns/OneClickFinder.appex"
  ONECLICK_EXTENSION_BINARY="$ONECLICK_APPEX/Contents/MacOS/OneClickFinder"
  for ONECLICK_PID in $(pgrep -x OneClick || true); do
    ONECLICK_COMMAND="$(ps -p "$ONECLICK_PID" -o comm=)"
    if [[ "$ONECLICK_COMMAND" == "$ONECLICK_APP/Contents/MacOS/OneClick" ]]; then
      kill "$ONECLICK_PID"
    fi
  done
  for ONECLICK_PID in $(pgrep -f "$ONECLICK_EXTENSION_BINARY" || true); do
    kill "$ONECLICK_PID"
  done
fi
mkdir -p "$ONECLICK_ROOT/.build/logs"
if ! xcodebuild -project OneClick.xcodeproj -scheme OneClick -configuration Debug \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath "$ONECLICK_BUILD" \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=NO "${ONECLICK_SIGNING_ARGS[@]}" build > "$ONECLICK_ROOT/.build/logs/build.log" 2>&1; then
  tail -80 "$ONECLICK_ROOT/.build/logs/build.log" >&2
  exit 1
fi
/usr/bin/codesign --verify --deep --strict "$ONECLICK_APP"
echo "Built $ONECLICK_APP"
if [[ "$ONECLICK_MODE" == "--build-only" ]]; then exit 0; fi

/usr/bin/open -n "$ONECLICK_APP"

ONECLICK_EXTENSION_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$ONECLICK_APPEX/Contents/Info.plist")"
ONECLICK_APP_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$ONECLICK_APP/Contents/Info.plist")"
ONECLICK_LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister

oneclick_registered_appex_path() {
  /usr/bin/pluginkit -m -v -i "$ONECLICK_EXTENSION_ID" 2>/dev/null |
    awk '{ path = $NF } path ~ /\.appex$/ { print path; exit }'
}

oneclick_retire_stale_registration() {
  local ONECLICK_REGISTERED ONECLICK_STALE_APP
  ONECLICK_REGISTERED="$(oneclick_registered_appex_path || true)"
  [[ -n "$ONECLICK_REGISTERED" ]] || return 0
  [[ "$ONECLICK_REGISTERED" == "$ONECLICK_APPEX" ]] && return 0
  ONECLICK_STALE_APP="${ONECLICK_REGISTERED%%.appex*}"
  ONECLICK_STALE_APP="${ONECLICK_STALE_APP%/Contents/PlugIns}"
  if [[ "$ONECLICK_STALE_APP" == *.app ]]; then
    echo "Retiring stale extension registration: $ONECLICK_STALE_APP"
    "$ONECLICK_LSREGISTER" -u "$ONECLICK_STALE_APP" > /dev/null 2>&1 || true
  fi
}

oneclick_registered_app_paths() {
  "$ONECLICK_LSREGISTER" -dump 2>/dev/null |
    awk -v wanted="$ONECLICK_APP_ID" '
      /^path:/ { path = $2 }
      /^identifier:/ { if ($2 == wanted) print path }'
}

oneclick_retire_stale_app_registrations() {
  local ONECLICK_REGISTERED
  while read -r ONECLICK_REGISTERED; do
    [[ -n "$ONECLICK_REGISTERED" ]] || continue
    [[ "$ONECLICK_REGISTERED" == "$ONECLICK_APP" ]] && continue
    [[ "$ONECLICK_REGISTERED" == "$ONECLICK_ROOT"/.build/* ]] || continue
    echo "Retiring stale app registration: $ONECLICK_REGISTERED"
    "$ONECLICK_LSREGISTER" -u "$ONECLICK_REGISTERED" > /dev/null 2>&1 || true
  done < <(oneclick_registered_app_paths)
}

oneclick_reload_extension() {
  if [[ ! -d "$ONECLICK_APPEX" ]]; then
    echo "Extension bundle missing from the build product: $ONECLICK_APPEX" >&2
    return 1
  fi
  oneclick_retire_stale_registration
  oneclick_retire_stale_app_registrations
  "$ONECLICK_LSREGISTER" -f "$ONECLICK_APP" > /dev/null 2>&1 || true
  touch "$ONECLICK_APP"
  local ONECLICK_RELOAD_ATTEMPT
  for ONECLICK_RELOAD_ATTEMPT in {1..40}; do
    if (( (ONECLICK_RELOAD_ATTEMPT - 1) % 8 == 0 )); then
      /usr/bin/pluginkit -a "$ONECLICK_APPEX" > /dev/null 2>&1 || true
      /usr/bin/pluginkit -e use -i "$ONECLICK_EXTENSION_ID" > /dev/null 2>&1 || true
    fi
    if pgrep -f "$ONECLICK_EXTENSION_BINARY" > /dev/null 2>&1; then
      echo "Finder extension is running"
      return 0
    fi
    sleep 0.25
  done
  echo "Finder extension did not restart. Open the OneClick settings window and use the status card, or restart Finder." >&2
  return 1
}
oneclick_reload_extension

for ONECLICK_ATTEMPT in {1..20}; do
  for ONECLICK_PID in $(pgrep -x OneClick || true); do
    if [[ "$(ps -p "$ONECLICK_PID" -o comm=)" == "$ONECLICK_APP/Contents/MacOS/OneClick" ]]; then
      echo "Development OneClick is running (pid $ONECLICK_PID)"; exit 0
    fi
  done
  sleep 0.25
done
echo "OneClick did not stay running" >&2; exit 1
