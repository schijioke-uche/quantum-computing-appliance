#!/usr/bin/env bash
set -Eeuo pipefail

#===============================================================================
# BQCA Production Repair Patch v30
# File: patch-BQCA.v30.sh
# Author: Dr. Jeffrey Chijioke-Uche, IBM Computer Scientist
#
# Purpose:
#   Repair the audited BQCA production appliance without changing .env.
#
# Repairs:
#   - Robustly locates the active BQCA appliance root.
#   - Creates a complete timestamped backup before modification.
#   - Repairs executable and data-file permissions while leaving .env untouched.
#   - Replaces silent host package mutation with explicit, opt-in XDG handling.
#   - Replaces the unpinned remote uv bootstrap with a local-only quality guard.
#   - Establishes one canonical v30 design/code/execution policy.
#   - Removes obsolete bob-quantum-codes routing references from active policy.
#   - Adds v30 precedence guidance to all custom Bob modes and active rule/skill
#     documents without deleting their domain intelligence.
#   - Repairs patch metadata, adds validation, idempotency, dry-run, and rollback.
#
# IMPORTANT:
#   This patch intentionally DOES NOT read, modify, copy, chmod, sanitize, or
#   remove the appliance .env file. The operator owns .env remediation.
#===============================================================================

PATCH_ID="BQCA.v30"
PATCH_FILE_NAME="patch-BQCA.v30.sh"
TIMESTAMP="$(date +%Y%m%d%H%M%S)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=0
VALIDATE_ONLY=0
ROLLBACK_DIR=""
TARGET_OVERRIDE=""

