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
