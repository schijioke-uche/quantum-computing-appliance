#!/usr/bin/env python3
"""Lightweight BQCA v48 semantic launch drift guard."""
from __future__ import annotations
import pathlib
import subprocess

root = pathlib.Path(__file__).resolve().parents[2]
doctor = root / ".bob/quantum-tools/bqca-policy-doctor.sh"
raise SystemExit(subprocess.run([str(doctor), "check", "--quiet"]).returncode)

# BQCA-CANONICAL-PRODUCTION-POLICY-v48:BEGIN
# Use .bob/BQCA-PRODUCTION-POLICY.md as the sole active BQCA v48 authority.
# Direct synchronous execution is the default; formal orchestration is explicit
# opt-in. Preserve the Qiskit configuration/home-environment/2.5+ gates,
# plan-aware Runtime V2 execution, real-QPU-first fallback order, synchronized
# notebooks, scoped Hello World behavior, live dual-result capture, Job-ID-first
# real-QPU reports, and secret protection. Quantum DESIGN and CODE work consults
# bqca-quantum-kb.sh and the offline v48 catalog. v48 incorporates core v47 and
# Updates 1-6; Update 6 supersedes Update 5 URL crawling.
# BQCA-CANONICAL-PRODUCTION-POLICY-v48:END
