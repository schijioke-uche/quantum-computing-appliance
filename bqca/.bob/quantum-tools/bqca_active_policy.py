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

# BQCA-ACTIVE-CENTRAL-POLICY:BEGIN
# Resolve the active authority through bqca-active-policy-listener.sh before
# every quantum DESIGN or CODE decision. Never hardcode a policy version or
# duplicate the full policy here. qiskit-design-policy-check.py and
# qiskit-code-policy-check.py reload the active registry/policy/contract on
# every invocation and create same-directory policy-compliance reports.
# Do not report completion until the active-policy report exists.
# BQCA-ACTIVE-CENTRAL-POLICY:END

# BQCA-BOB-SHELL-V2-DNA:BEGIN
# In a trusted Bob Shell 2.x workspace, bind this component to AGENTS.md, the
# active central BQCA policy, exported menu context, current rules/skills/tools,
# and the offline knowledgebase without changing this component's core purpose.
# BQCA-BOB-SHELL-V2-DNA:END
# BQCA-TRUSTED-CHAT-AUTO-APPROVAL-v51.4:BEGIN
# Trusted BQCA chat sessions auto-approve routine project-scoped tool calls at
# session launch. This does not authorize secrets, destructive operations, Bob
# home/settings writes, external paths, or bypass of BQCA policy/safety gates.
# BQCA-TRUSTED-CHAT-AUTO-APPROVAL-v51.4:END
