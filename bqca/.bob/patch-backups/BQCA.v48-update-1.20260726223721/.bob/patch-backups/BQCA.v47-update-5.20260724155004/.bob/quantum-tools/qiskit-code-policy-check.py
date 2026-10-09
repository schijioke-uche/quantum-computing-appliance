#!/usr/bin/env python3
"""BQCA v47 Update 4 Qiskit code-policy validator."""
from __future__ import annotations

import argparse
import ast
import pathlib
import re
import sys
from typing import Iterable

REQ_IMPORTS = {
    ("qiskit_connector", "QConnectorV2", "connector"),
    ("qiskit_connector", "QPlanV2", "plan"),
}
SIMULATOR_NAMES = {"AerSimulator", "BasicSimulator", "StatevectorSimulator"}
REQUIRED_MARKERS = (
    "BQCA_EXECUTION_TARGET=REAL_QPU",
    "BQCA_EXECUTION_TARGET=SIMULATOR",
    "BQCA_PLAN=",
    "BQCA_BACKEND=",
    "BQCA_JOB_ID=",
    "BQCA_RESULT=SUCCESS",
    "BQCA_RESULT=FAILURE",
    "BQCA_FALLBACK_REASON=",
)


def read_source(path: pathlib.Path) -> tuple[str, ast.AST]:
    text = path.read_text(encoding="utf-8")
    return text, ast.parse(text, filename=str(path))


def imports_qiskit(tree: ast.AST) -> bool:
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            if any(alias.name == "qiskit" or alias.name.startswith(("qiskit.", "qiskit_")) for alias in node.names):
                return True
        elif isinstance(node, ast.ImportFrom):
            module = node.module or ""
            if module == "qiskit" or module.startswith(("qiskit.", "qiskit_")):
                return True
    return False


def imported_aliases(tree: ast.AST) -> set[tuple[str, str, str | None]]:
    output: set[tuple[str, str, str | None]] = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.ImportFrom):
            for alias in node.names:
                output.add((node.module or "", alias.name, alias.asname))
    return output


def runtime_aliases(tree: ast.AST) -> tuple[set[str], set[str], set[str]]:
    samplers = {"SamplerV2"}
    estimators = {"EstimatorV2"}
    sessions = {"Session"}
    for node in ast.walk(tree):
        if not isinstance(node, ast.ImportFrom) or (node.module or "") != "qiskit_ibm_runtime":
            continue
        for alias in node.names:
            local = alias.asname or alias.name
            if alias.name == "SamplerV2":
                samplers.add(local)
            elif alias.name == "EstimatorV2":
                estimators.add(local)
            elif alias.name == "Session":
                sessions.add(local)
    return samplers, estimators, sessions


def call_name(call: ast.Call) -> str:
    if isinstance(call.func, ast.Name):
        return call.func.id
    if isinstance(call.func, ast.Attribute):
        return call.func.attr
    return ""


def target_names(node: ast.Assign | ast.AnnAssign) -> Iterable[str]:
    targets = node.targets if isinstance(node, ast.Assign) else [node.target]
    for target in targets:
        if isinstance(target, ast.Name):
            yield target.id


def has_assignment(tree: ast.AST, target: str, function: str) -> bool:
    for node in ast.walk(tree):
        if isinstance(node, (ast.Assign, ast.AnnAssign)) and isinstance(node.value, ast.Call):
            if call_name(node.value) == function and target in set(target_names(node)):
                return True
    return False


def unparse(node: ast.AST) -> str:
    try:
        return ast.unparse(node)
    except Exception:
        return ""


def calls_in(statements: list[ast.stmt]) -> list[ast.Call]:
    module = ast.Module(body=statements, type_ignores=[])
    return [node for node in ast.walk(module) if isinstance(node, ast.Call)]


def is_mode_call(call: ast.Call, names: set[str], mode_name: str) -> bool:
    if call_name(call) not in names:
        return False
    return any(
        keyword.arg == "mode" and isinstance(keyword.value, ast.Name) and keyword.value.id == mode_name
        for keyword in call.keywords
    )


def has_session_call(statements: list[ast.stmt], session_names: set[str]) -> bool:
    return any(call_name(call) in session_names for call in calls_in(statements))


def find_open_plan_if(tree: ast.AST) -> ast.If | None:
    for node in ast.walk(tree):
        if not isinstance(node, ast.If):
            continue
        test = unparse(node.test).lower()
        if "is_open_plan" in test or ("open" in test and ("plan" in test or "current" in test)):
            return node
    return None


def open_job_primitives(node: ast.If, samplers: set[str], estimators: set[str]) -> set[str]:
    found: set[str] = set()
    for call in calls_in(node.body):
        if is_mode_call(call, samplers, "backend"):
            found.add("SamplerV2")
        if is_mode_call(call, estimators, "backend"):
            found.add("EstimatorV2")
    return found


def has_paid_session_strategy(node: ast.If, samplers: set[str], estimators: set[str], sessions: set[str]) -> bool:
    statements = node.orelse
    if not statements:
        return False
    return has_session_call(statements, sessions) and any(
        is_mode_call(call, samplers | estimators, "session") for call in calls_in(statements)
    )


def simulator_receiver_name(call: ast.Call) -> str:
    if not isinstance(call.func, ast.Attribute) or call.func.attr != "run":
        return ""
    return unparse(call.func.value)


