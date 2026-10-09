#!/usr/bin/env python3
"""Version-neutral BQCA design/code validator driven by the active policy.

The validator resolves the active policy and its embedded machine-readable
validation contract on every invocation.  It never hardcodes a BQCA policy
version.  A compliance report is written beside every validated design or code
artifact on both PASS and FAIL outcomes.
"""
from __future__ import annotations

import argparse
import ast
import hashlib
import os
import pathlib
import re
import sys
import time
from dataclasses import dataclass, field
from datetime import datetime
from typing import Any, Iterable

SCRIPT_DIR = pathlib.Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from bqca_active_policy import PolicyError, load_active_policy  # noqa: E402


@dataclass
class GateResult:
    gate_id: str
    label: str
    status: str
    detail: str
    findings: list[str] = field(default_factory=list)


KNOWN_GATE_TYPES = {"routing", "text_policy", "python_syntax", "python_policy", "secret_scan"}
KNOWN_SEMANTIC_CHECKS = {
    "exact_imports",
    "assignment_calls",
    "home_environment_marker",
    "qiskit_min_version",
    "direct_execution_wrapper",
    "open_plan_v2_job_mode",
    "paid_plan_session_v2",
    "simulator_fallback",
    "real_backend_run_forbidden",
    "qpu_checks",
    "execution_markers",
    "synchronous_execution",
}


def compile_regex(pattern: str, flags: str | None = None) -> re.Pattern[str]:
    value = 0
    for flag in (flags or "ims"):
        value |= {"i": re.I, "m": re.M, "s": re.S, "x": re.X}.get(flag.lower(), 0)
    try:
        return re.compile(pattern, value)
    except re.error as exc:
        raise PolicyError(f"Invalid validation-contract regex {pattern!r}: {exc}") from exc


def version_token(version: str) -> str:
    return re.sub(r"[^A-Za-z0-9]+", "_", version).strip("_").upper() or "ACTIVE"


def first_heading(text: str) -> str:
    for raw in text.splitlines():
        line = raw.strip()
        if not line:
            continue
        return line.lstrip("#").strip() if line.startswith("#") else line
    return ""


def rule_is_exempt(rule: dict[str, Any], path: pathlib.Path, text: str) -> bool:
    path_pattern = rule.get("unless_path_regex")
    heading_pattern = rule.get("unless_heading_regex")
    if path_pattern and compile_regex(str(path_pattern), "i").search(str(path)):
        return True
    if heading_pattern and compile_regex(str(heading_pattern), "i").search(first_heading(text)):
        return True
    return False


def apply_text_rules(path: pathlib.Path, text: str, section: dict[str, Any]) -> list[str]:
    """Apply active-policy literal and regex needles.

    A future policy contract may use either detailed rule objects or concise
    string needles. The validator follows either form without source changes.
    """
    problems: list[str] = []

    for raw_rule in section.get("required_literals", []):
        if isinstance(raw_rule, str):
            rule: dict[str, Any] = {"value": raw_rule}
        elif isinstance(raw_rule, dict):
            rule = raw_rule
        else:
            problems.append("active policy contains an invalid required-literal rule")
            continue
        if rule_is_exempt(rule, path, text):
            continue
        value = str(rule.get("value", ""))
        if value and value.lower() not in text.lower():
            problems.append(str(rule.get("message") or f"missing required text: {value}"))

    for raw_rule in section.get("required_regex", []):
        if isinstance(raw_rule, str):
            rule = {"pattern": raw_rule}
        elif isinstance(raw_rule, dict):
            rule = raw_rule
        else:
            problems.append("active policy contains an invalid required-regex rule")
            continue
        if rule_is_exempt(rule, path, text):
            continue
        pattern = str(rule.get("pattern", ""))
        if pattern and not compile_regex(pattern, str(rule.get("flags", "ims"))).search(text):
            problems.append(str(rule.get("message") or f"missing required policy pattern: {pattern}"))

    for raw_group in section.get("required_any_groups", []):
        if isinstance(raw_group, (list, tuple)):
            group: dict[str, Any] = {"patterns": list(raw_group)}
        elif isinstance(raw_group, dict):
            group = raw_group
        else:
            problems.append("active policy contains an invalid required-any group")
            continue
        if rule_is_exempt(group, path, text):
            continue
        patterns = [str(item) for item in group.get("patterns", []) if str(item)]
        if patterns and not any(compile_regex(pattern, str(group.get("flags", "ims"))).search(text) for pattern in patterns):
            problems.append(str(group.get("message") or "missing one of the required active-policy alternatives"))

    for raw_rule in section.get("forbidden_literals", []):
        if isinstance(raw_rule, str):
            rule = {"value": raw_rule}
        elif isinstance(raw_rule, dict):
            rule = raw_rule
        else:
            problems.append("active policy contains an invalid forbidden-literal rule")
            continue
        if rule_is_exempt(rule, path, text):
            continue
        value = str(rule.get("value", ""))
        if value and value.lower() in text.lower():
            problems.append(str(rule.get("message") or f"forbidden text found: {value}"))

    for raw_rule in section.get("forbidden_regex", []):
        if isinstance(raw_rule, str):
            rule = {"pattern": raw_rule}
        elif isinstance(raw_rule, dict):
            rule = raw_rule
        else:
            problems.append("active policy contains an invalid forbidden-regex rule")
            continue
        if rule_is_exempt(rule, path, text):
            continue
        pattern = str(rule.get("pattern", ""))
        if pattern and compile_regex(pattern, str(rule.get("flags", "ims"))).search(text):
            problems.append(str(rule.get("message") or f"forbidden policy pattern found: {pattern}"))
    return problems


