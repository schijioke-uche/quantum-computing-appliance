# Sodium Hydroxide (NaOH) VQE 4-Qubit Circuit Design

## Design Overview

**Molecule**: Sodium Hydroxide (NaOH)  
**Method**: Variational Quantum Eigensolver (VQE)  
**Qubits**: 4  
**Objective**: Calculate ground state energy levels of NaOH using quantum simulation

## Molecular System

### Chemical Properties
- **Formula**: NaOH
- **Molecular Weight**: 39.997 g/mol
- **Structure**: Ionic compound (Na⁺ and OH⁻)
- **Electrons**: 10 total electrons (Na: 11, O: 8, H: 1)
- **Active Space**: 4 electrons in 4 orbitals (mapped to 4 qubits)

### Quantum Mapping Strategy
- **Qubit 0**: Sodium 3s orbital
- **Qubit 1**: Oxygen 2p orbital (bonding)
- **Qubit 2**: Oxygen 2p orbital (non-bonding)
- **Qubit 3**: Hydroxide bonding orbital

## Circuit Architecture

### 1. Initialization and Superposition Layer

**Purpose**: Create equal superposition of computational basis states

**Design**:
```
q0: ─H─
q1: ─H─
q2: ─H─
q3: ─H─
```

**Rationale**: 
- Hadamard gates on all qubits create superposition
- Enables exploration of all possible electron configurations
- Foundation for variational ansatz

### 2. Entanglement Layer

**Purpose**: Create quantum correlations representing electron-electron interactions

**Design Pattern**: CNOT ladder with rotation gates

```
q0: ─●─────────Ry(θ₀)─●─────────
     │                 │
q1: ─X─Ry(θ₁)─●───────┼─────────
              │        │
q2: ──────────X─Ry(θ₂)─┼─●───────
                        │ │
q3: ────────────────────X─X─Ry(θ₃)─
```

**Entanglement Strategy**:
- **CNOT(q0, q1)**: Correlates Na 3s with O 2p bonding
- **CNOT(q1, q2)**: Correlates O 2p orbitals
- **CNOT(q0, q3)**: Correlates Na with OH bonding
- **CNOT(q2, q3)**: Correlates O non-bonding with OH

**Rotation Parameters**:
- θ₀, θ₁, θ₂, θ₃: Variational parameters optimized during VQE
- Range: [0, 2π]
- Initial values: Random or chemistry-informed

### 3. Variational Ansatz Layer

**Purpose**: Parameterized quantum circuit for energy minimization

**Design**: Hardware-efficient ansatz with multiple layers

**Layer Structure** (repeated L times):
```
Layer l:
  - Single-qubit rotations: Ry(θ), Rz(φ) on each qubit
  - Entangling gates: CNOT pairs
  - Additional rotations: Ry(ω)
```

**Parameters per Layer**:
- 4 qubits × 3 rotation angles = 12 parameters per layer
- Typical layers: L = 2-4
- Total parameters: 24-48 variational parameters

### 4. Measurement Layer

**Purpose**: Extract energy expectation values

**Measurement Bases**:
- **Computational (Z) basis**: Default measurement
- **X basis**: Measure after H gate
- **Y basis**: Measure after S†H gates

**Measurement Strategy**:
```
Pauli Decomposition of Hamiltonian:
H = Σᵢ αᵢ Pᵢ

Where Pᵢ are Pauli strings (e.g., XYZZ, ZZII, etc.)
```

**Measurement Protocol**:
1. Prepare state |ψ(θ)⟩ using ansatz
2. For each Pauli term Pᵢ:
   - Apply basis rotation gates
   - Measure in computational basis
   - Calculate expectation ⟨Pᵢ⟩
3. Compute energy: E(θ) = Σᵢ αᵢ⟨Pᵢ⟩

## VQE Algorithm Design

### Classical-Quantum Loop

```
1. Initialize parameters θ = θ₀
2. Repeat until convergence:
   a. Prepare quantum state |ψ(θ)⟩
   b. Measure energy E(θ) = ⟨ψ(θ)|H|ψ(θ)⟩
   c. Update parameters: θ ← θ - η∇E(θ)
3. Return optimized energy E_min and state |ψ(θ_opt)⟩
```

### Optimizer Selection

**Recommended**: COBYLA (Constrained Optimization BY Linear Approximation)
- Gradient-free
- Handles noisy quantum measurements
- Robust for VQE applications

**Alternative**: SPSA (Simultaneous Perturbation Stochastic Approximation)
- Efficient for high-dimensional parameter spaces
- Good noise tolerance

