param(
    [switch]$RequireGodot,
    [switch]$ManifestOnly,
    [string]$ManifestPath
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$outputDir = Join-Path $root ".tmp\crew_poker_visual_qa"
if ([string]::IsNullOrWhiteSpace($ManifestPath)) {
    $ManifestPath = Join-Path $outputDir "manifest.json"
}

$godotExitCode = 0
if (-not $ManifestOnly) {
    $godot = $env:GODOT_BIN
    if ([string]::IsNullOrWhiteSpace($godot)) {
        $godot = Join-Path $root ".tools\godot-4.6-stable\Godot_v4.6-stable_win64.exe"
    }
    if (-not (Test-Path -LiteralPath $godot)) {
        if ($RequireGodot) {
            throw "Godot executable not found: $godot"
        }
        Write-Warning "Godot was not found, so Crew poker visual capture was skipped."
        exit 0
    }
    $windowedGodot = $godot -replace "_console\.exe$", ".exe"
    if (-not (Test-Path -LiteralPath $windowedGodot)) {
        $windowedGodot = $godot
    }
    # Never allow an old passing manifest to mask an early engine failure.
    if (Test-Path -LiteralPath $ManifestPath) {
        Remove-Item -LiteralPath $ManifestPath -Force
    }
    & $windowedGodot --path $root --script "res://tools/crew_poker_visual_capture.gd"
    $godotExitCode = $LASTEXITCODE
}

if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
    Write-Host "CREW_POKER_VISUAL_CAPTURE_WRAPPER_FAIL manifest missing: $ManifestPath"
    exit 1
}
try {
    $manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
} catch {
    Write-Host "CREW_POKER_VISUAL_CAPTURE_WRAPPER_FAIL manifest unreadable: $($_.Exception.Message)"
    exit 1
}
if ($manifest.passed -ne $true) {
    Write-Host "CREW_POKER_VISUAL_CAPTURE_WRAPPER_FAIL manifest passed=false: $ManifestPath"
    exit 1
}
if ($godotExitCode -ne 0) {
    Write-Host "CREW_POKER_VISUAL_CAPTURE_WRAPPER_FAIL Godot exit=$godotExitCode"
    exit $godotExitCode
}
Write-Host "CREW_POKER_VISUAL_CAPTURE_WRAPPER_PASS manifest=$ManifestPath"
exit 0
