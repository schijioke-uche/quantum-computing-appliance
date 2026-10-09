#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
BOB_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
BQCA_ROOT="$(cd "$BOB_ROOT/.." && pwd -P)"
: "${HOME:?HOME must be set for BQCA qiskit-v2x-env}"
HOME_DIR="$(cd "$HOME" 2>/dev/null && pwd -P)"
ENV_DIR="$HOME_DIR/qiskit-v2x-env"
LEGACY_PROJECT_ENV="$BQCA_ROOT/qiskit-v2x-env"
ENV_NAME="$(basename "$ENV_DIR")"
ACTIVATE_SCRIPT="$ENV_DIR/bin/activate"
PYTHON_BIN="$ENV_DIR/bin/python"
PYVENV_CFG="$ENV_DIR/pyvenv.cfg"
CONFIG_TOOL="$SCRIPT_DIR/qiskit-configuration.sh"
CODE_VALIDATOR="$SCRIPT_DIR/qiskit-code-policy-check.py"
HOME_ENV_VALIDATOR="$SCRIPT_DIR/qiskit-home-env-policy-check.py"
# BQCA-RESULT-OUTPUT-v42:INTEGRATION-BEGIN
RESULT_OUTPUT_TOOL="$SCRIPT_DIR/qiskit-result-output.sh"
RESULT_POLICY_VALIDATOR="$SCRIPT_DIR/qiskit-result-output-policy-check.py"
# BQCA-RESULT-OUTPUT-v42:INTEGRATION-END
LOG_DIR="$BOB_ROOT/runtime"
LOG_FILE="${BQCA_QISKIT_V40_LOG:-$LOG_DIR/qiskit-v40-environment.log}"
LOCK_DIR="$LOG_DIR/qiskit-v40-environment.lock"
SKIP_INSTALL="${BQCA_V40_SKIP_PACKAGE_INSTALL:-${BQCA_V39_SKIP_PACKAGE_INSTALL:-0}}"
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
  ((QUIET)) || printf '[BQCA v40] %s\n' "$*"
}

warn() {
  ((QUIET)) || printf '[BQCA v40][WARN] %s\n' "$*" >&2
  log "WARN: $*"
}

fail() {
  printf 'BQCA_QISKIT_V40=FAIL: %s\n' "$*" >&2
  exit 2
}

usage() {
  cat <<'USAGE'
BQCA home-scoped Qiskit 2.5+ runtime manager v40

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
  qiskit-v2x-environment.sh activation-command

Mandatory environment:
  $HOME/qiskit-v2x-env

Creation:
  python3 -m venv "$HOME/qiskit-v2x-env"

Activation:
  source "$HOME/qiskit-v2x-env/bin/activate"

A project-local <BQCA-root>/qiskit-v2x-env is unsupported and ignored.
USAGE
}

assert_home_scope() {
  [[ "$ENV_NAME" == "qiskit-v2x-env" ]] || \
    fail "Environment must be named qiskit-v2x-env, got: $ENV_NAME"
  [[ "$ENV_DIR" == "$HOME_DIR/qiskit-v2x-env" ]] || \
    fail "Environment must resolve to $HOME_DIR/qiskit-v2x-env"
  case "$ENV_DIR/" in
    "$BQCA_ROOT/"*)
      fail "Home environment resolves inside the BQCA project root: $ENV_DIR"
      ;;
  esac
}

report_legacy_project_environment() {
  if [[ -e "$LEGACY_PROJECT_ENV" ]]; then
    warn "Ignoring unsupported project-local environment: $LEGACY_PROJECT_ENV"
  fi
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
  for ((attempt = 1; attempt <= 120; attempt++)); do
    if mkdir "$LOCK_DIR" 2>/dev/null; then
      LOCK_HELD=1
      return 0
    fi
    sleep 0.25
  done
  fail "Timed out waiting for environment lock: $LOCK_DIR"
}

host_python_ok() {
  python3 - <<'PY'
import sys
raise SystemExit(0 if sys.version_info >= (3, 10) else 1)
PY
}

activate_environment() {
  assert_home_scope
  [[ -f "$ACTIVATE_SCRIPT" ]] || fail "Activation script is missing: $ACTIVATE_SCRIPT"
  # shellcheck source=/dev/null
  source "$HOME_DIR/qiskit-v2x-env/bin/activate"
  export PYTHONNOUSERSITE=1
  export PIP_REQUIRE_VIRTUALENV=true

  [[ "${VIRTUAL_ENV:-}" == "$ENV_DIR" ]] || \
    fail "Activation did not select the required environment: $ENV_DIR"

  local active_python
  active_python="$(command -v python 2>/dev/null || true)"
  [[ -n "$active_python" ]] || fail "Activated environment has no python command"

  python - "$ENV_DIR" <<'PY' >/dev/null 2>&1 || \
    fail "Activated Python is not isolated inside $ENV_DIR"
import pathlib
import sys
expected = pathlib.Path(sys.argv[1]).resolve()
actual = pathlib.Path(sys.prefix).resolve()
base = pathlib.Path(sys.base_prefix).resolve()
raise SystemExit(0 if actual == expected and actual != base else 1)
PY
}

