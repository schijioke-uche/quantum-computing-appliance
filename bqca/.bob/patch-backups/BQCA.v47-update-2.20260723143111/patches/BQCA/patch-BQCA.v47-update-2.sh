#!/usr/bin/env bash
set -Eeuo pipefail

#===============================================================================
# BQCA v47 Update 2 - Canonical Policy and Runtime Consolidation Repair
# File: patch-BQCA.v47-update-2.sh
#
# Purpose:
#   Repair a partially applied BQCA v47 installation where:
#     - v44/v45/v46 policy files remain active under .bob;
#     - stable and versioned v47 policies differ;
#     - the active-policy registry still points to an earlier version;
#     - v44-v46 awareness or runtime marker blocks remain active;
#     - the policy doctor still emits v46 assurance output; or
#     - direct execution and formal orchestration are not cleanly separated.
#
#   The existing .bob/BQCA-PRODUCTION-POLICY-v47.md is treated as the
#   authoritative source after semantic validation. The patch synchronizes the
#   stable policy, archives older active policy documents outside .bob, rebuilds
#   the registry and history manifest, reinstalls one v47 awareness block across
#   all active modes/rules/skills/tools, restores direct execution as the
#   default, keeps the orchestrator optional for formal compliance, and installs
#   an independent v47 policy doctor.
#
# Protected assets:
#   This installer does not read, copy, back up, modify, chmod, remove, or
#   restore the project .env, bob-quantum-designs, bob-quantum-store,
#   $HOME/qiskit-v2x-env, or $HOME/.qiskit/qiskit-ibm.json.
#===============================================================================

PATCH_ID="BQCA.v47-update-2"
PATCH_FILE_NAME="patch-BQCA.v47-update-2.sh"
TIMESTAMP="$(date +%Y%m%d%H%M%S)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
TARGET_OVERRIDE=""
DRY_RUN=0
VALIDATE_ONLY=0
ROLLBACK_DIR=""

info() { printf '[BQCA v47-update-2][INFO] %s\n' "$*"; }
warn() { printf '[BQCA v47-update-2][WARN] %s\n' "$*" >&2; }
fail() { printf '[BQCA v47-update-2][ERROR] %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'USAGE'
BQCA v47 Update 2 - Canonical Policy and Runtime Consolidation Repair

Usage:
  ./patch-BQCA.v47-update-2.sh [options]

Options:
  --target <path>        Explicit BQCA appliance root.
  --dry-run              Display the repair plan without changing files.
  --validate-only        Run the v47 policy doctor and behavioral checks only.
  --rollback <backup>    Restore a v47 Update 2 backup directory.
  -h, --help             Show this help.

Expected placement:
  <BQCA-root>/patches/BQCA/patch-BQCA.v47-update-2.sh

Protected assets are never touched by the installer:
  .env
  bob-quantum-designs/
  bob-quantum-store/
  $HOME/qiskit-v2x-env
  $HOME/.qiskit/qiskit-ibm.json
USAGE
}

while (($#)); do
  case "$1" in
    --target)
      (($# >= 2)) || fail "--target requires a path"
      TARGET_OVERRIDE="$2"
      shift 2
      ;;
    --dry-run) DRY_RUN=1; shift ;;
    --validate-only) VALIDATE_ONLY=1; shift ;;
    --rollback)
      (($# >= 2)) || fail "--rollback requires a backup directory"
      ROLLBACK_DIR="$2"
      shift 2
      ;;
    -h|--help) usage; exit 0 ;;
    *) fail "Unknown option: $1" ;;
  esac
done

for cmd in bash cat chmod cmp cp date dirname find grep head mkdir mktemp mv python3 rm sha256sum sort tail tee; do
  command -v "$cmd" >/dev/null 2>&1 || fail "Required command not found: $cmd"
done

is_bqca_root() {
  local candidate="$1"
  [[ -d "$candidate/.bob" ]] || return 1
  [[ -f "$candidate/.bob/custom_modes.yaml" ]] || return 1
  [[ -d "$candidate/.bob/skills" ]] || return 1
  [[ -d "$candidate/.bob/quantum-tools" ]] || return 1
  [[ -f "$candidate/xLaunchpad.sh" ]] || return 1
  [[ -d "$candidate/bob-quantum-store" ]] || return 1
}

resolve_bqca_root() {
  local candidate dir
  if [[ -n "$TARGET_OVERRIDE" ]]; then
    candidate="$(cd "$TARGET_OVERRIDE" 2>/dev/null && pwd -P || true)"
    [[ -n "$candidate" ]] || fail "Target path does not exist: $TARGET_OVERRIDE"
    is_bqca_root "$candidate" || fail "Target is not a valid BQCA root: $candidate"
    printf '%s\n' "$candidate"
    return
  fi

  candidate="$(pwd -P)"
  if is_bqca_root "$candidate"; then
    printf '%s\n' "$candidate"
    return
  fi

  dir="$SCRIPT_DIR"
  while [[ "$dir" != "/" ]]; do
    if is_bqca_root "$dir"; then
      printf '%s\n' "$dir"
      return
    fi
    if is_bqca_root "$dir/quantum-computing-agent"; then
      printf '%s\n' "$dir/quantum-computing-agent"
      return
    fi
    dir="$(dirname "$dir")"
  done
  fail "Unable to locate the BQCA root. Use --target <path>."
}

BQCA_ROOT="$(resolve_bqca_root)"
BOB_ROOT="$BQCA_ROOT/.bob"
TOOLS_DIR="$BOB_ROOT/quantum-tools"
PATCHES_DIR="$BQCA_ROOT/patches/BQCA"
HISTORY_DIR="$PATCHES_DIR/policy-history"
HISTORY_MANIFEST="$HISTORY_DIR/BQCA-policy-history-manifest.json"
REGISTRY="$BOB_ROOT/BQCA-ACTIVE-POLICY-REGISTRY.json"
POLICY_STABLE="$BOB_ROOT/BQCA-PRODUCTION-POLICY.md"
POLICY_V47="$BOB_ROOT/BQCA-PRODUCTION-POLICY-v47.md"
CUSTOM_MODES="$BOB_ROOT/custom_modes.yaml"
XLAUNCHPAD="$BQCA_ROOT/xLaunchpad.sh"
DIRECT_EXECUTOR="$TOOLS_DIR/bqca-direct-execution.sh"
LEGACY_DIRECT_EXECUTOR="$TOOLS_DIR/bqca-direct-execute.sh"
ORCHESTRATOR_SH="$TOOLS_DIR/bqca-policy-orchestrator.sh"
ORCHESTRATOR_PY="$TOOLS_DIR/bqca-policy-orchestrator.py"
DOCTOR_SH="$TOOLS_DIR/bqca-policy-doctor.sh"
DOCTOR_PY="$TOOLS_DIR/bqca-policy-doctor.py"
ASSURANCE_REPORT="$BOB_ROOT/patches-applied/BQCA.v47-assurance-report.txt"
PATCH_RECORD_DIR="$BOB_ROOT/patches-applied"
PATCH_RECORD_FILE="$PATCH_RECORD_DIR/${PATCH_ID}.txt"
CANONICAL_PATCH_PATH="$PATCHES_DIR/$PATCH_FILE_NAME"
BACKUP_ROOT="$BOB_ROOT/patch-backups"
BACKUP_DIR="$BACKUP_ROOT/${PATCH_ID}.${TIMESTAMP}"
BACKUP_MANIFEST="$BACKUP_DIR/BQCA-v47-update-2-backup-manifest.txt"
BACKED_UP_LIST="$BACKUP_DIR/BQCA-v47-update-2-backed-up-files.txt"
CREATED_LIST="$BACKUP_DIR/BQCA-v47-update-2-created-files.txt"

