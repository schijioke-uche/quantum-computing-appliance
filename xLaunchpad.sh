#!/usr/bin/env bash

# Author: Dr. Jeffrey Chijioke-Uche, Ph.D - IBM Computer Scientist.

set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
for TREE in bqca bqca; do
  if [[ -f "$ROOT/$TREE/xLaunchpad.sh" ]]; then
    exec bash "$ROOT/$TREE/xLaunchpad.sh" "$@"
  fi
done
printf '%s\n' 'IBM Bob Quantum Computing Appliance launchpad not found. Check inside the Use-cases directory for iLaunchpad file.' >&2
exit 2
