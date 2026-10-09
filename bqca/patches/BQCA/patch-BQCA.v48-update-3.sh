#!/usr/bin/env bash
set -Eeuo pipefail

#===============================================================================
# BQCA Bob Shell maxTokens Diagnostic and Custom-Mode Integrity Repair
# File: patch-BQCA.v48-update-3.sh
# Author: Dr. Jeffrey Chijioke-Uche, IBM Computer Scientist
#
# Purpose:
#   1. Trace the Bob Shell UI error:
#        Cannot read properties of undefined (reading 'maxTokens')
#   2. Repair only BQCA-owned configuration defects that can cause Bob Shell to
#      resolve an undefined custom-mode/model record.
#   3. Never modify the Bob binary, Bob package installation, Bob service, or
#      user-global Bob configuration under $HOME/.bob.
#
# BQCA defects repaired by this patch:
#   - duplicate custom-mode slugs;
#   - custom-mode slugs containing spaces or punctuation;
#   - mode-specific rule directories whose names no longer match valid slugs.
#
# Diagnostic behavior:
#   - searches active BQCA sources for maxTokens/max_tokens/tokenLimit keys;
#   - reports, but does not modify, matching user-global Bob settings/logs;
#   - enables optional Bob Shell debug mode with:
#       BQCA_BOB_DEBUG=1 ./xLaunchpad.sh
#
# Decision boundary:
#   If the error remains after BQCA mode configuration is valid and no active
#   BQCA source contains the token-property key, the remaining defect is in Bob
#   Shell or its service/model metadata. This patch then performs no additional
#   modification.
#
# Protected assets:
#   .env, workload stores, $HOME/qiskit-v2x-env,
#   $HOME/.qiskit/qiskit-ibm.json, $HOME/.bob, and the Bob executable.
#===============================================================================

PATCH_ID="BQCA.v48-update-3"
PATCH_FILE_NAME="patch-BQCA.v48-update-3.sh"
TIMESTAMP="$(date +%Y%m%d%H%M%S)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_OVERRIDE=""
DRY_RUN=0
VALIDATE_ONLY=0
ROLLBACK_DIR=""

