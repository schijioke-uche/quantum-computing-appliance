#!/usr/bin/env bash
set -Eeuo pipefail

#===============================================================================
# BQCA Canonical Policy Runtime Assurance and Open Plan Primitive Patch v44
# File: patch-BQCA.v44.sh
# Author: Dr. Jeffrey Chijioke-Uche, IBM Computer Scientist
#
# Purpose:
#   Protect the v43 policy consolidation against drift and bypass, update the
#   canonical Open Plan rule so real-QPU job mode may use SamplerV2 or
#   EstimatorV2 as appropriate to the workload, and install one deterministic
#   assurance/repair/test framework for every active BQCA policy surface.
#
# Protected runtime assets:
#   This installer never reads, copies, backs up, modifies, chmods, removes, or
#   restores:
#     - <BQCA-root>/.env
#     - $HOME/qiskit-v2x-env
#     - $HOME/.qiskit/qiskit-ibm.json
#     - workload artifacts under bob-quantum-designs/ or bob-quantum-store/
#===============================================================================

PATCH_ID="BQCA.v44"
PATCH_FILE_NAME="patch-BQCA.v44.sh"
TIMESTAMP="$(date +%Y%m%d%H%M%S)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
TARGET_OVERRIDE=""
DRY_RUN=0
VALIDATE_ONLY=0
ROLLBACK_DIR=""

