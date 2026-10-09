# Hello World 2-Qubit Quantum Circuit Design

## Overview
A foundational quantum computing demonstration using a 2-qubit system to showcase quantum superposition, entanglement, and measurement. This design serves as an introduction to quantum circuit construction and execution patterns.

**Request Scope Notice**: This Hello World design is request-scoped per BQCA v48 policy. Hello World content, tests, commands, artifacts, or dependencies must not be added to unrelated designs or code.

## Design Objectives
- Demonstrate basic quantum gate operations on 2 qubits
- Create quantum superposition using Hadamard gates
- Establish quantum entanglement using CNOT gate
- Measure quantum states and observe probability distributions
- Provide clear visualization of circuit structure and results

## Algorithm Selection and Rationale

This design uses a **Bell State preparation circuit**, which is the foundational quantum algorithm for demonstrating entanglement. The algorithm was selected for the following reasons:

1. **Educational Foundation**: Bell states are the simplest demonstration of quantum entanglement, making them ideal for learning quantum computing fundamentals
2. **Minimal Qubit Requirements**: Requires only 2 qubits, making it accessible on all IBM Quantum backends
3. **Clear Observable Outcomes**: The 50/50 probability distribution between |00⟩ and |11⟩ states provides unambiguous verification of quantum behavior
4. **Building Block for Advanced Algorithms**: Bell state preparation is a subroutine in quantum teleportation, superdense coding, and quantum error correction
5. **Hardware Validation**: Serves as a basic connectivity and fidelity test for quantum hardware

The Hadamard + CNOT gate sequence is the canonical implementation for creating maximally entangled states, widely documented in quantum computing literature and used as a standard benchmark.

## Risks and Limitations

### Technical Limitations
1. **Decoherence**: Real quantum hardware experiences decoherence, causing the measured distribution to deviate from the ideal 50/50 split
2. **Gate Fidelity**: Imperfect gate operations introduce errors, particularly in the CNOT gate which typically has lower fidelity than single-qubit gates
3. **Measurement Error**: Readout errors can cause misclassification of quantum states, affecting result accuracy
4. **Qubit Connectivity**: Some backends may require additional SWAP gates if qubits 0 and 1 are not directly connected, increasing circuit depth and error rates

### Operational Risks
1. **Backend Availability**: Real QPU execution depends on backend operational status and queue times
2. **Calibration Drift**: Backend performance varies with calibration cycles; results may differ between executions
3. **Shot Noise**: Statistical sampling with 1024 shots introduces ~3% standard error in probability estimates
4. **Simulator Limitations**: Fallback to AerSimulator provides ideal results without hardware noise, which may not reflect real-world quantum behavior

### Mitigation Strategies
1. Use Qiskit Connector to automatically select the least-busy, operational backend with best availability
2. Implement controlled simulator fallback for development and testing when real hardware is unavailable
3. Apply transpilation with optimization_level=1 to minimize circuit depth while preserving fidelity
4. Emit clear execution markers (BQCA_EXECUTION_TARGET) to distinguish real-QPU from simulator results
5. Document expected vs. observed distributions to account for hardware noise
6. Use sufficient shot count (1024) to reduce statistical uncertainty

### Known Constraints
- This is a demonstration circuit, not a production algorithm for solving computational problems
- Results are probabilistic and require multiple shots for statistical significance
- Hardware noise will cause deviations from theoretical predictions
- Circuit assumes basic 2-qubit connectivity; additional gates may be required on some topologies

## Circuit Architecture

### Qubit Configuration
- **Qubit 0**: Control qubit for entanglement
- **Qubit 1**: Target qubit for entanglement
- **Classical Bits**: 2 bits for measurement storage

### Gate Sequence
1. **Hadamard Gate (H) on Qubit 0**: Creates equal superposition |0⟩ + |1⟩
2. **CNOT Gate (CX)**: Entangles Qubit 0 (control) with Qubit 1 (target)
3. **Measurement**: Collapses quantum state to classical bits

### Expected Quantum States
- Initial state: |00⟩
- After H gate: (|00⟩ + |10⟩) / √2
- After CNOT: (|00⟩ + |11⟩) / √2 (Bell state)
- Measurement outcomes: 50% probability of |00⟩, 50% probability of |11⟩

## BQCA Qiskit 2.5+ Home Environment and Configuration

The implementation must use `$HOME/qiskit-v2x-env`, activated with `source $HOME/qiskit-v2x-env/bin/activate`. A project-local `qiskit-v2x-env` is prohibited. Qiskit package inspection, installation, upgrade, uninstall, validation, and execution occur only in the activated home environment. Qiskit 2.5 or later is required.

