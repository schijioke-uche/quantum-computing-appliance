#!/usr/bin/env python3
"""Toy Shor's algorithm: factor N=15 and recover a toy RSA private key.

EDUCATIONAL ONLY.  Do not apply on Real RSA (1024, 2048, and others)

SECURITY RISK: This script is an attack on RSA Cryptography - Do not use in business RSA.

Pipeline:
  1. Toy RSA key pair from p=3, q=5 (N=15, e=7). Only (N, e) is "public".
  2. Quantum order finding for a=7 mod 15 (3 counting + 4 work qubits).
  3. Classical continued fractions -> period r, then gcd -> factors p, q.
  4. phi=(p-1)(q-1), d = e^-1 mod phi -> recovered private key.
  5. Decrypt a toy ciphertext with the recovered d to prove recovery.

Default execution:
  .bob/quantum-tools/bqca-direct-execution.sh run <this-file.py>
Execution order: real QPU through the Qiskit Connector first, controlled
AerSimulator fallback on any failure or if the QPU result gives no valid factors.
"""
from __future__ import annotations

import math
import os
import sys
import time
from datetime import datetime
from fractions import Fraction
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

from qiskit import ClassicalRegister, QuantumCircuit, QuantumRegister, transpile
from qiskit.circuit.library import QFTGate
from qiskit_aer import AerSimulator
from qiskit_aer.primitives import SamplerV2 as AerSamplerV2
from qiskit_ibm_runtime import SamplerV2, Session
from qiskit_connector import QConnectorV2 as connector
from qiskit_connector import QPlanV2 as plan

BQCA_REQUIRED_ENV = "$HOME/qiskit-v2x-env"
BQCA_MIN_QISKIT_VERSION = "Qiskit >= 2.5"
BQCA_DIRECT_EXECUTION = ".bob/quantum-tools/bqca-direct-execution.sh"

# Toy RSA parameters. The attacker only knows N and e (and the ciphertext).
P_SECRET, Q_SECRET = 3, 5
N = P_SECRET * Q_SECRET          # 15
E = 7                            # public exponent, gcd(E, 8) = 1
MESSAGE = 2
BASE_A = 7                       # gcd(7, 15) = 1, order of 7 mod 15 is 4
N_COUNT = 3                      # counting qubits (resolves period 4 exactly)
N_WORK = 4                       # bits needed to hold values mod 15
SHOTS = 2048

OUT_DIR = os.path.dirname(os.path.abspath(__file__))   # works from any working directory

INFERENCE_NOTES = (
    "Only the public key and the ciphertext were used to recover the private key - "
    "That's how simple it is to attack.",
    "Large Fault-tolerant quantum computer is projected to be available in 2029.",
    "Plan migration to post-quantum cryptography (Quantum Safe Technology).",
)
INFERENCE_SUCCESS = (
    "The demo Shor's algorithm broke the Toy RSA Cryptography and recovered the RSA\n"
    "private key exponent. It also performed decrypt check for accuracy. This experiment\n"
    "is successful for the Toy RSA used.\n"
    "\n"
    "NOTES:\n"
    + "\n".join(f"{number}. {note}" for number, note in enumerate(INFERENCE_NOTES, 1))
)
INFERENCE_FAILURE = (
    "The demo Shor's algorithm did not recover the RSA private key exponent for the\n"
    "Toy RSA used. This experiment is not successful."
)


def normalized_plan(value: object) -> str:
    return str(value).strip().lower().replace("_", " ").replace("-", " ")


def format_duration(seconds: float) -> str:
    """Express an elapsed time in the most readable unit, from nanoseconds up to hours."""
    if seconds < 1e-6:
        return f"{seconds * 1e9:.3f} nanoseconds"
    if seconds < 1.0:
        return f"{seconds * 1e3:.3f} milliseconds"
    if seconds < 60.0:
        return f"{seconds:.2f} seconds"
    if seconds < 3600.0:
        return f"{seconds / 60.0:.2f} minutes"
    return f"{seconds / 3600.0:.2f} hours"


