# Custom Appliance Skills Index

This workspace includes the following shared IBM Bob skills for appliance operation:

| Skill | Purpose |
|---|---|
| create-plan | Structured planning before implementation work. |
| create-skill | Creation and validation of reusable Bob skills. |
| create-mode | Creation and validation of Bob custom modes. |
| configure-mcp | Add or diagnose MCP server configuration. |
| build-mcp-server | Build a custom MCP server for Bob tools/prompts. |
| xlsx-insights | Analyze Excel workbooks through sampling and scripted extraction. |
| git-version-control | Provide comprehensive Git command and workflow guidance. |

These skills are workspace-scoped under `.bob/skills/` and are intended to be auto-invoked when the user request matches the skill description.

## bob_quantum_skill

Alias skill for QCA generated-code quality policy, dual `.py` + `.ipynb` artifact generation, Qiskit/Python virtual environment readiness, dependency preflight, syntax validation, and clean execution behavior.

<!-- BQCA-v30-POLICY-REFERENCE-START -->
## BQCA Production Policy v30 — Authoritative Precedence
Use `.bob/BQCA-PRODUCTION-POLICY.md` as the authoritative appliance-wide
policy. Preserve the specialized intelligence of this mode, rule, skill, or tool,
but resolve routing, implementation, execution, security, and completion behavior
according to the v30 policy. Design artifacts go to `bob-quantum-designs/`;
implementation and result artifacts go to `bob-quantum-store/`. Legacy
implementation directories must never be used.
<!-- BQCA-v30-POLICY-REFERENCE-END -->

<!-- BQCA-ACTIVE-CENTRAL-POLICY:BEGIN -->
## Active central policy binding
Before every quantum DESIGN or CODE decision, resolve the currently active authority through `.bob/quantum-tools/bqca-active-policy-listener.sh sync`. Read the stable policy and its embedded validation contract returned by the listener. Never hardcode a policy version or duplicate the complete central policy in this component.

Validate every design through `.bob/quantum-tools/qiskit-design-policy-check.py` and every Python code artifact through `.bob/quantum-tools/qiskit-code-policy-check.py`. The validators reload the registry, policy, policy SHA-256, and validation contract on every invocation and automatically create the required same-directory design/code policy-compliance report. Do not report an artifact complete unless its compliance report exists and reflects the active policy.
<!-- BQCA-ACTIVE-CENTRAL-POLICY:END -->

<!-- BQCA-BOB-SHELL-V2-DNA:BEGIN -->
## Bob Shell 2.x BQCA project-DNA binding
In a trusted Bob Shell 2.x workspace, read `AGENTS.md`, resolve the active central BQCA policy, honor the exported menu option/action/skill/mode, and use the current rules, relevant skills, quantum tools, and offline knowledgebase. This component supplements the existing BQCA workflow and must not replace its domain purpose or active-policy controls. Never degrade to generic Bob behavior.
<!-- BQCA-BOB-SHELL-V2-DNA:END -->
<!-- BQCA-TRUSTED-CHAT-AUTO-APPROVAL-v51.4:BEGIN -->
## Trusted BQCA chat auto-approval

Routine tool approvals in BQCA interactive/resume chat sessions are handled by the trusted session launch flags. Do not ask the user to approve ordinary project-scoped skills, reads, writes, directory creation, validators, or commands. This speed optimization never authorizes credential access, destructive operations, Bob home/settings changes, external-path writes, or bypass of active BQCA policy and safety gates.
<!-- BQCA-TRUSTED-CHAT-AUTO-APPROVAL-v51.4:END -->
