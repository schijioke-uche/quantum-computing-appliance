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
