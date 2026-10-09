#!/usr/bin/env bash
set -Eeuo pipefail

#===============================================================================
# BQCA Bob Shell 2.0.x Native CLI Compatibility Patch v50-3
# File: patch-BQCA-v50-3.sh
# Author: Dr. Jeffrey Chijioke-Uche, IBM Computer Scientist
#
# Purpose:
#   Supersede the incomplete v50-1/v50-2 authentication integration and align
#   the standalone BQCA appliance with the installed Bob Shell 2.0.x command
#   model. Bob 2.0.0 advertises chat/run subcommands and does not advertise
#   --auth-method. This patch therefore:
#
#   - uses the project BOB_API_KEY and exports both supported key aliases;
#   - never passes --auth-method;
#   - dynamically discovers the installed Bob CLI's chat/run/mode/write/resume
#     capabilities from its own --help output;
#   - updates every BQCA Bob invocation through one compatibility adapter;
#   - removes legacy credential-file generation and obsolete 1.x flags;
#   - updates .env.example, while leaving the private .env byte-for-byte intact
#     when no private-file migration is necessary.
#
# Placement:
#   <BQCA-root>/patches/BQCA/patch-BQCA-v50-3.sh
#
# Protected assets:
#   The installer does not modify .env, HOME/.bob, bob-quantum-designs,
#   bob-quantum-store, HOME/qiskit-v2x-env, or HOME/.qiskit/qiskit-ibm.json.
#===============================================================================

PATCH_ID="BQCA-v50-3"
PATCH_FILE_NAME="patch-BQCA-v50-3.sh"
TIMESTAMP="$(date +%Y%m%d%H%M%S)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
TARGET_OVERRIDE=""
DRY_RUN=0
VALIDATE_ONLY=0
ROLLBACK_DIR=""

