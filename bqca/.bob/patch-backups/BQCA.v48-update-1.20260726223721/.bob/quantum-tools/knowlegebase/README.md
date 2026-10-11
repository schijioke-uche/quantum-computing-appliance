# BQCA Local Quantum Algorithm Knowledgebase — v48

This directory contains an offline, curated algorithm catalog and generated examples for BQCA quantum DESIGN and CODE requests.

Update 6 supersedes Update 5's mandatory external URL crawling and sublink-drilldown gate. No network access is required to use this knowledgebase.

## Canonical files

- `bqca_quantum_algorithm_catalog.json` — machine-readable catalog.
- `bqca_quantum_kb.py` — local search, design-card, and code-scaffold engine.
- `examples/` — generated design cards and starter code.
- `bqca_quantum_kb_index.optional.txt` — optional legacy URL index, when one existed before Update 6.

## Tool

From the BQCA root:

```bash
.bob/quantum-tools/bqca-quantum-kb.sh validate
.bob/quantum-tools/bqca-quantum-kb.sh list
.bob/quantum-tools/bqca-quantum-kb.sh search --query "VQE chemistry energy"
.bob/quantum-tools/bqca-quantum-kb.sh show vqe
.bob/quantum-tools/bqca-quantum-kb.sh design vqe --output /tmp/vqe-design.md --force
.bob/quantum-tools/bqca-quantum-kb.sh scaffold vqe --output /tmp/vqe.py --force
.bob/quantum-tools/bqca-quantum-kb.sh research --query "QAOA MaxCut" --output /tmp/qaoa-kb.md
```

## Execution compatibility

- Qiskit SDK: 2.5.0 or later.
- Open Plan: no Session; use `SamplerV2(mode=backend)` for sampling/counts or `EstimatorV2(mode=backend)` for expectation-value/energy workloads.
- Paid Plan: use `Session(backend=backend)` with the suitable V2 primitive.
- Simulator fallback: use controlled `try/except` and AerSimulator or Aer V2 primitives.

The catalog supplements IBM Bob intelligence and approved research. It never overrides the active central BQCA policy. If the requested algorithm is absent, BQCA may use approved external research and document the decision; a missing local entry is not a blocking failure.

<!-- BQCA-CANONICAL-PRODUCTION-POLICY-v48:BEGIN -->
## BQCA v48 cumulative production authority
Use `.bob/BQCA-PRODUCTION-POLICY.md` as the sole active BQCA v48 policy. Direct synchronous execution through `.bob/quantum-tools/bqca-direct-execution.sh` is the default for development, testing, exploration, debugging, and quick experiments; formal orchestration is explicit opt-in only for compliance, deployment, or audit evidence. Preserve Qiskit account configuration, `$HOME/qiskit-v2x-env`, Qiskit 2.5+, Open Plan SamplerV2/EstimatorV2 job mode without Session, Paid Plan Session with the suitable V2 primitive, real-QPU-first behavior, controlled simulator fallback, automatic synchronized notebooks, request-scoped Hello World, live terminal output, `<source-stem>-result-output.txt`, `output.txt`, Job-ID-first real-QPU reports, and credential-leak blocking. For quantum DESIGN and CODE requests consult `.bob/quantum-tools/bqca-quantum-kb.sh` and the offline v48 algorithm catalog. The catalog supplements IBM Bob intelligence and never overrides the central policy. v48 incorporates core v47 and Updates 1-6; Update 6 supersedes Update 5 URL crawling.
<!-- BQCA-CANONICAL-PRODUCTION-POLICY-v48:END -->

## Active policy
All catalog entries, design cards, and starter examples are supplemental to `.bob/BQCA-PRODUCTION-POLICY.md` (BQCA v48). If any local catalog guidance conflicts with the central policy, v48 controls.

