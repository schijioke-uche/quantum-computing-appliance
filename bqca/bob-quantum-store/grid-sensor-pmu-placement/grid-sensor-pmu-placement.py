#!/usr/bin/env python3
"""Grid sensor (PMU) placement with QAOA on an IBM Quantum QPU.

EDUCATIONAL DEMONSTRATION on the standard WSCC 9-bus test system. It is not a
utility planning tool.

Problem:
  A Phasor Measurement Unit (PMU) is a GPS-synchronised grid sensor. A PMU on a
  bus observes that bus and every bus directly connected to it. What is the
  fewest number of PMUs that lets the operator observe the whole grid?

Pipeline:
  1. Encode "one qubit per bus, 1 = install a PMU" as a QUBO cost.
  2. Tune the single-layer QAOA angles on a noise-free state-vector simulation.
  3. Run the QAOA circuit on a real QPU through the Qiskit Connector (sampling only).
  4. Decode every sampled bitstring into a bus list and verify observability.
  5. Compare with the exact brute-force optimum and the random-guess baseline.

Default execution:
  .bob/quantum-tools/bqca-direct-execution.sh run <this-file.py>
Execution order: real QPU through the Qiskit Connector first, controlled
AerSimulator fallback on any failure or if the QPU result misses the success criteria.
"""
from __future__ import annotations

import math
import os
import sys
import textwrap
from datetime import datetime
from pathlib import Path
from zoneinfo import ZoneInfo


def hand_off_to_bqca_wrapper() -> None:
    """Interactive terminal run: re-launch through the BQCA direct-execution wrapper.

    The wrapper uses $HOME/qiskit-v2x-env, writes <stem>-result-output.txt and
    output.txt beside this file in the background, and keeps its own progress
    lines, footer lines and the BQCA_* contract markers off the screen. When
    stdout is not a terminal (the wrapper itself, a pipe, a file) or the hand-off
    already happened, the script runs in place.
    """
    if not sys.stdout.isatty() or os.environ.get("BQCA_DIRECT_HANDOFF") == "1":
        return
    here = Path(__file__).resolve()
    for parent in here.parents:
        wrapper = parent / ".bob" / "quantum-tools" / "bqca-direct-execution.sh"
        if wrapper.is_file() and os.access(wrapper, os.X_OK):
            os.environ["BQCA_DIRECT_HANDOFF"] = "1"
            os.environ["BQCA_QUIET_TERMINAL"] = "1"
            os.execv(str(wrapper), [str(wrapper), "run", str(here), *sys.argv[1:]])


if __name__ == "__main__":
    hand_off_to_bqca_wrapper()

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.patches import Patch
from scipy.optimize import minimize

from qiskit import QuantumCircuit, transpile
from qiskit_aer import AerSimulator
from qiskit_aer.primitives import SamplerV2 as AerSamplerV2
from qiskit_ibm_runtime import SamplerV2, Session
from qiskit_connector import QConnectorV2 as connector
from qiskit_connector import QPlanV2 as plan

BQCA_REQUIRED_ENV = "$HOME/qiskit-v2x-env"
BQCA_MIN_QISKIT_VERSION = "Qiskit >= 2.5"
BQCA_DIRECT_EXECUTION = ".bob/quantum-tools/bqca-direct-execution.sh"

STEM = "grid-sensor-pmu-placement"
GRID_NAME = "WSCC 9-bus test system"
N_BUSES = 9                                   # one qubit per bus
BRANCHES = [(1, 4), (2, 7), (3, 9), (4, 5), (4, 6), (5, 7), (6, 9), (7, 8), (8, 9)]
ROLES = {1: "Generator", 2: "Generator", 3: "Generator", 4: "Junction", 5: "Load",
         6: "Load", 7: "Junction", 8: "Load", 9: "Junction"}
PENALTY = 2.0                                 # cost of one unobserved bus (> cost of one PMU)
SHOTS = 4096
SEED = 11
MIN_ENRICHMENT = 1.5                          # success: optimal-placement chance >= 1.5x random
WIDTH = 104

OUT_DIR = os.path.dirname(os.path.abspath(__file__))   # works from any working directory