# ---------------------------- Code semantic helpers ----------------------------

def read_python(path: pathlib.Path) -> tuple[str, ast.AST]:
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
    return any(keyword.arg == "mode" and isinstance(keyword.value, ast.Name) and keyword.value.id == mode_name for keyword in call.keywords)


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
    return bool(statements) and has_session_call(statements, sessions) and any(is_mode_call(call, samplers | estimators, "session") for call in calls_in(statements))


def simulator_receiver_name(call: ast.Call) -> str:
    if not isinstance(call.func, ast.Attribute) or call.func.attr != "run":
        return ""
    return unparse(call.func.value)


def simulator_operations_ok(statements: list[ast.stmt], simulator_names: set[str]) -> bool:
    calls = calls_in(statements)
    has_simulator = any(call_name(call) in simulator_names for call in calls)
    has_transpile = any(call_name(call) == "transpile" for call in calls)
    has_local_run = any(simulator_receiver_name(call) and any(token in simulator_receiver_name(call).lower() for token in ("sim", "aer", "local")) for call in calls)
    return has_simulator and has_transpile and has_local_run


def simulator_fallback_ok(tree: ast.AST, simulator_names: set[str]) -> bool:
    functions = {node.name: node.body for node in ast.walk(tree) if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))}
    for node in ast.walk(tree):
        if not isinstance(node, ast.Try):
            continue
        handler_statements = [statement for handler in node.handlers for statement in handler.body]
        if simulator_operations_ok(handler_statements, simulator_names):
            return True
        for call in calls_in(handler_statements):
            name = call_name(call)
            if name in functions and any(token in name.lower() for token in ("sim", "fallback")) and simulator_operations_ok(functions[name], simulator_names):
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


