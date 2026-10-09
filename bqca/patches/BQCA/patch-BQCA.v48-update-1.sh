#!/usr/bin/env bash
set -Eeuo pipefail

#===============================================================================
# BQCA Active Central Policy Listener and Automatic Compliance Patch
# File: patch-BQCA.v48-update-1.sh
# Author: Dr. Jeffrey Chijioke-Uche, IBM Computer Scientist
#
# Purpose:
#   1. Make --validate-design and --validate-code resolve the active central
#      policy on every invocation instead of hardcoding v48 or any future
#      policy version.
#   2. Embed a machine-readable validation contract in the active policy. The
#      active policy owns the required/forbidden needles and semantic checks.
#   3. Install a version-neutral active-policy resolver/listener, dynamic design
#      and code validator, policy doctor, and automatic compliance-report watcher.
#   4. Ensure every governed design and Python code artifact receives a
#      same-directory policy-compliance report:
#        <name>-design-policy-compliance.txt
#        <name>-code-policy-compliance.txt
#   5. Preserve all v48 concepts and execution behavior. This patch does not
#      redesign direct execution, Qiskit configuration, the home environment,
#      notebook generation, result output, or the offline knowledgebase.
#
# Protected assets:
#   The installer never reads, copies, backs up, changes, chmods, removes, or
#   restores .env, $HOME/qiskit-v2x-env, or $HOME/.qiskit/qiskit-ibm.json.
#   Source design/code artifacts are not rewritten. The only files created in
#   the governed stores are the required compliance reports.
#===============================================================================

PATCH_ID="BQCA.v48-update-1"
PATCH_FILE_NAME="patch-BQCA.v48-update-1.sh"
TIMESTAMP="$(date +%Y%m%d%H%M%S)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
TARGET_OVERRIDE=""
DRY_RUN=0
VALIDATE_ONLY=0
ROLLBACK_DIR=""

info() { printf '[BQCA v48-update-1][INFO] %s\n' "$*"; }
warn() { printf '[BQCA v48-update-1][WARN] %s\n' "$*" >&2; }
fail() { printf '[BQCA v48-update-1][ERROR] %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'USAGE'
BQCA v48 Update 1 - Active Central Policy Listener and Compliance Reports

Usage:
  ./patch-BQCA.v48-update-1.sh [options]

Options:
  --target <path>        Explicit BQCA appliance root.
  --dry-run              Display the patch plan without changing files.
  --validate-only        Validate the installed Update 1 behavior.
  --rollback <backup>    Restore an Update 1 backup directory.
  -h, --help             Show this help.

Expected placement:
  <BQCA-root>/patches/BQCA/patch-BQCA.v48-update-1.sh
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

for cmd in bash chmod cmp cp date dirname find grep mkdir mktemp mv python3 rm sha256sum; do
  command -v "$cmd" >/dev/null 2>&1 || fail "Required command not found: $cmd"
done

is_bqca_root() {
  local candidate="$1"
  [[ -d "$candidate/.bob" ]] || return 1
  [[ -f "$candidate/.bob/BQCA-ACTIVE-POLICY-REGISTRY.json" ]] || return 1
  [[ -f "$candidate/.bob/custom_modes.yaml" ]] || return 1
  [[ -d "$candidate/.bob/skills" ]] || return 1
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
RUNTIME_DIR="$BOB_ROOT/runtime"
DESIGN_STORE="$BQCA_ROOT/bob-quantum-designs"
CODE_STORE="$BQCA_ROOT/bob-quantum-store"
CUSTOM_MODES="$BOB_ROOT/custom_modes.yaml"
XLAUNCHPAD="$BQCA_ROOT/xLaunchpad.sh"
POLICY_FILE="$BOB_ROOT/BQCA-PRODUCTION-POLICY.md"
VERSIONED_POLICY_FILE="$BOB_ROOT/BQCA-PRODUCTION-POLICY-v48.md"
REGISTRY_FILE="$BOB_ROOT/BQCA-ACTIVE-POLICY-REGISTRY.json"
ACTIVE_POLICY_PY="$TOOLS_DIR/bqca_active_policy.py"
ACTIVE_POLICY_SH="$TOOLS_DIR/bqca-active-policy-listener.sh"
DYNAMIC_VALIDATOR="$TOOLS_DIR/bqca-dynamic-validator.py"
DESIGN_WRAPPER="$TOOLS_DIR/qiskit-design-policy-check.py"
CODE_WRAPPER="$TOOLS_DIR/qiskit-code-policy-check.py"
DOCTOR_PY="$TOOLS_DIR/bqca-policy-doctor.py"
DOCTOR_SH="$TOOLS_DIR/bqca-policy-doctor.sh"
COMPLIANCE_WATCHER="$TOOLS_DIR/bqca-policy-compliance-watcher.py"
COMPLIANCE_CONTROLLER="$TOOLS_DIR/bqca-policy-compliance.sh"
QISKIT_CONNECTOR="$TOOLS_DIR/qiskit-connector.sh"
QUALITY_GUARD="$TOOLS_DIR/qca-code-quality-guard.sh"
BACKUP_ROOT="$BOB_ROOT/patch-backups"
BACKUP_DIR="$BACKUP_ROOT/${PATCH_ID}.${TIMESTAMP}"
PATCH_RECORD_DIR="$BOB_ROOT/patches-applied"
PATCH_RECORD_FILE="$PATCH_RECORD_DIR/${PATCH_ID}.txt"
STATE_CACHE="$RUNTIME_DIR/BQCA-active-policy-state.json"

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
  : > "$BACKUP_DIR/preexisting-compliance-reports.txt"
  for file in \
    "$POLICY_FILE" "$VERSIONED_POLICY_FILE" "$REGISTRY_FILE" "$CUSTOM_MODES" \
    "$XLAUNCHPAD" "$ACTIVE_POLICY_PY" "$ACTIVE_POLICY_SH" "$DYNAMIC_VALIDATOR" \
    "$DESIGN_WRAPPER" "$CODE_WRAPPER" "$DOCTOR_PY" "$DOCTOR_SH" \
    "$COMPLIANCE_WATCHER" "$COMPLIANCE_CONTROLLER" "$QISKIT_CONNECTOR" "$QUALITY_GUARD"; do
    backup_file "$file"
  done
  while IFS= read -r -d '' file; do backup_file "$file"; done < <(
    find "$BOB_ROOT" -maxdepth 5 -type f \( -path '*/rules-*/*' -o -path '*/skills/*' -o -path '*/quantum-tools/*' \) -print0
  )
  while IFS= read -r -d '' file; do backup_file "$file"; done < <(
    find "$BQCA_ROOT" -maxdepth 1 -type f -name 'bob-quantum-v*.sh' -print0
  )
  while IFS= read -r -d '' file; do
    printf '%s\n' "${file#$BQCA_ROOT/}" >> "$BACKUP_DIR/preexisting-compliance-reports.txt"
    backup_file "$file"
  done < <(find "$DESIGN_STORE" "$CODE_STORE" -type f -name '*-policy-compliance.txt' -print0 2>/dev/null)
  cat > "$BACKUP_DIR/BQCA-v48-update-1-backup-manifest.txt" <<MANIFEST
Patch: $PATCH_ID
Created: $(date -u '+%Y-%m-%dT%H:%M:%SZ')
Appliance root: $BQCA_ROOT
Protected assets excluded: .env, HOME qiskit-v2x-env, HOME .qiskit/qiskit-ibm.json
Source design/code artifacts are not modified.
Restore with:
  $PATCH_FILE_NAME --target "$BQCA_ROOT" --rollback "$BACKUP_DIR"
MANIFEST
}

restore_backup() {
  local backup="$1" backup_abs source rel destination
  backup_abs="$(cd "$backup" 2>/dev/null && pwd -P || true)"
  [[ -n "$backup_abs" ]] || fail "Rollback directory not found: $backup"
  [[ -f "$backup_abs/BQCA-v48-update-1-backup-manifest.txt" ]] || fail "Not a BQCA v48 Update 1 backup: $backup_abs"
  "$COMPLIANCE_CONTROLLER" stop >/dev/null 2>&1 || true
  info "Restoring Update 1 backup: $backup_abs"
  while IFS= read -r -d '' source; do
    rel="${source#$backup_abs/}"
    case "$rel" in
      BQCA-v48-update-1-backup-manifest.txt|preexisting-compliance-reports.txt) continue ;;
    esac
    destination="$BQCA_ROOT/$rel"
    mkdir -p "$(dirname "$destination")"
    cp -a "$source" "$destination"
  done < <(find "$backup_abs" -mindepth 1 -type f -print0)
  for destination in \
    "$ACTIVE_POLICY_PY" "$ACTIVE_POLICY_SH" "$DYNAMIC_VALIDATOR" \
    "$DESIGN_WRAPPER" "$CODE_WRAPPER" "$DOCTOR_PY" "$DOCTOR_SH" \
    "$COMPLIANCE_WATCHER" "$COMPLIANCE_CONTROLLER" "$STATE_CACHE"; do
    rel="${destination#$BQCA_ROOT/}"
    [[ -e "$backup_abs/$rel" ]] || rm -f "$destination"
  done
  if [[ -f "$backup_abs/preexisting-compliance-reports.txt" ]]; then
    while IFS= read -r -d '' destination; do
      rel="${destination#$BQCA_ROOT/}"
      if ! grep -Fxq "$rel" "$backup_abs/preexisting-compliance-reports.txt"; then
        rm -f "$destination"
      fi
    done < <(find "$DESIGN_STORE" "$CODE_STORE" -type f -name '*-policy-compliance.txt' -print0 2>/dev/null)
  fi
  [[ -e "$backup_abs/${PATCH_RECORD_FILE#$BQCA_ROOT/}" ]] || rm -f "$PATCH_RECORD_FILE"
  rm -f "$RUNTIME_DIR/bqca-policy-compliance.pid"
  info "Rollback complete. Protected assets and source artifacts were not touched."
}

if [[ -n "$ROLLBACK_DIR" ]]; then
  restore_backup "$ROLLBACK_DIR"
  exit 0
fi

info "Resolved BQCA root: $BQCA_ROOT"
info "Patch identity: $PATCH_ID"
info "Protected assets: .env, HOME qiskit-v2x-env, and qiskit-ibm.json"

verify_v48_baseline() {
  python3 - "$BQCA_ROOT" <<'PY'
import hashlib, json, pathlib, sys
root = pathlib.Path(sys.argv[1])
registry_path = root / '.bob/BQCA-ACTIVE-POLICY-REGISTRY.json'
registry = json.loads(registry_path.read_text(encoding='utf-8'))
version = str(registry.get('active_version') or registry.get('active_authority', {}).get('version') or '')
if version != 'v48':
    raise SystemExit(f'BQCA v48 is required; active policy is {version!r}')
stable = root / '.bob/BQCA-PRODUCTION-POLICY.md'
versioned = root / '.bob/BQCA-PRODUCTION-POLICY-v48.md'
if not stable.is_file() or not versioned.is_file():
    raise SystemExit('BQCA v48 stable/versioned policy files are missing')
if stable.read_bytes() != versioned.read_bytes():
    raise SystemExit('BQCA v48 stable/versioned policy files differ')
actual = hashlib.sha256(stable.read_bytes()).hexdigest()
expected = str(registry.get('policy_sha256') or registry.get('canonical_policy_sha256') or registry.get('active_authority', {}).get('policy_sha256') or '')
if expected and expected != actual:
    raise SystemExit('BQCA v48 registry policy hash does not match the active policy')
PY
}

verify_v48_baseline || fail "The BQCA v48 baseline is not internally consistent"

if ((DRY_RUN)); then
  cat <<'DRY'
[BQCA v48-update-1][DRY-RUN] Planned changes:
  1. Preserve the active v48 policy concepts and embed a machine-readable
     design/code validation contract in the active policy.
  2. Install a version-neutral active-policy resolver/listener that reloads the
     registry, policy, hash, and validation contract on every invocation.
  3. Replace design/code validator implementations with version-neutral wrappers
     that delegate to one dynamic validation engine.
  4. Make qiskit-connector.sh --validate-design and --validate-code synchronize
     with the active policy before every validation.
  5. Make bqca-policy-doctor.sh resolve the active policy dynamically.
  6. Install automatic design/code compliance-report monitoring and a final
     synchronous sweep from xLaunchpad.sh.
  7. Create <name>-design-policy-compliance.txt and
     <name>-code-policy-compliance.txt beside governed artifacts.
  8. Replace version-specific awareness blocks in custom modes, rules, skills,
     tools, and knowledgebase guidance with one version-neutral policy binding.
  9. Preserve direct execution, notebooks, account configuration, the Qiskit
     environment, result capture, Hello World scope, and knowledgebase behavior.
DRY
  exit 0
fi

