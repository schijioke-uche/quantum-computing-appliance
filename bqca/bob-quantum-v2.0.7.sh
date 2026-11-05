#!/usr/bin/env bash
set -Eeuo pipefail

clear

#===============================================================================
# @Author: Dr. Jeffrey Chijioke-Uche, IBM Computer Scientist
# @Description: Launchpad for interacting with IBM Bob Quantum Computing Agent (QCA)
# @Bob Version Target: Bob Shell v1.x and v2.x
#===============================================================================

#===============================================================================
# This script is part of the IBM Bob Quantum Computing Agent (BQCA) appliance.
#===============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# BQCA-CUSTOM-MODE-RULE-SYNC-v51.2:BEGIN
if [[ "${BQCA_CUSTOM_MODE_RULES_SYNCED:-0}" != "1" ]]; then
  _BQCA_MODE_RULE_SYNC="${SCRIPT_DIR}/.bob/quantum-tools/bqca-custom-mode-rules.sh"
  if [[ ! -x "${_BQCA_MODE_RULE_SYNC}" ]] || ! "${_BQCA_MODE_RULE_SYNC}" sync --quiet; then
    printf '[BQCA][ERROR] Custom modes and custom rules are not synchronized. Run: %s report\n' "${_BQCA_MODE_RULE_SYNC}" >&2
    exit 1
  fi
  BQCA_CUSTOM_MODE_RULES_SYNCED=1
  export BQCA_CUSTOM_MODE_RULES_SYNCED
  unset _BQCA_MODE_RULE_SYNC
fi
# BQCA-CUSTOM-MODE-RULE-SYNC-v51.2:END

# BQCA-ACTIVE-POLICY-RUNTIME-EXPORT:BEGIN
_BQCA_ACTIVE_POLICY_LISTENER="${SCRIPT_DIR}/.bob/quantum-tools/bqca-active-policy-listener.sh"
if [[ -x "${_BQCA_ACTIVE_POLICY_LISTENER}" ]]; then
  export BQCA_ACTIVE_POLICY_VERSION="$("${_BQCA_ACTIVE_POLICY_LISTENER}" version)"
  export BQCA_ACTIVE_POLICY_PATH="$("${_BQCA_ACTIVE_POLICY_LISTENER}" policy-path)"
  export BQCA_ACTIVE_POLICY_CONTRACT="$("${_BQCA_ACTIVE_POLICY_LISTENER}" field contract_sha256)"
fi
# BQCA-ACTIVE-POLICY-RUNTIME-EXPORT:END


# BQCA-DIRECT-EXECUTION-EXPORT-v48:BEGIN
BQCA_ACTIVE_POLICY="${SCRIPT_DIR}/.bob/BQCA-PRODUCTION-POLICY.md"
BQCA_ACTIVE_POLICY_VERSION="v48"
BQCA_DIRECT_EXECUTION="${SCRIPT_DIR}/.bob/quantum-tools/bqca-direct-execution.sh"
BQCA_FORMAL_ORCHESTRATOR="${SCRIPT_DIR}/.bob/quantum-tools/bqca-policy-orchestrator.sh"
BQCA_POLICY_DOCTOR="${SCRIPT_DIR}/.bob/quantum-tools/bqca-policy-doctor.sh"
BQCA_QUANTUM_KNOWLEDGEBASE="${SCRIPT_DIR}/.bob/quantum-tools/bqca-quantum-kb.sh"
export BQCA_ACTIVE_POLICY BQCA_ACTIVE_POLICY_VERSION BQCA_DIRECT_EXECUTION BQCA_FORMAL_ORCHESTRATOR BQCA_POLICY_DOCTOR BQCA_QUANTUM_KNOWLEDGEBASE
# Direct execution is the default. Formal orchestration is explicit opt-in.
# All design/code decisions and knowledgebase use follow the v48 central policy.
# BQCA-DIRECT-EXECUTION-EXPORT-v48:END


# BQCA-BOB-SHELL-V2-DNA-CHAIN-v51.0:BEGIN
BQCA_BOB2_DNA_ENVELOPE="${BQCA_BOB2_DNA_ENVELOPE:-1}"
export BQCA_BOB2_DNA_ENVELOPE

