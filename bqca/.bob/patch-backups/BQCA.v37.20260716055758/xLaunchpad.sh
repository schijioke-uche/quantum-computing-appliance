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
source "$SCRIPT_DIR/.env"
set +a

# Bob Instance ID:
#------------------------------------
: "${BOB_INSTANCE_ID:?BOB_INSTANCE_ID is not set in the .env}"

# # [Bob Instance ID and API Key (Pro Plus)]:
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


# Switch "on" one plan: Use one or the other at a time. You cannot switch both on at the same time.
#-----------------------------------------------------------------------------------
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
