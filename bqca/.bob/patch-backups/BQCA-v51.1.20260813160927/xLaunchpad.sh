#!/usr/bin/env bash
set -Eeuo pipefail

_BQCA_BOOTSTRAP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
if [[ -f "${_BQCA_BOOTSTRAP_DIR}/configure-bob-auth-browser.sh" ]]; then
  chmod 755 "${_BQCA_BOOTSTRAP_DIR}/configure-bob-auth-browser.sh"
  # shellcheck source=/dev/null
  source "${_BQCA_BOOTSTRAP_DIR}/configure-bob-auth-browser.sh"
fi
unset _BQCA_BOOTSTRAP_DIR

# BQCA-ROOT-FILENAME-VERSION-SYNC-49:BEGIN
# First operational action: detect the installed Bob Shell version and update
# older Bob-version tokens found in regular filenames directly under the BQCA
# project root before any other appliance initialization executes.
_BQCA49_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_BQCA49_VERSION_SYNC_TOOL="${_BQCA49_SCRIPT_DIR}/bob-filename-version-sync.sh"
if [[ ! -x "${_BQCA49_VERSION_SYNC_TOOL}" ]]; then
  printf '[BQCA-49][ERROR] Required filename-version synchronization helper is missing or not executable: %s\n' \
    "${_BQCA49_VERSION_SYNC_TOOL}" >&2
  exit 1
fi
current_bob_version="$("${_BQCA49_VERSION_SYNC_TOOL}" --sync --print-version --quiet)"
if [[ -z "${current_bob_version}" ]]; then
  printf '[BQCA-49][ERROR] Bob Shell version detection returned an empty value.\n' >&2
  exit 1
fi
BOB_VERSION="${current_bob_version}"
export current_bob_version BOB_VERSION
_BQCA49_EXPECTED_LAUNCHER="${_BQCA49_SCRIPT_DIR}/bob-quantum-v${current_bob_version}.sh"
if [[ ! -f "${_BQCA49_EXPECTED_LAUNCHER}" ]]; then
  printf '[BQCA-49][ERROR] The version-aligned BQCA launcher was not found after synchronization: %s\n' \
    "${_BQCA49_EXPECTED_LAUNCHER}" >&2
  exit 1
fi
unset _BQCA49_SCRIPT_DIR _BQCA49_VERSION_SYNC_TOOL _BQCA49_EXPECTED_LAUNCHER
# BQCA-ROOT-FILENAME-VERSION-SYNC-49:END

# BQCA-CRITICAL-PERMISSION-GUARD-v50:BEGIN
# Repair permission drift caused by Bob upgrades, archive extraction, or Git
# mode changes before active-policy assurance runs. BQCA-49 filename/version
# synchronization remains the first operational action when it is installed.
_BQCA50_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
_BQCA50_PERMISSION_GUARD="${_BQCA50_ROOT}/.bob/quantum-tools/bqca-permission-guard.sh"
if [[ ! -f "${_BQCA50_PERMISSION_GUARD}" ]]; then
  printf '[BQCA v50][ERROR] Required permission guard is missing: %s
'     "${_BQCA50_PERMISSION_GUARD}" >&2
  exit 1
fi
if ! bash "${_BQCA50_PERMISSION_GUARD}" repair --quiet; then
  printf '[BQCA v50][ERROR] Critical BQCA permissions could not be repaired. Run: %s report
'     "${_BQCA50_PERMISSION_GUARD}" >&2
  exit 1
fi
unset _BQCA50_ROOT _BQCA50_PERMISSION_GUARD
# BQCA-CRITICAL-PERMISSION-GUARD-v50:END



#===============================================================================
# @Author: Dr. Jeffrey Chijioke-Uche, IBM Computer Scientist
# @Description: Launchpad for interacting with IBM Bob Quantum Computing Agent (BQCA)
# @AI Tool: IBM Bob Shell
#===============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load persistent Bob Shell version for appliance version-aware paths.
if [[ -z "${BOB_VERSION:-}" ]]; then
  _BOB_VERSION_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# BQCA-BOB-MODE-PREFLIGHT-v48-update-3:BEGIN
_BQCA_BOB_MODE_DOCTOR="${SCRIPT_DIR}/.bob/quantum-tools/bqca-bob-mode-doctor.sh"
if [[ ! -x "${_BQCA_BOB_MODE_DOCTOR}" ]]; then
  printf '[BQCA][ERROR] Bob mode/configuration doctor is missing: %s\n' \
    "${_BQCA_BOB_MODE_DOCTOR}" >&2
  exit 1