info() { printf '[BQCA v30][INFO] %s\n' "$*"; }
warn() { printf '[BQCA v30][WARN] %s\n' "$*" >&2; }
fail() { printf '[BQCA v30][ERROR] %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'USAGE'
BQCA Production Repair Patch v30

Usage:
  ./patch-BQCA.v30.sh [options]

Options:
  --target <path>        Explicit BQCA appliance root.
  --dry-run              Show the resolved target and validation plan only.
  --validate-only        Validate the current appliance without modifying it.
  --rollback <backup>    Restore a specific v30 backup directory.
  -h, --help             Show this help.

Expected placement:
  <BQCA-root>/patches/BQCA/patch-BQCA.v30.sh

The patch also supports execution from outside the appliance when --target is
provided. The appliance .env file is never modified.
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

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

for cmd in awk bash chmod cp date find grep mkdir mktemp python3 sed; do
  require_cmd "$cmd"
done

is_bqca_root() {
  local candidate="$1"
  [[ -d "$candidate" ]] || return 1
  [[ -d "$candidate/.bob" ]] || return 1
  [[ -f "$candidate/xLaunchpad.sh" ]] || return 1
  [[ -f "$candidate/bob-auth.sh" ]] || return 1
  compgen -G "$candidate/bob-quantum-v*.sh" >/dev/null 2>&1 || return 1
  return 0
}

resolve_bqca_root() {
  local candidate dir

  if [[ -n "$TARGET_OVERRIDE" ]]; then
    candidate="$(cd "$TARGET_OVERRIDE" 2>/dev/null && pwd || true)"
    [[ -n "$candidate" ]] || fail "Target path does not exist: $TARGET_OVERRIDE"
    is_bqca_root "$candidate" || fail "Target is not a valid BQCA root: $candidate"
    printf '%s\n' "$candidate"
    return 0
  fi

  # 1. Current directory.
  candidate="$(pwd)"
  if is_bqca_root "$candidate"; then
    printf '%s\n' "$candidate"
    return 0
  fi

  # 2. Walk upward from the patch location. This directly supports:
  #    <BQCA-root>/patches/BQCA/patch-BQCA.v30.sh
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
    if is_bqca_root "$dir/use-cases/quantum"; then
      printf '%s\n' "$dir/use-cases/quantum"
      return 0
    fi
    if is_bqca_root "$dir/use-case/quantum"; then
      printf '%s\n' "$dir/use-case/quantum"
      return 0
    fi
    dir="$(dirname "$dir")"
  done

  fail "Unable to locate the BQCA appliance root. Use --target <path>."
}

BQCA_ROOT="$(resolve_bqca_root)"
BOB_ROOT="$BQCA_ROOT/.bob"
BACKUP_ROOT="$BOB_ROOT/patch-backups"
BACKUP_DIR="$BACKUP_ROOT/${PATCH_ID}.${TIMESTAMP}"
PATCH_RECORD_DIR="$BOB_ROOT/patches-applied"
PATCH_RECORD_FILE="$PATCH_RECORD_DIR/${PATCH_ID}.txt"
CANONICAL_POLICY_FILE="$BOB_ROOT/BQCA-PRODUCTION-POLICY-v30.md"
QUALITY_GUARD="$BOB_ROOT/quantum-tools/qca-code-quality-guard.sh"

# Explicit invariant requested by the operator.
ENV_FILE="$BQCA_ROOT/.env"
ENV_BEFORE_HASH=""
if [[ -f "$ENV_FILE" ]] && command -v sha256sum >/dev/null 2>&1; then
  ENV_BEFORE_HASH="$(sha256sum "$ENV_FILE" | awk '{print $1}')"
fi

active_find() {
  find "$BQCA_ROOT" \
    -path "$BQCA_ROOT/.git" -prune -o \
    -path "$BQCA_ROOT/.bob/patch-backups" -prune -o \
    -path "$BQCA_ROOT/.bob/backups" -prune -o \
    -path "$BQCA_ROOT/.bob/.bob-errors" -prune -o \
    "$@"
}

backup_file() {
  local file="$1" rel destination
  [[ -e "$file" ]] || return 0
  [[ "$file" != "$ENV_FILE" ]] || return 0
  rel="${file#$BQCA_ROOT/}"
  destination="$BACKUP_DIR/$rel"
  mkdir -p "$(dirname "$destination")"
  cp -a "$file" "$destination"
}

backup_active_configuration() {
  mkdir -p "$BACKUP_DIR"

  while IFS= read -r -d '' file; do
    backup_file "$file"
  done < <(
    active_find \( \
      -type f \( -name '*.sh' -o -name '*.md' -o -name '*.yaml' -o -name '*.yml' \) \
      -o -type l \
    \) -print0
  )

  cat > "$BACKUP_DIR/BQCA-v30-backup-manifest.txt" <<MANIFEST
Patch: $PATCH_ID
Created: $(date -u '+%Y-%m-%dT%H:%M:%SZ')
Appliance root: $BQCA_ROOT
Environment file intentionally excluded: .env
Restore with:
  $PATCH_FILE_NAME --target "$BQCA_ROOT" --rollback "$BACKUP_DIR"
MANIFEST
}

restore_backup() {
  local backup="$1" backup_abs rel source destination
  backup_abs="$(cd "$backup" 2>/dev/null && pwd || true)"
  [[ -n "$backup_abs" ]] || fail "Rollback directory does not exist: $backup"
  [[ -f "$backup_abs/BQCA-v30-backup-manifest.txt" ]] || fail "Not a BQCA v30 backup: $backup_abs"

  info "Restoring backup: $backup_abs"
  while IFS= read -r -d '' source; do
    rel="${source#$backup_abs/}"
    [[ "$rel" != "BQCA-v30-backup-manifest.txt" ]] || continue
    [[ "$rel" != ".env" ]] || continue
    destination="$BQCA_ROOT/$rel"
    mkdir -p "$(dirname "$destination")"
    rm -rf "$destination"
    cp -a "$source" "$destination"
  done < <(find "$backup_abs" -mindepth 1 -type f -print0)

  info "Rollback restored. The .env file was not touched."
}

if [[ -n "$ROLLBACK_DIR" ]]; then
  restore_backup "$ROLLBACK_DIR"
  exit 0
fi

info "Resolved BQCA root: $BQCA_ROOT"
info "Patch identity: $PATCH_ID"
info "Environment policy: .env is excluded from every patch operation"

if ((DRY_RUN)); then
  cat <<DRY
[BQCA v30][DRY-RUN] Planned repairs:
  1. Back up active shell, YAML, Markdown, rule, skill, and tool files.
  2. Preserve .env byte-for-byte and permission-for-permission.
  3. Install the canonical v30 production policy.
  4. Add v30 policy precedence to active modes, rules, skills, and tools.
  5. Remove obsolete bob-quantum-codes routing references.
  6. Replace unsafe XDG and code-quality bootstrap behavior.
  7. Repair script/document permissions.
  8. Run shell, Python, YAML, routing, and safety validation.
DRY
  exit 0
fi

validate_shells() {
  local failures=0 file
  while IFS= read -r -d '' file; do
    if ! bash -n "$file"; then
      warn "Bash syntax validation failed: ${file#$BQCA_ROOT/}"
      failures=$((failures + 1))
    fi
  done < <(active_find -type f -name '*.sh' -print0)
  ((failures == 0)) || return 1
}

validate_python() {
  python3 - "$BQCA_ROOT" <<'PY'
from pathlib import Path
import ast
import sys

root = Path(sys.argv[1])
exclude = {'.git', 'patch-backups', 'backups', '__pycache__'}
failures = []
for path in root.rglob('*.py'):
    if any(part in exclude for part in path.parts):
        continue
    try:
        ast.parse(path.read_text(encoding='utf-8', errors='strict'), filename=str(path))
    except Exception as exc:
        failures.append(f"{path.relative_to(root)}: {exc}")
if failures:
    print("\n".join(failures), file=sys.stderr)
    raise SystemExit(1)
PY
}

validate_yaml() {
  local modes="$BOB_ROOT/custom_modes.yaml"
  [[ -f "$modes" ]] || return 0

  if python3 -c 'import yaml' >/dev/null 2>&1; then
    python3 - "$modes" <<'PY'
from pathlib import Path
import sys, yaml
path = Path(sys.argv[1])
data = yaml.safe_load(path.read_text(encoding='utf-8'))
if not isinstance(data, dict) or not isinstance(data.get('customModes'), list):
    raise SystemExit('custom_modes.yaml does not contain customModes list')
if not data['customModes']:
    raise SystemExit('custom_modes.yaml contains no modes')
PY
  else
    grep -Eq '^customModes:[[:space:]]*$' "$modes" || return 1
    grep -Eq '^[[:space:]]+- slug:[[:space:]]+' "$modes" || return 1
  fi
}

validate_no_obsolete_routing() {
  local hits
  hits="$(active_find -type f \( -name '*.md' -o -name '*.yaml' -o -name '*.yml' -o -name '*.sh' \) \
    ! -path "$BQCA_ROOT/patches/BQCA/patch-BQCA.v30.sh" \
    -exec grep -Il 'bob-quantum-codes' {} + 2>/dev/null || true)"
  if [[ -n "$hits" ]]; then
    printf '%s\n' "$hits" >&2
    return 1
  fi
}

validate_no_remote_bootstrap() {
  if [[ -f "$QUALITY_GUARD" ]] && grep -Eq 'astral\.sh/uv/install\.sh|curl[^|]*\|[[:space:]]*(ba)?sh' "$QUALITY_GUARD"; then
    return 1
  fi
}

validate_permissions() {
  local failures=0 file mode
  while IFS= read -r -d '' file; do
    mode="$(python3 - "$file" <<'PY'
import os, stat, sys
print(oct(stat.S_IMODE(os.stat(sys.argv[1]).st_mode))[2:])
PY
)"
    if [[ "$mode" != "755" ]]; then
      warn "Expected 0755: ${file#$BQCA_ROOT/} (found $mode)"
      failures=$((failures + 1))
    fi
  done < <(active_find -type f -name '*.sh' -print0)
  ((failures == 0)) || return 1
}

