#!/usr/bin/env python3
"""
Qiskit Hello World - Basic Quantum Circuit Demo
Creates a simple Bell state and measures it using Qiskit 2.5+ primitives.

Requirements:
- Qiskit SDK >= 2.5.0
- qiskit-connector >= 2.4.6
- Python >= 3.9

BQCA v48 Policy Compliance:
- Uses $HOME/qiskit-v2x-env Python environment (not project-local)
- Configuration gate must pass before Qiskit Connector initialization
- Real-QPU-first with controlled simulator fallback
- All required execution markers emitted
- Open Plan uses SamplerV2(mode=backend) without Session
- Paid plans use Session(backend=backend) with SamplerV2(mode=session)
- Direct execution is default for development/testing/debugging
- Formal orchestrator is explicit opt-in only

Execution:
Default: .bob/quantum-tools/bqca-direct-execution.sh run hello-world.py
Formal: .bob/quantum-tools/bqca-direct-execution.sh formal-run hello-world.py
"""

import sys
import os
from datetime import datetime, timezone
from qiskit import QuantumCircuit, transpile
from qiskit_connector import QConnectorV2 as connector
from qiskit_connector import QPlanV2 as plan


def build_bell_circuit() -> QuantumCircuit:
    """Create a 2-qubit Bell-state circuit with measurements."""
    qc = QuantumCircuit(2, 2)
    qc.h(0)
    qc.cx(0, 1)
    qc.measure([0, 1], [0, 1])
    return qc


def print_counts(counts: dict[str, int], shots: int) -> None:
    """Print measured counts and percentages."""
    print("\nMeasurement Results:")
    for state, count in sorted(counts.items()):
        percentage = (count / shots) * 100
        print(f"  |{state}⟩: {count:4d} ({percentage:5.1f}%)")


def is_open_plan(current_plan: object) -> bool:
    """Return True when the detected plan is IBM Open Plan."""
    return "open" in str(current_plan).strip().lower()


def run_real_qpu(qc: QuantumCircuit, backend, current_plan: object, shots: int) -> dict[str, int]:
    """Execute on a real QPU using the plan-appropriate runtime mode."""
    from qiskit_ibm_runtime import SamplerV2, Session

    isa_circuit = transpile(qc, backend=backend, optimization_level=1)

    if is_open_plan(current_plan):
        print("Real QPU strategy: Open Plan SamplerV2(mode=backend) without Session")
        print(f"BQCA_EXECUTION_TARGET=REAL_QPU")
        print(f"BQCA_PLAN={current_plan}")
        print(f"BQCA_BACKEND={backend.name}")
        
        sampler = SamplerV2(mode=backend)
        job = sampler.run([isa_circuit], shots=shots)
        job_id = job.job_id()
        
        # BQCA v48: Job ID must be on first line for real QPU
        print(f"BQCA_JOB_ID={job_id}")
        print(f"Job ID: {job_id}")
        
        result = job.result()
        pub_result = result[0]
        counts = pub_result.data.c.get_counts()
        print(f"BQCA_RESULT=SUCCESS")
        return counts
    else:
        print(f"Real QPU strategy: Paid Plan ({current_plan}) Session with SamplerV2(mode=session)")
        print(f"BQCA_EXECUTION_TARGET=REAL_QPU")
        print(f"BQCA_PLAN={current_plan}")
        print(f"BQCA_BACKEND={backend.name}")
        
        with Session(backend=backend) as session:
            sampler = SamplerV2(mode=session)
            job = sampler.run([isa_circuit], shots=shots)
            job_id = job.job_id()
            
            # BQCA v48: Job ID must be on first line for real QPU
            print(f"BQCA_JOB_ID={job_id}")
            print(f"Job ID: {job_id}")
            
            result = job.result()
            pub_result = result[0]
            counts = pub_result.data.c.get_counts()
            print(f"BQCA_RESULT=SUCCESS")
            return counts


def run_simulator(qc: QuantumCircuit, shots: int, fallback_reason: str) -> dict[str, int]:
    """Execute on AerSimulator using controlled fallback with transpile."""
    from qiskit_aer import AerSimulator

    simulator = AerSimulator()
    print(f"Using simulator: {simulator.name}")
    print(f"BQCA_EXECUTION_TARGET=SIMULATOR")
    print(f"BQCA_PLAN=N/A")
    print(f"BQCA_BACKEND={simulator.name}")
    print(f"BQCA_JOB_ID=N/A")
    print(f"BQCA_FALLBACK_REASON={fallback_reason}")
    print("Simulator strategy: transpile + AerSimulator.run()")

    sim_circuit = transpile(qc, backend=simulator, optimization_level=1)
    job = simulator.run(sim_circuit, shots=shots)
    result = job.result()
    counts = result.get_counts()
    print(f"BQCA_RESULT=SUCCESS")
    return counts


