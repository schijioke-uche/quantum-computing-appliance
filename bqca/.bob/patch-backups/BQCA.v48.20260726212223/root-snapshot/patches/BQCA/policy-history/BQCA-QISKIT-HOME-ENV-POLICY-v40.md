# BQCA Home-Scoped Qiskit Virtual Environment Policy v40, Clarified by v41

<!-- BQCA-HELLO-WORLD-SCOPE-v41:BEGIN -->
The only authorized BQCA Qiskit environment is `$HOME/qiskit-v2x-env`, outside
the project root. Create it only when absent and activate it before Qiskit
inspection, package management, validation, or execution. Never use a
project-local `qiskit-v2x-env`.

This environment policy applies to all modes, rules, skills, tools, designs,
code, validators, Connector operations, and launchers. It does not impose a
Hello World test. Hello World content and execution are prohibited for every
non-Hello-World design and code request. They are permitted only when the user
specifically requests a Hello World design or executable.
<!-- BQCA-HELLO-WORLD-SCOPE-v41:END -->
