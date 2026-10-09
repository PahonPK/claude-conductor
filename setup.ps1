#requires -Version 5.1
<#
.SYNOPSIS
    Installs the claude-conductor "System layer" (Layer 1) for Claude Code into ~/.claude
    and fills in the machine-specific path tokens automatically.
    (For OpenAI Codex use setup-codex.ps1.)

.DESCRIPTION
    Automates the manual steps from the README ("How to adopt it"):

      1. Derives your home-path segment (the "C--Users-<name>" form that Claude
         builds from your home path) from $env:USERPROFILE - nothing is hardcoded.
         Memory dir = <ClaudeHome>\projects\<segment>\memory (Claude's auto-memory dir
         for your home folder).
      2. Copies the System layer (AGENTS.md, CLAUDE.md, MEMORY_SCHEME.md, settings.json,
         hooks/, skills/, templates/, docs/) into ~/.claude/. CLAUDE.md imports AGENTS.md
         with "@AGENTS.md", so both must sit side by side.
      3. Replaces the path tokens {{AGENT_HOME}}, {{MEMORY_DIR}} and {{SKILLS_DIR}} in every
         copied text file with your real paths (forward slashes, which work in Node,
         PowerShell and Git Bash alike).
      4. Seeds MEMORY.md and SESSION-BOARD.md into the memory dir - ONLY if absent
         (an existing memory file is never touched, not even with -Force).

    SAFETY:
      - Prints a dry-run summary of every action and asks for confirmation before
        touching anything (-DryRun stops after the summary; -Yes skips the prompt).
      - Never overwrites an existing file in ~/.claude without backing it up first
        (to <file>.bak-YYYYMMDD-HHMMSS) - use -Force to allow that, otherwise
        existing files are SKIPPED and reported.
      - Only the System layer is copied. Your Knowledge layer (workspaces/, project
        memory) and secrets are never created or touched beyond the two seed files.
      - Reads and writes files as UTF-8 (Windows PowerShell 5.1 Get-Content would
        decode BOM-less UTF-8 as the ANSI code page and corrupt non-ASCII text).

.PARAMETER ClaudeHome
    Target Claude config dir. Defaults to "$env:USERPROFILE\.claude".

.PARAMETER Yes
    Skip the confirmation prompt (assume "yes"). The dry-run summary is still printed.

.PARAMETER Force
    When a destination file already exists, back it up and overwrite it.
    Without -Force, existing destination files are skipped and reported.

.PARAMETER DryRun
    Print the planned actions and exit without changing anything.

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
    [switch]$Force,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# --- Repo root = folder this script lives in -------------------------------
$RepoRoot = $PSScriptRoot
if (-not $RepoRoot) { $RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path }

Write-Host ""
Write-Host "=== claude-conductor setup (Claude Code) ===" -ForegroundColor Cyan
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
# Replace ':' and '\' and '/' with '-'. A drive colon + backslash naturally
# yields the documented double dash (C: + \ -> "C-" + "-" = "C--").
$HomeSegment = ($HomePath -replace '[:\\/]', '-')
$MemoryDir   = Join-Path $ClaudeHome (Join-Path "projects" (Join-Path $HomeSegment "memory"))
$SkillsDir   = Join-Path $ClaudeHome "skills"
Write-Host "Home segment: $HomeSegment"
Write-Host "Memory dir  : $MemoryDir"
Write-Host ""

# Path tokens substituted into every copied text file (forward slashes).
$Tokens = [ordered]@{
    "AGENT_HOME" = ($ClaudeHome -replace '\\', '/')
    "MEMORY_DIR" = ($MemoryDir  -replace '\\', '/')
    "SKILLS_DIR" = ($SkillsDir  -replace '\\', '/')
}
$TokenExtensions = @(".md", ".js", ".json", ".toml", ".template")

# --- The System layer (Layer 1) - see README "3-layer model" ---------------
# Each entry is a path relative to the repo root. Directories are copied
# recursively. Anything not listed here (codex/, examples/, .env.example, .git,
# the setup scripts) is intentionally NOT installed.
$SystemLayer = @(
    "AGENTS.md",
    "CLAUDE.md",
    "MEMORY_SCHEME.md",
    "settings.json",
    "hooks",
    "skills",
    "templates",
    "docs"
)

# Memory seeds: template (repo-relative) -> file name in the memory dir.
$Seeds = [ordered]@{
    (Join-Path "templates" "MEMORY.md.template")        = "MEMORY.md"
    (Join-Path "templates" "SESSION-BOARD.md.template") = "SESSION-BOARD.md"
}

$Stamp = Get-Date -Format "yyyyMMdd-HHmmss"

# --- Plan (dry run) --------------------------------------------------------
function New-FilePlan {
    param([string]$RelFile, [string]$SrcFile, [string]$DstFile)

    if (Test-Path -LiteralPath $DstFile) {
        if ($Force) { $action = "OVERWRITE (backup first)" } else { $action = "SKIP (exists)" }
    }
    else {
        $action = "COPY (new)"
    }
    return [pscustomobject]@{ Rel = $RelFile; Action = $action; Src = $SrcFile; Dest = $DstFile }
}