info() { printf '[BQCA v44][INFO] %s\n' "$*"; }
warn() { printf '[BQCA v44][WARN] %s\n' "$*" >&2; }
fail() { printf '[BQCA v44][ERROR] %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'USAGE'
BQCA Canonical Policy Runtime Assurance and Open Plan Primitive Patch v44

Usage:
  ./patch-BQCA.v44.sh [options]

Options:
  --target <path>        Explicit BQCA appliance root.
  --dry-run              Display the v44 plan without changing files.
  --validate-only        Validate the current v44 installation.
  --rollback <backup>    Restore a v44 backup directory.
  -h, --help             Show this help.

Expected placement:
  <BQCA-root>/patches/BQCA/patch-BQCA.v44.sh

Protected assets are never touched by the installer:
  .env
  $HOME/qiskit-v2x-env
  $HOME/.qiskit/qiskit-ibm.json
  bob-quantum-designs/*
  bob-quantum-store/*
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

for cmd in bash chmod cp date dirname find grep mkdir mktemp mv python3 rm sha256sum sort stat tr; do
  command -v "$cmd" >/dev/null 2>&1 || fail "Required command not found: $cmd"
done

is_bqca_root() {
  local candidate="$1"
  [[ -d "$candidate/.bob" ]] || return 1
  [[ -f "$candidate/.bob/custom_modes.yaml" ]] || return 1
  [[ -d "$candidate/.bob/skills" ]] || return 1
  [[ -d "$candidate/.bob/quantum-tools" ]] || return 1
  [[ -f "$candidate/.bob/BQCA-PRODUCTION-POLICY.md" ]] || return 1
  [[ -x "$candidate/.bob/quantum-tools/bqca-policy-orchestrator.sh" ]] || return 1
  [[ -f "$candidate/xLaunchpad.sh" ]] || return 1
  [[ -d "$candidate/bob-quantum-designs" ]] || return 1
  [[ -d "$candidate/bob-quantum-store" ]] || return 1
}

resolve_bqca_root() {
  local candidate dir
  if [[ -n "$TARGET_OVERRIDE" ]]; then
    candidate="$(cd "$TARGET_OVERRIDE" 2>/dev/null && pwd -P || true)"
    [[ -n "$candidate" ]] || fail "Target path does not exist: $TARGET_OVERRIDE"
    is_bqca_root "$candidate" || fail "Target is not a valid v43+ BQCA root: $candidate"
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
    if is_bqca_root "$dir"; then
      printf '%s\n' "$dir"
      return
    fi
    if is_bqca_root "$dir/quantum-computing-agent"; then
      printf '%s\n' "$dir/quantum-computing-agent"
      return
    fi
    dir="$(dirname "$dir")"
  done
  fail "Unable to locate the BQCA root. Use --target <path>."
}

BQCA_ROOT="$(resolve_bqca_root)"
BOB_ROOT="$BQCA_ROOT/.bob"
TOOLS_DIR="$BOB_ROOT/quantum-tools"
CUSTOM_MODES="$BOB_ROOT/custom_modes.yaml"
XLAUNCHPAD="$BQCA_ROOT/xLaunchpad.sh"
DESIGN_DIR="$BQCA_ROOT/bob-quantum-designs"
STORE_DIR="$BQCA_ROOT/bob-quantum-store"
PATCHES_DIR="$BQCA_ROOT/patches/BQCA"
CANONICAL_PATCH="$PATCHES_DIR/$PATCH_FILE_NAME"
HISTORY_DIR="$PATCHES_DIR/policy-history"
HISTORY_MANIFEST="$HISTORY_DIR/BQCA-policy-history-manifest.json"
TIMELINE_FILE="$HISTORY_DIR/BQCA-policy-timeline.md"
CANONICAL_POLICY="$BOB_ROOT/BQCA-PRODUCTION-POLICY.md"
PREVIOUS_VERSIONED_POLICY="$BOB_ROOT/BQCA-PRODUCTION-POLICY-v43.md"
VERSIONED_POLICY="$BOB_ROOT/BQCA-PRODUCTION-POLICY-v44.md"
REGISTRY_FILE="$BOB_ROOT/BQCA-ACTIVE-POLICY-REGISTRY.json"
ORCHESTRATOR_SH="$TOOLS_DIR/bqca-policy-orchestrator.sh"
ORCHESTRATOR_PY="$TOOLS_DIR/bqca-policy-orchestrator.py"
DOCTOR_SH="$TOOLS_DIR/bqca-policy-doctor.sh"
DOCTOR_PY="$TOOLS_DIR/bqca-policy-doctor.py"
DRIFT_GUARD_PY="$TOOLS_DIR/bqca-policy-drift-guard.py"
TEST_SUITE_PY="$TOOLS_DIR/bqca-policy-test-suite.py"
SECRET_SCANNER="$TOOLS_DIR/bqca-secret-scan.py"
CODE_VALIDATOR="$TOOLS_DIR/qiskit-code-policy-check.py"
DESIGN_VALIDATOR="$TOOLS_DIR/qiskit-design-policy-check.py"
CODE_TEMPLATE="$TOOLS_DIR/qiskit-connector-required-template.py"
DESIGN_TEMPLATE="$TOOLS_DIR/qiskit-connector-design-required-template.md"
CONFIG_TOOL="$TOOLS_DIR/qiskit-configuration.sh"
ENV_TOOL="$TOOLS_DIR/qiskit-v2x-environment.sh"
CONNECTOR_TOOL="$TOOLS_DIR/qiskit-connector.sh"
QUALITY_GUARD="$TOOLS_DIR/qca-code-quality-guard.sh"
RESULT_TOOL="$TOOLS_DIR/qiskit-result-output.sh"
RESULT_VALIDATOR="$TOOLS_DIR/qiskit-result-output-policy-check.py"
HOME_ENV_VALIDATOR="$TOOLS_DIR/qiskit-home-env-policy-check.py"
HELLO_SCOPE_VALIDATOR="$TOOLS_DIR/qiskit-hello-world-scope-check.py"
NOTEBOOK_GENERATOR="$TOOLS_DIR/notebook-generator.sh"
PATCH_RECORD_DIR="$BOB_ROOT/patches-applied"
PATCH_RECORD_FILE="$PATCH_RECORD_DIR/${PATCH_ID}.txt"
ASSURANCE_REPORT="$PATCH_RECORD_DIR/${PATCH_ID}-assurance-report.txt"
BACKUP_ROOT="$BOB_ROOT/patch-backups"
BACKUP_DIR="$BACKUP_ROOT/${PATCH_ID}.${TIMESTAMP}"
BACKUP_MANIFEST="$BACKUP_DIR/BQCA-v44-backup-manifest.txt"
CREATED_LIST="$BACKUP_DIR/BQCA-v44-created-files.txt"

is_protected_path() {
  local path="$1" home_abs
  home_abs="$(cd "${HOME:?HOME must be set}" && pwd -P)"
  [[ "$path" == "$BQCA_ROOT/.env" ]] && return 0
  [[ "$path" == "$home_abs/qiskit-v2x-env" || "$path" == "$home_abs/qiskit-v2x-env/"* ]] && return 0
  [[ "$path" == "$home_abs/.qiskit/qiskit-ibm.json" ]] && return 0
  [[ "$path" == "$DESIGN_DIR" || "$path" == "$DESIGN_DIR/"* ]] && return 0
  [[ "$path" == "$STORE_DIR" || "$path" == "$STORE_DIR/"* ]] && return 0
  return 1
}

backup_file() {
  local source="$1" rel destination
  [[ -e "$source" ]] || return 0
  is_protected_path "$source" && return 0
  rel="${source#$BQCA_ROOT/}"
  destination="$BACKUP_DIR/$rel"
  mkdir -p "$(dirname "$destination")"
  cp -a "$source" "$destination"
}

record_created() {
  local path="$1"
  [[ -e "$path" ]] && return 0
  printf '%s\n' "${path#$BQCA_ROOT/}" >> "$CREATED_LIST"
}

create_backup() {
  mkdir -p "$BACKUP_DIR"
  : > "$CREATED_LIST"

  for file in \
    "$CUSTOM_MODES" "$XLAUNCHPAD" "$CANONICAL_POLICY" \
    "$PREVIOUS_VERSIONED_POLICY" "$VERSIONED_POLICY" "$REGISTRY_FILE" \
    "$HISTORY_MANIFEST" "$TIMELINE_FILE" "$ORCHESTRATOR_SH" "$ORCHESTRATOR_PY" \
    "$DOCTOR_SH" "$DOCTOR_PY" "$DRIFT_GUARD_PY" "$TEST_SUITE_PY" \
    "$SECRET_SCANNER" "$CODE_VALIDATOR" "$DESIGN_VALIDATOR" "$CODE_TEMPLATE" \
    "$DESIGN_TEMPLATE" "$CONNECTOR_TOOL" "$QUALITY_GUARD" "$ENV_TOOL" \
    "$RESULT_TOOL" "$PATCH_RECORD_FILE" "$ASSURANCE_REPORT" "$CANONICAL_PATCH"; do
    backup_file "$file"
  done

  while IFS= read -r -d '' file; do
    backup_file "$file"
  done < <(find "$BOB_ROOT" -maxdepth 4 -type f \
    \( -path '*/rules-*/*' -o -path '*/skills/*' -o -path '*/quantum-tools/*' \) \
    -print0)

  while IFS= read -r -d '' file; do
    backup_file "$file"
  done < <(find "$BQCA_ROOT" -maxdepth 1 -type f -name 'bob-quantum-v*.sh' -print0)

  cat > "$BACKUP_MANIFEST" <<MANIFEST
Patch: $PATCH_ID
Created: $(date -u '+%Y-%m-%dT%H:%M:%SZ')
Appliance root: $BQCA_ROOT
Protected assets intentionally excluded:
  .env
  $HOME/qiskit-v2x-env
  $HOME/.qiskit/qiskit-ibm.json
  bob-quantum-designs/*
  bob-quantum-store/*
Restore with:
  $PATCH_FILE_NAME --target "$BQCA_ROOT" --rollback "$BACKUP_DIR"
MANIFEST
}

restore_backup() {
  local backup="$1" backup_abs source rel destination
  backup_abs="$(cd "$backup" 2>/dev/null && pwd -P || true)"
  [[ -n "$backup_abs" ]] || fail "Rollback directory not found: $backup"
  [[ -f "$backup_abs/BQCA-v44-backup-manifest.txt" ]] || fail "Not a BQCA v44 backup: $backup_abs"

  info "Restoring v44 backup: $backup_abs"
  while IFS= read -r -d '' source; do
    rel="${source#$backup_abs/}"
    case "$rel" in
      BQCA-v44-backup-manifest.txt|BQCA-v44-created-files.txt) continue ;;
    esac
    destination="$BQCA_ROOT/$rel"
    is_protected_path "$destination" && continue
    mkdir -p "$(dirname "$destination")"
    cp -a "$source" "$destination"
  done < <(find "$backup_abs" -mindepth 1 -type f -print0)

  if [[ -f "$backup_abs/BQCA-v44-created-files.txt" ]]; then
    while IFS= read -r rel; do
      [[ -n "$rel" ]] || continue
      destination="$BQCA_ROOT/$rel"
      is_protected_path "$destination" && continue
      [[ -e "$backup_abs/$rel" ]] || rm -f "$destination"
    done < "$backup_abs/BQCA-v44-created-files.txt"
  fi

  info "Rollback complete. Protected runtime assets were not touched."
}

if [[ -n "$ROLLBACK_DIR" ]]; then
  restore_backup "$ROLLBACK_DIR"
  exit 0
fi

info "Resolved BQCA root: $BQCA_ROOT"
info "Patch identity: $PATCH_ID"
info "Assurance target: protect the canonical policy, enforce delegation, and prevent drift"
info "Open Plan update: SamplerV2 or EstimatorV2 in job mode; Session prohibited"
info "Protected assets: .env, home Qiskit environment, account JSON, and workload artifacts"

[[ -f "$PATCH_RECORD_DIR/BQCA.v43.txt" ]] || \
  fail "BQCA v43 is not recorded as applied: $PATCH_RECORD_DIR/BQCA.v43.txt"

if ((DRY_RUN)); then
  cat <<'DRY'
[BQCA v44][DRY-RUN] Planned changes:
  1. Promote one canonical v44 policy and archive the versioned v43 policy.
  2. Update Open Plan job mode to permit SamplerV2(mode=backend) or
     EstimatorV2(mode=backend), selected according to workload semantics.
  3. Preserve the Open Plan prohibition on Session.
  4. Update textual design validation and executable code validation.
  5. Replace v43 awareness blocks with one v44 block in all custom modes,
     rules, skills, and supported quantum tools.
  6. Update the canonical orchestrator and every public execution wrapper.
  7. Prevent direct result-capture invocation from bypassing the orchestrator.
  8. Install policy doctor, drift guard, secret scanner, and isolated test suite.
  9. Add a quiet launch preflight that fails closed on policy drift.
 10. Produce a v44 assurance report and patch record.
 11. Leave protected runtime assets unchanged.
DRY
  exit 0
fi

write_canonical_policy() {
  record_created "$VERSIONED_POLICY"
  cat > "$VERSIONED_POLICY" <<'V44_POLICY'
# BQCA Canonical Production Policy v44

<!-- BQCA-CANONICAL-PRODUCTION-POLICY-v44:BEGIN -->

## 1. Authority and precedence

This document is the sole active natural-language production policy for the Bob Quantum Computing Agent (BQCA). Historical policies from v30 through v43 are audit records only. The stable active path is `.bob/BQCA-PRODUCTION-POLICY.md`; the versioned active copy is `.bob/BQCA-PRODUCTION-POLICY-v44.md`.

All custom modes, rules, skills, and supported quantum tools must refer to the stable policy and route design, code, pre-execution, execution, result, and completion enforcement through `.bob/quantum-tools/bqca-policy-orchestrator.sh`. `.bob/quantum-tools/bqca-policy-doctor.sh` verifies policy integrity, wrapper delegation, drift, and behavioral assurance.

## 2. IBM Bob and BQCA guiding principles

IBM Bob classifies user intent, clarifies missing scientific parameters, decomposes work, creates governed designs, generates implementation artifacts, validates and repairs code, coordinates Qiskit configuration and execution, produces synchronized notebooks and result evidence, and routes artifacts for review and reuse. Human experts retain responsibility for scientific assumptions, execution cost decisions, and interpretation of research results.

## 3. CODE intent

Treat a request as CODE intent immediately when the user uses `create`, `implement`, `write`, `generate`, `build`, `develop`, `produce`, `scaffold`, `construct`, `code`, `program`, `modify`, `update`, `repair`, `fix`, `refactor`, `complete`, `execute`, or equivalent wording and the object is quantum/Qiskit code or an executable quantum artifact. Do not wait for the exact phrase `create code`.

## 4. Governed artifact routing and secrets

- Research, architecture, and solution-design artifacts go to `bob-quantum-designs/`.
- Executable Python, notebooks, scripts, results, plots, logs, and implementation documentation go to `bob-quantum-store/`.
- Design and implementation artifacts remain separate and reviewable.
- Credentials and secrets must never be embedded in generated designs, code, notebooks, logs, compliance reports, or result-output files.

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

- **Open Plan:** real-QPU execution uses job mode without `Session`. Use `SamplerV2(mode=backend)` when the workload returns samples, bitstrings, counts, shots, or probability distributions. Use `EstimatorV2(mode=backend)` when the workload estimates expectation values, observables, energies, or Hamiltonians. The code must select the suitable V2 primitive for its computation.
- **Paid Plan:** real-QPU execution uses `Session(backend=backend)` with `SamplerV2(mode=session)` or `EstimatorV2(mode=session)` as appropriate.
- **Simulator fallback:** use a controlled `try/except` path, `transpile`, and `AerSimulator` or another supported local simulator.
- `backend.run()` is permitted only for a clearly local simulator and is prohibited for real IBM Quantum hardware. Real hardware uses Runtime V2 primitives.
- Generated code must emit canonical execution markers for target, plan, backend, result, fallback reason, and real-QPU Job ID.

## 9. Notebook production

The `.py` implementation is authoritative. The BQCA runtime watcher automatically creates or refreshes the same-name `.ipynb` sibling after the Python source becomes stable. The notebook must be structurally valid and synchronized to the source digest. Manual notebook construction is an emergency fallback only after genuine automatic-generation failure.

## 10. Hello World scope

Hello World is request-scoped. Do not add Hello World sections, tests, commands, artifacts, or `bob-quantum-store/test` dependencies to unrelated designs or code. For an explicit Hello World request, use an existing artifact under `bob-quantum-store/test/` and execute it through the authorized environment and canonical gate.

## 11. Result-output contract

Every `.py` or `.ipynb` execution must run through the BQCA execution gate so a professionally formatted `<source-stem>-result-output.txt` file is created beside the source. Capture complete combined stdout and stderr, including Qiskit Connector, plan, backend, real-QPU, simulator, fallback, warning, error, and result output. Include start/completion date and time, duration, command, source, backend, plan, target, and exit status.

For a final real-QPU result, the actual Job ID must be the first line. The bottom of the file must contain a `RESULT SUMMARY` stating whether execution was successful and whether the result contract passed.

## 12. Canonical validation and completion order

### Design

1. Validate design routing and textual-only format.
2. Validate Connector, account, and plan strategy.
3. Validate Open Plan no-Session behavior and suitable SamplerV2/EstimatorV2 job-mode selection.
4. Validate Paid Plan Session behavior.
5. Validate home environment, Qiskit 2.5+, simulator fallback, and hardware restrictions.
6. Validate Hello World scope, result-output contract, and secret handling.
7. Generate a policy-compliance report.

### Code

1. Validate CODE intent and implementation routing.
2. Validate Connector imports and initialization.
3. Validate Open Plan no-Session behavior and a suitable SamplerV2 or EstimatorV2 `mode=backend` branch.
4. Validate Paid Plan Session behavior.
5. Reject real-hardware `backend.run()`.
6. Validate QPU checks, simulator fallback, home environment, Qiskit 2.5+, Hello World scope, markers, and secret handling.
7. Generate or validate the synchronized notebook.
8. Generate a policy-compliance report.

### Execution

1. Pass the policy-doctor drift check.
2. Rebuild the `bqca` Qiskit account configuration.
3. Activate `$HOME/qiskit-v2x-env` and confirm Qiskit 2.5+.
4. Revalidate code.
5. Begin complete result capture.
6. Attempt real QPU first and use controlled simulator fallback when required.
7. Validate the result-output file, Job ID rule, summary, secret scan, and notebook synchronization.
8. Generate the final policy-compliance report.
9. Report completion only when the canonical gate passes.

## 13. Runtime assurance and bypass prevention

- Stable and versioned active policies must be byte-identical and match the registry SHA-256.
- Historical policy hashes must match the policy-history manifest.
- Every custom mode, rule, skill, and supported quantum tool must contain exactly one v44 canonical awareness block and no active v30-v43 block.
- Public validation and execution wrappers must delegate through the canonical orchestrator.
- Direct invocation of the result-capture layer is prohibited unless the orchestrator marks the call as internal.
- `xLaunchpad.sh` performs a quiet policy-doctor preflight and fails closed when drift is detected.
- Compliance or result evidence that contains credential material is noncompliant.

## 14. Historical disposition

Requirements from v30-v42 remain incorporated as documented by v43. v43 is incorporated as the canonical-consolidation predecessor. v44 is the sole active authority and adds assurance, drift detection, bypass prevention, secret scanning, and the Open Plan SamplerV2-or-EstimatorV2 primitive-selection clarification.

<!-- BQCA-CANONICAL-PRODUCTION-POLICY-v44:END -->
V44_POLICY
  cp "$VERSIONED_POLICY" "$CANONICAL_POLICY"
  chmod 644 "$VERSIONED_POLICY" "$CANONICAL_POLICY"
}

update_history_registry_and_timeline() {
  record_created "$VERSIONED_POLICY"
  mkdir -p "$HISTORY_DIR"
  python3 - "$BQCA_ROOT" "$PREVIOUS_VERSIONED_POLICY" "$VERSIONED_POLICY" \
    "$HISTORY_DIR" "$HISTORY_MANIFEST" "$REGISTRY_FILE" "$TIMELINE_FILE" <<'PY_REGISTRY'
from __future__ import annotations

import hashlib
import json
import pathlib
import shutil
import sys
from datetime import datetime, timezone

root = pathlib.Path(sys.argv[1])
previous = pathlib.Path(sys.argv[2])
current = pathlib.Path(sys.argv[3])
history = pathlib.Path(sys.argv[4])
manifest_path = pathlib.Path(sys.argv[5])
registry_path = pathlib.Path(sys.argv[6])
timeline_path = pathlib.Path(sys.argv[7])
history.mkdir(parents=True, exist_ok=True)


def digest(path: pathlib.Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

entries: list[dict[str, object]] = []
if manifest_path.is_file():
    try:
        entries = json.loads(manifest_path.read_text(encoding="utf-8")).get("entries", [])
    except Exception:
        entries = []

if previous.is_file():
    target = history / previous.name
    if target.exists() and digest(target) != digest(previous):
        target = history / f"{previous.stem}.pre-v44-{digest(previous)[:12]}{previous.suffix}"
    if not target.exists():
        shutil.copy2(previous, target)
    entry = {
        "version": "v43",
        "status": "incorporated",
        "scope": "canonical consolidation, precedence, orchestration, and completion gate",
        "original_path": str(previous.relative_to(root)),
        "archive_path": str(target.relative_to(root)),
        "sha256": digest(target),
        "size_bytes": target.stat().st_size,
    }
    by_path = {str(item.get("archive_path")): item for item in entries}
    by_path[entry["archive_path"]] = entry
    entries = sorted(by_path.values(), key=lambda item: (str(item.get("version")), str(item.get("archive_path"))))
    previous.unlink()

manifest = {
    "schema": "bqca-policy-history-manifest/v2",
    "generated_utc": datetime.now(timezone.utc).isoformat(),
    "active_policy": ".bob/BQCA-PRODUCTION-POLICY.md",
    "entries": entries,
}
manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

versions = []
if registry_path.is_file():
    try:
        old = json.loads(registry_path.read_text(encoding="utf-8"))
        versions = old.get("versions", [])
    except Exception:
        versions = []
for item in versions:
    if item.get("version") == "v43":
        item["status"] = "incorporated"
        item["scope"] = "canonical consolidation predecessor retained through v44"
versions = [item for item in versions if item.get("version") != "v44"]
versions.append({
    "version": "v44",
    "status": "active authority",
    "scope": "runtime assurance, drift/bypass prevention, and Open Plan SamplerV2-or-EstimatorV2 job-mode clarification",
})
registry = {
    "schema": "bqca-active-policy-registry/v2",
    "generated_utc": datetime.now(timezone.utc).isoformat(),
    "active_authority": {
        "version": "v44",
        "stable_policy": ".bob/BQCA-PRODUCTION-POLICY.md",
        "versioned_policy": ".bob/BQCA-PRODUCTION-POLICY-v44.md",
        "policy_sha256": digest(current),
        "orchestrator": ".bob/quantum-tools/bqca-policy-orchestrator.sh",
        "doctor": ".bob/quantum-tools/bqca-policy-doctor.sh",
    },
    "historical_policy_directory": "patches/BQCA/policy-history",
    "precedence": [
        "BQCA-PRODUCTION-POLICY.md is the sole active natural-language authority.",
        "Historical policy files are audit records only.",
        "All public design, code, and execution routes must delegate through the canonical orchestrator.",
        "Open Plan real-QPU job mode uses SamplerV2 or EstimatorV2 as appropriate and never Session.",
    ],
    "versions": versions,
}
registry_path.write_text(json.dumps(registry, indent=2) + "\n", encoding="utf-8")

lines = [
    "# BQCA Policy Timeline and Disposition",
    "",
    "The stable active authority is `.bob/BQCA-PRODUCTION-POLICY.md` (v45).",
    "",
    "| Version | Status | Scope |",
    "|---|---|---|",
]
for item in versions:
    lines.append(f"| {item.get('version')} | {item.get('status')} | {item.get('scope')} |")
lines.extend([
    "",
    "Historical policies are audit records only. Active BQCA components use the stable policy and the v44 orchestrator.",
])
timeline_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY_REGISTRY
}

write_secret_scanner() {
  record_created "$SECRET_SCANNER"
  cat > "$SECRET_SCANNER" <<'PY_SECRET'
#!/usr/bin/env python3
"""BQCA v44 credential-leak scanner.

The scanner never reads .env. It checks supplied artifacts for known secret
variable assignments, bearer/token syntax, private keys, and currently exported
secret values without printing any secret material.
"""
from __future__ import annotations

import argparse
import os
import pathlib
import re
import sys

SECRET_NAMES = (
    "IQP_API_TOKEN",
    "BOB_API_KEY",
    "IBM_QUANTUM_TOKEN",
    "QISKIT_IBM_TOKEN",
    "API_KEY",
    "ACCESS_TOKEN",
)
PATTERNS = (
    (re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----"), "private key material"),
    (re.compile(r"(?i)\b(?:bearer|token)\s+[A-Za-z0-9._~+/=-]{24,}"), "bearer/token value"),
    (re.compile(r"(?i)\b(?:IQP_API_TOKEN|BOB_API_KEY|IBM_QUANTUM_TOKEN|QISKIT_IBM_TOKEN)\s*[:=]\s*['\"]?[A-Za-z0-9._~+/=-]{12,}"), "named credential assignment"),
)


def validate(path: pathlib.Path, use_env: bool) -> list[str]:
    try:
        data = path.read_text(encoding="utf-8", errors="replace")
    except OSError as exc:
        return [f"cannot read artifact: {exc}"]
    problems: list[str] = []
    for pattern, label in PATTERNS:
        if pattern.search(data):
            problems.append(label)
    if use_env:
        for name in SECRET_NAMES:
            value = os.environ.get(name, "")
            if len(value) >= 8 and value in data:
                problems.append(f"exported secret value from {name}")
    return sorted(set(problems))


def main() -> int:
    parser = argparse.ArgumentParser(description="BQCA v44 secret scanner")
    parser.add_argument("--use-env", action="store_true")
    parser.add_argument("paths", nargs="+")
    args = parser.parse_args()
    failed = False
    for raw in args.paths:
        path = pathlib.Path(raw)
        problems = validate(path, args.use_env)
        if problems:
            failed = True
            print(f"BQCA_SECRET_SCAN_V44=FAIL file={path}")
            for problem in problems:
                print(f"  - {problem}")
        else:
            print(f"BQCA_SECRET_SCAN_V44=PASS file={path}")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
PY_SECRET
  chmod 755 "$SECRET_SCANNER"
}

write_code_validator() {
  cat > "$CODE_VALIDATOR" <<'PY_CODE'
#!/usr/bin/env python3
"""BQCA v44 Qiskit 2.5+ plan-aware code-policy validator."""
from __future__ import annotations

import argparse
import ast
import pathlib
import re
import sys
from typing import Iterable

REQ_IMPORTS = {
    ("qiskit_connector", "QConnectorV2", "connector"),
    ("qiskit_connector", "QPlanV2", "plan"),
}
SIMULATOR_NAMES = {"AerSimulator", "BasicSimulator", "StatevectorSimulator"}


def read_source(path: pathlib.Path) -> tuple[str, ast.AST]:
    text = path.read_text(encoding="utf-8")
    return text, ast.parse(text, filename=str(path))


def imports_qiskit(tree: ast.AST) -> bool:
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            if any(alias.name == "qiskit" or alias.name.startswith(("qiskit.", "qiskit_")) for alias in node.names):
                return True
        elif isinstance(node, ast.ImportFrom):
            module = node.module or ""
            if module == "qiskit" or module.startswith(("qiskit.", "qiskit_")):
                return True
    return False


def imported_aliases(tree: ast.AST) -> set[tuple[str, str, str | None]]:
    output: set[tuple[str, str, str | None]] = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.ImportFrom):
            for alias in node.names:
                output.add((node.module or "", alias.name, alias.asname))
    return output


def runtime_aliases(tree: ast.AST) -> tuple[set[str], set[str], set[str]]:
    samplers = {"SamplerV2"}
    estimators = {"EstimatorV2"}
    sessions = {"Session"}
    for node in ast.walk(tree):
        if not isinstance(node, ast.ImportFrom) or (node.module or "") != "qiskit_ibm_runtime":
            continue
        for alias in node.names:
            local = alias.asname or alias.name
            if alias.name == "SamplerV2":
                samplers.add(local)
            elif alias.name == "EstimatorV2":
                estimators.add(local)
            elif alias.name == "Session":
                sessions.add(local)
    return samplers, estimators, sessions


def call_name(call: ast.Call) -> str:
    if isinstance(call.func, ast.Name):
        return call.func.id
    if isinstance(call.func, ast.Attribute):
        return call.func.attr
    return ""


def target_names(node: ast.Assign | ast.AnnAssign) -> Iterable[str]:
    targets = node.targets if isinstance(node, ast.Assign) else [node.target]
    for target in targets:
        if isinstance(target, ast.Name):
            yield target.id


def has_assignment(tree: ast.AST, target: str, function: str) -> bool:
    for node in ast.walk(tree):
        if isinstance(node, (ast.Assign, ast.AnnAssign)) and isinstance(node.value, ast.Call):
            if call_name(node.value) == function and target in set(target_names(node)):
                return True
    return False


def unparse(node: ast.AST) -> str:
    try:
        return ast.unparse(node)
    except Exception:
        return ""


def calls_in(statements: list[ast.stmt]) -> list[ast.Call]:
    module = ast.Module(body=statements, type_ignores=[])
    return [node for node in ast.walk(module) if isinstance(node, ast.Call)]


def is_mode_call(call: ast.Call, names: set[str], mode_name: str) -> bool:
    if call_name(call) not in names:
        return False
    return any(
        keyword.arg == "mode" and isinstance(keyword.value, ast.Name) and keyword.value.id == mode_name
        for keyword in call.keywords
    )


def has_session_call(statements: list[ast.stmt], session_names: set[str]) -> bool:
    return any(call_name(call) in session_names for call in calls_in(statements))


def find_open_plan_if(tree: ast.AST) -> ast.If | None:
    for node in ast.walk(tree):
        if not isinstance(node, ast.If):
            continue
        test = unparse(node.test).lower()
        if "is_open_plan" in test or ("open" in test and ("plan" in test or "current" in test)):
            return node
    return None


def open_job_primitives(node: ast.If, samplers: set[str], estimators: set[str]) -> set[str]:
    found: set[str] = set()
    for call in calls_in(node.body):
        if is_mode_call(call, samplers, "backend"):
            found.add("SamplerV2")
        if is_mode_call(call, estimators, "backend"):
            found.add("EstimatorV2")
    return found


def has_paid_session_strategy(node: ast.If, samplers: set[str], estimators: set[str], sessions: set[str]) -> bool:
    statements = node.orelse
    if not statements:
        return False
    return has_session_call(statements, sessions) and any(
        is_mode_call(call, samplers | estimators, "session") for call in calls_in(statements)
    )


def simulator_receiver_name(call: ast.Call) -> str:
    if not isinstance(call.func, ast.Attribute) or call.func.attr != "run":
        return ""
    return unparse(call.func.value)


def simulator_operations_ok(statements: list[ast.stmt]) -> bool:
    calls = calls_in(statements)
    has_simulator = any(call_name(call) in SIMULATOR_NAMES for call in calls)
    has_transpile = any(call_name(call) == "transpile" for call in calls)
    has_local_run = any(
        simulator_receiver_name(call)
        and any(token in simulator_receiver_name(call).lower() for token in ("sim", "aer", "local"))
        for call in calls
    )
    return has_simulator and has_transpile and has_local_run


def simulator_fallback_ok(tree: ast.AST) -> bool:
    functions = {
        node.name: node.body
        for node in ast.walk(tree)
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))
    }
    for node in ast.walk(tree):
        if not isinstance(node, ast.Try):
            continue
        handler_statements = [statement for handler in node.handlers for statement in handler.body]
        if simulator_operations_ok(handler_statements):
            return True
        for call in calls_in(handler_statements):
            name = call_name(call)
            if name in functions and any(token in name.lower() for token in ("sim", "fallback")):
                if simulator_operations_ok(functions[name]):
                    return True
    return False


def invalid_backend_runs(tree: ast.AST) -> list[int]:
    lines: list[int] = []
    for node in ast.walk(tree):
        if not isinstance(node, ast.Call) or not isinstance(node.func, ast.Attribute) or node.func.attr != "run":
            continue
        receiver = unparse(node.func.value).lower()
        if receiver == "backend" or ("backend" in receiver and not any(token in receiver for token in ("sim", "aer", "local"))):
            lines.append(getattr(node, "lineno", 0))
    return lines


def reporting_ok(tree: ast.AST) -> bool:
    strings = [node.value.upper() for node in ast.walk(tree) if isinstance(node, ast.Constant) and isinstance(node.value, str)]
    joined = "\n".join(strings)
    return "REAL_QPU" in joined and "SIMULATOR" in joined


def qpu_checks_ok(tree: ast.AST) -> bool:
    text = unparse(tree).lower()
    availability = any(token in text for token in ("operational", "status", "simulator", "is_simulator"))
    capacity = any(token in text for token in ("num_qubits", "required_qubits", "qubit_capacity"))
    return availability and capacity


def validate(path: pathlib.Path) -> list[str]:
    try:
        text, tree = read_source(path)
    except (OSError, UnicodeError, SyntaxError) as exc:
        return [f"cannot parse Python file: {exc}"]
    if not imports_qiskit(tree):
        return []

    problems: list[str] = []
    aliases = imported_aliases(tree)
    for required in sorted(REQ_IMPORTS):
        if required not in aliases:
            module, name, alias = required
            problems.append(f"missing exact import: from {module} import {name} as {alias}")
    if not has_assignment(tree, "current", "plan"):
        problems.append("missing executable assignment: current = plan()")
    if not has_assignment(tree, "backend", "connector"):
        problems.append("missing executable assignment: backend = connector()")
    if "$HOME/qiskit-v2x-env" not in text and "~/qiskit-v2x-env" not in text:
        problems.append("missing $HOME/qiskit-v2x-env execution contract marker")
    if not re.search(r"(?is)qiskit.{0,80}(?:>=|version|minimum|min).{0,30}2\.5|2\.5.{0,80}qiskit", text):
        problems.append("missing explicit Qiskit 2.5-or-later requirement")

    samplers, estimators, sessions = runtime_aliases(tree)
    open_branch = find_open_plan_if(tree)
    if open_branch is None:
        problems.append("missing explicit Open Plan execution branch")
    else:
        primitives = open_job_primitives(open_branch, samplers, estimators)
        if not primitives:
            problems.append("Open Plan branch must use SamplerV2(mode=backend) or EstimatorV2(mode=backend) job mode")
        if has_session_call(open_branch.body, sessions):
            problems.append("Open Plan branch illegally constructs or uses Session")
        if not has_paid_session_strategy(open_branch, samplers, estimators, sessions):
            problems.append("Paid Plan branch must use Session with SamplerV2/EstimatorV2 mode=session")

    if not simulator_fallback_ok(tree):
        problems.append("missing try/except simulator fallback using transpile plus AerSimulator/local simulator run")
    bad_lines = invalid_backend_runs(tree)
    if bad_lines:
        problems.append("backend.run() is prohibited for real QPU backends; offending line(s): " + ", ".join(map(str, bad_lines)))
    if not qpu_checks_ok(tree):
        problems.append("missing QPU availability/operational and qubit-capacity checks")
    if not reporting_ok(tree):
        problems.append("missing explicit REAL_QPU and SIMULATOR execution reporting")
    return problems


def main() -> int:
    parser = argparse.ArgumentParser(description="BQCA v44 Qiskit code policy validator")
    parser.add_argument("paths", nargs="+")
    args = parser.parse_args()
    failed = False
    for raw in args.paths:
        path = pathlib.Path(raw)
        problems = validate(path)
        if problems:
            failed = True
            print(f"BQCA_QISKIT_CODE_POLICY_V44=FAIL file={path}")
            for problem in problems:
                print(f"  - {problem}")
        else:
            print(f"BQCA_QISKIT_CODE_POLICY_V44=PASS file={path}")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
PY_CODE
  chmod 755 "$CODE_VALIDATOR"
}

write_design_validator() {
  cat > "$DESIGN_VALIDATOR" <<'PY_DESIGN'
#!/usr/bin/env python3
"""BQCA v44 textual Qiskit design-policy validator."""
from __future__ import annotations

import argparse
import pathlib
import re
import sys

REQUIRED_PATTERNS = [
    (r"(?i)BQCA Qiskit 2\.5\+ Home Environment and Plan Policy|BQCA v44 Open Plan Primitive Policy", "v44 plan-policy section title"),
    (r"(?i)(?:\$HOME|~)/qiskit-v2x-env", "home-scoped qiskit-v2x-env path"),
    (r"(?i)source\s+(?:\"?\$HOME|~)/qiskit-v2x-env/bin/activate", "home environment activation command"),
    (r"(?is)(?:(?:project\s+root|project-local).{0,180}qiskit-v2x-env.{0,180}(?:prohibited|forbidden|must\s+not|never)|qiskit-v2x-env.{0,180}(?:prohibited|forbidden|must\s+not|never).{0,180}(?:project\s+root|project-local))", "project-local environment prohibition"),
    (r"(?i)Qiskit.{0,100}(?:2\.5|2\.5\+|2\.5 or later)", "Qiskit 2.5-or-later requirement"),
    (r"(?is)Open Plan.{0,360}(?:(?:must\s+not|never|prohibited|forbidden|not\s+allowed).{0,100}Session|Session.{0,100}(?:prohibited|forbidden|not\s+allowed|must\s+not)|(?:no|without)\s+Session)", "Open Plan no-Session rule"),
    (r"SamplerV2\s*\(\s*mode\s*=\s*backend\s*\)", "Open Plan SamplerV2(mode=backend) option"),
    (r"EstimatorV2\s*\(\s*mode\s*=\s*backend\s*\)", "Open Plan EstimatorV2(mode=backend) option"),
    (r"(?is)(?:SamplerV2.{0,220}(?:sampling|sample|shot|count|distribution)|(?:sampling|sample|shot|count|distribution).{0,220}SamplerV2)", "SamplerV2 workload-suitability guidance"),
    (r"(?is)(?:EstimatorV2.{0,220}(?:expectation|observable|energy|Hamiltonian)|(?:expectation|observable|energy|Hamiltonian).{0,220}EstimatorV2)", "EstimatorV2 workload-suitability guidance"),
    (r"(?is)(?:Paid Plan|Flex|Pay-As-You-Go|Premium|Dedicated).{0,360}Session", "Paid Plan Session strategy"),
    (r"(?is)(?:SamplerV2|EstimatorV2).{0,180}mode\s*=\s*session", "Paid Plan Runtime primitive requirement"),
    (r"(?is)try\s*/?\s*except|try.{0,160}except", "try/except fallback requirement"),
    (r"(?i)AerSimulator", "AerSimulator fallback requirement"),
    (r"(?is)transpile.{0,220}(?:AerSimulator|simulator)|(?:AerSimulator|simulator).{0,220}transpile", "simulator transpilation requirement"),
    (r"(?is)backend\.run\(\).{0,220}(?:local simulator|Aer|simulator).{0,220}(?:only|permitted)|(?:local simulator|Aer|simulator).{0,220}backend\.run\(\).{0,220}(?:only|permitted)", "backend.run local-simulator-only rule"),
    (r"(?is)(?:backend\.run\(\).{0,220}(?:real QPU|hardware).{0,140}(?:prohibited|forbidden|must\s+not|not\s+allowed)|(?:real QPU|hardware).{0,220}backend\.run\(\).{0,140}(?:prohibited|forbidden|must\s+not|not\s+allowed)|backend\.run\(\).{0,180}(?:prohibited|forbidden|must\s+not|not\s+allowed).{0,180}(?:real QPU|hardware))", "real-QPU backend.run prohibition"),
    (r"(?is)create|implement|write|generate|build|develop|produce|scaffold|construct|code|program|modify|update|repair|fix|refactor|complete|execute", "CODE-intent action classification"),
]

