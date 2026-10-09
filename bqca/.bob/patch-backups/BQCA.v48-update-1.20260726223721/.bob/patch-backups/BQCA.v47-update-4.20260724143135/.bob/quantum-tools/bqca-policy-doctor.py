#!/usr/bin/env python3
"""BQCA v47 independent policy assurance and drift detector."""
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

CANONICAL = "BQCA-CANONICAL-PRODUCTION-POLICY-v47"
LEGACY_CANONICAL = re.compile(
    r"(?:<!--\s*BQCA-CANONICAL-PRODUCTION-POLICY-v(?:30|31|32|33|34|35|36|37|38|39|40|41|42|43|44|45|46):BEGIN\s*-->|"
    r"^\s*#\s*BQCA-CANONICAL-PRODUCTION-POLICY-v(?:30|31|32|33|34|35|36|37|38|39|40|41|42|43|44|45|46):BEGIN\s*$)",
    re.I | re.M,
)
STALE_RUNTIME = re.compile(
    r"BQCA-(?:POLICY-ASSURANCE|DIRECT-EXECUTION-EXPORT|CANONICAL-ORCHESTRATOR|DIRECT-EXECUTION-DELEGATION|RESULT-CAPTURE-GATE)-v(?:44|45|46):BEGIN"
)
EXTENSIONS = {".md", ".txt", ".sh", ".py", ".yaml", ".yml"}


