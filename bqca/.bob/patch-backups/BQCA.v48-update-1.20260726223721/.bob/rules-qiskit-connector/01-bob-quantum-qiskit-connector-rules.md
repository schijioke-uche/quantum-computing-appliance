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

<!-- BQCA-CANONICAL-PRODUCTION-POLICY-v48:BEGIN -->
## BQCA v48 cumulative production authority
Use `.bob/BQCA-PRODUCTION-POLICY.md` as the sole active BQCA v48 policy. Direct synchronous execution through `.bob/quantum-tools/bqca-direct-execution.sh` is the default for development, testing, exploration, debugging, and quick experiments; the formal orchestrator is explicit opt-in only for compliance, deployment, or audit evidence. Preserve Qiskit Connector configuration, `$HOME/qiskit-v2x-env`, Qiskit 2.5+, Open Plan SamplerV2/EstimatorV2 job mode without Session, Paid Plan Session with the suitable V2 primitive, real-QPU-first behavior, controlled simulator fallback, automatic synchronized notebooks, request-scoped Hello World, live terminal output, `<source-stem>-result-output.txt`, `output.txt`, Job-ID-first real-QPU reports, and credential-leak blocking. For quantum DESIGN and CODE requests consult `.bob/quantum-tools/bqca-quantum-kb.sh` and the offline v48 algorithm catalog. The catalog supplements IBM Bob intelligence and never overrides the central policy. v48 incorporates core v47 and Updates 1-6; Update 6 supersedes Update 5 URL crawling.
<!-- BQCA-CANONICAL-PRODUCTION-POLICY-v48:END -->
