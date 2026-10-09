# BQCA Qiskit 2.5 Plan-Aware Execution Policy v39 Update 1

<!-- BQCA-QISKIT-EXECUTION-v39-update-1:BEGIN -->
## Mandatory CODE-intent classification

Treat a request as **CODE intent** immediately when the user asks to `create`,
`implement`, `write`, `generate`, `build`, `develop`, `produce`, `scaffold`,
`construct`, `code`, `program`, `modify`, `update`, `repair`, `fix`, `refactor`,
`complete`, `execute`, or otherwise produce quantum/Qiskit code or an
executable quantum artifact. Do not wait for the exact phrase "create code".

## Mandatory isolated runtime preparation

Before executing any quantum/Qiskit Python file or notebook:

1. Run `.bob/quantum-tools/qiskit-configuration.sh configure --quiet`.
2. Run `.bob/quantum-tools/qiskit-v2x-environment.sh ensure --quiet`.
3. Execute through `.bob/quantum-tools/qiskit-v2x-environment.sh run <file.py>`
   or `run-notebook <file.ipynb>`.
4. The environment must be named `qiskit-v2x-env` and must use Qiskit 2.5 or
   later.
5. All Qiskit version discovery, import checks, uninstalls, upgrades, and
   installations must run only through
   `<BQCA-root>/qiskit-v2x-env/bin/python` and its environment-local pip.
6. System/global Python, system pip, and user-site packages must never be used
   to inspect, uninstall, upgrade, or install Qiskit.
7. Host `python3 -m venv` may be used only to create qiskit-v2x-env when the
   environment is absent. After creation, all Qiskit operations immediately
   switch to the virtual-environment interpreter.
8. A pre-existing invalid or non-isolated qiskit-v2x-env must fail closed. BQCA
   must not fall back to host Python or host pip.
9. If Qiskit inside qiskit-v2x-env is missing or older than 2.5, uninstall the
   old environment-local `qiskit`/`qiskit-terra` packages and install the latest
   compatible `qiskit>=2.5` plus required dependencies inside that environment
   only.

## Open Plan real-QPU rule

When `QPlanV2` reports Open Plan and a real QPU is available:

- Session is prohibited.
- Use job mode with `SamplerV2(mode=backend)`.
- Do not construct `Session(...)` in the Open Plan branch.
- Do not call `backend.run()` on real IBM Quantum hardware.

## Paid Plan real-QPU rule

When a paid plan is detected and a real QPU is available:

- Use `Session(backend=backend)`.
- Use `SamplerV2(mode=session)` or `EstimatorV2(mode=session)` as appropriate.
- Close the session through a context manager or explicit close operation.
- Do not call `backend.run()` on real IBM Quantum hardware.

## Simulator fallback rule

If no eligible real QPU is available or real-QPU execution fails:

- Fall back through `try/except`.
- Use `AerSimulator` or another supported local simulator.
- Transpile for the selected simulator before execution.
- `backend.run()`-style execution is permitted only when the receiver is a
  clearly local simulator backend.
- Report `REAL_QPU` or `SIMULATOR` and the fallback reason.

## Design and code rule

Every quantum design and implementation must state and follow the isolated
qiskit-v2x-env contract, Qiskit 2.5+, Open Plan no-Session rule, Paid Plan
Session rule, simulator fallback rule, and real-QPU backend.run() prohibition.
Design documents must contain textual instructions only, not executable Python.

## Hello World rule

For `Run Hello World`, `run hello-world`, `run hellow-world`, `run Qiskit Hello
World`, or equivalent wording, immediately inspect:

`<BQCA-root>/bob-quantum-store/test`

Run an existing matching Python file or notebook through qiskit-v2x-env. Do not
search the obsolete project-root `/test` location.

## Completion gates

Before reporting generated code complete:

```bash
.bob/quantum-tools/qca-code-quality-guard.sh --prepare <file.py>
```

Before reporting a generated design complete:

```bash
.bob/quantum-tools/qiskit-connector.sh --validate-design <file.md>
```

Validation failures are blocking.
<!-- BQCA-QISKIT-EXECUTION-v39-update-1:END -->
