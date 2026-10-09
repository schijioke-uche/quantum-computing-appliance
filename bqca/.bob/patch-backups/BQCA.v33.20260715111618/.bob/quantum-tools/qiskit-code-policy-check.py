#!/usr/bin/env python3
"""BQCA v32 mandatory Qiskit Connector static policy validator."""

from __future__ import annotations

import argparse
import ast
import pathlib
import sys
from dataclasses import dataclass


@dataclass
class Finding:
    path: pathlib.Path
    messages: list[str]


def is_qiskit_program(tree: ast.AST) -> bool:
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            for alias in node.names:
                if alias.name == "qiskit" or alias.name.startswith("qiskit.") or alias.name.startswith("qiskit_"):
                    return True
        elif isinstance(node, ast.ImportFrom):
            module = node.module or ""
            if module == "qiskit" or module.startswith("qiskit.") or module.startswith("qiskit_"):
                return True
    return False


def import_aliases(tree: ast.AST) -> set[tuple[str, str, str | None]]:
    found: set[tuple[str, str, str | None]] = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.ImportFrom):
            module = node.module or ""
            for alias in node.names:
                found.add((module, alias.name, alias.asname))
    return found


def has_assignment_call(tree: ast.AST, target_name: str, call_name: str) -> bool:
    for node in ast.walk(tree):
        if isinstance(node, (ast.Assign, ast.AnnAssign)):
            targets = node.targets if isinstance(node, ast.Assign) else [node.target]
            value = node.value
            if not isinstance(value, ast.Call):
                continue
            func = value.func
            called = func.id if isinstance(func, ast.Name) else None
            if called != call_name:
                continue
            for target in targets:
                if isinstance(target, ast.Name) and target.id == target_name:
                    return True
    return False


def has_try_except(tree: ast.AST) -> bool:
    return any(isinstance(node, ast.Try) and node.handlers for node in ast.walk(tree))


def has_simulator_reference(tree: ast.AST) -> bool:
    names = {"AerSimulator", "BasicSimulator", "StatevectorEstimator", "StatevectorSampler"}
    for node in ast.walk(tree):
        if isinstance(node, ast.Name) and node.id in names:
            return True
        if isinstance(node, ast.Attribute) and node.attr in names:
            return True
        if isinstance(node, ast.ImportFrom):
            if any(alias.name in names for alias in node.names):
                return True
    return False


def has_real_runtime_reference(tree: ast.AST) -> bool:
    names = {"SamplerV2", "EstimatorV2", "Sampler", "Estimator", "Session", "transpile"}
    for node in ast.walk(tree):
        if isinstance(node, ast.Name) and node.id in names:
            return True
        if isinstance(node, ast.Attribute) and node.attr in names:
            return True
        if isinstance(node, ast.ImportFrom):
            if any(alias.name in names for alias in node.names):
                return True
    return False


def has_execution_target_label(source: str) -> bool:
    upper = source.upper()
    return "REAL_QPU" in upper and "SIMULATOR" in upper


def validate_file(path: pathlib.Path) -> Finding | None:
    try:
        source = path.read_text(encoding="utf-8")
    except Exception as exc:
        return Finding(path, [f"cannot read file: {exc}"])

    try:
        tree = ast.parse(source, filename=str(path))
    except SyntaxError as exc:
        return Finding(path, [f"Python syntax error: {exc}"])

    if not is_qiskit_program(tree):
        return None

    errors: list[str] = []
    imports = import_aliases(tree)

    if ("qiskit_connector", "QConnectorV2", "connector") not in imports:
        errors.append("missing exact import: from qiskit_connector import QConnectorV2 as connector")
    if ("qiskit_connector", "QPlanV2", "plan") not in imports:
        errors.append("missing exact import: from qiskit_connector import QPlanV2 as plan")
    if not has_assignment_call(tree, "current", "plan"):
        errors.append("missing executable assignment: current = plan()")
    if not has_assignment_call(tree, "backend", "connector"):
        errors.append("missing executable assignment: backend = connector()")
    if not has_try_except(tree):
        errors.append("missing try/except real-QPU-to-simulator fallback")
    if not has_simulator_reference(tree):
        errors.append("missing executable simulator implementation (AerSimulator/BasicSimulator/statevector primitive)")
    if not has_real_runtime_reference(tree):
        errors.append("missing real-backend transpile/runtime primitive path")
    if not has_execution_target_label(source):
        errors.append("missing explicit REAL_QPU and SIMULATOR execution reporting")

    return Finding(path, errors) if errors else None


def iter_python_targets(targets: list[str]) -> list[pathlib.Path]:
    files: list[pathlib.Path] = []
    for raw in targets:
        path = pathlib.Path(raw).expanduser().resolve()
        if path.is_file() and path.suffix == ".py":
            files.append(path)
        elif path.is_dir():
            files.extend(sorted(p for p in path.rglob("*.py") if "__pycache__" not in p.parts))
        else:
            print(f"ERROR: target not found or unsupported: {raw}", file=sys.stderr)
            raise SystemExit(2)
    return sorted(set(files))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("targets", nargs="+", help="Python file(s) or directories to validate")
    args = parser.parse_args()

    files = iter_python_targets(args.targets)
    checked = 0
    violations: list[Finding] = []

    for path in files:
        try:
            tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
        except Exception:
            tree = None
        if tree is not None and is_qiskit_program(tree):
            checked += 1
        finding = validate_file(path)
        if finding:
            violations.append(finding)

    if violations:
        print("BQCA_QISKIT_POLICY=FAIL")
        for finding in violations:
            print(f"FILE: {finding.path}")
            for message in finding.messages:
                print(f"  - {message}")
        print(f"QISKIT_FILES_CHECKED={checked}")
        print(f"NONCOMPLIANT_FILES={len(violations)}")
        return 1

    print("BQCA_QISKIT_POLICY=PASS")
    print(f"QISKIT_FILES_CHECKED={checked}")
    print("NONCOMPLIANT_FILES=0")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
