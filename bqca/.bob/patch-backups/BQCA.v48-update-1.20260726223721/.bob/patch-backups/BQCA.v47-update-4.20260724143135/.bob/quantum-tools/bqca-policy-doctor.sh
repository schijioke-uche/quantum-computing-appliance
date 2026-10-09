#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
BOB_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
BQCA_ROOT="$(cd "$BOB_ROOT/.." && pwd -P)"
DOCTOR="$SCRIPT_DIR/bqca-policy-doctor.py"
PATCH="$BQCA_ROOT/patches/BQCA/patch-BQCA.v47-update-2.sh"
REPORT="$BOB_ROOT/patches-applied/BQCA.v47-assurance-report.txt"

usage() {
  cat <<'USAGE'
BQCA v47 policy doctor

Usage:
  bqca-policy-doctor.sh check [--quiet]
  bqca-policy-doctor.sh report
  bqca-policy-doctor.sh repair
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
    [[ -x "$PATCH" ]] || { printf 'BQCA v47 repair patch is missing: %s\n' "$PATCH" >&2; exit 2; }
    exec "$PATCH" --target "$BQCA_ROOT"
    ;;
  -h|--help) usage ;;
  *) usage >&2; exit 2 ;;
esac
# BQCA-CANONICAL-PRODUCTION-POLICY-v47:BEGIN
# The sole active policy is .bob/BQCA-PRODUCTION-POLICY.md (v47).
# Direct execution streams complete stdout/stderr live and writes the exact
# professional report to <source-stem>-result-output.txt and output.txt.
# REAL_QPU results put the actual Job ID on line one. Direct contract gaps
# are warnings; formal orchestration is explicit opt-in.
# BQCA-CANONICAL-PRODUCTION-POLICY-v47:END
