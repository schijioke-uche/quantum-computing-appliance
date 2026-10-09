#!/usr/bin/env python3
"""BQCA local quantum algorithm knowledgebase (v48).

Offline, curated, plan-aware design and code scaffolding for Qiskit 2.5+.
No network access or URL drilldown is required.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import re
import sys
from typing import Any

HERE = pathlib.Path(__file__).resolve().parent
DEFAULT_CATALOG = HERE / "bqca_quantum_algorithm_catalog.json"


def load_catalog(path: pathlib.Path) -> dict[str, Any]:
    data = json.loads(path.read_text(encoding="utf-8"))
    validate_catalog(data)
    return data


def validate_catalog(data: dict[str, Any]) -> None:
    if data.get("schema_version") != 1:
        raise ValueError("unsupported catalog schema")
    entries = data.get("entries")
    if not isinstance(entries, list) or not entries:
        raise ValueError("catalog entries are missing")
    seen: set[str] = set()
    required = {
        "slug", "name", "category", "primitive", "status", "summary",
        "use_cases", "packages", "template_pattern", "qiskit_min_version",
        "open_plan", "paid_plan", "simulator", "result_contract",
    }
    for index, entry in enumerate(entries):
        missing = required.difference(entry)
        if missing:
            raise ValueError(f"entry {index} missing fields: {sorted(missing)}")
        slug = str(entry["slug"])
        if slug in seen:
            raise ValueError(f"duplicate slug: {slug}")
        seen.add(slug)
        if entry["primitive"] not in {"sampler", "estimator", "hybrid", "local", "design"}:
            raise ValueError(f"invalid primitive for {slug}")
        if "Session" not in entry["paid_plan"]:
            raise ValueError(f"paid plan strategy missing Session for {slug}")
        if "No Session" not in entry["open_plan"]:
            raise ValueError(f"open plan strategy is not explicitly session-free for {slug}")
        if not str(entry["qiskit_min_version"]).startswith("2.5"):
            raise ValueError(f"entry {slug} does not declare Qiskit 2.5+")


def index_by_slug(data: dict[str, Any]) -> dict[str, dict[str, Any]]:
    return {str(entry["slug"]): entry for entry in data["entries"]}


def tokenize(text: str) -> set[str]:
    return {token for token in re.findall(r"[a-z0-9]+", text.lower()) if len(token) > 1}


def search_entries(data: dict[str, Any], query: str, limit: int) -> list[tuple[int, dict[str, Any]]]:
    wanted = tokenize(query)
    scored: list[tuple[int, dict[str, Any]]] = []
    for entry in data["entries"]:
        haystack = " ".join([
            str(entry["slug"]), str(entry["name"]), str(entry["category"]),
            str(entry["summary"]), " ".join(entry.get("use_cases", [])),
            " ".join(entry.get("packages", [])), str(entry.get("primitive", "")),
        ])
        words = tokenize(haystack)
        score = len(wanted.intersection(words)) * 10
        for token in wanted:
            if token in haystack.lower():
                score += 2
        if str(entry["slug"]).lower() in query.lower() or str(entry["name"]).lower() in query.lower():
            score += 30
        if score:
            scored.append((score, entry))
    scored.sort(key=lambda item: (-item[0], item[1]["name"]))
    return scored[:limit]


def catalog_hash(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def print_entry(entry: dict[str, Any]) -> None:
    print(f"Slug: {entry['slug']}")
    print(f"Name: {entry['name']}")
    print(f"Category: {entry['category']}")
    print(f"Primitive: {entry['primitive']}")
    print(f"Status: {entry['status']}")
    print(f"Qubits: {entry.get('qubits', 'problem-dependent')}")
    print(f"Qiskit: >= {entry['qiskit_min_version']}")
    print(f"Summary: {entry['summary']}")
    print("Use cases: " + ", ".join(entry.get("use_cases", [])))
    print("Packages: " + ", ".join(entry.get("packages", [])))
    print(f"Open Plan: {entry['open_plan']}")
    print(f"Paid Plan: {entry['paid_plan']}")
    print(f"Simulator: {entry['simulator']}")
    print(f"Result contract: {entry['result_contract']}")
    refs = entry.get("official_references", [])
    if refs:
        print("Official references:")
        for url in refs:
            print(f"  - {url}")


def design_markdown(entry: dict[str, Any], catalog_path: pathlib.Path) -> str:
    refs = "\n".join(f"- {url}" for url in entry.get("official_references", [])) or "- None recorded"
    uses = "\n".join(f"- {item}" for item in entry.get("use_cases", [])) or "- General research"
    packages = "\n".join(f"- `{item}`" for item in entry.get("packages", []))
    return f"""# {entry['name']} — BQCA Design Knowledge Card

