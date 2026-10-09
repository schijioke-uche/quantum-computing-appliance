#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GENERATOR="$SCRIPT_DIR/notebook-generator.py"
[[ -x "$GENERATOR" ]] || { printf 'BQCA_NOTEBOOK_GENERATION=FAIL: missing generator: %s\n' "$GENERATOR" >&2; exit 2; }
exec python3 "$GENERATOR" "$@"

# BQCA-QISKIT-CONFIGURATION-v38:POLICY-BEGIN
# V38 POLICY AWARENESS: Quantum/Qiskit code-producing requests include create,
# implement, write, generate, build, develop, produce, scaffold, construct,
# code, program, modify, update, repair, fix, refactor, complete, and execute.
# Before qiskit_connector behavior, run qiskit-configuration.sh configure
# --quiet and require success. The generated qiskit-ibm.json must contain only
# the default bqca profile. Never print IQP_API_TOKEN.
# BQCA-QISKIT-CONFIGURATION-v38:POLICY-END

# BQCA-HELLO-WORLD-SCOPE-v41:POLICY-BEGIN
# V41: Hello World is request-scoped, not a universal design/code test. Do not
# add, mention, execute, validate, or require Hello World content in unrelated
# designs or code. Only an explicit Hello World request may use the existing
# bob-quantum-store/test shortcut, and the artifact must be named/titled as
# Hello World. Preserve all v38-v40 Qiskit configuration and execution rules.
# BQCA-HELLO-WORLD-SCOPE-v41:POLICY-END

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
