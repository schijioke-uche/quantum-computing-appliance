# BQCA Canonical Production Policy v45

<!-- BQCA-CANONICAL-PRODUCTION-POLICY-v45:BEGIN -->

## 1. Authority and precedence

This document is the sole active natural-language production policy for the Bob Quantum Computing Agent (BQCA). Historical policies from v30 through v44 are audit records only. The stable active path is `.bob/BQCA-PRODUCTION-POLICY.md`; the versioned active copy is `.bob/BQCA-PRODUCTION-POLICY-v45.md`.

All custom modes, rules, skills, and supported quantum tools must refer to the stable policy. Direct execution is the default workflow for development and testing. `.bob/quantum-tools/bqca-policy-orchestrator.sh` is optional for formal compliance documentation. `.bob/quantum-tools/bqca-policy-doctor.sh` verifies policy integrity, wrapper delegation, drift, and behavioral assurance.

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

Every `.py` or `.ipynb` execution should capture output to a `<source-stem>-result-output.txt` file beside the source using the direct execution method (Section 15). Capture complete combined stdout and stderr, including Qiskit Connector, plan, backend, real-QPU, simulator, fallback, warning, error, and result output. Include start/completion date and time, duration, command, source, backend, plan, target, and exit status.

For a final real-QPU result, the actual Job ID must be the first line. The bottom of the file must contain a `RESULT SUMMARY` stating whether execution was successful and whether the result contract passed.

## 12. Canonical validation order

### Design

1. Validate design routing and textual-only format.
2. Validate Connector, account, and plan strategy.
3. Validate Open Plan no-Session behavior and suitable SamplerV2/EstimatorV2 job-mode selection.
4. Validate Paid Plan Session behavior.
5. Validate home environment, Qiskit 2.5+, simulator fallback, and hardware restrictions.
6. Validate Hello World scope, result-output contract, and secret handling.
7. Generate a policy-compliance report (optional).

### Code

1. Validate CODE intent and implementation routing.
2. Validate Connector imports and initialization.
3. Validate Open Plan no-Session behavior and a suitable SamplerV2 or EstimatorV2 `mode=backend` branch.
4. Validate Paid Plan Session behavior.
5. Reject real-hardware `backend.run()`.
6. Validate QPU checks, simulator fallback, home environment, Qiskit 2.5+, Hello World scope, markers, and secret handling.
7. Generate or validate the synchronized notebook.
8. Generate a policy-compliance report (optional).

## 13. Runtime assurance and bypass prevention

- Stable and versioned active policies must be byte-identical and match the registry SHA-256.
- Historical policy hashes must match the policy-history manifest.
- Every custom mode, rule, skill, and supported quantum tool must contain exactly one v45 canonical awareness block and no active v30-v44 block.
- Compliance or result evidence that contains credential material is noncompliant.

## 14. Historical disposition

Requirements from v30-v42 remain incorporated as documented by v43. v43 is incorporated as the canonical-consolidation predecessor. v44 added assurance, drift detection, bypass prevention, secret scanning, and the Open Plan SamplerV2-or-EstimatorV2 primitive-selection clarification. v45 makes direct execution the default workflow and orchestrator optional for formal compliance.

## 15. Direct execution workflow (v45 default)

### Primary Method: Direct Execution with Summary

**Recommended: Use BQCA Direct Execute Wrapper**

```bash
.bob/quantum-tools/bqca-direct-execute.sh bob-quantum-store/<design>/<code>.py
```

**Benefits:**
- Real-time terminal output streaming
- Immediate execution feedback
- Automatic result capture
- Structured RESULT SUMMARY appended automatically
- Parses BQCA execution markers
- Tracks duration, exit status, Job ID
- Fast and reliable
- Perfect for iterative development

**Alternative: Manual Direct Execution**

```bash
cd /path/to/workspace
~/qiskit-v2x-env/bin/python bob-quantum-store/<design>/<code>.py 2>&1 | tee bob-quantum-store/<design>/<code>-result-output.txt
```

**Note:** Manual execution captures raw output without structured summary. Use the wrapper for complete result documentation.

**Requirements:**
- Must use `$HOME/qiskit-v2x-env/bin/python` explicitly
- Result file must follow naming convention: `<source-stem>-result-output.txt`
- Result file must be in same directory as source
- Wrapper automatically appends RESULT SUMMARY section

### Optional Method: Orchestrator

**For Formal Compliance, Production, or Audit Requirements:**

```bash
.bob/quantum-tools/bqca-policy-orchestrator.sh execute bob-quantum-store/<design>/<code>.py
```

**Use When:**
- Formal compliance reports are required
- Production deployment validation needed
- Audit trail documentation required
- Policy drift checks are mandatory

**Note:** Orchestrator adds validation overhead and may timeout on long-running quantum jobs. Use direct execution for all interactive and development work.

### Execution Decision Matrix

| Scenario | Method | Reason |
|----------|--------|--------|
| Development/Testing | Direct | Fast, real-time output |
| Interactive Exploration | Direct | Immediate feedback |
| Debugging | Direct | Clear error messages |
| Quick Experiments | Direct | No overhead |
| Formal Documentation | Orchestrator | Compliance reports |
| Production Deployment | Orchestrator | Full validation |
| Audit Requirements | Orchestrator | Policy enforcement |

<!-- BQCA-CANONICAL-PRODUCTION-POLICY-v45:END -->
