#!/usr/bin/env bash
#===============================================================================
# @Author: Dr. Jeffrey Chijioke-Uche, IBM
# @Description: Version-aware IBM Bob Shell authentication for Bob 1.x and 2.x
# @Authentication: Browserless API-key authentication from the appliance .env
#===============================================================================

set -Eeuo pipefail
umask 077

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TLS_CONTROL_FILE="${SCRIPT_DIR}/tls-control.sh"
ENV_FILE="${SCRIPT_DIR}/.env"
BOB_BIN="${BOB_BIN:-bob}"

log_info() {
  printf '%s\n' "[bob-auth] INFO: $*" >&2
}

fail() {
  printf '%s\n' "[bob-auth] ERROR: $*" >&2
  exit 1
}

# Load the appliance TLS policy before invoking Bob.
[[ -f "${TLS_CONTROL_FILE}" ]] || fail "Missing TLS control file: ${TLS_CONTROL_FILE}"
# shellcheck source=/dev/null
source "${TLS_CONTROL_FILE}"

# Load appliance credentials and configuration.
[[ -f "${ENV_FILE}" ]] || fail "Missing .env file: ${ENV_FILE}"
set -a
# shellcheck source=/dev/null
source "${ENV_FILE}"
set +a

BOB_BIN="${BOB_BIN:-bob}"
command -v "${BOB_BIN}" >/dev/null 2>&1 || \
  fail "Bob CLI command not found: ${BOB_BIN}"

# Detect the installed Bob Shell version from the CLI itself.
BOB_VERSION_RAW="$("${BOB_BIN}" --version 2>&1 || true)"
BOB_VERSION_DETECTED="$(
  printf '%s\n' "${BOB_VERSION_RAW}" |
    tr -d '\r' |
    grep -Eo '[0-9]+([.][0-9]+){1,3}([-.][A-Za-z0-9]+)?' |
    head -n 1 || true
)"
[[ -n "${BOB_VERSION_DETECTED}" ]] || \
  fail "Unable to determine Bob Shell version from: ${BOB_VERSION_RAW:-<empty>}"

BOB_VERSION="${BOB_VERSION_DETECTED}"
BOB_MAJOR_VERSION="${BOB_VERSION%%.*}"
export BOB_VERSION

case "${BOB_MAJOR_VERSION}" in
  1)
    # Bob Shell 1.x compatibility path. Preserve the legacy appliance contract.
    : "${BOB_API_KEY:?ERROR: BOB_API_KEY is required in .env for Bob Shell 1.x}"
    : "${BOB_ENDPOINT:?ERROR: BOB_ENDPOINT is required in .env for Bob Shell 1.x}"
    : "${BOB_AUTH_ENDPOINT:?ERROR: BOB_AUTH_ENDPOINT is required in .env for Bob Shell 1.x}"

    BOB_REGION="${BOB_REGION:-us-east}"
    export BOB_API_KEY BOB_ENDPOINT BOB_AUTH_ENDPOINT BOB_REGION

    BOB_DIR="${HOME}/.bob"
    TOKEN_FILE="${BOB_DIR}/token.json"
    CONFIG_FILE="${BOB_DIR}/config.json"
    TIMESTAMP="$(TZ='America/New_York' date '+%Y%m%d-%H%M%S-%Z')"

    mkdir -p "${BOB_DIR}"
    chmod 700 "${BOB_DIR}"

    [[ ! -f "${TOKEN_FILE}" ]] || cp -p "${TOKEN_FILE}" "${TOKEN_FILE}.bak.${TIMESTAMP}"
    [[ ! -f "${CONFIG_FILE}" ]] || cp -p "${CONFIG_FILE}" "${CONFIG_FILE}.bak.${TIMESTAMP}"

    python3 - "${TOKEN_FILE}" "${CONFIG_FILE}" <<'PY_LEGACY'
import json
import os
import pathlib
import sys
import tempfile


