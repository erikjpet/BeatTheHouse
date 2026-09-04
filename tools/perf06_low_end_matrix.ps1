param(
    [Parameter(Mandatory = $true)][string]$ProfilePath,
    [string]$GodotPath = "",
    [string]$OutDir = ".tmp/perf06_1/low_end",
    [switch]$PreflightOnly,
    [switch]$RequireGodot
)

$ErrorActionPreference = "Stop"
$root = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$profileFile = if ([IO.Path]::IsPathRooted($ProfilePath)) { [IO.Path]::GetFullPath($ProfilePath) } else { [IO.Path]::GetFullPath((Join-Path $root $ProfilePath)) }
if (-not (Test-Path -LiteralPath $profileFile -PathType Leaf)) { throw "Low-end profile is missing: $profileFile" }
$profile = Get-Content -LiteralPath $profileFile -Raw | ConvertFrom-Json
foreach ($field in @("schema", "profile_id", "method", "computer_name", "resolution", "renderer", "power_plan", "web_browser", "web_cpu_throttle_rate", "web_device_scale_factor", "web_launch_flags", "hardware_fingerprint_sha256", "hardware")) {
    if (-not ($profile.PSObject.Properties.Name -contains $field)) { throw "Low-end profile is missing '$field'." }
}
if ([string]$profile.schema -cne "beat_the_house.perf06_low_end_profile/v1") { throw "Unsupported low-end profile schema '$($profile.schema)'." }
$method = [string]$profile.method
if ($method -notin @("physical", "reproducible_whole_matrix_throttle")) { throw "Low-end method must be physical or reproducible_whole_matrix_throttle." }
if ($method -eq "reproducible_whole_matrix_throttle") {
    foreach ($field in @("native_processor_affinity_hex", "native_priority_class")) {
        if (-not ($profile.PSObject.Properties.Name -contains $field)) { throw "Reproducible whole-matrix throttle is missing '$field'." }
    }
    if ([string]$profile.native_priority_class -notin @("Idle", "BelowNormal")) { throw "Reproducible native priority must be Idle or BelowNormal." }
}
if ([string]$profile.computer_name -cne $env:COMPUTERNAME) { throw "Profile host '$($profile.computer_name)' does not match '$env:COMPUTERNAME'." }
if ([string]$profile.resolution -cne "1280x720" -or [string]$profile.renderer -cne "compatibility") { throw "Low-end profile must use 1280x720 and the compatibility renderer." }
if ([string]$profile.web_browser -cne "chrome") { throw "Low-end Web qualification requires the maintained Chrome path." }
$actualPowerPlan = ((powercfg /getactivescheme) -join " ").Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($actualPowerPlan)) { throw "Could not capture the active Windows power plan." }
if ($actualPowerPlan -cne [string]$profile.power_plan) { throw "Active power plan does not match the low-end profile. Actual='$actualPowerPlan'" }

function Get-TextSha256([string]$Value) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Value)))).Replace("-", "").ToLowerInvariant() }
    finally { $sha.Dispose() }
}

$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
$os = Get-CimInstance Win32_OperatingSystem
$gpus = @(Get-CimInstance Win32_VideoController | Sort-Object Name | ForEach-Object { "$($_.Name)|$($_.DriverVersion)" })
$actualHardware = [ordered]@{
    os_build = [string]$os.BuildNumber
    cpu = [string]$cpu.Name
    physical_cores = [int]$cpu.NumberOfCores
    logical_cores = [int]$cpu.NumberOfLogicalProcessors
    ram_bytes = [int64]$os.TotalVisibleMemorySize * 1024
    gpu = ($gpus -join ";")
}
$hardwareCanonical = $actualHardware | ConvertTo-Json -Compress
$hardwareFingerprint = Get-TextSha256 $hardwareCanonical
foreach ($property in $actualHardware.GetEnumerator()) {
    if (-not ($profile.hardware.PSObject.Properties.Name -contains [string]$property.Key) -or [string]$profile.hardware.PSObject.Properties[[string]$property.Key].Value -cne [string]$property.Value) {
        throw "Profile hardware field '$($property.Key)' does not match the actual launch host. Actual='$($property.Value)'"
    }
}
if ($hardwareFingerprint -cne ([string]$profile.hardware_fingerprint_sha256).ToLowerInvariant()) {
    throw "Actual hardware fingerprint '$hardwareFingerprint' does not match the launch profile. Actual=$hardwareCanonical"
}

$head = (& git -C $root rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) { throw "Could not resolve candidate commit." }
$tracked = @(& git -C $root status --short --untracked-files=no)
if ($tracked.Count -ne 0) { throw "Low-end qualification requires a clean tracked candidate." }

