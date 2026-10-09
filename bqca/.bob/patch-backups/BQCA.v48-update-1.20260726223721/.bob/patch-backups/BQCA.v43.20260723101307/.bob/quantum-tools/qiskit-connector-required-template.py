#!/usr/bin/env python3
"""BQCA v42 Qiskit 2.5+ plan-aware execution template.

Execute only with:
  .bob/quantum-tools/qiskit-v2x-environment.sh run <this-file.py>

The v42 runtime writes <this-file>-result-output.txt beside this source and
captures complete stdout/stderr. This code emits canonical execution markers.
"""
from __future__ import annotations

from typing import Any

from qiskit import QuantumCircuit, transpile
from qiskit_aer import AerSimulator
from qiskit_ibm_runtime import EstimatorV2, SamplerV2, Session
from qiskit_connector import QConnectorV2 as connector
from qiskit_connector import QPlanV2 as plan

BQCA_REQUIRED_ENV = "$HOME/qiskit-v2x-env"
BQCA_MIN_QISKIT_VERSION = "Qiskit >= 2.5"
BQCA_RESULT_OUTPUT_POLICY = "<code-name>-result-output.txt in the source directory"

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
        result = job.result()
    else:
        # Paid Plan: Session strategy.
        with Session(backend=backend) as session:
            sampler = SamplerV2(mode=session)
            job = sampler.run([isa_circuit], shots=shots)
            result = job.result()

    print("BQCA_EXECUTION_TARGET=REAL_QPU")
    print(f"BQCA_JOB_ID={job.job_id()}")
    print(f"BQCA_PLAN={current}")
    print(f"BQCA_BACKEND={backend_name(backend)}")
    return result


def execute_simulator(circuit: QuantumCircuit, shots: int = 1024):
    sim_backend = AerSimulator()
    sim_circuit = transpile(circuit, backend=sim_backend, optimization_level=3)
    # backend.run()-style execution is permitted because sim_backend is local.
    sim_job = sim_backend.run(sim_circuit, shots=shots)
    result = sim_job.result()
    print("BQCA_EXECUTION_TARGET=SIMULATOR")
    print(f"BQCA_PLAN={current}")
    print(f"BQCA_BACKEND={backend_name(sim_backend)}")
    return result


def execute(circuit: QuantumCircuit, shots: int = 1024):
    try:
        return execute_real_qpu(circuit, shots=shots)
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

# BQCA-GENERIC-WORKLOAD-TEMPLATE-v41:BEGIN
# V41 generic workload template: include only validation that belongs to the
# requested quantum workload. Do not add unrelated smoke-test scaffolding,
# examples, or test-folder dependencies.
# BQCA-GENERIC-WORKLOAD-TEMPLATE-v41:END

# BQCA-RESULT-OUTPUT-v42:POLICY-BEGIN
# V42: execute quantum/Qiskit sources through qiskit-v2x-environment.sh run or
# run-notebook. The runtime creates <source-stem>-result-output.txt beside the
# source, captures complete Qiskit Connector/stdout/stderr output, includes
# date/time, places a real-QPU JOB ID on the first line, and appends a final
# RESULT SUMMARY with execution success. Code emits canonical BQCA markers.
# BQCA-RESULT-OUTPUT-v42:POLICY-END
