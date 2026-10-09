#!/usr/bin/env python3
"""BQCA v33 strict Qiskit Connector design-policy validator."""
from __future__ import annotations
import argparse
import pathlib
import re
import sys

REQUIRED_PATTERNS = [
    (r"Qiskit Connector Real-QPU-First Execution and Simulator Fallback", "required design section title"),
    (r"from\s+qiskit_connector\s+import\s+QConnectorV2\s+as\s+connector", "QConnectorV2 import"),
    (r"from\s+qiskit_connector\s+import\s+QPlanV2\s+as\s+plan", "QPlanV2 import"),
    (r"current\s*=\s*plan\s*\(\s*\)", "current = plan()"),
    (r"backend\s*=\s*connector\s*\(\s*\)", "backend = connector()"),
    (r"(?i)real[- ]?(qpu|quantum backend).{0,120}(first|before)", "real-QPU-first statement"),
    (r"(?i)(operational|availability|available).{0,160}(qubit|capacity)|(?:qubit|capacity).{0,160}(operational|availability|available)", "QPU availability/capacity check"),
    (r"(?i)try\s*/?\s*except|try.{0,120}except", "try/except fallback"),
    (r"(?i)AerSimulator", "AerSimulator fallback"),
    (r"(?i)simulator[- ]first.{0,80}(prohibited|not allowed|forbidden)", "simulator-first prohibition"),
    (r"(?i)EXECUTION_TARGET.{0,80}REAL_QPU", "REAL_QPU reporting"),
    (r"(?i)EXECUTION_TARGET.{0,80}SIMULATOR", "SIMULATOR reporting"),
]


def validate(path: pathlib.Path) -> list[str]:
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as exc:
        return [f"cannot read design file: {exc}"]
    problems = []
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
