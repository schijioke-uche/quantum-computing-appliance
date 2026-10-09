# IBM Bob Quantum Computing Agent (BQCA)

**IBM Bob Quantum Computing Agent (BQCA)** is a domain-specialized IBM Bob appliance designed to help quantum practitioners, platform engineers, researchers, and enterprise innovation teams plan, build, validate, and operationalize quantum-computing workflows. BQCA combines IBM Bob Shell, custom Bob modes, custom Bob skills, custom rules, and BQCA-specific tool guidance to produce a guided quantum development environment for Qiskit, IBM Quantum Runtime, circuit design, VQE workflows, simulation, visualization, and quantum solution planning.

**Author:** Bob Quantum Team (Inspired by IBM 2026 watsonx Challenge)

---

## 1. BQCA Appliance Snapshot

| Feature | Description |
|---|---|
| Appliance name | IBM Bob Quantum Computing Agent (BQCA) |
| Root folder in archive | `quantum/` |
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

# Background of BQCA Appliance

## 2. Executive Summary

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

## 3. Bob as an AI Tool Used in BQCA and Why

IBM Bob is used as the AI execution and reasoning engine behind BQCA because BQCA needs more than static quantum templates to bring value. Quantum-computing work often requires interpreting a user’s scientific goal, choosing an appropriate quantum workflow, creating executable Qiskit code, selecting simulator or runtime behavior, generating artifacts, and explaining the result clearly.

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

## 4. Custom Bob Functionalities That Produced BQCA

| Custom Functionality Name | Description |
|---|---|
| BQCA custom modes | Workspace-scoped Bob modes in `.bob/custom_modes.yaml` that specialize Bob behavior for quantum ask, code, advanced circuit design, planning, orchestration, Qiskit connector behavior, Draw.io, GraphQL, and WXO agent architecture tasks. |
| BQCA custom skills | Workspace-scoped skills under `.bob/skills/` that provide reusable procedures for BQCA quantum work and shared Bob tasks such as plan creation, skill creation, mode creation, MCP configuration, MCP server building, Excel analysis, and Git version-control guidance. |
| BQCA custom rules | Mode-specific rule folders under `.bob/rules-*` that enforce BQCA behavior, including Qiskit development standards, artifact routing, read-after-write verification, MCP guard behavior, and design/store separation. |
| BQCA custom tool guidance | `.bob/quantum-tools/README.md` defines BQCA’s quantum execution standards, Qiskit 2.x policy, visualization policy, terminal-output policy, backend/runtime guidance, and artifact discipline. |
| BQCA launcher menu | `bob-quantum-v1.0.6.sh` provides the interactive terminal menu for User Interactive, Quantum Assist, Quantum Code, Quantum Advanced, Resume, and Quit workflows. |
| BQCA version detector | `bob-version.sh` detects the Bob Shell version and exports `BOB_VERSION` so launchers and policy text can use persistent dynamic versioning. |
| BQCA xLaunchpad | `xLaunchpad.sh` loads `.env`, requires required Bob credentials, sources `bob-version.sh`, and starts the version-aware BQCA launcher. |
| BQCA design/store model | `bob-quantum-designs/` stores design-only Markdown artifacts; `bob-quantum-store/` stores executable implementation code and generated result artifacts. |

---

## 5. BQCA Custom Modes

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

## 6. BQCA Custom Skills

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

## 7. BQCA Custom Rules

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

## 8. BQCA Custom Tool Guidance

BQCA’s main custom tool guidance is stored in:

```text
.bob/quantum-tools/README.md
```

This file establishes the operational standards for quantum workflows.

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

## 9. IBM Bob BQCA Capabilities in Quantum

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

## 10. IBM Bob BQCA Quantum Intelligence

BQCA’s quantum intelligence is the combination of IBM Bob reasoning, BQCA-specific prompt policies, Qiskit coding standards, quantum artifact conventions, and production-grade file discipline. The appliance is designed to help users translate quantum intent into structured deliverables.

For example, a user can ask BQCA to design a VQE workflow for a target molecule. BQCA should first recognize whether the request is design-only or implementation-oriented. If it is design-only, BQCA routes the output to `bob-quantum-designs/` as Markdown. If the user asks for executable code, BQCA routes the implementation to `bob-quantum-store/`, writes the Python file, verifies that it exists, and then summarizes the path and run instructions.

BQCA also guides generated quantum code toward practical execution habits:

1. Use current Qiskit APIs by default.
2. State package assumptions.
3. Use environment variables for IBM Quantum credentials.
4. Prefer deterministic, executable scripts with `main()` functions.
5. Print useful execution summaries.
6. Save results and visualizations to durable files.
7. Avoid pretending that high-complexity quantum chemistry or heavy-element simulation is trivial.
8. Ask for missing backend, molecule, shot count, qubit count, or execution-risk details when required.

