#!/usr/bin/env bash
set -Eeuo pipefail

#===============================================================================
# BQCA Direct Execution Default + Live Dual Output Patch v46
# File: patch-BQCA.v46.sh
#
# Purpose:
#   Consolidate any existing v45 execution guidance and make direct execution
#   the default for development/testing, interactive exploration, debugging,
#   and quick experiments. The canonical orchestrator remains available only
#   when the user explicitly requests formal compliance, production deployment,
#   formal documentation evidence, or audit enforcement.
#
#   Direct execution:
#     - executes Python directly from $HOME/qiskit-v2x-env using unbuffered
#       Python;
#     - mirrors combined stdout/stderr to the terminal while the process runs;
#     - records the same complete transcript in both:
#         <source-stem>-result-output.txt (authoritative per-source record), and
#         output.txt (latest-run compatibility mirror) beside the source;
#     - does not invoke the canonical orchestrator or its pre-execution
#       validation sequence.
#
#   Formal execution:
#     - is explicit and opt-in;
#     - continues to use bqca-policy-orchestrator.sh for full policy validation,
#       compliance reporting, production deployment, and audit use cases.
#
# Conflict consolidation:
#   v46 archives v45, removes v44/v45 active awareness blocks and universal
#   orchestrator-only execution wording, and installs one v46 awareness block
#   in every custom mode, rule, skill, and supported quantum tool.
#
# Protected paths:
#   This installer does not read, copy, back up, modify, chmod, remove, or
#   restore the BQCA project .env, $HOME/qiskit-v2x-env, or
#   $HOME/.qiskit/qiskit-ibm.json.
#===============================================================================

PATCH_ID="BQCA.v46"
PATCH_FILE_NAME="patch-BQCA.v46.sh"
TIMESTAMP="$(date +%Y%m%d%H%M%S)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
TARGET_OVERRIDE=""
DRY_RUN=0
VALIDATE_ONLY=0
ROLLBACK_DIR=""