info() { printf '[BQCA v50-3][INFO] %s\n' "$*"; }
warn() { printf '[BQCA v50-3][WARN] %s\n' "$*" >&2; }
fail() { printf '[BQCA v50-3][ERROR] %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'USAGE'
BQCA Bob Shell 2.0.x Native CLI Compatibility Patch v50-3

Usage:
  ./patch-BQCA-v50-3.sh [options]

Options:
  --target <path>        Explicit standalone BQCA appliance root.
  --dry-run              Display the patch plan without changing files.
  --validate-only        Validate the installed v50-3 integration.
  --rollback <backup>    Restore a v50-3 timestamped backup directory.
  -h, --help             Show this help.

Expected placement:
  <BQCA-root>/patches/BQCA/patch-BQCA-v50-3.sh

The private project-root .env is inspected only for variable names during
validation and is never rewritten by this patch. The operator's existing
BOB_API_KEY remains valid; no duplicate secret variable is required.
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

for cmd in bash chmod cp date dirname find grep mkdir mktemp mv python3 rm sed sha256sum; do
  command -v "$cmd" >/dev/null 2>&1 || fail "Required command not found: $cmd"
done

is_bqca_root() {
  local candidate="$1"
  [[ -d "$candidate/.bob" ]] || return 1
  [[ -f "$candidate/.bob/custom_modes.yaml" ]] || return 1
  [[ -d "$candidate/.bob/quantum-tools" ]] || return 1
  [[ -f "$candidate/xLaunchpad.sh" ]] || return 1
  [[ -f "$candidate/bob-auth.sh" ]] || return 1
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
  fail "Unable to locate the BQCA root. Use --target <path>."
}

BQCA_ROOT="$(resolve_bqca_root)"
BOB_ROOT="$BQCA_ROOT/.bob"
TOOLS_DIR="$BOB_ROOT/quantum-tools"
XLAUNCHPAD="$BQCA_ROOT/xLaunchpad.sh"
BOB_AUTH_SH="$BQCA_ROOT/bob-auth.sh"
BOB_AUTH_MD="$BQCA_ROOT/bob-auth.md"
README_FILE="$BQCA_ROOT/README.md"
ENV_FILE="$BQCA_ROOT/.env"
ENV_EXAMPLE="$BQCA_ROOT/.env.example"
REGISTRY="$BOB_ROOT/BQCA-ACTIVE-POLICY-REGISTRY.json"
CLI_ADAPTER="$TOOLS_DIR/bqca-bob-cli-v2.sh"
SECRET_SCANNER="$TOOLS_DIR/bqca-secret-scan.py"
DYNAMIC_VALIDATOR="$TOOLS_DIR/bqca-dynamic-validator.py"
PATCH_RECORD_DIR="$BOB_ROOT/patches-applied"
PATCH_RECORD_FILE="$PATCH_RECORD_DIR/${PATCH_ID}.txt"
BACKUP_ROOT="$BOB_ROOT/patch-backups"
BACKUP_DIR="$BACKUP_ROOT/${PATCH_ID}.${TIMESTAMP}"
MARKER="BQCA-BOB-CLI-COMPAT-v50-3"
ENV_MARKER="BQCA-BOB-AUTH-ENV-v50-3"

mapfile -t BOB_LAUNCHERS < <(find "$BQCA_ROOT" -maxdepth 1 -type f -name 'bob-quantum-v*.sh' -print | sort -V)
((${#BOB_LAUNCHERS[@]} > 0)) || fail "No root bob-quantum-v*.sh launcher was found"

ENV_HASH_BEFORE=""
if [[ -f "$ENV_FILE" ]]; then
  ENV_HASH_BEFORE="$(sha256sum "$ENV_FILE" | awk '{print $1}')"
fi

backup_file() {
  local source="$1" rel destination
  [[ -e "$source" ]] || return 0
  [[ "$source" != "$ENV_FILE" ]] || return 0
  rel="${source#$BQCA_ROOT/}"
  destination="$BACKUP_DIR/$rel"
  mkdir -p "$(dirname "$destination")"
  cp -a "$source" "$destination"
}

create_backup() {
  mkdir -p "$BACKUP_DIR"
  backup_file "$XLAUNCHPAD"
  backup_file "$BOB_AUTH_SH"
  backup_file "$BOB_AUTH_MD"
  backup_file "$README_FILE"
  backup_file "$ENV_EXAMPLE"
  backup_file "$REGISTRY"
  backup_file "$CLI_ADAPTER"
  backup_file "$SECRET_SCANNER"
  backup_file "$DYNAMIC_VALIDATOR"
  backup_file "$PATCH_RECORD_FILE"
  local launcher
  for launcher in "${BOB_LAUNCHERS[@]}"; do
    backup_file "$launcher"
  done

  cat > "$BACKUP_DIR/BQCA-v50-3-backup-manifest.txt" <<MANIFEST
Patch: $PATCH_ID
Created: $(date -u '+%Y-%m-%dT%H:%M:%SZ')
Appliance root: $BQCA_ROOT
Private .env intentionally excluded and unchanged: yes
Restore with:
  $PATCH_FILE_NAME --target "$BQCA_ROOT" --rollback "$BACKUP_DIR"
MANIFEST
}

restore_backup() {
  local backup="$1" backup_abs source rel destination
  backup_abs="$(cd "$backup" 2>/dev/null && pwd -P || true)"
  [[ -n "$backup_abs" ]] || fail "Rollback directory not found: $backup"
  [[ -f "$backup_abs/BQCA-v50-3-backup-manifest.txt" ]] || fail "Not a BQCA v50-3 backup: $backup_abs"

  info "Restoring v50-3 backup: $backup_abs"
  while IFS= read -r -d '' source; do
    rel="${source#$backup_abs/}"
    [[ "$rel" != "BQCA-v50-3-backup-manifest.txt" ]] || continue
    destination="$BQCA_ROOT/$rel"
    mkdir -p "$(dirname "$destination")"
    cp -a "$source" "$destination"
  done < <(find "$backup_abs" -mindepth 1 -type f -print0)

  for destination in "$CLI_ADAPTER" "$PATCH_RECORD_FILE"; do
    rel="${destination#$BQCA_ROOT/}"
    [[ -e "$backup_abs/$rel" ]] || rm -f "$destination"
  done

  if [[ -n "$ENV_HASH_BEFORE" && -f "$ENV_FILE" ]]; then
    [[ "$(sha256sum "$ENV_FILE" | awk '{print $1}')" == "$ENV_HASH_BEFORE" ]] || fail ".env changed during rollback; refusing to claim success"
  fi
  info "Rollback complete. The private .env and Bob HOME settings were not touched."
}

if [[ -n "$ROLLBACK_DIR" ]]; then
  restore_backup "$ROLLBACK_DIR"
  exit 0
fi

info "Resolved BQCA root: $BQCA_ROOT"
info "Patch identity: $PATCH_ID"
info "Bob 2.0.x target: native environment-key authentication with chat/run capability detection"
info "Protected assets: .env, workload stores, HOME/.bob, HOME/qiskit-v2x-env, and qiskit-ibm.json"

if ((DRY_RUN)); then
  cat <<DRY
[BQCA v50-3][DRY-RUN] Planned changes:
  1. Install .bob/quantum-tools/bqca-bob-cli-v2.sh.
  2. Remove all v50-1/v50-2 --auth-method integration.
  3. Export one API key through both BOB_API_KEY and BOBSHELL_API_KEY.
  4. Replace every BQCA Bob invocation with the capability-aware adapter.
  5. Prefer Bob 2.x chat/run subcommands and fall back to top-level -p/resume.
  6. Dynamically use --mode or --chat-mode only when advertised by the CLI.
  7. Dynamically use --yolo/--auto-approve/--trust only when advertised.
  8. Replace legacy bob-auth.sh credential-file generation with local capability setup.
  9. Update .env.example, README.md, and bob-auth.md.
 10. Leave the private .env byte-for-byte unchanged.
DRY
  exit 0
fi

write_cli_adapter() {
  cat > "$CLI_ADAPTER" <<'SH'
#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
BQCA_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
BOB_BIN="${BOB_BIN:-bob}"

fail() { printf '[BQCA v50-3][ERROR] %s\n' "$*" >&2; exit 2; }
warn() { [[ "${BQCA_BOB_CLI_QUIET:-0}" == "1" ]] || printf '[BQCA v50-3][WARN] %s\n' "$*" >&2; }

command -v "$BOB_BIN" >/dev/null 2>&1 || fail "Bob CLI command not found: $BOB_BIN"

load_project_environment() {
  local env_file="$BQCA_ROOT/.env"
  local inherited_bob="${BOB_API_KEY-}"
  local inherited_shell="${BOBSHELL_API_KEY-}"
  if [[ -f "$env_file" ]]; then
    unset BOB_API_KEY BOBSHELL_API_KEY
    set -a
    # shellcheck disable=SC1090
    source "$env_file"
    set +a
    if [[ -z "${BOB_API_KEY:-}" && -z "${BOBSHELL_API_KEY:-}" ]]; then
      [[ -z "$inherited_bob" ]] || BOB_API_KEY="$inherited_bob"
      [[ -z "$inherited_shell" ]] || BOBSHELL_API_KEY="$inherited_shell"
    fi
  fi
}

bob_version_raw="$($BOB_BIN --version 2>&1 || true)"
bob_version="$(grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' <<<"$bob_version_raw" | head -n 1 || true)"
[[ -n "$bob_version" ]] || fail "Unable to parse Bob CLI version from: $bob_version_raw"
bob_major="${bob_version%%.*}"

load_project_environment
if (( bob_major >= 2 )); then
  selected_key="${BOB_API_KEY:-${BOBSHELL_API_KEY:-}}"
  key_source="${BOB_API_KEY:+BOB_API_KEY}"
  [[ -n "$key_source" ]] || key_source="BOBSHELL_API_KEY_COMPATIBILITY"
else
  selected_key="${BOBSHELL_API_KEY:-${BOB_API_KEY:-}}"
  key_source="${BOBSHELL_API_KEY:+BOBSHELL_API_KEY}"
  [[ -n "$key_source" ]] || key_source="BOB_API_KEY_COMPATIBILITY"
fi
[[ -n "$selected_key" ]] || fail "No Bob API key is configured. Set BOB_API_KEY in the project .env."

# Export both names with one identical value. Bob distributions and IBM
# documentation have used both names; no unsupported auth flag is required.
BOB_API_KEY="$selected_key"
BOBSHELL_API_KEY="$selected_key"
export BOB_API_KEY BOBSHELL_API_KEY
[[ -z "${BOB_ENDPOINT:-}" ]] || export BOB_ENDPOINT
[[ -z "${BOB_AUTH_ENDPOINT:-}" ]] || export BOB_AUTH_ENDPOINT
[[ -z "${BOB_REGION:-}" ]] || export BOB_REGION

TOP_HELP="$($BOB_BIN --help 2>&1 || true)"
CHAT_HELP="$($BOB_BIN chat --help 2>&1 || true)"
RUN_HELP="$($BOB_BIN run --help 2>&1 || true)"

help_has() {
  local text="$1" token="$2"
  grep -Fq -- "$token" <<<"$text"
}

has_command() {
  local name="$1"
  grep -Eq "^[[:space:]]*${name}([[:space:]]|$)" <<<"$TOP_HELP"
}

append_mode_args() {
  local mode="$1" subhelp="$2"
  if help_has "$subhelp" "--mode"; then
    BQCA_SUB_ARGS+=(--mode "$mode")
  elif help_has "$subhelp" "--chat-mode"; then
    BQCA_SUB_ARGS+=(--chat-mode "$mode")
  elif help_has "$TOP_HELP" "--mode"; then
    BQCA_GLOBAL_ARGS+=(--mode "$mode")
  elif help_has "$TOP_HELP" "--chat-mode"; then
    BQCA_GLOBAL_ARGS+=(--chat-mode "$mode")
  else
    warn "Bob $bob_version does not advertise a mode option; using automatic mode selection for BQCA intent '$mode'."
  fi
}

append_common_args() {
  local subhelp="$1" write_mode="$2"
  if help_has "$TOP_HELP" "--accept-license"; then
    BQCA_GLOBAL_ARGS+=(--accept-license)
  elif help_has "$subhelp" "--accept-license"; then
    BQCA_SUB_ARGS+=(--accept-license)
  fi

  if [[ -n "${BOB_TEAM_ID:-}" ]]; then
    if help_has "$subhelp" "--team-id"; then
      BQCA_SUB_ARGS+=(--team-id "$BOB_TEAM_ID")
    elif help_has "$TOP_HELP" "--team-id"; then
      BQCA_GLOBAL_ARGS+=(--team-id "$BOB_TEAM_ID")
    else
      warn "BOB_TEAM_ID is set, but Bob $bob_version does not advertise --team-id."
    fi
  fi

  if [[ -n "${BOB_INSTANCE_ID:-}" ]]; then
    if help_has "$subhelp" "--instance-id"; then
      BQCA_SUB_ARGS+=(--instance-id "$BOB_INSTANCE_ID")
    elif help_has "$TOP_HELP" "--instance-id"; then
      BQCA_GLOBAL_ARGS+=(--instance-id "$BOB_INSTANCE_ID")
    fi
  fi

  if [[ -n "${BOB_INCLUDED_DIRECTORY:-}" ]]; then
    if help_has "$subhelp" "--include-directories"; then
      BQCA_SUB_ARGS+=(--include-directories "$BOB_INCLUDED_DIRECTORY")
    elif help_has "$TOP_HELP" "--include-directories"; then
      BQCA_GLOBAL_ARGS+=(--include-directories "$BOB_INCLUDED_DIRECTORY")
    fi
  fi

  if [[ "$write_mode" == "1" ]]; then
    if help_has "$subhelp" "--yolo"; then
      BQCA_SUB_ARGS+=(--yolo)
    elif help_has "$TOP_HELP" "--yolo"; then
      BQCA_GLOBAL_ARGS+=(--yolo)
    elif help_has "$subhelp" "--auto-approve"; then
      BQCA_SUB_ARGS+=(--auto-approve)
    elif help_has "$TOP_HELP" "--auto-approve"; then
      BQCA_GLOBAL_ARGS+=(--auto-approve)
    elif help_has "$subhelp" "--trust"; then
      BQCA_SUB_ARGS+=(--trust)
    elif help_has "$TOP_HELP" "--trust"; then
      BQCA_GLOBAL_ARGS+=(--trust)
    else
      warn "Bob $bob_version does not advertise a write-approval option; file changes may require an interactive session."
    fi
  fi

  if [[ "${BQCA_BOB_DEBUG:-0}" == "1" || "${BQCA_BOB_AUTH_DEBUG:-0}" == "1" ]]; then
    if help_has "$subhelp" "--debug"; then
      BQCA_SUB_ARGS+=(--debug)
    elif help_has "$TOP_HELP" "--debug"; then
      BQCA_GLOBAL_ARGS+=(--debug)
    elif help_has "$subhelp" "--log-level"; then
      BQCA_SUB_ARGS+=(--log-level debug)
    elif help_has "$TOP_HELP" "--log-level"; then
      BQCA_GLOBAL_ARGS+=(--log-level debug)
    fi
  fi
}

run_task() {
  local mode="" prompt="" write_mode=0
  while (($#)); do
    case "$1" in
      --mode) mode="${2:?--mode requires a value}"; shift 2 ;;
      --prompt) prompt="${2:?--prompt requires a value}"; shift 2 ;;
      --write) write_mode=1; shift ;;
      *) fail "Unknown run option: $1" ;;
    esac
  done
  [[ -n "$prompt" ]] || fail "run requires --prompt"
  BQCA_GLOBAL_ARGS=()
  BQCA_SUB_ARGS=()
  if has_command run; then
    append_common_args "$RUN_HELP" "$write_mode"
    [[ -z "$mode" ]] || append_mode_args "$mode" "$RUN_HELP"
    if help_has "$RUN_HELP" "--workspace"; then
      BQCA_SUB_ARGS+=(--workspace "$BQCA_ROOT")
    fi
    cd "$BQCA_ROOT"
    exec "$BOB_BIN" "${BQCA_GLOBAL_ARGS[@]}" run "${BQCA_SUB_ARGS[@]}" "$prompt"
  fi

  append_common_args "$TOP_HELP" "$write_mode"
  [[ -z "$mode" ]] || append_mode_args "$mode" "$TOP_HELP"
  if help_has "$TOP_HELP" "--prompt" || help_has "$TOP_HELP" "-p"; then
    cd "$BQCA_ROOT"
    exec "$BOB_BIN" "${BQCA_GLOBAL_ARGS[@]}" "${BQCA_SUB_ARGS[@]}" -p "$prompt"
  fi
  fail "Bob $bob_version provides neither a run command nor a top-level prompt option."
}

chat_session() {
  local mode="" initial_prompt="" write_mode=0
  while (($#)); do
    case "$1" in
      --mode) mode="${2:?--mode requires a value}"; shift 2 ;;
      --initial-prompt) initial_prompt="${2:?--initial-prompt requires a value}"; shift 2 ;;
      --write) write_mode=1; shift ;;
      *) fail "Unknown chat option: $1" ;;
    esac
  done
  BQCA_GLOBAL_ARGS=()
  BQCA_SUB_ARGS=()
  if has_command chat; then
    append_common_args "$CHAT_HELP" "$write_mode"
    [[ -z "$mode" ]] || append_mode_args "$mode" "$CHAT_HELP"
    if [[ -n "$initial_prompt" ]]; then
      if help_has "$CHAT_HELP" "--prompt-interactive"; then
        BQCA_SUB_ARGS+=(--prompt-interactive "$initial_prompt")
      elif help_has "$CHAT_HELP" "--prompt"; then
        BQCA_SUB_ARGS+=(--prompt "$initial_prompt")
      elif help_has "$CHAT_HELP" "--initial-prompt"; then
        BQCA_SUB_ARGS+=(--initial-prompt "$initial_prompt")
      fi
    fi
    cd "$BQCA_ROOT"
    exec "$BOB_BIN" "${BQCA_GLOBAL_ARGS[@]}" chat "${BQCA_SUB_ARGS[@]}"
  fi

  append_common_args "$TOP_HELP" "$write_mode"
  [[ -z "$mode" ]] || append_mode_args "$mode" "$TOP_HELP"
  if [[ -n "$initial_prompt" ]] && help_has "$TOP_HELP" "--prompt-interactive"; then
    BQCA_GLOBAL_ARGS+=(--prompt-interactive "$initial_prompt")
  fi
  cd "$BQCA_ROOT"
  exec "$BOB_BIN" "${BQCA_GLOBAL_ARGS[@]}" "${BQCA_SUB_ARGS[@]}"
}

resume_session() {
  BQCA_GLOBAL_ARGS=()
  BQCA_SUB_ARGS=()
  if has_command chat && help_has "$CHAT_HELP" "--resume"; then
    append_common_args "$CHAT_HELP" 0
    BQCA_SUB_ARGS+=(--resume latest)
    cd "$BQCA_ROOT"
    exec "$BOB_BIN" "${BQCA_GLOBAL_ARGS[@]}" chat "${BQCA_SUB_ARGS[@]}"
  elif help_has "$TOP_HELP" "--resume"; then
    append_common_args "$TOP_HELP" 0
    cd "$BQCA_ROOT"
    exec "$BOB_BIN" "${BQCA_GLOBAL_ARGS[@]}" --resume latest
  elif help_has "$TOP_HELP" "-r"; then
    append_common_args "$TOP_HELP" 0
    cd "$BQCA_ROOT"
    exec "$BOB_BIN" "${BQCA_GLOBAL_ARGS[@]}" -r latest
  fi
  fail "Bob $bob_version does not advertise resume support."
}

print_capabilities() {
  printf 'BQCA_BOB_CLI_VERSION=%s\n' "$bob_version"
  printf 'BQCA_BOB_CLI_MAJOR=%s\n' "$bob_major"
  printf 'BQCA_BOB_KEY_SOURCE=%s\n' "$key_source"
  printf 'BQCA_BOB_CHAT_COMMAND=%s\n' "$(has_command chat && printf YES || printf NO)"
  printf 'BQCA_BOB_RUN_COMMAND=%s\n' "$(has_command run && printf YES || printf NO)"
  printf 'BQCA_BOB_TOP_PROMPT=%s\n' "$(help_has "$TOP_HELP" '-p' && printf YES || printf NO)"
  printf 'BQCA_BOB_AUTH_METHOD_FLAG=%s\n' "$(help_has "$TOP_HELP" '--auth-method' && printf YES || printf NO)"
}

command_name="${1:-}"
[[ -n "$command_name" ]] || fail "Usage: $(basename "$0") {chat|run|resume|capabilities} ..."
shift || true
case "$command_name" in
  chat) chat_session "$@" ;;
  run) run_task "$@" ;;
  resume) resume_session "$@" ;;
  capabilities) print_capabilities ;;
  *) fail "Unknown command: $command_name" ;;
