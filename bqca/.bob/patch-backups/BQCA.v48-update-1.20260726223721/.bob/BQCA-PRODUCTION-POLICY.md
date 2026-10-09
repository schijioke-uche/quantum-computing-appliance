# BQCA Canonical Production Policy v48

<!-- BQCA-CANONICAL-PRODUCTION-POLICY-v48:BEGIN -->

## 1. Authority and precedence

This document is the sole active natural-language production policy for the Bob Quantum Computing Agent (BQCA). The stable active path is `.bob/BQCA-PRODUCTION-POLICY.md`; the versioned active copy is `.bob/BQCA-PRODUCTION-POLICY-v48.md`. Historical policies and the v47 core/update patch series are audit records only after their effective requirements are incorporated here.

All custom modes, rules, skills, supported quantum tools, and the local quantum knowledgebase must follow this v48 authority. The active-policy registry, canonical policy SHA-256, policy doctor, and runtime wrappers enforce this precedence. Conflicting local guidance is superseded by this policy.

## 2. IBM Bob and BQCA guiding principles

IBM Bob classifies user intent, clarifies missing scientific parameters, decomposes work, creates governed designs, generates implementation artifacts, validates and repairs code, coordinates Qiskit configuration and execution, produces synchronized notebooks and result evidence, and routes artifacts for review and reuse. Human experts retain responsibility for scientific assumptions, execution-cost decisions, and interpretation of research results.

## 3. CODE intent

Treat a request as CODE intent immediately when the user uses `create`, `implement`, `write`, `generate`, `build`, `develop`, `produce`, `scaffold`, `construct`, `code`, `program`, `modify`, `update`, `repair`, `fix`, `refactor`, `complete`, `execute`, or equivalent wording and the object is quantum/Qiskit code or an executable quantum artifact. Do not wait for the exact phrase `create code`.

## 4. Governed artifact routing and secrets

- Research, architecture, and solution-design artifacts go to `bob-quantum-designs/`.
- Executable Python, notebooks, scripts, results, plots, logs, and implementation documentation go to `bob-quantum-store/`.
- Design and implementation artifacts remain separate and reviewable.
- Credentials and secrets must never be embedded in generated designs, code, notebooks, logs, compliance reports, knowledgebase outputs, or result-output files.

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

- **Open Plan:** real-QPU execution uses job mode without `Session`. Use `SamplerV2(mode=backend)` when the workload returns samples, bitstrings, counts, shots, or probability distributions. Use `EstimatorV2(mode=backend)` when the workload estimates expectation values, observables, energies, or Hamiltonians.
- **Paid Plan:** real-QPU execution uses `Session(backend=backend)` with `SamplerV2(mode=session)` or `EstimatorV2(mode=session)` as appropriate.
- **Simulator fallback:** use a controlled `try/except` path, `transpile`, and `AerSimulator` or another supported local simulator.
- `backend.run()` is permitted only for a clearly local simulator and is prohibited for real IBM Quantum hardware. Real hardware uses Runtime V2 primitives.

Every executable quantum workload must emit:

- `BQCA_EXECUTION_TARGET=REAL_QPU` or `BQCA_EXECUTION_TARGET=SIMULATOR`;
- `BQCA_PLAN=<detected-plan>`;
- `BQCA_BACKEND=<backend-name>`;
- `BQCA_JOB_ID=<actual-job-id>` for a real-QPU result;
- `BQCA_RESULT=SUCCESS` or `BQCA_RESULT=FAILURE`;
- `BQCA_FALLBACK_REASON=<reason>` whenever simulator fallback occurs.

Scientific values may be emitted separately as `BQCA_RESULT_VALUE=<value>` and must not replace the required SUCCESS/FAILURE execution-status marker.

## 9. Notebook production

The `.py` implementation is authoritative. The BQCA runtime watcher automatically creates or refreshes the same-name `.ipynb` sibling after the Python source becomes stable. The notebook must be structurally valid and synchronized to the source digest. Manual notebook construction is an emergency fallback only after genuine automatic-generation failure.

## 10. Hello World scope

Hello World is request-scoped. Do not add Hello World sections, tests, commands, artifacts, or `bob-quantum-store/test` dependencies to unrelated designs or code. For an explicit Hello World request, use an existing artifact under `bob-quantum-store/test/` and execute it through the authorized environment and v48 execution contract.

## 11. Direct execution and governed dual-result contract

Direct execution through `.bob/quantum-tools/bqca-direct-execution.sh` is the default for development, testing, interactive exploration, debugging, and quick experiments. The formal orchestrator is explicit opt-in only for formal compliance, production deployment, formal documentation evidence, or audit requirements.

1. Direct execution runs synchronously.
2. Python uses `$HOME/qiskit-v2x-env/bin/python`, `PYTHONUNBUFFERED=1`, and `python -u`.
3. Combined stdout and stderr display continuously on the terminal while the workload runs.
4. The same complete stream is captured in `<source-stem>-result-output.txt` beside the source.
5. The finalized professional report is mirrored to `output.txt` in the same directory.
6. Both files contain the complete terminal output, timestamps, duration, command, source path, execution method, plan, backend, target, Job ID, fallback reason, exit status, notebook status, contract status, and a bottom `RESULT SUMMARY`.
7. For a final real-QPU result, `JOB ID: <actual-job-id>` is line one of both files.
8. Direct-mode policy gaps are warnings and preserve the workload process exit status; they do not turn a successful process into an artificial failure.
9. Credential leakage is blocking; captured secret-bearing output must not be published.

## 12. Execution decision matrix and completion order

