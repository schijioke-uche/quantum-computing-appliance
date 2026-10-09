#!/usr/bin/env python3
"""Lightweight BQCA v48 semantic launch drift guard."""
from __future__ import annotations
import pathlib
import subprocess

root = pathlib.Path(__file__).resolve().parents[2]
doctor = root / ".bob/quantum-tools/bqca-policy-doctor.sh"
raise SystemExit(subprocess.run([str(doctor), "check", "--quiet"]).returncode)

# BQCA-ACTIVE-CENTRAL-POLICY:BEGIN
# Resolve the active authority through bqca-active-policy-listener.sh before
# every quantum DESIGN or CODE decision. Never hardcode a policy version or
# duplicate the full policy here. qiskit-design-policy-check.py and
# qiskit-code-policy-check.py reload the active registry/policy/contract on
# every invocation and create same-directory policy-compliance reports.
# Do not report completion until the active-policy report exists.
# BQCA-ACTIVE-CENTRAL-POLICY:END

# BQCA-BOB-SHELL-V2-DNA:BEGIN
# In a trusted Bob Shell 2.x workspace, bind this component to AGENTS.md, the
# active central BQCA policy, exported menu context, current rules/skills/tools,
# and the offline knowledgebase without changing this component's core purpose.
# BQCA-BOB-SHELL-V2-DNA:END
