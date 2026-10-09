# Grover's Search Algorithm Design (4 Qubits)

## Executive Summary

This design document specifies a quantum implementation of Grover's Search Algorithm for searching an unstructured database of 16 elements (2^4) using 4 qubits. Grover's algorithm provides a quadratic speedup over classical search, finding a marked item in O(√N) operations compared to O(N) classically.

## Algorithm Overview

### Purpose
Demonstrate quantum search advantage by locating a specific target state in an unstructured 4-qubit search space with high probability using amplitude amplification.

### Theoretical Foundation
- **Search Space**: 16 possible states (|0000⟩ to |1111⟩)
- **Target State**: One marked element (e.g., |1010⟩)
- **Optimal Iterations**: π/4 × √16 ≈ 3.14 iterations (use 3 iterations)
- **Success Probability**: >95% after optimal iterations
- **Quantum Speedup**: O(√N) vs O(N) classical

## Circuit Architecture

### 1. Initialization Phase
```
Initial State: |0000⟩
Apply Hadamard gates to all 4 qubits
Result: Equal superposition of all 16 states
|ψ⟩ = (1/4) Σ|x⟩ for x ∈ {0,1}^4
```

### 2. Oracle Design
The oracle marks the target state by applying a phase flip:
```
Oracle: O|x⟩ = (-1)^f(x)|x⟩
where f(x) = 1 if x is target, 0 otherwise

Implementation:
- Multi-controlled Z gate
- Target: |1010⟩ (example)
- Flips phase of target state only
```

### 3. Diffusion Operator (Inversion About Average)
```
Diffusion: D = 2|ψ⟩⟨ψ| - I

Implementation Steps:
1. Apply H⊗4 (Hadamard to all qubits)
2. Apply X⊗4 (X gates to all qubits)
3. Multi-controlled Z gate (4-qubit controlled-Z)
4. Apply X⊗4 (X gates to all qubits)
5. Apply H⊗4 (Hadamard to all qubits)

Effect: Amplifies amplitude of marked state
```

### 4. Grover Iteration
```
G = D × O (Diffusion after Oracle)
Apply G exactly 3 times for 4-qubit system
```

### 5. Measurement
```
Measure all 4 qubits in computational basis
Expected outcome: Target state with >95% probability
```

## Circuit Specifications

### Qubit Requirements
- **Total Qubits**: 4
- **Qubit Roles**: All qubits participate in search
- **Ancilla Qubits**: None required for basic implementation

### Gate Count Estimates (per iteration)
- Hadamard gates: 8 (4 in diffusion)
- X gates: 8 (4 in diffusion)
- Multi-controlled Z: 2 (1 oracle + 1 diffusion)
- **Total per iteration**: ~18 gates
- **Total for 3 iterations**: ~54 gates + initialization

### Circuit Depth
- Initialization: Depth 1 (parallel H gates)
- Per Grover iteration: Depth ~10-15 (depending on decomposition)
- Total depth: ~35-50 gates

## Implementation Strategy

### Phase 1: Oracle Construction
1. Define target state (e.g., |1010⟩ = decimal 10)
2. Implement phase oracle using controlled gates
3. Verify oracle marks only target state

### Phase 2: Diffusion Operator
1. Implement inversion about average
2. Use Hadamard-X-MCZ-X-Hadamard pattern
3. Optimize multi-controlled Z decomposition

### Phase 3: Iteration Loop
1. Apply Grover operator G = D × O
2. Repeat for optimal iterations (3 times)
3. Track amplitude evolution

### Phase 4: Measurement & Verification
1. Measure all qubits
2. Run multiple shots (1024-8192)
3. Verify target state has highest probability
4. Calculate success rate

## Visualization Requirements

### 1. Circuit Diagram
- Full Grover circuit with 3 iterations
- Clear oracle and diffusion operator boundaries
- Gate-level detail for educational purposes

### 2. Probability Distribution
- Histogram of measurement outcomes
- Highlight target state
- Show probability evolution across iterations

### 3. Amplitude Evolution
- Plot amplitude of target state vs iteration
- Show amplitude amplification effect
- Compare with uniform distribution

### 4. Success Probability vs Iterations
- Plot success rate for 1-6 iterations
- Identify optimal iteration count
- Demonstrate over-rotation effect

## Success Criteria

### Functional Requirements
1. ✓ Circuit initializes to equal superposition
2. ✓ Oracle correctly marks target state
3. ✓ Diffusion operator amplifies marked state
4. ✓ Target state measured with >90% probability
5. ✓ Success rate consistent across multiple runs