info() { printf '[BQCA v48-update-3][INFO] %s\n' "$*"; }
warn() { printf '[BQCA v48-update-3][WARN] %s\n' "$*" >&2; }
fail() { printf '[BQCA v48-update-3][ERROR] %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'USAGE'
BQCA v48 Update 3 - Bob Shell maxTokens Diagnostic and Mode Integrity Repair

Usage:
  ./patch-BQCA.v48-update-3.sh [options]

Options:
  --target <path>        Explicit BQCA appliance root.
  --dry-run              Display the repair plan without changing files.
  --validate-only        Validate the installed Update 3 state.
  --rollback <backup>    Restore an Update 3 backup directory.
  -h, --help             Show this help.

After installation:
  .bob/quantum-tools/bqca-bob-mode-doctor.sh report

Optional Bob Shell tracing:
  BQCA_BOB_DEBUG=1 ./xLaunchpad.sh

This patch does not modify Bob Shell software or $HOME/.bob.
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

for cmd in bash chmod cp date diff dirname find grep mkdir mktemp mv python3 rm; do
  command -v "$cmd" >/dev/null 2>&1 || fail "Required command not found: $cmd"
done

is_bqca_root() {
  local candidate="$1"
  [[ -d "$candidate/.bob" ]] || return 1
  [[ -f "$candidate/.bob/custom_modes.yaml" ]] || return 1
  [[ -d "$candidate/.bob/skills" ]] || return 1
  [[ -f "$candidate/xLaunchpad.sh" ]] || return 1
  [[ -d "$candidate/bob-quantum-store" ]] || return 1
}

resolve_bqca_root() {
  local candidate dir
  if [[ -n "$TARGET_OVERRIDE" ]]; then
    candidate="$(cd "$TARGET_OVERRIDE" 2>/dev/null && pwd -P || true)"
    [[ -n "$candidate" ]] || fail "Target path does not exist: $TARGET_OVERRIDE"
    is_bqca_root "$candidate" || fail "Target is not a valid BQCA root: $candidate"
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
CUSTOM_MODES="$BOB_ROOT/custom_modes.yaml"
XLAUNCHPAD="$BQCA_ROOT/xLaunchpad.sh"
STABLE_POLICY="$BOB_ROOT/BQCA-PRODUCTION-POLICY.md"
MODE_DOCTOR_PY="$TOOLS_DIR/bqca-bob-mode-doctor.py"
MODE_DOCTOR_SH="$TOOLS_DIR/bqca-bob-mode-doctor.sh"
BACKUP_ROOT="$BOB_ROOT/patch-backups"
BACKUP_DIR="$BACKUP_ROOT/${PATCH_ID}.${TIMESTAMP}"
PATCH_RECORD_DIR="$BOB_ROOT/patches-applied"
PATCH_RECORD_FILE="$PATCH_RECORD_DIR/${PATCH_ID}.txt"
DIAGNOSTIC_REPORT="$PATCH_RECORD_DIR/${PATCH_ID}-maxTokens-diagnostic.txt"
PREFLIGHT_MARKER="BQCA-BOB-MODE-PREFLIGHT-v48-update-3"
DEBUG_MARKER="BQCA-BOB-DEBUG-TRACE-v48-update-3"
POLICY_SHA_BEFORE=""

RULE_RENAMES=(
  "rules-WXO Agent Architect|rules-wxo-agent-architect"
  "rules-Draw.io|rules-drawio"
  "rules-GraphQL Dev|rules-graphql-dev"
)

# The duplicate slugs previously caused these modes to share one rules directory.
# After assigning unique slugs, clone the same rule content so their behavior is
# preserved instead of silently losing mode-specific rules.
RULE_CLONES=(
  "rules-code|rules-quantum-code-default"
  "rules-code|rules-quantum-code-heron"
  "rules-advanced|rules-quantum-advanced-default"
  "rules-advanced|rules-quantum-advanced"
  "rules-orchestrator|rules-quantum-smart"
)

MODE_NAME_SLUG_MAP_JSON='{
  "IBM Bob Quantum Sky™": "ask",
  "IBM Bob Quantum Code Default™": "quantum-code-default",
  "IBM Bob Quantum Code Heron™": "quantum-code-heron",
  "IBM Bob Quantum Qiskit Connector™": "code",
  "IBM Bob Quantum Advanced Default™": "quantum-advanced-default",
  "IBM Bob Quantum Advanced™": "quantum-advanced",
  "IBM Bob Quantum Advanced Implementator™": "advanced",
  "IBM Bob Quantum Smart™": "quantum-smart",
  "IBM Bob Quantum Orchestrator": "orchestrator",
  "IBM Bob Quantum Plan": "plan",
  "IBM Bob Quantum WXO Agent Architect": "wxo-agent-architect",
  "IBM Bob Quantum Draw.io": "drawio",
  "IBM Bob Quantum GraphQL Dev": "graphql-dev"
}'

backup_path() {
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
  backup_path "$CUSTOM_MODES"
  backup_path "$XLAUNCHPAD"
  backup_path "$MODE_DOCTOR_PY"
  backup_path "$MODE_DOCTOR_SH"
  backup_path "$PATCH_RECORD_FILE"
  backup_path "$DIAGNOSTIC_REPORT"

  local launcher pair old new
  while IFS= read -r -d '' launcher; do
    backup_path "$launcher"
  done < <(find "$BQCA_ROOT" -maxdepth 1 -type f -name 'bob-quantum-v*.sh' -print0)

  for pair in "${RULE_RENAMES[@]}"; do
    old="${pair%%|*}"
    new="${pair#*|}"
    backup_path "$BOB_ROOT/$old"
    backup_path "$BOB_ROOT/$new"
  done
  for pair in "${RULE_CLONES[@]}"; do
    new="${pair#*|}"
    backup_path "$BOB_ROOT/$new"
  done

  cat > "$BACKUP_DIR/BQCA-v48-update-3-backup-manifest.txt" <<MANIFEST
Patch: $PATCH_ID
Created: $(date -u '+%Y-%m-%dT%H:%M:%SZ')
Appliance root: $BQCA_ROOT
Protected assets excluded: .env, workload stores, HOME/.bob, HOME/qiskit-v2x-env, HOME/.qiskit/qiskit-ibm.json
Restore with:
  $PATCH_FILE_NAME --target "$BQCA_ROOT" --rollback "$BACKUP_DIR"
MANIFEST
}

restore_backup() {
  local backup="$1" backup_abs source rel destination pair old new
  backup_abs="$(cd "$backup" 2>/dev/null && pwd -P || true)"
  [[ -n "$backup_abs" ]] || fail "Rollback directory not found: $backup"
  [[ -f "$backup_abs/BQCA-v48-update-3-backup-manifest.txt" ]] || \
    fail "Not a BQCA v48 Update 3 backup: $backup_abs"

  info "Restoring Update 3 backup: $backup_abs"

  # Remove paths created by this patch when they were not present before.
  for destination in "$MODE_DOCTOR_PY" "$MODE_DOCTOR_SH" "$PATCH_RECORD_FILE" "$DIAGNOSTIC_REPORT"; do
    rel="${destination#$BQCA_ROOT/}"
    [[ -e "$backup_abs/$rel" ]] || rm -f "$destination"
  done

  # Remove renamed/cloned rule directories before restoring their original state.
  for pair in "${RULE_RENAMES[@]}"; do
    old="${pair%%|*}"
    new="${pair#*|}"
    rm -rf "$BOB_ROOT/$old" "$BOB_ROOT/$new"
  done
  for pair in "${RULE_CLONES[@]}"; do
    new="${pair#*|}"
    rm -rf "$BOB_ROOT/$new"
  done

  while IFS= read -r -d '' source; do
    rel="${source#$backup_abs/}"
    [[ "$rel" != "BQCA-v48-update-3-backup-manifest.txt" ]] || continue
    destination="$BQCA_ROOT/$rel"
    mkdir -p "$(dirname "$destination")"
    if [[ -d "$source" ]]; then
      mkdir -p "$destination"
    else
      cp -a "$source" "$destination"
    fi
  done < <(find "$backup_abs" -mindepth 1 -print0)

  info "Rollback complete. Bob Shell software and protected assets were not touched."
}

if [[ -n "$ROLLBACK_DIR" ]]; then
  restore_backup "$ROLLBACK_DIR"
  exit 0
fi

info "Resolved BQCA root: $BQCA_ROOT"
info "Patch identity: $PATCH_ID"
info "Scope: repair BQCA mode configuration and add diagnostics; never patch Bob Shell software"
info "Protected assets: .env, workload stores, HOME/.bob, home Qiskit environment, and Qiskit account JSON"

if [[ -f "$STABLE_POLICY" ]]; then
  POLICY_SHA_BEFORE="$(python3 - "$STABLE_POLICY" <<'PY'
import hashlib, pathlib, sys
print(hashlib.sha256(pathlib.Path(sys.argv[1]).read_bytes()).hexdigest())
PY
)"
fi

