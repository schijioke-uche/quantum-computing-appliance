# IBM Bob Quantum Computing Agent (QCA)

**IBM Bob Quantum Computing Agent (QCA)** is a domain-specialized IBM Bob appliance designed to help quantum practitioners, platform engineers, researchers, and enterprise innovation teams plan, build, validate, and operationalize quantum-computing workflows. QCA combines IBM Bob Shell, custom Bob modes, custom Bob skills, custom rules, and QCA-specific tool guidance to produce a guided quantum development environment for Qiskit, IBM Quantum Runtime, circuit design, VQE workflows, simulation, visualization, and quantum solution planning.

**Author:** Dr. Jeffrey Chijioke-Uche, IBM Computer Scientist  
**IBM Quantum Ambassador & AI Researcher**

---

## 1. QCA Appliance Snapshot

| Feature | Description |
|---|---|
| Appliance name | IBM Bob Quantum Computing Agent (QCA) |
| Root folder in archive | `quantum/` |
| Primary launcher | `bob-quantum-v1.0.5.sh` |
| Version detector | `bob-version.sh` |
| Dynamic version pattern | Runtime content uses `v${BOB_VERSION}`; physical launcher is resolved to the detected Bob version. |
| Entry launchpad | `xLaunchpad.sh` |
| Authentication helper | `bob-auth.sh` and `bob-auth.md` |
| TLS helper | `tls-control.sh` |
| Environment template | `.env.example` |
| Bob configuration root | `.bob/` |
| QCA tools guide | `.bob/quantum-tools/README.md` |
| Main QCA skill | `.bob/skills/bob-quantum-skill/SKILL.md` |
| Design directory | `bob-quantum-designs/` |
| Implementation directory | `bob-quantum-store/` |
| Existing design artifacts | Mercury VQE and Uranium-234 VQE design documents |
| Existing implementation artifacts | Mercury VQE and Uranium-234 VQE Python code, result files, and PNG visualizations |
| Active files analyzed | 47 active files, excluding `.git/` and patch-backup history |
| Active content size | 1,692,256 bytes |

---

# Background of QCA Appliance

## 2. Executive Summary

QCA is an IBM Bob-powered quantum engineering appliance. It converts Bob from a general AI coding assistant into a focused quantum-computing agent with persistent appliance rules, quantum modes, reusable skills, Qiskit-oriented tooling guidance, artifact routing, and execution discipline.

The appliance is optimized for users who need to:

1. Ask quantum-computing questions and receive domain-specific guidance.
2. Generate Qiskit and IBM Quantum Runtime-ready code.
3. Design circuits, VQE workflows, QAOA workflows, simulations, and quantum experiments.
4. Separate architecture/design documents from executable implementation artifacts.
5. Produce terminal output, result files, and PNG visualizations for quantum workflows.
6. Use shared Bob productivity skills such as planning, skill creation, MCP server building, Git guidance, and Excel workbook analysis.

QCA is not just a script wrapper. It is a configured Bob appliance with a purpose-built intelligence layer for quantum research, quantum education, quantum application prototyping, molecular simulation, quantum optimization, quantum runtime planning, and Qiskit-based software engineering.

---

## 3. Bob as an AI Tool Used in QCA and Why

IBM Bob is used as the AI execution and reasoning engine behind QCA because QCA needs more than static templates. Quantum-computing work often requires interpreting a user’s scientific goal, choosing an appropriate quantum workflow, creating executable Qiskit code, selecting simulator or runtime behavior, generating artifacts, and explaining the result clearly.

