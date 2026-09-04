param(
    [Parameter(Mandatory = $true)][string]$CandidateCommit,
    [Parameter(Mandatory = $true)][ValidateSet("native", "web")][string]$Platform,
    [Parameter(Mandatory = $true)][ValidateSet("native", "web", "low_end")][string]$Profile,
    [Parameter(Mandatory = $true)][string]$ProfilePath,
    [Parameter(Mandatory = $true)][string]$LaunchSummary,
    [Parameter(Mandatory = $true)][string]$StaticAudit,
    [Parameter(Mandatory = $true)][string]$Out
)

$ErrorActionPreference = "Stop"
$root = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
function Resolve-RepoPath([string]$Path) {
    if ([IO.Path]::IsPathRooted($Path)) { return [IO.Path]::GetFullPath($Path) }
    return [IO.Path]::GetFullPath((Join-Path $root $Path))
}
function Read-Json([string]$Path) { return Get-Content -LiteralPath (Resolve-RepoPath $Path) -Raw | ConvertFrom-Json }
function Has-Property($Value, [string]$Name) { return $null -ne $Value -and $Value.PSObject.Properties.Name -contains $Name }
function Metric($Stats, [string]$AverageName = "avg") {
    return [ordered]@{
        count = [int]$Stats.count
        mean_ms = [double]$Stats.$AverageName
        p95_ms = [double]$Stats.p95
        max_ms = [double]$Stats.max
    }
}