Before Qiskit Connector or backend work, the implementation must pass the BQCA configuration gate by running `.bob/quantum-tools/qiskit-configuration.sh configure --quiet` and requiring success. This atomically rebuilds `~/.qiskit/qiskit-ibm.json` with exactly one profile named `bqca` as the only default account.

## Qiskit Connector Integration

The implementation must include the exact Qiskit Connector imports: import QConnectorV2 as connector and QPlanV2 as plan from qiskit_connector package.

The code must execute current = plan() to detect the subscription plan and backend = connector() to initialize the IBM Quantum account and select the least-busy operational QPU with sufficient qubit capacity.

## Primitive Selection and Plan-Specific Execution

This Hello World workload performs quantum measurement sampling to collect bitstring counts and probability distributions. The appropriate primitive is **SamplerV2** because the workload returns samples, shots, counts, and distributions rather than expectation values or observables.

For workloads requiring expectation values, observables, energies, or Hamiltonians, the appropriate primitive would be **EstimatorV2** instead.

### Open Plan real-QPU job mode

Open Plan must not use Session. For this sampling workload, use SamplerV2(mode=backend) without Session. For expectation-value workloads, use EstimatorV2(mode=backend) without Session. The mode=backend parameter enables job mode, which is the correct pattern for Open Plan real-QPU execution.

### Paid Plan real-QPU mode

For Flex, Pay-As-You-Go, Premium, Dedicated, or another paid plan, the implementation must import Session and SamplerV2 from qiskit_ibm_runtime. Create a Session context manager with backend=backend parameter, then create the sampler inside the Session with mode=session parameter. This is the correct pattern for paid plan real-QPU execution.

### Real-QPU-first and controlled simulator fallback

The implementation must:
1. Verify backend operational status and qubit capacity
2. Attempt eligible real-QPU execution first using the plan-appropriate primitive pattern
3. Use a controlled `try/except` path for simulator fallback
4. Apply `transpile` to the circuit before simulator execution
5. Use `AerSimulator` or another supported local simulator for fallback
6. **Real-QPU backend.run() prohibition**: Using backend.run() for real QPU hardware is prohibited; always use Runtime V2 primitives (SamplerV2 or EstimatorV2)
7. Permit `backend.run()` only for clearly local simulators

## Required Execution Markers

Every execution must emit the following markers to terminal output and result files:

- `BQCA_EXECUTION_TARGET=REAL_QPU` or `BQCA_EXECUTION_TARGET=SIMULATOR`
- `BQCA_PLAN=<detected-plan>` (e.g., Open, Flex, Premium)
- `BQCA_BACKEND=<backend-name>` (e.g., ibm_brisbane, AerSimulator)
- `BQCA_JOB_ID=<actual-job-id>` for real-QPU results
- `BQCA_RESULT=SUCCESS` or `BQCA_RESULT=FAILURE`
- `BQCA_FALLBACK_REASON=<reason>` when simulator fallback occurs

Scientific result values may be emitted separately as `BQCA_RESULT_VALUE=<value>` but must not replace the required SUCCESS/FAILURE execution-status marker.

## Direct Execution and Result-Output Contract

**Direct execution is the normal development method.** Execute via `.bob/quantum-tools/bqca-direct-execution.sh` for development, testing, exploration, debugging, and quick experiments. Use formal orchestrator execution only for production deployment, formal documentation evidence, or audit requirements.

### Execution behavior

1. **Live terminal output**: Combined stdout and stderr stream continuously to the terminal as the process produces it. Qiskit Connector, plan, backend, QPU, simulator, fallback, warning, error, progress, and result messages remain visible during execution.

2. **Authoritative result file**: The authoritative result filename is `<source-stem>-result-output.txt` (specifically `hello-world-2qubit-result-output.txt` for this implementation), produced in the same directory as the source, containing:
   - Complete combined stdout/stderr stream
   - Start and completion timestamps
   - Execution duration
   - Command and source path
   - Execution method (direct or formal)
   - Detected plan and backend
   - Execution target (REAL_QPU or SIMULATOR)
   - Job ID for real-QPU results
   - Fallback reason if applicable
   - Process exit status
   - Notebook synchronization status
   - Contract compliance status
   - Bottom `RESULT SUMMARY` stating success or failure

3. **Compatibility mirror**: The same finalized report is also written to `output.txt` in the source directory.

4. **Real-QPU Job ID**: For real-QPU execution, the actual Job ID must appear on line one of both result files.

5. **Direct-mode policy gaps**: Warnings only; preserve the workload process exit status. Do not turn a successful process into an artificial failure.

6. **Credential leakage**: Blocking. Captured output containing secrets must not be published.

## Artifact Routing

