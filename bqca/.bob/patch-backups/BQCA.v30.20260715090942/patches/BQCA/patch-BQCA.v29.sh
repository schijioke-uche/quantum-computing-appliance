#!/usr/bin/env bash
set -Eeuo pipefail

#===============================================================================
# BQCA Patch v29
# @Author: Dr. Jeffrey Chijioke-Uche, IBM Computer Scientist
# @Purpose: Add BQCA generated-code quality, generated code type, and execution
#           policies to the production Quantum Computing Agent appliance.
# @Expected location: <repo-root>/patches/BQCA/patch-BQCA.v29.sh
# @Target appliance:  <repo-root>/use-cases/quantum or <repo-root>/use-case/quantum
#===============================================================================

PATCH_ID="BQCA.v29"
PATCH_NAME="patch-BQCA.v29.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP="$(date +%Y%m%d%H%M%S)"

info() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
fail() { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

find_repo_root() {
  local dir="$SCRIPT_DIR"

  while [[ "$dir" != "/" ]]; do
    if [[ -d "$dir/use-cases/quantum" || -d "$dir/use-case/quantum" ]]; then
      printf '%s\n' "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done

  if [[ -d "$PWD/use-cases/quantum" || -d "$PWD/use-case/quantum" ]]; then
    printf '%s\n' "$PWD"
    return 0
  fi

  if [[ -f "$PWD/xLaunchpad.sh" && -d "$PWD/.bob" ]]; then
    printf '%s\n' "$(dirname "$PWD")"
    return 0
  fi

  return 1
}

require_cmd python3
require_cmd find
require_cmd grep
require_cmd sed

REPO_ROOT="$(find_repo_root)" || fail "Could not locate repository root. Expected to run from <repo-root>/patches/BQCA with appliance in use-cases/quantum-computing-agent."

# ~/quantum-computing-agent

if [[ -d "$REPO_ROOT/quantum-computing-agent" ]]; then
  QCA_DIR="$REPO_ROOT/quantum-computing-agent"
elif [[ -d "$REPO_ROOT/quantum-computing-agent" ]]; then
  QCA_DIR="$REPO_ROOT/quantum-computing-agent"
elif [[ -f "$PWD/xLaunchpad.sh" && -d "$PWD/.bob" ]]; then
  QCA_DIR="$PWD"
else
  fail "Could not locate QCA appliance directory. Expected use-cases/quantum or use-case/quantum."
fi

[[ -d "$QCA_DIR/.bob" ]] || fail "QCA .bob directory not found: $QCA_DIR/.bob"

BACKUP_DIR="$BQCA_DIR/.bob/patch-backups/${PATCH_ID}.${TIMESTAMP}"
PATCH_RECORD_DIR="$BQCA_DIR/.bob/patches-applied"
PATCH_RECORD_FILE="$PATCH_RECORD_DIR/${PATCH_ID}.txt"
mkdir -p "$BACKUP_DIR" "$PATCH_RECORD_DIR"

backup_file() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  local rel="${file#$BQCA_DIR/}"
  mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
  cp -p "$file" "$BACKUP_DIR/$rel"
}

append_once() {
  local file="$1"
  local marker="$2"
  local content_file="$3"

  [[ -f "$file" ]] || return 0

  if grep -Fq "$marker" "$file"; then
    return 0
  fi

  backup_file "$file"
  {
    printf '\n\n'
    cat "$content_file"
    printf '\n'
  } >> "$file"
}

POLICY_TMP="$(mktemp)"
cat > "$POLICY_TMP" <<'POLICY_EOF'
<!-- QCA-PATCH-v29-POLICY-BLOCK-START -->

## QCA-GENERATED-CODE-QUALITY-POLICY-v${BOB_VERSION}.Q29

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
POLICY_EOF

CUSTOM_POLICY_TMP="$(mktemp)"
python3 - <<'PY' "$POLICY_TMP" "$CUSTOM_POLICY_TMP"
from pathlib import Path
import sys
src = Path(sys.argv[1]).read_text()
# Convert Markdown policy to YAML folded-text lines under customInstructions: >-
lines = []
for line in src.splitlines():
    # Keep policy readable inside existing folded scalar.
    lines.append("      " + line)
