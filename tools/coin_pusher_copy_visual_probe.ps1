param(
    [switch]$RequireGodot,
    [string]$Out = "res://.tmp/coin_pusher_copy_visual_probe"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$godot = $env:GODOT_BIN
if (-not $godot) {
    $localGodot = Get-ChildItem -LiteralPath (Join-Path $root ".tools") -Filter "Godot*_console.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $localGodot) {
        $localGodot = Get-ChildItem -LiteralPath (Join-Path $root ".tools") -Filter "Godot*.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    }
    if ($localGodot) { $godot = $localGodot.FullName }
}
if (-not $godot) {
    $command = Get-Command godot -ErrorAction SilentlyContinue
    if ($command) { $godot = $command.Source }
}
if (-not $godot) {
    if ($RequireGodot) { throw "Godot was not found." }
    Write-Warning "Godot was not found; Quarter Falls copy visual probe skipped."
    exit 0
}

if (-not $godot.EndsWith("_console.exe")) {
    $consoleGodot = $godot -replace "\.exe$", "_console.exe"
    if (Test-Path -LiteralPath $consoleGodot) {
        $godot = $consoleGodot
    }
}
# Keep the real renderer, but prefer the console binary so PowerShell waits for
# the capture process and propagates its actual exit status.
& $godot --path $root --script "res://tools/coin_pusher_copy_visual_probe.gd" -- "--out=$Out"
exit $LASTEXITCODE
