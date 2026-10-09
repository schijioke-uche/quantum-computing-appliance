#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
BOB_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
BQCA_ROOT="$(cd "$BOB_ROOT/.." && pwd -P)"
CONFIG_TOOL="$SCRIPT_DIR/qiskit-configuration.sh"
ENV_TOOL="$SCRIPT_DIR/qiskit-v2x-environment.sh"
NOTEBOOK_TOOL="$SCRIPT_DIR/notebook-generator.sh"
SECRET_SCANNER="$SCRIPT_DIR/bqca-secret-scan.py"
ORCHESTRATOR="$SCRIPT_DIR/bqca-policy-orchestrator.sh"

info() { printf '[BQCA v47][DIRECT] %s\n' "$*"; }
warn() { printf '[BQCA v47][DIRECT][WARN] %s\n' "$*" >&2; }
fail() { printf '[BQCA v47][DIRECT][ERROR] %s\n' "$*" >&2; exit 2; }

usage() {
  cat <<'USAGE'
BQCA v47 direct execution

Usage:
  bqca-direct-execution.sh run <file.py> [arguments...]
  bqca-direct-execution.sh run-notebook <file.ipynb>
  bqca-direct-execution.sh formal-run <file.py|file.ipynb> [arguments...]
  bqca-direct-execution.sh <file.py> [arguments...]

Direct execution is the default for development, testing, interactive
exploration, debugging, and quick experiments. Output is streamed to the
terminal and captured to both:
  <source-stem>-result-output.txt
  output.txt

The orchestrator is optional and is used only by formal-run for formal
compliance documentation, production deployment, or audit requirements.
USAGE
}

absolute_path() {
  python3 - "$1" <<'PY'
import pathlib, sys
print(pathlib.Path(sys.argv[1]).expanduser().resolve())
PY
}

marker_value() {
  local key="$1" file="$2"
  python3 - "$key" "$file" <<'PY'
import pathlib, sys
key = sys.argv[1] + "="
value = ""
for line in pathlib.Path(sys.argv[2]).read_text(encoding="utf-8", errors="replace").splitlines():
    if line.startswith(key):
        value = line[len(key):].strip()
print(value)
PY
}

