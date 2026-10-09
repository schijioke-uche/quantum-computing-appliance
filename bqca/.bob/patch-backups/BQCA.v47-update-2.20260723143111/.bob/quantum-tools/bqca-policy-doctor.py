#!/usr/bin/env python3
"""BQCA v47 semantic policy assurance, reporting, and safe repair."""
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
from typing import Any

VERSION = "v47"
REQUIRED_ENV_CAPABILITIES = {
    "ensure", "check", "python", "run", "run-notebook", "hello-world",
    "hello-world-if-present", "exec", "environment-path", "python-path",
    "activation-command",
}
REQUIRED_PATHS = {
    "orchestrator_path": ".bob/quantum-tools/bqca-policy-orchestrator.sh",
    "doctor_path": ".bob/quantum-tools/bqca-policy-doctor.sh",
}
EXECUTABLES = (
    "xLaunchpad.sh",
    ".bob/quantum-tools/bqca-policy-orchestrator.sh",
    ".bob/quantum-tools/bqca-policy-doctor.sh",
    ".bob/quantum-tools/qiskit-connector.sh",
    ".bob/quantum-tools/qca-code-quality-guard.sh",
    ".bob/quantum-tools/qiskit-v2x-environment.sh",
    ".bob/quantum-tools/qiskit-result-output.sh",
    ".bob/quantum-tools/bqca-direct-execute.sh",
)


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def sha256(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def run_syntax(path: pathlib.Path) -> str | None:
    result = subprocess.run(["bash", "-n", str(path)], text=True, capture_output=True)
    if result.returncode == 0:
        return None
    return result.stderr.strip() or "bash syntax validation failed"


def python_syntax(path: pathlib.Path) -> str | None:
    try:
        compile(path.read_text(encoding="utf-8"), str(path), "exec")
        return None
    except Exception as exc:  # pragma: no cover - diagnostic path
        return str(exc)


def parse_usage_capabilities(text: str) -> set[str]:
    capabilities: set[str] = set()
    pattern = re.compile(r"qiskit-v2x-environment\.sh\s+([a-z][a-z0-9-]*)", re.I)
    capabilities.update(match.group(1) for match in pattern.finditer(text))

    # Also parse case labels semantically without requiring a particular dispatch layout.
    for label_group in re.findall(r"^\s*([a-z0-9_-]+(?:\|[a-z0-9_-]+)*)\)\s*$", text, re.M | re.I):
        capabilities.update(label_group.split("|"))
    return capabilities


def load_json(path: pathlib.Path, errors: list[str], label: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
        if not isinstance(value, dict):
            raise ValueError("top-level value is not an object")
        return value
    except Exception as exc:
        errors.append(f"invalid {label}: {exc}")
        return {}


def count_surfaces(root: pathlib.Path) -> dict[str, int]:
    bob = root / ".bob"
    rules = [p for d in bob.glob("rules-*") if d.is_dir() for p in d.rglob("*") if p.is_file()]
    skills_root = bob / "skills"
    tools_root = bob / "quantum-tools"
    skills = [p for p in skills_root.rglob("*") if p.is_file()] if skills_root.is_dir() else []
    tools = [p for p in tools_root.iterdir() if p.is_file()] if tools_root.is_dir() else []
    modes = 0
    custom_modes = bob / "custom_modes.yaml"
    if custom_modes.is_file():
        text = custom_modes.read_text(encoding="utf-8", errors="replace")
        modes = len(re.findall(r"^\s*-\s+(?:slug|name):", text, re.M))
        # The production file is name-first; avoid double counting slug-first documents.
        name_count = len(re.findall(r"^\s*-\s+name:", text, re.M))
        if name_count:
            modes = name_count
    return {"modes": modes, "rules": len(rules), "skills": len(skills), "tools": len(tools)}


def check(root: pathlib.Path) -> dict[str, Any]:
    bob = root / ".bob"
    tools = bob / "quantum-tools"
    policy = bob / "BQCA-PRODUCTION-POLICY.md"
    versioned = bob / "BQCA-PRODUCTION-POLICY-v47.md"
    registry_path = bob / "BQCA-ACTIVE-POLICY-REGISTRY.json"
    errors: list[str] = []
    warnings: list[str] = []
    details: dict[str, Any] = {}

    if not policy.is_file():
        errors.append(f"canonical policy is missing: {policy}")
        policy_hash = ""
    else:
        policy_hash = sha256(policy)

    if not versioned.is_file():
        errors.append(f"versioned v47 policy is missing: {versioned}")
    elif policy.is_file() and policy.read_bytes() != versioned.read_bytes():
        errors.append("stable and versioned v47 policies differ")

    registry = load_json(registry_path, errors, "active policy registry JSON")
    if registry.get("active_version") != VERSION:
        errors.append(f"registry active_version is not {VERSION}")
    if registry.get("active_policy_path") != ".bob/BQCA-PRODUCTION-POLICY.md":
        errors.append("registry active policy path is incorrect")
    if registry.get("versioned_policy_path") != ".bob/BQCA-PRODUCTION-POLICY-v47.md":
        errors.append("registry versioned policy path is incorrect")
    if registry.get("policy_sha256") != policy_hash:
        errors.append("registry canonical policy hash mismatch")
    for field, expected in REQUIRED_PATHS.items():
        if registry.get(field) != expected:
            errors.append(f"registry {field} is incorrect")

    syntax_errors: list[str] = []
    permission_errors: list[str] = []
    executable_paths = [root / rel for rel in EXECUTABLES]
    executable_paths.extend(sorted(root.glob("bob-quantum-v*.sh")))
    seen: set[pathlib.Path] = set()
    for path in executable_paths:
        if path in seen:
            continue
        seen.add(path)
        if not path.is_file():
            errors.append(f"required executable is missing: {path.relative_to(root)}")
            continue
        failure = run_syntax(path)
        if failure:
            syntax_errors.append(f"{path.relative_to(root)}: {failure}")
        mode = stat.S_IMODE(path.stat().st_mode)
        if not (mode & stat.S_IXUSR):
            permission_errors.append(f"not owner-executable: {path.relative_to(root)}")
        if mode & stat.S_IWOTH:
            permission_errors.append(f"world-writable executable: {path.relative_to(root)}")
    errors.extend(syntax_errors)
    errors.extend(permission_errors)
    details["syntax_errors"] = syntax_errors
    details["permission_errors"] = permission_errors

    python_errors: list[str] = []
    for path in tools.glob("*.py"):
        failure = python_syntax(path)
        if failure:
            python_errors.append(f"{path.relative_to(root)}: {failure}")
    errors.extend(python_errors)
    details["python_errors"] = python_errors

    env_tool = tools / "qiskit-v2x-environment.sh"
    observed_capabilities: set[str] = set()
    if env_tool.is_file():
        observed_capabilities = parse_usage_capabilities(env_tool.read_text(encoding="utf-8", errors="replace"))
        missing = sorted(REQUIRED_ENV_CAPABILITIES - observed_capabilities)
        if missing:
            errors.append("qiskit-v2x-environment.sh is missing public capabilities: " + ", ".join(missing))
    details["qiskit_environment_capabilities"] = sorted(observed_capabilities)

    launchpad = root / "xLaunchpad.sh"
    if launchpad.is_file():
        launch_text = launchpad.read_text(encoding="utf-8", errors="replace")
        for token in ("bqca-policy-doctor.sh", "check --quiet", "BQCA_ACTIVE_POLICY"):
            if token not in launch_text:
                errors.append(f"xLaunchpad.sh is missing assurance capability: {token}")

    custom_modes = bob / "custom_modes.yaml"
    duplicate_slugs: list[str] = []
    if custom_modes.is_file():
        text = custom_modes.read_text(encoding="utf-8", errors="replace")
        slugs = re.findall(r"^\s+slug:\s*['\"]?([^'\"\s#]+)", text, re.M)
        duplicate_slugs = sorted({slug for slug in slugs if slugs.count(slug) > 1})
        if duplicate_slugs:
            warnings.append("duplicate custom-mode slugs: " + ", ".join(duplicate_slugs))
    else:
        errors.append("custom_modes.yaml is missing")
    details["duplicate_mode_slugs"] = duplicate_slugs

    # v45 awareness blocks are intentionally accepted as compatible metadata. v43 and older
    # active policy blocks are warnings, not hard failures, unless syntax or execution is broken.
    legacy_awareness = 0
    for path in [p for d in bob.glob("rules-*") if d.is_dir() for p in d.rglob("*") if p.is_file()]:
        text = path.read_text(encoding="utf-8", errors="replace")
        legacy_awareness += len(re.findall(r"BQCA-CANONICAL-PRODUCTION-POLICY-v(?:30|31|32|33|34|35|36|37|38|39|40|41|42|43):BEGIN", text))
    if legacy_awareness:
        warnings.append(f"legacy awareness blocks detected: {legacy_awareness}")
    details["legacy_awareness_blocks"] = legacy_awareness

    details["surfaces"] = count_surfaces(root)
    details["policy_sha256"] = policy_hash
    return {
        "version": VERSION,
        "root": str(root),
        "checked_at": utc_now(),
        "ok": not errors,
        "errors": errors,
        "warnings": warnings,
        "checks": details,
    }


def write_report(result: dict[str, Any], output: pathlib.Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.suffix.lower() == ".json":
        output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
        return
    lines = [
        "BQCA v47 Policy Assurance Report",
        "=" * 33,
        f"Root: {result['root']}",
        f"Checked: {result['checked_at']}",
        f"Status: {'PASS' if result['ok'] else 'FAIL'}",
        "",
    ]
    surfaces = result.get("checks", {}).get("surfaces", {})
    if surfaces:
        lines.append("Surfaces: " + " ".join(f"{key}={value}" for key, value in surfaces.items()))
        lines.append("")
    lines.append("Errors:")
    lines.extend([f"  - {item}" for item in result["errors"]] or ["  - none"])
    lines.append("")
    lines.append("Warnings:")
    lines.extend([f"  - {item}" for item in result["warnings"]] or ["  - none"])
    lines.append("")
    lines.append("Qiskit environment capabilities:")
    capabilities = result.get("checks", {}).get("qiskit_environment_capabilities", [])
    lines.extend([f"  - {item}" for item in capabilities] or ["  - none detected"])
    output.write_text("\n".join(lines) + "\n", encoding="utf-8")


def repair(root: pathlib.Path) -> dict[str, Any]:
    bob = root / ".bob"
    policy = bob / "BQCA-PRODUCTION-POLICY.md"
    versioned = bob / "BQCA-PRODUCTION-POLICY-v47.md"
    registry_path = bob / "BQCA-ACTIVE-POLICY-REGISTRY.json"

    if not policy.is_file():
        raise RuntimeError(f"cannot repair without canonical policy: {policy}")
    versioned.write_bytes(policy.read_bytes())

    registry = {}
    if registry_path.is_file():
        try:
            loaded = json.loads(registry_path.read_text(encoding="utf-8"))
            if isinstance(loaded, dict):
                registry = loaded
        except Exception:
            registry = {}
    registry.update({
        "active_version": VERSION,
        "active_policy_path": ".bob/BQCA-PRODUCTION-POLICY.md",
        "versioned_policy_path": ".bob/BQCA-PRODUCTION-POLICY-v47.md",
        "last_updated": utc_now(),
        "patch_applied": "patch-BQCA.v47.sh",
        "previous_version": registry.get("previous_version") or "v45",
        "policy_sha256": sha256(policy),
        "orchestrator_path": REQUIRED_PATHS["orchestrator_path"],
        "doctor_path": REQUIRED_PATHS["doctor_path"],
    })
    registry_path.write_text(json.dumps(registry, indent=2) + "\n", encoding="utf-8")

    executable_paths = [root / rel for rel in EXECUTABLES]
    executable_paths.extend(sorted(root.glob("bob-quantum-v*.sh")))
    for path in executable_paths:
        if not path.is_file():
            continue
        mode = stat.S_IMODE(path.stat().st_mode)
        mode |= stat.S_IXUSR
        mode &= ~stat.S_IWOTH
        os.chmod(path, mode)

    result = check(root)
    reports = bob / "reports"
    write_report(result, reports / "BQCA.v47-assurance-report.txt")
    write_report(result, reports / "BQCA.v47-assurance-report.json")
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    for name in ("check", "repair", "report"):
        cmd = sub.add_parser(name)
        cmd.add_argument("--root", required=True, type=pathlib.Path)
        cmd.add_argument("--quiet", action="store_true")
        cmd.add_argument("--json", action="store_true")
        if name == "report":
            cmd.add_argument("--output", type=pathlib.Path)
    args = parser.parse_args()
    root = args.root.resolve()

    if args.command == "repair":
        result = repair(root)
    else:
        result = check(root)

    if args.command == "report":
        output = args.output or root / ".bob/reports/BQCA.v47-assurance-report.txt"
        write_report(result, output)
        json_output = output.with_suffix(".json") if output.suffix.lower() != ".json" else output
        write_report(result, json_output)

    if args.json:
        print(json.dumps(result, indent=2))
    elif not args.quiet:
        surfaces = result.get("checks", {}).get("surfaces", {})
        print("BQCA_V46_SURFACES " + " ".join(f"{k}={v}" for k, v in surfaces.items()))
        for warning in result["warnings"]:
            print(f"[BQCA v47][WARN] {warning}", file=sys.stderr)
        if result["ok"]:
            print("BQCA_V46_POLICY_ASSURANCE=PASS")
        else:
            for error in result["errors"]:
                print(f"[BQCA v47][ERROR] {error}", file=sys.stderr)
            print("BQCA_V46_POLICY_ASSURANCE=FAIL", file=sys.stderr)

    return 0 if result["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
