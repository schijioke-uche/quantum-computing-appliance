#!/usr/bin/env python3
"""BQCA v39 update 1 textual-only Qiskit design-policy validator."""
from __future__ import annotations

import argparse
import pathlib
import re
import sys

REQUIRED_PATTERNS = [
    (r"(?i)BQCA Qiskit 2\.5\+ Execution and Plan Policy", "execution-policy section title"),
    (r"(?i)qiskit-v2x-env", "qiskit-v2x-env execution requirement"),
    (r"(?i)Qiskit.{0,100}(?:2\.5|2\.5\+|2\.5 or later)", "Qiskit 2.5-or-later requirement"),
    (r"(?is)(?:only|exclusively).{0,160}qiskit-v2x-env.{0,180}(?:version|install|upgrade|uninstall|pip)", "environment-only Qiskit package-management rule"),
    (r"(?is)(?:system|global|user-site).{0,160}(?:must not|never|prohibited).{0,180}(?:Qiskit|pip|install|upgrade|uninstall)", "host Python/pip prohibition"),
    (r"(?is)Open Plan.{0,280}(?:Session.{0,60}(?:prohibited|forbidden|not allowed|must not)|(?:no|without) Session)", "Open Plan no-Session rule"),
    (r"SamplerV2\s*\(\s*mode\s*=\s*backend\s*\)", "Open Plan SamplerV2(mode=backend) requirement"),
    (r"(?is)(?:Paid Plan|Flex|Pay-As-You-Go|Premium|Dedicated).{0,300}Session", "Paid Plan Session strategy"),
    (r"(?is)(?:SamplerV2|EstimatorV2).{0,120}mode\s*=\s*session", "Paid Plan Runtime primitive requirement"),
    (r"(?is)try\s*/?\s*except|try.{0,120}except", "try/except fallback requirement"),
    (r"(?i)AerSimulator", "AerSimulator fallback requirement"),
    (r"(?is)transpile.{0,180}(?:AerSimulator|simulator)|(?:AerSimulator|simulator).{0,180}transpile", "simulator transpilation requirement"),
    (r"(?is)backend\.run\(\).{0,180}(?:local simulator|Aer|simulator).{0,180}(?:only|permitted)|(?:local simulator|Aer|simulator).{0,180}backend\.run\(\).{0,180}(?:only|permitted)", "backend.run local-simulator-only rule"),
    (r"(?is)backend\.run\(\).{0,180}(?:real QPU|hardware).{0,100}(?:prohibited|forbidden|must not|not allowed)|(?:real QPU|hardware).{0,180}backend\.run\(\).{0,100}(?:prohibited|forbidden|must not|not allowed)", "real-QPU backend.run prohibition"),
    (r"(?is)Hello World.{0,260}bob-quantum-store/test", "Hello World bob-quantum-store/test rule"),
    (r"(?is)create|implement|write|generate|build|develop|produce|scaffold|construct|code|program|modify|update|repair|fix|refactor|complete|execute", "CODE-intent action classification"),
]

PYTHON_FENCE = re.compile(r"```\s*(python|py)\b.*?```", re.I | re.S)
EXECUTABLE_BLOCK = re.compile(
    r"(?s)```[^\n]*\n.*?(?:from\s+qiskit|current\s*=\s*plan\s*\(|backend\s*=\s*connector\s*\(|try\s*:).*?```",
    re.I,
)


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

    return problems


def main() -> int:
    parser = argparse.ArgumentParser(description="BQCA v39 update 1 textual design validator")
    parser.add_argument("paths", nargs="+")
    args = parser.parse_args()
    failed = False

    for raw in args.paths:
        path = pathlib.Path(raw)
        problems = validate(path)
        if problems:
            failed = True
            print(f"BQCA_QISKIT_DESIGN_POLICY_V39_UPDATE_1=FAIL file={path}")
            for problem in problems:
                print(f"  - {problem}")
        else:
            print(f"BQCA_QISKIT_DESIGN_POLICY_V39_UPDATE_1=PASS file={path}")

    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())

# BQCA-QISKIT-EXECUTION-v39-update-1:POLICY-BEGIN
# V39 UPDATE 1: Quantum/Qiskit code intent is immediate. Qiskit checks,
# uninstalls, upgrades, and installs are permitted only inside qiskit-v2x-env.
# System/global Python, pip, and user-site Qiskit are prohibited. Qiskit 2.5+
# is required. Open Plan uses SamplerV2(mode=backend) without Session; paid
# plans use Session with SamplerV2/EstimatorV2; simulator fallback uses
# transpile + AerSimulator. backend.run() is local-simulator-only. Hello World
# artifacts are discovered under bob-quantum-store/test.
# BQCA-QISKIT-EXECUTION-v39-update-1:POLICY-END
