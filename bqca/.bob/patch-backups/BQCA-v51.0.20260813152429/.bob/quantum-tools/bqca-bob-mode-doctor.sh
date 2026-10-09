#!/usr/bin/env bash
set -Eeuo pipefail
# BQCA-ACTIVE-CENTRAL-POLICY:BEGIN
# Resolve and follow .bob/BQCA-PRODUCTION-POLICY.md through the active-policy
# registry. This wrapper never overrides or duplicates the central policy.
# BQCA-ACTIVE-CENTRAL-POLICY:END
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BQCA_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
exec python3 "$SCRIPT_DIR/bqca-bob-mode-doctor.py" "$@" --root "$BQCA_ROOT"
