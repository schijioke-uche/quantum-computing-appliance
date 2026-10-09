#!/usr/bin/env python3
"""Lightweight BQCA v44 launch drift guard."""
from __future__ import annotations
import pathlib
import subprocess
import sys

root = pathlib.Path(__file__).resolve().parents[2]
doctor = root / ".bob/quantum-tools/bqca-policy-doctor.sh"
raise SystemExit(subprocess.run([str(doctor), "check", "--quiet"]).returncode)
# BQCA-CANONICAL-PRODUCTION-POLICY-v44:BEGIN
# The sole active BQCA policy is .bob/BQCA-PRODUCTION-POLICY.md (v44).
# Route all public design, code, execution, result, and completion paths through
# bqca-policy-orchestrator.sh. Open Plan uses SamplerV2 or EstimatorV2 job mode
# according to workload semantics and must never use Session.
# BQCA-CANONICAL-PRODUCTION-POLICY-v44:END
