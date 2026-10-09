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