info() { printf '[BQCA v46][INFO] %s\n' "$*"; }
warn() { printf '[BQCA v46][WARN] %s\n' "$*" >&2; }
fail() { printf '[BQCA v46][ERROR] %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'USAGE'
BQCA Direct Execution Default + Live Dual Output Patch v46

Usage:
  ./patch-BQCA.v46.sh [options]

Options:
  --target <path>        Explicit BQCA appliance root.
  --dry-run              Display the patch plan without changing files.
  --validate-only        Validate the current v46 installation.
  --rollback <backup>    Restore a v46 backup directory.
  -h, --help             Show this help.

Expected placement:
  <BQCA-root>/patches/BQCA/patch-BQCA.v46.sh
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

for cmd in bash chmod cmp cp date dd dirname find grep head mkdir mktemp mv python3 rm sha256sum sort tr wc; do
  command -v "$cmd" >/dev/null 2>&1 || fail "Required command not found: $cmd"
done

is_bqca_root() {
  local candidate="$1"
  [[ -d "$candidate/.bob" ]] || return 1
  [[ -f "$candidate/.bob/custom_modes.yaml" ]] || return 1
  [[ -d "$candidate/.bob/skills" ]] || return 1
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
CUSTOM_MODES="$BOB_ROOT/custom_modes.yaml"
XLAUNCHPAD="$BQCA_ROOT/xLaunchpad.sh"
POLICY_STABLE="$BOB_ROOT/BQCA-PRODUCTION-POLICY.md"
POLICY_V45="$BOB_ROOT/BQCA-PRODUCTION-POLICY-v45.md"
POLICY_V46="$BOB_ROOT/BQCA-PRODUCTION-POLICY-v46.md"
REGISTRY="$BOB_ROOT/BQCA-ACTIVE-POLICY-REGISTRY.json"
HISTORY_DIR="$BQCA_ROOT/patches/BQCA/policy-history"
HISTORY_MANIFEST="$HISTORY_DIR/BQCA-policy-history-manifest.json"
HISTORY_V45="$HISTORY_DIR/BQCA-PRODUCTION-POLICY-v45.md"
DIRECT_EXECUTOR="$TOOLS_DIR/bqca-direct-execution.sh"
LEGACY_DIRECT_EXECUTOR="$TOOLS_DIR/bqca-direct-execute.sh"
ORCHESTRATOR_SH="$TOOLS_DIR/bqca-policy-orchestrator.sh"
ORCHESTRATOR_PY="$TOOLS_DIR/bqca-policy-orchestrator.py"
DOCTOR_SH="$TOOLS_DIR/bqca-policy-doctor.sh"
DOCTOR_PY="$TOOLS_DIR/bqca-policy-doctor.py"
TEST_SUITE="$TOOLS_DIR/bqca-policy-test-suite.py"
RESULT_CAPTURE_PY="$TOOLS_DIR/qiskit-result-output.py"
RESULT_CAPTURE_SH="$TOOLS_DIR/qiskit-result-output.sh"
ENV_TOOL="$TOOLS_DIR/qiskit-v2x-environment.sh"
CONFIG_TOOL="$TOOLS_DIR/qiskit-configuration.sh"
CONNECTOR_TOOL="$TOOLS_DIR/qiskit-connector.sh"
QUALITY_GUARD="$TOOLS_DIR/qca-code-quality-guard.sh"
CODE_TEMPLATE="$TOOLS_DIR/qiskit-connector-required-template.py"
DESIGN_TEMPLATE="$TOOLS_DIR/qiskit-connector-design-required-template.md"
PATCHES_DIR="$BQCA_ROOT/patches/BQCA"
PATCH_RECORD_DIR="$BOB_ROOT/patches-applied"
PATCH_RECORD_FILE="$PATCH_RECORD_DIR/BQCA.v46.txt"
ASSURANCE_REPORT="$PATCH_RECORD_DIR/BQCA.v46-assurance-report.txt"
CANONICAL_PATCH="$PATCHES_DIR/$PATCH_FILE_NAME"
PREREQUISITE_RECORD="$PATCH_RECORD_DIR/BQCA.v45.txt"
BACKUP_ROOT="$BOB_ROOT/patch-backups"
BACKUP_DIR="$BACKUP_ROOT/${PATCH_ID}.${TIMESTAMP}"
BACKUP_FILE_LIST="$BACKUP_DIR/BQCA-v46-backed-up-files.txt"
CREATED_FILE_LIST="$BACKUP_DIR/BQCA-v46-created-files.txt"
AWARENESS_MARKER="BQCA-CANONICAL-PRODUCTION-POLICY-v46"

is_protected_path() {
  local path="$1" home_abs=""
  [[ "$path" == "$BQCA_ROOT/.env" ]] && return 0
  if [[ -n "${HOME:-}" ]]; then
    home_abs="$(cd "$HOME" 2>/dev/null && pwd -P || true)"
    [[ -n "$home_abs" && "$path" == "$home_abs/qiskit-v2x-env"* ]] && return 0
    [[ -n "$home_abs" && "$path" == "$home_abs/.qiskit/qiskit-ibm.json" ]] && return 0
  fi
  return 1
}

record_created() {
  local path="$1"
  [[ -e "$path" ]] && return 0
  mkdir -p "$BACKUP_DIR"
  printf '%s\n' "${path#$BQCA_ROOT/}" >> "$CREATED_FILE_LIST"
}

backup_file() {
  local source="$1" rel destination
  [[ -e "$source" ]] || return 0
  is_protected_path "$source" && return 0
  rel="${source#$BQCA_ROOT/}"
  destination="$BACKUP_DIR/$rel"
  mkdir -p "$(dirname "$destination")"
  cp -a "$source" "$destination"
  printf '%s\n' "$rel" >> "$BACKUP_FILE_LIST"
}

collect_active_files() {
  local directory
  for directory in "$BOB_ROOT"/rules-*; do
    [[ -d "$directory" ]] || continue
    find "$directory" -type f \
      \( -name '*.md' -o -name '*.txt' -o -name '*.sh' -o -name '*.py' -o -name '*.yaml' -o -name '*.yml' \) \
      -print0
  done
  if [[ -d "$BOB_ROOT/skills" ]]; then
    find "$BOB_ROOT/skills" -type f \
      \( -name '*.md' -o -name '*.txt' -o -name '*.sh' -o -name '*.py' -o -name '*.yaml' -o -name '*.yml' \) \
      -print0
  fi
  if [[ -d "$BOB_ROOT/quantum-tools" ]]; then
    find "$BOB_ROOT/quantum-tools" -maxdepth 1 -type f \
      \( -name '*.md' -o -name '*.txt' -o -name '*.sh' -o -name '*.py' -o -name '*.yaml' -o -name '*.yml' \) \
      -print0
  fi
}

create_backup() {
  mkdir -p "$BACKUP_DIR"
  : > "$BACKUP_FILE_LIST"
  : > "$CREATED_FILE_LIST"

  for file in \
    "$POLICY_STABLE" "$POLICY_V45" "$POLICY_V46" "$REGISTRY" "$HISTORY_MANIFEST" "$HISTORY_V45" \
    "$CUSTOM_MODES" "$XLAUNCHPAD" "$DIRECT_EXECUTOR" "$LEGACY_DIRECT_EXECUTOR" "$ORCHESTRATOR_SH" "$ORCHESTRATOR_PY" \
    "$DOCTOR_SH" "$DOCTOR_PY" "$TEST_SUITE" "$RESULT_CAPTURE_PY" "$RESULT_CAPTURE_SH" \
    "$ENV_TOOL" "$CONNECTOR_TOOL" "$QUALITY_GUARD" "$CODE_TEMPLATE" "$DESIGN_TEMPLATE" \
    "$PATCH_RECORD_FILE" "$ASSURANCE_REPORT" "$CANONICAL_PATCH"; do
    backup_file "$file"
  done

  while IFS= read -r -d '' file; do backup_file "$file"; done < <(collect_active_files)
  while IFS= read -r -d '' file; do backup_file "$file"; done < <(find "$BQCA_ROOT" -maxdepth 1 -type f -name 'bob-quantum-v*.sh' -print0)

  sort -u "$BACKUP_FILE_LIST" -o "$BACKUP_FILE_LIST"
  cat > "$BACKUP_DIR/BQCA-v46-backup-manifest.txt" <<MANIFEST
Patch: $PATCH_ID
Created: $(date -u '+%Y-%m-%dT%H:%M:%SZ')
Appliance root: $BQCA_ROOT
Protected paths intentionally excluded:
  .env
  \$HOME/qiskit-v2x-env
  \$HOME/.qiskit/qiskit-ibm.json
Restore with:
  $PATCH_FILE_NAME --target "$BQCA_ROOT" --rollback "$BACKUP_DIR"
MANIFEST
}

restore_backup() {
  local backup="$1" backup_abs source rel destination
  backup_abs="$(cd "$backup" 2>/dev/null && pwd -P || true)"
  [[ -n "$backup_abs" ]] || fail "Rollback directory not found: $backup"
  [[ -f "$backup_abs/BQCA-v46-backup-manifest.txt" ]] || fail "Not a BQCA v46 backup: $backup_abs"

  info "Restoring v46 backup: $backup_abs"
  while IFS= read -r -d '' source; do
    rel="${source#$backup_abs/}"
    case "$rel" in
      BQCA-v46-backup-manifest.txt|BQCA-v46-backed-up-files.txt|BQCA-v46-created-files.txt) continue ;;
    esac
    destination="$BQCA_ROOT/$rel"
    is_protected_path "$destination" && continue
    mkdir -p "$(dirname "$destination")"
    cp -a "$source" "$destination"
  done < <(find "$backup_abs" -mindepth 1 -type f -print0)

  if [[ -f "$backup_abs/BQCA-v46-created-files.txt" ]]; then
    while IFS= read -r rel; do
      [[ -n "$rel" ]] || continue
      destination="$BQCA_ROOT/$rel"
      is_protected_path "$destination" && continue
      [[ -e "$backup_abs/$rel" ]] || rm -f "$destination"
    done < "$backup_abs/BQCA-v46-created-files.txt"
  fi
  info "Rollback complete. Protected paths were not touched."
}

if [[ -n "$ROLLBACK_DIR" ]]; then
  restore_backup "$ROLLBACK_DIR"
  exit 0
fi

info "Resolved BQCA root: $BQCA_ROOT"
info "Patch identity: $PATCH_ID"
info "Protected paths: .env, qiskit-v2x-env, and qiskit-ibm.json are excluded from installer operations"

if ((VALIDATE_ONLY)); then
  [[ -f "$PATCH_RECORD_FILE" ]] || fail "BQCA v46 is not recorded as applied: $PATCH_RECORD_FILE"
  [[ -f "$POLICY_STABLE" && -f "$POLICY_V46" ]] || fail "The active v46 canonical policy files are missing."
elif [[ -f "$PATCH_RECORD_FILE" ]]; then
  [[ -f "$POLICY_STABLE" && -f "$POLICY_V46" ]] || fail "BQCA v46 is recorded but its active policy files are missing."
else
  if [[ ! -f "$PREREQUISITE_RECORD" && ! -f "$POLICY_V45" ]]; then
    fail "BQCA v45 is not available. Apply or restore the v45 live-output policy before v46."
  fi
  [[ -f "$POLICY_STABLE" && -f "$POLICY_V45" ]] || fail "The active v45 canonical policy files are missing."
fi

if ((DRY_RUN)); then
  cat <<'DRY'
[BQCA v46][DRY-RUN] Planned production changes:
  1. Archive and incorporate any active v45 policy before promoting v46.
  2. Make direct Python/notebook execution the default for:
       - development/testing;
       - interactive exploration;
       - debugging; and
       - quick experiments.
  3. Keep the orchestrator explicit and optional for:
       - formal documentation/compliance evidence;
       - production deployment; and
       - audit requirements.
  4. Install bqca-direct-execution.sh as the default execution entrypoint.
  5. Mirror combined stdout/stderr to the terminal live during execution.
  6. Record the complete transcript in both:
       - <source-stem>-result-output.txt; and
       - output.txt beside the source.
  7. Remove v44/v45 orchestrator-only execution wording and duplicate awareness blocks.
  8. Update all custom modes, rules, skills, and supported tools to one v46 awareness block.
  9. Update public wrappers so direct execution is the default and formal execution is explicit.
 10. Update the registry, policy history, doctor, assurance report, and behavioral tests.
 11. Leave .env, $HOME/qiskit-v2x-env, qiskit-ibm.json, and workload artifacts unchanged during installation.
DRY
  exit 0
fi

write_canonical_policy() {
  record_created "$POLICY_V46"
  record_created "$HISTORY_V45"
  mkdir -p "$HISTORY_DIR"
  if [[ -f "$POLICY_V45" ]]; then
    cp -a "$POLICY_V45" "$HISTORY_V45"
  elif [[ ! -f "$HISTORY_V45" ]]; then
    fail "Neither the active nor archived v45 policy is available for history."
  fi

  python3 - "$POLICY_STABLE" "$POLICY_V46" <<'PY'
from __future__ import annotations
import pathlib, re, sys
stable = pathlib.Path(sys.argv[1])
versioned = pathlib.Path(sys.argv[2])
text = stable.read_text(encoding="utf-8")
text = text.replace("Canonical Production Policy v45", "Canonical Production Policy v46")
text = text.replace("BQCA-CANONICAL-PRODUCTION-POLICY-v45", "BQCA-CANONICAL-PRODUCTION-POLICY-v46")
text = text.replace("Historical policies from v30 through v44", "Historical policies from v30 through v45")
text = text.replace("BQCA-PRODUCTION-POLICY-v45.md", "BQCA-PRODUCTION-POLICY-v46.md")

text = re.sub(
    r"All custom modes, rules, skills, and supported quantum tools must refer to the stable policy and route design, code, pre-execution, execution, result, and completion enforcement through `\.bob/quantum-tools/bqca-policy-orchestrator\.sh`\. `\.bob/quantum-tools/bqca-policy-doctor\.sh` verifies policy integrity, wrapper delegation, drift, and behavioral assurance\.",
    "All custom modes, rules, skills, and supported quantum tools must refer to the stable policy. Direct execution through `.bob/quantum-tools/bqca-direct-execution.sh` is the default for development/testing, interactive exploration, debugging, and quick experiments. The canonical orchestrator remains available only when formal compliance, production deployment, formal documentation evidence, or audit enforcement is explicitly requested. `.bob/quantum-tools/bqca-policy-doctor.sh` verifies policy integrity, execution routing, drift, and behavioral assurance.",
    text,
    count=1,
)

result_section = '''## 11. Live terminal and governed dual-result contract

Every direct or formal `.py`/`.ipynb` execution must provide live terminal visibility and durable evidence:

1. **Live terminal output:** combined workload stdout and stderr must be displayed continuously as the process produces it. Qiskit Connector, plan, backend, QPU, simulator, fallback, warning, error, progress, and result messages remain visible. End-only buffering is prohibited.
2. **Authoritative per-source result:** the same complete combined stream must be recorded in `<source-stem>-result-output.txt` beside the source artifact.
3. **Compatibility/latest-run mirror:** the same finalized professional report must also be written to `output.txt` in the source directory. The per-source result remains the authoritative durable record; `output.txt` is the latest-run convenience mirror.

Python execution must use unbuffered behavior (`PYTHONUNBUFFERED=1` and `python -u`). Both result files must include the full stream, start/completion date and time, duration, command, source, execution method, backend, plan, target, exit status, and bottom `RESULT SUMMARY`. For a final real-QPU result, the actual Job ID must be the first line of both finalized files.

Direct mode records policy gaps as non-blocking warnings while preserving the workload process exit status. Formal mode treats policy violations as blocking and is used only when explicitly requested.

'''
text = re.sub(r"## 11\.[\s\S]*?(?=## 12\.)", result_section, text, count=1)

section12 = '''## 12. Execution decision matrix and completion order

### Execution decision matrix

| Scenario | Default method | Reason |
|---|---|---|
| Development/Testing | Direct | Fast startup and real-time output |
| Interactive Exploration | Direct | Immediate feedback |
| Debugging | Direct | Clear live error messages |
| Quick Experiments | Direct | No orchestrator validation overhead |
| Formal Documentation | Orchestrator | Formal compliance reports |
| Production Deployment | Orchestrator | Full validation and completion gates |
| Audit Requirements | Orchestrator | Policy enforcement and auditable evidence |

### Direct execution (default)

1. Use `.bob/quantum-tools/bqca-direct-execution.sh`.
2. Confirm or prepare `$HOME/qiskit-v2x-env` and Qiskit 2.5+ without invoking the orchestrator.
3. Rebuild the `bqca` Qiskit account configuration when the configuration tool is available.
4. Execute Python directly with the authorized environment's Python in unbuffered mode.
5. Mirror combined stdout/stderr live to the terminal.
6. Produce `<source-stem>-result-output.txt` and `output.txt` beside the source.
7. Do not block a successful direct run solely because formal compliance markers are incomplete; record them as warnings.

### Formal execution (explicit opt-in)

1. Run the policy doctor.
2. Validate design/code and all canonical policy requirements.
3. Rebuild account configuration and activate the authorized environment.
4. Execute through `.bob/quantum-tools/bqca-policy-orchestrator.sh execute`.
5. Enforce the full result, notebook, secret-scan, compliance-report, and completion gates.
6. Report formal completion only when every canonical gate passes.

'''
text = re.sub(r"## 12\.[\s\S]*?(?=## 13\.)", section12, text, count=1)

section13 = '''## 13. Runtime assurance and conflict prevention

- Stable and versioned active policies must be byte-identical and match the registry SHA-256.
- Historical policy hashes must match the policy-history manifest.
- Every custom mode, rule, skill, and supported quantum tool must contain exactly one v46 canonical awareness block and no active v30-v45 block.
- Public execution wrappers default to `bqca-direct-execution.sh`; formal orchestrator execution requires an explicit formal command or flag.
- Universal orchestrator-only execution wording, direct-result-capture prohibitions, and v44/v45 execution routing blocks are conflicting guidance and must not remain active.
- `xLaunchpad.sh` performs the quiet policy-doctor preflight but must not force the orchestrator for ordinary direct execution.
- Compliance or result evidence that contains credential material is noncompliant.

'''
text = re.sub(r"## 13\.[\s\S]*?(?=## 14\.)", section13, text, count=1)

section14 = '''## 14. Historical disposition

Requirements from v30-v44 remain incorporated as documented by the registry and policy-history manifest. v45 is incorporated as the live-terminal and governed-result predecessor. v46 is the sole active authority and changes execution routing: direct execution is the default for development/testing, interactive exploration, debugging, and quick experiments; the orchestrator is explicit and optional for formal documentation, production deployment, and audit requirements.

'''
text = re.sub(r"## 14\.[\s\S]*?(?=<!-- BQCA-CANONICAL-PRODUCTION-POLICY-v46:END -->)", section14, text, count=1)

for forbidden in (
    "All public design, code, and execution routes must delegate through the canonical orchestrator.",
    "Public validation and execution wrappers must delegate through the canonical orchestrator.",
    "Direct invocation of the result-capture layer is prohibited",
):
    text = text.replace(forbidden, "")

required = (
    "Development/Testing",
    "bqca-direct-execution.sh",
    "output.txt",
    "formal compliance",
    "Direct mode records policy gaps as non-blocking warnings",
)
for token in required:
    if token not in text:
        raise SystemExit(f"Failed to install v46 policy token: {token}")
stable.write_text(text, encoding="utf-8")
versioned.write_text(text, encoding="utf-8")
PY
  if [[ -f "$POLICY_V45" ]]; then
    rm -f "$POLICY_V45"
  fi
}

update_registry_and_history() {
  python3 - "$POLICY_STABLE" "$REGISTRY" "$HISTORY_MANIFEST" "$HISTORY_V45" <<'PY'
from __future__ import annotations
import datetime as dt, hashlib, json, pathlib, sys
policy = pathlib.Path(sys.argv[1])
registry_path = pathlib.Path(sys.argv[2])
manifest_path = pathlib.Path(sys.argv[3])
history_v45 = pathlib.Path(sys.argv[4])
now = dt.datetime.now(dt.timezone.utc).isoformat()

def digest(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

registry = json.loads(registry_path.read_text(encoding="utf-8"))
registry["generated_utc"] = now
active = registry.setdefault("active_authority", {})
active.update({
    "version": "v46",
    "stable_policy": ".bob/BQCA-PRODUCTION-POLICY.md",
    "versioned_policy": ".bob/BQCA-PRODUCTION-POLICY-v46.md",
    "policy_sha256": digest(policy),
    "default_execution": ".bob/quantum-tools/bqca-direct-execution.sh",
    "formal_orchestrator": ".bob/quantum-tools/bqca-policy-orchestrator.sh",
    "doctor": ".bob/quantum-tools/bqca-policy-doctor.sh",
})
precedence = registry.setdefault("precedence", [])
precedence = [item for item in precedence if "delegate through the canonical orchestrator" not in item.lower()]
for statement in (
    "Direct execution is the default for development/testing, interactive exploration, debugging, and quick experiments.",
    "The canonical orchestrator is optional and explicit for formal documentation, production deployment, and audit requirements.",
    "Execution output is mirrored live to the terminal and finalized in both <source-stem>-result-output.txt and output.txt.",
):
    if statement not in precedence:
        precedence.append(statement)
registry["precedence"] = precedence
versions = registry.setdefault("versions", [])
for entry in versions:
    if entry.get("version") == "v45":
        entry["status"] = "incorporated"
        entry["scope"] = "live terminal mirroring and governed per-source result recording"
versions = [entry for entry in versions if entry.get("version") != "v46"]
versions.append({
    "version": "v46",
    "status": "active authority",
    "scope": "direct execution default, optional formal orchestration, live dual result recording",
})
registry["versions"] = versions
registry_path.write_text(json.dumps(registry, indent=2) + "\n", encoding="utf-8")

manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
manifest["generated_utc"] = now
entries = [entry for entry in manifest.setdefault("entries", []) if entry.get("version") != "v45"]
entries.append({
    "version": "v45",
    "status": "incorporated",
    "scope": "live terminal mirroring and governed per-source result recording",
    "original_path": ".bob/BQCA-PRODUCTION-POLICY-v45.md",
    "archive_path": "patches/BQCA/policy-history/BQCA-PRODUCTION-POLICY-v45.md",
    "sha256": digest(history_v45),
    "size_bytes": history_v45.stat().st_size,
})
manifest["entries"] = entries
manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
PY
}

write_result_capture() {
  cat > "$RESULT_CAPTURE_PY" <<'PY_RESULT'
#!/usr/bin/env python3
"""BQCA v46 live terminal mirror and dual governed result capture."""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import pathlib
import re
import shlex
import subprocess
import sys
import time
from typing import Iterable, BinaryIO

LINE = "=" * 88
SUBLINE = "-" * 88


def timestamp() -> str:
    return dt.datetime.now().astimezone().isoformat(timespec="seconds")


def source_digest(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def last_value(patterns: Iterable[str], text: str) -> str:
    values: list[str] = []
    for pattern in patterns:
        values.extend(re.findall(pattern, text, flags=re.I | re.M))
    return values[-1].strip() if values else ""


def detect_target(text: str) -> str:
    values = re.findall(r"(?:BQCA_)?EXECUTION_TARGET\s*[:=]\s*(REAL_QPU|SIMULATOR)", text, flags=re.I)
    if values:
        return values[-1].upper()
    if re.search(r"\busing\s+(?:a\s+)?real\s+qpu\b|\breal[-_ ]qpu\s+execution\b", text, re.I):
        return "REAL_QPU"
    if re.search(r"\busing\s+(?:the\s+)?simulator\b|\bsimulator\s+fallback\b", text, re.I):
        return "SIMULATOR"
    return "UNKNOWN"


def parse_metadata(text: str) -> dict[str, str]:
    return {
        "target": detect_target(text),
        "job_id": last_value((r"BQCA_JOB_ID\s*[:=]\s*([^\s]+)", r"\bJOB[ _-]?ID\s*[:=]\s*([^\s]+)", r"\bjob_id\s*[:=]\s*([^\s]+)"), text),
        "plan": last_value((r"BQCA_PLAN\s*[:=]\s*([^\r\n]+)", r"\bPLAN\s*[:=]\s*([^\r\n]+)"), text),
        "backend": last_value((r"BQCA_BACKEND\s*[:=]\s*([^\r\n]+)", r"\bBACKEND\s*[:=]\s*([^\r\n]+)"), text),
        "fallback": last_value((r"BQCA_FALLBACK_REASON\s*[:=]\s*([^\r\n]+)", r"\bFALLBACK_REASON\s*[:=]\s*([^\r\n]+)"), text),
    }


def notebook_outputs(path: pathlib.Path) -> str:
    if path.suffix.lower() != ".ipynb" or not path.is_file():
        return ""
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        return f"[BQCA] Unable to extract notebook cell outputs: {exc}\n"
    lines: list[str] = []
    for index, cell in enumerate(data.get("cells", []), start=1):
        if cell.get("cell_type") != "code":
            continue
        outputs = cell.get("outputs", [])
        if not outputs:
            continue
        lines.append(f"[Notebook code cell {index} outputs]\n")
        for output in outputs:
            output_type = output.get("output_type")
            if output_type == "stream":
                value = output.get("text", "")
                lines.extend(value if isinstance(value, list) else [str(value)])
            elif output_type in {"execute_result", "display_data"}:
                value = output.get("data", {}).get("text/plain", "")
                lines.extend(value if isinstance(value, list) else [str(value)])
            elif output_type == "error":
                lines.extend(str(item) + "\n" for item in output.get("traceback", []))
    return "".join(lines)


def field(label: str, value: object) -> str:
    return f"{label:<24}: {value}\n"


def provisional_header(source: pathlib.Path, canonical: pathlib.Path, mirror: pathlib.Path, command: list[str], started: str, method: str) -> bytes:
    text = "".join([
        LINE + "\n",
        "BQCA QUANTUM EXECUTION RESULT OUTPUT - IN PROGRESS\n",
        LINE + "\n",
        field("Source artifact", source),
        field("Result output", canonical),
        field("Compatibility output", mirror),
        field("Execution method", method),
        field("Started", started),
        field("Executed command", " ".join(shlex.quote(item) for item in command)),
        SUBLINE + "\n",
        "LIVE COMBINED EXECUTION OUTPUT (STDOUT + STDERR)\n",
        SUBLINE + "\n",
    ])
    return text.encode("utf-8", errors="replace")


def mirror_chunk(chunk: bytes, transcript: BinaryIO, outputs: list[BinaryIO]) -> None:
    transcript.write(chunk)
    transcript.flush()
    for stream in outputs:
        stream.write(chunk)
        stream.flush()
    try:
        sys.stdout.buffer.write(chunk)
        sys.stdout.buffer.flush()
    except (BrokenPipeError, OSError):
        pass


def run_live(command: list[str], source: pathlib.Path, canonical: pathlib.Path, mirror: pathlib.Path, started_at: str, method: str) -> tuple[int, str, str]:
    raw_path = canonical.with_name(f".{canonical.name}.raw.{os.getpid()}")
    spawn_error = ""
    return_code = 127
    env = os.environ.copy()
    env["PYTHONUNBUFFERED"] = "1"
    header = provisional_header(source, canonical, mirror, command, started_at, method)
    with raw_path.open("wb") as transcript, canonical.open("wb") as primary, mirror.open("wb") as compatibility:
        os.chmod(canonical, 0o644)
        os.chmod(mirror, 0o644)
        primary.write(header)
        compatibility.write(header)
        primary.flush()
        compatibility.flush()
        try:
            process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, bufsize=0, env=env)
            assert process.stdout is not None
            fd = process.stdout.fileno()
            while True:
                chunk = os.read(fd, 8192)
                if not chunk:
                    break
                mirror_chunk(chunk, transcript, [primary, compatibility])
            return_code = process.wait()
        except OSError as exc:
            spawn_error = str(exc)
            chunk = f"[BQCA v46] Unable to start execution command: {exc}\n".encode("utf-8", errors="replace")
            mirror_chunk(chunk, transcript, [primary, compatibility])
    raw = raw_path.read_bytes().decode("utf-8", errors="replace")
    raw_path.unlink(missing_ok=True)
    return return_code, raw, spawn_error


def build_report(*, source: pathlib.Path, canonical: pathlib.Path, mirror: pathlib.Path, command: list[str], raw_output: str,
                 return_code: int, started_at: str, completed_at: str, duration: float, spawn_error: str,
                 method: str) -> tuple[str, bool, bool, list[str]]:
    metadata = parse_metadata(raw_output)
    target = metadata["target"]
    job_id = metadata["job_id"]
    violations: list[str] = []
    if target == "UNKNOWN":
        violations.append("final execution target was not reported as REAL_QPU or SIMULATOR")
    if target == "REAL_QPU" and not job_id:
        violations.append("real-QPU execution did not report BQCA_JOB_ID/JOB ID")
    if spawn_error:
        violations.append(f"execution command could not start: {spawn_error}")

    formal = method.upper() == "FORMAL"
    successful = return_code == 0 and (not formal or not violations)
    compliant = not violations
    status = "SUCCESS" if successful else "FAILED"
    command_text = " ".join(shlex.quote(item) for item in command)
    lines: list[str] = []
    if target == "REAL_QPU":
        lines.append(f"JOB ID: {job_id or 'NOT REPORTED - POLICY WARNING'}\n")
    lines.extend([
        LINE + "\n", "BQCA QUANTUM EXECUTION RESULT OUTPUT\n", LINE + "\n",
        field("Execution status", status), field("Policy compliant", "YES" if compliant else "NO"),
        field("Compliance enforcement", "BLOCKING" if formal else "NON-BLOCKING"),
        field("Execution method", method.upper()), field("Execution target", target),
        field("Source artifact", source), field("Result output", canonical), field("Compatibility output", mirror),
        field("Started", started_at), field("Completed", completed_at), field("Duration seconds", f"{duration:.3f}"),
        field("Exit status", return_code), field("Plan", metadata["plan"] or "NOT REPORTED"),
        field("Backend", metadata["backend"] or "NOT REPORTED"),
        field("Job ID", job_id or "NOT APPLICABLE/NOT REPORTED"),
        field("Fallback reason", metadata["fallback"] or "NONE REPORTED"),
        field("Source SHA-256", source_digest(source)), field("Working directory", pathlib.Path.cwd()),
        field("Executed command", command_text), LINE + "\n",
        "COMPLETE COMBINED EXECUTION OUTPUT (STDOUT + STDERR)\n", SUBLINE + "\n",
    ])
    lines.append(raw_output if raw_output else "[No stdout or stderr was produced by the workload.]\n")
    if raw_output and not raw_output.endswith("\n"):
        lines.append("\n")
    lines.extend([
        SUBLINE + "\n", "RESULT SUMMARY\n", SUBLINE + "\n",
        field("Execution successful", "YES" if successful else "NO"),
        field("Result contract valid", "YES" if compliant else "NO"),
        field("Execution method", method.upper()),
        field("Final execution target", target), field("Real-QPU job ID", job_id or "N/A"),
        field("Backend", metadata["backend"] or "NOT REPORTED"), field("Plan", metadata["plan"] or "NOT REPORTED"),
        field("Process exit status", return_code), field("Completion date/time", completed_at),
        field("Total duration", f"{duration:.3f} seconds"), field("Source artifact", source),
        field("Result output", canonical), field("Compatibility output", mirror),
    ])
    if violations:
        lines.append("Policy/Execution warning(s):\n" if not formal else "Policy/Execution issue(s):\n")
        lines.extend(f"  - {item}\n" for item in violations)
    else:
        lines.append("Policy/Execution issue(s): NONE\n")
    lines.append(LINE + "\n")
    return "".join(lines), successful, compliant, violations


def atomic_write(path: pathlib.Path, text: str) -> None:
    temporary = path.with_name(f".{path.name}.tmp.{os.getpid()}")
    temporary.write_text(text, encoding="utf-8")
    os.chmod(temporary, 0o644)
    os.replace(temporary, path)


def main() -> int:
    parser = argparse.ArgumentParser(description="BQCA v46 live direct/formal execution capture")
    parser.add_argument("--source", required=True, type=pathlib.Path)
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    source = args.source.expanduser().resolve()
    if not source.is_file() or source.suffix.lower() not in {".py", ".ipynb"}:
        print(f"BQCA_RESULT_OUTPUT_V46=FAIL: invalid source artifact: {source}", file=sys.stderr)
        return 2
    command = list(args.command)
    if command and command[0] == "--":
        command = command[1:]
    if not command:
        print("BQCA_RESULT_OUTPUT_V46=FAIL: execution command is required after --", file=sys.stderr)
        return 2

    canonical = source.with_name(f"{source.stem}-result-output.txt")
    mirror = source.with_name("output.txt")
    method = os.environ.get("BQCA_EXECUTION_METHOD", "DIRECT").upper()
    if method not in {"DIRECT", "FORMAL"}:
        method = "DIRECT"
    started_at = timestamp()
    started_clock = time.monotonic()
    return_code, raw_output, spawn_error = run_live(command, source, canonical, mirror, started_at, method)

    if source.suffix.lower() == ".ipynb":
        extracted = notebook_outputs(source)
        if extracted:
            block = "\n" + SUBLINE + "\nEXTRACTED NOTEBOOK CELL OUTPUTS\n" + SUBLINE + "\n" + extracted
            try:
                sys.stdout.write(block)
                sys.stdout.flush()
            except BrokenPipeError:
                pass
            raw_output += block

    completed_at = timestamp()
    duration = time.monotonic() - started_clock
    report, successful, compliant, violations = build_report(
        source=source, canonical=canonical, mirror=mirror, command=command, raw_output=raw_output,
        return_code=return_code, started_at=started_at, completed_at=completed_at,
        duration=duration, spawn_error=spawn_error, method=method,
    )
    atomic_write(canonical, report)
    atomic_write(mirror, report)
    print(f"BQCA_RESULT_OUTPUT={canonical}")
    print(f"BQCA_OUTPUT_TXT={mirror}")
    print(f"BQCA_EXECUTION_METHOD={method}")
    print(f"BQCA_EXECUTION_SUCCESSFUL={'YES' if successful else 'NO'}")

    if return_code != 0:
        return return_code if 0 < return_code < 256 else 1
    if method == "FORMAL" and violations:
        return 46
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
# BQCA-CANONICAL-PRODUCTION-POLICY-v46:BEGIN
# v46 direct execution mirrors combined stdout/stderr live and writes both
# <source-stem>-result-output.txt and output.txt beside the source.
# Formal orchestrator execution is explicit and optional.
# BQCA-CANONICAL-PRODUCTION-POLICY-v46:END
PY_RESULT
  chmod 755 "$RESULT_CAPTURE_PY"

  cat > "$RESULT_CAPTURE_SH" <<'SH'
#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
CAPTURE="$SCRIPT_DIR/qiskit-result-output.py"
[[ -x "$CAPTURE" ]] || {
  printf 'BQCA_RESULT_OUTPUT_V46=FAIL: missing capture tool: %s\n' "$CAPTURE" >&2
  exit 2
}
exec env PYTHONUNBUFFERED=1 python3 -u "$CAPTURE" "$@"

# BQCA-CANONICAL-PRODUCTION-POLICY-v46:BEGIN
# The sole active policy is .bob/BQCA-PRODUCTION-POLICY-v46.md.
# Direct and formal execution may invoke this capture layer. It mirrors output
# live and writes both the canonical per-source result and output.txt.
# BQCA-CANONICAL-PRODUCTION-POLICY-v46:END
SH
  chmod 755 "$RESULT_CAPTURE_SH"
}

write_direct_executor() {
  record_created "$DIRECT_EXECUTOR"
  cat > "$DIRECT_EXECUTOR" <<'SH'
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
BQCA v46 direct execution controller

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

# BQCA-CANONICAL-PRODUCTION-POLICY-v46:BEGIN
# Direct execution is the default. Formal orchestrator execution is explicit.
# Live combined output is written to the terminal, the canonical result file,
# and output.txt beside the source.
# BQCA-CANONICAL-PRODUCTION-POLICY-v46:END
SH
  chmod 755 "$DIRECT_EXECUTOR"

  # Preserve the v45 command name as a compatibility entry point. It delegates
  # to the v46 executor, so callers cannot bypass live dual-output capture.
  cat > "$LEGACY_DIRECT_EXECUTOR" <<'SH'
#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
DIRECT="$SCRIPT_DIR/bqca-direct-execution.sh"
[[ -x "$DIRECT" ]] || {
  printf 'BQCA_DIRECT_EXECUTION_V46=FAIL: canonical direct executor missing: %s\n' "$DIRECT" >&2
  exit 2
}
case "${1:-}" in
  run|run-notebook|formal-run|decision-matrix|-h|--help)
    exec "$DIRECT" "$@"
    ;;
  "")
    exec "$DIRECT" --help
    ;;
  *)
    exec "$DIRECT" run "$@"
    ;;
