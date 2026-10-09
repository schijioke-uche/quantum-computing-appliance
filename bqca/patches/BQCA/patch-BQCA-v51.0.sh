#!/usr/bin/env bash
set -Eeuo pipefail

#===============================================================================
# BQCA Bob Shell 2.x Project-DNA Integration Patch v51.0
# File: patch-BQCA-v51.0.sh
# Author: Dr. Jeffrey Chijioke-Uche, IBM Computer Scientist
#
# Purpose:
#   Preserve the existing BQCA v48 policy and the version-aware Bob 1.x/2.x
#   authentication/launcher remediation while binding the complete BQCA project
#   intelligence to Bob Shell 2.x sessions through native project context,
#   trusted-workspace rules, lifecycle hooks, custom modes, skills, tools, and
#   the offline quantum knowledgebase.
#
# Important protected assets:
#   - The project-root .env file is never read, copied, backed up, modified,
#     chmodded, removed, or restored by this patch installer.
#   - bob-quantum-designs/ and bob-quantum-store/ are never modified.
#   - $HOME/.bob, $HOME/qiskit-v2x-env, and $HOME/.qiskit/qiskit-ibm.json are
#     never modified by this installer.
#===============================================================================

PATCH_ID="BQCA-v51.0"
PATCH_FILE_NAME="patch-BQCA-v51.0.sh"
TIMESTAMP="$(date +%Y%m%d%H%M%S)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
TARGET_OVERRIDE=""
DRY_RUN=0
VALIDATE_ONLY=0
ROLLBACK_DIR=""

