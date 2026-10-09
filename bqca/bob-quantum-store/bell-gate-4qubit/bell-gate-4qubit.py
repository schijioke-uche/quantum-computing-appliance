#!/usr/bin/env python3
"""
Bell Gate 4-Qubit implementation.

Qiskit SDK requirement: 2.5 or later.
Authorized home-scoped environment: ~/qiskit-v2x-env
Home environment activation command: source ~/qiskit-v2x-env/bin/activate
Direct execution wrapper: .bob/quantum-tools/bqca-direct-execution.sh run bell-gate-4qubit.py
Formal orchestrator opt-in: .bob/quantum-tools/bqca-direct-execution.sh formal-run bell-gate-4qubit.py

Creates two Bell pairs across four qubits, attempts real-QPU execution first
through qiskit-connector, and falls back to Aer simulator only if required.
Saves durable result artifacts and PNG visualizations for reproducibility.
"""

from __future__ import annotations

import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

from qiskit import QuantumCircuit, __version__ as qiskit_version, transpile
from qiskit.visualization import plot_histogram
from qiskit_connector import QConnectorV2 as connector
from qiskit_connector import QPlanV2 as plan


WORKFLOW_NAME = "Bell Gate 4-Qubit"
DESIGN_SLUG = "bell-gate-4qubit"
SHOTS = 1024
REQUIRED_QUBITS = 4
AUTHORIZED_HOME_ENV = os.path.expanduser("~/qiskit-v2x-env")
AUTHORIZED_HOME_PYTHON = os.path.join(AUTHORIZED_HOME_ENV, "bin", "python")

PROJECT_ROOT = Path("/home/architect/IBM-SOFTWARE-LAB2/quantum-computing-agent")
OUTPUT_DIR = PROJECT_ROOT / "bob-quantum-store" / DESIGN_SLUG
RESULTS_PATH = OUTPUT_DIR / "bell-gate-4qubit_results.txt"
OUTPUT_MIRROR_PATH = OUTPUT_DIR / "output.txt"
CIRCUIT_PNG = OUTPUT_DIR / "bell-gate-4qubit_circuit.png"
HISTOGRAM_PNG = OUTPUT_DIR / "bell-gate-4qubit_histogram.png"


def ensure_output_dir() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)


def build_circuit() -> QuantumCircuit:
    qc = QuantumCircuit(4, 4, name="bell_gate_4q")
    qc.h(0)
    qc.cx(0, 1)
    qc.h(2)
    qc.cx(2, 3)
    qc.measure([0, 1, 2, 3], [0, 1, 2, 3])
    return qc


def is_open_plan(current: object) -> bool:
    return "open" in str(current).strip().lower()


def save_circuit_png(circuit: QuantumCircuit) -> None:
    figure = circuit.draw(output="mpl")
    figure.savefig(CIRCUIT_PNG, dpi=150, bbox_inches="tight")
    plt.close(figure)
    print(f"Saved visualization: {CIRCUIT_PNG}")


def save_histogram_png(counts: dict[str, int]) -> None:
    figure = plot_histogram(counts)
    figure.savefig(HISTOGRAM_PNG, dpi=150, bbox_inches="tight")
    plt.close(figure)
    print(f"Saved visualization: {HISTOGRAM_PNG}")


def summarize_counts(counts: dict[str, int]) -> list[str]:
    lines: list[str] = []
    for state, count in sorted(counts.items()):
        pct = (count / SHOTS) * 100 if SHOTS else 0.0
        lines.append(f"  {state}: {count} ({pct:.2f}%)")
    return lines


def write_results(summary: dict[str, object]) -> None:
    ensure_output_dir()
    lines = [
        f"workflow={summary['workflow']}",
        f"timestamp_utc={summary['timestamp_utc']}",
        f"qiskit_backend={summary['backend']}",
        f"execution_target={summary['execution_target']}",
        f"plan={summary['plan']}",
        f"job_id={summary['job_id']}",
        f"shots={summary['shots']}",
        f"num_qubits={summary['num_qubits']}",
        f"depth={summary['depth']}",
        f"result={summary['result']}",
        f"fallback_reason={summary['fallback_reason']}",
        f"counts_json={json.dumps(summary['counts'], sort_keys=True)}",
        f"artifacts={json.dumps(summary['artifacts'])}",
    ]
    content = "\n".join(lines) + "\n"
    RESULTS_PATH.write_text(content, encoding="utf-8")
    OUTPUT_MIRROR_PATH.write_text(content, encoding="utf-8")


