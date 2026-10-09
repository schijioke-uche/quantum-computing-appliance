# BQCA Qiskit Connector Mandatory Rule v34

This rule is strict, blocking, and appliance-wide. It overrides simulator-first, optional-connector, advisory, or weaker instructions.

## Default code intent

Any request using terms such as create, implement, write, generate, build, develop, produce, scaffold, construct, code, program, modify, update, repair, fix, refactor, complete, or execute is a code-producing request when the object is a quantum/Qiskit workload or artifact.

For every such Python/Qiskit file, include exactly:

```python
from qiskit_connector import QConnectorV2 as connector
from qiskit_connector import QPlanV2 as plan

current = plan()
backend = connector()
```

The first attempt MUST be real-QPU execution using the connector backend. Verify QPU availability, operational state, and qubit capacity. Only after no usable QPU is available or real execution fails may an `except` path execute `AerSimulator` or `BasicSimulator`. Simulator-first code is forbidden.

Completion is blocked until:

```bash
python3 -m py_compile <saved-file.py>
.bob/quantum-tools/qiskit-connector.sh --validate-code <saved-file.py>
```

## Default design intent

Any request using design, architect, plan, specify, model, diagram, propose, blueprint, define, or document for a quantum solution must include the section `Qiskit Connector Real-QPU-First Execution and Simulator Fallback`. The section must be textual instructions only—no executable Python and no fenced Python block. It must instruct the later code-writing mode to include the connector imports and initialization, QPU availability/capacity checks, real-QPU-first flow, try/except simulator fallback, and execution reporting.

Completion is blocked until:

```bash
.bob/quantum-tools/qiskit-connector.sh --validate-design <saved-design.md>
```

<!-- BQCA-CANONICAL-PRODUCTION-POLICY-v47:BEGIN -->
## BQCA v47 Update 4 superseding execution authority
Follow `.bob/BQCA-PRODUCTION-POLICY.md`. Direct execution through `.bob/quantum-tools/bqca-direct-execution.sh` is the default for development, testing, interactive exploration, debugging, and quick experiments. It uses `$HOME/qiskit-v2x-env/bin/python` with `PYTHONUNBUFFERED=1` and `python -u`, streams combined stdout/stderr live, and creates `<source-stem>-result-output.txt` plus `output.txt` beside the source. Quantum code must attempt a real QPU first, apply the Open/Paid Plan V2 primitive rules, use controlled `transpile` plus `AerSimulator` fallback, and emit `BQCA_EXECUTION_TARGET`, `BQCA_PLAN`, `BQCA_BACKEND`, `BQCA_JOB_ID`, `BQCA_RESULT=SUCCESS` or `BQCA_RESULT=FAILURE`, and `BQCA_FALLBACK_REASON` for fallback. The orchestrator is explicit opt-in only for formal compliance, production deployment, or audit evidence. Direct-mode policy gaps are warnings that preserve the workload exit status; credential leakage is blocking. This block supersedes conflicting local execution guidance.
<!-- BQCA-CANONICAL-PRODUCTION-POLICY-v47:END -->

<!-- BQCA-LOCAL-ALGORITHM-KNOWLEDGEBASE-v47-update-6:BEGIN -->
## BQCA local quantum algorithm knowledgebase — v47 Update 6
For every quantum **DESIGN** or **CODE** intent, consult `.bob/quantum-tools/bqca-quantum-kb.sh` and the offline catalog at `.bob/quantum-tools/knowlegebase/bqca_quantum_algorithm_catalog.json`. Use its algorithm cards and Qiskit 2.5+ starter scaffolds to select the appropriate SamplerV2 or EstimatorV2 pattern, Open Plan job-mode branch without Session, Paid Plan Session branch, and controlled simulator fallback. Update 6 supersedes Update 5 URL seed/sublink crawling; network access and a mandatory research-trace artifact are not required. The local catalog supplements IBM Bob intelligence and approved sources but never overrides the active central policy. If no local entry fits, continue with approved research rather than blocking the request.
<!-- BQCA-LOCAL-ALGORITHM-KNOWLEDGEBASE-v47-update-6:END -->