if ((DRY_RUN)); then
  cat <<'DRY'
[BQCA v48-update-3][DRY-RUN] Planned changes:
  1. Back up BQCA custom modes, launcher files, affected rules, and new diagnostics.
  2. Validate the active BQCA tree for maxTokens/max_tokens/tokenLimit references.
  3. Normalize duplicate custom-mode slugs while preserving current effective menu behavior.
  4. Normalize mode slugs containing spaces or punctuation.
  5. Rename three mode-specific rules directories to match valid slugs.
  6. Install a mode/configuration doctor and launch-time mode preflight.
  7. Add optional Bob Shell debug tracing through BQCA_BOB_DEBUG=1.
  8. Generate a diagnostic report that distinguishes BQCA configuration from Bob Shell runtime defects.
  9. Do not modify the Bob executable, Bob installation, user-global Bob settings, .env, or Qiskit assets.
DRY
  exit 0
fi

write_mode_doctor_py() {
  cat > "$MODE_DOCTOR_PY" <<'PY'
#!/usr/bin/env python3
# BQCA-ACTIVE-CENTRAL-POLICY:BEGIN
# Resolve and follow .bob/BQCA-PRODUCTION-POLICY.md through the active-policy
# registry. This diagnostic never overrides or duplicates the central policy.
# BQCA-ACTIVE-CENTRAL-POLICY:END
"""BQCA custom-mode and Bob Shell max-token-property diagnostic.

This tool never modifies Bob Shell, $HOME/.bob, or BQCA files. It validates
project custom-mode integrity and reports whether the observed token-property
TypeError has a matching reference in active BQCA sources.
"""
from __future__ import annotations

import argparse
import collections
import json
import os
import pathlib
import re
import subprocess
import sys
from datetime import datetime, timezone
from typing import Iterable

VALID_SLUG = re.compile(r"^[A-Za-z0-9-]+$")
SLUG_LINE = re.compile(r"^  - slug:\s*(.+?)\s*$")
NAME_LINE = re.compile(r"^    name:\s*(.+?)\s*$")
TOKEN_PATTERNS = [
    re.compile(r"\b" + "max" + "Tokens" + r"\b"),
    re.compile(r"\b" + "max" + "_tokens" + r"\b"),
    re.compile(r"\b" + "token" + "Limit" + r"\b"),
    re.compile(r"\b" + "token" + "_limit" + r"\b"),
]


def unquote(value: str) -> str:
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in {'"', "'"}:
        return value[1:-1]
    return value


def parse_modes(path: pathlib.Path) -> list[dict[str, object]]:
    text = path.read_text(encoding="utf-8")
    records: list[dict[str, object]] = []
    current: dict[str, object] | None = None
    for lineno, line in enumerate(text.splitlines(), 1):
        match = SLUG_LINE.match(line)
        if match:
            if current:
                records.append(current)
            current = {"slug": unquote(match.group(1)), "name": "", "line": lineno}
            continue
        if current:
            match = NAME_LINE.match(line)
            if match and not current["name"]:
                current["name"] = unquote(match.group(1))
    if current:
        records.append(current)
    return records


def active_project_files(root: pathlib.Path, doctor: pathlib.Path) -> Iterable[pathlib.Path]:
    excluded_dirs = {
        ".git", "patch-backups", "policy-history", "__pycache__", ".venv", "venv",
        "qiskit-v2x-env", "node_modules", "bob-quantum-store", "bob-quantum-designs",
        "runtime", "patches-applied",
    }
    allowed_suffixes = {".sh", ".py", ".json", ".yaml", ".yml", ".md", ".txt"}
    candidates = [root / "xLaunchpad.sh", root / ".bob" / "custom_modes.yaml"]
    candidates.extend(root.glob("bob-quantum-v*.sh"))
    bob = root / ".bob"
    if bob.is_dir():
        for path in bob.rglob("*"):
            if not path.is_file() or path == doctor:
                continue
            rel_parts = path.relative_to(root).parts
            if any(part in excluded_dirs for part in rel_parts):
                continue
            if path.suffix.lower() in allowed_suffixes:
                candidates.append(path)
    seen: set[pathlib.Path] = set()
    for path in candidates:
        try:
            resolved = path.resolve()
        except OSError:
            continue
        if resolved in seen or not path.is_file():
            continue
        seen.add(resolved)
        yield path


def scan_patterns(paths: Iterable[pathlib.Path]) -> list[dict[str, object]]:
    hits: list[dict[str, object]] = []
    for path in paths:
        try:
            lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
        except OSError:
            continue
        for lineno, line in enumerate(lines, 1):
            if any(pattern.search(line) for pattern in TOKEN_PATTERNS):
                snippet = line.strip()
                snippet = re.sub(r"(?i)(bearer\s+)[^\s\"']+", r"\1<REDACTED>", snippet)
                snippet = re.sub(r"(?i)(api[_-]?key\s*[:=]\s*)[^,\s\"']+", r"\1<REDACTED>", snippet)
                hits.append({"path": str(path), "line": lineno, "snippet": snippet[:240]})
    return hits


def user_bob_files(home: pathlib.Path) -> Iterable[pathlib.Path]:
    for rel in (".bob/settings.json", ".bob/config.json", ".bob/custom_modes.yaml"):
        path = home / rel
        if path.is_file():
            yield path


def recent_log_hits(home: pathlib.Path) -> list[dict[str, object]]:
    logs = home / ".bob" / "logs"
    if not logs.is_dir():
        return []
    files = sorted((p for p in logs.rglob("*") if p.is_file()), key=lambda p: p.stat().st_mtime, reverse=True)[:20]
    return scan_patterns(files)


def bob_identity() -> dict[str, str]:
    result = {"binary": "NOT FOUND", "version": "UNKNOWN"}
    try:
        which = subprocess.run(["bash", "-lc", "command -v bob"], text=True, capture_output=True, check=False)
        if which.returncode == 0 and which.stdout.strip():
            result["binary"] = which.stdout.strip()
            version = subprocess.run([which.stdout.strip(), "--version"], text=True, capture_output=True, check=False, timeout=15)
            output = (version.stdout or version.stderr).strip()
            if output:
                result["version"] = output.splitlines()[0][:200]
    except Exception:
        pass
    return result


def inspect(root: pathlib.Path) -> dict[str, object]:
    modes_path = root / ".bob" / "custom_modes.yaml"
    doctor = root / ".bob" / "quantum-tools" / "bqca-bob-mode-doctor.py"
    modes = parse_modes(modes_path)
    counts = collections.Counter(str(item["slug"]) for item in modes)
    duplicates = {slug: count for slug, count in counts.items() if count > 1}
    invalid = [item for item in modes if not VALID_SLUG.fullmatch(str(item["slug"]))]
    project_hits = scan_patterns(active_project_files(root, doctor))
    home = pathlib.Path.home()
    global_hits = scan_patterns(user_bob_files(home))
    logs = recent_log_hits(home)
    identity = bob_identity()
    local_defect = bool(duplicates or invalid or project_hits)
    return {
        "generated": datetime.now(timezone.utc).isoformat(),
        "root": str(root),
        "mode_count": len(modes),
        "modes": modes,
        "duplicate_slugs": duplicates,
        "invalid_slugs": invalid,
        "project_token_property_hits": project_hits,
        "user_bob_token_property_hits": global_hits,
        "bob_log_token_property_hits": logs,
        "bob": identity,
        "bqca_mode_configuration_valid": not duplicates and not invalid,
        "active_bqca_token_property_reference": bool(project_hits),
        "classification": (
            "BQCA_PROJECT_CONFIGURATION" if local_defect else "BOB_SHELL_OR_SERVICE_IF_ERROR_PERSISTS"
        ),
    }


def print_report(data: dict[str, object]) -> None:
    print("=" * 88)
    print("BQCA BOB SHELL TOKEN-PROPERTY DIAGNOSTIC REPORT")
    print("=" * 88)
    print(f"Generated                    : {data['generated']}")
    print(f"BQCA root                    : {data['root']}")
    print(f"Bob binary                   : {data['bob']['binary']}")
    print(f"Bob version                  : {data['bob']['version']}")
    print(f"Custom modes                 : {data['mode_count']}")
    print(f"Duplicate slugs              : {len(data['duplicate_slugs'])}")
    print(f"Invalid slugs                : {len(data['invalid_slugs'])}")
    print(f"Active BQCA token-key hits   : {len(data['project_token_property_hits'])}")
    print(f"User Bob config key hits     : {len(data['user_bob_token_property_hits'])}")
    print(f"Recent Bob log key hits      : {len(data['bob_log_token_property_hits'])}")
    print(f"Classification               : {data['classification']}")
    print("-" * 88)
    if data["duplicate_slugs"]:
        print("DUPLICATE CUSTOM-MODE SLUGS")
        for slug, count in sorted(data["duplicate_slugs"].items()):
            print(f"  - {slug}: {count}")
    if data["invalid_slugs"]:
        print("INVALID CUSTOM-MODE SLUGS")
        for item in data["invalid_slugs"]:
            print(f"  - line {item['line']}: {item['slug']} ({item['name']})")
    for title, key in (
        ("ACTIVE BQCA TOKEN-PROPERTY REFERENCES", "project_token_property_hits"),
        ("USER-GLOBAL BOB CONFIG REFERENCES (REPORT ONLY)", "user_bob_token_property_hits"),
        ("RECENT BOB LOG REFERENCES (REPORT ONLY)", "bob_log_token_property_hits"),
    ):
        values = data[key]
        if values:
            print(title)
            for item in values:
                print(f"  - {item['path']}:{item['line']}: {item['snippet']}")
    print("-" * 88)
    if data["classification"] == "BOB_SHELL_OR_SERVICE_IF_ERROR_PERSISTS":
        print("TAKEAWAY: BQCA mode configuration is valid and no active BQCA source defines the")
        print("token-property key. If the UI TypeError still occurs, it is in Bob Shell or its")
        print("service/model metadata. This tool does not modify Bob software.")
    else:
        print("TAKEAWAY: A BQCA-owned mode/configuration defect was detected. Apply or reapply")
        print("patch-BQCA.v48-update-3.sh, restart Bob Shell, and test again.")
    print("=" * 88)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("check", "report", "json"))
    parser.add_argument("--root", type=pathlib.Path)
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args()
    root = (args.root or pathlib.Path(__file__).resolve().parents[2]).resolve()
    data = inspect(root)
    if args.command == "json":
        print(json.dumps(data, indent=2, ensure_ascii=False))
    elif args.command == "report":
        print_report(data)
    elif not args.quiet:
        print(
            "BQCA_BOB_MODE_CONFIG=" + ("PASS" if data["bqca_mode_configuration_valid"] else "FAIL")
        )
        print(f"BQCA_ACTIVE_TOKEN_PROPERTY_HITS={len(data['project_token_property_hits'])}")
        print(f"BQCA_DIAGNOSTIC_CLASSIFICATION={data['classification']}")
    return 0 if data["bqca_mode_configuration_valid"] and not data["project_token_property_hits"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
PY
  chmod 755 "$MODE_DOCTOR_PY"
}

