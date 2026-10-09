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

# BQCA-BOB-SHELL-V2-DNA:BEGIN
# In a trusted Bob Shell 2.x workspace, bind this component to AGENTS.md, the
# active central BQCA policy, exported menu context, current rules/skills/tools,
# and the offline knowledgebase without changing this component's core purpose.
# BQCA-BOB-SHELL-V2-DNA:END
