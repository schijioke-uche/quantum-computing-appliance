# BQCA Canonical Production Policy v44

<!-- BQCA-CANONICAL-PRODUCTION-POLICY-v44:BEGIN -->

## 1. Authority and precedence

This document is the sole active natural-language production policy for the Bob Quantum Computing Agent (BQCA). Historical policies from v30 through v43 are audit records only. The stable active path is `.bob/BQCA-PRODUCTION-POLICY.md`; the versioned active copy is `.bob/BQCA-PRODUCTION-POLICY-v44.md`.

All custom modes, rules, skills, and supported quantum tools must refer to the stable policy and route design, code, pre-execution, execution, result, and completion enforcement through `.bob/quantum-tools/bqca-policy-orchestrator.sh`. `.bob/quantum-tools/bqca-policy-doctor.sh` verifies policy integrity, wrapper delegation, drift, and behavioral assurance.

## 2. IBM Bob and BQCA guiding principles

IBM Bob classifies user intent, clarifies missing scientific parameters, decomposes work, creates governed designs, generates implementation artifacts, validates and repairs code, coordinates Qiskit configuration and execution, produces synchronized notebooks and result evidence, and routes artifacts for review and reuse. Human experts retain responsibility for scientific assumptions, execution cost decisions, and interpretation of research results.

## 3. CODE intent

Treat a request as CODE intent immediately when the user uses `create`, `implement`, `write`, `generate`, `build`, `develop`, `produce`, `scaffold`, `construct`, `code`, `program`, `modify`, `update`, `repair`, `fix`, `refactor`, `complete`, `execute`, or equivalent wording and the object is quantum/Qiskit code or an executable quantum artifact. Do not wait for the exact phrase `create code`.

## 4. Governed artifact routing and secrets

- Research, architecture, and solution-design artifacts go to `bob-quantum-designs/`.
- Executable Python, notebooks, scripts, results, plots, logs, and implementation documentation go to `bob-quantum-store/`.
- Design and implementation artifacts remain separate and reviewable.
- Credentials and secrets must never be embedded in generated designs, code, notebooks, logs, compliance reports, or result-output files.

## 5. Qiskit account-configuration gate

Before Qiskit Connector rules, templates, validators, backend resolution, or execution are invoked, run `.bob/quantum-tools/qiskit-configuration.sh configure --quiet` and require success. The runtime tool atomically rebuilds `~/.qiskit/qiskit-ibm.json` with exactly one profile named `bqca`; `bqca` is the only default account. Never print the token.

## 6. Authorized Qiskit environment and version

The only authorized BQCA Qiskit environment is `$HOME/qiskit-v2x-env`, outside the BQCA project root. When absent, create it with `python3 -m venv "$HOME/qiskit-v2x-env"`. Before Qiskit inspection, package management, validation, or execution, activate it with `source "$HOME/qiskit-v2x-env/bin/activate"`.

All Qiskit installation, uninstall, upgrade, and version checks occur only inside the activated home environment using its `python -m pip`. System/global pip, user-site Qiskit, and project-local `qiskit-v2x-env` are prohibited. Qiskit must be version 2.5 or later.

## 7. Design principles

Quantum solution designs must be textual and reviewable; executable Python blocks are prohibited. Designs must state:

- the problem, selected algorithm, assumptions, qubit/circuit strategy, risks, and validation criteria;
- the Qiskit Connector account and backend strategy;
- Open Plan and Paid Plan execution behavior;
- real-QPU-first execution and controlled simulator fallback;
- `$HOME/qiskit-v2x-env` and Qiskit 2.5+ requirements;
- the governed result-output contract;
- expected design and implementation artifacts.

For Open Plan, the design must state that real-QPU work runs in job mode without `Session`. It must identify `SamplerV2(mode=backend)` for sampling, shot, count, or distribution workloads and `EstimatorV2(mode=backend)` for expectation-value, observable, energy, or Hamiltonian workloads. The design must direct the implementation to choose the suitable V2 primitive according to workload semantics.

Hello World content must not appear in a generic design. It is permitted only when explicitly requested.

## 8. Code and execution principles

Generated Qiskit code must use Qiskit Connector imports and initialization, perform account/backend checks, verify real-QPU operational status and qubit capacity, and attempt eligible real-QPU execution before simulator fallback.

