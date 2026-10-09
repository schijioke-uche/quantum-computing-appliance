#!/usr/bin/env python3
"""Version-neutral BQCA active-policy assurance and drift detector."""
from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import re
import stat
import subprocess
import sys
from typing import Any

SCRIPT_DIR = pathlib.Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from bqca_active_policy import PolicyError, load_active_policy  # noqa: E402

GENERIC_MARKER = "BQCA-ACTIVE-CENTRAL-POLICY:BEGIN"
GENERIC_MARKER_LINE = re.compile(r"(?m)^\s*(?:#\s*BQCA-ACTIVE-CENTRAL-POLICY:BEGIN\s*|<!--\s*BQCA-ACTIVE-CENTRAL-POLICY:BEGIN\s*-->)$")
VERSIONED_MARKER = re.compile(r"BQCA-(?:CANONICAL-PRODUCTION-POLICY|ACTIVE-CENTRAL-POLICY)-v\d+(?:-[^:]*)?:BEGIN", re.I)
EXTENSIONS = {".md", ".txt", ".sh", ".py", ".yaml", ".yml"}


def supported_files(root: pathlib.Path) -> tuple[list[pathlib.Path], list[pathlib.Path], list[pathlib.Path]]:
    bob = root / ".bob"
    rules = sorted(path for directory in bob.glob("rules-*") if directory.is_dir() for path in directory.rglob("*") if path.is_file() and path.suffix.lower() in EXTENSIONS)
    skills_root = bob / "skills"
    skills = sorted(path for path in skills_root.rglob("*") if path.is_file() and path.suffix.lower() in EXTENSIONS) if skills_root.is_dir() else []
    tools_root = bob / "quantum-tools"
    tools = sorted(path for path in tools_root.iterdir() if path.is_file() and path.suffix.lower() in EXTENSIONS) if tools_root.is_dir() else []
    knowledgebase = tools_root / "knowlegebase"
    for relative in ("README.md", "bqca_quantum_kb.py"):
        path = knowledgebase / relative
        if path.is_file():
            tools.append(path)
    return rules, skills, sorted(set(tools))


