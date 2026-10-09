#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
BOB_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
BQCA_ROOT="$(cd "$BOB_ROOT/.." && pwd -P)"
DOCTOR="$SCRIPT_DIR/bqca-policy-doctor.py"
TEST_SUITE="$SCRIPT_DIR/bqca-policy-test-suite.py"
PATCH="$BQCA_ROOT/patches/BQCA/patch-BQCA.v44.sh"
REPORT="$BOB_ROOT/patches-applied/BQCA.v44-assurance-report.txt"

usage() {
  cat <<'USAGE'
BQCA v45 policy doctor

Usage:
  bqca-policy-doctor.sh check [--quiet]
  bqca-policy-doctor.sh report
  bqca-policy-doctor.sh repair
  bqca-policy-doctor.sh test
USAGE
}

command_name="${1:-}"
[[ -n "$command_name" ]] || { usage; exit 2; }
shift || true
case "$command_name" in
  check)
    exec python3 "$DOCTOR" check --root "$BQCA_ROOT" "$@"
    ;;
  report)
    (($# == 0)) || { usage; exit 2; }
    exec python3 "$DOCTOR" report --root "$BQCA_ROOT" --output "$REPORT"
    ;;
  repair)
    (($# == 0)) || { usage; exit 2; }
    [[ -x "$PATCH" ]] || { printf 'BQCA v45 repair patch is missing: %s\n' "$PATCH" >&2; exit 2; }
    exec "$PATCH" --target "$BQCA_ROOT"
    ;;
  test)
    (($# == 0)) || { usage; exit 2; }
    exec python3 "$TEST_SUITE" --root "$BQCA_ROOT"
    ;;
  -h|--help) usage ;;
  *) usage >&2; exit 2 ;;
esac
# BQCA-CANONICAL-PRODUCTION-POLICY-v45:BEGIN
# The sole active BQCA policy is .bob/BQCA-PRODUCTION-POLICY.md (v45).
# Route all public design, code, execution, result, and completion paths through
# bqca-policy-orchestrator.sh. Open Plan uses SamplerV2 or EstimatorV2 job mode
# according to workload semantics and must never use Session.
# BQCA-CANONICAL-PRODUCTION-POLICY-v45:END
