#!/usr/bin/env bash
set -Eeuo pipefail

#===============================================================================
# BQCA v48 Cumulative Production Policy Patch
# File: patch-BQCA.v48.sh
# Author: Dr. Jeffrey Chijioke-Uche, IBM Computer Scientist
#
# Purpose:
#   Promote BQCA v48 as the sole active production policy and aggregate the
#   effective behavior of:
#     patch-BQCA.v47.sh
#     patch-BQCA.v47-update-1.sh
#     patch-BQCA.v47-update-2.sh
#     patch-BQCA.v47-update-3.sh
#     patch-BQCA.v47-update-4.sh
#     patch-BQCA.v47-update-5.sh
#     patch-BQCA.v47-update-6.sh
#
#   The cumulative v48 policy preserves direct synchronous execution, live
#   terminal output, dual result files, plan-aware Runtime V2 execution,
#   Qiskit configuration and home environment controls, automatic notebooks,
#   request-scoped Hello World behavior, semantic assurance, and the offline
#   local algorithm knowledgebase. Update 6 supersedes Update 5 URL crawling.
#
# Protected assets:
#   This installer does not read, print, copy, back up, modify, chmod, remove,
#   or restore .env, bob-quantum-designs/, bob-quantum-store/,
#   $HOME/qiskit-v2x-env, or $HOME/.qiskit/qiskit-ibm.json.
#===============================================================================

PATCH_ID="BQCA.v48"
PATCH_FILE_NAME="patch-BQCA.v48.sh"
TIMESTAMP="$(date +%Y%m%d%H%M%S)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
TARGET_OVERRIDE=""
DRY_RUN=0
VALIDATE_ONLY=0
ROLLBACK_DIR=""

info() { printf '[BQCA v48][INFO] %s\n' "$*"; }
warn() { printf '[BQCA v48][WARN] %s\n' "$*" >&2; }
fail() { printf '[BQCA v48][ERROR] %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'USAGE'
BQCA v48 Cumulative Production Policy Patch

Usage:
  ./patch-BQCA.v48.sh [options]

Options:
  --target <path>        Explicit BQCA appliance root.
  --dry-run              Display the cumulative migration plan only.
  --validate-only        Validate the installed v48 policy and runtime.
  --rollback <backup>    Restore a v48 backup directory.
  -h, --help             Show this help.

Expected placement:
  <BQCA-root>/patches/BQCA/patch-BQCA.v48.sh

Protected assets are excluded from installer operations:
  .env
  bob-quantum-designs/
  bob-quantum-store/
  $HOME/qiskit-v2x-env
  $HOME/.qiskit/qiskit-ibm.json
USAGE
}

while (($#)); do
  case "$1" in
    --target)
      (($# >= 2)) || fail "--target requires a path"
      TARGET_OVERRIDE="$2"
      shift 2
      ;;
    --dry-run) DRY_RUN=1; shift ;;
    --validate-only) VALIDATE_ONLY=1; shift ;;
    --rollback)
      (($# >= 2)) || fail "--rollback requires a backup directory"
      ROLLBACK_DIR="$2"
      shift 2
      ;;
    -h|--help) usage; exit 0 ;;
    *) fail "Unknown option: $1" ;;
  esac
done

for cmd in awk base64 bash cat chmod cmp cp date dirname find grep head mkdir mktemp mv python3 rm sha256sum sort tar tee; do
  command -v "$cmd" >/dev/null 2>&1 || fail "Required command not found: $cmd"
done

is_bqca_root() {
  local candidate="$1"
  [[ -d "$candidate/.bob" ]] || return 1
  [[ -f "$candidate/.bob/custom_modes.yaml" ]] || return 1
  [[ -d "$candidate/.bob/skills" ]] || return 1
  [[ -d "$candidate/.bob/quantum-tools" ]] || return 1
  [[ -f "$candidate/xLaunchpad.sh" ]] || return 1
  [[ -d "$candidate/bob-quantum-store" ]] || return 1
  [[ -d "$candidate/bob-quantum-designs" ]] || return 1
}

resolve_bqca_root() {
  local candidate dir
  if [[ -n "$TARGET_OVERRIDE" ]]; then
    candidate="$(cd "$TARGET_OVERRIDE" 2>/dev/null && pwd -P || true)"
    [[ -n "$candidate" ]] || fail "Target path does not exist: $TARGET_OVERRIDE"
    is_bqca_root "$candidate" || fail "Target is not a valid BQCA root: $candidate"
    printf '%s\n' "$candidate"
    return
  fi
  candidate="$(pwd -P)"
  if is_bqca_root "$candidate"; then
    printf '%s\n' "$candidate"
    return
  fi
  dir="$SCRIPT_DIR"
  while [[ "$dir" != "/" ]]; do
    if is_bqca_root "$dir"; then printf '%s\n' "$dir"; return; fi
    if is_bqca_root "$dir/quantum-computing-agent"; then printf '%s\n' "$dir/quantum-computing-agent"; return; fi
    dir="$(dirname "$dir")"
  done
  fail "Unable to locate the BQCA root. Use --target <path>."
}

BQCA_ROOT="$(resolve_bqca_root)"
BOB_ROOT="$BQCA_ROOT/.bob"
TOOLS_DIR="$BOB_ROOT/quantum-tools"
CUSTOM_MODES="$BOB_ROOT/custom_modes.yaml"
REGISTRY="$BOB_ROOT/BQCA-ACTIVE-POLICY-REGISTRY.json"
POLICY_STABLE="$BOB_ROOT/BQCA-PRODUCTION-POLICY.md"
POLICY_V48="$BOB_ROOT/BQCA-PRODUCTION-POLICY-v48.md"
HISTORY_DIR="$BQCA_ROOT/patches/BQCA/policy-history"
PATCH_RECORD_DIR="$BOB_ROOT/patches-applied"
PATCH_RECORD="$PATCH_RECORD_DIR/BQCA.v48.txt"
ASSURANCE_REPORT="$PATCH_RECORD_DIR/BQCA.v48-assurance-report.txt"
BACKUP_ROOT="$BOB_ROOT/patch-backups"
BACKUP_DIR="$BACKUP_ROOT/${PATCH_ID}.${TIMESTAMP}"
BACKUP_PAYLOAD="$BACKUP_DIR/root-snapshot"
BACKUP_MANIFEST="$BACKUP_DIR/BQCA-v48-backup-manifest.txt"

info "Resolved BQCA root: $BQCA_ROOT"
info "Patch identity: $PATCH_ID"
info "Protected assets: .env, workload stores, home Qiskit environment, and account JSON"

if ((DRY_RUN)); then
  cat <<'DRY'
[BQCA v48][DRY-RUN] Planned cumulative changes:
  1. Back up all active policy, mode, rule, skill, tool, launcher, and history assets.
  2. Install the cumulative v47 Update 1-6 runtime-tool set.
  3. Write one clean canonical v48 policy and byte-identical stable/versioned copies.
  4. Archive the v47 active policy outside .bob and remove older active policy files.
  5. Rebuild the active-policy registry for v48 and record all incorporated patches.
  6. Replace v47 canonical/knowledgebase awareness with one v48 block across all modes, rules, skills, tools, templates, and knowledgebase assets.
  7. Preserve direct synchronous execution, live stdout/stderr, dual result files, notebook automation, plan-aware Runtime V2 behavior, semantic assurance, and the Update 6 local catalog.
  8. Mark Update 5 URL crawling as superseded by the offline Update 6 catalog.
  9. Update launch preflight, policy doctor, formal orchestrator, validators, result tools, and direct executor to v48.
 10. Validate policy equality, registry hashes, awareness coverage, syntax, runtime routing, direct execution, and knowledgebase integrity.
 11. Leave all protected assets unchanged.
