#!/usr/bin/env bash
set -Eeuo pipefail

#===============================================================================
# IBM Bob Quantum Computing Agent (BQCA)
# Root Filename Bob-Version Synchronization Patch 49
# File: patch-BQCA-49.sh
# Author: Dr. Jeffrey Chijioke-Uche, IBM Computer Scientist
#
# Purpose:
#   1. Detect the currently installed IBM Bob Shell version by running
#      `bob --version` and store the parsed value in `current_bob_version`.
#   2. Inspect regular filenames located directly in the BQCA project root.
#   3. Rename a root filename containing an older embedded Bob version token,
#      such as `bob-quantum-v1.0.4.sh`, to the currently installed Bob version.
#   4. Install this synchronization as the first operational action executed by
#      xLaunchpad.sh on every BQCA launch.
#
# BQCA standalone patch placement:
#   <BQCA-root>/patches/BQCA/patch-BQCA-49.sh
#
# Safety:
#   - The patch does not read, copy, back up, modify, chmod, remove, or restore
#     the project-root .env file.
#   - Only regular files directly under the BQCA project root are considered.
#   - Subdirectories, .git, .bob, patches, design stores, implementation stores,
#     and their contents are not scanned or renamed.
#   - Newer version-bearing filenames are never downgraded.
#   - Existing destination files are never overwritten.
#   - The active BQCA v48 policy and all existing BQCA intelligence remain
#     unchanged.
#===============================================================================

PATCH_ID="BQCA-49"
PATCH_FILE_NAME="patch-BQCA-49.sh"
MARKER="BQCA-ROOT-FILENAME-VERSION-SYNC-49"
HELPER_BASENAME="bob-filename-version-sync.sh"
TIMESTAMP="$(date +%Y%m%d%H%M%S)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_OVERRIDE=""
DRY_RUN=0
VALIDATE_ONLY=0
ROLLBACK_DIR=""

info() { printf '[BQCA-49][INFO] %s\n' "$*"; }
warn() { printf '[BQCA-49][WARN] %s\n' "$*" >&2; }
fail() { printf '[BQCA-49][ERROR] %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'USAGE'
BQCA Root Filename Bob-Version Synchronization Patch 49

Usage:
  ./patch-BQCA-49.sh [options]

Options:
  --target <path>        Explicit BQCA appliance root.
  --dry-run              Display the patch plan without changing files.
  --validate-only        Validate the current BQCA-49 installation.
  --rollback <backup>    Restore a timestamped BQCA-49 backup directory.
  -h, --help             Show this help.

Expected placement:
  <BQCA-root>/patches/BQCA/patch-BQCA-49.sh

The BQCA project-root .env file is never touched.
USAGE
}

