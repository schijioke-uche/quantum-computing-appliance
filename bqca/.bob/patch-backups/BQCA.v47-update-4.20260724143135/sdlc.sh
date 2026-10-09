#!/usr/bin/env bash
set -Eeuo pipefail

#===============================================================================
# @Author: Dr. Jeffrey Chijioke-Uche, IBM Computer Scientist
# @Description: SDLC automation for the IBM Bob Quantum Computing Agent Appliance
#
# Usage:
#   ./sdlc-v3.sh
#   ./sdlc-v3.sh "Custom commit message"
#
# Optional environment variables:
#   GIT_REMOTE=origin                 Remote to fetch from and push to.
#   STASH_POLICY=all                  Recover every existing stash (default).
#   STASH_POLICY=latest               Recover only the newest stash.
#   STASH_POLICY=current              Recover stashes created on this branch.
#   STASH_POLICY=keep                 Leave all existing stashes untouched.
#   STASH_POLICY=abort                Stop if an existing stash is detected.
#
# Stash safety:
#   - Existing stashes are recorded before the repository is changed.
#   - A stash is applied first; it is not popped immediately.
#   - Recovered changes are committed before the stash is dropped.
#   - If application or commit fails, the stash is retained.
#===============================================================================

readonly DEFAULT_COMMIT_MESSAGE="Updated IBM Bob Quantum Computing Agent Appliance"
readonly COMMIT_MESSAGE="${1:-$DEFAULT_COMMIT_MESSAGE}"
readonly REMOTE="${GIT_REMOTE:-origin}"
readonly STASH_POLICY="${STASH_POLICY:-all}"

error_report() {
    local exit_code=$?
    printf '\nERROR: SDLC failed at line %s while running: %s\n' \
        "${BASH_LINENO[0]:-unknown}" "${BASH_COMMAND:-unknown}" >&2
    exit "$exit_code"
}
trap error_report ERR

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

command -v git >/dev/null 2>&1 || fail "Git is not installed or is not in PATH."

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || \
    fail "Run this script from inside a Git repository."

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"
readonly REPO_ROOT

BRANCH="$(git symbolic-ref --quiet --short HEAD)" || \
    fail "Detached HEAD detected. Check out a branch before running this script."
readonly BRANCH

git remote get-url "$REMOTE" >/dev/null 2>&1 || \
    fail "Git remote '$REMOTE' does not exist."

case "$STASH_POLICY" in
    all|latest|current|keep|abort) ;;
    *)
        fail "Invalid STASH_POLICY '$STASH_POLICY'. Use all, latest, current, keep, or abort."
        ;;
esac

if [[ -n "$(git diff --name-only --diff-filter=U)" ]]; then
    fail "Unresolved merge conflicts exist. Resolve them before running this script."
fi

ensure_runtime_ignores() {
    # Runtime PID files are volatile and can change between commit and rebase.
    # Keep them on disk, but never track them in Git.
    touch .gitignore

    if ! grep -Fqx '.bob/runtime/*.pid' .gitignore; then
        {
            printf '\n# IBM Bob runtime process files\n'
            printf '.bob/runtime/*.pid\n'
        } >> .gitignore
        log "Added IBM Bob runtime PID files to .gitignore"
    fi

    # Remove an already tracked PID file from the index while retaining it in
    # the working directory.
    git rm --cached -f --ignore-unmatch -- '.bob/runtime/*.pid' >/dev/null
}

apply_shell_permissions() {
    local script_file

    # Set the executable bit before staging so Git records the mode change.
    while IFS= read -r -d '' script_file; do
        if [[ -f "$script_file" && ! -L "$script_file" ]]; then
            chmod +x -- "$script_file"
        fi
    done < <(git ls-files -z --cached --others --exclude-standard -- '*.sh')

    log "Applied executable permission to repository shell scripts"
}

