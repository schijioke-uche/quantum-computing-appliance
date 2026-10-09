# IBM Bob Quantum Computing Agent (BQCA)

**IBM Bob Quantum Computing Agent (BQCA)** is a domain-specialized IBM Bob appliance designed to help quantum practitioners, platform engineers, researchers, and enterprise innovation teams plan, build, validate, and operationalize quantum-computing workflows. BQCA combines IBM Bob Shell, custom Bob modes, custom Bob skills, custom rules, and BQCA-specific tool guidance to produce a guided quantum development environment for Qiskit, IBM Quantum Runtime, circuit design, VQE workflows, simulation, visualization, and quantum solution planning.

**Author:** Bob Quantum Team (Inspired by IBM 2026 watsonx Challenge)

---

# How to Use BQCA Appliance

## 0. Install IBM Bob Shell 1.0.6+

macOS/Linux
```bash
curl -fsSL https://bob.ibm.com/download/bobshell.sh | bash
```

Windows
```bash
powershell -ep Bypass 'irm -Uri "https://bob.ibm.com/download/bobshell.ps1" | iex' 
```

## 1. Clone the Repository

```bash
git clone <repository-url>
```

Replace `<repository-url>` with the Git repository that contains the IBM Bob appliance project.

## 2. Go to the BQCA Directory

Depending on your repository layout, use one of these patterns:

```bash
cd quantum-computing-agent
```

or, if the extracted appliance root is directly named `quantum-computing-agent`:

```bash
cd quantum-computing-agent
```

## 3. Create the Runtime Environment File

```bash
cp .env.example .env
sed -i 's/\r$//' .env
```

## 4. Fill Out Required `.env` Variables

Open `.env` and provide the required values.

**Minimum Bob runtime variables:**

```bash
export BOB_API_KEY="<your-bob-api-key>"
export BOB_INSTANCE_ID="<your-bob-instance-id>"
export BOB_ENDPOINT="https://api.us-east.bob.ibm.com"
export BOB_AUTH_ENDPOINT="https://console-ibm-prod.verify.ibm.com"
export BOB_REGION="us-east"
export APPLIANCE_NAME="IBM Bob Quantum Computing Agent (BQCA)"
```

**Quantum-specific variables to review:**

```bash
export IQP_API_TOKEN="<your-ibm-quantum-token>"
export OPEN_PLAN_CHANNEL="ibm_quantum_platform"
export PAID_PLAN_CHANNEL="ibm_quantum_platform"
export IQP_API_URL="https://auth.quantum-computing.ibm.com/api/users/loginWithToken"
export IQP_RUNTIME_BACKEND_URL="https://api.quantum-computing.ibm.com/runtime/backends"
export CLOUD_API_URL="https://cloud.ibm.com"
export QUANTUM_API_URL="https://auth.quantum.ibm.com/api"
export OPEN_PLAN_INSTANCE=""
export PAID_PLAN_INSTANCE="<optional - some paid instance identifier>"
export OPEN_PLAN="on"
export FLEX_PLAN="off"
export PAYGO_PLAN="off"
export PREMIUM_PLAN="off"
export DEDICATED_PLAN="off"
```

> Do not hardcode real tokens into generated source files. Keep secrets in `.env` or your enterprise secret-management system.

## 5. Verify Bob Shell

```bash
bob --version
```

The appliance uses `bob-version.sh` to detect the Bob Shell version and export `BOB_VERSION`. The current BQCA launcher is version-resolved as `bob-quantum-v1.0.6.sh`.

## 6. Start the Appliance

```bash
chmod +x xLaunchpad.sh bob-quantum-v1.0.6.sh bob-version.sh bob-auth.sh tls-control.sh
./xLaunchpad.sh
```

The launchpad presents the BQCA menu:

```text
+---------------------------------------------------------------------------------------------+
| IBM Bob Quantum Computing Agent (BQCA)                                                      |
| This is Quantum Computing Agent, built & integrated with IBM Bob Intelligence               |
+---------------------------------------------------------------------------------------------+
| No.   | Action                                                         | Skill ID           |
+---------------------------------------------------------------------------------------------+
| 1     | Start Interactive BQCA Session                                 | User Interactive   |
| 2     | Ask Quantum Computing Questions                                | Quantum Expert     |
| 3     | Quantum Computing Algorithm Implementation Concierge           | Quantum Developer  |
| 4     | Advanced Quantum Computing Solution Design Concierge           | Quantum Advanced   |
| 5     | Resume BQCA Last Activity (Picks: 1, 2, 3, or 4 last action)   | Resume Session     |
| 0     | Quit                                                           | Exit               |
+---------------------------------------------------------------------------------------------+
```

## Your First Prompt & Test
```bash
1. Select Menu Option 1
2. Tell BQCA: Run Hello World
```
---

## BQCA Usage Guidance

When submitting a request to BQCA, route it into the appropriate workflow — **DESIGN** or **IMPLEMENTATION** — using the menu option that matches your goal.

### Ask Quantum Computing Question (Menu Option 2)

Use this path when you want explanation, comparison, algorithm selection guidance, or conceptual clarification.

**Example prompts:**
- `Explain Grover's algorithm.`
- `Compare VQE and QAOA.`
- `What algorithm should I use for molecular ground-state estimation?`
- `How does phase estimation relate to Shor's algorithm?`
- `Design a quantum circuit for a 3-qubit GHZ state.`
- `Create a Qiskit v2 code for a 3-qubit GHZ state and run it on a simulator.`
- `Create a Qiskit v2 code for a 3-qubit GHZ state and run it on a real quantum backend using Qiskit Connector.`

### Quantum Computing Algorithms Concierge (Menu Option 3)

Use this path when you want implementation guidance, code generation, Qiskit examples, algorithm modification, or experiment scaffolding.

**Example prompts:**
- `Generate a Qiskit v2 VQE workflow design.`
- `Create a QAOA MaxCut design with Qiskit v2.`
- `Create a Qiskit v2 code for a Grover oracle for this QAOA MaxCut design.`
- `Modify this circuit to run on a real IBM Quantum backend.`

### Advanced Quantum Computing Circuit Design (Menu Option 4)

Use this path when you want a circuit architecture, a deeper quantum workflow design, backend execution planning, simulation strategy, or a production-quality quantum experiment plan.

**Example prompts:**
- `Design a VQE circuit and execution plan for a chemistry simulation.`
- `Create a QAOA circuit design for a routing optimization problem.`
- `Plan a simulator-to-real-QPU execution workflow.`
- `Create a design document for a quantum algorithm experiment.`

---

## Recommended User Prompts

| Goal | Example Prompt |
|---|---|
| Ask a quantum question | `Explain VQE and when I should use it.` |
| Create a design artifact | `Design a 4-qubit VQE workflow for lithium hydride. Save the design only.` |
| Generate code | `Create Qiskit code for a 3-qubit GHZ circuit and save it in the BQCA store.` |
| Generate visualization | `Create and run a Bell-state circuit and save the circuit PNG and histogram PNG.` |
| Build a VQE prototype | `Create a VQE prototype with result text output and convergence plot.` |
| Plan a larger implementation | `Create a plan for a QAOA portfolio-optimization proof of concept.` |
| Configure MCP | `Create an MCP server for local quantum documentation lookup.` |

---

## Recommended BQCA Output Pattern

For algorithm-related requests, BQCA produces outputs in this order:

1. Problem interpretation
2. Recommended quantum algorithm or algorithm family
3. Why the algorithm is appropriate
4. Required inputs and assumptions
5. Circuit or workflow design
6. Qiskit or IBM Quantum Runtime implementation plan
7. Simulator execution plan
8. Real backend execution considerations
9. Validation and metrics
10. Generated artifacts

---

## Recommended Artifact Routing

| Artifact Type | Recommended Location | Examples |
|---|---|---|
| Design document | `bob-quantum-designs/` | Algorithm design, architecture plan, backend strategy |
| Executable code | `bob-quantum-store/` | Python scripts, Qiskit notebooks, runtime jobs |
| Results | `bob-quantum-store/` | JSON, CSV, simulator counts, backend results |
| Visualizations | `bob-quantum-store/` | Circuit diagrams, histograms, plots, PNG files |
| Documentation | Repository root or docs folder | README files, runbooks, usage guides |

---

## Quantum Algorithms Catalog

The catalog is organized for BQCA use cases including: Quantum Computing Algorithms Concierge, Advanced Circuit Design, VQE and chemistry workflows, QAOA and optimization workflows, IBM Quantum backend and simulator execution planning, Qiskit and IBM Quantum Runtime implementation support, and quantum education.

