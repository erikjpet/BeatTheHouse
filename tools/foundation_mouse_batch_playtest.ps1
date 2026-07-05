param(
    [int]$RunCount = 2,
    [string]$OutputRoot = "",
    [string]$SeedPrefix = "M2-FUN-BATCH",
    [switch]$RequireGodot,
    [switch]$AllowRunFailures
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$singleRunner = Join-Path $PSScriptRoot "foundation_mouse_playtest.ps1"

function Get-JsonProp {
    param(
        [object]$Object,
        [string]$Name,
        [object]$Default = $null
    )
    if ($null -eq $Object) {
        return $Default
    }
    if ($Object -is [System.Collections.IDictionary] -and $Object.Contains($Name)) {
        return $Object[$Name]
    }
    $prop = $Object.PSObject.Properties[$Name]
    if ($null -eq $prop) {
        return $Default
    }
    return $prop.Value
}

function Get-BoolProp {
    param(
        [object]$Object,
        [string]$Name
    )
    return [bool](Get-JsonProp -Object $Object -Name $Name -Default $false)
}

function ConvertTo-Array {
    param([object]$Value)
    if ($null -eq $Value) {
        return @()
    }
    if ($Value -is [System.Array]) {
        return @($Value)
    }
    return @($Value)
}

function Test-PathInsideDirectory {
    param([string]$Path, [string]$Directory)
    $directoryFull = [System.IO.Path]::GetFullPath($Directory)
    if (-not $directoryFull.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
        $directoryFull += [System.IO.Path]::DirectorySeparatorChar
    }
    $pathFull = [System.IO.Path]::GetFullPath($Path)
    return $pathFull.StartsWith($directoryFull, [System.StringComparison]::OrdinalIgnoreCase)
}

function Remove-StaleRunReports {
    param(
        [string]$Directory,
        [string]$Pattern,
        [string]$RunIdRegex,
        [int]$MaxRunIndex
    )
    if (-not (Test-Path -LiteralPath $Directory)) {
        return 0
    }
    $removed = 0
    foreach ($file in Get-ChildItem -LiteralPath $Directory -Filter $Pattern -File) {
        $match = [regex]::Match($file.Name, $RunIdRegex)
        if (-not $match.Success) {
            continue
        }
        $runIndex = [int]$match.Groups[1].Value
        if ($runIndex -le $MaxRunIndex) {
            continue
        }
        $fullPath = [System.IO.Path]::GetFullPath($file.FullName)
        if (-not (Test-PathInsideDirectory -Path $fullPath -Directory $Directory)) {
            throw "Refusing to remove stale report outside output directory: $fullPath"
        }
        Remove-Item -LiteralPath $fullPath -Force -ErrorAction Stop
        $removed += 1
    }
    return $removed
}

function Get-MissingCoverageKeys {
    param([object]$Coverage)
    $missing = @()
    if ($null -eq $Coverage) {
        return $missing
    }
    foreach ($prop in $Coverage.PSObject.Properties) {
        if ($prop.Value -eq $false) {
            $missing += [string]$prop.Name
        }
    }
    return @($missing | Sort-Object)
}

function Get-OptionalSkipReasons {
    param([string[]]$Warnings)
    $skips = @()
    foreach ($warning in $Warnings) {
        $text = [string]$warning
        if ($text -match "No item was available") {
            $skips += "item_unavailable"
        }
        elseif ($text -match "No event was available") {
            $skips += "event_unavailable"
        }
        elseif ($text -match "No service was available") {
            $skips += "service_unavailable"
        }
        elseif ($text -match "No lender was available|No visible route to a lender") {
            $skips += "lender_unavailable"
        }
        elseif ($text -match "Failure/recovery was not reached") {
            $skips += "recovery_not_reached"
        }
    }
    return @($skips | Sort-Object -Unique)
}

function Get-PercentileValue {
    param(
        [double[]]$Values,
        [double]$Percentile
    )
    if ($null -eq $Values -or $Values.Count -le 0) {
        return 0
    }
    $sorted = @($Values | Sort-Object)
    if ($sorted.Count -eq 1) {
        return [math]::Round([double]$sorted[0], 3)
    }
    $rank = ($Percentile / 100.0) * ($sorted.Count - 1)
    $lower = [int][math]::Floor($rank)
    $upper = [int][math]::Ceiling($rank)
    if ($lower -eq $upper) {
        return [math]::Round([double]$sorted[$lower], 3)
    }
    $weight = $rank - $lower
    $value = ([double]$sorted[$lower] * (1.0 - $weight)) + ([double]$sorted[$upper] * $weight)
    return [math]::Round($value, 3)
}

function Get-RunFailureReason {
    param(
        [int]$ExitCode,
        [bool]$R100UiPass,
        [string[]]$Errors,
        [string[]]$MissingCoverage,
        [string]$FinalObjective,
        [int]$TotalGameActions
    )

    if ($ExitCode -eq 0) {
        return "passed"
    }
    if (-not $R100UiPass) {
        return "r100_ui_regression_failed"
    }

    $errorText = ($Errors -join " | ")
    if ($errorText -match "prohibited button|side-panel fallback") {
        return "prohibited_ui_path_used"
    }
    if ($FinalObjective -match "ready" -and (($MissingCoverage -contains "prestige_victory") -and ($MissingCoverage -contains "demo_victory"))) {
        return "victory_ready_not_claimed"
    }
    if ($FinalObjective -match "Visit .*more place" -and $MissingCoverage -contains "travel_object_double_click") {
        return "place_progression_not_traveled"
    }
    if (($FinalObjective -match "choose stake|game-surface action") -and $TotalGameActions -ge 6 -and ($MissingCoverage -contains "travel_object_double_click" -or (($MissingCoverage -contains "prestige_victory") -and ($MissingCoverage -contains "demo_victory")))) {
        return "game_surface_overplayed_no_objective_pivot"
    }
    if (($MissingCoverage -contains "save" -or $MissingCoverage -contains "load" -or $MissingCoverage -contains "continue") -and $errorText -match "Save was not|Load was not|Continue was not") {
        return "save_load_skipped_after_earlier_failure"
    }
    if ($errorText -match "available, but required|No .* available") {
        return "optional_hook_expectation_or_availability"
    }
    if ($errorText -match "Runner did not produce a raw report|Foundation visual QA exited") {
        return "visual_qa_failed_unclassified"
    }
    return "unclassified_playable_loop_failure"
}

function New-RunAnalysis {
    param(
        [object]$Report,
        [int]$RunIndex,
        [string]$Seed,
        [int]$ExitCode,
        [string[]]$RunnerOutput,
        [int64]$DurationMs = 0
    )

    $coverage = Get-JsonProp -Object $Report -Name "coverage" -Default ([pscustomobject]@{})
    $events = ConvertTo-Array (Get-JsonProp -Object $Report -Name "input_events" -Default @())
    $states = ConvertTo-Array (Get-JsonProp -Object $Report -Name "states" -Default @())
    $warnings = ConvertTo-Array (Get-JsonProp -Object $Report -Name "warnings" -Default @())
    $errors = ConvertTo-Array (Get-JsonProp -Object $Report -Name "errors" -Default @())
    $finalRun = Get-JsonProp -Object $Report -Name "final_run_state" -Default ([pscustomobject]@{})
    $r100UiKeys = @(
        "r100_environment_no_overlap",
        "r100_focus_camera_clipped",
        "r100_critical_controls_1280_visible",
        "r100_multiple_games_clickable",
        "r100_side_box_not_required",
        "r100_game_resolution_surface_only",
        "r100_result_hidden_when_empty",
        "consequence_result_card",
        "r100_run_status_hud_structured"
    )
    $r100UiCoverage = [ordered]@{}
    $r100UiPass = $true
    foreach ($key in $r100UiKeys) {
        $passed = Get-BoolProp -Object $coverage -Name $key
        $r100UiCoverage[$key] = $passed
        if (-not $passed) {
            $r100UiPass = $false
        }
    }
    $missingCoverage = Get-MissingCoverageKeys -Coverage $coverage
    $r100MissingCoverage = @($r100UiCoverage.GetEnumerator() | Where-Object { -not $_.Value } | ForEach-Object { [string]$_.Key } | Sort-Object)

    $gameActions = @()
    foreach ($event in $events) {
        if ([string](Get-JsonProp -Object $event -Name "kind" -Default "") -ne "game_surface_mouse_confirm_click") {
            continue
        }
        $stake = [int](Get-JsonProp -Object $event -Name "stake" -Default 0)
        $bankrollDelta = [int](Get-JsonProp -Object $event -Name "bankroll_delta" -Default 0)
        $won = [bool](Get-JsonProp -Object $event -Name "won" -Default ($bankrollDelta -gt 0))
        $gameActions += [ordered]@{
            order = $gameActions.Count + 1
            game_id = [string](Get-JsonProp -Object $event -Name "game_id" -Default "")
            game = [string](Get-JsonProp -Object $event -Name "game_label" -Default "")
            action_surface = [string](Get-JsonProp -Object $event -Name "action" -Default "")
            action_id = [string](Get-JsonProp -Object $event -Name "selected_action_id" -Default "")
            action_label = [string](Get-JsonProp -Object $event -Name "selected_action_label" -Default "")
            action_kind = [string](Get-JsonProp -Object $event -Name "selected_action_kind" -Default "")
            wager = $stake
            bankroll_delta = $bankrollDelta
            heat_delta = [int](Get-JsonProp -Object $event -Name "suspicion_delta" -Default 0)
            won = $won
            bankroll_after = [int](Get-JsonProp -Object $event -Name "bankroll_after" -Default 0)
            heat_after = [int](Get-JsonProp -Object $event -Name "heat_after" -Default 0)
            result_message = [string](Get-JsonProp -Object $event -Name "result_message" -Default "")
        }
    }

    $gameGroups = @{}
    foreach ($action in $gameActions) {
        $gameName = [string]$action.game
        if ([string]::IsNullOrWhiteSpace($gameName)) {
            $gameName = "(unknown game)"
        }
        if (-not $gameGroups.ContainsKey($gameName)) {
            $gameGroups[$gameName] = New-Object System.Collections.ArrayList
        }
        [void]$gameGroups[$gameName].Add($action)
    }

    $gameStats = @()
    foreach ($gameName in ($gameGroups.Keys | Sort-Object)) {
        $plays = @($gameGroups[$gameName])
        $wins = @($plays | Where-Object { $_.won })
        $legal = @($plays | Where-Object { $_.action_surface -eq "surface_legal" -or $_.action_kind -eq "legal" })
        $risky = @($plays | Where-Object { $_.action_surface -eq "surface_cheat" -or $_.action_kind -eq "cheat" })
        $totalWager = 0
        $totalDelta = 0
        $totalHeat = 0
        foreach ($play in $plays) {
            $totalWager += [int]$play.wager
            $totalDelta += [int]$play.bankroll_delta
            $totalHeat += [int]$play.heat_delta
        }
        $gameStats += [ordered]@{
            game = $gameName
            plays = $plays.Count
            wins = $wins.Count
            losses = $plays.Count - $wins.Count
            win_percentage = if ($plays.Count -gt 0) { [math]::Round(($wins.Count / $plays.Count) * 100, 2) } else { 0 }
            legal_plays = $legal.Count
            risky_plays = $risky.Count
            total_wagered = $totalWager
            net_bankroll_delta = $totalDelta
            heat_delta = $totalHeat
        }
    }

    $itemEvents = @($events | Where-Object { [string](Get-JsonProp -Object $_ -Name "object_type" -Default "") -eq "item" })
    $itemsBought = @()
    foreach ($state in $states) {
        $stateName = [string](Get-JsonProp -Object $state -Name "name" -Default "")
        $message = [string](Get-JsonProp -Object $state -Name "message" -Default "")
        if ($stateName.Contains("item") -or $message.StartsWith("Bought ")) {
            $itemsBought += [ordered]@{
                state = $stateName
                message = $message
                bankroll = Get-JsonProp -Object (Get-JsonProp -Object $state -Name "consequence" -Default ([pscustomobject]@{})) -Name "bankroll" -Default $null
            }
        }
    }

    $eventResolutions = @()
    foreach ($state in $states) {
        $stateName = [string](Get-JsonProp -Object $state -Name "name" -Default "")
        if ($stateName.Contains("event")) {
            $eventResolutions += [ordered]@{
                state = $stateName
                message = [string](Get-JsonProp -Object $state -Name "message" -Default "")
            }
        }
    }

    $travelEvents = @()
    foreach ($event in $events) {
        if ([string](Get-JsonProp -Object $event -Name "object_type" -Default "") -eq "travel") {
            $travelEvents += [ordered]@{
                label = [string](Get-JsonProp -Object $event -Name "label" -Default "")
                object_id = [string](Get-JsonProp -Object $event -Name "object_id" -Default "")
                kind = [string](Get-JsonProp -Object $event -Name "kind" -Default "")
            }
        }
    }

    $serviceEvents = @($events | Where-Object { [string](Get-JsonProp -Object $_ -Name "object_type" -Default "") -eq "service" })
    $lenderEvents = @($events | Where-Object { [string](Get-JsonProp -Object $_ -Name "object_type" -Default "") -eq "lender" })

    $victory = (Get-BoolProp -Object $coverage -Name "prestige_victory") -or (Get-BoolProp -Object $coverage -Name "demo_victory")
    $failed = $false
    $lossReason = ""
    foreach ($state in $states) {
        $consequence = Get-JsonProp -Object $state -Name "consequence" -Default ([pscustomobject]@{})
        $status = [string](Get-JsonProp -Object $consequence -Name "run_status" -Default "")
        if ($status -eq "failed") {
            $failed = $true
            $lossReason = [string](Get-JsonProp -Object $state -Name "message" -Default "Run entered failed state.")
            break
        }
    }
    if (-not $failed -and [string](Get-JsonProp -Object $finalRun -Name "run_status" -Default "") -eq "failed") {
        $failed = $true
        $lossReason = [string](Get-JsonProp -Object $finalRun -Name "message" -Default "Final run status was failed.")
    }

    $victoryState = $states | Where-Object {
        $stateName = [string](Get-JsonProp -Object $_ -Name "name" -Default "")
        $stateName -eq "prestige_victory_screen" -or $stateName -eq "demo_victory_screen"
    } | Select-Object -First 1
    $completionBalance = Get-JsonProp -Object $finalRun -Name "bankroll" -Default $null
    if ($null -ne $victoryState) {
        $completionBalance = Get-JsonProp -Object (Get-JsonProp -Object $victoryState -Name "consequence" -Default ([pscustomobject]@{})) -Name "bankroll" -Default $completionBalance
    }
    $finalObjective = Get-JsonProp -Object $finalRun -Name "objective" -Default ""
    $optionalSkips = Get-OptionalSkipReasons -Warnings $warnings
    $failureReason = Get-RunFailureReason -ExitCode $ExitCode -R100UiPass $r100UiPass -Errors $errors -MissingCoverage $missingCoverage -FinalObjective $finalObjective -TotalGameActions $gameActions.Count
    $failureScope = "none"
    if ($failureReason -eq "r100_ui_regression_failed") {
        $failureScope = "r100_ui_regression"
    }
    elseif ($ExitCode -ne 0) {
        $failureScope = "playable_loop"
    }

    return [ordered]@{
        run_index = $RunIndex
        seed = $Seed
        result = [string](Get-JsonProp -Object $Report -Name "result" -Default ($(if ($ExitCode -eq 0) { "PASS" } else { "FAIL" })))
        exit_code = $ExitCode
        run_duration_ms = $DurationMs
        run_duration_sec = [math]::Round(([double]$DurationMs / 1000.0), 3)
        playable_loop_passed = $ExitCode -eq 0
        failure_scope = $failureScope
        failure_reason = $failureReason
        missing_coverage = $missingCoverage
        r100_missing_coverage = $r100MissingCoverage
        optional_skips = $optionalSkips
        won = $victory
        lost = $failed
        loss_reason = $lossReason
        victory_result = [string](Get-JsonProp -Object $Report -Name "victory_result" -Default "")
        failure_recovery_result = [string](Get-JsonProp -Object $Report -Name "failure_recovery_result" -Default "")
        completion_balance = $completionBalance
        final_recorded_balance = Get-JsonProp -Object $finalRun -Name "bankroll" -Default $null
        final_recorded_heat = Get-JsonProp -Object $finalRun -Name "heat" -Default $null
        final_recorded_status = Get-JsonProp -Object $finalRun -Name "run_status" -Default ""
        final_recorded_environment = Get-JsonProp -Object $finalRun -Name "environment" -Default ""
        final_objective = $finalObjective
        r100_ui_regression_passed = $r100UiPass
        r100_ui_regression_coverage = $r100UiCoverage
        games_played = $gameStats
        game_actions = $gameActions
        total_game_actions = $gameActions.Count
        total_wagered = ($gameStats | ForEach-Object { [int](Get-JsonProp -Object $_ -Name "total_wagered" -Default 0) } | Measure-Object -Sum).Sum
        net_game_bankroll_delta = ($gameStats | ForEach-Object { [int](Get-JsonProp -Object $_ -Name "net_bankroll_delta" -Default 0) } | Measure-Object -Sum).Sum
        items_bought = $itemsBought
        visible_item_events = @($itemEvents | ForEach-Object {
            [ordered]@{
                label = [string](Get-JsonProp -Object $_ -Name "label" -Default "")
                object_id = [string](Get-JsonProp -Object $_ -Name "object_id" -Default "")
                kind = [string](Get-JsonProp -Object $_ -Name "kind" -Default "")
            }
        })
        events_resolved = $eventResolutions
        travel = $travelEvents
        services = @($serviceEvents | ForEach-Object {
            [ordered]@{
                label = [string](Get-JsonProp -Object $_ -Name "label" -Default "")
                object_id = [string](Get-JsonProp -Object $_ -Name "object_id" -Default "")
                kind = [string](Get-JsonProp -Object $_ -Name "kind" -Default "")
            }
        })
        lenders = @($lenderEvents | ForEach-Object {
            [ordered]@{
                label = [string](Get-JsonProp -Object $_ -Name "label" -Default "")
                object_id = [string](Get-JsonProp -Object $_ -Name "object_id" -Default "")
                kind = [string](Get-JsonProp -Object $_ -Name "kind" -Default "")
            }
        })
        coverage = $coverage
        warnings = $warnings
        errors = $errors
        screenshot_capture = Get-JsonProp -Object (Get-JsonProp -Object $Report -Name "screenshots" -Default ([pscustomobject]@{})) -Name "mode" -Default ""
        input_events = $events
        states_observed = @($states | ForEach-Object {
            [ordered]@{
                name = [string](Get-JsonProp -Object $_ -Name "name" -Default "")
                message = [string](Get-JsonProp -Object $_ -Name "message" -Default "")
                environment = [string](Get-JsonProp -Object (Get-JsonProp -Object $_ -Name "environment" -Default ([pscustomobject]@{})) -Name "display_name" -Default "")
                bankroll = Get-JsonProp -Object (Get-JsonProp -Object $_ -Name "consequence" -Default ([pscustomobject]@{})) -Name "bankroll" -Default $null
                heat = Get-JsonProp -Object (Get-JsonProp -Object $_ -Name "consequence" -Default ([pscustomobject]@{})) -Name "suspicion_level" -Default $null
                run_status = [string](Get-JsonProp -Object (Get-JsonProp -Object $_ -Name "consequence" -Default ([pscustomobject]@{})) -Name "run_status" -Default "")
            }
        })
        runner_output_tail = @($RunnerOutput | Select-Object -Last 20)
    }
}

if ($RunCount -le 0) {
    throw "RunCount must be greater than zero."
}
if (-not (Test-Path -LiteralPath $singleRunner)) {
    throw "foundation_mouse_playtest.ps1 was not found."
}

if (-not $OutputRoot) {
    $OutputRoot = Join-Path $root ".tmp\foundation_mouse_batch"
}
New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null
$analysisDir = Join-Path $OutputRoot "run_analysis"
$rawDir = Join-Path $OutputRoot "raw_mouse_reports"
New-Item -ItemType Directory -Force -Path $analysisDir | Out-Null
New-Item -ItemType Directory -Force -Path $rawDir | Out-Null
$staleRawRemoved = Remove-StaleRunReports -Directory $rawDir -Pattern "mouse_run_*.json" -RunIdRegex "^mouse_run_(\d+)\.json$" -MaxRunIndex $RunCount
$staleAnalysisRemoved = Remove-StaleRunReports -Directory $analysisDir -Pattern "run_*_analysis.json" -RunIdRegex "^run_(\d+)_analysis\.json$" -MaxRunIndex $RunCount
if (($staleRawRemoved + $staleAnalysisRemoved) -gt 0) {
    Write-Output ("Mouse batch report rotation removed {0} stale raw reports and {1} stale analysis reports beyond RunCount {2}." -f $staleRawRemoved, $staleAnalysisRemoved, $RunCount)
}

$analyses = @()
$batchStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
for ($i = 1; $i -le $RunCount; $i++) {
    $runId = "{0:D3}" -f $i
    $seed = "$SeedPrefix-$runId"
    $reportName = "mouse_run_$runId.json"
    Write-Output ("[{0}/{1}] Running mouse-only playtest seed {2}" -f $i, $RunCount, $seed)
    $args = @(
        "-ExecutionPolicy", "Bypass",
        "-File", $singleRunner,
        "-Seed", $seed,
        "-OutputDir", $rawDir,
        "-ReportName", $reportName,
        "-CleanSave"
    )
    if ($RequireGodot) {
        $args += "-RequireGodot"
    }
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $runStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $runnerOutput = @(powershell @args 2>&1 | ForEach-Object { [string]$_ })
    $runStopwatch.Stop()
    $runDurationMs = [int64]$runStopwatch.ElapsedMilliseconds
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousErrorActionPreference
    $rawPath = Join-Path $rawDir $reportName
    $report = [pscustomobject]@{
        result = if ($exitCode -eq 0) { "PASS" } else { "FAIL" }
        warnings = @()
        errors = @("Runner did not produce a raw report.")
        input_events = @()
        coverage = [pscustomobject]@{}
        final_run_state = [pscustomobject]@{}
        screenshots = [pscustomobject]@{ mode = "unknown" }
        states = @()
    }
    if (Test-Path -LiteralPath $rawPath) {
        $report = Get-Content -LiteralPath $rawPath -Raw | ConvertFrom-Json
    }
    $analysis = New-RunAnalysis -Report $report -RunIndex $i -Seed $seed -ExitCode $exitCode -RunnerOutput $runnerOutput -DurationMs $runDurationMs
    $analysisPath = Join-Path $analysisDir ("run_{0}_analysis.json" -f $runId)
    ($analysis | ConvertTo-Json -Depth 100) | Set-Content -LiteralPath $analysisPath -Encoding UTF8
    $analyses += [pscustomobject]$analysis
}
$batchStopwatch.Stop()

$passed = @($analyses | Where-Object { $_.playable_loop_passed })
$r100UiPassed = @($analyses | Where-Object { $_.r100_ui_regression_passed })
$won = @($analyses | Where-Object { $_.won })
$lost = @($analyses | Where-Object { $_.lost })
$trueFailures = @($analyses | Where-Object { -not $_.playable_loop_passed })
$strictGatePassed = $trueFailures.Count -eq 0
$failureReasonCounts = [ordered]@{}
$failureScopeCounts = [ordered]@{}
$missingCoverageCounts = [ordered]@{}
$optionalSkipCounts = [ordered]@{}
foreach ($analysis in $analyses) {
    $reason = [string](Get-JsonProp -Object $analysis -Name "failure_reason" -Default "unclassified")
    if (-not $failureReasonCounts.Contains($reason)) {
        $failureReasonCounts[$reason] = 0
    }
    $failureReasonCounts[$reason] = [int]$failureReasonCounts[$reason] + 1

    $scope = [string](Get-JsonProp -Object $analysis -Name "failure_scope" -Default "unknown")
    if (-not $failureScopeCounts.Contains($scope)) {
        $failureScopeCounts[$scope] = 0
    }
    $failureScopeCounts[$scope] = [int]$failureScopeCounts[$scope] + 1

    foreach ($key in (ConvertTo-Array (Get-JsonProp -Object $analysis -Name "missing_coverage" -Default @()))) {
        $keyText = [string]$key
        if (-not $missingCoverageCounts.Contains($keyText)) {
            $missingCoverageCounts[$keyText] = 0
        }
        $missingCoverageCounts[$keyText] = [int]$missingCoverageCounts[$keyText] + 1
    }

    foreach ($skip in (ConvertTo-Array (Get-JsonProp -Object $analysis -Name "optional_skips" -Default @()))) {
        $skipText = [string]$skip
        if (-not $optionalSkipCounts.Contains($skipText)) {
            $optionalSkipCounts[$skipText] = 0
        }
        $optionalSkipCounts[$skipText] = [int]$optionalSkipCounts[$skipText] + 1
    }
}
$allGameStats = @{}
foreach ($analysis in $analyses) {
    foreach ($game in (ConvertTo-Array $analysis.games_played)) {
        $gameName = [string](Get-JsonProp -Object $game -Name "game" -Default "(unknown game)")
        if (-not $allGameStats.ContainsKey($gameName)) {
            $allGameStats[$gameName] = [ordered]@{
                game = $gameName
                runs_seen = 0
                plays = 0
                wins = 0
                losses = 0
                total_wagered = 0
                net_bankroll_delta = 0
                heat_delta = 0
            }
        }
        $stats = $allGameStats[$gameName]
        $stats["runs_seen"] = [int]$stats["runs_seen"] + 1
        $stats["plays"] = [int]$stats["plays"] + [int](Get-JsonProp -Object $game -Name "plays" -Default 0)
        $stats["wins"] = [int]$stats["wins"] + [int](Get-JsonProp -Object $game -Name "wins" -Default 0)
        $stats["losses"] = [int]$stats["losses"] + [int](Get-JsonProp -Object $game -Name "losses" -Default 0)
        $stats["total_wagered"] = [int]$stats["total_wagered"] + [int](Get-JsonProp -Object $game -Name "total_wagered" -Default 0)
        $stats["net_bankroll_delta"] = [int]$stats["net_bankroll_delta"] + [int](Get-JsonProp -Object $game -Name "net_bankroll_delta" -Default 0)
        $stats["heat_delta"] = [int]$stats["heat_delta"] + [int](Get-JsonProp -Object $game -Name "heat_delta" -Default 0)
    }
}

$aggregateGameStats = @()
foreach ($gameName in ($allGameStats.Keys | Sort-Object)) {
    $stats = $allGameStats[$gameName]
    $plays = [int]$stats["plays"]
    $winsCount = [int]$stats["wins"]
    $stats["win_percentage"] = if ($plays -gt 0) { [math]::Round(($winsCount / $plays) * 100, 2) } else { 0 }
    $aggregateGameStats += $stats
}

$runDurationsMs = @($analyses | ForEach-Object { [double](Get-JsonProp -Object $_ -Name "run_duration_ms" -Default 0) })
$durationTotalMs = 0.0
foreach ($durationMs in $runDurationsMs) {
    $durationTotalMs += [double]$durationMs
}
$durationAverageMs = if ($runDurationsMs.Count -gt 0) { $durationTotalMs / $runDurationsMs.Count } else { 0.0 }

$aggregate = [ordered]@{
    tool = "foundation_mouse_batch_playtest"
    gate = "r100_stab_mouse_only"
    gate_mode = if ($AllowRunFailures) { "investigation_allow_failures" } else { "strict" }
    strict_gate_passed = $strictGatePassed
    allow_run_failures = [bool]$AllowRunFailures
    run_count_requested = $RunCount
    run_count_completed = $analyses.Count
    batch_wall_ms = [int64]$batchStopwatch.ElapsedMilliseconds
    batch_wall_sec = [math]::Round(([double]$batchStopwatch.ElapsedMilliseconds / 1000.0), 3)
    run_duration_ms = [ordered]@{
        min = Get-PercentileValue -Values $runDurationsMs -Percentile 0
        avg = [math]::Round($durationAverageMs, 3)
        p50 = Get-PercentileValue -Values $runDurationsMs -Percentile 50
        p75 = Get-PercentileValue -Values $runDurationsMs -Percentile 75
        p95 = Get-PercentileValue -Values $runDurationsMs -Percentile 95
        max = Get-PercentileValue -Values $runDurationsMs -Percentile 100
    }
    run_duration_sec = [ordered]@{
        min = [math]::Round((Get-PercentileValue -Values $runDurationsMs -Percentile 0) / 1000.0, 3)
        avg = [math]::Round($durationAverageMs / 1000.0, 3)
        p50 = [math]::Round((Get-PercentileValue -Values $runDurationsMs -Percentile 50) / 1000.0, 3)
        p75 = [math]::Round((Get-PercentileValue -Values $runDurationsMs -Percentile 75) / 1000.0, 3)
        p95 = [math]::Round((Get-PercentileValue -Values $runDurationsMs -Percentile 95) / 1000.0, 3)
        max = [math]::Round((Get-PercentileValue -Values $runDurationsMs -Percentile 100) / 1000.0, 3)
    }
    output_root = (Resolve-Path -LiteralPath $OutputRoot).Path
    analysis_dir = (Resolve-Path -LiteralPath $analysisDir).Path
    raw_report_dir = (Resolve-Path -LiteralPath $rawDir).Path
    seed_prefix = $SeedPrefix
    playable_loop_pass_count = $passed.Count
    playable_loop_fail_count = $analyses.Count - $passed.Count
    playable_loop_pass_percentage = if ($analyses.Count -gt 0) { [math]::Round(($passed.Count / $analyses.Count) * 100, 2) } else { 0 }
    r100_ui_regression_pass_count = $r100UiPassed.Count
    r100_ui_regression_fail_count = $analyses.Count - $r100UiPassed.Count
    r100_ui_regression_pass_percentage = if ($analyses.Count -gt 0) { [math]::Round(($r100UiPassed.Count / $analyses.Count) * 100, 2) } else { 0 }
    true_failure_count = $trueFailures.Count
    true_failures = @($trueFailures | ForEach-Object {
        [ordered]@{
            run_index = $_.run_index
            seed = $_.seed
            failure_scope = $_.failure_scope
            failure_reason = $_.failure_reason
            missing_coverage = $_.missing_coverage
            errors = $_.errors
        }
    })
    failure_reason_counts = @($failureReasonCounts.GetEnumerator() | Sort-Object -Property @{Expression = "Value"; Descending = $true}, @{Expression = "Name"; Descending = $false} | ForEach-Object {
        [ordered]@{
            reason = [string]$_.Key
            count = [int]$_.Value
        }
    })
    failure_scope_counts = @($failureScopeCounts.GetEnumerator() | Sort-Object -Property @{Expression = "Value"; Descending = $true}, @{Expression = "Name"; Descending = $false} | ForEach-Object {
        [ordered]@{
            scope = [string]$_.Key
            count = [int]$_.Value
        }
    })
    missing_coverage_counts = @($missingCoverageCounts.GetEnumerator() | Sort-Object -Property @{Expression = "Value"; Descending = $true}, @{Expression = "Name"; Descending = $false} | ForEach-Object {
        [ordered]@{
            coverage = [string]$_.Key
            count = [int]$_.Value
        }
    })
    optional_skip_counts = @($optionalSkipCounts.GetEnumerator() | Sort-Object -Property @{Expression = "Value"; Descending = $true}, @{Expression = "Name"; Descending = $false} | ForEach-Object {
        [ordered]@{
            skip = [string]$_.Key
            count = [int]$_.Value
        }
    })
    victory_count = $won.Count
    loss_count = $lost.Count
    victory_percentage = if ($analyses.Count -gt 0) { [math]::Round(($won.Count / $analyses.Count) * 100, 2) } else { 0 }
    loss_percentage = if ($analyses.Count -gt 0) { [math]::Round(($lost.Count / $analyses.Count) * 100, 2) } else { 0 }
    game_stats = $aggregateGameStats
    runs = @($analyses | ForEach-Object {
        [ordered]@{
            run_index = $_.run_index
            seed = $_.seed
            result = $_.result
            run_duration_ms = $_.run_duration_ms
            run_duration_sec = $_.run_duration_sec
            failure_scope = $_.failure_scope
            failure_reason = $_.failure_reason
            won = $_.won
            lost = $_.lost
            completion_balance = $_.completion_balance
            final_recorded_balance = $_.final_recorded_balance
            final_recorded_heat = $_.final_recorded_heat
            r100_ui_regression_passed = $_.r100_ui_regression_passed
            missing_coverage_count = (ConvertTo-Array $_.missing_coverage).Count
            total_game_actions = $_.total_game_actions
            total_wagered = $_.total_wagered
            net_game_bankroll_delta = $_.net_game_bankroll_delta
            warning_count = (ConvertTo-Array $_.warnings).Count
        }
    })
}

$aggregatePath = Join-Path $OutputRoot "aggregate_summary.json"
($aggregate | ConvertTo-Json -Depth 100) | Set-Content -LiteralPath $aggregatePath -Encoding UTF8

$markdownPath = Join-Path $OutputRoot "aggregate_summary.md"
$lines = @()
$lines += "# M2-FUN Mouse-Only Batch Playtest"
$lines += ""
$lines += "- Gate: R100-STAB mouse-only stabilization"
$lines += "- Gate mode: $($aggregate.gate_mode)"
$lines += "- Strict gate passed: $($aggregate.strict_gate_passed)"
$lines += "- Allow run failures: $($aggregate.allow_run_failures)"
$lines += "- Runs requested: $RunCount"
$lines += "- Runs completed: $($analyses.Count)"
$lines += "- Batch wall time: $($aggregate.batch_wall_sec)s"
$lines += "- Run duration seconds: min $($aggregate.run_duration_sec.min), avg $($aggregate.run_duration_sec.avg), p50 $($aggregate.run_duration_sec.p50), p75 $($aggregate.run_duration_sec.p75), p95 $($aggregate.run_duration_sec.p95), max $($aggregate.run_duration_sec.max)"
$lines += "- Playable-loop passes: $($passed.Count) ($($aggregate.playable_loop_pass_percentage)%)"
$lines += "- Playable-loop failures: $($analyses.Count - $passed.Count)"
$lines += "- R100 UI regression passes: $($r100UiPassed.Count) ($($aggregate.r100_ui_regression_pass_percentage)%)"
$lines += "- R100 UI regression failures: $($analyses.Count - $r100UiPassed.Count)"
$lines += "- True failures: $($aggregate.true_failure_count)"
$lines += "- Victories: $($won.Count) ($($aggregate.victory_percentage)%)"
$lines += "- Losses: $($lost.Count) ($($aggregate.loss_percentage)%)"
$lines += "- Analysis files: $analysisDir"
$lines += "- Raw mouse reports: $rawDir"
$lines += "- Report preservation: current aggregate files and matching run ids are overwritten for this output root; stale per-run files beyond the requested RunCount are removed."
$lines += ""
$lines += "## Failure Reasons"
$lines += ""
$lines += "| Reason | Count |"
$lines += "|---|---:|"
foreach ($entry in $aggregate.failure_reason_counts) {
    $lines += "| $($entry.reason) | $($entry.count) |"
}
$lines += ""
$lines += "## Failure Scopes"
$lines += ""
$lines += "| Scope | Count |"
$lines += "|---|---:|"
foreach ($entry in $aggregate.failure_scope_counts) {
    $lines += "| $($entry.scope) | $($entry.count) |"
}
$lines += ""
$lines += "## Missing Coverage Counts"
$lines += ""
$lines += "| Coverage | Count |"
$lines += "|---|---:|"
foreach ($entry in ($aggregate.missing_coverage_counts | Select-Object -First 20)) {
    $lines += "| $($entry.coverage) | $($entry.count) |"
}
$lines += ""
$lines += "## Optional Skips"
$lines += ""
$lines += "| Skip | Count |"
$lines += "|---|---:|"
foreach ($entry in $aggregate.optional_skip_counts) {
    $lines += "| $($entry.skip) | $($entry.count) |"
}
$lines += ""
$lines += "## True Failures"
$lines += ""
$lines += "| Run | Seed | Scope | Reason | Missing Coverage |"
$lines += "|---:|---|---|---|---|"
if ($aggregate.true_failure_count -eq 0) {
    $lines += "| - | - | - | none | - |"
}
else {
    foreach ($failure in $aggregate.true_failures) {
        $missing = ((ConvertTo-Array $failure.missing_coverage) -join ", ")
        $lines += "| $($failure.run_index) | $($failure.seed) | $($failure.failure_scope) | $($failure.failure_reason) | $missing |"
    }
}
$lines += ""
$lines += "## Aggregate Game Stats"
$lines += ""
$lines += "| Game | Runs Seen | Plays | Wins | Losses | Win % | Total Wagered | Net Bankroll Delta | Heat Delta |"
$lines += "|---|---:|---:|---:|---:|---:|---:|---:|---:|"
foreach ($game in $aggregateGameStats) {
    $lines += "| $($game.game) | $($game.runs_seen) | $($game.plays) | $($game.wins) | $($game.losses) | $($game.win_percentage) | $($game.total_wagered) | $($game.net_bankroll_delta) | $($game.heat_delta) |"
}
$lines += ""
$lines += "## Per-Run Summary"
$lines += ""
$lines += "| Run | Seed | Duration Sec | Result | Scope | Failure Reason | R100 UI | Won | Lost | Completion Balance | Final Balance | Final Heat | Missing Coverage | Wagered | Game Delta | Warnings |"
$lines += "|---:|---|---:|---|---|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|"
foreach ($analysis in $analyses) {
    $lines += "| $($analysis.run_index) | $($analysis.seed) | $($analysis.run_duration_sec) | $($analysis.result) | $($analysis.failure_scope) | $($analysis.failure_reason) | $($analysis.r100_ui_regression_passed) | $($analysis.won) | $($analysis.lost) | $($analysis.completion_balance) | $($analysis.final_recorded_balance) | $($analysis.final_recorded_heat) | $((ConvertTo-Array $analysis.missing_coverage).Count) | $($analysis.total_wagered) | $($analysis.net_game_bankroll_delta) | $((ConvertTo-Array $analysis.warnings).Count) |"
}
$lines | Set-Content -LiteralPath $markdownPath -Encoding UTF8

Write-Output "Foundation mouse-only batch playtest complete."
Write-Output "Aggregate summary: $aggregatePath"
Write-Output "Markdown summary: $markdownPath"
Write-Output "Run analysis files: $analysisDir"
Write-Output "Raw mouse reports: $rawDir"
Write-Output ("Playable-loop pass count: {0}/{1}" -f $passed.Count, $analyses.Count)
Write-Output ("Playable-loop pass rate: {0}%" -f $aggregate.playable_loop_pass_percentage)
Write-Output ("R100 UI regression pass count: {0}/{1}" -f $r100UiPassed.Count, $analyses.Count)
Write-Output ("R100 UI regression pass rate: {0}%" -f $aggregate.r100_ui_regression_pass_percentage)
Write-Output ("Victory count: {0}/{1}" -f $won.Count, $analyses.Count)
Write-Output ("Batch wall time: {0}s" -f $aggregate.batch_wall_sec)
Write-Output ("Run duration seconds: min {0}, avg {1}, p50 {2}, p75 {3}, p95 {4}, max {5}" -f $aggregate.run_duration_sec.min, $aggregate.run_duration_sec.avg, $aggregate.run_duration_sec.p50, $aggregate.run_duration_sec.p75, $aggregate.run_duration_sec.p95, $aggregate.run_duration_sec.max)
Write-Output ("True failure count: {0}" -f $aggregate.true_failure_count)
Write-Output ("Gate mode: {0}" -f $aggregate.gate_mode)
Write-Output ("Strict gate passed: {0}" -f $aggregate.strict_gate_passed)
Write-Output "Failure reasons:"
foreach ($entry in $aggregate.failure_reason_counts) {
    Write-Output ("- {0}: {1}" -f $entry.reason, $entry.count)
}
if (($analyses.Count - $passed.Count) -gt 0 -and -not $AllowRunFailures) {
    exit 1
}
exit 0
