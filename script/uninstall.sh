#!/bin/bash
set -euo pipefail
oneclick_fail() { echo "$*" >&2; exit 1; }
oneclick_fail_usage() { echo "$*" >&2; exit 2; }

ONECLICK_APP_ID="local.oneclick.app"
ONECLICK_EXTENSION_ID="local.oneclick.app.finder"
ONECLICK_APPEX_NAME="OneClickFinder.appex"

ONECLICK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ONECLICK_HOME="${HOME:-}"
[[ -n "$ONECLICK_HOME" ]] || oneclick_fail "HOME is not set"
ONECLICK_APPLICATIONS_DIR="${ONECLICK_APPLICATIONS_DIR:-/Applications}"

ONECLICK_LSREGISTER="${ONECLICK_LSREGISTER:-/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister}"
ONECLICK_PLUGINKIT="${ONECLICK_PLUGINKIT:-/usr/bin/pluginkit}"

ONECLICK_APPLY=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) ONECLICK_APPLY=true; shift ;;
    -h|--help)
      echo "Usage: $0 [--apply] (default: report only)"
      exit 0 ;;
    *) oneclick_fail_usage "unknown argument: $1" ;;
  esac
done

ONECLICK_REMOVED=0

info() { printf '%s\n' "$1"; }

remove() {
  local ONECLICK_TARGET="$1" ONECLICK_LABEL="${2:-}"
  if [[ ! -e "$ONECLICK_TARGET" ]]; then
    return 0
  fi
  if [[ "$ONECLICK_APPLY" == false ]]; then
    info "  would remove  $ONECLICK_TARGET${ONECLICK_LABEL:+  ($ONECLICK_LABEL)}"
    ONECLICK_REMOVED=$((ONECLICK_REMOVED + 1))
    return 0
  fi
  rm -rf -- "$ONECLICK_TARGET" 2>/dev/null || return 1
  [[ -e "$ONECLICK_TARGET" ]] && return 1
  info "  removed       $ONECLICK_TARGET${ONECLICK_LABEL:+  ($ONECLICK_LABEL)}"
  ONECLICK_REMOVED=$((ONECLICK_REMOVED + 1))
  return 0
}

announce_then_run() {
  local ONECLICK_LABEL="$1"; shift
  if [[ "$ONECLICK_APPLY" == false ]]; then
    info "  would run     $ONECLICK_LABEL"
    return 0
  fi
  "$@" > /dev/null 2>&1 || true
}

oneclick_app_paths() {
  local ONECLICK_CANDIDATE ONECLICK_IDENTIFIER
  {
    for ONECLICK_CANDIDATE in "$ONECLICK_APPLICATIONS_DIR/OneClick.app" "$ONECLICK_HOME/Applications/OneClick.app"; do
      [[ -d "$ONECLICK_CANDIDATE" ]] && printf '%s\n' "$ONECLICK_CANDIDATE"
    done
    if [[ -x "$ONECLICK_LSREGISTER" ]]; then
      "$ONECLICK_LSREGISTER" -dump 2>/dev/null |
        awk -v wanted="$ONECLICK_APP_ID" '
          /^path:/ { path = $2 }
          /^identifier:/ { if ($2 == wanted) { print path } }' || true
    fi
    for ONECLICK_CANDIDATE in "$ONECLICK_ROOT"/.build/*/Build/Products/*/"OneClick.app"; do
      [[ -d "$ONECLICK_CANDIDATE" ]] && printf '%s\n' "$ONECLICK_CANDIDATE"
    done
  } | while IFS= read -r ONECLICK_CANDIDATE; do
    [[ -n "$ONECLICK_CANDIDATE" ]] || continue
    ONECLICK_IDENTIFIER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' \
      "$ONECLICK_CANDIDATE/Contents/Info.plist" 2>/dev/null || true)"
    if [[ "$ONECLICK_IDENTIFIER" == "$ONECLICK_APP_ID" ]]; then
      printf '%s\n' "$ONECLICK_CANDIDATE"
    else
      printf 'foreign\n%s\n' "$ONECLICK_CANDIDATE" >&2
    fi
  done
}

oneclick_remove_shared_directory() {
  local ONECLICK_DIRECTORY="$ONECLICK_HOME/Library/Application Support/OneClick"
  local ONECLICK_MARKER="$ONECLICK_DIRECTORY/.oneclick-owner.plist" ONECLICK_OWNER
  [[ -e "$ONECLICK_DIRECTORY" || -L "$ONECLICK_DIRECTORY" ]] || return 0
  if [[ -d "$ONECLICK_DIRECTORY" && ! -L "$ONECLICK_DIRECTORY" && -f "$ONECLICK_MARKER" && ! -L "$ONECLICK_MARKER" ]]; then
    ONECLICK_OWNER="$(/usr/bin/plutil -extract CFBundleIdentifier raw "$ONECLICK_MARKER" 2>/dev/null || true)"
    if [[ "$ONECLICK_OWNER" == "$ONECLICK_APP_ID" ]]; then
      remove "$ONECLICK_DIRECTORY" "shared configuration"
      return $?
    fi
  fi
  info "  preserved     $ONECLICK_DIRECTORY (ownership not confirmed or symlink)"
}

