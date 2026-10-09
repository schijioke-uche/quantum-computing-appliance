#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GENERATOR="$SCRIPT_DIR/notebook-generator.py"

usage() {
  cat <<'USAGE'
BQCA notebook generator

Generate a sibling notebook from a completed Python source:
  notebook-generator.sh --source path/to/file.py [--output file.ipynb] [--title "Title"] [--force]

Validate a notebook:
  notebook-generator.sh --validate path/to/file.ipynb
USAGE
}

[[ -x "$GENERATOR" ]] || {
  printf 'BQCA_NOTEBOOK_GENERATION=FAIL: generator is missing or not executable: %s\n' "$GENERATOR" >&2
  exit 2
}

if (($# == 0)); then
  usage
  exit 2
fi

exec python3 "$GENERATOR" "$@"
