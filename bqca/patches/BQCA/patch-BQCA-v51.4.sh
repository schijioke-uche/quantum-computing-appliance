#!/usr/bin/env bash
set -Eeuo pipefail

#===============================================================================
# IBM Bob Quantum Computing Agent (BQCA)
# Trusted Interactive Chat Auto-Approval Patch v51.4
#
# Purpose:
#   Eliminate routine tool-approval interruptions in trusted BQCA interactive
#   and resumed chat sessions without changing the active quantum policy,
#   governed artifact routing, Qiskit execution policy, or non-interactive flow.
#
# Bob Shell compatibility:
#   - Bob Shell 2.x: bob chat --trust --auto-approve
#   - Bob Shell 1.x: capability-detected full approval flag; prefer
#     --auto-approve when advertised, otherwise use --yolo.
#
# Safety boundary:
#   Auto-approval is enabled only for BQCA chat/resume sessions started from the
#   structurally validated BQCA project root. It is not authorization to modify
#   protected credentials, Bob home settings, Qiskit account state, files
#   outside the workspace, or to execute destructive commands.
#
# Protected assets:
#   The installer does not read, copy, back up, modify, chmod, remove, or restore
#   the project .env, governed design/code stores, $HOME/.bob,
#   $HOME/qiskit-v2x-env, or $HOME/.qiskit/qiskit-ibm.json.
#===============================================================================

PATCH_ID="BQCA-v51.4"
PATCH_FILE_NAME="patch-BQCA-v51.4.sh"
TIMESTAMP="$(date +%Y%m%d%H%M%S)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_OVERRIDE=""
DRY_RUN=0
VALIDATE_ONLY=0
ROLLBACK_DIR=""

