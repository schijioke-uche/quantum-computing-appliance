#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOB_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BQCA_ROOT="$(cd "$BOB_ROOT/.." && pwd)"
WATCHER="$SCRIPT_DIR/notebook-autogen-watcher.py"
GENERATOR="$SCRIPT_DIR/notebook-generator.sh"
RUNTIME_DIR="$BOB_ROOT/runtime"
PID_FILE="$RUNTIME_DIR/notebook-autogen.pid"
LOG_FILE="$RUNTIME_DIR/notebook-autogen.log"
DEFAULT_STORE="$BQCA_ROOT/bob-quantum-store"

usage() {
  cat <<'USAGE'
BQCA automatic notebook runtime controller

Usage:
  notebook-autogen.sh start [--store <directory>]
  notebook-autogen.sh stop
  notebook-autogen.sh status
  notebook-autogen.sh sweep [--store <directory>]
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
    [[ "$cmdline" == *"notebook-autogen-watcher.py"* ]] || return 1
  fi
  return 0
}

store="$DEFAULT_STORE"
command_name="${1:-}"
[[ -n "$command_name" ]] || { usage; exit 2; }
shift || true
while (($#)); do
  case "$1" in
    --store) (($# >= 2)) || { echo "--store requires a path" >&2; exit 2; }; store="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

mkdir -p "$RUNTIME_DIR" "$store"
chmod 700 "$RUNTIME_DIR" 2>/dev/null || true

case "$command_name" in
  start)
    if is_running; then
      printf 'BQCA_NOTEBOOK_AUTOGEN=RUNNING PID=%s\n' "$(cat "$PID_FILE")"
      exit 0
    fi
    rm -f "$PID_FILE"
    nohup python3 "$WATCHER" --store "$store" --generator "$GENERATOR" --log "$LOG_FILE" >/dev/null 2>&1 &
    pid=$!
    printf '%s\n' "$pid" > "$PID_FILE"
    sleep 0.2
    if ! kill -0 "$pid" 2>/dev/null; then
      rm -f "$PID_FILE"
      printf 'BQCA_NOTEBOOK_AUTOGEN=FAIL: watcher did not start; inspect %s\n' "$LOG_FILE" >&2
      exit 3
    fi
    printf 'BQCA_NOTEBOOK_AUTOGEN=STARTED PID=%s STORE=%s\n' "$pid" "$store"
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
    printf 'BQCA_NOTEBOOK_AUTOGEN=STOPPED\n'
    ;;
  status)
    if is_running; then
      printf 'BQCA_NOTEBOOK_AUTOGEN=RUNNING PID=%s LOG=%s\n' "$(cat "$PID_FILE")" "$LOG_FILE"
    else
      printf 'BQCA_NOTEBOOK_AUTOGEN=STOPPED\n'
      exit 1
    fi
    ;;
  sweep)
    python3 "$WATCHER" --store "$store" --generator "$GENERATOR" --sweep --log "$LOG_FILE"
    printf 'BQCA_NOTEBOOK_AUTOGEN=SWEEP_COMPLETE STORE=%s\n' "$store"
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
