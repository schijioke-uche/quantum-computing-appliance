# IBM Bob Quantum Computing Agent Appliance (BQCA)

> **Author:** Dr. Jeffrey Chijioke-Uche, IBM Computer Scientist
>
> *IBM Bob Quantum Computing Agent — built and integrated with IBM Bob Intelligence.*

---

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Installation](#installation)
   - [Step 1 — Clone the Repository](#step-1--clone-the-repository)
   - [Step 2 — Configure Environment Variables](#step-2--configure-environment-variables)
   - [Step 3 — Set Up the Qiskit Environment](#step-3--set-up-the-qiskit-environment)
   - [Step 4 — Set Script Permissions](#step-4--set-script-permissions)
4. [Authentication](#authentication)
   - [Browserless API-Key Authentication](#browserless-api-key-authentication)
   - [Browser-Based Authentication](#browser-based-authentication)
5. [Launching the Appliance](#launching-the-appliance)
6. [Menu Options](#menu-options)
7. [Code Structure](#code-structure)
8. [Artifact Stores](#artifact-stores)
   - [bob-quantum-designs/](#bob-quantum-designs)
   - [bob-quantum-store/](#bob-quantum-store)
9. [Included Quantum Experiments](#included-quantum-experiments)
10. [Knowledgebase Research Traces](#knowledgebase-research-traces)
11. [SDLC Automation](#sdlc-automation)
12. [Post-Upgrade Maintenance](#post-upgrade-maintenance)
13. [Patches](#patches)
14. [Debugging](#debugging)
15. [Security](#security)
16. [License](#license)

---

## Overview

The **IBM Bob Quantum Computing Agent (BQCA)** is a production-grade appliance that integrates IBM Bob Shell (v1.x and v2.x) with IBM Quantum computing resources via Qiskit 2.5+. It provides a governed, menu-driven interface for:

- Interacting with IBM Quantum backends (real QPU and simulator)
- Designing, generating, and executing quantum circuits
- Asking quantum computing questions through IBM Bob intelligence
- Automatically generating Jupyter notebooks from Python quantum artifacts
- Enforcing production policies, compliance reports, and execution contracts

The appliance follows a **Real-QPU-first / controlled simulator fallback** execution contract and supports Open Plan, Flex, Pay-As-You-Go, Premium, and Dedicated IBM Quantum plans.

---

## Prerequisites

Before installing the BQCA appliance, ensure the following are available on your system:

| Requirement | Version | Notes |
|---|---|---|
| **IBM Bob Shell** | v1.x or v2.x | Must be installed and available as `bob` in `PATH` |
| **Python** | 3.10+ | Required for authentication scripts and Qiskit |
| **Bash** | 4.0+ | All launcher scripts require Bash |
| **Git** | Any | Required for cloning and SDLC automation |
| **IBM Quantum Account** | — | Required for real QPU access: [quantum.cloud.ibm.com](https://quantum.cloud.ibm.com) |
| **IBM Bob API Key** | — | Obtain from your IBM Bob account |
| **`xdg-utils`** | Any (optional) | Required on Linux for browser-based authentication |

> **Note:** On WSL (Windows Subsystem for Linux), browser authentication is automatically bridged to the Windows default browser via `configure-bob-auth-browser.sh`.

---

## Installation

### Step 1 — Clone the Repository

```bash
git clone <repository-url> IBM-BOB-APPLIANCES
cd IBM-BOB-APPLIANCES/bob-quantum-computing-appliance
```

Replace `<repository-url>` with the actual repository URL.

> The working directory for all subsequent steps is `bob-quantum-computing-appliance/` — the repository root that contains `xLaunchpad.sh`. The `bqca/` subdirectory is the appliance payload and is managed internally by the launchers.

---

### Step 2 — Configure Environment Variables

The appliance reads all credentials and configuration from a `.env` file in the `bqca/` directory. This file is **never committed to version control**.

An annotated template is provided at [`bqca/.env.example`](bqca/.env.example). Copy it and fill in your credentials:

```bash
cp bqca/.env.example bqca/.env
chmod 600 bqca/.env
```

The table below documents every variable in `.env.example`:

| Variable | Required | Description |
|---|---|---|
| `BOB_API_KEY` | ✅ | IBM Bob **Inference-scope** API key (recommended). General-scope keys also work but require `BOB_TEAM_ID`. |
| `BOB_INSTANCE_ID` | ✅ | Bob instance classification: `IBM Internal`, `bob-001` (Pro Plus), `Trial`, `Pro`, `Ultra` |
| `BOBSHELL_API_KEY` | auto | Derived automatically from `BOB_API_KEY`; do not set manually |
| `BOB_ENDPOINT` | 1.x only | `https://api.us-east.bob.ibm.com` |
| `BOB_AUTH_ENDPOINT` | 1.x only | `https://console-ibm-prod.verify.ibm.com` |
| `BOB_REGION` | 1.x only | Default: `us-east` |
| `BOB_TEAM_ID` | General key only | Set to `"default"` or your team ID when using a General-scope API key under Bob Shell 2.x |
| `IQP_API_TOKEN` | ✅ | IBM Quantum Platform API token from [quantum.cloud.ibm.com](https://quantum.cloud.ibm.com) |
| `IQP_API_URL` | ✅ | `https://auth.quantum-computing.ibm.com/api/users/loginWithToken` |
| `IQP_RUNTIME_BACKEND_URL` | ✅ | `https://api.quantum-computing.ibm.com/runtime/backends` |
| `CLOUD_API_URL` | ✅ | `https://cloud.ibm.com` |
| `QUANTUM_API_URL` | ✅ | `https://auth.quantum.ibm.com/api` |
| `OPEN_PLAN_CHANNEL` | ✅ | `ibm_quantum_platform` (current releases; the former `ibm_quantum` channel is no longer supported) |
| `PAID_PLAN_CHANNEL` | ✅ | `ibm_quantum_platform` |
| `OPEN_PLAN_INSTANCE` | ✅ | Open-plan service-instance CRN from the IBM Quantum console |
| `PAID_PLAN_INSTANCE` | paid only | Paid-plan CRN; contact IBM Support |
| `OPEN_PLAN_NAME` | ✅ | `open` |
| `PAYGO_PLAN_NAME` | optional | `pay-as-you-go` |
| `FLEX_PLAN_NAME` | optional | `flex` |
| `PREMIUM_PLAN_NAME` | optional | `premium` |
| `DEDICATED_PLAN_NAME` | optional | `dedicated` |
| `OPEN_PLAN` | ✅ | `on` / `off` — set exactly one plan to `on` |
| `FLEX_PLAN` | ✅ | `on` / `off` |
| `PAYGO_PLAN` | ✅ | `on` / `off` |
| `PREMIUM_PLAN` | ✅ | `on` / `off` |
| `DEDICATED_PLAN` | ✅ | `on` / `off` |
| `APPLIANCE_ROOT` | auto | Defaults to `.` (the `bqca/` directory) |
| `QCA_DESIGN_DIR` | auto | `${APPLIANCE_ROOT}/bob-quantum-designs` |
| `QCA_STORE_DIR` | auto | `${APPLIANCE_ROOT}/bob-quantum-store` |
| `BOB_INCLUDED_DIRECTORY` | auto | Comma-separated list of `QCA_STORE_DIR` and `QCA_DESIGN_DIR` passed to Bob |
| `APPLIANCE_NAME` | auto | `IBM Bob Quantum Computing Agent (BQCA)` |
| `BQCA_BOB2_OUTPUT_FORMAT` | optional | `pretty` \| `json` \| `stream-json` (default: `pretty`) |
| `BQCA_BOB2_MAX_TURNS` | optional | Max agentic turns per run session (default: `50`) |
| `BQCA_BOB2_LOG_LEVEL` | optional | `error` \| `warn` \| `info` \| `debug` \| `trace` (default: `warn`) |
| `BQCA_CHAT_AUTO_APPROVE` | optional | `1` = auto-approve tool calls in interactive sessions (default: `1`) |
| `BQCA_BOB2_DNA_ENVELOPE` | optional | `1` = inject BQCA project context into Bob 2.x non-interactive runs (default: `1`) |
| `BQCA_BOB2_INTERACTIVE_MODE` | optional | Override interactive chat mode (default: `quantum-qiskit-connector`) |
| `BQCA_BOB2_ASK_MODE` | optional | Override ask mode (default: `quantum-smart`) |
| `BQCA_BOB2_CODE_MODE` | optional | Override code mode (default: `quantum-code-heron`) |
| `BQCA_BOB2_ADVANCED_MODE` | optional | Override advanced mode (default: `quantum-advanced`) |
| `BQCA_BOB2_RESUME_MODE` | optional | Override resume mode (default: `quantum-qiskit-connector`) |
| `BOB_NODE_EXTRA_CA_CERTS` | optional | Path to enterprise CA certificate for TLS trust |

> **Security:** `.env` is loaded with `set -a` and every variable is exported to the shell. Keep it `chmod 600` and never commit it to version control. The `.env.example` file contains no secrets and is safe to commit.

---

### Step 3 — Set Up the Qiskit Environment

The only authorized BQCA Qiskit runtime is located at `$HOME/qiskit-v2x-env`. A project-local virtual environment is **prohibited**.

```bash
# Create the home-scoped Qiskit virtual environment
python3 -m venv ~/qiskit-v2x-env

# Activate it
source ~/qiskit-v2x-env/bin/activate

# Install required Qiskit packages (Qiskit 2.5 or later is required)
pip install --upgrade pip
pip install qiskit>=2.5.0 qiskit-ibm-runtime qiskit-aer qiskit-connector
```

Verify the installation:

```bash
python3 -c "import qiskit; print(qiskit.__version__)"
```

> The Qiskit environment is automatically configured per the active `.env` file when the appliance launches.

---

### Step 4 — Set Script Permissions

Ensure all shell scripts are executable:

```bash
find . -name '*.sh' -type f -exec chmod +x {} \;
```

Or use the built-in SDLC automation (which applies this automatically):

```bash
./sdlc.sh
```

---

## Authentication

### Browserless API-Key Authentication

This is the **default and recommended** authentication method. The appliance reads `BOB_API_KEY` from `.env` and authenticates directly without requiring a browser.

Authentication is performed automatically when the appliance launches via `iLaunchpad.sh` or `bob-quantum-v2.0.5.sh`. No manual steps are required beyond populating `.env`.

**What happens internally:**

1. `bob-auth.sh` is sourced by the launcher.
2. The installed Bob major version is detected from `bob --version`.
3. **Bob Shell 1.x path:** `~/.bob/token.json` and `~/.bob/config.json` are created atomically with your API key. Bob CLI reads these files for every subsequent request.
4. **Bob Shell 2.x path:** `BOB_API_KEY` is exported directly; no credential files are manufactured. A backend probe validates connectivity.

**Bob Shell 2.x Authentication Probe:**
The 2.x auth script runs a lightweight isolated probe (`bob run --mode ask --max-turns 1`) in a temporary workspace to confirm the API key is valid and the backend is reachable. The probe workspace is never part of your BQCA project, so it does not pollute the task history.

---

### Browser-Based Authentication

For interactive browser login (e.g., on supported Linux desktops, macOS, or WSL), the `configure-bob-auth-browser.sh` script is sourced automatically by `iLaunchpad.sh`. It:

- Detects the operating system (macOS, Ubuntu, Fedora, RHEL, SLES, openSUSE, WSL)
- Installs a browser bridge appropriate for the detected environment
- Sets the `BROWSER` environment variable so Bob can open the login page

To test browser setup independently:

```bash
./configure-bob-auth-browser.sh --test
```

---

## Launching the Appliance

The **recommended entry point** is `xLaunchpad.sh`, located at the repository root (`bob-quantum-computing-appliance/`). It automatically discovers and delegates to `bqca/iLaunchpad.sh`.

```bash
# From the bob-quantum-computing-appliance/ directory
./xLaunchpad.sh
```

### Launch Chain

```
xLaunchpad.sh                          ← recommended entry point (repo root)
  └─ bqca/iLaunchpad.sh                ← full preflight suite
        └─ bob-quantum-v1x.sh  OR  bob-quantum-v2.0.5.sh  ← versioned launcher
```

### What `xLaunchpad.sh` does

`xLaunchpad.sh` resolves the repository root, locates `bqca/iLaunchpad.sh`, and delegates to it via `exec`. If the appliance payload cannot be found it exits with a clear error message. It requires no arguments.

### What `bqca/iLaunchpad.sh` does

`bqca/iLaunchpad.sh` performs the full preflight suite before invoking the versioned launcher:

1. Configures browser authentication integration
2. Synchronizes root filenames to the installed Bob Shell version
3. Repairs any permission drift in the appliance tree
4. Validates custom mode/rule synchronization
5. Validates Bob Shell 2.x project DNA
6. Loads and validates XDG utilities
7. Loads `bqca/.env` (with re-load guard to prevent duplicate loads)
8. Asserts active policy integrity and refreshes compliance reports
9. Validates the Qiskit home environment path
10. Exports Qiskit execution and validation tools
11. Configures the `bqca` Qiskit account
12. Starts automatic policy-compliance and notebook-autogen watchers
13. Delegates to the version-aligned launcher: `bob-quantum-v<VERSION>.sh`

### Version-aware launcher dispatch

`bqca/iLaunchpad.sh` detects the installed Bob Shell version and delegates to the correct versioned launcher:

| Installed Bob Shell | Versioned Launcher |
|---|---|
| Bob Shell **1.x** | `bqca/bob-quantum-v1x.sh` — Bob Shell 1.x CLI API (`--chat-mode`, `--instance-id`, `--include-directories`, `--auto-approve` / `--yolo`) |
| Bob Shell **2.x** | `bqca/bob-quantum-v2.0.5.sh` — Bob Shell 2.x CLI API (`bob chat`, `bob run`, `--mode`, `--trust`, `--auto-approve`) |

> **Direct launch (development only):** You can bypass `xLaunchpad.sh` and the full preflight suite by invoking launchers directly. This skips permission guards, policy assurance, compliance sweeps, and notebook-autogen watchers.
>
> ```bash
> # Full preflight, no repo-root wrapper
> bash bqca/iLaunchpad.sh
>
> # Skip preflight entirely — Bob Shell 1.x
> bash bqca/bob-quantum-v1x.sh
>
> # Skip preflight entirely — Bob Shell 2.x
> bash bqca/bob-quantum-v2.0.5.sh
> ```

---

## Menu Options

After launch, the appliance presents an interactive menu:

```
+-----------------------------------------------------------------------------------------------+
| IBM Bob Quantum Computing Agent (BQCA)                                                        |
| This is Quantum Computing Agent, built & integrated with IBM Bob Intelligence                 |
+-----------------------------------------------------------------------------------------------+
| No.  | Action                                                         | Skill ID           |
+-----------------------------------------------------------------------------------------------+
| 1    | Start Interactive BQCA Session                                 | User Interactive   |
| 2    | Ask Quantum Computing Questions                                | Quantum Expert     |
| 3    | Quantum Computing Algorithm Implementation Concierge           | Quantum Developer  |
| 4    | Advanced Quantum Computing Solution Design Concierge           | Quantum Advanced   |
| 5    | Resume BQCA Last Activity (Picks: 1, 2, 3, or 4 last action)  | Resume Session     |
| 0    | Quit                                                           | Exit               |
+-----------------------------------------------------------------------------------------------+
```

| Option | Description | Bob Mode |
|--------|-------------|----------|
| **1** | Opens a trusted interactive BQCA chat session. Supports full session-level auto-approval for skill, file, and command operations. | `quantum-qiskit-connector` |
| **2** | Accepts a free-text quantum computing question; returns an expert explanation. Hello World execution is intercepted and runs the existing artifact directly. | `quantum-smart` |
| **3** | Accepts a prompt and generates a complete Qiskit implementation including Python source, notebook, compliance report, and result-output files. | `quantum-code-heron` |
| **4** | Accepts a prompt and generates a textual solution design saved to `bob-quantum-designs/`. | `quantum-advanced` |
| **5** | Resumes the most recent real user task in the workspace under `quantum-qiskit-connector` mode. Never resumes authentication-probe tasks. | `quantum-qiskit-connector` |
| **0** | Exits the appliance cleanly. |  |

---

## Code Structure

```
bob-quantum-computing-appliance/         ← repository root
│
├── xLaunchpad.sh                        # Recommended entry point — discovers & delegates to bqca/iLaunchpad.sh
│
└── bqca/                                # Appliance payload
    │
    ├── iLaunchpad.sh                    # Full preflight suite — called by xLaunchpad.sh
    ├── bob-quantum-v1x.sh               # Versioned launcher — Bob Shell 1.x CLI API
    ├── bob-quantum-v2.0.5.sh            # Versioned launcher — Bob Shell 2.x CLI API
    │
    ├── bob-auth.sh                      # Version-aware browserless authentication (1.x + 2.x)
    ├── bob-auth-v1x.sh                  # Legacy Bob Shell 1.x authentication script
    ├── bob-shell.sh                     # ASCII banner and version-aware shell helper
    ├── bob-version.sh                   # Bob Shell version detector (sources bob CLI)
    ├── bob-filename-version-sync.sh     # Renames root-level files to match installed Bob version
    │
    ├── tls-control.sh                   # TLS policy enforcement (NODE_TLS_REJECT_UNAUTHORIZED)
    ├── configure-bob-auth-browser.sh    # Browser integration for WSL, macOS, and Linux
    ├── xdg.sh                           # XDG open helper (check / install)
    │
    ├── sdlc.sh                          # Git SDLC automation (stage → commit → push)
    │
    ├── .env.example                     # Annotated environment template (safe to commit — no secrets)
    ├── .env                             # Operator credentials (NOT committed to version control)
    ├── AGENTS.md                        # BQCA project context for Bob Shell 2.x
    ├── bob-auth.md                      # Authentication documentation
    ├── LICENSE                          # Project license
    │
    ├── bob-quantum-designs/             # Design artifacts (Markdown, Draw.io XML)
    │   ├── readme.md
    │   ├── hello-world-2qubit/
    │   ├── bell-gate-4qubit/
    │   ├── superposition-156qubit/
    │   ├── shor-factoring-direct/
    │   ├── entanglement-routing-experiment/
    │   ├── execution-time-uncertainty-experiment/
    │   ├── measurement-time-allocation-experiment/
    │   ├── reaction-barrier-experiment/
    │   └── tail-latency-decoder-experiment/
    │
    ├── bob-quantum-store/               # Implementation artifacts (Python, notebooks, results)
    │   ├── readme.md
    │   ├── vqe-kb-research.md           # VQE knowledgebase research trace (BQCA KB artifact)
    │   ├── hello-world/
    │   ├── bell-gate-4qubit/
    │   ├── shor-factoring-direct/
    │   ├── entanglement-routing-experiment/
    │   ├── execution-time-uncertainty-experiment/
    │   ├── measurement-time-allocation-experiment/
    │   ├── reaction-barrier-experiment/
    │   ├── tail-latency-decoder-experiment/
    │   └── test/
    │
    ├── patches/                         # Incremental appliance patches
    │   ├── patch.md
    │   └── BQCA/
    │       ├── patch-BQCA-v48.sh
    │       ├── patch-BQCA-v49.sh
    │       ├── patch-BQCA-v50.sh  …
    │       ├── patch-BQCA-v51.0.sh … patch-BQCA-v51.4.sh
    │       ├── upgrade-patch.sh
    │       ├── bob-version.sh
    │       └── policy-history/          # Versioned policy audit trail
    │
    ├── post-upgrade/
    │   └── post-upgade-cleaner-v1x.sh   # Removes obsolete Bob 1.x shell-profile entries
    │
    └── documentation/
        └── IBM_Quantum_Team_wxCha26_Submission_Final_Draft-v1.3.0.pdf
```

### Key Relationships

```
xLaunchpad.sh                           (repo root — recommended entry point)
  └─ bqca/iLaunchpad.sh                 (full preflight suite)
        └─ configure-bob-auth-browser.sh  (browser setup)
        └─ bob-filename-version-sync.sh   (version-aligned filenames)
        └─ .bob/quantum-tools/            (policy, compliance, notebook, Qiskit tools)
        └─ xdg.sh                         (XDG check)
        └─ bqca/.env  ←  bqca/.env.example  (credentials; copy example, fill secrets)
        └─ bob-quantum-v1x.sh             (Bob Shell 1.x versioned launcher)
        │     └─ tls-control.sh           (TLS policy)
        │     └─ bob-version.sh           (Bob version detection)
        │     └─ bob-shell.sh             (welcome banner)
        │     └─ bob-auth.sh              (1.x auth → token.json / config.json)
        │     └─ [menu dispatch → bob --chat-mode / --resume]
        └─ bob-quantum-v2.0.5.sh          (Bob Shell 2.x versioned launcher)
              └─ tls-control.sh           (TLS policy)
              └─ bob-version.sh           (Bob version detection)
              └─ bob-shell.sh             (welcome banner)
              └─ bob-auth.sh              (2.x auth → BOB_API_KEY export + probe)
              └─ [menu dispatch → bob chat --trust / bob run --mode]
```

---

## Artifact Stores

### `bob-quantum-designs/`

Contains **design-only Markdown artifacts** for every quantum experiment. Each subdirectory holds:

| File | Purpose |
|---|---|
| `<experiment>-design.md` | Full circuit design: algorithm rationale, gate sequence, runtime contract, execution markers, artifact routing |
| `<experiment>-design-policy-compliance.txt` | Active-policy compliance report generated automatically by the BQCA compliance sweep |

Design artifacts are **not executable Python**. They define the specification that Option 3 (Quantum Developer) implements.

---

### `bob-quantum-store/`

Contains **all executable implementation artifacts** for every experiment, plus top-level knowledgebase research traces. Each subdirectory holds:

| File | Purpose |
|---|---|
| `<experiment>.py` | Authoritative Python implementation |
| `<experiment>.ipynb` | Jupyter notebook auto-generated and synchronized from the `.py` source |
| `<experiment>-result-output.txt` | Primary result file: full stdout/stderr, timestamps, plan, backend, job ID, exit status |
| `output.txt` | Compatibility mirror of the result file |
| `experiment_results.json` | Structured JSON results (experiments only) |
| `experiment_report.txt` | Human-readable experiment report |
| `*.png` | Circuit diagrams, histograms, and experimental plots |
| `<experiment>-code-policy-compliance.txt` | Active-policy compliance report for the Python source |

Top-level files in `bob-quantum-store/` that are not experiment subdirectories:

| File | Purpose |
|---|---|
| `vqe-kb-research.md` | Knowledgebase research trace generated by the BQCA quantum KB tool for the VQE / Variational Quantum Eigensolver topic |

---

## Knowledgebase Research Traces

The BQCA appliance generates **knowledgebase research trace files** (`*-kb-research.md`) when the BQCA quantum knowledgebase tool (`bqca-quantum-kb.sh`) is invoked to research a topic before design or code generation. These files are stored in `bob-quantum-store/` at the top level and record:

| Field | Description |
|---|---|
| `Policy/tool version` | The BQCA policy and tool version active at research time |
| `Research status` | `OK` (all seeds accessed) or `FAIL` (one or more seeds unreachable) |
| `Generated` | ISO-8601 UTC timestamp of the research run |
| `User topic/query` | The quantum computing topic that was researched |
| `Knowledgebase index` | Path and SHA-256 of the knowledgebase index file used |
| `Seed URL` | Each seed URL attempted, including access result and drilled sublinks |

> **`FAIL` status on `vqe-kb-research.md`:** The current trace shows `FAIL` because the seed URLs could not be reached due to an SSL certificate verification error (`CERTIFICATE_VERIFY_FAILED`). This is an environment-level TLS trust issue — it does not affect the appliance's execution of quantum circuits. To resolve it, configure `BOB_NODE_EXTRA_CA_CERTS` in `.env` with your enterprise CA certificate, or run the appliance in an environment with the required CA installed.

Research traces are informational artifacts. They supplement IBM Bob intelligence and do not override the active BQCA central policy, Qiskit version requirements, or human scientific review.

---

## Included Quantum Experiments

| Experiment | Qubits | Type | Description |
|---|---|---|---|
| **Hello World** | 2 | Bell State | Two-qubit Bell state — canonical quantum Hello World demonstrating superposition and entanglement |
| **Bell Gate 4-Qubit** | 4 | Entanglement | Two independent Bell pairs across four qubits with pairwise correlation verification |
| **Superposition 156-Qubit** | 156 | Full Superposition | Uniform superposition of 2^156 basis states; targets `ibm_torino` / `ibm_fez` |
| **Shor Factoring (Direct)** | Variable | Algorithm | Direct implementation of Shor's integer factoring algorithm |
| **Entanglement Routing** | Variable | Research | Experiment exploring entanglement routing strategies across QPU topologies |
| **Execution Time Uncertainty** | Variable | Research | Statistical analysis of QPU backend execution time uncertainty |
| **Measurement Time Allocation** | Variable | Research | Ramsey sensing and optimal measurement time allocation under QPU constraints |
| **Reaction Barrier** | Variable | Chemistry | VQE-based quantum chemistry: H₂ potential energy surface and reaction barrier estimation |
| **Tail Latency Decoder** | Variable | Research | Quantum error correction decoder performance and tail-latency characterization |

Each experiment follows the BQCA production execution contract:
- Real QPU first via Qiskit Connector (`QConnectorV2`, `QPlanV2`)
- Controlled `AerSimulator` fallback on QPU unavailability
- All required BQCA execution markers (`BQCA_EXECUTION_TARGET`, `BQCA_PLAN`, `BQCA_BACKEND`, `BQCA_JOB_ID`, `BQCA_RESULT`)
- Plan-aware primitive selection (`SamplerV2` for sampling, `EstimatorV2` for expectation values)

---

## SDLC Automation

The `sdlc.sh` script provides simple Git automation for the appliance:

```bash
# Commit and push with the default commit message
./sdlc.sh

# Commit with a custom message
./sdlc.sh "Add 156-qubit superposition experiment"
```

**What `sdlc.sh` does:**

1. Clears all Git stashes silently
2. Resolves any unresolved stash-conflict paths (restores from HEAD or removes)
3. Applies `chmod +x` to all `.sh` files in the repository
4. Stages all changes (`git add -A`)
5. Commits if there are staged changes
6. Pushes the current branch to `origin` with up to 3 retries

**Optional environment variables:**

```bash
GIT_REMOTE=origin       # Remote name (default: origin)
PUSH_RETRIES=3          # Number of push attempts (default: 3)
PUSH_RETRY_DELAY=5      # Seconds between retries (default: 5)
```

> `sdlc.sh` intentionally does not run `git pull`, `git fetch`, `git rebase`, `git merge`, `git stash apply`, or `git stash pop`.

---

## Post-Upgrade Maintenance

After upgrading from IBM Bob Shell 1.x to 2.x, run the post-upgrade cleaner to remove the obsolete `~/.bob/export-env.sh` source line from your shell RC file:

```bash
# Auto-detect your active shell (bash or zsh) and clean its RC file
./post-upgrade/post-upgade-cleaner-v1x.sh

# Clean a specific shell
./post-upgrade/post-upgade-cleaner-v1x.sh --shell bash
./post-upgrade/post-upgade-cleaner-v1x.sh --shell zsh

# Clean both shells
./post-upgrade/post-upgade-cleaner-v1x.sh --shell all

# Preview changes without modifying files
./post-upgrade/post-upgade-cleaner-v1x.sh --dry-run
```

The cleaner creates a timestamped backup before editing and validates the RC file with `bash -n` or `zsh -n`. If validation fails, the original file is restored automatically.

---

## Patches

The `patches/BQCA/` directory contains incremental appliance patches that extend the policy, tooling, and runtime behavior. Each patch is a standalone Bash script named after its version token (e.g., `patch-BQCA-v51.4.sh`).

**Policy history** is preserved in `patches/BQCA/policy-history/` as versioned Markdown files and a JSON manifest (`BQCA-policy-history-manifest.json`). These are audit records and are not active unless the policy registry explicitly references them.

To apply the latest patch:

```bash
bash patches/BQCA/patch-BQCA-v51.4.sh
```

To apply the upgrade patch:

```bash
bash patches/BQCA/upgrade-patch.sh
```

---

## Debugging

Enable verbose Bob Shell diagnostics by setting `BQCA_BOB_DEBUG=1` before launching:

```bash
BQCA_BOB_DEBUG=1 ./iLaunchpad.sh
```

This appends `--log-level debug` to all Bob run and chat invocations.

**Other useful environment variables:**

| Variable | Default | Description |
|---|---|---|
| `BQCA_BOB_DEBUG` | `0` | Enable debug logging for Bob CLI |
| `BQCA_BOB2_MAX_TURNS` | `50` | Maximum turns per Bob Shell 2.x run session |
| `BQCA_BOB2_OUTPUT_FORMAT` | `pretty` | Output format for Bob Shell 2.x (`pretty` or `json`) |
| `BQCA_BOB2_LOG_LEVEL` | `warn` | Log level (`warn`, `info`, `debug`) |
| `BQCA_CHAT_AUTO_APPROVE` | `1` | Auto-approve tool calls in interactive chat sessions |
| `BOB_AUTH_PROBE_TIMEOUT_SECONDS` | `90` | Timeout for the Bob Shell 2.x authentication probe |
| `BQCA_ALLOW_HOST_PACKAGE_INSTALL` | `0` | Allow `xdg.sh` to install `xdg-utils` via the system package manager |

---

## Security

The appliance enforces several security controls:

- **Credential isolation:** API keys, IBM Quantum tokens, and Bob session credentials are read exclusively from `.env` and are never written to design artifacts, code, notebooks, logs, compliance reports, or terminal prompts.
- **TLS enforcement:** `tls-control.sh` ensures `NODE_TLS_REJECT_UNAUTHORIZED` is never set to `0`. Enterprise CAs are supported via `NODE_EXTRA_CA_CERTS`.
- **Restricted file permissions:** `~/.bob/token.json` and `~/.bob/config.json` are always written with mode `600`. The `~/.bob/` directory is mode `700`.
- **Auth probe isolation (Bob 2.x):** The backend validation probe runs in a throwaway temporary workspace, preventing probe activity from polluting the BQCA project task history.
- **Credential masking:** If the authentication probe fails, diagnostic output is scanned for any occurrence of `BOB_API_KEY` and replaced with `***REDACTED***` before being printed.
- **Auto-approval scope:** Interactive session auto-approval is confined to the trusted BQCA project. It does not authorize credential access, destructive system actions, writes outside the project root, or bypass of BQCA validators and policy gates.

---

## License

See [`LICENSE`](./LICENSE) for the project license terms.

---

*IBM Bob Quantum Computing Agent (BQCA) — Dr. Jeffrey Chijioke-Uche, IBM Computer Scientist*
