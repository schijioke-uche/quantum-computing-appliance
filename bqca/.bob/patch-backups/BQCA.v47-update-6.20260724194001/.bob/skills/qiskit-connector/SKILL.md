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

<!-- BQCA-CANONICAL-PRODUCTION-POLICY-v47:BEGIN -->
## BQCA v47 Update 4 superseding execution authority
Follow `.bob/BQCA-PRODUCTION-POLICY.md`. Direct execution through `.bob/quantum-tools/bqca-direct-execution.sh` is the default for development, testing, interactive exploration, debugging, and quick experiments. It uses `$HOME/qiskit-v2x-env/bin/python` with `PYTHONUNBUFFERED=1` and `python -u`, streams combined stdout/stderr live, and creates `<source-stem>-result-output.txt` plus `output.txt` beside the source. Quantum code must attempt a real QPU first, apply the Open/Paid Plan V2 primitive rules, use controlled `transpile` plus `AerSimulator` fallback, and emit `BQCA_EXECUTION_TARGET`, `BQCA_PLAN`, `BQCA_BACKEND`, `BQCA_JOB_ID`, `BQCA_RESULT=SUCCESS` or `BQCA_RESULT=FAILURE`, and `BQCA_FALLBACK_REASON` for fallback. The orchestrator is explicit opt-in only for formal compliance, production deployment, or audit evidence. Direct-mode policy gaps are warnings that preserve the workload exit status; credential leakage is blocking. This block supersedes conflicting local execution guidance.
<!-- BQCA-CANONICAL-PRODUCTION-POLICY-v47:END -->

<!-- BQCA-QUANTUM-KNOWLEDGEBASE-v47-update-5:BEGIN -->
## BQCA quantum knowledgebase research — v47 Update 5
For every quantum **DESIGN** or **CODE** intent, consult `.bob/quantum-tools/knowlegebase/bqca_quantum_kb_index.txt` through `.bob/quantum-tools/bqca-quantum-kb.sh` before finalizing the artifact. Access relevant seed URLs and drill into at least one relevant sublink from every seed accessed. Save `<artifact-stem>-kb-research.md` beside the governed artifact and use it alongside IBM Bob intelligence and other approved sources. The knowledgebase supplements but never overrides the active central policy. A missing/empty index, inaccessible seed, or incomplete sublink drilldown must be reported; do not claim a policy-compliant design/code result when the research gate fails.
<!-- BQCA-QUANTUM-KNOWLEDGEBASE-v47-update-5:END -->
