#!/usr/bin/env bash
set -Eeuo pipefail

clear

#===============================================================================
# @Author: Dr. Jeffrey Chijioke-Uche, IBM Computer Scientist
# @Description: Launchpad for interacting with IBM Bob Quantum Computing Agent (QCA)
# @Version: v${BOB_VERSION}.Q1.0.0
#===============================================================================

#===============================================================================
# This script is part of the IBM Bob Quantum Computing Agent (BQCA) appliance.
#===============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# BQCA-DIRECT-EXECUTION-EXPORT-v46:BEGIN
BQCA_DIRECT_EXECUTION_TOOL="${SCRIPT_DIR}/.bob/quantum-tools/bqca-direct-execution.sh"
BQCA_FORMAL_ORCHESTRATOR="${SCRIPT_DIR}/.bob/quantum-tools/bqca-policy-orchestrator.sh"
export BQCA_DIRECT_EXECUTION_TOOL BQCA_FORMAL_ORCHESTRATOR
# BQCA-DIRECT-EXECUTION-EXPORT-v46:END


# BQCA-CANONICAL-ORCHESTRATOR-v44:BEGIN
BQCA_POLICY_ORCHESTRATOR="${SCRIPT_DIR}/.bob/quantum-tools/bqca-policy-orchestrator.sh"
BQCA_POLICY_DOCTOR="${SCRIPT_DIR}/.bob/quantum-tools/bqca-policy-doctor.sh"
BQCA_ACTIVE_POLICY="${SCRIPT_DIR}/.bob/BQCA-PRODUCTION-POLICY.md"
export BQCA_POLICY_ORCHESTRATOR BQCA_POLICY_DOCTOR BQCA_ACTIVE_POLICY
# BQCA-CANONICAL-ORCHESTRATOR-v44:END








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
source "${SCRIPT_DIR}/tls-control.sh"

set -a
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/.env"
set +a

date_time_stamp() {
  TZ="America/New_York" date "+%Y-%m-%d %H:%M:%S %Z"
}

#===============================================================================
# BQCA Spinner v3.9.0
#
# Displays a rotating spinner while the supplied background process is running.
# The spinner disappears automatically before the completed Bob response prints.
#===============================================================================
spinner() {
  local process_pid="$1"
  local message="${2:-BQCA is processing your request}"
  local frames='|/-\'
  local frame_index=0
  local frame_count="${#frames}"
  local frame=""

  # When stdout is not connected to a terminal, wait silently.
  if [[ ! -t 1 ]]; then
    while kill -0 "${process_pid}" 2>/dev/null; do
      sleep 0.12
    done
    return 0
  fi

  # Hide terminal cursor while spinner is running.
  if command -v tput >/dev/null 2>&1; then
    tput civis 2>/dev/null || true
  fi

  while kill -0 "${process_pid}" 2>/dev/null; do
    frame="${frames:frame_index:1}"

    printf '\r%b%s %s...%b' \
      "${BOLD}${CYAN}" \
      "${frame}" \
      "${message}" \
      "${RESET}"

    frame_index=$(((frame_index + 1) % frame_count))
    sleep 0.12
  done

  # Erase spinner line completely.
  printf '\r\033[2K'

  # Restore terminal cursor.
  if command -v tput >/dev/null 2>&1; then
    tput cnorm 2>/dev/null || true
  fi
}

