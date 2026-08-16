param(
    [switch]$RequireGodot,
    [switch]$ManifestOnly,
    [string]$ManifestPath,
    [ValidateRange(5, 600)]
    [int]$TimeoutSec = 90
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
    # Remove every expected image before launch so a parse/startup failure can
    # never leave later captures (especially 03/04) looking current.
    foreach ($captureFileName in @(
        "01_entry_idle_1280x720.png",
        "02_active_draw_1280x720.png",
        "03_authored_subtle_tell_1280x720.png",
        "04_reduced_motion_static_1280x720.png"
    )) {
        $capturePath = Join-Path $outputDir $captureFileName
        if (Test-Path -LiteralPath $capturePath) {
            Remove-Item -LiteralPath $capturePath -Force
        }
    }
    $arguments = @("--path", "`"$root`"", "--script", "res://tools/crew_poker_visual_capture.gd")
    $godotProcess = Start-Process `
        -FilePath $windowedGodot `
        -ArgumentList $arguments `
        -PassThru `
        -WindowStyle Hidden
    if (-not $godotProcess.WaitForExit($TimeoutSec * 1000)) {
        # Kill only the exact process tree created above. Never sweep by image
        # name: other serialized or editor Godot processes may be legitimate.
        & taskkill.exe /PID $godotProcess.Id /T /F 2>$null | Out-Null
        $terminated = $godotProcess.WaitForExit(10000)
        if (-not $terminated) {
            & taskkill.exe /PID $godotProcess.Id /T /F 2>$null | Out-Null
            $terminated = $godotProcess.WaitForExit(5000)
        }
        if (-not $terminated) {
            Write-Host "CREW_POKER_VISUAL_CAPTURE_WRAPPER_FAIL timeout=${TimeoutSec}s pid=$($godotProcess.Id) spawned process tree could not be terminated"
            exit 1
        }
        Write-Host "CREW_POKER_VISUAL_CAPTURE_WRAPPER_FAIL timeout=${TimeoutSec}s pid=$($godotProcess.Id) spawned process tree terminated"
        exit 1
    }
    $godotExitCode = $godotProcess.ExitCode
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
