#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
exec python3 "${SCRIPT_DIR}/bqca-custom-mode-rules.py" "$@"

# BQCA-ACTIVE-CENTRAL-POLICY:BEGIN
# Resolve and obey the current stable BQCA policy and validation contract.
# BQCA-ACTIVE-CENTRAL-POLICY:END

# BQCA-BOB-SHELL-V2-DNA:BEGIN
# Bind this tool to AGENTS.md, active BQCA policy, menu context, current rules,
# relevant skills/tools, and the offline knowledgebase without changing purpose.
# BQCA-BOB-SHELL-V2-DNA:END
# BQCA-TRUSTED-CHAT-AUTO-APPROVAL-v51.4:BEGIN
# Trusted BQCA chat sessions auto-approve routine project-scoped tool calls at
# session launch. This does not authorize secrets, destructive operations, Bob
# home/settings writes, external paths, or bypass of BQCA policy/safety gates.
# BQCA-TRUSTED-CHAT-AUTO-APPROVAL-v51.4:END