# ---------------------------------------------------------------------------
# Terminal colour. On only for an interactive terminal or the terminal hand-off,
# off when NO_COLOR is set. The wrapper strips colour codes from the result files.
# ---------------------------------------------------------------------------
USE_COLOR = "NO_COLOR" not in os.environ and (
    sys.stdout.isatty()
    or os.environ.get("BQCA_DIRECT_HANDOFF") == "1"
    or bool(os.environ.get("FORCE_COLOR"))
)
CODES = {"bold": "1", "dim": "2", "red": "31", "green": "32", "yellow": "33", "blue": "34",
         "magenta": "35", "cyan": "36", "white": "97", "gray": "90"}


def paint(text: str, *styles: str) -> str:
    if not USE_COLOR or not styles:
        return text
    return "\033[" + ";".join(CODES[style] for style in styles) + "m" + text + "\033[0m"


def cell_parts(cell) -> tuple[str, tuple[str, ...]]:
    return (cell, ()) if isinstance(cell, str) else (cell[0], tuple(cell[1]))


def box_table(headers: list[str], rows: list[list], border=("blue",), head=("bold", "cyan")) -> None:
    """Unicode box table. Cells are text or (text, styles); widths use the plain text."""
    widths = [len(header) for header in headers]
    for row in rows:
        for index, cell in enumerate(row):
            widths[index] = max(widths[index], len(cell_parts(cell)[0]))

    def edge(left: str, mid: str, right: str) -> str:
        return paint(left + mid.join("─" * (width + 2) for width in widths) + right, *border)

    def line(cells: list) -> str:
        bar = paint("│", *border)
        pieces = [" " + paint(text.ljust(width), *styles) + " "
                  for (text, styles), width in zip(map(cell_parts, cells), widths)]
        return bar + bar.join(pieces) + bar

    print(edge("┌", "┬", "┐"))
    print(line([(header, head) for header in headers]))
    print(edge("├", "┼", "┤"))
    for row in rows:
        print(line(row))
    print(edge("└", "┴", "┘"))


def section(title: str) -> None:
    print()
    print(paint(f"━━ {title} " + "━" * max(3, WIDTH - len(title) - 4), "bold", "blue"))


def normalized_plan(value: object) -> str:
    return str(value).strip().lower().replace("_", " ").replace("-", " ")


def buses_of(index: int) -> list[int]:
    """Bus numbers (1-based) that carry a PMU in the placement with this integer value."""
    return [bus + 1 for bus in range(N_BUSES) if (index >> bus) & 1]


def bus_set(buses: list[int]) -> str:
    return "{" + ", ".join(str(bus) for bus in buses) + "}" if buses else "{}"


# ---------------------------------------------------------------------------
# Grid model and exact classical solution
# ---------------------------------------------------------------------------
def closed_neighbourhoods() -> list[set[int]]:
    """For each bus (0-based): itself plus every bus directly connected to it."""
    neighbourhood = [{bus} for bus in range(N_BUSES)]
    for first, second in BRANCHES:
        neighbourhood[first - 1].add(second - 1)
        neighbourhood[second - 1].add(first - 1)
    return neighbourhood


NEIGHBOURS = closed_neighbourhoods()


def placement_tables():
    """Evaluate all 2^9 placements: PMU count, QUBO cost, and full observability."""
    index = np.arange(2 ** N_BUSES)
    placed = (index[:, None] >> np.arange(N_BUSES)) & 1
    sizes = placed.sum(axis=1)
    unobserved = np.zeros(index.size, dtype=int)
    for bus in range(N_BUSES):
        seen = np.zeros(index.size, dtype=bool)
        for neighbour in NEIGHBOURS[bus]:
            seen |= placed[:, neighbour] == 1
        unobserved += (~seen).astype(int)
    cost = sizes.astype(float) + PENALTY * unobserved
    return sizes, cost, unobserved == 0


def exact_solution(sizes, feasible):
    minimum = int(sizes[feasible].min())
    return minimum, feasible & (sizes == minimum)


