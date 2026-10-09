# BQCA Qiskit Connector Mandatory Rule v34

This rule is strict, blocking, and appliance-wide. It overrides simulator-first, optional-connector, advisory, or weaker instructions.

## Default code intent

Any request using terms such as create, implement, write, generate, build, develop, produce, scaffold, construct, code, program, modify, update, repair, fix, refactor, complete, or execute is a code-producing request when the object is a quantum/Qiskit workload or artifact.

For every such Python/Qiskit file, include exactly:

```python
from qiskit_connector import QConnectorV2 as connector
from qiskit_connector import QPlanV2 as plan

current = plan()
backend = connector()
```

The first attempt MUST be real-QPU execution using the connector backend. Verify QPU availability, operational state, and qubit capacity. Only after no usable QPU is available or real execution fails may an `except` path execute `AerSimulator` or `BasicSimulator`. Simulator-first code is forbidden.

Completion is blocked until:

```bash
python3 -m py_compile <saved-file.py>
.bob/quantum-tools/qiskit-connector.sh --validate-code <saved-file.py>
```

## Default design intent

Any request using design, architect, plan, specify, model, diagram, propose, blueprint, define, or document for a quantum solution must include the section `Qiskit Connector Real-QPU-First Execution and Simulator Fallback`. The section must be textual instructions only—no executable Python and no fenced Python block. It must instruct the later code-writing mode to include the connector imports and initialization, QPU availability/capacity checks, real-QPU-first flow, try/except simulator fallback, and execution reporting.

Completion is blocked until:

```bash
.bob/quantum-tools/qiskit-connector.sh --validate-design <saved-design.md>
```

<!-- BQCA-AUTOMATIC-NOTEBOOK-v36:BEGIN -->
## Mandatory automatic notebook generation
For every request that creates, writes, implements, generates, builds, develops, scaffolds, modifies, repairs, fixes, or otherwise produces Python/quantum code, create and complete the `.py` source first. After all required source validation succeeds, automatically run `.bob/quantum-tools/notebook-generator.sh --source <ready-file.py> --force`. Validate the resulting sibling `.ipynb` with `.bob/quantum-tools/notebook-generator.sh --validate <generated-file.ipynb>` before reporting completion. Automatic generation is the default even when the user asks only for code, unless the user explicitly says not to create a notebook. Manual notebook JSON construction is allowed only after the installed generator was actually invoked and failed; report the failure reason, preserve the `.py` source, construct the notebook manually as fallback, and validate it before completion.
<!-- BQCA-AUTOMATIC-NOTEBOOK-v36:END -->

<!-- BQCA-NOTEBOOK-AUTOGEN-v37:BEGIN -->
## Enforced automatic notebook production
Automatic notebook generation is enforced by the BQCA runtime watcher and is not optional mode guidance. Whenever a `.py` implementation is created or modified under `bob-quantum-store/`, the watcher automatically generates or refreshes its sibling `.ipynb` after the source becomes stable and validates the notebook. BQCA must create the `.py` first, wait for or invoke the automatic notebook generation, and report both paths. Manual notebook creation is permitted only after a genuine automatic-generation failure.
<!-- BQCA-NOTEBOOK-AUTOGEN-v37:END -->

<!-- BQCA-QISKIT-CONFIGURATION-v38:BEGIN -->
## BQCA v38 mandatory Qiskit configuration gate
Treat `create`, `implement`, `write`, `generate`, `build`, `develop`, `produce`, `scaffold`, `construct`, `code`, `program`, `modify`, `update`, `repair`, `fix`, `refactor`, `complete`, or `execute` as a code-producing request when the object is a quantum/Qiskit workload or artifact. Before invoking qiskit_connector rules, templates, validators, generated Connector code, or backend-selection behavior, run `.bob/quantum-tools/qiskit-configuration.sh configure --quiet` and require success. The tool rebuilds `~/.qiskit/qiskit-ibm.json` from the BQCA project-root `.env`, with exactly one profile named `bqca`, and `bqca` is the only default account. qiskit_connector relies on this file for connectivity decisions. Never print the token.
<!-- BQCA-QISKIT-CONFIGURATION-v38:END -->

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
