#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GENERATOR="$SCRIPT_DIR/notebook-generator.py"
[[ -x "$GENERATOR" ]] || { printf 'BQCA_NOTEBOOK_GENERATION=FAIL: missing generator: %s\n' "$GENERATOR" >&2; exit 2; }
exec python3 "$GENERATOR" "$@"
# BQCA-CANONICAL-PRODUCTION-POLICY-v43:BEGIN
# The sole active BQCA policy is .bob/BQCA-PRODUCTION-POLICY.md. Historical
# policies are audit records only. Route design, code, execution, result, and
# completion enforcement through bqca-policy-orchestrator.sh.
# BQCA-CANONICAL-PRODUCTION-POLICY-v43:END
