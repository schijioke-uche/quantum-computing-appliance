#!/usr/bin/env python3
"""BQCA v48 textual quantum-design validator."""
from __future__ import annotations

import argparse
import pathlib
import re

REQUIRED_PATTERNS = [
    (r"(?i)(?:\$HOME|~)/qiskit-v2x-env", "home-scoped qiskit-v2x-env path"),
    (r"(?i)source\s+(?:\"?\$HOME|~)/qiskit-v2x-env/bin/activate", "home environment activation command"),
    (r"(?i)Qiskit.{0,100}(?:2\.5|2\.5\+|2\.5 or later)", "Qiskit 2.5-or-later requirement"),
    (r"(?is)Open Plan.{0,360}(?:(?:must\s+not|never|prohibited|forbidden|not\s+allowed).{0,100}Session|(?:no|without)\s+Session)", "Open Plan no-Session rule"),
    (r"SamplerV2\s*\(\s*mode\s*=\s*backend\s*\)", "Open Plan SamplerV2(mode=backend) option"),
    (r"EstimatorV2\s*\(\s*mode\s*=\s*backend\s*\)", "Open Plan EstimatorV2(mode=backend) option"),
    (r"(?is)(?:Paid Plan|Flex|Pay-As-You-Go|Premium|Dedicated).{0,360}Session", "Paid Plan Session strategy"),
    (r"(?is)(?:SamplerV2|EstimatorV2).{0,180}mode\s*=\s*session", "Paid Plan Runtime primitive requirement"),
    (r"(?is)try\s*/?\s*except|try.{0,160}except", "try/except fallback requirement"),
    (r"(?i)AerSimulator", "AerSimulator fallback requirement"),
    (r"(?is)transpile.{0,220}(?:AerSimulator|simulator)|(?:AerSimulator|simulator).{0,220}transpile", "simulator transpilation requirement"),
    (r"(?is)(?:backend\.run\(\).{0,220}(?:real QPU|hardware).{0,140}(?:prohibited|forbidden|must\s+not|not\s+allowed)|(?:real QPU|hardware).{0,220}backend\.run\(\).{0,140}(?:prohibited|forbidden|must\s+not|not\s+allowed))", "real-QPU backend.run prohibition"),
    (r"(?i)bqca-direct-execution\.sh", "direct-execution wrapper"),
    (r"(?i)development.{0,120}direct|testing.{0,120}direct|debugging.{0,120}direct", "direct execution as the normal development method"),
    (r"(?is)(?:formal|compliance|production|audit).{0,220}(?:orchestrator|formal-run)|(?:orchestrator|formal-run).{0,220}(?:formal|compliance|production|audit)", "formal orchestrator opt-in scope"),
    (r"(?is)(?:stdout|standard output).{0,100}(?:stderr|standard error).{0,120}(?:terminal|live|stream)", "live combined stdout/stderr requirement"),
    (r"(?i)PYTHONUNBUFFERED\s*=\s*1", "PYTHONUNBUFFERED=1 requirement"),
    (r"(?i)python\s+-u", "python -u requirement"),
    (r"(?i)<source-stem>-result-output\.txt|<code-name>-result-output\.txt", "authoritative result filename"),
    (r"(?i)output\.txt", "output.txt mirror"),
    (r"(?i)BQCA_EXECUTION_TARGET", "BQCA_EXECUTION_TARGET marker"),
    (r"(?i)BQCA_PLAN", "BQCA_PLAN marker"),
    (r"(?i)BQCA_BACKEND", "BQCA_BACKEND marker"),
    (r"(?i)BQCA_JOB_ID", "BQCA_JOB_ID marker"),
    (r"(?i)BQCA_RESULT\s*=\s*SUCCESS", "BQCA_RESULT=SUCCESS marker"),
    (r"(?i)BQCA_RESULT\s*=\s*FAILURE", "BQCA_RESULT=FAILURE marker"),
    (r"(?is)JOB ID.{0,100}(?:first line|line one)|(?:first line|line one).{0,100}JOB ID", "real-QPU Job ID line-one requirement"),
    (r"(?is)RESULT SUMMARY.{0,160}(?:bottom|end)|(?:bottom|end).{0,160}RESULT SUMMARY", "bottom RESULT SUMMARY requirement"),
    (r"(?is)(?:policy gaps|missing markers|contract gaps).{0,160}(?:warning|non-blocking)", "direct-mode non-blocking policy-gap rule"),
    (r"(?is)(?:credential|secret).{0,120}(?:blocking|must block|prohibited)", "credential leakage blocking rule"),
]

HELLO_VARIANT = re.compile(r"(?i)(?:\bhello[\s_-]*world\b|\bhellow[\s_-]*world\b)")
PYTHON_FENCE = re.compile(r"```\s*(python|py)\b.*?```", re.I | re.S)
EXECUTABLE_BLOCK = re.compile(r"(?s)```[^\n]*\n.*?(?:from\s+qiskit|current\s*=\s*plan\s*\(|backend\s*=\s*connector\s*\(|try\s*:).*?```", re.I)


def normalized(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", value.lower())


def is_hello_world_design(path: pathlib.Path, text: str) -> bool:
    stem = normalized(path.stem)
    if "helloworld" in stem or "hellowworld" in stem:
        return True
    for raw in text.splitlines():
        line = raw.strip()
        if not line:
            continue
        if line.startswith("#"):
            return bool(HELLO_VARIANT.search(line.lstrip("#").strip()))
        break
    return False


def validate(path: pathlib.Path) -> list[str]:
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as exc:
        return [f"cannot read design file: {exc}"]
    problems: list[str] = []
    if PYTHON_FENCE.search(text) or EXECUTABLE_BLOCK.search(text):
        problems.append("design contains executable/fenced Python; use textual instructions only")
    for pattern, label in REQUIRED_PATTERNS:
        if not re.search(pattern, text):
            problems.append(f"missing {label}")
    if not is_hello_world_design(path, text) and HELLO_VARIANT.search(text):
        problems.append("Hello World content is prohibited in a non-Hello-World design")
    if re.search(r"(?i)\bbackground\b|\bnohup\b", text):
        problems.append("design must use the direct synchronous execution contract without alternate shell routing")
    return problems


def main() -> int:
    parser = argparse.ArgumentParser(description="BQCA v48 textual design validator")
    parser.add_argument("paths", nargs="+")
    args = parser.parse_args()
    failed = False
    for raw in args.paths:
        path = pathlib.Path(raw)
        problems = validate(path)
        if problems:
            failed = True
            print(f"BQCA_QISKIT_DESIGN_POLICY_V48=FAIL file={path}")
            for problem in problems:
                print(f"  - {problem}")
        else:
            print(f"BQCA_QISKIT_DESIGN_POLICY_V48=PASS file={path}")
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
