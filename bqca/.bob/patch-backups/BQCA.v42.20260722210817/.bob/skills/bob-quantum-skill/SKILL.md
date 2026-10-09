---
name: bob-quantum-skill
description: Specialized workflow for IBM Bob Quantum Computing Intelligence tasks including Qiskit code generation, quantum circuit design, molecular simulation, VQE, saved code artifacts, configuration of qiskit_connector, and file verification.
---

# IBM Bob Quantum Skill

Use this skill when the request involves quantum computing, Qiskit, IBM Quantum, quantum circuit design, qiskit_connector, VQE, QAOA, QPE, molecular simulation, quantum chemistry, or saving generated quantum code.

<Steps>


<Step>
QCA Execution Output and Visualization Policy: For every generated executable quantum workflow, include terminal print statements that show the executed result summary and save visualization PNG files under the included `bob-quantum-store/` directory by default. Generated code must create the output directory, save circuit/results/algorithm visualizations as PNG, print each saved path, and remain safe for headless terminal execution.
</Step>


<Step>
QCA Qiskit 2.x Default Policy: Unless the user explicitly requests an older compatibility target, write all new Qiskit code for Qiskit SDK version 2.x or later. Prefer current Qiskit 2.x primitives and package boundaries, use `qiskit_algorithms` for algorithms when available, use `qiskit_aer` imports when Aer simulation is required, and avoid legacy pre-2.x APIs such as deprecated `qiskit.opflow` or old execution helpers. Include package/version checks when Qiskit 2.x behavior matters.
</Step>

<Step>
Qiskit or python environment setup step: If the user requests that a Python, Qiskit, or quantum environment is created, first attempt to activate it by running `source ~/qiskit-v2x-env/bin/activate`. If that activation command fails, analyze `https://github.com/schijioke-uche/quantum-computing-qiskit-tool-wizard`, git clone `https://github.com/schijioke-uche/quantum-computing-qiskit-tool-wizard.git`, and follow the setup instructions from `https://github.com/schijioke-uche/quantum-computing-qiskit-tool-wizard` to install the Qiskit, Python, or quantum environment. Executing this environment setup flow should have auto approval when the user requested environment creation or repair. After creating the Python environment, if any Qiskit code is available, use it to test the environment.
</Step>
<Step>
Identify the requested quantum workflow, target language, expected output file, and target workspace directory. Prefer the included workspace directory when the user says to save code in the included directory.
</Step>

<Step>
If the user requests a saved file, create or update the target file before attempting to read or verify it. Do not call `read_file` on a path that has not been created.
</Step>

<Step>
For Qiskit code, use clear imports, executable structure, deterministic configuration where possible, comments, and a `main()` entry point when appropriate.
</Step>

<Step>
For molecular simulation and VQE, state practical package assumptions in code comments, separate molecule/ansatz/optimizer/simulation setup, and avoid pretending that heavy-element chemistry is trivial.
</Step>

<Step>
After creating the file, verify it by listing the exact output path or running a safe command such as `test -f <path>` before reading the file content.
</Step>

<Step>
Return the final saved path, a concise summary of what was created, and any run instructions.
</Step>


<Step>
QCA Read-After-Write Artifact Policy (v${BOB_VERSION}.Q19): For every request that creates executable quantum code, a VQE workflow, circuit artifact, simulation, or result file, first create the target file in `bob-quantum-store/` unless the user provides another path. Never call `read_file` on a generated Python file or generated results file until the file has been written and verified with `test -f`, `ls -l`, or an equivalent command. Use a predictable companion results file named `<script_stem>_results.txt`. Print execution output to the terminal, write durable output into the results file, save applicable PNG visualizations under `bob-quantum-store/`, and print each saved path.
</Step>

</Steps>

## Q20 Ask-Mode Write Tool Availability Policy

When a user selects menu option 2, Quantum Assist may still be asked to create, save, execute, summarize, or visualize quantum code. QCA must treat those requests as artifact workflows, not read-only Q&A. The launchpad must provide the same safe file-creation tool access used by code-generation modes so QCA can write `.py` files, results `.txt` files, and PNG visualizations under the included `bob-quantum-store/` directory.

For prompts such as "Create VQE Barium with 7 Qubits. Save the code. Summarize what you created," QCA must create the requested code artifact first, verify that it exists, then read or summarize it. Do not claim that no write/edit tool is available when the launchpad has supplied `write_to_file`, `apply_diff`, or `insert_content`.

## QCA-DESIGN-STORE-POLICY-v${BOB_VERSION}.Q22: QCA Design and Code Store Routing

When a user asks QCA to design a quantum workflow, circuit, algorithm, experiment, VQE/QAOA/QPE workflow, or quantum architecture, QCA must treat the request as a design-only task by default. Design-only tasks must produce Markdown documentation only and must not create executable code unless the user explicitly asks to write, create, generate, or implement code.

Required directories:
- `bob-quantum-designs/` stores design documentation only.
- `bob-quantum-store/` stores generated source code and implementation files.

