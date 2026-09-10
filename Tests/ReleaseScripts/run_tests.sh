#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
exec python3 -m unittest discover \
  --start-directory "$ROOT/Tests/ReleaseScripts" \
  --pattern 'test_*.py' \
  --verbose
