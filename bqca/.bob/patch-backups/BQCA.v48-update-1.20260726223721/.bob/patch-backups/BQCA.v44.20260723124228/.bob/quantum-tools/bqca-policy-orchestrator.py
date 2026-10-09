#!/usr/bin/env python3
"""BQCA v45 canonical-policy registry, scan, and compliance helper."""
from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import re
import sys
from datetime import datetime, timezone

CANONICAL = "BQCA-CANONICAL-PRODUCTION-POLICY-" + "v44"
LEGACY_VERSION = r"(?:v30|v31|v32|v33|v34|v35|v36|v37|v38|v39(?:-update-1)?|v40|v41|v42|v43)"
LEGACY_HTML = re.compile(rf"<!--\s*BQCA-[^>\n]*{LEGACY_VERSION}:(?:POLICY-)?BEGIN\s*-->", re.I)
LEGACY_COMMENT = re.compile(rf"^\s*#\s*BQCA-[^\n]*{LEGACY_VERSION}:(?:POLICY-)?BEGIN\s*$", re.I | re.M)


def sha256(path: pathlib.Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def write_report(artifact: pathlib.Path, kind: str, status: str, checks_file: pathlib.Path, policy: pathlib.Path) -> pathlib.Path:
    checks: list[tuple[str, str, str]] = []
    if checks_file.is_file():
        for raw in checks_file.read_text(encoding="utf-8", errors="replace").splitlines():
            if not raw.strip():
                continue
            parts = raw.split("|", 2)
            while len(parts) < 3:
                parts.append("")
            checks.append((parts[0], parts[1], parts[2]))
    report = artifact.with_name(f"{artifact.stem}-policy-compliance.txt")
    now = datetime.now(timezone.utc).astimezone().isoformat()
    width = 88
    lines = [
        "=" * width,
        "BQCA v45 POLICY COMPLIANCE REPORT",
        "=" * width,
        f"Artifact                : {artifact}",
        f"Artifact type           : {kind}",
        f"Canonical policy        : {policy}",
        f"Validation date/time    : {now}",
        f"Artifact SHA-256        : {sha256(artifact) if artifact.is_file() else 'NOT AVAILABLE'}",
        "-" * width,
        "VALIDATION GATES",
        "-" * width,
    ]
    for label, gate_status, detail in checks:
        lines.append(f"{label[:31]:31} : {gate_status[:8]:8} {detail}".rstrip())
    lines.extend([
        "-" * width,
        f"FINAL STATUS            : {status}",
        "=" * width,
    ])
    report.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return report


def validate_registry(root: pathlib.Path, registry_path: pathlib.Path, manifest_path: pathlib.Path, policy: pathlib.Path, versioned: pathlib.Path) -> list[str]:
    errors: list[str] = []
    try:
        registry = json.loads(registry_path.read_text(encoding="utf-8"))
    except Exception as exc:
        return [f"invalid active-policy registry: {exc}"]
    active = registry.get("active_authority", {})
    if active.get("version") != "v44":
        errors.append("registry active authority is not v44")
    if active.get("stable_policy") != ".bob/BQCA-PRODUCTION-POLICY.md":
        errors.append("registry stable policy path is incorrect")
    if active.get("versioned_policy") != ".bob/BQCA-PRODUCTION-POLICY-v44.md":
        errors.append("registry versioned policy path is incorrect")
    if not policy.is_file() or not versioned.is_file():
        errors.append("canonical policy files are missing")
    elif policy.read_bytes() != versioned.read_bytes():
        errors.append("stable and versioned canonical policies differ")
    elif active.get("policy_sha256") != sha256(policy):
        errors.append("registry policy SHA-256 does not match canonical policy")
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except Exception as exc:
        return errors + [f"invalid policy-history manifest: {exc}"]
    for entry in manifest.get("entries", []):
        archive = root / str(entry.get("archive_path", ""))
        if not archive.is_file():
            errors.append(f"missing archived policy: {archive}")
        elif sha256(archive) != entry.get("sha256"):
            errors.append(f"archive hash mismatch: {archive}")
    return errors


def supported_files(root: pathlib.Path) -> tuple[list[pathlib.Path], list[pathlib.Path], list[pathlib.Path]]:
    bob = root / ".bob"
    extensions = {".md", ".txt", ".sh", ".py", ".yaml", ".yml"}
    rules = sorted(path for directory in bob.glob("rules-*") if directory.is_dir() for path in directory.rglob("*") if path.is_file() and path.suffix.lower() in extensions)
    skills_root = bob / "skills"
    skills = sorted(path for path in skills_root.rglob("*") if path.is_file() and path.suffix.lower() in extensions) if skills_root.is_dir() else []
    tools_root = bob / "quantum-tools"
    tools = sorted(path for path in tools_root.iterdir() if path.is_file() and path.suffix.lower() in extensions) if tools_root.is_dir() else []
    return rules, skills, tools


def scan_active(root: pathlib.Path) -> dict[str, object]:
    bob = root / ".bob"
    custom_modes = bob / "custom_modes.yaml"
    rules, skills, tools = supported_files(root)
    legacy_blocks = 0
    coverage_errors: list[dict[str, object]] = []
    begin_literal = CANONICAL + ":BEGIN"
    for path in [custom_modes, *rules, *skills, *tools]:
        text = path.read_text(encoding="utf-8", errors="replace")
        legacy_blocks += len(LEGACY_HTML.findall(text)) + len(LEGACY_COMMENT.findall(text))
        marker_count = text.count(begin_literal)
        expected = len(re.findall(r"^\s*customInstructions:\s*[>|][+-]?\s*(?:#.*)?$", text, re.M)) if path == custom_modes else 1
        if marker_count != expected:
            coverage_errors.append({"file": str(path.relative_to(root)), "expected": expected, "actual": marker_count})
    active_policy_names = sorted(path.name for path in bob.glob("BQCA-*.md") if "POLICY" in path.name.upper())
    return {
        "legacy_blocks": legacy_blocks,
        "coverage_errors": coverage_errors,
        "rule_files": len(rules),
        "skill_files": len(skills),
        "tool_files": len(tools),
        "active_policy_files": active_policy_names,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    report = sub.add_parser("write-report")
    report.add_argument("--artifact", type=pathlib.Path, required=True)
    report.add_argument("--kind", required=True)
    report.add_argument("--status", required=True)
    report.add_argument("--checks", type=pathlib.Path, required=True)
    report.add_argument("--policy", type=pathlib.Path, required=True)
    registry = sub.add_parser("validate-registry")
    registry.add_argument("--root", type=pathlib.Path, required=True)
    registry.add_argument("--registry", type=pathlib.Path, required=True)
    registry.add_argument("--manifest", type=pathlib.Path, required=True)
    registry.add_argument("--policy", type=pathlib.Path, required=True)
    registry.add_argument("--versioned-policy", type=pathlib.Path, required=True)
    scan = sub.add_parser("scan-active")
    scan.add_argument("--root", type=pathlib.Path, required=True)
    args = parser.parse_args()
    if args.command == "write-report":
        print(write_report(args.artifact.resolve(), args.kind, args.status, args.checks, args.policy.resolve()))
        return 0
    if args.command == "validate-registry":
        errors = validate_registry(args.root.resolve(), args.registry.resolve(), args.manifest.resolve(), args.policy.resolve(), args.versioned_policy.resolve())
        if errors:
            for error in errors:
                print(f"BQCA_V44_REGISTRY=FAIL: {error}", file=sys.stderr)
            return 1
        print("BQCA_V44_REGISTRY=PASS")
        return 0
    if args.command == "scan-active":
        result = scan_active(args.root.resolve())
        print(json.dumps(result, indent=2))
        expected = {"BQCA-PRODUCTION-POLICY.md", "BQCA-PRODUCTION-POLICY-v44.md"}
        bad = result["legacy_blocks"] or result["coverage_errors"] or set(result["active_policy_files"]) != expected
        return 1 if bad else 0
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
# BQCA-CANONICAL-PRODUCTION-POLICY-v45:BEGIN
# The sole active BQCA policy is .bob/BQCA-PRODUCTION-POLICY.md (v45).
# Route all public design, code, execution, result, and completion paths through
# bqca-policy-orchestrator.sh. Open Plan uses SamplerV2 or EstimatorV2 job mode
# according to workload semantics and must never use Session.
# BQCA-CANONICAL-PRODUCTION-POLICY-v45:END
