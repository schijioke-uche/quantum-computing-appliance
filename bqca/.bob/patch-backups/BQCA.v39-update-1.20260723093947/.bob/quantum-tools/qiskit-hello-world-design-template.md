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

<!-- BQCA-HELLO-WORLD-SCOPE-v41:BEGIN -->
## BQCA v41 request-scoped Hello World enforcement
Preserve all BQCA v38-v40 configuration, Qiskit 2.5+, home-environment,
Open/Paid plan, simulator fallback, and real-hardware execution rules. Hello
World is not a universal design or code requirement. For every request that is
not explicitly a Hello World design or executable, do not add, mention,
scaffold, execute, validate, document, or require a Hello World section, test,
command, artifact, filename, example, or `bob-quantum-store/test` reference.
Only an explicit Hello World request may use the existing request-scoped
shortcut and test artifacts. Explicit Hello World artifacts must be named or
titled as Hello World. All generated designs and code must pass the v41 scope
validator before completion.
<!-- BQCA-HELLO-WORLD-SCOPE-v41:END -->

<!-- BQCA-RESULT-OUTPUT-v42:BEGIN -->
## BQCA v42 governed result-output enforcement
Every quantum/Qiskit `.py` or `.ipynb` execution must use the BQCA runtime
manager so `<source-stem>-result-output.txt` is created beside the source. The
report captures complete combined stdout/stderr, including Qiskit Connector,
plan, backend, real-QPU, simulator, fallback, warning, error, and result output;
contains date/time and duration; and ends with a professional `RESULT SUMMARY`
stating execution success. Generated code must emit the canonical target, plan,
backend, result, and real-QPU JOB ID markers. For a real-QPU result, the actual
JOB ID must be the first line at the top. Designs describe this policy textually,
and code/design/result validation is blocking before completion.
<!-- BQCA-RESULT-OUTPUT-v42:END -->

<!-- BQCA-QISKIT-EXECUTION-v39:BEGIN -->
## BQCA v39 Qiskit 2.5 plan-aware execution enforcement
Immediately treat create, implement, write, generate, build, develop, produce, scaffold, construct, code, program, modify, update, repair, fix, refactor, complete, execute, or equivalent language as CODE intent when the object is quantum/Qiskit code or an executable artifact. Before execution configure the v38 bqca account, ensure and use `qiskit-v2x-env`, and require Qiskit 2.5 or later; replace an older Qiskit installation with the latest `qiskit>=2.5`. Open Plan real-QPU execution uses job mode with `SamplerV2(mode=backend)` and must not use Session. Paid Plan real-QPU execution uses `Session(backend=backend)` with `SamplerV2(mode=session)` or `EstimatorV2(mode=session)`. Simulator fallback uses try/except, `transpile`, and `AerSimulator` or another supported local simulator. `backend.run()` is permitted only on a clearly local simulator and is prohibited on real QPU hardware. Designs must include these requirements as textual instructions and must not contain executable Python blocks. A Run Hello World/run hello-world/run hellow-world/run Qiskit Hello World request must inspect the project-root `/test` folder and immediately execute an existing matching Python file or notebook through `qiskit-v2x-env`.
<!-- BQCA-QISKIT-EXECUTION-v39:END -->
