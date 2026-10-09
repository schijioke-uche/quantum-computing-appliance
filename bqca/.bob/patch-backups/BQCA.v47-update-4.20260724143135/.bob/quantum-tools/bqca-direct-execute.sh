#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
DIRECT="$SCRIPT_DIR/bqca-direct-execution.sh"
[[ -x "$DIRECT" ]] || { printf 'BQCA v47 direct executor is missing: %s\n' "$DIRECT" >&2; exit 2; }
(($# >= 1)) || { printf 'Usage: bqca-direct-execute.sh <file.py> [arguments...]\n' >&2; exit 2; }
exec "$DIRECT" run "$@"
# BQCA-CANONICAL-PRODUCTION-POLICY-v47:BEGIN
# The sole active policy is .bob/BQCA-PRODUCTION-POLICY.md (v47).
# Direct execution streams complete stdout/stderr live and writes the exact
# professional report to <source-stem>-result-output.txt and output.txt.
# REAL_QPU results put the actual Job ID on line one. Direct contract gaps
# are warnings; formal orchestration is explicit opt-in.
# BQCA-CANONICAL-PRODUCTION-POLICY-v47:END
