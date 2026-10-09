# BQCA Canonical Production Policy v47

<!-- BQCA-CANONICAL-PRODUCTION-POLICY-v47:BEGIN -->

## 1. Authority and precedence

This document is the sole active natural-language production policy for the Bob Quantum Computing Agent (BQCA). Historical policies from v30 through v46 are audit records only. The stable active path is `.bob/BQCA-PRODUCTION-POLICY.md`; the versioned active copy is `.bob/BQCA-PRODUCTION-POLICY-v47.md`.

All custom modes, rules, skills, and supported quantum tools must refer to the stable policy. Direct execution through `.bob/quantum-tools/bqca-direct-execution.sh` is the default for development/testing, interactive exploration, debugging, and quick experiments. The canonical orchestrator remains available only when formal compliance, production deployment, formal documentation evidence, or audit enforcement is explicitly requested. `.bob/quantum-tools/bqca-policy-doctor.sh` verifies policy integrity, execution routing, drift, and behavioral assurance.

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

- **Open Plan:** real-QPU execution uses job mode without `Session`. Use `SamplerV2(mode=backend)` when the workload returns samples, bitstrings, counts, shots, or probability distributions. Use `EstimatorV2(mode=backend)` when the workload estimates expectation values, observables, energies, or Hamiltonians. The implementation must select the suitable V2 primitive for its computation.
- **Paid Plan:** real-QPU execution uses `Session(backend=backend)` with `SamplerV2(mode=session)` or `EstimatorV2(mode=session)` as appropriate.
- **Simulator fallback:** use a controlled `try/except` path, `transpile`, and `AerSimulator` or another supported local simulator.
- `backend.run()` is permitted only for a clearly local simulator and is prohibited for real IBM Quantum hardware. Real hardware uses Runtime V2 primitives.

Every executable quantum workload must emit these canonical markers in its terminal stream:

- `BQCA_EXECUTION_TARGET=REAL_QPU` or `BQCA_EXECUTION_TARGET=SIMULATOR`;
- `BQCA_PLAN=<detected-plan>`;
- `BQCA_BACKEND=<backend-name>`;
- `BQCA_JOB_ID=<actual-job-id>` for a real-QPU result;
- `BQCA_RESULT=SUCCESS` when the workload completes successfully, or `BQCA_RESULT=FAILURE` when it fails;
- `BQCA_FALLBACK_REASON=<reason>` whenever simulator fallback occurs.

Scientific values may be emitted separately, for example as `BQCA_RESULT_VALUE=<value>`. They must not replace the required SUCCESS/FAILURE execution-status marker.

## 9. Notebook production

The `.py` implementation is authoritative. The BQCA runtime watcher automatically creates or refreshes the same-name `.ipynb` sibling after the Python source becomes stable. The notebook must be structurally valid and synchronized to the source digest. Manual notebook construction is an emergency fallback only after genuine automatic-generation failure.

## 10. Hello World scope

Hello World is request-scoped. Do not add Hello World sections, tests, commands, artifacts, or `bob-quantum-store/test` dependencies to unrelated designs or code. For an explicit Hello World request, use an existing artifact under `bob-quantum-store/test/` and execute it through the authorized environment and canonical gate.

## 11. Live terminal and governed dual-result contract

Direct execution is the normal BQCA execution method for development, testing, interactive exploration, debugging, and quick experiments. Use `.bob/quantum-tools/bqca-direct-execution.sh`.

1. The executor must run synchronously and display combined workload stdout and stderr continuously on the terminal while the workload is running.
2. Python must run with `$HOME/qiskit-v2x-env/bin/python`, `PYTHONUNBUFFERED=1`, and `python -u`.
3. The exact terminal stream, including Qiskit Connector, plan, backend, QPU, simulator, fallback, warning, error, progress, and result messages, must be captured in `<source-stem>-result-output.txt` beside the source artifact.
4. The finalized professional report must also be copied to `output.txt` in the same source directory. The per-source file is authoritative; `output.txt` is the latest-run mirror.
5. Both result files must contain the complete terminal output, start and completion timestamps, duration, command, source path, execution method, plan, backend, execution target, Job ID, fallback reason, exit status, notebook status, result-contract status, and a bottom `RESULT SUMMARY` section.
6. For a final real-QPU result, `JOB ID: <actual-job-id>` must be line one of both finalized files.
7. Direct mode records missing or inconsistent policy markers as warnings and preserves the workload process exit status. Such warnings must not convert an otherwise successful direct workload into a different process failure code.
8. Credential leakage is blocking. If a credential-leak scan fails, the complete captured stream must not be published into the durable result files.

