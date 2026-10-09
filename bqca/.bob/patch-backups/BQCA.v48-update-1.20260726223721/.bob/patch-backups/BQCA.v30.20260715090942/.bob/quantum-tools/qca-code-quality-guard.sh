#!/usr/bin/env bash
set -Eeuo pipefail

#===============================================================================
# QCA Code Quality Guard
# Purpose: Validate generated quantum Python code, create companion notebooks,
#          ensure Qiskit/Python environment readiness, install missing imports,
#          and execute code with diagnostic logging.
#===============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QCA_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LOG_FILE="${QCA_CODE_QUALITY_LOG:-$QCA_ROOT/.bob/qca-code-quality.log}"
VENV_PATH="${QISKIT_VENV_PATH:-$HOME/qiskit-v2x-env}"
PYTHON_VERSION="${QCA_PYTHON_VERSION:-3.12}"

mkdir -p "$(dirname "$LOG_FILE")"

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')" "$*" >> "$LOG_FILE" 2>/dev/null || true
}

usage() {
  cat <<'USAGE'
QCA Code Quality Guard

Usage:
  qca-code-quality-guard.sh --ensure-venv
  qca-code-quality-guard.sh --validate <file.py>
  qca-code-quality-guard.sh --ensure-modules <file.py>
  qca-code-quality-guard.sh --notebook <file.py> [file.ipynb]
  qca-code-quality-guard.sh --prepare <file.py>
  qca-code-quality-guard.sh --execute <file.py>

All dependency and diagnostic details are logged behind the scenes.
USAGE
}

venv_python() {
  printf '%s/bin/python' "$VENV_PATH"
}

have_venv() {
  [[ -x "$(venv_python)" ]]
}

ensure_uv() {
  if command -v uv >/dev/null 2>&1; then
    return 0
  fi

  log "uv not found. Attempting silent uv install."
  if command -v curl >/dev/null 2>&1; then
    curl -LsSf https://astral.sh/uv/install.sh 2>>"$LOG_FILE" | sh >>"$LOG_FILE" 2>&1 || true
    export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"
  fi

  command -v uv >/dev/null 2>&1
}

ensure_venv() {
  if have_venv; then
    return 0
  fi

  log "Qiskit/Python virtual environment not found at $VENV_PATH. Creating silently."
  mkdir -p "$(dirname "$VENV_PATH")"

  if ensure_uv; then
    uv python install "$PYTHON_VERSION" >>"$LOG_FILE" 2>&1 || true
    uv venv --seed --python "$PYTHON_VERSION" "$VENV_PATH" >>"$LOG_FILE" 2>&1 || true
  fi

  if ! have_venv; then
    log "uv venv creation failed or unavailable. Falling back to python3 -m venv."
    python3 -m venv "$VENV_PATH" >>"$LOG_FILE" 2>&1 || true
    "$(venv_python)" -m ensurepip --upgrade >>"$LOG_FILE" 2>&1 || true
  fi

  if ! have_venv; then
    log "Failed to create virtual environment at $VENV_PATH."
    return 1
  fi

  "$(venv_python)" -m pip install --upgrade pip setuptools wheel >>"$LOG_FILE" 2>&1 || true
}

validate_python() {
  local py_file="$1"
  [[ -f "$py_file" ]] || { log "Missing Python file: $py_file"; return 1; }
  ensure_venv
  "$(venv_python)" -m py_compile "$py_file" >>"$LOG_FILE" 2>&1
}

extract_modules_json() {
  local py_file="$1"
  "$(venv_python)" - "$py_file" <<'PY'
import ast
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
mods = set()
try:
    tree = ast.parse(path.read_text(encoding="utf-8"))
except Exception:
    print("[]")
    raise

for node in ast.walk(tree):
    if isinstance(node, ast.Import):
        for alias in node.names:
            mods.add(alias.name.split(".")[0])
    elif isinstance(node, ast.ImportFrom):
        if node.module:
            mods.add(node.module.split(".")[0])

stdlib = set(getattr(sys, "stdlib_module_names", set()))
ignore = stdlib | {
    "__future__", "typing", "pathlib", "datetime", "json", "math", "os", "sys", "subprocess",
    "itertools", "collections", "dataclasses", "random", "statistics", "time", "re", "csv",
}
mods = sorted(m for m in mods if m and m not in ignore)
print(json.dumps(mods))
PY
}

