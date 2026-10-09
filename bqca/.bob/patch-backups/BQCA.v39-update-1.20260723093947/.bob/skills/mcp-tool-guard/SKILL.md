---
name: mcp-tool-guard
description: Use when the user asks to create, build, configure, diagnose, explain, or troubleshoot an MCP server or Bob MCP configuration, especially when documentation-search tools such as search_docs or show_sections are unavailable or failing.
---

# MCP Tool Guard

Follow this workflow for MCP server and Bob MCP configuration requests.

## 1. Do not start with documentation-search tools

Do not call `search_docs`, `show_sections`, or similar documentation-section helpers as the first step. They are not required for MCP work and can fail when a page parameter is unavailable.

## 2. Route to the correct local skill

Use local workspace skill instructions first:

- Use `.bob/skills/build-mcp-server/SKILL.md` when the user wants to design, scaffold, implement, register, or verify a custom MCP server.
- Use `.bob/skills/configure-mcp/SKILL.md` when the user wants to add, update, restrict, or diagnose Bob MCP configuration.

## 3. Ask targeted questions only when required

Collect only the missing facts needed to proceed:

- Local STDIO server or remote HTTP/SSE server.
- Preferred language/runtime, usually Node.js/TypeScript unless the user specifies otherwise.
- External API or service integration.
- Authentication model and whether secrets must be written to disk.
- Workspace or global Bob configuration scope.

## 4. Continue without search_docs/show_sections

If `search_docs` or `show_sections` is unavailable, missing, or returns an argument error, ignore that failure and continue using the local skill instructions and the user's requirements.

## 5. Preserve appliance policy

Keep the appliance-specific domain rules authoritative. MCP guidance supplements the appliance; it does not override QCA, TIA, SWA, WMA, or QVC design/store routing and safety policies.


<!-- QCA-PATCH-v20-POLICY-BLOCK-START -->

## QCA-GENERATED-CODE-QUALITY-POLICY-v${BOB_VERSION}.Q20

When the user asks QCA to execute, write, create, generate, or implement quantum code from a design or prompt, all generated code must be production-quality, syntactically correct, and executable without avoidable errors.

Mandatory behavior:

1. Generated Python code must pass syntax validation before QCA reports success.
2. After writing any `.py` implementation file, validate it with `python -m py_compile <file>` or with `.bob/quantum-tools/qca-code-quality-guard.sh --validate <file>`.
3. If syntax validation fails, repair the code silently and revalidate before reading, summarizing, or reporting the file.
4. QCA must not claim that code is complete, saved, or executable until the saved file exists and syntax validation succeeds.
5. Generated code must use explicit imports, deterministic file paths, safe output directories, and clear terminal output.
6. Generated quantum code must remain aligned with Qiskit SDK 2.x or later unless the user explicitly requests another compatibility target.
7. For quantum visualizations, generated code must save durable PNG artifacts and print clean artifact paths.
8. Errors must be minimized. User-facing output must be clean, professional, and focused on final execution results and saved artifact paths.
9. Diagnostic failures, dependency installation output, and retry logs must be written behind the scenes to `.bob/qca-code-quality.log` or an equivalent local log file.

## QCA-GENERATE-CODE-TYPES-POLICY-v${BOB_VERSION}.Q20

When the user asks QCA to execute, write, create, generate, or implement code from a design, QCA must save implementation code under:

```text
bob-quantum-store/<normalized-design-name>/
```

For every generated implementation, QCA must create two code artifact types:

```text
<descriptive-code-name>.py
<descriptive-code-name>.ipynb
```

Mandatory behavior:

1. The `.py` file is the default executable artifact because it is compatible with terminal execution and clean terminal output requirements.
2. The `.ipynb` file is the companion notebook artifact for notebook review, learning, and visual inspection.
3. The notebook must represent the same implementation as the `.py` file unless the user explicitly asks for a notebook-only or divergent notebook workflow.
4. Both files must be saved in the same `bob-quantum-store/<normalized-design-name>/` directory.
5. QCA must verify both files exist before reporting success.
6. QCA must not save generated implementation code under `bob-quantum-designs/`.
7. QCA must keep design Markdown under `bob-quantum-designs/` and executable/generated code under `bob-quantum-store/`.

