#!/usr/bin/env bash
# BQCA Bob Shell version detector v30
# Author: Dr. Jeffrey Chijioke-Uche, IBM Computer Scientist

_bqca_bob_bin="${BOB_BIN:-bob}"
_bqca_configured_version="${BOB_VERSION:-}"
_bqca_version_raw=""
_bqca_detected_version=""

if command -v "$_bqca_bob_bin" >/dev/null 2>&1; then
  _bqca_version_raw="$("$_bqca_bob_bin" --version 2>/dev/null | head -n 1 | tr -d '\r' || true)"
  _bqca_detected_version="$(printf '%s\n' "$_bqca_version_raw" | grep -Eo '[0-9]+([.][0-9]+){1,3}([-.][A-Za-z0-9]+)?' | head -n 1 || true)"
fi

if [[ -n "$_bqca_detected_version" ]]; then
  BOB_VERSION="$_bqca_detected_version"
elif [[ -n "$_bqca_configured_version" && "$_bqca_configured_version" != "unknown" ]]; then
  BOB_VERSION="$_bqca_configured_version"
else
  printf '[bob-version] ERROR: Unable to determine Bob version.\n' >&2
  return 1 2>/dev/null || exit 1
fi

export BOB_VERSION
unset _bqca_bob_bin _bqca_configured_version _bqca_version_raw _bqca_detected_version
