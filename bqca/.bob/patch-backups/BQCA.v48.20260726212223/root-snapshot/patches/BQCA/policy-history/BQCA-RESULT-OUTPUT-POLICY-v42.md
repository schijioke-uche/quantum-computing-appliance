# BQCA Governed Result Output Policy v42

<!-- BQCA-RESULT-OUTPUT-v42:BEGIN -->
Every BQCA quantum/Qiskit code or notebook execution must produce a professional
result text file beside the executed source artifact.

## Mandatory filename and location

For a source named `workload.py` or `workload.ipynb`, the mandatory result file
is:

`workload-result-output.txt`

The result file must be in the same directory as the source that produced it.
The BQCA runtime capture tool owns this filename and overwrites it atomically on
each execution.

## Mandatory captured content

The report must contain the complete combined standard output and standard error
from the workload, including all Qiskit Connector, account-plan, backend,
real-QPU, simulator, fallback, result, warning, and error output printed during
execution. It must include start and completion date/time, duration, source,
command, plan, backend, final execution target, exit status, and source digest.

Generated code must emit these canonical markers:

- `BQCA_EXECUTION_TARGET=REAL_QPU` after a successful real-QPU result is retrieved;
- `BQCA_JOB_ID=<job-id>` for real-QPU execution;
- `BQCA_EXECUTION_TARGET=SIMULATOR` for the final simulator fallback path;
- `BQCA_PLAN=<plan>`;
- `BQCA_BACKEND=<backend-name>`;
- `BQCA_RESULT=<complete-result-representation>`.

When the final target is `REAL_QPU`, the first line of the result file must be
`JOB ID: <job-id>`. A real-QPU execution that does not expose a JOB ID is a
blocking v42 policy failure.

## Mandatory final summary

The bottom of the file must contain a clearly formatted `RESULT SUMMARY`
section stating whether execution was successful, whether the result contract
was compliant, the final target, JOB ID when applicable, backend, plan, exit
status, completion date/time, duration, source path, and result-file path.

## Runtime enforcement

All BQCA code execution must use `.bob/quantum-tools/qiskit-v2x-environment.sh
run` or `run-notebook`. These commands activate `$HOME/qiskit-v2x-env`, validate
the source, and invoke `.bob/quantum-tools/qiskit-result-output.sh`. Manual
result-file assembly is not the default and must not replace the v42 capture
path.

Design documents must state this result-output contract textually. Generated
code must print the canonical markers and complete result representation. All
designs, code, and result reports must pass the v42 validator before BQCA
reports completion.
<!-- BQCA-RESULT-OUTPUT-v42:END -->