esac

# BQCA-ACTIVE-CENTRAL-POLICY:BEGIN
# This runtime compatibility adapter does not define quantum policy. Design,
# code, execution, and completion decisions continue to follow the active
# central policy resolved through bqca-active-policy-listener.sh.
# BQCA-ACTIVE-CENTRAL-POLICY:END
SH
  chmod 755 "$CLI_ADAPTER"
}

write_bob_auth() {
  cat > "$BOB_AUTH_SH" <<'AUTH'
#!/usr/bin/env bash
set -Eeuo pipefail

#===============================================================================
# IBM Bob Quantum Computing Agent (BQCA)
# Bob Shell 2.0.x API-key bootstrap
# Managed by patch-BQCA-v50-3.sh
#===============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ENV_FILE="$SCRIPT_DIR/.env"
CLI_ADAPTER="$SCRIPT_DIR/.bob/quantum-tools/bqca-bob-cli-v2.sh"
CYAN="${CYAN:-}"
RESET="${RESET:-}"

[[ -f "$ENV_FILE" ]] || {
  printf 'Bob Shell Authentication Failed: missing environment file: %s\n' "$ENV_FILE" >&2
  exit 1
}

inherited_bob="${BOB_API_KEY-}"
inherited_shell="${BOBSHELL_API_KEY-}"
unset BOB_API_KEY BOBSHELL_API_KEY
set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a
if [[ -z "${BOB_API_KEY:-}" && -z "${BOBSHELL_API_KEY:-}" ]]; then
  [[ -z "$inherited_bob" ]] || BOB_API_KEY="$inherited_bob"
  [[ -z "$inherited_shell" ]] || BOBSHELL_API_KEY="$inherited_shell"
fi

BOB_BIN="${BOB_BIN:-bob}"
command -v "$BOB_BIN" >/dev/null 2>&1 || {
  printf 'Bob Shell Authentication Failed: Bob CLI command not found: %s\n' "$BOB_BIN" >&2
  exit 1
}

version_raw="$($BOB_BIN --version 2>&1 || true)"
version="$(grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' <<<"$version_raw" | head -n 1 || true)"
[[ -n "$version" ]] || {
  printf 'Bob Shell Authentication Failed: unable to parse Bob CLI version from: %s\n' "$version_raw" >&2
  exit 1
}
major="${version%%.*}"

if (( major >= 2 )); then
  selected_key="${BOB_API_KEY:-${BOBSHELL_API_KEY:-}}"
  key_source="${BOB_API_KEY:+BOB_API_KEY}"
  [[ -n "$key_source" ]] || key_source="BOBSHELL_API_KEY_COMPATIBILITY"
else
  selected_key="${BOBSHELL_API_KEY:-${BOB_API_KEY:-}}"
  key_source="${BOBSHELL_API_KEY:+BOBSHELL_API_KEY}"
  [[ -n "$key_source" ]] || key_source="BOB_API_KEY_COMPATIBILITY"
fi

[[ -n "$selected_key" ]] || {
  printf 'Bob Shell Authentication Failed: set BOB_API_KEY in the project .env.\n' >&2
  exit 1
}

BOB_API_KEY="$selected_key"
BOBSHELL_API_KEY="$selected_key"
BQCA_BOB_KEY_SOURCE="$key_source"
export BOB_API_KEY BOBSHELL_API_KEY BQCA_BOB_KEY_SOURCE BOB_BIN
[[ -z "${BOB_ENDPOINT:-}" ]] || export BOB_ENDPOINT
[[ -z "${BOB_AUTH_ENDPOINT:-}" ]] || export BOB_AUTH_ENDPOINT
[[ -z "${BOB_REGION:-}" ]] || export BOB_REGION

[[ -x "$CLI_ADAPTER" ]] || {
  printf 'Bob Shell Authentication Failed: Bob 2.x compatibility adapter is missing: %s\n' "$CLI_ADAPTER" >&2
  exit 1
}
if ! "$CLI_ADAPTER" capabilities >/dev/null; then
  printf 'Bob Shell Authentication Failed: unable to validate Bob CLI capabilities.\n' >&2
  exit 1
fi

BQCA_BOB_AUTH_PREFLIGHT="${BQCA_BOB_AUTH_PREFLIGHT:-configure-only}"
case "$BQCA_BOB_AUTH_PREFLIGHT" in
  configure-only|auto|off|skip|false|0|defer)
    printf '%b\n' "${CYAN}Bob Shell ${version} API-key environment configured; the first BQCA request will validate connectivity.${RESET}"
    ;;
  live|required)
    auth_log="$(mktemp "${TMPDIR:-/tmp}/bqca-bob-auth.XXXXXX")"
    set +e
    "$CLI_ADAPTER" run --mode ask --prompt 'Reply exactly: BQCA_AUTH_OK' >"$auth_log" 2>&1
    status=$?
    set -e
    if (( status == 0 )); then
      rm -f "$auth_log"
      printf '%b\n' "${CYAN}Bob Shell authenticated successfully with the configured API key.${RESET}"
    else
      printf 'Bob Shell Authentication Failed: the optional live API-key preflight was rejected.\n' >&2
      printf 'Verify BOB_API_KEY, key scope/team selection, proxy, TLS, and Bob service availability.\n' >&2
      if [[ "${BQCA_BOB_AUTH_DEBUG:-0}" == "1" ]]; then
        sed -E 's/[A-Za-z0-9._~+\/=:-]{24,}/[REDACTED]/g' "$auth_log" >&2 || true
      fi
      rm -f "$auth_log"
      exit "$status"
    fi
    ;;
  *)
    printf 'Bob Shell Authentication Failed: invalid BQCA_BOB_AUTH_PREFLIGHT value: %s\n' "$BQCA_BOB_AUTH_PREFLIGHT" >&2
    exit 2
    ;;
