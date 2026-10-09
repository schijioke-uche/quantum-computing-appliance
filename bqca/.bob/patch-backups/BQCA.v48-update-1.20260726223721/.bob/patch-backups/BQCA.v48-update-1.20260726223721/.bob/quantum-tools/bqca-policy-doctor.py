#!/usr/bin/env python3
"""BQCA v48 canonical policy assurance and drift detector."""
from __future__ import annotations
import argparse, hashlib, json, os, pathlib, re, stat, subprocess
from datetime import datetime, timezone

CANONICAL = "BQCA-CANONICAL-PRODUCTION-POLICY-v48"
LEGACY_CANONICAL = re.compile(
    r"(?:<!--\s*BQCA-CANONICAL-PRODUCTION-POLICY-v(?:30|31|32|33|34|35|36|37|38|39|40|41|42|43|44|45|46|47)(?:-[^:]*)?:BEGIN\s*-->|"
    r"^\s*#\s*BQCA-CANONICAL-PRODUCTION-POLICY-v(?:30|31|32|33|34|35|36|37|38|39|40|41|42|43|44|45|46|47)(?:-[^:]*)?:BEGIN\s*$)", re.I|re.M)
STALE_RUNTIME = re.compile(r"BQCA-(?:POLICY-ASSURANCE|DIRECT-EXECUTION-EXPORT|CANONICAL-ORCHESTRATOR|DIRECT-EXECUTION-DELEGATION|EXECUTION-ROUTING|FORMAL-ORCHESTRATOR|RESULT-CAPTURE-GATE)-v(?:44|45|46|47):BEGIN")
EXTENSIONS={".md",".txt",".sh",".py",".yaml",".yml"}

def sha256(path:pathlib.Path)->str:
    h=hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda:f.read(1024*1024),b''):h.update(chunk)
    return h.hexdigest()

def supported_files(root:pathlib.Path):
    bob=root/'.bob'
    rules=sorted(p for d in bob.glob('rules-*') if d.is_dir() for p in d.rglob('*') if p.is_file() and p.suffix.lower() in EXTENSIONS)
    s=bob/'skills'; skills=sorted(p for p in s.rglob('*') if p.is_file() and p.suffix.lower() in EXTENSIONS) if s.is_dir() else []
    t=bob/'quantum-tools'; tools=sorted(p for p in t.iterdir() if p.is_file() and p.suffix.lower() in EXTENSIONS) if t.is_dir() else []
    return rules,skills,tools

def bash_syntax(path):
    x=subprocess.run(['bash','-n',str(path)],text=True,capture_output=True)
    return None if x.returncode==0 else x.stderr.strip()

def python_syntax(path):
    try:compile(path.read_text(encoding='utf-8',errors='replace'),str(path),'exec');return None
    except Exception as e:return str(e)

