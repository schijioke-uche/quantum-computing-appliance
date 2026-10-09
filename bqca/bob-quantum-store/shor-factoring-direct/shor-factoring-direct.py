#!/usr/bin/env python3
"""
Shor's Factoring Algorithm - Direct Execution Optimized
Factor N=15 using quantum period finding with QFT
Optimized for BQCA v48 direct execution with live terminal streaming

BQCA v48 Execution Contract:
- Use $HOME/qiskit-v2x-env/bin/python (not project-local environment)
- Execute via .bob/quantum-tools/bqca-direct-execution.sh run <file.py>
- Direct execution is the default for development, testing, debugging
- Formal orchestrator is explicit opt-in only for compliance/audit
- Configuration gate must pass before Qiskit Connector initialization
"""

import math
import sys
from datetime import datetime, timezone
from fractions import Fraction
from typing import Optional

# BQCA v48: Qiskit 2.5+ required
from qiskit import QuantumCircuit, QuantumRegister, ClassicalRegister, transpile
from qiskit.circuit.library import QFTGate
from qiskit_ibm_runtime import SamplerV2, Session
from qiskit_aer import AerSimulator
from qiskit_aer.primitives import SamplerV2 as AerSamplerV2

# BQCA v48: Mandatory qiskit-connector imports (exact pattern required)
from qiskit_connector import QConnectorV2 as connector
from qiskit_connector import QPlanV2 as plan


def gcd(a: int, b: int) -> int:
    """Compute greatest common divisor."""
    while b:
        a, b = b, a % b
    return a


def mod_exp(base: int, exp: int, mod: int) -> int:
    """Compute (base^exp) mod mod efficiently."""
    result = 1
    base = base % mod
    while exp > 0:
        if exp % 2 == 1:
            result = (result * base) % mod
        exp = exp >> 1
        base = (base * base) % mod
    return result


def c_amod15(a: int, power: int) -> QuantumCircuit:
    """
    Controlled multiplication by a mod 15.
    Simplified implementation using SWAP-based permutations.
    """
    U = QuantumCircuit(4)
    
    # Simplified modular multiplication for N=15
    # This is a demonstration circuit, not cryptographically secure
    for _ in range(power):
        if a in [2, 13]:
            U.swap(0, 1)
            U.swap(1, 2)
            U.swap(2, 3)
        elif a in [7, 8]:
            U.swap(2, 3)
            U.swap(1, 2)
            U.swap(0, 1)
        elif a == 11:
            U.swap(1, 3)
            U.swap(0, 2)
        elif a in [4, 14]:
            U.swap(1, 3)
            U.swap(0, 2)
            U.swap(2, 3)
    
    U = U.to_gate()
    U.name = f"{a}^{power} mod 15"
    c_U = U.control()
    return c_U


def build_shor_circuit(N: int, a: int, n_count: int) -> QuantumCircuit:
    """Build Shor's algorithm circuit for factoring N with base a."""
    n_target = math.ceil(math.log2(N))
    
    # Create quantum registers
    counting = QuantumRegister(n_count, 'counting')
    target = QuantumRegister(n_target, 'target')
    c_counting = ClassicalRegister(n_count, 'c_counting')
    
    qc = QuantumCircuit(counting, target, c_counting)
    
    # Initialize target register to |1⟩
    qc.x(target[0])
    
    # Apply Hadamard gates to counting register
    qc.h(counting)
    qc.barrier()
    
    # Apply controlled-U operations
    for q in range(n_count):
        qc.append(
            c_amod15(a, 2**q),
            [counting[q]] + [target[i] for i in range(n_target)]
        )
    qc.barrier()
    
    # Apply inverse QFT
    qc.append(QFTGate(n_count).inverse(), counting)
    qc.barrier()
    
    # Measure counting register
    qc.measure(counting, c_counting)
    
    return qc


