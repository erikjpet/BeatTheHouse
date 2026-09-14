function Test-WebPerfIdlePropertiesPresent {
    param([object]$Value, [string[]]$Names)
    if ($null -eq $Value) { return $false }
    foreach ($name in $Names) {
        $property = $Value.PSObject.Properties[$name]
        if ($null -eq $property -or $null -eq $property.Value) { return $false }
    }
    return $true
}

function Get-WebPerfIdleMinimumWindowMsec {
    param([double]$DeclaredFps, [int]$MinimumIntervals = 2)
    if ($DeclaredFps -le 0.0 -or $MinimumIntervals -le 0) { return 0 }
    return [int][Math]::Ceiling(([double]$MinimumIntervals * 1000.0) / $DeclaredFps)
}

function Get-WebPerfIdleRequiredRedraws {
    param([double]$ElapsedMsec, [double]$DeclaredFps)
    if ($ElapsedMsec -le 0.0 -or $DeclaredFps -le 0.0) { return 0 }
    return [int][Math]::Floor(($ElapsedMsec * $DeclaredFps) / 1000.0)
}

function Get-WebPerfIdleLivenessEvaluation {
    param([object]$Scenario, [int]$MinimumIntervals = 2)
    $evaluation = [ordered]@{
        schema_present = $false
        cadence_stable = $false
        declared_fps = 0.0
        scheduler_elapsed_msec = 0
        minimum_window_msec = 0
        window_complete = $false
        redraw_delta = 0
        required_redraws = 0
        redraw_cadence_passed = $false
        draw_sample_delta = 0
        paired_draw_passed = $false
        passed = $false
    }
    if (-not (Test-WebPerfIdlePropertiesPresent -Value $Scenario -Names @("liveness_counters_start", "liveness_counters", "liveness_counter_delta"))) {
        return [pscustomobject]$evaluation
    }
    $start = $Scenario.liveness_counters_start.game_surface
    $after = $Scenario.liveness_counters.game_surface
    $delta = $Scenario.liveness_counter_delta.game_surface
    $counterNames = @("surface_idle_animation_fps", "surface_animation_scheduler_elapsed_msec", "surface_animation_redraw_count", "draw_sample_count")
    $deltaNames = @("surface_idle_animation_fps", "surface_animation_scheduler_elapsed_msec", "surface_animation_redraw_count", "draw_sample_count")
    if (-not (Test-WebPerfIdlePropertiesPresent -Value $start -Names $counterNames) `
            -or -not (Test-WebPerfIdlePropertiesPresent -Value $after -Names $counterNames) `
            -or -not (Test-WebPerfIdlePropertiesPresent -Value $delta -Names $deltaNames)) {
        return [pscustomobject]$evaluation
    }
    $evaluation.schema_present = $true
    $startFps = [double]$start.surface_idle_animation_fps
    $declaredFps = [double]$after.surface_idle_animation_fps
    $deltaFps = [double]$delta.surface_idle_animation_fps
    $evaluation.declared_fps = $declaredFps
    $evaluation.cadence_stable = $declaredFps -gt 0.0 `
        -and [Math]::Abs($startFps - $declaredFps) -lt 0.0001 `
        -and [Math]::Abs($deltaFps - $declaredFps) -lt 0.0001
    $elapsedMsec = [int]$delta.surface_animation_scheduler_elapsed_msec
    $evaluation.scheduler_elapsed_msec = $elapsedMsec
    $minimumWindowMsec = Get-WebPerfIdleMinimumWindowMsec -DeclaredFps $declaredFps -MinimumIntervals $MinimumIntervals
    $evaluation.minimum_window_msec = $minimumWindowMsec
    $evaluation.window_complete = $evaluation.cadence_stable -and $elapsedMsec -ge $minimumWindowMsec
    $redrawDelta = [int]$delta.surface_animation_redraw_count
    $requiredRedraws = Get-WebPerfIdleRequiredRedraws -ElapsedMsec $elapsedMsec -DeclaredFps $declaredFps
    $evaluation.redraw_delta = $redrawDelta
    $evaluation.required_redraws = $requiredRedraws
    $evaluation.redraw_cadence_passed = $evaluation.window_complete `
        -and $requiredRedraws -ge $MinimumIntervals `
        -and $redrawDelta -ge $requiredRedraws
    $drawSampleDelta = [int]$delta.draw_sample_count
    $evaluation.draw_sample_delta = $drawSampleDelta
    $evaluation.paired_draw_passed = $evaluation.redraw_cadence_passed -and $drawSampleDelta -gt 0
    $evaluation.passed = $evaluation.schema_present -and $evaluation.cadence_stable `
        -and $evaluation.window_complete -and $evaluation.redraw_cadence_passed `
        -and $evaluation.paired_draw_passed
    return [pscustomobject]$evaluation
}
