---
name: xlsx-insights
description: Use when the user asks for analysis, extraction, or insights from an Excel .xlsx workbook using workbook sampling, JSON dump, and a focused extraction script.
---

# Xlsx Insights

Content
XLSX Insights
Use this skill when the user asks for analysis, extraction, or insights from an Excel (.xlsx)
workbook. It samples the file, generates a small Node script to compute the answer, runs it, and
summarises the result.

Step 1 — Sample the Workbook
Call read_xlsx with just path to get the workbook's structure without flooding context:

read_xlsx({ path: "<workspace-relative-path>.xlsx" })

Read the tool result carefully:

Sheet names and total row counts per sheet (hidden sheets are included in the list — note them)
Headers and inferred column types for the active sheet
First ~50 sample rows
If detectedHeaderRow is present, the real headers may be on a different row — retry with header_row: <detectedHeaderRow> before proceeding. This is especially common when merged cells span the first few rows (e.g. a merged title band above the real column headers).
If sampleWarning is present, act on it before proceeding.
If formulaErrors is present, report the broken cells to the user before proceeding. A value of "#UNCALCULATED" means the formula was never computed (workbook was not saved after edits); all other values (e.g. "#DIV/0!", "#REF!", "#N/A") are live Excel formula errors. Ask the user whether to skip those cells, treat them as null, or fix the source workbook first.
If a column type is "string" but sample values look like numbers, the cells were formatted as Text in Excel. Your script must coerce them: Number(row[idx["Price"]]) || 0.
Step 2 — Confirm Intent
If the user's request is unambiguous given the schema, proceed directly to Step 3.

If the request is ambiguous (e.g. multiple sheets that could match, column names that are unclear,
or an aggregation that could be interpreted several ways), ask one focused question using
ask_followup_question before continuing. Do not ask multiple questions at once.

Step 3 — Dump the Workbook to JSON
Call read_xlsx with dump: true. Do not pass header_row — the dump auto-detects
the real header row independently for each sheet:

read_xlsx({ path: "<path>.xlsx", dump: true })

Read the manifest path from the tool result — it will look like:
.bob/tmp/xlsx-dumps/<stem>-<hash>/manifest.json

The manifest lists each sheet with its JSON file path, row count, and correct headers
(auto-detected per sheet, so a workbook where different sheets have headers on different rows
is handled automatically). The dump is content-addressed: calling again with the same file
reuses the existing dump without re-reading the workbook.

Step 4 — Write an Extraction Script
Use write_file to create a Node script inside the dump directory, alongside the data it reads:

.bob/tmp/xlsx-dumps/<stem>-<hash>/<slug>.mjs

Where <slug> is a short kebab-case description of what the script does (e.g.
revenue-by-region.mjs, overdue-invoices.mjs). Do not use a timestamp as the filename.

Keeping the script beside its data makes it self-contained and easy to re-run or hand off.

Critical rules for the script:

Use Node stdlib only — fs.readFileSync + JSON.parse. Do not import "exceljs" or any other npm package. The JSON dump was already produced by
