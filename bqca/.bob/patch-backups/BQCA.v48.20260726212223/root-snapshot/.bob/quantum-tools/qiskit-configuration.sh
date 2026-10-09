#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIGURATOR="$SCRIPT_DIR/qiskit-configuration.py"
[[ -x "$CONFIGURATOR" ]] || {
  printf 'BQCA_QISKIT_CONFIGURATION=FAIL: missing configurator: %s\n' "$CONFIGURATOR" >&2
  exit 2
}
exec python3 "$CONFIGURATOR" "$@"

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