| Why Bob is used in QCA | Business and technical value |
|---|---|
| Natural-language quantum interaction | Users can ask for circuits, algorithms, VQE designs, or runtime workflows without manually composing every file. |
| Tool-enabled software generation | Bob can read, write, update, list, and validate files inside the quantum workspace. |
| Mode-driven task routing | QCA custom modes guide Bob toward ask, code, plan, advanced design, orchestration, and quantum intelligence behaviors. |
| Persistent custom rules | QCA rules enforce design/store separation, artifact verification, terminal-output discipline, visualization output, and Qiskit coding standards. |
| Reusable skill layer | Shared skills give QCA reusable workflows for planning, MCP configuration, Git, Excel analysis, skill creation, and mode creation. |
| Quantum-specific guidance | The appliance instructs Bob to favor Qiskit 2.x-or-later patterns, IBM Quantum Runtime awareness, simulation discipline, and safe credential handling. |
| Repeatable artifact production | QCA can generate durable Markdown designs, Python source files, `.txt` result files, and `.png` visualizations. |

---

## 4. Custom Bob Functionalities That Produced QCA

| Custom Functionality Name | Description |
|---|---|
| QCA custom modes | Workspace-scoped Bob modes in `.bob/custom_modes.yaml` that specialize Bob behavior for quantum ask, code, advanced circuit design, planning, orchestration, Qiskit connector behavior, Draw.io, GraphQL, and WXO agent architecture tasks. |
| QCA custom skills | Workspace-scoped skills under `.bob/skills/` that provide reusable procedures for QCA quantum work and shared Bob tasks such as plan creation, skill creation, mode creation, MCP configuration, MCP server building, Excel analysis, and Git version-control guidance. |
| QCA custom rules | Mode-specific rule folders under `.bob/rules-*` that enforce QCA behavior, including Qiskit development standards, artifact routing, read-after-write verification, MCP guard behavior, and design/store separation. |
| QCA custom tool guidance | `.bob/quantum-tools/README.md` defines QCA’s quantum execution standards, Qiskit 2.x policy, visualization policy, terminal-output policy, backend/runtime guidance, and artifact discipline. |
| QCA launcher menu | `bob-quantum-v1.0.5.sh` provides the interactive terminal menu for User Interactive, Quantum Assist, Quantum Code, Quantum Advanced, Resume, and Quit workflows. |
| QCA version detector | `bob-version.sh` detects the Bob Shell version and exports `BOB_VERSION` so launchers and policy text can use persistent dynamic versioning. |
| QCA xLaunchpad | `xLaunchpad.sh` loads `.env`, requires required Bob credentials, sources `bob-version.sh`, and starts the version-aware QCA launcher. |
| QCA design/store model | `bob-quantum-designs/` stores design-only Markdown artifacts; `bob-quantum-store/` stores executable implementation code and generated result artifacts. |

---

## 5. QCA Custom Modes

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

> Note: The current QCA custom modes file contains compatibility duplicate slugs for `code`, `advanced`, and `orchestrator`. This reflects the current production appliance state and should only be changed intentionally by a future patch.

---

## 6. QCA Custom Skills

| Skill | Purpose |
|---|---|
| `bob-quantum-skill` | Main QCA skill for Qiskit code generation, quantum circuit design, molecular simulation, VQE, saved artifact workflows, and QCA behavior. |
| `create-plan` | Creates structured implementation plans before code changes or artifact generation. |
| `create-skill` | Guides creation of reusable Bob custom skills. |
| `create-mode` | Guides creation or update of Bob custom modes. |
| `configure-mcp` | Configures or diagnoses local and remote MCP servers for Bob. |
| `build-mcp-server` | Designs and scaffolds custom MCP servers. |
| `xlsx-insights` | Analyzes Excel workbooks through sampling, JSON dumps, and targeted extraction scripts. |
| `git-version-control` | Provides Git workflow, branching, tagging, recovery, release, and enterprise version-control guidance. |
| `mcp-tool-guard` | Prevents MCP workflows from failing due to missing or miscalled documentation-search helpers such as `search_docs` or `show_sections`. |

---

## 7. QCA Custom Rules

| Rule Area | File / Folder | Role in QCA |
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
| WXO Agent Architect rules | `.bob/rules-WXO Agent Architect/` | Supports agent architecture tasks while preserving QCA domain behavior. |

---

## 8. QCA Custom Tool Guidance

QCA’s main custom tool guidance is stored in:

```text
.bob/quantum-tools/README.md
```

This file establishes the operational standards for quantum workflows.