esac
AUTH
  chmod 755 "$BOB_AUTH_SH"
}

patch_xlaunchpad() {
  local temporary
  temporary="$(mktemp)"
  python3 - "$XLAUNCHPAD" "$temporary" <<'PY'
import pathlib, re, sys
src = pathlib.Path(sys.argv[1])
out = pathlib.Path(sys.argv[2])
text = src.read_text(encoding="utf-8")

# Remove failed v50-1/v50-2 authentication integrations and any prior v50-3 block.
for marker in (
    "BQCA-BOB-NATIVE-API-KEY-v50-1",
    "BQCA-BOB-NATIVE-API-KEY-v50-2",
    "BQCA-BOB-AUTH-ENV-v50-1",
    "BQCA-BOB-AUTH-ENV-v50-2",
    "BQCA-BOB-AUTH-ENV-v50-3",
):
    text = re.sub(rf"(?ms)^# {re.escape(marker)}:BEGIN\n.*?^# {re.escape(marker)}:END\n?", "", text)

# Remove obsolete browser-auth integration and duplicate raw .env loading blocks.
text = re.sub(r"(?m)^\s*chmod\s+777\s+configure-bob-auth-browser\.sh\s*\n", "", text)
text = re.sub(r"(?m)^\s*source\s+(?:\"?\$\{?SCRIPT_DIR\}?/?\"?)?configure-bob-auth-browser\.sh\s*\n", "", text)
text = re.sub(r"(?m)^\s*source\s+configure-bob-auth-browser\.sh\s*\n", "", text)
text = re.sub(
    r"(?ms)^set -a\n(?:# shellcheck[^\n]*\n)?source \"\$\{SCRIPT_DIR\}/\.env\"\nset \+a\n",
    "",
    text,
)

# Remove stale single-line authentication assertions from prior updates.
text = re.sub(r"(?m)^\s*: \"\$\{BOBSHELL_API_KEY:[^\n]*\n", "", text)
text = re.sub(r"(?m)^\s*BOB_AUTH_METHOD=.*\n", "", text)
text = re.sub(r"(?m)^\s*export\s+BOBSHELL_API_KEY\s+BOB_AUTH_METHOD.*\n", "", text)

block = r'''# BQCA-BOB-AUTH-ENV-v50-3:BEGIN
# Load the project environment once. Bob Shell 2.0.x in this appliance uses
# BOB_API_KEY. BQCA exports the same selected value under BOBSHELL_API_KEY as a
# compatibility alias because IBM Bob distributions/documentation have used
# both names. No --auth-method flag is passed unless a future CLI advertises it.
_BQCA_INHERITED_BOB_API_KEY="${BOB_API_KEY-}"
_BQCA_INHERITED_BOBSHELL_API_KEY="${BOBSHELL_API_KEY-}"
unset BOB_API_KEY BOBSHELL_API_KEY
set -a
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/.env"
set +a
if [[ -z "${BOB_API_KEY:-}" && -z "${BOBSHELL_API_KEY:-}" ]]; then
  [[ -z "${_BQCA_INHERITED_BOB_API_KEY}" ]] || BOB_API_KEY="${_BQCA_INHERITED_BOB_API_KEY}"
  [[ -z "${_BQCA_INHERITED_BOBSHELL_API_KEY}" ]] || BOBSHELL_API_KEY="${_BQCA_INHERITED_BOBSHELL_API_KEY}"
fi
unset _BQCA_INHERITED_BOB_API_KEY _BQCA_INHERITED_BOBSHELL_API_KEY
_BQCA_SELECTED_BOB_API_KEY="${BOB_API_KEY:-${BOBSHELL_API_KEY:-}}"
: "${_BQCA_SELECTED_BOB_API_KEY:?BOB_API_KEY is not set in the project .env}"
BOB_API_KEY="${_BQCA_SELECTED_BOB_API_KEY}"
BOBSHELL_API_KEY="${_BQCA_SELECTED_BOB_API_KEY}"
export BOB_API_KEY BOBSHELL_API_KEY
unset _BQCA_SELECTED_BOB_API_KEY
# BQCA-BOB-AUTH-ENV-v50-3:END
'''

# Place the environment block after the v50 permission guard when present,
# otherwise after Patch 49, otherwise after the initial SCRIPT_DIR assignment.
inserted = False
for marker in ("BQCA-CRITICAL-PERMISSION-GUARD-v50", "BQCA-ROOT-FILENAME-VERSION-SYNC-49"):
    pattern = rf"(?ms)(^# {re.escape(marker)}:BEGIN\n.*?^# {re.escape(marker)}:END\n)"
    if re.search(pattern, text):
        text = re.sub(pattern, rf"\1\n{block}\n", text, count=1)
        inserted = True
        break
if not inserted:
    needle = 'SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"\n'
    if needle not in text:
        raise SystemExit("Unable to locate xLaunchpad insertion boundary")
    text = text.replace(needle, needle + "\n" + block + "\n", 1)

# Any remaining requirement should use the selected v2-compatible key.
text = re.sub(
    r': "\$\{BOB_API_KEY:\?BOB_API_KEY is not set in the \.env\}"',
    ': "${BOB_API_KEY:?BOB_API_KEY is not set in the .env}"',
    text,
)
text = re.sub(
    r': "\$\{BOBSHELL_API_KEY:\?[^\n]*\}"',
    ': "${BOB_API_KEY:?BOB_API_KEY is not set in the .env}"',
    text,
)
out.write_text(text, encoding="utf-8")
PY
  cp "$temporary" "$XLAUNCHPAD"
  rm -f "$temporary"
  chmod 755 "$XLAUNCHPAD"
}