bqca_set_menu_context() {
  BQCA_MENU_OPTION="$1"
  BQCA_MENU_ACTION="$2"
  BQCA_MENU_SKILL_ID="$3"
  BQCA_SELECTED_MODE="$4"
  export BQCA_MENU_OPTION BQCA_MENU_ACTION BQCA_MENU_SKILL_ID BQCA_SELECTED_MODE
}

bqca_bob2_envelope_prompt() {
  local user_prompt="$1"
  local selected_mode="$2"
  if [[ "${BQCA_BOB2_DNA_ENVELOPE}" != "1" ]]; then
    printf '%s\n' "${user_prompt}"
    return 0
  fi
  cat <<EOF_BQCA_PROMPT
[BQCA PROJECT CONTEXT]
Operate as the IBM Bob Quantum Computing Agent in the trusted workspace ${SCRIPT_DIR}.
Menu option: ${BQCA_MENU_OPTION:-unspecified}
Menu action: ${BQCA_MENU_ACTION:-BQCA request}
Skill identity: ${BQCA_MENU_SKILL_ID:-BQCA intelligence}
Selected mode: ${selected_mode}
Read AGENTS.md, resolve the active central policy, and use the current mode rules, relevant skills, quantum tools, and offline knowledgebase. Preserve governed design/code routing, validators/compliance reports, notebook synchronization, Qiskit execution rules, result-output governance, and credential protection.

[USER REQUEST]
${user_prompt}
EOF_BQCA_PROMPT
}
# BQCA-BOB-SHELL-V2-DNA-CHAIN-v51.0:END

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

# BQCA-PROJECT-ENV-LOAD-GUARD-v51.1:BEGIN
if [[ "${BQCA_PROJECT_ENV_LOADED:-0}" != "1" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "${SCRIPT_DIR}/.env"
  set +a
  BQCA_PROJECT_ENV_LOADED=1
  export BQCA_PROJECT_ENV_LOADED
fi
# BQCA-PROJECT-ENV-LOAD-GUARD-v51.1:END

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

# BQCA-BOB-DEBUG-TRACE-v48-update-3:BEGIN
# Optional Bob Shell diagnostics. This changes no default behavior.
# Run: BQCA_BOB_DEBUG=1 ./xLaunchpad.sh
if [[ "${BQCA_BOB_DEBUG:-0}" == "1" ]]; then
  BOB_QUANTUM_TOOL_FLAGS+=(--debug)
fi
# BQCA-BOB-DEBUG-TRACE-v48-update-3:END

# shellcheck source=/dev/null
source "${SCRIPT_DIR}/bob-version.sh"

# shellcheck source=/dev/null
source "${SCRIPT_DIR}/bob-shell.sh"

bob_shell

# BQCA-BOB-SHELL-DUAL-VERSION-COMPATIBILITY:BEGIN
#
# Bob Shell 1.x command family:
#   bob [prompt] --chat-mode <mode> ...
#
# Bob Shell 2.x command family:
#   bob chat --mode <mode> ...
#   bob run  --mode <mode> ...
#
# The authentication layer is delegated to bob-auth.sh. This launcher only
# selects the correct CLI syntax after bob-version.sh has resolved BOB_VERSION.
#===============================================================================
if [[ "${BOB_VERSION}" =~ ^([0-9]+) ]]; then
  BQCA_BOB_SHELL_MAJOR="${BASH_REMATCH[1]}"
else
  printf '[BQCA][ERROR] Unsupported Bob Shell version value: %s\n' "${BOB_VERSION}" >&2
  exit 1
fi

case "${BQCA_BOB_SHELL_MAJOR}" in
  1|2)
    ;;
  *)
    printf '[BQCA][ERROR] This launcher supports Bob Shell 1.x and 2.x; detected: %s\n' \
      "${BOB_VERSION}" >&2
    exit 1
    ;;
esac

export BQCA_BOB_SHELL_MAJOR

