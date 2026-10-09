# BQCA Qiskit Connector Enforcement Rule — v32

## Highest-priority, non-negotiable rule

This rule applies whenever any BQCA mode creates, writes, generates, implements, repairs, refactors, converts, or executes Python code that imports Qiskit, `qiskit_algorithms`, `qiskit_ibm_runtime`, `qiskit_aer`, or any Qiskit provider.

A Qiskit implementation is **not complete**, **not valid**, and **must not be reported as created successfully** until the saved `.py` file passes:

```bash
.bob/quantum-tools/qiskit-connector.sh --validate-code <saved-python-file>
```

## Exact mandatory statements

Every generated Qiskit `.py` implementation must contain these exact imports:

```python
from qiskit_connector import QConnectorV2 as connector
from qiskit_connector import QPlanV2 as plan
```

It must execute these assignments in its real-backend decision path:

```python
current = plan()
backend = connector()
```

Imports or assignments placed only in comments, prose, Markdown, or an unused string do not satisfy the rule.

## Mandatory behavior

1. Attempt Qiskit Connector initialization first.
2. Verify that the returned backend represents a real, non-simulator QPU, is operational when status is available, and has enough qubits for the circuit.
3. When a usable QPU is available, transpile against that backend and submit using a current Qiskit Runtime primitive appropriate to the algorithm.
4. If connector import, credentials, account plan, backend discovery, QPU availability, capacity, transpilation, submission, or result retrieval fails, immediately execute the workload on a simulator through an executable `try/except` path.
5. Prefer `qiskit_aer.AerSimulator`; use `BasicSimulator` or an appropriate statevector primitive when required by the algorithm.
6. Print `EXECUTION_TARGET=REAL_QPU` only after successful QPU job submission and result retrieval.
7. Print `EXECUTION_TARGET=SIMULATOR` and a fallback reason when simulation is used.
8. Never hardcode tokens or credentials.
9. Never omit this connector-first path merely because the algorithm is VQE, QAOA, QPE, chemistry, optimization, sampling, estimation, visualization, educational, or research-oriented.
10. For VQE/estimator algorithms, the real-QPU branch must use a backend/runtime-compatible estimator path, while the simulator branch may use a local estimator. A simulator-only `Estimator()` implementation is non-compliant.

## Required completion gate

After saving or changing a Qiskit Python file, BQCA must run both:

```bash
python3 -m py_compile <saved-python-file>
.bob/quantum-tools/qiskit-connector.sh --validate-code <saved-python-file>
```

If either command fails, BQCA must repair the file and repeat both commands. BQCA must not claim success while validation fails.

Official package installation and import syntax:

```bash
pip install qiskit-connector
```

```python
from qiskit_connector import QConnectorV2 as connector
from qiskit_connector import QPlanV2 as plan
current = plan()
backend = connector()
```

Canonical implementation template:

```text
.bob/quantum-tools/qiskit-connector-required-template.py
```

Official reference: <https://pypi.org/project/qiskit-connector/>
