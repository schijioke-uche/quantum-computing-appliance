#!/usr/bin/env python3
"""BQCA v48 result-output contract validator."""
from __future__ import annotations

import argparse
import pathlib
import re


def validate_code(path: pathlib.Path) -> list[str]:
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as exc:
        return [f"cannot read code: {exc}"]
    if "qiskit" not in text.lower():
        return []
    requirements = (
        "BQCA_EXECUTION_TARGET=REAL_QPU",
        "BQCA_EXECUTION_TARGET=SIMULATOR",
        "BQCA_PLAN=",
        "BQCA_BACKEND=",
        "BQCA_JOB_ID=",
        "BQCA_RESULT=SUCCESS",
        "BQCA_RESULT=FAILURE",
        "BQCA_FALLBACK_REASON=",
    )
    problems = [f"missing canonical runtime marker: {value}" for value in requirements if value not in text]
    if "bqca-direct-execution.sh" not in text:
        problems.append("missing direct-execution wrapper contract")
    return problems


def validate_design(path: pathlib.Path) -> list[str]:
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as exc:
        return [f"cannot read design: {exc}"]
    requirements = (
        (r"(?i)<source-stem>-result-output\.txt|<code-name>-result-output\.txt", "canonical result filename"),
        (r"(?i)output\.txt", "output.txt mirror"),
        (r"(?is)(?:stdout|standard output).{0,100}(?:stderr|standard error)", "combined stdout/stderr capture"),
        (r"(?i)date.{0,30}time|timestamp", "date/time requirement"),
        (r"(?i)duration", "duration requirement"),
        (r"(?i)exit status", "exit-status requirement"),
        (r"(?i)RESULT SUMMARY", "RESULT SUMMARY requirement"),
        (r"(?is)(?:first line|line one).{0,100}JOB ID|JOB ID.{0,100}(?:first line|line one)", "real-QPU Job ID line-one rule"),
        (r"(?i)BQCA_RESULT\s*=\s*SUCCESS", "BQCA_RESULT=SUCCESS marker"),
        (r"(?i)BQCA_RESULT\s*=\s*FAILURE", "BQCA_RESULT=FAILURE marker"),
    )
    return [f"missing {label}" for pattern, label in requirements if not re.search(pattern, text)]


def field(text: str, name: str) -> str:
    match = re.search(rf"(?m)^{re.escape(name)}\s*:\s*(.+?)\s*$", text)
    return match.group(1).strip() if match else ""


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

    required_values = (
        "BQCA v48 DIRECT QUANTUM EXECUTION RESULT OUTPUT",
        "Execution successful",
        "Result contract valid",
        "Execution method        : DIRECT",
        "Execution target",
        "Source artifact",
        "Command",
        "Result output",
        "Output mirror",
        "Started",
        "Completed",
        "Duration seconds",
        "Exit status",
        "Plan",
        "Backend",
        "Job ID",
        "Fallback reason",
        "COMPLETE TERMINAL OUTPUT (STDOUT + STDERR)",
        "RESULT SUMMARY",
        "Process exit status",
        "Completion date/time",
        "Policy/Execution issue(s)",
    )
    for value in required_values:
        if value not in text:
            problems.append(f"missing report section/field: {value}")

    target = field(text, "Final execution target") or field(text, "Execution target")
    if target not in {"REAL_QPU", "SIMULATOR", "UNKNOWN"}:
        problems.append("missing or invalid final execution target")
    if target == "REAL_QPU":
        first_line = text.splitlines()[0] if text.splitlines() else ""
        if not re.fullmatch(r"JOB ID:\s*\S+", first_line) or "NOT REPORTED" in first_line:
            problems.append("real-QPU result must place the actual JOB ID on line one")

    result_markers = re.findall(r"(?m)^BQCA_RESULT=(\S+)\s*$", text)
    if not result_markers:
        problems.append("complete terminal output does not contain BQCA_RESULT")
    elif any(value.upper() not in {"SUCCESS", "FAILURE"} for value in result_markers):
        problems.append("BQCA_RESULT must be SUCCESS or FAILURE")

    mirror = field(text, "Output mirror") or field(text, "Compatibility output")
    if not mirror.endswith("output.txt"):
        problems.append("missing same-directory output.txt mirror")
    return problems


def main() -> int:
    parser = argparse.ArgumentParser(description="BQCA v48 result-output validator")
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

        label = f"BQCA_RESULT_OUTPUT_POLICY_V48_{args.kind.upper()}"
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
