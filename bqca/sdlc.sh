#!/usr/bin/env bash
set -Eeuo pipefail

#===============================================================================
# @Author: Dr. Jeffrey Chijioke-Uche, IBM Computer Scientist
# @Description:
#   Simple SDLC automation for the IBM Bob Quantum Computing Agent Appliance.
#
# Workflow:
#   1. Silently remove all existing Git stashes.
#   2. Silently clear unresolved stash conflicts by keeping HEAD.
#   3. Apply executable permission to repository shell scripts.
#   4. Stage all repository changes.
#   5. Commit staged changes when present.
#   6. Push the current branch to origin, with safe retries.
#
# Usage:
#   ./sdlc.sh
#   ./sdlc.sh "Custom commit message"
#
# Optional environment variables:
#   GIT_REMOTE=origin
#   PUSH_RETRIES=3
#   PUSH_RETRY_DELAY=5
#
# This script intentionally does not run:
#   - git stash apply
#   - git stash pop
#   - git pull
#   - git fetch
#   - git rebase
#   - git merge
#===============================================================================

readonly DEFAULT_COMMIT_MESSAGE="Updated IBM Bob Quantum Computing Agent Appliance"
readonly COMMIT_MESSAGE="${1:-$DEFAULT_COMMIT_MESSAGE}"
readonly REMOTE="${GIT_REMOTE:-origin}"
readonly PUSH_RETRIES="${PUSH_RETRIES:-3}"
readonly PUSH_RETRY_DELAY="${PUSH_RETRY_DELAY:-5}"

###############################################################################
# Logging and error handling
###############################################################################

log() {
    printf 'OK: %s\n' "$*"
}

warn() {
    printf 'WARNING: %s\n' "$*" >&2
}

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

error_report() {
    local exit_code=$?

    printf '\nERROR: SDLC failed at line %s while running: %s\n' \
        "${BASH_LINENO[0]:-unknown}" \
        "${BASH_COMMAND:-unknown}" >&2

    exit "$exit_code"
}

trap error_report ERR

###############################################################################
# Validate configuration
###############################################################################

[[ "$PUSH_RETRIES" =~ ^[1-9][0-9]*$ ]] ||
    fail "PUSH_RETRIES must be a positive integer."

[[ "$PUSH_RETRY_DELAY" =~ ^[0-9]+$ ]] ||
    fail "PUSH_RETRY_DELAY must be a non-negative integer."

###############################################################################
# Validate Git and repository
###############################################################################

command -v git >/dev/null 2>&1 ||
    fail "Git is not installed or is not available in PATH."

git rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
    fail "Run this script from inside a Git repository."

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"
readonly REPO_ROOT

BRANCH="$(git symbolic-ref --quiet --short HEAD)" ||
    fail "Detached HEAD detected. Check out a branch before running this script."
readonly BRANCH

git remote get-url "$REMOTE" >/dev/null 2>&1 ||
    fail "Git remote '$REMOTE' does not exist."

###############################################################################
# Silently remove all existing stashes
###############################################################################

if [[ -n "$(git stash list)" ]]; then
    git stash clear
fi

###############################################################################
# Silently clear unresolved conflicts
#
# Unresolved paths left by an earlier stash operation are restored from HEAD.
# If a conflicted path does not exist in HEAD, its unresolved index entry and
# working-tree copy are removed.
###############################################################################

declare -a CONFLICTED_FILES=()

mapfile -d '' -t CONFLICTED_FILES < <(
    git diff --name-only --diff-filter=U -z
)

if ((${#CONFLICTED_FILES[@]} > 0)); then
    for conflicted_file in "${CONFLICTED_FILES[@]}"; do
        if git cat-file -e "HEAD:${conflicted_file}" 2>/dev/null; then
            git restore \
                --source=HEAD \
                --staged \
                --worktree \
                -- \
                "$conflicted_file"
        else
            git rm \
                -f \
                --ignore-unmatch \
                -- \
                "$conflicted_file" >/dev/null
        fi
    done
fi

if [[ -n "$(git diff --name-only --diff-filter=U)" ]]; then
    fail "Unable to clear all unresolved Git conflicts automatically."
fi

###############################################################################
# Apply executable permission to repository shell scripts
###############################################################################

while IFS= read -r -d '' script_file; do
    [[ -L "$script_file" ]] && continue
    chmod +x -- "$script_file"
done < <(
    find "$REPO_ROOT" \
        -type f \
        -name '*.sh' \
        -not -path "$REPO_ROOT/.git/*" \
        -print0
)

log "Applied executable permission to repository shell scripts"

###############################################################################
# Stage all changes
###############################################################################

git add -A
log "Staged repository changes"

###############################################################################
# Commit staged changes
###############################################################################

if git diff --cached --quiet; then
    log "No changes to commit"
else
    git commit -m "$COMMIT_MESSAGE"
    log "Committed repository changes"
fi

###############################################################################
# Determine whether origin already contains the local HEAD
#
# A GitHub Enterprise server may report a commit_refs failure even when the
# branch reference was updated. This check avoids unnecessary duplicate pushes.
###############################################################################

remote_branch_matches_head() {
    local local_head
    local remote_head

    local_head="$(git rev-parse HEAD)"

    remote_head="$(
        git ls-remote \
            --heads \
            "$REMOTE" \
            "refs/heads/$BRANCH" 2>/dev/null |
        awk 'NR == 1 {print $1}'
    )"

    [[ -n "$remote_head" && "$remote_head" == "$local_head" ]]
}

###############################################################################
# Push current branch with retry protection
###############################################################################

push_succeeded=0

for ((attempt = 1; attempt <= PUSH_RETRIES; attempt++)); do
    if git push -u "$REMOTE" "$BRANCH"; then
        push_succeeded=1
        break
    fi

    # Confirm whether the server updated the branch despite returning an error.
    if remote_branch_matches_head; then
        warn "The remote reported an error, but '$REMOTE/$BRANCH' contains the local HEAD."
        push_succeeded=1
        break
    fi

    if ((attempt < PUSH_RETRIES)); then
        warn "Push attempt ${attempt}/${PUSH_RETRIES} failed; retrying in ${PUSH_RETRY_DELAY} seconds."
        sleep "$PUSH_RETRY_DELAY"
    fi
done

if ((push_succeeded == 0)); then
    fail "Push failed after ${PUSH_RETRIES} attempts. The local commit remains safe."
fi

log "Pushed '$BRANCH' to '$REMOTE'"

###############################################################################
# Final status
###############################################################################

printf '\nRepository status:\n'
git status --short --branch

printf '\n'
log "SDLC completed successfully"

# BQCA-BOB-SHELL-V2-DNA:BEGIN
# In a trusted Bob Shell 2.x workspace, bind this component to AGENTS.md, the
# active central BQCA policy, exported menu context, current rules/skills/tools,
# and the offline knowledgebase without changing this component's core purpose.
# BQCA-BOB-SHELL-V2-DNA:END
