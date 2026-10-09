# IBM Bob Quantum Tools Design


## QCA Execution Output and Visualization Policy

QCA must make quantum execution observable in two ways by default: terminal output and saved PNG artifacts.

### Default artifact directory

Use the included QCA directory unless the user explicitly provides another path:

```text
bob-quantum-store/
```

Generated code should create the directory before writing files:

```python
from pathlib import Path

OUTPUT_DIR = Path(__file__).resolve().parent if "__file__" in globals() else Path.cwd() / "bob-quantum-store"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
```

For scripts saved directly inside `bob-quantum-store/`, save artifacts next to the script. For scripts executed from the appliance root, save artifacts under `bob-quantum-store/`.

### Terminal output standard

Every executable workflow should print a concise execution report, including the fields that apply:

1. Workflow name.
2. Python/Qiskit package versions when relevant.
3. Backend, simulator, or runtime service name.
4. Number of qubits, classical bits, circuit depth, and operation counts when applicable.
5. Shot count when using sampling or measurement.
6. Counts, probabilities, expectation values, energies, eigenvalues, optimizer status, or other primary results.
7. Final success/failure status.
8. Saved visualization PNG paths.

### PNG visualization standard

Every executable workflow should save at least one useful PNG artifact when a visualization is meaningful:

- Circuit workflows: save `<workflow>_circuit.png`.
- Measurement workflows: save `<workflow>_histogram.png` or `<workflow>_results.png`.
- VQE/QAOA/optimizer workflows: save `<workflow>_convergence.png`.
- Chemistry workflows: save energy/progress/result plots where applicable.
- Runtime/backend workflows: save circuit and measurement/result visualizations when available.

Use headless-safe Matplotlib behavior:

```python
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
```

Circuit drawing example:

```python
fig = circuit.draw(output="mpl")
out_path = OUTPUT_DIR / "example_circuit.png"
fig.savefig(out_path, dpi=160, bbox_inches="tight")
plt.close(fig)
print(f"Saved visualization: {out_path}")
```

Measurement histogram example:

```python
from qiskit.visualization import plot_histogram

fig = plot_histogram(counts)
out_path = OUTPUT_DIR / "example_histogram.png"
fig.savefig(out_path, dpi=160, bbox_inches="tight")
plt.close(fig)
print(f"Saved visualization: {out_path}")
```

Fallback plotting example when Qiskit visualization helpers are unavailable:

```python
labels = list(counts.keys())
values = [counts[key] for key in labels]
fig, ax = plt.subplots(figsize=(8, 4.5))
ax.bar(labels, values)
ax.set_xlabel("Measured bitstring")
ax.set_ylabel("Counts")
ax.set_title("Measurement results")
fig.tight_layout()
out_path = OUTPUT_DIR / "example_results.png"
fig.savefig(out_path, dpi=160, bbox_inches="tight")
plt.close(fig)
print(f"Saved visualization: {out_path}")
```

### Result discipline

Do not rely on notebook-only display behavior. Do not only call `plt.show()`. Always save PNG artifacts, print the saved path, and print the executed result summary to the terminal.



## QCA Qiskit 2.x Default Policy

QCA must default to Qiskit SDK version 2.x or later for newly generated Python/Qiskit code unless the user explicitly requests legacy compatibility.

Operational standards:

1. Prefer current Qiskit 2.x primitives and APIs for circuit execution, sampling, estimation, transpilation, and results handling.
2. Use `qiskit_algorithms` for supported algorithm workflows such as VQE, QAOA, eigensolvers, optimizers, time evolution, phase estimation, and amplitude estimation.
3. Use `qiskit_ibm_runtime` for IBM Quantum Runtime workflows and ask before submitting jobs that may consume quota or cost.
4. Use `qiskit_aer` explicitly when Aer simulation is required; do not assume Aer is bundled into the base `qiskit` namespace.
5. Avoid deprecated pre-2.x patterns unless the user explicitly requests legacy compatibility.
6. Include a lightweight environment check such as printing Python, Qiskit, qiskit_algorithms, qiskit_ibm_runtime, qiskit_aer, or qiskit_connector versions when relevant.
7. Keep generated code deterministic and executable, preferably with a `main()` function and clear run instructions.
8. Use `.env` or runtime environment variables for IBM Quantum credentials and never hardcode tokens.

