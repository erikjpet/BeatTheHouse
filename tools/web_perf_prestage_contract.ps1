function Test-WebPerfPrestagePropertiesPresent {
    param([object]$Value, [string[]]$Names)
    if ($null -eq $Value) { return $false }
    foreach ($name in $Names) {
        $property = $Value.PSObject.Properties[$name]
        if ($null -eq $property -or $null -eq $property.Value) { return $false }
    }
    return $true
}

function Get-WebPerfActivePhaseEvaluation {
    param(
        [object]$Scenario,
        [string]$ExpectedChannel,
        [int]$MinimumActiveFrames = 12,
        [double]$MinimumActiveMsec = 500.0
    )
    $evaluation = [ordered]@{
        schema_present = $false
        channel_matches = $false
        channel_id = ""
        active_at_start = $false
        active_frame_count = 0
        longest_consecutive_active_frames = 0
        active_elapsed_msec = 0.0
        minimum_active_frames = $MinimumActiveFrames
        minimum_active_msec = $MinimumActiveMsec
        frame_window_passed = $false
        elapsed_window_passed = $false
        passed = $false
    }
    if (-not (Test-WebPerfPrestagePropertiesPresent -Value $Scenario -Names @("tags"))) {
        return [pscustomobject]$evaluation
    }
    $evidence = $Scenario.tags.active_phase_evidence
    $required = @(
        "channel_id", "active_at_start", "sample_frames", "active_frame_count",
        "longest_consecutive_active_frames", "active_elapsed_msec"
    )
    if (-not (Test-WebPerfPrestagePropertiesPresent -Value $evidence -Names $required)) {
        return [pscustomobject]$evaluation
    }
    $evaluation.schema_present = $true
    $evaluation.channel_id = [string]$evidence.channel_id
    $evaluation.channel_matches = $evaluation.channel_id -eq $ExpectedChannel
    $evaluation.active_at_start = [bool]$evidence.active_at_start
    $evaluation.active_frame_count = [int]$evidence.active_frame_count
    $evaluation.longest_consecutive_active_frames = [int]$evidence.longest_consecutive_active_frames
    $evaluation.active_elapsed_msec = [double]$evidence.active_elapsed_msec
    $evaluation.frame_window_passed = $evaluation.longest_consecutive_active_frames -ge $MinimumActiveFrames `
        -and $evaluation.active_frame_count -ge $evaluation.longest_consecutive_active_frames
    $evaluation.elapsed_window_passed = $evaluation.active_elapsed_msec -ge $MinimumActiveMsec
    $evaluation.passed = $evaluation.schema_present -and $evaluation.channel_matches `
        -and $evaluation.active_at_start -and $evaluation.frame_window_passed `
        -and $evaluation.elapsed_window_passed
    return [pscustomobject]$evaluation
}

function Get-WebPerfCornerStoreTimingEvaluation {
    param([object]$Report)
    $requiredStartup = @("foundation_run_start_ms", "post_start_settle_ms", "choice_build_ms", "travel_ms", "total_ms")
    $requiredTravelStages = @(
        "lifecycle_snapshot_ms", "route_preflight_ms", "route_clock_ms",
        "destination_generation_install_ms", "destination_postprocess_ms",
        "result_commit_save_ms", "triggered_events_refresh_ms"
    )
    $evaluation = [ordered]@{
        startup_event_count = 0
        travel_event_count = 0
        startup_schema_present = $false
        travel_schema_present = $false
        stage_values_valid = $false
        totals_valid = $false
        passed = $false
    }
    if ($null -eq $Report -or $null -eq $Report.events) {
        return [pscustomobject]$evaluation
    }
    $startupEvents = @($Report.events | Where-Object { [string]$_.id -eq "corner_store_startup_timing" })
    $travelEvents = @($Report.events | Where-Object { [string]$_.id -eq "corner_store_travel_stage_timing" })
    $evaluation.startup_event_count = $startupEvents.Count
    $evaluation.travel_event_count = $travelEvents.Count
    if ($startupEvents.Count -ne 1 -or $travelEvents.Count -ne 1) {
        return [pscustomobject]$evaluation
    }
    $startup = $startupEvents[0].data
    $travel = $travelEvents[0].data
    $evaluation.startup_schema_present = Test-WebPerfPrestagePropertiesPresent -Value $startup -Names $requiredStartup
    $evaluation.travel_schema_present = (Test-WebPerfPrestagePropertiesPresent -Value $travel -Names @("target_id", "stages", "total_ms")) `
        -and (Test-WebPerfPrestagePropertiesPresent -Value $travel.stages -Names $requiredTravelStages)
    if (-not $evaluation.startup_schema_present -or -not $evaluation.travel_schema_present) {
        return [pscustomobject]$evaluation
    }
    $stageValues = @($requiredStartup | ForEach-Object { [double]$startup.$_ }) `
        + @($requiredTravelStages | ForEach-Object { [double]$travel.stages.$_ })
    $evaluation.stage_values_valid = @($stageValues | Where-Object { $_ -lt 0.0 }).Count -eq 0 `
        -and [string]$travel.target_id -eq "corner_store"
    $startupPartition = [double]$startup.foundation_run_start_ms + [double]$startup.post_start_settle_ms `
        + [double]$startup.choice_build_ms + [double]$startup.travel_ms
    $travelPartition = 0.0
    foreach ($name in $requiredTravelStages) { $travelPartition += [double]$travel.stages.$name }
    $evaluation.totals_valid = [double]$startup.total_ms -gt 0.0 `
        -and [double]$travel.total_ms -gt 0.0 `
        -and [double]$startup.total_ms -ge $startupPartition `
        -and [Math]::Abs([double]$travel.total_ms - $travelPartition) -le 5.0 `
        -and [double]$startup.travel_ms -ge [double]$travel.total_ms
    $evaluation.passed = $evaluation.startup_schema_present -and $evaluation.travel_schema_present `
        -and $evaluation.stage_values_valid -and $evaluation.totals_valid
    return [pscustomobject]$evaluation
}
