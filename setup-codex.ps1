#requires -Version 5.1
<#
.SYNOPSIS
    Installs the claude-conductor System layer for OpenAI Codex (CLI) and fills in the
    machine-specific path tokens automatically. (For Claude Code use setup.ps1.)

.DESCRIPTION
    Copies (tokens {{AGENT_HOME}} / {{MEMORY_DIR}} / {{SKILLS_DIR}} filled with your real
    paths, forward slashes):

      AGENTS.md                      -> $CODEX_HOME\AGENTS.md         (global instructions)
      MEMORY_SCHEME.md, docs/, templates/ -> $CODEX_HOME\...           (AGENTS.md points at them)
      skills/<name>/                 -> $HOME\.agents\skills\<name>\  (Codex user skills dir)
      codex/agents/*.toml            -> $CODEX_HOME\agents\           (planner / reviewer / worker-heavy / worker-light)
      hooks/memory-checkpoint.js,
      hooks/memory-guard.js          -> $CODEX_HOME\hooks\            (memory-extract.js is Claude-only)
      codex/hooks.json               -> $CODEX_HOME\hooks.json        (if one exists: NOT overwritten - see below)
      templates/MEMORY.md.template, SESSION-BOARD.md.template
                                     -> $CODEX_HOME\conductor-memory\ (only if absent, never overwritten)

    It does NOT edit config.toml. It prints the exact [sandbox_workspace_write] snippet
    (your absolute memory path filled in) for you to paste, plus the next steps
    (/hooks -> trust, smoke test in docs/07-codex.md).

    SAFETY (same style as setup.ps1):
      - Prints a dry-run summary and asks before touching anything (-DryRun stops after
        the summary; -Yes skips the prompt).
      - An existing destination file is SKIPPED unless -Force, which backs it up first
        (<file>.bak-YYYYMMDD-HHMMSS).
      - An existing hooks.json is never overwritten (it may hold your other hooks): the
        rendered conductor hooks go to hooks.conductor.json for you to merge.
      - Memory files are never overwritten, not even with -Force.
      - Reads and writes files as UTF-8.

.PARAMETER CodexHome
    Codex config dir. Defaults to $env:CODEX_HOME, else "$env:USERPROFILE\.codex".

.PARAMETER SkillsHome
    User skills dir. Defaults to "$env:USERPROFILE\.agents\skills" (your real home, not CODEX_HOME).

.PARAMETER MemoryDir
    Memory dir. Defaults to "<CodexHome>\conductor-memory". Override only as the fallback when
    the sandbox cannot write there (e.g. "$env:USERPROFILE\agent-memory") - never point it at
    "<CodexHome>\memories", which is Codex's own generated-memory feature.

.PARAMETER Yes
    Skip the confirmation prompt. The dry-run summary is still printed.

.PARAMETER Force
    Back up and overwrite existing destination files (except hooks.json and memory files).

.PARAMETER DryRun
    Print the planned actions and exit without changing anything.

.EXAMPLE
    ./setup-codex.ps1
        Dry-run summary, then prompts before installing.
#>
[CmdletBinding()]
param(
    [string]$CodexHome = $(if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE ".codex" }),
    [string]$SkillsHome = (Join-Path $env:USERPROFILE (Join-Path ".agents" "skills")),
    [string]$MemoryDir = "",
    [switch]$Yes,
    [switch]$Force,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$RepoRoot = $PSScriptRoot
if (-not $RepoRoot) { $RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path }

if (-not $MemoryDir) { $MemoryDir = Join-Path $CodexHome "conductor-memory" }
$HooksJson = Join-Path $CodexHome "hooks.json"
$HooksJsonAlt = Join-Path $CodexHome "hooks.conductor.json"

Write-Host ""
Write-Host "=== claude-conductor setup (Codex) ===" -ForegroundColor Cyan
Write-Host "Repo root   : $RepoRoot"
Write-Host "Codex home  : $CodexHome"
Write-Host "Skills dir  : $SkillsHome"
Write-Host "Memory dir  : $MemoryDir"
Write-Host ""

# Path tokens substituted into every copied text file (forward slashes).
$Tokens = [ordered]@{
    "AGENT_HOME" = ($CodexHome  -replace '\\', '/')
    "MEMORY_DIR" = ($MemoryDir  -replace '\\', '/')
    "SKILLS_DIR" = ($SkillsHome -replace '\\', '/')
}
$TokenExtensions = @(".md", ".js", ".json", ".toml", ".template")
$Stamp = Get-Date -Format "yyyyMMdd-HHmmss"

# --- Plan ------------------------------------------------------------------
$plan = New-Object System.Collections.Generic.List[object]

function Add-Plan {
    param([string]$SrcFile, [string]$DstFile, [string]$Kind = "file")
    $rel = $SrcFile.Substring($RepoRoot.Length).TrimStart('\', '/')
    if (-not (Test-Path -LiteralPath $SrcFile)) {
        $action = "MISSING-IN-REPO"
    }
    elseif ($Kind -eq "seed") {
        $action = if (Test-Path -LiteralPath $DstFile) { "KEEP (memory exists)" } else { "SEED (new)" }
    }
    elseif ($Kind -eq "hooksjson" -and (Test-Path -LiteralPath $DstFile)) {
        $action = "MERGE BY HAND (hooks.json exists) -> hooks.conductor.json"
        $DstFile = $HooksJsonAlt
    }
    elseif (Test-Path -LiteralPath $DstFile) {
        $action = if ($Force) { "OVERWRITE (backup first)" } else { "SKIP (exists)" }
    }
    else {
        $action = "COPY (new)"
    }
    $plan.Add([pscustomobject]@{ Rel = $rel; Action = $action; Src = $SrcFile; Dest = $DstFile; Kind = $Kind })
}

function Add-PlanTree {
    param([string]$SrcDir, [string]$DstDir)
    foreach ($f in (Get-ChildItem -LiteralPath $SrcDir -Recurse -File)) {
        $sub = $f.FullName.Substring($SrcDir.Length).TrimStart('\', '/')
        Add-Plan -SrcFile $f.FullName -DstFile (Join-Path $DstDir $sub)
    }
}

Add-Plan -SrcFile (Join-Path $RepoRoot "AGENTS.md")        -DstFile (Join-Path $CodexHome "AGENTS.md")
Add-Plan -SrcFile (Join-Path $RepoRoot "MEMORY_SCHEME.md") -DstFile (Join-Path $CodexHome "MEMORY_SCHEME.md")
Add-PlanTree -SrcDir (Join-Path $RepoRoot "docs")      -DstDir (Join-Path $CodexHome "docs")
Add-PlanTree -SrcDir (Join-Path $RepoRoot "templates") -DstDir (Join-Path $CodexHome "templates")
Add-PlanTree -SrcDir (Join-Path $RepoRoot "skills")    -DstDir $SkillsHome
Add-PlanTree -SrcDir (Join-Path $RepoRoot (Join-Path "codex" "agents")) -DstDir (Join-Path $CodexHome "agents")
foreach ($h in @("memory-checkpoint.js", "memory-guard.js")) {
    Add-Plan -SrcFile (Join-Path $RepoRoot (Join-Path "hooks" $h)) -DstFile (Join-Path $CodexHome (Join-Path "hooks" $h))
}
Add-Plan -SrcFile (Join-Path $RepoRoot (Join-Path "codex" "hooks.json")) -DstFile $HooksJson -Kind "hooksjson"
Add-Plan -SrcFile (Join-Path $RepoRoot (Join-Path "templates" "MEMORY.md.template"))        -DstFile (Join-Path $MemoryDir "MEMORY.md")        -Kind "seed"
Add-Plan -SrcFile (Join-Path $RepoRoot (Join-Path "templates" "SESSION-BOARD.md.template")) -DstFile (Join-Path $MemoryDir "SESSION-BOARD.md") -Kind "seed"

Write-Host "Planned actions (dry run):" -ForegroundColor Yellow
$plan | Format-Table -AutoSize Rel, Action, Dest | Out-String -Width 400 | Write-Host

$missing = @($plan | Where-Object { $_.Action -eq "MISSING-IN-REPO" })
$skips   = @($plan | Where-Object { $_.Action -eq "SKIP (exists)" })
if ($missing.Count -gt 0) {
    Write-Host "WARNING: missing in the repo, will be skipped:" -ForegroundColor Red
    $missing | ForEach-Object { Write-Host "  - $($_.Rel)" -ForegroundColor Red }
}
if ($skips.Count -gt 0) {
    Write-Host "NOTE: $($skips.Count) file(s) already exist and will be SKIPPED. Re-run with -Force to back up + overwrite." -ForegroundColor Yellow
}
if (Test-Path -LiteralPath (Join-Path $CodexHome "AGENTS.override.md")) {
    Write-Host "WARNING: $CodexHome\AGENTS.override.md exists - Codex reads it INSTEAD of AGENTS.md." -ForegroundColor Red
}
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "WARNING: 'node' is not on PATH - the hooks need Node.js." -ForegroundColor Red
}
Write-Host ""
Write-Host "Path tokens to fill in every copied text file:" -ForegroundColor Yellow
foreach ($k in $Tokens.Keys) { Write-Host ("  {{{{{0}}}}} -> {1}" -f $k, $Tokens[$k]) }
Write-Host ""

if ($DryRun) {
    Write-Host "Dry run only (-DryRun). Nothing was changed." -ForegroundColor Yellow
    exit 0
}

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

# --- Execute -----------------------------------------------------------------
$copied = 0; $skipped = 0; $backedUp = 0; $expanded = 0; $seeded = 0
foreach ($p in $plan) {
    if ($p.Action -eq "MISSING-IN-REPO" -or $p.Action -like "KEEP*") { continue }
    $dst = $p.Dest

    if ($p.Kind -ne "seed" -and (Test-Path -LiteralPath $dst)) {
        if (-not $Force) { $skipped++; continue }
        $backup = "$dst.bak-$Stamp"
        Copy-Item -LiteralPath $dst -Destination $backup -Force
        Write-Host "  backed up: $dst -> $(Split-Path -Leaf $backup)" -ForegroundColor DarkGray
        $backedUp++
    }

    $dstDir = Split-Path -Parent $dst
    if (-not (Test-Path -LiteralPath $dstDir)) { New-Item -ItemType Directory -Path $dstDir -Force | Out-Null }
    Copy-Item -LiteralPath $p.Src -Destination $dst -Force
    if (Expand-Tokens -File $dst) { $expanded++ }
    if ($p.Kind -eq "seed") { $seeded++ } else { $copied++ }
}
if (-not (Test-Path -LiteralPath $MemoryDir)) { New-Item -ItemType Directory -Path $MemoryDir -Force | Out-Null }

Write-Host ""
Write-Host ("Done: {0} copied ({1} with path tokens filled), {2} skipped, {3} backed up, {4} memory seed(s) created." -f $copied, $expanded, $skipped, $backedUp, $seeded) -ForegroundColor Green

# --- Manual steps (config.toml is never edited by this script) ---------------
$TomlPath = $MemoryDir -replace '\\', '\\'
Write-Host ""
Write-Host "NEXT STEPS" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Let Codex write the memory dir. Paste into $CodexHome\config.toml" -ForegroundColor Cyan
Write-Host "   (if a [sandbox_workspace_write] table already exists, add the path to its writable_roots instead):"
Write-Host ""
Write-Host "[sandbox_workspace_write]"
Write-Host ("writable_roots = [""{0}""]" -f $TomlPath)
Write-Host ""
Write-Host "   Applies to the workspace-write sandbox. Per-run alternative: codex --add-dir ""$MemoryDir"""
Write-Host ""
if (@($plan | Where-Object { $_.Kind -eq "hooksjson" -and $_.Dest -eq $HooksJsonAlt }).Count -gt 0) {
    Write-Host "2. MERGE HOOKS: $HooksJson already existed and was left untouched." -ForegroundColor Yellow
    Write-Host "   The conductor hooks were written to $HooksJsonAlt. Copy its SessionStart and"
    Write-Host "   PostToolUse entries into the matching arrays under ""hooks"" in hooks.json, then delete it."
}
else {
    Write-Host "2. Hooks installed at $HooksJson (if your config.toml also has a [hooks] table, keep one place only)."
}
Write-Host ""
Write-Host "3. Open codex in a repo and run /hooks: review and TRUST the conductor hooks"
Write-Host "   (memory-checkpoint SessionStart, memory-guard SessionStart + PostToolUse). Any later edit"
Write-Host "   of hooks.json or a hook script changes its hash = trust it again."
Write-Host "4. Run the smoke test in $CodexHome\docs\07-codex.md (instruction sources, /skills, `$memory-save, /agents)."
Write-Host "5. Fill in your Knowledge layer: Workspace registry + Project mapping in $CodexHome\AGENTS.md,"
Write-Host "   PROJECT_MEMORY_MAP in $CodexHome\hooks\memory-checkpoint.js, project memory in $MemoryDir."
Write-Host ""
