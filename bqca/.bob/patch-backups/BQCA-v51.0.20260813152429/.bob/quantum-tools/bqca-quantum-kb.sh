#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENGINE="$SCRIPT_DIR/knowlegebase/bqca_quantum_kb.py"
CATALOG="$SCRIPT_DIR/knowlegebase/bqca_quantum_algorithm_catalog.json"
[[ -x "$ENGINE" ]] || { printf 'BQCA_LOCAL_KB=FAIL: missing engine: %s\n' "$ENGINE" >&2; exit 2; }
[[ -f "$CATALOG" ]] || { printf 'BQCA_LOCAL_KB=FAIL: missing catalog: %s\n' "$CATALOG" >&2; exit 2; }
exec python3 "$ENGINE" --catalog "$CATALOG" "$@"

# BQCA-ACTIVE-CENTRAL-POLICY:BEGIN
# Resolve the active authority through bqca-active-policy-listener.sh before
# every quantum DESIGN or CODE decision. Never hardcode a policy version or
# duplicate the full policy here. qiskit-design-policy-check.py and
# qiskit-code-policy-check.py reload the active registry/policy/contract on
# every invocation and create same-directory policy-compliance reports.
# Do not report completion until the active-policy report exists.
# BQCA-ACTIVE-CENTRAL-POLICY:END
