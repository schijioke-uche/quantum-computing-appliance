# BQCA Qiskit Connector Mandatory Rule v34

This rule is strict, blocking, and appliance-wide. It overrides simulator-first, optional-connector, advisory, or weaker instructions.

## Default code intent

Any request using terms such as create, implement, write, generate, build, develop, produce, scaffold, construct, code, program, modify, update, repair, fix, refactor, complete, or execute is a code-producing request when the object is a quantum/Qiskit workload or artifact.

For every such Python/Qiskit file, include exactly:

```python
from qiskit_connector import QConnectorV2 as connector
from qiskit_connector import QPlanV2 as plan

current = plan()
backend = connector()
```

The first attempt MUST be real-QPU execution using the connector backend. Verify QPU availability, operational state, and qubit capacity. Only after no usable QPU is available or real execution fails may an `except` path execute `AerSimulator` or `BasicSimulator`. Simulator-first code is forbidden.

Completion is blocked until:

```bash
python3 -m py_compile <saved-file.py>
.bob/quantum-tools/qiskit-connector.sh --validate-code <saved-file.py>
```

## Default design intent

Any request using design, architect, plan, specify, model, diagram, propose, blueprint, define, or document for a quantum solution must include the section `Qiskit Connector Real-QPU-First Execution and Simulator Fallback`. The section must be textual instructions only—no executable Python and no fenced Python block. It must instruct the later code-writing mode to include the connector imports and initialization, QPU availability/capacity checks, real-QPU-first flow, try/except simulator fallback, and execution reporting.

Completion is blocked until:

```bash
.bob/quantum-tools/qiskit-connector.sh --validate-design <saved-design.md>
```

<!-- BQCA-ACTIVE-CENTRAL-POLICY:BEGIN -->
## Active central policy binding
Before every quantum DESIGN or CODE decision, resolve the currently active authority through `.bob/quantum-tools/bqca-active-policy-listener.sh sync`. Read the stable policy and its embedded validation contract returned by the listener. Never hardcode a policy version or duplicate the complete central policy in this component.

Validate every design through `.bob/quantum-tools/qiskit-design-policy-check.py` and every Python code artifact through `.bob/quantum-tools/qiskit-code-policy-check.py`. The validators reload the registry, policy, policy SHA-256, and validation contract on every invocation and automatically create the required same-directory design/code policy-compliance report. Do not report an artifact complete unless its compliance report exists and reflects the active policy.
<!-- BQCA-ACTIVE-CENTRAL-POLICY:END -->

<!-- BQCA-BOB-SHELL-V2-DNA:BEGIN -->
## Bob Shell 2.x BQCA project-DNA binding
In a trusted Bob Shell 2.x workspace, read `AGENTS.md`, resolve the active central BQCA policy, honor the exported menu option/action/skill/mode, and use the current rules, relevant skills, quantum tools, and offline knowledgebase. This component supplements the existing BQCA workflow and must not replace its domain purpose or active-policy controls. Never degrade to generic Bob behavior.
<!-- BQCA-BOB-SHELL-V2-DNA:END -->
<!-- BQCA-TRUSTED-CHAT-AUTO-APPROVAL-v51.4:BEGIN -->
## Trusted BQCA chat auto-approval

Routine tool approvals in BQCA interactive/resume chat sessions are handled by the trusted session launch flags. Do not ask the user to approve ordinary project-scoped skills, reads, writes, directory creation, validators, or commands. This speed optimization never authorizes credential access, destructive operations, Bob home/settings changes, external-path writes, or bypass of active BQCA policy and safety gates.
<!-- BQCA-TRUSTED-CHAT-AUTO-APPROVAL-v51.4:END -->
