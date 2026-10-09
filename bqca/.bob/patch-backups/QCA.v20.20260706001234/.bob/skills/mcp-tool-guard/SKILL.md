---
name: mcp-tool-guard
description: Use when the user asks to create, build, configure, diagnose, explain, or troubleshoot an MCP server or Bob MCP configuration, especially when documentation-search tools such as search_docs or show_sections are unavailable or failing.
---

# MCP Tool Guard

Follow this workflow for MCP server and Bob MCP configuration requests.

## 1. Do not start with documentation-search tools

Do not call `search_docs`, `show_sections`, or similar documentation-section helpers as the first step. They are not required for MCP work and can fail when a page parameter is unavailable.

## 2. Route to the correct local skill

Use local workspace skill instructions first:

- Use `.bob/skills/build-mcp-server/SKILL.md` when the user wants to design, scaffold, implement, register, or verify a custom MCP server.
- Use `.bob/skills/configure-mcp/SKILL.md` when the user wants to add, update, restrict, or diagnose Bob MCP configuration.

## 3. Ask targeted questions only when required

Collect only the missing facts needed to proceed:

- Local STDIO server or remote HTTP/SSE server.
- Preferred language/runtime, usually Node.js/TypeScript unless the user specifies otherwise.
- External API or service integration.
- Authentication model and whether secrets must be written to disk.
- Workspace or global Bob configuration scope.

## 4. Continue without search_docs/show_sections

If `search_docs` or `show_sections` is unavailable, missing, or returns an argument error, ignore that failure and continue using the local skill instructions and the user's requirements.

## 5. Preserve appliance policy

Keep the appliance-specific domain rules authoritative. MCP guidance supplements the appliance; it does not override QCA, TIA, SWA, WMA, or QVC design/store routing and safety policies.
