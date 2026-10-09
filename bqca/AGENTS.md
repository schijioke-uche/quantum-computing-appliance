# IBM Bob Quantum Computing Agent (BQCA) — Project Context

<!-- BQCA-BOB-SHELL-V2-DNA:BEGIN -->
This workspace is the **IBM Bob Quantum Computing Agent (BQCA)**. Never operate as a generic coding assistant when this project is trusted. Use the active menu context, active central policy, custom mode, rules, skills, quantum tools, and offline quantum knowledgebase together.

## Active authority

- Resolve the active BQCA policy through `.bob/quantum-tools/bqca-active-policy-listener.sh`.
- The stable authority is `.bob/BQCA-PRODUCTION-POLICY.md`.
- Do not replace, weaken, or independently reinterpret the active policy.
- Historical policies and patch files are audit records unless the active registry says otherwise.

## Menu and mode identity

The launcher exports `BQCA_MENU_OPTION`, `BQCA_MENU_ACTION`, `BQCA_MENU_SKILL_ID`, and `BQCA_SELECTED_MODE`. Honor those values for the current task:

- Option 1: interactive BQCA workbench.
- Option 2: Quantum Expert questions and explanations.
- Option 3: Quantum Developer implementation and executable artifacts.
- Option 4: Quantum Advanced textual solution design.
- Option 5: resume the latest BQCA activity without losing context.

## Governed artifact contract

- Designs and architecture: `bob-quantum-designs/`.
- Python, notebooks, results, plots, logs, and implementation evidence: `bob-quantum-store/`.
- Python is authoritative; the same-name notebook is generated and synchronized automatically.
- Every design and Python artifact must pass the active-policy validator and have a current same-directory policy-compliance report before completion is claimed.

## Quantum execution contract

- Configure the `bqca` Qiskit account before Connector/backend operations.
- Use only `$HOME/qiskit-v2x-env` with Qiskit 2.5 or later.
- Attempt an eligible real QPU before controlled simulator fallback.
- Open Plan: no Session; use `SamplerV2(mode=backend)` for sampled outputs or `EstimatorV2(mode=backend)` for expectation values/energy.
- Paid Plan: use `Session(backend=backend)` with the suitable V2 primitive.
- Never use `backend.run()` on real IBM Quantum hardware.
- Use direct synchronous execution by default; formal orchestration is explicit opt-in for compliance/deployment/audit evidence.
- Stream terminal output and create the governed result-output files required by the active policy.

## BQCA intelligence sources

Use the current mode-specific rule directory, `.bob/rules/`, `.bob/skills/`, `.bob/quantum-tools/`, and `.bob/quantum-tools/knowlegebase/`. The offline knowledgebase supplements IBM Bob intelligence and never overrides the active policy or current official product documentation.

## Security

Never expose `.env`, Bob API keys, IBM Quantum tokens, Qiskit account secrets, or credentials in designs, code, notebooks, logs, reports, prompts, or tool output.
<!-- BQCA-BOB-SHELL-V2-DNA:END -->

<!-- BQCA-RESUME-CONTINUITY-v51.3:BEGIN -->
## Bob Shell 2.x Resume Continuity

Menu option 5 is a production BQCA resume operation. It must resolve the latest real user task in the current BQCA workspace, exclude authentication-probe tasks, and invoke `bob chat --mode quantum-qiskit-connector --resume <task-id>`. It must never omit the mode or silently fall back to Agent Mode.
<!-- BQCA-RESUME-CONTINUITY-v51.3:END -->

<!-- BQCA-TRUSTED-CHAT-AUTO-APPROVAL-v51.4:BEGIN -->
## Trusted BQCA chat auto-approval

BQCA menu option 1 and option 5 launch trusted interactive chat sessions with full session-level auto-approval. Bob Shell 2.x uses `--trust --auto-approve`; Bob Shell 1.x uses the full capability advertised by the installed CLI (`--auto-approve` or `--yolo`). This prevents routine skill, file, and command approval prompts from interrupting the BQCA workflow.

Auto-approval is confined to the trusted BQCA project and does not authorize credential access, destructive system actions, Bob settings/home writes, unapproved external paths, or bypass of BQCA validators and policy gates.
<!-- BQCA-TRUSTED-CHAT-AUTO-APPROVAL-v51.4:END -->