def run_real_qpu(circuit: QuantumCircuit, backend, current_plan: object) -> tuple[dict[str, int], str]:
    from qiskit_ibm_runtime import SamplerV2, Session

    isa_circuit = transpile(circuit, backend=backend, optimization_level=1)

    print("BQCA_EXECUTION_TARGET=REAL_QPU")
    print(f"BQCA_PLAN={current_plan}")
    print(f"BQCA_BACKEND={backend.name}")

    if is_open_plan(current_plan):
        sampler = SamplerV2(mode=backend)
        job = sampler.run([isa_circuit], shots=SHOTS)
        job_id = job.job_id()
        print(f"BQCA_JOB_ID={job_id}")
        result = job.result()
    else:
        with Session(backend=backend) as session:
            sampler = SamplerV2(mode=session)
            job = sampler.run([isa_circuit], shots=SHOTS)
            job_id = job.job_id()
            print(f"BQCA_JOB_ID={job_id}")
            result = job.result()

    counts = result[0].data.c.get_counts()
    return counts, job_id


def run_simulator(circuit: QuantumCircuit, fallback_reason: str) -> tuple[dict[str, int], str, str]:
    from qiskit_aer import AerSimulator

    simulator = AerSimulator()
    isa_circuit = transpile(circuit, backend=simulator, optimization_level=1)
    job = simulator.run(isa_circuit, shots=SHOTS)
    result = job.result()
    counts = result.get_counts()
    print("BQCA_EXECUTION_TARGET=SIMULATOR")
    print("BQCA_PLAN=N/A")
    print(f"BQCA_BACKEND={simulator.name}")
    print("BQCA_JOB_ID=N/A")
    print(f"BQCA_FALLBACK_REASON={fallback_reason}")
    return counts, "N/A", simulator.name


def main() -> int:
    ensure_output_dir()

    print(f"BQCA_AUTHORIZED_HOME_ENV={AUTHORIZED_HOME_ENV}")
    print(f"BQCA_AUTHORIZED_HOME_PYTHON={AUTHORIZED_HOME_PYTHON}")
    print("BQCA_DIRECT_EXECUTION_WRAPPER=.bob/quantum-tools/bqca-direct-execution.sh")
    print(f"Qiskit version: {qiskit_version}")

    current = plan()
    backend = connector()
    timestamp_utc = datetime.now(timezone.utc).isoformat()

    print(f"Workflow: {WORKFLOW_NAME}")
    print(f"Timestamp (UTC): {timestamp_utc}")
    print(f"Detected plan: {current}")

    circuit = build_circuit()
    save_circuit_png(circuit)

    print(f"Circuit qubits: {circuit.num_qubits}")
    print(f"Circuit depth: {circuit.depth()}")
    print(f"Shot count: {SHOTS}")

    fallback_reason = "N/A"
    execution_target = "REAL_QPU"
    backend_name = backend.name
    job_id = "N/A"

    try:
        status = backend.status()
        if not status.operational:
            raise RuntimeError(f"Backend {backend.name} is not operational")
        if backend.num_qubits < REQUIRED_QUBITS:
            raise RuntimeError(
                f"Backend {backend.name} has {backend.num_qubits} qubits; requires {REQUIRED_QUBITS}"
            )
        counts, job_id = run_real_qpu(circuit, backend, current)
    except Exception as exc:
        fallback_reason = str(exc)
        execution_target = "SIMULATOR"
        counts, job_id, backend_name = run_simulator(circuit, fallback_reason)

    save_histogram_png(counts)

    print("Measurement counts:")
    for line in summarize_counts(counts):
        print(line)

    dominant_state = max(counts, key=counts.get)
    dominant_probability = counts[dominant_state] / SHOTS

    print("BQCA_RESULT=SUCCESS")
    print(f"BQCA_RESULT_VALUE={dominant_state}:{dominant_probability:.6f}")

    summary = {
        "workflow": WORKFLOW_NAME,
        "timestamp_utc": timestamp_utc,
        "backend": backend_name,
        "execution_target": execution_target,
        "plan": str(current) if execution_target == "REAL_QPU" else "N/A",
        "job_id": job_id,
        "shots": SHOTS,
        "num_qubits": circuit.num_qubits,
        "depth": circuit.depth(),
        "result": "SUCCESS",
        "fallback_reason": fallback_reason,
        "counts": counts,
        "artifacts": [
            str(CIRCUIT_PNG),
            str(HISTOGRAM_PNG),
            str(RESULTS_PATH),
            str(OUTPUT_MIRROR_PATH),
        ],
    }
    write_results(summary)

    print("RESULT SUMMARY")
    print(f"  Backend/simulator: {backend_name}")
    print(f"  Execution target: {execution_target}")
    print(f"  Dominant state: {dominant_state}")
    print(f"  Dominant probability: {dominant_probability:.6f}")
    print(f"  Results file: {RESULTS_PATH}")
    print(f"  Output mirror: {OUTPUT_MIRROR_PATH}")
    print(f"  Saved visualization: {CIRCUIT_PNG}")
    print(f"  Saved visualization: {HISTOGRAM_PNG}")
    return 0


if __name__ == "__main__":
    sys.exit(main())