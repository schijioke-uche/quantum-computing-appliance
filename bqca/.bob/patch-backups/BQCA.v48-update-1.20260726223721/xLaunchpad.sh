#!/usr/bin/env bash
set -Eeuo pipefail

#===============================================================================
# @Author: Dr. Jeffrey Chijioke-Uche, IBM Computer Scientist
# @Description: Launchpad for interacting with IBM Bob Quantum Computing Agent (BQCA)
# @AI Tool: IBM Bob Shell
#===============================================================================

# Load persistent Bob Shell version for appliance version-aware paths.
if [[ -z "${BOB_VERSION:-}" ]]; then
  _BOB_VERSION_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [[ -f "${_BOB_VERSION_SCRIPT_DIR}/bob-version.sh" ]]; then
    # shellcheck source=/dev/null
    source "${_BOB_VERSION_SCRIPT_DIR}/bob-version.sh"
  fi
  unset _BOB_VERSION_SCRIPT_DIR
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/xdg.sh" --check

set -a
source "${SCRIPT_DIR}/.env"
set +a

# BQCA-POLICY-ASSURANCE-v48:BEGIN
_BQCA_V48_POLICY_DOCTOR="${SCRIPT_DIR}/.bob/quantum-tools/bqca-policy-doctor.sh"
if [[ ! -x "${_BQCA_V48_POLICY_DOCTOR}" ]]; then
  printf '[BQCA][ERROR] BQCA v48 policy doctor is missing: %s\n' "${_BQCA_V48_POLICY_DOCTOR}" >&2
  exit 1
fi
if ! "${_BQCA_V48_POLICY_DOCTOR}" check --quiet; then
  printf '[BQCA][ERROR] BQCA v48 policy drift detected. Run: %s repair\n' "${_BQCA_V48_POLICY_DOCTOR}" >&2
  exit 1
fi
unset _BQCA_V48_POLICY_DOCTOR
# BQCA-POLICY-ASSURANCE-v48:END

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

    trap _bqca_notebook_autogen_cleanup EXIT

else
    printf '[BQCA][ERROR] Required notebook auto-generation tool is missing: %s\n' \
        "${_BQCA_NOTEBOOK_AUTOGEN_TOOL}" >&2
    exit 1
fi

#===============================================================================
# BQCA-NOTEBOOK-AUTOGEN-v37:END
#===============================================================================


# Bob Instance ID:
#------------------------------------
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