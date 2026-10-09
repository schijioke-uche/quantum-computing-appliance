# BQCA Quantum Knowledgebase

The directory name `knowlegebase` is retained intentionally for compatibility with the BQCA production path requested by the appliance owner.

## Canonical index

Policy-relative path:

```text
quantum-tools/knowlegebase/bqca_quantum_kb_index.txt
```

Project-root path:

```text
.bob/quantum-tools/knowlegebase/bqca_quantum_kb_index.txt
```

The index is operator maintained. It may contain a URL on its own or an annotated line such as:

```text
VQE and quantum chemistry reference: https://approved.example/quantum/vqe
```

Do not place credentials, tokens, cookies, private keys, or confidential data in the index.

## Required DESIGN/CODE research flow

1. Resolve the user's quantum topic.
2. Search the index for relevant seed URLs.
3. Access selected seed URLs.
4. From every seed accessed, drill into at least one relevant sublink.
5. Save the result as a concise research trace next to the governed design or code artifact.
6. Use the trace alongside IBM Bob intelligence and other approved sources.
7. Validate the final design or code against the active central policy and installed Qiskit version.

Example:

```bash
.bob/quantum-tools/bqca-quantum-kb.sh research \
  --query "VQE ground-state energy for a molecular Hamiltonian" \
  --output bob-quantum-designs/molecule-vqe/molecule-vqe-kb-research.md
```

The research command is strict by default. It fails when no seed URL can be accessed or when an accessed seed does not yield at least one successfully accessed relevant sublink. `--allow-incomplete` is diagnostic only and is not policy compliant.
