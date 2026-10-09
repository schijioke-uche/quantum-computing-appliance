#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BQCA_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENV_TOOL="$SCRIPT_DIR/qiskit-v2x-environment.sh"
CODE_VALIDATOR="$SCRIPT_DIR/qiskit-code-policy-check.py"
NOTEBOOK_GENERATOR="$SCRIPT_DIR/notebook-generator.sh"
LOG_FILE="${BQCA_CODE_QUALITY_LOG:-$BQCA_ROOT/.bob/qca-code-quality.log}"

mkdir -p "$(dirname "$LOG_FILE")"

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')" "$*" >> "$LOG_FILE" 2>/dev/null || true
}

usage() {
  cat <<'USAGE'
BQCA Code Quality Guard v39

Usage:
  qca-code-quality-guard.sh --ensure-venv
  qca-code-quality-guard.sh --validate <file.py>
  qca-code-quality-guard.sh --imports <file.py>
  qca-code-quality-guard.sh --notebook <file.py> [file.ipynb]
  qca-code-quality-guard.sh --prepare <file.py>
  qca-code-quality-guard.sh --execute <file.py> [arguments...]

All validation and execution uses qiskit-v2x-env with Qiskit 2.5+.
USAGE
}

list_imports() {
  local file="$1"
  python3 - "$file" <<'PY'
from pathlib import Path
import ast, sys
path = Path(sys.argv[1])
tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
mods = set()
for node in ast.walk(tree):
    if isinstance(node, ast.Import):
        mods.update(alias.name.split(".")[0] for alias in node.names)
    elif isinstance(node, ast.ImportFrom) and node.module:
        mods.add(node.module.split(".")[0])
for name in sorted(mods):
    print(name)
PY
}

validate_file() {
  local file="$1"
  [[ -f "$file" ]] || { printf '[BQCA] File not found: %s\n' "$file" >&2; return 1; }
  "$ENV_TOOL" ensure --quiet
  "$ENV_TOOL" python -m py_compile "$file" >>"$LOG_FILE" 2>&1
  "$ENV_TOOL" python "$CODE_VALIDATOR" "$file"
}

make_notebook() {
  local source="$1" output="${2:-${source%.py}.ipynb}"
  [[ -x "$NOTEBOOK_GENERATOR" ]] || { printf '[BQCA] Notebook generator unavailable: %s\n' "$NOTEBOOK_GENERATOR" >&2; return 1; }
  "$NOTEBOOK_GENERATOR" --source "$source" --output "$output" --force
  "$NOTEBOOK_GENERATOR" --validate "$output" --against-source "$source"
}

prepare_file() {
  local file="$1"
  validate_file "$file"
  make_notebook "$file" "${file%.py}.ipynb"
  log "Prepared v39 Qiskit implementation: $file"
}

execute_file() {
  local file="$1"
  shift
  prepare_file "$file"
  "$ENV_TOOL" run "$file" "$@"
}

(($# >= 1)) || { usage; exit 2; }
case "$1" in
  --ensure-venv)
    "$ENV_TOOL" ensure
    ;;
  --validate)
    (($# == 2)) || { usage; exit 2; }
    validate_file "$2"
    ;;
  --imports)
    (($# == 2)) || { usage; exit 2; }
    list_imports "$2"
    ;;
  --notebook)
    (($# == 2 || $# == 3)) || { usage; exit 2; }
    make_notebook "$2" "${3:-${2%.py}.ipynb}"
    ;;
  --prepare)
    (($# == 2)) || { usage; exit 2; }
    prepare_file "$2"
    ;;
  --execute)
    (($# >= 2)) || { usage; exit 2; }
    shift
    execute_file "$@"
    ;;
  -h|--help)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

# BQCA-QISKIT-EXECUTION-v39-update-1:POLICY-BEGIN
# V39 UPDATE 1: Quantum/Qiskit code intent is immediate. Qiskit checks,
# uninstalls, upgrades, and installs are permitted only inside qiskit-v2x-env.
# System/global Python, pip, and user-site Qiskit are prohibited. Qiskit 2.5+
# is required. Open Plan uses SamplerV2(mode=backend) without Session; paid
# plans use Session with SamplerV2/EstimatorV2; simulator fallback uses
# transpile + AerSimulator. backend.run() is local-simulator-only. Hello World
# artifacts are discovered under bob-quantum-store/test.
# BQCA-QISKIT-EXECUTION-v39-update-1:POLICY-END
