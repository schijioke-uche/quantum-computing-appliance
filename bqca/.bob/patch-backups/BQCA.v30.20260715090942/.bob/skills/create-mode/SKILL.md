---
name: create-mode
description: Use when the user wants to create or update a Bob custom mode; gathers persona, permissions, scope, slug, YAML entry, and validation requirements.
---

# Create Mode

Step 1 — Gather Requirements
Use the ask_followup_question tool before writing anything:

Purpose & persona: What is this mode for? What role/behavior should it embody? (This becomes roleDefinition — the primary differentiator. Push for a focused, specific persona, not a generic one.)
Tool access: What should it be allowed to do — read files, edit files, run commands, use the browser, use MCP servers? (This maps to groups.)
Scope: Global (available in every workspace) or workspace (only this project)?
Display details: A human-readable name for the picker, and optionally whenToUse (tooltip) and a short description.
Step 2 — Choose and Validate the Slug
The slug is the mode's unique identifier. It must match:

^[a-zA-Z0-9-]+$        (letters, digits, and dashes only — no underscores, no spaces)

⚠️ Keep slugs unique — avoid reusing one. A duplicate slug within the same file fails schema
validation and the entire file is dropped (no modes load from it). Reusing a slug that already
exists in another scope is also best avoided — one entry will silently shadow the other. Before
writing, read the target file (Step 4) and confirm the slug isn't already taken.

Step 3 — Draft the YAML Entry
Each mode is one object under the top-level customModes array. Fields:

Field	Required	Notes
slug	✅	Unique id, regex above.
name	✅	Display name shown in the mode picker.
roleDefinition	✅	Core system prompt / persona. Where most design effort goes.
whenToUse	No	Tooltip in the mode picker.
description	No	Short description.
customInstructions	No	Appended to the system prompt after roleDefinition.
groups	No	Tool permission groups (see below). List explicitly — omitting groups gives the mode none of the grouped tools (it can't read, edit, run commands, etc.), not full access.
allowedSubagents	No	Trap: if set, restricts sub-agent spawning to only the named presets. Omit unless you specifically need that restriction.
Tool permission groups
The supported group values are:

Group	Allows
read	File reading and symbol lookup
edit	File writing and modification
execute	Shell command execution
mcp	MCP server tools
skill	use_skill tool (load skill instructions)
todo	update_todo_list tool
subagent	spawn_subagent tool
mode	switch_mode tool
A group can carry a fileRegex restriction (tuple form):

groups:
  - read
  - - edit
    - fileRegex: ".*\\.md$"   # this mode may only edit markdown files

⚠️ Use only the exact group names above. Group names are free-form strings to the schema, so an
unrecognized value (e.g. command instead of execute, or write, shell, run) is
not a validation error — the file loads fine, but that line matches no tool and silently grants
nothing. The result is a mode quietly missing a capability you thought you granted, with no error
anywhere. Double-check each group against the table; the most common slip is command for shell
access, which must be execute.

⚠️ Two validations beyond the slug rule will drop the whole file if violated: duplicate group
names are rejected, and any fileRegex must compile as a valid regular expression.

Example entry:

customModes:
  - slug: docs-writer
    name: Docs Writer
    roleDefinition: >-
      You are a technical writer who produces clear, concise documentation.
      You favor examples over prose and never edit source code.
    whenToUse: Use when writing or revising documentation.
    groups:
      - read
      - - edit
        - fileRegex: ".*\\.(md|mdx)$"

⚠️ Use plain ASCII. The loader strips problematic unicode (curly quotes " " ' ', em/en
dashes, non-breaking spaces) — copy-pasting YAML from a rich editor often introduces these. Type
straight quotes and hyphens.

Step 4 — Write the File (read-then-append)
The file's top-level key is customModes (an array). Use read_file first; if the file exists,
append your new entry to the existing customModes array and write the whole thing back with
write_file. If it doesn't exist, create it with a single-entry customModes array.

Global:    ~/.bob/settings/custom_modes.yaml   (available in all workspaces)
Workspace: .bob/custom_modes.yaml              (only when this workspace is open)

⚠️ The two scopes are not symmetric. Global modes live under a settings/ sub-directory
(~/.bob/settings/custom_modes.yaml), but workspace modes do not (.bob/custom_modes.yaml,
no settings/). Writing a global mode to ~/.bob/custom_modes.yaml puts it in a directory
nothing watches, so it silently never loads. Use the exact paths above.

Never overwrite an existing file blind — you would delete the user's other modes.

Step 5 — Confirm
Tell the user the mode appears in the mode picker immediately (hot-reload, no restart). If it
doesn't appear, the file likely failed validation and was dropped — re-check the slug regex,
slug uniqueness, group names, and any fileRegex.

Reminders
Always ask questions using the ask_followup_question tool.
Read the target file and confirm slug uniqueness before writing.
Prefer workspace scope (.bob/custom_modes.yaml) unless the user wants the mode everywhere.
Never include information without evidence.


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