- **Open Plan:** real-QPU execution uses job mode without `Session`. Use `SamplerV2(mode=backend)` when the workload returns samples, bitstrings, counts, shots, or probability distributions. Use `EstimatorV2(mode=backend)` when the workload estimates expectation values, observables, energies, or Hamiltonians. The code must select the suitable V2 primitive for its computation.
- **Paid Plan:** real-QPU execution uses `Session(backend=backend)` with `SamplerV2(mode=session)` or `EstimatorV2(mode=session)` as appropriate.
- **Simulator fallback:** use a controlled `try/except` path, `transpile`, and `AerSimulator` or another supported local simulator.
- `backend.run()` is permitted only for a clearly local simulator and is prohibited for real IBM Quantum hardware. Real hardware uses Runtime V2 primitives.
- Generated code must emit canonical execution markers for target, plan, backend, result, fallback reason, and real-QPU Job ID.

## 9. Notebook production

The `.py` implementation is authoritative. The BQCA runtime watcher automatically creates or refreshes the same-name `.ipynb` sibling after the Python source becomes stable. The notebook must be structurally valid and synchronized to the source digest. Manual notebook construction is an emergency fallback only after genuine automatic-generation failure.

## 10. Hello World scope

Hello World is request-scoped. Do not add Hello World sections, tests, commands, artifacts, or `bob-quantum-store/test` dependencies to unrelated designs or code. For an explicit Hello World request, use an existing artifact under `bob-quantum-store/test/` and execute it through the authorized environment and canonical gate.

## 11. Result-output contract

Every `.py` or `.ipynb` execution must run through the BQCA execution gate so a professionally formatted `<source-stem>-result-output.txt` file is created beside the source. Capture complete combined stdout and stderr, including Qiskit Connector, plan, backend, real-QPU, simulator, fallback, warning, error, and result output. Include start/completion date and time, duration, command, source, backend, plan, target, and exit status.

For a final real-QPU result, the actual Job ID must be the first line. The bottom of the file must contain a `RESULT SUMMARY` stating whether execution was successful and whether the result contract passed.

## 12. Canonical validation and completion order

### Design

1. Validate design routing and textual-only format.
2. Validate Connector, account, and plan strategy.
3. Validate Open Plan no-Session behavior and suitable SamplerV2/EstimatorV2 job-mode selection.
4. Validate Paid Plan Session behavior.
5. Validate home environment, Qiskit 2.5+, simulator fallback, and hardware restrictions.
6. Validate Hello World scope, result-output contract, and secret handling.
7. Generate a policy-compliance report.

### Code

1. Validate CODE intent and implementation routing.
2. Validate Connector imports and initialization.
3. Validate Open Plan no-Session behavior and a suitable SamplerV2 or EstimatorV2 `mode=backend` branch.
4. Validate Paid Plan Session behavior.
5. Reject real-hardware `backend.run()`.
6. Validate QPU checks, simulator fallback, home environment, Qiskit 2.5+, Hello World scope, markers, and secret handling.
7. Generate or validate the synchronized notebook.
8. Generate a policy-compliance report.

### Execution

1. Pass the policy-doctor drift check.
2. Rebuild the `bqca` Qiskit account configuration.
3. Activate `$HOME/qiskit-v2x-env` and confirm Qiskit 2.5+.
4. Revalidate code.
5. Begin complete result capture.
6. Attempt real QPU first and use controlled simulator fallback when required.
7. Validate the result-output file, Job ID rule, summary, secret scan, and notebook synchronization.
8. Generate the final policy-compliance report.
9. Report completion only when the canonical gate passes.

## 13. Runtime assurance and bypass prevention

- Stable and versioned active policies must be byte-identical and match the registry SHA-256.
- Historical policy hashes must match the policy-history manifest.
- Every custom mode, rule, skill, and supported quantum tool must contain exactly one v44 canonical awareness block and no active v30-v43 block.
- Public validation and execution wrappers must delegate through the canonical orchestrator.
- Direct invocation of the result-capture layer is prohibited unless the orchestrator marks the call as internal.
- `xLaunchpad.sh` performs a quiet policy-doctor preflight and fails closed when drift is detected.
- Compliance or result evidence that contains credential material is noncompliant.

## 14. Historical disposition

Requirements from v30-v42 remain incorporated as documented by v43. v43 is incorporated as the canonical-consolidation predecessor. v44 is the sole active authority and adds assurance, drift detection, bypass prevention, secret scanning, and the Open Plan SamplerV2-or-EstimatorV2 primitive-selection clarification.

<!-- BQCA-CANONICAL-PRODUCTION-POLICY-v44:END -->
