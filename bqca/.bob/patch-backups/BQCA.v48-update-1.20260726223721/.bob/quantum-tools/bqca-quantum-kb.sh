#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENGINE="$SCRIPT_DIR/knowlegebase/bqca_quantum_kb.py"
CATALOG="$SCRIPT_DIR/knowlegebase/bqca_quantum_algorithm_catalog.json"
[[ -x "$ENGINE" ]] || { printf 'BQCA_LOCAL_KB=FAIL: missing engine: %s\n' "$ENGINE" >&2; exit 2; }
[[ -f "$CATALOG" ]] || { printf 'BQCA_LOCAL_KB=FAIL: missing catalog: %s\n' "$CATALOG" >&2; exit 2; }
exec python3 "$ENGINE" --catalog "$CATALOG" "$@"

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