validate_env_untouched() {
  if [[ -n "$ENV_BEFORE_HASH" ]]; then
    local after
    after="$(sha256sum "$ENV_FILE" | awk '{print $1}')"
    [[ "$ENV_BEFORE_HASH" == "$after" ]] || return 1
  fi
}

run_validation() {
  local failed=0
  info "Validating Bash scripts"
  validate_shells || { warn "Shell validation failed"; failed=1; }

  info "Validating Python implementations"
  validate_python || { warn "Python validation failed"; failed=1; }

  info "Validating custom mode registry"
  validate_yaml || { warn "YAML validation failed"; failed=1; }

  info "Checking obsolete routing references"
  validate_no_obsolete_routing || { warn "Obsolete bob-quantum-codes routing remains"; failed=1; }

  info "Checking remote bootstrap removal"
  validate_no_remote_bootstrap || { warn "Unsafe remote installer pattern remains"; failed=1; }

  info "Checking shell permissions"
  validate_permissions || { warn "Shell permission validation failed"; failed=1; }

  info "Confirming .env remained unchanged"
  validate_env_untouched || { warn ".env changed unexpectedly"; failed=1; }

  ((failed == 0)) || return 1
}

if ((VALIDATE_ONLY)); then
  run_validation
  info "Validation completed successfully."
  exit 0
fi

backup_active_configuration
info "Backup created: $BACKUP_DIR"

