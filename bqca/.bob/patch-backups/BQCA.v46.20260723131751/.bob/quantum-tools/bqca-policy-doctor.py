#!/usr/bin/env python3
"""BQCA v46 direct-execution policy assurance and drift doctor."""
from __future__ import annotations
import argparse, hashlib, json, os, pathlib, re, stat, subprocess
from datetime import datetime, timezone

VERSION = "v46"
CANONICAL = "BQCA-CANONICAL-PRODUCTION-POLICY-v46"
LEGACY_VERSION = r"(?:v30|v31|v32|v33|v34|v35|v36|v37|v38|v39(?:-update-1)?|v40|v41|v42|v43|v44|v45)"
LEGACY_BLOCK = re.compile(rf"(?:<!--\s*BQCA-[^>\n]*{LEGACY_VERSION}:(?:POLICY-)?BEGIN\s*-->|^\s*#\s*BQCA-[^\n]*{LEGACY_VERSION}:(?:POLICY-)?BEGIN\s*$)", re.I | re.M)
TEXT_EXTENSIONS = {".md", ".txt", ".sh", ".py", ".yaml", ".yml"}


def sha256(path: pathlib.Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def supported_files(root: pathlib.Path):
    bob = root / ".bob"
    rules = sorted(path for directory in bob.glob("rules-*") if directory.is_dir() for path in directory.rglob("*") if path.is_file() and path.suffix.lower() in TEXT_EXTENSIONS)
    skills_root = bob / "skills"
    skills = sorted(path for path in skills_root.rglob("*") if path.is_file() and path.suffix.lower() in TEXT_EXTENSIONS) if skills_root.is_dir() else []
    tools_root = bob / "quantum-tools"
    tools = sorted(path for path in tools_root.iterdir() if path.is_file() and path.suffix.lower() in TEXT_EXTENSIONS) if tools_root.is_dir() else []
    return rules, skills, tools


def check(root: pathlib.Path) -> dict[str, object]:
    bob = root / ".bob"
    tools = bob / "quantum-tools"
    policy = bob / "BQCA-PRODUCTION-POLICY.md"
    versioned = bob / "BQCA-PRODUCTION-POLICY-v46.md"
    registry_path = bob / "BQCA-ACTIVE-POLICY-REGISTRY.json"
    manifest_path = root / "patches/BQCA/policy-history/BQCA-policy-history-manifest.json"
    custom = bob / "custom_modes.yaml"
    errors: list[str] = []
    checks: dict[str, object] = {}

    active_policies = {p.name for p in bob.glob("BQCA-*.md") if "POLICY" in p.name.upper()}
    expected = {"BQCA-PRODUCTION-POLICY.md", "BQCA-PRODUCTION-POLICY-v46.md"}
    if active_policies != expected:
        errors.append(f"active policy files differ from expected set: {sorted(active_policies)}")
    checks["active_policy_files"] = sorted(active_policies)

    policy_hash = ""
    if not policy.is_file() or not versioned.is_file():
        errors.append("canonical policy files are missing")
    else:
        policy_hash = sha256(policy)
        if policy.read_bytes() != versioned.read_bytes():
            errors.append("stable and versioned policies differ")
        ptext = policy.read_text(encoding="utf-8", errors="replace")
        for token in ("Execution decision matrix", "bqca-direct-execution.sh", "output.txt", "orchestrator is explicit and optional", "NON-BLOCKING"):
            if token.lower() not in ptext.lower():
                errors.append(f"canonical v46 token missing: {token}")
        for forbidden in ("Public validation and execution wrappers must delegate through the canonical orchestrator", "Direct invocation of the result-capture layer is prohibited"):
            if forbidden.lower() in ptext.lower():
                errors.append(f"conflicting orchestrator-only policy remains: {forbidden}")

    try:
        registry = json.loads(registry_path.read_text(encoding="utf-8"))
    except Exception as exc:
        registry = {}
        errors.append(f"invalid registry JSON: {exc}")
    active = registry.get("active_authority", {}) if isinstance(registry, dict) else {}
    if active.get("version") != "v46":
        errors.append("registry active authority is not v46")
    if active.get("policy_sha256") != policy_hash:
        errors.append("registry canonical policy hash mismatch")
    if active.get("default_execution") != ".bob/quantum-tools/bqca-direct-execution.sh":
        errors.append("registry default direct-execution path is incorrect")
    if active.get("formal_orchestrator") != ".bob/quantum-tools/bqca-policy-orchestrator.sh":
        errors.append("registry formal orchestrator path is incorrect")

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
    coverage_errors = []
    legacy_count = 0
    for path in [custom, *rules, *skills, *tool_files]:
        text = path.read_text(encoding="utf-8", errors="replace")
        legacy_count += len(LEGACY_BLOCK.findall(text))
        actual = len(re.findall(rf"(?m)^\s*(?:#\s*|<!--\s*){re.escape(begin)}(?:\s*-->)?\s*$", text))
        expected_count = len(re.findall(r"^\s*customInstructions:\s*[>|][+-]?\s*(?:#.*)?$", text, re.M)) if path == custom else 1
        if actual != expected_count:
            coverage_errors.append({"file": str(path.relative_to(root)), "expected": expected_count, "actual": actual})
    if legacy_count:
        errors.append(f"active legacy awareness blocks found: {legacy_count}")
    if coverage_errors:
        errors.append(f"canonical awareness coverage errors: {len(coverage_errors)}")
    checks["legacy_blocks"] = legacy_count
    checks["coverage_errors"] = coverage_errors
    checks["custom_mode_blocks"] = len(re.findall(r"^\s*customInstructions:\s*[>|][+-]?\s*(?:#.*)?$", custom.read_text(encoding="utf-8"), re.M))
    checks["rule_files"] = len(rules)
    checks["skill_files"] = len(skills)
    checks["tool_files"] = len(tool_files)

    wrapper_requirements = {
        root / "xLaunchpad.sh": ("BQCA-POLICY-ASSURANCE-v46:BEGIN", "bqca-direct-execution.sh"),
        tools / "bqca-direct-execution.sh": ("formal-run", "decision-matrix", "BQCA_EXECUTION_METHOD=DIRECT"),
        tools / "bqca-direct-execute.sh": ("bqca-direct-execution.sh", "exec \"$DIRECT\""),
        tools / "qiskit-v2x-environment.sh": ("BQCA-DIRECT-EXECUTION-v46:BEGIN", "DIRECT_EXECUTION_TOOL"),
        tools / "qiskit-connector.sh": ("BQCA-EXECUTION-ROUTING-v46:BEGIN", "--run-code-formal"),
        tools / "qca-code-quality-guard.sh": ("BQCA-EXECUTION-ROUTING-v46:BEGIN", "--formal-execute"),
        tools / "qiskit-result-output.sh": ("BQCA-CANONICAL-PRODUCTION-POLICY-v46:BEGIN", "python3 -u"),
        tools / "qiskit-result-output.py": ("output.txt", "sys.stdout.buffer.write", "NON-BLOCKING"),
        tools / "bqca-policy-orchestrator.sh": ("optional formal policy orchestrator", "BQCA_V46_FORMAL"),
    }
    wrapper_errors = []
    for path, required in wrapper_requirements.items():
        if not path.is_file():
            wrapper_errors.append(f"missing wrapper: {path}")
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        for token in required:
            if token not in text:
                wrapper_errors.append(f"{path.name} missing v46 token: {token}")
    if wrapper_errors:
        errors.extend(wrapper_errors)
    checks["wrapper_errors"] = wrapper_errors

    conflict_hits = []
    conflict_patterns = (
        "Direct result-capture invocation is prohibited",
        "Public validation and execution wrappers must delegate through the canonical orchestrator",
        "All public design, code, and execution routes must delegate through the canonical orchestrator",
        "use bqca-policy-orchestrator.sh as the completion gate",
    )
    for path in [custom, *rules, *skills, *tool_files]:
        if path.name == "bqca-policy-doctor.py":
            continue
        text = path.read_text(encoding="utf-8", errors="replace").lower()
        for phrase in conflict_patterns:
            if phrase.lower() in text:
                conflict_hits.append(f"{path.relative_to(root)}: {phrase}")
    if conflict_hits:
        errors.extend(conflict_hits)
    checks["conflict_hits"] = conflict_hits

    executable_targets = [
        root / "xLaunchpad.sh", tools / "bqca-direct-execution.sh", tools / "bqca-direct-execute.sh", tools / "bqca-policy-orchestrator.sh",
        tools / "bqca-policy-doctor.sh", tools / "qiskit-connector.sh", tools / "qca-code-quality-guard.sh",
        tools / "qiskit-v2x-environment.sh", tools / "qiskit-result-output.sh",
    ] + sorted(root.glob("bob-quantum-v*.sh"))
    syntax_errors = []
    for path in executable_targets:
        if not path.is_file():
            syntax_errors.append(f"missing executable: {path}")
            continue
        result = subprocess.run(["bash", "-n", str(path)], text=True, capture_output=True)
        if result.returncode:
            syntax_errors.append(f"{path}: {result.stderr.strip()}")
        mode = stat.S_IMODE(path.stat().st_mode)
        if not (mode & stat.S_IXUSR):
            syntax_errors.append(f"not owner-executable: {path}")
        if mode & stat.S_IWOTH:
            syntax_errors.append(f"world-writable executable: {path}")
    for path in tool_files:
        if path.suffix.lower() == ".py":
            try:
                compile(path.read_text(encoding="utf-8"), str(path), "exec")
            except Exception as exc:
                syntax_errors.append(f"{path}: {exc}")
    if syntax_errors:
        errors.extend(syntax_errors)
    checks["syntax_permission_errors"] = syntax_errors

    history_dir = root / "patches/BQCA/policy-history"
    checks["historical_context_isolated"] = not str(history_dir.resolve()).startswith(str(bob.resolve()) + os.sep)
    if not checks["historical_context_isolated"]:
        errors.append("historical policy directory is inside active .bob context")

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
        "BQCA v46 DIRECT EXECUTION POLICY ASSURANCE REPORT",
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
        f"Conflicting policy hits     : {len(result.get('conflict_hits', []))}",
        f"Syntax/permission errors    : {len(result.get('syntax_permission_errors', []))}",
        f"Historical context isolated : {'YES' if result.get('historical_context_isolated') else 'NO'}",
        "-" * width,
    ]
    if errors:
        lines.append("ISSUES")
        lines.extend(f"- {error}" for error in errors)
        lines.append("-" * width)
    lines.append(f"FINAL ASSURANCE STATUS      : {result.get('status')}")
    lines.append("=" * width)
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description="BQCA v46 policy doctor")
    parser.add_argument("command", choices=("check", "report"))
    parser.add_argument("--root", type=pathlib.Path, required=True)
    parser.add_argument("--output", type=pathlib.Path)
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args()
    result = check(args.root.resolve())
    report = format_report(result)
    if args.command == "report" or args.output:
        output = args.output or args.root / ".bob/patches-applied/BQCA.v46-assurance-report.txt"
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(report, encoding="utf-8")
    if not args.quiet:
        print(report, end="")
    return 0 if result["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())

# BQCA-CANONICAL-PRODUCTION-POLICY-v46:BEGIN
# The v46 doctor verifies direct execution routing, formal opt-in orchestration,
# live terminal output, and both result-output files.
# BQCA-CANONICAL-PRODUCTION-POLICY-v46:END
