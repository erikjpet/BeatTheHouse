param(
    [int]$SimMinutes = 180,
    [int]$ActionsPerSample = 28,
    [string]$SeedPrefix = "FOUNDATION-SOAK",
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
    $godot = $env:GODOT_BIN
}
else {
    $localGodot = Get-ChildItem -LiteralPath (Join-Path $root ".tools") -Filter "Godot*_console.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $localGodot) {
        $localGodot = Get-ChildItem -LiteralPath (Join-Path $root ".tools") -Filter "Godot*.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    }
    if ($localGodot) {
        $godot = $localGodot.FullName
    }
    else {
        $command = Get-Command godot -ErrorAction SilentlyContinue
        if ($command) {
            $godot = $command.Source
        }
    }
}

if (-not $godot) {
    if ($RequireGodot) {
        throw "Godot was not found. Run tools/install_godot.ps1 or set GODOT_BIN."
    }
    Write-Warning "Godot was not found, so foundation soak probe could not run."
    exit 0
}

$oldMinutes = $env:BTH_SOAK_MINUTES
$oldActions = $env:BTH_SOAK_ACTIONS_PER_SAMPLE
$oldSeedPrefix = $env:BTH_SOAK_SEED_PREFIX
$oldDeveloperPlacementPath = $env:BTH_DEVELOPER_PLACEMENT_PATH
$oldProjectPlacementPath = $env:BTH_PROJECT_PLACEMENT_PATH
try {
    $env:BTH_SOAK_MINUTES = [string]$SimMinutes
    $env:BTH_SOAK_ACTIONS_PER_SAMPLE = [string]$ActionsPerSample
    $env:BTH_SOAK_SEED_PREFIX = $SeedPrefix
    # The release soak qualifies repository placement authority, not the
    # operator's live placement-mode session or an inherited project override.
    $env:BTH_DEVELOPER_PLACEMENT_PATH = Join-Path $root (".tmp\foundation_soak_isolated_developer_placements_{0}.json" -f $PID)
    $env:BTH_PROJECT_PLACEMENT_PATH = ''
    $consoleGodot = Use-ConsoleGodot $godot
    & $consoleGodot --headless --path $root --script "res://tools/foundation_soak_probe.gd"
    exit $LASTEXITCODE
}
finally {
    $env:BTH_SOAK_MINUTES = $oldMinutes
    $env:BTH_SOAK_ACTIONS_PER_SAMPLE = $oldActions
    $env:BTH_SOAK_SEED_PREFIX = $oldSeedPrefix
    $env:BTH_DEVELOPER_PLACEMENT_PATH = $oldDeveloperPlacementPath
    $env:BTH_PROJECT_PLACEMENT_PATH = $oldProjectPlacementPath
}