oneclick_report() {
  local ONECLICK_PATHS="$1" ONECLICK_LABEL="$2" ONECLICK_PATH ONECLICK_STATUS=0
  if [[ -z "$ONECLICK_PATHS" ]]; then
    info "  none found    ($ONECLICK_LABEL)"
    return 0
  fi
  while IFS= read -r ONECLICK_PATH; do
    [[ -n "$ONECLICK_PATH" ]] || continue
    remove "$ONECLICK_PATH" "$ONECLICK_LABEL" || ONECLICK_STATUS=1
  done <<< "$ONECLICK_PATHS"
  return "$ONECLICK_STATUS"
}

info "1. Processes"
ONECLICK_APPS="$(oneclick_app_paths 2>/dev/null || true)"
ONECLICK_RUNNING_APP=false
if pgrep -x OneClick > /dev/null 2>&1; then
  ONECLICK_RUNNING_APP=true
  announce_then_run "pkill -x OneClick" pkill -x OneClick
elif pgrep -f "OneClick.app/Contents/MacOS/OneClick" > /dev/null 2>&1; then
  ONECLICK_RUNNING_APP=true
  announce_then_run "pkill -f OneClick.app/Contents/MacOS/OneClick" pkill -f "OneClick.app/Contents/MacOS/OneClick"
fi
[[ "$ONECLICK_RUNNING_APP" == true ]] || info "  not running   (settings app)"

if pgrep -f "$ONECLICK_APPEX_NAME" > /dev/null 2>&1; then
  announce_then_run "pkill -f $ONECLICK_APPEX_NAME" pkill -f "$ONECLICK_APPEX_NAME"
else
  info "  not running   (Finder extension)"
fi

info "2. Registrations"
announce_then_run "pluginkit -e ignore -i $ONECLICK_EXTENSION_ID" \
  "$ONECLICK_PLUGINKIT" -e ignore -i "$ONECLICK_EXTENSION_ID"
while IFS= read -r ONECLICK_APP; do
  [[ -n "$ONECLICK_APP" ]] || continue
  announce_then_run "lsregister -u $ONECLICK_APP" "$ONECLICK_LSREGISTER" -u "$ONECLICK_APP"
done <<< "$ONECLICK_APPS"
info "  note          if the extension is still enabled in System Settings,"
info "                turn it off there first: 通用 → 登录项与扩展 → 文件提供程序"

info "3. Application bundles"
oneclick_report "$ONECLICK_APPS" "application" || oneclick_fail "one or more application bundles could not be removed"

info "4. Data"
oneclick_remove_shared_directory || oneclick_fail "could not remove the shared configuration directory"
for ONECLICK_CONTAINER in \
  "$ONECLICK_HOME/Library/Containers/$ONECLICK_APP_ID" \
  "$ONECLICK_HOME/Library/Containers/$ONECLICK_EXTENSION_ID"; do
  remove "$ONECLICK_CONTAINER" "sandbox container" || oneclick_fail "could not remove $ONECLICK_CONTAINER"
done
for ONECLICK_PREFERENCE in \
  "$ONECLICK_HOME/Library/Preferences/$ONECLICK_APP_ID.plist" \
  "$ONECLICK_HOME/Library/Preferences/$ONECLICK_EXTENSION_ID.plist" \
  "$ONECLICK_HOME/Library/Saved Application State/$ONECLICK_APP_ID.savedState" \
  "$ONECLICK_HOME/Library/Saved Application State/$ONECLICK_EXTENSION_ID.savedState" \
  "$ONECLICK_HOME/Library/Caches/$ONECLICK_APP_ID" \
  "$ONECLICK_HOME/Library/Caches/$ONECLICK_EXTENSION_ID"; do
  remove "$ONECLICK_PREFERENCE" || oneclick_fail "could not remove $ONECLICK_PREFERENCE"
done
echo
if [[ "$ONECLICK_APPLY" == false ]]; then
  info "Report only: nothing was changed."
  info "Re-run with --apply to remove the $ONECLICK_REMOVED item(s) above."
else
  info "Removed $ONECLICK_REMOVED item(s)."
  info "Restart Finder to drop the toolbar button and any cached extension:"
  info "    killall Finder"
fi
