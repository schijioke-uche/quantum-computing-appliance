---
name: qiskit-connector
description: Enforce real-QPU-first Qiskit Connector execution and mandatory simulator fallback in every BQCA code and design workflow.
---

# Qiskit Connector Skill v34

## Trigger

Invoke this skill for any quantum request that creates, implements, writes, generates, builds, develops, produces, scaffolds, constructs, modifies, repairs, fixes, refactors, executes, or otherwise creates code. Also invoke it for every quantum design, architecture, planning, specification, model, diagram, proposal, blueprint, or workflow-document request.

## Code workflow

1. Start from `.bob/quantum-tools/qiskit-connector-required-template.py`.
2. Preserve the exact Qiskit Connector imports and `current = plan()` / `backend = connector()` initialization.
3. Put real-QPU execution in the first `try` path.
4. Validate QPU operational state and qubit capacity.
5. Put simulator execution only in `except` or a post-check no-QPU branch.
6. Report execution target, account plan, backend, and fallback reason.
7. Save code under `bob-quantum-store/`.
8. Run Python compilation and `--validate-code`; repair until both pass.

## Design workflow

1. Start from `.bob/quantum-tools/qiskit-connector-design-required-template.md`.
2. Write textual architecture and implementation instructions only; do not place executable Python or fenced Python blocks in a design file.
3. State that the generated implementation must import QConnectorV2 as connector and QPlanV2 as plan and must initialize `current = plan()` and `backend = connector()`.
4. Specify plan discovery, QPU discovery, operational/capacity validation, real-QPU-first execution, and try/except simulator fallback.
5. State that simulator-first implementation is prohibited.
6. Save design under `bob-quantum-designs/`.
7. Run `--validate-design`; repair until it passes.

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
