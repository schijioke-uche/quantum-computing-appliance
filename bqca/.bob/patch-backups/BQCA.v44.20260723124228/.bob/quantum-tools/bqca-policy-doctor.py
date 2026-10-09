#!/usr/bin/env python3
"""BQCA v45 canonical policy assurance and drift doctor."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import pathlib
import re
import stat
import subprocess
import sys
from datetime import datetime, timezone

VERSION = "v45"
CANONICAL = "BQCA-CANONICAL-PRODUCTION-POLICY-" + VERSION
LEGACY_VERSION = r"(?:v30|v31|v32|v33|v34|v35|v36|v37|v38|v39(?:-update-1)?|v40|v41|v42|v43|v44)"
LEGACY_BLOCK = re.compile(
    rf"(?:<!--\s*BQCA-[^>\n]*{LEGACY_VERSION}:(?:POLICY-)?BEGIN\s*-->|^\s*#\s*BQCA-[^\n]*{LEGACY_VERSION}:(?:POLICY-)?BEGIN\s*$)",
    re.I | re.M,
)
TEXT_EXTENSIONS = {".md", ".txt", ".sh", ".py", ".yaml", ".yml"}


def sha256(path: pathlib.Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def supported_files(root: pathlib.Path) -> tuple[list[pathlib.Path], list[pathlib.Path], list[pathlib.Path]]:
    bob = root / ".bob"
    rules = sorted(path for directory in bob.glob("rules-*") if directory.is_dir() for path in directory.rglob("*") if path.is_file() and path.suffix.lower() in TEXT_EXTENSIONS)
    skills_root = bob / "skills"
    skills = sorted(path for path in skills_root.rglob("*") if path.is_file() and path.suffix.lower() in TEXT_EXTENSIONS) if skills_root.is_dir() else []
    tools_root = bob / "quantum-tools"
    tools = sorted(path for path in tools_root.iterdir() if path.is_file() and path.suffix.lower() in TEXT_EXTENSIONS) if tools_root.is_dir() else []
    return rules, skills, tools


def bash_syntax(path: pathlib.Path) -> str | None:
    result = subprocess.run(["bash", "-n", str(path)], text=True, capture_output=True)
    return None if result.returncode == 0 else (result.stderr.strip() or "bash syntax failure")


def python_syntax(path: pathlib.Path) -> str | None:
    try:
        source = path.read_text(encoding="utf-8")
        compile(source, str(path), "exec")
        return None
    except Exception as exc:
        return str(exc)


def check(root: pathlib.Path) -> dict[str, object]:
    bob = root / ".bob"
    tools = bob / "quantum-tools"
    policy = bob / "BQCA-PRODUCTION-POLICY.md"
    versioned = bob / "BQCA-PRODUCTION-POLICY-v45.md"
    registry_path = bob / "BQCA-ACTIVE-POLICY-REGISTRY.json"
    manifest_path = root / "patches/BQCA/policy-history/BQCA-policy-history-manifest.json"
    custom_modes = bob / "custom_modes.yaml"
    errors: list[str] = []
    checks: dict[str, object] = {}

    expected_policies = {"BQCA-PRODUCTION-POLICY.md", "BQCA-PRODUCTION-POLICY-v45.md"}
    active_policies = {path.name for path in bob.glob("BQCA-*.md") if "POLICY" in path.name.upper()}
    checks["active_policy_files"] = sorted(active_policies)
    if active_policies != expected_policies:
        errors.append(f"active policy files differ from expected set: {sorted(active_policies)}")

    if not policy.is_file() or not versioned.is_file():
        errors.append("canonical policy files are missing")
        policy_hash = ""
    else:
        policy_hash = sha256(policy)
        if policy.read_bytes() != versioned.read_bytes():
            errors.append("stable and versioned policies differ")

    try:
        registry = json.loads(registry_path.read_text(encoding="utf-8"))
    except Exception as exc:
        registry = {}
        errors.append(f"invalid registry JSON: {exc}")
    active = registry.get("active_version") if isinstance(registry, dict) else None
    if active != "v45":
        errors.append("registry active version is not v45")
    if registry.get("policy_sha256") != policy_hash:
        errors.append("registry canonical policy hash mismatch")
    if registry.get("orchestrator_path") != ".bob/quantum-tools/bqca-policy-orchestrator.sh":
        errors.append("registry orchestrator path is incorrect")
    if registry.get("doctor_path") != ".bob/quantum-tools/bqca-policy-doctor.sh":
        errors.append("registry doctor path is incorrect")

    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except Exception as exc:
        manifest = {}
        errors.append(f"invalid history manifest: {exc}")
    history_failures = 0
    for entry in manifest.get("entries", []) if isinstance(manifest, dict) else []:
        archive = root / str(entry.get("archive_path", ""))
        if not archive.is_file() or sha256(archive) != entry.get("sha256"):
            history_failures += 1
            errors.append(f"history manifest mismatch: {archive}")
    checks["history_hash_failures"] = history_failures

    rules, skills, tool_files = supported_files(root)
    begin = CANONICAL + ":BEGIN"
    coverage_errors: list[dict[str, object]] = []
    legacy_count = 0
    for path in [custom_modes, *rules, *skills, *tool_files]:
        text = path.read_text(encoding="utf-8", errors="replace")
        legacy_count += len(LEGACY_BLOCK.findall(text))
        actual = text.count(begin)
        expected = len(re.findall(r"^\s*customInstructions:\s*[>|][+-]?\s*(?:#.*)?$", text, re.M)) if path == custom_modes else 1
        if actual != expected:
            coverage_errors.append({"file": str(path.relative_to(root)), "expected": expected, "actual": actual})
    if legacy_count:
        errors.append(f"active legacy awareness blocks found: {legacy_count}")
    if coverage_errors:
        errors.append(f"canonical awareness coverage errors: {len(coverage_errors)}")
    checks["legacy_blocks"] = legacy_count
    checks["coverage_errors"] = coverage_errors
    checks["custom_mode_blocks"] = len(re.findall(r"^\s*customInstructions:\s*[>|][+-]?\s*(?:#.*)?$", custom_modes.read_text(encoding="utf-8"), re.M))
    checks["rule_files"] = len(rules)
    checks["skill_files"] = len(skills)
    checks["tool_files"] = len(tool_files)

    wrapper_requirements = {
        root / "xLaunchpad.sh": ("BQCA-POLICY-ASSURANCE-v45:BEGIN", "bqca-policy-doctor.sh", "check --quiet"),
        tools / "qiskit-connector.sh": ("BQCA-CANONICAL-ORCHESTRATOR-v45:BEGIN", "BQCA_V45_INTERNAL", "bqca-policy-orchestrator.sh"),
        tools / "qca-code-quality-guard.sh": ("BQCA-CANONICAL-ORCHESTRATOR-v45:BEGIN", "BQCA_V45_INTERNAL", "bqca-policy-orchestrator.sh"),
        tools / "qiskit-v2x-environment.sh": ("BQCA-CANONICAL-ORCHESTRATOR-v45:BEGIN", "BQCA_V45_ORCHESTRATED", "bqca-policy-orchestrator.sh"),
        tools / "qiskit-result-output.sh": ("BQCA-RESULT-CAPTURE-GATE-v45:BEGIN", "BQCA_V45_ORCHESTRATED", "Direct result-capture invocation is prohibited"),
    }
    wrapper_errors: list[str] = []
    for path, required in wrapper_requirements.items():
        if not path.is_file():
            wrapper_errors.append(f"missing wrapper: {path}")
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        for token in required:
            if token not in text:
                wrapper_errors.append(f"{path.name} missing delegation token: {token}")
    for path in sorted(root.glob("bob-quantum-v*.sh")):
        text = path.read_text(encoding="utf-8", errors="replace")
        if "BQCA-CANONICAL-ORCHESTRATOR-v44:BEGIN" not in text:
            wrapper_errors.append(f"{path.name} lacks v44 orchestrator export")
    if wrapper_errors:
        errors.extend(wrapper_errors)
    checks["wrapper_errors"] = wrapper_errors

    syntax_errors: list[str] = []
    executable_targets = [
        root / "xLaunchpad.sh",
        tools / "bqca-policy-orchestrator.sh",
        tools / "bqca-policy-doctor.sh",
        tools / "qiskit-connector.sh",
        tools / "qca-code-quality-guard.sh",
        tools / "qiskit-v2x-environment.sh",
        tools / "qiskit-result-output.sh",
    ] + sorted(root.glob("bob-quantum-v*.sh"))
    for path in executable_targets:
        if not path.is_file():
            syntax_errors.append(f"missing executable: {path}")
            continue
        failure = bash_syntax(path)
        if failure:
            syntax_errors.append(f"{path}: {failure}")
        mode = stat.S_IMODE(path.stat().st_mode)
        if not (mode & stat.S_IXUSR):
            syntax_errors.append(f"not owner-executable: {path}")
        if mode & stat.S_IWOTH:
            syntax_errors.append(f"world-writable executable: {path}")
    for path in tool_files:
        if path.suffix.lower() == ".py":
            failure = python_syntax(path)
            if failure:
                syntax_errors.append(f"{path}: {failure}")
    if syntax_errors:
        errors.extend(syntax_errors)
    checks["syntax_permission_errors"] = syntax_errors

    history_dir = root / "patches/BQCA/policy-history"
    if str(history_dir.resolve()).startswith(str(bob.resolve()) + os.sep):
        errors.append("historical policy directory is inside active .bob context")
    checks["historical_context_isolated"] = not str(history_dir.resolve()).startswith(str(bob.resolve()) + os.sep)

    checks["policy_sha256"] = policy_hash
    checks["errors"] = errors
    checks["status"] = "PASS" if not errors else "FAIL"
    checks["checked_utc"] = datetime.now(timezone.utc).isoformat()
    return checks


def format_report(result: dict[str, object]) -> str:
    width = 88
    errors = result.get("errors", [])
    lines = [
        "=" * width,
        "BQCA v45 CANONICAL POLICY ASSURANCE REPORT",
        "=" * width,
        f"Assessment time             : {result.get('checked_utc')}",
        f"Canonical policy SHA-256    : {result.get('policy_sha256')}",
        f"Active policies             : {', '.join(result.get('active_policy_files', []))}",
        f"Custom mode blocks          : {result.get('custom_mode_blocks')}",
        f"Rules / Skills / Tools      : {result.get('rule_files')} / {result.get('skill_files')} / {result.get('tool_files')}",
        f"Legacy active blocks        : {result.get('legacy_blocks')}",
        f"History hash failures       : {result.get('history_hash_failures')}",
        f"Coverage errors             : {len(result.get('coverage_errors', []))}",
        f"Wrapper errors              : {len(result.get('wrapper_errors', []))}",
        f"Syntax/permission errors    : {len(result.get('syntax_permission_errors', []))}",
        f"Historical context isolated : {'YES' if result.get('historical_context_isolated') else 'NO'}",
        "-" * width,
    ]
    if errors:
        lines.append("ISSUES")
        for error in errors:
            lines.append(f"- {error}")
        lines.append("-" * width)
    lines.append(f"FINAL ASSURANCE STATUS      : {result.get('status')}")
    lines.append("=" * width)
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description="BQCA v45 policy doctor")
    parser.add_argument("command", choices=("check", "report"))
    parser.add_argument("--root", type=pathlib.Path, required=True)
    parser.add_argument("--output", type=pathlib.Path)
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args()
    result = check(args.root.resolve())
    report = format_report(result)
    if args.command == "report" or args.output:
        output = args.output or args.root / ".bob/patches-applied/BQCA.v44-assurance-report.txt"
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(report, encoding="utf-8")
    if not args.quiet:
        print(report, end="")
    return 0 if result["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
# BQCA-CANONICAL-PRODUCTION-POLICY-v45:BEGIN
# The sole active BQCA policy is .bob/BQCA-PRODUCTION-POLICY.md (v45).
# Route all public design, code, execution, result, and completion paths through
# bqca-policy-orchestrator.sh. Open Plan uses SamplerV2 or EstimatorV2 job mode
# according to workload semantics and must never use Session.
# BQCA-CANONICAL-PRODUCTION-POLICY-v45:END
