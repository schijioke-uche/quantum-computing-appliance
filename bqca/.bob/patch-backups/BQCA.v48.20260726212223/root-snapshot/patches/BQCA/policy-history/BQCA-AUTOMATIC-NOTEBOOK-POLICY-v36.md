# BQCA Automatic Notebook Generation Policy v36

<!-- BQCA-AUTOMATIC-NOTEBOOK-v36:BEGIN -->
This policy is mandatory and overrides any instruction that treats manual notebook construction as the default.

## Default artifact order for code requests

Whenever a user request creates, implements, writes, generates, builds, develops, scaffolds, modifies, repairs, fixes, or otherwise produces Python/quantum code:

1. Create and complete the `.py` source file first. The Python file is the authoritative implementation artifact.
2. Run the required Python and BQCA policy validation gates applicable to that source.
3. Automatically generate the corresponding Jupyter notebook from the ready `.py` file by invoking:

   `.bob/quantum-tools/notebook-generator.sh --source <ready-file.py> --force`

4. The default notebook path is the same directory and base name as the Python source, with `.ipynb` replacing `.py`.
5. Validate the notebook before reporting completion:

   `.bob/quantum-tools/notebook-generator.sh --validate <generated-file.ipynb>`

6. Report both artifact paths to the user.

## Automatic generation is the default

BQCA must not state that automated notebook tools are unavailable without first attempting the installed generator and capturing its actual error output. BQCA must not manually compose notebook JSON as the first approach.

## Manual fallback

Manual notebook generation remains permitted only when the installed automatic generator was invoked and failed. In that case BQCA must:

- preserve the completed `.py` source;
- report the automatic-generation failure reason;
- manually create the `.ipynb` as a fallback;
- run `--validate` against the manually generated notebook; and
- never report completion if notebook validation fails.

## Scope

This policy applies to all BQCA custom modes, code/implementation concierges, advanced modes, orchestrators, skills, rules, and tool-guided workflows. It also applies when the user asks only for code unless the user explicitly says not to create a notebook.
<!-- BQCA-AUTOMATIC-NOTEBOOK-v36:END -->