write_canonical_policy() {
  mkdir -p "$BOB_ROOT"
  cat > "$CANONICAL_POLICY_FILE" <<'POLICY'
# BQCA Production Policy v30

<!-- BQCA-PRODUCTION-POLICY-v30-START -->

This policy is the authoritative appliance-wide policy for Bob Quantum Computing
Agent (BQCA). When older QCA/BQCA policy text conflicts with this document, this
v30 policy takes precedence.

## 1. User intent and operating behavior

BQCA must support quantum question answering, solution design, algorithm and
circuit implementation, simulator execution, real IBM Quantum backend planning
and execution, visualization, documentation, troubleshooting, and repair. BQCA
must not refuse an authorized design, code-generation, or execution request only
because an older appliance rule is more restrictive.

## 2. Canonical artifact routing

- Design and architecture documents belong only in:
  `bob-quantum-designs/<normalized-solution-name>/`
- Executable code, notebooks, result files, reports, visualizations, and generated
  implementation artifacts belong only in:
  `bob-quantum-store/<normalized-solution-name>/`
- Any legacy implementation directory is obsolete; use only `bob-quantum-store/`.
- A design request produces design artifacts. A code/implement/generate request
  produces implementation artifacts. A combined request may produce both.
- Create target directories before writing and verify every reported path exists.

## 3. Implementation requirements

For normal Python/Qiskit implementations, create a `.py` executable artifact and,
when useful or requested, a corresponding `.ipynb` notebook. Do not claim success
until the saved Python source passes syntax validation. Keep imports explicit,
paths deterministic, output directories safe, and messages clear.

## 4. Execution requirements

- Validate source before execution.
- Use an existing operator-managed Python/Qiskit environment when available.
- BQCA must not download or pipe remote installers into a shell.
- Dependency installation is opt-in and must be visible to the operator.
- Simulator and real-backend execution must clearly identify the selected path.
- Real IBM Quantum execution must use configured credentials without printing or
  copying secrets into generated artifacts.
- On failure, preserve diagnostics in a local log, repair when feasible, validate
  again, and retry at most once unless the user requests otherwise.

## 5. Security and governance

- Never expose credentials or secret values.
- Never modify `.env` unless the user explicitly requests that exact change.
- Do not silently install operating-system packages or invoke privilege elevation.
- Keep design and implementation assets reviewable and compatible with Git.
- Restrict generated outputs to the BQCA workspace unless explicitly authorized.

## 6. Quality and completion

BQCA may reason, design, create, write, modify, execute, troubleshoot, and repair
quantum solutions. Completion requires evidence: created paths, validation status,
execution status when requested, and concise result/artifact reporting.

<!-- BQCA-PRODUCTION-POLICY-v30-END -->
POLICY
  chmod 0644 "$CANONICAL_POLICY_FILE"
}

write_canonical_policy

# Replace the unsafe/non-deterministic quality guard with a local-only guard.
write_quality_guard() {
  mkdir -p "$(dirname "$QUALITY_GUARD")"
  cat > "$QUALITY_GUARD" <<'GUARD'
#!/usr/bin/env bash
set -Eeuo pipefail

# BQCA Code Quality Guard v30
# Local-only validation, notebook generation, dependency inspection, and execution.
# No remote installer is downloaded or piped to a shell.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BQCA_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LOG_FILE="${BQCA_CODE_QUALITY_LOG:-$BQCA_ROOT/.bob/qca-code-quality.log}"
VENV_PATH="${QISKIT_VENV_PATH:-$HOME/qiskit-v2x-env}"
ALLOW_INSTALL="${BQCA_ALLOW_DEPENDENCY_INSTALL:-0}"

mkdir -p "$(dirname "$LOG_FILE")"

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')" "$*" >> "$LOG_FILE" 2>/dev/null || true
}

usage() {
  cat <<'USAGE'
BQCA Code Quality Guard v30

Usage:
  qca-code-quality-guard.sh --ensure-venv
  qca-code-quality-guard.sh --validate <file.py>
  qca-code-quality-guard.sh --imports <file.py>
  qca-code-quality-guard.sh --notebook <file.py> [file.ipynb]
  qca-code-quality-guard.sh --prepare <file.py>
  qca-code-quality-guard.sh --execute <file.py>

Dependency installation is disabled by default. To explicitly allow local pip
installation, set BQCA_ALLOW_DEPENDENCY_INSTALL=1 before --prepare or --execute.
No remote bootstrap installer is used.
USAGE
}

