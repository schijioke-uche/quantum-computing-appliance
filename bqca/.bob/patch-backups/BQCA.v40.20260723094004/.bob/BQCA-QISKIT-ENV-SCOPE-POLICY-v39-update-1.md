# BQCA Qiskit Environment Scope and Hello World Location Policy v39 Update 1

<!-- BQCA-QISKIT-ENV-SCOPE-v39-update-1:BEGIN -->
- Qiskit is inspected and changed only inside project-root `qiskit-v2x-env`.
- The authorized package command is `qiskit-v2x-env/bin/python -m pip`.
- System/global Python and pip must never inspect or modify Qiskit.
- Host `python3 -m venv` is allowed only to create a missing environment.
- A pre-existing invalid or non-isolated environment fails closed.
- `check` is read-only; `ensure` may create/repair only inside the environment.
- Hello World artifacts are discovered only under `bob-quantum-store/test`.
- These rules apply to designs, code, modes, rules, skills, and quantum tools.
<!-- BQCA-QISKIT-ENV-SCOPE-v39-update-1:END -->
