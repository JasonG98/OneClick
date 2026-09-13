#!/bin/bash
# Remove every trace OneClick leaves on this Mac, and the build products it
# leaves in this repository.
#
#   ./script/uninstall.sh                 show what would be removed (no changes)
#   ./script/uninstall.sh --apply         actually remove it
#   ./script/uninstall.sh --apply --build   ... and .build/ (Xcode's output)
#   ./script/uninstall.sh --apply --local-config
#                                         ... and config/Local.xcconfig (Team ID)
#
# The phases below are ordered, and the order matters:
#
#   1. stop the processes      the app, and the extension process Finder owns
#   2. retire the registrations LaunchServices and PluginKit, while the bundles
#                              they point at still exist to be unregistered
#   3. delete the bundles      every copy of OneClick.app for this bundle id
#   4. delete the data         App Group containers, sandbox containers, prefs
#
# Doing 4 before 2 leaves registrations pointing at nothing, which LaunchServices
# resolves by keeping a stale record; doing 1 last leaves a process running from
# a binary that no longer exists on disk.
#
# Nothing is removed without --apply. The default run is a report: it prints the
# same paths it would delete, so the run you act on is the run you read.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

ONECLICK_APP_ID="local.oneclick.app"
ONECLICK_EXTENSION_ID="local.oneclick.app.finder"
ONECLICK_APPEX_NAME="OneClickFinder.appex"

ONECLICK_ROOT="$(oneclick_root)"
ONECLICK_HOME="${HOME:-}"
[[ -n "$ONECLICK_HOME" ]] || oneclick_fail "HOME is not set"

# Absolute paths rather than lookups in PATH: `pluginkit` is also a Homebrew
# formula, and removing the wrong tool's registrations is not recoverable.
# Overridable so the tests can run the script without touching this Mac.
ONECLICK_LSREGISTER="${ONECLICK_LSREGISTER:-/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister}"
ONECLICK_PLUGINKIT="${ONECLICK_PLUGINKIT:-/usr/bin/pluginkit}"

ONECLICK_APPLY=false
ONECLICK_BUILD=false
ONECLICK_LOCAL_CONFIG=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) ONECLICK_APPLY=true; shift ;;
    --build) ONECLICK_BUILD=true; shift ;;
    --local-config) ONECLICK_LOCAL_CONFIG=true; shift ;;
    -h|--help)
      sed -n '2,22p' "${BASH_SOURCE[0]}" | cut -c 3-
      exit 0 ;;
    *) oneclick_fail_usage "unknown argument: $1" ;;
  esac
done

ONECLICK_REMOVED=0
ONECLICK_SKIPPED=0

info() { printf '%s\n' "$1"; }

