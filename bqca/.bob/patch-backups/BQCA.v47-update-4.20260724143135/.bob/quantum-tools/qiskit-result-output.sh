#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
CAPTURE="$SCRIPT_DIR/qiskit-result-output.py"
[[ -x "$CAPTURE" ]] || {
  printf 'BQCA_RESULT_OUTPUT_V46=FAIL: missing capture tool: %s\n' "$CAPTURE" >&2
  exit 2
}
exec env PYTHONUNBUFFERED=1 python3 -u "$CAPTURE" "$@"
# BQCA-CANONICAL-PRODUCTION-POLICY-v47:BEGIN
# The sole active policy is .bob/BQCA-PRODUCTION-POLICY.md (v47).
# Direct execution streams complete stdout/stderr live and writes the exact
# professional report to <source-stem>-result-output.txt and output.txt.
# REAL_QPU results put the actual Job ID on line one. Direct contract gaps
# are warnings; formal orchestration is explicit opt-in.
# BQCA-CANONICAL-PRODUCTION-POLICY-v47:END
