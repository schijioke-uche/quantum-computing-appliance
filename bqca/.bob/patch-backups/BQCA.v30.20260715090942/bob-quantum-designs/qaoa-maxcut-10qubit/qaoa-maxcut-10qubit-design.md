# QAOA MaxCut Design: 10-Qubit Implementation

**Design Version:** 1.0  
**Created:** 2026-07-10  
**Algorithm:** Quantum Approximate Optimization Algorithm (QAOA)  
**Problem:** Maximum Cut (MaxCut)  
**Qubits:** 10  
**Target:** Qiskit SDK 2.x

---

## 1. Problem Definition

### MaxCut Problem
The Maximum Cut problem seeks to partition a graph's vertices into two sets such that the number of edges between the sets is maximized.

**Graph Specification:**
- **Vertices (V):** 10 nodes
- **Edges (E):** Complete graph K₁₀ or custom weighted graph
- **Objective:** Maximize the cut value C(z) = Σ wᵢⱼ(1 - zᵢzⱼ)/2

Where:
- wᵢⱼ = weight of edge between vertices i and j
- zᵢ ∈ {-1, +1} represents partition assignment

### Graph Structure Options

**Option A: Complete Graph (K₁₀)**
- 45 edges total
- All vertices connected
- Uniform edge weights (wᵢⱼ = 1)

**Option B: Random Weighted Graph**
- Erdős-Rényi random graph with probability p = 0.4
- Expected ~18 edges
- Random weights wᵢⱼ ∈ [0.5, 2.0]

**Option C: Structured Graph**
- Ring topology with cross-connections
- 15-20 edges
- Strategic placement for interesting optimization landscape

**Recommended:** Option B for balanced complexity and interesting optimization dynamics

---

## 2. QAOA Algorithm Architecture

### 2.1 Circuit Structure

**Layers:** p = 3 (three QAOA layers recommended for 10 qubits)

Each QAOA layer consists of:
1. **Cost Hamiltonian Evolution:** exp(-iγₗHc)
2. **Mixer Hamiltonian Evolution:** exp(-iβₗHm)

**Total Parameters:** 2p = 6 parameters (γ₁, β₁, γ₂, β₂, γ₃, β₃)

### 2.2 Initial State Preparation

```
|ψ₀⟩ = |+⟩⊗¹⁰ = (H⊗¹⁰)|0⟩⊗¹⁰
```

Apply Hadamard gates to all 10 qubits to create equal superposition:
- Represents uniform probability over all 2¹⁰ = 1024 possible cuts

### 2.3 Cost Hamiltonian (Hc)

Encodes the MaxCut objective function:

```
Hc = Σ(i,j)∈E wᵢⱼ(1 - ZᵢZⱼ)/2
```

**Circuit Implementation:**
- For each edge (i,j):
  - Apply CNOT(i,j)
  - Apply RZ(γₗ × wᵢⱼ) on qubit j
  - Apply CNOT(i,j) to uncompute

**Gate Count per Layer:**
- For complete graph: 45 edges × 3 gates = 135 gates
- For sparse graph (~18 edges): ~54 gates

### 2.4 Mixer Hamiltonian (Hm)

Standard X-mixer for exploring solution space:

```
Hm = Σᵢ₌₀⁹ Xᵢ
```

**Circuit Implementation:**
- Apply RX(2βₗ) gate to each of the 10 qubits

**Gate Count per Layer:** 10 RX gates

### 2.5 Complete Circuit Depth

**Per QAOA Layer:**
- Cost layer: ~54-135 gates (depending on graph density)
- Mixer layer: 10 gates

**Total for p=3:**
- Minimum: 3 × (54 + 10) = 192 gates
- Maximum: 3 × (135 + 10) = 435 gates
- **Estimated Depth:** 200-250 (with parallelization)

---

## 3. Parameterization Strategy

### 3.1 Initial Parameter Values

**Strategy 1: Linear Ramp (Recommended)**
```python
γ = [0.5, 1.0, 1.5]  # Increasing cost focus
β = [1.0, 0.7, 0.4]  # Decreasing mixing
```

**Strategy 2: Uniform Start**
```python
γ = [0.5, 0.5, 0.5]
β = [0.5, 0.5, 0.5]
```

