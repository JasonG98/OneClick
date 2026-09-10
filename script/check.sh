#!/bin/bash
# Fast, repeatable checks. No app launch, Finder restart or GUI automation.
set -euo pipefail
ONECLICK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ONECLICK_ROOT"
ONECLICK_CHECK_BUILD=false
if [[ "${1:-}" == "--build" ]]; then
  ONECLICK_CHECK_BUILD=true
  shift
fi

./script/test.sh "$@"
tests/release-scripts/run_tests.sh
for ONECLICK_SCRIPT in script/*.sh tests/release-scripts/*.sh; do
  bash -n "$ONECLICK_SCRIPT"
done

if [[ "$ONECLICK_CHECK_BUILD" == true ]]; then
  ONECLICK_CHECK_APP="$ONECLICK_ROOT/.build/Checks/Build/Products/Debug/OneClick.app"
  ONECLICK_EXIT_STATUS=0
  # Xcode registers macOS apps even for unsigned builds. Always undo that step,
  # including when the build itself fails, so URL routing keeps the live app.
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
