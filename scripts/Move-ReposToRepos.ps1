<#
.SYNOPSIS
    Finds git repositories scattered outside ~/repos and moves them in.

.DESCRIPTION
    Scans a set of common dev folders for directories containing a .git folder
    and reports where each would move to under ~/repos/<name>. Dry-run by
    default: nothing is moved unless -Apply is passed. Name collisions (two
    repos that would land on the same ~/repos/<name>) are always skipped and
    reported, never overwritten.

.PARAMETER Apply
    Actually move the repos found. Without this switch, only a report is printed.

.PARAMETER SearchPaths
    Folders to scan for stray repos. Defaults to common dev locations.
#>
[CmdletBinding()]
param(
    [switch]$Apply,
    [string[]]$SearchPaths = @(
        (Join-Path $env:USERPROFILE 'Documents'),
        (Join-Path $env:USERPROFILE 'Desktop'),
        'C:\dev',
        'C:\src'
    ),
    [int]$MaxDepth = 4
)

$ErrorActionPreference = 'Stop'
$reposHome = Join-Path $env:USERPROFILE 'repos'
if (-not (Test-Path -LiteralPath $reposHome)) {
    New-Item -ItemType Directory -Path $reposHome -Force | Out-Null
}
$reposHomeFull = (Resolve-Path $reposHome).Path

$found = [ordered]@{}  # resolved repo path -> $true

foreach ($searchPath in $SearchPaths) {
    if (-not (Test-Path -LiteralPath $searchPath)) { continue }

    Get-ChildItem -LiteralPath $searchPath -Directory -Filter '.git' -Recurse -Depth $MaxDepth -Force -ErrorAction SilentlyContinue |
        ForEach-Object {
            $repoDir = (Resolve-Path (Split-Path -Parent $_.FullName)).Path
            if ($repoDir.StartsWith($reposHomeFull, [System.StringComparison]::OrdinalIgnoreCase)) { return }
            $found[$repoDir] = $true
        }
}

if ($found.Count -eq 0) {
    Write-Host "No stray repositories found under: $($SearchPaths -join ', ')"
    return
}

# Group by target folder name to detect collisions
$byName = @{}
foreach ($repoPath in $found.Keys) {
    $name = Split-Path -Leaf $repoPath
    if (-not $byName.ContainsKey($name)) { $byName[$name] = @() }
    $byName[$name] += $repoPath
}

$toMove = @()
$collisions = @()
foreach ($name in $byName.Keys) {
    $paths = $byName[$name]
    if ($paths.Count -gt 1) {
        $collisions += [pscustomobject]@{ Name = $name; Paths = $paths }
    } else {
        $toMove += [pscustomobject]@{ Name = $name; Source = $paths[0]; Target = Join-Path $reposHomeFull $name }
    }
}

Write-Host "=== Repos to move into $reposHomeFull ==="
foreach ($item in $toMove) {
    Write-Host "  $($item.Source)  ->  $($item.Target)"
}

if ($collisions.Count -gt 0) {
    Write-Host ""
    Write-Warning "Name collisions (skipped, resolve manually):"
    foreach ($c in $collisions) {
        Write-Warning "  $($c.Name):"
        $c.Paths | ForEach-Object { Write-Warning "    $_" }
    }
}

if (-not $Apply) {
    Write-Host ""
    Write-Host "Dry run only. Re-run with -Apply to actually move these repos."
    return
}

foreach ($item in $toMove) {
    if (Test-Path -LiteralPath $item.Target) {
        Write-Warning "Skipping $($item.Name): target already exists at $($item.Target)"
        continue
    }
    Move-Item -LiteralPath $item.Source -Destination $item.Target
    Write-Host "Moved $($item.Source) -> $($item.Target)"
}