Recommended Qiskit 2.x dependency check pattern:

```python
import importlib.metadata as metadata

for package in ["qiskit", "qiskit-algorithms", "qiskit-ibm-runtime", "qiskit-aer"]:
    try:
        print(f"{package}: {metadata.version(package)}")
    except metadata.PackageNotFoundError:
        print(f"{package}: not installed")
```


This Quantum Computing Agent uses IBM Bob tool categories as follows:

- Read tools: inspect Qiskit files, quantum circuits, operator definitions, result artifacts, runtime logs, and generated notebooks or scripts.
- Write tools: create and update `.py`, `.ipynb`, `.md`, `.json`, `.env.example`, circuit diagrams, result notes, and support files under the active quantum workspace.
- Command tools: run Python and Qiskit environment checks, execute deterministic quantum simulations, run Qiskit scripts, inspect package versions, and validate generated artifacts.
- MCP tools: connect to approved local or remote MCP servers for quantum documentation, Qiskit package intelligence, IBM Quantum workflow helpers, and repository/tool discovery when configured by the user.
- Mode tools: use the active QCA modes for quantum ask, code, plan, orchestrator, advanced, intelligence, Draw.io, GraphQL Dev, WXO Agent Architect, and Qiskit connector work when appropriate.
- Question tools: request missing backend, IBM Quantum instance, target simulator, molecule/system definition, qubit count, circuit depth, shot count, optimization objective, or safety confirmation before proceeding.

## Quantum command safety

Do not run destructive commands, credential writes, account overwrites, paid runtime jobs, or long-running hardware submissions unless the user explicitly requests the action.

Prefer local deterministic validation first:

1. Check Python version and executable path.
2. Check whether the Qiskit environment is already active.
3. Prefer `source ~/qiskit-v2x-env/bin/activate` when a Python, Qiskit, or quantum environment is requested.
4. If activation fails, use the approved setup path from the quantum-computing-qiskit-tool-wizard repository.
5. Test with an available Qiskit script or a minimal Bell-state circuit before claiming the environment is ready.
6. Save generated code before reading or verifying it.
7. Verify output paths and summarize run commands.

## Quantum Qiskit Connector

Use Quantum Qiskit Connector when the task requires plan-aware IBM Quantum/Qiskit Runtime access, backend discovery, backend selection, environment onboarding, or machine-readable runtime helper output.

Primary package:

- https://pypi.org/project/qiskit-connector

Recommended usage pattern:

- Check whether `qiskit-connector` is installed before using it.
- Prefer environment variables and `.env` for secrets; do not hardcode IBM Quantum tokens.
- Identify the user plan, instance, channel, and target backend before runtime execution.
- Prefer deterministic backend selection when the user has not chosen a backend.
- Return machine-readable backend, plan, job, and health-scan summaries when available.
- Treat hardware runtime execution as explicit-user-request only.

## Qiskit Algorithms

Use Qiskit Algorithms documentation for VQE, QAOA, eigensolvers, optimizers, time evolution, amplitude estimation, phase estimation, and variational algorithm workflows.

Reference:

- https://qiskit-community.github.io/qiskit-algorithms/apidocs/qiskit_algorithms.html#

Operational guidance:

- Use `qiskit_algorithms` for algorithm classes when available.
- Pin or report package versions when behavior depends on API version.
- For VQE/QAOA workflows, clearly separate ansatz, operator/Hamiltonian, optimizer, estimator/sampler primitive, initial point, and result interpretation.
- For molecular simulation, state whether the Hamiltonian is physically derived or a toy/simplified SparsePauliOp model.
- Do not overstate chemical accuracy for heavy elements or simplified active spaces.