write_active_policy_py() {
  cat > "$ACTIVE_POLICY_PY" <<'PY_BQCA_ACTIVE_POLICY'
#!/usr/bin/env python3
"""Dynamic BQCA active-policy resolver and validation-contract listener.

This module is intentionally version-neutral. It resolves the currently active
policy from .bob/BQCA-ACTIVE-POLICY-REGISTRY.json every time it is invoked,
verifies the stable/versioned policy pair and SHA-256, reads the validation
contract embedded in the active policy, and refreshes a runtime cache whenever
policy identity or content changes.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import pathlib
import re
import sys
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any

CONTRACT_BEGIN = "<!-- BQCA-ACTIVE-VALIDATION-CONTRACT:BEGIN -->"
CONTRACT_END = "<!-- BQCA-ACTIVE-VALIDATION-CONTRACT:END -->"
DEFAULT_REGISTRY = pathlib.Path(".bob/BQCA-ACTIVE-POLICY-REGISTRY.json")
DEFAULT_CACHE = pathlib.Path(".bob/runtime/BQCA-active-policy-state.json")


class PolicyError(RuntimeError):
    """Raised when the active policy package is invalid or inconsistent."""


@dataclass(frozen=True)
class ActivePolicyState:
    root: pathlib.Path
    registry_path: pathlib.Path
    active_version: str
    policy_path: pathlib.Path
    versioned_policy_path: pathlib.Path
    policy_sha256: str
    contract: dict[str, Any]
    contract_sha256: str
    registry: dict[str, Any]
    cache_path: pathlib.Path

    def as_dict(self) -> dict[str, Any]:
        return {
            "schema_version": 1,
            "active_version": self.active_version,
            "policy_path": str(self.policy_path),
            "versioned_policy_path": str(self.versioned_policy_path),
            "policy_sha256": self.policy_sha256,
            "contract_sha256": self.contract_sha256,
            "registry_path": str(self.registry_path),
            "cache_path": str(self.cache_path),
            "synced_utc": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "contract": self.contract,
        }


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def discover_root(start: pathlib.Path | None = None) -> pathlib.Path:
    candidates: list[pathlib.Path] = []
    if start is not None:
        candidates.append(start)
    env_root = os.environ.get("BQCA_ROOT")
    if env_root:
        candidates.append(pathlib.Path(env_root))
    candidates.append(pathlib.Path.cwd())
    candidates.append(pathlib.Path(__file__).resolve().parents[2])

    seen: set[pathlib.Path] = set()
    for candidate in candidates:
        try:
            candidate = candidate.expanduser().resolve()
        except OSError:
            continue
        for current in (candidate, *candidate.parents):
            if current in seen:
                continue
            seen.add(current)
            if (
                (current / ".bob").is_dir()
                and (current / ".bob" / "BQCA-ACTIVE-POLICY-REGISTRY.json").is_file()
                and (current / "xLaunchpad.sh").is_file()
            ):
                return current
            nested = current / "quantum-computing-agent"
            if (
                (nested / ".bob").is_dir()
                and (nested / ".bob" / "BQCA-ACTIVE-POLICY-REGISTRY.json").is_file()
                and (nested / "xLaunchpad.sh").is_file()
            ):
                return nested.resolve()
    raise PolicyError("Unable to locate the BQCA project root")


def resolve_under_root(root: pathlib.Path, value: str, label: str) -> pathlib.Path:
    path = pathlib.Path(value).expanduser()
    if not path.is_absolute():
        path = root / path
    try:
        path = path.resolve()
    except OSError as exc:
        raise PolicyError(f"Unable to resolve {label}: {value}: {exc}") from exc
    try:
        path.relative_to(root)
    except ValueError as exc:
        raise PolicyError(f"{label} must remain inside the BQCA root: {path}") from exc
    return path


def extract_contract(policy_text: str) -> dict[str, Any]:
    start = policy_text.find(CONTRACT_BEGIN)
    end = policy_text.find(CONTRACT_END)
    if start < 0 or end < 0 or end <= start:
        raise PolicyError(
            "The active policy does not contain a BQCA active validation contract block"
        )
    payload = policy_text[start + len(CONTRACT_BEGIN) : end].strip()
    if payload.startswith("```json"):
        payload = payload[len("```json") :].strip()
        if payload.endswith("```"):
            payload = payload[:-3].strip()
    try:
        contract = json.loads(payload)
    except json.JSONDecodeError as exc:
        raise PolicyError(f"Invalid active-policy validation contract JSON: {exc}") from exc
    if not isinstance(contract, dict):
        raise PolicyError("Active-policy validation contract must be a JSON object")
    if int(contract.get("schema_version", 0)) != 1:
        raise PolicyError(
            f"Unsupported active-policy validation contract schema: {contract.get('schema_version')!r}"
        )
    if not isinstance(contract.get("design"), dict) or not isinstance(contract.get("code"), dict):
        raise PolicyError("Validation contract must define design and code sections")
    return contract


def load_registry(root: pathlib.Path) -> tuple[pathlib.Path, dict[str, Any]]:
    path = root / DEFAULT_REGISTRY
    if not path.is_file():
        raise PolicyError(f"Active-policy registry not found: {path}")
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise PolicyError(f"Unable to read active-policy registry: {exc}") from exc
    if not isinstance(data, dict):
        raise PolicyError("Active-policy registry must contain a JSON object")
    return path, data


def registry_value(registry: dict[str, Any], *names: str) -> Any:
    for name in names:
        if name in registry and registry[name] not in (None, ""):
            return registry[name]
    authority = registry.get("active_authority")
    if isinstance(authority, dict):
        for name in names:
            mapped = {
                "active_version": "version",
                "active_policy_path": "stable_policy",
                "policy_path": "stable_policy",
                "versioned_policy_path": "versioned_policy",
                "policy_sha256": "policy_sha256",
                "canonical_policy_sha256": "policy_sha256",
            }.get(name, name)
            if mapped in authority and authority[mapped] not in (None, ""):
                return authority[mapped]
    return None


def load_active_policy(
    root: pathlib.Path | None = None,
    *,
    write_cache: bool = True,
) -> ActivePolicyState:
    root = discover_root(root)
    registry_path, registry = load_registry(root)

    active_version = str(registry_value(registry, "active_version") or "").strip()
    policy_value = str(
        registry_value(registry, "active_policy_path", "policy_path")
        or ".bob/BQCA-PRODUCTION-POLICY.md"
    )
    versioned_value = str(registry_value(registry, "versioned_policy_path") or "").strip()
    expected_hash = str(
        registry_value(registry, "policy_sha256", "canonical_policy_sha256") or ""
    ).strip()

    if not active_version:
        raise PolicyError("Registry active_version is missing")
    if not versioned_value:
        raise PolicyError("Registry versioned_policy_path is missing")

    policy_path = resolve_under_root(root, policy_value, "active policy path")
    versioned_path = resolve_under_root(root, versioned_value, "versioned policy path")
    if not policy_path.is_file():
        raise PolicyError(f"Active policy file not found: {policy_path}")
    if not versioned_path.is_file():
        raise PolicyError(f"Versioned active policy file not found: {versioned_path}")

    stable_bytes = policy_path.read_bytes()
    versioned_bytes = versioned_path.read_bytes()
    if stable_bytes != versioned_bytes:
        raise PolicyError("Stable and versioned active policy files differ")
    actual_hash = sha256_bytes(stable_bytes)
    if expected_hash and expected_hash != actual_hash:
        raise PolicyError(
            f"Registry policy SHA-256 mismatch: expected {expected_hash}, actual {actual_hash}"
        )

    try:
        policy_text = stable_bytes.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise PolicyError(f"Active policy must be UTF-8: {exc}") from exc
    contract = extract_contract(policy_text)
    contract_version = str(contract.get("policy_version", "")).strip()
    if contract_version and contract_version != active_version:
        raise PolicyError(
            f"Contract policy_version {contract_version!r} does not match registry active_version {active_version!r}"
        )
    canonical_contract = json.dumps(contract, sort_keys=True, separators=(",", ":")).encode("utf-8")
    contract_hash = sha256_bytes(canonical_contract)

    cache_value = registry.get("active_policy_state_cache") or str(DEFAULT_CACHE)
    cache_path = resolve_under_root(root, str(cache_value), "active policy state cache")
    state = ActivePolicyState(
        root=root,
        registry_path=registry_path,
        active_version=active_version,
        policy_path=policy_path,
        versioned_policy_path=versioned_path,
        policy_sha256=actual_hash,
        contract=contract,
        contract_sha256=contract_hash,
        registry=registry,
        cache_path=cache_path,
    )
    if write_cache:
        write_state_cache(state)
    return state


def write_state_cache(state: ActivePolicyState) -> None:
    state.cache_path.parent.mkdir(parents=True, exist_ok=True)
    temporary = state.cache_path.with_name(
        f".{state.cache_path.name}.{os.getpid()}.{time.time_ns()}.tmp"
    )
    temporary.write_text(
        json.dumps(state.as_dict(), indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    os.chmod(temporary, 0o600)
    temporary.replace(state.cache_path)
    os.chmod(state.cache_path, 0o600)


def json_pointer(data: Any, pointer: str) -> Any:
    if pointer in ("", "/"):
        return data
    current = data
    parts = pointer.split(".") if not pointer.startswith("/") else pointer[1:].split("/")
    for raw in parts:
        key = raw.replace("~1", "/").replace("~0", "~")
        if isinstance(current, list):
            try:
                current = current[int(key)]
            except (ValueError, IndexError) as exc:
                raise PolicyError(f"Invalid list index in field path: {raw}") from exc
        elif isinstance(current, dict) and key in current:
            current = current[key]
        else:
            raise PolicyError(f"Field not found in active-policy state: {raw}")
    return current


def print_value(value: Any) -> None:
    if isinstance(value, (dict, list)):
        print(json.dumps(value, indent=2, sort_keys=True))
    elif isinstance(value, bool):
        print("true" if value else "false")
    elif value is None:
        print("null")
    else:
        print(value)


def watch(root: pathlib.Path | None, interval: float, quiet: bool) -> int:
    previous: tuple[str, str, str] | None = None
    while True:
        try:
            state = load_active_policy(root, write_cache=True)
            current = (state.active_version, state.policy_sha256, state.contract_sha256)
            if current != previous and not quiet:
                print(
                    "BQCA_ACTIVE_POLICY_CHANGED "
                    f"version={state.active_version} "
                    f"policy_sha256={state.policy_sha256} "
                    f"contract_sha256={state.contract_sha256}",
                    flush=True,
                )
            previous = current
        except PolicyError as exc:
            print(f"BQCA_ACTIVE_POLICY_LISTENER=FAIL: {exc}", file=sys.stderr, flush=True)
            return 2
        time.sleep(max(interval, 0.1))


def main() -> int:
    parser = argparse.ArgumentParser(description="BQCA dynamic active-policy resolver and listener")
    parser.add_argument("--root", type=pathlib.Path)
    subparsers = parser.add_subparsers(dest="command", required=True)

    sync_parser = subparsers.add_parser("sync")
    sync_parser.add_argument("--quiet", action="store_true")
    subparsers.add_parser("show")
    subparsers.add_parser("version")
    subparsers.add_parser("policy-path")
    subparsers.add_parser("versioned-policy-path")
    subparsers.add_parser("contract")
    subparsers.add_parser("validate")
    field_parser = subparsers.add_parser("field")
    field_parser.add_argument("path")
    watch_parser = subparsers.add_parser("watch")
    watch_parser.add_argument("--interval", type=float, default=1.0)
    watch_parser.add_argument("--quiet", action="store_true")

    args = parser.parse_args()
    if args.command == "watch":
        return watch(args.root, args.interval, args.quiet)

    try:
        state = load_active_policy(args.root, write_cache=True)
    except PolicyError as exc:
        print(f"BQCA_ACTIVE_POLICY_LISTENER=FAIL: {exc}", file=sys.stderr)
        return 2

    if args.command in {"sync", "validate"}:
        if not getattr(args, "quiet", False):
            print(
                "BQCA_ACTIVE_POLICY_LISTENER=PASS "
                f"version={state.active_version} "
                f"policy_sha256={state.policy_sha256} "
                f"contract_sha256={state.contract_sha256}"
            )
    elif args.command == "show":
        print(json.dumps(state.as_dict(), indent=2, sort_keys=True))
    elif args.command == "version":
        print(state.active_version)
    elif args.command == "policy-path":
        print(state.policy_path)
    elif args.command == "versioned-policy-path":
        print(state.versioned_policy_path)
    elif args.command == "contract":
        print(json.dumps(state.contract, indent=2, sort_keys=True))
    elif args.command == "field":
        print_value(json_pointer(state.as_dict(), args.path))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
PY_BQCA_ACTIVE_POLICY
  chmod 755 "$ACTIVE_POLICY_PY"
}

write_active_policy_sh() {
  cat > "$ACTIVE_POLICY_SH" <<'SH_BQCA_ACTIVE_POLICY'
#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
exec python3 "$SCRIPT_DIR/bqca_active_policy.py" "$@"
SH_BQCA_ACTIVE_POLICY
  chmod 755 "$ACTIVE_POLICY_SH"
}

write_dynamic_validator() {
  cat > "$DYNAMIC_VALIDATOR" <<'PY_BQCA_DYNAMIC_VALIDATOR'
#!/usr/bin/env python3
"""Version-neutral BQCA design/code validator driven by the active policy.

The validator resolves the active policy and its embedded machine-readable
validation contract on every invocation.  It never hardcodes a BQCA policy
version.  A compliance report is written beside every validated design or code
artifact on both PASS and FAIL outcomes.
"""
from __future__ import annotations

import argparse
import ast
import hashlib
import os
import pathlib
import re
import sys
import time
from dataclasses import dataclass, field
from datetime import datetime
from typing import Any, Iterable

SCRIPT_DIR = pathlib.Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from bqca_active_policy import PolicyError, load_active_policy  # noqa: E402


@dataclass
class GateResult:
    gate_id: str
    label: str
    status: str
    detail: str
    findings: list[str] = field(default_factory=list)


KNOWN_GATE_TYPES = {"routing", "text_policy", "python_syntax", "python_policy", "secret_scan"}
KNOWN_SEMANTIC_CHECKS = {
    "exact_imports",
    "assignment_calls",
    "home_environment_marker",
    "qiskit_min_version",
    "direct_execution_wrapper",
    "open_plan_v2_job_mode",
    "paid_plan_session_v2",
    "simulator_fallback",
    "real_backend_run_forbidden",
    "qpu_checks",
    "execution_markers",
    "synchronous_execution",
}


def compile_regex(pattern: str, flags: str | None = None) -> re.Pattern[str]:
    value = 0
    for flag in (flags or "ims"):
        value |= {"i": re.I, "m": re.M, "s": re.S, "x": re.X}.get(flag.lower(), 0)
    try:
        return re.compile(pattern, value)
    except re.error as exc:
        raise PolicyError(f"Invalid validation-contract regex {pattern!r}: {exc}") from exc


def version_token(version: str) -> str:
    return re.sub(r"[^A-Za-z0-9]+", "_", version).strip("_").upper() or "ACTIVE"


def first_heading(text: str) -> str:
    for raw in text.splitlines():
        line = raw.strip()
        if not line:
            continue
        return line.lstrip("#").strip() if line.startswith("#") else line
    return ""


def rule_is_exempt(rule: dict[str, Any], path: pathlib.Path, text: str) -> bool:
    path_pattern = rule.get("unless_path_regex")
    heading_pattern = rule.get("unless_heading_regex")
    if path_pattern and compile_regex(str(path_pattern), "i").search(str(path)):
        return True
    if heading_pattern and compile_regex(str(heading_pattern), "i").search(first_heading(text)):
        return True
    return False


def apply_text_rules(path: pathlib.Path, text: str, section: dict[str, Any]) -> list[str]:
    """Apply active-policy literal and regex needles.

    A future policy contract may use either detailed rule objects or concise
    string needles. The validator follows either form without source changes.
    """
    problems: list[str] = []

    for raw_rule in section.get("required_literals", []):
        if isinstance(raw_rule, str):
            rule: dict[str, Any] = {"value": raw_rule}
        elif isinstance(raw_rule, dict):
            rule = raw_rule
        else:
            problems.append("active policy contains an invalid required-literal rule")
            continue
        if rule_is_exempt(rule, path, text):
            continue
        value = str(rule.get("value", ""))
        if value and value.lower() not in text.lower():
            problems.append(str(rule.get("message") or f"missing required text: {value}"))

    for raw_rule in section.get("required_regex", []):
        if isinstance(raw_rule, str):
            rule = {"pattern": raw_rule}
        elif isinstance(raw_rule, dict):
            rule = raw_rule
        else:
            problems.append("active policy contains an invalid required-regex rule")
            continue
        if rule_is_exempt(rule, path, text):
            continue
        pattern = str(rule.get("pattern", ""))
        if pattern and not compile_regex(pattern, str(rule.get("flags", "ims"))).search(text):
            problems.append(str(rule.get("message") or f"missing required policy pattern: {pattern}"))

    for raw_group in section.get("required_any_groups", []):
        if isinstance(raw_group, (list, tuple)):
            group: dict[str, Any] = {"patterns": list(raw_group)}
        elif isinstance(raw_group, dict):
            group = raw_group
        else:
            problems.append("active policy contains an invalid required-any group")
            continue
        if rule_is_exempt(group, path, text):
            continue
        patterns = [str(item) for item in group.get("patterns", []) if str(item)]
        if patterns and not any(compile_regex(pattern, str(group.get("flags", "ims"))).search(text) for pattern in patterns):
            problems.append(str(group.get("message") or "missing one of the required active-policy alternatives"))

    for raw_rule in section.get("forbidden_literals", []):
        if isinstance(raw_rule, str):
            rule = {"value": raw_rule}
        elif isinstance(raw_rule, dict):
            rule = raw_rule
        else:
            problems.append("active policy contains an invalid forbidden-literal rule")
            continue
        if rule_is_exempt(rule, path, text):
            continue
        value = str(rule.get("value", ""))
        if value and value.lower() in text.lower():
            problems.append(str(rule.get("message") or f"forbidden text found: {value}"))

    for raw_rule in section.get("forbidden_regex", []):
        if isinstance(raw_rule, str):
            rule = {"pattern": raw_rule}
        elif isinstance(raw_rule, dict):
            rule = raw_rule
        else:
            problems.append("active policy contains an invalid forbidden-regex rule")
            continue
        if rule_is_exempt(rule, path, text):
            continue
        pattern = str(rule.get("pattern", ""))
        if pattern and compile_regex(pattern, str(rule.get("flags", "ims"))).search(text):
            problems.append(str(rule.get("message") or f"forbidden policy pattern found: {pattern}"))
    return problems


# ---------------------------- Code semantic helpers ----------------------------

def read_python(path: pathlib.Path) -> tuple[str, ast.AST]:
    text = path.read_text(encoding="utf-8")
    return text, ast.parse(text, filename=str(path))


def imports_qiskit(tree: ast.AST) -> bool:
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            if any(alias.name == "qiskit" or alias.name.startswith(("qiskit.", "qiskit_")) for alias in node.names):
                return True
        elif isinstance(node, ast.ImportFrom):
            module = node.module or ""
            if module == "qiskit" or module.startswith(("qiskit.", "qiskit_")):
                return True
    return False


def imported_aliases(tree: ast.AST) -> set[tuple[str, str, str | None]]:
    output: set[tuple[str, str, str | None]] = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.ImportFrom):
            for alias in node.names:
                output.add((node.module or "", alias.name, alias.asname))
    return output


def runtime_aliases(tree: ast.AST) -> tuple[set[str], set[str], set[str]]:
    samplers = {"SamplerV2"}
    estimators = {"EstimatorV2"}
    sessions = {"Session"}
    for node in ast.walk(tree):
        if not isinstance(node, ast.ImportFrom) or (node.module or "") != "qiskit_ibm_runtime":
            continue
        for alias in node.names:
            local = alias.asname or alias.name
            if alias.name == "SamplerV2":
                samplers.add(local)
            elif alias.name == "EstimatorV2":
                estimators.add(local)
            elif alias.name == "Session":
                sessions.add(local)
    return samplers, estimators, sessions


def call_name(call: ast.Call) -> str:
    if isinstance(call.func, ast.Name):
        return call.func.id
    if isinstance(call.func, ast.Attribute):
        return call.func.attr
    return ""


def target_names(node: ast.Assign | ast.AnnAssign) -> Iterable[str]:
    targets = node.targets if isinstance(node, ast.Assign) else [node.target]
    for target in targets:
        if isinstance(target, ast.Name):
            yield target.id


def has_assignment(tree: ast.AST, target: str, function: str) -> bool:
    for node in ast.walk(tree):
        if isinstance(node, (ast.Assign, ast.AnnAssign)) and isinstance(node.value, ast.Call):
            if call_name(node.value) == function and target in set(target_names(node)):
                return True
    return False


def unparse(node: ast.AST) -> str:
    try:
        return ast.unparse(node)
    except Exception:
        return ""


def calls_in(statements: list[ast.stmt]) -> list[ast.Call]:
    module = ast.Module(body=statements, type_ignores=[])
    return [node for node in ast.walk(module) if isinstance(node, ast.Call)]


def is_mode_call(call: ast.Call, names: set[str], mode_name: str) -> bool:
    if call_name(call) not in names:
        return False
    return any(keyword.arg == "mode" and isinstance(keyword.value, ast.Name) and keyword.value.id == mode_name for keyword in call.keywords)


def has_session_call(statements: list[ast.stmt], session_names: set[str]) -> bool:
    return any(call_name(call) in session_names for call in calls_in(statements))


def find_open_plan_if(tree: ast.AST) -> ast.If | None:
    for node in ast.walk(tree):
        if not isinstance(node, ast.If):
            continue
        test = unparse(node.test).lower()
        if "is_open_plan" in test or ("open" in test and ("plan" in test or "current" in test)):
            return node
    return None


def open_job_primitives(node: ast.If, samplers: set[str], estimators: set[str]) -> set[str]:
    found: set[str] = set()
    for call in calls_in(node.body):
        if is_mode_call(call, samplers, "backend"):
            found.add("SamplerV2")
        if is_mode_call(call, estimators, "backend"):
            found.add("EstimatorV2")
    return found


def has_paid_session_strategy(node: ast.If, samplers: set[str], estimators: set[str], sessions: set[str]) -> bool:
    statements = node.orelse
    return bool(statements) and has_session_call(statements, sessions) and any(is_mode_call(call, samplers | estimators, "session") for call in calls_in(statements))


def simulator_receiver_name(call: ast.Call) -> str:
    if not isinstance(call.func, ast.Attribute) or call.func.attr != "run":
        return ""
    return unparse(call.func.value)


def simulator_operations_ok(statements: list[ast.stmt], simulator_names: set[str]) -> bool:
    calls = calls_in(statements)
    has_simulator = any(call_name(call) in simulator_names for call in calls)
    has_transpile = any(call_name(call) == "transpile" for call in calls)
    has_local_run = any(simulator_receiver_name(call) and any(token in simulator_receiver_name(call).lower() for token in ("sim", "aer", "local")) for call in calls)
    return has_simulator and has_transpile and has_local_run


def simulator_fallback_ok(tree: ast.AST, simulator_names: set[str]) -> bool:
    functions = {node.name: node.body for node in ast.walk(tree) if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))}
    for node in ast.walk(tree):
        if not isinstance(node, ast.Try):
            continue
        handler_statements = [statement for handler in node.handlers for statement in handler.body]
        if simulator_operations_ok(handler_statements, simulator_names):
            return True
        for call in calls_in(handler_statements):
            name = call_name(call)
            if name in functions and any(token in name.lower() for token in ("sim", "fallback")) and simulator_operations_ok(functions[name], simulator_names):
                return True
    return False


def invalid_backend_runs(tree: ast.AST) -> list[int]:
    lines: list[int] = []
    for node in ast.walk(tree):
        if not isinstance(node, ast.Call) or not isinstance(node.func, ast.Attribute) or node.func.attr != "run":
            continue
        receiver = unparse(node.func.value).lower()
        if receiver == "backend" or ("backend" in receiver and not any(token in receiver for token in ("sim", "aer", "local"))):
            lines.append(getattr(node, "lineno", 0))
    return lines


def qpu_checks_ok(tree: ast.AST) -> bool:
    text = unparse(tree).lower()
    availability = any(token in text for token in ("operational", "status", "simulator", "is_simulator"))
    capacity = any(token in text for token in ("num_qubits", "required_qubits", "qubit_capacity"))
    return availability and capacity


def strings_and_text(tree: ast.AST, text: str) -> str:
    strings = [node.value for node in ast.walk(tree) if isinstance(node, ast.Constant) and isinstance(node.value, str)]
    return text + "\n" + "\n".join(strings)


def apply_code_semantic_checks(text: str, tree: ast.AST, section: dict[str, Any]) -> list[str]:
    checks = set(str(item) for item in section.get("semantic_checks", []))
    unknown = checks - KNOWN_SEMANTIC_CHECKS
    if unknown:
        return ["active policy requests unsupported semantic check(s): " + ", ".join(sorted(unknown))]
    params = section.get("parameters", {}) if isinstance(section.get("parameters"), dict) else {}
    problems: list[str] = []
    aliases = imported_aliases(tree)
    if "exact_imports" in checks:
        for required in params.get("exact_imports", []):
            if not isinstance(required, dict):
                continue
            item = (str(required.get("module", "")), str(required.get("name", "")), required.get("asname"))
            if item not in aliases:
                alias_text = f" as {item[2]}" if item[2] else ""
                problems.append(f"missing exact import: from {item[0]} import {item[1]}{alias_text}")
    if "assignment_calls" in checks:
        for required in params.get("assignment_calls", []):
            if isinstance(required, dict):
                target, function = str(required.get("target", "")), str(required.get("function", ""))
                if target and function and not has_assignment(tree, target, function):
                    problems.append(f"missing executable assignment: {target} = {function}()")
    if "home_environment_marker" in checks:
        markers = [str(item) for item in params.get("home_environment_markers", ["$HOME/qiskit-v2x-env", "~/qiskit-v2x-env"])]
        if not any(marker in text for marker in markers):
            problems.append("missing authorized home-scoped qiskit-v2x-env execution marker")
    if "qiskit_min_version" in checks:
        minimum = str(params.get("minimum_qiskit_version", "2.5"))
        escaped = re.escape(minimum)
        if not re.search(rf"(?is)qiskit.{{0,100}}(?:>=|version|minimum|min).{{0,30}}{escaped}|{escaped}.{{0,100}}qiskit", text):
            problems.append(f"missing explicit Qiskit {minimum}-or-later requirement")
    if "direct_execution_wrapper" in checks:
        wrapper = str(params.get("direct_execution_wrapper", "bqca-direct-execution.sh"))
        if wrapper not in text:
            problems.append(f"missing direct-execution wrapper contract: {wrapper}")
    samplers, estimators, sessions = runtime_aliases(tree)
    open_branch = find_open_plan_if(tree)
    if "open_plan_v2_job_mode" in checks:
        if open_branch is None:
            problems.append("missing explicit Open Plan execution branch")
        else:
            if not open_job_primitives(open_branch, samplers, estimators):
                problems.append("Open Plan branch must use SamplerV2(mode=backend) or EstimatorV2(mode=backend)")
            if has_session_call(open_branch.body, sessions):
                problems.append("Open Plan branch illegally constructs or uses Session")
    if "paid_plan_session_v2" in checks and (open_branch is None or not has_paid_session_strategy(open_branch, samplers, estimators, sessions)):
        problems.append("Paid Plan branch must use Session with SamplerV2/EstimatorV2 mode=session")
    if "simulator_fallback" in checks:
        simulator_names = set(str(item) for item in params.get("simulator_names", ["AerSimulator", "StatevectorSimulator", "BasicSimulator"]))
        if not simulator_fallback_ok(tree, simulator_names):
            problems.append("missing try/except simulator fallback using transpile plus a supported local simulator run")
    if "real_backend_run_forbidden" in checks:
        bad_lines = invalid_backend_runs(tree)
        if bad_lines:
            problems.append("backend.run() is prohibited for real QPU backends; offending line(s): " + ", ".join(map(str, bad_lines)))
    if "qpu_checks" in checks and not qpu_checks_ok(tree):
        problems.append("missing QPU availability/operational and qubit-capacity checks")
    evidence = strings_and_text(tree, text)
    if "execution_markers" in checks:
        for marker in params.get("required_markers", []):
            marker = str(marker)
            if marker and marker not in evidence:
                problems.append(f"missing canonical runtime marker: {marker}")
    if "synchronous_execution" in checks and ("nohup" in text or re.search(r"(?m)(?<!&)&\s*$", text)):
        problems.append("execution instructions must use the synchronous direct executor")
    return problems


# ------------------------------ Gate evaluation -------------------------------

def path_under(path: pathlib.Path, root: pathlib.Path) -> bool:
    try:
        path.resolve().relative_to(root.resolve())
        return True
    except ValueError:
        return False


def routing_gate(path: pathlib.Path, root: pathlib.Path, gate: dict[str, Any]) -> list[str]:
    problems: list[str] = []
    allowed_roots = [root / str(item) for item in gate.get("allowed_roots", [])]
    if allowed_roots and not any(path_under(path, candidate) for candidate in allowed_roots):
        problems.append("artifact is outside the active policy's governed store")
    allowed_extensions = {str(item).lower() for item in gate.get("allowed_extensions", [])}
    if allowed_extensions and path.suffix.lower() not in allowed_extensions:
        problems.append(f"artifact extension {path.suffix!r} is not permitted")
    return problems


def default_secret_patterns() -> list[tuple[re.Pattern[str], str]]:
    return [
        (re.compile(r"(?is)\b(?:IQP_API_TOKEN|BOB_API_KEY|API[_-]?KEY|ACCESS[_-]?TOKEN)\b\s*[:=]\s*[\"'][^\"'\s]{12,}[\"']"), "hardcoded credential assignment detected"),
        (re.compile(r"(?is)\bBearer\s+[A-Za-z0-9._~+/-]{20,}"), "Bearer credential detected"),
        (re.compile(r"(?is)[\"']token[\"']\s*:\s*[\"'][^\"'\s]{12,}[\"']"), "hardcoded token value detected"),
    ]


def secret_gate(text: str, gate: dict[str, Any]) -> list[str]:
    patterns = default_secret_patterns()
    for item in gate.get("patterns", []):
        if isinstance(item, dict) and item.get("pattern"):
            patterns.append((compile_regex(str(item["pattern"]), str(item.get("flags", "ims"))), str(item.get("message", "secret pattern detected"))))
    return [message for pattern, message in patterns if pattern.search(text)]


def gate_token(gate_id: str, kind: str, version: str) -> str:
    token = version_token(version)
    mapping = {
        "artifact_routing": f"BQCA_ARTIFACT_ROUTING_{token}",
        "design_policy": f"BQCA_QISKIT_DESIGN_POLICY_{token}",
        "code_policy": f"BQCA_QISKIT_CODE_POLICY_{token}",
        "python_syntax": f"BQCA_PYTHON_SYNTAX_{token}",
        "home_environment": f"BQCA_HOME_ENV_POLICY_{token}",
        "hello_world_scope": f"BQCA_HELLO_WORLD_SCOPE_{token}",
        "result_output_contract": f"BQCA_RESULT_OUTPUT_POLICY_{token}_{kind.upper()}",
        "secret_scan": f"BQCA_SECRET_SCAN_{token}",
    }
    return mapping.get(gate_id, f"BQCA_{re.sub(r'[^A-Za-z0-9]+', '_', gate_id).upper()}_{token}")


def evaluate_gate(path: pathlib.Path, kind: str, root: pathlib.Path, gate: dict[str, Any], text: str, tree: ast.AST | None, qiskit_code: bool) -> GateResult:
    gate_id = str(gate.get("id") or "unnamed_gate")
    label = str(gate.get("label") or gate_id.replace("_", " ").title())
    gate_type = str(gate.get("type") or "text_policy")
    if gate_type not in KNOWN_GATE_TYPES:
        problems = [f"active policy requests unsupported gate type: {gate_type}"]
    elif gate_type == "routing":
        problems = routing_gate(path, root, gate)
    elif gate_type == "text_policy":
        problems = apply_text_rules(path, text, gate)
    elif gate_type == "python_syntax":
        problems = [] if tree is not None else ["Python syntax is invalid"]
    elif gate_type == "python_policy":
        if not qiskit_code:
            return GateResult(gate_id, label, "PASS", "Non-Qiskit artifact; Qiskit-specific policy checks are not applicable", [])
        problems = apply_text_rules(path, text, gate)
        if tree is None:
            problems.append("Python syntax must pass before code-policy checks")
        else:
            problems.extend(apply_code_semantic_checks(text, tree, gate))
    else:
        problems = secret_gate(text, gate)
    status = "PASS" if not problems else "FAIL"
    return GateResult(gate_id, label, status, "", problems)


def report_path(path: pathlib.Path, kind: str, reporting: dict[str, Any]) -> pathlib.Path:
    stem = path.stem
    if kind == "design":
        suffix = str(reporting.get("design_suffix", "-design-policy-compliance.txt"))
        if stem.lower().endswith("-design") and suffix.startswith("-design"):
            filename = stem + suffix[len("-design"):]
        else:
            filename = stem + suffix
    else:
        suffix = str(reporting.get("code_suffix", "-code-policy-compliance.txt"))
        if stem.lower().endswith("-code") and suffix.startswith("-code"):
            filename = stem + suffix[len("-code"):]
        else:
            filename = stem + suffix
    return path.with_name(filename)


def sha256_file(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def write_report(path: pathlib.Path, kind: str, state: Any, results: list[GateResult], reporting: dict[str, Any]) -> pathlib.Path:
    output = report_path(path, kind, reporting)
    output.parent.mkdir(parents=True, exist_ok=True)
    compliant = all(item.status != "FAIL" for item in results)
    width = 88
    title = str(reporting.get("title", "FORMAL POLICY COMPLIANCE REPORT"))
    lines = [
        "=" * width,
        f"BQCA {state.active_version} {title}",
        "=" * width,
        f"Artifact                : {path.resolve()}",
        f"Artifact type           : {kind}",
        f"Canonical policy        : {state.policy_path}",
        f"Active policy SHA-256   : {state.policy_sha256}",
        f"Validation contract SHA : {state.contract_sha256}",
        f"Validation date/time    : {datetime.now().astimezone().isoformat()}",
        f"Artifact SHA-256        : {sha256_file(path) if path.is_file() else 'NOT AVAILABLE'}",
        "-" * width,
        "VALIDATION GATES",
        "-" * width,
    ]
    token = version_token(state.active_version)
    for item in results:
        gate_status = item.status
        detail_token = gate_token(item.gate_id, kind, state.active_version)
        detail = item.detail or f"{detail_token}={gate_status} active_policy={state.active_version} file={path.resolve()}"
        lines.append(f"{item.label[:31]:31} : {gate_status[:8]:8} {detail}".rstrip())
    findings = [(item.label, finding) for item in results for finding in item.findings]
    if findings:
        lines.extend(["-" * width, "VALIDATION FINDINGS", "-" * width])
        for label, finding in findings:
            lines.append(f"- {label}: {finding}")
    lines.extend([
        "-" * width,
        f"FINAL STATUS            : {'COMPLIANT' if compliant else 'NON-COMPLIANT'}",
        "=" * width,
    ])
    temporary = output.with_name(f".{output.name}.{os.getpid()}.{time.time_ns()}.tmp")
    temporary.write_text("\n".join(lines) + "\n", encoding="utf-8")
    temporary.replace(output)
    output.chmod(0o644)
    return output


def validate_artifact(path: pathlib.Path, kind: str, state: Any) -> tuple[list[GateResult], pathlib.Path | None]:
    section = state.contract.get(kind)
    if not isinstance(section, dict):
        raise PolicyError(f"active policy contract has no {kind} section")
    gates = section.get("gates")
    if not isinstance(gates, list) or not gates:
        raise PolicyError(f"active policy contract {kind} section has no gates")
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as exc:
        text = ""
        results = [GateResult("artifact_read", "Artifact readability", "FAIL", "", [f"cannot read artifact: {exc}"])]
        reporting = state.contract.get("compliance_reporting", {})
        report = write_report(path, kind, state, results, reporting) if path.exists() else None
        return results, report
    tree: ast.AST | None = None
    if kind == "code":
        try:
            tree = ast.parse(text, filename=str(path))
        except SyntaxError:
            tree = None
    qiskit_code = bool(tree is not None and imports_qiskit(tree))
    results = [evaluate_gate(path, kind, state.root, gate, text, tree, qiskit_code) for gate in gates if isinstance(gate, dict)]
    reporting = state.contract.get("compliance_reporting", {})
    report = None
    enabled = not isinstance(reporting, dict) or bool(reporting.get("enabled", True))
    if enabled:
        report = write_report(path, kind, state, results, reporting if isinstance(reporting, dict) else {})
    return results, report


def main() -> int:
    parser = argparse.ArgumentParser(description="BQCA active-policy dynamic design/code validator")
    parser.add_argument("--kind", choices=("design", "code"), required=True)
    parser.add_argument("--root", type=pathlib.Path)
    parser.add_argument("--no-report", action="store_true")
    parser.add_argument("paths", nargs="+")
    args = parser.parse_args()
    try:
        state = load_active_policy(args.root, write_cache=True)
    except PolicyError as exc:
        print(f"BQCA_ACTIVE_POLICY_VALIDATION=FAIL: {exc}", file=sys.stderr)
        return 2
    if args.no_report:
        reporting = state.contract.get("compliance_reporting")
        if isinstance(reporting, dict):
            reporting["enabled"] = False
    failed = False
    token = version_token(state.active_version)
    label = "DESIGN" if args.kind == "design" else "CODE"
    for raw in args.paths:
        path = pathlib.Path(raw).expanduser()
        if not path.is_absolute():
            path = (pathlib.Path.cwd() / path).resolve()
        if not path.is_file():
            failed = True
            print(f"BQCA_QISKIT_{label}_POLICY_{token}=FAIL active_policy={state.active_version} file={path}")
            print("  - artifact file not found")
            continue
        try:
            results, report = validate_artifact(path, args.kind, state)
        except PolicyError as exc:
            failed = True
            print(f"BQCA_QISKIT_{label}_POLICY_{token}=FAIL active_policy={state.active_version} file={path}")
            print(f"  - {exc}")
            continue
        problems = [finding for item in results for finding in item.findings]
        compliant = all(item.status != "FAIL" for item in results)
        if not compliant:
            failed = True
        status = "PASS" if compliant else "FAIL"
        report_text = f" compliance_report={report}" if report else ""
        print(f"BQCA_QISKIT_{label}_POLICY_{token}={status} active_policy={state.active_version} file={path}{report_text}")
        for problem in problems:
            print(f"  - {problem}")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
PY_BQCA_DYNAMIC_VALIDATOR
  chmod 755 "$DYNAMIC_VALIDATOR"
}

write_design_wrapper() {
  cat > "$DESIGN_WRAPPER" <<'PY_BQCA_DESIGN_WRAPPER'
#!/usr/bin/env python3
"""BQCA version-neutral design validator bound to the current active policy."""
from __future__ import annotations
import pathlib
import subprocess
import sys

SCRIPT_DIR = pathlib.Path(__file__).resolve().parent
VALIDATOR = SCRIPT_DIR / "bqca-dynamic-validator.py"

if __name__ == "__main__":
    raise SystemExit(subprocess.call([sys.executable, str(VALIDATOR), "--kind", "design", *sys.argv[1:]]))
PY_BQCA_DESIGN_WRAPPER
  chmod 755 "$DESIGN_WRAPPER"
}

write_code_wrapper() {
  cat > "$CODE_WRAPPER" <<'PY_BQCA_CODE_WRAPPER'
#!/usr/bin/env python3
"""BQCA version-neutral code validator bound to the current active policy."""
from __future__ import annotations
import pathlib
import subprocess
import sys

SCRIPT_DIR = pathlib.Path(__file__).resolve().parent
VALIDATOR = SCRIPT_DIR / "bqca-dynamic-validator.py"

if __name__ == "__main__":
    raise SystemExit(subprocess.call([sys.executable, str(VALIDATOR), "--kind", "code", *sys.argv[1:]]))
PY_BQCA_CODE_WRAPPER
  chmod 755 "$CODE_WRAPPER"
}

write_doctor_py() {
  cat > "$DOCTOR_PY" <<'PY_BQCA_POLICY_DOCTOR'
#!/usr/bin/env python3
"""Version-neutral BQCA active-policy assurance and drift detector."""
from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import re
import stat
import subprocess
import sys
from typing import Any

SCRIPT_DIR = pathlib.Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from bqca_active_policy import PolicyError, load_active_policy  # noqa: E402

GENERIC_MARKER = "BQCA-ACTIVE-CENTRAL-POLICY:BEGIN"
GENERIC_MARKER_LINE = re.compile(r"(?m)^\s*(?:#\s*BQCA-ACTIVE-CENTRAL-POLICY:BEGIN\s*|<!--\s*BQCA-ACTIVE-CENTRAL-POLICY:BEGIN\s*-->)$")
VERSIONED_MARKER = re.compile(r"BQCA-(?:CANONICAL-PRODUCTION-POLICY|ACTIVE-CENTRAL-POLICY)-v\d+(?:-[^:]*)?:BEGIN", re.I)
EXTENSIONS = {".md", ".txt", ".sh", ".py", ".yaml", ".yml"}


def supported_files(root: pathlib.Path) -> tuple[list[pathlib.Path], list[pathlib.Path], list[pathlib.Path]]:
    bob = root / ".bob"
    rules = sorted(path for directory in bob.glob("rules-*") if directory.is_dir() for path in directory.rglob("*") if path.is_file() and path.suffix.lower() in EXTENSIONS)
    skills_root = bob / "skills"
    skills = sorted(path for path in skills_root.rglob("*") if path.is_file() and path.suffix.lower() in EXTENSIONS) if skills_root.is_dir() else []
    tools_root = bob / "quantum-tools"
    tools = sorted(path for path in tools_root.iterdir() if path.is_file() and path.suffix.lower() in EXTENSIONS) if tools_root.is_dir() else []
    knowledgebase = tools_root / "knowlegebase"
    for relative in ("README.md", "bqca_quantum_kb.py"):
        path = knowledgebase / relative
        if path.is_file():
            tools.append(path)
    return rules, skills, sorted(set(tools))


def read_text(path: pathlib.Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def bash_syntax(path: pathlib.Path) -> str | None:
    result = subprocess.run(["bash", "-n", str(path)], text=True, capture_output=True)
    return None if result.returncode == 0 else result.stderr.strip()


def python_syntax(path: pathlib.Path) -> str | None:
    try:
        compile(read_text(path), str(path), "exec")
        return None
    except Exception as exc:
        return str(exc)


def mode_counts(path: pathlib.Path) -> tuple[int, int]:
    text = read_text(path)
    expected = len(re.findall(r"(?m)^\s*customInstructions:\s*[>|][+-]?\s*(?:#.*)?$", text))
    actual = len(GENERIC_MARKER_LINE.findall(text))
    return expected, actual


def history_hash_failures(root: pathlib.Path) -> list[str]:
    manifest = root / "patches/BQCA/policy-history/BQCA-policy-history-manifest.json"
    if not manifest.is_file():
        return []
    try:
        data = json.loads(manifest.read_text(encoding="utf-8"))
    except Exception as exc:
        return [f"cannot parse policy-history manifest: {exc}"]
    entries = data.get("policies") or data.get("entries") or []
    if isinstance(entries, dict):
        entries = list(entries.values())
    errors: list[str] = []
    for entry in entries if isinstance(entries, list) else []:
        if not isinstance(entry, dict):
            continue
        value = entry.get("path") or entry.get("archive_path") or entry.get("file")
        expected = entry.get("sha256")
        if not value or not expected:
            continue
        path = pathlib.Path(str(value))
        if not path.is_absolute():
            path = root / path
        if not path.is_file():
            errors.append(f"history file missing: {path}")
            continue
        actual = hashlib.sha256(path.read_bytes()).hexdigest()
        if actual != expected:
            errors.append(f"history hash mismatch: {path}")
    return errors


def iter_designs(root: pathlib.Path):
    store = root / "bob-quantum-designs"
    if not store.is_dir():
        return
    for path in store.rglob("*"):
        if path.is_file() and path.suffix.lower() in {".md", ".txt"}:
            name = path.name.lower()
            if name not in {"readme.md", "readme.txt"} and not name.endswith("-policy-compliance.txt"):
                yield path


def iter_code(root: pathlib.Path):
    store = root / "bob-quantum-store"
    if not store.is_dir():
        return
    for path in store.rglob("*.py"):
        if path.is_file() and not any(part in {"__pycache__", ".venv", "venv", "node_modules"} for part in path.parts):
            yield path


def report_path(path: pathlib.Path, kind: str) -> pathlib.Path:
    stem = path.stem
    if kind == "design":
        return path.with_name(stem + ("-policy-compliance.txt" if stem.lower().endswith("-design") else "-design-policy-compliance.txt"))
    return path.with_name(stem + ("-policy-compliance.txt" if stem.lower().endswith("-code") else "-code-policy-compliance.txt"))


def compliance_report_errors(root: pathlib.Path, policy_hash: str, contract_hash: str) -> tuple[list[str], int, int]:
    errors: list[str] = []
    expected = 0
    current = 0
    for kind, artifacts in (("design", iter_designs(root)), ("code", iter_code(root))):
        for artifact in artifacts or []:
            expected += 1
            report = report_path(artifact, kind)
            if not report.is_file():
                errors.append(f"missing compliance report: {report}")
                continue
            text = read_text(report)
            artifact_hash = hashlib.sha256(artifact.read_bytes()).hexdigest()
            checks = {
                "artifact hash": f"Artifact SHA-256        : {artifact_hash}",
                "policy hash": f"Active policy SHA-256   : {policy_hash}",
                "contract hash": f"Validation contract SHA : {contract_hash}",
            }
            stale = [name for name, needle in checks.items() if needle not in text]
            if stale:
                errors.append(f"stale compliance report ({', '.join(stale)}): {report}")
            else:
                current += 1
    return errors, expected, current


def check(root: pathlib.Path) -> dict[str, Any]:
    errors: list[str] = []
    result: dict[str, Any] = {}
    try:
        state = load_active_policy(root, write_cache=True)
    except PolicyError as exc:
        return {"errors": [str(exc)], "final_status": "FAIL"}

    bob = root / ".bob"
    tools_root = bob / "quantum-tools"
    custom_modes = bob / "custom_modes.yaml"
    result.update({
        "active_version": state.active_version,
        "policy_path": str(state.policy_path),
        "versioned_policy_path": str(state.versioned_policy_path),
        "policy_sha256": state.policy_sha256,
        "contract_sha256": state.contract_sha256,
    })

    active_policy_files = sorted(path.name for path in bob.glob("BQCA-*POLICY*.md"))
    expected_policy_files = sorted({state.policy_path.name, state.versioned_policy_path.name})
    result["active_policy_files"] = active_policy_files
    if active_policy_files != expected_policy_files:
        errors.append(f"active policy files differ from registry authority: expected {expected_policy_files}, actual {active_policy_files}")
    if not state.cache_path.is_file():
        errors.append(f"active-policy state cache missing: {state.cache_path}")

    expected_modes, actual_modes = mode_counts(custom_modes) if custom_modes.is_file() else (0, 0)
    result["custom_modes_expected"] = expected_modes
    result["custom_modes_actual"] = actual_modes
    if expected_modes == 0 or actual_modes != expected_modes:
        errors.append(f"custom-mode active-policy coverage {actual_modes}/{expected_modes}")

    rules, skills, tools = supported_files(root)
    result["rules"], result["skills"], result["tools"] = len(rules), len(skills), len(tools)
    coverage_errors: list[str] = []
    versioned_hits: list[str] = []
    for path in [*rules, *skills, *tools]:
        text = read_text(path)
        if len(GENERIC_MARKER_LINE.findall(text)) != 1:
            coverage_errors.append(str(path))
        if VERSIONED_MARKER.search(text):
            versioned_hits.append(str(path))
    if coverage_errors:
        errors.append(f"active-policy awareness missing/duplicated in {len(coverage_errors)} file(s)")
    if versioned_hits:
        errors.append(f"version-specific authority markers remain in {len(versioned_hits)} active file(s)")
    result["coverage_errors"] = coverage_errors
    result["versioned_marker_hits"] = versioned_hits

    critical = [
        tools_root / "bqca-active-policy-listener.sh",
        tools_root / "bqca_active_policy.py",
        tools_root / "bqca-dynamic-validator.py",
        tools_root / "qiskit-design-policy-check.py",
        tools_root / "qiskit-code-policy-check.py",
        tools_root / "bqca-policy-compliance-watcher.py",
        tools_root / "bqca-policy-compliance.sh",
        tools_root / "bqca-policy-doctor.sh",
        tools_root / "bqca-policy-doctor.py",
        tools_root / "qiskit-connector.sh",
        root / "xLaunchpad.sh",
    ]
    syntax_errors: list[str] = []
    permission_errors: list[str] = []
    for path in critical:
        if not path.is_file():
            errors.append(f"critical active-policy component missing: {path}")
            continue
        mode = stat.S_IMODE(path.stat().st_mode)
        if path.suffix in {".sh", ".py"} and not (mode & stat.S_IXUSR):
            permission_errors.append(f"not executable: {path} ({mode:o})")
        if mode & stat.S_IWOTH:
            permission_errors.append(f"world-writable: {path} ({mode:o})")
        syntax_error = bash_syntax(path) if path.suffix == ".sh" else python_syntax(path) if path.suffix == ".py" else None
        if syntax_error:
            syntax_errors.append(f"{path}: {syntax_error}")
    if syntax_errors:
        errors.append(f"syntax errors in {len(syntax_errors)} critical component(s)")
    if permission_errors:
        errors.append(f"permission errors in {len(permission_errors)} critical component(s)")
    result["syntax_errors"] = syntax_errors
    result["permission_errors"] = permission_errors

    connector = tools_root / "qiskit-connector.sh"
    if connector.is_file():
        connector_text = read_text(connector)
        if "BQCA-ACTIVE-POLICY-VALIDATION" not in connector_text or "bqca-active-policy-listener.sh" not in connector_text:
            errors.append("qiskit-connector.sh does not force active-policy synchronization")
        if "qiskit-design-policy-check.py" not in connector_text or "qiskit-code-policy-check.py" not in connector_text:
            errors.append("qiskit-connector.sh does not use the active design/code validators")

    for wrapper in (tools_root / "qiskit-design-policy-check.py", tools_root / "qiskit-code-policy-check.py"):
        if wrapper.is_file() and "bqca-dynamic-validator.py" not in read_text(wrapper):
            errors.append(f"validator wrapper does not delegate to the dynamic validator: {wrapper}")

    launch_text = read_text(root / "xLaunchpad.sh") if (root / "xLaunchpad.sh").is_file() else ""
    if "BQCA-ACTIVE-POLICY-ASSURANCE:BEGIN" not in launch_text:
        errors.append("xLaunchpad.sh does not use version-neutral active-policy assurance")
    if "BQCA-AUTOMATIC-POLICY-COMPLIANCE:BEGIN" not in launch_text:
        errors.append("xLaunchpad.sh does not start automatic policy-compliance reporting")

    report_errors, report_expected, report_current = compliance_report_errors(root, state.policy_sha256, state.contract_sha256)
    if report_errors:
        errors.append(f"missing/stale artifact compliance reports: {len(report_errors)}")
    result["compliance_report_errors"] = report_errors
    result["compliance_reports_expected"] = report_expected
    result["compliance_reports_current"] = report_current

    history_errors = history_hash_failures(root)
    if history_errors:
        errors.append(f"policy-history hash failures: {len(history_errors)}")
    result["history_hash_errors"] = history_errors
    result["errors"] = errors
    result["final_status"] = "PASS" if not errors else "FAIL"
    return result


def format_report(result: dict[str, Any]) -> str:
    version = result.get("active_version", "UNKNOWN")
    lines = [
        "=" * 88,
        "BQCA ACTIVE CENTRAL POLICY ASSURANCE REPORT",
        "=" * 88,
        f"Active policy version       : {version}",
        f"Active policy path          : {result.get('policy_path', 'UNKNOWN')}",
        f"Versioned policy path       : {result.get('versioned_policy_path', 'UNKNOWN')}",
        f"Policy SHA-256              : {result.get('policy_sha256', 'UNKNOWN')}",
        f"Validation-contract SHA-256 : {result.get('contract_sha256', 'UNKNOWN')}",
        f"Custom mode blocks          : {result.get('custom_modes_actual', 0)}/{result.get('custom_modes_expected', 0)}",
        f"Rules / Skills / Tools      : {result.get('rules', 0)} / {result.get('skills', 0)} / {result.get('tools', 0)}",
        f"Compliance reports          : {result.get('compliance_reports_current', 0)}/{result.get('compliance_reports_expected', 0)} current",
        f"Coverage errors             : {len(result.get('coverage_errors', []))}",
        f"Versioned marker hits       : {len(result.get('versioned_marker_hits', []))}",
        f"History hash failures       : {len(result.get('history_hash_errors', []))}",
        f"Syntax errors               : {len(result.get('syntax_errors', []))}",
        f"Permission errors           : {len(result.get('permission_errors', []))}",
        "-" * 88,
    ]
    errors = result.get("errors", [])
    if errors:
        lines.append("ISSUES")
        lines.extend(f"- {item}" for item in errors)
        for item in result.get("compliance_report_errors", [])[:20]:
            lines.append(f"  - {item}")
        lines.append("-" * 88)
    status = result.get("final_status", "FAIL")
    lines.append(f"FINAL ASSURANCE STATUS      : {status}")
    lines.append("=" * 88)
    token = re.sub(r"[^A-Za-z0-9]+", "_", str(version)).strip("_").upper() or "ACTIVE"
    lines.append(f"BQCA_ACTIVE_POLICY_ASSURANCE={status}")
    lines.append(f"BQCA_{token}_POLICY_ASSURANCE={status}")
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description="BQCA version-neutral active-policy doctor")
    parser.add_argument("command", choices=("check", "report", "repair-path", "version"))
    parser.add_argument("--root", type=pathlib.Path, required=True)
    parser.add_argument("--output", type=pathlib.Path)
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args()
    root = args.root.expanduser().resolve()
    if args.command in {"repair-path", "version"}:
        try:
            state = load_active_policy(root, write_cache=True)
        except PolicyError as exc:
            print(f"BQCA_ACTIVE_POLICY_ASSURANCE=FAIL: {exc}", file=sys.stderr)
            return 2
        if args.command == "version":
            print(state.active_version)
        else:
            value = state.registry.get("repair_patch_path")
            if not value:
                print("Registry repair_patch_path is missing", file=sys.stderr)
                return 2
            path = pathlib.Path(str(value))
            if not path.is_absolute():
                path = root / path
            print(path.resolve())
        return 0
    result = check(root)
    report = format_report(result)
    if args.command == "report":
        if args.output:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(report, encoding="utf-8")
        print(report, end="")
    elif not args.quiet or result.get("final_status") != "PASS":
        print(report, end="")
    return 0 if result.get("final_status") == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
PY_BQCA_POLICY_DOCTOR
  chmod 755 "$DOCTOR_PY"
}

write_doctor_sh() {
  cat > "$DOCTOR_SH" <<'SH_BQCA_POLICY_DOCTOR'
#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
BOB_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
BQCA_ROOT="$(cd "$BOB_ROOT/.." && pwd -P)"
DOCTOR="$SCRIPT_DIR/bqca-policy-doctor.py"
usage() {
  cat <<'USAGE'
BQCA active central policy doctor
Usage:
  bqca-policy-doctor.sh check [--quiet]
  bqca-policy-doctor.sh report
  bqca-policy-doctor.sh repair
  bqca-policy-doctor.sh version
USAGE
}
command_name="${1:-}"
[[ -n "$command_name" ]] || { usage; exit 2; }
shift || true
case "$command_name" in
  check)
    exec python3 "$DOCTOR" check --root "$BQCA_ROOT" "$@"
    ;;
  report)
    (($# == 0)) || { usage >&2; exit 2; }
    active_version="$(python3 "$DOCTOR" version --root "$BQCA_ROOT")"
    report="$BOB_ROOT/patches-applied/BQCA.${active_version}-assurance-report.txt"
    exec python3 "$DOCTOR" report --root "$BQCA_ROOT" --output "$report"
    ;;
  repair)
    (($# == 0)) || { usage >&2; exit 2; }
    patch="$(python3 "$DOCTOR" repair-path --root "$BQCA_ROOT")"
    [[ -x "$patch" ]] || { printf 'BQCA active-policy repair patch is missing or not executable: %s\n' "$patch" >&2; exit 2; }
    exec "$patch" --target "$BQCA_ROOT"
    ;;
  version)
    (($# == 0)) || { usage >&2; exit 2; }
    exec python3 "$DOCTOR" version --root "$BQCA_ROOT"
    ;;
  -h|--help)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
SH_BQCA_POLICY_DOCTOR
  chmod 755 "$DOCTOR_SH"
}

write_compliance_watcher() {
  cat > "$COMPLIANCE_WATCHER" <<'PY_BQCA_COMPLIANCE_WATCHER'
#!/usr/bin/env python3
"""BQCA automatic design/code compliance-report watcher.

The watcher follows the active central policy.  Every time a governed design or
Python implementation becomes stable, or whenever the active policy/contract
changes, the artifact is revalidated and its policy-compliance report is
created or refreshed beside the artifact.
"""
from __future__ import annotations

import argparse
import os
import pathlib
import signal
import subprocess
import sys
import time
from dataclasses import dataclass

SCRIPT_DIR = pathlib.Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from bqca_active_policy import PolicyError, load_active_policy  # noqa: E402

STOP = False


def stop_handler(signum: int, frame: object) -> None:
    del signum, frame
    global STOP
    STOP = True


@dataclass
class Observation:
    size: int
    mtime_ns: int
    stable_scans: int = 0
    validated_signature: tuple[int, int, str, str] | None = None


def iter_designs(store: pathlib.Path):
    if not store.exists():
        return
    for path in store.rglob("*"):
        if not path.is_file() or path.suffix.lower() not in {".md", ".txt"}:
            continue
        name = path.name.lower()
        if name in {"readme.md", "readme.txt"} or name.endswith("-policy-compliance.txt"):
            continue
        if any(part in {".git", "__pycache__", ".venv", "venv", "node_modules"} for part in path.parts):
            continue
        yield path


def iter_code(store: pathlib.Path):
    if not store.exists():
        return
    for path in store.rglob("*.py"):
        if not path.is_file():
            continue
        if any(part in {".git", "__pycache__", ".venv", "venv", "node_modules"} for part in path.parts):
            continue
        yield path


def run_validator(python: str, validator: pathlib.Path, kind: str, source: pathlib.Path, log) -> bool:
    command = [python, str(validator), "--kind", kind, str(source)]
    result = subprocess.run(command, text=True, capture_output=True)
    stamp = time.strftime("%Y-%m-%dT%H:%M:%S%z")
    stream = (result.stdout + ("\n" if result.stdout and result.stderr else "") + result.stderr).strip()
    status = "PASS" if result.returncode == 0 else "NON_COMPLIANT"
    print(f"{stamp} {status} kind={kind} artifact={source}", file=log, flush=True)
    if stream:
        for line in stream.splitlines():
            print(f"{stamp}   {line}", file=log, flush=True)
    # Non-compliance is a valid report outcome.  The watcher fails only when the
    # validator cannot create a report due to an internal/policy-package error.
    return result.returncode in {0, 1}


def policy_key(root: pathlib.Path) -> tuple[str, str, str]:
    state = load_active_policy(root, write_cache=True)
    return state.active_version, state.policy_sha256, state.contract_sha256


def sweep(root: pathlib.Path, design_store: pathlib.Path, code_store: pathlib.Path, validator: pathlib.Path, log) -> int:
    failures = 0
    python = sys.executable
    for path in iter_designs(design_store) or []:
        if not run_validator(python, validator, "design", path, log):
            failures += 1
    for path in iter_code(code_store) or []:
        if not run_validator(python, validator, "code", path, log):
            failures += 1
    return failures


def watch(root: pathlib.Path, design_store: pathlib.Path, code_store: pathlib.Path, validator: pathlib.Path, interval: float, stable_scans: int, log) -> int:
    observations: dict[tuple[str, pathlib.Path], Observation] = {}
    last_policy: tuple[str, str, str] | None = None
    while not STOP:
        try:
            current_policy = policy_key(root)
        except PolicyError as exc:
            print(f"{time.strftime('%Y-%m-%dT%H:%M:%S%z')} FAIL active_policy={exc}", file=log, flush=True)
            time.sleep(interval)
            continue
        if current_policy != last_policy:
            for item in observations.values():
                item.validated_signature = None
            print(
                f"{time.strftime('%Y-%m-%dT%H:%M:%S%z')} POLICY_CHANGED "
                f"version={current_policy[0]} policy_sha256={current_policy[1]} contract_sha256={current_policy[2]}",
                file=log,
                flush=True,
            )
            last_policy = current_policy

        present: set[tuple[str, pathlib.Path]] = set()
        for kind, iterator in (("design", iter_designs(design_store)), ("code", iter_code(code_store))):
            for source in iterator or []:
                key = (kind, source)
                present.add(key)
                try:
                    stat = source.stat()
                except FileNotFoundError:
                    continue
                signature2 = (stat.st_size, stat.st_mtime_ns)
                signature4 = (*signature2, current_policy[1], current_policy[2])
                item = observations.get(key)
                if item is None:
                    observations[key] = Observation(*signature2, stable_scans=0)
                    continue
                if (item.size, item.mtime_ns) != signature2:
                    item.size, item.mtime_ns = signature2
                    item.stable_scans = 0
                    item.validated_signature = None
                    continue
                item.stable_scans += 1
                if item.stable_scans < stable_scans or item.validated_signature == signature4:
                    continue
                if run_validator(sys.executable, validator, kind, source, log):
                    item.validated_signature = signature4
        for missing in set(observations).difference(present):
            observations.pop(missing, None)
        time.sleep(interval)
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True, type=pathlib.Path)
    parser.add_argument("--design-store", required=True, type=pathlib.Path)
    parser.add_argument("--code-store", required=True, type=pathlib.Path)
    parser.add_argument("--validator", required=True, type=pathlib.Path)
    parser.add_argument("--interval", type=float, default=0.75)
    parser.add_argument("--stable-scans", type=int, default=2)
    parser.add_argument("--sweep", action="store_true")
    parser.add_argument("--log", type=pathlib.Path)
    args = parser.parse_args()

    root = args.root.expanduser().resolve()
    design_store = args.design_store.expanduser().resolve()
    code_store = args.code_store.expanduser().resolve()
    validator = args.validator.expanduser().resolve()
    if not validator.is_file() or not os.access(validator, os.X_OK):
        print(f"BQCA_POLICY_COMPLIANCE=FAIL: validator unavailable: {validator}", file=sys.stderr)
        return 2
    design_store.mkdir(parents=True, exist_ok=True)
    code_store.mkdir(parents=True, exist_ok=True)
    log_stream = args.log.open("a", encoding="utf-8") if args.log else sys.stdout
    try:
        if args.sweep:
            return 1 if sweep(root, design_store, code_store, validator, log_stream) else 0
        signal.signal(signal.SIGTERM, stop_handler)
        signal.signal(signal.SIGINT, stop_handler)
        print(f"{time.strftime('%Y-%m-%dT%H:%M:%S%z')} START root={root}", file=log_stream, flush=True)
        sweep(root, design_store, code_store, validator, log_stream)
        return watch(root, design_store, code_store, validator, args.interval, args.stable_scans, log_stream)
    finally:
        if log_stream is not sys.stdout:
            log_stream.close()


if __name__ == "__main__":
    raise SystemExit(main())
PY_BQCA_COMPLIANCE_WATCHER
  chmod 755 "$COMPLIANCE_WATCHER"
}

write_compliance_controller() {
  cat > "$COMPLIANCE_CONTROLLER" <<'SH_BQCA_COMPLIANCE_CONTROLLER'
#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
BOB_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
BQCA_ROOT="$(cd "$BOB_ROOT/.." && pwd -P)"
WATCHER="$SCRIPT_DIR/bqca-policy-compliance-watcher.py"
VALIDATOR="$SCRIPT_DIR/bqca-dynamic-validator.py"
RUNTIME_DIR="$BOB_ROOT/runtime"
PID_FILE="$RUNTIME_DIR/bqca-policy-compliance.pid"
LOG_FILE="$RUNTIME_DIR/bqca-policy-compliance.log"
DEFAULT_DESIGN_STORE="$BQCA_ROOT/bob-quantum-designs"
DEFAULT_CODE_STORE="$BQCA_ROOT/bob-quantum-store"

usage() {
  cat <<'USAGE'
BQCA active-policy compliance-report controller
Usage:
  bqca-policy-compliance.sh start [--design-store <dir>] [--code-store <dir>]
  bqca-policy-compliance.sh stop
  bqca-policy-compliance.sh status
  bqca-policy-compliance.sh sweep [--design-store <dir>] [--code-store <dir>]
USAGE
}

is_running() {
  [[ -f "$PID_FILE" ]] || return 1
  local pid cmdline
  pid="$(cat "$PID_FILE" 2>/dev/null || true)"
  [[ "$pid" =~ ^[0-9]+$ ]] || return 1
  kill -0 "$pid" 2>/dev/null || return 1
  if [[ -r "/proc/$pid/cmdline" ]]; then
    cmdline="$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null || true)"
    [[ "$cmdline" == *"bqca-policy-compliance-watcher.py"* ]] || return 1
  fi
}

design_store="$DEFAULT_DESIGN_STORE"
code_store="$DEFAULT_CODE_STORE"
command_name="${1:-}"
[[ -n "$command_name" ]] || { usage; exit 2; }
shift || true
while (($#)); do
  case "$1" in
    --design-store) (($# >= 2)) || { echo "--design-store requires a path" >&2; exit 2; }; design_store="$2"; shift 2 ;;
    --code-store) (($# >= 2)) || { echo "--code-store requires a path" >&2; exit 2; }; code_store="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done
mkdir -p "$RUNTIME_DIR" "$design_store" "$code_store"
chmod 700 "$RUNTIME_DIR" 2>/dev/null || true

case "$command_name" in
  start)
    if is_running; then
      printf 'BQCA_POLICY_COMPLIANCE=RUNNING PID=%s\n' "$(cat "$PID_FILE")"
      exit 0
    fi
    rm -f "$PID_FILE"
    nohup python3 "$WATCHER" \
      --root "$BQCA_ROOT" \
      --design-store "$design_store" \
      --code-store "$code_store" \
      --validator "$VALIDATOR" \
      --log "$LOG_FILE" >/dev/null 2>&1 &
    pid=$!
    printf '%s\n' "$pid" > "$PID_FILE"
    sleep 0.2
    if ! kill -0 "$pid" 2>/dev/null; then
      rm -f "$PID_FILE"
      printf 'BQCA_POLICY_COMPLIANCE=FAIL: watcher did not start; inspect %s\n' "$LOG_FILE" >&2
      exit 3
    fi
    printf 'BQCA_POLICY_COMPLIANCE=STARTED PID=%s\n' "$pid"
    ;;
  stop)
    if is_running; then
      pid="$(cat "$PID_FILE")"
      kill "$pid" 2>/dev/null || true
      for _ in 1 2 3 4 5 6 7 8 9 10; do
        kill -0 "$pid" 2>/dev/null || break
        sleep 0.1
      done
      kill -9 "$pid" 2>/dev/null || true
    fi
    rm -f "$PID_FILE"
    printf 'BQCA_POLICY_COMPLIANCE=STOPPED\n'
    ;;
  status)
    if is_running; then
      printf 'BQCA_POLICY_COMPLIANCE=RUNNING PID=%s LOG=%s\n' "$(cat "$PID_FILE")" "$LOG_FILE"
    else
      printf 'BQCA_POLICY_COMPLIANCE=STOPPED\n'
      exit 1
    fi
    ;;
  sweep)
    python3 "$WATCHER" \
      --root "$BQCA_ROOT" \
      --design-store "$design_store" \
      --code-store "$code_store" \
      --validator "$VALIDATOR" \
      --sweep --log "$LOG_FILE"
    printf 'BQCA_POLICY_COMPLIANCE=SWEEP_COMPLETE\n'
    ;;
  *) usage; exit 2 ;;
esac
SH_BQCA_COMPLIANCE_CONTROLLER
  chmod 755 "$COMPLIANCE_CONTROLLER"
}

write_contract_file() {
  local output="$1"
  cat > "$output" <<'JSON_BQCA_ACTIVE_CONTRACT'
{
  "binding": {
    "listener": ".bob/quantum-tools/bqca-active-policy-listener.sh",
    "mode": "resolve-registry-and-policy-on-every-validation",
    "registry": ".bob/BQCA-ACTIVE-POLICY-REGISTRY.json",
    "stable_policy": ".bob/BQCA-PRODUCTION-POLICY.md",
    "validator_engine": ".bob/quantum-tools/bqca-dynamic-validator.py"
  },
  "code": {
    "gates": [
      {
        "allowed_extensions": [
          ".py"
        ],
        "allowed_roots": [
          "bob-quantum-store"
        ],
        "id": "artifact_routing",
        "label": "Artifact routing",
        "type": "routing"
      },
      {
        "id": "python_syntax",
        "label": "Python syntax",
        "type": "python_syntax"
      },
      {
        "id": "code_policy",
        "label": "Code policy",
        "parameters": {
          "assignment_calls": [
            {
              "function": "plan",
              "target": "current"
            },
            {
              "function": "connector",
              "target": "backend"
            }
          ],
          "direct_execution_wrapper": "bqca-direct-execution.sh",
          "exact_imports": [
            {
              "asname": "connector",
              "module": "qiskit_connector",
              "name": "QConnectorV2"
            },
            {
              "asname": "plan",
              "module": "qiskit_connector",
              "name": "QPlanV2"
            }
          ],
          "home_environment_markers": [
            "$HOME/qiskit-v2x-env",
            "~/qiskit-v2x-env"
          ],
          "minimum_qiskit_version": "2.5",
          "required_markers": [
            "BQCA_EXECUTION_TARGET",
            "BQCA_PLAN",
            "BQCA_BACKEND",
            "BQCA_JOB_ID",
            "BQCA_RESULT",
            "BQCA_FALLBACK_REASON"
          ],
          "simulator_names": [
            "AerSimulator",
            "StatevectorSimulator",
            "BasicSimulator"
          ]
        },
        "required_regex": [
          {
            "message": "missing authorized home-scoped qiskit-v2x-env execution marker",
            "pattern": "(?:\\$HOME|~)/qiskit-v2x-env"
          },
          {
            "message": "missing explicit Qiskit 2.5-or-later requirement",
            "pattern": "Qiskit.{0,100}(?:>=|version|minimum|min).{0,30}2\\.5|2\\.5.{0,100}Qiskit"
          },
          {
            "message": "missing direct-execution wrapper contract",
            "pattern": "bqca-direct-execution\\.sh"
          }
        ],
        "semantic_checks": [
          "exact_imports",
          "assignment_calls",
          "home_environment_marker",
          "qiskit_min_version",
          "direct_execution_wrapper",
          "open_plan_v2_job_mode",
          "paid_plan_session_v2",
          "simulator_fallback",
          "real_backend_run_forbidden",
          "qpu_checks",
          "execution_markers",
          "synchronous_execution"
        ],
        "type": "python_policy"
      },
      {
        "forbidden_regex": [
          {
            "message": "project-local qiskit-v2x-env is prohibited",
            "pattern": "(?:PROJECT_ROOT|BQCA_ROOT|SCRIPT_DIR)[^\\n]{0,80}/qiskit-v2x-env"
          }
        ],
        "id": "home_environment",
        "label": "Home environment",
        "required_regex": [
          {
            "message": "missing authorized home Qiskit environment",
            "pattern": "(?:\\$HOME|~)/qiskit-v2x-env"
          }
        ],
        "type": "text_policy"
      },
      {
        "forbidden_regex": [
          {
            "message": "Hello World content is prohibited in non-Hello-World code",
            "pattern": "\\b(?:hello[\\s_-]*world|hellow[\\s_-]*world)\\b",
            "unless_path_regex": "hello[\\s_-]*world|hellow[\\s_-]*world"
          }
        ],
        "id": "hello_world_scope",
        "label": "Hello World scope",
        "type": "text_policy"
      },
      {
        "id": "result_output_contract",
        "label": "Result-output contract",
        "required_literals": [
          {
            "message": "missing BQCA_EXECUTION_TARGET marker",
            "value": "BQCA_EXECUTION_TARGET"
          },
          {
            "message": "missing BQCA_PLAN marker",
            "value": "BQCA_PLAN"
          },
          {
            "message": "missing BQCA_BACKEND marker",
            "value": "BQCA_BACKEND"
          },
          {
            "message": "missing BQCA_JOB_ID marker",
            "value": "BQCA_JOB_ID"
          },
          {
            "message": "missing BQCA_RESULT marker",
            "value": "BQCA_RESULT"
          },
          {
            "message": "missing BQCA_FALLBACK_REASON marker",
            "value": "BQCA_FALLBACK_REASON"
          }
        ],
        "required_regex": [
          {
            "message": "BQCA_RESULT must report SUCCESS or FAILURE at runtime",
            "pattern": "BQCA_RESULT\\s*=\\s*(?:SUCCESS|FAILURE)|BQCA_RESULT[}\\\"']?\\s*[:=]"
          }
        ],
        "type": "text_policy"
      },
      {
        "id": "secret_scan",
        "label": "Secret scan",
        "type": "secret_scan"
      }
    ],
    "skip_if_no_qiskit": true
  },
  "compliance_reporting": {
    "code_suffix": "-code-policy-compliance.txt",
    "design_suffix": "-design-policy-compliance.txt",
    "enabled": true,
    "same_directory_as_artifact": true,
    "title": "FORMAL POLICY COMPLIANCE REPORT",
    "write_on_fail": true,
    "write_on_pass": true
  },
  "design": {
    "gates": [
      {
        "allowed_extensions": [
          ".md",
          ".txt"
        ],
        "allowed_roots": [
          "bob-quantum-designs"
        ],
        "id": "artifact_routing",
        "label": "Artifact routing",
        "type": "routing"
      },
      {
        "forbidden_regex": [
          {
            "message": "design contains executable/fenced Python; use textual instructions only",
            "pattern": "```\\s*(?:python|py)\\b.*?```"
          },
          {
            "message": "design contains an executable implementation block",
            "pattern": "```[^\\n]*\\n.*?(?:from\\s+qiskit|current\\s*=\\s*plan\\s*\\(|backend\\s*=\\s*connector\\s*\\(|try\\s*:).*?```"
          }
        ],
        "id": "design_policy",
        "label": "Design policy",
        "required_regex": [
          {
            "message": "missing problem/objective statement",
            "pattern": "(?:problem|objective|research question)"
          },
          {
            "message": "missing algorithm selection or rationale",
            "pattern": "algorithm"
          },
          {
            "message": "missing qubit or circuit strategy",
            "pattern": "(?:qubit|circuit)"
          },
          {
            "message": "missing risk or limitation discussion",
            "pattern": "(?:risk|limitation)"
          },
          {
            "message": "missing validation criteria",
            "pattern": "validation"
          },
          {
            "message": "missing Qiskit Connector strategy",
            "pattern": "Qiskit Connector|QConnectorV2|qiskit_connector"
          },
          {
            "message": "missing home-scoped qiskit-v2x-env path",
            "pattern": "(?:\\$HOME|~)/qiskit-v2x-env"
          },
          {
            "message": "missing home environment activation command",
            "pattern": "source\\s+(?:\\\"?\\$HOME|~)/qiskit-v2x-env/bin/activate"
          },
          {
            "message": "missing Qiskit 2.5-or-later requirement",
            "pattern": "Qiskit.{0,100}(?:2\\.5|2\\.5\\+|2\\.5 or later)"
          },
          {
            "message": "missing Open Plan no-Session rule",
            "pattern": "Open Plan.{0,360}(?:(?:must\\s+not|never|prohibited|forbidden|not\\s+allowed).{0,100}Session|(?:no|without)\\s+Session)"
          },
          {
            "message": "missing Open Plan SamplerV2(mode=backend) option",
            "pattern": "SamplerV2\\s*\\(\\s*mode\\s*=\\s*backend\\s*\\)"
          },
          {
            "message": "missing Open Plan EstimatorV2(mode=backend) option",
            "pattern": "EstimatorV2\\s*\\(\\s*mode\\s*=\\s*backend\\s*\\)"
          },
          {
            "message": "missing Paid Plan Session strategy",
            "pattern": "(?:Paid Plan|Flex|Pay-As-You-Go|Premium|Dedicated).{0,360}Session"
          },
          {
            "message": "missing Paid Plan Runtime primitive requirement",
            "pattern": "(?:SamplerV2|EstimatorV2).{0,180}mode\\s*=\\s*session"
          },
          {
            "message": "missing controlled try/except fallback requirement",
            "pattern": "try\\s*/?\\s*except|try.{0,160}except"
          },
          {
            "message": "missing AerSimulator fallback requirement",
            "pattern": "AerSimulator"
          },
          {
            "message": "missing simulator transpilation requirement",
            "pattern": "transpile.{0,220}(?:AerSimulator|simulator)|(?:AerSimulator|simulator).{0,220}transpile"
          },
          {
            "message": "missing real-QPU backend.run prohibition",
            "pattern": "(?:backend\\.run\\(\\).{0,220}(?:real QPU|hardware).{0,140}(?:prohibited|forbidden|must\\s+not|not\\s+allowed)|(?:real QPU|hardware).{0,220}backend\\.run\\(\\).{0,140}(?:prohibited|forbidden|must\\s+not|not\\s+allowed))"
          },
          {
            "message": "missing direct-execution wrapper",
            "pattern": "bqca-direct-execution\\.sh"
          },
          {
            "message": "missing formal orchestrator opt-in scope",
            "pattern": "(?:formal|compliance|production|audit).{0,220}(?:orchestrator|formal-run)|(?:orchestrator|formal-run).{0,220}(?:formal|compliance|production|audit)"
          }
        ],
        "type": "text_policy"
      },
      {
        "forbidden_regex": [
          {
            "message": "Hello World content is prohibited in a non-Hello-World design",
            "pattern": "\\b(?:hello[\\s_-]*world|hellow[\\s_-]*world)\\b",
            "unless_heading_regex": "hello[\\s_-]*world|hellow[\\s_-]*world",
            "unless_path_regex": "hello[\\s_-]*world|hellow[\\s_-]*world"
          }
        ],
        "id": "hello_world_scope",
        "label": "Hello World scope",
        "type": "text_policy"
      },
      {
        "id": "result_output_contract",
        "label": "Result-output contract",
        "required_regex": [
          {
            "message": "missing authoritative result filename",
            "pattern": "<source-stem>-result-output\\.txt|<code-name>-result-output\\.txt"
          },
          {
            "message": "missing output.txt mirror",
            "pattern": "output\\.txt"
          },
          {
            "message": "missing complete live stdout/stderr requirement",
            "pattern": "(?:stdout|standard output).{0,100}(?:stderr|standard error).{0,120}(?:terminal|live|stream)"
          },
          {
            "message": "missing result timing/duration/exit-status requirements",
            "pattern": "(?:timestamp|date and time|started).{0,180}(?:completed|duration|exit status)"
          },
          {
            "message": "missing real-QPU Job ID line-one requirement",
            "pattern": "JOB ID.{0,100}(?:first line|line one)|(?:first line|line one).{0,100}JOB ID"
          },
          {
            "message": "missing RESULT SUMMARY requirement",
            "pattern": "RESULT SUMMARY"
          },
          {
            "message": "missing direct-mode non-blocking policy-gap rule",
            "pattern": "(?:policy gaps|missing markers|contract gaps).{0,160}(?:warning|non-blocking)"
          }
        ],
        "type": "text_policy"
      },
      {
        "id": "secret_scan",
        "label": "Secret scan",
        "type": "secret_scan"
      }
    ]
  },
  "policy_version": "v48",
  "schema_version": 1
}
JSON_BQCA_ACTIVE_CONTRACT
}
patch_policy_and_registry() {
  local contract_file
  contract_file="$(mktemp)"
  write_contract_file "$contract_file"
  python3 - "$POLICY_FILE" "$VERSIONED_POLICY_FILE" "$REGISTRY_FILE" "$contract_file" <<'PY'
import datetime, hashlib, json, pathlib, re, sys
stable, versioned, registry_path, contract_path = map(pathlib.Path, sys.argv[1:])
text = stable.read_text(encoding='utf-8')
contract = json.loads(contract_path.read_text(encoding='utf-8'))
text = re.sub(
    r'(?ms)\n?## 18\. Active-policy dynamic validation and automatic compliance reporting.*?'
    r'<!-- BQCA-ACTIVE-VALIDATION-CONTRACT:END -->\s*',
    '\n',
    text,
)
text = re.sub(
    r'(?ms)\n?<!-- BQCA-ACTIVE-VALIDATION-CONTRACT:BEGIN -->.*?'
    r'<!-- BQCA-ACTIVE-VALIDATION-CONTRACT:END -->\s*',
    '\n',
    text,
)
block = """

## 18. Active-policy dynamic validation and automatic compliance reporting (v48 Update 1)

The active central policy owns design and code validation. Validators, the policy doctor, custom modes, rules, skills, tools, and knowledgebase guidance must never hardcode a policy version or duplicate the full policy. Before every validation, they resolve `.bob/BQCA-ACTIVE-POLICY-REGISTRY.json`, verify the stable and versioned active policies and their SHA-256, and load the machine-readable validation contract embedded below.

When a future policy becomes active, its policy package must update the stable policy, versioned policy, registry, policy SHA-256, and embedded validation contract. The version-neutral listener and validators immediately apply that new authority without source-code modification.

Every governed design and Python code artifact must receive a same-directory compliance report. Design reports use `<artifact>-design-policy-compliance.txt` (or `<artifact>-policy-compliance.txt` when the source already ends in `-design`). Code reports use `<artifact>-code-policy-compliance.txt` (or `<artifact>-policy-compliance.txt` when the source already ends in `-code`). Reports are written for both compliant and non-compliant artifacts and contain the active policy version/path/hash, validation-contract hash, artifact SHA-256, validation date/time, gate results, findings, and final status.

`qiskit-design-policy-check.py` and `qiskit-code-policy-check.py` are version-neutral wrappers. `qiskit-connector.sh --validate-design` and `--validate-code` must synchronize with the active policy before invoking them. `bqca-policy-doctor.sh` must resolve and assure whichever policy is active. Automatic compliance monitoring revalidates governed artifacts after source changes and after active-policy changes.

<!-- BQCA-ACTIVE-VALIDATION-CONTRACT:BEGIN -->
```json
""" + json.dumps(contract, indent=2, sort_keys=True) + """
```
<!-- BQCA-ACTIVE-VALIDATION-CONTRACT:END -->
"""
new_text = text.rstrip() + block + '\n'
stable.write_text(new_text, encoding='utf-8')
versioned.write_text(new_text, encoding='utf-8')
policy_hash = hashlib.sha256(new_text.encode('utf-8')).hexdigest()
registry = json.loads(registry_path.read_text(encoding='utf-8'))
registry['schema_version'] = max(int(registry.get('schema_version', 0)), 4)
registry['active_version'] = 'v48'
registry['active_policy_path'] = '.bob/BQCA-PRODUCTION-POLICY.md'
registry['policy_path'] = '.bob/BQCA-PRODUCTION-POLICY.md'
registry['versioned_policy_path'] = '.bob/BQCA-PRODUCTION-POLICY-v48.md'
registry['policy_sha256'] = policy_hash
registry['canonical_policy_sha256'] = policy_hash
registry['active_policy_listener_path'] = '.bob/quantum-tools/bqca-active-policy-listener.sh'
registry['active_policy_resolver_path'] = '.bob/quantum-tools/bqca_active_policy.py'
registry['active_policy_state_cache'] = '.bob/runtime/BQCA-active-policy-state.json'
registry['dynamic_validator_path'] = '.bob/quantum-tools/bqca-dynamic-validator.py'
registry['design_validator_path'] = '.bob/quantum-tools/qiskit-design-policy-check.py'
registry['code_validator_path'] = '.bob/quantum-tools/qiskit-code-policy-check.py'
registry['policy_compliance_controller_path'] = '.bob/quantum-tools/bqca-policy-compliance.sh'
registry['policy_compliance_watcher_path'] = '.bob/quantum-tools/bqca-policy-compliance-watcher.py'
registry['repair_patch_path'] = 'patches/BQCA/patch-BQCA.v48-update-1.sh'
registry['validation_contract'] = {
    'source': 'embedded-in-active-policy',
    'begin_marker': '<!-- BQCA-ACTIVE-VALIDATION-CONTRACT:BEGIN -->',
    'end_marker': '<!-- BQCA-ACTIVE-VALIDATION-CONTRACT:END -->',
    'schema_version': contract.get('schema_version'),
    'policy_version': contract.get('policy_version'),
}
registry['compliance_reporting'] = contract.get('compliance_reporting', {})
registry['updated_utc'] = datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
authority = registry.setdefault('active_authority', {})
authority.update({
    'version': 'v48',
    'stable_policy': '.bob/BQCA-PRODUCTION-POLICY.md',
    'versioned_policy': '.bob/BQCA-PRODUCTION-POLICY-v48.md',
    'policy_sha256': policy_hash,
})
temporary = registry_path.with_name('.' + registry_path.name + '.tmp')
temporary.write_text(json.dumps(registry, indent=2, sort_keys=True) + '\n', encoding='utf-8')
temporary.replace(registry_path)
PY
  rm -f "$contract_file"
  chmod 644 "$POLICY_FILE" "$VERSIONED_POLICY_FILE" "$REGISTRY_FILE"
}

patch_qiskit_connector() {
  python3 - "$QISKIT_CONNECTOR" <<'PY'
import pathlib, re, sys
path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding='utf-8')
text = re.sub(r'(?ms)^# BQCA-ACTIVE-POLICY-VALIDATION:BEGIN\n.*?^# BQCA-ACTIVE-POLICY-VALIDATION:END\n?', '', text)
block = r'''# BQCA-ACTIVE-POLICY-VALIDATION:BEGIN
ACTIVE_POLICY_LISTENER="$SCRIPT_DIR/bqca-active-policy-listener.sh"
ACTIVE_DESIGN_VALIDATOR="$SCRIPT_DIR/qiskit-design-policy-check.py"
ACTIVE_CODE_VALIDATOR="$SCRIPT_DIR/qiskit-code-policy-check.py"
case "${1:-}" in
  --validate-code)
    shift
    (($#)) || { printf 'At least one Python artifact is required.\n' >&2; exit 2; }
    "$ACTIVE_POLICY_LISTENER" sync --quiet
    exec python3 "$ACTIVE_CODE_VALIDATOR" "$@"
    ;;
  --validate-design)
    shift
    (($#)) || { printf 'At least one design artifact is required.\n' >&2; exit 2; }
    "$ACTIVE_POLICY_LISTENER" sync --quiet
    exec python3 "$ACTIVE_DESIGN_VALIDATOR" "$@"
    ;;
  --validate-store)
    root="${2:-bob-quantum-store}"
    mapfile -d '' files < <(find "$root" -type f -name '*.py' -print0)
    ((${#files[@]})) || { printf 'No Python files found under %s\n' "$root"; exit 0; }
    "$ACTIVE_POLICY_LISTENER" sync --quiet
    exec python3 "$ACTIVE_CODE_VALIDATOR" "${files[@]}"
    ;;
  --validate-design-store)
    root="${2:-bob-quantum-designs}"
    mapfile -d '' files < <(find "$root" -type f \( -name '*.md' -o -name '*.txt' \) ! -name '*-policy-compliance.txt' -print0)
    ((${#files[@]})) || { printf 'No design files found under %s\n' "$root"; exit 0; }
    "$ACTIVE_POLICY_LISTENER" sync --quiet
    exec python3 "$ACTIVE_DESIGN_VALIDATOR" "${files[@]}"
    ;;
esac
# BQCA-ACTIVE-POLICY-VALIDATION:END
'''
match = re.search(r'(?m)^SCRIPT_DIR=.*$', text)
if not match:
    raise SystemExit('Unable to locate SCRIPT_DIR in qiskit-connector.sh')
text = text[:match.end()] + '\n' + block + text[match.end():]
path.write_text(text, encoding='utf-8')
PY
  chmod 755 "$QISKIT_CONNECTOR"
}

patch_quality_guard() {
  python3 - "$QUALITY_GUARD" <<'PY'
import pathlib, re, sys
path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding='utf-8')
text = re.sub(r'(?ms)^# BQCA-ACTIVE-POLICY-QUALITY-GATE:BEGIN\n.*?^# BQCA-ACTIVE-POLICY-QUALITY-GATE:END\n?', '', text)
vars_block = r'''# BQCA-ACTIVE-POLICY-QUALITY-GATE:BEGIN
ACTIVE_POLICY_LISTENER="$SCRIPT_DIR/bqca-active-policy-listener.sh"
ACTIVE_CODE_VALIDATOR="$SCRIPT_DIR/qiskit-code-policy-check.py"
# BQCA-ACTIVE-POLICY-QUALITY-GATE:END
'''
match = re.search(r'(?m)^SCRIPT_DIR=.*$', text)
if not match:
    raise SystemExit('Unable to locate SCRIPT_DIR in qca-code-quality-guard.sh')
text = text[:match.end()] + '\n' + vars_block + text[match.end():]
new_function = r'''validate_file() {
  local file="$1"
  [[ -f "$file" ]] || { printf '[BQCA] File not found: %s\n' "$file" >&2; return 1; }
  "$ACTIVE_POLICY_LISTENER" sync --quiet
  python3 "$ACTIVE_CODE_VALIDATOR" "$file"
}
'''
text, count = re.subn(r'(?ms)^validate_file\(\) \{\n.*?^\}\n', new_function, text, count=1)
if count != 1:
    raise SystemExit('Unable to replace validate_file in qca-code-quality-guard.sh')
path.write_text(text, encoding='utf-8')
PY
  chmod 755 "$QUALITY_GUARD"
}

patch_xlaunchpad() {
  python3 - "$XLAUNCHPAD" <<'PY'
import pathlib, re, sys
path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding='utf-8')
text = re.sub(r'(?ms)^# BQCA-POLICY-ASSURANCE-v\d+:BEGIN\n.*?^# BQCA-POLICY-ASSURANCE-v\d+:END\n?', '', text)
text = re.sub(r'(?ms)^# BQCA-ACTIVE-POLICY-ASSURANCE:BEGIN\n.*?^# BQCA-ACTIVE-POLICY-ASSURANCE:END\n?', '', text)
text = re.sub(r'(?ms)^# BQCA-AUTOMATIC-POLICY-COMPLIANCE:BEGIN\n.*?^# BQCA-AUTOMATIC-POLICY-COMPLIANCE:END\n?', '', text)
text = re.sub(r'(?ms)^# BQCA-COMBINED-RUNTIME-CLEANUP:BEGIN\n.*?^# BQCA-COMBINED-RUNTIME-CLEANUP:END\n?', '', text)
assurance = r'''# BQCA-ACTIVE-POLICY-ASSURANCE:BEGIN
_BQCA_ACTIVE_POLICY_LISTENER="${SCRIPT_DIR}/.bob/quantum-tools/bqca-active-policy-listener.sh"
_BQCA_ACTIVE_POLICY_DOCTOR="${SCRIPT_DIR}/.bob/quantum-tools/bqca-policy-doctor.sh"
_BQCA_ACTIVE_POLICY_COMPLIANCE="${SCRIPT_DIR}/.bob/quantum-tools/bqca-policy-compliance.sh"
for _bqca_policy_tool in \
  "${_BQCA_ACTIVE_POLICY_LISTENER}" \
  "${_BQCA_ACTIVE_POLICY_DOCTOR}" \
  "${_BQCA_ACTIVE_POLICY_COMPLIANCE}"; do
  if [[ ! -x "${_bqca_policy_tool}" ]]; then
    printf '[BQCA][ERROR] Active-policy tool is missing: %s\n' "${_bqca_policy_tool}" >&2
    exit 1
  fi
done
if ! "${_BQCA_ACTIVE_POLICY_LISTENER}" sync --quiet; then
  printf '[BQCA][ERROR] Unable to resolve the active BQCA policy.\n' >&2
  exit 1
fi
# A newly activated policy changes the policy/contract hashes. Refresh every
# governed artifact report before the doctor evaluates drift so policy changes
# do not require validator or launcher source modifications.
_BQCA_PREFLIGHT_DESIGN_STORE="${QCA_DESIGN_DIR:-${SCRIPT_DIR}/bob-quantum-designs}"
_BQCA_PREFLIGHT_CODE_STORE="${QCA_STORE_DIR:-${SCRIPT_DIR}/bob-quantum-store}"
if [[ "${_BQCA_PREFLIGHT_DESIGN_STORE}" != /* ]]; then
  _BQCA_PREFLIGHT_DESIGN_STORE="${SCRIPT_DIR}/${_BQCA_PREFLIGHT_DESIGN_STORE}"
fi
if [[ "${_BQCA_PREFLIGHT_CODE_STORE}" != /* ]]; then
  _BQCA_PREFLIGHT_CODE_STORE="${SCRIPT_DIR}/${_BQCA_PREFLIGHT_CODE_STORE}"
fi
if ! "${_BQCA_ACTIVE_POLICY_COMPLIANCE}" sweep \
  --design-store "${_BQCA_PREFLIGHT_DESIGN_STORE}" \
  --code-store "${_BQCA_PREFLIGHT_CODE_STORE}" >/dev/null 2>&1; then
  printf '[BQCA][ERROR] Unable to refresh active-policy compliance reports.\n' >&2
  exit 1
fi
if ! "${_BQCA_ACTIVE_POLICY_DOCTOR}" check --quiet; then
  _BQCA_ACTIVE_POLICY_VERSION="$("${_BQCA_ACTIVE_POLICY_LISTENER}" version 2>/dev/null || printf 'UNKNOWN')"
  printf '[BQCA][ERROR] BQCA %s active-policy drift detected. Run: %s repair\n' \
    "${_BQCA_ACTIVE_POLICY_VERSION}" "${_BQCA_ACTIVE_POLICY_DOCTOR}" >&2
  exit 1
fi
unset _bqca_policy_tool _BQCA_ACTIVE_POLICY_VERSION \
  _BQCA_PREFLIGHT_DESIGN_STORE _BQCA_PREFLIGHT_CODE_STORE
# BQCA-ACTIVE-POLICY-ASSURANCE:END
'''

needle = 'set +a\n'
if needle not in text:
    raise SystemExit('Unable to locate environment-loading boundary in xLaunchpad.sh')
text = text.replace(needle, needle + '\n' + assurance + '\n', 1)
compliance = r'''# BQCA-AUTOMATIC-POLICY-COMPLIANCE:BEGIN
_BQCA_POLICY_COMPLIANCE_TOOL="${SCRIPT_DIR}/.bob/quantum-tools/bqca-policy-compliance.sh"
_BQCA_POLICY_DESIGN_STORE="${QCA_DESIGN_DIR:-${SCRIPT_DIR}/bob-quantum-designs}"
_BQCA_POLICY_CODE_STORE="${QCA_STORE_DIR:-${SCRIPT_DIR}/bob-quantum-store}"
for _bqca_store_var in _BQCA_POLICY_DESIGN_STORE _BQCA_POLICY_CODE_STORE; do
  if [[ "${!_bqca_store_var}" != /* ]]; then
    printf -v "${_bqca_store_var}" '%s/%s' "${SCRIPT_DIR}" "${!_bqca_store_var}"
  fi
done
if [[ ! -x "${_BQCA_POLICY_COMPLIANCE_TOOL}" ]]; then
  printf '[BQCA][ERROR] Automatic policy-compliance tool is missing: %s\n' \
    "${_BQCA_POLICY_COMPLIANCE_TOOL}" >&2
  exit 1
fi
"${_BQCA_POLICY_COMPLIANCE_TOOL}" start \
  --design-store "${_BQCA_POLICY_DESIGN_STORE}" \
  --code-store "${_BQCA_POLICY_CODE_STORE}" >/dev/null 2>&1
_bqca_policy_compliance_cleanup() {
  "${_BQCA_POLICY_COMPLIANCE_TOOL}" stop >/dev/null 2>&1 || true
  "${_BQCA_POLICY_COMPLIANCE_TOOL}" sweep \
    --design-store "${_BQCA_POLICY_DESIGN_STORE}" \
    --code-store "${_BQCA_POLICY_CODE_STORE}" >/dev/null 2>&1 || true
}
unset _bqca_store_var
# BQCA-AUTOMATIC-POLICY-COMPLIANCE:END
'''
notebook_marker = '# BQCA-NOTEBOOK-AUTOGEN-v37:BEGIN'
pos = text.find(notebook_marker)
if pos < 0:
    raise SystemExit('Unable to locate notebook-autogen block in xLaunchpad.sh')
text = text[:pos] + compliance + '\n\n' + text[pos:]
text = re.sub(r'(?m)^\s*trap\s+[^\n]*(?:_bqca_notebook_autogen_cleanup|_bqca_policy_compliance_cleanup|_bqca_combined_runtime_cleanup)[^\n]*EXIT\s*\n?', '', text)
end_marker = '#===============================================================================\n# BQCA-NOTEBOOK-AUTOGEN-v37:END\n#============================================================================='
if end_marker not in text:
    raise SystemExit('Unable to locate notebook-autogen end boundary in xLaunchpad.sh')
combined = r'''# BQCA-COMBINED-RUNTIME-CLEANUP:BEGIN
_bqca_combined_runtime_cleanup() {
  _bqca_policy_compliance_cleanup || true
  _bqca_notebook_autogen_cleanup || true
}
trap _bqca_combined_runtime_cleanup EXIT
# BQCA-COMBINED-RUNTIME-CLEANUP:END
'''
text = text.replace(end_marker, end_marker + '\n\n' + combined, 1)
path.write_text(text, encoding='utf-8')
PY
  chmod 755 "$XLAUNCHPAD"
}

patch_bob_launchers() {
  while IFS= read -r -d '' file; do
    python3 - "$file" <<'PY'
import pathlib, re, sys
path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding='utf-8')
text = re.sub(r'(?ms)^# BQCA-ACTIVE-POLICY-RUNTIME-EXPORT:BEGIN\n.*?^# BQCA-ACTIVE-POLICY-RUNTIME-EXPORT:END\n?', '', text)
block = r'''# BQCA-ACTIVE-POLICY-RUNTIME-EXPORT:BEGIN
_BQCA_ACTIVE_POLICY_LISTENER="${SCRIPT_DIR}/.bob/quantum-tools/bqca-active-policy-listener.sh"
if [[ -x "${_BQCA_ACTIVE_POLICY_LISTENER}" ]]; then
  export BQCA_ACTIVE_POLICY_VERSION="$("${_BQCA_ACTIVE_POLICY_LISTENER}" version)"
  export BQCA_ACTIVE_POLICY_PATH="$("${_BQCA_ACTIVE_POLICY_LISTENER}" policy-path)"
  export BQCA_ACTIVE_POLICY_CONTRACT="$("${_BQCA_ACTIVE_POLICY_LISTENER}" field contract_sha256)"
fi
# BQCA-ACTIVE-POLICY-RUNTIME-EXPORT:END
'''
match = re.search(r'(?m)^SCRIPT_DIR=.*$', text)
if match:
    text = text[:match.end()] + '\n' + block + text[match.end():]
else:
    text = block + '\n' + text
path.write_text(text, encoding='utf-8')
PY
    chmod 755 "$file"
  done < <(find "$BQCA_ROOT" -maxdepth 1 -type f -name 'bob-quantum-v*.sh' -print0)
}

patch_awareness_surfaces() {
  python3 - "$BQCA_ROOT" <<'PY'
import pathlib, re, sys
root = pathlib.Path(sys.argv[1])
bob = root / '.bob'
html_block = """
<!-- BQCA-ACTIVE-CENTRAL-POLICY:BEGIN -->
## Active central policy binding
Before every quantum DESIGN or CODE decision, resolve the currently active authority through `.bob/quantum-tools/bqca-active-policy-listener.sh sync`. Read the stable policy and its embedded validation contract returned by the listener. Never hardcode a policy version or duplicate the complete central policy in this component.

Validate every design through `.bob/quantum-tools/qiskit-design-policy-check.py` and every Python code artifact through `.bob/quantum-tools/qiskit-code-policy-check.py`. The validators reload the registry, policy, policy SHA-256, and validation contract on every invocation and automatically create the required same-directory design/code policy-compliance report. Do not report an artifact complete unless its compliance report exists and reflects the active policy.
<!-- BQCA-ACTIVE-CENTRAL-POLICY:END -->
""".strip()
comment_lines = [
    '# BQCA-ACTIVE-CENTRAL-POLICY:BEGIN',
    '# Resolve the active authority through bqca-active-policy-listener.sh before',
    '# every quantum DESIGN or CODE decision. Never hardcode a policy version or',
    '# duplicate the full policy here. qiskit-design-policy-check.py and',
    '# qiskit-code-policy-check.py reload the active registry/policy/contract on',
    '# every invocation and create same-directory policy-compliance reports.',
    '# Do not report completion until the active-policy report exists.',
    '# BQCA-ACTIVE-CENTRAL-POLICY:END',
]
comment_block = '\n'.join(comment_lines)

def clean(text: str) -> str:
    text = re.sub(r'(?ms)\n?<!-- BQCA-ACTIVE-CENTRAL-POLICY:BEGIN -->.*?<!-- BQCA-ACTIVE-CENTRAL-POLICY:END -->\n?', '\n', text)
    text = re.sub(r'(?ms)\n?<!-- BQCA-CANONICAL-PRODUCTION-POLICY-v\d+(?:-[^:]*)?:BEGIN -->.*?<!-- BQCA-CANONICAL-PRODUCTION-POLICY-v\d+(?:-[^:]*)?:END -->\n?', '\n', text)
    text = re.sub(r'(?ms)^([ \t]*)# BQCA-ACTIVE-CENTRAL-POLICY:BEGIN\n.*?^\1# BQCA-ACTIVE-CENTRAL-POLICY:END\n?', '', text)
    text = re.sub(r'(?ms)^([ \t]*)# BQCA-CANONICAL-PRODUCTION-POLICY-v\d+(?:-[^:]*)?:BEGIN\n.*?^\1# BQCA-CANONICAL-PRODUCTION-POLICY-v\d+(?:-[^:]*)?:END\n?', '', text)
    return text.rstrip()

custom = bob / 'custom_modes.yaml'
text = clean(custom.read_text(encoding='utf-8'))
lines = text.splitlines()
result = []
count = 0
pattern = re.compile(r'^(?P<indent>[ \t]*)customInstructions:\s*[>|][+-]?\s*(?:#.*)?$')
for line in lines:
    result.append(line)
    match = pattern.match(line)
    if not match:
        continue
    indent = match.group('indent') + '  '
    result.extend(indent + item for item in comment_lines)
    count += 1
if count == 0:
    raise SystemExit('No customInstructions block scalars found in custom_modes.yaml')
custom.write_text('\n'.join(result) + '\n', encoding='utf-8')

extensions = {'.md', '.txt', '.sh', '.py', '.yaml', '.yml'}
files = []
for directory in bob.glob('rules-*'):
    if directory.is_dir():
        files.extend(path for path in directory.rglob('*') if path.is_file() and path.suffix.lower() in extensions)
skills = bob / 'skills'
if skills.is_dir():
    files.extend(path for path in skills.rglob('*') if path.is_file() and path.suffix.lower() in extensions)
tools = bob / 'quantum-tools'
if tools.is_dir():
    files.extend(path for path in tools.iterdir() if path.is_file() and path.suffix.lower() in extensions)
for relative in ('README.md', 'bqca_quantum_kb.py'):
    path = tools / 'knowlegebase' / relative
    if path.is_file():
        files.append(path)
for path in sorted(set(files)):
    value = clean(path.read_text(encoding='utf-8', errors='replace'))
    block = html_block if path.suffix.lower() in {'.md', '.txt'} else comment_block
    path.write_text(value + '\n\n' + block + '\n', encoding='utf-8')
print(f'custom_modes={count} awareness_files={len(set(files))}')
PY
}

write_patch_record() {
  mkdir -p "$PATCH_RECORD_DIR"
  cat > "$PATCH_RECORD_FILE" <<RECORD
Patch: $PATCH_ID
Applied: $(date -u '+%Y-%m-%dT%H:%M:%SZ')
Root: $BQCA_ROOT
Backup: $BACKUP_DIR
Active policy: v48 (concepts preserved)
Behavior: validators and policy doctor dynamically resolve the active central policy; automatic design/code compliance reports enabled
Protected assets: .env, HOME qiskit-v2x-env, HOME .qiskit/qiskit-ibm.json
Source design/code artifacts: not rewritten
RECORD
  chmod 644 "$PATCH_RECORD_FILE"
}

run_compliance_sweep() {
  "$COMPLIANCE_CONTROLLER" stop >/dev/null 2>&1 || true
  "$COMPLIANCE_CONTROLLER" sweep \
    --design-store "$DESIGN_STORE" \
    --code-store "$CODE_STORE" >/dev/null
}

validate_installation() {
  local failures=0 test_dir design_dir code_dir design_file code_file design_report code_report
  local future_root future_tools future_design future_code future_output future_rc
  "$ACTIVE_POLICY_SH" validate >/dev/null || { warn "Active-policy listener validation failed"; failures=$((failures+1)); }
  cmp -s "$POLICY_FILE" "$VERSIONED_POLICY_FILE" || { warn "Stable and versioned v48 policies differ"; failures=$((failures+1)); }

  for file in "$ACTIVE_POLICY_PY" "$DYNAMIC_VALIDATOR" "$DESIGN_WRAPPER" "$CODE_WRAPPER" "$DOCTOR_PY" "$COMPLIANCE_WATCHER"; do
    [[ -x "$file" ]] || { warn "Missing executable: $file"; failures=$((failures+1)); continue; }
    python3 -m py_compile "$file" || failures=$((failures+1))
  done
  for file in "$ACTIVE_POLICY_SH" "$DOCTOR_SH" "$COMPLIANCE_CONTROLLER" "$QISKIT_CONNECTOR" "$QUALITY_GUARD" "$XLAUNCHPAD"; do
    [[ -x "$file" ]] || { warn "Missing executable: $file"; failures=$((failures+1)); continue; }
    bash -n "$file" || failures=$((failures+1))
  done

  grep -Fq 'BQCA-ACTIVE-POLICY-VALIDATION:BEGIN' "$QISKIT_CONNECTOR" || { warn "qiskit-connector active-policy interception is missing"; failures=$((failures+1)); }
  grep -Fq 'bqca-dynamic-validator.py' "$DESIGN_WRAPPER" || { warn "design validator is not dynamic"; failures=$((failures+1)); }
  grep -Fq 'bqca-dynamic-validator.py' "$CODE_WRAPPER" || { warn "code validator is not dynamic"; failures=$((failures+1)); }
  grep -Fq 'BQCA-ACTIVE-POLICY-ASSURANCE:BEGIN' "$XLAUNCHPAD" || { warn "xLaunchpad active-policy assurance is missing"; failures=$((failures+1)); }
  grep -Fq 'BQCA-AUTOMATIC-POLICY-COMPLIANCE:BEGIN' "$XLAUNCHPAD" || { warn "xLaunchpad compliance watcher is missing"; failures=$((failures+1)); }

  run_compliance_sweep || { warn "Compliance-report sweep encountered an internal error"; failures=$((failures+1)); }

  test_dir="$(mktemp -d "$BQCA_ROOT/.bqca-v48u1-test.XXXXXX")"
  design_dir="$DESIGN_STORE/.bqca-v48u1-test"
  code_dir="$CODE_STORE/.bqca-v48u1-test"
  mkdir -p "$design_dir" "$code_dir"
  design_file="$design_dir/active-policy-test-design.md"
  code_file="$code_dir/active-policy-test.py"
  cat > "$design_file" <<'DESIGN'
# Active Policy Test Design
Problem/objective: validate a two-qubit sampling algorithm.
Algorithm: Bell-state sampling. The circuit uses two qubits and includes validation criteria, risks, limitations, and expected artifacts.
Use Qiskit Connector for account/backend selection. Use $HOME/qiskit-v2x-env and activate it with source "$HOME/qiskit-v2x-env/bin/activate". Qiskit 2.5 or later is required.
Open Plan must not use Session. Use SamplerV2(mode=backend) for samples/counts and EstimatorV2(mode=backend) for expectation values/energy. Paid Plan uses Session with SamplerV2(mode=session) or EstimatorV2(mode=session).
Attempt a real QPU first. Use a controlled try/except fallback with transpile and AerSimulator. backend.run() is prohibited on real QPU hardware.
Use bqca-direct-execution.sh for development and debugging. The orchestrator/formal-run is opt-in for formal compliance, production deployment, or audit.
The result contract creates <source-stem>-result-output.txt and output.txt, streams stdout and stderr live to the terminal, records timestamps, completion, duration, exit status, and ends with RESULT SUMMARY. For real QPU results, JOB ID is on the first line. Missing markers are non-blocking policy gaps/warnings; credential leakage is blocking.
DESIGN
  cat > "$code_file" <<'CODE'
"""Qiskit >= 2.5. Execute with $HOME/qiskit-v2x-env via bqca-direct-execution.sh."""
from qiskit import QuantumCircuit, transpile
from qiskit_aer import AerSimulator
from qiskit_ibm_runtime import SamplerV2, EstimatorV2, Session
from qiskit_connector import QConnectorV2 as connector
from qiskit_connector import QPlanV2 as plan
current = plan()
backend = connector()
required_qubits = 2
status = backend.status()
if not status.operational or backend.num_qubits < required_qubits:
    raise RuntimeError("QPU unavailable or insufficient qubit capacity")
try:
    if "open" in str(current).lower():
        sampler = SamplerV2(mode=backend)
        # EstimatorV2(mode=backend) is selected for expectation/energy workloads.
        job = sampler.run([], shots=1)
    else:
        with Session(backend=backend) as session:
            sampler = SamplerV2(mode=session)
            # EstimatorV2(mode=session) is selected for expectation/energy workloads.
            job = sampler.run([], shots=1)
    print("BQCA_EXECUTION_TARGET=REAL_QPU")
    print(f"BQCA_JOB_ID={job.job_id()}")
    print("BQCA_RESULT=SUCCESS")
except Exception as exc:
    sim_backend = AerSimulator()
    qc = transpile(QuantumCircuit(2), sim_backend)
    sim_backend.run(qc, shots=1).result()
    print("BQCA_EXECUTION_TARGET=SIMULATOR")
    print(f"BQCA_FALLBACK_REASON={exc}")
    print("BQCA_RESULT=SUCCESS")
print(f"BQCA_PLAN={current}")
print(f"BQCA_BACKEND={getattr(backend, 'name', 'unknown')}")
CODE
  python3 "$DESIGN_WRAPPER" "$design_file" >/dev/null || { warn "Synthetic design validation failed"; failures=$((failures+1)); }
  python3 "$CODE_WRAPPER" "$code_file" >/dev/null || { warn "Synthetic code validation failed"; failures=$((failures+1)); }
  design_report="$design_dir/active-policy-test-design-policy-compliance.txt"
  code_report="$code_dir/active-policy-test-code-policy-compliance.txt"
  [[ -f "$design_report" ]] || { warn "Design compliance report was not created"; failures=$((failures+1)); }
  [[ -f "$code_report" ]] || { warn "Code compliance report was not created"; failures=$((failures+1)); }
  if [[ -f "$design_report" ]]; then
    grep -Fq 'FORMAL POLICY COMPLIANCE REPORT' "$design_report" || failures=$((failures+1))
    grep -Fq 'FINAL STATUS            : COMPLIANT' "$design_report" || failures=$((failures+1))
  fi
  if [[ -f "$code_report" ]]; then
    grep -Fq 'FORMAL POLICY COMPLIANCE REPORT' "$code_report" || failures=$((failures+1))
    grep -Fq 'FINAL STATUS            : COMPLIANT' "$code_report" || failures=$((failures+1))
  fi

  # Isolated future-policy binding test. Only the central policy package is
  # changed; validator source files are copied byte-for-byte and must adopt the
  # new version and newly declared design/code needles automatically.
  future_root="$test_dir/future-policy-root"
  future_tools="$future_root/.bob/quantum-tools"
  future_design="$future_root/bob-quantum-designs/future-design.md"
  future_code="$future_root/bob-quantum-store/future.py"
  mkdir -p "$future_tools" "$(dirname "$future_design")" "$(dirname "$future_code")"
  cp "$POLICY_FILE" "$future_root/.bob/BQCA-PRODUCTION-POLICY.md"
  cp "$REGISTRY_FILE" "$future_root/.bob/BQCA-ACTIVE-POLICY-REGISTRY.json"
  cp "$ACTIVE_POLICY_PY" "$future_tools/bqca_active_policy.py"
  cp "$DYNAMIC_VALIDATOR" "$future_tools/bqca-dynamic-validator.py"
  cp "$DESIGN_WRAPPER" "$future_tools/qiskit-design-policy-check.py"
  cp "$CODE_WRAPPER" "$future_tools/qiskit-code-policy-check.py"
  cp "$design_file" "$future_design"
  cp "$code_file" "$future_code"
  : > "$future_root/xLaunchpad.sh"
  chmod 755 "$future_tools"/*.py "$future_root/xLaunchpad.sh"
  python3 - "$future_root" <<'PY_FUTURE_POLICY'
import hashlib, json, pathlib, re, sys
root = pathlib.Path(sys.argv[1])
policy = root / '.bob/BQCA-PRODUCTION-POLICY.md'
text = policy.read_text(encoding='utf-8')
begin = '<!-- BQCA-ACTIVE-VALIDATION-CONTRACT:BEGIN -->'
end = '<!-- BQCA-ACTIVE-VALIDATION-CONTRACT:END -->'
start = text.find(begin)
finish = text.find(end)
if start < 0 or finish < 0 or finish <= start:
    raise SystemExit('future-policy test cannot locate validation contract')
payload = text[start + len(begin):finish].strip()
if payload.startswith('```json'):
    payload = payload[len('```json'):].strip()
    if payload.endswith('```'):
        payload = payload[:-3].strip()
contract = json.loads(payload)
contract['policy_version'] = 'v999'
for kind, gate_id, literal in (
    ('design', 'design_policy', 'FUTURE_DESIGN_NEEDLE'),
    ('code', 'result_output_contract', 'FUTURE_CODE_NEEDLE'),
):
    gates = contract.get(kind, {}).get('gates', [])
    gate = next((item for item in gates if item.get('id') == gate_id), None)
    if gate is None:
        raise SystemExit(f'future-policy test cannot locate {kind} gate {gate_id}')
    gate.setdefault('required_literals', []).append(literal)
contract_text = '```json\n' + json.dumps(contract, indent=2, sort_keys=True) + '\n```'
text = text[:start + len(begin)] + '\n' + contract_text + '\n' + text[finish:]
text = re.sub(r'(?m)^(# .*?Policy )v48\b', r'\1v999', text, count=1)
policy.write_text(text, encoding='utf-8')
versioned = root / '.bob/BQCA-PRODUCTION-POLICY-v999.md'
versioned.write_text(text, encoding='utf-8')
policy_hash = hashlib.sha256(policy.read_bytes()).hexdigest()
registry_path = root / '.bob/BQCA-ACTIVE-POLICY-REGISTRY.json'
registry = json.loads(registry_path.read_text(encoding='utf-8'))
registry['active_version'] = 'v999'
registry['active_policy_path'] = '.bob/BQCA-PRODUCTION-POLICY.md'
registry['policy_path'] = '.bob/BQCA-PRODUCTION-POLICY.md'
registry['versioned_policy_path'] = '.bob/BQCA-PRODUCTION-POLICY-v999.md'
registry['policy_sha256'] = policy_hash
registry['canonical_policy_sha256'] = policy_hash
registry.setdefault('active_authority', {})['version'] = 'v999'
registry['active_authority']['stable_policy'] = '.bob/BQCA-PRODUCTION-POLICY.md'
registry['active_authority']['versioned_policy'] = '.bob/BQCA-PRODUCTION-POLICY-v999.md'
registry['active_authority']['policy_sha256'] = policy_hash
registry.setdefault('validation_contract', {})['policy_version'] = 'v999'
registry_path.write_text(json.dumps(registry, indent=2, sort_keys=True) + '\n', encoding='utf-8')
PY_FUTURE_POLICY

  set +e
  future_output="$(BQCA_ROOT="$future_root" python3 "$future_tools/qiskit-design-policy-check.py" "$future_design" 2>&1)"
  future_rc=$?
  set -e
  if [[ "$future_rc" -ne 1 ]] || ! grep -Fq 'FUTURE_DESIGN_NEEDLE' <<<"$future_output" || ! grep -Fq 'active_policy=v999' <<<"$future_output"; then
    warn "Dynamic design validator did not adopt the simulated future policy"
    failures=$((failures+1))
  fi
  set +e
  future_output="$(BQCA_ROOT="$future_root" python3 "$future_tools/qiskit-code-policy-check.py" "$future_code" 2>&1)"
  future_rc=$?
  set -e
  if [[ "$future_rc" -ne 1 ]] || ! grep -Fq 'FUTURE_CODE_NEEDLE' <<<"$future_output" || ! grep -Fq 'active_policy=v999' <<<"$future_output"; then
    warn "Dynamic code validator did not adopt the simulated future policy"
    failures=$((failures+1))
  fi
  printf '\nFUTURE_DESIGN_NEEDLE\n' >> "$future_design"
  printf '\n# FUTURE_CODE_NEEDLE\n' >> "$future_code"
  BQCA_ROOT="$future_root" python3 "$future_tools/qiskit-design-policy-check.py" "$future_design" >/dev/null || {
    warn "Dynamic design validator did not pass after satisfying the future-policy needle"
    failures=$((failures+1))
  }
  BQCA_ROOT="$future_root" python3 "$future_tools/qiskit-code-policy-check.py" "$future_code" >/dev/null || {
    warn "Dynamic code validator did not pass after satisfying the future-policy needle"
    failures=$((failures+1))
  }

  rm -rf "$design_dir" "$code_dir" "$test_dir"

  "$DOCTOR_SH" check --quiet || { warn "Active-policy doctor assurance failed"; "$DOCTOR_SH" report >&2 || true; failures=$((failures+1)); }

  if ((failures)); then
    fail "v48 Update 1 validation failed with $failures issue(s)."
  fi
  info "Validation passed: design/code validators, policy doctor, active-policy listener, and automatic compliance reports follow the current central policy."
}

if ((VALIDATE_ONLY)); then
  validate_installation
  exit 0
fi

create_backup
mkdir -p "$TOOLS_DIR" "$RUNTIME_DIR" "$PATCH_RECORD_DIR"
chmod 700 "$RUNTIME_DIR" 2>/dev/null || true
"$COMPLIANCE_CONTROLLER" stop >/dev/null 2>&1 || true

write_active_policy_py
write_active_policy_sh
write_dynamic_validator
write_design_wrapper
write_code_wrapper
write_doctor_py
write_doctor_sh
write_compliance_watcher
write_compliance_controller
patch_policy_and_registry
patch_qiskit_connector
patch_quality_guard
patch_xlaunchpad
patch_bob_launchers
patch_awareness_surfaces
write_patch_record
run_compliance_sweep
validate_installation

info "Patch $PATCH_ID applied successfully."
info "Backup: $BACKUP_DIR"
info "Active-policy listener: .bob/quantum-tools/bqca-active-policy-listener.sh"
info "Dynamic validator: .bob/quantum-tools/bqca-dynamic-validator.py"
info "Compliance controller: .bob/quantum-tools/bqca-policy-compliance.sh"
info "The active v48 policy concepts and existing execution workflow were preserved."
