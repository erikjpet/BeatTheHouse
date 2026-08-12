param([switch]$RequireGodot)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$godot = $env:GODOT_BIN
if (-not $godot) {
    $localGodot = Get-ChildItem -LiteralPath (Join-Path $root ".tools") -Filter "Godot*_console.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($localGodot) { $godot = $localGodot.FullName }
}
if (-not $godot) {
    $command = Get-Command godot -ErrorAction SilentlyContinue
    if ($command) { $godot = $command.Source }
}
if (-not $godot) {
    if ($RequireGodot) { throw "Godot was not found." }
    Write-Warning "Godot was not found; probe skipped."
    exit 0
}

& $godot --headless --path $root --script "res://tools/heat_feedback_probe.gd"
exit $LASTEXITCODE