write_mode_doctor_sh() {
  cat > "$MODE_DOCTOR_SH" <<'SH'
#!/usr/bin/env bash
set -Eeuo pipefail
# BQCA-ACTIVE-CENTRAL-POLICY:BEGIN
# Resolve and follow .bob/BQCA-PRODUCTION-POLICY.md through the active-policy
# registry. This wrapper never overrides or duplicates the central policy.
# BQCA-ACTIVE-CENTRAL-POLICY:END
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BQCA_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
exec python3 "$SCRIPT_DIR/bqca-bob-mode-doctor.py" "$@" --root "$BQCA_ROOT"
SH
  chmod 755 "$MODE_DOCTOR_SH"
}

patch_custom_modes() {
  local tmp
  tmp="$(mktemp)"
  python3 - "$CUSTOM_MODES" "$tmp" "$MODE_NAME_SLUG_MAP_JSON" <<'PY'
from __future__ import annotations
import collections, json, pathlib, re, sys
source = pathlib.Path(sys.argv[1])
out = pathlib.Path(sys.argv[2])
mapping = json.loads(sys.argv[3])
text = source.read_text(encoding="utf-8")
parts = re.split(r"(?m)(?=^  - slug:\s*)", text)
result = [parts[0]]
changed = []
for record in parts[1:]:
    name_match = re.search(r"(?m)^    name:\s*(.+?)\s*$", record)
    slug_match = re.search(r"(?m)^  - slug:\s*(.+?)\s*$", record)
    if not name_match or not slug_match:
        raise SystemExit("Malformed custom-mode record")
    name = name_match.group(1).strip().strip('"\'')
    old_slug = slug_match.group(1).strip().strip('"\'')
    new_slug = mapping.get(name, old_slug)
    if new_slug != old_slug:
        record = re.sub(r"(?m)^  - slug:\s*.+?$", f"  - slug: {new_slug}", record, count=1)
        changed.append((name, old_slug, new_slug))
    result.append(record)
updated = "".join(result)
slugs = [m.group(1).strip().strip('"\'') for m in re.finditer(r"(?m)^  - slug:\s*(.+?)\s*$", updated)]
counts = collections.Counter(slugs)
duplicates = {key: value for key, value in counts.items() if value > 1}
invalid = [slug for slug in slugs if not re.fullmatch(r"[A-Za-z0-9-]+", slug)]
if duplicates or invalid:
    raise SystemExit(f"Custom-mode normalization incomplete: duplicates={duplicates} invalid={invalid}")
out.write_text(updated, encoding="utf-8")
for name, old, new in changed:
    print(f"mode_slug: {old!r} -> {new!r} ({name})")
print(f"modes={len(slugs)} changed={len(changed)}")
PY
  cp "$tmp" "$CUSTOM_MODES"
  rm -f "$tmp"
  chmod 644 "$CUSTOM_MODES"
}

