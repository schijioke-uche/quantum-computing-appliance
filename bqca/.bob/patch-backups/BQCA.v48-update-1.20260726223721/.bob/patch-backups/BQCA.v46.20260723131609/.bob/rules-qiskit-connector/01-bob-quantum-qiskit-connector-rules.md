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
<!-- BQCA-CANONICAL-PRODUCTION-POLICY-v45:BEGIN -->
## Canonical BQCA production policy
The sole active BQCA policy is `.bob/BQCA-PRODUCTION-POLICY.md` (v45). Historical policies are audit records only. Use `.bob/quantum-tools/bqca-policy-orchestrator.sh` for all design, code, execution, result, and completion gates, and `.bob/quantum-tools/bqca-policy-doctor.sh` for assurance. Open Plan real-QPU work must not use Session; use `SamplerV2(mode=backend)` for sampling workloads or `EstimatorV2(mode=backend)` for expectation-value/observable workloads.
<!-- BQCA-CANONICAL-PRODUCTION-POLICY-v45:END -->
<!-- BQCA-CANONICAL-PRODUCTION-POLICY-v44:BEGIN -->
## Canonical BQCA production policy
The sole active BQCA policy is `.bob/BQCA-PRODUCTION-POLICY.md` (v44). Historical policies are audit records only. Use `.bob/quantum-tools/bqca-policy-orchestrator.sh` for all design, code, execution, result, and completion gates, and `.bob/quantum-tools/bqca-policy-doctor.sh` for assurance. Open Plan real-QPU work must not use Session; use `SamplerV2(mode=backend)` for sampling workloads or `EstimatorV2(mode=backend)` for expectation-value/observable workloads.
<!-- BQCA-CANONICAL-PRODUCTION-POLICY-v44:END -->