## Knowledgebase provenance

- Catalog: `{catalog_path}`
- Catalog SHA-256: `{catalog_hash(catalog_path)}`
- Catalog version: `BQCA.v48`
- Qiskit compatibility floor: `2.5.0`
- Entry status: `{entry['status']}`

## Purpose

{entry['summary']}

## Suitable use cases

{uses}

## Algorithm and circuit strategy

- Category: **{entry['category']}**
- Primitive family: **{entry['primitive']}**
- Estimated qubits: **{entry.get('qubits', 'problem-dependent')}**
- Template pattern: **{entry.get('template_pattern', 'generic')}**
- Define the problem instance, input encoding, circuit/ansatz, classical optimizer or post-processing where applicable, and validation baseline before implementation.

## IBM Quantum plan-aware execution

### Open Plan

{entry['open_plan']}

### Paid Plan

{entry['paid_plan']}

### Simulator fallback

{entry['simulator']}

## Qiskit 2.5+ dependencies

{packages}

## Required implementation evidence

- Qiskit Connector plan and backend initialization.
- Real-QPU eligibility and qubit-capacity checks.
- Real-QPU-first execution branch.
- Controlled simulator fallback.
- Canonical BQCA execution markers and result-output files.
- Synchronized `.py` and `.ipynb` artifacts.
- Human review of scientific assumptions and result interpretation.

## Result contract

{entry['result_contract']}

## Official references

{refs}

## Limitations and review notes

