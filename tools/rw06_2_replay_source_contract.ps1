[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Worktree = Split-Path -Parent $PSScriptRoot
$RunnerPath = Join-Path $PSScriptRoot 'rw06_2_ending_replay.ps1'
$LauncherPath = Join-Path $PSScriptRoot 'agent_playtest_session.ps1'
$BridgePath = Join-Path $PSScriptRoot 'agent_playtest_session.gd'
$SanitizerPath = Join-Path $PSScriptRoot 'agent_playtest_public_observation.gd'
$ObservationContractPath = Join-Path $PSScriptRoot 'rw06_2_public_observation_contract.gd'
$ReportPath = Join-Path $Worktree '.tmp\rw06_2\replay_source_contract.json'

$failures = [Collections.Generic.List[string]]::new()

function Add-Failure {
    param([Parameter(Mandatory = $true)][string]$Message)
    $failures.Add($Message)
}

function Assert-Contains {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Needle,
        [Parameter(Mandatory = $true)][string]$Message
    )
    if ($Source.IndexOf($Needle, [StringComparison]::Ordinal) -lt 0) {
        Add-Failure $Message
    }
}

function Assert-NotMatch {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Pattern,
        [Parameter(Mandatory = $true)][string]$Message
    )
    if ([regex]::IsMatch($Source, $Pattern, [Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
        Add-Failure $Message
    }
}

function Assert-Match {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Pattern,
        [Parameter(Mandatory = $true)][string]$Message
    )
    if (-not [regex]::IsMatch($Source, $Pattern, [Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
        Add-Failure $Message
    }
}

function Assert-PowerShellParses {
    param([Parameter(Mandatory = $true)][string]$Path)
    $tokens = $null
    $errors = $null
    [void][Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors)
    if ($errors.Count -gt 0) {
        Add-Failure "PowerShell parse failed for $Path`: $($errors[0].Message)"
    }
}

foreach ($path in @($RunnerPath, $LauncherPath, $BridgePath, $SanitizerPath, $ObservationContractPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        Add-Failure "Required rw06_2 source is missing: $path"
    }
}

if ($failures.Count -eq 0) {
    Assert-PowerShellParses $RunnerPath
    Assert-PowerShellParses $LauncherPath

    $runner = Get-Content -LiteralPath $RunnerPath -Raw
    $launcher = Get-Content -LiteralPath $LauncherPath -Raw
    $bridge = Get-Content -LiteralPath $BridgePath -Raw
    $sanitizer = Get-Content -LiteralPath $SanitizerPath -Raw
    $observationContract = Get-Content -LiteralPath $ObservationContractPath -Raw

    foreach ($required in @(
        'function Invoke-CleanEndingRoute',
        'function Invoke-CheatEndingRoute',
        'function Invoke-HeistEndingRoute',
        'function Invoke-BridgeTransportRegression',
        'function Invoke-BridgeStatusRegression',
        "clean = @('players_card')",
        "cheat = @('showdown_survived')",
        "heist = @('heist_clean_sweep', 'heist_out_hot', 'heist_somebody_got_pinched')",
        'click_object $SemanticId',
        'click_action $action',
        'click_map $NodeId',
        'click_choice $ChoiceId',
        'set_field seed $Seed',
        'function Enter-GrandRoom',
        'function Resolve-VisibleBlockingPresentation',
        "'travel:grand_casino_cage'",
        "'environment_layer:casino'",
        'left the same visible handoff and map marker active',
        "Click-Button -Text 'Save'",
        "Click-Button -Text 'Main Menu'",
        "Click-Button -Text 'CONTINUE'",
        'Save -> relaunch -> Continue',
        "@('before_fingerprint')",
        "@('after_fingerprint')",
        'Get-FileHash -LiteralPath $script:TranscriptPath',
        'Get-FileHash -LiteralPath $script:MoneyCurvePath'
    )) {
        Assert-Contains $runner $required "Replay runner is missing required source contract token: $required"
    }

    foreach ($required in @(
        'PublicObservation.sanitize(Fidelity.observable_host_snapshot(app))',
        'PublicObservation.transition_summary(',
        'before_observable,',
        '"trace": transition',
        '"focus_field"',
        '"set_field"',
        '"click_map"',
        '"click_choice"',
        '"click_inventory"'
    )) {
        Assert-Contains $bridge $required "Production-input bridge is missing required source contract token: $required"
    }

    foreach ($required in @(
        'const SCHEMA := "beat_the_house.agent_public_observation"',
        'static func sanitize(',
        'static func canonical_checkpoint(',
        'static func transition_summary(',
        'var before_fingerprint := fingerprint(before_observation)',
        'var after_fingerprint := fingerprint(after_observation)',
        '"dealer_hole_visible"',
        '"dealer_up_card"'
    )) {
        Assert-Contains $sanitizer $required "Public observation sanitizer is missing required source contract token: $required"
    }

    foreach ($required in @(
        'SECRET_HOLE_A',
        'SECRET_SHOE_A',
        'SECRET_BRANCH_A',
        'Private blackjack/run-state changes altered the public observation.',
        'REPORT_PATH'
    )) {
        Assert-Contains $observationContract $required "Public observation hostile contract is missing required token: $required"
    }

    Assert-Contains $launcher '-WindowStyle Hidden' 'Session launcher must keep the game process hidden during agent replay.'
    Assert-Match $launcher "if\s*\(\s*-not\s+\`$PSBoundParameters\.ContainsKey\('Command'\)\s*\)\s*\{[^}]*\bexit\s+0\b[^}]*\}" 'Start-only launcher path must explicitly exit after emitting ready.json.'
    Assert-Contains $launcher "`$commandTempToken -notmatch '^[0-9]+-[a-f0-9]{32}$'" 'Command publication must validate its unique same-directory temporary name.'
    Assert-Contains $launcher 'Set-Content -LiteralPath $commandTempPath -Value $Command' 'Command publication must write bytes to its temporary path first.'
    Assert-Contains $launcher 'Move-Item -LiteralPath $commandTempPath -Destination $commandPath' 'Command publication must atomically rename the complete temporary file.'
    Assert-Contains $launcher 'Remove-Item -LiteralPath $commandTempPath -ErrorAction SilentlyContinue' 'Command publication must clean its temporary file in the finally path.'
    Assert-Contains $bridge 'action_id == "blackjack_deal"' 'The bridge must recognize blackjack''s invisible compatibility Deal hit.'
    Assert-Contains $bridge 'not bool(public_game.get("can_deal", false))' 'The bridge must reject the invisible Deal hit unless the public DEAL control is available.'

    Assert-NotMatch $runner '(?m)^\s*(?:\$[^=]+\s*=\s*)?Invoke-BridgeCommand\s+-Command\s+["''](?:click_xy|key|type)(?:\s|["''])' 'Replay runner must not use raw coordinate, key, or typing commands.'
    Assert-NotMatch $runner 'Get-Value[^\r\n]+(?:run_state|narrative_flags|local_narrative_flags|crew_heist_state|trigger_context|scenario_layout_audit)' 'Replay runner must not read private host-state keys.'
    Assert-NotMatch $runner '\$[A-Za-z_][A-Za-z0-9_]*\.(?:run_state|narrative_flags|local_narrative_flags|crew_heist_state|trigger_context|scenario_layout_audit)\b' 'Replay runner must not access private host-state properties.'
    Assert-NotMatch $runner "@\('environment',\s*'world_map'" 'Replay runner must not fall back to the raw environment world-map model.'
    Assert-NotMatch $runner '\.\s*(?:call|set)\s*\(' 'Replay runner must not call or mutate Godot objects directly.'
    Assert-NotMatch $sanitizer '"(?:turns|game_ids|event_ids|resolved_event_ids|service_ids|travel_hooks|event_options|travel_choices|item_offers|service_options|lender_options|interactable_objects)"' 'Public sanitizer must not admit raw environment model lists or option catalogs.'
    Assert-Contains $runner "Invoke-GameAction -Action 'blackjack_boss_callout' -Index `$index" 'Rourke callouts must click the matching rendered indexed control.'
    Assert-Contains $runner "@('game', 'boss_hand_number') 0) -ne 1" 'Rourke persistence must recognize the publicly numbered first hand.'
    Assert-Contains $runner ".StartsWith('Confirm:', [StringComparison]::OrdinalIgnoreCase)" 'Replay choices must complete visibly armed two-press confirmations.'
    Assert-Contains $observationContract 'Public environment leaked raw model key' 'Hostile observation contract must reject raw environment model keys.'
    Assert-Contains $observationContract 'The rendered screen world map was removed with the raw environment map.' 'Hostile observation contract must preserve the rendered screen map.'
    Assert-Contains $runner 'Start-Process -FilePath $script:PowerShellExe' 'Bridge calls must use the bounded detached subprocess helper.'
    Assert-Contains $runner '-RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath' 'Detached bridge stdout/stderr must use per-call files, never a retained pipeline.'
    Assert-Contains $runner 'while (-not $bridgeProcess.HasExited' 'Detached bridge calls must poll only the short-lived bridge process.'
    Assert-Contains $runner 'Stop-Process -Id $bridgeProcess.Id' 'A timed-out detached bridge call must stop only its bridge PID.'
    Assert-Contains $runner 'Remove-Item -LiteralPath $stdoutPath' 'Detached bridge stdout capture must be cleaned.'
    Assert-Contains $runner 'Remove-Item -LiteralPath $stderrPath' 'Detached bridge stderr capture must be cleaned.'
    Assert-Contains $runner 'function Remove-OwnedBridgeCaptureResidue' 'Bridge captures inherited by the live host need bounded post-exit cleanup.'
    Assert-Contains $runner 'Bridge capture cleanup remained locked after the host exited' 'Post-exit bridge capture cleanup must fail closed.'
    Assert-Contains $runner 'Remove-OwnedBridgeCaptureResidue' 'Bridge lifecycle exits must run deterministic owned-capture cleanup.'
    Assert-Contains $runner "Invoke-BridgeCommand -Command 'wait 1'" 'Transport regression must exercise a second command through the exact replay helper.'
    Assert-Contains $runner 'Get-SessionStatus' 'No-Godot bridge regression must exercise the exact detached helper with a status call.'
    Assert-NotMatch $runner 'Start-Process[^\r\n]+\s-Wait(?:\s|$)' 'Detached bridge helper must not wait on the long-lived descendant process tree.'
    Assert-NotMatch $runner '2>&1\s*\|\s*Out-String' 'Replay bridge calls must not capture a native pipeline retained by the Godot descendant.'
}

$reportDirectory = Split-Path -Parent $ReportPath
[void](New-Item -ItemType Directory -Path $reportDirectory -Force)
$report = [ordered]@{
    contract = 'rw06_2_replay_source'
    passed = ($failures.Count -eq 0)
    failures = @($failures)
}
$report | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $ReportPath -Encoding utf8

if ($failures.Count -gt 0) {
    foreach ($failure in $failures) {
        Write-Error $failure -ErrorAction Continue
    }
    throw "RW06_2_REPLAY_SOURCE_CONTRACT FAIL ($($failures.Count) failure(s)); report: $ReportPath"
}

Write-Output "RW06_2_REPLAY_SOURCE_CONTRACT PASS; report: $ReportPath"