commit_pending_changes() {
    local message="${1:-$COMMIT_MESSAGE}"

    git add -A

    if git diff --cached --quiet; then
        log "No staged changes to commit"
        return 0
    fi

    git commit -m "$message"
    log "Committed repository changes"
}

working_tree_is_clean() {
    [[ -z "$(git status --porcelain=v1 --untracked-files=all)" ]]
}

commit_until_clean() {
    local message="${1:-$COMMIT_MESSAGE}"
    local attempt

    # Retry briefly if a hook or background process changes a tracked file
    # while a commit is being created.
    for attempt in 1 2 3; do
        commit_pending_changes "$message"
        if working_tree_is_clean; then
            return 0
        fi
        warn "The working tree changed during commit attempt $attempt; retrying."
    done

    git status --short >&2
    fail "The working tree is still changing. Stop the modifying process and rerun the script."
}

sync_from_remote() {
    git fetch --prune "$REMOTE"

    if git show-ref --verify --quiet "refs/remotes/$REMOTE/$BRANCH"; then
        if ! git rebase --autostash "$REMOTE/$BRANCH"; then
            printf '\nRebase stopped. Resolve the conflicts, then run:\n' >&2
            printf '  git add -A\n' >&2
            printf '  git rebase --continue\n' >&2
            printf '  ./sdlc-v3.sh\n' >&2
            exit 1
        fi
        log "Rebased '$BRANCH' onto '$REMOTE/$BRANCH'"
    else
        warn "Remote branch '$REMOTE/$BRANCH' does not exist yet; rebase was skipped."
    fi
}

stash_ref_for_oid() {
    local wanted_oid="$1"

    git stash list --format='%gd%x09%H' | \
        awk -F '\t' -v oid="$wanted_oid" '$2 == oid { print $1; exit }'
}

stash_subject_for_oid() {
    local stash_oid="$1"

    git log -1 --format='%s' "$stash_oid"
}

stash_matches_current_branch() {
    local subject="$1"

    case "$subject" in
        "WIP on $BRANCH:"*|"On $BRANCH:"*) return 0 ;;
        *) return 1 ;;
    esac
}

declare -a EXISTING_STASH_OIDS=()
declare -a SELECTED_STASH_OIDS=()