## 12. Execution decision matrix and completion order

| Scenario | Method | Reason |
|---|---|---|
| Development/Testing | Direct | Fast, real-time output |
| Interactive Exploration | Direct | Immediate feedback |
| Debugging | Direct | Clear error messages |
| Quick Experiments | Direct | No validation overhead |
| Formal Documentation | Orchestrator | Compliance reports |
| Production Deployment | Orchestrator | Full validation |
| Audit Requirements | Orchestrator | Policy enforcement |

### Direct execution — default

1. Invoke `.bob/quantum-tools/bqca-direct-execution.sh run <file.py>` or `run-notebook <file.ipynb>`.
2. Confirm or prepare `$HOME/qiskit-v2x-env` and Qiskit 2.5+ without invoking the orchestrator.
3. Rebuild the `bqca` Qiskit account configuration when the configuration tool is available.
4. Execute through the authorized Python with unbuffered output.
5. Stream combined stdout/stderr live and capture the same stream.
6. Produce `<source-stem>-result-output.txt` and `output.txt` beside the source.
7. Preserve the workload exit status. Record direct-mode contract gaps as warnings; block credential leakage.

### Formal execution — explicit opt-in

Use `.bob/quantum-tools/bqca-direct-execution.sh formal-run <artifact>` only when formal compliance documentation, production deployment, or audit evidence is explicitly required. Formal mode may use `.bob/quantum-tools/bqca-policy-orchestrator.sh` and treats policy violations as blocking.

## 13. Runtime assurance and conflict prevention

- Stable and versioned active policies must be byte-identical and match the registry SHA-256.
- Historical policy hashes must match the policy-history manifest.
- Every custom mode, rule, skill, and supported quantum tool must contain exactly one v47 canonical awareness block and no active v30-v46 block.
- Public execution wrappers default to `bqca-direct-execution.sh`; formal orchestrator execution requires an explicit formal command or flag.
- Universal orchestrator-only execution wording, direct-result-capture prohibitions, and v44/v45 execution routing blocks are conflicting guidance and must not remain active.
- `xLaunchpad.sh` performs the quiet policy-doctor preflight but must not force the orchestrator for ordinary direct execution.
- Compliance or result evidence that contains credential material is noncompliant.

## 14. Historical disposition

Requirements from v30-v42 remain incorporated as documented by v43. v43 is incorporated as the canonical-consolidation predecessor. v44 added assurance, drift detection, bypass prevention, secret scanning, and the Open Plan SamplerV2-or-EstimatorV2 primitive-selection clarification. v45 made direct execution the default workflow with the bqca-direct-execute.sh wrapper and orchestrator optional for formal compliance. v46 added semantic policy assurance and drift repair. v47 combines the critical direct execution workflow from v45 with the semantic assurance from v46.

## 15. Direct execution operational commands

### Default Python execution

```bash
.bob/quantum-tools/bqca-direct-execution.sh run \
  bob-quantum-store/<workload>/<code>.py
```

### Default notebook execution

```bash
.bob/quantum-tools/bqca-direct-execution.sh run-notebook \
  bob-quantum-store/<workload>/<code>.ipynb
```

### Explicit formal execution

```bash
.bob/quantum-tools/bqca-direct-execution.sh formal-run \
  bob-quantum-store/<workload>/<code>.py
```

The default commands stream live combined output and create both the authoritative `<source-stem>-result-output.txt` file and the same-directory `output.txt` mirror. The formal command is reserved for formal compliance, deployment, or audit workflows.

## 16. BQCA v47 Semantic Policy Assurance and Drift Repair

BQCA v47 replaces brittle source-layout matching with semantic assurance. A protected shell tool is valid when it exists, passes shell syntax validation, has safe executable permissions, and exposes the capabilities required by its public usage contract. Formatting, function order, and the exact spelling of an internal dispatch implementation must not independently trigger policy drift.

The Qiskit environment manager must continue to expose these public capabilities: `ensure`, `check`, `python`, `run`, `run-notebook`, `hello-world`, `hello-world-if-present`, `exec`, `environment-path`, `python-path`, and `activation-command`.

