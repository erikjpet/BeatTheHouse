function Test-Perf06ValueProperty {
    param([object]$Value, [string]$Name)
    return $null -ne $Value -and $null -ne $Value.PSObject.Properties[$Name] -and $null -ne $Value.PSObject.Properties[$Name].Value
}

function New-Perf06BudgetCheck {
    param([string]$Metric, [double]$Observed, [double]$Maximum)
    return [pscustomobject][ordered]@{
        metric = $Metric
        observed = $Observed
        maximum = $Maximum
        passed = $Observed -le $Maximum
    }
}

function Test-Perf06IdlePhase {
    param([string]$SurfaceId, [string]$PhaseId)
    $idlePhases = @{
        pull_tabs = @("idle")
        scratch_tickets = @("idle")
        slot = @("idle")
        bar_dice = @("idle")
        blackjack = @("betting_idle")
        baccarat = @("betting_idle")
        craps = @("idle")
        roulette = @("betting_idle")
        crew_draw_poker = @("actor_idle")
        video_poker = @("idle")
        coin_pusher = @("cap_idle")
        meta_home = @("animated_idle")
        room_environment = @("quiet_idle")
        crew = @("actor_idle")
        world = @("map_idle")
        audio = @("quiet_idle")
    }
    return $idlePhases.ContainsKey($SurfaceId) -and $idlePhases[$SurfaceId] -ccontains $PhaseId
}

function Get-Perf06PhaseProgressEvaluation {
    param(
        [Parameter(Mandatory = $true)][string]$SurfaceId,
        [Parameter(Mandatory = $true)][string]$PhaseId,
        [Parameter(Mandatory = $true)][object]$Evidence
    )
    if (Test-Perf06IdlePhase $SurfaceId $PhaseId) {
        return [pscustomobject][ordered]@{ applicable=$false; checks=@(); passed=$true }
    }
    $checks = [Collections.Generic.List[object]]::new()
    if (Test-Perf06ValueProperty $Evidence "action_evidence") {
        $value = $Evidence.action_evidence
        $checks.Add([pscustomobject][ordered]@{ kind="action_evidence"; passed=([bool]$value.accepted -and [bool]$value.progressed) })
    }
    if (Test-Perf06ValueProperty $Evidence "phase_evidence") {
        $value = $Evidence.phase_evidence
        $checks.Add([pscustomobject][ordered]@{ kind="phase_evidence"; passed=[bool]$value.observed })
    }
    if (Test-Perf06ValueProperty $Evidence "active_phase_evidence") {
        $value = $Evidence.active_phase_evidence
        $checks.Add([pscustomobject][ordered]@{ kind="active_phase_evidence"; passed=[bool]$value.coverage_passed })
    }
    return [pscustomobject][ordered]@{
        applicable = $true
        checks = @($checks)
        passed = $checks.Count -gt 0 -and @($checks | Where-Object { -not [bool]$_.passed }).Count -eq 0
    }
}

function Get-Perf06PhaseLivenessEvaluation {
    param(
        [Parameter(Mandatory = $true)][object]$Scenario,
        [Parameter(Mandatory = $true)][ValidateSet("native", "web")][string]$Platform,
        [Parameter(Mandatory = $true)][object]$BudgetTable
    )
    $tags = $Scenario.tags
    $surfaceId = [string]$tags.perf06_surface_id
    $phaseId = [string]$tags.perf06_phase_id
    $isIdle = Test-Perf06IdlePhase $surfaceId $phaseId
    if (-not $isIdle) {
        return [pscustomobject][ordered]@{
            counter = "static_phase"
            floor = 0
            measured = 0
            zero_reason = "Synchronous/static action phase; production action progress is required instead."
            source = "not_applicable"
            passed = $true
        }
    }

    $game = $Scenario.liveness_counter_delta.game_surface
    $environment = $Scenario.liveness_counter_delta.environment_scene
    $gameIds = @($BudgetTable.native.resolve_ms.PSObject.Properties.Name) + @("coin_pusher")
    $isGameSurface = $gameIds -ccontains $surfaceId
    $gameCounterPresent = $isGameSurface -and (Test-Perf06ValueProperty $game "surface_animation_redraw_count")
    $environmentCounterPresent = (-not $isGameSurface) -and (Test-Perf06ValueProperty $environment "scene_idle_animation_redraw_count")
    $counter = if ($gameCounterPresent) { "surface_animation_redraw_count" } elseif ($environmentCounterPresent) { "scene_idle_animation_redraw_count" } else { "" }
    $measured = if ($gameCounterPresent) { [int]$game.surface_animation_redraw_count } elseif ($environmentCounterPresent) { [int]$environment.scene_idle_animation_redraw_count } else { 0 }
    $floor = 0
    $source = "missing"
    if ($Platform -eq "native") {
        $frames = [int]$Scenario.frame_time_ms.count
        $per120 = [int]$BudgetTable.native.animated_idle_liveness_minimum_per_120_frames
        if ($frames -gt 0 -and $per120 -gt 0) {
            $floor = [Math]::Max(1, [int][Math]::Ceiling(([double]$frames * [double]$per120) / 120.0))
            $source = "perf06_budget_table.native.animated_idle_liveness_minimum_per_120_frames"
        }
    } elseif ($gameCounterPresent -and (Test-Perf06ValueProperty $game "surface_idle_animation_fps") -and (Test-Perf06ValueProperty $game "surface_animation_scheduler_elapsed_msec")) {
        $declaredFps = [double]$game.surface_idle_animation_fps
        $elapsedMsec = [double]$game.surface_animation_scheduler_elapsed_msec
        if ($declaredFps -gt 0.0 -and $elapsedMsec -gt 0.0) {
            $floor = [Math]::Max(1, [int][Math]::Floor(($elapsedMsec * $declaredFps) / 1000.0))
            $source = "production_scheduler_elapsed_x_declared_fps"
        }
    } elseif ($environmentCounterPresent) {
        $frames = [int]$Scenario.frame_time_ms.count
        $per120 = [int]$BudgetTable.native.animated_idle_liveness_minimum_per_120_frames
        if ($frames -gt 0 -and $per120 -gt 0) {
            $floor = [Math]::Max(1, [int][Math]::Ceiling(([double]$frames * [double]$per120) / 120.0))
            $source = "published_environment_idle_floor"
        }
    }

    $passed = -not [string]::IsNullOrWhiteSpace($counter) -and $floor -gt 0 -and $measured -ge $floor
    return [pscustomobject][ordered]@{
        counter = $counter
        floor = $floor
        measured = $measured
        zero_reason = ""
        source = $source
        passed = $passed
    }
}

