#!/usr/bin/env python3
"""BQCA v48 direct execution behavioral smoke tests."""
from __future__ import annotations
import argparse, os, pathlib, subprocess, sys, tempfile, textwrap, time


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True, type=pathlib.Path)
    args = parser.parse_args()
    root = args.root.resolve()
    tools = root / ".bob/quantum-tools"
    direct = tools / "bqca-direct-execution.sh"
    with tempfile.TemporaryDirectory(prefix="bqca-v48-test-") as tmp_raw:
        temp = pathlib.Path(tmp_raw)
        source = temp / "direct-live.py"
        source.write_text(textwrap.dedent('''\
            import sys, time
            print("DIRECT_STDOUT_FIRST", flush=True)
            time.sleep(2.0)
            print("DIRECT_STDERR_SECOND", file=sys.stderr, flush=True)
            print("BQCA_EXECUTION_TARGET=SIMULATOR", flush=True)
            print("BQCA_PLAN=Open Plan", flush=True)
            print("BQCA_BACKEND=aer_simulator", flush=True)
            print("BQCA_RESULT=v48-direct-pass", flush=True)
        '''), encoding="utf-8")
        terminal = temp / "terminal.log"
        env = os.environ.copy()
        env.update({
            "BQCA_V48_TEST_MODE": "1",
            "BQCA_V48_SKIP_CONFIGURATION": "1",
            "BQCA_V48_TEST_PYTHON": sys.executable,
        })
        with terminal.open("wb") as stream:
            proc = subprocess.Popen([str(direct), "run", str(source)], stdout=stream, stderr=subprocess.STDOUT, env=env)
            deadline = time.time() + 1.5
            early = ""
            while time.time() < deadline:
                early = terminal.read_text(encoding="utf-8", errors="replace")
                if "DIRECT_STDOUT_FIRST" in early or proc.poll() is not None:
                    break
                time.sleep(0.1)
            if "DIRECT_STDOUT_FIRST" not in early:
                proc.kill()
                raise RuntimeError("v47 direct output did not reach the terminal live")
            if proc.poll() is not None:
                raise RuntimeError("v47 direct process ended before live-output assertion")
            status = proc.wait(timeout=10)
            if status != 0:
                raise RuntimeError(f"v47 direct execution returned {status}")
        canonical = temp / "direct-live-result-output.txt"
        mirror = temp / "output.txt"
        if not canonical.is_file() or not mirror.is_file():
            raise RuntimeError("v47 did not create both result files")
        if canonical.read_bytes() != mirror.read_bytes():
            raise RuntimeError("output.txt does not match the canonical result")
        report = canonical.read_text(encoding="utf-8", errors="replace")
        for token in ("DIRECT_STDOUT_FIRST", "DIRECT_STDERR_SECOND", "BQCA_RESULT=v48-direct-pass", "Execution method        : DIRECT", "Execution successful    : YES", "RESULT SUMMARY"):
            if token not in report:
                raise RuntimeError(f"v47 result report is missing: {token}")
        matrix = subprocess.run([str(direct), "decision-matrix"], text=True, capture_output=True)
        if matrix.returncode or "Production Deployment    Orchestrator" not in matrix.stdout:
            raise RuntimeError("v47 execution decision matrix is unavailable")
    print("BQCA_V48_TEST_SUITE=PASS")
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