HELLO_VARIANT = re.compile(r"(?i)(?:\bhello[\s_-]*world\b|\bhellow[\s_-]*world\b)")
HELLO_REFERENCE = re.compile(r"(?i)(?:bob-quantum-store[/\\]test|hello[-_]?world\.(?:py|ipynb)|hellow[-_]?world\.(?:py|ipynb)|run\s+(?:qiskit\s+)?hello[\s_-]*world|hello[\s_-]*world\s+(?:test|testing|smoke\s*test|artifact|example|requirement))")
PYTHON_FENCE = re.compile(r"```\s*(python|py)\b.*?```", re.I | re.S)
EXECUTABLE_BLOCK = re.compile(r"(?s)```[^\n]*\n.*?(?:from\s+qiskit|current\s*=\s*plan\s*\(|backend\s*=\s*connector\s*\(|try\s*:).*?```", re.I)


def normalized(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", value.lower())


def is_hello_world_design(path: pathlib.Path, text: str) -> bool:
    stem = normalized(path.stem)
    if "helloworld" in stem or "hellowworld" in stem:
        return True
    for raw in text.splitlines():
        line = raw.strip()
        if not line:
            continue
        if line.startswith("#"):
            return bool(HELLO_VARIANT.search(line.lstrip("#").strip()))
        break
    return False


def validate(path: pathlib.Path) -> list[str]:
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as exc:
        return [f"cannot read design file: {exc}"]
    problems: list[str] = []
    hello_design = is_hello_world_design(path, text)
    if PYTHON_FENCE.search(text) or EXECUTABLE_BLOCK.search(text):
        problems.append("design contains executable/fenced Python; use textual instructions only")
    for pattern, label in REQUIRED_PATTERNS:
        if not re.search(pattern, text):
            problems.append(f"missing {label}")
    if not hello_design and (HELLO_VARIANT.search(text) or HELLO_REFERENCE.search(text)):
        problems.append("Hello World content is prohibited in a non-Hello-World design")
    return problems


def main() -> int:
    parser = argparse.ArgumentParser(description="BQCA v44 textual design validator")
    parser.add_argument("paths", nargs="+")
    args = parser.parse_args()
    failed = False
    for raw in args.paths:
        path = pathlib.Path(raw)
        problems = validate(path)
        if problems:
            failed = True
            print(f"BQCA_QISKIT_DESIGN_POLICY_V44=FAIL file={path}")
            for problem in problems:
                print(f"  - {problem}")
        else:
            print(f"BQCA_QISKIT_DESIGN_POLICY_V44=PASS file={path}")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
PY_DESIGN
  chmod 755 "$DESIGN_VALIDATOR"
}

