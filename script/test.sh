#!/bin/bash
set -euo pipefail
ONECLICK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ONECLICK_ROOT"
mkdir -p .build/module-cache .build/package-cache
CLANG_MODULE_CACHE_PATH="$ONECLICK_ROOT/.build/module-cache" \
  swift test --scratch-path .build/core --cache-path .build/package-cache "$@"
