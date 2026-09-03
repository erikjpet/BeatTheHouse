$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "web_perf_prestage_contract.ps1")

function Assert-PrestageContract {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-ActiveElapsedModelMsec {
    param([int[]]$SampleUsec, [bool[]]$ActiveSamples)
    if ($SampleUsec.Count -ne $ActiveSamples.Count -or $SampleUsec.Count -lt 2) {
        throw "Elapsed model requires paired timestamps and activity samples."
    }
    $elapsedMsec = 0.0
    $priorUsec = $SampleUsec[0]
    for ($index = 1; $index -lt $SampleUsec.Count; $index++) {
        $nowUsec = $SampleUsec[$index]
        if ($ActiveSamples[$index]) {
            $elapsedMsec += [Math]::Max(0, $nowUsec - $priorUsec) / 1000.0
        }
        $priorUsec = $nowUsec
    }
    return $elapsedMsec
}

function New-ActivePhaseScenario {
    param(
        [string]$Channel = "baccarat_deal",
        [bool]$ActiveAtStart = $true,
        [int]$ActiveFrames = 18,
        [int]$LongestFrames = 18,
        [double]$ActiveMsec = 750.0
    )
    return [pscustomobject]@{
        tags = [pscustomobject]@{
            active_phase_evidence = [pscustomobject]@{
                channel_id = $Channel
                active_at_start = $ActiveAtStart
                active_at_end = $false
                sample_frames = 60
                active_frame_count = $ActiveFrames
                longest_consecutive_active_frames = $LongestFrames
                active_elapsed_msec = $ActiveMsec
            }
        }
    }
}

function New-CornerStoreReport {
    $startup = [pscustomobject]@{
        id = "corner_store_startup_timing"
        data = [pscustomobject]@{
            foundation_run_start_ms = 120.0
            post_start_settle_ms = 160.0
            choice_build_ms = 1.0
            travel_ms = 400.0
            total_ms = 681.0
        }
    }
    $travel = [pscustomobject]@{
        id = "corner_store_travel_stage_timing"
        data = [pscustomobject]@{
            target_id = "corner_store"
            total_ms = 399.5
            stages = [pscustomobject]@{
                lifecycle_snapshot_ms = 20.0
                route_preflight_ms = 25.0
                route_clock_ms = 5.0
                destination_generation_install_ms = 250.0
                destination_postprocess_ms = 35.0
                result_commit_save_ms = 45.0
                triggered_events_refresh_ms = 19.0
            }
        }
    }
    return [pscustomobject]@{ events = @($travel, $startup) }
}

$validBaccarat = Get-WebPerfActivePhaseEvaluation -Scenario (New-ActivePhaseScenario) -ExpectedChannel "baccarat_deal"
Assert-PrestageContract -Condition ([bool]$validBaccarat.passed) -Message "A sustained Baccarat deal phase was rejected."

$wrongChannel = Get-WebPerfActivePhaseEvaluation -Scenario (New-ActivePhaseScenario -Channel "baccarat_payout") -ExpectedChannel "baccarat_deal"
Assert-PrestageContract -Condition (-not [bool]$wrongChannel.passed -and -not [bool]$wrongChannel.channel_matches) -Message "The wrong Baccarat phase passed."

$latePhase = Get-WebPerfActivePhaseEvaluation -Scenario (New-ActivePhaseScenario -ActiveAtStart $false) -ExpectedChannel "baccarat_deal"
Assert-PrestageContract -Condition (-not [bool]$latePhase.passed) -Message "A phase absent at the action boundary passed."

$shortFrames = Get-WebPerfActivePhaseEvaluation -Scenario (New-ActivePhaseScenario -ActiveFrames 11 -LongestFrames 11) -ExpectedChannel "baccarat_deal"
Assert-PrestageContract -Condition (-not [bool]$shortFrames.passed -and -not [bool]$shortFrames.frame_window_passed) -Message "A short active frame window passed."

$shortElapsed = Get-WebPerfActivePhaseEvaluation -Scenario (New-ActivePhaseScenario -ActiveMsec 499.9) -ExpectedChannel "baccarat_deal"
Assert-PrestageContract -Condition (-not [bool]$shortElapsed.passed -and -not [bool]$shortElapsed.elapsed_window_passed) -Message "A short active elapsed-time window passed."

$linearElapsed = Get-ActiveElapsedModelMsec -SampleUsec @(0, 100000, 200000, 300000) -ActiveSamples @($false, $true, $true, $true)
Assert-PrestageContract -Condition ([Math]::Abs($linearElapsed - 300.0) -lt 0.001) -Message "Sustained active elapsed time was triangularly overcounted."
$gappedElapsed = Get-ActiveElapsedModelMsec -SampleUsec @(0, 100000, 350000, 500000) -ActiveSamples @($false, $true, $false, $true)
Assert-PrestageContract -Condition ([Math]::Abs($gappedElapsed - 250.0) -lt 0.001) -Message "Inactive gaps leaked into active elapsed time."

$validCorner = Get-WebPerfCornerStoreTimingEvaluation -Report (New-CornerStoreReport)
Assert-PrestageContract -Condition ([bool]$validCorner.passed) -Message "Complete Corner Store stage evidence was rejected."

$missingStageReport = New-CornerStoreReport
$missingStageReport.events[0].data.stages.PSObject.Properties.Remove("route_clock_ms")
$missingStage = Get-WebPerfCornerStoreTimingEvaluation -Report $missingStageReport
Assert-PrestageContract -Condition (-not [bool]$missingStage.passed -and -not [bool]$missingStage.travel_schema_present) -Message "Missing Corner Store stage evidence passed."

$smokeSource = Get-Content -LiteralPath (Join-Path $PSScriptRoot "web_perf_smoke.ps1") -Raw
Assert-PrestageContract -Condition ($smokeSource -match "Get-WebPerfActivePhaseEvaluation" -and $smokeSource -match "Get-WebPerfCornerStoreTimingEvaluation") -Message "The Web smoke does not consume the prestage contract."
$overlaySource = Get-Content -LiteralPath (Join-Path $PSScriptRoot "../scripts/ui/perf_telemetry_overlay.gd") -Raw
Assert-PrestageContract -Condition ($overlaySource -match '"baccarat": "baccarat_deal"' -and $overlaySource -match '"roulette": "roulette_spin"') -Message "The runtime probe no longer names the production Baccarat/Roulette phases."
Assert-PrestageContract -Condition ($overlaySource -match '(?ms)if active:.*?active_elapsed_msec \+=.*?else:\s+consecutive_active_frames = 0\s+prior_usec = now_usec') -Message "The runtime probe no longer advances its elapsed-time baseline on every sampled frame."

Write-Host "Web performance prestage contract: PASS"
