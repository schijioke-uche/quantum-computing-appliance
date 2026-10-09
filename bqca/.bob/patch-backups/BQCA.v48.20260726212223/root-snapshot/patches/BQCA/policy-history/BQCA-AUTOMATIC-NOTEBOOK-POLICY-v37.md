# BQCA Enforced Automatic Notebook Production Policy v37

<!-- BQCA-NOTEBOOK-AUTOGEN-v37:BEGIN -->
Automatic notebook generation is a production runtime requirement, not merely a conversational instruction.

For every Python implementation created or modified under `bob-quantum-store/`:

1. The `.py` file is created first and remains the authoritative implementation artifact.
2. The BQCA runtime watcher detects the new or changed `.py` file.
3. After the source becomes stable, the watcher automatically creates or refreshes the same-name sibling `.ipynb` file.
4. The generated notebook is validated before success is recorded.
5. BQCA must report both the `.py` and `.ipynb` artifact paths.

The enforced runtime tools are:

- `.bob/quantum-tools/notebook-generator.py`
- `.bob/quantum-tools/notebook-generator.sh`
- `.bob/quantum-tools/notebook-autogen-watcher.py`
- `.bob/quantum-tools/notebook-autogen.sh`

`xLaunchpad.sh` starts the watcher before the Bob quantum session and performs a final synchronous sweep when the session exits. This guarantees notebook generation even when a mode fails to invoke the generator itself.

Manual notebook construction remains an emergency fallback only when automatic generation returns a genuine failure. It is never the default path.
<!-- BQCA-NOTEBOOK-AUTOGEN-v37:END -->