rename_rule_directories() {
  local pair old new source target
  for pair in "${RULE_RENAMES[@]}"; do
    old="${pair%%|*}"
    new="${pair#*|}"
    source="$BOB_ROOT/$old"
    target="$BOB_ROOT/$new"
    if [[ -d "$source" ]]; then
      if [[ -e "$target" ]]; then
        if diff -qr "$source" "$target" >/dev/null 2>&1; then
          rm -rf "$source"
        else
          fail "Cannot normalize rule directory; both paths exist with different content: $old and $new"
        fi
      else
        mv "$source" "$target"
      fi
      info "Normalized rule directory: $old -> $new"
    fi
  done

  # Preserve the prior shared-rule behavior for modes that now have unique slugs.
  for pair in "${RULE_CLONES[@]}"; do
    old="${pair%%|*}"
    new="${pair#*|}"
    source="$BOB_ROOT/$old"
    target="$BOB_ROOT/$new"
    [[ -d "$source" ]] || fail "Source rules directory is missing: $old"
    if [[ ! -d "$target" ]]; then
      cp -a "$source" "$target"
      info "Created rules compatibility directory: $new (from $old)"
    fi
  done

  python3 - "$BOB_ROOT" <<'PY'
from __future__ import annotations
import pathlib, sys
root = pathlib.Path(sys.argv[1])
replacements = {
    "rules-WXO Agent Architect": "rules-wxo-agent-architect",
    "rules-Draw.io": "rules-drawio",
    "rules-GraphQL Dev": "rules-graphql-dev",
}
allowed = {".md", ".txt", ".sh", ".py", ".yaml", ".yml", ".json"}
for path in root.rglob("*"):
    if not path.is_file() or path.suffix.lower() not in allowed:
        continue
    parts = path.relative_to(root).parts
    if any(part in {"patch-backups", "policy-history", "__pycache__", "runtime", "patches-applied"} for part in parts):
        continue
    text = path.read_text(encoding="utf-8", errors="replace")
    changed = text
    for old, new in replacements.items():
        changed = changed.replace(old, new)
    if changed != text:
        path.write_text(changed, encoding="utf-8")
PY
}