fi
if ! "${_BQCA_BOB_MODE_DOCTOR}" check --quiet; then
  printf '[BQCA][ERROR] Invalid BQCA custom-mode configuration. Run: %s report\n' \
    "${_BQCA_BOB_MODE_DOCTOR}" >&2
  exit 1
fi
# BQCA-BOB-MODE-PREFLIGHT-v48-update-3:END

  if [[ -f "${_BOB_VERSION_SCRIPT_DIR}/bob-version.sh" ]]; then
    # shellcheck source=/dev/null
    source "${_BOB_VERSION_SCRIPT_DIR}/bob-version.sh"
  fi
  unset _BOB_VERSION_SCRIPT_DIR
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# BQCA-BOB-SHELL-V2-DNA-PREFLIGHT-v51.0:BEGIN
_BQCA_BOB2_DNA_DOCTOR="${SCRIPT_DIR}/.bob/quantum-tools/bqca-bob2-dna-doctor.sh"
if [[ ! -x "${_BQCA_BOB2_DNA_DOCTOR}" ]]; then
  printf '[BQCA][ERROR] Bob Shell 2.x BQCA DNA doctor is missing: %s\n' \
    "${_BQCA_BOB2_DNA_DOCTOR}" >&2
  exit 1
fi
if ! "${_BQCA_BOB2_DNA_DOCTOR}" check --quiet; then
  printf '[BQCA][ERROR] Bob Shell 2.x BQCA project-DNA drift detected. Run: %s report\n' \
    "${_BQCA_BOB2_DNA_DOCTOR}" >&2
  exit 1
fi
# BQCA-BOB-SHELL-V2-DNA-PREFLIGHT-v51.0:END

source "${SCRIPT_DIR}/xdg.sh" --check

set -a
source "${SCRIPT_DIR}/.env"
set +a

# BQCA-ACTIVE-POLICY-ASSURANCE:BEGIN
_BQCA_ACTIVE_POLICY_LISTENER="${SCRIPT_DIR}/.bob/quantum-tools/bqca-active-policy-listener.sh"
_BQCA_ACTIVE_POLICY_DOCTOR="${SCRIPT_DIR}/.bob/quantum-tools/bqca-policy-doctor.sh"
_BQCA_ACTIVE_POLICY_COMPLIANCE="${SCRIPT_DIR}/.bob/quantum-tools/bqca-policy-compliance.sh"
for _bqca_policy_tool in \
  "${_BQCA_ACTIVE_POLICY_LISTENER}" \
  "${_BQCA_ACTIVE_POLICY_DOCTOR}" \
  "${_BQCA_ACTIVE_POLICY_COMPLIANCE}"; do
  if [[ ! -x "${_bqca_policy_tool}" ]]; then
    printf '[BQCA][ERROR] Active-policy tool is missing: %s\n' "${_bqca_policy_tool}" >&2
    exit 1
  fi
done
if ! "${_BQCA_ACTIVE_POLICY_LISTENER}" sync --quiet; then
  printf '[BQCA][ERROR] Unable to resolve the active BQCA policy.\n' >&2
  exit 1