patch_launchers() {
  local launcher temporary
  for launcher in "${BOB_LAUNCHERS[@]}"; do
    temporary="$(mktemp)"
    python3 - "$launcher" "$temporary" <<'PY'
import pathlib, re, sys
src = pathlib.Path(sys.argv[1])
out = pathlib.Path(sys.argv[2])
text = src.read_text(encoding="utf-8")

for marker in (
    "BQCA-BOB-AUTH-ENV-v50-1",
    "BQCA-BOB-AUTH-ENV-v50-2",
    "BQCA-BOB-NATIVE-API-KEY-v50-1",
    "BQCA-BOB-NATIVE-API-KEY-v50-2",
    "BQCA-BOB-CLI-COMPAT-v50-3",
):
    text = re.sub(rf"(?ms)^# {re.escape(marker)}:BEGIN\n.*?^# {re.escape(marker)}:END\n?", "", text)

# Remove duplicate raw environment loads and reinstall one version-neutral block.
text = re.sub(
    r"(?ms)^set -a\n(?:# shellcheck[^\n]*\n)?source \"\$\{SCRIPT_DIR\}/\.env\"\nset \+a\n",
    "",
    text,
)

env_block = r'''# BQCA-BOB-CLI-COMPAT-v50-3:BEGIN
# Bob Shell 2.0.x compatibility: the project BOB_API_KEY is authoritative;
# BOBSHELL_API_KEY is exported with the same value for distribution compatibility.
set -a
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/.env"
set +a
_BQCA_SELECTED_BOB_API_KEY="${BOB_API_KEY:-${BOBSHELL_API_KEY:-}}"
: "${_BQCA_SELECTED_BOB_API_KEY:?BOB_API_KEY is required for BQCA Bob Shell execution}"
BOB_API_KEY="${_BQCA_SELECTED_BOB_API_KEY}"
BOBSHELL_API_KEY="${_BQCA_SELECTED_BOB_API_KEY}"
BQCA_BOB_CLI_ADAPTER="${SCRIPT_DIR}/.bob/quantum-tools/bqca-bob-cli-v2.sh"
[[ -x "${BQCA_BOB_CLI_ADAPTER}" ]] || {
  printf '[BQCA v50-3][ERROR] Bob CLI compatibility adapter is missing: %s\n' "${BQCA_BOB_CLI_ADAPTER}" >&2
  exit 1
}
export BOB_API_KEY BOBSHELL_API_KEY BQCA_BOB_CLI_ADAPTER
unset _BQCA_SELECTED_BOB_API_KEY
# BQCA-BOB-CLI-COMPAT-v50-3:END
'''

# Insert after the TLS helper so environment values are available before menu setup.
needle_re = r'(?m)^source "\$\{SCRIPT_DIR\}/tls-control\.sh"\n'
if re.search(needle_re, text):
    text = re.sub(needle_re, lambda m: m.group(0) + "\n" + env_block + "\n", text, count=1)
else:
    needle = 'SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"\n'
    if needle not in text:
        raise SystemExit(f"Unable to locate environment insertion boundary in {src}")
    text = text.replace(needle, needle + "\n" + env_block + "\n", 1)

# Retire obsolete 1.x tool-flag arrays. Runtime capability selection now lives
# in bqca-bob-cli-v2.sh.
text = re.sub(
    r"(?ms)^BOB_QUANTUM_TOOL_FLAGS=\(\n.*?^\)\n",
    "BOB_QUANTUM_TOOL_FLAGS=()\n",
    text,
)

adapter_note = r'''# BQCA-BOB-CLI-COMPAT-v50-3:BEGIN
# Every Bob invocation delegates to the installed CLI capability adapter. The
# adapter uses chat/run when advertised, top-level -p/resume as compatibility
# fallbacks, and never assumes --auth-method exists.
# BQCA-BOB-CLI-COMPAT-v50-3:END
'''
# The environment block already uses this marker. Keep exactly one marker by
# appending the note inside the existing block rather than adding a second block.
text = text.replace(
    '# BQCA-BOB-CLI-COMPAT-v50-3:END\n',
    '# Every Bob invocation below delegates to this capability-aware adapter.\n# BQCA-BOB-CLI-COMPAT-v50-3:END\n',
    1,
)

replacements = {
    "quantum_interactive": '''    quantum_interactive() {\n      "${BQCA_BOB_CLI_ADAPTER}" chat \\\n        --mode code \\\n        --write \\\n        --initial-prompt "${INITIAL_PROMPT}"\n    }\n''',
    "quantum_assist": '''    quantum_assist() {\n      "${BQCA_BOB_CLI_ADAPTER}" run \\\n        --mode ask \\\n        --prompt "${prompt}"\n    }\n''',
    "quantum_code": '''    quantum_code() {\n      "${BQCA_BOB_CLI_ADAPTER}" run \\\n        --mode code \\\n        --write \\\n        --prompt "${prompt}"\n    }\n''',
    "quantum_advanced": '''    quantum_advanced() {\n      "${BQCA_BOB_CLI_ADAPTER}" run \\\n        --mode advanced \\\n        --write \\\n        --prompt "${prompt}"\n    }\n''',
    "quantum_resume": '''    quantum_resume() {\n      "${BQCA_BOB_CLI_ADAPTER}" resume\n    }\n''',
}
for name, replacement in replacements.items():
    pattern = rf"(?ms)^    {name}\(\) \{{\n.*?^    \}}\n"
    text, count = re.subn(pattern, replacement, text, count=1)
    if count != 1:
        raise SystemExit(f"Unable to replace {name} in {src}")

# Remove stale v50-1/v50-2 variables and assertions outside marker blocks.
text = re.sub(r"(?m)^\s*BOB_AUTH_METHOD=.*\n", "", text)
text = re.sub(r"(?m)^\s*BQCA_BOB_NATIVE_AUTH_ARGS=.*\n", "", text)
text = re.sub(r"(?m)^\s*: \"\$\{BOBSHELL_API_KEY:[^\n]*\n", "", text)

out.write_text(text, encoding="utf-8")
PY
    cp "$temporary" "$launcher"
    rm -f "$temporary"
    chmod 755 "$launcher"
  done
}

