param(
    [switch]$RequireGodot,
    [switch]$CleanSave,
    [string]$Seed = "",
    [string]$OutputDir = "",
    [string]$ReportName = ""
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$visualQa = Join-Path $PSScriptRoot "foundation_visual_qa.ps1"

function Get-JsonProp {
    param(
        [object]$Object,
        [string]$Name,
        [object]$Default = $null
    )
    if ($null -eq $Object) {
        return $Default
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

function Add-Error {
    param([string]$Message)
    $script:errors += $Message
}

function Add-Warning {
    param([string]$Message)
    $script:warnings += $Message
}

function Get-VictoryReachability {
    param(
        [object]$Visual,
        [object]$Coverage
    )

    if (Get-BoolProp -Object $Coverage -Name "demo_victory") {
        return [pscustomobject][ordered]@{
            status = "reached"
            reason = "Victory reached through visible mouse controls."
            objective = ""
            next_objective = [pscustomobject]@{}
        }
    }

    $hud = Get-JsonProp -Object $Visual -Name "final_objective_hud" -Default ([pscustomobject]@{})
    $demoObjective = Get-JsonProp -Object $hud -Name "demo_objective" -Default ([pscustomobject]@{})
    $nextObjective = Get-JsonProp -Object $hud -Name "next_objective" -Default ([pscustomobject]@{})
    $objectiveText = [string](Get-JsonProp -Object $hud -Name "text" -Default "")
    $objectiveReason = [string](Get-JsonProp -Object $hud -Name "goal" -Default "")

    $demoActive = Get-BoolProp -Object $demoObjective -Name "active"
    $requirementsVisible = (Get-BoolProp -Object $Coverage -Name "demo_objective_visible") -or $demoActive
    $reasonLooksUseful = $objectiveReason -match "bankroll|heat|visit|place|locked|need|build|casino|entry|target|\\$100"
    if ($demoActive -and [string]::IsNullOrWhiteSpace($objectiveReason)) {
        $objectiveReason = [string](Get-JsonProp -Object $demoObjective -Name "summary" -Default $objectiveText)
        $reasonLooksUseful = $objectiveReason -match "bankroll|heat|visit|place|locked|need|casino|target"
    }
    if ($requirementsVisible -and $reasonLooksUseful) {
        return [pscustomobject][ordered]@{
            status = "not_yet_reachable_requirements_visible"
            reason = $objectiveReason
            objective = $objectiveText
            next_objective = $nextObjective
        }
    }

    return [pscustomobject][ordered]@{
        status = "unknown_or_hidden"
        reason = "Victory target was not reached and missing requirements were not clearly classified."
        objective = $objectiveText
        next_objective = $nextObjective
    }
}

function Get-OptionalHookEntry {
    param(
        [object]$Status,
        [string]$Kind
    )

    $entry = Get-JsonProp -Object $Status -Name $Kind -Default $null
    if ($null -eq $entry) {
        return [pscustomobject][ordered]@{
            status = "unknown"
            reason = ""
            object_id = ""
            label = ""
        }
    }
    return $entry
}

if (-not (Test-Path -LiteralPath $visualQa)) {
    throw "foundation_visual_qa.ps1 was not found."
}

$godotUserDir = Join-Path $env:APPDATA "Godot\app_userdata\Beat the House"
$visualReportPath = Join-Path $godotUserDir "foundation_visual_qa_report.json"
$autosavePath = Join-Path $godotUserDir "saves\autosave.json"
if ($CleanSave -and (Test-Path -LiteralPath $autosavePath)) {
    Remove-Item -LiteralPath $autosavePath -Force
}
if (Test-Path -LiteralPath $visualReportPath) {
    Remove-Item -LiteralPath $visualReportPath -Force
}

$visualArgs = @("-ExecutionPolicy", "Bypass", "-File", $visualQa)
if ($RequireGodot) {
    $visualArgs += "-RequireGodot"
}

$previousSeed = $env:FOUNDATION_VISUAL_QA_SEED
if ($Seed) {
    $env:FOUNDATION_VISUAL_QA_SEED = $Seed
}

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
$visualOutput = & powershell @visualArgs 2>&1
$visualExit = $LASTEXITCODE
$ErrorActionPreference = $previousErrorActionPreference
if ($Seed) {
    if ($null -eq $previousSeed) {
        Remove-Item Env:\FOUNDATION_VISUAL_QA_SEED -ErrorAction SilentlyContinue
    }
    else {
        $env:FOUNDATION_VISUAL_QA_SEED = $previousSeed
    }
}
$visualFailed = $visualExit -ne 0

$reportPath = $null
foreach ($lineValue in $visualOutput) {
    $line = [string]$lineValue
    if ($line -match "Foundation visual QA report written to (.+)$") {
        $reportPath = $Matches[1].Trim()
    }
}

if (-not $reportPath) {
    $reportPath = $visualReportPath
}

if (-not (Test-Path -LiteralPath $reportPath)) {
    throw "Foundation visual QA report was not found at $reportPath."
}

$visual = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
$coverage = Get-JsonProp -Object $visual -Name "coverage" -Default ([pscustomobject]@{})
$optionalHookStatus = Get-JsonProp -Object $visual -Name "optional_hook_status" -Default ([pscustomobject]@{})
$gameSurfaceStatus = Get-JsonProp -Object $visual -Name "game_surface_status" -Default ([pscustomobject]@{})
$inputEvents = @(Get-JsonProp -Object $visual -Name "input_events" -Default @())
$states = @(Get-JsonProp -Object $visual -Name "states" -Default @())
$victoryReachability = Get-VictoryReachability -Visual $visual -Coverage $coverage
$errors = @()
$warnings = @()
if ($visualFailed) {
    Add-Error ("Foundation visual QA exited with code {0}." -f $visualExit)
    $warnings += @($visualOutput | Select-Object -Last 12 | ForEach-Object { [string]$_ })
}

$requiredCoverage = [ordered]@{
    "start_screen" = "Start screen was not covered."
    "new_run_button" = "New run was not started from visible UI."
    "environment_screen" = "Environment screen was not covered."
    "r100_environment_no_overlap" = "Environment canvas overlap regression guard did not pass."
    "r100_focus_camera_clipped" = "Environment focus/camera clipping regression guard did not pass."
    "r100_critical_controls_1280_visible" = "Critical controls were not proven visible at the target viewport."
    "multiple_game_objects_clickable" = "Multiple visible game objects were not proven clickable when available."
    "r100_multiple_games_clickable" = "R100 multi-game visible click guard did not pass."
    "game_object_double_click" = "Visible game object double-click did not enter a game."
    "game_surface_primary" = "Game surface did not become primary."
    "stake_selector" = "Stake was not changed from the game surface."
    "legal_action_selection" = "Legal action was not selected from the game surface."
    "game_surface_click" = "Game surface click selection was not covered."
    "game_surface_resolve_click" = "Game surface resolution was not covered."
    "screen_click_only_gameplay" = "Screen-click-only gameplay enforcement did not pass."
    "r100_side_box_not_required" = "Normal game entry still appears to require the old side-box labels."
    "r100_game_resolution_surface_only" = "Normal game resolution was not proven to be game-surface-only."
    "r100_result_hidden_when_empty" = "Empty result panel was not proven hidden on a fresh run."
    "consequence_result_card" = "Consequence data was not proven after a resolved action."
    "r100_run_status_hud_structured" = "Structured R100 run-status HUD was not proven."
    "autosave_available" = "Autosave was not available for main-menu Continue."
    "save" = "Save was not covered."
    "load" = "Main-menu Continue load was not covered."
    "continue" = "Continue was not covered."
}

foreach ($key in $requiredCoverage.Keys) {
    if (-not (Get-BoolProp -Object $coverage -Name $key)) {
        Add-Error $requiredCoverage[$key]
    }
}

foreach ($assessment in @(
    @{ kind = "entry"; label = "Game entry" },
    @{ kind = "stake"; label = "Game-surface stake selection" },
    @{ kind = "legal"; label = "Game-surface legal action" }
)) {
    $entry = Get-OptionalHookEntry -Status $gameSurfaceStatus -Kind $assessment.kind
    $status = [string](Get-JsonProp -Object $entry -Name "status" -Default "unknown")
    $reason = [string](Get-JsonProp -Object $entry -Name "reason" -Default "")
    if ($status -ne "passed") {
        Add-Error ("{0} did not pass through visible game-surface controls. {1}" -f $assessment.label, $reason).Trim()
    }
}

$riskyEntry = Get-OptionalHookEntry -Status $gameSurfaceStatus -Kind "risky"
$riskyStatus = [string](Get-JsonProp -Object $riskyEntry -Name "status" -Default "unknown")
$riskyReason = [string](Get-JsonProp -Object $riskyEntry -Name "reason" -Default "")
if ($riskyStatus -eq "passed") {
    if (-not (Get-BoolProp -Object $coverage -Name "cheat_action_selection")) {
        Add-Error "Risky action status passed, but risky action coverage was not recorded."
    }
}
elseif ($riskyStatus -eq "skipped_unavailable") {
    Add-Warning ("No risky game-surface action was available in the selected GameModule. {0}" -f $riskyReason).Trim()
}
else {
    Add-Error ("Risky game-surface action was neither resolved nor classified unavailable. {0}" -f $riskyReason).Trim()
}

if (-not (Get-BoolProp -Object $coverage -Name "demo_victory")) {
    $victoryStatus = [string](Get-JsonProp -Object $victoryReachability -Name "status" -Default "unknown_or_hidden")
    $victoryReason = [string](Get-JsonProp -Object $victoryReachability -Name "reason" -Default "")
    if ($victoryStatus -eq "ready_not_claimed") {
        Add-Error $victoryReason
    }
    elseif ($victoryStatus -eq "not_yet_reachable_requirements_visible") {
        Add-Warning ("Victory not yet reachable: {0}" -f $victoryReason)
    }
    else {
        Add-Error $victoryReason
    }
}

foreach ($assessment in @(
    @{ kind = "travel"; label = "Travel"; required = @("travel_card", "travel_object_double_click") },
    @{ kind = "item"; label = "Item"; required = @("item_focus_no_mutation", "item_object_double_click", "item_purchase_result", "item_save_load") },
    @{ kind = "event"; label = "Event"; required = @("event_card") },
    @{ kind = "service"; label = "Service"; required = @("service_card", "service_object_double_click") },
    @{ kind = "lender"; label = "Lender"; required = @("lender_card", "lender_object_double_click") }
)) {
    $entry = Get-OptionalHookEntry -Status $optionalHookStatus -Kind $assessment.kind
    $status = [string](Get-JsonProp -Object $entry -Name "status" -Default "unknown")
    $reason = [string](Get-JsonProp -Object $entry -Name "reason" -Default "")
    $label = [string]$assessment.label
    if ($status -eq "passed") {
        foreach ($key in @($assessment.required)) {
            if (-not (Get-BoolProp -Object $coverage -Name $key)) {
                Add-Error "$label was available, but required mouse-only coverage '$key' did not pass."
            }
        }
    }
    elseif ($status -eq "failed" -or $status -eq "present") {
        Add-Error ("{0} was present, but mouse-only interaction did not complete. {1}" -f $label, $reason).Trim()
    }
    elseif ($status -eq "locked_explained") {
        Add-Warning ("{0} was present but locked/display-only: {1}" -f $label, $reason).Trim()
    }
    elseif ($status -eq "skipped_unavailable") {
        Add-Warning ("No {0} was available in the visual QA route. {1}" -f $label.ToLowerInvariant(), $reason).Trim()
    }
    else {
        $primaryCoverage = [string](@($assessment.required)[0])
        if (Get-BoolProp -Object $coverage -Name $primaryCoverage) {
            foreach ($key in @($assessment.required)) {
                if (-not (Get-BoolProp -Object $coverage -Name $key)) {
                    Add-Error "$label was available, but required mouse-only coverage '$key' did not pass."
                }
            }
        }
        else {
            Add-Warning "No $($label.ToLowerInvariant()) was available in the visual QA route."
        }
    }
}

if (-not (Get-BoolProp -Object $coverage -Name "recovery_lender_path")) {
    Add-Warning "Failure/recovery was not reached; current run may not expose recovery through this seed."
}

$prohibitedLabels = @(Get-JsonProp -Object $visual -Name "prohibited_game_control_button_labels" -Default @("Play it straight", "Try something risky"))
foreach ($eventValue in $inputEvents) {
    $kind = [string](Get-JsonProp -Object $eventValue -Name "kind" -Default "")
    $label = [string](Get-JsonProp -Object $eventValue -Name "label" -Default "")
    if ($kind.StartsWith("visible_button") -and $prohibitedLabels -contains $label) {
        Add-Error "Game resolution used prohibited button '$label' instead of game surface input."
    }
    if ($kind -eq "visible_object_button_fallback" -or $kind -eq "visible_save_button_fallback") {
        Add-Error "Mouse-only QA used side-panel fallback '$kind' instead of a visible environment object."
    }
}

$finalState = $null
if ($states.Count -gt 0) {
    $finalState = $states[$states.Count - 1]
}

$finalSerialized = Get-JsonProp -Object $visual -Name "final_serialized_run_state" -Default ([pscustomobject]@{})
$finalConsequence = Get-JsonProp -Object $finalState -Name "consequence" -Default ([pscustomobject]@{})
$finalEnvironment = Get-JsonProp -Object $finalState -Name "environment" -Default ([pscustomobject]@{})
$finalScreen = Get-JsonProp -Object $finalState -Name "screen" -Default ([pscustomobject]@{})
$screenshotCapture = [string](Get-JsonProp -Object $visual -Name "screenshot_capture" -Default "manual_non_headless")
$screenshotNote = "Headless screenshot capture is not used by this harness."
if ($screenshotCapture -eq "manual_non_headless") {
    $screenshotNote = "Headless/dummy screenshot capture is unavailable or intentionally avoided; inspect manually with a non-headless run."
}

$victoryReachabilityStatus = [string](Get-JsonProp -Object $victoryReachability -Name "status" -Default "unknown_or_hidden")
$victoryResultText = switch ($victoryReachabilityStatus) {
    "reached" { "Victory reached through visible mouse controls." }
    "not_yet_reachable_requirements_visible" { "Victory not yet reachable; visible requirements were recorded." }
    "ready_not_claimed" { "Victory target was ready but not claimed." }
    default { "Victory not reached and requirements were not clearly classified." }
}

$mouseReport = [ordered]@{
    tool = "foundation_mouse_playtest"
    source_report = $reportPath
    active_scene = Get-JsonProp -Object $visual -Name "active_scene" -Default ""
    active_script = Get-JsonProp -Object $visual -Name "active_script" -Default ""
    seed = Get-JsonProp -Object $visual -Name "seed" -Default ""
    result = if ($errors.Count -eq 0) { "PASS" } else { "FAIL" }
    screen_click_only_gameplay_enforced = Get-JsonProp -Object $visual -Name "screen_click_only_gameplay_enforced" -Default $false
    direct_debug_helper_methods_used = Get-JsonProp -Object $visual -Name "direct_debug_helper_methods_used" -Default $true
    prohibited_game_control_button_labels = $prohibitedLabels
    screenshots = [ordered]@{
        mode = $screenshotCapture
        note = $screenshotNote
    }
    coverage = $coverage
    optional_hook_status = $optionalHookStatus
    game_surface_status = $gameSurfaceStatus
    victory_reachability = $victoryReachability
    input_events = $inputEvents
    states = $states
    final_run_state = [ordered]@{
        state_name = Get-JsonProp -Object $finalState -Name "name" -Default ""
        screen = Get-JsonProp -Object $finalScreen -Name "screen" -Default ""
        environment = Get-JsonProp -Object $finalEnvironment -Name "display_name" -Default ""
        bankroll = Get-JsonProp -Object $finalConsequence -Name "bankroll" -Default $null
        heat = Get-JsonProp -Object $finalConsequence -Name "suspicion_level" -Default $null
        run_status = Get-JsonProp -Object $finalConsequence -Name "run_status" -Default ""
        objective = Get-JsonProp -Object $finalState -Name "objective" -Default ""
        message = Get-JsonProp -Object $finalState -Name "message" -Default ""
        serialized = $finalSerialized
    }
    victory_result = $victoryResultText
    failure_recovery_result = if (Get-BoolProp -Object $coverage -Name "recovery_lender_path") { "Recovery/debt pressure verified through visible mouse controls." } else { "Failure/recovery not reached in this route; see warnings." }
    warnings = @($warnings + @(Get-JsonProp -Object $visual -Name "warnings" -Default @()))
    errors = $errors
}

$targetOutputDir = Split-Path -Parent $reportPath
if ($OutputDir) {
    if (-not (Test-Path -LiteralPath $OutputDir)) {
        New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
    }
    $targetOutputDir = (Resolve-Path -LiteralPath $OutputDir).Path
}
$reportFileName = if ($ReportName) { $ReportName } else { "foundation_mouse_playtest_report.json" }
if (-not $reportFileName.EndsWith(".json")) {
    $reportFileName = "$reportFileName.json"
}
$mouseReportPath = Join-Path $targetOutputDir $reportFileName
($mouseReport | ConvertTo-Json -Depth 80) | Set-Content -LiteralPath $mouseReportPath -Encoding UTF8

Write-Output "Foundation mouse-only playtest report written to $mouseReportPath"
Write-Output ("Result: {0}" -f $mouseReport.result)
Write-Output ("Input events recorded: {0}" -f $inputEvents.Count)
Write-Output ("Victory: {0}" -f $mouseReport.victory_result)
Write-Output ("Failure/recovery: {0}" -f $mouseReport.failure_recovery_result)
if ($mouseReport.warnings.Count -gt 0) {
    Write-Output "Warnings:"
    foreach ($warning in $mouseReport.warnings) {
        Write-Output ("- {0}" -f $warning)
    }
}

if ($errors.Count -gt 0) {
    Write-Error ("Mouse-only playtest failed:`n{0}" -f ($errors -join "`n"))
    exit 1
}

exit 0
