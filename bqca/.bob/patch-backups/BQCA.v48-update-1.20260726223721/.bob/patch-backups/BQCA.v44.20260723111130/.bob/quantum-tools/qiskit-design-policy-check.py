#!/usr/bin/env python3
"""BQCA v41 textual Qiskit design validator with request-scoped Hello World."""
from __future__ import annotations

import argparse
import pathlib
import re
import sys

REQUIRED_PATTERNS = [
    (r"(?i)BQCA Qiskit 2\.5\+ Home Environment and Plan Policy", "v40/v41 policy section title"),
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
    (r"(?is)create|implement|write|generate|build|develop|produce|scaffold|construct|code|program|modify|update|repair|fix|refactor|complete|execute", "CODE-intent action classification"),
]

HELLO_VARIANT = re.compile(r"(?i)(?:\bhello[\s_-]*world\b|\bhellow[\s_-]*world\b)")
HELLO_REFERENCE = re.compile(
    r"(?i)(?:bob-quantum-store[/\\]test|hello[-_]?world\.(?:py|ipynb)|"
    r"hellow[-_]?world\.(?:py|ipynb)|run\s+(?:qiskit\s+)?hello[\s_-]*world|"
    r"hello[\s_-]*world\s+(?:test|testing|smoke\s*test|artifact|example|requirement))"
)
PYTHON_FENCE = re.compile(r"```\s*(python|py)\b.*?```", re.I | re.S)
EXECUTABLE_BLOCK = re.compile(
    r"(?s)```[^\n]*\n.*?(?:from\s+qiskit|current\s*=\s*plan\s*\(|backend\s*=\s*connector\s*\(|try\s*:).*?```",
    re.I,
)


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
        problems.append(
            "Hello World content is prohibited in a non-Hello-World design; remove the section, test, command, artifact, and test-folder reference"
        )

    return problems


def main() -> int:
    parser = argparse.ArgumentParser(description="BQCA v41 textual design validator")
    parser.add_argument("paths", nargs="+")
    args = parser.parse_args()
    failed = False

    for raw in args.paths:
        path = pathlib.Path(raw)
        problems = validate(path)
        if problems:
            failed = True
            print(f"BQCA_QISKIT_DESIGN_POLICY_V41=FAIL file={path}")
            for problem in problems:
                print(f"  - {problem}")
        else:
            print(f"BQCA_QISKIT_DESIGN_POLICY_V41=PASS file={path}")

    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
# BQCA-CANONICAL-PRODUCTION-POLICY-v43:BEGIN
# The sole active BQCA policy is .bob/BQCA-PRODUCTION-POLICY.md. Historical
# policies are audit records only. Route design, code, execution, result, and
# completion enforcement through bqca-policy-orchestrator.sh.
# BQCA-CANONICAL-PRODUCTION-POLICY-v43:END
