#!/usr/bin/env python3
"""BQCA v45 textual Qiskit design-policy validator."""
from __future__ import annotations

import argparse
import pathlib
import re
import sys

REQUIRED_PATTERNS = [
    (r"(?i)BQCA Qiskit 2\.5\+ Home Environment and Plan Policy|BQCA v45 Open Plan Primitive Policy", "v44 plan-policy section title"),
    (r"(?i)(?:\$HOME|~)/qiskit-v2x-env", "home-scoped qiskit-v2x-env path"),
    (r"(?i)source\s+(?:\"?\$HOME|~)/qiskit-v2x-env/bin/activate", "home environment activation command"),
    (r"(?is)(?:(?:project\s+root|project-local).{0,180}qiskit-v2x-env.{0,180}(?:prohibited|forbidden|must\s+not|never)|qiskit-v2x-env.{0,180}(?:prohibited|forbidden|must\s+not|never).{0,180}(?:project\s+root|project-local))", "project-local environment prohibition"),
    (r"(?i)Qiskit.{0,100}(?:2\.5|2\.5\+|2\.5 or later)", "Qiskit 2.5-or-later requirement"),
    (r"(?is)Open Plan.{0,360}(?:(?:must\s+not|never|prohibited|forbidden|not\s+allowed).{0,100}Session|Session.{0,100}(?:prohibited|forbidden|not\s+allowed|must\s+not)|(?:no|without)\s+Session)", "Open Plan no-Session rule"),
    (r"SamplerV2\s*\(\s*mode\s*=\s*backend\s*\)", "Open Plan SamplerV2(mode=backend) option"),
    (r"EstimatorV2\s*\(\s*mode\s*=\s*backend\s*\)", "Open Plan EstimatorV2(mode=backend) option"),
    (r"(?is)(?:SamplerV2.{0,220}(?:sampling|sample|shot|count|distribution)|(?:sampling|sample|shot|count|distribution).{0,220}SamplerV2)", "SamplerV2 workload-suitability guidance"),
    (r"(?is)(?:EstimatorV2.{0,220}(?:expectation|observable|energy|Hamiltonian)|(?:expectation|observable|energy|Hamiltonian).{0,220}EstimatorV2)", "EstimatorV2 workload-suitability guidance"),
    (r"(?is)(?:Paid Plan|Flex|Pay-As-You-Go|Premium|Dedicated).{0,360}Session", "Paid Plan Session strategy"),
    (r"(?is)(?:SamplerV2|EstimatorV2).{0,180}mode\s*=\s*session", "Paid Plan Runtime primitive requirement"),
    (r"(?is)try\s*/?\s*except|try.{0,160}except", "try/except fallback requirement"),
    (r"(?i)AerSimulator", "AerSimulator fallback requirement"),
    (r"(?is)transpile.{0,220}(?:AerSimulator|simulator)|(?:AerSimulator|simulator).{0,220}transpile", "simulator transpilation requirement"),
    (r"(?is)backend\.run\(\).{0,220}(?:local simulator|Aer|simulator).{0,220}(?:only|permitted)|(?:local simulator|Aer|simulator).{0,220}backend\.run\(\).{0,220}(?:only|permitted)", "backend.run local-simulator-only rule"),
    (r"(?is)(?:backend\.run\(\).{0,220}(?:real QPU|hardware).{0,140}(?:prohibited|forbidden|must\s+not|not\s+allowed)|(?:real QPU|hardware).{0,220}backend\.run\(\).{0,140}(?:prohibited|forbidden|must\s+not|not\s+allowed)|backend\.run\(\).{0,180}(?:prohibited|forbidden|must\s+not|not\s+allowed).{0,180}(?:real QPU|hardware))", "real-QPU backend.run prohibition"),
    (r"(?is)create|implement|write|generate|build|develop|produce|scaffold|construct|code|program|modify|update|repair|fix|refactor|complete|execute", "CODE-intent action classification"),
]

HELLO_VARIANT = re.compile(r"(?i)(?:\bhello[\s_-]*world\b|\bhellow[\s_-]*world\b)")
HELLO_REFERENCE = re.compile(r"(?i)(?:bob-quantum-store[/\\]test|hello[-_]?world\.(?:py|ipynb)|hellow[-_]?world\.(?:py|ipynb)|run\s+(?:qiskit\s+)?hello[\s_-]*world|hello[\s_-]*world\s+(?:test|testing|smoke\s*test|artifact|example|requirement))")
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
    hello_design = is_hello_world_design(path, text)
    if PYTHON_FENCE.search(text) or EXECUTABLE_BLOCK.search(text):
        problems.append("design contains executable/fenced Python; use textual instructions only")
    for pattern, label in REQUIRED_PATTERNS:
        if not re.search(pattern, text):
            problems.append(f"missing {label}")
    if not hello_design and (HELLO_VARIANT.search(text) or HELLO_REFERENCE.search(text)):
        problems.append("Hello World content is prohibited in a non-Hello-World design")
    return problems


def main() -> int:
    parser = argparse.ArgumentParser(description="BQCA v45 textual design validator")
    parser.add_argument("paths", nargs="+")
    args = parser.parse_args()
    failed = False
    for raw in args.paths:
        path = pathlib.Path(raw)
        problems = validate(path)
        if problems:
            failed = True
            print(f"BQCA_QISKIT_DESIGN_POLICY_V44=FAIL file={path}")
            for problem in problems:
                print(f"  - {problem}")
        else:
            print(f"BQCA_QISKIT_DESIGN_POLICY_V44=PASS file={path}")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
# BQCA-CANONICAL-PRODUCTION-POLICY-v45:BEGIN
# The sole active BQCA policy is .bob/BQCA-PRODUCTION-POLICY.md (v45).
# Route all public design, code, execution, result, and completion paths through
# bqca-policy-orchestrator.sh. Open Plan uses SamplerV2 or EstimatorV2 job mode
# according to workload semantics and must never use Session.
# BQCA-CANONICAL-PRODUCTION-POLICY-v45:END