Design artifact rule:
- Save each design as `.md` only.
- Save each design under `bob-quantum-designs/<normalized-design-name>/<descriptive-design-name>.md`.
- Example: `bob-quantum-designs/nitrogen-vqe/nitrogen-vqe-2qubit-design.md`.

Code artifact rule:
- Save generated Qiskit/Python source code under `bob-quantum-store/<normalized-design-name>/<descriptive-code-name>.py`.
- Example: `bob-quantum-store/nitrogen-vqe/nitrogen-vqe-2qubit.py`.
- Do not place generated code in `bob-quantum-designs/`.

Operational rule:
- Create directories before list/read operations.
- Write the requested file first, verify it exists, then summarize the saved path.
- Preserve the existing QCA Qiskit 2.x-or-later policy and visualization/output policies when implementation code is requested.

## QCA-DESIGN-STORE-POLICY-v${BOB_VERSION}.Q23: QCA Design and Code Store Routing

QCA must separate design artifacts from implementation artifacts.

Default design behavior:
- If the user asks to design, architect, blueprint, plan, or specify a quantum solution, QCA must create only Markdown design documentation.
- QCA must not write executable Qiskit/Python code for a design-only request unless the user explicitly asks to write, create, generate, or implement code.

Required directories:
- `bob-quantum-designs/` stores design documentation only.
- `bob-quantum-store/` stores generated Qiskit/Python implementation code.

Design artifact rule:
- Save each design as `.md` only.
- Save each design under `bob-quantum-designs/<normalized-design-name>/<descriptive-design-name>.md`.
- Example: `bob-quantum-designs/nitrogen-vqe/nitrogen-vqe-2qubit-design.md`.

Code artifact rule:
- Save generated source code only under `bob-quantum-store/<normalized-design-name>/<descriptive-code-name>.py`.
- Example: `bob-quantum-store/nitrogen-vqe/nitrogen-vqe-2qubit.py`.
- Do not place generated code in `bob-quantum-designs/`.

Operational rule:
- Create directories before list/read operations.
- Write the requested file first, verify it exists, then summarize the saved path.
- Preserve the existing QCA Qiskit 2.x-or-later, terminal-output, PNG-visualization, and read-after-write policies when implementation code is requested.

## QCA-DESIGN-STORE-POLICY-v${BOB_VERSION}.Q24

QCA design/store routing policy:
- `bob-quantum-designs/` is the only directory for quantum design documents.
- `bob-quantum-store/` is the only directory for implementation code generated from designs or code-writing requests.
- If the user says to design a quantum workflow, circuit, VQE, QAOA, QPE, algorithm, experiment, architecture, integration, or system, QCA must produce design only unless the user explicitly asks to write or create code.
- Design-only output must be a Markdown file only and must be saved as `bob-quantum-designs/<normalized-design-name>/<descriptive-design-name>.md`.
- If the user asks to write, create, generate, implement, or code a design, QCA must save Qiskit/Python code under `bob-quantum-store/<normalized-design-name>/<descriptive-code-name>.py`.
- Do not put generated source code in `bob-quantum-designs/`.
- Do not put design-only Markdown in `bob-quantum-store/`.
- Create the target directory before writing files. Verify each reported file exists before reading, listing, summarizing, or claiming it was created.
- Use lowercase directory slugs: replace spaces and underscores with hyphens, remove unsafe path characters, and keep names concise.
- Example design request: `Design Nitrogen VQE with 2 qubits` saves to `bob-quantum-designs/nitrogen-vqe/nitrogen-vqe-2qubit-design.md`.
- Example code request: `Create code for Nitrogen VQE with 2 qubits` saves to `bob-quantum-store/nitrogen-vqe/nitrogen-vqe-2qubit.py`.

## PLAN-MODE-WRITE-TOOLS-POLICY-v${BOB_VERSION}.Q25

QCA Plan mode must be write-enabled for planning artifacts, design Markdown, implementation scaffolds, and generated project files when the user asks to create, save, write, update, or modify files.
The plan custom mode must include an edit group with fileRegex .* so write_to_file, apply_diff, and insert_content can be used when those tools are also allowed by the launchpad.
Do not stop with 'write_to_file is not available in plan mode' for artifact creation workflows. Use the write/edit tools available to the session, create directories before listing them, write files before reading them, and verify every path before reporting success.


<!-- BEGIN IBM BOB SHARED CUSTOM SKILLS POLICY v${BOB_VERSION}.Q26 -->
## Shared Custom Skills Policy

This appliance can reference and use the workspace-scoped skills installed under `.bob/skills/` when the user request matches the skill purpose:

- `/create-plan` for structured planning before implementation.
- `/create-skill` for reusable Bob skill creation.
- `/create-mode` for custom mode creation and validation.
- `/configure-mcp` for MCP server setup or diagnosis.
- `/build-mcp-server` for custom MCP server design and scaffolding.
- `/xlsx-insights` for Excel workbook analysis and extraction.
- `/git-version-control` for Git command, workflow, branching, recovery, and release guidance.