- This local knowledge card is a design accelerator, not a substitute for the active central BQCA policy.
- Package APIs and backend constraints must be checked in the authorized `$HOME/qiskit-v2x-env` before execution.
- Large or fault-tolerant algorithms may require a reduced demonstration problem for current hardware.
"""


def builder_code(pattern: str, primitive: str) -> str:
    if pattern == "bell":
        return """def build_workload():\n    qc = QuantumCircuit(2, 2)\n    qc.h(0)\n    qc.cx(0, 1)\n    qc.measure([0, 1], [0, 1])\n    return qc\n"""
    if pattern == "ghz":
        return """def build_workload():\n    qubits = 3\n    qc = QuantumCircuit(qubits, qubits)\n    qc.h(0)\n    for index in range(qubits - 1):\n        qc.cx(index, index + 1)\n    qc.measure(range(qubits), range(qubits))\n    return qc\n"""
    if pattern == "deutsch_jozsa":
        return """def build_workload():\n    data_qubits = 2\n    qc = QuantumCircuit(data_qubits + 1, data_qubits)\n    qc.x(data_qubits)\n    qc.h(range(data_qubits + 1))\n    for qubit in range(data_qubits):\n        qc.cx(qubit, data_qubits)  # balanced oracle example\n    qc.h(range(data_qubits))\n    qc.measure(range(data_qubits), range(data_qubits))\n    return qc\n"""
    if pattern == "bernstein_vazirani":
        return """def build_workload():\n    secret = \"101\"\n    n = len(secret)\n    qc = QuantumCircuit(n + 1, n)\n    qc.x(n)\n    qc.h(range(n + 1))\n    for qubit, bit in enumerate(reversed(secret)):\n        if bit == \"1\":\n            qc.cx(qubit, n)\n    qc.h(range(n))\n    qc.measure(range(n), range(n))\n    return qc\n"""
    if pattern == "grover":
        return """def build_workload():\n    qc = QuantumCircuit(2, 2)\n    qc.h([0, 1])\n    qc.cz(0, 1)  # oracle marks |11>\n    qc.h([0, 1])\n    qc.z([0, 1])\n    qc.cz(0, 1)\n    qc.h([0, 1])\n    qc.measure([0, 1], [0, 1])\n    return qc\n"""
    if pattern == "qft":
        return """def build_workload():\n    from qiskit.circuit.library import QFT\n    qc = QuantumCircuit(3, 3)\n    qc.x(0)\n    qc.append(QFT(3, do_swaps=True), range(3))\n    qc.measure(range(3), range(3))\n    return qc\n"""
    if pattern == "repetition":
        return """def build_workload():\n    qc = QuantumCircuit(3, 3)\n    qc.x(0)\n    qc.cx(0, 1)\n    qc.cx(0, 2)\n    qc.x(1)  # injected bit flip\n    qc.measure(range(3), range(3))\n    return qc\n"""
    if pattern == "maxcut":
        return """def build_workload():\n    from qiskit.circuit.library import RealAmplitudes\n    from qiskit.quantum_info import SparsePauliOp\n    circuit = RealAmplitudes(4, reps=1)\n    observable = SparsePauliOp.from_list([(\"ZZII\", -0.5), (\"IZZI\", -0.5), (\"IIZZ\", -0.5), (\"ZIIZ\", -0.5)])\n    return circuit, observable\n"""
    if pattern in {"variational", "time_evolution"} or primitive == "estimator":
        return """def build_workload():\n    from qiskit.circuit.library import RealAmplitudes\n    from qiskit.quantum_info import SparsePauliOp\n    circuit = RealAmplitudes(2, reps=1)\n    observable = SparsePauliOp.from_list([(\"ZI\", 0.5), (\"IZ\", 0.5), (\"XX\", 0.25)])\n    return circuit, observable\n"""
    if pattern == "variational_sampler":
        return """def build_workload():\n    from qiskit.circuit.library import RealAmplitudes\n    circuit = RealAmplitudes(3, reps=1).decompose()\n    circuit.measure_all()\n    return circuit\n"""
    if pattern == "amplitude":
        return """def build_workload():\n    qc = QuantumCircuit(2, 2)\n    qc.ry(0.6, 0)\n    qc.cx(0, 1)\n    qc.measure([0, 1], [0, 1])\n    return qc\n"""
    return """def build_workload():\n    # Starter circuit. Replace this body with the algorithm-specific oracle,\n    # ansatz, Hamiltonian, feature map, or experiment circuit described by the\n    # accompanying knowledge card.\n    qc = QuantumCircuit(2, 2)\n    qc.h(0)\n    qc.cx(0, 1)\n    qc.measure([0, 1], [0, 1])\n    return qc\n"""


def common_helpers() -> str:
    return r'''
def _backend_name(value):
    name = getattr(value, "name", None)
    return name() if callable(name) else str(name or value)


def _backend_qubits(value):
    count = getattr(value, "num_qubits", None)
    if isinstance(count, int):
        return count
    target = getattr(value, "target", None)
    count = getattr(target, "num_qubits", None)
    if isinstance(count, int):
        return count
    configuration = getattr(value, "configuration", None)
    if callable(configuration):
        return int(getattr(configuration(), "n_qubits", 0))
    return 0


def _backend_is_simulator(value):
    configuration = getattr(value, "configuration", None)
    if callable(configuration):
        return bool(getattr(configuration(), "simulator", False))
    return bool(getattr(value, "simulator", False))


def _backend_operational(value):
    status = getattr(value, "status", None)
    if callable(status):
        return bool(getattr(status(), "operational", True))
    return True


def _is_open_plan(value):
    return "open" in str(value).strip().lower()


def _is_paid_plan(value):
    lowered = str(value).strip().lower()
    return any(name in lowered for name in ("paid", "flex", "premium", "dedicated", "paygo"))


def _validate_real_backend(value, required_qubits):
    if value is None:
        raise RuntimeError("Qiskit Connector did not return a backend")
    if _backend_is_simulator(value):
        raise RuntimeError("Connector returned a simulator instead of a real QPU")
    if not _backend_operational(value):
        raise RuntimeError(f"backend {_backend_name(value)} is not operational")
    available = _backend_qubits(value)
    if available and available < required_qubits:
        raise RuntimeError(f"backend has {available} qubits but {required_qubits} are required")
'''


