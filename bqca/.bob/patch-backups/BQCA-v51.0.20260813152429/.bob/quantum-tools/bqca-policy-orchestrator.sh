#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

# BQCA-FORMAL-ORCHESTRATOR-v48:BEGIN
# The orchestrator is explicit and optional. This flag keeps child wrapper calls
# on the formal path and prevents recursion into the direct-execution default.
export BQCA_V48_FORMAL=1
# BQCA-FORMAL-ORCHESTRATOR-v48:END

BOB_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
BQCA_ROOT="$(cd "$BOB_ROOT/.." && pwd -P)"
POLICY="$BOB_ROOT/BQCA-PRODUCTION-POLICY.md"
VERSIONED_POLICY="$BOB_ROOT/BQCA-PRODUCTION-POLICY-v48.md"
REGISTRY="$BOB_ROOT/BQCA-ACTIVE-POLICY-REGISTRY.json"
HISTORY_MANIFEST="$BQCA_ROOT/patches/BQCA/policy-history/BQCA-policy-history-manifest.json"
HELPER="$SCRIPT_DIR/bqca-policy-orchestrator.py"
DOCTOR="$SCRIPT_DIR/bqca-policy-doctor.sh"
CONFIG_TOOL="$SCRIPT_DIR/qiskit-configuration.sh"
ENV_TOOL="$SCRIPT_DIR/qiskit-v2x-environment.sh"
CODE_VALIDATOR="$SCRIPT_DIR/qiskit-code-policy-check.py"
HOME_ENV_VALIDATOR="$SCRIPT_DIR/qiskit-home-env-policy-check.py"
DESIGN_VALIDATOR="$SCRIPT_DIR/qiskit-design-policy-check.py"
HELLO_VALIDATOR="$SCRIPT_DIR/qiskit-hello-world-scope-check.py"
RESULT_VALIDATOR="$SCRIPT_DIR/qiskit-result-output-policy-check.py"
SECRET_SCANNER="$SCRIPT_DIR/bqca-secret-scan.py"
NOTEBOOK_GENERATOR="$SCRIPT_DIR/notebook-generator.sh"
DESIGN_DIR="$BQCA_ROOT/bob-quantum-designs"
STORE_DIR="$BQCA_ROOT/bob-quantum-store"

# BQCA-FORMAL-ORCHESTRATOR-GUARD-v48:BEGIN
export BQCA_EXECUTION_METHOD=FORMAL
export BQCA_V48_FORMAL=1
export BQCA_V48_INTERNAL=1
export BQCA_V48_INTERNAL=1
export BQCA_V48_ORCHESTRATED=1
export BQCA_V48_INTERNAL=1
export BQCA_V48_ORCHESTRATED=1
# BQCA-FORMAL-ORCHESTRATOR-GUARD-v48:END


info() { printf '[BQCA v48][FORMAL ORCHESTRATOR] %s\n' "$*"; }
fail() { printf '[BQCA v48][FORMAL ORCHESTRATOR][ERROR] %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'USAGE'
BQCA v48 optional formal policy orchestrator

Usage:
  bqca-policy-orchestrator.sh validate-design <design.md> [more...]
  bqca-policy-orchestrator.sh validate-code <code.py> [more...]
  bqca-policy-orchestrator.sh validate-store [directory]
  bqca-policy-orchestrator.sh validate-design-store [directory]
  bqca-policy-orchestrator.sh pre-execute <code.py>
  bqca-policy-orchestrator.sh execute <code.py|notebook.ipynb> [arguments...]
  bqca-policy-orchestrator.sh post-execute <code.py|notebook.ipynb>
  bqca-policy-orchestrator.sh validate-result <result.txt> [source.py|source.ipynb]
  bqca-policy-orchestrator.sh validate-installation
  bqca-policy-orchestrator.sh explain-policy
USAGE
}

require_file() { [[ -f "$1" ]] || fail "Required file is missing: $1"; }
require_exec() { [[ -x "$1" ]] || fail "Required executable is missing: $1"; }

