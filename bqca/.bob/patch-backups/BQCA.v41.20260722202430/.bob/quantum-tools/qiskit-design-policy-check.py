#!/usr/bin/env python3
"""BQCA v40 textual-only Qiskit design-policy validator."""
from __future__ import annotations

import argparse
import pathlib
import re
import sys

REQUIRED_PATTERNS = [
    (r"(?i)BQCA Qiskit 2\.5\+ Home Environment and Plan Policy", "v40 policy section title"),
    (r"(?i)(?:\$HOME|~)/qiskit-v2x-env", "home-scoped qiskit-v2x-env path"),
    (r"(?i)source\s+(?:\"?\$HOME|~)/qiskit-v2x-env/bin/activate", "home environment activation command"),
    (r"(?is)(?:(?:must\s+not|never|prohibited).{0,180}(?:project\s+root|project-local).{0,180}qiskit-v2x-env|qiskit-v2x-env.{0,180}(?:must\s+not|never|prohibited).{0,180}(?:project\s+root|project-local))", "project-local environment prohibition"),
    (r"(?is)(?:only|exclusively).{0,180}(?:activated|home).{0,180}qiskit-v2x-env.{0,180}(?:version|install|upgrade|uninstall|pip)", "home-environment-only package-management rule"),
    (r"(?i)Qiskit.{0,100}(?:2\.5|2\.5\+|2\.5 or later)", "Qiskit 2.5-or-later requirement"),
    (r"(?is)Open Plan.{0,280}(?:Session.{0,80}(?:prohibited|forbidden|not allowed|must not)|(?:no|without) Session)", "Open Plan no-Session rule"),
    (r"SamplerV2\s*\(\s*mode\s*=\s*backend\s*\)", "Open Plan SamplerV2(mode=backend) requirement"),
    (r"(?is)(?:Paid Plan|Flex|Pay-As-You-Go|Premium|Dedicated).{0,320}Session", "Paid Plan Session strategy"),
    (r"(?is)(?:SamplerV2|EstimatorV2).{0,140}mode\s*=\s*session", "Paid Plan Runtime primitive requirement"),
    (r"(?is)try\s*/?\s*except|try.{0,140}except", "try/except fallback requirement"),
    (r"(?i)AerSimulator", "AerSimulator fallback requirement"),
    (r"(?is)transpile.{0,200}(?:AerSimulator|simulator)|(?:AerSimulator|simulator).{0,200}transpile", "simulator transpilation requirement"),
    (r"(?is)backend\.run\(\).{0,200}(?:local simulator|Aer|simulator).{0,200}(?:only|permitted)|(?:local simulator|Aer|simulator).{0,200}backend\.run\(\).{0,200}(?:only|permitted)", "backend.run local-simulator-only rule"),
    (r"(?is)backend\.run\(\).{0,200}(?:real QPU|hardware).{0,120}(?:prohibited|forbidden|must not|not allowed)|(?:real QPU|hardware).{0,200}backend\.run\(\).{0,120}(?:prohibited|forbidden|must not|not allowed)", "real-QPU backend.run prohibition"),
    (r"(?is)Hello World.{0,280}bob-quantum-store/test", "Hello World governed test path"),
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
    parser = argparse.ArgumentParser(description="BQCA v40 textual design validator")
    parser.add_argument("paths", nargs="+")
    args = parser.parse_args()
    failed = False

    for raw in args.paths:
        path = pathlib.Path(raw)
        problems = validate(path)
        if problems:
            failed = True
            print(f"BQCA_QISKIT_DESIGN_POLICY_V40=FAIL file={path}")
            for problem in problems:
                print(f"  - {problem}")
        else:
            print(f"BQCA_QISKIT_DESIGN_POLICY_V40=PASS file={path}")

    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())

# BQCA-QISKIT-HOME-ENV-v40:POLICY-BEGIN
# V40: Use only $HOME/qiskit-v2x-env, created with python3 -m venv
# "$HOME/qiskit-v2x-env" and activated with source
# "$HOME/qiskit-v2x-env/bin/activate". Never create or use a project-local
# qiskit-v2x-env. All Qiskit checks and package operations occur after home
# environment activation. Existing v39 plan and Qiskit 2.5+ rules remain active.
# BQCA-QISKIT-HOME-ENV-v40:POLICY-END
