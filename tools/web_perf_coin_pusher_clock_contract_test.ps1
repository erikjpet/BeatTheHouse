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
    observed_tray_count = 2
    liveness_before = 0
    liveness_after = 32
    conservation = [pscustomobject]@{
        active = 296; tray = 2; gutter = 2; collected = 0; cup_consumed = 0
        origin = 300; accounted = 300; conservation_ok = $true; solver_invariants_present = $true; solver_conservation_ok = $true
    }
}
Assert-ClockContract -Condition (Test-CoinPusherReinstallClockObservation -Observation $validObservation) -Message "Valid live reinstall observation was rejected."
$frozenObservation = $validObservation.PSObject.Copy()
$frozenObservation.liveness_after = 0
Assert-ClockContract -Condition (-not (Test-CoinPusherReinstallClockObservation -Observation $frozenObservation)) -Message "Frozen reinstall observation was accepted."
$fabricatedObservation = $validObservation.PSObject.Copy()
$fabricatedObservation.conservation = $validObservation.conservation.PSObject.Copy()
$fabricatedObservation.conservation.tray = 3
$fabricatedObservation.conservation.accounted = 301
Assert-ClockContract -Condition (-not (Test-CoinPusherReinstallClockObservation -Observation $fabricatedObservation)) -Message "Fabricated reinstall body was accepted."
$lostObservation = $validObservation.PSObject.Copy()
$lostObservation.conservation = $validObservation.conservation.PSObject.Copy()
$lostObservation.conservation.gutter = 1
$lostObservation.conservation.accounted = 299
Assert-ClockContract -Condition (-not (Test-CoinPusherReinstallClockObservation -Observation $lostObservation)) -Message "Lost reinstall body was accepted."
$mismatchedObservation = $validObservation.PSObject.Copy()
$mismatchedObservation.observed_body_count = 295
Assert-ClockContract -Condition (-not (Test-CoinPusherReinstallClockObservation -Observation $mismatchedObservation)) -Message "Reinstall surface/conservation body mismatch was accepted."
$missingInvariantObservation = $validObservation.PSObject.Copy()
$missingInvariantObservation.conservation = $validObservation.conservation.PSObject.Copy()
$missingInvariantObservation.conservation.solver_invariants_present = $false
Assert-ClockContract -Condition (-not (Test-CoinPusherReinstallClockObservation -Observation $missingInvariantObservation)) -Message "Missing solver conservation invariant was accepted."
$negativeChannelObservation = $validObservation.PSObject.Copy()
$negativeChannelObservation.conservation = $validObservation.conservation.PSObject.Copy()
$negativeChannelObservation.conservation.gutter = -1
$negativeChannelObservation.conservation.tray = 5
Assert-ClockContract -Condition (-not (Test-CoinPusherReinstallClockObservation -Observation $negativeChannelObservation)) -Message "Negative conservation channel was accepted."
$missingZeroChannelObservation = $validObservation.PSObject.Copy()
$missingZeroChannelObservation.conservation = $validObservation.conservation.PSObject.Copy()
$missingZeroChannelObservation.conservation.PSObject.Properties.Remove("cup_consumed")
Assert-ClockContract -Condition (-not (Test-CoinPusherReinstallClockObservation -Observation $missingZeroChannelObservation)) -Message "Missing zero-valued conservation channel was accepted."
$missingZeroBoundaryObservation = $validObservation.PSObject.Copy()
$missingZeroBoundaryObservation.PSObject.Properties.Remove("boundary_tray_count")
Assert-ClockContract -Condition (-not (Test-CoinPusherReinstallClockObservation -Observation $missingZeroBoundaryObservation)) -Message "Missing zero-valued reinstall boundary field was accepted."

$reducedBoundary = [pscustomobject]@{ body_count = 296; tray_count = 2; liveness_ticks = 48; conservation = $validObservation.conservation }
$reducedFixture = [pscustomobject]@{ body_count = 300 }
$reducedScenario = [pscustomobject]@{ body_count_before = 296; tray_count_before = 2; solver_liveness_before = 48; conservation_before = $validObservation.conservation }
Assert-ClockContract -Condition (Test-CoinPusherReducedSampleBoundary -Fixture $reducedFixture -Boundary $reducedBoundary -ScenarioTags $reducedScenario) -Message "Known 300-boundary/296-sample transition was rejected."
$reducedCountMismatch = $reducedScenario.PSObject.Copy()
$reducedCountMismatch.body_count_before = 295
Assert-ClockContract -Condition (-not (Test-CoinPusherReducedSampleBoundary -Fixture $reducedFixture -Boundary $reducedBoundary -ScenarioTags $reducedCountMismatch)) -Message "Reduced sample body-count mismatch was accepted."
$reducedTrayMismatch = $reducedScenario.PSObject.Copy()
$reducedTrayMismatch.tray_count_before = 1
Assert-ClockContract -Condition (-not (Test-CoinPusherReducedSampleBoundary -Fixture $reducedFixture -Boundary $reducedBoundary -ScenarioTags $reducedTrayMismatch)) -Message "Reduced sample tray-count mismatch was accepted."
$reducedLivenessMismatch = $reducedScenario.PSObject.Copy()
$reducedLivenessMismatch.solver_liveness_before = 49
Assert-ClockContract -Condition (-not (Test-CoinPusherReducedSampleBoundary -Fixture $reducedFixture -Boundary $reducedBoundary -ScenarioTags $reducedLivenessMismatch)) -Message "Reduced sample liveness-boundary mismatch was accepted."
$reducedAfterMismatch = [pscustomobject]@{ body_count_after = 295; tray_count_after = 2; conservation_after = $validObservation.conservation }
Assert-ClockContract -Condition (-not (Test-CoinPusherSurfaceConservationBinding -BodyCount $reducedAfterMismatch.body_count_after -TrayCount $reducedAfterMismatch.tray_count_after -Snapshot $reducedAfterMismatch.conservation_after -ExpectedOrigin 300)) -Message "Reduced after-state surface/conservation mismatch was accepted."

