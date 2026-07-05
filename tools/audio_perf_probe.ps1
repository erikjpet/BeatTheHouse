param(
    [int]$Iterations = 12000,
    [int]$WarmupIterations = 600,
    [string]$Out = ".tmp/audio_perf_probe/report.json",
    [switch]$RequireGodot
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

function Resolve-Godot {
    if ($env:GODOT_BIN) { return $env:GODOT_BIN }
    $toolsDir = Join-Path $root ".tools"
    $local = Get-ChildItem -LiteralPath $toolsDir -Filter "Godot*_console.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $local) {
        $local = Get-ChildItem -LiteralPath $toolsDir -Filter "Godot*.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    }
    if ($local) { return $local.FullName }
    $cmd = Get-Command godot -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    if ($RequireGodot) {
        throw "Godot was not found. Run tools/install_godot.ps1 or set GODOT_BIN."
    }
    return $null
}

$godot = Resolve-Godot
if (-not $godot) {
    Write-Warning "Godot was not found, so audio performance probe could not run."
    exit 0
}

$outPath = Join-Path $root $Out
$outDir = Split-Path -Parent $outPath
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
if (Test-Path -LiteralPath $outPath) { Remove-Item -LiteralPath $outPath -Force }

$oldIterations = $env:BTH_AUDIO_PERF_ITERATIONS
$oldWarmup = $env:BTH_AUDIO_PERF_WARMUP
$oldOut = $env:BTH_AUDIO_PERF_OUT
try {
    $env:BTH_AUDIO_PERF_ITERATIONS = [string]$Iterations
    $env:BTH_AUDIO_PERF_WARMUP = [string]$WarmupIterations
    $env:BTH_AUDIO_PERF_OUT = $Out
    & $godot --headless --path $root --script "res://tools/audio_perf_probe.gd"
    exit $LASTEXITCODE
}
finally {
    $env:BTH_AUDIO_PERF_ITERATIONS = $oldIterations
    $env:BTH_AUDIO_PERF_WARMUP = $oldWarmup
    $env:BTH_AUDIO_PERF_OUT = $oldOut
}
