#!/usr/bin/env python3
"""BQCA v42 governed quantum execution result capture."""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import pathlib
import re
import shlex
import subprocess
import sys
import time
from typing import Iterable

LINE = "=" * 88
SUBLINE = "-" * 88


def timestamp() -> str:
    return dt.datetime.now().astimezone().isoformat(timespec="seconds")


def source_digest(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def last_value(patterns: Iterable[str], text: str) -> str:
    values: list[str] = []
    for pattern in patterns:
        values.extend(re.findall(pattern, text, flags=re.I | re.M))
    return values[-1].strip() if values else ""


def detect_target(text: str) -> str:
    values = re.findall(
        r"(?:BQCA_)?EXECUTION_TARGET\s*[:=]\s*(REAL_QPU|SIMULATOR)",
        text,
        flags=re.I,
    )
    if values:
        return values[-1].upper()
    if re.search(r"\busing\s+(?:a\s+)?real\s+qpu\b|\breal[-_ ]qpu\s+execution\b", text, re.I):
        return "REAL_QPU"
    if re.search(r"\busing\s+(?:the\s+)?simulator\b|\bsimulator\s+fallback\b", text, re.I):
        return "SIMULATOR"
    return "UNKNOWN"


def parse_metadata(text: str) -> dict[str, str]:
    return {
        "target": detect_target(text),
        "job_id": last_value(
            (
                r"BQCA_JOB_ID\s*[:=]\s*([^\s]+)",
                r"\bJOB[ _-]?ID\s*[:=]\s*([^\s]+)",
                r"\bjob_id\s*[:=]\s*([^\s]+)",
            ),
            text,
        ),
        "plan": last_value((r"BQCA_PLAN\s*[:=]\s*([^\r\n]+)", r"\bPLAN\s*[:=]\s*([^\r\n]+)"), text),
        "backend": last_value(
            (r"BQCA_BACKEND\s*[:=]\s*([^\r\n]+)", r"\bBACKEND\s*[:=]\s*([^\r\n]+)"),
            text,
        ),
        "fallback": last_value(
            (r"BQCA_FALLBACK_REASON\s*[:=]\s*([^\r\n]+)", r"\bFALLBACK_REASON\s*[:=]\s*([^\r\n]+)"),
            text,
        ),
    }


def notebook_outputs(path: pathlib.Path) -> str:
    if path.suffix.lower() != ".ipynb" or not path.is_file():
        return ""
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        return f"[BQCA] Unable to extract notebook cell outputs: {exc}\n"

    lines: list[str] = []
    for index, cell in enumerate(data.get("cells", []), start=1):
        if cell.get("cell_type") != "code":
            continue
        outputs = cell.get("outputs", [])
        if not outputs:
            continue
        lines.append(f"[Notebook code cell {index} outputs]")
        for output in outputs:
            output_type = output.get("output_type")
            if output_type == "stream":
                value = output.get("text", "")
                lines.extend(value if isinstance(value, list) else [str(value)])
            elif output_type in {"execute_result", "display_data"}:
                value = output.get("data", {}).get("text/plain", "")
                lines.extend(value if isinstance(value, list) else [str(value)])
            elif output_type == "error":
                traceback = output.get("traceback", [])
                lines.extend(str(item) for item in traceback)
        if lines and not lines[-1].endswith("\n"):
            lines.append("\n")
    return "".join(lines)


def field(label: str, value: object) -> str:
    return f"{label:<24}: {value}\n"


def write_report(
    *,
    source: pathlib.Path,
    result_path: pathlib.Path,
    command: list[str],
    raw_output: str,
    return_code: int,
    started_at: str,
    completed_at: str,
    duration: float,
    spawn_error: str,
) -> tuple[bool, list[str]]:
    metadata = parse_metadata(raw_output)
    target = metadata["target"]
    job_id = metadata["job_id"]
    violations: list[str] = []

    if target == "UNKNOWN":
        violations.append("final execution target was not reported as REAL_QPU or SIMULATOR")
    if target == "REAL_QPU" and not job_id:
        violations.append("real-QPU execution did not report BQCA_JOB_ID/JOB ID")
    if spawn_error:
        violations.append(f"execution command could not start: {spawn_error}")

    successful = return_code == 0 and not violations
    policy_compliant = not violations
    status = "SUCCESS" if successful else "FAILED"
    command_text = " ".join(shlex.quote(item) for item in command)

    lines: list[str] = []
    if target == "REAL_QPU":
        lines.append(f"JOB ID: {job_id or 'NOT REPORTED - POLICY VIOLATION'}\n")
    lines.extend(
        [
            LINE + "\n",
            "BQCA QUANTUM EXECUTION RESULT OUTPUT\n",
            LINE + "\n",
            field("Execution status", status),
            field("Policy compliant", "YES" if policy_compliant else "NO"),
            field("Execution target", target),
            field("Source artifact", source),
            field("Result output", result_path),
            field("Started", started_at),
            field("Completed", completed_at),
            field("Duration seconds", f"{duration:.3f}"),
            field("Exit status", return_code),
            field("Plan", metadata["plan"] or "NOT REPORTED"),
            field("Backend", metadata["backend"] or "NOT REPORTED"),
            field("Job ID", job_id or "NOT APPLICABLE/NOT REPORTED"),
            field("Fallback reason", metadata["fallback"] or "NONE REPORTED"),
            field("Source SHA-256", source_digest(source)),
            field("Working directory", pathlib.Path.cwd()),
            field("Executed command", command_text),
            LINE + "\n",
            "COMPLETE COMBINED EXECUTION OUTPUT (STDOUT + STDERR)\n",
            SUBLINE + "\n",
        ]
    )

    if raw_output:
        lines.append(raw_output)
        if not raw_output.endswith("\n"):
            lines.append("\n")
    else:
        lines.append("[No stdout or stderr was produced by the workload.]\n")

    lines.extend([SUBLINE + "\n", "RESULT SUMMARY\n", SUBLINE + "\n"])
    lines.extend(
        [
            field("Execution successful", "YES" if successful else "NO"),
            field("Result contract valid", "YES" if policy_compliant else "NO"),
            field("Final execution target", target),
            field("Real-QPU job ID", job_id or "N/A"),
            field("Backend", metadata["backend"] or "NOT REPORTED"),
            field("Plan", metadata["plan"] or "NOT REPORTED"),
            field("Process exit status", return_code),
            field("Completion date/time", completed_at),
            field("Total duration", f"{duration:.3f} seconds"),
            field("Source artifact", source),
            field("Result output", result_path),
        ]
    )
    if violations:
        lines.append("Policy/Execution issue(s):\n")
        lines.extend(f"  - {item}\n" for item in violations)
    else:
        lines.append("Policy/Execution issue(s): NONE\n")
    lines.append(LINE + "\n")

    result_path.parent.mkdir(parents=True, exist_ok=True)
    temporary = result_path.with_name(f".{result_path.name}.tmp.{os.getpid()}")
    temporary.write_text("".join(lines), encoding="utf-8")
    os.chmod(temporary, 0o644)
    os.replace(temporary, result_path)
    return successful, violations


def main() -> int:
    parser = argparse.ArgumentParser(description="BQCA v42 governed result-output capture")
    parser.add_argument("--source", required=True, type=pathlib.Path)
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()

    source = args.source.expanduser().resolve()
    if not source.is_file() or source.suffix.lower() not in {".py", ".ipynb"}:
        print(f"BQCA_RESULT_OUTPUT_V42=FAIL: invalid source artifact: {source}", file=sys.stderr)
        return 2

    command = list(args.command)
    if command and command[0] == "--":
        command = command[1:]
    if not command:
        print("BQCA_RESULT_OUTPUT_V42=FAIL: execution command is required after --", file=sys.stderr)
        return 2

    result_path = source.with_name(f"{source.stem}-result-output.txt")
    started_at = timestamp()
    started_clock = time.monotonic()
    output_parts: list[str] = []
    return_code = 127
    spawn_error = ""

    try:
        process = subprocess.Popen(
            command,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            encoding="utf-8",
            errors="replace",
            bufsize=1,
        )
        assert process.stdout is not None
        for line in process.stdout:
            sys.stdout.write(line)
            sys.stdout.flush()
            output_parts.append(line)
        return_code = process.wait()
    except OSError as exc:
        spawn_error = str(exc)
        message = f"[BQCA v42] Unable to start execution command: {exc}\n"
        sys.stderr.write(message)
        output_parts.append(message)

    if source.suffix.lower() == ".ipynb":
        extracted = notebook_outputs(source)
        if extracted:
            block = "\n" + SUBLINE + "\nEXTRACTED NOTEBOOK CELL OUTPUTS\n" + SUBLINE + "\n" + extracted
            output_parts.append(block)

    completed_at = timestamp()
    duration = time.monotonic() - started_clock
    raw_output = "".join(output_parts)
    successful, violations = write_report(
        source=source,
        result_path=result_path,
        command=command,
        raw_output=raw_output,
        return_code=return_code,
        started_at=started_at,
        completed_at=completed_at,
        duration=duration,
        spawn_error=spawn_error,
    )

    print(f"BQCA_RESULT_OUTPUT={result_path}")
    print(f"BQCA_EXECUTION_SUCCESSFUL={'YES' if successful else 'NO'}")
    if return_code != 0:
        return return_code if 0 < return_code < 256 else 1
    return 42 if violations else 0


if __name__ == "__main__":
    raise SystemExit(main())

# BQCA-RESULT-OUTPUT-v42:POLICY-BEGIN
# V42: execute quantum/Qiskit sources through qiskit-v2x-environment.sh run or
# run-notebook. The runtime creates <source-stem>-result-output.txt beside the
# source, captures complete Qiskit Connector/stdout/stderr output, includes
# date/time, places a real-QPU JOB ID on the first line, and appends a final
# RESULT SUMMARY with execution success. Code emits canonical BQCA markers.
# BQCA-RESULT-OUTPUT-v42:POLICY-END
