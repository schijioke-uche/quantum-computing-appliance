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

<!-- BQCA-CANONICAL-PRODUCTION-POLICY-v48:BEGIN -->
## BQCA v48 cumulative production authority
Use `.bob/BQCA-PRODUCTION-POLICY.md` as the sole active BQCA v48 policy. Direct synchronous execution through `.bob/quantum-tools/bqca-direct-execution.sh` is the default for development, testing, exploration, debugging, and quick experiments; the formal orchestrator is explicit opt-in only for compliance, deployment, or audit evidence. Preserve Qiskit Connector configuration, `$HOME/qiskit-v2x-env`, Qiskit 2.5+, Open Plan SamplerV2/EstimatorV2 job mode without Session, Paid Plan Session with the suitable V2 primitive, real-QPU-first behavior, controlled simulator fallback, automatic synchronized notebooks, request-scoped Hello World, live terminal output, `<source-stem>-result-output.txt`, `output.txt`, Job-ID-first real-QPU reports, and credential-leak blocking. For quantum DESIGN and CODE requests consult `.bob/quantum-tools/bqca-quantum-kb.sh` and the offline v48 algorithm catalog. The catalog supplements IBM Bob intelligence and never overrides the central policy. v48 incorporates core v47 and Updates 1-6; Update 6 supersedes Update 5 URL crawling.
<!-- BQCA-CANONICAL-PRODUCTION-POLICY-v48:END -->
