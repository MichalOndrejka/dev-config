<#
.SYNOPSIS
    Symlinks this repo's configs into their real locations on Windows.

.DESCRIPTION
    Creates symbolic links so that editing the live config file (e.g. VS Code's
    settings.json) edits the file inside this repo directly. Existing files that
    aren't already links into this repo are backed up (renamed with a timestamp
    suffix) rather than overwritten.

    Creating symbolic links on Windows requires either Developer Mode to be
    enabled, or running this script from an elevated (Run as Administrator)
    shell. If neither is available, the script reports exactly which links
    failed and why, instead of silently falling back to copying files.

.PARAMETER SkipExtensions
    Skip installing VS Code extensions from vscode/extensions.txt.
#>
[CmdletBinding()]
param(
    [switch]$SkipExtensions
)

$ErrorActionPreference = 'Stop'
$repoRoot = $PSScriptRoot

$links = [ordered]@{
    'Claude Code CLAUDE.md'    = @{ Source = '.claude/CLAUDE.md';     Target = Join-Path $env:USERPROFILE '.claude/CLAUDE.md' }
    'Claude Code settings'     = @{ Source = '.claude/settings.json'; Target = Join-Path $env:USERPROFILE '.claude/settings.json' }
    'VS Code settings'         = @{ Source = 'vscode/settings.json'; Target = Join-Path $env:APPDATA 'Code/User/settings.json' }
    'VS Code MCP config'       = @{ Source = 'vscode/mcp.json';      Target = Join-Path $env:APPDATA 'Code/User/mcp.json' }
    'PowerShell profile'       = @{ Source = 'shell/powershell/Microsoft.PowerShell_profile.ps1'; Target = $PROFILE }
    'bash profile (Git Bash)'  = @{ Source = 'shell/bash/.bashrc'; Target = Join-Path $env:USERPROFILE '.bashrc' }
    'zsh profile'              = @{ Source = 'shell/zsh/.zshrc';   Target = Join-Path $env:USERPROFILE '.zshrc' }
}

$results = @{ Linked = @(); AlreadyLinked = @(); BackedUp = @(); Failed = @() }

function Install-DevConfigSymlink {
    param([string]$Name, [string]$SourceRelative, [string]$TargetPath)

    $sourcePath = Join-Path $repoRoot $SourceRelative
    if (-not (Test-Path -LiteralPath $sourcePath)) {
        Write-Warning "[$Name] source missing: $sourcePath (skipped)"
        $results.Failed += $Name
        return
    }

    $targetParent = Split-Path -Parent $TargetPath
    if (-not (Test-Path -LiteralPath $targetParent)) {
        New-Item -ItemType Directory -Path $targetParent -Force | Out-Null
    }

    if (Test-Path -LiteralPath $TargetPath) {
        $existing = Get-Item -LiteralPath $TargetPath -Force
        $isOurLink = $existing.LinkType -eq 'SymbolicLink' -and
            ($existing.Target | ForEach-Object { $_ -replace '/', '\' }) -contains ($sourcePath -replace '/', '\')

        if ($isOurLink) {
            $results.AlreadyLinked += $Name
            return
        }

        $backupPath = "$TargetPath.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Move-Item -LiteralPath $TargetPath -Destination $backupPath -Force
        $results.BackedUp += "$Name -> $backupPath"
    }

    try {
        New-Item -ItemType SymbolicLink -Path $TargetPath -Target $sourcePath -Force | Out-Null
        $results.Linked += $Name
    } catch {
        Write-Warning "[$Name] failed to create symlink: $($_.Exception.Message)"
        Write-Warning "  Enable Developer Mode (Settings > Privacy & security > For developers) or re-run this script as Administrator."
        $results.Failed += $Name
    }
}

foreach ($name in $links.Keys) {
    Install-DevConfigSymlink -Name $name -SourceRelative $links[$name].Source -TargetPath $links[$name].Target
}

if (-not $SkipExtensions) {
    $extensionsFile = Join-Path $repoRoot 'vscode/extensions.txt'
    if (Get-Command code -ErrorAction SilentlyContinue) {
        $extensionIds = Get-Content -LiteralPath $extensionsFile |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ -and -not $_.StartsWith('#') }

        foreach ($id in $extensionIds) {
            Write-Host "Installing VS Code extension: $id"
            & code --install-extension $id | Out-Null
        }
    } else {
        Write-Warning "'code' CLI not found on PATH; skipping VS Code extension install."
    }
}

Write-Host ""
Write-Host "=== dev-config install summary ==="
Write-Host "Linked:        $($results.Linked -join ', ')"
Write-Host "Already linked: $($results.AlreadyLinked -join ', ')"
if ($results.BackedUp.Count -gt 0) { Write-Host "Backed up:     $($results.BackedUp -join '; ')" }
if ($results.Failed.Count -gt 0)   { Write-Warning "Failed:        $($results.Failed -join ', ')" }
