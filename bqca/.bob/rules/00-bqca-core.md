# BQCA Core Workspace Rule for Bob Shell 2.x

<!-- BQCA-BOB-SHELL-V2-DNA:BEGIN -->
This trusted workspace is the IBM Bob Quantum Computing Agent. Apply this rule in every mode, including a built-in fallback mode.

1. Read `AGENTS.md` and resolve `.bob/BQCA-PRODUCTION-POLICY.md` through the active-policy listener.
2. Honor the exported BQCA menu option, action, skill identity, and selected mode.
3. Combine the current mode-specific rules with relevant BQCA skills, quantum tools, and the offline knowledgebase.
4. Designs belong under `bob-quantum-designs/`; executable artifacts and evidence belong under `bob-quantum-store/`.
5. Use the active design/code validators and require the current same-directory compliance report.
6. Preserve Qiskit account configuration, the home Qiskit environment, plan-aware real-QPU-first behavior, controlled simulator fallback, notebook synchronization, live direct execution, result-output governance, and credential protection.
7. Never degrade to generic Bob behavior merely because the Bob Shell major version or selected custom mode changed.
<!-- BQCA-BOB-SHELL-V2-DNA:END -->

<!-- BQCA-RESUME-CONTINUITY-v51.3:BEGIN -->
## Option 5 Resume Rule

When menu option 5 is selected, resume the latest real user session for this workspace using the exact `quantum-qiskit-connector` custom-mode slug. Authentication validation tasks such as `BOB_AUTH_OK` are not user sessions and must never be selected. Resolve and pass the exact task ID rather than relying on an unfiltered `latest` token.
<!-- BQCA-RESUME-CONTINUITY-v51.3:END -->
<!-- BQCA-TRUSTED-CHAT-AUTO-APPROVAL-v51.4:BEGIN -->
## Trusted BQCA chat auto-approval

Routine tool approvals in BQCA interactive/resume chat sessions are handled by the trusted session launch flags. Do not ask the user to approve ordinary project-scoped skills, reads, writes, directory creation, validators, or commands. This speed optimization never authorizes credential access, destructive operations, Bob home/settings changes, external-path writes, or bypass of active BQCA policy and safety gates.
<!-- BQCA-TRUSTED-CHAT-AUTO-APPROVAL-v51.4:END -->
