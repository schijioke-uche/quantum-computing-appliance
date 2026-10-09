#!/usr/bin/env python3
"""BQCA custom-mode/custom-rule parity synchronizer, v51.2."""
from __future__ import annotations
import argparse, json, pathlib, re, shutil, sys

VALID = re.compile(r"^[A-Za-z0-9-]+$")
SUFFIXES = {".md", ".txt", ".xml"}
DNA_NAME = "BQCA-" + "BOB-SHELL-V2-DNA"
POLICY_NAME = "BQCA-" + "ACTIVE-CENTRAL-POLICY"
ALIASES = {
    "quantum-qiskit-connector": ["qiskit-connector", "code", "quantum-code"],
    "quantum-code-default": ["quantum-code", "code"],
    "quantum-code-heron": ["quantum-code", "code"],
    "quantum-advanced-default": ["advanced"],
    "quantum-advanced": ["advanced"],
    "quantum-smart": ["quantum-intelligence", "orchestrator"],
}


def root() -> pathlib.Path:
    return pathlib.Path(__file__).resolve().parents[2]


def load_modes(path: pathlib.Path) -> list[dict]:
    try:
        import yaml
        data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    except Exception as exc:
        raise RuntimeError(f"cannot parse custom_modes.yaml: {exc}") from exc
    value = data.get("customModes") or data.get("modes") or []
    if not isinstance(value, list):
        raise RuntimeError("customModes must be a list")
    return [m for m in value if isinstance(m, dict)]


def files(directory: pathlib.Path) -> list[pathlib.Path]:
    if not directory.is_dir():
        return []
    return sorted(p for p in directory.rglob("*") if p.is_file() and p.suffix.lower() in SUFFIXES)


def dna_block() -> str:
    return (
        f"<!-- {DNA_NAME}:BEGIN -->\n"
        "## Bob Shell 2.x BQCA project-DNA binding\n"
        "Read `AGENTS.md`, resolve the active central policy, honor exported menu context, and use relevant skills, tools, and the offline knowledgebase without replacing this rule's specialized purpose.\n"
        f"<!-- {DNA_NAME}:END -->"
    )


def policy_block() -> str:
    return (
        f"<!-- {POLICY_NAME}:BEGIN -->\n"
        "## Active central policy binding\n"
        "Resolve and obey the current stable BQCA policy and require current design/code compliance reports before completion.\n"
        f"<!-- {POLICY_NAME}:END -->"
    )


def generic(mode: dict) -> str:
    slug = str(mode.get("slug", ""))
    name = str(mode.get("name", slug))
    role = str(mode.get("roleDefinition", "")).strip()
    use = str(mode.get("whenToUse", "")).strip()
    return f"""# {name} — Custom Rules

This is the custom-rule bridge for the BQCA mode slug `{slug}`.

## Role

{role or 'Use the role and instructions declared in .bob/custom_modes.yaml.'}

## When to use

{use or 'Use this mode only when selected by BQCA or the user.'}

## Requirements

- Preserve the active BQCA policy, project identity, security, routing, validation, notebook, and result-output controls.
- Use relevant BQCA skills, quantum tools, and the offline knowledgebase.
- Never silently fall back to generic Bob behavior.

{policy_block()}

{dna_block()}
"""


def candidate_dirs(bob: pathlib.Path, slug: str) -> list[pathlib.Path]:
    names = list(ALIASES.get(slug, []))
    if slug.startswith("quantum-"):
        names.append(slug.removeprefix("quantum-"))
    result=[]; seen=set()
    for name in names:
        if name and name != slug and name not in seen:
            seen.add(name); result.append(bob / f"rules-{name}")
    return result


