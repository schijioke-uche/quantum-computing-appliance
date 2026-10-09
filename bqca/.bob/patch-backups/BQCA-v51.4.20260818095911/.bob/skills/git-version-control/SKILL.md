---
name: git-version-control
description: Use when the user asks for Git version control guidance, commands, workflows, branching, release tagging, recovery, or enterprise Git best practices.
---

# Git Version Control

Git Version Control — Comprehensive Analysis 🧭

Git is a distributed version control system used to track changes in source code, configuration, documentation, infrastructure-as-code, scripts, and any text-based project files. It allows developers to work independently, collaborate safely, preserve history, branch workstreams, review changes, recover older versions, and coordinate releases.

At its core, Git manages three major areas:

Working directory  -> files you are editing
Staging area       -> files prepared for commit
Repository         -> committed history

A standard Git workflow looks like this:

Create or clone repository
      ↓
Create/edit files
      ↓
Stage changes
      ↓
Commit changes
      ↓
Push to remote repository
      ↓
Pull/fetch changes from others
      ↓
Merge/rebase branches
      ↓
Tag/release versions
1. Git Installation and Version Commands
Check Git version
git --version

Shows the installed Git version.

Example:

git version 2.45.2
Show help
git help
git help <command>
git <command> --help

Examples:

git help commit
git clone --help

Used to open detailed documentation for a Git command.

2. Git Global Configuration

Git configuration controls your identity, editor, default branch name, credential helpers, aliases, merge behavior, and more.

Show all config values
git config --list
Show global config
git config --global --list
Set user name
git config --global user.name "Dr. Jeffrey Chijioke-Uche"

Used as the author name for commits.

Set user email
git config --global user.email "your-email@example.com"

Used as the author email for commits.

Set default branch name
git config --global init.defaultBranch main

Makes new repositories use main instead of master.

Set default editor
git config --global core.editor "code --wait"

Uses VS Code as Git’s editor.

Other examples:

git config --global core.editor "vim"
git config --global core.editor "nano"
Enable color output
git config --global color.ui auto
Set pull strategy

Merge on pull:

git config --global pull.rebase false

Rebase on pull:

git config --global pull.rebase true

Fast-forward only:

git config --global pull.ff only
Configure credential helper

Linux:

git config --global credential.helper store

macOS:

git config --global credential.helper osxkeychain

Windows:

git config --global credential.helper manager
Show config origin
git config --list --show-origin

Shows where each config value comes from.

Unset a config value
git config --global --unset user.email
3. Creating and Cloning Repositories
Initialize a new Git repository
git init

Creates a new .git directory in the current folder.

Example:

mkdir my-project
cd my-project
git init
Initialize with a specific branch
git init --initial-branch=main
Clone a repository
git clone <repository-url>

Example:

git clone https://github.com/example/project.git
Clone into a specific directory
git clone https://github.com/example/project.git my-folder
Clone a specific branch
git clone --branch dev https://github.com/example/project.git
Shallow clone
git clone --depth 1 https://github.com/example/project.git

Downloads only the latest history. Useful for CI/CD or large repositories.

Clone with submodules
git clone --recurse-submodules https://github.com/example/project.git
4. Checking Repository Status
Show working tree status
git status

Shows modified, staged, untracked, and deleted files.

Short status
git status -s

Example output:

 M app.py
A  README.md
?? notes.txt

Meaning:

M  modified
A  added
D  deleted
?? untracked
Show current branch
git branch --show-current
5. Tracking and Staging Files

The staging area is where you prepare the exact changes that will go into the next commit.

Add a file
git add file.txt
Add all changed files
git add .

Stages new, modified, and deleted files under the current directory.

Add all changes in repo
git add -A

Stages all changes in the repository.

Add modified/deleted files only
git add -u

Does not add new untracked files.

Add interactively
git add -p

Lets you stage selected hunks of changes.

Unstage a file
git restore --staged file.txt

Older syntax:

