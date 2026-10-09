#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
BOB_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
BQCA_ROOT="$(cd "$BOB_ROOT/.." && pwd -P)"
DOCTOR="$SCRIPT_DIR/bqca-policy-doctor.py"
TEST_SUITE="$SCRIPT_DIR/bqca-policy-test-suite.py"
REPORT="$BOB_ROOT/reports/BQCA.v47-assurance-report.txt"

usage() {
  cat <<'USAGE'
BQCA v47 semantic policy doctor

Usage:
  bqca-policy-doctor.sh check [--quiet] [--json]
  bqca-policy-doctor.sh report [--json]
  bqca-policy-doctor.sh repair [--quiet] [--json]
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
    exec python3 "$DOCTOR" report --root "$BQCA_ROOT" --output "$REPORT" "$@"
    ;;
  repair)
    exec python3 "$DOCTOR" repair --root "$BQCA_ROOT" "$@"
    ;;
  test)
    (($# == 0)) || { usage; exit 2; }
    exec python3 "$TEST_SUITE" --root "$BQCA_ROOT"
    ;;
  -h|--help)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
# BQCA-CANONICAL-PRODUCTION-POLICY-v47:BEGIN
# BQCA v47 performs semantic policy assurance and safe self-repair.
# Exact source layout or command-dispatch formatting is not an integrity boundary.
# BQCA-CANONICAL-PRODUCTION-POLICY-v47:END
