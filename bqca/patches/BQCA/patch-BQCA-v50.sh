#!/usr/bin/env bash
set -Eeuo pipefail

#===============================================================================
# IBM Bob Quantum Computing Agent (BQCA)
# Critical Runtime Permission Assurance Patch v50
# File: patch-BQCA-v50.sh
# Author: Dr. Jeffrey Chijioke-Uche, IBM Computer Scientist
#
# Purpose:
#   Repair and continuously prevent the permission drift reported after the
#   IBM Bob Shell upgrade from v1.0.6 to v2.0.0:
#
#     BQCA ACTIVE CENTRAL POLICY ASSURANCE REPORT
#     - permission errors in 11 critical component(s)
#
#   The active-policy doctor requires its critical shell/Python components to
#   be executable by the appliance owner and not world-writable. This patch:
#
#   1. Repairs the exact 11 active-policy components checked by the current
#      BQCA policy doctor.
#   2. Repairs the root BQCA runtime launchers and support scripts when present.
#   3. Installs a small permission guard that runs automatically on every
#      xLaunchpad.sh execution, after BQCA-49 filename/version synchronization
#      and before active-policy assurance.
#   4. Preserves the active BQCA v48 policy, validators, modes, rules, skills,
#      tools, design artifacts, code artifacts, and normal appliance flow.
#
# Standalone BQCA patch placement:
#   <BQCA-root>/patches/BQCA/patch-BQCA-v50.sh
#
# Protected assets:
#   This patch does not read, copy, back up, modify, chmod, remove, or restore:
#     - <BQCA-root>/.env
#     - <BQCA-root>/bob-quantum-designs/
#     - <BQCA-root>/bob-quantum-store/
#     - $HOME/qiskit-v2x-env
#     - $HOME/.qiskit/qiskit-ibm.json
#===============================================================================

PATCH_ID="BQCA-v50"
PATCH_FILE_NAME="patch-BQCA-v50.sh"
MARKER="BQCA-CRITICAL-PERMISSION-GUARD-v50"
GUARD_BASENAME="bqca-permission-guard.sh"
TIMESTAMP="$(date +%Y%m%d%H%M%S)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
TARGET_OVERRIDE=""
DRY_RUN=0
VALIDATE_ONLY=0
ROLLBACK_DIR=""

info() { printf '[BQCA v50][INFO] %s\n' "$*"; }
warn() { printf '[BQCA v50][WARN] %s\n' "$*" >&2; }
fail() { printf '[BQCA v50][ERROR] %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'USAGE'
BQCA Critical Runtime Permission Assurance Patch v50

Usage:
  ./patch-BQCA-v50.sh [options]

Options:
  --target <path>        Explicit BQCA appliance root.
  --dry-run              Display the repair plan without changing files.
  --validate-only        Validate the installed v50 permission assurance.
  --rollback <backup>    Restore a timestamped v50 backup directory.
  -h, --help             Show this help.

Expected placement:
  <BQCA-root>/patches/BQCA/patch-BQCA-v50.sh

The project-root .env, workload stores, home Qiskit environment, and Qiskit
account JSON are never touched by this patch.
USAGE
}

