#!/usr/bin/env python3
"""Reject project-local qiskit-v2x-env management in generated Python code."""
from __future__ import annotations

import argparse
import ast
import pathlib
import re
import sys

ALLOWED_REFERENCES = (
    "~/qiskit-v2x-env",
    "$HOME/qiskit-v2x-env",
    "${HOME}/qiskit-v2x-env",
    "qiskit-v2x-environment.sh",
)

FORBIDDEN_TEXT = [
    re.compile(r"(?i)python3\s+-m\s+venv\s+(?:\./)?qiskit-v2x-env(?:\s|$)"),
    re.compile(r"(?i)(?:BQCA_ROOT|PROJECT_ROOT|SCRIPT_DIR)[^\n]{0,120}qiskit-v2x-env"),
    re.compile(r"(?i)quantum-computing-agent[/\\]qiskit-v2x-env"),
]


def string_problem(value: str) -> str | None:
    if "qiskit-v2x-env" not in value:
        return None
    if any(item in value for item in ALLOWED_REFERENCES):
        return None
    normalized = value.strip().replace("\\", "/")
    if normalized in {"qiskit-v2x-env", "./qiskit-v2x-env"}:
        return "relative/project-local qiskit-v2x-env reference"
    if "/qiskit-v2x-env" in normalized and not normalized.startswith("/home/"):
        return "non-home qiskit-v2x-env reference"
    return None


def validate(path: pathlib.Path) -> list[str]:
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as exc:
        return [f"cannot read file: {exc}"]

    problems: list[str] = []
    for pattern in FORBIDDEN_TEXT:
        if pattern.search(text):
            problems.append(f"forbidden project-local environment pattern: {pattern.pattern}")

    try:
        tree = ast.parse(text, filename=str(path))
    except SyntaxError as exc:
        problems.append(f"invalid Python syntax: {exc}")
        return problems

    for node in ast.walk(tree):
        if isinstance(node, ast.Constant) and isinstance(node.value, str):
            problem = string_problem(node.value)
            if problem:
                problems.append(f"line {getattr(node, 'lineno', '?')}: {problem}")

    return sorted(set(problems))


def main() -> int:
    parser = argparse.ArgumentParser(description="BQCA v40 home environment code validator")
    parser.add_argument("paths", nargs="+")
    args = parser.parse_args()
    failed = False

    for raw in args.paths:
        path = pathlib.Path(raw)
        problems = validate(path)
        if problems:
            failed = True
            print(f"BQCA_QISKIT_HOME_ENV_V40=FAIL file={path}")
            for problem in problems:
                print(f"  - {problem}")
        else:
            print(f"BQCA_QISKIT_HOME_ENV_V40=PASS file={path}")

    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())

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