is_protected_path() {
  local path="$1"
  case "$path" in
    "$BQCA_ROOT/.env"|"$BQCA_ROOT/.env/"*|\
    "$BQCA_ROOT/bob-quantum-designs"|"$BQCA_ROOT/bob-quantum-designs/"*|\
    "$BQCA_ROOT/bob-quantum-store"|"$BQCA_ROOT/bob-quantum-store/"*) return 0 ;;
  esac
  if [[ -n "${HOME:-}" ]]; then
    case "$path" in
      "$HOME/qiskit-v2x-env"|"$HOME/qiskit-v2x-env/"*|\
      "$HOME/.qiskit/qiskit-ibm.json") return 0 ;;
    esac
  fi
  return 1
}

backup_file() {
  local source="$1" rel destination
  [[ -e "$source" ]] || return 0
  is_protected_path "$source" && return 0
  rel="${source#$BQCA_ROOT/}"
  destination="$BACKUP_DIR/$rel"
  mkdir -p "$(dirname "$destination")"
  cp -a "$source" "$destination"
  grep -Fxq "$rel" "$BACKED_UP_LIST" 2>/dev/null || printf '%s\n' "$rel" >> "$BACKED_UP_LIST"
}

record_created() {
  local path="$1" rel
  [[ -e "$path" ]] && return 0
  is_protected_path "$path" && return 0
  rel="${path#$BQCA_ROOT/}"
  grep -Fxq "$rel" "$CREATED_LIST" 2>/dev/null || printf '%s\n' "$rel" >> "$CREATED_LIST"
}

create_backup() {
  mkdir -p "$BACKUP_DIR"
  : > "$BACKED_UP_LIST"
  : > "$CREATED_LIST"

  while IFS= read -r -d '' file; do backup_file "$file"; done < <(
    find "$BOB_ROOT" -maxdepth 1 -type f -name 'BQCA-*POLICY*.md' -print0
  )

  for file in "$REGISTRY" "$CUSTOM_MODES" "$XLAUNCHPAD" "$HISTORY_MANIFEST" \
              "$DIRECT_EXECUTOR" "$LEGACY_DIRECT_EXECUTOR" "$ORCHESTRATOR_SH" \
              "$ORCHESTRATOR_PY" "$DOCTOR_SH" "$DOCTOR_PY" "$ASSURANCE_REPORT" \
              "$PATCH_RECORD_FILE" "$CANONICAL_PATCH_PATH"; do
    backup_file "$file"
  done

  local directory
  for directory in "$BOB_ROOT"/rules-* "$BOB_ROOT/skills" "$TOOLS_DIR"; do
    [[ -d "$directory" ]] || continue
    while IFS= read -r -d '' file; do backup_file "$file"; done < <(
      find "$directory" -type f \
        \( -name '*.md' -o -name '*.txt' -o -name '*.sh' -o -name '*.py' -o -name '*.yaml' -o -name '*.yml' \) \
        -print0
    )
  done

  while IFS= read -r -d '' file; do backup_file "$file"; done < <(
    find "$BQCA_ROOT" -maxdepth 1 -type f -name 'bob-quantum-v*.sh' -print0
  )

  cat > "$BACKUP_MANIFEST" <<MANIFEST
Patch: $PATCH_ID
Created: $(date -u '+%Y-%m-%dT%H:%M:%SZ')
Appliance root: $BQCA_ROOT
Purpose: repair partial BQCA v47 policy and runtime consolidation
Protected paths excluded: .env, bob-quantum-designs, bob-quantum-store, \$HOME/qiskit-v2x-env, \$HOME/.qiskit/qiskit-ibm.json
Restore with:
  $PATCH_FILE_NAME --target "$BQCA_ROOT" --rollback "$BACKUP_DIR"
MANIFEST
}

restore_backup() {
  local backup="$1" backup_abs source rel destination
  backup_abs="$(cd "$backup" 2>/dev/null && pwd -P || true)"
  [[ -n "$backup_abs" ]] || fail "Rollback directory not found: $backup"
  [[ -f "$backup_abs/BQCA-v47-update-2-backup-manifest.txt" ]] || \
    fail "Not a BQCA v47 Update 2 backup: $backup_abs"

  info "Restoring v47 Update 2 backup: $backup_abs"
  while IFS= read -r -d '' source; do
    rel="${source#$backup_abs/}"
    case "$rel" in
      BQCA-v47-update-2-backup-manifest.txt|\
      BQCA-v47-update-2-backed-up-files.txt|\
      BQCA-v47-update-2-created-files.txt) continue ;;
    esac
    destination="$BQCA_ROOT/$rel"
    is_protected_path "$destination" && continue
    mkdir -p "$(dirname "$destination")"
    cp -a "$source" "$destination"
  done < <(find "$backup_abs" -mindepth 1 -type f -print0)

  if [[ -f "$backup_abs/BQCA-v47-update-2-created-files.txt" ]]; then
    while IFS= read -r rel; do
      [[ -n "$rel" ]] || continue
      destination="$BQCA_ROOT/$rel"
      is_protected_path "$destination" && continue
      [[ -e "$backup_abs/$rel" ]] || rm -f "$destination"
    done < "$backup_abs/BQCA-v47-update-2-created-files.txt"
  fi

  info "Rollback complete. Protected assets were not touched."
}

if [[ -n "$ROLLBACK_DIR" ]]; then
  restore_backup "$ROLLBACK_DIR"
  exit 0
fi

info "Resolved BQCA root: $BQCA_ROOT"
info "Patch identity: $PATCH_ID"
info "Protected assets: .env, workload stores, home Qiskit environment, and account JSON"

if ((DRY_RUN)); then
  cat <<'DRY'
[BQCA v47-update-2][DRY-RUN] Planned repair:
  1. Semantically validate BQCA-PRODUCTION-POLICY-v47.md without rejecting valid audit-history wording.
  2. Back up all active policies, registry, launchers, modes, rules, skills,
     tools, templates, doctor assets, and policy-history metadata.
  3. Synchronize BQCA-PRODUCTION-POLICY.md from the verified v47 policy.
  4. Archive v44/v45/v46 and any other unexpected active policy documents
     outside the active .bob context.
  5. Rebuild the v47 active-policy registry and policy-history manifest.
  6. Remove v44-v46 canonical awareness blocks and install one v47 awareness
     block in every custom mode, rule, skill, and supported quantum tool.
  7. Replace stale launcher/runtime marker blocks with v47 blocks.
  8. Restore direct execution as the default with live terminal output and
     dual result files; retain the orchestrator only for formal compliance.
  9. Replace the policy doctor with an independent v47 assurance implementation.
 10. Validate syntax, permissions, policy equality, registry integrity,
     awareness coverage, direct execution, output capture, and rollback metadata.
 11. Leave all protected assets unchanged.