esac

# BQCA-CANONICAL-PRODUCTION-POLICY-v46:BEGIN
# Compatibility wrapper: all execution delegates to bqca-direct-execution.sh.
# BQCA-CANONICAL-PRODUCTION-POLICY-v46:END
SH
  chmod 755 "$LEGACY_DIRECT_EXECUTOR"
}

patch_environment_tool() {
  python3 - "$ENV_TOOL" <<'PY'
from __future__ import annotations
import pathlib, re, sys
path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
text = re.sub(r'(?ms)^# BQCA-CANONICAL-ORCHESTRATOR-v4[45]:BEGIN\n.*?^# BQCA-CANONICAL-ORCHESTRATOR-v4[45]:END\n?', '', text)
text = re.sub(r'(?ms)^# BQCA-DIRECT-EXECUTION-v46:BEGIN\n.*?^# BQCA-DIRECT-EXECUTION-v46:END\n?', '', text)
block = '''# BQCA-DIRECT-EXECUTION-v46:BEGIN
DIRECT_EXECUTION_TOOL="$SCRIPT_DIR/bqca-direct-execution.sh"
if [[ "${BQCA_V46_FORMAL:-0}" != "1" && "${BQCA_V46_INTERNAL:-0}" != "1" ]]; then
  case "$command_name" in
    run)
      [[ -x "$DIRECT_EXECUTION_TOOL" ]] || { printf 'BQCA v46 direct execution tool is missing: %s\\n' "$DIRECT_EXECUTION_TOOL" >&2; exit 2; }
      exec "$DIRECT_EXECUTION_TOOL" run "$@"
      ;;
    run-notebook)
      [[ -x "$DIRECT_EXECUTION_TOOL" ]] || { printf 'BQCA v46 direct execution tool is missing: %s\\n' "$DIRECT_EXECUTION_TOOL" >&2; exit 2; }
      exec "$DIRECT_EXECUTION_TOOL" run-notebook "$@"
      ;;
  esac
fi
# BQCA-DIRECT-EXECUTION-v46:END
'''
needle = 'shift || true\n'
if needle not in text:
    raise SystemExit("Unable to locate command dispatch boundary in qiskit-v2x-environment.sh")
text = text.replace(needle, needle + '\n' + block, 1)
path.write_text(text, encoding="utf-8")
PY
  chmod 755 "$ENV_TOOL"
}

