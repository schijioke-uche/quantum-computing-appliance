# Quantum Solution Design

## BQCA Qiskit 2.5+ Home Environment and Plan Policy

This design targets Qiskit 2.5 or later. The only authorized runtime virtual
environment is `$HOME/qiskit-v2x-env` (equivalent: `~/qiskit-v2x-env`). It must
not be created inside the BQCA project root.

If absent, create the environment with `python3 -m venv "$HOME/qiskit-v2x-env"`.
Before Qiskit version checks, package operations, validation, or execution,
activate it with `source "$HOME/qiskit-v2x-env/bin/activate"`. All Qiskit
version discovery, uninstalls, upgrades, and installations occur exclusively
inside the activated home qiskit-v2x-env using `python -m pip`. System/global
pip, user-site Qiskit, and a project-local qiskit-v2x-env are prohibited.

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

### Completion

Report `REAL_QPU` or `SIMULATOR`, preserve the fallback reason, route designs to
`bob-quantum-designs/`, route executable artifacts to `bob-quantum-store/`, and
pass BQCA design and code validators. This design contains textual instructions
only and no executable Python block.

<!-- BQCA-GENERIC-WORKLOAD-TEMPLATE-v41:BEGIN -->
This generic template contains only workload-specific validation. Do not add
unrelated smoke-test scaffolding, examples, or test-folder dependencies.
<!-- BQCA-GENERIC-WORKLOAD-TEMPLATE-v41:END -->
