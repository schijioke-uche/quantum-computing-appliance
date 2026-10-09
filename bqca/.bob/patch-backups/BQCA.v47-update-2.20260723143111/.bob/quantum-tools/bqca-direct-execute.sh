#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
DIRECT="$SCRIPT_DIR/bqca-direct-execution.sh"
[[ -x "$DIRECT" ]] || { printf 'BQCA v47 direct executor is missing: %s\n' "$DIRECT" >&2; exit 2; }
case "${1:-}" in
  run|run-notebook|formal-run|decision-matrix|-h|--help)
    exec "$DIRECT" "$@"
    ;;
  "")
    exec "$DIRECT" --help
    ;;
  *)
    exec "$DIRECT" run "$@"
    ;;
esac

# BQCA-CANONICAL-PRODUCTION-POLICY-v47:BEGIN
# The sole active policy is .bob/BQCA-PRODUCTION-POLICY-v47.md.
# v47 direct execution is the default for development/testing, exploration,
# debugging, and quick experiments. The orchestrator is explicit and optional
# for formal compliance, production deployment, and audit. Mirror output live
# and write both <source-stem>-result-output.txt and output.txt.
# BQCA-CANONICAL-PRODUCTION-POLICY-v47:END
