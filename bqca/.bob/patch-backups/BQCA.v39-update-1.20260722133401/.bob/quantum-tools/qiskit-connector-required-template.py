#!/usr/bin/env python3
"""BQCA v39 Qiskit 2.5+ plan-aware execution template.

Execute only with:
  .bob/quantum-tools/qiskit-v2x-environment.sh run <this-file.py>
"""
from __future__ import annotations

from typing import Any

from qiskit import QuantumCircuit, transpile
from qiskit_aer import AerSimulator
from qiskit_ibm_runtime import EstimatorV2, SamplerV2, Session
from qiskit_connector import QConnectorV2 as connector
from qiskit_connector import QPlanV2 as plan

BQCA_REQUIRED_ENV = "qiskit-v2x-env"
BQCA_MIN_QISKIT_VERSION = "Qiskit >= 2.5"

current = plan()
backend = connector()


def normalized_plan(value: object) -> str:
    return str(value).strip().lower().replace("_", " ").replace("-", " ")


def is_open_plan(value: object) -> bool:
    return "open" in normalized_plan(value)


def backend_is_simulator(candidate: Any) -> bool:
    configuration = getattr(candidate, "configuration", None)
    if callable(configuration):
        try:
            return bool(getattr(configuration(), "simulator", False))
        except Exception:
            pass
    return bool(getattr(candidate, "simulator", False))


def backend_is_operational(candidate: Any) -> bool:
    status = getattr(candidate, "status", None)
    if callable(status):
        try:
            return bool(getattr(status(), "operational", True))
        except Exception:
            return True
    return True


def backend_qubits(candidate: Any) -> int:
    direct = getattr(candidate, "num_qubits", None)
    if isinstance(direct, int):
        return direct
    configuration = getattr(candidate, "configuration", None)
    if callable(configuration):
        try:
            return int(getattr(configuration(), "n_qubits", 0))
        except Exception:
            return 0
    return 0


def execute_real_qpu(circuit: QuantumCircuit, shots: int = 1024):
    required_qubits = circuit.num_qubits
    if backend_is_simulator(backend):
        raise RuntimeError("Qiskit Connector returned a simulator instead of a real QPU")
    if not backend_is_operational(backend):
        raise RuntimeError("The selected real QPU is not operational")
    if backend_qubits(backend) < required_qubits:
        raise RuntimeError("The selected real QPU has insufficient qubit capacity")

    isa_circuit = transpile(circuit, backend=backend, optimization_level=3)

    if is_open_plan(current):
        # Open Plan: job mode only. Session is prohibited.
        sampler = SamplerV2(mode=backend)
        job = sampler.run([isa_circuit], shots=shots)
        return job.result()
    else:
        # Paid Plan: Session strategy. EstimatorV2(mode=session) may be used for
        # expectation-value workloads; this sampling template uses SamplerV2.
        with Session(backend=backend) as session:
            sampler = SamplerV2(mode=session)
            job = sampler.run([isa_circuit], shots=shots)
            return job.result()


def execute_simulator(circuit: QuantumCircuit, shots: int = 1024):
    sim_backend = AerSimulator()
    sim_circuit = transpile(circuit, backend=sim_backend, optimization_level=3)
    # backend.run()-style execution is permitted because sim_backend is local.
    sim_job = sim_backend.run(sim_circuit, shots=shots)
    return sim_job.result()


def execute(circuit: QuantumCircuit, shots: int = 1024):
    try:
        result = execute_real_qpu(circuit, shots=shots)
        print("EXECUTION_TARGET=REAL_QPU")
        print(f"PLAN={current}")
        return result
    except Exception as exc:
        print("EXECUTION_TARGET=SIMULATOR")
        print(f"FALLBACK_REASON={exc}")
        return execute_simulator(circuit, shots=shots)


def build_circuit() -> QuantumCircuit:
    circuit = QuantumCircuit(2)
    circuit.h(0)
    circuit.cx(0, 1)
    circuit.measure_all()
    return circuit


if __name__ == "__main__":
    print(execute(build_circuit()))

# BQCA-QISKIT-EXECUTION-v39:POLICY-BEGIN
# V39 POLICY AWARENESS: Quantum/Qiskit create/implement/write/generate/build/
# develop/produce/scaffold/construct/code/program/modify/update/repair/fix/
# refactor/complete/execute requests are CODE intent. Use qiskit-v2x-env and
# Qiskit 2.5+. Open Plan uses SamplerV2(mode=backend) without Session; paid
# plans use Session with SamplerV2/EstimatorV2; simulator fallback uses
# transpile + AerSimulator. backend.run() is local-simulator-only. Hello World
# requests execute a matching artifact from project-root /test when present.
# BQCA-QISKIT-EXECUTION-v39:POLICY-END
