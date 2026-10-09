#!/usr/bin/env python3
"""BQCA v47 Qiskit 2.5+ real-QPU-first execution template.

Default execution:
  .bob/quantum-tools/bqca-direct-execution.sh run <this-file.py>

Formal compliance, deployment, or audit only:
  .bob/quantum-tools/bqca-direct-execution.sh formal-run <this-file.py>

The wrapper uses $HOME/qiskit-v2x-env/bin/python with unbuffered output and
creates <source-stem>-result-output.txt plus output.txt beside this source.
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
BQCA_DIRECT_EXECUTION = ".bob/quantum-tools/bqca-direct-execution.sh"

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
        if observable is None:
            primitive = SamplerV2(mode=backend)
            job = primitive.run([isa_circuit], shots=shots)
        else:
            primitive = EstimatorV2(mode=backend)
            job = primitive.run([(isa_circuit, observable)])
        result = job.result()
    else:
        with Session(backend=backend) as session:
            if observable is None:
                primitive = SamplerV2(mode=session)
                job = primitive.run([isa_circuit], shots=shots)
            else:
                primitive = EstimatorV2(mode=session)
                job = primitive.run([(isa_circuit, observable)])
            result = job.result()

    print("BQCA_EXECUTION_TARGET=REAL_QPU")
    print(f"BQCA_PLAN={current}")
    print(f"BQCA_BACKEND={backend_name(backend)}")
    print(f"BQCA_JOB_ID={job.job_id()}")
    return result


def execute_simulator(circuit: QuantumCircuit, shots: int = 1024):
    sim_backend = AerSimulator()
    sim_circuit = transpile(circuit, backend=sim_backend, optimization_level=3)
    sim_job = sim_backend.run(sim_circuit, shots=shots)
    result = sim_job.result()
    print("BQCA_EXECUTION_TARGET=SIMULATOR")
    print(f"BQCA_PLAN={current}")
    print(f"BQCA_BACKEND={backend_name(sim_backend)}")
    print("BQCA_JOB_ID=NOT_APPLICABLE")
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
    try:
        final_result = execute(build_circuit())
        print(f"BQCA_RESULT_VALUE={final_result}")
        print("BQCA_RESULT=SUCCESS")
    except Exception as exc:
        print(f"BQCA_FAILURE_REASON={exc}")
        print("BQCA_RESULT=FAILURE")
        raise

# BQCA-CANONICAL-PRODUCTION-POLICY-v47:BEGIN
# BQCA v47 Update 4: follow .bob/BQCA-PRODUCTION-POLICY.md. Direct execution
# through bqca-direct-execution.sh is the default and must use the authorized
# home Python with unbuffered live stdout/stderr plus dual result capture.
# Code must preserve real-QPU-first plan-aware execution, controlled simulator
# fallback, and the required BQCA markers, including BQCA_RESULT=SUCCESS or
# BQCA_RESULT=FAILURE. The orchestrator is explicit opt-in only for formal
# compliance, deployment, or audit evidence. Direct-mode policy gaps are
# warnings that preserve the workload exit status; credential leakage blocks.
# This block supersedes conflicting local execution guidance.
# BQCA-CANONICAL-PRODUCTION-POLICY-v47:END

# BQCA-QUANTUM-KNOWLEDGEBASE-v47-update-5:BEGIN
# For every quantum DESIGN or CODE intent, consult the canonical index at
# .bob/quantum-tools/knowlegebase/bqca_quantum_kb_index.txt through
# .bob/quantum-tools/bqca-quantum-kb.sh. Access relevant seed URLs and drill
# into at least one relevant sublink from every seed accessed. Preserve a
# <artifact-stem>-kb-research.md trace beside the governed artifact. The
# knowledgebase supplements IBM Bob intelligence and never overrides the active
# central policy. Do not claim compliance when the strict research gate fails.
# This block supersedes conflicting local quantum-knowledge-source guidance.
# BQCA-QUANTUM-KNOWLEDGEBASE-v47-update-5:END