> **Note:** Quantum computing research evolves continuously. This catalog is a broad practical reference for known major algorithms and algorithm families, not a formal proof that every published variant is included.

### Algorithm Table of Contents

1. [BQCA Priority Algorithm Set](#bqca-priority-algorithm-set)
2. [Foundational and Core Quantum Algorithms](#foundational-and-core-quantum-algorithms)
3. [Search, Oracle, and Query Algorithms](#search-oracle-and-query-algorithms)
4. [Number Theory, Algebra, and Cryptanalysis](#number-theory-algebra-and-cryptanalysis)
5. [Quantum Simulation and Physics Algorithms](#quantum-simulation-and-physics-algorithms)
6. [Chemistry, Materials, and Molecular Simulation](#chemistry-materials-and-molecular-simulation)
7. [Optimization Algorithms](#optimization-algorithms)
8. [Linear Algebra and Matrix Algorithms](#linear-algebra-and-matrix-algorithms)
9. [Machine Learning and AI Algorithms](#machine-learning-and-ai-algorithms)
10. [Variational and NISQ Algorithms](#variational-and-nisq-algorithms)
11. [Quantum Walk Algorithms](#quantum-walk-algorithms)
12. [Sampling and Complexity-Oriented Algorithms](#sampling-and-complexity-oriented-algorithms)
13. [Communication, Cryptography, and Protocol Algorithms](#communication-cryptography-and-protocol-algorithms)
14. [Error Correction, Fault Tolerance, and Compilation Algorithms](#error-correction-fault-tolerance-and-compilation-algorithms)

---

### BQCA Priority Algorithm Set

For the IBM Bob BQCA solution, the following algorithm set is prioritized as the visible and explainable supported coverage.

1. Variational Quantum Eigensolver (VQE)
2. Adaptive Derivative-Assembled Pseudo-Trotter VQE (ADAPT-VQE)
3. Quantum Approximate Optimization Algorithm (QAOA)
4. Grover's algorithm
5. Quantum Phase Estimation (QPE)
6. Quantum Fourier Transform (QFT)
7. Hamiltonian simulation
8. Quantum chemistry simulation
9. Quantum optimization, QUBO, and Ising workflows
10. Quantum circuit design algorithms
11. Amplitude amplification
12. Amplitude estimation
13. Harrow-Hassidim-Lloyd algorithm (HHL) and quantum linear systems algorithms
14. Quantum kernel methods
15. Variational Quantum Classifier (VQC)
16. Quantum neural network workflows
17. Quantum walk algorithms
18. Quantum Monte Carlo and amplitude-estimation workflows
19. Real IBM Quantum backend execution workflows
20. Qiskit Runtime-ready algorithm workflows

---

### Foundational and Core Quantum Algorithms

- Deutsch algorithm
- Deutsch-Jozsa algorithm
- Bernstein-Vazirani algorithm
- Simon's algorithm
- Grover's algorithm
- Quantum Fourier Transform (QFT)
- Quantum Phase Estimation (QPE)
- Iterative Phase Estimation (IPE)
- Kitaev Phase Estimation
- Amplitude amplification
- Amplitude estimation
- Iterative amplitude estimation
- Maximum-likelihood amplitude estimation
- Quantum counting
- Swap test
- Hadamard test
- Destructive swap test
- Quantum state overlap estimation
- Quantum state fidelity estimation
- Quantum tomography algorithms
- Classical shadows
- Quantum mean estimation
- Quantum gradient estimation
- Quantum Singular Value Transformation (QSVT)
- Quantum Signal Processing (QSP)
- Block-encoding algorithms

---

### Search, Oracle, and Query Algorithms

- Grover search
- Multi-solution Grover search
- Fixed-point Grover search
- Adaptive Grover search
- Quantum exhaustive search
- Quantum backtracking algorithm
- Quantum branch-and-bound
- Quantum minimum finding, also known as the Durr-Hoyer algorithm
- Quantum maximum finding
- Quantum approximate counting
- Quantum collision finding
- Brassard-Hoyer-Tapp collision algorithm
- Element distinctness algorithm
- Ambainis element distinctness algorithm
- Quantum walk search
- Spatial search by quantum walk
- Quantum algorithm for formula evaluation
- NAND-tree algorithm
- Span-program algorithms
- Adversary-bound algorithms
- Oracle interrogation algorithms
- Quantum algorithms for Boolean satisfiability variants
- Quantum algorithms for graph property testing

---

### Number Theory, Algebra, and Cryptanalysis

- Shor's factoring algorithm
- Shor's discrete logarithm algorithm
- Order-finding algorithm
- Period-finding algorithm
- Abelian Hidden Subgroup Problem algorithms
- Non-abelian Hidden Subgroup Problem algorithms
- Dihedral Hidden Subgroup Problem algorithms
- Kuperberg's sieve algorithm
- Hidden shift algorithms
- Hallgren's algorithm for Pell's equation
- Principal ideal problem algorithms
- Unit group computation algorithms
- Class group computation algorithms
- Algorithms for Gauss sums
- Algorithms for estimating Jones polynomials
- Quantum algorithms for knot invariants
- Quantum algorithms for lattice-related hidden structure problems
- Quantum algorithms for isomorphism-related problems
- Quantum algorithms for discrete logarithms over elliptic curves
- Quantum algorithms for cryptographic key recovery where reductions map to period finding

---

### Quantum Simulation and Physics Algorithms

- Hamiltonian simulation
- Trotter-Suzuki product-formula simulation
- Higher-order product-formula simulation
- Linear Combination of Unitaries (LCU) simulation
- Taylor-series Hamiltonian simulation
- Qubitization
- Quantum signal processing simulation
- Quantum walk Hamiltonian simulation
- Sparse Hamiltonian simulation
- Dense Hamiltonian simulation
- Interaction-picture simulation
- Quantum simulation by phase estimation
- Real-time evolution algorithms
- Imaginary-time evolution algorithms
- Quantum Imaginary Time Evolution (QITE)
- Variational Quantum Simulation (VQS)
- Variational Quantum Real-Time Evolution (VarQRTE)
- Variational Quantum Imaginary-Time Evolution (VarQITE)
- Quantum Lanczos algorithms
- Quantum Krylov algorithms
- Quantum Subspace Expansion (QSE)
- Quantum Metropolis algorithm
- Quantum Gibbs sampling
- Quantum algorithms for thermal-state preparation
- Quantum algorithms for Green's functions
- Quantum algorithms for spectral functions
- Quantum algorithms for lattice models
- Quantum algorithms for quantum field theory simulation

---

### Chemistry, Materials, and Molecular Simulation

- Variational Quantum Eigensolver (VQE)
- Adaptive Derivative-Assembled Pseudo-Trotter VQE (ADAPT-VQE)
- Unitary Coupled Cluster VQE (UCC-VQE)
- Unitary Coupled Cluster Singles and Doubles VQE (UCCSD-VQE)
- Hardware-efficient VQE
- Chemistry VQE
- Excited-state VQE
- Variational Quantum Deflation (VQD)
- Subspace-Search VQE (SSVQE)
- Multistate Contracted VQE (MC-VQE)
- Orbital-optimized VQE
- Quantum Equation of Motion (qEOM)
- Quantum subspace expansion for chemistry
- Quantum phase-estimation chemistry algorithms
- Quantum algorithms for molecular ground-state energy
- Quantum algorithms for excited-state energy
- Quantum algorithms for reaction pathways
- Quantum algorithms for catalyst modeling
- Quantum algorithms for battery and materials discovery
- Quantum algorithms for electronic-structure simulation
- Fermionic simulation algorithms
- Jordan-Wigner mapping workflows
- Bravyi-Kitaev mapping workflows
- Parity mapping workflows

---

### Optimization Algorithms

- Quantum Approximate Optimization Algorithm (QAOA)
- Recursive QAOA (RQAOA)
- Warm-start QAOA
- Multi-angle QAOA
- Quantum Alternating Operator Ansatz
- Quantum annealing
- Adiabatic quantum optimization
- Quantum adiabatic algorithm
- Quantum approximate counting for optimization
- Grover Adaptive Search (GAS)
- Quantum minimum finding
- Quantum walk optimization
- Quantum backtracking
- Quantum branch-and-bound
- Quantum algorithms for semidefinite programming
- Quantum algorithms for linear programming
- Quantum algorithms for convex optimization
- Quantum algorithms for combinatorial optimization
- Quantum algorithms for MaxCut
- Quantum algorithms for graph coloring
- Quantum algorithms for traveling salesperson variants
- Quantum algorithms for portfolio optimization
- Quantum algorithms for supply-chain optimization
- Quantum algorithms for scheduling
- Quantum algorithms for routing
- Quantum algorithms for QUBO problems
- Quantum algorithms for Ising-model optimization

---

### Linear Algebra and Matrix Algorithms

- Harrow-Hassidim-Lloyd algorithm (HHL)
- Quantum Linear Systems Algorithm (QLSA)
- Childs-Kothari-Somma QLSA
- Variable-time amplitude-amplification QLSA
- Block-encoded QLSA
- Quantum matrix inversion
- Quantum matrix multiplication algorithms
- Quantum matrix-vector multiplication
- Quantum least-squares fitting
- Quantum Principal Component Analysis (qPCA)
- Quantum Singular Value Estimation (QSVE)
- Quantum Singular Value Transformation (QSVT)
- Quantum eigenvalue estimation
- Quantum algorithms for solving differential equations
- Quantum algorithms for partial differential equations
- Quantum algorithms for finite-element methods
- Quantum algorithms for recommendation systems
- Quantum algorithms for data fitting
- Quantum algorithms for Monte Carlo integration
- Quantum algorithms for numerical integration

---

### Machine Learning and AI Algorithms

- Variational Quantum Classifier (VQC)
- Quantum Support Vector Machine (QSVM)
- Quantum kernel estimation
- Quantum kernel alignment
- Quantum feature maps
- Quantum Neural Networks (QNNs)
- Quantum Convolutional Neural Networks (QCNNs)
- Quantum recurrent neural networks
- Quantum Generative Adversarial Networks (QGANs)
- Quantum Born machines
- Quantum circuit Born machines
- Quantum Boltzmann machines
- Quantum autoencoders
- Quantum reservoir computing
- Quantum k-means
- Quantum nearest-neighbor algorithms
- Quantum recommendation algorithms
- Quantum Principal Component Analysis (qPCA)
- HHL-based machine-learning algorithms
- Quantum-enhanced least squares
- Quantum-enhanced classification
- Quantum-enhanced clustering
- Quantum reinforcement-learning algorithms
- Quantum natural gradient algorithms
- Variational Quantum Linear Solver (VQLS)

---

### Variational and NISQ Algorithms

- VQE
- QAOA
- VQD
- ADAPT-VQE
- VQLS
- Variational quantum simulation
- Variational quantum compiling
- Variational quantum factoring
- Variational quantum classifier
- Variational quantum regressor
- Variational quantum neural network
- Variational quantum autoencoder
- Variational quantum state diagonalization
- Variational quantum thermalizer
- Variational quantum imaginary-time evolution
- Variational quantum real-time evolution
- Quantum natural gradient optimization
- Parameter-shift gradient algorithms
- Barren-plateau mitigation algorithms
- Ansatz search algorithms
- Hardware-efficient ansatz algorithms
- Problem-inspired ansatz algorithms

---

### Quantum Walk Algorithms

- Discrete-time coined quantum walk
- Continuous-time quantum walk
- Szegedy quantum walk
- Quantum walk search
- Spatial quantum search
- Element distinctness by quantum walk
- Triangle finding algorithms
- Graph collision algorithms
- Glued-trees algorithm
- NAND-tree evaluation
- Quantum walk algorithms for Markov chains
- Quantum walk algorithms for hitting time
- Quantum walk algorithms for graph traversal
- Quantum walk algorithms for ranking and centrality
- Quantum walk Hamiltonian simulation

---

### Sampling and Complexity-Oriented Algorithms

- Boson sampling
- Gaussian boson sampling
- Random circuit sampling
- Instantaneous Quantum Polynomial-time (IQP) circuits
- DQC1 / one-clean-qubit algorithms
- Quantum approximate sampling
- Quantum Metropolis sampling
- Quantum Gibbs sampling
- Quantum rejection sampling
- Quantum Monte Carlo algorithms
- Quantum amplitude-estimation Monte Carlo
- Quantum walks for sampling
- Quantum algorithms for partition functions
- Quantum algorithms for Ising-model sampling

---

### Communication, Cryptography, and Protocol Algorithms

These are often described as quantum protocols rather than algorithms, but are useful for BQCA quantum education, architecture design, and solution framing.

- BB84 quantum key distribution
- E91 quantum key distribution
- B92 quantum key distribution
- SARG04 quantum key distribution
- Measurement-device-independent quantum key distribution
- Device-independent quantum key distribution
- Twin-field quantum key distribution
- Quantum teleportation
- Superdense coding
- Entanglement swapping
- Quantum secret sharing
- Quantum digital signatures
- Quantum fingerprinting
- Quantum money protocols
- Quantum coin flipping
- Quantum oblivious transfer
- Quantum secure direct communication
- Quantum random-number generation
- Quantum authentication protocols

---

### Error Correction, Fault Tolerance, and Compilation Algorithms

- Shor code
- Steane code
- Five-qubit code
- Seven-qubit code
- Bacon-Shor code
- Surface code
- Color code
- Repetition code
- Cat codes
- Bosonic codes
- Gottesman-Kitaev-Preskill (GKP) code
- Quantum Low-Density Parity-Check (LDPC) codes
- Syndrome-extraction algorithms
- Minimum-weight perfect matching decoder
- Union-find decoder
- Belief-propagation decoder
- Neural quantum decoders
- Magic-state distillation
- Lattice surgery
- Fault-tolerant gate synthesis
- Solovay-Kitaev algorithm
- Clifford+T synthesis
- T-count optimization
- T-depth optimization
- Quantum Shannon decomposition
- Cosine-sine decomposition
- KAK decomposition
- Phase-polynomial optimization
- Qubit routing algorithms
- SWAP-network algorithms
- SABRE-style transpilation and routing
- Circuit cutting
- Circuit knitting
- Error mitigation algorithms
- Zero-noise extrapolation
- Probabilistic error cancellation
- Measurement-error mitigation
- Dynamical decoupling

---

## Security and Governance Notes

1. Never commit `.env` with real secrets.
2. Keep IBM Quantum tokens and Bob API keys outside generated source code.
3. Use enterprise-approved runtime environments for production quantum workloads.
4. Review generated quantum code before using real hardware or quota-consuming runtime jobs.
5. Keep design-only work in `bob-quantum-designs/` and implementation code in `bob-quantum-store/`.
6. Treat generated scientific results as prototypes unless independently validated.

---

## Documentation and Reference

| Documentation Area | Where to Look |
|---|---|
| BQCA tools and quantum execution policy | `.bob/quantum-tools/README.md` |
| BQCA main skill | `.bob/skills/bob-quantum-skill/SKILL.md` |
| Shared custom skills | `.bob/skills/` |
| BQCA custom modes | `.bob/custom_modes.yaml` |
| BQCA mode-specific rules | `.bob/rules-*/*.md` |
| Bob authentication notes | `bob-auth.md` |
| Design outputs | `bob-quantum-designs/` |
| Implementation outputs | `bob-quantum-store/` |

---

## Authors

| Name | Role / Affiliation | Additional Designation |
|---|---|---|
| Akpojotor Shemi | IBM Quantum Qiskit Advocate | Bob Quantum Team Member (watsonx Challenge '26) |
| Nic Ponder | Aspiring Quantum Graduate Student | Bob Quantum Team Member (watsonx Challenge '26) |
| Taylor Sperry | IBM Quantum Ambassador Candidate | Bob Quantum Team Member (watsonx Challenge '26) |
| Jeffrey Chijioke-Uche, PhD | IBM Computer Scientist & IBM Quantum Ambassador \| Quantum Qiskit Advocate | Quantum Master Inventor, IEEE Senior Member for Computational Intelligence, Bob Quantum Team Member (watsonx Challenge '26) |

---
---

## BQCA Appliance Snapshot

| Feature | Description |
|---|---|
| Appliance name | IBM Bob Quantum Computing Agent (BQCA) |
| BQCA Root folder | `quantum-computing-agent/` |
| Primary launcher | `bob-quantum-v1.0.6.sh` |
| Version detector | `bob-version.sh` |
| Dynamic version pattern | Runtime content uses `v${BOB_VERSION}`; physical launcher is resolved to the detected Bob version. |
| Entry launchpad | `xLaunchpad.sh` |
| Authentication helper | `bob-auth.sh` and `bob-auth.md` |
| TLS helper | `tls-control.sh` |
| Environment template | `.env.example` |
| Bob configuration root | `.bob/` |
| BQCA tools guide | `.bob/quantum-tools/README.md` |
| Main BQCA skill | `.bob/skills/bob-quantum-skill/SKILL.md` |
| Design directory | `bob-quantum-designs/` |
| Implementation directory | `bob-quantum-store/` |

---

### Background of BQCA Appliance

#### Executive Summary

BQCA is an IBM Bob-powered quantum engineering appliance. It converts Bob from a general AI coding assistant into a focused quantum-computing agent with persistent appliance rules, quantum modes, reusable skills, Qiskit-oriented tooling guidance, artifact routing, and execution discipline.

The appliance is optimized for users who need to:

1. Ask quantum-computing questions and receive domain-specific guidance.
2. Generate Qiskit and IBM Quantum Runtime-ready code.
3. Design circuits, VQE workflows, QAOA workflows, simulations, and quantum experiments.
4. Separate architecture/design documents from executable implementation artifacts.
5. Produce terminal output, result files, and PNG visualizations for quantum workflows.
6. Use shared Bob productivity skills such as planning, skill creation, MCP server building, Git guidance, and Excel workbook analysis.

BQCA is a configured Bob appliance with a purpose-built intelligence layer for quantum research, quantum education, quantum application prototyping, molecular simulation, quantum optimization, quantum runtime planning, and Qiskit-based software engineering. This made BQCA to be valuable in multiple industries.

---

#### BQCA Concrete Ways of Reducing Research Friction to Offer Productivity Gains

> **watsonx Challenge 2026 Judging Evidence — Effectiveness & Efficiency**

The following six measured, observable mechanisms demonstrate how BQCA directly removes research friction and converts hours of manual preparation into minutes of automated, governed output. Each point below is backed by real artifacts produced during the challenge window.

| # | Friction Removed | How BQCA Removes It | Observable Evidence |
|---|---|---|---|
| 1 | **44.60-hour/week preparation overhead** | The same ten-stage scaffolded workflow took **44.8 hours manually** and **0.20 hours (12 minutes) with BQCA** — a **99.6% reduction, 224× faster**. QPU queue time and expert scientific review are excluded; the measure covers repetitive research preparation and artifact generation. | Timed benchmark recorded by the Bob Quantum Team across ten decomposed workflow stages. |
| 2 | **Five-or-more research handoffs per experiment** | One natural-language prompt replaces separate reference searching, algorithm comparison, assumption capture, design drafting, environment setup, Qiskit scaffolding, troubleshooting, notebook conversion, backend selection, visualization, and documentation. | Observable single-request-to-artifact path in every BQCA session. |
| 3 | **Manual environment provisioning** | BQCA automates virtual-environment creation, packaging upgrades, Qiskit dependency installation, Runtime and Qiskit Connector support, and import/version verification — before any code runs. | Ready execution environment and dependency verification produced on demand. |
| 4 | **Boilerplate Qiskit code rewriting** | Bob generates the authoritative `.py` implementation (circuit construction, parameters, execution logic, result handling, error handling, and documentation) directly from the user's request. | Grover Search, Uranium-234 VQE, and Oxygen VQE `.py` artifacts in `bob-quantum-store/`. |
| 5 | **Manual Python-to-notebook conversion** | Immediately after the `.py` file is written, BQCA auto-generates and validates the same-name `.ipynb` notebook. One source always produces two aligned delivery formats; notebook drift is eliminated. | Sibling `.py` / `.ipynb` artifact pairs confirmed for every generated workload. |
| 6 | **Repeated backend-status checks and code rewrites** | BQCA uses Qiskit Connector to resolve the account plan, checks QPU availability and qubit capacity, attempts real-QPU execution first, and falls back automatically to a simulator. Output records `REAL_QPU` or `SIMULATOR` plus the fallback reason. | Backend-fallback output in the repository; no manual status portal visit or code edit required. |

**Cross-team reuse multiplier:** IBM Research teams can clone the appliance, configure approved credentials, and reuse all modes, skills, rules, validators, notebook automation, backend policy, and the governed folder contract — changing only the research question, algorithm, data, or Hamiltonian. The same friction reduction applies immediately to new teams without rebuilding anything.

**Human control retained:** Domain experts approve scientific assumptions and results. BQCA removes only the repetitive preparation layer and records the full artifact chain for review, audit, and Git-tracked reuse.

---

#### BQCA Concrete Evidence of Productivity Gains and Workflow Automation Provided

> **watsonx Challenge 2026 Judging Evidence — Practicality, Coherence, Creativity & Innovation**

The ten evidence items below correspond directly to the judging criteria. Each is a concrete, observable, or measurable outcome produced by the BQCA appliance during the challenge window. See the automation-evidence pages and the Git repository for artifact-level detail.

##### Evidence 1 — Measured 44.60-Hour Weekly Productivity Gain

The benchmark boundary starts when a user submits a defined quantum request and stops when BQCA has produced the structured design, validated Python source, synchronized notebook, execution path, results/plots (where run), and review documentation. The team decomposed that same scaffolded workflow into **ten activities**. The manual baseline totaled **44.8 hours/week**; BQCA completed the defined preparation in **0.20 hours (12 minutes)**, saving **44.60 hours/week (99.6%; 224×)**. QPU queue time and expert scientific review are excluded — the measure is specifically repetitive research preparation and artifact generation.

| Stage | Manual Time Contribution | BQCA Handling |
|---|---|---|
| Research framing & literature search | High | Single guided interaction |
| Algorithm comparison & selection | High | Bob decomposes and selects |
| Assumption capture & validation plan | Medium | Structured design document |
| Environment setup | Medium | Automated provisioning |
| Qiskit boilerplate scaffolding | High | Prompt-to-production `.py` |
| Code debugging & repair | High | Automated validation & repair loop |
| Notebook conversion | Medium | Auto-generated `.ipynb` sibling |
| Backend selection & configuration | Medium | Qiskit Connector resolution |
| Visualization & result packaging | Medium | Governed artifact routing |
| Review documentation assembly | Medium | Complete evidence package |

##### Evidence 2 — Quantum Research-to-Design Automation

Before BQCA, a practitioner typically searches multiple references, records assumptions, compares algorithms, selects a circuit approach, drafts a backend strategy, and writes a validation plan as **separate activities**. With BQCA, one natural-language request is decomposed by Bob into a structured design containing the problem statement, selected algorithm, qubit and circuit assumptions, QPU-versus-simulator strategy, validation criteria, risks, and expected artifacts. The observable output is a **reusable design document** in `bob-quantum-designs/`. This converts at least five research and planning handoffs into one guided interaction plus expert review.

##### Evidence 3 — Automatic Quantum Qiskit Virtual Runtime Environment Provisioning

After the user's secured account configuration is available, BQCA creates the quantum/Qiskit runtime environment without repeated manual setup. The automated flow replaces separate actions to create and activate a virtual environment, upgrade packaging tools, install Qiskit dependencies, add Runtime and Qiskit Connector support, and verify imports and versions. This removes **setup variability between users** and allows the researcher to focus on the quantum objective rather than reproducing workstation preparation steps.

##### Evidence 4 — Prompt-to-Production Qiskit Python Generation

A code request does not end with a prose recommendation. Bob produces the **authoritative Python implementation** in `bob-quantum-store/`, including circuit or algorithm construction, parameters, execution logic, result handling, error handling, and documentation appropriate to the request. This replaces starting from a blank editor, finding boilerplate, reconciling package versions, wiring execution, and manually assembling output handling. The productivity gain is observable as **one user request producing a reviewable `.py` artifact**. Human review remains required, but the repetitive scaffold and first implementation pass are automated.

**Concrete artifacts produced:**
- `grover_search.py` / `grover_search.ipynb` — Grover Search algorithm
- `uranium_234_vqe.py` / `uranium_234_vqe.ipynb` — Uranium-234 VQE molecular simulation
- `oxygen_vqe.py` / `oxygen_vqe.ipynb` — Oxygen VQE molecular simulation

##### Evidence 5 — Automatic Python-to-Jupyter Notebook Generation

Immediately after the authoritative `.py` implementation is completed, the BQCA notebook tool automatically creates the same-name `.ipynb` file and validates it. **One source file produces two aligned delivery formats**: production-oriented Python and an interactive notebook for explanation, demonstration, and review. This eliminates manual copy-and-paste into notebook cells, repeated metadata creation, and source/notebook drift. When the Python source changes, the notebook can be regenerated so the code remains authoritative and synchronized.

##### Evidence 6 — Automatic Qiskit Connector Account and Backend Configuration

BQCA uses Qiskit Connector behavior to resolve the user's IBM Quantum account plan and obtain an account-accessible backend as part of generated code. The user no longer has to open a separate portal, inspect plan details, copy a backend name, and rebuild configuration logic for each workload. This **standardizes backend access** across generated workloads and reduces configuration errors.

##### Evidence 7 — Real-QPU-First Decision with Automatic Simulator Fallback

BQCA checks whether the selected backend is a real QPU, whether it is operational, and whether it has enough qubits for the circuit. It attempts the real backend first when the user's account has an eligible QPU. If no suitable QPU is available, a controlled `try/except` path immediately executes with a supported simulator. The output states `REAL_QPU` or `SIMULATOR` and records the fallback reason. This **removes manual status checks and code rewrites** while preventing a workflow from stopping merely because hardware is unavailable.

##### Evidence 8 — Automatic Quantum Code Troubleshooting and Repair

Generated implementations pass through syntax and policy validation before BQCA reports completion. The checks identify issues such as invalid Python, missing required connector behavior, missing real-QPU-first logic, absent simulator fallback, or an out-of-date notebook. Bob uses the failure information to **repair the implementation and rerun validation**. The former manual loop of edit → execute → inspect traceback → search for a fix → edit again → recreate companion artifacts is compressed into an **automated repair cycle**.

##### Evidence 9 — Governed Artifact Routing and Complete Evidence Package

BQCA routes architecture and research designs to `bob-quantum-designs/` and executable assets to `bob-quantum-store/`. A completed workflow includes the design, authoritative Python source, generated notebook, result data, plots, execution notes, and review documentation — rather than leaving artifacts scattered across user folders. Existing Mercury VQE and Uranium-234 VQE artifact sets demonstrate this reusable pattern. The resulting package is **easier to audit, review, reuse, and commit** through normal Git workflows.

| Artifact | Location | Status |
|---|---|---|
| Algorithm design documents | `bob-quantum-designs/` | ✓ Produced |
| Grover Search `.py` + `.ipynb` | `bob-quantum-store/` | ✓ Produced |
| Uranium-234 VQE `.py` + `.ipynb` | `bob-quantum-store/` | ✓ Produced |
| Oxygen VQE `.py` + `.ipynb` | `bob-quantum-store/` | ✓ Produced |
| Backend-fallback execution output | `bob-quantum-store/` | ✓ Recorded |
| Convergence plots (PNG) | `bob-quantum-store/` | ✓ Produced |

##### Evidence 10 — Reusable IBM Research Team Deployment and Session Continuity

An IBM Research team can clone the repository, set approved credentials, launch `xLaunchpad.sh`, and reuse the **same modes, skills, rules, validators, notebook generator, QPU/simulator policy, and governed folder contract**. Chemistry researchers substitute a molecule or Hamiltonian; optimization researchers substitute a QUBO/QAOA problem; algorithm researchers substitute a search oracle. The common research-to-artifact automation remains unchanged.

Menu option **5 resumes the latest activity** so assumptions, files, and decisions are not reconstructed. Grover, Uranium-234 VQE, Oxygen VQE, and backend-fallback artifacts demonstrate the same appliance pattern across different research workloads.

> **Summary for IBM Research Judges:** BQCA is not a demo — it is a production-deployed IBM Bob 1.0.6 appliance with a real launcher, custom modes/skills/rules/tools, governed design/store directories, Qiskit and Runtime integration, validation, notebook automation, and security controls. A shared repository and output contract support **immediate reuse by other IBM Research teams**. The measured 224× acceleration and the full artifact chain constitute the concrete, verifiable evidence of productivity gain required by the watsonx Challenge 2026 judging criteria.

---

#### How IBM Bob Was Used in BQCA to Automate Research Tasks or Improve Productivity

> **Judging Committee Response — Bob-Driven Features: Code Generation, Documentation, Workflow Orchestration, and Measurable Productivity Impact**

This section directly addresses the judging committee feedback requesting explicit evidence of how IBM Bob was used to automate research tasks and improve productivity. Every capability below is Bob-driven — meaning IBM Bob is the active agent that classifies intent, decomposes work, generates code, creates documentation, orchestrates the pipeline, and enforces governance. Qiskit, Qiskit Connector, and IBM Quantum hardware are the execution targets that Bob orchestrates. The measurable impact of each feature is stated explicitly.

---

##### Bob-Driven Feature 1 — Quantum Code Generation from Natural Language

IBM Bob is the sole author of every Qiskit Python file produced by BQCA. When a researcher selects menu option 3 and submits a natural-language request, Bob: (1) classifies the quantum algorithm required, (2) clarifies missing parameters through guided dialogue, (3) decomposes the implementation into circuit construction, parameter initialization, execution logic, result handling, error handling, and inline documentation, and (4) writes the complete `.py` file to `bob-quantum-store/` in a single, validated pass. No human writes boilerplate, no human searches Qiskit API docs during generation, and no human manually wires execution paths.

**Concrete Bob-generated code artifacts (produced during the challenge window):**

- `bob-quantum-store/grover_search.py` — Grover Search oracle, amplitude amplification, QPU execution, histogram output
- `bob-quantum-store/uranium_234_vqe.py` — VQE with UCCSD ansatz, Jordan-Wigner mapping, Qiskit Connector init, energy convergence loop
- `bob-quantum-store/oxygen_vqe.py` — hardware-efficient VQE for O2, Open Plan backend resolution, simulator fallback

**Measurable impact:** The same code-generation task that took a quantum developer 4–8 hours manually (algorithm selection, API research, scaffolding, execution wiring, testing) takes Bob 3–8 minutes. Across the ten-stage benchmark, Bob reduced total preparation time from 44.8 hours to 0.20 hours — a 99.6% reduction (224× faster). Code generation is the single largest contributor to that saving.

---

##### Bob-Driven Feature 2 — Automated Research Documentation in `bob-quantum-designs/`

When a researcher selects menu option 4 (Advanced Quantum Solution Design Concierge), Bob does not simply answer a question — it produces a structured, governed Markdown design document and saves it to `bob-quantum-designs/`. Each document contains: problem statement, selected quantum algorithm with justification, qubit and circuit assumptions, QPU-versus-simulator strategy, validation criteria, risk assessment, and expected artifact checklist. This is research documentation generated entirely by Bob from a single natural-language prompt.

**Concrete Bob-generated design documents (in `bob-quantum-designs/`):**

- Mercury VQE design — molecular simulation design for Mercury, full algorithm and circuit plan
- Uranium-234 VQE design — nuclear binding energy estimation design with backend strategy
- Oxygen VQE design — O2 ground-state chemistry simulation design with Open Plan constraints

**What Bob replaces:** Before BQCA, a researcher spent 3–5 hours per experiment on: literature search (1 hr), algorithm comparison (1 hr), assumption documentation (30 min), backend strategy (30 min), and risk capture (30 min) — all as separate unstructured activities. Bob compresses all five into one 5-minute guided interaction that produces a reusable, auditable Markdown artifact.

**Measurable impact:** Five research planning handoffs per experiment eliminated. Documentation is produced consistently across every researcher on the team — no tribal knowledge, no format variance, no missing sections.

---

##### Bob-Driven Feature 3 — End-to-End Workflow Orchestration (Ten Stages, One Prompt)

The most critical Bob-driven feature in BQCA is that IBM Bob orchestrates the entire quantum research workflow end-to-end from a single user prompt. Bob does not generate code and stop. It drives every stage of the pipeline in sequence, passing outputs between stages automatically.

| Stage | What Bob Orchestrates | Human Input Required | Measurable Saving |
|---|---|---|---|
| 1. Research framing | Classifies the quantum objective, identifies the algorithm family, and structures the research question. | Initial natural-language prompt only | Eliminates 1+ hour of unstructured literature framing per experiment |
| 2. Algorithm selection | Reasons about the problem structure and recommends VQE, QAOA, Grover, QPE, or other algorithm with written justification. | None after clarification | Eliminates 30–60 min algorithm comparison time |
| 3. Design document creation | Writes the structured Markdown design to `bob-quantum-designs/` including all assumptions and strategy. | Expert review of scientific assumptions | Eliminates 2–3 hours of manual documentation |
| 4. Virtual environment provisioning | Creates the Qiskit venv, installs SDK + Runtime + Connector, and verifies imports — before any code runs. | None | Eliminates 30–60 min of per-researcher environment setup variance |
| 5. Qiskit Python generation | Writes the complete, documented `.py` implementation to `bob-quantum-store/`. | None | Eliminates 4–8 hours of manual coding and API research |
| 6. Validation and auto-repair | Validates syntax, checks QPU-first policy, fallback logic, and no-secret rule. Repairs and revalidates on failure automatically. | None | Eliminates the manual edit-debug-retry cycle (30 min–2 hrs per bug) |
| 7. Notebook generation | Generates the same-name `.ipynb` sibling from the validated `.py` and verifies it. | None | Eliminates 1–2 hours of manual notebook cell copy-paste and metadata setup |
| 8. Backend resolution | Uses Qiskit Connector to resolve IBM Quantum account plan and select an accessible backend. | None after `.env` config | Eliminates repeated portal visits and manual backend name lookup |
| 9. QPU / simulator execution | Attempts real QPU first; falls back to simulator under controlled policy; records execution target and reason. | None | Eliminates manual status checks and code rewrites when hardware changes |
| 10. Result and artifact packaging | Routes results, plots, and notes to `bob-quantum-store/` with predictable naming. | None | Eliminates file-naming decisions, folder creation, and result scatter |

**Measurable impact:** Total workflow time: **44.8 hours manually** vs. **0.20 hours (12 minutes) with Bob orchestration**. 44.60 hours saved per experiment cycle. 99.6% reduction. 224× faster.

---

##### Bob-Driven Feature 4 — Automatic Code Troubleshooting and Repair

After generating a Qiskit Python implementation, Bob passes the code through a validation loop that checks: Python syntax correctness, presence of Qiskit Connector initialization, real-QPU-first execution logic, simulator fallback in a `try/except` block, absence of hardcoded credentials, and currency of the sibling `.ipynb` notebook. If any check fails, Bob reads the failure output, identifies the root cause, repairs the implementation, and revalidates — without any user action.

**What Bob replaces:** The manual quantum debugging cycle: run code → read traceback → search StackOverflow / Qiskit docs → edit → re-run → verify companion artifacts. Each iteration of this loop typically costs 15–45 minutes.

**Measurable impact:** Routine first-line detection and correction of code defects is fully automated. Human review is still required for scientific correctness, but not for syntax errors, missing imports, wrong API calls, or policy violations.

---

##### Bob-Driven Feature 5 — Automatic Jupyter Notebook Generation and Synchronization

Immediately after Bob validates the `.py` source, it triggers automatic Jupyter notebook generation. The `.ipynb` is created, populated with the same code structured into titled cells for circuit definition, execution, result display, and visualization, and then validated. If the `.py` source is later changed, the notebook can be regenerated by Bob to stay synchronized.

**Concrete Bob-generated notebook artifacts:**

- `bob-quantum-store/grover_search.ipynb` — sibling of `grover_search.py`, auto-generated and validated
- `bob-quantum-store/uranium_234_vqe.ipynb` — sibling of `uranium_234_vqe.py`, includes convergence cell
- `bob-quantum-store/oxygen_vqe.ipynb` — sibling of `oxygen_vqe.py`, includes fallback output cell

**Measurable impact:** Every code artifact in BQCA has a companion notebook at zero additional user effort. Source-notebook drift — one of the most common causes of reproducibility failures in quantum research — is eliminated by design.

---

##### Bob-Driven Feature 6 — Session Resume for Continuous Research Without Restart Friction

IBM Bob maintains session context across interactions. Menu option 5 restores the most recent BQCA activity — including the research objective, generated artifacts, design decisions, and execution state — so a researcher returning after an interruption does not need to re-state the problem, re-enter parameters, or re-locate previously generated files.

**Measurable impact:** Session startup time drops from 15–30 minutes (reconstructing context, finding files, re-reading prior outputs) to under 1 minute. For a researcher running 3–5 BQCA sessions per week, this recovers 45–150 minutes of productive research time weekly.

---

##### Bob-Driven Feature 7 — Cross-Team Reuse: Bob Configuration as a Shared Research Accelerator

All of Bob's quantum behavior is encoded in shareable configuration files — custom modes (`.bob/custom_modes.yaml`), skills (`.bob/skills/`), rules (`.bob/rules-*/`), and tool guidance (`.bob/quantum-tools/README.md`). Any IBM Research team can clone the repository, configure IBM credentials, and immediately receive the same Bob-driven code generation, documentation, validation, notebook generation, and artifact routing. No custom development is required. Only the research question changes.

**Measurable impact:** Time-to-first-governed-quantum-artifact for a new IBM Research team: under 15 minutes from clone to first Bob-generated `.py` + `.ipynb` pair.

---

##### Bob Research Automation Flow (End-to-End)

**Bob-driven research automation flow:** user prompt → IBM Bob intent classification and clarification → algorithm/design decomposition → design documentation in `bob-quantum-designs/` → production Qiskit code generation → validation and auto-repair → notebook generation → Qiskit Connector backend resolution → real-QPU attempt → simulator fallback (if required) → result packaging in `bob-quantum-store/` → human expert review → Git commit.

| IBM Bob-Driven Feature | How IBM Bob Automates the Research Task | Productivity or Research Impact |
|---|---|---|
| Research framing and task decomposition | Bob interprets the research objective, asks for missing parameters, identifies the appropriate quantum method, and decomposes the work into design, implementation, validation, execution, visualization, and documentation tasks. | Replaces multiple manual research handoffs with one guided interaction and reduces failed starts caused by incomplete requirements. |
| Design and documentation generation | Bob creates a structured research/design document containing the problem statement, algorithm rationale, circuit and qubit assumptions, backend strategy, validation criteria, risks, and expected artifacts, then routes it to `bob-quantum-designs/`. | Produces a reusable, reviewable design before code execution and improves scientific traceability across team members. |
| Production Qiskit code generation | For menu option 3, Bob generates the authoritative Python implementation, including circuit or algorithm construction, parameters, Qiskit Connector initialization, real-QPU-first logic, simulator fallback, result handling, error handling, and inline documentation. | Removes blank-editor work, Qiskit boilerplate recreation, and repeated version reconciliation. Grover Search, Uranium-234 VQE, and Oxygen VQE are concrete outputs. |
| Validation, troubleshooting, and repair | Bob applies BQCA rules and validators to check syntax, required Connector behavior, no-secret handling, QPU-first policy, fallback behavior, and notebook currency. When a check fails, Bob uses the failure details to repair and revalidate the implementation. | Compresses the manual edit-run-debug-search-edit cycle and improves consistency of generated research code. |
| Notebook and evidence generation | After Python validation, Bob triggers creation and validation of the same-name Jupyter notebook and prepares result files, plots, execution notes, and review documentation in `bob-quantum-store/`. | One prompt produces both production-oriented Python and an interactive research notebook while preventing source/notebook drift. |
| Workflow and backend orchestration | Bob coordinates the sequence of BQCA skills and tools. Qiskit Connector resolves the account plan and accessible backend; Bob enforces the execution policy, records `REAL_QPU` or `SIMULATOR`, and preserves the fallback reason. | Eliminates repeated portal checks, manual backend-name selection, and code rewrites when hardware availability changes. |
| Governed artifact management | Bob enforces the folder contract: designs and research documentation go to `bob-quantum-designs/`; code, notebooks, results, plots, logs, and implementation documentation go to `bob-quantum-store/`. | Makes every artifact predictable, auditable, reusable, Git-reviewable, and easier to hand off across IBM Research teams. |
| Session continuity and cross-team reuse | Menu option 5 restores the prior Bob activity and context. A new team can clone the appliance and reuse the same modes, skills, rules, validators, notebook automation, backend policy, and artifact contract. | Reduces restart effort and allows chemistry, optimization, and algorithm teams to change only the research question, molecule, Hamiltonian, data, or oracle. |

---

##### Consolidated Measurable Impact of IBM Bob Automation in BQCA

| Bob-Driven Feature | Research Task Automated | Manual Baseline | With IBM Bob | Saving |
|---|---|---|---|---|
| Code generation (Feature 1) | Write validated Qiskit `.py` from prompt | 4–8 hours | 3–8 minutes | ~98% reduction |
| Documentation (Feature 2) | Create structured research design document | 2–3 hours | 3–5 minutes | ~97% reduction |
| Workflow orchestration (Feature 3) | Complete 10-stage research-to-artifact pipeline | 44.8 hours/week | 0.20 hours (12 min) | **99.6% reduction, 224× faster** |
| Code repair (Feature 4) | Detect and fix code defects, policy violations | 15–45 min per bug | Seconds (automated) | Full elimination for routine defects |
| Notebook generation (Feature 5) | Create and synchronize `.ipynb` sibling | 1–2 hours | Automatic (< 30 sec) | ~99% reduction |
| Session resume (Feature 6) | Reconstruct research context after interruption | 15–30 min per session | < 1 minute | ~96% reduction |
| Cross-team reuse (Feature 7) | Set up quantum workflow for a new research team | Days to weeks | < 15 minutes | >95% reduction |

> **Statement to the IBM Research Judging Committee:** IBM Bob is not a peripheral component in BQCA — it is the central automation engine. Every research task that BQCA accelerates is accelerated because Bob classifies, decomposes, generates, validates, repairs, documents, and routes the work. Qiskit and IBM Quantum hardware are the execution substrate that Bob orchestrates. The seven Bob-driven features above, with their measurable savings, constitute the direct evidence that BQCA uses IBM Bob to automate quantum research tasks and improve researcher productivity — which is precisely what the watsonx Challenge 2026 asks for.

---

#### Bob as an AI Tool Used in BQCA and Why (IBM Bob Engine)

IBM Bob is used as the AI execution and reasoning engine behind BQCA because BQCA needs more than static quantum templates to bring value. Quantum-computing work often requires interpreting a user's scientific goal, choosing an appropriate quantum workflow, creating executable Qiskit code, selecting simulator or runtime behavior, generating artifacts, and explaining the result clearly.

| Why Bob is used in BQCA | Business and technical value |
|---|---|
| Natural-language quantum interaction | Users can ask for circuits, algorithms, VQE designs, or runtime workflows without manually composing every file. |
| Tool-enabled software generation | Bob can read, write, update, list, and validate files inside the quantum workspace. |
| Mode-driven task routing | BQCA custom modes guide Bob toward ask, code, plan, advanced design, orchestration, and quantum intelligence behaviors. |
| Persistent custom rules | BQCA rules enforce design/store separation, artifact verification, terminal-output discipline, visualization output, and Qiskit coding standards. |
| Reusable skill layer | Shared skills give BQCA reusable workflows for planning, MCP configuration, Git, Excel analysis, skill creation, and mode creation. |
| Quantum-specific guidance | The appliance instructs Bob to favor Qiskit 2.x-or-later patterns, IBM Quantum Runtime awareness, simulation discipline, and safe credential handling. |
| Repeatable artifact production | BQCA can generate durable Markdown designs, Python source files, `.txt` result files, and `.png` visualizations. |

---

#### Custom Bob Functionalities That Produced BQCA

| Custom Functionality Name | Description |
|---|---|
| BQCA custom modes | Workspace-scoped Bob modes in `.bob/custom_modes.yaml` that specialize Bob behavior for quantum ask, code, advanced circuit design, planning, orchestration, Qiskit connector behavior, Draw.io, GraphQL, and WXO agent architecture tasks. |
| BQCA custom skills | Workspace-scoped skills under `.bob/skills/` that provide reusable procedures for BQCA quantum work and shared Bob tasks such as plan creation, skill creation, mode creation, MCP configuration, MCP server building, Excel analysis, and Git version-control guidance. |
| BQCA custom rules | Mode-specific rule folders under `.bob/rules-*` that enforce BQCA behavior, including Qiskit development standards, artifact routing, read-after-write verification, MCP guard behavior, and design/store separation. |
| BQCA custom tool guidance | `.bob/quantum-tools/README.md` defines BQCA's quantum execution standards, Qiskit 2.x policy, visualization policy, terminal-output policy, backend/runtime guidance, and artifact discipline. |
| BQCA launcher menu | `bob-quantum-v1.0.6.sh` provides the interactive terminal menu for User Interactive, Quantum Assist, Quantum Code, Quantum Advanced, Resume, and Quit workflows. |
| BQCA version detector | `bob-version.sh` detects the Bob Shell version and exports `BOB_VERSION` so launchers and policy text can use persistent dynamic versioning. |
| BQCA xLaunchpad | `xLaunchpad.sh` loads `.env`, requires required Bob credentials, sources `bob-version.sh`, and starts the version-aware BQCA launcher. |
| BQCA design/store model | `bob-quantum-designs/` stores design-only Markdown artifacts; `bob-quantum-store/` stores executable implementation code and generated result artifacts. |

---

#### BQCA Custom Modes

| Mode Slug | Display Name | Purpose |
|---|---|---|
| `ask` | IBM Bob Quantum Sky™ | Quantum Q&A, explanations, architectural guidance, and user-facing quantum support. |
| `code` | IBM Bob Quantum Code Default™ / IBM Bob Quantum Code Heron™ | Qiskit code generation, artifact creation, quantum script updates, and simulation support. |
| `advanced` | IBM Bob Quantum Advanced Default™ / IBM Bob Quantum Advanced™ / IBM Bob Quantum Advanced Implementator™ | Advanced circuit design, quantum algorithm architecture, VQE/QAOA/QPE planning, and complex quantum solution implementation. |
| `orchestrator` | IBM Bob Quantum Smart™ / IBM Bob Quantum Orchestrator | Multi-step quantum work coordination, artifact planning, and task routing. |
| `plan` | IBM Bob Quantum Plan | Structured planning, design Markdown generation, and implementation planning with write-enabled plan artifacts. |
| `WXO Agent Architect` | IBM Bob Quantum WXO Agent Architect | Agent architecture workflows that may interact with quantum-adjacent automation or orchestration concepts. |
| `Draw.io` | IBM Bob Quantum Draw.io | Diagramming and architecture visualization support. |
| `GraphQL Dev` | IBM Bob Quantum GraphQL Dev | API and GraphQL development support when needed in quantum-adjacent workflows. |

> Note: The current BQCA custom modes file contains compatibility duplicate slugs for `code`, `advanced`, and `orchestrator`. This reflects the current production appliance state and should only be changed intentionally by a future patch.

---

#### BQCA Custom Skills

| Skill | Purpose |
|---|---|
| `bob-quantum-skill` | Main BQCA skill for Qiskit code generation, quantum circuit design, molecular simulation, VQE, saved artifact workflows, and BQCA behavior. |
| `create-plan` | Creates structured implementation plans before code changes or artifact generation. |
| `create-skill` | Guides creation of reusable Bob custom skills. |
| `create-mode` | Guides creation or update of Bob custom modes. |
| `configure-mcp` | Configures or diagnoses local and remote MCP servers for Bob. |
| `build-mcp-server` | Designs and scaffolds custom MCP servers. |
| `xlsx-insights` | Analyzes Excel workbooks through sampling, JSON dumps, and targeted extraction scripts. |
| `git-version-control` | Provides Git workflow, branching, tagging, recovery, release, and enterprise version-control guidance. |
| `mcp-tool-guard` | Prevents MCP workflows from failing due to missing or miscalled documentation-search helpers such as `search_docs` or `show_sections`. |

---

#### BQCA Custom Rules

| Rule Area | File / Folder | Role in BQCA |
|---|---|---|
| Ask rules | `.bob/rules-ask/` | Guides quantum question-answering behavior and prevents unsupported claims. |
| Code rules | `.bob/rules-code/` | Governs Qiskit/Python code creation, write-before-read behavior, and output verification. |
| Advanced rules | `.bob/rules-advanced/` | Supports advanced quantum circuit, algorithm, and implementation design. |
| Plan rules | `.bob/rules-plan/` | Ensures planning artifacts can be created and saved when requested. |
| Orchestrator rules | `.bob/rules-orchestrator/` | Coordinates multi-step quantum tasks and mode-aware routing. |
| Qiskit connector rules | `.bob/rules-qiskit-connector/` | Supports IBM Quantum and Qiskit connector-oriented patterns. |
| Quantum code rules | `.bob/rules-quantum-code/` | Strengthens quantum code generation and artifact execution behavior. |
| Quantum intelligence rules | `.bob/rules-quantum-intelligence/` | Adds quantum-domain intelligence and enterprise-quality response discipline. |
| Draw.io rules | `.bob/rules-Draw.io/` | Supports diagram generation or architecture visualization requests. |
| GraphQL Dev rules | `.bob/rules-GraphQL Dev/` | Supports API/GraphQL development when needed. |
| WXO Agent Architect rules | `.bob/rules-WXO Agent Architect/` | Supports agent architecture tasks while preserving BQCA domain behavior. |

---

#### BQCA Custom Tool Guidance

BQCA's main custom tool guidance is stored in `.bob/quantum-tools/README.md`. This file establishes the operational standards for quantum workflows.

| Tool Guidance Area | BQCA Behavior |
|---|---|
| Terminal output | Executable quantum workflows should print workflow name, package versions, backend or simulator, circuit metrics, shot count, results, success/failure status, and saved artifact paths when applicable. |
| PNG visualization | Circuit, measurement, VQE, QAOA, chemistry, and optimizer workflows should save meaningful PNG visualizations when applicable. |
| Headless plotting | Uses Matplotlib `Agg` style patterns so scripts can run in terminal, CI, or server environments. |
| Qiskit 2.x default | Newly generated code should prefer current Qiskit SDK 2.x-or-later patterns unless the user asks for legacy compatibility. |
| IBM Quantum credentials | Uses `.env` or runtime environment variables and must not hardcode tokens. |
| Artifact discipline | Code, results, and visualizations must be durable and saved to predictable paths. |
| Read-after-write safety | Generated files must be written and verified before being read or summarized. |
| MCP guard | MCP server tasks use local skills first and must not fail because documentation-search helpers are unavailable. |

---

#### IBM Bob BQCA Capabilities in Quantum

| Capability | Quantum Focus | Typical Output |
|---|---|---|
| Quantum question answering | Explains quantum computing concepts, circuits, gates, algorithms, and IBM Quantum workflows. | Natural-language explanations, comparisons, summaries, and guidance. |
| Qiskit code generation | Creates executable Qiskit Python workflows. | `.py` scripts under `bob-quantum-store/`. |
| Circuit design | Designs quantum circuits for simulation, analysis, or runtime execution. | Circuit diagrams, Markdown design files, and Qiskit circuit code. |
| VQE workflows | Designs and implements variational quantum eigensolver workflows for chemistry-style simulations. | VQE design docs, Python code, result text files, convergence plots. |
| QAOA workflows | Supports optimization-focused quantum algorithm planning and implementation. | QAOA design docs, Qiskit code, optimizer outputs, plots. |
| IBM Quantum Runtime guidance | Helps reason about runtime backends, instances, channels, credentials, and execution choices. | Runtime-aware code and configuration guidance. |
| Simulation workflows | Generates local simulator workflows using Qiskit Aer when appropriate. | Simulator code, counts/probability output, histograms. |
| Visualization workflows | Produces circuit drawings, histograms, convergence charts, and result graphics. | PNG files saved alongside generated code. |
| Artifact routing | Separates design artifacts from implementation artifacts. | Markdown in `bob-quantum-designs/`; code in `bob-quantum-store/`. |
| Quantum project productivity | Helps users move from idea to design, code, execution, results, and documentation. | Repeatable project folders and durable deliverables. |

---

#### IBM Bob BQCA Quantum Intelligence

BQCA's quantum intelligence is the combination of IBM Bob reasoning, BQCA-specific prompt policies, Qiskit coding standards, quantum artifact conventions, and production-grade file discipline. The appliance is designed to help users translate quantum intent into structured deliverables.

For example, a user can ask BQCA to design a VQE workflow for a target molecule. BQCA first recognizes whether the request is design-only or implementation-oriented. If it is design-only, BQCA routes the output to `bob-quantum-designs/` as Markdown. If the user asks for executable code, BQCA routes the implementation to `bob-quantum-store/`, writes the Python file, verifies that it exists, and then summarizes the path and run instructions.

BQCA also guides generated quantum code toward practical execution habits:

1. Use current Qiskit APIs by default.
2. State package assumptions.
3. Use environment variables for IBM Quantum credentials.
4. Prefer deterministic, executable scripts with `main()` functions.
5. Print useful execution summaries.
6. Save results and visualizations to durable files.
7. Avoid pretending that high-complexity quantum chemistry or heavy-element simulation is trivial.
8. Ask for missing backend, molecule, shot count, qubit count, or execution-risk details when required.

---

#### IBM Bob BQCA Quantum Use Cases in Industries

| Use Case | Industry | Business Value |
|---|---|---|
| VQE molecular-energy prototyping | Chemicals, materials science, pharmaceuticals | Helps research teams prototype molecular simulation workflows and explore future quantum advantage paths. |
| Quantum optimization workflow design | Logistics, transportation, supply chain | Supports modeling of routing, scheduling, and allocation problems with quantum optimization patterns. |
| Portfolio optimization experiments | Financial services | Enables early exploration of QAOA and hybrid quantum-classical optimization strategies. |
| Quantum education and enablement | Academia, enterprise training, workforce development | Speeds up learning by generating circuits, explanations, and executable examples. |
| Quantum circuit prototyping | Research labs, cloud engineering, quantum startups | Accelerates circuit design, simulation, visualization, and iteration. |
| IBM Quantum Runtime planning | Enterprises using IBM Quantum | Helps teams plan backend usage, runtime credentials, channel choices, and safe execution workflows. |
| Quantum proof-of-concept delivery | Enterprise innovation teams | Produces structured designs, implementation code, result artifacts, and presentation-ready outputs. |
| Quantum-safe exploration support | Cybersecurity and regulated industries | Assists with adjacent quantum concepts, cryptographic transition planning, and quantum-readiness discussions. |
| Scientific computing modernization | Energy, government, engineering | Bridges classical scientific computing workflows with emerging quantum algorithm exploration. |
| AI + quantum experimentation | AI research, data science, enterprise labs | Supports hybrid thinking across optimization, simulation, model experimentation, and algorithm research. |

---

#### Quantum Productivity Problems Solved by IBM Bob BQCA

| Productivity Problem | How BQCA Helps |
|---|---|
| Quantum code starts from a blank page | BQCA generates structured Qiskit code from natural-language intent. |
| Designs and code get mixed together | BQCA separates `bob-quantum-designs/` from `bob-quantum-store/`. |
| Generated code is not verified | BQCA rules require write-before-read verification and saved path reporting. |
| Results disappear after terminal execution | BQCA encourages durable `.txt` result files and PNG artifacts. |
| Quantum users forget visualization output | BQCA instructs workflows to save circuit diagrams, histograms, and convergence plots. |
| Legacy Qiskit examples create confusion | BQCA defaults to Qiskit 2.x-or-later guidance unless legacy compatibility is requested. |
| Credentials are mishandled | BQCA requires `.env` or runtime variables and discourages hardcoded tokens. |
| Quantum runtime choices are unclear | BQCA prompts for backend, IBM Quantum instance, channel, shot count, and execution context when needed. |
| Heavy quantum chemistry is oversimplified | BQCA rules encourage realistic statements about package assumptions and computational complexity. |
| Users need repeatable project assets | BQCA creates saved design files, code files, result files, and visualizations in predictable directories. |

---

#### IBM Bob BQCA File Analysis Table

| File / Directory | Purpose |
|---|---|
| `.env.example` | Template for Bob credentials, endpoints, Bob included directories, appliance name, and IBM Quantum plan/channel variables. |
| `.env` | Runtime environment file. Do not commit real secrets. Do not print or share its values. |
| `xLaunchpad.sh` | Entry script that loads Bob version and environment variables, validates required Bob settings, and starts the BQCA launcher. |
| `bob-version.sh` | Detects Bob Shell version through `bob --version` and exports `BOB_VERSION`. |
| `bob-quantum-v1.0.6.sh` | Main BQCA interactive launcher with the BQCA menu and Bob command invocations. |
| `bob-auth.sh` | Authenticates Bob Shell before menu actions execute. |
| `bob-auth.md` | Documents Bob authentication behavior and environment expectations. |
| `tls-control.sh` | TLS helper used by the appliance launch scripts. |
| `.bob/custom_modes.yaml` | Defines BQCA custom modes and mode-level behavior. |
| `.bob/skills/bob-quantum-skill/SKILL.md` | Main BQCA domain skill. |
| `.bob/skills/*/SKILL.md` | Shared Bob productivity skills available to BQCA. |
| `.bob/rules-*/*.md` | Mode-specific BQCA rules and policies. |
| `.bob/quantum-tools/README.md` | BQCA tool guidance, Qiskit policy, output policy, and artifact policy. |
| `.bob/notes/pending-notes.txt` | Placeholder for pending notes. |
| `.bob/patches-applied/` | Patch tracking for applied BQCA updates. |
| `bob-quantum-designs/` | Design-only Markdown artifacts. |
| `bob-quantum-store/` | Generated Qiskit/Python code, result files, and visualization artifacts. |
| `.git/` | Git repository metadata. |

---

#### Challenge Alignment

This document supports the IBM Bob BQCA watsonx challenge submission by documenting algorithm coverage for the solution statement, technical statement, and solution impact areas.

Relevant impact categories include:

- Simplify personal and team processes
- Reduce time and manual effort for routine quantum tasks
- Improve accuracy and consistency of generated outputs
- Reduce operational risk through governed artifact routing
- Reduce time and effort accessing quantum information
- Speed up product and offering development
- Support innovation and exploration of new quantum features
- Improve code quality and maintenance

---

#### Maintainer Notes

Suggested future additions:

- Add links to internal BQCA design examples.
- Add Qiskit code snippets for top-priority algorithms.
- Add algorithm-to-use-case mapping tables.
- Add backend-readiness notes for IBM Quantum hardware execution.
- Add estimated before-and-after time savings from BQCA workflows.
- Add example prompts for each algorithm family.
