function Resolve-WebPerfEvidencePath {
    param([string]$Root, [string]$Out)
    if ([string]::IsNullOrWhiteSpace($Out)) {
        throw "Web performance evidence output must be a non-empty relative path."
    }
    if ([System.IO.Path]::IsPathRooted($Out)) {
        throw "Web performance evidence output must be relative to the repository root: $Out"
    }
    $rootPath = [System.IO.Path]::GetFullPath($Root).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    $candidate = [System.IO.Path]::GetFullPath((Join-Path $rootPath $Out))
    $rootPrefix = $rootPath + [System.IO.Path]::DirectorySeparatorChar
    if (-not $candidate.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Web performance evidence output escaped the repository root: $Out"
    }
    if ([System.IO.Path]::GetExtension($candidate) -ne ".json") {
        throw "Web performance evidence output must name a JSON report: $Out"
    }
    return $candidate
}

function Test-CoinPusherPropertiesPresent {
    param([object]$Value, [string[]]$Names)
    if ($null -eq $Value) { return $false }
    foreach ($name in $Names) {
        $property = $Value.PSObject.Properties[$name]
        if ($null -eq $property -or $null -eq $property.Value) { return $false }
    }
    return $true
}

function Get-CoinPusherRequiredIdleRedraws {
    param([double]$DurationMsec)
    return [Math]::Max(1, [Math]::Floor(([Math]::Max(0.0, $DurationMsec)) / 1000.0))
}

function Test-CoinPusherIdleSchedulerEvidence {
    param([object]$Counters)
    if (-not (Test-CoinPusherPropertiesPresent -Value $Counters -Names @("surface_animation_scheduler_elapsed_msec", "surface_animation_redraw_count"))) {
        return $false
    }
    $elapsedMsec = [double]$Counters.surface_animation_scheduler_elapsed_msec
    $requiredRedraws = Get-CoinPusherRequiredIdleRedraws -DurationMsec $elapsedMsec
    return $elapsedMsec -gt 0.0 -and [int]$Counters.surface_animation_redraw_count -ge $requiredRedraws
}

