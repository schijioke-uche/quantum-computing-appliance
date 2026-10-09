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
## BQCA v47 Update 4 superseding execution authority
Follow `.bob/BQCA-PRODUCTION-POLICY.md`. Direct execution through `.bob/quantum-tools/bqca-direct-execution.sh` is the default for development, testing, interactive exploration, debugging, and quick experiments. It uses `$HOME/qiskit-v2x-env/bin/python` with `PYTHONUNBUFFERED=1` and `python -u`, streams combined stdout/stderr live, and creates `<source-stem>-result-output.txt` plus `output.txt` beside the source. Quantum code must attempt a real QPU first, apply the Open/Paid Plan V2 primitive rules, use controlled `transpile` plus `AerSimulator` fallback, and emit `BQCA_EXECUTION_TARGET`, `BQCA_PLAN`, `BQCA_BACKEND`, `BQCA_JOB_ID`, `BQCA_RESULT=SUCCESS` or `BQCA_RESULT=FAILURE`, and `BQCA_FALLBACK_REASON` for fallback. The orchestrator is explicit opt-in only for formal compliance, production deployment, or audit evidence. Direct-mode policy gaps are warnings that preserve the workload exit status; credential leakage is blocking. This block supersedes conflicting local execution guidance.
<!-- BQCA-CANONICAL-PRODUCTION-POLICY-v47:END -->
