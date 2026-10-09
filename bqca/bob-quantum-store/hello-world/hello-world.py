#!/usr/bin/env python3
"""BQCA Hello World — Quantum Bell State (Qiskit 2.5+)

Prepares a 2-qubit Bell state, samples it, and reports results.
Follows the BQCA v48 real-QPU-first / simulator-fallback execution contract.

Run:
    .bob/quantum-tools/bqca-direct-execution.sh run bob-quantum-store/hello-world/hello-world.py
or:
    source ~/qiskit-v2x-env/bin/activate && python3 bob-quantum-store/hello-world/hello-world.py
"""
from __future__ import annotations

import importlib.metadata
import pathlib
from datetime import datetime, timezone
from typing import Any

# Enforce Qiskit 2.5 or later at import time
_qiskit_version = importlib.metadata.version("qiskit")
_major, _minor = (int(x) for x in _qiskit_version.split(".")[:2])
if (_major, _minor) < (2, 5):
    raise RuntimeError(
        f"BQCA requires Qiskit >= 2.5.0 but found {_qiskit_version}. "
        "Activate ~/qiskit-v2x-env and retry."
    )

from qiskit import QuantumCircuit, transpile
from qiskit.visualization import circuit_drawer
from qiskit_aer import AerSimulator
from qiskit_ibm_runtime import SamplerV2, Session
from qiskit_connector import QConnectorV2 as connector
from qiskit_connector import QPlanV2 as plan

# ── BQCA Policy constants ────────────────────────────────────────────────────
BQCA_POLICY        = "v48"
BQCA_MIN_QISKIT    = "2.5.0"
SHOTS              = 1024
OUTPUT_DIR         = pathlib.Path("bob-quantum-store/hello-world")
RESULT_FILE        = OUTPUT_DIR / "hello-world-result-output.txt"
CIRCUIT_PNG        = OUTPUT_DIR / "hello-world-circuit.png"

# ── Qiskit Connector initialisation ─────────────────────────────────────────
current = plan()
backend = connector()


# ── Helper utilities ─────────────────────────────────────────────────────────
def _backend_name(value: Any) -> str:
    attr = getattr(value, "name", None)
    return str(attr() if callable(attr) else attr or value.__class__.__name__)


def _backend_is_simulator(value: Any) -> bool:
    cfg = getattr(value, "configuration", None)
    if callable(cfg):
        try:
            return bool(getattr(cfg(), "simulator", False))
        except Exception:
            pass
    return bool(getattr(value, "simulator", False))


def _backend_is_operational(value: Any) -> bool:
    status = getattr(value, "status", None)
    if callable(status):
        try:
            return bool(getattr(status(), "operational", True))
        except Exception:
            return True
    return True


def _backend_qubits(value: Any) -> int:
    direct = getattr(value, "num_qubits", None)
    if isinstance(direct, int):
        return direct
    cfg = getattr(value, "configuration", None)
    if callable(cfg):
        try:
            return int(getattr(cfg(), "n_qubits", 0))
        except Exception:
            return 0
    return 0


def _is_open_plan(value: Any) -> bool:
    return "open" in str(value).strip().lower()


# ── Circuit builder ───────────────────────────────────────────────────────────
def build_hello_world_circuit() -> QuantumCircuit:
    """Two-qubit Bell state — the canonical quantum Hello World."""
    qc = QuantumCircuit(2, 2)
    qc.h(0)       # superposition
    qc.cx(0, 1)   # entanglement
    qc.measure([0, 1], [0, 1])
    return qc


