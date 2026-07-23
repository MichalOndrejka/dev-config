# dev-config

Personal cross-platform dev environment configuration: Claude Code, GitHub
Copilot, VS Code, shell profiles, and per-project scaffolding templates.
Real configs are **symlinked** from this repo into their OS locations, so
editing the live file edits the file in this repo directly.

## Layout

- `.claude/` — symlinked: `~/.claude/CLAUDE.md`, `~/.claude/settings.json`
- `.copilot/copilot-instructions.md` — starter template (**not symlinked** —
  copy into a project as `.github/copilot-instructions.md`)
- `vscode/` — symlinked: VS Code `settings.json`, `mcp.json`, and
  `extensions.txt` (one extension ID per line, installed via
  `code --install-extension`)
- `.editorconfig` — template (**not symlinked** — copy into a new project's
  root as `.editorconfig`)
- `shell/` — symlinked shell profiles.
  - `powershell/` — PowerShell profile (`$PROFILE`), works on Windows,
    Linux, and macOS under PowerShell 7 (pwsh)
  - `bash/`, `zsh/` — `.bashrc`, `.zshrc`
- `.gitignore` — combined template covering OS/editor noise plus Python,
  JavaScript, TypeScript, Go, and .NET build artifacts, **not symlinked**.
  Copy the whole thing (or just the sections you need) into a new project's
  `.gitignore`, or point `git config --global core.excludesfile` at this
  file.
- `scripts/` — one-off maintenance scripts (repo migration), not part of
  the main install flow.

## Install

**Windows** (PowerShell):
```powershell
.\install.ps1
```

**Linux/macOS**:
```bash
./install.sh
```

Both scripts:
- Create symlinks from this repo into the real config locations for your OS.
- Back up any existing file that isn't already a link into this repo
  (renamed with a timestamp suffix) before linking — nothing is silently
  overwritten.
- Install VS Code extensions listed in `vscode/extensions.txt`
  (skip with `-SkipExtensions` / `--skip-extensions`).

### Windows symlink permissions

Creating symlinks on Windows requires either **Developer Mode** enabled
(Settings > Privacy & security > For developers) or running `install.ps1`
from an elevated (Run as Administrator) shell. If neither is available the
script reports exactly which links failed, rather than silently falling
back to copying files.

## Moving stray repos into `~/repos`

All repos are expected to live under `~/repos`. If you've got repos
scattered elsewhere, `scripts/Move-ReposToRepos.ps1` (Windows) /
`scripts/move-repos-to-repos.sh` (Linux/macOS) will find them and move them
in.

Dry run (default — nothing is moved, just reported):
```powershell
.\scripts\Move-ReposToRepos.ps1
```
```bash
./scripts/move-repos-to-repos.sh
```

Actually move them:
```powershell
.\scripts\Move-ReposToRepos.ps1 -Apply
```
```bash
./scripts/move-repos-to-repos.sh --apply
```

Name collisions (two repos that would land on the same `~/repos/<name>`)
are always skipped and reported, never overwritten.