assert_environment_python() {
  [[ -x "$PYTHON_BIN" ]] || fail "Environment Python is missing: $PYTHON_BIN"
  [[ -f "$PYVENV_CFG" ]] || fail "Environment metadata is missing: $PYVENV_CFG"

  if grep -Eiq \
    '^[[:space:]]*include-system-site-packages[[:space:]]*=[[:space:]]*true[[:space:]]*$' \
    "$PYVENV_CFG"; then
    fail "qiskit-v2x-env exposes host packages; recreate $ENV_DIR with include-system-site-packages=false"
  fi

  activate_environment
}

qiskit_version() {
  activate_environment
  python - <<'PY' 2>/dev/null || true
from importlib.metadata import PackageNotFoundError, version
try:
    print(version("qiskit"))
except PackageNotFoundError:
    pass
PY
}

qiskit_version_ok() {
  activate_environment
  python - <<'PY' >/dev/null 2>&1
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
  activate_environment
  python - <<'PY' >/dev/null 2>&1
import importlib.util
required = (
    "qiskit",
    "qiskit_aer",
    "qiskit_ibm_runtime",
    "qiskit_algorithms",
    "qiskit_connector",
)
missing = [name for name in required if importlib.util.find_spec(name) is None]
raise SystemExit(0 if not missing else 1)
PY
}

create_environment() {
  assert_home_scope
  report_legacy_project_environment

  if [[ -e "$ENV_DIR" && ! -x "$PYTHON_BIN" ]]; then
    fail "Path exists but is not a valid qiskit-v2x-env: $ENV_DIR"
  fi

  if [[ -x "$PYTHON_BIN" ]]; then
    assert_environment_python
    return 0
  fi

  command -v python3 >/dev/null 2>&1 || fail "python3 is unavailable"
  host_python_ok || fail "Qiskit 2.5 requires Python 3.10 or later"
  say "Creating home-scoped environment: $ENV_DIR"
  log "Creating home-scoped environment with python3 -m venv: $ENV_DIR"
  python3 -m venv "$HOME_DIR/qiskit-v2x-env" >> "$LOG_FILE" 2>&1 || \
    fail "Unable to create $ENV_DIR; inspect $LOG_FILE"
  assert_environment_python
}

install_or_upgrade_packages() {
  local current
  assert_environment_python
  current="$(qiskit_version)"

  if [[ -n "$current" ]] && qiskit_version_ok && required_imports_ok; then
    say "Home qiskit-v2x-env ready: Qiskit $current"
    return 0
  fi

  if [[ "$SKIP_INSTALL" == "1" ]]; then
    fail "Home environment Qiskit 2.5+ or required packages are missing and installation is disabled"
  fi

  activate_environment
  say "Preparing Qiskit 2.5+ inside $ENV_DIR"
  log "Upgrading pip/setuptools/wheel inside activated home environment"
  python -m pip install --upgrade pip setuptools wheel \
    >> "$LOG_FILE" 2>&1 || fail "Environment-local pip bootstrap failed; inspect $LOG_FILE"

  if [[ -n "$current" ]] && ! qiskit_version_ok; then
    activate_environment
    say "Replacing environment-local Qiskit $current"
    log "Uninstalling outdated environment-local Qiskit: $current"
    python -m pip uninstall -y qiskit qiskit-terra \
      >> "$LOG_FILE" 2>&1 || true
  fi

  activate_environment
  log "Installing/upgrading required packages inside activated $ENV_DIR"
  python -m pip install --upgrade "${PACKAGES[@]}" \
    >> "$LOG_FILE" 2>&1 || fail "Environment-local package installation failed; inspect $LOG_FILE"

  qiskit_version_ok || fail "Environment-local Qiskit does not satisfy 2.5+"
  required_imports_ok || fail "Required environment-local packages are unavailable"
  current="$(qiskit_version)"
  say "Home qiskit-v2x-env ready: Qiskit $current"
}

ensure_environment() {
  acquire_lock
  create_environment
  install_or_upgrade_packages
  release_lock
}

check_environment() {
  assert_home_scope
  report_legacy_project_environment
  [[ -x "$PYTHON_BIN" ]] || fail "Home environment does not exist: $ENV_DIR"
  assert_environment_python
  qiskit_version_ok || fail "Qiskit 2.5+ is not installed inside $ENV_DIR"
  required_imports_ok || fail "Required packages are missing inside $ENV_DIR"
  say "Environment: $ENV_DIR"
  say "Activation: source $ENV_DIR/bin/activate"
  say "Qiskit: $(qiskit_version)"
}

