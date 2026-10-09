# BQCA Canonical Production Policy v43

<!-- BQCA-CANONICAL-PRODUCTION-POLICY-v43:BEGIN -->

## 1. Authority and precedence

This document is the sole active natural-language production policy for the Bob Quantum Computing Agent (BQCA). Historical policy documents from v30 through v42 are retained only as audit records under `patches/BQCA/policy-history/`; they must not be independently interpreted as active instructions.

The stable active path is `.bob/BQCA-PRODUCTION-POLICY.md`. All custom modes, rules, skills, and supported quantum tools must refer to this file and route enforcement through `.bob/quantum-tools/bqca-policy-orchestrator.sh`.

## 2. IBM Bob and BQCA guiding principles

IBM Bob is the BQCA reasoning and orchestration layer. Bob classifies user intent, clarifies missing scientific parameters, decomposes work, creates governed designs, generates implementation artifacts, validates and repairs code, coordinates Qiskit configuration and execution, produces synchronized notebooks and result evidence, and routes artifacts for review and reuse. Human experts retain responsibility for scientific assumptions, execution cost decisions, and interpretation of research results.

## 3. CODE intent

Treat a request as CODE intent immediately when the user uses `create`, `implement`, `write`, `generate`, `build`, `develop`, `produce`, `scaffold`, `construct`, `code`, `program`, `modify`, `update`, `repair`, `fix`, `refactor`, `complete`, `execute`, or equivalent wording and the object is quantum/Qiskit code or an executable quantum artifact. Do not wait for the exact phrase “create code.”

## 4. Governed artifact routing

- Research, architecture, and solution-design artifacts go to `bob-quantum-designs/`.
- Executable Python, notebooks, scripts, results, plots, logs, and implementation documentation go to `bob-quantum-store/`.
- Design and implementation artifacts remain separate and reviewable.
- Credentials and secrets must never be embedded in generated designs, code, notebooks, logs, or reports.

## 5. Qiskit account-configuration gate

Before Qiskit Connector rules, templates, validators, backend resolution, or execution are invoked, run `.bob/quantum-tools/qiskit-configuration.sh configure --quiet` and require success. The runtime tool reads the required plan variables from the project-root `.env` and atomically rebuilds `~/.qiskit/qiskit-ibm.json` with exactly one profile named `bqca`; `bqca` is the only default account. Never print the token.

## 6. Authorized Qiskit environment and version

The only authorized BQCA Qiskit environment is `$HOME/qiskit-v2x-env`, outside the BQCA project root. When absent, create it with `python3 -m venv "$HOME/qiskit-v2x-env"`. Before Qiskit inspection, package management, validation, or execution, activate it with `source "$HOME/qiskit-v2x-env/bin/activate"`.

All Qiskit installation, uninstall, upgrade, and version checks occur only inside the activated home environment using its `python -m pip`. System/global pip, user-site Qiskit, and project-local `qiskit-v2x-env` are prohibited. Qiskit must be version 2.5 or later; if the environment contains an older Qiskit, remove the incompatible environment-local packages and install a compatible `qiskit>=2.5` stack inside that environment only.

## 7. Design principles

Quantum solution designs must be textual and reviewable; executable Python blocks are prohibited in design documents. Designs must state:

- the problem, selected algorithm, assumptions, qubit/circuit strategy, risks, and validation criteria;
- the Qiskit Connector account and backend strategy;
- Open Plan and Paid Plan execution behavior;
- real-QPU-first execution and controlled simulator fallback;
- `$HOME/qiskit-v2x-env` and Qiskit 2.5+ requirements;
- the governed result-output contract;
- expected design and implementation artifacts.

Hello World content must not appear in a generic design. It is permitted only when the user explicitly requests a Hello World design.

## 8. Code and execution principles

Generated Qiskit code must use Qiskit Connector imports and initialization, perform account/backend checks, verify real-QPU operational status and qubit capacity, and attempt eligible real-QPU execution before simulator fallback.