git reset HEAD file.txt
Unstage everything
git restore --staged .
6. Committing Changes

A commit is a saved snapshot of your staged changes.

Commit staged changes
git commit -m "Add initial project files"
Commit with longer message
git commit

Opens editor for detailed commit message.

Stage tracked files and commit
git commit -am "Update tracked files"

Only works for files already tracked by Git.

Amend the last commit
git commit --amend

Used to modify the previous commit message or include additional staged changes.

Amend without changing message
git commit --amend --no-edit
Empty commit
git commit --allow-empty -m "Trigger pipeline"

Useful for CI/CD triggers.

7. Viewing Commit History
Show commit log
git log
Compact log
git log --oneline
Graph view
git log --oneline --graph --decorate --all
Show last N commits
git log -5
Show commits by author
git log --author="Jeffrey"
Show commits for a file
git log -- file.txt
Show file history with renames
git log --follow -- file.txt
Show detailed commit
git show <commit-hash>

Example:

git show a1b2c3d
Show changed file names in commits
git log --name-only
Show commit stats
git log --stat
8. Viewing Differences
Show unstaged changes
git diff
Show staged changes
git diff --staged

Equivalent:

git diff --cached
Compare two commits
git diff commit1 commit2
Compare branches
git diff main feature-branch
Compare file between branches
git diff main feature-branch -- file.txt
Word-level diff
git diff --word-diff
9. Branch Management

Branches allow independent lines of development.

List local branches
git branch
List all branches
git branch -a
List remote branches
git branch -r
Create a branch
git branch feature-login
Switch to branch
git switch feature-login

Older syntax:

git checkout feature-login
Create and switch
git switch -c feature-login

Older syntax:

git checkout -b feature-login
Rename current branch
git branch -m new-branch-name
Rename another branch
git branch -m old-name new-name
Delete local branch
git branch -d feature-login

Force delete:

git branch -D feature-login
Show merged branches
git branch --merged
Show unmerged branches
git branch --no-merged
10. Remote Repository Management

A remote is a hosted Git repository, usually on GitHub, GitLab, Bitbucket, Azure DevOps, or an internal enterprise Git server.

Show remotes
git remote
Show remote URLs
git remote -v
Add remote
git remote add origin https://github.com/example/project.git
Change remote URL
git remote set-url origin https://github.com/example/new-project.git
Remove remote
git remote remove origin
Rename remote
git remote rename origin upstream
Show remote details
git remote show origin
11. Fetching, Pulling, and Pushing
Fetch remote changes
git fetch

Downloads remote updates but does not merge them.

Fetch all remotes
git fetch --all
Pull changes
git pull

Equivalent to:

git fetch + git merge
Pull with rebase
git pull --rebase

Keeps history more linear.

Push current branch
git push
Push branch and set upstream
git push -u origin feature-login
Push all branches
git push --all
Push tags
git push --tags
Delete remote branch
git push origin --delete feature-login
Force push
git push --force

Safer force push:

git push --force-with-lease

Use --force-with-lease instead of --force because it prevents overwriting someone else’s newer remote work.

12. Merging Branches

Merging combines changes from one branch into another.

Merge another branch into current branch
git merge feature-login
Fast-forward only merge
git merge --ff-only feature-login

Fails if a merge commit would be required.

No fast-forward merge
git merge --no-ff feature-login

Always creates a merge commit.

Abort merge
git merge --abort

Use when conflicts occur and you want to cancel the merge.

13. Rebasing Branches

Rebase moves commits from one base to another.

Rebase current branch onto main
git rebase main
Interactive rebase
git rebase -i HEAD~5

Used to edit, squash, reorder, or drop commits.

Common interactive rebase actions:

pick    use commit
reword  use commit but edit message
edit    stop and amend commit
squash  combine with previous commit
fixup   combine and discard message
drop    remove commit
Continue rebase
git rebase --continue
Abort rebase
git rebase --abort
Skip commit during rebase
git rebase --skip
14. Conflict Resolution

