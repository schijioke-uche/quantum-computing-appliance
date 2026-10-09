#!/usr/bin/env bash
set -Eeuo pipefail

#===============================================================================
# BQCA Bob Shell 2.x Custom-Mode Rule Parity Patch v51.2
# File: patch-BQCA-v51.2.sh
# Author: Dr. Jeffrey Chijioke-Uche, IBM Computer Scientist
#
# Purpose:
#   Synchronize .bob/custom_modes.yaml with Bob Shell mode-specific custom rules.
#   For every custom-mode slug, Bob Shell expects a corresponding directory:
#
#       .bob/rules-<slug>/
#
#   This patch repairs the current missing rules-quantum-qiskit-connector binding,
#   installs a reusable parity synchronizer, runs it before Bob 2.x DNA assurance,
#   and aligns Bob 2.x menu defaults with the current production mode slugs.
#
# Protected assets:
#   The installer does not read, copy, back up, modify, chmod, remove, or restore
#   .env, the active central policy, governed design/code stores, $HOME/.bob,
#   $HOME/qiskit-v2x-env, or $HOME/.qiskit/qiskit-ibm.json.
#   custom_modes.yaml is read for slug discovery but preserved byte-for-byte.
#===============================================================================

PATCH_ID="BQCA-v51.2"
PATCH_FILE_NAME="patch-BQCA-v51.2.sh"
TIMESTAMP="$(date +%Y%m%d%H%M%S)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
TARGET_OVERRIDE=""
DRY_RUN=0
VALIDATE_ONLY=0
ROLLBACK_DIR=""

