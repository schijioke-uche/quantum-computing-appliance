#!/usr/bin/env python3
"""Isolated BQCA v45 static and behavioral assurance tests."""
from __future__ import annotations

import argparse
import os
import pathlib
import subprocess
import tempfile
import textwrap


def run(command: list[str], *, env: dict[str, str] | None = None, expect: int = 0) -> None:
    result = subprocess.run(command, text=True, capture_output=True, env=env)
    if result.returncode != expect:
        raise RuntimeError(
            f"unexpected status {result.returncode}, expected {expect}: {' '.join(command)}\n"
            f"stdout:\n{result.stdout}\nstderr:\n{result.stderr}"
        )


def code_text(primitive: str, open_session: bool = False) -> str:
    primitive_import = "SamplerV2, EstimatorV2, Session"
    open_line = f"primitive = {primitive}(mode=backend)"
    if open_session:
        open_line = "with Session(backend=backend) as session:\n            primitive = SamplerV2(mode=session)"
    return textwrap.dedent(f'''\
        #!/usr/bin/env python3
        """Synthetic v44 Qiskit workload.
        Execute with qiskit-v2x-environment.sh run under $HOME/qiskit-v2x-env.
        Qiskit >= 2.5. qiskit-result-output is mandatory.
        """
        from qiskit import QuantumCircuit, transpile
        from qiskit_aer import AerSimulator
        from qiskit_ibm_runtime import {primitive_import}
        from qiskit_connector import QConnectorV2 as connector
        from qiskit_connector import QPlanV2 as plan

        current = plan()
        backend = connector()

        def is_open_plan(value):
            return "open" in str(value).lower()

        def execute(circuit):
            required_qubits = circuit.num_qubits
            if getattr(backend.status(), "operational", True) is not True:
                raise RuntimeError("not operational")
            if getattr(backend, "num_qubits", 0) < required_qubits:
                raise RuntimeError("insufficient qubit capacity")
            try:
                if is_open_plan(current):
                    {textwrap.indent(open_line, ' ' * 8).lstrip()}
                    job = primitive.run([circuit])
                else:
                    with Session(backend=backend) as session:
                        primitive = SamplerV2(mode=session)
                        job = primitive.run([circuit])
                result = job.result()
                print("BQCA_EXECUTION_TARGET=REAL_QPU")
                print(f"BQCA_JOB_ID={{job.job_id()}}")
                print(f"BQCA_PLAN={{current}}")
                print(f"BQCA_BACKEND={{backend}}")
                print(f"BQCA_RESULT={{result}}")
                return result
            except Exception as exc:
                print(f"BQCA_FALLBACK_REASON={{exc}}")
                sim_backend = AerSimulator()
                compiled = transpile(circuit, backend=sim_backend)
                result = sim_backend.run(compiled).result()
                print("BQCA_EXECUTION_TARGET=SIMULATOR")
                print(f"BQCA_PLAN={{current}}")
                print(f"BQCA_BACKEND={{sim_backend}}")
                print(f"BQCA_RESULT={{result}}")
                return result
    ''')


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=pathlib.Path, required=True)
    args = parser.parse_args()
    root = args.root.resolve()
    tools = root / ".bob/quantum-tools"
    code_validator = tools / "qiskit-code-policy-check.py"
    design_validator = tools / "qiskit-design-policy-check.py"
    result_validator = tools / "qiskit-result-output-policy-check.py"
    secret_scanner = tools / "bqca-secret-scan.py"
    notebook_generator = tools / "notebook-generator.sh"
    orchestrator = tools / "bqca-policy-orchestrator.sh"

    with tempfile.TemporaryDirectory(prefix="bqca-v44-test-") as raw:
        temp = pathlib.Path(raw)
        sampler = temp / "sampler-workload.py"
        estimator = temp / "estimator-workload.py"
        bad_open = temp / "invalid-open-session.py"
        sampler.write_text(code_text("SamplerV2"), encoding="utf-8")
        estimator.write_text(code_text("EstimatorV2"), encoding="utf-8")
        bad_open.write_text(code_text("SamplerV2", open_session=True), encoding="utf-8")
        run(["python3", str(code_validator), str(sampler)])
        run(["python3", str(code_validator), str(estimator)])
        run(["python3", str(code_validator), str(bad_open)], expect=1)

        design = temp / "vqe-design.md"
        design.write_text(textwrap.dedent('''\
            # VQE Research Design
            ## BQCA Qiskit 2.5+ Home Environment and Plan Policy
            Use $HOME/qiskit-v2x-env and source $HOME/qiskit-v2x-env/bin/activate.
            A project-local qiskit-v2x-env is prohibited. Qiskit 2.5 or later is required.
            CODE intent includes create, implement, write, generate, build, develop, produce,
            scaffold, construct, code, program, modify, update, repair, fix, refactor, complete, execute.
            Open Plan must not use Session. Use SamplerV2(mode=backend) for sampling, shots,
            counts, bitstrings, and distributions. Use EstimatorV2(mode=backend) for expectation
            values, observables, energy, and Hamiltonian workloads. Choose the suitable primitive.
            Paid Plan uses Session with SamplerV2(mode=session) or EstimatorV2(mode=session).
            Use try/except fallback, transpile, and AerSimulator. backend.run() is permitted only
            for a local simulator and is prohibited on real QPU hardware.
            Produce <code-name>-result-output.txt in the same directory. Capture complete stdout
            and combined stderr including Qiskit Connector output, timestamp, and a RESULT SUMMARY
            at the bottom stating execution successful. Put the real-QPU JOB ID on the first line.
            Execute with qiskit-v2x-environment.sh run through the canonical gate.
        '''), encoding="utf-8")
        run(["python3", str(design_validator), str(design)])
        run(["python3", str(result_validator), "--kind", "design", str(design)])

        notebook = temp / "sampler-workload.ipynb"
        run([str(notebook_generator), "--source", str(sampler), "--output", str(notebook), "--force"])
        run([str(notebook_generator), "--validate", str(notebook), "--against-source", str(sampler)])

        qpu_result = temp / "sampler-workload-result-output.txt"
        qpu_result.write_text(textwrap.dedent('''\
            JOB ID: synthetic-job-id
            BQCA QUANTUM EXECUTION RESULT OUTPUT
            Execution target        : REAL_QPU
            COMPLETE COMBINED EXECUTION OUTPUT
            BQCA_EXECUTION_TARGET=REAL_QPU
            BQCA_JOB_ID=synthetic-job-id
            BQCA_RESULT=ok
            RESULT SUMMARY
            Execution successful    : YES
            Completion date/time    : 2026-07-23T00:00:00+00:00
            Final execution target  : REAL_QPU
        '''), encoding="utf-8")
        run(["python3", str(result_validator), "--kind", "result", "--source", str(sampler), str(qpu_result)])

        clean = temp / "clean.txt"
        dirty = temp / "dirty.txt"
        clean.write_text("safe output\n", encoding="utf-8")
        dirty.write_text("IQP_API_TOKEN=ABCDEFGHIJKLMNOPQRSTUVWXYZ012345\n", encoding="utf-8")
        run(["python3", str(secret_scanner), str(clean)])
        run(["python3", str(secret_scanner), str(dirty)], expect=1)

        env = os.environ.copy()
        env["BQCA_V44_STATIC_ONLY"] = "1"
        env["BQCA_V44_TEST_MODE"] = "1"
        run([str(orchestrator), "validate-code", str(sampler)], env=env)

    print("BQCA_V44_TEST_SUITE=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
# BQCA-CANONICAL-PRODUCTION-POLICY-v45:BEGIN
# The sole active BQCA policy is .bob/BQCA-PRODUCTION-POLICY.md (v45).
# Route all public design, code, execution, result, and completion paths through
# bqca-policy-orchestrator.sh. Open Plan uses SamplerV2 or EstimatorV2 job mode
# according to workload semantics and must never use Session.
# BQCA-CANONICAL-PRODUCTION-POLICY-v45:END
