---
name: build-mcp-server
description: Use when the user wants to design and build a custom MCP server that exposes tools or prompts to Bob using Node.js or another supported runtime.
---

# Build Mcp Server

Build a Custom MCP Server
Guide the user through designing and building a new MCP server from scratch — a Node.js process
(or remote HTTP endpoint) that exposes tools, resources, and/or prompts to Bob. Follow these steps
in order.

Step 0 — Decide Whether a Custom Server Is the Right Fit
Push back if it isn't. A custom server is warranted when:

The user needs a reusable, stateful integration with an external API or data source across many tasks.
The required capability involves multi-step protocol negotiation (OAuth token exchange, streaming data, pagination) that is too brittle to do ad-hoc with execute_command.
The user explicitly says "create an MCP server" or "add a tool that…".
A custom server is not needed when:

A one-off shell script or execute_command call solves the problem.
An existing MCP server in the marketplace already covers the use-case.
The task is a single API call with no reuse value.
Step 1 — Gather Requirements
Use ask_followup_question to establish:

What capability does the server expose? (tools, prompts, or a mix — see note below on resources)
What external API/service does it integrate with? Does it require an API key or OAuth?
Transport: local stdio (spawned by Bob as a child process) or remote HTTP (a running service)? Default to local stdio unless the user has a specific reason for HTTP.
Language: default to TypeScript/Node.js unless the user prefers Python or another runtime.
Scope: should it be registered globally or workspace-only in mcp.json?
Step 2 — Scaffold the Project
TypeScript / Node.js (default)
Create the project directory and install dependencies:

mkdir <server-name>
cd <server-name>
npm init -y
npm install @modelcontextprotocol/server zod
npm install -D @types/node typescript
mkdir src && touch src/index.ts

Set package.json fields:

{
  "type": "module",
  "scripts": { "build": "tsc && chmod 755 build/index.js" },
  "bin": { "<server-name>": "./build/index.js" },
  "files": ["build"]
}

Use this tsconfig.json:

{
  "compilerOptions": {
    "target": "ES2022",
    "module": "Node16",
    "moduleResolution": "Node16",
    "outDir": "./build",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules"]
}

Step 3 — Implement the Server
Minimal stdio server skeleton (v2 API)
#!/usr/bin/env node
import { McpServer } from "@modelcontextprotocol/server";
import { StdioServerTransport } from "@modelcontextprotocol/server/stdio";
import { z } from "zod/v4";

const server = new McpServer({ name: "<server-name>", version: "0.1.0" });

// Register tools and prompts here (see below)

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("<server-name> running on stdio");
}

main().catch((error) => {
  console.error("Fatal error:", error);
  process.exit(1);
});

⚠️ Always use console.error for logging — console.log writes to stdout, which is the MCP
protocol channel; any non-JSON output there will corrupt the connection.

Registering a tool (v2 API)
Use server.registerTool. Always wrap input schemas in z.object(). Return isError: true for
recoverable failures so Bob can self-correct:

server.registerTool(
  "get-weather",
  {
    description: "Get current weather for a city",
    inputSchema: z.object({
      city: z.string().describe("City name"),
    }),
  },
  async ({ city }) => {
    try {
      const data = await fetchWeather(city);
      return { content: [{ type: "text", text: JSON.stringify(data) }] };
    } catch (error) {
      return {
        content: [{ type: "text", text: `Failed: ${error instanceof Error ? error.message : String(error)}` }],
        isError: true,
      };
    }
  }
);

⚠️ Resources are not supported by Bob. Bob only loads tools and prompts from MCP servers —
registerResource / readResource calls are never made. Do not implement resources expecting Bob
to use them; expose data as tools instead.

Registering a prompt
server.registerPrompt(
  "summarize",
  { argsSchema: z.object({ text: z.string() }) },
  async ({ text }) => ({
    messages: [{ role: "user", content: { type: "text", text: `Summarize: ${text}` } }],
  })
);

Step 4 — Handle Authentication
API key (simplest)
Read credentials from environment variables — never hardcode them:

const API_KEY = process.env.MY_API_KEY;
if (!API_KEY) throw new Error("MY_API_KEY environment variable is required");

Bob/the user injects these via the env block in mcp.json.

