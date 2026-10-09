#!/usr/bin/env bash
set -Eeuo pipefail

#===============================================================================
# IBM Bob Quantum Computing Agent (BQCA)
# Native Bob Shell API-Key Authentication Repair Patch v50-2
# File: patch-BQCA-v50-2.sh
#
# Purpose:
#   Repair the v50-1 authentication integration after Bob Shell 2.x upgrades.
#
#   v50-1 incorrectly failed whenever BOBSHELL_API_KEY and BOB_API_KEY were both
#   present but different. That can happen legitimately when a native Bob Shell
#   inference key coexists with a legacy BQCA variable, or when inherited shell
#   variables differ from the project .env. Its isolated smoke test also
#   inherited the operator's real key variables, causing a false validation
#   failure before the mock Bob CLI created its log.
#
#   v50-2 enforces this deterministic contract:
#
#     1. The project-root .env is authoritative when it defines either key.
#     2. BOBSHELL_API_KEY is the native Bob Shell key and has precedence.
#     3. BOB_API_KEY is used only when BOBSHELL_API_KEY is absent.
#     4. Differing native and legacy keys never cause an automatic failure.
#     5. The legacy key is never overwritten from the native key.
#     6. Every authenticated Bob invocation uses --auth-method api-key.
#     7. Network authentication preflight is opt-in; normal startup configures
#        the native key and lets the first requested Bob operation validate it.
#     8. Validation runs in a sanitized environment and cannot consume or be
#        confused by the operator's real key variables.
#
# Standalone BQCA patch placement:
#   <BQCA-root>/patches/BQCA/patch-BQCA-v50-2.sh
#
# Protected assets:
#   The installer does not read, copy, back up, modify, chmod, remove, or restore:
#     - <BQCA-root>/.env
#     - <BQCA-root>/bob-quantum-designs/
#     - <BQCA-root>/bob-quantum-store/
#     - $HOME/.bob
#     - $HOME/qiskit-v2x-env
#     - $HOME/.qiskit/qiskit-ibm.json
#===============================================================================

PATCH_ID="BQCA-v50-2"
PATCH_FILE_NAME="patch-BQCA-v50-2.sh"
TIMESTAMP="$(date +%Y%m%d%H%M%S)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
TARGET_OVERRIDE=""
DRY_RUN=0
VALIDATE_ONLY=0
ROLLBACK_DIR=""

