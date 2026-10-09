#!/usr/bin/env python3
"""BQCA v41 request-scoped Hello World validator."""
from __future__ import annotations

import argparse
import ast
import pathlib
import re
import sys

HELLO_VARIANT = re.compile(
    r"(?i)(?:\bhello[\s_-]*world\b|\bhellow[\s_-]*world\b)"
)
HELLO_ARTIFACT = re.compile(
    r"(?i)(?:"
    r"bob-quantum-store[/\\]test|"
    r"hello[-_]?world\.(?:py|ipynb)|"
    r"hellow[-_]?world\.(?:py|ipynb)|"
    r"run\s+(?:qiskit\s+)?hello[\s_-]*world|"
    r"hello[\s_-]*world\s+(?:test|testing|smoke\s*test|artifact|example|requirement)"
    r")"
)


def normalized(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", value.lower())


def filename_is_hello_world(path: pathlib.Path) -> bool:
    name = normalized(path.stem)
    return "helloworld" in name or "hellowworld" in name


def first_heading_is_hello_world(text: str) -> bool:
    for raw in text.splitlines():
        line = raw.strip()
        if not line:
            continue
        if line.startswith("#"):
            return bool(HELLO_VARIANT.search(line.lstrip("#").strip()))
        break
    return False


def module_docstring_is_hello_world(text: str) -> bool:
    try:
        tree = ast.parse(text)
    except SyntaxError:
        return False
    doc = ast.get_docstring(tree, clean=False) or ""
    return bool(HELLO_VARIANT.search(doc))


def explicit_hello_world(path: pathlib.Path, text: str, kind: str) -> bool:
    if filename_is_hello_world(path):
        return True
    if kind == "design":
        return first_heading_is_hello_world(text)
    if kind == "code":
        return module_docstring_is_hello_world(text)
    return first_heading_is_hello_world(text) or module_docstring_is_hello_world(text)


def hello_references(text: str) -> list[str]:
    findings: list[str] = []
    for pattern, label in (
        (HELLO_VARIANT, "Hello World wording"),
        (HELLO_ARTIFACT, "Hello World test/artifact/path requirement"),
    ):
        if pattern.search(text):
            findings.append(label)
    return findings


def validate(path: pathlib.Path, kind: str) -> list[str]:
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as exc:
        return [f"cannot read artifact: {exc}"]

    actual_kind = kind
    if actual_kind == "auto":
        actual_kind = "code" if path.suffix.lower() == ".py" else "design"

    if explicit_hello_world(path, text, actual_kind):
        return []

    findings = hello_references(text)
    if not findings:
        return []

    return [
        "non-Hello-World artifact contains prohibited Hello World content: "
        + ", ".join(sorted(set(findings))),
        "remove the Hello World section/test/path or explicitly name/title the artifact as a Hello World request",
    ]


def main() -> int:
    parser = argparse.ArgumentParser(
        description="BQCA v41 Hello World request-scope validator"
    )
    parser.add_argument("--kind", choices=("auto", "design", "code"), default="auto")
    parser.add_argument("paths", nargs="+")
    args = parser.parse_args()

    failed = False
    for raw in args.paths:
        path = pathlib.Path(raw)
        problems = validate(path, args.kind)
        if problems:
            failed = True
            print(f"BQCA_HELLO_WORLD_SCOPE_V41=FAIL kind={args.kind} file={path}")
            for problem in problems:
                print(f"  - {problem}")
        else:
            print(f"BQCA_HELLO_WORLD_SCOPE_V41=PASS kind={args.kind} file={path}")

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

# BQCA-QISKIT-EXECUTION-v39-update-1:POLICY-BEGIN
# V39 UPDATE 1: Quantum/Qiskit code intent is immediate. Qiskit checks,
# uninstalls, upgrades, and installs are permitted only inside qiskit-v2x-env.
# System/global Python, pip, and user-site Qiskit are prohibited. Qiskit 2.5+
# is required. Open Plan uses SamplerV2(mode=backend) without Session; paid
# plans use Session with SamplerV2/EstimatorV2; simulator fallback uses
# transpile + AerSimulator. backend.run() is local-simulator-only. Hello World
# artifacts are discovered under bob-quantum-store/test.
# BQCA-QISKIT-EXECUTION-v39-update-1:POLICY-END
