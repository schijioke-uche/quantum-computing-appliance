#!/usr/bin/env bash
set -Eeuo pipefail

# BQCA Code Quality Guard v30
# Local-only validation, notebook generation, dependency inspection, and execution.
# No remote installer is downloaded or piped to a shell.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BQCA_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LOG_FILE="${BQCA_CODE_QUALITY_LOG:-$BQCA_ROOT/.bob/qca-code-quality.log}"
VENV_PATH="${QISKIT_VENV_PATH:-$HOME/qiskit-v2x-env}"
ALLOW_INSTALL="${BQCA_ALLOW_DEPENDENCY_INSTALL:-0}"

mkdir -p "$(dirname "$LOG_FILE")"

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')" "$*" >> "$LOG_FILE" 2>/dev/null || true
}

usage() {
  cat <<'USAGE'
BQCA Code Quality Guard v30

Usage:
  qca-code-quality-guard.sh --ensure-venv
  qca-code-quality-guard.sh --validate <file.py>
  qca-code-quality-guard.sh --imports <file.py>
  qca-code-quality-guard.sh --notebook <file.py> [file.ipynb]
  qca-code-quality-guard.sh --prepare <file.py>
  qca-code-quality-guard.sh --execute <file.py>

Dependency installation is disabled by default. To explicitly allow local pip
installation, set BQCA_ALLOW_DEPENDENCY_INSTALL=1 before --prepare or --execute.
No remote bootstrap installer is used.
USAGE
}

resolve_python() {
  if [[ -x "$VENV_PATH/bin/python" ]]; then
    printf '%s\n' "$VENV_PATH/bin/python"
    return 0
  fi
  command -v python3 >/dev/null 2>&1 || return 1
  command -v python3
}

ensure_venv() {
  if [[ -x "$VENV_PATH/bin/python" ]]; then
    return 0
  fi
  [[ "$ALLOW_INSTALL" == "1" ]] || {
    printf '[BQCA] Python environment not found: %s\n' "$VENV_PATH" >&2
    printf '[BQCA] Create it explicitly or set BQCA_ALLOW_DEPENDENCY_INSTALL=1.\n' >&2
    return 1
  }
  command -v python3 >/dev/null 2>&1 || return 1
  log "Creating operator-approved virtual environment: $VENV_PATH"
  python3 -m venv "$VENV_PATH" >>"$LOG_FILE" 2>&1
}

validate_file() {
  local file="$1" python_bin
  [[ -f "$file" ]] || { printf '[BQCA] File not found: %s\n' "$file" >&2; return 1; }
  python_bin="$(resolve_python)" || { printf '[BQCA] python3 is unavailable\n' >&2; return 1; }
  "$python_bin" -m py_compile "$file" >>"$LOG_FILE" 2>&1
}

list_imports() {
  local file="$1"
  python3 - "$file" <<'PY'
from pathlib import Path
import ast, sys
path = Path(sys.argv[1])
tree = ast.parse(path.read_text(encoding='utf-8'), filename=str(path))
mods = set()
for node in ast.walk(tree):
    if isinstance(node, ast.Import):
        mods.update(alias.name.split('.')[0] for alias in node.names)
    elif isinstance(node, ast.ImportFrom) and node.module:
        mods.add(node.module.split('.')[0])
for name in sorted(mods):
    print(name)
PY
}

missing_imports() {
  local file="$1" python_bin
  python_bin="$(resolve_python)" || return 1
  while IFS= read -r module; do
    [[ -n "$module" ]] || continue
    if ! "$python_bin" - "$module" >/dev/null 2>&1 <<'PY'
import importlib.util, sys
raise SystemExit(0 if importlib.util.find_spec(sys.argv[1]) else 1)
PY
    then
      printf '%s\n' "$module"
    fi
  done < <(list_imports "$file")
}

package_for_module() {
  case "$1" in
    qiskit_aer) printf '%s\n' qiskit-aer ;;
    qiskit_algorithms) printf '%s\n' qiskit-algorithms ;;
    qiskit_connector) printf '%s\n' qiskit-connector ;;
    sklearn) printf '%s\n' scikit-learn ;;
    PIL) printf '%s\n' pillow ;;
    yaml) printf '%s\n' pyyaml ;;
    *) printf '%s\n' "$1" ;;
  esac
}

ensure_imports() {
  local file="$1" module package python_bin failures=0
  python_bin="$(resolve_python)" || return 1
  while IFS= read -r module; do
    [[ -n "$module" ]] || continue
    if [[ "$ALLOW_INSTALL" != "1" ]]; then
      printf '[BQCA] Missing Python module: %s\n' "$module" >&2
      failures=$((failures + 1))
      continue
    fi
    package="$(package_for_module "$module")"
    printf '[BQCA] Installing operator-approved dependency: %s\n' "$package"
    "$python_bin" -m pip install "$package" >>"$LOG_FILE" 2>&1 || failures=$((failures + 1))
  done < <(missing_imports "$file")
  ((failures == 0))
}

make_notebook() {
  local source="$1" output="${2:-${source%.py}.ipynb}"
  [[ -f "$source" ]] || return 1
  python3 - "$source" "$output" <<'PY'
from pathlib import Path
import json, sys
source = Path(sys.argv[1])
output = Path(sys.argv[2])
text = source.read_text(encoding='utf-8')
notebook = {
    "cells": [{"cell_type": "code", "execution_count": None, "metadata": {},
               "outputs": [], "source": text.splitlines(keepends=True)}],
    "metadata": {"kernelspec": {"display_name": "Python 3", "language": "python", "name": "python3"},
                 "language_info": {"name": "python", "version": "3"}},
    "nbformat": 4,
    "nbformat_minor": 5,
}
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(json.dumps(notebook, indent=2) + "\n", encoding='utf-8')
PY
  printf '%s\n' "$output"
}

prepare_file() {
  local file="$1"
  validate_file "$file"
  ensure_imports "$file"
}

execute_file() {
  local file="$1" python_bin
  prepare_file "$file"
  python_bin="$(resolve_python)"
  "$python_bin" "$file" 2>>"$LOG_FILE"
}

(($# >= 1)) || { usage; exit 2; }
case "$1" in
  --ensure-venv)
    ensure_venv
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
    (($# == 2)) || { usage; exit 2; }
    execute_file "$2"
    ;;
  -h|--help)
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