info() { printf '[BQCA v51.4][INFO] %s\n' "$*"; }
warn() { printf '[BQCA v51.4][WARN] %s\n' "$*" >&2; }
fail() { printf '[BQCA v51.4][ERROR] %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'USAGE'
BQCA Trusted Interactive Chat Auto-Approval Patch v51.4

Usage:
  ./patch-BQCA-v51.4.sh [options]

Options:
  --target <path>        Explicit BQCA appliance root.
  --dry-run              Display planned changes without modifying files.
  --validate-only        Validate the current v51.4 installation.
  --rollback <backup>    Restore a timestamped v51.4 backup directory.
  -h, --help             Show this help.

# ROLLBACK ACTION:
./patches/BQCA/patch-BQCA-v51.4.sh \
  --rollback \
  .bob/patch-backups/BQCA-v51.4.YYYYMMDDHHMMSS

Expected placement:
  <BQCA-root>/patches/BQCA/patch-BQCA-v51.4.sh

The private .env and governed workload stores are never touched.
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

for cmd in bash chmod cmp cp date dirname find grep mkdir mktemp mv python3 rm sed sha256sum sort; do
  command -v "$cmd" >/dev/null 2>&1 || fail "Required command not found: $cmd"
done

is_bqca_root() {
  local candidate="$1"
  [[ -d "$candidate/.bob" ]] || return 1
  [[ -f "$candidate/.bob/custom_modes.yaml" ]] || return 1
  [[ -d "$candidate/.bob/skills" ]] || return 1
  [[ -d "$candidate/.bob/quantum-tools" ]] || return 1
  [[ -f "$candidate/xLaunchpad.sh" ]] || return 1
  [[ -d "$candidate/bob-quantum-designs" ]] || return 1
  [[ -d "$candidate/bob-quantum-store" ]] || return 1
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
RULES_ROOT="$BOB_ROOT"
SKILLS_DIR="$BOB_ROOT/skills"
CUSTOM_MODES="$BOB_ROOT/custom_modes.yaml"
XLAUNCHPAD="$BQCA_ROOT/xLaunchpad.sh"
ENV_EXAMPLE="$BQCA_ROOT/.env.example"
README_FILE="$BQCA_ROOT/README.md"
AGENTS_FILE="$BQCA_ROOT/AGENTS.md"
POLICY_STABLE="$BOB_ROOT/BQCA-PRODUCTION-POLICY.md"
REGISTRY="$BOB_ROOT/BQCA-ACTIVE-POLICY-REGISTRY.json"
HELPER_SH="$TOOLS_DIR/bqca-chat-auto-approval.sh"
DOCTOR_SH="$TOOLS_DIR/bqca-chat-auto-approval-doctor.sh"
AUTO_RULE="$BOB_ROOT/rules/01-bqca-trusted-chat-auto-approval.md"
PATCH_RECORD_DIR="$BOB_ROOT/patches-applied"
PATCH_RECORD_FILE="$PATCH_RECORD_DIR/${PATCH_ID}.txt"
BACKUP_ROOT="$BOB_ROOT/patch-backups"
BACKUP_DIR="$BACKUP_ROOT/${PATCH_ID}.${TIMESTAMP}"
CREATED_LIST="$BACKUP_DIR/created-files.txt"
MARKER="BQCA-TRUSTED-CHAT-AUTO-APPROVAL-v51.4"

BOB1_LAUNCHER=""
if [[ -f "$BQCA_ROOT/bob-quantum-v1x.sh" ]]; then
  BOB1_LAUNCHER="$BQCA_ROOT/bob-quantum-v1x.sh"
else
  BOB1_LAUNCHER="$(find "$BQCA_ROOT" -maxdepth 1 -type f -name 'bob-quantum-v1*.sh' -print | sort | tail -n 1)"
fi
BOB2_LAUNCHER="$(find "$BQCA_ROOT" -maxdepth 1 -type f -name 'bob-quantum-v2*.sh' -print | sort -V | tail -n 1)"

[[ -n "$BOB2_LAUNCHER" && -f "$BOB2_LAUNCHER" ]] || fail "No Bob Shell 2.x BQCA launcher found in $BQCA_ROOT"
[[ -f "$POLICY_STABLE" ]] || fail "Missing active policy: $POLICY_STABLE"
[[ -f "$REGISTRY" ]] || fail "Missing active policy registry: $REGISTRY"

VERSIONED_POLICY="$(python3 - "$BQCA_ROOT" "$REGISTRY" <<'PY'
import json, pathlib, sys
root = pathlib.Path(sys.argv[1])
registry = json.loads(pathlib.Path(sys.argv[2]).read_text(encoding='utf-8'))
value = registry.get('versioned_policy_path') or registry.get('active_authority', {}).get('versioned_policy')
if not value:
    raise SystemExit('Active policy registry has no versioned_policy_path')
path = pathlib.Path(value)
if not path.is_absolute():
    path = root / path
print(path.resolve())
PY
)"
[[ -f "$VERSIONED_POLICY" ]] || fail "Missing versioned active policy: $VERSIONED_POLICY"

is_protected_path() {
  local path="$1"
  case "$path" in
    "$BQCA_ROOT/.env"|"$BQCA_ROOT/bob-quantum-designs"/*|"$BQCA_ROOT/bob-quantum-store"/*|"$BQCA_ROOT/.git"/*|"$BOB_ROOT/patch-backups"/*)
      return 0
      ;;
  esac
  return 1
}

track_created() {
  local path="$1" rel
  [[ -e "$path" ]] && return 0
  rel="${path#$BQCA_ROOT/}"
  mkdir -p "$BACKUP_DIR"
  printf '%s\n' "$rel" >> "$CREATED_LIST"
}

backup_file() {
  local source="$1" rel destination
  [[ -e "$source" ]] || return 0
  is_protected_path "$source" && return 0
  rel="${source#$BQCA_ROOT/}"
  destination="$BACKUP_DIR/$rel"
  mkdir -p "$(dirname "$destination")"
  cp -a "$source" "$destination"
}

collect_awareness_files() {
  find "$BOB_ROOT" -maxdepth 2 -type f -path '*/rules*/*.md' -print0
  find "$SKILLS_DIR" -type f \( -name 'SKILL.md' -o -name 'README-custom-skills.md' \) -print0
  find "$TOOLS_DIR" -maxdepth 1 -type f \
    \( -name '*.sh' -o -name '*.py' -o -name '*.md' -o -name '*.txt' -o -name '*.yaml' -o -name '*.yml' \) -print0
}

create_backup() {
  mkdir -p "$BACKUP_DIR"
  : > "$CREATED_LIST"
  backup_file "$XLAUNCHPAD"
  backup_file "$ENV_EXAMPLE"
  backup_file "$README_FILE"
  backup_file "$AGENTS_FILE"
  backup_file "$CUSTOM_MODES"
  backup_file "$POLICY_STABLE"
  backup_file "$VERSIONED_POLICY"
  backup_file "$REGISTRY"
  backup_file "$BOB1_LAUNCHER"
  backup_file "$BOB2_LAUNCHER"
  backup_file "$HELPER_SH"
  backup_file "$DOCTOR_SH"
  backup_file "$AUTO_RULE"
  backup_file "$PATCH_RECORD_FILE"

  while IFS= read -r -d '' file; do
    backup_file "$file"
  done < <(collect_awareness_files)

  cat > "$BACKUP_DIR/BQCA-v51.4-backup-manifest.txt" <<MANIFEST
Patch: $PATCH_ID
Created: $(date -u '+%Y-%m-%dT%H:%M:%SZ')
Appliance root: $BQCA_ROOT
Bob 1.x launcher: ${BOB1_LAUNCHER:-not-present}
Bob 2.x launcher: $BOB2_LAUNCHER
Protected assets excluded: .env, governed stores, .git, patch backups, HOME Bob/Qiskit state
Restore with:
  $PATCH_FILE_NAME --target "$BQCA_ROOT" --rollback "$BACKUP_DIR"
MANIFEST
}

restore_backup() {
  local backup="$1" backup_abs source rel destination
  backup_abs="$(cd "$backup" 2>/dev/null && pwd -P || true)"
  [[ -n "$backup_abs" ]] || fail "Rollback directory not found: $backup"
  [[ -f "$backup_abs/BQCA-v51.4-backup-manifest.txt" ]] || fail "Not a BQCA v51.4 backup: $backup_abs"

  info "Restoring v51.4 backup: $backup_abs"
  while IFS= read -r -d '' source; do
    rel="${source#$backup_abs/}"
    case "$rel" in
      BQCA-v51.4-backup-manifest.txt|created-files.txt) continue ;;
    esac
    destination="$BQCA_ROOT/$rel"
    mkdir -p "$(dirname "$destination")"
    cp -a "$source" "$destination"
  done < <(find "$backup_abs" -mindepth 1 -type f -print0)

  if [[ -f "$backup_abs/created-files.txt" ]]; then
    while IFS= read -r rel; do
      [[ -n "$rel" ]] || continue
      [[ ! -e "$backup_abs/$rel" ]] || continue
      rm -f "$BQCA_ROOT/$rel"
      rmdir --ignore-fail-on-non-empty "$(dirname "$BQCA_ROOT/$rel")" 2>/dev/null || true
    done < "$backup_abs/created-files.txt"
  fi

  info "Rollback complete. Protected assets were not touched."
}

if [[ -n "$ROLLBACK_DIR" ]]; then
  restore_backup "$ROLLBACK_DIR"
  exit 0
fi

info "Resolved BQCA root: $BQCA_ROOT"
info "Patch identity: $PATCH_ID"
info "Auto-approval scope: trusted BQCA interactive and resumed chat sessions"
info "Protected assets: .env, governed stores, HOME Bob/Qiskit state"

if ((DRY_RUN)); then
  cat <<DRY
[BQCA v51.4][DRY-RUN] Planned changes:
  1. Install a Bob-version-aware chat auto-approval capability helper.
  2. Make Bob Shell 2.x chat/resume use --trust --auto-approve.
  3. Make Bob Shell 1.x chat/resume use full approval when advertised:
       --auto-approve first, otherwise --yolo.
  4. Keep Bob run/non-interactive execution behavior unchanged.
  5. Add a trusted-chat auto-approval safety rule without changing the active v48 policy.
  6. Broadcast the rule to every custom mode, rule, skill, and supported tool.
  7. Update .env.example; the private .env remains unchanged.
  8. Update the active-policy registry hash and v51.4 metadata.
  9. Validate both Bob 1.x and Bob 2.x flag selection with isolated mock CLIs.
DRY
  exit 0
fi

write_helper() {
  track_created "$HELPER_SH"
  cat > "$HELPER_SH" <<'SH'
#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BQCA_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"

# BQCA-BOB-SHELL-V2-DNA:BEGIN
# This trusted BQCA runtime tool is bound to AGENTS.md, the active central policy,
# current modes/rules/skills/tools, and the governed BQCA project root.
# BQCA-BOB-SHELL-V2-DNA:END
# BQCA-ACTIVE-CENTRAL-POLICY:BEGIN
# Resolve and preserve the active central policy. This helper selects only the
# supported Bob Shell chat auto-approval flag and does not alter quantum policy.
# BQCA-ACTIVE-CENTRAL-POLICY:END
# BQCA-TRUSTED-CHAT-AUTO-APPROVAL-v51.4:BEGIN
# Full chat auto-approval is permitted only for BQCA interactive/resume sessions
# launched from this structurally validated project root. Protected assets and
# destructive actions remain outside this authorization.
# BQCA-TRUSTED-CHAT-AUTO-APPROVAL-v51.4:END

usage() {
  cat <<'USAGE'
BQCA chat auto-approval capability helper

Usage:
  bqca-chat-auto-approval.sh flag --major <1|2> [--bob-bin <path>]
  bqca-chat-auto-approval.sh trust-flag --major <1|2> [--bob-bin <path>]
  bqca-chat-auto-approval.sh check --major <1|2> [--bob-bin <path>]
  bqca-chat-auto-approval.sh report [--bob-bin <path>]
USAGE
}

command_name="${1:-}"
[[ -n "$command_name" ]] || { usage; exit 2; }
shift || true
major=""
bob_bin="${BOB_BIN:-bob}"
while (($#)); do
  case "$1" in
    --major) (($# >= 2)) || { echo '--major requires a value' >&2; exit 2; }; major="$2"; shift 2 ;;
    --bob-bin) (($# >= 2)) || { echo '--bob-bin requires a value' >&2; exit 2; }; bob_bin="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

[[ -f "$BQCA_ROOT/.bob/custom_modes.yaml" && -f "$BQCA_ROOT/xLaunchpad.sh" ]] || {
  echo '[BQCA][ERROR] Chat auto-approval helper is not running from a valid BQCA root.' >&2
  exit 3
}
command -v "$bob_bin" >/dev/null 2>&1 || {
  echo "[BQCA][ERROR] Bob executable not found: $bob_bin" >&2
  exit 3
}

enabled="${BQCA_CHAT_AUTO_APPROVE:-1}"
case "$enabled" in 1|true|TRUE|on|ON|yes|YES) enabled=1 ;; *) enabled=0 ;; esac

help_text() {
  case "$1" in
    1) "$bob_bin" --help 2>&1 || true ;;
    2) "$bob_bin" chat --help 2>&1 || true ;;
    *) return 2 ;;
  esac
}

full_flag() {
  local requested_major="$1" help
  [[ "$enabled" -eq 1 ]] || return 0
  help="$(help_text "$requested_major")"
  case "$requested_major" in
    2)
      grep -q -- '--auto-approve' <<<"$help" || {
        echo '[BQCA][ERROR] Bob Shell 2.x chat does not advertise --auto-approve.' >&2
        return 4
      }
      printf '%s\n' '--auto-approve'
      ;;
    1)
      if grep -q -- '--auto-approve' <<<"$help"; then
        printf '%s\n' '--auto-approve'
      elif grep -q -- '--yolo' <<<"$help"; then
        printf '%s\n' '--yolo'
      else
        echo '[BQCA][ERROR] Bob Shell 1.x does not advertise full chat auto-approval (--auto-approve or --yolo).' >&2
        return 4
      fi
      ;;
    *) echo "Unsupported Bob major version: $requested_major" >&2; return 2 ;;
  esac
}

trust_flag() {
  local requested_major="$1" help
  help="$(help_text "$requested_major")"
  if grep -q -- '--trust' <<<"$help"; then
    printf '%s\n' '--trust'
  fi
}

case "$command_name" in
  flag)
    [[ "$major" =~ ^[12]$ ]] || { echo 'flag requires --major 1 or 2' >&2; exit 2; }
    full_flag "$major"
    ;;
  trust-flag)
    [[ "$major" =~ ^[12]$ ]] || { echo 'trust-flag requires --major 1 or 2' >&2; exit 2; }
    trust_flag "$major"
    ;;
  check)
    [[ "$major" =~ ^[12]$ ]] || { echo 'check requires --major 1 or 2' >&2; exit 2; }
    if [[ "$enabled" -eq 1 ]]; then
      full_flag "$major" >/dev/null
      if [[ "$major" -eq 2 ]]; then
        [[ "$(trust_flag 2)" == '--trust' ]] || {
          echo '[BQCA][ERROR] Bob Shell 2.x chat does not advertise --trust; trusted auto-approval cannot be enforced.' >&2
          exit 5
        }
      fi
    fi
    printf 'BQCA_CHAT_AUTO_APPROVAL=PASS major=%s enabled=%s\n' "$major" "$enabled"
    ;;
  report)
    version="$($bob_bin --version 2>&1 | head -n 1 || true)"
    printf '%s\n' '========================================================================================'
    printf '%s\n' 'BQCA TRUSTED CHAT AUTO-APPROVAL CAPABILITY REPORT'
    printf '%s\n' '========================================================================================'
    printf 'BQCA root              : %s\n' "$BQCA_ROOT"
    printf 'Bob executable         : %s\n' "$bob_bin"
    printf 'Bob version output     : %s\n' "$version"
    printf 'Production enabled     : %s\n' "$enabled"
    for m in 1 2; do
      flag="$(full_flag "$m" 2>/dev/null || true)"
      trust="$(trust_flag "$m" 2>/dev/null || true)"
      printf 'Bob %s.x approval flag : %s\n' "$m" "${flag:-UNAVAILABLE}"
      printf 'Bob %s.x trust flag    : %s\n' "$m" "${trust:-NOT ADVERTISED}"
    done
    printf '%s\n' '----------------------------------------------------------------------------------------'
    printf '%s\n' 'Scope: BQCA menu option 1 and option 5 chat sessions only.'
    printf '%s\n' 'Protected assets and destructive actions remain governed by BQCA safety rules.'
    printf '%s\n' '========================================================================================'
    ;;
  *) usage; exit 2 ;;
esac
SH
  chmod 755 "$HELPER_SH"
}

write_doctor() {
  track_created "$DOCTOR_SH"
  cat > "$DOCTOR_SH" <<'SH'
#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BQCA_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
MARKER="BQCA-TRUSTED-CHAT-AUTO-APPROVAL-v51.4"
quiet=0
command_name="${1:-check}"
shift || true
while (($#)); do
  case "$1" in --quiet) quiet=1; shift ;; *) echo "Unknown option: $1" >&2; exit 2 ;; esac
done
issues=()
add_issue() { issues+=("$*"); }

# BQCA-BOB-SHELL-V2-DNA:BEGIN
# BQCA Bob 2.x project-DNA assurance component.
# BQCA-BOB-SHELL-V2-DNA:END
# BQCA-ACTIVE-CENTRAL-POLICY:BEGIN
# Dynamically validates the active central-policy integration.
# BQCA-ACTIVE-CENTRAL-POLICY:END
# BQCA-TRUSTED-CHAT-AUTO-APPROVAL-v51.4:BEGIN
# Validates trusted BQCA chat auto-approval coverage without changing runtime state.
# BQCA-TRUSTED-CHAT-AUTO-APPROVAL-v51.4:END

stable="$BQCA_ROOT/.bob/BQCA-PRODUCTION-POLICY.md"
registry="$BQCA_ROOT/.bob/BQCA-ACTIVE-POLICY-REGISTRY.json"
custom="$BQCA_ROOT/.bob/custom_modes.yaml"
helper="$BQCA_ROOT/.bob/quantum-tools/bqca-chat-auto-approval.sh"
env_example="$BQCA_ROOT/.env.example"
bob1="$BQCA_ROOT/bob-quantum-v1x.sh"
bob2="$(find "$BQCA_ROOT" -maxdepth 1 -type f -name 'bob-quantum-v2*.sh' -print | sort -V | tail -n 1)"

[[ -x "$helper" ]] || add_issue "missing executable helper: $helper"
[[ -f "$stable" ]] || add_issue "missing active policy"
[[ -f "$registry" ]] || add_issue "missing policy registry"
[[ -f "$custom" ]] || add_issue "missing custom_modes.yaml"
[[ -f "$bob2" ]] || add_issue "missing Bob 2.x launcher"

auto_rule="$BQCA_ROOT/.bob/rules/01-bqca-trusted-chat-auto-approval.md"
[[ -f "$auto_rule" ]] || add_issue "missing trusted chat auto-approval rule"
if [[ -f "$auto_rule" ]]; then
  [[ "$(grep -c "$MARKER:BEGIN" "$auto_rule" || true)" -eq 1 ]] || add_issue "trusted chat auto-approval rule marker count is not 1"
fi
if [[ -f "$custom" ]]; then
  expected="$(grep -c '^[[:space:]]*customInstructions:' "$custom" || true)"
  actual="$(grep -c "$MARKER:BEGIN" "$custom" || true)"
  [[ "$actual" -eq "$expected" ]] || add_issue "custom-mode coverage is $actual/$expected"
fi
if [[ -f "$bob2" ]]; then
  grep -Fq 'BQCA_CHAT_AUTO_APPROVE="${BQCA_CHAT_AUTO_APPROVE:-1}"' "$bob2" || add_issue "Bob 2.x launcher does not default trusted chat auto-approval on"
  grep -Fq 'bob2_args+=(--auto-approve)' "$bob2" || add_issue "Bob 2.x chat does not add --auto-approve"
  grep -Fq 'local -a bob2_args=(chat --trust)' "$bob2" || add_issue "Bob 2.x chat does not enforce --trust"
fi
if [[ -f "$bob1" ]]; then
  grep -Fq 'BQCA_BOB1_CHAT_APPROVAL_FLAGS' "$bob1" || add_issue "Bob 1.x launcher has no full chat approval flags"
fi
if [[ -f "$env_example" ]]; then
  grep -Eq '^BQCA_CHAT_AUTO_APPROVE=1$' "$env_example" || add_issue ".env.example does not enable BQCA_CHAT_AUTO_APPROVE"
fi

rule_files=0; rule_ok=0
while IFS= read -r -d '' f; do
  rule_files=$((rule_files+1)); grep -q "$MARKER:BEGIN" "$f" && rule_ok=$((rule_ok+1))
done < <(find "$BQCA_ROOT/.bob" -maxdepth 2 -type f -path '*/rules*/*.md' -print0)
skill_files=0; skill_ok=0
while IFS= read -r -d '' f; do
  skill_files=$((skill_files+1)); grep -q "$MARKER:BEGIN" "$f" && skill_ok=$((skill_ok+1))
done < <(find "$BQCA_ROOT/.bob/skills" -type f \( -name 'SKILL.md' -o -name 'README-custom-skills.md' \) -print0)
tool_files=0; tool_ok=0
while IFS= read -r -d '' f; do
  tool_files=$((tool_files+1)); grep -q "$MARKER:BEGIN" "$f" && tool_ok=$((tool_ok+1))
done < <(find "$BQCA_ROOT/.bob/quantum-tools" -maxdepth 1 -type f \( -name '*.sh' -o -name '*.py' -o -name '*.md' -o -name '*.txt' -o -name '*.yaml' -o -name '*.yml' \) -print0)
[[ "$rule_ok" -eq "$rule_files" ]] || add_issue "rule coverage is $rule_ok/$rule_files"
[[ "$skill_ok" -eq "$skill_files" ]] || add_issue "skill coverage is $skill_ok/$skill_files"
[[ "$tool_ok" -eq "$tool_files" ]] || add_issue "tool coverage is $tool_ok/$tool_files"

status=PASS
((${#issues[@]} == 0)) || status=FAIL
if [[ "$quiet" -eq 0 || "$status" == FAIL || "$command_name" == report ]]; then
  printf '%s\n' '========================================================================================'
  printf '%s\n' 'BQCA v51.4 TRUSTED CHAT AUTO-APPROVAL ASSURANCE REPORT'
  printf '%s\n' '========================================================================================'
  printf 'Custom modes           : %s\n' "${actual:-0}/${expected:-0}"
  printf 'Rules / Skills / Tools : %s/%s / %s/%s / %s/%s\n' "$rule_ok" "$rule_files" "$skill_ok" "$skill_files" "$tool_ok" "$tool_files"
  printf 'Issues                 : %s\n' "${#issues[@]}"
  if ((${#issues[@]})); then
    printf '%s\n' '----------------------------------------------------------------------------------------'
    for issue in "${issues[@]}"; do printf -- '- %s\n' "$issue"; done
  fi
  printf '%s\n' '----------------------------------------------------------------------------------------'
  printf 'FINAL AUTO-APPROVAL STATUS : %s\n' "$status"
  printf 'BQCA_CHAT_AUTO_APPROVAL_ASSURANCE=%s\n' "$status"
  printf '%s\n' '========================================================================================'
fi
[[ "$status" == PASS ]]
SH
  chmod 755 "$DOCTOR_SH"
}

patch_v1_launcher() {
  [[ -n "$BOB1_LAUNCHER" && -f "$BOB1_LAUNCHER" ]] || { info "Bob 1.x launcher not present; skipping Bob 1.x source patch."; return 0; }
  python3 - "$BOB1_LAUNCHER" <<'PY'
import pathlib, re, sys
path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding='utf-8')
marker = 'BQCA-TRUSTED-CHAT-AUTO-APPROVAL-v51.4'
text = re.sub(rf'(?ms)^# {re.escape(marker)}:BEGIN\n.*?^# {re.escape(marker)}:END\n?', '', text)
block = r'''# BQCA-TRUSTED-CHAT-AUTO-APPROVAL-v51.4:BEGIN
# Production default: BQCA menu option 1 and option 5 run as full auto-approved
# chat sessions. Bob 1.x uses --auto-approve when advertised, otherwise --yolo.
# This applies only inside the structurally validated BQCA workspace.
BQCA_CHAT_AUTO_APPROVE="${BQCA_CHAT_AUTO_APPROVE:-1}"
BQCA_CHAT_AUTO_APPROVAL_TOOL="${SCRIPT_DIR}/.bob/quantum-tools/bqca-chat-auto-approval.sh"
declare -a BQCA_BOB1_CHAT_APPROVAL_FLAGS=()

bqca_bob1_refresh_chat_auto_approval_v514() {
  local full_flag trust_flag
  BQCA_BOB1_CHAT_APPROVAL_FLAGS=()
  case "${BQCA_CHAT_AUTO_APPROVE}" in 1|true|TRUE|on|ON|yes|YES) ;; *) return 0 ;; esac
  [[ -x "${BQCA_CHAT_AUTO_APPROVAL_TOOL}" ]] || {
    printf '[BQCA][ERROR] Missing trusted chat auto-approval tool: %s\n' "${BQCA_CHAT_AUTO_APPROVAL_TOOL}" >&2
    return 1
  }
  full_flag="$("${BQCA_CHAT_AUTO_APPROVAL_TOOL}" flag --major 1 --bob-bin "${BOB_BIN}")" || return 1
  [[ -n "${full_flag}" ]] && BQCA_BOB1_CHAT_APPROVAL_FLAGS+=("${full_flag}")
  trust_flag="$("${BQCA_CHAT_AUTO_APPROVAL_TOOL}" trust-flag --major 1 --bob-bin "${BOB_BIN}")" || return 1
  [[ -n "${trust_flag}" ]] && BQCA_BOB1_CHAT_APPROVAL_FLAGS+=("${trust_flag}")
}

bqca_bob1_refresh_chat_auto_approval_v514
export BQCA_CHAT_AUTO_APPROVE
# BQCA-TRUSTED-CHAT-AUTO-APPROVAL-v51.4:END
'''
needle = 'INITIAL_PROMPT="${*:-What quantum computing code should I write?}"\n'
if needle not in text:
    raise SystemExit('Unable to locate Bob 1.x BOB_BIN/INITIAL_PROMPT boundary')
text = text.replace(needle, needle + '\n' + block + '\n', 1)

# Option 1: use full chat approval flags instead of the granular auto-edit array.
interactive_pattern = re.compile(r'(?ms)quantum_interactive\(\) \{.*?\n    \}')
match = interactive_pattern.search(text)
if not match:
    raise SystemExit('Unable to locate Bob 1.x quantum_interactive function')
interactive = match.group(0)
if '"${BQCA_BOB1_CHAT_APPROVAL_FLAGS[@]}"' not in interactive:
    if '"${BOB_QUANTUM_TOOL_FLAGS[@]}"' not in interactive:
        raise SystemExit('Unable to locate Bob 1.x interactive tool flags')
    interactive = interactive.replace('"${BOB_QUANTUM_TOOL_FLAGS[@]}"', '"${BQCA_BOB1_CHAT_APPROVAL_FLAGS[@]}"', 1)
text = text[:match.start()] + interactive + text[match.end():]

# Option 5: add the same full chat approval flags to resume.
resume_pattern = re.compile(r'(?ms)quantum_resume\(\) \{.*?\n    \}')
match = resume_pattern.search(text)
if not match:
    raise SystemExit('Unable to locate Bob 1.x quantum_resume function')
resume = match.group(0)
if '"${BQCA_BOB1_CHAT_APPROVAL_FLAGS[@]}"' not in resume:
    needle_resume = '        --hide-intermediary-output'
    if needle_resume not in resume:
        raise SystemExit('Unable to locate Bob 1.x resume output flag')
    resume = resume.replace(needle_resume, '        "${BQCA_BOB1_CHAT_APPROVAL_FLAGS[@]}" \\\n' + needle_resume, 1)
text = text[:match.start()] + resume + text[match.end():]
path.write_text(text, encoding='utf-8')
PY
  chmod 755 "$BOB1_LAUNCHER"
}

patch_v2_launcher() {
  python3 - "$BOB2_LAUNCHER" <<'PY'
import pathlib, re, sys
path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding='utf-8')
marker = 'BQCA-TRUSTED-CHAT-AUTO-APPROVAL-v51.4'
text = re.sub(rf'(?ms)^# {re.escape(marker)}:BEGIN\n.*?^# {re.escape(marker)}:END\n?', '', text)
# Remove the old single-variable default so v51.4 is the sole default authority.
text = re.sub(r'^BQCA_BOB2_AUTO_APPROVE="\$\{BQCA_BOB2_AUTO_APPROVE:-[^}]*\}"\n', '', text, flags=re.M)
block = r'''# BQCA-TRUSTED-CHAT-AUTO-APPROVAL-v51.4:BEGIN
# Production default: all BQCA Bob Shell 2.x interactive and resumed chat
# sessions use --trust --auto-approve. Non-interactive bob run behavior is not
# changed by this patch.
BQCA_CHAT_AUTO_APPROVE="${BQCA_CHAT_AUTO_APPROVE:-1}"
BQCA_BOB2_AUTO_APPROVE="${BQCA_CHAT_AUTO_APPROVE}"
BQCA_CHAT_AUTO_APPROVAL_TOOL="${SCRIPT_DIR}/.bob/quantum-tools/bqca-chat-auto-approval.sh"
export BQCA_CHAT_AUTO_APPROVE BQCA_BOB2_AUTO_APPROVE BQCA_CHAT_AUTO_APPROVAL_TOOL
# BQCA-TRUSTED-CHAT-AUTO-APPROVAL-v51.4:END
'''
needle = 'BQCA_BOB2_LOG_LEVEL="${BQCA_BOB2_LOG_LEVEL:-warn}"\n'
if needle not in text:
    raise SystemExit('Unable to locate Bob 2.x settings boundary')
text = text.replace(needle, needle + block, 1)
# Avoid duplicate export entry if BQCA_BOB2_AUTO_APPROVE already appears later.
# The value remains exported by the v51.4 block.

old = '''  if [[ "${BQCA_BOB2_AUTO_APPROVE}" == "1" ]]; then
    bob2_args+=(--auto-approve)
  fi
'''
new = '''  if [[ "${BQCA_BOB2_AUTO_APPROVE}" == "1" ]]; then
    [[ -x "${BQCA_CHAT_AUTO_APPROVAL_TOOL}" ]] || {
      printf '[BQCA][ERROR] Missing trusted chat auto-approval tool: %s\\n' "${BQCA_CHAT_AUTO_APPROVAL_TOOL}" >&2
      return 1
    }
    "${BQCA_CHAT_AUTO_APPROVAL_TOOL}" check --major 2 --bob-bin "${BOB_BIN}" >/dev/null || return 1
    bob2_args+=(--auto-approve)
  fi
'''
if '"${BQCA_CHAT_AUTO_APPROVAL_TOOL}" check --major 2 --bob-bin "${BOB_BIN}"' not in text:
    if old not in text:
        raise SystemExit('Unable to locate Bob 2.x chat auto-approval block')
    text = text.replace(old, new, 1)
if 'local -a bob2_args=(chat --trust)' not in text:
    raise SystemExit('Bob 2.x chat does not enforce --trust')
path.write_text(text, encoding='utf-8')
PY
  chmod 755 "$BOB2_LAUNCHER"
}

write_auto_rule() {
  track_created "$AUTO_RULE"
  mkdir -p "$(dirname "$AUTO_RULE")"
  cat > "$AUTO_RULE" <<'RULE'
# BQCA Trusted Interactive Chat Auto-Approval Rule

<!-- BQCA-BOB-SHELL-V2-DNA:BEGIN -->
This is a cross-mode BQCA project rule. It supplements all current mode-specific rules without replacing their quantum intelligence.
<!-- BQCA-BOB-SHELL-V2-DNA:END -->
<!-- BQCA-ACTIVE-CENTRAL-POLICY:BEGIN -->
The active central BQCA production policy remains authoritative. This rule governs only session-level tool approval behavior.
<!-- BQCA-ACTIVE-CENTRAL-POLICY:END -->
<!-- BQCA-TRUSTED-CHAT-AUTO-APPROVAL-v51.4:BEGIN -->
## Production rule

BQCA interactive and resumed chat sessions launched through the trusted BQCA appliance must use the full auto-approval capability supported by the installed Bob Shell:

- Bob Shell 2.x uses `bob chat --trust --auto-approve`.
- Bob Shell 1.x uses `--auto-approve` when advertised; otherwise it uses the documented full-approval `--yolo` capability.
- Auto-approval is a session launch property. It remains active when Bob changes between BQCA custom modes during the same task.
- Do not ask the user to approve routine BQCA skill activation, project-scoped file operations, active-policy checks, validator calls, governed directory creation, or ordinary project-scoped commands.

## Mandatory safety boundary

Auto-approval improves workflow speed but is not authorization to bypass BQCA security or governance. Even in an auto-approved session:

1. Never disclose, edit, copy, or commit `.env`, API keys, tokens, private keys, or credentials.
2. Never write to Bob-managed settings or `$HOME/.bob` merely because auto-approval is active. Bob may still require explicit approval for protected settings and home-directory writes.
3. Never modify `$HOME/.qiskit/qiskit-ibm.json` except through the approved BQCA configuration gate.
4. Never modify files outside the trusted BQCA workspace unless the user explicitly requests it and the active policy permits it.
5. Never run destructive system commands, privilege escalation, filesystem formatting, uncontrolled recursive deletion, destructive Git cleanup/reset, or host package installation without explicit user instruction and the applicable BQCA safety gate.
6. Do not weaken validators, compliance reports, notebook synchronization, real-QPU-first rules, result-output governance, or secret scanning.
7. When a requested action falls outside this trusted, project-scoped boundary, stop and request explicit user confirmation rather than relying on session auto-approval.

Bob Shell may retain non-bypassable approval prompts for protected settings, Bob home writes, subagent spawning, or other product-defined high-risk operations. Those product controls are not to be circumvented.
<!-- BQCA-TRUSTED-CHAT-AUTO-APPROVAL-v51.4:END -->
RULE
  chmod 644 "$AUTO_RULE"
}

verify_active_policy_unchanged() {
  cmp -s "$POLICY_STABLE" "$VERSIONED_POLICY" || fail "Stable and versioned active policies differ"
  local stable_hash versioned_hash
  stable_hash="$(sha256sum "$POLICY_STABLE" | awk '{print $1}')"
  versioned_hash="$(sha256sum "$VERSIONED_POLICY" | awk '{print $1}')"
  [[ "$stable_hash" == "$versioned_hash" ]] || fail "Active policy hashes differ"
}

patch_registry() {
  python3 - "$BQCA_ROOT" "$REGISTRY" "$POLICY_STABLE" <<'PY'
import datetime, hashlib, json, pathlib, sys
root = pathlib.Path(sys.argv[1])
path = pathlib.Path(sys.argv[2])
policy = pathlib.Path(sys.argv[3])
data = json.loads(path.read_text(encoding='utf-8'))
digest = hashlib.sha256(policy.read_bytes()).hexdigest()
data['policy_sha256'] = digest
data['canonical_policy_sha256'] = digest
if isinstance(data.get('active_authority'), dict):
    data['active_authority']['policy_sha256'] = digest
data['chat_auto_approval'] = {
    'patch': 'BQCA-v51.4',
    'enabled_by_default': True,
    'environment_variable': 'BQCA_CHAT_AUTO_APPROVE',
    'scope': ['interactive-chat', 'resume-chat'],
    'trusted_workspace_only': True,
    'bob_2x': {'command': 'bob chat', 'flags': ['--trust', '--auto-approve']},
    'bob_1x': {'full_flag_preference': ['--auto-approve', '--yolo'], 'capability_detected': True},
    'non_interactive_run_changed': False,
    'rule_path': '.bob/rules/01-bqca-trusted-chat-auto-approval.md',
    'helper_path': '.bob/quantum-tools/bqca-chat-auto-approval.sh',
    'doctor_path': '.bob/quantum-tools/bqca-chat-auto-approval-doctor.sh',
    'protected_operations_remain_blocking': True,
}
data['updated_utc'] = datetime.datetime.now(datetime.timezone.utc).isoformat().replace('+00:00', 'Z')
path.write_text(json.dumps(data, indent=2, sort_keys=True) + '\n', encoding='utf-8')
PY
  chmod 644 "$REGISTRY"
}

patch_env_example() {
  [[ -f "$ENV_EXAMPLE" ]] || return 0
  python3 - "$ENV_EXAMPLE" <<'PY'
import pathlib, re, sys
path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding='utf-8')
text = re.sub(r'(?m)^BQCA_CHAT_AUTO_APPROVE=.*\n?', '', text)
text = re.sub(r'(?m)^BQCA_BOB2_AUTO_APPROVE=.*\n?', '', text)
block = '''
# =============================================================================
# BQCA trusted interactive chat auto-approval
# Applies to menu option 1 and option 5 in the trusted BQCA workspace.
# Set to 0 only for an explicit emergency/manual-approval session.
# =============================================================================
BQCA_CHAT_AUTO_APPROVE=1
# Legacy compatibility alias; the launcher derives this from the canonical value.
BQCA_BOB2_AUTO_APPROVE=1
'''
anchor = 'BQCA_BOB2_LOG_LEVEL='
lines = text.splitlines(keepends=True)
out=[]; inserted=False
for line in lines:
    out.append(line)
    if not inserted and line.startswith(anchor):
        out.append(block)
        inserted=True
if not inserted:
    out.append(block)
path.write_text(''.join(out).rstrip() + '\n', encoding='utf-8')
PY
  chmod 644 "$ENV_EXAMPLE"
}

patch_docs() {
  python3 - "$AGENTS_FILE" "$README_FILE" <<'PY'
import pathlib, re, sys
marker = 'BQCA-TRUSTED-CHAT-AUTO-APPROVAL-v51.4'
block = '''
<!-- BQCA-TRUSTED-CHAT-AUTO-APPROVAL-v51.4:BEGIN -->
## Trusted BQCA chat auto-approval

BQCA menu option 1 and option 5 launch trusted interactive chat sessions with full session-level auto-approval. Bob Shell 2.x uses `--trust --auto-approve`; Bob Shell 1.x uses the full capability advertised by the installed CLI (`--auto-approve` or `--yolo`). This prevents routine skill, file, and command approval prompts from interrupting the BQCA workflow.

Auto-approval is confined to the trusted BQCA project and does not authorize credential access, destructive system actions, Bob settings/home writes, unapproved external paths, or bypass of BQCA validators and policy gates.
<!-- BQCA-TRUSTED-CHAT-AUTO-APPROVAL-v51.4:END -->
'''
for name in sys.argv[1:]:
    path = pathlib.Path(name)
    if not path.exists():
        continue
    text = path.read_text(encoding='utf-8')
    text = re.sub(rf'\n?<!-- {re.escape(marker)}:BEGIN -->.*?<!-- {re.escape(marker)}:END -->\n?', '\n', text, flags=re.S)
    path.write_text(text.rstrip() + '\n' + block, encoding='utf-8')
PY
  [[ -f "$AGENTS_FILE" ]] && chmod 644 "$AGENTS_FILE"
  [[ -f "$README_FILE" ]] && chmod 644 "$README_FILE"
}

patch_custom_modes() {
  python3 - "$CUSTOM_MODES" <<'PY'
import pathlib, re, sys
path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding='utf-8')
marker = 'BQCA-TRUSTED-CHAT-AUTO-APPROVAL-v51.4'
text = re.sub(rf'(?ms)^([ \t]*)# {re.escape(marker)}:BEGIN\n.*?^\1# {re.escape(marker)}:END\n?', '', text)
lines = text.splitlines()
result=[]; count=0
pattern = re.compile(r'^(?P<indent>[ \t]*)customInstructions:\s*[>|][+-]?\s*(?:#.*)?$')
for line in lines:
    result.append(line)
    m=pattern.match(line)
    if not m:
        continue
    indent=m.group('indent')+'  '
    result.extend([
        f'{indent}# {marker}:BEGIN',
        f'{indent}TRUSTED CHAT AUTO-APPROVAL: For BQCA interactive and resumed chat sessions, the launcher enforces the installed Bob Shell full auto-approval capability in the trusted project. Do not request routine skill, file, or command approvals. Auto-approval does not permit credential access, destructive commands, Bob home/settings changes, external-path writes, or bypass of the active policy, validators, notebook synchronization, result governance, and secret protection.',
        f'{indent}# {marker}:END',
    ])
    count += 1
if count == 0:
    raise SystemExit('No customInstructions block scalars found in custom_modes.yaml')
path.write_text('\n'.join(result)+'\n', encoding='utf-8')
print(count)
PY
  chmod 644 "$CUSTOM_MODES"
}

patch_awareness_files() {
  python3 - "$BOB_ROOT" "$SKILLS_DIR" "$TOOLS_DIR" <<'PY'
import pathlib, re, sys
bob_root=pathlib.Path(sys.argv[1]); skills=pathlib.Path(sys.argv[2]); tools=pathlib.Path(sys.argv[3])
marker='BQCA-TRUSTED-CHAT-AUTO-APPROVAL-v51.4'
files=[]
files.extend(p for p in bob_root.glob('rules*/*.md') if p.is_file())
files.extend(p for p in skills.rglob('*') if p.is_file() and (p.name=='SKILL.md' or p.name=='README-custom-skills.md'))
files.extend(p for p in tools.iterdir() if p.is_file() and p.suffix.lower() in {'.sh','.py','.md','.txt','.yaml','.yml'})
md_block=f'''\n<!-- {marker}:BEGIN -->\n## Trusted BQCA chat auto-approval\n\nRoutine tool approvals in BQCA interactive/resume chat sessions are handled by the trusted session launch flags. Do not ask the user to approve ordinary project-scoped skills, reads, writes, directory creation, validators, or commands. This speed optimization never authorizes credential access, destructive operations, Bob home/settings changes, external-path writes, or bypass of active BQCA policy and safety gates.\n<!-- {marker}:END -->\n'''
comment_block=f'''\n# {marker}:BEGIN\n# Trusted BQCA chat sessions auto-approve routine project-scoped tool calls at\n# session launch. This does not authorize secrets, destructive operations, Bob\n# home/settings writes, external paths, or bypass of BQCA policy/safety gates.\n# {marker}:END\n'''
for path in sorted(set(files)):
    text=path.read_text(encoding='utf-8')
    if path.suffix.lower()=='.md':
        text=re.sub(rf'\n?<!-- {re.escape(marker)}:BEGIN -->.*?<!-- {re.escape(marker)}:END -->\n?', '\n', text, flags=re.S)
        text=text.rstrip()+md_block
    else:
        text=re.sub(rf'(?ms)^# {re.escape(marker)}:BEGIN\n.*?^# {re.escape(marker)}:END\n?', '', text)
        text=text.rstrip()+comment_block
    path.write_text(text, encoding='utf-8')
print(f'awareness_files={len(set(files))}')
PY
}

write_patch_record() {
  mkdir -p "$PATCH_RECORD_DIR"
  cat > "$PATCH_RECORD_FILE" <<RECORD
Patch: $PATCH_ID
Applied: $(date -u '+%Y-%m-%dT%H:%M:%SZ')
Root: $BQCA_ROOT
Backup: $BACKUP_DIR
Active policy: $(python3 - "$REGISTRY" <<'PY'
import json, pathlib, sys
print(json.loads(pathlib.Path(sys.argv[1]).read_text()).get('active_version','unknown'))
PY
)
Production behavior:
  - Bob 2.x chat/resume uses --trust --auto-approve.
  - Bob 1.x chat/resume uses --auto-approve when advertised, otherwise --yolo.
  - Non-interactive run behavior is unchanged.
  - Auto-approval is confined by the BQCA trusted-workspace safety rule.
Protected assets: .env, governed stores, HOME Bob/Qiskit state excluded and unchanged.
RECORD
  chmod 644 "$PATCH_RECORD_FILE"
}

validate_installation() {
  local failures=0 expected_modes actual_modes rule_files rule_hits skill_files skill_hits tool_files tool_hits

  for file in "$HELPER_SH" "$DOCTOR_SH" "$BOB2_LAUNCHER" "$XLAUNCHPAD"; do
    [[ -e "$file" ]] || { warn "Missing required file: $file"; failures=$((failures+1)); continue; }
    [[ -x "$file" ]] || { warn "Required executable lacks execute permission: $file"; failures=$((failures+1)); }
    bash -n "$file" || failures=$((failures+1))
  done
  if [[ -n "$BOB1_LAUNCHER" && -f "$BOB1_LAUNCHER" ]]; then
    [[ -x "$BOB1_LAUNCHER" ]] || { warn "Bob 1.x launcher lacks execute permission"; failures=$((failures+1)); }
    bash -n "$BOB1_LAUNCHER" || failures=$((failures+1))
  fi

  cmp -s "$POLICY_STABLE" "$VERSIONED_POLICY" || { warn "Stable and versioned active policies differ"; failures=$((failures+1)); }
  [[ -f "$AUTO_RULE" && "$(grep -c "$MARKER:BEGIN" "$AUTO_RULE" || true)" -eq 1 ]] || { warn "Trusted chat auto-approval rule is missing or duplicated"; failures=$((failures+1)); }

  expected_modes="$(grep -c '^[[:space:]]*customInstructions:' "$CUSTOM_MODES" || true)"
  actual_modes="$(grep -c "$MARKER:BEGIN" "$CUSTOM_MODES" || true)"
  [[ "$expected_modes" -gt 0 && "$actual_modes" -eq "$expected_modes" ]] || { warn "Custom-mode awareness is $actual_modes/$expected_modes"; failures=$((failures+1)); }

  rule_files="$(find "$BOB_ROOT" -maxdepth 2 -type f -path '*/rules*/*.md' | wc -l)"
  rule_hits="$(find "$BOB_ROOT" -maxdepth 2 -type f -path '*/rules*/*.md' -exec grep -l "$MARKER:BEGIN" {} + | wc -l)"
  skill_files="$(find "$SKILLS_DIR" -type f \( -name 'SKILL.md' -o -name 'README-custom-skills.md' \) | wc -l)"
  skill_hits="$(find "$SKILLS_DIR" -type f \( -name 'SKILL.md' -o -name 'README-custom-skills.md' \) -exec grep -l "$MARKER:BEGIN" {} + | wc -l)"
  tool_files="$(find "$TOOLS_DIR" -maxdepth 1 -type f \( -name '*.sh' -o -name '*.py' -o -name '*.md' -o -name '*.txt' -o -name '*.yaml' -o -name '*.yml' \) | wc -l)"
  tool_hits="$(find "$TOOLS_DIR" -maxdepth 1 -type f \( -name '*.sh' -o -name '*.py' -o -name '*.md' -o -name '*.txt' -o -name '*.yaml' -o -name '*.yml' \) -exec grep -l "$MARKER:BEGIN" {} + | wc -l)"
  [[ "$rule_hits" -eq "$rule_files" ]] || { warn "Rule awareness is $rule_hits/$rule_files"; failures=$((failures+1)); }
  [[ "$skill_hits" -eq "$skill_files" ]] || { warn "Skill awareness is $skill_hits/$skill_files"; failures=$((failures+1)); }
  [[ "$tool_hits" -eq "$tool_files" ]] || { warn "Tool awareness is $tool_hits/$tool_files"; failures=$((failures+1)); }

  grep -Fq 'BQCA_CHAT_AUTO_APPROVE="${BQCA_CHAT_AUTO_APPROVE:-1}"' "$BOB2_LAUNCHER" || { warn "Bob 2.x launcher does not default auto-approval to enabled"; failures=$((failures+1)); }
  grep -Fq 'local -a bob2_args=(chat --trust)' "$BOB2_LAUNCHER" || { warn "Bob 2.x chat does not use --trust"; failures=$((failures+1)); }
  grep -Fq 'bob2_args+=(--auto-approve)' "$BOB2_LAUNCHER" || { warn "Bob 2.x chat does not use --auto-approve"; failures=$((failures+1)); }
  if [[ -n "$BOB1_LAUNCHER" && -f "$BOB1_LAUNCHER" ]]; then
    grep -Fq 'BQCA_BOB1_CHAT_APPROVAL_FLAGS' "$BOB1_LAUNCHER" || { warn "Bob 1.x chat auto-approval flags missing"; failures=$((failures+1)); }
  fi
  grep -Eq '^BQCA_CHAT_AUTO_APPROVE=1$' "$ENV_EXAMPLE" || { warn ".env.example does not enable BQCA_CHAT_AUTO_APPROVE"; failures=$((failures+1)); }

  # Isolated capability tests. Operator credentials and the real Bob binary are not used.
  local test_root mock1 mock2
  test_root="$(mktemp -d)"
  mock1="$test_root/bob1"
  mock2="$test_root/bob2"
  cat > "$mock1" <<'MOCK'
#!/usr/bin/env bash
if [[ "${1:-}" == "--help" ]]; then
  printf '%s\n' 'Usage: bob [options]' '  --yolo' '  --trust'
  exit 0
fi
printf '%s\n' 'Bob Shell 1.0.6'
MOCK
  cat > "$mock2" <<'MOCK'
#!/usr/bin/env bash
if [[ "${1:-}" == "chat" && "${2:-}" == "--help" ]]; then
  printf '%s\n' 'Usage: bob chat [options]' '  --auto-approve' '  --trust' '  --mode <mode>'
  exit 0
fi
if [[ "${1:-}" == "--version" ]]; then printf '%s\n' '2.0.1'; exit 0; fi
printf '%s\n' 'Bob Shell 2.0.1'
MOCK
  chmod 755 "$mock1" "$mock2"
  [[ "$(BQCA_CHAT_AUTO_APPROVE=1 "$HELPER_SH" flag --major 1 --bob-bin "$mock1")" == '--yolo' ]] || { warn "Bob 1.x mock did not select --yolo"; failures=$((failures+1)); }
  [[ "$(BQCA_CHAT_AUTO_APPROVE=1 "$HELPER_SH" trust-flag --major 1 --bob-bin "$mock1")" == '--trust' ]] || { warn "Bob 1.x mock did not select --trust"; failures=$((failures+1)); }
  [[ "$(BQCA_CHAT_AUTO_APPROVE=1 "$HELPER_SH" flag --major 2 --bob-bin "$mock2")" == '--auto-approve' ]] || { warn "Bob 2.x mock did not select --auto-approve"; failures=$((failures+1)); }
  BQCA_CHAT_AUTO_APPROVE=1 "$HELPER_SH" check --major 2 --bob-bin "$mock2" >/dev/null || { warn "Bob 2.x mock capability check failed"; failures=$((failures+1)); }
  rm -rf "$test_root"

  "$DOCTOR_SH" check --quiet || failures=$((failures+1))

  if ((failures)); then
    fail "v51.4 validation failed with $failures issue(s)."
  fi
  info "Validation passed: trusted chat auto-approval is enforced for Bob 1.x/2.x chat sessions; modes=$actual_modes rules=$rule_hits skills=$skill_hits tools=$tool_hits."
}

if ((VALIDATE_ONLY)); then
  validate_installation
  exit 0
fi

create_backup
mkdir -p "$TOOLS_DIR" "$BOB_ROOT/rules" "$PATCH_RECORD_DIR"
write_helper
write_doctor
patch_v1_launcher
patch_v2_launcher
write_auto_rule
verify_active_policy_unchanged
patch_registry
patch_env_example
patch_docs
patch_custom_modes
patch_awareness_files
# Re-run awareness after helper/doctor creation so both new tools receive the block.
patch_awareness_files
write_patch_record
verify_active_policy_unchanged

# Normalize only files installed or directly edited by this patch.
chmod 755 "$HELPER_SH" "$DOCTOR_SH" "$BOB2_LAUNCHER"
[[ -n "$BOB1_LAUNCHER" && -f "$BOB1_LAUNCHER" ]] && chmod 755 "$BOB1_LAUNCHER"
chmod 644 "$AUTO_RULE" "$POLICY_STABLE" "$VERSIONED_POLICY" "$REGISTRY" "$CUSTOM_MODES"
[[ -f "$ENV_EXAMPLE" ]] && chmod 644 "$ENV_EXAMPLE"

validate_installation
info "Patch $PATCH_ID applied successfully."
info "Backup: $BACKUP_DIR"
info "Capability helper: .bob/quantum-tools/bqca-chat-auto-approval.sh"
info "Assurance doctor: .bob/quantum-tools/bqca-chat-auto-approval-doctor.sh"
info "Private .env and governed workload stores were not touched."
