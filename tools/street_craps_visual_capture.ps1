param([switch]$RequireGodot)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$godot = $env:GODOT_BIN
if ([string]::IsNullOrWhiteSpace($godot)) {
    $godot = Join-Path $root ".tools\godot-4.6-stable\Godot_v4.6-stable_win64.exe"
}
if (-not (Test-Path -LiteralPath $godot)) {
    if ($RequireGodot) {
        throw "Godot executable not found: $godot"
    }
    Write-Warning "Godot was not found, so Street Craps visual capture was skipped."
    exit 0
}
$windowedGodot = $godot -replace "_console\.exe$", ".exe"
if (-not (Test-Path -LiteralPath $windowedGodot)) {
    $windowedGodot = $godot
}
& $windowedGodot --path $root --script "res://tools/street_craps_visual_capture.gd"
exit $LASTEXITCODE
