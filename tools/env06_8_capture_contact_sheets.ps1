param(
    [string]$EvidenceDir = "res://.tmp/env06_8_contact_sheets"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$godot = $null
if ($env:GODOT_BIN -and (Test-Path -LiteralPath $env:GODOT_BIN)) {
    $godot = $env:GODOT_BIN
}
if (-not $godot) {
    $local = Get-ChildItem -LiteralPath (Join-Path $projectRoot ".tools") -Filter "Godot*_console.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($local) {
        $godot = $local.FullName
    }
}
if (-not $godot) {
    $canonicalTools = "D:\Projects\Beat-The-House\.tools"
    if (Test-Path -LiteralPath $canonicalTools) {
        $shared = Get-ChildItem -LiteralPath $canonicalTools -Filter "Godot*_console.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($shared) {
            $godot = $shared.FullName
        }
    }
}
if (-not $godot) {
    $command = Get-Command godot -ErrorAction SilentlyContinue
    if ($command) {
        $godot = $command.Source
    }
}
if (-not $godot) {
    throw "Godot was not found. Set GODOT_BIN or install the project-local Godot runtime."
}

Write-Host "Capturing env06_8 contact sheets with the Windows display driver and OpenGL renderer..."
& $godot `
    --path $projectRoot `
    --display-driver windows `
    --rendering-method gl_compatibility `
    --position 4000,2000 `
    --script res://tools/env06_8_all_scenario_contact_sheet_probe.gd `
    -- "--evidence-dir=$EvidenceDir"
$exitCode = $LASTEXITCODE
if ($exitCode -ne 0) {
    throw "env06_8 contact-sheet capture failed with exit code $exitCode."
}
