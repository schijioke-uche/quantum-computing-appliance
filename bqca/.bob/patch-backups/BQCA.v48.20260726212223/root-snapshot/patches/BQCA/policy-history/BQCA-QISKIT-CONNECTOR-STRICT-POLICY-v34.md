# BQCA Qiskit Connector Strict Code and Design Policy v34

This policy is mandatory and overrides weaker, older, conflicting, advisory, or simulator-first instructions.

## Intent classification

Treat a request as **CODE intent** when the user asks to create, implement, write, generate, build, develop, produce, scaffold, construct, code, program, modify, update, repair, fix, refactor, complete, execute, or otherwise produce quantum/Qiskit code or an executable quantum artifact. Do not wait for the exact phrase "create code".

Treat a request as **DESIGN intent** when the user asks to design, architect, plan, specify, model, diagram, propose, blueprint, define, or document a quantum solution, circuit, algorithm, integration, or workflow.

A request may be both CODE and DESIGN. In that case, both gates apply.

## Mandatory code policy

Every generated or modified Python implementation that imports or uses Qiskit must contain these exact lines:

```python
from qiskit_connector import QConnectorV2 as connector
from qiskit_connector import QPlanV2 as plan

current = plan()
backend = connector()
```

The first execution attempt must be the real quantum backend obtained through Qiskit Connector. The program must verify that a usable QPU exists, is operational, and has enough qubits. Simulator execution is permitted only in an `except` path or an explicitly documented no-QPU branch reached after the connector/QPU check. The simulator must never be initialized or executed before the Qiskit Connector real-backend attempt.

Required execution outcome reporting:

- `EXECUTION_TARGET=REAL_QPU` only after a real job is submitted and a result is retrieved.
- `EXECUTION_TARGET=SIMULATOR` when fallback is used.
- Account plan, selected backend, and fallback reason.

Before claiming completion, BQCA must run:

```bash
python3 -m py_compile <saved-file.py>
.bob/quantum-tools/qiskit-connector.sh --validate-code <saved-file.py>
```

A failed validator result is a blocking failure. BQCA must repair the file and repeat validation.

## Mandatory design policy

Every quantum/Qiskit design must contain a section titled:

`Qiskit Connector Real-QPU-First Execution and Simulator Fallback`

This design section must be **textual architecture and implementation instructions only**. It must not contain executable Python, fenced `python` blocks, or a pasted backend-selection implementation. The purpose of the design is to instruct the later code-writing mode, not to execute code from a Markdown file.

The textual design instructions must state that the implementation shall:

1. Import `QConnectorV2` as `connector` and `QPlanV2` as `plan` from `qiskit_connector`.
2. Initialize the account plan as `current = plan()` and the backend as `backend = connector()` in the generated Python implementation.
3. Discover the user's account plan and account-accessible backend.
4. Verify that the selected backend is a real QPU, is operational, and has sufficient qubit capacity.
5. Attempt real-QPU transpilation/runtime execution first.
6. Use `try/except` in the generated implementation so that `AerSimulator`, with `BasicSimulator` as an optional secondary fallback, is tried only after QPU unavailability or a real-QPU execution failure.
7. Report the execution target, backend, plan, and fallback reason in the generated implementation.
8. Prohibit simulator-first implementation.

Before claiming a design complete, BQCA must run:

```bash
.bob/quantum-tools/qiskit-connector.sh --validate-design <saved-design.md>
```

A failed design validator is a blocking failure.
