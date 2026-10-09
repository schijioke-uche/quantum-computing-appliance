#!/usr/bin/env bash
set -Eeuo pipefail

#===============================================================================
# BQCA Bob Shell 2.x Resume Continuity Patch v51.3
# File: patch-BQCA-v51.3.sh
# Author: Dr. Jeffrey Chijioke-Uche, IBM Computer Scientist
#
# Purpose:
#   Repair BQCA menu option 5 for Bob Shell 2.x so that it:
#     1. always resumes under the quantum-qiskit-connector custom mode; and
#     2. resumes the latest real user task for the BQCA workspace, excluding
#        authentication-probe tasks created by bob-auth.sh.
#
#   The patch also isolates the Bob 2.x authentication probe in a temporary
#   workspace, preventing future authentication probes from becoming the
#   latest task in the BQCA project workspace.
#
# Expected placement:
#   <BQCA-root>/patches/BQCA/patch-BQCA-v51.3.sh
#
# Protected assets:
#   The installer does not read, copy, back up, modify, chmod, remove, or
#   restore .env, the active central policy, governed design/code stores,
#   $HOME/.bob, $HOME/qiskit-v2x-env, or $HOME/.qiskit/qiskit-ibm.json.
#===============================================================================

PATCH_ID="BQCA-v51.3"
PATCH_FILE_NAME="patch-BQCA-v51.3.sh"
TIMESTAMP="$(date +%Y%m%d%H%M%S)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
TARGET_OVERRIDE=""
DRY_RUN=0
VALIDATE_ONLY=0
ROLLBACK_DIR=""

