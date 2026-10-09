#!/usr/bin/env bash
set -Eeuo pipefail

# BQCA v50 runtime permission guard.
# This utility repairs only active BQCA executable components. It never reads or
# modifies .env, workload artifacts, the home Qiskit environment, or account JSON.
#
# BQCA-ACTIVE-CENTRAL-POLICY:BEGIN
# Follow the active central policy resolved from
# .bob/BQCA-ACTIVE-POLICY-REGISTRY.json. This guard does not define or replace
# policy behavior; it only restores the safe executable permissions required by
# the active-policy assurance and existing BQCA runtime flow.
# BQCA-ACTIVE-CENTRAL-POLICY:END

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
BOB_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
BQCA_ROOT="$(cd "$BOB_ROOT/.." && pwd -P)"
RUNTIME_DIR="$BOB_ROOT/runtime"
LOG_FILE="$RUNTIME_DIR/bqca-v50-permission-guard.log"
COMMAND="${1:-check}"
QUIET=0
shift || true

while (($#)); do
  case "$1" in
    --quiet) QUIET=1; shift ;;
    -h|--help)
      cat <<'USAGE'
BQCA v50 permission guard

Usage:
  bqca-permission-guard.sh check [--quiet]
  bqca-permission-guard.sh repair [--quiet]
  bqca-permission-guard.sh report
USAGE
      exit 0
      ;;
    *) printf '[BQCA v50][ERROR] Unknown permission-guard option: %s\n' "$1" >&2; exit 2 ;;
  esac
done

case "$COMMAND" in
  check|repair|report) ;;
  *) printf '[BQCA v50][ERROR] Unknown permission-guard command: %s\n' "$COMMAND" >&2; exit 2 ;;
esac

critical=(
  ".bob/quantum-tools/bqca-active-policy-listener.sh"
  ".bob/quantum-tools/bqca_active_policy.py"
  ".bob/quantum-tools/bqca-dynamic-validator.py"
  ".bob/quantum-tools/qiskit-design-policy-check.py"
  ".bob/quantum-tools/qiskit-code-policy-check.py"
  ".bob/quantum-tools/bqca-policy-compliance-watcher.py"
  ".bob/quantum-tools/bqca-policy-compliance.sh"
  ".bob/quantum-tools/bqca-policy-doctor.sh"
  ".bob/quantum-tools/bqca-policy-doctor.py"
  ".bob/quantum-tools/qiskit-connector.sh"
  "xLaunchpad.sh"
)

optional_root=(
  "bob-auth.sh"
  "bob-shell.sh"
  "bob-version.sh"
  "tls-control.sh"
  "xdg.sh"
  "sdlc.sh"
  "bob-filename-version-sync.sh"
)

mkdir -p "$RUNTIME_DIR"
chmod 700 "$RUNTIME_DIR" 2>/dev/null || true

mode_of() { stat -c '%a' "$1"; }
is_world_writable() {
  local decimal
  decimal=$((8#$(mode_of "$1")))
  (( decimal & 0002 ))
}
is_owner_executable() {
  local decimal
  decimal=$((8#$(mode_of "$1")))
  (( decimal & 0100 ))
}

changed=0
failures=0
issues=()

check_one() {
  local relative="$1" path mode
  path="$BQCA_ROOT/$relative"
  if [[ ! -f "$path" ]]; then
    issues+=("missing: $relative")
    failures=$((failures + 1))
    return
  fi
  mode="$(mode_of "$path")"
  if ! is_owner_executable "$path"; then
    issues+=("not executable: $relative ($mode)")
    failures=$((failures + 1))
  fi
  if is_world_writable "$path"; then
    issues+=("world-writable: $relative ($mode)")
    failures=$((failures + 1))
  fi
}

repair_one() {
  local relative="$1" path old_mode
  path="$BQCA_ROOT/$relative"
  if [[ ! -f "$path" ]]; then
    issues+=("missing: $relative")
    failures=$((failures + 1))
    return
  fi
  old_mode="$(mode_of "$path")"
  if [[ "$old_mode" != "755" ]]; then
    if chmod 755 "$path"; then
      printf '%s\t%s\t%s\t755\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$relative" "$old_mode" >> "$LOG_FILE"
      changed=$((changed + 1))
    else
      issues+=("chmod failed: $relative ($old_mode)")
      failures=$((failures + 1))
    fi
  fi
}

if [[ "$COMMAND" == "repair" ]]; then
  for relative in "${critical[@]}"; do repair_one "$relative"; done
  for relative in "${optional_root[@]}"; do
    [[ -f "$BQCA_ROOT/$relative" ]] && repair_one "$relative"
  done
  while IFS= read -r -d '' launcher; do
    repair_one "${launcher#$BQCA_ROOT/}"
  done < <(find "$BQCA_ROOT" -maxdepth 1 -type f -name 'bob-quantum-v*.sh' -print0)
  chmod 600 "$LOG_FILE" 2>/dev/null || true
fi

# Always re-check the exact doctor-critical set after an attempted repair.
failures=0
issues=()
for relative in "${critical[@]}"; do check_one "$relative"; done

if [[ "$COMMAND" == "report" ]]; then
  printf '%s\n' '========================================================================================'
  printf '%s\n' 'BQCA v50 CRITICAL PERMISSION ASSURANCE REPORT'
  printf '%s\n' '========================================================================================'
  printf 'Appliance root           : %s\n' "$BQCA_ROOT"
  printf 'Critical components      : %s\n' "${#critical[@]}"
  printf 'Components changed       : %s\n' "$changed"
  printf 'Permission issues        : %s\n' "$failures"
  printf '%s\n' '----------------------------------------------------------------------------------------'
  if ((${#issues[@]})); then
    printf '%s\n' 'ISSUES'
    printf -- '- %s\n' "${issues[@]}"
  else
    printf '%s\n' 'All critical components are owner-executable and not world-writable.'
  fi
  printf '%s\n' '----------------------------------------------------------------------------------------'
  if ((failures == 0)); then
    printf '%s\n' 'FINAL PERMISSION STATUS  : PASS'
  else
    printf '%s\n' 'FINAL PERMISSION STATUS  : FAIL'
  fi
  printf '%s\n' '========================================================================================'
fi

if ((failures)); then
  if ((QUIET == 0)) && [[ "$COMMAND" != "report" ]]; then
    printf '[BQCA v50][ERROR] Critical permission assurance failed with %s issue(s).\n' "$failures" >&2
    printf '[BQCA v50][ERROR] %s\n' "${issues[@]}" >&2
  fi
  exit 1
fi

if ((QUIET == 0)) && [[ "$COMMAND" != "report" ]]; then
  printf 'BQCA_V50_PERMISSION_ASSURANCE=PASS changed=%s critical=%s\n' "$changed" "${#critical[@]}"
fi
