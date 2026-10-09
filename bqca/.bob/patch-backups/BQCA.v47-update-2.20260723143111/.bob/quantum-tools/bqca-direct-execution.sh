#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
BOB_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
BQCA_ROOT="$(cd "$BOB_ROOT/.." && pwd -P)"
: "${HOME:?HOME must be set}"
HOME_DIR="$(cd "$HOME" && pwd -P)"
ENV_DIR="$HOME_DIR/qiskit-v2x-env"
ACTIVATE="$ENV_DIR/bin/activate"
PYTHON_BIN="$ENV_DIR/bin/python"
CONFIG_TOOL="$SCRIPT_DIR/qiskit-configuration.sh"
ENV_TOOL="$SCRIPT_DIR/qiskit-v2x-environment.sh"
RESULT_TOOL="$SCRIPT_DIR/qiskit-result-output.sh"
ORCHESTRATOR="$SCRIPT_DIR/bqca-policy-orchestrator.sh"

usage() {
  cat <<'USAGE'
BQCA v47 direct execution controller

Usage:
  bqca-direct-execution.sh run <file.py> [arguments...]
  bqca-direct-execution.sh run-notebook <file.ipynb>
  bqca-direct-execution.sh formal-run <file.py|file.ipynb> [arguments...]
  bqca-direct-execution.sh decision-matrix

Defaults:
  Development/testing, interactive exploration, debugging, and quick
  experiments use direct execution.

Formal mode:
  Use formal-run only for formal documentation/compliance evidence,
  production deployment, or audit requirements.
USAGE
}

fail() { printf 'BQCA_DIRECT_EXECUTION_V46=FAIL: %s\n' "$*" >&2; exit 2; }

resolve_file() {
  local file="$1" dir base
  [[ -f "$file" ]] || fail "Artifact not found: $file"
  dir="$(cd "$(dirname "$file")" && pwd -P)"
  base="$(basename "$file")"
  printf '%s/%s\n' "$dir" "$base"
}

prepare_runtime() {
  if [[ "${BQCA_V46_TEST_MODE:-0}" == "1" ]]; then
    return 0
  fi
  [[ -x "$ENV_TOOL" ]] || fail "Qiskit environment tool is unavailable: $ENV_TOOL"
  "$ENV_TOOL" ensure --quiet
  [[ -f "$ACTIVATE" && -x "$PYTHON_BIN" ]] || fail "Authorized environment is unavailable: $ENV_DIR"
  # shellcheck source=/dev/null
  source "$HOME_DIR/qiskit-v2x-env/bin/activate"
  export PYTHONNOUSERSITE=1
  export PIP_REQUIRE_VIRTUALENV=true
  export PYTHONUNBUFFERED=1
  [[ "${VIRTUAL_ENV:-}" == "$ENV_DIR" ]] || fail "Unable to activate $ENV_DIR"
  python - <<'PY' >/dev/null 2>&1 || exit 2
from importlib.metadata import PackageNotFoundError, version
import re
try:
    raw = version("qiskit")
except PackageNotFoundError:
    raise SystemExit(1)
parts = [int(x) for x in re.findall(r"\d+", raw)[:2]]
while len(parts) < 2:
    parts.append(0)
raise SystemExit(0 if tuple(parts) >= (2, 5) else 1)
PY
}

configure_account() {
  [[ "${BQCA_V46_TEST_MODE:-0}" == "1" || "${BQCA_V46_SKIP_CONFIGURATION:-0}" == "1" ]] && return 0
  [[ -x "$CONFIG_TOOL" ]] || fail "Qiskit configuration tool is unavailable: $CONFIG_TOOL"
  "$CONFIG_TOOL" configure --quiet
}

python_command() {
  if [[ "${BQCA_V46_TEST_MODE:-0}" == "1" ]]; then
    printf '%s\n' "${BQCA_V46_TEST_PYTHON:-$(command -v python3)}"
  else
    printf '%s\n' "$PYTHON_BIN"
  fi
}

run_python() {
  local file python_cmd
  file="$(resolve_file "$1")"
  shift
  prepare_runtime
  configure_account
  python_cmd="$(python_command)"
  [[ -x "$RESULT_TOOL" ]] || fail "Result capture tool is unavailable: $RESULT_TOOL"
  export BQCA_EXECUTION_METHOD=DIRECT BQCA_V46_DIRECT=1 BQCA_V46_INTERNAL=1 PYTHONUNBUFFERED=1
  exec "$RESULT_TOOL" --source "$file" -- "$python_cmd" -u "$file" "$@"
}

run_notebook() {
  local file python_cmd
  file="$(resolve_file "$1")"
  prepare_runtime
  configure_account
  python_cmd="$(python_command)"
  [[ -x "$RESULT_TOOL" ]] || fail "Result capture tool is unavailable: $RESULT_TOOL"
  export BQCA_EXECUTION_METHOD=DIRECT BQCA_V46_DIRECT=1 BQCA_V46_INTERNAL=1 PYTHONUNBUFFERED=1
  exec "$RESULT_TOOL" --source "$file" -- "$python_cmd" -u -m jupyter nbconvert --to notebook --execute --inplace "$file"
}

formal_run() {
  (($# >= 1)) || { usage; exit 2; }
  [[ -x "$ORCHESTRATOR" ]] || fail "Formal orchestrator is unavailable: $ORCHESTRATOR"
  export BQCA_EXECUTION_METHOD=FORMAL BQCA_V46_FORMAL=1
  exec "$ORCHESTRATOR" execute "$@"
}

print_matrix() {
  cat <<'MATRIX'
Execution Decision Matrix

Scenario                 Method        Reason
-----------------------  ------------  ----------------------------------------
Development/Testing      Direct        Fast, real-time output
Interactive Exploration  Direct        Immediate feedback
Debugging                Direct        Clear live error messages
Quick Experiments        Direct        No orchestrator validation overhead
Formal Documentation     Orchestrator  Compliance reports
Production Deployment    Orchestrator  Full validation and completion gates
Audit Requirements       Orchestrator  Policy enforcement and audit evidence
MATRIX
}

case "${1:-}" in
  run)
    shift
    (($# >= 1)) || { usage; exit 2; }
    run_python "$@"
    ;;
  run-notebook)
    shift
    (($# == 1)) || { usage; exit 2; }
    run_notebook "$1"
    ;;
  formal-run)
    shift
    formal_run "$@"
    ;;
  decision-matrix)
    print_matrix
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
# The sole active policy is .bob/BQCA-PRODUCTION-POLICY-v47.md.
# v47 direct execution is the default for development/testing, exploration,
# debugging, and quick experiments. The orchestrator is explicit and optional
# for formal compliance, production deployment, and audit. Mirror output live
# and write both <source-stem>-result-output.txt and output.txt.
# BQCA-CANONICAL-PRODUCTION-POLICY-v47:END