inside_dir() {
  python3 - "$1" "$2" <<'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1]).resolve()
root = pathlib.Path(sys.argv[2]).resolve()
try:
    path.relative_to(root)
except ValueError:
    raise SystemExit(1)
PY
}

record_check() {
  local checks="$1" label="$2"
  shift 2
  local log status detail
  log="$(mktemp)"
  set +e
  "$@" >"$log" 2>&1
  status=$?
  set -e
  cat "$log"
  detail="$(tr '\n' ' ' < "$log" | tr '|' ';' | cut -c1-360)"
  if ((status == 0)); then
    printf '%s|PASS|%s\n' "$label" "$detail" >> "$checks"
  else
    printf '%s|FAIL|%s\n' "$label" "$detail" >> "$checks"
  fi
  rm -f "$log"
  return "$status"
}

write_report() {
  python3 "$HELPER" write-report --artifact "$1" --kind "$2" --status "$3" --checks "$4" --policy "$POLICY"
}

run_secret_scan() {
  [[ -x "$SECRET_SCANNER" ]] || return 0
  python3 "$SECRET_SCANNER" --use-env "$@"
}

validate_design_one() {
  local file="$1" checks failures=0 report
  [[ -f "$file" ]] || fail "Design not found: $file"
  if [[ "${BQCA_V48_TEST_MODE:-0}" != "1" ]] && ! inside_dir "$file" "$DESIGN_DIR"; then
    fail "Design must be under $DESIGN_DIR: $file"
  fi
  checks="$(mktemp)"
  if [[ "${BQCA_V48_TEST_MODE:-0}" == "1" ]]; then
    printf '%s|PASS|Synthetic validation path accepted in test mode\n' "Artifact routing" >> "$checks"
  else
    record_check "$checks" "Artifact routing" inside_dir "$file" "$DESIGN_DIR" || failures=$((failures+1))
  fi
  record_check "$checks" "Design policy" python3 "$DESIGN_VALIDATOR" "$file" || failures=$((failures+1))
  record_check "$checks" "Hello World scope" python3 "$HELLO_VALIDATOR" --kind design "$file" || failures=$((failures+1))
  record_check "$checks" "Result-output contract" python3 "$RESULT_VALIDATOR" --kind design "$file" || failures=$((failures+1))
  record_check "$checks" "Secret scan" run_secret_scan "$file" || failures=$((failures+1))
  if ((failures)); then
    write_report "$file" design NONCOMPLIANT "$checks" >/dev/null
    rm -f "$checks"
    return 1
  fi
  report="$(write_report "$file" design COMPLIANT "$checks")"
  rm -f "$checks"
  printf 'BQCA_V48_FORMAL_COMPLETION_GATE=PASS artifact=%s report=%s\n' "$file" "$report"
}