Conflicts occur when Git cannot automatically combine changes.

Check conflict status
git status
Conflict markers in files
<<<<<<< HEAD
current branch changes
=======
incoming branch changes
>>>>>>> feature-branch
Resolve conflict manually

Edit the file, remove conflict markers, then stage:

git add conflicted-file.txt

Then continue:

For merge:

git commit

For rebase:

git rebase --continue
Abort conflict operation

Merge:

git merge --abort

Rebase:

git rebase --abort

Cherry-pick:

git cherry-pick --abort
15. Restoring, Resetting, and Reverting

These commands are critical and often confused.

Restore file from working tree
git restore file.txt

Discards unstaged changes.

Restore file from a commit
git restore --source=<commit> file.txt

Example:

git restore --source=HEAD~1 app.py
Reset staged file
git restore --staged file.txt
Soft reset
git reset --soft HEAD~1

Moves branch pointer back but keeps changes staged.

Mixed reset
git reset --mixed HEAD~1

Moves branch pointer back and unstages changes, but keeps files modified.

Default behavior:

git reset HEAD~1
Hard reset
git reset --hard HEAD~1

Destroys working tree changes and resets history. Use carefully.

Reset to remote branch
git fetch origin
git reset --hard origin/main

Makes local branch exactly match remote main.

Revert a commit
git revert <commit-hash>

Creates a new commit that undoes a previous commit. Safe for shared branches.

Revert merge commit
git revert -m 1 <merge-commit-hash>
16. Stashing Changes

Stash temporarily saves uncommitted changes.

Save changes
git stash
Save with message
git stash push -m "work in progress"
Include untracked files
git stash -u
List stashes
git stash list
Apply latest stash
git stash apply
Apply specific stash
git stash apply stash@{2}
Apply and remove stash
git stash pop
Drop stash
git stash drop stash@{0}
Clear all stashes
git stash clear
17. Tags and Releases

Tags mark specific commits, usually releases.

List tags
git tag
Create lightweight tag
git tag v1.0.0
Create annotated tag
git tag -a v1.0.0 -m "Release v1.0.0"

Annotated tags are recommended for releases.

Push tag
git push origin v1.0.0
Push all tags
git push --tags
Delete local tag
git tag -d v1.0.0
Delete remote tag
git push origin --delete v1.0.0
Checkout tag
git switch --detach v1.0.0
18. Cherry-Picking

Cherry-pick applies a specific commit onto the current branch.

Cherry-pick one commit
git cherry-pick <commit-hash>
Cherry-pick multiple commits
git cherry-pick commit1 commit2
Cherry-pick range
git cherry-pick A..B
Continue after conflict
git cherry-pick --continue
Abort cherry-pick
git cherry-pick --abort
19. Git Ignore

.gitignore prevents files from being tracked.

Example .gitignore
# OS files
.DS_Store
Thumbs.db

# Logs
*.log

# Python
__pycache__/
*.pyc
.venv/

# Node
node_modules/

# Terraform
.terraform/
*.tfstate
*.tfstate.*
crash.log
terraform.tfvars

# Secrets
.env
*.pem
*.key
Check why file is ignored
git check-ignore -v file.txt
Stop tracking already tracked file
git rm --cached file.txt

Then commit the change.

20. Removing and Moving Files
Remove file from Git and disk
git rm file.txt
Remove from Git only, keep local file
git rm --cached file.txt
Move or rename file
git mv old.txt new.txt
21. Cleaning Untracked Files
Preview cleanup
git clean -n
Remove untracked files
git clean -f
Remove untracked directories
git clean -fd
Remove ignored files too
git clean -fdx

Use carefully. This can delete generated files, build directories, and local artifacts.

22. Blame and Annotation
Show who changed each line
git blame file.txt
Blame specific line range
git blame -L 10,30 file.txt

Useful for debugging ownership and history.

