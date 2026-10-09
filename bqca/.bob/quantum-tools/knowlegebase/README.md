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


## Active policy
All catalog entries, design cards, and starter examples are supplemental to `.bob/BQCA-PRODUCTION-POLICY.md` (BQCA v48). If any local catalog guidance conflicts with the central policy, v48 controls.

<!-- BQCA-ACTIVE-CENTRAL-POLICY:BEGIN -->
## Active central policy binding
Before every quantum DESIGN or CODE decision, resolve the currently active authority through `.bob/quantum-tools/bqca-active-policy-listener.sh sync`. Read the stable policy and its embedded validation contract returned by the listener. Never hardcode a policy version or duplicate the complete central policy in this component.

Validate every design through `.bob/quantum-tools/qiskit-design-policy-check.py` and every Python code artifact through `.bob/quantum-tools/qiskit-code-policy-check.py`. The validators reload the registry, policy, policy SHA-256, and validation contract on every invocation and automatically create the required same-directory design/code policy-compliance report. Do not report an artifact complete unless its compliance report exists and reflects the active policy.
<!-- BQCA-ACTIVE-CENTRAL-POLICY:END -->

<!-- BQCA-BOB-SHELL-V2-DNA:BEGIN -->
## Bob Shell 2.x BQCA project-DNA binding
In a trusted Bob Shell 2.x workspace, read `AGENTS.md`, resolve the active central BQCA policy, honor the exported menu option/action/skill/mode, and use the current rules, relevant skills, quantum tools, and offline knowledgebase. This component supplements the existing BQCA workflow and must not replace its domain purpose or active-policy controls. Never degrade to generic Bob behavior.
<!-- BQCA-BOB-SHELL-V2-DNA:END -->
