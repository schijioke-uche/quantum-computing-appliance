#!/usr/bin/env bash
#===============================================================================
# @Author: Dr. Jeffrey Chijioke-Uche, IBM Computer Scientist
# @Description: Bob Shell version detector for IBM Bob appliance launchers
# @Version: v${BOB_VERSION}
#===============================================================================

_bob_version_command="${BOB_BIN:-bob}"
_bob_version_raw=""

if [[ -n "${BOB_VERSION:-}" && "${BOB_VERSION}" != "unknown" ]]; then
  export BOB_VERSION
  return 0 2>/dev/null || exit 0
fi

if ! command -v "${_bob_version_command}" >/dev/null 2>&1; then
  printf '[bob-version] ERROR: Bob executable not found: %s\n' "${_bob_version_command}" >&2
  return 1 2>/dev/null || exit 1
fi

_bob_version_raw="$(${_bob_version_command} --version 2>/dev/null | head -n 1 | tr -d '\r' || true)"
BOB_VERSION="$(printf '%s\n' "${_bob_version_raw}" | grep -Eo '[0-9]+([.][0-9]+){1,3}([-.][A-Za-z0-9]+)?' | head -n 1 || true)"

if [[ -z "${BOB_VERSION}" ]]; then
  BOB_VERSION="$(printf '%s\n' "${_bob_version_raw}" | awk '{print $NF}' | tr -cd 'A-Za-z0-9._-')"
fi

if [[ -z "${BOB_VERSION}" ]]; then
  printf '[bob-version] ERROR: Unable to determine Bob version from: %s\n' "${_bob_version_raw:-<empty>}" >&2
  return 1 2>/dev/null || exit 1
fi

export BOB_VERSION
unset _bob_version_command _bob_version_raw