23. Searching Git History
Search tracked files
git grep "search text"
Search in specific branch
git grep "search text" main
Search commit messages
git log --grep="bugfix"
Search changes by content
git log -S "function_name"

Finds commits that added or removed a specific string.

Search using regex patch history
git log -G "regex_pattern"
24. Bisecting Bugs

git bisect helps find which commit introduced a bug.

Start bisect
git bisect start
Mark current commit bad
git bisect bad
Mark known good commit
git bisect good <commit-hash>

Git checks out commits. Test each one, then mark:

git bisect good

or:

git bisect bad
End bisect
git bisect reset
25. Submodules

Submodules embed one Git repository inside another.

Add submodule
git submodule add https://github.com/example/library.git libs/library
Initialize submodules
git submodule init
Update submodules
git submodule update
Clone with submodules
git clone --recurse-submodules https://github.com/example/project.git
Update all submodules recursively
git submodule update --init --recursive
Pull submodule updates
git submodule update --remote
26. Worktrees

Worktrees let you check out multiple branches into separate directories.

Add worktree
git worktree add ../project-feature feature-branch
List worktrees
git worktree list
Remove worktree
git worktree remove ../project-feature
Prune stale worktrees
git worktree prune

Useful when you need to work on multiple branches simultaneously.

27. Git Archive

Creates an archive of repository contents.

Create ZIP archive
git archive --format=zip --output=release.zip HEAD
Create tar archive
git archive --format=tar --output=release.tar HEAD
Archive a specific branch
git archive --format=zip --output=main.zip main
28. Git Notes

Git notes attach metadata to commits without changing commits.