### Hamiltonian Construction

**Molecular Hamiltonian**:
```
H = H_core + H_electron-electron

H_core: One-electron terms (kinetic + nuclear attraction)
H_electron-electron: Two-electron repulsion terms
```

**Qubit Hamiltonian** (Jordan-Wigner or Parity mapping):
```
H_qubit = Σᵢⱼ hᵢⱼ (Zᵢ ⊗ Zⱼ) + Σᵢⱼₖₗ gᵢⱼₖₗ (Xᵢ ⊗ Yⱼ ⊗ Yₖ ⊗ Xₗ) + ...
```

## Energy Level Calculation

### Expected Energy Range
- **Ground State**: -75.0 to -76.0 Hartree (estimated)
- **Excited States**: Accessible through state preparation variations

### Convergence Criteria
- Energy change: |E(n+1) - E(n)| < 10⁻⁶ Hartree
- Parameter change: ||θ(n+1) - θ(n)|| < 10⁻⁴
- Maximum iterations: 1000

### Accuracy Considerations
- **Shot noise**: Use 8192-10000 shots per measurement
- **Barren plateaus**: Mitigate with layer-wise training
- **Hardware noise**: Apply error mitigation (ZNE, PEC)

## Implementation Specifications

### Backend Requirements
- **Simulator**: Qiskit Aer StatevectorSimulator or AerSimulator
- **Hardware**: IBM Quantum systems with ≥4 qubits
- **Connectivity**: All-to-all or linear chain topology

### Circuit Depth
- **Minimum depth**: ~20 gates (basic ansatz)
- **Typical depth**: 40-80 gates (L=2-3 layers)
- **Maximum depth**: <200 gates (hardware constraint)

### Resource Estimates
- **Classical memory**: ~100 MB for optimizer state
- **Quantum shots**: 8192 × number of Pauli terms
- **Runtime**: 10-30 minutes (simulator), 1-3 hours (hardware)

## Validation Strategy

### Verification Steps
1. **Classical benchmark**: Compare with Hartree-Fock calculation
2. **Exact diagonalization**: Verify with 4-qubit full state simulation
3. **Energy bounds**: Check E_VQE ≥ E_exact (variational principle)
4. **Convergence plots**: Monitor energy vs. iteration

### Success Metrics
- Chemical accuracy: |E_VQE - E_exact| < 1.6 mHartree (1 kcal/mol)
- Convergence rate: <500 iterations
- State fidelity: F(|ψ_VQE⟩, |ψ_exact⟩) > 0.95

## Extensions and Optimizations

### Advanced Features
1. **Adaptive VQE**: Dynamically grow ansatz depth
2. **Quantum Natural Gradient**: Faster convergence
3. **Symmetry preservation**: Enforce particle number, spin
4. **Error mitigation**: Zero-noise extrapolation

### Scalability Path
- **6 qubits**: Include additional O 2p orbitals
- **8 qubits**: Full valence space for NaOH
- **10+ qubits**: Include Na 2p core orbitals

## References and Resources

### Theoretical Background
- Peruzzo et al., "A variational eigenvalue solver on a photonic quantum processor" (2014)
- McClean et al., "The theory of variational hybrid quantum-classical algorithms" (2016)

### Qiskit Implementation
- `qiskit.algorithms.minimum_eigensolvers.VQE`
- `qiskit_nature.second_q.algorithms.GroundStateEigensolver`
- `qiskit.circuit.library.EfficientSU2` (ansatz template)

### Chemistry Tools
- PySCF: Classical quantum chemistry calculations
- Qiskit Nature: Molecular Hamiltonian generation
- OpenFermion: Fermion-to-qubit mappings

## Design Summary

This 4-qubit VQE circuit design for Sodium Hydroxide provides:
- ✅ Superposition initialization via Hadamard gates
- ✅ Entanglement through CNOT ladder structure
- ✅ Variational ansatz with 24-48 optimizable parameters
- ✅ Comprehensive measurement strategy for energy calculation
- ✅ Scalable architecture for molecular simulation

**Next Steps**: 
- Implement circuit in Qiskit
- Generate molecular Hamiltonian using Qiskit Nature
- Run VQE optimization with COBYLA
- Validate against classical methods
- Visualize convergence and energy landscape

---

**Design Version**: 1.0  
**Created**: 2026-07-07  
**Target Platform**: IBM Quantum / Qiskit 2.x  
**Status**: Ready for Implementation