package_for_module() {
  case "$1" in
    qiskit) echo "qiskit[visualization]" ;;
    qiskit_aer) echo "qiskit-aer" ;;
    qiskit_ibm_runtime) echo "qiskit-ibm-runtime" ;;
    qiskit_algorithms) echo "qiskit-algorithms" ;;
    qiskit_nature) echo "qiskit-nature" ;;
    dotenv) echo "python-dotenv" ;;
    matplotlib) echo "matplotlib" ;;
    numpy) echo "numpy" ;;
    scipy) echo "scipy" ;;
    pandas) echo "pandas" ;;
    sympy) echo "sympy" ;;
    pyscf) echo "pyscf" ;;
    networkx) echo "networkx" ;;
    pylatexenc) echo "pylatexenc" ;;
    IPython) echo "ipython" ;;
    nbformat) echo "nbformat" ;;
    *) echo "$1" ;;
  esac
}

module_exists() {
  local module="$1"
  "$(venv_python)" - "$module" <<'PY' >/dev/null 2>>"$LOG_FILE"
import importlib.util
import sys
module = sys.argv[1]
raise SystemExit(0 if importlib.util.find_spec(module) else 1)
PY
}

install_package() {
  local package="$1"
  log "Installing missing package silently: $package"
  if ensure_uv; then
    uv pip install --python "$(venv_python)" "$package" >>"$LOG_FILE" 2>&1 || \
      "$(venv_python)" -m pip install "$package" >>"$LOG_FILE" 2>&1
  else
    "$(venv_python)" -m pip install "$package" >>"$LOG_FILE" 2>&1
  fi
}

ensure_modules() {
  local py_file="$1"
  local modules_json
  ensure_venv
  validate_python "$py_file"
  modules_json="$(extract_modules_json "$py_file")"

  "$(venv_python)" - "$modules_json" <<'PY' | while IFS= read -r module; do
import json
import sys
for item in json.loads(sys.argv[1]):
    print(item)
PY
    [[ -z "$module" ]] && continue
    if ! module_exists "$module"; then
      install_package "$(package_for_module "$module")" || {
        log "Failed to install package for missing module: $module"
        return 1
      }
    fi
  done
}

create_notebook() {
  local py_file="$1"
  local ipynb_file="${2:-${py_file%.py}.ipynb}"
  ensure_venv
  validate_python "$py_file"

  "$(venv_python)" - "$py_file" "$ipynb_file" <<'PY'
import json
import sys
from pathlib import Path

py = Path(sys.argv[1])
ipynb = Path(sys.argv[2])
source = py.read_text(encoding="utf-8")
notebook = {
    "cells": [
        {
            "cell_type": "markdown",
            "metadata": {},
            "source": [
                "# QCA Generated Quantum Implementation\\n",
                f"Generated companion notebook for `{py.name}`.\\n"
            ],
        },
        {
            "cell_type": "code",
            "execution_count": None,
            "metadata": {},
            "outputs": [],
            "source": source.splitlines(True),
        },
    ],
    "metadata": {
        "kernelspec": {
            "display_name": "Python 3 (QCA)",
            "language": "python",
            "name": "python3",
        },
        "language_info": {
            "name": "python",
            "pygments_lexer": "ipython3",
        },
    },
    "nbformat": 4,
    "nbformat_minor": 5,
}
ipynb.write_text(json.dumps(notebook, indent=2), encoding="utf-8")
PY
}

prepare_file() {
  local py_file="$1"
  validate_python "$py_file"
  ensure_modules "$py_file"
  create_notebook "$py_file"
  test -f "${py_file%.py}.ipynb"
}

execute_file() {
  local py_file="$1"
  prepare_file "$py_file"
  log "Executing QCA Python artifact: $py_file"
  "$(venv_python)" "$py_file" 2>>"$LOG_FILE"
}

main() {
  local mode="${1:-}"
  local py_file="${2:-}"
  local ipynb_file="${3:-}"

  case "$mode" in
    --ensure-venv)
      ensure_venv
      ;;
    --validate)
      [[ -n "$py_file" ]] || { usage; return 2; }
      validate_python "$py_file"
      ;;
    --ensure-modules)
      [[ -n "$py_file" ]] || { usage; return 2; }
      ensure_modules "$py_file"
      ;;
    --notebook)
      [[ -n "$py_file" ]] || { usage; return 2; }
      create_notebook "$py_file" "$ipynb_file"
      ;;
    --prepare)
      [[ -n "$py_file" ]] || { usage; return 2; }
      prepare_file "$py_file"
      ;;
    --execute)
      [[ -n "$py_file" ]] || { usage; return 2; }
      execute_file "$py_file"
      ;;
    --help|-h|help)
      usage
      ;;
    *)
      usage
      return 2
      ;;
  esac
}

main "$@"