def apply_code_semantic_checks(text: str, tree: ast.AST, section: dict[str, Any]) -> list[str]:
    checks = set(str(item) for item in section.get("semantic_checks", []))
    unknown = checks - KNOWN_SEMANTIC_CHECKS
    if unknown:
        return ["active policy requests unsupported semantic check(s): " + ", ".join(sorted(unknown))]
    params = section.get("parameters", {}) if isinstance(section.get("parameters"), dict) else {}
    problems: list[str] = []
    aliases = imported_aliases(tree)
    if "exact_imports" in checks:
        for required in params.get("exact_imports", []):
            if not isinstance(required, dict):
                continue
            item = (str(required.get("module", "")), str(required.get("name", "")), required.get("asname"))
            if item not in aliases:
                alias_text = f" as {item[2]}" if item[2] else ""
                problems.append(f"missing exact import: from {item[0]} import {item[1]}{alias_text}")
    if "assignment_calls" in checks:
        for required in params.get("assignment_calls", []):
            if isinstance(required, dict):
                target, function = str(required.get("target", "")), str(required.get("function", ""))
                if target and function and not has_assignment(tree, target, function):
                    problems.append(f"missing executable assignment: {target} = {function}()")
    if "home_environment_marker" in checks:
        markers = [str(item) for item in params.get("home_environment_markers", ["$HOME/qiskit-v2x-env", "~/qiskit-v2x-env"])]
        if not any(marker in text for marker in markers):
            problems.append("missing authorized home-scoped qiskit-v2x-env execution marker")
    if "qiskit_min_version" in checks:
        minimum = str(params.get("minimum_qiskit_version", "2.5"))
        escaped = re.escape(minimum)
        if not re.search(rf"(?is)qiskit.{{0,100}}(?:>=|version|minimum|min).{{0,30}}{escaped}|{escaped}.{{0,100}}qiskit", text):
            problems.append(f"missing explicit Qiskit {minimum}-or-later requirement")
    if "direct_execution_wrapper" in checks:
        wrapper = str(params.get("direct_execution_wrapper", "bqca-direct-execution.sh"))
        if wrapper not in text:
            problems.append(f"missing direct-execution wrapper contract: {wrapper}")
    samplers, estimators, sessions = runtime_aliases(tree)
    open_branch = find_open_plan_if(tree)
    if "open_plan_v2_job_mode" in checks:
        if open_branch is None:
            problems.append("missing explicit Open Plan execution branch")
        else:
            if not open_job_primitives(open_branch, samplers, estimators):
                problems.append("Open Plan branch must use SamplerV2(mode=backend) or EstimatorV2(mode=backend)")
            if has_session_call(open_branch.body, sessions):
                problems.append("Open Plan branch illegally constructs or uses Session")
    if "paid_plan_session_v2" in checks and (open_branch is None or not has_paid_session_strategy(open_branch, samplers, estimators, sessions)):
        problems.append("Paid Plan branch must use Session with SamplerV2/EstimatorV2 mode=session")
    if "simulator_fallback" in checks:
        simulator_names = set(str(item) for item in params.get("simulator_names", ["AerSimulator", "StatevectorSimulator", "BasicSimulator"]))
        if not simulator_fallback_ok(tree, simulator_names):
            problems.append("missing try/except simulator fallback using transpile plus a supported local simulator run")
    if "real_backend_run_forbidden" in checks:
        bad_lines = invalid_backend_runs(tree)
        if bad_lines:
            problems.append("backend.run() is prohibited for real QPU backends; offending line(s): " + ", ".join(map(str, bad_lines)))
    if "qpu_checks" in checks and not qpu_checks_ok(tree):
        problems.append("missing QPU availability/operational and qubit-capacity checks")
    evidence = strings_and_text(tree, text)
    if "execution_markers" in checks:
        for marker in params.get("required_markers", []):
            marker = str(marker)
            if marker and marker not in evidence:
                problems.append(f"missing canonical runtime marker: {marker}")
    if "synchronous_execution" in checks and ("nohup" in text or re.search(r"(?m)(?<!&)&\s*$", text)):
        problems.append("execution instructions must use the synchronous direct executor")
    return problems


# ------------------------------ Gate evaluation -------------------------------

def path_under(path: pathlib.Path, root: pathlib.Path) -> bool:
    try:
        path.resolve().relative_to(root.resolve())
        return True
    except ValueError:
        return False


def routing_gate(path: pathlib.Path, root: pathlib.Path, gate: dict[str, Any]) -> list[str]:
    problems: list[str] = []
    allowed_roots = [root / str(item) for item in gate.get("allowed_roots", [])]
    if allowed_roots and not any(path_under(path, candidate) for candidate in allowed_roots):
        problems.append("artifact is outside the active policy's governed store")
    allowed_extensions = {str(item).lower() for item in gate.get("allowed_extensions", [])}
    if allowed_extensions and path.suffix.lower() not in allowed_extensions:
        problems.append(f"artifact extension {path.suffix!r} is not permitted")
    return problems


def default_secret_patterns() -> list[tuple[re.Pattern[str], str]]:
    return [
        (re.compile(r"(?is)\b(?:IQP_API_TOKEN|BOB_API_KEY|API[_-]?KEY|ACCESS[_-]?TOKEN)\b\s*[:=]\s*[\"'][^\"'\s]{12,}[\"']"), "hardcoded credential assignment detected"),
        (re.compile(r"(?is)\bBearer\s+[A-Za-z0-9._~+/-]{20,}"), "Bearer credential detected"),
        (re.compile(r"(?is)[\"']token[\"']\s*:\s*[\"'][^\"'\s]{12,}[\"']"), "hardcoded token value detected"),
    ]


def secret_gate(text: str, gate: dict[str, Any]) -> list[str]:
    patterns = default_secret_patterns()
    for item in gate.get("patterns", []):
        if isinstance(item, dict) and item.get("pattern"):
            patterns.append((compile_regex(str(item["pattern"]), str(item.get("flags", "ims"))), str(item.get("message", "secret pattern detected"))))
    return [message for pattern, message in patterns if pattern.search(text)]


