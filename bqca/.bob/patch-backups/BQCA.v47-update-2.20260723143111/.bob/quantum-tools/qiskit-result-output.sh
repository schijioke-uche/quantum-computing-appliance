#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
CAPTURE="$SCRIPT_DIR/qiskit-result-output.py"
[[ -x "$CAPTURE" ]] || {
  printf 'BQCA_RESULT_OUTPUT_V46=FAIL: missing capture tool: %s\n' "$CAPTURE" >&2
  exit 2
}
exec env PYTHONUNBUFFERED=1 python3 -u "$CAPTURE" "$@"

# BQCA-CANONICAL-PRODUCTION-POLICY-v47:BEGIN
# The sole active policy is .bob/BQCA-PRODUCTION-POLICY-v47.md.
# v47 direct execution is the default for development/testing, exploration,
# debugging, and quick experiments. The orchestrator is explicit and optional
# for formal compliance, production deployment, and audit. Mirror output live
# and write both <source-stem>-result-output.txt and output.txt.
# BQCA-CANONICAL-PRODUCTION-POLICY-v47:END