function Get-Perf06PhaseBudgetEvaluation {
    param(
        [Parameter(Mandatory = $true)][object]$Scenario,
        [Parameter(Mandatory = $true)][ValidateSet("native", "web")][string]$Platform,
        [Parameter(Mandatory = $true)][object]$BudgetTable,
        [string]$Plan = ""
    )
    $tags = $Scenario.tags
    $surfaceId = [string]$tags.perf06_surface_id
    $phaseId = [string]$tags.perf06_phase_id
    $isIdle = Test-Perf06IdlePhase $surfaceId $phaseId
    $checks = [Collections.Generic.List[object]]::new()

    if ($Platform -eq "native") {
        $gameIds = @($BudgetTable.native.resolve_ms.PSObject.Properties.Name) + @("coin_pusher")
        if ($gameIds -ccontains $surfaceId) {
            $drawMaximum = [double]$BudgetTable.native.surface_draw_p95_ms
            if ($surfaceId -ceq "coin_pusher" -and $phaseId -in @("drop", "carriage", "skill_stop", "skill_release", "collect")) {
                $drawMaximum = [double]$BudgetTable.native.coin_pusher.active_draw_p95_ms
            } elseif ($isIdle -and $BudgetTable.native.animated_idle_surface_draw_p95_ms.PSObject.Properties.Name -ccontains $surfaceId) {
                $drawMaximum = [double]$BudgetTable.native.animated_idle_surface_draw_p95_ms.PSObject.Properties[$surfaceId].Value
            }
            if (Test-Perf06ValueProperty $Scenario "surface_draw_time_ms") {
                $checks.Add((New-Perf06BudgetCheck "draw_p95_ms" ([double]$Scenario.surface_draw_time_ms.p95_ms) $drawMaximum))
            }
        }
        if ($surfaceId -ceq "coin_pusher" -and $phaseId -in @("drop", "carriage", "skill_stop", "skill_release", "collect")) {
            $checks.Add((New-Perf06BudgetCheck "frame_p95_ms" ([double]$Scenario.frame_time_ms.p95) ([double]$BudgetTable.native.coin_pusher.active_frame_p95_ms)))
            if (Test-Perf06ValueProperty $tags "resolve_call_ms") {
                $checks.Add((New-Perf06BudgetCheck "resolve_call_ms" ([double]$tags.resolve_call_ms) ([double]$BudgetTable.native.coin_pusher.active_action_ms)))
            }
        }
        if ($surfaceId -ceq "coin_pusher" -and $phaseId -ceq "raw_solver" -and (Test-Perf06ValueProperty $tags "raw_solver_timing")) {
            $checks.Add((New-Perf06BudgetCheck "solver_tick_p95_ms" ([double]$tags.raw_solver_timing.p95) ([double]$BudgetTable.native.coin_pusher.solver_tick_p95_ms)))
        }
    } else {
        $planBudgets = $BudgetTable.web_frame_p95_ms.PSObject.Properties[$Plan].Value
        $scenarioName = [string]$Scenario.name
        if ($null -ne $planBudgets -and $planBudgets.PSObject.Properties.Name -ccontains $scenarioName) {
            $checks.Add((New-Perf06BudgetCheck "frame_p95_ms" ([double]$Scenario.frame_time_ms.p95) ([double]$planBudgets.PSObject.Properties[$scenarioName].Value)))
        }
        if ($surfaceId -ceq "coin_pusher" -and $phaseId -in @("cap_idle", "drop", "carriage", "skill_stop", "skill_release", "collect")) {
            $drawMaximum = if ($phaseId -in @("drop", "carriage", "skill_stop", "skill_release", "collect")) { [double]$BudgetTable.native.coin_pusher.active_draw_p95_ms } else { [double]$BudgetTable.native.surface_draw_p95_ms }
            if (Test-Perf06ValueProperty $Scenario "surface_draw_time_ms") {
                $checks.Add((New-Perf06BudgetCheck "draw_p95_ms" ([double]$Scenario.surface_draw_time_ms.p95_ms) $drawMaximum))
            }
            if (Test-Perf06ValueProperty $tags "resolve_call_ms") {
                $checks.Add((New-Perf06BudgetCheck "resolve_call_ms" ([double]$tags.resolve_call_ms) ([double]$BudgetTable.native.coin_pusher.active_action_ms)))
            }
        }
    }

    return [pscustomobject][ordered]@{
        budget_table_version = [int]$BudgetTable.version
        applicable = $checks.Count -gt 0
        checks = @($checks)
        passed = @($checks | Where-Object { -not [bool]$_.passed }).Count -eq 0
    }
}
