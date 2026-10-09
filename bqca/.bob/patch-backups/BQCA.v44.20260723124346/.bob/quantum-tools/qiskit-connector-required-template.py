#!/usr/bin/env python3
"""BQCA v44 Qiskit 2.5+ plan-aware execution template.

Execute only with:
  .bob/quantum-tools/bqca-policy-orchestrator.sh execute <this-file.py>

Open Plan uses job mode without Session. Select SamplerV2 for sample/count/
distribution workloads or EstimatorV2 for expectation-value/observable/energy
workloads. The v44 gate writes <this-file>-result-output.txt beside the source.
"""
from __future__ import annotations

from typing import Any

from qiskit import QuantumCircuit, transpile
from qiskit.quantum_info import SparsePauliOp
from qiskit_aer import AerSimulator
from qiskit_ibm_runtime import EstimatorV2, SamplerV2, Session
from qiskit_connector import QConnectorV2 as connector
from qiskit_connector import QPlanV2 as plan

BQCA_REQUIRED_ENV = "$HOME/qiskit-v2x-env"
BQCA_MIN_QISKIT_VERSION = "Qiskit >= 2.5"
BQCA_RESULT_OUTPUT_POLICY = "qiskit-result-output through the v44 orchestrator"

current = plan()
backend = connector()


def normalized_plan(value: object) -> str:
    return str(value).strip().lower().replace("_", " ").replace("-", " ")


def is_open_plan(value: object) -> bool:
    return "open" in normalized_plan(value)


def backend_name(candidate: Any) -> str:
    value = getattr(candidate, "name", None)
    return str(value() if callable(value) else value or candidate.__class__.__name__)


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


def execute_real_qpu(circuit: QuantumCircuit, observable: SparsePauliOp | None = None, shots: int = 1024):
    required_qubits = circuit.num_qubits
    if backend_is_simulator(backend):
        raise RuntimeError("Qiskit Connector returned a simulator instead of a real QPU")
    if not backend_is_operational(backend):
        raise RuntimeError("The selected real QPU is not operational")
    if backend_qubits(backend) < required_qubits:
        raise RuntimeError("The selected real QPU has insufficient qubit capacity")

    isa_circuit = transpile(circuit, backend=backend, optimization_level=3)
    if is_open_plan(current):
        # Open Plan: job mode only; Session is prohibited.
        if observable is None:
            primitive = SamplerV2(mode=backend)  # samples, shots, counts, distributions
            job = primitive.run([isa_circuit], shots=shots)
        else:
            primitive = EstimatorV2(mode=backend)  # expectation values, observables, energies
            job = primitive.run([(isa_circuit, observable)])
        result = job.result()
    else:
        # Paid Plan: Session is permitted and selected by workload semantics.
        with Session(backend=backend) as session:
            if observable is None:
                primitive = SamplerV2(mode=session)
                job = primitive.run([isa_circuit], shots=shots)
            else:
                primitive = EstimatorV2(mode=session)
                job = primitive.run([(isa_circuit, observable)])
            result = job.result()

    print("BQCA_EXECUTION_TARGET=REAL_QPU")
    print(f"BQCA_JOB_ID={job.job_id()}")
    print(f"BQCA_PLAN={current}")
    print(f"BQCA_BACKEND={backend_name(backend)}")
    return result


def execute_simulator(circuit: QuantumCircuit, shots: int = 1024):
    sim_backend = AerSimulator()
    sim_circuit = transpile(circuit, backend=sim_backend, optimization_level=3)
    sim_job = sim_backend.run(sim_circuit, shots=shots)
    result = sim_job.result()
    print("BQCA_EXECUTION_TARGET=SIMULATOR")
    print(f"BQCA_PLAN={current}")
    print(f"BQCA_BACKEND={backend_name(sim_backend)}")
    return result


def execute(circuit: QuantumCircuit, observable: SparsePauliOp | None = None, shots: int = 1024):
    try:
        return execute_real_qpu(circuit, observable=observable, shots=shots)
    except Exception as exc:
        print(f"BQCA_FALLBACK_REASON={exc}")
        return execute_simulator(circuit, shots=shots)


def build_circuit() -> QuantumCircuit:
    circuit = QuantumCircuit(2)
    circuit.h(0)
    circuit.cx(0, 1)
    circuit.measure_all()
    return circuit


if __name__ == "__main__":
    final_result = execute(build_circuit())
    print(f"BQCA_RESULT={final_result}")
# BQCA-CANONICAL-PRODUCTION-POLICY-v44:BEGIN
# The sole active BQCA policy is .bob/BQCA-PRODUCTION-POLICY.md (v44).
# Route all public design, code, execution, result, and completion paths through
# bqca-policy-orchestrator.sh. Open Plan uses SamplerV2 or EstimatorV2 job mode
# according to workload semantics and must never use Session.
# BQCA-CANONICAL-PRODUCTION-POLICY-v44:END