The canonical policy hash and active registry remain authoritative. Repair may synchronize the stable and versioned policy copies, refresh the registered SHA-256 value, restore safe owner-executable permissions, and regenerate assurance reports. Repair must not read, print, overwrite, or redistribute `.env`, IBM Quantum account JSON, API tokens, or workload secrets.

Custom-mode duplicate slugs and legacy-compatible awareness blocks are diagnostics unless they prevent parsing or execution. They must be reported as warnings rather than causing a false launch failure.



<!-- BQCA-LOCAL-ALGORITHM-KNOWLEDGEBASE-v47-update-6:BEGIN -->
## 17. Local quantum algorithm knowledgebase (v47 Update 6)

BQCA uses the offline local catalog at `.bob/quantum-tools/knowlegebase/bqca_quantum_algorithm_catalog.json` through `.bob/quantum-tools/bqca-quantum-kb.sh` as a supplementary accelerator for quantum **DESIGN** and **CODE** requests.

Update 6 supersedes the Update 5 requirement to access URL seeds and drill into sublinks. Network crawling, seed-page access, sublink drilldown, and a mandatory `-kb-research.md` gate are no longer required for policy compliance.

For quantum design or code work:

1. Use `bqca-quantum-kb.sh search`, `show`, `design`, or `scaffold` to identify compatible algorithm patterns, Qiskit packages, primitive selection, circuit assumptions, and output expectations.
2. Use Qiskit 2.5.0 or later in the authorized `$HOME/qiskit-v2x-env`.
3. Open Plan must not use `Session`; use `SamplerV2(mode=backend)` for sampling/counts/distributions and `EstimatorV2(mode=backend)` for expectation values, observables, or energy workloads.
4. Paid Plan uses `Session(backend=backend)` with `SamplerV2(mode=session)` or `EstimatorV2(mode=session)` as suitable.
5. Simulator fallback remains controlled and occurs only after real-QPU eligibility or execution failure, using AerSimulator or Aer V2 primitives.
6. The local catalog supplies design cards and starter scaffolds across major foundations, oracle algorithms, Fourier/phase algorithms, amplitude estimation, variational eigensolvers, optimization, machine learning, chemistry/nature, dynamics, linear systems, error correction/mitigation, characterization, and application patterns.
7. The catalog supplements IBM Bob intelligence and approved sources. It never overrides the active central policy, current installed APIs, backend constraints, secret protections, artifact routing, notebook synchronization, result-output governance, or human scientific review.
8. If the requested algorithm is not represented or a catalog entry is only a design reference, use IBM Bob intelligence and approved external research. A missing local entry is not a blocking failure and must not prevent an otherwise policy-compliant artifact.

The active BQCA v47 direct-execution, formal-compliance, Qiskit Connector, plan, environment, notebook, Hello World, and result-output contracts remain unchanged.
<!-- BQCA-LOCAL-ALGORITHM-KNOWLEDGEBASE-v47-update-6:END -->

<!-- BQCA-CANONICAL-PRODUCTION-POLICY-v47:END -->

<!-- BQCA-V47-DIRECT-RESULT-CONTRACT-UPDATE-3:BEGIN -->
## v47 Update 3 — exact direct quantum result-output presentation

Every direct Python or notebook execution must stream combined stdout and stderr to the terminal while simultaneously capturing the complete stream. After execution, BQCA must write the same professional finalized report to `<source-stem>-result-output.txt` and `output.txt` in the source directory.

For a final real-QPU result, line one of both files must be `JOB ID: <actual-job-id>`. The report must then contain: the `BQCA v47 DIRECT QUANTUM EXECUTION RESULT OUTPUT` title; execution success; contract validity; target; source and output paths; start/completion timestamps; duration; exit status; plan; backend; Job ID; fallback reason; notebook synchronization; the complete terminal output including Qiskit Connector output; and a bottom `RESULT SUMMARY` with execution method `DIRECT`, compatibility-output path, and policy/execution issues.

Direct workload success is determined by the actual process exit status. Missing policy markers such as `BQCA_RESULT` make `Result contract valid: NO` and are recorded in `Policy/Execution issue(s)`, but do not convert an otherwise successful direct workload into a failed process. Formal orchestration may enforce those markers as blocking requirements.
<!-- BQCA-V47-DIRECT-RESULT-CONTRACT-UPDATE-3:END -->