DRY
  exit 0
fi

backup_path() {
  local source="$1" rel destination
  [[ -e "$source" ]] || return 0
  rel="${source#$BQCA_ROOT/}"
  case "$rel" in
    .env|bob-quantum-designs|bob-quantum-designs/*|bob-quantum-store|bob-quantum-store/*) return 0 ;;
  esac
  destination="$BACKUP_PAYLOAD/$rel"
  mkdir -p "$(dirname "$destination")"
  cp -a "$source" "$destination"
}

create_backup() {
  mkdir -p "$BACKUP_PAYLOAD"
  backup_path "$POLICY_STABLE"
  while IFS= read -r -d '' path; do backup_path "$path"; done < <(find "$BOB_ROOT" -maxdepth 1 -type f -name 'BQCA-*POLICY*.md' -print0)
  backup_path "$REGISTRY"
  backup_path "$CUSTOM_MODES"
  backup_path "$BOB_ROOT/skills"
  backup_path "$TOOLS_DIR"
  while IFS= read -r -d '' path; do backup_path "$path"; done < <(find "$BOB_ROOT" -maxdepth 1 -type d -name 'rules-*' -print0)
  backup_path "$BQCA_ROOT/xLaunchpad.sh"
  while IFS= read -r -d '' path; do backup_path "$path"; done < <(find "$BQCA_ROOT" -maxdepth 1 -type f -name 'bob-quantum-v*.sh' -print0)
  backup_path "$HISTORY_DIR"
  backup_path "$PATCH_RECORD"
  backup_path "$ASSURANCE_REPORT"
  cat > "$BACKUP_MANIFEST" <<MANIFEST
Patch: $PATCH_ID
Created: $(date -u '+%Y-%m-%dT%H:%M:%SZ')
Appliance root: $BQCA_ROOT
Backup payload: $BACKUP_PAYLOAD
Protected assets excluded: .env, bob-quantum-designs, bob-quantum-store, \$HOME/qiskit-v2x-env, \$HOME/.qiskit/qiskit-ibm.json
Restore with:
  $PATCH_FILE_NAME --target "$BQCA_ROOT" --rollback "$BACKUP_DIR"
MANIFEST
}

restore_backup() {
  local backup="$1" backup_abs payload source rel destination
  backup_abs="$(cd "$backup" 2>/dev/null && pwd -P || true)"
  [[ -n "$backup_abs" ]] || fail "Rollback directory not found: $backup"
  [[ -f "$backup_abs/BQCA-v48-backup-manifest.txt" ]] || fail "Not a BQCA v48 backup: $backup_abs"
  payload="$backup_abs/root-snapshot"
  [[ -d "$payload" ]] || fail "Backup payload is missing: $payload"

  "$TOOLS_DIR/notebook-autogen.sh" stop >/dev/null 2>&1 || true

  rm -f "$BOB_ROOT"/BQCA-*POLICY*.md "$REGISTRY" "$CUSTOM_MODES" "$PATCH_RECORD" "$ASSURANCE_REPORT"
  rm -rf "$BOB_ROOT/skills" "$TOOLS_DIR" "$HISTORY_DIR"
  find "$BOB_ROOT" -maxdepth 1 -type d -name 'rules-*' -exec rm -rf {} +
  rm -f "$BQCA_ROOT/xLaunchpad.sh"
  find "$BQCA_ROOT" -maxdepth 1 -type f -name 'bob-quantum-v*.sh' -delete

  while IFS= read -r -d '' source; do
    rel="${source#$payload/}"
    destination="$BQCA_ROOT/$rel"
    mkdir -p "$(dirname "$destination")"
    cp -a "$source" "$destination"
  done < <(find "$payload" -mindepth 1 -type f -print0)

  info "Rollback complete. Protected assets were not touched."
}

if [[ -n "$ROLLBACK_DIR" ]]; then
  restore_backup "$ROLLBACK_DIR"
  exit 0
fi

write_policy() {
  cat > "$POLICY_V48" <<'POLICY_V48'
# BQCA Canonical Production Policy v48

<!-- BQCA-CANONICAL-PRODUCTION-POLICY-v48:BEGIN -->

## 1. Authority and precedence

This document is the sole active natural-language production policy for the Bob Quantum Computing Agent (BQCA). The stable active path is `.bob/BQCA-PRODUCTION-POLICY.md`; the versioned active copy is `.bob/BQCA-PRODUCTION-POLICY-v48.md`. Historical policies and the v47 core/update patch series are audit records only after their effective requirements are incorporated here.

All custom modes, rules, skills, supported quantum tools, and the local quantum knowledgebase must follow this v48 authority. The active-policy registry, canonical policy SHA-256, policy doctor, and runtime wrappers enforce this precedence. Conflicting local guidance is superseded by this policy.

## 2. IBM Bob and BQCA guiding principles

IBM Bob classifies user intent, clarifies missing scientific parameters, decomposes work, creates governed designs, generates implementation artifacts, validates and repairs code, coordinates Qiskit configuration and execution, produces synchronized notebooks and result evidence, and routes artifacts for review and reuse. Human experts retain responsibility for scientific assumptions, execution-cost decisions, and interpretation of research results.

## 3. CODE intent

Treat a request as CODE intent immediately when the user uses `create`, `implement`, `write`, `generate`, `build`, `develop`, `produce`, `scaffold`, `construct`, `code`, `program`, `modify`, `update`, `repair`, `fix`, `refactor`, `complete`, `execute`, or equivalent wording and the object is quantum/Qiskit code or an executable quantum artifact. Do not wait for the exact phrase `create code`.

## 4. Governed artifact routing and secrets

- Research, architecture, and solution-design artifacts go to `bob-quantum-designs/`.
- Executable Python, notebooks, scripts, results, plots, logs, and implementation documentation go to `bob-quantum-store/`.
- Design and implementation artifacts remain separate and reviewable.
- Credentials and secrets must never be embedded in generated designs, code, notebooks, logs, compliance reports, knowledgebase outputs, or result-output files.

## 5. Qiskit account-configuration gate

Before Qiskit Connector rules, templates, validators, backend resolution, or execution are invoked, run `.bob/quantum-tools/qiskit-configuration.sh configure --quiet` and require success. The runtime tool atomically rebuilds `~/.qiskit/qiskit-ibm.json` with exactly one profile named `bqca`; `bqca` is the only default account. Never print the token.

## 6. Authorized Qiskit environment and version

The only authorized BQCA Qiskit environment is `$HOME/qiskit-v2x-env`, outside the BQCA project root. When absent, create it with `python3 -m venv "$HOME/qiskit-v2x-env"`. Before Qiskit inspection, package management, validation, or execution, activate it with `source "$HOME/qiskit-v2x-env/bin/activate"`.

All Qiskit installation, uninstall, upgrade, and version checks occur only inside the activated home environment using its `python -m pip`. System/global pip, user-site Qiskit, and project-local `qiskit-v2x-env` are prohibited. Qiskit must be version 2.5 or later.

## 7. Design principles

Quantum solution designs must be textual and reviewable; executable Python blocks are prohibited. Designs must state:

- the problem, selected algorithm, assumptions, qubit/circuit strategy, risks, and validation criteria;
- the Qiskit Connector account and backend strategy;
- Open Plan and Paid Plan execution behavior;
- real-QPU-first execution and controlled simulator fallback;
- `$HOME/qiskit-v2x-env` and Qiskit 2.5+ requirements;
- the governed result-output contract;
- expected design and implementation artifacts.

For Open Plan, the design must state that real-QPU work runs in job mode without `Session`. It must identify `SamplerV2(mode=backend)` for sampling, shot, count, or distribution workloads and `EstimatorV2(mode=backend)` for expectation-value, observable, energy, or Hamiltonian workloads. The design must direct the implementation to choose the suitable V2 primitive according to workload semantics.

Hello World content must not appear in a generic design. It is permitted only when explicitly requested.

## 8. Code and execution principles

Generated Qiskit code must use Qiskit Connector imports and initialization, perform account/backend checks, verify real-QPU operational status and qubit capacity, and attempt eligible real-QPU execution before simulator fallback.

- **Open Plan:** real-QPU execution uses job mode without `Session`. Use `SamplerV2(mode=backend)` when the workload returns samples, bitstrings, counts, shots, or probability distributions. Use `EstimatorV2(mode=backend)` when the workload estimates expectation values, observables, energies, or Hamiltonians.
- **Paid Plan:** real-QPU execution uses `Session(backend=backend)` with `SamplerV2(mode=session)` or `EstimatorV2(mode=session)` as appropriate.
- **Simulator fallback:** use a controlled `try/except` path, `transpile`, and `AerSimulator` or another supported local simulator.
- `backend.run()` is permitted only for a clearly local simulator and is prohibited for real IBM Quantum hardware. Real hardware uses Runtime V2 primitives.

Every executable quantum workload must emit:

- `BQCA_EXECUTION_TARGET=REAL_QPU` or `BQCA_EXECUTION_TARGET=SIMULATOR`;
- `BQCA_PLAN=<detected-plan>`;
- `BQCA_BACKEND=<backend-name>`;
- `BQCA_JOB_ID=<actual-job-id>` for a real-QPU result;
- `BQCA_RESULT=SUCCESS` or `BQCA_RESULT=FAILURE`;
- `BQCA_FALLBACK_REASON=<reason>` whenever simulator fallback occurs.

Scientific values may be emitted separately as `BQCA_RESULT_VALUE=<value>` and must not replace the required SUCCESS/FAILURE execution-status marker.

## 9. Notebook production

The `.py` implementation is authoritative. The BQCA runtime watcher automatically creates or refreshes the same-name `.ipynb` sibling after the Python source becomes stable. The notebook must be structurally valid and synchronized to the source digest. Manual notebook construction is an emergency fallback only after genuine automatic-generation failure.

## 10. Hello World scope

Hello World is request-scoped. Do not add Hello World sections, tests, commands, artifacts, or `bob-quantum-store/test` dependencies to unrelated designs or code. For an explicit Hello World request, use an existing artifact under `bob-quantum-store/test/` and execute it through the authorized environment and v48 execution contract.

## 11. Direct execution and governed dual-result contract

Direct execution through `.bob/quantum-tools/bqca-direct-execution.sh` is the default for development, testing, interactive exploration, debugging, and quick experiments. The formal orchestrator is explicit opt-in only for formal compliance, production deployment, formal documentation evidence, or audit requirements.

1. Direct execution runs synchronously.
2. Python uses `$HOME/qiskit-v2x-env/bin/python`, `PYTHONUNBUFFERED=1`, and `python -u`.
3. Combined stdout and stderr display continuously on the terminal while the workload runs.
4. The same complete stream is captured in `<source-stem>-result-output.txt` beside the source.
5. The finalized professional report is mirrored to `output.txt` in the same directory.
6. Both files contain the complete terminal output, timestamps, duration, command, source path, execution method, plan, backend, target, Job ID, fallback reason, exit status, notebook status, contract status, and a bottom `RESULT SUMMARY`.
7. For a final real-QPU result, `JOB ID: <actual-job-id>` is line one of both files.
8. Direct-mode policy gaps are warnings and preserve the workload process exit status; they do not turn a successful process into an artificial failure.
9. Credential leakage is blocking; captured secret-bearing output must not be published.

## 12. Execution decision matrix and completion order

| Scenario | Method | Reason |
|---|---|---|
| Development/Testing | Direct | Fast, real-time output |
| Interactive Exploration | Direct | Immediate feedback |
| Debugging | Direct | Clear error messages |
| Quick Experiments | Direct | No orchestration overhead |
| Formal Documentation | Orchestrator | Compliance reports |
| Production Deployment | Orchestrator | Full validation |
| Audit Requirements | Orchestrator | Policy enforcement |

### Direct execution — default

1. Invoke `.bob/quantum-tools/bqca-direct-execution.sh run <file.py>` or `run-notebook <file.ipynb>`.
2. Confirm or prepare `$HOME/qiskit-v2x-env` and Qiskit 2.5+ without invoking the orchestrator.
3. Rebuild the `bqca` Qiskit account configuration when the configuration tool is available.
4. Execute through the authorized Python with unbuffered output.
5. Stream and capture combined stdout/stderr.
6. Produce `<source-stem>-result-output.txt` and `output.txt` beside the source.
7. Preserve the workload exit status; record direct-mode contract gaps as warnings and block credential leakage.

### Formal execution — explicit opt-in

Use `.bob/quantum-tools/bqca-direct-execution.sh formal-run <artifact>` only when formal compliance documentation, production deployment, or audit evidence is explicitly required. Formal mode may use `.bob/quantum-tools/bqca-policy-orchestrator.sh` and treats policy violations as blocking.

## 13. Runtime assurance and conflict prevention

- Stable and versioned v48 policy files must be byte-identical and match the registry SHA-256.
- Historical policy hashes must match the policy-history manifest.
- Every custom mode, rule, skill, and supported quantum tool must contain exactly one v48 awareness block.
- Public execution wrappers default to `bqca-direct-execution.sh`; formal orchestration requires an explicit formal command or flag.
- Universal orchestrator-only execution wording, direct-result-capture prohibitions, and stale v30-v47 active-policy blocks must not remain active.
- `xLaunchpad.sh` performs the quiet v48 policy-doctor preflight but must not force formal orchestration for ordinary direct execution.
- Compliance, result, or knowledgebase evidence containing credential material is noncompliant.
- Semantic capability checks take precedence over brittle source-layout matching.

## 14. Local quantum algorithm knowledgebase

BQCA uses the offline catalog at `.bob/quantum-tools/knowlegebase/bqca_quantum_algorithm_catalog.json` through `.bob/quantum-tools/bqca-quantum-kb.sh` as a supplementary accelerator for every quantum DESIGN and CODE request.

1. Use `search`, `show`, `design`, or `scaffold` to identify compatible algorithm patterns, Qiskit packages, primitive selection, circuit assumptions, and result expectations.
2. The catalog and examples must identify themselves as BQCA v48 assets and support Qiskit 2.5+.
3. Open Plan examples use `SamplerV2(mode=backend)` or `EstimatorV2(mode=backend)` without `Session`.
4. Paid Plan examples use `Session(backend=backend)` with the suitable V2 primitive.
5. Simulator fallback is controlled and follows real-QPU eligibility or execution failure.
6. The catalog covers foundations, oracle algorithms, Fourier/phase algorithms, amplitude estimation, variational eigensolvers, optimization, machine learning, chemistry/nature, dynamics, linear systems, error correction/mitigation, characterization, and application patterns.
7. The catalog supplements IBM Bob intelligence and approved research. It never overrides the central policy, installed APIs, backend constraints, security, routing, notebook, result, or human-review requirements.
8. Update 5 mandatory URL crawling and sublink drilldown are superseded. Network crawling and a mandatory research-trace artifact are not required.
9. A missing local entry is not a blocking failure; use approved supplemental research and continue when a compatible pattern is not present.

## 15. Semantic assurance and repair

A protected shell or Python tool is valid when it exists, passes syntax validation, has safe permissions, and exposes the public capabilities required by this policy. Formatting, function order, and internal dispatch spelling must not independently trigger policy drift.

The Qiskit environment manager must expose `ensure`, `check`, `python`, `run`, `run-notebook`, `hello-world`, `hello-world-if-present`, `exec`, `environment-path`, `python-path`, and `activation-command`.

Repair may synchronize stable/versioned policy copies, refresh registry hashes, restore safe executable permissions, restore v48 awareness blocks, and regenerate assurance reports. Repair must never read, print, overwrite, or redistribute `.env`, IBM Quantum account JSON, API tokens, or workload secrets.

Duplicate custom-mode slugs and legacy-compatible implementation markers are warnings unless they prevent parsing or execution.

## 16. Cumulative v48 lineage

BQCA v48 incorporates the effective behavior of:

- `patch-BQCA.v47.sh` — direct execution plus semantic assurance baseline;
- `patch-BQCA.v47-update-1.sh` — canonical-policy/runtime consolidation repair;
- `patch-BQCA.v47-update-2.sh` — corrected semantic authority validation;
- `patch-BQCA.v47-update-3.sh` — professional direct-result presentation and process-status behavior;
- `patch-BQCA.v47-update-4.sh` — superseding synchronous direct execution, strict markers, and appliance-wide routing;
- `patch-BQCA.v47-update-5.sh` — historical knowledgebase-index experiment;
- `patch-BQCA.v47-update-6.sh` — active offline curated algorithm catalog that supersedes Update 5 URL crawling.

The preceding patch files and v47 policy are historical/audit sources after v48 activation. They do not independently govern decisions.

## 17. Active-component obligation

All custom modes, rules, skills, supported tools, templates, launchers, validators, result processors, and knowledgebase assets must use `.bob/BQCA-PRODUCTION-POLICY.md` as the active v48 authority. They must not independently reactivate v47 or any older policy. The v48 policy doctor blocks launch when authority, hash, awareness, routing, syntax, permissions, or cumulative knowledgebase requirements drift.

<!-- BQCA-CANONICAL-PRODUCTION-POLICY-v48:END -->
POLICY_V48
  cp "$POLICY_V48" "$POLICY_STABLE"
  chmod 644 "$POLICY_V48" "$POLICY_STABLE"
}

install_tools_payload() {
  local temp payload_file
  temp="$(mktemp -d)"
  payload_file="$temp/tools.tar.gz"
  base64 -d > "$payload_file" <<'TOOLS_PAYLOAD'
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
TOOLS_PAYLOAD
  tar -xzf "$payload_file" -C "$temp"
  [[ -d "$temp/quantum-tools" ]] || fail "Embedded cumulative tools payload is invalid"
  mkdir -p "$TOOLS_DIR"
  cp -a "$temp/quantum-tools/." "$TOOLS_DIR/"

  # Update 6 supersedes the Update 5 network index. Preserve an operator-populated
  # index as optional audit/reference material, but remove an empty generated
  # skeleton and never use either form as a mandatory DESIGN/CODE gate.
  local legacy_index="$TOOLS_DIR/knowlegebase/bqca_quantum_kb_index.txt"
  local optional_index="$TOOLS_DIR/knowlegebase/bqca_quantum_kb_index.optional.txt"
  if [[ -f "$legacy_index" ]]; then
    if grep -Eq 'https?://' "$legacy_index"; then
      if [[ ! -e "$optional_index" ]]; then
        mv "$legacy_index" "$optional_index"
      else
        rm -f "$legacy_index"
      fi
      chmod 644 "$optional_index" 2>/dev/null || true
    else
      rm -f "$legacy_index"
    fi
  fi
  rm -rf "$temp"
}

archive_old_active_policies() {
  local path base destination
  mkdir -p "$HISTORY_DIR"
  while IFS= read -r -d '' path; do
    base="$(basename "$path")"
    case "$base" in
      BQCA-PRODUCTION-POLICY.md|BQCA-PRODUCTION-POLICY-v48.md) continue ;;
    esac
    destination="$HISTORY_DIR/$base"
    if [[ -e "$destination" && ! "$path" -ef "$destination" ]]; then
      destination="$HISTORY_DIR/${base%.md}-archived-${TIMESTAMP}.md"
    fi
    cp -a "$path" "$destination"
    rm -f "$path"
  done < <(find "$BOB_ROOT" -maxdepth 1 -type f -name 'BQCA-*POLICY*.md' -print0)
}

patch_active_surfaces() {
  python3 - "$BQCA_ROOT" <<'PY_PATCH'
from __future__ import annotations
import json, pathlib, re, sys
root = pathlib.Path(sys.argv[1]).resolve()
bob = root / '.bob'
tools = bob / 'quantum-tools'

HTML_V48 = '''<!-- BQCA-CANONICAL-PRODUCTION-POLICY-v48:BEGIN -->
## BQCA v48 cumulative production authority
Use `.bob/BQCA-PRODUCTION-POLICY.md` as the sole active BQCA v48 policy. Direct synchronous execution through `.bob/quantum-tools/bqca-direct-execution.sh` is the default for development, testing, exploration, debugging, and quick experiments; the formal orchestrator is explicit opt-in only for compliance, deployment, or audit evidence. Preserve Qiskit Connector configuration, `$HOME/qiskit-v2x-env`, Qiskit 2.5+, Open Plan SamplerV2/EstimatorV2 job mode without Session, Paid Plan Session with the suitable V2 primitive, real-QPU-first behavior, controlled simulator fallback, automatic synchronized notebooks, request-scoped Hello World, live terminal output, `<source-stem>-result-output.txt`, `output.txt`, Job-ID-first real-QPU reports, and credential-leak blocking. For quantum DESIGN and CODE requests consult `.bob/quantum-tools/bqca-quantum-kb.sh` and the offline v48 algorithm catalog. The catalog supplements IBM Bob intelligence and never overrides the central policy. v48 incorporates core v47 and Updates 1-6; Update 6 supersedes Update 5 URL crawling.
<!-- BQCA-CANONICAL-PRODUCTION-POLICY-v48:END -->'''
COMMENT_V48 = '''# BQCA-CANONICAL-PRODUCTION-POLICY-v48:BEGIN
# Use .bob/BQCA-PRODUCTION-POLICY.md as the sole active BQCA v48 authority.
# Direct synchronous execution is the default; formal orchestration is explicit
# opt-in. Preserve the Qiskit configuration/home-environment/2.5+ gates,
# plan-aware Runtime V2 execution, real-QPU-first fallback order, synchronized
# notebooks, scoped Hello World behavior, live dual-result capture, Job-ID-first
# real-QPU reports, and secret protection. Quantum DESIGN and CODE work consults
# bqca-quantum-kb.sh and the offline v48 catalog. v48 incorporates core v47 and
# Updates 1-6; Update 6 supersedes Update 5 URL crawling.
# BQCA-CANONICAL-PRODUCTION-POLICY-v48:END'''
YAML_LINES = [
    '# BQCA-CANONICAL-PRODUCTION-POLICY-v48:BEGIN',
    'BQCA V48 CUMULATIVE PRODUCTION AUTHORITY: Use .bob/BQCA-PRODUCTION-POLICY.md as the sole active policy. Direct synchronous execution through .bob/quantum-tools/bqca-direct-execution.sh is the default for development, testing, exploration, debugging, and quick experiments; formal orchestration is explicit opt-in only for compliance, deployment, or audit evidence. Preserve Qiskit Connector configuration, $HOME/qiskit-v2x-env, Qiskit 2.5+, Open Plan SamplerV2 or EstimatorV2 job mode without Session, Paid Plan Session with the suitable V2 primitive, real-QPU-first behavior, controlled simulator fallback, synchronized notebooks, request-scoped Hello World, live terminal output, <source-stem>-result-output.txt plus output.txt, Job-ID-first real-QPU reports, and credential-leak blocking. For every quantum DESIGN and CODE request consult .bob/quantum-tools/bqca-quantum-kb.sh and the offline v48 algorithm catalog. v48 incorporates core v47 and Updates 1-6; Update 6 supersedes Update 5 URL crawling. This authority supersedes conflicting local wording.',
    '# BQCA-CANONICAL-PRODUCTION-POLICY-v48:END',
]

html_patterns = [
    r'\n?<!--\s*BQCA-CANONICAL-PRODUCTION-POLICY-v\d+(?:-[^:]*)?:BEGIN\s*-->.*?<!--\s*BQCA-CANONICAL-PRODUCTION-POLICY-v\d+(?:-[^:]*)?:END\s*-->\n?',
    r'\n?<!--\s*BQCA-LOCAL-ALGORITHM-KNOWLEDGEBASE-[^:]+:BEGIN\s*-->.*?<!--\s*BQCA-LOCAL-ALGORITHM-KNOWLEDGEBASE-[^:]+:END\s*-->\n?',
    r'\n?<!--\s*BQCA-V47-DIRECT-RESULT-CONTRACT-UPDATE-3:BEGIN\s*-->.*?<!--\s*BQCA-V47-DIRECT-RESULT-CONTRACT-UPDATE-3:END\s*-->\n?',
    r'\n?<!--\s*BQCA-QUANTUM-KB-[^>]*(?:BEGIN|START)\s*-->.*?<!--\s*BQCA-QUANTUM-KB-[^>]*END\s*-->\n?',
]
def clean_html(text: str) -> str:
    for pattern in html_patterns:
        text = re.sub(pattern, '\n', text, flags=re.I|re.S)
    return text

cm = bob / 'custom_modes.yaml'
text = cm.read_text(encoding='utf-8')
text = re.sub(r'(?ms)^([ \t]*)# BQCA-CANONICAL-PRODUCTION-POLICY-v\d+(?:-[^:]*)?:BEGIN\n.*?^\1# BQCA-CANONICAL-PRODUCTION-POLICY-v\d+(?:-[^:]*)?:END\n?', '', text)
text = re.sub(r'(?ms)^([ \t]*)# BQCA-LOCAL-ALGORITHM-KNOWLEDGEBASE-[^:]+:BEGIN\n.*?^\1# BQCA-LOCAL-ALGORITHM-KNOWLEDGEBASE-[^:]+:END\n?', '', text)
lines = text.splitlines(); result=[]; count=0
pat=re.compile(r'^(?P<indent>[ \t]*)customInstructions:\s*[>|][+-]?\s*(?:#.*)?$')
for line in lines:
    result.append(line)
    m=pat.match(line)
    if m:
        indent=m.group('indent')+'  '
        result.extend(indent+x for x in YAML_LINES)
        count += 1
cm.write_text('\n'.join(result)+'\n', encoding='utf-8')
print(f'custom_modes={count}')

files=[]
for d in bob.glob('rules-*'):
    if d.is_dir(): files.extend(p for p in d.rglob('*') if p.is_file() and p.suffix.lower() in {'.md','.txt','.yaml','.yml'})
skills=bob/'skills'
if skills.is_dir(): files.extend(p for p in skills.rglob('*') if p.is_file() and p.suffix.lower() in {'.md','.txt','.yaml','.yml'})
for p in sorted(set(files)):
    t=clean_html(p.read_text(encoding='utf-8', errors='replace')).rstrip()
    p.write_text(t+'\n\n'+HTML_V48+'\n', encoding='utf-8')

key_files = {
    'bqca-policy-doctor.py','bqca-policy-doctor.sh','bqca-policy-orchestrator.py','bqca-policy-orchestrator.sh',
    'bqca-direct-execution.sh','bqca-direct-execute.sh','qiskit-code-policy-check.py','qiskit-design-policy-check.py',
    'qiskit-result-output-policy-check.py','qiskit-result-output.py','qiskit-result-output.sh','qiskit-v2x-environment.sh',
    'qiskit-connector.sh','qca-code-quality-guard.sh','bqca-quantum-kb.sh'
}
for p in sorted(tools.iterdir()):
    if not p.is_file() or p.suffix.lower() not in {'.md','.txt','.sh','.py','.yaml','.yml'}: continue
    t=p.read_text(encoding='utf-8', errors='replace')
    t=clean_html(t)
    t=re.sub(r'(?ms)^# BQCA-CANONICAL-PRODUCTION-POLICY-v\d+(?:-[^:]*)?:BEGIN\n.*?^# BQCA-CANONICAL-PRODUCTION-POLICY-v\d+(?:-[^:]*)?:END\n?', '', t)
    t=re.sub(r'(?ms)^# BQCA-LOCAL-ALGORITHM-KNOWLEDGEBASE-[^:]+:BEGIN\n.*?^# BQCA-LOCAL-ALGORITHM-KNOWLEDGEBASE-[^:]+:END\n?', '', t)
    if p.name in key_files:
        t=t.replace('BQCA v47', 'BQCA v48').replace('BQCA_V47', 'BQCA_V48')
        t=t.replace('BQCA-PRODUCTION-POLICY-v47.md', 'BQCA-PRODUCTION-POLICY-v48.md')
        t=t.replace('BQCA-DIRECT-EXECUTION-DELEGATION-v47', 'BQCA-DIRECT-EXECUTION-DELEGATION-v48')
        t=t.replace('BQCA-EXECUTION-ROUTING-v47', 'BQCA-EXECUTION-ROUTING-v48')
        t=t.replace('BQCA-RESULT-CAPTURE-GATE-v47', 'BQCA-RESULT-CAPTURE-GATE-v48')
        t=t.replace('BQCA-FORMAL-ORCHESTRATOR-v47', 'BQCA-FORMAL-ORCHESTRATOR-v48')
        t=t.replace('BQCA-FORMAL-ORCHESTRATOR-GUARD-v47', 'BQCA-FORMAL-ORCHESTRATOR-GUARD-v48')
        t=t.replace('BQCA v47 Update 4', 'BQCA v48')
        t=t.replace('v47-update-4', 'v48').replace('v47-u4', 'v48')
        t=t.replace('POLICY_VERSION="v47"', 'POLICY_VERSION="v48"')
        t=t.replace('POLICY_UPDATE="update-4"', 'POLICY_UPDATE="cumulative"')
        t=t.replace('patch-BQCA.v47-update-4.sh', 'patch-BQCA.v48.sh')
        t=t.replace('BQCA.v47-assurance-report.txt', 'BQCA.v48-assurance-report.txt')
        t=t.replace('BQCA_QISKIT_CODE_POLICY_V47_UPDATE4', 'BQCA_QISKIT_CODE_POLICY_V48')
        t=t.replace('BQCA_QISKIT_DESIGN_POLICY_V47_UPDATE4', 'BQCA_QISKIT_DESIGN_POLICY_V48')
        t=t.replace('BQCA_RESULT_OUTPUT_POLICY_V47_UPDATE4', 'BQCA_RESULT_OUTPUT_POLICY_V48')
        t=t.replace('BQCA v47 DIRECT QUANTUM EXECUTION RESULT OUTPUT', 'BQCA v48 DIRECT QUANTUM EXECUTION RESULT OUTPUT')
    p.write_text(t.rstrip()+'\n\n'+COMMENT_V48+'\n', encoding='utf-8')

for name in ('bqca-policy-doctor.py','bqca-policy-orchestrator.py'):
    p=tools/name; t=p.read_text(encoding='utf-8')
    t=t.replace('|45|46)', '|45|46|47)').replace('|45|46):', '|45|46|47):')
    t=t.replace('v44|45|46):BEGIN', 'v44|45|46|47):BEGIN')
    t=t.replace('v44|45|46)', 'v44|45|46|47)')
    p.write_text(t, encoding='utf-8')

kb=tools/'knowlegebase'
if kb.is_dir():
    for p in kb.rglob('*'):
        if not p.is_file() or p.suffix.lower() not in {'.md','.txt','.py','.json'}: continue
        if p.suffix.lower()=='.json':
            try: data=json.loads(p.read_text(encoding='utf-8'))
            except Exception: continue
            if isinstance(data,dict) and p.name=='bqca_quantum_algorithm_catalog.json':
                data['catalog_version']='BQCA.v48'
                notes=data.setdefault('policy_notes',{})
                notes['active_policy']='BQCA.v48'; notes['update5_url_crawling']='superseded'
                p.write_text(json.dumps(data, indent=2, sort_keys=True)+'\n', encoding='utf-8')
        else:
            t=p.read_text(encoding='utf-8', errors='replace')
            t=t.replace('BQCA.v47-update-6','BQCA.v48').replace('v47 Update 6','v48').replace('V47 UPDATE 6','V48')
            t=t.replace('BQCA v47','BQCA v48')
            p.write_text(t, encoding='utf-8')

xl=root/'xLaunchpad.sh'; t=xl.read_text(encoding='utf-8')
t=re.sub(r'(?ms)^# BQCA-POLICY-ASSURANCE-v(?:47|48):BEGIN\n.*?^# BQCA-POLICY-ASSURANCE-v(?:47|48):END\n?', '', t)
block='''# BQCA-POLICY-ASSURANCE-v48:BEGIN
_BQCA_V48_POLICY_DOCTOR="${SCRIPT_DIR}/.bob/quantum-tools/bqca-policy-doctor.sh"
if [[ ! -x "${_BQCA_V48_POLICY_DOCTOR}" ]]; then
  printf '[BQCA][ERROR] BQCA v48 policy doctor is missing: %s\\n' "${_BQCA_V48_POLICY_DOCTOR}" >&2
  exit 1
fi
if ! "${_BQCA_V48_POLICY_DOCTOR}" check --quiet; then
  printf '[BQCA][ERROR] BQCA v48 policy drift detected. Run: %s repair\\n' "${_BQCA_V48_POLICY_DOCTOR}" >&2
  exit 1
fi
unset _BQCA_V48_POLICY_DOCTOR
# BQCA-POLICY-ASSURANCE-v48:END
'''
needle='set +a\n'
if needle not in t: raise SystemExit('Unable to locate environment-loading boundary in xLaunchpad.sh')
t=t.replace(needle, needle+'\n'+block+'\n', 1)
xl.write_text(t, encoding='utf-8')

for p in root.glob('bob-quantum-v*.sh'):
    t=p.read_text(encoding='utf-8')
    t=re.sub(r'(?ms)^# BQCA-DIRECT-EXECUTION-EXPORT-v(?:47|48):BEGIN\n.*?^# BQCA-DIRECT-EXECUTION-EXPORT-v(?:47|48):END\n?', '', t)
    block='''# BQCA-DIRECT-EXECUTION-EXPORT-v48:BEGIN
BQCA_ACTIVE_POLICY="${SCRIPT_DIR}/.bob/BQCA-PRODUCTION-POLICY.md"
BQCA_ACTIVE_POLICY_VERSION="v48"
BQCA_DIRECT_EXECUTION="${SCRIPT_DIR}/.bob/quantum-tools/bqca-direct-execution.sh"
BQCA_FORMAL_ORCHESTRATOR="${SCRIPT_DIR}/.bob/quantum-tools/bqca-policy-orchestrator.sh"
BQCA_POLICY_DOCTOR="${SCRIPT_DIR}/.bob/quantum-tools/bqca-policy-doctor.sh"
BQCA_QUANTUM_KNOWLEDGEBASE="${SCRIPT_DIR}/.bob/quantum-tools/bqca-quantum-kb.sh"
export BQCA_ACTIVE_POLICY BQCA_ACTIVE_POLICY_VERSION BQCA_DIRECT_EXECUTION BQCA_FORMAL_ORCHESTRATOR BQCA_POLICY_DOCTOR BQCA_QUANTUM_KNOWLEDGEBASE
# Direct execution is the default. Formal orchestration is explicit opt-in.
# All design/code decisions and knowledgebase use follow the v48 central policy.
# BQCA-DIRECT-EXECUTION-EXPORT-v48:END
'''
    needle='SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"\n'
    if needle not in t: raise SystemExit(f'Unable to locate SCRIPT_DIR in {p.name}')
    t=t.replace(needle, needle+'\n'+block+'\n',1)
    p.write_text(t, encoding='utf-8')
print(f'awareness_files={len(set(files))}')
PY_PATCH
}

rebuild_history_manifest() {
  python3 - "$BQCA_ROOT" <<'PY_HISTORY'
from __future__ import annotations
import hashlib, json, pathlib, sys
from datetime import datetime, timezone
root=pathlib.Path(sys.argv[1]).resolve()
hist=root/'patches/BQCA/policy-history'
hist.mkdir(parents=True, exist_ok=True)
timeline=hist/'BQCA-policy-timeline.md'
old=timeline.read_text(encoding='utf-8',errors='replace').rstrip() if timeline.exists() else '# BQCA Policy Timeline'
line='- v48: cumulative active authority aggregating core v47 and Updates 1-6; Update 6 supersedes Update 5 URL crawling.'
if line not in old:
    old += '\n' + line
timeline.write_text(old+'\n',encoding='utf-8')

def sha(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

entries=[]
# The timeline and manifest describe history; they are deliberately excluded
# from their own checksum inventory to prevent self-invalidating metadata.
for p in sorted(hist.glob('BQCA-*POLICY*.md')):
    name=p.name
    if 'v35' in name or 'v36' in name:
        status='duplicate-superseded'
    elif any(v in name for v in ('v43','v44','v45','v46','v47')):
        status='incorporated-into-v48'
    else:
        status='historical-audit'
    entries.append({
        'name':name,
        'archive_path':str(p.relative_to(root)),
        'sha256':sha(p),
        'size_bytes':p.stat().st_size,
        'status':status,
    })
manifest={
    'schema_version':3,
    'generated_utc':datetime.now(timezone.utc).isoformat(),
    'active_version':'v48',
    'timeline_path':str(timeline.relative_to(root)),
    'entries':entries,
}
(hist/'BQCA-policy-history-manifest.json').write_text(json.dumps(manifest,indent=2,sort_keys=True)+'\n',encoding='utf-8')
PY_HISTORY
}

write_registry() {
  local hash
  hash="$(sha256sum "$POLICY_STABLE" | awk '{print $1}')"
  python3 - "$REGISTRY" "$hash" "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" <<'PY_REGISTRY'
import json, pathlib, sys
path=pathlib.Path(sys.argv[1]); digest=sys.argv[2]; now=sys.argv[3]
data={
  'schema_version':3,'active_version':'v48','active_policy_path':'.bob/BQCA-PRODUCTION-POLICY.md','policy_path':'.bob/BQCA-PRODUCTION-POLICY.md','versioned_policy_path':'.bob/BQCA-PRODUCTION-POLICY-v48.md','policy_sha256':digest,'canonical_policy_sha256':digest,'updated_utc':now,
  'direct_execution_path':'.bob/quantum-tools/bqca-direct-execution.sh','orchestrator_path':'.bob/quantum-tools/bqca-policy-orchestrator.sh','doctor_path':'.bob/quantum-tools/bqca-policy-doctor.sh','repair_patch_path':'patches/BQCA/patch-BQCA.v48.sh','default_execution':'direct','formal_compliance':'optional-orchestrator','historical_policy_directory':'patches/BQCA/policy-history',
  'active_authority':{'version':'v48','stable_policy':'.bob/BQCA-PRODUCTION-POLICY.md','versioned_policy':'.bob/BQCA-PRODUCTION-POLICY-v48.md','policy_sha256':digest},
  'incorporated_patches':['patch-BQCA.v47.sh','patch-BQCA.v47-update-1.sh','patch-BQCA.v47-update-2.sh','patch-BQCA.v47-update-3.sh','patch-BQCA.v47-update-4.sh','patch-BQCA.v47-update-5.sh','patch-BQCA.v47-update-6.sh'],
  'execution_contract':{'method':'direct-synchronous-default','python':'$HOME/qiskit-v2x-env/bin/python','unbuffered':['PYTHONUNBUFFERED=1','python -u'],'authoritative_result':'<source-stem>-result-output.txt','latest_run_mirror':'output.txt','live_terminal':True,'real_qpu_job_id_first_line':True,'direct_policy_gaps':'warning-preserve-workload-exit-status','credential_leakage':'blocking','required_markers':['BQCA_EXECUTION_TARGET','BQCA_PLAN','BQCA_BACKEND','BQCA_JOB_ID','BQCA_RESULT','BQCA_FALLBACK_REASON'],'result_status_values':['SUCCESS','FAILURE']},
  'knowledgebase':{'policy_version':'BQCA.v48','mode':'offline-curated-algorithm-catalog','catalog_path':'.bob/quantum-tools/knowlegebase/bqca_quantum_algorithm_catalog.json','tool_path':'.bob/quantum-tools/bqca-quantum-kb.sh','examples_path':'.bob/quantum-tools/knowlegebase/examples','required_for_intents':['design','code'],'qiskit_min_version':'2.5.0','open_plan_session_allowed':False,'open_plan_primitives':['SamplerV2(mode=backend)','EstimatorV2(mode=backend)'],'paid_plan_primitives':['SamplerV2(mode=session)','EstimatorV2(mode=session)'],'real_qpu_first':True,'url_seed_access_required':False,'sublink_drilldown_required':False,'mandatory_research_trace':False,'supplemental_external_research_allowed':True,'overrides_central_policy':False,'update5_status':'superseded-by-update6'},
  'disposition':{'v47':'incorporated into v48','v47-update-1':'incorporated into v48','v47-update-2':'incorporated into v48','v47-update-3':'incorporated into v48','v47-update-4':'incorporated into v48','v47-update-5':'superseded by update-6 and retained as history','v47-update-6':'incorporated into v48 local algorithm knowledgebase','v48':'active authority'}
}
path.write_text(json.dumps(data,indent=2,sort_keys=True)+'\n',encoding='utf-8')
PY_REGISTRY
  chmod 644 "$REGISTRY"
}

normalize_permissions() {
  chmod 755 "$BQCA_ROOT/xLaunchpad.sh" 2>/dev/null || true
  find "$BQCA_ROOT" -maxdepth 1 -type f -name 'bob-quantum-v*.sh' -exec chmod 755 {} +
  find "$TOOLS_DIR" -maxdepth 1 -type f \( -name '*.sh' -o -name '*.py' \) -exec chmod 755 {} +
  find "$TOOLS_DIR/knowlegebase" -maxdepth 1 -type f -name '*.py' -exec chmod 755 {} + 2>/dev/null || true
  chmod 644 "$POLICY_STABLE" "$POLICY_V48" "$REGISTRY" "$CUSTOM_MODES"
  find "$HISTORY_DIR" -type f -exec chmod 644 {} +
}

write_patch_record() {
  local hash catalog_entries design_cards code_examples
  hash="$(sha256sum "$POLICY_STABLE" | awk '{print $1}')"
  catalog_entries="$(python3 - "$TOOLS_DIR/knowlegebase/bqca_quantum_algorithm_catalog.json" <<'PY_COUNT'
import json,sys
print(len(json.load(open(sys.argv[1],encoding='utf-8')).get('entries',[])))
PY_COUNT
)"
  design_cards="$(find "$TOOLS_DIR/knowlegebase/examples" -maxdepth 1 -type f -name '*-design.md' | wc -l)"
  code_examples="$(find "$TOOLS_DIR/knowlegebase/examples" -maxdepth 1 -type f -name '*.py' | wc -l)"
  mkdir -p "$PATCH_RECORD_DIR"
  cat > "$PATCH_RECORD" <<RECORD
Patch: $PATCH_ID
Applied: $(date -u '+%Y-%m-%dT%H:%M:%SZ')
Root: $BQCA_ROOT
Backup: $BACKUP_DIR
Active policy: .bob/BQCA-PRODUCTION-POLICY.md
Versioned policy: .bob/BQCA-PRODUCTION-POLICY-v48.md
Policy SHA-256: $hash
Incorporated patches: patch-BQCA.v47.sh, v47-update-1, v47-update-2, v47-update-3, v47-update-4, v47-update-5, v47-update-6
Update 5 disposition: superseded by Update 6 offline local catalog
Knowledgebase entries: $catalog_entries
Knowledgebase design cards: $design_cards
Knowledgebase code examples: $code_examples
Default execution: direct synchronous live terminal + dual result files
Formal orchestrator: explicit opt-in only
Protected assets: excluded and unchanged by installer
RECORD
}

validate_installation() {
  local failures=0 mode_expected mode_actual rules skills tools catalog_entries design_cards code_examples
  [[ -f "$POLICY_STABLE" && -f "$POLICY_V48" ]] || { warn "v48 policy files are missing"; failures=$((failures+1)); }
  cmp -s "$POLICY_STABLE" "$POLICY_V48" || { warn "stable and versioned v48 policies differ"; failures=$((failures+1)); }

  python3 - "$BQCA_ROOT" <<'PY_VALIDATE' || failures=$((failures+1))
import hashlib,json,pathlib,sys
root=pathlib.Path(sys.argv[1]); bob=root/'.bob'
policy=bob/'BQCA-PRODUCTION-POLICY.md'; versioned=bob/'BQCA-PRODUCTION-POLICY-v48.md'; registry=bob/'BQCA-ACTIVE-POLICY-REGISTRY.json'
data=json.loads(registry.read_text()); hashv=hashlib.sha256(policy.read_bytes()).hexdigest()
assert data['active_version']=='v48'
assert data['versioned_policy_path']=='.bob/BQCA-PRODUCTION-POLICY-v48.md'
assert data['policy_sha256']==hashv==data['canonical_policy_sha256']
assert data['knowledgebase']['policy_version']=='BQCA.v48'
assert data['knowledgebase']['url_seed_access_required'] is False
assert policy.read_bytes()==versioned.read_bytes()
active={p.name for p in bob.glob('BQCA-*POLICY*.md')}
assert active=={'BQCA-PRODUCTION-POLICY.md','BQCA-PRODUCTION-POLICY-v48.md'},active
print('BQCA_V48_POLICY_REGISTRY=PASS')
PY_VALIDATE

  mode_expected="$(grep -cE '^[[:space:]]*customInstructions:[[:space:]]*[>|][+-]?' "$CUSTOM_MODES" || true)"
  mode_actual="$(grep -c 'BQCA-CANONICAL-PRODUCTION-POLICY-v48:BEGIN' "$CUSTOM_MODES" || true)"
  [[ "$mode_expected" -gt 0 && "$mode_actual" -eq "$mode_expected" ]] || { warn "custom-mode v48 coverage $mode_actual/$mode_expected"; failures=$((failures+1)); }

  rules="$(find "$BOB_ROOT" -maxdepth 2 -type f -path '*/rules-*/*' \( -name '*.md' -o -name '*.txt' -o -name '*.yaml' -o -name '*.yml' \) | wc -l)"
  skills="$(find "$BOB_ROOT/skills" -type f \( -name '*.md' -o -name '*.txt' -o -name '*.yaml' -o -name '*.yml' \) | wc -l)"
  tools="$(find "$TOOLS_DIR" -maxdepth 1 -type f \( -name '*.md' -o -name '*.txt' -o -name '*.sh' -o -name '*.py' -o -name '*.yaml' -o -name '*.yml' \) | wc -l)"
  [[ "$(grep -RIl 'BQCA-CANONICAL-PRODUCTION-POLICY-v48:BEGIN' "$BOB_ROOT"/rules-* 2>/dev/null | wc -l)" -eq "$rules" ]] || { warn "not every rule file is v48-aware"; failures=$((failures+1)); }
  [[ "$(grep -RIl 'BQCA-CANONICAL-PRODUCTION-POLICY-v48:BEGIN' "$BOB_ROOT/skills" 2>/dev/null | wc -l)" -eq "$skills" ]] || { warn "not every skill file is v48-aware"; failures=$((failures+1)); }
  [[ "$(grep -Il 'BQCA-CANONICAL-PRODUCTION-POLICY-v48:BEGIN' "$TOOLS_DIR"/* 2>/dev/null | wc -l)" -eq "$tools" ]] || { warn "not every supported top-level tool is v48-aware"; failures=$((failures+1)); }

  for file in "$BQCA_ROOT/xLaunchpad.sh" "$TOOLS_DIR/bqca-direct-execution.sh" "$TOOLS_DIR/bqca-policy-doctor.sh" "$TOOLS_DIR/bqca-policy-orchestrator.sh" "$TOOLS_DIR/qiskit-v2x-environment.sh" "$TOOLS_DIR/qiskit-connector.sh" "$TOOLS_DIR/qca-code-quality-guard.sh"; do
    [[ -x "$file" ]] || { warn "missing executable: $file"; failures=$((failures+1)); continue; }
    bash -n "$file" || failures=$((failures+1))
  done
  while IFS= read -r -d '' file; do python3 -m py_compile "$file" || failures=$((failures+1)); done < <(find "$TOOLS_DIR" -type f -name '*.py' -not -path '*/examples/*' -print0)

  grep -q 'BQCA-POLICY-ASSURANCE-v48:BEGIN' "$BQCA_ROOT/xLaunchpad.sh" || { warn "xLaunchpad lacks v48 assurance"; failures=$((failures+1)); }
  while IFS= read -r -d '' file; do grep -q 'BQCA-DIRECT-EXECUTION-EXPORT-v48:BEGIN' "$file" || { warn "$file lacks v48 export"; failures=$((failures+1)); }; done < <(find "$BQCA_ROOT" -maxdepth 1 -type f -name 'bob-quantum-v*.sh' -print0)

  grep -q 'POLICY_VERSION="v48"' "$TOOLS_DIR/bqca-direct-execution.sh" || { warn "direct executor is not v48"; failures=$((failures+1)); }
  grep -q 'BQCA v48 DIRECT QUANTUM EXECUTION RESULT OUTPUT' "$TOOLS_DIR/bqca-direct-execution.sh" || { warn "direct result title is not v48"; failures=$((failures+1)); }
  grep -q 'BQCA_V48_POLICY_ASSURANCE' "$TOOLS_DIR/bqca-policy-doctor.py" || { warn "policy doctor is not v48"; failures=$((failures+1)); }

  "$TOOLS_DIR/bqca-quantum-kb.sh" validate >/dev/null || { warn "local knowledgebase validation failed"; failures=$((failures+1)); }
  catalog_entries="$(python3 - "$TOOLS_DIR/knowlegebase/bqca_quantum_algorithm_catalog.json" <<'PY_KB'
import json,sys
x=json.load(open(sys.argv[1],encoding='utf-8')); assert x.get('catalog_version')=='BQCA.v48'; print(len(x.get('entries',[])))
PY_KB
)" || { warn "invalid v48 algorithm catalog"; failures=$((failures+1)); catalog_entries=0; }
  design_cards="$(find "$TOOLS_DIR/knowlegebase/examples" -maxdepth 1 -type f -name '*-design.md' | wc -l)"
  code_examples="$(find "$TOOLS_DIR/knowlegebase/examples" -maxdepth 1 -type f -name '*.py' | wc -l)"
  [[ "$catalog_entries" -ge 80 && "$design_cards" -ge 80 && "$code_examples" -ge 60 ]] || { warn "knowledgebase coverage is incomplete: entries=$catalog_entries designs=$design_cards code=$code_examples"; failures=$((failures+1)); }

  local test_root test_py test_result test_mirror
  test_root="$(mktemp -d)"; test_py="$test_root/v48-smoke.py"
  cat > "$test_py" <<'PY_SMOKE'
import sys
print('V48_STDOUT_VISIBLE', flush=True)
print('V48_STDERR_VISIBLE', file=sys.stderr, flush=True)
print('BQCA_EXECUTION_TARGET=SIMULATOR', flush=True)
print('BQCA_PLAN=TEST', flush=True)
print('BQCA_BACKEND=local-test', flush=True)
print('BQCA_FALLBACK_REASON=isolated smoke test', flush=True)
print('BQCA_RESULT=SUCCESS', flush=True)
print('BQCA_RESULT_VALUE=48', flush=True)
PY_SMOKE
  BQCA_V48_TEST_MODE=1 BQCA_V48_PYTHON_BIN="$(command -v python3)" "$TOOLS_DIR/bqca-direct-execution.sh" run "$test_py" >/dev/null 2>&1 || { warn "v48 direct execution smoke test failed"; failures=$((failures+1)); }
  test_result="$test_root/v48-smoke-result-output.txt"; test_mirror="$test_root/output.txt"
  [[ -f "$test_result" && -f "$test_mirror" ]] || { warn "v48 dual result files were not generated"; failures=$((failures+1)); }
  if [[ -f "$test_result" && -f "$test_mirror" ]]; then
    cmp -s "$test_result" "$test_mirror" || { warn "v48 result files differ"; failures=$((failures+1)); }
    grep -q 'BQCA v48 DIRECT QUANTUM EXECUTION RESULT OUTPUT' "$test_result" || { warn "v48 result format missing"; failures=$((failures+1)); }
    grep -q 'Execution successful    : YES' "$test_result" || { warn "v48 execution summary missing"; failures=$((failures+1)); }
  fi
  rm -rf "$test_root"

  if [[ -x "$TOOLS_DIR/bqca-policy-doctor.sh" ]]; then
    "$TOOLS_DIR/bqca-policy-doctor.sh" check --quiet || { warn "v48 policy doctor assurance failed"; failures=$((failures+1)); "$TOOLS_DIR/bqca-policy-doctor.sh" report || true; }
  fi

  if ((failures)); then fail "v48 validation failed with $failures issue(s)."; fi
  info "Validation passed: v48 is active; modes=$mode_actual rules=$rules skills=$skills tools=$tools catalog=$catalog_entries design_cards=$design_cards code_examples=$code_examples."
}

if ((VALIDATE_ONLY)); then validate_installation; exit 0; fi

create_backup
install_tools_payload
write_policy
archive_old_active_policies
patch_active_surfaces
rebuild_history_manifest
write_registry
normalize_permissions
write_patch_record
validate_installation

info "Patch $PATCH_ID applied successfully."
info "Active policy: .bob/BQCA-PRODUCTION-POLICY.md"
info "Versioned policy: .bob/BQCA-PRODUCTION-POLICY-v48.md"
info "Backup: $BACKUP_DIR"
info "Default execution: .bob/quantum-tools/bqca-direct-execution.sh"
info "Knowledgebase: .bob/quantum-tools/knowlegebase/bqca_quantum_algorithm_catalog.json"
info "Protected assets were not touched."