Add note
git notes add -m "Reviewed by architecture team"
Show notes
git notes show
List notes
git notes list
Push notes
git push origin refs/notes/*
29. Git Hooks

Hooks are scripts that run automatically during Git events.

Common hooks:

pre-commit
commit-msg
pre-push
pre-rebase
post-merge
post-checkout

Hook directory:

.git/hooks/

Example pre-commit hook:

#!/usr/bin/env bash
set -e

terraform fmt -check -recursive

Make executable:

chmod +x .git/hooks/pre-commit

For team-managed hooks, use tools such as pre-commit, Husky, or centralized hook templates.

30. Git Reflog

Reflog records movements of branch tips and HEAD.

Show reflog
git reflog
Recover deleted commit
git checkout <reflog-hash>

or create a branch:

git switch -c recovered-work <reflog-hash>
Reset to previous state
git reset --hard HEAD@{1}

Very useful after accidental reset, rebase, or branch deletion.

31. Git Maintenance and Optimization
Garbage collection
git gc

Cleans unnecessary files and optimizes repository.

Aggressive garbage collection
git gc --aggressive
Check repository integrity
git fsck
Prune unreachable objects
git prune

Usually git gc handles this.

Repack repository
git repack
Maintenance command
git maintenance run
32. Git LFS

Git LFS is used for large files such as models, binaries, archives, and media.

Install LFS
git lfs install
Track file type
git lfs track "*.zip"
git lfs track "*.pt"
git lfs track "*.bin"
Show tracked LFS patterns
git lfs track
Add .gitattributes
git add .gitattributes
Pull LFS files
git lfs pull
List LFS files
git lfs ls-files
33. SSH and Authentication
Generate SSH key
ssh-keygen -t ed25519 -C "your-email@example.com"
Start SSH agent
eval "$(ssh-agent -s)"
Add key
ssh-add ~/.ssh/id_ed25519
Show public key
cat ~/.ssh/id_ed25519.pub
Test GitHub SSH
ssh -T git@github.com
Change remote from HTTPS to SSH
git remote set-url origin git@github.com:org/repo.git
34. GitHub/GitLab Pull Request Workflow

Typical branch workflow:

git switch main
git pull
git switch -c feature/my-change
# edit files
git add .
git commit -m "Implement my change"
git push -u origin feature/my-change

Then open a Pull Request or Merge Request.

After merge:

git switch main
git pull
git branch -d feature/my-change
git remote prune origin
35. Production Branching Strategies
Trunk-based development
main
 ├── short-lived feature branches
 └── frequent merges

Best for mature CI/CD and fast release cycles.

Git Flow
main
develop
feature/*
release/*
hotfix/*

Best for structured release cycles.

GitHub Flow
main
feature branch
pull request
merge
deploy

Best for web/cloud delivery.

Release branch strategy
main
release/v1.0
release/v1.1
hotfix/v1.0.1

Best for enterprise products with multiple supported versions.

36. Recommended Enterprise Git Workflow

A strong enterprise workflow:

1. Create issue or work item
2. Create branch from main
3. Make focused changes
4. Run local tests
5. Commit with clear message
6. Push branch
7. Open pull request
8. Run CI checks
9. Code review
10. Squash or merge
11. Tag release if needed
12. Deploy through pipeline
13. Delete branch

Example:

git switch main
git pull --ff-only
git switch -c feature/add-authentication

git status
git add .
git commit -m "Add Bob authentication validation"

git push -u origin feature/add-authentication
37. Commit Message Best Practices

Good commit messages:

Add RPM noarch packaging support
Fix Bob authentication validation
Update IBM Software Hub README
Remove deprecated installer flags

Recommended format:

<type>: <short summary>

<longer explanation if needed>

Examples:

feat: add noarch RPM build support
fix: correct Debian package permissions
docs: update OpenShift install instructions
chore: remove stale patch scripts

Common types:

feat     new feature
fix      bug fix
docs     documentation
test     tests
refactor code change without behavior change
chore    maintenance
build    build system changes
ci       pipeline changes
38. Git Commands by Category
Category	Commands
Setup	git config, git init, git clone
Status	git status, git log, git show, git diff
Staging	git add, git restore --staged, git reset
Commit	git commit, git commit --amend
Branch	git branch, git switch, git checkout
Remote	git remote, git fetch, git pull, git push
Merge	git merge, git merge --abort
Rebase	git rebase, git rebase -i, git rebase --continue
Undo	git restore, git reset, git revert
Temporary save	git stash
Release	git tag, git archive
Debug	git blame, git bisect, git grep
Recovery	git reflog, git fsck
Large files	git lfs
Advanced	git submodule, git worktree, git notes
39. High-Value Daily Git Commands

These are the commands most developers use every day:

git status
git add .
git commit -m "message"
git pull --rebase
git push
git switch main
git switch -c feature/name
git log --oneline --graph --decorate --all
git diff
git restore file.txt
git stash
git stash pop
40. Safe Production Git Checklist ✅

Before pushing:

git status
git diff
git diff --staged
git log --oneline -5

Before merging:

git switch main
git pull --ff-only
git switch feature/my-branch
git rebase main

Before release:

git status
git log --oneline
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0

Before destructive operations:

git status
git branch backup-before-reset

Then safely reset if needed:

git reset --hard origin/main
41. Common Git Problems and Fixes
Problem: committed to wrong branch
git branch correct-branch
git reset --hard HEAD~1
git switch correct-branch
Problem: need to undo last commit but keep changes
git reset --soft HEAD~1
Problem: need to discard all local changes
git reset --hard
git clean -fd
Problem: local branch behind remote
git pull --rebase
Problem: remote branch deleted but still visible
git remote prune origin
Problem: accidentally deleted branch
git reflog
git switch -c recovered-branch <commit-hash>
Problem: need to remove secret from latest commit
git reset --soft HEAD~1
# remove secret
git add .
git commit -m "Remove secret"

For secrets already pushed, rotate the secret immediately and rewrite history only if required.

42. Git for Terraform / Infrastructure-as-Code

Recommended .gitignore:

.terraform/
*.tfstate
*.tfstate.*
crash.log
crash.*.log
*.tfvars
override.tf
override.tf.json
*_override.tf
*_override.tf.json
.terraform.lock.hcl

Important note: many teams do commit .terraform.lock.hcl to keep provider versions stable. Do not commit terraform.tfvars if it contains secrets.

Recommended flow:

terraform fmt -recursive
terraform validate
git status
git add .
git commit -m "Add Terraform infrastructure module"
git push
43. Git for Release Versioning

Semantic version example:

vMAJOR.MINOR.PATCH
v1.0.0
v1.1.0
v1.1.1

Release commands:

git tag -a v${BOB_VERSION} -m "Release v${BOB_VERSION}"
git push origin v${BOB_VERSION}

List versions:

git tag --sort=-version:refname
44. Recommended Git Aliases
git config --global alias.st status
git config --global alias.co checkout
git config --global alias.sw switch
git config --global alias.br branch
git config --global alias.cm "commit -m"
git config --global alias.lg "log --oneline --graph --decorate --all"
git config --global alias.last "log -1 HEAD --stat"

Usage:

git st
git lg
git cm "Update README"
45. Best Practices Summary

Use Git safely and professionally:

1. Commit small, logical changes.
2. Write clear commit messages.
3. Pull before starting work.
4. Use branches for features and fixes.
5. Use pull requests for review.
6. Avoid force-pushing shared branches.
7. Prefer --force-with-lease over --force.
8. Never commit secrets.
9. Use .gitignore properly.
10. Tag releases.
11. Protect main branches.
12. Use CI/CD checks before merge.
13. Keep commits meaningful.
14. Use rebase carefully.
15. Use revert for shared history.

For production teams, the safest default model is:

main protected
feature branches required
pull request required
CI checks required
review required
signed commits optional but recommended
release tags required


<!-- QCA-PATCH-v20-POLICY-BLOCK-START -->

## QCA-GENERATED-CODE-QUALITY-POLICY-v${BOB_VERSION}.Q20

When the user asks QCA to execute, write, create, generate, or implement quantum code from a design or prompt, all generated code must be production-quality, syntactically correct, and executable without avoidable errors.

Mandatory behavior:

1. Generated Python code must pass syntax validation before QCA reports success.
2. After writing any `.py` implementation file, validate it with `python -m py_compile <file>` or with `.bob/quantum-tools/qca-code-quality-guard.sh --validate <file>`.
3. If syntax validation fails, repair the code silently and revalidate before reading, summarizing, or reporting the file.
4. QCA must not claim that code is complete, saved, or executable until the saved file exists and syntax validation succeeds.
5. Generated code must use explicit imports, deterministic file paths, safe output directories, and clear terminal output.
6. Generated quantum code must remain aligned with Qiskit SDK 2.x or later unless the user explicitly requests another compatibility target.
7. For quantum visualizations, generated code must save durable PNG artifacts and print clean artifact paths.
8. Errors must be minimized. User-facing output must be clean, professional, and focused on final execution results and saved artifact paths.
9. Diagnostic failures, dependency installation output, and retry logs must be written behind the scenes to `.bob/qca-code-quality.log` or an equivalent local log file.

## QCA-GENERATE-CODE-TYPES-POLICY-v${BOB_VERSION}.Q20

When the user asks QCA to execute, write, create, generate, or implement code from a design, QCA must save implementation code under:

```text
bob-quantum-store/<normalized-design-name>/
```

For every generated implementation, QCA must create two code artifact types:

```text
<descriptive-code-name>.py
<descriptive-code-name>.ipynb
```

Mandatory behavior:

1. The `.py` file is the default executable artifact because it is compatible with terminal execution and clean terminal output requirements.
2. The `.ipynb` file is the companion notebook artifact for notebook review, learning, and visual inspection.
3. The notebook must represent the same implementation as the `.py` file unless the user explicitly asks for a notebook-only or divergent notebook workflow.
4. Both files must be saved in the same `bob-quantum-store/<normalized-design-name>/` directory.
5. QCA must verify both files exist before reporting success.
6. QCA must not save generated implementation code under `bob-quantum-designs/`.
7. QCA must keep design Markdown under `bob-quantum-designs/` and executable/generated code under `bob-quantum-store/`.

## QCA-CODE-EXECUTION-POLICY-v${BOB_VERSION}.Q20

When the user requests code execution, QCA must perform a silent execution readiness process before running code.

Mandatory pre-execution sequence:

1. Silently check whether the Qiskit/Python virtual environment exists. The default environment is:

```text
~/qiskit-v2x-env
```

2. If the environment does not exist, silently create or repair it using the established Qiskit v2.x environment setup workflow and Python 3.12-compatible environment behavior.
3. Before executing generated code, inspect the generated Python file and collect the imported modules.
4. Silently verify that required imported modules are installed inside the Qiskit/Python virtual environment.
5. If any required module is missing, silently install it into the virtual environment using `uv pip install --python <venv-python> <package>` or a safe fallback equivalent.
6. Do not execute code until the environment exists, imports are resolved, and syntax validation passes.
7. Execute the `.py` artifact by default unless the user specifically requests notebook execution.
8. Do not expose raw `ModuleNotFoundError`, dependency installation noise, or avoidable stack traces to the user. Log diagnostic details behind the scenes.
9. If execution fails, repair the code or environment when possible, revalidate, and retry once before reporting a concise failure summary.
10. Use `.bob/quantum-tools/qca-code-quality-guard.sh` when available for validation, notebook generation, dependency checks, and execution readiness.

Recommended guard command pattern:

```bash
.bob/quantum-tools/qca-code-quality-guard.sh --prepare bob-quantum-store/<design>/<code>.py
.bob/quantum-tools/qca-code-quality-guard.sh --execute bob-quantum-store/<design>/<code>.py
```

<!-- QCA-PATCH-v20-POLICY-BLOCK-END -->

<!-- BQCA-v30-POLICY-REFERENCE-START -->
## BQCA Production Policy v30 — Authoritative Precedence
Use `.bob/BQCA-PRODUCTION-POLICY.md` as the authoritative appliance-wide
policy. Preserve the specialized intelligence of this mode, rule, skill, or tool,
but resolve routing, implementation, execution, security, and completion behavior
according to the v30 policy. Design artifacts go to `bob-quantum-designs/`;
implementation and result artifacts go to `bob-quantum-store/`. Legacy
implementation directories must never be used.
<!-- BQCA-v30-POLICY-REFERENCE-END -->

<!-- BQCA-ACTIVE-CENTRAL-POLICY:BEGIN -->
## Active central policy binding
Before every quantum DESIGN or CODE decision, resolve the currently active authority through `.bob/quantum-tools/bqca-active-policy-listener.sh sync`. Read the stable policy and its embedded validation contract returned by the listener. Never hardcode a policy version or duplicate the complete central policy in this component.

Validate every design through `.bob/quantum-tools/qiskit-design-policy-check.py` and every Python code artifact through `.bob/quantum-tools/qiskit-code-policy-check.py`. The validators reload the registry, policy, policy SHA-256, and validation contract on every invocation and automatically create the required same-directory design/code policy-compliance report. Do not report an artifact complete unless its compliance report exists and reflects the active policy.
<!-- BQCA-ACTIVE-CENTRAL-POLICY:END -->

<!-- BQCA-BOB-SHELL-V2-DNA:BEGIN -->
## Bob Shell 2.x BQCA project-DNA binding
In a trusted Bob Shell 2.x workspace, read `AGENTS.md`, resolve the active central BQCA policy, honor the exported menu option/action/skill/mode, and use the current rules, relevant skills, quantum tools, and offline knowledgebase. This component supplements the existing BQCA workflow and must not replace its domain purpose or active-policy controls. Never degrade to generic Bob behavior.
<!-- BQCA-BOB-SHELL-V2-DNA:END -->