DRY
  exit 0
fi

[[ -f "$POLICY_V47" ]] || fail "Missing intended v47 policy: $POLICY_V47"

validate_v47_policy() {
  python3 - "$POLICY_V47" <<'PY'
from __future__ import annotations
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding="utf-8", errors="replace")
low = text.lower()

required_all = {
    "v47 identity": ("bqca canonical production policy v47",),
    "active authority": ("sole active", "production policy"),
    "historical audit disposition": ("audit records only",),
    "stable policy path": (".bob/bqca-production-policy.md",),
    "versioned v47 path": (".bob/bqca-production-policy-v47.md",),
    "formal orchestrator": ("orchestrator", "formal"),
    "dual output": ("output.txt", "result-output.txt"),
    "home environment": ("qiskit-v2x-env", "$home"),
    "open plan primitives": ("samplerv2", "estimatorv2"),
    "session rule": ("session", "open plan"),
    "configuration gate": ("qiskit-configuration", "qiskit-ibm.json"),
    "notebook": ("notebook", ".ipynb"),
    "hello world": ("hello world",),
}
required_any = {
    "direct execution": ("direct execution", "direct-execution"),
    "live terminal output": ("real-time terminal", "live terminal", "terminal output"),
}

problems: list[str] = []
for label, tokens in required_all.items():
    if not all(token in low for token in tokens):
        problems.append(f"missing required policy concept: {label}")
for label, tokens in required_any.items():
    if not any(token in low for token in tokens):
        problems.append(f"missing required policy concept: {label}")

# Historical references to v44-v46 are valid in the v47 history/disposition
# section. Reject only wording that actually makes an older version active, or
# embeds an older active marker in the v47 policy itself.
prohibited = {
    "legacy canonical marker": re.compile(
        r"bqca-canonical-production-policy-v(?:44|45|46):begin", re.I
    ),
    "legacy policy heading": re.compile(
        r"^\s*#\s+bqca\s+(?:canonical\s+)?production\s+policy\s+v(?:44|45|46)\s*$",
        re.I | re.M,
    ),
    "legacy active authority statement": re.compile(
        r"\b(?:bqca\s+)?v(?:44|45|46)\b[^\n.]{0,100}\b(?:is|remains|becomes)\b[^\n.]{0,80}\b(?:the\s+)?(?:sole\s+)?(?:active|canonical)\b",
        re.I,
    ),
    "legacy versioned active path": re.compile(
        r"(?:stable|active|canonical|versioned)[^\n]{0,100}bqca-production-policy-v(?:44|45|46)\.md",
        re.I,
    ),
}
for label, pattern in prohibited.items():
    match = pattern.search(text)
    if match:
        line = text.count("\n", 0, match.start()) + 1
        excerpt = " ".join(match.group(0).split())[:120]
        problems.append(f"{label} at line {line}: {excerpt}")

if problems:
    print("BQCA_V47_POLICY_SEMANTICS=FAIL", file=sys.stderr)
    for problem in problems:
        print(f"  - {problem}", file=sys.stderr)
    raise SystemExit(1)

print("BQCA_V47_POLICY_SEMANTICS=PASS")
PY
}
validate_v47_policy

if ((VALIDATE_ONLY)); then
  [[ -x "$DOCTOR_SH" ]] || fail "Policy doctor is unavailable: $DOCTOR_SH"
  "$DOCTOR_SH" report || true
  "$DOCTOR_SH" check --quiet
  exit $?
fi

create_backup
mkdir -p "$HISTORY_DIR" "$PATCH_RECORD_DIR" "$TOOLS_DIR" "$PATCHES_DIR"

record_created "$POLICY_STABLE"
record_created "$REGISTRY"
record_created "$HISTORY_MANIFEST"
record_created "$DIRECT_EXECUTOR"
record_created "$LEGACY_DIRECT_EXECUTOR"
record_created "$DOCTOR_SH"
record_created "$DOCTOR_PY"
record_created "$ASSURANCE_REPORT"
record_created "$PATCH_RECORD_FILE"
record_created "$CANONICAL_PATCH_PATH"

# Keep a canonical copy of this repair patch so the policy doctor repair command
# always has a deterministic target.
if [[ "$(cd "$(dirname "$CANONICAL_PATCH_PATH")" && pwd -P)/$(basename "$CANONICAL_PATCH_PATH")" != \
      "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/$(basename "${BASH_SOURCE[0]}")" ]]; then
  cp "${BASH_SOURCE[0]}" "$CANONICAL_PATCH_PATH"
fi
chmod 755 "$CANONICAL_PATCH_PATH"