BQCA_BOB2_OUTPUT_FORMAT="${BQCA_BOB2_OUTPUT_FORMAT:-pretty}"
BQCA_BOB2_MAX_TURNS="${BQCA_BOB2_MAX_TURNS:-50}"
BQCA_BOB2_LOG_LEVEL="${BQCA_BOB2_LOG_LEVEL:-warn}"
# BQCA-TRUSTED-CHAT-AUTO-APPROVAL-v51.4:BEGIN
# Production default: all BQCA Bob Shell 2.x interactive and resumed chat
# sessions use --trust --auto-approve. Non-interactive bob run behavior is not
# changed by this patch.
BQCA_CHAT_AUTO_APPROVE="${BQCA_CHAT_AUTO_APPROVE:-1}"
BQCA_BOB2_AUTO_APPROVE="${BQCA_CHAT_AUTO_APPROVE}"
BQCA_CHAT_AUTO_APPROVAL_TOOL="${SCRIPT_DIR}/.bob/quantum-tools/bqca-chat-auto-approval.sh"
export BQCA_CHAT_AUTO_APPROVE BQCA_BOB2_AUTO_APPROVE BQCA_CHAT_AUTO_APPROVAL_TOOL
# BQCA-TRUSTED-CHAT-AUTO-APPROVAL-v51.4:END
BQCA_BOB2_INSTANCE_ID="${BQCA_BOB2_INSTANCE_ID:-}"

bqca_is_bob2() {
  [[ "${BQCA_BOB_SHELL_MAJOR}" -eq 2 ]]
}

bqca_bob2_custom_mode_exists() {
  local requested_slug="$1"
  local mode_file="${SCRIPT_DIR}/.bob/custom_modes.yaml"

  [[ -f "${mode_file}" ]] || return 1

  grep -Eq \
    "^[[:space:]]*-[[:space:]]*slug:[[:space:]]*['\"]?${requested_slug}['\"]?[[:space:]]*$" \
    "${mode_file}"
}

bqca_bob2_resolve_mode() {
  local preferred_mode="$1"
  local fallback_mode="$2"

  case "${preferred_mode}" in
    agent|plan|ask)
      printf '%s\n' "${preferred_mode}"
      return 0
      ;;
  esac

  if bqca_bob2_custom_mode_exists "${preferred_mode}"; then
    printf '%s\n' "${preferred_mode}"
  else
    printf '%s\n' "${fallback_mode}"
  fi
}

BQCA_BOB2_INTERACTIVE_MODE="${BQCA_BOB2_INTERACTIVE_MODE:-$(bqca_bob2_resolve_mode quantum-qiskit-connector quantum-smart)}"
BQCA_BOB2_ASK_MODE="${BQCA_BOB2_ASK_MODE:-$(bqca_bob2_resolve_mode quantum-smart ask)}"
BQCA_BOB2_CODE_MODE="${BQCA_BOB2_CODE_MODE:-$(bqca_bob2_resolve_mode quantum-code-heron quantum-qiskit-connector)}"
BQCA_BOB2_ADVANCED_MODE="${BQCA_BOB2_ADVANCED_MODE:-$(bqca_bob2_resolve_mode quantum-advanced advanced)}"

export \
  BQCA_BOB2_OUTPUT_FORMAT \
  BQCA_BOB2_MAX_TURNS \
  BQCA_BOB2_LOG_LEVEL \
  BQCA_BOB2_AUTO_APPROVE \
  BQCA_BOB2_INSTANCE_ID \
  BQCA_BOB2_INTERACTIVE_MODE \
  BQCA_BOB2_ASK_MODE \
  BQCA_BOB2_CODE_MODE \
  BQCA_BOB2_ADVANCED_MODE

# BQCA-BOB2-MODE-BRIDGE-v51.1:BEGIN
bqca_trim_mode_value() {
  local value="${1:-}"
  printf '%s' "${value}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

bqca_bob2_mode_is_available() {
  local mode_name="${1:-}"
  case "${mode_name}" in agent|ask|plan) return 0 ;; esac
  [[ -n "${mode_name}" ]] && bqca_bob2_custom_mode_exists "${mode_name}"
}

