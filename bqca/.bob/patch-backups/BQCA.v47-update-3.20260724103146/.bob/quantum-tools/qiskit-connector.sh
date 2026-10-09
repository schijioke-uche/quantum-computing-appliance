#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# BQCA-EXECUTION-ROUTING-v47:BEGIN
DIRECT_EXECUTION_TOOL="$SCRIPT_DIR/bqca-direct-execution.sh"
FORMAL_ORCHESTRATOR="$SCRIPT_DIR/bqca-policy-orchestrator.sh"
case "${1:-}" in
  --run-code)
    shift
    (($# >= 1)) || { printf 'A Python artifact is required.\n' >&2; exit 2; }
    exec "$DIRECT_EXECUTION_TOOL" run "$@"
    ;;
  --run-notebook)
    shift
    (($# == 1)) || { printf 'One notebook artifact is required.\n' >&2; exit 2; }
    exec "$DIRECT_EXECUTION_TOOL" run-notebook "$1"
    ;;
  --run-code-formal|--run-notebook-formal)
    shift
    (($# >= 1)) || { printf 'An executable artifact is required.\n' >&2; exit 2; }
    exec "$DIRECT_EXECUTION_TOOL" formal-run "$@"
    ;;
  --validate-code)
    shift
    exec "$FORMAL_ORCHESTRATOR" validate-code "$@"
    ;;
  --validate-design)
    shift
    exec "$FORMAL_ORCHESTRATOR" validate-design "$@"
    ;;
esac
# BQCA-EXECUTION-ROUTING-v47:END
# BQCA-EXECUTION-ROUTING-v47:BEGIN
DIRECT_EXECUTION_TOOL="$SCRIPT_DIR/bqca-direct-execution.sh"
FORMAL_ORCHESTRATOR="$SCRIPT_DIR/bqca-policy-orchestrator.sh"
case "${1:-}" in
  --run-code)
    shift
    (($# >= 1)) || { printf 'A Python artifact is required.\n' >&2; exit 2; }
    exec "$DIRECT_EXECUTION_TOOL" run "$@"
    ;;
  --run-notebook)
    shift
    (($# == 1)) || { printf 'One notebook artifact is required.\n' >&2; exit 2; }
    exec "$DIRECT_EXECUTION_TOOL" run-notebook "$1"
    ;;
  --run-code-formal|--run-notebook-formal)
    shift
    (($# >= 1)) || { printf 'An executable artifact is required.\n' >&2; exit 2; }
    exec "$DIRECT_EXECUTION_TOOL" formal-run "$@"
    ;;
  --validate-code)
    shift
    exec "$FORMAL_ORCHESTRATOR" validate-code "$@"
    ;;
  --validate-design)
    shift
    exec "$FORMAL_ORCHESTRATOR" validate-design "$@"
    ;;
esac
# BQCA-EXECUTION-ROUTING-v47:END




CONFIG_TOOL="$SCRIPT_DIR/qiskit-configuration.sh"
ENV_TOOL="$SCRIPT_DIR/qiskit-v2x-environment.sh"
CODE_VALIDATOR="$SCRIPT_DIR/qiskit-code-policy-check.py"
# BQCA-QISKIT-HOME-ENV-v40:VALIDATOR-BEGIN
HOME_ENV_VALIDATOR="$SCRIPT_DIR/qiskit-home-env-policy-check.py"
# BQCA-QISKIT-HOME-ENV-v40:VALIDATOR-END
DESIGN_VALIDATOR="$SCRIPT_DIR/qiskit-design-policy-check.py"
# BQCA-HELLO-WORLD-SCOPE-v41:VALIDATOR-BEGIN
HELLO_SCOPE_VALIDATOR="$SCRIPT_DIR/qiskit-hello-world-scope-check.py"
# BQCA-HELLO-WORLD-SCOPE-v41:VALIDATOR-END
# BQCA-RESULT-OUTPUT-v42:VALIDATOR-BEGIN
RESULT_POLICY_VALIDATOR="$SCRIPT_DIR/qiskit-result-output-policy-check.py"
# BQCA-RESULT-OUTPUT-v42:VALIDATOR-END
CODE_TEMPLATE="$SCRIPT_DIR/qiskit-connector-required-template.py"
DESIGN_TEMPLATE="$SCRIPT_DIR/qiskit-connector-design-required-template.md"

usage() {
  cat <<'USAGE'
Usage:
  qiskit-connector.sh --check
  qiskit-connector.sh --install
  qiskit-connector.sh --prepare-runtime
  qiskit-connector.sh --show-python-template
  qiskit-connector.sh --show-design-template
  qiskit-connector.sh --validate-code <file.py> [more.py ...]
  qiskit-connector.sh --validate-design <file.md> [more.md ...]
  qiskit-connector.sh --validate-store [directory]
  qiskit-connector.sh --validate-design-store [directory]
  qiskit-connector.sh --run-code <file.py> [arguments...]
  qiskit-connector.sh --run-notebook <file.ipynb>
  qiskit-connector.sh --run-code-formal <file.py> [arguments...]
  qiskit-connector.sh --run-notebook-formal <file.ipynb>
  qiskit-connector.sh --run-code-formal <file.py> [arguments...]
  qiskit-connector.sh --run-notebook-formal <file.ipynb>
  qiskit-connector.sh --hello-world
USAGE
}

prepare_runtime() {
  [[ -x "$CONFIG_TOOL" ]] || { printf 'BQCA_QISKIT_CONFIGURATION=FAIL: missing %s\n' "$CONFIG_TOOL" >&2; exit 2; }
  [[ -x "$ENV_TOOL" ]] || { printf 'BQCA_QISKIT_V39=FAIL: missing %s\n' "$ENV_TOOL" >&2; exit 2; }
  "$CONFIG_TOOL" configure --quiet
  "$ENV_TOOL" ensure --quiet
}

case "${1:-}" in
  --check)
    prepare_runtime
    "$ENV_TOOL" python - <<'PY'
from importlib.metadata import version
mods = ["qiskit", "qiskit_aer", "qiskit_ibm_runtime", "qiskit_connector"]
for mod in mods:
    try:
        __import__(mod)
        print(f"{mod}=AVAILABLE")
    except Exception as exc:
        print(f"{mod}=UNAVAILABLE ({exc})")
print(f"qiskit_version={version('qiskit')}")
PY
    ;;
  --install|--prepare-runtime)
    prepare_runtime
    ;;
  --show-python-template)
    cat "$CODE_TEMPLATE"
    ;;
  --show-design-template)
    cat "$DESIGN_TEMPLATE"
    ;;
  --validate-code)
    shift
    (($#)) || { usage >&2; exit 2; }
    "$ENV_TOOL" ensure --quiet
    "$ENV_TOOL" python "$CODE_VALIDATOR" "$@"
    "$ENV_TOOL" python "$HOME_ENV_VALIDATOR" "$@"
    "$ENV_TOOL" python "$HELLO_SCOPE_VALIDATOR" --kind code "$@"
    "$ENV_TOOL" python "$RESULT_POLICY_VALIDATOR" --kind code "$@"
    ;;
  --validate-design)
    shift
    (($#)) || { usage >&2; exit 2; }
    python3 "$DESIGN_VALIDATOR" "$@"
    python3 "$HELLO_SCOPE_VALIDATOR" --kind design "$@"
    python3 "$RESULT_POLICY_VALIDATOR" --kind design "$@"
    ;;
  --validate-store)
    root="${2:-bob-quantum-store}"
    mapfile -d '' files < <(find "$root" -type f -name '*.py' -print0)
    ((${#files[@]})) || { echo "No Python files found under $root"; exit 0; }
    "$ENV_TOOL" ensure --quiet
    "$ENV_TOOL" python "$CODE_VALIDATOR" "${files[@]}"
    "$ENV_TOOL" python "$HELLO_SCOPE_VALIDATOR" --kind code "${files[@]}"
    "$ENV_TOOL" python "$RESULT_POLICY_VALIDATOR" --kind code "${files[@]}"
    ;;
  --validate-design-store)
    root="${2:-bob-quantum-designs}"
    mapfile -d '' files < <(find "$root" -type f \( -name '*.md' -o -name '*.txt' \) -print0)
    ((${#files[@]})) || { echo "No design files found under $root"; exit 0; }
    python3 "$DESIGN_VALIDATOR" "${files[@]}"
    python3 "$HELLO_SCOPE_VALIDATOR" --kind design "${files[@]}"
    python3 "$RESULT_POLICY_VALIDATOR" --kind design "${files[@]}"
    ;;
  --run-code)
    shift
    (($# >= 1)) || { usage >&2; exit 2; }
    "$ENV_TOOL" run "$@"
    ;;
  --run-notebook)
    shift
    (($# == 1)) || { usage >&2; exit 2; }
    "$ENV_TOOL" run-notebook "$1"
    ;;
  --hello-world)
    "$ENV_TOOL" hello-world
    ;;
  -h|--help|"")
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
# BQCA-CANONICAL-PRODUCTION-POLICY-v47:BEGIN
# The sole active BQCA policy is .bob/BQCA-PRODUCTION-POLICY.md (v47).
# Direct execution with live terminal output and dual result capture is the
# default. The orchestrator is optional and reserved for formal compliance,
# production-deployment evidence, and audit validation. Historical policies
# are audit-only and must not drive runtime decisions.
# BQCA-CANONICAL-PRODUCTION-POLICY-v47:END