⚠️ Bob cannot expand ${VAR} references in mcp.json — values are stored literally. Walk
the user through obtaining the key, then use ask_followup_question to collect it before writing
the config.

OAuth (requires a one-time setup script)
MCP servers run non-interactively — they cannot open browser windows or initiate OAuth flows at
runtime. The pattern is:

Write a separate one-time script (e.g. get-refresh-token.js) that:
Starts a local HTTP server to receive the OAuth callback
Opens the authorization URL (or prints it for the user to visit)
Logs the resulting refresh token to stderr/stdout
Instruct the user to run the script once with execute_command to capture the token.
Put the refresh token in the server's env block in mcp.json.
The server exchanges the refresh token for access tokens at runtime.
Step 5 — Build
npm run build

Verify the output file exists at build/index.js before registering it.

Step 6 — Register in mcp.json
After a successful build, register the server using the configure-mcp skill (Path A). Key
points:

Set command to "node" and args to the absolute path of build/index.js.
Add all required env vars to the env block.
Default disabled to false (omit it) and alwaysAllow to [] (omit it).
{
  "mcpServers": {
    "<server-name>": {
      "command": "node",
      "args": ["/absolute/path/to/<server-name>/build/index.js"],
      "env": {
        "MY_API_KEY": "<user-provided>"
      }
    }
  }
}

Step 7 — Verify and Demonstrate
Once the config is saved, Bob hot-reloads the server. Confirm it appears as connected in Bob's MCP
panel, then suggest a concrete command the user can try to exercise the new tool — e.g. "You can
now ask: what's the weather in London?"

If the server fails to connect, use the configure-mcp skill (Path B) to diagnose.

Notes for power users
HTTP transport: for a remotely hosted server, use NodeStreamableHTTPServerTransport from @modelcontextprotocol/node and register the server with a url instead of command/args.
Editing an existing server: locate the server's source from its args path, edit it with apply_diff/write_file, rebuild, and the server will reconnect automatically.
Multiple tools: keep each tool focused on one operation. Prefer more small tools over one large tool with a mode parameter.

Reminders
Use ask_followup_question for API keys and OAuth tokens — never guess or placeholder them.
Always use console.error for server-side logging, never console.log.
Use registerTool / registerResource / registerPrompt (v2 API) — not the old server.tool() variadic form.
Never include information without evidence.

<!-- BEGIN IBM BOB MCP TOOL GUARD POLICY v${BOB_VERSION}.Q27 -->
## MCP Tool Guard Policy

When the user asks to create, build, configure, diagnose, or explain an MCP server, do not call `search_docs`, `show_sections`, or any documentation-search helper first. Those helpers are not required for MCP server work and may fail when a page parameter is missing.

Use the local workspace skills and files instead:

1. Prefer `.bob/skills/build-mcp-server/SKILL.md` for custom MCP server design, scaffolding, implementation, registration, and verification.
2. Prefer `.bob/skills/configure-mcp/SKILL.md` for Bob MCP configuration, `.bob/mcp.json`, `~/.bob/settings/mcp.json`, local STDIO servers, remote HTTP/SSE servers, runtime checks, and diagnostics.
3. Ask only the minimum clarifying questions needed for transport, language/runtime, API/authentication needs, and workspace/global scope.
4. If documentation is needed, use local skill instructions first and ask the user for a specific external document or page before using any documentation-search tool.
5. Never fail a user-facing MCP workflow because `search_docs` or `show_sections` is unavailable or returned an argument error.

This guard applies to all appliance modes. It supplements, and does not replace, appliance-specific domain policies.
<!-- END IBM BOB MCP TOOL GUARD POLICY v${BOB_VERSION}.Q27 -->


<!-- QCA-PATCH-v20-POLICY-BLOCK-START -->

## QCA-GENERATED-CODE-QUALITY-POLICY-v${BOB_VERSION}.Q20

When the user asks QCA to execute, write, create, generate, or implement quantum code from a design or prompt, all generated code must be production-quality, syntactically correct, and executable without avoidable errors.

Mandatory behavior:

