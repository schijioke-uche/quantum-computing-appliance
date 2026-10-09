#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# BQCA-CANONICAL-ORCHESTRATOR-v43:BEGIN
V43_ORCHESTRATOR="$SCRIPT_DIR/bqca-policy-orchestrator.sh"
if [[ "${BQCA_V43_INTERNAL:-0}" != "1" && -x "$V43_ORCHESTRATOR" ]]; then
  case "${1:-}" in
    --validate|--prepare)
      (($# == 2)) || { printf 'v43 requires one Python file\n' >&2; exit 2; }
      exec "$V43_ORCHESTRATOR" validate-code "$2"
      ;;
    --execute)
      (($# >= 2)) || { printf 'v43 requires a Python file\n' >&2; exit 2; }
      shift
      exec "$V43_ORCHESTRATOR" execute "$@"
      ;;
  esac
fi
# BQCA-CANONICAL-ORCHESTRATOR-v43:END

BQCA_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENV_TOOL="$SCRIPT_DIR/qiskit-v2x-environment.sh"
CODE_VALIDATOR="$SCRIPT_DIR/qiskit-code-policy-check.py"
# BQCA-QISKIT-HOME-ENV-v40:VALIDATOR-BEGIN
HOME_ENV_VALIDATOR="$SCRIPT_DIR/qiskit-home-env-policy-check.py"
# BQCA-HELLO-WORLD-SCOPE-v41:VALIDATOR-BEGIN
HELLO_SCOPE_VALIDATOR="$SCRIPT_DIR/qiskit-hello-world-scope-check.py"
# BQCA-HELLO-WORLD-SCOPE-v41:VALIDATOR-END
# BQCA-RESULT-OUTPUT-v42:VALIDATOR-BEGIN
RESULT_POLICY_VALIDATOR="$SCRIPT_DIR/qiskit-result-output-policy-check.py"
# BQCA-RESULT-OUTPUT-v42:VALIDATOR-END
# BQCA-QISKIT-HOME-ENV-v40:VALIDATOR-END
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

All validation and execution uses $HOME/qiskit-v2x-env with Qiskit 2.5+.
Execution also creates <source-stem>-result-output.txt beside the source.
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
  "$ENV_TOOL" python "$HOME_ENV_VALIDATOR" "$file"
  "$ENV_TOOL" python "$HELLO_SCOPE_VALIDATOR" --kind code "$file"
  "$ENV_TOOL" python "$RESULT_POLICY_VALIDATOR" --kind code "$file"
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
# BQCA-CANONICAL-PRODUCTION-POLICY-v43:BEGIN
# The sole active BQCA policy is .bob/BQCA-PRODUCTION-POLICY.md. Historical
# policies are audit records only. Route design, code, execution, result, and
# completion enforcement through bqca-policy-orchestrator.sh.
# BQCA-CANONICAL-PRODUCTION-POLICY-v43:END