validate_code_one() {
  local file="$1" checks failures=0 notebook report
  [[ -f "$file" && "$file" == *.py ]] || fail "validate-code requires a Python file: $file"
  if [[ "${BQCA_V48_TEST_MODE:-0}" != "1" ]] && ! inside_dir "$file" "$STORE_DIR"; then
    fail "Implementation must be under $STORE_DIR: $file"
  fi
  checks="$(mktemp)"
  if [[ "${BQCA_V48_TEST_MODE:-0}" == "1" ]]; then
    printf '%s|PASS|Synthetic validation path accepted in test mode\n' "Artifact routing" >> "$checks"
  else
    record_check "$checks" "Artifact routing" inside_dir "$file" "$STORE_DIR" || failures=$((failures+1))
  fi

  if [[ "${BQCA_V48_STATIC_ONLY:-0}" == "1" ]]; then
    record_check "$checks" "Python syntax" python3 -m py_compile "$file" || failures=$((failures+1))
    record_check "$checks" "Qiskit code policy" python3 "$CODE_VALIDATOR" "$file" || failures=$((failures+1))
    record_check "$checks" "Home environment policy" python3 "$HOME_ENV_VALIDATOR" "$file" || failures=$((failures+1))
    record_check "$checks" "Hello World scope" python3 "$HELLO_VALIDATOR" --kind code "$file" || failures=$((failures+1))
    record_check "$checks" "Result-output markers" python3 "$RESULT_VALIDATOR" --kind code "$file" || failures=$((failures+1))
  else
    require_exec "$ENV_TOOL"
    "$ENV_TOOL" ensure --quiet
    record_check "$checks" "Python syntax" "$ENV_TOOL" python -m py_compile "$file" || failures=$((failures+1))
    record_check "$checks" "Qiskit code policy" "$ENV_TOOL" python "$CODE_VALIDATOR" "$file" || failures=$((failures+1))
    record_check "$checks" "Home environment policy" "$ENV_TOOL" python "$HOME_ENV_VALIDATOR" "$file" || failures=$((failures+1))
    record_check "$checks" "Hello World scope" "$ENV_TOOL" python "$HELLO_VALIDATOR" --kind code "$file" || failures=$((failures+1))
    record_check "$checks" "Result-output markers" "$ENV_TOOL" python "$RESULT_VALIDATOR" --kind code "$file" || failures=$((failures+1))
  fi
  record_check "$checks" "Secret scan" run_secret_scan "$file" || failures=$((failures+1))

  notebook="${file%.py}.ipynb"
  if [[ ! -f "$notebook" ]]; then
    record_check "$checks" "Notebook generation" "$NOTEBOOK_GENERATOR" --source "$file" --output "$notebook" --force || failures=$((failures+1))
  fi
  if [[ -f "$notebook" ]]; then
    record_check "$checks" "Notebook synchronization" "$NOTEBOOK_GENERATOR" --validate "$notebook" --against-source "$file" || failures=$((failures+1))
    record_check "$checks" "Notebook secret scan" run_secret_scan "$notebook" || failures=$((failures+1))
  else
    printf '%s|FAIL|Notebook was not created\n' "Notebook synchronization" >> "$checks"
    failures=$((failures+1))
  fi

  if ((failures)); then
    write_report "$file" code NONCOMPLIANT "$checks" >/dev/null
    rm -f "$checks"
    return 1
  fi
  report="$(write_report "$file" code COMPLIANT "$checks")"
  rm -f "$checks"
  printf 'BQCA_V48_FORMAL_COMPLETION_GATE=PASS artifact=%s report=%s\n' "$file" "$report"
}

pre_execute() {
  local source="$1"
  [[ -f "$source" ]] || fail "Source not found: $source"
  require_exec "$DOCTOR"
  require_exec "$CONFIG_TOOL"
  require_exec "$ENV_TOOL"
  "$DOCTOR" check --quiet
  "$CONFIG_TOOL" configure --project-root "$BQCA_ROOT" --quiet
  "$ENV_TOOL" ensure --quiet
  if [[ "$source" == *.py ]]; then
    validate_code_one "$source"
  elif [[ "$source" == *.ipynb ]]; then
    local sibling="${source%.ipynb}.py"
    [[ -f "$sibling" ]] || fail "Notebook execution requires its authoritative sibling Python source: $sibling"
    validate_code_one "$sibling"
  else
    fail "Unsupported executable artifact: $source"
  fi
}

validate_result_one() {
  local result="$1" source="${2:-}"
  [[ -f "$result" ]] || fail "Result file not found: $result"
  if [[ -n "$source" ]]; then
    python3 "$RESULT_VALIDATOR" --kind result --source "$source" "$result"
  else
    python3 "$RESULT_VALIDATOR" --kind result "$result"
  fi
  run_secret_scan "$result"
}

post_execute() {
  local source="$1" result checks failures=0 notebook report
  result="${source%.*}-result-output.txt"
  checks="$(mktemp)"
  record_check "$checks" "Result-output contract" validate_result_one "$result" "$source" || failures=$((failures+1))
  if [[ "$source" == *.py ]]; then
    notebook="${source%.py}.ipynb"
    record_check "$checks" "Notebook synchronization" "$NOTEBOOK_GENERATOR" --validate "$notebook" --against-source "$source" || failures=$((failures+1))
  elif [[ "$source" == *.ipynb ]]; then
    local sibling="${source%.ipynb}.py"
    record_check "$checks" "Notebook synchronization" "$NOTEBOOK_GENERATOR" --validate "$source" --against-source "$sibling" || failures=$((failures+1))
  fi
  if ((failures)); then
    write_report "$source" execution NONCOMPLIANT "$checks" >/dev/null
    rm -f "$checks"
    return 1
  fi
  report="$(write_report "$source" execution COMPLIANT "$checks")"
  rm -f "$checks"
  run_secret_scan "$report"
  printf 'BQCA_V48_FORMAL_COMPLETION_GATE=PASS artifact=%s report=%s\n' "$source" "$report"
}