def pauli_z_terms(cost) -> list[tuple[int, float]]:
    """Walsh-Hadamard transform: cost(x) = sum_S c_S * (-1)^(S.x). Returns (S, c_S), S != 0."""
    values = cost.astype(float).copy()
    half = 1
    while half < values.size:
        blocks = values.reshape(-1, 2, half)
        values = np.stack([blocks[:, 0, :] + blocks[:, 1, :],
                           blocks[:, 0, :] - blocks[:, 1, :]], axis=1).reshape(-1)
        half *= 2
    values /= values.size
    return [(subset, float(values[subset])) for subset in range(1, values.size)
            if abs(values[subset]) > 1e-12]


def qaoa_state(gamma: float, beta: float, cost):
    """Exact depth-1 QAOA state vector (noise-free), used only to tune the angles."""
    state = np.exp(-1j * gamma * cost) / math.sqrt(cost.size)
    state = state.reshape([2] * N_BUSES)
    cosine, sine = math.cos(beta), -1j * math.sin(beta)
    for axis in range(N_BUSES):
        low, high = np.take(state, 0, axis=axis), np.take(state, 1, axis=axis)
        state = np.stack([cosine * low + sine * high, sine * low + cosine * high], axis=axis)
    return state.reshape(-1)


def tune_angles(cost) -> tuple[float, float, float]:
    """Coarse grid search, then Nelder-Mead, on the noise-free expected cost."""
    def energy(angles) -> float:
        return float((np.abs(qaoa_state(angles[0], angles[1], cost)) ** 2 * cost).sum())

    start = min((energy((g, b)), g, b)
                for g in np.linspace(0, math.pi, 25) for b in np.linspace(0, math.pi / 2, 13))
    result = minimize(energy, [start[1], start[2]], method="Nelder-Mead")
    return float(result.x[0]), float(result.x[1]), float(result.fun)


# ---------------------------------------------------------------------------
# Quantum circuit and execution
# ---------------------------------------------------------------------------
def build_qaoa_circuit(terms, gamma: float, beta: float) -> QuantumCircuit:
    """Depth-1 QAOA: H layer, cost layer (parity ladder + RZ), RX mixer, measure all."""
    circuit = QuantumCircuit(N_BUSES, name="pmu_qaoa")
    circuit.h(range(N_BUSES))
    for subset, coefficient in terms:
        qubits = [qubit for qubit in range(N_BUSES) if (subset >> qubit) & 1]
        target = qubits[-1]
        for control in qubits[:-1]:
            circuit.cx(control, target)
        circuit.rz(2 * gamma * coefficient, target)
        for control in reversed(qubits[:-1]):
            circuit.cx(control, target)
    circuit.rx(2 * beta, range(N_BUSES))
    circuit.measure_all()
    return circuit


def counts_from(result) -> dict:
    return result[0].data.meas.get_counts()


def run_real_qpu(circuit: QuantumCircuit):
    """First attempt: real IBM QPU through the Qiskit Connector."""
    current = plan()
    backend = connector()
    name = str(getattr(backend, "name", backend))
    if getattr(backend, "simulator", False):
        raise RuntimeError("Qiskit Connector returned a simulator instead of a real QPU")
    if not backend.status().operational:
        raise RuntimeError(f"Backend {name} is not operational")
    if backend.num_qubits < circuit.num_qubits:
        raise RuntimeError(f"Backend {name} has {backend.num_qubits} qubits, need {circuit.num_qubits}")

    isa_circuit = transpile(circuit, backend=backend, optimization_level=3, seed_transpiler=SEED)
    if "open" in normalized_plan(current):
        primitive = SamplerV2(mode=backend)                                # Open Plan: no Session
        job = primitive.run([isa_circuit], shots=SHOTS)
        result = job.result()
    else:
        with Session(backend=backend) as session:                          # Paid Plan: Session
            primitive = SamplerV2(mode=session)
            job = primitive.run([isa_circuit], shots=SHOTS)
            result = job.result()
    return counts_from(result), "REAL_QPU", str(current), name, str(job.job_id()), isa_circuit


def run_simulator(circuit: QuantumCircuit):
    """Controlled fallback: local AerSimulator."""
    sim = AerSimulator()
    isa_circuit = transpile(circuit, sim, optimization_level=1, seed_transpiler=SEED)
    result = AerSamplerV2().run([isa_circuit], shots=SHOTS).result()
    return counts_from(result), "SIMULATOR", "not applicable", "AerSimulator", "NOT_APPLICABLE", isa_circuit