while (($#)); do
  case "$1" in
    --target)
      (($# >= 2)) || fail "--target requires a path"
      TARGET_OVERRIDE="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --validate-only)
      VALIDATE_ONLY=1
      shift
      ;;
    --rollback)
      (($# >= 2)) || fail "--rollback requires a backup directory"
      ROLLBACK_DIR="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown option: $1"
      ;;
  esac
done

for command_name in bash chmod cp date dirname find grep head mkdir mktemp mv python3 rm stat tail; do
  command -v "$command_name" >/dev/null 2>&1 || fail "Required command not found: $command_name"
done

launcher_exists() {
  local candidate="$1"
  compgen -G "$candidate/bob-quantum-v*.sh" >/dev/null 2>&1
}

is_bqca_root() {
  local candidate="$1"
  [[ -d "$candidate/.bob" ]] || return 1
  [[ -f "$candidate/.bob/custom_modes.yaml" ]] || return 1
  [[ -d "$candidate/.bob/skills" ]] || return 1
  [[ -d "$candidate/.bob/quantum-tools" ]] || return 1
  [[ -f "$candidate/xLaunchpad.sh" ]] || return 1
  [[ -d "$candidate/bob-quantum-store" ]] || return 1
  launcher_exists "$candidate"
}

resolve_bqca_root() {
  local candidate dir

  if [[ -n "$TARGET_OVERRIDE" ]]; then
    candidate="$(cd "$TARGET_OVERRIDE" 2>/dev/null && pwd -P || true)"
    [[ -n "$candidate" ]] || fail "Target path does not exist: $TARGET_OVERRIDE"
    is_bqca_root "$candidate" || fail "Target is not a valid BQCA root: $candidate"
    printf '%s\n' "$candidate"
    return 0
  fi

  candidate="$(pwd -P)"
  if is_bqca_root "$candidate"; then
    printf '%s\n' "$candidate"
    return 0
  fi

  dir="$SCRIPT_DIR"
  while [[ "$dir" != "/" ]]; do
    if is_bqca_root "$dir"; then
      printf '%s\n' "$dir"
      return 0
    fi
    if is_bqca_root "$dir/quantum-computing-agent"; then
      printf '%s\n' "$dir/quantum-computing-agent"
      return 0
    fi
    dir="$(dirname "$dir")"
  done

  fail "Unable to locate the BQCA root. Use --target <path>."
}

BQCA_ROOT="$(resolve_bqca_root)"
BOB_ROOT="$BQCA_ROOT/.bob"
TOOLS_DIR="$BOB_ROOT/quantum-tools"
RUNTIME_DIR="$BOB_ROOT/runtime"
XLAUNCHPAD="$BQCA_ROOT/xLaunchpad.sh"
GUARD="$TOOLS_DIR/$GUARD_BASENAME"
REGISTRY="$BOB_ROOT/BQCA-ACTIVE-POLICY-REGISTRY.json"
BACKUP_ROOT="$BOB_ROOT/patch-backups"
BACKUP_DIR="$BACKUP_ROOT/${PATCH_ID}.${TIMESTAMP}"
PATCH_RECORD_DIR="$BOB_ROOT/patches-applied"
PATCH_RECORD_FILE="$PATCH_RECORD_DIR/${PATCH_ID}.txt"

# These are the exact 11 components checked by the v48 active-policy doctor.
CRITICAL_RELATIVE_PATHS=(
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

# Root operational scripts are normalized when present. They are not part of
# the doctor's 11-item error count, but they are required for a reliable launch
# after Bob-version filename synchronization.
ROOT_OPERATIONAL_BASENAMES=(
  "bob-auth.sh"
  "bob-shell.sh"
  "bob-version.sh"
  "tls-control.sh"
  "xdg.sh"
  "sdlc.sh"
  "bob-filename-version-sync.sh"
)

preflight_critical_files() {
  local relative path failures=0
  for relative in "${CRITICAL_RELATIVE_PATHS[@]}"; do
    path="$BQCA_ROOT/$relative"
    if [[ ! -f "$path" ]]; then
      warn "Required active-policy component is missing: $path"
      failures=$((failures + 1))
    fi
  done
  ((failures == 0)) || fail "Cannot repair permissions because $failures critical component(s) are missing."
}

backup_file() {
  local source="$1" relative destination
  [[ -e "$source" ]] || return 0
  [[ "$source" != "$BQCA_ROOT/.env" ]] || return 0
  case "$source" in
    "$BQCA_ROOT/bob-quantum-designs"/*|"$BQCA_ROOT/bob-quantum-store"/*)
      return 0
      ;;
  esac
  relative="${source#$BQCA_ROOT/}"
  destination="$BACKUP_DIR/$relative"
  mkdir -p "$(dirname "$destination")"
  cp -a "$source" "$destination"
}

record_mode() {
  local path="$1" relative mode
  [[ -e "$path" ]] || return 0
  relative="${path#$BQCA_ROOT/}"
  mode="$(stat -c '%a' "$path")"
  printf '%s\t%s\n' "$mode" "$relative" >> "$BACKUP_DIR/original-modes.tsv"
}

create_backup() {
  local relative path basename launcher
  mkdir -p "$BACKUP_DIR" "$PATCH_RECORD_DIR"
  : > "$BACKUP_DIR/original-modes.tsv"

  backup_file "$XLAUNCHPAD"
  record_mode "$XLAUNCHPAD"

  backup_file "$GUARD"
  record_mode "$GUARD"
  [[ -e "$GUARD" ]] || : > "$BACKUP_DIR/guard-was-absent"

  backup_file "$REGISTRY"
  record_mode "$REGISTRY"
  [[ -e "$REGISTRY" ]] || : > "$BACKUP_DIR/registry-was-absent"

  backup_file "$PATCH_RECORD_FILE"
  record_mode "$PATCH_RECORD_FILE"
  [[ -e "$PATCH_RECORD_FILE" ]] || : > "$BACKUP_DIR/patch-record-was-absent"

  for relative in "${CRITICAL_RELATIVE_PATHS[@]}"; do
    path="$BQCA_ROOT/$relative"
    backup_file "$path"
    record_mode "$path"
  done

  for basename in "${ROOT_OPERATIONAL_BASENAMES[@]}"; do
    path="$BQCA_ROOT/$basename"
    [[ -e "$path" ]] || continue
    backup_file "$path"
    record_mode "$path"
  done

  while IFS= read -r -d '' launcher; do
    backup_file "$launcher"
    record_mode "$launcher"
  done < <(find "$BQCA_ROOT" -maxdepth 1 -type f -name 'bob-quantum-v*.sh' -print0)

  cat > "$BACKUP_DIR/BQCA-v50-backup-manifest.txt" <<MANIFEST
Patch: $PATCH_ID
Created: $(date -u '+%Y-%m-%dT%H:%M:%SZ')
Appliance root: $BQCA_ROOT
Launcher marker: $MARKER
Critical active-policy components: ${#CRITICAL_RELATIVE_PATHS[@]}
Protected project-root file excluded: .env
Protected workload directories excluded: bob-quantum-designs and bob-quantum-store
Protected home assets excluded: qiskit-v2x-env and .qiskit/qiskit-ibm.json
Restore with:
  $PATCH_FILE_NAME --target "$BQCA_ROOT" --rollback "$BACKUP_DIR"
MANIFEST
}

restore_backup() {
  local backup="$1" backup_abs source relative destination
  backup_abs="$(cd "$backup" 2>/dev/null && pwd -P || true)"
  [[ -n "$backup_abs" ]] || fail "Rollback directory not found: $backup"
  [[ -f "$backup_abs/BQCA-v50-backup-manifest.txt" ]] || fail "Not a BQCA v50 backup: $backup_abs"

  info "Restoring BQCA v50 backup: $backup_abs"

  while IFS= read -r -d '' source; do
    relative="${source#$backup_abs/}"
    case "$relative" in
      BQCA-v50-backup-manifest.txt|original-modes.tsv|guard-was-absent|registry-was-absent|patch-record-was-absent)
        continue
        ;;
    esac
    destination="$BQCA_ROOT/$relative"
    mkdir -p "$(dirname "$destination")"
    cp -a "$source" "$destination"
  done < <(find "$backup_abs" -mindepth 1 -type f -print0)

  if [[ -f "$backup_abs/guard-was-absent" ]]; then
    rm -f "$GUARD"
  fi
  if [[ -f "$backup_abs/registry-was-absent" ]]; then
    rm -f "$REGISTRY"
  fi
  if [[ -f "$backup_abs/patch-record-was-absent" ]]; then
    rm -f "$PATCH_RECORD_FILE"
  fi

  info "Rollback complete. Protected assets were not touched."
}

if [[ -n "$ROLLBACK_DIR" ]]; then
  restore_backup "$ROLLBACK_DIR"
  exit 0
fi

info "Resolved BQCA root: $BQCA_ROOT"
info "Patch identity: $PATCH_ID"
info "Repair target: the 11 critical active-policy components plus root runtime scripts"
info "Protected assets: .env, workload stores, home Qiskit environment, and account JSON"

preflight_critical_files

print_permission_plan() {
  local relative path mode basename launcher
  printf '%-5s  %s\n' "MODE" "PATH"
  printf '%-5s  %s\n' "-----" "----"
  for relative in "${CRITICAL_RELATIVE_PATHS[@]}"; do
    path="$BQCA_ROOT/$relative"
    mode="$(stat -c '%a' "$path")"
    printf '%-5s  %s\n' "$mode" "$relative"
  done
  for basename in "${ROOT_OPERATIONAL_BASENAMES[@]}"; do
    path="$BQCA_ROOT/$basename"
    [[ -f "$path" ]] || continue
    mode="$(stat -c '%a' "$path")"
    printf '%-5s  %s\n' "$mode" "$basename"
  done
  while IFS= read -r -d '' launcher; do
    mode="$(stat -c '%a' "$launcher")"
    printf '%-5s  %s\n' "$mode" "${launcher#$BQCA_ROOT/}"
  done < <(find "$BQCA_ROOT" -maxdepth 1 -type f -name 'bob-quantum-v*.sh' -print0)
}

if ((DRY_RUN)); then
  cat <<DRY
[BQCA v50][DRY-RUN] Planned changes:
  1. Install .bob/quantum-tools/$GUARD_BASENAME.
  2. Repair the exact 11 critical components checked by the active-policy doctor.
  3. Normalize present root runtime scripts and bob-quantum-v*.sh launchers to 0755.
  4. Insert one $MARKER block into xLaunchpad.sh.
  5. Run the guard after BQCA-49 filename synchronization and before policy assurance.
  6. Point registry repair_patch_path to patches/BQCA/$PATCH_FILE_NAME when the registry exists.
  7. Preserve the active v48 policy and all appliance intelligence.
  8. Leave .env, workload stores, the home Qiskit environment, and qiskit-ibm.json unchanged.

Current permission state:
DRY
  print_permission_plan
  exit 0
fi

write_permission_guard() {
  cat > "$GUARD" <<'GUARD'
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
GUARD
  chmod 755 "$GUARD"
}

patch_xlaunchpad() {
  local temporary
  temporary="$(mktemp)"

  python3 - "$XLAUNCHPAD" "$temporary" "$MARKER" <<'PY_PATCH'
from __future__ import annotations

import pathlib
import re
import sys

source = pathlib.Path(sys.argv[1])
destination = pathlib.Path(sys.argv[2])
marker = sys.argv[3]
text = source.read_text(encoding="utf-8")

pattern = re.compile(
    rf"(?ms)^# {re.escape(marker)}:BEGIN\n.*?^# {re.escape(marker)}:END\n?"
)
text = pattern.sub("", text)

block = f'''# {marker}:BEGIN
# Repair permission drift caused by Bob upgrades, archive extraction, or Git
# mode changes before active-policy assurance runs. BQCA-49 filename/version
# synchronization remains the first operational action when it is installed.
_BQCA50_ROOT="$(cd "$(dirname "${{BASH_SOURCE[0]}}")" && pwd -P)"
_BQCA50_PERMISSION_GUARD="${{_BQCA50_ROOT}}/.bob/quantum-tools/bqca-permission-guard.sh"
if [[ ! -f "${{_BQCA50_PERMISSION_GUARD}}" ]]; then
  printf '[BQCA v50][ERROR] Required permission guard is missing: %s\n' \
    "${{_BQCA50_PERMISSION_GUARD}}" >&2
  exit 1
fi
if ! bash "${{_BQCA50_PERMISSION_GUARD}}" repair --quiet; then
  printf '[BQCA v50][ERROR] Critical BQCA permissions could not be repaired. Run: %s report\n' \
    "${{_BQCA50_PERMISSION_GUARD}}" >&2
  exit 1
fi
unset _BQCA50_ROOT _BQCA50_PERMISSION_GUARD
# {marker}:END
'''

lines = text.splitlines(keepends=True)
insert_at = None

# Preserve Patch 49's explicit requirement that filename/version sync remains
# the first operational action. Install v50 immediately after it when present.
end_line = f"# BQCA-ROOT-FILENAME-VERSION-SYNC-49:END"
for index, line in enumerate(lines):
    if line.strip() == end_line:
        insert_at = index + 1
        break

if insert_at is None:
    for index, line in enumerate(lines):
        if line.strip() == "set -Eeuo pipefail":
            insert_at = index + 1
            break

if insert_at is None:
    raise SystemExit("Unable to locate a safe xLaunchpad insertion boundary")

lines.insert(insert_at, "\n" + block + "\n")
destination.write_text("".join(lines), encoding="utf-8")
PY_PATCH

  cp "$temporary" "$XLAUNCHPAD"
  rm -f "$temporary"
  chmod 755 "$XLAUNCHPAD"
}

update_registry() {
  [[ -f "$REGISTRY" ]] || return 0
  python3 - "$REGISTRY" <<'PY_REGISTRY'
from __future__ import annotations

import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["repair_patch_path"] = "patches/BQCA/patch-BQCA-v50.sh"
data["permission_guard_path"] = ".bob/quantum-tools/bqca-permission-guard.sh"
data["permission_guard_patch"] = "BQCA-v50"
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY_REGISTRY
  chmod 644 "$REGISTRY"
}

repair_permissions_now() {
  bash "$GUARD" repair --quiet
}

run_guard_smoke_test() {
  local test_root test_tools test_guard relative
  test_root="$(mktemp -d)"
  test_tools="$test_root/.bob/quantum-tools"
  mkdir -p "$test_tools"
  cp "$GUARD" "$test_tools/$GUARD_BASENAME"
  chmod 755 "$test_tools/$GUARD_BASENAME"

  # Create the exact critical paths with deliberately bad permission modes.
  for relative in "${CRITICAL_RELATIVE_PATHS[@]}"; do
    mkdir -p "$(dirname "$test_root/$relative")"
    if [[ "$relative" == *.py ]]; then
      printf '#!/usr/bin/env python3\nprint("ok")\n' > "$test_root/$relative"
      chmod 644 "$test_root/$relative"
    else
      printf '#!/usr/bin/env bash\nexit 0\n' > "$test_root/$relative"
      chmod 777 "$test_root/$relative"
    fi
  done

  bash "$test_tools/$GUARD_BASENAME" repair --quiet
  bash "$test_tools/$GUARD_BASENAME" check --quiet

  for relative in "${CRITICAL_RELATIVE_PATHS[@]}"; do
    [[ "$(stat -c '%a' "$test_root/$relative")" == "755" ]] || {
      rm -rf "$test_root"
      return 1
    }
  done
  rm -rf "$test_root"
}

validate_marker_order() {
  python3 - "$XLAUNCHPAD" "$MARKER" <<'PY_ORDER'
from __future__ import annotations

import pathlib
import sys

path = pathlib.Path(sys.argv[1])
marker = sys.argv[2]
text = path.read_text(encoding="utf-8")

begin = text.find(f"# {marker}:BEGIN")
end = text.find(f"# {marker}:END")
if begin < 0 or end < begin:
    raise SystemExit("v50 launcher marker is missing or malformed")

sync_end = text.find("# BQCA-ROOT-FILENAME-VERSION-SYNC-49:END")
if sync_end >= 0 and begin < sync_end:
    raise SystemExit("v50 permission guard runs before required BQCA-49 version synchronization")

assurance_candidates = [
    text.find("# BQCA-ACTIVE-POLICY-ASSURANCE:BEGIN"),
    text.find("bqca-policy-doctor.sh"),
]
assurance_positions = [value for value in assurance_candidates if value >= 0]
if assurance_positions and begin > min(assurance_positions):
    raise SystemExit("v50 permission guard does not run before active-policy assurance")
PY_ORDER
}

validate_installation() {
  local failures=0 relative path marker_count launcher basename mode doctor

  [[ -f "$GUARD" ]] || { warn "Missing permission guard: $GUARD"; failures=$((failures + 1)); }
  [[ -x "$GUARD" ]] || { warn "Permission guard is not executable: $GUARD"; failures=$((failures + 1)); }
  [[ -x "$XLAUNCHPAD" ]] || { warn "xLaunchpad.sh is not executable"; failures=$((failures + 1)); }

  bash -n "$GUARD" || failures=$((failures + 1))
  bash -n "$XLAUNCHPAD" || failures=$((failures + 1))

  marker_count="$(grep -c "^# $MARKER:BEGIN$" "$XLAUNCHPAD" || true)"
  [[ "$marker_count" -eq 1 ]] || { warn "xLaunchpad v50 marker count is $marker_count, expected 1"; failures=$((failures + 1)); }

  validate_marker_order || failures=$((failures + 1))
  bash "$GUARD" check --quiet || failures=$((failures + 1))

  for relative in "${CRITICAL_RELATIVE_PATHS[@]}"; do
    path="$BQCA_ROOT/$relative"
    [[ -f "$path" ]] || { warn "Critical component missing: $path"; failures=$((failures + 1)); continue; }
    mode="$(stat -c '%a' "$path")"
    [[ "$mode" == "755" ]] || { warn "Critical component mode is $mode, expected 755: $path"; failures=$((failures + 1)); }
    if [[ "$path" == *.sh ]]; then
      bash -n "$path" || failures=$((failures + 1))
    elif [[ "$path" == *.py ]]; then
      python3 - "$path" <<'PY_SYNTAX' || failures=$((failures + 1))
import ast, pathlib, sys
path = pathlib.Path(sys.argv[1])
ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
PY_SYNTAX
    fi
  done

  for basename in "${ROOT_OPERATIONAL_BASENAMES[@]}"; do
    path="$BQCA_ROOT/$basename"
    [[ -f "$path" ]] || continue
    mode="$(stat -c '%a' "$path")"
    [[ "$mode" == "755" ]] || { warn "Root runtime script mode is $mode, expected 755: $path"; failures=$((failures + 1)); }
    bash -n "$path" || failures=$((failures + 1))
  done

  while IFS= read -r -d '' launcher; do
    mode="$(stat -c '%a' "$launcher")"
    [[ "$mode" == "755" ]] || { warn "Versioned launcher mode is $mode, expected 755: $launcher"; failures=$((failures + 1)); }
    bash -n "$launcher" || failures=$((failures + 1))
  done < <(find "$BQCA_ROOT" -maxdepth 1 -type f -name 'bob-quantum-v*.sh' -print0)

  run_guard_smoke_test || { warn "Isolated permission-guard smoke test failed"; failures=$((failures + 1)); }

  doctor="$TOOLS_DIR/bqca-policy-doctor.sh"
  if [[ -x "$doctor" ]]; then
    if ! "$doctor" check --quiet; then
      warn "Active-policy doctor still reports a failure after the v50 permission repair"
      "$doctor" report >&2 || true
      failures=$((failures + 1))
    fi
  else
    warn "Policy doctor is missing or not executable: $doctor"
    failures=$((failures + 1))
  fi

  if ((failures)); then
    fail "v50 validation failed with $failures issue(s)."
  fi

  info "Validation passed: all 11 doctor-critical components are executable, non-world-writable, syntactically valid, and repaired before policy assurance."
}

if ((VALIDATE_ONLY)); then
  validate_installation
  exit 0
fi

create_backup
mkdir -p "$TOOLS_DIR" "$RUNTIME_DIR" "$PATCH_RECORD_DIR"
chmod 700 "$RUNTIME_DIR" 2>/dev/null || true
write_permission_guard
patch_xlaunchpad
update_registry
repair_permissions_now

cat > "$PATCH_RECORD_FILE" <<RECORD
Patch: $PATCH_ID
Applied: $(date -u '+%Y-%m-%dT%H:%M:%SZ')
Root: $BQCA_ROOT
Backup: $BACKUP_DIR
Behavior: repair and continuously enforce safe permissions for active-policy components
Critical components: ${#CRITICAL_RELATIVE_PATHS[@]}
Runtime guard: .bob/quantum-tools/$GUARD_BASENAME
Launcher marker: $MARKER
Active central policy content: unchanged
Protected assets: .env, workload stores, home Qiskit environment, and qiskit-ibm.json excluded
RECORD
chmod 644 "$PATCH_RECORD_FILE"

validate_installation

info "Patch $PATCH_ID applied successfully."
info "Backup: $BACKUP_DIR"
info "Runtime guard: .bob/quantum-tools/$GUARD_BASENAME"
info "The active v48 policy and protected assets were not changed."
