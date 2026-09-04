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
$lowEndLauncher = Get-Content -LiteralPath (Join-Path $PSScriptRoot "perf06_low_end_matrix.ps1") -Raw
foreach ($needle in @("reproducible_whole_matrix_throttle", "ProcessorAffinity", "PriorityClass", "native_surface_probe.json", "ProfileManifestSha256")) {
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
$unknownRootOwners = @($matrix.allocation_roots.PSObject.Properties.Name | Where-Object { $_ -notin $matrixIds -and $_ -notin @($matrix.systems.PSObject.Properties.Name) })
if ($unknownRootOwners.Count -ne 0) { throw "Allocation roots contain unknown surfaces: $($unknownRootOwners -join ',')" }
Write-Host "PERF06 REQUIRED MATRIX CONTRACT PASS games=$($matrixIds.Count) systems=$(@($matrix.systems.PSObject.Properties).Count)"