info() { printf '[BQCA v51.0][INFO] %s\n' "$*"; }
warn() { printf '[BQCA v51.0][WARN] %s\n' "$*" >&2; }
fail() { printf '[BQCA v51.0][ERROR] %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'USAGE'
BQCA Bob Shell 2.x Project-DNA Integration Patch v51.0

Usage:
  ./patch-BQCA-v51.0.sh [options]

Options:
  --target <path>        Explicit standalone BQCA appliance root.
  --dry-run              Display the patch plan without changing files.
  --validate-only        Validate the installed v51.0 integration.
  --rollback <backup>    Restore a v51.0 timestamped backup directory.
  -h, --help             Show this help.

Expected placement:
  <BQCA-root>/patches/BQCA/patch-BQCA-v51.0.sh

The installer does not read or modify the private .env file or governed
workload stores.
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

for cmd in bash chmod cmp cp date dirname find grep mkdir mktemp mv python3 rm sed sha256sum; do
  command -v "$cmd" >/dev/null 2>&1 || fail "Required command not found: $cmd"
done

is_bqca_root() {
  local candidate="$1"
  [[ -d "$candidate/.bob" ]] || return 1
  [[ -f "$candidate/.bob/custom_modes.yaml" ]] || return 1
  [[ -d "$candidate/.bob/skills" ]] || return 1
  [[ -d "$candidate/.bob/quantum-tools" ]] || return 1
  [[ -f "$candidate/xLaunchpad.sh" ]] || return 1
  [[ -f "$candidate/bob-auth.sh" ]] || return 1
  [[ -d "$candidate/bob-quantum-designs" ]] || return 1
  [[ -d "$candidate/bob-quantum-store" ]] || return 1
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
KB_DIR="$TOOLS_DIR/knowlegebase"
CUSTOM_MODES="$BOB_ROOT/custom_modes.yaml"
XLAUNCHPAD="$BQCA_ROOT/xLaunchpad.sh"
BOB_AUTH_DOC="$BQCA_ROOT/bob-auth.md"
README_FILE="$BQCA_ROOT/README.md"
ENV_EXAMPLE="$BQCA_ROOT/.env.example"
REGISTRY="$BOB_ROOT/BQCA-ACTIVE-POLICY-REGISTRY.json"
POLICY_STABLE="$BOB_ROOT/BQCA-PRODUCTION-POLICY.md"
AGENTS_FILE="$BQCA_ROOT/AGENTS.md"
SETTINGS_FILE="$BOB_ROOT/settings.json"
HOOKS_DIR="$BOB_ROOT/hooks"
SESSION_HOOK="$HOOKS_DIR/bqca-session-context.sh"
PROMPT_HOOK="$HOOKS_DIR/bqca-user-prompt-context.py"
GENERAL_RULE_DIR="$BOB_ROOT/rules"
GENERAL_RULE="$GENERAL_RULE_DIR/00-bqca-core.md"
DNA_DOCTOR_PY="$TOOLS_DIR/bqca-bob2-dna-doctor.py"
DNA_DOCTOR_SH="$TOOLS_DIR/bqca-bob2-dna-doctor.sh"
PATCH_RECORD_DIR="$BOB_ROOT/patches-applied"
PATCH_RECORD_FILE="$PATCH_RECORD_DIR/${PATCH_ID}.txt"
BACKUP_ROOT="$BOB_ROOT/patch-backups"
BACKUP_DIR="$BACKUP_ROOT/${PATCH_ID}.${TIMESTAMP}"
CREATED_LIST="$BACKUP_DIR/BQCA-v51.0-created-files.txt"
BACKUP_MANIFEST="$BACKUP_DIR/BQCA-v51.0-backup-manifest.txt"
DNA_MARKER="BQCA-BOB-SHELL-V2-DNA"

find_bob2_launcher() {
  local found
  found="$(find "$BQCA_ROOT" -maxdepth 1 -type f -name 'bob-quantum-v2.*.sh' -print | sort -V | tail -n 1)"
  [[ -n "$found" ]] || fail "No Bob Shell 2.x BQCA launcher found in $BQCA_ROOT"
  printf '%s\n' "$found"
}

BOB2_LAUNCHER="$(find_bob2_launcher)"

record_created_if_absent() {
  local path="$1" rel
  [[ ! -e "$path" ]] || return 0
  rel="${path#$BQCA_ROOT/}"
  printf '%s\n' "$rel" >> "$CREATED_LIST"
}

backup_file() {
  local source="$1" rel destination
  [[ -e "$source" ]] || return 0
  [[ "$source" != "$BQCA_ROOT/.env" ]] || return 0
  case "$source" in
    "$BQCA_ROOT/bob-quantum-designs"/*|"$BQCA_ROOT/bob-quantum-store"/*) return 0 ;;
    "$BOB_ROOT/patch-backups"/*) return 0 ;;
  esac
  rel="${source#$BQCA_ROOT/}"
  destination="$BACKUP_DIR/$rel"
  mkdir -p "$(dirname "$destination")"
  cp -a "$source" "$destination"
}

create_backup() {
  mkdir -p "$BACKUP_DIR"
  : > "$CREATED_LIST"

  for path in \
    "$AGENTS_FILE" "$SETTINGS_FILE" "$SESSION_HOOK" "$PROMPT_HOOK" \
    "$GENERAL_RULE" "$DNA_DOCTOR_PY" "$DNA_DOCTOR_SH" "$PATCH_RECORD_FILE"; do
    record_created_if_absent "$path"
  done

  for file in \
    "$XLAUNCHPAD" "$BOB2_LAUNCHER" "$BOB_AUTH_DOC" "$README_FILE" \
    "$ENV_EXAMPLE" "$CUSTOM_MODES" "$REGISTRY" "$AGENTS_FILE" \
    "$SETTINGS_FILE" "$SESSION_HOOK" "$PROMPT_HOOK" "$GENERAL_RULE" \
    "$DNA_DOCTOR_PY" "$DNA_DOCTOR_SH" "$PATCH_RECORD_FILE"; do
    backup_file "$file"
  done

  while IFS= read -r -d '' file; do backup_file "$file"; done < <(
    find "$BQCA_ROOT" -maxdepth 1 -type f -name '*.sh' -print0
  )

  while IFS= read -r -d '' file; do backup_file "$file"; done < <(
    find "$BOB_ROOT" -maxdepth 3 -type f \
      \( -path '*/rules-*/*' -o -path '*/skills/*' \) \
      ! -path '*/patch-backups/*' -print0
  )
  while IFS= read -r -d '' file; do backup_file "$file"; done < <(
    find "$TOOLS_DIR" -maxdepth 1 -type f \
      \( -name '*.sh' -o -name '*.py' -o -name '*.md' -o -name '*.txt' \) -print0
  )
  if [[ -d "$KB_DIR" ]]; then
    while IFS= read -r -d '' file; do backup_file "$file"; done < <(
      find "$KB_DIR" -type f \
        \( -name '*.sh' -o -name '*.py' -o -name '*.md' -o -name '*.txt' -o -name '*.json' \) -print0
    )
  fi

  cat > "$BACKUP_MANIFEST" <<MANIFEST
Patch: $PATCH_ID
Created: $(date -u '+%Y-%m-%dT%H:%M:%SZ')
Appliance root: $BQCA_ROOT
Bob 2.x launcher: ${BOB2_LAUNCHER#$BQCA_ROOT/}
Active policy before patch: $(sha256sum "$POLICY_STABLE" | awk '{print $1}')
Protected and intentionally excluded: .env, bob-quantum-designs, bob-quantum-store, HOME/.bob, HOME/qiskit-v2x-env, HOME/.qiskit/qiskit-ibm.json
Restore with:
  $PATCH_FILE_NAME --target "$BQCA_ROOT" --rollback "$BACKUP_DIR"
MANIFEST
}

restore_backup() {
  local backup="$1" backup_abs source rel destination
  backup_abs="$(cd "$backup" 2>/dev/null && pwd -P || true)"
  [[ -n "$backup_abs" ]] || fail "Rollback directory not found: $backup"
  [[ -f "$backup_abs/BQCA-v51.0-backup-manifest.txt" ]] || \
    fail "Not a BQCA v51.0 backup: $backup_abs"

  info "Restoring v51.0 backup: $backup_abs"
  while IFS= read -r -d '' source; do
    rel="${source#$backup_abs/}"
    case "$rel" in
      BQCA-v51.0-backup-manifest.txt|BQCA-v51.0-created-files.txt) continue ;;
    esac
    destination="$BQCA_ROOT/$rel"
    mkdir -p "$(dirname "$destination")"
    cp -a "$source" "$destination"
  done < <(find "$backup_abs" -mindepth 1 -type f -print0)

  if [[ -f "$backup_abs/BQCA-v51.0-created-files.txt" ]]; then
    while IFS= read -r rel; do
      [[ -n "$rel" ]] || continue
      [[ -e "$backup_abs/$rel" ]] || rm -f "$BQCA_ROOT/$rel"
    done < "$backup_abs/BQCA-v51.0-created-files.txt"
  fi

  rm -rf "$HOOKS_DIR/__pycache__" 2>/dev/null || true
  rmdir "$HOOKS_DIR" 2>/dev/null || true
  rmdir "$GENERAL_RULE_DIR" 2>/dev/null || true
  info "Rollback complete. Protected assets were not touched."
}

if [[ -n "$ROLLBACK_DIR" ]]; then
  restore_backup "$ROLLBACK_DIR"
  exit 0
fi

info "Resolved BQCA root: $BQCA_ROOT"
info "Patch identity: $PATCH_ID"
info "Bob 2.x launcher: ${BOB2_LAUNCHER#$BQCA_ROOT/}"
info "Protected assets: .env, workload stores, HOME/.bob, qiskit-v2x-env, and qiskit-ibm.json"

if ((DRY_RUN)); then
  cat <<'DRY'
[BQCA v51.0][DRY-RUN] Planned changes:
  1. Preserve the active BQCA central policy and existing Bob 1.x/2.x authentication.
  2. Create a project AGENTS.md that Bob Shell 2.x loads as BQCA context.
  3. Create .bob/settings.json lifecycle hooks for SessionStart and UserPromptSubmit.
  4. Create non-blocking BQCA context-injection hooks.
  5. Create a general .bob/rules/00-bqca-core.md cross-mode rule.
  6. Export BQCA menu option/action/skill/mode context from the Bob 2.x launcher.
  7. Add a concise BQCA DNA envelope to Bob 2.x non-interactive prompts.
  8. Broadcast a version-neutral Bob Shell 2.x DNA binding to all custom modes,
     rules, skills, top-level tools, and every knowledgebase text/code asset.
  9. Install a BQCA Bob 2.x DNA doctor and launch-time preflight.
 10. Correct .env.example quantum directory names; the private .env is unchanged.
 11. Update operator documentation and registry integration metadata.
DRY
  exit 0
fi

write_agents_file() {
  cat > "$AGENTS_FILE" <<'EOF_AGENTS'
# IBM Bob Quantum Computing Agent (BQCA) — Project Context

<!-- BQCA-BOB-SHELL-V2-DNA:BEGIN -->
This workspace is the **IBM Bob Quantum Computing Agent (BQCA)**. Never operate as a generic coding assistant when this project is trusted. Use the active menu context, active central policy, custom mode, rules, skills, quantum tools, and offline quantum knowledgebase together.

## Active authority

- Resolve the active BQCA policy through `.bob/quantum-tools/bqca-active-policy-listener.sh`.
- The stable authority is `.bob/BQCA-PRODUCTION-POLICY.md`.
- Do not replace, weaken, or independently reinterpret the active policy.
- Historical policies and patch files are audit records unless the active registry says otherwise.

## Menu and mode identity

The launcher exports `BQCA_MENU_OPTION`, `BQCA_MENU_ACTION`, `BQCA_MENU_SKILL_ID`, and `BQCA_SELECTED_MODE`. Honor those values for the current task:

- Option 1: interactive BQCA workbench.
- Option 2: Quantum Expert questions and explanations.
- Option 3: Quantum Developer implementation and executable artifacts.
- Option 4: Quantum Advanced textual solution design.
- Option 5: resume the latest BQCA activity without losing context.

## Governed artifact contract

- Designs and architecture: `bob-quantum-designs/`.
- Python, notebooks, results, plots, logs, and implementation evidence: `bob-quantum-store/`.
- Python is authoritative; the same-name notebook is generated and synchronized automatically.
- Every design and Python artifact must pass the active-policy validator and have a current same-directory policy-compliance report before completion is claimed.

## Quantum execution contract

- Configure the `bqca` Qiskit account before Connector/backend operations.
- Use only `$HOME/qiskit-v2x-env` with Qiskit 2.5 or later.
- Attempt an eligible real QPU before controlled simulator fallback.
- Open Plan: no Session; use `SamplerV2(mode=backend)` for sampled outputs or `EstimatorV2(mode=backend)` for expectation values/energy.
- Paid Plan: use `Session(backend=backend)` with the suitable V2 primitive.
- Never use `backend.run()` on real IBM Quantum hardware.
- Use direct synchronous execution by default; formal orchestration is explicit opt-in for compliance/deployment/audit evidence.
- Stream terminal output and create the governed result-output files required by the active policy.

## BQCA intelligence sources

Use the current mode-specific rule directory, `.bob/rules/`, `.bob/skills/`, `.bob/quantum-tools/`, and `.bob/quantum-tools/knowlegebase/`. The offline knowledgebase supplements IBM Bob intelligence and never overrides the active policy or current official product documentation.

## Security

Never expose `.env`, Bob API keys, IBM Quantum tokens, Qiskit account secrets, or credentials in designs, code, notebooks, logs, reports, prompts, or tool output.
<!-- BQCA-BOB-SHELL-V2-DNA:END -->
EOF_AGENTS
  chmod 644 "$AGENTS_FILE"
}

merge_settings_file() {
  mkdir -p "$BOB_ROOT"
  python3 - "$SETTINGS_FILE" <<'PY_SETTINGS'
from __future__ import annotations
import json, pathlib, sys
path = pathlib.Path(sys.argv[1])
if path.exists():
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        raise SystemExit(f"Cannot parse existing .bob/settings.json: {exc}")
    if not isinstance(data, dict):
        raise SystemExit("Existing .bob/settings.json must contain a JSON object")
else:
    data = {}
hooks = data.setdefault("hooks", {})
if not isinstance(hooks, dict):
    raise SystemExit("Existing settings hooks value must be a JSON object")

def install(name: str, command: str, timeout: int) -> None:
    entries = hooks.get(name, [])
    if not isinstance(entries, list):
        entries = []
    cleaned = []
    for entry in entries:
        encoded = json.dumps(entry, sort_keys=True)
        if "bqca-session-context.sh" in encoded or "bqca-user-prompt-context.py" in encoded:
            continue
        cleaned.append(entry)
    cleaned.append({"hooks": [{"type": "command", "command": command, "timeout": timeout}]})
    hooks[name] = cleaned

install("SessionStart", "sh .bob/hooks/bqca-session-context.sh", 5)
install("UserPromptSubmit", "python3 .bob/hooks/bqca-user-prompt-context.py", 5)
path.parent.mkdir(parents=True, exist_ok=True)
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY_SETTINGS
  chmod 644 "$SETTINGS_FILE"
}

write_hooks() {
  mkdir -p "$HOOKS_DIR"
  cat > "$SESSION_HOOK" <<'EOF_SESSION_HOOK'
#!/usr/bin/env sh
set -eu
# Consume the hook payload; SessionStart context is derived from the trusted workspace.
cat >/dev/null || true
ROOT="$(pwd -P)"
LISTENER="$ROOT/.bob/quantum-tools/bqca-active-policy-listener.sh"
POLICY_VERSION="${BQCA_ACTIVE_POLICY_VERSION:-UNKNOWN}"
POLICY_PATH="${BQCA_ACTIVE_POLICY_PATH:-$ROOT/.bob/BQCA-PRODUCTION-POLICY.md}"
if [ -x "$LISTENER" ]; then
  POLICY_VERSION="$($LISTENER version 2>/dev/null || printf '%s' "$POLICY_VERSION")"
  POLICY_PATH="$($LISTENER policy-path 2>/dev/null || printf '%s' "$POLICY_PATH")"
fi
cat <<EOF_CONTEXT
BQCA_SESSION_CONTEXT=ACTIVE
Appliance: IBM Bob Quantum Computing Agent (BQCA)
Menu option: ${BQCA_MENU_OPTION:-interactive-or-unspecified}
Menu action: ${BQCA_MENU_ACTION:-BQCA workspace session}
Skill identity: ${BQCA_MENU_SKILL_ID:-BQCA intelligence}
Selected mode: ${BQCA_SELECTED_MODE:-current Bob mode}
Active policy version: $POLICY_VERSION
Active policy path: $POLICY_PATH
Project context: Read AGENTS.md, the active mode rules, .bob/rules/00-bqca-core.md, relevant .bob/skills, .bob/quantum-tools, and the offline quantum knowledgebase. Preserve BQCA artifact routing, validators, notebook synchronization, execution, result-output, and security requirements.
EOF_CONTEXT
EOF_SESSION_HOOK
  chmod 755 "$SESSION_HOOK"

  cat > "$PROMPT_HOOK" <<'EOF_PROMPT_HOOK'
#!/usr/bin/env python3
"""Inject concise BQCA intent and operating context into every Bob Shell 2.x prompt."""
from __future__ import annotations
import json, os, re, sys

try:
    payload = json.load(sys.stdin)
    prompt = str(payload.get("prompt", ""))
except Exception:
    prompt = ""

lower = prompt.lower()
code_verbs = re.compile(r"\b(create|implement|write|generate|build|develop|produce|scaffold|construct|code|program|modify|update|repair|fix|refactor|complete|execute)\b")
design_words = re.compile(r"\b(design|architecture|plan|blueprint|strategy|workflow)\b")
quantum_words = re.compile(r"\b(quantum|qiskit|qubit|circuit|vqe|qaoa|grover|estimator|sampler|hamiltonian|qpu)\b")

menu = os.environ.get("BQCA_MENU_OPTION", "unspecified")
action = os.environ.get("BQCA_MENU_ACTION", "BQCA request")
skill = os.environ.get("BQCA_MENU_SKILL_ID", "BQCA intelligence")
mode = os.environ.get("BQCA_SELECTED_MODE", "current")
policy = os.environ.get("BQCA_ACTIVE_POLICY_PATH", ".bob/BQCA-PRODUCTION-POLICY.md")

if quantum_words.search(lower) and code_verbs.search(lower):
    intent = "CODE"
elif quantum_words.search(lower) and design_words.search(lower):
    intent = "DESIGN"
elif menu == "3":
    intent = "CODE"
elif menu == "4":
    intent = "DESIGN"
elif menu == "2":
    intent = "QUANTUM_QUESTION"
else:
    intent = "BQCA_INTERACTIVE"

lines = [
    "BQCA_PROMPT_CONTEXT=ACTIVE",
    f"Menu={menu}; Action={action}; Skill={skill}; Mode={mode}; Intent={intent}",
    f"Use active policy: {policy}",
    "Operate as BQCA, not as a generic assistant. Load AGENTS.md, the current mode rules, the general BQCA rule, relevant skills, and quantum tools.",
]
if intent == "CODE":
    lines.append("Route executable artifacts to bob-quantum-store; consult the offline quantum knowledgebase when useful; validate code; generate/synchronize the notebook; use the default direct execution and governed result contract.")
elif intent == "DESIGN":
    lines.append("Route the textual reviewable design to bob-quantum-designs; consult the offline quantum knowledgebase when useful; include active-policy execution strategy and validate the design before completion.")
elif intent == "QUANTUM_QUESTION":
    lines.append("Answer as the BQCA Quantum Expert using current rules and approved quantum/Qiskit sources; do not create artifacts unless requested.")
else:
    lines.append("Maintain BQCA identity and preserve the current menu-selected workflow across the session.")
print("\n".join(lines))
raise SystemExit(0)
EOF_PROMPT_HOOK
  chmod 755 "$PROMPT_HOOK"
}

write_general_rule() {
  mkdir -p "$GENERAL_RULE_DIR"
  cat > "$GENERAL_RULE" <<'EOF_GENERAL_RULE'
# BQCA Core Workspace Rule for Bob Shell 2.x

<!-- BQCA-BOB-SHELL-V2-DNA:BEGIN -->
This trusted workspace is the IBM Bob Quantum Computing Agent. Apply this rule in every mode, including a built-in fallback mode.

1. Read `AGENTS.md` and resolve `.bob/BQCA-PRODUCTION-POLICY.md` through the active-policy listener.
2. Honor the exported BQCA menu option, action, skill identity, and selected mode.
3. Combine the current mode-specific rules with relevant BQCA skills, quantum tools, and the offline knowledgebase.
4. Designs belong under `bob-quantum-designs/`; executable artifacts and evidence belong under `bob-quantum-store/`.
5. Use the active design/code validators and require the current same-directory compliance report.
6. Preserve Qiskit account configuration, the home Qiskit environment, plan-aware real-QPU-first behavior, controlled simulator fallback, notebook synchronization, live direct execution, result-output governance, and credential protection.
7. Never degrade to generic Bob behavior merely because the Bob Shell major version or selected custom mode changed.
<!-- BQCA-BOB-SHELL-V2-DNA:END -->
EOF_GENERAL_RULE
  chmod 644 "$GENERAL_RULE"
}

write_dna_doctor() {
  cat > "$DNA_DOCTOR_PY" <<'EOF_DNA_DOCTOR_PY'
#!/usr/bin/env python3
"""BQCA Bob Shell 2.x project-DNA installation and drift doctor."""
from __future__ import annotations
import argparse, json, pathlib, re, subprocess, sys

MARKER = "BQCA-BOB-SHELL-V2-DNA:BEGIN"
MARKER_LINE = re.compile(r"(?m)^\s*(?:#\s*BQCA-BOB-SHELL-V2-DNA:BEGIN\s*|<!--\s*BQCA-BOB-SHELL-V2-DNA:BEGIN\s*-->)$")
TEXT_EXTENSIONS = {".md", ".txt", ".sh", ".py"}
SLUG = re.compile(r"^[A-Za-z0-9-]+$")

def read(path: pathlib.Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")

def root_from_script() -> pathlib.Path:
    return pathlib.Path(__file__).resolve().parents[2]

def custom_modes(path: pathlib.Path):
    try:
        import yaml
        data = yaml.safe_load(read(path)) or {}
    except Exception as exc:
        raise RuntimeError(f"cannot parse custom_modes.yaml: {exc}")
    modes = data.get("customModes") or data.get("modes") or []
    if not isinstance(modes, list):
        raise RuntimeError("customModes must be a list")
    return modes

def syntax_error(path: pathlib.Path) -> str | None:
    if path.suffix == ".sh":
        r = subprocess.run(["bash", "-n", str(path)], text=True, capture_output=True)
        return None if r.returncode == 0 else r.stderr.strip()
    if path.suffix == ".py":
        try: compile(read(path), str(path), "exec")
        except Exception as exc: return str(exc)
    return None

def check(root: pathlib.Path) -> dict:
    errors=[]
    bob=root/".bob"; tools=bob/"quantum-tools"; kb=tools/"knowlegebase"
    agents=root/"AGENTS.md"; settings=bob/"settings.json"; modes_file=bob/"custom_modes.yaml"
    required=[
        agents, settings, bob/"hooks/bqca-session-context.sh",
        bob/"hooks/bqca-user-prompt-context.py", bob/"rules/00-bqca-core.md",
        tools/"bqca-bob2-dna-doctor.py", tools/"bqca-bob2-dna-doctor.sh",
    ]
    for p in required:
        if not p.is_file(): errors.append(f"missing required BQCA DNA component: {p}")
    for p in [agents, bob/"rules/00-bqca-core.md"]:
        if p.is_file() and len(MARKER_LINE.findall(read(p))) != 1:
            errors.append(f"DNA marker missing/duplicated: {p}")
    try:
        data=json.loads(read(settings)) if settings.is_file() else {}
        encoded=json.dumps(data)
        for needle in ("bqca-session-context.sh", "bqca-user-prompt-context.py"):
            if needle not in encoded: errors.append(f"settings hook missing: {needle}")
    except Exception as exc:
        errors.append(f"settings JSON invalid: {exc}")

    modes=[]
    try: modes=custom_modes(modes_file)
    except Exception as exc: errors.append(str(exc))
    slugs=[]; mode_marker_count=0
    for mode in modes:
        slug=str(mode.get("slug", "")); slugs.append(slug)
        if not SLUG.fullmatch(slug): errors.append(f"invalid custom mode slug: {slug}")
        if str(mode.get("customInstructions", "")).count(MARKER) != 1:
            errors.append(f"custom mode DNA missing/duplicated: {slug}")
        else: mode_marker_count += 1
        if not (bob/f"rules-{slug}").is_dir(): errors.append(f"mode rule directory missing: rules-{slug}")
    if len(slugs) != len(set(slugs)): errors.append("duplicate custom mode slugs detected")

    root_ops=sorted(p for p in root.glob("*.sh") if p.is_file())
    rules=sorted(p for d in bob.glob("rules-*") if d.is_dir() for p in d.rglob("*") if p.is_file() and p.suffix.lower() in TEXT_EXTENSIONS)
    skills=sorted(p for p in (bob/"skills").rglob("*") if p.is_file() and p.suffix.lower() in TEXT_EXTENSIONS)
    top_tools=sorted(p for p in tools.iterdir() if p.is_file() and p.suffix.lower() in TEXT_EXTENSIONS)
    kb_files=sorted(p for p in kb.rglob("*") if p.is_file() and p.suffix.lower() in {".md", ".txt", ".py"}) if kb.is_dir() else []
    for p in [*root_ops,*rules,*skills,*top_tools,*kb_files]:
        if len(MARKER_LINE.findall(read(p))) != 1: errors.append(f"DNA awareness missing/duplicated: {p}")
    catalog=kb/"bqca_quantum_algorithm_catalog.json"
    try:
        c=json.loads(read(catalog)); meta=c.get("bob_shell_v2_dna", {})
        if meta.get("binding") != "project-active": errors.append("knowledgebase catalog DNA metadata missing")
    except Exception as exc: errors.append(f"knowledgebase catalog invalid: {exc}")

    launcher=sorted(root.glob("bob-quantum-v2.*.sh"))
    launcher=launcher[-1] if launcher else None
    if not launcher: errors.append("Bob 2.x launcher missing")
    else:
        text=read(launcher)
        if text.count("BQCA-BOB-SHELL-V2-DNA-CHAIN-v51.0:BEGIN") != 1: errors.append("Bob 2.x launcher DNA chain missing/duplicated")
        for option in ("1","2","3","4","5"):
            if f'bqca_set_menu_context "{option}"' not in text: errors.append(f"menu context export missing for option {option}")
    xlaunch=root/"xLaunchpad.sh"
    if xlaunch.is_file() and read(xlaunch).count("BQCA-BOB-SHELL-V2-DNA-PREFLIGHT-v51.0:BEGIN") != 1:
        errors.append("xLaunchpad v51.0 DNA preflight missing/duplicated")

    for p in [root/"xLaunchpad.sh", launcher, bob/"hooks/bqca-session-context.sh", bob/"hooks/bqca-user-prompt-context.py", tools/"bqca-bob2-dna-doctor.py", tools/"bqca-bob2-dna-doctor.sh"]:
        if p and p.is_file():
            err=syntax_error(p)
            if err: errors.append(f"syntax error {p}: {err}")

    listener=tools/"bqca-active-policy-listener.sh"
    if listener.is_file():
        r=subprocess.run([str(listener),"validate"],text=True,capture_output=True)
        if r.returncode: errors.append("active central policy listener validation failed")
    return {
        "errors":errors,"modes":len(modes),"mode_markers":mode_marker_count,
        "root_operations":len(root_ops),"rules":len(rules),"skills":len(skills),"tools":len(top_tools),
        "knowledgebase_files":len(kb_files),"final_status":"PASS" if not errors else "FAIL",
    }

def main() -> int:
    ap=argparse.ArgumentParser(); ap.add_argument("command",choices=["check","report"]); ap.add_argument("--quiet",action="store_true")
    args=ap.parse_args(); result=check(root_from_script())
    if args.command=="report" or not args.quiet:
        print("="*88); print("BQCA v51.0 BOB SHELL 2.x PROJECT-DNA ASSURANCE REPORT"); print("="*88)
        print(f"Custom modes             : {result['mode_markers']}/{result['modes']}")
        print(f"Root operation scripts   : {result['root_operations']}")
        print(f"Rules / Skills / Tools   : {result['rules']} / {result['skills']} / {result['tools']}")
        print(f"Knowledgebase text/code  : {result['knowledgebase_files']}")
        if result['errors']:
            print("-"*88); print("ISSUES")
            for e in result['errors']: print(f"- {e}")
        print("-"*88); print(f"FINAL DNA STATUS         : {result['final_status']}")
        print("="*88)
        print(f"BQCA_BOB2_DNA_ASSURANCE={result['final_status']}")
    return 0 if result['final_status']=="PASS" else 1
if __name__=="__main__": raise SystemExit(main())

# BQCA-ACTIVE-CENTRAL-POLICY:BEGIN
# Resolve and obey the current stable BQCA policy and its validation contract.
# BQCA-ACTIVE-CENTRAL-POLICY:END
# BQCA-BOB-SHELL-V2-DNA:BEGIN
# This tool verifies Bob Shell 2.x BQCA project-context integration.
# BQCA-BOB-SHELL-V2-DNA:END
EOF_DNA_DOCTOR_PY
  chmod 755 "$DNA_DOCTOR_PY"

  cat > "$DNA_DOCTOR_SH" <<'EOF_DNA_DOCTOR_SH'
#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
exec python3 "${SCRIPT_DIR}/bqca-bob2-dna-doctor.py" "$@"

# BQCA-ACTIVE-CENTRAL-POLICY:BEGIN
# Resolve and obey the current stable BQCA policy and its validation contract.
# BQCA-ACTIVE-CENTRAL-POLICY:END
# BQCA-BOB-SHELL-V2-DNA:BEGIN
# This wrapper exposes the Bob Shell 2.x BQCA project-DNA doctor.
# BQCA-BOB-SHELL-V2-DNA:END
EOF_DNA_DOCTOR_SH
  chmod 755 "$DNA_DOCTOR_SH"
}

patch_custom_modes() {
  python3 - "$CUSTOM_MODES" <<'PY_MODES'
from __future__ import annotations
import pathlib,re,sys
p=pathlib.Path(sys.argv[1]); text=p.read_text(encoding="utf-8")
text=re.sub(r'(?ms)^([ \t]*)# BQCA-BOB-SHELL-V2-DNA:BEGIN\n.*?^\1# BQCA-BOB-SHELL-V2-DNA:END\n?', '', text)
lines=text.splitlines(); out=[]; count=0
pat=re.compile(r'^(?P<indent>[ \t]*)customInstructions:\s*(?P<style>[>|])(?P<chomp>[+-]?)\s*(?:#.*)?$')
for line in lines:
    out.append(line); m=pat.match(line)
    if not m: continue
    i=m.group('indent')+'  '
    out.extend([
      f'{i}# BQCA-BOB-SHELL-V2-DNA:BEGIN',
      f'{i}BOB SHELL 2.x BQCA DNA: This is a trusted BQCA project mode. Read AGENTS.md, resolve the active central policy, honor BQCA_MENU_OPTION/BQCA_MENU_ACTION/BQCA_MENU_SKILL_ID/BQCA_SELECTED_MODE, and combine this mode with its rules, relevant skills, quantum tools, and the offline knowledgebase. Do not fall back to generic Bob behavior. Preserve governed design/code routing, active validators and compliance reports, notebook synchronization, plan-aware Qiskit execution, result-output governance, and secret protection.',
      f'{i}# BQCA-BOB-SHELL-V2-DNA:END',
    ]); count+=1
if count==0: raise SystemExit('No customInstructions block scalars found')
p.write_text('\n'.join(out)+'\n',encoding='utf-8')
print(f'custom_modes={count}')
PY_MODES
}

patch_all_awareness() {
  python3 - "$BQCA_ROOT" "$BOB_ROOT" "$TOOLS_DIR" "$KB_DIR" <<'PY_AWARENESS_BATCH'
from __future__ import annotations
import json, pathlib, re, sys
root=pathlib.Path(sys.argv[1]); bob=pathlib.Path(sys.argv[2]); tools=pathlib.Path(sys.argv[3]); kb=pathlib.Path(sys.argv[4])
text_ext={'.md','.txt','.sh','.py'}
files=[p for p in root.glob('*.sh') if p.is_file()]
for d in bob.glob('rules-*'):
    if d.is_dir(): files.extend(p for p in d.rglob('*') if p.is_file() and p.suffix.lower() in text_ext)
skills=bob/'skills'
if skills.is_dir(): files.extend(p for p in skills.rglob('*') if p.is_file() and p.suffix.lower() in text_ext)
if tools.is_dir(): files.extend(p for p in tools.iterdir() if p.is_file() and p.suffix.lower() in text_ext)
if kb.is_dir(): files.extend(p for p in kb.rglob('*') if p.is_file() and p.suffix.lower() in text_ext)
files=sorted(set(files))
md_block='''\n<!-- BQCA-BOB-SHELL-V2-DNA:BEGIN -->\n## Bob Shell 2.x BQCA project-DNA binding\nIn a trusted Bob Shell 2.x workspace, read `AGENTS.md`, resolve the active central BQCA policy, honor the exported menu option/action/skill/mode, and use the current rules, relevant skills, quantum tools, and offline knowledgebase. This component supplements the existing BQCA workflow and must not replace its domain purpose or active-policy controls. Never degrade to generic Bob behavior.\n<!-- BQCA-BOB-SHELL-V2-DNA:END -->\n'''
code_block='''\n# BQCA-BOB-SHELL-V2-DNA:BEGIN\n# In a trusted Bob Shell 2.x workspace, bind this component to AGENTS.md, the\n# active central BQCA policy, exported menu context, current rules/skills/tools,\n# and the offline knowledgebase without changing this component's core purpose.\n# BQCA-BOB-SHELL-V2-DNA:END\n'''
for p in files:
    text=p.read_text(encoding='utf-8',errors='replace')
    text=re.sub(r'\n?<!-- BQCA-BOB-SHELL-V2-DNA:BEGIN -->.*?<!-- BQCA-BOB-SHELL-V2-DNA:END -->\n?', '\n', text, flags=re.S)
    text=re.sub(r'(?ms)^# BQCA-BOB-SHELL-V2-DNA:BEGIN\n.*?^# BQCA-BOB-SHELL-V2-DNA:END\n?', '', text)
    p.write_text(text.rstrip()+"\n"+(md_block if p.suffix.lower()=='.md' else code_block),encoding='utf-8')
catalog=kb/'bqca_quantum_algorithm_catalog.json'
if catalog.is_file():
    d=json.loads(catalog.read_text(encoding='utf-8'))
    d['bob_shell_v2_dna']={
      'binding':'project-active','patch':'BQCA-v51.0','agents_path':'AGENTS.md',
      'active_policy_path':'.bob/BQCA-PRODUCTION-POLICY.md',
      'menu_context_variables':['BQCA_MENU_OPTION','BQCA_MENU_ACTION','BQCA_MENU_SKILL_ID','BQCA_SELECTED_MODE'],
      'supplemental':True,'overrides_active_policy':False,
    }
    catalog.write_text(json.dumps(d,indent=2,sort_keys=True)+'\n',encoding='utf-8')
print(f'awareness_files={len(files)}')
PY_AWARENESS_BATCH
  [[ ! -f "$KB_DIR/bqca_quantum_algorithm_catalog.json" ]] || chmod 644 "$KB_DIR/bqca_quantum_algorithm_catalog.json"
}

patch_bob2_launcher() {
  python3 - "$BOB2_LAUNCHER" <<'PY_LAUNCHER'
from __future__ import annotations
import pathlib,re,sys
p=pathlib.Path(sys.argv[1]); text=p.read_text(encoding='utf-8')
text=re.sub(r'(?ms)^# BQCA-BOB-SHELL-V2-DNA-CHAIN-v51\.0:BEGIN\n.*?^# BQCA-BOB-SHELL-V2-DNA-CHAIN-v51\.0:END\n?', '', text)
text=re.sub(r'(?m)^    bqca_set_menu_context \"[1-5]\".*\n', '', text)
block=r'''# BQCA-BOB-SHELL-V2-DNA-CHAIN-v51.0:BEGIN
BQCA_BOB2_DNA_ENVELOPE="${BQCA_BOB2_DNA_ENVELOPE:-1}"
export BQCA_BOB2_DNA_ENVELOPE

bqca_set_menu_context() {
  BQCA_MENU_OPTION="$1"
  BQCA_MENU_ACTION="$2"
  BQCA_MENU_SKILL_ID="$3"
  BQCA_SELECTED_MODE="$4"
  export BQCA_MENU_OPTION BQCA_MENU_ACTION BQCA_MENU_SKILL_ID BQCA_SELECTED_MODE
}

bqca_bob2_envelope_prompt() {
  local user_prompt="$1"
  local selected_mode="$2"
  if [[ "${BQCA_BOB2_DNA_ENVELOPE}" != "1" ]]; then
    printf '%s\n' "${user_prompt}"
    return 0
  fi
  cat <<EOF_BQCA_PROMPT
[BQCA PROJECT CONTEXT]
Operate as the IBM Bob Quantum Computing Agent in the trusted workspace ${SCRIPT_DIR}.
Menu option: ${BQCA_MENU_OPTION:-unspecified}
Menu action: ${BQCA_MENU_ACTION:-BQCA request}
Skill identity: ${BQCA_MENU_SKILL_ID:-BQCA intelligence}
Selected mode: ${selected_mode}
Read AGENTS.md, resolve the active central policy, and use the current mode rules, relevant skills, quantum tools, and offline knowledgebase. Preserve governed design/code routing, validators/compliance reports, notebook synchronization, Qiskit execution rules, result-output governance, and credential protection.

[USER REQUEST]
${user_prompt}
EOF_BQCA_PROMPT
}
# BQCA-BOB-SHELL-V2-DNA-CHAIN-v51.0:END
'''
needle='BOLD=""\n'
if needle not in text: raise SystemExit('Unable to locate launcher color initialization')
text=text.replace(needle,block+'\n'+needle,1)

old='''  (\n    cd "${SCRIPT_DIR}"\n    "${BOB_BIN}" "${bob2_args[@]}" "${user_prompt}"\n  )'''
new='''  local bqca_enveloped_prompt\n  bqca_enveloped_prompt="$(bqca_bob2_envelope_prompt "${user_prompt}" "${selected_mode}")"\n\n  (\n    cd "${SCRIPT_DIR}"\n    "${BOB_BIN}" "${bob2_args[@]}" "${bqca_enveloped_prompt}"\n  )'''
if old in text:
    text=text.replace(old,new,1)
elif 'bqca_enveloped_prompt="$(bqca_bob2_envelope_prompt' in text and '"${BOB_BIN}" "${bob2_args[@]}" "${bqca_enveloped_prompt}"' in text:
    pass
else:
    raise SystemExit('Unable to locate Bob 2.x run invocation')

contexts={
'1':'bqca_set_menu_context "1" "Start Interactive BQCA Session" "User Interactive" "${BQCA_BOB2_INTERACTIVE_MODE}"',
'2':'bqca_set_menu_context "2" "Ask Quantum Computing Questions" "Quantum Expert" "${BQCA_BOB2_ASK_MODE}"',
'3':'bqca_set_menu_context "3" "Quantum Computing Algorithm Implementation Concierge" "Quantum Developer" "${BQCA_BOB2_CODE_MODE}"',
'4':'bqca_set_menu_context "4" "Advanced Quantum Computing Solution Design Concierge" "Quantum Advanced" "${BQCA_BOB2_ADVANCED_MODE}"',
'5':'bqca_set_menu_context "5" "Resume BQCA Last Activity" "Resume Session" "resume"',
}
for option,call in contexts.items():
    pattern=re.compile(rf'(?m)^  {option}\)\n')
    if not pattern.search(text): raise SystemExit(f'Unable to locate menu option {option}')
    text=pattern.sub(f'  {option})\n    {call}\n',text,count=1)
p.write_text(text,encoding='utf-8')
PY_LAUNCHER
  chmod 755 "$BOB2_LAUNCHER"
}

patch_xlaunchpad() {
  python3 - "$XLAUNCHPAD" <<'PY_XLAUNCH'
from __future__ import annotations
import pathlib,re,sys
p=pathlib.Path(sys.argv[1]); text=p.read_text(encoding='utf-8')
text=re.sub(r'(?ms)^# BQCA-BOB-SHELL-V2-DNA-PREFLIGHT-v51\.0:BEGIN\n.*?^# BQCA-BOB-SHELL-V2-DNA-PREFLIGHT-v51\.0:END\n?', '', text)
# Replace unsafe relative browser-helper setup without changing authentication semantics.
text=text.replace('chmod 777 configure-bob-auth-browser.sh\nsource configure-bob-auth-browser.sh\n', '''_BQCA_BOOTSTRAP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"\nif [[ -f "${_BQCA_BOOTSTRAP_DIR}/configure-bob-auth-browser.sh" ]]; then\n  chmod 755 "${_BQCA_BOOTSTRAP_DIR}/configure-bob-auth-browser.sh"\n  # shellcheck source=/dev/null\n  source "${_BQCA_BOOTSTRAP_DIR}/configure-bob-auth-browser.sh"\nfi\nunset _BQCA_BOOTSTRAP_DIR\n''',1)
block=r'''# BQCA-BOB-SHELL-V2-DNA-PREFLIGHT-v51.0:BEGIN
_BQCA_BOB2_DNA_DOCTOR="${SCRIPT_DIR}/.bob/quantum-tools/bqca-bob2-dna-doctor.sh"
if [[ ! -x "${_BQCA_BOB2_DNA_DOCTOR}" ]]; then
  printf '[BQCA][ERROR] Bob Shell 2.x BQCA DNA doctor is missing: %s\n' \
    "${_BQCA_BOB2_DNA_DOCTOR}" >&2
  exit 1
fi
if ! "${_BQCA_BOB2_DNA_DOCTOR}" check --quiet; then
  printf '[BQCA][ERROR] Bob Shell 2.x BQCA project-DNA drift detected. Run: %s report\n' \
    "${_BQCA_BOB2_DNA_DOCTOR}" >&2
  exit 1
fi
# BQCA-BOB-SHELL-V2-DNA-PREFLIGHT-v51.0:END
'''
needle='source "${SCRIPT_DIR}/xdg.sh" --check\n'
if needle not in text: raise SystemExit('Unable to locate xdg preflight in xLaunchpad.sh')
text=text.replace(needle,block+'\n'+needle,1)
p.write_text(text,encoding='utf-8')
PY_XLAUNCH
  chmod 755 "$XLAUNCHPAD"
}

patch_env_example() {
  [[ -f "$ENV_EXAMPLE" ]] || return 0
  python3 - "$ENV_EXAMPLE" <<'PY_ENV'
import pathlib,re,sys
p=pathlib.Path(sys.argv[1]); text=p.read_text(encoding='utf-8')
text=text.replace('SWA_DESIGN_DIR="${APPLIANCE_ROOT}/bob-quantum-designs"','QCA_DESIGN_DIR="${APPLIANCE_ROOT}/bob-quantum-designs"')
text=text.replace('SWA_STORE_DIR="${APPLIANCE_ROOT}/bob-quantum-store"','QCA_STORE_DIR="${APPLIANCE_ROOT}/bob-quantum-store"')
text=text.replace('BOB_INCLUDED_DIRECTORY="${SWA_STORE_DIR},${SWA_DESIGN_DIR}"','BOB_INCLUDED_DIRECTORY="${QCA_STORE_DIR},${QCA_DESIGN_DIR}"')
marker='# BQCA-BOB-SHELL-V2-DNA-ENV-v51.0:BEGIN'
text=re.sub(r'(?ms)^# BQCA-BOB-SHELL-V2-DNA-ENV-v51\.0:BEGIN\n.*?^# BQCA-BOB-SHELL-V2-DNA-ENV-v51\.0:END\n?', '', text)
block='''# BQCA-BOB-SHELL-V2-DNA-ENV-v51.0:BEGIN\n# Keep the concise BQCA context envelope enabled for Bob Shell 2.x non-interactive runs.\nBQCA_BOB2_DNA_ENVELOPE=1\n# Workspace lifecycle hooks are configured in .bob/settings.json and run only in a trusted workspace.\nBQCA_BOB2_DNA_HOOKS=1\n# BQCA-BOB-SHELL-V2-DNA-ENV-v51.0:END\n\n'''
needle='# Optional Bob Shell 2.x mode overrides.\n'
if needle in text: text=text.replace(needle,block+needle,1)
else: text += '\n'+block
p.write_text(text,encoding='utf-8')
PY_ENV
  chmod 644 "$ENV_EXAMPLE"
}

patch_documentation() {
  python3 - "$BOB_AUTH_DOC" "$README_FILE" <<'PY_DOCS'
import pathlib,re,sys
for value in sys.argv[1:]:
    p=pathlib.Path(value)
    if not p.is_file(): continue
    text=p.read_text(encoding='utf-8',errors='replace')
    text=re.sub(r'\n?<!-- BQCA-BOB-SHELL-V2-DNA-DOC-v51\.0:BEGIN -->.*?<!-- BQCA-BOB-SHELL-V2-DNA-DOC-v51\.0:END -->\n?', '\n', text, flags=re.S)
    if p.name=='bob-auth.md':
        block='''<!-- BQCA-BOB-SHELL-V2-DNA-DOC-v51.0:BEGIN -->\n# Version-aware Bob Shell authentication and BQCA context\n\n`bob-auth.sh` detects the installed Bob major version. Bob 1.x retains the legacy token/config compatibility path. Bob 2.x uses the production `bob run` API-key probe already implemented in the script and does not manufacture legacy credential files. The private `.env` remains the operator-managed input.\n\nAuthentication alone does not provide the complete BQCA operating identity. Bob Shell 2.x receives BQCA project intelligence through root `AGENTS.md`, `.bob/settings.json` lifecycle hooks, `.bob/rules/00-bqca-core.md`, project custom modes, mode-specific rules, skills, quantum tools, and the offline knowledgebase. The versioned launcher exports the selected menu option/action/skill/mode for those context channels.\n<!-- BQCA-BOB-SHELL-V2-DNA-DOC-v51.0:END -->\n\n'''
        text=block+text
    else:
        block='''\n<!-- BQCA-BOB-SHELL-V2-DNA-DOC-v51.0:BEGIN -->\n## Bob Shell 2.x BQCA project-DNA integration\n\nBob Shell 2.x sessions run from the trusted BQCA workspace and load `AGENTS.md`, the general BQCA rule, the selected custom mode and mode-specific rules, relevant skills/tools, and lifecycle-hook context. `bob-quantum-v2.x.sh` exports the BQCA menu option, action, skill identity, and selected mode; non-interactive prompts also receive a concise BQCA context envelope. This preserves the same BQCA appliance identity and governed workflow used by the Bob 1.x launcher while retaining the existing active central policy and quantum execution controls.\n<!-- BQCA-BOB-SHELL-V2-DNA-DOC-v51.0:END -->\n'''
        text=text.rstrip()+block+'\n'
    p.write_text(text,encoding='utf-8')
PY_DOCS
  chmod 644 "$BOB_AUTH_DOC" "$README_FILE"
}

update_registry() {
  [[ -f "$REGISTRY" ]] || return 0
  python3 - "$REGISTRY" <<'PY_REGISTRY'
import datetime,json,pathlib,sys
p=pathlib.Path(sys.argv[1]); d=json.loads(p.read_text(encoding='utf-8'))
d['bob_shell_v2_dna']={
  'patch':'BQCA-v51.0',
  'status':'active',
  'agents_path':'AGENTS.md',
  'settings_path':'.bob/settings.json',
  'general_rule_path':'.bob/rules/00-bqca-core.md',
  'session_hook_path':'.bob/hooks/bqca-session-context.sh',
  'prompt_hook_path':'.bob/hooks/bqca-user-prompt-context.py',
  'doctor_path':'.bob/quantum-tools/bqca-bob2-dna-doctor.sh',
  'menu_context_variables':['BQCA_MENU_OPTION','BQCA_MENU_ACTION','BQCA_MENU_SKILL_ID','BQCA_SELECTED_MODE'],
  'active_policy_unchanged':True,
  'bob_1x_compatibility_preserved':True,
  'bob_2x_project_context':'agents-rules-modes-skills-tools-hooks-knowledgebase',
}
d['updated_utc']=datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).isoformat().replace('+00:00','Z')
p.write_text(json.dumps(d,indent=2,sort_keys=True)+'\n',encoding='utf-8')
PY_REGISTRY
  chmod 644 "$REGISTRY"
}

normalize_permissions() {
  chmod 755 "$XLAUNCHPAD" "$BOB2_LAUNCHER" "$SESSION_HOOK" "$PROMPT_HOOK" "$DNA_DOCTOR_PY" "$DNA_DOCTOR_SH"
  chmod 644 "$AGENTS_FILE" "$SETTINGS_FILE" "$GENERAL_RULE" "$CUSTOM_MODES" "$ENV_EXAMPLE" "$README_FILE" "$BOB_AUTH_DOC" "$REGISTRY"
  if [[ -f "$TOOLS_DIR/bqca-permission-guard.sh" ]]; then
    bash "$TOOLS_DIR/bqca-permission-guard.sh" repair --quiet || true
  fi
}

validate_installation() {
  local failures=0 before_hash after_hash
  before_hash="$(awk -F': ' '/^Active policy before patch:/ {print $2}' "$BACKUP_MANIFEST" 2>/dev/null || true)"
  after_hash="$(sha256sum "$POLICY_STABLE" | awk '{print $1}')"
  if [[ -n "$before_hash" && "$before_hash" != "$after_hash" ]]; then
    warn "Active central policy content changed unexpectedly"
    failures=$((failures+1))
  fi

  for file in "$XLAUNCHPAD" "$BOB2_LAUNCHER" "$SESSION_HOOK" "$DNA_DOCTOR_SH"; do
    bash -n "$file" || failures=$((failures+1))
  done
  for file in "$PROMPT_HOOK" "$DNA_DOCTOR_PY"; do
    PYTHONDONTWRITEBYTECODE=1 python3 - "$file" <<'PY_COMPILE' || failures=$((failures+1))
import pathlib,sys
path=pathlib.Path(sys.argv[1])
compile(path.read_text(encoding="utf-8"), str(path), "exec")
PY_COMPILE
  done
  python3 -m json.tool "$SETTINGS_FILE" >/dev/null || failures=$((failures+1))
  python3 -m json.tool "$REGISTRY" >/dev/null || failures=$((failures+1))
  if [[ -f "$KB_DIR/bqca_quantum_algorithm_catalog.json" ]]; then
    python3 -m json.tool "$KB_DIR/bqca_quantum_algorithm_catalog.json" >/dev/null || failures=$((failures+1))
  fi

  if ! PYTHONDONTWRITEBYTECODE=1 BQCA_MENU_OPTION=3 \
       BQCA_MENU_ACTION='Quantum Computing Algorithm Implementation Concierge' \
       BQCA_MENU_SKILL_ID='Quantum Developer' \
       BQCA_SELECTED_MODE=code \
       printf '%s\n' '{"event":"UserPromptSubmit","session_id":"test","prompt":"Create Qiskit VQE code"}' | \
       BQCA_MENU_OPTION=3 BQCA_MENU_ACTION='Quantum Computing Algorithm Implementation Concierge' \
       BQCA_MENU_SKILL_ID='Quantum Developer' BQCA_SELECTED_MODE=code \
       PYTHONDONTWRITEBYTECODE=1 python3 "$PROMPT_HOOK" | grep -q 'Intent=CODE'; then
    warn "UserPromptSubmit BQCA CODE-intent hook smoke test failed"
    failures=$((failures+1))
  fi
  if ! printf '%s\n' '{"event":"SessionStart","session_id":"test"}' | \
       BQCA_MENU_OPTION=4 BQCA_MENU_ACTION='Advanced Quantum Design' \
       BQCA_MENU_SKILL_ID='Quantum Advanced' BQCA_SELECTED_MODE=advanced \
       sh "$SESSION_HOOK" | grep -q 'BQCA_SESSION_CONTEXT=ACTIVE'; then
    warn "SessionStart BQCA context hook smoke test failed"
    failures=$((failures+1))
  fi

  if ! PYTHONDONTWRITEBYTECODE=1 "$DNA_DOCTOR_SH" check --quiet; then
    warn "Bob Shell 2.x BQCA DNA doctor failed"
    PYTHONDONTWRITEBYTECODE=1 "$DNA_DOCTOR_SH" report >&2 || true
    failures=$((failures+1))
  fi
  if [[ -x "$TOOLS_DIR/bqca-policy-doctor.sh" ]]; then
    if ! PYTHONDONTWRITEBYTECODE=1 "$TOOLS_DIR/bqca-policy-doctor.sh" check --quiet; then
      warn "Existing active-policy doctor failed after v51.0 integration"
      PYTHONDONTWRITEBYTECODE=1 "$TOOLS_DIR/bqca-policy-doctor.sh" report >&2 || true
      failures=$((failures+1))
    fi
  fi

  if ((failures)); then
    fail "v51.0 validation failed with $failures issue(s)."
  fi
  info "Validation passed: Bob Shell 2.x sessions receive BQCA identity through AGENTS, rules, modes, skills, tools, hooks, and the knowledgebase without changing the active policy."
}

if ((VALIDATE_ONLY)); then
  # Build a temporary manifest path only for hash-neutral validation.
  mkdir -p "$BACKUP_DIR"
  printf 'Active policy before patch: %s\n' "$(sha256sum "$POLICY_STABLE" | awk '{print $1}')" > "$BACKUP_MANIFEST"
  validate_installation
  rm -rf "$BACKUP_DIR"
  exit 0
fi

create_backup
write_agents_file
merge_settings_file
write_hooks
write_general_rule
write_dna_doctor
patch_custom_modes
patch_all_awareness
patch_bob2_launcher
patch_xlaunchpad
patch_env_example
patch_documentation
update_registry
normalize_permissions
mkdir -p "$PATCH_RECORD_DIR"
cat > "$PATCH_RECORD_FILE" <<RECORD
Patch: $PATCH_ID
Applied: $(date -u '+%Y-%m-%dT%H:%M:%SZ')
Root: $BQCA_ROOT
Backup: $BACKUP_DIR
Bob 2.x launcher: ${BOB2_LAUNCHER#$BQCA_ROOT/}
Behavior: project AGENTS, general rule, lifecycle hooks, menu context, prompt envelope, and appliance-wide BQCA DNA awareness
Active central policy: unchanged
Protected assets: .env and governed workload stores excluded
RECORD
chmod 644 "$PATCH_RECORD_FILE"

validate_installation
info "Patch $PATCH_ID applied successfully."
info "Backup: $BACKUP_DIR"
info "Project context: AGENTS.md"
info "Lifecycle hooks: .bob/settings.json"
info "DNA doctor: .bob/quantum-tools/bqca-bob2-dna-doctor.sh"
info ".env and governed workload stores were not touched."
