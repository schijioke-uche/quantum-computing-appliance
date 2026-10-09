#!/usr/bin/env python3
"""BQCA Scheduling QAOA starter for Qiskit 2.5+.

Catalog status: starter. Review the companion design card before use.
"""
from __future__ import annotations

from qiskit import transpile
from qiskit.transpiler import generate_preset_pass_manager
from qiskit_aer import AerSimulator
from qiskit_aer.primitives import EstimatorV2 as AerEstimator
from qiskit_ibm_runtime import EstimatorV2 as Estimator, Session
from qiskit_connector import QConnectorV2 as connector
from qiskit_connector import QPlanV2 as plan

current = plan()
backend = connector()

def build_workload():
    from qiskit.circuit.library import RealAmplitudes
    from qiskit.quantum_info import SparsePauliOp
    circuit = RealAmplitudes(2, reps=1)
    observable = SparsePauliOp.from_list([("ZI", 0.5), ("IZ", 0.5), ("XX", 0.25)])
    return circuit, observable


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


def run_real_qpu(circuit, observable):
    _validate_real_backend(backend, circuit.num_qubits)
    pass_manager = generate_preset_pass_manager(backend=backend, optimization_level=3)
    isa_circuit = pass_manager.run(circuit)
    isa_observable = observable.apply_layout(isa_circuit.layout)
    if _is_open_plan(current):
        estimator = Estimator(mode=backend)
        job = estimator.run([(isa_circuit, isa_observable)])
    elif _is_paid_plan(current):
        with Session(backend=backend) as session:
            estimator = Estimator(mode=session)
            job = estimator.run([(isa_circuit, isa_observable)])
    else:
        raise RuntimeError(f"unsupported plan: {current}")
    result = job.result()
    print("BQCA_EXECUTION_TARGET=REAL_QPU")
    print(f"BQCA_PLAN={current}")
    print(f"BQCA_BACKEND={_backend_name(backend)}")
    print(f"BQCA_JOB_ID={job.job_id()}")
    return result


def run_simulator(circuit, observable, reason):
    sim_backend = AerSimulator()
    transpile(circuit, backend=sim_backend, optimization_level=1)
    estimator = AerEstimator()
    result = estimator.run([(circuit, observable)]).result()
    print("BQCA_EXECUTION_TARGET=SIMULATOR")
    print(f"BQCA_PLAN={current}")
    print(f"BQCA_BACKEND={_backend_name(sim_backend)}")
    print(f"BQCA_FALLBACK_REASON={reason}")
    return result


def main():
    circuit, observable = build_workload()
    try:
        value = run_real_qpu(circuit, observable)
    except Exception as exc:
        value = run_simulator(circuit, observable, exc)
    print("BQCA_RESULT=SUCCESS")
    print(f"BQCA_RESULT_VALUE={value!r}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

# BQCA-CANONICAL-PRODUCTION-POLICY-v48:BEGIN
# Use .bob/BQCA-PRODUCTION-POLICY.md as the sole active BQCA v48 authority.
# Direct synchronous execution is the default; formal orchestration is explicit
# opt-in. Preserve account configuration, the authorized home environment,
# Qiskit 2.5+, plan-aware Runtime V2 execution, real-QPU-first fallback order,
# synchronized notebooks, scoped Hello World behavior, live dual-result capture,
# Job-ID-first real-QPU reports, and secret protection. Quantum DESIGN and CODE
# work consults bqca-quantum-kb.sh and the offline v48 catalog. v48 incorporates
# core v47 and Updates 1-6; Update 6 supersedes Update 5 URL crawling.
# BQCA-CANONICAL-PRODUCTION-POLICY-v48:END

# BQCA-BOB-SHELL-V2-DNA:BEGIN
# In a trusted Bob Shell 2.x workspace, bind this component to AGENTS.md, the
# active central BQCA policy, exported menu context, current rules/skills/tools,
# and the offline knowledgebase without changing this component's core purpose.
# BQCA-BOB-SHELL-V2-DNA:END