def inspect(do_sync: bool) -> dict:
    base=root(); bob=base/".bob"
    modes=load_modes(bob/"custom_modes.yaml")
    slugs=[str(m.get("slug", "")).strip() for m in modes]
    errors=[]; actions=[]
    if len(slugs) != len(set(slugs)):
        errors.append("duplicate custom mode slugs")
    for mode in modes:
        slug=str(mode.get("slug", "")).strip()
        if not VALID.fullmatch(slug):
            errors.append(f"invalid slug: {slug}")
            continue
        target=bob/f"rules-{slug}"
        if not files(target) and do_sync:
            source=next((d for d in candidate_dirs(bob, slug) if files(d)), None)
            if source:
                if target.exists() and not target.is_dir():
                    errors.append(f"rule path is not a directory: {target}")
                    continue
                if not target.exists():
                    shutil.copytree(source, target)
                else:
                    for src in files(source):
                        dst=target/src.relative_to(source)
                        dst.parent.mkdir(parents=True, exist_ok=True)
                        shutil.copy2(src, dst)
                actions.append(f"rules-{slug} <- {source.name}")
            else:
                target.mkdir(parents=True, exist_ok=True)
                (target/f"01-bqca-{slug}-rules.md").write_text(generic(mode), encoding="utf-8")
                actions.append(f"rules-{slug} <- generated")
            target.chmod(0o755)
            for path in files(target):
                path.chmod(0o644)
        current=files(target)
        if not target.is_dir(): errors.append(f"missing rules-{slug}")
        elif not current: errors.append(f"empty rules-{slug}")
    orphans=sorted(d.name for d in bob.glob("rules-*") if d.is_dir() and d.name.removeprefix("rules-") not in set(slugs))
    return {"mode_count":len(modes),"actions":actions,"orphans":orphans,"errors":errors,"status":"PASS" if not errors else "FAIL"}


def main() -> int:
    parser=argparse.ArgumentParser()
    parser.add_argument("command", choices=["check","sync","report","json"])
    parser.add_argument("--quiet", action="store_true")
    args=parser.parse_args()
    result=inspect(args.command=="sync")
    if args.command=="json": print(json.dumps(result, indent=2))
    elif args.command=="report" or (not args.quiet and args.command in {"check","sync"}):
        print("="*88); print("BQCA v51.2 CUSTOM MODE / RULE PARITY REPORT"); print("="*88)
        print(f"Custom modes             : {result['mode_count']}")
        print(f"Missing/invalid issues   : {len(result['errors'])}")
        print(f"Compatibility rule dirs : {len(result['orphans'])}")
        for action in result["actions"]: print(f"Created                  : {action}")
        if result["orphans"]:
            print("-"*88); print("PRESERVED COMPATIBILITY RULE DIRECTORIES")
            for item in result["orphans"]: print(f"- {item}")
        if result["errors"]:
            print("-"*88); print("ISSUES")
            for item in result["errors"]: print(f"- {item}")
        print("-"*88); print(f"FINAL MODE-RULE STATUS   : {result['status']}"); print("="*88)
        print(f"BQCA_CUSTOM_MODE_RULES={result['status']}")
    return 0 if result["status"]=="PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())

# BQCA-ACTIVE-CENTRAL-POLICY:BEGIN
# Resolve and obey the current stable BQCA policy and validation contract.
# BQCA-ACTIVE-CENTRAL-POLICY:END

# BQCA-BOB-SHELL-V2-DNA:BEGIN
# Bind this tool to AGENTS.md, active BQCA policy, menu context, current rules,
# relevant skills/tools, and the offline knowledgebase without changing purpose.
# BQCA-BOB-SHELL-V2-DNA:END
# BQCA-TRUSTED-CHAT-AUTO-APPROVAL-v51.4:BEGIN
# Trusted BQCA chat sessions auto-approve routine project-scoped tool calls at
# session launch. This does not authorize secrets, destructive operations, Bob
# home/settings writes, external paths, or bypass of BQCA policy/safety gates.
# BQCA-TRUSTED-CHAT-AUTO-APPROVAL-v51.4:END