configure_account() {
  [[ -x "$CONFIG_TOOL" ]] || fail "Required v38 configurator is missing: $CONFIG_TOOL"
  "$CONFIG_TOOL" configure --project-root "$BQCA_ROOT" --quiet
}

validate_code() {
  local file="$1"
  [[ -f "$file" ]] || fail "Python file not found: $file"
  assert_environment_python
  python -m py_compile "$file" || fail "Python syntax validation failed: $file"
  [[ -x "$CODE_VALIDATOR" ]] || fail "v39 code validator is unavailable: $CODE_VALIDATOR"
  python "$CODE_VALIDATOR" "$file" || fail "BQCA code policy validation failed: $file"
  if [[ -x "$HOME_ENV_VALIDATOR" ]]; then
    python "$HOME_ENV_VALIDATOR" "$file" || fail "BQCA v40 home-environment policy validation failed: $file"
  fi
  [[ -x "$RESULT_POLICY_VALIDATOR" ]] || fail "BQCA v42 result validator is unavailable: $RESULT_POLICY_VALIDATOR"
  python "$RESULT_POLICY_VALIDATOR" --kind code "$file" || fail "BQCA v42 result-output code policy failed: $file"
}

run_python_file() {
  local file="$1"
  shift
  ensure_environment
  configure_account
  activate_environment
  validate_code "$file"
  [[ -x "$RESULT_OUTPUT_TOOL" ]] || fail "BQCA v42 result-output tool is unavailable: $RESULT_OUTPUT_TOOL"
  exec "$RESULT_OUTPUT_TOOL" --source "$file" -- python "$file" "$@"
}

run_notebook_file() {
  local file="$1"
  ensure_environment
  configure_account
  [[ -f "$file" ]] || fail "Notebook file not found: $file"
  activate_environment
  [[ -x "$RESULT_OUTPUT_TOOL" ]] || fail "BQCA v42 result-output tool is unavailable: $RESULT_OUTPUT_TOOL"
  exec "$RESULT_OUTPUT_TOOL" --source "$file" -- python -m jupyter nbconvert --to notebook --execute --inplace "$file"
}

find_hello_world() {
  local test_dir="$BQCA_ROOT/bob-quantum-store/test" candidate
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

  candidate="$(
    find "$test_dir" -maxdepth 2 -type f \
      \( -iname '*hello*world*.py' -o \
         -iname '*hello*world*.ipynb' -o \
         -iname '*hellow*world*.py' -o \
         -iname '*hellow*world*.ipynb' \) \
      | sort | head -n 1 || true
  )"
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
      fail "No Hello World artifact found under $BQCA_ROOT/bob-quantum-store/test"
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

# BQCA-CANONICAL-ORCHESTRATOR-v45:BEGIN
if [[ "${BQCA_V45_INTERNAL:-0}" != "1" && "${BQCA_V45_ORCHESTRATED:-0}" != "1" ]]; then
  _BQCA_V45_ORCHESTRATOR="$SCRIPT_DIR/bqca-policy-orchestrator.sh"
  case "$command_name" in
    run|run-notebook)
      [[ -x "$_BQCA_V45_ORCHESTRATOR" ]] || { printf 'BQCA v45 orchestrator is missing: %s\n' "$_BQCA_V45_ORCHESTRATOR" >&2; exit 2; }
      (($# >= 1)) || { usage; exit 2; }
      exec "$_BQCA_V45_ORCHESTRATOR" execute "$@"
      ;;
  esac
fi
# BQCA-CANONICAL-ORCHESTRATOR-v45:END

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
    activate_environment
    exec python "$@"
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
    activate_environment
    exec "$@"
    ;;
  environment-path)
    assert_home_scope
    printf '%s\n' "$ENV_DIR"
    ;;
  python-path)
    ensure_environment
    activate_environment
    printf '%s\n' "$(command -v python)"
    ;;
  activation-command)
    assert_home_scope
    printf 'source %q\n' "$ACTIVATE_SCRIPT"
    ;;
  -h|--help)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
# BQCA-CANONICAL-PRODUCTION-POLICY-v45:BEGIN
# The sole active BQCA policy is .bob/BQCA-PRODUCTION-POLICY.md (v45).
# Route all public design, code, execution, result, and completion paths through
# bqca-policy-orchestrator.sh. Open Plan uses SamplerV2 or EstimatorV2 job mode
# according to workload semantics and must never use Session.
# BQCA-CANONICAL-PRODUCTION-POLICY-v45:END
# BQCA-CANONICAL-PRODUCTION-POLICY-v44:BEGIN
# The sole active BQCA policy is .bob/BQCA-PRODUCTION-POLICY.md (v44).
# Route all public design, code, execution, result, and completion paths through
# bqca-policy-orchestrator.sh. Open Plan uses SamplerV2 or EstimatorV2 job mode
# according to workload semantics and must never use Session.
# BQCA-CANONICAL-PRODUCTION-POLICY-v44:END