| Scenario | Method | Reason |
|---|---|---|
| Development/Testing | Direct | Fast, real-time output |
| Interactive Exploration | Direct | Immediate feedback |
| Debugging | Direct | Clear error messages |
| Quick Experiments | Direct | No orchestration overhead |
| Formal Documentation | Orchestrator | Compliance reports |
| Production Deployment | Orchestrator | Full validation |
| Audit Requirements | Orchestrator | Policy enforcement |

### Direct execution — default

1. Invoke `.bob/quantum-tools/bqca-direct-execution.sh run <file.py>` or `run-notebook <file.ipynb>`.
2. Confirm or prepare `$HOME/qiskit-v2x-env` and Qiskit 2.5+ without invoking the orchestrator.
3. Rebuild the `bqca` Qiskit account configuration when the configuration tool is available.
4. Execute through the authorized Python with unbuffered output.
5. Stream and capture combined stdout/stderr.
6. Produce `<source-stem>-result-output.txt` and `output.txt` beside the source.
7. Preserve the workload exit status; record direct-mode contract gaps as warnings and block credential leakage.

### Formal execution — explicit opt-in

Use `.bob/quantum-tools/bqca-direct-execution.sh formal-run <artifact>` only when formal compliance documentation, production deployment, or audit evidence is explicitly required. Formal mode may use `.bob/quantum-tools/bqca-policy-orchestrator.sh` and treats policy violations as blocking.

## 13. Runtime assurance and conflict prevention

- Stable and versioned v48 policy files must be byte-identical and match the registry SHA-256.
- Historical policy hashes must match the policy-history manifest.
- Every custom mode, rule, skill, and supported quantum tool must contain exactly one v48 awareness block.
- Public execution wrappers default to `bqca-direct-execution.sh`; formal orchestration requires an explicit formal command or flag.
- Universal orchestrator-only execution wording, direct-result-capture prohibitions, and stale v30-v47 active-policy blocks must not remain active.
- `xLaunchpad.sh` performs the quiet v48 policy-doctor preflight but must not force formal orchestration for ordinary direct execution.
- Compliance, result, or knowledgebase evidence containing credential material is noncompliant.
- Semantic capability checks take precedence over brittle source-layout matching.

## 14. Local quantum algorithm knowledgebase

BQCA uses the offline catalog at `.bob/quantum-tools/knowlegebase/bqca_quantum_algorithm_catalog.json` through `.bob/quantum-tools/bqca-quantum-kb.sh` as a supplementary accelerator for every quantum DESIGN and CODE request.

1. Use `search`, `show`, `design`, or `scaffold` to identify compatible algorithm patterns, Qiskit packages, primitive selection, circuit assumptions, and result expectations.
2. The catalog and examples must identify themselves as BQCA v48 assets and support Qiskit 2.5+.
3. Open Plan examples use `SamplerV2(mode=backend)` or `EstimatorV2(mode=backend)` without `Session`.
4. Paid Plan examples use `Session(backend=backend)` with the suitable V2 primitive.
5. Simulator fallback is controlled and follows real-QPU eligibility or execution failure.
6. The catalog covers foundations, oracle algorithms, Fourier/phase algorithms, amplitude estimation, variational eigensolvers, optimization, machine learning, chemistry/nature, dynamics, linear systems, error correction/mitigation, characterization, and application patterns.
7. The catalog supplements IBM Bob intelligence and approved research. It never overrides the central policy, installed APIs, backend constraints, security, routing, notebook, result, or human-review requirements.
8. Update 5 mandatory URL crawling and sublink drilldown are superseded. Network crawling and a mandatory research-trace artifact are not required.
9. A missing local entry is not a blocking failure; use approved supplemental research and continue when a compatible pattern is not present.

## 15. Semantic assurance and repair

A protected shell or Python tool is valid when it exists, passes syntax validation, has safe permissions, and exposes the public capabilities required by this policy. Formatting, function order, and internal dispatch spelling must not independently trigger policy drift.

The Qiskit environment manager must expose `ensure`, `check`, `python`, `run`, `run-notebook`, `hello-world`, `hello-world-if-present`, `exec`, `environment-path`, `python-path`, and `activation-command`.

Repair may synchronize stable/versioned policy copies, refresh registry hashes, restore safe executable permissions, restore v48 awareness blocks, and regenerate assurance reports. Repair must never read, print, overwrite, or redistribute `.env`, IBM Quantum account JSON, API tokens, or workload secrets.

Duplicate custom-mode slugs and legacy-compatible implementation markers are warnings unless they prevent parsing or execution.

## 16. Cumulative v48 lineage

BQCA v48 incorporates the effective behavior of:

- `patch-BQCA.v47.sh` — direct execution plus semantic assurance baseline;
- `patch-BQCA.v47-update-1.sh` — canonical-policy/runtime consolidation repair;
- `patch-BQCA.v47-update-2.sh` — corrected semantic authority validation;
- `patch-BQCA.v47-update-3.sh` — professional direct-result presentation and process-status behavior;
- `patch-BQCA.v47-update-4.sh` — superseding synchronous direct execution, strict markers, and appliance-wide routing;
- `patch-BQCA.v47-update-5.sh` — historical knowledgebase-index experiment;
- `patch-BQCA.v47-update-6.sh` — active offline curated algorithm catalog that supersedes Update 5 URL crawling.

The preceding patch files and v47 policy are historical/audit sources after v48 activation. They do not independently govern decisions.

## 17. Active-component obligation

All custom modes, rules, skills, supported tools, templates, launchers, validators, result processors, and knowledgebase assets must use `.bob/BQCA-PRODUCTION-POLICY.md` as the active v48 authority. They must not independently reactivate v47 or any older policy. The v48 policy doctor blocks launch when authority, hash, awareness, routing, syntax, permissions, or cumulative knowledgebase requirements drift.

<!-- BQCA-CANONICAL-PRODUCTION-POLICY-v48:END -->
