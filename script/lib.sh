#!/bin/bash
# Shared helpers for the scripts in this directory.
#
# Source it, do not run it:
#     source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
#
# Everything here is a pure function: sourcing it must not change the caller's
# working directory, options, or exit status, so each script stays readable on
# its own. That also keeps `check.sh`'s `bash -n` sweep over `script/*.sh`
# meaningful -- this file is meant to be parsed, never executed.
#
# macOS ships bash 3.2: no `${var,,}`, no `mapfile`, and under `set -u` an
# expanded empty array is an error rather than an empty string. Every helper
# below is written for that shell.

# The repository root, derived from this file rather than the caller's cwd.
oneclick_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}

# The first file on the call stack that is not this one.
#
# `${BASH_SOURCE[1]}` is not enough on its own: when `oneclick_require_env` below
# reports, the caller one frame up is this file, and the message would be blamed
# on `lib.sh`. Skipping every frame that belongs to this file finds the script
# that actually asked.
oneclick_caller() {
  local oneclick_index=0
  while [[ -n "${BASH_SOURCE[$oneclick_index]:-}" ]]; do
    if [[ "${BASH_SOURCE[$oneclick_index]}" != *"lib.sh" ]]; then
      basename "${BASH_SOURCE[$oneclick_index]}"
      return 0
    fi
    oneclick_index=$((oneclick_index + 1))
  done
  echo "lib.sh"
}

# `<calling script>: <message>` on stderr, then exit 1: the script ran but the
# work could not be done.
oneclick_fail() {
  echo "$(oneclick_caller): $1" >&2
  exit 1
}

# As `oneclick_fail`, but exit 2, for a caller that got the invocation itself
# wrong -- the same status a wrong argument count uses.
oneclick_fail_usage() {
  echo "$(oneclick_caller): $1" >&2
  exit 2
}

# All of the named environment variables must be set and non-empty.
#
# Reports every missing name at once, because fixing them one per run is exactly
# the kind of friction that makes a script feel broken.
oneclick_require_env() {
  local oneclick_name oneclick_missing=()
  for oneclick_name in "$@"; do
    [[ -n "${!oneclick_name:-}" ]] || oneclick_missing+=("$oneclick_name")
  done
  if (( ${#oneclick_missing[@]} > 0 )); then
    oneclick_fail_usage "missing required input: ${oneclick_missing[*]}"
  fi
}

# A plain MAJOR.MINOR.PATCH release version, without a `v` prefix.
#
# Leading zeros are rejected: `01.2.3` is not a version anyone means to type, and
# accepting it would let a typo reach a signed release's MARKETING_VERSION.
oneclick_is_version() {
  [[ "$1" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]
}
