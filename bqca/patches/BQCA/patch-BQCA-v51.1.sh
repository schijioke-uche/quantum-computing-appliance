#!/usr/bin/env bash
set -Eeuo pipefail

#===============================================================================
# BQCA Bob Shell 2.x Custom-Mode Runtime Bridge Patch v51.1
# File: patch-BQCA-v51.1.sh
# Author: Dr. Jeffrey Chijioke-Uche, IBM Computer Scientist
#
# Purpose:
#   Fix Bob Shell 2.x menu routing after authentication. The Bob 2.x launcher
#   resolves BQCA_BOB2_*_MODE values correctly, but bob-auth.sh is sourced later
#   and re-sources .env. Because the optional mode override variables in .env are
#   intentionally empty, this second source erases the resolved values. Bob is
#   then invoked with --mode "", producing:
#
#       Error: Mode with id "" not found
#
#   This patch makes project .env loading idempotent, refreshes and validates
#   all Bob 2.x mode bindings after authentication, and blocks empty mode calls.
#
# Protected assets:
#   - The installer never reads, copies, backs up, modifies, chmods, removes, or
#     restores the project-root .env file.
#   - Governed design/code stores and HOME-scoped Bob/Qiskit state are untouched.
#===============================================================================

PATCH_ID="BQCA-v51.1"
PATCH_FILE_NAME="patch-BQCA-v51.1.sh"
TIMESTAMP="$(date +%Y%m%d%H%M%S)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
TARGET_OVERRIDE=""
DRY_RUN=0
VALIDATE_ONLY=0
ROLLBACK_DIR=""