#===============================================================================
# Run a Bob operation with a spinner and buffered output.
#
# The Bob process runs in the background while all stdout and stderr are written
# to a temporary file. Once processing is complete, the spinner is removed and
# the full Bob response is printed normally.
#===============================================================================
run_with_spinner() {
  local spinner_message="$1"
  shift

  local response_file=""
  local process_pid=""
  local process_status=0

  response_file="$(mktemp "${TMPDIR:-/tmp}/bqca-response.XXXXXX")"

  "$@" >"${response_file}" 2>&1 &
  process_pid=$!

  spinner "${process_pid}" "${spinner_message}"

  set +e
  wait "${process_pid}"
  process_status=$?
  set -e

  if (( process_status == 0 )); then
    cat "${response_file}"
  else
    cat "${response_file}" >&2
  fi

  rm -f "${response_file}"

  return "${process_status}"
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
QCA_DESIGN_DIR="${QCA_DESIGN_DIR:-${SCRIPT_DIR}/bob-quantum-designs}"
QCA_STORE_DIR="${QCA_STORE_DIR:-${SCRIPT_DIR}/bob-quantum-store}"

mkdir -p "${QCA_DESIGN_DIR}" "${QCA_STORE_DIR}"
chmod -R u+rwX,go+rX "${QCA_DESIGN_DIR}" "${QCA_STORE_DIR}" 2>/dev/null || true

export QCA_DESIGN_DIR
export QCA_STORE_DIR

# QCA-GENERATED-CODE-QUALITY-POLICY-v${BOB_VERSION}.Q20 helper path.
# Bob should use this guard before reporting generated code success or executing code.
QCA_CODE_QUALITY_GUARD="${QCA_CODE_QUALITY_GUARD:-${SCRIPT_DIR}/.bob/quantum-tools/qca-code-quality-guard.sh}"

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

# shellcheck source=/dev/null
source "${SCRIPT_DIR}/bob-version.sh"

# shellcheck source=/dev/null
source "${SCRIPT_DIR}/bob-shell.sh"

bob_shell





# BQCA-QISKIT-EXECUTION-v39-update-1:HELPER-BEGIN
BQCA_QISKIT_V39_ENV_TOOL="${BQCA_QISKIT_V39_ENV_TOOL:-${SCRIPT_DIR}/.bob/quantum-tools/qiskit-v2x-environment.sh}"
export BQCA_QISKIT_V39_ENV_TOOL

bqca_v39_is_hello_world_request() {
  local prompt_text="${1,,}"
  prompt_text="${prompt_text//_/ }"
  [[ "${prompt_text}" =~ run[[:space:]]+(qiskit[[:space:]]+)?hello(w)?[-[:space:]]*world ]]
}

bqca_v39_maybe_run_hello_world() {
  local prompt_text="$1" status
  bqca_v39_is_hello_world_request "${prompt_text}" || return 10
  [[ -x "${BQCA_QISKIT_V39_ENV_TOOL}" ]] || {
    printf '[BQCA][ERROR] v39 update 1 runtime tool is missing: %s\n' \
      "${BQCA_QISKIT_V39_ENV_TOOL}" >&2
    return 2
  }
  set +e
  "${BQCA_QISKIT_V39_ENV_TOOL}" hello-world-if-present
  status=$?
  set -e
  return "${status}"
}
# BQCA-QISKIT-EXECUTION-v39-update-1:HELPER-END

# BQCA-QISKIT-HOME-ENV-v40:BEGIN
: "${HOME:?HOME must be set for BQCA qiskit-v2x-env}"
BQCA_QISKIT_V40_HOME_ENV="$(cd "${HOME}" && pwd -P)/qiskit-v2x-env"
export BQCA_QISKIT_V40_HOME_ENV
# BQCA-QISKIT-HOME-ENV-v40:END

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
    out+="${char}"
    count=$((count - 1))
  done

  printf '%s' "${out}"
}

menu_border() {
  printf '%b+%s+%b\n' \
    "${CYAN}" \
    "$(_repeat_char "-" $((MENU_ROW_WIDTH - 2)))" \
    "${RESET}"
}

menu_title() {
  local text="$1"
  local color="$2"

  printf '%b|%b ' "${CYAN}" "${RESET}"
  printf '%b%-*.*s%b' \
    "${color}" \
    "${MENU_TITLE_WIDTH}" \
    "${MENU_TITLE_WIDTH}" \
    "${text}" \
    "${RESET}"
  printf ' %b|%b\n' "${CYAN}" "${RESET}"
}

menu_row() {
  local no="$1"
  local action="$2"
  local skill="$3"
  local no_color="${4:-}"

  printf '%b|%b ' "${CYAN}" "${RESET}"

  if [[ -n "${no_color}" ]]; then
    printf '%b%-*.*s%b' \
      "${no_color}" \
      "${MENU_NO_WIDTH}" \
      "${MENU_NO_WIDTH}" \
      "${no}" \
      "${RESET}"
  else
    printf '%-*.*s' \
      "${MENU_NO_WIDTH}" \
      "${MENU_NO_WIDTH}" \
      "${no}"
  fi

  printf ' %b|%b ' "${CYAN}" "${RESET}"
  printf '%-*.*s' \
    "${MENU_ACTION_WIDTH}" \
    "${MENU_ACTION_WIDTH}" \
    "${action}"

  printf ' %b|%b ' "${CYAN}" "${RESET}"
  printf '%-*.*s' \
    "${MENU_SKILL_WIDTH}" \
    "${MENU_SKILL_WIDTH}" \
    "${skill}"

  printf ' %b|%b\n' "${CYAN}" "${RESET}"
}

