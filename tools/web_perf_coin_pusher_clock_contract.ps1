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
        -and [int]$Observation.observed_body_count + [int]$Observation.observed_tray_count -le 300
}

function Get-CoinPusherPostCollectAccounting {
    param([object]$Tags)
    $bodyDelta = [int]$Tags.body_count_at_accept - [int]$Tags.body_count_after
    $trayDelta = [int]$Tags.tray_count_after - [int]$Tags.tray_count_at_accept
    return [ordered]@{
        body_delta = $bodyDelta
        tray_delta = $trayDelta
        valid = [int]$Tags.body_count_at_accept -gt 0 `
            -and $bodyDelta -ge 0 `
            -and $trayDelta -ge 0 `
            -and $trayDelta -le $bodyDelta
    }
}
