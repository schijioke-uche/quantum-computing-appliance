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

<!-- BQCA-CANONICAL-PRODUCTION-POLICY-v48:BEGIN -->
## BQCA v48 cumulative production authority
Use `.bob/BQCA-PRODUCTION-POLICY.md` as the sole active BQCA v48 policy. Direct synchronous execution through `.bob/quantum-tools/bqca-direct-execution.sh` is the default for development, testing, exploration, debugging, and quick experiments; the formal orchestrator is explicit opt-in only for compliance, deployment, or audit evidence. Preserve Qiskit Connector configuration, `$HOME/qiskit-v2x-env`, Qiskit 2.5+, Open Plan SamplerV2/EstimatorV2 job mode without Session, Paid Plan Session with the suitable V2 primitive, real-QPU-first behavior, controlled simulator fallback, automatic synchronized notebooks, request-scoped Hello World, live terminal output, `<source-stem>-result-output.txt`, `output.txt`, Job-ID-first real-QPU reports, and credential-leak blocking. For quantum DESIGN and CODE requests consult `.bob/quantum-tools/bqca-quantum-kb.sh` and the offline v48 algorithm catalog. The catalog supplements IBM Bob intelligence and never overrides the central policy. v48 incorporates core v47 and Updates 1-6; Update 6 supersedes Update 5 URL crawling.
<!-- BQCA-CANONICAL-PRODUCTION-POLICY-v48:END -->
