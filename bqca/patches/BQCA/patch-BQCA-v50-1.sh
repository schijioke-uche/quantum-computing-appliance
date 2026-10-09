#!/usr/bin/env bash
set -Eeuo pipefail

#===============================================================================
# IBM Bob Quantum Computing Agent (BQCA)
# Native Bob Shell API-Key Authentication Patch v50-1
# File: patch-BQCA-v50-1.sh
#
# Purpose:
#   Update BQCA authentication for the current native Bob Shell API-key method.
#
#   - Prefer BOBSHELL_API_KEY, with BOB_API_KEY retained as a compatibility alias.
#   - Force BOB_AUTH_METHOD=api-key for BQCA Bob Shell invocations.
#   - Add --auth-method api-key to every authenticated Bob invocation.
#   - Use the current documented --accept-license and -p prompt forms.
#   - Stop manufacturing ~/.bob/token.json and ~/.bob/config.json.
#   - Skip browser-auth integration for the API-key appliance flow.
#   - Preserve the active BQCA policy, modes, rules, skills, quantum workflows,
#     Qiskit environment, account configuration, and workload artifacts.
#
# Protected assets:
#   The installer does not read, copy, back up, modify, chmod, remove, or restore:
#     - <BQCA-root>/.env
#     - <BQCA-root>/bob-quantum-designs/
#     - <BQCA-root>/bob-quantum-store/
#     - $HOME/qiskit-v2x-env
#     - $HOME/.qiskit/qiskit-ibm.json
#     - $HOME/.bob
#===============================================================================

PATCH_ID="BQCA-v50-1"
PATCH_FILE_NAME="patch-BQCA-v50-1.sh"
TIMESTAMP="$(date +%Y%m%d%H%M%S)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_OVERRIDE=""
DRY_RUN=0
VALIDATE_ONLY=0
ROLLBACK_DIR=""

info() { printf '[BQCA v50-1][INFO] %s\n' "$*"; }
warn() { printf '[BQCA v50-1][WARN] %s\n' "$*" >&2; }
fail() { printf '[BQCA v50-1][ERROR] %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'USAGE'
BQCA Native Bob Shell API-Key Authentication Patch v50-1

Usage:
  ./patch-BQCA-v50-1.sh [options]

Options:
  --target <path>        Explicit standalone BQCA appliance root.
  --dry-run              Display the patch plan without changing files.
  --validate-only        Validate the installed v50-1 authentication integration.
  --rollback <backup>    Restore a v50-1 timestamped backup directory.
  -h, --help             Show this help.

Expected placement:
  <BQCA-root>/patches/BQCA/patch-BQCA-v50-1.sh

This patch never reads or modifies the project-root .env file.
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

for cmd in bash chmod cp date dirname find grep mkdir mktemp mv python3 rm sha256sum stat; do
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
MARKER="BQCA-BOB-NATIVE-API-KEY-v50-1"
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

  while IFS= read -r -d '' file; do
    backup_file "$file"
  done < <(find "$BQCA_ROOT" -maxdepth 1 -type f -name 'bob-quantum-v*.sh' -print0)

  cat > "$BACKUP_DIR/BQCA-v50-1-backup-manifest.txt" <<MANIFEST
Patch: $PATCH_ID
Created: $(date -u '+%Y-%m-%dT%H:%M:%SZ')
Appliance root: $BQCA_ROOT
Protected and intentionally excluded: .env, workload stores, HOME-scoped Qiskit environment, Qiskit account JSON, HOME/.bob
Restore with:
  $PATCH_FILE_NAME --target "$BQCA_ROOT" --rollback "$BACKUP_DIR"
MANIFEST
}