patch_xlaunchpad_preflight() {
  local tmp
  tmp="$(mktemp)"
  python3 - "$XLAUNCHPAD" "$tmp" "$PREFLIGHT_MARKER" <<'PY'
from __future__ import annotations
import pathlib, re, sys
src = pathlib.Path(sys.argv[1])
out = pathlib.Path(sys.argv[2])
marker = sys.argv[3]
text = src.read_text(encoding="utf-8")
text = re.sub(
    rf"(?ms)^# {re.escape(marker)}:BEGIN\n.*?^# {re.escape(marker)}:END\n?",
    "",
    text,
)
block = f'''# {marker}:BEGIN
_BQCA_BOB_MODE_DOCTOR="${{SCRIPT_DIR}}/.bob/quantum-tools/bqca-bob-mode-doctor.sh"
if [[ ! -x "${{_BQCA_BOB_MODE_DOCTOR}}" ]]; then
  printf '[BQCA][ERROR] Bob mode/configuration doctor is missing: %s\\n' \\
    "${{_BQCA_BOB_MODE_DOCTOR}}" >&2
  exit 1
fi
if ! "${{_BQCA_BOB_MODE_DOCTOR}}" check --quiet; then
  printf '[BQCA][ERROR] Invalid BQCA custom-mode configuration. Run: %s report\\n' \\
    "${{_BQCA_BOB_MODE_DOCTOR}}" >&2
  exit 1
fi
# {marker}:END
'''
needle = 'SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"\n'
if needle not in text:
    raise SystemExit("Unable to locate SCRIPT_DIR assignment in xLaunchpad.sh")
text = text.replace(needle, needle + "\n" + block + "\n", 1)
out.write_text(text, encoding="utf-8")
PY
  cp "$tmp" "$XLAUNCHPAD"
  rm -f "$tmp"
  chmod 755 "$XLAUNCHPAD"
}