def sha256(path: pathlib.Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def supported_files(root: pathlib.Path):
    bob = root / ".bob"
    rules = sorted(
        path for directory in bob.glob("rules-*") if directory.is_dir()
        for path in directory.rglob("*") if path.is_file() and path.suffix.lower() in EXTENSIONS
    )
    skills_root = bob / "skills"
    skills = sorted(
        path for path in skills_root.rglob("*") if path.is_file() and path.suffix.lower() in EXTENSIONS
    ) if skills_root.is_dir() else []
    tools_root = bob / "quantum-tools"
    tools = sorted(
        path for path in tools_root.iterdir() if path.is_file() and path.suffix.lower() in EXTENSIONS
    ) if tools_root.is_dir() else []
    return rules, skills, tools


def bash_syntax(path: pathlib.Path) -> str | None:
    result = subprocess.run(["bash", "-n", str(path)], text=True, capture_output=True)
    return None if result.returncode == 0 else result.stderr.strip()


def python_syntax(path: pathlib.Path) -> str | None:
    try:
        compile(path.read_text(encoding="utf-8", errors="replace"), str(path), "exec")
        return None
    except Exception as exc:
        return str(exc)


def check(root: pathlib.Path) -> dict[str, object]:
    bob = root / ".bob"
    tools = bob / "quantum-tools"
    policy = bob / "BQCA-PRODUCTION-POLICY.md"
    versioned = bob / "BQCA-PRODUCTION-POLICY-v47.md"
    registry_path = bob / "BQCA-ACTIVE-POLICY-REGISTRY.json"
    manifest_path = root / "patches/BQCA/policy-history/BQCA-policy-history-manifest.json"
    custom_modes = bob / "custom_modes.yaml"
    errors: list[str] = []
    result: dict[str, object] = {}

    expected_policies = {"BQCA-PRODUCTION-POLICY.md", "BQCA-PRODUCTION-POLICY-v47.md"}
    active_policies = {path.name for path in bob.glob("BQCA-*POLICY*.md")}
    result["active_policy_files"] = sorted(active_policies)
    if active_policies != expected_policies:
        errors.append(f"active policy files differ from expected set: {sorted(active_policies)}")

    policy_hash = ""
    if not policy.is_file() or not versioned.is_file():
        errors.append("canonical v47 policy files are missing")
    else:
        policy_hash = sha256(policy)
        if policy.read_bytes() != versioned.read_bytes():
            errors.append("stable and versioned v47 policies differ")

    try:
        registry = json.loads(registry_path.read_text(encoding="utf-8"))
    except Exception as exc:
        registry = {}
        errors.append(f"invalid registry JSON: {exc}")
    if registry.get("active_version") != "v47":
        errors.append("registry active_version is not v47")
    if registry.get("active_policy_path") != ".bob/BQCA-PRODUCTION-POLICY.md":
        errors.append("registry active policy path is incorrect")
    if registry.get("versioned_policy_path") != ".bob/BQCA-PRODUCTION-POLICY-v47.md":
        errors.append("registry versioned policy path is incorrect")
    if registry.get("policy_sha256") != policy_hash:
        errors.append("registry canonical policy hash mismatch")
    if registry.get("direct_execution_path") != ".bob/quantum-tools/bqca-direct-execution.sh":
        errors.append("registry direct execution path is incorrect")
    if registry.get("orchestrator_path") != ".bob/quantum-tools/bqca-policy-orchestrator.sh":
        errors.append("registry orchestrator_path is incorrect")
    if registry.get("doctor_path") != ".bob/quantum-tools/bqca-policy-doctor.sh":
        errors.append("registry doctor_path is incorrect")
    active = registry.get("active_authority", {}) if isinstance(registry, dict) else {}
    if active.get("version") != "v47":
        errors.append("registry active_authority version is not v47")

    history_failures = 0
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except Exception as exc:
        manifest = {}
        errors.append(f"invalid policy-history manifest: {exc}")
    for entry in manifest.get("entries", []) if isinstance(manifest, dict) else []:
        archive = root / str(entry.get("archive_path", ""))
        if not archive.is_file() or sha256(archive) != entry.get("sha256"):
            history_failures += 1
            errors.append(f"history manifest mismatch: {archive}")
    result["history_hash_failures"] = history_failures

    rules, skills, tool_files = supported_files(root)
    files = [custom_modes, *rules, *skills, *tool_files]
    begin = CANONICAL + ":BEGIN"
    coverage_errors = []
    legacy_count = 0
    for path in files:
        text = path.read_text(encoding="utf-8", errors="replace")
        legacy_count += len(LEGACY_CANONICAL.findall(text))
        actual = text.count(begin)
        if path == custom_modes:
            expected = len(re.findall(r"^\s*customInstructions:\s*[>|][+-]?\s*(?:#.*)?$", text, re.M))
        else:
            expected = 1
        if actual != expected:
            coverage_errors.append({"file": str(path.relative_to(root)), "expected": expected, "actual": actual})
    if legacy_count:
        errors.append(f"active v30-v46 canonical awareness blocks found: {legacy_count}")
    if coverage_errors:
        errors.append(f"v47 awareness coverage errors: {len(coverage_errors)}")
    result["legacy_blocks"] = legacy_count
    result["coverage_errors"] = coverage_errors
    result["custom_mode_blocks"] = len(re.findall(
        r"^\s*customInstructions:\s*[>|][+-]?\s*(?:#.*)?$",
        custom_modes.read_text(encoding="utf-8", errors="replace"), re.M,
    ))
    result["rule_files"] = len(rules)
    result["skill_files"] = len(skills)
    result["tool_files"] = len(tool_files)

    stale_hits = []
    scan_paths = [custom_modes, root / "xLaunchpad.sh", *root.glob("bob-quantum-v*.sh"), *rules, *skills, *tool_files]
    for path in scan_paths:
        text = path.read_text(encoding="utf-8", errors="replace")
        if STALE_RUNTIME.search(text):
            stale_hits.append(str(path.relative_to(root)))
    if stale_hits:
        errors.append(f"stale v44-v46 runtime markers remain: {len(stale_hits)}")
    result["stale_runtime_files"] = stale_hits

    wrapper_errors = []
    requirements = {
        root / "xLaunchpad.sh": ("BQCA-POLICY-ASSURANCE-v47:BEGIN", "bqca-policy-doctor.sh", "check --quiet"),
        tools / "qiskit-v2x-environment.sh": ("BQCA-DIRECT-EXECUTION-DELEGATION-v47:BEGIN", "bqca-direct-execution.sh"),
        tools / "bqca-direct-execution.sh": ("tee", "output.txt", "formal-run", "PIPESTATUS"),
        tools / "bqca-policy-doctor.sh": ("patch-BQCA.v47-update-2.sh", "BQCA v47 policy doctor"),
        tools / "bqca-policy-orchestrator.sh": ("BQCA-PRODUCTION-POLICY-v47.md", "BQCA_V47_INTERNAL"),
    }
    for path, tokens in requirements.items():
        if not path.is_file():
            wrapper_errors.append(f"missing wrapper: {path}")
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        for token in tokens:
            if token not in text:
                wrapper_errors.append(f"{path.name} missing token: {token}")
    for path in sorted(root.glob("bob-quantum-v*.sh")):
        text = path.read_text(encoding="utf-8", errors="replace")
        if "BQCA-DIRECT-EXECUTION-EXPORT-v47:BEGIN" not in text:
            wrapper_errors.append(f"{path.name} lacks v47 direct-execution export")
    if wrapper_errors:
        errors.extend(wrapper_errors)
    result["wrapper_errors"] = wrapper_errors

    syntax_errors = []
    executable_targets = [
        root / "xLaunchpad.sh",
        tools / "bqca-direct-execution.sh",
        tools / "bqca-direct-execute.sh",
        tools / "bqca-policy-doctor.sh",
        tools / "bqca-policy-orchestrator.sh",
        tools / "qiskit-v2x-environment.sh",
        tools / "qiskit-connector.sh",
        tools / "qca-code-quality-guard.sh",
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
    result["syntax_permission_errors"] = syntax_errors

    history_dir = root / "patches/BQCA/policy-history"
    isolated = not str(history_dir.resolve()).startswith(str(bob.resolve()) + os.sep)
    if not isolated:
        errors.append("historical policy directory is inside active .bob context")
    result["historical_context_isolated"] = isolated

    result["policy_sha256"] = policy_hash
    result["errors"] = errors
    result["status"] = "PASS" if not errors else "FAIL"
    result["checked_utc"] = datetime.now(timezone.utc).isoformat()
    return result


def format_report(result: dict[str, object]) -> str:
    width = 88
    lines = [
        "=" * width,
        "BQCA v47 CANONICAL POLICY ASSURANCE REPORT",
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
        f"Stale runtime files         : {len(result.get('stale_runtime_files', []))}",
        f"Syntax/permission errors    : {len(result.get('syntax_permission_errors', []))}",
        f"Historical context isolated : {'YES' if result.get('historical_context_isolated') else 'NO'}",
        "-" * width,
    ]
    errors = result.get("errors", [])
    if errors:
        lines.append("ISSUES")
        lines.extend(f"- {error}" for error in errors)
        lines.append("-" * width)
    lines.append(f"FINAL ASSURANCE STATUS      : {result.get('status')}")
    lines.append("=" * width)
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description="BQCA v47 policy doctor")
    parser.add_argument("command", choices=("check", "report"))
    parser.add_argument("--root", type=pathlib.Path, required=True)
    parser.add_argument("--output", type=pathlib.Path)
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args()
    result = check(args.root.resolve())
    report = format_report(result)
    if args.command == "report" or args.output:
        output = args.output or args.root / ".bob/patches-applied/BQCA.v47-assurance-report.txt"
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(report, encoding="utf-8")
    if not args.quiet:
        print(report, end="")
    print(f"BQCA_V47_POLICY_ASSURANCE={result['status']}", file=sys.stderr if result['status'] != 'PASS' else sys.stdout)
    return 0 if result["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
# BQCA-CANONICAL-PRODUCTION-POLICY-v47:BEGIN
# The sole active policy is .bob/BQCA-PRODUCTION-POLICY.md (v47).
# Direct execution streams complete stdout/stderr live and writes the exact
# professional report to <source-stem>-result-output.txt and output.txt.
# REAL_QPU results put the actual Job ID on line one. Direct contract gaps
# are warnings; formal orchestration is explicit opt-in.
# BQCA-CANONICAL-PRODUCTION-POLICY-v47:END
