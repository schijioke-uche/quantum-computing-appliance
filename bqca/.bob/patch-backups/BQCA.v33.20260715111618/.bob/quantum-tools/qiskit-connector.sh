#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATOR="$SCRIPT_DIR/qiskit-code-policy-check.py"
TEMPLATE="$SCRIPT_DIR/qiskit-connector-required-template.py"

usage() {
  cat <<'USAGE'
BQCA Qiskit Connector Enforcement Tool v32

Usage:
  qiskit-connector.sh --check
  qiskit-connector.sh --install
  qiskit-connector.sh --show-python-template
  qiskit-connector.sh --validate-code <file.py>
  qiskit-connector.sh --validate-store [directory]
  qiskit-connector.sh --help
USAGE
}

python_cmd() {
  if command -v python3 >/dev/null 2>&1; then
    printf '%s\n' python3
  elif command -v python >/dev/null 2>&1; then
    printf '%s\n' python
  else
    printf 'ERROR: Python is not installed.\n' >&2
    exit 1
  fi
}

check_connector() {
  local py
  py="$(python_cmd)"
  "$py" - <<'PY'
import importlib.metadata as metadata
import sys
print(f"Python: {sys.version.split()[0]}")
try:
    version = metadata.version("qiskit-connector")
except metadata.PackageNotFoundError:
    print("qiskit-connector: not installed")
    raise SystemExit(2)
print(f"qiskit-connector: {version}")
from qiskit_connector import QConnectorV2, QPlanV2
print("Import check: PASS")
PY
}

install_connector() {
  local py
  py="$(python_cmd)"
  "$py" -m pip install --upgrade qiskit-connector
}

show_template() {
  cat "$TEMPLATE"
}

validate_code() {
  [[ $# -eq 1 ]] || { printf 'ERROR: --validate-code requires one Python file.\n' >&2; exit 2; }
  "$(python_cmd)" "$VALIDATOR" "$1"
}

validate_store() {
  local target="${1:-bob-quantum-store}"
  "$(python_cmd)" "$VALIDATOR" "$target"
}

case "${1:---help}" in
  --check) check_connector ;;
  --install) install_connector ;;
  --show-python-template) show_template ;;
  --validate-code) shift; validate_code "$@" ;;
  --validate-store) shift; validate_store "$@" ;;
  --help|-h) usage ;;
  *) usage >&2; exit 2 ;;
esac
