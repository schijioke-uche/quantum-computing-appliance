# BQCA Qiskit 2.5 Plan-Aware Execution Policy v39, Superseded by v40 Home Environment Scope

<!-- BQCA-QISKIT-HOME-ENV-v40:BEGIN -->
## Mandatory CODE-intent classification

Treat a request as **CODE intent** immediately when the user asks to `create`,
`implement`, `write`, `generate`, `build`, `develop`, `produce`, `scaffold`,
`construct`, `code`, `program`, `modify`, `update`, `repair`, `fix`, `refactor`,
`complete`, `execute`, or otherwise produce quantum/Qiskit code or an
executable quantum artifact. Do not wait for the exact phrase "create code".

## Mandatory home-scoped Qiskit runtime

The only authorized BQCA Qiskit virtual environment is:

`$HOME/qiskit-v2x-env` (equivalent shell notation: `~/qiskit-v2x-env`).

It must never be created under the BQCA project root. When absent, create it
only with:

```bash
python3 -m venv "$HOME/qiskit-v2x-env"
```

Before Qiskit version discovery, import checks, package management, validation,
or execution, activate it with:

```bash
source "$HOME/qiskit-v2x-env/bin/activate"
```

All Qiskit checks, uninstalls, upgrades, and installations must then use the
activated environment's `python -m pip`. System/global pip, user-site Qiskit,
and project-local Qiskit environments are prohibited. A pre-existing project
`<BQCA-root>/qiskit-v2x-env` is unsupported, must be ignored, and must never be
modified by BQCA.

Qiskit 2.5 or later is required. If the environment-local Qiskit is missing or
older than 2.5, uninstall the old environment-local packages and install the
latest compatible `qiskit>=2.5` inside the activated home environment only.

## Open Plan real-QPU rule

When Open Plan and an eligible real QPU are detected, Session is prohibited.
Use job mode with `SamplerV2(mode=backend)`. Never call `backend.run()` on real
IBM Quantum hardware.

## Paid Plan real-QPU rule

When a paid plan and an eligible real QPU are detected, use
`Session(backend=backend)` with `SamplerV2(mode=session)` or
`EstimatorV2(mode=session)`. Never call `backend.run()` on real hardware.

## Simulator fallback rule

Attempt real QPU first. If unavailable or execution fails, use a controlled
`try/except` fallback with `transpile` and `AerSimulator` or another supported
local simulator. `backend.run()` is permitted only on a clearly local simulator.
Report `REAL_QPU` or `SIMULATOR` and preserve the fallback reason.

## Hello World rule

For Run Hello World, run hello-world, run hellow-world, run Qiskit Hello World,
or equivalent wording, inspect `<BQCA-root>/bob-quantum-store/test` and execute
an existing matching Python file or notebook through the activated
`$HOME/qiskit-v2x-env` environment.

## Design and code rule

Every design must describe these requirements textually. Every generated or
modified code artifact must be validated and executed through
`.bob/quantum-tools/qiskit-v2x-environment.sh`, which owns the home-scoped
activation and package-management contract.
<!-- BQCA-QISKIT-HOME-ENV-v40:END -->
