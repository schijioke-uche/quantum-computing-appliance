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
Use `.bob/BQCA-PRODUCTION-POLICY.md` as the authoritative appliance-wide
policy. Preserve the specialized intelligence of this mode, rule, skill, or tool,
but resolve routing, implementation, execution, security, and completion behavior
according to the v30 policy. Design artifacts go to `bob-quantum-designs/`;
implementation and result artifacts go to `bob-quantum-store/`. Legacy
implementation directories must never be used.
<!-- BQCA-v30-POLICY-REFERENCE-END -->

<!-- BQCA-CANONICAL-PRODUCTION-POLICY-v47:BEGIN -->
## BQCA v47 Update 4 superseding execution authority
Follow `.bob/BQCA-PRODUCTION-POLICY.md`. Direct execution through `.bob/quantum-tools/bqca-direct-execution.sh` is the default for development, testing, interactive exploration, debugging, and quick experiments. It uses `$HOME/qiskit-v2x-env/bin/python` with `PYTHONUNBUFFERED=1` and `python -u`, streams combined stdout/stderr live, and creates `<source-stem>-result-output.txt` plus `output.txt` beside the source. Quantum code must attempt a real QPU first, apply the Open/Paid Plan V2 primitive rules, use controlled `transpile` plus `AerSimulator` fallback, and emit `BQCA_EXECUTION_TARGET`, `BQCA_PLAN`, `BQCA_BACKEND`, `BQCA_JOB_ID`, `BQCA_RESULT=SUCCESS` or `BQCA_RESULT=FAILURE`, and `BQCA_FALLBACK_REASON` for fallback. The orchestrator is explicit opt-in only for formal compliance, production deployment, or audit evidence. Direct-mode policy gaps are warnings that preserve the workload exit status; credential leakage is blocking. This block supersedes conflicting local execution guidance.
<!-- BQCA-CANONICAL-PRODUCTION-POLICY-v47:END -->

<!-- BQCA-LOCAL-ALGORITHM-KNOWLEDGEBASE-v47-update-6:BEGIN -->
## BQCA local quantum algorithm knowledgebase — v47 Update 6
For every quantum **DESIGN** or **CODE** intent, consult `.bob/quantum-tools/bqca-quantum-kb.sh` and the offline catalog at `.bob/quantum-tools/knowlegebase/bqca_quantum_algorithm_catalog.json`. Use its algorithm cards and Qiskit 2.5+ starter scaffolds to select the appropriate SamplerV2 or EstimatorV2 pattern, Open Plan job-mode branch without Session, Paid Plan Session branch, and controlled simulator fallback. Update 6 supersedes Update 5 URL seed/sublink crawling; network access and a mandatory research-trace artifact are not required. The local catalog supplements IBM Bob intelligence and approved sources but never overrides the active central policy. If no local entry fits, continue with approved research rather than blocking the request.
<!-- BQCA-LOCAL-ALGORITHM-KNOWLEDGEBASE-v47-update-6:END -->
