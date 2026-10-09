#!/usr/bin/env python3
"""BQCA v47 live terminal mirror and dual governed result capture."""
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
from typing import Iterable, BinaryIO

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
    values = re.findall(r"(?:BQCA_)?EXECUTION_TARGET\s*[:=]\s*(REAL_QPU|SIMULATOR)", text, flags=re.I)
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
        "job_id": last_value((r"BQCA_JOB_ID\s*[:=]\s*([^\s]+)", r"\bJOB[ _-]?ID\s*[:=]\s*([^\s]+)", r"\bjob_id\s*[:=]\s*([^\s]+)"), text),
        "plan": last_value((r"BQCA_PLAN\s*[:=]\s*([^\r\n]+)", r"\bPLAN\s*[:=]\s*([^\r\n]+)"), text),
        "backend": last_value((r"BQCA_BACKEND\s*[:=]\s*([^\r\n]+)", r"\bBACKEND\s*[:=]\s*([^\r\n]+)"), text),
        "fallback": last_value((r"BQCA_FALLBACK_REASON\s*[:=]\s*([^\r\n]+)", r"\bFALLBACK_REASON\s*[:=]\s*([^\r\n]+)"), text),
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
        lines.append(f"[Notebook code cell {index} outputs]\n")
        for output in outputs:
            output_type = output.get("output_type")
            if output_type == "stream":
                value = output.get("text", "")
                lines.extend(value if isinstance(value, list) else [str(value)])
            elif output_type in {"execute_result", "display_data"}:
                value = output.get("data", {}).get("text/plain", "")
                lines.extend(value if isinstance(value, list) else [str(value)])
            elif output_type == "error":
                lines.extend(str(item) + "\n" for item in output.get("traceback", []))
    return "".join(lines)


def field(label: str, value: object) -> str:
    return f"{label:<24}: {value}\n"


def provisional_header(source: pathlib.Path, canonical: pathlib.Path, mirror: pathlib.Path, command: list[str], started: str, method: str) -> bytes:
    text = "".join([
        LINE + "\n",
        "BQCA QUANTUM EXECUTION RESULT OUTPUT - IN PROGRESS\n",
        LINE + "\n",
        field("Source artifact", source),
        field("Result output", canonical),
        field("Compatibility output", mirror),
        field("Execution method", method),
        field("Started", started),
        field("Executed command", " ".join(shlex.quote(item) for item in command)),
        SUBLINE + "\n",
        "LIVE COMBINED EXECUTION OUTPUT (STDOUT + STDERR)\n",
        SUBLINE + "\n",
    ])
    return text.encode("utf-8", errors="replace")


def mirror_chunk(chunk: bytes, transcript: BinaryIO, outputs: list[BinaryIO]) -> None:
    transcript.write(chunk)
    transcript.flush()
    for stream in outputs:
        stream.write(chunk)
        stream.flush()
    try:
        sys.stdout.buffer.write(chunk)
        sys.stdout.buffer.flush()
    except (BrokenPipeError, OSError):
        pass


def run_live(command: list[str], source: pathlib.Path, canonical: pathlib.Path, mirror: pathlib.Path, started_at: str, method: str) -> tuple[int, str, str]:
    raw_path = canonical.with_name(f".{canonical.name}.raw.{os.getpid()}")
    spawn_error = ""
    return_code = 127
    env = os.environ.copy()
    env["PYTHONUNBUFFERED"] = "1"
    header = provisional_header(source, canonical, mirror, command, started_at, method)
    with raw_path.open("wb") as transcript, canonical.open("wb") as primary, mirror.open("wb") as compatibility:
        os.chmod(canonical, 0o644)
        os.chmod(mirror, 0o644)
        primary.write(header)
        compatibility.write(header)
        primary.flush()
        compatibility.flush()
        try:
            process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, bufsize=0, env=env)
            assert process.stdout is not None
            fd = process.stdout.fileno()
            while True:
                chunk = os.read(fd, 8192)
                if not chunk:
                    break
                mirror_chunk(chunk, transcript, [primary, compatibility])
            return_code = process.wait()
        except OSError as exc:
            spawn_error = str(exc)
            chunk = f"[BQCA v47] Unable to start execution command: {exc}\n".encode("utf-8", errors="replace")
            mirror_chunk(chunk, transcript, [primary, compatibility])
    raw = raw_path.read_bytes().decode("utf-8", errors="replace")
    raw_path.unlink(missing_ok=True)
    return return_code, raw, spawn_error