def gate_token(gate_id: str, kind: str, version: str) -> str:
    token = version_token(version)
    mapping = {
        "artifact_routing": f"BQCA_ARTIFACT_ROUTING_{token}",
        "design_policy": f"BQCA_QISKIT_DESIGN_POLICY_{token}",
        "code_policy": f"BQCA_QISKIT_CODE_POLICY_{token}",
        "python_syntax": f"BQCA_PYTHON_SYNTAX_{token}",
        "home_environment": f"BQCA_HOME_ENV_POLICY_{token}",
        "hello_world_scope": f"BQCA_HELLO_WORLD_SCOPE_{token}",
        "result_output_contract": f"BQCA_RESULT_OUTPUT_POLICY_{token}_{kind.upper()}",
        "secret_scan": f"BQCA_SECRET_SCAN_{token}",
    }
    return mapping.get(gate_id, f"BQCA_{re.sub(r'[^A-Za-z0-9]+', '_', gate_id).upper()}_{token}")


def evaluate_gate(path: pathlib.Path, kind: str, root: pathlib.Path, gate: dict[str, Any], text: str, tree: ast.AST | None, qiskit_code: bool) -> GateResult:
    gate_id = str(gate.get("id") or "unnamed_gate")
    label = str(gate.get("label") or gate_id.replace("_", " ").title())
    gate_type = str(gate.get("type") or "text_policy")
    if gate_type not in KNOWN_GATE_TYPES:
        problems = [f"active policy requests unsupported gate type: {gate_type}"]
    elif gate_type == "routing":
        problems = routing_gate(path, root, gate)
    elif gate_type == "text_policy":
        problems = apply_text_rules(path, text, gate)
    elif gate_type == "python_syntax":
        problems = [] if tree is not None else ["Python syntax is invalid"]
    elif gate_type == "python_policy":
        if not qiskit_code:
            return GateResult(gate_id, label, "PASS", "Non-Qiskit artifact; Qiskit-specific policy checks are not applicable", [])
        problems = apply_text_rules(path, text, gate)
        if tree is None:
            problems.append("Python syntax must pass before code-policy checks")
        else:
            problems.extend(apply_code_semantic_checks(text, tree, gate))
    else:
        problems = secret_gate(text, gate)
    status = "PASS" if not problems else "FAIL"
    return GateResult(gate_id, label, status, "", problems)


def report_path(path: pathlib.Path, kind: str, reporting: dict[str, Any]) -> pathlib.Path:
    stem = path.stem
    if kind == "design":
        suffix = str(reporting.get("design_suffix", "-design-policy-compliance.txt"))
        if stem.lower().endswith("-design") and suffix.startswith("-design"):
            filename = stem + suffix[len("-design"):]
        else:
            filename = stem + suffix
    else:
        suffix = str(reporting.get("code_suffix", "-code-policy-compliance.txt"))
        if stem.lower().endswith("-code") and suffix.startswith("-code"):
            filename = stem + suffix[len("-code"):]
        else:
            filename = stem + suffix
    return path.with_name(filename)


