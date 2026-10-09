# BQCA Qiskit Configuration Enforcement Policy v38

<!-- BQCA-QISKIT-CONFIGURATION-v38:BEGIN -->
## Code-producing request classification

A request is a **code-producing request** when both conditions are true:

1. The request uses an implementation action such as `create`, `implement`, `write`, `generate`, `build`, `develop`, `produce`, `scaffold`, `construct`, `code`, `program`, `modify`, `update`, `repair`, `fix`, `refactor`, `complete`, or `execute`; and
2. The object is a quantum/Qiskit workload or artifact, including Python code, Qiskit code, circuits, algorithms, notebooks, scripts, runtime workloads, implementations, tests, repairs, or executable research assets.

## Mandatory pre-connector configuration gate

Before invoking qiskit_connector rules, templates, validation, generated Connector code, or backend-selection behavior for any code-producing request, BQCA must run:

```bash
.bob/quantum-tools/qiskit-configuration.sh configure --quiet
```

The configuration gate must succeed before qiskit_connector behavior proceeds. The tool reads the required values from the BQCA project-root `.env` at runtime and atomically creates or overwrites `~/.qiskit/qiskit-ibm.json`.

## Required environment objects

- `IQP_API_TOKEN`
- `OPEN_PLAN_CHANNEL`
- `PAID_PLAN_CHANNEL`
- `OPEN_PLAN_INSTANCE`
- `PAID_PLAN_INSTANCE`
- `OPEN_PLAN`
- `FLEX_PLAN`
- `PAYGO_PLAN`
- `PREMIUM_PLAN`
- `DEDICATED_PLAN`

## Resulting account contract

- If `OPEN_PLAN=on`, the `bqca` profile uses `OPEN_PLAN_CHANNEL` and `OPEN_PLAN_INSTANCE`.
- If any of `FLEX_PLAN`, `PAYGO_PLAN`, `PREMIUM_PLAN`, or `DEDICATED_PLAN` is `on`, the `bqca` profile uses `PAID_PLAN_CHANNEL` and `PAID_PLAN_INSTANCE`.
- Open and paid modes cannot be active at the same time.
- The output file contains exactly one profile named `bqca`.
- `bqca.is_default_account` is always `true`.
- No other profile is retained; therefore no other profile can be a default account.
- The token must never be printed in logs or user-visible output.

`qiskit_connector` relies on `~/.qiskit/qiskit-ibm.json` when making connectivity, account, instance, and backend decisions. Configuration failure is a blocking production error for code-producing requests.
<!-- BQCA-QISKIT-CONFIGURATION-v38:END -->
