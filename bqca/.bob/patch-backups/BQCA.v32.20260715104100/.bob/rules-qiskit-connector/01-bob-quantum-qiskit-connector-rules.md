# BQCA Qiskit Connector Rules — v31

## Authority and scope

This rule is mandatory for every BQCA mode that creates, writes, generates, implements, repairs, refactors, or executes Python/Qiskit code.

Official package reference: <https://pypi.org/project/qiskit-connector/>

The package is installed with:

```bash
pip install qiskit-connector
```

Qiskit Connector 2.2.3 and later use the class-based aliases below:

```python
from qiskit_connector import QConnectorV2 as connector
from qiskit_connector import QPlanV2 as plan

current = plan()
backend = connector()
```

## Strict connector-first execution policy

Every newly generated Qiskit implementation must contain an explicit connector-first execution path.

1. Import `QConnectorV2 as connector` and `QPlanV2 as plan`.
2. Resolve the current account plan with `current = plan()`.
3. Attempt to obtain a real IBM Quantum backend with `backend = connector()`.
4. Verify that the returned backend is non-null, operational, and exposes enough qubits for the generated circuit before treating it as QPU-capable.
5. When a usable QPU exists, transpile for that backend and execute using the appropriate Qiskit Runtime primitive.
6. If the connector package is unavailable, credentials are unavailable, the plan has no usable QPU, the backend is non-operational, the backend has too few qubits, or real-backend execution fails, immediately execute the same workload with a local simulator.
7. The simulator fallback must be implemented with `try/except`; it must not merely be described in comments.
8. Generated code must print whether execution used `REAL_QPU` or `SIMULATOR`, the plan when known, backend name, and the fallback reason when simulation is selected.
9. Never hardcode IBM Quantum tokens or secrets. Use `.env` or runtime environment variables.
10. Do not claim that a QPU execution occurred unless a real job was submitted and a result was retrieved.

## Required generated-code scaffold

Use this pattern or an equivalent implementation in every generated Qiskit program:

```python
from __future__ import annotations

from typing import Any

from qiskit import QuantumCircuit, transpile


def backend_name(backend: Any) -> str:
    name = getattr(backend, "name", None)
    return name() if callable(name) else str(name or "unknown")


def qpu_is_usable(backend: Any, required_qubits: int) -> bool:
    if backend is None:
        return False
    try:
        configuration = backend.configuration()
        if bool(getattr(configuration, "simulator", False)):
            return False
        if int(getattr(configuration, "n_qubits", 0)) < required_qubits:
            return False
    except Exception:
        if int(getattr(backend, "num_qubits", 0) or 0) < required_qubits:
            return False
    try:
        status = backend.status()
        if not bool(getattr(status, "operational", False)):
            return False
    except Exception:
        pass
    return True


def resolve_execution_target(required_qubits: int):
    try:
        from qiskit_connector import QConnectorV2 as connector
        from qiskit_connector import QPlanV2 as plan

        current = plan()
        backend = connector()
        if qpu_is_usable(backend, required_qubits):
            return "REAL_QPU", current, backend, None
        return "SIMULATOR", current, None, "No operational QPU is available for this circuit."
    except Exception as exc:
        return "SIMULATOR", "Unknown Plan", None, f"Qiskit Connector unavailable: {exc}"
```

The implementation must then attempt real execution only when `execution_target == "REAL_QPU"`; any real-execution exception must transfer control immediately to the simulator path.

## Qiskit Connector installation and initialization sample

```bash
pip install qiskit-connector
```

```python
# After Qiskit Connector® pip install, import Qiskit Connector®:
from qiskit_connector import QConnectorV2 as connector
from qiskit_connector import QPlanV2 as plan

# Initialize Qiskit Connector®:
current = plan()
backend = connector()
```

## Qiskit 2.x real-backend sample

```python
from qiskit import QuantumCircuit, transpile
from qiskit_ibm_runtime import SamplerV2 as Sampler, Session


def base_circuit():
    qc = QuantumCircuit(2, 2)
    for q in range(2):
        qc.h(q)
        qc.rx(0.5, q)
        qc.rz(1.0, q)
        qc.s(q)
        qc.t(q)
        qc.h(q)
    qc.cx(0, 1)
    qc.measure([0, 1], [0, 1])
    return qc


def randomize_circuit(base_qc, p):
    qc = QuantumCircuit(2, 2)
    # Insert the required randomized Pauli-twirling implementation here.
    return qc


rand_range = 5
p = 0.1
qc = base_circuit()
circuits = [randomize_circuit(qc, p) for _ in range(rand_range)]
qc_t = [transpile(c, backend=backend, optimization_level=3) for c in circuits]

if current == "Open Plan":
    sampler = Sampler(mode=backend)
    job = sampler.run(qc_t, shots=1)
elif current == "Paid Plan":
    with Session(backend=backend) as session:
        sampler = Sampler(mode=session)
        job = sampler.run(qc_t, shots=1)
else:
    sampler = Sampler(mode=backend)
    job = sampler.run(qc_t, shots=1)
```

The abbreviated `randomize_circuit` body above is documentation only. BQCA-generated production code must implement the requested algorithm completely and must not leave placeholder comments in executable paths.

## Simulator fallback standard

Prefer `qiskit_aer.AerSimulator` when available. If Aer is unavailable, use a compatible local Qiskit simulator supported by the installed environment. The fallback must preserve the circuit intent, shot count, result reporting, and visualization/artifact policies.

```python
try:
    from qiskit_aer import AerSimulator

    simulator = AerSimulator()
except ImportError:
    from qiskit.providers.basic_provider import BasicSimulator

    simulator = BasicSimulator()
```

## Output and governance requirements

- Save implementation code under `bob-quantum-store/<normalized-name>/`.
- Keep design-only Markdown under `bob-quantum-designs/<normalized-name>/`.
- Print plan, execution target, backend/simulator name, job identifier when available, and result summary.
- Save useful circuit/result visualizations and durable result files.
- Validate Python syntax before reporting completion.
- Ask for confirmation before knowingly submitting a paid or quota-consuming workload when the user has not already explicitly requested real-QPU execution.