write_templates() {
  cat > "$CODE_TEMPLATE" <<'PY_TEMPLATE'
#!/usr/bin/env python3
"""BQCA v44 Qiskit 2.5+ plan-aware execution template.

Execute only with:
  .bob/quantum-tools/bqca-policy-orchestrator.sh execute <this-file.py>

Open Plan uses job mode without Session. Select SamplerV2 for sample/count/
distribution workloads or EstimatorV2 for expectation-value/observable/energy
workloads. The v44 gate writes <this-file>-result-output.txt beside the source.
"""
from __future__ import annotations

from typing import Any

from qiskit import QuantumCircuit, transpile
from qiskit.quantum_info import SparsePauliOp
from qiskit_aer import AerSimulator
from qiskit_ibm_runtime import EstimatorV2, SamplerV2, Session
from qiskit_connector import QConnectorV2 as connector
from qiskit_connector import QPlanV2 as plan

BQCA_REQUIRED_ENV = "$HOME/qiskit-v2x-env"
BQCA_MIN_QISKIT_VERSION = "Qiskit >= 2.5"
BQCA_RESULT_OUTPUT_POLICY = "qiskit-result-output through the v44 orchestrator"

current = plan()
backend = connector()


def normalized_plan(value: object) -> str:
    return str(value).strip().lower().replace("_", " ").replace("-", " ")


def is_open_plan(value: object) -> bool:
    return "open" in normalized_plan(value)


def backend_name(candidate: Any) -> str:
    value = getattr(candidate, "name", None)
    return str(value() if callable(value) else value or candidate.__class__.__name__)


def backend_is_simulator(candidate: Any) -> bool:
    configuration = getattr(candidate, "configuration", None)
    if callable(configuration):
        try:
            return bool(getattr(configuration(), "simulator", False))
        except Exception:
            pass
    return bool(getattr(candidate, "simulator", False))


def backend_is_operational(candidate: Any) -> bool:
    status = getattr(candidate, "status", None)
    if callable(status):
        try:
            return bool(getattr(status(), "operational", True))
        except Exception:
            return True
    return True


def backend_qubits(candidate: Any) -> int:
    direct = getattr(candidate, "num_qubits", None)
    if isinstance(direct, int):
        return direct
    configuration = getattr(candidate, "configuration", None)
    if callable(configuration):
        try:
            return int(getattr(configuration(), "n_qubits", 0))
        except Exception:
            return 0
    return 0


def execute_real_qpu(circuit: QuantumCircuit, observable: SparsePauliOp | None = None, shots: int = 1024):
    required_qubits = circuit.num_qubits
    if backend_is_simulator(backend):
        raise RuntimeError("Qiskit Connector returned a simulator instead of a real QPU")
    if not backend_is_operational(backend):
        raise RuntimeError("The selected real QPU is not operational")
    if backend_qubits(backend) < required_qubits:
        raise RuntimeError("The selected real QPU has insufficient qubit capacity")

    isa_circuit = transpile(circuit, backend=backend, optimization_level=3)
    if is_open_plan(current):
        # Open Plan: job mode only; Session is prohibited.
        if observable is None:
            primitive = SamplerV2(mode=backend)  # samples, shots, counts, distributions
            job = primitive.run([isa_circuit], shots=shots)
        else:
            primitive = EstimatorV2(mode=backend)  # expectation values, observables, energies
            job = primitive.run([(isa_circuit, observable)])
        result = job.result()
    else:
        # Paid Plan: Session is permitted and selected by workload semantics.
        with Session(backend=backend) as session:
            if observable is None:
                primitive = SamplerV2(mode=session)
                job = primitive.run([isa_circuit], shots=shots)
            else:
                primitive = EstimatorV2(mode=session)
                job = primitive.run([(isa_circuit, observable)])
            result = job.result()

    print("BQCA_EXECUTION_TARGET=REAL_QPU")
    print(f"BQCA_JOB_ID={job.job_id()}")
    print(f"BQCA_PLAN={current}")
    print(f"BQCA_BACKEND={backend_name(backend)}")
    return result


def execute_simulator(circuit: QuantumCircuit, shots: int = 1024):
    sim_backend = AerSimulator()
    sim_circuit = transpile(circuit, backend=sim_backend, optimization_level=3)
    sim_job = sim_backend.run(sim_circuit, shots=shots)
    result = sim_job.result()
    print("BQCA_EXECUTION_TARGET=SIMULATOR")
    print(f"BQCA_PLAN={current}")
    print(f"BQCA_BACKEND={backend_name(sim_backend)}")
    return result


def execute(circuit: QuantumCircuit, observable: SparsePauliOp | None = None, shots: int = 1024):
    try:
        return execute_real_qpu(circuit, observable=observable, shots=shots)
    except Exception as exc:
        print(f"BQCA_FALLBACK_REASON={exc}")
        return execute_simulator(circuit, shots=shots)


def build_circuit() -> QuantumCircuit:
    circuit = QuantumCircuit(2)
    circuit.h(0)
    circuit.cx(0, 1)
    circuit.measure_all()
    return circuit


if __name__ == "__main__":
    final_result = execute(build_circuit())
    print(f"BQCA_RESULT={final_result}")
PY_TEMPLATE
  chmod 644 "$CODE_TEMPLATE"

  cat > "$DESIGN_TEMPLATE" <<'MD_TEMPLATE'
# BQCA v44 Quantum Solution Design Template

## Problem and algorithm

Describe the research problem, selected quantum algorithm, scientific assumptions, qubit/circuit strategy, risks, validation criteria, and expected artifacts.

## BQCA Qiskit 2.5+ Home Environment and Plan Policy

The implementation must use `$HOME/qiskit-v2x-env`, activated with `source $HOME/qiskit-v2x-env/bin/activate`. A project-local `qiskit-v2x-env` is prohibited. Qiskit package inspection, installation, upgrade, uninstall, validation, and execution occur only in the activated home environment. Qiskit 2.5 or later is required.

Before Qiskit Connector or backend work, the implementation must pass the BQCA configuration gate and use the single default `bqca` profile.

### Open Plan real-QPU job mode

Open Plan must not use `Session`. The implementation must choose the suitable Runtime V2 primitive according to workload semantics:

- Use `SamplerV2(mode=backend)` for sampling, shot, count, bitstring, and probability-distribution workloads.
- Use `EstimatorV2(mode=backend)` for expectation-value, observable, energy, and Hamiltonian workloads.

The design-to-code transition must preserve this primitive choice.

### Paid Plan real-QPU mode

For Flex, Pay-As-You-Go, Premium, Dedicated, or another paid plan, use `Session(backend=backend)` with `SamplerV2(mode=session)` or `EstimatorV2(mode=session)` according to workload semantics.

### Real-QPU-first and simulator fallback

The code must verify backend operational status and qubit capacity, attempt an eligible real QPU first, and use a controlled try/except fallback with `transpile` and `AerSimulator` or another supported local simulator. `backend.run()` is permitted only for a clearly local simulator and is prohibited for real QPU hardware.

## Result-output contract

Execute through `.bob/quantum-tools/bqca-policy-orchestrator.sh execute`. Produce `<code-name>-result-output.txt` in the same directory as the source. Capture complete stdout and combined stderr, including Qiskit Connector output. Include date/time, duration, plan, backend, target, result, fallback reason, and a bottom `RESULT SUMMARY` stating whether execution was successful. For real-QPU output, put the actual Job ID on the first line.

## Artifact contract

Route this textual design to `bob-quantum-designs/`. Route Python, synchronized notebook, result output, plots, logs, and implementation documentation to `bob-quantum-store/`.
MD_TEMPLATE
  chmod 644 "$DESIGN_TEMPLATE"
}

write_orchestrator_python() {
  cat > "$ORCHESTRATOR_PY" <<'PY_ORCH'
#!/usr/bin/env python3
"""BQCA v44 canonical-policy registry, scan, and compliance helper."""
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
        "BQCA v44 POLICY COMPLIANCE REPORT",
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
PY_ORCH
  chmod 755 "$ORCHESTRATOR_PY"
}