### Performance Metrics
- **Target Success Rate**: >95%
- **Shots per Run**: 8192
- **Execution Time**: <5 seconds on simulator
- **Circuit Fidelity**: >98% (simulator)

### Educational Outcomes
- Demonstrate quantum search advantage
- Visualize amplitude amplification
- Show optimal iteration calculation
- Illustrate over-rotation phenomenon

## Backend Requirements

### Simulator Options
1. **Primary**: `AerSimulator` (statevector or qasm)
2. **Alternative**: `BasicSimulator` for quick tests
3. **Advanced**: Noisy simulator for error analysis

### Real Hardware Considerations
- **Minimum Qubits**: 4
- **Gate Set**: H, X, CX, CZ (or decomposition)
- **Connectivity**: Preferably all-to-all or star topology
- **Error Rates**: <1% gate error for reliable results
- **Recommended Backends**: ibm_brisbane, ibm_kyoto, ibm_osaka

## Extensions & Variations

### 1. Multiple Target Search
- Modify oracle to mark multiple states
- Adjust iteration count: π/4 × √(N/M) where M = marked items
- Compare success rates

### 2. Unknown Target Count
- Implement quantum counting algorithm
- Estimate number of solutions
- Adapt iteration count dynamically

### 3. Error Mitigation
- Add readout error mitigation
- Implement zero-noise extrapolation
- Compare mitigated vs raw results

### 4. Scalability Study
- Extend to 5-6 qubits
- Analyze iteration scaling
- Measure circuit depth growth

### 5. Hybrid Classical-Quantum
- Use classical optimization for oracle design
- Adaptive iteration strategies
- Feedback-based search refinement

## Testing & Validation

### Unit Tests
1. Oracle phase flip verification
2. Diffusion operator correctness
3. Superposition initialization
4. Measurement distribution analysis

### Integration Tests
1. Full Grover iteration correctness
2. Multi-iteration amplitude tracking
3. Success rate across different targets
4. Comparison with classical search

### Performance Tests
1. Execution time benchmarks
2. Shot count sensitivity analysis
3. Simulator vs hardware comparison
4. Scalability to larger search spaces

## Expected Outcomes

### Quantum Advantage Demonstration
- **Classical Search**: Average 8 queries (N/2)
- **Grover's Search**: 3 iterations (√N)
- **Speedup Factor**: ~2.67× for 4 qubits
- **Probability Boost**: From 6.25% to >95%

### Learning Objectives
1. Understand amplitude amplification mechanics
2. Recognize optimal iteration importance
3. Observe quantum interference effects
4. Appreciate oracle design flexibility

## References & Resources

### Theoretical Background
- Grover, L. K. (1996). "A fast quantum mechanical algorithm for database search"
- Nielsen & Chuang, "Quantum Computation and Quantum Information" (Chapter 6)
- Qiskit Textbook: Grover's Algorithm

### Implementation Guides
- Qiskit Documentation: Grover's Algorithm
- IBM Quantum Learning: Search Algorithms
- Qiskit Algorithms: GroverOperator class

### Related Algorithms
- Quantum Amplitude Amplification (generalization)
- Quantum Counting Algorithm
- Quantum Phase Estimation (related technique)

## Design Metadata

- **Design Version**: 1.0
- **Target Qiskit Version**: 2.x
- **Complexity Level**: Intermediate
- **Estimated Implementation Time**: 4-6 hours
- **Prerequisites**: Basic quantum gates, superposition, quantum measurement
- **Design Date**: 2026-07-14
- **Design Status**: Ready for Implementation

---

## Implementation Checklist

- [ ] Set up Qiskit 2.x environment
- [ ] Define target state and oracle
- [ ] Implement oracle circuit
- [ ] Implement diffusion operator
- [ ] Construct full Grover circuit
- [ ] Run simulation with optimal iterations
- [ ] Generate circuit diagram
- [ ] Create measurement histogram
- [ ] Plot amplitude evolution
- [ ] Analyze success rate
- [ ] Test with different target states
- [ ] Document results and insights
- [ ] (Optional) Run on real quantum hardware
- [ ] (Optional) Implement error mitigation
- [ ] (Optional) Extend to 5-6 qubits

---

**Design Complete**: This document provides a comprehensive blueprint for implementing Grover's Search Algorithm on a 4-qubit quantum system using Qiskit 2.x, with clear specifications for circuit construction, visualization, testing, and validation.
