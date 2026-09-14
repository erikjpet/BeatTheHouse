$ErrorActionPreference = "Stop"
$root = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
. (Join-Path $PSScriptRoot "perf06_phase_qualification_contract.ps1")
$budget = Get-Content -LiteralPath (Join-Path $PSScriptRoot "perf06_budget_table.json") -Raw | ConvertFrom-Json

function New-Scenario {
    param(
        [string]$Surface = "pull_tabs",
        [string]$Phase = "idle",
        [string]$Mode = "idle",
        [int]$Frames = 120,
        [int]$Redraws = 8,
        [double]$DrawP95 = 4.0,
        [double]$FrameP95 = 10.0,
        [double]$ResolveMs = 0.0
    )
    return [pscustomobject]@{
        name = if ($Surface -eq "coin_pusher") { "coin_pusher_active_$Phase" } else { "${Surface}_$Phase" }
        tags = [pscustomobject]@{
            perf06_surface_id = $Surface
            perf06_phase_id = $Phase
            mode = $Mode
            resolve_call_ms = $ResolveMs
        }
        frame_time_ms = [pscustomobject]@{ count=$Frames; avg=8.0; p95=$FrameP95; max=12.0 }
        surface_draw_time_ms = [pscustomobject]@{ count=$Frames; avg_ms=2.0; p95_ms=$DrawP95; max_ms=5.0 }
        liveness_counter_delta = [pscustomobject]@{
            game_surface = [pscustomobject]@{ surface_animation_redraw_count=$Redraws; surface_animation_scheduler_elapsed_msec=2000; surface_idle_animation_fps=4.0; draw_sample_count=$Redraws }
            environment_scene = [pscustomobject]@{ scene_idle_animation_redraw_count=0 }
        }
    }
}

$goodIdle = New-Scenario
$goodLive = Get-Perf06PhaseLivenessEvaluation -Scenario $goodIdle -Platform native -BudgetTable $budget
if (-not $goodLive.passed -or $goodLive.floor -ne 8 -or $goodLive.measured -ne 8) { throw "Published native 8-per-120 liveness floor did not pass exactly." }
$frozenIdle = New-Scenario -Redraws 7
if ((Get-Perf06PhaseLivenessEvaluation -Scenario $frozenIdle -Platform native -BudgetTable $budget).passed) { throw "Below-floor native idle liveness was accepted." }
$forgedStaticIdle = New-Scenario -Surface slot -Phase idle -Redraws 0 -DrawP95 1.4
$forgedStaticIdle.tags | Add-Member -NotePropertyName accepted_zero_liveness_reason -NotePropertyValue "No authored idle animation." -Force
$forgedStaticLive = Get-Perf06PhaseLivenessEvaluation -Scenario $forgedStaticIdle -Platform native -BudgetTable $budget
if ($forgedStaticLive.passed -or $forgedStaticLive.floor -ne 8) { throw "Caller-authored static-zero text bypassed the contract-owned idle liveness floor." }
$forgedRoulette = New-Scenario -Surface roulette -Phase betting_idle -Redraws 0
$forgedRoulette.tags | Add-Member -NotePropertyName accepted_zero_liveness_reason -NotePropertyValue "Trust me." -Force
if ((Get-Perf06PhaseLivenessEvaluation -Scenario $forgedRoulette -Platform native -BudgetTable $budget).passed) { throw "Animated Roulette idle accepted caller-authored zero-liveness authority." }
$environmentIdle = New-Scenario -Surface room_environment -Phase quiet_idle -Redraws 0
$environmentIdle.liveness_counter_delta.environment_scene.scene_idle_animation_redraw_count = 8
$environmentLive = Get-Perf06PhaseLivenessEvaluation -Scenario $environmentIdle -Platform native -BudgetTable $budget
if (-not $environmentLive.passed -or $environmentLive.counter -cne "scene_idle_animation_redraw_count") { throw "Native environment idle used a synthetic game counter instead of its published scene liveness floor." }

$goodBudget = Get-Perf06PhaseBudgetEvaluation -Scenario $goodIdle -Platform native -BudgetTable $budget -Plan l02
if (-not $goodBudget.passed -or @($goodBudget.checks).Count -eq 0) { throw "Published native draw budget was not evaluated." }
$slowIdle = New-Scenario -DrawP95 5.1
if ((Get-Perf06PhaseBudgetEvaluation -Scenario $slowIdle -Platform native -BudgetTable $budget -Plan l02).passed) { throw "Native draw p95 above the unchanged 5ms cap was accepted." }

