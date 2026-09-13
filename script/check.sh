#!/bin/bash
# Fast, repeatable checks. No app launch, Finder restart or GUI automation.
#
#   ./script/check.sh                       Swift tests, script tests, icon check
#   ./script/check.sh --filter FinderMenu   ... one Swift suite, plus the rest
#   ./script/check.sh --icons               ... and re-verify the .icns ladder
#   ./script/check.sh --build               ... and compile the app and extension
#
# Anything that is not --build or --icons goes to `swift test`, so every SwiftPM
# flag keeps working here. This used to shell out to script/test.sh, which only
# existed to add the module cache and the scratch path below.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$(oneclick_root)"

ONECLICK_CHECK_BUILD=false
ONECLICK_CHECK_ICNS=false
ONECLICK_PASSTHROUGH=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --build) ONECLICK_CHECK_BUILD=true; shift ;;
    --icons) ONECLICK_CHECK_ICNS=true; shift ;;
    # Everything else belongs to `swift test`; pass it through untouched.
    *) ONECLICK_PASSTHROUGH+=("$1"); shift ;;
  esac
done

# The module cache and the scratch path are pinned inside the repository so a
# check never writes to the user's global caches and never races another build.
# bash 3.2 errors on an expanded empty array under `set -u`, hence the guard.
mkdir -p .build/module-cache .build/package-cache
ONECLICK_SWIFT_TEST=(
  swift test --scratch-path .build/core --cache-path .build/package-cache
)
if (( ${#ONECLICK_PASSTHROUGH[@]} > 0 )); then
  ONECLICK_SWIFT_TEST+=("${ONECLICK_PASSTHROUGH[@]}")
fi
CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache" "${ONECLICK_SWIFT_TEST[@]}"

tests/release-scripts/run_tests.sh

# Every generated icon file must still match assets/icon.svg. This is the check
# that catches "edited the SVG, forgot to regenerate", which is otherwise only
# visible by looking at the icon.
/usr/bin/python3 script/generate_icon.py --check
if [[ "$ONECLICK_CHECK_ICNS" == true ]]; then
  # Assembles the standalone .icns and re-reads all ten rungs, which is the part
  # that has historically caught a silently truncated container. The build does
  # not use this file; it is a slower check, so it is opt-in.
  /usr/bin/python3 script/generate_icon.py --icns > /dev/null
  echo "Verified the standalone .icns (all ten rungs)"
fi

for ONECLICK_SCRIPT in script/*.sh tests/release-scripts/*.sh; do
  bash -n "$ONECLICK_SCRIPT"
done

if [[ "$ONECLICK_CHECK_BUILD" == true ]]; then
  ONECLICK_CHECK_APP="$PWD/.build/Checks/Build/Products/Debug/OneClick.app"
  ONECLICK_EXIT_STATUS=0
  # Xcode registers macOS apps even for unsigned builds. Always undo that step,
  # including when the build itself fails, so URL routing keeps the live app.
  # A copy left behind here would not break anything -- build_and_run.sh retires
  # every other .build/ registration of the same bundle id -- but undoing it is
  # what keeps that retirement from having to.
  #
  # The trap must not call `exit` itself: doing so replaces the status that was
  # already recorded, and because every `if`/`[[ ]]`/command resets `$?`, a
  # failing build used to be reported as a passing check.
  oneclick_cleanup_check_registration() {
    local ONECLICK_UNREGISTER_OUTPUT
    [[ -d "$ONECLICK_CHECK_APP" ]] || return 0
    if ! ONECLICK_UNREGISTER_OUTPUT="$(/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister -u "$ONECLICK_CHECK_APP" 2>&1)"; then
      # An incremental build can skip registration. -10814 means the app is
      # already absent (kLSApplicationNotFoundErr), so cleanup is complete.
      if [[ "$ONECLICK_UNREGISTER_OUTPUT" != *": -10814"* ]]; then
        echo "$ONECLICK_UNREGISTER_OUTPUT" >&2
        echo "Could not unregister check bundle: $ONECLICK_CHECK_APP" >&2
        ONECLICK_EXIT_STATUS=1
      fi
    fi
  }
  trap oneclick_cleanup_check_registration EXIT
  mkdir -p .build/logs
  if ! xcodebuild -project OneClick.xcodeproj -scheme OneClick -configuration Debug \
    -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/Checks \
    ARCHS=arm64 ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO build \
    > .build/logs/check-build.log 2>&1; then
    tail -80 .build/logs/check-build.log >&2
    ONECLICK_EXIT_STATUS=1
  else
    echo "App and Finder extension compiled for arm64 (unsigned, not launched)."
  fi
  exit "$ONECLICK_EXIT_STATUS"
fi
