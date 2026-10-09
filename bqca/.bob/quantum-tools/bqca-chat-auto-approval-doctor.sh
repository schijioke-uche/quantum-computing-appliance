#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BQCA_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
MARKER="BQCA-TRUSTED-CHAT-AUTO-APPROVAL-v51.4"
quiet=0
command_name="${1:-check}"
shift || true
while (($#)); do
  case "$1" in --quiet) quiet=1; shift ;; *) echo "Unknown option: $1" >&2; exit 2 ;; esac
done
issues=()
add_issue() { issues+=("$*"); }

# BQCA-BOB-SHELL-V2-DNA:BEGIN
# BQCA Bob 2.x project-DNA assurance component.
# BQCA-BOB-SHELL-V2-DNA:END
# BQCA-ACTIVE-CENTRAL-POLICY:BEGIN
# Dynamically validates the active central-policy integration.
# BQCA-ACTIVE-CENTRAL-POLICY:END

stable="$BQCA_ROOT/.bob/BQCA-PRODUCTION-POLICY.md"
registry="$BQCA_ROOT/.bob/BQCA-ACTIVE-POLICY-REGISTRY.json"
custom="$BQCA_ROOT/.bob/custom_modes.yaml"
helper="$BQCA_ROOT/.bob/quantum-tools/bqca-chat-auto-approval.sh"
env_example="$BQCA_ROOT/.env.example"
bob1="$BQCA_ROOT/bob-quantum-v1x.sh"
bob2="$(find "$BQCA_ROOT" -maxdepth 1 -type f -name 'bob-quantum-v2*.sh' -print | sort -V | tail -n 1)"

[[ -x "$helper" ]] || add_issue "missing executable helper: $helper"
[[ -f "$stable" ]] || add_issue "missing active policy"
[[ -f "$registry" ]] || add_issue "missing policy registry"
[[ -f "$custom" ]] || add_issue "missing custom_modes.yaml"
[[ -f "$bob2" ]] || add_issue "missing Bob 2.x launcher"

auto_rule="$BQCA_ROOT/.bob/rules/01-bqca-trusted-chat-auto-approval.md"
[[ -f "$auto_rule" ]] || add_issue "missing trusted chat auto-approval rule"
if [[ -f "$auto_rule" ]]; then
  [[ "$(grep -c "$MARKER:BEGIN" "$auto_rule" || true)" -eq 1 ]] || add_issue "trusted chat auto-approval rule marker count is not 1"
fi
if [[ -f "$custom" ]]; then
  expected="$(grep -c '^[[:space:]]*customInstructions:' "$custom" || true)"
  actual="$(grep -c "$MARKER:BEGIN" "$custom" || true)"
  [[ "$actual" -eq "$expected" ]] || add_issue "custom-mode coverage is $actual/$expected"
fi
if [[ -f "$bob2" ]]; then
  grep -Fq 'BQCA_CHAT_AUTO_APPROVE="${BQCA_CHAT_AUTO_APPROVE:-1}"' "$bob2" || add_issue "Bob 2.x launcher does not default trusted chat auto-approval on"
  grep -Fq 'bob2_args+=(--auto-approve)' "$bob2" || add_issue "Bob 2.x chat does not add --auto-approve"
  grep -Fq 'local -a bob2_args=(chat --trust)' "$bob2" || add_issue "Bob 2.x chat does not enforce --trust"
fi
if [[ -f "$bob1" ]]; then
  grep -Fq 'BQCA_BOB1_CHAT_APPROVAL_FLAGS' "$bob1" || add_issue "Bob 1.x launcher has no full chat approval flags"
fi
if [[ -f "$env_example" ]]; then
  grep -Eq '^BQCA_CHAT_AUTO_APPROVE=1$' "$env_example" || add_issue ".env.example does not enable BQCA_CHAT_AUTO_APPROVE"
fi

rule_files=0; rule_ok=0
while IFS= read -r -d '' f; do
  rule_files=$((rule_files+1)); grep -q "$MARKER:BEGIN" "$f" && rule_ok=$((rule_ok+1))
done < <(find "$BQCA_ROOT/.bob" -maxdepth 2 -type f -path '*/rules*/*.md' -print0)
skill_files=0; skill_ok=0
while IFS= read -r -d '' f; do
  skill_files=$((skill_files+1)); grep -q "$MARKER:BEGIN" "$f" && skill_ok=$((skill_ok+1))
done < <(find "$BQCA_ROOT/.bob/skills" -type f \( -name 'SKILL.md' -o -name 'README-custom-skills.md' \) -print0)
tool_files=0; tool_ok=0
while IFS= read -r -d '' f; do
  tool_files=$((tool_files+1)); grep -q "$MARKER:BEGIN" "$f" && tool_ok=$((tool_ok+1))
done < <(find "$BQCA_ROOT/.bob/quantum-tools" -maxdepth 1 -type f \( -name '*.sh' -o -name '*.py' -o -name '*.md' -o -name '*.txt' -o -name '*.yaml' -o -name '*.yml' \) -print0)
[[ "$rule_ok" -eq "$rule_files" ]] || add_issue "rule coverage is $rule_ok/$rule_files"
[[ "$skill_ok" -eq "$skill_files" ]] || add_issue "skill coverage is $skill_ok/$skill_files"
[[ "$tool_ok" -eq "$tool_files" ]] || add_issue "tool coverage is $tool_ok/$tool_files"

status=PASS
((${#issues[@]} == 0)) || status=FAIL
if [[ "$quiet" -eq 0 || "$status" == FAIL || "$command_name" == report ]]; then
  printf '%s\n' '========================================================================================'
  printf '%s\n' 'BQCA v51.4 TRUSTED CHAT AUTO-APPROVAL ASSURANCE REPORT'
  printf '%s\n' '========================================================================================'
  printf 'Custom modes           : %s\n' "${actual:-0}/${expected:-0}"
  printf 'Rules / Skills / Tools : %s/%s / %s/%s / %s/%s\n' "$rule_ok" "$rule_files" "$skill_ok" "$skill_files" "$tool_ok" "$tool_files"
  printf 'Issues                 : %s\n' "${#issues[@]}"
  if ((${#issues[@]})); then
    printf '%s\n' '----------------------------------------------------------------------------------------'
    for issue in "${issues[@]}"; do printf -- '- %s\n' "$issue"; done
  fi
  printf '%s\n' '----------------------------------------------------------------------------------------'
  printf 'FINAL AUTO-APPROVAL STATUS : %s\n' "$status"
  printf 'BQCA_CHAT_AUTO_APPROVAL_ASSURANCE=%s\n' "$status"
  printf '%s\n' '========================================================================================'
fi
[[ "$status" == PASS ]]
# BQCA-TRUSTED-CHAT-AUTO-APPROVAL-v51.4:BEGIN
# Trusted BQCA chat sessions auto-approve routine project-scoped tool calls at
# session launch. This does not authorize secrets, destructive operations, Bob
# home/settings writes, external paths, or bypass of BQCA policy/safety gates.
# BQCA-TRUSTED-CHAT-AUTO-APPROVAL-v51.4:END
