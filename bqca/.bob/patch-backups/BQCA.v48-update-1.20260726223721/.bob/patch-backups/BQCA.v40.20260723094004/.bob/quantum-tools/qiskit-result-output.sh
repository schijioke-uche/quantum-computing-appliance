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

# BQCA-QISKIT-EXECUTION-v39-update-1:POLICY-BEGIN
# V39 UPDATE 1: Quantum/Qiskit code intent is immediate. Qiskit checks,
# uninstalls, upgrades, and installs are permitted only inside qiskit-v2x-env.
# System/global Python, pip, and user-site Qiskit are prohibited. Qiskit 2.5+
# is required. Open Plan uses SamplerV2(mode=backend) without Session; paid
# plans use Session with SamplerV2/EstimatorV2; simulator fallback uses
# transpile + AerSimulator. backend.run() is local-simulator-only. Hello World
# artifacts are discovered under bob-quantum-store/test.
# BQCA-QISKIT-EXECUTION-v39-update-1:POLICY-END
