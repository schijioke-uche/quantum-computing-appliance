---
name: create-plan
description: Use when the user wants a structured implementation plan before code changes; gathers requirements, researches the codebase, writes a plan file, validates it, and guides subtask execution.
---

# Create Plan

Step 1 — Gather Requirements
Ask the user clarifying questions to fully understand the task:

What is the goal and expected outcome?
Are there constraints, preferences, or non-goals?
Which parts of the codebase are likely involved?
Any related issues or requirement documents?
Do not proceed until you have enough context to scope the work, be critical of vague intent or requirements.

Step 2 — Code Search via Sub-Agent
Spawn a spawn_subagent of type "explore" to research the codebase. The sub-agent should:

Locate relevant files, symbols, and patterns related to the task
Identify existing utilities or abstractions that should be reused
Identify existing design patterns
Surface any constraints or conventions (e.g. patterns in similar files)
Use the sub-agent's findings to ground your plan in the actual code.

Step 3 — Clarify Design Intention
Based on the requirements and code research:

Always confirm your understanding of the intended design with the user
Raise any open questions or trade-offs that need a decision
Adjust scope if the code research revealed complexity or simplifications
Do not begin writing the plan document until design intent is confirmed.

Step 4 — Write the Plan File
Write a structured plan to a markdown file (e.g. {short-plan-name}-plan.md). The plan must NOT go into low-level code detail — focus on what needs to happen and why.

The plan file must include:

Top-Level Overview
A concise summary of the goal, scope, and approach.

Sub-Tasks
Break the work into sub-tasks. Each sub-task must have:

Intent — what this sub-task achieves and why
Expected Outcomes — observable results when this sub-task is complete
Todo List — ordered, specific steps to achieve the outcome
Relevant Context — pointers to relevant files, symbols, or patterns
Status — [ ] pending (updated to [x] done after completion)
Design each sub-task to be processed independently, one at a time, so changes stay focused and reviewable.

Step 5 — Plan Validation
Before moving to implementation, ensure that the user has fully read the plan. Always ask the user targeted questions to verify the plan is correct and complete:

Does this plan capture the full scope of the task?
Are the sub-task boundaries and ordering correct?
Is any context missing that would be needed during implementation?
Use Mermaid diagrams in chat responses where they clarify architecture or workflow, but do not place Mermaid diagrams directly in the plan file. Avoid double quotes and parentheses inside square brackets in Mermaid syntax.

Refine the plan file based on the user's answers.

Step 6 — Implementation
Only after the user confirms the plan, recommend implementation by calling the switch_mode tool to agent.

When explaining how to implement the plan in agent mode:

Using the start_subtask tool, create a new task for each subtask in the <plan-file>.
In the prompt for the subtask make sure it reads the plan-file to gain the full context around the task.
After each sub task is complete update the task status in the <plan-file>
Add any context needed for the next subtask in the <plan-file>
Wait for the user to check and ok the changes before moving on to the next subtask.
Reminders
Ask questions always using the "ask_followup_question" tool
Never include information without evidence
Don't include time estimates


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
Use `.bob/BQCA-PRODUCTION-POLICY.md` as the authoritative appliance-wide
policy. Preserve the specialized intelligence of this mode, rule, skill, or tool,
but resolve routing, implementation, execution, security, and completion behavior
according to the v30 policy. Design artifacts go to `bob-quantum-designs/`;
implementation and result artifacts go to `bob-quantum-store/`. Legacy
implementation directories must never be used.
<!-- BQCA-v30-POLICY-REFERENCE-END -->

<!-- BQCA-CANONICAL-PRODUCTION-POLICY-v48:BEGIN -->
## BQCA v48 cumulative production authority
Use `.bob/BQCA-PRODUCTION-POLICY.md` as the sole active BQCA v48 policy. Direct synchronous execution through `.bob/quantum-tools/bqca-direct-execution.sh` is the default for development, testing, exploration, debugging, and quick experiments; the formal orchestrator is explicit opt-in only for compliance, deployment, or audit evidence. Preserve Qiskit Connector configuration, `$HOME/qiskit-v2x-env`, Qiskit 2.5+, Open Plan SamplerV2/EstimatorV2 job mode without Session, Paid Plan Session with the suitable V2 primitive, real-QPU-first behavior, controlled simulator fallback, automatic synchronized notebooks, request-scoped Hello World, live terminal output, `<source-stem>-result-output.txt`, `output.txt`, Job-ID-first real-QPU reports, and credential-leak blocking. For quantum DESIGN and CODE requests consult `.bob/quantum-tools/bqca-quantum-kb.sh` and the offline v48 algorithm catalog. The catalog supplements IBM Bob intelligence and never overrides the central policy. v48 incorporates core v47 and Updates 1-6; Update 6 supersedes Update 5 URL crawling.
<!-- BQCA-CANONICAL-PRODUCTION-POLICY-v48:END -->
