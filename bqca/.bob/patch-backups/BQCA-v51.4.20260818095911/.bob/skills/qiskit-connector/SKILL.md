---
name: qiskit-connector
description: Enforce real-QPU-first Qiskit Connector execution and mandatory simulator fallback in every BQCA code and design workflow.
---

# Qiskit Connector Skill v34

## Trigger

Invoke this skill for any quantum request that creates, implements, writes, generates, builds, develops, produces, scaffolds, constructs, modifies, repairs, fixes, refactors, executes, or otherwise creates code. Also invoke it for every quantum design, architecture, planning, specification, model, diagram, proposal, blueprint, or workflow-document request.

## Code workflow

1. Start from `.bob/quantum-tools/qiskit-connector-required-template.py`.
2. Preserve the exact Qiskit Connector imports and `current = plan()` / `backend = connector()` initialization.
3. Put real-QPU execution in the first `try` path.
4. Validate QPU operational state and qubit capacity.
5. Put simulator execution only in `except` or a post-check no-QPU branch.
6. Report execution target, account plan, backend, and fallback reason.
7. Save code under `bob-quantum-store/`.
8. Run Python compilation and `--validate-code`; repair until both pass.

## Design workflow

1. Start from `.bob/quantum-tools/qiskit-connector-design-required-template.md`.
2. Write textual architecture and implementation instructions only; do not place executable Python or fenced Python blocks in a design file.
3. State that the generated implementation must import QConnectorV2 as connector and QPlanV2 as plan and must initialize `current = plan()` and `backend = connector()`.
4. Specify plan discovery, QPU discovery, operational/capacity validation, real-QPU-first execution, and try/except simulator fallback.
5. State that simulator-first implementation is prohibited.
6. Save design under `bob-quantum-designs/`.
7. Run `--validate-design`; repair until it passes.

<!-- BQCA-ACTIVE-CENTRAL-POLICY:BEGIN -->
## Active central policy binding
Before every quantum DESIGN or CODE decision, resolve the currently active authority through `.bob/quantum-tools/bqca-active-policy-listener.sh sync`. Read the stable policy and its embedded validation contract returned by the listener. Never hardcode a policy version or duplicate the complete central policy in this component.

Validate every design through `.bob/quantum-tools/qiskit-design-policy-check.py` and every Python code artifact through `.bob/quantum-tools/qiskit-code-policy-check.py`. The validators reload the registry, policy, policy SHA-256, and validation contract on every invocation and automatically create the required same-directory design/code policy-compliance report. Do not report an artifact complete unless its compliance report exists and reflects the active policy.
<!-- BQCA-ACTIVE-CENTRAL-POLICY:END -->

<!-- BQCA-BOB-SHELL-V2-DNA:BEGIN -->
## Bob Shell 2.x BQCA project-DNA binding
In a trusted Bob Shell 2.x workspace, read `AGENTS.md`, resolve the active central BQCA policy, honor the exported menu option/action/skill/mode, and use the current rules, relevant skills, quantum tools, and offline knowledgebase. This component supplements the existing BQCA workflow and must not replace its domain purpose or active-policy controls. Never degrade to generic Bob behavior.
<!-- BQCA-BOB-SHELL-V2-DNA:END -->