1. Generated Python code must pass syntax validation before QCA reports success.
2. After writing any `.py` implementation file, validate it with `python -m py_compile <file>` or with `.bob/quantum-tools/qca-code-quality-guard.sh --validate <file>`.
3. If syntax validation fails, repair the code silently and revalidate before reading, summarizing, or reporting the file.
4. QCA must not claim that code is complete, saved, or executable until the saved file exists and syntax validation succeeds.
5. Generated code must use explicit imports, deterministic file paths, safe output directories, and clear terminal output.
6. Generated quantum code must remain aligned with Qiskit SDK 2.x or later unless the user explicitly requests another compatibility target.
7. For quantum visualizations, generated code must save durable PNG artifacts and print clean artifact paths.
8. Errors must be minimized. User-facing output must be clean, professional, and focused on final execution results and saved artifact paths.
9. Diagnostic failures, dependency installation output, and retry logs must be written behind the scenes to `.bob/qca-code-quality.log` or an equivalent local log file.

## QCA-GENERATE-CODE-TYPES-POLICY-v${BOB_VERSION}.Q20

When the user asks QCA to execute, write, create, generate, or implement code from a design, QCA must save implementation code under:

```text
bob-quantum-store/<normalized-design-name>/
```

For every generated implementation, QCA must create two code artifact types:

```text
<descriptive-code-name>.py
<descriptive-code-name>.ipynb
```

Mandatory behavior:

1. The `.py` file is the default executable artifact because it is compatible with terminal execution and clean terminal output requirements.
2. The `.ipynb` file is the companion notebook artifact for notebook review, learning, and visual inspection.
3. The notebook must represent the same implementation as the `.py` file unless the user explicitly asks for a notebook-only or divergent notebook workflow.
4. Both files must be saved in the same `bob-quantum-store/<normalized-design-name>/` directory.
5. QCA must verify both files exist before reporting success.
6. QCA must not save generated implementation code under `bob-quantum-designs/`.
7. QCA must keep design Markdown under `bob-quantum-designs/` and executable/generated code under `bob-quantum-store/`.

## QCA-CODE-EXECUTION-POLICY-v${BOB_VERSION}.Q20

When the user requests code execution, QCA must perform a silent execution readiness process before running code.

Mandatory pre-execution sequence:

1. Silently check whether the Qiskit/Python virtual environment exists. The default environment is:

```text
~/qiskit-v2x-env
```

2. If the environment does not exist, silently create or repair it using the established Qiskit v2.x environment setup workflow and Python 3.12-compatible environment behavior.
3. Before executing generated code, inspect the generated Python file and collect the imported modules.
4. Silently verify that required imported modules are installed inside the Qiskit/Python virtual environment.
5. If any required module is missing, silently install it into the virtual environment using `uv pip install --python <venv-python> <package>` or a safe fallback equivalent.
6. Do not execute code until the environment exists, imports are resolved, and syntax validation passes.
7. Execute the `.py` artifact by default unless the user specifically requests notebook execution.
8. Do not expose raw `ModuleNotFoundError`, dependency installation noise, or avoidable stack traces to the user. Log diagnostic details behind the scenes.
9. If execution fails, repair the code or environment when possible, revalidate, and retry once before reporting a concise failure summary.
10. Use `.bob/quantum-tools/qca-code-quality-guard.sh` when available for validation, notebook generation, dependency checks, and execution readiness.

Recommended guard command pattern:

```bash
.bob/quantum-tools/qca-code-quality-guard.sh --prepare bob-quantum-store/<design>/<code>.py
.bob/quantum-tools/qca-code-quality-guard.sh --execute bob-quantum-store/<design>/<code>.py
```

<!-- QCA-PATCH-v20-POLICY-BLOCK-END -->

<!-- BQCA-v30-POLICY-REFERENCE-START -->
## BQCA Production Policy v30 — Authoritative Precedence
Use `.bob/BQCA-PRODUCTION-POLICY-v30.md` as the authoritative appliance-wide
policy. Preserve the specialized intelligence of this mode, rule, skill, or tool,
but resolve routing, implementation, execution, security, and completion behavior
according to the v30 policy. Design artifacts go to `bob-quantum-designs/`;
implementation and result artifacts go to `bob-quantum-store/`. Legacy
implementation directories must never be used.
<!-- BQCA-v30-POLICY-REFERENCE-END -->