patch_connector_tool() {
  python3 - "$CONNECTOR_TOOL" <<'PY'
from __future__ import annotations
import pathlib, re, sys
path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
text = re.sub(r'(?ms)^# BQCA-CANONICAL-ORCHESTRATOR-v4[45]:BEGIN\n.*?^# BQCA-CANONICAL-ORCHESTRATOR-v4[45]:END\n?', '', text)
block = '''# BQCA-EXECUTION-ROUTING-v46:BEGIN
DIRECT_EXECUTION_TOOL="$SCRIPT_DIR/bqca-direct-execution.sh"
FORMAL_ORCHESTRATOR="$SCRIPT_DIR/bqca-policy-orchestrator.sh"
case "${1:-}" in
  --run-code)
    shift
    (($# >= 1)) || { printf 'A Python artifact is required.\\n' >&2; exit 2; }
    exec "$DIRECT_EXECUTION_TOOL" run "$@"
    ;;
  --run-notebook)
    shift
    (($# == 1)) || { printf 'One notebook artifact is required.\\n' >&2; exit 2; }
    exec "$DIRECT_EXECUTION_TOOL" run-notebook "$1"
    ;;
  --run-code-formal|--run-notebook-formal)
    shift
    (($# >= 1)) || { printf 'An executable artifact is required.\\n' >&2; exit 2; }
    exec "$DIRECT_EXECUTION_TOOL" formal-run "$@"
    ;;
  --validate-code)
    shift
    exec "$FORMAL_ORCHESTRATOR" validate-code "$@"
    ;;
  --validate-design)
    shift
    exec "$FORMAL_ORCHESTRATOR" validate-design "$@"
    ;;
esac
# BQCA-EXECUTION-ROUTING-v46:END
'''
needle = 'SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"\n'
if needle not in text:
    raise SystemExit("Unable to locate SCRIPT_DIR in qiskit-connector.sh")
text = text.replace(needle, needle + block, 1)
text = text.replace('  qiskit-connector.sh --run-notebook <file.ipynb>\n',
                    '  qiskit-connector.sh --run-notebook <file.ipynb>\n  qiskit-connector.sh --run-code-formal <file.py> [arguments...]\n  qiskit-connector.sh --run-notebook-formal <file.ipynb>\n')
path.write_text(text, encoding="utf-8")
PY
  chmod 755 "$CONNECTOR_TOOL"
}

patch_quality_guard() {
  python3 - "$QUALITY_GUARD" <<'PY'
from __future__ import annotations
import pathlib, re, sys
path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
text = re.sub(r'(?ms)^# BQCA-CANONICAL-ORCHESTRATOR-v4[45]:BEGIN\n.*?^# BQCA-CANONICAL-ORCHESTRATOR-v4[45]:END\n?', '', text)
block = '''# BQCA-EXECUTION-ROUTING-v46:BEGIN
DIRECT_EXECUTION_TOOL="$SCRIPT_DIR/bqca-direct-execution.sh"
FORMAL_ORCHESTRATOR="$SCRIPT_DIR/bqca-policy-orchestrator.sh"
case "${1:-}" in
  --execute)
    shift
    (($# >= 1)) || { printf 'A Python artifact is required.\\n' >&2; exit 2; }
    exec "$DIRECT_EXECUTION_TOOL" run "$@"
    ;;
  --formal-execute)
    shift
    (($# >= 1)) || { printf 'An executable artifact is required.\\n' >&2; exit 2; }
    exec "$DIRECT_EXECUTION_TOOL" formal-run "$@"
    ;;
  --validate)
    (($# == 2)) || { printf 'One Python artifact is required.\\n' >&2; exit 2; }
    exec "$FORMAL_ORCHESTRATOR" validate-code "$2"
    ;;
esac
# BQCA-EXECUTION-ROUTING-v46:END
'''
needle = 'SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"\n'
if needle not in text:
    raise SystemExit("Unable to locate SCRIPT_DIR in qca-code-quality-guard.sh")
text = text.replace(needle, needle + block, 1)
text = text.replace('  qca-code-quality-guard.sh --execute <file.py> [arguments...]\n',
                    '  qca-code-quality-guard.sh --execute <file.py> [arguments...]\n  qca-code-quality-guard.sh --formal-execute <file.py> [arguments...]\n')
path.write_text(text, encoding="utf-8")
PY
  chmod 755 "$QUALITY_GUARD"
}