def analyse(counts: dict, sizes, feasible, optimal) -> dict:
    """Decode sampled bitstrings and measure how well they hit the exact optimum."""
    total = sum(counts.values())
    per_value: dict[int, int] = {}
    for bitstring, count in counts.items():
        value = int(bitstring.replace(" ", ""), 2)
        per_value[value] = per_value.get(value, 0) + count
    ranked = sorted(per_value.items(), key=lambda item: -item[1])
    observable = [(value, count) for value, count in per_value.items() if feasible[value]]
    best = min(observable, key=lambda item: (int(sizes[item[0]]), -item[1])) if observable else None
    return {
        "total": total,
        "ranked": ranked,
        "best_value": best[0] if best else None,
        "best_count": best[1] if best else 0,
        "optimal_share": sum(count for value, count in per_value.items() if optimal[value]) / total,
        "feasible_share": sum(count for value, count in observable) / total,
        "distinct": len(per_value),
    }


def save_circuit_png(circuit: QuantumCircuit, path: str) -> bool:
    try:
        circuit.draw("mpl", filename=path, fold=-1, scale=0.5)
        return True
    except Exception as exc:
        print(paint(f"  Circuit PNG skipped: {exc}", "yellow"))
        return False


def save_placement_png(analysis: dict, sizes, feasible, optimal, target: str, path: str) -> None:
    top = analysis["ranked"][:12]
    labels = [bus_set(buses_of(value)) for value, _ in top]
    colors = ["#24a148" if optimal[value] else "#0f62fe" if feasible[value] else "#da1e28"
              for value, _ in top]
    figure, axis = plt.subplots(figsize=(9, 5))
    axis.barh(range(len(top)), [count for _, count in top], color=colors)
    axis.set_yticks(range(len(top)))
    axis.set_yticklabels(labels, fontsize=8)
    axis.invert_yaxis()
    axis.set_xlabel("Shots")
    axis.set_title(f"Most-sampled PMU placements, {GRID_NAME} ({target})")
    axis.legend(handles=[Patch(color="#24a148", label="Optimal, observable"),
                         Patch(color="#0f62fe", label="Observable, not minimal"),
                         Patch(color="#da1e28", label="Not fully observable")], loc="lower right")
    figure.tight_layout()
    figure.savefig(path, dpi=150)
    plt.close(figure)


def emit_marker(line: str) -> None:
    """Print a BQCA_* contract marker for the wrapper or formal orchestrator.

    The markers repeat what the summary table shows, so they are not printed to
    an interactive terminal. When stdout is captured (bqca-direct-execution.sh,
    the formal orchestrator, a pipe or a file) they are printed so the result
    contract can read them.
    """
    if not sys.stdout.isatty():
        print(line)


# ---------------------------------------------------------------------------
# Terminal presentation
# ---------------------------------------------------------------------------
def bar(share: float, scale: float, width: int = 22) -> str:
    return "█" * max(1, round(width * share / scale)) if share > 0 else ""


def print_banner() -> None:
    line = paint("═" * WIDTH, "bold", "cyan")
    print(line)
    print(paint("  ⚡ Grid Sensor (PMU) Placement with QAOA on an IBM Quantum QPU", "bold", "white"))
    print(paint(f"  Energy-industry demo · {GRID_NAME} · {N_BUSES} buses → {N_BUSES} qubits", "cyan"))
    print(paint("  Educational only: a 9-qubit quantum workflow demonstration.", "dim"))
    print(line)


def print_grid_table() -> None:
    section("1 · THE GRID: where could a sensor go?")
    rows = []
    for bus in range(1, N_BUSES + 1):
        linked = sorted(({b for a, b in BRANCHES if a == bus} | {a for a, b in BRANCHES if b == bus}))
        role = ROLES[bus]
        style = {"Generator": ("bold", "yellow"), "Load": ("bold", "magenta")}.get(role, ("bold", "white"))
        rows.append([(str(bus), ("bold", "white")), (f"q{bus - 1}", ("cyan",)), (role, style),
                     ", ".join(str(b) for b in linked),
                     bus_set(sorted(n + 1 for n in NEIGHBOURS[bus - 1]))])
    box_table(["Bus", "Qubit", "Role", "Directly linked to", "Observed if a PMU sits on any of"], rows)