**Strategy 3: Heuristic-Based**
```python
γ = [π/4, π/2, 3π/4]
β = [π/2, π/4, π/8]
```

### 3.2 Optimization Method

**Primary Optimizer:** COBYLA (Constrained Optimization BY Linear Approximation)
- Derivative-free
- Handles noisy cost functions
- Max iterations: 200
- Tolerance: 1e-6

**Alternative Optimizers:**
- SPSA (Simultaneous Perturbation Stochastic Approximation) for noisy backends
- L-BFGS-B for smooth landscapes
- Powell for local refinement

### 3.3 Parameter Bounds

```python
γ_bounds = [(0, 2π)] × 3
β_bounds = [(0, π)] × 3
```

---

## 4. Measurement and Evaluation

### 4.1 Measurement Strategy

**Basis:** Computational basis (Z-basis)
**Shots:** 8192 (for statistical significance)
**Repetitions:** 5 independent runs for averaging

### 4.2 Cost Function Evaluation

For each measurement outcome z = (z₀, z₁, ..., z₉):

```python
C(z) = Σ(i,j)∈E wᵢⱼ × (1 - zᵢzⱼ)/2
```

**Expectation Value:**
```python
⟨Hc⟩ = Σz P(z) × C(z)
```

Where P(z) is the measured probability of bitstring z.

### 4.3 Success Metrics

1. **Approximation Ratio:** r = C_QAOA / C_optimal
   - Target: r ≥ 0.85 for p=3
   - Excellent: r ≥ 0.90

2. **Convergence:** Optimizer reaches stable minimum
   - Max function evaluations: 200
   - Convergence tolerance: 1e-6

3. **Solution Quality:** Top 10 measured bitstrings contain near-optimal cuts

---

## 5. Circuit Architecture Details

### 5.1 Qubit Mapping

```
Physical Qubits: q[0] through q[9]
Graph Vertices:  v₀ through v₉
Mapping: Direct (qᵢ ↔ vᵢ)
```

### 5.2 Gate Decomposition

**Cost Layer (per edge):**
```
Edge (i,j) with weight w:
  CNOT qᵢ → qⱼ
  RZ(γ × w) qⱼ
  CNOT qᵢ → qⱼ
```

**Mixer Layer (per qubit):**
```
For each qubit qᵢ:
  RX(2β) qᵢ
```

### 5.3 Optimization for Depth Reduction

**Parallelization Strategy:**
- Group non-overlapping edges for simultaneous application
- Typical reduction: 30-40% depth savings
- Example: Edges (0,1), (2,3), (4,5) can be applied in parallel

**Gate Fusion:**
- Combine consecutive single-qubit rotations
- Merge RZ gates on same qubit within layer

---

## 6. Expected Outcomes

### 6.1 Classical Benchmark

**Brute Force Solution:**
- Search space: 2¹⁰ = 1024 configurations
- Optimal cut value: C_opt (depends on graph)
- Computational time: ~1ms (classical)

**Goemans-Williamson Algorithm:**
- Approximation ratio: 0.878 (guaranteed)
- Polynomial time complexity

### 6.2 QAOA Performance Expectations

**For p=3 layers:**
- Expected approximation ratio: 0.80-0.90
- Probability of optimal solution: 15-30%
- Top-10 solutions contain near-optimal cuts

**Convergence Behavior:**
- Typical iterations: 80-150
- Cost function evaluations: 100-200
- Optimization time: 2-5 minutes (simulator)

### 6.3 Quantum Advantage Indicators

- **Solution diversity:** QAOA explores multiple good solutions
- **Landscape navigation:** Quantum tunneling through local minima
- **Scalability:** Polynomial circuit depth vs exponential classical search

---

## 7. Visualization Strategy

### 7.1 Circuit Diagram
- Full QAOA circuit with p=3 layers
- Color-coded: Cost (blue), Mixer (green)
- Parameter annotations

### 7.2 Graph Visualization
- Node layout: Circular or force-directed
- Edge coloring: By weight
- Optimal cut: Red/blue node coloring

### 7.3 Optimization Convergence
- X-axis: Iteration number
- Y-axis: Cost function value
- Show: Best value, current value, parameter evolution

### 7.4 Solution Distribution
- Histogram of top 20 measured bitstrings
- Bar height: Measurement probability
- Color: Cut value (gradient)