write_orchestrator_shell() {
  cat > "$ORCHESTRATOR_SH" <<'SH_ORCH'
#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
BOB_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
BQCA_ROOT="$(cd "$BOB_ROOT/.." && pwd -P)"
POLICY="$BOB_ROOT/BQCA-PRODUCTION-POLICY.md"
VERSIONED_POLICY="$BOB_ROOT/BQCA-PRODUCTION-POLICY-v44.md"
REGISTRY="$BOB_ROOT/BQCA-ACTIVE-POLICY-REGISTRY.json"
HISTORY_MANIFEST="$BQCA_ROOT/patches/BQCA/policy-history/BQCA-policy-history-manifest.json"
HELPER="$SCRIPT_DIR/bqca-policy-orchestrator.py"
DOCTOR="$SCRIPT_DIR/bqca-policy-doctor.sh"
CONFIG_TOOL="$SCRIPT_DIR/qiskit-configuration.sh"
ENV_TOOL="$SCRIPT_DIR/qiskit-v2x-environment.sh"
CODE_VALIDATOR="$SCRIPT_DIR/qiskit-code-policy-check.py"
HOME_ENV_VALIDATOR="$SCRIPT_DIR/qiskit-home-env-policy-check.py"
DESIGN_VALIDATOR="$SCRIPT_DIR/qiskit-design-policy-check.py"
HELLO_VALIDATOR="$SCRIPT_DIR/qiskit-hello-world-scope-check.py"
RESULT_VALIDATOR="$SCRIPT_DIR/qiskit-result-output-policy-check.py"
SECRET_SCANNER="$SCRIPT_DIR/bqca-secret-scan.py"
NOTEBOOK_GENERATOR="$SCRIPT_DIR/notebook-generator.sh"
DESIGN_DIR="$BQCA_ROOT/bob-quantum-designs"
STORE_DIR="$BQCA_ROOT/bob-quantum-store"

info() { printf '[BQCA v44][ORCHESTRATOR] %s\n' "$*"; }
fail() { printf '[BQCA v44][ORCHESTRATOR][ERROR] %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'USAGE'
BQCA v44 canonical policy orchestrator

Usage:
  bqca-policy-orchestrator.sh validate-design <design.md> [more...]
  bqca-policy-orchestrator.sh validate-code <code.py> [more...]
  bqca-policy-orchestrator.sh validate-store [directory]
  bqca-policy-orchestrator.sh validate-design-store [directory]
  bqca-policy-orchestrator.sh pre-execute <code.py>
  bqca-policy-orchestrator.sh execute <code.py|notebook.ipynb> [arguments...]
  bqca-policy-orchestrator.sh post-execute <code.py|notebook.ipynb>
  bqca-policy-orchestrator.sh validate-result <result.txt> [source.py|source.ipynb]
  bqca-policy-orchestrator.sh validate-installation
  bqca-policy-orchestrator.sh explain-policy
USAGE
}

require_file() { [[ -f "$1" ]] || fail "Required file is missing: $1"; }
require_exec() { [[ -x "$1" ]] || fail "Required executable is missing: $1"; }

inside_dir() {
  python3 - "$1" "$2" <<'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1]).resolve()
root = pathlib.Path(sys.argv[2]).resolve()
try:
    path.relative_to(root)
except ValueError:
    raise SystemExit(1)
PY
}

record_check() {
  local checks="$1" label="$2"
  shift 2
  local log status detail
  log="$(mktemp)"
  set +e
  "$@" >"$log" 2>&1
  status=$?
  set -e
  cat "$log"
  detail="$(tr '\n' ' ' < "$log" | tr '|' ';' | cut -c1-360)"
  if ((status == 0)); then
    printf '%s|PASS|%s\n' "$label" "$detail" >> "$checks"
  else
    printf '%s|FAIL|%s\n' "$label" "$detail" >> "$checks"
  fi
  rm -f "$log"
  return "$status"
}

write_report() {
  python3 "$HELPER" write-report --artifact "$1" --kind "$2" --status "$3" --checks "$4" --policy "$POLICY"
}

run_secret_scan() {
  [[ -x "$SECRET_SCANNER" ]] || return 0
  python3 "$SECRET_SCANNER" --use-env "$@"
}

validate_design_one() {
  local file="$1" checks failures=0 report
  [[ -f "$file" ]] || fail "Design not found: $file"
  if [[ "${BQCA_V44_TEST_MODE:-0}" != "1" ]] && ! inside_dir "$file" "$DESIGN_DIR"; then
    fail "Design must be under $DESIGN_DIR: $file"
  fi
  checks="$(mktemp)"
  if [[ "${BQCA_V44_TEST_MODE:-0}" == "1" ]]; then
    printf '%s|PASS|Synthetic validation path accepted in test mode\n' "Artifact routing" >> "$checks"
  else
    record_check "$checks" "Artifact routing" inside_dir "$file" "$DESIGN_DIR" || failures=$((failures+1))
  fi
  record_check "$checks" "Design policy" python3 "$DESIGN_VALIDATOR" "$file" || failures=$((failures+1))
  record_check "$checks" "Hello World scope" python3 "$HELLO_VALIDATOR" --kind design "$file" || failures=$((failures+1))
  record_check "$checks" "Result-output contract" python3 "$RESULT_VALIDATOR" --kind design "$file" || failures=$((failures+1))
  record_check "$checks" "Secret scan" run_secret_scan "$file" || failures=$((failures+1))
  if ((failures)); then
    write_report "$file" design NONCOMPLIANT "$checks" >/dev/null
    rm -f "$checks"
    return 1
  fi
  report="$(write_report "$file" design COMPLIANT "$checks")"
  rm -f "$checks"
  printf 'BQCA_V44_COMPLETION_GATE=PASS artifact=%s report=%s\n' "$file" "$report"
}

validate_code_one() {
  local file="$1" checks failures=0 notebook report
  [[ -f "$file" && "$file" == *.py ]] || fail "validate-code requires a Python file: $file"
  if [[ "${BQCA_V44_TEST_MODE:-0}" != "1" ]] && ! inside_dir "$file" "$STORE_DIR"; then
    fail "Implementation must be under $STORE_DIR: $file"
  fi
  checks="$(mktemp)"
  if [[ "${BQCA_V44_TEST_MODE:-0}" == "1" ]]; then
    printf '%s|PASS|Synthetic validation path accepted in test mode\n' "Artifact routing" >> "$checks"
  else
    record_check "$checks" "Artifact routing" inside_dir "$file" "$STORE_DIR" || failures=$((failures+1))
  fi

  if [[ "${BQCA_V44_STATIC_ONLY:-0}" == "1" ]]; then
    record_check "$checks" "Python syntax" python3 -m py_compile "$file" || failures=$((failures+1))
    record_check "$checks" "Qiskit code policy" python3 "$CODE_VALIDATOR" "$file" || failures=$((failures+1))
    record_check "$checks" "Home environment policy" python3 "$HOME_ENV_VALIDATOR" "$file" || failures=$((failures+1))
    record_check "$checks" "Hello World scope" python3 "$HELLO_VALIDATOR" --kind code "$file" || failures=$((failures+1))
    record_check "$checks" "Result-output markers" python3 "$RESULT_VALIDATOR" --kind code "$file" || failures=$((failures+1))
  else
    require_exec "$ENV_TOOL"
    "$ENV_TOOL" ensure --quiet
    record_check "$checks" "Python syntax" "$ENV_TOOL" python -m py_compile "$file" || failures=$((failures+1))
    record_check "$checks" "Qiskit code policy" "$ENV_TOOL" python "$CODE_VALIDATOR" "$file" || failures=$((failures+1))
    record_check "$checks" "Home environment policy" "$ENV_TOOL" python "$HOME_ENV_VALIDATOR" "$file" || failures=$((failures+1))
    record_check "$checks" "Hello World scope" "$ENV_TOOL" python "$HELLO_VALIDATOR" --kind code "$file" || failures=$((failures+1))
    record_check "$checks" "Result-output markers" "$ENV_TOOL" python "$RESULT_VALIDATOR" --kind code "$file" || failures=$((failures+1))
  fi
  record_check "$checks" "Secret scan" run_secret_scan "$file" || failures=$((failures+1))

  notebook="${file%.py}.ipynb"
  if [[ ! -f "$notebook" ]]; then
    record_check "$checks" "Notebook generation" "$NOTEBOOK_GENERATOR" --source "$file" --output "$notebook" --force || failures=$((failures+1))
  fi
  if [[ -f "$notebook" ]]; then
    record_check "$checks" "Notebook synchronization" "$NOTEBOOK_GENERATOR" --validate "$notebook" --against-source "$file" || failures=$((failures+1))
    record_check "$checks" "Notebook secret scan" run_secret_scan "$notebook" || failures=$((failures+1))
  else
    printf '%s|FAIL|Notebook was not created\n' "Notebook synchronization" >> "$checks"
    failures=$((failures+1))
  fi

  if ((failures)); then
    write_report "$file" code NONCOMPLIANT "$checks" >/dev/null
    rm -f "$checks"
    return 1
  fi
  report="$(write_report "$file" code COMPLIANT "$checks")"
  rm -f "$checks"
  printf 'BQCA_V44_COMPLETION_GATE=PASS artifact=%s report=%s\n' "$file" "$report"
}

pre_execute() {
  local source="$1"
  [[ -f "$source" ]] || fail "Source not found: $source"
  require_exec "$DOCTOR"
  require_exec "$CONFIG_TOOL"
  require_exec "$ENV_TOOL"
  "$DOCTOR" check --quiet
  "$CONFIG_TOOL" configure --project-root "$BQCA_ROOT" --quiet
  "$ENV_TOOL" ensure --quiet
  if [[ "$source" == *.py ]]; then
    validate_code_one "$source"
  elif [[ "$source" == *.ipynb ]]; then
    local sibling="${source%.ipynb}.py"
    [[ -f "$sibling" ]] || fail "Notebook execution requires its authoritative sibling Python source: $sibling"
    validate_code_one "$sibling"
  else
    fail "Unsupported executable artifact: $source"
  fi
}

validate_result_one() {
  local result="$1" source="${2:-}"
  [[ -f "$result" ]] || fail "Result file not found: $result"
  if [[ -n "$source" ]]; then
    python3 "$RESULT_VALIDATOR" --kind result --source "$source" "$result"
  else
    python3 "$RESULT_VALIDATOR" --kind result "$result"
  fi
  run_secret_scan "$result"
}

post_execute() {
  local source="$1" result checks failures=0 notebook report
  result="${source%.*}-result-output.txt"
  checks="$(mktemp)"
  record_check "$checks" "Result-output contract" validate_result_one "$result" "$source" || failures=$((failures+1))
  if [[ "$source" == *.py ]]; then
    notebook="${source%.py}.ipynb"
    record_check "$checks" "Notebook synchronization" "$NOTEBOOK_GENERATOR" --validate "$notebook" --against-source "$source" || failures=$((failures+1))
  elif [[ "$source" == *.ipynb ]]; then
    local sibling="${source%.ipynb}.py"
    record_check "$checks" "Notebook synchronization" "$NOTEBOOK_GENERATOR" --validate "$source" --against-source "$sibling" || failures=$((failures+1))
  fi
  if ((failures)); then
    write_report "$source" execution NONCOMPLIANT "$checks" >/dev/null
    rm -f "$checks"
    return 1
  fi
  report="$(write_report "$source" execution COMPLIANT "$checks")"
  rm -f "$checks"
  run_secret_scan "$report"
  printf 'BQCA_V44_COMPLETION_GATE=PASS artifact=%s report=%s\n' "$source" "$report"
}

execute_artifact() {
  local source="$1"
  shift
  pre_execute "$source"
  local status
  set +e
  if [[ "$source" == *.py ]]; then
    BQCA_V44_INTERNAL=1 BQCA_V44_ORCHESTRATED=1 "$ENV_TOOL" run "$source" "$@"
    status=$?
  elif [[ "$source" == *.ipynb ]]; then
    BQCA_V44_INTERNAL=1 BQCA_V44_ORCHESTRATED=1 "$ENV_TOOL" run-notebook "$source"
    status=$?
  else
    status=2
  fi
  set -e
  post_execute "$source" || status=1
  return "$status"
}

validate_installation() {
  require_file "$POLICY"
  require_file "$VERSIONED_POLICY"
  require_file "$REGISTRY"
  require_file "$HISTORY_MANIFEST"
  require_exec "$HELPER"
  require_exec "$DOCTOR"
  python3 "$HELPER" validate-registry --root "$BQCA_ROOT" --registry "$REGISTRY" --manifest "$HISTORY_MANIFEST" --policy "$POLICY" --versioned-policy "$VERSIONED_POLICY"
  python3 "$HELPER" scan-active --root "$BQCA_ROOT"
  "$DOCTOR" check --quiet
}

command_name="${1:-}"
[[ -n "$command_name" ]] || { usage; exit 2; }
shift || true
case "$command_name" in
  validate-design)
    (($# >= 1)) || { usage; exit 2; }
    for file in "$@"; do validate_design_one "$file"; done
    ;;
  validate-code)
    (($# >= 1)) || { usage; exit 2; }
    for file in "$@"; do validate_code_one "$file"; done
    ;;
  validate-store)
    root="${1:-$STORE_DIR}"
    mapfile -d '' files < <(find "$root" -type f -name '*.py' -print0)
    ((${#files[@]})) || { info "No Python files found under $root"; exit 0; }
    for file in "${files[@]}"; do validate_code_one "$file"; done
    ;;
  validate-design-store)
    root="${1:-$DESIGN_DIR}"
    mapfile -d '' files < <(find "$root" -type f \( -name '*.md' -o -name '*.txt' \) -print0)
    ((${#files[@]})) || { info "No design files found under $root"; exit 0; }
    for file in "${files[@]}"; do validate_design_one "$file"; done
    ;;
  pre-execute) (($# == 1)) || { usage; exit 2; }; pre_execute "$1" ;;
  execute) (($# >= 1)) || { usage; exit 2; }; source="$1"; shift; execute_artifact "$source" "$@" ;;
  post-execute) (($# == 1)) || { usage; exit 2; }; post_execute "$1" ;;
  validate-result) (($# == 1 || $# == 2)) || { usage; exit 2; }; validate_result_one "$1" "${2:-}" ;;
  validate-installation) (($# == 0)) || { usage; exit 2; }; validate_installation ;;
  explain-policy) (($# == 0)) || { usage; exit 2; }; cat "$POLICY" ;;
  -h|--help) usage ;;
  *) usage >&2; exit 2 ;;
esac
SH_ORCH
  chmod 755 "$ORCHESTRATOR_SH"
}

write_doctor_tools() {
  record_created "$DOCTOR_PY"
  record_created "$DOCTOR_SH"
  record_created "$DRIFT_GUARD_PY"
  record_created "$TEST_SUITE_PY"

  cat > "$DOCTOR_PY" <<'PY_DOCTOR'
#!/usr/bin/env python3
"""BQCA v44 canonical policy assurance and drift doctor."""
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

VERSION = "v44"
CANONICAL = "BQCA-CANONICAL-PRODUCTION-POLICY-" + VERSION
LEGACY_VERSION = r"(?:v30|v31|v32|v33|v34|v35|v36|v37|v38|v39(?:-update-1)?|v40|v41|v42|v43)"
LEGACY_BLOCK = re.compile(
    rf"(?:<!--\s*BQCA-[^>\n]*{LEGACY_VERSION}:(?:POLICY-)?BEGIN\s*-->|^\s*#\s*BQCA-[^\n]*{LEGACY_VERSION}:(?:POLICY-)?BEGIN\s*$)",
    re.I | re.M,
)
TEXT_EXTENSIONS = {".md", ".txt", ".sh", ".py", ".yaml", ".yml"}


def sha256(path: pathlib.Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def supported_files(root: pathlib.Path) -> tuple[list[pathlib.Path], list[pathlib.Path], list[pathlib.Path]]:
    bob = root / ".bob"
    rules = sorted(path for directory in bob.glob("rules-*") if directory.is_dir() for path in directory.rglob("*") if path.is_file() and path.suffix.lower() in TEXT_EXTENSIONS)
    skills_root = bob / "skills"
    skills = sorted(path for path in skills_root.rglob("*") if path.is_file() and path.suffix.lower() in TEXT_EXTENSIONS) if skills_root.is_dir() else []
    tools_root = bob / "quantum-tools"
    tools = sorted(path for path in tools_root.iterdir() if path.is_file() and path.suffix.lower() in TEXT_EXTENSIONS) if tools_root.is_dir() else []
    return rules, skills, tools


def bash_syntax(path: pathlib.Path) -> str | None:
    result = subprocess.run(["bash", "-n", str(path)], text=True, capture_output=True)
    return None if result.returncode == 0 else (result.stderr.strip() or "bash syntax failure")


def python_syntax(path: pathlib.Path) -> str | None:
    try:
        source = path.read_text(encoding="utf-8")
        compile(source, str(path), "exec")
        return None
    except Exception as exc:
        return str(exc)


def check(root: pathlib.Path) -> dict[str, object]:
    bob = root / ".bob"
    tools = bob / "quantum-tools"
    policy = bob / "BQCA-PRODUCTION-POLICY.md"
    versioned = bob / "BQCA-PRODUCTION-POLICY-v44.md"
    registry_path = bob / "BQCA-ACTIVE-POLICY-REGISTRY.json"
    manifest_path = root / "patches/BQCA/policy-history/BQCA-policy-history-manifest.json"
    custom_modes = bob / "custom_modes.yaml"
    errors: list[str] = []
    checks: dict[str, object] = {}

    expected_policies = {"BQCA-PRODUCTION-POLICY.md", "BQCA-PRODUCTION-POLICY-v44.md"}
    active_policies = {path.name for path in bob.glob("BQCA-*.md") if "POLICY" in path.name.upper()}
    checks["active_policy_files"] = sorted(active_policies)
    if active_policies != expected_policies:
        errors.append(f"active policy files differ from expected set: {sorted(active_policies)}")

    if not policy.is_file() or not versioned.is_file():
        errors.append("canonical policy files are missing")
        policy_hash = ""
    else:
        policy_hash = sha256(policy)
        if policy.read_bytes() != versioned.read_bytes():
            errors.append("stable and versioned policies differ")

    try:
        registry = json.loads(registry_path.read_text(encoding="utf-8"))
    except Exception as exc:
        registry = {}
        errors.append(f"invalid registry JSON: {exc}")
    active = registry.get("active_authority", {}) if isinstance(registry, dict) else {}
    if active.get("version") != "v44":
        errors.append("registry active authority is not v44")
    if active.get("policy_sha256") != policy_hash:
        errors.append("registry canonical policy hash mismatch")
    if active.get("orchestrator") != ".bob/quantum-tools/bqca-policy-orchestrator.sh":
        errors.append("registry orchestrator path is incorrect")
    if active.get("doctor") != ".bob/quantum-tools/bqca-policy-doctor.sh":
        errors.append("registry doctor path is incorrect")

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
    coverage_errors: list[dict[str, object]] = []
    legacy_count = 0
    for path in [custom_modes, *rules, *skills, *tool_files]:
        text = path.read_text(encoding="utf-8", errors="replace")
        legacy_count += len(LEGACY_BLOCK.findall(text))
        actual = text.count(begin)
        expected = len(re.findall(r"^\s*customInstructions:\s*[>|][+-]?\s*(?:#.*)?$", text, re.M)) if path == custom_modes else 1
        if actual != expected:
            coverage_errors.append({"file": str(path.relative_to(root)), "expected": expected, "actual": actual})
    if legacy_count:
        errors.append(f"active legacy awareness blocks found: {legacy_count}")
    if coverage_errors:
        errors.append(f"canonical awareness coverage errors: {len(coverage_errors)}")
    checks["legacy_blocks"] = legacy_count
    checks["coverage_errors"] = coverage_errors
    checks["custom_mode_blocks"] = len(re.findall(r"^\s*customInstructions:\s*[>|][+-]?\s*(?:#.*)?$", custom_modes.read_text(encoding="utf-8"), re.M))
    checks["rule_files"] = len(rules)
    checks["skill_files"] = len(skills)
    checks["tool_files"] = len(tool_files)

    wrapper_requirements = {
        root / "xLaunchpad.sh": ("BQCA-POLICY-ASSURANCE-v44:BEGIN", "bqca-policy-doctor.sh", "check --quiet"),
        tools / "qiskit-connector.sh": ("BQCA-CANONICAL-ORCHESTRATOR-v44:BEGIN", "BQCA_V44_INTERNAL", "bqca-policy-orchestrator.sh"),
        tools / "qca-code-quality-guard.sh": ("BQCA-CANONICAL-ORCHESTRATOR-v44:BEGIN", "BQCA_V44_INTERNAL", "bqca-policy-orchestrator.sh"),
        tools / "qiskit-v2x-environment.sh": ("BQCA-CANONICAL-ORCHESTRATOR-v44:BEGIN", "BQCA_V44_ORCHESTRATED", "bqca-policy-orchestrator.sh"),
        tools / "qiskit-result-output.sh": ("BQCA-RESULT-CAPTURE-GATE-v44:BEGIN", "BQCA_V44_ORCHESTRATED", "Direct result-capture invocation is prohibited"),
    }
    wrapper_errors: list[str] = []
    for path, required in wrapper_requirements.items():
        if not path.is_file():
            wrapper_errors.append(f"missing wrapper: {path}")
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        for token in required:
            if token not in text:
                wrapper_errors.append(f"{path.name} missing delegation token: {token}")
    for path in sorted(root.glob("bob-quantum-v*.sh")):
        text = path.read_text(encoding="utf-8", errors="replace")
        if "BQCA-CANONICAL-ORCHESTRATOR-v44:BEGIN" not in text:
            wrapper_errors.append(f"{path.name} lacks v44 orchestrator export")
    if wrapper_errors:
        errors.extend(wrapper_errors)
    checks["wrapper_errors"] = wrapper_errors

    syntax_errors: list[str] = []
    executable_targets = [
        root / "xLaunchpad.sh",
        tools / "bqca-policy-orchestrator.sh",
        tools / "bqca-policy-doctor.sh",
        tools / "qiskit-connector.sh",
        tools / "qca-code-quality-guard.sh",
        tools / "qiskit-v2x-environment.sh",
        tools / "qiskit-result-output.sh",
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
    checks["syntax_permission_errors"] = syntax_errors

    history_dir = root / "patches/BQCA/policy-history"
    if str(history_dir.resolve()).startswith(str(bob.resolve()) + os.sep):
        errors.append("historical policy directory is inside active .bob context")
    checks["historical_context_isolated"] = not str(history_dir.resolve()).startswith(str(bob.resolve()) + os.sep)

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
        "BQCA v44 CANONICAL POLICY ASSURANCE REPORT",
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
        f"Syntax/permission errors    : {len(result.get('syntax_permission_errors', []))}",
        f"Historical context isolated : {'YES' if result.get('historical_context_isolated') else 'NO'}",
        "-" * width,
    ]
    if errors:
        lines.append("ISSUES")
        for error in errors:
            lines.append(f"- {error}")
        lines.append("-" * width)
    lines.append(f"FINAL ASSURANCE STATUS      : {result.get('status')}")
    lines.append("=" * width)
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description="BQCA v44 policy doctor")
    parser.add_argument("command", choices=("check", "report"))
    parser.add_argument("--root", type=pathlib.Path, required=True)
    parser.add_argument("--output", type=pathlib.Path)
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args()
    result = check(args.root.resolve())
    report = format_report(result)
    if args.command == "report" or args.output:
        output = args.output or args.root / ".bob/patches-applied/BQCA.v44-assurance-report.txt"
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(report, encoding="utf-8")
    if not args.quiet:
        print(report, end="")
    return 0 if result["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
PY_DOCTOR
  chmod 755 "$DOCTOR_PY"

  cat > "$DOCTOR_SH" <<'SH_DOCTOR'
#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
BOB_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
BQCA_ROOT="$(cd "$BOB_ROOT/.." && pwd -P)"
DOCTOR="$SCRIPT_DIR/bqca-policy-doctor.py"
TEST_SUITE="$SCRIPT_DIR/bqca-policy-test-suite.py"
PATCH="$BQCA_ROOT/patches/BQCA/patch-BQCA.v44.sh"
REPORT="$BOB_ROOT/patches-applied/BQCA.v44-assurance-report.txt"

usage() {
  cat <<'USAGE'
BQCA v44 policy doctor

Usage:
  bqca-policy-doctor.sh check [--quiet]
  bqca-policy-doctor.sh report
  bqca-policy-doctor.sh repair
  bqca-policy-doctor.sh test
USAGE
}

command_name="${1:-}"
[[ -n "$command_name" ]] || { usage; exit 2; }
shift || true
case "$command_name" in
  check)
    exec python3 "$DOCTOR" check --root "$BQCA_ROOT" "$@"
    ;;
  report)
    (($# == 0)) || { usage; exit 2; }
    exec python3 "$DOCTOR" report --root "$BQCA_ROOT" --output "$REPORT"
    ;;
  repair)
    (($# == 0)) || { usage; exit 2; }
    [[ -x "$PATCH" ]] || { printf 'BQCA v44 repair patch is missing: %s\n' "$PATCH" >&2; exit 2; }
    exec "$PATCH" --target "$BQCA_ROOT"
    ;;
  test)
    (($# == 0)) || { usage; exit 2; }
    exec python3 "$TEST_SUITE" --root "$BQCA_ROOT"
    ;;
  -h|--help) usage ;;
  *) usage >&2; exit 2 ;;
esac
SH_DOCTOR
  chmod 755 "$DOCTOR_SH"

  cat > "$DRIFT_GUARD_PY" <<'PY_DRIFT'
#!/usr/bin/env python3
"""Lightweight BQCA v44 launch drift guard."""
from __future__ import annotations
import pathlib
import subprocess
import sys

root = pathlib.Path(__file__).resolve().parents[2]
doctor = root / ".bob/quantum-tools/bqca-policy-doctor.sh"
raise SystemExit(subprocess.run([str(doctor), "check", "--quiet"]).returncode)
PY_DRIFT
  chmod 755 "$DRIFT_GUARD_PY"

  cat > "$TEST_SUITE_PY" <<'PY_TEST'
#!/usr/bin/env python3
"""Isolated BQCA v44 static and behavioral assurance tests."""
from __future__ import annotations

import argparse
import os
import pathlib
import subprocess
import tempfile
import textwrap


def run(command: list[str], *, env: dict[str, str] | None = None, expect: int = 0) -> None:
    result = subprocess.run(command, text=True, capture_output=True, env=env)
    if result.returncode != expect:
        raise RuntimeError(
            f"unexpected status {result.returncode}, expected {expect}: {' '.join(command)}\n"
            f"stdout:\n{result.stdout}\nstderr:\n{result.stderr}"
        )


def code_text(primitive: str, open_session: bool = False) -> str:
    primitive_import = "SamplerV2, EstimatorV2, Session"
    open_line = f"primitive = {primitive}(mode=backend)"
    if open_session:
        open_line = "with Session(backend=backend) as session:\n            primitive = SamplerV2(mode=session)"
    return textwrap.dedent(f'''\
        #!/usr/bin/env python3
        """Synthetic v44 Qiskit workload.
        Execute with qiskit-v2x-environment.sh run under $HOME/qiskit-v2x-env.
        Qiskit >= 2.5. qiskit-result-output is mandatory.
        """
        from qiskit import QuantumCircuit, transpile
        from qiskit_aer import AerSimulator
        from qiskit_ibm_runtime import {primitive_import}
        from qiskit_connector import QConnectorV2 as connector
        from qiskit_connector import QPlanV2 as plan

        current = plan()
        backend = connector()

        def is_open_plan(value):
            return "open" in str(value).lower()

        def execute(circuit):
            required_qubits = circuit.num_qubits
            if getattr(backend.status(), "operational", True) is not True:
                raise RuntimeError("not operational")
            if getattr(backend, "num_qubits", 0) < required_qubits:
                raise RuntimeError("insufficient qubit capacity")
            try:
                if is_open_plan(current):
                    {textwrap.indent(open_line, ' ' * 8).lstrip()}
                    job = primitive.run([circuit])
                else:
                    with Session(backend=backend) as session:
                        primitive = SamplerV2(mode=session)
                        job = primitive.run([circuit])
                result = job.result()
                print("BQCA_EXECUTION_TARGET=REAL_QPU")
                print(f"BQCA_JOB_ID={{job.job_id()}}")
                print(f"BQCA_PLAN={{current}}")
                print(f"BQCA_BACKEND={{backend}}")
                print(f"BQCA_RESULT={{result}}")
                return result
            except Exception as exc:
                print(f"BQCA_FALLBACK_REASON={{exc}}")
                sim_backend = AerSimulator()
                compiled = transpile(circuit, backend=sim_backend)
                result = sim_backend.run(compiled).result()
                print("BQCA_EXECUTION_TARGET=SIMULATOR")
                print(f"BQCA_PLAN={{current}}")
                print(f"BQCA_BACKEND={{sim_backend}}")
                print(f"BQCA_RESULT={{result}}")
                return result
    ''')


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=pathlib.Path, required=True)
    args = parser.parse_args()
    root = args.root.resolve()
    tools = root / ".bob/quantum-tools"
    code_validator = tools / "qiskit-code-policy-check.py"
    design_validator = tools / "qiskit-design-policy-check.py"
    result_validator = tools / "qiskit-result-output-policy-check.py"
    secret_scanner = tools / "bqca-secret-scan.py"
    notebook_generator = tools / "notebook-generator.sh"
    orchestrator = tools / "bqca-policy-orchestrator.sh"

    with tempfile.TemporaryDirectory(prefix="bqca-v44-test-") as raw:
        temp = pathlib.Path(raw)
        sampler = temp / "sampler-workload.py"
        estimator = temp / "estimator-workload.py"
        bad_open = temp / "invalid-open-session.py"
        sampler.write_text(code_text("SamplerV2"), encoding="utf-8")
        estimator.write_text(code_text("EstimatorV2"), encoding="utf-8")
        bad_open.write_text(code_text("SamplerV2", open_session=True), encoding="utf-8")
        run(["python3", str(code_validator), str(sampler)])
        run(["python3", str(code_validator), str(estimator)])
        run(["python3", str(code_validator), str(bad_open)], expect=1)

        design = temp / "vqe-design.md"
        design.write_text(textwrap.dedent('''\
            # VQE Research Design
            ## BQCA Qiskit 2.5+ Home Environment and Plan Policy
            Use $HOME/qiskit-v2x-env and source $HOME/qiskit-v2x-env/bin/activate.
            A project-local qiskit-v2x-env is prohibited. Qiskit 2.5 or later is required.
            CODE intent includes create, implement, write, generate, build, develop, produce,
            scaffold, construct, code, program, modify, update, repair, fix, refactor, complete, execute.
            Open Plan must not use Session. Use SamplerV2(mode=backend) for sampling, shots,
            counts, bitstrings, and distributions. Use EstimatorV2(mode=backend) for expectation
            values, observables, energy, and Hamiltonian workloads. Choose the suitable primitive.
            Paid Plan uses Session with SamplerV2(mode=session) or EstimatorV2(mode=session).
            Use try/except fallback, transpile, and AerSimulator. backend.run() is permitted only
            for a local simulator and is prohibited on real QPU hardware.
            Produce <code-name>-result-output.txt in the same directory. Capture complete stdout
            and combined stderr including Qiskit Connector output, timestamp, and a RESULT SUMMARY
            at the bottom stating execution successful. Put the real-QPU JOB ID on the first line.
            Execute with qiskit-v2x-environment.sh run through the canonical gate.
        '''), encoding="utf-8")
        run(["python3", str(design_validator), str(design)])
        run(["python3", str(result_validator), "--kind", "design", str(design)])

        notebook = temp / "sampler-workload.ipynb"
        run([str(notebook_generator), "--source", str(sampler), "--output", str(notebook), "--force"])
        run([str(notebook_generator), "--validate", str(notebook), "--against-source", str(sampler)])

        qpu_result = temp / "sampler-workload-result-output.txt"
        qpu_result.write_text(textwrap.dedent('''\
            JOB ID: synthetic-job-id
            BQCA QUANTUM EXECUTION RESULT OUTPUT
            Execution target        : REAL_QPU
            COMPLETE COMBINED EXECUTION OUTPUT
            BQCA_EXECUTION_TARGET=REAL_QPU
            BQCA_JOB_ID=synthetic-job-id
            BQCA_RESULT=ok
            RESULT SUMMARY
            Execution successful    : YES
            Completion date/time    : 2026-07-23T00:00:00+00:00
            Final execution target  : REAL_QPU
        '''), encoding="utf-8")
        run(["python3", str(result_validator), "--kind", "result", "--source", str(sampler), str(qpu_result)])

        clean = temp / "clean.txt"
        dirty = temp / "dirty.txt"
        clean.write_text("safe output\n", encoding="utf-8")
        dirty.write_text("IQP_API_TOKEN=ABCDEFGHIJKLMNOPQRSTUVWXYZ012345\n", encoding="utf-8")
        run(["python3", str(secret_scanner), str(clean)])
        run(["python3", str(secret_scanner), str(dirty)], expect=1)

        env = os.environ.copy()
        env["BQCA_V44_STATIC_ONLY"] = "1"
        env["BQCA_V44_TEST_MODE"] = "1"
        run([str(orchestrator), "validate-code", str(sampler)], env=env)

    print("BQCA_V44_TEST_SUITE=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
PY_TEST
  chmod 755 "$TEST_SUITE_PY"
}

consolidate_active_surfaces() {
  python3 - "$BQCA_ROOT" <<'PY_SURFACES'
from __future__ import annotations

import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1])
bob = root / ".bob"
custom_modes = bob / "custom_modes.yaml"
old_marker = "BQCA-CANONICAL-PRODUCTION-POLICY-v43"
new_marker = "BQCA-CANONICAL-PRODUCTION-POLICY-v44"
extensions = {".md", ".txt", ".sh", ".py", ".yaml", ".yml"}


def remove_html(text: str, marker: str) -> str:
    return re.sub(
        rf"\n?<!--\s*{re.escape(marker)}:BEGIN\s*-->.*?<!--\s*{re.escape(marker)}:END\s*-->\n?",
        "\n",
        text,
        flags=re.S,
    )


def remove_comment(text: str, marker: str) -> str:
    return re.sub(
        rf"(?ms)^\s*#\s*{re.escape(marker)}:BEGIN\n.*?^\s*#\s*{re.escape(marker)}:END\n?",
        "",
        text,
    )


def clean(text: str) -> str:
    for marker in (old_marker, new_marker):
        text = remove_html(text, marker)
        text = remove_comment(text, marker)
    text = text.replace("BQCA-PRODUCTION-POLICY-v43.md", "BQCA-PRODUCTION-POLICY-v44.md")
    return text


def md_block() -> str:
    return f"""
<!-- {new_marker}:BEGIN -->
## Canonical BQCA production policy
The sole active BQCA policy is `.bob/BQCA-PRODUCTION-POLICY.md` (v45). Historical policies are audit records only. Use `.bob/quantum-tools/bqca-policy-orchestrator.sh` for all design, code, execution, result, and completion gates, and `.bob/quantum-tools/bqca-policy-doctor.sh` for assurance. Open Plan real-QPU work must not use Session; use `SamplerV2(mode=backend)` for sampling workloads or `EstimatorV2(mode=backend)` for expectation-value/observable workloads.
<!-- {new_marker}:END -->
"""


def code_block() -> str:
    return f"""
# {new_marker}:BEGIN
# The sole active BQCA policy is .bob/BQCA-PRODUCTION-POLICY.md (v45).
# Route all public design, code, execution, result, and completion paths through
# bqca-policy-orchestrator.sh. Open Plan uses SamplerV2 or EstimatorV2 job mode
# according to workload semantics and must never use Session.
# {new_marker}:END
"""

text = custom_modes.read_text(encoding="utf-8")
text = clean(text)
lines = text.splitlines()
result: list[str] = []
pattern = re.compile(r"^(?P<indent>[ \t]*)customInstructions:\s*(?P<style>[>|])(?P<chomp>[+-]?)\s*(?:#.*)?$")
count = 0
for line in lines:
    result.append(line)
    match = pattern.match(line)
    if not match:
        continue
    indent = match.group("indent") + "  "
    result.extend([
        f"{indent}# {new_marker}:BEGIN",
        f"{indent}V44 CANONICAL POLICY: Use .bob/BQCA-PRODUCTION-POLICY.md as the sole active policy and bqca-policy-orchestrator.sh as the mandatory completion gate. Run bqca-policy-doctor.sh for assurance. For Open Plan real-QPU code, never use Session; use SamplerV2(mode=backend) for sampling/count/distribution workloads or EstimatorV2(mode=backend) for expectation-value/observable/energy workloads, selected according to the design and computation semantics.",
        f"{indent}# {new_marker}:END",
    ])
    count += 1
if count == 0:
    raise SystemExit("No customInstructions block scalars found in custom_modes.yaml")
custom_modes.write_text("\n".join(result) + "\n", encoding="utf-8")

rules = sorted(path for directory in bob.glob("rules-*") if directory.is_dir() for path in directory.rglob("*") if path.is_file() and path.suffix.lower() in extensions)
skills_root = bob / "skills"
skills = sorted(path for path in skills_root.rglob("*") if path.is_file() and path.suffix.lower() in extensions)
tools_root = bob / "quantum-tools"
tools = sorted(path for path in tools_root.iterdir() if path.is_file() and path.suffix.lower() in extensions)
for path in [*rules, *skills, *tools]:
    text = clean(path.read_text(encoding="utf-8", errors="strict"))
    block = md_block() if path.suffix.lower() in {".md", ".txt"} else code_block()
    path.write_text(text.rstrip() + "\n" + block.lstrip(), encoding="utf-8")
print(f"BQCA_V44_SURFACES modes={count} rules={len(rules)} skills={len(skills)} tools={len(tools)}")
PY_SURFACES
}

patch_runtime_entry_points() {
  python3 - "$BQCA_ROOT" <<'PY_RUNTIME'
from __future__ import annotations

import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1])
tools = root / ".bob/quantum-tools"


def remove_block(text: str, marker: str) -> str:
    return re.sub(rf"(?ms)^# {re.escape(marker)}:BEGIN\n.*?^# {re.escape(marker)}:END\n?", "", text)


def clean_runtime(text: str) -> str:
    for marker in (
        "BQCA-CANONICAL-ORCHESTRATOR-v43",
        "BQCA-CANONICAL-ORCHESTRATOR-v44",
        "BQCA-POLICY-ASSURANCE-v44",
        "BQCA-RESULT-CAPTURE-GATE-v44",
    ):
        text = remove_block(text, marker)
    return text.replace("BQCA_V43_", "BQCA_V44_").replace("V43_ORCHESTRATOR", "V44_ORCHESTRATOR").replace("v43 orchestrator", "v44 orchestrator")

# xLaunchpad: require orchestrator and run quiet drift preflight after .env load.
path = root / "xLaunchpad.sh"
text = clean_runtime(path.read_text(encoding="utf-8"))
block = r'''# BQCA-POLICY-ASSURANCE-v44:BEGIN
_BQCA_POLICY_ORCHESTRATOR="${SCRIPT_DIR}/.bob/quantum-tools/bqca-policy-orchestrator.sh"
_BQCA_POLICY_DOCTOR="${SCRIPT_DIR}/.bob/quantum-tools/bqca-policy-doctor.sh"
if [[ ! -x "${_BQCA_POLICY_ORCHESTRATOR}" || ! -x "${_BQCA_POLICY_DOCTOR}" ]]; then
  printf '[BQCA][ERROR] Required v44 policy tools are missing.\n' >&2
  exit 1
fi
if ! "${_BQCA_POLICY_DOCTOR}" check --quiet; then
  printf '[BQCA][ERROR] BQCA v44 policy drift detected. Run: %s repair\n' \
    "${_BQCA_POLICY_DOCTOR}" >&2
  exit 1
fi
export BQCA_POLICY_ORCHESTRATOR="${_BQCA_POLICY_ORCHESTRATOR}"
export BQCA_POLICY_DOCTOR="${_BQCA_POLICY_DOCTOR}"
export BQCA_ACTIVE_POLICY="${SCRIPT_DIR}/.bob/BQCA-PRODUCTION-POLICY.md"
# BQCA-POLICY-ASSURANCE-v44:END
'''
needle = "set +a\n"
if needle not in text:
    raise SystemExit("Unable to locate environment-loading boundary in xLaunchpad.sh")
text = text.replace(needle, needle + "\n" + block + "\n", 1)
path.write_text(text, encoding="utf-8")

# Versioned launchers expose v44 governance paths.
for path in sorted(root.glob("bob-quantum-v*.sh")):
    text = clean_runtime(path.read_text(encoding="utf-8"))
    block = r'''# BQCA-CANONICAL-ORCHESTRATOR-v44:BEGIN
BQCA_POLICY_ORCHESTRATOR="${SCRIPT_DIR}/.bob/quantum-tools/bqca-policy-orchestrator.sh"
BQCA_POLICY_DOCTOR="${SCRIPT_DIR}/.bob/quantum-tools/bqca-policy-doctor.sh"
BQCA_ACTIVE_POLICY="${SCRIPT_DIR}/.bob/BQCA-PRODUCTION-POLICY.md"
export BQCA_POLICY_ORCHESTRATOR BQCA_POLICY_DOCTOR BQCA_ACTIVE_POLICY
# BQCA-CANONICAL-ORCHESTRATOR-v44:END
'''
    match = re.search(r"^SCRIPT_DIR=.*$", text, re.M)
    if not match:
        raise SystemExit(f"Unable to locate SCRIPT_DIR in {path}")
    text = text[:match.end()] + "\n\n" + block + text[match.end():]
    path.write_text(text, encoding="utf-8")

# qiskit-connector public entry points.
path = tools / "qiskit-connector.sh"
text = clean_runtime(path.read_text(encoding="utf-8"))
block = r'''# BQCA-CANONICAL-ORCHESTRATOR-v44:BEGIN
V44_ORCHESTRATOR="$SCRIPT_DIR/bqca-policy-orchestrator.sh"
if [[ "${BQCA_V44_INTERNAL:-0}" != "1" && -x "$V44_ORCHESTRATOR" ]]; then
  case "${1:-}" in
    --validate-code) shift; exec "$V44_ORCHESTRATOR" validate-code "$@" ;;
    --validate-design) shift; exec "$V44_ORCHESTRATOR" validate-design "$@" ;;
    --validate-store) shift; exec "$V44_ORCHESTRATOR" validate-store "${1:-}" ;;
    --validate-design-store) shift; exec "$V44_ORCHESTRATOR" validate-design-store "${1:-}" ;;
    --run-code) shift; exec "$V44_ORCHESTRATOR" execute "$@" ;;
    --run-notebook) shift; exec "$V44_ORCHESTRATOR" execute "$@" ;;
  esac
fi
# BQCA-CANONICAL-ORCHESTRATOR-v44:END
'''
needle = 'SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"\n'
if needle not in text:
    needle = 'SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"\n'
if needle not in text:
    raise SystemExit("Unable to locate SCRIPT_DIR in qiskit-connector.sh")
text = text.replace(needle, needle + block + "\n", 1)
path.write_text(text, encoding="utf-8")

# Quality guard public entry points.
path = tools / "qca-code-quality-guard.sh"
text = clean_runtime(path.read_text(encoding="utf-8"))
block = r'''# BQCA-CANONICAL-ORCHESTRATOR-v44:BEGIN
V44_ORCHESTRATOR="$SCRIPT_DIR/bqca-policy-orchestrator.sh"
if [[ "${BQCA_V44_INTERNAL:-0}" != "1" && -x "$V44_ORCHESTRATOR" ]]; then
  case "${1:-}" in
    --validate|--prepare)
      (($# == 2)) || { printf 'v44 requires one Python file\n' >&2; exit 2; }
      exec "$V44_ORCHESTRATOR" validate-code "$2"
      ;;
    --execute)
      (($# >= 2)) || { printf 'v44 requires a Python file\n' >&2; exit 2; }
      shift
      exec "$V44_ORCHESTRATOR" execute "$@"
      ;;
  esac
fi
# BQCA-CANONICAL-ORCHESTRATOR-v44:END
'''
needle = 'SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"\n'
if needle not in text:
    needle = 'SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"\n'
if needle not in text:
    raise SystemExit("Unable to locate SCRIPT_DIR in qca-code-quality-guard.sh")
text = text.replace(needle, needle + block + "\n", 1)
path.write_text(text, encoding="utf-8")

# Environment manager execution routes.
path = tools / "qiskit-v2x-environment.sh"
text = clean_runtime(path.read_text(encoding="utf-8"))
block = r'''# BQCA-CANONICAL-ORCHESTRATOR-v44:BEGIN
if [[ "${BQCA_V44_INTERNAL:-0}" != "1" && "${BQCA_V44_ORCHESTRATED:-0}" != "1" ]]; then
  _BQCA_V44_ORCHESTRATOR="$SCRIPT_DIR/bqca-policy-orchestrator.sh"
  case "$command_name" in
    run|run-notebook)
      [[ -x "$_BQCA_V44_ORCHESTRATOR" ]] || { printf 'BQCA v44 orchestrator is missing: %s\n' "$_BQCA_V44_ORCHESTRATOR" >&2; exit 2; }
      (($# >= 1)) || { usage; exit 2; }
      exec "$_BQCA_V44_ORCHESTRATOR" execute "$@"
      ;;
  esac
fi
# BQCA-CANONICAL-ORCHESTRATOR-v44:END
'''
dispatch = re.search(r"shift \|\| true\s*\n\s*case \"\$command_name\" in\n", text)
if not dispatch:
    raise SystemExit("Unable to locate command dispatch in qiskit-v2x-environment.sh")
text = text[:dispatch.start()] + 'shift || true\n\n' + block + '\ncase "$command_name" in\n' + text[dispatch.end():]
path.write_text(text, encoding="utf-8")

# Result capture is an internal layer, not a public bypass.
path = tools / "qiskit-result-output.sh"
text = clean_runtime(path.read_text(encoding="utf-8"))
block = r'''# BQCA-RESULT-CAPTURE-GATE-v44:BEGIN
if [[ "${BQCA_V44_INTERNAL:-0}" != "1" && "${BQCA_V44_ORCHESTRATED:-0}" != "1" ]]; then
  printf 'Direct result-capture invocation is prohibited; use bqca-policy-orchestrator.sh execute.\n' >&2
  exit 2
fi
# BQCA-RESULT-CAPTURE-GATE-v44:END
'''
needle = 'SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"\n'
if needle not in text:
    raise SystemExit("Unable to locate SCRIPT_DIR in qiskit-result-output.sh")
text = text.replace(needle, needle + block + "\n", 1)
path.write_text(text, encoding="utf-8")
PY_RUNTIME

  chmod 755 "$XLAUNCHPAD" "$CONNECTOR_TOOL" "$QUALITY_GUARD" "$ENV_TOOL" "$RESULT_TOOL" "$ORCHESTRATOR_SH" "$DOCTOR_SH"
  while IFS= read -r -d '' launcher; do chmod 755 "$launcher"; done < <(find "$BQCA_ROOT" -maxdepth 1 -type f -name 'bob-quantum-v*.sh' -print0)
}

install_patch_copy() {
  mkdir -p "$PATCHES_DIR"
  record_created "$CANONICAL_PATCH"
  if [[ "$(cd "$(dirname "$0")" && pwd -P)/$(basename "$0")" != "$CANONICAL_PATCH" ]]; then
    cp "$0" "$CANONICAL_PATCH"
  fi
  chmod 755 "$CANONICAL_PATCH"
}

write_patch_records() {
  record_created "$PATCH_RECORD_FILE"
  record_created "$ASSURANCE_REPORT"
  mkdir -p "$PATCH_RECORD_DIR"
  cat > "$PATCH_RECORD_FILE" <<RECORD
Patch: $PATCH_ID
Applied: $(date -u '+%Y-%m-%dT%H:%M:%SZ')
Root: $BQCA_ROOT
Backup: $BACKUP_DIR
Active policy: .bob/BQCA-PRODUCTION-POLICY.md (v45)
Open Plan: SamplerV2(mode=backend) or EstimatorV2(mode=backend), selected by workload; Session prohibited
Assurance: policy doctor, drift guard, wrapper delegation, bypass prevention, secret scan, isolated tests
Protected assets: excluded and unchanged by installer
RECORD
  "$DOCTOR_SH" report >/dev/null
}

validate_installation() {
  local failures=0
  for file in "$ORCHESTRATOR_SH" "$DOCTOR_SH" "$CONNECTOR_TOOL" "$QUALITY_GUARD" "$ENV_TOOL" "$RESULT_TOOL" "$XLAUNCHPAD"; do
    [[ -x "$file" ]] || { warn "Missing executable: $file"; failures=$((failures+1)); continue; }
    bash -n "$file" || failures=$((failures+1))
  done
  while IFS= read -r -d '' launcher; do bash -n "$launcher" || failures=$((failures+1)); done < <(find "$BQCA_ROOT" -maxdepth 1 -type f -name 'bob-quantum-v*.sh' -print0)

  python3 - "$TOOLS_DIR" <<'PY_COMPILE' || failures=$((failures+1))
import pathlib, sys
root = pathlib.Path(sys.argv[1])
for path in root.iterdir():
    if path.is_file() and path.suffix == ".py":
        compile(path.read_text(encoding="utf-8"), str(path), "exec")
print("BQCA_V44_PYTHON_SYNTAX=PASS")
PY_COMPILE

  python3 "$ORCHESTRATOR_PY" validate-registry --root "$BQCA_ROOT" --registry "$REGISTRY_FILE" --manifest "$HISTORY_MANIFEST" --policy "$CANONICAL_POLICY" --versioned-policy "$VERSIONED_POLICY" || failures=$((failures+1))
  python3 "$ORCHESTRATOR_PY" scan-active --root "$BQCA_ROOT" || failures=$((failures+1))
  "$DOCTOR_SH" check --quiet || failures=$((failures+1))
  "$DOCTOR_SH" test || failures=$((failures+1))
  "$DOCTOR_SH" report >/dev/null || failures=$((failures+1))

  if ((failures)); then
    fail "v44 validation failed with $failures issue(s)."
  fi
  info "Validation passed: policy integrity, registry/history hashes, v44 awareness, wrapper delegation, Open Plan SamplerV2/EstimatorV2 behavior, secret scan, notebook, result, and completion gates."
}

if ((VALIDATE_ONLY)); then
  validate_installation
  exit 0
fi

create_backup
record_created "$DOCTOR_SH"
record_created "$DOCTOR_PY"
record_created "$DRIFT_GUARD_PY"
record_created "$TEST_SUITE_PY"
record_created "$SECRET_SCANNER"
record_created "$VERSIONED_POLICY"
record_created "$PATCH_RECORD_FILE"
record_created "$ASSURANCE_REPORT"
record_created "$CANONICAL_PATCH"

mkdir -p "$TOOLS_DIR" "$PATCH_RECORD_DIR" "$HISTORY_DIR"
write_canonical_policy
update_history_registry_and_timeline
write_secret_scanner
write_code_validator
write_design_validator
write_templates
write_orchestrator_python
write_orchestrator_shell
write_doctor_tools
consolidate_active_surfaces
patch_runtime_entry_points
install_patch_copy
write_patch_records
validate_installation

info "Patch $PATCH_ID applied successfully."
info "Backup: $BACKUP_DIR"
info "Canonical policy: .bob/BQCA-PRODUCTION-POLICY.md"
info "Policy doctor: .bob/quantum-tools/bqca-policy-doctor.sh"
info "Open Plan: SamplerV2 or EstimatorV2 job mode as suitable; no Session"
info "Protected runtime assets were not touched."
