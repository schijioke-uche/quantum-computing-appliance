#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# BQCA-QISKIT-CONFIGURATION-v38:BEGIN
# qiskit_connector depends on ~/.qiskit/qiskit-ibm.json. Rebuild the single
# default bqca profile before every connector tool operation.
QISKIT_CONFIGURATION_TOOL="$SCRIPT_DIR/qiskit-configuration.sh"
if [[ ! -x "$QISKIT_CONFIGURATION_TOOL" ]]; then
  printf 'BQCA_QISKIT_CONFIGURATION=FAIL: missing tool: %s\n' "$QISKIT_CONFIGURATION_TOOL" >&2
  exit 2
fi
"$QISKIT_CONFIGURATION_TOOL" configure --quiet
# BQCA-QISKIT-CONFIGURATION-v38:END

CODE_VALIDATOR="$SCRIPT_DIR/qiskit-code-policy-check.py"
DESIGN_VALIDATOR="$SCRIPT_DIR/qiskit-design-policy-check.py"
CODE_TEMPLATE="$SCRIPT_DIR/qiskit-connector-required-template.py"
DESIGN_TEMPLATE="$SCRIPT_DIR/qiskit-connector-design-required-template.md"

usage() {
  cat <<'USAGE'
Usage:
  qiskit-connector.sh --check
  qiskit-connector.sh --install
  qiskit-connector.sh --show-python-template
  qiskit-connector.sh --show-design-template
  qiskit-connector.sh --validate-code <file.py> [more.py ...]
  qiskit-connector.sh --validate-design <file.md> [more.md ...]
  qiskit-connector.sh --validate-store [directory]
  qiskit-connector.sh --validate-design-store [directory]
USAGE
}

case "${1:-}" in
  --check)
    python3 - <<'PY'
mods = ["qiskit", "qiskit_connector"]
for mod in mods:
    try:
        __import__(mod)
        print(f"{mod}=AVAILABLE")
    except Exception as exc:
        print(f"{mod}=UNAVAILABLE ({exc})")
PY
    ;;
  --install)
    python3 -m pip install qiskit-connector
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
    python3 "$CODE_VALIDATOR" "$@"
    ;;
  --validate-design)
    shift
    (($#)) || { usage >&2; exit 2; }
    python3 "$DESIGN_VALIDATOR" "$@"
    ;;
  --validate-store)
    root="${2:-bob-quantum-store}"
    mapfile -d '' files < <(find "$root" -type f -name '*.py' -print0)
    ((${#files[@]})) || { echo "No Python files found under $root"; exit 0; }
    python3 "$CODE_VALIDATOR" "${files[@]}"
    ;;
  --validate-design-store)
    root="${2:-bob-quantum-designs}"
    mapfile -d '' files < <(find "$root" -type f \( -name '*.md' -o -name '*.txt' \) -print0)
    ((${#files[@]})) || { echo "No design files found under $root"; exit 0; }
    python3 "$DESIGN_VALIDATOR" "${files[@]}"
    ;;
  -h|--help|"")
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

# BQCA-QISKIT-CONFIGURATION-v38:POLICY-BEGIN
# V38 POLICY AWARENESS: Quantum/Qiskit code-producing requests include create,
# implement, write, generate, build, develop, produce, scaffold, construct,
# code, program, modify, update, repair, fix, refactor, complete, and execute.
# Before qiskit_connector behavior, run qiskit-configuration.sh configure
# --quiet and require success. The generated qiskit-ibm.json must contain only
# the default bqca profile. Never print IQP_API_TOKEN.
# BQCA-QISKIT-CONFIGURATION-v38:POLICY-END