patch_orchestrator() {
  python3 - "$ORCHESTRATOR_SH" "$ORCHESTRATOR_PY" <<'PY'
from __future__ import annotations
import pathlib, re, sys
sh = pathlib.Path(sys.argv[1])
py = pathlib.Path(sys.argv[2])
text = sh.read_text(encoding="utf-8")

text = re.sub(
    r'(?ms)^# BQCA-FORMAL-ORCHESTRATOR-v46:BEGIN\n.*?^# BQCA-FORMAL-ORCHESTRATOR-v46:END\n?',
    '',
    text,
)

# Normalize either v44 or v45 source variants into the optional v46 formal path.
for old in ('v44', 'v45'):
    text = text.replace(f'BQCA-PRODUCTION-POLICY-{old}.md', 'BQCA-PRODUCTION-POLICY-v46.md')
    text = text.replace(f'[BQCA {old}][ORCHESTRATOR][ERROR]', '[BQCA v46][FORMAL ORCHESTRATOR][ERROR]')
    text = text.replace(f'[BQCA {old}][ORCHESTRATOR]', '[BQCA v46][FORMAL ORCHESTRATOR]')
    text = text.replace(f'BQCA {old} canonical policy orchestrator', 'BQCA v46 optional formal policy orchestrator')
    text = text.replace(f'BQCA_{old.upper()}_COMPLETION_GATE=PASS', 'BQCA_V46_FORMAL_COMPLETION_GATE=PASS')

text = re.sub(
    r'(?:BQCA_V44_INTERNAL=1\s+BQCA_V44_ORCHESTRATED=1|'
    r'BQCA_V45_INTERNAL=1\s+BQCA_V45_ORCHESTRATED=1)\s+',
    'BQCA_V46_FORMAL=1 BQCA_V46_INTERNAL=1 '
    'BQCA_V44_INTERNAL=1 BQCA_V44_ORCHESTRATED=1 '
    'BQCA_V45_INTERNAL=1 BQCA_V45_ORCHESTRATED=1 ',
    text,
)

formal_block = '''# BQCA-FORMAL-ORCHESTRATOR-v46:BEGIN
# The orchestrator is explicit and optional. This flag keeps child wrapper calls
# on the formal path and prevents recursion into the direct-execution default.
export BQCA_V46_FORMAL=1
# BQCA-FORMAL-ORCHESTRATOR-v46:END
'''
needle = 'SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"\n'
if needle not in text:
    needle = 'SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"\n'
if needle not in text:
    raise SystemExit('Unable to locate SCRIPT_DIR in bqca-policy-orchestrator.sh')
text = text.replace(needle, needle + '\n' + formal_block, 1)
if 'optional formal policy orchestrator' not in text:
    text = text.replace(
        'usage() {',
        '# v46: optional formal policy orchestrator for compliance, production deployment, and audit.\nusage() {',
        1,
    )
sh.write_text(text, encoding="utf-8")

pyt = py.read_text(encoding="utf-8")
pyt = pyt.replace('BQCA v44 POLICY COMPLIANCE REPORT', 'BQCA v46 FORMAL POLICY COMPLIANCE REPORT')
pyt = pyt.replace('BQCA v45 POLICY COMPLIANCE REPORT', 'BQCA v46 FORMAL POLICY COMPLIANCE REPORT')
pyt = pyt.replace('BQCA-PRODUCTION-POLICY-v44', 'BQCA-PRODUCTION-POLICY-v46')
pyt = pyt.replace('BQCA-PRODUCTION-POLICY-v45', 'BQCA-PRODUCTION-POLICY-v46')
py.write_text(pyt, encoding="utf-8")
PY
  chmod 755 "$ORCHESTRATOR_SH" "$ORCHESTRATOR_PY"
}

patch_templates_and_launchers() {
  python3 - "$CODE_TEMPLATE" "$DESIGN_TEMPLATE" <<'PY'
import pathlib, sys
code = pathlib.Path(sys.argv[1])
design = pathlib.Path(sys.argv[2])
if code.is_file():
    text = code.read_text(encoding="utf-8", errors="replace")
    text = text.replace('.bob/quantum-tools/bqca-policy-orchestrator.sh execute <this-file.py>',
                        '.bob/quantum-tools/bqca-direct-execution.sh run <this-file.py>  # default\n  # For formal production/audit only: .bob/quantum-tools/bqca-direct-execution.sh formal-run <this-file.py>')
    code.write_text(text, encoding="utf-8")
if design.is_file():
    text = design.read_text(encoding="utf-8", errors="replace")
    text = text.replace('Execute through `.bob/quantum-tools/bqca-policy-orchestrator.sh execute`.',
                        'Execute directly through `.bob/quantum-tools/bqca-direct-execution.sh run` for development/testing, exploration, debugging, and quick experiments. Use `.bob/quantum-tools/bqca-direct-execution.sh formal-run` only for production deployment, formal documentation evidence, or audit requirements.')
    design.write_text(text, encoding="utf-8")
PY

  python3 - "$XLAUNCHPAD" <<'PY'
import pathlib, re, sys
path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding="utf-8")

# Accept mismatched BEGIN/END versions because the production launcher contains
# a v45 BEGIN marker paired with a v44 END marker.
text = re.sub(
    r'(?ms)^# BQCA-POLICY-ASSURANCE-v(?:44|45|46):BEGIN\n.*?^# BQCA-POLICY-ASSURANCE-v(?:44|45|46):END\n?',
    '',
    text,
)
text = re.sub(
    r'(?ms)^# BQCA-DIRECT-EXECUTION-EXPORT-v46:BEGIN\n.*?^# BQCA-DIRECT-EXECUTION-EXPORT-v46:END\n?',
    '',
    text,
)

block = '''# BQCA-POLICY-ASSURANCE-v46:BEGIN
_BQCA_POLICY_DOCTOR="${SCRIPT_DIR}/.bob/quantum-tools/bqca-policy-doctor.sh"
BQCA_DIRECT_EXECUTION_TOOL="${SCRIPT_DIR}/.bob/quantum-tools/bqca-direct-execution.sh"
BQCA_FORMAL_ORCHESTRATOR="${SCRIPT_DIR}/.bob/quantum-tools/bqca-policy-orchestrator.sh"
for _bqca_v46_tool in \
  "${_BQCA_POLICY_DOCTOR}" \
  "${BQCA_DIRECT_EXECUTION_TOOL}" \
  "${BQCA_FORMAL_ORCHESTRATOR}"; do
  if [[ ! -x "${_bqca_v46_tool}" ]]; then
    printf '[BQCA][ERROR] Required v46 policy tool is missing: %s\n' "${_bqca_v46_tool}" >&2
    exit 1
  fi
done
if ! "${_BQCA_POLICY_DOCTOR}" check --quiet; then
  printf '[BQCA][ERROR] BQCA v46 policy drift detected. Run: %s repair\n' \
    "${_BQCA_POLICY_DOCTOR}" >&2
  exit 1
fi
export BQCA_POLICY_DOCTOR="${_BQCA_POLICY_DOCTOR}"
export BQCA_DIRECT_EXECUTION_TOOL BQCA_FORMAL_ORCHESTRATOR
export BQCA_ACTIVE_POLICY="${SCRIPT_DIR}/.bob/BQCA-PRODUCTION-POLICY.md"
unset _bqca_v46_tool
# BQCA-POLICY-ASSURANCE-v46:END
'''
needle = 'set +a\n'
if needle not in text:
    raise SystemExit('Unable to locate the .env loading boundary in xLaunchpad.sh')
text = text.replace(needle, needle + '\n' + block + '\n', 1)
path.write_text(text, encoding="utf-8")
PY
  chmod 755 "$XLAUNCHPAD"


  while IFS= read -r -d '' launcher; do
    python3 - "$launcher" <<'PY'
import pathlib, re, sys
path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
text = re.sub(r'(?ms)^# BQCA-DIRECT-EXECUTION-EXPORT-v46:BEGIN\n.*?^# BQCA-DIRECT-EXECUTION-EXPORT-v46:END\n?', '', text)
block = '''# BQCA-DIRECT-EXECUTION-EXPORT-v46:BEGIN
BQCA_DIRECT_EXECUTION_TOOL="${SCRIPT_DIR}/.bob/quantum-tools/bqca-direct-execution.sh"
BQCA_FORMAL_ORCHESTRATOR="${SCRIPT_DIR}/.bob/quantum-tools/bqca-policy-orchestrator.sh"
export BQCA_DIRECT_EXECUTION_TOOL BQCA_FORMAL_ORCHESTRATOR
# BQCA-DIRECT-EXECUTION-EXPORT-v46:END
'''
needle = 'SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"\n'
if needle in text:
    text = text.replace(needle, needle + '\n' + block, 1)
else:
    text = block + '\n' + text
text = text.replace('BQCA-CANONICAL-ORCHESTRATOR-v45', 'BQCA-DIRECT-EXECUTION-v46')
path.write_text(text, encoding="utf-8")
PY
    chmod 755 "$launcher"
  done < <(find "$BQCA_ROOT" -maxdepth 1 -type f -name 'bob-quantum-v*.sh' -print0)
}

update_awareness_and_remove_conflicts() {
  python3 - "$BQCA_ROOT" <<'PY'
from __future__ import annotations
import pathlib, re, sys
root = pathlib.Path(sys.argv[1])
bob = root / '.bob'
marker = 'BQCA-CANONICAL-PRODUCTION-POLICY-v46'

custom = bob / 'custom_modes.yaml'
text = custom.read_text(encoding='utf-8')
text = re.sub(r'(?ms)^([ \t]*)# BQCA-CANONICAL-PRODUCTION-POLICY-v4[456]:BEGIN\n.*?^\1# BQCA-CANONICAL-PRODUCTION-POLICY-v4[456]:END\n?', '', text)
lines = text.splitlines()
result = []
count = 0
pattern = re.compile(r'^(?P<indent>[ \t]*)customInstructions:\s*[>|][+-]?\s*(?:#.*)?$')
for line in lines:
    result.append(line)
    match = pattern.match(line)
    if not match:
        continue
    indent = match.group('indent') + '  '
    result.extend([
        f'{indent}# {marker}:BEGIN',
        f'{indent}CANONICAL v46 POLICY: Direct execution through .bob/quantum-tools/bqca-direct-execution.sh is the default for development/testing, interactive exploration, debugging, and quick experiments. Use the orchestrator only when formal compliance, production deployment, formal documentation evidence, or audit enforcement is explicitly requested. During execution, mirror combined stdout/stderr live to the terminal and write both <source-stem>-result-output.txt and output.txt beside the source.',
        f'{indent}# {marker}:END',
    ])
    count += 1
if count == 0:
    raise SystemExit('No customInstructions block scalars found')
custom.write_text('\n'.join(result) + '\n', encoding='utf-8')

extensions = {'.md', '.txt', '.sh', '.py', '.yaml', '.yml'}
files = []
for directory in bob.glob('rules-*'):
    if directory.is_dir():
        files.extend(path for path in directory.rglob('*') if path.is_file() and path.suffix.lower() in extensions)
skills = bob / 'skills'
if skills.is_dir():
    files.extend(path for path in skills.rglob('*') if path.is_file() and path.suffix.lower() in extensions)
tools = bob / 'quantum-tools'
if tools.is_dir():
    files.extend(path for path in tools.iterdir() if path.is_file() and path.suffix.lower() in extensions)

conflict_phrases = (
    'Route all public design, code, execution, result, and completion paths through `bqca-policy-orchestrator.sh`.',
    'Route all public design, code, execution, result, and completion paths through bqca-policy-orchestrator.sh.',
    'use bqca-policy-orchestrator.sh as the completion gate',
    'Direct result-capture invocation is prohibited; use bqca-policy-orchestrator.sh execute.',
    'Public validation and execution wrappers must delegate through the canonical orchestrator.',
    'All public design, code, and execution routes must delegate through the canonical orchestrator.',
)
for path in sorted(set(files)):
    content = path.read_text(encoding='utf-8', errors='replace')
    content = re.sub(r'\n?<!-- BQCA-CANONICAL-PRODUCTION-POLICY-v4[456]:BEGIN -->.*?<!-- BQCA-CANONICAL-PRODUCTION-POLICY-v4[456]:END -->\n?', '\n', content, flags=re.S)
    content = re.sub(r'(?ms)^\s*# BQCA-CANONICAL-PRODUCTION-POLICY-v4[456]:BEGIN\n.*?^\s*# BQCA-CANONICAL-PRODUCTION-POLICY-v4[456]:END\n?', '', content)
    for phrase in conflict_phrases:
        content = content.replace(phrase, '')
    if path.suffix.lower() in {'.md', '.txt'}:
        block = f'''\n<!-- {marker}:BEGIN -->\nThe sole active BQCA policy is `.bob/BQCA-PRODUCTION-POLICY.md` (v46). Direct execution through `bqca-direct-execution.sh` is the default for development/testing, interactive exploration, debugging, and quick experiments. Use `bqca-policy-orchestrator.sh` only when formal compliance, production deployment, formal documentation evidence, or audit enforcement is explicitly requested. Mirror combined stdout/stderr live to the terminal and write both `<source-stem>-result-output.txt` and `output.txt` beside the source.\n<!-- {marker}:END -->\n'''
    else:
        block = f'''\n# {marker}:BEGIN\n# The sole active policy is .bob/BQCA-PRODUCTION-POLICY-v46.md.\n# v46 direct execution is the default for development/testing, exploration,\n# debugging, and quick experiments. The orchestrator is explicit and optional\n# for formal compliance, production deployment, and audit. Mirror output live\n# and write both <source-stem>-result-output.txt and output.txt.\n# {marker}:END\n'''
    path.write_text(content.rstrip() + '\n' + block, encoding='utf-8')
print(f'custom_modes={count} files={len(set(files))}')
PY
}

