# BQCA v39 Update 1 Environment Scope — Superseded by v40

<!-- BQCA-QISKIT-HOME-ENV-v40:BEGIN -->
The former project-root `qiskit-v2x-env` location is superseded and prohibited.
The only authorized BQCA runtime is `$HOME/qiskit-v2x-env`.

- Create it with `python3 -m venv "$HOME/qiskit-v2x-env"` only when absent.
- Activate it with `source "$HOME/qiskit-v2x-env/bin/activate"` before every
  Qiskit check, package operation, validation, or execution.
- Never create, use, modify, migrate, or remove `<BQCA-root>/qiskit-v2x-env`.
- Never use system/global pip or user-site Qiskit.
- Continue enforcing Qiskit 2.5+, Open Plan no-Session, Paid Plan Session,
  simulator fallback, Hello World, and real-QPU `backend.run()` restrictions.
<!-- BQCA-QISKIT-HOME-ENV-v40:END -->
