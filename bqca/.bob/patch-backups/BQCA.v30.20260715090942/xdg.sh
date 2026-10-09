#!/usr/bin/env bash

# Silent, non-blocking XDG opener prerequisite check/install helper.
# Requirement:
#   - If xdg-open is installed correctly: do nothing.
#   - If xdg-open is missing or unusable: silently attempt to install xdg-utils.
#   - No hard stop.
#   - No explicit exit statement, so parent launcher logic can continue when sourced,
#     and normal shell script completion occurs when executed.

# Do not use set -e. This file must never hard-stop a parent flow.

_xdg_v5_has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

_xdg_v5_is_wsl() {
  grep -qiE '(microsoft|wsl)' /proc/version 2>/dev/null || [ -n "${WSL_DISTRO_NAME:-}" ]
}

_xdg_v5_xdg_ok() {
  _xdg_v5_has_cmd xdg-open || return 1

  # If xdg-open exists, treat it as valid for native Linux.
  # For WSL, also accept it if a Windows launcher is reachable because many xdg-open
  # wrappers delegate to powershell.exe, cmd.exe, or wslview.
  if _xdg_v5_is_wsl; then
    _xdg_v5_has_cmd powershell.exe || _xdg_v5_has_cmd cmd.exe || _xdg_v5_has_cmd wslview || return 1
  fi

  return 0
}

_xdg_v5_install_silent() {
  # macOS does not use xdg-utils; open is the native launcher.
  if [ "$(uname -s 2>/dev/null)" = "Darwin" ]; then
    return 0
  fi

  # Debian/Ubuntu/WSL Ubuntu
  if _xdg_v5_has_cmd apt-get; then
    if _xdg_v5_has_cmd sudo; then
      sudo DEBIAN_FRONTEND=noninteractive apt-get update -y >/dev/null 2>&1
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -y xdg-utils >/dev/null 2>&1
    else
      DEBIAN_FRONTEND=noninteractive apt-get update -y >/dev/null 2>&1
      DEBIAN_FRONTEND=noninteractive apt-get install -y xdg-utils >/dev/null 2>&1
    fi
    return 0
  fi

  # Fedora/RHEL/CentOS/Rocky/Alma
  if _xdg_v5_has_cmd dnf; then
    if _xdg_v5_has_cmd sudo; then
      sudo dnf install -y xdg-utils >/dev/null 2>&1
    else
      dnf install -y xdg-utils >/dev/null 2>&1
    fi
    return 0
  fi

  if _xdg_v5_has_cmd yum; then
    if _xdg_v5_has_cmd sudo; then
      sudo yum install -y xdg-utils >/dev/null 2>&1
    else
      yum install -y xdg-utils >/dev/null 2>&1
    fi
    return 0
  fi

  # openSUSE/SLES fallback
  if _xdg_v5_has_cmd zypper; then
    if _xdg_v5_has_cmd sudo; then
      sudo zypper --non-interactive install xdg-utils >/dev/null 2>&1
    else
      zypper --non-interactive install xdg-utils >/dev/null 2>&1
    fi
    return 0
  fi

  # Alpine fallback
  if _xdg_v5_has_cmd apk; then
    if _xdg_v5_has_cmd sudo; then
      sudo apk add --no-cache xdg-utils >/dev/null 2>&1
    else
      apk add --no-cache xdg-utils >/dev/null 2>&1
    fi
    return 0
  fi

  return 0
}

# Main silent check/install. No output. No explicit exit.
if ! _xdg_v5_xdg_ok >/dev/null 2>&1; then
  _xdg_v5_install_silent >/dev/null 2>&1 || true
fi

# When sourced, remove helper functions to avoid polluting the parent shell.
unset -f _xdg_v5_has_cmd 2>/dev/null || true
unset -f _xdg_v5_is_wsl 2>/dev/null || true
unset -f _xdg_v5_xdg_ok 2>/dev/null || true
unset -f _xdg_v5_install_silent 2>/dev/null || true

# Load persistent Bob Shell version for appliance version-aware paths.
if [[ -z "${BOB_VERSION:-}" ]]; then
  _BOB_VERSION_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [[ -f "${_BOB_VERSION_SCRIPT_DIR}/bob-version.sh" ]]; then
    # shellcheck source=/dev/null
    source "${_BOB_VERSION_SCRIPT_DIR}/bob-version.sh"
  fi
  unset _BOB_VERSION_SCRIPT_DIR
fi
