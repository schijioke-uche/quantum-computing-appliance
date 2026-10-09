# BQCA Home-Scoped Qiskit Virtual Environment Policy v40

<!-- BQCA-QISKIT-HOME-ENV-v40:BEGIN -->
## Production path contract

The BQCA Qiskit runtime environment must exist at the absolute user-home path:

`$HOME/qiskit-v2x-env` (`~/qiskit-v2x-env`).

The BQCA project root must never contain the active Qiskit environment. An old
project-local `qiskit-v2x-env` is ignored and left untouched.

## Creation and activation contract

When the home environment does not exist, the runtime manager creates it with:

```bash
python3 -m venv "$HOME/qiskit-v2x-env"
```

Before any Qiskit check, install, uninstall, upgrade, validation, or execution,
the runtime manager activates it with:

```bash
source "$HOME/qiskit-v2x-env/bin/activate"
```

After activation, only the environment's `python`, `python -m pip`, and commands
resolved from `$HOME/qiskit-v2x-env/bin` are authorized.

## Enforcement scope

This rule applies to all BQCA custom modes, rules, skills, tools, designs,
implementation workflows, code validators, Qiskit Connector operations,
quality gates, Hello World execution, and versioned launchers.
<!-- BQCA-QISKIT-HOME-ENV-v40:END -->