Use the relevant skill before ad-hoc reasoning when a request clearly matches one of these workflows. Keep appliance-domain behavior authoritative; these shared skills supplement QCA, TIA, SWA, WMA, and QVC workflows without replacing the appliance-specific skill, rules, or route policy.
<!-- END IBM BOB SHARED CUSTOM SKILLS POLICY v${BOB_VERSION}.Q26 -->

<!-- BEGIN IBM BOB MCP TOOL GUARD POLICY v${BOB_VERSION}.Q27 -->
## MCP Tool Guard Policy

When the user asks to create, build, configure, diagnose, or explain an MCP server, do not call `search_docs`, `show_sections`, or any documentation-search helper first. Those helpers are not required for MCP server work and may fail when a page parameter is missing.

Use the local workspace skills and files instead:

1. Prefer `.bob/skills/build-mcp-server/SKILL.md` for custom MCP server design, scaffolding, implementation, registration, and verification.
2. Prefer `.bob/skills/configure-mcp/SKILL.md` for Bob MCP configuration, `.bob/mcp.json`, `~/.bob/settings/mcp.json`, local STDIO servers, remote HTTP/SSE servers, runtime checks, and diagnostics.
3. Ask only the minimum clarifying questions needed for transport, language/runtime, API/authentication needs, and workspace/global scope.
4. If documentation is needed, use local skill instructions first and ask the user for a specific external document or page before using any documentation-search tool.
5. Never fail a user-facing MCP workflow because `search_docs` or `show_sections` is unavailable or returned an argument error.

This guard applies to all appliance modes. It supplements, and does not replace, appliance-specific domain policies.
<!-- END IBM BOB MCP TOOL GUARD POLICY v${BOB_VERSION}.Q27 -->


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

<!-- BQCA-QISKIT-CONNECTOR-ENFORCEMENT-v32-START -->

## BQCA-QISKIT-CONNECTOR-ENFORCEMENT-v32

For every generated or modified Python/Qiskit implementation, the following is mandatory and overrides weaker or older instructions:

- Include the exact imports `from qiskit_connector import QConnectorV2 as connector` and `from qiskit_connector import QPlanV2 as plan`.
- Execute `current = plan()` and `backend = connector()` in a real-QPU-first try/except path.
- Verify QPU availability, operational state, and qubit capacity before real execution.
- Immediately fall back to an executable simulator path when real-QPU execution is unavailable or fails.
- Run `.bob/quantum-tools/qiskit-connector.sh --validate-code <saved-file.py>` before reporting completion.
- Repair any failure and repeat validation. Simulator-only Qiskit code is not acceptable.

<!-- BQCA-QISKIT-CONNECTOR-ENFORCEMENT-v32-END -->

<!-- BQCA-QISKIT-CONNECTOR-STRICT-v33-START -->

## BQCA-QISKIT-CONNECTOR-STRICT-v33

This is a blocking policy and overrides weaker instructions.

- Classify create/implement/write/generate/build/develop/produce/scaffold/construct/code/program/modify/update/repair/fix/refactor/complete/execute requests for quantum artifacts as CODE intent.
- Every generated or modified Qiskit Python file must include the exact `QConnectorV2 as connector` and `QPlanV2 as plan` imports, followed by `current = plan()` and `backend = connector()`.
- The first execution attempt must use the connector-selected real QPU after operational and qubit-capacity checks.
- Simulator execution is allowed only after no usable QPU exists or the real-QPU path fails, using try/except. Simulator-first code is forbidden.
- Validate saved code with `.bob/quantum-tools/qiskit-connector.sh --validate-code <file.py>` before completion.
- Classify design/architect/plan/specify/model/diagram/propose/blueprint/define/document requests as DESIGN intent.
- Every quantum design must include the Qiskit Connector real-QPU-first and simulator-fallback section and must pass `--validate-design` before completion.

<!-- BQCA-QISKIT-CONNECTOR-STRICT-v33-END -->

<!-- BQCA-QISKIT-CONNECTOR-STRICT-v34-START -->

## BQCA-QISKIT-CONNECTOR-STRICT-v34

This is a blocking policy and overrides weaker instructions.

- Classify create/implement/write/generate/build/develop/produce/scaffold/construct/code/program/modify/update/repair/fix/refactor/complete/execute requests for quantum artifacts as CODE intent.
- Every generated or modified Qiskit Python file must include the exact `QConnectorV2 as connector` and `QPlanV2 as plan` imports, followed by `current = plan()` and `backend = connector()`.
- The first execution attempt must use the connector-selected real QPU after operational and qubit-capacity checks.
- Simulator execution is allowed only after no usable QPU exists or the real-QPU path fails, using try/except. Simulator-first code is forbidden.
- Validate saved code with `.bob/quantum-tools/qiskit-connector.sh --validate-code <file.py>` before completion.
- Classify design/architect/plan/specify/model/diagram/propose/blueprint/define/document requests as DESIGN intent.
- Every quantum design must include a textual-only Qiskit Connector real-QPU-first and simulator-fallback section. Do not insert executable Python or fenced Python into a design. The design must pass `--validate-design` before completion.

<!-- BQCA-QISKIT-CONNECTOR-STRICT-v34-END -->

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
