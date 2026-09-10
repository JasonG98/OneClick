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
  # Only terminate an instance whose executable is our development build.
  for ONECLICK_PID in $(pgrep -x OneClick || true); do
    ONECLICK_COMMAND="$(ps -p "$ONECLICK_PID" -o comm=)"
    if [[ "$ONECLICK_COMMAND" == "$ONECLICK_APP/Contents/MacOS/OneClick" ]]; then
      kill "$ONECLICK_PID"
    fi
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