write_doctor() {
  cat > "$DOCTOR_PY" <<'PY'
#!/usr/bin/env python3
"""BQCA v46 direct-execution policy assurance and drift doctor."""
from __future__ import annotations
import argparse, hashlib, json, os, pathlib, re, stat, subprocess
from datetime import datetime, timezone

VERSION = "v46"
CANONICAL = "BQCA-CANONICAL-PRODUCTION-POLICY-v46"
LEGACY_VERSION = r"(?:v30|v31|v32|v33|v34|v35|v36|v37|v38|v39(?:-update-1)?|v40|v41|v42|v43|v44|v45)"
LEGACY_BLOCK = re.compile(rf"(?:<!--\s*BQCA-[^>\n]*{LEGACY_VERSION}:(?:POLICY-)?BEGIN\s*-->|^\s*#\s*BQCA-[^\n]*{LEGACY_VERSION}:(?:POLICY-)?BEGIN\s*$)", re.I | re.M)
TEXT_EXTENSIONS = {".md", ".txt", ".sh", ".py", ".yaml", ".yml"}


def sha256(path: pathlib.Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def supported_files(root: pathlib.Path):
    bob = root / ".bob"
    rules = sorted(path for directory in bob.glob("rules-*") if directory.is_dir() for path in directory.rglob("*") if path.is_file() and path.suffix.lower() in TEXT_EXTENSIONS)
    skills_root = bob / "skills"
    skills = sorted(path for path in skills_root.rglob("*") if path.is_file() and path.suffix.lower() in TEXT_EXTENSIONS) if skills_root.is_dir() else []
    tools_root = bob / "quantum-tools"
    tools = sorted(path for path in tools_root.iterdir() if path.is_file() and path.suffix.lower() in TEXT_EXTENSIONS) if tools_root.is_dir() else []
    return rules, skills, tools


def check(root: pathlib.Path) -> dict[str, object]:
    bob = root / ".bob"
    tools = bob / "quantum-tools"
    policy = bob / "BQCA-PRODUCTION-POLICY.md"
    versioned = bob / "BQCA-PRODUCTION-POLICY-v46.md"
    registry_path = bob / "BQCA-ACTIVE-POLICY-REGISTRY.json"
    manifest_path = root / "patches/BQCA/policy-history/BQCA-policy-history-manifest.json"
    custom = bob / "custom_modes.yaml"
    errors: list[str] = []
    checks: dict[str, object] = {}

    active_policies = {p.name for p in bob.glob("BQCA-*.md") if "POLICY" in p.name.upper()}
    expected = {"BQCA-PRODUCTION-POLICY.md", "BQCA-PRODUCTION-POLICY-v46.md"}
    if active_policies != expected:
        errors.append(f"active policy files differ from expected set: {sorted(active_policies)}")
    checks["active_policy_files"] = sorted(active_policies)

    policy_hash = ""
    if not policy.is_file() or not versioned.is_file():
        errors.append("canonical policy files are missing")
    else:
        policy_hash = sha256(policy)
        if policy.read_bytes() != versioned.read_bytes():
            errors.append("stable and versioned policies differ")
        ptext = policy.read_text(encoding="utf-8", errors="replace")
        for token in ("Execution decision matrix", "bqca-direct-execution.sh", "output.txt", "orchestrator is explicit and optional", "NON-BLOCKING"):
            if token.lower() not in ptext.lower():
                errors.append(f"canonical v46 token missing: {token}")
        for forbidden in ("Public validation and execution wrappers must delegate through the canonical orchestrator", "Direct invocation of the result-capture layer is prohibited"):
            if forbidden.lower() in ptext.lower():
                errors.append(f"conflicting orchestrator-only policy remains: {forbidden}")

    try:
        registry = json.loads(registry_path.read_text(encoding="utf-8"))
    except Exception as exc:
        registry = {}
        errors.append(f"invalid registry JSON: {exc}")
    active = registry.get("active_authority", {}) if isinstance(registry, dict) else {}
    if active.get("version") != "v46":
        errors.append("registry active authority is not v46")
    if active.get("policy_sha256") != policy_hash:
        errors.append("registry canonical policy hash mismatch")
    if active.get("default_execution") != ".bob/quantum-tools/bqca-direct-execution.sh":
        errors.append("registry default direct-execution path is incorrect")
    if active.get("formal_orchestrator") != ".bob/quantum-tools/bqca-policy-orchestrator.sh":
        errors.append("registry formal orchestrator path is incorrect")

    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except Exception as exc:
        manifest = {}
        errors.append(f"invalid history manifest: {exc}")
    history_failures = 0
    for entry in manifest.get("entries", []) if isinstance(manifest, dict) else []:
        archive = root / str(entry.get("archive_path", ""))
        if not archive.is_file() or sha256(archive) != entry.get("sha256"):
            history_failures += 1
            errors.append(f"history manifest mismatch: {archive}")
    checks["history_hash_failures"] = history_failures

    rules, skills, tool_files = supported_files(root)
    begin = CANONICAL + ":BEGIN"
    coverage_errors = []
    legacy_count = 0
    for path in [custom, *rules, *skills, *tool_files]:
        text = path.read_text(encoding="utf-8", errors="replace")
        legacy_count += len(LEGACY_BLOCK.findall(text))
        actual = len(re.findall(rf"(?m)^\s*(?:#\s*|<!--\s*){re.escape(begin)}(?:\s*-->)?\s*$", text))
        expected_count = len(re.findall(r"^\s*customInstructions:\s*[>|][+-]?\s*(?:#.*)?$", text, re.M)) if path == custom else 1
        if actual != expected_count:
            coverage_errors.append({"file": str(path.relative_to(root)), "expected": expected_count, "actual": actual})
    if legacy_count:
        errors.append(f"active legacy awareness blocks found: {legacy_count}")
    if coverage_errors:
        errors.append(f"canonical awareness coverage errors: {len(coverage_errors)}")
    checks["legacy_blocks"] = legacy_count
    checks["coverage_errors"] = coverage_errors
    checks["custom_mode_blocks"] = len(re.findall(r"^\s*customInstructions:\s*[>|][+-]?\s*(?:#.*)?$", custom.read_text(encoding="utf-8"), re.M))
    checks["rule_files"] = len(rules)
    checks["skill_files"] = len(skills)
    checks["tool_files"] = len(tool_files)

    wrapper_requirements = {
        root / "xLaunchpad.sh": ("BQCA-POLICY-ASSURANCE-v46:BEGIN", "bqca-direct-execution.sh"),
        tools / "bqca-direct-execution.sh": ("formal-run", "decision-matrix", "BQCA_EXECUTION_METHOD=DIRECT"),
        tools / "bqca-direct-execute.sh": ("bqca-direct-execution.sh", "exec \"$DIRECT\""),
        tools / "qiskit-v2x-environment.sh": ("BQCA-DIRECT-EXECUTION-v46:BEGIN", "DIRECT_EXECUTION_TOOL"),
        tools / "qiskit-connector.sh": ("BQCA-EXECUTION-ROUTING-v46:BEGIN", "--run-code-formal"),
        tools / "qca-code-quality-guard.sh": ("BQCA-EXECUTION-ROUTING-v46:BEGIN", "--formal-execute"),
        tools / "qiskit-result-output.sh": ("BQCA-CANONICAL-PRODUCTION-POLICY-v46:BEGIN", "python3 -u"),
        tools / "qiskit-result-output.py": ("output.txt", "sys.stdout.buffer.write", "NON-BLOCKING"),
        tools / "bqca-policy-orchestrator.sh": ("optional formal policy orchestrator", "BQCA_V46_FORMAL"),
    }
    wrapper_errors = []
    for path, required in wrapper_requirements.items():
        if not path.is_file():
            wrapper_errors.append(f"missing wrapper: {path}")
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        for token in required:
            if token not in text:
                wrapper_errors.append(f"{path.name} missing v46 token: {token}")
    if wrapper_errors:
        errors.extend(wrapper_errors)
    checks["wrapper_errors"] = wrapper_errors

    conflict_hits = []
    conflict_patterns = (
        "Direct result-capture invocation is prohibited",
        "Public validation and execution wrappers must delegate through the canonical orchestrator",
        "All public design, code, and execution routes must delegate through the canonical orchestrator",
        "use bqca-policy-orchestrator.sh as the completion gate",
    )
    for path in [custom, *rules, *skills, *tool_files]:
        if path.name == "bqca-policy-doctor.py":
            continue
        text = path.read_text(encoding="utf-8", errors="replace").lower()
        for phrase in conflict_patterns:
            if phrase.lower() in text:
                conflict_hits.append(f"{path.relative_to(root)}: {phrase}")
    if conflict_hits:
        errors.extend(conflict_hits)
    checks["conflict_hits"] = conflict_hits

    executable_targets = [
        root / "xLaunchpad.sh", tools / "bqca-direct-execution.sh", tools / "bqca-direct-execute.sh", tools / "bqca-policy-orchestrator.sh",
        tools / "bqca-policy-doctor.sh", tools / "qiskit-connector.sh", tools / "qca-code-quality-guard.sh",
        tools / "qiskit-v2x-environment.sh", tools / "qiskit-result-output.sh",
    ] + sorted(root.glob("bob-quantum-v*.sh"))
    syntax_errors = []
    for path in executable_targets:
        if not path.is_file():
            syntax_errors.append(f"missing executable: {path}")
            continue
        result = subprocess.run(["bash", "-n", str(path)], text=True, capture_output=True)
        if result.returncode:
            syntax_errors.append(f"{path}: {result.stderr.strip()}")
        mode = stat.S_IMODE(path.stat().st_mode)
        if not (mode & stat.S_IXUSR):
            syntax_errors.append(f"not owner-executable: {path}")
        if mode & stat.S_IWOTH:
            syntax_errors.append(f"world-writable executable: {path}")
    for path in tool_files:
        if path.suffix.lower() == ".py":
            try:
                compile(path.read_text(encoding="utf-8"), str(path), "exec")
            except Exception as exc:
                syntax_errors.append(f"{path}: {exc}")
    if syntax_errors:
        errors.extend(syntax_errors)
    checks["syntax_permission_errors"] = syntax_errors

    history_dir = root / "patches/BQCA/policy-history"
    checks["historical_context_isolated"] = not str(history_dir.resolve()).startswith(str(bob.resolve()) + os.sep)
    if not checks["historical_context_isolated"]:
        errors.append("historical policy directory is inside active .bob context")

    checks["policy_sha256"] = policy_hash
    checks["errors"] = errors
    checks["status"] = "PASS" if not errors else "FAIL"
    checks["checked_utc"] = datetime.now(timezone.utc).isoformat()
    return checks


def format_report(result: dict[str, object]) -> str:
    width = 88
    errors = result.get("errors", [])
    lines = [
        "=" * width,
        "BQCA v46 DIRECT EXECUTION POLICY ASSURANCE REPORT",
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
        f"Conflicting policy hits     : {len(result.get('conflict_hits', []))}",
        f"Syntax/permission errors    : {len(result.get('syntax_permission_errors', []))}",
        f"Historical context isolated : {'YES' if result.get('historical_context_isolated') else 'NO'}",
        "-" * width,
    ]
    if errors:
        lines.append("ISSUES")
        lines.extend(f"- {error}" for error in errors)
        lines.append("-" * width)
    lines.append(f"FINAL ASSURANCE STATUS      : {result.get('status')}")
    lines.append("=" * width)
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description="BQCA v46 policy doctor")
    parser.add_argument("command", choices=("check", "report"))
    parser.add_argument("--root", type=pathlib.Path, required=True)
    parser.add_argument("--output", type=pathlib.Path)
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args()
    result = check(args.root.resolve())
    report = format_report(result)
    if args.command == "report" or args.output:
        output = args.output or args.root / ".bob/patches-applied/BQCA.v46-assurance-report.txt"
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(report, encoding="utf-8")
    if not args.quiet:
        print(report, end="")
    return 0 if result["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())

# BQCA-CANONICAL-PRODUCTION-POLICY-v46:BEGIN
# The v46 doctor verifies direct execution routing, formal opt-in orchestration,
# live terminal output, and both result-output files.
# BQCA-CANONICAL-PRODUCTION-POLICY-v46:END
PY
  chmod 755 "$DOCTOR_PY"

  cat > "$DOCTOR_SH" <<'SH'
#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
BQCA_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
DOCTOR="$SCRIPT_DIR/bqca-policy-doctor.py"
PATCH="$BQCA_ROOT/patches/BQCA/patch-BQCA.v46.sh"
REPORT="$BQCA_ROOT/.bob/patches-applied/BQCA.v46-assurance-report.txt"
TEST_SUITE="$SCRIPT_DIR/bqca-policy-test-suite.py"

usage() {
  cat <<'USAGE'
BQCA v46 policy doctor

Usage:
  bqca-policy-doctor.sh check [--quiet]
  bqca-policy-doctor.sh report
  bqca-policy-doctor.sh repair
  bqca-policy-doctor.sh test
USAGE
}

case "${1:-}" in
  check)
    shift
    exec python3 "$DOCTOR" check --root "$BQCA_ROOT" "$@"
    ;;
  report)
    exec python3 "$DOCTOR" report --root "$BQCA_ROOT" --output "$REPORT"
    ;;
  repair)
    [[ -x "$PATCH" ]] || { printf 'BQCA v46 patch is unavailable: %s\n' "$PATCH" >&2; exit 2; }
    exec "$PATCH" --target "$BQCA_ROOT"
    ;;
  test)
    [[ -x "$TEST_SUITE" ]] || { printf 'BQCA v46 test suite is unavailable: %s\n' "$TEST_SUITE" >&2; exit 2; }
    exec python3 "$TEST_SUITE" --root "$BQCA_ROOT"
    ;;
  -h|--help|"")
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

