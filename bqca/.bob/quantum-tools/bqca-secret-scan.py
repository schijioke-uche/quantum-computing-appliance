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
