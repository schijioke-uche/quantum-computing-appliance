# BQCA v44 Quantum Solution Design Template

## Problem and algorithm

Describe the research problem, selected quantum algorithm, scientific assumptions, qubit/circuit strategy, risks, validation criteria, and expected artifacts.

## BQCA Qiskit 2.5+ Home Environment and Plan Policy

The implementation must use `$HOME/qiskit-v2x-env`, activated with `source $HOME/qiskit-v2x-env/bin/activate`. A project-local `qiskit-v2x-env` is prohibited. Qiskit package inspection, installation, upgrade, uninstall, validation, and execution occur only in the activated home environment. Qiskit 2.5 or later is required.

Before Qiskit Connector or backend work, the implementation must pass the BQCA configuration gate and use the single default `bqca` profile.

### Open Plan real-QPU job mode

Open Plan must not use `Session`. The implementation must choose the suitable Runtime V2 primitive according to workload semantics:

- Use `SamplerV2(mode=backend)` for sampling, shot, count, bitstring, and probability-distribution workloads.
- Use `EstimatorV2(mode=backend)` for expectation-value, observable, energy, and Hamiltonian workloads.

The design-to-code transition must preserve this primitive choice.

### Paid Plan real-QPU mode

For Flex, Pay-As-You-Go, Premium, Dedicated, or another paid plan, use `Session(backend=backend)` with `SamplerV2(mode=session)` or `EstimatorV2(mode=session)` according to workload semantics.

### Real-QPU-first and simulator fallback

The code must verify backend operational status and qubit capacity, attempt an eligible real QPU first, and use a controlled try/except fallback with `transpile` and `AerSimulator` or another supported local simulator. `backend.run()` is permitted only for a clearly local simulator and is prohibited for real QPU hardware.

## Result-output contract

Execute through `.bob/quantum-tools/bqca-policy-orchestrator.sh execute`. Produce `<code-name>-result-output.txt` in the same directory as the source. Capture complete stdout and combined stderr, including Qiskit Connector output. Include date/time, duration, plan, backend, target, result, fallback reason, and a bottom `RESULT SUMMARY` stating whether execution was successful. For real-QPU output, put the actual Job ID on the first line.

## Artifact contract

Route this textual design to `bob-quantum-designs/`. Route Python, synchronized notebook, result output, plots, logs, and implementation documentation to `bob-quantum-store/`.
<!-- BQCA-CANONICAL-PRODUCTION-POLICY-v44:BEGIN -->
## Canonical BQCA production policy
The sole active BQCA policy is `.bob/BQCA-PRODUCTION-POLICY.md` (v44). Historical policies are audit records only. Use `.bob/quantum-tools/bqca-policy-orchestrator.sh` for all design, code, execution, result, and completion gates, and `.bob/quantum-tools/bqca-policy-doctor.sh` for assurance. Open Plan real-QPU work must not use Session; use `SamplerV2(mode=backend)` for sampling workloads or `EstimatorV2(mode=backend)` for expectation-value/observable workloads.
<!-- BQCA-CANONICAL-PRODUCTION-POLICY-v44:END -->