$missingProgress = New-Scenario -Surface slot -Phase spin -Mode active
if ((Get-Perf06PhaseProgressEvaluation -SurfaceId slot -PhaseId spin -Evidence $missingProgress.tags).passed) { throw "Active phase omitted all progress evidence and passed." }
$missingProgress.tags | Add-Member -NotePropertyName action_evidence -NotePropertyValue ([pscustomobject]@{ accepted=$true; progressed=$true }) -Force
if (-not (Get-Perf06PhaseProgressEvaluation -SurfaceId slot -PhaseId spin -Evidence $missingProgress.tags).passed) { throw "Observed accepted active action did not satisfy progress evidence." }
$missingProgress.tags.action_evidence.progressed = $false
if ((Get-Perf06PhaseProgressEvaluation -SurfaceId slot -PhaseId spin -Evidence $missingProgress.tags).passed) { throw "Rejected active progress evidence passed." }

$goodPusher = New-Scenario -Surface coin_pusher -Phase drop -Mode active -Frames 240 -Redraws 0 -DrawP95 6.9 -FrameP95 21.9 -ResolveMs 15.9
$goodPusherBudget = Get-Perf06PhaseBudgetEvaluation -Scenario $goodPusher -Platform native -BudgetTable $budget -Plan coin_pusher
if (-not $goodPusherBudget.passed -or @($goodPusherBudget.checks).Count -ne 3) { throw "Native Coin Pusher did not evaluate draw/frame/action caps together." }
foreach ($mutation in @(
    @{ draw=7.1; frame=21.9; resolve=15.9 },
    @{ draw=6.9; frame=22.1; resolve=15.9 },
    @{ draw=6.9; frame=21.9; resolve=16.1 }
)) {
    $bad = New-Scenario -Surface coin_pusher -Phase drop -Mode active -Frames 240 -DrawP95 $mutation.draw -FrameP95 $mutation.frame -ResolveMs $mutation.resolve
    if ((Get-Perf06PhaseBudgetEvaluation -Scenario $bad -Platform native -BudgetTable $budget -Plan coin_pusher).passed) { throw "A native Coin Pusher timing cap was weakened." }
}

$nativeLauncher = Get-Content -LiteralPath (Join-Path $PSScriptRoot "perf06_native_runtime_matrix.ps1") -Raw
foreach ($token in @("Get-Perf06PhaseBudgetEvaluation", "Get-Perf06PhaseLivenessEvaluation", 'passed = $qualificationFailures.Count -eq 0', "PERF06 NATIVE RUNTIME FAIL")) {
    if (-not $nativeLauncher.Contains($token)) { throw "Native launcher is missing fail-closed qualification token '$token'." }
}
if ($nativeLauncher.Contains('passed = $true')) { throw "Native launcher still hard-codes a passing result." }

$builder = Get-Content -LiteralPath (Join-Path $PSScriptRoot "perf06_build_surface_report.ps1") -Raw
if ($builder.Contains('floor=if ($measured -gt 0) { 1 } else { 0 }')) { throw "Surface builder still replaces published liveness floors with one tick." }
foreach ($token in @("budget_evaluation =", "progress_evaluation =", "liveness = `$livenessEvaluation", "Get-Perf06PhaseBudgetEvaluation", "Get-Perf06PhaseProgressEvaluation")) {
    if (-not $builder.Contains($token)) { throw "Surface builder lost qualification evidence '$token'." }
}

$consumer = Get-Content -LiteralPath (Join-Path $PSScriptRoot "perf06_matrix_contract.ps1") -Raw
foreach ($token in @('liveness.measured -lt [int]$Row.liveness.floor', 'observed -gt [double]$check.maximum', 'budget_evaluation', 'progress_evaluation', 'active phase has no passing retained progress evidence')) {
    if (-not $consumer.Contains($token)) { throw "Final consumer lost fail-closed check '$token'." }
}

Write-Host "PERF06 PHASE QUALIFICATION CONTRACT PASS native_liveness_floor=$($goodLive.floor) pusher_checks=$(@($goodPusherBudget.checks).Count)"
