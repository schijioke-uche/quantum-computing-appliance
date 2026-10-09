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

# BQCA-QISKIT-HOME-ENV-v40:POLICY-BEGIN
# V40: Use only $HOME/qiskit-v2x-env, created with python3 -m venv
# "$HOME/qiskit-v2x-env" and activated with source
# "$HOME/qiskit-v2x-env/bin/activate". Never create or use a project-local
# qiskit-v2x-env. All Qiskit checks and package operations occur after home
# environment activation. Existing v39 plan and Qiskit 2.5+ rules remain active.
# BQCA-QISKIT-HOME-ENV-v40:POLICY-END