bqca_bob2_resolve_runtime_mode() {
  local current_value="${1:-}" preferred_mode="$2" fallback_mode="$3" label="$4" resolved
  resolved="$(bqca_trim_mode_value "${current_value}")"
  [[ -n "${resolved}" ]] || resolved="$(bqca_bob2_resolve_mode "${preferred_mode}" "${fallback_mode}")"
  if ! bqca_bob2_mode_is_available "${resolved}"; then
    printf '[BQCA][ERROR] Bob Shell 2.x %s mode is unavailable: %s\n' "${label}" "${resolved:-<empty>}" >&2
    return 1
  fi
  printf '%s\n' "${resolved}"
}

bqca_bob2_refresh_modes() {
  BQCA_BOB2_INTERACTIVE_MODE="$(bqca_bob2_resolve_runtime_mode "${BQCA_BOB2_INTERACTIVE_MODE:-}" code agent interactive)" || return 1
  BQCA_BOB2_ASK_MODE="$(bqca_bob2_resolve_runtime_mode "${BQCA_BOB2_ASK_MODE:-}" ask ask expert)" || return 1
  BQCA_BOB2_CODE_MODE="$(bqca_bob2_resolve_runtime_mode "${BQCA_BOB2_CODE_MODE:-}" code agent developer)" || return 1
  BQCA_BOB2_ADVANCED_MODE="$(bqca_bob2_resolve_runtime_mode "${BQCA_BOB2_ADVANCED_MODE:-}" advanced plan advanced)" || return 1
  export BQCA_BOB2_INTERACTIVE_MODE BQCA_BOB2_ASK_MODE BQCA_BOB2_CODE_MODE BQCA_BOB2_ADVANCED_MODE
}

bqca_bob2_require_mode() {
  local selected_mode
  selected_mode="$(bqca_trim_mode_value "${1:-}")"
  if [[ -z "${selected_mode}" ]]; then
    printf '[BQCA][ERROR] Refusing to invoke Bob Shell 2.x with an empty mode.\n' >&2
    return 1
  fi
  if ! bqca_bob2_mode_is_available "${selected_mode}"; then
    printf '[BQCA][ERROR] Refusing to invoke unavailable Bob Shell 2.x mode: %s\n' "${selected_mode}" >&2
    return 1
  fi
  printf '%s\n' "${selected_mode}"
}

bqca_bob2_refresh_modes
# BQCA-BOB2-MODE-BRIDGE-v51.1:END

# BQCA-BOB2-CUSTOM-MODE-ROUTING-v51.2:BEGIN
bqca_bob2_normalize_mode_alias_v512() {
  local value
  value="$(bqca_trim_mode_value "${1:-}")"
  case "${value}" in
    code|qiskit-connector) printf '%s\n' quantum-qiskit-connector ;;
    quantum-code) printf '%s\n' quantum-code-default ;;
    quantum-intelligence) printf '%s\n' quantum-smart ;;
    *) printf '%s\n' "${value}" ;;
  esac
}

bqca_bob2_first_available_mode_v512() {
  local candidate
  for candidate in "$@"; do
    if bqca_bob2_mode_is_available "${candidate}"; then printf '%s\n' "${candidate}"; return 0; fi
  done
  return 1
}

bqca_bob2_resolve_role_mode_v512() {
  local current_value="${1:-}" role="$2" resolved
  resolved="$(bqca_bob2_normalize_mode_alias_v512 "${current_value}")"
  if [[ -n "${resolved}" ]]; then
    bqca_bob2_mode_is_available "${resolved}" || { printf '[BQCA][ERROR] Bob Shell 2.x %s mode is unavailable: %s\n' "${role}" "${resolved}" >&2; return 1; }
    printf '%s\n' "${resolved}"; return 0
  fi
  case "${role}" in
    interactive) bqca_bob2_first_available_mode_v512 quantum-qiskit-connector quantum-smart ask quantum-code-default ;;
    expert) bqca_bob2_first_available_mode_v512 quantum-smart ask ;;
    developer) bqca_bob2_first_available_mode_v512 quantum-code-heron quantum-qiskit-connector quantum-code-default ;;
    advanced) bqca_bob2_first_available_mode_v512 quantum-advanced advanced quantum-advanced-default plan ;;
    *) return 1 ;;
  esac
}

