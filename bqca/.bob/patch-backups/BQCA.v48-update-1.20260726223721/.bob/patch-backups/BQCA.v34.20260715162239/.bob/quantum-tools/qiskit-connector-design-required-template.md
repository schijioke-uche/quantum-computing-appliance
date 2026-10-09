# Quantum Solution Design

## Qiskit Connector Real-QPU-First Execution and Simulator Fallback

The solution SHALL attempt execution on a real QPU before simulator execution. Simulator-first execution is prohibited.

```python
from qiskit_connector import QConnectorV2 as connector
from qiskit_connector import QPlanV2 as plan

current = plan()
backend = connector()
```

### Required execution decision

1. Resolve the user's quantum account plan with `QPlanV2`.
2. Discover the account-accessible backend with `QConnectorV2`.
3. Check that the backend is a real QPU, is operational/available, and has sufficient qubit capacity for the circuit.
4. In the first `try` path, transpile and submit the workload to that real QPU and retrieve the result.
5. If no usable QPU is available or real-QPU submission/result retrieval raises an exception, enter the `except` path and use `AerSimulator`; `BasicSimulator` may be used as a secondary fallback.
6. Report `EXECUTION_TARGET=REAL_QPU` for successful QPU execution or `EXECUTION_TARGET=SIMULATOR` for fallback, together with the account plan, selected backend, and fallback reason.

### Control flow

```text
User request -> QPlanV2 account-plan discovery -> QConnectorV2 backend discovery
             -> QPU operational + qubit-capacity validation
             -> TRY real-QPU execution first
             -> success: EXECUTION_TARGET=REAL_QPU
             -> EXCEPT/no usable QPU: AerSimulator/BasicSimulator
             -> EXECUTION_TARGET=SIMULATOR + fallback reason
```
