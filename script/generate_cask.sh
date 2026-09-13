#!/bin/bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$(oneclick_root)"

usage() {
  echo "Usage: $0 VERSION HTTPS_RELEASE_URL HTTPS_HOMEPAGE [ARCHIVE_PATH]" >&2
  echo "  ARCHIVE_PATH defaults to dist/OneClick-VERSION.zip, which is what release.sh writes." >&2
}

fail() {
  oneclick_fail "$1"
}

# The same shape as lib.sh's `oneclick_is_version`, and deliberately duplicated
# rather than shared: what this guards is not "is it a version" but "is it safe to
# splice between quotes in the generated Ruby". Leading zeros are rejected there
# for the same reason the URL rule below rejects quotes.
is_https_url() {
  [[ "$1" =~ ^https://([A-Za-z0-9-]+\.)+[A-Za-z0-9-]{2,63}(:[0-9]{1,5})?(/[A-Za-z0-9._~:/?%+,\&=@-]*)?$ ]]
}

if [[ $# -ne 3 && $# -ne 4 ]]; then
  usage
  exit 2
fi

VERSION="$1"
RELEASE_URL="$2"
HOMEPAGE="$3"

oneclick_is_version "$VERSION" || fail "VERSION must be a release version such as 1.2.3 (without a v prefix)"
is_https_url "$RELEASE_URL" || fail "HTTPS_RELEASE_URL must be a plain HTTPS URL without quotes, fragments, interpolation, or credentials"
is_https_url "$HOMEPAGE" || fail "HTTPS_HOMEPAGE must be a plain HTTPS URL without quotes, fragments, interpolation, or credentials"

# Defaulting the archive keeps the documented flow one command: release.sh writes
# dist/OneClick-<version>.zip, so asking the caller to repeat that path (or to
# find it) is only a chance to generate a Cask for the wrong file. Both branches
# end at the same check, so a path that does not exist is one clear error.
ARCHIVE_PATH="${4:-${ONECLICK_DIST_DIR:-$PWD/dist}/OneClick-$VERSION.zip}"
if [[ ! -f "$ARCHIVE_PATH" ]]; then
  if [[ $# -eq 4 ]]; then
    fail "ARCHIVE_PATH does not name an existing file: $ARCHIVE_PATH"
  fi
  fail "no archive at $ARCHIVE_PATH; run ./script/release.sh $VERSION first, or pass ARCHIVE_PATH"
fi

HASH_OUTPUT="$(shasum -a 256 -- "$ARCHIVE_PATH")"
SHA256="${HASH_OUTPUT%% *}"
[[ "$SHA256" =~ ^[0-9a-f]{64}$ ]] || fail "could not calculate a SHA-256 for ARCHIVE_PATH"

cat <<EOF
cask "oneclick" do
  version "$VERSION"
  sha256 "$SHA256"

  url "$RELEASE_URL"
  name "OneClick"
  desc "Open Finder selections in configured applications and copy absolute paths"
  homepage "$HOMEPAGE"

  depends_on arch: :arm64
  depends_on macos: :tahoe

  app "OneClick.app"
end
EOF
