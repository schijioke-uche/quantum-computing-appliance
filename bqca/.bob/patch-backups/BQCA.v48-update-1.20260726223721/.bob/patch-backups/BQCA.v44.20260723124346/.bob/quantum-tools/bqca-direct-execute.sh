#!/usr/bin/env bash
# BQCA v45 Direct Execution Wrapper with Result Summary
# Provides fast direct execution with structured result summary

set -euo pipefail

SCRIPT_PATH="${1:?Usage: bqca-direct-execute.sh <script.py>}"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
SCRIPT_NAME="$(basename "$SCRIPT_PATH" .py)"
OUTPUT_FILE="${SCRIPT_DIR}/${SCRIPT_NAME}-result-output.txt"
PYTHON_BIN="$HOME/qiskit-v2x-env/bin/python"

if [ ! -f "$PYTHON_BIN" ]; then
    echo "ERROR: Qiskit environment not found: $PYTHON_BIN"
    exit 1
fi

if [ ! -f "$SCRIPT_PATH" ]; then
    echo "ERROR: Script not found: $SCRIPT_PATH"
    exit 1
fi

# Capture execution
START_TIME=$(date -u +%Y-%m-%dT%H:%M:%S%z)
START_EPOCH=$(date +%s)

echo "Executing: $SCRIPT_PATH"
echo "Output: $OUTPUT_FILE"
echo ""

# Execute and capture output
set +e
"$PYTHON_BIN" "$SCRIPT_PATH" 2>&1 | tee "$OUTPUT_FILE"
EXIT_CODE=$?
set -e

END_TIME=$(date -u +%Y-%m-%dT%H:%M:%S%z)
END_EPOCH=$(date +%s)
DURATION=$((END_EPOCH - START_EPOCH))

# Parse BQCA markers from output
JOB_ID=$(grep "BQCA_JOB_ID=" "$OUTPUT_FILE" | tail -1 | cut -d= -f2 || echo "NOT REPORTED")
PLAN=$(grep "BQCA_PLAN=" "$OUTPUT_FILE" | tail -1 | cut -d= -f2 || echo "NOT REPORTED")
BACKEND=$(grep "BQCA_BACKEND=" "$OUTPUT_FILE" | tail -1 | cut -d= -f2 || echo "NOT REPORTED")
TARGET=$(grep "BQCA_EXECUTION_TARGET=" "$OUTPUT_FILE" | tail -1 | cut -d= -f2 || echo "UNKNOWN")
RESULT=$(grep "BQCA_RESULT=" "$OUTPUT_FILE" | tail -1 | cut -d= -f2 || echo "UNKNOWN")

# Determine success
if [ "$EXIT_CODE" -eq 0 ] && [ "$RESULT" = "SUCCESS" ]; then
    EXEC_SUCCESS="YES"
    CONTRACT_VALID="YES"
    ISSUES="NONE"
else
    EXEC_SUCCESS="NO"
    CONTRACT_VALID="NO"
    ISSUES="Exit code: $EXIT_CODE, Result: $RESULT"
fi

# Append result summary
cat >> "$OUTPUT_FILE" << EOF

----------------------------------------------------------------------------------------
RESULT SUMMARY
----------------------------------------------------------------------------------------
Execution successful    : $EXEC_SUCCESS
Result contract valid   : $CONTRACT_VALID
Final execution target  : $TARGET
Real-QPU job ID         : $JOB_ID
Backend                 : $BACKEND
Plan                    : $PLAN
Process exit status     : $EXIT_CODE
Completion date/time    : $END_TIME
Total duration          : $DURATION seconds
Source artifact         : $(realpath "$SCRIPT_PATH")
Result output           : $(realpath "$OUTPUT_FILE")
Policy/Execution issue(s): $ISSUES
========================================================================================
EOF

echo ""
echo "✓ Execution complete"
echo "  Exit code: $EXIT_CODE"
echo "  Duration: ${DURATION}s"
echo "  Result: $OUTPUT_FILE"

exit $EXIT_CODE
# BQCA-CANONICAL-PRODUCTION-POLICY-v44:BEGIN
# The sole active BQCA policy is .bob/BQCA-PRODUCTION-POLICY.md (v44).
# Route all public design, code, execution, result, and completion paths through
# bqca-policy-orchestrator.sh. Open Plan uses SamplerV2 or EstimatorV2 job mode
# according to workload semantics and must never use Session.
# BQCA-CANONICAL-PRODUCTION-POLICY-v44:END
