#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENGINE="$SCRIPT_DIR/knowlegebase/bqca_quantum_kb.py"
CATALOG="$SCRIPT_DIR/knowlegebase/bqca_quantum_algorithm_catalog.json"
[[ -x "$ENGINE" ]] || { printf 'BQCA_LOCAL_KB=FAIL: missing engine: %s\n' "$ENGINE" >&2; exit 2; }
[[ -f "$CATALOG" ]] || { printf 'BQCA_LOCAL_KB=FAIL: missing catalog: %s\n' "$CATALOG" >&2; exit 2; }
exec python3 "$ENGINE" --catalog "$CATALOG" "$@"

# BQCA-CANONICAL-PRODUCTION-POLICY-v47:BEGIN
# The sole active BQCA policy is .bob/BQCA-PRODUCTION-POLICY.md (v47).
# Direct execution with live terminal output and dual result capture is the
# default. The orchestrator is optional and reserved for formal compliance,
# production-deployment evidence, and audit validation. Historical policies
# are audit-only and must not drive runtime decisions.
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