info() { printf '[BQCA v51.3][INFO] %s\n' "$*"; }
warn() { printf '[BQCA v51.3][WARN] %s\n' "$*" >&2; }
fail() { printf '[BQCA v51.3][ERROR] %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'USAGE'
BQCA Bob Shell 2.x Resume Continuity Patch v51.3

Usage:
  ./patch-BQCA-v51.3.sh [options]

Options:
  --target <path>        Explicit standalone BQCA appliance root.
  --dry-run              Display the patch plan without changing files.
  --validate-only        Validate the installed v51.3 resume feature.
  --rollback <backup>    Restore a v51.3 timestamped backup directory.
  -h, --help             Show this help.

Expected placement:
  <BQCA-root>/patches/BQCA/patch-BQCA-v51.3.sh
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

for cmd in bash chmod cp date dirname find grep mkdir mktemp mv python3 rm sed sort tail sha256sum; do
  command -v "$cmd" >/dev/null 2>&1 || fail "Required command not found: $cmd"
done

is_bqca_root() {
  local candidate="$1"
  [[ -d "$candidate/.bob" ]] || return 1
  [[ -f "$candidate/.bob/custom_modes.yaml" ]] || return 1
  [[ -f "$candidate/xLaunchpad.sh" ]] || return 1
  [[ -f "$candidate/bob-auth.sh" ]] || return 1
  [[ -d "$candidate/bob-quantum-designs" ]] || return 1
  [[ -d "$candidate/bob-quantum-store" ]] || return 1
  [[ -d "$candidate/patches/BQCA" ]] || return 1
}

resolve_bqca_root() {
  local candidate dir
  if [[ -n "$TARGET_OVERRIDE" ]]; then
    candidate="$(cd "$TARGET_OVERRIDE" 2>/dev/null && pwd -P || true)"
    [[ -n "$candidate" ]] || fail "Target path does not exist: $TARGET_OVERRIDE"
    is_bqca_root "$candidate" || fail "Target is not a valid standalone BQCA root: $candidate"
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
  fail "Unable to locate the standalone BQCA root. Use --target <path>."
}

BQCA_ROOT="$(resolve_bqca_root)"
BOB_ROOT="$BQCA_ROOT/.bob"
TOOLS_DIR="$BOB_ROOT/quantum-tools"
CUSTOM_MODES="$BOB_ROOT/custom_modes.yaml"
BOB_AUTH="$BQCA_ROOT/bob-auth.sh"
ENV_EXAMPLE="$BQCA_ROOT/.env.example"
README_FILE="$BQCA_ROOT/README.md"
AGENTS_FILE="$BQCA_ROOT/AGENTS.md"
CORE_RULE="$BOB_ROOT/rules/00-bqca-core.md"
REGISTRY="$BOB_ROOT/BQCA-ACTIVE-POLICY-REGISTRY.json"
RESUME_PY="$TOOLS_DIR/bqca-bob2-resume.py"
RESUME_SH="$TOOLS_DIR/bqca-bob2-resume.sh"
DNA_DOCTOR_SH="$TOOLS_DIR/bqca-bob2-dna-doctor.sh"
POLICY_DOCTOR_SH="$TOOLS_DIR/bqca-policy-doctor.sh"
MODE_SYNC_SH="$TOOLS_DIR/bqca-custom-mode-rules.sh"
PATCH_RECORD_DIR="$BOB_ROOT/patches-applied"
PATCH_RECORD_FILE="$PATCH_RECORD_DIR/${PATCH_ID}.txt"
BACKUP_ROOT="$BOB_ROOT/patch-backups"
BACKUP_DIR="$BACKUP_ROOT/${PATCH_ID}.${TIMESTAMP}"
BACKUP_MANIFEST="$BACKUP_DIR/BQCA-v51.3-backup-manifest.txt"
MANAGED_PATHS="$BACKUP_DIR/managed-paths.txt"
RESUME_MARKER="BQCA-BOB2-RESUME-v51.3"
PROBE_MARKER="BQCA-BOB2-AUTH-PROBE-ISOLATION-v51.3"
DOC_MARKER="BQCA-RESUME-CONTINUITY-v51.3"

find_bob2_launcher() {
  local found
  found="$(find "$BQCA_ROOT" -maxdepth 1 -type f -name 'bob-quantum-v2.*.sh' -print | sort -V | tail -n 1)"
  [[ -n "$found" ]] || fail "No Bob Shell 2.x BQCA launcher found in $BQCA_ROOT"
  printf '%s\n' "$found"
}
BOB2_LAUNCHER="$(find_bob2_launcher)"

managed_paths() {
  cat <<EOF
${BOB2_LAUNCHER#$BQCA_ROOT/}
bob-auth.sh
.env.example
README.md
AGENTS.md
.bob/rules/00-bqca-core.md
.bob/BQCA-ACTIVE-POLICY-REGISTRY.json
.bob/quantum-tools/bqca-bob2-resume.py
.bob/quantum-tools/bqca-bob2-resume.sh
.bob/patches-applied/${PATCH_ID}.txt
EOF
}

backup_one() {
  local rel="$1" src="$BQCA_ROOT/$rel" dst="$BACKUP_DIR/$rel"
  [[ "$rel" != ".env" ]] || return 0
  [[ -e "$src" || -L "$src" ]] || return 0
  mkdir -p "$(dirname "$dst")"
  cp -a "$src" "$dst"
}

create_backup() {
  mkdir -p "$BACKUP_DIR"
  managed_paths > "$MANAGED_PATHS"
  while IFS= read -r rel; do
    [[ -n "$rel" ]] || continue
    backup_one "$rel"
  done < "$MANAGED_PATHS"

  cat > "$BACKUP_MANIFEST" <<EOF
Patch: $PATCH_ID
Created: $(date -u '+%Y-%m-%dT%H:%M:%SZ')
Appliance root: $BQCA_ROOT
Managed paths: managed-paths.txt
Protected: .env, active policy, governed stores, HOME/.bob, HOME/qiskit-v2x-env, HOME/.qiskit/qiskit-ibm.json
Restore with:
  $PATCH_FILE_NAME --target "$BQCA_ROOT" --rollback "$BACKUP_DIR"
EOF
}

restore_backup() {
  local backup="$1" backup_abs rel src dst
  backup_abs="$(cd "$backup" 2>/dev/null && pwd -P || true)"
  [[ -n "$backup_abs" ]] || fail "Rollback directory not found: $backup"
  [[ -f "$backup_abs/BQCA-v51.3-backup-manifest.txt" ]] || fail "Not a BQCA v51.3 backup: $backup_abs"
  [[ -f "$backup_abs/managed-paths.txt" ]] || fail "Backup managed-paths.txt is missing: $backup_abs"

  info "Restoring v51.3 backup: $backup_abs"
  while IFS= read -r rel; do
    [[ -n "$rel" ]] || continue
    [[ "$rel" != ".env" ]] || continue
    dst="$BQCA_ROOT/$rel"
    rm -rf "$dst"
    src="$backup_abs/$rel"
    if [[ -e "$src" || -L "$src" ]]; then
      mkdir -p "$(dirname "$dst")"
      cp -a "$src" "$dst"
    fi
  done < "$backup_abs/managed-paths.txt"

  info "Rollback complete. Protected assets were not touched."
}

if [[ -n "$ROLLBACK_DIR" ]]; then
  restore_backup "$ROLLBACK_DIR"
  exit 0
fi

info "Resolved BQCA root: $BQCA_ROOT"
info "Patch identity: $PATCH_ID"
info "Bob 2.x launcher: ${BOB2_LAUNCHER#$BQCA_ROOT/}"
info "Resume requirement: quantum-qiskit-connector mode plus latest non-authentication BQCA task"
info "Protected assets: .env, active policy, governed stores, home Bob/Qiskit state"

if ((DRY_RUN)); then
  cat <<'DRY'
[BQCA v51.3][DRY-RUN] Planned changes:
  1. Install a Bob 2.x task resolver that reads the current workspace task list.
  2. Exclude BQCA authentication-probe tasks such as BOB_AUTH_OK.
  3. Resolve the latest real user task by updatedAt and use its exact task ID.
  4. Force menu option 5 to use quantum-qiskit-connector mode.
  5. Invoke Bob as: bob chat --mode quantum-qiskit-connector --resume <task-id>.
  6. Isolate future Bob authentication probes in a temporary workspace.
  7. Add the production resume requirement to AGENTS.md, the core rule, docs, and registry.
  8. Preserve Bob 1.x resume behavior, active v48 policy, .env, and governed artifacts.
DRY
  exit 0
fi

normalize_permissions() {
  for file in "$BOB2_LAUNCHER" "$BOB_AUTH" "$RESUME_PY" "$RESUME_SH"; do
    if [[ -f "$file" ]]; then
      chmod 755 "$file"
    fi
  done
  for file in "$ENV_EXAMPLE" "$README_FILE" "$AGENTS_FILE" "$CORE_RULE" "$REGISTRY" "$PATCH_RECORD_FILE"; do
    if [[ -f "$file" ]]; then
      chmod 644 "$file"
    fi
  done
  return 0
}

write_resume_py() {
  cat > "$RESUME_PY" <<'PY'
#!/usr/bin/env python3
"""Resolve the latest real BQCA user task for Bob Shell 2.x resume."""
from __future__ import annotations

import argparse
import json
import pathlib
import re
import subprocess
import sys
import urllib.parse
from typing import Any

AUTH_TITLE_PATTERNS = (
    re.compile(r"\bBOB_AUTH_OK\b", re.IGNORECASE),
    re.compile(r"Return\s+exactly\s+.*AUTH_OK", re.IGNORECASE),
    re.compile(r"BQCA[_ -]?AUTH(?:ENTICATION)?[_ -]?PROBE", re.IGNORECASE),
    re.compile(r"authentication\s+probe", re.IGNORECASE),
)


def normalized_workspace(value: str) -> pathlib.Path | None:
    value = (value or "").strip()
    if not value:
        return None
    parsed = urllib.parse.urlparse(value)
    if parsed.scheme == "file":
        value = urllib.parse.unquote(parsed.path)
    try:
        return pathlib.Path(value).expanduser().resolve()
    except Exception:
        return None


def parse_payload(text: str) -> list[dict[str, Any]]:
    text = text.strip()
    if not text:
        return []
    tasks: list[dict[str, Any]] = []
    try:
        payload = json.loads(text)
    except Exception:
        payload = None
    if isinstance(payload, list):
        tasks.extend(item for item in payload if isinstance(item, dict))
    elif isinstance(payload, dict):
        if isinstance(payload.get("tasks"), list):
            tasks.extend(item for item in payload["tasks"] if isinstance(item, dict))
        elif "id" in payload:
            tasks.append(payload)
    if tasks:
        return tasks
    for raw in text.splitlines():
        raw = raw.strip()
        if not raw:
            continue
        try:
            item = json.loads(raw)
        except Exception:
            continue
        if isinstance(item, dict) and "id" in item:
            tasks.append(item)
    return tasks


def run_task_list(bob_bin: str, workspace: pathlib.Path) -> tuple[list[dict[str, Any]], str]:
    attempts = (
        [bob_bin, "--list-tasks", "all"],
        [bob_bin, "--list-tasks", "--limit", "1000"],
        [bob_bin, "--list-tasks"],
    )
    diagnostics: list[str] = []
    for command in attempts:
        try:
            result = subprocess.run(
                command,
                cwd=workspace,
                text=True,
                capture_output=True,
                check=False,
            )
        except FileNotFoundError:
            raise RuntimeError(f"Bob CLI not found: {bob_bin}")
        tasks = parse_payload(result.stdout)
        diagnostics.append(
            f"command={' '.join(command)} rc={result.returncode} parsed={len(tasks)}"
        )
        if result.returncode == 0 and tasks:
            return tasks, "; ".join(diagnostics)
    return [], "; ".join(diagnostics)


def is_auth_probe(task: dict[str, Any]) -> bool:
    title = str(task.get("title") or "")
    return any(pattern.search(title) for pattern in AUTH_TITLE_PATTERNS)


def task_updated_at(task: dict[str, Any]) -> int:
    value = task.get("updatedAt", 0)
    try:
        return int(value)
    except Exception:
        return 0


def eligible_tasks(tasks: list[dict[str, Any]], workspace: pathlib.Path) -> list[dict[str, Any]]:
    resolved_workspace = workspace.resolve()
    eligible: list[dict[str, Any]] = []
    for task in tasks:
        task_id = str(task.get("id") or "").strip()
        if not task_id or is_auth_probe(task):
            continue
        task_workspace = normalized_workspace(str(task.get("workspace") or ""))
        if task_workspace is not None and task_workspace != resolved_workspace:
            continue
        eligible.append(task)
    eligible.sort(key=task_updated_at, reverse=True)
    return eligible


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("resolve", "report"))
    parser.add_argument("--bob-bin", default="bob")
    parser.add_argument("--workspace", required=True, type=pathlib.Path)
    args = parser.parse_args()

    workspace = args.workspace.expanduser().resolve()
    if not workspace.is_dir():
        print(f"BQCA_RESUME=FAIL: workspace not found: {workspace}", file=sys.stderr)
        return 2

    try:
        tasks, diagnostic = run_task_list(args.bob_bin, workspace)
    except RuntimeError as exc:
        print(f"BQCA_RESUME=FAIL: {exc}", file=sys.stderr)
        return 2

    candidates = eligible_tasks(tasks, workspace)
    if args.command == "report":
        print("=" * 88)
        print("BQCA v51.3 BOB SHELL 2.x RESUME TASK REPORT")
        print("=" * 88)
        print(f"Workspace               : {workspace}")
        print(f"Tasks parsed            : {len(tasks)}")
        print(f"Eligible user tasks     : {len(candidates)}")
        print(f"Task-list diagnostics   : {diagnostic}")
        print("-" * 88)
        for task in candidates[:20]:
            print(
                f"{task_updated_at(task):>16}  {str(task.get('id')):<40}  "
                f"{str(task.get('status') or ''):<10}  {str(task.get('title') or '')}"
            )
        print("-" * 88)
        if candidates:
            print(f"Selected task           : {candidates[0].get('id')}")
            print("FINAL RESUME STATUS     : PASS")
            return 0
        print("Selected task           : NONE")
        print("FINAL RESUME STATUS     : FAIL")
        return 3

    if not candidates:
        print(
            "BQCA_RESUME=FAIL: no resumable user task exists for this BQCA workspace; "
            "authentication-probe tasks are intentionally excluded",
            file=sys.stderr,
        )
        return 3

    print(str(candidates[0]["id"]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

# BQCA-ACTIVE-CENTRAL-POLICY:BEGIN
# Resolve the active BQCA policy dynamically and preserve its design, code,
# security, artifact-routing, and execution requirements.
# BQCA-ACTIVE-CENTRAL-POLICY:END
# BQCA-BOB-SHELL-V2-DNA:BEGIN
# Bind resume behavior to AGENTS.md, the active central policy, current menu
# context, quantum-qiskit-connector mode, and the latest real user task.
# BQCA-BOB-SHELL-V2-DNA:END
PY
  chmod 755 "$RESUME_PY"
}

write_resume_sh() {
  cat > "$RESUME_SH" <<'SH'
#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PY_TOOL="${SCRIPT_DIR}/bqca-bob2-resume.py"
[[ -x "${PY_TOOL}" ]] || {
  printf 'BQCA_RESUME=FAIL: missing resume resolver: %s\n' "${PY_TOOL}" >&2
  exit 2
}
exec python3 "${PY_TOOL}" "$@"

# BQCA-ACTIVE-CENTRAL-POLICY:BEGIN
# Use the active central policy for every BQCA resume decision.
# BQCA-ACTIVE-CENTRAL-POLICY:END
# BQCA-BOB-SHELL-V2-DNA:BEGIN
# Resume the latest real user task under quantum-qiskit-connector mode.
# BQCA-BOB-SHELL-V2-DNA:END
SH
  chmod 755 "$RESUME_SH"
}

patch_bob_auth() {
  python3 - "$BOB_AUTH" "$PROBE_MARKER" <<'PY'
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
marker = sys.argv[2]
text = path.read_text(encoding="utf-8")
block = rf'''    # {marker}:BEGIN
    # Run the Bob 2.x backend probe in an isolated temporary workspace so the
    # probe cannot become the latest task in the BQCA project workspace.
    PROBE_TIMEOUT_SECONDS="${{BOB_AUTH_PROBE_TIMEOUT_SECONDS:-90}}"
    [[ "${{PROBE_TIMEOUT_SECONDS}}" =~ ^[0-9]+$ ]] || \
      fail "BOB_AUTH_PROBE_TIMEOUT_SECONDS must be an integer"

    PROBE_OUTPUT="$(mktemp "${{TMPDIR:-/tmp}}/bob-auth-v2.XXXXXX")"
    BQCA_AUTH_PROBE_WORKSPACE="$(mktemp -d "${{TMPDIR:-/tmp}}/bqca-auth-probe-workspace.XXXXXX")"
    chmod 700 "${{BQCA_AUTH_PROBE_WORKSPACE}}"

    PROBE_ARGS=(
      run
      --mode ask
      --format json
      --max-turns 1
      --disable-mcp
      --disable-subagents
      --workspace "${{BQCA_AUTH_PROBE_WORKSPACE}}"
      --trust
      --accept-license
    )

    # General-scope API keys require a team context; inference-scope keys do not.
    if [[ -n "${{BOB_TEAM_ID:-}}" ]]; then
      PROBE_ARGS+=(--team-id "${{BOB_TEAM_ID}}")
    fi

    PROBE_PROMPT="${{BOB_AUTH_PROBE_PROMPT:-BQCA_AUTH_PROBE: Return exactly BOB_AUTH_OK and nothing else.}}"

    set +e
    if command -v timeout >/dev/null 2>&1; then
      timeout "${{PROBE_TIMEOUT_SECONDS}}s" \
        "${{BOB_BIN}}" "${{PROBE_ARGS[@]}}" "${{PROBE_PROMPT}}" \
        >"${{PROBE_OUTPUT}}" 2>&1
      PROBE_STATUS=$?
    else
      "${{BOB_BIN}}" "${{PROBE_ARGS[@]}}" "${{PROBE_PROMPT}}" \
        >"${{PROBE_OUTPUT}}" 2>&1
      PROBE_STATUS=$?
    fi
    set -e

    rm -rf "${{BQCA_AUTH_PROBE_WORKSPACE}}"
    unset BQCA_AUTH_PROBE_WORKSPACE
    # {marker}:END
'''
marker_re = re.compile(
    rf'(?ms)^    # {re.escape(marker)}:BEGIN\n.*?^    # {re.escape(marker)}:END\n?'
)
if marker_re.search(text):
    text = marker_re.sub(lambda _match: block, text, count=1)
else:
    old = re.compile(
        r'(?ms)^    PROBE_TIMEOUT_SECONDS=.*?^    set -e\n'
    )
    if not old.search(text):
        raise SystemExit("Unable to locate Bob 2.x authentication probe block")
    text = old.sub(lambda _match: block, text, count=1)
path.write_text(text, encoding="utf-8")
PY
  chmod 755 "$BOB_AUTH"
}

patch_launcher() {
  python3 - "$BOB2_LAUNCHER" "$RESUME_MARKER" <<'PY'
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
marker = sys.argv[2]
text = path.read_text(encoding="utf-8")
text = re.sub(
    rf'(?ms)^# {re.escape(marker)}:BEGIN\n.*?^# {re.escape(marker)}:END\n?',
    '',
    text,
)

anchor = '# BQCA-BOB2-CUSTOM-MODE-ROUTING-v51.2:END\n'
if anchor not in text:
    anchor = '# BQCA-BOB2-MODE-BRIDGE-v51.1:END\n'
if anchor not in text:
    raise SystemExit("Unable to locate the Bob 2.x mode-routing anchor")

block = rf'''# {marker}:BEGIN
# Production option-5 contract:
#   - always resume under quantum-qiskit-connector;
#   - select the latest real user task for this workspace;
#   - never resume authentication-probe tasks.
BQCA_BOB2_RESUME_MODE="${{BQCA_BOB2_RESUME_MODE:-quantum-qiskit-connector}}"
BQCA_BOB2_RESUME_TOOL="${{SCRIPT_DIR}}/.bob/quantum-tools/bqca-bob2-resume.sh"
export BQCA_BOB2_RESUME_MODE BQCA_BOB2_RESUME_TOOL

bqca_bob2_resolve_resume_mode_v513() {{
  local configured
  configured="$(bqca_trim_mode_value "${{BQCA_BOB2_RESUME_MODE:-}}")"
  if [[ -z "${{configured}}" ]]; then
    configured="quantum-qiskit-connector"
  fi
  if [[ "${{configured}}" != "quantum-qiskit-connector" ]]; then
    printf '[BQCA][ERROR] Option 5 requires BQCA_BOB2_RESUME_MODE=quantum-qiskit-connector; actual: %s\n' "${{configured}}" >&2
    return 1
  fi
  bqca_bob2_require_mode "${{configured}}"
}}

bqca_bob2_latest_user_task_v513() {{
  [[ -x "${{BQCA_BOB2_RESUME_TOOL}}" ]] || {{
    printf '[BQCA][ERROR] Bob 2.x resume resolver is missing: %s\n' "${{BQCA_BOB2_RESUME_TOOL}}" >&2
    return 1
  }}
  "${{BQCA_BOB2_RESUME_TOOL}}" resolve \
    --bob-bin "${{BOB_BIN}}" \
    --workspace "${{SCRIPT_DIR}}"
}}

bqca_bob2_resume_last_user_session_v513() {{
  local resume_mode task_id
  resume_mode="$(bqca_bob2_resolve_resume_mode_v513)" || return 1
  task_id="$(bqca_bob2_latest_user_task_v513)" || return 1
  printf '%bResuming the latest BQCA user session with mode %s...%b\n' \
    "${{BOLD}}${{YELLOW}}" "${{resume_mode}}" "${{RESET}}"
  bqca_bob2_chat "${{resume_mode}}" "${{task_id}}"
}}
# {marker}:END
'''
text = text.replace(anchor, anchor + '\n' + block + '\n', 1)

# A resumed task must still carry an explicit, validated BQCA mode.
already_guarded = re.search(
    r'(?ms)bqca_bob2_chat\(\) \{\n\s+local selected_mode="\$\{1:-\}"\n\s+local resume_task="\$\{2:-\}"\n\s+selected_mode="\$\(bqca_bob2_require_mode "\$\{selected_mode\}"\)" \|\| return 1\n',
    text,
)
if not already_guarded:
    old_chat_guard = re.compile(
        r'''(?ms)(bqca_bob2_chat\(\) \{\n\s+local selected_mode="\$\{1:-\}"\n\s+local resume_task="\$\{2:-\}"\n)\s+if \[\[ -z "\$\{resume_task\}" \]\]; then\n\s+selected_mode="\$\(bqca_bob2_require_mode "\$\{selected_mode\}"\)" \|\| return 1\n\s+fi\n'''
    )
    def replace_chat_guard(match):
        return match.group(1) + '  selected_mode="$(bqca_bob2_require_mode "${selected_mode}")" || return 1\n'
    text, count = old_chat_guard.subn(replace_chat_guard, text, count=1)
    if count != 1:
        raise SystemExit("Unable to update bqca_bob2_chat mode validation")

# Replace option 5 completely so it cannot fall back to Agent mode or resume an
# authentication probe via the ambiguous 'latest' token.
option5 = re.compile(r'(?ms)^  5\)\n.*?^    ;;\n\n(?=  0\))')
new_option5 = r'''  5)
    bqca_set_menu_context "5" "Resume BQCA Last Activity" "Resume Session" "quantum-qiskit-connector"
    printf '%bYou Selected BQCA Quantum Resume for Return to Last Activity, please wait ⏳%b\n' \
      "${BOLD}${YELLOW}" \
      "${RESET}"

    quantum_resume() {
      if bqca_is_bob2; then
        bqca_bob2_resume_last_user_session_v513
      else
        "${BOB_BIN}" \
          --resume latest \
          --instance-id "${BOB_INSTANCE_ID}" \
          --include-directories "${BOB_INCLUDED_DIRECTORY}" \
          --hide-intermediary-output
      fi
    }

    quantum_resume
    ;;

'''
text, count = option5.subn(lambda _match: new_option5, text, count=1)
if count != 1:
    raise SystemExit("Unable to replace menu option 5")

path.write_text(text, encoding="utf-8")
PY
  chmod 755 "$BOB2_LAUNCHER"
}

patch_env_example() {
  python3 - "$ENV_EXAMPLE" <<'PY'
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
key = "BQCA_BOB2_RESUME_MODE"
value = "quantum-qiskit-connector"
pattern = re.compile(rf'(?m)^{re.escape(key)}=.*$')
if pattern.search(text):
    text = pattern.sub(f"{key}={value}", text, count=1)
else:
    needle = re.compile(r'(?m)^BQCA_BOB2_ADVANCED_MODE=.*$')
    if needle.search(text):
        match = needle.search(text)
        text = text[:match.end()] + f"\n{key}={value}" + text[match.end():]
    else:
        text = text.rstrip() + f"\n{key}={value}\n"
path.write_text(text, encoding="utf-8")
PY
  chmod 644 "$ENV_EXAMPLE"
}

patch_markdown_document() {
  local file="$1" title="$2" body="$3"
  [[ -f "$file" ]] || return 0
  python3 - "$file" "$DOC_MARKER" "$title" "$body" <<'PY'
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
marker = sys.argv[2]
title = sys.argv[3]
body = sys.argv[4]
text = path.read_text(encoding="utf-8")
text = re.sub(
    rf'(?ms)\n?<!-- {re.escape(marker)}:BEGIN -->.*?<!-- {re.escape(marker)}:END -->\n?',
    '\n',
    text,
)
block = (
    f"\n<!-- {marker}:BEGIN -->\n"
    f"## {title}\n\n{body.strip()}\n"
    f"<!-- {marker}:END -->\n"
)
path.write_text(text.rstrip() + "\n" + block, encoding="utf-8")
PY
  chmod 644 "$file"
}

patch_documents() {
  patch_markdown_document "$AGENTS_FILE" \
    "Bob Shell 2.x Resume Continuity" \
    'Menu option 5 is a production BQCA resume operation. It must resolve the latest real user task in the current BQCA workspace, exclude authentication-probe tasks, and invoke `bob chat --mode quantum-qiskit-connector --resume <task-id>`. It must never omit the mode or silently fall back to Agent Mode.'

  patch_markdown_document "$CORE_RULE" \
    "Option 5 Resume Rule" \
    'When menu option 5 is selected, resume the latest real user session for this workspace using the exact `quantum-qiskit-connector` custom-mode slug. Authentication validation tasks such as `BOB_AUTH_OK` are not user sessions and must never be selected. Resolve and pass the exact task ID rather than relying on an unfiltered `latest` token.'

  patch_markdown_document "$README_FILE" \
    "BQCA Menu Option 5 on Bob Shell 2.x" \
    'For Bob Shell 2.x, option 5 identifies the most recently updated non-authentication task in the BQCA workspace and resumes it with `bob chat --mode quantum-qiskit-connector --resume <task-id>`. The Bob authentication probe runs in a separate temporary workspace so it cannot replace the user’s latest BQCA session.'
}

patch_registry() {
  [[ -f "$REGISTRY" ]] || return 0
  python3 - "$REGISTRY" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["bob2_resume_patch"] = "BQCA-v51.3"
data["bob2_resume_mode"] = "quantum-qiskit-connector"
data["bob2_resume_resolver_path"] = ".bob/quantum-tools/bqca-bob2-resume.sh"
data["bob2_resume_behavior"] = "latest-non-authentication-user-task-by-exact-id"
data["bob2_auth_probe_workspace"] = "isolated-temporary-workspace"
path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
PY
  chmod 644 "$REGISTRY"
}

validate_installation() {
  local failures=0 mode_count
  normalize_permissions

  for file in "$RESUME_PY"; do
    [[ -x "$file" ]] || { warn "Missing executable: $file"; failures=$((failures+1)); }
    python3 -m py_compile "$file" || failures=$((failures+1))
  done
  for file in "$RESUME_SH" "$BOB_AUTH" "$BOB2_LAUNCHER"; do
    [[ -x "$file" ]] || { warn "Missing executable: $file"; failures=$((failures+1)); }
    bash -n "$file" || failures=$((failures+1))
  done

  grep -Fq 'BQCA_BOB2_RESUME_MODE="${BQCA_BOB2_RESUME_MODE:-quantum-qiskit-connector}"' "$BOB2_LAUNCHER" || {
    warn "Bob 2.x resume-mode default is missing"; failures=$((failures+1));
  }
  grep -Fq 'bqca_bob2_chat "${resume_mode}" "${task_id}"' "$BOB2_LAUNCHER" || {
    warn "Option 5 does not pass the exact task ID and resume mode"; failures=$((failures+1));
  }
  if grep -Fq 'bqca_bob2_chat "" latest' "$BOB2_LAUNCHER"; then
    warn "Legacy blank-mode latest resume call remains"
    failures=$((failures+1))
  fi
  grep -Fq -- '--workspace "${BQCA_AUTH_PROBE_WORKSPACE}"' "$BOB_AUTH" || {
    warn "Bob authentication probe is not workspace-isolated"; failures=$((failures+1));
  }
  grep -Fq 'BQCA_BOB2_RESUME_MODE=quantum-qiskit-connector' "$ENV_EXAMPLE" || {
    warn ".env.example does not define the production resume mode"; failures=$((failures+1));
  }

  mode_count="$(python3 - "$CUSTOM_MODES" <<'PY'
import pathlib,sys,yaml
path=pathlib.Path(sys.argv[1]); data=yaml.safe_load(path.read_text(encoding="utf-8")) or {}
print(sum(1 for item in data.get("customModes",[]) if str(item.get("slug","")) == "quantum-qiskit-connector"))
PY
)"
  [[ "$mode_count" -eq 1 ]] || {
    warn "Expected exactly one quantum-qiskit-connector custom mode, found $mode_count"
    failures=$((failures+1))
  }

  # Test task resolution with a mock Bob CLI. The newest task is an auth probe;
  # the resolver must skip it and select the newest real user task.
  local test_root test_workspace mock_bob resolved
  test_root="$(mktemp -d)"
  test_workspace="$test_root/workspace"
  mkdir -p "$test_workspace"
  mock_bob="$test_root/bob"
  cat > "$mock_bob" <<'MOCK'
#!/usr/bin/env bash
set -Eeuo pipefail
if [[ "${1:-}" == "--list-tasks" ]]; then
  workspace_uri="$(python3 - "$PWD" <<'PY'
import pathlib,sys
print(pathlib.Path(sys.argv[1]).resolve().as_uri())
PY
)"
  printf '{"id":"user-old","title":"Design a VQE workflow","status":"completed","workspace":"%s","updatedAt":100}\n' "$workspace_uri"
  printf '{"id":"user-latest","title":"Implement Grover search","status":"active","workspace":"%s","updatedAt":300}\n' "$workspace_uri"
  printf '{"id":"auth-probe-newest","title":"BQCA_AUTH_PROBE: Return exactly BOB_AUTH_OK and nothing else.","status":"completed","workspace":"%s","updatedAt":400}\n' "$workspace_uri"
  exit 0
fi
exit 2
MOCK
  chmod 755 "$mock_bob"
  set +e
  resolved="$($RESUME_SH resolve --bob-bin "$mock_bob" --workspace "$test_workspace" 2>/dev/null)"
  local resolver_status=$?
  set -e
  [[ "$resolver_status" -eq 0 && "$resolved" == "user-latest" ]] || {
    warn "Resume resolver selected '${resolved:-<none>}' instead of user-latest"
    failures=$((failures+1))
  }
  rm -rf "$test_root"

  if [[ -x "$MODE_SYNC_SH" ]]; then
    "$MODE_SYNC_SH" check --quiet || { warn "Custom mode/rule parity failed"; failures=$((failures+1)); }
  fi
  if [[ -x "$DNA_DOCTOR_SH" ]]; then
    "$DNA_DOCTOR_SH" check --quiet || { warn "Bob Shell 2.x DNA assurance failed"; "$DNA_DOCTOR_SH" report >&2 || true; failures=$((failures+1)); }
  fi
  if [[ -x "$POLICY_DOCTOR_SH" ]]; then
    "$POLICY_DOCTOR_SH" check --quiet || { warn "Active-policy assurance failed"; failures=$((failures+1)); }
  fi

  ((failures == 0)) || fail "v51.3 validation failed with $failures issue(s)."
  info "Validation passed: option 5 resolves the latest real BQCA user task and resumes it under quantum-qiskit-connector mode."
}

if ((VALIDATE_ONLY)); then
  validate_installation
  exit 0
fi

CUSTOM_SHA_BEFORE="$(sha256sum "$CUSTOM_MODES" | awk '{print $1}')"
POLICY_SHA_BEFORE="$(sha256sum "$BOB_ROOT/BQCA-PRODUCTION-POLICY.md" | awk '{print $1}')"
create_backup
mkdir -p "$TOOLS_DIR" "$PATCH_RECORD_DIR"
normalize_permissions
write_resume_py
write_resume_sh
patch_bob_auth
patch_launcher
patch_env_example
patch_documents
patch_registry

[[ "$CUSTOM_SHA_BEFORE" == "$(sha256sum "$CUSTOM_MODES" | awk '{print $1}')" ]] || fail "custom_modes.yaml was unexpectedly changed"
[[ "$POLICY_SHA_BEFORE" == "$(sha256sum "$BOB_ROOT/BQCA-PRODUCTION-POLICY.md" | awk '{print $1}')" ]] || fail "active central policy was unexpectedly changed"

cat > "$PATCH_RECORD_FILE" <<EOF
Patch: $PATCH_ID
Applied: $(date -u '+%Y-%m-%dT%H:%M:%SZ')
Root: $BQCA_ROOT
Backup: $BACKUP_DIR
Bob 2.x launcher: ${BOB2_LAUNCHER#$BQCA_ROOT/}
Option 5 mode: quantum-qiskit-connector
Task selection: latest non-authentication user task by exact task ID
Authentication probe: isolated temporary workspace
Bob 1.x resume: preserved
Private .env: excluded and unchanged
custom_modes.yaml: preserved byte-for-byte
Active central policy: preserved byte-for-byte
EOF
chmod 644 "$PATCH_RECORD_FILE"

validate_installation
info "Patch $PATCH_ID applied successfully."
info "Backup: $BACKUP_DIR"
info "Resume resolver: ${RESUME_SH#$BQCA_ROOT/}"