info() { printf '[BQCA v51.2][INFO] %s\n' "$*"; }
warn() { printf '[BQCA v51.2][WARN] %s\n' "$*" >&2; }
fail() { printf '[BQCA v51.2][ERROR] %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'USAGE'
BQCA Bob Shell 2.x Custom-Mode Rule Parity Patch v51.2

Usage:
  ./patch-BQCA-v51.2.sh [options]

Options:
  --target <path>        Explicit standalone BQCA appliance root.
  --dry-run              Display the patch plan without changing files.
  --validate-only        Validate the installed v51.2 rule parity feature.
  --rollback <backup>    Restore a v51.2 timestamped backup directory.
  -h, --help             Show this help.

Expected placement:
  <BQCA-root>/patches/BQCA/patch-BQCA-v51.2.sh
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
XLAUNCHPAD="$BQCA_ROOT/xLaunchpad.sh"
ENV_EXAMPLE="$BQCA_ROOT/.env.example"
SYNC_PY="$TOOLS_DIR/bqca-custom-mode-rules.py"
SYNC_SH="$TOOLS_DIR/bqca-custom-mode-rules.sh"
DNA_DOCTOR_PY="$TOOLS_DIR/bqca-bob2-dna-doctor.py"
DNA_DOCTOR_SH="$TOOLS_DIR/bqca-bob2-dna-doctor.sh"
MODE_DOCTOR_PY="$TOOLS_DIR/bqca-bob-mode-doctor.py"
MODE_DOCTOR_SH="$TOOLS_DIR/bqca-bob-mode-doctor.sh"
POLICY_DOCTOR_PY="$TOOLS_DIR/bqca-policy-doctor.py"
POLICY_DOCTOR_SH="$TOOLS_DIR/bqca-policy-doctor.sh"
POLICY_LISTENER="$TOOLS_DIR/bqca-active-policy-listener.sh"
PATCH_RECORD_DIR="$BOB_ROOT/patches-applied"
PATCH_RECORD_FILE="$PATCH_RECORD_DIR/${PATCH_ID}.txt"
BACKUP_ROOT="$BOB_ROOT/patch-backups"
BACKUP_DIR="$BACKUP_ROOT/${PATCH_ID}.${TIMESTAMP}"
BACKUP_MANIFEST="$BACKUP_DIR/BQCA-v51.2-backup-manifest.txt"
MANAGED_PATHS="$BACKUP_DIR/managed-paths.txt"
SYNC_MARKER="BQCA-CUSTOM-MODE-RULE-SYNC-v51.2"
ROUTING_MARKER="BQCA-BOB2-CUSTOM-MODE-ROUTING-v51.2"

find_bob2_launcher() {
  local found
  found="$(find "$BQCA_ROOT" -maxdepth 1 -type f -name 'bob-quantum-v2.*.sh' -print | sort -V | tail -n 1)"
  [[ -n "$found" ]] || fail "No Bob Shell 2.x BQCA launcher found in $BQCA_ROOT"
  printf '%s\n' "$found"
}
BOB2_LAUNCHER="$(find_bob2_launcher)"

managed_paths() {
  cat <<EOF
xLaunchpad.sh
${BOB2_LAUNCHER#$BQCA_ROOT/}
.env.example
.bob/BQCA-ACTIVE-POLICY-REGISTRY.json
.bob/quantum-tools/bqca-custom-mode-rules.py
.bob/quantum-tools/bqca-custom-mode-rules.sh
.bob/quantum-tools/bqca-bob2-dna-doctor.py
.bob/quantum-tools/bqca-bob2-dna-doctor.sh
.bob/quantum-tools/bqca-bob-mode-doctor.py
.bob/quantum-tools/bqca-bob-mode-doctor.sh
.bob/quantum-tools/bqca-policy-doctor.py
.bob/quantum-tools/bqca-policy-doctor.sh
.bob/quantum-tools/bqca-active-policy-listener.sh
.bob/rules-quantum-qiskit-connector
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
Protected: .env, custom_modes.yaml content, active policy, governed stores, HOME/.bob, HOME/qiskit-v2x-env, HOME/.qiskit/qiskit-ibm.json
Restore with:
  $PATCH_FILE_NAME --target "$BQCA_ROOT" --rollback "$BACKUP_DIR"
EOF
}

restore_backup() {
  local backup="$1" backup_abs rel src dst
  backup_abs="$(cd "$backup" 2>/dev/null && pwd -P || true)"
  [[ -n "$backup_abs" ]] || fail "Rollback directory not found: $backup"
  [[ -f "$backup_abs/BQCA-v51.2-backup-manifest.txt" ]] || fail "Not a BQCA v51.2 backup: $backup_abs"
  [[ -f "$backup_abs/managed-paths.txt" ]] || fail "Backup managed-paths.txt is missing: $backup_abs"
  info "Restoring v51.2 backup: $backup_abs"
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
  info "Rollback complete."
}

if [[ -n "$ROLLBACK_DIR" ]]; then
  restore_backup "$ROLLBACK_DIR"
  exit 0
fi

info "Resolved BQCA root: $BQCA_ROOT"
info "Patch identity: $PATCH_ID"
info "Bob 2.x launcher: ${BOB2_LAUNCHER#$BQCA_ROOT/}"
info "Protected assets: .env, custom_modes.yaml content, central policy, governed stores, home Bob/Qiskit state"

if ((DRY_RUN)); then
  cat <<'DRY'
[BQCA v51.2][DRY-RUN]
  1. Install a custom-mode/rule parity synchronizer under .bob/quantum-tools.
  2. Read custom mode slugs from .bob/custom_modes.yaml without changing the file.
  3. Ensure every slug has a non-empty .bob/rules-<slug>/ directory.
  4. Seed rules-quantum-qiskit-connector from the existing Qiskit Connector rules.
  5. Run parity synchronization before Bob Shell 2.x project-DNA assurance.
  6. Align Bob 2.x menu defaults with quantum-qiskit-connector, quantum-smart, quantum-code-heron, and quantum-advanced.
  7. Update .env.example only; leave private .env unchanged.
  8. Preserve compatibility rule directories used by Bob 1.x and historical flows.
DRY
  exit 0
fi

write_sync_py() {
  cat > "$SYNC_PY" <<'PY'
#!/usr/bin/env python3
"""BQCA custom-mode/custom-rule parity synchronizer, v51.2."""
from __future__ import annotations
import argparse, json, pathlib, re, shutil, sys

VALID = re.compile(r"^[A-Za-z0-9-]+$")
SUFFIXES = {".md", ".txt", ".xml"}
DNA_NAME = "BQCA-" + "BOB-SHELL-V2-DNA"
POLICY_NAME = "BQCA-" + "ACTIVE-CENTRAL-POLICY"
ALIASES = {
    "quantum-qiskit-connector": ["qiskit-connector", "code", "quantum-code"],
    "quantum-code-default": ["quantum-code", "code"],
    "quantum-code-heron": ["quantum-code", "code"],
    "quantum-advanced-default": ["advanced"],
    "quantum-advanced": ["advanced"],
    "quantum-smart": ["quantum-intelligence", "orchestrator"],
}


def root() -> pathlib.Path:
    return pathlib.Path(__file__).resolve().parents[2]


def load_modes(path: pathlib.Path) -> list[dict]:
    try:
        import yaml
        data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    except Exception as exc:
        raise RuntimeError(f"cannot parse custom_modes.yaml: {exc}") from exc
    value = data.get("customModes") or data.get("modes") or []
    if not isinstance(value, list):
        raise RuntimeError("customModes must be a list")
    return [m for m in value if isinstance(m, dict)]


def files(directory: pathlib.Path) -> list[pathlib.Path]:
    if not directory.is_dir():
        return []
    return sorted(p for p in directory.rglob("*") if p.is_file() and p.suffix.lower() in SUFFIXES)


def dna_block() -> str:
    return (
        f"<!-- {DNA_NAME}:BEGIN -->\n"
        "## Bob Shell 2.x BQCA project-DNA binding\n"
        "Read `AGENTS.md`, resolve the active central policy, honor exported menu context, and use relevant skills, tools, and the offline knowledgebase without replacing this rule's specialized purpose.\n"
        f"<!-- {DNA_NAME}:END -->"
    )


def policy_block() -> str:
    return (
        f"<!-- {POLICY_NAME}:BEGIN -->\n"
        "## Active central policy binding\n"
        "Resolve and obey the current stable BQCA policy and require current design/code compliance reports before completion.\n"
        f"<!-- {POLICY_NAME}:END -->"
    )


def generic(mode: dict) -> str:
    slug = str(mode.get("slug", ""))
    name = str(mode.get("name", slug))
    role = str(mode.get("roleDefinition", "")).strip()
    use = str(mode.get("whenToUse", "")).strip()
    return f"""# {name} — Custom Rules

This is the custom-rule bridge for the BQCA mode slug `{slug}`.

## Role

{role or 'Use the role and instructions declared in .bob/custom_modes.yaml.'}

## When to use

{use or 'Use this mode only when selected by BQCA or the user.'}

## Requirements

- Preserve the active BQCA policy, project identity, security, routing, validation, notebook, and result-output controls.
- Use relevant BQCA skills, quantum tools, and the offline knowledgebase.
- Never silently fall back to generic Bob behavior.

{policy_block()}

{dna_block()}
"""


def candidate_dirs(bob: pathlib.Path, slug: str) -> list[pathlib.Path]:
    names = list(ALIASES.get(slug, []))
    if slug.startswith("quantum-"):
        names.append(slug.removeprefix("quantum-"))
    result=[]; seen=set()
    for name in names:
        if name and name != slug and name not in seen:
            seen.add(name); result.append(bob / f"rules-{name}")
    return result


def inspect(do_sync: bool) -> dict:
    base=root(); bob=base/".bob"
    modes=load_modes(bob/"custom_modes.yaml")
    slugs=[str(m.get("slug", "")).strip() for m in modes]
    errors=[]; actions=[]
    if len(slugs) != len(set(slugs)):
        errors.append("duplicate custom mode slugs")
    for mode in modes:
        slug=str(mode.get("slug", "")).strip()
        if not VALID.fullmatch(slug):
            errors.append(f"invalid slug: {slug}")
            continue
        target=bob/f"rules-{slug}"
        if not files(target) and do_sync:
            source=next((d for d in candidate_dirs(bob, slug) if files(d)), None)
            if source:
                if target.exists() and not target.is_dir():
                    errors.append(f"rule path is not a directory: {target}")
                    continue
                if not target.exists():
                    shutil.copytree(source, target)
                else:
                    for src in files(source):
                        dst=target/src.relative_to(source)
                        dst.parent.mkdir(parents=True, exist_ok=True)
                        shutil.copy2(src, dst)
                actions.append(f"rules-{slug} <- {source.name}")
            else:
                target.mkdir(parents=True, exist_ok=True)
                (target/f"01-bqca-{slug}-rules.md").write_text(generic(mode), encoding="utf-8")
                actions.append(f"rules-{slug} <- generated")
            target.chmod(0o755)
            for path in files(target):
                path.chmod(0o644)
        current=files(target)
        if not target.is_dir(): errors.append(f"missing rules-{slug}")
        elif not current: errors.append(f"empty rules-{slug}")
    orphans=sorted(d.name for d in bob.glob("rules-*") if d.is_dir() and d.name.removeprefix("rules-") not in set(slugs))
    return {"mode_count":len(modes),"actions":actions,"orphans":orphans,"errors":errors,"status":"PASS" if not errors else "FAIL"}


def main() -> int:
    parser=argparse.ArgumentParser()
    parser.add_argument("command", choices=["check","sync","report","json"])
    parser.add_argument("--quiet", action="store_true")
    args=parser.parse_args()
    result=inspect(args.command=="sync")
    if args.command=="json": print(json.dumps(result, indent=2))
    elif args.command=="report" or (not args.quiet and args.command in {"check","sync"}):
        print("="*88); print("BQCA v51.2 CUSTOM MODE / RULE PARITY REPORT"); print("="*88)
        print(f"Custom modes             : {result['mode_count']}")
        print(f"Missing/invalid issues   : {len(result['errors'])}")
        print(f"Compatibility rule dirs : {len(result['orphans'])}")
        for action in result["actions"]: print(f"Created                  : {action}")
        if result["orphans"]:
            print("-"*88); print("PRESERVED COMPATIBILITY RULE DIRECTORIES")
            for item in result["orphans"]: print(f"- {item}")
        if result["errors"]:
            print("-"*88); print("ISSUES")
            for item in result["errors"]: print(f"- {item}")
        print("-"*88); print(f"FINAL MODE-RULE STATUS   : {result['status']}"); print("="*88)
        print(f"BQCA_CUSTOM_MODE_RULES={result['status']}")
    return 0 if result["status"]=="PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())

# BQCA-ACTIVE-CENTRAL-POLICY:BEGIN
# Resolve and obey the current stable BQCA policy and validation contract.
# BQCA-ACTIVE-CENTRAL-POLICY:END

# BQCA-BOB-SHELL-V2-DNA:BEGIN
# Bind this tool to AGENTS.md, active BQCA policy, menu context, current rules,
# relevant skills/tools, and the offline knowledgebase without changing purpose.
# BQCA-BOB-SHELL-V2-DNA:END
PY
  chmod 755 "$SYNC_PY"
}

write_sync_sh() {
  cat > "$SYNC_SH" <<'SH2'
#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
exec python3 "${SCRIPT_DIR}/bqca-custom-mode-rules.py" "$@"

# BQCA-ACTIVE-CENTRAL-POLICY:BEGIN
# Resolve and obey the current stable BQCA policy and validation contract.
# BQCA-ACTIVE-CENTRAL-POLICY:END

# BQCA-BOB-SHELL-V2-DNA:BEGIN
# Bind this tool to AGENTS.md, active BQCA policy, menu context, current rules,
# relevant skills/tools, and the offline knowledgebase without changing purpose.
# BQCA-BOB-SHELL-V2-DNA:END
SH2
  chmod 755 "$SYNC_SH"
}

normalize_permissions() {
  local file
  for file in "$DNA_DOCTOR_PY" "$DNA_DOCTOR_SH" "$MODE_DOCTOR_PY" "$MODE_DOCTOR_SH" "$POLICY_DOCTOR_PY" "$POLICY_DOCTOR_SH" "$POLICY_LISTENER"; do
    [[ -f "$file" ]] || continue
    chmod 755 "$file"
  done
}

patch_xlaunchpad() {
  python3 - "$XLAUNCHPAD" "$SYNC_MARKER" <<'PY'
import pathlib,re,sys
path=pathlib.Path(sys.argv[1]); marker=sys.argv[2]
text=path.read_text(encoding="utf-8")
block=f'''# {marker}:BEGIN
_BQCA_MODE_RULE_SYNC="${{SCRIPT_DIR}}/.bob/quantum-tools/bqca-custom-mode-rules.sh"
if [[ ! -x "${{_BQCA_MODE_RULE_SYNC}}" ]] || ! "${{_BQCA_MODE_RULE_SYNC}}" sync --quiet; then
  printf '[BQCA][ERROR] Custom modes and custom rules are not synchronized. Run: %s report\\n' \\
    "${{_BQCA_MODE_RULE_SYNC}}" >&2
  exit 1
fi
unset _BQCA_MODE_RULE_SYNC
# {marker}:END
'''
pat=re.compile(rf'(?ms)^# {re.escape(marker)}:BEGIN\n.*?^# {re.escape(marker)}:END\n?')
if pat.search(text): text=pat.sub(block,text,count=1)
else:
    needle=re.search(r'(?m)^# BQCA-BOB-SHELL-V2-DNA-PREFLIGHT-v51\.0:BEGIN$',text)
    if not needle: raise SystemExit("Unable to locate Bob Shell 2.x DNA preflight")
    text=text[:needle.start()]+block+'\n'+text[needle.start():]
path.write_text(text,encoding="utf-8")
PY
  chmod 755 "$XLAUNCHPAD"
}

patch_launcher() {
  python3 - "$BOB2_LAUNCHER" "$SYNC_MARKER" "$ROUTING_MARKER" <<'PY'
import pathlib,re,sys
path=pathlib.Path(sys.argv[1]); sync_marker=sys.argv[2]; routing_marker=sys.argv[3]
text=path.read_text(encoding="utf-8")
for marker in (sync_marker,routing_marker):
    text=re.sub(rf'(?ms)^# {re.escape(marker)}:BEGIN\n.*?^# {re.escape(marker)}:END\n?', '', text)
# Direct-launch parity check after SCRIPT_DIR is established.
sync=f'''# {sync_marker}:BEGIN
if [[ "${{BQCA_CUSTOM_MODE_RULES_SYNCED:-0}}" != "1" ]]; then
  _BQCA_MODE_RULE_SYNC="${{SCRIPT_DIR}}/.bob/quantum-tools/bqca-custom-mode-rules.sh"
  if [[ ! -x "${{_BQCA_MODE_RULE_SYNC}}" ]] || ! "${{_BQCA_MODE_RULE_SYNC}}" sync --quiet; then
    printf '[BQCA][ERROR] Custom modes and custom rules are not synchronized. Run: %s report\\n' "${{_BQCA_MODE_RULE_SYNC}}" >&2
    exit 1
  fi
  BQCA_CUSTOM_MODE_RULES_SYNCED=1
  export BQCA_CUSTOM_MODE_RULES_SYNCED
  unset _BQCA_MODE_RULE_SYNC
fi
# {sync_marker}:END
'''
match=re.search(r'(?m)^SCRIPT_DIR=.*$',text)
if not match: raise SystemExit("Unable to locate SCRIPT_DIR in Bob 2.x launcher")
text=text[:match.end()]+'\n\n'+sync+text[match.end():]
# Replace the four initial defaults when present.
repls={
'BQCA_BOB2_INTERACTIVE_MODE="${BQCA_BOB2_INTERACTIVE_MODE:-$(bqca_bob2_resolve_mode code agent)}"':'BQCA_BOB2_INTERACTIVE_MODE="${BQCA_BOB2_INTERACTIVE_MODE:-$(bqca_bob2_resolve_mode quantum-qiskit-connector quantum-smart)}"',
'BQCA_BOB2_ASK_MODE="${BQCA_BOB2_ASK_MODE:-$(bqca_bob2_resolve_mode ask ask)}"':'BQCA_BOB2_ASK_MODE="${BQCA_BOB2_ASK_MODE:-$(bqca_bob2_resolve_mode quantum-smart ask)}"',
'BQCA_BOB2_CODE_MODE="${BQCA_BOB2_CODE_MODE:-$(bqca_bob2_resolve_mode code agent)}"':'BQCA_BOB2_CODE_MODE="${BQCA_BOB2_CODE_MODE:-$(bqca_bob2_resolve_mode quantum-code-heron quantum-qiskit-connector)}"',
'BQCA_BOB2_ADVANCED_MODE="${BQCA_BOB2_ADVANCED_MODE:-$(bqca_bob2_resolve_mode advanced plan)}"':'BQCA_BOB2_ADVANCED_MODE="${BQCA_BOB2_ADVANCED_MODE:-$(bqca_bob2_resolve_mode quantum-advanced advanced)}"',
}
for old,new in repls.items(): text=text.replace(old,new)
routing=f'''# {routing_marker}:BEGIN
bqca_bob2_normalize_mode_alias_v512() {{
  local value
  value="$(bqca_trim_mode_value "${{1:-}}")"
  case "${{value}}" in
    code|qiskit-connector) printf '%s\\n' quantum-qiskit-connector ;;
    quantum-code) printf '%s\\n' quantum-code-default ;;
    quantum-intelligence) printf '%s\\n' quantum-smart ;;
    *) printf '%s\\n' "${{value}}" ;;
  esac
}}

bqca_bob2_first_available_mode_v512() {{
  local candidate
  for candidate in "$@"; do
    if bqca_bob2_mode_is_available "${{candidate}}"; then printf '%s\\n' "${{candidate}}"; return 0; fi
  done
  return 1
}}

bqca_bob2_resolve_role_mode_v512() {{
  local current_value="${{1:-}}" role="$2" resolved
  resolved="$(bqca_bob2_normalize_mode_alias_v512 "${{current_value}}")"
  if [[ -n "${{resolved}}" ]]; then
    bqca_bob2_mode_is_available "${{resolved}}" || {{ printf '[BQCA][ERROR] Bob Shell 2.x %s mode is unavailable: %s\\n' "${{role}}" "${{resolved}}" >&2; return 1; }}
    printf '%s\\n' "${{resolved}}"; return 0
  fi
  case "${{role}}" in
    interactive) bqca_bob2_first_available_mode_v512 quantum-qiskit-connector quantum-smart ask quantum-code-default ;;
    expert) bqca_bob2_first_available_mode_v512 quantum-smart ask ;;
    developer) bqca_bob2_first_available_mode_v512 quantum-code-heron quantum-qiskit-connector quantum-code-default ;;
    advanced) bqca_bob2_first_available_mode_v512 quantum-advanced advanced quantum-advanced-default plan ;;
    *) return 1 ;;
  esac
}}

bqca_bob2_refresh_modes() {{
  BQCA_BOB2_INTERACTIVE_MODE="$(bqca_bob2_resolve_role_mode_v512 "${{BQCA_BOB2_INTERACTIVE_MODE:-}}" interactive)" || return 1
  BQCA_BOB2_ASK_MODE="$(bqca_bob2_resolve_role_mode_v512 "${{BQCA_BOB2_ASK_MODE:-}}" expert)" || return 1
  BQCA_BOB2_CODE_MODE="$(bqca_bob2_resolve_role_mode_v512 "${{BQCA_BOB2_CODE_MODE:-}}" developer)" || return 1
  BQCA_BOB2_ADVANCED_MODE="$(bqca_bob2_resolve_role_mode_v512 "${{BQCA_BOB2_ADVANCED_MODE:-}}" advanced)" || return 1
  export BQCA_BOB2_INTERACTIVE_MODE BQCA_BOB2_ASK_MODE BQCA_BOB2_CODE_MODE BQCA_BOB2_ADVANCED_MODE
}}

bqca_bob2_require_mode() {{
  local selected_mode
  selected_mode="$(bqca_bob2_normalize_mode_alias_v512 "${{1:-}}")"
  [[ -n "${{selected_mode}}" ]] || {{ printf '[BQCA][ERROR] Refusing to invoke Bob Shell 2.x with an empty mode.\\n' >&2; return 1; }}
  bqca_bob2_mode_is_available "${{selected_mode}}" || {{ printf '[BQCA][ERROR] Refusing unavailable Bob Shell 2.x mode: %s\\n' "${{selected_mode}}" >&2; return 1; }}
  printf '%s\\n' "${{selected_mode}}"
}}

bqca_bob2_refresh_modes
# {routing_marker}:END
'''
needle='# BQCA-BOB2-MODE-BRIDGE-v51.1:END\n'
if needle not in text: raise SystemExit("Unable to locate v51.1 mode bridge")
text=text.replace(needle,needle+'\n'+routing+'\n',1)
path.write_text(text,encoding="utf-8")
PY
  chmod 755 "$BOB2_LAUNCHER"
}

patch_env_example() {
  python3 - "$ENV_EXAMPLE" <<'PY'
import pathlib,re,sys
path=pathlib.Path(sys.argv[1]); text=path.read_text(encoding="utf-8")
values={
"BQCA_BOB2_INTERACTIVE_MODE":"quantum-qiskit-connector",
"BQCA_BOB2_ASK_MODE":"quantum-smart",
"BQCA_BOB2_CODE_MODE":"quantum-code-heron",
"BQCA_BOB2_ADVANCED_MODE":"quantum-advanced",
}
for key,value in values.items():
    pattern=re.compile(rf'(?m)^{re.escape(key)}=.*$')
    text=pattern.sub(f"{key}={value}",text,count=1) if pattern.search(text) else text.rstrip()+f"\n{key}={value}\n"
path.write_text(text,encoding="utf-8")
PY
  chmod 644 "$ENV_EXAMPLE"
}

patch_registry() {
  local registry="$BOB_ROOT/BQCA-ACTIVE-POLICY-REGISTRY.json"
  [[ -f "$registry" ]] || return 0
  python3 - "$registry" <<'PY'
import json,pathlib,sys
path=pathlib.Path(sys.argv[1]); data=json.loads(path.read_text(encoding="utf-8"))
data["custom_mode_rule_sync_path"]=".bob/quantum-tools/bqca-custom-mode-rules.sh"
data["custom_mode_rule_sync_patch"]="BQCA-v51.2"
data["custom_mode_rule_sync_behavior"]="ensure-rules-before-dna-assurance"
data["bob2_menu_mode_defaults"]={"interactive":"quantum-qiskit-connector","ask":"quantum-smart","code":"quantum-code-heron","advanced":"quantum-advanced"}
path.write_text(json.dumps(data,indent=2)+"\n",encoding="utf-8")
PY
  chmod 644 "$registry"
}

validate_installation() {
  local failures=0 mode_count matched sync_count
  normalize_permissions
  for file in "$SYNC_PY" "$DNA_DOCTOR_PY" "$MODE_DOCTOR_PY" "$POLICY_DOCTOR_PY"; do
    [[ -x "$file" ]] || { warn "Missing executable: $file"; failures=$((failures+1)); }
    python3 -m py_compile "$file" || failures=$((failures+1))
  done
  for file in "$SYNC_SH" "$XLAUNCHPAD" "$BOB2_LAUNCHER" "$DNA_DOCTOR_SH" "$MODE_DOCTOR_SH" "$POLICY_DOCTOR_SH" "$POLICY_LISTENER"; do
    [[ -x "$file" ]] || { warn "Missing executable: $file"; failures=$((failures+1)); }
    bash -n "$file" || failures=$((failures+1))
  done
  "$SYNC_SH" sync --quiet || failures=$((failures+1))
  "$SYNC_SH" check --quiet || failures=$((failures+1))
  read -r mode_count matched < <(python3 - "$CUSTOM_MODES" "$BOB_ROOT" <<'PY'
import pathlib,re,sys,yaml
m=pathlib.Path(sys.argv[1]); b=pathlib.Path(sys.argv[2]); data=yaml.safe_load(m.read_text()) or {}; modes=data.get("customModes") or []
matched=0
for mode in modes:
    slug=str(mode.get("slug", "")); d=b/f"rules-{slug}"
    if re.fullmatch(r"[A-Za-z0-9-]+",slug) and d.is_dir() and any(p.is_file() and p.suffix.lower() in {".md",".txt",".xml"} for p in d.rglob("*")): matched+=1
print(len(modes),matched)
PY
)
  [[ "$mode_count" -gt 0 && "$matched" -eq "$mode_count" ]] || { warn "Mode-rule coverage ${matched}/${mode_count}"; failures=$((failures+1)); }
  [[ -d "$BOB_ROOT/rules-quantum-qiskit-connector" ]] || { warn "Missing rules-quantum-qiskit-connector"; failures=$((failures+1)); }
  sync_count="$(grep -c "$SYNC_MARKER:BEGIN" "$XLAUNCHPAD" || true)"
  [[ "$sync_count" -eq 1 ]] || { warn "xLaunchpad synchronization marker count is $sync_count"; failures=$((failures+1)); }
  python3 - "$XLAUNCHPAD" <<'PY' || failures=$((failures+1))
import pathlib,sys
text=pathlib.Path(sys.argv[1]).read_text()
a=text.find("BQCA-CUSTOM-MODE-RULE-SYNC-v51.2:BEGIN"); b=text.find("BQCA-BOB-SHELL-V2-DNA-PREFLIGHT-v51.0:BEGIN")
if a<0 or b<0 or a>b: raise SystemExit(1)
PY
  for needle in \
    'BQCA_BOB2_INTERACTIVE_MODE=quantum-qiskit-connector' \
    'BQCA_BOB2_ASK_MODE=quantum-smart' \
    'BQCA_BOB2_CODE_MODE=quantum-code-heron' \
    'BQCA_BOB2_ADVANCED_MODE=quantum-advanced'; do
    grep -Fqx "$needle" "$ENV_EXAMPLE" || { warn ".env.example missing $needle"; failures=$((failures+1)); }
  done
  "$MODE_DOCTOR_SH" check --quiet || { warn "Bob mode doctor failed"; failures=$((failures+1)); }
  "$DNA_DOCTOR_SH" check --quiet || { warn "Bob Shell 2.x DNA doctor failed"; "$DNA_DOCTOR_SH" report >&2 || true; failures=$((failures+1)); }
  "$POLICY_LISTENER" validate >/dev/null || { warn "Active-policy listener failed"; failures=$((failures+1)); }
  "$POLICY_DOCTOR_SH" check --quiet || { warn "Active-policy doctor failed"; failures=$((failures+1)); }
  ((failures==0)) || fail "v51.2 validation failed with $failures issue(s)."
  info "Validation passed: ${matched}/${mode_count} custom modes have matching custom rules; Bob 2.x DNA and active-policy assurance pass."
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
write_sync_py
write_sync_sh
"$SYNC_SH" sync --quiet
patch_xlaunchpad
patch_launcher
patch_env_example
patch_registry
[[ "$CUSTOM_SHA_BEFORE" == "$(sha256sum "$CUSTOM_MODES" | awk '{print $1}')" ]] || fail "custom_modes.yaml was unexpectedly changed"
[[ "$POLICY_SHA_BEFORE" == "$(sha256sum "$BOB_ROOT/BQCA-PRODUCTION-POLICY.md" | awk '{print $1}')" ]] || fail "active central policy was unexpectedly changed"
cat > "$PATCH_RECORD_FILE" <<EOF
Patch: $PATCH_ID
Applied: $(date -u '+%Y-%m-%dT%H:%M:%SZ')
Root: $BQCA_ROOT
Backup: $BACKUP_DIR
Bob 2.x launcher: ${BOB2_LAUNCHER#$BQCA_ROOT/}
Repair: synchronized every custom mode slug with .bob/rules-<slug>/ before DNA assurance
Primary rule: .bob/rules-quantum-qiskit-connector seeded from existing Qiskit Connector intelligence
Menu defaults: interactive=quantum-qiskit-connector, ask=quantum-smart, code=quantum-code-heron, advanced=quantum-advanced
Private .env: excluded and unchanged
custom_modes.yaml: preserved byte-for-byte
Active central policy: preserved byte-for-byte
EOF
chmod 644 "$PATCH_RECORD_FILE"
validate_installation
info "Patch $PATCH_ID applied successfully."
info "Backup: $BACKUP_DIR"
info "Mode-rule synchronizer: ${SYNC_SH#$BQCA_ROOT/}"