restore_backup() {
  local backup="$1" backup_abs source rel destination
  backup_abs="$(cd "$backup" 2>/dev/null && pwd -P || true)"
  [[ -n "$backup_abs" ]] || fail "Rollback directory not found: $backup"
  [[ -f "$backup_abs/BQCA-v50-1-backup-manifest.txt" ]] || fail "Not a BQCA v50-1 backup: $backup_abs"

  info "Restoring v50-1 backup: $backup_abs"
  while IFS= read -r -d '' source; do
    rel="${source#$backup_abs/}"
    [[ "$rel" != "BQCA-v50-1-backup-manifest.txt" ]] || continue
    destination="$BQCA_ROOT/$rel"
    mkdir -p "$(dirname "$destination")"
    cp -a "$source" "$destination"
  done < <(find "$backup_abs" -mindepth 1 -type f -print0)

  # Remove the patch record only when it did not exist before installation.
  rel="${PATCH_RECORD_FILE#$BQCA_ROOT/}"
  [[ -e "$backup_abs/$rel" ]] || rm -f "$PATCH_RECORD_FILE"

  info "Rollback complete. .env, workload stores, HOME/.bob, Qiskit environment, and Qiskit account JSON were not touched."
}

if [[ -n "$ROLLBACK_DIR" ]]; then
  restore_backup "$ROLLBACK_DIR"
  exit 0
fi

info "Resolved BQCA root: $BQCA_ROOT"
info "Patch identity: $PATCH_ID"
info "Authentication target: native Bob Shell API-key method using BOBSHELL_API_KEY"
info "Protected assets: .env, workload stores, HOME/.bob, qiskit-v2x-env, and qiskit-ibm.json"

if ((DRY_RUN)); then
  cat <<'DRY'
[BQCA v50-1][DRY-RUN] Planned changes:
  1. Replace legacy bob-auth.sh credential-file generation with native API-key setup.
  2. Prefer BOBSHELL_API_KEY and accept BOB_API_KEY only as a compatibility alias.
  3. Force BOB_AUTH_METHOD=api-key for BQCA Bob Shell invocations.
  4. Add --auth-method api-key to every menu and resume invocation.
  5. Use --accept-license without the obsolete boolean value.
  6. Use -p for non-interactive prompts in options 2, 3, and 4.
  7. Skip browser-auth integration in the API-key flow.
  8. Update .env.example, README.md, and bob-auth.md without modifying .env.
  9. Treat BOBSHELL_API_KEY as a protected secret in BQCA scanners.
 10. Preserve the active BQCA policy and all quantum execution behavior.
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
# Managed by patch-BQCA-v50-1.sh
#
# Bob Shell consumes BOBSHELL_API_KEY when invoked with:
#   --auth-method api-key
#
# BOB_API_KEY remains accepted only as a backward-compatible input alias.
# This script never creates or overwrites ~/.bob/token.json or ~/.bob/config.json.
#===============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ENV_FILE="$SCRIPT_DIR/.env"
TLS_CONTROL_FILE="$SCRIPT_DIR/tls-control.sh"
CYAN="${CYAN:-}"
RESET="${RESET:-}"

[[ -f "$ENV_FILE" ]] || {
  printf 'Bob Shell Authentication Failed: missing environment file: %s\n' "$ENV_FILE" >&2
  exit 1
}

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

if [[ -f "$TLS_CONTROL_FILE" ]]; then
  # shellcheck source=/dev/null
  source "$TLS_CONTROL_FILE"
fi

BOB_BIN="${BOB_BIN:-bob}"
command -v "$BOB_BIN" >/dev/null 2>&1 || {
  printf 'Bob Shell Authentication Failed: Bob CLI command not found: %s\n' "$BOB_BIN" >&2
  exit 1
}

# Native variable first; legacy BQCA variable is an input compatibility alias.
if [[ -n "${BOBSHELL_API_KEY:-}" && -n "${BOB_API_KEY:-}" && "${BOBSHELL_API_KEY}" != "${BOB_API_KEY}" ]]; then
  printf 'Bob Shell Authentication Failed: BOBSHELL_API_KEY and BOB_API_KEY are both set but do not match.
' >&2
  exit 1
fi
if [[ -z "${BOBSHELL_API_KEY:-}" && -n "${BOB_API_KEY:-}" ]]; then
  BOBSHELL_API_KEY="$BOB_API_KEY"
fi
if [[ -z "${BOB_API_KEY:-}" && -n "${BOBSHELL_API_KEY:-}" ]]; then
  BOB_API_KEY="$BOBSHELL_API_KEY"
fi

: "${BOBSHELL_API_KEY:?Bob Shell Authentication Failed: set BOBSHELL_API_KEY in .env (BOB_API_KEY is accepted as a legacy alias)}"

