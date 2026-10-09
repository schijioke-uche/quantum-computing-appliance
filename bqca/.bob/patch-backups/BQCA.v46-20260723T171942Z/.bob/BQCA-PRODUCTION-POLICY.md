# BQCA Canonical Production Policy v44

<!-- BQCA-CANONICAL-PRODUCTION-POLICY-v44:BEGIN -->

## 1. Authority and precedence

This document is the sole active natural-language production policy for the Bob Quantum Computing Agent (BQCA). Historical policies from v30 through v43 are audit records only. The stable active path is `.bob/BQCA-PRODUCTION-POLICY.md`; the versioned active copy is `.bob/BQCA-PRODUCTION-POLICY-v44.md`.

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

- **Open Plan:** real-QPU execution uses job mode without `Session`. Use `SamplerV2(mode=backend)` when the workload returns samples, bitstrings, counts, shots, or probability distributions. Use `EstimatorV2(mode=backend)` when the workload estimates expectation values, observables, energies, or Hamiltonians. The code must select the suitable V2 primitive for its computation.
- **Paid Plan:** real-QPU execution uses `Session(backend=backend)` with `SamplerV2(mode=session)` or `EstimatorV2(mode=session)` as appropriate.
- **Simulator fallback:** use a controlled `try/except` path, `transpile`, and `AerSimulator` or another supported local simulator.
- `backend.run()` is permitted only for a clearly local simulator and is prohibited for real IBM Quantum hardware. Real hardware uses Runtime V2 primitives.
- Generated code must emit canonical execution markers for target, plan, backend, result, fallback reason, and real-QPU Job ID.

## 9. Notebook production

The `.py` implementation is authoritative. The BQCA runtime watcher automatically creates or refreshes the same-name `.ipynb` sibling after the Python source becomes stable. The notebook must be structurally valid and synchronized to the source digest. Manual notebook construction is an emergency fallback only after genuine automatic-generation failure.

## 10. Hello World scope

Hello World is request-scoped. Do not add Hello World sections, tests, commands, artifacts, or `bob-quantum-store/test` dependencies to unrelated designs or code. For an explicit Hello World request, use an existing artifact under `bob-quantum-store/test/` and execute it through the authorized environment and canonical gate.

## 11. Live terminal and governed dual-result contract

Every direct or formal `.py`/`.ipynb` execution must provide live terminal visibility and durable evidence:

1. **Live terminal output:** combined workload stdout and stderr must be displayed continuously as the process produces it. Qiskit Connector, plan, backend, QPU, simulator, fallback, warning, error, progress, and result messages remain visible. End-only buffering is prohibited.
2. **Authoritative per-source result:** the same complete combined stream must be recorded in `<source-stem>-result-output.txt` beside the source artifact.
3. **Compatibility/latest-run mirror:** the same finalized professional report must also be written to `output.txt` in the source directory. The per-source result remains the authoritative durable record; `output.txt` is the latest-run convenience mirror.

Python execution must use unbuffered behavior (`PYTHONUNBUFFERED=1` and `python -u`). Both result files must include the full stream, start/completion date and time, duration, command, source, execution method, backend, plan, target, exit status, and bottom `RESULT SUMMARY`. For a final real-QPU result, the actual Job ID must be the first line of both finalized files.

Direct mode records policy gaps as non-blocking warnings while preserving the workload process exit status. Formal mode treats policy violations as blocking and is used only when explicitly requested.

## 12. Execution decision matrix and completion order

### Execution decision matrix

| Scenario | Default method | Reason |
|---|---|---|
| Development/Testing | Direct | Fast startup and real-time output |
| Interactive Exploration | Direct | Immediate feedback |
| Debugging | Direct | Clear live error messages |
| Quick Experiments | Direct | No orchestrator validation overhead |
| Formal Documentation | Orchestrator | Formal compliance reports |
| Production Deployment | Orchestrator | Full validation and completion gates |
| Audit Requirements | Orchestrator | Policy enforcement and auditable evidence |

### Direct execution (default)

1. Use `.bob/quantum-tools/bqca-direct-execution.sh`.
2. Confirm or prepare `$HOME/qiskit-v2x-env` and Qiskit 2.5+ without invoking the orchestrator.
3. Rebuild the `bqca` Qiskit account configuration when the configuration tool is available.
4. Execute Python directly with the authorized environment's Python in unbuffered mode.
5. Mirror combined stdout/stderr live to the terminal.
6. Produce `<source-stem>-result-output.txt` and `output.txt` beside the source.
7. Do not block a successful direct run solely because formal compliance markers are incomplete; record them as warnings.

### Formal execution (explicit opt-in)

1. Run the policy doctor.
2. Validate design/code and all canonical policy requirements.
3. Rebuild account configuration and activate the authorized environment.
4. Execute through `.bob/quantum-tools/bqca-policy-orchestrator.sh execute`.
5. Enforce the full result, notebook, secret-scan, compliance-report, and completion gates.
6. Report formal completion only when every canonical gate passes.

## 13. Runtime assurance and conflict prevention

- Stable and versioned active policies must be byte-identical and match the registry SHA-256.
- Historical policy hashes must match the policy-history manifest.
- Every custom mode, rule, skill, and supported quantum tool must contain exactly one v46 canonical awareness block and no active v30-v45 block.
- Public execution wrappers default to `bqca-direct-execution.sh`; formal orchestrator execution requires an explicit formal command or flag.
- Universal orchestrator-only execution wording, direct-result-capture prohibitions, and v44/v45 execution routing blocks are conflicting guidance and must not remain active.
- `xLaunchpad.sh` performs the quiet policy-doctor preflight but must not force the orchestrator for ordinary direct execution.
- Compliance or result evidence that contains credential material is noncompliant.

## 14. Historical disposition

Requirements from v30-v42 remain incorporated as documented by v43. v43 is incorporated as the canonical-consolidation predecessor. v44 is the sole active authority and adds assurance, drift detection, bypass prevention, secret scanning, and the Open Plan SamplerV2-or-EstimatorV2 primitive-selection clarification.

<!-- BQCA-CANONICAL-PRODUCTION-POLICY-v44:END -->
