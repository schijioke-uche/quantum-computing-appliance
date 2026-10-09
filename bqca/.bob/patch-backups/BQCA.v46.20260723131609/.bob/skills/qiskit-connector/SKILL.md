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
<!-- BQCA-CANONICAL-PRODUCTION-POLICY-v45:BEGIN -->
## Canonical BQCA production policy
The sole active BQCA policy is `.bob/BQCA-PRODUCTION-POLICY.md` (v45). Historical policies are audit records only. Use `.bob/quantum-tools/bqca-policy-orchestrator.sh` for all design, code, execution, result, and completion gates, and `.bob/quantum-tools/bqca-policy-doctor.sh` for assurance. Open Plan real-QPU work must not use Session; use `SamplerV2(mode=backend)` for sampling workloads or `EstimatorV2(mode=backend)` for expectation-value/observable workloads.
<!-- BQCA-CANONICAL-PRODUCTION-POLICY-v45:END -->
<!-- BQCA-CANONICAL-PRODUCTION-POLICY-v44:BEGIN -->
## Canonical BQCA production policy
The sole active BQCA policy is `.bob/BQCA-PRODUCTION-POLICY.md` (v44). Historical policies are audit records only. Use `.bob/quantum-tools/bqca-policy-orchestrator.sh` for all design, code, execution, result, and completion gates, and `.bob/quantum-tools/bqca-policy-doctor.sh` for assurance. Open Plan real-QPU work must not use Session; use `SamplerV2(mode=backend)` for sampling workloads or `EstimatorV2(mode=backend)` for expectation-value/observable workloads.
<!-- BQCA-CANONICAL-PRODUCTION-POLICY-v44:END -->