def print_qubo_table(min_pmus: int, n_optimal: int, n_feasible: int) -> None:
    section("2 · THE PROBLEM AS A QUANTUM OPTIMISATION")
    rows = [
        [("Meaning of a qubit", ("bold",)), "Qubit i measured as 1 means: install a PMU on bus i + 1"],
        [("Observability rule", ("bold",)), "A PMU sees its own bus and every bus directly connected to it"],
        [("Cost to minimise", ("bold",)), f"(number of PMUs) + {PENALTY:.0f} × (number of unobserved buses)"],
        [("Search space", ("bold",)), f"{2 ** N_BUSES} placements, of which {n_feasible} observe the whole grid"],
        [("Exact optimum (brute force)", ("bold",)),
         (f"{min_pmus} PMUs, reached by {n_optimal} different placements", ("bold", "green"))],
        [("Quantum algorithm", ("bold",)), "QAOA, one layer: the QPU samples candidate placements"],
    ]
    box_table(["Item", "Description"], rows)


def print_ranked_table(analysis: dict, sizes, feasible, optimal) -> None:
    section("4 · WHAT WAS SAMPLED: most frequent PMU placements")
    top = analysis["ranked"][:8]
    scale = max(count for _, count in top) / analysis["total"]
    rows = []
    for rank, (value, count) in enumerate(top, 1):
        share = count / analysis["total"]
        if optimal[value]:
            mark, style = "✔ optimal", ("bold", "green")
        elif feasible[value]:
            mark, style = "✔ observable", ("blue",)
        else:
            mark, style = "✘ gaps", ("red",)
        rows.append([str(rank), (bus_set(buses_of(value)), ("bold", "white")), str(int(sizes[value])),
                     f"{count}", f"{share:6.1%}", (bar(share, scale), style), (mark, style)])
    box_table(["#", "PMU buses", "PMUs", "Shots", "Share", "Frequency", "Grid status"], rows)
    print(paint(f"  {analysis['distinct']} distinct placements were sampled out of {2 ** N_BUSES} possible.",
                "dim"))


def print_coverage_table(best_value: int) -> None:
    section("5 · PROOF: every bus covered by the best placement")
    placed = set(buses_of(best_value))
    rows = []
    for bus in range(1, N_BUSES + 1):
        watchers = sorted(n + 1 for n in NEIGHBOURS[bus - 1] if (n + 1) in placed)
        own = bus in placed
        rows.append([str(bus), ("PMU installed" if own else "-", ("bold", "green") if own else ("dim",)),
                     ", ".join(str(w) for w in watchers) or "none",
                     ("✔ observed", ("green",)) if watchers else ("✘ blind", ("bold", "red"))])
    box_table(["Bus", "Own sensor", "Seen by PMU on bus", "Status"], rows)


