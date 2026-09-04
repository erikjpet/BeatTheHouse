$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "web_perf_coin_pusher_clock_contract.ps1")

function Assert-ClockContract {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

Assert-ClockContract -Condition ((Get-CoinPusherRequiredIdleRedraws -DurationMsec 7587) -eq 7) -Message "Slow-frame 1 Hz floor did not use elapsed wall time."
Assert-ClockContract -Condition ((Get-CoinPusherRequiredIdleRedraws -DurationMsec 400) -eq 1) -Message "Idle redraw floor lost its positive liveness minimum."
$validSchedulerEvidence = [pscustomobject]@{ surface_animation_scheduler_elapsed_msec = 16000; surface_animation_redraw_count = 16 }
Assert-ClockContract -Condition (Test-CoinPusherIdleSchedulerEvidence -Counters $validSchedulerEvidence) -Message "Exact production scheduler cadence was rejected."
$underCadenceSchedulerEvidence = [pscustomobject]@{ surface_animation_scheduler_elapsed_msec = 18174; surface_animation_redraw_count = 16 }
Assert-ClockContract -Condition (-not (Test-CoinPusherIdleSchedulerEvidence -Counters $underCadenceSchedulerEvidence)) -Message "A real two-redraw scheduler deficit was accepted."
$missingSchedulerElapsed = [pscustomobject]@{ surface_animation_redraw_count = 16 }
Assert-ClockContract -Condition (-not (Test-CoinPusherIdleSchedulerEvidence -Counters $missingSchedulerElapsed)) -Message "Missing production scheduler elapsed time was accepted."

$eligibleDrawTags = [pscustomobject]@{ draw_sampling = [pscustomobject]@{ warmup_samples = 3; target_samples = 64; sample_frames = 946; sample_count = 64; complete = $true; p95_percentile = 0.95; p95_rank = 61; probe_interval_frames = 15 } }
$eligibleDrawCounters = [pscustomobject]@{ draw_sample_count = 64; draw_sample_buffer_count = 64; draw_frame_usec_samples = @(1..64) }
Assert-ClockContract -Condition (Test-CoinPusherDrawSamplingEvidence -ScenarioTags $eligibleDrawTags -Counters $eligibleDrawCounters) -Message "Eligible warmed fixed 64-draw percentile evidence was rejected."
$sparseDrawCounters = $eligibleDrawCounters.PSObject.Copy()
$sparseDrawCounters.draw_sample_count = 63
$sparseDrawCounters.draw_sample_buffer_count = 63
$sparseDrawCounters.draw_frame_usec_samples = @(1..63)
Assert-ClockContract -Condition (-not (Test-CoinPusherDrawSamplingEvidence -ScenarioTags $eligibleDrawTags -Counters $sparseDrawCounters)) -Message "Incomplete 63-draw percentile evidence was accepted."
$coldDrawTags = $eligibleDrawTags.PSObject.Copy()
$coldDrawTags.draw_sampling = $eligibleDrawTags.draw_sampling.PSObject.Copy()
$coldDrawTags.draw_sampling.warmup_samples = 2
Assert-ClockContract -Condition (-not (Test-CoinPusherDrawSamplingEvidence -ScenarioTags $coldDrawTags -Counters $eligibleDrawCounters)) -Message "Under-warmed draw percentile evidence was accepted."
$incompleteDrawTags = $eligibleDrawTags.PSObject.Copy()
$incompleteDrawTags.draw_sampling = $eligibleDrawTags.draw_sampling.PSObject.Copy()
$incompleteDrawTags.draw_sampling.complete = $false
Assert-ClockContract -Condition (-not (Test-CoinPusherDrawSamplingEvidence -ScenarioTags $incompleteDrawTags -Counters $eligibleDrawCounters)) -Message "An explicitly incomplete fixed draw window was accepted."
$wrongRankDrawTags = $eligibleDrawTags.PSObject.Copy()
$wrongRankDrawTags.draw_sampling = $eligibleDrawTags.draw_sampling.PSObject.Copy()
$wrongRankDrawTags.draw_sampling.p95_rank = 60
Assert-ClockContract -Condition (-not (Test-CoinPusherDrawSamplingEvidence -ScenarioTags $wrongRankDrawTags -Counters $eligibleDrawCounters)) -Message "Incorrect p95 rank was accepted."

$pathRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$validEvidencePath = Resolve-WebPerfEvidencePath -Root $pathRoot -Out ".tmp/fix06_14_unique/report.json"
Assert-ClockContract -Condition ($validEvidencePath -eq [System.IO.Path]::GetFullPath((Join-Path $pathRoot ".tmp/fix06_14_unique/report.json"))) -Message "Valid relative evidence path was not resolved beneath the repository root."
foreach ($invalidOut in @("", (Join-Path $pathRoot "absolute.json"), "../escaped.json", ".tmp/not-json.txt")) {
    $rejected = $false
    try { Resolve-WebPerfEvidencePath -Root $pathRoot -Out $invalidOut | Out-Null }
    catch { $rejected = $true }
    Assert-ClockContract -Condition $rejected -Message "Invalid evidence output path was accepted: '$invalidOut'."
}

$validObservation = [pscustomobject]@{
    boundary_body_count = 160
    boundary_tray_count = 0
    observed_body_count = 156
    observed_tray_count = 2
    liveness_before = 0
    liveness_after = 32
    conservation = [pscustomobject]@{
        active = 156; tray = 2; gutter = 2; collected = 0; cup_consumed = 0
        origin = 160; accounted = 160; conservation_ok = $true; solver_invariants_present = $true; solver_conservation_ok = $true
    }
}
Assert-ClockContract -Condition (Test-CoinPusherReinstallClockObservation -Observation $validObservation) -Message "Valid live reinstall observation was rejected."
$frozenObservation = $validObservation.PSObject.Copy()
$frozenObservation.liveness_after = 0
Assert-ClockContract -Condition (-not (Test-CoinPusherReinstallClockObservation -Observation $frozenObservation)) -Message "Frozen reinstall observation was accepted."
$fabricatedObservation = $validObservation.PSObject.Copy()
$fabricatedObservation.conservation = $validObservation.conservation.PSObject.Copy()
$fabricatedObservation.conservation.tray = 3
$fabricatedObservation.conservation.accounted = 161
Assert-ClockContract -Condition (-not (Test-CoinPusherReinstallClockObservation -Observation $fabricatedObservation)) -Message "Fabricated reinstall body was accepted."
$lostObservation = $validObservation.PSObject.Copy()
$lostObservation.conservation = $validObservation.conservation.PSObject.Copy()
$lostObservation.conservation.gutter = 1
$lostObservation.conservation.accounted = 159
Assert-ClockContract -Condition (-not (Test-CoinPusherReinstallClockObservation -Observation $lostObservation)) -Message "Lost reinstall body was accepted."
$mismatchedObservation = $validObservation.PSObject.Copy()
$mismatchedObservation.observed_body_count = 155
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

$reducedBoundary = [pscustomobject]@{ body_count = 156; tray_count = 2; liveness_ticks = 48; conservation = $validObservation.conservation }
$reducedFixture = [pscustomobject]@{ body_count = 160 }
$reducedScenario = [pscustomobject]@{ body_count_before = 156; tray_count_before = 2; solver_liveness_before = 48; conservation_before = $validObservation.conservation }
Assert-ClockContract -Condition (Test-CoinPusherReducedSampleBoundary -Fixture $reducedFixture -Boundary $reducedBoundary -ScenarioTags $reducedScenario) -Message "Known 160-boundary/156-sample transition was rejected."
$reducedCountMismatch = $reducedScenario.PSObject.Copy()
$reducedCountMismatch.body_count_before = 155
Assert-ClockContract -Condition (-not (Test-CoinPusherReducedSampleBoundary -Fixture $reducedFixture -Boundary $reducedBoundary -ScenarioTags $reducedCountMismatch)) -Message "Reduced sample body-count mismatch was accepted."
$reducedTrayMismatch = $reducedScenario.PSObject.Copy()
$reducedTrayMismatch.tray_count_before = 1
Assert-ClockContract -Condition (-not (Test-CoinPusherReducedSampleBoundary -Fixture $reducedFixture -Boundary $reducedBoundary -ScenarioTags $reducedTrayMismatch)) -Message "Reduced sample tray-count mismatch was accepted."
$reducedLivenessMismatch = $reducedScenario.PSObject.Copy()
$reducedLivenessMismatch.solver_liveness_before = 49
Assert-ClockContract -Condition (-not (Test-CoinPusherReducedSampleBoundary -Fixture $reducedFixture -Boundary $reducedBoundary -ScenarioTags $reducedLivenessMismatch)) -Message "Reduced sample liveness-boundary mismatch was accepted."
$reducedAfterMismatch = [pscustomobject]@{ body_count_after = 155; tray_count_after = 2; conservation_after = $validObservation.conservation }
Assert-ClockContract -Condition (-not (Test-CoinPusherSurfaceConservationBinding -BodyCount $reducedAfterMismatch.body_count_after -TrayCount $reducedAfterMismatch.tray_count_after -Snapshot $reducedAfterMismatch.conservation_after -ExpectedOrigin $CoinPusherShippedBodyCount)) -Message "Reduced after-state surface/conservation mismatch was accepted."
$validReducedEvidence = [pscustomobject]@{
    frame_time_ms = [pscustomobject]@{ count = 120 }
    tags = [pscustomobject]@{
        solver_liveness_delta = 480; solver_liveness_before = 48
        body_count_before = 156; body_count_after = 150
        tray_count_before = 2; tray_count_after = 0
        conservation_before = $validObservation.conservation
        conservation_after = $validObservation.conservation
        redraw_delta = 0
        canvas_after = [pscustomobject]@{ surface_animation_liveness_active = $false; draw_sample_count = 120; draw_p95_ms = 4.5 }
    }
}
Assert-ClockContract -Condition (Test-CoinPusherReducedEvidenceSchema -Scenario $validReducedEvidence) -Message "Complete reduced evidence schema was rejected."
$missingReducedTrayAfter = $validReducedEvidence.PSObject.Copy()
$missingReducedTrayAfter.tags = $validReducedEvidence.tags.PSObject.Copy()
$missingReducedTrayAfter.tags.PSObject.Properties.Remove("tray_count_after")
Assert-ClockContract -Condition (-not (Test-CoinPusherReducedEvidenceSchema -Scenario $missingReducedTrayAfter)) -Message "Missing zero-valued reduced tray-after field was accepted."
$missingReducedScheduler = $validReducedEvidence.PSObject.Copy()
$missingReducedScheduler.tags = $validReducedEvidence.tags.PSObject.Copy()
$missingReducedScheduler.tags.PSObject.Properties.Remove("redraw_delta")
Assert-ClockContract -Condition (-not (Test-CoinPusherReducedEvidenceSchema -Scenario $missingReducedScheduler)) -Message "Missing reduced scheduler field was accepted."
$missingReducedDraw = $validReducedEvidence.PSObject.Copy()
$missingReducedDraw.tags = $validReducedEvidence.tags.PSObject.Copy()
$missingReducedDraw.tags.canvas_after = $validReducedEvidence.tags.canvas_after.PSObject.Copy()
$missingReducedDraw.tags.canvas_after.PSObject.Properties.Remove("draw_sample_count")
Assert-ClockContract -Condition (-not (Test-CoinPusherReducedEvidenceSchema -Scenario $missingReducedDraw)) -Message "Missing reduced draw field was accepted."

$validCollect = [pscustomobject]@{
    body_count_at_accept = 159
    body_count_after = 155
    tray_count_at_accept = 0
    tray_count_after = 2
    tray_value_at_accept = 0
    conservation_at_accept = [pscustomobject]@{
        active = 159; tray = 0; gutter = 0; collected = 1; cup_consumed = 0
        origin = 160; accounted = 160; conservation_ok = $true; solver_invariants_present = $true; solver_conservation_ok = $true
    }
    conservation_after = [pscustomobject]@{
        active = 155; tray = 2; gutter = 2; collected = 1; cup_consumed = 0
        origin = 160; accounted = 160; conservation_ok = $true; solver_invariants_present = $true; solver_conservation_ok = $true
    }
}
Assert-ClockContract -Condition ([bool](Get-CoinPusherPostCollectAccounting -Tags $validCollect).valid) -Message "Legitimate post-COLLECT exits were rejected."
$fabricatedCollect = $validCollect.PSObject.Copy()
$fabricatedCollect.tray_count_after = 5
Assert-ClockContract -Condition (-not [bool](Get-CoinPusherPostCollectAccounting -Tags $fabricatedCollect).valid) -Message "Fabricated post-COLLECT tray result was accepted."
$droppedCollect = $validCollect.PSObject.Copy()
$droppedCollect.conservation_after = $validCollect.conservation_after.PSObject.Copy()
$droppedCollect.conservation_after.gutter = 1
$droppedCollect.conservation_after.accounted = 159
Assert-ClockContract -Condition (-not [bool](Get-CoinPusherPostCollectAccounting -Tags $droppedCollect).valid) -Message "Dropped post-COLLECT outcome channel was accepted."
$collectAcceptMismatch = $validCollect.PSObject.Copy()
$collectAcceptMismatch.body_count_at_accept = 158
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
