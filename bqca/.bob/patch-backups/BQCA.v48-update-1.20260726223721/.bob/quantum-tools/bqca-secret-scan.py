#!/usr/bin/env python3
"""BQCA v48 credential-leak scanner.

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
    parser = argparse.ArgumentParser(description="BQCA v48 secret scanner")
    parser.add_argument("--use-env", action="store_true")
    parser.add_argument("paths", nargs="+")
    args = parser.parse_args()
    failed = False
    for raw in args.paths:
        path = pathlib.Path(raw)
        problems = validate(path, args.use_env)
        if problems:
            failed = True
            print(f"BQCA_SECRET_SCAN_V48=FAIL file={path}")
            for problem in problems:
                print(f"  - {problem}")
        else:
            print(f"BQCA_SECRET_SCAN_V48=PASS file={path}")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())

# BQCA-CANONICAL-PRODUCTION-POLICY-v48:BEGIN
# Use .bob/BQCA-PRODUCTION-POLICY.md as the sole active BQCA v48 authority.
# Direct synchronous execution is the default; formal orchestration is explicit
# opt-in. Preserve the Qiskit configuration/home-environment/2.5+ gates,
# plan-aware Runtime V2 execution, real-QPU-first fallback order, synchronized
# notebooks, scoped Hello World behavior, live dual-result capture, Job-ID-first
# real-QPU reports, and secret protection. Quantum DESIGN and CODE work consults
# bqca-quantum-kb.sh and the offline v48 catalog. v48 incorporates core v47 and
# Updates 1-6; Update 6 supersedes Update 5 URL crawling.
# BQCA-CANONICAL-PRODUCTION-POLICY-v48:END
