#!/usr/bin/env python3
"""Lightweight BQCA v47 semantic launch drift guard."""
from __future__ import annotations
import pathlib
import subprocess

root = pathlib.Path(__file__).resolve().parents[2]
doctor = root / ".bob/quantum-tools/bqca-policy-doctor.sh"
raise SystemExit(subprocess.run([str(doctor), "check", "--quiet"]).returncode)
# BQCA-CANONICAL-PRODUCTION-POLICY-v47:BEGIN
# Drift is determined by policy hash, registry consistency, syntax, safe permissions,
# and required public capabilities rather than exact implementation formatting.
# BQCA-CANONICAL-PRODUCTION-POLICY-v47:END