def sampler_code(entry: dict[str, Any]) -> str:
    return f'''#!/usr/bin/env python3
"""BQCA {entry['name']} starter for Qiskit 2.5+.

Catalog status: {entry['status']}. Review the companion design card before use.
"""
from __future__ import annotations

from qiskit import QuantumCircuit, transpile
from qiskit_aer import AerSimulator
from qiskit_ibm_runtime import SamplerV2 as Sampler, Session
from qiskit_connector import QConnectorV2 as connector
from qiskit_connector import QPlanV2 as plan

current = plan()
backend = connector()

{builder_code(str(entry.get('template_pattern', 'generic')), 'sampler')}
{common_helpers()}

def run_real_qpu(circuit):
    _validate_real_backend(backend, circuit.num_qubits)
    isa_circuit = transpile(circuit, backend=backend, optimization_level=3)
    if _is_open_plan(current):
        sampler = Sampler(mode=backend)
        job = sampler.run([isa_circuit], shots=1024)
    elif _is_paid_plan(current):
        with Session(backend=backend) as session:
            sampler = Sampler(mode=session)
            job = sampler.run([isa_circuit], shots=1024)
    else:
        raise RuntimeError(f"unsupported plan: {{current}}")
    result = job.result()
    print("BQCA_EXECUTION_TARGET=REAL_QPU")
    print(f"BQCA_PLAN={{current}}")
    print(f"BQCA_BACKEND={{_backend_name(backend)}}")
    print(f"BQCA_JOB_ID={{job.job_id()}}")
    return result


def run_simulator(circuit, reason):
    sim_backend = AerSimulator()
    compiled = transpile(circuit, backend=sim_backend, optimization_level=1)
    result = sim_backend.run(compiled, shots=1024).result()
    counts = result.get_counts(compiled)
    print("BQCA_EXECUTION_TARGET=SIMULATOR")
    print(f"BQCA_PLAN={{current}}")
    print(f"BQCA_BACKEND={{_backend_name(sim_backend)}}")
    print(f"BQCA_FALLBACK_REASON={{reason}}")
    return counts


def main():
    circuit = build_workload()
    try:
        value = run_real_qpu(circuit)
    except Exception as exc:
        value = run_simulator(circuit, exc)
    print("BQCA_RESULT=SUCCESS")
    print(f"BQCA_RESULT_VALUE={{value!r}}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
'''


def estimator_code(entry: dict[str, Any]) -> str:
    return f'''#!/usr/bin/env python3
"""BQCA {entry['name']} starter for Qiskit 2.5+.

Catalog status: {entry['status']}. Review the companion design card before use.
"""
from __future__ import annotations

from qiskit import transpile
from qiskit.transpiler import generate_preset_pass_manager
from qiskit_aer import AerSimulator
from qiskit_aer.primitives import EstimatorV2 as AerEstimator
from qiskit_ibm_runtime import EstimatorV2 as Estimator, Session
from qiskit_connector import QConnectorV2 as connector
from qiskit_connector import QPlanV2 as plan

current = plan()
backend = connector()

{builder_code(str(entry.get('template_pattern', 'variational')), 'estimator')}
{common_helpers()}

def run_real_qpu(circuit, observable):
    _validate_real_backend(backend, circuit.num_qubits)
    pass_manager = generate_preset_pass_manager(backend=backend, optimization_level=3)
    isa_circuit = pass_manager.run(circuit)
    isa_observable = observable.apply_layout(isa_circuit.layout)
    if _is_open_plan(current):
        estimator = Estimator(mode=backend)
        job = estimator.run([(isa_circuit, isa_observable)])
    elif _is_paid_plan(current):
        with Session(backend=backend) as session:
            estimator = Estimator(mode=session)
            job = estimator.run([(isa_circuit, isa_observable)])
    else:
        raise RuntimeError(f"unsupported plan: {{current}}")
    result = job.result()
    print("BQCA_EXECUTION_TARGET=REAL_QPU")
    print(f"BQCA_PLAN={{current}}")
    print(f"BQCA_BACKEND={{_backend_name(backend)}}")
    print(f"BQCA_JOB_ID={{job.job_id()}}")
    return result


def run_simulator(circuit, observable, reason):
    sim_backend = AerSimulator()
    transpile(circuit, backend=sim_backend, optimization_level=1)
    estimator = AerEstimator()
    result = estimator.run([(circuit, observable)]).result()
    print("BQCA_EXECUTION_TARGET=SIMULATOR")
    print(f"BQCA_PLAN={{current}}")
    print(f"BQCA_BACKEND={{_backend_name(sim_backend)}}")
    print(f"BQCA_FALLBACK_REASON={{reason}}")
    return result


def main():
    circuit, observable = build_workload()
    try:
        value = run_real_qpu(circuit, observable)
    except Exception as exc:
        value = run_simulator(circuit, observable, exc)
    print("BQCA_RESULT=SUCCESS")
    print(f"BQCA_RESULT_VALUE={{value!r}}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
'''