def mul_mod15_gate(multiplier: int):
    """4-qubit gate computing y -> multiplier*y mod 15 (multiplier coprime to 15)."""
    u = QuantumCircuit(N_WORK, name=f"x{multiplier} mod 15")
    if multiplier in (2, 13):
        u.swap(2, 3); u.swap(1, 2); u.swap(0, 1)
    if multiplier in (7, 8):
        u.swap(0, 1); u.swap(1, 2); u.swap(2, 3)
    if multiplier in (4, 11):
        u.swap(1, 3); u.swap(0, 2)
    if multiplier in (7, 11, 13, 14):
        for qubit in range(N_WORK):
            u.x(qubit)
    return u.to_gate()


def build_order_finding_circuit(a: int) -> QuantumCircuit:
    counting = QuantumRegister(N_COUNT, "count")
    work = QuantumRegister(N_WORK, "work")
    bits = ClassicalRegister(N_COUNT, "c")
    qc = QuantumCircuit(counting, work, bits)
    qc.h(counting)
    qc.x(work[0])                                   # work register = |1>
    for q in range(N_COUNT):
        multiplier = pow(a, 2 ** q, N)              # a^(2^q) mod N
        if multiplier != 1:
            qc.append(mul_mod15_gate(multiplier).control(1), [counting[q], *work])
    qc.append(QFTGate(N_COUNT).inverse(), counting)
    qc.measure(counting, bits)
    return qc


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

    isa_circuit = transpile(circuit, backend=backend, optimization_level=3)
    if "open" in normalized_plan(current):
        primitive = SamplerV2(mode=backend)                                # Open Plan: no Session
        job = primitive.run([isa_circuit], shots=SHOTS)
        result = job.result()
    else:
        with Session(backend=backend) as session:                          # Paid Plan: Session
            primitive = SamplerV2(mode=session)
            job = primitive.run([isa_circuit], shots=SHOTS)
            result = job.result()
    return result[0].data.c.get_counts(), "REAL_QPU", str(current), name, str(job.job_id())


def run_simulator(circuit: QuantumCircuit):
    """Controlled fallback: local AerSimulator."""
    sim = AerSimulator()
    isa_circuit = transpile(circuit, sim, optimization_level=1)
    result = AerSamplerV2().run([isa_circuit], shots=SHOTS).result()
    return result[0].data.c.get_counts(), "SIMULATOR", "not applicable", "AerSimulator", "NOT_APPLICABLE"