resolve_python() {
  if [[ -x "$VENV_PATH/bin/python" ]]; then
    printf '%s\n' "$VENV_PATH/bin/python"
    return 0
  fi
  command -v python3 >/dev/null 2>&1 || return 1
  command -v python3
}

ensure_venv() {
  if [[ -x "$VENV_PATH/bin/python" ]]; then
    return 0
  fi
  [[ "$ALLOW_INSTALL" == "1" ]] || {
    printf '[BQCA] Python environment not found: %s\n' "$VENV_PATH" >&2
    printf '[BQCA] Create it explicitly or set BQCA_ALLOW_DEPENDENCY_INSTALL=1.\n' >&2
    return 1
  }
  command -v python3 >/dev/null 2>&1 || return 1
  log "Creating operator-approved virtual environment: $VENV_PATH"
  python3 -m venv "$VENV_PATH" >>"$LOG_FILE" 2>&1
}

validate_file() {
  local file="$1" python_bin
  [[ -f "$file" ]] || { printf '[BQCA] File not found: %s\n' "$file" >&2; return 1; }
  python_bin="$(resolve_python)" || { printf '[BQCA] python3 is unavailable\n' >&2; return 1; }
  "$python_bin" -m py_compile "$file" >>"$LOG_FILE" 2>&1
}

list_imports() {
  local file="$1"
  python3 - "$file" <<'PY'
from pathlib import Path
import ast, sys
path = Path(sys.argv[1])
tree = ast.parse(path.read_text(encoding='utf-8'), filename=str(path))
mods = set()
for node in ast.walk(tree):
    if isinstance(node, ast.Import):
        mods.update(alias.name.split('.')[0] for alias in node.names)
    elif isinstance(node, ast.ImportFrom) and node.module:
        mods.add(node.module.split('.')[0])
for name in sorted(mods):
    print(name)
PY
}

missing_imports() {
  local file="$1" python_bin
  python_bin="$(resolve_python)" || return 1
  while IFS= read -r module; do
    [[ -n "$module" ]] || continue
    if ! "$python_bin" - "$module" >/dev/null 2>&1 <<'PY'
import importlib.util, sys
raise SystemExit(0 if importlib.util.find_spec(sys.argv[1]) else 1)
PY
    then
      printf '%s\n' "$module"
    fi
  done < <(list_imports "$file")
}

package_for_module() {
  case "$1" in
    qiskit_aer) printf '%s\n' qiskit-aer ;;
    qiskit_algorithms) printf '%s\n' qiskit-algorithms ;;
    qiskit_connector) printf '%s\n' qiskit-connector ;;
    sklearn) printf '%s\n' scikit-learn ;;
    PIL) printf '%s\n' pillow ;;
    yaml) printf '%s\n' pyyaml ;;
    *) printf '%s\n' "$1" ;;
  esac
}

ensure_imports() {
  local file="$1" module package python_bin failures=0
  python_bin="$(resolve_python)" || return 1
  while IFS= read -r module; do
    [[ -n "$module" ]] || continue
    if [[ "$ALLOW_INSTALL" != "1" ]]; then
      printf '[BQCA] Missing Python module: %s\n' "$module" >&2
      failures=$((failures + 1))
      continue
    fi
    package="$(package_for_module "$module")"
    printf '[BQCA] Installing operator-approved dependency: %s\n' "$package"
    "$python_bin" -m pip install "$package" >>"$LOG_FILE" 2>&1 || failures=$((failures + 1))
  done < <(missing_imports "$file")
  ((failures == 0))
}

make_notebook() {
  local source="$1" output="${2:-${source%.py}.ipynb}"
  [[ -f "$source" ]] || return 1
  python3 - "$source" "$output" <<'PY'
from pathlib import Path
import json, sys
source = Path(sys.argv[1])
output = Path(sys.argv[2])
text = source.read_text(encoding='utf-8')
notebook = {
    "cells": [{"cell_type": "code", "execution_count": None, "metadata": {},
               "outputs": [], "source": text.splitlines(keepends=True)}],
    "metadata": {"kernelspec": {"display_name": "Python 3", "language": "python", "name": "python3"},
                 "language_info": {"name": "python", "version": "3"}},
    "nbformat": 4,
    "nbformat_minor": 5,
}
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(json.dumps(notebook, indent=2) + "\n", encoding='utf-8')
PY
  printf '%s\n' "$output"
}