def print_summary_table(rows: list[tuple[str, str]], inference: str, notes: list[str],
                        fallback_full: str) -> None:
    """Print the dated RESULT SUMMARY table, the experiment inference and the notes."""
    plain = dict(rows)
    width_item = max(len("Item"), *(len(item) for item, _ in rows))
    width_value = max(len("Value"), *(len(value) for _, value in rows))
    rule = f"+-{'-' * width_item}-+-{'-' * width_value}-+"
    now = datetime.now(ZoneInfo("America/New_York"))        # Eastern time (EST/EDT)
    stamp = f"{now:%B} {now.day}, {now:%Y}, {now:%I:%M %p %Z}"
    result_style = ("bold", "green") if plain["Result"].startswith("SUCCESS") else ("bold", "red")
    target_style = ("bold", "green") if plain["Execution target"] == "REAL_QPU" else ("bold", "yellow")

    print()
    print(paint("=" * len(rule), "bold", "magenta"))
    print(paint(f"RESULT SUMMARY    -  {stamp}", "bold", "white"))
    print(paint("=" * len(rule), "bold", "magenta"))
    print(paint(rule, "blue"))
    print(f"{paint('|', 'blue')} {paint('Item'.ljust(width_item), 'bold', 'cyan')} {paint('|', 'blue')} "
          f"{paint('Value'.ljust(width_value), 'bold', 'cyan')} {paint('|', 'blue')}")
    print(paint(rule, "blue"))
    for item, value in rows:
        style = result_style if item == "Result" else target_style if item == "Execution target" else ("white",)
        print(f"{paint('|', 'blue')} {paint(item.ljust(width_item), 'bold')} {paint('|', 'blue')} "
              f"{paint(value.ljust(width_value), *style)} {paint('|', 'blue')}")
    print(paint(rule, "blue"))

    print(paint("EXPERIMENT INFERENCE:", "bold", "yellow"))
    for paragraph in inference.split("\n\n"):
        head, _, body = paragraph.partition(" ")
        label = head if head.endswith(".") and head.isupper() else ""
        wrapped = textwrap.fill(paragraph, width=len(rule), break_on_hyphens=False)
        if label:
            first, _, rest = wrapped.partition(" ")
            print(paint(first, "bold", "cyan") + (" " + rest if rest else ""))
        else:
            print(wrapped)
        print()
    print(paint("NOTES:", "bold", "yellow"))
    for number, note in enumerate(notes, 1):
        print(textwrap.fill(f"{number}. {note}", width=len(rule), subsequent_indent="   ",
                            break_on_hyphens=False))
    print(paint("-" * len(rule), "magenta"))

    values = plain
    emit_marker(f"BQCA_EXECUTION_TARGET={values['Execution target']}")
    emit_marker(f"BQCA_PLAN={values['Plan']}")
    emit_marker(f"BQCA_BACKEND={values['Backend']}")
    emit_marker(f"BQCA_JOB_ID={values['Job ID']}")
    emit_marker(f"BQCA_FALLBACK_REASON={fallback_full}")


NOTES = [
    "A PMU (phasor measurement unit) is a GPS-synchronised grid sensor. Fewer PMUs means lower "
    "installation and communication cost, but the operator must still see every bus.",
    "The model is topological only: a PMU observes its own bus and its direct neighbours. Real "
    "planning also uses zero-injection buses, line-outage redundancy, channel limits and costs.",
    "The QAOA angles were tuned on a noise-free classical simulation. The QPU only sampled the "
    "circuit; it did no learning, and its answer was checked against brute force.",
    "This run is a 9-qubit workflow demonstration; it does not claim a quantum speed-up.",
    "Next steps: larger IEEE test systems (14, 30, 57 buses), more QAOA layers, error "
    "mitigation, and zero-injection and N-1 constraints.",
]


def build_inference(ok: bool, ctx: dict) -> str:
    """Detailed plain-language inference, built from the measured numbers."""
    where = (f"on the real QPU {ctx['backend']}" if ctx["target"] == "REAL_QPU"
             else "on the local AerSimulator (not on quantum hardware)")
    what = (f"WHAT WAS RUN. A one-layer QAOA circuit with {N_BUSES} qubits, one per bus of the {GRID_NAME}, "
            f"was sampled {ctx['shots']} times {where}. Each measured bitstring is a candidate PMU placement. "
            f"The circuit has {ctx['logical_2q']} two-qubit gates before transpilation and {ctx['t_2q']} after, "
            f"with depth {ctx['t_depth']}.")
    if not ok:
        reason = ctx["failure_reason"]
        return (what + "\n\n"
                f"RESULT. This experiment is not successful. {reason} The exact brute-force optimum is "
                f"{ctx['min_pmus']} PMUs, and the sampled optimal-placement share was "
                f"{ctx['optimal_share']:.1%} against {ctx['baseline']:.1%} for random guessing "
                f"({ctx['enrichment']:.1f}x).\n\n"
                "WHAT THIS MEANS. Hardware noise or a shallow ansatz can wash out a small signal. "
                "A failed check is a valid scientific outcome here; it is reported as it is and is "
                "never replaced by simulator output without saying so.")
    trust = (f"WHY IT CAN BE TRUSTED. The answer is not taken on faith. Classical code enumerated all "
             f"{2 ** N_BUSES} placements and found the exact minimum of {ctx['min_pmus']} PMUs, then "
             f"re-checked that every bus is within one hop of a PMU in the reported placement. "
             f"The optimal-placement share is {ctx['enrichment']:.1f}x the random baseline, above the "
             f"{MIN_ENRICHMENT:.1f}x threshold used for success.")
    shown = (f"WHAT THE RESULT SHOWS. The best fully observable placement sampled is "
             f"{bus_set(buses_of(ctx['best_value'])).replace(', ', ',')}, using {ctx['best_pmus']} PMUs, which equals the exact "
             f"minimum. {ctx['optimal_share']:.1%} of shots landed on one of the {ctx['n_optimal']} optimal "
             f"placements, against {ctx['baseline']:.1%} for a random guess, and {ctx['feasible_share']:.1%} "
             f"of shots observed the whole grid, against {ctx['feasible_baseline']:.1%} at random.")
    if ctx["target"] == "REAL_QPU":
        noise = (f"WHAT THE QPU CONTRIBUTED. It produced the samples. The noise-free prediction for this "
                 f"circuit is {ctx['ideal_share']:.1%} on optimal placements; the hardware gave "
                 f"{ctx['optimal_share']:.1%}. The gap is hardware noise, and it is the honest measure of "
                 f"how far today's devices are from a clean run.")
    else:
        noise = ("WHAT THE SIMULATOR CONTRIBUTED. The real-QPU attempt did not give a usable result "
                 f"({ctx['fallback_reason']}), so the same circuit was run on a local noise-free simulator. "
                 "No quantum hardware produced this result.")
    limits = ("LIMITS. This is a 9-qubit workflow demonstration. It does not claim a quantum advantage, "
              "and the result says nothing about utility-scale grids.")
    return "\n\n".join([what, shown, trust, noise, limits])


