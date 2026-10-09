#!/usr/bin/env python3
"""Resolve the latest real BQCA user task for Bob Shell 2.x resume."""
from __future__ import annotations

import argparse
import json
import pathlib
import re
import subprocess
import sys
import urllib.parse
from typing import Any

AUTH_TITLE_PATTERNS = (
    re.compile(r"\bBOB_AUTH_OK\b", re.IGNORECASE),
    re.compile(r"Return\s+exactly\s+.*AUTH_OK", re.IGNORECASE),
    re.compile(r"BQCA[_ -]?AUTH(?:ENTICATION)?[_ -]?PROBE", re.IGNORECASE),
    re.compile(r"authentication\s+probe", re.IGNORECASE),
)


def normalized_workspace(value: str) -> pathlib.Path | None:
    value = (value or "").strip()
    if not value:
        return None
    parsed = urllib.parse.urlparse(value)
    if parsed.scheme == "file":
        value = urllib.parse.unquote(parsed.path)
    try:
        return pathlib.Path(value).expanduser().resolve()
    except Exception:
        return None


def parse_payload(text: str) -> list[dict[str, Any]]:
    text = text.strip()
    if not text:
        return []
    tasks: list[dict[str, Any]] = []
    try:
        payload = json.loads(text)
    except Exception:
        payload = None
    if isinstance(payload, list):
        tasks.extend(item for item in payload if isinstance(item, dict))
    elif isinstance(payload, dict):
        if isinstance(payload.get("tasks"), list):
            tasks.extend(item for item in payload["tasks"] if isinstance(item, dict))
        elif "id" in payload:
            tasks.append(payload)
    if tasks:
        return tasks
    for raw in text.splitlines():
        raw = raw.strip()
        if not raw:
            continue
        try:
            item = json.loads(raw)
        except Exception:
            continue
        if isinstance(item, dict) and "id" in item:
            tasks.append(item)
    return tasks


def run_task_list(bob_bin: str, workspace: pathlib.Path) -> tuple[list[dict[str, Any]], str]:
    attempts = (
        [bob_bin, "--list-tasks", "all"],
        [bob_bin, "--list-tasks", "--limit", "1000"],
        [bob_bin, "--list-tasks"],
    )
    diagnostics: list[str] = []
    for command in attempts:
        try:
            result = subprocess.run(
                command,
                cwd=workspace,
                text=True,
                capture_output=True,
                check=False,
            )
        except FileNotFoundError:
            raise RuntimeError(f"Bob CLI not found: {bob_bin}")
        tasks = parse_payload(result.stdout)
        diagnostics.append(
            f"command={' '.join(command)} rc={result.returncode} parsed={len(tasks)}"
        )
        if result.returncode == 0 and tasks:
            return tasks, "; ".join(diagnostics)
    return [], "; ".join(diagnostics)


def is_auth_probe(task: dict[str, Any]) -> bool:
    title = str(task.get("title") or "")
    return any(pattern.search(title) for pattern in AUTH_TITLE_PATTERNS)


def task_updated_at(task: dict[str, Any]) -> int:
    value = task.get("updatedAt", 0)
    try:
        return int(value)
    except Exception:
        return 0


def eligible_tasks(tasks: list[dict[str, Any]], workspace: pathlib.Path) -> list[dict[str, Any]]:
    resolved_workspace = workspace.resolve()
    eligible: list[dict[str, Any]] = []
    for task in tasks:
        task_id = str(task.get("id") or "").strip()
        if not task_id or is_auth_probe(task):
            continue
        task_workspace = normalized_workspace(str(task.get("workspace") or ""))
        if task_workspace is not None and task_workspace != resolved_workspace:
            continue
        eligible.append(task)
    eligible.sort(key=task_updated_at, reverse=True)
    return eligible


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("resolve", "report"))
    parser.add_argument("--bob-bin", default="bob")
    parser.add_argument("--workspace", required=True, type=pathlib.Path)
    args = parser.parse_args()

    workspace = args.workspace.expanduser().resolve()
    if not workspace.is_dir():
        print(f"BQCA_RESUME=FAIL: workspace not found: {workspace}", file=sys.stderr)
        return 2

    try:
        tasks, diagnostic = run_task_list(args.bob_bin, workspace)
    except RuntimeError as exc:
        print(f"BQCA_RESUME=FAIL: {exc}", file=sys.stderr)
        return 2

    candidates = eligible_tasks(tasks, workspace)
    if args.command == "report":
        print("=" * 88)
        print("BQCA v51.3 BOB SHELL 2.x RESUME TASK REPORT")
        print("=" * 88)
        print(f"Workspace               : {workspace}")
        print(f"Tasks parsed            : {len(tasks)}")
        print(f"Eligible user tasks     : {len(candidates)}")
        print(f"Task-list diagnostics   : {diagnostic}")
        print("-" * 88)
        for task in candidates[:20]:
            print(
                f"{task_updated_at(task):>16}  {str(task.get('id')):<40}  "
                f"{str(task.get('status') or ''):<10}  {str(task.get('title') or '')}"
            )
        print("-" * 88)
        if candidates:
            print(f"Selected task           : {candidates[0].get('id')}")
            print("FINAL RESUME STATUS     : PASS")
            return 0
        print("Selected task           : NONE")
        print("FINAL RESUME STATUS     : FAIL")
        return 3

    if not candidates:
        print(
            "BQCA_RESUME=FAIL: no resumable user task exists for this BQCA workspace; "
            "authentication-probe tasks are intentionally excluded",
            file=sys.stderr,
        )
        return 3

    print(str(candidates[0]["id"]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

# BQCA-ACTIVE-CENTRAL-POLICY:BEGIN
# Resolve the active BQCA policy dynamically and preserve its design, code,
# security, artifact-routing, and execution requirements.
# BQCA-ACTIVE-CENTRAL-POLICY:END
# BQCA-BOB-SHELL-V2-DNA:BEGIN
# Bind resume behavior to AGENTS.md, the active central policy, current menu
# context, quantum-qiskit-connector mode, and the latest real user task.
# BQCA-BOB-SHELL-V2-DNA:END
