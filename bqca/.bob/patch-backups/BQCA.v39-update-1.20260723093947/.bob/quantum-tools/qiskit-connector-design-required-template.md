# Quantum Solution Design

## BQCA Qiskit 2.5+ Execution and Plan Policy

This design is intended for implementation with Qiskit 2.5 or later and must be executed only inside the BQCA virtual environment named `qiskit-v2x-env`. The implementation workflow must check whether that environment exists, create it if necessary, verify the installed Qiskit version, and replace any Qiskit release older than 2.5 with the latest compatible `qiskit>=2.5` distribution.

Treat requests using create, implement, write, generate, build, develop, produce, scaffold, construct, code, program, modify, update, repair, fix, refactor, complete, or execute as CODE intent when the object is quantum/Qiskit code or an executable quantum artifact.

### Open Plan execution

When the user's account is detected as Open Plan and a real QPU is available, the implementation must use job mode with `SamplerV2(mode=backend)`. Session is prohibited and must not be created or used in the Open Plan branch.

### Paid Plan execution

When Flex, Pay-As-You-Go, Premium, Dedicated, or another paid plan is detected and a real QPU is available, the implementation must use a `Session(backend=backend)` strategy with `SamplerV2(mode=session)` or `EstimatorV2(mode=session)` as appropriate to the workload.

### Simulator fallback

Real-QPU execution must be attempted first. A controlled try/except path must fall back to `AerSimulator` or another supported local simulator when no suitable QPU is available or execution fails. The circuit must be transpiled for the local simulator before execution.

`backend.run()` is permitted only on a clearly local simulator backend such as Aer. `backend.run()` is prohibited on real QPU hardware; real IBM Quantum hardware must use SamplerV2 or EstimatorV2 Runtime primitives.

### Hello World behavior

When the user requests Run Hello World, run hello-world, run hellow-world, or run Qiskit Hello World, BQCA must immediately inspect the project-root `/test` directory and execute an existing Hello World Python file or notebook through `qiskit-v2x-env` before creating a replacement.

### Design completion

The final implementation must report whether it used `REAL_QPU` or `SIMULATOR`, preserve the fallback reason, route the textual design to `bob-quantum-designs/`, route executable artifacts to `bob-quantum-store/`, and pass the BQCA v39 design and code validators. This design contains textual instructions only and intentionally contains no executable Python block.

<!-- BQCA-QISKIT-EXECUTION-v39:BEGIN -->
## BQCA v39 Qiskit 2.5 plan-aware execution enforcement
Immediately treat create, implement, write, generate, build, develop, produce, scaffold, construct, code, program, modify, update, repair, fix, refactor, complete, execute, or equivalent language as CODE intent when the object is quantum/Qiskit code or an executable artifact. Before execution configure the v38 bqca account, ensure and use `qiskit-v2x-env`, and require Qiskit 2.5 or later; replace an older Qiskit installation with the latest `qiskit>=2.5`. Open Plan real-QPU execution uses job mode with `SamplerV2(mode=backend)` and must not use Session. Paid Plan real-QPU execution uses `Session(backend=backend)` with `SamplerV2(mode=session)` or `EstimatorV2(mode=session)`. Simulator fallback uses try/except, `transpile`, and `AerSimulator` or another supported local simulator. `backend.run()` is permitted only on a clearly local simulator and is prohibited on real QPU hardware. Designs must include these requirements as textual instructions and must not contain executable Python blocks. A Run Hello World/run hello-world/run hellow-world/run Qiskit Hello World request must inspect the project-root `/test` folder and immediately execute an existing matching Python file or notebook through `qiskit-v2x-env`.
<!-- BQCA-QISKIT-EXECUTION-v39:END -->