bqca_bob2_refresh_modes() {
  BQCA_BOB2_INTERACTIVE_MODE="$(bqca_bob2_resolve_role_mode_v512 "${BQCA_BOB2_INTERACTIVE_MODE:-}" interactive)" || return 1
  BQCA_BOB2_ASK_MODE="$(bqca_bob2_resolve_role_mode_v512 "${BQCA_BOB2_ASK_MODE:-}" expert)" || return 1
  BQCA_BOB2_CODE_MODE="$(bqca_bob2_resolve_role_mode_v512 "${BQCA_BOB2_CODE_MODE:-}" developer)" || return 1
  BQCA_BOB2_ADVANCED_MODE="$(bqca_bob2_resolve_role_mode_v512 "${BQCA_BOB2_ADVANCED_MODE:-}" advanced)" || return 1
  export BQCA_BOB2_INTERACTIVE_MODE BQCA_BOB2_ASK_MODE BQCA_BOB2_CODE_MODE BQCA_BOB2_ADVANCED_MODE
}

bqca_bob2_require_mode() {
  local selected_mode
  selected_mode="$(bqca_bob2_normalize_mode_alias_v512 "${1:-}")"
  [[ -n "${selected_mode}" ]] || { printf '[BQCA][ERROR] Refusing to invoke Bob Shell 2.x with an empty mode.\n' >&2; return 1; }
  bqca_bob2_mode_is_available "${selected_mode}" || { printf '[BQCA][ERROR] Refusing unavailable Bob Shell 2.x mode: %s\n' "${selected_mode}" >&2; return 1; }
  printf '%s\n' "${selected_mode}"
}

bqca_bob2_refresh_modes
# BQCA-BOB2-CUSTOM-MODE-ROUTING-v51.2:END

# BQCA-BOB2-RESUME-v51.3:BEGIN
# Production option-5 contract:
#   - always resume under quantum-qiskit-connector;
#   - select the latest real user task for this workspace;
#   - never resume authentication-probe tasks.
BQCA_BOB2_RESUME_MODE="${BQCA_BOB2_RESUME_MODE:-quantum-qiskit-connector}"
BQCA_BOB2_RESUME_TOOL="${SCRIPT_DIR}/.bob/quantum-tools/bqca-bob2-resume.sh"
export BQCA_BOB2_RESUME_MODE BQCA_BOB2_RESUME_TOOL

bqca_bob2_resolve_resume_mode_v513() {
  local configured
  configured="$(bqca_trim_mode_value "${BQCA_BOB2_RESUME_MODE:-}")"
  if [[ -z "${configured}" ]]; then
    configured="quantum-qiskit-connector"
  fi
  if [[ "${configured}" != "quantum-qiskit-connector" ]]; then
    printf '[BQCA][ERROR] Option 5 requires BQCA_BOB2_RESUME_MODE=quantum-qiskit-connector; actual: %s\n' "${configured}" >&2
    return 1
  fi
  bqca_bob2_require_mode "${configured}"
}

bqca_bob2_latest_user_task_v513() {
  [[ -x "${BQCA_BOB2_RESUME_TOOL}" ]] || {
    printf '[BQCA][ERROR] Bob 2.x resume resolver is missing: %s\n' "${BQCA_BOB2_RESUME_TOOL}" >&2
    return 1
  }
  "${BQCA_BOB2_RESUME_TOOL}" resolve \
    --bob-bin "${BOB_BIN}" \
    --workspace "${SCRIPT_DIR}"
}

bqca_bob2_resume_last_user_session_v513() {
  local resume_mode task_id
  resume_mode="$(bqca_bob2_resolve_resume_mode_v513)" || return 1
  task_id="$(bqca_bob2_latest_user_task_v513)" || return 1
  printf '%bResuming the latest BQCA user session with mode %s...%b\n' \
    "${BOLD}${YELLOW}" "${resume_mode}" "${RESET}"
  bqca_bob2_chat "${resume_mode}" "${task_id}"
}
# BQCA-BOB2-RESUME-v51.3:END



