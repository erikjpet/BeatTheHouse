param(
    [int]$RollsPerBet = 1000000
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$godot = $env:GODOT_BIN
if ([string]::IsNullOrWhiteSpace($godot)) {
    $godot = Join-Path $root ".tools\godot-4.6-stable\Godot_v4.6-stable_win64_console.exe"
}
if (-not (Test-Path -LiteralPath $godot)) {
    throw "Godot console executable not found: $godot"
}
$env:BTH_CRAPS_RTP_ROLLS = [string][Math]::Max(1000000, $RollsPerBet)
& $godot --headless --path $root --script "res://tools/craps_rtp_audit.gd"
exit $LASTEXITCODE
