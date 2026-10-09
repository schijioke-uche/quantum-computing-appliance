#!/usr/bin/env python3
"""BQCA runtime watcher enforcing automatic notebook creation (v37)."""
from __future__ import annotations

import argparse
import json
import os
import pathlib
import signal
import subprocess
import sys
import time
from dataclasses import dataclass

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
    generated_signature: tuple[int, int] | None = None


def iter_python_files(store: pathlib.Path):
    if not store.exists():
        return
    for path in store.rglob("*.py"):
        if any(part in {".git", "__pycache__", ".venv", "venv", "node_modules"} for part in path.parts):
            continue
        if path.is_file():
            yield path


def notebook_current(source: pathlib.Path, notebook: pathlib.Path) -> bool:
    if not notebook.is_file():
        return False
    try:
        data = json.loads(notebook.read_text(encoding="utf-8"))
        digest = data.get("metadata", {}).get("bqca", {}).get("source_sha256")
        import hashlib
        expected = hashlib.sha256(source.read_bytes()).hexdigest()
        return digest == expected
    except Exception:
        return False


def generate(generator: pathlib.Path, source: pathlib.Path, log) -> bool:
    notebook = source.with_suffix(".ipynb")
    command = [str(generator), "--source", str(source), "--force"]
    result = subprocess.run(command, text=True, capture_output=True)
    stamp = time.strftime("%Y-%m-%dT%H:%M:%S%z")
    if result.returncode == 0:
        verify = subprocess.run(
            [str(generator), "--validate", str(notebook), "--against-source", str(source)],
            text=True,
            capture_output=True,
        )
        if verify.returncode == 0:
            print(f"{stamp} PASS source={source} notebook={notebook}", file=log, flush=True)
            return True
        print(f"{stamp} FAIL validation source={source} stderr={verify.stderr.strip()}", file=log, flush=True)
        return False
    print(f"{stamp} FAIL generation source={source} stderr={result.stderr.strip()}", file=log, flush=True)
    return False


def sweep(store: pathlib.Path, generator: pathlib.Path, log) -> int:
    failures = 0
    for source in iter_python_files(store) or []:
        notebook = source.with_suffix(".ipynb")
        if not notebook_current(source, notebook):
            if not generate(generator, source, log):
                failures += 1
    return failures


def watch(store: pathlib.Path, generator: pathlib.Path, interval: float, stable_scans: int, log) -> int:
    observations: dict[pathlib.Path, Observation] = {}
    while not STOP:
        present: set[pathlib.Path] = set()
        for source in iter_python_files(store) or []:
            present.add(source)
            try:
                stat = source.stat()
            except FileNotFoundError:
                continue
            signature = (stat.st_size, stat.st_mtime_ns)
            item = observations.get(source)
            if item is None:
                observations[source] = Observation(*signature, stable_scans=0)
                continue
            if (item.size, item.mtime_ns) != signature:
                item.size, item.mtime_ns = signature
                item.stable_scans = 0
                continue
            item.stable_scans += 1
            if item.stable_scans < stable_scans:
                continue
            notebook = source.with_suffix(".ipynb")
            if item.generated_signature == signature and notebook_current(source, notebook):
                continue
            if notebook_current(source, notebook):
                item.generated_signature = signature
                continue
            if generate(generator, source, log):
                item.generated_signature = signature
        for missing in set(observations).difference(present):
            observations.pop(missing, None)
        time.sleep(interval)
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--store", required=True, type=pathlib.Path)
    parser.add_argument("--generator", required=True, type=pathlib.Path)
    parser.add_argument("--interval", type=float, default=0.5)
    parser.add_argument("--stable-scans", type=int, default=2)
    parser.add_argument("--sweep", action="store_true")
    parser.add_argument("--log", type=pathlib.Path)
    args = parser.parse_args()

    store = args.store.resolve()
    generator = args.generator.resolve()
    if not generator.is_file() or not os.access(generator, os.X_OK):
        print(f"BQCA_NOTEBOOK_AUTOGEN=FAIL: generator unavailable: {generator}", file=sys.stderr)
        return 2
    store.mkdir(parents=True, exist_ok=True)
    log_stream = args.log.open("a", encoding="utf-8") if args.log else sys.stdout
    try:
        if args.sweep:
            return 1 if sweep(store, generator, log_stream) else 0
        signal.signal(signal.SIGTERM, stop_handler)
        signal.signal(signal.SIGINT, stop_handler)
        print(f"{time.strftime('%Y-%m-%dT%H:%M:%S%z')} START store={store}", file=log_stream, flush=True)
        sweep(store, generator, log_stream)
        return watch(store, generator, args.interval, args.stable_scans, log_stream)
    finally:
        if log_stream is not sys.stdout:
            log_stream.close()


if __name__ == "__main__":
    raise SystemExit(main())

# BQCA-CANONICAL-PRODUCTION-POLICY-v47:BEGIN
# BQCA v47 Update 4: follow .bob/BQCA-PRODUCTION-POLICY.md. Direct execution
# through bqca-direct-execution.sh is the default and must use the authorized
# home Python with unbuffered live stdout/stderr plus dual result capture.
# Code must preserve real-QPU-first plan-aware execution, controlled simulator
# fallback, and the required BQCA markers, including BQCA_RESULT=SUCCESS or
# BQCA_RESULT=FAILURE. The orchestrator is explicit opt-in only for formal
# compliance, deployment, or audit evidence. Direct-mode policy gaps are
# warnings that preserve the workload exit status; credential leakage blocks.
# This block supersedes conflicting local execution guidance.
# BQCA-CANONICAL-PRODUCTION-POLICY-v47:END

# BQCA-QUANTUM-KNOWLEDGEBASE-v47-update-5:BEGIN
# For every quantum DESIGN or CODE intent, consult the canonical index at
# .bob/quantum-tools/knowlegebase/bqca_quantum_kb_index.txt through
# .bob/quantum-tools/bqca-quantum-kb.sh. Access relevant seed URLs and drill
# into at least one relevant sublink from every seed accessed. Preserve a
# <artifact-stem>-kb-research.md trace beside the governed artifact. The
# knowledgebase supplements IBM Bob intelligence and never overrides the active
# central policy. Do not claim compliance when the strict research gate fails.
# This block supersedes conflicting local quantum-knowledge-source guidance.
# BQCA-QUANTUM-KNOWLEDGEBASE-v47-update-5:END
