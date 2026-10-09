#!/usr/bin/env python3
"""BQCA v32 connector-first execution template for generated Qiskit 2.x code."""

from __future__ import annotations

from typing import Any

from qiskit import QuantumCircuit, transpile
from qiskit_connector import QConnectorV2 as connector
from qiskit_connector import QPlanV2 as plan


def backend_name(target: Any) -> str:
    value = getattr(target, "name", None)
    return str(value() if callable(value) else value or type(target).__name__)


def qpu_is_usable(target: Any, required_qubits: int) -> tuple[bool, str]:
    if target is None:
        return False, "Qiskit Connector returned no backend"

    try:
        configuration = target.configuration()
        if bool(getattr(configuration, "simulator", False)):
            return False, "Connector returned a simulator instead of a QPU"
        qubits = int(getattr(configuration, "n_qubits", 0) or 0)
    except Exception:
        qubits = int(getattr(target, "num_qubits", 0) or 0)

    if qubits < required_qubits:
        return False, f"Backend has {qubits} qubits; circuit requires {required_qubits}"

    try:
        status = target.status()
        if not bool(getattr(status, "operational", False)):
            return False, "Backend is not operational"
    except Exception:
        pass

    return True, "usable real QPU"


def run_on_simulator(circuit: QuantumCircuit, shots: int, reason: str):
    try:
        from qiskit_aer import AerSimulator

        simulator = AerSimulator()
    except ImportError:
        from qiskit.providers.basic_provider import BasicSimulator

        simulator = BasicSimulator()

    measured = circuit.copy()
    if measured.num_clbits == 0:
        measured.measure_all()
    compiled = transpile(measured, simulator, optimization_level=1)
    result = simulator.run(compiled, shots=shots).result()
    print("EXECUTION_TARGET=SIMULATOR")
    print(f"BACKEND={backend_name(simulator)}")
    print(f"FALLBACK_REASON={reason}")
    print(f"RESULT={result.get_counts()}")
    return result


def execute_connector_first(circuit: QuantumCircuit, shots: int = 1024):
    required_qubits = circuit.num_qubits
    current = "Unknown Plan"

    try:
        current = plan()
        backend = connector()
        usable, reason = qpu_is_usable(backend, required_qubits)
        if not usable:
            return run_on_simulator(circuit, shots, reason)

        from qiskit_ibm_runtime import SamplerV2 as Sampler

        measured = circuit.copy()
        if measured.num_clbits == 0:
            measured.measure_all()
        compiled = transpile(measured, backend=backend, optimization_level=3)
        sampler = Sampler(mode=backend)
        job = sampler.run([compiled], shots=shots)
        result = job.result()
        print("EXECUTION_TARGET=REAL_QPU")
        print(f"PLAN={current}")
        print(f"BACKEND={backend_name(backend)}")
        print(f"JOB_ID={job.job_id() if hasattr(job, 'job_id') else 'unavailable'}")
        print(f"RESULT={result}")
        return result
    except Exception as exc:
        return run_on_simulator(circuit, shots, f"Real-QPU path failed: {exc}")


if __name__ == "__main__":
    qc = QuantumCircuit(2)
    qc.h(0)
    qc.cx(0, 1)
    execute_connector_first(qc)
