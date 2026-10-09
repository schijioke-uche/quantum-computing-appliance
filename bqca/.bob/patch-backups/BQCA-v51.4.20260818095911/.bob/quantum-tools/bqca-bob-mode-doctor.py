#!/usr/bin/env python3
# BQCA-ACTIVE-CENTRAL-POLICY:BEGIN
# Resolve and follow .bob/BQCA-PRODUCTION-POLICY.md through the active-policy
# registry. This diagnostic never overrides or duplicates the central policy.
# BQCA-ACTIVE-CENTRAL-POLICY:END
"""BQCA custom-mode and Bob Shell max-token-property diagnostic.

This tool never modifies Bob Shell, $HOME/.bob, or BQCA files. It validates
project custom-mode integrity and reports whether the observed token-property
TypeError has a matching reference in active BQCA sources.
"""
from __future__ import annotations

import argparse
import collections
import json
import os
import pathlib
import re
import subprocess
import sys
from datetime import datetime, timezone
from typing import Iterable

VALID_SLUG = re.compile(r"^[A-Za-z0-9-]+$")
SLUG_LINE = re.compile(r"^  - slug:\s*(.+?)\s*$")
NAME_LINE = re.compile(r"^    name:\s*(.+?)\s*$")
TOKEN_PATTERNS = [
    re.compile(r"\b" + "max" + "Tokens" + r"\b"),
    re.compile(r"\b" + "max" + "_tokens" + r"\b"),
    re.compile(r"\b" + "token" + "Limit" + r"\b"),
    re.compile(r"\b" + "token" + "_limit" + r"\b"),
]


def unquote(value: str) -> str:
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in {'"', "'"}:
        return value[1:-1]
    return value


def parse_modes(path: pathlib.Path) -> list[dict[str, object]]:
    text = path.read_text(encoding="utf-8")
    records: list[dict[str, object]] = []
    current: dict[str, object] | None = None
    for lineno, line in enumerate(text.splitlines(), 1):
        match = SLUG_LINE.match(line)
        if match:
            if current:
                records.append(current)
            current = {"slug": unquote(match.group(1)), "name": "", "line": lineno}
            continue
        if current:
            match = NAME_LINE.match(line)
            if match and not current["name"]:
                current["name"] = unquote(match.group(1))
    if current:
        records.append(current)
    return records


def active_project_files(root: pathlib.Path, doctor: pathlib.Path) -> Iterable[pathlib.Path]:
    excluded_dirs = {
        ".git", "patch-backups", "policy-history", "__pycache__", ".venv", "venv",
        "qiskit-v2x-env", "node_modules", "bob-quantum-store", "bob-quantum-designs",
        "runtime", "patches-applied",
    }
    allowed_suffixes = {".sh", ".py", ".json", ".yaml", ".yml", ".md", ".txt"}
    candidates = [root / "xLaunchpad.sh", root / ".bob" / "custom_modes.yaml"]
    candidates.extend(root.glob("bob-quantum-v*.sh"))
    bob = root / ".bob"
    if bob.is_dir():
        for path in bob.rglob("*"):
            if not path.is_file() or path == doctor:
                continue
            rel_parts = path.relative_to(root).parts
            if any(part in excluded_dirs for part in rel_parts):
                continue
            if path.suffix.lower() in allowed_suffixes:
                candidates.append(path)
    seen: set[pathlib.Path] = set()
    for path in candidates:
        try:
            resolved = path.resolve()
        except OSError:
            continue
        if resolved in seen or not path.is_file():
            continue
        seen.add(resolved)
        yield path


def scan_patterns(paths: Iterable[pathlib.Path]) -> list[dict[str, object]]:
    hits: list[dict[str, object]] = []
    for path in paths:
        try:
            lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
        except OSError:
            continue
        for lineno, line in enumerate(lines, 1):
            if any(pattern.search(line) for pattern in TOKEN_PATTERNS):
                snippet = line.strip()
                snippet = re.sub(r"(?i)(bearer\s+)[^\s\"']+", r"\1<REDACTED>", snippet)
                snippet = re.sub(r"(?i)(api[_-]?key\s*[:=]\s*)[^,\s\"']+", r"\1<REDACTED>", snippet)
                hits.append({"path": str(path), "line": lineno, "snippet": snippet[:240]})
    return hits


def user_bob_files(home: pathlib.Path) -> Iterable[pathlib.Path]:
    for rel in (".bob/settings.json", ".bob/config.json", ".bob/custom_modes.yaml"):
        path = home / rel
        if path.is_file():
            yield path


def recent_log_hits(home: pathlib.Path) -> list[dict[str, object]]:
    logs = home / ".bob" / "logs"
    if not logs.is_dir():
        return []
    files = sorted((p for p in logs.rglob("*") if p.is_file()), key=lambda p: p.stat().st_mtime, reverse=True)[:20]
    return scan_patterns(files)


def bob_identity() -> dict[str, str]:
    result = {"binary": "NOT FOUND", "version": "UNKNOWN"}
    try:
        which = subprocess.run(["bash", "-lc", "command -v bob"], text=True, capture_output=True, check=False)
        if which.returncode == 0 and which.stdout.strip():
            result["binary"] = which.stdout.strip()
            version = subprocess.run([which.stdout.strip(), "--version"], text=True, capture_output=True, check=False, timeout=15)
            output = (version.stdout or version.stderr).strip()
            if output:
                result["version"] = output.splitlines()[0][:200]
    except Exception:
        pass
    return result