## Core IBM Quantum documentation

Use these references for IBM Quantum platform, API, and cloud setup work:

- IBM Quantum Documentation Home: https://quantum.cloud.ibm.com/docs
- IBM Quantum API References: https://quantum.cloud.ibm.com/docs/api
- IBM Quantum Services / Compute Services: https://quantum.cloud.ibm.com/docs/guides/compute-services
- IBM Quantum REST API Setup: https://quantum.cloud.ibm.com/docs/en/guides/cloud-setup-rest-api

## Qiskit documentation

Use these references for Qiskit SDK, tools, product guidance, and source documentation:

- Introduction to Qiskit: https://quantum.cloud.ibm.com/docs/guides/tools-intro
- Qiskit SDK API Reference: https://quantum.cloud.ibm.com/docs/api/qiskit
- IBM Qiskit Product Page: https://www.ibm.com/quantum/qiskit
- Qiskit Documentation GitHub Repository: https://github.com/Qiskit/documentation

## Qiskit Runtime documentation

Use these references for IBM Quantum Runtime client and REST workflows:

- Qiskit Runtime Client API: https://quantum.cloud.ibm.com/docs/en/api/qiskit-ibm-runtime
- QiskitRuntimeService API: https://quantum.cloud.ibm.com/docs/en/api/qiskit-ibm-runtime/qiskit-runtime-service
- Qiskit Runtime REST API: https://quantum.cloud.ibm.com/docs/api/runtime
- Runtime Service API Module: https://quantum.cloud.ibm.com/docs/api/qiskit-ibm-runtime/runtime-service

## Learning and tutorials

Use these references for guided learning, examples, and conceptual explanation:

- IBM Quantum Learning: https://qiskit.qotlabs.org/learning
- IBM Quantum / Qiskit Guides: https://qiskit.qotlabs.org/

## Specialized and community package documentation

Use these references for specialized quantum machine learning and community package work:

- Qiskit Machine Learning: https://qiskit-community.github.io/qiskit-machine-learning/

## IBM Bob MCP guidance for quantum tooling

When MCP is requested or useful, prefer safe local STDIO tools first and remote transports only when explicitly configured.

IBM Bob MCP references:

- Understanding MCP: https://bob.ibm.com/docs/ide/configuration/mcp/understanding-mcp
- MCP server transports: https://bob.ibm.com/docs/ide/configuration/mcp/server-transports

Recommended QCA MCP server use cases:

- Local Qiskit environment inspection.
- Local package/version inventory.
- IBM Quantum documentation lookup helpers.
- Backend catalog and status helpers.
- Quantum circuit validation helpers.
- Qiskit Runtime job/result summarization helpers.
- Draw.io quantum architecture diagram generation helpers.
- GraphQL/API schema inspection when connecting quantum services through application layers.

## Quantum workflow checklist

For every QCA-generated quantum workflow:

1. Clarify the workflow type: circuit, algorithm, runtime, chemistry, optimization, ML, API, documentation, or architecture.
2. Identify target execution: simulator, Aer, Statevector, Sampler/Estimator primitive, IBM Quantum Runtime, or hardware backend.
3. Create or update files in the requested output path before reading them.
4. Use deterministic, executable Python where practical.
5. Include package/version checks when dependencies matter.
6. Separate credentials into `.env` or runtime environment variables.
7. Avoid printing tokens, CRNs, API keys, or private instance names.
8. Run local validation when feasible.
9. Save result artifacts or explain why execution was not performed.
10. Return saved paths, summary, and exact run instructions.

## Quantum code quality standards

- Prefer `main()` entrypoints in generated Python scripts.
- Use clear function boundaries for circuit construction, backend selection, execution, and result reporting.
- Use type hints where practical.
- Avoid notebook-only code unless the user requests notebooks.
- Keep simulation examples small enough for local validation unless the user explicitly requests large workloads.
- Document assumptions for Hamiltonians, noise models, optimizer settings, and backend selection.
- For runtime jobs, show dry-run/local validation first and ask before submitting jobs that may consume quota or cost.