patch_bob_runtime_debug() {
  local launcher tmp
  while IFS= read -r -d '' launcher; do
    tmp="$(mktemp)"
    python3 - "$launcher" "$tmp" "$DEBUG_MARKER" <<'PY'
from __future__ import annotations
import pathlib, re, sys
src = pathlib.Path(sys.argv[1])
out = pathlib.Path(sys.argv[2])
marker = sys.argv[3]
text = src.read_text(encoding="utf-8")
text = re.sub(
    rf"(?ms)^# {re.escape(marker)}:BEGIN\n.*?^# {re.escape(marker)}:END\n?",
    "",
    text,
)
block = f'''# {marker}:BEGIN
# Optional Bob Shell diagnostics. This changes no default behavior.
# Run: BQCA_BOB_DEBUG=1 ./xLaunchpad.sh
if [[ "${{BQCA_BOB_DEBUG:-0}}" == "1" ]]; then
  BOB_QUANTUM_TOOL_FLAGS+=(--debug)
fi
# {marker}:END
'''
pattern = re.compile(r"(?ms)(^BOB_QUANTUM_TOOL_FLAGS=\(\n.*?^\)\n)")
match = pattern.search(text)
if not match:
    raise SystemExit(f"Unable to locate BOB_QUANTUM_TOOL_FLAGS in {src}")
text = text[:match.end()] + "\n" + block + text[match.end():]
out.write_text(text, encoding="utf-8")
PY
    cp "$tmp" "$launcher"
    rm -f "$tmp"
    chmod 755 "$launcher"
  done < <(find "$BQCA_ROOT" -maxdepth 1 -type f -name 'bob-quantum-v*.sh' -print0)
}