Path(sys.argv[2]).write_text("\n".join(lines) + "\n")
PY

patch_custom_modes() {
  local file="$QCA_DIR/.bob/custom_modes.yaml"
  [[ -f "$file" ]] || return 0

  if grep -Fq "QCA-PATCH-v20-POLICY-BLOCK-START" "$file"; then
    return 0
  fi

  backup_file "$file"

  python3 - <<'PY' "$file" "$CUSTOM_POLICY_TMP"
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
policy = Path(sys.argv[2]).read_text().rstrip("\n").splitlines()
text = path.read_text()

if "QCA-PATCH-v20-POLICY-BLOCK-START" in text:
    raise SystemExit(0)

out = []
inserted = 0
for line in text.splitlines():
    out.append(line)
    if re.match(r"^\s{4}customInstructions:\s*>-\s*$", line):
        out.extend(policy)
        inserted += 1

if inserted == 0:
    raise SystemExit("No customInstructions: >- blocks found in custom_modes.yaml")

path.write_text("\n".join(out) + "\n")
print(f"Patched custom_modes.yaml customInstructions blocks: {inserted}")
PY
}

create_quality_guard() {
  local guard="$QCA_DIR/.bob/quantum-tools/qca-code-quality-guard.sh"
  mkdir -p "$(dirname "$guard")"
  backup_file "$guard"

  cat > "$guard" <<'GUARD_EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

#===============================================================================
# QCA Code Quality Guard
# Purpose: Validate generated quantum Python code, create companion notebooks,
#          ensure Qiskit/Python environment readiness, install missing imports,
#          and execute code with diagnostic logging.
#===============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QCA_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LOG_FILE="${QCA_CODE_QUALITY_LOG:-$QCA_ROOT/.bob/qca-code-quality.log}"
VENV_PATH="${QISKIT_VENV_PATH:-$HOME/qiskit-v2x-env}"
PYTHON_VERSION="${QCA_PYTHON_VERSION:-3.12}"

mkdir -p "$(dirname "$LOG_FILE")"

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')" "$*" >> "$LOG_FILE" 2>/dev/null || true
}

usage() {
  cat <<'USAGE'
QCA Code Quality Guard

Usage:
  qca-code-quality-guard.sh --ensure-venv
  qca-code-quality-guard.sh --validate <file.py>
  qca-code-quality-guard.sh --ensure-modules <file.py>
  qca-code-quality-guard.sh --notebook <file.py> [file.ipynb]
  qca-code-quality-guard.sh --prepare <file.py>
  qca-code-quality-guard.sh --execute <file.py>

All dependency and diagnostic details are logged behind the scenes.
USAGE
}

venv_python() {
  printf '%s/bin/python' "$VENV_PATH"
}

have_venv() {
  [[ -x "$(venv_python)" ]]
}

ensure_uv() {
  if command -v uv >/dev/null 2>&1; then
    return 0
  fi

  log "uv not found. Attempting silent uv install."
  if command -v curl >/dev/null 2>&1; then
    curl -LsSf https://astral.sh/uv/install.sh 2>>"$LOG_FILE" | sh >>"$LOG_FILE" 2>&1 || true
    export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"
  fi

  command -v uv >/dev/null 2>&1
}

ensure_venv() {
  if have_venv; then
    return 0
  fi

  log "Qiskit/Python virtual environment not found at $VENV_PATH. Creating silently."
  mkdir -p "$(dirname "$VENV_PATH")"

  if ensure_uv; then
    uv python install "$PYTHON_VERSION" >>"$LOG_FILE" 2>&1 || true
    uv venv --seed --python "$PYTHON_VERSION" "$VENV_PATH" >>"$LOG_FILE" 2>&1 || true
  fi

  if ! have_venv; then
    log "uv venv creation failed or unavailable. Falling back to python3 -m venv."
    python3 -m venv "$VENV_PATH" >>"$LOG_FILE" 2>&1 || true
    "$(venv_python)" -m ensurepip --upgrade >>"$LOG_FILE" 2>&1 || true
  fi

  if ! have_venv; then
    log "Failed to create virtual environment at $VENV_PATH."
    return 1
  fi

  "$(venv_python)" -m pip install --upgrade pip setuptools wheel >>"$LOG_FILE" 2>&1 || true
}

