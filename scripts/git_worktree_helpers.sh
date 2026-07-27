#!/bin/bash

# Helper utilities for Release Hub scripts that need to switch an app repo to a
# client branch. Git refuses `checkout <branch>` when that branch is already
# checked out in another worktree; these helpers detect that case and move the
# script into the existing worktree instead of failing.

git_worktree_path_for_branch() {
    local branch_name="$1"
    local wanted_ref="refs/heads/${branch_name}"

    git worktree list --porcelain 2>/dev/null | awk -v wanted_ref="$wanted_ref" '
        /^worktree / { path = substr($0, 10); next }
        /^branch / {
            ref = substr($0, 8)
            if (ref == wanted_ref) {
                print path
                exit
            }
        }
    '
}

git_current_branch_name() {
    git rev-parse --abbrev-ref HEAD 2>/dev/null || true
}

git_checkout_or_use_worktree() {
    local branch_name="$1"
    local checkout_log=""
    local existing_worktree=""
    local current_branch=""

    if [ -z "$branch_name" ]; then
        echo "  ❌ Branch target kosong."
        return 1
    fi

    current_branch=$(git_current_branch_name)
    if [ "$current_branch" = "$branch_name" ]; then
        return 0
    fi

    checkout_log=$(mktemp 2>/dev/null || mktemp -t release-hub-checkout)
    if git checkout "$branch_name" >/dev/null 2>"$checkout_log"; then
        rm -f "$checkout_log"
        return 0
    fi

    existing_worktree=$(git_worktree_path_for_branch "$branch_name")
    if [ -n "$existing_worktree" ] && [ -d "$existing_worktree" ]; then
        echo "  ⚠️ Branch '$branch_name' sedang aktif di worktree lain:"
        echo "     $existing_worktree"
        echo "  ➜ Menggunakan worktree tersebut untuk proses Release Hub."
        rm -f "$checkout_log"
        cd "$existing_worktree" || return 1
        return 0
    fi

    echo "  ❌ Error: Gagal pindah ke branch '$branch_name'."
    if [ -s "$checkout_log" ]; then
        sed 's/^/     /' "$checkout_log" | tail -n 8
    fi
    rm -f "$checkout_log"
    return 1
}

git_pull_current_branch() {
    local branch_name="$1"

    if [ -z "$branch_name" ]; then
        return 0
    fi

    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        git pull origin "$branch_name" >/dev/null 2>&1 || {
            echo "  ⚠️ Gagal pull origin '$branch_name'. Melanjutkan dengan state lokal."
        }
    fi
}

git_create_branch_from_base() {
    local new_branch="$1"
    local base_branch="$2"
    local base_ref="origin/${base_branch}"
    local checkout_log=""

    if [ -z "$new_branch" ] || [ -z "$base_branch" ]; then
        echo "  ❌ Branch baru/base branch kosong."
        return 1
    fi

    if ! git show-ref --verify --quiet "refs/remotes/origin/${base_branch}"; then
        base_ref="$base_branch"
    fi

    checkout_log=$(mktemp 2>/dev/null || mktemp -t release-hub-new-branch)
    if git checkout -b "$new_branch" "$base_ref" >/dev/null 2>"$checkout_log"; then
        rm -f "$checkout_log"
        return 0
    fi

    echo "  ❌ Error: Gagal membuat branch baru '$new_branch' dari '$base_ref'."
    if [ -s "$checkout_log" ]; then
        sed 's/^/     /' "$checkout_log" | tail -n 8
    fi
    rm -f "$checkout_log"
    return 1
}
