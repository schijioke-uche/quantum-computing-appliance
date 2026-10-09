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

# BQCA-LOCAL-ALGORITHM-KNOWLEDGEBASE-v47-update-6:BEGIN
# For every quantum DESIGN or CODE intent, consult bqca-quantum-kb.sh and the
# offline bqca_quantum_algorithm_catalog.json for Qiskit 2.5+ algorithm,
# Open/Paid plan, simulator-fallback, design-card, and scaffold guidance.
# Update 6 supersedes Update 5 URL crawling and sublink drilldown. No network
# access or mandatory research trace is required. The catalog supplements IBM
# Bob intelligence and never overrides the active central policy. If no local
# entry fits, use approved research and continue rather than blocking the task.
# BQCA-LOCAL-ALGORITHM-KNOWLEDGEBASE-v47-update-6:END
