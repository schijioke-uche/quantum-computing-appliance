# Quantum Circuit — Full Superposition: 156 Qubits
<!-- BQCA-DESIGN-ARTIFACT | Policy: v48 | Mode: quantum-qiskit-connector -->

## Overview

This design specifies a **full superposition quantum circuit** operating on exactly
**156 physical qubits**, structured into functional register banks that can be
mapped directly to IBM Quantum hardware (e.g., `ibm_torino`, `ibm_fez`, or `ibm_kyoto`
with ≥ 156-qubit capacity) and visualized as a Draw.io diagram.

The circuit applies a **Hadamard gate (H) to every qubit**, placing the entire
156-qubit register into a uniform superposition of all 2^156 computational basis states.
Measurement is applied to all qubits and routed to 156 classical bits.

---

## Architecture — Register Bank Layout (156 Qubits)

The 156 qubits are partitioned into **logical register banks** of equal or near-equal
size for hardware zone mapping, diagram readability, and future circuit expansion.

| Bank ID | Register Name    | Qubit Range  | Width | Role / Purpose                        |
|---------|-----------------|--------------|-------|---------------------------------------|
| A       | `q_bank_A`      | q[0]–q[19]   | 20    | Primary superposition register        |
| B       | `q_bank_B`      | q[20]–q[39]  | 20    | Secondary superposition register      |
| C       | `q_bank_C`      | q[40]–q[59]  | 20    | Tertiary superposition register       |
| D       | `q_bank_D`      | q[60]–q[79]  | 20    | Quaternary superposition register     |
| E       | `q_bank_E`      | q[80]–q[99]  | 20    | Quinary superposition register        |
| F       | `q_bank_F`      | q[100]–q[119]| 20    | Senary superposition register         |
| G       | `q_bank_G`      | q[120]–q[139]| 20    | Septenary superposition register      |
| H       | `q_bank_H`      | q[140]–q[155]| 16    | Final superposition register          |
| C0      | `c_out`         | c[0]–c[155]  | 156   | Classical measurement output register |

Total: **156 qubits** + **156 classical bits**

---

## Draw.io Diagram — Quantum Circuit XML

