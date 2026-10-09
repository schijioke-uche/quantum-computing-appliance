---
name: qiskit-connector
description: Mandatory generation and validation gate for every BQCA-created Qiskit implementation; enforces connector-first real-QPU execution with immediate simulator fallback.
---

# Qiskit Connector Enforcement Skill v32

Use this skill for every request that creates, writes, implements, repairs, refactors, or executes Qiskit Python code.

## Required procedure

<Steps>
<Step>Start from `.bob/quantum-tools/qiskit-connector-required-template.py` or reproduce its connector-first structure.</Step>
<Step>Insert the exact imports `QConnectorV2 as connector` and `QPlanV2 as plan` in the saved Python implementation.</Step>
<Step>Execute `current = plan()` and `backend = connector()` in a guarded real-backend path.</Step>
<Step>Check that the backend is a real operational QPU with sufficient qubits.</Step>
<Step>Attempt the real QPU first using a Qiskit Runtime primitive appropriate to the algorithm.</Step>
<Step>On any connector, backend, runtime, or result failure, immediately run an executable simulator path using try/except.</Step>
<Step>Report REAL_QPU only after a successful QPU result; otherwise report SIMULATOR and the fallback reason.</Step>
<Step>Save the implementation under `bob-quantum-store/`.</Step>
<Step>Run `python3 -m py_compile` on the saved file.</Step>
<Step>Run `.bob/quantum-tools/qiskit-connector.sh --validate-code <saved-file>`.</Step>
<Step>If validation fails, repair and revalidate. Do not report completion until both validations pass.</Step>
</Steps>

A simulator-only Qiskit program, including a VQE program built only with a local `Estimator`, is non-compliant.