This makes BQCA useful not only for writing code, but also for teaching quantum workflows, creating reusable assets, preparing technical demonstrations, and supporting enterprise quantum exploration.

---

## 11. IBM Bob BQCA Quantum Use Cases in Industries

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

## 12. Quantum Productivity Problems Solved by IBM Bob BQCA

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

## 13. IBM Bob BQCA File Analysis Table

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

# How to Use BQCA Appliance

## 14. Clone the Repository

```bash
git clone <repository-url>
```

Replace `<repository-url>` with the Git repository that contains the IBM Bob appliance project.

## 15. Go to the BQCA Directory

Depending on your repository layout, use one of these patterns:

```bash
cd ibm-bob-operations/use-cases/quantum-computing-agent
```

or, if the extracted appliance root is directly named `quantum-computing-agent`:

```bash
cd quantum-computing-agent
```

## 16. Create the Runtime Environment File

```bash
cp .env.example .env
```

## 17. Fill Out Required `.env` Variables

Open `.env` and provide the required values.

Minimum Bob runtime variables:

```bash
export BOB_API_KEY="<your-bob-api-key>"
export BOB_INSTANCE_ID="<your-bob-instance-id>"
export BOB_ENDPOINT="https://api.us-east.bob.ibm.com"
export BOB_AUTH_ENDPOINT="https://console-ibm-prod.verify.ibm.com"
export BOB_REGION="us-east"
export APPLIANCE_NAME="IBM Bob Quantum Computing Agent (BQCA)"
```

Quantum-specific variables to review:

```bash
export IQP_API_TOKEN="<your-ibm-quantum-token>"
export OPEN_PLAN_CHANNEL="ibm_cloud"
export PAID_PLAN_CHANNEL="ibm_quantum"
export IQP_API_URL="https://auth.quantum-computing.ibm.com/api/users/loginWithToken"
export IQP_RUNTIME_BACKEND_URL="https://api.quantum-computing.ibm.com/runtime/backends"
export CLOUD_API_URL="https://cloud.ibm.com"
export QUANTUM_API_URL="https://auth.quantum.ibm.com/api"
export OPEN_PLAN_INSTANCE=""
export PAID_PLAN_INSTANCE=""
export OPEN_PLAN="on"
export FLEX_PLAN="off"
export PAYGO_PLAN="off"
export PREMIUM_PLAN="off"
export DEDICATED_PLAN="off"
```

Do not hardcode real tokens into generated source files. Keep secrets in `.env` or your enterprise secret-management system.

## 18. Verify Bob Shell

```bash
bob --version
```

The appliance uses `bob-version.sh` to detect the Bob Shell version and export:

```bash
BOB_VERSION
```

The current BQCA launcher is version-resolved as:

```text
bob-quantum-v1.0.6.sh
```

## 19. Start the Appliance

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


### IBM Bob Quantum Computing Agent (BQCA) - Quantum Algorithms Catalog

The catalog is organized for quantum and BQCA use cases such as:

- Quantum Computing Algorithms Concierge
- Advanced Quantum Computing Circuit Design
- VQE and chemistry workflows
- QAOA and optimization workflows
- Quantum circuit design and documentation
- IBM Quantum backend and simulator execution planning
- Qiskit and IBM Quantum Runtime implementation support
- Quantum education and workforce enablement

> Note: Quantum computing research evolves continuously. This BQCA catalog is intended as a broad practical reference for known major algorithms and algorithm families, not as a formal proof that every published variant is included.

---

