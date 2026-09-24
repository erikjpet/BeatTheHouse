[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Worktree = Split-Path -Parent $PSScriptRoot
$RunnerPath = Join-Path $PSScriptRoot 'rw06_2_ending_replay.ps1'
$ReplayPolicyPath = Join-Path $PSScriptRoot 'rw06_2_replay_policies.ps1'
$LauncherPath = Join-Path $PSScriptRoot 'agent_playtest_session.ps1'
$BridgePath = Join-Path $PSScriptRoot 'agent_playtest_session.gd'
$SanitizerPath = Join-Path $PSScriptRoot 'agent_playtest_public_observation.gd'
$ObservationContractPath = Join-Path $PSScriptRoot 'rw06_2_public_observation_contract.gd'
$FoundationMainPath = Join-Path $Worktree 'scripts\ui\foundation_main.gd'
$FoundationHudBarPath = Join-Path $Worktree 'scripts\ui\foundation_hud_bar.gd'
$FoundationScreenBuilderPath = Join-Path $Worktree 'scripts\ui\foundation_screen_builder.gd'
$PixelSceneCanvasPath = Join-Path $Worktree 'scripts\ui\pixel_scene_canvas.gd'
$TalkDockPath = Join-Path $Worktree 'scripts\ui\talk_dock.gd'
$RunStatePath = Join-Path $Worktree 'scripts\core\run_state.gd'
$EventsPath = Join-Path $Worktree 'data\events\events.json'
$ReportPath = Join-Path $Worktree '.tmp\rw06_2\replay_source_contract.json'
$SemanticScrollReportPath = Join-Path $Worktree '.tmp\rw06_2\semantic_scroll_contract.json'

$failures = [Collections.Generic.List[string]]::new()
$wheelSequenceValidFixtures = 0
$wheelSequenceHostileFixtures = 0
$buttonViewportValidFixtures = 0
$buttonViewportHostileFixtures = 0
$machineJamValidFixtures = 0
$machineJamHostileFixtures = 0
$grandFareFundingValidFixtures = 0
$grandFareFundingHostileFixtures = 0
$grandFareCashEventValidFixtures = 0
$grandFareCashEventHostileFixtures = 0
$commandOpenValidFixtures = 0
$commandOpenHostileFixtures = 0
$cheatBlackjackValidFixtures = 0
$cheatBlackjackHostileFixtures = 0
$cheatBossCalloutValidFixtures = 0
$cheatBossCalloutHostileFixtures = 0
$cheatShowdownWalkValidFixtures = 0
$cheatShowdownWalkHostileFixtures = 0
$cheatDuelContinuationValidFixtures = 0
$cheatDuelContinuationHostileFixtures = 0

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

function Test-CommandOpenRetrySequence {
    param([Parameter(Mandatory = $true)][string]$Source)
    $functionMatch = [regex]::Match(
        $Source,
        '(?ms)^func\s+_poll_once\(\)[^\r\n]*\r?\n.*?(?=^func\s|\z)'
    )
    if (-not $functionMatch.Success) { return $false }
    return [regex]::IsMatch(
        $functionMatch.Value,
        '(?s)var\s+file\s*:=\s*FileAccess\.open\(command_path,\s*FileAccess\.READ\)\s*if\s+file\s*==\s*null:\s*return\s*var\s+raw\s*:=\s*file\.get_as_text\(\)\.strip_edges\(\)\s*file\.close\(\)\s*var\s+result\s*:=\s*await\s+_execute_command\(raw,\s*next_command\)\s*_write_json\([^\r\n]+result\)\s*next_command\s*\+=\s*1'
    )
}

function Resolve-ButtonInputRouteFixture {
    param(
        [AllowNull()][object[]]$Candidates,
        [AllowNull()][string]$LiveViewport,
        [Parameter(Mandatory = $true)][string]$RootViewport,
        [string]$SurfaceId = '',
        [bool]$Embedded = $false,
        [string]$ParentNode = '',
        [string]$EmbedderViewport = '',
        [double]$WindowX = 0,
        [double]$WindowY = 0,
        [double]$LocalX = 0,
        [double]$LocalY = 0
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
    if ($recordedViewport -ceq $RootViewport) {
        return [pscustomobject]@{ viewport = $RootViewport; x = $LocalX; y = $LocalY }
    }
    if ($SurfaceId -cne 'tutorial_skip_dialog' -or -not $Embedded -or
        $ParentNode -cne 'app' -or
        [string]::IsNullOrWhiteSpace($EmbedderViewport) -or
        $EmbedderViewport -cne $RootViewport) {
        throw 'Embedded tutorial dialog route is missing, non-embedded, nested, or bound to the wrong embedder.'
    }
    return [pscustomobject]@{
        viewport = $EmbedderViewport
        x = $WindowX + $LocalX
        y = $WindowY + $LocalY
    }
}

function Assert-ButtonInputRouteFixture {
    param(
        [Parameter(Mandatory = $true)]$Fixture
    )
    $route = Resolve-ButtonInputRouteFixture `
        -Candidates @($Fixture.candidates) `
        -LiveViewport ([string]$Fixture.live) `
        -RootViewport ([string]$Fixture.root) `
        -SurfaceId ([string]$Fixture.surface_id) `
        -Embedded ([bool]$Fixture.embedded) `
        -ParentNode ([string]$Fixture.parent_node) `
        -EmbedderViewport ([string]$Fixture.embedder) `
        -WindowX ([double]$Fixture.window_x) `
        -WindowY ([double]$Fixture.window_y) `
        -LocalX ([double]$Fixture.local_x) `
        -LocalY ([double]$Fixture.local_y)
    if ([string]$route.viewport -cne [string]$Fixture.expected_viewport -or
        [Math]::Abs([double]$route.x - [double]$Fixture.expected_x) -gt 0.0001 -or
        [Math]::Abs([double]$route.y - [double]$Fixture.expected_y) -gt 0.0001) {
        throw "Resolved button input route did not match the exact expected viewport/position."
    }
    return $route
}

function New-MachineJamPolicyFixture {
    param([switch]$WithHiddenSentinels)
    $fixture = [pscustomobject]@{
        event_popup = [pscustomobject]@{
            visible = $true
            render_valid = $true
            event_id = 'machine_jam'
            title = 'Machine Jam'
            summary = "The machine stops. The room doesn't."
            choice_ids = @('wait', 'push')
            choices = @(
                [pscustomobject]@{ id = 'wait'; label = 'Wait it out'; text = 'Play stops. Attention moves on.'; enabled = $true },
                [pscustomobject]@{ id = 'push'; label = 'Push through'; text = 'You keep playing. The room turns your way.'; enabled = $true }
            )
        }
        talk = [pscustomobject]@{ visible = $false }
    }
    if ($WithHiddenSentinels) {
        $fixture.event_popup.choices[0] | Add-Member -NotePropertyName consequence_summary -NotePropertyValue 'HIDDEN SENTINEL'
        $fixture.event_popup.choices[0] | Add-Member -NotePropertyName impact_summary -NotePropertyValue 'HIDDEN SENTINEL'
        $fixture.event_popup.choices[0] | Add-Member -NotePropertyName requires_confirm -NotePropertyValue $true
    }
    return $fixture
}


function New-GrandFareFundingPolicyFixture {
    param([ValidateSet('crew', 'family', 'street', 'motel_friend')][string]$Kind = 'crew')

    $definition = switch ($Kind) {
        'family' {
            [pscustomobject]@{
                lender_id = 'brother_in_law'; lender_label = 'Your Brother-in-Law'; world_node_id = 'motel'
                terms = 'Family help. Family invoice. Borrow $30. Repay $33 (10% interest) in 6 turns.'
                principal = 30; before_bankroll = 86; debt_kind = 'cash'
                before_debt = [pscustomobject]@{ rendered = $true; present = $true; tooltip = 'Vic Mercer balance 30' }
                after_debt = [pscustomobject]@{ rendered = $true; present = $true; tooltip = '2 active debts' }
                message = 'Family money arrives with a sigh attached.'
            }
        }
        'street' {
            [pscustomobject]@{
                lender_id = 'street_lender'; lender_label = 'Vic Mercer'; world_node_id = 'back_alley'
                terms = 'Fast cash. A cold book. Borrow $25. Repay $30 (10% interest) in 3 turns.'
                principal = 25; before_bankroll = 100; debt_kind = 'cash'
                before_debt = [pscustomobject]@{ rendered = $true; present = $false }
                after_debt = [pscustomobject]@{ rendered = $true; present = $true; tooltip = 'Vic Mercer balance 30' }
                message = 'Fast cash. Your name in the book.'
            }
        }
        'motel_friend' {
            [pscustomobject]@{
                lender_id = 'motel_friend'; lender_label = 'Motel Friend'; world_node_id = 'motel'
                terms = 'A soft loan. Thin walls. Borrow $20. Repay $24 (10% interest) in 4 turns.'
                principal = 20; before_bankroll = 86; debt_kind = 'cash'
                before_debt = [pscustomobject]@{ rendered = $true; present = $false }
                after_debt = [pscustomobject]@{ rendered = $true; present = $true; tooltip = 'Motel Friend balance 24' }
                message = "Nico spots you cash and says it's nothing."
            }
        }
        default {
            [pscustomobject]@{
                lender_id = 'the_crew'; lender_label = 'The Crew'; world_node_id = 'kitty_cat_lounge'
                terms = 'No interest. Only favors. Borrow $45. Repay 2 favors (0% cash interest) in 2 turns.'
                principal = 45; before_bankroll = 63; debt_kind = 'favor'
                before_debt = [pscustomobject]@{ rendered = $true; present = $false }
                after_debt = [pscustomobject]@{ rendered = $true; present = $true; tooltip = 'The Crew wants 2 favors' }
                message = "The Crew hands it over like it was always yours. It wasn't."
            }
        }
    }
    $lenderId = [string]$definition.lender_id
    $lenderLabel = [string]$definition.lender_label
    $worldNodeId = [string]$definition.world_node_id
    $terms = [string]$definition.terms
    $principal = [int]$definition.principal
    $beforeBankroll = [int]$definition.before_bankroll
    $beforeDebtIndicator = $definition.before_debt
    $afterDebtIndicator = $definition.after_debt
    $authoredMessage = [string]$definition.message

    return [pscustomobject]@{
        world_node_id = $worldNodeId
        expected_semantic_id = "lender:$lenderId"
        canvas_objects = @([pscustomobject]@{
            semantic_id = "lender:$lenderId"
            label = $lenderLabel
            object_type = 'character'
            enabled = $true
            rendered = $true
        })
        room_actions = @([pscustomobject]@{
            id = ''
            action = ''
            action_id = ''
            emit_object_id = ''
            label = 'Use'
            enabled = $true
            index = 0
        })
        talk = [pscustomobject]@{
            visible = $true
            render_valid = $true
            expanded = $true
            body_complete = $true
            typewriter_active = $false
            event_id = "lender_conversation:borrow:$lenderId"
            summary = $terms
            choice_ids = @('accept', 'decline')
        }
        talk_choices = @(
            [pscustomobject]@{ id = 'accept'; label = 'Accept Offer'; enabled = $true },
            [pscustomobject]@{ id = 'decline'; label = 'Not Now'; enabled = $true }
        )
        confirmation_talk = [pscustomobject]@{
            visible = $true
            render_valid = $true
            expanded = $true
            body_complete = $true
            typewriter_active = $false
            event_id = "lender_conversation:borrow:$lenderId"
            summary = $terms
            choice_ids = @('accept', 'decline')
        }
        confirmation_choices = @(
            [pscustomobject]@{ id = 'accept'; label = 'Confirm: Accept Offer'; enabled = $true },
            [pscustomobject]@{ id = 'decline'; label = 'Not Now'; enabled = $true }
        )
        accepted_offer_keys = @()
        accepted_lender_ids = @()
        before_bankroll = $beforeBankroll
        before_debt_indicator = $beforeDebtIndicator
        expected_principal = $principal
        expected_debt_kind = [string]$definition.debt_kind
        after_observation = [pscustomobject]@{
            status_hud = [pscustomobject]@{
                bankroll_rendered = $true
                bankroll = $beforeBankroll + $principal
                debt_indicator = $afterDebtIndicator
            }
            talk = [pscustomobject]@{ visible = $false }
            feedback = [pscustomobject]@{
                visible = $true
                title = 'Result'
                text = '{0} {1}  $+{2}' -f $authoredMessage, $terms, $principal
            }
        }
    }
}


function New-GrandFareCashEventPolicyFixture {
    param([ValidateSet('alley', 'wedding')][string]$Kind = 'alley')

    $isWedding = $Kind -ceq 'wedding'
    $eventId = if ($isWedding) { 'scenario_wedding_overflow_hallway' } else { 'back_alley_offer' }
    $eventLabel = if ($isWedding) { 'Hallway Table' } else { 'Back Alley Offer' }
    $choiceId = if ($isWedding) { 'take_the_hallway_seat' } else { 'take_cash' }
    $choiceLabel = if ($isWedding) { 'Take the hallway seat' } else { 'Take the cash' }
    $otherChoiceId = if ($isWedding) { 'step_over_the_coolers' } else { 'walk' }
    $otherChoiceLabel = if ($isWedding) { 'Step over the coolers' } else { 'Keep walking' }
    $message = if ($isWedding) { 'The wedding pays out to learn your face.' } else { 'Small cash. Small stain. Both travel light.' }
    $cashDelta = if ($isWedding) { 10 } else { 8 }
    $heatDelta = if ($isWedding) { 3 } else { 2 }
    $beforeBankroll = if ($isWedding) { 116 } else { 171 }
    $beforeHeat = 4

    return [pscustomobject]@{
        world_node_id = if ($isWedding) { 'motel' } else { 'back_alley' }
        event_id = $eventId
        event_object = [pscustomobject]@{
            semantic_id = "event:$eventId"
            label = $eventLabel
            object_type = 'event'
            enabled = $true
            rendered = $true
        }
        room_actions = @(
            [pscustomobject]@{ emit_object_id = ('event_response:{0}:{1}' -f $eventId, $choiceId); label = $choiceLabel; enabled = $true; index = 0 },
            [pscustomobject]@{ emit_object_id = ('event_response:{0}:{1}' -f $eventId, $otherChoiceId); label = $otherChoiceLabel; enabled = $true; index = 1 }
        )
        talk = [pscustomobject]@{ visible = $false }
        resolved_event_keys = @()
        before_bankroll = $beforeBankroll
        before_heat = $beforeHeat
        before_feedback = [pscustomobject]@{ visible = $false }
        after_observation = [pscustomobject]@{
            status_hud = [pscustomobject]@{
                bankroll_rendered = $true
                bankroll = $beforeBankroll + $cashDelta
                heat_rendered = $true
                heat_level = $beforeHeat + $heatDelta
            }
            event_popup = [pscustomobject]@{ visible = $false }
            talk = [pscustomobject]@{ visible = $false }
            feedback = [pscustomobject]@{
                visible = $true
                title = 'Result'
                text = '{0}  $+{1} / Heat +{2}' -f $message, $cashDelta, $heatDelta
            }
        }
    }
}


function New-CheatReplayBlackjackPolicyFixture {
    param([ValidateSet('wait_for_deal', 'open_window', 'peek', 'complete')][string]$Stage = 'open_window')

    $peekAvailable = $Stage -cin @('open_window', 'peek')
    $peekWindowOpen = $Stage -ceq 'peek'
    $dealerHoleVisible = $Stage -ceq 'complete'
    $canDeal = $Stage -ceq 'wait_for_deal'
    return [pscustomobject]@{
        game = [pscustomobject]@{
            peek_available = $peekAvailable
            peek_window_open = $peekWindowOpen
            dealer_hole_visible = $dealerHoleVisible
            can_deal = $canDeal
            cheat_actions = @(
                [pscustomobject]@{ id = 'peek_hole_card'; kind = 'cheat'; label = 'Peek Hole Card' },
                [pscustomobject]@{ id = 'count_cards'; kind = 'cheat'; label = 'Count Cards' }
            )
        }
        surface_actions = @(
            [pscustomobject]@{ action = 'blackjack_distraction'; index = 1; enabled = $true },
            [pscustomobject]@{ action = 'blackjack_distraction'; index = 0; enabled = $true },
            [pscustomobject]@{ action = 'blackjack_peek'; index = 0; enabled = $true }
        )
        expected_stage = $Stage
        expected_index = if ($Stage -ceq 'open_window' -or $Stage -ceq 'peek') { 0 } else { -1 }
    }
}


function New-CheatReplayBossCalloutPolicyFixture {
    param(
        [ValidateSet('defer_until_dealt', 'call_stack', 'call_swap', 'none')][string]$Stage = 'call_stack'
    )

    $tell = switch ($Stage) {
        'call_swap' { 'Rourke thumbs the down card before the cut.' }
        'none' { 'Rourke gives nothing away.' }
        default { 'Rourke squares one slug against the stack.' }
    }
    return [pscustomobject]@{
        game = [pscustomobject]@{
            boss_duel_active = $true
            boss_tell = $tell
            boss_callouts = @(
                [pscustomobject]@{ id = 'stacked_shoe'; label = 'Call the stack' },
                [pscustomobject]@{ id = 'hole_swap'; label = 'Call the swap' }
            )
            boss_callout_used = $false
            can_deal = $Stage -ceq 'defer_until_dealt'
        }
        surface_actions = @(
            [pscustomobject]@{ action = 'blackjack_boss_callout'; index = 0; enabled = $true },
            [pscustomobject]@{ action = 'blackjack_boss_callout'; index = 1; enabled = $true }
        )
        expected_stage = if ($Stage -cin @('call_stack', 'call_swap')) { 'call' } else { $Stage }
        expected_index = if ($Stage -ceq 'call_stack') { 0 } elseif ($Stage -ceq 'call_swap') { 1 } elseif ($Stage -ceq 'defer_until_dealt') { 0 } else { -1 }
    }
}


function New-CheatReplayShowdownWalkPolicyFixture {
    param(
        [AllowEmptyCollection()][string[]]$ChoiceIds = @('keep_everything'),
        [string]$ExpectedChoice = 'keep_everything'
    )

    $choices = @($ChoiceIds | ForEach-Object {
        [pscustomobject]@{
            id = [string]$_
            label = ([string]$_).Replace('_', ' ')
            text = "Visible consequence for $($_)."
            enabled = $true
        }
    })
    return [pscustomobject]@{
        popup = [pscustomobject]@{
            visible = $true
            render_valid = $true
            event_id = 'the_house_calls'
            choice_ids = @($ChoiceIds)
            choices = $choices
        }
        expected_choice = $ExpectedChoice
    }
}


function Test-CheatReplayDuelContinuationOrder {
    param([Parameter(Mandatory = $true)][string]$Source)

    $functionMatch = [regex]::Match($Source, '(?ms)^function Enter-BlackjackTable\s*\{.*?(?=^function |\z)')
    if (-not $functionMatch.Success) { return $false }
    $body = $functionMatch.Value
    $navigationIndex = $body.IndexOf('Enter-GrandRoom -Room main', [StringComparison]::Ordinal)
    $screenIndex = $body.IndexOf("@('screen', 'screen')", [StringComparison]::Ordinal)
    $gameIndex = $body.IndexOf("@('game', 'game_id')", [StringComparison]::Ordinal)
    $returnIndex = $body.IndexOf('return', [StringComparison]::Ordinal)
    return $navigationIndex -gt 0 -and
        $screenIndex -ge 0 -and $screenIndex -lt $navigationIndex -and
        $gameIndex -ge 0 -and $gameIndex -lt $navigationIndex -and
        $returnIndex -ge 0 -and $returnIndex -lt $navigationIndex
}

foreach ($path in @(
    $RunnerPath, $ReplayPolicyPath, $LauncherPath, $BridgePath, $SanitizerPath,
    $ObservationContractPath, $FoundationMainPath, $FoundationHudBarPath,
    $FoundationScreenBuilderPath, $PixelSceneCanvasPath, $TalkDockPath, $RunStatePath,
    $EventsPath
)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        Add-Failure "Required rw06_2 source is missing: $path"
    }
}

if ($failures.Count -eq 0) {
    Assert-PowerShellParses $RunnerPath
    Assert-PowerShellParses $ReplayPolicyPath
    Assert-PowerShellParses $LauncherPath

    $runner = Get-Content -LiteralPath $RunnerPath -Raw
    $replayPolicy = Get-Content -LiteralPath $ReplayPolicyPath -Raw
    $launcher = Get-Content -LiteralPath $LauncherPath -Raw
    $bridge = Get-Content -LiteralPath $BridgePath -Raw
    $sanitizer = Get-Content -LiteralPath $SanitizerPath -Raw
    $observationContract = Get-Content -LiteralPath $ObservationContractPath -Raw
    $foundationMain = Get-Content -LiteralPath $FoundationMainPath -Raw
    $foundationHudBar = Get-Content -LiteralPath $FoundationHudBarPath -Raw
    $foundationScreenBuilder = Get-Content -LiteralPath $FoundationScreenBuilderPath -Raw
    $pixelSceneCanvas = Get-Content -LiteralPath $PixelSceneCanvasPath -Raw
    $talkDock = Get-Content -LiteralPath $TalkDockPath -Raw
    $runState = Get-Content -LiteralPath $RunStatePath -Raw

    try {
        $eventCatalogValue = Get-Content -LiteralPath $EventsPath -Raw | ConvertFrom-Json
        $eventCatalog = @($eventCatalogValue)
        $showdownEvents = @($eventCatalog | Where-Object { $_.id -is [string] -and [string]$_.id -ceq 'the_house_calls' })
        if ($showdownEvents.Count -ne 1) {
            throw "Expected one exact the_house_calls event; found $($showdownEvents.Count)."
        }
        $classifications = @($showdownEvents[0].payload.pat_down.classifications)
        $contraband = @($classifications | Where-Object { $_.id -is [string] -and [string]$_.id -ceq 'contraband' })
        $surveillance = @($classifications | Where-Object { $_.id -is [string] -and [string]$_.id -ceq 'surveillance' })
        if ($classifications.Count -ne 2 -or $contraband.Count -ne 1 -or $surveillance.Count -ne 1 -or
            (@($contraband[0].item_ids) -join ',') -cne 'marked_cards,foil_sleeve,weighted_keyring' -or
            (@($surveillance[0].item_ids) -join ',') -cne 'xray_glasses,tab_detector,tarot_card') {
            throw 'Showdown classified-item catalog changed without an updated public walk policy.'
        }
    }
    catch {
        Add-Failure "Showdown classified-item source contract failed: $($_.Exception.Message)"
    }

    try {
        . $ReplayPolicyPath
    }
    catch {
        Add-Failure "Replay policy helper could not be loaded: $($_.Exception.Message)"
    }

    $blackjackPolicyCommand = Get-Command 'Select-CheatReplayBlackjackCheatAction' -ErrorAction SilentlyContinue
    if ($null -ne $blackjackPolicyCommand) {
        $validBlackjackCases = @(
            New-CheatReplayBlackjackPolicyFixture -Stage wait_for_deal
            New-CheatReplayBlackjackPolicyFixture -Stage open_window
            New-CheatReplayBlackjackPolicyFixture -Stage peek
            New-CheatReplayBlackjackPolicyFixture -Stage complete
        )
        $cheatBlackjackValidFixtures = $validBlackjackCases.Count
        foreach ($fixture in $validBlackjackCases) {
            try {
                $selection = Select-CheatReplayBlackjackCheatAction -Game $fixture.game -SurfaceActions @($fixture.surface_actions)
                if ([string]$selection.stage -cne [string]$fixture.expected_stage -or
                    [int]$selection.index -ne [int]$fixture.expected_index) {
                    Add-Failure "Valid Cheat Blackjack fixture '$($fixture.expected_stage)' selected the wrong public transition."
                }
            }
            catch {
                Add-Failure "Valid Cheat Blackjack fixture '$($fixture.expected_stage)' threw: $($_.Exception.Message)"
            }
        }

        $hostileBlackjackCases = [Collections.Generic.List[object]]::new()
        $fixture = New-CheatReplayBlackjackPolicyFixture -Stage open_window; $fixture.game.cheat_actions[0].id = 'blackjack_peek'
        $hostileBlackjackCases.Add([pscustomobject]@{ label = 'semantic-cheat-id-replaced-by-control-id'; fixture = $fixture })
        $fixture = New-CheatReplayBlackjackPolicyFixture -Stage open_window; $fixture.game.cheat_actions += [pscustomobject]@{ id = 'peek_hole_card'; kind = 'cheat'; label = 'Other Peek' }
        $hostileBlackjackCases.Add([pscustomobject]@{ label = 'semantic-cheat-id-duplicate'; fixture = $fixture })
        $fixture = New-CheatReplayBlackjackPolicyFixture -Stage open_window; $fixture.game.peek_available = 'true'
        $hostileBlackjackCases.Add([pscustomobject]@{ label = 'peek-available-non-boolean'; fixture = $fixture })
        $fixture = New-CheatReplayBlackjackPolicyFixture -Stage open_window; $fixture.game.can_deal = $true
        $hostileBlackjackCases.Add([pscustomobject]@{ label = 'peek-and-deal-both-available'; fixture = $fixture })
        $fixture = New-CheatReplayBlackjackPolicyFixture -Stage wait_for_deal; $fixture.game.peek_window_open = $true
        $hostileBlackjackCases.Add([pscustomobject]@{ label = 'window-without-active-peek'; fixture = $fixture })
        $fixture = New-CheatReplayBlackjackPolicyFixture -Stage open_window; $fixture.surface_actions = @($fixture.surface_actions | Where-Object { $_.action -cne 'blackjack_distraction' })
        $hostileBlackjackCases.Add([pscustomobject]@{ label = 'distraction-missing'; fixture = $fixture })
        $fixture = New-CheatReplayBlackjackPolicyFixture -Stage open_window; $fixture.surface_actions[0].enabled = $false
        $hostileBlackjackCases.Add([pscustomobject]@{ label = 'distraction-disabled'; fixture = $fixture })
        $fixture = New-CheatReplayBlackjackPolicyFixture -Stage open_window; $fixture.surface_actions[0].index = 0
        $hostileBlackjackCases.Add([pscustomobject]@{ label = 'distraction-index-duplicate'; fixture = $fixture })
        $fixture = New-CheatReplayBlackjackPolicyFixture -Stage peek; $fixture.surface_actions = @($fixture.surface_actions | Where-Object { $_.action -cne 'blackjack_peek' })
        $hostileBlackjackCases.Add([pscustomobject]@{ label = 'peek-control-missing'; fixture = $fixture })
        $fixture = New-CheatReplayBlackjackPolicyFixture -Stage peek; $fixture.surface_actions += [pscustomobject]@{ action = 'blackjack_peek'; index = 0; enabled = $true }
        $hostileBlackjackCases.Add([pscustomobject]@{ label = 'peek-control-duplicate'; fixture = $fixture })
        $fixture = New-CheatReplayBlackjackPolicyFixture -Stage peek; $fixture.surface_actions[2].index = 1
        $hostileBlackjackCases.Add([pscustomobject]@{ label = 'peek-control-wrong-index'; fixture = $fixture })

        $cheatBlackjackHostileFixtures = $hostileBlackjackCases.Count
        foreach ($case in $hostileBlackjackCases) {
            $threw = $false
            try {
                $null = Select-CheatReplayBlackjackCheatAction -Game $case.fixture.game -SurfaceActions @($case.fixture.surface_actions)
            }
            catch { $threw = $true }
            if (-not $threw) {
                Add-Failure "Hostile Cheat Blackjack fixture '$($case.label)' did not fail closed."
            }
        }
    }
    else {
        Add-Failure 'Replay policy helper did not export Select-CheatReplayBlackjackCheatAction.'
    }

    $bossCalloutPolicyCommand = Get-Command 'Select-CheatReplayBossCalloutAction' -ErrorAction SilentlyContinue
    if ($null -ne $bossCalloutPolicyCommand) {
        $validBossCases = @(
            New-CheatReplayBossCalloutPolicyFixture -Stage defer_until_dealt
            New-CheatReplayBossCalloutPolicyFixture -Stage call_stack
            New-CheatReplayBossCalloutPolicyFixture -Stage call_swap
            New-CheatReplayBossCalloutPolicyFixture -Stage none
        )
        $validBossCases[0].surface_actions = @()
        $validBossCases[3].surface_actions = @()
        $cheatBossCalloutValidFixtures = $validBossCases.Count
        foreach ($fixture in $validBossCases) {
            try {
                $selection = Select-CheatReplayBossCalloutAction -Game $fixture.game -SurfaceActions @($fixture.surface_actions)
                if ([string]$selection.stage -cne [string]$fixture.expected_stage -or
                    [int]$selection.index -ne [int]$fixture.expected_index) {
                    Add-Failure "Valid Cheat boss-callout fixture '$($fixture.expected_stage)' selected the wrong public transition."
                }
            }
            catch {
                Add-Failure "Valid Cheat boss-callout fixture '$($fixture.expected_stage)' threw: $($_.Exception.Message)"
            }
        }

        $hostileBossCases = [Collections.Generic.List[object]]::new()
        $fixture = New-CheatReplayBossCalloutPolicyFixture; $fixture.game.boss_duel_active = $false
        $hostileBossCases.Add([pscustomobject]@{ label = 'duel-inactive'; fixture = $fixture })
        $fixture = New-CheatReplayBossCalloutPolicyFixture; $fixture.game.boss_duel_active = 'true'
        $hostileBossCases.Add([pscustomobject]@{ label = 'duel-active-non-boolean'; fixture = $fixture })
        $fixture = New-CheatReplayBossCalloutPolicyFixture; $fixture.game.boss_tell = 'Rourke blinks.'
        $hostileBossCases.Add([pscustomobject]@{ label = 'tell-unrecognized'; fixture = $fixture })
        $fixture = New-CheatReplayBossCalloutPolicyFixture; $fixture.game.boss_callouts = @($fixture.game.boss_callouts[0])
        $hostileBossCases.Add([pscustomobject]@{ label = 'callout-missing'; fixture = $fixture })
        $fixture = New-CheatReplayBossCalloutPolicyFixture; $fixture.game.boss_callouts[1].id = 'stacked_shoe'
        $hostileBossCases.Add([pscustomobject]@{ label = 'callout-id-duplicate'; fixture = $fixture })
        $fixture = New-CheatReplayBossCalloutPolicyFixture; $fixture.game.boss_callouts[1].label = 'Stack the swap'
        $hostileBossCases.Add([pscustomobject]@{ label = 'tell-label-ambiguous'; fixture = $fixture })
        $fixture = New-CheatReplayBossCalloutPolicyFixture -Stage defer_until_dealt; $fixture.game.can_deal = 1
        $hostileBossCases.Add([pscustomobject]@{ label = 'can-deal-non-boolean'; fixture = $fixture })
        $fixture = New-CheatReplayBossCalloutPolicyFixture; $fixture.surface_actions = @($fixture.surface_actions | Where-Object { [int]$_.index -ne 0 })
        $hostileBossCases.Add([pscustomobject]@{ label = 'matching-surface-row-missing'; fixture = $fixture })
        $fixture = New-CheatReplayBossCalloutPolicyFixture; $fixture.surface_actions[0].enabled = $false
        $hostileBossCases.Add([pscustomobject]@{ label = 'matching-surface-row-disabled'; fixture = $fixture })
        $fixture = New-CheatReplayBossCalloutPolicyFixture; $fixture.surface_actions[0].index = '0'
        $hostileBossCases.Add([pscustomobject]@{ label = 'matching-surface-index-non-integral'; fixture = $fixture })
        $fixture = New-CheatReplayBossCalloutPolicyFixture; $fixture.game.PSObject.Properties.Remove('boss_callout_used')
        $hostileBossCases.Add([pscustomobject]@{ label = 'callout-used-witness-missing'; fixture = $fixture })

        $cheatBossCalloutHostileFixtures = $hostileBossCases.Count
        foreach ($case in $hostileBossCases) {
            $threw = $false
            try {
                $null = Select-CheatReplayBossCalloutAction -Game $case.fixture.game -SurfaceActions @($case.fixture.surface_actions)
            }
            catch { $threw = $true }
            if (-not $threw) {
                Add-Failure "Hostile Cheat boss-callout fixture '$($case.label)' did not fail closed."
            }
        }
    }
    else {
        Add-Failure 'Replay policy helper did not export Select-CheatReplayBossCalloutAction.'
    }

    $walkPolicyCommand = Get-Command 'Select-CheatReplayShowdownWalkChoice' -ErrorAction SilentlyContinue
    if ($null -ne $walkPolicyCommand) {
        $validWalkCases = @(
            (New-CheatReplayShowdownWalkPolicyFixture),
            (New-CheatReplayShowdownWalkPolicyFixture -ChoiceIds @('keep_everything', 'trash_item__instant_coffee') -ExpectedChoice 'keep_everything'),
            (New-CheatReplayShowdownWalkPolicyFixture -ChoiceIds @('keep_everything', 'trash_item__marked_cards') -ExpectedChoice 'trash_item__marked_cards'),
            (New-CheatReplayShowdownWalkPolicyFixture -ChoiceIds @('keep_everything', 'trash_item__xray_glasses', 'hand_to_crew__xray_glasses') -ExpectedChoice 'hand_to_crew__xray_glasses')
        )
        $cheatShowdownWalkValidFixtures = $validWalkCases.Count
        foreach ($fixture in $validWalkCases) {
            try {
                $choice = Select-CheatReplayShowdownWalkChoice -EventPopup $fixture.popup
                if ($choice -isnot [string] -or [string]$choice -cne [string]$fixture.expected_choice) {
                    Add-Failure "Valid Cheat showdown-walk fixture expected '$($fixture.expected_choice)' but selected '$choice'."
                }
            }
            catch {
                Add-Failure "Valid Cheat showdown-walk fixture '$($fixture.expected_choice)' threw: $($_.Exception.Message)"
            }
        }

        $hostileWalkCases = [Collections.Generic.List[object]]::new()
        $fixture = New-CheatReplayShowdownWalkPolicyFixture; $fixture.popup.visible = $false
        $hostileWalkCases.Add([pscustomobject]@{ label = 'popup-hidden'; fixture = $fixture })
        $fixture = New-CheatReplayShowdownWalkPolicyFixture; $fixture.popup.visible = 'true'
        $hostileWalkCases.Add([pscustomobject]@{ label = 'popup-visible-non-boolean'; fixture = $fixture })
        $fixture = New-CheatReplayShowdownWalkPolicyFixture; $fixture.popup.render_valid = $false
        $hostileWalkCases.Add([pscustomobject]@{ label = 'popup-clipped'; fixture = $fixture })
        $fixture = New-CheatReplayShowdownWalkPolicyFixture; $fixture.popup.event_id = 'The_House_Calls'
        $hostileWalkCases.Add([pscustomobject]@{ label = 'event-id-case'; fixture = $fixture })
        $fixture = New-CheatReplayShowdownWalkPolicyFixture; $fixture.popup.choices = @()
        $hostileWalkCases.Add([pscustomobject]@{ label = 'choice-count-mismatch'; fixture = $fixture })
        $fixture = New-CheatReplayShowdownWalkPolicyFixture -ChoiceIds @('keep_everything', 'guess');
        $hostileWalkCases.Add([pscustomobject]@{ label = 'unsupported-choice'; fixture = $fixture })
        $fixture = New-CheatReplayShowdownWalkPolicyFixture -ChoiceIds @('keep_everything', 'keep_everything');
        $hostileWalkCases.Add([pscustomobject]@{ label = 'choice-id-duplicate'; fixture = $fixture })
        $fixture = New-CheatReplayShowdownWalkPolicyFixture; $fixture.popup.choices[0].enabled = $false
        $hostileWalkCases.Add([pscustomobject]@{ label = 'choice-disabled'; fixture = $fixture })
        $fixture = New-CheatReplayShowdownWalkPolicyFixture -ChoiceIds @('keep_everything', 'trash_item__marked_cards', 'trash_item__xray_glasses')
        $hostileWalkCases.Add([pscustomobject]@{ label = 'multiple-classified-items'; fixture = $fixture })
        $fixture = New-CheatReplayShowdownWalkPolicyFixture -ChoiceIds @('trash_item__marked_cards')
        $hostileWalkCases.Add([pscustomobject]@{ label = 'keep-control-missing'; fixture = $fixture })
        $fixture = New-CheatReplayShowdownWalkPolicyFixture; $fixture.popup.choices[0] = [pscustomobject]@{ Id = 'keep_everything'; label = 'Keep Everything'; text = 'Keep it.'; enabled = $true }
        $hostileWalkCases.Add([pscustomobject]@{ label = 'choice-property-case'; fixture = $fixture })
        $fixture = New-CheatReplayShowdownWalkPolicyFixture -ChoiceIds @()
        $hostileWalkCases.Add([pscustomobject]@{ label = 'choice-list-empty'; fixture = $fixture })

        $cheatShowdownWalkHostileFixtures = $hostileWalkCases.Count
        foreach ($case in $hostileWalkCases) {
            $threw = $false
            try { $null = Select-CheatReplayShowdownWalkChoice -EventPopup $case.fixture.popup }
            catch { $threw = $true }
            if (-not $threw) {
                Add-Failure "Hostile Cheat showdown-walk fixture '$($case.label)' did not fail closed."
            }
        }
    }
    else {
        Add-Failure 'Replay policy helper did not export Select-CheatReplayShowdownWalkChoice.'
    }

    $cheatDuelContinuationValidFixtures = 1
    if (-not (Test-CheatReplayDuelContinuationOrder -Source $runner)) {
        Add-Failure 'Enter-BlackjackTable no longer preserves a restored Blackjack duel surface before Grand-room navigation.'
    }
    $hostileDuelContinuationSources = @(
@'
function Enter-BlackjackTable {
    Enter-GrandRoom -Room main
    if ([string](Get-Value $script:LastObservation @('screen', 'screen') '') -ceq 'GAME' -and [string](Get-Value $script:LastObservation @('game', 'game_id') '') -ceq 'blackjack') { return }
}
'@,
@'
function Enter-BlackjackTable {
    if ([string](Get-Value $script:LastObservation @('screen', 'screen') '') -ceq 'GAME' -and [string](Get-Value $script:LastObservation @('game', 'game_id') '') -ceq 'blackjack') { Write-Output 'seen' }
    Enter-GrandRoom -Room main
}
'@
    )
    $cheatDuelContinuationHostileFixtures = $hostileDuelContinuationSources.Count
    foreach ($source in $hostileDuelContinuationSources) {
        if (Test-CheatReplayDuelContinuationOrder -Source $source) {
            Add-Failure 'Hostile Cheat duel-continuation ordering fixture did not fail closed.'
        }
    }

    if ($null -ne (Get-Command 'Select-GrandFareMachineJamChoice' -ErrorAction SilentlyContinue)) {
        $validMachineJamFixtures = @(
            [pscustomobject]@{ label = 'exact-rendered-copy'; fixture = (New-MachineJamPolicyFixture) },
            [pscustomobject]@{ label = 'hidden-private-sentinels-are-inert'; fixture = (New-MachineJamPolicyFixture -WithHiddenSentinels) }
        )
        $machineJamValidFixtures = $validMachineJamFixtures.Count
        foreach ($case in $validMachineJamFixtures) {
            try {
                $actual = Select-GrandFareMachineJamChoice -EventPopup $case.fixture.event_popup -Talk $case.fixture.talk
                if ($actual -isnot [string] -or [string]$actual -cne 'wait') {
                    Add-Failure "Valid machine_jam fixture '$($case.label)' did not choose the exact visible de-escalation response."
                }
            }
            catch {
                Add-Failure "Valid machine_jam fixture '$($case.label)' threw: $($_.Exception.Message)"
            }
        }

        $hostileMachineJamFixtures = [Collections.Generic.List[object]]::new()
        $fixture = New-MachineJamPolicyFixture; $fixture.event_popup.visible = $false
        $hostileMachineJamFixtures.Add([pscustomobject]@{ label = 'popup-hidden'; fixture = $fixture })
        $fixture = New-MachineJamPolicyFixture; $fixture.event_popup.visible = 'true'
        $hostileMachineJamFixtures.Add([pscustomobject]@{ label = 'popup-visible-non-boolean'; fixture = $fixture })
        $fixture = New-MachineJamPolicyFixture; $fixture.event_popup.render_valid = $false
        $hostileMachineJamFixtures.Add([pscustomobject]@{ label = 'popup-clipped'; fixture = $fixture })
        $fixture = New-MachineJamPolicyFixture; $fixture.event_popup.render_valid = 1
        $hostileMachineJamFixtures.Add([pscustomobject]@{ label = 'popup-render-witness-non-boolean'; fixture = $fixture })
        $fixture = New-MachineJamPolicyFixture; $fixture.event_popup.event_id = 'Machine_Jam'
        $hostileMachineJamFixtures.Add([pscustomobject]@{ label = 'event-id-case'; fixture = $fixture })
        $fixture = New-MachineJamPolicyFixture; $fixture.event_popup.event_id = 'unlisted_event'
        $hostileMachineJamFixtures.Add([pscustomobject]@{ label = 'wrong-event-id'; fixture = $fixture })
        $fixture = New-MachineJamPolicyFixture; $fixture.event_popup.title = 'Machine jam'
        $hostileMachineJamFixtures.Add([pscustomobject]@{ label = 'title-copy'; fixture = $fixture })
        $fixture = New-MachineJamPolicyFixture; $fixture.event_popup.summary = 'The machine stops.'
        $hostileMachineJamFixtures.Add([pscustomobject]@{ label = 'summary-copy'; fixture = $fixture })
        $fixture = New-MachineJamPolicyFixture; $fixture.event_popup.choice_ids = @('push', 'wait')
        $hostileMachineJamFixtures.Add([pscustomobject]@{ label = 'choice-order'; fixture = $fixture })
        $fixture = New-MachineJamPolicyFixture; $fixture.event_popup.choice_ids = @('WAIT', 'push')
        $hostileMachineJamFixtures.Add([pscustomobject]@{ label = 'choice-id-case'; fixture = $fixture })
        $fixture = New-MachineJamPolicyFixture; $fixture.event_popup.choice_ids = @('wait')
        $hostileMachineJamFixtures.Add([pscustomobject]@{ label = 'choice-id-missing'; fixture = $fixture })
        $fixture = New-MachineJamPolicyFixture; $fixture.event_popup.choice_ids = @('wait', 'push', 'guess')
        $hostileMachineJamFixtures.Add([pscustomobject]@{ label = 'choice-id-extra'; fixture = $fixture })
        $fixture = New-MachineJamPolicyFixture; $fixture.event_popup.choices = @($fixture.event_popup.choices[0], $fixture.event_popup.choices[0])
        $hostileMachineJamFixtures.Add([pscustomobject]@{ label = 'choice-duplicate'; fixture = $fixture })
        $fixture = New-MachineJamPolicyFixture; $fixture.event_popup.choices[0].enabled = $false
        $hostileMachineJamFixtures.Add([pscustomobject]@{ label = 'choice-disabled'; fixture = $fixture })
        $fixture = New-MachineJamPolicyFixture; $fixture.event_popup.choices[0].enabled = 'true'
        $hostileMachineJamFixtures.Add([pscustomobject]@{ label = 'choice-enabled-non-boolean'; fixture = $fixture })
        $fixture = New-MachineJamPolicyFixture; $fixture.event_popup.choices[0].label = 'wait it out'
        $hostileMachineJamFixtures.Add([pscustomobject]@{ label = 'choice-label-case'; fixture = $fixture })
        $fixture = New-MachineJamPolicyFixture; $fixture.event_popup.choices[1].text = 'The room turns.'
        $hostileMachineJamFixtures.Add([pscustomobject]@{ label = 'choice-copy'; fixture = $fixture })
        $fixture = New-MachineJamPolicyFixture; $fixture.talk.visible = $true
        $hostileMachineJamFixtures.Add([pscustomobject]@{ label = 'talk-visible'; fixture = $fixture })
        $fixture = New-MachineJamPolicyFixture; $fixture.talk.visible = 0
        $hostileMachineJamFixtures.Add([pscustomobject]@{ label = 'talk-visible-non-boolean'; fixture = $fixture })
        $fixture = New-MachineJamPolicyFixture; $fixture.talk = [pscustomobject]@{ Visible = $false }
        $hostileMachineJamFixtures.Add([pscustomobject]@{ label = 'property-name-case'; fixture = $fixture })

        $machineJamHostileFixtures = $hostileMachineJamFixtures.Count
        foreach ($case in $hostileMachineJamFixtures) {
            $threw = $false
            try {
                $null = Select-GrandFareMachineJamChoice -EventPopup $case.fixture.event_popup -Talk $case.fixture.talk
            }
            catch {
                $threw = $true
            }
            if (-not $threw) {
                Add-Failure "Hostile machine_jam fixture '$($case.label)' did not fail closed."
            }
        }
    }
    else {
        Add-Failure 'Replay policy helper did not export Select-GrandFareMachineJamChoice.'
    }

    function Invoke-FundingPolicyFixture {
        param(
            [Parameter(Mandatory = $true)]$Fixture,
            [ValidateSet('selection', 'action', 'preflight', 'talk', 'confirmation', 'result')]
            [string]$Through = 'result'
        )

        $selection = Select-GrandFareFundingObject -CanvasObjects @($Fixture.canvas_objects) -WorldNodeId ([string]$Fixture.world_node_id) -AcceptedOfferKeys @($Fixture.accepted_offer_keys) -AcceptedLenderIds @($Fixture.accepted_lender_ids)
        if ($Fixture.PSObject.Properties['expected_semantic_id'] -and
            [string]$selection.semantic_id -cne [string]$Fixture.expected_semantic_id) {
            throw "Funding selection did not use the deterministic expected semantic id."
        }
        if ($Through -ceq 'selection') { return $selection }

        $actionSelection = Select-GrandFareFundingObjectAction -Selection $selection -RoomActions @($Fixture.room_actions)
        if ($Through -ceq 'action') { return $actionSelection }

        $preflightAccepted = @($Fixture.accepted_lender_ids)
        if ($Fixture.PSObject.Properties['preflight_accepted_lender_ids']) {
            $preflightAccepted = @($Fixture.preflight_accepted_lender_ids)
        }
        $preflight = Test-GrandFareFundingPreflight -Selection $actionSelection -DebtIndicator $Fixture.before_debt_indicator -AcceptedLenderIds $preflightAccepted
        if ($preflight -isnot [bool] -or -not [bool]$preflight) {
            throw 'Funding preflight refused the fixture.'
        }
        if ($Through -ceq 'preflight') { return $actionSelection }

        $offer = Select-GrandFareFundingTalkOffer -Selection $actionSelection -Talk $Fixture.talk -TalkChoices @($Fixture.talk_choices)
        if ($Through -ceq 'talk') { return $offer }

        $null = Assert-GrandFareFundingConfirmation -Offer $offer -Talk $Fixture.confirmation_talk -TalkChoices @($Fixture.confirmation_choices)
        if ($Through -ceq 'confirmation') { return $offer }

        $null = Assert-GrandFareFundingResult -Offer $offer -BeforeBankroll ([int]$Fixture.before_bankroll) -BeforeDebtIndicator $Fixture.before_debt_indicator -AfterObservation $Fixture.after_observation
        return $offer
    }

    $fundingCommandNames = @(
        'Select-GrandFareFundingObject',
        'Select-GrandFareFundingObjectAction',
        'Get-GrandFarePublicDebtCount',
        'Test-GrandFareFundingPreflight',
        'Select-GrandFareFundingTalkOffer',
        'Assert-GrandFareFundingConfirmation',
        'Assert-GrandFareFundingResult'
    )
    $fundingCommands = @($fundingCommandNames | Where-Object {
        $null -ne (Get-Command $_ -ErrorAction SilentlyContinue)
    })
    if ($fundingCommands.Count -ceq $fundingCommandNames.Count) {
        $validFundingFixtures = [Collections.Generic.List[object]]::new()
        $validFundingFixtures.Add([pscustomobject]@{ label = 'crew-debt-free'; fixture = (New-GrandFareFundingPolicyFixture -Kind crew) })
        $validFundingFixtures.Add([pscustomobject]@{ label = 'family-adds-second-visible-debt'; fixture = (New-GrandFareFundingPolicyFixture -Kind family) })

        $fixture = New-GrandFareFundingPolicyFixture -Kind crew
        $fixture.canvas_objects += [pscustomobject]@{ semantic_id = 'lender:aaa_disabled'; label = 'Disabled Lender'; object_type = 'lender'; enabled = $false; rendered = $true }
        $validFundingFixtures.Add([pscustomobject]@{ label = 'disabled-other-lender-is-skipped'; fixture = $fixture })

        $fixture = New-GrandFareFundingPolicyFixture -Kind crew
        $fixture.canvas_objects += [pscustomobject]@{ semantic_id = 'lender:aaa_accepted'; label = 'Accepted Lender'; object_type = 'lender'; enabled = $true; rendered = $true }
        $fixture.accepted_lender_ids = @('aaa_accepted')
        $validFundingFixtures.Add([pscustomobject]@{ label = 'accepted-other-lender-is-skipped'; fixture = $fixture })

        $fixture = New-GrandFareFundingPolicyFixture -Kind crew
        $fixture.canvas_objects += [pscustomobject]@{ semantic_id = 'lender:zeta'; label = 'Zeta'; object_type = 'lender'; enabled = $true; rendered = $true }
        $validFundingFixtures.Add([pscustomobject]@{ label = 'multiple-enabled-lenders-use-ordinal-id'; fixture = $fixture })

        $fixture = New-GrandFareFundingPolicyFixture -Kind street
        $fixture.canvas_objects += [pscustomobject]@{ semantic_id = 'lender:the_crew'; label = 'The Crew'; object_type = 'character'; enabled = $true; rendered = $true }
        $validFundingFixtures.Add([pscustomobject]@{ label = 'back-alley-production-pair-selects-street-lender'; fixture = $fixture })

        $fixture = New-GrandFareFundingPolicyFixture -Kind motel_friend
        $fixture.canvas_objects += [pscustomobject]@{ semantic_id = 'lender:brother_in_law'; label = 'Your Brother-in-Law'; object_type = 'character'; enabled = $false; rendered = $true }
        $validFundingFixtures.Add([pscustomobject]@{ label = 'motel-disabled-brother-selects-motel-friend'; fixture = $fixture })

        $fixture = New-GrandFareFundingPolicyFixture -Kind family
        $fixture.canvas_objects += [pscustomobject]@{ semantic_id = 'lender:motel_friend'; label = 'Motel Friend'; object_type = 'character'; enabled = $true; rendered = $true }
        $validFundingFixtures.Add([pscustomobject]@{ label = 'motel-enabled-brother-wins-ordinal-selection'; fixture = $fixture })

        $grandFareFundingValidFixtures = $validFundingFixtures.Count
        foreach ($case in $validFundingFixtures) {
            try {
                $offer = Invoke-FundingPolicyFixture -Fixture $case.fixture -Through result
                if ([int]$offer.principal -cne [int]$case.fixture.expected_principal -or
                    [string]$offer.debt_kind -cne [string]$case.fixture.expected_debt_kind) {
                    Add-Failure "Valid Grand-fare funding fixture '$($case.label)' returned the wrong disclosed terms."
                }
            }
            catch {
                Add-Failure "Valid Grand-fare funding fixture '$($case.label)' threw: $($_.Exception.Message)"
            }
        }

        $fundingHostileCases = [Collections.Generic.List[object]]::new()

        $fixture = New-GrandFareFundingPolicyFixture; $fixture.canvas_objects[0].PSObject.Properties.Remove('rendered')
        $fundingHostileCases.Add([pscustomobject]@{ label = 'object-rendered-missing'; stage = 'selection'; fixture = $fixture })
        $fixture = New-GrandFareFundingPolicyFixture; $fixture.canvas_objects[0].rendered = $false
        $fundingHostileCases.Add([pscustomobject]@{ label = 'object-clipped'; stage = 'selection'; fixture = $fixture })
        $fixture = New-GrandFareFundingPolicyFixture; $fixture.canvas_objects[0].rendered = 1
        $fundingHostileCases.Add([pscustomobject]@{ label = 'object-rendered-non-boolean'; stage = 'selection'; fixture = $fixture })
        $fixture = New-GrandFareFundingPolicyFixture; $fixture.canvas_objects[0].enabled = $false
        $fundingHostileCases.Add([pscustomobject]@{ label = 'object-disabled'; stage = 'selection'; fixture = $fixture })
        $fixture = New-GrandFareFundingPolicyFixture; $fixture.canvas_objects[0].enabled = 'true'
        $fundingHostileCases.Add([pscustomobject]@{ label = 'object-enabled-non-boolean'; stage = 'selection'; fixture = $fixture })
        $fixture = New-GrandFareFundingPolicyFixture; $fixture.canvas_objects = @()
        $fundingHostileCases.Add([pscustomobject]@{ label = 'object-hidden'; stage = 'selection'; fixture = $fixture })
        $fixture = New-GrandFareFundingPolicyFixture; $fixture.canvas_objects += $fixture.canvas_objects[0]
        $fundingHostileCases.Add([pscustomobject]@{ label = 'duplicate-semantic-id'; stage = 'selection'; fixture = $fixture })
        $fixture = New-GrandFareFundingPolicyFixture; $fixture.world_node_id = 'Kitty_Cat_Lounge'
        $fundingHostileCases.Add([pscustomobject]@{ label = 'world-node-case'; stage = 'selection'; fixture = $fixture })
        $fixture = New-GrandFareFundingPolicyFixture; $fixture.canvas_objects[0].semantic_id = 'LENDER:the_crew'
        $fundingHostileCases.Add([pscustomobject]@{ label = 'lender-prefix-case'; stage = 'selection'; fixture = $fixture })
        $fixture = New-GrandFareFundingPolicyFixture; $fixture.canvas_objects[0].semantic_id = 'lender:The_Crew'
        $fundingHostileCases.Add([pscustomobject]@{ label = 'lender-suffix-case'; stage = 'selection'; fixture = $fixture })
        $fixture = New-GrandFareFundingPolicyFixture; $fixture.canvas_objects[0].object_type = 'Character'
        $fundingHostileCases.Add([pscustomobject]@{ label = 'object-type-case'; stage = 'selection'; fixture = $fixture })
        $fixture = New-GrandFareFundingPolicyFixture
        $fixture.canvas_objects = @([pscustomobject]@{ semantic_id = 'lender:the_crew'; Label = 'The Crew'; object_type = 'character'; enabled = $true; rendered = $true })
        $fundingHostileCases.Add([pscustomobject]@{ label = 'object-property-case'; stage = 'selection'; fixture = $fixture })
        $fixture = New-GrandFareFundingPolicyFixture; $fixture.accepted_offer_keys = @('kitty_cat_lounge|lender:the_crew')
        $fundingHostileCases.Add([pscustomobject]@{ label = 'accepted-offer-key'; stage = 'selection'; fixture = $fixture })
        $fixture = New-GrandFareFundingPolicyFixture; $fixture.accepted_lender_ids = @('the_crew')
        $fundingHostileCases.Add([pscustomobject]@{ label = 'accepted-lender-id'; stage = 'selection'; fixture = $fixture })

        $fixture = New-GrandFareFundingPolicyFixture; $fixture.room_actions += $fixture.room_actions[0]
        $fundingHostileCases.Add([pscustomobject]@{ label = 'action-duplicate'; stage = 'action'; fixture = $fixture })
        $fixture = New-GrandFareFundingPolicyFixture; $fixture.room_actions[0].enabled = $false
        $fundingHostileCases.Add([pscustomobject]@{ label = 'action-disabled'; stage = 'action'; fixture = $fixture })
        $fixture = New-GrandFareFundingPolicyFixture; $fixture.room_actions[0].enabled = 'true'
        $fundingHostileCases.Add([pscustomobject]@{ label = 'action-enabled-non-boolean'; stage = 'action'; fixture = $fixture })
        $fixture = New-GrandFareFundingPolicyFixture; $fixture.room_actions[0].label = 'use'
        $fundingHostileCases.Add([pscustomobject]@{ label = 'action-label-case'; stage = 'action'; fixture = $fixture })
        $fixture = New-GrandFareFundingPolicyFixture; $fixture.room_actions[0].index = 1
        $fundingHostileCases.Add([pscustomobject]@{ label = 'action-index'; stage = 'action'; fixture = $fixture })
        $fixture = New-GrandFareFundingPolicyFixture; $fixture.room_actions[0].id = 'use_lender_hook'
        $fundingHostileCases.Add([pscustomobject]@{ label = 'action-fabricated-id'; stage = 'action'; fixture = $fixture })
        $fixture = New-GrandFareFundingPolicyFixture
        $fixture.room_actions = @([pscustomobject]@{ id = ''; action = ''; action_id = ''; Emit_Object_Id = ''; label = 'Use'; enabled = $true; index = 0 })
        $fundingHostileCases.Add([pscustomobject]@{ label = 'action-property-case'; stage = 'action'; fixture = $fixture })

        $fixture = New-GrandFareFundingPolicyFixture
        $fixture.before_debt_indicator = [pscustomobject]@{ rendered = $true; present = $true; tooltip = 'Existing lender balance 10' }
        $fundingHostileCases.Add([pscustomobject]@{ label = 'crew-with-existing-debt'; stage = 'preflight'; fixture = $fixture })
        $fixture = New-GrandFareFundingPolicyFixture
        $fixture | Add-Member -NotePropertyName preflight_accepted_lender_ids -NotePropertyValue @('the_crew')
        $fundingHostileCases.Add([pscustomobject]@{ label = 'preflight-repeat-lender'; stage = 'preflight'; fixture = $fixture })
        foreach ($tooltipCase in @(
            [pscustomobject]@{ label = 'debt-count-case'; text = '2 Active debts' },
            [pscustomobject]@{ label = 'debt-count-leading-zero'; text = '01 active debts' },
            [pscustomobject]@{ label = 'debt-count-impossible-one'; text = '1 active debts' }
        )) {
            $fixture = New-GrandFareFundingPolicyFixture
            $fixture.before_debt_indicator = [pscustomobject]@{ rendered = $true; present = $true; tooltip = $tooltipCase.text }
            $fundingHostileCases.Add([pscustomobject]@{ label = $tooltipCase.label; stage = 'preflight'; fixture = $fixture })
        }
        $fixture = New-GrandFareFundingPolicyFixture; $fixture.before_debt_indicator.rendered = $false
        $fundingHostileCases.Add([pscustomobject]@{ label = 'debt-render-witness-false'; stage = 'preflight'; fixture = $fixture })
        $fixture = New-GrandFareFundingPolicyFixture; $fixture.before_debt_indicator.present = 'false'
        $fundingHostileCases.Add([pscustomobject]@{ label = 'debt-present-non-boolean'; stage = 'preflight'; fixture = $fixture })
        $fixture = New-GrandFareFundingPolicyFixture; $fixture.before_debt_indicator | Add-Member -NotePropertyName tooltip -NotePropertyValue 'stale'
        $fundingHostileCases.Add([pscustomobject]@{ label = 'absent-debt-with-tooltip'; stage = 'preflight'; fixture = $fixture })

        $fixture = New-GrandFareFundingPolicyFixture; $fixture.talk.visible = $false
        $fundingHostileCases.Add([pscustomobject]@{ label = 'talk-hidden'; stage = 'talk'; fixture = $fixture })
        $fixture = New-GrandFareFundingPolicyFixture; $fixture.talk.visible = 'true'
        $fundingHostileCases.Add([pscustomobject]@{ label = 'talk-visible-non-boolean'; stage = 'talk'; fixture = $fixture })
        $fixture = New-GrandFareFundingPolicyFixture; $fixture.talk.render_valid = $false
        $fundingHostileCases.Add([pscustomobject]@{ label = 'talk-clipped'; stage = 'talk'; fixture = $fixture })
        $fixture = New-GrandFareFundingPolicyFixture; $fixture.talk.render_valid = 1
        $fundingHostileCases.Add([pscustomobject]@{ label = 'talk-render-witness-non-boolean'; stage = 'talk'; fixture = $fixture })
        $fixture = New-GrandFareFundingPolicyFixture; $fixture.talk.expanded = $false
        $fundingHostileCases.Add([pscustomobject]@{ label = 'talk-collapsed'; stage = 'talk'; fixture = $fixture })
        $fixture = New-GrandFareFundingPolicyFixture; $fixture.talk.body_complete = $false
        $fundingHostileCases.Add([pscustomobject]@{ label = 'talk-body-incomplete'; stage = 'talk'; fixture = $fixture })
        $fixture = New-GrandFareFundingPolicyFixture; $fixture.talk.typewriter_active = $true
        $fundingHostileCases.Add([pscustomobject]@{ label = 'talk-typewriter-active'; stage = 'talk'; fixture = $fixture })
        $fixture = New-GrandFareFundingPolicyFixture; $fixture.talk.event_id = 'lender_conversation:borrow:The_Crew'
        $fundingHostileCases.Add([pscustomobject]@{ label = 'talk-event-case'; stage = 'talk'; fixture = $fixture })
        $fixture = New-GrandFareFundingPolicyFixture; $fixture.talk.summary = 'No interest. Only favors. Borrow $45. Due later.'
        $fundingHostileCases.Add([pscustomobject]@{ label = 'talk-terms-incomplete'; stage = 'talk'; fixture = $fixture })
        $fixture = New-GrandFareFundingPolicyFixture; $fixture.talk.choice_ids = @('Accept', 'decline')
        $fundingHostileCases.Add([pscustomobject]@{ label = 'talk-choice-id-case'; stage = 'talk'; fixture = $fixture })
        $fixture = New-GrandFareFundingPolicyFixture; $fixture.talk_choices += $fixture.talk_choices[0]
        $fundingHostileCases.Add([pscustomobject]@{ label = 'talk-choice-duplicate'; stage = 'talk'; fixture = $fixture })
        $fixture = New-GrandFareFundingPolicyFixture; $fixture.talk_choices[0].enabled = $false
        $fundingHostileCases.Add([pscustomobject]@{ label = 'talk-choice-disabled'; stage = 'talk'; fixture = $fixture })
        $fixture = New-GrandFareFundingPolicyFixture; $fixture.talk_choices[0].enabled = 1
        $fundingHostileCases.Add([pscustomobject]@{ label = 'talk-choice-enabled-non-boolean'; stage = 'talk'; fixture = $fixture })
        $fixture = New-GrandFareFundingPolicyFixture; $fixture.talk_choices[0].label = 'accept offer'
        $fundingHostileCases.Add([pscustomobject]@{ label = 'talk-choice-label-case'; stage = 'talk'; fixture = $fixture })

        $fixture = New-GrandFareFundingPolicyFixture; $fixture.confirmation_talk.render_valid = $false
        $fundingHostileCases.Add([pscustomobject]@{ label = 'confirmation-clipped'; stage = 'confirmation'; fixture = $fixture })
        $fixture = New-GrandFareFundingPolicyFixture; $fixture.confirmation_talk.summary += ' changed'
        $fundingHostileCases.Add([pscustomobject]@{ label = 'confirmation-summary-changed'; stage = 'confirmation'; fixture = $fixture })
        $fixture = New-GrandFareFundingPolicyFixture; $fixture.confirmation_talk.choice_ids = @('decline', 'accept')
        $fundingHostileCases.Add([pscustomobject]@{ label = 'confirmation-choice-order'; stage = 'confirmation'; fixture = $fixture })
        $fixture = New-GrandFareFundingPolicyFixture; $fixture.confirmation_choices[0].label = 'Confirm: accept offer'
        $fundingHostileCases.Add([pscustomobject]@{ label = 'confirmation-label-case'; stage = 'confirmation'; fixture = $fixture })
        $fixture = New-GrandFareFundingPolicyFixture; $fixture.confirmation_choices[0].enabled = $false
        $fundingHostileCases.Add([pscustomobject]@{ label = 'confirmation-disabled'; stage = 'confirmation'; fixture = $fixture })
        $fixture = New-GrandFareFundingPolicyFixture; $fixture.confirmation_choices[0].enabled = 'true'
        $fundingHostileCases.Add([pscustomobject]@{ label = 'confirmation-enabled-non-boolean'; stage = 'confirmation'; fixture = $fixture })

        $fixture = New-GrandFareFundingPolicyFixture; $fixture.after_observation.status_hud.bankroll_rendered = $false
        $fundingHostileCases.Add([pscustomobject]@{ label = 'result-bankroll-unrendered'; stage = 'result'; fixture = $fixture })
        $fixture = New-GrandFareFundingPolicyFixture; $fixture.after_observation.status_hud.bankroll = 107
        $fundingHostileCases.Add([pscustomobject]@{ label = 'result-bankroll-mismatch'; stage = 'result'; fixture = $fixture })
        $fixture = New-GrandFareFundingPolicyFixture; $fixture.after_observation.status_hud.debt_indicator.rendered = $false
        $fundingHostileCases.Add([pscustomobject]@{ label = 'result-debt-unrendered'; stage = 'result'; fixture = $fixture })
        $fixture = New-GrandFareFundingPolicyFixture; $fixture.after_observation.status_hud.debt_indicator = [pscustomobject]@{ rendered = $true; present = $false }
        $fundingHostileCases.Add([pscustomobject]@{ label = 'result-debt-unchanged'; stage = 'result'; fixture = $fixture })
        $fixture = New-GrandFareFundingPolicyFixture; $fixture.after_observation.status_hud.debt_indicator.tooltip = '2 active debts'
        $fundingHostileCases.Add([pscustomobject]@{ label = 'result-debt-jump'; stage = 'result'; fixture = $fixture })
        $fixture = New-GrandFareFundingPolicyFixture; $fixture.after_observation.talk.visible = $true
        $fundingHostileCases.Add([pscustomobject]@{ label = 'result-talk-visible'; stage = 'result'; fixture = $fixture })
        $fixture = New-GrandFareFundingPolicyFixture; $fixture.after_observation.feedback.visible = $false
        $fundingHostileCases.Add([pscustomobject]@{ label = 'result-feedback-hidden'; stage = 'result'; fixture = $fixture })
        $fixture = New-GrandFareFundingPolicyFixture; $fixture.after_observation.feedback.title = 'result'
        $fundingHostileCases.Add([pscustomobject]@{ label = 'result-title-case'; stage = 'result'; fixture = $fixture })
        $fixture = New-GrandFareFundingPolicyFixture; $fixture.after_observation.feedback.text = $fixture.after_observation.feedback.text.Replace('Borrow $45', 'Borrow $44')
        $fundingHostileCases.Add([pscustomobject]@{ label = 'result-terms-mismatch'; stage = 'result'; fixture = $fixture })
        $fixture = New-GrandFareFundingPolicyFixture; $fixture.after_observation.feedback.text = $fixture.after_observation.feedback.text.Replace('$+45', '$+44')
        $fundingHostileCases.Add([pscustomobject]@{ label = 'result-delta-mismatch'; stage = 'result'; fixture = $fixture })

        $grandFareFundingHostileFixtures = $fundingHostileCases.Count
        foreach ($case in $fundingHostileCases) {
            $threw = $false
            try {
                $null = Invoke-FundingPolicyFixture -Fixture $case.fixture -Through ([string]$case.stage)
            }
            catch {
                $threw = $true
            }
            if (-not $threw) {
                Add-Failure "Hostile Grand-fare funding fixture '$($case.label)' did not fail closed."
            }
        }
    }
    else {
        Add-Failure 'Replay policy helper did not export the complete Grand-fare public funding policy.'
    }

    function Invoke-CashEventPolicyFixture {
        param(
            [Parameter(Mandatory = $true)]$Fixture,
            [ValidateSet('choice', 'result')][string]$Through = 'result',
            [AllowNull()][scriptblock]$EventMutator = $null
        )

        $event = Select-GrandFareCashEventChoice -EventId ([string]$Fixture.event_id) -EventObject $Fixture.event_object -RoomActions @($Fixture.room_actions) -Talk $Fixture.talk -WorldNodeId ([string]$Fixture.world_node_id) -ResolvedEventKeys @($Fixture.resolved_event_keys)
        if ($Through -ceq 'choice') { return $event }
        if ($null -ne $EventMutator) {
            $null = & $EventMutator $event
        }
        $null = Assert-GrandFareCashEventResult -Event $event -BeforeBankroll ([int]$Fixture.before_bankroll) -BeforeHeat ([int]$Fixture.before_heat) -BeforeFeedback $Fixture.before_feedback -AfterObservation $Fixture.after_observation
        return $event
    }

    $cashEventCommands = @(
        Get-Command 'Select-GrandFareCashEventChoice' -ErrorAction SilentlyContinue
        Get-Command 'Assert-GrandFareCashEventResult' -ErrorAction SilentlyContinue
    )
    if (@($cashEventCommands | Where-Object { $null -ne $_ }).Count -ceq 2) {
        $validCashEventFixtures = @(
            [pscustomobject]@{ label = 'back-alley-public-cash'; fixture = (New-GrandFareCashEventPolicyFixture -Kind alley) },
            [pscustomobject]@{ label = 'wedding-public-cash'; fixture = (New-GrandFareCashEventPolicyFixture -Kind wedding) }
        )
        $grandFareCashEventValidFixtures = $validCashEventFixtures.Count
        foreach ($case in $validCashEventFixtures) {
            try {
                $null = Invoke-CashEventPolicyFixture -Fixture $case.fixture -Through result
            }
            catch {
                Add-Failure "Valid Grand-fare cash event '$($case.label)' threw: $($_.Exception.Message)"
            }
        }

        $cashEventHostileCases = [Collections.Generic.List[object]]::new()

        $fixture = New-GrandFareCashEventPolicyFixture; $fixture.event_id = 'rowdy_regular'
        $cashEventHostileCases.Add([pscustomobject]@{ label = 'event-unlisted'; stage = 'choice'; fixture = $fixture })
        $fixture = New-GrandFareCashEventPolicyFixture; $fixture.event_id = 'Back_Alley_Offer'
        $cashEventHostileCases.Add([pscustomobject]@{ label = 'event-id-case'; stage = 'choice'; fixture = $fixture })
        $fixture = New-GrandFareCashEventPolicyFixture; $fixture.world_node_id = 'Back_Alley'
        $cashEventHostileCases.Add([pscustomobject]@{ label = 'world-node-case'; stage = 'choice'; fixture = $fixture })
        $fixture = New-GrandFareCashEventPolicyFixture; $fixture.talk.visible = $true
        $cashEventHostileCases.Add([pscustomobject]@{ label = 'talk-visible'; stage = 'choice'; fixture = $fixture })
        $fixture = New-GrandFareCashEventPolicyFixture; $fixture.talk.visible = 0
        $cashEventHostileCases.Add([pscustomobject]@{ label = 'talk-visible-non-boolean'; stage = 'choice'; fixture = $fixture })
        $fixture = New-GrandFareCashEventPolicyFixture; $fixture.resolved_event_keys = @('back_alley|event:back_alley_offer')
        $cashEventHostileCases.Add([pscustomobject]@{ label = 'event-repeat'; stage = 'choice'; fixture = $fixture })

        $fixture = New-GrandFareCashEventPolicyFixture; $fixture.event_object.PSObject.Properties.Remove('rendered')
        $cashEventHostileCases.Add([pscustomobject]@{ label = 'object-rendered-missing'; stage = 'choice'; fixture = $fixture })
        $fixture = New-GrandFareCashEventPolicyFixture; $fixture.event_object.rendered = $false
        $cashEventHostileCases.Add([pscustomobject]@{ label = 'object-clipped'; stage = 'choice'; fixture = $fixture })
        $fixture = New-GrandFareCashEventPolicyFixture; $fixture.event_object.rendered = 1
        $cashEventHostileCases.Add([pscustomobject]@{ label = 'object-rendered-non-boolean'; stage = 'choice'; fixture = $fixture })
        $fixture = New-GrandFareCashEventPolicyFixture; $fixture.event_object.semantic_id = 'event:Back_Alley_Offer'
        $cashEventHostileCases.Add([pscustomobject]@{ label = 'object-semantic-id-case'; stage = 'choice'; fixture = $fixture })
        $fixture = New-GrandFareCashEventPolicyFixture; $fixture.event_object.label = 'Back alley offer'
        $cashEventHostileCases.Add([pscustomobject]@{ label = 'object-label-case'; stage = 'choice'; fixture = $fixture })
        $fixture = New-GrandFareCashEventPolicyFixture; $fixture.event_object.object_type = 'Event'
        $cashEventHostileCases.Add([pscustomobject]@{ label = 'object-type-case'; stage = 'choice'; fixture = $fixture })
        $fixture = New-GrandFareCashEventPolicyFixture; $fixture.event_object.enabled = $false
        $cashEventHostileCases.Add([pscustomobject]@{ label = 'object-disabled'; stage = 'choice'; fixture = $fixture })
        $fixture = New-GrandFareCashEventPolicyFixture; $fixture.event_object.enabled = 'true'
        $cashEventHostileCases.Add([pscustomobject]@{ label = 'object-enabled-non-boolean'; stage = 'choice'; fixture = $fixture })
        $fixture = New-GrandFareCashEventPolicyFixture
        $fixture.event_object = [pscustomobject]@{ semantic_id = 'event:back_alley_offer'; label = 'Back Alley Offer'; Object_Type = 'event'; enabled = $true; rendered = $true }
        $cashEventHostileCases.Add([pscustomobject]@{ label = 'object-property-case'; stage = 'choice'; fixture = $fixture })

        $fixture = New-GrandFareCashEventPolicyFixture; $fixture.room_actions += $fixture.room_actions[0]
        $cashEventHostileCases.Add([pscustomobject]@{ label = 'action-duplicate'; stage = 'choice'; fixture = $fixture })
        $fixture = New-GrandFareCashEventPolicyFixture; $fixture.room_actions[0].enabled = $false
        $cashEventHostileCases.Add([pscustomobject]@{ label = 'action-disabled'; stage = 'choice'; fixture = $fixture })
        $fixture = New-GrandFareCashEventPolicyFixture; $fixture.room_actions[0].enabled = 'true'
        $cashEventHostileCases.Add([pscustomobject]@{ label = 'action-enabled-non-boolean'; stage = 'choice'; fixture = $fixture })
        $fixture = New-GrandFareCashEventPolicyFixture; $fixture.room_actions[0].label = 'Take The Cash'
        $cashEventHostileCases.Add([pscustomobject]@{ label = 'action-label-case'; stage = 'choice'; fixture = $fixture })
        $fixture = New-GrandFareCashEventPolicyFixture; $fixture.room_actions[0].emit_object_id = 'event_response:back_alley_offer:TAKE_CASH'
        $cashEventHostileCases.Add([pscustomobject]@{ label = 'action-id-case'; stage = 'choice'; fixture = $fixture })
        $fixture = New-GrandFareCashEventPolicyFixture; $fixture.room_actions[0].emit_object_id = 'event_response:back_alley_offer:take_money'
        $cashEventHostileCases.Add([pscustomobject]@{ label = 'action-id-fabricated'; stage = 'choice'; fixture = $fixture })

        $fixture = New-GrandFareCashEventPolicyFixture; $fixture.after_observation.event_popup.visible = $true
        $cashEventHostileCases.Add([pscustomobject]@{ label = 'result-popup-visible'; stage = 'result'; fixture = $fixture })
        $fixture = New-GrandFareCashEventPolicyFixture; $fixture.after_observation.event_popup.visible = 0
        $cashEventHostileCases.Add([pscustomobject]@{ label = 'result-popup-visible-non-boolean'; stage = 'result'; fixture = $fixture })
        $fixture = New-GrandFareCashEventPolicyFixture; $fixture.after_observation.talk.visible = $true
        $cashEventHostileCases.Add([pscustomobject]@{ label = 'result-talk-visible'; stage = 'result'; fixture = $fixture })
        $fixture = New-GrandFareCashEventPolicyFixture; $fixture.after_observation.status_hud.bankroll_rendered = $false
        $cashEventHostileCases.Add([pscustomobject]@{ label = 'result-bankroll-unrendered'; stage = 'result'; fixture = $fixture })
        $fixture = New-GrandFareCashEventPolicyFixture; $fixture.after_observation.status_hud.bankroll_rendered = 1
        $cashEventHostileCases.Add([pscustomobject]@{ label = 'result-bankroll-render-non-boolean'; stage = 'result'; fixture = $fixture })
        $fixture = New-GrandFareCashEventPolicyFixture; $fixture.after_observation.status_hud.heat_rendered = $false
        $cashEventHostileCases.Add([pscustomobject]@{ label = 'result-heat-unrendered'; stage = 'result'; fixture = $fixture })
        $fixture = New-GrandFareCashEventPolicyFixture; $fixture.after_observation.status_hud.bankroll = $fixture.before_bankroll
        $cashEventHostileCases.Add([pscustomobject]@{ label = 'result-bankroll-nonpositive'; stage = 'result'; fixture = $fixture })
        $fixture = New-GrandFareCashEventPolicyFixture; $fixture.after_observation.status_hud.heat_level = $fixture.before_heat
        $cashEventHostileCases.Add([pscustomobject]@{ label = 'result-heat-nonpositive'; stage = 'result'; fixture = $fixture })
        $fixture = New-GrandFareCashEventPolicyFixture; $fixture.after_observation.status_hud.bankroll += 1
        $cashEventHostileCases.Add([pscustomobject]@{ label = 'result-bankroll-feedback-mismatch'; stage = 'result'; fixture = $fixture })
        $fixture = New-GrandFareCashEventPolicyFixture; $fixture.after_observation.status_hud.heat_level += 1
        $cashEventHostileCases.Add([pscustomobject]@{ label = 'result-heat-feedback-mismatch'; stage = 'result'; fixture = $fixture })
        $fixture = New-GrandFareCashEventPolicyFixture; $fixture.after_observation.feedback.visible = $false
        $cashEventHostileCases.Add([pscustomobject]@{ label = 'result-feedback-hidden'; stage = 'result'; fixture = $fixture })
        $fixture = New-GrandFareCashEventPolicyFixture; $fixture.after_observation.feedback.visible = 'true'
        $cashEventHostileCases.Add([pscustomobject]@{ label = 'result-feedback-visible-non-boolean'; stage = 'result'; fixture = $fixture })
        $fixture = New-GrandFareCashEventPolicyFixture; $fixture.after_observation.feedback.title = 'result'
        $cashEventHostileCases.Add([pscustomobject]@{ label = 'result-title-case'; stage = 'result'; fixture = $fixture })
        $fixture = New-GrandFareCashEventPolicyFixture; $fixture.after_observation.feedback.text = $fixture.after_observation.feedback.text.Replace('Small cash.', 'Cash.')
        $cashEventHostileCases.Add([pscustomobject]@{ label = 'result-message-mismatch'; stage = 'result'; fixture = $fixture })
        $fixture = New-GrandFareCashEventPolicyFixture
        $fixture.before_feedback = [pscustomobject]@{ visible = $true; text = $fixture.after_observation.feedback.text }
        $cashEventHostileCases.Add([pscustomobject]@{ label = 'result-feedback-stale'; stage = 'result'; fixture = $fixture })

        $fixture = New-GrandFareCashEventPolicyFixture
        $cashEventHostileCases.Add([pscustomobject]@{
            label = 'result-event-id-case'; stage = 'result'; fixture = $fixture
            event_mutator = { param($event) $event.event_id = 'Back_Alley_Offer' }
        })
        $fixture = New-GrandFareCashEventPolicyFixture
        $cashEventHostileCases.Add([pscustomobject]@{
            label = 'result-choice-id-case'; stage = 'result'; fixture = $fixture
            event_mutator = { param($event) $event.choice_id = 'TAKE_CASH' }
        })
        $fixture = New-GrandFareCashEventPolicyFixture
        $cashEventHostileCases.Add([pscustomobject]@{
            label = 'result-allowlisted-message-tampered'; stage = 'result'; fixture = $fixture
            event_mutator = { param($event) $event.expected_result_text = 'Small cash.' }
        })

        $grandFareCashEventHostileFixtures = $cashEventHostileCases.Count
        foreach ($case in $cashEventHostileCases) {
            $threw = $false
            try {
                $eventMutator = $null
                if ($case.PSObject.Properties['event_mutator']) {
                    $eventMutator = $case.event_mutator
                }
                $null = Invoke-CashEventPolicyFixture -Fixture $case.fixture -Through ([string]$case.stage) -EventMutator $eventMutator
            }
            catch {
                $threw = $true
            }
            if (-not $threw) {
                Add-Failure "Hostile Grand-fare cash event '$($case.label)' did not fail closed."
            }
        }
    }
    else {
        Add-Failure 'Replay policy helper did not export the complete Grand-fare public cash-event policy.'
    }

    $validCommandOpenFixture = @'
func _poll_once() -> void:
	var command_path := _path("%04d.command.txt" % next_command)
	if not FileAccess.file_exists(command_path):
		return
	var file := FileAccess.open(command_path, FileAccess.READ)
	if file == null:
		return
	var raw := file.get_as_text().strip_edges()
	file.close()
	var result := await _execute_command(raw, next_command)
	_write_json(_path("%04d.result.json" % next_command), result)
	next_command += 1
'@
    $hostileCommandOpenFixtures = @(
        [pscustomobject]@{ label = 'null-open-becomes-empty-command'; source = @'
func _poll_once() -> void:
	var file := FileAccess.open(command_path, FileAccess.READ)
	var raw := file.get_as_text().strip_edges() if file != null else ""
	if file != null:
		file.close()
	var result := await _execute_command(raw, next_command)
	_write_json(_path("%04d.result.json" % next_command), result)
	next_command += 1
'@ },
        [pscustomobject]@{ label = 'null-open-advances-ordinal'; source = @'
func _poll_once() -> void:
	var file := FileAccess.open(command_path, FileAccess.READ)
	if file == null:
		next_command += 1
		return
	var raw := file.get_as_text().strip_edges()
	file.close()
	var result := await _execute_command(raw, next_command)
	_write_json(_path("%04d.result.json" % next_command), result)
	next_command += 1
'@ },
        [pscustomobject]@{ label = 'null-open-writes-result'; source = @'
func _poll_once() -> void:
	var file := FileAccess.open(command_path, FileAccess.READ)
	if file == null:
		_write_json(_path("%04d.result.json" % next_command), {})
		return
	var raw := file.get_as_text().strip_edges()
	file.close()
	var result := await _execute_command(raw, next_command)
	_write_json(_path("%04d.result.json" % next_command), result)
	next_command += 1
'@ },
        [pscustomobject]@{ label = 'execute-before-open-check'; source = @'
func _poll_once() -> void:
	var file := FileAccess.open(command_path, FileAccess.READ)
	var raw := file.get_as_text().strip_edges() if file != null else ""
	var result := await _execute_command(raw, next_command)
	if file == null:
		return
	file.close()
	_write_json(_path("%04d.result.json" % next_command), result)
	next_command += 1
'@ }
    )
    $commandOpenValidFixtures = 1
    $commandOpenHostileFixtures = $hostileCommandOpenFixtures.Count
    if (-not (Test-CommandOpenRetrySequence -Source $validCommandOpenFixture)) {
        Add-Failure 'Valid transient command-open retry fixture was rejected.'
    }
    foreach ($fixture in $hostileCommandOpenFixtures) {
        if (Test-CommandOpenRetrySequence -Source ([string]$fixture.source)) {
            Add-Failure "Hostile command-open fixture '$($fixture.label)' did not fail closed."
        }
    }
    if (-not (Test-CommandOpenRetrySequence -Source $bridge)) {
        Add-Failure 'Production bridge must leave a transiently unopenable published command pending without executing, writing a result, or advancing its ordinal.'
    }
    Assert-Match $bridge '(?s)func _execute_command\(raw: String, command_number: int\).*?elif raw\.is_empty\(\):\s*reason\s*=\s*"empty command"' 'A successfully opened, genuinely empty command must retain its explicit rejection.'

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
        [pscustomobject]@{ label = 'ordinary-root-button'; candidates = @('app-root'); live = 'app-root'; root = 'app-root'; surface_id = ''; embedded = $false; parent_node = ''; embedder = ''; window_x = 0; window_y = 0; local_x = 420.0; local_y = 210.0; expected_viewport = 'app-root'; expected_x = 420.0; expected_y = 210.0 },
        [pscustomobject]@{ label = 'embedded-confirmation-dialog-button'; candidates = @('tutorial-dialog'); live = 'tutorial-dialog'; root = 'app-root'; surface_id = 'tutorial_skip_dialog'; embedded = $true; parent_node = 'app'; embedder = 'app-root'; window_x = 380.0; window_y = 265.0; local_x = 161.5; local_y = 166.5; expected_viewport = 'app-root'; expected_x = 541.5; expected_y = 431.5 }
    )
    $buttonViewportValidFixtures = $validButtonViewportFixtures.Count
    foreach ($fixture in $validButtonViewportFixtures) {
        try {
            $null = Assert-ButtonInputRouteFixture -Fixture $fixture
        }
        catch {
            Add-Failure "Valid button viewport fixture '$($fixture.label)' threw: $($_.Exception.Message)"
        }
    }
    $hostileButtonViewportFixtures = @(
        [pscustomobject]@{ label = 'null-recorded-viewport'; candidates = @($null); live = 'app-root'; root = 'app-root'; surface_id = ''; embedded = $false; parent_node = ''; embedder = ''; window_x = 0; window_y = 0; local_x = 420.0; local_y = 210.0; expected_viewport = 'app-root'; expected_x = 420.0; expected_y = 210.0 },
        [pscustomobject]@{ label = 'wrong-recorded-viewport'; candidates = @('app-root'); live = 'tutorial-dialog'; root = 'app-root'; surface_id = 'tutorial_skip_dialog'; embedded = $true; parent_node = 'app'; embedder = 'app-root'; window_x = 380.0; window_y = 265.0; local_x = 161.5; local_y = 166.5; expected_viewport = 'app-root'; expected_x = 541.5; expected_y = 431.5 },
        [pscustomobject]@{ label = 'ambiguous-recorded-viewports'; candidates = @('app-root', 'tutorial-dialog'); live = 'tutorial-dialog'; root = 'app-root'; surface_id = 'tutorial_skip_dialog'; embedded = $true; parent_node = 'app'; embedder = 'app-root'; window_x = 380.0; window_y = 265.0; local_x = 161.5; local_y = 166.5; expected_viewport = 'app-root'; expected_x = 541.5; expected_y = 431.5 },
        [pscustomobject]@{ label = 'non-embedded-dialog'; candidates = @('tutorial-dialog'); live = 'tutorial-dialog'; root = 'app-root'; surface_id = 'tutorial_skip_dialog'; embedded = $false; parent_node = 'app'; embedder = 'app-root'; window_x = 380.0; window_y = 265.0; local_x = 161.5; local_y = 166.5; expected_viewport = 'app-root'; expected_x = 541.5; expected_y = 431.5 },
        [pscustomobject]@{ label = 'missing-dialog-parent'; candidates = @('tutorial-dialog'); live = 'tutorial-dialog'; root = 'app-root'; surface_id = 'tutorial_skip_dialog'; embedded = $true; parent_node = ''; embedder = 'app-root'; window_x = 380.0; window_y = 265.0; local_x = 161.5; local_y = 166.5; expected_viewport = 'app-root'; expected_x = 541.5; expected_y = 431.5 },
        [pscustomobject]@{ label = 'wrong-dialog-parent'; candidates = @('tutorial-dialog'); live = 'tutorial-dialog'; root = 'app-root'; surface_id = 'tutorial_skip_dialog'; embedded = $true; parent_node = 'wrapper'; embedder = 'app-root'; window_x = 380.0; window_y = 265.0; local_x = 161.5; local_y = 166.5; expected_viewport = 'app-root'; expected_x = 541.5; expected_y = 431.5 },
        [pscustomobject]@{ label = 'nested-dialog-embedder'; candidates = @('tutorial-dialog'); live = 'tutorial-dialog'; root = 'app-root'; surface_id = 'tutorial_skip_dialog'; embedded = $true; parent_node = 'outer-dialog'; embedder = 'outer-dialog'; window_x = 380.0; window_y = 265.0; local_x = 161.5; local_y = 166.5; expected_viewport = 'app-root'; expected_x = 541.5; expected_y = 431.5 },
        [pscustomobject]@{ label = 'untranslated-dialog-offset'; candidates = @('tutorial-dialog'); live = 'tutorial-dialog'; root = 'app-root'; surface_id = 'tutorial_skip_dialog'; embedded = $true; parent_node = 'app'; embedder = 'app-root'; window_x = 380.0; window_y = 265.0; local_x = 161.5; local_y = 166.5; expected_viewport = 'app-root'; expected_x = 161.5; expected_y = 166.5 }
    )
    $buttonViewportHostileFixtures = $hostileButtonViewportFixtures.Count
    foreach ($fixture in $hostileButtonViewportFixtures) {
        $threw = $false
        try {
            $null = Assert-ButtonInputRouteFixture -Fixture $fixture
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
        'Select-CheatReplayBlackjackCheatAction',
        'Select-CheatReplayBossCalloutAction',
        'Select-CheatReplayShowdownWalkChoice',
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
        'function Enter-VisibleSlotForGrandFare',
        'function Wait-ForVisibleSlotActionBoundary',
        'function Earn-GrandFareThroughVisibleSlot',
        'function Invoke-GrandFarePublicFundingOffer',
        'function Invoke-GrandFarePublicCashEvent',
        'function Recover-GrandFareThroughPublicFunding',
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
        "'cage_buy_50' -cin `$enabledChoices",
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
        "@('screen', 'run_report_visible') `$null",
        '$Repeat -ceq 2',
        'release_qualifying = $releaseQualifying',
        'PLAY did not visibly enter a live first-night lesson',
        "StartsWith('tutorial_guide:', [StringComparison]::Ordinal)",
        "`$choiceIds.Count -cne 1 -or [string]`$choiceIds[0] -cne 'continue'",
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
        'func _button_input_route(data: Dictionary, button: Button, local_position: Vector2) -> Dictionary:',
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
        'var save_indicator := _public_status_indicator("save")',
        'result["save_text_visible"] = true',
        'func _public_status_indicator(status_id: String) -> Dictionary:',
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
        'var map_rendered := _is_true_bool(source.get("world_map_overlay_visible", false))',
        'and _is_true_bool(overlay_state.get("world_map_visible", false))',
        'if map_rendered else {}',
        'var start_menu_rendered := screen_id == "START"',
        'var run_menu_rendered := _is_true_bool(source.get("run_menu_visible", false))',
        'and _is_true_bool(overlay_state.get("run_menu_visible", false))',
        'var run_report_rendered := screen_id in ["VICTORY", "FAILURE"]',
        'and _is_true_bool(source.get("run_report_visible", false))',
        'if _is_true_bool(source.get("seed_field_visible", false)) and _is_true_bool(source.get("seed_text_committed", false))',
        'typeof(save_visible_value) == TYPE_BOOL and bool(save_visible_value)',
        'result["debt_indicator"] = _debt_indicator(_dict(source.get("debt_indicator", {})))'
    )) {
        Assert-Contains $sanitizer $required "Public observation sanitizer is missing required source contract token: $required"
    }
    Assert-NotMatch $sanitizer '(?ms)^static func _actions\(.*?(?=^static func |\z).*?"impact_summary"' 'Selected room/game actions must not expose undisplayed impact_summary metadata through the public observation sanitizer.'

    foreach ($required in @(
        'SECRET_HOLE_A',
        'SECRET_SHOE_A',
        'SECRET_BRANCH_A',
        'SECRET_CLOSED_MAP_MARKER',
        'SECRET_CLOSED_MAP_DETAIL',
        'SECRET_CLOSED_MENU_ASYNC_A',
        'A visible clipped TalkDock was incorrectly reported hidden.',
        'Visible TalkDock typewriter completion did not alter the public trace.',
        'A non-boolean typewriter witness did not fail closed.',
        'A visible clipped event popup was incorrectly reported hidden.',
        'A rendered event popup leaked hidden consequence or trigger metadata.',
        'Raw HUD mutations with false rendered witnesses altered the public trace.',
        'Malformed HUD type witnesses were coerced into public values.',
        'Raw consequence debt escaped into public observation.',
        'Feedback exposed fields beyond its visible title and text.',
        'Rendered action identity leaked unaudited detail or consequence text.',
        'RUN-SECRET-WALL-CLOCK-A',
        'SECRET_OFFSCREEN_TERMINAL_OUTCOME',
        'A populated closed-overlay world map escaped into public observation.',
        'Closed run-menu async state altered the public trace.',
        'Uncommitted generated menu seeds made replay traces nondeterministic.',
        'Distinct explicitly entered visible seeds were incorrectly normalized away.',
        'An offscreen terminal report escaped into public observation.',
        'A non-boolean terminal render witness was coerced to visible.',
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
    Assert-Contains $bridge 'var choice_list := talk_dock.get("choice_list") as Control if talk_dock != null else null' 'Semantic TalkDock choices must bind to the actual rendered choice list.'
    Assert-Contains $runner "@('look', 'clickable', 'talk_choices')" 'Replay routes must consume the rendered TalkDock enabled-state mapping.'
    Assert-Contains $runner "@('look', 'clickable', 'scroll_surfaces')" 'Replay routes must consume only the public rendered scroll-surface mapping.'
    Assert-Match $runner '(?s)function Get-VisibleTutorialGuideAcknowledgment.*?render_valid.*?tutorial_guide:.*?choiceIds\.Count\s+-cne\s+1.*?choiceIds\[0\].*?continue.*?Get-PublicTalkChoices.*?enabled\s+-is\s+\[bool\]' 'Coach recovery must accept only one fully rendered, exactly typed, enabled continue choice from the public tutorial-guide TalkDock.'
    Assert-Match $runner '(?s)function Clear-VisibleCoach.*?Get-VisibleTutorialGuideAcknowledgment.*?Choose-VisibleChoice\s+-ChoiceId\s+''continue''.*?Wait-Frames.*?continue.*?dismissLabel.*?Select-UniqueFullyVisibleButton\s+-Buttons\s+@\(Get-Buttons\)\s+-Text\s+\$dismissLabel.*?Select-UniqueFullyVisibleButton\s+-Buttons\s+@\(Get-Buttons\)\s+-Text\s+''Skip tip''.*?fully visible public dismiss control' 'Coach recovery must follow the narrow public tutorial-guide acknowledgement, then require a unique boolean-true fully-visible dismiss control before input.'
    Assert-Match $runner '(?s)function Accept-GrandCasinoInviteIfVisible\s*\{.*?Invoke-EventObjectChoice\s+-EventId\s+''grand_casino_invite''\s+-ChoiceId\s+''accept_invite''\s+-Intent\s+''accept the visible invitation to the Grand Casino''.*?return \$true\s*\}' 'The clean replay must choose the exact visible invitation action instead of asking a selected multi-action object for a generic open action.'
    Assert-NotMatch $runner 'Open-EventObject\s+-EventId\s+''grand_casino_invite''' 'The Grand Casino invitation must not use the generic event-open path when the selected object already exposes explicit actions.'
    Assert-Match $runner '(?s)function Reach-GrandCasino.*?\$grand\s*=\s*@\(\$nodes.*?archetype_id.*?grand_casino.*?\$grand\.Count\s+-gt\s+1.*?\$requiredCash.*?GrandCasinoChipReserve.*?Recover-GrandFareThroughPublicFunding\s+-RequiredCash\s+\$requiredCash.*?travel_enabled.*?Travel-ToNode' 'The clean replay must recompute the published Grand fare plus its documented chip reserve, recover that full amount, and only then take the visible route.'
    Assert-Match $runner '(?s)function Invoke-GrandFarePublicFundingOffer.*?Select-GrandFareFundingObject.*?Test-GrandFareFundingPreflight.*?click_object.*?Select-GrandFareFundingObjectAction.*?Invoke-RoomActionRow.*?Select-GrandFareFundingTalkOffer.*?click_choice accept.*?Assert-GrandFareFundingConfirmation.*?click_choice accept.*?Assert-GrandFareFundingResult.*?GrandFareAcceptedOfferKeys\.Add.*?GrandFareAcceptedLenderIds\.Add' 'Grand fare lender recovery must validate one public object and debt preflight before focus, validate its unique action and rendered terms, verify confirmation and the exact bankroll/debt result, then record both one-use keys.'
    Assert-Match $runner '(?s)function Invoke-GrandFarePublicCashEvent.*?Select-GrandFareCashEventChoice.*?Invoke-RoomActionRow.*?Assert-GrandFareCashEventResult.*?GrandFareResolvedCashEventKeys\.Add' 'Grand fare cash-event recovery must use the exact public allowlist, one direct-resolve rendered room action, a positive public HUD delta, and one-use bookkeeping.'
    Assert-Match $runner '(?s)function Recover-GrandFareThroughPublicFunding.*?MaximumFundingStops\s*=\s*6.*?GrandFareRecoveryActive.*?RequiredCash.*?GrandFareRecoveryVisitedNodes\.Add.*?Invoke-GrandFarePublicFundingOffer.*?Invoke-GrandFarePublicCashEvent.*?Get-MapNodes.*?Earn-GrandFareThroughVisibleSlot.*?finally.*?GrandFareRecoveryActive\s*=\s*\$false' 'The funding helper must be recovery-scoped, bounded, lender-first, public-map driven, and leave slot play as its final fallback.'
    Assert-Match $runner '(?s)function Earn-GrandFareThroughVisibleSlot.*?MaximumSpins\s*=\s*6.*?MaximumLosses\s*=\s*3.*?Enter-VisibleSlotForGrandFare.*?startingCash.*?losses.*?Wait-ForVisibleSlotActionBoundary.*?status_hud.*?bankroll.*?slot_spin.*?loss-stopped.*?Leave-GameSurface' 'Grand fare slot fallback must be capped at six spins, stop after three losses, and use only visible actions and public bankroll evidence.'
    Assert-Match $runner '(?s)function Resolve-GrandFareMachineJamIfVisible.*?Select-GrandFareMachineJamChoice.*?Choose-VisibleChoice.*?visible de-escalation choice.*?Wait-Frames.*?modal remained visible or chained into another modal' 'Grand fare recovery must route the exact rendered machine_jam policy through the confirmation-aware visible-choice path and fail closed if any modal remains.'
    Assert-Match $runner '(?s)function Wait-ForVisibleSlotActionBoundary.*?Resolve-GrandFareMachineJamIfVisible.*?continue.*?slot_handpay_acknowledge' 'Only the Grand fare slot boundary may resolve the allowlisted public machine_jam before normal slot actions resume.'
    Assert-Match $replayPolicy '(?s)function Select-GrandFareMachineJamChoice.*?TalkDock state.*?rendered event-popup witness.*?machine_jam.*?Machine Jam.*?exactly ordered wait, push.*?Wait it out.*?Push through.*?return ''wait''' 'The shared replay policy must strictly validate the rendered machine_jam identity, copy, choice order, controls, and visible de-escalation response.'
    Assert-Match $replayPolicy '(?s)function Select-GrandFareFundingObject.*?lender:.*?rendered.*?AcceptedOfferKeys.*?AcceptedLenderIds.*?Sort-Object.*?-CaseSensitive.*?function Select-GrandFareFundingObjectAction.*?exact public Use action.*?function Select-GrandFareFundingTalkOffer' 'The shared funding policy must validate exact rendered lender identity, skip used or disabled offers, deterministically select among multiple lenders, and require the unique Use action.'
    Assert-Match $replayPolicy '(?s)function Select-GrandFareFundingTalkOffer.*?lender_conversation:borrow:.*?Borrow.*?Repay.*?Accept Offer.*?function Assert-GrandFareFundingConfirmation' 'The shared funding policy must validate the exact lender talk identity, rendered principal and obligation terms, and accept control.'
    Assert-Match $replayPolicy '(?s)function Assert-GrandFareFundingConfirmation.*?Confirm: Accept Offer.*?function Assert-GrandFareFundingResult' 'The shared funding policy must require the visibly armed lender confirmation.'
    Assert-Match $replayPolicy '(?s)function Assert-GrandFareFundingResult.*?bankroll_rendered.*?expectedBankrollLong.*?Get-GrandFarePublicDebtCount.*?afterDebtCount\s+-ne\s+\$beforeDebtCount\s+\+\s+1.*?exact disclosed terms.*?exact positive bankroll delta' 'The shared funding policy must verify exact rendered bankroll, one additional rendered debt indicator, and Result feedback bound to the disclosed terms and delta.'
    Assert-Match $replayPolicy '(?s)function Get-Rw062ExactPublicPropertyMatches.*?Name\s+-ceq.*?function Get-Rw062RequiredPublicProperty.*?properties\.Count\s+-ne\s+1' 'Critical replay-policy schema keys must be matched by exact property-name casing.'
    Assert-Match $replayPolicy '(?s)function Select-GrandFareFundingObject.*?-cnotmatch.*?StartsWith\(''lender:'', \[StringComparison\]::Ordinal\).*?-cnotin.*?function Select-GrandFareFundingObjectAction.*?-cne ''Use''.*?IsNullOrEmpty' 'Grand fare lender schema matching must remain case-sensitive for world ids, lender prefixes/suffixes, object types, the Use label, and blank compatibility identities.'
    Assert-Match $replayPolicy '(?s)function Select-GrandFareCashEventChoice.*?back_alley_offer.*?Back Alley Offer.*?Small cash.*?scenario_wedding_overflow_hallway.*?Hallway Table.*?pays out.*?function Assert-GrandFareCashEventResult.*?strictly positive public HUD bankroll delta' 'The shared cash-event policy must strictly allowlist exact rendered event objects/actions and require only the positive public HUD result promised by their visible copy.'
    Assert-NotMatch $replayPolicy '(?ms)^function (?:Select|Assert)-GrandFare(?:Funding|CashEvent).*?(?=^function |\z).*?impact_summary' 'New Grand-fare lender/cash policies must not consume undisplayed impact_summary metadata.'
    Assert-NotMatch $runner '(?ms)^function Invoke-GrandFarePublic(?:FundingOffer|CashEvent).*?(?=^function |\z).*?impact_summary' 'New Grand-fare runner paths must not consume undisplayed impact_summary metadata.'
    Assert-NotMatch $replayPolicy '(?:slot_nudge|slot_auto_toggle|autoplay|narrative_flags|run_state|local_narrative_flags|crew_heist_state|trigger_context|scenario_layout_audit)' 'Replay policy helpers must not use slot cheats, autoplay, or private state.'
    Assert-Match $runner '(?s)function Wait-ForVisibleSlotActionBoundary.*?slot_handpay_acknowledge.*?slot_bonus_.*?slot_spin.*?within twelve seconds' 'Grand fare recovery must finish visible slot presentation and deterministic bonus controls before the next Spin.'
    Assert-NotMatch $runner '(?ms)^function Enter-VisibleSlotForGrandFare(?:(?!^function Reach-GrandCasino).)*(?:slot_nudge|slot_auto_toggle|narrative_flags|run_state)' 'Grand fare recovery must not use a slot cheat, autoplay, or private state.'
    Assert-Match $foundationMain '(?s)func activate_event_choice_action\(event_id: String, choice_id: String\).*?select_event_choice\(event_id, choice_id\).*?confirm_selected_event_choice\(\)' 'Inline room event actions must remain a single public callback that selects and confirms the rendered choice internally.'
    Assert-Match $foundationMain '(?s)func _add_context_event_inline_actions\(.*?_add_card_button\(card, label, Callable\(self, "activate_event_choice_action"\)\.bind\(event_id, choice_id\)' 'Rendered inline event choice controls must remain directly bound to the select-and-confirm callback.'
    Assert-Match $foundationMain '(?s)func _event_inline_response_actions\(event_id: String, choices: Array\).*?"event_response:%s:%s" % \[event_id, choice_id\].*?"emit_object_id": emit_object_id' 'Foundation event cards must publish exact event/choice semantic action tokens.'
    Assert-Match $pixelSceneCanvas '(?s)func _selected_info_inline_actions\(.*?emit_object_id.*?func _selected_info_action_entries_from_info\(.*?"enabled": bool\(action_data\.get\("enabled".*?func _activate_selected_info_action_entry\(.*?not bool\(action_entry\.get\("enabled".*?object_activated\.emit\(emit_object_id if not emit_object_id\.is_empty\(\) else object_id\)' 'The room canvas must carry semantic inline-action identity into the selected snapshot, re-check enabled state, and emit the exact action token.'
    Assert-Contains $foundationScreenBuilder 'host.environment_canvas.object_activated.connect(host._on_environment_object_activated)' 'The production room canvas activation signal must remain connected to FoundationMain.'
    Assert-Match $foundationMain '(?s)func _on_environment_object_activated\(object_id: String\).*?activate_interactable_object\(object_id\)' 'Canvas activation must enter FoundationMain through the production interactable dispatcher.'
    Assert-Match $foundationMain '(?s)func activate_interactable_object\(object_id: String\).*?event_response:.*?_activate_event_response_action\(object_id\)' 'FoundationMain must dispatch exact event-response tokens before generic interaction handling.'
    Assert-Match $foundationMain '(?s)func _activate_event_response_action\(action_object_id: String\).*?call_deferred\("_finish_deferred_event_response_action", event_id, choice_id\).*?func _finish_deferred_event_response_action\(event_id: String, choice_id: String\).*?activate_event_choice_action\(event_id, choice_id\)' 'Event-response dispatch must defer the exact event/choice pair into the select-and-confirm callback.'
    Assert-Match $foundationMain '(?s)func _add_wager_confirmation_card\(.*?card\.set_meta\("event_id", rendered_event_id\).*?card\.set_meta\("choice_id", rendered_choice_id\).*?button\.set_meta\("event_id", rendered_event_id\).*?button\.set_meta\("choice_id", rendered_choice_id\)' 'Event popup cards and buttons must retain exact event/choice metadata for live click revalidation.'
    Assert-Match $foundationMain '(?s)"Leave It".*?Callable\(self, "_dismiss_interactable_event_popup"\).*?event_id,\s*"dismiss"' 'Synthetic event dismissal must carry an exact rendered event/choice identity.'
    Assert-Match $talkDock '(?s)var button := FoundationWidgets\.button\(label, Callable\(self, "_on_choice_pressed"\)\.bind\(choice_id\)\).*?button\.set_meta\("event_id".*?button\.set_meta\("choice_id", choice_id\)' 'TalkDock buttons must carry exact event/choice metadata for live click revalidation.'
    Assert-Contains $foundationHudBar 'icon_rect.set_meta("status_id", str(status.get("id", "")))' 'Structured HUD status icons must carry stable status ids for rendered indicator evidence.'
    Assert-Match $runState '(?s)func _merge_stackable_debt\(debt_entry: Dictionary\).*?lender_id.*?CREW_LENDER_ID.*?debt_kind.*?favor.*?existing.*?CREW_LENDER_ID.*?existing.*?favor.*?debt\[index\] = existing.*?return true' 'RunState debt merging must remain limited to Crew favor obligations.'

    Assert-Match $bridge '(?s)func _public_status_indicator\(status_id: String\).*?_control_is_fully_rendered\(structured_hud\).*?_control_is_fully_rendered\(status_tray\).*?for child in status_tray\.get_children\(\).*?not _control_is_fully_rendered\(control\).*?get_meta\("status_id".*?matches\.size\(\) != 1.*?tooltip.*?"rendered": true, "present": true' 'HUD status evidence must require the full structured HUD, tray, every child, one stable id, and rendered tooltip text.'
    Assert-Match $bridge '(?s)func _public_rendered_status_hud\(_source: Dictionary\).*?wallet_label\.text.*?bankroll_rendered.*?chips_chip.*?chips_label\.text.*?chips_rendered.*?heat_label\.text.*?heat_rendered.*?_public_status_indicator\("save"\)' 'Bankroll, chips, heat, and save evidence must be derived from their actual fully rendered HUD controls.'
    Assert-NotMatch $bridge '(?ms)^func _public_rendered_status_hud\(.*?(?=^func |\z).*?_source\.get' 'Rendered HUD construction must not copy raw host HUD values.'
    Assert-Match $bridge '(?s)func _public_rendered_talk\(source: Dictionary\).*?_control_is_rendered\(panel\).*?"visible": true.*?"render_valid": false.*?_control_is_fully_rendered\(panel\).*?_label_text_is_fully_rendered\(body_label\).*?result\["render_valid"\] = true' 'A present but clipped TalkDock must stay visibly invalid until its complete rendered surface is authenticated.'
    Assert-Match $bridge '(?s)func _public_rendered_event_popup\(_source: Dictionary\).*?_control_is_rendered\(panel\).*?"visible": true, "render_valid": false.*?_control_is_fully_rendered\(panel\).*?result\["render_valid"\] = true' 'A present but clipped event popup must stay visibly invalid until every rendered card is authenticated.'
    Assert-Match $bridge '(?s)func _canvas_objects\(canvas: Control\).*?_control_is_fully_rendered\(canvas\).*?global_rect_for_object.*?_rect_encloses_with_tolerance.*?"rendered": rendered' 'Clickable room objects must carry an exact fully rendered geometry witness.'
    Assert-Match $bridge '(?s)func _room_selected_actions\(canvas: Control\).*?_control_is_fully_rendered\(canvas\).*?selected_object_id.*?button_rect.*?_room_action_label_is_fully_rendered.*?"rendered": rendered.*?"rect": global_rect if rendered else Rect2\(\)' 'Selected room actions must publish their exact selected-object identity, live row, fully rendered label/geometry witness, and hit rectangle.'
    Assert-Match $bridge '(?s)func _click_action\(argument: String\).*?parts\[0\].*?room.*?_click_room_action.*?func _click_room_action\(parts: PackedStringArray\).*?identity_matches\.size\(\) != 1.*?live_index_value.*?TYPE_BOOL.*?TYPE_RECT2.*?distance_to.*?_push_mouse_click\(live_rect\.get_center\(\), false\)' 'Room actions must revalidate one exact live object/identity/index, boolean enabled/rendered signals, unchanged hit geometry, and then use a physical click.'
    Assert-NotMatch $sanitizer '"(?:demo_objective|objective_guidance|next_objective|run_status|run_text|debt_items)"' 'Public sanitization must omit raw objective, run-state, and debt-model fields.'

    Assert-Match $runner '(?s)function Get-Value\s*\{.*?IDictionary.*?Keys.*?-ceq\s+\$segment.*?PSObject\.Properties.*?Name\s+-ceq\s+\$segment.*?Ambiguous exact property' 'Runner property traversal must use exact dictionary/property names and reject ambiguity.'
    $getValueFunction = [regex]::Match($runner, '(?ms)^function Get-Value\s*\{.*?(?=^function |\z)')
    if (-not $getValueFunction.Success -or $getValueFunction.Value.Contains('OrdinalIgnoreCase')) {
        Add-Failure 'Runner Get-Value must not perform case-insensitive property lookup.'
    }
    Assert-NotMatch $runner 'Get-Value[^\r\n]+(?:demo_objective|objective_guidance|next_objective|run_status|run_text)' 'Replay routes must not consume raw objective or run-status fields.'
    Assert-Match $runner '(?s)function Select-ExactRenderedCanvasObject.*?matches\.Count\s+-gt\s+1.*?rendered\s+-isnot\s+\[bool\].*?enabled\s+-isnot\s+\[bool\].*?function Select-FirstRenderedCanvasObjectByPrefix.*?duplicate semantic id.*?Sort-Object.*?-CaseSensitive' 'Canvas-object route decisions must require unique exact identities, true boolean rendered/enabled witnesses, and deterministic ordinal prefix selection.'
    Assert-Match $runner '(?s)function Assert-ExactRenderedRoomActionBinding.*?matches\.Count\s+-cne\s+1.*?changed row order.*?disabled, clipped.*?function Invoke-RoomActionRow.*?selected_object_id.*?ConvertTo-BridgeBase64Token.*?click_action room' 'Room-action commands must bind one exact selected object, identity, row index, rendered/enabled state, and encoded bridge command.'
    Assert-Match $runner '(?s)function Assert-ExplicitSaveAcknowledgmentObservation.*?hasSave\s+-isnot\s+\[bool\].*?saveTextVisible\s+-isnot\s+\[bool\].*?saveText\s+-isnot\s+\[string\].*?-cne\s+\$expectedVisibleText' 'Save acknowledgment must reject missing, non-boolean, and inexact public witnesses.'
    Assert-Match $runner '(?s)function Test-PublicTerminalSurface.*?screen\s+-cnotin\s+@\(''VICTORY'', ''FAILURE''\).*?visible\s+-isnot\s+\[bool\].*?function Assert-TerminalOutcome.*?screenName\s+-cne\s+''VICTORY''.*?won\s+-isnot\s+\[bool\].*?outcome\s+-cnotin\s+\$ExpectedOutcomes' 'Terminal routing must require exact terminal screen ids, exact boolean witnesses, and exact allowlisted outcome ids.'
    $cashRunnerFunction = [regex]::Match($runner, '(?ms)^function Invoke-GrandFarePublicCashEvent\s*\{.*?(?=^function |\z)')
    if (-not $cashRunnerFunction.Success -or [regex]::Matches($cashRunnerFunction.Value, '\bInvoke-RoomActionRow\b').Count -ne 1 -or
        [regex]::IsMatch($cashRunnerFunction.Value, '(?:requires_confirm|impact_summary|click_choice)', [Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
        Add-Failure 'Grand fare cash-event recovery must issue exactly one rendered room-action click and consume no hidden or second-click confirmation metadata.'
    }
    Assert-Match $runner '(?s)function Select-UniquePublicVerticalScrollSurface.*?SurfaceId\s+-cne\s+''run_menu''.*?matches\.Count\s+-cne\s+1.*?axis.*?vertical.*?rendered\s+-isnot\s+\[bool\].*?canScroll\s+-isnot\s+\[bool\]' 'Run-menu scroll selection must reject unsupported, ambiguous, hidden, wrong-axis, non-boolean, and direction-blocked public surfaces.'
    Assert-Match $runner '(?s)function Select-UniqueFullyVisibleButton.*?matches\.Count\s+-gt\s+1.*?Get-Value\s+\$button\s+@\(''fully_visible''\)\s+\$null.*?-isnot\s+\[bool\].*?fully_visible signal.*?return \$null' 'Run-menu button selection must fail closed on ambiguous, absent, wrong-case, non-boolean, and false fully-visible signals.'
    Assert-Match $runner '(?s)function Select-UniquePublicTutorialDialogButton.*?tutorial_skip_dialog:\$Role.*?surface_id.*?dialog_role.*?matches\.Count\s+-cne\s+1.*?enabled.*?fully_visible.*?dialog_rendered.*?Get-Value.*?-isnot\s+\[bool\].*?-not\s+\[bool\]' 'Tutorial confirmation selection must require one exact stable-id control with true boolean enabled, fully-visible, and rendered signals.'
    Assert-Match $runner '(?s)function Click-TutorialConfirmationButton.*?Select-UniquePublicTutorialDialogButton.*?tutorial_skip_dialog:\$Role.*?IsNullOrWhiteSpace.*?-cne\s+\$expectedId.*?click_button \$id' 'Tutorial confirmation clicks must use the exact validated stable public id.'
    Assert-Match $runner '(?s)function Reveal-ButtonByVerticalScroll.*?MaximumScrolls\s*=\s*12.*?Select-UniqueFullyVisibleButton.*?Get-PublicScrollSurfaces.*?scroll_surface \$surfaceId \$Direction.*?did not become visible within' 'Run-menu reveal must require a fully visible target, use bounded public semantic scroll inputs, and fail closed.'
    Assert-NotMatch $runner '\$null\s+-eq\s+\(Find-Button\s+-Text\s+''Skip Lessons''\)' 'The tutorial route must not demand an already visible Skip Lessons button before semantic scrolling can reveal it.'
    Assert-NotMatch $runner '(?:Find-Button|Click-Button)\s+-Text\s+''OK''' 'The tutorial confirmation route must not select the generic OK label.'
    Assert-Match $bridge '(?s)func _scroll_surface\(argument: String\).*?surface_id != "run_menu".*?direction not in \["up", "down"\].*?surface\.get\(capability, false\).*?_push_mouse_wheel.*?after <= before.*?after >= before' 'The bridge semantic scroll command must allow only rendered public run-menu capabilities and verify real wheel movement.'
    Assert-Match $bridge '(?s)func _click_button\(target: String\).*?fully_visible.*?button became hidden, clipped, or disabled before click' 'The bridge must re-check that a semantic button is fully visible immediately before clicking it.'
    Assert-Match $bridge '(?s)func _click_button\(target: String\).*?_button_input_route\(data, button, click_position\).*?input_viewport\s*==\s*null.*?TYPE_VECTOR2.*?missing, changed, or ambiguous.*?_push_mouse_click_in_viewport\(input_viewport, input_position, false\)' 'Every semantic button click must fail closed on a stale input route and use its exact physical viewport coordinate.'
    Assert-Match $bridge '(?s)func _button_input_route\(data: Dictionary, button: Button, local_position: Vector2\).*?input_viewport_candidates.*?viewport_candidates\.size\(\)\s*!=\s*1.*?viewport_candidates\[0\]\s+as\s+Viewport.*?button\.get_viewport\(\).*?recorded_viewport\s*!=\s*live_viewport.*?recorded_viewport\s*==\s*root_viewport.*?tutorial_skip_dialog.*?dialog\.is_embedded\(\).*?dialog\.get_ok_button\(\).*?dialog\.get_cancel_button\(\).*?tutorial_skip_dialog:%s.*?button\s*!=\s*expected_button.*?data\.get\("id".*?expected_id.*?var\s+dialog_parent:\s*Node\s*=\s*dialog\.get_parent\(\).*?dialog_parent\s*==\s*null.*?dialog_parent\s*!=\s*app.*?var\s+embedder_viewport:\s*Viewport\s*=\s*dialog_parent\.get_viewport\(\).*?embedder_viewport\s*!=\s*root_viewport.*?Vector2\(dialog\.position\)\s*\+\s*local_position' 'Button input routing must keep root controls unchanged, require the exact application parent and its explicitly typed Viewport, and admit only the exact embedded tutorial dialog controls translated into root embedder coordinates.'
    Assert-NotMatch $bridge 'dialog\.get_parent_viewport\(' 'ConfirmationDialog must not call the nonexistent get_parent_viewport API.'
    Assert-Match $bridge '(?s)func _push_mouse_click\(position: Vector2, double_click: bool\).*?_push_mouse_click_in_viewport\(app\.get_viewport\(\), position, double_click\).*?func _push_mouse_click_in_viewport\(viewport: Viewport.*?viewport\.push_input\(motion, true\).*?viewport\.push_input\(press, true\).*?viewport\.push_input\(release, true\)' 'Ordinary clicks and translated embedded-dialog clicks must retain the same physical motion, press, and release sequence through the root embedder viewport.'
    Assert-Match $bridge '(?s)func _collect_buttons\(node: Node, result: Array\).*?full_rect\s*:=\s*button\.get_global_rect\(\).*?visible_rect\s*:=\s*_clipped_control_rect\(button\).*?"fully_visible":\s*_rect_encloses_with_tolerance\(visible_rect, full_rect\)' 'The bridge must derive fully-visible button state by comparing the full global rect with the clipped visible rect.'
    Assert-Match $bridge '(?s)func _append_tutorial_confirmation_buttons\(result: Array\).*?app\.get\("tutorial_skip_dialog"\) as ConfirmationDialog.*?dialog\s*==\s*null.*?not\s+dialog\.visible.*?dialog\.size\.x\s*<=\s*0.*?dialog\.size\.y\s*<=\s*0.*?dialog\.get_ok_button\(\).*?tutorial_skip_dialog:ok.*?dialog\.get_cancel_button\(\).*?tutorial_skip_dialog:cancel.*?button\.disabled.*?button\.is_visible_in_tree\(\).*?_clipped_control_rect\(button\).*?visible_rect\.has_area\(\).*?"fully_visible":\s*_rect_encloses_with_tolerance\(visible_rect, full_rect\).*?"dialog_rendered":\s*true' 'The bridge may expose only the rendered, enabled, fully measured tutorial confirmation OK/Cancel controls under exact stable ids.'
    Assert-NotMatch $bridge '_control_is_rendered\(dialog\)' 'ConfirmationDialog is a Window, so the bridge must not pass it to the Control-only rendered helper.'
    Assert-Match $bridge '(?s)func _clipped_control_rect\(control: Control\).*?control\.get_viewport\(\).*?viewport\s*==\s*null.*?control\.get_global_rect\(\)\.intersection\(viewport\.get_visible_rect\(\)\)' 'Control visibility and click coordinates must be clipped in the exact control viewport coordinate space.'
    Assert-NotMatch $bridge 'get_children\(true\)' 'The bridge must not broadly enumerate internal controls; only the tutorial confirmation whitelist is admissible.'
    Assert-NotMatch $bridge '\.scroll_vertical\s*=' 'The replay bridge must not inject scroll-container state directly.'
    Assert-Match $runner '(?s)function Visit-CageAndClaimReadyPlayersCard.*?cage_claim_card.*?claimMatches\.Count\s+-cne\s+1.*?claimEnabled\s+-isnot\s+\[bool\].*?bronze.*?silver.*?gold' 'Clean-ending progress must use Linda''s unique rendered claim control and exact visible tier recognition sequence.'
    Assert-Contains $runner 'Stop-Process -Id $script:OwnedSessionPid -Force -ErrorAction Stop' 'Failure cleanup may force-stop only the exact recorded session-owned Godot PID.'
    Assert-Contains $runner '$actualStartUtcTicks -cne $script:OwnedSessionStartUtcTicks' 'Failure cleanup must verify process start identity before force-stop.'
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
    Assert-Match $sanitizer '(?s)static func _talk\(.*?typewriter_active.*?typeof\(typewriter_value\) == TYPE_BOOL' 'Public TalkDock observation must retain its exact visible typewriter-state witness while rejecting non-boolean values.'
    Assert-Match $runner '(?s)function Invoke-VisibleCheatIfAvailable.*?Select-CheatReplayBlackjackCheatAction.*?''open_window''.*?blackjack_distraction.*?peek_window_open.*?''peek''.*?blackjack_peek.*?dealer_hole_visible' 'Cheat replay must bind published peek_hole_card policy to the rendered Distraction -> open window -> Peek sequence and exact public completion witness.'
    Assert-NotMatch $runner '\$preferred\s*=\s*@\(''blackjack_distraction'',\s*''blackjack_peek''\)' 'Cheat replay must not return after the old control-id preference loop before performing Peek.'
    Assert-Match $replayPolicy '(?s)function Select-CheatReplayBlackjackCheatAction.*?''peek_hole_card''.*?''blackjack_distraction''.*?''blackjack_peek''' 'Cheat replay policy must distinguish the published semantic cheat id from the two rendered control ids.'
    Assert-Match $runner '(?s)function Invoke-PublicBossCalloutIfShown.*?Select-CheatReplayBossCalloutAction.*?stage\s+-cne\s+''call''.*?blackjack_boss_callout.*?boss_callout_used' 'Rourke replay must defer through the public policy and verify a post-deal rendered callout witness.'
    Assert-Match $runner '(?s)function Resolve-ShowdownChoiceSurface.*?Select-CheatReplayShowdownWalkChoice.*?keep_everything.*?hand_to_crew__.*?trash' 'Showdown walk must use the public classified-item policy instead of blindly keeping every inventory.'
    Assert-Match $replayPolicy '(?s)function Select-CheatReplayShowdownWalkChoice.*?marked_cards.*?foil_sleeve.*?weighted_keyring.*?xray_glasses.*?tab_detector.*?tarot_card.*?multiple classified items' 'Showdown walk policy must fail closed when its one pocket change cannot remove every classified item.'
    Assert-Contains $runner "Invoke-GameAction -Action 'blackjack_boss_callout' -Index `$index" 'Rourke callouts must click the matching rendered indexed control.'
    Assert-Contains $runner "@('game', 'boss_hand_number') 0) -cne 1" 'Rourke persistence must recognize the publicly numbered first hand.'
    Assert-Match $runner '(?s)function Assert-VisibleTalkChoiceConfirmation.*?render_valid.*?eventId.*?-cne\s+\$ExpectedEventId.*?Confirm:\s+\$OriginalLabel.*?label.*?-cne\s+\$expectedConfirmLabel.*?function Choose-VisibleChoice.*?Assert-VisibleTalkChoiceConfirmation' 'Replay choices must bind the second press to the same fully rendered TalkDock event and exact Confirm label.'
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
        if (-not [bool]$scrollReport.passed -or [int]$scrollReport.hostile_fixtures -cne 10) {
            Add-Failure 'Semantic scroll hostile regression did not pass all ten fail-closed fixtures.'
        }
        if ([int]$scrollReport.hostile_button_fixtures -cne 6) {
            Add-Failure 'Semantic scroll hostile regression did not pass all six fully-visible button fixtures.'
        }
        if ([int]$scrollReport.valid_dialog_fixtures -cne 2 -or [int]$scrollReport.hostile_dialog_fixtures -cne 8) {
            Add-Failure 'Tutorial confirmation regression did not pass both exact controls and all eight fail-closed fixtures.'
        }
        if ([int]$scrollReport.valid_confirmation_fixtures -cne 1 -or [int]$scrollReport.hostile_confirmation_fixtures -cne 5) {
            Add-Failure 'TalkDock confirmation regression did not pass its exact valid case and five cross-modal/schema hostiles.'
        }
        if ([int]$scrollReport.valid_canvas_object_fixtures -cne 2 -or [int]$scrollReport.hostile_canvas_object_fixtures -cne 6) {
            Add-Failure 'Canvas-object regression did not pass both exact selection cases and six rendered/schema hostiles.'
        }
        if ([int]$scrollReport.valid_room_action_fixtures -cne 1 -or [int]$scrollReport.hostile_room_action_fixtures -cne 6) {
            Add-Failure 'Room-action regression did not pass its exact binding and six duplicate/order/render/selection hostiles.'
        }
        if ([int]$scrollReport.valid_save_acknowledgment_fixtures -cne 1 -or [int]$scrollReport.hostile_save_acknowledgment_fixtures -cne 5) {
            Add-Failure 'Save acknowledgment regression did not pass its exact witness and five type/case hostiles.'
        }
        if ([int]$scrollReport.valid_terminal_fixtures -cne 1 -or [int]$scrollReport.hostile_terminal_fixtures -cne 4) {
            Add-Failure 'Terminal regression did not pass its exact valid case and four type/case hostiles.'
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
    machine_jam_valid_fixtures = $machineJamValidFixtures
    machine_jam_hostile_fixtures = $machineJamHostileFixtures
    grand_fare_funding_valid_fixtures = $grandFareFundingValidFixtures
    grand_fare_funding_hostile_fixtures = $grandFareFundingHostileFixtures
    grand_fare_cash_event_valid_fixtures = $grandFareCashEventValidFixtures
    grand_fare_cash_event_hostile_fixtures = $grandFareCashEventHostileFixtures
    command_open_valid_fixtures = $commandOpenValidFixtures
    command_open_hostile_fixtures = $commandOpenHostileFixtures
    cheat_blackjack_valid_fixtures = $cheatBlackjackValidFixtures
    cheat_blackjack_hostile_fixtures = $cheatBlackjackHostileFixtures
    cheat_boss_callout_valid_fixtures = $cheatBossCalloutValidFixtures
    cheat_boss_callout_hostile_fixtures = $cheatBossCalloutHostileFixtures
    cheat_showdown_walk_valid_fixtures = $cheatShowdownWalkValidFixtures
    cheat_showdown_walk_hostile_fixtures = $cheatShowdownWalkHostileFixtures
    cheat_duel_continuation_valid_fixtures = $cheatDuelContinuationValidFixtures
    cheat_duel_continuation_hostile_fixtures = $cheatDuelContinuationHostileFixtures
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