def find_factors(counts: dict, a: int):
    """Classical post-processing: continued fractions -> period r -> gcd -> factors."""
    for bitstring, count in sorted(counts.items(), key=lambda item: -item[1]):
        y = int(bitstring.replace(" ", ""), 2)
        if y == 0:
            continue
        den = Fraction(y, 2 ** N_COUNT).limit_denominator(N).denominator
        r = next((den * k for k in range(1, N) if den * k < N + 1 and pow(a, den * k, N) == 1), None)
        print(f"  measured y={y:>2} ({bitstring}) x{count:<5} phase={y}/{2 ** N_COUNT} -> r={r}")
        if r is None or r % 2:
            continue
        half = pow(a, r // 2, N)
        if half == N - 1:
            continue
        p, q = math.gcd(half - 1, N), math.gcd(half + 1, N)
        if p * q == N and 1 < p < N:
            return r, tuple(sorted((p, q)))
    return None, None


def save_histogram(counts: dict, target: str, path: str) -> None:
    ordered = dict(sorted(counts.items()))
    plt.figure(figsize=(7, 4))
    plt.bar(list(ordered.keys()), list(ordered.values()), color="#0f62fe")
    plt.xlabel("Counting register outcome")
    plt.ylabel("Counts")
    plt.title(f"Shor order finding, a={BASE_A}, N={N} ({target})")
    plt.tight_layout()
    plt.savefig(path, dpi=150)
    plt.close()


def emit_marker(line: str) -> None:
    """Print a BQCA_* contract marker for the wrapper or formal orchestrator.

    The markers repeat what the summary table shows, so they are not printed to
    an interactive terminal. When stdout is captured (bqca-direct-execution.sh,
    the formal orchestrator, a pipe or a file) they are printed so the result
    contract can read them.
    """
    if not sys.stdout.isatty():
        print(line)


def print_summary_table(rows: list[tuple[str, str]], inference: str) -> None:
    """Print the dated RESULT SUMMARY table, the experiment inference, then the
    BQCA contract markers.

    The wrapper reads BQCA_* markers only from lines that begin with the key, so
    the marker lines follow the table and are not folded into it.
    """
    width_item = max(len("Item"), *(len(item) for item, _ in rows))
    width_value = max(len("Value"), *(len(value) for _, value in rows))
    rule = f"+-{'-' * width_item}-+-{'-' * width_value}-+"
    now = datetime.now(ZoneInfo("America/New_York"))        # Eastern time (EST/EDT)
    stamp = f"{now:%B} {now.day}, {now:%Y}, {now:%I:%M %p %Z}"
    print("\n" + "=" * len(rule))
    print(f"RESULT SUMMARY    -  {stamp}")
    print("=" * len(rule))
    print(rule)
    print(f"| {'Item'.ljust(width_item)} | {'Value'.ljust(width_value)} |")
    print(rule)
    for item, value in rows:
        print(f"| {item.ljust(width_item)} | {value.ljust(width_value)} |")
    print(rule)
    print("EXPERIMENT INFERENCE:")
    print(inference)
    print("-" * len(rule))
    values = dict(rows)
    emit_marker(f"BQCA_EXECUTION_TARGET={values['Execution target']}")
    emit_marker(f"BQCA_PLAN={values['Plan']}")
    emit_marker(f"BQCA_BACKEND={values['Backend']}")
    emit_marker(f"BQCA_JOB_ID={values['Job ID']}")
    emit_marker(f"BQCA_FALLBACK_REASON={values['Fallback reason']}")


def print_rsa_size_table() -> None:
    """Print the RSA-Toy size table.

    The row comes from this demo's own circuit: its qubit count and its gate
    count after decomposition to the generic rz/sx/x/cz basis.
    """
    widths = (10, 29, 29, 11, 20)
    toy_circuit = transpile(build_order_finding_circuit(BASE_A),
                            basis_gates=["rz", "sx", "x", "cz"], optimization_level=1)
    toy_gates = sum(count for name, count in toy_circuit.count_ops().items() if name != "measure")

    def rule() -> str:
        return "+" + "+".join("-" * w for w in widths) + "+"

    def line(cells: tuple[str, ...]) -> str:
        return "|" + "|".join(f" {cell}".ljust(w) for cell, w in zip(cells, widths)) + "|"

    rows = [("RSA-Toy", f"{N_COUNT + N_WORK} (this demo)", f"{toy_gates} (this demo)",
             f"{N.bit_length()} bits", str(E))]

    print(rule())
    print(line(("RSA", "Algorithm qubits required", "Algorithm gates required",
                "Key size", "Public exponent")))
    print(rule())
    for row_cells in rows:
        print(line(row_cells))
    print(rule())


def print_intro_banner() -> None:
    """Print the banner, the RSA size table, the public-key explanation and key values."""
    inner_part, inner_meaning = 6, 117                      # cell widths between the │ borders
    width = inner_part + inner_meaning + 3                  # three vertical borders -> 126
    rows = [
        ("p", "The modulus, the product of two secret primes. "
              "The demo attack to try to recover those secret primes."),
        ("q", "The public exponent, used to encrypt which shares no common factor with φ(p)"),
    ]

    def border(left: str, mid: str, right: str) -> str:
        return left + "─" * inner_part + mid + "─" * inner_meaning + right

    def row(part: str, meaning: str) -> str:
        return "│" + f" {part}".ljust(inner_part) + "│" + f"  {meaning}".ljust(inner_meaning) + "│"

    print("=" * width)
    print("Shor's algorithm: Break and recover the demo RSA-Toy private key cryptography")
    print("Educational only: Do not apply to real RSA-1024/2048/4096, et al. keys.")
    print("=" * width)
    print()
    print()
    print_rsa_size_table()
    print()
    print()
    print("Quantum RSA-Toy public key demo cryptography attack. "
          "An RSA cryptography public key is a pair of modulus & exponent (p, q).")
    print(border("┌", "┬", "┐"))
    print("│" + "Prime".ljust(inner_part) + "│" + "  Meaning".ljust(inner_meaning) + "│")
    print(border("├", "┼", "┤"))
    for index, (part, meaning) in enumerate(rows):
        print(row(part, meaning))
        if index < len(rows) - 1:
            print(border("├", "┼", "┤"))
    print(border("└", "┴", "┘"))


def main() -> int:
    os.makedirs(OUT_DIR, exist_ok=True)
    ciphertext = pow(MESSAGE, E, N)
    true_d = pow(E, -1, (P_SECRET - 1) * (Q_SECRET - 1))

    print_intro_banner()
    print("Prime factors: p x q = N.")
    print(f"Public key modulus & exponent: N={N}, e={E}")
    print(f"Toy RSA ciphertext of message {MESSAGE}: {ciphertext}")
    print(f"Base a={BASE_A}; classical order check: smallest r with a^r = 1 mod N is "
          f"{next(r for r in range(1, N) if pow(BASE_A, r, N) == 1)}")

    circuit = build_order_finding_circuit(BASE_A)
    print(f"Circuit: {circuit.num_qubits} qubits, depth {circuit.depth()}")
    circuit_png = os.path.join(OUT_DIR, "attack-circuit.png")
    try:
        circuit.draw("mpl", filename=circuit_png, fold=-1)
        print("Saved circuit PNG: **********************************")
    except Exception as exc:
        print(f"Circuit PNG skipped: {exc}")

    fallback_reason = "NONE"
    outcome = None
    attack_started = time.perf_counter()        # wall-clock: QPU submission through key recovery
    try:
        print("Attempting real QPU through Qiskit Connector first...")
        counts, target, plan_name, backend_name, job_id = run_real_qpu(circuit)
        print("Real QPU job result retrieved. Post-processing:")
        r, factors = find_factors(counts, BASE_A)
        if factors is None:
            raise RuntimeError("Real QPU counts did not yield valid factors (hardware noise)")
        outcome = (counts, target, plan_name, backend_name, job_id, r, factors)
    except Exception as exc:
        fallback_reason = str(exc).replace("\n", " ")
        emit_marker(f"BQCA_FALLBACK_REASON={fallback_reason}")
        print("Running controlled AerSimulator fallback...")
        counts, target, plan_name, backend_name, job_id = run_simulator(circuit)
        print("Simulator result retrieved. Post-processing:")
        r, factors = find_factors(counts, BASE_A)
        outcome = (counts, target, plan_name, backend_name, job_id, r, factors)

    counts, target, plan_name, backend_name, job_id, r, factors = outcome
    hist_png = os.path.join(OUT_DIR, "attack-histogram.png")
    save_histogram(counts, target, hist_png)
    print("Saved histogram PNG: ****************************************")

    rows = [
        ("Execution target", target),
        ("Plan", plan_name),
        ("Backend", backend_name),
        ("Job ID", job_id),
        ("Fallback reason", fallback_reason),
    ]

    if factors is None:
        rows.append(("Result", "FAILURE - no valid factors recovered"))
        print_summary_table(rows, INFERENCE_FAILURE)
        emit_marker("BQCA_RESULT=FAILURE")
        emit_marker("BQCA_RESULT_VALUE=No valid factors recovered")
        return 1

    p, q = factors
    phi = (p - 1) * (q - 1)
    d = pow(E, -1, phi)
    recovered = pow(ciphertext, d, N)
    attack_seconds = time.perf_counter() - attack_started
    ok = (d == true_d) and (recovered == MESSAGE)
    rows += [
        ("Period r", str(r)),
        ("Factors", f"{N} = {p} x {q}"),
        ("phi(N)", f"({p}-1)({q}-1) = {phi}"),
        ("Recovered private exponent d", f"e^-1 mod phi = {d}"),
        ("Decrypt check", f"ciphertext {ciphertext} with d -> {recovered} (original message {MESSAGE})"),
        ("Result", "SUCCESS" if ok else "FAILURE"),
        ("Time taken to break RSA", f"{format_duration(attack_seconds)} (Attack wall-clock)"),
    ]
    print_summary_table(rows, INFERENCE_SUCCESS if ok else INFERENCE_FAILURE)
    emit_marker(f"BQCA_RESULT={'SUCCESS' if ok else 'FAILURE'}")
    emit_marker(f"BQCA_RESULT_VALUE=N={N} = {p} x {q}; d={d}; decrypted={recovered}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
