# Shor's Factoring Algorithm - Direct Execution Design

## Algorithm Overview

**Name:** Shor's Factoring Algorithm (Direct Execution Optimized)
**Category:** Fourier and Phase
**Primitive:** Sampler (SamplerV2)
**Status:** Design Reference
**Qiskit Version:** >= 2.5.0
**Qubit Requirements:** Problem-dependent (8-12 qubits for N=15)

## Purpose and Use Cases

Quantum integer factorization using period finding with QFT, optimized for direct execution workflow with live terminal streaming.

**Primary Use Cases:**
- Cryptanalysis research and RSA vulnerability analysis
- Period finding in modular arithmetic
- Quantum algorithm education and demonstration
- NISQ-era quantum computing exploration

## BQCA Qiskit 2.5+ Home Environment and Configuration

The implementation must use `$HOME/qiskit-v2x-env`, activated with `source $HOME/qiskit-v2x-env/bin/activate`. A project-local `qiskit-v2x-env` is prohibited. Qiskit package inspection, installation, upgrade, uninstall, validation, and execution occur only in the activated home environment. Qiskit 2.5 or later is required.

Before Qiskit Connector or backend work, the implementation must pass the BQCA configuration gate by running `.bob/quantum-tools/qiskit-configuration.sh configure --quiet` and requiring success. This atomically rebuilds `~/.qiskit/qiskit-ibm.json` with exactly one profile named `bqca` as the only default account.

## Qiskit Connector Integration

The implementation must include the exact Qiskit Connector imports: import QConnectorV2 as connector and QPlanV2 as plan from qiskit_connector package.

The code must execute current = plan() to detect the subscription plan and backend = connector() to initialize the IBM Quantum account and select the least-busy operational QPU with sufficient qubit capacity.

## Risks and Limitations

### Technical Limitations

1. **Qubit Requirements**: Shor's algorithm requires 2n+3 qubits for factoring an n-bit number. For N=15 (4 bits), this requires 8-12 qubits, which is at the edge of NISQ-era capabilities
2. **Circuit Depth**: The full Shor circuit has depth O(n³), resulting in 150-300 gates after transpilation. Deep circuits are highly susceptible to decoherence and gate errors
3. **Gate Fidelity**: Multi-qubit gates (especially CNOT) have error rates of 0.5-2%, compounding across the circuit depth
4. **Decoherence**: T1 and T2 times on current hardware (50-200 μs) limit circuit execution time, causing state decay during computation
5. **Measurement Error**: Readout errors (1-5%) can corrupt the measured phase, leading to incorrect period extraction
6. **Simplified Implementation**: Educational implementations use simplified modular exponentiation, sacrificing accuracy for NISQ compatibility

### Operational Risks

1. **Success Probability**: Even on ideal simulators, Shor's algorithm has ~40% success probability per run. Real hardware success rates are significantly lower (5-15%) due to noise
2. **Multiple Attempts Required**: Period finding typically requires 3-10 quantum circuit executions with different measurement outcomes
3. **Classical Post-Processing Complexity**: Continued fraction expansion and GCD computation can fail if measured phase is corrupted by noise
4. **Backend Availability**: Real QPU execution depends on backend operational status, queue times, and qubit connectivity constraints
5. **Calibration Sensitivity**: Algorithm performance varies significantly with backend calibration state and time-of-day effects
6. **Resource Consumption**: Multiple job submissions on paid plans can consume significant quantum time credits

### Algorithm-Specific Challenges

1. **Period Ambiguity**: Measured outcomes may correspond to multiples of the period, requiring additional classical verification
2. **Trivial Factors**: Some bases yield trivial factors (1 or N), requiring retry with different base selection
3. **Even Period Requirement**: Algorithm requires even period; odd periods provide no factorization information
4. **Phase Estimation Precision**: Limited qubit count in counting register reduces phase estimation precision, increasing failure probability
5. **Quantum Fourier Transform Errors**: QFT is sensitive to gate errors, particularly in the controlled rotation gates with small angles

### Mitigation Strategies

1. **Simplified Circuit Design**: Use SWAP-based permutation circuits instead of full quantum arithmetic to reduce gate count and depth
2. **Transpilation Optimization**: Apply optimization_level=1-2 to balance circuit depth reduction with compilation time
3. **Multiple Base Attempts**: Implement retry logic with different bases (a ∈ {2, 7, 8, 11, 13} for N=15) to increase overall success probability
4. **Simulator Validation**: Test classical post-processing logic on simulator before attempting real QPU execution
5. **Error Mitigation**: Consider readout error mitigation techniques available in Qiskit Runtime
6. **Controlled Fallback**: Implement graceful simulator fallback when real QPU is unavailable or returns corrupted results
7. **Result Validation**: Verify extracted factors multiply to N before reporting success

### Known Constraints