function Get-PlanForItem {
    param([string]$RelPath)

    $src = Join-Path $RepoRoot $RelPath
    $dst = Join-Path $ClaudeHome $RelPath
    $plan = New-Object System.Collections.Generic.List[object]

    if (-not (Test-Path -LiteralPath $src)) {
        $plan.Add([pscustomobject]@{ Rel = $RelPath; Action = "MISSING-IN-REPO"; Src = $src; Dest = $dst })
        return $plan
    }

    if (Test-Path -LiteralPath $src -PathType Container) {
        foreach ($f in (Get-ChildItem -LiteralPath $src -Recurse -File)) {
            $relFile = $f.FullName.Substring($RepoRoot.Length).TrimStart('\', '/')
            $plan.Add((New-FilePlan -RelFile $relFile -SrcFile $f.FullName -DstFile (Join-Path $ClaudeHome $relFile)))
        }
    }
    else {
        $plan.Add((New-FilePlan -RelFile $RelPath -SrcFile $src -DstFile $dst))
    }
    return $plan
}

$plan = New-Object System.Collections.Generic.List[object]
foreach ($item in $SystemLayer) {
    foreach ($p in (Get-PlanForItem -RelPath $item)) { $plan.Add($p) }
}

Write-Host "Planned actions (dry run):" -ForegroundColor Yellow
$plan | Sort-Object Rel | Format-Table -AutoSize Rel, Action | Out-String | Write-Host

$missing = @($plan | Where-Object { $_.Action -eq "MISSING-IN-REPO" })
$skips   = @($plan | Where-Object { $_.Action -eq "SKIP (exists)" })

if ($missing.Count -gt 0) {
    Write-Host "WARNING: these System-layer items are missing in the repo and will be skipped:" -ForegroundColor Red
    $missing | ForEach-Object { Write-Host "  - $($_.Rel)" -ForegroundColor Red }
}
if ($skips.Count -gt 0) {
    Write-Host "NOTE: $($skips.Count) file(s) already exist in $ClaudeHome and will be SKIPPED." -ForegroundColor Yellow
    Write-Host "      Re-run with -Force to back them up and overwrite." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Path tokens to fill in every copied text file:" -ForegroundColor Yellow
foreach ($k in $Tokens.Keys) { Write-Host ("  {{{{{0}}}}} -> {1}" -f $k, $Tokens[$k]) }
Write-Host "Memory seeds (only if absent):" -ForegroundColor Yellow
foreach ($s in $Seeds.Values) {
    $state = if (Test-Path -LiteralPath (Join-Path $MemoryDir $s)) { "exists - keep" } else { "create" }
    Write-Host ("  {0} : {1}" -f (Join-Path $MemoryDir $s), $state)
}
Write-Host ""

if ($DryRun) {
    Write-Host "Dry run only (-DryRun). Nothing was changed." -ForegroundColor Yellow
    exit 0
}

# --- Confirm ---------------------------------------------------------------
if (-not $Yes) {
    $answer = Read-Host "Proceed? Type 'yes' to continue"
    if ($answer -ne "yes") {
        Write-Host "Aborted. Nothing was changed." -ForegroundColor Yellow
        exit 0
    }
}

# --- Token substitution (UTF-8 in, UTF-8 without BOM out) -------------------
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
function Expand-Tokens {
    param([string]$File)
    if ($TokenExtensions -notcontains [System.IO.Path]::GetExtension($File).ToLowerInvariant()) { return $false }
    $text = [System.IO.File]::ReadAllText($File, $Utf8NoBom)
    $new = $text
    foreach ($k in $Tokens.Keys) { $new = $new.Replace("{{$k}}", $Tokens[$k]) }
    if ($new -eq $text) { return $false }
    [System.IO.File]::WriteAllText($File, $new, $Utf8NoBom)
    return $true
}

# --- Execute copy ----------------------------------------------------------
$copied = 0; $skipped = 0; $backedUp = 0; $expanded = 0
foreach ($p in $plan) {
    if ($p.Action -eq "MISSING-IN-REPO") { continue }

    $dst = $p.Dest
    $dstDir = Split-Path -Parent $dst

    if (Test-Path -LiteralPath $dst) {
        if (-not $Force) {
            $skipped++
            continue
        }
        $backup = "$dst.bak-$Stamp"
        Copy-Item -LiteralPath $dst -Destination $backup -Force
        Write-Host "  backed up: $($p.Rel) -> $(Split-Path -Leaf $backup)" -ForegroundColor DarkGray
        $backedUp++
    }

    if (-not (Test-Path -LiteralPath $dstDir)) {
        New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
    }
    Copy-Item -LiteralPath $p.Src -Destination $dst -Force
    $copied++
    if (Expand-Tokens -File $dst) { $expanded++ }
}

Write-Host ""
Write-Host ("Copy complete: {0} copied ({1} with path tokens filled), {2} skipped, {3} backed up." -f $copied, $expanded, $skipped, $backedUp) -ForegroundColor Green

# --- Seed the memory dir (never overwrite) ----------------------------------
if (-not (Test-Path -LiteralPath $MemoryDir)) {
    New-Item -ItemType Directory -Path $MemoryDir -Force | Out-Null
}
foreach ($rel in $Seeds.Keys) {
    $dst = Join-Path $MemoryDir $Seeds[$rel]
    if (Test-Path -LiteralPath $dst) {
        Write-Host "  KEEP $dst (exists)" -ForegroundColor DarkGray
        continue
    }
    Copy-Item -LiteralPath (Join-Path $RepoRoot $rel) -Destination $dst
    Expand-Tokens -File $dst | Out-Null
    Write-Host "  SEED $dst" -ForegroundColor Green
}

Write-Host ""
Write-Host "Done. Next steps:" -ForegroundColor Cyan
Write-Host "  1. Fill in your Knowledge layer (workspaces/ + memory files) using templates/ + examples/."
Write-Host "  2. Update the Workspace registry + Project mapping tables in $ClaudeHome\AGENTS.md,"
Write-Host "     and PROJECT_MEMORY_MAP in $ClaudeHome\hooks\memory-checkpoint.js to match."
Write-Host "  3. Copy .env.example -> .env and fill secrets (never commit it)."
Write-Host "  4. Start a new Claude Code session - the SessionStart hook loads matching memory."
Write-Host ""
