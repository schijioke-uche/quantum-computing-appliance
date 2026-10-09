---
name: qiskit-connector
description: Enforces Qiskit Connector plan detection, real-QPU availability checks, connector-first execution, and immediate simulator fallback for every BQCA-generated Qiskit implementation.
---

# Qiskit Connector Skill

Use this skill whenever a user asks BQCA to create, write, generate, implement, repair, refactor, or execute Qiskit code.

## Mandatory workflow

<Steps>

<Step>
Confirm that generated code targets Qiskit SDK 2.x or later unless the user explicitly requests another supported target.
</Step>

<Step>
Ensure installation guidance includes `pip install qiskit-connector` when the package is not available. Never install packages silently unless the user requested installation.
</Step>

<Step>
Insert these exact imports into every generated Qiskit implementation:

```python
from qiskit_connector import QConnectorV2 as connector
from qiskit_connector import QPlanV2 as plan
```
</Step>

<Step>
Insert connector initialization into the guarded real-backend path:

```python
current = plan()
backend = connector()
```
</Step>

<Step>
Verify that `backend` is not `None`, is not a simulator, is operational when status information is available, and has at least the number of qubits required by the circuit.
</Step>

<Step>
If a usable QPU is available, transpile and attempt execution on that real backend using current Qiskit Runtime primitives. Record the plan, backend name, and job identifier when available.
</Step>

<Step>
If connector import, plan detection, authentication, backend selection, QPU availability, qubit capacity, transpilation, job submission, or result retrieval fails, immediately run the workload on a local simulator through a real `try/except` fallback path.
</Step>

<Step>
Prefer `qiskit_aer.AerSimulator`; use `qiskit.providers.basic_provider.BasicSimulator` when Aer is not installed and the workload is compatible.
</Step>

<Step>
Print a clear execution summary containing `REAL_QPU` or `SIMULATOR`, plan, backend/simulator, fallback reason when applicable, shots, and primary result values. Never report real-QPU success without a submitted job and retrieved result.
</Step>

<Step>
Save implementation artifacts under `bob-quantum-store/`, preserve design-only artifacts under `bob-quantum-designs/`, validate syntax, save required result/visualization files, and verify paths before reporting completion.
</Step>

</Steps>

## Required minimum code pattern

```python
try:
    from qiskit_connector import QConnectorV2 as connector
    from qiskit_connector import QPlanV2 as plan

    current = plan()
    backend = connector()
    # Validate backend operational state and qubit capacity here.
    # Attempt real-QPU execution only when validation succeeds.
except Exception as connector_error:
    # Immediately execute the same workload with a local simulator.
    print(f"Simulator fallback reason: {connector_error}")
```

The final generated implementation must contain complete validation and simulator execution logic; comments alone do not satisfy this skill.
