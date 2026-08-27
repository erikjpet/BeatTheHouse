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
        -and (Test-CoinPusherConservationSnapshot -Snapshot $Observation.conservation -ExpectedOrigin 300)
}

function Test-CoinPusherConservationSnapshot {
    param([object]$Snapshot, [int]$ExpectedOrigin = 300)
    $accounted = [int]$Snapshot.active + [int]$Snapshot.tray + [int]$Snapshot.gutter + [int]$Snapshot.collected + [int]$Snapshot.cup_consumed
    return [int]$Snapshot.origin -eq $ExpectedOrigin `
        -and [int]$Snapshot.accounted -eq $accounted `
        -and $accounted -eq $ExpectedOrigin `
        -and [bool]$Snapshot.conservation_ok `
        -and [bool]$Snapshot.solver_conservation_ok
}

function Test-CoinPusherReducedSampleBoundary {
    param([object]$Fixture, [object]$Boundary, [object]$ScenarioTags)
    return [int]$Fixture.body_count -eq 300 `
        -and [int]$Boundary.body_count -eq [int]$ScenarioTags.body_count_before `
        -and [int]$Boundary.tray_count -eq [int]$ScenarioTags.conservation_before.tray `
        -and (Test-CoinPusherConservationSnapshot -Snapshot $Boundary.conservation -ExpectedOrigin 300) `
        -and (Test-CoinPusherConservationSnapshot -Snapshot $ScenarioTags.conservation_before -ExpectedOrigin 300)
}

function Get-CoinPusherPostCollectAccounting {
    param([object]$Tags)
    $bodyDelta = [int]$Tags.body_count_at_accept - [int]$Tags.body_count_after
    $trayDelta = [int]$Tags.tray_count_after - [int]$Tags.tray_count_at_accept
    return [ordered]@{
        body_delta = $bodyDelta
        tray_delta = $trayDelta
        valid = [int]$Tags.tray_count_at_accept -eq 0 `
            -and [int]$Tags.tray_value_at_accept -eq 0 `
            -and [int]$Tags.body_count_at_accept -gt 0 `
            -and $bodyDelta -ge 0 `
            -and $trayDelta -ge 0 `
            -and $trayDelta -le $bodyDelta `
            -and (Test-CoinPusherConservationSnapshot -Snapshot $Tags.conservation_at_accept -ExpectedOrigin 300) `
            -and (Test-CoinPusherConservationSnapshot -Snapshot $Tags.conservation_after -ExpectedOrigin 300)
    }
}