# BQCA-CANONICAL-PRODUCTION-POLICY-v46:BEGIN
# The policy doctor verifies direct-default and formal-opt-in execution routing.
# BQCA-CANONICAL-PRODUCTION-POLICY-v46:END
SH
  chmod 755 "$DOCTOR_SH"
}

write_test_suite() {
  cat > "$TEST_SUITE" <<'PY'
#!/usr/bin/env python3
"""BQCA v46 direct execution behavioral smoke tests."""
from __future__ import annotations
import argparse, os, pathlib, subprocess, sys, tempfile, textwrap, time


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True, type=pathlib.Path)
    args = parser.parse_args()
    root = args.root.resolve()
    tools = root / ".bob/quantum-tools"
    direct = tools / "bqca-direct-execution.sh"
    with tempfile.TemporaryDirectory(prefix="bqca-v46-test-") as tmp_raw:
        temp = pathlib.Path(tmp_raw)
        source = temp / "direct-live.py"
        source.write_text(textwrap.dedent('''\
            import sys, time
            print("DIRECT_STDOUT_FIRST", flush=True)
            time.sleep(2.0)
            print("DIRECT_STDERR_SECOND", file=sys.stderr, flush=True)
            print("BQCA_EXECUTION_TARGET=SIMULATOR", flush=True)
            print("BQCA_PLAN=Open Plan", flush=True)
            print("BQCA_BACKEND=aer_simulator", flush=True)
            print("BQCA_RESULT=v46-direct-pass", flush=True)
        '''), encoding="utf-8")
        terminal = temp / "terminal.log"
        env = os.environ.copy()
        env.update({
            "BQCA_V46_TEST_MODE": "1",
            "BQCA_V46_SKIP_CONFIGURATION": "1",
            "BQCA_V46_TEST_PYTHON": sys.executable,
        })
        with terminal.open("wb") as stream:
            proc = subprocess.Popen([str(direct), "run", str(source)], stdout=stream, stderr=subprocess.STDOUT, env=env)
            deadline = time.time() + 1.5
            early = ""
            while time.time() < deadline:
                early = terminal.read_text(encoding="utf-8", errors="replace")
                if "DIRECT_STDOUT_FIRST" in early or proc.poll() is not None:
                    break
                time.sleep(0.1)
            if "DIRECT_STDOUT_FIRST" not in early:
                proc.kill()
                raise RuntimeError("v46 direct output did not reach the terminal live")
            if proc.poll() is not None:
                raise RuntimeError("v46 direct process ended before live-output assertion")
            status = proc.wait(timeout=10)
            if status != 0:
                raise RuntimeError(f"v46 direct execution returned {status}")
        canonical = temp / "direct-live-result-output.txt"
        mirror = temp / "output.txt"
        if not canonical.is_file() or not mirror.is_file():
            raise RuntimeError("v46 did not create both result files")
        if canonical.read_bytes() != mirror.read_bytes():
            raise RuntimeError("output.txt does not match the canonical result")
        report = canonical.read_text(encoding="utf-8", errors="replace")
        for token in ("DIRECT_STDOUT_FIRST", "DIRECT_STDERR_SECOND", "BQCA_RESULT=v46-direct-pass", "Execution method        : DIRECT", "Execution successful    : YES", "RESULT SUMMARY"):
            if token not in report:
                raise RuntimeError(f"v46 result report is missing: {token}")
        matrix = subprocess.run([str(direct), "decision-matrix"], text=True, capture_output=True)
        if matrix.returncode or "Production Deployment    Orchestrator" not in matrix.stdout:
            raise RuntimeError("v46 execution decision matrix is unavailable")
    print("BQCA_V46_TEST_SUITE=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

# BQCA-CANONICAL-PRODUCTION-POLICY-v46:BEGIN
# v46 direct execution test suite.
# BQCA-CANONICAL-PRODUCTION-POLICY-v46:END
PY
  chmod 755 "$TEST_SUITE"
}

repair_formal_orchestrator_v46() {
  python3 - "$ORCHESTRATOR_SH" "$ORCHESTRATOR_PY" <<'PY'
from __future__ import annotations
import pathlib, re, sys
sh = pathlib.Path(sys.argv[1])
py = pathlib.Path(sys.argv[2])
text = sh.read_text(encoding="utf-8")

text = re.sub(
    r'VERSIONED_POLICY="\$BOB_ROOT/BQCA-PRODUCTION-POLICY-v(?:44|45)\.md"',
    'VERSIONED_POLICY="$BOB_ROOT/BQCA-PRODUCTION-POLICY-v46.md"',
    text,
)
for old in (
    '[BQCA v44][ORCHESTRATOR]',
    '[BQCA v45][ORCHESTRATOR]',
):
    text = text.replace(old, '[BQCA v46][FORMAL ORCHESTRATOR]')
for old in (
    '[BQCA v44][ORCHESTRATOR][ERROR]',
    '[BQCA v45][ORCHESTRATOR][ERROR]',
):
    text = text.replace(old, '[BQCA v46][FORMAL ORCHESTRATOR][ERROR]')
text = text.replace('BQCA v44 canonical policy orchestrator', 'BQCA v46 optional formal policy orchestrator')
text = text.replace('BQCA v45 canonical policy orchestrator', 'BQCA v46 optional formal policy orchestrator')
text = text.replace('BQCA_V44_COMPLETION_GATE=PASS', 'BQCA_V46_FORMAL_COMPLETION_GATE=PASS')
text = text.replace('BQCA_V45_COMPLETION_GATE=PASS', 'BQCA_V46_FORMAL_COMPLETION_GATE=PASS')
text = text.replace('BQCA_V44_TEST_MODE', 'BQCA_V46_TEST_MODE')
text = text.replace('BQCA_V45_TEST_MODE', 'BQCA_V46_TEST_MODE')
text = text.replace('BQCA_V44_STATIC_ONLY', 'BQCA_V46_STATIC_ONLY')
text = text.replace('BQCA_V45_STATIC_ONLY', 'BQCA_V46_STATIC_ONLY')
text = re.sub(
    r'(?ms)^# BQCA-FORMAL-ORCHESTRATOR-GUARD-v46:BEGIN\n.*?^# BQCA-FORMAL-ORCHESTRATOR-GUARD-v46:END\n?',
    '',
    text,
)
guard = '''# BQCA-FORMAL-ORCHESTRATOR-GUARD-v46:BEGIN
export BQCA_EXECUTION_METHOD=FORMAL
export BQCA_V46_FORMAL=1
export BQCA_V46_INTERNAL=1
export BQCA_V45_INTERNAL=1
export BQCA_V45_ORCHESTRATED=1
export BQCA_V44_INTERNAL=1
export BQCA_V44_ORCHESTRATED=1
# BQCA-FORMAL-ORCHESTRATOR-GUARD-v46:END
'''
needle = 'STORE_DIR="$BQCA_ROOT/bob-quantum-store"\n'
if needle not in text:
    raise SystemExit('Unable to locate formal orchestrator variable boundary')
text = text.replace(needle, needle + '\n' + guard, 1)
sh.write_text(text, encoding="utf-8")

pyt = py.read_text(encoding="utf-8")
pyt = pyt.replace('BQCA v44 POLICY COMPLIANCE REPORT', 'BQCA v46 FORMAL POLICY COMPLIANCE REPORT')
pyt = pyt.replace('BQCA v45 POLICY COMPLIANCE REPORT', 'BQCA v46 FORMAL POLICY COMPLIANCE REPORT')
pyt = pyt.replace('BQCA-PRODUCTION-POLICY-v44', 'BQCA-PRODUCTION-POLICY-v46')
pyt = pyt.replace('BQCA-PRODUCTION-POLICY-v45', 'BQCA-PRODUCTION-POLICY-v46')
py.write_text(pyt, encoding="utf-8")
PY
  chmod 755 "$ORCHESTRATOR_SH" "$ORCHESTRATOR_PY"
}

