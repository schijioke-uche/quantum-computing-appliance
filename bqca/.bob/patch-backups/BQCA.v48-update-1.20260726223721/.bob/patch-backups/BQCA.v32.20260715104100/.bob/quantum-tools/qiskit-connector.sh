#!/usr/bin/env bash
set -Eeuo pipefail

# BQCA Qiskit Connector helper.
# This tool does not read or modify .env and does not submit quantum jobs.

usage() {
  cat <<'USAGE'
BQCA Qiskit Connector Tool

Usage:
  qiskit-connector.sh --check
  qiskit-connector.sh --install
  qiskit-connector.sh --show-python-template
  qiskit-connector.sh --help

Options:
  --check                 Report Python and qiskit-connector availability.
  --install               Install/upgrade qiskit-connector with Python pip.
  --show-python-template  Print the strict connector-first fallback template.
  --help                  Show this help.

This helper never reads or writes .env and never submits a QPU job.
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
else:
    print(f"qiskit-connector: {version}")

try:
    from qiskit_connector import QConnectorV2, QPlanV2
except Exception as exc:
    print(f"Import check: FAILED: {exc}")
    raise SystemExit(3)
else:
    print("Import check: PASS")
    print("Available classes: QConnectorV2, QPlanV2")
PY
}

install_connector() {
  local py
  py="$(python_cmd)"
  "$py" -m pip install --upgrade qiskit-connector
}

show_template() {
  cat <<'PY'
from qiskit_connector import QConnectorV2 as connector
from qiskit_connector import QPlanV2 as plan

try:
    current = plan()
    backend = connector()
    # Verify backend is an operational QPU with enough qubits.
    # Execute on the real QPU only when verification succeeds.
except Exception as exc:
    print(f"Qiskit Connector unavailable; using simulator: {exc}")
    try:
        from qiskit_aer import AerSimulator
        backend = AerSimulator()
    except ImportError:
        from qiskit.providers.basic_provider import BasicSimulator
        backend = BasicSimulator()
PY
}

case "${1:---help}" in
  --check) check_connector ;;
  --install) install_connector ;;
  --show-python-template) show_template ;;
  --help|-h) usage ;;
  *) usage >&2; exit 2 ;;
esac
