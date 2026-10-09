#!/usr/bin/env bash
set -Eeuo pipefail

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

source "${SCRIPT_DIR}/xdg.sh" --install

set -a
source "$SCRIPT_DIR/.env"
set +a

# Checking Bob Shell API Key:
: "${BOB_API_KEY:?BOB_API_KEY is not set in the .env}"

# Checking Bob Instance ID:
: "${BOB_INSTANCE_ID:?BOB_INSTANCE_ID is not set in the .env}"


#===============================================================================
# @Author: Dr. Jeffrey Chijioke-Uche, IBM Computer Scientist
# @Description: Launchpad for interacting with IBM Bob Quantum Computing Agent (QCA)
# @Version: v${BOB_VERSION}
#===============================================================================
source "${SCRIPT_DIR}/bob-quantum-v${BOB_VERSION}.sh"