- **Design artifacts**: Route this textual design to `bob-quantum-designs/hello-world-2qubit/`
- **Implementation artifacts**: Route Python source (`hello-world-2qubit.py`), synchronized notebook (`hello-world-2qubit.ipynb`), result output (`hello-world-2qubit-result-output.txt` and `output.txt`), circuit diagrams, histogram plots, logs, and implementation documentation to `bob-quantum-store/hello-world-2qubit/`

Design and implementation artifacts remain separate and reviewable per BQCA v48 governed routing.

## Implementation Specifications

### Circuit Construction
- Create QuantumCircuit with 2 qubits and 2 classical bits
- Apply Hadamard gate h to qubit 0
- Apply CNOT gate cx with qubit 0 as control and qubit 1 as target
- Apply measure operation to both qubits, storing results in classical bits

### Execution Parameters
- **Shots**: 1024 (standard for statistical sampling)
- **Optimization Level**: 1 (balance between speed and fidelity)
- **Transpilation**: Required for real hardware execution
- **Python Execution**: Use PYTHONUNBUFFERED=1 environment variable and python -u flag for unbuffered real-time output
- **Backend Prohibition**: Never use backend.run() for real QPU hardware; always use Runtime V2 primitives (SamplerV2 or EstimatorV2)
- **Direct Execution**: Direct execution via bqca-direct-execution.sh is the normal development method; formal orchestrator is explicit opt-in only

### Output Requirements

1. **Terminal Output**:
   - Workflow name and description
   - Python and Qiskit version information
   - Detected plan (Open, Flex, Premium, etc.)
   - Backend name (QPU or simulator)
   - Execution target (REAL_QPU or SIMULATOR)
   - Shot count
   - Circuit depth and gate count
   - Measurement counts dictionary
   - All required BQCA execution markers
   - Execution status summary

2. **Visualization Artifacts** (saved to `bob-quantum-store/hello-world-2qubit/`):
   - Circuit diagram: `hello-world-2qubit_circuit.png`
   - Measurement histogram: `hello-world-2qubit_histogram.png`
   - Use Matplotlib with `Agg` backend for headless rendering
   - Print artifact paths to terminal

### Error Handling
- Validate IBM Quantum authentication before execution
- Verify backend operational status and qubit capacity
- Handle QPU unavailability gracefully with controlled simulator fallback
- Catch and report transpilation errors
- Validate measurement results before visualization
- Emit appropriate BQCA_FALLBACK_REASON when simulator is used

## Success Criteria
- Circuit successfully constructs 2-qubit Bell state
- Qiskit Connector integration with exact imports and initialization
- Real-QPU execution attempted first with proper plan detection
- Correct primitive selection (SamplerV2) for sampling workload
- Open Plan uses job mode without Session
- Paid Plan uses Session with mode=session
- Simulator fallback functions correctly with controlled try/except
- Measurement results show ~50/50 distribution between |00⟩ and |11⟩
- All required BQCA execution markers emitted
- Circuit diagram and histogram saved as PNG artifacts
- Terminal output provides complete execution summary with live visibility
- Authoritative result file and compatibility mirror created
- Real-QPU Job ID on line one when applicable
- All paths print saved artifact locations
- Code passes `.bob/quantum-tools/qiskit-connector.sh --validate-code`

## Educational Value
This design demonstrates:
- Quantum superposition principle
- Quantum entanglement creation
- Bell state preparation
- Measurement collapse behavior
- Real quantum hardware vs. simulation differences
- Production-ready quantum code patterns with Qiskit Connector v2
- BQCA v48 governed execution and result contracts
- Plan-aware primitive selection and execution patterns

## Next Steps for Implementation
When converting this design to executable code:
1. Configure IBM Quantum account using `.bob/quantum-tools/qiskit-configuration.sh configure --quiet`
2. Verify `$HOME/qiskit-v2x-env` activation
3. Import Qiskit Connector modules: `QConnectorV2 as connector` and `QPlanV2 as plan`
4. Execute `current = plan()` and `backend = connector()`
5. Implement plan-aware primitive selection (SamplerV2 for this sampling workload)
6. Implement real-QPU-first execution with controlled simulator fallback
7. Emit all required BQCA execution markers
8. Generate and save visualization artifacts
9. Validate code with `.bob/quantum-tools/qiskit-connector.sh --validate-code`
10. Execute with `.bob/quantum-tools/bqca-direct-execution.sh run hello-world-2qubit.py`
11. Verify result files and compliance

## References
- BQCA Production Policy v48: `.bob/BQCA-PRODUCTION-POLICY.md`
- Qiskit Documentation: https://docs.quantum.ibm.com/
- Qiskit Connector: https://github.com/schijioke-uche/qiskit-connector
- Bell State Theory: Nielsen & Chuang, "Quantum Computation and Quantum Information"
