#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIGURATOR="$SCRIPT_DIR/qiskit-configuration.py"
[[ -x "$CONFIGURATOR" ]] || {
  printf 'BQCA_QISKIT_CONFIGURATION=FAIL: missing configurator: %s\n' "$CONFIGURATOR" >&2
  exit 2
}
exec python3 "$CONFIGURATOR" "$@"
# BQCA-CANONICAL-PRODUCTION-POLICY-v43:BEGIN
# The sole active BQCA policy is .bob/BQCA-PRODUCTION-POLICY.md. Historical
# policies are audit records only. Route design, code, execution, result, and
# completion enforcement through bqca-policy-orchestrator.sh.
# BQCA-CANONICAL-PRODUCTION-POLICY-v43:END
