# Custom Appliance Skills Index

This workspace includes the following shared IBM Bob skills for appliance operation:

| Skill | Purpose |
|---|---|
| create-plan | Structured planning before implementation work. |
| create-skill | Creation and validation of reusable Bob skills. |
| create-mode | Creation and validation of Bob custom modes. |
| configure-mcp | Add or diagnose MCP server configuration. |
| build-mcp-server | Build a custom MCP server for Bob tools/prompts. |
| xlsx-insights | Analyze Excel workbooks through sampling and scripted extraction. |
| git-version-control | Provide comprehensive Git command and workflow guidance. |

These skills are workspace-scoped under `.bob/skills/` and are intended to be auto-invoked when the user request matches the skill description.

## bob_quantum_skill

Alias skill for QCA generated-code quality policy, dual `.py` + `.ipynb` artifact generation, Qiskit/Python virtual environment readiness, dependency preflight, syntax validation, and clean execution behavior.

<!-- BQCA-v30-POLICY-REFERENCE-START -->
## BQCA Production Policy v30 — Authoritative Precedence
Use `.bob/BQCA-PRODUCTION-POLICY-v30.md` as the authoritative appliance-wide
policy. Preserve the specialized intelligence of this mode, rule, skill, or tool,
but resolve routing, implementation, execution, security, and completion behavior
according to the v30 policy. Design artifacts go to `bob-quantum-designs/`;
implementation and result artifacts go to `bob-quantum-store/`. Legacy
implementation directories must never be used.
<!-- BQCA-v30-POLICY-REFERENCE-END -->

<!-- BQCA-QISKIT-CONFIGURATION-v38:BEGIN -->
## BQCA v38 mandatory Qiskit configuration gate
Treat `create`, `implement`, `write`, `generate`, `build`, `develop`, `produce`, `scaffold`, `construct`, `code`, `program`, `modify`, `update`, `repair`, `fix`, `refactor`, `complete`, or `execute` as a code-producing request when the object is a quantum/Qiskit workload or artifact. Before invoking qiskit_connector rules, templates, validators, generated Connector code, or backend-selection behavior, run `.bob/quantum-tools/qiskit-configuration.sh configure --quiet` and require success. The tool rebuilds `~/.qiskit/qiskit-ibm.json` from the BQCA project-root `.env`, with exactly one profile named `bqca`, and `bqca` is the only default account. qiskit_connector relies on this file for connectivity decisions. Never print the token.
<!-- BQCA-QISKIT-CONFIGURATION-v38:END -->

<!-- BQCA-QISKIT-EXECUTION-v39:BEGIN -->
## BQCA v39 Qiskit 2.5 plan-aware execution enforcement
Immediately treat create, implement, write, generate, build, develop, produce, scaffold, construct, code, program, modify, update, repair, fix, refactor, complete, execute, or equivalent language as CODE intent when the object is quantum/Qiskit code or an executable artifact. Before execution configure the v38 bqca account, ensure and use `qiskit-v2x-env`, and require Qiskit 2.5 or later; replace an older Qiskit installation with the latest `qiskit>=2.5`. Open Plan real-QPU execution uses job mode with `SamplerV2(mode=backend)` and must not use Session. Paid Plan real-QPU execution uses `Session(backend=backend)` with `SamplerV2(mode=session)` or `EstimatorV2(mode=session)`. Simulator fallback uses try/except, `transpile`, and `AerSimulator` or another supported local simulator. `backend.run()` is permitted only on a clearly local simulator and is prohibited on real QPU hardware. Designs must include these requirements as textual instructions and must not contain executable Python blocks. A Run Hello World/run hello-world/run hellow-world/run Qiskit Hello World request must inspect the project-root `/test` folder and immediately execute an existing matching Python file or notebook through `qiskit-v2x-env`.
<!-- BQCA-QISKIT-EXECUTION-v39:END -->
