#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
CAPTURE="$SCRIPT_DIR/qiskit-result-output.py"
[[ -x "$CAPTURE" ]] || {
  printf 'BQCA_RESULT_OUTPUT_V42=FAIL: missing capture tool: %s\n' "$CAPTURE" >&2
  exit 2
}
exec python "$CAPTURE" "$@"
# BQCA-CANONICAL-PRODUCTION-POLICY-v43:BEGIN
# The sole active BQCA policy is .bob/BQCA-PRODUCTION-POLICY.md. Historical
# policies are audit records only. Route design, code, execution, result, and
# completion enforcement through bqca-policy-orchestrator.sh.
# BQCA-CANONICAL-PRODUCTION-POLICY-v43:END