validate_python() {
  local py_file="$1"
  [[ -f "$py_file" ]] || { log "Missing Python file: $py_file"; return 1; }
  ensure_venv
  "$(venv_python)" -m py_compile "$py_file" >>"$LOG_FILE" 2>&1
}

extract_modules_json() {
  local py_file="$1"
  "$(venv_python)" - "$py_file" <<'PY'
import ast
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
mods = set()
try:
    tree = ast.parse(path.read_text(encoding="utf-8"))
except Exception:
    print("[]")
    raise

for node in ast.walk(tree):
    if isinstance(node, ast.Import):
        for alias in node.names:
            mods.add(alias.name.split(".")[0])
    elif isinstance(node, ast.ImportFrom):
        if node.module:
            mods.add(node.module.split(".")[0])

stdlib = set(getattr(sys, "stdlib_module_names", set()))
ignore = stdlib | {
    "__future__", "typing", "pathlib", "datetime", "json", "math", "os", "sys", "subprocess",
    "itertools", "collections", "dataclasses", "random", "statistics", "time", "re", "csv",
}
mods = sorted(m for m in mods if m and m not in ignore)
print(json.dumps(mods))
PY
}

package_for_module() {
  case "$1" in
    qiskit) echo "qiskit[visualization]" ;;
    qiskit_aer) echo "qiskit-aer" ;;
    qiskit_ibm_runtime) echo "qiskit-ibm-runtime" ;;
    qiskit_algorithms) echo "qiskit-algorithms" ;;
    qiskit_nature) echo "qiskit-nature" ;;
    dotenv) echo "python-dotenv" ;;
    matplotlib) echo "matplotlib" ;;
    numpy) echo "numpy" ;;
    scipy) echo "scipy" ;;
    pandas) echo "pandas" ;;
    sympy) echo "sympy" ;;
    pyscf) echo "pyscf" ;;
    networkx) echo "networkx" ;;
    pylatexenc) echo "pylatexenc" ;;
    IPython) echo "ipython" ;;
    nbformat) echo "nbformat" ;;
    *) echo "$1" ;;
  esac
}

module_exists() {
  local module="$1"
  "$(venv_python)" - "$module" <<'PY' >/dev/null 2>>"$LOG_FILE"
import importlib.util
import sys
module = sys.argv[1]
raise SystemExit(0 if importlib.util.find_spec(module) else 1)
PY
}

install_package() {
  local package="$1"
  log "Installing missing package silently: $package"
  if ensure_uv; then
    uv pip install --python "$(venv_python)" "$package" >>"$LOG_FILE" 2>&1 || \
      "$(venv_python)" -m pip install "$package" >>"$LOG_FILE" 2>&1
  else
    "$(venv_python)" -m pip install "$package" >>"$LOG_FILE" 2>&1
  fi
}

ensure_modules() {
  local py_file="$1"
  local modules_json
  ensure_venv
  validate_python "$py_file"
  modules_json="$(extract_modules_json "$py_file")"

  "$(venv_python)" - "$modules_json" <<'PY' | while IFS= read -r module; do
import json
import sys
for item in json.loads(sys.argv[1]):
    print(item)
PY
    [[ -z "$module" ]] && continue
    if ! module_exists "$module"; then
      install_package "$(package_for_module "$module")" || {
        log "Failed to install package for missing module: $module"
        return 1
      }
    fi
  done
}