BOB_AUTH_METHOD="api-key"
export BOBSHELL_API_KEY BOB_API_KEY BOB_AUTH_METHOD BOB_BIN

# Legacy endpoint/region variables are preserved when an existing environment
# still provides them, but native API-key authentication does not require BQCA
# to manufacture Bob-managed credential files.
[[ -z "${BOB_ENDPOINT:-}" ]] || export BOB_ENDPOINT
[[ -z "${BOB_AUTH_ENDPOINT:-}" ]] || export BOB_AUTH_ENDPOINT
[[ -z "${BOB_REGION:-}" ]] || export BOB_REGION

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
  else
    printf 'Bob Shell Authentication Failed: BOB_TEAM_ID is set but this Bob CLI does not advertise --team-id.
' >&2
    exit 2
  fi
fi

# Native, non-destructive preflight. When the installed CLI exposes session
# listing, use it to validate the key without generating an inference prompt.
# Otherwise, configuration succeeds and the first normal BQCA invocation is the
# network credential check. Set BQCA_BOB_AUTH_PREFLIGHT=off to skip the probe.
BQCA_BOB_AUTH_PREFLIGHT="${BQCA_BOB_AUTH_PREFLIGHT:-auto}"
case "$BQCA_BOB_AUTH_PREFLIGHT" in
  off|skip|false|0)
    printf '%b\n' "${CYAN}Bob Shell native API-key authentication configured (preflight skipped).${RESET}"
    ;;
  auto|required)
    if grep -q -- '--list-sessions' <<<"$bob_help"; then
      auth_error="$(mktemp "${TMPDIR:-/tmp}/bqca-bob-auth.XXXXXX")"
      if "$BOB_BIN" "${AUTH_ARGS[@]}" --accept-license --list-sessions >/dev/null 2>"$auth_error"; then
        rm -f "$auth_error"
        printf '%b\n' "${CYAN}Bob Shell Authenticated Successfully with the native API-key method!${RESET}"
      else
        status=$?
        printf 'Bob Shell Authentication Failed: native API-key validation was rejected by Bob CLI.\n' >&2
        printf 'Verify BOBSHELL_API_KEY, API-key scope, BOB_INSTANCE_ID/BOB_TEAM_ID, proxy, and TLS settings.\n' >&2
        if [[ "${BQCA_BOB_AUTH_DEBUG:-0}" == "1" ]]; then
          # Show Bob's diagnostic without ever echoing the key value.
          sed -E 's/[A-Za-z0-9._~+\/=:-]{24,}/[REDACTED]/g' "$auth_error" >&2 || true
        fi
        rm -f "$auth_error"
        exit "$status"
      fi
    elif [[ "$BQCA_BOB_AUTH_PREFLIGHT" == "required" ]]; then
      printf 'Bob Shell Authentication Failed: --list-sessions is unavailable for the required preflight.\n' >&2
      exit 2
    else
      printf '%b\n' "${CYAN}Bob Shell native API-key authentication configured; the first BQCA request will validate connectivity.${RESET}"
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

# Remove an existing v50-1 block for idempotency.
text = re.sub(
    r"(?ms)^# BQCA-BOB-NATIVE-API-KEY-v50-1:BEGIN\n.*?^# BQCA-BOB-NATIVE-API-KEY-v50-1:END\n?",
    "",
    text,
)

# API-key mode must not chmod or source the browser-auth helper.
text = re.sub(r"(?m)^\s*chmod\s+777\s+configure-bob-auth-browser\.sh\s*\n", "", text)
text = re.sub(r"(?m)^\s*source\s+(?:\"?\$\{?SCRIPT_DIR\}?/?\"?)?configure-bob-auth-browser\.sh\s*\n", "", text)
text = re.sub(r"(?m)^\s*source\s+configure-bob-auth-browser\.sh\s*\n", "", text)

# Find all canonical project .env load blocks. Keep only the first one so Bob
# authentication variables are loaded early and exactly once.
env_pattern = re.compile(
    r"(?ms)^set -a\n(?:# shellcheck[^\n]*\n)?source \"\$\{SCRIPT_DIR\}/\.env\"\nset \+a\n"
)
matches = list(env_pattern.finditer(text))
if not matches:
    raise SystemExit("Unable to locate the canonical .env loading block in xLaunchpad.sh")
