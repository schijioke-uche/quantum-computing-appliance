#!/usr/bin/env python3
"""BQCA v47 direct/formal result-output contract validator."""
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
    (r"(?i)(?:<name of code>|<code-name>|source|workload).{0,80}-result-output\.txt", "canonical result filename"),
    (r"(?i)output\.txt", "output.txt compatibility mirror"),
    (r"(?i)same directory", "same-directory requirement"),
    (r"(?is)(?:stdout|standard output).{0,120}(?:stderr|standard error)|combined.{0,120}(?:stdout|stderr)", "combined stdout/stderr capture"),
    (r"(?i)(?:live|real[- ]time).{0,100}(?:terminal|output)|terminal.{0,100}(?:live|real[- ]time)", "live terminal visibility"),
    (r"(?i)Qiskit Connector", "Qiskit Connector output capture"),
    (r"(?i)date.{0,30}time|timestamp", "date/time requirement"),
    (r"(?is)bottom.{0,100}(?:summary|result summary)|result summary.{0,100}bottom", "summary-at-bottom requirement"),
    (r"(?i)execution (?:was )?successful|execution successful", "execution-success summary"),
    (r"(?is)real[- ]QPU.{0,160}JOB ID|JOB ID.{0,160}real[- ]QPU", "real-QPU Job ID requirement"),
    (r"(?is)JOB ID.{0,100}(?:top|first line)|(?:top|first line).{0,100}JOB ID", "Job ID first-line requirement"),
    (r"(?i)bqca-direct-execution\.sh|qiskit-result-output\.sh|qiskit-v2x-environment\.sh\s+(?:run|run-notebook)", "runtime capture-tool requirement"),
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
    if not re.search(r"(?i)bqca-direct-execution|qiskit-v2x-environment\.sh\s+run|qiskit-result-output", text):
        problems.append("missing governed result-capture execution contract marker")
    return problems


def validate_design(path: pathlib.Path) -> list[str]:
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as exc:
        return [f"cannot read design: {exc}"]
    return [f"missing {label}" for pattern, label in DESIGN_REQUIREMENTS if not re.search(pattern, text)]


def field(text: str, label: str) -> str | None:
    match = re.search(rf"(?m)^\s*{re.escape(label)}\s*:\s*(.*?)\s*$", text)
    return match.group(1) if match else None


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

    required_patterns = (
        (r"BQCA\s+v\d+(?:[-.\w]*)?\s+DIRECT QUANTUM EXECUTION RESULT OUTPUT|BQCA QUANTUM EXECUTION RESULT OUTPUT", "execution report title"),
        (r"COMPLETE TERMINAL OUTPUT \(STDOUT \+ STDERR\)|COMPLETE COMBINED EXECUTION OUTPUT", "complete terminal-output section"),
        (r"RESULT SUMMARY", "RESULT SUMMARY section"),
        (r"Execution successful\s*:\s*(?:YES|NO)", "execution-success field"),
        (r"Result contract valid\s*:\s*(?:YES|NO)", "result-contract field"),
        (r"Started\s*:\s*\S+", "start timestamp"),
        (r"Completed\s*:\s*\S+", "completion timestamp"),
        (r"Duration seconds\s*:\s*\d+", "duration"),
        (r"Final execution target\s*:\s*(?:REAL_QPU|SIMULATOR|UNKNOWN)", "final execution target"),
        (r"Execution method\s*:\s*(?:DIRECT|FORMAL)", "execution method"),
        (r"Compatibility output\s*:\s*.+output\.txt", "output.txt compatibility path"),
        (r"Policy/Execution issue\(s\)\s*:\s*.+", "policy/execution issue summary"),
    )
    for pattern, label in required_patterns:
        if not re.search(pattern, text, re.I | re.M):
            problems.append(f"missing {label}")

    target = field(text, "Final execution target")
    if target == "REAL_QPU":
        first_line = text.splitlines()[0] if text.splitlines() else ""
        if not re.fullmatch(r"JOB ID:\s*\S+", first_line) or "NOT REPORTED" in first_line:
            problems.append("real-QPU result must place the actual Job ID on the first line")
    return problems


def main() -> int:
    parser = argparse.ArgumentParser(description="BQCA v47 result-output policy validator")
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

        label = f"BQCA_RESULT_OUTPUT_POLICY_V47_{args.kind.upper()}"
        if problems:
            failed = True
            print(f"{label}=FAIL file={path}")
            for problem in problems:
                print(f"  - {problem}")
        else:
            print(f"{label}=PASS file={path}")
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