menu_border
menu_title \
  "${APPLIANCE_NAME:-IBM Bob Quantum Computing Agent (BQCA)}" \
  "${BOLD}${BLUE}"

menu_title \
  "This is Quantum Computing Agent, built & integrated with IBM Bob Intelligence" \
  "${BOLD}${MAGENTA}"

menu_border

menu_row "No." "Action" "Skill ID"

menu_border

menu_row \
  "1" \
  "Start Interactive BQCA Session" \
  "User Interactive" \
  "${GREEN}${BOLD}"

menu_row \
  "2" \
  "Ask Quantum Computing Questions" \
  "Quantum Expert" \
  "${GREEN}${BOLD}"

menu_row \
  "3" \
  "Quantum Computing Algorithm Implementation Concierge" \
  "Quantum Developer" \
  "${GREEN}${BOLD}"

menu_row \
  "4" \
  "Advanced Quantum Computing Solution Design Concierge" \
  "Quantum Advanced" \
  "${GREEN}${BOLD}"

menu_row \
  "5" \
  "Resume BQCA Last Activity (Picks: 1, 2, 3, or 4 last action)" \
  "Resume Session" \
  "${YELLOW}${BOLD}"

menu_row \
  "0" \
  "Quit" \
  "Exit" \
  "${RED}${BOLD}"

menu_border

printf '%b\n' "${CYAN}Authenticating Bob Shell...${RESET}"

# shellcheck source=/dev/null
source "${SCRIPT_DIR}/bob-auth.sh"

printf '%b\n' "${CYAN}Bob Time: $(date_time_stamp)${RESET}"
printf '%bSelect menu option (0-5):%b ' "${BOLD}${YELLOW}" "${RESET}"

read -r choice

