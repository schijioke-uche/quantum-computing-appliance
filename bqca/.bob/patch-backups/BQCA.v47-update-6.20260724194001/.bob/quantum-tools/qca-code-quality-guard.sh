#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# BQCA-EXECUTION-ROUTING-v47:BEGIN
DIRECT_EXECUTION_TOOL="$SCRIPT_DIR/bqca-direct-execution.sh"
case "${1:-}" in
  --execute)
    shift
    (($# >= 1)) || { printf 'A Python artifact is required.\n' >&2; exit 2; }
    exec "$DIRECT_EXECUTION_TOOL" run "$@"
    ;;
  --formal-execute)
    shift
    (($# >= 1)) || { printf 'An executable artifact is required.\n' >&2; exit 2; }
    exec "$DIRECT_EXECUTION_TOOL" formal-run "$@"
    ;;
esac
# BQCA-EXECUTION-ROUTING-v47:END




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
  qca-code-quality-guard.sh --formal-execute <file.py> [arguments...]

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

# BQCA-CANONICAL-PRODUCTION-POLICY-v47:BEGIN
# BQCA v47 Update 4: follow .bob/BQCA-PRODUCTION-POLICY.md. Direct execution
# through bqca-direct-execution.sh is the default and must use the authorized
# home Python with unbuffered live stdout/stderr plus dual result capture.
# Code must preserve real-QPU-first plan-aware execution, controlled simulator
# fallback, and the required BQCA markers, including BQCA_RESULT=SUCCESS or
# BQCA_RESULT=FAILURE. The orchestrator is explicit opt-in only for formal
# compliance, deployment, or audit evidence. Direct-mode policy gaps are
# warnings that preserve the workload exit status; credential leakage blocks.
# This block supersedes conflicting local execution guidance.
# BQCA-CANONICAL-PRODUCTION-POLICY-v47:END

# BQCA-QUANTUM-KNOWLEDGEBASE-v47-update-5:BEGIN
# For every quantum DESIGN or CODE intent, consult the canonical index at
# .bob/quantum-tools/knowlegebase/bqca_quantum_kb_index.txt through
# .bob/quantum-tools/bqca-quantum-kb.sh. Access relevant seed URLs and drill
# into at least one relevant sublink from every seed accessed. Preserve a
# <artifact-stem>-kb-research.md trace beside the governed artifact. The
# knowledgebase supplements IBM Bob intelligence and never overrides the active
# central policy. Do not claim compliance when the strict research gate fails.
# This block supersedes conflicting local quantum-knowledge-source guidance.
# BQCA-QUANTUM-KNOWLEDGEBASE-v47-update-5:END
