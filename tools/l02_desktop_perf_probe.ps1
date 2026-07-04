param(
    [int]$Frames = 180,
    [int]$ActiveFrames = 240,
    [int]$MemorySeconds = 600,
    [string]$Out = ".tmp/l02_baseline/desktop_report.json"
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
    throw "Godot was not found. Run tools/install_godot.ps1 or set GODOT_BIN."
}

$outPath = Join-Path $root $Out
$outDir = Split-Path -Parent $outPath
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$logPath = [System.IO.Path]::ChangeExtension($outPath, ".log")
if (Test-Path -LiteralPath $outPath) { Remove-Item -LiteralPath $outPath -Force }
if (Test-Path -LiteralPath $logPath) { Remove-Item -LiteralPath $logPath -Force }

$godot = Resolve-Godot
$args = @(
    "--path", $root,
    "--",
    "--bth-perf-telemetry",
    "--bth-perf-plan=l02",
    "--bth-perf-auto-quit",
    "--bth-perf-frames=$Frames",
    "--bth-perf-active-frames=$ActiveFrames",
    "--bth-perf-memory-seconds=$MemorySeconds"
)

Write-Host "Running L0.2 desktop telemetry with: $godot"
$output = & $godot @args 2>&1
$exitCode = $LASTEXITCODE
$output | Set-Content -LiteralPath $logPath -Encoding utf8
if ($exitCode -ne 0) {
    throw "Godot desktop telemetry exited with code $exitCode. Log: $logPath"
}

$reportLine = $output | Where-Object { [string]$_ -like "BTH_PERF_REPORT *" } | Select-Object -Last 1
if (-not $reportLine) {
    throw "No BTH_PERF_REPORT line was emitted. Log: $logPath"
}
$json = ([string]$reportLine).Substring("BTH_PERF_REPORT ".Length)
$json | Set-Content -LiteralPath $outPath -Encoding utf8
Write-Host "L0.2 desktop telemetry report written to $outPath"
Write-Host "Log: $logPath"