def check(root:pathlib.Path):
    bob=root/'.bob'; tools=bob/'quantum-tools'; errors=[]; result={}
    policy=bob/'BQCA-PRODUCTION-POLICY.md'; versioned=bob/'BQCA-PRODUCTION-POLICY-v48.md'; registry_path=bob/'BQCA-ACTIVE-POLICY-REGISTRY.json'
    manifest_path=root/'patches/BQCA/policy-history/BQCA-policy-history-manifest.json'; cm=bob/'custom_modes.yaml'
    expected={'BQCA-PRODUCTION-POLICY.md','BQCA-PRODUCTION-POLICY-v48.md'}
    active={p.name for p in bob.glob('BQCA-*POLICY*.md')}; result['active_policy_files']=sorted(active)
    if active!=expected:errors.append(f'active policy files differ from expected set: {sorted(active)}')
    digest=''
    if not policy.is_file() or not versioned.is_file():errors.append('canonical v48 policy files are missing')
    else:
        digest=sha256(policy)
        if policy.read_bytes()!=versioned.read_bytes():errors.append('stable and versioned v48 policies differ')
    try:reg=json.loads(registry_path.read_text(encoding='utf-8'))
    except Exception as e:reg={};errors.append(f'invalid registry JSON: {e}')
    for key,want in [('active_version','v48'),('active_policy_path','.bob/BQCA-PRODUCTION-POLICY.md'),('versioned_policy_path','.bob/BQCA-PRODUCTION-POLICY-v48.md'),('direct_execution_path','.bob/quantum-tools/bqca-direct-execution.sh'),('orchestrator_path','.bob/quantum-tools/bqca-policy-orchestrator.sh'),('doctor_path','.bob/quantum-tools/bqca-policy-doctor.sh')]:
        if reg.get(key)!=want:errors.append(f'registry {key} is incorrect')
    if reg.get('policy_sha256')!=digest or reg.get('canonical_policy_sha256')!=digest:errors.append('registry canonical policy hash mismatch')
    auth=reg.get('active_authority',{}) if isinstance(reg,dict) else {}
    if auth.get('version')!='v48':errors.append('registry active_authority version is not v48')
    if auth.get('policy_sha256')!=digest:errors.append('registry active_authority hash mismatch')
    history_fail=0
    try:manifest=json.loads(manifest_path.read_text(encoding='utf-8'))
    except Exception as e:manifest={};errors.append(f'invalid policy-history manifest: {e}')
    for entry in manifest.get('entries',[]) if isinstance(manifest,dict) else []:
        p=root/str(entry.get('archive_path',''))
        if not p.is_file() or sha256(p)!=entry.get('sha256'):
            history_fail+=1;errors.append(f'history manifest mismatch: {p}')
    result['history_hash_failures']=history_fail
    rules,skills,tool_files=supported_files(root); files=[cm,*rules,*skills,*tool_files]
    begin=CANONICAL+':BEGIN'; coverage=[]; legacy=0
    for p in files:
        text=p.read_text(encoding='utf-8',errors='replace');legacy+=len(LEGACY_CANONICAL.findall(text));actual=text.count(begin)
        expected_count=len(re.findall(r'^\s*customInstructions:\s*[>|][+-]?\s*(?:#.*)?$',text,re.M)) if p==cm else 1
        if actual!=expected_count:coverage.append({'file':str(p.relative_to(root)),'expected':expected_count,'actual':actual})
    if legacy:errors.append(f'active v30-v47 canonical awareness blocks found: {legacy}')
    if coverage:errors.append(f'v48 awareness coverage errors: {len(coverage)}')
    result.update(legacy_blocks=legacy,coverage_errors=coverage,custom_mode_blocks=len(re.findall(r'^\s*customInstructions:\s*[>|][+-]?\s*(?:#.*)?$',cm.read_text(encoding='utf-8',errors='replace'),re.M)),rule_files=len(rules),skill_files=len(skills),tool_files=len(tool_files))
    stale=[]
    for p in [cm,root/'xLaunchpad.sh',*root.glob('bob-quantum-v*.sh'),*rules,*skills,*tool_files]:
        if STALE_RUNTIME.search(p.read_text(encoding='utf-8',errors='replace')):stale.append(str(p.relative_to(root)))
    if stale:errors.append(f'stale v44-v47 runtime markers remain: {len(stale)}')
    result['stale_runtime_files']=stale
    wrappers=[]
    req={
      root/'xLaunchpad.sh':('BQCA-POLICY-ASSURANCE-v48:BEGIN','bqca-policy-doctor.sh','check --quiet'),
      tools/'qiskit-v2x-environment.sh':('BQCA-DIRECT-EXECUTION-DELEGATION-v48:BEGIN','bqca-direct-execution.sh'),
      tools/'bqca-direct-execution.sh':('POLICY_VERSION="v48"','tee','output.txt','formal-run','PIPESTATUS','BQCA v48 DIRECT QUANTUM EXECUTION RESULT OUTPUT'),
      tools/'bqca-policy-doctor.sh':('patch-BQCA.v48.sh','BQCA v48 policy doctor'),
      tools/'bqca-policy-orchestrator.sh':('BQCA-PRODUCTION-POLICY-v48.md','BQCA_V48_INTERNAL','BQCA-FORMAL-ORCHESTRATOR-v48:BEGIN'),
    }
    for p,tokens in req.items():
        if not p.is_file():wrappers.append(f'missing wrapper: {p}');continue
        text=p.read_text(encoding='utf-8',errors='replace')
        for token in tokens:
            if token not in text:wrappers.append(f'{p.name} missing token: {token}')
    for p in sorted(root.glob('bob-quantum-v*.sh')):
        if 'BQCA-DIRECT-EXECUTION-EXPORT-v48:BEGIN' not in p.read_text(encoding='utf-8',errors='replace'):wrappers.append(f'{p.name} lacks v48 direct-execution export')
    if wrappers:errors.extend(wrappers)
    result['wrapper_errors']=wrappers
    syntax=[]
    executables=[root/'xLaunchpad.sh',tools/'bqca-direct-execution.sh',tools/'bqca-direct-execute.sh',tools/'bqca-policy-doctor.sh',tools/'bqca-policy-orchestrator.sh',tools/'qiskit-v2x-environment.sh',tools/'qiskit-connector.sh',tools/'qca-code-quality-guard.sh',*root.glob('bob-quantum-v*.sh')]
    for p in executables:
        if not p.is_file():syntax.append(f'missing executable: {p}');continue
        e=bash_syntax(p)
        if e:syntax.append(f'{p}: {e}')
        mode=stat.S_IMODE(p.stat().st_mode)
        if not mode&stat.S_IXUSR:syntax.append(f'not owner-executable: {p}')
        if mode&stat.S_IWOTH:syntax.append(f'world-writable executable: {p}')
    for p in tool_files:
        if p.suffix.lower()=='.py':
            e=python_syntax(p)
            if e:syntax.append(f'{p}: {e}')
    if syntax:errors.extend(syntax)
    result['syntax_permission_errors']=syntax
    hist=root/'patches/BQCA/policy-history'; isolated=not str(hist.resolve()).startswith(str(bob.resolve())+os.sep)
    if not isolated:errors.append('historical policy directory is inside active .bob context')
    result['historical_context_isolated']=isolated
    kb=tools/'knowlegebase/bqca_quantum_algorithm_catalog.json'
    try:
        cat=json.loads(kb.read_text(encoding='utf-8'))
        result['knowledgebase_entries']=len(cat.get('entries',[]))
        if cat.get('catalog_version')!='BQCA.v48':errors.append('knowledgebase catalog version is not BQCA.v48')
        if len(cat.get('entries',[]))<80:errors.append('knowledgebase catalog has fewer than 80 entries')
    except Exception as e:result['knowledgebase_entries']=0;errors.append(f'invalid knowledgebase catalog: {e}')
    result.update(policy_sha256=digest,errors=errors,status='PASS' if not errors else 'FAIL',checked_utc=datetime.now(timezone.utc).isoformat())
    return result

