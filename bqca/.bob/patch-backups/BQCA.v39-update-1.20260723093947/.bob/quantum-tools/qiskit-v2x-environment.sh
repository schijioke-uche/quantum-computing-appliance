#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOB_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BQCA_ROOT="$(cd "$BOB_ROOT/.." && pwd)"
ENV_DIR="${BQCA_QISKIT_ENV_DIR:-$BQCA_ROOT/qiskit-v2x-env}"
ENV_NAME="$(basename "$ENV_DIR")"
PYTHON_BIN="$ENV_DIR/bin/python"
CONFIG_TOOL="$SCRIPT_DIR/qiskit-configuration.sh"
CODE_VALIDATOR="$SCRIPT_DIR/qiskit-code-policy-check.py"
LOG_DIR="$BOB_ROOT/runtime"
LOG_FILE="${BQCA_QISKIT_V39_LOG:-$LOG_DIR/qiskit-v39-environment.log}"
LOCK_DIR="$LOG_DIR/qiskit-v39-environment.lock"
MIN_QISKIT="2.5"
SKIP_INSTALL="${BQCA_V39_SKIP_PACKAGE_INSTALL:-0}"
QUIET=0
LOCK_HELD=0

PACKAGES=(
  "qiskit>=2.5"
  "qiskit-aer"
  "qiskit-ibm-runtime"
  "qiskit-algorithms"
  "qiskit-connector"
  "jupyter"
  "nbconvert"
  "ipykernel"
)

log() {
  mkdir -p "$LOG_DIR"
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')" "$*" >> "$LOG_FILE" 2>/dev/null || true
}

say() {
  ((QUIET)) || printf '[BQCA v39] %s\n' "$*"
}

fail() {
  printf 'BQCA_QISKIT_V39=FAIL: %s\n' "$*" >&2
  exit 2
}

usage() {
  cat <<'USAGE'
BQCA Qiskit 2.5 runtime manager

Usage:
  qiskit-v2x-environment.sh ensure [--quiet]
  qiskit-v2x-environment.sh check [--quiet]
  qiskit-v2x-environment.sh python [python-arguments...]
  qiskit-v2x-environment.sh run <file.py> [script-arguments...]
  qiskit-v2x-environment.sh run-notebook <file.ipynb>
  qiskit-v2x-environment.sh hello-world
  qiskit-v2x-environment.sh hello-world-if-present
  qiskit-v2x-environment.sh exec -- <command> [arguments...]
  qiskit-v2x-environment.sh environment-path
  qiskit-v2x-environment.sh python-path

Every execution is performed inside <BQCA-root>/qiskit-v2x-env by default.
USAGE
}

release_lock() {
  if ((LOCK_HELD)); then
    rm -rf "$LOCK_DIR" 2>/dev/null || true
    LOCK_HELD=0
  fi
}
trap release_lock EXIT INT TERM

acquire_lock() {
  local attempt
  mkdir -p "$LOG_DIR"
  chmod 700 "$LOG_DIR" 2>/dev/null || true
  for attempt in $(seq 1 120); do
    if mkdir "$LOCK_DIR" 2>/dev/null; then
      LOCK_HELD=1
      return 0
    fi
    sleep 0.25
  done
  fail "Timed out waiting for Qiskit environment lock: $LOCK_DIR"
}

host_python_ok() {
  python3 - <<'PY'
import sys
raise SystemExit(0 if sys.version_info >= (3, 10) else 1)
PY
}

qiskit_version() {
  "$PYTHON_BIN" - <<'PY' 2>/dev/null || true
from importlib.metadata import PackageNotFoundError, version
try:
    print(version("qiskit"))
except PackageNotFoundError:
    pass
PY
}

qiskit_version_ok() {
  "$PYTHON_BIN" - <<'PY' >/dev/null 2>&1
from importlib.metadata import PackageNotFoundError, version
import re
try:
    raw = version("qiskit")
except PackageNotFoundError:
    raise SystemExit(1)
parts = [int(item) for item in re.findall(r"\d+", raw)[:2]]
while len(parts) < 2:
    parts.append(0)
raise SystemExit(0 if tuple(parts) >= (2, 5) else 1)
PY
}

