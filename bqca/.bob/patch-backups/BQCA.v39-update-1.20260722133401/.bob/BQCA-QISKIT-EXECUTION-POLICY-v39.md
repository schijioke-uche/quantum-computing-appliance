# BQCA Qiskit 2.5 Plan-Aware Execution Policy v39

<!-- BQCA-QISKIT-EXECUTION-v39:BEGIN -->
## Mandatory CODE-intent classification

Treat a request as **CODE intent** immediately when the user asks to `create`, `implement`, `write`, `generate`, `build`, `develop`, `produce`, `scaffold`, `construct`, `code`, `program`, `modify`, `update`, `repair`, `fix`, `refactor`, `complete`, `execute`, or otherwise produce quantum/Qiskit code or an executable quantum artifact. Do not wait for the exact phrase "create code".

## Mandatory runtime preparation

Before executing any quantum/Qiskit Python file or notebook:

1. Run `.bob/quantum-tools/qiskit-configuration.sh configure --quiet`.
2. Run `.bob/quantum-tools/qiskit-v2x-environment.sh ensure --quiet`.
3. Execute through `.bob/quantum-tools/qiskit-v2x-environment.sh run <file.py>` or `run-notebook <file.ipynb>`.
4. The environment must be named `qiskit-v2x-env` and must use Qiskit 2.5 or later.
5. If Qiskit is missing or older than 2.5, uninstall the old `qiskit`/`qiskit-terra` packages and install the latest compatible `qiskit>=2.5` plus the required Runtime, Aer, algorithm, Connector, and notebook dependencies.

## Open Plan real-QPU rule

When `QPlanV2` reports Open Plan and a real QPU is available:

- Session is prohibited.
- Use job mode with `SamplerV2(mode=backend)`.
- Do not construct `Session(...)` in the Open Plan branch.
- Do not call `backend.run()` on real IBM Quantum hardware.

## Paid Plan real-QPU rule

When a paid plan is detected (`Flex`, `Pay-As-You-Go`, `Premium`, or `Dedicated`) and a real QPU is available:

- Use a `Session(backend=backend)` strategy.
- Use `SamplerV2(mode=session)` or `EstimatorV2(mode=session)` as appropriate to the workload.
- Close the session through a context manager or explicit close operation.
- Do not call `backend.run()` on real IBM Quantum hardware.

## Simulator fallback rule

If no eligible real QPU is available or real-QPU execution fails:

- Fall back through `try/except`.
- Use `AerSimulator` or another supported local simulator.
- Transpile the circuit for the selected simulator before execution.
- `backend.run()`-style execution is permitted only when the receiver is a local simulator backend such as `sim_backend`, `aer_backend`, or another clearly local simulator object.
- Report `REAL_QPU` or `SIMULATOR` and the fallback reason.

## Qiskit 2.5 design and code rule

Every quantum solution design and every Qiskit implementation must explicitly state and follow the Qiskit 2.5-or-later contract, the `qiskit-v2x-env` execution requirement, the Open Plan no-Session rule, the Paid Plan Session rule, the simulator fallback rule, and the real-QPU `backend.run()` prohibition.

Design documents must be textual instructions. They must not embed executable Python blocks.

## Hello World rule

When the user says `Run Hello World`, `run hello-world`, `run hellow-world`, `run Qiskit Hello World`, or an equivalent spelling, immediately inspect `<BQCA-root>/test/`. If a matching `hello-world.py`/`hello_world.py`/`hellow-world.py` exists, run it through `qiskit-v2x-env`. If no Python file exists but a matching notebook exists, execute the notebook through the same environment. If neither exists, continue with normal CODE-intent handling and report that no prebuilt test artifact was found.

## Completion gates

Before reporting a generated code artifact complete:

```bash
.bob/quantum-tools/qca-code-quality-guard.sh --prepare <file.py>
```

Before reporting a generated design complete:

```bash
.bob/quantum-tools/qiskit-connector.sh --validate-design <file.md>
```

Any validation failure is blocking. Repair the artifact and validate again.
<!-- BQCA-QISKIT-EXECUTION-v39:END -->
