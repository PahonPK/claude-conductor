#requires -Version 5.1
<#
.SYNOPSIS
    Installs the claude-conductor "System layer" (Layer 1) into ~/.claude
    and fixes the machine-specific placeholders automatically.

.DESCRIPTION
    Automates the manual steps from the README ("How to adopt it"):

      1. Derives your home-path segment (the "C--Users-<name>" form that Claude
         builds from your home path) from $env:USERPROFILE - nothing is hardcoded.
      2. Copies the System layer (CLAUDE.md, MEMORY_SCHEME.md, settings.json,
         commands/, hooks/, templates/, docs/) into ~/.claude/.
      3. Substitutes <YOUR_HOME> in the copied settings.json and replaces the
         "C--Users-you" placeholder segment in the copied hooks/memory-checkpoint.js
         with your real segment.

    SAFETY:
      - Prints a dry-run summary of every action and asks for confirmation before
        touching anything (skip the prompt with -Yes for non-interactive use).
      - Never overwrites an existing file in ~/.claude without backing it up first
        (to <file>.bak-YYYYMMDD-HHMMSS) - use -Force to allow that, otherwise
        existing files are SKIPPED and reported.
      - Only the System layer is copied. Your Knowledge layer (workspaces/, memory/)
        and secrets are never created or touched here - see README + examples/.

.PARAMETER ClaudeHome
    Target Claude config dir. Defaults to "$env:USERPROFILE\.claude".

.PARAMETER Yes
    Skip the confirmation prompt (assume "yes"). The dry-run summary is still printed.

.PARAMETER Force
    When a destination file already exists, back it up and overwrite it.
    Without -Force, existing destination files are skipped and reported.

.EXAMPLE
    ./setup.ps1
        Dry-run summary, then prompts before copying into ~/.claude.

.EXAMPLE
    ./setup.ps1 -Force -Yes
        Non-interactive: back up + overwrite existing files, no prompt.
