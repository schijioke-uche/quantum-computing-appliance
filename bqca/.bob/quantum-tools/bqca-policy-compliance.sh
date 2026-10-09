#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
BOB_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
BQCA_ROOT="$(cd "$BOB_ROOT/.." && pwd -P)"
WATCHER="$SCRIPT_DIR/bqca-policy-compliance-watcher.py"
VALIDATOR="$SCRIPT_DIR/bqca-dynamic-validator.py"
RUNTIME_DIR="$BOB_ROOT/runtime"
PID_FILE="$RUNTIME_DIR/bqca-policy-compliance.pid"
LOG_FILE="$RUNTIME_DIR/bqca-policy-compliance.log"
DEFAULT_DESIGN_STORE="$BQCA_ROOT/bob-quantum-designs"
DEFAULT_CODE_STORE="$BQCA_ROOT/bob-quantum-store"

usage() {
  cat <<'USAGE'
BQCA active-policy compliance-report controller
Usage:
  bqca-policy-compliance.sh start [--design-store <dir>] [--code-store <dir>]
  bqca-policy-compliance.sh stop
  bqca-policy-compliance.sh status
  bqca-policy-compliance.sh sweep [--design-store <dir>] [--code-store <dir>]
USAGE
}

is_running() {
  [[ -f "$PID_FILE" ]] || return 1
  local pid cmdline
  pid="$(cat "$PID_FILE" 2>/dev/null || true)"
  [[ "$pid" =~ ^[0-9]+$ ]] || return 1
  kill -0 "$pid" 2>/dev/null || return 1
  if [[ -r "/proc/$pid/cmdline" ]]; then
    cmdline="$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null || true)"
    [[ "$cmdline" == *"bqca-policy-compliance-watcher.py"* ]] || return 1
  fi
}

design_store="$DEFAULT_DESIGN_STORE"
code_store="$DEFAULT_CODE_STORE"
command_name="${1:-}"
[[ -n "$command_name" ]] || { usage; exit 2; }
shift || true
while (($#)); do
  case "$1" in
    --design-store) (($# >= 2)) || { echo "--design-store requires a path" >&2; exit 2; }; design_store="$2"; shift 2 ;;
    --code-store) (($# >= 2)) || { echo "--code-store requires a path" >&2; exit 2; }; code_store="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done
mkdir -p "$RUNTIME_DIR" "$design_store" "$code_store"
chmod 700 "$RUNTIME_DIR" 2>/dev/null || true

case "$command_name" in
  start)
    if is_running; then
      printf 'BQCA_POLICY_COMPLIANCE=RUNNING PID=%s\n' "$(cat "$PID_FILE")"
      exit 0
    fi
    rm -f "$PID_FILE"
    nohup python3 "$WATCHER" \
      --root "$BQCA_ROOT" \
      --design-store "$design_store" \
      --code-store "$code_store" \
      --validator "$VALIDATOR" \
      --log "$LOG_FILE" >/dev/null 2>&1 &
    pid=$!
    printf '%s\n' "$pid" > "$PID_FILE"
    sleep 0.2
    if ! kill -0 "$pid" 2>/dev/null; then
      rm -f "$PID_FILE"
      printf 'BQCA_POLICY_COMPLIANCE=FAIL: watcher did not start; inspect %s\n' "$LOG_FILE" >&2
      exit 3
    fi
    printf 'BQCA_POLICY_COMPLIANCE=STARTED PID=%s\n' "$pid"
    ;;
  stop)
    if is_running; then
      pid="$(cat "$PID_FILE")"
      kill "$pid" 2>/dev/null || true
      for _ in 1 2 3 4 5 6 7 8 9 10; do
        kill -0 "$pid" 2>/dev/null || break
        sleep 0.1
      done
      kill -9 "$pid" 2>/dev/null || true
    fi
    rm -f "$PID_FILE"
    printf 'BQCA_POLICY_COMPLIANCE=STOPPED\n'
    ;;
  status)
    if is_running; then
      printf 'BQCA_POLICY_COMPLIANCE=RUNNING PID=%s LOG=%s\n' "$(cat "$PID_FILE")" "$LOG_FILE"
    else
      printf 'BQCA_POLICY_COMPLIANCE=STOPPED\n'
      exit 1
    fi
    ;;
  sweep)
    python3 "$WATCHER" \
      --root "$BQCA_ROOT" \
      --design-store "$design_store" \
      --code-store "$code_store" \
      --validator "$VALIDATOR" \
      --sweep --log "$LOG_FILE"
    printf 'BQCA_POLICY_COMPLIANCE=SWEEP_COMPLETE\n'
    ;;
  *) usage; exit 2 ;;
esac

# BQCA-ACTIVE-CENTRAL-POLICY:BEGIN
# Resolve the active authority through bqca-active-policy-listener.sh before
# every quantum DESIGN or CODE decision. Never hardcode a policy version or
# duplicate the full policy here. qiskit-design-policy-check.py and
# qiskit-code-policy-check.py reload the active registry/policy/contract on
# every invocation and create same-directory policy-compliance reports.
# Do not report completion until the active-policy report exists.
# BQCA-ACTIVE-CENTRAL-POLICY:END

# BQCA-BOB-SHELL-V2-DNA:BEGIN
# In a trusted Bob Shell 2.x workspace, bind this component to AGENTS.md, the
# active central BQCA policy, exported menu context, current rules/skills/tools,
# and the offline knowledgebase without changing this component's core purpose.
# BQCA-BOB-SHELL-V2-DNA:END
# BQCA-TRUSTED-CHAT-AUTO-APPROVAL-v51.4:BEGIN
# Trusted BQCA chat sessions auto-approve routine project-scoped tool calls at
# session launch. This does not authorize secrets, destructive operations, Bob
# home/settings writes, external paths, or bypass of BQCA policy/safety gates.
# BQCA-TRUSTED-CHAT-AUTO-APPROVAL-v51.4:END
