#!/usr/bin/env python3
"""BQCA Quantum Risk Analysis starter for Qiskit 2.5+.

Catalog status: starter. Review the companion design card before use.
"""
from __future__ import annotations

from qiskit import QuantumCircuit, transpile
from qiskit_aer import AerSimulator
from qiskit_ibm_runtime import SamplerV2 as Sampler, Session
from qiskit_connector import QConnectorV2 as connector
from qiskit_connector import QPlanV2 as plan

current = plan()
backend = connector()

def build_workload():
    qc = QuantumCircuit(2, 2)
    qc.ry(0.6, 0)
    qc.cx(0, 1)
    qc.measure([0, 1], [0, 1])
    return qc


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
        raise RuntimeError(f"unsupported plan: {current}")
    result = job.result()
    print("BQCA_EXECUTION_TARGET=REAL_QPU")
    print(f"BQCA_PLAN={current}")
    print(f"BQCA_BACKEND={_backend_name(backend)}")
    print(f"BQCA_JOB_ID={job.job_id()}")
    return result


def run_simulator(circuit, reason):
    sim_backend = AerSimulator()
    compiled = transpile(circuit, backend=sim_backend, optimization_level=1)
    result = sim_backend.run(compiled, shots=1024).result()
    counts = result.get_counts(compiled)
    print("BQCA_EXECUTION_TARGET=SIMULATOR")
    print(f"BQCA_PLAN={current}")
    print(f"BQCA_BACKEND={_backend_name(sim_backend)}")
    print(f"BQCA_FALLBACK_REASON={reason}")
    return counts


def main():
    circuit = build_workload()
    try:
        value = run_real_qpu(circuit)
    except Exception as exc:
        value = run_simulator(circuit, exc)
    print("BQCA_RESULT=SUCCESS")
    print(f"BQCA_RESULT_VALUE={value!r}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
