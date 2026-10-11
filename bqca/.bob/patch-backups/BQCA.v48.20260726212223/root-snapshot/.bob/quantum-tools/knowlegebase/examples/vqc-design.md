# Variational Quantum Classifier — BQCA Design Knowledge Card

## Knowledgebase provenance

- Catalog: `/home/architect/IBM-SOFTWARE-LAB2/quantum-computing-agent/.bob/quantum-tools/knowlegebase/bqca_quantum_algorithm_catalog.json`
- Catalog SHA-256: `542f7119261e656302355be9ade899f70d3125e6649ba53fc458222860eaebea`
- Catalog version: `BQCA.v47-update-6`
- Qiskit compatibility floor: `2.5.0`
- Entry status: `starter`

## Purpose

Classification with a feature map and variational ansatz

## Suitable use cases

- classification
- regression
- hybrid ML

## Algorithm and circuit strategy

- Category: **Quantum Machine Learning**
- Primitive family: **sampler**
- Estimated qubits: **problem-dependent**
- Template pattern: **variational_sampler**
- Define the problem instance, input encoding, circuit/ansatz, classical optimizer or post-processing where applicable, and validation baseline before implementation.

## IBM Quantum plan-aware execution

### Open Plan

No Session. Use SamplerV2(mode=backend) for sampling/counts or EstimatorV2(mode=backend) for expectation values/energy, according to the primitive field.

### Paid Plan

Use Session(backend=backend) and SamplerV2(mode=session) or EstimatorV2(mode=session), according to the primitive field.

### Simulator fallback

Fallback only after real-QPU eligibility/attempt failure. Use try/except with transpilation and AerSimulator or Aer V2 primitives.

## Qiskit 2.5+ dependencies

- `qiskit`
- `qiskit-machine-learning`
- `qiskit-ibm-runtime`
- `qiskit-aer`
- `qiskit-connector`

## Required implementation evidence

- Qiskit Connector plan and backend initialization.
- Real-QPU eligibility and qubit-capacity checks.
- Real-QPU-first execution branch.
- Controlled simulator fallback.
- Canonical BQCA execution markers and result-output files.
- Synchronized `.py` and `.ipynb` artifacts.
- Human review of scientific assumptions and result interpretation.

## Result contract

Emit BQCA_EXECUTION_TARGET, BQCA_PLAN, BQCA_BACKEND, BQCA_JOB_ID for real QPU, BQCA_FALLBACK_REASON for fallback, BQCA_RESULT=SUCCESS|FAILURE, and BQCA_RESULT_VALUE for scientific output.

## Official references

- https://pypi.org/project/qiskit/2.5.0/
- https://quantum.cloud.ibm.com/docs/en/guides/qiskit-runtime-primitives
- https://qiskit-community.github.io/qiskit-machine-learning/

## Limitations and review notes

- This local knowledge card is a design accelerator, not a substitute for the active central BQCA policy.
- Package APIs and backend constraints must be checked in the authorized `$HOME/qiskit-v2x-env` before execution.
- Large or fault-tolerant algorithms may require a reduced demonstration problem for current hardware.