create_notebook() {
  local py_file="$1"
  local ipynb_file="${2:-${py_file%.py}.ipynb}"
  ensure_venv
  validate_python "$py_file"

  "$(venv_python)" - "$py_file" "$ipynb_file" <<'PY'
import json
import sys
from pathlib import Path

py = Path(sys.argv[1])
ipynb = Path(sys.argv[2])
source = py.read_text(encoding="utf-8")
notebook = {
    "cells": [
        {
            "cell_type": "markdown",
            "metadata": {},
            "source": [
                "# QCA Generated Quantum Implementation\\n",
                f"Generated companion notebook for `{py.name}`.\\n"
            ],
        },
        {
            "cell_type": "code",
            "execution_count": None,
            "metadata": {},
            "outputs": [],
            "source": source.splitlines(True),
        },
    ],
    "metadata": {
        "kernelspec": {
            "display_name": "Python 3 (QCA)",
            "language": "python",
            "name": "python3",
        },
        "language_info": {
            "name": "python",
            "pygments_lexer": "ipython3",
        },
    },
    "nbformat": 4,
    "nbformat_minor": 5,
}
ipynb.write_text(json.dumps(notebook, indent=2), encoding="utf-8")
PY
}

prepare_file() {
  local py_file="$1"
  validate_python "$py_file"
  ensure_modules "$py_file"
  create_notebook "$py_file"
  test -f "${py_file%.py}.ipynb"
}

execute_file() {
  local py_file="$1"
  prepare_file "$py_file"
  log "Executing QCA Python artifact: $py_file"
  "$(venv_python)" "$py_file" 2>>"$LOG_FILE"
}

main() {
  local mode="${1:-}"
  local py_file="${2:-}"
  local ipynb_file="${3:-}"

  case "$mode" in
    --ensure-venv)
      ensure_venv
      ;;
    --validate)
      [[ -n "$py_file" ]] || { usage; return 2; }
      validate_python "$py_file"
      ;;
    --ensure-modules)
      [[ -n "$py_file" ]] || { usage; return 2; }
      ensure_modules "$py_file"
      ;;
    --notebook)
      [[ -n "$py_file" ]] || { usage; return 2; }
      create_notebook "$py_file" "$ipynb_file"
      ;;
    --prepare)
      [[ -n "$py_file" ]] || { usage; return 2; }
      prepare_file "$py_file"
      ;;
    --execute)
      [[ -n "$py_file" ]] || { usage; return 2; }
      execute_file "$py_file"
      ;;
    --help|-h|help)
      usage
      ;;
    *)
      usage
      return 2
      ;;
  esac
}

main "$@"
GUARD_EOF

  chmod 0755 "$guard"
}

patch_launcher_env() {
  local file="$QCA_DIR/bob-quantum-v1.0.5.sh"
  [[ -f "$file" ]] || return 0

  if grep -Fq "QCA_CODE_QUALITY_GUARD" "$file"; then
    return 0
  fi

  backup_file "$file"

  python3 - <<'PY' "$file"
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()
needle = 'export QCA_STORE_DIR\n'
insert = '''export QCA_STORE_DIR

# QCA-GENERATED-CODE-QUALITY-POLICY-v${BOB_VERSION}.Q20 helper path.
# Bob should use this guard before reporting generated code success or executing code.
QCA_CODE_QUALITY_GUARD="${QCA_CODE_QUALITY_GUARD:-$SCRIPT_DIR/.bob/quantum-tools/qca-code-quality-guard.sh}"
export QCA_CODE_QUALITY_GUARD
'''
if needle not in text:
    raise SystemExit("Could not locate export QCA_STORE_DIR insertion point in launcher")
path.write_text(text.replace(needle, insert, 1))
PY
}

patch_readme() {
  local file="$QCA_DIR/README.md"
  [[ -f "$file" ]] || return 0
  append_once "$file" "QCA-GENERATED-CODE-QUALITY-POLICY-v" "$POLICY_TMP"
}

patch_quantum_tools_readme() {
  local file="$QCA_DIR/.bob/quantum-tools/README.md"
  [[ -f "$file" ]] || return 0
  append_once "$file" "QCA-GENERATED-CODE-QUALITY-POLICY-v" "$POLICY_TMP"
}

