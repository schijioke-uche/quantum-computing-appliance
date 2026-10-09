#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
BOB_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
BQCA_ROOT="$(cd "$BOB_ROOT/.." && pwd -P)"
DOCTOR="$SCRIPT_DIR/bqca-policy-doctor.py"
usage() {
  cat <<'USAGE'
BQCA active central policy doctor
Usage:
  bqca-policy-doctor.sh check [--quiet]
  bqca-policy-doctor.sh report
  bqca-policy-doctor.sh repair
  bqca-policy-doctor.sh version
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
    (($# == 0)) || { usage >&2; exit 2; }
    active_version="$(python3 "$DOCTOR" version --root "$BQCA_ROOT")"
    report="$BOB_ROOT/patches-applied/BQCA.${active_version}-assurance-report.txt"
    exec python3 "$DOCTOR" report --root "$BQCA_ROOT" --output "$report"
    ;;
  repair)
    (($# == 0)) || { usage >&2; exit 2; }
    patch="$(python3 "$DOCTOR" repair-path --root "$BQCA_ROOT")"
    [[ -x "$patch" ]] || { printf 'BQCA active-policy repair patch is missing or not executable: %s\n' "$patch" >&2; exit 2; }
    exec "$patch" --target "$BQCA_ROOT"
    ;;
  version)
    (($# == 0)) || { usage >&2; exit 2; }
    exec python3 "$DOCTOR" version --root "$BQCA_ROOT"
    ;;
  -h|--help)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

# BQCA-ACTIVE-CENTRAL-POLICY:BEGIN
# Resolve the active authority through bqca-active-policy-listener.sh before
# every quantum DESIGN or CODE decision. Never hardcode a policy version or
# duplicate the full policy here. qiskit-design-policy-check.py and
# qiskit-code-policy-check.py reload the active registry/policy/contract on
# every invocation and create same-directory policy-compliance reports.
# Do not report completion until the active-policy report exists.
# BQCA-ACTIVE-CENTRAL-POLICY:END