first = matches[0]
for match in reversed(matches[1:]):
    text = text[: match.start()] + text[match.end() :]

# Re-find the first block after removing duplicates.
first = env_pattern.search(text)
assert first is not None
block = r'''
# BQCA-BOB-NATIVE-API-KEY-v50-1:BEGIN
# Native Bob Shell API-key authentication. BOBSHELL_API_KEY is the current Bob
# Shell variable; BOB_API_KEY remains accepted as a backward-compatible alias.
if [[ -n "${BOBSHELL_API_KEY:-}" && -n "${BOB_API_KEY:-}" && "${BOBSHELL_API_KEY}" != "${BOB_API_KEY}" ]]; then
  printf '[BQCA v50-1][ERROR] BOBSHELL_API_KEY and BOB_API_KEY are both set but do not match.
' >&2
  exit 1
fi
if [[ -z "${BOBSHELL_API_KEY:-}" && -n "${BOB_API_KEY:-}" ]]; then
  BOBSHELL_API_KEY="${BOB_API_KEY}"
fi
if [[ -z "${BOB_API_KEY:-}" && -n "${BOBSHELL_API_KEY:-}" ]]; then
  BOB_API_KEY="${BOBSHELL_API_KEY}"
fi
: "${BOBSHELL_API_KEY:?BOBSHELL_API_KEY is not set in .env (BOB_API_KEY is accepted as a legacy alias)}"
BOB_AUTH_METHOD="api-key"
export BOBSHELL_API_KEY BOB_API_KEY BOB_AUTH_METHOD
# Browser authentication is intentionally not loaded for the native API-key flow.
# BQCA-BOB-NATIVE-API-KEY-v50-1:END
'''
text = text[: first.end()] + "\n" + block + text[first.end() :]

