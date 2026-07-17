param(
    [string]$Report = "res://.tmp/test_reports/audio_adaptive_tempo_probe.json"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$godot = $env:GODOT_BIN
if ([string]::IsNullOrWhiteSpace($godot) -or -not (Test-Path -LiteralPath $godot)) {
    throw "Set GODOT_BIN to the Godot 4.6 console executable."
}
$activeGodot = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like "*Godot*" }
if ($activeGodot) {
    throw "Another Godot process is active; run the adaptive-tempo probe in an isolated gate window."
}
& $godot --headless --path $projectRoot --script res://tools/audio_adaptive_tempo_probe.gd -- "--report=$Report"
exit $LASTEXITCODE
