#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIGURATOR="$SCRIPT_DIR/qiskit-configuration.py"
[[ -x "$CONFIGURATOR" ]] || {
  printf 'BQCA_QISKIT_CONFIGURATION=FAIL: missing configurator: %s\n' "$CONFIGURATOR" >&2
  exit 2
}
exec python3 "$CONFIGURATOR" "$@"
# BQCA-CANONICAL-PRODUCTION-POLICY-v47:BEGIN
# The sole active BQCA policy is .bob/BQCA-PRODUCTION-POLICY.md (v47).
# Direct execution with live terminal output and dual result capture is the
# default. The orchestrator is optional and reserved for formal compliance,
# production-deployment evidence, and audit validation. Historical policies
# are audit-only and must not drive runtime decisions.
# BQCA-CANONICAL-PRODUCTION-POLICY-v47:END