function Test-CoinPusherReinstallClockObservation {
    param([object]$Observation)
    return (Test-CoinPusherPropertiesPresent -Value $Observation -Names @("boundary_body_count", "boundary_tray_count", "liveness_before", "liveness_after", "observed_body_count", "observed_tray_count", "conservation")) `
        -and [int]$Observation.boundary_body_count -eq 300 `
        -and [int]$Observation.boundary_tray_count -eq 0 `
        -and [int]$Observation.liveness_after -gt [int]$Observation.liveness_before `
        -and [int]$Observation.observed_body_count -gt 0 `
        -and [int]$Observation.observed_body_count -eq [int]$Observation.conservation.active `
        -and [int]$Observation.observed_tray_count -eq [int]$Observation.conservation.tray `
        -and (Test-CoinPusherConservationSnapshot -Snapshot $Observation.conservation -ExpectedOrigin 300)
}

function Test-CoinPusherConservationSnapshot {
    param([object]$Snapshot, [int]$ExpectedOrigin = 300)
    if (-not (Test-CoinPusherPropertiesPresent -Value $Snapshot -Names @("active", "tray", "gutter", "collected", "cup_consumed", "origin", "accounted", "conservation_ok", "solver_invariants_present", "solver_conservation_ok"))) {
        return $false
    }
    $accounted = [int]$Snapshot.active + [int]$Snapshot.tray + [int]$Snapshot.gutter + [int]$Snapshot.collected + [int]$Snapshot.cup_consumed
    return [int]$Snapshot.active -ge 0 `
        -and [int]$Snapshot.tray -ge 0 `
        -and [int]$Snapshot.gutter -ge 0 `
        -and [int]$Snapshot.collected -ge 0 `
        -and [int]$Snapshot.cup_consumed -ge 0 `
        -and [int]$Snapshot.origin -ge 0 `
        -and [int]$Snapshot.accounted -ge 0 `
        -and [int]$Snapshot.origin -eq $ExpectedOrigin `
        -and [int]$Snapshot.accounted -eq $accounted `
        -and $accounted -eq $ExpectedOrigin `
        -and [bool]$Snapshot.conservation_ok `
        -and [bool]$Snapshot.solver_invariants_present `
        -and [bool]$Snapshot.solver_conservation_ok
}

function Test-CoinPusherSurfaceConservationBinding {
    param([int]$BodyCount, [int]$TrayCount, [object]$Snapshot, [int]$ExpectedOrigin = 300)
    return $BodyCount -eq [int]$Snapshot.active `
        -and $TrayCount -eq [int]$Snapshot.tray `
        -and (Test-CoinPusherConservationSnapshot -Snapshot $Snapshot -ExpectedOrigin $ExpectedOrigin)
}

function Test-CoinPusherReducedSampleBoundary {
    param([object]$Fixture, [object]$Boundary, [object]$ScenarioTags)
    return (Test-CoinPusherPropertiesPresent -Value $Fixture -Names @("body_count")) `
        -and (Test-CoinPusherPropertiesPresent -Value $Boundary -Names @("body_count", "tray_count", "liveness_ticks", "conservation")) `
        -and (Test-CoinPusherPropertiesPresent -Value $ScenarioTags -Names @("body_count_before", "tray_count_before", "solver_liveness_before", "conservation_before")) `
        -and [int]$Fixture.body_count -eq 300 `
        -and [int]$Boundary.body_count -eq [int]$ScenarioTags.body_count_before `
        -and [int]$Boundary.tray_count -eq [int]$ScenarioTags.tray_count_before `
        -and [int]$Boundary.liveness_ticks -eq [int]$ScenarioTags.solver_liveness_before `
        -and (Test-CoinPusherSurfaceConservationBinding -BodyCount ([int]$Boundary.body_count) -TrayCount ([int]$Boundary.tray_count) -Snapshot $Boundary.conservation -ExpectedOrigin 300) `
        -and (Test-CoinPusherSurfaceConservationBinding -BodyCount ([int]$ScenarioTags.body_count_before) -TrayCount ([int]$ScenarioTags.tray_count_before) -Snapshot $ScenarioTags.conservation_before -ExpectedOrigin 300)
}

function Test-CoinPusherReducedEvidenceSchema {
    param([object]$Scenario)
    if (-not (Test-CoinPusherPropertiesPresent -Value $Scenario -Names @("frame_time_ms", "tags"))) { return $false }
    if (-not (Test-CoinPusherPropertiesPresent -Value $Scenario.frame_time_ms -Names @("count"))) { return $false }
    if (-not (Test-CoinPusherPropertiesPresent -Value $Scenario.tags -Names @("solver_liveness_delta", "solver_liveness_before", "body_count_before", "body_count_after", "tray_count_before", "tray_count_after", "conservation_before", "conservation_after", "redraw_delta", "canvas_after"))) { return $false }
    return Test-CoinPusherPropertiesPresent -Value $Scenario.tags.canvas_after -Names @("surface_animation_liveness_active", "draw_sample_count", "draw_p95_ms")
}

function Get-CoinPusherPostCollectAccounting {
    param([object]$Tags)
    $requiredTags = @("body_count_at_accept", "body_count_after", "tray_count_at_accept", "tray_count_after", "tray_value_at_accept", "conservation_at_accept", "conservation_after")
    if (-not (Test-CoinPusherPropertiesPresent -Value $Tags -Names $requiredTags)) {
        return [ordered]@{ body_delta = 0; tray_delta = 0; gutter_delta = 0; valid = $false }
    }
    $bodyDelta = [int]$Tags.body_count_at_accept - [int]$Tags.body_count_after
    $trayDelta = [int]$Tags.tray_count_after - [int]$Tags.tray_count_at_accept
    $gutterDelta = [int]$Tags.conservation_after.gutter - [int]$Tags.conservation_at_accept.gutter
    return [ordered]@{
        body_delta = $bodyDelta
        tray_delta = $trayDelta
        gutter_delta = $gutterDelta
        valid = [int]$Tags.tray_count_at_accept -eq 0 `
            -and [int]$Tags.tray_value_at_accept -eq 0 `
            -and [int]$Tags.conservation_at_accept.active -eq 299 `
            -and [int]$Tags.conservation_at_accept.tray -eq 0 `
            -and [int]$Tags.conservation_at_accept.gutter -eq 0 `
            -and [int]$Tags.conservation_at_accept.collected -eq 1 `
            -and [int]$Tags.conservation_at_accept.cup_consumed -eq 0 `
            -and (Test-CoinPusherSurfaceConservationBinding -BodyCount ([int]$Tags.body_count_at_accept) -TrayCount ([int]$Tags.tray_count_at_accept) -Snapshot $Tags.conservation_at_accept -ExpectedOrigin 300) `
            -and (Test-CoinPusherSurfaceConservationBinding -BodyCount ([int]$Tags.body_count_after) -TrayCount ([int]$Tags.tray_count_after) -Snapshot $Tags.conservation_after -ExpectedOrigin 300) `
            -and $bodyDelta -ge 0 `
            -and $trayDelta -ge 0 `
            -and $gutterDelta -ge 0 `
            -and $bodyDelta -eq $trayDelta + $gutterDelta `
            -and [int]$Tags.conservation_after.collected -eq [int]$Tags.conservation_at_accept.collected `
            -and [int]$Tags.conservation_after.cup_consumed -eq [int]$Tags.conservation_at_accept.cup_consumed
    }
}
