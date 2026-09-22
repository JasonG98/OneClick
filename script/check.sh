#!/bin/bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

ONECLICK_CHECK_BUILD=false
ONECLICK_PASSTHROUGH=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --build) ONECLICK_CHECK_BUILD=true; shift ;;
    *) ONECLICK_PASSTHROUGH+=("$1"); shift ;;
  esac
done

mkdir -p .build/module-cache .build/package-cache
ONECLICK_SWIFT_TEST=(
  swift test --scratch-path .build/core --cache-path .build/package-cache
)
if (( ${#ONECLICK_PASSTHROUGH[@]} > 0 )); then
  ONECLICK_SWIFT_TEST+=("${ONECLICK_PASSTHROUGH[@]}")
fi
CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache" "${ONECLICK_SWIFT_TEST[@]}"

python3 -m unittest discover -s tests/release-scripts -p 'test_*.py'

for ONECLICK_SCRIPT in script/*.sh; do
  bash -n "$ONECLICK_SCRIPT"
done

if [[ "$ONECLICK_CHECK_BUILD" == true ]]; then
  ONECLICK_CHECK_APP="$PWD/.build/Checks/Build/Products/Debug/OneClick.app"
  ONECLICK_EXIT_STATUS=0
  oneclick_cleanup_check_registration() {
    local ONECLICK_UNREGISTER_OUTPUT
    [[ -d "$ONECLICK_CHECK_APP" ]] || return 0
    if ! ONECLICK_UNREGISTER_OUTPUT="$(/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister -u "$ONECLICK_CHECK_APP" 2>&1)"; then
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