## QCA tool-use discipline

Use this quantum tools design as operational guidance only. It does not replace user instructions, project rules, or the active QCA skill. When instructions conflict, prefer the user's explicit request and safety constraints, then QCA skill instructions, then mode rules, then this tool guide.

## QCA Read-After-Write Artifact Policy (v${BOB_VERSION}.Q19)

When a user asks QCA to create executable quantum code, simulations, VQE examples, circuit artifacts, or result files, QCA must follow this artifact-safe workflow:

1. Resolve all generated artifacts under the included QCA code directory: `bob-quantum-store/`, unless the user explicitly provides another path.
2. Create the target Python file before attempting to read it. Never call `read_file` on a generated path until the file has been written and verified with `test -f`, `ls -l`, or an equivalent file-existence check.
3. If QCA plans to produce a results text file, create or update that results file before reading it. For generated code, use a predictable companion file such as `<script_stem>_results.txt` in `bob-quantum-store/`.
4. For requests such as `Create VQE for uranium 235 with 4 qubits`, create the requested script first, for example `bob-quantum-store/uranium_235_vqe_4qubit.py`, then execute or dry-run safely, capture terminal output, and write `bob-quantum-store/uranium_235_vqe_4qubit_results.txt` before reading or summarizing that results file.
5. Print execution results to the terminal and save durable artifacts. If execution cannot complete because an optional dependency, backend credential, simulator, or chemistry package is unavailable, write a clear results file explaining the blocker, the attempted command, and the next command to run after the dependency is available.
6. Save visualization PNG files under `bob-quantum-store/` whenever the workflow has a circuit diagram, measurement histogram, convergence chart, observable plot, or backend/result visualization. Print each saved path using `Saved visualization: <path>`.
7. Return the exact saved paths for the Python file, results text file, and any PNG visualization. Do not claim a file exists unless it has been created and verified.

## Q20 Ask-Mode Write Tool Availability Policy

When a user selects menu option 2, Quantum Assist may still be asked to create, save, execute, summarize, or visualize quantum code. QCA must treat those requests as artifact workflows, not read-only Q&A. The launchpad must provide the same safe file-creation tool access used by code-generation modes so QCA can write `.py` files, results `.txt` files, and PNG visualizations under the included `bob-quantum-store/` directory.

For prompts such as "Create VQE Barium with 7 Qubits. Save the code. Summarize what you created," QCA must create the requested code artifact first, verify that it exists, then read or summarize it. Do not claim that no write/edit tool is available when the launchpad has supplied `write_to_file`, `apply_diff`, or `insert_content`.


<!-- QCA-Q21-ASK-WRITE-TOOLS-LOCATION -->

## QCA ask-mode artifact write tool policy

This guidance belongs in `.bob/quantum-tools/README.md`, not in `bob-quantum-store/`.
The `bob-quantum-store/` directory is reserved for generated quantum code, execution result text files, and visualization PNG artifacts.

When the user asks QCA to create, save, execute, summarize, or visualize quantum code from Quantum Assist, QCA should use the active Bob write/edit tools made available by the launchpad, then verify artifacts before reading or summarizing them.

Required behavior:

1. Use Qiskit SDK 2.x or later by default unless the user explicitly requests another version.
2. Create the requested `.py` file in `bob-quantum-store/` before any read attempt.
3. Create the corresponding result text file when execution output is requested.
4. Save PNG visualizations in `bob-quantum-store/` when the workflow includes circuits, histograms, convergence plots, measurement output, or other visual results.
5. Print terminal execution summaries and print each saved artifact path.
6. Verify each expected artifact exists with an explicit file-existence check before reading or summarizing it.
7. Do not place policy, tool notes, or Bob behavioral documentation inside `bob-quantum-store/`; keep that directory focused on generated artifacts.