while (($#)); do
  case "$1" in
    --target)
      (($# >= 2)) || fail "--target requires a path"
      TARGET_OVERRIDE="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --validate-only)
      VALIDATE_ONLY=1
      shift
      ;;
    --rollback)
      (($# >= 2)) || fail "--rollback requires a backup directory"
      ROLLBACK_DIR="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown option: $1"
      ;;
  esac
done

for command_name in bash basename chmod cp date dirname find grep head mkdir mktemp mv python3 rm sleep tr wc; do
  command -v "$command_name" >/dev/null 2>&1 || fail "Required command not found: $command_name"
done

launcher_exists() {
  local candidate="$1"
  compgen -G "$candidate/bob-quantum-v*.sh" >/dev/null 2>&1
}

is_bqca_root() {
  local candidate="$1"
  [[ -d "$candidate/.bob" ]] || return 1
  [[ -f "$candidate/.bob/custom_modes.yaml" ]] || return 1
  [[ -d "$candidate/.bob/skills" ]] || return 1
  [[ -f "$candidate/xLaunchpad.sh" ]] || return 1
  [[ -f "$candidate/bob-version.sh" ]] || return 1
  [[ -d "$candidate/bob-quantum-store" ]] || return 1
  launcher_exists "$candidate"
}

resolve_bqca_root() {
  local candidate dir

  if [[ -n "$TARGET_OVERRIDE" ]]; then
    candidate="$(cd "$TARGET_OVERRIDE" 2>/dev/null && pwd || true)"
    [[ -n "$candidate" ]] || fail "Target path does not exist: $TARGET_OVERRIDE"
    is_bqca_root "$candidate" || fail "Target is not a valid BQCA root: $candidate"
    printf '%s\n' "$candidate"
    return 0
  fi

  candidate="$(pwd)"
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
XLAUNCHPAD="$BQCA_ROOT/xLaunchpad.sh"
HELPER="$BQCA_ROOT/$HELPER_BASENAME"
RUNTIME_DIR="$BOB_ROOT/runtime"
JOURNAL_FILE="$RUNTIME_DIR/bqca-49-filename-version-sync-renames.jsonl"
BACKUP_ROOT="$BOB_ROOT/patch-backups"
BACKUP_DIR="$BACKUP_ROOT/${PATCH_ID}.${TIMESTAMP}"
PATCH_RECORD_DIR="$BOB_ROOT/patches-applied"
PATCH_RECORD_FILE="$PATCH_RECORD_DIR/${PATCH_ID}.txt"

is_versioned_root_file() {
  local file="$1" filename
  [[ -f "$file" && ! -L "$file" ]] || return 1
  filename="$(basename "$file")"
  [[ "$filename" != ".env" ]] || return 1
  printf '%s\n' "$filename" | grep -Eq 'v[0-9]+([.][0-9]+){1,3}'
}

backup_file() {
  local source="$1" relative destination
  [[ -e "$source" ]] || return 0
  [[ "$source" != "$BQCA_ROOT/.env" ]] || return 0
  relative="${source#$BQCA_ROOT/}"
  destination="$BACKUP_DIR/$relative"
  mkdir -p "$(dirname "$destination")"
  cp -a "$source" "$destination"
}

create_backup() {
  local journal_lines=0

  mkdir -p "$BACKUP_DIR/root-versioned-files" "$PATCH_RECORD_DIR"

  backup_file "$XLAUNCHPAD"
  backup_file "$HELPER"
  backup_file "$JOURNAL_FILE"
  backup_file "$PATCH_RECORD_FILE"

  [[ -e "$HELPER" ]] || : > "$BACKUP_DIR/helper-was-absent"
  [[ -e "$JOURNAL_FILE" ]] || : > "$BACKUP_DIR/journal-was-absent"
  [[ -e "$PATCH_RECORD_FILE" ]] || : > "$BACKUP_DIR/patch-record-was-absent"

  if [[ -f "$JOURNAL_FILE" ]]; then
    journal_lines="$(wc -l < "$JOURNAL_FILE" | tr -d ' ')"
  fi
  printf '%s\n' "$journal_lines" > "$BACKUP_DIR/journal-baseline-lines.txt"

  while IFS= read -r -d '' file; do
    is_versioned_root_file "$file" || continue
    cp -a "$file" "$BACKUP_DIR/root-versioned-files/$(basename "$file")"
  done < <(find "$BQCA_ROOT" -maxdepth 1 -type f ! -name '.env' -print0)

  cat > "$BACKUP_DIR/BQCA-49-backup-manifest.txt" <<MANIFEST
Patch: $PATCH_ID
Created: $(date -u '+%Y-%m-%dT%H:%M:%SZ')
Appliance root: $BQCA_ROOT
Protected project-root file excluded: .env
Runtime helper: $HELPER_BASENAME
Launcher marker: $MARKER
Journal baseline lines: $journal_lines
Restore with:
  $PATCH_FILE_NAME --target "$BQCA_ROOT" --rollback "$BACKUP_DIR"
MANIFEST
}

reverse_journal_delta() {
  local baseline_lines
  baseline_lines="$(cat "$BACKUP_DIR/journal-baseline-lines.txt" 2>/dev/null || printf '0')"
  [[ "$baseline_lines" =~ ^[0-9]+$ ]] || fail "Invalid journal baseline in backup: $baseline_lines"
  [[ -f "$JOURNAL_FILE" ]] || return 0

  python3 - "$BQCA_ROOT" "$JOURNAL_FILE" "$baseline_lines" <<'PY_REVERSE'
from __future__ import annotations

import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1]).resolve()
journal = pathlib.Path(sys.argv[2])
baseline = int(sys.argv[3])

lines = journal.read_text(encoding="utf-8").splitlines()
if baseline > len(lines):
    raise SystemExit(
        f"journal baseline {baseline} exceeds current journal length {len(lines)}"
    )

for raw in reversed(lines[baseline:]):
    if not raw.strip():
        continue
    record = json.loads(raw)
    if record.get("action") != "RENAME":
        continue
    old_name = str(record.get("old", ""))
    new_name = str(record.get("new", ""))
    if not old_name or not new_name:
        raise SystemExit("invalid rename record in BQCA-49 journal")
    if any(separator in old_name or separator in new_name for separator in ("/", "\\")):
        raise SystemExit("unsafe path found in BQCA-49 rename journal")

    old_path = root / old_name
    new_path = root / new_name

    if new_path.exists() and old_path.exists():
        raise SystemExit(
            f"rollback collision: both {old_path.name} and {new_path.name} exist"
        )
    if new_path.exists() and not old_path.exists():
        new_path.rename(old_path)
    elif old_path.exists() and not new_path.exists():
        # Already reversed or manually restored.
        continue
    else:
        # Neither side exists. The backup restoration phase can restore files that
        # existed at patch time, but a post-patch file is no longer recoverable.
        continue
PY_REVERSE
}

restore_backup() {
  local backup="$1" backup_abs source relative destination

  backup_abs="$(cd "$backup" 2>/dev/null && pwd || true)"
  [[ -n "$backup_abs" ]] || fail "Rollback directory not found: $backup"
  [[ -f "$backup_abs/BQCA-49-backup-manifest.txt" ]] || fail "Not a BQCA-49 backup: $backup_abs"

  BACKUP_DIR="$backup_abs"
  reverse_journal_delta

  cp -a "$BACKUP_DIR/xLaunchpad.sh" "$XLAUNCHPAD"

  if [[ -f "$BACKUP_DIR/helper-was-absent" ]]; then
    rm -f "$HELPER"
  else
    cp -a "$BACKUP_DIR/$HELPER_BASENAME" "$HELPER"
  fi

  if [[ -f "$BACKUP_DIR/journal-was-absent" ]]; then
    rm -f "$JOURNAL_FILE"
  else
    mkdir -p "$RUNTIME_DIR"
    cp -a "$BACKUP_DIR/.bob/runtime/$(basename "$JOURNAL_FILE")" "$JOURNAL_FILE"
  fi

  if [[ -f "$BACKUP_DIR/patch-record-was-absent" ]]; then
    rm -f "$PATCH_RECORD_FILE"
  else
    cp -a "$BACKUP_DIR/.bob/patches-applied/$(basename "$PATCH_RECORD_FILE")" "$PATCH_RECORD_FILE"
  fi

  if [[ -d "$BACKUP_DIR/root-versioned-files" ]]; then
    while IFS= read -r -d '' source; do
      destination="$BQCA_ROOT/$(basename "$source")"
      cp -a "$source" "$destination"
    done < <(find "$BACKUP_DIR/root-versioned-files" -maxdepth 1 -type f -print0)
  fi

  chmod 755 "$XLAUNCHPAD"
  [[ ! -e "$HELPER" ]] || chmod 755 "$HELPER"
  info "Rollback complete. The BQCA .env file was not touched."
}

if [[ -n "$ROLLBACK_DIR" ]]; then
  restore_backup "$ROLLBACK_DIR"
  exit 0
fi

write_runtime_helper() {
  cat > "$HELPER" <<'SYNC_HELPER'
#!/usr/bin/env bash
set -Eeuo pipefail

# BQCA root-filename Bob-version synchronization runtime helper.
# This helper is intentionally executed before all other xLaunchpad operations.

APPLIANCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOB_BIN_RESOLVED="${BOB_BIN:-bob}"
PRINT_VERSION=0
DRY_RUN=0
QUIET=0

usage() {
  cat <<'USAGE'
Usage:
  bob-filename-version-sync.sh [--sync] [--print-version] [--dry-run] [--quiet]

Behavior:
  - Detect the installed Bob version with `bob --version`.
  - Store the parsed numeric version in current_bob_version.
  - Scan only regular files directly under the BQCA appliance root.
  - Rename filenames containing older vX.Y.Z tokens to the installed Bob version.
  - Never downgrade a newer filename and never overwrite an existing file.
USAGE
}

while (($#)); do
  case "$1" in
    --sync)
      shift
      ;;
    --print-version)
      PRINT_VERSION=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --quiet)
      QUIET=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf '[bob-filename-version-sync] ERROR: Unknown option: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

log() {
  (( QUIET )) || printf '[bob-filename-version-sync] %s\n' "$*" >&2
}

fail() {
  printf '[bob-filename-version-sync] ERROR: %s\n' "$*" >&2
  exit 1
}

for command_name in chmod grep head mkdir python3 sleep tr; do
  command -v "$command_name" >/dev/null 2>&1 || fail "Required command not found: $command_name"
done

if ! command -v "$BOB_BIN_RESOLVED" >/dev/null 2>&1; then
  fail "Bob executable not found: $BOB_BIN_RESOLVED"
fi

current_bob_version_raw="$("$BOB_BIN_RESOLVED" --version 2>&1 || true)"
current_bob_version="$(
  printf '%s\n' "$current_bob_version_raw" |
    tr -d '\r' |
    grep -Eo '[0-9]+([.][0-9]+){1,3}' |
    head -n 1 || true
)"

[[ -n "$current_bob_version" ]] || fail "Unable to determine Bob version from: ${current_bob_version_raw:-<empty>}"
[[ "$current_bob_version" =~ ^[0-9]+([.][0-9]+){1,3}$ ]] || fail "Unsupported Bob version format: $current_bob_version"

export current_bob_version

RUNTIME_DIR="$APPLIANCE_ROOT/.bob/runtime"
LOCK_DIR="$RUNTIME_DIR/bqca-49-filename-version-sync.lock"
JOURNAL_FILE="$RUNTIME_DIR/bqca-49-filename-version-sync-renames.jsonl"
mkdir -p "$RUNTIME_DIR"
chmod 700 "$RUNTIME_DIR" 2>/dev/null || true

lock_acquired=0
for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
  if mkdir "$LOCK_DIR" 2>/dev/null; then
    lock_acquired=1
    break
  fi
  sleep 0.05
done
(( lock_acquired == 1 )) || fail "Unable to acquire runtime synchronization lock: $LOCK_DIR"
trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT

python3 - "$APPLIANCE_ROOT" "$current_bob_version" "$DRY_RUN" "$QUIET" "$JOURNAL_FILE" <<'PY_SYNC'
from __future__ import annotations

import datetime as dt
import json
import os
import pathlib
import re
import sys
from collections import defaultdict

root = pathlib.Path(sys.argv[1]).resolve()
current_text = sys.argv[2]
dry_run = sys.argv[3] == "1"
quiet = sys.argv[4] == "1"
journal = pathlib.Path(sys.argv[5])
version_pattern = re.compile(r"v(?P<version>[0-9]+(?:\.[0-9]+){1,3})")


def log(message: str) -> None:
    if not quiet:
        print(f"[bob-filename-version-sync] {message}", file=sys.stderr)


def version_tuple(value: str) -> tuple[int, int, int, int]:
    parts = [int(part) for part in value.split(".")]
    if not 2 <= len(parts) <= 4:
        raise ValueError(f"unsupported version: {value}")
    return tuple((parts + [0, 0, 0, 0])[:4])


current = version_tuple(current_text)
plan: list[tuple[pathlib.Path, pathlib.Path]] = []
newer_messages: set[str] = set()

for source in sorted(root.iterdir(), key=lambda item: item.name):
    if source.name == ".env" or source.is_symlink() or not source.is_file():
        continue

    def replace(match: re.Match[str]) -> str:
        embedded_text = match.group("version")
        embedded = version_tuple(embedded_text)
        if embedded < current:
            return f"v{current_text}"
        if embedded > current:
            newer_messages.add(
                f"Not downgrading newer filename: {source.name} "
                f"(embedded {embedded_text}; installed {current_text})"
            )
        return match.group(0)

    new_name = version_pattern.sub(replace, source.name)
    if new_name != source.name:
        plan.append((source, root / new_name))

for message in sorted(newer_messages):
    log(message)

by_destination: dict[pathlib.Path, list[pathlib.Path]] = defaultdict(list)
for source, destination in plan:
    by_destination[destination].append(source)

errors: list[str] = []
for destination, sources in by_destination.items():
    if len(sources) > 1:
        errors.append(
            "multiple source filenames map to the same destination "
            f"{destination.name}: {', '.join(source.name for source in sources)}"
        )
    if destination.exists() and destination not in sources:
        errors.append(
            f"rename collision: destination already exists: {destination.name}"
        )

if errors:
    for error in errors:
        print(f"[bob-filename-version-sync] ERROR: {error}", file=sys.stderr)
    raise SystemExit(3)

if dry_run:
    for source, destination in plan:
        log(f"Would rename: {source.name} -> {destination.name}")
    log(f"Installed Bob version: {current_text}; planned renames: {len(plan)}")
    raise SystemExit(0)

journal.parent.mkdir(parents=True, exist_ok=True)
records: list[dict[str, str]] = []
for source, destination in plan:
    source.rename(destination)
    record = {
        "timestamp": dt.datetime.now(dt.timezone.utc).isoformat(),
        "action": "RENAME",
        "old": source.name,
        "new": destination.name,
        "current_bob_version": current_text,
    }
    records.append(record)
    log(f"Renamed: {source.name} -> {destination.name}")

if records:
    with journal.open("a", encoding="utf-8") as stream:
        for record in records:
            stream.write(json.dumps(record, sort_keys=True) + "\n")
        stream.flush()
        os.fsync(stream.fileno())
    os.chmod(journal, 0o600)

log(f"Installed Bob version: {current_text}; renamed files: {len(records)}")
PY_SYNC

if (( PRINT_VERSION )); then
  printf '%s\n' "$current_bob_version"
fi
SYNC_HELPER

  chmod 755 "$HELPER"
}

patch_xlaunchpad() {
  local temporary
  temporary="$(mktemp)"

  python3 - "$XLAUNCHPAD" "$temporary" "$MARKER" <<'PY_PATCH'
from __future__ import annotations

import pathlib
import re
import sys

source = pathlib.Path(sys.argv[1])
destination = pathlib.Path(sys.argv[2])
marker = sys.argv[3]
text = source.read_text(encoding="utf-8")

block_pattern = re.compile(
    rf"(?ms)^# {re.escape(marker)}:BEGIN\n.*?^# {re.escape(marker)}:END\n?"
)
text = block_pattern.sub("", text)

block = f'''# {marker}:BEGIN
# First operational action: detect the installed Bob Shell version and update
# older Bob-version tokens found in regular filenames directly under the BQCA
# project root before any other appliance initialization executes.
_BQCA49_SCRIPT_DIR="$(cd "$(dirname "${{BASH_SOURCE[0]}}")" && pwd)"
_BQCA49_VERSION_SYNC_TOOL="${{_BQCA49_SCRIPT_DIR}}/bob-filename-version-sync.sh"
if [[ ! -x "${{_BQCA49_VERSION_SYNC_TOOL}}" ]]; then
  printf '[BQCA-49][ERROR] Required filename-version synchronization helper is missing or not executable: %s\\n' \\
    "${{_BQCA49_VERSION_SYNC_TOOL}}" >&2
  exit 1
fi
current_bob_version="$("${{_BQCA49_VERSION_SYNC_TOOL}}" --sync --print-version --quiet)"
if [[ -z "${{current_bob_version}}" ]]; then
  printf '[BQCA-49][ERROR] Bob Shell version detection returned an empty value.\\n' >&2
  exit 1
fi
BOB_VERSION="${{current_bob_version}}"
export current_bob_version BOB_VERSION
_BQCA49_EXPECTED_LAUNCHER="${{_BQCA49_SCRIPT_DIR}}/bob-quantum-v${{current_bob_version}}.sh"
if [[ ! -f "${{_BQCA49_EXPECTED_LAUNCHER}}" ]]; then
  printf '[BQCA-49][ERROR] The version-aligned BQCA launcher was not found after synchronization: %s\\n' \\
    "${{_BQCA49_EXPECTED_LAUNCHER}}" >&2
  exit 1
fi
unset _BQCA49_SCRIPT_DIR _BQCA49_VERSION_SYNC_TOOL _BQCA49_EXPECTED_LAUNCHER
# {marker}:END
'''

lines = text.splitlines(keepends=True)
strict_index = None
for index, line in enumerate(lines):
    if line.strip() == "set -Eeuo pipefail":
        strict_index = index
        break

if strict_index is None:
    raise SystemExit("Unable to locate 'set -Eeuo pipefail' in xLaunchpad.sh")

insert_at = strict_index + 1
lines.insert(insert_at, "\n" + block + "\n")
destination.write_text("".join(lines), encoding="utf-8")
PY_PATCH

  cp "$temporary" "$XLAUNCHPAD"
  rm -f "$temporary"
  chmod 755 "$XLAUNCHPAD"
}

run_synthetic_helper_test() {
  local test_root fake_bin helper_copy detected collision_root dry_root

  test_root="$(mktemp -d)"
  fake_bin="$test_root/bin"
  mkdir -p "$fake_bin" "$test_root/appliance/.bob" "$test_root/appliance/subdirectory"
  helper_copy="$test_root/appliance/$HELPER_BASENAME"
  cp "$HELPER" "$helper_copy"
  chmod 755 "$helper_copy"

  cat > "$fake_bin/bob" <<'FAKE_BOB'
#!/usr/bin/env bash
printf 'IBM Bob Shell version 1.0.6\n'
FAKE_BOB
  chmod 755 "$fake_bin/bob"

  printf 'legacy launcher\n' > "$test_root/appliance/bob-quantum-v1.0.4.sh"
  printf 'legacy file\n' > "$test_root/appliance/example-v1.0.5.txt"
  printf 'current file\n' > "$test_root/appliance/current-v1.0.6.txt"
  printf 'newer file\n' > "$test_root/appliance/newer-v1.0.7.txt"
  printf 'nested file\n' > "$test_root/appliance/subdirectory/nested-v1.0.4.sh"

  detected="$(PATH="$fake_bin:$PATH" BOB_BIN=bob "$helper_copy" --sync --print-version --quiet)"
  [[ "$detected" == "1.0.6" ]] || fail "Synthetic helper returned an unexpected Bob version: $detected"
  [[ -f "$test_root/appliance/bob-quantum-v1.0.6.sh" ]] || fail "Synthetic helper did not rename the stale BQCA launcher"
  [[ ! -e "$test_root/appliance/bob-quantum-v1.0.4.sh" ]] || fail "Synthetic helper left the stale BQCA launcher"
  [[ -f "$test_root/appliance/example-v1.0.6.txt" ]] || fail "Synthetic helper did not rename another stale root filename"
  [[ -f "$test_root/appliance/current-v1.0.6.txt" ]] || fail "Synthetic helper changed a current filename"
  [[ -f "$test_root/appliance/newer-v1.0.7.txt" ]] || fail "Synthetic helper downgraded a newer filename"
  [[ -f "$test_root/appliance/subdirectory/nested-v1.0.4.sh" ]] || fail "Synthetic helper scanned a subdirectory"

  dry_root="$test_root/dry-run"
  mkdir -p "$dry_root/.bob"
  cp "$HELPER" "$dry_root/$HELPER_BASENAME"
  chmod 755 "$dry_root/$HELPER_BASENAME"
  printf 'dry\n' > "$dry_root/dry-v1.0.4.sh"
  PATH="$fake_bin:$PATH" BOB_BIN=bob "$dry_root/$HELPER_BASENAME" --sync --dry-run --quiet
  [[ -f "$dry_root/dry-v1.0.4.sh" ]] || fail "Synthetic dry-run modified a filename"
  [[ ! -e "$dry_root/dry-v1.0.6.sh" ]] || fail "Synthetic dry-run created a destination file"

  collision_root="$test_root/collision"
  mkdir -p "$collision_root/.bob"
  cp "$HELPER" "$collision_root/$HELPER_BASENAME"
  chmod 755 "$collision_root/$HELPER_BASENAME"
  printf 'old\n' > "$collision_root/conflict-v1.0.4.sh"
  printf 'existing\n' > "$collision_root/conflict-v1.0.6.sh"
  if PATH="$fake_bin:$PATH" BOB_BIN=bob "$collision_root/$HELPER_BASENAME" --sync --quiet >/dev/null 2>&1; then
    fail "Synthetic collision test unexpectedly overwrote an existing file"
  fi

  rm -rf "$test_root"
}

validate_launcher_order() {
  python3 - "$XLAUNCHPAD" "$MARKER" <<'PY_ORDER'
from __future__ import annotations

import pathlib
import sys

path = pathlib.Path(sys.argv[1])
marker = sys.argv[2]
lines = path.read_text(encoding="utf-8").splitlines()

try:
    strict = next(index for index, line in enumerate(lines) if line.strip() == "set -Eeuo pipefail")
except StopIteration:
    raise SystemExit("strict-mode line is missing")

try:
    begin = next(index for index, line in enumerate(lines) if line == f"# {marker}:BEGIN")
except StopIteration:
    raise SystemExit("BQCA-49 marker is missing")

for line in lines[strict + 1 : begin]:
    stripped = line.strip()
    if stripped and not stripped.startswith("#"):
        raise SystemExit(
            f"an operational command appears before the BQCA-49 runtime hook: {stripped}"
        )

if begin <= strict:
    raise SystemExit("BQCA-49 hook does not follow strict mode")
PY_ORDER
}

validate_installation() {
  local failures=0 marker_count real_version=""

  [[ -x "$HELPER" ]] || { warn "Missing executable helper: $HELPER"; failures=$((failures + 1)); }
  [[ -x "$XLAUNCHPAD" ]] || { warn "xLaunchpad is not executable: $XLAUNCHPAD"; failures=$((failures + 1)); }

  bash -n "$HELPER" || failures=$((failures + 1))
  bash -n "$XLAUNCHPAD" || failures=$((failures + 1))

  marker_count="$(grep -c "^# $MARKER:BEGIN$" "$XLAUNCHPAD" || true)"
  [[ "$marker_count" -eq 1 ]] || {
    warn "xLaunchpad marker count is $marker_count; expected 1"
    failures=$((failures + 1))
  }

  grep -q 'current_bob_version=' "$XLAUNCHPAD" || {
    warn "xLaunchpad does not store current_bob_version"
    failures=$((failures + 1))
  }
  grep -q 'export current_bob_version BOB_VERSION' "$XLAUNCHPAD" || {
    warn "xLaunchpad does not export current_bob_version and BOB_VERSION"
    failures=$((failures + 1))
  }
  grep -q 'bob-quantum-v${current_bob_version}.sh' "$XLAUNCHPAD" || {
    warn "xLaunchpad does not verify the version-aligned BQCA launcher"
    failures=$((failures + 1))
  }

  validate_launcher_order || failures=$((failures + 1))
  run_synthetic_helper_test || failures=$((failures + 1))

  if command -v "${BOB_BIN:-bob}" >/dev/null 2>&1; then
    real_version="$("$HELPER" --sync --print-version --dry-run --quiet)" || failures=$((failures + 1))
    [[ -n "$real_version" ]] || {
      warn "Installed Bob version validation returned an empty value"
      failures=$((failures + 1))
    }
  fi

  if (( failures )); then
    fail "$PATCH_ID validation failed with $failures issue(s)."
  fi

  info "Validation passed: Bob version detection, root-only filename upgrades, collision protection, launch-first ordering, and rollback metadata are installed."
}

write_patch_record() {
  local detected_version="$1"
  mkdir -p "$PATCH_RECORD_DIR"
  cat > "$PATCH_RECORD_FILE" <<RECORD
Patch: $PATCH_ID
Applied: $(date -u '+%Y-%m-%dT%H:%M:%SZ')
Root: $BQCA_ROOT
Backup: $BACKUP_DIR
Runtime helper: $HELPER_BASENAME
Launcher marker: $MARKER
Current Bob version at application: ${detected_version:-deferred-until-next-launch}
Behavior: On every xLaunchpad start, detect the installed Bob Shell version, store it in current_bob_version, export BOB_VERSION, and rename only older Bob-version-bearing regular filenames located directly in the BQCA project root.
Safety: No downgrade, no overwrite, no subdirectory scan, active policy unchanged, and .env excluded.
RECORD
  chmod 644 "$PATCH_RECORD_FILE"
}

info "Resolved BQCA root: $BQCA_ROOT"
info "Patch identity: $PATCH_ID"
info "Protected assets: .env, .bob internals, patches, design store, implementation store, home Qiskit environment, and Qiskit account JSON"

if (( DRY_RUN )); then
  cat <<DRY_RUN
[BQCA-49][DRY-RUN] Planned production changes:
  1. Create a timestamped backup under .bob/patch-backups/$PATCH_ID.<timestamp>/.
  2. Install $HELPER_BASENAME in the BQCA project root.
  3. Insert one $MARKER block immediately after xLaunchpad strict mode.
  4. Run `bob --version`, parse the current version, and store it in current_bob_version.
  5. Export both current_bob_version and BOB_VERSION before other launch operations.
  6. On every launch, scan only regular filenames directly under the project root.
  7. Rename only filenames containing an older vX.Y.Z token to the installed Bob version.
  8. Never downgrade newer filenames and never overwrite an existing destination.
  9. Leave the active BQCA v48 policy and all existing intelligence unchanged.
 10. Leave .env and all subdirectory contents unchanged.
DRY_RUN
  exit 0
fi

if (( VALIDATE_ONLY )); then
  validate_installation
  exit 0
fi

create_backup
write_runtime_helper
patch_xlaunchpad

initial_version=""
if command -v "${BOB_BIN:-bob}" >/dev/null 2>&1; then
  initial_version="$("$HELPER" --sync --print-version)"
  info "Detected installed Bob version: $initial_version"
else
  warn "Bob executable is not currently available; synchronization will run automatically and fail closed at the next xLaunchpad start if Bob remains unavailable."
fi

write_patch_record "$initial_version"
validate_installation

info "Patch $PATCH_ID applied successfully."
info "Backup: $BACKUP_DIR"
info "Runtime helper: $HELPER"
info "The active BQCA policy and .env were not changed."