def simulator_operations_ok(statements: list[ast.stmt]) -> bool:
    calls = calls_in(statements)
    has_simulator = any(call_name(call) in SIMULATOR_NAMES for call in calls)
    has_transpile = any(call_name(call) == "transpile" for call in calls)
    has_local_run = any(
        simulator_receiver_name(call)
        and any(token in simulator_receiver_name(call).lower() for token in ("sim", "aer", "local"))
        for call in calls
    )
    return has_simulator and has_transpile and has_local_run


def simulator_fallback_ok(tree: ast.AST) -> bool:
    functions = {
        node.name: node.body
        for node in ast.walk(tree)
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))
    }
    for node in ast.walk(tree):
        if not isinstance(node, ast.Try):
            continue
        handler_statements = [statement for handler in node.handlers for statement in handler.body]
        if simulator_operations_ok(handler_statements):
            return True
        for call in calls_in(handler_statements):
            name = call_name(call)
            if name in functions and any(token in name.lower() for token in ("sim", "fallback")):
                if simulator_operations_ok(functions[name]):
                    return True
    return False


def invalid_backend_runs(tree: ast.AST) -> list[int]:
    lines: list[int] = []
    for node in ast.walk(tree):
        if not isinstance(node, ast.Call) or not isinstance(node.func, ast.Attribute) or node.func.attr != "run":
            continue
        receiver = unparse(node.func.value).lower()
        if receiver == "backend" or ("backend" in receiver and not any(token in receiver for token in ("sim", "aer", "local"))):
            lines.append(getattr(node, "lineno", 0))
    return lines


def qpu_checks_ok(tree: ast.AST) -> bool:
    text = unparse(tree).lower()
    availability = any(token in text for token in ("operational", "status", "simulator", "is_simulator"))
    capacity = any(token in text for token in ("num_qubits", "required_qubits", "qubit_capacity"))
    return availability and capacity


def strings_and_text(tree: ast.AST, text: str) -> str:
    strings = [node.value for node in ast.walk(tree) if isinstance(node, ast.Constant) and isinstance(node.value, str)]
    return text + "\n" + "\n".join(strings)


def validate(path: pathlib.Path) -> list[str]:
    try:
        text, tree = read_source(path)
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
    if "$HOME/qiskit-v2x-env" not in text and "~/qiskit-v2x-env" not in text:
        problems.append("missing $HOME/qiskit-v2x-env execution contract marker")
    if not re.search(r"(?is)qiskit.{0,80}(?:>=|version|minimum|min).{0,30}2\.5|2\.5.{0,80}qiskit", text):
        problems.append("missing explicit Qiskit 2.5-or-later requirement")
    if "bqca-direct-execution.sh" not in text:
        problems.append("missing direct-execution wrapper contract")

    samplers, estimators, sessions = runtime_aliases(tree)
    open_branch = find_open_plan_if(tree)
    if open_branch is None:
        problems.append("missing explicit Open Plan execution branch")
    else:
        primitives = open_job_primitives(open_branch, samplers, estimators)
        if not primitives:
            problems.append("Open Plan branch must use SamplerV2(mode=backend) or EstimatorV2(mode=backend)")
        if has_session_call(open_branch.body, sessions):
            problems.append("Open Plan branch illegally constructs or uses Session")
        if not has_paid_session_strategy(open_branch, samplers, estimators, sessions):
            problems.append("Paid Plan branch must use Session with SamplerV2/EstimatorV2 mode=session")

    if not simulator_fallback_ok(tree):
        problems.append("missing try/except simulator fallback using transpile plus AerSimulator/local simulator run")
    bad_lines = invalid_backend_runs(tree)
    if bad_lines:
        problems.append("backend.run() is prohibited for real QPU backends; offending line(s): " + ", ".join(map(str, bad_lines)))
    if not qpu_checks_ok(tree):
        problems.append("missing QPU availability/operational and qubit-capacity checks")

    evidence = strings_and_text(tree, text)
    for marker in REQUIRED_MARKERS:
        if marker not in evidence:
            problems.append(f"missing canonical runtime marker: {marker}")
    if "nohup" in text or re.search(r"(?m)(?<!&)\&\s*$", text):
        problems.append("execution instructions must use the synchronous direct executor")
    return problems


def main() -> int:
    parser = argparse.ArgumentParser(description="BQCA v47 Update 4 Qiskit code policy validator")
    parser.add_argument("paths", nargs="+")
    args = parser.parse_args()
    failed = False
    for raw in args.paths:
        path = pathlib.Path(raw)
        problems = validate(path)
        if problems:
            failed = True
            print(f"BQCA_QISKIT_CODE_POLICY_V47_UPDATE4=FAIL file={path}")
            for problem in problems:
                print(f"  - {problem}")
        else:
            print(f"BQCA_QISKIT_CODE_POLICY_V47_UPDATE4=PASS file={path}")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())

# BQCA-CANONICAL-PRODUCTION-POLICY-v47:BEGIN
# BQCA v47 Update 4: follow .bob/BQCA-PRODUCTION-POLICY.md. Direct execution
# through bqca-direct-execution.sh is the default and must use the authorized
# home Python with unbuffered live stdout/stderr plus dual result capture.
# Code must preserve real-QPU-first plan-aware execution, controlled simulator
# fallback, and the required BQCA markers, including BQCA_RESULT=SUCCESS or
# BQCA_RESULT=FAILURE. The orchestrator is explicit opt-in only for formal
# compliance, deployment, or audit evidence. Direct-mode policy gaps are
# warnings that preserve the workload exit status; credential leakage blocks.
# This block supersedes conflicting local execution guidance.
# BQCA-CANONICAL-PRODUCTION-POLICY-v47:END
