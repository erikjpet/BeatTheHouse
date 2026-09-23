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
$SemanticScrollReportPath = Join-Path $Worktree '.tmp\rw06_2\semantic_scroll_contract.json'

$failures = [Collections.Generic.List[string]]::new()
$wheelSequenceValidFixtures = 0
$wheelSequenceHostileFixtures = 0
$buttonViewportValidFixtures = 0
$buttonViewportHostileFixtures = 0

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

function Test-WheelPressReleaseSequence {
    param([Parameter(Mandatory = $true)][string]$Source)
    $functionMatch = [regex]::Match(
        $Source,
        '(?ms)^func\s+_push_mouse_wheel\([^\r\n]*\).*?(?=^func\s|\z)'
    )
    if (-not $functionMatch.Success) { return $false }
    return [regex]::IsMatch(
        $functionMatch.Value,
        '(?s)var\s+wheel\s*:=\s*InputEventMouseButton\.new\(\).*?wheel\.pressed\s*=\s*true.*?app\.get_viewport\(\)\.push_input\(wheel,\s*true\)\s*await\s+process_frame\s*var\s+release\s*:=\s*wheel\.duplicate\(\)\s+as\s+InputEventMouseButton\s*release\.pressed\s*=\s*false\s*app\.get_viewport\(\)\.push_input\(release,\s*true\)\s*await\s+process_frame'
    )
}