The XML below is a **Draw.io–importable quantum circuit diagram** for the
full 156-qubit superposition circuit. It represents each register bank as a
labeled swimlane row. The Hadamard gate (H box) and Measurement symbol (M)
are drawn per register.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<mxGraphModel dx="1500" dy="900" grid="1" gridSize="10" guides="1"
    tooltips="1" connect="1" arrows="1" fold="1" page="1"
    pageScale="1" pageWidth="1654" pageHeight="1169"
    math="0" shadow="0">
  <root>
    <mxCell id="0"/>
    <mxCell id="1" parent="0"/>

    <!-- ══════════════════════════════════════════════════════════
         TITLE BLOCK
    ══════════════════════════════════════════════════════════ -->
    <mxCell id="title" value="IBM Quantum — 156-Qubit Full Superposition Circuit"
      style="text;html=1;strokeColor=none;fillColor=none;align=center;
             verticalAlign=middle;whiteSpace=wrap;rounded=0;
             fontSize=18;fontStyle=1;fontColor=#1F3864;"
      vertex="1" parent="1">
      <mxGeometry x="100" y="20" width="1400" height="50" as="geometry"/>
    </mxCell>

    <!-- ══════════════════════════════════════════════════════════
         LEGEND
    ══════════════════════════════════════════════════════════ -->
    <mxCell id="legend_H" value="H = Hadamard Gate (Superposition)"
      style="text;html=1;strokeColor=none;fillColor=#dae8fc;align=left;
             verticalAlign=middle;whiteSpace=wrap;rounded=1;fontSize=11;"
      vertex="1" parent="1">
      <mxGeometry x="100" y="80" width="280" height="28" as="geometry"/>
    </mxCell>
    <mxCell id="legend_M" value="M = Measurement → Classical Bit"
      style="text;html=1;strokeColor=none;fillColor=#d5e8d4;align=left;
             verticalAlign=middle;whiteSpace=wrap;rounded=1;fontSize=11;"
      vertex="1" parent="1">
      <mxGeometry x="400" y="80" width="280" height="28" as="geometry"/>
    </mxCell>
    <mxCell id="legend_wire" value="— = Qubit Wire"
      style="text;html=1;strokeColor=none;fillColor=#fff2cc;align=left;
             verticalAlign=middle;whiteSpace=wrap;rounded=1;fontSize=11;"
      vertex="1" parent="1">
      <mxGeometry x="700" y="80" width="200" height="28" as="geometry"/>
    </mxCell>
    <mxCell id="legend_dbl" value="═ = Classical Wire"
      style="text;html=1;strokeColor=none;fillColor=#f8cecc;align=left;
             verticalAlign=middle;whiteSpace=wrap;rounded=1;fontSize=11;"
      vertex="1" parent="1">
      <mxGeometry x="920" y="80" width="200" height="28" as="geometry"/>
    </mxCell>

    <!-- ══════════════════════════════════════════════════════════
         CIRCUIT COLUMN HEADERS
    ══════════════════════════════════════════════════════════ -->
    <mxCell id="hdr_init" value="INIT |0⟩"
      style="text;html=1;strokeColor=#666666;fillColor=#f5f5f5;
             align=center;verticalAlign=middle;fontStyle=1;fontSize=11;
             fontColor=#333333;"
      vertex="1" parent="1">
      <mxGeometry x="280" y="120" width="100" height="30" as="geometry"/>
    </mxCell>
    <mxCell id="hdr_H" value="HADAMARD H"
      style="text;html=1;strokeColor=#666666;fillColor=#dae8fc;
             align=center;verticalAlign=middle;fontStyle=1;fontSize=11;
             fontColor=#004A8F;"
      vertex="1" parent="1">
      <mxGeometry x="480" y="120" width="120" height="30" as="geometry"/>
    </mxCell>
    <mxCell id="hdr_meas" value="MEASURE M"
      style="text;html=1;strokeColor=#666666;fillColor=#d5e8d4;
             align=center;verticalAlign=middle;fontStyle=1;fontSize=11;
             fontColor=#1A5C1A;"
      vertex="1" parent="1">
      <mxGeometry x="720" y="120" width="120" height="30" as="geometry"/>
    </mxCell>
    <mxCell id="hdr_class" value="CLASSICAL c[0..155]"
      style="text;html=1;strokeColor=#666666;fillColor=#f8cecc;
             align=center;verticalAlign=middle;fontStyle=1;fontSize=11;
             fontColor=#8B0000;"
      vertex="1" parent="1">
      <mxGeometry x="960" y="120" width="180" height="30" as="geometry"/>
    </mxCell>

    <!-- ══════════════════════════════════════════════════════════
         BANK A — q[0..19] — 20 qubits
    ══════════════════════════════════════════════════════════ -->
    <mxCell id="bank_A_label" value="Bank A&#xa;q[0..19]&#xa;(20 qubits)"
      style="swimlane;startSize=0;fillColor=#1F3864;fontColor=#ffffff;
             strokeColor=#1F3864;fontStyle=1;fontSize=11;
             horizontal=0;align=center;verticalAlign=middle;"
      vertex="1" parent="1">
      <mxGeometry x="100" y="160" width="70" height="100" as="geometry"/>
    </mxCell>
    <!-- init node A -->
    <mxCell id="init_A" value="|0⟩ ×20"
      style="rounded=1;whiteSpace=wrap;html=1;fillColor=#f5f5f5;
             strokeColor=#666666;fontColor=#333333;fontSize=12;fontStyle=1;"
      vertex="1" parent="1">
      <mxGeometry x="280" y="185" width="100" height="50" as="geometry"/>
    </mxCell>
    <!-- qubit wire A -->
    <mxCell id="wire_A" value=""
      style="endArrow=none;html=1;exitX=1;exitY=0.5;exitDx=0;exitDy=0;
             entryX=0;entryY=0.5;entryDx=0;entryDy=0;strokeColor=#333333;strokeWidth=2;"
      edge="1" source="init_A" target="gate_H_A" parent="1">
      <mxGeometry relative="1" as="geometry"/>
    </mxCell>
    <!-- Hadamard gate A -->
    <mxCell id="gate_H_A" value="H"
      style="rounded=0;whiteSpace=wrap;html=1;fillColor=#dae8fc;
             strokeColor=#004A8F;fontColor=#004A8F;fontSize=18;fontStyle=1;
             verticalAlign=middle;align=center;"
      vertex="1" parent="1">
      <mxGeometry x="480" y="185" width="60" height="50" as="geometry"/>
    </mxCell>
    <!-- wire A → measure -->
    <mxCell id="wire_A2" value=""
      style="endArrow=none;html=1;strokeColor=#333333;strokeWidth=2;"
      edge="1" source="gate_H_A" target="meas_A" parent="1">
      <mxGeometry relative="1" as="geometry"/>
    </mxCell>
    <!-- Measure gate A -->
    <mxCell id="meas_A" value="M"
      style="rounded=1;whiteSpace=wrap;html=1;fillColor=#d5e8d4;
             strokeColor=#1A5C1A;fontColor=#1A5C1A;fontSize=18;fontStyle=1;
             verticalAlign=middle;align=center;"
      vertex="1" parent="1">
      <mxGeometry x="720" y="185" width="60" height="50" as="geometry"/>
    </mxCell>
    <!-- classical wire A -->
    <mxCell id="cwire_A" value=""
      style="endArrow=block;html=1;strokeColor=#8B0000;strokeWidth=3;
             dashed=0;endFill=1;"
      edge="1" source="meas_A" target="creg_A" parent="1">
      <mxGeometry relative="1" as="geometry"/>
    </mxCell>
    <!-- Classical register A -->
    <mxCell id="creg_A" value="c[0..19]"
      style="rounded=1;whiteSpace=wrap;html=1;fillColor=#f8cecc;
             strokeColor=#8B0000;fontColor=#8B0000;fontSize=11;fontStyle=1;"
      vertex="1" parent="1">
      <mxGeometry x="960" y="185" width="120" height="50" as="geometry"/>
    </mxCell>

    <!-- ══════════════════════════════════════════════════════════
         BANK B — q[20..39] — 20 qubits
    ══════════════════════════════════════════════════════════ -->
    <mxCell id="bank_B_label" value="Bank B&#xa;q[20..39]&#xa;(20 qubits)"
      style="swimlane;startSize=0;fillColor=#1F3864;fontColor=#ffffff;
             strokeColor=#1F3864;fontStyle=1;fontSize=11;
             horizontal=0;align=center;verticalAlign=middle;"
      vertex="1" parent="1">
      <mxGeometry x="100" y="270" width="70" height="100" as="geometry"/>
    </mxCell>
    <mxCell id="init_B" value="|0⟩ ×20"
      style="rounded=1;whiteSpace=wrap;html=1;fillColor=#f5f5f5;
             strokeColor=#666666;fontColor=#333333;fontSize=12;fontStyle=1;"
      vertex="1" parent="1">
      <mxGeometry x="280" y="295" width="100" height="50" as="geometry"/>
    </mxCell>
    <mxCell id="wire_B" value=""
      style="endArrow=none;html=1;strokeColor=#333333;strokeWidth=2;"
      edge="1" source="init_B" target="gate_H_B" parent="1">
      <mxGeometry relative="1" as="geometry"/>
    </mxCell>
    <mxCell id="gate_H_B" value="H"
      style="rounded=0;whiteSpace=wrap;html=1;fillColor=#dae8fc;
             strokeColor=#004A8F;fontColor=#004A8F;fontSize=18;fontStyle=1;
             verticalAlign=middle;align=center;"
      vertex="1" parent="1">
      <mxGeometry x="480" y="295" width="60" height="50" as="geometry"/>
    </mxCell>
    <mxCell id="wire_B2" value=""
      style="endArrow=none;html=1;strokeColor=#333333;strokeWidth=2;"
      edge="1" source="gate_H_B" target="meas_B" parent="1">
      <mxGeometry relative="1" as="geometry"/>
    </mxCell>
    <mxCell id="meas_B" value="M"
      style="rounded=1;whiteSpace=wrap;html=1;fillColor=#d5e8d4;
             strokeColor=#1A5C1A;fontColor=#1A5C1A;fontSize=18;fontStyle=1;
             verticalAlign=middle;align=center;"
      vertex="1" parent="1">
      <mxGeometry x="720" y="295" width="60" height="50" as="geometry"/>
    </mxCell>
    <mxCell id="cwire_B" value=""
      style="endArrow=block;html=1;strokeColor=#8B0000;strokeWidth=3;endFill=1;"
      edge="1" source="meas_B" target="creg_B" parent="1">
      <mxGeometry relative="1" as="geometry"/>
    </mxCell>
    <mxCell id="creg_B" value="c[20..39]"
      style="rounded=1;whiteSpace=wrap;html=1;fillColor=#f8cecc;
             strokeColor=#8B0000;fontColor=#8B0000;fontSize=11;fontStyle=1;"
      vertex="1" parent="1">
      <mxGeometry x="960" y="295" width="120" height="50" as="geometry"/>
    </mxCell>

    <!-- ══════════════════════════════════════════════════════════
         BANK C — q[40..59] — 20 qubits
    ══════════════════════════════════════════════════════════ -->
    <mxCell id="bank_C_label" value="Bank C&#xa;q[40..59]&#xa;(20 qubits)"
      style="swimlane;startSize=0;fillColor=#274E13;fontColor=#ffffff;
             strokeColor=#274E13;fontStyle=1;fontSize=11;
             horizontal=0;align=center;verticalAlign=middle;"
      vertex="1" parent="1">
      <mxGeometry x="100" y="380" width="70" height="100" as="geometry"/>
    </mxCell>
    <mxCell id="init_C" value="|0⟩ ×20"
      style="rounded=1;whiteSpace=wrap;html=1;fillColor=#f5f5f5;
             strokeColor=#666666;fontColor=#333333;fontSize=12;fontStyle=1;"
      vertex="1" parent="1">
      <mxGeometry x="280" y="405" width="100" height="50" as="geometry"/>
    </mxCell>
    <mxCell id="wire_C" value=""
      style="endArrow=none;html=1;strokeColor=#333333;strokeWidth=2;"
      edge="1" source="init_C" target="gate_H_C" parent="1">
      <mxGeometry relative="1" as="geometry"/>
    </mxCell>
    <mxCell id="gate_H_C" value="H"
      style="rounded=0;whiteSpace=wrap;html=1;fillColor=#dae8fc;
             strokeColor=#004A8F;fontColor=#004A8F;fontSize=18;fontStyle=1;
             verticalAlign=middle;align=center;"
      vertex="1" parent="1">
      <mxGeometry x="480" y="405" width="60" height="50" as="geometry"/>
    </mxCell>
    <mxCell id="wire_C2" value=""
      style="endArrow=none;html=1;strokeColor=#333333;strokeWidth=2;"
      edge="1" source="gate_H_C" target="meas_C" parent="1">
      <mxGeometry relative="1" as="geometry"/>
    </mxCell>
    <mxCell id="meas_C" value="M"
      style="rounded=1;whiteSpace=wrap;html=1;fillColor=#d5e8d4;
             strokeColor=#1A5C1A;fontColor=#1A5C1A;fontSize=18;fontStyle=1;
             verticalAlign=middle;align=center;"
      vertex="1" parent="1">
      <mxGeometry x="720" y="405" width="60" height="50" as="geometry"/>
    </mxCell>
    <mxCell id="cwire_C" value=""
      style="endArrow=block;html=1;strokeColor=#8B0000;strokeWidth=3;endFill=1;"
      edge="1" source="meas_C" target="creg_C" parent="1">
      <mxGeometry relative="1" as="geometry"/>
    </mxCell>
    <mxCell id="creg_C" value="c[40..59]"
      style="rounded=1;whiteSpace=wrap;html=1;fillColor=#f8cecc;
             strokeColor=#8B0000;fontColor=#8B0000;fontSize=11;fontStyle=1;"
      vertex="1" parent="1">
      <mxGeometry x="960" y="405" width="120" height="50" as="geometry"/>
    </mxCell>

    <!-- ══════════════════════════════════════════════════════════
         BANKS D–H: collapsed summary rows
    ══════════════════════════════════════════════════════════ -->
    <mxCell id="banks_DEF_label" value="Banks D–F&#xa;q[60..119]&#xa;(60 qubits)"
      style="swimlane;startSize=0;fillColor=#7B3F00;fontColor=#ffffff;
             strokeColor=#7B3F00;fontStyle=1;fontSize=11;
             horizontal=0;align=center;verticalAlign=middle;"
      vertex="1" parent="1">
      <mxGeometry x="100" y="490" width="70" height="100" as="geometry"/>
    </mxCell>
    <mxCell id="init_DEF" value="|0⟩ ×60"
      style="rounded=1;whiteSpace=wrap;html=1;fillColor=#f5f5f5;
             strokeColor=#666666;fontColor=#333333;fontSize=12;fontStyle=1;"
      vertex="1" parent="1">
      <mxGeometry x="280" y="515" width="100" height="50" as="geometry"/>
    </mxCell>
    <mxCell id="wire_DEF" value=""
      style="endArrow=none;html=1;strokeColor=#333333;strokeWidth=2;"
      edge="1" source="init_DEF" target="gate_H_DEF" parent="1">
      <mxGeometry relative="1" as="geometry"/>
    </mxCell>
    <mxCell id="gate_H_DEF" value="H ×60"
      style="rounded=0;whiteSpace=wrap;html=1;fillColor=#dae8fc;
             strokeColor=#004A8F;fontColor=#004A8F;fontSize=14;fontStyle=1;
             verticalAlign=middle;align=center;"
      vertex="1" parent="1">
      <mxGeometry x="480" y="515" width="80" height="50" as="geometry"/>
    </mxCell>
    <mxCell id="wire_DEF2" value=""
      style="endArrow=none;html=1;strokeColor=#333333;strokeWidth=2;"
      edge="1" source="gate_H_DEF" target="meas_DEF" parent="1">
      <mxGeometry relative="1" as="geometry"/>
    </mxCell>
    <mxCell id="meas_DEF" value="M ×60"
      style="rounded=1;whiteSpace=wrap;html=1;fillColor=#d5e8d4;
             strokeColor=#1A5C1A;fontColor=#1A5C1A;fontSize=14;fontStyle=1;
             verticalAlign=middle;align=center;"
      vertex="1" parent="1">
      <mxGeometry x="720" y="515" width="80" height="50" as="geometry"/>
    </mxCell>
    <mxCell id="cwire_DEF" value=""
      style="endArrow=block;html=1;strokeColor=#8B0000;strokeWidth=3;endFill=1;"
      edge="1" source="meas_DEF" target="creg_DEF" parent="1">
      <mxGeometry relative="1" as="geometry"/>
    </mxCell>
    <mxCell id="creg_DEF" value="c[60..119]"
      style="rounded=1;whiteSpace=wrap;html=1;fillColor=#f8cecc;
             strokeColor=#8B0000;fontColor=#8B0000;fontSize=11;fontStyle=1;"
      vertex="1" parent="1">
      <mxGeometry x="960" y="515" width="120" height="50" as="geometry"/>
    </mxCell>

    <!-- Banks G–H -->
    <mxCell id="banks_GH_label" value="Banks G–H&#xa;q[120..155]&#xa;(36 qubits)"
      style="swimlane;startSize=0;fillColor=#4C0099;fontColor=#ffffff;
             strokeColor=#4C0099;fontStyle=1;fontSize=11;
             horizontal=0;align=center;verticalAlign=middle;"
      vertex="1" parent="1">
      <mxGeometry x="100" y="600" width="70" height="100" as="geometry"/>
    </mxCell>
    <mxCell id="init_GH" value="|0⟩ ×36"
      style="rounded=1;whiteSpace=wrap;html=1;fillColor=#f5f5f5;
             strokeColor=#666666;fontColor=#333333;fontSize=12;fontStyle=1;"
      vertex="1" parent="1">
      <mxGeometry x="280" y="625" width="100" height="50" as="geometry"/>
    </mxCell>
    <mxCell id="wire_GH" value=""
      style="endArrow=none;html=1;strokeColor=#333333;strokeWidth=2;"
      edge="1" source="init_GH" target="gate_H_GH" parent="1">
      <mxGeometry relative="1" as="geometry"/>
    </mxCell>
    <mxCell id="gate_H_GH" value="H ×36"
      style="rounded=0;whiteSpace=wrap;html=1;fillColor=#dae8fc;
             strokeColor=#004A8F;fontColor=#004A8F;fontSize=14;fontStyle=1;
             verticalAlign=middle;align=center;"
      vertex="1" parent="1">
      <mxGeometry x="480" y="625" width="80" height="50" as="geometry"/>
    </mxCell>
    <mxCell id="wire_GH2" value=""
      style="endArrow=none;html=1;strokeColor=#333333;strokeWidth=2;"
      edge="1" source="gate_H_GH" target="meas_GH" parent="1">
      <mxGeometry relative="1" as="geometry"/>
    </mxCell>
    <mxCell id="meas_GH" value="M ×36"
      style="rounded=1;whiteSpace=wrap;html=1;fillColor=#d5e8d4;
             strokeColor=#1A5C1A;fontColor=#1A5C1A;fontSize=14;fontStyle=1;
             verticalAlign=middle;align=center;"
      vertex="1" parent="1">
      <mxGeometry x="720" y="625" width="80" height="50" as="geometry"/>
    </mxCell>
    <mxCell id="cwire_GH" value=""
      style="endArrow=block;html=1;strokeColor=#8B0000;strokeWidth=3;endFill=1;"
      edge="1" source="meas_GH" target="creg_GH" parent="1">
      <mxGeometry relative="1" as="geometry"/>
    </mxCell>
    <mxCell id="creg_GH" value="c[120..155]"
      style="rounded=1;whiteSpace=wrap;html=1;fillColor=#f8cecc;
             strokeColor=#8B0000;fontColor=#8B0000;fontSize=11;fontStyle=1;"
      vertex="1" parent="1">
      <mxGeometry x="960" y="625" width="120" height="50" as="geometry"/>
    </mxCell>

    <!-- ══════════════════════════════════════════════════════════
         FOOTER: Circuit Statistics
    ══════════════════════════════════════════════════════════ -->
    <mxCell id="footer" value="Circuit Stats:  Qubits = 156  |  Gate Depth = 2 (H + Measure)  |  H Gates = 156  |  Measurements = 156  |  Hilbert Space = 2^156 basis states  |  IBM Quantum Target: ibm_torino / ibm_fez (≥156Q)"
      style="text;html=1;strokeColor=#1F3864;fillColor=#E8EAF6;align=center;
             verticalAlign=middle;whiteSpace=wrap;rounded=1;
             fontSize=12;fontStyle=0;fontColor=#1F3864;"
      vertex="1" parent="1">
      <mxGeometry x="100" y="720" width="1350" height="40" as="geometry"/>
    </mxCell>

  </root>
