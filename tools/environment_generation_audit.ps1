<#
.SYNOPSIS
Runs the maintained environment generation and travel audit.

.PARAMETER AuditSurvivalReserve
Enables a tool-only, minimally funded reserve that prevents audit-selected
events and travel settlements from ending a trajectory at zero bankroll and
makes an incomplete requested trajectory fail the audit. The production
generation, travel, and room-finalization paths are unchanged, and every
reserve grant is written to the JSON evidence.

.EXAMPLE
powershell -NoProfile -ExecutionPolicy Bypass -File tools/environment_generation_audit.ps1 -Runs 100 -Visits 6 -SeedPrefix POSTFIX06_2-FRESH100 -AuditSurvivalReserve -RequireGodot
#>
param(
    [int]$Runs = 100,
    [int]$Visits = 6,
    [string]$Output = "res://.tmp/environment_generation_audit/report.json",
    [string]$Report = "res://.tmp/environment_generation_audit/report.md",
    [string]$SeedPrefix = "",
    [string]$ExactSeed = "",
    [switch]$AuditSurvivalReserve,
    [switch]$RequireGodot
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

function Use-ConsoleGodot {
    param([string]$Path)
    if (-not $Path) {
        return $null
    }
    if ($Path.EndsWith("_console.exe")) {
        return $Path
    }
    $candidate = $Path -replace "\.exe$", "_console.exe"
    if (Test-Path -LiteralPath $candidate) {
        return $candidate
    }
    return $Path
}

if ($env:GODOT_BIN) {
    $godot = Use-ConsoleGodot $env:GODOT_BIN
}
else {
    $localGodot = Get-ChildItem -LiteralPath (Join-Path $root ".tools") -Filter "Godot*_console.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $localGodot) {
        $localGodot = Get-ChildItem -LiteralPath (Join-Path $root ".tools") -Filter "Godot*.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    }
    if ($localGodot) {
        $godot = Use-ConsoleGodot $localGodot.FullName
    }
    else {
        $command = Get-Command godot -ErrorAction SilentlyContinue
        if ($command) {
            $godot = Use-ConsoleGodot $command.Source
        }
    }
}

if (-not $godot) {
    if ($RequireGodot) {
        throw "Godot was not found. Run tools/install_godot.ps1 or set GODOT_BIN."
    }
    Write-Warning "Godot was not found, so environment generation audit was skipped."
    exit 0
}

$argsList = @(
    "--runs=$Runs",
    "--visits=$Visits",
    "--output=$Output",
    "--report=$Report"
)
if ($SeedPrefix.Trim().Length -gt 0) {
    $argsList += "--seed-prefix=$SeedPrefix"
}
if ($ExactSeed.Trim().Length -gt 0) {
    $argsList += "--exact-seed=$ExactSeed"
}
if ($AuditSurvivalReserve) {
    $argsList += "--audit-survival-reserve"
}

& $godot --headless --path $root --script "res://tools/environment_generation_audit.gd" -- $argsList
exit $LASTEXITCODE
