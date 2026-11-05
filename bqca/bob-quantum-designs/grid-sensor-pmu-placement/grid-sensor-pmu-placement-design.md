# Grid Sensor (PMU) Placement Design

## Problem and algorithm

**Energy-industry problem.** A Phasor Measurement Unit (PMU) is a grid sensor that measures voltage and current phasors with GPS-synchronized timestamps. Utilities cannot afford a PMU on every bus, so they ask: what is the fewest number of PMUs that still lets the operator observe the whole grid?

**Observability rule used.** A PMU installed on a bus observes that bus and every bus directly connected to it by a line or transformer. The grid is fully observable when every bus is observed by at least one PMU. The minimum PMU set under this rule is the minimum dominating set of the network graph, which is NP-hard in general.

**Selected quantum algorithm.** QAOA (Quantum Approximate Optimization Algorithm), depth p = 1, applied to a QUBO encoding of the minimum dominating set. QAOA is chosen because the problem is a binary selection problem with a cost function that maps directly to an Ising Hamiltonian, the circuit is shallow enough for a 156-qubit Heron device, and the answer can be verified exactly by brute force at this size.

**Demonstration instance.** The standard WSCC 9-bus test system:

- Nine buses, numbered 1 to 9.
- Nine branches: 1-4, 2-7, 3-9, 4-5, 4-6, 5-7, 6-9, 7-8, 8-9.
- Buses 1, 2, 3 carry generators. Buses 5, 6, 8 carry loads. Buses 4, 7, 9 are transformer or junction buses.
- One qubit per bus. A qubit measured as 1 means a PMU is installed on that bus.

**Scientific assumptions and simplifications.**

- Zero-injection buses are not exploited to reduce the PMU count.
- No PMU channel limits, no line-outage (N-1) redundancy, and no per-bus installation cost differences.
- The instance is small on purpose, so this is a workflow demonstration on real hardware, not a quantum advantage claim.

## QUBO and cost function

- Decision variable x_i equals 1 when bus i receives a PMU.
- The cost is the PMU count plus a penalty for every unobserved bus.
- The penalty for bus i applies when no bus in its closed neighborhood (itself plus its neighbors) holds a PMU.
- The penalty weight is 2.0. Because adding one PMU costs 1 and can repair at least one unobserved bus worth 2, an unobserved bus never lowers the total cost.
- Expected exact optimum (to be recomputed by brute force at run time): 3 PMUs, with four equivalent optimal placements, out of 512 candidate bit patterns of which 185 are fully observable.

## Circuit strategy

- Nine qubits, one per bus. Initial layer of Hadamard gates.
- Cost layer: the penalty expands into Pauli-Z product terms of weight up to four. The implementation should derive these terms automatically from the cost table with a fast Walsh-Hadamard transform, then apply each term as a parity-computing CNOT ladder, a single Z rotation, and the uncompute ladder.
- Mixer layer: one X rotation on every qubit.
- Measure all nine qubits.
- QAOA angles (gamma, beta) are tuned classically on an exact 512-amplitude state vector before submission, using a coarse grid followed by a Nelder-Mead refinement. The QPU is used to sample the circuit, not to train it, and the output must say so.
- Let the transpiler choose the physical layout with optimization level 3 and a fixed seed. Expected transpiled size on a Heron-class device from pre-implementation modeling: about 150 two-qubit gates and depth about 320. These are estimates, and the run must report the actual numbers.

## Post-processing and success criteria

- Convert each measured bitstring to a PMU placement. Bit i of the integer value of the bitstring is the qubit for bus i, matching the Qiskit convention that qubit 0 is the rightmost character.
- Evaluate every sampled placement for observability and PMU count.
- Report the best fully observable placement, ranked by PMU count and then by sample count.
- Report the share of shots that landed on an optimal placement and on any fully observable placement, each compared with the uniform-random baseline.
- Pre-implementation modeling expectations: ideal simulation puts about 4.3 percent of shots on an optimal placement (about 5.5 times uniform). An `ibm_fez` noise-model simulation puts about 2.9 percent (about 3.7 times uniform), with about 56 percent of shots fully observable against 36 percent for uniform random guessing. Real-hardware figures will differ.
- **SUCCESS** requires all of the following: the best sampled observable placement uses the exact brute-force minimum number of PMUs, the placement is independently verified as observing every bus, and the optimal-placement probability is at least 1.5 times the uniform baseline.
- If the real-QPU result does not meet these criteria, treat it as a real-QPU outcome that failed the check and use the controlled simulator fallback, recording the reason.

## Qiskit 2.5+ home environment and account configuration

The implementation must use `$HOME/qiskit-v2x-env`, activated with `source $HOME/qiskit-v2x-env/bin/activate`. Qiskit 2.5 or later is required. Before Qiskit Connector or backend work, the implementation must pass the BQCA configuration gate and use the single default `bqca` profile. SciPy and NumPy are available in that environment and may be used for the classical angle tuning.

## Qiskit Connector Real-QPU-First Execution and Simulator Fallback

These are instructions for the later code-generation step. This design contains no executable code.

