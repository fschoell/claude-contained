#!/usr/bin/env bash
#
# Tests for flavor image resolution and build helpers in the launchers.
#
# The launchers are sourced with CLAUDE_CONTAINED_LIB_ONLY=1, which parses the
# flags and resolves the flavor image tag, then returns before launching a
# container. No container runtime is required.
#
# Usage: tests/flavor.test.sh
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(dirname "$here")"

fails=0
_check() { # _check "description" <rc-that-should-be-0>
  if [[ "$2" -eq 0 ]]; then
    echo "  PASS: $1"
  else
    echo "  FAIL: $1"
    fails=$((fails + 1))
  fi
}

# Resolve $image_ref from a lib-only sourcing of the given launcher + args.
resolved_ref() {
  local script="$1"; shift
  (
    CLAUDE_CONTAINED_LIB_ONLY=1
    source "${repo_root}/${script}" "$@" >/dev/null 2>&1
    printf '%s' "${image_ref:-}"
  )
}

for script in claude-contained claude-docked; do
  echo "== ${script} flavor image resolution =="

  ref="$(resolved_ref "$script")"
  [[ "$ref" == "claude-contained-base:latest" ]]
  _check "no flavor -> base image (got: ${ref})" $?

  ref="$(resolved_ref "$script" --flavor go)"
  [[ "$ref" == "claude-contained-go:latest" ]]
  _check "--flavor go -> go image (got: ${ref})" $?

  ref="$(resolved_ref "$script" -f go)"
  [[ "$ref" == "claude-contained-go:latest" ]]
  _check "-f go (short) -> go image (got: ${ref})" $?

  ref="$(resolved_ref "$script" --flavor web)"
  [[ "$ref" == "claude-contained-web:latest" ]]
  _check "--flavor web -> web image (got: ${ref})" $?

  ( CLAUDE_CONTAINED_LIB_ONLY=1; source "${repo_root}/${script}" >/dev/null 2>&1; declare -F image_exists >/dev/null )
  _check "image_exists helper is defined" $?

  ( CLAUDE_CONTAINED_LIB_ONLY=1; source "${repo_root}/${script}" >/dev/null 2>&1; declare -F run_build build_image >/dev/null )
  _check "run_build/build_image helpers are defined" $?

  # Unknown flavor is rejected with exit 2 (repo is reachable in-tree).
  ( CLAUDE_CONTAINED_LIB_ONLY=1; source "${repo_root}/${script}" --flavor bogus >/dev/null 2>&1 )
  [[ $? -eq 2 ]]
  _check "unknown flavor rejected (exit 2)" $?

  # --flavor requires an argument.
  ( CLAUDE_CONTAINED_LIB_ONLY=1; source "${repo_root}/${script}" --flavor >/dev/null 2>&1 )
  [[ $? -eq 2 ]]
  _check "--flavor without value rejected (exit 2)" $?
done

if [[ $fails -eq 0 ]]; then
  echo "All flavor tests passed."
  exit 0
else
  echo "FAILED: ${fails} assertion(s) failed."
  exit 1
fi