# Replace the legacy required-key check with the native variable.
text = re.sub(
    r': "\$\{BOB_API_KEY:\?BOB_API_KEY is not set in the \.env\}"',
    ': "${BOBSHELL_API_KEY:?BOBSHELL_API_KEY is not set in the .env}"',
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

# Remove the previous v50-1 helper block while retaining already-converted call
# sites so reapplication is idempotent.
text = re.sub(
    r"(?ms)^# BQCA-BOB-NATIVE-API-KEY-v50-1:BEGIN\n.*?^# BQCA-BOB-NATIVE-API-KEY-v50-1:END\n?",
    "",
    text,
)

# Convert direct Bob invocations. Specific prompt calls must be transformed
# before generic invocations.
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

block = r'''# BQCA-BOB-NATIVE-API-KEY-v50-1:BEGIN
# Every authenticated Bob Shell invocation uses the native API-key method.
if [[ -n "${BOBSHELL_API_KEY:-}" && -n "${BOB_API_KEY:-}" && "${BOBSHELL_API_KEY}" != "${BOB_API_KEY}" ]]; then
  printf '[BQCA v50-1][ERROR] BOBSHELL_API_KEY and BOB_API_KEY are both set but do not match.
' >&2
  exit 1
fi
if [[ -z "${BOBSHELL_API_KEY:-}" && -n "${BOB_API_KEY:-}" ]]; then
  BOBSHELL_API_KEY="${BOB_API_KEY}"
fi
if [[ -z "${BOB_API_KEY:-}" && -n "${BOBSHELL_API_KEY:-}" ]]; then
  BOB_API_KEY="${BOBSHELL_API_KEY}"
fi
: "${BOBSHELL_API_KEY:?BOBSHELL_API_KEY is required for BQCA Bob Shell execution}"
BOB_AUTH_METHOD="api-key"
export BOBSHELL_API_KEY BOB_API_KEY BOB_AUTH_METHOD
BQCA_BOB_NATIVE_AUTH_ARGS=(--auth-method "${BOB_AUTH_METHOD}")
_BQCA_BOB_HELP="$("${BOB_BIN}" --help 2>&1 || true)"
if ! grep -q -- '--auth-method' <<<"${_BQCA_BOB_HELP}"; then
  printf '[BQCA v50-1][ERROR] Installed Bob CLI does not advertise --auth-method.
' >&2
  exit 2
fi
if [[ -n "${BOB_TEAM_ID:-}" ]]; then
  if grep -q -- '--team-id' <<<"${_BQCA_BOB_HELP}"; then
    BQCA_BOB_NATIVE_AUTH_ARGS+=(--team-id "${BOB_TEAM_ID}")
  else
    printf '[BQCA v50-1][ERROR] BOB_TEAM_ID is set but this Bob CLI does not advertise --team-id.
' >&2
    exit 2
  fi
fi
unset _BQCA_BOB_HELP
bqca_bob_native() {
  "${BOB_BIN}" "${BQCA_BOB_NATIVE_AUTH_ARGS[@]}" "$@"
}
# BQCA-BOB-NATIVE-API-KEY-v50-1:END
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
from __future__ import annotations

import pathlib
import re
import sys

src = pathlib.Path(sys.argv[1])
out = pathlib.Path(sys.argv[2])
text = src.read_text(encoding="utf-8")

# Replace the first legacy key declaration with the native variable plus alias.
if 'BOBSHELL_API_KEY=' not in text:
    text, count = re.subn(
        r'(?m)^BOB_API_KEY=""\s*$',
        'BOBSHELL_API_KEY=""\n\n# Legacy compatibility alias. Prefer BOBSHELL_API_KEY for Bob Shell 2.x.\nBOB_API_KEY=""\n\n# BQCA uses native API-key authentication for every Bob invocation.\nBOB_AUTH_METHOD="api-key"\n\n# Optional: set to off to skip the non-destructive session-list preflight.\nBQCA_BOB_AUTH_PREFLIGHT="auto"',
        text,
        count=1,
    )
    if count != 1:
        raise SystemExit("Unable to locate BOB_API_KEY in .env.example")
else:
    if 'BOB_AUTH_METHOD=' not in text:
        text += '\nBOB_AUTH_METHOD="api-key"\n'
    if 'BQCA_BOB_AUTH_PREFLIGHT=' not in text:
        text += 'BQCA_BOB_AUTH_PREFLIGHT="auto"\n'

# Clarify endpoint fields without deleting compatibility configuration.
text = text.replace('# Bob API endpoint:', '# Optional legacy/custom Bob API endpoint:')
text = text.replace('# Optional Bob authentication endpoint:', '# Optional legacy/custom Bob authentication endpoint:')
out.write_text(text, encoding="utf-8")
PY
  cp "$tmp" "$ENV_EXAMPLE"
  rm -f "$tmp"
  chmod 644 "$ENV_EXAMPLE"
}

write_bob_auth_doc() {
  [[ -e "$BOB_AUTH_MD" ]] || return 0
  cat > "$BOB_AUTH_MD" <<'DOC'
# BQCA Bob Shell Native API-Key Authentication

BQCA uses the native Bob Shell API-key authentication flow.

## Required environment variable

Add the Bob API key to the project-root `.env` file using the native Bob Shell variable:

```bash
BOBSHELL_API_KEY="REPLACE_WITH_YOUR_BOB_INFERENCE_API_KEY"
BOB_AUTH_METHOD="api-key"
```

`BOB_API_KEY` remains accepted as a backward-compatible BQCA alias. When only
`BOB_API_KEY` is present, BQCA exports the same value as `BOBSHELL_API_KEY`
before Bob Shell starts.

## Native invocation contract

Every authenticated BQCA Bob invocation includes:

```bash
--auth-method api-key
```

Non-interactive prompts use:

```bash
-p "<prompt>"
```

License acceptance uses:

```bash
--accept-license
```

## Credential ownership

BQCA does not manufacture or overwrite:

```text
~/.bob/token.json
~/.bob/config.json
```

Bob Shell owns and manages its user-level state. BQCA supplies the API key by
environment variable and selects the API-key method on each invocation.

## Optional variables

```bash
BOB_TEAM_ID=""                 # Needed by some general/team-scoped keys
BQCA_BOB_AUTH_PREFLIGHT="auto" # auto, required, or off
BQCA_BOB_AUTH_DEBUG="0"        # Set to 1 for redacted CLI diagnostics
```

The existing `BOB_INSTANCE_ID` remains part of the BQCA session invocation.
Legacy endpoint and region variables may remain in `.env` for compatibility,
but BQCA v50-1 does not require them to build local Bob credential files.

## Security

- Never print or commit `BOBSHELL_API_KEY` or `BOB_API_KEY`.
- Use an API key with the correct Bob inference scope.
- Keep `.env` outside release archives and source control.
- Use approved proxy and enterprise CA settings when required.
DOC
  chmod 644 "$BOB_AUTH_MD"
}

patch_readme() {
  [[ -f "$README_FILE" ]] || return 0
  local tmp
  tmp="$(mktemp)"
  python3 - "$README_FILE" "$tmp" <<'PY'
from __future__ import annotations

import pathlib
import re
import sys

src = pathlib.Path(sys.argv[1])
out = pathlib.Path(sys.argv[2])
text = src.read_text(encoding="utf-8")
text = re.sub(
    r'(?ms)\n?<!-- BQCA-BOB-NATIVE-API-KEY-v50-1:BEGIN -->.*?<!-- BQCA-BOB-NATIVE-API-KEY-v50-1:END -->\n?',
    '\n',
    text,
)
text = text.replace('export BOB_API_KEY="<your-bob-api-key>"', 'export BOBSHELL_API_KEY="<your-bob-api-key>"')
block = r'''
<!-- BQCA-BOB-NATIVE-API-KEY-v50-1:BEGIN -->
## Bob Shell Native API-Key Authentication

BQCA authenticates Bob Shell through the native API-key method. Configure:

```bash
BOBSHELL_API_KEY="<your-Bob-inference-api-key>"
BOB_AUTH_METHOD="api-key"
```

The legacy `BOB_API_KEY` name remains accepted as an input alias, but
`BOBSHELL_API_KEY` is the preferred Bob Shell variable. BQCA adds
`--auth-method api-key` to every Bob invocation and uses `-p` for
non-interactive prompts. BQCA no longer creates `~/.bob/token.json` or
`~/.bob/config.json`; those files, when present, are Bob-managed state.
<!-- BQCA-BOB-NATIVE-API-KEY-v50-1:END -->
'''
# Put the authoritative authentication note before the quantum-variable section
# when possible; otherwise append it.
needle = '**Quantum-specific variables to review:**'
if needle in text:
    text = text.replace(needle, block + '\n' + needle, 1)
else:
    text = text.rstrip() + '\n\n' + block
out.write_text(text, encoding="utf-8")
PY
  cp "$tmp" "$README_FILE"
  rm -f "$tmp"
  chmod 644 "$README_FILE"
}

patch_secret_scanners() {
  local file tmp
  for file in "$SECRET_SCANNER" "$DYNAMIC_VALIDATOR"; do
    [[ -f "$file" ]] || continue
    tmp="$(mktemp)"
    python3 - "$file" "$tmp" <<'PY'
from __future__ import annotations

import pathlib
import sys

src = pathlib.Path(sys.argv[1])
out = pathlib.Path(sys.argv[2])
text = src.read_text(encoding="utf-8")

# List-based secret names.
if '"BOB_API_KEY"' in text and '"BOBSHELL_API_KEY"' not in text:
    text = text.replace('"BOB_API_KEY",', '"BOBSHELL_API_KEY",\n    "BOB_API_KEY",', 1)

# Regex alternations used by the dynamic validators and secret scanners.
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
printf '\nKEY=%s\n' "$([[ -n "${BOBSHELL_API_KEY:-}" ]] && printf SET || printf MISSING)" >> "${BQCA_MOCK_LOG}"
[[ " $* " == *" --auth-method api-key "* ]] || exit 41
[[ " $* " == *" --accept-license "* ]] || exit 42
[[ " $* " == *" --list-sessions "* ]] || exit 43
[[ -n "${BOBSHELL_API_KEY:-}" ]] || exit 44
exit 0
MOCK
  chmod 755 "$mock_bin" "$test_root/bob-auth.sh" "$test_root/tls-control.sh"

  cat > "$test_root/.env" <<ENV
BOB_API_KEY="legacy-alias-test-value-123456789"
BOB_BIN="$mock_bin"
BQCA_BOB_AUTH_PREFLIGHT="required"
ENV

  HOME="$test_root/home" BQCA_MOCK_LOG="$log" bash "$test_root/bob-auth.sh" >/dev/null
  grep -q 'KEY=SET' "$log" || { rm -rf "$test_root"; return 1; }
  grep -q -- '--auth-method api-key' "$log" || { rm -rf "$test_root"; return 1; }
  [[ ! -e "$test_root/home/.bob/token.json" ]] || { rm -rf "$test_root"; return 1; }
  [[ ! -e "$test_root/home/.bob/config.json" ]] || { rm -rf "$test_root"; return 1; }

  : > "$log"
  cat > "$test_root/.env" <<ENV
BOBSHELL_API_KEY="native-key-test-value-123456789"
BOB_BIN="$mock_bin"
BQCA_BOB_AUTH_PREFLIGHT="required"
ENV
  HOME="$test_root/home" BQCA_MOCK_LOG="$log" bash "$test_root/bob-auth.sh" >/dev/null
  grep -q 'KEY=SET' "$log" || { rm -rf "$test_root"; return 1; }

  rm -rf "$test_root"
}

validate_installation() {
  local failures=0 file marker_count direct_calls prompt_calls env_loads

  bash -n "$XLAUNCHPAD" || failures=$((failures + 1))
  bash -n "$BOB_AUTH_SH" || failures=$((failures + 1))

  marker_count="$(grep -c 'BQCA-BOB-NATIVE-API-KEY-v50-1:BEGIN' "$XLAUNCHPAD" || true)"
  [[ "$marker_count" -eq 1 ]] || { warn "xLaunchpad native-auth marker count is $marker_count, expected 1"; failures=$((failures + 1)); }

  env_loads="$(grep -c 'source "${SCRIPT_DIR}/.env"' "$XLAUNCHPAD" || true)"
  [[ "$env_loads" -eq 1 ]] || { warn "xLaunchpad loads .env $env_loads times, expected exactly 1"; failures=$((failures + 1)); }

  if grep -Eq 'chmod[[:space:]]+777[[:space:]]+configure-bob-auth-browser|source[[:space:]]+.*configure-bob-auth-browser' "$XLAUNCHPAD"; then
    warn "xLaunchpad still invokes browser authentication in the API-key flow"
    failures=$((failures + 1))
  fi
  grep -q 'BOBSHELL_API_KEY' "$XLAUNCHPAD" || { warn "xLaunchpad lacks BOBSHELL_API_KEY"; failures=$((failures + 1)); }
  grep -q 'BOB_AUTH_METHOD="api-key"' "$XLAUNCHPAD" || { warn "xLaunchpad does not force api-key authentication"; failures=$((failures + 1)); }

  if grep -Eq '^[[:space:]]*(TOKEN_FILE|CONFIG_FILE)=|^[[:space:]]*(TOKEN_TMP|CONFIG_TMP)=|^[[:space:]]*cat[[:space:]]*>[[:space:]]*"?\$?\{?(TOKEN_FILE|CONFIG_FILE|TOKEN_TMP|CONFIG_TMP)' "$BOB_AUTH_SH"; then
    warn "bob-auth.sh still manufactures legacy Bob credential files"
    failures=$((failures + 1))
  fi
  grep -q -- '--auth-method' "$BOB_AUTH_SH" || { warn "bob-auth.sh lacks native auth method"; failures=$((failures + 1)); }
  grep -q 'BOBSHELL_API_KEY' "$BOB_AUTH_SH" || { warn "bob-auth.sh lacks BOBSHELL_API_KEY"; failures=$((failures + 1)); }

  while IFS= read -r -d '' file; do
    bash -n "$file" || failures=$((failures + 1))
    marker_count="$(grep -c 'BQCA-BOB-NATIVE-API-KEY-v50-1:BEGIN' "$file" || true)"
    [[ "$marker_count" -eq 1 ]] || { warn "$file marker count is $marker_count, expected 1"; failures=$((failures + 1)); }

    direct_calls="$(grep -cE '^[[:space:]]*"\$\{BOB_BIN\}"[[:space:]]+("\$\{prompt\}"[[:space:]]+)?\\$' "$file" || true)"
    [[ "$direct_calls" -eq 0 ]] || { warn "$file still contains $direct_calls direct authenticated Bob invocation(s)"; failures=$((failures + 1)); }

    prompt_calls="$(grep -c -- '-p "${prompt}"' "$file" || true)"
    [[ "$prompt_calls" -ge 3 ]] || { warn "$file has $prompt_calls non-interactive -p prompt calls, expected at least 3"; failures=$((failures + 1)); }

    grep -q 'bqca_bob_native' "$file" || { warn "$file lacks native Bob wrapper"; failures=$((failures + 1)); }
    grep -q -- '--auth-method' "$file" || { warn "$file lacks --auth-method integration"; failures=$((failures + 1)); }
    if grep -q -- '--accept-license true' "$file"; then
      warn "$file still uses obsolete --accept-license true syntax"
      failures=$((failures + 1))
    fi
  done < <(find "$BQCA_ROOT" -maxdepth 1 -type f -name 'bob-quantum-v*.sh' -print0)

  [[ -f "$ENV_EXAMPLE" ]] && grep -q 'BOBSHELL_API_KEY=' "$ENV_EXAMPLE" || { warn ".env.example lacks BOBSHELL_API_KEY"; failures=$((failures + 1)); }
  [[ -f "$BOB_AUTH_MD" ]] && grep -q 'BOBSHELL_API_KEY' "$BOB_AUTH_MD" || { warn "bob-auth.md lacks native API-key guidance"; failures=$((failures + 1)); }

  if [[ -f "$SECRET_SCANNER" ]]; then
    python3 -m py_compile "$SECRET_SCANNER" || failures=$((failures + 1))
    grep -q 'BOBSHELL_API_KEY' "$SECRET_SCANNER" || { warn "secret scanner does not protect BOBSHELL_API_KEY"; failures=$((failures + 1)); }
  fi
  if [[ -f "$DYNAMIC_VALIDATOR" ]]; then
    python3 -m py_compile "$DYNAMIC_VALIDATOR" || failures=$((failures + 1))
    grep -q 'BOBSHELL_API_KEY' "$DYNAMIC_VALIDATOR" || { warn "dynamic validator does not protect BOBSHELL_API_KEY"; failures=$((failures + 1)); }
  fi

  run_mock_auth_test || { warn "isolated native API-key authentication smoke test failed"; failures=$((failures + 1)); }

  if [[ -n "$POLICY_HASH_BEFORE" ]]; then
    [[ "$(sha256sum "$BOB_ROOT/BQCA-PRODUCTION-POLICY.md" | awk '{print $1}')" == "$POLICY_HASH_BEFORE" ]] || {
      warn "active BQCA policy changed during authentication patch installation"
      failures=$((failures + 1))
    }
  fi

  if ((failures)); then
    fail "v50-1 validation failed with $failures issue(s)."
  fi

  info "Validation passed: native BOBSHELL_API_KEY authentication and --auth-method api-key are applied to bob-auth.sh and every BQCA Bob invocation."
}

if ((VALIDATE_ONLY)); then
  validate_installation
  exit 0
fi

create_backup
write_bob_auth
patch_xlaunchpad
patch_launchers
patch_env_example
write_bob_auth_doc
patch_readme
patch_secret_scanners

mkdir -p "$PATCH_RECORD_DIR"
cat > "$PATCH_RECORD_FILE" <<RECORD
Patch: $PATCH_ID
Applied: $(date -u '+%Y-%m-%dT%H:%M:%SZ')
Root: $BQCA_ROOT
Backup: $BACKUP_DIR
Authentication method: native Bob Shell API key
Native environment variable: BOBSHELL_API_KEY
Compatibility input alias: BOB_API_KEY
Invocation flag: --auth-method api-key
Credential files created by BQCA: none
Protected .env: excluded and unchanged
Active BQCA policy: unchanged
RECORD
chmod 644 "$PATCH_RECORD_FILE"

validate_installation
info "Patch $PATCH_ID applied successfully."
info "Backup: $BACKUP_DIR"
info "Native Bob key variable: BOBSHELL_API_KEY"
info "Every authenticated BQCA Bob invocation now uses --auth-method api-key."
info ".env and the active BQCA policy were not changed."