def scaffold_code(entry: dict[str, Any]) -> str:
    if entry["primitive"] == "estimator":
        return estimator_code(entry)
    return sampler_code(entry)


def write_text(path: pathlib.Path, text: str, force: bool) -> None:
    if path.exists() and not force:
        raise FileExistsError(f"output exists; use --force: {path}")
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_text(text, encoding="utf-8")
    temporary.replace(path)


def command_list(data: dict[str, Any], category: str | None) -> int:
    entries = data["entries"]
    if category:
        entries = [entry for entry in entries if category.lower() in entry["category"].lower()]
    for entry in entries:
        print(f"{entry['slug']:<38} {entry['primitive']:<10} {entry['status']:<16} {entry['name']}")
    print(f"TOTAL={len(entries)}")
    return 0


def command_search(data: dict[str, Any], query: str, limit: int) -> int:
    results = search_entries(data, query, limit)
    for score, entry in results:
        print(f"SCORE={score:<3} SLUG={entry['slug']} NAME={entry['name']} PRIMITIVE={entry['primitive']} STATUS={entry['status']}")
        print(f"  {entry['summary']}")
    print(f"MATCHES={len(results)}")
    return 0 if results else 1


def command_research(data: dict[str, Any], query: str, output: pathlib.Path | None, limit: int, catalog_path: pathlib.Path) -> int:
    results = search_entries(data, query, limit)
    if not results:
        print("BQCA_LOCAL_KB=NO_MATCH", file=sys.stderr)
        return 4
    lines = [
        "# BQCA Local Quantum Knowledgebase Consultation", "",
        f"- Query: `{query}`", f"- Catalog: `{catalog_path}`",
        f"- Catalog SHA-256: `{catalog_hash(catalog_path)}`",
        "- Network crawling required: **No**", "",
        "## Recommended algorithm entries", "",
    ]
    for score, entry in results:
        lines.extend([
            f"### {entry['name']} (`{entry['slug']}`)", "",
            f"- Match score: {score}", f"- Category: {entry['category']}",
            f"- Primitive: {entry['primitive']}", f"- Status: {entry['status']}",
            f"- Summary: {entry['summary']}", f"- Open Plan: {entry['open_plan']}",
            f"- Paid Plan: {entry['paid_plan']}", f"- Simulator: {entry['simulator']}", "",
        ])
    lines.extend([
        "## BQCA decision note", "",
        "Use these local entries with IBM Bob intelligence and the active central BQCA policy. "
        "If the requested method is not represented, use approved external research without treating the local catalog as a blocking gate.", "",
    ])
    text = "\n".join(lines)
    if output:
        write_text(output.resolve(), text, force=True)
        print(f"BQCA_LOCAL_KB=PASS OUTPUT={output.resolve()}")
    else:
        print(text)
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog", type=pathlib.Path, default=DEFAULT_CATALOG)
    sub = parser.add_subparsers(dest="command", required=True)
    p_list = sub.add_parser("list")
    p_list.add_argument("--category")
    p_search = sub.add_parser("search")
    p_search.add_argument("--query", required=True)
    p_search.add_argument("--limit", type=int, default=10)
    p_show = sub.add_parser("show")
    p_show.add_argument("slug")
    p_design = sub.add_parser("design")
    p_design.add_argument("slug")
    p_design.add_argument("--output", type=pathlib.Path)
    p_design.add_argument("--force", action="store_true")
    p_scaffold = sub.add_parser("scaffold")
    p_scaffold.add_argument("slug")
    p_scaffold.add_argument("--output", required=True, type=pathlib.Path)
    p_scaffold.add_argument("--force", action="store_true")
    p_research = sub.add_parser("research")
    p_research.add_argument("--query", required=True)
    p_research.add_argument("--output", type=pathlib.Path)
    p_research.add_argument("--limit", type=int, default=5)
    p_research.add_argument("--allow-incomplete", action="store_true", help=argparse.SUPPRESS)
    p_generate = sub.add_parser("generate-examples")
    p_generate.add_argument("--output-dir", type=pathlib.Path, default=HERE / "examples")
    p_generate.add_argument("--force", action="store_true")
    sub.add_parser("validate")
    sub.add_parser("plan-matrix")
    args = parser.parse_args()

    catalog_path = args.catalog.resolve()
    try:
        data = load_catalog(catalog_path)
    except Exception as exc:
        print(f"BQCA_LOCAL_KB=FAIL: {exc}", file=sys.stderr)
        return 2
    entries = index_by_slug(data)

    if args.command == "list":
        return command_list(data, args.category)
    if args.command == "search":
        return command_search(data, args.query, args.limit)
    if args.command == "show":
        entry = entries.get(args.slug)
        if not entry:
            print(f"unknown algorithm slug: {args.slug}", file=sys.stderr)
            return 3
        print_entry(entry)
        return 0
    if args.command == "design":
        entry = entries.get(args.slug)
        if not entry:
            print(f"unknown algorithm slug: {args.slug}", file=sys.stderr)
            return 3
        text = design_markdown(entry, catalog_path)
        if args.output:
            write_text(args.output.resolve(), text, args.force)
            print(f"DESIGN={args.output.resolve()}")
        else:
            print(text)
        return 0
    if args.command == "scaffold":
        entry = entries.get(args.slug)
        if not entry:
            print(f"unknown algorithm slug: {args.slug}", file=sys.stderr)
            return 3
        write_text(args.output.resolve(), scaffold_code(entry), args.force)
        print(f"CODE={args.output.resolve()}")
        print(f"STATUS={entry['status']}")
        return 0
    if args.command == "research":
        return command_research(data, args.query, args.output, args.limit, catalog_path)
    if args.command == "generate-examples":
        output_dir = args.output_dir.resolve()
        for entry in data["entries"]:
            write_text(output_dir / f"{entry['slug']}-design.md", design_markdown(entry, catalog_path), args.force)
            if entry["status"] != "design_reference":
                write_text(output_dir / f"{entry['slug']}.py", scaffold_code(entry), args.force)
        print(f"EXAMPLES={output_dir}")
        return 0
    if args.command == "validate":
        print("BQCA_LOCAL_KB=PASS")
        print(f"CATALOG={catalog_path}")
        print(f"SHA256={catalog_hash(catalog_path)}")
        print(f"ENTRIES={len(data['entries'])}")
        print(f"QISKIT_MIN_VERSION={data['qiskit_min_version']}")
        return 0
    if args.command == "plan-matrix":
        print("OPEN_PLAN: SamplerV2(mode=backend) or EstimatorV2(mode=backend); Session prohibited")
        print("PAID_PLAN: Session(backend=backend) with SamplerV2(mode=session) or EstimatorV2(mode=session)")
        print("SIMULATOR: controlled fallback with AerSimulator or Aer V2 primitives")
        return 0
    return 2


if __name__ == "__main__":
    raise SystemExit(main())

# BQCA-ACTIVE-CENTRAL-POLICY:BEGIN
# Resolve the active authority through bqca-active-policy-listener.sh before
# every quantum DESIGN or CODE decision. Never hardcode a policy version or
# duplicate the full policy here. qiskit-design-policy-check.py and
# qiskit-code-policy-check.py reload the active registry/policy/contract on
# every invocation and create same-directory policy-compliance reports.
# Do not report completion until the active-policy report exists.
# BQCA-ACTIVE-CENTRAL-POLICY:END