## Table of Contents

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
15. [BQCA Usage Guidance](#bqca-usage-guidance)

---

## BQCA Priority Algorithm Set

For the IBM Bob BQCA solution, the following algorithm set should be prioritized as the visible and explainable supported coverage.

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

## Foundational and Core Quantum Algorithms

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

## Search, Oracle, and Query Algorithms

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

## Number Theory, Algebra, and Cryptanalysis

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

## Quantum Simulation and Physics Algorithms

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

## Chemistry, Materials, and Molecular Simulation

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

## Optimization Algorithms

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

## Linear Algebra and Matrix Algorithms

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

## Machine Learning and AI Algorithms

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

## Variational and NISQ Algorithms

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

## Quantum Walk Algorithms

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

## Sampling and Complexity-Oriented Algorithms

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

## Communication, Cryptography, and Protocol Algorithms

These are often described as quantum protocols rather than algorithms, but they are useful for BQCA quantum education, architecture design, and solution framing.

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

## Error Correction, Fault Tolerance, and Compilation Algorithms

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

## BQCA Usage Guidance

When using this quantum algorithm catalog when running BQCA, route the request into the appropriate BQCA workflow of >> DESIGN or >> IMPLEMENTATION. The following guidance is recommended:

### Ask Quantum Computing Question

Use this path when the user wants explanation, comparison, algorithm selection guidance, or conceptual clarification.

Examples:

- Explain Grover's algorithm.
- Compare VQE and QAOA.
- What algorithm should I use for molecular ground-state estimation?
- How does phase estimation relate to Shor's algorithm?
- Design a quantum circuit for a 3-qubit GHZ state.
- Create a qiskit v2 code for the design of quantum circuit for a 3-qubit GHZ state and run the implementation on a simulator on a qiskit v2 virtual environment.
- Create a qiskit v2 code for the design of quantum circuit for a 3-qubit GHZ state and run the implementation on a real quantum backend using Quantum Qiskit Connector on a qiskit v2 virtual environment.

### Quantum Computing Algorithms Concierge

Use this path when the user wants implementation guidance, code generation, Qiskit examples, algorithm modification, or experiment scaffolding.

Examples:

- Generate a Qiskit v2 VQE workflow design.
- Create a QAOA MaxCut design with qiskit v2.
- Create a qiskit v2 code for a search problem of Grover oracle for this QAOA MaxCut design .
- Modify this circuit to run on an real IBM Quantum backend.

### Advanced Quantum Computing Circuit Design

Use this path when the user wants a circuit architecture, a deeper quantum workflow design, backend execution planning, simulation strategy, or production-quality quantum experiment plan.

Examples:

- Design a VQE circuit and execution plan for a chemistry simulation.
- Create a QAOA circuit design for a routing optimization problem.
- Plan a simulator-to-real-QPU execution workflow.
- Create a design document for a quantum algorithm experiment.

---

## Recommended BQCA Output Pattern

For algorithm-related user requests, BQCA will produce outputs using this structure:

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

Use design and implementation separation to keep the BQCA appliance governed and reusable.

| Artifact Type | Recommended Location | Examples |
| --- | --- | --- |
| Design document | `bob-quantum-designs/` | Algorithm design, architecture plan, backend strategy |
| Executable code | `bob-quantum-store/` | Python scripts, Qiskit notebooks, runtime jobs |
| Results | `bob-quantum-store/` | JSON, CSV, simulator counts, backend results |
| Visualizations | `bob-quantum-store/` | Circuit diagrams, histograms, plots, PNG files |
| Documentation | Repository root or docs folder | README files, runbooks, usage guides |

---

## Challenge Alignment

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

## Maintainer Notes

Suggested future additions:

- Add links to internal BQCA design examples.
- Add Qiskit code snippets for top-priority algorithms.
- Add algorithm-to-use-case mapping tables.
- Add backend-readiness notes for IBM Quantum hardware execution.
- Add estimated before-and-after time savings from BQCA workflows.
- Add example prompts for each algorithm family.


## 20. Recommended User Prompts

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

## 21. Documentation and Business Notes

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

Business teams can use BQCA to accelerate quantum education, prototype delivery, research planning, and innovation programs. Engineering teams can use BQCA to standardize Qiskit workflows and keep generated artifacts reproducible. Research teams can use BQCA to create early-stage designs, code examples, and visualizations that support discovery and communication.

---

## 22. Security and Governance Notes

1. Never commit `.env` with real secrets.
2. Keep IBM Quantum tokens and Bob API keys outside generated source code.
3. Use enterprise-approved runtime environments for production quantum workloads.
4. Review generated quantum code before using real hardware or quota-consuming runtime jobs.
5. Keep design-only work in `bob-quantum-designs/` and implementation code in `bob-quantum-store/`.
6. Treat generated scientific results as prototypes unless independently validated.

---

## 23 Authors

| Name | Role / Affiliation | Additional Designation |
|---|---|---|
| Akpojotor Shemi | IBM Quantum Qiskit Advocate | Bob Quantum Team Member (watsonx Challenge '26) |
| Nic Ponder | Aspiring Quantum Graduate Student | Bob Quantum Team Member (watsonx Challenge '26) |
| Taylor Sperry | IBM Quantum Ambassador Candidate | Bob Quantum Team Member (watsonx Challenge '26) |
| Jeffrey Chijioke-Uche, PhD | IBM Computer Scientist & IBM Quantum Ambassador \| Quantum Qiskit Advocate | Quantum Master Inventor, IEEE Senior Member for Computational Intelligence, Bob Quantum Team Member (watsonx Challenge '26) |