$validCollect = [pscustomobject]@{
    body_count_at_accept = 299
    body_count_after = 295
    tray_count_at_accept = 0
    tray_count_after = 2
    tray_value_at_accept = 0
    conservation_at_accept = [pscustomobject]@{
        active = 299; tray = 0; gutter = 0; collected = 1; cup_consumed = 0
        origin = 300; accounted = 300; conservation_ok = $true; solver_invariants_present = $true; solver_conservation_ok = $true
    }
    conservation_after = [pscustomobject]@{
        active = 295; tray = 2; gutter = 2; collected = 1; cup_consumed = 0
        origin = 300; accounted = 300; conservation_ok = $true; solver_invariants_present = $true; solver_conservation_ok = $true
    }
}
Assert-ClockContract -Condition ([bool](Get-CoinPusherPostCollectAccounting -Tags $validCollect).valid) -Message "Legitimate post-COLLECT exits were rejected."
$fabricatedCollect = $validCollect.PSObject.Copy()
$fabricatedCollect.tray_count_after = 5
Assert-ClockContract -Condition (-not [bool](Get-CoinPusherPostCollectAccounting -Tags $fabricatedCollect).valid) -Message "Fabricated post-COLLECT tray result was accepted."
$droppedCollect = $validCollect.PSObject.Copy()
$droppedCollect.conservation_after = $validCollect.conservation_after.PSObject.Copy()
$droppedCollect.conservation_after.gutter = 1
$droppedCollect.conservation_after.accounted = 299
Assert-ClockContract -Condition (-not [bool](Get-CoinPusherPostCollectAccounting -Tags $droppedCollect).valid) -Message "Dropped post-COLLECT outcome channel was accepted."
$collectAcceptMismatch = $validCollect.PSObject.Copy()
$collectAcceptMismatch.body_count_at_accept = 298
Assert-ClockContract -Condition (-not [bool](Get-CoinPusherPostCollectAccounting -Tags $collectAcceptMismatch).valid) -Message "COLLECT acceptance surface/conservation mismatch was accepted."
$collectAfterMismatch = $validCollect.PSObject.Copy()
$collectAfterMismatch.tray_count_after = 1
Assert-ClockContract -Condition (-not [bool](Get-CoinPusherPostCollectAccounting -Tags $collectAfterMismatch).valid) -Message "COLLECT post-window surface/conservation mismatch was accepted."
$wrongAcceptTerminal = $validCollect.PSObject.Copy()
$wrongAcceptTerminal.conservation_at_accept = $validCollect.conservation_at_accept.PSObject.Copy()
$wrongAcceptTerminal.conservation_at_accept.gutter = 1
$wrongAcceptTerminal.conservation_at_accept.collected = 0
Assert-ClockContract -Condition (-not [bool](Get-CoinPusherPostCollectAccounting -Tags $wrongAcceptTerminal).valid) -Message "COLLECT acceptance with the wrong terminal channel was accepted."
$wrongAfterTerminal = $validCollect.PSObject.Copy()
$wrongAfterTerminal.conservation_after = $validCollect.conservation_after.PSObject.Copy()
$wrongAfterTerminal.conservation_after.collected = 2
$wrongAfterTerminal.conservation_after.gutter = 1
Assert-ClockContract -Condition (-not [bool](Get-CoinPusherPostCollectAccounting -Tags $wrongAfterTerminal).valid) -Message "COLLECT post-window terminal-channel mutation was accepted."
$missingCollectZeroBoundary = $validCollect.PSObject.Copy()
$missingCollectZeroBoundary.PSObject.Properties.Remove("tray_count_at_accept")
Assert-ClockContract -Condition (-not [bool](Get-CoinPusherPostCollectAccounting -Tags $missingCollectZeroBoundary).valid) -Message "Missing zero-valued COLLECT boundary field was accepted."

Write-Host "Coin Pusher Web clock contract self-test passed."