patch_env_example() {
  [[ -f "$ENV_EXAMPLE" ]] || return 0
  local temporary
  temporary="$(mktemp)"
  python3 - "$ENV_EXAMPLE" "$temporary" <<'PYENV'
import pathlib
import re
import sys

src = pathlib.Path(sys.argv[1])
out = pathlib.Path(sys.argv[2])
lines = src.read_text(encoding="utf-8").splitlines()

managed_comment_fragments = (
    "Bob Shell 2.0.x API key used by BQCA",
    "BQCA exports the same selected value under BOBSHELL_API_KEY",
    "for compatibility. Do not duplicate the secret",
    "Optional team identifier for a general API key",
    "only when the installed Bob CLI advertises --team-id",
    "--team-id.",
    "Legacy compatibility alias",
    "Prefer BOBSHELL_API_KEY",
    "Use BOB_API_KEY for the BQCA Bob Shell runtime",
)

result = []
skipping_generated_preamble = False
for line in lines:
    if line.startswith("# BQCA Native Bob Shell API-key authentication (v50-"):
        skipping_generated_preamble = True
        continue
    if skipping_generated_preamble:
        if line.strip() == "# End BQCA native authentication defaults":
            skipping_generated_preamble = False
        continue
    if re.match(r"^(BOBSHELL_API_KEY|BOB_AUTH_METHOD|BQCA_BOB_AUTH_PREFLIGHT|BQCA_BOB_AUTH_DEBUG|BOB_TEAM_ID)=", line):
        continue
    if any(fragment in line for fragment in managed_comment_fragments):
        continue
    if "session-list preflight" in line:
        continue
    result.append(line)

# Remove every BOB_API_KEY assignment and remember the earliest position.
api_positions = [i for i, line in enumerate(result) if re.match(r"^BOB_API_KEY=", line)]
if api_positions:
    insert_at = api_positions[0]
    result = [line for line in result if not re.match(r"^BOB_API_KEY=", line)]
else:
    insert_at = 0
    for i, line in enumerate(result):
        if line.startswith("BOB_INSTANCE_ID="):
            insert_at = i + 1
            break

# Remove stale generic key-heading comments immediately around the insertion.
while insert_at > 0 and result[insert_at - 1].strip() in {"# Bob API key:", "# Bob Shell 2.x API key:"}:
    result.pop(insert_at - 1)
    insert_at -= 1

managed_block = [
    "",
    "# Bob Shell 2.0.x API key used by BQCA. Keep the live value only in .env.",
    "# BQCA exports the same selected value under BOBSHELL_API_KEY at runtime",
    "# for compatibility. Do not duplicate the secret in this template.",
    'BOB_API_KEY=""',
    "",
    "# Optional team identifier for a general API key. The runtime passes it",
    "# only when the installed Bob CLI advertises --team-id.",
    'BOB_TEAM_ID=""',
]
result[insert_at:insert_at] = managed_block

# Collapse excessive blank lines and remove orphaned legacy headings.
final = []
blank_count = 0
for line in result:
    if line.strip() == "# Bob API key:":
        continue
    if line.strip():
        blank_count = 0
        final.append(line)
    else:
        blank_count += 1
        if blank_count <= 2:
            final.append("")

out.write_text("\n".join(final).lstrip("\n").rstrip() + "\n", encoding="utf-8")
PYENV
  cp "$temporary" "$ENV_EXAMPLE"
  rm -f "$temporary"
  chmod 644 "$ENV_EXAMPLE"
}

