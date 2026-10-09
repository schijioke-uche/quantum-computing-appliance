---
name: xlsx-insights
description: Use when the user asks for analysis, extraction, or insights from an Excel .xlsx workbook using workbook sampling, JSON dump, and a focused extraction script.
---

# Xlsx Insights

Content
XLSX Insights
Use this skill when the user asks for analysis, extraction, or insights from an Excel (.xlsx)
workbook. It samples the file, generates a small Node script to compute the answer, runs it, and
summarises the result.

Step 1 — Sample the Workbook
Call read_xlsx with just path to get the workbook's structure without flooding context:

read_xlsx({ path: "<workspace-relative-path>.xlsx" })

Read the tool result carefully:

Sheet names and total row counts per sheet (hidden sheets are included in the list — note them)
Headers and inferred column types for the active sheet
First ~50 sample rows
If detectedHeaderRow is present, the real headers may be on a different row — retry with header_row: <detectedHeaderRow> before proceeding. This is especially common when merged cells span the first few rows (e.g. a merged title band above the real column headers).
If sampleWarning is present, act on it before proceeding.
If formulaErrors is present, report the broken cells to the user before proceeding. A value of "#UNCALCULATED" means the formula was never computed (workbook was not saved after edits); all other values (e.g. "#DIV/0!", "#REF!", "#N/A") are live Excel formula errors. Ask the user whether to skip those cells, treat them as null, or fix the source workbook first.
If a column type is "string" but sample values look like numbers, the cells were formatted as Text in Excel. Your script must coerce them: Number(row[idx["Price"]]) || 0.
Step 2 — Confirm Intent
If the user's request is unambiguous given the schema, proceed directly to Step 3.

If the request is ambiguous (e.g. multiple sheets that could match, column names that are unclear,
or an aggregation that could be interpreted several ways), ask one focused question using
ask_followup_question before continuing. Do not ask multiple questions at once.

Step 3 — Dump the Workbook to JSON
Call read_xlsx with dump: true. Do not pass header_row — the dump auto-detects
the real header row independently for each sheet:

read_xlsx({ path: "<path>.xlsx", dump: true })

Read the manifest path from the tool result — it will look like:
.bob/tmp/xlsx-dumps/<stem>-<hash>/manifest.json

The manifest lists each sheet with its JSON file path, row count, and correct headers
(auto-detected per sheet, so a workbook where different sheets have headers on different rows
is handled automatically). The dump is content-addressed: calling again with the same file
reuses the existing dump without re-reading the workbook.

Step 4 — Write an Extraction Script
Use write_file to create a Node script inside the dump directory, alongside the data it reads:

.bob/tmp/xlsx-dumps/<stem>-<hash>/<slug>.mjs

Where <slug> is a short kebab-case description of what the script does (e.g.
revenue-by-region.mjs, overdue-invoices.mjs). Do not use a timestamp as the filename.

Keeping the script beside its data makes it self-contained and easy to re-run or hand off.

Critical rules for the script:

Use Node stdlib only — fs.readFileSync + JSON.parse. Do not import "exceljs" or any other npm package. The JSON dump was already produced by


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

<!-- BQCA-QISKIT-HOME-ENV-v40:BEGIN -->
## BQCA v40 home-scoped Qiskit environment enforcement
The only authorized BQCA Qiskit environment is `$HOME/qiskit-v2x-env`
(`~/qiskit-v2x-env`), outside the project root. When absent, create it with
`python3 -m venv "$HOME/qiskit-v2x-env"`; before Qiskit inspection, package
management, validation, or execution, activate it with
`source "$HOME/qiskit-v2x-env/bin/activate"`. Never create, use, modify,
migrate, or remove `<BQCA-root>/qiskit-v2x-env`. All Qiskit checks, uninstalls,
upgrades, and installs occur inside the activated home environment only. Qiskit
2.5+, Open Plan no-Session, Paid Plan Session, simulator fallback, Hello World,
and real-QPU `backend.run()` restrictions remain mandatory for designs and code.
<!-- BQCA-QISKIT-HOME-ENV-v40:END -->