# ── Real-QPU execution path ──────────────────────────────────────────────────
def run_real_qpu(circuit: QuantumCircuit) -> dict:
    if _backend_is_simulator(backend):
        raise RuntimeError("Qiskit Connector returned a simulator — not a real QPU")
    if not _backend_is_operational(backend):
        raise RuntimeError(f"QPU {_backend_name(backend)} is not operational")
    avail = _backend_qubits(backend)
    if avail and avail < circuit.num_qubits:
        raise RuntimeError(f"QPU has {avail} qubits; circuit requires {circuit.num_qubits}")

    isa = transpile(circuit, backend=backend, optimization_level=3)

    if _is_open_plan(current):
        sampler = SamplerV2(mode=backend)
        job = sampler.run([isa], shots=SHOTS)
    else:
        with Session(backend=backend) as session:
            sampler = SamplerV2(mode=session)
            job = sampler.run([isa], shots=SHOTS)

    result = job.result()
    # SamplerV2 DataBin key matches the classical register name in the circuit.
    # Extract robustly by iterating available BitArray fields.
    pub_result = result[0]
    data_bin = pub_result.data
    bit_array = None
    # Iterate DataBin fields robustly across Qiskit Runtime versions
    field_names = (
        list(data_bin.__dataclass_fields__)
        if hasattr(data_bin, "__dataclass_fields__")
        else [k for k in vars(data_bin) if not k.startswith("_")]
    )
    for field_name in field_names:
        candidate = getattr(data_bin, field_name, None)
        if candidate is not None and hasattr(candidate, "get_counts"):
            bit_array = candidate
            break
    if bit_array is None:
        raise RuntimeError("SamplerV2 DataBin contained no usable classical register field")
    counts = bit_array.get_counts()

    print("BQCA_EXECUTION_TARGET=REAL_QPU")
    print(f"BQCA_PLAN={current}")
    print(f"BQCA_BACKEND={_backend_name(backend)}")
    print(f"BQCA_JOB_ID={job.job_id()}")
    return counts


# ── Simulator fallback path ──────────────────────────────────────────────────
def run_simulator(circuit: QuantumCircuit, reason: Exception) -> dict:
    sim = AerSimulator()
    isa = transpile(circuit, backend=sim, optimization_level=1)
    counts = sim.run(isa, shots=SHOTS).result().get_counts()

    print("BQCA_EXECUTION_TARGET=SIMULATOR")
    print(f"BQCA_PLAN={current}")
    print(f"BQCA_BACKEND={_backend_name(sim)}")
    print(f"BQCA_FALLBACK_REASON={reason}")
    return counts


# ── Result reporter ──────────────────────────────────────────────────────────
def report(counts: dict, circuit: QuantumCircuit) -> None:
    total = sum(counts.values())
    now   = datetime.now(timezone.utc).isoformat()

    print("\n╔══════════════════════════════════════════════════╗")
    print("║   🔬  BQCA Hello World — Bell State Result       ║")
    print("╚══════════════════════════════════════════════════╝")
    print(f"  Timestamp  : {now}")
    print(f"  Shots      : {SHOTS}")
    print(f"  Qubits     : {circuit.num_qubits}")
    print("\n  Measurement counts:")
    for state, count in sorted(counts.items(), key=lambda x: -x[1]):
        bar = "█" * int(30 * count / total)
        pct = 100 * count / total
        print(f"    |{state}⟩  {bar:<30}  {count:>5}  ({pct:5.1f}%)")

    print(f"\n  Bell state fidelity: |00⟩ + |11⟩ sum = "
          f"{counts.get('00', 0) + counts.get('11', 0)} / {total}")

    # Save circuit visualization
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    try:
        circuit_drawer(circuit, output="mpl", filename=str(CIRCUIT_PNG))
        print(f"\n  Circuit PNG : {CIRCUIT_PNG.resolve()}")
    except Exception as exc:
        print(f"  Circuit PNG : skipped ({exc})")

    # Save result output file
    lines = [
        f"BQCA_POLICY={BQCA_POLICY}",
        f"TIMESTAMP={now}",
        f"SHOTS={SHOTS}",
        f"COUNTS={counts}",
        f"CIRCUIT_PNG={CIRCUIT_PNG.resolve()}",
    ]
    RESULT_FILE.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"  Results     : {RESULT_FILE.resolve()}")
    print("\nBQCA_RESULT=SUCCESS")


# ── Entry point ──────────────────────────────────────────────────────────────
def main() -> int:
    print("┌─────────────────────────────────────────────────────┐")
    print("│  IBM BQCA — Hello World (Bell State) · Qiskit 2.5+  │")
    print("└─────────────────────────────────────────────────────┘")
    print(f"  Policy   : BQCA {BQCA_POLICY}")
    print(f"  Plan     : {current}")
    print(f"  Backend  : {_backend_name(backend)}")
    print()

    circuit = build_hello_world_circuit()

    try:
        counts = run_real_qpu(circuit)
    except Exception as exc:
        counts = run_simulator(circuit, exc)

    report(counts, circuit)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

# BQCA-ACTIVE-CENTRAL-POLICY:BEGIN
# Active policy v48 · Resolved via bqca-active-policy-listener.sh
# BQCA-ACTIVE-CENTRAL-POLICY:END
