#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
BOB_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
BQCA_ROOT="$(cd "$BOB_ROOT/.." && pwd -P)"
DOCTOR="$SCRIPT_DIR/bqca-policy-doctor.py"
PATCH="$BQCA_ROOT/patches/BQCA/patch-BQCA.v47-update-4.sh"
REPORT="$BOB_ROOT/patches-applied/BQCA.v47-assurance-report.txt"

usage() {
  cat <<'USAGE'
BQCA v47 policy doctor

Usage:
  bqca-policy-doctor.sh check [--quiet]
  bqca-policy-doctor.sh report
  bqca-policy-doctor.sh repair
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
    [[ -x "$PATCH" ]] || { printf 'BQCA v47 repair patch is missing: %s\n' "$PATCH" >&2; exit 2; }
    exec "$PATCH" --target "$BQCA_ROOT"
    ;;
  -h|--help) usage ;;
  *) usage >&2; exit 2 ;;
esac

# BQCA-CANONICAL-PRODUCTION-POLICY-v47:BEGIN
# BQCA v47 Update 4: follow .bob/BQCA-PRODUCTION-POLICY.md. Direct execution
# through bqca-direct-execution.sh is the default and must use the authorized
# home Python with unbuffered live stdout/stderr plus dual result capture.
# Code must preserve real-QPU-first plan-aware execution, controlled simulator
# fallback, and the required BQCA markers, including BQCA_RESULT=SUCCESS or
# BQCA_RESULT=FAILURE. The orchestrator is explicit opt-in only for formal
# compliance, deployment, or audit evidence. Direct-mode policy gaps are
# warnings that preserve the workload exit status; credential leakage blocks.
# This block supersedes conflicting local execution guidance.
# BQCA-CANONICAL-PRODUCTION-POLICY-v47:END

# BQCA-LOCAL-ALGORITHM-KNOWLEDGEBASE-v47-update-6:BEGIN
# For every quantum DESIGN or CODE intent, consult bqca-quantum-kb.sh and the
# offline bqca_quantum_algorithm_catalog.json for Qiskit 2.5+ algorithm,
# Open/Paid plan, simulator-fallback, design-card, and scaffold guidance.
# Update 6 supersedes Update 5 URL crawling and sublink drilldown. No network
# access or mandatory research trace is required. The catalog supplements IBM
# Bob intelligence and never overrides the active central policy. If no local
# entry fits, use approved research and continue rather than blocking the task.
# BQCA-LOCAL-ALGORITHM-KNOWLEDGEBASE-v47-update-6:END