## QCA-CODE-EXECUTION-POLICY-v${BOB_VERSION}.Q20

When the user requests code execution, QCA must perform a silent execution readiness process before running code.

Mandatory pre-execution sequence:

1. Silently check whether the Qiskit/Python virtual environment exists. The default environment is:

```text
~/qiskit-v2x-env
```

2. If the environment does not exist, silently create or repair it using the established Qiskit v2.x environment setup workflow and Python 3.12-compatible environment behavior.
3. Before executing generated code, inspect the generated Python file and collect the imported modules.
4. Silently verify that required imported modules are installed inside the Qiskit/Python virtual environment.
5. If any required module is missing, silently install it into the virtual environment using `uv pip install --python <venv-python> <package>` or a safe fallback equivalent.
6. Do not execute code until the environment exists, imports are resolved, and syntax validation passes.
7. Execute the `.py` artifact by default unless the user specifically requests notebook execution.
8. Do not expose raw `ModuleNotFoundError`, dependency installation noise, or avoidable stack traces to the user. Log diagnostic details behind the scenes.
9. If execution fails, repair the code or environment when possible, revalidate, and retry once before reporting a concise failure summary.
10. Use `.bob/quantum-tools/qca-code-quality-guard.sh` when available for validation, notebook generation, dependency checks, and execution readiness.

Recommended guard command pattern:

```bash
.bob/quantum-tools/qca-code-quality-guard.sh --prepare bob-quantum-store/<design>/<code>.py
.bob/quantum-tools/qca-code-quality-guard.sh --execute bob-quantum-store/<design>/<code>.py
```

<!-- QCA-PATCH-v20-POLICY-BLOCK-END -->

<!-- BQCA-v30-POLICY-REFERENCE-START -->
## BQCA Production Policy v30 — Authoritative Precedence
Use `.bob/BQCA-PRODUCTION-POLICY-v30.md` as the authoritative appliance-wide
policy. Preserve the specialized intelligence of this mode, rule, skill, or tool,
but resolve routing, implementation, execution, security, and completion behavior
according to the v30 policy. Design artifacts go to `bob-quantum-designs/`;
implementation and result artifacts go to `bob-quantum-store/`. Legacy
implementation directories must never be used.
<!-- BQCA-v30-POLICY-REFERENCE-END -->

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

<!-- BQCA-QISKIT-EXECUTION-v39:BEGIN -->
## BQCA v39 Qiskit 2.5 plan-aware execution enforcement
Immediately treat create, implement, write, generate, build, develop, produce, scaffold, construct, code, program, modify, update, repair, fix, refactor, complete, execute, or equivalent language as CODE intent when the object is quantum/Qiskit code or an executable artifact. Before execution configure the v38 bqca account, ensure and use `qiskit-v2x-env`, and require Qiskit 2.5 or later; replace an older Qiskit installation with the latest `qiskit>=2.5`. Open Plan real-QPU execution uses job mode with `SamplerV2(mode=backend)` and must not use Session. Paid Plan real-QPU execution uses `Session(backend=backend)` with `SamplerV2(mode=session)` or `EstimatorV2(mode=session)`. Simulator fallback uses try/except, `transpile`, and `AerSimulator` or another supported local simulator. `backend.run()` is permitted only on a clearly local simulator and is prohibited on real QPU hardware. Designs must include these requirements as textual instructions and must not contain executable Python blocks. A Run Hello World/run hello-world/run hellow-world/run Qiskit Hello World request must inspect the project-root `/test` folder and immediately execute an existing matching Python file or notebook through `qiskit-v2x-env`.
<!-- BQCA-QISKIT-EXECUTION-v39:END -->
