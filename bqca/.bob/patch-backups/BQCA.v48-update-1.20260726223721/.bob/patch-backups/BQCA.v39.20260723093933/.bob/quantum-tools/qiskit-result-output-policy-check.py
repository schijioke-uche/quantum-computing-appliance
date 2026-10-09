#!/usr/bin/env python3
"""BQCA v42 result-output contract validator for code, designs, and reports."""
from __future__ import annotations

import argparse
import ast
import pathlib
import re
import sys

CODE_MARKERS = (
    "BQCA_EXECUTION_TARGET=REAL_QPU",
    "BQCA_EXECUTION_TARGET=SIMULATOR",
    "BQCA_JOB_ID=",
    "BQCA_PLAN=",
    "BQCA_BACKEND=",
    "BQCA_RESULT=",
)

DESIGN_REQUIREMENTS = (
    (r"(?i)(?:<name of code>|<code-name>|source|workload).{0,80}-result-output\.txt", "canonical <code-name>-result-output.txt filename"),
    (r"(?i)same directory", "same-directory requirement"),
    (r"(?is)complete.{0,100}(?:stdout|standard output|execution output)", "complete execution-output capture"),
    (r"(?is)(?:stderr|standard error).{0,120}(?:capture|combined|output)|combined.{0,120}stderr", "stderr capture"),
    (r"(?i)Qiskit Connector", "Qiskit Connector output capture"),
    (r"(?i)date.{0,30}time|timestamp", "result date/time requirement"),
    (r"(?is)bottom.{0,100}(?:summary|result summary)|result summary.{0,100}bottom", "summary-at-bottom requirement"),
    (r"(?i)execution (?:was )?successful|execution successful", "execution-success summary"),
    (r"(?is)real[- ]QPU.{0,160}JOB ID|JOB ID.{0,160}real[- ]QPU", "real-QPU JOB ID requirement"),
    (r"(?is)JOB ID.{0,100}(?:top|first line)|(?:top|first line).{0,100}JOB ID", "JOB ID at top requirement"),
    (r"(?i)qiskit-result-output\.sh|qiskit-v2x-environment\.sh\s+(?:run|run-notebook)", "runtime capture-tool requirement"),
)


def strings_in(tree: ast.AST) -> str:
    return "\n".join(
        node.value for node in ast.walk(tree)
        if isinstance(node, ast.Constant) and isinstance(node.value, str)
    )


def has_job_id_call(tree: ast.AST) -> bool:
    return any(
        isinstance(node, ast.Call)
        and isinstance(node.func, ast.Attribute)
        and node.func.attr == "job_id"
        for node in ast.walk(tree)
    )


def validate_code(path: pathlib.Path) -> list[str]:
    try:
        text = path.read_text(encoding="utf-8")
        tree = ast.parse(text, filename=str(path))
    except (OSError, UnicodeError, SyntaxError) as exc:
        return [f"cannot parse code: {exc}"]

    imported_qiskit = any(
        (isinstance(node, ast.Import) and any(alias.name.startswith("qiskit") for alias in node.names))
        or (isinstance(node, ast.ImportFrom) and (node.module or "").startswith("qiskit"))
        for node in ast.walk(tree)
    )
    if not imported_qiskit:
        return []

    problems: list[str] = []
    joined = strings_in(tree)
    for marker in CODE_MARKERS:
        if marker not in joined and marker not in text:
            problems.append(f"missing canonical runtime marker: {marker}")
    if not has_job_id_call(tree):
        problems.append("real-QPU branch must call job.job_id() and print BQCA_JOB_ID=<id>")
    if not re.search(r"(?i)qiskit-v2x-environment\.sh\s+run|qiskit-result-output", text):
        problems.append("missing v42 result-capture execution contract marker")
    return problems


def validate_design(path: pathlib.Path) -> list[str]:
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as exc:
        return [f"cannot read design: {exc}"]
    problems: list[str] = []
    for pattern, label in DESIGN_REQUIREMENTS:
        if not re.search(pattern, text):
            problems.append(f"missing {label}")
    return problems


def validate_result(path: pathlib.Path, source: pathlib.Path | None) -> list[str]:
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as exc:
        return [f"cannot read result output: {exc}"]

    problems: list[str] = []
    if source is not None:
        expected = source.with_name(f"{source.stem}-result-output.txt").resolve()
        if path.resolve() != expected:
            problems.append(f"result filename/location must be {expected}")
    required = (
        "BQCA QUANTUM EXECUTION RESULT OUTPUT",
        "COMPLETE COMBINED EXECUTION OUTPUT",
        "RESULT SUMMARY",
        "Execution successful",
        "Completion date/time",
        "Execution target",
    )
    for value in required:
        if value not in text:
            problems.append(f"missing report section/field: {value}")

    target_match = re.search(r"Final execution target\s*:\s*(REAL_QPU|SIMULATOR|UNKNOWN)", text)
    if not target_match:
        problems.append("missing final execution target in summary")
    elif target_match.group(1) == "REAL_QPU":
        first_line = text.splitlines()[0] if text.splitlines() else ""
        if not re.match(r"JOB ID:\s*\S+", first_line) or "NOT REPORTED" in first_line:
            problems.append("real-QPU result must place the actual JOB ID on the first line")
    return problems


def main() -> int:
    parser = argparse.ArgumentParser(description="BQCA v42 result-output policy validator")
    parser.add_argument("--kind", choices=("code", "design", "result"), required=True)
    parser.add_argument("--source", type=pathlib.Path)
    parser.add_argument("paths", nargs="+")
    args = parser.parse_args()

    failed = False
    for raw in args.paths:
        path = pathlib.Path(raw)
        if args.kind == "code":
            problems = validate_code(path)
        elif args.kind == "design":
            problems = validate_design(path)
        else:
            problems = validate_result(path, args.source)

        label = f"BQCA_RESULT_OUTPUT_POLICY_V42_{args.kind.upper()}"
        if problems:
            failed = True
            print(f"{label}=FAIL file={path}")
            for problem in problems:
                print(f"  - {problem}")
        else:
            print(f"{label}=PASS file={path}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())

# BQCA-RESULT-OUTPUT-v42:POLICY-BEGIN
# V42: execute quantum/Qiskit sources through qiskit-v2x-environment.sh run or
# run-notebook. The runtime creates <source-stem>-result-output.txt beside the
# source, captures complete Qiskit Connector/stdout/stderr output, includes
# date/time, places a real-QPU JOB ID on the first line, and appends a final
# RESULT SUMMARY with execution success. Code emits canonical BQCA markers.
# BQCA-RESULT-OUTPUT-v42:POLICY-END