def extract_period(counts: dict, n_count: int, a: int, N: int) -> Optional[int]:
    """Extract period from measurement results using continued fractions."""
    # Get top measurement outcomes
    sorted_counts = sorted(counts.items(), key=lambda x: x[1], reverse=True)
    
    print(f"\nTop 5 measurement outcomes:")
    for bitstring, count in sorted_counts[:5]:
        measured_int = int(bitstring, 2)
        phase = measured_int / (2**n_count)
        print(f"  {bitstring} ({measured_int}): {count} counts, phase ≈ {phase:.4f}")
    
    # Try to extract period from top measurements
    for bitstring, _ in sorted_counts[:10]:
        measured_int = int(bitstring, 2)
        if measured_int == 0:
            continue
        
        phase = measured_int / (2**n_count)
        frac = Fraction(phase).limit_denominator(N)
        r = frac.denominator
        
        print(f"\nCandidate period from phase {phase:.4f}: r = {r}")
        
        # Verify period
        if r > 0 and mod_exp(a, r, N) == 1:
            print(f"Period verified: {a}^{r} ≡ 1 (mod {N})")
            return r
    
    print("\nNo valid period extracted from measurements")
    return None


def attempt_factorization(N: int, a: int, n_count: int, backend, current: str, 
                         execution_target: str) -> Optional[tuple[int, int]]:
    """Attempt to factor N using base a."""
    print(f"\n--- Attempt: Base a = {a} ---")
    print(f"Building Shor circuit for N={N}, a={a}, n_count={n_count}")
    
    # Build circuit
    shor_circuit = build_shor_circuit(N, a, n_count)
    print(f"Circuit size: {shor_circuit.num_qubits} qubits, {shor_circuit.depth()} depth")
    
    # Transpile circuit
    print(f"\nTranspiling circuit...")
    transpiled = transpile(shor_circuit, backend=backend, optimization_level=3)
    print(f"Transpiled depth: {transpiled.depth()}")
    print()
    
    # BQCA v48: Real-QPU-first with controlled simulator fallback
    try:
        if execution_target == "REAL_QPU":
            # Real QPU execution with plan-aware primitive selection
            if "Open" in current:
                # Open Plan: No Session, mode=backend (SamplerV2 for sampling workload)
                print("Using Open Plan: SamplerV2(mode=backend) without Session")
                sampler = SamplerV2(mode=backend)
            else:
                # Paid Plan: Use Session with mode=session
                print(f"Using Paid Plan ({current}): Session with SamplerV2(mode=session)")
                session = Session(backend=backend)
                sampler = SamplerV2(mode=session)
            
            print("Submitting job to real QPU...")
            job = sampler.run([transpiled], shots=4096)
            job_id = job.job_id()
            
            # BQCA v48: Emit job ID on first line for real QPU
            print(f"BQCA_JOB_ID={job_id}")
            print()
            
            print(f"Job ID: {job_id}")
            print("Waiting for results...")
            result = job.result()
            
        else:
            raise RuntimeError("Fallback to simulator")
            
    except Exception as qpu_error:
        # BQCA v48: Controlled simulator fallback with transpile
        print(f"Real QPU execution failed: {qpu_error}")
        print("Falling back to AerSimulator...")
        
        sim_backend = AerSimulator()
        sim_transpiled = transpile(shor_circuit, backend=sim_backend, optimization_level=3)
        sim_sampler = AerSamplerV2()
        
        print("Running on simulator...")
        print(f"BQCA_EXECUTION_TARGET=SIMULATOR")
        print(f"BQCA_FALLBACK_REASON={qpu_error}")
        
        job = sim_sampler.run([sim_transpiled], shots=4096)
        result = job.result()
        execution_target = "SIMULATOR"
    
    print("Results received")
    
    # Extract counts
    pub_result = result[0]
    counts_dict = pub_result.data.c_counting.get_counts()
    
    # Extract period
    r = extract_period(counts_dict, n_count, a, N)
    
    if r is None:
        return None
    
    # Check if period is even
    if r % 2 != 0:
        print(f"Period r={r} is odd, cannot extract factors")
        return None
    
    # Compute factors
    x = mod_exp(a, r // 2, N)
    
    if x == 1 or x == N - 1:
        print(f"x = {x} is trivial, cannot extract factors")
        return None
    
    factor1 = gcd(x - 1, N)
    factor2 = gcd(x + 1, N)
    
    if factor1 > 1 and factor2 > 1 and factor1 * factor2 == N:
        print(f"SUCCESS: Factors found!")
        print(f"  {N} = {factor1} × {factor2}")
        return (factor1, factor2)
    
    return None


def main():
    """Main execution function."""
    start_time = datetime.now(timezone.utc)
    
    print("=" * 80)
    print("Shor's Factoring Algorithm - Factor N=15")
    print("BQCA v48 Direct Execution")
    print("=" * 80)
    print(f"Execution started: {start_time.isoformat()}")
    print()
    
    # Problem parameters
    N = 15
    n_count = 8
    candidate_bases = [2, 7, 8, 11, 13]
    
    print(f"Target integer: N = {N}")
    print(f"Counting qubits: {n_count}")
    print(f"Candidate bases: {candidate_bases}")
    print()
    
    # BQCA v48: Initialize qiskit-connector (configuration gate must pass first)
    try:
        print("Initializing Qiskit Connector...")
        current = plan()
        backend = connector()
        
        print(f"BQCA_PLAN={current}")
        print(f"BQCA_BACKEND={backend.name}")
        print(f"BQCA_EXECUTION_TARGET=REAL_QPU")
        print()
        
        # Verify backend operational status
        if not backend.status().operational:
            raise RuntimeError(f"Backend {backend.name} is not operational")
        
        # Verify sufficient qubits
        required_qubits = n_count + math.ceil(math.log2(N))
        if backend.num_qubits < required_qubits:
            raise RuntimeError(f"Backend has {backend.num_qubits} qubits, need {required_qubits}")
        
        print(f"Backend operational: {backend.status().operational}")
        print(f"Available qubits: {backend.num_qubits}")
        print(f"Required qubits: {required_qubits}")
        print()
        
        execution_target = "REAL_QPU"
        fallback_reason = None
        
    except Exception as e:
        # BQCA v48: Controlled simulator fallback
        print(f"BQCA_FALLBACK_REASON=Real QPU unavailable: {e}")
        print(f"BQCA_EXECUTION_TARGET=SIMULATOR")
        print(f"BQCA_BACKEND=AerSimulator")
        print()
        
        backend = AerSimulator()
        current = "simulator"
        execution_target = "SIMULATOR"
        fallback_reason = str(e)
    
    # Try factorization with different bases
    factors = None
    attempts = 0
    final_base = None
    
    for a in candidate_bases:
        attempts += 1
        
        # Skip if gcd(a, N) > 1
        if gcd(a, N) > 1:
            print(f"\n--- Skipping base a = {a}: gcd({a}, {N}) = {gcd(a, N)} ---")
            continue
        
        result = attempt_factorization(N, a, n_count, backend, current, execution_target)
        
        if result is not None:
            factors = result
            final_base = a
            break
    
    # Compute duration
    end_time = datetime.now(timezone.utc)
    duration = (end_time - start_time).total_seconds()
    
    # BQCA v48: Print result summary with all required markers
    print()
    print("=" * 80)
    print("RESULT SUMMARY")
    print("=" * 80)
    print(f"Execution date/time: {start_time.isoformat()}")
    print(f"Execution duration: {duration:.2f} seconds")
    print(f"BQCA_EXECUTION_TARGET={execution_target}")
    print(f"BQCA_BACKEND={backend.name if hasattr(backend, 'name') else 'AerSimulator'}")
    
    if factors is not None:
        print(f"BQCA_RESULT=SUCCESS")
        print(f"BQCA_RESULT_VALUE=Factors of {N}: {factors[0]} × {factors[1]}")
        print(f"Attempts: {attempts}")
        print(f"Final base: a = {final_base}")
        print()
        print(f"Factorization successful: {N} = {factors[0]} × {factors[1]}")
        return 0
    else:
        print(f"BQCA_RESULT=FAILURE")
        print(f"BQCA_RESULT_VALUE=Factorization failed after {attempts} attempts")
        print()
        print("Factorization failed. Possible reasons:")
        print("  - Insufficient measurement statistics")
        print("  - Period extraction failed")
        print("  - All candidate bases yielded trivial factors")
        return 1


if __name__ == "__main__":
    sys.exit(main())