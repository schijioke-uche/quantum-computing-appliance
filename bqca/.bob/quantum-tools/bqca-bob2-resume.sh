#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PY_TOOL="${SCRIPT_DIR}/bqca-bob2-resume.py"
[[ -x "${PY_TOOL}" ]] || {
  printf 'BQCA_RESUME=FAIL: missing resume resolver: %s\n' "${PY_TOOL}" >&2
  exit 2
}
exec python3 "${PY_TOOL}" "$@"

# BQCA-ACTIVE-CENTRAL-POLICY:BEGIN
# Use the active central policy for every BQCA resume decision.
# BQCA-ACTIVE-CENTRAL-POLICY:END
# BQCA-BOB-SHELL-V2-DNA:BEGIN
# Resume the latest real user task under quantum-qiskit-connector mode.
# BQCA-BOB-SHELL-V2-DNA:END
# BQCA-TRUSTED-CHAT-AUTO-APPROVAL-v51.4:BEGIN
# Trusted BQCA chat sessions auto-approve routine project-scoped tool calls at
# session launch. This does not authorize secrets, destructive operations, Bob
# home/settings writes, external paths, or bypass of BQCA policy/safety gates.
# BQCA-TRUSTED-CHAT-AUTO-APPROVAL-v51.4:END
