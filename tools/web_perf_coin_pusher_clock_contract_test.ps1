$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "web_perf_coin_pusher_clock_contract.ps1")

function Assert-ClockContract {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

Assert-ClockContract -Condition ((Get-CoinPusherRequiredIdleRedraws -DurationMsec 7587) -eq 7) -Message "Slow-frame 1 Hz floor did not use elapsed wall time."
Assert-ClockContract -Condition ((Get-CoinPusherRequiredIdleRedraws -DurationMsec 400) -eq 1) -Message "Idle redraw floor lost its positive liveness minimum."

$validObservation = [pscustomobject]@{
    boundary_body_count = 300
    boundary_tray_count = 0
    observed_body_count = 296
    observed_tray_count = 4
    liveness_before = 0
    liveness_after = 32
}
Assert-ClockContract -Condition (Test-CoinPusherReinstallClockObservation -Observation $validObservation) -Message "Valid live reinstall observation was rejected."
$frozenObservation = $validObservation.PSObject.Copy()
$frozenObservation.liveness_after = 0
Assert-ClockContract -Condition (-not (Test-CoinPusherReinstallClockObservation -Observation $frozenObservation)) -Message "Frozen reinstall observation was accepted."
$fabricatedObservation = $validObservation.PSObject.Copy()
$fabricatedObservation.observed_tray_count = 5
Assert-ClockContract -Condition (-not (Test-CoinPusherReinstallClockObservation -Observation $fabricatedObservation)) -Message "Fabricated reinstall body was accepted."

$validCollect = [pscustomobject]@{
    body_count_at_accept = 299
    body_count_after = 295
    tray_count_at_accept = 0
    tray_count_after = 2
}
Assert-ClockContract -Condition ([bool](Get-CoinPusherPostCollectAccounting -Tags $validCollect).valid) -Message "Legitimate post-COLLECT exits were rejected."
$fabricatedCollect = $validCollect.PSObject.Copy()
$fabricatedCollect.tray_count_after = 5
Assert-ClockContract -Condition (-not [bool](Get-CoinPusherPostCollectAccounting -Tags $fabricatedCollect).valid) -Message "Fabricated post-COLLECT tray result was accepted."

Write-Host "Coin Pusher Web clock contract self-test passed."