1. **Educational Scope**: This implementation is designed for demonstration and learning, not production cryptanalysis
2. **Limited Scalability**: Current NISQ hardware cannot factor cryptographically relevant numbers (>100 bits)
3. **Noise Dominance**: For N=15, quantum noise often dominates over quantum advantage; classical algorithms are faster and more reliable
4. **Connectivity Requirements**: Circuit may require additional SWAP gates on backends with limited qubit connectivity
5. **Shot Budget**: Adequate statistical sampling requires 1000-4000 shots per circuit execution
6. **Classical Overhead**: Post-processing time can exceed quantum execution time for small problem instances

### Success Expectations

- **Simulator**: 40-60% success rate per attempt, 3-5 attempts typically sufficient
- **Real QPU**: 5-15% success rate per attempt, 10-20 attempts may be required
- **Factors for N=15**: Should reliably find {3, 5} within reasonable attempt budget on simulator
- **Real Hardware**: May require error mitigation, multiple sessions, or fallback to simulator for reliable results

## Algorithm Implementation Strategy

### Simplified Modular Exponentiation

For N=15 demonstration, use simplified modular exponentiation circuit:
- Implement controlled multiplication by a mod N using SWAP-based permutations
- Avoid complex quantum arithmetic circuits for NISQ compatibility
- Focus on demonstrating period finding concept
- Accept reduced accuracy for educational value

### Quantum Period Finding Circuit

**Circuit Structure:**

1. **Register Initialization:**
   - Initialize n qubits for control (counting) register in state |0⟩
   - Initialize m qubits for target register to |1⟩

2. **Superposition Creation:**
   - Apply Hadamard gates to all control qubits to create uniform superposition

3. **Modular Exponentiation:**
   - Apply controlled modular exponentiation operations U^(2^j) for j=0 to n-1
   - Each operation is controlled by control qubit j

4. **Phase Extraction:**
   - Apply inverse Quantum Fourier Transform to the control register to extract phase information

5. **Measurement:**
   - Measure the control register in computational basis to obtain period-related outcomes

### Classical Post-Processing

**Period Extraction:**
1. Convert measured bitstring to decimal value s
2. Compute phase φ = s / 2^n
3. Apply continued fraction expansion to φ to find candidate periods
4. Test each convergent denominator as a potential period r
5. Verify period satisfies a^r ≡ 1 (mod N)

**Factor Computation:**
1. Check if period r is even
2. Compute x = a^(r/2) mod N
3. Verify x ≠ ±1 (mod N)
4. Calculate factors using gcd(x-1, N) and gcd(x+1, N)
5. Verify factors multiply to N

## Primitive Selection and Plan-Specific Execution

Shor's algorithm performs quantum measurement sampling to collect bitstring counts for period finding. The appropriate primitive is **SamplerV2** because the workload returns samples, shots, counts, and distributions rather than expectation values or observables.

### Open Plan real-QPU job mode

Open Plan must not use Session. For this sampling workload, use SamplerV2(mode=backend) without Session. For expectation-value workloads, use EstimatorV2(mode=backend) without Session. The mode=backend parameter enables job mode, which is the correct pattern for Open Plan real-QPU execution.

### Paid Plan real-QPU mode

For Flex, Pay-As-You-Go, Premium, Dedicated, or another paid plan, import Session and SamplerV2 from qiskit_ibm_runtime. Create a Session context manager with backend=backend parameter, then create the sampler inside the Session with mode=session parameter. This is the correct pattern for paid plan real-QPU execution and is particularly useful for Shor's algorithm which may require multiple job submissions for iterative period finding.

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
- `BQCA_JOB_ID=<actual-job-id>` for real-QPU results (must be line one of output)
- `BQCA_RESULT=SUCCESS` or `BQCA_RESULT=FAILURE`
- `BQCA_FALLBACK_REASON=<reason>` when simulator fallback occurs
- `BQCA_RESULT_VALUE=<factorization-result>` for scientific output

The Job ID must appear on the first line of stdout immediately after job submission for real QPU tracking. This is mandatory for real QPU execution.

## Direct Execution and Result-Output Contract

**Direct execution is the normal development method.** Execute via `.bob/quantum-tools/bqca-direct-execution.sh` for development, testing, exploration, debugging, and quick experiments. Use formal orchestrator execution only for production deployment, formal documentation evidence, or audit requirements.

### Execution Command

Execute with: .bob/quantum-tools/bqca-direct-execution.sh run /path/to/shor-factoring-direct.py

This command activates the home-scoped Qiskit environment at $HOME/qiskit-v2x-env, sets PYTHONUNBUFFERED=1 for unbuffered output, executes with python -u flag for real-time streaming, streams combined stdout and stderr live to the terminal, creates result output files with complete execution evidence, and preserves workload exit status.

### Execution behavior

1. **Live terminal output**: Combined stdout and stderr stream continuously to the terminal as the process produces it. Qiskit Connector, plan, backend, QPU, simulator, fallback, warning, error, progress, and result messages remain visible during execution.

