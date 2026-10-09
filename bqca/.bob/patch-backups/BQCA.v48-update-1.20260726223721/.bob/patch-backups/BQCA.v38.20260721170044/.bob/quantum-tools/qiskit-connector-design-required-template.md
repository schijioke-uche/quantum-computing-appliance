# Quantum Solution Design

## Qiskit Connector Real-QPU-First Execution and Simulator Fallback

This section contains architecture and implementation instructions only. Do not place executable Python or a fenced Python code block in this design document.

The generated Qiskit implementation shall import `QConnectorV2` as `connector` and `QPlanV2` as `plan` from the `qiskit_connector` package. In the generated Python code, it shall initialize the account plan with `current = plan()` and initialize backend selection with `backend = connector()`.

The generated implementation shall resolve the user's IBM Quantum account plan, discover an account-accessible backend, and verify that the selected backend is a real QPU, is operational, and has sufficient qubit capacity for the workload. Its first execution attempt shall transpile and submit the workload to that real QPU.

The generated implementation shall use a `try/except` control path. Only when no usable QPU is available, or when real-QPU submission or result retrieval fails, may the `except` path execute with `AerSimulator`; `BasicSimulator` may be used as an optional secondary fallback. Simulator-first implementation is prohibited.

The generated implementation shall report an execution target of `REAL_QPU` only after successful real-backend job submission and result retrieval. When fallback is used, it shall report an execution target of `SIMULATOR`, together with the account plan, selected backend, and fallback reason.

### Required implementation sequence

1. Account-plan discovery with QPlanV2.
2. Backend discovery with QConnectorV2.
3. Real-QPU, operational-state, and qubit-capacity validation.
4. First attempt: real-QPU transpilation and execution.
5. On QPU unavailability or failure: try/except simulator fallback.
6. Execution-target, plan, backend, and fallback-reason reporting.
