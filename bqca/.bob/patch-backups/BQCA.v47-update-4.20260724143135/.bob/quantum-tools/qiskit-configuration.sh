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
# The sole active policy is .bob/BQCA-PRODUCTION-POLICY.md (v47).
# Direct execution streams complete stdout/stderr live and writes the exact
# professional report to <source-stem>-result-output.txt and output.txt.
# REAL_QPU results put the actual Job ID on line one. Direct contract gaps
# are warnings; formal orchestration is explicit opt-in.
# BQCA-CANONICAL-PRODUCTION-POLICY-v47:END