2. **Authoritative result file**: The authoritative result filename is `<source-stem>-result-output.txt` (specifically `shor-factoring-direct-result-output.txt` for this implementation), produced in the same directory as the source, containing:
   - Complete combined stdout/stderr stream
   - Start and completion timestamps
   - Execution duration
   - Command and source path
   - Execution method (direct or formal)
   - Detected plan and backend
   - Execution target (REAL_QPU or SIMULATOR)
   - Job ID for real-QPU results (line one)
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

- **Design artifacts**: Route this textual design to `bob-quantum-designs/shor-factoring-direct/`
- **Implementation artifacts**: Route Python source (`shor-factoring-direct.py`), synchronized notebook (`shor-factoring-direct.ipynb`), result output (`shor-factoring-direct-result-output.txt` and `output.txt`), circuit diagrams, histogram plots, logs, and implementation documentation to `bob-quantum-store/shor-factoring-direct/`

Design and implementation artifacts remain separate and reviewable per BQCA v48 governed routing.

## Example Problem: Factor N=15

**Known Factors:** 3 × 5
**Qubits Required:** 8-12 (8 counting, 4 target)
**Candidate Bases:** a ∈ {2, 7, 8, 11, 13}
**Expected Periods:** r=4 for a∈{2,7,8,13}, r=2 for a=11
**Circuit Depth:** 150-300 gates (after transpilation)
**Success Probability:** ~40% per attempt on simulator, lower on real QPU due to noise

## Required Packages

**Core Dependencies:**
- qiskit >= 2.5.0 (Core Qiskit SDK)
- qiskit-ibm-runtime >= 0.30.0 (IBM Quantum Runtime client)
- qiskit-aer >= 0.15.0 (Aer simulator for fallback)
- qiskit-connector >= 2.4.6 (Mandatory: QPU selection and plan detection)

**Installation:**
All packages must be installed in home-scoped environment at `$HOME/qiskit-v2x-env/`.

## Success Criteria

- Circuit successfully implements Shor's period-finding algorithm
- Qiskit Connector integration with exact imports and initialization
- Real-QPU execution attempted first with proper plan detection
- Correct primitive selection (SamplerV2) for sampling workload
- Open Plan uses job mode without Session
- Paid Plan uses Session with mode=session
- Simulator fallback functions correctly with controlled try/except
- Classical post-processing extracts period and computes factors
- All required BQCA execution markers emitted
- Circuit diagram and result visualizations saved as PNG artifacts
- Terminal output provides complete execution summary with live visibility
- Authoritative result file and compatibility mirror created
- Real-QPU Job ID on line one when applicable
- Code passes `.bob/quantum-tools/qiskit-connector.sh --validate-code`

## Educational Value

This design demonstrates:
- Quantum period finding and integer factorization
- Quantum Fourier Transform application
- Classical-quantum hybrid algorithm design
- Real quantum hardware vs. simulation differences
- Production-ready quantum code patterns with Qiskit Connector v2
- BQCA v48 governed execution and result contracts
- Plan-aware primitive selection and execution patterns
- Cryptographic algorithm vulnerability analysis

## Next Steps for Implementation

When converting this design to executable code:
1. Configure IBM Quantum account using `.bob/quantum-tools/qiskit-configuration.sh configure --quiet`
2. Verify `$HOME/qiskit-v2x-env` activation
3. Import Qiskit Connector modules: `QConnectorV2 as connector` and `QPlanV2 as plan`
4. Execute `current = plan()` and `backend = connector()`
5. Implement plan-aware primitive selection (SamplerV2 for this sampling workload)
6. Implement simplified modular exponentiation circuit for N=15
7. Implement inverse QFT for phase extraction
8. Implement classical post-processing for period and factor extraction
9. Implement real-QPU-first execution with controlled simulator fallback
10. Emit all required BQCA execution markers
11. Generate and save visualization artifacts
12. Validate code with `.bob/quantum-tools/qiskit-connector.sh --validate-code`
13. Execute with `.bob/quantum-tools/bqca-direct-execution.sh run shor-factoring-direct.py`
14. Verify result files and compliance

## References

- BQCA Production Policy v48: `.bob/BQCA-PRODUCTION-POLICY.md`
- Qiskit Documentation: https://docs.quantum.ibm.com/
- Qiskit Connector: https://github.com/schijioke-uche/qiskit-connector
- Shor's Algorithm: Nielsen & Chuang, "Quantum Computation and Quantum Information"
- Period Finding: Shor, P. W. (1997). "Polynomial-Time Algorithms for Prime Factorization and Discrete Logarithms on a Quantum Computer"

---

**Design Status:** Complete
**Policy Version:** BQCA v48
**Validation Required:** Yes (use `.bob/quantum-tools/qiskit-connector.sh --validate-design`)
**Implementation Ready:** Yes (optimized for direct execution)
**Estimated Complexity:** Medium-High (educational demonstration with classical post-processing)