def count_two_qubit_gates(circuit: QuantumCircuit) -> int:
    return sum(count for name, count in circuit.count_ops().items()
               if name in {"cx", "cz", "ecr", "swap", "rzz"})


def meets_criteria(analysis: dict, min_pmus: int, sizes, baseline: float) -> tuple[bool, str]:
    """Success: best observable placement is minimal and optimal share beats the random baseline."""
    if analysis["best_value"] is None:
        return False, "No sampled placement observed the whole grid."
    best_pmus = int(sizes[analysis["best_value"]])
    if best_pmus != min_pmus:
        return False, (f"The best observable placement used {best_pmus} PMUs, not the exact minimum "
                       f"of {min_pmus}.")
    enrichment = analysis["optimal_share"] / baseline
    if enrichment < MIN_ENRICHMENT:
        return False, (f"The optimal-placement share was only {enrichment:.1f}x the random baseline "
                       f"(need {MIN_ENRICHMENT:.1f}x).")
    return True, ""


def main() -> int:
    os.makedirs(OUT_DIR, exist_ok=True)
    sizes, cost, feasible = placement_tables()
    min_pmus, optimal = exact_solution(sizes, feasible)
    baseline = float(optimal.mean())
    feasible_baseline = float(feasible.mean())

    print_banner()
    print_grid_table()
    print_qubo_table(min_pmus, int(optimal.sum()), int(feasible.sum()))

    gamma, beta, ideal_energy = tune_angles(cost)
    ideal_probs = np.abs(qaoa_state(gamma, beta, cost)) ** 2
    ideal_share = float(ideal_probs[optimal].sum())
    terms = pauli_z_terms(cost)
    circuit = build_qaoa_circuit(terms, gamma, beta)
    logical_2q = count_two_qubit_gates(circuit)

    section("3 · CIRCUIT AND EXECUTION")
    print(f"  {paint('QAOA angles', 'bold')}   gamma = {gamma:.4f}, beta = {beta:.4f}  "
          f"{paint('(tuned classically on a noise-free simulation)', 'dim')}")
    print(f"  {paint('Circuit', 'bold')}       {circuit.num_qubits} qubits, {len(terms)} cost terms, "
          f"depth {circuit.depth()} before transpilation")
    circuit_png = os.path.join(OUT_DIR, f"{STEM}-circuit.png")
    if save_circuit_png(circuit, circuit_png):
        print(f"  {paint('Saved circuit PNG', 'bold')}   {paint('**********************************', 'dim')}")

    fallback_reason = "NONE"
    print(paint("  Attempting a real QPU through the Qiskit Connector first...", "cyan"))
    try:
        counts, target, plan_name, backend_name, job_id, isa = run_real_qpu(circuit)
        analysis = analyse(counts, sizes, feasible, optimal)
        passed, why = meets_criteria(analysis, min_pmus, sizes, baseline)
        if not passed:
            raise RuntimeError(f"Real QPU result missed the success criteria: {why}")
        print(paint("  ✔ Real QPU job result retrieved and verified.", "bold", "green"))
    except Exception as exc:
        fallback_reason = str(exc).replace("\n", " ")
        emit_marker(f"BQCA_FALLBACK_REASON={fallback_reason}")
        print(paint("  ✘ Real-QPU path ended: " + textwrap.shorten(fallback_reason, 150), "yellow"))
        print(paint("  ↪ Running the controlled AerSimulator fallback...", "yellow"))
        counts, target, plan_name, backend_name, job_id, isa = run_simulator(circuit)
        analysis = analyse(counts, sizes, feasible, optimal)
        passed, why = meets_criteria(analysis, min_pmus, sizes, baseline)

    t_2q = count_two_qubit_gates(isa)
    print(f"  {paint('Transpiled', 'bold')}    depth {isa.depth()}, {t_2q} two-qubit gates, {SHOTS} shots on {backend_name}")

    print_ranked_table(analysis, sizes, feasible, optimal)
    if analysis["best_value"] is not None:
        print_coverage_table(analysis["best_value"])

    placement_png = os.path.join(OUT_DIR, f"{STEM}-placements.png")
    save_placement_png(analysis, sizes, feasible, optimal, target, placement_png)
    print(f"\n  {paint('Saved placements PNG', 'bold')}   {paint('****************************************', 'dim')}")

    enrichment = analysis["optimal_share"] / baseline
    best_value = analysis["best_value"]
    best_text = (f"{bus_set(buses_of(best_value))} ({int(sizes[best_value])} PMUs)"
                 if best_value is not None else "none observable")
    ok = passed
    rows = [
        ("Execution target", target),
        ("Plan", plan_name),
        ("Backend", backend_name),
        ("Job ID", job_id),
        ("Fallback reason", textwrap.shorten(fallback_reason, 74, placeholder="...")),
        ("Grid", f"{GRID_NAME}, {N_BUSES} buses, {len(BRANCHES)} branches"),
        ("Qubits / shots", f"{circuit.num_qubits} qubits, {SHOTS} shots"),
        ("Transpiled circuit", f"depth {isa.depth()}, {t_2q} two-qubit gates"),
        ("QAOA angles (classical)", f"gamma={gamma:.4f}, beta={beta:.4f}"),
        ("Best placement found", best_text),
        ("Exact minimum (brute force)", f"{min_pmus} PMUs, {int(optimal.sum())} optimal placements"),
        ("Observability check", "every bus covered" if best_value is not None else "FAILED"),
        ("Optimal-placement chance", f"{analysis['optimal_share']:.1%} vs {baseline:.1%} random "
                                     f"= {enrichment:.1f}x"),
        ("Fully observable share", f"{analysis['feasible_share']:.1%} vs {feasible_baseline:.1%} random"),
        ("Result", "SUCCESS" if ok else "FAILURE - criteria not met"),
    ]
    context = {
        "target": target, "backend": backend_name, "shots": SHOTS, "logical_2q": logical_2q, "t_2q": t_2q,
        "t_depth": isa.depth(), "min_pmus": min_pmus, "n_optimal": int(optimal.sum()),
        "optimal_share": analysis["optimal_share"], "baseline": baseline, "enrichment": enrichment,
        "feasible_share": analysis["feasible_share"], "feasible_baseline": feasible_baseline,
        "ideal_share": ideal_share, "best_value": best_value,
        "best_pmus": int(sizes[best_value]) if best_value is not None else 0,
        "failure_reason": why, "fallback_reason": fallback_reason,
    }
    print_summary_table(rows, build_inference(ok, context), NOTES, fallback_reason)
    emit_marker(f"BQCA_RESULT={'SUCCESS' if ok else 'FAILURE'}")
    emit_marker(f"BQCA_RESULT_VALUE=best placement {best_text}; exact minimum {min_pmus} PMUs; "
                f"optimal share {analysis['optimal_share']:.1%} ({enrichment:.1f}x random)")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