bqca_bob2_run() {
  local selected_mode="$1"
  local user_prompt="$2"
  selected_mode="$(bqca_bob2_require_mode "${selected_mode}")" || return 1
  local -a bob2_args=(
    run
    --mode "${selected_mode}"
    --format "${BQCA_BOB2_OUTPUT_FORMAT}"
    --max-turns "${BQCA_BOB2_MAX_TURNS}"
    --workspace "${SCRIPT_DIR}"
    --trust
    --accept-license
  )

  if [[ -n "${BOB_TEAM_ID:-}" ]]; then
    bob2_args+=(--team-id "${BOB_TEAM_ID}")
  fi

  if [[ "${BQCA_BOB_DEBUG:-0}" == "1" ]]; then
    bob2_args+=(--log-level debug)
  elif [[ -n "${BQCA_BOB2_LOG_LEVEL}" ]]; then
    bob2_args+=(--log-level "${BQCA_BOB2_LOG_LEVEL}")
  fi

  local bqca_enveloped_prompt
  bqca_enveloped_prompt="$(bqca_bob2_envelope_prompt "${user_prompt}" "${selected_mode}")"

  (
    cd "${SCRIPT_DIR}"
    "${BOB_BIN}" "${bob2_args[@]}" "${bqca_enveloped_prompt}"
  )
}

bqca_bob2_chat() {
  local selected_mode="${1:-}"
  local resume_task="${2:-}"
  selected_mode="$(bqca_bob2_require_mode "${selected_mode}")" || return 1
  local -a bob2_args=(chat --trust)

  if [[ -n "${selected_mode}" ]]; then
    bob2_args+=(--mode "${selected_mode}")
  fi

  if [[ -n "${resume_task}" ]]; then
    bob2_args+=(--resume "${resume_task}")
  fi

  if [[ "${BQCA_BOB2_AUTO_APPROVE}" == "1" ]]; then
    [[ -x "${BQCA_CHAT_AUTO_APPROVAL_TOOL}" ]] || {
      printf '[BQCA][ERROR] Missing trusted chat auto-approval tool: %s\n' "${BQCA_CHAT_AUTO_APPROVAL_TOOL}" >&2
      return 1
    }
    "${BQCA_CHAT_AUTO_APPROVAL_TOOL}" check --major 2 --bob-bin "${BOB_BIN}" >/dev/null || return 1
    bob2_args+=(--auto-approve)
  fi

  if [[ -n "${BQCA_BOB2_INSTANCE_ID}" ]]; then
    bob2_args+=(--instance-id "${BQCA_BOB2_INSTANCE_ID}")
  fi

  if [[ "${BQCA_BOB_DEBUG:-0}" == "1" ]]; then
    bob2_args+=(--log-level debug)
  elif [[ -n "${BQCA_BOB2_LOG_LEVEL}" ]]; then
    bob2_args+=(--log-level "${BQCA_BOB2_LOG_LEVEL}")
  fi

  # Bob Shell 2.x documents --team-id for bob run. Some builds also expose it
  # for bob chat. Add it only when the installed chat command advertises it.
  if [[ -n "${BOB_TEAM_ID:-}" ]]; then
    if "${BOB_BIN}" chat --help 2>&1 | grep -q -- '--team-id'; then
      bob2_args+=(--team-id "${BOB_TEAM_ID}")
    else
      printf '[BQCA][WARN] BOB_TEAM_ID is set, but this Bob 2.x chat command does not advertise --team-id.\n' >&2
      printf '[BQCA][WARN] Use an Inference API key or select the team interactively with /team.\n' >&2
    fi
  fi

  (
    cd "${SCRIPT_DIR}"
    "${BOB_BIN}" "${bob2_args[@]}"
  )
}
# BQCA-BOB-SHELL-DUAL-VERSION-COMPATIBILITY:END

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

# bob-auth.sh is sourced into this shell. Refresh the Bob 2.x bindings after
# authentication so no helper can leave the mode variables empty.
if bqca_is_bob2; then
  bqca_bob2_refresh_modes
fi

printf '%b\n' "${CYAN}Bob Time: $(date_time_stamp)${RESET}"
printf '%bSelect menu option (0-5):%b ' "${BOLD}${YELLOW}" "${RESET}"

read -r choice