patch_launch_assurance_v46() {
  python3 - "$XLAUNCHPAD" <<'PY'
import pathlib, re, sys
path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
text = re.sub(
    r'(?ms)^# BQCA-POLICY-ASSURANCE-v[^\n]*:BEGIN\n.*?^# BQCA-POLICY-ASSURANCE-v[^\n]*:END\n?',
    '',
    text,
)
text = re.sub(
    r'(?ms)^# BQCA-DIRECT-EXECUTION-EXPORT-v46:BEGIN\n.*?^# BQCA-DIRECT-EXECUTION-EXPORT-v46:END\n?',
    '',
    text,
)
block = '''# BQCA-POLICY-ASSURANCE-v46:BEGIN
_BQCA_DIRECT_EXECUTION_TOOL="${SCRIPT_DIR}/.bob/quantum-tools/bqca-direct-execution.sh"
_BQCA_FORMAL_ORCHESTRATOR="${SCRIPT_DIR}/.bob/quantum-tools/bqca-policy-orchestrator.sh"
_BQCA_POLICY_DOCTOR="${SCRIPT_DIR}/.bob/quantum-tools/bqca-policy-doctor.sh"
for _bqca_v46_required in \
  "${_BQCA_DIRECT_EXECUTION_TOOL}" \
  "${_BQCA_FORMAL_ORCHESTRATOR}" \
  "${_BQCA_POLICY_DOCTOR}"; do
  if [[ ! -x "${_bqca_v46_required}" ]]; then
    printf '[BQCA][ERROR] Required v46 policy tool is missing: %s\\n' \
      "${_bqca_v46_required}" >&2
    exit 1
  fi
done
if ! "${_BQCA_POLICY_DOCTOR}" check --quiet; then
  printf '[BQCA][ERROR] BQCA v46 policy drift detected. Run: %s repair\\n' \
    "${_BQCA_POLICY_DOCTOR}" >&2
  exit 1
fi
export BQCA_DIRECT_EXECUTION_TOOL="${_BQCA_DIRECT_EXECUTION_TOOL}"
export BQCA_FORMAL_ORCHESTRATOR="${_BQCA_FORMAL_ORCHESTRATOR}"
export BQCA_POLICY_ORCHESTRATOR="${_BQCA_FORMAL_ORCHESTRATOR}"
export BQCA_POLICY_DOCTOR="${_BQCA_POLICY_DOCTOR}"
export BQCA_ACTIVE_POLICY="${SCRIPT_DIR}/.bob/BQCA-PRODUCTION-POLICY.md"
unset _bqca_v46_required
# BQCA-POLICY-ASSURANCE-v46:END
'''
needle = 'set +a\n'
if needle not in text:
    raise SystemExit('Unable to locate environment-loading boundary in xLaunchpad.sh')
text = text.replace(needle, needle + '\n' + block + '\n', 1)
path.write_text(text, encoding="utf-8")
PY
  chmod 755 "$XLAUNCHPAD"
}

write_legacy_direct_shim() {
  local legacy="$TOOLS_DIR/bqca-direct-execute.sh"
  cat > "$legacy" <<'SH'
#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
DIRECT="$SCRIPT_DIR/bqca-direct-execution.sh"
[[ -x "$DIRECT" ]] || { printf 'BQCA v46 direct executor is missing: %s\n' "$DIRECT" >&2; exit 2; }
case "${1:-}" in
  run|run-notebook|formal-run|decision-matrix|-h|--help)
    exec "$DIRECT" "$@"
    ;;
  "")
    exec "$DIRECT" --help
    ;;
  *)
    exec "$DIRECT" run "$@"
    ;;
esac
# BQCA-CANONICAL-PRODUCTION-POLICY-v46:BEGIN
# Compatibility shim: ordinary invocations use the canonical v46 direct path.
# BQCA-CANONICAL-PRODUCTION-POLICY-v46:END
SH
  chmod 755 "$legacy"
}

write_patch_records() {
  record_created "$PATCH_RECORD_FILE"
  record_created "$ASSURANCE_REPORT"
  mkdir -p "$PATCH_RECORD_DIR"
  cat > "$PATCH_RECORD_FILE" <<RECORD
Patch: $PATCH_ID
Applied: $(date -u '+%Y-%m-%dT%H:%M:%SZ')
Root: $BQCA_ROOT
Backup: $BACKUP_DIR
Canonical authority: .bob/BQCA-PRODUCTION-POLICY.md (v46)
Default execution: .bob/quantum-tools/bqca-direct-execution.sh
Formal execution: .bob/quantum-tools/bqca-policy-orchestrator.sh (explicit opt-in only)
Output behavior: live terminal + <source-stem>-result-output.txt + output.txt
Protected paths: .env, \$HOME/qiskit-v2x-env, and \$HOME/.qiskit/qiskit-ibm.json excluded and unchanged
RECORD
}

install_patch_copy() {
  mkdir -p "$PATCHES_DIR"
  record_created "$CANONICAL_PATCH"
  local current
  current="$(cd "$(dirname "$0")" && pwd -P)/$(basename "$0")"
  if [[ "$current" != "$CANONICAL_PATCH" ]]; then
    cp "$0" "$CANONICAL_PATCH"
  fi
  chmod 755 "$CANONICAL_PATCH"
}

validate_direct_behavior() {
  BQCA_V46_TEST_MODE=1 BQCA_V46_SKIP_CONFIGURATION=1 BQCA_V46_TEST_PYTHON="$(command -v python3)" \
    python3 "$TEST_SUITE" --root "$BQCA_ROOT" >/dev/null
}

validate_installation() {
  local failures=0 expected_modes actual_modes awareness_failures=0 conflict_count=0
  [[ -f "$POLICY_STABLE" && -f "$POLICY_V46" ]] || { warn "Canonical v46 policies are missing"; failures=$((failures+1)); }
  if [[ -f "$POLICY_STABLE" && -f "$POLICY_V46" ]]; then
    cmp -s "$POLICY_STABLE" "$POLICY_V46" || { warn "Stable and versioned v46 policies differ"; failures=$((failures+1)); }
    grep -qi 'execution decision matrix' "$POLICY_STABLE" || { warn "Canonical policy lacks execution decision matrix"; failures=$((failures+1)); }
    grep -qi 'bqca-direct-execution.sh' "$POLICY_STABLE" || { warn "Canonical policy lacks direct execution tool"; failures=$((failures+1)); }
    grep -qi 'output.txt' "$POLICY_STABLE" || { warn "Canonical policy lacks output.txt mirror"; failures=$((failures+1)); }
  fi

  python3 - "$REGISTRY" "$POLICY_STABLE" <<'PY' || failures=$((failures+1))
import hashlib, json, pathlib, sys
registry = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
policy = pathlib.Path(sys.argv[2])
active = registry["active_authority"]
assert active["version"] == "v46"
assert active["versioned_policy"] == ".bob/BQCA-PRODUCTION-POLICY-v46.md"
assert active["default_execution"] == ".bob/quantum-tools/bqca-direct-execution.sh"
assert active["formal_orchestrator"] == ".bob/quantum-tools/bqca-policy-orchestrator.sh"
assert active["policy_sha256"] == hashlib.sha256(policy.read_bytes()).hexdigest()
PY

  for file in "$DIRECT_EXECUTOR" "$LEGACY_DIRECT_EXECUTOR" "$RESULT_CAPTURE_SH" "$ENV_TOOL" "$CONNECTOR_TOOL" "$QUALITY_GUARD" "$ORCHESTRATOR_SH" "$DOCTOR_SH" "$XLAUNCHPAD"; do
    [[ -x "$file" ]] || { warn "Missing executable: $file"; failures=$((failures+1)); continue; }
    bash -n "$file" || failures=$((failures+1))
  done
  while IFS= read -r -d '' launcher; do
    bash -n "$launcher" || failures=$((failures+1))
    grep -q 'BQCA-DIRECT-EXECUTION-EXPORT-v46:BEGIN' "$launcher" || { warn "Launcher lacks v46 direct-execution export: $launcher"; failures=$((failures+1)); }
  done < <(find "$BQCA_ROOT" -maxdepth 1 -type f -name 'bob-quantum-v*.sh' -print0)

  for file in "$RESULT_CAPTURE_PY" "$ORCHESTRATOR_PY" "$DOCTOR_PY" "$TEST_SUITE"; do
    [[ -x "$file" ]] || { warn "Missing executable: $file"; failures=$((failures+1)); continue; }
    python3 -m py_compile "$file" || failures=$((failures+1))
  done

  expected_modes="$(grep -Ec '^\s*customInstructions:\s*[>|][+-]?' "$CUSTOM_MODES" || true)"
  actual_modes="$(grep -c 'BQCA-CANONICAL-PRODUCTION-POLICY-v46:BEGIN' "$CUSTOM_MODES" || true)"
  [[ "$expected_modes" -eq "$actual_modes" && "$expected_modes" -gt 0 ]] || { warn "Custom mode awareness mismatch: expected=$expected_modes actual=$actual_modes"; failures=$((failures+1)); }

  while IFS= read -r -d '' file; do
    [[ "$(grep -Ec '^[[:space:]]*#[[:space:]]*BQCA-CANONICAL-PRODUCTION-POLICY-v46:BEGIN[[:space:]]*$|^[[:space:]]*<!--[[:space:]]*BQCA-CANONICAL-PRODUCTION-POLICY-v46:BEGIN[[:space:]]*-->[[:space:]]*$' "$file" || true)" -eq 1 ]] || awareness_failures=$((awareness_failures+1))
    if [[ "$file" != "$DOCTOR_PY" ]] && grep -Eqi 'Direct result-capture invocation is prohibited|Public validation and execution wrappers must delegate through the canonical orchestrator|All public design, code, and execution routes must delegate through the canonical orchestrator|use bqca-policy-orchestrator\.sh as the completion gate' "$file"; then
      conflict_count=$((conflict_count+1))
    fi
  done < <(collect_active_files)
  ((awareness_failures == 0)) || { warn "v46 awareness failures: $awareness_failures"; failures=$((failures+1)); }
  ((conflict_count == 0)) || { warn "Conflicting v45/orchestrator-only guidance remains in $conflict_count active file(s)"; failures=$((failures+1)); }

  validate_direct_behavior || { warn "Direct execution/live output behavioral test failed"; failures=$((failures+1)); }

  if [[ -x "$DOCTOR_SH" ]]; then
    "$DOCTOR_SH" check --quiet || failures=$((failures+1))
  fi

  if ((failures)); then
    fail "v46 validation failed with $failures issue(s)."
  fi

  "$DOCTOR_SH" report >/dev/null 2>&1 || true
  info "Validation passed: direct execution is default, formal orchestration is opt-in, and live output is captured in both result files; modes=$actual_modes."
}

if ((VALIDATE_ONLY)); then
  validate_installation
  exit 0
fi

create_backup
record_created "$POLICY_V46"
record_created "$HISTORY_V45"
record_created "$DIRECT_EXECUTOR"
record_created "$PATCH_RECORD_FILE"
record_created "$ASSURANCE_REPORT"

write_canonical_policy
update_registry_and_history
write_result_capture
write_direct_executor
patch_environment_tool
patch_connector_tool
patch_quality_guard
patch_orchestrator
repair_formal_orchestrator_v46
patch_templates_and_launchers
patch_launch_assurance_v46
write_legacy_direct_shim
update_awareness_and_remove_conflicts
write_doctor
write_test_suite
install_patch_copy
write_patch_records
validate_installation

info "Patch $PATCH_ID applied successfully."
info "Backup: $BACKUP_DIR"
info "Canonical policy: .bob/BQCA-PRODUCTION-POLICY.md (v46)"
info "Default execution: .bob/quantum-tools/bqca-direct-execution.sh"
info "Compatibility entry point: .bob/quantum-tools/bqca-direct-execute.sh"
info "Formal orchestrator: optional and explicit only"
info "Live output: terminal + <source-stem>-result-output.txt + output.txt"
info "Protected paths were not touched."
