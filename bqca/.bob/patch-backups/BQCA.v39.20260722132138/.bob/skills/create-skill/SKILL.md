---
name: create-skill
description: Use when the user wants to create or refine a reusable Bob custom skill; validates scope, name, frontmatter, supporting files, and workspace/global placement.
---

# Create Skill

Step 0 — Decide Whether a Skill Is the Right Fit
Before gathering requirements, apply judgment — a good skill is small, focused, and reusable, and
not every request should become one. Evaluate these, and push back on the user where they don't hold:

Is a skill even the right tool? Skills are for recurring, procedural workflows that benefit from self-activation. A one-off task, or something the model already handles well unprompted, does not need a skill. If a mode (persona + tool permissions) or just a well-worded prompt fits better, say so.
Is it one focused capability? Each skill should do one thing well. If the request spans several distinct workflows, propose splitting it into smaller skills that compose, rather than one sprawling skill.
Is it the right size? A skill that balloons into hundreds of lines of branching instructions is a sign the scope is wrong. Keep the body tight and procedural; move bulky reference material into supporting files (see Step 4 notes) instead of inlining everything.
Raise these concerns with the user now — do not silently scaffold an over-scoped or unnecessary skill.

Step 1 — Gather Requirements
Use the ask_followup_question tool to understand the skill before writing anything:

What should the skill do? What task or workflow does it guide the model through?
When should it activate? What user phrasing or situation should trigger it? (This becomes the description — the single most important field.)
Scope: Global (available in every workspace) or workspace (only this project)?
Invocation: By default a skill is both a /<skill-name> command and auto-invoked by Bob whenever its description matches — this is almost always what you want, so it needs no config. The only choice worth raising: should it instead run only when the user explicitly types /<skill-name> (no auto-invocation)? That maps to the "Allow Bob to use this skill" toggle (metadata.disable-model-invocation, see Step 3).
If the answers reveal the skill is really several workflows, return to Step 0 and propose splitting
it before continuing.

Step 2 — Choose and Validate the Name
The canonical name comes from the directory that contains SKILL.md, and the directory name
must match:

^[a-z0-9]+(-[a-z0-9]+)*$        (lowercase, digits, single dashes between words)   max 64 chars

⚠️ Validation is silent. An invalid name (uppercase, underscores, spaces, leading/trailing or
doubled dashes) causes the skill to be skipped with no error. Confirm the final name with the
user before writing.

Step 3 — Draft the Frontmatter and Body
A normal skill needs only two frontmatter fields: name and description. That's it — keep it
simple.

---
name: security-review
description: Use when the user wants to review a PR for security issues — walks through auth, input validation, and secrets handling.
---

# Security Review

Follow these steps to review the pull request...

name — match the directory name. (It's technically inferred from the directory, but writing it explicitly is the convention.)
description — the trigger. This is what drives auto-activation, so write it with concrete trigger phrases ("Use when the user wants to…"), not vague intent. If omitted, the first body line is used as a fallback, but an explicit description is much better.
The body is the procedural content the model follows when the skill activates. Write it like the
create-plan skill: clear, step-numbered, and naming the actual Bob tools to use
(ask_followup_question, write_file, etc.).

Optional: advanced metadata fields
Most skills need none of these — the default (both a / command and auto-invoked by Bob) is
usually right. Add a metadata: block only to change that:

Field	Default	Notes
metadata.disable-model-invocation	false	true ⇒ Bob will not auto-invoke it; it runs only when the user types /<skill-name>. This is the "Allow Bob to use this skill" toggle in settings.
metadata.argument-hint	—	Autocomplete hint shown after /skill-name, e.g. "[issue-number]".
metadata.user-invocable	true	Advanced: false ⇒ agent-only (no / command), but Bob can still auto-invoke it. Rarely wanted for user skills; this is how built-ins like create-plan work.
Step 4 — Decide Whether Supporting Scripts Are Needed
Before writing any files, evaluate whether the skill's workflow involves steps that are better
handled by a script than by Bob reasoning through them freeform each time.

Reach for a supporting script when the skill needs to:

Fetch or transform data from an external source (APIs, databases, files)
Parse structured output into a consistent format (JSON, CSV, XML)
Run a sequence of shell commands and return a single clean result
Generate boilerplate or scaffolding from a template
Perform any logic where free-form model reasoning would produce inconsistent results
Keep it in prose instructions when:

The steps are simple, linear, and tool-call based
The output is open-ended (summaries, explanations, plans)
There is no external data to fetch or process
If a script is warranted, write it alongside SKILL.md in the same skill directory. The
SKILL.md body should then instruct Bob to run the script using execute_command and act on its
output, rather than trying to replicate the logic in natural language.

A script can be in any language the user's system supports — shell, Python, Node.js, etc. Keep it
focused: one script, one responsibility. If the skill needs multiple distinct data-gathering steps,
prefer multiple small scripts over one large one.

Example layout:

.bob/skills/my-skill/
  SKILL.md          ← procedural instructions that call the script
  fetch-data.sh     ← does the programmatic work, prints structured output

Step 5 — Write the Files
Place SKILL.md in a directory named exactly after the skill. Use the write_file tool. Write
any supporting scripts to the same directory in the same step.

Always default to the .bob folder. It's the canonical Bob location and makes onboarding
straightforward for new users:

Global:    ~/.bob/skills/<skill-name>/SKILL.md
Workspace: .bob/skills/<skill-name>/SKILL.md

Only use .agents or .claude instead if the user's workspace clearly shows they are already
working in that ecosystem (e.g. an existing .agents/ or .claude/ directory with content).
Never mention or suggest these alternatives unprompted — the goal is a smooth first-run experience,
not a folder-choice decision for someone just getting started.

If the user does use an alternative root, the precedence order is .bob > .agents > .claude, and the
same sub-path applies: <root>/skills/<skill-name>/SKILL.md.

Step 6 — Confirm
Tell the user the skill will be available in the next task — start a new conversation to use it.
If it does not appear, the most likely cause is an invalid name (Step 2); re-check the name against
the regex.

Notes for power users
First-wins deduplication by name: workspace > global > builtin. A workspace skill silently overrides a global one with the same name.
Grouped skills: a skill may live one level deeper inside a "group" folder (skills/<group>/<skill-name>/SKILL.md). The name still comes from the immediate parent directory, not the group folder. Useful for organizing many related skills.
Supporting files: any file placed alongside SKILL.md is available to the skill at activation time — scripts, static reference data, templates, etc.
Reminders
Always ask questions using the ask_followup_question tool.
Confirm the final name and scope with the user before writing.
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
