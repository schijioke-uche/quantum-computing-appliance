#!/usr/bin/env python3
"""BQCA v44 credential-leak scanner.

The scanner never reads .env. It checks supplied artifacts for known secret
variable assignments, bearer/token syntax, private keys, and currently exported
secret values without printing any secret material.
"""
from __future__ import annotations

import argparse
import os
import pathlib
import re
import sys

SECRET_NAMES = (
    "IQP_API_TOKEN",
    "BOB_API_KEY",
    "IBM_QUANTUM_TOKEN",
    "QISKIT_IBM_TOKEN",
    "API_KEY",
    "ACCESS_TOKEN",
)
PATTERNS = (
    (re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----"), "private key material"),
    (re.compile(r"(?i)\b(?:bearer|token)\s+[A-Za-z0-9._~+/=-]{24,}"), "bearer/token value"),
    (re.compile(r"(?i)\b(?:IQP_API_TOKEN|BOB_API_KEY|IBM_QUANTUM_TOKEN|QISKIT_IBM_TOKEN)\s*[:=]\s*['\"]?[A-Za-z0-9._~+/=-]{12,}"), "named credential assignment"),
)


def validate(path: pathlib.Path, use_env: bool) -> list[str]:
    try:
        data = path.read_text(encoding="utf-8", errors="replace")
    except OSError as exc:
        return [f"cannot read artifact: {exc}"]
    problems: list[str] = []
    for pattern, label in PATTERNS:
        if pattern.search(data):
            problems.append(label)
    if use_env:
        for name in SECRET_NAMES:
            value = os.environ.get(name, "")
            if len(value) >= 8 and value in data:
                problems.append(f"exported secret value from {name}")
    return sorted(set(problems))


def main() -> int:
    parser = argparse.ArgumentParser(description="BQCA v44 secret scanner")
    parser.add_argument("--use-env", action="store_true")
    parser.add_argument("paths", nargs="+")
    args = parser.parse_args()
    failed = False
    for raw in args.paths:
        path = pathlib.Path(raw)
        problems = validate(path, args.use_env)
        if problems:
            failed = True
            print(f"BQCA_SECRET_SCAN_V44=FAIL file={path}")
            for problem in problems:
                print(f"  - {problem}")
        else:
            print(f"BQCA_SECRET_SCAN_V44=PASS file={path}")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
# BQCA-CANONICAL-PRODUCTION-POLICY-v47:BEGIN
# The sole active policy is .bob/BQCA-PRODUCTION-POLICY.md (v47).
# Direct execution streams complete stdout/stderr live and writes the exact
# professional report to <source-stem>-result-output.txt and output.txt.
# REAL_QPU results put the actual Job ID on line one. Direct contract gaps
# are warnings; formal orchestration is explicit opt-in.
# BQCA-CANONICAL-PRODUCTION-POLICY-v47:END
