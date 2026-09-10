#!/bin/bash
set -euo pipefail

ONECLICK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ONECLICK_MODE="${1:-run}"
ONECLICK_BUILD="$ONECLICK_ROOT/.build/DerivedData"
ONECLICK_APP="$ONECLICK_BUILD/Build/Products/Debug/OneClick.app"
case "$ONECLICK_MODE" in
  run|--verify|--debug|--logs|--telemetry|--build-only) ;;
  *) echo "usage: $0 [--build-only|--verify|--debug|--logs|--telemetry]" >&2; exit 2 ;;
esac
cd "$ONECLICK_ROOT"
ONECLICK_TEAM="${ONECLICK_TEAM_ID:-}"
if [[ -z "$ONECLICK_TEAM" && -f config/Local.xcconfig ]]; then
  ONECLICK_TEAM="$(awk -F= '/^[[:space:]]*DEVELOPMENT_TEAM[[:space:]]*=/ {gsub(/[[:space:]]/, "", $2); print $2; exit}' config/Local.xcconfig)"
fi
ONECLICK_SIGNING_ARGS=(CODE_SIGNING_ALLOWED=NO)
if [[ -n "$ONECLICK_TEAM" ]]; then
  if [[ ! "$ONECLICK_TEAM" =~ ^[A-Z0-9]{10}$ ]]; then
    echo "ONECLICK_TEAM_ID / DEVELOPMENT_TEAM must be a 10-character Apple team ID." >&2; exit 2
  fi
  ONECLICK_SIGNING_ARGS=(CODE_SIGNING_ALLOWED=YES "DEVELOPMENT_TEAM=$ONECLICK_TEAM" "CODE_SIGN_IDENTITY=${ONECLICK_SIGNING_IDENTITY:-Apple Development}" "ONECLICK_APP_GROUP=$ONECLICK_TEAM.local.oneclick.shared")
elif [[ "$ONECLICK_MODE" != "--build-only" ]]; then
  echo "Running Finder integration requires an Apple Development identity and team. Set DEVELOPMENT_TEAM in config/Local.xcconfig or export ONECLICK_TEAM_ID. Ad hoc signing cannot authorize App Group access on current macOS." >&2
  exit 2
fi
if [[ "$ONECLICK_MODE" != "--build-only" ]]; then
  # Only terminate instances whose executable is this development build. An
  # extension started from another copy (Xcode's own DerivedData, for example)
  # is left alone: that copy is not the one this script manages.
  ONECLICK_APPEX="$ONECLICK_APP/Contents/PlugIns/OneClickFinder.appex"
  ONECLICK_EXTENSION_BINARY="$ONECLICK_APPEX/Contents/MacOS/OneClickFinder"
  for ONECLICK_PID in $(pgrep -x OneClick || true); do
    ONECLICK_COMMAND="$(ps -p "$ONECLICK_PID" -o comm=)"
    if [[ "$ONECLICK_COMMAND" == "$ONECLICK_APP/Contents/MacOS/OneClick" ]]; then
      kill "$ONECLICK_PID"
    fi
  done
  # Finder keeps the extension resident until its bundle is replaced under it,
  # at which point the process exits. It is never started again on its own, so
  # retire it here and let the recovery step below start the fresh one.
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
if [[ -n "$ONECLICK_TEAM" ]]; then
  /usr/bin/codesign --verify --deep --strict "$ONECLICK_APP"
fi
echo "Built $ONECLICK_APP"
if [[ "$ONECLICK_MODE" == "--build-only" ]]; then exit 0; fi

/usr/bin/open -n "$ONECLICK_APP"

# Finder starts a Finder Sync extension once and never starts it again when that
# process exits. A rebuild replaces the .appex underneath the running process, so
# the extension dies and stays dead while System Settings still shows it as
# enabled: no context menu and no toolbar button, with nothing to re-enable.
#
# PluginKit keeps whichever copy of the bundle registered first and ignores a
# later `pluginkit -a` for the same identifier, so a stale copy (Xcode's own
# DerivedData) keeps winning and this build's extension never loads. Retiring
# the stale registration and re-registering this build is what repoints it, and
# re-electing the plugin restarts the extension without touching Finder or the
# user's other extensions.
ONECLICK_EXTENSION_ID="local.oneclick.app.finder"
ONECLICK_LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister

oneclick_registered_appex_path() {
  /usr/bin/pluginkit -m -v -i "$ONECLICK_EXTENSION_ID" 2>/dev/null |
    awk '{ path = $NF } path ~ /\.appex$/ { print path; exit }'
}

oneclick_retire_stale_registration() {
  local ONECLICK_REGISTERED ONECLICK_STALE_APP
  ONECLICK_REGISTERED="$(oneclick_registered_appex_path)"
  [[ -n "$ONECLICK_REGISTERED" ]] || return 0
  [[ "$ONECLICK_REGISTERED" == "$ONECLICK_APPEX" ]] && return 0
  # Keep the app bundle that owns the stale extension, never the appex alone:
  # a stale appex outlives the registration of its container otherwise.
  ONECLICK_STALE_APP="${ONECLICK_REGISTERED%%.appex*}"
  ONECLICK_STALE_APP="${ONECLICK_STALE_APP%/Contents/PlugIns}"
  if [[ "$ONECLICK_STALE_APP" == *.app ]]; then
    echo "Retiring stale extension registration: $ONECLICK_STALE_APP"
    "$ONECLICK_LSREGISTER" -u "$ONECLICK_STALE_APP" > /dev/null 2>&1 || true
  fi
}

oneclick_reload_extension() {
  if [[ ! -d "$ONECLICK_APPEX" ]]; then
    echo "Extension bundle missing from the build product: $ONECLICK_APPEX" >&2
    return 0
  fi
  oneclick_retire_stale_registration
  "$ONECLICK_LSREGISTER" -f "$ONECLICK_APP" > /dev/null 2>&1 || true
  /usr/bin/pluginkit -a "$ONECLICK_APPEX" > /dev/null 2>&1 || true
  /usr/bin/pluginkit -e use -i "$ONECLICK_EXTENSION_ID" > /dev/null 2>&1 || true
  for _ in {1..40}; do
    if pgrep -f "$ONECLICK_EXTENSION_BINARY" > /dev/null 2>&1; then
      echo "Finder extension is running"
      return 0
    fi
    sleep 0.25
  done
  echo "Finder extension did not restart. Open the OneClick settings window and use the status card, or restart Finder." >&2
}
oneclick_reload_extension

case "$ONECLICK_MODE" in
  --verify)
    for ONECLICK_ATTEMPT in {1..20}; do
      for ONECLICK_PID in $(pgrep -x OneClick || true); do
        if [[ "$(ps -p "$ONECLICK_PID" -o comm=)" == "$ONECLICK_APP/Contents/MacOS/OneClick" ]]; then
          echo "Development OneClick is running (pid $ONECLICK_PID)"; exit 0
        fi
      done
      sleep 0.25
    done
    echo "OneClick did not stay running" >&2; exit 1 ;;
  --debug) exec lldb -n OneClick ;;
  --logs) exec /usr/bin/log stream --info --style compact --predicate 'process == "OneClick"' ;;
  --telemetry) exec /usr/bin/log stream --info --style compact --predicate 'subsystem == "local.oneclick.app"' ;;
esac