- **Open Plan:** real-QPU execution uses job mode with `SamplerV2(mode=backend)`. `Session` is prohibited.
- **Paid Plan:** real-QPU execution uses `Session(backend=backend)` with `SamplerV2(mode=session)` or `EstimatorV2(mode=session)`.
- **Simulator fallback:** use a controlled `try/except` path, `transpile`, and `AerSimulator` or another supported local simulator.
- `backend.run()` is permitted only for a clearly local simulator backend and is prohibited for real IBM Quantum hardware. Real hardware uses Runtime V2 primitives.
- Generated code must emit canonical execution markers for target, plan, backend, result, fallback reason, and real-QPU Job ID.

## 9. Notebook production

The `.py` implementation is authoritative. The BQCA runtime watcher automatically creates or refreshes the same-name `.ipynb` sibling after the Python source becomes stable. The notebook must be structurally valid and synchronized to the source digest. Manual notebook construction is an emergency fallback only after genuine automatic-generation failure.

## 10. Hello World scope

Hello World is request-scoped. Do not add Hello World sections, tests, commands, artifacts, or `bob-quantum-store/test` dependencies to unrelated designs or code. For an explicit Hello World request, use an existing Hello World Python or notebook artifact under `bob-quantum-store/test/` and execute it through the authorized environment and canonical execution gate.

## 11. Result-output contract

Every `.py` or `.ipynb` execution must run through the BQCA execution gate so a professionally formatted `<source-stem>-result-output.txt` file is created in the same directory as the source. The report captures complete combined stdout and stderr, including Qiskit Connector, plan, backend, real-QPU, simulator, fallback, warning, error, and result output. It includes start/completion date and time, duration, command, source, backend, plan, target, and exit status.

For a final real-QPU result, the actual Job ID must be the first line. The bottom of the file must contain a `RESULT SUMMARY` stating whether execution was successful and whether the result contract passed.

## 12. Canonical validation and completion order

### Design

1. Validate design routing.
2. Validate textual Connector and plan strategy.
3. Validate home environment and Qiskit 2.5+ requirements.
4. Validate simulator fallback and real-hardware restrictions.
5. Validate Hello World scope.
6. Validate the result-output contract.
7. Generate a policy-compliance report.

### Code

1. Validate CODE intent and implementation routing.
2. Validate Connector imports and initialization.
3. Validate Open Plan and Paid Plan branches.
4. Reject real-hardware `backend.run()`.
5. Validate simulator fallback and QPU checks.
6. Validate home environment and Qiskit 2.5+ requirements.
7. Validate Hello World scope and result markers.
8. Generate or validate the synchronized notebook.
9. Generate a policy-compliance report.

### Execution

1. Rebuild the `bqca` Qiskit account configuration.
2. Activate `$HOME/qiskit-v2x-env` and confirm Qiskit 2.5+.
3. Revalidate code.
4. Begin complete result capture.
5. Attempt real QPU first and use controlled simulator fallback when necessary.
6. Validate the result-output file, Job ID rule, summary, and notebook synchronization.
7. Generate the final policy-compliance report.
8. Report completion only when the canonical gate passes.

## 13. Historical policy disposition

- v30 routing/security: incorporated.
- v31/v32 early Connector rollout: superseded by and incorporated through v33/v34.
- v33 Connector code requirements: incorporated.
- v34 textual design clarification: incorporated.
- v35/v36 notebook guidance: duplicate/superseded by v37.
- v37 runtime notebook enforcement: incorporated.
- v38 account configuration gate: incorporated.
- v39 CODE intent and plan-aware execution: incorporated; only its earlier Hello World/environment wording was superseded.
- v39-update-1 environment isolation: superseded by v40 where more specific.
- v40 home-environment policy: incorporated.
- v41 Hello World scope: incorporated and authoritative for that scope.
- v42 result-output governance: incorporated.
- v43 is the sole active policy authority.

<!-- BQCA-CANONICAL-PRODUCTION-POLICY-v43:END -->
