#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
KB_DIR="$SCRIPT_DIR/knowlegebase"
KB_TOOL="$KB_DIR/bqca_quantum_kb.py"
KB_INDEX="${BQCA_QUANTUM_KB_INDEX:-$KB_DIR/bqca_quantum_kb_index.txt}"

[[ -f "$KB_TOOL" ]] || { printf 'BQCA_QUANTUM_KB=FAIL missing tool: %s\n' "$KB_TOOL" >&2; exit 2; }

export BQCA_QUANTUM_KB_INDEX="$KB_INDEX"
exec python3 "$KB_TOOL" --index "$KB_INDEX" "$@"

# BQCA-CANONICAL-PRODUCTION-POLICY-v47:BEGIN
# The sole active BQCA policy is .bob/BQCA-PRODUCTION-POLICY.md (v47).
# Direct execution with live terminal output and dual result capture is the
# default. The orchestrator is optional and reserved for formal compliance,
# production-deployment evidence, and audit validation. Historical policies
# are audit-only and must not drive runtime decisions.
# BQCA-CANONICAL-PRODUCTION-POLICY-v47:END

# BQCA-QUANTUM-KNOWLEDGEBASE-v47-update-5:BEGIN
# For every quantum DESIGN or CODE intent, consult the canonical index at
# .bob/quantum-tools/knowlegebase/bqca_quantum_kb_index.txt through
# .bob/quantum-tools/bqca-quantum-kb.sh. Access relevant seed URLs and drill
# into at least one relevant sublink from every seed accessed. Preserve a
# <artifact-stem>-kb-research.md trace beside the governed artifact. The
# knowledgebase supplements IBM Bob intelligence and never overrides the active
# central policy. Do not claim compliance when the strict research gate fails.
# This block supersedes conflicting local quantum-knowledge-source guidance.
# BQCA-QUANTUM-KNOWLEDGEBASE-v47-update-5:END