prepare_file() {
  local file="$1"
  validate_file "$file"
  ensure_imports "$file"
}

execute_file() {
  local file="$1" python_bin
  prepare_file "$file"
  python_bin="$(resolve_python)"
  "$python_bin" "$file" 2>>"$LOG_FILE"
}

(($# >= 1)) || { usage; exit 2; }
case "$1" in
  --ensure-venv)
    ensure_venv
    ;;
  --validate)
    (($# == 2)) || { usage; exit 2; }
    validate_file "$2"
    ;;
  --imports)
    (($# == 2)) || { usage; exit 2; }
    list_imports "$2"
    ;;
  --notebook)
    (($# == 2 || $# == 3)) || { usage; exit 2; }
    make_notebook "$2" "${3:-${2%.py}.ipynb}"
    ;;
  --prepare)
    (($# == 2)) || { usage; exit 2; }
    prepare_file "$2"
    ;;
  --execute)
    (($# == 2)) || { usage; exit 2; }
    execute_file "$2"
    ;;
  -h|--help)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
GUARD
  chmod 0755 "$QUALITY_GUARD"
}

write_quality_guard

# Replace xdg.sh with an explicit and non-silent helper. Launch-time behavior is
# check-only; package installation requires both --install and explicit opt-in.
write_xdg_helper() {
  cat > "$BQCA_ROOT/xdg.sh" <<'XDG'
#!/usr/bin/env bash
set -u

# BQCA XDG helper v30
# Default behavior is check-only. Host package installation is never silent and
# is permitted only when BQCA_ALLOW_HOST_PACKAGE_INSTALL=1 is explicitly set.

_bqca_xdg_have() { command -v "$1" >/dev/null 2>&1; }

_bqca_xdg_check() {
  if [[ "$(uname -s 2>/dev/null || true)" == "Darwin" ]]; then
    _bqca_xdg_have open
    return
  fi
  _bqca_xdg_have xdg-open
}

_bqca_xdg_install() {
  [[ "${BQCA_ALLOW_HOST_PACKAGE_INSTALL:-0}" == "1" ]] || {
    printf '[BQCA] xdg-open is unavailable. Automatic host installation is disabled.\n' >&2
    printf '[BQCA] Install xdg-utils manually, or explicitly set BQCA_ALLOW_HOST_PACKAGE_INSTALL=1.\n' >&2
    return 1
  }

  printf '[BQCA] Installing xdg-utils with explicit operator approval.\n'
  if _bqca_xdg_have apt-get; then
    if [[ "$(id -u)" -eq 0 ]]; then
      DEBIAN_FRONTEND=noninteractive apt-get update -y && DEBIAN_FRONTEND=noninteractive apt-get install -y xdg-utils
    elif _bqca_xdg_have sudo; then
      sudo DEBIAN_FRONTEND=noninteractive apt-get update -y && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y xdg-utils
    else
      return 1
    fi
  elif _bqca_xdg_have dnf; then
    [[ "$(id -u)" -eq 0 ]] && dnf install -y xdg-utils || sudo dnf install -y xdg-utils
  elif _bqca_xdg_have yum; then
    [[ "$(id -u)" -eq 0 ]] && yum install -y xdg-utils || sudo yum install -y xdg-utils
  elif _bqca_xdg_have zypper; then
    [[ "$(id -u)" -eq 0 ]] && zypper --non-interactive install xdg-utils || sudo zypper --non-interactive install xdg-utils
  elif _bqca_xdg_have apk; then
    [[ "$(id -u)" -eq 0 ]] && apk add --no-cache xdg-utils || sudo apk add --no-cache xdg-utils
  else
    printf '[BQCA] No supported package manager was found.\n' >&2
    return 1
  fi
}

case "${1:---check}" in
  --check)
    _bqca_xdg_check || true
    ;;
  --install)
    _bqca_xdg_check || _bqca_xdg_install
    ;;
  *)
    printf 'Usage: %s [--check|--install]\n' "${BASH_SOURCE[0]}" >&2
    return 2 2>/dev/null || exit 2
    ;;
esac

unset -f _bqca_xdg_have _bqca_xdg_check _bqca_xdg_install 2>/dev/null || true
XDG
  chmod 0755 "$BQCA_ROOT/xdg.sh"
}

write_xdg_helper

# Force launch-time XDG behavior to check-only, preserving the rest of launchpad.
python3 - "$BQCA_ROOT/xLaunchpad.sh" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
text = path.read_text(encoding='utf-8')
text = text.replace('source "${SCRIPT_DIR}/xdg.sh" --install', 'source "${SCRIPT_DIR}/xdg.sh" --check')
path.write_text(text, encoding='utf-8')
PY

# Repair root bob-version behavior: runtime detection takes precedence. A configured
# version remains an explicit fallback only when Bob cannot be queried.
write_bob_version_detector() {
  cat > "$BQCA_ROOT/bob-version.sh" <<'BOBVER'
#!/usr/bin/env bash
# BQCA Bob Shell version detector v30

_bqca_bob_bin="${BOB_BIN:-bob}"
_bqca_configured_version="${BOB_VERSION:-}"
_bqca_version_raw=""
_bqca_detected_version=""

if command -v "$_bqca_bob_bin" >/dev/null 2>&1; then
  _bqca_version_raw="$("$_bqca_bob_bin" --version 2>/dev/null | head -n 1 | tr -d '\r' || true)"
  _bqca_detected_version="$(printf '%s\n' "$_bqca_version_raw" | grep -Eo '[0-9]+([.][0-9]+){1,3}([-.][A-Za-z0-9]+)?' | head -n 1 || true)"
fi

if [[ -n "$_bqca_detected_version" ]]; then
  BOB_VERSION="$_bqca_detected_version"
elif [[ -n "$_bqca_configured_version" && "$_bqca_configured_version" != "unknown" ]]; then
  BOB_VERSION="$_bqca_configured_version"
else
  printf '[bob-version] ERROR: Unable to determine Bob version.\n' >&2
  return 1 2>/dev/null || exit 1
fi

export BOB_VERSION
unset _bqca_bob_bin _bqca_configured_version _bqca_version_raw _bqca_detected_version
BOBVER
  chmod 0755 "$BQCA_ROOT/bob-version.sh"

  if [[ -d "$BQCA_ROOT/patches/BQCA" ]]; then
    cp -p "$BQCA_ROOT/bob-version.sh" "$BQCA_ROOT/patches/BQCA/bob-version.sh"
    chmod 0755 "$BQCA_ROOT/patches/BQCA/bob-version.sh"
  fi
}

write_bob_version_detector

# Safely normalize active policy text. This leaves .env, generated design/code,
# backups, logs, and Git metadata untouched.
python3 - "$BQCA_ROOT" <<'PY'
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])
exclude_parts = {'.git', 'patch-backups', 'backups', '.bob-errors', '__pycache__'}
allowed_suffixes = {'.md', '.yaml', '.yml'}

