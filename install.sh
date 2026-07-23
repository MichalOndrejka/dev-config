#!/usr/bin/env bash
# Symlinks this repo's home/ configs into their real locations on Linux/macOS.
#
# Creates symbolic links so that editing the live config file (e.g. VS Code's
# settings.json) edits the file inside this repo directly. Existing files that
# aren't already links into this repo are backed up (renamed with a timestamp
# suffix) rather than overwritten.
#
# Usage: ./install.sh [--skip-extensions]

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKIP_EXTENSIONS=0
[[ "${1:-}" == "--skip-extensions" ]] && SKIP_EXTENSIONS=1

case "$(uname -s)" in
    Darwin) VSCODE_USER_DIR="$HOME/Library/Application Support/Code/User" ;;
    Linux)  VSCODE_USER_DIR="$HOME/.config/Code/User" ;;
    *)      echo "Unsupported OS: $(uname -s)" >&2; exit 1 ;;
esac

declare -a LINKED=() ALREADY_LINKED=() BACKED_UP=() FAILED=()

link_one() {
    local name="$1" source_rel="$2" target="$3"
    local source="$REPO_ROOT/$source_rel"

    if [[ ! -e "$source" ]]; then
        echo "warning: [$name] source missing: $source (skipped)" >&2
        FAILED+=("$name")
        return
    fi

    mkdir -p "$(dirname "$target")"

    if [[ -L "$target" ]]; then
        if [[ "$(readlink "$target")" == "$source" ]]; then
            ALREADY_LINKED+=("$name")
            return
        fi
    fi

    if [[ -e "$target" || -L "$target" ]]; then
        local backup="${target}.backup-$(date +%Y%m%d-%H%M%S)"
        mv "$target" "$backup"
        BACKED_UP+=("$name -> $backup")
    fi

    if ln -s "$source" "$target"; then
        LINKED+=("$name")
    else
        echo "warning: [$name] failed to create symlink" >&2
        FAILED+=("$name")
    fi
}

link_one "Claude Code CLAUDE.md"   ".claude/CLAUDE.md"     "$HOME/.claude/CLAUDE.md"
link_one "Claude Code settings"    ".claude/settings.json" "$HOME/.claude/settings.json"
link_one "VS Code settings"        "vscode/settings.json" "$VSCODE_USER_DIR/settings.json"
link_one "VS Code MCP config"      "vscode/mcp.json"      "$VSCODE_USER_DIR/mcp.json"
link_one "bash profile"            "shell/bash/.bashrc"  "$HOME/.bashrc"
link_one "zsh profile"             "shell/zsh/.zshrc"    "$HOME/.zshrc"

if command -v pwsh >/dev/null 2>&1; then
    PROFILE_PATH="$(pwsh -NoProfile -Command 'Write-Output $PROFILE' 2>/dev/null || true)"
    if [[ -n "$PROFILE_PATH" ]]; then
        link_one "PowerShell profile" "shell/powershell/Microsoft.PowerShell_profile.ps1" "$PROFILE_PATH"
    fi
else
    echo "note: pwsh not found; skipping PowerShell profile link" >&2
fi

if [[ "$SKIP_EXTENSIONS" -eq 0 ]]; then
    if command -v code >/dev/null 2>&1; then
        while IFS= read -r id; do
            id="$(echo "$id" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
            [[ -z "$id" || "$id" == \#* ]] && continue
            echo "Installing VS Code extension: $id"
            code --install-extension "$id" >/dev/null
        done < "$REPO_ROOT/vscode/extensions.txt"
    else
        echo "note: 'code' CLI not found on PATH; skipping VS Code extension install" >&2
    fi
fi

echo ""
echo "=== dev-config install summary ==="
echo "Linked:         ${LINKED[*]:-none}"
echo "Already linked: ${ALREADY_LINKED[*]:-none}"
[[ ${#BACKED_UP[@]} -gt 0 ]] && printf 'Backed up:      %s\n' "${BACKED_UP[*]}"
[[ ${#FAILED[@]} -gt 0 ]] && printf 'Failed:         %s\n' "${FAILED[*]}" >&2
