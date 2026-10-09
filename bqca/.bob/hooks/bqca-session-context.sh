#!/usr/bin/env sh
set -eu
# Consume the hook payload; SessionStart context is derived from the trusted workspace.
cat >/dev/null || true
ROOT="$(pwd -P)"
LISTENER="$ROOT/.bob/quantum-tools/bqca-active-policy-listener.sh"
POLICY_VERSION="${BQCA_ACTIVE_POLICY_VERSION:-UNKNOWN}"
POLICY_PATH="${BQCA_ACTIVE_POLICY_PATH:-$ROOT/.bob/BQCA-PRODUCTION-POLICY.md}"
if [ -x "$LISTENER" ]; then
  POLICY_VERSION="$($LISTENER version 2>/dev/null || printf '%s' "$POLICY_VERSION")"
  POLICY_PATH="$($LISTENER policy-path 2>/dev/null || printf '%s' "$POLICY_PATH")"
fi
cat <<EOF_CONTEXT
BQCA_SESSION_CONTEXT=ACTIVE
Appliance: IBM Bob Quantum Computing Agent (BQCA)
Menu option: ${BQCA_MENU_OPTION:-interactive-or-unspecified}
Menu action: ${BQCA_MENU_ACTION:-BQCA workspace session}
Skill identity: ${BQCA_MENU_SKILL_ID:-BQCA intelligence}
Selected mode: ${BQCA_SELECTED_MODE:-current Bob mode}
Active policy version: $POLICY_VERSION
Active policy path: $POLICY_PATH
Project context: Read AGENTS.md, the active mode rules, .bob/rules/00-bqca-core.md, relevant .bob/skills, .bob/quantum-tools, and the offline quantum knowledgebase. Preserve BQCA artifact routing, validators, notebook synchronization, execution, result-output, and security requirements.
EOF_CONTEXT