inspect_existing_stashes() {
    local i stash_oid stash_subject

    # Capture stable stash object IDs. Unlike stash@{N}, these IDs do not
    # change when another stash is dropped and the stash indexes are renumbered.
    mapfile -t EXISTING_STASH_OIDS < <(git stash list --format='%H')

    if ((${#EXISTING_STASH_OIDS[@]} == 0)); then
        log "No existing Git stashes found; running the normal SDLC flow"
        return 0
    fi

    printf '\nExisting Git stashes detected:\n'
    git stash list --format='  %gd | %ci | %gs'
    printf '\n'

    case "$STASH_POLICY" in
        abort)
            fail "STASH_POLICY=abort: no repository or stash changes were made."
            ;;

        keep)
            warn "STASH_POLICY=keep: existing stashes will remain untouched."
            return 0
            ;;

        latest)
            SELECTED_STASH_OIDS+=("${EXISTING_STASH_OIDS[0]}")
            ;;

        current)
            # Inspect oldest-to-newest so selected stashes are later recovered
            # in chronological order.
            for ((i=${#EXISTING_STASH_OIDS[@]} - 1; i >= 0; i--)); do
                stash_oid="${EXISTING_STASH_OIDS[i]}"
                stash_subject="$(stash_subject_for_oid "$stash_oid")"
                if stash_matches_current_branch "$stash_subject"; then
                    SELECTED_STASH_OIDS+=("$stash_oid")
                fi
            done
            ;;

        all)
            # git stash list is newest-first. Reverse it so recovery is oldest
            # to newest, matching the order in which the work was stashed.
            for ((i=${#EXISTING_STASH_OIDS[@]} - 1; i >= 0; i--)); do
                SELECTED_STASH_OIDS+=("${EXISTING_STASH_OIDS[i]}")
            done
            ;;
    esac

    if ((${#SELECTED_STASH_OIDS[@]} == 0)); then
        warn "No stash matched STASH_POLICY=$STASH_POLICY; all stashes were preserved."
        return 0
    fi

    log "Will safely recover ${#SELECTED_STASH_OIDS[@]} stash entry or entries"
}

recover_selected_stashes() {
    local stash_oid stash_ref stash_subject short_subject stash_message current_ref

    if ((${#SELECTED_STASH_OIDS[@]} == 0)); then
        return 0
    fi

    for stash_oid in "${SELECTED_STASH_OIDS[@]}"; do
        stash_ref="$(stash_ref_for_oid "$stash_oid")"

        if [[ -z "$stash_ref" ]]; then
            warn "A selected stash no longer exists; skipping object $stash_oid."
            continue
        fi

        stash_subject="$(stash_subject_for_oid "$stash_oid")"
        short_subject="${stash_subject:0:120}"

        # A stash should only be applied to a clean tree. Capture any file
        # changed by a hook or background process before proceeding.
        ensure_runtime_ignores
        apply_shell_permissions
        commit_until_clean "$COMMIT_MESSAGE"

        printf '\nApplying %s: %s\n' "$stash_ref" "$stash_subject"

        # Apply first and retain the stash as a backup. It is dropped only
        # after the restored content has been committed successfully.
        if ! git stash apply --quiet "$stash_oid"; then
            printf '\nERROR: Could not apply %s cleanly.\n' "$stash_ref" >&2
            printf 'The stash was NOT dropped, so its data remains safe.\n\n' >&2
            git status --short >&2
            printf '\nResolve the conflicts, then run:\n' >&2
            printf '  git add -A\n' >&2
            printf '  git commit -m "Recovered %s"\n' "$stash_ref" >&2
            printf "  git stash drop '%s'\n" "$stash_ref" >&2
            printf '  ./sdlc-v3.sh\n' >&2
            exit 1
        fi

        ensure_runtime_ignores
        apply_shell_permissions
        stash_message="Recovered $stash_ref: $short_subject"
        commit_until_clean "$stash_message"

        # Find the reference again because stash indexes may have changed.
        current_ref="$(stash_ref_for_oid "$stash_oid")"
        if [[ -n "$current_ref" ]]; then
            git stash drop "$current_ref" >/dev/null
            log "Recovered, committed, and dropped $stash_ref"
        else
            warn "$stash_ref was already absent after its content was committed."
        fi
    done
}

# Detect and select existing stashes before changing the repository.
inspect_existing_stashes

# Commit current working-tree changes before synchronization. This creates a
# clean base for both rebase and stash recovery.
ensure_runtime_ignores
apply_shell_permissions
commit_until_clean "$COMMIT_MESSAGE"

# Integrate the latest remote history before restoring the selected stashes.
sync_from_remote

# Restore each selected stash safely, commit it, and only then drop it.
recover_selected_stashes

# Capture any legitimate file changed by a hook or background process during
# rebase or stash recovery. Ignored PID files are never included.
ensure_runtime_ignores
apply_shell_permissions
commit_until_clean "$COMMIT_MESSAGE"

# A remote update can occur after fetch. Retry once after another rebase if the
# first push is rejected as non-fast-forward.
if ! git push -u "$REMOTE" "$BRANCH"; then
    warn "Initial push failed; fetching and rebasing once more."
    sync_from_remote
    ensure_runtime_ignores
    apply_shell_permissions
    commit_until_clean "$COMMIT_MESSAGE"
    git push -u "$REMOTE" "$BRANCH"
fi

log "Pushed '$BRANCH' to '$REMOTE'"

printf '\nRemaining Git stashes:\n'
if git stash list | grep -q .; then
    git stash list --format='  %gd | %ci | %gs'
else
    printf '  None\n'
fi

printf '\nRepository status:\n'
git status --short --br