info() { printf '[BQCA v51.1][INFO] %s\n' "$*"; }
warn() { printf '[BQCA v51.1][WARN] %s\n' "$*" >&2; }
fail() { printf '[BQCA v51.1][ERROR] %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'USAGE'
BQCA Bob Shell 2.x Custom-Mode Runtime Bridge Patch v51.1

Usage:
  ./patch-BQCA-v51.1.sh [options]

Options:
  --target <path>        Explicit standalone BQCA appliance root.
  --dry-run              Display the patch plan without changing files.
  --validate-only        Validate the installed v51.1 mode bridge.
  --rollback <backup>    Restore a v51.1 timestamped backup directory.
  -h, --help             Show this help.

Expected placement:
  <BQCA-root>/patches/BQCA/patch-BQCA-v51.1.sh
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

for cmd in bash chmod cp date dirname find grep mkdir mktemp mv python3 rm sed sort tail; do
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
CUSTOM_MODES="$BOB_ROOT/custom_modes.yaml"
XLAUNCHPAD="$BQCA_ROOT/xLaunchpad.sh"
BOB_AUTH="$BQCA_ROOT/bob-auth.sh"
PATCH_RECORD_DIR="$BOB_ROOT/patches-applied"
PATCH_RECORD_FILE="$PATCH_RECORD_DIR/${PATCH_ID}.txt"
BACKUP_ROOT="$BOB_ROOT/patch-backups"
BACKUP_DIR="$BACKUP_ROOT/${PATCH_ID}.${TIMESTAMP}"
BACKUP_MANIFEST="$BACKUP_DIR/BQCA-v51.1-backup-manifest.txt"
CREATED_LIST="$BACKUP_DIR/BQCA-v51.1-created-files.txt"
ENV_MARKER="BQCA-PROJECT-ENV-LOAD-GUARD-v51.1"
MODE_MARKER="BQCA-BOB2-MODE-BRIDGE-v51.1"

find_bob2_launcher() {
  local found
  found="$(find "$BQCA_ROOT" -maxdepth 1 -type f -name 'bob-quantum-v2.*.sh' -print | sort -V | tail -n 1)"
  [[ -n "$found" ]] || fail "No Bob Shell 2.x BQCA launcher found in $BQCA_ROOT"
  printf '%s\n' "$found"
}
BOB2_LAUNCHER="$(find_bob2_launcher)"

backup_file() {
  local source="$1" rel destination
  [[ -e "$source" ]] || return 0
  [[ "$source" != "$BQCA_ROOT/.env" ]] || return 0
  rel="${source#$BQCA_ROOT/}"
  destination="$BACKUP_DIR/$rel"
  mkdir -p "$(dirname "$destination")"
  cp -a "$source" "$destination"
}

create_backup() {
  mkdir -p "$BACKUP_DIR"
  : > "$CREATED_LIST"
  [[ -e "$PATCH_RECORD_FILE" ]] || printf '%s\n' "${PATCH_RECORD_FILE#$BQCA_ROOT/}" >> "$CREATED_LIST"
  backup_file "$XLAUNCHPAD"
  backup_file "$BOB_AUTH"
  backup_file "$BOB2_LAUNCHER"
  backup_file "$PATCH_RECORD_FILE"
  cat > "$BACKUP_MANIFEST" <<MANIFEST
Patch: $PATCH_ID
Created: $(date -u '+%Y-%m-%dT%H:%M:%SZ')
Appliance root: $BQCA_ROOT
Bob 2.x launcher: ${BOB2_LAUNCHER#$BQCA_ROOT/}
Protected: .env, bob-quantum-designs, bob-quantum-store, HOME/.bob, HOME/qiskit-v2x-env, HOME/.qiskit/qiskit-ibm.json
Restore with:
  $PATCH_FILE_NAME --target "$BQCA_ROOT" --rollback "$BACKUP_DIR"
MANIFEST
}

restore_backup() {
  local backup="$1" backup_abs source rel destination
  backup_abs="$(cd "$backup" 2>/dev/null && pwd -P || true)"
  [[ -n "$backup_abs" ]] || fail "Rollback directory not found: $backup"
  [[ -f "$backup_abs/BQCA-v51.1-backup-manifest.txt" ]] || fail "Not a BQCA v51.1 backup: $backup_abs"
  info "Restoring v51.1 backup: $backup_abs"
  while IFS= read -r -d '' source; do
    rel="${source#$backup_abs/}"
    case "$rel" in BQCA-v51.1-backup-manifest.txt|BQCA-v51.1-created-files.txt) continue ;; esac
    destination="$BQCA_ROOT/$rel"
    mkdir -p "$(dirname "$destination")"
    cp -a "$source" "$destination"
  done < <(find "$backup_abs" -mindepth 1 -type f -print0)
  if [[ -f "$backup_abs/BQCA-v51.1-created-files.txt" ]]; then
    while IFS= read -r rel; do
      [[ -n "$rel" ]] || continue
      [[ -e "$backup_abs/$rel" ]] || rm -f "$BQCA_ROOT/$rel"
    done < "$backup_abs/BQCA-v51.1-created-files.txt"
  fi
  info "Rollback complete."
}

if [[ -n "$ROLLBACK_DIR" ]]; then
  restore_backup "$ROLLBACK_DIR"
  exit 0
fi

info "Resolved BQCA root: $BQCA_ROOT"
info "Patch identity: $PATCH_ID"
info "Bob 2.x launcher: ${BOB2_LAUNCHER#$BQCA_ROOT/}"
info "Protected assets: .env, governed stores, home Bob state, Qiskit environment, and account JSON"

if ((DRY_RUN)); then
  cat <<'DRY'
[BQCA v51.1][DRY-RUN]
  1. Mark project .env loading as complete in xLaunchpad.sh and the Bob 2.x launcher.
  2. Make bob-auth.sh skip a second .env source when the caller already loaded it.
  3. Refresh and validate interactive/ask/code/advanced mode bindings after authentication.
  4. Block every Bob 2.x run call whose selected mode is empty or unavailable.
  5. Preserve custom_modes.yaml, active policy, BQCA DNA, rules, skills, tools, and knowledgebase.
DRY
  exit 0
fi

patch_project_env_loader() {
  local file="$1"
  python3 - "$file" "$ENV_MARKER" <<'PY'
from __future__ import annotations
import pathlib, re, sys
path = pathlib.Path(sys.argv[1])
marker = sys.argv[2]
text = path.read_text(encoding="utf-8")
block = f'''# {marker}:BEGIN
if [[ "${{BQCA_PROJECT_ENV_LOADED:-0}}" != "1" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "${{SCRIPT_DIR}}/.env"
  set +a
  BQCA_PROJECT_ENV_LOADED=1
  export BQCA_PROJECT_ENV_LOADED
fi
# {marker}:END
'''
existing = re.compile(rf'(?ms)^# {re.escape(marker)}:BEGIN\n.*?^# {re.escape(marker)}:END\n?')
if existing.search(text):
    text = existing.sub(block, text, count=1)
else:
    canonical = re.compile(
        r'(?m)^set -a\n(?:# shellcheck source=/dev/null\n)?source "\$\{SCRIPT_DIR\}/\.env"\nset \+a\n'
    )
    match = canonical.search(text)
    if not match:
        raise SystemExit(f"Unable to locate project .env load block in {path}")
    text = text[:match.start()] + block + text[match.end():]
path.write_text(text, encoding="utf-8")
PY
  chmod 755 "$file"
}

patch_auth_env_loader() {
  python3 - "$BOB_AUTH" "$ENV_MARKER" <<'PY'
from __future__ import annotations
import pathlib, re, sys
path = pathlib.Path(sys.argv[1])
marker = sys.argv[2]
text = path.read_text(encoding="utf-8")
block = f'''# {marker}:BEGIN
# bob-auth.sh is sourced into the launcher shell. Do not re-source .env after
# the launcher has resolved its Bob 2.x mode defaults, because the intentionally
# empty BQCA_BOB2_*_MODE override assignments would erase those values.
[[ -f "${{ENV_FILE}}" ]] || fail "Missing .env file: ${{ENV_FILE}}"
if [[ "${{BQCA_PROJECT_ENV_LOADED:-0}}" != "1" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "${{ENV_FILE}}"
  set +a
  BQCA_PROJECT_ENV_LOADED=1
  export BQCA_PROJECT_ENV_LOADED
fi
# {marker}:END
'''
existing = re.compile(rf'(?ms)^# {re.escape(marker)}:BEGIN\n.*?^# {re.escape(marker)}:END\n?')
if existing.search(text):
    text = existing.sub(block, text, count=1)
else:
    canonical = re.compile(
        r'(?ms)^# Load appliance credentials and configuration\.\n'
        r'\[\[ -f "\$\{ENV_FILE\}" \]\] \|\| fail "Missing \.env file: \$\{ENV_FILE\}"\n'
        r'set -a\n# shellcheck source=/dev/null\nsource "\$\{ENV_FILE\}"\nset \+a\n'
    )
    match = canonical.search(text)
    if not match:
        raise SystemExit("Unable to locate bob-auth.sh .env load block")
    text = text[:match.start()] + block + text[match.end():]
path.write_text(text, encoding="utf-8")
PY
  chmod 755 "$BOB_AUTH"
}

patch_mode_bridge() {
  python3 - "$BOB2_LAUNCHER" "$MODE_MARKER" <<'PY'
from __future__ import annotations
import pathlib, re, sys
path = pathlib.Path(sys.argv[1])
marker = sys.argv[2]
text = path.read_text(encoding="utf-8")
text = re.sub(rf'(?ms)^# {re.escape(marker)}:BEGIN\n.*?^# {re.escape(marker)}:END\n?', '', text)

export_re = re.compile(
    r'(?ms)^export \\\n'
    r'  BQCA_BOB2_OUTPUT_FORMAT \\\n'
    r'  BQCA_BOB2_MAX_TURNS \\\n'
    r'  BQCA_BOB2_LOG_LEVEL \\\n'
    r'  BQCA_BOB2_AUTO_APPROVE \\\n'
    r'  BQCA_BOB2_INSTANCE_ID \\\n'
    r'  BQCA_BOB2_INTERACTIVE_MODE \\\n'
    r'  BQCA_BOB2_ASK_MODE \\\n'
    r'  BQCA_BOB2_CODE_MODE \\\n'
    r'  BQCA_BOB2_ADVANCED_MODE\n'
)
match = export_re.search(text)
if not match:
    raise SystemExit("Unable to locate Bob 2.x mode export block")
block = f'''# {marker}:BEGIN
bqca_trim_mode_value() {{
  local value="${{1:-}}"
  printf '%s' "${{value}}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}}

bqca_bob2_mode_is_available() {{
  local mode_name="${{1:-}}"
  case "${{mode_name}}" in agent|ask|plan) return 0 ;; esac
  [[ -n "${{mode_name}}" ]] && bqca_bob2_custom_mode_exists "${{mode_name}}"
}}

bqca_bob2_resolve_runtime_mode() {{
  local current_value="${{1:-}}" preferred_mode="$2" fallback_mode="$3" label="$4" resolved
  resolved="$(bqca_trim_mode_value "${{current_value}}")"
  [[ -n "${{resolved}}" ]] || resolved="$(bqca_bob2_resolve_mode "${{preferred_mode}}" "${{fallback_mode}}")"
  if ! bqca_bob2_mode_is_available "${{resolved}}"; then
    printf '[BQCA][ERROR] Bob Shell 2.x %s mode is unavailable: %s\\n' "${{label}}" "${{resolved:-<empty>}}" >&2
    return 1
  fi
  printf '%s\\n' "${{resolved}}"
}}

bqca_bob2_refresh_modes() {{
  BQCA_BOB2_INTERACTIVE_MODE="$(bqca_bob2_resolve_runtime_mode "${{BQCA_BOB2_INTERACTIVE_MODE:-}}" code agent interactive)" || return 1
  BQCA_BOB2_ASK_MODE="$(bqca_bob2_resolve_runtime_mode "${{BQCA_BOB2_ASK_MODE:-}}" ask ask expert)" || return 1
  BQCA_BOB2_CODE_MODE="$(bqca_bob2_resolve_runtime_mode "${{BQCA_BOB2_CODE_MODE:-}}" code agent developer)" || return 1
  BQCA_BOB2_ADVANCED_MODE="$(bqca_bob2_resolve_runtime_mode "${{BQCA_BOB2_ADVANCED_MODE:-}}" advanced plan advanced)" || return 1
  export BQCA_BOB2_INTERACTIVE_MODE BQCA_BOB2_ASK_MODE BQCA_BOB2_CODE_MODE BQCA_BOB2_ADVANCED_MODE
}}

bqca_bob2_require_mode() {{
  local selected_mode
  selected_mode="$(bqca_trim_mode_value "${{1:-}}")"
  if [[ -z "${{selected_mode}}" ]]; then
    printf '[BQCA][ERROR] Refusing to invoke Bob Shell 2.x with an empty mode.\\n' >&2
    return 1
  fi
  if ! bqca_bob2_mode_is_available "${{selected_mode}}"; then
    printf '[BQCA][ERROR] Refusing to invoke unavailable Bob Shell 2.x mode: %s\\n' "${{selected_mode}}" >&2
    return 1
  fi
  printf '%s\\n' "${{selected_mode}}"
}}

bqca_bob2_refresh_modes
# {marker}:END
'''
text = text[:match.end()] + '\n' + block + text[match.end():]

required_line = '  selected_mode="$(bqca_bob2_require_mode "${selected_mode}")" || return 1\n'
if required_line not in text:
    header = 'bqca_bob2_run() {\n  local selected_mode="$1"\n  local user_prompt="$2"\n'
    if header not in text:
        raise SystemExit("Unable to locate bqca_bob2_run header")
    text = text.replace(header, header + required_line, 1)

chat_guard = '''  if [[ -z "${resume_task}" ]]; then
    selected_mode="$(bqca_bob2_require_mode "${selected_mode}")" || return 1
  fi
'''
if chat_guard not in text:
    chat_header = 'bqca_bob2_chat() {\n  local selected_mode="${1:-}"\n  local resume_task="${2:-}"\n'
    if chat_header not in text:
        raise SystemExit("Unable to locate bqca_bob2_chat header")
    text = text.replace(chat_header, chat_header + chat_guard, 1)

refresh_block = '''# bob-auth.sh is sourced into this shell. Refresh the Bob 2.x bindings after
# authentication so no helper can leave the mode variables empty.
if bqca_is_bob2; then
  bqca_bob2_refresh_modes
fi

'''
if refresh_block not in text:
    auth_needle = '# shellcheck source=/dev/null\nsource "${SCRIPT_DIR}/bob-auth.sh"\n\n'
    if auth_needle not in text:
        raise SystemExit("Unable to locate bob-auth.sh source point")
    text = text.replace(auth_needle, auth_needle + refresh_block, 1)
path.write_text(text, encoding="utf-8")
PY
  chmod 755 "$BOB2_LAUNCHER"
}

validate_static() {
  local failures=0
  for file in "$XLAUNCHPAD" "$BOB_AUTH" "$BOB2_LAUNCHER"; do
    [[ -x "$file" ]] || { warn "Missing executable: $file"; failures=$((failures+1)); }
    bash -n "$file" || failures=$((failures+1))
  done
  [[ "$(grep -c "$ENV_MARKER:BEGIN" "$XLAUNCHPAD" || true)" -eq 1 ]] || failures=$((failures+1))
  [[ "$(grep -c "$ENV_MARKER:BEGIN" "$BOB_AUTH" || true)" -eq 1 ]] || failures=$((failures+1))
  [[ "$(grep -c "$ENV_MARKER:BEGIN" "$BOB2_LAUNCHER" || true)" -eq 1 ]] || failures=$((failures+1))
  [[ "$(grep -c "$MODE_MARKER:BEGIN" "$BOB2_LAUNCHER" || true)" -eq 1 ]] || failures=$((failures+1))
  grep -q 'selected_mode="$(bqca_bob2_require_mode' "$BOB2_LAUNCHER" || failures=$((failures+1))
  grep -Fq 'if [[ -z "${resume_task}" ]]; then' "$BOB2_LAUNCHER" || failures=$((failures+1))
  ((failures == 0))
}

validate_runtime() {
  local test_root mock_dir mock_log output_file
  test_root="$(mktemp -d)"
  mock_dir="$test_root/mockbin"
  mock_log="$test_root/mock.log"
  output_file="$test_root/output.log"
  mkdir -p "$test_root/.bob" "$test_root/bob-quantum-designs" "$test_root/bob-quantum-store" "$mock_dir"
  cp "$BOB2_LAUNCHER" "$test_root/$(basename "$BOB2_LAUNCHER")"
  cp "$BOB_AUTH" "$test_root/bob-auth.sh"
  cp "$BQCA_ROOT/bob-version.sh" "$test_root/bob-version.sh"
  cp "$BQCA_ROOT/bob-shell.sh" "$test_root/bob-shell.sh"
  cp "$BQCA_ROOT/tls-control.sh" "$test_root/tls-control.sh"
  cp "$CUSTOM_MODES" "$test_root/.bob/custom_modes.yaml"
  chmod 755 "$test_root"/*.sh
  cat > "$test_root/.env" <<'ENV'
BOB_API_KEY='TEST_KEY'
BOB_INSTANCE_ID='TEST_INSTANCE'
BOB_INCLUDED_DIRECTORY='/tmp'
BQCA_BOB2_OUTPUT_FORMAT=pretty
BQCA_BOB2_MAX_TURNS=5
BQCA_BOB2_LOG_LEVEL=warn
BQCA_BOB2_AUTO_APPROVE=0
BQCA_BOB2_INSTANCE_ID=''
BQCA_BOB2_INTERACTIVE_MODE=
BQCA_BOB2_ASK_MODE=
BQCA_BOB2_CODE_MODE=
BQCA_BOB2_ADVANCED_MODE=
BOB_TEAM_ID=
QCA_DESIGN_DIR='bob-quantum-designs'
QCA_STORE_DIR='bob-quantum-store'
ENV
  cat > "$mock_dir/bob" <<'MOCK'
#!/usr/bin/env bash
printf 'CALL:' >> "${BQCA_TEST_LOG}"
printf ' <%s>' "$@" >> "${BQCA_TEST_LOG}"
printf '\n' >> "${BQCA_TEST_LOG}"
case "${1:-}" in
  --version|-v) echo 2.0.1; exit 0 ;;
  run) echo '{"result":"OK"}'; exit 0 ;;
  chat) echo CHAT_OK; exit 0 ;;
  --help|-h) echo 'Usage: bob'; exit 0 ;;
esac
exit 0
MOCK
  chmod 755 "$mock_dir/bob"

  run_case() {
    local choice="$1" prompt="$2" expected_command="$3" expected_mode="$4" final_call status
    : > "$mock_log"
    : > "$output_file"
    set +e
    (
      cd "$test_root"
      if [[ -n "$prompt" ]]; then
        { printf '%s\n' "$choice"; printf '%s\n' "$prompt"; } | \
          TERM=xterm PATH="$mock_dir:$PATH" BOB_BIN="$mock_dir/bob" \
          BQCA_TEST_LOG="$mock_log" "./$(basename "$BOB2_LAUNCHER")" >"$output_file" 2>&1
      else
        printf '%s\n' "$choice" | \
          TERM=xterm PATH="$mock_dir:$PATH" BOB_BIN="$mock_dir/bob" \
          BQCA_TEST_LOG="$mock_log" "./$(basename "$BOB2_LAUNCHER")" >"$output_file" 2>&1
      fi
    )
    status=$?
    set -e
    if ((status != 0)); then
      cat "$output_file" >&2 || true
      return 1
    fi
    final_call="$(grep "^CALL: <${expected_command}>" "$mock_log" | tail -n 1 || true)"
    if [[ "$final_call" != *'<--mode>'*" <${expected_mode}>"* || "$final_call" == *'<--mode> <>'* ]]; then
      printf 'Unexpected Bob call for menu option %s: %s\n' "$choice" "$final_call" >&2
      return 1
    fi
  }

  run_case 1 '' chat code || { rm -rf "$test_root"; return 1; }
  run_case 2 'Who are you?' run ask || { rm -rf "$test_root"; return 1; }
  run_case 3 'Create a Bell circuit.' run code || { rm -rf "$test_root"; return 1; }
  run_case 4 'Design a VQE workflow.' run advanced || { rm -rf "$test_root"; return 1; }

  rm -rf "$test_root"
}

validate_installation() {
  local failures=0
  validate_static || failures=$((failures+1))
  validate_runtime || failures=$((failures+1))
  ((failures == 0)) || fail "v51.1 validation failed with $failures issue(s)."
  info "Validation passed: authentication no longer clears Bob 2.x modes; menu options 1-4 invoke code/ask/code/advanced without an empty mode."
}

if ((VALIDATE_ONLY)); then
  validate_installation
  exit 0
fi

create_backup
patch_project_env_loader "$XLAUNCHPAD"
patch_project_env_loader "$BOB2_LAUNCHER"
patch_auth_env_loader
patch_mode_bridge
mkdir -p "$PATCH_RECORD_DIR"
cat > "$PATCH_RECORD_FILE" <<RECORD
Patch: $PATCH_ID
Applied: $(date -u '+%Y-%m-%dT%H:%M:%SZ')
Root: $BQCA_ROOT
Backup: $BACKUP_DIR
Bob 2.x launcher: ${BOB2_LAUNCHER#$BQCA_ROOT/}
Behavior: idempotent project environment loading, post-authentication mode refresh, and empty-mode prevention for chat/run
Protected: .env, governed stores, HOME/.bob, HOME/qiskit-v2x-env, HOME/.qiskit/qiskit-ibm.json
RECORD
chmod 644 "$PATCH_RECORD_FILE"
validate_installation
info "Patch $PATCH_ID applied successfully."
info "Backup: $BACKUP_DIR"
info "Active v48 policy, custom_modes.yaml, BQCA DNA, rules, skills, tools, and knowledgebase were not changed."