$candidate = (& git -C $root rev-parse "$CandidateCommit^{commit}").Trim()
if ($LASTEXITCODE -ne 0) { throw "CandidateCommit does not resolve." }
if ((& git -C $root rev-parse HEAD).Trim() -cne $candidate) { throw "Surface report must be built on its exact candidate." }
if (@(& git -C $root status --short --untracked-files=no).Count -ne 0) { throw "Surface report requires a clean tracked candidate." }
$profileFile = Resolve-RepoPath $ProfilePath
$summaryFile = Resolve-RepoPath $LaunchSummary
$auditFile = Resolve-RepoPath $StaticAudit
$budgetFile = Join-Path $PSScriptRoot "perf06_budget_table.json"
$outFile = Resolve-RepoPath $Out
foreach ($path in @($profileFile, $summaryFile, $auditFile, $budgetFile)) { if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required evidence is missing: $path" } }
if (Test-Path -LiteralPath $outFile) { throw "Refusing to overwrite immutable surface report: $outFile" }
$profileManifest = Read-Json $profileFile
$summary = Read-Json $summaryFile
$audit = Read-Json $auditFile
$budgetTable = Read-Json $budgetFile
if (-not [bool]$audit.passed -or [string]$audit.candidate_commit -cne $candidate) { throw "Static allocation audit is not green for the candidate." }
if (-not [bool]$summary.passed -or @($summary.failures).Count -ne 0) { throw "Runtime launch summary did not pass its enforced budgets and contracts." }

$rawPath = Resolve-RepoPath ([string]$(if ($Platform -eq "native") { $summary.runtime_report } else { $summary.report }))
$rawEnvelope = Read-Json $rawPath
$runtime = if ($Platform -eq "web" -and (Has-Property $rawEnvelope "report")) { $rawEnvelope.report } else { $rawEnvelope }
$summaryCandidate = [string]$(if ($Platform -eq "native") { $summary.candidate_commit } else { $summary.source_commit })
if ($summaryCandidate -cne $candidate -or [string]$runtime.build_identity.source_commit -cne $candidate) { throw "Runtime/summary candidate identity mismatch." }

$profileHash = (Get-FileHash -LiteralPath $profileFile -Algorithm SHA256).Hash.ToLowerInvariant()
$auditHash = (Get-FileHash -LiteralPath $auditFile -Algorithm SHA256).Hash.ToLowerInvariant()
$budgetHash = (Get-FileHash -LiteralPath $budgetFile -Algorithm SHA256).Hash.ToLowerInvariant()
$launch = [ordered]@{
    candidate_commit = $candidate
    profile_manifest_sha256 = $profileHash
    host_id = [string]$(if ($summary.host_id) { $summary.host_id } else { $summary.host_name })
    resolution = "1280x720"
    renderer = "compatibility"
    power_plan = [string]$profileManifest.power_plan
    actual_cpu_throttle_rate = [string]$(if ($Platform -eq "native") { $summary.actual_cpu_throttle_rate } else { $summary.cpu_throttle_rate })
    actual_device_scale_factor = [double]$(if ($summary.actual_device_scale_factor) { $summary.actual_device_scale_factor } else { $summary.viewport.device_pixel_ratio })
    budget_table_version = [int]$budgetTable.version
    budget_table_sha256 = $budgetHash
}
if ($Platform -eq "native") {
    $launch.godot_sha256 = [string]$summary.godot_sha256
    $launch.build_sha256 = [string]$summary.build_sha256
} else {
    if ([int]$summary.budget_table_version -ne [int]$budgetTable.version -or [string]$summary.budget_table_sha256 -cne $budgetHash) { throw "Web runtime did not enforce the published budget-table identity." }
    $launch.browser_version = [string]$summary.browser_version
    $launch.browser_flags = @($summary.launch_options.args)
    $launch.viewport = $summary.viewport
    $launch.worker_mode = [bool]$runtime.boot_timeline.web_thread_feature
    $launch.export_sha256 = [string]$summary.web_export_identity.aggregate_sha256
}
if ($Profile -eq "low_end") {
    $launch.low_end_profile_sha256 = $profileHash
    $launch.low_end_method = [string]$profileManifest.method
    $launch.hardware_fingerprint = [string]$profileManifest.hardware_fingerprint_sha256
}

$rows = [Collections.Generic.List[object]]::new()
$failures = [Collections.Generic.List[string]]::new()
foreach ($scenario in @($runtime.scenarios)) {
    $tags = $scenario.tags
    if ($null -eq $tags -or -not (Has-Property $tags "perf06_surface_id") -or -not (Has-Property $tags "perf06_phase_id")) { continue }
    $surfaceId = [string]$tags.perf06_surface_id
    $phaseId = [string]$tags.perf06_phase_id
    if ([string]::IsNullOrWhiteSpace($surfaceId) -or [string]::IsNullOrWhiteSpace($phaseId)) { continue }
    $gameLive = $scenario.liveness_counter_delta.game_surface
    $environmentLive = $scenario.liveness_counter_delta.environment_scene
    $gameMeasured = [int]$gameLive.draw_sample_count
    $environmentMeasured = [int]$environmentLive.scene_idle_animation_redraw_count
    $isIdle = [string]$tags.mode -match "idle"
    $counter = if ($gameMeasured -gt 0) { "draw_sample_count" } elseif ($environmentMeasured -gt 0) { "scene_idle_animation_redraw_count" } else { "static_phase" }
    $measured = if ($gameMeasured -gt 0) { $gameMeasured } else { $environmentMeasured }
    $zeroReason = if ($measured -le 0 -and -not $isIdle) { "Synchronous/static action phase; production action progress is required instead." } else { "" }
    $drawStats = $scenario.surface_draw_time_ms
    $frameMetric = Metric $scenario.frame_time_ms
    $drawMetric = [ordered]@{
        count = [int]$drawStats.count
        mean_ms = [double]$drawStats.avg_ms
        p95_ms = [double]$drawStats.p95_ms
        max_ms = [double]$drawStats.max_ms
        calls_mean = [double]$scenario.draw_calls.avg
        source = [string]$drawStats.source
    }
    $allocation = [ordered]@{}
    foreach ($property in $scenario.allocation_copy_counters.PSObject.Properties) { $allocation[$property.Name] = $property.Value }
    $allocation.static_call_root_audit_path = $auditFile
    $allocation.static_call_root_audit_sha256 = $auditHash
    $actionPassed = $true
    if (Has-Property $tags "action_evidence") { $actionPassed = [bool]$tags.action_evidence.accepted -and [bool]$tags.action_evidence.progressed }
    $phaseEvidencePassed = $true
    if (Has-Property $tags "phase_evidence") { $phaseEvidencePassed = [bool]$tags.phase_evidence.observed }
    $passed = $frameMetric.count -gt 0 -and $drawMetric.count -gt 0 -and $actionPassed -and $phaseEvidencePassed -and ($measured -gt 0 -or -not [string]::IsNullOrWhiteSpace($zeroReason)) -and [int64]$allocation.deep_copies -eq 0
    if (-not $passed) { $failures.Add("Phase did not produce complete live evidence: $surfaceId/$phaseId/$Profile") }
    $rows.Add([pscustomobject][ordered]@{
        surface_id = $surfaceId
        phase_id = $phaseId
        platform = $Platform
        profile = $Profile
        source_scenario = [string]$scenario.name
        launch_identity = $launch
        frame = $frameMetric
        draw = $drawMetric
        liveness = [ordered]@{ counter=$counter; floor=if ($measured -gt 0) { 1 } else { 0 }; measured=$measured; zero_reason=$zeroReason }
        allocation_copy_counters = $allocation
        retained_counters = [ordered]@{ static_memory=$scenario.static_memory_bytes; objects=$scenario.object_count; nodes=$scenario.node_count; orphans=$scenario.orphan_node_count }
        action_evidence = $(if (Has-Property $tags "action_evidence") { $tags.action_evidence } else { $null })
        phase_evidence = $(if (Has-Property $tags "phase_evidence") { $tags.phase_evidence } else { $null })
        passed = $passed
    })
}
if ($rows.Count -eq 0) { $failures.Add("Runtime report contained no canonical perf06 phase tags.") }
$toolHash = (Get-FileHash -LiteralPath $MyInvocation.MyCommand.Path -Algorithm SHA256).Hash.ToLowerInvariant()
$result = [ordered]@{
    schema = "beat_the_house.perf06_surface_report/v1"
    version = 1
    candidate_commit = $candidate
    candidate_tree = (& git -C $root rev-parse "HEAD^{tree}").Trim()
    tool_source_sha256 = $toolHash
    phase_samples = @($rows)
    retained_counters = [ordered]@{ source="phase_rows"; phase_count=$rows.Count }
    allocation_copy_counters = [ordered]@{ source="phase_rows"; static_audit_sha256=$auditHash }
    artifacts = @(
        [ordered]@{ path=$rawPath; sha256=(Get-FileHash -LiteralPath $rawPath -Algorithm SHA256).Hash.ToLowerInvariant(); size_bytes=(Get-Item -LiteralPath $rawPath).Length },
        [ordered]@{ path=$summaryFile; sha256=(Get-FileHash -LiteralPath $summaryFile -Algorithm SHA256).Hash.ToLowerInvariant(); size_bytes=(Get-Item -LiteralPath $summaryFile).Length },
        [ordered]@{ path=$auditFile; sha256=$auditHash; size_bytes=(Get-Item -LiteralPath $auditFile).Length },
        [ordered]@{ path=$profileFile; sha256=$profileHash; size_bytes=(Get-Item -LiteralPath $profileFile).Length },
        [ordered]@{ path=$budgetFile; sha256=$budgetHash; size_bytes=(Get-Item -LiteralPath $budgetFile).Length }
    )
    failures = @($failures)
    passed = $failures.Count -eq 0
}
$directory = Split-Path -Parent $outFile
New-Item -ItemType Directory -Force -Path $directory | Out-Null
$result | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $outFile -Encoding utf8
if ($failures.Count -ne 0) { Write-Error "PERF06 SURFACE REPORT FAIL failures=$($failures.Count) report=$outFile"; exit 1 }
Write-Host "PERF06 SURFACE REPORT PASS phases=$($rows.Count) report=$outFile"
