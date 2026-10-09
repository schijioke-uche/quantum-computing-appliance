#!/usr/bin/env python3
"""Inject concise BQCA intent and operating context into every Bob Shell 2.x prompt."""
from __future__ import annotations
import json, os, re, sys

try:
    payload = json.load(sys.stdin)
    prompt = str(payload.get("prompt", ""))
except Exception:
    prompt = ""

lower = prompt.lower()
code_verbs = re.compile(r"\b(create|implement|write|generate|build|develop|produce|scaffold|construct|code|program|modify|update|repair|fix|refactor|complete|execute)\b")
design_words = re.compile(r"\b(design|architecture|plan|blueprint|strategy|workflow)\b")
quantum_words = re.compile(r"\b(quantum|qiskit|qubit|circuit|vqe|qaoa|grover|estimator|sampler|hamiltonian|qpu)\b")

menu = os.environ.get("BQCA_MENU_OPTION", "unspecified")
action = os.environ.get("BQCA_MENU_ACTION", "BQCA request")
skill = os.environ.get("BQCA_MENU_SKILL_ID", "BQCA intelligence")
mode = os.environ.get("BQCA_SELECTED_MODE", "current")
policy = os.environ.get("BQCA_ACTIVE_POLICY_PATH", ".bob/BQCA-PRODUCTION-POLICY.md")

if quantum_words.search(lower) and code_verbs.search(lower):
    intent = "CODE"
elif quantum_words.search(lower) and design_words.search(lower):
    intent = "DESIGN"
elif menu == "3":
    intent = "CODE"
elif menu == "4":
    intent = "DESIGN"
elif menu == "2":
    intent = "QUANTUM_QUESTION"
else:
    intent = "BQCA_INTERACTIVE"

lines = [
    "BQCA_PROMPT_CONTEXT=ACTIVE",
    f"Menu={menu}; Action={action}; Skill={skill}; Mode={mode}; Intent={intent}",
    f"Use active policy: {policy}",
    "Operate as BQCA, not as a generic assistant. Load AGENTS.md, the current mode rules, the general BQCA rule, relevant skills, and quantum tools.",
]
if intent == "CODE":
    lines.append("Route executable artifacts to bob-quantum-store; consult the offline quantum knowledgebase when useful; validate code; generate/synchronize the notebook; use the default direct execution and governed result contract.")
elif intent == "DESIGN":
    lines.append("Route the textual reviewable design to bob-quantum-designs; consult the offline quantum knowledgebase when useful; include active-policy execution strategy and validate the design before completion.")
elif intent == "QUANTUM_QUESTION":
    lines.append("Answer as the BQCA Quantum Expert using current rules and approved quantum/Qiskit sources; do not create artifacts unless requested.")
else:
    lines.append("Maintain BQCA identity and preserve the current menu-selected workflow across the session.")
print("\n".join(lines))
raise SystemExit(0)
