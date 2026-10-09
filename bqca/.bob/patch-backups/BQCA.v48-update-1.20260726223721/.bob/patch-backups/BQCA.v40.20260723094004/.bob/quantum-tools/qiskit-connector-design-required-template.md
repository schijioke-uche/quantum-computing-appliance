# Quantum Solution Design

## BQCA Qiskit 2.5+ Execution and Plan Policy

This design targets Qiskit 2.5 or later and must execute only inside the BQCA
virtual environment named `qiskit-v2x-env`. Every Qiskit version check, import
check, uninstall, upgrade, and installation must occur exclusively through
`qiskit-v2x-env/bin/python` and its environment-local pip. System/global Python,
system pip, and user-site packages must never inspect or modify Qiskit. Host
`python3 -m venv` may be used only to create a missing environment. A
pre-existing invalid or non-isolated environment must fail closed.

Treat create, implement, write, generate, build, develop, produce, scaffold,
construct, code, program, modify, update, repair, fix, refactor, complete, or
execute as CODE intent when the object is quantum/Qiskit code or an executable
quantum artifact.

### Open Plan execution

When Open Plan and a real QPU are detected, use job mode with
`SamplerV2(mode=backend)`. Session is prohibited in the Open Plan branch.

### Paid Plan execution

When a paid plan and real QPU are detected, use `Session(backend=backend)` with
`SamplerV2(mode=session)` or `EstimatorV2(mode=session)`.

### Simulator fallback

Attempt real QPU first. Use a controlled try/except fallback with `transpile`
and `AerSimulator` or another supported local simulator. `backend.run()` is
permitted only on a clearly local simulator and is prohibited on real hardware.

### Hello World behavior

For Run Hello World, run hello-world, run hellow-world, or run Qiskit Hello
World, inspect `<BQCA-root>/bob-quantum-store/test` and immediately execute an
existing matching Python file or notebook through `qiskit-v2x-env`. Do not use
the obsolete project-root `/test` location.

### Completion

Report `REAL_QPU` or `SIMULATOR`, preserve the fallback reason, route designs to
`bob-quantum-designs/`, route executable artifacts to `bob-quantum-store/`, and
pass BQCA design and code validators. This design contains textual instructions
only and no executable Python block.

<!-- BQCA-QISKIT-EXECUTION-v39-update-1:BEGIN -->
## BQCA v39 Update 1 isolated Qiskit execution enforcement
Treat quantum/Qiskit create, implement, write, generate, build, develop,
produce, scaffold, construct, code, program, modify, update, repair, fix,
refactor, complete, execute, or equivalent requests as CODE intent. Configure
the v38 bqca account and use only project-root `qiskit-v2x-env`. Every Qiskit
version check, import check, uninstall, upgrade, and install must run through
that environment's `bin/python` and environment-local pip. System/global Python,
pip, and user-site Qiskit are prohibited. Host `python3 -m venv` may only create
a missing environment; an invalid pre-existing environment fails closed. Qiskit
2.5+ is required. Open Plan uses `SamplerV2(mode=backend)` without Session;
paid plans use Session with SamplerV2/EstimatorV2; simulator fallback uses
try/except, `transpile`, and AerSimulator. `backend.run()` is local-simulator-only.
Designs state these rules textually. Hello World requests inspect
`bob-quantum-store/test` and execute an existing artifact through
`qiskit-v2x-env`.
<!-- BQCA-QISKIT-EXECUTION-v39-update-1:END -->