v30_pointer = """\n\n<!-- BQCA-v30-POLICY-REFERENCE-START -->
## BQCA Production Policy v30 — Authoritative Precedence
Use `.bob/BQCA-PRODUCTION-POLICY-v30.md` as the authoritative appliance-wide
policy. Preserve the specialized intelligence of this mode, rule, skill, or tool,
but resolve routing, implementation, execution, security, and completion behavior
according to the v30 policy. Design artifacts go to `bob-quantum-designs/`;
implementation and result artifacts go to `bob-quantum-store/`. Legacy
implementation directories must never be used.
<!-- BQCA-v30-POLICY-REFERENCE-END -->
"""

for path in root.rglob('*'):
    if not path.is_file() or path.suffix.lower() not in allowed_suffixes:
        continue
    if any(part in exclude_parts for part in path.parts):
        continue
    if path.name == 'BQCA-PRODUCTION-POLICY-v30.md':
        continue
    text = path.read_text(encoding='utf-8', errors='replace')
    original = text

    # Correct obsolete destination references without deleting surrounding domain knowledge.
    text = text.replace('bob-quantum-codes/', 'bob-quantum-store/')
    text = text.replace('bob-quantum-codes', 'bob-quantum-store')

    # Remove prior v30 pointer if rerunning, then append exactly once to active
    # rules, skills, tool documentation, and general appliance documentation.
    text = re.sub(
        r'\n*<!-- BQCA-v30-POLICY-REFERENCE-START -->.*?<!-- BQCA-v30-POLICY-REFERENCE-END -->\n*',
        '\n', text, flags=re.S
    )

    rel = path.relative_to(root).as_posix()
    append_pointer = (
        rel == 'README.md'
        or rel.startswith('.bob/rules-')
        or rel.startswith('.bob/skills/')
        or rel == '.bob/quantum-tools/README.md'
    )
    if append_pointer:
        text = text.rstrip() + v30_pointer

    if text != original:
        path.write_text(text, encoding='utf-8')