info() { printf '[BQCA v50-2][INFO] %s\n' "$*"; }
warn() { printf '[BQCA v50-2][WARN] %s\n' "$*" >&2; }
fail() { printf '[BQCA v50-2][ERROR] %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'USAGE'
BQCA Native Bob Shell API-Key Authentication Repair Patch v50-2

Usage:
  ./patch-BQCA-v50-2.sh [options]

Options:
  --target <path>        Explicit standalone BQCA appliance root.
  --dry-run              Display the patch plan without changing files.
  --validate-only        Validate the installed v50-2 authentication integration.
  --rollback <backup>    Restore a v50-2 timestamped backup directory.
  -h, --help             Show this help.

Expected placement:
  <BQCA-root>/patches/BQCA/patch-BQCA-v50-2.sh

The installer never reads or modifies the project-root .env file.
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

for cmd in bash chmod cp date dirname env find grep mkdir mktemp mv python3 rm sha256sum stat; do
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
  find "$candidate" -maxdepth 1 -type f -name 'bob-quantum-v*.sh' -print -quit | grep -q . || return 1
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
XLAUNCHPAD="$BQCA_ROOT/xLaunchpad.sh"
BOB_AUTH_SH="$BQCA_ROOT/bob-auth.sh"
BOB_AUTH_MD="$BQCA_ROOT/bob-auth.md"
ENV_EXAMPLE="$BQCA_ROOT/.env.example"
README_FILE="$BQCA_ROOT/README.md"
SECRET_SCANNER="$TOOLS_DIR/bqca-secret-scan.py"
DYNAMIC_VALIDATOR="$TOOLS_DIR/bqca-dynamic-validator.py"
BACKUP_ROOT="$BOB_ROOT/patch-backups"
BACKUP_DIR="$BACKUP_ROOT/${PATCH_ID}.${TIMESTAMP}"
PATCH_RECORD_DIR="$BOB_ROOT/patches-applied"
PATCH_RECORD_FILE="$PATCH_RECORD_DIR/${PATCH_ID}.txt"
MARKER="BQCA-BOB-NATIVE-API-KEY-v50-2"
POLICY_HASH_BEFORE=""

if [[ -f "$BOB_ROOT/BQCA-PRODUCTION-POLICY.md" ]]; then
  POLICY_HASH_BEFORE="$(sha256sum "$BOB_ROOT/BQCA-PRODUCTION-POLICY.md" | awk '{print $1}')"
fi

backup_file() {
  local source="$1" rel destination
  [[ -e "$source" ]] || return 0
  [[ "$source" != "$BQCA_ROOT/.env" ]] || return 0
  case "$source" in
    "$BQCA_ROOT/bob-quantum-designs"/*|"$BQCA_ROOT/bob-quantum-store"/*) return 0 ;;
  esac
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
  backup_file "$ENV_EXAMPLE"
  backup_file "$README_FILE"
  backup_file "$SECRET_SCANNER"
  backup_file "$DYNAMIC_VALIDATOR"
  backup_file "$PATCH_RECORD_FILE"
  backup_file "$BOB_ROOT/patches-applied/BQCA-v50-1.txt"

  while IFS= read -r -d '' file; do
    backup_file "$file"
  done < <(find "$BQCA_ROOT" -maxdepth 1 -type f -name 'bob-quantum-v*.sh' -print0)

  cat > "$BACKUP_DIR/BQCA-v50-2-backup-manifest.txt" <<MANIFEST
Patch: $PATCH_ID
Created: $(date -u '+%Y-%m-%dT%H:%M:%SZ')
Appliance root: $BQCA_ROOT
Protected and intentionally excluded: .env, workload stores, HOME/.bob, HOME/qiskit-v2x-env, HOME/.qiskit/qiskit-ibm.json
Restore with:
  $PATCH_FILE_NAME --target "$BQCA_ROOT" --rollback "$BACKUP_DIR"
MANIFEST
}

restore_backup() {
  local backup="$1" backup_abs source rel destination
  backup_abs="$(cd "$backup" 2>/dev/null && pwd -P || true)"
  [[ -n "$backup_abs" ]] || fail "Rollback directory not found: $backup"
  [[ -f "$backup_abs/BQCA-v50-2-backup-manifest.txt" ]] || fail "Not a BQCA v50-2 backup: $backup_abs"

  info "Restoring v50-2 backup: $backup_abs"
  while IFS= read -r -d '' source; do
    rel="${source#$backup_abs/}"
    [[ "$rel" != "BQCA-v50-2-backup-manifest.txt" ]] || continue
    destination="$BQCA_ROOT/$rel"
    mkdir -p "$(dirname "$destination")"
    cp -a "$source" "$destination"
  done < <(find "$backup_abs" -mindepth 1 -type f -print0)

  rel="${PATCH_RECORD_FILE#$BQCA_ROOT/}"
  [[ -e "$backup_abs/$rel" ]] || rm -f "$PATCH_RECORD_FILE"

  info "Rollback complete. Protected assets were not touched."
}

if [[ -n "$ROLLBACK_DIR" ]]; then
  restore_backup "$ROLLBACK_DIR"
  exit 0
fi

info "Resolved BQCA root: $BQCA_ROOT"
info "Patch identity: $PATCH_ID"
info "Authentication target: native Bob Shell API-key method with deterministic key precedence"
info "Standalone patch location: patches/BQCA/$PATCH_FILE_NAME"
info "Protected assets: .env, workload stores, HOME/.bob, qiskit-v2x-env, and qiskit-ibm.json"

if ((DRY_RUN)); then
  cat <<'DRY'
[BQCA v50-2][DRY-RUN] Planned changes:
  1. Replace the v50-1 strict key-equality rule with native-key precedence.
  2. Use BOBSHELL_API_KEY when present; otherwise map legacy BOB_API_KEY.
  3. Never overwrite BOB_API_KEY from BOBSHELL_API_KEY.
  4. Make project .env key values authoritative over inherited shell values.
  5. Keep --auth-method api-key on every authenticated Bob invocation.
  6. Make network preflight opt-in; normal startup performs configuration-only validation.
  7. Sanitize inherited key variables during patch smoke tests.
  8. Update .env.example and authentication documentation without modifying .env.
  9. Preserve the active BQCA policy, modes, rules, skills, Qiskit workflows, and workload artifacts.
DRY
  exit 0
fi

write_bob_auth() {
  cat > "$BOB_AUTH_SH" <<'AUTH'
#!/usr/bin/env bash
set -Eeuo pipefail

#===============================================================================
# IBM Bob Quantum Computing Agent (BQCA)
# Native Bob Shell API-Key Authentication
# Managed by patch-BQCA-v50-2.sh
#
# Native contract:
#   export BOBSHELL_API_KEY="..."
#   bob --auth-method api-key ...
#
# Compatibility:
#   BOB_API_KEY is accepted only when BOBSHELL_API_KEY is absent.
#   When both are present and differ, BOBSHELL_API_KEY wins. The legacy value is
#   left unchanged because it may belong to an older operator workflow.
#
# This script never creates or overwrites ~/.bob/token.json or ~/.bob/config.json.
#===============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ENV_FILE="$SCRIPT_DIR/.env"
TLS_CONTROL_FILE="$SCRIPT_DIR/tls-control.sh"
CYAN="${CYAN:-}"
YELLOW="${YELLOW:-}"
RESET="${RESET:-}"

[[ -f "$ENV_FILE" ]] || {
  printf 'Bob Shell Authentication Failed: missing environment file: %s\n' "$ENV_FILE" >&2
  exit 1
}

# The project .env is authoritative when it defines either supported key. If it
# defines neither key, inherited shell values remain available as a fallback.
_BQCA_INHERITED_BOBSHELL_API_KEY="${BOBSHELL_API_KEY-}"
_BQCA_INHERITED_BOB_API_KEY="${BOB_API_KEY-}"
unset BOBSHELL_API_KEY BOB_API_KEY
set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a
if [[ -z "${BOBSHELL_API_KEY:-}" && -z "${BOB_API_KEY:-}" ]]; then
  [[ -z "$_BQCA_INHERITED_BOBSHELL_API_KEY" ]] || BOBSHELL_API_KEY="$_BQCA_INHERITED_BOBSHELL_API_KEY"
  [[ -z "$_BQCA_INHERITED_BOB_API_KEY" ]] || BOB_API_KEY="$_BQCA_INHERITED_BOB_API_KEY"
fi
unset _BQCA_INHERITED_BOBSHELL_API_KEY _BQCA_INHERITED_BOB_API_KEY

if [[ -n "${BOBSHELL_API_KEY:-}" ]]; then
  BQCA_BOB_KEY_SOURCE="BOBSHELL_API_KEY"
elif [[ -n "${BOB_API_KEY:-}" ]]; then
  BOBSHELL_API_KEY="$BOB_API_KEY"
  BQCA_BOB_KEY_SOURCE="BOB_API_KEY_COMPATIBILITY_ALIAS"
else
  printf 'Bob Shell Authentication Failed: set BOBSHELL_API_KEY in .env; BOB_API_KEY is accepted as a legacy alias.\n' >&2
  exit 1
fi

# A differing legacy value is not an error. Native Bob Shell always consumes
# BOBSHELL_API_KEY. Never print either value.
if [[ -n "${BOB_API_KEY:-}" && "$BOBSHELL_API_KEY" != "$BOB_API_KEY" && "${BQCA_BOB_AUTH_DEBUG:-0}" == "1" ]]; then
  printf '%b\n' "${YELLOW}BQCA authentication note: native BOBSHELL_API_KEY takes precedence over the differing legacy BOB_API_KEY.${RESET}" >&2
fi

BOB_AUTH_METHOD="api-key"
BOB_BIN="${BOB_BIN:-bob}"
export BOBSHELL_API_KEY BOB_AUTH_METHOD BOB_BIN BQCA_BOB_KEY_SOURCE

[[ -z "${BOB_ENDPOINT:-}" ]] || export BOB_ENDPOINT
[[ -z "${BOB_AUTH_ENDPOINT:-}" ]] || export BOB_AUTH_ENDPOINT
[[ -z "${BOB_REGION:-}" ]] || export BOB_REGION

command -v "$BOB_BIN" >/dev/null 2>&1 || {
  printf 'Bob Shell Authentication Failed: Bob CLI command not found: %s\n' "$BOB_BIN" >&2
  exit 1
}

bob_help="$("$BOB_BIN" --help 2>&1 || true)"
if ! grep -q -- '--auth-method' <<<"$bob_help"; then
  printf 'Bob Shell Authentication Failed: this Bob CLI does not advertise --auth-method.\n' >&2
  printf 'Installed Bob version: %s\n' "$("$BOB_BIN" --version 2>&1 | head -n 1)" >&2
  exit 2
fi

AUTH_ARGS=(--auth-method api-key)
if [[ -n "${BOB_TEAM_ID:-}" ]]; then
  if grep -q -- '--team-id' <<<"$bob_help"; then
    AUTH_ARGS+=(--team-id "$BOB_TEAM_ID")
  elif [[ "${BQCA_BOB_AUTH_DEBUG:-0}" == "1" ]]; then
    printf 'BQCA authentication note: BOB_TEAM_ID is set, but this Bob CLI does not advertise --team-id; continuing without it.\n' >&2
  fi
fi

# The default is configuration-only. This avoids blocking BQCA startup on an
# undocumented or version-sensitive session-list operation. The first normal
# BQCA request performs the real service authentication.
BQCA_BOB_AUTH_PREFLIGHT="${BQCA_BOB_AUTH_PREFLIGHT:-configure-only}"
case "$BQCA_BOB_AUTH_PREFLIGHT" in
  off|skip|false|0|auto|configure-only|defer)
    printf '%b\n' "${CYAN}Bob Shell native API-key authentication configured; the first BQCA request will validate connectivity.${RESET}"
    ;;
  sessions|required)
    if ! grep -q -- '--list-sessions' <<<"$bob_help"; then
      printf 'Bob Shell Authentication Failed: --list-sessions is unavailable for the explicitly requested session preflight.\n' >&2
      exit 2
    fi
    auth_error="$(mktemp "${TMPDIR:-/tmp}/bqca-bob-auth.XXXXXX")"
    if "$BOB_BIN" "${AUTH_ARGS[@]}" --accept-license --list-sessions >/dev/null 2>"$auth_error"; then
      rm -f "$auth_error"
      printf '%b\n' "${CYAN}Bob Shell Authenticated Successfully with the native API-key method!${RESET}"
    else
      status=$?
      printf 'Bob Shell Authentication Failed: the explicitly requested native API-key session preflight was rejected.\n' >&2
      printf 'Verify BOBSHELL_API_KEY, key scope/team selection, proxy, and TLS settings.\n' >&2
      if [[ "${BQCA_BOB_AUTH_DEBUG:-0}" == "1" ]]; then
        sed -E 's/[A-Za-z0-9._~+\/=:-]{24,}/[REDACTED]/g' "$auth_error" >&2 || true
      fi
      rm -f "$auth_error"
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
  local tmp
  tmp="$(mktemp)"
  python3 - "$XLAUNCHPAD" "$tmp" <<'PY'
from __future__ import annotations

import pathlib
import re
import sys

src = pathlib.Path(sys.argv[1])
out = pathlib.Path(sys.argv[2])
text = src.read_text(encoding="utf-8")

# Remove earlier native-auth blocks.
text = re.sub(
    r"(?ms)^# BQCA-BOB-NATIVE-API-KEY-v50-[12]:BEGIN\n.*?^# BQCA-BOB-NATIVE-API-KEY-v50-[12]:END\n?",
    "",
    text,
)

# API-key mode does not use the browser-auth helper.
text = re.sub(r"(?m)^\s*chmod\s+777\s+configure-bob-auth-browser\.sh\s*\n", "", text)
text = re.sub(r"(?m)^\s*source\s+(?:\"?\$\{?SCRIPT_DIR\}?/?\"?)?configure-bob-auth-browser\.sh\s*\n", "", text)
text = re.sub(r"(?m)^\s*source\s+configure-bob-auth-browser\.sh\s*\n", "", text)

# Normalize all canonical project .env blocks to one authoritative block.
env_pattern = re.compile(
    r"(?ms)^set -a\n(?:# shellcheck[^\n]*\n)?source \"\$\{SCRIPT_DIR\}/\.env\"\nset \+a\n"
)
matches = list(env_pattern.finditer(text))
for match in reversed(matches):
    text = text[: match.start()] + text[match.end() :]

script_dir_match = re.search(r'(?m)^SCRIPT_DIR="\$\(cd "\$\(dirname "\$\{BASH_SOURCE\[0\]\}"\)" && pwd(?: -P)?\)"\s*$', text)
if not script_dir_match:
    raise SystemExit("Unable to locate SCRIPT_DIR assignment in xLaunchpad.sh")

block = r'''
# BQCA-BOB-NATIVE-API-KEY-v50-2:BEGIN
# Load the project environment once. For Bob API-key variables, values defined
# by the project .env take precedence over inherited shell values.
_BQCA_INHERITED_BOBSHELL_API_KEY="${BOBSHELL_API_KEY-}"
_BQCA_INHERITED_BOB_API_KEY="${BOB_API_KEY-}"
unset BOBSHELL_API_KEY BOB_API_KEY
set -a
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/.env"
set +a
if [[ -z "${BOBSHELL_API_KEY:-}" && -z "${BOB_API_KEY:-}" ]]; then
  [[ -z "${_BQCA_INHERITED_BOBSHELL_API_KEY}" ]] || BOBSHELL_API_KEY="${_BQCA_INHERITED_BOBSHELL_API_KEY}"
  [[ -z "${_BQCA_INHERITED_BOB_API_KEY}" ]] || BOB_API_KEY="${_BQCA_INHERITED_BOB_API_KEY}"
fi
unset _BQCA_INHERITED_BOBSHELL_API_KEY _BQCA_INHERITED_BOB_API_KEY

if [[ -z "${BOBSHELL_API_KEY:-}" && -n "${BOB_API_KEY:-}" ]]; then
  BOBSHELL_API_KEY="${BOB_API_KEY}"
fi
: "${BOBSHELL_API_KEY:?BOBSHELL_API_KEY is not set in .env; BOB_API_KEY is accepted as a legacy alias}"
BOB_AUTH_METHOD="api-key"
export BOBSHELL_API_KEY BOB_AUTH_METHOD
# When both key variables differ, native BOBSHELL_API_KEY wins. BOB_API_KEY is
# left unchanged and is never copied from the native key.
# BQCA-BOB-NATIVE-API-KEY-v50-2:END
'''
# Preserve the BQCA-49 filename synchronizer and v50 permission guard as the
# earlier runtime safety steps. Insert authentication only after SCRIPT_DIR has
# been defined and after those blocks when they exist.
anchor_patterns = [
    r"(?ms)^# BQCA-CRITICAL-PERMISSION-GUARD-v50:BEGIN\n.*?^# BQCA-CRITICAL-PERMISSION-GUARD-v50:END\s*$",
    r"(?ms)^# BQCA-ROOT-FILENAME-VERSION-SYNC-49:BEGIN\n.*?^# BQCA-ROOT-FILENAME-VERSION-SYNC-49:END\s*$",
]
insert_at = script_dir_match.end()
for pattern in anchor_patterns:
    match = re.search(pattern, text)
    if match:
        insert_at = max(insert_at, match.end())
text = text[:insert_at] + "\n\n" + block + text[insert_at:]

text = re.sub(
    r': "\$\{BOB_API_KEY:\?BOB_API_KEY is not set in the \.env\}"',
    ': "${BOBSHELL_API_KEY:?BOBSHELL_API_KEY is not set in the .env}"',
    text,
)
text = re.sub(
    r': "\$\{BOBSHELL_API_KEY:\?BOBSHELL_API_KEY is not set in \.env \(BOB_API_KEY is accepted as a legacy alias\)\}"',
    ': "${BOBSHELL_API_KEY:?BOBSHELL_API_KEY is not set in .env; BOB_API_KEY is accepted as a legacy alias}"',
    text,
)

out.write_text(text, encoding="utf-8")
PY
  cp "$tmp" "$XLAUNCHPAD"
  rm -f "$tmp"
  chmod 755 "$XLAUNCHPAD"
}

patch_launchers() {
  local file tmp
  while IFS= read -r -d '' file; do
    tmp="$(mktemp)"
    python3 - "$file" "$tmp" <<'PY'
from __future__ import annotations

import pathlib
import re
import sys

src = pathlib.Path(sys.argv[1])
out = pathlib.Path(sys.argv[2])
text = src.read_text(encoding="utf-8")

text = re.sub(
    r"(?ms)^# BQCA-BOB-NATIVE-API-KEY-v50-[12]:BEGIN\n.*?^# BQCA-BOB-NATIVE-API-KEY-v50-[12]:END\n?",
    "",
    text,
)

# Make direct launcher execution use the same project-environment precedence.
env_pattern = re.compile(
    r"(?ms)^set -a\n(?:# shellcheck[^\n]*\n)?source \"\$\{SCRIPT_DIR\}/\.env\"\nset \+a\n"
)
text = re.sub(
    r"(?ms)^# BQCA-BOB-AUTH-ENV-v50-2:BEGIN\n.*?^# BQCA-BOB-AUTH-ENV-v50-2:END\n?",
    "",
    text,
)
for match in reversed(list(env_pattern.finditer(text))):
    text = text[:match.start()] + text[match.end():]

env_block = r'''# BQCA-BOB-AUTH-ENV-v50-2:BEGIN
_BQCA_INHERITED_BOBSHELL_API_KEY="${BOBSHELL_API_KEY-}"
_BQCA_INHERITED_BOB_API_KEY="${BOB_API_KEY-}"
unset BOBSHELL_API_KEY BOB_API_KEY
set -a
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/.env"
set +a
if [[ -z "${BOBSHELL_API_KEY:-}" && -z "${BOB_API_KEY:-}" ]]; then
  [[ -z "${_BQCA_INHERITED_BOBSHELL_API_KEY}" ]] || BOBSHELL_API_KEY="${_BQCA_INHERITED_BOBSHELL_API_KEY}"
  [[ -z "${_BQCA_INHERITED_BOB_API_KEY}" ]] || BOB_API_KEY="${_BQCA_INHERITED_BOB_API_KEY}"
fi
unset _BQCA_INHERITED_BOBSHELL_API_KEY _BQCA_INHERITED_BOB_API_KEY
# BQCA-BOB-AUTH-ENV-v50-2:END
'''
tls_match = re.search(r'(?m)^source "\$\{SCRIPT_DIR\}/tls-control\.sh"\s*$', text)
if not tls_match:
    raise SystemExit(f"Unable to locate TLS source boundary in {src}")
text = text[:tls_match.end()] + "\n\n" + env_block + text[tls_match.end():]

# Convert unwrapped Bob calls. Specific prompt calls are converted first.
text = re.sub(
    r'^([ \t]*)"\$\{BOB_BIN\}" "\$\{prompt\}" \\\n',
    r'\1bqca_bob_native \\\n\1  -p "${prompt}" \\\n',
    text,
    flags=re.M,
)
text = re.sub(
    r'^([ \t]*)"\$\{BOB_BIN\}" \\\n',
    r'\1bqca_bob_native \\\n',
    text,
    flags=re.M,
)
text = text.replace("--accept-license true \\\n", "--accept-license \\\n")

needle = 'BOB_BIN="${BOB_BIN:-bob}"\n'
if needle not in text:
    raise SystemExit(f"Unable to locate BOB_BIN assignment in {src}")

block = r'''# BQCA-BOB-NATIVE-API-KEY-v50-2:BEGIN
# Native Bob Shell API-key authentication. BOBSHELL_API_KEY has precedence;
# legacy BOB_API_KEY is consulted only when the native key is absent.
if [[ -z "${BOBSHELL_API_KEY:-}" && -n "${BOB_API_KEY:-}" ]]; then
  BOBSHELL_API_KEY="${BOB_API_KEY}"
fi
: "${BOBSHELL_API_KEY:?BOBSHELL_API_KEY is required for BQCA Bob Shell execution}"
BOB_AUTH_METHOD="api-key"
export BOBSHELL_API_KEY BOB_AUTH_METHOD
BQCA_BOB_NATIVE_AUTH_ARGS=(--auth-method "${BOB_AUTH_METHOD}")
_BQCA_BOB_HELP="$("${BOB_BIN}" --help 2>&1 || true)"
if ! grep -q -- '--auth-method' <<<"${_BQCA_BOB_HELP}"; then
  printf '[BQCA v50-2][ERROR] Installed Bob CLI does not advertise --auth-method.\n' >&2
  exit 2
fi
if [[ -n "${BOB_TEAM_ID:-}" && "${_BQCA_BOB_HELP}" == *"--team-id"* ]]; then
  BQCA_BOB_NATIVE_AUTH_ARGS+=(--team-id "${BOB_TEAM_ID}")
fi
unset _BQCA_BOB_HELP
bqca_bob_native() {
  "${BOB_BIN}" "${BQCA_BOB_NATIVE_AUTH_ARGS[@]}" "$@"
}
# BQCA-BOB-NATIVE-API-KEY-v50-2:END
'''
text = text.replace(needle, needle + block + "\n", 1)

out.write_text(text, encoding="utf-8")
PY
    cp "$tmp" "$file"
    rm -f "$tmp"
    chmod 755 "$file"
  done < <(find "$BQCA_ROOT" -maxdepth 1 -type f -name 'bob-quantum-v*.sh' -print0)
}

patch_env_example() {
  [[ -f "$ENV_EXAMPLE" ]] || return 0
  local tmp
  tmp="$(mktemp)"
  python3 - "$ENV_EXAMPLE" "$tmp" <<'PY'
import pathlib
import re
import sys

src = pathlib.Path(sys.argv[1])
out = pathlib.Path(sys.argv[2])
text = src.read_text(encoding="utf-8")

# Remove a previous v50 auth documentation block if present.
text = re.sub(
    r"(?ms)^# BQCA Native Bob Shell API-key authentication.*?^# End BQCA native authentication defaults\n?",
    "",
    text,
)

block = '''# BQCA Native Bob Shell API-key authentication (v50-2)
# Preferred Bob Shell 2.x key. This value has precedence when both variables
# are present. Never commit a live key.
BOBSHELL_API_KEY=""

# Legacy BQCA input alias. Used only when BOBSHELL_API_KEY is empty.
# It may differ from BOBSHELL_API_KEY; differing values are not an error.
BOB_API_KEY=""

BOB_AUTH_METHOD="api-key"
# configure-only/auto/off: no network preflight; first BQCA request validates.
# sessions/required: explicitly run Bob's session-list preflight when supported.
BQCA_BOB_AUTH_PREFLIGHT="configure-only"
BQCA_BOB_AUTH_DEBUG="0"
# Optional for general API keys when the installed Bob CLI supports --team-id.
BOB_TEAM_ID=""
# End BQCA native authentication defaults

'''

# Remove older individual declarations to avoid duplicates.
text = re.sub(r'(?m)^BOBSHELL_API_KEY=".*"\s*\n?', '', text)
text = re.sub(r'(?m)^BOB_AUTH_METHOD=".*"\s*\n?', '', text)
text = re.sub(r'(?m)^BQCA_BOB_AUTH_PREFLIGHT=".*"\s*\n?', '', text)
text = re.sub(r'(?m)^BQCA_BOB_AUTH_DEBUG=".*"\s*\n?', '', text)
text = re.sub(r'(?m)^BOB_TEAM_ID=".*"\s*\n?', '', text)

legacy = re.search(r'(?m)^BOB_API_KEY=".*"\s*$', text)
if legacy:
    text = text[:legacy.start()] + block + text[legacy.end():]
else:
    text = block + text

out.write_text(text, encoding="utf-8")
PY
  cp "$tmp" "$ENV_EXAMPLE"
  rm -f "$tmp"
  chmod 644 "$ENV_EXAMPLE"
}

patch_docs() {
  if [[ -f "$BOB_AUTH_MD" ]]; then
    cat > "$BOB_AUTH_MD" <<'DOC'
# BQCA Bob Shell Native API-Key Authentication

BQCA uses Bob Shell's native API-key flow:

```bash
export BOBSHELL_API_KEY="your-inference-api-key"
bob --auth-method api-key -p "Explain this project"
```

## Key precedence

1. `BOBSHELL_API_KEY` is the native Bob Shell key and always wins when present.
2. `BOB_API_KEY` is accepted only when `BOBSHELL_API_KEY` is absent.
3. The two variables may legitimately differ. BQCA does not compare or print
   their values and never copies the native key back into the legacy variable.
4. Values defined in the project-root `.env` take precedence over inherited
   shell values. If `.env` defines neither key, inherited values are used.

## Preflight behavior

The default is:

```bash
BQCA_BOB_AUTH_PREFLIGHT="configure-only"
```

This verifies local configuration and lets the first requested Bob operation
perform service authentication. It avoids blocking startup on version-sensitive
session-list behavior.

An operator can explicitly request the session-list preflight with:

```bash
BQCA_BOB_AUTH_PREFLIGHT="sessions"
```

## Security

- Never print or commit `BOBSHELL_API_KEY` or `BOB_API_KEY`.
- BQCA does not create or overwrite `~/.bob/token.json` or `~/.bob/config.json`.
- The private project `.env` remains operator-managed and is never changed by
  the authentication patch installer.
DOC
    chmod 644 "$BOB_AUTH_MD"
  fi

  if [[ -f "$README_FILE" ]]; then
    local tmp
    tmp="$(mktemp)"
    python3 - "$README_FILE" "$tmp" <<'PY'
import pathlib
import re
import sys

src = pathlib.Path(sys.argv[1])
out = pathlib.Path(sys.argv[2])
text = src.read_text(encoding="utf-8")
text = re.sub(
    r"(?ms)<!-- BQCA-BOB-AUTH-v50-[12]:BEGIN -->.*?<!-- BQCA-BOB-AUTH-v50-[12]:END -->\n?",
    "",
    text,
)
block = '''
<!-- BQCA-BOB-AUTH-v50-2:BEGIN -->
## Bob Shell 2.x API-key authentication

BQCA uses `BOBSHELL_API_KEY` with `--auth-method api-key`. The legacy
`BOB_API_KEY` variable is used only when the native variable is absent. If both
variables are present and differ, `BOBSHELL_API_KEY` takes precedence; startup
must not fail merely because the legacy value differs. Network preflight is
configuration-only by default, and the first requested Bob operation validates
service connectivity.
<!-- BQCA-BOB-AUTH-v50-2:END -->
'''
out.write_text(text.rstrip() + "\n" + block, encoding="utf-8")
PY
    cp "$tmp" "$README_FILE"
    rm -f "$tmp"
    chmod 644 "$README_FILE"
  fi
}

patch_secret_scanners() {
  local file tmp
  for file in "$SECRET_SCANNER" "$DYNAMIC_VALIDATOR"; do
    [[ -f "$file" ]] || continue
    tmp="$(mktemp)"
    python3 - "$file" "$tmp" <<'PY'
import pathlib
import sys

src = pathlib.Path(sys.argv[1])
out = pathlib.Path(sys.argv[2])
text = src.read_text(encoding="utf-8")
if "BOBSHELL_API_KEY" not in text:
    text = text.replace('"BOB_API_KEY",', '"BOBSHELL_API_KEY",\n    "BOB_API_KEY",', 1)
    text = text.replace('IQP_API_TOKEN|BOB_API_KEY|', 'IQP_API_TOKEN|BOBSHELL_API_KEY|BOB_API_KEY|')
    text = text.replace('IQP_API_TOKEN|BOB_API_KEY|IBM_QUANTUM_TOKEN', 'IQP_API_TOKEN|BOBSHELL_API_KEY|BOB_API_KEY|IBM_QUANTUM_TOKEN')
out.write_text(text, encoding="utf-8")
PY
    cp "$tmp" "$file"
    rm -f "$tmp"
    chmod 755 "$file"
  done
}

run_mock_auth_test() {
  local test_root mock_bin log
  test_root="$(mktemp -d)"
  mock_bin="$test_root/mock-bob"
  log="$test_root/mock.log"
  mkdir -p "$test_root/home"

  cp "$BOB_AUTH_SH" "$test_root/bob-auth.sh"
  cat > "$test_root/tls-control.sh" <<'TLS'
#!/usr/bin/env bash
true
TLS
  cat > "$mock_bin" <<'MOCK'
#!/usr/bin/env bash
set -Eeuo pipefail
if [[ "${1:-}" == "--help" ]]; then
  cat <<'HELP'
Usage: bob [options]
  --auth-method <method>
  --accept-license
  --list-sessions
  --team-id <id>
HELP
  exit 0
fi
if [[ "${1:-}" == "--version" ]]; then
  echo "IBM Bob Shell version 2.0.0"
  exit 0
fi
printf 'ARGS=' >> "${BQCA_MOCK_LOG}"
printf '%q ' "$@" >> "${BQCA_MOCK_LOG}"
printf '\nKEY_SET=%s\n' "$([[ -n "${BOBSHELL_API_KEY:-}" ]] && printf YES || printf NO)" >> "${BQCA_MOCK_LOG}"
[[ " $* " == *" --auth-method api-key "* ]] || exit 41
[[ " $* " == *" --accept-license "* ]] || exit 42
[[ " $* " == *" --list-sessions "* ]] || exit 43
[[ -n "${BOBSHELL_API_KEY:-}" ]] || exit 44
exit 0
MOCK
  chmod 755 "$mock_bin" "$test_root/bob-auth.sh" "$test_root/tls-control.sh"

  # Case 1: project .env has only the legacy alias while the parent environment
  # contains two different keys. Project .env must win and validation must pass.
  cat > "$test_root/.env" <<ENV
BOB_API_KEY="project-legacy-key-123456789"
BOB_BIN="$mock_bin"
BQCA_BOB_AUTH_PREFLIGHT="sessions"
ENV
  : > "$log"
  env \
    HOME="$test_root/home" \
    BQCA_MOCK_LOG="$log" \
    BOBSHELL_API_KEY="inherited-native-key-123456789" \
    BOB_API_KEY="inherited-legacy-key-987654321" \
    bash "$test_root/bob-auth.sh" >/dev/null
  grep -q 'KEY_SET=YES' "$log" || { rm -rf "$test_root"; return 1; }
  grep -q -- '--auth-method api-key' "$log" || { rm -rf "$test_root"; return 1; }

  # Case 2: the project .env intentionally contains two different values. The
  # native key must take precedence without an equality failure.
  cat > "$test_root/.env" <<ENV
BOBSHELL_API_KEY="project-native-key-123456789"
BOB_API_KEY="project-legacy-key-987654321"
BOB_BIN="$mock_bin"
BQCA_BOB_AUTH_PREFLIGHT="sessions"
ENV
  : > "$log"
  env -u BOBSHELL_API_KEY -u BOB_API_KEY \
    HOME="$test_root/home" \
    BQCA_MOCK_LOG="$log" \
    bash "$test_root/bob-auth.sh" >/dev/null
  grep -q 'KEY_SET=YES' "$log" || { rm -rf "$test_root"; return 1; }

  # Case 3: native-only configuration.
  cat > "$test_root/.env" <<ENV
BOBSHELL_API_KEY="project-native-key-only-123456789"
BOB_BIN="$mock_bin"
BQCA_BOB_AUTH_PREFLIGHT="sessions"
ENV
  : > "$log"
  env -u BOBSHELL_API_KEY -u BOB_API_KEY \
    HOME="$test_root/home" \
    BQCA_MOCK_LOG="$log" \
    bash "$test_root/bob-auth.sh" >/dev/null
  grep -q 'KEY_SET=YES' "$log" || { rm -rf "$test_root"; return 1; }

  [[ ! -e "$test_root/home/.bob/token.json" ]] || { rm -rf "$test_root"; return 1; }
  [[ ! -e "$test_root/home/.bob/config.json" ]] || { rm -rf "$test_root"; return 1; }
  rm -rf "$test_root"
}

validate_installation() {
  local failures=0 file marker_count launcher_count direct_calls env_loads script_dir_line auth_marker_line

  bash -n "$XLAUNCHPAD" || failures=$((failures + 1))
  bash -n "$BOB_AUTH_SH" || failures=$((failures + 1))

  marker_count="$(grep -c 'BQCA-BOB-NATIVE-API-KEY-v50-2:BEGIN' "$XLAUNCHPAD" || true)"
  [[ "$marker_count" -eq 1 ]] || { warn "xLaunchpad v50-2 marker count is $marker_count, expected 1"; failures=$((failures + 1)); }

  env_loads="$(grep -c 'source "${SCRIPT_DIR}/.env"' "$XLAUNCHPAD" || true)"
  [[ "$env_loads" -eq 1 ]] || { warn "xLaunchpad loads .env $env_loads times, expected exactly 1"; failures=$((failures + 1)); }

  script_dir_line="$(grep -n '^SCRIPT_DIR=' "$XLAUNCHPAD" | head -n1 | cut -d: -f1 || true)"
  auth_marker_line="$(grep -n 'BQCA-BOB-NATIVE-API-KEY-v50-2:BEGIN' "$XLAUNCHPAD" | head -n1 | cut -d: -f1 || true)"
  if [[ -z "$script_dir_line" || -z "$auth_marker_line" || "$auth_marker_line" -le "$script_dir_line" ]]; then
    warn "xLaunchpad authentication block appears before SCRIPT_DIR is defined"
    failures=$((failures + 1))
  fi

  if grep -q 'both set but do not match' "$XLAUNCHPAD" "$BOB_AUTH_SH"; then
    warn "strict native/legacy key-equality failure remains"
    failures=$((failures + 1))
  fi
  if grep -q 'BOB_API_KEY="\$BOBSHELL_API_KEY"\|BOB_API_KEY="\${BOBSHELL_API_KEY}"' "$XLAUNCHPAD" "$BOB_AUTH_SH"; then
    warn "native key is still copied back into the legacy variable"
    failures=$((failures + 1))
  fi

  grep -q 'BOBSHELL_API_KEY' "$XLAUNCHPAD" || { warn "xLaunchpad lacks BOBSHELL_API_KEY"; failures=$((failures + 1)); }
  grep -q -- '--auth-method' "$BOB_AUTH_SH" || { warn "bob-auth.sh lacks --auth-method"; failures=$((failures + 1)); }
  grep -q 'configure-only' "$BOB_AUTH_SH" || { warn "bob-auth.sh lacks non-blocking default preflight"; failures=$((failures + 1)); }

  launcher_count=0
  while IFS= read -r -d '' file; do
    launcher_count=$((launcher_count + 1))
    bash -n "$file" || failures=$((failures + 1))
    marker_count="$(grep -c 'BQCA-BOB-NATIVE-API-KEY-v50-2:BEGIN' "$file" || true)"
    [[ "$marker_count" -eq 1 ]] || { warn "$file v50-2 marker count is $marker_count, expected 1"; failures=$((failures + 1)); }
    grep -q 'bqca_bob_native' "$file" || { warn "$file lacks native Bob wrapper"; failures=$((failures + 1)); }
    grep -q -- '--auth-method' "$file" || { warn "$file lacks --auth-method integration"; failures=$((failures + 1)); }
    if grep -q 'both set but do not match' "$file"; then
      warn "$file retains strict key-equality failure"
      failures=$((failures + 1))
    fi
    direct_calls="$(grep -Ec '^[[:space:]]*"?\$\{?BOB_BIN\}?"?[[:space:]]+"?\$\{?prompt\}?"?[[:space:]]*\\|^[[:space:]]*"?\$\{?BOB_BIN\}?"?[[:space:]]*\\' "$file" || true)"
    [[ "$direct_calls" -eq 0 ]] || { warn "$file retains $direct_calls unwrapped Bob invocation(s)"; failures=$((failures + 1)); }
  done < <(find "$BQCA_ROOT" -maxdepth 1 -type f -name 'bob-quantum-v*.sh' -print0)
  [[ "$launcher_count" -ge 1 ]] || { warn "no versioned BQCA launcher found"; failures=$((failures + 1)); }

  [[ -f "$ENV_EXAMPLE" ]] && grep -q 'BOBSHELL_API_KEY=' "$ENV_EXAMPLE" || { warn ".env.example lacks BOBSHELL_API_KEY"; failures=$((failures + 1)); }
  [[ -f "$BOB_AUTH_MD" ]] && grep -q 'native Bob Shell key and always wins' "$BOB_AUTH_MD" || { warn "bob-auth.md lacks v50-2 precedence guidance"; failures=$((failures + 1)); }

  if [[ -f "$SECRET_SCANNER" ]]; then
    python3 -m py_compile "$SECRET_SCANNER" || failures=$((failures + 1))
    grep -q 'BOBSHELL_API_KEY' "$SECRET_SCANNER" || { warn "secret scanner does not protect BOBSHELL_API_KEY"; failures=$((failures + 1)); }
  fi
  if [[ -f "$DYNAMIC_VALIDATOR" ]]; then
    python3 -m py_compile "$DYNAMIC_VALIDATOR" || failures=$((failures + 1))
    grep -q 'BOBSHELL_API_KEY' "$DYNAMIC_VALIDATOR" || { warn "dynamic validator does not protect BOBSHELL_API_KEY"; failures=$((failures + 1)); }
  fi

  run_mock_auth_test || { warn "sanitized native API-key authentication smoke test failed"; failures=$((failures + 1)); }

  if [[ -n "$POLICY_HASH_BEFORE" && -f "$BOB_ROOT/BQCA-PRODUCTION-POLICY.md" ]]; then
    current_hash="$(sha256sum "$BOB_ROOT/BQCA-PRODUCTION-POLICY.md" | awk '{print $1}')"
    [[ "$current_hash" == "$POLICY_HASH_BEFORE" ]] || { warn "active BQCA policy content changed"; failures=$((failures + 1)); }
  fi

  if ((failures)); then
    fail "v50-2 validation failed with $failures issue(s)."
  fi

  info "Validation passed: BOBSHELL_API_KEY precedence, legacy fallback, sanitized tests, and native API-key invocation are active."
}

if ((VALIDATE_ONLY)); then
  validate_installation
  exit 0
fi

create_backup
mkdir -p "$PATCH_RECORD_DIR"
write_bob_auth
patch_xlaunchpad
patch_launchers
patch_env_example
patch_docs
patch_secret_scanners

cat > "$PATCH_RECORD_FILE" <<RECORD
Patch: $PATCH_ID
Applied: $(date -u '+%Y-%m-%dT%H:%M:%SZ')
Root: $BQCA_ROOT
Backup: $BACKUP_DIR
Native key: BOBSHELL_API_KEY
Compatibility alias: BOB_API_KEY only when native key is absent
Differing-key behavior: native key wins; no equality failure
Default preflight: configure-only
Invocation: --auth-method api-key
Environment precedence: project .env, then inherited shell values
Protected assets: .env, workload stores, HOME/.bob, HOME/qiskit-v2x-env, HOME/.qiskit/qiskit-ibm.json
RECORD
chmod 644 "$PATCH_RECORD_FILE"

validate_installation
info "Patch $PATCH_ID applied successfully."
info "Backup: $BACKUP_DIR"
info "Native Bob key variable: BOBSHELL_API_KEY"
info "Legacy BOB_API_KEY is used only when the native key is absent."
info "Network preflight is opt-in; the first requested Bob operation validates connectivity by default."