def format_report(r):
    w=88;lines=['='*w,'BQCA v48 CANONICAL POLICY ASSURANCE REPORT','='*w,f"Assessment time             : {r.get('checked_utc')}",f"Canonical policy SHA-256    : {r.get('policy_sha256')}",f"Active policies             : {', '.join(r.get('active_policy_files',[]))}",f"Custom mode blocks          : {r.get('custom_mode_blocks')}",f"Rules / Skills / Tools      : {r.get('rule_files')} / {r.get('skill_files')} / {r.get('tool_files')}",f"Legacy active blocks        : {r.get('legacy_blocks')}",f"History hash failures       : {r.get('history_hash_failures')}",f"Coverage errors             : {len(r.get('coverage_errors',[]))}",f"Wrapper errors              : {len(r.get('wrapper_errors',[]))}",f"Stale runtime files         : {len(r.get('stale_runtime_files',[]))}",f"Syntax/permission errors    : {len(r.get('syntax_permission_errors',[]))}",f"Knowledgebase entries       : {r.get('knowledgebase_entries')}",f"Historical context isolated : {'YES' if r.get('historical_context_isolated') else 'NO'}",'-'*w]
    if r.get('errors'):lines+=['ISSUES',*[f'- {x}' for x in r['errors']],'-'*w]
    lines += [f"FINAL ASSURANCE STATUS      : {r.get('status')}",'='*w]
    return '\n'.join(lines)+'\n'

def main():
    ap=argparse.ArgumentParser(description='BQCA v48 policy doctor');ap.add_argument('command',choices=('check','report'));ap.add_argument('--root',type=pathlib.Path,required=True);ap.add_argument('--output',type=pathlib.Path);ap.add_argument('--quiet',action='store_true');a=ap.parse_args()
    r=check(a.root.resolve());report=format_report(r)
    if a.command=='report' or a.output:
        out=a.output or a.root/'.bob/patches-applied/BQCA.v48-assurance-report.txt';out.parent.mkdir(parents=True,exist_ok=True);out.write_text(report,encoding='utf-8')
    if not a.quiet:print(report,end='')
    print(f"BQCA_V48_POLICY_ASSURANCE={r['status']}",file=__import__('sys').stderr if r['status']!='PASS' else __import__('sys').stdout)
    return 0 if r['status']=='PASS' else 1
if __name__=='__main__':raise SystemExit(main())

# BQCA-CANONICAL-PRODUCTION-POLICY-v48:BEGIN
# Use .bob/BQCA-PRODUCTION-POLICY.md as the sole active BQCA v48 authority.
# Direct synchronous execution is the default; formal orchestration is explicit
# opt-in. Preserve the Qiskit configuration/home-environment/2.5+ gates,
# plan-aware Runtime V2 execution, real-QPU-first fallback order, synchronized
# notebooks, scoped Hello World behavior, live dual-result capture, Job-ID-first
# real-QPU reports, and secret protection. Quantum DESIGN and CODE work consults
# bqca-quantum-kb.sh and the offline v48 catalog. v48 incorporates core v47 and
# Updates 1-6; Update 6 supersedes Update 5 URL crawling.
# BQCA-CANONICAL-PRODUCTION-POLICY-v48:END