execute_artifact() {
  local source="$1"
  shift
  pre_execute "$source"
  local status
  set +e
  if [[ "$source" == *.py ]]; then
    BQCA_V48_FORMAL=1 BQCA_V48_INTERNAL=1 BQCA_V48_ORCHESTRATED=1 "$ENV_TOOL" run "$source" "$@"
    status=$?
  elif [[ "$source" == *.ipynb ]]; then
    BQCA_V48_FORMAL=1 BQCA_V48_INTERNAL=1 BQCA_V48_ORCHESTRATED=1 "$ENV_TOOL" run-notebook "$source"
    status=$?
  else
    status=2
  fi
  set -e
  post_execute "$source" || status=1
  return "$status"
}

validate_installation() {
  require_file "$POLICY"
  require_file "$VERSIONED_POLICY"
  require_file "$REGISTRY"
  require_file "$HISTORY_MANIFEST"
  require_exec "$HELPER"
  require_exec "$DOCTOR"
  python3 "$HELPER" validate-registry --root "$BQCA_ROOT" --registry "$REGISTRY" --manifest "$HISTORY_MANIFEST" --policy "$POLICY" --versioned-policy "$VERSIONED_POLICY"
  python3 "$HELPER" scan-active --root "$BQCA_ROOT"
  "$DOCTOR" check --quiet
}

command_name="${1:-}"
[[ -n "$command_name" ]] || { usage; exit 2; }
shift || true
case "$command_name" in
  validate-design)
    (($# >= 1)) || { usage; exit 2; }
    for file in "$@"; do validate_design_one "$file"; done
    ;;
  validate-code)
    (($# >= 1)) || { usage; exit 2; }
    for file in "$@"; do validate_code_one "$file"; done
    ;;
  validate-store)
    root="${1:-$STORE_DIR}"
    mapfile -d '' files < <(find "$root" -type f -name '*.py' -print0)
    ((${#files[@]})) || { info "No Python files found under $root"; exit 0; }
    for file in "${files[@]}"; do validate_code_one "$file"; done
    ;;
  validate-design-store)
    root="${1:-$DESIGN_DIR}"
    mapfile -d '' files < <(find "$root" -type f \( -name '*.md' -o -name '*.txt' \) -print0)
    ((${#files[@]})) || { info "No design files found under $root"; exit 0; }
    for file in "${files[@]}"; do validate_design_one "$file"; done
    ;;
  pre-execute) (($# == 1)) || { usage; exit 2; }; pre_execute "$1" ;;
  execute) (($# >= 1)) || { usage; exit 2; }; source="$1"; shift; execute_artifact "$source" "$@" ;;
  post-execute) (($# == 1)) || { usage; exit 2; }; post_execute "$1" ;;
  validate-result) (($# == 1 || $# == 2)) || { usage; exit 2; }; validate_result_one "$1" "${2:-}" ;;
  validate-installation) (($# == 0)) || { usage; exit 2; }; validate_installation ;;
  explain-policy) (($# == 0)) || { usage; exit 2; }; cat "$POLICY" ;;
  -h|--help) usage ;;
  *) usage >&2; exit 2 ;;
esac

# BQCA-ACTIVE-CENTRAL-POLICY:BEGIN
# Resolve the active authority through bqca-active-policy-listener.sh before
# every quantum DESIGN or CODE decision. Never hardcode a policy version or
# duplicate the full policy here. qiskit-design-policy-check.py and
# qiskit-code-policy-check.py reload the active registry/policy/contract on
# every invocation and create same-directory policy-compliance reports.
# Do not report completion until the active-policy report exists.
# BQCA-ACTIVE-CENTRAL-POLICY:END
