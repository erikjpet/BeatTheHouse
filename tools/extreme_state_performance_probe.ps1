param(
    [int]$CollectionSize = 2000,
    [int]$CorruptRunEntryCount = 10000,
    [switch]$RequireGodot
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

function Use-ConsoleGodot {
    param([string]$Path)
    if (-not $Path) { return $null }
    if ($Path.EndsWith("_console.exe")) { return $Path }
    $candidate = $Path -replace "\.exe$", "_console.exe"
    if (Test-Path -LiteralPath $candidate) { return $candidate }
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
        if ($command) { $godot = $command.Source }
    }
}

if (-not $godot) {
    if ($RequireGodot) { throw "Godot was not found. Run tools/install_godot.ps1 or set GODOT_BIN." }
    Write-Warning "Godot was not found, so the extreme-state probe could not run."
    exit 0
}

$oldCollectionSize = $env:BTH_EXTREME_COLLECTION_SIZE
$oldRunEntries = $env:BTH_EXTREME_RUN_ENTRIES
try {
    $env:BTH_EXTREME_COLLECTION_SIZE = [string]$CollectionSize
    $env:BTH_EXTREME_RUN_ENTRIES = [string]$CorruptRunEntryCount
    $consoleGodot = Use-ConsoleGodot $godot
    & $consoleGodot --headless --path $root --script "res://tools/extreme_state_performance_probe.gd"
    exit $LASTEXITCODE
}
finally {
    $env:BTH_EXTREME_COLLECTION_SIZE = $oldCollectionSize
    $env:BTH_EXTREME_RUN_ENTRIES = $oldRunEntries
}
