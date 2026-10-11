# BQCA v48 Quantum Solution Design Template

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

<!-- BQCA-ACTIVE-CENTRAL-POLICY:BEGIN -->
## Active central policy binding
Before every quantum DESIGN or CODE decision, resolve the currently active authority through `.bob/quantum-tools/bqca-active-policy-listener.sh sync`. Read the stable policy and its embedded validation contract returned by the listener. Never hardcode a policy version or duplicate the complete central policy in this component.

Validate every design through `.bob/quantum-tools/qiskit-design-policy-check.py` and every Python code artifact through `.bob/quantum-tools/qiskit-code-policy-check.py`. The validators reload the registry, policy, policy SHA-256, and validation contract on every invocation and automatically create the required same-directory design/code policy-compliance report. Do not report an artifact complete unless its compliance report exists and reflects the active policy.
<!-- BQCA-ACTIVE-CENTRAL-POLICY:END -->

<!-- BQCA-BOB-SHELL-V2-DNA:BEGIN -->
## Bob Shell 2.x BQCA project-DNA binding
In a trusted Bob Shell 2.x workspace, read `AGENTS.md`, resolve the active central BQCA policy, honor the exported menu option/action/skill/mode, and use the current rules, relevant skills, quantum tools, and offline knowledgebase. This component supplements the existing BQCA workflow and must not replace its domain purpose or active-policy controls. Never degrade to generic Bob behavior.
<!-- BQCA-BOB-SHELL-V2-DNA:END -->
