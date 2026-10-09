#!/usr/bin/env python3
"""BQCA v34 required real-QPU-first scaffold. Adapt the circuit/workload only."""
from __future__ import annotations

from qiskit import QuantumCircuit, transpile
from qiskit_connector import QConnectorV2 as connector
from qiskit_connector import QPlanV2 as plan

current = plan()
backend = connector()


def backend_name(value) -> str:
    name = getattr(value, "name", None)
    return name() if callable(name) else str(name or value)


def usable_real_qpu(value, required_qubits: int) -> bool:
    if value is None:
        return False
    configuration = value.configuration() if hasattr(value, "configuration") else None
    is_simulator = bool(getattr(configuration, "simulator", False))
    qubit_count = getattr(value, "num_qubits", None) or getattr(configuration, "n_qubits", 0)
    status = value.status() if hasattr(value, "status") else None
    operational = bool(getattr(status, "operational", True))
    return not is_simulator and operational and int(qubit_count or 0) >= required_qubits


def run_workload(circuit: QuantumCircuit, shots: int = 1024):
    fallback_reason = ""
    try:
        if not usable_real_qpu(backend, circuit.num_qubits):
            raise RuntimeError("No operational account QPU has sufficient qubit capacity")

        from qiskit_ibm_runtime import SamplerV2 as Sampler
        compiled = transpile(circuit, backend=backend, optimization_level=3)
        sampler = Sampler(mode=backend)
        job = sampler.run([compiled], shots=shots)
        result = job.result()
        print("EXECUTION_TARGET=REAL_QPU")
        print(f"ACCOUNT_PLAN={current}")
        print(f"BACKEND={backend_name(backend)}")
        return result
    except Exception as real_qpu_error:
        fallback_reason = f"{type(real_qpu_error).__name__}: {real_qpu_error}"
        try:
            from qiskit_aer import AerSimulator
            simulator = AerSimulator()
        except Exception:
            from qiskit.providers.basic_provider import BasicSimulator
            simulator = BasicSimulator()

        compiled = transpile(circuit, backend=simulator, optimization_level=3)
        result = simulator.run(compiled, shots=shots).result()
        print("EXECUTION_TARGET=SIMULATOR")
        print(f"ACCOUNT_PLAN={current}")
        print(f"BACKEND={backend_name(simulator)}")
        print(f"FALLBACK_REASON={fallback_reason}")
        return result


if __name__ == "__main__":
    qc = QuantumCircuit(2, 2)
    qc.h(0)
    qc.cx(0, 1)
    qc.measure([0, 1], [0, 1])
    print(run_workload(qc))