## QCA-DESIGN-STORE-POLICY-v${BOB_VERSION}.Q22: QCA Design and Code Store Tool Policy

### Purpose
This tool policy separates QCA design artifacts from QCA implementation artifacts.

### Design-only default
When the prompt says `design`, `architect`, `blueprint`, `plan`, `specify`, or asks for a quantum design, QCA must create a Markdown design only. It must not write executable code unless the user explicitly asks for code.

### Design directory
All quantum designs must be saved under:

```text
bob-quantum-designs/<normalized-design-name>/<descriptive-design-name>.md
```

Example:

```text
bob-quantum-designs/nitrogen-vqe/nitrogen-vqe-2qubit-design.md
```

### Code directory
When the user asks to create, write, generate, or implement code for a design, QCA must save generated source code under:

```text
bob-quantum-store/<normalized-design-name>/<descriptive-code-name>.py
```

Example:

```text
bob-quantum-store/nitrogen-vqe/nitrogen-vqe-2qubit.py
```

### Directory normalization
Use lowercase slugs, replace spaces/underscores with hyphens, remove unsafe shell path characters, and keep names concise. Examples: `nitrogen-vqe`, `uranium-235-vqe`, `bell-state`, `qaoa-maxcut`.

### Required execution discipline
1. Determine whether the request is design-only or code-writing.
2. Create the target directory first.
3. Write the `.md` design or `.py` code file.
4. Verify the file exists before listing or reading it.
5. Report the saved path accurately.
6. Keep `bob-quantum-designs/` free of generated source code.
7. Keep generated implementation code in `bob-quantum-store/`.

## QCA-DESIGN-STORE-POLICY-v${BOB_VERSION}.Q23: QCA Design and Code Store Tool Policy

### Purpose
This tool policy separates QCA design artifacts from QCA implementation artifacts.

### Design-only default
When the prompt says `design`, `architect`, `blueprint`, `plan`, `specify`, or asks for a quantum design, QCA must create a Markdown design only. It must not write executable code unless the user explicitly asks for code.

### Design directory
All quantum designs must be saved under:

```text
bob-quantum-designs/<normalized-design-name>/<descriptive-design-name>.md
```

Example:

```text
bob-quantum-designs/nitrogen-vqe/nitrogen-vqe-2qubit-design.md
```

### Code directory
When the user asks to create, write, generate, or implement code for a design, QCA must save generated source code under:

```text
bob-quantum-store/<normalized-design-name>/<descriptive-code-name>.py
```

Example:

```text
bob-quantum-store/nitrogen-vqe/nitrogen-vqe-2qubit.py
```

### Directory normalization
Use lowercase slugs, replace spaces and underscores with hyphens, remove unsafe shell path characters, and keep names concise. Examples: `nitrogen-vqe`, `uranium-235-vqe`, `bell-state`, `qaoa-maxcut`.

### Required execution discipline
1. Determine whether the request is design-only or code-writing.
2. Create the target directory first.
3. Write the `.md` design or `.py` code file.
4. Verify the file exists before listing or reading it.
5. Report the saved path accurately.
6. Keep `bob-quantum-designs/` free of generated source code.
7. Keep generated implementation code in `bob-quantum-store/`.

## QCA-DESIGN-STORE-POLICY-v${BOB_VERSION}.Q24

### QCA design and code store directories

`bob-quantum-designs/` is the design-only workspace. Store only Markdown quantum design documents there, grouped by normalized design name.

`bob-quantum-store/` is the implementation workspace. Store generated Qiskit/Python code and implementation artifacts there, grouped by normalized design name.

### Intent routing

- Design intent: produce `.md` only under `bob-quantum-designs/<design-slug>/`.
- Code intent: produce `.py` and related implementation artifacts under `bob-quantum-store/<design-slug>/`.
- If the user says "design" and does not explicitly ask for code, do not write code.
- If the user asks to create code from an existing design, inspect the design first, then write code into `bob-quantum-store/<design-slug>/`.

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