def inspect(root: pathlib.Path) -> dict[str, object]:
    modes_path = root / ".bob" / "custom_modes.yaml"
    doctor = root / ".bob" / "quantum-tools" / "bqca-bob-mode-doctor.py"
    modes = parse_modes(modes_path)
    counts = collections.Counter(str(item["slug"]) for item in modes)
    duplicates = {slug: count for slug, count in counts.items() if count > 1}
    invalid = [item for item in modes if not VALID_SLUG.fullmatch(str(item["slug"]))]
    project_hits = scan_patterns(active_project_files(root, doctor))
    home = pathlib.Path.home()
    global_hits = scan_patterns(user_bob_files(home))
    logs = recent_log_hits(home)
    identity = bob_identity()
    local_defect = bool(duplicates or invalid or project_hits)
    return {
        "generated": datetime.now(timezone.utc).isoformat(),
        "root": str(root),
        "mode_count": len(modes),
        "modes": modes,
        "duplicate_slugs": duplicates,
        "invalid_slugs": invalid,
        "project_token_property_hits": project_hits,
        "user_bob_token_property_hits": global_hits,
        "bob_log_token_property_hits": logs,
        "bob": identity,
        "bqca_mode_configuration_valid": not duplicates and not invalid,
        "active_bqca_token_property_reference": bool(project_hits),
        "classification": (
            "BQCA_PROJECT_CONFIGURATION" if local_defect else "BOB_SHELL_OR_SERVICE_IF_ERROR_PERSISTS"
        ),
    }


def print_report(data: dict[str, object]) -> None:
    print("=" * 88)
    print("BQCA BOB SHELL TOKEN-PROPERTY DIAGNOSTIC REPORT")
    print("=" * 88)
    print(f"Generated                    : {data['generated']}")
    print(f"BQCA root                    : {data['root']}")
    print(f"Bob binary                   : {data['bob']['binary']}")
    print(f"Bob version                  : {data['bob']['version']}")
    print(f"Custom modes                 : {data['mode_count']}")
    print(f"Duplicate slugs              : {len(data['duplicate_slugs'])}")
    print(f"Invalid slugs                : {len(data['invalid_slugs'])}")
    print(f"Active BQCA token-key hits   : {len(data['project_token_property_hits'])}")
    print(f"User Bob config key hits     : {len(data['user_bob_token_property_hits'])}")
    print(f"Recent Bob log key hits      : {len(data['bob_log_token_property_hits'])}")
    print(f"Classification               : {data['classification']}")
    print("-" * 88)
    if data["duplicate_slugs"]:
        print("DUPLICATE CUSTOM-MODE SLUGS")
        for slug, count in sorted(data["duplicate_slugs"].items()):
            print(f"  - {slug}: {count}")
    if data["invalid_slugs"]:
        print("INVALID CUSTOM-MODE SLUGS")
        for item in data["invalid_slugs"]:
            print(f"  - line {item['line']}: {item['slug']} ({item['name']})")
    for title, key in (
        ("ACTIVE BQCA TOKEN-PROPERTY REFERENCES", "project_token_property_hits"),
        ("USER-GLOBAL BOB CONFIG REFERENCES (REPORT ONLY)", "user_bob_token_property_hits"),
        ("RECENT BOB LOG REFERENCES (REPORT ONLY)", "bob_log_token_property_hits"),
    ):
        values = data[key]
        if values:
            print(title)
            for item in values:
                print(f"  - {item['path']}:{item['line']}: {item['snippet']}")
    print("-" * 88)
    if data["classification"] == "BOB_SHELL_OR_SERVICE_IF_ERROR_PERSISTS":
        print("TAKEAWAY: BQCA mode configuration is valid and no active BQCA source defines the")
        print("token-property key. If the UI TypeError still occurs, it is in Bob Shell or its")
        print("service/model metadata. This tool does not modify Bob software.")
    else:
        print("TAKEAWAY: A BQCA-owned mode/configuration defect was detected. Apply or reapply")
        print("patch-BQCA.v48-update-3.sh, restart Bob Shell, and test again.")
    print("=" * 88)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("check", "report", "json"))
    parser.add_argument("--root", type=pathlib.Path)
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args()
    root = (args.root or pathlib.Path(__file__).resolve().parents[2]).resolve()
    data = inspect(root)
    if args.command == "json":
        print(json.dumps(data, indent=2, ensure_ascii=False))
    elif args.command == "report":
        print_report(data)
    elif not args.quiet:
        print(
            "BQCA_BOB_MODE_CONFIG=" + ("PASS" if data["bqca_mode_configuration_valid"] else "FAIL")
        )
        print(f"BQCA_ACTIVE_TOKEN_PROPERTY_HITS={len(data['project_token_property_hits'])}")
        print(f"BQCA_DIAGNOSTIC_CLASSIFICATION={data['classification']}")
    return 0 if data["bqca_mode_configuration_valid"] and not data["project_token_property_hits"] else 1


if __name__ == "__main__":
    raise SystemExit(main())

# BQCA-BOB-SHELL-V2-DNA:BEGIN
# In a trusted Bob Shell 2.x workspace, bind this component to AGENTS.md, the
# active central BQCA policy, exported menu context, current rules/skills/tools,
# and the offline knowledgebase without changing this component's core purpose.
# BQCA-BOB-SHELL-V2-DNA:END
