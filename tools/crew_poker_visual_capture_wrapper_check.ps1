$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$wrapper = Join-Path $PSScriptRoot "crew_poker_visual_capture.ps1"
$capture = Join-Path $PSScriptRoot "crew_poker_visual_capture.gd"
$seedAudit = Join-Path $PSScriptRoot "crew_poker_visual_seed_audit.gd"
$contractDir = Join-Path $root ".tmp\crew_poker_wrapper_contract"
$manifestPath = Join-Path $contractDir "manifest.json"
New-Item -ItemType Directory -Path $contractDir -Force | Out-Null

$wrapperSource = Get-Content -LiteralPath $wrapper -Raw
$requiredProcessControls = @(
    "Start-Process",
    "-PassThru",
    "-WindowStyle Hidden",
    ".WaitForExit(",
    "taskkill.exe /PID `$godotProcess.Id /T /F"
)
foreach ($requiredControl in $requiredProcessControls) {
    if (-not $wrapperSource.Contains($requiredControl)) {
        throw "Crew poker wrapper is missing owned-process control: $requiredControl"
    }
}
if ($wrapperSource -match '&\s+\$windowedGodot') {
    throw "Crew poker wrapper must not invoke the windowed executable without an exact process handle."
}

$captureSource = Get-Content -LiteralPath $capture -Raw
$seedAuditSource = Get-Content -LiteralPath $seedAudit -Raw
foreach ($requiredCaptureControl in @(
    "CrewPokerVisualSeedAuditScript.audit_pinned_seed",
    'app.call("start_foundation_run", FIXTURE_SEED, {}, false)',
    '"production_action_before"',
    '"production_action_after"',
    '"natural_tell_surface_read"',
    '"capture_surface_state_read"',
    '"capture_surface_view_read"',
    '"capture_surface_image_read"',
    "authored_tell_state",
    "authored_tell_observation",
    "fixture_rng_untouched",
    'int(table.get("hand_number", -1)) == 0'
)) {
    if (-not $captureSource.Contains($requiredCaptureControl)) {
        throw "Crew poker capture is missing bounded natural-tell control: $requiredCaptureControl"
    }
}
if ($captureSource.Contains('var tell_state := canvas.call("realtime_surface_state")') -or
        $captureSource.Contains('var reduced_state := (canvas.call("realtime_surface_state")')) {
    throw "Crew poker capture must reuse the already-audited authored-tell state for captures 03 and 04."
}
if ($captureSource.Contains("run_state.save_rng(") -or
        $captureSource.Contains("_advance_to_authored_observation") -or
        $captureSource -match 'run_state\.rng_(seed|state)\s*=') {
    throw "Crew poker capture must preserve the audited live RNG and stay within one hand."
}
if ([regex]::Matches($captureSource, '_handle_module_surface_action').Count -ne 1) {
    throw "Every Crew poker production action must route through the one before/after diagnostic helper."
}
foreach ($requiredAuditControl in @(
    'FIXTURE_SEED := "CREW-POKER-PUNCHLINE-VISUAL-00"',
    "audit_pinned_seed(library: ContentLibrary)",
    "source_run.start_new(seed_text)",
    "RunGeneratorScript.new(library)",
    "generator.next_environment(source_run)",
    'RESIDENTS: Array[String] = ["crew_mags", "crew_rook"]',
    'INPUT_SEQUENCE: Array[String] = ["poker_deal", "poker_call"]'
)) {
    if (-not $seedAuditSource.Contains($requiredAuditControl)) {
        throw "Crew poker pure seed audit is missing production-authentic control: $requiredAuditControl"
    }
}
if (($captureSource + $seedAuditSource) -match '\["beat"\]\s*=') {
    throw "Crew poker visual evidence must never inject a table beat."
}
foreach ($staleCaptureName in @(
    "03_authored_subtle_tell_1280x720.png",
    "04_reduced_motion_static_1280x720.png"
)) {
    if (-not $wrapperSource.Contains($staleCaptureName) -or -not $captureSource.Contains($staleCaptureName)) {
        throw "Crew poker harness does not remove stale capture evidence: $staleCaptureName"
    }
}

if (Test-Path -LiteralPath $manifestPath) {
    Remove-Item -LiteralPath $manifestPath -Force
}
& powershell -NoProfile -ExecutionPolicy Bypass -File $wrapper -ManifestOnly -ManifestPath $manifestPath
if ($LASTEXITCODE -eq 0) {
    throw "Crew poker wrapper accepted a missing manifest."
}

Set-Content -LiteralPath $manifestPath -Encoding UTF8 -Value '{"passed":false}'
& powershell -NoProfile -ExecutionPolicy Bypass -File $wrapper -ManifestOnly -ManifestPath $manifestPath
if ($LASTEXITCODE -eq 0) {
    throw "Crew poker wrapper accepted passed=false."
}

Set-Content -LiteralPath $manifestPath -Encoding UTF8 -Value '{"passed":true}'
& powershell -NoProfile -ExecutionPolicy Bypass -File $wrapper -ManifestOnly -ManifestPath $manifestPath
if ($LASTEXITCODE -ne 0) {
    throw "Crew poker wrapper rejected passed=true."
}

Remove-Item -LiteralPath $manifestPath -Force
Write-Host "CREW_POKER_VISUAL_CAPTURE_WRAPPER_CHECK_PASS"