def main() -> int:
    """Main execution function with BQCA v48 policy compliance.
    
    Execute with direct execution (default):
        .bob/quantum-tools/bqca-direct-execution.sh run hello-world.py
    
    Execute with formal orchestrator (explicit opt-in):
        .bob/quantum-tools/bqca-direct-execution.sh formal-run hello-world.py
    """
    start_time = datetime.now(timezone.utc)
    
    # BQCA v48: Verify execution environment
    venv_python = os.path.expanduser("~/qiskit-v2x-env/bin/python")
    if not os.path.exists(venv_python):
        print(f"ERROR: Required environment not found: {venv_python}")
        print("Please create environment: .bob/quantum-tools/qiskit-v2x-environment.sh")
        return 1
    
    shots = 1024
    required_qubits = 2

    print("=" * 80)
    print("Qiskit Hello World - Bell State Demo")
    print("BQCA v48 Direct Execution")
    print("=" * 80)
    print(f"Execution started: {start_time.isoformat()}")
    print()

    # BQCA v48: Real-QPU-first with controlled simulator fallback
    fallback_reason = None
    try:
        print("Initializing Qiskit Connector...")
        current = plan()
        print(f"Detected Plan: {current}")

        backend = connector()
        print(f"Selected Backend: {backend.name}")

        status = backend.status()
        num_qubits = backend.num_qubits

        print(f"Backend Status: {status.status_msg}")
        print(f"Backend Operational: {status.operational}")
        print(f"Available Qubits: {num_qubits}")
        print(f"Required Qubits: {required_qubits}")
        print()

        if not status.operational:
            raise RuntimeError(f"Backend {backend.name} is not operational")

        if num_qubits < required_qubits:
            raise RuntimeError(
                f"Backend has {num_qubits} qubits, need {required_qubits}"
            )

        qc = build_bell_circuit()
        print(f"Circuit created with {qc.num_qubits} qubits")
        print("\nCircuit diagram:")
        print(qc.draw(output="text"))
        print()

        print(f"Executing on {backend.name}...")
        counts = run_real_qpu(qc, backend, current, shots)

        print_counts(counts, shots)
        
        # Compute duration
        end_time = datetime.now(timezone.utc)
        duration = (end_time - start_time).total_seconds()
        
        print()
        print("=" * 80)
        print("RESULT SUMMARY")
        print("=" * 80)
        print(f"Execution date/time: {start_time.isoformat()}")
        print(f"Execution duration: {duration:.2f} seconds")
        print("✓ Hello World execution completed successfully on real QPU!")
        print("=" * 80)
        return 0

    except Exception as e:
        fallback_reason = str(e)
        print(f"\n✗ Real QPU execution failed: {e}")
        print("\nFalling back to simulator...")
        print()

        try:
            qc = build_bell_circuit()
            print("Circuit diagram:")
            print(qc.draw(output="text"))
            print()

            print("Executing on simulator...")
            counts = run_simulator(qc, shots, fallback_reason)

            print_counts(counts, shots)
            
            # Compute duration
            end_time = datetime.now(timezone.utc)
            duration = (end_time - start_time).total_seconds()
            
            print()
            print("=" * 80)
            print("RESULT SUMMARY")
            print("=" * 80)
            print(f"Execution date/time: {start_time.isoformat()}")
            print(f"Execution duration: {duration:.2f} seconds")
            print("✓ Hello World execution completed on simulator!")
            print("=" * 80)
            return 0

        except Exception as sim_error:
            print(f"\n✗ Simulator execution also failed: {sim_error}")
            print(f"BQCA_RESULT=FAILURE")
            
            # Compute duration
            end_time = datetime.now(timezone.utc)
            duration = (end_time - start_time).total_seconds()
            
            print()
            print("=" * 80)
            print("RESULT SUMMARY")
            print("=" * 80)
            print(f"Execution date/time: {start_time.isoformat()}")
            print(f"Execution duration: {duration:.2f} seconds")
            print("✗ Execution failed")
            print("=" * 80)
            return 1


if __name__ == "__main__":
    sys.exit(main())