required_imports_ok() {
  "$PYTHON_BIN" - <<'PY' >/dev/null 2>&1
import importlib.util
required = ("qiskit", "qiskit_aer", "qiskit_ibm_runtime", "qiskit_algorithms", "qiskit_connector")
missing = [name for name in required if importlib.util.find_spec(name) is None]
raise SystemExit(0 if not missing else 1)
PY
}

create_environment() {
  [[ "$ENV_NAME" == "qiskit-v2x-env" ]] || fail "Environment must be named qiskit-v2x-env, got: $ENV_NAME"
  if [[ -x "$PYTHON_BIN" ]]; then
    return 0
  fi
  host_python_ok || fail "Qiskit 2.5 requires Python 3.10 or later"
  command -v python3 >/dev/null 2>&1 || fail "python3 is unavailable"
  say "Creating Qiskit virtual environment: $ENV_DIR"
  log "Creating virtual environment: $ENV_DIR"
  python3 -m venv "$ENV_DIR" >>"$LOG_FILE" 2>&1 || fail "Unable to create virtual environment; inspect $LOG_FILE"
  [[ -x "$PYTHON_BIN" ]] || fail "Virtual environment Python was not created: $PYTHON_BIN"
}

install_or_upgrade_packages() {
  local current
  current="$(qiskit_version)"

  if [[ -n "$current" ]] && qiskit_version_ok && required_imports_ok; then
    say "qiskit-v2x-env ready: Qiskit $current"
    return 0
  fi

  if [[ "$SKIP_INSTALL" == "1" ]]; then
    fail "Qiskit 2.5+ or required packages are missing and package installation is disabled"
  fi

  say "Preparing Qiskit 2.5+ runtime packages"
  log "Upgrading pip/setuptools/wheel"
  "$PYTHON_BIN" -m pip install --upgrade pip setuptools wheel >>"$LOG_FILE" 2>&1 || fail "pip bootstrap failed; inspect $LOG_FILE"

  if [[ -n "$current" ]] && ! qiskit_version_ok; then
    say "Replacing outdated Qiskit $current with the latest Qiskit 2.5+"
    log "Uninstalling outdated Qiskit version: $current"
    "$PYTHON_BIN" -m pip uninstall -y qiskit qiskit-terra >>"$LOG_FILE" 2>&1 || true
  fi

  log "Installing/upgrading required Qiskit packages"
  "$PYTHON_BIN" -m pip install --upgrade "${PACKAGES[@]}" >>"$LOG_FILE" 2>&1 || fail "Qiskit package installation failed; inspect $LOG_FILE"

  qiskit_version_ok || fail "Installed Qiskit does not satisfy version 2.5+"
  required_imports_ok || fail "One or more required Qiskit runtime packages are unavailable"
  current="$(qiskit_version)"
  say "qiskit-v2x-env ready: Qiskit $current"
}

ensure_environment() {
  acquire_lock
  create_environment
  install_or_upgrade_packages
  release_lock
}

check_environment() {
  [[ "$ENV_NAME" == "qiskit-v2x-env" ]] || fail "Environment must be named qiskit-v2x-env"
  [[ -x "$PYTHON_BIN" ]] || fail "Environment does not exist: $ENV_DIR"
  qiskit_version_ok || fail "Qiskit 2.5+ is not installed in $ENV_DIR"
  required_imports_ok || fail "Required Qiskit packages are missing from $ENV_DIR"
  say "Environment: $ENV_DIR"
  say "Qiskit: $(qiskit_version)"
}

configure_account() {
  [[ -x "$CONFIG_TOOL" ]] || fail "Required v38 Qiskit configurator is missing: $CONFIG_TOOL"
  "$CONFIG_TOOL" configure --project-root "$BQCA_ROOT" --quiet
}

validate_code() {
  local file="$1"
  [[ -f "$file" ]] || fail "Python file not found: $file"
  "$PYTHON_BIN" -m py_compile "$file" || fail "Python syntax validation failed: $file"
  [[ -x "$CODE_VALIDATOR" ]] || fail "v39 code validator is unavailable: $CODE_VALIDATOR"
  "$PYTHON_BIN" "$CODE_VALIDATOR" "$file" || fail "BQCA v39 code policy validation failed: $file"
}

run_python_file() {
  local file="$1"
  shift
  ensure_environment
  configure_account
  validate_code "$file"
  export VIRTUAL_ENV="$ENV_DIR"
  export PATH="$ENV_DIR/bin:$PATH"
  exec "$PYTHON_BIN" "$file" "$@"
}

