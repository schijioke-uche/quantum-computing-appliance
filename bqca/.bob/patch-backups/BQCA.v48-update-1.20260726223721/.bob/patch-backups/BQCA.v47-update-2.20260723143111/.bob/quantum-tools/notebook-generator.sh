#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GENERATOR="$SCRIPT_DIR/notebook-generator.py"
[[ -x "$GENERATOR" ]] || { printf 'BQCA_NOTEBOOK_GENERATION=FAIL: missing generator: %s\n' "$GENERATOR" >&2; exit 2; }
exec python3 "$GENERATOR" "$@"

# BQCA-CANONICAL-PRODUCTION-POLICY-v47:BEGIN
# The sole active policy is .bob/BQCA-PRODUCTION-POLICY-v47.md.
# v47 direct execution is the default for development/testing, exploration,
# debugging, and quick experiments. The orchestrator is explicit and optional
# for formal compliance, production deployment, and audit. Mirror output live
# and write both <source-stem>-result-output.txt and output.txt.
# BQCA-CANONICAL-PRODUCTION-POLICY-v47:END
