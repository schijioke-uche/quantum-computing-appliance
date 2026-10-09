#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
CAPTURE="$SCRIPT_DIR/qiskit-result-output.py"
[[ -x "$CAPTURE" ]] || {
  printf 'BQCA_RESULT_OUTPUT_V42=FAIL: missing capture tool: %s\n' "$CAPTURE" >&2
  exit 2
}
exec python "$CAPTURE" "$@"

# BQCA-RESULT-OUTPUT-v42:POLICY-BEGIN
# V42: execute quantum/Qiskit sources through qiskit-v2x-environment.sh run or
# run-notebook. The runtime creates <source-stem>-result-output.txt beside the
# source, captures complete Qiskit Connector/stdout/stderr output, includes
# date/time, places a real-QPU JOB ID on the first line, and appends a final
# RESULT SUMMARY with execution success. Code emits canonical BQCA markers.
# BQCA-RESULT-OUTPUT-v42:POLICY-END

# BQCA-QISKIT-HOME-ENV-v40:POLICY-BEGIN
# V40: Use only $HOME/qiskit-v2x-env, created with python3 -m venv
# "$HOME/qiskit-v2x-env" and activated with source
# "$HOME/qiskit-v2x-env/bin/activate". Never create or use a project-local
# qiskit-v2x-env. All Qiskit checks and package operations occur after home
# environment activation. Existing v39 plan and Qiskit 2.5+ rules remain active.
# BQCA-QISKIT-HOME-ENV-v40:POLICY-END
