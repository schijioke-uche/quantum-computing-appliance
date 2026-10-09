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