def sha256_file(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def write_report(path: pathlib.Path, kind: str, state: Any, results: list[GateResult], reporting: dict[str, Any]) -> pathlib.Path:
    output = report_path(path, kind, reporting)
    output.parent.mkdir(parents=True, exist_ok=True)
    compliant = all(item.status != "FAIL" for item in results)
    width = 88
    title = str(reporting.get("title", "FORMAL POLICY COMPLIANCE REPORT"))
    lines = [
        "=" * width,
        f"BQCA {state.active_version} {title}",
        "=" * width,
        f"Artifact                : {path.resolve()}",
        f"Artifact type           : {kind}",
        f"Canonical policy        : {state.policy_path}",
        f"Active policy SHA-256   : {state.policy_sha256}",
        f"Validation contract SHA : {state.contract_sha256}",
        f"Validation date/time    : {datetime.now().astimezone().isoformat()}",
        f"Artifact SHA-256        : {sha256_file(path) if path.is_file() else 'NOT AVAILABLE'}",
        "-" * width,
        "VALIDATION GATES",
        "-" * width,
    ]
    token = version_token(state.active_version)
    for item in results:
        gate_status = item.status
        detail_token = gate_token(item.gate_id, kind, state.active_version)
        detail = item.detail or f"{detail_token}={gate_status} active_policy={state.active_version} file={path.resolve()}"
        lines.append(f"{item.label[:31]:31} : {gate_status[:8]:8} {detail}".rstrip())
    findings = [(item.label, finding) for item in results for finding in item.findings]
    if findings:
        lines.extend(["-" * width, "VALIDATION FINDINGS", "-" * width])
        for label, finding in findings:
            lines.append(f"- {label}: {finding}")
    lines.extend([
        "-" * width,
        f"FINAL STATUS            : {'COMPLIANT' if compliant else 'NON-COMPLIANT'}",
        "=" * width,
    ])
    temporary = output.with_name(f".{output.name}.{os.getpid()}.{time.time_ns()}.tmp")
    temporary.write_text("\n".join(lines) + "\n", encoding="utf-8")
    temporary.replace(output)
    output.chmod(0o644)
    return output


def validate_artifact(path: pathlib.Path, kind: str, state: Any) -> tuple[list[GateResult], pathlib.Path | None]:
    section = state.contract.get(kind)
    if not isinstance(section, dict):
        raise PolicyError(f"active policy contract has no {kind} section")
    gates = section.get("gates")
    if not isinstance(gates, list) or not gates:
        raise PolicyError(f"active policy contract {kind} section has no gates")
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as exc:
        text = ""
        results = [GateResult("artifact_read", "Artifact readability", "FAIL", "", [f"cannot read artifact: {exc}"])]
        reporting = state.contract.get("compliance_reporting", {})
        report = write_report(path, kind, state, results, reporting) if path.exists() else None
        return results, report
    tree: ast.AST | None = None
    if kind == "code":
        try:
            tree = ast.parse(text, filename=str(path))
        except SyntaxError:
            tree = None
    qiskit_code = bool(tree is not None and imports_qiskit(tree))
    results = [evaluate_gate(path, kind, state.root, gate, text, tree, qiskit_code) for gate in gates if isinstance(gate, dict)]
    reporting = state.contract.get("compliance_reporting", {})
    report = None
    enabled = not isinstance(reporting, dict) or bool(reporting.get("enabled", True))
    if enabled:
        report = write_report(path, kind, state, results, reporting if isinstance(reporting, dict) else {})
    return results, report


def main() -> int:
    parser = argparse.ArgumentParser(description="BQCA active-policy dynamic design/code validator")
    parser.add_argument("--kind", choices=("design", "code"), required=True)
    parser.add_argument("--root", type=pathlib.Path)
    parser.add_argument("--no-report", action="store_true")
    parser.add_argument("paths", nargs="+")
    args = parser.parse_args()
    try:
        state = load_active_policy(args.root, write_cache=True)
    except PolicyError as exc:
        print(f"BQCA_ACTIVE_POLICY_VALIDATION=FAIL: {exc}", file=sys.stderr)
        return 2
    if args.no_report:
        reporting = state.contract.get("compliance_reporting")
        if isinstance(reporting, dict):
            reporting["enabled"] = False
    failed = False
    token = version_token(state.active_version)
    label = "DESIGN" if args.kind == "design" else "CODE"
    for raw in args.paths:
        path = pathlib.Path(raw).expanduser()
        if not path.is_absolute():
            path = (pathlib.Path.cwd() / path).resolve()
        if not path.is_file():
            failed = True
            print(f"BQCA_QISKIT_{label}_POLICY_{token}=FAIL active_policy={state.active_version} file={path}")
            print("  - artifact file not found")
            continue
        try:
            results, report = validate_artifact(path, args.kind, state)
        except PolicyError as exc:
            failed = True
            print(f"BQCA_QISKIT_{label}_POLICY_{token}=FAIL active_policy={state.active_version} file={path}")
            print(f"  - {exc}")
            continue
        problems = [finding for item in results for finding in item.findings]
        compliant = all(item.status != "FAIL" for item in results)
        if not compliant:
            failed = True
        status = "PASS" if compliant else "FAIL"
        report_text = f" compliance_report={report}" if report else ""
        print(f"BQCA_QISKIT_{label}_POLICY_{token}={status} active_policy={state.active_version} file={path}{report_text}")
        for problem in problems:
            print(f"  - {problem}")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())

# BQCA-ACTIVE-CENTRAL-POLICY:BEGIN
# Resolve the active authority through bqca-active-policy-listener.sh before
# every quantum DESIGN or CODE decision. Never hardcode a policy version or
# duplicate the full policy here. qiskit-design-policy-check.py and
# qiskit-code-policy-check.py reload the active registry/policy/contract on
# every invocation and create same-directory policy-compliance reports.
# Do not report completion until the active-policy report exists.
# BQCA-ACTIVE-CENTRAL-POLICY:END
