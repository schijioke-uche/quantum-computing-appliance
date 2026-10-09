# Qiskit Hello World Design

This template is authorized only when the user explicitly requests a Hello
World design or executable.

## BQCA Qiskit 2.5+ Home Environment and Plan Policy

Use `$HOME/qiskit-v2x-env`, activate it with
`source "$HOME/qiskit-v2x-env/bin/activate"`, and require Qiskit 2.5 or later.
Never use or create a project-local qiskit-v2x-env. All Qiskit version checks,
installs, upgrades, uninstalls, and pip operations occur exclusively inside the
activated home qiskit-v2x-env.

Treat create, implement, write, generate, build, develop, produce, scaffold,
construct, code, program, modify, update, repair, fix, refactor, complete, or
execute as CODE intent when the object is this explicit Qiskit executable.

For this explicit Hello World request only, inspect
`<BQCA-root>/bob-quantum-store/test` for an existing matching Python file or
notebook and execute it through the activated home environment.

### Open Plan execution

When Open Plan and an eligible real QPU are detected, use
`SamplerV2(mode=backend)` without Session.

### Paid Plan execution

When Paid Plan and an eligible real QPU are detected, use
`Session(backend=backend)` with `SamplerV2(mode=session)` or
`EstimatorV2(mode=session)`.

### Simulator fallback

Use controlled try/except, `transpile`, and `AerSimulator` when real hardware is
unavailable. `backend.run()` is permitted only for a local simulator and is
prohibited on real QPU hardware.

The artifact must be named or titled as Hello World so the v41 scope validator
recognizes that this is the authorized exception.

<!-- BQCA-CANONICAL-PRODUCTION-POLICY-v47:BEGIN -->
The sole active policy is `.bob/BQCA-PRODUCTION-POLICY.md` (v47). Direct execution must stream complete stdout/stderr live and write the exact professional report to `<source-stem>-result-output.txt` and `output.txt` beside the source. A real-QPU result places the actual Job ID on line one. Direct contract gaps are recorded as warnings; formal orchestration is explicit opt-in.
<!-- BQCA-CANONICAL-PRODUCTION-POLICY-v47:END -->
