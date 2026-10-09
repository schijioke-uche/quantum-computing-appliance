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

# BQCA-HELLO-WORLD-SCOPE-v41:POLICY-BEGIN
# V41: Hello World is request-scoped, not a universal design/code test. Do not
# add, mention, execute, validate, or require Hello World content in unrelated
# designs or code. Only an explicit Hello World request may use the existing
# bob-quantum-store/test shortcut, and the artifact must be named/titled as
# Hello World. Preserve all v38-v40 Qiskit configuration and execution rules.
# BQCA-HELLO-WORLD-SCOPE-v41:POLICY-END

# BQCA-RESULT-OUTPUT-v42:POLICY-BEGIN
# V42: execute quantum/Qiskit sources through qiskit-v2x-environment.sh run or
# run-notebook. The runtime creates <source-stem>-result-output.txt beside the
# source, captures complete Qiskit Connector/stdout/stderr output, includes
# date/time, places a real-QPU JOB ID on the first line, and appends a final
# RESULT SUMMARY with execution success. Code emits canonical BQCA markers.
# BQCA-RESULT-OUTPUT-v42:POLICY-END
