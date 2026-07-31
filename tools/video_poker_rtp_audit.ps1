param(
    [int]$RoundsPerCabinet = 10000
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
$env:BTH_VIDEO_POKER_RTP_ROUNDS = [string][Math]::Max(100, $RoundsPerCabinet)
& $godot --headless --path $root --script "res://tools/video_poker_rtp_audit.gd"
exit $LASTEXITCODE
