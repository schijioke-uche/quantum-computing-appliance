# Bell Gate 4-Qubit Design

## Objective
Design a 4-qubit Bell-style entanglement workflow that prepares two Bell pairs on four qubits, measures all qubits for correlated outcomes, and defines a compliant execution and result-output contract for later implementation.

## Scope
This is a design-only artifact. It specifies the circuit structure, algorithm rationale, runtime routing, environment requirements, result-output requirements, risks, and validation expectations without generating executable Python code.

## Algorithm Selection and Rationale
This workflow uses a Bell-pair preparation pattern rather than a variational or search algorithm because the goal is deterministic entanglement demonstration, backend connectivity validation, and measurement-correlation verification on a small 4-qubit workload.

Rationale:
- Bell-pair preparation is the simplest reliable entanglement benchmark for a 4-qubit demonstration.
- Two Bell pairs allow pairwise correlation checks across four qubits without requiring deeper GHZ-style entanglement.
- The circuit is shallow, making it suitable for noisy real hardware and simulator comparison.
- The design is appropriate for Qiskit SDK 2.5 or later and IBM Quantum Runtime primitives.

## Target System
- **Workflow name:** Bell Gate 4-Qubit
- **Qubit count:** 4
- **Primary intent:** Demonstrate entanglement across four qubits as two Bell pairs
- **Primary platform:** Qiskit SDK 2.5 or later with IBM Quantum Runtime compatibility
- **Authorized home-scoped environment:** `~/qiskit-v2x-env`
- **Home environment activation command:** `source ~/qiskit-v2x-env/bin/activate`
- **Execution preference:** Real QPU first through Qiskit Connector, simulator fallback only if no suitable QPU is available or execution fails
- **Direct execution wrapper:** `.bob/quantum-tools/bqca-direct-execution.sh run bell-gate-4qubit.py`
- **Formal orchestrator opt-in only:** `.bob/quantum-tools/bqca-direct-execution.sh formal-run bell-gate-4qubit.py`

## Circuit Design
### Logical qubit allocation
- `q0`, `q1` form Bell Pair A
- `q2`, `q3` form Bell Pair B

### Gate sequence
1. Apply Hadamard gate to `q0`
2. Apply CNOT with control `q0` and target `q1`
3. Apply Hadamard gate to `q2`
4. Apply CNOT with control `q2` and target `q3`
5. Measure all four qubits into four classical bits

### Expected state structure
The circuit prepares the tensor product of two Bell states:

- Pair A approximates `( |00⟩ + |11⟩ ) / sqrt(2)`
- Pair B approximates `( |00⟩ + |11⟩ ) / sqrt(2)`

Combined 4-qubit measurement outcomes should concentrate around:
- `0000`
- `0011`
- `1100`
- `1111`

The exact ordering depends on bitstring conventions used by the execution stack.

## Measurement Expectations
### Ideal correlations
- `q0` should match `q1`
- `q2` should match `q3`

### Noise-aware expectations
On real hardware, readout noise and gate errors may introduce low-probability non-ideal bitstrings. The dominant counts should still preserve pairwise correlation patterns.

## Runtime and Backend Requirements
- Minimum usable backend size: 4 qubits
- Backend must be operational
- Backend selection should prefer a real IBM Quantum backend through Qiskit Connector
- For real QPU hardware, `backend.run()` is prohibited.
- `backend.run()` for real QPU hardware is forbidden.
- If no operational backend with at least 4 qubits is available, execution should fall back to `AerSimulator` in a controlled try/except path
- Simulator execution must transpile the circuit before running

## Qiskit Connector Real-QPU-First and Simulator-Fallback Section
For implementation derived from this design:
- Import `QConnectorV2 as connector` and `QPlanV2 as plan`
- Execute `current = plan()` and `backend = connector()`
- Verify backend operational state and qubit capacity before attempting real execution
- Attempt real-QPU execution first
- Use simulator fallback only after real-QPU unavailability or execution failure
- Emit execution markers for target, plan, backend, job ID, result, result value, and fallback reason where applicable

### Open Plan runtime rule
- Open Plan without Session is required for real-QPU job mode.
- Open Plan must not use Session.
- Open Plan uses `SamplerV2(mode=backend)` for sampler workflows.
- Open Plan uses `EstimatorV2(mode=backend)` for estimator workflows when the workflow type requires estimation.

### Paid Plan runtime rule
- Under paid plans, use a Runtime `Session(backend=backend)`
- Use the appropriate Runtime primitive inside the session, such as `SamplerV2(mode=session)` or `EstimatorV2(mode=session)`

### Execution mode rule
- Direct execution is the default development and testing path
- Formal orchestrator execution is explicit opt-in only and is not the default path for this workflow
- Policy gaps are warning-only and non-blocking in direct mode unless credential leakage occurs.

## Result-Output Contract
Any implementation derived from this design must produce durable terminal and file outputs.

### Required result files
- Authoritative result file: `<code-name>-result-output.txt`
- Authoritative result file path example: `bob-quantum-store/bell-gate-4qubit/bell-gate-4qubit-result-output.txt`
- Output mirror file: `output.txt`
- Additional durable summary file: `bob-quantum-store/bell-gate-4qubit/bell-gate-4qubit_results.txt`

### Required live output behavior
- Standard output and standard error must stream live to the terminal.
- Preserve complete live stdout/stderr during execution.
- Started timestamp, completed timestamp, duration, and exit status must be reported.
- JOB ID must be the first line for a final real-QPU result.
- End with a `RESULT SUMMARY` section.

### Required terminal summary fields
An implementation based on this design should print:
- Workflow name
- Qiskit version and relevant package versions when applicable
- Detected plan
- Selected backend
- Backend qubit count
- Circuit width and depth
- Shot count
- Measurement counts
- Execution target
- Job ID when applicable
- Final result summary with duration and exit status

## Suggested Visual Artifacts
If code is later requested, save these PNG artifacts under `bob-quantum-store/`:
- `bell-gate-4qubit_circuit.png`
- `bell-gate-4qubit_histogram.png`

## Risks and Limitations
- Real hardware noise can reduce ideal Bell-pair correlations.
- Backend queue time may delay completion on real QPU targets.
- Backend topology and calibration drift can affect measured fidelity.
- This design demonstrates entanglement structure, not fault-tolerant behavior.
- This design uses two Bell pairs rather than a single 4-qubit GHZ state.

## Validation Criteria
The design is considered successful when:
1. It clearly defines a 4-qubit Bell-style entanglement workflow
2. It remains design-only and contains no executable Python code
3. It includes a textual real-QPU-first and simulator-fallback section
4. It includes environment, runtime, and result-output requirements
5. It is saved under `bob-quantum-designs/bell-gate-4qubit/`

## Notes
If a single global 4-qubit entangled state is desired instead, that should be specified as a GHZ-state design request.