def read_text(path: pathlib.Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def bash_syntax(path: pathlib.Path) -> str | None:
    result = subprocess.run(["bash", "-n", str(path)], text=True, capture_output=True)
    return None if result.returncode == 0 else result.stderr.strip()


def python_syntax(path: pathlib.Path) -> str | None:
    try:
        compile(read_text(path), str(path), "exec")
        return None
    except Exception as exc:
        return str(exc)


def mode_counts(path: pathlib.Path) -> tuple[int, int]:
    text = read_text(path)
    expected = len(re.findall(r"(?m)^\s*customInstructions:\s*[>|][+-]?\s*(?:#.*)?$", text))
    actual = len(GENERIC_MARKER_LINE.findall(text))
    return expected, actual


def history_hash_failures(root: pathlib.Path) -> list[str]:
    manifest = root / "patches/BQCA/policy-history/BQCA-policy-history-manifest.json"
    if not manifest.is_file():
        return []
    try:
        data = json.loads(manifest.read_text(encoding="utf-8"))
    except Exception as exc:
        return [f"cannot parse policy-history manifest: {exc}"]
    entries = data.get("policies") or data.get("entries") or []
    if isinstance(entries, dict):
        entries = list(entries.values())
    errors: list[str] = []
    for entry in entries if isinstance(entries, list) else []:
        if not isinstance(entry, dict):
            continue
        value = entry.get("path") or entry.get("archive_path") or entry.get("file")
        expected = entry.get("sha256")
        if not value or not expected:
            continue
        path = pathlib.Path(str(value))
        if not path.is_absolute():
            path = root / path
        if not path.is_file():
            errors.append(f"history file missing: {path}")
            continue
        actual = hashlib.sha256(path.read_bytes()).hexdigest()
        if actual != expected:
            errors.append(f"history hash mismatch: {path}")
    return errors


def iter_designs(root: pathlib.Path):
    store = root / "bob-quantum-designs"
    if not store.is_dir():
        return
    for path in store.rglob("*"):
        if path.is_file() and path.suffix.lower() in {".md", ".txt"}:
            name = path.name.lower()
            if name not in {"readme.md", "readme.txt"} and not name.endswith("-policy-compliance.txt"):
                yield path


def iter_code(root: pathlib.Path):
    store = root / "bob-quantum-store"
    if not store.is_dir():
        return
    for path in store.rglob("*.py"):
        if path.is_file() and not any(part in {"__pycache__", ".venv", "venv", "node_modules"} for part in path.parts):
            yield path


def report_path(path: pathlib.Path, kind: str) -> pathlib.Path:
    stem = path.stem
    if kind == "design":
        return path.with_name(stem + ("-policy-compliance.txt" if stem.lower().endswith("-design") else "-design-policy-compliance.txt"))
    return path.with_name(stem + ("-policy-compliance.txt" if stem.lower().endswith("-code") else "-code-policy-compliance.txt"))


def compliance_report_errors(root: pathlib.Path, policy_hash: str, contract_hash: str) -> tuple[list[str], int, int]:
    errors: list[str] = []
    expected = 0
    current = 0
    for kind, artifacts in (("design", iter_designs(root)), ("code", iter_code(root))):
        for artifact in artifacts or []:
            expected += 1
            report = report_path(artifact, kind)
            if not report.is_file():
                errors.append(f"missing compliance report: {report}")
                continue
            text = read_text(report)
            artifact_hash = hashlib.sha256(artifact.read_bytes()).hexdigest()
            checks = {
                "artifact hash": f"Artifact SHA-256        : {artifact_hash}",
                "policy hash": f"Active policy SHA-256   : {policy_hash}",
                "contract hash": f"Validation contract SHA : {contract_hash}",
            }
            stale = [name for name, needle in checks.items() if needle not in text]
            if stale:
                errors.append(f"stale compliance report ({', '.join(stale)}): {report}")
            else:
                current += 1
    return errors, expected, current


def check(root: pathlib.Path) -> dict[str, Any]:
    errors: list[str] = []
    result: dict[str, Any] = {}
    try:
        state = load_active_policy(root, write_cache=True)
    except PolicyError as exc:
        return {"errors": [str(exc)], "final_status": "FAIL"}

    bob = root / ".bob"
    tools_root = bob / "quantum-tools"
    custom_modes = bob / "custom_modes.yaml"
    result.update({
        "active_version": state.active_version,
        "policy_path": str(state.policy_path),
        "versioned_policy_path": str(state.versioned_policy_path),
        "policy_sha256": state.policy_sha256,
        "contract_sha256": state.contract_sha256,
    })

    active_policy_files = sorted(path.name for path in bob.glob("BQCA-*POLICY*.md"))
    expected_policy_files = sorted({state.policy_path.name, state.versioned_policy_path.name})
    result["active_policy_files"] = active_policy_files
    if active_policy_files != expected_policy_files:
        errors.append(f"active policy files differ from registry authority: expected {expected_policy_files}, actual {active_policy_files}")
    if not state.cache_path.is_file():
        errors.append(f"active-policy state cache missing: {state.cache_path}")

    expected_modes, actual_modes = mode_counts(custom_modes) if custom_modes.is_file() else (0, 0)
    result["custom_modes_expected"] = expected_modes
    result["custom_modes_actual"] = actual_modes
    if expected_modes == 0 or actual_modes != expected_modes:
        errors.append(f"custom-mode active-policy coverage {actual_modes}/{expected_modes}")

    rules, skills, tools = supported_files(root)
    result["rules"], result["skills"], result["tools"] = len(rules), len(skills), len(tools)
    coverage_errors: list[str] = []
    versioned_hits: list[str] = []
    for path in [*rules, *skills, *tools]:
        text = read_text(path)
        if len(GENERIC_MARKER_LINE.findall(text)) != 1:
            coverage_errors.append(str(path))
        if VERSIONED_MARKER.search(text):
            versioned_hits.append(str(path))
    if coverage_errors:
        errors.append(f"active-policy awareness missing/duplicated in {len(coverage_errors)} file(s)")
    if versioned_hits:
        errors.append(f"version-specific authority markers remain in {len(versioned_hits)} active file(s)")
    result["coverage_errors"] = coverage_errors
    result["versioned_marker_hits"] = versioned_hits

    critical = [
        tools_root / "bqca-active-policy-listener.sh",
        tools_root / "bqca_active_policy.py",
        tools_root / "bqca-dynamic-validator.py",
        tools_root / "qiskit-design-policy-check.py",
        tools_root / "qiskit-code-policy-check.py",
        tools_root / "bqca-policy-compliance-watcher.py",
        tools_root / "bqca-policy-compliance.sh",
        tools_root / "bqca-policy-doctor.sh",
        tools_root / "bqca-policy-doctor.py",
        tools_root / "qiskit-connector.sh",
        root / "xLaunchpad.sh",
    ]
    syntax_errors: list[str] = []
    permission_errors: list[str] = []
    for path in critical:
        if not path.is_file():
            errors.append(f"critical active-policy component missing: {path}")
            continue
        mode = stat.S_IMODE(path.stat().st_mode)
        if path.suffix in {".sh", ".py"} and not (mode & stat.S_IXUSR):
            permission_errors.append(f"not executable: {path} ({mode:o})")
        if mode & stat.S_IWOTH:
            permission_errors.append(f"world-writable: {path} ({mode:o})")
        syntax_error = bash_syntax(path) if path.suffix == ".sh" else python_syntax(path) if path.suffix == ".py" else None
        if syntax_error:
            syntax_errors.append(f"{path}: {syntax_error}")
    if syntax_errors:
        errors.append(f"syntax errors in {len(syntax_errors)} critical component(s)")
    if permission_errors:
        errors.append(f"permission errors in {len(permission_errors)} critical component(s)")
    result["syntax_errors"] = syntax_errors
    result["permission_errors"] = permission_errors

    connector = tools_root / "qiskit-connector.sh"
    if connector.is_file():
        connector_text = read_text(connector)
        if "BQCA-ACTIVE-POLICY-VALIDATION" not in connector_text or "bqca-active-policy-listener.sh" not in connector_text:
            errors.append("qiskit-connector.sh does not force active-policy synchronization")
        if "qiskit-design-policy-check.py" not in connector_text or "qiskit-code-policy-check.py" not in connector_text:
            errors.append("qiskit-connector.sh does not use the active design/code validators")

    for wrapper in (tools_root / "qiskit-design-policy-check.py", tools_root / "qiskit-code-policy-check.py"):
        if wrapper.is_file() and "bqca-dynamic-validator.py" not in read_text(wrapper):
            errors.append(f"validator wrapper does not delegate to the dynamic validator: {wrapper}")

    launch_text = read_text(root / "xLaunchpad.sh") if (root / "xLaunchpad.sh").is_file() else ""
    if "BQCA-ACTIVE-POLICY-ASSURANCE:BEGIN" not in launch_text:
        errors.append("xLaunchpad.sh does not use version-neutral active-policy assurance")
    if "BQCA-AUTOMATIC-POLICY-COMPLIANCE:BEGIN" not in launch_text:
        errors.append("xLaunchpad.sh does not start automatic policy-compliance reporting")

    report_errors, report_expected, report_current = compliance_report_errors(root, state.policy_sha256, state.contract_sha256)
    if report_errors:
        errors.append(f"missing/stale artifact compliance reports: {len(report_errors)}")
    result["compliance_report_errors"] = report_errors
    result["compliance_reports_expected"] = report_expected
    result["compliance_reports_current"] = report_current

    history_errors = history_hash_failures(root)
    if history_errors:
        errors.append(f"policy-history hash failures: {len(history_errors)}")
    result["history_hash_errors"] = history_errors
    result["errors"] = errors
    result["final_status"] = "PASS" if not errors else "FAIL"
    return result


def format_report(result: dict[str, Any]) -> str:
    version = result.get("active_version", "UNKNOWN")
    lines = [
        "=" * 88,
        "BQCA ACTIVE CENTRAL POLICY ASSURANCE REPORT",
        "=" * 88,
        f"Active policy version       : {version}",
        f"Active policy path          : {result.get('policy_path', 'UNKNOWN')}",
        f"Versioned policy path       : {result.get('versioned_policy_path', 'UNKNOWN')}",
        f"Policy SHA-256              : {result.get('policy_sha256', 'UNKNOWN')}",
        f"Validation-contract SHA-256 : {result.get('contract_sha256', 'UNKNOWN')}",
        f"Custom mode blocks          : {result.get('custom_modes_actual', 0)}/{result.get('custom_modes_expected', 0)}",
        f"Rules / Skills / Tools      : {result.get('rules', 0)} / {result.get('skills', 0)} / {result.get('tools', 0)}",
        f"Compliance reports          : {result.get('compliance_reports_current', 0)}/{result.get('compliance_reports_expected', 0)} current",
        f"Coverage errors             : {len(result.get('coverage_errors', []))}",
        f"Versioned marker hits       : {len(result.get('versioned_marker_hits', []))}",
        f"History hash failures       : {len(result.get('history_hash_errors', []))}",
        f"Syntax errors               : {len(result.get('syntax_errors', []))}",
        f"Permission errors           : {len(result.get('permission_errors', []))}",
        "-" * 88,
    ]
    errors = result.get("errors", [])
    if errors:
        lines.append("ISSUES")
        lines.extend(f"- {item}" for item in errors)
        for item in result.get("compliance_report_errors", [])[:20]:
            lines.append(f"  - {item}")
        lines.append("-" * 88)
    status = result.get("final_status", "FAIL")
    lines.append(f"FINAL ASSURANCE STATUS      : {status}")
    lines.append("=" * 88)
    token = re.sub(r"[^A-Za-z0-9]+", "_", str(version)).strip("_").upper() or "ACTIVE"
    lines.append(f"BQCA_ACTIVE_POLICY_ASSURANCE={status}")
    lines.append(f"BQCA_{token}_POLICY_ASSURANCE={status}")
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description="BQCA version-neutral active-policy doctor")
    parser.add_argument("command", choices=("check", "report", "repair-path", "version"))
    parser.add_argument("--root", type=pathlib.Path, required=True)
    parser.add_argument("--output", type=pathlib.Path)
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args()
    root = args.root.expanduser().resolve()
    if args.command in {"repair-path", "version"}:
        try:
            state = load_active_policy(root, write_cache=True)
        except PolicyError as exc:
            print(f"BQCA_ACTIVE_POLICY_ASSURANCE=FAIL: {exc}", file=sys.stderr)
            return 2
        if args.command == "version":
            print(state.active_version)
        else:
            value = state.registry.get("repair_patch_path")
            if not value:
                print("Registry repair_patch_path is missing", file=sys.stderr)
                return 2
            path = pathlib.Path(str(value))
            if not path.is_absolute():
                path = root / path
            print(path.resolve())
        return 0
    result = check(root)
    report = format_report(result)
    if args.command == "report":
        if args.output:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(report, encoding="utf-8")
        print(report, end="")
    elif not args.quiet or result.get("final_status") != "PASS":
        print(report, end="")
    return 0 if result.get("final_status") == "PASS" else 1


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

# BQCA-BOB-SHELL-V2-DNA:BEGIN
# In a trusted Bob Shell 2.x workspace, bind this component to AGENTS.md, the
# active central BQCA policy, exported menu context, current rules/skills/tools,
# and the offline knowledgebase without changing this component's core purpose.
# BQCA-BOB-SHELL-V2-DNA:END
