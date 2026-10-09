# BQCA v47 Quantum Solution Design Template

## Problem and algorithm

Describe the research problem, selected quantum algorithm, scientific assumptions, qubit/circuit strategy, risks, validation criteria, and expected artifacts.

## Qiskit 2.5+ home environment and account configuration

The implementation must use `$HOME/qiskit-v2x-env`, activated with `source $HOME/qiskit-v2x-env/bin/activate`. Qiskit 2.5 or later is required. Before Qiskit Connector or backend work, the implementation must pass the BQCA configuration gate and use the single default `bqca` profile.

## Real-QPU-first plan strategy

Open Plan must not use `Session`. Use `SamplerV2(mode=backend)` for sampling, shot, count, bitstring, and probability-distribution workloads. Use `EstimatorV2(mode=backend)` for expectation-value, observable, energy, and Hamiltonian workloads.

For a Paid Plan such as Flex, Pay-As-You-Go, Premium, or Dedicated, use `Session(backend=backend)` with `SamplerV2(mode=session)` or `EstimatorV2(mode=session)` according to workload semantics.

The implementation must verify backend operational status and qubit capacity, attempt an eligible real QPU first, and use a controlled try/except fallback with `transpile` and `AerSimulator`. `backend.run()` is prohibited for real QPU hardware and is permitted only for a clearly local simulator.

## Direct execution and result contract

Development, testing, interactive exploration, debugging, and quick experiments use `.bob/quantum-tools/bqca-direct-execution.sh`. Formal compliance, production deployment, or audit evidence may explicitly use `formal-run` and the orchestrator.

The direct executor uses `$HOME/qiskit-v2x-env/bin/python` with `PYTHONUNBUFFERED=1` and `python -u`. It displays combined stdout and stderr live on the terminal and captures the same complete stream in `<source-stem>-result-output.txt` plus the same-directory `output.txt` mirror.

The code must emit:

- `BQCA_EXECUTION_TARGET=REAL_QPU` or `BQCA_EXECUTION_TARGET=SIMULATOR`;
- `BQCA_PLAN=<detected-plan>`;
- `BQCA_BACKEND=<backend-name>`;
- `BQCA_JOB_ID=<actual-job-id>` for real QPU;
- `BQCA_RESULT=SUCCESS` or `BQCA_RESULT=FAILURE`;
- `BQCA_FALLBACK_REASON=<reason>` for simulator fallback.

Both result files must contain complete terminal output, timestamps, duration, exit status, plan, backend, target, Job ID, fallback reason, notebook status, and a bottom `RESULT SUMMARY`. For a real-QPU result, the actual Job ID is line one. Direct-mode policy gaps are non-blocking warnings that preserve the workload exit status. Credential or secret leakage is blocking.

## Artifact contract

Route this textual design to `bob-quantum-designs/`. Route Python, the synchronized notebook, result files, plots, logs, and implementation documentation to `bob-quantum-store/`.

<!-- BQCA-CANONICAL-PRODUCTION-POLICY-v47:BEGIN -->
## BQCA v47 Update 4 superseding execution authority
Follow `.bob/BQCA-PRODUCTION-POLICY.md`. Direct execution through `.bob/quantum-tools/bqca-direct-execution.sh` is the default for development, testing, interactive exploration, debugging, and quick experiments. It uses `$HOME/qiskit-v2x-env/bin/python` with `PYTHONUNBUFFERED=1` and `python -u`, streams combined stdout/stderr live, and creates `<source-stem>-result-output.txt` plus `output.txt` beside the source. Quantum code must attempt a real QPU first, apply the Open/Paid Plan V2 primitive rules, use controlled `transpile` plus `AerSimulator` fallback, and emit `BQCA_EXECUTION_TARGET`, `BQCA_PLAN`, `BQCA_BACKEND`, `BQCA_JOB_ID`, `BQCA_RESULT=SUCCESS` or `BQCA_RESULT=FAILURE`, and `BQCA_FALLBACK_REASON` for fallback. The orchestrator is explicit opt-in only for formal compliance, production deployment, or audit evidence. Direct-mode policy gaps are warnings that preserve the workload exit status; credential leakage is blocking. This block supersedes conflicting local execution guidance.
<!-- BQCA-CANONICAL-PRODUCTION-POLICY-v47:END -->
