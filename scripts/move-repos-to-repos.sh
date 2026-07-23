#!/usr/bin/env bash
# Finds git repositories scattered outside ~/repos and moves them in.
#
# Scans common dev folders for directories containing a .git folder and
# reports where each would move to under ~/repos/<name>. Dry-run by default:
# nothing is moved unless --apply is passed. Name collisions (two repos that
# would land on the same ~/repos/<name>) are always skipped and reported,
# never overwritten.
#
# Usage: ./move-repos-to-repos.sh [--apply] [search_path ...]

set -euo pipefail

APPLY=0
if [[ "${1:-}" == "--apply" ]]; then
    APPLY=1
    shift
fi

SEARCH_PATHS=("$@")
if [[ ${#SEARCH_PATHS[@]} -eq 0 ]]; then
    SEARCH_PATHS=("$HOME/Documents" "$HOME/Desktop" "$HOME/dev" "$HOME/src")
fi

REPOS_HOME="$HOME/repos"
mkdir -p "$REPOS_HOME"
REPOS_HOME="$(cd "$REPOS_HOME" && pwd)"

declare -A FOUND=()
for search_path in "${SEARCH_PATHS[@]}"; do
    [[ -d "$search_path" ]] || continue
    while IFS= read -r -d '' git_dir; do
        repo_dir="$(cd "$(dirname "$git_dir")" && pwd)"
        [[ "$repo_dir" == "$REPOS_HOME"* ]] && continue
        FOUND["$repo_dir"]=1
    done < <(find "$search_path" -maxdepth 4 -type d -name ".git" -print0 2>/dev/null)
done

if [[ ${#FOUND[@]} -eq 0 ]]; then
    echo "No stray repositories found under: ${SEARCH_PATHS[*]}"
    exit 0
fi

declare -A BY_NAME=()
for repo_path in "${!FOUND[@]}"; do
    name="$(basename "$repo_path")"
    BY_NAME["$name"]="${BY_NAME[$name]:-}"$'\n'"$repo_path"
done

echo "=== Repos to move into $REPOS_HOME ==="
declare -a MOVE_SRC=() MOVE_DST=()
declare -a COLLISION_NAMES=()
for name in "${!BY_NAME[@]}"; do
    paths=()
    while IFS= read -r p; do [[ -n "$p" ]] && paths+=("$p"); done <<< "${BY_NAME[$name]}"
    if [[ ${#paths[@]} -gt 1 ]]; then
        COLLISION_NAMES+=("$name")
    else
        echo "  ${paths[0]}  ->  $REPOS_HOME/$name"
        MOVE_SRC+=("${paths[0]}")
        MOVE_DST+=("$REPOS_HOME/$name")
    fi
done

if [[ ${#COLLISION_NAMES[@]} -gt 0 ]]; then
    echo ""
    echo "Name collisions (skipped, resolve manually):" >&2
    for name in "${COLLISION_NAMES[@]}"; do
        echo "  $name:" >&2
        while IFS= read -r p; do [[ -n "$p" ]] && echo "    $p" >&2; done <<< "${BY_NAME[$name]}"
    done
fi

if [[ "$APPLY" -eq 0 ]]; then
    echo ""
    echo "Dry run only. Re-run with --apply to actually move these repos."
    exit 0
fi

for i in "${!MOVE_SRC[@]}"; do
    src="${MOVE_SRC[$i]}"
    dst="${MOVE_DST[$i]}"
    if [[ -e "$dst" ]]; then
        echo "warning: skipping $(basename "$dst"): target already exists at $dst" >&2
        continue
    fi
    mv "$src" "$dst"
    echo "Moved $src -> $dst"
done