| Tool Guidance Area | QCA Behavior |
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

## 9. IBM Bob QCA Capabilities in Quantum

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

## 10. IBM Bob QCA Quantum Intelligence

QCA’s quantum intelligence is the combination of IBM Bob reasoning, QCA-specific prompt policies, Qiskit coding standards, quantum artifact conventions, and production-grade file discipline. The appliance is designed to help users translate quantum intent into structured deliverables.

For example, a user can ask QCA to design a VQE workflow for a target molecule. QCA should first recognize whether the request is design-only or implementation-oriented. If it is design-only, QCA routes the output to `bob-quantum-designs/` as Markdown. If the user asks for executable code, QCA routes the implementation to `bob-quantum-store/`, writes the Python file, verifies that it exists, and then summarizes the path and run instructions.

QCA also guides generated quantum code toward practical execution habits:

1. Use current Qiskit APIs by default.
2. State package assumptions.
3. Use environment variables for IBM Quantum credentials.
4. Prefer deterministic, executable scripts with `main()` functions.
5. Print useful execution summaries.
6. Save results and visualizations to durable files.
7. Avoid pretending that high-complexity quantum chemistry or heavy-element simulation is trivial.
8. Ask for missing backend, molecule, shot count, qubit count, or execution-risk details when required.

This makes QCA useful not only for writing code, but also for teaching quantum workflows, creating reusable assets, preparing technical demonstrations, and supporting enterprise quantum exploration.

---

## 11. IBM Bob QCA Quantum Use Cases in Industries

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

## 12. Quantum Productivity Problems Solved by IBM Bob QCA

| Productivity Problem | How QCA Helps |
|---|---|
| Quantum code starts from a blank page | QCA generates structured Qiskit code from natural-language intent. |
| Designs and code get mixed together | QCA separates `bob-quantum-designs/` from `bob-quantum-store/`. |
| Generated code is not verified | QCA rules require write-before-read verification and saved path reporting. |
| Results disappear after terminal execution | QCA encourages durable `.txt` result files and PNG artifacts. |
| Quantum users forget visualization output | QCA instructs workflows to save circuit diagrams, histograms, and convergence plots. |
| Legacy Qiskit examples create confusion | QCA defaults to Qiskit 2.x-or-later guidance unless legacy compatibility is requested. |
| Credentials are mishandled | QCA requires `.env` or runtime variables and discourages hardcoded tokens. |
| Quantum runtime choices are unclear | QCA prompts for backend, IBM Quantum instance, channel, shot count, and execution context when needed. |
| Heavy quantum chemistry is oversimplified | QCA rules encourage realistic statements about package assumptions and computational complexity. |
| Users need repeatable project assets | QCA creates saved design files, code files, result files, and visualizations in predictable directories. |

---

## 13. IBM Bob QCA File Analysis Table

| File / Directory | Purpose |
|---|---|
| `.env.example` | Template for Bob credentials, endpoints, Bob included directories, appliance name, and IBM Quantum plan/channel variables. |
| `.env` | Runtime environment file. Do not commit real secrets. Do not print or share its values. |
| `xLaunchpad.sh` | Entry script that loads Bob version and environment variables, validates required Bob settings, and starts the QCA launcher. |
| `bob-version.sh` | Detects Bob Shell version through `bob --version` and exports `BOB_VERSION`. |
| `bob-quantum-v1.0.5.sh` | Main QCA interactive launcher with the QCA menu and Bob command invocations. |
| `bob-auth.sh` | Authenticates Bob Shell before menu actions execute. |
| `bob-auth.md` | Documents Bob authentication behavior and environment expectations. |
| `tls-control.sh` | TLS helper used by the appliance launch scripts. |
| `.bob/custom_modes.yaml` | Defines QCA custom modes and mode-level behavior. |
| `.bob/skills/bob-quantum-skill/SKILL.md` | Main QCA domain skill. |
| `.bob/skills/*/SKILL.md` | Shared Bob productivity skills available to QCA. |
| `.bob/rules-*/*.md` | Mode-specific QCA rules and policies. |
| `.bob/quantum-tools/README.md` | QCA tool guidance, Qiskit policy, output policy, and artifact policy. |
| `.bob/notes/pending-notes.txt` | Placeholder for pending notes. |
| `.bob/patches-applied/` | Patch tracking for applied QCA updates. |
| `bob-quantum-designs/` | Design-only Markdown artifacts. |
| `bob-quantum-store/` | Generated Qiskit/Python code, result files, and visualization artifacts. |
| `.git/` | Git repository metadata. |