$out = if ([IO.Path]::IsPathRooted($OutDir)) { [IO.Path]::GetFullPath($OutDir) } else { [IO.Path]::GetFullPath((Join-Path $root $OutDir)) }
$tmp = [IO.Path]::GetFullPath((Join-Path $root ".tmp"))
if (-not $out.StartsWith($tmp + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw "OutDir must resolve below .tmp." }
if (Test-Path -LiteralPath $out) { throw "Refusing to overwrite retained low-end evidence: $out" }
New-Item -ItemType Directory -Path $out | Out-Null

$profileHash = (Get-FileHash -LiteralPath $profileFile -Algorithm SHA256).Hash.ToLowerInvariant()
$oldEvidenceProfile = $env:BTH_PERF_EVIDENCE_PROFILE
$oldLowEndProfile = $env:BTH_PERF_LOW_END_PROFILE
$launcherProcess = Get-Process -Id $PID
$oldProcessorAffinity = $launcherProcess.ProcessorAffinity
$oldPriorityClass = $launcherProcess.PriorityClass
$env:BTH_PERF_EVIDENCE_PROFILE = "low_end:$($profile.profile_id)"
$env:BTH_PERF_LOW_END_PROFILE = $profileFile
try {
    if ($method -eq "reproducible_whole_matrix_throttle") {
        $affinityText = ([string]$profile.native_processor_affinity_hex).Trim().ToLowerInvariant().Replace("0x", "")
        $affinityMask = [Convert]::ToInt64($affinityText, 16)
        if ($affinityMask -le 0) { throw "Native processor affinity mask must select at least one logical CPU." }
        $launcherProcess.ProcessorAffinity = [IntPtr]$affinityMask
        $launcherProcess.PriorityClass = [Diagnostics.ProcessPriorityClass]([string]$profile.native_priority_class)
    }
    $processInventory = Get-Process | Select-Object Name, Id, CPU, WorkingSet64
    $hostEvidence = [ordered]@{
        schema = "beat_the_house.perf06_low_end_run/v1"
        candidate_commit = $head
        profile_id = [string]$profile.profile_id
        profile_sha256 = $profileHash
        hardware_fingerprint_sha256 = $hardwareFingerprint
        actual_hardware = $actualHardware
        actual_power_plan = $actualPowerPlan
        low_end_method = $method
        actual_launcher_processor_affinity = ("0x{0:x}" -f [int64]$launcherProcess.ProcessorAffinity)
        actual_launcher_priority_class = [string]$launcherProcess.PriorityClass
        computer_name = $env:COMPUTERNAME
        started_utc = [DateTime]::UtcNow.ToString("o")
        process_inventory_before = @($processInventory)
    }
    $hostEvidence | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $out "run_identity.json") -Encoding utf8

    if ($PreflightOnly) {
        $hostEvidence.completed_utc = [DateTime]::UtcNow.ToString("o")
        $hostEvidence.preflight_only = $true
        $hostEvidence.passed = $true
        $hostEvidence | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $out "run_identity.json") -Encoding utf8
        Write-Host "PERF06 LOW-END PREFLIGHT PASS profile=$($profile.profile_id) commit=$head out=$out"
        return
    }

    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "foundation_performance_probe.ps1") -RunCount 8 -FramesPerSurface 120 -ResolveSampleCount 48 -SeedPrefix "PERF06-LOW-$($profile.profile_id)" -Out (Join-Path $out "native_surface_probe.json") -CandidateCommit $head -ProfileManifestSha256 $profileHash -EvidenceProfile "low_end:$($profile.profile_id)" -RequireGodot:$RequireGodot
    if ($LASTEXITCODE -ne 0) { throw "Native low-end surface matrix failed." }

    $staticAudit = Join-Path $out "allocation_call_root_audit.json"
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "perf06_allocation_call_root_audit.ps1") -CandidateCommit $head -Out $staticAudit
    if ($LASTEXITCODE -ne 0) { throw "Low-end allocation call-root audit failed." }

    foreach ($nativePlan in @("l02", "grand_casino", "coin_pusher")) {
        $nativeOut = Join-Path $out ("native_runtime_{0}" -f $nativePlan)
        & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "perf06_native_runtime_matrix.ps1") -ProfilePath $profileFile -GodotPath $GodotPath -OutDir $nativeOut -Plan $nativePlan -EvidenceProfile "low_end:$($profile.profile_id)" -Frames 120 -ActiveFrames 240 -MemorySeconds 600 -TimeoutMs 900000
        if ($LASTEXITCODE -ne 0) { throw "Low-end native runtime plan failed: $nativePlan." }
        & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "perf06_build_surface_report.ps1") -CandidateCommit $head -Platform native -Profile low_end -ProfilePath $profileFile -LaunchSummary (Join-Path $nativeOut "summary.json") -StaticAudit $staticAudit -Out (Join-Path $nativeOut "surface_report.json")
        if ($LASTEXITCODE -ne 0) { throw "Low-end native surface report failed: $nativePlan." }
    }

    $webRuns = @(
        @{ plan="l02"; cache="cold"; port=18620 },
        @{ plan="l02"; cache="warm"; port=18621 },
        @{ plan="grand_casino"; cache="cold"; port=18622 },
        @{ plan="coin_pusher"; cache="cold"; port=18623 }
    )
    foreach ($run in $webRuns) {
        $webOut = Join-Path $out ("web_{0}_{1}.json" -f $run.plan, $run.cache)
        & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "web_perf_smoke.ps1") -Browser chrome -Cpu ([int]$profile.web_cpu_throttle_rate) -Port $run.port -Frames 120 -ActiveFrames 240 -MemorySeconds 600 -TimeoutMs 900000 -Plan $run.plan -CacheMode $run.cache -EvidenceProfile "low_end:$($profile.profile_id)" -Out $webOut
        if ($LASTEXITCODE -ne 0) { throw "Low-end Web run failed: $($run.plan)/$($run.cache)." }
        $captured = Get-Content -LiteralPath $webOut -Raw | ConvertFrom-Json
        if ([int]$captured.cpu_throttle_rate -ne [int]$profile.web_cpu_throttle_rate) { throw "Web capture did not apply the declared CPU throttle." }
        if ([int]$captured.viewport.inner_width -ne 1280 -or [int]$captured.viewport.inner_height -ne 720) { throw "Web capture viewport was not 1280x720." }
        if ([double]$captured.viewport.device_pixel_ratio -le 0) { throw "Web capture did not record device scale." }
        if ([double]$captured.viewport.device_pixel_ratio -ne [double]$profile.web_device_scale_factor) { throw "Web capture device scale does not match the profile." }
        if ([string]::IsNullOrWhiteSpace([string]$captured.browser_version) -or [string]::IsNullOrWhiteSpace([string]$captured.user_agent)) { throw "Web capture did not record browser identity." }
        $actualFlags = @($captured.launch_options.args)
        foreach ($flag in @($profile.web_launch_flags)) { if ($actualFlags -cnotcontains [string]$flag) { throw "Web capture omitted declared launch flag '$flag'." } }
        $webSummary = [System.IO.Path]::ChangeExtension($webOut, ".summary.json")
        $webSurfaceReport = [System.IO.Path]::ChangeExtension($webOut, ".surface.json")
        & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "perf06_build_surface_report.ps1") -CandidateCommit $head -Platform web -Profile low_end -ProfilePath $profileFile -LaunchSummary $webSummary -StaticAudit $staticAudit -Out $webSurfaceReport
        if ($LASTEXITCODE -ne 0) { throw "Low-end Web surface report failed: $($run.plan)/$($run.cache)." }
    }

    foreach ($orchestrator in @("integ06_1_composition_matrix.ps1", "integ06_1_terminal_soak.ps1")) {
        $path = Join-Path $PSScriptRoot $orchestrator
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Integration producer is not available: $path" }
        $integrationOut = Join-Path $out ($orchestrator -replace '\.ps1$', '')
        & powershell -NoProfile -ExecutionPolicy Bypass -File $path -CandidateCommit $head -ProfilePath $profileFile -EvidenceProfile "low_end:$($profile.profile_id)" -OutDir $integrationOut -GodotPath $GodotPath -RequireGodot:$RequireGodot
        if ($LASTEXITCODE -ne 0) { throw "Integration low-end producer failed: $orchestrator" }
    }

    $hostEvidence.completed_utc = [DateTime]::UtcNow.ToString("o")
    $hostEvidence.process_inventory_after = @(Get-Process | Select-Object Name, Id, CPU, WorkingSet64)
    $hostEvidence.passed = $true
    $hostEvidence | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $out "run_identity.json") -Encoding utf8
    Write-Host "PERF06 LOW-END MATRIX PASS profile=$($profile.profile_id) commit=$head out=$out"
}
finally {
    $env:BTH_PERF_EVIDENCE_PROFILE = $oldEvidenceProfile
    $env:BTH_PERF_LOW_END_PROFILE = $oldLowEndProfile
    $launcherProcess.ProcessorAffinity = $oldProcessorAffinity
    $launcherProcess.PriorityClass = $oldPriorityClass
}