patch_rules() {
  while IFS= read -r file; do
    append_once "$file" "QCA-GENERATED-CODE-QUALITY-POLICY-v" "$POLICY_TMP"
  done < <(find "$QCA_DIR/.bob" -type f -path '*/rules-*/*.md' | sort)
}

patch_skills() {
  while IFS= read -r file; do
    append_once "$file" "QCA-GENERATED-CODE-QUALITY-POLICY-v" "$POLICY_TMP"
  done < <(find "$QCA_DIR/.bob/skills" -type f -name 'SKILL.md' | sort)

  # Ensure underscore skill alias exists for environments or docs that refer to bob_quantum_skill.
  local alias_dir="$QCA_DIR/.bob/skills/bob_quantum_skill"
  local alias_skill="$alias_dir/SKILL.md"
  if [[ ! -f "$alias_skill" ]]; then
    mkdir -p "$alias_dir"
    cat > "$alias_skill" <<'ALIAS_EOF'
---
name: bob_quantum_skill
description: QCA quantum computing skill alias for generated code quality, dual artifact generation, Qiskit execution readiness, and production quantum implementation workflows.
---

# bob_quantum_skill

This skill is an alias and policy reinforcement layer for the IBM Bob Quantum Computing Agent (QCA).

Use this skill when the user asks to design, execute, write, create, generate, or implement quantum computing code, Qiskit code, VQE, QAOA, QPE, circuits, molecular simulation, IBM Quantum Runtime examples, or quantum algorithm artifacts.
ALIAS_EOF
  fi

  append_once "$alias_skill" "QCA-GENERATED-CODE-QUALITY-POLICY-v" "$POLICY_TMP"

  local skills_readme="$QCA_DIR/.bob/skills/README-custom-skills.md"
  if [[ -f "$skills_readme" ]] && ! grep -Fq "bob_quantum_skill" "$skills_readme"; then
    backup_file "$skills_readme"
    cat >> "$skills_readme" <<'README_EOF'

## bob_quantum_skill

Alias skill for QCA generated-code quality policy, dual `.py` + `.ipynb` artifact generation, Qiskit/Python virtual environment readiness, dependency preflight, syntax validation, and clean execution behavior.
README_EOF
  fi
}

write_patch_record() {
  cat > "$PATCH_RECORD_FILE" <<EOF
Patch: ${PATCH_ID}
Script: ${PATCH_NAME}
Applied: $(date '+%Y-%m-%d %H:%M:%S %Z')
Repository root: ${REPO_ROOT}
QCA appliance: ${QCA_DIR}
Backup directory: ${BACKUP_DIR}

Summary:
- Added QCA-GENERATED-CODE-QUALITY-POLICY.
- Added QCA-GENERATE-CODE-TYPES-POLICY.
- Added QCA-CODE-EXECUTION-POLICY.
- Patched custom modes to include policy in customInstructions.
- Patched Bob rules with policy block.
- Patched Bob skills with policy block.
- Added/updated bob_quantum_skill alias skill.
- Added QCA code quality guard helper script.
- Added launcher export for QCA_CODE_QUALITY_GUARD when supported.
EOF
}

main() {
  info "Patch: $PATCH_ID"
  info "Script directory: $SCRIPT_DIR"
  info "Repository root: $REPO_ROOT"
  info "QCA appliance: $QCA_DIR"
  info "Backup directory: $BACKUP_DIR"

  patch_custom_modes
  patch_rules
  patch_skills
  patch_quantum_tools_readme
  patch_readme
  create_quality_guard
  patch_launcher_env
  write_patch_record

  bash -n "$QCA_DIR/.bob/quantum-tools/qca-code-quality-guard.sh"
  [[ -f "$QCA_DIR/.bob/custom_modes.yaml" ]] || fail "custom_modes.yaml missing after patch."

  rm -f "$POLICY_TMP" "$CUSTOM_POLICY_TMP"

  info "QCA patch v20 completed successfully."
  info "Patch record: $PATCH_RECORD_FILE"
}

main "$@"