def atomic_json(path: pathlib.Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_name = tempfile.mkstemp(prefix=path.name + ".tmp.", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            json.dump(payload, stream, indent=2)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(tmp_name, 0o600)
        os.replace(tmp_name, path)
    finally:
        if os.path.exists(tmp_name):
            os.unlink(tmp_name)


token_path = pathlib.Path(sys.argv[1])
config_path = pathlib.Path(sys.argv[2])
api_key = os.environ["BOB_API_KEY"]

atomic_json(
    token_path,
    {
        "access_token": api_key,
        "token_type": "Bearer",
        "expires_at": 9999999999,
        "scope": "openid email profile",
    },
)
atomic_json(
    config_path,
    {
        "apiKey": api_key,
        "apiEndpoint": os.environ["BOB_ENDPOINT"],
        "authEndpoint": os.environ["BOB_AUTH_ENDPOINT"],
        "region": os.environ.get("BOB_REGION", "us-east"),
    },
)
PY_LEGACY

    if "${BOB_BIN}" --list-sessions --accept-license true >/dev/null 2>&1; then
      printf '%b\n' "${CYAN:-}Bob Shell ${BOB_VERSION} Authenticated Successfully!${RESET:-}"
      export BOBSHELL_API_KEY="${BOB_API_KEY}"
    else
      fail "Bob Shell ${BOB_VERSION} could not validate the configured 1.x credentials"
    fi
    ;;

  2|3|4|5|6|7|8|9)
    # Bob Shell 2.x+ API-key contract:
    #   - Use BOB_API_KEY directly.
    #   - Do not manufacture legacy token.json/config.json files.
    #   - Do not require or export Bob 1.x endpoint/auth/region overrides.
    : "${BOB_API_KEY:?ERROR: BOB_API_KEY is required in .env for Bob Shell 2.x}"

    # Reject malformed multiline/CRLF secrets before they reach the backend.
    case "${BOB_API_KEY}" in
      *$'\r'*|*$'\n'*) fail "BOB_API_KEY contains a carriage return or newline" ;;
    esac

    export BOB_API_KEY

    # A stale BOBSHELL_API_KEY from Bob 1.x wrappers can select the wrong secret.
    # Bob Shell 2.x officially uses BOB_API_KEY, so remove only the stale alias.
    unset BOBSHELL_API_KEY || true

    # Bob Shell 2.x does not document the 1.x endpoint/auth/region variables for
    # API-key authentication. Prevent stale 1.x values from overriding the 2.x
    # backend unless the operator explicitly opts in.
    if [[ "${BOB2_PRESERVE_LEGACY_ENDPOINT_OVERRIDES:-0}" != "1" ]]; then
      unset BOB_ENDPOINT BOB_AUTH_ENDPOINT BOB_REGION || true
    fi

    PROBE_TIMEOUT_SECONDS="${BOB_AUTH_PROBE_TIMEOUT_SECONDS:-90}"
    [[ "${PROBE_TIMEOUT_SECONDS}" =~ ^[0-9]+$ ]] || \
      fail "BOB_AUTH_PROBE_TIMEOUT_SECONDS must be an integer"

    PROBE_OUTPUT="$(mktemp "${TMPDIR:-/tmp}/bob-auth-v2.XXXXXX")"
    PROBE_ARGS=(
      run
      --mode ask
      --format json
      --max-turns 1
      --disable-mcp
      --disable-subagents
      --accept-license
    )

    # General-scope API keys require a team context; inference-scope keys do not.
    if [[ -n "${BOB_TEAM_ID:-}" ]]; then
      PROBE_ARGS+=(--team-id "${BOB_TEAM_ID}")
    fi

    if [[ "${BOB_AUTH_TRUST_WORKSPACE:-0}" == "1" ]]; then
      PROBE_ARGS+=(--trust)
    fi

    PROBE_PROMPT="${BOB_AUTH_PROBE_PROMPT:-Return exactly BOB_AUTH_OK and nothing else.}"

    set +e
    if command -v timeout >/dev/null 2>&1; then
      timeout "${PROBE_TIMEOUT_SECONDS}s" \
        "${BOB_BIN}" "${PROBE_ARGS[@]}" "${PROBE_PROMPT}" \
        >"${PROBE_OUTPUT}" 2>&1
      PROBE_STATUS=$?
    else
      "${BOB_BIN}" "${PROBE_ARGS[@]}" "${PROBE_PROMPT}" \
        >"${PROBE_OUTPUT}" 2>&1
      PROBE_STATUS=$?
    fi
    set -e

    if (( PROBE_STATUS == 0 )); then
      rm -f "${PROBE_OUTPUT}"
      printf '%b\n' "${CYAN:-}Bob Shell ${BOB_VERSION} Backend Authentication Validated Successfully!${RESET:-}"
      export BOB_AUTH_VALIDATED=1
    else
      # Print useful diagnostics while masking the active API key. The backend
      # response is retained only in the terminal and not written to the project.
      SAFE_DIAGNOSTIC="$(python3 - "${PROBE_OUTPUT}" <<'PY_MASK'
import os
import pathlib
import sys

text = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace")
for name in ("BOB_API_KEY", "BOBSHELL_API_KEY"):
    value = os.environ.get(name, "")
    if value:
        text = text.replace(value, "***REDACTED***")
print(text[-8000:], end="")
PY_MASK
)"
      rm -f "${PROBE_OUTPUT}"

      printf '%s\n' "Bob Shell ${BOB_VERSION} Authentication Failed: Bob CLI could not reach or authenticate with Bob's backend service." >&2
      if (( PROBE_STATUS == 124 )); then
        printf '%s\n' "The Bob backend probe timed out after ${PROBE_TIMEOUT_SECONDS} seconds." >&2
      fi
      if [[ -n "${SAFE_DIAGNOSTIC}" ]]; then
        printf '%s\n' "--- Bob Shell diagnostic (credentials redacted) ---" >&2
        printf '%s\n' "${SAFE_DIAGNOSTIC}" >&2
        printf '%s\n' "--- End diagnostic ---" >&2
      fi
      if [[ -z "${BOB_TEAM_ID:-}" ]]; then
        printf '%s\n' "If this is a general-scope API key, set BOB_TEAM_ID in .env. Inference-scope keys do not require it." >&2
      fi
      printf '%s\n' "Verify BOB_API_KEY, proxy/TLS trust, and Bob service availability. Bob Shell 2.x does not require the legacy BOB_ENDPOINT, BOB_AUTH_ENDPOINT, or BOB_REGION variables for its documented API-key flow." >&2
      exit "${PROBE_STATUS}"
    fi
    ;;

  *)
    fail "Unsupported Bob Shell major version: ${BOB_VERSION}"
    ;;
esac

unset BOB_VERSION_RAW BOB_VERSION_DETECTED BOB_MAJOR_VERSION

# BQCA-BOB-SHELL-V2-DNA:BEGIN
# In a trusted Bob Shell 2.x workspace, bind this component to AGENTS.md, the
# active central BQCA policy, exported menu context, current rules/skills/tools,
# and the offline knowledgebase without changing this component's core purpose.
# BQCA-BOB-SHELL-V2-DNA:END
