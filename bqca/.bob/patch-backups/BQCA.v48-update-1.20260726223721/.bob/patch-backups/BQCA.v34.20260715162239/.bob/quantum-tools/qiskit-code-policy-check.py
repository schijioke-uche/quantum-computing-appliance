#!/usr/bin/env python3
"""BQCA v33 strict Qiskit Connector code-policy validator."""
from __future__ import annotations

import argparse
import ast
import pathlib
import sys

REQ_IMPORTS = {
    ("qiskit_connector", "QConnectorV2", "connector"),
    ("qiskit_connector", "QPlanV2", "plan"),
}


def imports_qiskit(tree: ast.AST) -> bool:
    for n in ast.walk(tree):
        if isinstance(n, ast.Import):
            if any(a.name == "qiskit" or a.name.startswith("qiskit.") or a.name.startswith("qiskit_") for a in n.names):
                return True
        if isinstance(n, ast.ImportFrom):
            m = n.module or ""
            if m == "qiskit" or m.startswith("qiskit.") or m.startswith("qiskit_"):
                return True
    return False


def imported_aliases(tree: ast.AST) -> set[tuple[str, str, str | None]]:
    out: set[tuple[str, str, str | None]] = set()
    for n in ast.walk(tree):
        if isinstance(n, ast.ImportFrom):
            for a in n.names:
                out.add((n.module or "", a.name, a.asname))
    return out


def is_call(node: ast.AST, name: str) -> bool:
    return isinstance(node, ast.Call) and isinstance(node.func, ast.Name) and node.func.id == name


def has_assignment(tree: ast.AST, target_name: str, call_name: str) -> bool:
    for n in ast.walk(tree):
        if isinstance(n, (ast.Assign, ast.AnnAssign)):
            value = n.value
            targets = n.targets if isinstance(n, ast.Assign) else [n.target]
            if is_call(value, call_name):
                for t in targets:
                    if isinstance(t, ast.Name) and t.id == target_name:
                        return True
    return False


def mentions_simulator(node: ast.AST) -> bool:
    for n in ast.walk(node):
        if isinstance(n, ast.Name) and n.id in {"AerSimulator", "BasicSimulator"}:
            return True
        if isinstance(n, ast.Attribute) and n.attr in {"AerSimulator", "BasicSimulator"}:
            return True
        if isinstance(n, ast.Constant) and isinstance(n.value, str) and "SIMULATOR" in n.value.upper():
            return True
    return False


def mentions_connector_or_real_runtime(node: ast.AST) -> bool:
    for n in ast.walk(node):
        if isinstance(n, ast.Name) and n.id in {"connector", "backend", "Sampler", "SamplerV2", "Estimator", "EstimatorV2", "Session", "transpile"}:
            return True
        if isinstance(n, ast.Attribute) and n.attr in {"run", "result", "backend", "operational", "num_qubits", "status"}:
            return True
        if isinstance(n, ast.Constant) and isinstance(n.value, str) and "REAL_QPU" in n.value.upper():
            return True
    return False


def first_simulator_lineno(tree: ast.AST) -> int | None:
    lines = [getattr(n, "lineno", 10**9) for n in ast.walk(tree) if mentions_simulator(n) and isinstance(n, (ast.Assign, ast.AnnAssign, ast.Expr, ast.With, ast.If, ast.Try))]
    return min(lines) if lines else None


def first_connector_lineno(tree: ast.AST) -> int | None:
    lines: list[int] = []
    for n in ast.walk(tree):
        if isinstance(n, (ast.Assign, ast.AnnAssign)) and is_call(n.value, "connector"):
            lines.append(getattr(n, "lineno", 10**9))
    return min(lines) if lines else None


def has_real_first_try_except(tree: ast.AST) -> bool:
    for n in ast.walk(tree):
        if not isinstance(n, ast.Try):
            continue
        try_mod = ast.Module(body=n.body, type_ignores=[])
        handlers_mod = ast.Module(body=[stmt for h in n.handlers for stmt in h.body], type_ignores=[])
        if mentions_connector_or_real_runtime(try_mod) and mentions_simulator(handlers_mod):
            return True
    return False


def has_qpu_checks(tree: ast.AST) -> bool:
    text_tokens = set()
    for n in ast.walk(tree):
        if isinstance(n, ast.Attribute):
            text_tokens.add(n.attr.lower())
        elif isinstance(n, ast.Name):
            text_tokens.add(n.id.lower())
        elif isinstance(n, ast.Constant) and isinstance(n.value, str):
            text_tokens.update(n.value.lower().replace("-", "_").split())
    availability = bool(text_tokens & {"operational", "status", "simulator", "is_simulator", "backend"})
    capacity = bool(text_tokens & {"num_qubits", "qubits", "required_qubits"})
    return availability and capacity


def has_reporting(tree: ast.AST) -> bool:
    strings = [n.value.upper() for n in ast.walk(tree) if isinstance(n, ast.Constant) and isinstance(n.value, str)]
    joined = "\n".join(strings)
    return "REAL_QPU" in joined and "SIMULATOR" in joined


def validate(path: pathlib.Path) -> list[str]:
    try:
        tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
    except (OSError, UnicodeError, SyntaxError) as exc:
        return [f"cannot parse Python file: {exc}"]

    if not imports_qiskit(tree):
        return []

    problems: list[str] = []
    aliases = imported_aliases(tree)
    for required in sorted(REQ_IMPORTS):
        if required not in aliases:
            module, name, alias = required
            problems.append(f"missing exact import: from {module} import {name} as {alias}")

    if not has_assignment(tree, "current", "plan"):
        problems.append("missing executable assignment: current = plan()")
    if not has_assignment(tree, "backend", "connector"):
        problems.append("missing executable assignment: backend = connector()")
    if not has_real_first_try_except(tree):
        problems.append("missing real-QPU-first try block with simulator fallback in except")
    if not has_qpu_checks(tree):
        problems.append("missing QPU operational/availability and qubit-capacity checks")
    if not has_reporting(tree):
        problems.append("missing explicit REAL_QPU and SIMULATOR execution-target reporting")

    connector_line = first_connector_lineno(tree)
    simulator_line = first_simulator_lineno(tree)
    if simulator_line is not None and (connector_line is None or simulator_line < connector_line):
        problems.append("simulator is initialized or executed before Qiskit Connector real-backend initialization")

    return problems


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("paths", nargs="+")
    args = p.parse_args()
    failed = False
    for raw in args.paths:
        path = pathlib.Path(raw)
        problems = validate(path)
        if problems:
            failed = True
            print(f"BQCA_QISKIT_CODE_POLICY=FAIL file={path}")
            for problem in problems:
                print(f"  - {problem}")
        else:
            print(f"BQCA_QISKIT_CODE_POLICY=PASS file={path}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
