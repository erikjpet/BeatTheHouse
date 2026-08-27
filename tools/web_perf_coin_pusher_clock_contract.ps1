function Get-CoinPusherRequiredIdleRedraws {
    param([double]$DurationMsec)
    return [Math]::Max(1, [Math]::Floor(([Math]::Max(0.0, $DurationMsec)) / 1000.0))
}

function Test-CoinPusherReinstallClockObservation {
    param([object]$Observation)
    return [int]$Observation.boundary_body_count -eq 300 `
        -and [int]$Observation.boundary_tray_count -eq 0 `
        -and [int]$Observation.liveness_after -gt [int]$Observation.liveness_before `
        -and [int]$Observation.observed_body_count -gt 0 `
        -and [int]$Observation.observed_body_count -eq [int]$Observation.conservation.active `
        -and [int]$Observation.observed_tray_count -eq [int]$Observation.conservation.tray `
        -and (Test-CoinPusherConservationSnapshot -Snapshot $Observation.conservation -ExpectedOrigin 300)
}

function Test-CoinPusherConservationSnapshot {
    param([object]$Snapshot, [int]$ExpectedOrigin = 300)
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
    return [int]$Fixture.body_count -eq 300 `
        -and [int]$Boundary.body_count -eq [int]$ScenarioTags.body_count_before `
        -and [int]$Boundary.tray_count -eq [int]$ScenarioTags.tray_count_before `
        -and [int]$Boundary.liveness_ticks -eq [int]$ScenarioTags.solver_liveness_before `
        -and (Test-CoinPusherSurfaceConservationBinding -BodyCount ([int]$Boundary.body_count) -TrayCount ([int]$Boundary.tray_count) -Snapshot $Boundary.conservation -ExpectedOrigin 300) `
        -and (Test-CoinPusherSurfaceConservationBinding -BodyCount ([int]$ScenarioTags.body_count_before) -TrayCount ([int]$ScenarioTags.tray_count_before) -Snapshot $ScenarioTags.conservation_before -ExpectedOrigin 300)
}

function Get-CoinPusherPostCollectAccounting {
    param([object]$Tags)
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
