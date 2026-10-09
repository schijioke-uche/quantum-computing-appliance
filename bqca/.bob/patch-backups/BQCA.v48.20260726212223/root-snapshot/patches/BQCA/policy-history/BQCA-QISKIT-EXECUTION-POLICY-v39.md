# BQCA Qiskit 2.5 Plan-Aware Execution Policy v39, Superseded by v41 Hello World Scope

<!-- BQCA-HELLO-WORLD-SCOPE-v41:BEGIN -->
## Mandatory CODE-intent classification

Treat a request as **CODE intent** immediately when the user asks to `create`,
`implement`, `write`, `generate`, `build`, `develop`, `produce`, `scaffold`,
`construct`, `code`, `program`, `modify`, `update`, `repair`, `fix`, `refactor`,
`complete`, `execute`, or otherwise produce quantum/Qiskit code or an
executable quantum artifact.

## Qiskit runtime and execution policy

Use only `$HOME/qiskit-v2x-env`, activate it before Qiskit operations, and
require Qiskit 2.5 or later. Open Plan real-QPU execution uses
`SamplerV2(mode=backend)` without Session. Paid Plan real-QPU execution uses
`Session(backend=backend)` with `SamplerV2(mode=session)` or
`EstimatorV2(mode=session)`. Simulator fallback uses controlled `try/except`,
`transpile`, and `AerSimulator` or another supported local simulator.
`backend.run()` is prohibited on real hardware and is allowed only on a clearly
local simulator.

## Request-scoped Hello World rule

Hello World is **not** a universal design, code, validation, or completion
requirement. For every request that is not specifically a Hello World request:

- do not add a Hello World section, test, command, artifact, scaffold, or step;
- do not reference `bob-quantum-store/test` or a Hello World filename;
- do not execute Hello World as a pre-test, post-test, smoke test, or example;
- do not require Hello World in the generated design or code.

Only when the user explicitly requests a Hello World design or executable may
BQCA use the existing request-scoped shortcut and artifacts under
`bob-quantum-store/test`. An explicit Hello World artifact must be named or
titled as Hello World so the v41 validators can recognize its authorized scope.

Every generic design uses textual Qiskit policy instructions only and contains
no Hello World content. Every generic code artifact must pass the v41 scope
validator before completion.
<!-- BQCA-HELLO-WORLD-SCOPE-v41:END -->
