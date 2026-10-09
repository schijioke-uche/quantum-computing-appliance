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

# BQCA-QISKIT-EXECUTION-v39:POLICY-BEGIN
# V39 POLICY AWARENESS: Quantum/Qiskit create/implement/write/generate/build/
# develop/produce/scaffold/construct/code/program/modify/update/repair/fix/
# refactor/complete/execute requests are CODE intent. Use qiskit-v2x-env and
# Qiskit 2.5+. Open Plan uses SamplerV2(mode=backend) without Session; paid
# plans use Session with SamplerV2/EstimatorV2; simulator fallback uses
# transpile + AerSimulator. backend.run() is local-simulator-only. Hello World
# requests execute a matching artifact from project-root /test when present.
# BQCA-QISKIT-EXECUTION-v39:POLICY-END
