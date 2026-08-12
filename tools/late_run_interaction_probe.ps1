param(
    [switch]$RequireGodot
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

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
        if ($command) { $godot = $command.Source }
    }
}

if (-not $godot) {
    if ($RequireGodot) { throw "Godot was not found. Run tools/install_godot.ps1 or set GODOT_BIN." }
    Write-Warning "Godot was not found, so the late-run interaction probe could not run."
    exit 0
}

if (-not $godot.EndsWith("_console.exe")) {
    $consoleCandidate = $godot -replace "\.exe$", "_console.exe"
    if (Test-Path -LiteralPath $consoleCandidate) { $godot = $consoleCandidate }
}

& $godot --headless --path $root --script "res://tools/late_run_interaction_probe.gd"
exit $LASTEXITCODE
