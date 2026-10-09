# BQCA Request-Scoped Hello World Policy v41

<!-- BQCA-HELLO-WORLD-SCOPE-v41:BEGIN -->
## Production rule

Hello World is an explicit user-request workflow, not a mandatory test for all
quantum work.

For a non-Hello-World request, BQCA must not place any of the following in the
design or code:

- a Hello World section or heading;
- a Hello World test or smoke-test requirement;
- a Hello World command, function, fixture, example, or artifact;
- a `hello-world.py`, `hello_world.py`, `hellow-world.py`, or corresponding
  notebook reference;
- a `bob-quantum-store/test` reference;
- an instruction to execute Hello World before, during, or after the requested
  workload.

This prohibition applies to generated and modified designs, implementation
code, notebooks derived from that code, validation reports, and completion
summaries.

## Authorized exception

Hello World content is permitted only when the user explicitly requests a
Hello World design or Hello World executable. The artifact must be clearly
identified by a Hello World filename or top-level title/module description.
Only in that explicit scope may BQCA inspect and run an existing artifact under
`<BQCA-root>/bob-quantum-store/test` through `$HOME/qiskit-v2x-env`.

## Completion gate

All non-Hello-World designs and code must pass
`.bob/quantum-tools/qiskit-hello-world-scope-check.py`. A violation is blocking
and must be removed before BQCA reports completion.
<!-- BQCA-HELLO-WORLD-SCOPE-v41:END -->
