#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# BQCA-RESULT-CAPTURE-GATE-v45:BEGIN
if [[ "${BQCA_V45_INTERNAL:-0}" != "1" && "${BQCA_V45_ORCHESTRATED:-0}" != "1" ]]; then
  printf 'Direct result-capture invocation is prohibited; use bqca-policy-orchestrator.sh execute.\n' >&2
  exit 2
fi
# BQCA-RESULT-CAPTURE-GATE-v45:END

CAPTURE="$SCRIPT_DIR/qiskit-result-output.py"
[[ -x "$CAPTURE" ]] || {
  printf 'BQCA_RESULT_OUTPUT_V42=FAIL: missing capture tool: %s\n' "$CAPTURE" >&2
  exit 2
}
exec python "$CAPTURE" "$@"
# BQCA-CANONICAL-PRODUCTION-POLICY-v45:BEGIN
# The sole active BQCA policy is .bob/BQCA-PRODUCTION-POLICY.md (v45).
# Route all public design, code, execution, result, and completion paths through
# bqca-policy-orchestrator.sh. Open Plan uses SamplerV2 or EstimatorV2 job mode
# according to workload semantics and must never use Session.
# BQCA-CANONICAL-PRODUCTION-POLICY-v45:END