write_bob_auth_doc() {
  [[ -e "$BOB_AUTH_MD" ]] || return 0
  cat > "$BOB_AUTH_MD" <<'DOC'
# BQCA Bob Shell 2.0.x Authentication

BQCA uses the project-root `.env` file and the installed Bob CLI's native
environment-key behavior.

```bash
BOB_API_KEY="REPLACE_WITH_YOUR_BOB_API_KEY"
```

At runtime BQCA exports the selected value under both `BOB_API_KEY` and
`BOBSHELL_API_KEY`. This supports Bob distributions and documentation that have
used either name while avoiding duplicate secret values in `.env`.

BQCA does **not** pass `--auth-method` unless a future CLI implementation
explicitly adds and advertises that option. Bob Shell 2.0.0 does not advertise
it. BQCA discovers the actual installed command surface from:

```bash
bob --help
bob chat --help
bob run --help
```

The runtime adapter chooses `bob chat` for interactive work, `bob run` for
non-interactive work, and top-level `-p`/`--resume` as compatibility fallbacks.
Mode, team, workspace, trust, and write-approval flags are used only when the
installed CLI advertises them.

Startup performs a local capability check only. The first actual BQCA request
validates service connectivity and API-key acceptance.

Never print or commit API keys. The patch does not create or overwrite
`~/.bob/token.json` or `~/.bob/config.json`.
DOC
  chmod 644 "$BOB_AUTH_MD"
}

patch_readme() {
  [[ -f "$README_FILE" ]] || return 0
  local temporary
  temporary="$(mktemp)"
  python3 - "$README_FILE" "$temporary" <<'PY'
import pathlib, re, sys
src = pathlib.Path(sys.argv[1])
out = pathlib.Path(sys.argv[2])
text = src.read_text(encoding="utf-8")
text = re.sub(
    r"(?ms)<!-- BQCA-BOB-AUTH-v50-[12]:BEGIN -->.*?<!-- BQCA-BOB-AUTH-v50-[12]:END -->\n?",
    "",
    text,
)
block = '''\n<!-- BQCA-BOB-CLI-v50-3:BEGIN -->\n## Bob Shell 2.0.x CLI compatibility\n\nBQCA uses `BOB_API_KEY` from `.env` and exports the same selected value under\n`BOBSHELL_API_KEY` for distribution compatibility. The runtime does not assume\nthat `--auth-method` exists. It discovers the installed CLI surface through\n`bob --help`, `bob chat --help`, and `bob run --help`.\n\nInteractive work uses `bob chat` when available. Non-interactive work uses\n`bob run` when available and falls back to top-level `-p`. Mode and write\napproval flags are added only when the installed Bob CLI advertises them.\n<!-- BQCA-BOB-CLI-v50-3:END -->\n'''
text = text.rstrip() + "\n" + block
out.write_text(text, encoding="utf-8")
PY
  cp "$temporary" "$README_FILE"
  rm -f "$temporary"
  chmod 644 "$README_FILE"
}

patch_secret_scanners() {
  local file temporary
  for file in "$SECRET_SCANNER" "$DYNAMIC_VALIDATOR"; do
    [[ -f "$file" ]] || continue
    temporary="$(mktemp)"
    python3 - "$file" "$temporary" <<'PY'
import pathlib, sys
src = pathlib.Path(sys.argv[1])
out = pathlib.Path(sys.argv[2])
text = src.read_text(encoding="utf-8")
if '"BOBSHELL_API_KEY"' not in text and '"BOB_API_KEY"' in text:
    text = text.replace('"BOB_API_KEY",', '"BOB_API_KEY",\n    "BOBSHELL_API_KEY",', 1)
text = text.replace('IQP_API_TOKEN|BOB_API_KEY|', 'IQP_API_TOKEN|BOB_API_KEY|BOBSHELL_API_KEY|')
text = text.replace('IQP_API_TOKEN|BOB_API_KEY|IBM_QUANTUM_TOKEN', 'IQP_API_TOKEN|BOB_API_KEY|BOBSHELL_API_KEY|IBM_QUANTUM_TOKEN')
out.write_text(text, encoding="utf-8")
PY
    cp "$temporary" "$file"
    rm -f "$temporary"
    chmod 755 "$file"
  done
}

patch_registry() {
  [[ -f "$REGISTRY" ]] || return 0
  python3 - "$REGISTRY" <<'PY'
import json, pathlib, sys
path = pathlib.Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["repair_patch_path"] = "patches/BQCA/patch-BQCA-v50-3.sh"
data["bob_cli_runtime"] = {
    "patch": "BQCA-v50-3",
    "minimum_supported_major": 2,
    "adapter_path": ".bob/quantum-tools/bqca-bob-cli-v2.sh",
    "primary_api_key_variable": "BOB_API_KEY",
    "compatibility_api_key_variable": "BOBSHELL_API_KEY",
    "auth_method_flag_required": False,
    "command_discovery": ["bob --help", "bob chat --help", "bob run --help"],
    "interactive_preference": "chat",
    "non_interactive_preference": "run",
    "prompt_fallback": "-p",
}
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
  chmod 644 "$REGISTRY"
}

run_mock_smoke_test() {
  local test_root mock_bin log adapter auth
  test_root="$(mktemp -d)"
  mkdir -p "$test_root/bin" "$test_root/root/.bob/quantum-tools"
  mock_bin="$test_root/bin/bob"
  log="$test_root/mock.log"
  adapter="$test_root/root/.bob/quantum-tools/bqca-bob-cli-v2.sh"
  auth="$test_root/root/bob-auth.sh"
  cp "$CLI_ADAPTER" "$adapter"
  cp "$BOB_AUTH_SH" "$auth"
  cat > "$test_root/root/.env" <<'ENV'
BOB_API_KEY="test-key-for-isolated-validation-only"
BOB_INSTANCE_ID="IBM Internal"
BQCA_BOB_AUTH_PREFLIGHT="configure-only"
ENV
  cat > "$mock_bin" <<'MOCK'
#!/usr/bin/env bash
set -Eeuo pipefail
log="${BQCA_MOCK_LOG:?}"
printf 'BOB_API_KEY=%s BOBSHELL_API_KEY=%s ARGS=' \
  "$([[ -n "${BOB_API_KEY:-}" ]] && printf SET || printf MISSING)" \
  "$([[ -n "${BOBSHELL_API_KEY:-}" ]] && printf SET || printf MISSING)" >> "$log"
printf '%q ' "$@" >> "$log"
printf '\n' >> "$log"
case "${1:-}" in
  --version|-v) echo 'IBM Bob Shell 2.0.0'; exit 0 ;;
  --help|-h|'') cat <<'EOF'
Usage: bob [options] [command]
Options:
  -v, --version
  -p, --prompt <prompt>
  -r, --resume [task-id]
  --accept-license
Commands:
  chat [options]
  run [options] [prompt...]
  mcp
EOF
    exit 0 ;;
  chat)
    if [[ "${2:-}" == "--help" ]]; then
      cat <<'EOF'
Usage: bob chat [options]
Options:
  --mode <mode>
  --resume [task-id]
  --trust
  --prompt <prompt>
EOF
      exit 0
    fi
    echo "CHAT_OK"; exit 0 ;;
  run)
    if [[ "${2:-}" == "--help" ]]; then
      cat <<'EOF'
Usage: bob run [options] [prompt...]
Options:
  --mode <mode>
  --workspace <path>
  --yolo
  --team-id <id>
EOF
      exit 0
    fi
    echo "RUN_OK"; exit 0 ;;