consolidate_policy_metadata() {
  python3 - "$BQCA_ROOT" "$POLICY_V47" "$POLICY_STABLE" "$REGISTRY" "$HISTORY_DIR" "$HISTORY_MANIFEST" "$TIMESTAMP" "$CREATED_LIST" <<'PY'
from __future__ import annotations
import datetime as dt
import hashlib
import json
import pathlib
import shutil
import sys

root = pathlib.Path(sys.argv[1])
versioned = pathlib.Path(sys.argv[2])
stable = pathlib.Path(sys.argv[3])
registry_path = pathlib.Path(sys.argv[4])
history = pathlib.Path(sys.argv[5])
manifest_path = pathlib.Path(sys.argv[6])
stamp = sys.argv[7]
created_list = pathlib.Path(sys.argv[8])
bob = root / ".bob"
history.mkdir(parents=True, exist_ok=True)

def digest(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

# The verified versioned v47 document is the source of truth.
stable.write_bytes(versioned.read_bytes())

expected = {stable.name, versioned.name}
archived = []
for path in sorted(bob.glob("BQCA-*POLICY*.md")):
    if path.name in expected:
        continue
    destination = history / path.name
    if destination.exists() and destination.read_bytes() != path.read_bytes():
        destination = history / f"{path.stem}-recovered-{stamp}{path.suffix}"
    created = not destination.exists()
    if created:
        shutil.copy2(path, destination)
        with created_list.open("a", encoding="utf-8") as stream:
            stream.write(destination.relative_to(root).as_posix() + "\n")
    path.unlink()
    archived.append(destination.relative_to(root).as_posix())

entries = []
for path in sorted(history.glob("*.md")):
    name = path.name.lower()
    status = "historical-audit"
    if "v35" in name or "v36" in name:
        status = "duplicate-superseded"
    elif any(tag in name for tag in ("v44", "v45", "v46")):
        status = "incorporated-into-v47"
    entries.append({
        "name": path.name,
        "archive_path": path.relative_to(root).as_posix(),
        "sha256": digest(path),
        "size_bytes": path.stat().st_size,
        "status": status,
    })
manifest = {
    "schema_version": 1,
    "generated_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
    "active_version": "v47",
    "entries": entries,
}
manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

policy_hash = digest(stable)
registry = {
    "schema_version": 2,
    "active_version": "v47",
    "active_policy_path": ".bob/BQCA-PRODUCTION-POLICY.md",
    "policy_path": ".bob/BQCA-PRODUCTION-POLICY.md",
    "versioned_policy_path": ".bob/BQCA-PRODUCTION-POLICY-v47.md",
    "policy_sha256": policy_hash,
    "canonical_policy_sha256": policy_hash,
    "direct_execution_path": ".bob/quantum-tools/bqca-direct-execution.sh",
    "orchestrator_path": ".bob/quantum-tools/bqca-policy-orchestrator.sh",
    "doctor_path": ".bob/quantum-tools/bqca-policy-doctor.sh",
    "repair_patch_path": "patches/BQCA/patch-BQCA.v47-update-2.sh",
    "default_execution": "direct",
    "formal_compliance": "optional-orchestrator",
    "historical_policy_directory": "patches/BQCA/policy-history",
    "active_authority": {
        "version": "v47",
        "stable_policy": ".bob/BQCA-PRODUCTION-POLICY.md",
        "versioned_policy": ".bob/BQCA-PRODUCTION-POLICY-v47.md",
        "policy_sha256": policy_hash,
    },
    "disposition": {
        "v44": "incorporated into v47 semantic assurance",
        "v45": "incorporated into v47 direct execution",
        "v46": "incorporated into v47 assurance repair",
        "v47": "active authority",
    },
}
registry_path.write_text(json.dumps(registry, indent=2) + "\n", encoding="utf-8")
print(f"unexpected_active_policies_archived={len(archived)}")
print(f"history_entries={len(entries)}")
print(f"policy_sha256={policy_hash}")
PY
}

consolidate_policy_metadata

write_direct_executor() {
  cat > "$DIRECT_EXECUTOR" <<'SH'
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
SH
  chmod 755 "$DIRECT_EXECUTOR"
}

write_legacy_direct_shim() {
  cat > "$LEGACY_DIRECT_EXECUTOR" <<'SH'
#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
DIRECT="$SCRIPT_DIR/bqca-direct-execution.sh"
[[ -x "$DIRECT" ]] || { printf 'BQCA v47 direct executor is missing: %s\n' "$DIRECT" >&2; exit 2; }
(($# >= 1)) || { printf 'Usage: bqca-direct-execute.sh <file.py> [arguments...]\n' >&2; exit 2; }
exec "$DIRECT" run "$@"
SH
  chmod 755 "$LEGACY_DIRECT_EXECUTOR"
}

patch_runtime_wiring() {
  python3 - "$BQCA_ROOT" <<'PY'
from __future__ import annotations
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1])
bob = root / ".bob"
tools = bob / "quantum-tools"

BLOCK_RE = re.compile(
    r"(?ms)^# BQCA-(?P<family>POLICY-ASSURANCE|DIRECT-EXECUTION-EXPORT|CANONICAL-ORCHESTRATOR|DIRECT-EXECUTION-DELEGATION|RESULT-CAPTURE-GATE)-v(?:44|45|46|47):BEGIN\n.*?^# BQCA-(?P=family)-v(?:44|45|46|47):END\n?"
)

def strip_blocks(text: str) -> str:
    return BLOCK_RE.sub("", text)

# xLaunchpad: one v47 assurance block immediately after .env loading.
launch = root / "xLaunchpad.sh"
text = strip_blocks(launch.read_text(encoding="utf-8"))
block = r'''# BQCA-POLICY-ASSURANCE-v47:BEGIN
_BQCA_V47_POLICY_DOCTOR="${SCRIPT_DIR}/.bob/quantum-tools/bqca-policy-doctor.sh"
if [[ ! -x "${_BQCA_V47_POLICY_DOCTOR}" ]]; then
  printf '[BQCA][ERROR] BQCA v47 policy doctor is missing: %s\n' "${_BQCA_V47_POLICY_DOCTOR}" >&2
  exit 1
fi
if ! "${_BQCA_V47_POLICY_DOCTOR}" check --quiet; then
  printf '[BQCA][ERROR] BQCA v47 policy drift detected. Run: %s repair\n' "${_BQCA_V47_POLICY_DOCTOR}" >&2
  exit 1
fi
unset _BQCA_V47_POLICY_DOCTOR
# BQCA-POLICY-ASSURANCE-v47:END
'''
needle = "set +a\n"
if needle not in text:
    raise SystemExit("Unable to locate .env loading boundary in xLaunchpad.sh")
text = text.replace(needle, needle + "\n" + block + "\n", 1)
launch.write_text(text, encoding="utf-8")

# Versioned Bob launchers: export direct execution as default and formal
# orchestrator as an optional path.
for path in sorted(root.glob("bob-quantum-v*.sh")):
    text = strip_blocks(path.read_text(encoding="utf-8"))
    block = r'''# BQCA-DIRECT-EXECUTION-EXPORT-v47:BEGIN
BQCA_ACTIVE_POLICY="${SCRIPT_DIR}/.bob/BQCA-PRODUCTION-POLICY.md"
BQCA_DIRECT_EXECUTION="${SCRIPT_DIR}/.bob/quantum-tools/bqca-direct-execution.sh"
BQCA_FORMAL_ORCHESTRATOR="${SCRIPT_DIR}/.bob/quantum-tools/bqca-policy-orchestrator.sh"
BQCA_POLICY_DOCTOR="${SCRIPT_DIR}/.bob/quantum-tools/bqca-policy-doctor.sh"
export BQCA_ACTIVE_POLICY BQCA_DIRECT_EXECUTION BQCA_FORMAL_ORCHESTRATOR BQCA_POLICY_DOCTOR
# Direct execution is the default. Use BQCA_FORMAL_ORCHESTRATOR only for
# formal documentation, production deployment compliance, or audit evidence.
# BQCA-DIRECT-EXECUTION-EXPORT-v47:END
'''
    match = re.search(r'^SCRIPT_DIR=.*$', text, re.M)
    if not match:
        raise SystemExit(f"Unable to locate SCRIPT_DIR in {path}")
    text = text[:match.end()] + "\n\n" + block + text[match.end():]
    path.write_text(text, encoding="utf-8")

# Environment manager: public run/run-notebook commands delegate to the direct
# executor. Internal/formal calls retain the existing implementation.
env_tool = tools / "qiskit-v2x-environment.sh"
if env_tool.is_file():
    text = strip_blocks(env_tool.read_text(encoding="utf-8"))
    if 'DIRECT_EXECUTOR="$SCRIPT_DIR/bqca-direct-execution.sh"' not in text:
        match = re.search(r'^SCRIPT_DIR=.*$', text, re.M)
        if not match:
            raise SystemExit("Unable to locate SCRIPT_DIR in qiskit-v2x-environment.sh")
        text = text[:match.end()] + '\nDIRECT_EXECUTOR="$SCRIPT_DIR/bqca-direct-execution.sh"' + text[match.end():]
    block = r'''# BQCA-DIRECT-EXECUTION-DELEGATION-v47:BEGIN
if [[ "${BQCA_V47_INTERNAL:-0}" != "1" && "${BQCA_V47_ORCHESTRATED:-0}" != "1" && "${BQCA_V47_FORMAL:-0}" != "1" ]]; then
  case "$command_name" in
    run)
      [[ -x "$DIRECT_EXECUTOR" ]] || { printf 'BQCA v47 direct executor is missing: %s\n' "$DIRECT_EXECUTOR" >&2; exit 2; }
      exec "$DIRECT_EXECUTOR" run "$@"
      ;;
    run-notebook)
      [[ -x "$DIRECT_EXECUTOR" ]] || { printf 'BQCA v47 direct executor is missing: %s\n' "$DIRECT_EXECUTOR" >&2; exit 2; }
      exec "$DIRECT_EXECUTOR" run-notebook "$@"
      ;;
  esac
fi
# BQCA-DIRECT-EXECUTION-DELEGATION-v47:END

'''
    index = text.rfind('case "$command_name" in')
    if index < 0:
        raise SystemExit("Unable to locate command dispatch in qiskit-v2x-environment.sh")
    text = text[:index] + block + text[index:]
    env_tool.write_text(text, encoding="utf-8")

# Remove obsolete orchestrator-first wrapper blocks from the connector and code
# quality guard. Their normal run paths now reach the environment manager, which
# delegates to the direct executor.
for name in ("qiskit-connector.sh", "qca-code-quality-guard.sh"):
    path = tools / name
    if path.is_file():
        path.write_text(strip_blocks(path.read_text(encoding="utf-8")), encoding="utf-8")

# Formal orchestrator and helper: normalize all internal generations to v47.
for name in ("bqca-policy-orchestrator.sh", "bqca-policy-orchestrator.py", "qiskit-result-output.sh"):
    path = tools / name
    if not path.is_file():
        continue
    text = path.read_text(encoding="utf-8", errors="replace")
    for old in ("BQCA_V44_", "BQCA_V45_", "BQCA_V46_"):
        text = text.replace(old, "BQCA_V47_")
    text = re.sub(r'BQCA-PRODUCTION-POLICY-v(?:44|45|46)\.md', 'BQCA-PRODUCTION-POLICY-v47.md', text)
    text = re.sub(r'BQCA-CANONICAL-PRODUCTION-POLICY-v(?:44|45|46)', 'BQCA-CANONICAL-PRODUCTION-POLICY-v47', text)
    text = re.sub(r'BQCA-RESULT-CAPTURE-GATE-v(?:44|45|46)', 'BQCA-RESULT-CAPTURE-GATE-v47', text)
    text = re.sub(r'BQCA v(?:44|45|46)', 'BQCA v47', text)
    text = re.sub(r'BQCA_V(?:44|45|46)', 'BQCA_V47', text)
    if name == "bqca-policy-orchestrator.py":
        text = text.replace('CANONICAL = "BQCA-CANONICAL-PRODUCTION-POLICY-" + "v44"',
                            'CANONICAL = "BQCA-CANONICAL-PRODUCTION-POLICY-" + "v47"')
        text = re.sub(r'LEGACY_VERSION = r"[^"]+"',
                      'LEGACY_VERSION = r"(?:v30|v31|v32|v33|v34|v35|v36|v37|v38|v39(?:-update-1)?|v40|v41|v42|v43|v44|v45|v46)"',
                      text, count=1)
        text = text.replace('expected = {"BQCA-PRODUCTION-POLICY.md", "BQCA-PRODUCTION-POLICY-v44.md"}',
                            'expected = {"BQCA-PRODUCTION-POLICY.md", "BQCA-PRODUCTION-POLICY-v47.md"}')
    path.write_text(text, encoding="utf-8")
PY
}

write_doctor_py() {
  cat > "$DOCTOR_PY" <<'PY'
#!/usr/bin/env python3
"""BQCA v47 independent policy assurance and drift detector."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import pathlib
import re
import stat
import subprocess
import sys
from datetime import datetime, timezone

CANONICAL = "BQCA-CANONICAL-PRODUCTION-POLICY-v47"
LEGACY_CANONICAL = re.compile(
    r"(?:<!--\s*BQCA-CANONICAL-PRODUCTION-POLICY-v(?:30|31|32|33|34|35|36|37|38|39|40|41|42|43|44|45|46):BEGIN\s*-->|"
    r"^\s*#\s*BQCA-CANONICAL-PRODUCTION-POLICY-v(?:30|31|32|33|34|35|36|37|38|39|40|41|42|43|44|45|46):BEGIN\s*$)",
    re.I | re.M,
)
STALE_RUNTIME = re.compile(
    r"BQCA-(?:POLICY-ASSURANCE|DIRECT-EXECUTION-EXPORT|CANONICAL-ORCHESTRATOR|DIRECT-EXECUTION-DELEGATION|RESULT-CAPTURE-GATE)-v(?:44|45|46):BEGIN"
)
EXTENSIONS = {".md", ".txt", ".sh", ".py", ".yaml", ".yml"}


def sha256(path: pathlib.Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def supported_files(root: pathlib.Path):
    bob = root / ".bob"
    rules = sorted(
        path for directory in bob.glob("rules-*") if directory.is_dir()
        for path in directory.rglob("*") if path.is_file() and path.suffix.lower() in EXTENSIONS
    )
    skills_root = bob / "skills"
    skills = sorted(
        path for path in skills_root.rglob("*") if path.is_file() and path.suffix.lower() in EXTENSIONS
    ) if skills_root.is_dir() else []
    tools_root = bob / "quantum-tools"
    tools = sorted(
        path for path in tools_root.iterdir() if path.is_file() and path.suffix.lower() in EXTENSIONS
    ) if tools_root.is_dir() else []
    return rules, skills, tools


def bash_syntax(path: pathlib.Path) -> str | None:
    result = subprocess.run(["bash", "-n", str(path)], text=True, capture_output=True)
    return None if result.returncode == 0 else result.stderr.strip()


def python_syntax(path: pathlib.Path) -> str | None:
    try:
        compile(path.read_text(encoding="utf-8", errors="replace"), str(path), "exec")
        return None
    except Exception as exc:
        return str(exc)


def check(root: pathlib.Path) -> dict[str, object]:
    bob = root / ".bob"
    tools = bob / "quantum-tools"
    policy = bob / "BQCA-PRODUCTION-POLICY.md"
    versioned = bob / "BQCA-PRODUCTION-POLICY-v47.md"
    registry_path = bob / "BQCA-ACTIVE-POLICY-REGISTRY.json"
    manifest_path = root / "patches/BQCA/policy-history/BQCA-policy-history-manifest.json"
    custom_modes = bob / "custom_modes.yaml"
    errors: list[str] = []
    result: dict[str, object] = {}

    expected_policies = {"BQCA-PRODUCTION-POLICY.md", "BQCA-PRODUCTION-POLICY-v47.md"}
    active_policies = {path.name for path in bob.glob("BQCA-*POLICY*.md")}
    result["active_policy_files"] = sorted(active_policies)
    if active_policies != expected_policies:
        errors.append(f"active policy files differ from expected set: {sorted(active_policies)}")

    policy_hash = ""
    if not policy.is_file() or not versioned.is_file():
        errors.append("canonical v47 policy files are missing")
    else:
        policy_hash = sha256(policy)
        if policy.read_bytes() != versioned.read_bytes():
            errors.append("stable and versioned v47 policies differ")

    try:
        registry = json.loads(registry_path.read_text(encoding="utf-8"))
    except Exception as exc:
        registry = {}
        errors.append(f"invalid registry JSON: {exc}")
    if registry.get("active_version") != "v47":
        errors.append("registry active_version is not v47")
    if registry.get("active_policy_path") != ".bob/BQCA-PRODUCTION-POLICY.md":
        errors.append("registry active policy path is incorrect")
    if registry.get("versioned_policy_path") != ".bob/BQCA-PRODUCTION-POLICY-v47.md":
        errors.append("registry versioned policy path is incorrect")
    if registry.get("policy_sha256") != policy_hash:
        errors.append("registry canonical policy hash mismatch")
    if registry.get("direct_execution_path") != ".bob/quantum-tools/bqca-direct-execution.sh":
        errors.append("registry direct execution path is incorrect")
    if registry.get("orchestrator_path") != ".bob/quantum-tools/bqca-policy-orchestrator.sh":
        errors.append("registry orchestrator_path is incorrect")
    if registry.get("doctor_path") != ".bob/quantum-tools/bqca-policy-doctor.sh":
        errors.append("registry doctor_path is incorrect")
    active = registry.get("active_authority", {}) if isinstance(registry, dict) else {}
    if active.get("version") != "v47":
        errors.append("registry active_authority version is not v47")

    history_failures = 0
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except Exception as exc:
        manifest = {}
        errors.append(f"invalid policy-history manifest: {exc}")
    for entry in manifest.get("entries", []) if isinstance(manifest, dict) else []:
        archive = root / str(entry.get("archive_path", ""))
        if not archive.is_file() or sha256(archive) != entry.get("sha256"):
            history_failures += 1
            errors.append(f"history manifest mismatch: {archive}")
    result["history_hash_failures"] = history_failures

    rules, skills, tool_files = supported_files(root)
    files = [custom_modes, *rules, *skills, *tool_files]
    begin = CANONICAL + ":BEGIN"
    coverage_errors = []
    legacy_count = 0
    for path in files:
        text = path.read_text(encoding="utf-8", errors="replace")
        legacy_count += len(LEGACY_CANONICAL.findall(text))
        actual = text.count(begin)
        if path == custom_modes:
            expected = len(re.findall(r"^\s*customInstructions:\s*[>|][+-]?\s*(?:#.*)?$", text, re.M))
        else:
            expected = 1
        if actual != expected:
            coverage_errors.append({"file": str(path.relative_to(root)), "expected": expected, "actual": actual})
    if legacy_count:
        errors.append(f"active v30-v46 canonical awareness blocks found: {legacy_count}")
    if coverage_errors:
        errors.append(f"v47 awareness coverage errors: {len(coverage_errors)}")
    result["legacy_blocks"] = legacy_count
    result["coverage_errors"] = coverage_errors
    result["custom_mode_blocks"] = len(re.findall(
        r"^\s*customInstructions:\s*[>|][+-]?\s*(?:#.*)?$",
        custom_modes.read_text(encoding="utf-8", errors="replace"), re.M,
    ))
    result["rule_files"] = len(rules)
    result["skill_files"] = len(skills)
    result["tool_files"] = len(tool_files)

    stale_hits = []
    scan_paths = [custom_modes, root / "xLaunchpad.sh", *root.glob("bob-quantum-v*.sh"), *rules, *skills, *tool_files]
    for path in scan_paths:
        text = path.read_text(encoding="utf-8", errors="replace")
        if STALE_RUNTIME.search(text):
            stale_hits.append(str(path.relative_to(root)))
    if stale_hits:
        errors.append(f"stale v44-v46 runtime markers remain: {len(stale_hits)}")
    result["stale_runtime_files"] = stale_hits

    wrapper_errors = []
    requirements = {
        root / "xLaunchpad.sh": ("BQCA-POLICY-ASSURANCE-v47:BEGIN", "bqca-policy-doctor.sh", "check --quiet"),
        tools / "qiskit-v2x-environment.sh": ("BQCA-DIRECT-EXECUTION-DELEGATION-v47:BEGIN", "bqca-direct-execution.sh"),
        tools / "bqca-direct-execution.sh": ("tee", "output.txt", "formal-run", "PIPESTATUS"),
        tools / "bqca-policy-doctor.sh": ("patch-BQCA.v47-update-2.sh", "BQCA v47 policy doctor"),
        tools / "bqca-policy-orchestrator.sh": ("BQCA-PRODUCTION-POLICY-v47.md", "BQCA_V47_INTERNAL"),
    }
    for path, tokens in requirements.items():
        if not path.is_file():
            wrapper_errors.append(f"missing wrapper: {path}")
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        for token in tokens:
            if token not in text:
                wrapper_errors.append(f"{path.name} missing token: {token}")
    for path in sorted(root.glob("bob-quantum-v*.sh")):
        text = path.read_text(encoding="utf-8", errors="replace")
        if "BQCA-DIRECT-EXECUTION-EXPORT-v47:BEGIN" not in text:
            wrapper_errors.append(f"{path.name} lacks v47 direct-execution export")
    if wrapper_errors:
        errors.extend(wrapper_errors)
    result["wrapper_errors"] = wrapper_errors

    syntax_errors = []
    executable_targets = [
        root / "xLaunchpad.sh",
        tools / "bqca-direct-execution.sh",
        tools / "bqca-direct-execute.sh",
        tools / "bqca-policy-doctor.sh",
        tools / "bqca-policy-orchestrator.sh",
        tools / "qiskit-v2x-environment.sh",
        tools / "qiskit-connector.sh",
        tools / "qca-code-quality-guard.sh",
    ] + sorted(root.glob("bob-quantum-v*.sh"))
    for path in executable_targets:
        if not path.is_file():
            syntax_errors.append(f"missing executable: {path}")
            continue
        failure = bash_syntax(path)
        if failure:
            syntax_errors.append(f"{path}: {failure}")
        mode = stat.S_IMODE(path.stat().st_mode)
        if not (mode & stat.S_IXUSR):
            syntax_errors.append(f"not owner-executable: {path}")
        if mode & stat.S_IWOTH:
            syntax_errors.append(f"world-writable executable: {path}")
    for path in tool_files:
        if path.suffix.lower() == ".py":
            failure = python_syntax(path)
            if failure:
                syntax_errors.append(f"{path}: {failure}")
    if syntax_errors:
        errors.extend(syntax_errors)
    result["syntax_permission_errors"] = syntax_errors

    history_dir = root / "patches/BQCA/policy-history"
    isolated = not str(history_dir.resolve()).startswith(str(bob.resolve()) + os.sep)
    if not isolated:
        errors.append("historical policy directory is inside active .bob context")
    result["historical_context_isolated"] = isolated

    result["policy_sha256"] = policy_hash
    result["errors"] = errors
    result["status"] = "PASS" if not errors else "FAIL"
    result["checked_utc"] = datetime.now(timezone.utc).isoformat()
    return result


def format_report(result: dict[str, object]) -> str:
    width = 88
    lines = [
        "=" * width,
        "BQCA v47 CANONICAL POLICY ASSURANCE REPORT",
        "=" * width,
        f"Assessment time             : {result.get('checked_utc')}",
        f"Canonical policy SHA-256    : {result.get('policy_sha256')}",
        f"Active policies             : {', '.join(result.get('active_policy_files', []))}",
        f"Custom mode blocks          : {result.get('custom_mode_blocks')}",
        f"Rules / Skills / Tools      : {result.get('rule_files')} / {result.get('skill_files')} / {result.get('tool_files')}",
        f"Legacy active blocks        : {result.get('legacy_blocks')}",
        f"History hash failures       : {result.get('history_hash_failures')}",
        f"Coverage errors             : {len(result.get('coverage_errors', []))}",
        f"Wrapper errors              : {len(result.get('wrapper_errors', []))}",
        f"Stale runtime files         : {len(result.get('stale_runtime_files', []))}",
        f"Syntax/permission errors    : {len(result.get('syntax_permission_errors', []))}",
        f"Historical context isolated : {'YES' if result.get('historical_context_isolated') else 'NO'}",
        "-" * width,
    ]
    errors = result.get("errors", [])
    if errors:
        lines.append("ISSUES")
        lines.extend(f"- {error}" for error in errors)
        lines.append("-" * width)
    lines.append(f"FINAL ASSURANCE STATUS      : {result.get('status')}")
    lines.append("=" * width)
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description="BQCA v47 policy doctor")
    parser.add_argument("command", choices=("check", "report"))
    parser.add_argument("--root", type=pathlib.Path, required=True)
    parser.add_argument("--output", type=pathlib.Path)
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args()
    result = check(args.root.resolve())
    report = format_report(result)
    if args.command == "report" or args.output:
        output = args.output or args.root / ".bob/patches-applied/BQCA.v47-assurance-report.txt"
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(report, encoding="utf-8")
    if not args.quiet:
        print(report, end="")
    print(f"BQCA_V47_POLICY_ASSURANCE={result['status']}", file=sys.stderr if result['status'] != 'PASS' else sys.stdout)
    return 0 if result["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
PY
  chmod 755 "$DOCTOR_PY"
}

write_doctor_sh() {
  cat > "$DOCTOR_SH" <<'SH'
#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
BOB_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
BQCA_ROOT="$(cd "$BOB_ROOT/.." && pwd -P)"
DOCTOR="$SCRIPT_DIR/bqca-policy-doctor.py"
PATCH="$BQCA_ROOT/patches/BQCA/patch-BQCA.v47-update-2.sh"
REPORT="$BOB_ROOT/patches-applied/BQCA.v47-assurance-report.txt"

usage() {
  cat <<'USAGE'
BQCA v47 policy doctor

Usage:
  bqca-policy-doctor.sh check [--quiet]
  bqca-policy-doctor.sh report
  bqca-policy-doctor.sh repair
USAGE
}

command_name="${1:-}"
[[ -n "$command_name" ]] || { usage; exit 2; }
shift || true
case "$command_name" in
  check)
    exec python3 "$DOCTOR" check --root "$BQCA_ROOT" "$@"
    ;;
  report)
    (($# == 0)) || { usage; exit 2; }
    exec python3 "$DOCTOR" report --root "$BQCA_ROOT" --output "$REPORT"
    ;;
  repair)
    (($# == 0)) || { usage; exit 2; }
    [[ -x "$PATCH" ]] || { printf 'BQCA v47 repair patch is missing: %s\n' "$PATCH" >&2; exit 2; }
    exec "$PATCH" --target "$BQCA_ROOT"
    ;;
  -h|--help) usage ;;
  *) usage >&2; exit 2 ;;
esac
SH
  chmod 755 "$DOCTOR_SH"
}

inject_awareness() {
  python3 - "$BQCA_ROOT" <<'PY'
from __future__ import annotations
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1])
bob = root / ".bob"
custom_modes = bob / "custom_modes.yaml"
extensions = {".md", ".txt", ".sh", ".py", ".yaml", ".yml"}

HTML_RE = re.compile(
    r"\n?<!--\s*BQCA-CANONICAL-PRODUCTION-POLICY-v\d+(?:-update-\d+)?:BEGIN\s*-->.*?"
    r"<!--\s*BQCA-CANONICAL-PRODUCTION-POLICY-v\d+(?:-update-\d+)?:END\s*-->\n?",
    re.S | re.I,
)
COMMENT_RE = re.compile(
    r"(?ms)^([ \t]*)# BQCA-CANONICAL-PRODUCTION-POLICY-v\d+(?:-update-\d+)?:BEGIN\n.*?"
    r"^\1# BQCA-CANONICAL-PRODUCTION-POLICY-v\d+(?:-update-\d+)?:END\n?"
)

html_block = """
<!-- BQCA-CANONICAL-PRODUCTION-POLICY-v47:BEGIN -->
The sole active BQCA policy is `.bob/BQCA-PRODUCTION-POLICY.md` (v47). Direct execution through `.bob/quantum-tools/bqca-direct-execution.sh` is the default for development, testing, interactive exploration, debugging, and quick experiments. Output must stream to the terminal while being captured to `<source-stem>-result-output.txt` and `output.txt`. Use `.bob/quantum-tools/bqca-policy-orchestrator.sh` only when formal compliance documentation, production deployment evidence, or audit validation is explicitly required. Historical policies are audit-only.
<!-- BQCA-CANONICAL-PRODUCTION-POLICY-v47:END -->
"""
comment_block = """# BQCA-CANONICAL-PRODUCTION-POLICY-v47:BEGIN
# The sole active BQCA policy is .bob/BQCA-PRODUCTION-POLICY.md (v47).
# Direct execution with live terminal output and dual result capture is the
# default. The orchestrator is optional and reserved for formal compliance,
# production-deployment evidence, and audit validation. Historical policies
# are audit-only and must not drive runtime decisions.
# BQCA-CANONICAL-PRODUCTION-POLICY-v47:END
"""

def clean(text: str) -> str:
    return COMMENT_RE.sub("", HTML_RE.sub("\n", text))

# custom_modes.yaml receives one indented block per customInstructions scalar.
text = clean(custom_modes.read_text(encoding="utf-8", errors="replace"))
lines = text.splitlines()
result = []
count = 0
pattern = re.compile(r"^(?P<indent>[ \t]*)customInstructions:\s*[>|][+-]?\s*(?:#.*)?$")
for line in lines:
    result.append(line)
    match = pattern.match(line)
    if not match:
        continue
    indent = match.group("indent") + "  "
    result.extend([
        f"{indent}# BQCA-CANONICAL-PRODUCTION-POLICY-v47:BEGIN",
        f"{indent}V47 EXECUTION AUTHORITY: Use .bob/BQCA-PRODUCTION-POLICY.md as the sole active policy. Direct execution through .bob/quantum-tools/bqca-direct-execution.sh is the default and must stream output to the terminal while capturing both <source-stem>-result-output.txt and output.txt. Use the orchestrator only for explicitly requested formal compliance, production deployment evidence, or audit validation. Historical policy files are audit-only.",
        f"{indent}# BQCA-CANONICAL-PRODUCTION-POLICY-v47:END",
    ])
    count += 1
if count == 0:
    raise SystemExit("No customInstructions block scalars found in custom_modes.yaml")
custom_modes.write_text("\n".join(result) + "\n", encoding="utf-8")

rules = sorted(
    path for directory in bob.glob("rules-*") if directory.is_dir()
    for path in directory.rglob("*") if path.is_file() and path.suffix.lower() in extensions
)
skills_root = bob / "skills"
skills = sorted(path for path in skills_root.rglob("*") if path.is_file() and path.suffix.lower() in extensions)
tools_root = bob / "quantum-tools"
tools = sorted(path for path in tools_root.iterdir() if path.is_file() and path.suffix.lower() in extensions)
for path in [*rules, *skills, *tools]:
    text = clean(path.read_text(encoding="utf-8", errors="replace")).rstrip() + "\n"
    block = html_block if path.suffix.lower() in {".md", ".txt"} else comment_block
    path.write_text(text + block, encoding="utf-8")
print(f"BQCA_V47_SURFACES modes={count} rules={len(rules)} skills={len(skills)} tools={len(tools)}")
PY
}

write_patch_record() {
  cat > "$PATCH_RECORD_FILE" <<RECORD
Patch: $PATCH_ID
Applied: $(date -u '+%Y-%m-%dT%H:%M:%SZ')
Root: $BQCA_ROOT
Backup: $BACKUP_DIR
Authority: .bob/BQCA-PRODUCTION-POLICY.md and BQCA-PRODUCTION-POLICY-v47.md
Default execution: .bob/quantum-tools/bqca-direct-execution.sh
Formal compliance: .bob/quantum-tools/bqca-policy-orchestrator.sh (optional)
Repair target: patches/BQCA/patch-BQCA.v47-update-2.sh
Protected assets: excluded and unchanged by installer
RECORD
}

normalize_permissions() {
  chmod 755 "$XLAUNCHPAD" "$DIRECT_EXECUTOR" "$LEGACY_DIRECT_EXECUTOR" "$DOCTOR_SH" "$DOCTOR_PY" \
            "$ORCHESTRATOR_SH" "$ORCHESTRATOR_PY" "$CANONICAL_PATCH_PATH" 2>/dev/null || true
  while IFS= read -r -d '' file; do chmod 755 "$file"; done < <(
    find "$TOOLS_DIR" -maxdepth 1 -type f \( -name '*.sh' -o -name '*.py' \) -print0
  )
  while IFS= read -r -d '' file; do chmod 755 "$file"; done < <(
    find "$BQCA_ROOT" -maxdepth 1 -type f -name 'bob-quantum-v*.sh' -print0
  )
  chmod 755 "$XLAUNCHPAD"
  chmod 644 "$POLICY_STABLE" "$POLICY_V47" "$REGISTRY" "$HISTORY_MANIFEST" 2>/dev/null || true
}

validate_direct_smoke() {
  local test_root test_home test_source log result mirror status
  test_root="$(mktemp -d)"
  test_home="$test_root/home"
  mkdir -p "$test_home" "$test_root/work"
  test_source="$test_root/work/v47-live-output.py"
  cat > "$test_source" <<'PY'
import sys
import time
print("V47_STDOUT_START", flush=True)
time.sleep(0.2)
print("V47_STDERR_VISIBLE", file=sys.stderr, flush=True)
print("BQCA_EXECUTION_TARGET=SIMULATOR", flush=True)
print("BQCA_PLAN=TEST", flush=True)
print("BQCA_BACKEND=local-test", flush=True)
print("BQCA_RESULT=42", flush=True)
PY
  log="$test_root/terminal.log"
  set +e
  HOME="$test_home" BQCA_V47_TEST_MODE=1 BQCA_V47_PYTHON_BIN="$(command -v python3)" \
    "$DIRECT_EXECUTOR" run "$test_source" >"$log" 2>&1
  status=$?
  set -e
  result="$test_root/work/v47-live-output-result-output.txt"
  mirror="$test_root/work/output.txt"
  [[ "$status" -eq 0 ]] || { cat "$log" >&2; rm -rf "$test_root"; return 1; }
  grep -q 'V47_STDOUT_START' "$log" || { rm -rf "$test_root"; return 1; }
  grep -q 'V47_STDERR_VISIBLE' "$log" || { rm -rf "$test_root"; return 1; }
  [[ -f "$result" && -f "$mirror" ]] || { rm -rf "$test_root"; return 1; }
  cmp -s "$result" "$mirror" || { rm -rf "$test_root"; return 1; }
  grep -q 'Execution successful    : YES' "$result" || { rm -rf "$test_root"; return 1; }
  rm -rf "$test_root"
}

validate_installation() {
  local failures=0
  validate_v47_policy || failures=$((failures+1))
  cmp -s "$POLICY_STABLE" "$POLICY_V47" || { warn "Stable and versioned v47 policies differ"; failures=$((failures+1)); }

  for file in "$XLAUNCHPAD" "$DIRECT_EXECUTOR" "$LEGACY_DIRECT_EXECUTOR" "$DOCTOR_SH" \
              "$ORCHESTRATOR_SH" "$TOOLS_DIR/qiskit-v2x-environment.sh" \
              "$TOOLS_DIR/qiskit-connector.sh" "$TOOLS_DIR/qca-code-quality-guard.sh"; do
    [[ -x "$file" ]] || { warn "Missing executable: $file"; failures=$((failures+1)); continue; }
    bash -n "$file" || failures=$((failures+1))
  done
  for file in "$DOCTOR_PY" "$ORCHESTRATOR_PY"; do
    [[ -x "$file" ]] || { warn "Missing executable: $file"; failures=$((failures+1)); continue; }
    python3 -m py_compile "$file" || failures=$((failures+1))
  done

  if ! "$DOCTOR_SH" check --quiet; then
    warn "v47 policy doctor failed; printing full report"
    "$DOCTOR_SH" report || true
    [[ -f "$ASSURANCE_REPORT" ]] && cat "$ASSURANCE_REPORT" >&2
    failures=$((failures+1))
  fi

  validate_direct_smoke || { warn "Direct-execution live-output smoke test failed"; failures=$((failures+1)); }

  if ((failures)); then
    fail "v47 Update 2 validation failed with $failures issue(s)."
  fi
  info "Validation passed: v47 policy, registry, awareness, runtime wiring, doctor, and direct execution are consistent."
}

write_direct_executor
write_legacy_direct_shim
patch_runtime_wiring
write_doctor_py
write_doctor_sh
inject_awareness
write_patch_record
normalize_permissions
validate_installation

info "Patch $PATCH_ID applied successfully."
info "Backup: $BACKUP_DIR"
info "Active policy: .bob/BQCA-PRODUCTION-POLICY.md (v47)"
info "Default execution: .bob/quantum-tools/bqca-direct-execution.sh"
info "Formal compliance: .bob/quantum-tools/bqca-policy-orchestrator.sh"
info "Protected assets were not touched."