</mxGraphModel>
```

---

## Quantum State After H⊗156

After applying H to all 156 qubits starting from |0⟩⊗156:

```
|ψ⟩ = H⊗156 |0⟩⊗156
     = (1/√2^156) Σ_{x ∈ {0,1}^156} |x⟩
     = uniform superposition of 2^156 ≈ 9.14 × 10^46 computational basis states
```

Each basis state has equal probability amplitude **1/√2^156**, and equal
measurement probability **1/2^156**.

---

## Circuit Properties

| Property                  | Value                                            |
|---------------------------|--------------------------------------------------|
| Total qubits              | 156                                              |
| Classical bits            | 156                                              |
| Gate depth                | 2 (H layer + Measure layer)                      |
| Single-qubit H gates      | 156                                              |
| Measurements              | 156                                              |
| Circuit width             | 156                                              |
| 2-qubit gate count        | 0 (pure single-qubit superposition)              |
| Hilbert space dimension   | 2^156 ≈ 9.14 × 10^46                            |
| IBM target backend        | `ibm_torino` (133Q+), `ibm_fez` (156Q), or sim  |

---

## Qiskit Connector — Real-QPU-First Execution and Simulator Fallback

**Mandatory for any code generated from this design.**

Implementation code must:

1. Import `QConnectorV2 as connector` and `QPlanV2 as plan` from `qiskit_connector`.
2. Initialize `current = plan()` and `backend = connector()`.
3. Verify the selected backend is a real, operational, non-simulator IBM Quantum QPU
   with ≥ 156 qubit capacity before submitting.
4. Use `SamplerV2(mode=backend)` under an Open Plan session for real-QPU execution.
5. On any failure — authentication, plan detection, backend selection, qubit capacity,
   transpilation, submission, or result retrieval — immediately fall back to an
   `AerSimulator` (or `BasicSimulator` when Aer is unavailable) using a
   try/except block in the generated code.
6. Print `REAL_QPU` or `SIMULATOR`, plan name, backend name, and fallback reason.
7. Save measurement histogram PNG and circuit diagram PNG to `bob-quantum-store/`.

---

## How to Import Into Draw.io

1. Open [app.diagrams.net](https://app.diagrams.net) (or the desktop Draw.io app).
2. From the menu: **Extras → Edit Diagram…** (or press `Ctrl+Shift+X`).
3. Paste the XML block above and click **OK**.
4. The circuit will render with all 8 register banks, Hadamard gates, measurement
   symbols, and classical output register.

---

## Next Steps

| Action                           | Command / Route                                              |
|----------------------------------|--------------------------------------------------------------|
| Generate executable Qiskit code  | `Create code for Superposition 156 Qubit circuit`           |
| Generate .ipynb notebook         | Automatic companion via QCA code generation                  |
| Run on IBM Quantum hardware      | Requires backend with ≥ 156 qubits + IBMQ credentials       |
| Run on local simulator           | `AerSimulator` with 156-qubit state-vector (memory-heavy)   |
| Extend with entanglement         | Add CX/CZ/ECR gates between register banks                  |

---

*Design artifact — BQCA Policy v48 | Mode: quantum-qiskit-connector | Store: bob-quantum-designs/superposition-156qubit/*
