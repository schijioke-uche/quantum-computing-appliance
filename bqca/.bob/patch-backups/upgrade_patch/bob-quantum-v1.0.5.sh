#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

#===============================================================================
# TERMINAL COLOR INITIALIZATION
# Must happen before sourcing any helper script because set -u fails if CYAN,
# RESET, BOLD, etc. are referenced before assignment.
#===============================================================================
BOLD=""
RESET=""
BLUE=""
CYAN=""
GREEN=""
YELLOW=""
MAGENTA=""
RED=""

if [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
  BOLD="$(tput bold 2>/dev/null || true)"
  RESET="$(tput sgr0 2>/dev/null || true)"
  BLUE="$(tput setaf 4 2>/dev/null || true)"
  CYAN="$(tput setaf 6 2>/dev/null || true)"
  GREEN="$(tput setaf 2 2>/dev/null || true)"
  YELLOW="$(tput setaf 3 2>/dev/null || true)"
  MAGENTA="$(tput setaf 5 2>/dev/null || true)"
  RED="$(tput setaf 1 2>/dev/null || true)"
fi

export BOLD RESET BLUE CYAN GREEN YELLOW MAGENTA RED

# Load persistent Bob Shell version for appliance version-aware paths.
if [[ -z "${BOB_VERSION:-}" ]]; then
  _BOB_VERSION_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [[ -f "${_BOB_VERSION_SCRIPT_DIR}/bob-version.sh" ]]; then
    # shellcheck source=/dev/null
    source "${_BOB_VERSION_SCRIPT_DIR}/bob-version.sh"
  fi
  unset _BOB_VERSION_SCRIPT_DIR
fi

#===============================================================================
# @Author: Dr. Jeffrey Chijioke-Uche, IBM Computer Scientist
# @Description: Launchpad for interacting with IBM Bob Quantum Computing Agent (QCA)
# @Version: v${BOB_VERSION}.Q18
#===============================================================================

# shellcheck source=/dev/null
source "$SCRIPT_DIR/tls-control.sh"

set -a
# shellcheck source=/dev/null
source "$SCRIPT_DIR/.env"
set +a

date_time_stamp() {
  TZ="America/New_York" date "+%Y-%m-%d %H:%M:%S %Z"
}

#====================================================================================
# This script provides a launchpad menu for interacting with IBM Bob.
#====================================================================================
BOB_BIN="${BOB_BIN:-bob}"
INITIAL_PROMPT="${*:-What quantum computing code should I write?}"
BOB_INSTANCE_ID="${BOB_INSTANCE_ID}"
BOB_INCLUDED_DIRECTORY="${BOB_INCLUDED_DIRECTORY}"

export BOB_INSTANCE_ID
export BOB_BIN
export BOB_INCLUDED_DIRECTORY

# QCA design/store directories. Design Markdown and generated implementation code
# are intentionally separated.
QCA_DESIGN_DIR="${QCA_DESIGN_DIR:-$SCRIPT_DIR/bob-quantum-designs}"
QCA_STORE_DIR="${QCA_STORE_DIR:-$SCRIPT_DIR/bob-quantum-store}"

mkdir -p "$QCA_DESIGN_DIR" "$QCA_STORE_DIR"
chmod -R u+rwX,go+rX "$QCA_DESIGN_DIR" "$QCA_STORE_DIR" 2>/dev/null || true

export QCA_DESIGN_DIR
export QCA_STORE_DIR

# QCA-GENERATED-CODE-QUALITY-POLICY-v${BOB_VERSION}.Q20 helper path.
# Bob should use this guard before reporting generated code success or executing code.
QCA_CODE_QUALITY_GUARD="${QCA_CODE_QUALITY_GUARD:-$SCRIPT_DIR/.bob/quantum-tools/qca-code-quality-guard.sh}"
export QCA_CODE_QUALITY_GUARD

# Bob tool flags for quantum code generation workflows.
# These flags preserve the production menu flow while allowing Bob to create,
# update, read, list, and verify files in the included quantum code workspace.
BOB_QUANTUM_TOOL_FLAGS=(
  --approval-mode auto_edit
  --allowed-tools read_file
  --allowed-tools write_to_file
  --allowed-tools apply_diff
  --allowed-tools insert_content
  --allowed-tools list_files
  --allowed-tools search_files
  --allowed-tools execute_command
)

clear

# shellcheck source=/dev/null
source "${SCRIPT_DIR}/bob-version.sh"

# shellcheck source=/dev/null
source "${SCRIPT_DIR}/bob-shell.sh"

bob_shell

#===============================================================================
# COLOR-SAFE MENU BOX
# Do not put ANSI color codes inside padded strings.
# This keeps the box aligned while preserving colored output.
#===============================================================================
MENU_NO_WIDTH=5
MENU_ACTION_WIDTH=62
MENU_SKILL_WIDTH=18
MENU_ROW_WIDTH=95
MENU_TITLE_WIDTH=$((MENU_ROW_WIDTH - 4))

_repeat_char() {
  local char="$1"
  local count="$2"
  local out=""

  while (( count > 0 )); do
    out+="$char"
    count=$((count - 1))
  done

  printf '%s' "$out"
}

menu_border() {
  printf '%b+%s+%b\n' "${CYAN}" "$(_repeat_char "-" $((MENU_ROW_WIDTH - 2)))" "${RESET}"
}

menu_title() {
  local text="$1"
  local color="$2"

  printf '%b|%b ' "${CYAN}" "${RESET}"
  printf '%b%-*.*s%b' "${color}" "${MENU_TITLE_WIDTH}" "${MENU_TITLE_WIDTH}" "${text}" "${RESET}"
  printf ' %b|%b\n' "${CYAN}" "${RESET}"
}

menu_row() {
  local no="$1"
  local action="$2"
  local skill="$3"
  local no_color="${4:-}"

  printf '%b|%b ' "${CYAN}" "${RESET}"

  if [[ -n "${no_color}" ]]; then
    printf '%b%-*.*s%b' "${no_color}" "${MENU_NO_WIDTH}" "${MENU_NO_WIDTH}" "${no}" "${RESET}"
  else
    printf '%-*.*s' "${MENU_NO_WIDTH}" "${MENU_NO_WIDTH}" "${no}"
  fi

  printf ' %b|%b ' "${CYAN}" "${RESET}"
  printf '%-*.*s' "${MENU_ACTION_WIDTH}" "${MENU_ACTION_WIDTH}" "${action}"

  printf ' %b|%b ' "${CYAN}" "${RESET}"
  printf '%-*.*s' "${MENU_SKILL_WIDTH}" "${MENU_SKILL_WIDTH}" "${skill}"

  printf ' %b|%b\n' "${CYAN}" "${RESET}"
}

menu_border
menu_title "${APPLIANCE_NAME:-IBM Bob Quantum Computing Agent (QCA)}" "${BOLD}${BLUE}"
menu_title "This is Quantum Computing Agent, built & integrated with IBM Bob Intelligence" "${BOLD}${MAGENTA}"
menu_border

menu_row "No." "Action" "Skill ID"
menu_border

menu_row "1" "Start Interactive QCA Session" "User Interactive" "${GREEN}${BOLD}"
menu_row "2" "Ask Quantum Computing Questions" "Quantum Concierge" "${GREEN}${BOLD}"
menu_row "3" "Quantum Computing Algorithm Concierge" "Quantum Developer" "${GREEN}${BOLD}"
menu_row "4" "Advanced Quantum Computing Algorithm Circuit Design" "Quantum Advanced" "${GREEN}${BOLD}"
menu_row "5" "Resume QCA Session (Picks: 1, 2, 3, or 4)" "Resume latest" "${YELLOW}${BOLD}"
menu_row "0" "Quit" "Exit" "${RED}${BOLD}"

menu_border

printf '%b\n' "${CYAN}Authenticating Bob Shell...${RESET}"

# shellcheck source=/dev/null
source "$SCRIPT_DIR/bob-auth.sh"

printf '%b\n' "${CYAN}Bob Time: $(date_time_stamp)${RESET}"
printf '%bSelect menu option (0-5):%b ' "${BOLD}${YELLOW}" "${RESET}"
read -r choice

case "$choice" in
  1)
    quantum_interactive() {
      "$BOB_BIN" \
        --chat-mode code \
        --accept-license true \
        --instance-id "$BOB_INSTANCE_ID" \
        --include-directories "$BOB_INCLUDED_DIRECTORY" \
        "${BOB_QUANTUM_TOOL_FLAGS[@]}" \
        --hide-intermediary-output \
        --prompt-interactive "$INITIAL_PROMPT"
    }
    quantum_interactive
    ;;

  2)
    printf '%bEnter quantum computing question prompt:%b ' "${YELLOW}" "${RESET}"
    read -r prompt

    quantum_assist() {
      "$BOB_BIN" "${prompt}" \
        --chat-mode ask \
        --accept-license true \
        --instance-id "$BOB_INSTANCE_ID" \
        --include-directories "$BOB_INCLUDED_DIRECTORY" \
        "${BOB_QUANTUM_TOOL_FLAGS[@]}" \
        --hide-intermediary-output
    }
    quantum_assist
    ;;

  3)
    printf '%bEnter quantum computing code assist prompt:%b ' "${YELLOW}" "${RESET}"
    read -r prompt

    quantum_code() {
      "$BOB_BIN" "${prompt}" \
        --chat-mode code \
        --accept-license true \
        --trust \
        --instance-id "$BOB_INSTANCE_ID" \
        --include-directories "$BOB_INCLUDED_DIRECTORY" \
        "${BOB_QUANTUM_TOOL_FLAGS[@]}" \
        --hide-intermediary-output
    }
    quantum_code
    ;;

  4)
    printf '%bEnter advanced quantum computing circuit design prompt:%b ' "${YELLOW}" "${RESET}"
    read -r prompt

    quantum_advanced() {
      "$BOB_BIN" "${prompt}" \
        --chat-mode advanced \
        --accept-license true \
        --trust \
        --instance-id "$BOB_INSTANCE_ID" \
        --include-directories "$BOB_INCLUDED_DIRECTORY" \
        "${BOB_QUANTUM_TOOL_FLAGS[@]}" \
        --hide-intermediary-output
    }
    quantum_advanced
    ;;

  5)
    quantum_resume() {
      "$BOB_BIN" --resume latest \
        --instance-id "$BOB_INSTANCE_ID" \
        --include-directories "$BOB_INCLUDED_DIRECTORY" \
        --hide-intermediary-output
    }
    quantum_resume
    ;;

  0)
    printf '%b🤖 %s, Goodbye!%b\n' "${GREEN}" "${APPLIANCE_NAME:-IBM Bob Quantum Computing Agent (QCA)}" "${RESET}"
    exit 0
    ;;

  *)
    printf '%bInvalid option.%b\n' "${RED}" "${RESET}"
    exit 1
    ;;
esac