param(
    [int]$SeedCount = 10,
    [string]$SeedPrefix = "FOUNDATION-DETERMINISM",
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
    Write-Warning "Godot was not found, so foundation determinism probe could not run."
    exit 0
}

$consoleGodot = Use-ConsoleGodot $godot
$outputDir = Join-Path $root ".tmp\foundation_determinism_probe"
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
$runA = "res://.tmp/foundation_determinism_probe/run_a.json"
$runB = "res://.tmp/foundation_determinism_probe/run_b.json"
$runAPath = Join-Path $outputDir "run_a.json"
$runBPath = Join-Path $outputDir "run_b.json"

$oldSeedCount = $env:BTH_DETERMINISM_SEED_COUNT
$oldSeedPrefix = $env:BTH_DETERMINISM_SEED_PREFIX
$oldOutput = $env:BTH_DETERMINISM_OUTPUT
try {
    $env:BTH_DETERMINISM_SEED_COUNT = [string]$SeedCount
    $env:BTH_DETERMINISM_SEED_PREFIX = $SeedPrefix

    $env:BTH_DETERMINISM_OUTPUT = $runA
    & $consoleGodot --headless --path $root --script "res://tools/foundation_determinism_probe.gd"
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }

    $env:BTH_DETERMINISM_OUTPUT = $runB
    & $consoleGodot --headless --path $root --script "res://tools/foundation_determinism_probe.gd"
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}
finally {
    $env:BTH_DETERMINISM_SEED_COUNT = $oldSeedCount
    $env:BTH_DETERMINISM_SEED_PREFIX = $oldSeedPrefix
    $env:BTH_DETERMINISM_OUTPUT = $oldOutput
}

$a = Get-Content -Raw -LiteralPath $runAPath | ConvertFrom-Json
$b = Get-Content -Raw -LiteralPath $runBPath | ConvertFrom-Json

if (-not $a.passed -or -not $b.passed) {
    Write-Error "Determinism probe reported failures. run_a passed=$($a.passed), run_b passed=$($b.passed)"
    exit 1
}

if ($a.combined_hash -ne $b.combined_hash) {
    Write-Error "Determinism combined hash mismatch: $($a.combined_hash) != $($b.combined_hash)"
    exit 1
}

for ($runIndex = 0; $runIndex -lt $a.runs.Count; $runIndex++) {
    $runAData = $a.runs[$runIndex]
    $runBData = $b.runs[$runIndex]
    if ($runAData.seed -ne $runBData.seed) {
        Write-Error "Determinism seed mismatch at run $runIndex`: $($runAData.seed) != $($runBData.seed)"
        exit 1
    }
    if ($runAData.checkpoints.Count -ne $runBData.checkpoints.Count) {
        Write-Error "Determinism checkpoint count mismatch for $($runAData.seed)"
        exit 1
    }
    for ($checkpointIndex = 0; $checkpointIndex -lt $runAData.checkpoints.Count; $checkpointIndex++) {
        $checkpointA = $runAData.checkpoints[$checkpointIndex]
        $checkpointB = $runBData.checkpoints[$checkpointIndex]
        if ($checkpointA.label -ne $checkpointB.label -or $checkpointA.hash -ne $checkpointB.hash) {
            Write-Error "Determinism checkpoint mismatch for $($runAData.seed) index $checkpointIndex`: $($checkpointA.label) $($checkpointA.hash) != $($checkpointB.label) $($checkpointB.hash)"
            exit 1
        }
    }
}

Write-Host "Foundation determinism probe passed. Seeds: $SeedCount. Checkpoints: $($a.checkpoint_count). Combined hash: $($a.combined_hash)."
Write-Host "Reports: $runAPath ; $runBPath"