esac
if [[ " $* " == *" --resume "* || " $* " == *" -r "* ]]; then echo RESUME_OK; exit 0; fi
if [[ " $* " == *" -p "* ]]; then echo PROMPT_OK; exit 0; fi
exit 0
MOCK
  chmod 755 "$mock_bin" "$adapter" "$auth"
  : > "$log"

  env -u BOB_API_KEY -u BOBSHELL_API_KEY \
    PATH="$test_root/bin:$PATH" \
    BOB_BIN=bob \
    BQCA_MOCK_LOG="$log" \
    bash "$auth" >/dev/null

  PATH="$test_root/bin:$PATH" BOB_BIN=bob BQCA_MOCK_LOG="$log" \
    "$adapter" run --mode ask --prompt 'question' >/dev/null
  PATH="$test_root/bin:$PATH" BOB_BIN=bob BQCA_MOCK_LOG="$log" \
    "$adapter" run --mode code --write --prompt 'create code' >/dev/null
  PATH="$test_root/bin:$PATH" BOB_BIN=bob BQCA_MOCK_LOG="$log" \
    "$adapter" chat --mode code --write --initial-prompt 'start' >/dev/null
  PATH="$test_root/bin:$PATH" BOB_BIN=bob BQCA_MOCK_LOG="$log" \
    "$adapter" resume >/dev/null

  if grep -q -- '--auth-method' "$log"; then
    rm -rf "$test_root"
    return 1
  fi
  grep -q 'BOB_API_KEY=SET BOBSHELL_API_KEY=SET' "$log" || { rm -rf "$test_root"; return 1; }
  grep -q 'run --mode ask' "$log" || { rm -rf "$test_root"; return 1; }
  grep -q 'run --yolo --mode code' "$log" || { rm -rf "$test_root"; return 1; }
  grep -q 'chat --trust --mode code' "$log" || { rm -rf "$test_root"; return 1; }
  grep -q 'chat --resume latest' "$log" || { rm -rf "$test_root"; return 1; }
  rm -rf "$test_root"
}

validate_installation() {
  local failures=0 env_loads launcher marker_count

  for file in "$CLI_ADAPTER" "$BOB_AUTH_SH" "$XLAUNCHPAD"; do
    [[ -x "$file" ]] || { warn "Missing executable: $file"; failures=$((failures + 1)); continue; }
    bash -n "$file" || failures=$((failures + 1))
  done
  for launcher in "${BOB_LAUNCHERS[@]}"; do
    [[ -x "$launcher" ]] || { warn "Launcher is not executable: $launcher"; failures=$((failures + 1)); continue; }
    bash -n "$launcher" || failures=$((failures + 1))
    marker_count="$(grep -c '^# BQCA-BOB-CLI-COMPAT-v50-3:BEGIN$' "$launcher" || true)"
    [[ "$marker_count" -eq 1 ]] || { warn "$launcher has $marker_count v50-3 compatibility blocks"; failures=$((failures + 1)); }
    for needle in \
      'bqca-bob-cli-v2.sh' \
      'quantum_interactive()' \
      'quantum_assist()' \
      'quantum_code()' \
      'quantum_advanced()' \
      'quantum_resume()'; do
      grep -q "$needle" "$launcher" || { warn "$launcher lacks $needle"; failures=$((failures + 1)); }
    done
    if grep -qE -- '--auth-method|--accept-license true|--prompt-interactive|--hide-intermediary-output|--approval-mode|--allowed-tools|--include-directories' "$launcher"; then
      warn "$launcher still contains obsolete active Bob 1.x invocation options"
      failures=$((failures + 1))
    fi
  done

  env_loads="$(grep -c 'source "${SCRIPT_DIR}/.env"' "$XLAUNCHPAD" || true)"
  [[ "$env_loads" -eq 1 ]] || { warn "xLaunchpad loads .env $env_loads times, expected exactly 1"; failures=$((failures + 1)); }
  [[ "$(grep -c '^# BQCA-BOB-AUTH-ENV-v50-3:BEGIN$' "$XLAUNCHPAD" || true)" -eq 1 ]] || {
    warn "xLaunchpad lacks exactly one v50-3 environment block"; failures=$((failures + 1));
  }
  if grep -qE -- '--auth-method|--list-sessions|token\.json|config\.json' "$BOB_AUTH_SH"; then
    warn "bob-auth.sh still contains obsolete authentication behavior"
    failures=$((failures + 1))
  fi
  grep -q 'BOB_API_KEY="$selected_key"' "$BOB_AUTH_SH" || { warn "bob-auth.sh does not export the selected BOB_API_KEY"; failures=$((failures + 1)); }
  grep -q 'capabilities' "$BOB_AUTH_SH" || { warn "bob-auth.sh does not validate local CLI capabilities"; failures=$((failures + 1)); }

  [[ -f "$ENV_EXAMPLE" ]] || { warn ".env.example is missing"; failures=$((failures + 1)); }
  if [[ -f "$ENV_EXAMPLE" ]]; then
    grep -q '^BOB_API_KEY=""$' "$ENV_EXAMPLE" || { warn ".env.example lacks canonical BOB_API_KEY"; failures=$((failures + 1)); }
    if grep -qE '^BOBSHELL_API_KEY=|^BOB_AUTH_METHOD=' "$ENV_EXAMPLE"; then
      warn ".env.example still duplicates the key or declares an unsupported auth method"
      failures=$((failures + 1))
    fi
  fi

  if ! run_mock_smoke_test; then
    warn "isolated Bob 2.0.0 chat/run/API-key smoke test failed"
    failures=$((failures + 1))
  fi

  if [[ -n "$ENV_HASH_BEFORE" && -f "$ENV_FILE" ]]; then
    if [[ "$(sha256sum "$ENV_FILE" | awk '{print $1}')" != "$ENV_HASH_BEFORE" ]]; then
      warn "private .env changed during patch installation"
      failures=$((failures + 1))
    fi
  fi

  if ((failures)); then
    fail "v50-3 validation failed with $failures issue(s)."
  fi
  info "Validation passed: Bob 2.0.x chat/run capability detection, API-key environment compatibility, and every BQCA Bob invocation are active."
}

if ((VALIDATE_ONLY)); then
  validate_installation
  exit 0
fi

create_backup
mkdir -p "$TOOLS_DIR" "$PATCH_RECORD_DIR"
write_cli_adapter
write_bob_auth
patch_xlaunchpad
patch_launchers
patch_env_example
write_bob_auth_doc
patch_readme
patch_secret_scanners
patch_registry

cat > "$PATCH_RECORD_FILE" <<RECORD
Patch: $PATCH_ID
Applied: $(date -u '+%Y-%m-%dT%H:%M:%SZ')
Root: $BQCA_ROOT
Backup: $BACKUP_DIR
Bob CLI target: 2.0.x chat/run command model with runtime capability detection
Primary project key: BOB_API_KEY
Compatibility export: BOBSHELL_API_KEY receives the same selected value
Unsupported authentication flag: --auth-method is never required or passed
Private .env: inspected only by runtime and unchanged by the installer
Active BQCA policy: unchanged
RECORD
chmod 644 "$PATCH_RECORD_FILE"

validate_installation
info "Patch $PATCH_ID applied successfully."
info "Backup: $BACKUP_DIR"
info "Runtime adapter: .bob/quantum-tools/bqca-bob-cli-v2.sh"
info "Private .env changed: no"