fi
# A newly activated policy changes the policy/contract hashes. Refresh every
# governed artifact report before the doctor evaluates drift so policy changes
# do not require validator or launcher source modifications.
_BQCA_PREFLIGHT_DESIGN_STORE="${QCA_DESIGN_DIR:-${SCRIPT_DIR}/bob-quantum-designs}"
_BQCA_PREFLIGHT_CODE_STORE="${QCA_STORE_DIR:-${SCRIPT_DIR}/bob-quantum-store}"
if [[ "${_BQCA_PREFLIGHT_DESIGN_STORE}" != /* ]]; then
  _BQCA_PREFLIGHT_DESIGN_STORE="${SCRIPT_DIR}/${_BQCA_PREFLIGHT_DESIGN_STORE}"
fi
if [[ "${_BQCA_PREFLIGHT_CODE_STORE}" != /* ]]; then
  _BQCA_PREFLIGHT_CODE_STORE="${SCRIPT_DIR}/${_BQCA_PREFLIGHT_CODE_STORE}"
fi
if ! "${_BQCA_ACTIVE_POLICY_COMPLIANCE}" sweep \
  --design-store "${_BQCA_PREFLIGHT_DESIGN_STORE}" \
  --code-store "${_BQCA_PREFLIGHT_CODE_STORE}" >/dev/null 2>&1; then
  printf '[BQCA][ERROR] Unable to refresh active-policy compliance reports.\n' >&2
  exit 1
fi
if ! "${_BQCA_ACTIVE_POLICY_DOCTOR}" check --quiet; then
  _BQCA_ACTIVE_POLICY_VERSION="$("${_BQCA_ACTIVE_POLICY_LISTENER}" version 2>/dev/null || printf 'UNKNOWN')"
  printf '[BQCA][ERROR] BQCA %s active-policy drift detected. Run: %s repair\n' \
    "${_BQCA_ACTIVE_POLICY_VERSION}" "${_BQCA_ACTIVE_POLICY_DOCTOR}" >&2
  exit 1
fi
unset _bqca_policy_tool _BQCA_ACTIVE_POLICY_VERSION \
  _BQCA_PREFLIGHT_DESIGN_STORE _BQCA_PREFLIGHT_CODE_STORE
# BQCA-ACTIVE-POLICY-ASSURANCE:END



# BQCA-QISKIT-HOME-ENV-v40:BEGIN
# The only authorized BQCA Qiskit runtime is outside the project root.
: "${HOME:?HOME must be set for BQCA qiskit-v2x-env}"
_BQCA_QISKIT_V40_HOME_ENV="$(cd "${HOME}" && pwd -P)/qiskit-v2x-env"
case "${_BQCA_QISKIT_V40_HOME_ENV}/" in
  "${SCRIPT_DIR}/"*)
    printf '[BQCA][ERROR] HOME-scoped qiskit-v2x-env resolves inside the BQCA project root: %s\n' \
      "${_BQCA_QISKIT_V40_HOME_ENV}" >&2
    exit 1
    ;;
esac
export BQCA_QISKIT_V40_HOME_ENV="${_BQCA_QISKIT_V40_HOME_ENV}"
# BQCA-QISKIT-HOME-ENV-v40:END


# BQCA-QISKIT-EXECUTION-v39-update-1:BEGIN
# Export the mandatory isolated Qiskit runtime and validation tools.
_BQCA_QISKIT_V39_ENV_TOOL="${SCRIPT_DIR}/.bob/quantum-tools/qiskit-v2x-environment.sh"
_BQCA_QISKIT_V39_CODE_VALIDATOR="${SCRIPT_DIR}/.bob/quantum-tools/qiskit-code-policy-check.py"
_BQCA_QISKIT_V39_DESIGN_VALIDATOR="${SCRIPT_DIR}/.bob/quantum-tools/qiskit-design-policy-check.py"
for _bqca_v39_required in \
  "${_BQCA_QISKIT_V39_ENV_TOOL}" \
  "${_BQCA_QISKIT_V39_CODE_VALIDATOR}" \
  "${_BQCA_QISKIT_V39_DESIGN_VALIDATOR}"; do
  if [[ ! -x "${_bqca_v39_required}" ]]; then
    printf '[BQCA][ERROR] Required v39 update 1 tool is missing: %s\n' \
      "${_bqca_v39_required}" >&2
    exit 1
  fi
done
export BQCA_QISKIT_V39_ENV_TOOL="${_BQCA_QISKIT_V39_ENV_TOOL}"
export BQCA_QISKIT_V39_CODE_VALIDATOR="${_BQCA_QISKIT_V39_CODE_VALIDATOR}"
export BQCA_QISKIT_V39_DESIGN_VALIDATOR="${_BQCA_QISKIT_V39_DESIGN_VALIDATOR}"
unset _bqca_v39_required
# BQCA-QISKIT-EXECUTION-v39-update-1:END


# BQCA-QISKIT-CONFIGURATION-v38:BEGIN
# Production gate: configure the single default "bqca" Qiskit account before
# IBM Bob can invoke qiskit_connector behavior during this BQCA session.
_BQCA_QISKIT_CONFIGURATION_TOOL="${SCRIPT_DIR}/.bob/quantum-tools/qiskit-configuration.sh"
export BQCA_QISKIT_CONFIGURATION_TOOL="${_BQCA_QISKIT_CONFIGURATION_TOOL}"
if [[ ! -x "${_BQCA_QISKIT_CONFIGURATION_TOOL}" ]]; then
  printf '[BQCA][ERROR] Required Qiskit configuration tool is missing: %s\n' \
    "${_BQCA_QISKIT_CONFIGURATION_TOOL}" >&2
  exit 1
fi
if ! "${_BQCA_QISKIT_CONFIGURATION_TOOL}" configure --project-root "${SCRIPT_DIR}" --quiet; then
  printf '[BQCA][ERROR] Unable to configure the required bqca Qiskit account.\n' >&2
  exit 1
fi
# BQCA-QISKIT-CONFIGURATION-v38:END


#===============================================================================
# BQCA-AUTOMATIC-POLICY-COMPLIANCE:BEGIN
_BQCA_POLICY_COMPLIANCE_TOOL="${SCRIPT_DIR}/.bob/quantum-tools/bqca-policy-compliance.sh"
_BQCA_POLICY_DESIGN_STORE="${QCA_DESIGN_DIR:-${SCRIPT_DIR}/bob-quantum-designs}"
_BQCA_POLICY_CODE_STORE="${QCA_STORE_DIR:-${SCRIPT_DIR}/bob-quantum-store}"
for _bqca_store_var in _BQCA_POLICY_DESIGN_STORE _BQCA_POLICY_CODE_STORE; do
  if [[ "${!_bqca_store_var}" != /* ]]; then
    printf -v "${_bqca_store_var}" '%s/%s' "${SCRIPT_DIR}" "${!_bqca_store_var}"
  fi
done
if [[ ! -x "${_BQCA_POLICY_COMPLIANCE_TOOL}" ]]; then
  printf '[BQCA][ERROR] Automatic policy-compliance tool is missing: %s\n' \
    "${_BQCA_POLICY_COMPLIANCE_TOOL}" >&2
  exit 1
fi
"${_BQCA_POLICY_COMPLIANCE_TOOL}" start \
  --design-store "${_BQCA_POLICY_DESIGN_STORE}" \
  --code-store "${_BQCA_POLICY_CODE_STORE}" >/dev/null 2>&1
_bqca_policy_compliance_cleanup() {
  "${_BQCA_POLICY_COMPLIANCE_TOOL}" stop >/dev/null 2>&1 || true
  "${_BQCA_POLICY_COMPLIANCE_TOOL}" sweep \
    --design-store "${_BQCA_POLICY_DESIGN_STORE}" \
    --code-store "${_BQCA_POLICY_CODE_STORE}" >/dev/null 2>&1 || true
}
unset _bqca_store_var
# BQCA-AUTOMATIC-POLICY-COMPLIANCE:END


# BQCA-NOTEBOOK-AUTOGEN-v37:BEGIN
#
# Production enforcement:
# Automatically create/refresh .ipynb after every .py implementation written
# under the BQCA implementation store.
#
# Exit cleanup is intentionally SILENT.
#===============================================================================

_BQCA_NOTEBOOK_AUTOGEN_TOOL="${SCRIPT_DIR}/.bob/quantum-tools/notebook-autogen.sh"
_BQCA_NOTEBOOK_STORE="${QCA_STORE_DIR:-${SCRIPT_DIR}/bob-quantum-store}"

if [[ "${_BQCA_NOTEBOOK_STORE}" != /* ]]; then
    _BQCA_NOTEBOOK_STORE="${SCRIPT_DIR}/${_BQCA_NOTEBOOK_STORE}"
fi

if [[ -x "${_BQCA_NOTEBOOK_AUTOGEN_TOOL}" ]]; then

    "${_BQCA_NOTEBOOK_AUTOGEN_TOOL}" start \
        --store "${_BQCA_NOTEBOOK_STORE}"

    _bqca_notebook_autogen_cleanup() {

        # Sweep pending notebook generation requests silently.
        "${_BQCA_NOTEBOOK_AUTOGEN_TOOL}" sweep \
            --store "${_BQCA_NOTEBOOK_STORE}" \
            >/dev/null 2>&1 || true

        # Stop the watcher silently.
        "${_BQCA_NOTEBOOK_AUTOGEN_TOOL}" stop \
            >/dev/null 2>&1 || true
    }
else
    printf '[BQCA][ERROR] Required notebook auto-generation tool is missing: %s\n' \
        "${_BQCA_NOTEBOOK_AUTOGEN_TOOL}" >&2
    exit 1
fi

#===============================================================================
# BQCA-NOTEBOOK-AUTOGEN-v37:END
#=============================================================================

# BQCA-COMBINED-RUNTIME-CLEANUP:BEGIN
_bqca_combined_runtime_cleanup() {
  _bqca_policy_compliance_cleanup || true
  _bqca_notebook_autogen_cleanup || true
}
trap _bqca_combined_runtime_cleanup EXIT
# BQCA-COMBINED-RUNTIME-CLEANUP:END
#==============================================================================


# Bob Instance ID:
#-------------------------------------------
: "${BOB_INSTANCE_ID:?BOB_INSTANCE_ID is not set in the .env}"

# [Bob Instance ID and API Key (Pro Plus)]:
#--------------------------------------------
: "${BOB_API_KEY:?BOB_API_KEY is not set in the .env}"

# Quantum Account Token:
#------------------------------------------
: "${IQP_API_TOKEN:?IQP_API_TOKEN is not set in the .env}"

# Channels:
#------------------------------------------
: "${OPEN_PLAN_CHANNEL:?OPEN_PLAN_CHANNEL is not set in the .env}"
: "${PAID_PLAN_CHANNEL:?PAID_PLAN_CHANNEL is not set in the .env}"

# API Access:
#-------------------------------------
: "${IQP_API_URL:?IQP_API_URL is not set in the .env}"
: "${IQP_RUNTIME_BACKEND_URL:?IQP_RUNTIME_BACKEND_URL is not set in the .env}"

# Quantum Url:
#-------------------------------------
: "${CLOUD_API_URL:?CLOUD_API_URL is not set in the .env}"
: "${QUANTUM_API_URL:?QUANTUM_API_URL is not set in the .env}"

# Instance CRN:
#-------------------------------------
: "${OPEN_PLAN_INSTANCE:?OPEN_PLAN_INSTANCE is not set in the .env. Go to https://quantum.cloud.ibm.com , sign in and copy the CRN of your Open plan instance.}"
: "${PAID_PLAN_INSTANCE:?PAID_PLAN_INSTANCE is not set in the .env}"

# Default (Open plan) - free:
#--------------------------------------------------
: "${OPEN_PLAN_NAME:?OPEN_PLAN_NAME is not set in the .env}"

# Optional (Upgrade) - Pay-As-You-Go:
#--------------------------------------------------
: "${PAYGO_PLAN_NAME:?PAYGO_PLAN_NAME is not set in the .env}"

# Optional (Upgrade) - Flex:
#--------------------------------------------------
: "${FLEX_PLAN_NAME:?FLEX_PLAN_NAME is not set in the .env}"

# Optional (Upgrade) - Premium:
#--------------------------------------------------
: "${PREMIUM_PLAN_NAME:?PREMIUM_PLAN_NAME is not set in the .env}"

# Optional (Upgrade) - Dedicated:
#--------------------------------------------------
: "${DEDICATED_PLAN_NAME:?DEDICATED_PLAN_NAME is not set in the .env}"

# Switch "on" one plan: Use one or the other at a time.
#--------------------------------------------------
: "${OPEN_PLAN:?OPEN_PLAN is not set in the .env}"
: "${FLEX_PLAN:?FLEX_PLAN is not set in the .env}"
: "${PAYGO_PLAN:?PAYGO_PLAN is not set in the .env}"
: "${PREMIUM_PLAN:?PREMIUM_PLAN is not set in the .env}"
: "${DEDICATED_PLAN:?DEDICATED_PLAN is not set in the .env}"

#===============================================================================
# @Author: Dr. Jeffrey Chijioke-Uche, IBM Computer Scientist
# @Description: Launchpad for interacting with IBM Bob Quantum Computing Agent (BQCA)
# @Version: v${BOB_VERSION}
#===============================================================================

source "${SCRIPT_DIR}/bob-quantum-v${BOB_VERSION}.sh"

# BQCA-BOB-SHELL-V2-DNA:BEGIN
# In a trusted Bob Shell 2.x workspace, bind this component to AGENTS.md, the
# active central BQCA policy, exported menu context, current rules/skills/tools,
# and the offline knowledgebase without changing this component's core purpose.
# BQCA-BOB-SHELL-V2-DNA:END