case "${choice}" in
  1)
    printf '%bYou Selected Start Interactive BQCA Session, please wait ⏳%b\n' \
      "${BOLD}${YELLOW}" \
      "${RESET}"

    quantum_interactive() {
      "${BOB_BIN}" \
        --chat-mode code \
        --accept-license true \
        --instance-id "${BOB_INSTANCE_ID}" \
        --include-directories "${BOB_INCLUDED_DIRECTORY}" \
        "${BOB_QUANTUM_TOOL_FLAGS[@]}" \
        --hide-intermediary-output \
        --prompt-interactive "${INITIAL_PROMPT}"
    }

    quantum_interactive
    ;;

  2)
    printf '%bYou Selected BQCA Quantum Expert for Questions....%b\n' \
      "${BOLD}${YELLOW}" \
      "${RESET}"

    printf '%bEnter prompt for your quantum computing question:%b ' \
      "${YELLOW}" \
      "${RESET}"

    read -r prompt

    # BQCA-QISKIT-EXECUTION-v39-update-1:HELLO-BEGIN
    if bqca_v39_is_hello_world_request "${prompt}"; then
      set +e
      run_with_spinner         "BQCA is running the existing Qiskit Hello World artifact, please wait"         bqca_v39_maybe_run_hello_world "${prompt}"
      _bqca_v39_hello_status=$?
      set -e
      if [[ "${_bqca_v39_hello_status}" -eq 0 ]]; then
        exit 0
      elif [[ "${_bqca_v39_hello_status}" -ne 10 ]]; then
        exit "${_bqca_v39_hello_status}"
      fi
      unset _bqca_v39_hello_status
    fi
    # BQCA-QISKIT-EXECUTION-v39-update-1:HELLO-END
    quantum_assist() {
      "${BOB_BIN}" "${prompt}" \
        --chat-mode ask \
        --accept-license true \
        --instance-id "${BOB_INSTANCE_ID}" \
        --include-directories "${BOB_INCLUDED_DIRECTORY}" \
        "${BOB_QUANTUM_TOOL_FLAGS[@]}" \
        --hide-intermediary-output
    }

    run_with_spinner \
      "BQCA Quantum Expert is analyzing your question, please wait ⏳" \
      quantum_assist
    ;;

  3)
    printf '%bYou Selected BQCA Quantum Developer for Code Implementation....%b\n' \
      "${BOLD}${YELLOW}" \
      "${RESET}"

    printf '%bEnter prompt for quantum computing code pilot:%b ' \
      "${YELLOW}" \
      "${RESET}"

    read -r prompt

    # BQCA-QISKIT-EXECUTION-v39-update-1:HELLO-BEGIN
    if bqca_v39_is_hello_world_request "${prompt}"; then
      set +e
      run_with_spinner         "BQCA is running the existing Qiskit Hello World artifact, please wait"         bqca_v39_maybe_run_hello_world "${prompt}"
      _bqca_v39_hello_status=$?
      set -e
      if [[ "${_bqca_v39_hello_status}" -eq 0 ]]; then
        exit 0
      elif [[ "${_bqca_v39_hello_status}" -ne 10 ]]; then
        exit "${_bqca_v39_hello_status}"
      fi
      unset _bqca_v39_hello_status
    fi
    # BQCA-QISKIT-EXECUTION-v39-update-1:HELLO-END
    quantum_code() {
      "${BOB_BIN}" "${prompt}" \
        --chat-mode code \
        --accept-license true \
        --trust \
        --instance-id "${BOB_INSTANCE_ID}" \
        --include-directories "${BOB_INCLUDED_DIRECTORY}" \
        "${BOB_QUANTUM_TOOL_FLAGS[@]}" \
        --hide-intermediary-output
    }

    run_with_spinner \
      "BQCA Quantum Developer is implementing your request, please wait ⏳" \
      quantum_code
    ;;

  4)
    printf '%bYou Selected BQCA Quantum Advanced for Solution Design....%b\n' \
      "${BOLD}${YELLOW}" \
      "${RESET}"

    printf '%bEnter prompt for quantum computing problem solution design:%b ' \
      "${YELLOW}" \
      "${RESET}"

    read -r prompt

    # BQCA-QISKIT-EXECUTION-v39-update-1:HELLO-BEGIN
    if bqca_v39_is_hello_world_request "${prompt}"; then
      set +e
      run_with_spinner         "BQCA is running the existing Qiskit Hello World artifact, please wait"         bqca_v39_maybe_run_hello_world "${prompt}"
      _bqca_v39_hello_status=$?
      set -e
      if [[ "${_bqca_v39_hello_status}" -eq 0 ]]; then
        exit 0
      elif [[ "${_bqca_v39_hello_status}" -ne 10 ]]; then
        exit "${_bqca_v39_hello_status}"
      fi
      unset _bqca_v39_hello_status
    fi
    # BQCA-QISKIT-EXECUTION-v39-update-1:HELLO-END
    quantum_advanced() {
      "${BOB_BIN}" "${prompt}" \
        --chat-mode advanced \
        --accept-license true \
        --trust \
        --instance-id "${BOB_INSTANCE_ID}" \
        --include-directories "${BOB_INCLUDED_DIRECTORY}" \
        "${BOB_QUANTUM_TOOL_FLAGS[@]}" \
        --hide-intermediary-output
    }

    run_with_spinner \
      "BQCA Quantum Advanced is designing your solution, please wait ⏳" \
      quantum_advanced
    ;;

  5)
    printf '%bYou Selected BQCA Quantum Resume for Return to Last Activity, please wait ⏳%b\n' \
      "${BOLD}${YELLOW}" \
      "${RESET}"

    quantum_resume() {
      "${BOB_BIN}" \
        --resume latest \
        --instance-id "${BOB_INSTANCE_ID}" \
        --include-directories "${BOB_INCLUDED_DIRECTORY}" \
        --hide-intermediary-output
    }

    quantum_resume
    ;;

  0)
    printf '%b🤖 %s, Goodbye!%b\n' \
      "${GREEN}" \
      "${APPLIANCE_NAME:-IBM Bob Quantum Computing Agent (BQCA)}" \
      "${RESET}"

    exit 0
    ;;

  *)
    printf '%bInvalid option.%b\n' "${RED}" "${RESET}"
    exit 1
    ;;
esac