PY

# Add v30 precedence inside every customInstructions folded scalar while
# preserving each mode's existing roleDefinition, whenToUse, instructions,
# groups, and metadata. No slug is renamed because launcher compatibility must
# not be broken by a production repair patch.
python3 - "$BOB_ROOT/custom_modes.yaml" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding='utf-8')

# First correct obsolete paths globally.
text = text.replace('bob-quantum-codes/', 'bob-quantum-store/')
text = text.replace('bob-quantum-codes', 'bob-quantum-store')

# Remove prior v30 injected lines, if present.
text = re.sub(
    r'\n      \[BQCA-PRODUCTION-POLICY-v30\].*?(?=\n    [A-Za-z][A-Za-z0-9]*:|\n  - slug:|\Z)',
    '\n', text, flags=re.S
)

lines = text.splitlines()
out = []
insertions = 0
for line in lines:
    out.append(line)
    if re.match(r'^    customInstructions:\s*>-\s*$', line):
        out.extend([
            '      [BQCA-PRODUCTION-POLICY-v30] This mode preserves its specialized quantum intelligence and must apply `.bob/BQCA-PRODUCTION-POLICY-v30.md` as the authoritative precedence policy.',
            '      Design artifacts must use `bob-quantum-designs/`; implementation, notebooks, results, and visualizations must use only `bob-quantum-store/`; legacy implementation directories are prohibited.',
            '      BQCA is authorized to design, create, write, implement, execute, troubleshoot, and repair quantum solutions when requested, subject to v30 validation and security controls.',
        ])
        insertions += 1

if insertions == 0:
    raise SystemExit('No customInstructions folded scalars were found')
path.write_text('\n'.join(out) + '\n', encoding='utf-8')
print(f'[BQCA v30][INFO] Updated custom mode instruction blocks: {insertions}')
PY

# Repair broad file modes from the packaged 0666 baseline. .env is intentionally
# excluded from all chmod operations.
repair_permissions() {
  local file
  while IFS= read -r -d '' file; do
    [[ "$file" != "$ENV_FILE" ]] || continue
    chmod 0755 "$file"
  done < <(active_find -type f -name '*.sh' -print0)

  while IFS= read -r -d '' file; do
    [[ "$file" != "$ENV_FILE" ]] || continue
    chmod 0644 "$file"
  done < <(active_find -type f \( -name '*.md' -o -name '*.yaml' -o -name '*.yml' \) -print0)
}

repair_permissions

# Clean source-cache debris without touching implementation source or output.
while IFS= read -r -d '' cache_dir; do
  rm -rf "$cache_dir"
done < <(find "$BQCA_ROOT/bob-quantum-store" -type d -name '__pycache__' -print0 2>/dev/null || true)

# Ensure patch framework names and records are coherent.
mkdir -p "$PATCH_RECORD_DIR"
cat > "$PATCH_RECORD_FILE" <<RECORD
Patch: $PATCH_ID
Patch file: $PATCH_FILE_NAME
Applied UTC: $(date -u '+%Y-%m-%dT%H:%M:%SZ')
Appliance root: $BQCA_ROOT
Backup: $BACKUP_DIR
Environment: .env intentionally untouched
Repairs:
- production permissions
- robust target resolution
- canonical design/store/execution policy
- obsolete bob-quantum-codes routing removal
- non-mutating launch-time XDG behavior
- local-only code quality guard
- runtime-first Bob version detection
- validation and rollback support
RECORD
chmod 0644 "$PATCH_RECORD_FILE"

# Validate after all writes. Any failure triggers automatic rollback.
if ! run_validation; then
  warn "Post-patch validation failed. Restoring backup automatically."
  restore_backup "$BACKUP_DIR"
  fail "Patch v30 failed validation and was rolled back."
fi

# Verify .env byte content once more.
validate_env_untouched || {
  warn ".env integrity check failed. Restoring backup."
  restore_backup "$BACKUP_DIR"
  fail ".env changed unexpectedly; patch rolled back."
}

info "Patch $PATCH_ID completed successfully."
info "Backup: $BACKUP_DIR"
info "Record: $PATCH_RECORD_FILE"
info ".env was not modified."
info "Run validation again with: $PATCH_FILE_NAME --target \"$BQCA_ROOT\" --validate-only"
