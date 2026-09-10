#!/bin/bash
set -euo pipefail

usage() {
  echo "Usage: $0 VERSION HTTPS_RELEASE_URL HTTPS_HOMEPAGE ARCHIVE_PATH" >&2
}

fail() {
  echo "generate_cask.sh: $1" >&2
  exit 1
}

is_release_version() {
  [[ "$1" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]
}

is_https_url() {
  [[ "$1" =~ ^https://([A-Za-z0-9-]+\.)+[A-Za-z0-9-]{2,63}(:[0-9]{1,5})?(/[A-Za-z0-9._~:/?%+,\&=@-]*)?$ ]]
}

if [[ $# -ne 4 ]]; then
  usage
  exit 2
fi

VERSION="$1"
RELEASE_URL="$2"
HOMEPAGE="$3"
ARCHIVE_PATH="$4"

is_release_version "$VERSION" || fail "VERSION must be a release version such as 1.2.3 (without a v prefix)"
is_https_url "$RELEASE_URL" || fail "HTTPS_RELEASE_URL must be a plain HTTPS URL without quotes, fragments, interpolation, or credentials"
is_https_url "$HOMEPAGE" || fail "HTTPS_HOMEPAGE must be a plain HTTPS URL without quotes, fragments, interpolation, or credentials"
[[ -f "$ARCHIVE_PATH" ]] || fail "ARCHIVE_PATH does not name an existing file: $ARCHIVE_PATH"

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
