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

## BQCA v42 Result Output Contract

Every execution must use `qiskit-v2x-environment.sh run` or `run-notebook`,
which invokes `qiskit-result-output.sh`. For a source workload, the runtime must
create `<code-name>-result-output.txt` in the same directory as the code or
notebook that produced it.

The report must capture the complete combined stdout and stderr, including all
Qiskit Connector output, plan and backend printout, real-QPU output, simulator
fallback printout, warnings, errors, fallback reason, and final result. It must
contain the execution date and time, duration, source, command, backend, plan,
execution target, and process exit status.

When real QPU hardware produces the final result, the actual JOB ID must be on
the first line at the top of the result file. Generated code must print
`BQCA_JOB_ID=<job-id>` after retrieving a successful real-QPU result. Simulator
execution does not require a JOB ID.

At the bottom, the file must contain a professionally formatted `RESULT
SUMMARY` that states whether execution was successful, whether the result
contract was valid, the final target, JOB ID when applicable, backend, plan,
exit status, completion date/time, duration, source, and result-file path.

### Completion

Report `REAL_QPU` or `SIMULATOR`, preserve the fallback reason, route designs to
`bob-quantum-designs/`, route executable artifacts to `bob-quantum-store/`, and
pass BQCA design, code, and v42 result-output validators. This design contains
textual instructions only and no executable Python block.

<!-- BQCA-GENERIC-WORKLOAD-TEMPLATE-v41:BEGIN -->
This generic template contains only workload-specific validation. Do not add
unrelated smoke-test scaffolding, examples, or test-folder dependencies.
<!-- BQCA-GENERIC-WORKLOAD-TEMPLATE-v41:END -->

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
