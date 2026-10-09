#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
DIRECT="$SCRIPT_DIR/bqca-direct-execution.sh"
[[ -x "$DIRECT" ]] || { printf 'BQCA v48 direct executor is missing: %s\n' "$DIRECT" >&2; exit 2; }
(($# >= 1)) || { printf 'Usage: bqca-direct-execute.sh <file.py> [arguments...]\n' >&2; exit 2; }
exec "$DIRECT" run "$@"

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