---

# How to Use QCA Appliance

## 14. Clone the Repository

```bash
git clone <repository-url>
```

Replace `<repository-url>` with the Git repository that contains the IBM Bob appliance project.

## 15. Go to the QCA Directory

Depending on your repository layout, use one of these patterns:

```bash
cd ibm-bob-operations/use-cases/quantum
```

or, if the extracted appliance root is directly named `quantum`:

```bash
cd quantum
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
export APPLIANCE_NAME="IBM Bob Quantum Computing Agent (QCA)"
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

The current extracted QCA launcher is version-resolved as:

```text
bob-quantum-v1.0.5.sh
```

## 19. Start the Appliance

```bash
chmod +x xLaunchpad.sh bob-quantum-v1.0.5.sh bob-version.sh bob-auth.sh tls-control.sh
./xLaunchpad.sh
```

The launchpad presents the QCA menu:

| Option | Action | Skill ID |
|---:|---|---|
| 1 | Start Interactive QCA Session | User Interactive |
| 2 | Ask Quantum Computing Question | Quantum Assist |
| 3 | Quantum Computing Code Assist | Quantum Code |
| 4 | Advanced Quantum Computing Circuit Design | Quantum Advanced |
| 5 | Resume QCA Session | Resume latest |
| 0 | Quit | Exit |

## 20. Recommended User Prompts

| Goal | Example Prompt |
|---|---|
| Ask a quantum question | `Explain VQE and when I should use it.` |
| Create a design artifact | `Design a 4-qubit VQE workflow for lithium hydride. Save the design only.` |
| Generate code | `Create Qiskit code for a 3-qubit GHZ circuit and save it in the QCA store.` |
| Generate visualization | `Create and run a Bell-state circuit and save the circuit PNG and histogram PNG.` |
| Build a VQE prototype | `Create a VQE prototype with result text output and convergence plot.` |
| Plan a larger implementation | `Create a plan for a QAOA portfolio-optimization proof of concept.` |
| Configure MCP | `Create an MCP server for local quantum documentation lookup.` |

---

## 21. Documentation and Business Notes

| Documentation Area | Where to Look |
|---|---|
| QCA tools and quantum execution policy | `.bob/quantum-tools/README.md` |
| QCA main skill | `.bob/skills/bob-quantum-skill/SKILL.md` |
| Shared custom skills | `.bob/skills/` |
| QCA custom modes | `.bob/custom_modes.yaml` |
| QCA mode-specific rules | `.bob/rules-*/*.md` |
| Bob authentication notes | `bob-auth.md` |
| Design outputs | `bob-quantum-designs/` |
| Implementation outputs | `bob-quantum-store/` |

Business teams can use QCA to accelerate quantum education, prototype delivery, research planning, and innovation programs. Engineering teams can use QCA to standardize Qiskit workflows and keep generated artifacts reproducible. Research teams can use QCA to create early-stage designs, code examples, and visualizations that support discovery and communication.

---

## 22. Security and Governance Notes

1. Never commit `.env` with real secrets.
2. Keep IBM Quantum tokens and Bob API keys outside generated source code.
3. Use enterprise-approved runtime environments for production quantum workloads.
4. Review generated quantum code before using real hardware or quota-consuming runtime jobs.
5. Keep design-only work in `bob-quantum-designs/` and implementation code in `bob-quantum-store/`.
6. Treat generated scientific results as prototypes unless independently validated.

---

## 23. Author

**Dr. Jeffrey Chijioke-Uche, IBM Computer Scientist**  
**IBM Quantum Ambassador & AI Researcher**