### 7.5 Parameter Landscape
- 2D heatmap for (γ, β) pairs
- Contour lines for cost function
- Optimal point marked

### 7.6 Approximation Ratio
- Bar chart comparing:
  - Classical optimal
  - QAOA result
  - Random guess baseline

---

## 8. Implementation Considerations

### 8.1 Backend Selection

**Simulator (Development):**
- `AerSimulator` with statevector method
- Exact simulation for p=3, 10 qubits
- Memory requirement: ~8 MB

**Simulator (Production):**
- `AerSimulator` with shot-based sampling
- Noise models for realistic testing

**Hardware (Future):**
- IBM Quantum systems with ≥10 qubits
- Connectivity constraints may require SWAP gates
- Error mitigation recommended

### 8.2 Qiskit 2.x Compatibility

**Required Packages:**
```python
qiskit >= 2.0.0
qiskit-algorithms >= 0.3.0
qiskit-aer >= 0.15.0
networkx >= 3.0
matplotlib >= 3.7.0
numpy >= 1.24.0
```

**Key APIs:**
- `qiskit.circuit.QuantumCircuit`
- `qiskit_algorithms.QAOA`
- `qiskit_algorithms.optimizers.COBYLA`
- `qiskit.primitives.Sampler` or `Estimator`

### 8.3 Error Handling

**Potential Issues:**
1. Optimizer convergence failure → Retry with different initial parameters
2. Measurement noise → Increase shot count
3. Circuit depth limits → Reduce p or simplify graph
4. Memory constraints → Use shot-based simulation

---

## 9. Extensions and Variations

### 9.1 Advanced QAOA Variants

**Multi-Angle QAOA:**
- Individual γᵢⱼ for each edge
- Parameters: 2 × |E| + p
- Better approximation, harder optimization

**Warm-Start QAOA:**
- Initialize with classical heuristic solution
- Faster convergence
- Hybrid quantum-classical approach

**Recursive QAOA:**
- Solve subproblems iteratively
- Reduce effective problem size
- Applicable to large graphs

### 9.2 Problem Variations

**Weighted MaxCut:**
- Non-uniform edge weights
- Real-world network optimization

**Constrained MaxCut:**
- Balanced partition requirement
- Additional penalty terms in Hc

**Multi-Way Cut:**
- Partition into k > 2 sets
- Requires additional qubits or encoding

### 9.3 Hybrid Algorithms

**QAOA + Classical Refinement:**
- Use QAOA for exploration
- Apply local search for exploitation

**VQE-Style Adaptation:**
- Adaptive circuit depth
- Dynamic parameter initialization

---

## 10. Success Criteria

### Design Completeness
- ✅ Problem formulation defined
- ✅ Circuit architecture specified
- ✅ Parameterization strategy established
- ✅ Measurement protocol defined
- ✅ Visualization plan outlined

### Implementation Readiness
- ✅ Qiskit 2.x compatibility ensured
- ✅ Backend requirements specified
- ✅ Error handling considered
- ✅ Extension paths identified

### Expected Performance
- ✅ Approximation ratio target: ≥0.85
- ✅ Convergence criteria defined
- ✅ Benchmark comparisons planned

---

## 11. Next Steps

### For Design Review:
1. Validate graph structure choice
2. Confirm p=3 layer depth
3. Review parameter initialization strategy
4. Approve visualization requirements

### For Implementation:
1. Generate graph instance (NetworkX)
2. Build QAOA circuit with Qiskit 2.x
3. Implement cost function evaluator
4. Set up optimizer with COBYLA
5. Execute on AerSimulator
6. Generate all visualizations
7. Compare with classical benchmarks

---

## References

- Farhi, E., et al. "A Quantum Approximate Optimization Algorithm" (2014)
- Hadfield, S., et al. "From the Quantum Approximate Optimization Algorithm to a Quantum Alternating Operator Ansatz" (2019)
- Qiskit Algorithms Documentation: https://qiskit.github.io/qiskit-algorithms/
- NetworkX MaxCut: https://networkx.org/documentation/stable/reference/algorithms/cuts.html

---

**Design Status:** ✅ Complete and Ready for Implementation  
**Estimated Implementation Time:** 2-3 hours  
**Estimated Execution Time:** 5-10 minutes (simulator)