# One line per item. In a report the item is listed but nothing is touched; with
# --apply the same line is printed after the removal succeeds.
# Returns non-zero on failure rather than exiting: `oneclick_report` below runs
# it inside a subshell, where an `exit` would only end the subshell and let the
# script report success over a removal that failed.
remove() {
  local ONECLICK_TARGET="$1" ONECLICK_LABEL="${2:-}"
  if [[ ! -e "$ONECLICK_TARGET" ]]; then
    ONECLICK_SKIPPED=$((ONECLICK_SKIPPED + 1))
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

# A system call that cannot be reported the way a file can. Reported in both
# modes; only --apply runs it.
announce_then_run() {
  local ONECLICK_LABEL="$1"; shift
  if [[ "$ONECLICK_APPLY" == false ]]; then
    info "  would run     $ONECLICK_LABEL"
    return 0
  fi
  "$@" > /dev/null 2>&1 || true
}

# Every copy of the app this bundle id owns, from both places one can exist:
# the install locations, and whatever LaunchServices still has registered
# (a development build under .build/, or a copy the user moved).
oneclick_app_paths() {
  local ONECLICK_CANDIDATE ONECLICK_IDENTIFIER
  {
    for ONECLICK_CANDIDATE in "/Applications/OneClick.app" "$ONECLICK_HOME/Applications/OneClick.app"; do
      [[ -d "$ONECLICK_CANDIDATE" ]] && printf '%s\n' "$ONECLICK_CANDIDATE"
    done
    if [[ -x "$ONECLICK_LSREGISTER" ]]; then
      # `path:` and `identifier:` are separate top-level records in the dump, so
      # the identifier that follows a path is the one that owns it. The
      # parentheses are load-bearing: without them awk parses `$2 == wanted`
      # as an argument of print.
      "$ONECLICK_LSREGISTER" -dump 2>/dev/null |
        awk -v wanted="$ONECLICK_APP_ID" '
          /^path:/ { path = $2 }
          /^identifier:/ { if ($2 == wanted) { print path } }' || true
    fi
    # The development build, whether or not it is still registered.
    for ONECLICK_CANDIDATE in "$ONECLICK_ROOT"/.build/*/Build/Products/*/"OneClick.app"; do
      [[ -d "$ONECLICK_CANDIDATE" ]] && printf '%s\n' "$ONECLICK_CANDIDATE"
    done
  } | while IFS= read -r ONECLICK_CANDIDATE; do
    [[ -n "$ONECLICK_CANDIDATE" ]] || continue
    # An identifier check rather than a name check: the path is only ours if the
    # bundle at it really is OneClick. This is what keeps a directory that merely
    # looks like ours out of the removal list.
    ONECLICK_IDENTIFIER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' \
      "$ONECLICK_CANDIDATE/Contents/Info.plist" 2>/dev/null || true)"
    if [[ "$ONECLICK_IDENTIFIER" == "$ONECLICK_APP_ID" ]]; then
      printf '%s\n' "$ONECLICK_CANDIDATE"
    else
      printf 'foreign\n%s\n' "$ONECLICK_CANDIDATE" >&2
    fi
  done
}

# App Group containers owned by OneClick. The name cannot be trusted -- a team
# rename leaves one behind under the old prefix, and `latest` is not reliable
# either -- so ownership is read from the container manager's own metadata.
oneclick_group_containers() {
  local ONECLICK_CONTAINER ONECLICK_CREATOR
  for ONECLICK_CONTAINER in "$ONECLICK_HOME"/Library/Group\ Containers/*/; do
    [[ -d "$ONECLICK_CONTAINER" ]] || continue
    ONECLICK_CREATOR="$(/usr/bin/plutil -extract MCMMetadataCreator raw \
      "$ONECLICK_CONTAINER.com.apple.containermanagerd.metadata.plist" 2>/dev/null || true)"
    [[ "$ONECLICK_CREATOR" == "$ONECLICK_APP_ID" ]] && printf '%s\n' "${ONECLICK_CONTAINER%/}"
  done
}

# Prints one item per line through `remove`, remembering whether any of them
# failed. The status is returned, not raised: this runs inside a subshell, so an
# `exit` here would end the subshell and leave the script reporting success.
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

# ---------------------------------------------------------------- phase 1: stop
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

# The extension is a separate process Finder owns; it outlives the app, so a
# removal that skips it leaves a live process behind a deleted bundle.
if pgrep -f "$ONECLICK_APPEX_NAME" > /dev/null 2>&1; then
  announce_then_run "pkill -f $ONECLICK_APPEX_NAME" pkill -f "$ONECLICK_APPEX_NAME"
else
  info "  not running   (Finder extension)"
fi

# ------------------------------------------------------- phase 2: registrations
info "2. Registrations"
announce_then_run "pluginkit -e ignore -i $ONECLICK_EXTENSION_ID" \
  "$ONECLICK_PLUGINKIT" -e ignore -i "$ONECLICK_EXTENSION_ID"
while IFS= read -r ONECLICK_APP; do
  [[ -n "$ONECLICK_APP" ]] || continue
  announce_then_run "lsregister -u $ONECLICK_APP" "$ONECLICK_LSREGISTER" -u "$ONECLICK_APP"
done <<< "$(oneclick_app_paths 2>/dev/null || true)"
info "  note          if the extension is still enabled in System Settings,"
info "                turn it off there first: 通用 → 登录项与扩展 → 文件提供程序"

# ------------------------------------------------------------ phase 3: the app
info "3. Application bundles"
oneclick_report "$ONECLICK_APPS" "application" || oneclick_fail "one or more application bundles could not be removed"

# ----------------------------------------------------------------- phase 4: data
info "4. Data"
oneclick_report "$(oneclick_group_containers)" "App Group container" || oneclick_fail "one or more App Group containers could not be removed"
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
  "$ONECLICK_HOME/Library/Caches/$ONECLICK_EXTENSION_ID" \
  "$ONECLICK_HOME/Library/HTTPStorages/$ONECLICK_APP_ID" \
  "$ONECLICK_HOME/Library/WebKit/$ONECLICK_APP_ID"; do
  remove "$ONECLICK_PREFERENCE" || oneclick_fail "could not remove $ONECLICK_PREFERENCE"
done
# The app registers no login item and no background agent, so there is nothing
# in LaunchAgents: asserted here so a future one cannot be forgotten silently.
for ONECLICK_AGENT in "$ONECLICK_HOME"/Library/LaunchAgents/*oneclick*; do
  if [[ -e "$ONECLICK_AGENT" ]]; then
    remove "$ONECLICK_AGENT" "login item" || oneclick_fail "could not remove $ONECLICK_AGENT"
  fi
done

# ------------------------------------------------------------ phase 5: the repo
if [[ "$ONECLICK_BUILD" == true || "$ONECLICK_LOCAL_CONFIG" == true ]]; then
  info "5. Repository"
  if [[ "$ONECLICK_BUILD" == true ]]; then
    remove "$ONECLICK_ROOT/.build" "build products and logs" || oneclick_fail "could not remove $ONECLICK_ROOT/.build"
    remove "$ONECLICK_ROOT/dist" "release archives" || oneclick_fail "could not remove $ONECLICK_ROOT/dist"
  fi
  if [[ "$ONECLICK_LOCAL_CONFIG" == true ]]; then
    # Ignored, local-only, and trivially recreated; removed only on request.
    remove "$ONECLICK_ROOT/config/Local.xcconfig" "your Team ID" || oneclick_fail "could not remove config/Local.xcconfig"
  fi
fi

# ------------------------------------------------------------------- summary
echo
if [[ "$ONECLICK_APPLY" == false ]]; then
  info "Report only: nothing was changed."
  info "Re-run with --apply to remove the $ONECLICK_REMOVED item(s) above."
  [[ "$ONECLICK_BUILD" == true ]] || info "Add --build to include .build/ and dist/."
else
  info "Removed $ONECLICK_REMOVED item(s)."
  info "Restart Finder to drop the toolbar button and any cached extension:"
  info "    killall Finder"
fi
