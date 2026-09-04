$ErrorActionPreference = "Stop"
$root = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$matrix = Get-Content -LiteralPath (Join-Path $PSScriptRoot "perf06_required_matrix.json") -Raw | ConvertFrom-Json
$games = Get-Content -LiteralPath (Join-Path $root "data/games/games.json") -Raw | ConvertFrom-Json
if ([string]$matrix.schema -cne "beat_the_house.perf06_required_matrix/v1") { throw "Required matrix schema changed." }
$shippedIds = @($games | ForEach-Object { [string]$_.id } | Sort-Object)
$matrixIds = @($matrix.games.PSObject.Properties.Name | Sort-Object)
if (($shippedIds -join "|") -cne ($matrixIds -join "|")) { throw "Performance matrix game IDs do not exactly match shipped games. shipped=$($shippedIds -join ',') matrix=$($matrixIds -join ',')" }
if ((@($matrix.required_profiles) -join "|") -cne "native|web|low_end") { throw "Required platform profiles changed." }
foreach ($surface in @($matrix.games.PSObject.Properties) + @($matrix.systems.PSObject.Properties)) {
    $phases = @($surface.Value | ForEach-Object { [string]$_ })
    if ($phases.Count -eq 0 -or @($phases | Sort-Object -Unique).Count -ne $phases.Count) { throw "Surface '$($surface.Name)' has empty or duplicate phases." }
    if (-not ($matrix.allocation_roots.PSObject.Properties.Name -contains $surface.Name) -or @($matrix.allocation_roots.PSObject.Properties[$surface.Name].Value).Count -eq 0) { throw "Surface '$($surface.Name)' has no allocation roots." }
}
foreach ($surfaceOverride in @($matrix.allocation_roots_by_phase.PSObject.Properties)) {
    $surfaceDefinition = if ($matrix.games.PSObject.Properties.Name -contains $surfaceOverride.Name) { $matrix.games.PSObject.Properties[$surfaceOverride.Name].Value } else { $matrix.systems.PSObject.Properties[$surfaceOverride.Name].Value }
    if ($null -eq $surfaceDefinition) { throw "Phase allocation override names unknown surface '$($surfaceOverride.Name)'." }
    $unionRoots = @($matrix.allocation_roots.PSObject.Properties[$surfaceOverride.Name].Value)
    foreach ($phaseOverride in @($surfaceOverride.Value.PSObject.Properties)) {
        if (@($surfaceDefinition) -cnotcontains $phaseOverride.Name) { throw "Allocation override names unknown phase '$($surfaceOverride.Name)/$($phaseOverride.Name)'." }
        $phaseRoots = @($phaseOverride.Value)
        if ($phaseRoots.Count -eq 0) { throw "Allocation override is empty for '$($surfaceOverride.Name)/$($phaseOverride.Name)'." }
        foreach ($rootName in $phaseRoots) { if ($unionRoots -cnotcontains [string]$rootName) { throw "Allocation override '$rootName' is not in the surface union for '$($surfaceOverride.Name)'." } }
    }
}
$lowEndLauncher = Get-Content -LiteralPath (Join-Path $PSScriptRoot "perf06_low_end_matrix.ps1") -Raw
foreach ($needle in @("reproducible_whole_matrix_throttle", "ProcessorAffinity", "PriorityClass", "native_surface_probe.json", "ProfileManifestSha256", "PERF06 LOW-END PREFLIGHT PASS")) {
    if (-not $lowEndLauncher.Contains($needle)) { throw "Low-end launcher lost reproducible whole-matrix binding '$needle'." }
}
$nativeWrapper = Get-Content -LiteralPath (Join-Path $PSScriptRoot "foundation_performance_probe.ps1") -Raw
foreach ($needle in @("BTH_PERF_REPORT_PATH", "BTH_PERF_CANDIDATE_COMMIT", "BTH_PERF_PROFILE_MANIFEST_SHA256")) {
    if (-not $nativeWrapper.Contains($needle)) { throw "Native performance report lost immutable identity seam '$needle'." }
}
$profileCapture = Get-Content -LiteralPath (Join-Path $PSScriptRoot "perf06_capture_host_profile.ps1") -Raw
foreach ($needle in @("hardware_fingerprint_sha256", "reproducible_whole_matrix_throttle", "Refusing to overwrite immutable host profile")) {
    if (-not $profileCapture.Contains($needle)) { throw "Host-profile capture lost '$needle'." }
}
$nativeRuntime = Get-Content -LiteralPath (Join-Path $PSScriptRoot "perf06_native_runtime_matrix.ps1") -Raw
foreach ($needle in @("build_native_solver.ps1", "-Platform Windows", "-Target template_release", "native_plugin_sha256", "--export-release", "Windows Steam", "Refusing to overwrite immutable native evidence", "profile_manifest_sha256", "runtime_report_sha256")) {
    if (-not $nativeRuntime.Contains($needle)) { throw "Native release-runtime matrix lost '$needle'." }
}
foreach ($needle in @("perf06_native_runtime_matrix.ps1", 'foreach ($nativePlan in @("l02", "grand_casino", "coin_pusher"))', "perf06_build_surface_report.ps1", "-Profile low_end", "allocation_call_root_audit.json")) {
    if (-not $lowEndLauncher.Contains($needle)) { throw "Low-end launcher lost complete report production seam '$needle'." }
}
if ($nativeRuntime.Contains("SkipExport")) { throw "Native binding evidence must always use a fresh release export." }
$overlay = Get-Content -LiteralPath (Join-Path $root "scripts/ui/perf_telemetry_overlay.gd") -Raw
foreach ($needle in @('"surface_draw_time_ms"', '"production_game_canvas"', '"complete_frame_upper_bound"', 'reset_performance_counters')) {
    if (-not $overlay.Contains($needle)) { throw "Runtime surface measurement lost '$needle'." }
}
$surfaceBuilder = Get-Content -LiteralPath (Join-Path $PSScriptRoot "perf06_build_surface_report.ps1") -Raw
foreach ($needle in @("perf06_surface_id", "perf06_phase_id", "surface_draw_time_ms", "action_evidence", "static_call_root_audit_sha256", "Refusing to overwrite immutable surface report")) {
    if (-not $surfaceBuilder.Contains($needle)) { throw "Surface-report builder lost '$needle'." }
}
$unknownRootOwners = @($matrix.allocation_roots.PSObject.Properties.Name | Where-Object { $_ -notin $matrixIds -and $_ -notin @($matrix.systems.PSObject.Properties.Name) })
if ($unknownRootOwners.Count -ne 0) { throw "Allocation roots contain unknown surfaces: $($unknownRootOwners -join ',')" }
Write-Host "PERF06 REQUIRED MATRIX CONTRACT PASS games=$($matrixIds.Count) systems=$(@($matrix.systems.PSObject.Properties).Count)"