write_patch_record() {
  mkdir -p "$PATCH_RECORD_DIR"
  "$MODE_DOCTOR_SH" report > "$DIAGNOSTIC_REPORT" 2>&1 || true
  chmod 644 "$DIAGNOSTIC_REPORT"
  cat > "$PATCH_RECORD_FILE" <<RECORD
Patch: $PATCH_ID
Applied: $(date -u '+%Y-%m-%dT%H:%M:%SZ')
Root: $BQCA_ROOT
Backup: $BACKUP_DIR
Purpose: diagnose Bob Shell maxTokens TypeError and repair BQCA custom-mode identity defects
BQCA custom modes: unique and slug-valid
Bob software modified: No
User-global HOME/.bob modified: No
Central BQCA policy modified: No
Optional debug command: BQCA_BOB_DEBUG=1 ./xLaunchpad.sh
Diagnostic report: ${DIAGNOSTIC_REPORT#$BQCA_ROOT/}
RECORD
  chmod 644 "$PATCH_RECORD_FILE"
}

validate_installation() {
  local failures=0 launcher count old new pair policy_sha_after

  [[ -x "$MODE_DOCTOR_SH" ]] || { warn "Missing executable mode doctor shell wrapper"; failures=$((failures+1)); }
  [[ -x "$MODE_DOCTOR_PY" ]] || { warn "Missing executable mode doctor Python tool"; failures=$((failures+1)); }
  python3 -m py_compile "$MODE_DOCTOR_PY" || failures=$((failures+1))
  bash -n "$MODE_DOCTOR_SH" || failures=$((failures+1))
  bash -n "$XLAUNCHPAD" || failures=$((failures+1))

  if ! "$MODE_DOCTOR_SH" check --quiet; then
    warn "BQCA custom-mode or active-project token-property validation failed"
    "$MODE_DOCTOR_SH" report >&2 || true
    failures=$((failures+1))
  fi

  count="$(grep -c "# ${PREFLIGHT_MARKER}:BEGIN" "$XLAUNCHPAD" || true)"
  [[ "$count" -eq 1 ]] || { warn "xLaunchpad mode preflight count is $count, expected 1"; failures=$((failures+1)); }

  while IFS= read -r -d '' launcher; do
    bash -n "$launcher" || failures=$((failures+1))
    count="$(grep -c "# ${DEBUG_MARKER}:BEGIN" "$launcher" || true)"
    [[ "$count" -eq 1 ]] || { warn "Debug marker count is $count in ${launcher#$BQCA_ROOT/}"; failures=$((failures+1)); }
  done < <(find "$BQCA_ROOT" -maxdepth 1 -type f -name 'bob-quantum-v*.sh' -print0)

  for pair in "${RULE_RENAMES[@]}"; do
    old="${pair%%|*}"
    new="${pair#*|}"
    [[ ! -e "$BOB_ROOT/$old" ]] || { warn "Legacy invalid rule directory remains: $old"; failures=$((failures+1)); }
    [[ -d "$BOB_ROOT/$new" ]] || { warn "Normalized rule directory is missing: $new"; failures=$((failures+1)); }
  done
  for pair in "${RULE_CLONES[@]}"; do
    new="${pair#*|}"
    [[ -d "$BOB_ROOT/$new" ]] || { warn "Rules compatibility directory is missing: $new"; failures=$((failures+1)); }
  done

  if [[ -n "$POLICY_SHA_BEFORE" && -f "$STABLE_POLICY" ]]; then
    policy_sha_after="$(python3 - "$STABLE_POLICY" <<'PY'
import hashlib, pathlib, sys
print(hashlib.sha256(pathlib.Path(sys.argv[1]).read_bytes()).hexdigest())
PY
)"
    [[ "$policy_sha_after" == "$POLICY_SHA_BEFORE" ]] || {
      warn "The active central policy changed unexpectedly"
      failures=$((failures+1))
    }
  fi

  if ((failures)); then
    fail "v48 Update 3 validation failed with $failures issue(s)."
  fi

  info "Validation passed: BQCA mode slugs are unique/valid, no active BQCA token-property key exists, and optional Bob debug tracing is installed."
}

if ((VALIDATE_ONLY)); then
  validate_installation
  exit 0
fi

create_backup
mkdir -p "$TOOLS_DIR" "$PATCH_RECORD_DIR"
write_mode_doctor_py
write_mode_doctor_sh
patch_custom_modes
rename_rule_directories
patch_xlaunchpad_preflight
patch_bob_runtime_debug
write_patch_record
validate_installation

info "Patch $PATCH_ID applied successfully."
info "Backup: $BACKUP_DIR"
info "Diagnostic report: ${DIAGNOSTIC_REPORT#$BQCA_ROOT/}"
info "Run optional Bob debug tracing with: BQCA_BOB_DEBUG=1 ./xLaunchpad.sh"
info "Bob Shell software and user-global Bob configuration were not modified."