def build_report(*, source: pathlib.Path, canonical: pathlib.Path, mirror: pathlib.Path, command: list[str], raw_output: str,
                 return_code: int, started_at: str, completed_at: str, duration: float, spawn_error: str,
                 method: str) -> tuple[str, bool, bool, list[str]]:
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

    formal = method.upper() == "FORMAL"
    successful = return_code == 0 and (not formal or not violations)
    compliant = not violations
    status = "SUCCESS" if successful else "FAILED"
    command_text = " ".join(shlex.quote(item) for item in command)
    lines: list[str] = []
    if target == "REAL_QPU":
        lines.append(f"JOB ID: {job_id or 'NOT REPORTED - POLICY WARNING'}\n")
    lines.extend([
        LINE + "\n", "BQCA QUANTUM EXECUTION RESULT OUTPUT\n", LINE + "\n",
        field("Execution status", status), field("Policy compliant", "YES" if compliant else "NO"),
        field("Compliance enforcement", "BLOCKING" if formal else "NON-BLOCKING"),
        field("Execution method", method.upper()), field("Execution target", target),
        field("Source artifact", source), field("Result output", canonical), field("Compatibility output", mirror),
        field("Started", started_at), field("Completed", completed_at), field("Duration seconds", f"{duration:.3f}"),
        field("Exit status", return_code), field("Plan", metadata["plan"] or "NOT REPORTED"),
        field("Backend", metadata["backend"] or "NOT REPORTED"),
        field("Job ID", job_id or "NOT APPLICABLE/NOT REPORTED"),
        field("Fallback reason", metadata["fallback"] or "NONE REPORTED"),
        field("Source SHA-256", source_digest(source)), field("Working directory", pathlib.Path.cwd()),
        field("Executed command", command_text), LINE + "\n",
        "COMPLETE COMBINED EXECUTION OUTPUT (STDOUT + STDERR)\n", SUBLINE + "\n",
    ])
    lines.append(raw_output if raw_output else "[No stdout or stderr was produced by the workload.]\n")
    if raw_output and not raw_output.endswith("\n"):
        lines.append("\n")
    lines.extend([
        SUBLINE + "\n", "RESULT SUMMARY\n", SUBLINE + "\n",
        field("Execution successful", "YES" if successful else "NO"),
        field("Result contract valid", "YES" if compliant else "NO"),
        field("Execution method", method.upper()),
        field("Final execution target", target), field("Real-QPU job ID", job_id or "N/A"),
        field("Backend", metadata["backend"] or "NOT REPORTED"), field("Plan", metadata["plan"] or "NOT REPORTED"),
        field("Process exit status", return_code), field("Completion date/time", completed_at),
        field("Total duration", f"{duration:.3f} seconds"), field("Source artifact", source),
        field("Result output", canonical), field("Compatibility output", mirror),
    ])
    if violations:
        lines.append("Policy/Execution warning(s):\n" if not formal else "Policy/Execution issue(s):\n")
        lines.extend(f"  - {item}\n" for item in violations)
    else:
        lines.append("Policy/Execution issue(s): NONE\n")
    lines.append(LINE + "\n")
    return "".join(lines), successful, compliant, violations


def atomic_write(path: pathlib.Path, text: str) -> None:
    temporary = path.with_name(f".{path.name}.tmp.{os.getpid()}")
    temporary.write_text(text, encoding="utf-8")
    os.chmod(temporary, 0o644)
    os.replace(temporary, path)


def main() -> int:
    parser = argparse.ArgumentParser(description="BQCA v47 live direct/formal execution capture")
    parser.add_argument("--source", required=True, type=pathlib.Path)
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    source = args.source.expanduser().resolve()
    if not source.is_file() or source.suffix.lower() not in {".py", ".ipynb"}:
        print(f"BQCA_RESULT_OUTPUT_V46=FAIL: invalid source artifact: {source}", file=sys.stderr)
        return 2
    command = list(args.command)
    if command and command[0] == "--":
        command = command[1:]
    if not command:
        print("BQCA_RESULT_OUTPUT_V46=FAIL: execution command is required after --", file=sys.stderr)
        return 2

    canonical = source.with_name(f"{source.stem}-result-output.txt")
    mirror = source.with_name("output.txt")
    method = os.environ.get("BQCA_EXECUTION_METHOD", "DIRECT").upper()
    if method not in {"DIRECT", "FORMAL"}:
        method = "DIRECT"
    started_at = timestamp()
    started_clock = time.monotonic()
    return_code, raw_output, spawn_error = run_live(command, source, canonical, mirror, started_at, method)

    if source.suffix.lower() == ".ipynb":
        extracted = notebook_outputs(source)
        if extracted:
            block = "\n" + SUBLINE + "\nEXTRACTED NOTEBOOK CELL OUTPUTS\n" + SUBLINE + "\n" + extracted
            try:
                sys.stdout.write(block)
                sys.stdout.flush()
            except BrokenPipeError:
                pass
            raw_output += block

    completed_at = timestamp()
    duration = time.monotonic() - started_clock
    report, successful, compliant, violations = build_report(
        source=source, canonical=canonical, mirror=mirror, command=command, raw_output=raw_output,
        return_code=return_code, started_at=started_at, completed_at=completed_at,
        duration=duration, spawn_error=spawn_error, method=method,
    )
    atomic_write(canonical, report)
    atomic_write(mirror, report)
    print(f"BQCA_RESULT_OUTPUT={canonical}")
    print(f"BQCA_OUTPUT_TXT={mirror}")
    print(f"BQCA_EXECUTION_METHOD={method}")
    print(f"BQCA_EXECUTION_SUCCESSFUL={'YES' if successful else 'NO'}")

    if return_code != 0:
        return return_code if 0 < return_code < 256 else 1
    if method == "FORMAL" and violations:
        return 46
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

# BQCA-CANONICAL-PRODUCTION-POLICY-v47:BEGIN
# The sole active policy is .bob/BQCA-PRODUCTION-POLICY-v47.md.
# v47 direct execution is the default for development/testing, exploration,
# debugging, and quick experiments. The orchestrator is explicit and optional
# for formal compliance, production deployment, and audit. Mirror output live
# and write both <source-stem>-result-output.txt and output.txt.
# BQCA-CANONICAL-PRODUCTION-POLICY-v47:END