- The generated Python file must contain exactly the import of `QConnectorV2` as `connector` and the import of `QPlanV2` as `plan` from `qiskit_connector`, and must initialize `current = plan()` and `backend = connector()` inside the guarded real-QPU path.
- Check QPU availability: reject a backend that reports itself as a simulator, reject a backend that is not operational, and reject a backend whose qubit count is below the nine qubits the circuit needs.
- Real-QPU-first flow: the first execution attempt always goes to the connector-selected real QPU. Transpile the circuit for that backend, then sample it with the Runtime Sampler primitive.
- Open Plan must not use Session. Open Plan uses SamplerV2(mode=backend) for this workload, because it returns bitstring counts. EstimatorV2(mode=backend) is the Open Plan option for expectation-value workloads and is not needed here.
- Paid Plan (Flex, Pay-As-You-Go, Premium, or Dedicated) opens a Session on the backend and uses the Sampler as SamplerV2(mode=session). An Estimator workload would use EstimatorV2(mode=session).
- `backend.run()` for real QPU hardware is prohibited. It is permitted only for a clearly local simulator.
- Wrap the real-QPU attempt, and the post-processing check of its result, in a try/except block. On any connector, plan, credential, backend, capacity, transpilation, submission, result, or success-criteria failure, the except block must transpile the same circuit for a local AerSimulator, run it there, and record the fallback reason.
- Simulator-first or simulator-only implementation is prohibited.
- Execution reporting: print and record the execution target (REAL_QPU or SIMULATOR), account plan, backend name, actual job ID for a real-QPU run, and the fallback reason. Never claim QPU execution unless a job was submitted and a result was retrieved.

## Direct execution and result contract

Development, testing, interactive exploration, and demonstrations use `.bob/quantum-tools/bqca-direct-execution.sh`. Formal compliance, production deployment, or audit evidence may explicitly use the formal orchestrator through the formal-run mode. The orchestrator is opt-in only and is not the default path.

The direct executor uses `$HOME/qiskit-v2x-env/bin/python` with unbuffered output. It streams combined stdout and stderr live to the terminal and captures the same stream in `<source-stem>-result-output.txt` plus the same-directory `output.txt` mirror.

Both files record the started and completed timestamps, the duration, and the exit status, together with the plan, backend, target, job ID, fallback reason, notebook status, and a bottom RESULT SUMMARY. For a real-QPU result, the JOB ID is the first line of both files.

The code must emit these contract markers when its output is captured: BQCA_EXECUTION_TARGET, BQCA_PLAN, BQCA_BACKEND, BQCA_JOB_ID for a real QPU, BQCA_RESULT with SUCCESS or FAILURE, BQCA_RESULT_VALUE, and BQCA_FALLBACK_REASON. Policy gaps and missing markers in direct mode are reported as a warning and are non-blocking, and they preserve the workload exit status. Credential or secret leakage is blocking.

When the script runs on an interactive terminal it must hand itself off to the direct executor so that the result files are still produced, and the markers must not clutter the screen.

## Terminal presentation requirements

The script must be runnable directly from a terminal in the same way as the earlier Shor demonstration, and the screen output must be colorful and well organized.

- Color: use ANSI colors with a consistent palette. Color is enabled on an interactive terminal and on a terminal hand-off, and is disabled when the NO_COLOR environment variable is set or when output is captured by a pipe or file without a hand-off. Plain-text output must be fully readable without color.
- Result files: the result-output file and the output mirror must be free of ANSI escape codes. The direct executor should strip them when it publishes the files.
- Screen order: a banner; the grid description table; a problem-to-QUBO explanation table; circuit statistics; the Qiskit Connector progress; a ranked table of the most-sampled placements with bar charts and an observability mark; a bus-by-bus coverage table for the best placement; the dated RESULT SUMMARY table; then, at the bottom, the EXPERIMENT INFERENCE block and a NOTES list.
- Summary table rows: execution target, plan, backend, job ID, fallback reason, grid, qubits, transpiled depth and two-qubit gate count, shots, QAOA angles, best placement found, PMUs used against the exact minimum, observability check, optimal-placement probability against the uniform baseline with the enrichment factor, fully-observable share against its baseline, and the final result.
- The EXPERIMENT INFERENCE must be detailed. It must state in plain language what was run, what the numbers show, why the result can or cannot be trusted, what the QPU actually contributed, and the honest limits. The NOTES list must cover the PMU concept, the observability model, the classical angle tuning, the absence of quantum advantage at this size, the model simplifications, and sensible next steps such as larger IEEE test systems and error mitigation.
- A failed or fallback run must print its own honest inference and must never present simulator output as hardware output.

## Artifact contract

Route this textual design to `bob-quantum-designs/`. Route the Python file, the synchronized notebook, result files, plots, logs, and policy-compliance reports to `bob-quantum-store/grid-sensor-pmu-placement/`. Suggested PNG artifacts: a circuit diagram and a bar chart of the most-sampled placements. The Python file is authoritative and the same-name notebook is generated from it.

## Risks and limitations

- Hardware noise lowers the optimal-placement probability well below the ideal value, so a small sampled share of optimal placements is normal.
- Open Plan QPU time is limited, and queue time may delay a run.
- The instance is trivially solvable classically. Do not describe the result as a quantum speedup.
- Observability here is topological only. Real PMU placement also considers zero-injection buses, channel counts, redundancy, communications, and cost.

## Validation criteria

The design is successful when it:

1. Defines a nine-qubit QAOA formulation of PMU placement with an exact classical check.
2. Remains design-only and contains no executable Python.
3. Includes the textual real-QPU-first and simulator-fallback section.
4. Specifies the terminal presentation, the result files, and the success criteria.
5. Is saved under `bob-quantum-designs/grid-sensor-pmu-placement/`.
