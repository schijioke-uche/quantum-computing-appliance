#!/usr/bin/env bash

# @Author: Dr. Jeffrey Chijioke-Uche, IBM
#==================================================================
# Bob Authentication Script - Production Version
# Authenticates Bob CLI using API key from .env without browser
#==================================================================

set -Eeuo pipefail

# Load persistent Bob Shell version for appliance version-aware paths.
if [[ -z "${BOB_VERSION:-}" ]]; then
  _BOB_VERSION_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [[ -f "${_BOB_VERSION_SCRIPT_DIR}/bob-version.sh" ]]; then
    # shellcheck source=/dev/null
    source "${_BOB_VERSION_SCRIPT_DIR}/bob-version.sh"
    # cp bob-quantum-v1.0.5.sh bob-quantum-v${BOB_VERSION}.sh
  fi
  unset _BOB_VERSION_SCRIPT_DIR
fi
umask 077

#------------------------------------------------------------------
# Resolve script directory
#------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

#------------------------------------------------------------------
# Source TLS control settings
#------------------------------------------------------------------
TLS_CONTROL_FILE="$SCRIPT_DIR/tls-control.sh"

if [[ ! -f "$TLS_CONTROL_FILE" ]]; then
  echo "ERROR: Missing TLS control file: $TLS_CONTROL_FILE" >&2
  exit 1
fi

source "$TLS_CONTROL_FILE"

#------------------------------------------------------------------
# Load environment variables from .env
#------------------------------------------------------------------
ENV_FILE="$SCRIPT_DIR/.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: Missing .env file: $ENV_FILE" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

#------------------------------------------------------------------
# Validate required variables
#------------------------------------------------------------------
: "${BOB_API_KEY:?ERROR: BOB_API_KEY is required in .env}"
: "${BOB_ENDPOINT:?ERROR: BOB_ENDPOINT is required in .env}"
: "${BOB_AUTH_ENDPOINT:?ERROR: BOB_AUTH_ENDPOINT is required in .env}"

BOB_REGION="${BOB_REGION:-us-east}"
BOB_BIN="${BOB_BIN:-bob}"

if ! command -v "$BOB_BIN" >/dev/null 2>&1; then
  echo "ERROR: Bob CLI command not found: $BOB_BIN" >&2
  echo "Ensure Bob is installed and available in PATH, or set BOB_BIN in .env." >&2
  exit 1
fi

#------------------------------------------------------------------
# Export Bob configuration
#------------------------------------------------------------------
export BOB_API_KEY
export BOB_ENDPOINT
export BOB_AUTH_ENDPOINT
export BOB_REGION

#------------------------------------------------------------------
# Bob credential directory and files
#------------------------------------------------------------------
BOB_DIR="$HOME/.bob"
TOKEN_FILE="$BOB_DIR/token.json"
CONFIG_FILE="$BOB_DIR/config.json"

mkdir -p "$BOB_DIR"
chmod 700 "$BOB_DIR"

#------------------------------------------------------------------
# Backup existing credential files
#------------------------------------------------------------------
timestamp="$(TZ="America/New_York" date "+%Y%m%d-%H%M%S-%Z")"

if [[ -f "$TOKEN_FILE" ]]; then
  cp -p "$TOKEN_FILE" "$TOKEN_FILE.bak.$timestamp"
fi

if [[ -f "$CONFIG_FILE" ]]; then
  cp -p "$CONFIG_FILE" "$CONFIG_FILE.bak.$timestamp"
fi

#------------------------------------------------------------------
# Write credential files atomically
#------------------------------------------------------------------
TOKEN_TMP="$(mktemp "$BOB_DIR/token.json.tmp.XXXXXX")"
CONFIG_TMP="$(mktemp "$BOB_DIR/config.json.tmp.XXXXXX")"

cat > "$TOKEN_TMP" <<JSON
{
  "access_token": "$BOB_API_KEY",
  "token_type": "Bearer",
  "expires_at": 9999999999,
  "scope": "openid email profile"
}
JSON

cat > "$CONFIG_TMP" <<JSON
{
  "apiKey": "$BOB_API_KEY",
  "apiEndpoint": "$BOB_ENDPOINT",
  "authEndpoint": "$BOB_AUTH_ENDPOINT",
  "region": "$BOB_REGION"
}
JSON

chmod 600 "$TOKEN_TMP" "$CONFIG_TMP"
mv "$TOKEN_TMP" "$TOKEN_FILE"
mv "$CONFIG_TMP" "$CONFIG_FILE"

#------------------------------------------------------------------
# Validate JSON structure
#------------------------------------------------------------------
python3 - <<PY
import json
from pathlib import Path

for file_path in [Path("$TOKEN_FILE"), Path("$CONFIG_FILE")]:
    with file_path.open("r", encoding="utf-8") as f:
        json.load(f)
PY

#------------------------------------------------------------------
# Confirm files exist and are non-empty
#------------------------------------------------------------------
if [[ ! -s "$TOKEN_FILE" || ! -s "$CONFIG_FILE" ]]; then
  echo "Bob Shell Authentication Failed: credential files were not created correctly." >&2
  exit 1
fi

#------------------------------------------------------------------
# Actual Bob authentication validation:
#------------------------------------------------------------------
if "$BOB_BIN" --list-sessions --accept-license true >/dev/null 2>&1; then
  printf '%b\n' "${CYAN}Bob Shell Authenticated Successfully!${RESET}"
  export BOBSHELL_API_KEY="${BOB_API_KEY}"
  # echo "Credential files:"
  # echo "  $TOKEN_FILE"
  # echo "  $CONFIG_FILE"
else
  echo "Bob Shell Authentication Failed: Bob CLI could not validate the configured credentials." >&2
  echo "Check BOB_API_KEY, BOB_ENDPOINT, BOB_AUTH_ENDPOINT, BOB_REGION, and TLS settings." >&2
  exit 1
fi

# Happy coding! - Dr. Jeffrey Chijioke-Uche, IBM

# BQCA-BOB-SHELL-V2-DNA:BEGIN
# In a trusted Bob Shell 2.x workspace, bind this component to AGENTS.md, the
# active central BQCA policy, exported menu context, current rules/skills/tools,
# and the offline knowledgebase without changing this component's core purpose.
# BQCA-BOB-SHELL-V2-DNA:END
