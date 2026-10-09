#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
BQCA_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
DOCTOR="$SCRIPT_DIR/bqca-policy-doctor.py"
PATCH="$BQCA_ROOT/patches/BQCA/patch-BQCA.v46.sh"
REPORT="$BQCA_ROOT/.bob/patches-applied/BQCA.v46-assurance-report.txt"
TEST_SUITE="$SCRIPT_DIR/bqca-policy-test-suite.py"

usage() {
  cat <<'USAGE'
BQCA v46 policy doctor

Usage:
  bqca-policy-doctor.sh check [--quiet]
  bqca-policy-doctor.sh report
  bqca-policy-doctor.sh repair
  bqca-policy-doctor.sh test
USAGE
}

case "${1:-}" in
  check)
    shift
    exec python3 "$DOCTOR" check --root "$BQCA_ROOT" "$@"
    ;;
  report)
    exec python3 "$DOCTOR" report --root "$BQCA_ROOT" --output "$REPORT"
    ;;
  repair)
    [[ -x "$PATCH" ]] || { printf 'BQCA v46 patch is unavailable: %s\n' "$PATCH" >&2; exit 2; }
    exec "$PATCH" --target "$BQCA_ROOT"
    ;;
  test)
    [[ -x "$TEST_SUITE" ]] || { printf 'BQCA v46 test suite is unavailable: %s\n' "$TEST_SUITE" >&2; exit 2; }
    exec python3 "$TEST_SUITE" --root "$BQCA_ROOT"
    ;;
  -h|--help|"")
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

# BQCA-CANONICAL-PRODUCTION-POLICY-v46:BEGIN
# The policy doctor verifies direct-default and formal-opt-in execution routing.
# BQCA-CANONICAL-PRODUCTION-POLICY-v46:END