#>
[CmdletBinding()]
param(
    [string]$ClaudeHome = (Join-Path $env:USERPROFILE ".claude"),
    [switch]$Yes,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

# --- Repo root = folder this script lives in -------------------------------
$RepoRoot = $PSScriptRoot
if (-not $RepoRoot) { $RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path }

Write-Host ""
Write-Host "=== claude-conductor setup ===" -ForegroundColor Cyan
Write-Host "Repo root   : $RepoRoot"
Write-Host "Claude home : $ClaudeHome"

# --- Derive the home-path segment (C--Users-<name> style) ------------------
# Claude turns a home path like C:\Users\alice into the segment C--Users-alice
# by replacing the drive colon and each path separator with a single dash.
$HomePath = $env:USERPROFILE
if (-not $HomePath) {
    Write-Error "Could not read \$env:USERPROFILE - cannot derive your home segment."
    exit 1
}
# Normalise separators to backslash, then replace ':' and '\' and '/' with '-'.
$HomeSegment = ($HomePath -replace '[:\\/]', '-')
# Collapse any accidental doubles is NOT done: a drive colon+slash naturally
# yields the documented double dash (C: + \ -> "C-" + "-" = "C--").
Write-Host "Home path   : $HomePath"
Write-Host "Home segment: $HomeSegment  (replaces the 'C--Users-you' placeholder)"
Write-Host ""

# --- The System layer (Layer 1) - see README "3-layer model" ---------------
# Each entry is a path relative to the repo root. Directories are copied
# recursively. Anything not listed here (examples/, .env.example, .git, this
# script) is intentionally NOT installed.
$SystemLayer = @(
    "CLAUDE.md",
    "MEMORY_SCHEME.md",
    "settings.json",
    "commands",
    "hooks",
    "templates",
    "docs"
)

# Files in the destination that get placeholder substitution after copy.
$SettingsRel = "settings.json"
$HookRel     = Join-Path "hooks" "memory-checkpoint.js"

$Stamp = Get-Date -Format "yyyyMMdd-HHmmss"

# --- Plan (dry run) --------------------------------------------------------
function Get-PlanForItem {
    param([string]$RelPath)

    $src = Join-Path $RepoRoot $RelPath
    $dst = Join-Path $ClaudeHome $RelPath
    $plan = New-Object System.Collections.Generic.List[object]

    if (-not (Test-Path -LiteralPath $src)) {
        $plan.Add([pscustomobject]@{ Rel = $RelPath; Action = "MISSING-IN-REPO"; Dest = $dst })
        return $plan
    }

    if (Test-Path -LiteralPath $src -PathType Container) {
        # Enumerate files inside the directory so we can report per-file.
        $files = Get-ChildItem -LiteralPath $src -Recurse -File
        foreach ($f in $files) {
            $relFile = $f.FullName.Substring($RepoRoot.Length).TrimStart('\', '/')
            $dstFile = Join-Path $ClaudeHome $relFile
            $plan.Add((New-FilePlan -RelFile $relFile -DstFile $dstFile))
        }
    }
    else {
        $plan.Add((New-FilePlan -RelFile $RelPath -DstFile $dst))
    }
    return $plan
}

function New-FilePlan {
    param([string]$RelFile, [string]$DstFile)

    if (Test-Path -LiteralPath $DstFile) {
        if ($Force) {
            $action = "OVERWRITE (backup first)"
        }
        else {
            $action = "SKIP (exists)"
        }
    }
    else {
        $action = "COPY (new)"
    }
    return [pscustomobject]@{ Rel = $RelFile; Action = $action; Dest = $DstFile }
}

$plan = New-Object System.Collections.Generic.List[object]
foreach ($item in $SystemLayer) {
    foreach ($p in (Get-PlanForItem -RelPath $item)) { $plan.Add($p) }
}

Write-Host "Planned actions (dry run):" -ForegroundColor Yellow
$plan | Sort-Object Rel | Format-Table -AutoSize Rel, Action | Out-String | Write-Host

$missing   = @($plan | Where-Object { $_.Action -eq "MISSING-IN-REPO" })
$skips     = @($plan | Where-Object { $_.Action -eq "SKIP (exists)" })
$overwrite = @($plan | Where-Object { $_.Action -like "OVERWRITE*" })
$news      = @($plan | Where-Object { $_.Action -eq "COPY (new)" })

if ($missing.Count -gt 0) {
    Write-Host "WARNING: these System-layer items are missing in the repo and will be skipped:" -ForegroundColor Red
    $missing | ForEach-Object { Write-Host "  - $($_.Rel)" -ForegroundColor Red }
}
if ($skips.Count -gt 0) {
    Write-Host "NOTE: $($skips.Count) file(s) already exist in $ClaudeHome and will be SKIPPED." -ForegroundColor Yellow
    Write-Host "      Re-run with -Force to back them up and overwrite." -ForegroundColor Yellow
}

Write-Host ""
Write-Host ("After copy, placeholders will be fixed in:") -ForegroundColor Yellow
Write-Host ("  - {0}: <YOUR_HOME> -> {1}" -f $SettingsRel, $HomePath)
Write-Host ("  - {0}: 'C--Users-you' -> '{1}'" -f $HookRel, $HomeSegment)
Write-Host ""

# --- Confirm ---------------------------------------------------------------
if (-not $Yes) {
    $answer = Read-Host "Proceed? Type 'yes' to continue"
    if ($answer -ne "yes") {
        Write-Host "Aborted. Nothing was changed." -ForegroundColor Yellow
        exit 0
    }
}

# --- Execute copy ----------------------------------------------------------
$copied = 0; $skipped = 0; $backedUp = 0
foreach ($p in $plan) {
    if ($p.Action -eq "MISSING-IN-REPO") { continue }

    $relFile = $p.Rel
    $src = Join-Path $RepoRoot $relFile
    $dst = $p.Dest
    $dstDir = Split-Path -Parent $dst

    if (Test-Path -LiteralPath $dst) {
        if (-not $Force) {
            $skipped++
            continue
        }
        $backup = "$dst.bak-$Stamp"
        Copy-Item -LiteralPath $dst -Destination $backup -Force
        Write-Host "  backed up: $relFile -> $(Split-Path -Leaf $backup)" -ForegroundColor DarkGray
        $backedUp++
    }

    if (-not (Test-Path -LiteralPath $dstDir)) {
        New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
    }
    Copy-Item -LiteralPath $src -Destination $dst -Force
    $copied++
}

Write-Host ""
Write-Host ("Copy complete: {0} copied, {1} skipped, {2} backed up." -f $copied, $skipped, $backedUp) -ForegroundColor Green

# --- Substitute placeholders in the copied operational files ---------------
function Set-Placeholder {
    param([string]$DstFile, [string]$Find, [string]$Replace, [string]$Label)

    if (-not (Test-Path -LiteralPath $DstFile)) {
        Write-Host ("  SKIP {0}: not present at destination ({1})" -f $Label, $DstFile) -ForegroundColor Yellow
        return
    }
    $content = Get-Content -LiteralPath $DstFile -Raw
    if ($content -notmatch [regex]::Escape($Find)) {
        Write-Host ("  SKIP {0}: placeholder '{1}' not found (already configured?)" -f $Label, $Find) -ForegroundColor Yellow
        return
    }
    $new = $content.Replace($Find, $Replace)
    # Write back as UTF-8 without BOM so the JS/JSON stay clean.
    [System.IO.File]::WriteAllText($DstFile, $new, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host ("  OK   {0}: '{1}' -> '{2}'" -f $Label, $Find, $Replace) -ForegroundColor Green
}

Write-Host ""
Write-Host "Fixing placeholders:" -ForegroundColor Cyan

# settings.json: <YOUR_HOME> -> real home path.
$dstSettings = Join-Path $ClaudeHome $SettingsRel
Set-Placeholder -DstFile $dstSettings -Find "<YOUR_HOME>" -Replace $HomePath -Label "settings.json"

# hooks/memory-checkpoint.js: C--Users-you -> real home segment.
$dstHook = Join-Path $ClaudeHome $HookRel
Set-Placeholder -DstFile $dstHook -Find "C--Users-you" -Replace $HomeSegment -Label "memory-checkpoint.js"

Write-Host ""
Write-Host "Done. Next steps:" -ForegroundColor Cyan
Write-Host "  1. Fill in your Knowledge layer (workspaces/ + memory/) using templates/ + examples/."
Write-Host "  2. Update the Workspace Registry + Project mapping tables in $ClaudeHome\CLAUDE.md."
Write-Host "  3. Copy .env.example -> .env and fill secrets (never commit it)."
Write-Host "  4. Start a new Claude Code session - the SessionStart hook loads matching memory."
Write-Host ""