run_notebook_file() {
  local file="$1"
  ensure_environment
  configure_account
  [[ -f "$file" ]] || fail "Notebook file not found: $file"
  export VIRTUAL_ENV="$ENV_DIR"
  export PATH="$ENV_DIR/bin:$PATH"
  exec "$PYTHON_BIN" -m jupyter nbconvert --to notebook --execute --inplace "$file"
}

find_hello_world() {
  local test_dir="$BQCA_ROOT/test" candidate
  [[ -d "$test_dir" ]] || return 10
  for candidate in \
    "$test_dir/hello-world.py" \
    "$test_dir/hello_world.py" \
    "$test_dir/hellow-world.py" \
    "$test_dir/hello-world.ipynb" \
    "$test_dir/hello_world.ipynb" \
    "$test_dir/hellow-world.ipynb"; do
    [[ -f "$candidate" ]] && { printf '%s\n' "$candidate"; return 0; }
  done
  candidate="$(find "$test_dir" -maxdepth 2 -type f \( -iname '*hello*world*.py' -o -iname '*hello*world*.ipynb' -o -iname '*hellow*world*.py' -o -iname '*hellow*world*.ipynb' \) | sort | head -n 1 || true)"
  [[ -n "$candidate" ]] || return 10
  printf '%s\n' "$candidate"
}

run_hello_world() {
  local required="$1" artifact status
  set +e
  artifact="$(find_hello_world)"
  status=$?
  set -e
  if ((status == 10)); then
    if [[ "$required" == "yes" ]]; then
      fail "No Hello World Python file or notebook was found under $BQCA_ROOT/test"
    fi
    return 10
  fi
  say "Running prebuilt BQCA Hello World artifact: $artifact"
  case "$artifact" in
    *.py) run_python_file "$artifact" ;;
    *.ipynb) run_notebook_file "$artifact" ;;
    *) fail "Unsupported Hello World artifact: $artifact" ;;
  esac
}

command_name="${1:-}"
[[ -n "$command_name" ]] || { usage; exit 2; }
shift || true

case "$command_name" in
  ensure)
    if [[ "${1:-}" == "--quiet" ]]; then QUIET=1; shift; fi
    (($# == 0)) || { usage; exit 2; }
    ensure_environment
    ;;
  check)
    if [[ "${1:-}" == "--quiet" ]]; then QUIET=1; shift; fi
    (($# == 0)) || { usage; exit 2; }
    check_environment
    ;;
  python)
    ensure_environment
    export VIRTUAL_ENV="$ENV_DIR"
    export PATH="$ENV_DIR/bin:$PATH"
    exec "$PYTHON_BIN" "$@"
    ;;
  run)
    (($# >= 1)) || { usage; exit 2; }
    run_python_file "$@"
    ;;
  run-notebook)
    (($# == 1)) || { usage; exit 2; }
    run_notebook_file "$1"
    ;;
  hello-world)
    (($# == 0)) || { usage; exit 2; }
    run_hello_world yes
    ;;
  hello-world-if-present)
    (($# == 0)) || { usage; exit 2; }
    run_hello_world no
    ;;
  exec)
    [[ "${1:-}" == "--" ]] || { usage; exit 2; }
    shift
    (($# >= 1)) || { usage; exit 2; }
    ensure_environment
    export VIRTUAL_ENV="$ENV_DIR"
    export PATH="$ENV_DIR/bin:$PATH"
    exec "$@"
    ;;
  environment-path)
    printf '%s\n' "$ENV_DIR"
    ;;
  python-path)
    ensure_environment
    printf '%s\n' "$PYTHON_BIN"
    ;;
  -h|--help)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

# BQCA-QISKIT-EXECUTION-v39:POLICY-BEGIN
# V39 POLICY AWARENESS: Quantum/Qiskit create/implement/write/generate/build/
# develop/produce/scaffold/construct/code/program/modify/update/repair/fix/
# refactor/complete/execute requests are CODE intent. Use qiskit-v2x-env and
# Qiskit 2.5+. Open Plan uses SamplerV2(mode=backend) without Session; paid
# plans use Session with SamplerV2/EstimatorV2; simulator fallback uses
# transpile + AerSimulator. backend.run() is local-simulator-only. Hello World
# requests execute a matching artifact from project-root /test when present.
# BQCA-QISKIT-EXECUTION-v39:POLICY-END