<!-- BQCA-NOTEBOOK-AUTOGEN-v37:BEGIN -->
## Enforced automatic notebook production
Automatic notebook generation is enforced by the BQCA runtime watcher and is not optional mode guidance. Whenever a `.py` implementation is created or modified under `bob-quantum-store/`, the watcher automatically generates or refreshes its sibling `.ipynb` after the source becomes stable and validates the notebook. BQCA must create the `.py` first, wait for or invoke the automatic notebook generation, and report both paths. Manual notebook creation is permitted only after a genuine automatic-generation failure.
<!-- BQCA-NOTEBOOK-AUTOGEN-v37:END -->

<!-- BQCA-QISKIT-CONFIGURATION-v38:BEGIN -->
## BQCA v38 mandatory Qiskit configuration gate
Treat `create`, `implement`, `write`, `generate`, `build`, `develop`, `produce`, `scaffold`, `construct`, `code`, `program`, `modify`, `update`, `repair`, `fix`, `refactor`, `complete`, or `execute` as a code-producing request when the object is a quantum/Qiskit workload or artifact. Before invoking qiskit_connector rules, templates, validators, generated Connector code, or backend-selection behavior, run `.bob/quantum-tools/qiskit-configuration.sh configure --quiet` and require success. The tool rebuilds `~/.qiskit/qiskit-ibm.json` from the BQCA project-root `.env`, with exactly one profile named `bqca`, and `bqca` is the only default account. qiskit_connector relies on this file for connectivity decisions. Never print the token.
<!-- BQCA-QISKIT-CONFIGURATION-v38:END -->

<!-- BQCA-HELLO-WORLD-SCOPE-v41:BEGIN -->
## BQCA v41 request-scoped Hello World enforcement
Preserve all BQCA v38-v40 configuration, Qiskit 2.5+, home-environment,
Open/Paid plan, simulator fallback, and real-hardware execution rules. Hello
World is not a universal design or code requirement. For every request that is
not explicitly a Hello World design or executable, do not add, mention,
scaffold, execute, validate, document, or require a Hello World section, test,
command, artifact, filename, example, or `bob-quantum-store/test` reference.
Only an explicit Hello World request may use the existing request-scoped
shortcut and test artifacts. Explicit Hello World artifacts must be named or
titled as Hello World. All generated designs and code must pass the v41 scope
validator before completion.
<!-- BQCA-HELLO-WORLD-SCOPE-v41:END -->

<!-- BQCA-RESULT-OUTPUT-v42:BEGIN -->
## BQCA v42 governed result-output enforcement
Every quantum/Qiskit `.py` or `.ipynb` execution must use the BQCA runtime
manager so `<source-stem>-result-output.txt` is created beside the source. The
report captures complete combined stdout/stderr, including Qiskit Connector,
plan, backend, real-QPU, simulator, fallback, warning, error, and result output;
contains date/time and duration; and ends with a professional `RESULT SUMMARY`
stating execution success. Generated code must emit the canonical target, plan,
backend, result, and real-QPU JOB ID markers. For a real-QPU result, the actual
JOB ID must be the first line at the top. Designs describe this policy textually,
and code/design/result validation is blocking before completion.
<!-- BQCA-RESULT-OUTPUT-v42:END -->

<!-- BQCA-QISKIT-EXECUTION-v39-update-1:BEGIN -->
## BQCA v39 Update 1 isolated Qiskit execution enforcement
Treat quantum/Qiskit create, implement, write, generate, build, develop,
produce, scaffold, construct, code, program, modify, update, repair, fix,
refactor, complete, execute, or equivalent requests as CODE intent. Configure
the v38 bqca account and use only project-root `qiskit-v2x-env`. Every Qiskit
version check, import check, uninstall, upgrade, and install must run through
that environment's `bin/python` and environment-local pip. System/global Python,
pip, and user-site Qiskit are prohibited. Host `python3 -m venv` may only create
a missing environment; an invalid pre-existing environment fails closed. Qiskit
2.5+ is required. Open Plan uses `SamplerV2(mode=backend)` without Session;
paid plans use Session with SamplerV2/EstimatorV2; simulator fallback uses
try/except, `transpile`, and AerSimulator. `backend.run()` is local-simulator-only.
Designs state these rules textually. Hello World requests inspect
`bob-quantum-store/test` and execute an existing artifact through
`qiskit-v2x-env`.
<!-- BQCA-QISKIT-EXECUTION-v39-update-1:END -->
