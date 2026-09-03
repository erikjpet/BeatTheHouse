$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "web_perf_idle_liveness_contract.ps1")

function Assert-IdleContract {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function New-IdleScenario {
    param(
        [double]$StartFps = 1.0,
        [double]$EndFps = 1.0,
        [int]$ElapsedMsec = 2000,
        [int]$Redraws = 2,
        [int]$Draws = 2
    )
    return [pscustomobject]@{
        liveness_counters_start = [pscustomobject]@{
            game_surface = [pscustomobject]@{
                surface_idle_animation_fps = $StartFps
                surface_animation_scheduler_elapsed_msec = 100
                surface_animation_redraw_count = 5
                draw_sample_count = 7
            }
        }
        liveness_counters = [pscustomobject]@{
            game_surface = [pscustomobject]@{
                surface_idle_animation_fps = $EndFps
                surface_animation_scheduler_elapsed_msec = 100 + $ElapsedMsec
                surface_animation_redraw_count = 5 + $Redraws
                draw_sample_count = 7 + $Draws
            }
        }
        liveness_counter_delta = [pscustomobject]@{
            game_surface = [pscustomobject]@{
                surface_idle_animation_fps = $EndFps
                surface_animation_scheduler_elapsed_msec = $ElapsedMsec
                surface_animation_redraw_count = $Redraws
                draw_sample_count = $Draws
            }
        }
    }
}

Assert-IdleContract -Condition ((Get-WebPerfIdleMinimumWindowMsec -DeclaredFps 1.0) -eq 2000) -Message "The production 1 Hz cadence did not require two complete intervals."
Assert-IdleContract -Condition ((Get-WebPerfIdleMinimumWindowMsec -DeclaredFps 15.0) -eq 134) -Message "The declared 15 Hz cadence did not produce a two-interval window."
Assert-IdleContract -Condition ((Get-WebPerfIdleRequiredRedraws -ElapsedMsec 2500 -DeclaredFps 1.0) -eq 2) -Message "Elapsed-time redraw floor lost the declared cadence."

$validOneHertz = Get-WebPerfIdleLivenessEvaluation -Scenario (New-IdleScenario -ElapsedMsec 2500 -Redraws 2 -Draws 2)
Assert-IdleContract -Condition ([bool]$validOneHertz.passed) -Message "A live two-interval 1 Hz sample was rejected."

$validFifteenHertz = Get-WebPerfIdleLivenessEvaluation -Scenario (New-IdleScenario -StartFps 15 -EndFps 15 -ElapsedMsec 600 -Redraws 9 -Draws 9)
Assert-IdleContract -Condition ([bool]$validFifteenHertz.passed -and [int]$validFifteenHertz.required_redraws -eq 9) -Message "A live elapsed-time 15 Hz sample was rejected."

$shortWindow = Get-WebPerfIdleLivenessEvaluation -Scenario (New-IdleScenario -ElapsedMsec 1999 -Redraws 2 -Draws 2)
Assert-IdleContract -Condition (-not [bool]$shortWindow.passed -and -not [bool]$shortWindow.window_complete) -Message "A sample shorter than two declared intervals passed."

$underCadence = Get-WebPerfIdleLivenessEvaluation -Scenario (New-IdleScenario -ElapsedMsec 3100 -Redraws 2 -Draws 2)
Assert-IdleContract -Condition (-not [bool]$underCadence.passed -and [int]$underCadence.required_redraws -eq 3) -Message "A scheduler redraw deficit passed."

$noDraw = Get-WebPerfIdleLivenessEvaluation -Scenario (New-IdleScenario -ElapsedMsec 2500 -Redraws 2 -Draws 0)
Assert-IdleContract -Condition (-not [bool]$noDraw.passed -and -not [bool]$noDraw.paired_draw_passed) -Message "Scheduled redraws without a paired production draw passed."

$cadenceChanged = Get-WebPerfIdleLivenessEvaluation -Scenario (New-IdleScenario -StartFps 1 -EndFps 8 -ElapsedMsec 2000 -Redraws 16 -Draws 16)
Assert-IdleContract -Condition (-not [bool]$cadenceChanged.passed -and -not [bool]$cadenceChanged.cadence_stable) -Message "A cadence-changing sample passed as one idle window."

$missingSchema = New-IdleScenario
$missingSchema.liveness_counter_delta.game_surface.PSObject.Properties.Remove("surface_animation_scheduler_elapsed_msec")
$missing = Get-WebPerfIdleLivenessEvaluation -Scenario $missingSchema
Assert-IdleContract -Condition (-not [bool]$missing.passed -and -not [bool]$missing.schema_present) -Message "Missing scheduler evidence passed."

$smokeSource = Get-Content -LiteralPath (Join-Path $PSScriptRoot "web_perf_smoke.ps1") -Raw
Assert-IdleContract -Condition ($smokeSource -match "Get-WebPerfIdleLivenessEvaluation") -Message "The Web smoke does not consume the focused idle-liveness contract."
Assert-IdleContract -Condition ($smokeSource -notmatch "minimumIdleRedraws") -Message "The obsolete frame-count idle floor remains in the Web smoke."
$overlaySource = Get-Content -LiteralPath (Join-Path $PSScriptRoot "../scripts/ui/perf_telemetry_overlay.gd") -Raw
Assert-IdleContract -Condition ($overlaySource -match "IDLE_LIVENESS_MINIMUM_INTERVALS := 2" -and $overlaySource -match "surface_animation_scheduler_elapsed_msec") -Message "The runtime report no longer guarantees a two-interval scheduler window."

Write-Host "Web performance idle-liveness contract: PASS"
