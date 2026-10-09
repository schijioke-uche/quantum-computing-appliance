#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# BQCA-ACTIVE-POLICY-QUALITY-GATE:BEGIN
ACTIVE_POLICY_LISTENER="$SCRIPT_DIR/bqca-active-policy-listener.sh"
ACTIVE_CODE_VALIDATOR="$SCRIPT_DIR/qiskit-code-policy-check.py"
# BQCA-ACTIVE-POLICY-QUALITY-GATE:END

# BQCA-EXECUTION-ROUTING-v48:BEGIN
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
# BQCA-EXECUTION-ROUTING-v48:END




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
  [[ -f "$file" ]] || { printf '[BQCA] File not found: %s
' "$file" >&2; return 1; }
  "$ACTIVE_POLICY_LISTENER" sync --quiet
  python3 "$ACTIVE_CODE_VALIDATOR" "$file"
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

# BQCA-ACTIVE-CENTRAL-POLICY:BEGIN
# Resolve the active authority through bqca-active-policy-listener.sh before
# every quantum DESIGN or CODE decision. Never hardcode a policy version or
# duplicate the full policy here. qiskit-design-policy-check.py and
# qiskit-code-policy-check.py reload the active registry/policy/contract on
# every invocation and create same-directory policy-compliance reports.
# Do not report completion until the active-policy report exists.
# BQCA-ACTIVE-CENTRAL-POLICY:END

# BQCA-BOB-SHELL-V2-DNA:BEGIN
# In a trusted Bob Shell 2.x workspace, bind this component to AGENTS.md, the
# active central BQCA policy, exported menu context, current rules/skills/tools,
# and the offline knowledgebase without changing this component's core purpose.
# BQCA-BOB-SHELL-V2-DNA:END
# BQCA-TRUSTED-CHAT-AUTO-APPROVAL-v51.4:BEGIN
# Trusted BQCA chat sessions auto-approve routine project-scoped tool calls at
# session launch. This does not authorize secrets, destructive operations, Bob
# home/settings writes, external paths, or bypass of BQCA policy/safety gates.
# BQCA-TRUSTED-CHAT-AUTO-APPROVAL-v51.4:END
