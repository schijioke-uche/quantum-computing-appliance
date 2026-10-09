#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
BOB_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
BQCA_ROOT="$(cd "$BOB_ROOT/.." && pwd -P)"
DOCTOR="$SCRIPT_DIR/bqca-policy-doctor.py"
PATCH="$BQCA_ROOT/patches/BQCA/patch-BQCA.v48.sh"
REPORT="$BOB_ROOT/patches-applied/BQCA.v48-assurance-report.txt"
usage(){ cat <<'USAGE'
BQCA v48 policy doctor
Usage:
  bqca-policy-doctor.sh check [--quiet]
  bqca-policy-doctor.sh report
  bqca-policy-doctor.sh repair
USAGE
}
cmd="${1:-}"; [[ -n "$cmd" ]] || { usage; exit 2; }; shift || true
case "$cmd" in
 check) exec python3 "$DOCTOR" check --root "$BQCA_ROOT" "$@" ;;
 report) (($#==0)) || { usage; exit 2; }; exec python3 "$DOCTOR" report --root "$BQCA_ROOT" --output "$REPORT" ;;
 repair) (($#==0)) || { usage; exit 2; }; [[ -x "$PATCH" ]] || { printf 'BQCA v48 repair patch is missing: %s\n' "$PATCH" >&2; exit 2; }; exec "$PATCH" --target "$BQCA_ROOT" ;;
 -h|--help) usage ;;
 *) usage >&2; exit 2 ;;
esac

# BQCA-CANONICAL-PRODUCTION-POLICY-v48:BEGIN
# Use .bob/BQCA-PRODUCTION-POLICY.md as the sole active BQCA v48 authority.
# Direct synchronous execution is the default; formal orchestration is explicit
# opt-in. Preserve the Qiskit configuration/home-environment/2.5+ gates,
# plan-aware Runtime V2 execution, real-QPU-first fallback order, synchronized
# notebooks, scoped Hello World behavior, live dual-result capture, Job-ID-first
# real-QPU reports, and secret protection. Quantum DESIGN and CODE work consults
# bqca-quantum-kb.sh and the offline v48 catalog. v48 incorporates core v47 and
# Updates 1-6; Update 6 supersedes Update 5 URL crawling.
# BQCA-CANONICAL-PRODUCTION-POLICY-v48:END
