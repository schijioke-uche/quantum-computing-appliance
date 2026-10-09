#!/usr/bin/env bash
set -u

# BQCA XDG helper v30
# Default behavior is check-only. Host package installation is never silent and
# is permitted only when BQCA_ALLOW_HOST_PACKAGE_INSTALL=1 is explicitly set.

_bqca_xdg_have() { command -v "$1" >/dev/null 2>&1; }

_bqca_xdg_check() {
  if [[ "$(uname -s 2>/dev/null || true)" == "Darwin" ]]; then
    _bqca_xdg_have open
    return
  fi
  _bqca_xdg_have xdg-open
}

_bqca_xdg_install() {
  [[ "${BQCA_ALLOW_HOST_PACKAGE_INSTALL:-0}" == "1" ]] || {
    printf '[BQCA] xdg-open is unavailable. Automatic host installation is disabled.\n' >&2
    printf '[BQCA] Install xdg-utils manually, or explicitly set BQCA_ALLOW_HOST_PACKAGE_INSTALL=1.\n' >&2
    return 1
  }

  printf '[BQCA] Installing xdg-utils with explicit operator approval.\n'
  if _bqca_xdg_have apt-get; then
    if [[ "$(id -u)" -eq 0 ]]; then
      DEBIAN_FRONTEND=noninteractive apt-get update -y && DEBIAN_FRONTEND=noninteractive apt-get install -y xdg-utils
    elif _bqca_xdg_have sudo; then
      sudo DEBIAN_FRONTEND=noninteractive apt-get update -y && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y xdg-utils
    else
      return 1
    fi
  elif _bqca_xdg_have dnf; then
    [[ "$(id -u)" -eq 0 ]] && dnf install -y xdg-utils || sudo dnf install -y xdg-utils
  elif _bqca_xdg_have yum; then
    [[ "$(id -u)" -eq 0 ]] && yum install -y xdg-utils || sudo yum install -y xdg-utils
  elif _bqca_xdg_have zypper; then
    [[ "$(id -u)" -eq 0 ]] && zypper --non-interactive install xdg-utils || sudo zypper --non-interactive install xdg-utils
  elif _bqca_xdg_have apk; then
    [[ "$(id -u)" -eq 0 ]] && apk add --no-cache xdg-utils || sudo apk add --no-cache xdg-utils
  else
    printf '[BQCA] No supported package manager was found.\n' >&2
    return 1
  fi
}

case "${1:---check}" in
  --check)
    _bqca_xdg_check || true
    ;;
  --install)
    _bqca_xdg_check || _bqca_xdg_install
    ;;
  *)
    printf 'Usage: %s [--check|--install]\n' "${BASH_SOURCE[0]}" >&2
    return 2 2>/dev/null || exit 2
    ;;
esac

unset -f _bqca_xdg_have _bqca_xdg_check _bqca_xdg_install 2>/dev/null || true
