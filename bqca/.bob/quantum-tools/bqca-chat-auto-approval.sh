#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BQCA_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"

# BQCA-BOB-SHELL-V2-DNA:BEGIN
# This trusted BQCA runtime tool is bound to AGENTS.md, the active central policy,
# current modes/rules/skills/tools, and the governed BQCA project root.
# BQCA-BOB-SHELL-V2-DNA:END
# BQCA-ACTIVE-CENTRAL-POLICY:BEGIN
# Resolve and preserve the active central policy. This helper selects only the
# supported Bob Shell chat auto-approval flag and does not alter quantum policy.
# BQCA-ACTIVE-CENTRAL-POLICY:END

usage() {
  cat <<'USAGE'
BQCA chat auto-approval capability helper

Usage:
  bqca-chat-auto-approval.sh flag --major <1|2> [--bob-bin <path>]
  bqca-chat-auto-approval.sh trust-flag --major <1|2> [--bob-bin <path>]
  bqca-chat-auto-approval.sh check --major <1|2> [--bob-bin <path>]
  bqca-chat-auto-approval.sh report [--bob-bin <path>]
USAGE
}

command_name="${1:-}"
[[ -n "$command_name" ]] || { usage; exit 2; }
shift || true
major=""
bob_bin="${BOB_BIN:-bob}"
while (($#)); do
  case "$1" in
    --major) (($# >= 2)) || { echo '--major requires a value' >&2; exit 2; }; major="$2"; shift 2 ;;
    --bob-bin) (($# >= 2)) || { echo '--bob-bin requires a value' >&2; exit 2; }; bob_bin="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

[[ -f "$BQCA_ROOT/.bob/custom_modes.yaml" && -f "$BQCA_ROOT/xLaunchpad.sh" ]] || {
  echo '[BQCA][ERROR] Chat auto-approval helper is not running from a valid BQCA root.' >&2
  exit 3
}
command -v "$bob_bin" >/dev/null 2>&1 || {
  echo "[BQCA][ERROR] Bob executable not found: $bob_bin" >&2
  exit 3
}

enabled="${BQCA_CHAT_AUTO_APPROVE:-1}"
case "$enabled" in 1|true|TRUE|on|ON|yes|YES) enabled=1 ;; *) enabled=0 ;; esac

help_text() {
  case "$1" in
    1) "$bob_bin" --help 2>&1 || true ;;
    2) "$bob_bin" chat --help 2>&1 || true ;;
    *) return 2 ;;
  esac
}

full_flag() {
  local requested_major="$1" help
  [[ "$enabled" -eq 1 ]] || return 0
  help="$(help_text "$requested_major")"
  case "$requested_major" in
    2)
      grep -q -- '--auto-approve' <<<"$help" || {
        echo '[BQCA][ERROR] Bob Shell 2.x chat does not advertise --auto-approve.' >&2
        return 4
      }
      printf '%s\n' '--auto-approve'
      ;;
    1)
      if grep -q -- '--auto-approve' <<<"$help"; then
        printf '%s\n' '--auto-approve'
      elif grep -q -- '--yolo' <<<"$help"; then
        printf '%s\n' '--yolo'
      else
        echo '[BQCA][ERROR] Bob Shell 1.x does not advertise full chat auto-approval (--auto-approve or --yolo).' >&2
        return 4
      fi
      ;;
    *) echo "Unsupported Bob major version: $requested_major" >&2; return 2 ;;
  esac
}

trust_flag() {
  local requested_major="$1" help
  help="$(help_text "$requested_major")"
  if grep -q -- '--trust' <<<"$help"; then
    printf '%s\n' '--trust'
  fi
}

case "$command_name" in
  flag)
    [[ "$major" =~ ^[12]$ ]] || { echo 'flag requires --major 1 or 2' >&2; exit 2; }
    full_flag "$major"
    ;;
  trust-flag)
    [[ "$major" =~ ^[12]$ ]] || { echo 'trust-flag requires --major 1 or 2' >&2; exit 2; }
    trust_flag "$major"
    ;;
  check)
    [[ "$major" =~ ^[12]$ ]] || { echo 'check requires --major 1 or 2' >&2; exit 2; }
    if [[ "$enabled" -eq 1 ]]; then
      full_flag "$major" >/dev/null
      if [[ "$major" -eq 2 ]]; then
        [[ "$(trust_flag 2)" == '--trust' ]] || {
          echo '[BQCA][ERROR] Bob Shell 2.x chat does not advertise --trust; trusted auto-approval cannot be enforced.' >&2
          exit 5
        }
      fi
    fi
    printf 'BQCA_CHAT_AUTO_APPROVAL=PASS major=%s enabled=%s\n' "$major" "$enabled"
    ;;
  report)
    version="$($bob_bin --version 2>&1 | head -n 1 || true)"
    printf '%s\n' '========================================================================================'
    printf '%s\n' 'BQCA TRUSTED CHAT AUTO-APPROVAL CAPABILITY REPORT'
    printf '%s\n' '========================================================================================'
    printf 'BQCA root              : %s\n' "$BQCA_ROOT"
    printf 'Bob executable         : %s\n' "$bob_bin"
    printf 'Bob version output     : %s\n' "$version"
    printf 'Production enabled     : %s\n' "$enabled"
    for m in 1 2; do
      flag="$(full_flag "$m" 2>/dev/null || true)"
      trust="$(trust_flag "$m" 2>/dev/null || true)"
      printf 'Bob %s.x approval flag : %s\n' "$m" "${flag:-UNAVAILABLE}"
      printf 'Bob %s.x trust flag    : %s\n' "$m" "${trust:-NOT ADVERTISED}"
    done
    printf '%s\n' '----------------------------------------------------------------------------------------'
    printf '%s\n' 'Scope: BQCA menu option 1 and option 5 chat sessions only.'
    printf '%s\n' 'Protected assets and destructive actions remain governed by BQCA safety rules.'
    printf '%s\n' '========================================================================================'
    ;;
  *) usage; exit 2 ;;
esac
# BQCA-TRUSTED-CHAT-AUTO-APPROVAL-v51.4:BEGIN
# Trusted BQCA chat sessions auto-approve routine project-scoped tool calls at
# session launch. This does not authorize secrets, destructive operations, Bob
# home/settings writes, external paths, or bypass of BQCA policy/safety gates.
# BQCA-TRUSTED-CHAT-AUTO-APPROVAL-v51.4:END
