param(
    [int]$Iterations = 10000,
    [int]$WarmupIterations = 500,
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
    Write-Warning "Godot was not found, so allocation churn probe could not run."
    exit 0
}

$oldIterations = $env:BTH_ALLOC_PROBE_ITERS
$oldWarmup = $env:BTH_ALLOC_PROBE_WARMUP
try {
    $env:BTH_ALLOC_PROBE_ITERS = [string]$Iterations
    $env:BTH_ALLOC_PROBE_WARMUP = [string]$WarmupIterations
    $consoleGodot = Use-ConsoleGodot $godot
    & $consoleGodot --headless --path $root --script "res://tools/allocation_churn_probe.gd"
    exit $LASTEXITCODE
}
finally {
    $env:BTH_ALLOC_PROBE_ITERS = $oldIterations
    $env:BTH_ALLOC_PROBE_WARMUP = $oldWarmup
}