case "${choice}" in
  1)
    bqca_set_menu_context "1" "Start Interactive BQCA Session" "User Interactive" "${BQCA_BOB2_INTERACTIVE_MODE}"
    printf '%bYou Selected Start Interactive BQCA Session, please wait ⏳%b\n' \
      "${BOLD}${YELLOW}" \
      "${RESET}"

    quantum_interactive() {
      if bqca_is_bob2; then
        bqca_bob2_chat "${BQCA_BOB2_INTERACTIVE_MODE}"
      else
        "${BOB_BIN}" \
          --chat-mode code \
          --accept-license true \
          --instance-id "${BOB_INSTANCE_ID}" \
          --include-directories "${BOB_INCLUDED_DIRECTORY}" \
          "${BOB_QUANTUM_TOOL_FLAGS[@]}" \
          --hide-intermediary-output \
          --prompt-interactive "${INITIAL_PROMPT}"
      fi
    }

    quantum_interactive
    ;;

  2)
    bqca_set_menu_context "2" "Ask Quantum Computing Questions" "Quantum Expert" "${BQCA_BOB2_ASK_MODE}"
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
      if bqca_is_bob2; then
        bqca_bob2_run "${BQCA_BOB2_ASK_MODE}" "${prompt}"
      else
        "${BOB_BIN}" "${prompt}" \
          --chat-mode ask \
          --accept-license true \
          --instance-id "${BOB_INSTANCE_ID}" \
          --include-directories "${BOB_INCLUDED_DIRECTORY}" \
          "${BOB_QUANTUM_TOOL_FLAGS[@]}" \
          --hide-intermediary-output
      fi
    }

    run_with_spinner \
      "BQCA Quantum Expert is analyzing your question, please wait ⏳" \
      quantum_assist
    ;;

  3)
    bqca_set_menu_context "3" "Quantum Computing Algorithm Implementation Concierge" "Quantum Developer" "${BQCA_BOB2_CODE_MODE}"
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
      if bqca_is_bob2; then
        bqca_bob2_run "${BQCA_BOB2_CODE_MODE}" "${prompt}"
      else
        "${BOB_BIN}" "${prompt}" \
          --chat-mode code \
          --accept-license true \
          --trust \
          --instance-id "${BOB_INSTANCE_ID}" \
          --include-directories "${BOB_INCLUDED_DIRECTORY}" \
          "${BOB_QUANTUM_TOOL_FLAGS[@]}" \
          --hide-intermediary-output
      fi
    }

    run_with_spinner \
      "BQCA Quantum Developer is implementing your request, please wait ⏳" \
      quantum_code
    ;;

  4)
    bqca_set_menu_context "4" "Advanced Quantum Computing Solution Design Concierge" "Quantum Advanced" "${BQCA_BOB2_ADVANCED_MODE}"
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
      if bqca_is_bob2; then
        bqca_bob2_run "${BQCA_BOB2_ADVANCED_MODE}" "${prompt}"
      else
        "${BOB_BIN}" "${prompt}" \
          --chat-mode advanced \
          --accept-license true \
          --trust \
          --instance-id "${BOB_INSTANCE_ID}" \
          --include-directories "${BOB_INCLUDED_DIRECTORY}" \
          "${BOB_QUANTUM_TOOL_FLAGS[@]}" \
          --hide-intermediary-output
      fi
    }

    run_with_spinner \
      "BQCA Quantum Advanced is designing your solution, please wait ⏳" \
      quantum_advanced
    ;;

  5)
    bqca_set_menu_context "5" "Resume BQCA Last Activity" "Resume Session" "quantum-qiskit-connector"
    printf '%bYou Selected BQCA Quantum Resume for Return to Last Activity, please wait ⏳%b\n' \
      "${BOLD}${YELLOW}" \
      "${RESET}"

    quantum_resume() {
      if bqca_is_bob2; then
        bqca_bob2_resume_last_user_session_v513
      else
        "${BOB_BIN}" \
          --resume latest \
          --instance-id "${BOB_INSTANCE_ID}" \
          --include-directories "${BOB_INCLUDED_DIRECTORY}" \
          --hide-intermediary-output
      fi
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

# BQCA-BOB-SHELL-V2-DNA:BEGIN
# In a trusted Bob Shell 2.x workspace, bind this component to AGENTS.md, the
# active central BQCA policy, exported menu context, current rules/skills/tools,
# and the offline knowledgebase without changing this component's core purpose.
# BQCA-BOB-SHELL-V2-DNA:END
