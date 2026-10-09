#!/usr/bin/env python3
"""BQCA Bob Shell 2.x project-DNA installation and drift doctor."""
from __future__ import annotations
import argparse, json, pathlib, re, subprocess, sys

MARKER = "BQCA-BOB-SHELL-V2-DNA:BEGIN"
MARKER_LINE = re.compile(r"(?m)^\s*(?:#\s*BQCA-BOB-SHELL-V2-DNA:BEGIN\s*|<!--\s*BQCA-BOB-SHELL-V2-DNA:BEGIN\s*-->)$")
TEXT_EXTENSIONS = {".md", ".txt", ".sh", ".py"}
SLUG = re.compile(r"^[A-Za-z0-9-]+$")

def read(path: pathlib.Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")

def root_from_script() -> pathlib.Path:
    return pathlib.Path(__file__).resolve().parents[2]

def custom_modes(path: pathlib.Path):
    try:
        import yaml
        data = yaml.safe_load(read(path)) or {}
    except Exception as exc:
        raise RuntimeError(f"cannot parse custom_modes.yaml: {exc}")
    modes = data.get("customModes") or data.get("modes") or []
    if not isinstance(modes, list):
        raise RuntimeError("customModes must be a list")
    return modes

def syntax_error(path: pathlib.Path) -> str | None:
    if path.suffix == ".sh":
        r = subprocess.run(["bash", "-n", str(path)], text=True, capture_output=True)
        return None if r.returncode == 0 else r.stderr.strip()
    if path.suffix == ".py":
        try: compile(read(path), str(path), "exec")
        except Exception as exc: return str(exc)
    return None

def check(root: pathlib.Path) -> dict:
    errors=[]
    bob=root/".bob"; tools=bob/"quantum-tools"; kb=tools/"knowlegebase"
    agents=root/"AGENTS.md"; settings=bob/"settings.json"; modes_file=bob/"custom_modes.yaml"
    required=[
        agents, settings, bob/"hooks/bqca-session-context.sh",
        bob/"hooks/bqca-user-prompt-context.py", bob/"rules/00-bqca-core.md",
        tools/"bqca-bob2-dna-doctor.py", tools/"bqca-bob2-dna-doctor.sh",
    ]
    for p in required:
        if not p.is_file(): errors.append(f"missing required BQCA DNA component: {p}")
    for p in [agents, bob/"rules/00-bqca-core.md"]:
        if p.is_file() and len(MARKER_LINE.findall(read(p))) != 1:
            errors.append(f"DNA marker missing/duplicated: {p}")
    try:
        data=json.loads(read(settings)) if settings.is_file() else {}
        encoded=json.dumps(data)
        for needle in ("bqca-session-context.sh", "bqca-user-prompt-context.py"):
            if needle not in encoded: errors.append(f"settings hook missing: {needle}")
    except Exception as exc:
        errors.append(f"settings JSON invalid: {exc}")

    modes=[]
    try: modes=custom_modes(modes_file)
    except Exception as exc: errors.append(str(exc))
    slugs=[]; mode_marker_count=0
    for mode in modes:
        slug=str(mode.get("slug", "")); slugs.append(slug)
        if not SLUG.fullmatch(slug): errors.append(f"invalid custom mode slug: {slug}")
        if str(mode.get("customInstructions", "")).count(MARKER) != 1:
            errors.append(f"custom mode DNA missing/duplicated: {slug}")
        else: mode_marker_count += 1
        if not (bob/f"rules-{slug}").is_dir(): errors.append(f"mode rule directory missing: rules-{slug}")
    if len(slugs) != len(set(slugs)): errors.append("duplicate custom mode slugs detected")

    root_ops=sorted(p for p in root.glob("*.sh") if p.is_file())
    rules=sorted(p for d in bob.glob("rules-*") if d.is_dir() for p in d.rglob("*") if p.is_file() and p.suffix.lower() in TEXT_EXTENSIONS)
    skills=sorted(p for p in (bob/"skills").rglob("*") if p.is_file() and p.suffix.lower() in TEXT_EXTENSIONS)
    top_tools=sorted(p for p in tools.iterdir() if p.is_file() and p.suffix.lower() in TEXT_EXTENSIONS)
    kb_files=sorted(p for p in kb.rglob("*") if p.is_file() and p.suffix.lower() in {".md", ".txt", ".py"}) if kb.is_dir() else []
    for p in [*root_ops,*rules,*skills,*top_tools,*kb_files]:
        if len(MARKER_LINE.findall(read(p))) != 1: errors.append(f"DNA awareness missing/duplicated: {p}")
    catalog=kb/"bqca_quantum_algorithm_catalog.json"
    try:
        c=json.loads(read(catalog)); meta=c.get("bob_shell_v2_dna", {})
        if meta.get("binding") != "project-active": errors.append("knowledgebase catalog DNA metadata missing")
    except Exception as exc: errors.append(f"knowledgebase catalog invalid: {exc}")

    launcher=sorted(root.glob("bob-quantum-v2.*.sh"))
    launcher=launcher[-1] if launcher else None
    if not launcher: errors.append("Bob 2.x launcher missing")
    else:
        text=read(launcher)
        if text.count("BQCA-BOB-SHELL-V2-DNA-CHAIN-v51.0:BEGIN") != 1: errors.append("Bob 2.x launcher DNA chain missing/duplicated")
        for option in ("1","2","3","4","5"):
            if f'bqca_set_menu_context "{option}"' not in text: errors.append(f"menu context export missing for option {option}")
    xlaunch=root/"xLaunchpad.sh"
    if xlaunch.is_file() and read(xlaunch).count("BQCA-BOB-SHELL-V2-DNA-PREFLIGHT-v51.0:BEGIN") != 1:
        errors.append("xLaunchpad v51.0 DNA preflight missing/duplicated")

    for p in [root/"xLaunchpad.sh", launcher, bob/"hooks/bqca-session-context.sh", bob/"hooks/bqca-user-prompt-context.py", tools/"bqca-bob2-dna-doctor.py", tools/"bqca-bob2-dna-doctor.sh"]:
        if p and p.is_file():
            err=syntax_error(p)
            if err: errors.append(f"syntax error {p}: {err}")

    listener=tools/"bqca-active-policy-listener.sh"
    if listener.is_file():
        r=subprocess.run([str(listener),"validate"],text=True,capture_output=True)
        if r.returncode: errors.append("active central policy listener validation failed")
    return {
        "errors":errors,"modes":len(modes),"mode_markers":mode_marker_count,
        "root_operations":len(root_ops),"rules":len(rules),"skills":len(skills),"tools":len(top_tools),
        "knowledgebase_files":len(kb_files),"final_status":"PASS" if not errors else "FAIL",
    }

def main() -> int:
    ap=argparse.ArgumentParser(); ap.add_argument("command",choices=["check","report"]); ap.add_argument("--quiet",action="store_true")
    args=ap.parse_args(); result=check(root_from_script())
    if args.command=="report" or not args.quiet:
        print("="*88); print("BQCA v51.0 BOB SHELL 2.x PROJECT-DNA ASSURANCE REPORT"); print("="*88)
        print(f"Custom modes             : {result['mode_markers']}/{result['modes']}")
        print(f"Root operation scripts   : {result['root_operations']}")
        print(f"Rules / Skills / Tools   : {result['rules']} / {result['skills']} / {result['tools']}")
        print(f"Knowledgebase text/code  : {result['knowledgebase_files']}")
        if result['errors']:
            print("-"*88); print("ISSUES")
            for e in result['errors']: print(f"- {e}")
        print("-"*88); print(f"FINAL DNA STATUS         : {result['final_status']}")
        print("="*88)
        print(f"BQCA_BOB2_DNA_ASSURANCE={result['final_status']}")
    return 0 if result['final_status']=="PASS" else 1
if __name__=="__main__": raise SystemExit(main())

# BQCA-ACTIVE-CENTRAL-POLICY:BEGIN
# Resolve and obey the current stable BQCA policy and its validation contract.
# BQCA-ACTIVE-CENTRAL-POLICY:END

# BQCA-BOB-SHELL-V2-DNA:BEGIN
# In a trusted Bob Shell 2.x workspace, bind this component to AGENTS.md, the
# active central BQCA policy, exported menu context, current rules/skills/tools,
# and the offline knowledgebase without changing this component's core purpose.
# BQCA-BOB-SHELL-V2-DNA:END
# BQCA-TRUSTED-CHAT-AUTO-APPROVAL-v51.4:BEGIN
# Trusted BQCA chat sessions auto-approve routine project-scoped tool calls at
# session launch. This does not authorize secrets, destructive operations, Bob
# home/settings writes, external paths, or bypass of BQCA policy/safety gates.
# BQCA-TRUSTED-CHAT-AUTO-APPROVAL-v51.4:END