run_direct() {
  local kind="$1" source="$2"
  shift 2
  local source_abs source_dir stem canonical mirror raw temporary_report
  local python_bin start_iso end_iso start_epoch end_epoch duration status
  local target plan backend job_id result fallback contract_valid execution_success issues
  local notebook_status="NOT APPLICABLE" secret_status="PASS" final_status

  source_abs="$(absolute_path "$source")"
  [[ -f "$source_abs" ]] || fail "Artifact not found: $source_abs"
  source_dir="$(dirname "$source_abs")"
  stem="$(basename "$source_abs")"
  stem="${stem%.*}"
  canonical="$source_dir/${stem}-result-output.txt"
  mirror="$source_dir/output.txt"
  raw="$(mktemp "$source_dir/.${stem}.v47-output.XXXXXX")"
  temporary_report="$(mktemp "$source_dir/.${stem}.v47-report.XXXXXX")"

  if [[ "${BQCA_V47_TEST_MODE:-0}" == "1" ]]; then
    python_bin="${BQCA_V47_PYTHON_BIN:-$(command -v python3)}"
  else
    [[ -x "$CONFIG_TOOL" ]] || fail "Qiskit configuration tool is missing: $CONFIG_TOOL"
    [[ -x "$ENV_TOOL" ]] || fail "Qiskit environment tool is missing: $ENV_TOOL"
    "$CONFIG_TOOL" configure --project-root "$BQCA_ROOT" --quiet
    if ! "$ENV_TOOL" check --quiet >/dev/null 2>&1; then
      info "Preparing the authorized home Qiskit environment"
      "$ENV_TOOL" ensure --quiet
    fi
    python_bin="$HOME/qiskit-v2x-env/bin/python"
  fi
  [[ -x "$python_bin" ]] || fail "Authorized Python is unavailable: $python_bin"

  if [[ "$kind" == "python" ]]; then
    "$python_bin" -m py_compile "$source_abs"
  fi

  start_iso="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  start_epoch="$(date +%s)"
  info "Executing: $source_abs"
  info "Live output is displayed and captured"

  set +e
  if [[ "$kind" == "python" ]]; then
    "$python_bin" -u "$source_abs" "$@" 2>&1 | tee "$raw"
    status=${PIPESTATUS[0]}
  else
    "$python_bin" -m jupyter nbconvert --to notebook --execute --inplace "$source_abs" 2>&1 | tee "$raw"
    status=${PIPESTATUS[0]}
  fi
  set -e

  end_iso="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  end_epoch="$(date +%s)"
  duration=$((end_epoch - start_epoch))

  target="$(marker_value BQCA_EXECUTION_TARGET "$raw")"
  plan="$(marker_value BQCA_PLAN "$raw")"
  backend="$(marker_value BQCA_BACKEND "$raw")"
  job_id="$(marker_value BQCA_JOB_ID "$raw")"
  result="$(marker_value BQCA_RESULT "$raw")"
  fallback="$(marker_value BQCA_FALLBACK_REASON "$raw")"
  target="${target:-UNKNOWN}"
  plan="${plan:-NOT REPORTED}"
  backend="${backend:-NOT REPORTED}"
  result="${result:-NOT REPORTED}"
  fallback="${fallback:-NONE}"
  job_id="${job_id:-NOT REPORTED}"

  execution_success="NO"
  ((status == 0)) && execution_success="YES"
  contract_valid="YES"
  issues="NONE"

  if [[ "$target" == "REAL_QPU" && "$job_id" == "NOT REPORTED" ]]; then
    contract_valid="NO"
    issues="REAL_QPU execution did not report BQCA_JOB_ID"
  fi
  if [[ "$target" == "UNKNOWN" ]]; then
    contract_valid="NO"
    issues="${issues/NONE/} missing BQCA_EXECUTION_TARGET"
  fi
  if [[ "$result" == "NOT REPORTED" ]]; then
    contract_valid="NO"
    issues="${issues/NONE/} missing BQCA_RESULT"
  fi
  if ((status != 0)); then
    contract_valid="NO"
    issues="${issues/NONE/} process exit status $status"
  fi
  issues="${issues# }"
  [[ -n "$issues" ]] || issues="NONE"

  if [[ "$kind" == "python" && -x "$NOTEBOOK_TOOL" ]]; then
    if "$NOTEBOOK_TOOL" --source "$source_abs" --force >/dev/null 2>&1 && \
       "$NOTEBOOK_TOOL" --validate "${source_abs%.py}.ipynb" --against-source "$source_abs" >/dev/null 2>&1; then
      notebook_status="PASS"
    else
      notebook_status="FAIL"
      contract_valid="NO"
      issues="${issues/NONE/} notebook synchronization failed"
      issues="${issues# }"
    fi
  fi

  {
    if [[ "$target" == "REAL_QPU" ]]; then
      printf 'JOB ID: %s\n' "$job_id"
    fi
    printf '%s\n' '========================================================================================'
    printf '%s\n' 'BQCA v47 DIRECT QUANTUM EXECUTION RESULT OUTPUT'
    printf '%s\n' '========================================================================================'
    printf 'Execution successful    : %s\n' "$execution_success"
    printf 'Result contract valid   : %s\n' "$contract_valid"
    printf 'Execution target        : %s\n' "$target"
    printf 'Source artifact         : %s\n' "$source_abs"
    printf 'Result output           : %s\n' "$canonical"
    printf 'Output mirror           : %s\n' "$mirror"
    printf 'Started                 : %s\n' "$start_iso"
    printf 'Completed               : %s\n' "$end_iso"
    printf 'Duration seconds        : %s\n' "$duration"
    printf 'Exit status             : %s\n' "$status"
    printf 'Plan                    : %s\n' "$plan"
    printf 'Backend                 : %s\n' "$backend"
    printf 'Job ID                  : %s\n' "$job_id"
    printf 'Fallback reason         : %s\n' "$fallback"
    printf 'Notebook synchronization: %s\n' "$notebook_status"
    printf '%s\n' '----------------------------------------------------------------------------------------'
    printf '%s\n' 'COMPLETE TERMINAL OUTPUT (STDOUT + STDERR)'
    printf '%s\n' '----------------------------------------------------------------------------------------'
    cat "$raw"
    printf '%s\n' '----------------------------------------------------------------------------------------'
    printf '%s\n' 'RESULT SUMMARY'
    printf '%s\n' '----------------------------------------------------------------------------------------'
    printf 'Execution successful    : %s\n' "$execution_success"
    printf 'Result contract valid   : %s\n' "$contract_valid"
    printf 'Final execution target  : %s\n' "$target"
    printf 'Real-QPU job ID         : %s\n' "$job_id"
    printf 'Backend                 : %s\n' "$backend"
    printf 'Plan                    : %s\n' "$plan"
    printf 'Reported result         : %s\n' "$result"
    printf 'Process exit status     : %s\n' "$status"
    printf 'Completion date/time    : %s\n' "$end_iso"
    printf 'Total duration          : %s seconds\n' "$duration"
    printf 'Source artifact         : %s\n' "$source_abs"
    printf 'Result output           : %s\n' "$canonical"
    printf 'Policy/Execution issue(s): %s\n' "$issues"
    printf '%s\n' '========================================================================================'
  } > "$temporary_report"

  if [[ -x "$SECRET_SCANNER" ]]; then
    if ! python3 "$SECRET_SCANNER" --use-env "$temporary_report" >/dev/null 2>&1; then
      secret_status="FAIL"
      contract_valid="NO"
      warn "The result report failed the credential-leak scan"
    fi
  fi

  # If the secret scan changed compliance, update the visible summary before
  # publishing the final report.
  if [[ "$secret_status" == "FAIL" ]]; then
    python3 - "$temporary_report" <<'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding="utf-8", errors="replace")
text = text.replace("Result contract valid   : YES", "Result contract valid   : NO")
text = text.replace("Policy/Execution issue(s): NONE", "Policy/Execution issue(s): credential-leak scan failed")
path.write_text(text, encoding="utf-8")
PY
  fi

  mv "$temporary_report" "$canonical"
  cp "$canonical" "$mirror"
  chmod 644 "$canonical" "$mirror"
  rm -f "$raw"

  printf '\n'
  info "Execution complete: status=$status contract=$contract_valid"
  info "Canonical result: $canonical"
  info "Output mirror: $mirror"

  final_status="$status"
  if ((final_status == 0)) && [[ "$contract_valid" != "YES" || "$secret_status" != "PASS" ]]; then
    final_status=4
  fi
  return "$final_status"
}

command_name="${1:-}"
[[ -n "$command_name" ]] || { usage; exit 2; }
case "$command_name" in
  run)
    shift
    (($# >= 1)) || { usage >&2; exit 2; }
    source="$1"; shift
    run_direct python "$source" "$@"
    ;;
  run-notebook)
    shift
    (($# == 1)) || { usage >&2; exit 2; }
    run_direct notebook "$1"
    ;;
  formal-run)
    shift
    (($# >= 1)) || { usage >&2; exit 2; }
    [[ -x "$ORCHESTRATOR" ]] || fail "Formal orchestrator is missing: $ORCHESTRATOR"
    BQCA_V47_FORMAL=1 exec "$ORCHESTRATOR" execute "$@"
    ;;
  *.py)
    source="$1"; shift
    run_direct python "$source" "$@"
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
# The sole active BQCA policy is .bob/BQCA-PRODUCTION-POLICY.md (v47).
# Direct execution with live terminal output and dual result capture is the
# default. The orchestrator is optional and reserved for formal compliance,
# production-deployment evidence, and audit validation. Historical policies
# are audit-only and must not drive runtime decisions.
# BQCA-CANONICAL-PRODUCTION-POLICY-v47:END
