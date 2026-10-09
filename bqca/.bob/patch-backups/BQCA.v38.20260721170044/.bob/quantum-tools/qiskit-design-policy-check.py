#!/usr/bin/env python3
"""BQCA v34 textual-only Qiskit Connector design-policy validator."""
from __future__ import annotations
import argparse
import pathlib
import re
import sys

REQUIRED_PATTERNS = [
    (r"Qiskit Connector Real-QPU-First Execution and Simulator Fallback", "required design section title"),
    (r"(?i)QConnectorV2.{0,100}(connector|import)|(?:connector|import).{0,100}QConnectorV2", "textual QConnectorV2-as-connector instruction"),
    (r"(?i)QPlanV2.{0,100}(plan|import)|(?:plan|import).{0,100}QPlanV2", "textual QPlanV2-as-plan instruction"),
    (r"current\s*=\s*plan\s*\(\s*\)", "textual current = plan() instruction"),
    (r"backend\s*=\s*connector\s*\(\s*\)", "textual backend = connector() instruction"),
    (r"(?i)real[- ]?(qpu|quantum backend).{0,180}(first|before)|(?:first|before).{0,180}real[- ]?(qpu|quantum backend)", "real-QPU-first instruction"),
    (r"(?i)(operational|availability|available).{0,180}(qubit|capacity)|(?:qubit|capacity).{0,180}(operational|availability|available)", "QPU availability/capacity instruction"),
    (r"(?i)try\s*/?\s*except|try.{0,120}except", "try/except fallback instruction"),
    (r"(?i)AerSimulator", "AerSimulator fallback instruction"),
    (r"(?i)simulator[- ]first.{0,100}(prohibited|not allowed|forbidden)", "simulator-first prohibition"),
    (r"(?i)(execution target|EXECUTION_TARGET).{0,120}(REAL_QPU|real QPU)", "REAL_QPU reporting instruction"),
    (r"(?i)(execution target|EXECUTION_TARGET).{0,120}SIMULATOR", "SIMULATOR reporting instruction"),
]

PYTHON_FENCE = re.compile(r"```\s*(python|py)\b.*?```", re.I | re.S)
EXECUTABLE_BLOCK_HINT = re.compile(
    r"(?s)```[^\n]*\n.*?(?:from\s+qiskit_connector\s+import|current\s*=\s*plan\s*\(|backend\s*=\s*connector\s*\(|try\s*:).*?```",
    re.I,
)


def validate(path: pathlib.Path) -> list[str]:
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as exc:
        return [f"cannot read design file: {exc}"]
    problems = []
    if PYTHON_FENCE.search(text) or EXECUTABLE_BLOCK_HINT.search(text):
        problems.append("design contains an executable/fenced Python implementation; use textual instructions only")
    for pattern, label in REQUIRED_PATTERNS:
        if not re.search(pattern, text, re.S):
            problems.append(f"missing {label}")
    return problems


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("paths", nargs="+")
    args = p.parse_args()
    failed = False
    for raw in args.paths:
        path = pathlib.Path(raw)
        problems = validate(path)
        if problems:
            failed = True
            print(f"BQCA_QISKIT_DESIGN_POLICY=FAIL file={path}")
            for problem in problems:
                print(f"  - {problem}")
        else:
            print(f"BQCA_QISKIT_DESIGN_POLICY=PASS file={path}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