function Select-ExactButtonViewportFixture {
    param(
        [AllowNull()][object[]]$Candidates,
        [AllowNull()][string]$LiveViewport
    )
    $resolvedCandidates = @($Candidates | Where-Object { $null -ne $_ })
    if ($resolvedCandidates.Count -ne 1) {
        throw "Expected exactly one recorded button input viewport; found $($resolvedCandidates.Count)."
    }
    $recordedViewport = [string]$resolvedCandidates[0]
    if ([string]::IsNullOrWhiteSpace($recordedViewport) -or
        [string]::IsNullOrWhiteSpace($LiveViewport) -or
        $recordedViewport -cne $LiveViewport) {
        throw 'Recorded and live button input viewports are missing or do not match.'
    }
    return $recordedViewport
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

    $validWheelFixture = @'
func _push_mouse_wheel(position: Vector2, button_index: int) -> void:
	var wheel := InputEventMouseButton.new()
	wheel.pressed = true
	app.get_viewport().push_input(wheel, true)
	await process_frame
	var release := wheel.duplicate() as InputEventMouseButton
	release.pressed = false
	app.get_viewport().push_input(release, true)
	await process_frame
'@
    $hostileWheelFixtures = @(
        [pscustomobject]@{ label = 'press-only'; source = @'
func _push_mouse_wheel(position: Vector2, button_index: int) -> void:
	var wheel := InputEventMouseButton.new()
	wheel.pressed = true
	app.get_viewport().push_input(wheel, true)
	await process_frame
'@ },
        [pscustomobject]@{ label = 'release-before-press'; source = @'
func _push_mouse_wheel(position: Vector2, button_index: int) -> void:
	var wheel := InputEventMouseButton.new()
	var release := wheel.duplicate() as InputEventMouseButton
	release.pressed = false
	app.get_viewport().push_input(release, true)
	await process_frame
	wheel.pressed = true
	app.get_viewport().push_input(wheel, true)
	await process_frame
'@ },
        [pscustomobject]@{ label = 'release-still-pressed'; source = @'
func _push_mouse_wheel(position: Vector2, button_index: int) -> void:
	var wheel := InputEventMouseButton.new()
	wheel.pressed = true
	app.get_viewport().push_input(wheel, true)
	await process_frame
	var release := wheel.duplicate() as InputEventMouseButton
	release.pressed = true
	app.get_viewport().push_input(release, true)
	await process_frame
'@ },
        [pscustomobject]@{ label = 'intervening-input'; source = @'
func _push_mouse_wheel(position: Vector2, button_index: int) -> void:
	var wheel := InputEventMouseButton.new()
	wheel.pressed = true
	app.get_viewport().push_input(wheel, true)
	await process_frame
	app.get_viewport().push_input(InputEventMouseMotion.new(), true)
	var release := wheel.duplicate() as InputEventMouseButton
	release.pressed = false
	app.get_viewport().push_input(release, true)
	await process_frame
'@ },
        [pscustomobject]@{ label = 'different-release-source'; source = @'
func _push_mouse_wheel(position: Vector2, button_index: int) -> void:
	var wheel := InputEventMouseButton.new()
	wheel.pressed = true
	app.get_viewport().push_input(wheel, true)
	await process_frame
	var release := InputEventMouseButton.new()
	release.pressed = false
	app.get_viewport().push_input(release, true)
	await process_frame
'@ }
    )
    $wheelSequenceValidFixtures = 1
    $wheelSequenceHostileFixtures = $hostileWheelFixtures.Count
    if (-not (Test-WheelPressReleaseSequence -Source $validWheelFixture)) {
        Add-Failure 'Valid wheel press-release fixture was rejected.'
    }
    foreach ($fixture in $hostileWheelFixtures) {
        if (Test-WheelPressReleaseSequence -Source ([string]$fixture.source)) {
            Add-Failure "Hostile wheel press-release fixture '$($fixture.label)' did not fail closed."
        }
    }
    if (-not (Test-WheelPressReleaseSequence -Source $bridge)) {
        Add-Failure 'Production bridge wheel input must publish its matching release immediately after every press.'
    }

    $validButtonViewportFixtures = @(
        [pscustomobject]@{ label = 'ordinary-root-button'; candidates = @('app-root'); live = 'app-root' },
        [pscustomobject]@{ label = 'confirmation-dialog-button'; candidates = @('tutorial-dialog'); live = 'tutorial-dialog' }
    )
    $buttonViewportValidFixtures = $validButtonViewportFixtures.Count
    foreach ($fixture in $validButtonViewportFixtures) {
        try {
            $selectedViewport = Select-ExactButtonViewportFixture -Candidates @($fixture.candidates) -LiveViewport ([string]$fixture.live)
            if ($selectedViewport -cne [string]$fixture.live) {
                Add-Failure "Valid button viewport fixture '$($fixture.label)' selected the wrong viewport."
            }
        }
        catch {
            Add-Failure "Valid button viewport fixture '$($fixture.label)' threw: $($_.Exception.Message)"
        }
    }
    $hostileButtonViewportFixtures = @(
        [pscustomobject]@{ label = 'null-recorded-viewport'; candidates = @($null); live = 'app-root' },
        [pscustomobject]@{ label = 'wrong-recorded-viewport'; candidates = @('app-root'); live = 'tutorial-dialog' },
        [pscustomobject]@{ label = 'ambiguous-recorded-viewports'; candidates = @('app-root', 'tutorial-dialog'); live = 'tutorial-dialog' }
    )
    $buttonViewportHostileFixtures = $hostileButtonViewportFixtures.Count
    foreach ($fixture in $hostileButtonViewportFixtures) {
        $threw = $false
        try {
            $null = Select-ExactButtonViewportFixture -Candidates @($fixture.candidates) -LiveViewport ([string]$fixture.live)
        }
        catch {
            $threw = $true
        }
        if (-not $threw) {
            Add-Failure "Hostile button viewport fixture '$($fixture.label)' did not fail closed."
        }
    }

    foreach ($required in @(
        'function Invoke-CleanEndingRoute',
        'function Invoke-CheatEndingRoute',
        'function Invoke-HeistEndingRoute',
        'function Invoke-BridgeTransportRegression',
        'function Invoke-BridgeStatusRegression',
        'function Select-UniqueFullyVisibleButton',
        'function Select-UniquePublicTutorialDialogButton',
        'function Select-UniquePublicVerticalScrollSurface',
        'function Reveal-ButtonByVerticalScroll',
        'function Click-RunMenuButton',
        'function Click-TutorialConfirmationButton',
        'function Invoke-SemanticScrollRegression',
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
        'function Get-PublicTalkChoices',
        'function Get-VisibleTutorialGuideAcknowledgment',
        'function Write-FinalPublicCheckpoint',
        'function Get-ExactOwnedSessionProcess',
        'function Stop-ExactOwnedSessionProcess',
        "'travel:grand_casino_cage'",
        "'environment_layer:casino'",
        'left the same visible handoff and map marker active',
        "Click-RunMenuButton -Text 'Save'",
        "Click-RunMenuButton -Text 'Main Menu'",
        "Click-RunMenuButton -Text 'Skip Lessons'",
        "Click-TutorialConfirmationButton -Role ok",
        "Click-Button -Text 'CONTINUE'",
        'Save -> relaunch -> Continue',
        "@('before_fingerprint')",
        "@('after_fingerprint')",
        'Get-FileHash -LiteralPath $script:TranscriptPath',
        'Get-FileHash -LiteralPath $script:MoneyCurvePath',
        "record_kind = 'final_public_checkpoint'",
        'public_fingerprint = $publicFingerprint',
        'checkpoint_fingerprint = $checkpointFingerprint',
        'observed_seed = $observedSeed',
        '$observedSeed -cne $Seed',
        '$currentFinalCheckpointJson -cne $referenceFinalCheckpointJson',
        '$saveText -cne $expectedVisibleText',
        "`$acknowledgment = 'Saved to Resume Slot.'",
        'Assert-ExplicitSaveAcknowledged -Milestone $Milestone',
        "Assert-ExplicitSaveAcknowledged -Milestone 'The Count completed setup'",
        '$maximumChipPurchases = 8',
        "[bool](Get-Value `$_ @('enabled') `$false)",
        "'cage_buy_50' -in `$enabledChoices",
        '$afterChips -le $beforeChips',
        'within $maximumChipPurchases bounded purchases',
        'Start-BridgeSession -SkipInitialLook',
        '@{ stdout = 999999; stderr = 999999 }',
        'retained its relaunched exact owned Godot process after quit',
        'function Assert-NoPostExitLogAlerts',
        'function Assert-ReplayPauseOwnership',
        "@('replay_pause_before')",
        "@('look', 'replay_pause')",
        '$script:SessionRoot = New-AnchoredSessionRoot',
        "`$screenName -cne 'VICTORY'",
        "@('screen', 'run_report_visible') `$false",
        '$Repeat -eq 2',
        'release_qualifying = $releaseQualifying',
        'PLAY did not visibly enter a live active first-night lesson',
        "StartsWith('tutorial_guide:', [StringComparison]::Ordinal)",
        "`$choiceIds.Count -ne 1 -or [string]`$choiceIds[0] -cne 'continue'",
        "Choose-VisibleChoice -ChoiceId 'continue'",
        'follow Pal''s visible tutorial guidance: $label',
        'The live first-night lesson did not render its run menu.',
        'The semantic seed entry was not preserved as exact visible public evidence',
        'Main Menu did not visibly return The Count checkpoint to START before relaunch.'
    )) {
        Assert-Contains $runner $required "Replay runner is missing required source contract token: $required"
    }

    foreach ($required in @(
        'func _public_observation() -> Dictionary:',
        'return PublicObservation.sanitize(snapshot)',
        'const REPLAY_PAUSE_OWNER := "agent_replay"',
        'app.call("set_application_pause_owner", REPLAY_PAUSE_OWNER, true)',
        '"replay_pause": ready_pause',
        '"replay_pause_before": pause_before',
        '"replay_pause": _replay_pause_snapshot()',
        'func _replay_pause_is_valid(snapshot: Dictionary) -> bool:',
        'PublicObservation.transition_summary(',
        'before_observable,',
        '"trace": transition',
        '"focus_field"',
        '"set_field"',
        '"click_map"',
        '"click_choice"',
        '"click_inventory"',
        '"scroll_surface"',
        '"talk_choices": _public_talk_choices(observable)',
        '"scroll_surfaces": _public_scroll_surfaces()',
        '"fully_visible": bool(entry.get("fully_visible", false))',
        'func _scroll_surface(argument: String) -> Dictionary:',
        'func _visible_vertical_scroll_surface(surface_id: String) -> Dictionary:',
        'func _public_scroll_surfaces() -> Array:',
        'func _append_tutorial_confirmation_buttons(result: Array) -> void:',
        'func _button_input_viewport(data: Dictionary, button: Button) -> Viewport:',
        'func _push_mouse_click_in_viewport(viewport: Viewport, position: Vector2, double_click: bool) -> void:',
        '"input_viewport_candidates": [button.get_viewport()]',
        'app.get("tutorial_skip_dialog") as ConfirmationDialog',
        'dialog.get_ok_button()',
        'dialog.get_cancel_button()',
        '"id": "tutorial_skip_dialog:ok"',
        '"id": "tutorial_skip_dialog:cancel"',
        'func _push_mouse_wheel(position: Vector2, button_index: int) -> void:',
        'func _rect_encloses_with_tolerance(outer: Rect2, inner: Rect2, tolerance: float = 0.75) -> bool:',
        'start_menu["seed_text_committed"] = seed_field_visible',
        'screen["run_report_visible"] = screen_id in ["VICTORY", "FAILURE"]',
        'status_hud["save_text_visible"] = _hud_status_tooltip_is_rendered',
        'func _hud_status_tooltip_is_rendered(expected_text: String) -> bool:',
        'if button.disabled:',
        'visible talk choice is disabled'
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
        '"dealer_up_card"',
        'var map_rendered := bool(source.get("world_map_overlay_visible", false))',
        'and bool(overlay_state.get("world_map_visible", false))',
        'if map_rendered else {}',
        'var start_menu_rendered := screen_id == "START"',
        'var run_menu_rendered := bool(source.get("run_menu_visible", false))',
        'and bool(overlay_state.get("run_menu_visible", false))',
        'var run_report_rendered := screen_id in ["VICTORY", "FAILURE"]',
        'and bool(source.get("run_report_visible", false))',
        'if bool(source.get("seed_field_visible", false)) and bool(source.get("seed_text_committed", false))',
        'result["save_text_visible"] = bool(source.get("save_text_visible", false))'
    )) {
        Assert-Contains $sanitizer $required "Public observation sanitizer is missing required source contract token: $required"
    }

    foreach ($required in @(
        'SECRET_HOLE_A',
        'SECRET_SHOE_A',
        'SECRET_BRANCH_A',
        'SECRET_CLOSED_MAP_MARKER',
        'SECRET_CLOSED_MAP_DETAIL',
        'SECRET_CLOSED_MENU_ASYNC_A',
        'Talk typewriter frame timing altered the canonical public trace.',
        'Deterministic talk normalization removed rendered conversation choices.',
        'RUN-SECRET-WALL-CLOCK-A',
        'SECRET_OFFSCREEN_TERMINAL_OUTCOME',
        'A populated closed-overlay world map escaped into public observation.',
        'Closed run-menu async state altered the public trace.',
        'Uncommitted generated menu seeds made replay traces nondeterministic.',
        'Distinct explicitly entered visible seeds were incorrectly normalized away.',
        'An offscreen terminal report escaped into public observation.',
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
    Assert-Contains $launcher "`$ProcessIdentityPath = Join-Path `$SessionRoot 'process.identity.json'" 'Launcher must persist an exact owned-process identity beside its PID.'
    Assert-Contains $launcher "[string]`$SessionRoot = ''" 'Launcher must accept an exact absolute session root that remains stable across date rollover.'
    Assert-Contains $launcher 'session_root = $SessionRoot' 'Launcher process identity must bind to the exact anchored session root.'
    Assert-Contains $launcher '$identity.session_root' 'Launcher must reject process identity from a different session root.'
    Assert-Contains $launcher 'start_utc_ticks = $processStartUtcTicks' 'Launcher process identity must include the exact start time.'
    Assert-Contains $launcher 'if ((Get-ProcessStartUtcTicks -Process $process) -ne [long]$identity.start_utc_ticks)' 'Launcher must reject a reused PID before reporting a session as running.'
    Assert-Contains $launcher 'Set-AtomicJsonFile -Path $LogCursorPath -Value @{ stdout = 0; stderr = 0 }' 'Every same-session Start must atomically reset the cursor for newly truncated logs.'
    Assert-Match $launcher '(?s)if\s*\(\$Start\).*?Set-AtomicJsonFile\s+-Path\s+\$LogCursorPath\s+-Value\s+@\{\s*stdout\s*=\s*0;\s*stderr\s*=\s*0\s*\}.*?Start-Process' 'The zero log cursor must be published inside Start before the redirected Godot process begins.'
    Assert-Contains $bridge 'action_id == "blackjack_deal"' 'The bridge must recognize blackjack''s invisible compatibility Deal hit.'
    Assert-Contains $bridge 'not bool(public_game.get("can_deal", false))' 'The bridge must reject the invisible Deal hit unless the public DEAL control is available.'
    Assert-NotMatch $bridge 'set_application_pause_owner[^\r\n]+false' 'The bridge must retain its deterministic replay pause owner for the entire process lifetime.'
    Assert-Contains $bridge 'var choice_list := talk_dock.get("choice_list") as Node if talk_dock != null else null' 'Semantic TalkDock choices must bind to the actual rendered choice list.'
    Assert-Contains $runner "@('look', 'clickable', 'talk_choices')" 'Replay routes must consume the rendered TalkDock enabled-state mapping.'
    Assert-Contains $runner "@('look', 'clickable', 'scroll_surfaces')" 'Replay routes must consume only the public rendered scroll-surface mapping.'
    Assert-Match $runner '(?s)function Get-VisibleTutorialGuideAcknowledgment.*?tutorial_guide:.*?choiceIds\.Count\s+-ne\s+1.*?choiceIds\[0\].*?continue.*?Get-PublicTalkChoices.*?enabled' 'Coach recovery must accept only one rendered enabled continue choice from the public tutorial-guide TalkDock.'
    Assert-Match $runner '(?s)function Clear-VisibleCoach.*?Get-VisibleTutorialGuideAcknowledgment.*?Choose-VisibleChoice\s+-ChoiceId\s+''continue''.*?Wait-Frames.*?continue.*?dismissLabel' 'Coach recovery must follow the narrow public tutorial-guide acknowledgement before trying the rendered coach dismiss control.'
    Assert-Match $runner '(?s)function Select-UniquePublicVerticalScrollSurface.*?SurfaceId\s+-cne\s+''run_menu''.*?matches\.Count\s+-ne\s+1.*?axis.*?vertical.*?rendered.*?can_scroll_\$Direction' 'Run-menu scroll selection must reject unsupported, ambiguous, hidden, wrong-axis, and direction-blocked public surfaces.'
    Assert-Match $runner '(?s)function Select-UniqueFullyVisibleButton.*?matches\.Count\s+-gt\s+1.*?Properties\[''fully_visible''\].*?-isnot\s+\[bool\].*?fully_visible signal.*?return \$null' 'Run-menu button selection must fail closed on ambiguous, absent, non-boolean, and false fully-visible signals.'
    Assert-Match $runner '(?s)function Select-UniquePublicTutorialDialogButton.*?tutorial_skip_dialog:\$Role.*?surface_id.*?dialog_role.*?matches\.Count\s+-ne\s+1.*?enabled.*?fully_visible.*?dialog_rendered.*?-isnot\s+\[bool\].*?-not\s+\[bool\]' 'Tutorial confirmation selection must require one exact stable-id control with true boolean enabled, fully-visible, and rendered signals.'
    Assert-Match $runner '(?s)function Click-TutorialConfirmationButton.*?Select-UniquePublicTutorialDialogButton.*?tutorial_skip_dialog:\$Role.*?IsNullOrWhiteSpace.*?-cne\s+\$expectedId.*?click_button \$id' 'Tutorial confirmation clicks must use the exact validated stable public id.'
    Assert-Match $runner '(?s)function Reveal-ButtonByVerticalScroll.*?MaximumScrolls\s*=\s*12.*?Select-UniqueFullyVisibleButton.*?Get-PublicScrollSurfaces.*?scroll_surface \$surfaceId \$Direction.*?did not become visible within' 'Run-menu reveal must require a fully visible target, use bounded public semantic scroll inputs, and fail closed.'
    Assert-NotMatch $runner '\$null\s+-eq\s+\(Find-Button\s+-Text\s+''Skip Lessons''\)' 'The tutorial route must not demand an already visible Skip Lessons button before semantic scrolling can reveal it.'
    Assert-NotMatch $runner '(?:Find-Button|Click-Button)\s+-Text\s+''OK''' 'The tutorial confirmation route must not select the generic OK label.'
    Assert-Match $bridge '(?s)func _scroll_surface\(argument: String\).*?surface_id != "run_menu".*?direction not in \["up", "down"\].*?surface\.get\(capability, false\).*?_push_mouse_wheel.*?after <= before.*?after >= before' 'The bridge semantic scroll command must allow only rendered public run-menu capabilities and verify real wheel movement.'
    Assert-Match $bridge '(?s)func _click_button\(target: String\).*?fully_visible.*?button became hidden, clipped, or disabled before click' 'The bridge must re-check that a semantic button is fully visible immediately before clicking it.'
    Assert-Match $bridge '(?s)func _click_button\(target: String\).*?_button_input_viewport\(data, button\).*?input_viewport\s*==\s*null.*?missing, changed, or ambiguous.*?_push_mouse_click_in_viewport\(input_viewport, click_position, false\)' 'Every semantic button click must fail closed on stale viewport identity and route input through the exact button viewport.'
    Assert-Match $bridge '(?s)func _button_input_viewport\(data: Dictionary, button: Button\).*?input_viewport_candidates.*?viewport_candidates\.size\(\)\s*!=\s*1.*?viewport_candidates\[0\]\s+as\s+Viewport.*?button\.get_viewport\(\).*?recorded_viewport\s*!=\s*live_viewport.*?return recorded_viewport' 'Button viewport selection must require one non-null recorded viewport that still exactly matches the live button viewport.'
    Assert-Match $bridge '(?s)func _push_mouse_click\(position: Vector2, double_click: bool\).*?_push_mouse_click_in_viewport\(app\.get_viewport\(\), position, double_click\).*?func _push_mouse_click_in_viewport\(viewport: Viewport.*?viewport\.push_input\(motion, true\).*?viewport\.push_input\(press, true\).*?viewport\.push_input\(release, true\)' 'Ordinary clicks must retain the root viewport while exact button clicks may route the same real input sequence through an embedded dialog viewport.'
    Assert-Match $bridge '(?s)func _collect_buttons\(node: Node, result: Array\).*?full_rect\s*:=\s*button\.get_global_rect\(\).*?visible_rect\s*:=\s*_clipped_control_rect\(button\).*?"fully_visible":\s*_rect_encloses_with_tolerance\(visible_rect, full_rect\)' 'The bridge must derive fully-visible button state by comparing the full global rect with the clipped visible rect.'
    Assert-Match $bridge '(?s)func _append_tutorial_confirmation_buttons\(result: Array\).*?app\.get\("tutorial_skip_dialog"\) as ConfirmationDialog.*?dialog\s*==\s*null.*?not\s+dialog\.visible.*?dialog\.size\.x\s*<=\s*0.*?dialog\.size\.y\s*<=\s*0.*?dialog\.get_ok_button\(\).*?tutorial_skip_dialog:ok.*?dialog\.get_cancel_button\(\).*?tutorial_skip_dialog:cancel.*?button\.disabled.*?button\.is_visible_in_tree\(\).*?_clipped_control_rect\(button\).*?visible_rect\.has_area\(\).*?"fully_visible":\s*_rect_encloses_with_tolerance\(visible_rect, full_rect\).*?"dialog_rendered":\s*true' 'The bridge may expose only the rendered, enabled, fully measured tutorial confirmation OK/Cancel controls under exact stable ids.'
    Assert-NotMatch $bridge '_control_is_rendered\(dialog\)' 'ConfirmationDialog is a Window, so the bridge must not pass it to the Control-only rendered helper.'
    Assert-Match $bridge '(?s)func _clipped_control_rect\(control: Control\).*?control\.get_viewport\(\).*?viewport\s*==\s*null.*?control\.get_global_rect\(\)\.intersection\(viewport\.get_visible_rect\(\)\)' 'Control visibility and click coordinates must be clipped in the exact control viewport coordinate space.'
    Assert-NotMatch $bridge 'get_children\(true\)' 'The bridge must not broadly enumerate internal controls; only the tutorial confirmation whitelist is admissible.'
    Assert-NotMatch $bridge '\.scroll_vertical\s*=' 'The replay bridge must not inject scroll-container state directly.'
    Assert-Contains $runner "@('players_card_eligible') `$false" 'Clean-ending eligibility must fail closed when its public field is absent.'
    Assert-Contains $runner 'Stop-Process -Id $script:OwnedSessionPid -Force -ErrorAction Stop' 'Failure cleanup may force-stop only the exact recorded session-owned Godot PID.'
    Assert-Contains $runner '$actualStartUtcTicks -ne $script:OwnedSessionStartUtcTicks' 'Failure cleanup must verify process start identity before force-stop.'
    Assert-Contains $runner '$actualExecutablePath.Equals($expectedExecutablePath' 'Failure cleanup must verify the owned executable path before force-stop.'
    Assert-Match $runner '(?s)Wait-ForSessionExit\s*\r?\n\s*Assert-NoPostExitLogAlerts\s*\r?\n\s*Remove-OwnedBridgeCaptureResidue\s*\r?\n\s*Start-BridgeSession' 'Every same-session relaunch must rescan complete logs after exit and before cleanup/restart.'
    Assert-Match $runner '(?s)function Stop-BridgeSessionSafely.*?Assert-NoPostExitLogAlerts.*?Remove-OwnedBridgeCaptureResidue' 'Final cleanup must rescan complete logs after exit and before residue cleanup/PASS.'
    Assert-NotMatch $runner '\bKeepSessionOnFailure\b' 'Replay failures must not expose an option that leaves the owned Godot host alive.'

    Assert-NotMatch $runner '(?m)^\s*(?:\$[^=]+\s*=\s*)?Invoke-BridgeCommand\s+-Command\s+["''](?:click_xy|key|type)(?:\s|["''])' 'Replay runner must not use raw coordinate, key, or typing commands.'
    Assert-NotMatch $runner 'Get-Value[^\r\n]+(?:run_state|narrative_flags|local_narrative_flags|crew_heist_state|trigger_context|scenario_layout_audit)' 'Replay runner must not read private host-state keys.'
    Assert-NotMatch $runner '\$[A-Za-z_][A-Za-z0-9_]*\.(?:run_state|narrative_flags|local_narrative_flags|crew_heist_state|trigger_context|scenario_layout_audit)\b' 'Replay runner must not access private host-state properties.'
    Assert-NotMatch $runner "@\('environment',\s*'world_map'" 'Replay runner must not fall back to the raw environment world-map model.'
    Assert-NotMatch $runner '\.\s*(?:call|set)\s*\(' 'Replay runner must not call or mutate Godot objects directly.'
    Assert-NotMatch $sanitizer '"(?:turns|game_ids|event_ids|resolved_event_ids|service_ids|travel_hooks|event_options|travel_choices|item_offers|service_options|lender_options|interactable_objects)"' 'Public sanitizer must not admit raw environment model lists or option catalogs.'
    Assert-NotMatch $sanitizer '"typewriter_active"' 'Frame-time-dependent TalkDock typewriter state must not contaminate deterministic public fingerprints.'
    Assert-Contains $runner "Invoke-GameAction -Action 'blackjack_boss_callout' -Index `$index" 'Rourke callouts must click the matching rendered indexed control.'
    Assert-Contains $runner "@('game', 'boss_hand_number') 0) -ne 1" 'Rourke persistence must recognize the publicly numbered first hand.'
    Assert-Contains $runner ".StartsWith('Confirm:', [StringComparison]::OrdinalIgnoreCase)" 'Replay choices must complete visibly armed two-press confirmations.'
    Assert-Contains $observationContract 'Public environment leaked raw model key' 'Hostile observation contract must reject raw environment model keys.'
    Assert-Contains $observationContract 'The rendered screen world map was removed with the raw environment map.' 'Hostile observation contract must preserve the rendered screen map.'
    Assert-Contains $observationContract 'closed_map_screen["world_map_overlay_visible"] = false' 'Hostile observation contract must exercise a populated map while its overlay is closed.'
    Assert-Contains $observationContract 'unrendered_map_screen["overlay_state"] = {"world_map_visible": false}' 'Hostile observation contract must reject a stale outer-visible map that is not rendered.'
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

    $crossDateSession = "rw062-source-contract-$PID"
    $crossDateRoot = [IO.Path]::GetFullPath((Join-Path $Worktree ".tmp\agent_playtest\1999-12-31\$crossDateSession"))
    try {
        $crossDateOutput = & $LauncherPath -Session $crossDateSession -SessionRoot $crossDateRoot | Out-String
        $crossDateStatus = $crossDateOutput | ConvertFrom-Json
        $reportedCrossDateRoot = [IO.Path]::GetFullPath([string]$crossDateStatus.folder)
        if ([bool]$crossDateStatus.running -or
            -not $reportedCrossDateRoot.Equals($crossDateRoot, [StringComparison]::OrdinalIgnoreCase)) {
            Add-Failure 'Launcher cross-date contract did not preserve the exact supplied absolute session root.'
        }
    }
    catch {
        Add-Failure "Launcher cross-date contract failed: $($_.Exception.Message)"
    }

    try {
        $scrollOutput = & $RunnerPath -Ending clean -SemanticScrollContract | Out-String
        $scrollReport = $scrollOutput | ConvertFrom-Json
        if (-not [bool]$scrollReport.passed -or [int]$scrollReport.hostile_fixtures -ne 7) {
            Add-Failure 'Semantic scroll hostile regression did not pass all seven fail-closed fixtures.'
        }
        if ([int]$scrollReport.hostile_button_fixtures -ne 5) {
            Add-Failure 'Semantic scroll hostile regression did not pass all five fully-visible button fixtures.'
        }
        if ([int]$scrollReport.valid_dialog_fixtures -ne 2 -or [int]$scrollReport.hostile_dialog_fixtures -ne 7) {
            Add-Failure 'Tutorial confirmation regression did not pass both exact controls and all seven fail-closed fixtures.'
        }
        if (-not (Test-Path -LiteralPath $SemanticScrollReportPath -PathType Leaf)) {
            Add-Failure 'Semantic scroll hostile regression did not publish its deterministic report.'
        }
    }
    catch {
        Add-Failure "Semantic scroll hostile regression failed: $($_.Exception.Message)"
    }
}

$reportDirectory = Split-Path -Parent $ReportPath
[void](New-Item -ItemType Directory -Path $reportDirectory -Force)
$report = [ordered]@{
    contract = 'rw06_2_replay_source'
    passed = ($failures.Count -eq 0)
    wheel_sequence_valid_fixtures = $wheelSequenceValidFixtures
    wheel_sequence_hostile_fixtures = $wheelSequenceHostileFixtures
    button_viewport_valid_fixtures = $buttonViewportValidFixtures
    button_viewport_hostile_fixtures = $buttonViewportHostileFixtures
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
