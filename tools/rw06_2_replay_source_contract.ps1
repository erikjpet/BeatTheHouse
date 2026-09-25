[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Worktree = Split-Path -Parent $PSScriptRoot
$RunnerPath = Join-Path $PSScriptRoot 'rw06_2_ending_replay.ps1'
$ReplayPolicyPath = Join-Path $PSScriptRoot 'rw06_2_replay_policies.ps1'
$EvidenceAdmissionPath = Join-Path $PSScriptRoot 'rw06_2_evidence_admission.ps1'
$EvidenceAdmissionContractPath = Join-Path $PSScriptRoot 'rw06_2_evidence_admission_contract.ps1'
$HeistSeedPreflightPath = Join-Path $PSScriptRoot 'rw06_2_heist_seed_preflight.ps1'
$FinalEvidencePath = Join-Path $PSScriptRoot 'rw06_2_final_evidence.ps1'
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
$RunActionServicePath = Join-Path $Worktree 'scripts\core\run_action_service.gd'
$CrewRunFacadePath = Join-Path $Worktree 'scripts\core\crew_run_facade.gd'
$WorldMapPath = Join-Path $Worktree 'scripts\core\world_map.gd'
$FoundationWorldTestPath = Join-Path $Worktree 'scripts\tests\foundation\check_items_events_world.gd'
$CrewHeistTestPath = Join-Path $Worktree 'scripts\tests\foundation\crew_heist_contract.gd'
$UiMainFlowTestPath = Join-Path $Worktree 'scripts\tests\ui_scene\compile_components_and_main_flow.gd'
$EventsPath = Join-Path $Worktree 'data\events\events.json'
$ServicesPath = Join-Path $Worktree 'data\services\services.json'
$ArchetypesPath = Join-Path $Worktree 'data\environments\archetypes.json'
$ReportPath = Join-Path $Worktree '.tmp\rw06_2\replay_source_contract.json'
$SemanticScrollReportPath = Join-Path $Worktree '.tmp\rw06_2\semantic_scroll_contract.json'
$EvidenceAdmissionReportPath = Join-Path $Worktree '.tmp\rw06_2\evidence_admission_contract.json'

$failures = [Collections.Generic.List[string]]::new()
$wheelSequenceValidFixtures = 0
$wheelSequenceHostileFixtures = 0
$buttonViewportValidFixtures = 0
$buttonViewportHostileFixtures = 0
$grandArrivalGreetingValidFixtures = 0
$grandArrivalGreetingHostileFixtures = 0
$machineJamValidFixtures = 0
$machineJamHostileFixtures = 0
$deltaQueenBeachValidFixtures = 0
$deltaQueenBeachHostileFixtures = 0
$grandFareFundingValidFixtures = 0
$grandFareFundingHostileFixtures = 0
$grandFareCashEventValidFixtures = 0
$grandFareCashEventHostileFixtures = 0
$commandOpenValidFixtures = 0
$commandOpenHostileFixtures = 0
$cheatDuelCheckpointValidFixtures = 0
$cheatDuelCheckpointHostileFixtures = 0
$cheatBlackjackValidFixtures = 0
$cheatBlackjackHostileFixtures = 0
$cheatPostPeekValidFixtures = 0
$cheatPostPeekHostileFixtures = 0
$cheatBossCalloutValidFixtures = 0
$cheatBossCalloutHostileFixtures = 0
$cheatInterrogationValidFixtures = 0
$cheatInterrogationHostileFixtures = 0
$cheatShowdownWalkValidFixtures = 0
$cheatShowdownWalkHostileFixtures = 0
$cheatDuelContinuationValidFixtures = 0
$cheatDuelContinuationHostileFixtures = 0
$heistSeedValidFixtures = 0
$heistSeedHostileFixtures = 0
$heistSeedReportSchemaHostileFixtures = 0
$heistLaunchSetupValidFixtures = 0
$heistLaunchSetupHostileFixtures = 0
$heistAuditHookValidFixtures = 0
$heistAuditHookHostileFixtures = 0
$heistConventionHookValidFixtures = 0
$heistConventionHookHostileFixtures = 0
$persistenceCheckpointValidFixtures = 0
$persistenceCheckpointHostileFixtures = 0
$directQualificationValidFixtures = 0
$directQualificationHostileFixtures = 0
$evidenceAdmissionValidFixtures = 0
$evidenceAdmissionHostileFixtures = 0
$evidenceAdmissionReportSchemaHostileFixtures = 0
$bridgeExactTypeValidFixtures = 0
$bridgeExactTypeHostileFixtures = 0
$semanticReportSchemaValidFixtures = 0
$semanticReportSchemaHostileFixtures = 0

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

function New-GrandArrivalGreetingPolicyFixture {
    param([switch]$WithHiddenSentinels)

    $fixture = [pscustomobject]@{
        event_popup = [pscustomobject]@{ visible = $false }
        talk = [pscustomobject]@{
            visible = $true
            expanded = $true
            render_valid = $true
            body_complete = $true
            typewriter_active = $false
            event_id = 'dialogue:normal_grand_host_greeting'
            summary = "Welcome to the Grand. I'm Vivienne, your host. The floor is yours."
            choice_ids = @('continue')
        }
        talk_choices = @(
            [pscustomobject]@{
                event_id = 'dialogue:normal_grand_host_greeting'
                id = 'continue'
                label = 'Enter the floor'
                enabled = $true
            }
        )
    }
    if ($WithHiddenSentinels) {
        $fixture.talk | Add-Member -NotePropertyName private_dialogue_state -NotePropertyValue 'HIDDEN SENTINEL'
        $fixture.talk_choices[0] | Add-Member -NotePropertyName requires_confirm -NotePropertyValue $true
    }
    return $fixture
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
                terms = "Switch: `"Quick deal: our cash, your legs, one future call. Yes or no?`"`nNo interest. Only favors. Borrow `$45. Repay 2 favors (0% cash interest) in 2 turns."
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
                text = '{0} Cash change: +{1}.  $+{1} / Heat +{2}' -f $message, $cashDelta, $heatDelta
            }
        }
    }
}


function New-DeltaQueenBeachPolicyFixture {
    param([switch]$Locked)
    $lockReason = 'The River Queen is out on the river for 2 more actions.'
    return [pscustomobject]@{
        archetype_id = 'delta_queen'
        nodes = @(
            [pscustomobject]@{
                id = 'beach_011'
                archetype_id = 'beach'
                state = 'revealed'
                cost = 0
                travel_target = $true
                travel_enabled = (-not $Locked)
                travel_disabled_reason = if ($Locked) { $lockReason } else { '' }
            },
            [pscustomobject]@{
                id = 'motel_004'
                archetype_id = 'motel'
                state = 'visited'
                cost = 6
                travel_enabled = (-not $Locked)
                travel_disabled_reason = if ($Locked) { $lockReason } else { '' }
            },
            [pscustomobject]@{
                id = 'delta_queen_009'
                archetype_id = 'delta_queen'
                state = 'current'
                cost = 0
                travel_enabled = $false
                travel_disabled_reason = 'Already here.'
            }
        )
    }
}


function New-HeistFreshSetupPolicyFixture {
    return [pscustomobject]@{
        screen = [pscustomobject]@{
            screen = 'START'
            start_menu = [pscustomobject]@{
                run_config_visible = $true
                selected_challenge_id = ''
                selected_home_type_id = 'random'
                selected_content_groups = @(
                    'universal_passive_items', 'universal_active_items', 'scratch_tickets_pack',
                    'pull_tabs_pack', 'slot_pack', 'coin_pusher_pack', 'bar_dice_pack',
                    'craps_pack', 'crew_poker_pack', 'blackjack_pack', 'baccarat_pack',
                    'roulette_pack', 'video_poker_pack', 'numbers_pack'
                )
            }
        }
    }
}


function New-HeistAuditHookPolicyFixture {
    return [pscustomobject]@{
        observation = [pscustomobject]@{
            screen = [pscustomobject]@{ screen = 'ENVIRONMENT' }
            environment = [pscustomobject]@{ archetype_id = 'grand_casino' }
        }
        canvas_objects = @(
            [pscustomobject]@{
                semantic_id = 'event:scenario_audit_roster'
                label = 'The Audit Roster'
                object_type = 'event'
                rendered = $true
                enabled = $true
            },
            [pscustomobject]@{
                semantic_id = 'game:blackjack'
                label = 'Blackjack'
                object_type = 'game'
                rendered = $true
                enabled = $true
            }
        )
    }
}


function New-HeistConventionHookPolicyFixture {
    return [pscustomobject]@{
        observation = [pscustomobject]@{
            screen = [pscustomobject]@{ screen = 'ENVIRONMENT' }
            environment = [pscustomobject]@{ archetype_id = 'grand_casino' }
        }
        canvas_objects = @(
            [pscustomobject]@{
                semantic_id = 'event:scenario_convention_badge'
                label = 'Borrowed Badge'
                object_type = 'event'
                rendered = $true
                enabled = $true
            },
            [pscustomobject]@{
                semantic_id = 'game:blackjack'
                label = 'Blackjack'
                object_type = 'game'
                rendered = $true
                enabled = $true
            }
        )
    }
}


function Get-GDScriptFunctionSource {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Name
    )
    $escapedName = [regex]::Escape($Name)
    $functionMatch = [regex]::Match(
        $Source,
        "(?ms)^(?:static\s+)?func\s+$escapedName\([^\r\n]*\).*?(?=^(?:static\s+)?func\s|\z)"
    )
    if (-not $functionMatch.Success) {
        Add-Failure "Required GDScript function is missing: $Name"
        return ''
    }
    return $functionMatch.Value
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


function New-CheatReplayPostPeekPolicyFixture {
    param([ValidateSet('continue_hand', 'leave_for_showdown')][string]$Stage = 'leave_for_showdown')

    return [pscustomobject]@{
        game = [pscustomobject]@{
            phase = if ($Stage -ceq 'leave_for_showdown') { 'barred' } else { 'decision' }
        }
        status_hud = [pscustomobject]@{
            heat_rendered = $true
            heat_level = if ($Stage -ceq 'leave_for_showdown') { 90 } else { 66 }
        }
        surface_actions = @(
            [pscustomobject]@{ action = 'surface_back'; index = -1; enabled = $true },
            [pscustomobject]@{ action = 'blackjack_stand'; index = 0; enabled = ($Stage -ceq 'continue_hand') }
        )
        expected_stage = $Stage
    }
}


function ConvertTo-PowerShellAnalysis {
    param([Parameter(Mandatory = $true)][string]$Source)
    $tokens = $null
    $parseErrors = $null
    $ast = [Management.Automation.Language.Parser]::ParseInput($Source, [ref]$tokens, [ref]$parseErrors)
    return [pscustomobject][ordered]@{
        source = $Source
        ast = $ast
        parse_errors = @($parseErrors)
    }
}


function Get-PowerShellFunctionAst {
    param(
        [Parameter(Mandatory = $true)]$Analysis,
        [Parameter(Mandatory = $true)][string]$Name
    )
    $matches = @($Analysis.ast.FindAll({
        param($node)
        $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq $Name
    }, $true))
    if ($matches.Count -cne 1) { return $null }
    return $matches[0]
}


function Get-PowerShellFunctionSource {
    param(
        [Parameter(Mandatory = $true)]$Analysis,
        [Parameter(Mandatory = $true)][string]$Name
    )
    $functionAst = Get-PowerShellFunctionAst -Analysis $Analysis -Name $Name
    if ($null -ceq $functionAst) { return '' }
    return [string]$functionAst.Extent.Text
}


function Get-PowerShellTopLevelSource {
    param([Parameter(Mandatory = $true)]$Analysis)
    return [string]::Join("`n", @($Analysis.ast.EndBlock.Statements | Where-Object {
        $_ -isnot [Management.Automation.Language.FunctionDefinitionAst]
    } | ForEach-Object { $_.Extent.Text }))
}


function Replace-SourceOnce {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Needle,
        [Parameter(Mandatory = $true)][string]$Replacement
    )
    $first = $Source.IndexOf($Needle, [StringComparison]::Ordinal)
    if ($first -lt 0 -or $Source.IndexOf($Needle, $first + $Needle.Length, [StringComparison]::Ordinal) -ge 0) {
        throw "Hostile replay source mutation requires exactly one occurrence: $Needle"
    }
    return $Source.Substring(0, $first) + $Replacement + $Source.Substring($first + $Needle.Length)
}


function Replace-PowerShellFunctionSourceOnce {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$FunctionName,
        [Parameter(Mandatory = $true)][string]$Needle,
        [Parameter(Mandatory = $true)][string]$Replacement
    )
    $analysis = ConvertTo-PowerShellAnalysis -Source $Source
    if ($analysis.parse_errors.Count -cne 0) {
        throw "Hostile replay source mutation could not parse the source for function '$FunctionName'."
    }
    $functionAst = Get-PowerShellFunctionAst -Analysis $analysis -Name $FunctionName
    if ($null -ceq $functionAst) {
        throw "Hostile replay source mutation could not find function '$FunctionName'."
    }
    $functionSource = [string]$functionAst.Extent.Text
    $effectiveNeedle = $Needle
    $effectiveReplacement = $Replacement
    if ($functionSource.IndexOf($effectiveNeedle, [StringComparison]::Ordinal) -lt 0) {
        if ($functionSource.Contains("`r`n")) {
            $effectiveNeedle = $Needle.Replace("`r`n", "`n").Replace("`n", "`r`n")
            $effectiveReplacement = $Replacement.Replace("`r`n", "`n").Replace("`n", "`r`n")
        }
        else {
            $effectiveNeedle = $Needle.Replace("`r`n", "`n")
            $effectiveReplacement = $Replacement.Replace("`r`n", "`n")
        }
    }
    $first = $functionSource.IndexOf($effectiveNeedle, [StringComparison]::Ordinal)
    if ($first -lt 0 -or $functionSource.IndexOf($effectiveNeedle, $first + $effectiveNeedle.Length, [StringComparison]::Ordinal) -ge 0) {
        throw "Hostile replay source mutation requires exactly one occurrence in function '$FunctionName': $Needle"
    }
    $absoluteStart = $functionAst.Extent.StartOffset + $first
    return $Source.Substring(0, $absoluteStart) + $effectiveReplacement + $Source.Substring($absoluteStart + $effectiveNeedle.Length)
}


function Test-ExactGetterBinding {
    param(
        [Parameter(Mandatory = $true)]$FunctionAst,
        [Parameter(Mandatory = $true)][string]$Getter,
        [Parameter(Mandatory = $true)][string]$InputToken,
        [Parameter(Mandatory = $true)][string]$PathToken,
        [string]$ExtraToken = ''
    )
    $matches = @($FunctionAst.FindAll({
        param($node)
        $node -is [Management.Automation.Language.CommandAst] -and $node.GetCommandName() -ceq $Getter
    }, $true) | Where-Object {
        $text = [string]$_.Extent.Text
        $text.IndexOf($InputToken, [StringComparison]::Ordinal) -ge 0 -and
            $text.IndexOf($PathToken, [StringComparison]::Ordinal) -ge 0 -and
            ([string]::IsNullOrEmpty($ExtraToken) -or $text.IndexOf($ExtraToken, [StringComparison]::Ordinal) -ge 0)
    })
    return $matches.Count -ge 1
}


function Get-ExactNamedCommandArguments {
    param([Parameter(Mandatory = $true)]$CommandAst)

    if ($CommandAst -isnot [Management.Automation.Language.CommandAst] -or
        $CommandAst.Redirections.Count -cne 0) {
        return [pscustomobject]@{ valid = $false; arguments = @{} }
    }
    $elements = @($CommandAst.CommandElements)
    if ($elements.Count -lt 2) {
        return [pscustomobject]@{ valid = $false; arguments = @{} }
    }
    $arguments = @{}
    for ($index = 1; $index -lt $elements.Count; $index++) {
        $parameter = $elements[$index]
        if ($parameter -isnot [Management.Automation.Language.CommandParameterAst]) {
            return [pscustomobject]@{ valid = $false; arguments = @{} }
        }
        $name = [string]$parameter.ParameterName
        if ([string]::IsNullOrWhiteSpace($name) -or $arguments.ContainsKey($name)) {
            return [pscustomobject]@{ valid = $false; arguments = @{} }
        }
        $argument = $parameter.Argument
        if ($null -ceq $argument -and
            $index + 1 -lt $elements.Count -and
            $elements[$index + 1] -isnot [Management.Automation.Language.CommandParameterAst]) {
            $index++
            $argument = $elements[$index]
        }
        $arguments[$name] = $argument
    }
    return [pscustomobject]@{ valid = $true; arguments = $arguments }
}


function Test-PowerShellTopLevelStatement {
    param(
        [Parameter(Mandatory = $true)]$FunctionAst,
        [Parameter(Mandatory = $true)]$StatementAst
    )
    return @($FunctionAst.Body.EndBlock.Statements | Where-Object {
        $_.Extent.StartOffset -ceq $StatementAst.Extent.StartOffset -and
        $_.Extent.EndOffset -ceq $StatementAst.Extent.EndOffset
    }).Count -ceq 1
}


function Test-ExactAssignedGetterBinding {
    param(
        [Parameter(Mandatory = $true)]$FunctionAst,
        [Parameter(Mandatory = $true)][string]$TargetVariable,
        [Parameter(Mandatory = $true)][string]$Getter,
        [Parameter(Mandatory = $true)]$ExpectedArguments
    )

    $targetAssignments = @($FunctionAst.FindAll({
        param($node)
        $node -is [Management.Automation.Language.AssignmentStatementAst] -and
            $node.Left -is [Management.Automation.Language.VariableExpressionAst] -and
            $node.Left.VariablePath.UserPath -ceq $TargetVariable
    }, $true))
    if ($TargetVariable -cne 'null' -and $targetAssignments.Count -cne 1) { return $false }

    $matches = @($targetAssignments | Where-Object {
        $assignment = $_
        if (-not (Test-PowerShellTopLevelStatement -FunctionAst $FunctionAst -StatementAst $assignment)) {
            return $false
        }
        $commands = @($assignment.Right.FindAll({
            param($node)
            $node -is [Management.Automation.Language.CommandAst]
        }, $true))
        if ($commands.Count -cne 1 -or $commands[0].GetCommandName() -cne $Getter) { return $false }
        $command = $commands[0]
        if ([string]$assignment.Right.Extent.Text.Trim() -cne [string]$command.Extent.Text.Trim() -or
            @($assignment.Right.FindAll({
                param($node)
                $node -is [Management.Automation.Language.ConvertExpressionAst]
            }, $true)).Count -cne 0) {
            return $false
        }
        $parsed = Get-ExactNamedCommandArguments -CommandAst $command
        if (-not $parsed.valid -or $parsed.arguments.Count -cne $ExpectedArguments.Count) { return $false }
        if (@($parsed.arguments.Keys | Where-Object { $ExpectedArguments.Keys -cnotcontains $_ }).Count -cne 0) {
            return $false
        }
        foreach ($name in $ExpectedArguments.Keys) {
            if (-not $parsed.arguments.ContainsKey([string]$name)) { return $false }
            $actualArgument = $parsed.arguments[[string]$name]
            $expectedText = $ExpectedArguments[$name]
            if ($null -ceq $expectedText) {
                if ($null -cne $actualArgument) { return $false }
            }
            elseif ($null -ceq $actualArgument -or
                [string]$actualArgument.Extent.Text.Trim() -cne [string]$expectedText) {
                return $false
            }
        }
        return $true
    })
    return $matches.Count -ceq 1
}


function Test-NoDirectRetainedObjectAccess {
    param(
        [Parameter(Mandatory = $true)]$FunctionAst,
        [Parameter(Mandatory = $true)][string]$VariableName
    )
    $directReads = @($FunctionAst.FindAll({
        param($node)
        ($node -is [Management.Automation.Language.MemberExpressionAst] -and
            $node.Expression -is [Management.Automation.Language.VariableExpressionAst] -and
            $node.Expression.VariablePath.UserPath -ceq $VariableName) -or
        ($node -is [Management.Automation.Language.IndexExpressionAst] -and
            $node.Target -is [Management.Automation.Language.VariableExpressionAst] -and
            $node.Target.VariablePath.UserPath -ceq $VariableName)
    }, $true))
    return $directReads.Count -ceq 0
}


function Test-ExactKeyClosureCall {
    param(
        [Parameter(Mandatory = $true)]$FunctionAst,
        [Parameter(Mandatory = $true)][string]$ValueExpression,
        [Parameter(Mandatory = $true)][string[]]$ExpectedKeys,
        [Parameter(Mandatory = $true)][string]$ContextExpression
    )

    $commands = @($FunctionAst.FindAll({
        param($node)
        $node -is [Management.Automation.Language.CommandAst] -and
            $node.GetCommandName() -ceq 'Assert-ExactReplayObjectKeys'
    }, $true))
    if ($commands.Count -cne 1) { return $false }
    $command = $commands[0]
    if ($command.Parent -isnot [Management.Automation.Language.PipelineAst] -or
        -not (Test-PowerShellTopLevelStatement -FunctionAst $FunctionAst -StatementAst $command.Parent)) {
        return $false
    }
    $parsed = Get-ExactNamedCommandArguments -CommandAst $command
    if (-not $parsed.valid -or $parsed.arguments.Count -cne 3) { return $false }
    if (@($parsed.arguments.Keys | Where-Object { @('Value', 'ExpectedKeys', 'Context') -cnotcontains $_ }).Count -cne 0) {
        return $false
    }
    foreach ($name in @('Value', 'ExpectedKeys', 'Context')) {
        if (-not $parsed.arguments.ContainsKey($name) -or $null -ceq $parsed.arguments[$name]) { return $false }
    }
    if ([string]$parsed.arguments['Value'].Extent.Text.Trim() -cne $ValueExpression -or
        [string]$parsed.arguments['Context'].Extent.Text.Trim() -cne $ContextExpression -or
        $parsed.arguments['ExpectedKeys'] -isnot [Management.Automation.Language.ArrayExpressionAst]) {
        return $false
    }
    try {
        $actualKeys = @($parsed.arguments['ExpectedKeys'].SafeGetValue())
    }
    catch {
        return $false
    }
    if ($actualKeys.Count -cne $ExpectedKeys.Count) { return $false }
    for ($index = 0; $index -lt $ExpectedKeys.Count; $index++) {
        if ($actualKeys[$index] -isnot [string] -or $actualKeys[$index] -cne $ExpectedKeys[$index]) {
            return $false
        }
    }
    $getterCommands = @($FunctionAst.FindAll({
        param($node)
        $node -is [Management.Automation.Language.CommandAst] -and
            $node.GetCommandName() -cmatch '^Get-ExactReplay'
    }, $true))
    if ($getterCommands.Count -eq 0 -or
        @($getterCommands | Where-Object { $_.Extent.StartOffset -le $command.Extent.StartOffset }).Count -ne 0) {
        return $false
    }
    return $true
}


function Test-HeistRouteExactCommandInventory {
    param([Parameter(Mandatory = $true)][string]$Source)

    $routeSource = [regex]::Match(
        $Source,
        '(?ms)^function\s+Invoke-HeistEndingRoute\s*\{.*?(?=^function |\z)'
    ).Value
    if ([string]::IsNullOrWhiteSpace($routeSource)) { return $false }
    $tokens = $null
    $errors = $null
    $routeAst = [Management.Automation.Language.Parser]::ParseInput(
        $routeSource,
        [ref]$tokens,
        [ref]$errors
    )
    if ($errors.Count -cne 0) { return $false }
    $expected = @(
        'Establish-CrewMarker',
        'Reach-GrandCasino',
        'Restore-EnvironmentSurfaceAfterTravelResult',
        'Observe-RenderedAuditNightHook',
        'Clear-CrewMarkerFavors',
        'Ensure-PunchlineCasinoDiscovered',
        'Recruit-Bishop',
        'Promote-BishopToInnerCircle',
        'Assert-HeistAuditKnowledgeUnderHostileRevisit',
        'Assert-HeistAuditKnowledgeSaveRelaunchContinue',
        'Test-CountPlanLive',
        'Invoke-EventObjectChoice',
        'Close-VisibleChoiceSurface',
        'Complete-CountIdentitySessions',
        'Enter-PunchlineBackRoom',
        'Invoke-EventObjectChoice',
        'Close-VisibleChoiceSurface',
        'Complete-PublicDelivery',
        'Enter-PunchlineBackRoom',
        'Invoke-EventObjectChoice',
        'Close-VisibleChoiceSurface',
        'Complete-PublicDelivery',
        'Enter-PunchlineBackRoom',
        'Test-EventObjectChoiceEnabled',
        'Close-VisibleChoiceSurface',
        'Invoke-EventObjectChoice',
        'Close-VisibleChoiceSurface',
        'Reach-GrandCasino',
        'Enter-GrandRoom',
        'Find-CanvasObject',
        'Invoke-EventObjectChoice',
        'Close-VisibleChoiceSurface',
        'Play-OneBlackjackRound',
        'Leave-GameSurface',
        'Invoke-EventObjectChoice',
        'Close-VisibleChoiceSurface',
        'Complete-PublicDelivery',
        'Wait-Frames',
        'Assert-TerminalOutcome'
    )
    $actual = @($routeAst.FindAll({
        param($node)
        return $node -is [Management.Automation.Language.CommandAst]
    }, $true) | ForEach-Object { $_.GetCommandName() })
    if ($actual.Count -cne $expected.Count) { return $false }
    for ($index = 0; $index -lt $expected.Count; $index++) {
        if ($actual[$index] -cne $expected[$index]) { return $false }
    }
    return $true
}


function Get-ExactContractPropertyValue {
    param(
        [AllowNull()]$InputObject,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Context
    )
    if ($InputObject -isnot [System.Management.Automation.PSCustomObject]) {
        throw "$Context must be an exact JSON object."
    }
    $properties = @($InputObject.PSObject.Properties | Where-Object { $_.Name -ceq $Name })
    if ($properties.Count -cne 1) {
        throw "$Context must contain exactly one case-sensitive '$Name' property."
    }
    Write-Output -NoEnumerate $properties[0].Value
}


function ConvertTo-ContractClone {
    param([Parameter(Mandatory = $true)]$InputObject)
    $clone = $InputObject | ConvertTo-Json -Depth 40 -Compress | ConvertFrom-Json
    Write-Output -NoEnumerate $clone
}


function Assert-ExactContractObjectKeys {
    param(
        [AllowNull()]$Value,
        [Parameter(Mandatory = $true)][string[]]$ExpectedKeys,
        [Parameter(Mandatory = $true)][string]$Context
    )
    if ($Value -isnot [System.Management.Automation.PSCustomObject]) {
        throw "$Context must be an exact JSON object."
    }
    $actualKeys = @($Value.PSObject.Properties | ForEach-Object { $_.Name })
    if ($actualKeys.Count -cne $ExpectedKeys.Count) {
        throw "$Context has $($actualKeys.Count) properties instead of $($ExpectedKeys.Count)."
    }
    for ($index = 0; $index -lt $ExpectedKeys.Count; $index++) {
        if ($actualKeys[$index] -cne $ExpectedKeys[$index]) {
            throw "$Context property $index must be '$($ExpectedKeys[$index])'."
        }
    }
}


function Get-ContractMutationPathValueNoEnumerate {
    param(
        [AllowNull()]$Root,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Path
    )
    $current = $Root
    foreach ($segment in $Path) {
        if ($segment -is [int32]) {
            if ($current -isnot [Array] -or $segment -lt 0 -or $segment -ge $current.Count) {
                throw "Contract mutation path has no array index '$segment'."
            }
            $current = $current[[int]$segment]
            continue
        }
        if ($segment -isnot [string] -or $current -isnot [System.Management.Automation.PSCustomObject]) {
            throw 'Contract mutation path traverses a non-object value.'
        }
        $current = Get-ExactContractPropertyValue `
            -InputObject $current `
            -Name $segment `
            -Context 'Contract mutation path'
    }
    Write-Output -NoEnumerate $current
}


function Set-ContractMutationPathValue {
    param(
        [Parameter(Mandatory = $true)]$Root,
        [Parameter(Mandatory = $true)][object[]]$Path,
        [AllowNull()]$Value
    )
    if ($Path.Count -ceq 0) { throw 'Contract mutation root replacement must be explicit.' }
    [object[]]$parentPath = [object[]]::new(0)
    if ($Path.Count -gt 1) {
        $parentPath = [object[]]@($Path[0..($Path.Count - 2)])
    }
    $parent = Get-ContractMutationPathValueNoEnumerate -Root $Root -Path $parentPath
    $leaf = $Path[$Path.Count - 1]
    if ($leaf -is [int32]) {
        if ($parent -isnot [Array] -or $leaf -lt 0 -or $leaf -ge $parent.Count) {
            throw "Contract mutation path has no writable array index '$leaf'."
        }
        $parent[[int]$leaf] = $Value
        return
    }
    if ($leaf -isnot [string] -or $parent -isnot [System.Management.Automation.PSCustomObject]) {
        throw 'Contract mutation path has no writable object property.'
    }
    $properties = @($parent.PSObject.Properties | Where-Object { $_.Name -ceq $leaf })
    if ($properties.Count -cne 1) { throw "Contract mutation path has no exact writable property '$leaf'." }
    $properties[0].Value = $Value
}


function Remove-ContractMutationPathProperty {
    param(
        [Parameter(Mandatory = $true)]$Root,
        [Parameter(Mandatory = $true)][object[]]$Path
    )
    if ($Path.Count -ceq 0 -or $Path[$Path.Count - 1] -isnot [string]) {
        throw 'Contract mutation removal requires a non-root object property.'
    }
    [object[]]$parentPath = [object[]]::new(0)
    if ($Path.Count -gt 1) {
        $parentPath = [object[]]@($Path[0..($Path.Count - 2)])
    }
    $parent = Get-ContractMutationPathValueNoEnumerate -Root $Root -Path $parentPath
    if ($parent -isnot [System.Management.Automation.PSCustomObject]) {
        throw 'Contract mutation removal parent is not an exact object.'
    }
    $parent.PSObject.Properties.Remove([string]$Path[$Path.Count - 1])
}


function Format-ContractMutationPath {
    param([Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Path)
    if ($Path.Count -ceq 0) { return '<root>' }
    return (($Path | ForEach-Object {
        if ($_ -is [int32]) { "[$_]" } else { [string]$_ }
    }) -join '.')
}


function Add-UniversalContractSchemaHostiles {
    param(
        [Parameter(Mandatory = $true)]$ValidRoot,
        [AllowNull()]$Node,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Path,
        [Parameter(Mandatory = $true)][Collections.Generic.List[object]]$Cases,
        [Parameter(Mandatory = $true)][string]$Prefix
    )
    $pathLabel = Format-ContractMutationPath -Path $Path
    if ($Node -is [System.Management.Automation.PSCustomObject]) {
        $extraClone = ConvertTo-ContractClone -InputObject $ValidRoot
        $extraTarget = Get-ContractMutationPathValueNoEnumerate -Root $extraClone -Path $Path
        $extraTarget | Add-Member -NotePropertyName authority_override -NotePropertyValue 'hostile'
        $Cases.Add([pscustomobject]@{ name = "$Prefix $pathLabel extra authority key"; value = $extraClone })
        if ($Path.Count -gt 0) {
            foreach ($replacement in @(
                [pscustomobject]@{ suffix = 'null object'; value = $null },
                [pscustomobject]@{ suffix = 'scalar object'; value = 'hostile' },
                [pscustomobject]@{ suffix = 'array object'; value = [object[]]@([pscustomobject]@{}) },
                [pscustomobject]@{ suffix = 'empty object'; value = [pscustomobject]@{} }
            )) {
                $clone = ConvertTo-ContractClone -InputObject $ValidRoot
                Set-ContractMutationPathValue -Root $clone -Path $Path -Value $replacement.value
                $Cases.Add([pscustomobject]@{ name = "$Prefix $pathLabel $($replacement.suffix)"; value = $clone })
            }
        }
        foreach ($property in @($Node.PSObject.Properties)) {
            $childPath = [object[]]@($Path + [object[]]@([string]$property.Name))
            $clone = ConvertTo-ContractClone -InputObject $ValidRoot
            Remove-ContractMutationPathProperty -Root $clone -Path $childPath
            $Cases.Add([pscustomobject]@{
                name = "$Prefix $(Format-ContractMutationPath -Path $childPath) missing"
                value = $clone
            })
            Add-UniversalContractSchemaHostiles `
                -ValidRoot $ValidRoot `
                -Node $property.Value `
                -Path $childPath `
                -Cases $Cases `
                -Prefix $Prefix
        }
        return
    }
    if ($Node -is [Array]) {
        foreach ($replacement in @(
            [pscustomobject]@{ suffix = 'null array'; value = $null },
            [pscustomobject]@{ suffix = 'scalar array'; value = 'hostile' },
            [pscustomobject]@{ suffix = 'object array'; value = [pscustomobject]@{} },
            [pscustomobject]@{ suffix = 'nested array'; value = [object[]]@(,([object[]]@('hostile'))) }
        )) {
            $clone = ConvertTo-ContractClone -InputObject $ValidRoot
            Set-ContractMutationPathValue -Root $clone -Path $Path -Value $replacement.value
            $Cases.Add([pscustomobject]@{ name = "$Prefix $pathLabel $($replacement.suffix)"; value = $clone })
        }
        $countClone = ConvertTo-ContractClone -InputObject $ValidRoot
        $countValue = Get-ContractMutationPathValueNoEnumerate -Root $countClone -Path $Path
        [object[]]$countReplacement = [object[]]::new(0)
        if ($countValue.Count -ceq 0) {
            $countReplacement = [object[]]@('hostile')
        }
        elseif ($countValue.Count -gt 1) {
            $countReplacement = [object[]]@($countValue[0..($countValue.Count - 2)])
        }
        Set-ContractMutationPathValue -Root $countClone -Path $Path -Value $countReplacement
        $Cases.Add([pscustomobject]@{ name = "$Prefix $pathLabel count drift"; value = $countClone })
        if ($Node.Count -gt 0) {
            $elementClone = ConvertTo-ContractClone -InputObject $ValidRoot
            $elementValue = Get-ContractMutationPathValueNoEnumerate -Root $elementClone -Path $Path
            $elementValue[0] = if ($Node[0] -is [string]) { [pscustomobject]@{} } else { 'hostile' }
            $Cases.Add([pscustomobject]@{ name = "$Prefix $pathLabel wrong element"; value = $elementClone })
        }
        if ($Node.Count -gt 1) {
            $orderClone = ConvertTo-ContractClone -InputObject $ValidRoot
            $orderValue = Get-ContractMutationPathValueNoEnumerate -Root $orderClone -Path $Path
            $temporary = $orderValue[0]
            $orderValue[0] = $orderValue[1]
            $orderValue[1] = $temporary
            $Cases.Add([pscustomobject]@{ name = "$Prefix $pathLabel order drift"; value = $orderClone })
        }
        for ($index = 0; $index -lt $Node.Count; $index++) {
            if ($Node[$index] -is [System.Management.Automation.PSCustomObject]) {
                Add-UniversalContractSchemaHostiles `
                    -ValidRoot $ValidRoot `
                    -Node $Node[$index] `
                    -Path ([object[]]@($Path + [object[]]@([int32]$index))) `
                    -Cases $Cases `
                    -Prefix $Prefix
            }
        }
        return
    }
    $replacements = if ($null -ceq $Node) {
        @(
            [pscustomobject]@{ suffix = 'null expected object'; value = [pscustomobject]@{} },
            [pscustomobject]@{ suffix = 'null expected array'; value = [object[]]@('hostile') },
            [pscustomobject]@{ suffix = 'null expected string'; value = 'hostile' },
            [pscustomobject]@{ suffix = 'null expected boolean'; value = $false }
        )
    }
    else {
        $wrongScalar = if ($Node -is [string]) { [int32]7 }
        elseif ($Node -is [bool]) { 'true' }
        elseif ($Node -is [int32] -or $Node -is [int64]) { [double]([int64]$Node + 0.5) }
        elseif ($Node -is [double] -or $Node -is [decimal]) { '1.0' }
        else { 'hostile' }
        @(
            [pscustomobject]@{ suffix = 'null scalar'; value = $null },
            [pscustomobject]@{ suffix = 'object scalar'; value = [pscustomobject]@{ value = $Node } },
            [pscustomobject]@{ suffix = 'one-element array scalar'; value = [object[]]@($Node) },
            [pscustomobject]@{ suffix = 'wrong scalar type'; value = $wrongScalar }
        )
    }
    foreach ($replacement in $replacements) {
        $clone = ConvertTo-ContractClone -InputObject $ValidRoot
        Set-ContractMutationPathValue -Root $clone -Path $Path -Value $replacement.value
        $Cases.Add([pscustomobject]@{ name = "$Prefix $pathLabel $($replacement.suffix)"; value = $clone })
    }
}


function Get-UniversalContractSchemaHostiles {
    param(
        [Parameter(Mandatory = $true)]$ValidRoot,
        [Parameter(Mandatory = $true)][string]$Prefix
    )
    $cases = [Collections.Generic.List[object]]::new()
    foreach ($fixture in @(
        [pscustomobject]@{ name = "$Prefix root null"; value = $null },
        [pscustomobject]@{ name = "$Prefix root scalar"; value = 'hostile' },
        [pscustomobject]@{ name = "$Prefix root array"; value = [object[]]@($ValidRoot) },
        [pscustomobject]@{ name = "$Prefix root empty object"; value = [pscustomobject]@{} }
    )) {
        $cases.Add($fixture)
    }
    Add-UniversalContractSchemaHostiles `
        -ValidRoot $ValidRoot `
        -Node $ValidRoot `
        -Path ([object[]]@()) `
        -Cases $cases `
        -Prefix $Prefix
    return $cases.ToArray()
}


function Assert-ExactHeistSeedSelectionReport {
    param(
        [AllowNull()]$Selection,
        [Parameter(Mandatory = $true)][string]$Context,
        [Parameter(Mandatory = $true)][string]$ExpectedSeed,
        [Parameter(Mandatory = $true)][string]$ExpectedChallengeKey,
        [Parameter(Mandatory = $true)][int32]$ExpectedRunSeed,
        [Parameter(Mandatory = $true)][string]$ExpectedCycleId,
        [Parameter(Mandatory = $true)][string]$ExpectedStreamKey,
        [Parameter(Mandatory = $true)][int32]$ExpectedStreamSeed,
        [Parameter(Mandatory = $true)][int32]$ExpectedNoneRoll,
        [Parameter(Mandatory = $true)][int32]$ExpectedAbsoluteMinutes,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$ExpectedRecentScenarioIds,
        [Parameter(Mandatory = $true)][object[]]$ExpectedWeightedEntries,
        [Parameter(Mandatory = $true)][int32]$ExpectedTotalWeight,
        [Parameter(Mandatory = $true)][int32]$ExpectedWeightedRoll,
        [Parameter(Mandatory = $true)][string]$ExpectedSelectedScenario
    )
    Assert-ExactContractObjectKeys -Value $Selection -ExpectedKeys @(
        'seed_text', 'challenge_key', 'run_seed', 'cycle_id', 'stream_key', 'stream_seed',
        'none_roll', 'none_percent', 'absolute_minutes', 'recent_scenario_ids',
        'town_multiplier', 'weighted_entries', 'total_weight', 'weighted_roll', 'selected_scenario'
    ) -Context $Context
    $values = [ordered]@{}
    foreach ($name in @(
        'seed_text', 'challenge_key', 'run_seed', 'cycle_id', 'stream_key', 'stream_seed',
        'none_roll', 'none_percent', 'absolute_minutes', 'recent_scenario_ids',
        'town_multiplier', 'weighted_entries', 'total_weight', 'weighted_roll', 'selected_scenario'
    )) {
        $values[$name] = Get-ExactContractPropertyValue -InputObject $Selection -Name $name -Context $Context
    }
    foreach ($name in @('seed_text', 'challenge_key', 'cycle_id', 'stream_key', 'selected_scenario')) {
        if ($values[$name] -isnot [string]) { throw "$Context field '$name' must be an exact string." }
    }
    foreach ($name in @(
        'run_seed', 'stream_seed', 'none_roll', 'none_percent', 'absolute_minutes',
        'town_multiplier', 'total_weight', 'weighted_roll'
    )) {
        if ($values[$name] -isnot [int32]) { throw "$Context field '$name' must be an exact Int32." }
    }
    foreach ($name in @('recent_scenario_ids', 'weighted_entries')) {
        if ($values[$name] -isnot [object[]]) { throw "$Context field '$name' must be an exact JSON array." }
    }
    foreach ($item in @($values['recent_scenario_ids'])) {
        if ($item -isnot [string]) { throw "$Context recent_scenario_ids must contain only exact strings." }
    }
    $actualEntryValues = [Collections.Generic.List[object]]::new()
    for ($entryIndex = 0; $entryIndex -lt $values['weighted_entries'].Count; $entryIndex++) {
        $entry = $values['weighted_entries'][$entryIndex]
        $entryContext = "$Context weighted_entries[$entryIndex]"
        Assert-ExactContractObjectKeys -Value $entry -ExpectedKeys @(
            'id', 'repeat_multiplier', 'town_multiplier', 'scaled_weight', 'ceiling'
        ) -Context $entryContext
        $entryValues = [ordered]@{}
        foreach ($name in @('id', 'repeat_multiplier', 'town_multiplier', 'scaled_weight', 'ceiling')) {
            $entryValues[$name] = Get-ExactContractPropertyValue -InputObject $entry -Name $name -Context $entryContext
        }
        if ($entryValues['id'] -isnot [string]) { throw "$entryContext id must be an exact string." }
        foreach ($name in @('repeat_multiplier', 'town_multiplier', 'scaled_weight', 'ceiling')) {
            if ($entryValues[$name] -isnot [int32]) { throw "$entryContext field '$name' must be an exact Int32." }
        }
        $actualEntryValues.Add($entryValues)
    }

    if ($values['seed_text'] -cne $ExpectedSeed -or
        $values['challenge_key'] -cne $ExpectedChallengeKey -or
        $values['run_seed'] -cne $ExpectedRunSeed -or
        $values['cycle_id'] -cne $ExpectedCycleId -or
        $values['stream_key'] -cne $ExpectedStreamKey -or
        $values['stream_seed'] -cne $ExpectedStreamSeed -or
        $values['none_roll'] -cne $ExpectedNoneRoll -or
        $values['none_percent'] -cne [int32]25 -or
        $values['absolute_minutes'] -cne $ExpectedAbsoluteMinutes -or
        $values['town_multiplier'] -cne [int32]1 -or
        $values['total_weight'] -cne $ExpectedTotalWeight -or
        $values['weighted_roll'] -cne $ExpectedWeightedRoll -or
        $values['selected_scenario'] -cne $ExpectedSelectedScenario) {
        throw "$Context deterministic selection values drifted."
    }
    if ($values['recent_scenario_ids'].Count -cne $ExpectedRecentScenarioIds.Count) {
        throw "$Context recent_scenario_ids count drifted."
    }
    for ($index = 0; $index -lt $ExpectedRecentScenarioIds.Count; $index++) {
        if ($values['recent_scenario_ids'][$index] -cne $ExpectedRecentScenarioIds[$index]) {
            throw "$Context recent_scenario_ids order or value drifted."
        }
    }
    if ($actualEntryValues.Count -cne $ExpectedWeightedEntries.Count) {
        throw "$Context weighted-entry count drifted."
    }
    for ($entryIndex = 0; $entryIndex -lt $ExpectedWeightedEntries.Count; $entryIndex++) {
        $actual = $actualEntryValues[$entryIndex]
        $expected = $ExpectedWeightedEntries[$entryIndex]
        foreach ($name in @('id', 'repeat_multiplier', 'town_multiplier', 'scaled_weight', 'ceiling')) {
            if ($actual[$name] -cne $expected.$name) {
                throw "$Context weighted entry $entryIndex field '$name' drifted."
            }
        }
    }
}


function Assert-ExactHeistSeedContractReport {
    param([AllowNull()]$Report)

    $context = 'Heist seed preflight contract report'
    Assert-ExactContractObjectKeys -Value $Report -ExpectedKeys @(
        'contract', 'passed', 'expected_scenario', 'selection', 'fresh_interactive_selection',
        'launch_model', 'serialization_calibration', 'arrival_history_hostile', 'owner_decisions',
        'valid_fixtures', 'hostile_fixtures', 'failures'
    ) -Context $context
    $values = [ordered]@{}
    foreach ($name in @(
        'contract', 'passed', 'expected_scenario', 'selection', 'fresh_interactive_selection',
        'launch_model', 'serialization_calibration', 'arrival_history_hostile', 'owner_decisions',
        'valid_fixtures', 'hostile_fixtures', 'failures'
    )) {
        $values[$name] = Get-ExactContractPropertyValue -InputObject $Report -Name $name -Context $context
    }
    foreach ($name in @('contract', 'expected_scenario')) {
        if ($values[$name] -isnot [string]) { throw "$context field '$name' must be an exact string." }
    }
    if ($values['passed'] -isnot [bool]) { throw "$context passed must be an exact Boolean." }
    foreach ($name in @('selection', 'fresh_interactive_selection', 'launch_model', 'serialization_calibration', 'arrival_history_hostile')) {
        if ($values[$name] -isnot [System.Management.Automation.PSCustomObject]) {
            throw "$context field '$name' must be an exact JSON object."
        }
    }
    foreach ($name in @('owner_decisions', 'failures')) {
        if ($values[$name] -isnot [object[]]) { throw "$context field '$name' must be an exact JSON array." }
    }
    foreach ($name in @('valid_fixtures', 'hostile_fixtures')) {
        if ($values[$name] -isnot [int32]) { throw "$context field '$name' must be an exact Int32." }
    }
    foreach ($decision in @($values['owner_decisions'])) {
        if ($decision -isnot [string]) { throw "$context owner_decisions must contain only exact strings." }
    }
    foreach ($failure in @($values['failures'])) {
        if ($failure -isnot [string]) { throw "$context failures must contain only exact strings." }
    }

    $launch = $values['launch_model']
    Assert-ExactContractObjectKeys -Value $launch -ExpectedKeys @(
        'screen', 'run_config', 'selected_challenge', 'selected_home', 'selected_content_groups',
        'challenge_mode', 'challenge_id', 'fresh_profile_modifier_text', 'start_absolute_minutes',
        'first_arrival_recent_scenario_ids'
    ) -Context "$context launch_model"
    $launchValues = [ordered]@{}
    foreach ($name in @(
        'screen', 'run_config', 'selected_challenge', 'selected_home', 'selected_content_groups',
        'challenge_mode', 'challenge_id', 'fresh_profile_modifier_text', 'start_absolute_minutes',
        'first_arrival_recent_scenario_ids'
    )) {
        $launchValues[$name] = Get-ExactContractPropertyValue -InputObject $launch -Name $name -Context "$context launch_model"
    }
    foreach ($name in @('screen', 'selected_challenge', 'selected_home', 'challenge_mode', 'challenge_id', 'fresh_profile_modifier_text')) {
        if ($launchValues[$name] -isnot [string]) { throw "$context launch_model.$name must be an exact string." }
    }
    if ($launchValues['run_config'] -isnot [bool]) { throw "$context launch_model.run_config must be an exact Boolean." }
    if ($launchValues['start_absolute_minutes'] -isnot [int32]) { throw "$context launch_model.start_absolute_minutes must be an exact Int32." }
    foreach ($name in @('selected_content_groups', 'first_arrival_recent_scenario_ids')) {
        if ($launchValues[$name] -isnot [object[]]) { throw "$context launch_model.$name must be an exact JSON array." }
        foreach ($item in @($launchValues[$name])) {
            if ($item -isnot [string]) { throw "$context launch_model.$name must contain only exact strings." }
        }
    }

    $serialization = $values['serialization_calibration']
    Assert-ExactContractObjectKeys -Value $serialization -ExpectedKeys @(
        'seed_text', 'challenge_key', 'run_seed', 'packed_save_witness'
    ) -Context "$context serialization_calibration"
    $serializationValues = [ordered]@{}
    foreach ($name in @('seed_text', 'challenge_key', 'run_seed', 'packed_save_witness')) {
        $serializationValues[$name] = Get-ExactContractPropertyValue `
            -InputObject $serialization `
            -Name $name `
            -Context "$context serialization_calibration"
    }
    foreach ($name in @('seed_text', 'challenge_key')) {
        if ($serializationValues[$name] -isnot [string]) { throw "$context serialization_calibration.$name must be an exact string." }
    }
    foreach ($name in @('run_seed', 'packed_save_witness')) {
        if ($serializationValues[$name] -isnot [int32]) { throw "$context serialization_calibration.$name must be an exact Int32." }
    }

    $expectedModifierText = 'home_archetype_id=back_alley;meta_collection_carried_instance_ids=[];meta_collection_containers=[{ "id": "meta_bag_01", "item_id": "bag", "capacity": 3, "items": [], "item_definitions": {  }, "meta_loadout": true, "meta_container_instance_id": 0 }];meta_collection_enabled=true;meta_collection_loadout=[]'
    $expectedContentGroups = [object[]]@(
        'universal_passive_items', 'universal_active_items', 'scratch_tickets_pack',
        'pull_tabs_pack', 'slot_pack', 'coin_pusher_pack', 'bar_dice_pack',
        'craps_pack', 'crew_poker_pack', 'blackjack_pack', 'baccarat_pack',
        'roulette_pack', 'video_poker_pack', 'numbers_pack'
    )
    $fullWeightedEntries = [object[]]@(
        [pscustomobject]@{ id = 'grand_casino_gala_night'; repeat_multiplier = [int32]1; town_multiplier = [int32]1; scaled_weight = [int32]8000; ceiling = [int32]8000 },
        [pscustomobject]@{ id = 'grand_casino_convention_crowd'; repeat_multiplier = [int32]1; town_multiplier = [int32]1; scaled_weight = [int32]11000; ceiling = [int32]19000 },
        [pscustomobject]@{ id = 'grand_casino_audit_night'; repeat_multiplier = [int32]1; town_multiplier = [int32]1; scaled_weight = [int32]7000; ceiling = [int32]26000 }
    )
    $suppressedWeightedEntries = [object[]]@($fullWeightedEntries[0], $fullWeightedEntries[1])
    $fixedChallengeKey = "standard|standard|RW06-HEIST-AUDIT-0002|$expectedModifierText"
    $freshChallengeKey = "standard|standard|RW06-HEIST-AUDIT-0000|$expectedModifierText"
    Assert-ExactHeistSeedSelectionReport `
        -Selection $values['selection'] `
        -Context "$context selection" `
        -ExpectedSeed 'RW06-HEIST-AUDIT-0002' `
        -ExpectedChallengeKey $fixedChallengeKey `
        -ExpectedRunSeed 919325714 `
        -ExpectedCycleId 'day:0' `
        -ExpectedStreamKey 'environment_situation:grand_casino:day:0' `
        -ExpectedStreamSeed 1392077385 `
        -ExpectedNoneRoll 59 `
        -ExpectedAbsoluteMinutes 720 `
        -ExpectedRecentScenarioIds ([object[]]@()) `
        -ExpectedWeightedEntries $fullWeightedEntries `
        -ExpectedTotalWeight 26000 `
        -ExpectedWeightedRoll 24088 `
        -ExpectedSelectedScenario 'grand_casino_audit_night'
    Assert-ExactHeistSeedSelectionReport `
        -Selection $values['fresh_interactive_selection'] `
        -Context "$context fresh_interactive_selection" `
        -ExpectedSeed 'RW06-HEIST-AUDIT-0000' `
        -ExpectedChallengeKey $freshChallengeKey `
        -ExpectedRunSeed 1262406216 `
        -ExpectedCycleId 'day:0' `
        -ExpectedStreamKey 'environment_situation:grand_casino:day:0' `
        -ExpectedStreamSeed 501255064 `
        -ExpectedNoneRoll 96 `
        -ExpectedAbsoluteMinutes 720 `
        -ExpectedRecentScenarioIds ([object[]]@()) `
        -ExpectedWeightedEntries $fullWeightedEntries `
        -ExpectedTotalWeight 26000 `
        -ExpectedWeightedRoll 22402 `
        -ExpectedSelectedScenario 'grand_casino_audit_night'
    Assert-ExactHeistSeedSelectionReport `
        -Selection $values['arrival_history_hostile'] `
        -Context "$context arrival_history_hostile" `
        -ExpectedSeed 'RW06-HEIST-AUDIT-0002' `
        -ExpectedChallengeKey $fixedChallengeKey `
        -ExpectedRunSeed 919325714 `
        -ExpectedCycleId 'day:1' `
        -ExpectedStreamKey 'environment_situation:grand_casino:day:1' `
        -ExpectedStreamSeed 1392125656 `
        -ExpectedNoneRoll 53 `
        -ExpectedAbsoluteMinutes 2160 `
        -ExpectedRecentScenarioIds ([object[]]@('grand_casino_audit_night')) `
        -ExpectedWeightedEntries $suppressedWeightedEntries `
        -ExpectedTotalWeight 19000 `
        -ExpectedWeightedRoll 15327 `
        -ExpectedSelectedScenario 'grand_casino_convention_crowd'

    if ($values['contract'] -cne 'rw06_2_heist_seed_preflight' -or
        -not $values['passed'] -or
        $values['expected_scenario'] -cne 'grand_casino_audit_night' -or
        $values['owner_decisions'].Count -cne 2 -or
        $values['owner_decisions'][0] -cne 'Q-013A' -or
        $values['owner_decisions'][1] -cne 'Q-017A' -or
        $values['valid_fixtures'] -cne [int32]2 -or
        $values['hostile_fixtures'] -cne [int32]4 -or
        $values['failures'].Count -cne 0) {
        throw "$context identity, owner authority, counts, or outcome drifted."
    }
    if ($launchValues['screen'] -cne 'START' -or
        -not $launchValues['run_config'] -or
        $launchValues['selected_challenge'] -cne '' -or
        $launchValues['selected_home'] -cne 'random' -or
        $launchValues['challenge_mode'] -cne 'standard' -or
        $launchValues['challenge_id'] -cne 'standard' -or
        $launchValues['fresh_profile_modifier_text'] -cne $expectedModifierText -or
        $launchValues['start_absolute_minutes'] -cne [int32]720 -or
        $launchValues['first_arrival_recent_scenario_ids'].Count -cne 0 -or
        $launchValues['selected_content_groups'].Count -cne $expectedContentGroups.Count) {
        throw "$context launch model values drifted."
    }
    for ($index = 0; $index -lt $expectedContentGroups.Count; $index++) {
        if ($launchValues['selected_content_groups'][$index] -cne $expectedContentGroups[$index]) {
            throw "$context launch content-group order or value drifted."
        }
    }
    if ($serializationValues['seed_text'] -cne 'RW06-CLEAN-ROUTE-01' -or
        $serializationValues['challenge_key'] -cne "standard|standard|RW06-CLEAN-ROUTE-01|$expectedModifierText" -or
        $serializationValues['run_seed'] -cne [int32]6620395 -or
        $serializationValues['packed_save_witness'] -cne [int32]6620395) {
        throw "$context serialization calibration drifted."
    }
    return [pscustomobject]@{
        valid_fixtures = $values['valid_fixtures']
        hostile_fixtures = $values['hostile_fixtures']
    }
}


function Assert-ExactEvidenceAdmissionContractReport {
    param(
        [AllowNull()]$Report,
        [Parameter(Mandatory = $true)][Collections.IDictionary]$ExpectedSourceHashes
    )
    $context = 'Evidence admission contract report'
    $expectedKeys = @(
        'contract', 'passed', 'owner_decisions', 'fixed_heist_seed', 'fresh_interactive_seed',
        'fresh_interactive_route_plan', 'resolver_valid_fixtures', 'resolver_hostile_fixtures',
        'preflight_valid_fixtures', 'admission_object_hostile_fixtures',
        'admission_universal_schema_hostile_fixtures', 'preflight_hostile_fixtures',
        'preflight_universal_schema_hostile_fixtures', 'source_valid_fixtures',
        'source_hostile_fixtures', 'outer_valid_fixtures', 'outer_hostile_fixtures',
        'outer_universal_schema_hostile_fixtures', 'source_sha256', 'failures'
    )
    Assert-ExactContractObjectKeys -Value $Report -ExpectedKeys $expectedKeys -Context $context
    $values = [ordered]@{}
    foreach ($name in $expectedKeys) {
        $values[$name] = Get-ExactContractPropertyValue -InputObject $Report -Name $name -Context $context
    }
    foreach ($name in @('contract', 'fixed_heist_seed', 'fresh_interactive_seed', 'fresh_interactive_route_plan')) {
        if ($values[$name] -isnot [string]) { throw "$context field '$name' must be an exact string." }
    }
    if ($values['passed'] -isnot [bool]) { throw "$context passed must be an exact Boolean." }
    foreach ($name in @('owner_decisions', 'failures')) {
        if ($values[$name] -isnot [object[]]) { throw "$context field '$name' must be an exact JSON array." }
    }
    foreach ($item in @($values['owner_decisions'])) {
        if ($item -isnot [string]) { throw "$context owner_decisions must contain only exact strings." }
    }
    foreach ($item in @($values['failures'])) {
        if ($item -isnot [string]) { throw "$context failures must contain only exact strings." }
    }
    $countNames = @(
        'resolver_valid_fixtures', 'resolver_hostile_fixtures', 'preflight_valid_fixtures',
        'admission_object_hostile_fixtures', 'admission_universal_schema_hostile_fixtures',
        'preflight_hostile_fixtures', 'preflight_universal_schema_hostile_fixtures',
        'source_valid_fixtures', 'source_hostile_fixtures', 'outer_valid_fixtures',
        'outer_hostile_fixtures', 'outer_universal_schema_hostile_fixtures'
    )
    foreach ($name in $countNames) {
        if ($values[$name] -isnot [int32]) { throw "$context field '$name' must be an exact Int32." }
    }
    $sourceHashes = $values['source_sha256']
    Assert-ExactContractObjectKeys `
        -Value $sourceHashes `
        -ExpectedKeys @('admission', 'preflight', 'runner', 'fixed_launcher') `
        -Context "$context source_sha256"
    $actualHashes = [ordered]@{}
    foreach ($name in @('admission', 'preflight', 'runner', 'fixed_launcher')) {
        $actualHashes[$name] = Get-ExactContractPropertyValue `
            -InputObject $sourceHashes `
            -Name $name `
            -Context "$context source_sha256"
        if ($actualHashes[$name] -isnot [string] -or $actualHashes[$name] -cnotmatch '^[A-F0-9]{64}$') {
            throw "$context source_sha256.$name must be an exact uppercase SHA-256 string."
        }
    }

    $expectedCounts = [ordered]@{
        resolver_valid_fixtures = [int32]3
        resolver_hostile_fixtures = [int32]10
        preflight_valid_fixtures = [int32]2
        admission_object_hostile_fixtures = [int32]105
        admission_universal_schema_hostile_fixtures = [int32]73
        preflight_hostile_fixtures = [int32]403
        preflight_universal_schema_hostile_fixtures = [int32]294
        source_valid_fixtures = [int32]1
        source_hostile_fixtures = [int32]33
        outer_valid_fixtures = [int32]3
        outer_hostile_fixtures = [int32]93
        outer_universal_schema_hostile_fixtures = [int32]73
    }
    if ($values['contract'] -cne 'rw06_2_evidence_admission' -or
        -not $values['passed'] -or
        $values['owner_decisions'].Count -cne 2 -or
        $values['owner_decisions'][0] -cne 'Q-013A' -or
        $values['owner_decisions'][1] -cne 'Q-017A' -or
        $values['fixed_heist_seed'] -cne 'RW06-HEIST-AUDIT-0002' -or
        $values['fresh_interactive_seed'] -cne 'RW06-HEIST-AUDIT-0000' -or
        $values['fresh_interactive_route_plan'] -cne 'count' -or
        $values['failures'].Count -cne 0) {
        throw "$context identity, owner authority, route authority, or outcome drifted."
    }
    foreach ($name in $expectedCounts.Keys) {
        if ($values[$name] -cne $expectedCounts[$name]) {
            throw "$context field '$name' drifted from its exact expected count."
        }
    }
    foreach ($name in @('admission', 'preflight', 'runner', 'fixed_launcher')) {
        if (-not $ExpectedSourceHashes.Contains($name) -or
            $ExpectedSourceHashes[$name] -isnot [string] -or
            $actualHashes[$name] -cne $ExpectedSourceHashes[$name]) {
            throw "$context source_sha256.$name does not authenticate the inspected source."
        }
    }
    return [pscustomobject]@{
        valid_fixtures = [int32](
            $values['resolver_valid_fixtures'] + $values['preflight_valid_fixtures'] +
            $values['source_valid_fixtures'] + $values['outer_valid_fixtures']
        )
        hostile_fixtures = [int32](
            $values['resolver_hostile_fixtures'] + $values['admission_object_hostile_fixtures'] +
            $values['preflight_hostile_fixtures'] + $values['source_hostile_fixtures'] +
            $values['outer_hostile_fixtures']
        )
    }
}


function Assert-ExactSemanticScrollReport {
    param(
        [AllowNull()]$Report,
        [Parameter(Mandatory = $true)][string]$ExpectedReportPath
    )
    $context = 'Semantic-scroll regression report'
    if ($Report -isnot [System.Management.Automation.PSCustomObject]) {
        throw "$context must be an exact JSON object."
    }
    $expectedKeys = @(
        'schema_version',
        'check_id',
        'passed',
        'valid_button_fixtures',
        'hostile_button_fixtures',
        'valid_dialog_fixtures',
        'hostile_dialog_fixtures',
        'valid_fixtures',
        'hostile_fixtures',
        'valid_confirmation_fixtures',
        'hostile_confirmation_fixtures',
        'valid_canvas_object_fixtures',
        'hostile_canvas_object_fixtures',
        'valid_room_action_fixtures',
        'hostile_room_action_fixtures',
        'valid_save_acknowledgment_fixtures',
        'hostile_save_acknowledgment_fixtures',
        'valid_terminal_fixtures',
        'hostile_terminal_fixtures',
        'failures',
        'report'
    )
    $actualKeys = @($Report.PSObject.Properties | ForEach-Object { $_.Name })
    if ($actualKeys.Count -cne $expectedKeys.Count) {
        throw "$context has $($actualKeys.Count) properties instead of $($expectedKeys.Count)."
    }
    for ($index = 0; $index -lt $expectedKeys.Count; $index++) {
        if ($actualKeys[$index] -cne $expectedKeys[$index]) {
            throw "$context property $index is '$($actualKeys[$index])' instead of '$($expectedKeys[$index])'."
        }
    }
    $expectedInt32 = [ordered]@{
        schema_version = 1
        valid_button_fixtures = 1
        hostile_button_fixtures = 6
        valid_dialog_fixtures = 2
        hostile_dialog_fixtures = 8
        valid_fixtures = 2
        hostile_fixtures = 10
        valid_confirmation_fixtures = 1
        hostile_confirmation_fixtures = 5
        valid_canvas_object_fixtures = 2
        hostile_canvas_object_fixtures = 6
        valid_room_action_fixtures = 1
        hostile_room_action_fixtures = 6
        valid_save_acknowledgment_fixtures = 1
        hostile_save_acknowledgment_fixtures = 5
        valid_terminal_fixtures = 1
        hostile_terminal_fixtures = 4
    }
    foreach ($name in $expectedInt32.Keys) {
        $value = Get-ExactContractPropertyValue -InputObject $Report -Name $name -Context $context
        if ($value -isnot [int32] -or $value -cne [int32]$expectedInt32[$name]) {
            throw "$context field '$name' is not the exact expected Int32."
        }
    }
    $checkId = Get-ExactContractPropertyValue -InputObject $Report -Name 'check_id' -Context $context
    $passed = Get-ExactContractPropertyValue -InputObject $Report -Name 'passed' -Context $context
    $failuresValue = Get-ExactContractPropertyValue -InputObject $Report -Name 'failures' -Context $context
    $reportPathValue = Get-ExactContractPropertyValue -InputObject $Report -Name 'report' -Context $context
    if ($checkId -isnot [string] -or $checkId -cne 'rw06_2_semantic_scroll_contract' -or
        $passed -isnot [bool] -or -not $passed -or
        $failuresValue -isnot [object[]] -or $failuresValue.Count -cne 0 -or
        $reportPathValue -isnot [string] -or
        -not ([IO.Path]::GetFullPath($reportPathValue)).Equals([IO.Path]::GetFullPath($ExpectedReportPath), [StringComparison]::OrdinalIgnoreCase)) {
        throw "$context identity, outcome, failure list, or report path is malformed."
    }
}


function New-CheatReplayDuelCheckpointPolicyFixture {
    return [pscustomobject]@{
        game = [pscustomobject]@{
            game_id = 'blackjack'
            phase = 'betting'
            boss_duel_active = $true
            boss_hand_number = [int32]1
            can_deal = $true
        }
        surface_actions = [object[]]@(
            [pscustomobject]@{ action = 'blackjack_deal'; index = [int32]0; enabled = $true },
            [pscustomobject]@{ action = 'surface_back'; index = [int32]0; enabled = $true }
        )
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


function New-CheatReplayInterrogationPolicyFixture {
    $choiceIds = @('hold_steady', 'talk_down', 'take_the_edge')
    return [pscustomobject]@{
        popup = [pscustomobject]@{
            visible = $true
            render_valid = $true
            event_id = 'the_house_calls'
            choice_ids = $choiceIds
            choices = @(
                [pscustomobject]@{ id = 'hold_steady'; label = 'Hold Steady'; text = 'Let the run record answer.'; enabled = $true },
                [pscustomobject]@{ id = 'talk_down'; label = 'Name Your People'; text = 'Put Linda and the Crew between the claims.'; enabled = $true },
                [pscustomobject]@{ id = 'take_the_edge'; label = 'Take the Edge'; text = "Risk one fresh tell under Rourke's stare."; enabled = $true }
            )
        }
        expected_choice = 'take_the_edge'
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


function Test-CheatReplayBarredPeekExitOrder {
    param([Parameter(Mandatory = $true)][string]$Source)

    $functionMatch = [regex]::Match($Source, '(?ms)^function Play-OneBlackjackRound\s*\{.*?(?=^function |\z)')
    if (-not $functionMatch.Success) { return $false }
    return [regex]::IsMatch(
        $functionMatch.Value,
        '(?s)\$peekApplied\s*=\s*Invoke-VisibleCheatIfAvailable.*?Select-CheatReplayPostPeekTransition.*?stage\s+-ceq\s+''leave_for_showdown''\)\s*\{\s*return\s*\}.*?Find-GameAction\s+-Action\s+''blackjack_settle''.*?Invoke-PublicBlackjackDecision'
    )
}

function Test-PersistenceCheckpointWriteSequence {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$FunctionName,
        [Parameter(Mandatory = $true)][ValidateSet(10, 20)][int]$Depth
    )

    $tokens = $null
    $parseErrors = $null
    $ast = [Management.Automation.Language.Parser]::ParseInput($Source, [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors.Count -ne 0) { return $false }
    $functionAsts = @($ast.FindAll({
        param($node)
        $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq $FunctionName
    }, $true))
    if ($functionAsts.Count -cne 1 -or $null -ceq $functionAsts[0].Body.EndBlock) { return $false }
    $functionAst = $functionAsts[0]
    $body = $functionAst.Extent.Text
    $directStatements = @($functionAst.Body.EndBlock.Statements)
    $beforeCaptureToken = '$beforeJson = $before | ConvertTo-Json -Depth {0} -Compress' -f $Depth
    $afterCaptureToken = '$afterJson = $after | ConvertTo-Json -Depth {0} -Compress' -f $Depth
    $beforeWriteToken = '$before | ConvertTo-Json -Depth {0} | Set-Content -LiteralPath (Join-Path $script:RunRoot ''checkpoint_before.json'') -Encoding utf8' -f $Depth
    $afterWriteToken = '$after | ConvertTo-Json -Depth {0} | Set-Content -LiteralPath (Join-Path $script:RunRoot ''checkpoint_after.json'') -Encoding utf8' -f $Depth
    $comparisonToken = 'if ($afterJson -cne $beforeJson) {'
    $midpointToken = '$script:MidpointSaved = $true'
    $beforeCaptureIndex = $body.IndexOf($beforeCaptureToken, [StringComparison]::Ordinal)
    $afterCaptureIndex = $body.IndexOf($afterCaptureToken, [StringComparison]::Ordinal)
    $beforeWriteIndex = $body.IndexOf($beforeWriteToken, [StringComparison]::Ordinal)
    $afterWriteIndex = $body.IndexOf($afterWriteToken, [StringComparison]::Ordinal)
    $comparisonIndex = $body.IndexOf($comparisonToken, [StringComparison]::Ordinal)
    $midpointIndex = $body.IndexOf($midpointToken, [StringComparison]::Ordinal)
    $directBeforeWrites = @($directStatements | Where-Object { $_.Extent.Text.Trim() -ceq $beforeWriteToken })
    $directAfterWrites = @($directStatements | Where-Object { $_.Extent.Text.Trim() -ceq $afterWriteToken })
    $unconditionalStopsBeforeWrites = @($directStatements | Where-Object {
        $_.Extent.StartOffset -gt ($functionAst.Extent.StartOffset + $afterCaptureIndex) -and
            $_.Extent.StartOffset -lt ($functionAst.Extent.StartOffset + $beforeWriteIndex) -and
            ($_ -is [Management.Automation.Language.ReturnStatementAst] -or
                $_ -is [Management.Automation.Language.ThrowStatementAst] -or
                $_ -is [Management.Automation.Language.ExitStatementAst])
    })
    return [regex]::Matches($body, [regex]::Escape($beforeCaptureToken)).Count -ceq 1 -and
        [regex]::Matches($body, [regex]::Escape($afterCaptureToken)).Count -ceq 1 -and
        [regex]::Matches($body, [regex]::Escape($beforeWriteToken)).Count -ceq 1 -and
        [regex]::Matches($body, [regex]::Escape($afterWriteToken)).Count -ceq 1 -and
        $directBeforeWrites.Count -ceq 1 -and
        $directAfterWrites.Count -ceq 1 -and
        $unconditionalStopsBeforeWrites.Count -ceq 0 -and
        $beforeCaptureIndex -ge 0 -and
        $afterCaptureIndex -gt $beforeCaptureIndex -and
        $beforeWriteIndex -gt $afterCaptureIndex -and
        $afterWriteIndex -gt $beforeWriteIndex -and
        $comparisonIndex -gt $afterWriteIndex -and
        $midpointIndex -gt $comparisonIndex
}


function Test-EndingNormalizationSequence {
    param([Parameter(Mandatory = $true)][string]$Source)
    $normalizationToken = '$Ending = $Ending.ToLowerInvariant()'
    $roleNormalizationToken = '$EvidenceRole = $EvidenceRole.ToLowerInvariant()'
    $admissionToken = '$script:ReplayAdmission = Resolve-Rw062ReplayAdmission'
    $heistPreflightToken = "if (`$Ending -ceq 'heist') {"
    $normalizationIndex = $Source.IndexOf($normalizationToken, [StringComparison]::Ordinal)
    $roleNormalizationIndex = $Source.IndexOf($roleNormalizationToken, [StringComparison]::Ordinal)
    $admissionIndex = $Source.IndexOf($admissionToken, [StringComparison]::Ordinal)
    $heistPreflightIndex = $Source.LastIndexOf($heistPreflightToken, [StringComparison]::Ordinal)
    return [regex]::Matches($Source, [regex]::Escape($normalizationToken)).Count -ceq 1 -and
        [regex]::Matches($Source, [regex]::Escape($roleNormalizationToken)).Count -ceq 1 -and
        $normalizationIndex -ge 0 -and
        $roleNormalizationIndex -gt $normalizationIndex -and
        $admissionIndex -gt $roleNormalizationIndex -and
        $heistPreflightIndex -gt $admissionIndex
}


function Test-ExclusiveEvidenceDirectorySource {
    param([Parameter(Mandatory = $true)][string]$Source)
    $functionMatch = [regex]::Match($Source, '(?ms)^function\s+New-ExclusiveEvidenceDirectory\s*\{.*?(?=^function |\z)')
    if (-not $functionMatch.Success) { return $false }
    $body = $functionMatch.Value
    $existsToken = 'if (Test-Path -LiteralPath $absolutePath) {'
    $createToken = '[void](New-Item -ItemType Directory -Path $absolutePath -ErrorAction Stop)'
    $existsIndex = $body.IndexOf($existsToken, [StringComparison]::Ordinal)
    $createIndex = $body.IndexOf($createToken, [StringComparison]::Ordinal)
    return $body.Contains('$absolutePath = [IO.Path]::GetFullPath($Path)') -and
        $existsIndex -ge 0 -and
        $createIndex -gt $existsIndex -and
        $body.Contains('refusing stale artifact reuse') -and
        -not [regex]::IsMatch($body, '(?s)New-Item[^\r\n]*\$absolutePath[^\r\n]*-Force')
}


function Test-CleanSilverPersistenceSource {
    param([Parameter(Mandatory = $true)][string]$Source)
    $projection = [regex]::Match($Source, '(?ms)^function\s+Get-CleanSilverPlayersCardProjection\s*\{.*?(?=^function |\z)').Value
    $save = [regex]::Match($Source, '(?ms)^function\s+Assert-SaveRelaunchContinue\s*\{.*?(?=^function |\z)').Value
    if ([string]::IsNullOrWhiteSpace($projection) -or [string]::IsNullOrWhiteSpace($save)) { return $false }
    foreach ($token in @(
        'Open-CageCounter',
        "Choose-VisibleChoice -ChoiceId 'open_card'",
        "Get-ExactReplayString -InputObject `$talk -Path @('summary')",
        "StartsWith('Silver. Gold:', [StringComparison]::Ordinal)",
        'Get-ExactReplayObjectArray',
        "@('look', 'clickable', 'talk_choices')",
        "`$expectedChoiceIds = @('cage_claim_card', 'cage_ambient', 'back_main')",
        "tier_witness = 'Silver'",
        "next_tier_witness = 'Gold'",
        "Choose-VisibleChoice -ChoiceId 'back_main'",
        "Choose-VisibleChoice -ChoiceId 'leave_counter'"
    )) {
        if ($projection.IndexOf($token, [StringComparison]::Ordinal) -lt 0) { return $false }
    }
    if ($projection -match 'run_state|narrative_flags|demo_objective|players_card_tier_label') { return $false }
    foreach ($token in @(
        "`$beforeCleanPlayersCard = if (`$Ending -ceq 'clean') { Get-CleanSilverPlayersCardProjection } else { `$null }",
        'clean_players_card = $beforeCleanPlayersCard',
        "`$afterCleanPlayersCard = if (`$Ending -ceq 'clean') { Get-CleanSilverPlayersCardProjection } else { `$null }",
        'clean_players_card = $afterCleanPlayersCard'
    )) {
        if ($save.IndexOf($token, [StringComparison]::Ordinal) -lt 0) { return $false }
    }
    return $true
}


function Test-CheckpointDeterminismFailureSource {
    param([Parameter(Mandatory = $true)][string]$Source)
    return [regex]::IsMatch(
        $Source,
        '(?s)\$referenceCheckpointBeforeHash\s*=\s*''''.*?\$referenceCheckpointAfterHash\s*=\s*''''.*?\$currentCheckpointBeforeHash\s*=.*?persistence_checkpoint_before_sha256.*?\$currentCheckpointAfterHash\s*=.*?persistence_checkpoint_after_sha256.*?elseif\s*\(\$currentTranscriptHash.*?\$currentCheckpointBeforeHash\s+-cne\s+\$referenceCheckpointBeforeHash.*?\$currentCheckpointAfterHash\s+-cne\s+\$referenceCheckpointAfterHash.*?\)\s*\{\s*throw\s+"Deterministic replay mismatch',
        [Text.RegularExpressions.RegexOptions]::IgnoreCase
    )
}


function Test-MidpointCheckpointCompletenessSource {
    param([Parameter(Mandatory = $true)][string]$Source)
    return [regex]::IsMatch(
        $Source,
        '(?s)\$checkpointEvidenceComplete\s*=\s*\$script:MidpointSaved\s+-and\s*\$checkpointBeforeHash\s+-cmatch\s+''\^\[a-f0-9\]\{64\}\$''.*?\$checkpointAfterHash\s+-cmatch\s+''\^\[a-f0-9\]\{64\}\$''.*?\$checkpointBeforeHash\s+-ceq\s+\$checkpointAfterHash'
    )
}


function Test-DirectDeterminismFormulaSource {
    param([Parameter(Mandatory = $true)][string]$Source)
    if ([regex]::Matches($Source, '(?im)^[ \t]*\$deterministic[ \t]*=').Count -cne 1) {
        return $false
    }
    $formulaMatch = [regex]::Match(
        $Source,
        '(?ms)^[ \t]*\$deterministic[ \t]*=[ \t]*(?<formula>.*?)^[ \t]*\$checkpointEvidenceComplete[ \t]*='
    )
    if (-not $formulaMatch.Success) { return $false }
    $actualFormula = [regex]::Replace($formulaMatch.Groups['formula'].Value, '\s+', '')
    $expectedFormula = '$Repeat-ceq2-and@($validatedRunReceipts|Select-Object-ExpandPropertytranscript_sha256-Unique).Count-ceq1-and@($validatedRunReceipts|Select-Object-ExpandPropertymoney_curve_sha256-Unique).Count-ceq1-and@($validatedRunReceipts|Select-Object-ExpandPropertypersistence_checkpoint_before_sha256-Unique).Count-ceq1-and@($validatedRunReceipts|Select-Object-ExpandPropertypersistence_checkpoint_after_sha256-Unique).Count-ceq1-and@($validatedRunReceipts|ForEach-Object{$_.final_public_checkpoint|ConvertTo-Json-Depth10-Compress}|Select-Object-Unique).Count-ceq1'
    return $actualFormula -ceq $expectedFormula
}


function Test-DirectDevelopmentQualificationSource {
    param([Parameter(Mandatory = $true)][string]$Source)
    if ([regex]::IsMatch($Source, '(?i)\$releaseQualifying\b|\$fixedRepeatQualifying\b|\bfixed_repeat_qualifying\b')) { return $false }
    if ([regex]::Matches($Source, '(?i)\brelease_qualifying\s*=').Count -cne 2) { return $false }
    if ([regex]::IsMatch($Source, '(?i)\bfixed_route_repeat\b|\btwo_identical_repeats\b|\brw06_2_final_evidence\b|\baggregate_summary\.json\b')) { return $false }
    if ([regex]::IsMatch($Source, '(?im)\$env:(?:APPDATA|LOCALAPPDATA)\s*=|(?:Set-Item|New-Item)\b[^\r\n]*(?:Env:APPDATA|Env:LOCALAPPDATA)|SetEnvironmentVariable\s*\(\s*[''"](?:APPDATA|LOCALAPPDATA)[''"]|(?:^|\s)-Environment\b|\bProcessStartInfo\b|\.(?:Environment|EnvironmentVariables)\s*(?:\[|\.|=)')) { return $false }
    if ([regex]::IsMatch($Source, '(?im)^[ \t]*\$(?!finalSummary\b|runSummary\b)[A-Za-z_][A-Za-z0-9_]*[ \t]*=[ \t]*\$(?:finalSummary|runSummary)\b')) { return $false }
    if ([regex]::IsMatch($Source, '(?im)\$(?:finalSummary|runSummary)\s*(?:\.[A-Za-z_][A-Za-z0-9_]*|\[[^\]]+\])\s*=|\$(?:finalSummary|runSummary)\s*\.\s*Add\s*\(|\$(?:finalSummary|runSummary)\s*\|\s*Add-Member\b|Add-Member\b[^\r\n]*\$(?:finalSummary|runSummary)|\$(?:finalSummary|runSummary)\.PSObject\.Properties')) { return $false }
    if (-not (Test-DirectDeterminismFormulaSource -Source $Source)) { return $false }

    $runSummaryMatch = [regex]::Match($Source, '(?ms)^[ \t]*\$runSummary\s*=\s*\[ordered\]@\{(?<body>.*?)^[ \t]*\}')
    if (-not $runSummaryMatch.Success) { return $false }
    $runBody = $runSummaryMatch.Groups['body'].Value
    $exactRunFields = [ordered]@{
        role = "role = 'child_development_iteration'"
        repeat_profile_scope = "repeat_profile_scope = 'shared_caller_appdata'"
        fixed_repeat_qualification_authority = "fixed_repeat_qualification_authority = 'outer_independent_profile_aggregate_only'"
        release_qualifying = 'release_qualifying = $false'
        qualification = "qualification = 'non_qualifying_development_iteration'"
    }
    foreach ($field in $exactRunFields.Keys) {
        $matches = @([regex]::Matches($runBody, "(?m)^\s*$([regex]::Escape([string]$field))\s*=.*$"))
        if ($matches.Count -cne 1 -or $matches[0].Value.Trim() -cne [string]$exactRunFields[$field]) {
            return $false
        }
    }

    $summaryMatch = [regex]::Match($Source, '(?ms)^[ \t]*\$finalSummary\s*=\s*\[ordered\]@\{(?<body>.*?)^[ \t]*\}')
    if (-not $summaryMatch.Success) { return $false }
    $body = $summaryMatch.Groups['body'].Value
    $exactFields = [ordered]@{
        role = "role = 'child_development_run'"
        repeat_profile_scope = "repeat_profile_scope = 'shared_caller_appdata'"
        fixed_repeat_qualification_authority = "fixed_repeat_qualification_authority = 'outer_independent_profile_aggregate_only'"
        deterministic = 'deterministic = $deterministic'
        release_qualifying = 'release_qualifying = $false'
        qualification = "qualification = 'non_qualifying_development_run'"
    }
    foreach ($field in $exactFields.Keys) {
        $matches = @([regex]::Matches($body, "(?m)^\s*$([regex]::Escape([string]$field))\s*=.*$"))
        if ($matches.Count -cne 1 -or $matches[0].Value.Trim() -cne [string]$exactFields[$field]) {
            return $false
        }
    }
    $allowedKeys = @(
        'schema_version', 'check_id', 'role', 'repeat_profile_scope',
        'fixed_repeat_qualification_authority', 'ending', 'seed',
        'requested_evidence_role', 'replay_admission',
        'observed_terminal_seeds', 'repeat', 'deterministic',
        'checkpoint_evidence_complete', 'release_qualifying', 'qualification',
        'public_observation_schema', 'public_observation_schema_version',
        'heist_seed_preflight', 'heist_preflight_admission', 'evidence_root', 'runs'
    )
    $summaryKeys = @([regex]::Matches($body, '(?m)^\s*(?<key>[A-Za-z_][A-Za-z0-9_]*)\s*=') | ForEach-Object { $_.Groups['key'].Value })
    if (@($summaryKeys | Select-Object -Unique).Count -cne $summaryKeys.Count -or
        @($summaryKeys | Where-Object { $_ -cnotin $allowedKeys }).Count -ne 0) {
        return $false
    }
    return $true
}


function Test-ReplayExactEvidenceTypeSource {
    param([Parameter(Mandatory = $true)][string]$Source)

    $analysis = ConvertTo-PowerShellAnalysis -Source $Source
    if ($analysis.parse_errors.Count -cne 0) { return $false }
    $requiredFunctions = @(
        'Get-ReplayPathValue',
        'Test-ReplayPathPresent',
        'Get-ExactReplayString',
        'Get-ExactReplayBoolean',
        'Get-ExactReplayInt32',
        'Get-ExactReplayObjectArray',
        'Get-ExactReplayPsCustomObject',
        'Assert-ExactReplayPsCustomObject',
        'Assert-ExactReplayObjectKeys',
        'Assert-ExactFinalPublicCheckpoint',
        'Assert-ExactReplayRunSummary',
        'Assert-ExactReplayFinalSummary',
        'Get-RenderedHudInteger',
        'Test-PublicTerminalSurface',
        'Assert-ReplayPauseOwnership',
        'Assert-HealthyResult',
        'New-CanonicalRecord',
        'Get-CleanSilverPlayersCardProjection',
        'Get-PersistenceCheckpoint',
        'Assert-TerminalOutcome',
        'Write-FinalPublicCheckpoint',
        'Get-PlanningTableProjection'
    )
    $functionAsts = @{}
    $functionSources = @{}
    foreach ($name in $requiredFunctions) {
        $functionAst = Get-PowerShellFunctionAst -Analysis $analysis -Name $name
        if ($null -ceq $functionAst) { return $false }
        $functionAsts[$name] = $functionAst
        $functionSources[$name] = [string]$functionAst.Extent.Text
    }

    $pathReader = [string]$functionSources['Get-ReplayPathValue']
    foreach ($token in @(
        '$Found.Value = $false',
        '$current -is [System.Collections.IDictionary]',
        '$current -isnot [System.Management.Automation.PSCustomObject]',
        '$_.Name -ceq $segment',
        '$Found.Value = $true',
        'Write-Output -NoEnumerate $current'
    )) {
        if ($pathReader.IndexOf($token, [StringComparison]::Ordinal) -lt 0) { return $false }
    }
    if ($pathReader.IndexOf('return $current', [StringComparison]::Ordinal) -ge 0) { return $false }
    $exactHelperRequirements = [ordered]@{
        'Get-ExactReplayString' = @('$value -isnot [string]', 'throw "$Context must be an exact string."')
        'Get-ExactReplayBoolean' = @('$value -isnot [bool]', 'throw "$Context must be an exact boolean."')
        'Get-ExactReplayInt32' = @('$value -isnot [int32]', 'throw "$Context must be an exact Int32."')
        'Get-ExactReplayObjectArray' = @(
            '$value -isnot [object[]]',
            'throw "$Context must be an exact JSON array."',
            '$value[$index] -isnot [string]',
            'throw "$Context contains a non-string element at index $index."',
            '$value[$index] -isnot [System.Management.Automation.PSCustomObject]',
            'throw "$Context contains a non-object element at index $index."',
            'Write-Output -NoEnumerate $value'
        )
        'Get-ExactReplayPsCustomObject' = @(
            '$value -isnot [System.Management.Automation.PSCustomObject]',
            'if ($AllowNull) { return $null }'
        )
        'Assert-ExactReplayObjectKeys' = @(
            '$actualKeys.Count -cne $ExpectedKeys.Count',
            '$actualKeys[$index] -cne $ExpectedKeys[$index]'
        )
    }
    foreach ($name in $exactHelperRequirements.Keys) {
        $body = [string]$functionSources[$name]
        foreach ($token in $exactHelperRequirements[$name]) {
            if ($body.IndexOf([string]$token, [StringComparison]::Ordinal) -lt 0) { return $false }
        }
    }

    foreach ($name in @(
        'Get-RenderedHudInteger', 'Test-PublicTerminalSurface', 'Assert-ReplayPauseOwnership',
        'Assert-HealthyResult', 'New-CanonicalRecord', 'Get-CleanSilverPlayersCardProjection',
        'Get-PersistenceCheckpoint', 'Assert-TerminalOutcome', 'Write-FinalPublicCheckpoint',
        'Get-PlanningTableProjection', 'Assert-ExactFinalPublicCheckpoint',
        'Assert-ExactReplayRunSummary', 'Assert-ExactReplayFinalSummary'
    )) {
        if ([regex]::IsMatch([string]$functionSources[$name], '\bGet-(?:Value|Array)\b')) { return $false }
    }

    $groups = @(
        [pscustomobject]@{ fn = 'Get-RenderedHudInteger'; getter = 'Get-ExactReplayBoolean'; input = '-InputObject $script:LastObservation'; paths = @("@('status_hud', `$witnessName)"); extra = '' },
        [pscustomobject]@{ fn = 'Get-RenderedHudInteger'; getter = 'Get-ExactReplayInt32'; input = '-InputObject $script:LastObservation'; paths = @("@('status_hud', `$Name)"); extra = '' },
        [pscustomobject]@{ fn = 'Test-PublicTerminalSurface'; getter = 'Get-ExactReplayString'; input = '-InputObject $script:LastObservation'; paths = @("@('screen', 'screen')"); extra = '' },
        [pscustomobject]@{ fn = 'Test-PublicTerminalSurface'; getter = 'Get-ExactReplayBoolean'; input = '-InputObject $script:LastObservation'; paths = @("@('screen', 'run_report_visible')"); extra = '' },
        [pscustomobject]@{ fn = 'Assert-ReplayPauseOwnership'; getter = 'Get-ExactReplayObjectArray'; input = '-InputObject $Snapshot'; paths = @("@('pause_owners')"); extra = '-ElementType String' },
        [pscustomobject]@{ fn = 'Assert-ReplayPauseOwnership'; getter = 'Get-ExactReplayBoolean'; input = '-InputObject $Snapshot'; paths = @("@('application_paused')", "@('simulation_paused')", "@('environment_canvas_paused')", "@('game_canvas_paused')"); extra = '' },
        [pscustomobject]@{ fn = 'Assert-HealthyResult'; getter = 'Get-ExactReplayBoolean'; input = '-InputObject $Result'; paths = @("@('accepted')"); extra = '' },
        [pscustomobject]@{ fn = 'Assert-HealthyResult'; getter = 'Get-ExactReplayString'; input = '-InputObject $Result'; paths = @("@('reason')", "@('look', 'png_error')"); extra = '' },
        [pscustomobject]@{ fn = 'Assert-HealthyResult'; getter = 'Get-ExactReplayObjectArray'; input = '-InputObject $Result'; paths = @("@('log_alerts')"); extra = '-ElementType String' },
        [pscustomobject]@{ fn = 'Assert-HealthyResult'; getter = 'Get-ExactReplayPsCustomObject'; input = '-InputObject $Result'; paths = @("@('replay_pause_before')", "@('look', 'replay_pause')", "@('look', 'observable')", "@('trace')"); extra = '' },
        [pscustomobject]@{ fn = 'Assert-HealthyResult'; getter = 'Get-ExactReplayString'; input = '-InputObject $observation'; paths = @("@('schema')", "@('privacy', 'policy')", "@('game', 'game_id')"); extra = '' },
        [pscustomobject]@{ fn = 'Assert-HealthyResult'; getter = 'Get-ExactReplayInt32'; input = '-InputObject $observation'; paths = @("@('schema_version')"); extra = '' },
        [pscustomobject]@{ fn = 'Assert-HealthyResult'; getter = 'Get-ExactReplayString'; input = '-InputObject $trace'; paths = @("@('command')"); extra = '' },
        [pscustomobject]@{ fn = 'Assert-HealthyResult'; getter = 'Get-ExactReplayBoolean'; input = '-InputObject $trace'; paths = @("@('input_emitted')"); extra = '' },
        [pscustomobject]@{ fn = 'Assert-HealthyResult'; getter = 'Get-ExactReplayBoolean'; input = '-InputObject $observation'; paths = @("@('game', 'dealer_hole_visible')"); extra = '' },
        [pscustomobject]@{ fn = 'Assert-HealthyResult'; getter = 'Get-ExactReplayObjectArray'; input = '-InputObject $observation'; paths = @("@('game', 'dealer_cards')"); extra = '-ElementType PSCustomObject' },
        [pscustomobject]@{ fn = 'New-CanonicalRecord'; getter = 'Get-ExactReplayPsCustomObject'; input = '-InputObject $Result'; paths = @("@('look', 'observable')", "@('trace')"); extra = '' },
        [pscustomobject]@{ fn = 'New-CanonicalRecord'; getter = 'Get-ExactReplayString'; input = '-InputObject $Result'; paths = @("@('command')"); extra = '' },
        [pscustomobject]@{ fn = 'New-CanonicalRecord'; getter = 'Get-ExactReplayPsCustomObject'; input = '-InputObject $observation'; paths = @("@('checkpoint')", "@('game')", "@('event_popup')", "@('talk')", "@('feedback')", "@('screen')"); extra = '' },
        [pscustomobject]@{ fn = 'New-CanonicalRecord'; getter = 'Get-ExactReplayBoolean'; input = '-InputObject $screen'; paths = @("@('run_report_visible')"); extra = '' },
        [pscustomobject]@{ fn = 'New-CanonicalRecord'; getter = 'Get-ExactReplayPsCustomObject'; input = '-InputObject $screen'; paths = @("@('run_report')"); extra = '' },
        [pscustomobject]@{ fn = 'New-CanonicalRecord'; getter = 'Get-ExactReplayPsCustomObject'; input = '-InputObject $runReport'; paths = @("@('outcome')"); extra = '' },
        [pscustomobject]@{ fn = 'New-CanonicalRecord'; getter = 'Get-ExactReplayString'; input = '-InputObject $checkpoint'; paths = @("@('screen')", "@('location_id')", "@('location_archetype')"); extra = '' },
        [pscustomobject]@{ fn = 'New-CanonicalRecord'; getter = 'Get-ExactReplayInt32'; input = '-InputObject $checkpoint'; paths = @("@('bankroll')", "@('chips')", "@('heat')"); extra = '' },
        [pscustomobject]@{ fn = 'New-CanonicalRecord'; getter = 'Get-ExactReplayString'; input = '-InputObject $game'; paths = @("@('game_id')", "@('phase')", "@('outcome_message')", "@('boss_tell')"); extra = '' },
        [pscustomobject]@{ fn = 'New-CanonicalRecord'; getter = 'Get-ExactReplayInt32'; input = '-InputObject $game'; paths = @("@('selected_stake')", "@('boss_hand_number')"); extra = '' },
        [pscustomobject]@{ fn = 'New-CanonicalRecord'; getter = 'Get-ExactReplayBoolean'; input = '-InputObject $game'; paths = @("@('dealer_hole_visible')"); extra = '' },
        [pscustomobject]@{ fn = 'New-CanonicalRecord'; getter = 'Get-ExactReplayObjectArray'; input = '-InputObject $game'; paths = @("@('player_hands')", "@('dealer_cards')"); extra = '-ElementType PSCustomObject' },
        [pscustomobject]@{ fn = 'New-CanonicalRecord'; getter = 'Get-ExactReplayPsCustomObject'; input = '-InputObject $game'; paths = @("@('dealer_up_card')"); extra = '' },
        [pscustomobject]@{ fn = 'New-CanonicalRecord'; getter = 'Get-ExactReplayBoolean'; input = '-InputObject $event'; paths = @("@('visible')", "@('render_valid')"); extra = '' },
        [pscustomobject]@{ fn = 'New-CanonicalRecord'; getter = 'Get-ExactReplayString'; input = '-InputObject $event'; paths = @("@('event_id')"); extra = '' },
        [pscustomobject]@{ fn = 'New-CanonicalRecord'; getter = 'Get-ExactReplayObjectArray'; input = '-InputObject $event'; paths = @("@('choice_ids')"); extra = '-ElementType String' },
        [pscustomobject]@{ fn = 'New-CanonicalRecord'; getter = 'Get-ExactReplayBoolean'; input = '-InputObject $talk'; paths = @("@('visible')", "@('expanded')", "@('render_valid')", "@('body_complete')", "@('typewriter_active')"); extra = '' },
        [pscustomobject]@{ fn = 'New-CanonicalRecord'; getter = 'Get-ExactReplayString'; input = '-InputObject $talk'; paths = @("@('event_id')", "@('summary')"); extra = '' },
        [pscustomobject]@{ fn = 'New-CanonicalRecord'; getter = 'Get-ExactReplayObjectArray'; input = '-InputObject $talk'; paths = @("@('choice_ids')"); extra = '-ElementType String' },
        [pscustomobject]@{ fn = 'New-CanonicalRecord'; getter = 'Get-ExactReplayBoolean'; input = '-InputObject $feedback'; paths = @("@('visible')"); extra = '' },
        [pscustomobject]@{ fn = 'New-CanonicalRecord'; getter = 'Get-ExactReplayString'; input = '-InputObject $feedback'; paths = @("@('title')", "@('text')"); extra = '' },
        [pscustomobject]@{ fn = 'New-CanonicalRecord'; getter = 'Get-ExactReplayString'; input = '-InputObject $transition'; paths = @("@('before_fingerprint')", "@('after_fingerprint')"); extra = '' },
        [pscustomobject]@{ fn = 'New-CanonicalRecord'; getter = 'Get-ExactReplayBoolean'; input = '-InputObject $transition'; paths = @("@('public_state_changed')", "@('screen_changed')", "@('location_changed')", "@('modal_changed')", "@('economy_changed')", "@('heat_changed')"); extra = '' },
        [pscustomobject]@{ fn = 'New-CanonicalRecord'; getter = 'Get-ExactReplayString'; input = '-InputObject $report'; paths = @("@('key')"); extra = '' },
        [pscustomobject]@{ fn = 'New-CanonicalRecord'; getter = 'Get-ExactReplayBoolean'; input = '-InputObject $report'; paths = @("@('won')"); extra = '' },
        [pscustomobject]@{ fn = 'Get-CleanSilverPlayersCardProjection'; getter = 'Get-ExactReplayPsCustomObject'; input = '-InputObject $script:LastObservation'; paths = @("@('talk')"); extra = '' },
        [pscustomobject]@{ fn = 'Get-CleanSilverPlayersCardProjection'; getter = 'Get-ExactReplayBoolean'; input = '-InputObject $talk'; paths = @("@('visible')", "@('expanded')", "@('render_valid')", "@('body_complete')", "@('typewriter_active')"); extra = '' },
        [pscustomobject]@{ fn = 'Get-CleanSilverPlayersCardProjection'; getter = 'Get-ExactReplayString'; input = '-InputObject $talk'; paths = @("@('event_id')", "@('summary')"); extra = '' },
        [pscustomobject]@{ fn = 'Get-CleanSilverPlayersCardProjection'; getter = 'Get-ExactReplayObjectArray'; input = '-InputObject $talk'; paths = @("@('choice_ids')"); extra = '-ElementType String' },
        [pscustomobject]@{ fn = 'Get-CleanSilverPlayersCardProjection'; getter = 'Get-ExactReplayObjectArray'; input = '-InputObject $script:LastResult'; paths = @("@('look', 'clickable', 'talk_choices')"); extra = '-ElementType PSCustomObject' },
        [pscustomobject]@{ fn = 'Get-CleanSilverPlayersCardProjection'; getter = 'Get-ExactReplayString'; input = '-InputObject $choice'; paths = @("@('id')", "@('event_id')", "@('label')"); extra = '' },
        [pscustomobject]@{ fn = 'Get-CleanSilverPlayersCardProjection'; getter = 'Get-ExactReplayBoolean'; input = '-InputObject $choice'; paths = @("@('enabled')"); extra = '' },
        [pscustomobject]@{ fn = 'Get-CleanSilverPlayersCardProjection'; getter = 'Get-ExactReplayString'; input = '-InputObject $script:LastObservation'; paths = @("@('environment', 'archetype_id')"); extra = '' },
        [pscustomobject]@{ fn = 'Get-PersistenceCheckpoint'; getter = 'Get-ExactReplayPsCustomObject'; input = '-InputObject $script:LastObservation'; paths = @("@('game')"); extra = '' },
        [pscustomobject]@{ fn = 'Get-PersistenceCheckpoint'; getter = 'Get-ExactReplayString'; input = '-InputObject $script:LastObservation'; paths = @("@('environment', 'id')", "@('environment', 'archetype_id')", "@('environment', 'world_node_id')"); extra = '' },
        [pscustomobject]@{ fn = 'Get-PersistenceCheckpoint'; getter = 'Get-ExactReplayString'; input = '-InputObject $game'; paths = @("@('game_id')", "@('phase')"); extra = '' },
        [pscustomobject]@{ fn = 'Get-PersistenceCheckpoint'; getter = 'Get-ExactReplayInt32'; input = '-InputObject $game'; paths = @("@('boss_hand_number')", "@('boss_player_stack')", "@('boss_rourke_stack')"); extra = '' },
        [pscustomobject]@{ fn = 'Assert-TerminalOutcome'; getter = 'Get-ExactReplayString'; input = '-InputObject $script:LastObservation'; paths = @("@('screen', 'screen')", "@('screen', 'run_report', 'outcome', 'key')"); extra = '' },
        [pscustomobject]@{ fn = 'Assert-TerminalOutcome'; getter = 'Get-ExactReplayBoolean'; input = '-InputObject $script:LastObservation'; paths = @("@('screen', 'run_report_visible')", "@('screen', 'run_report', 'outcome', 'won')"); extra = '' },
        [pscustomobject]@{ fn = 'Write-FinalPublicCheckpoint'; getter = 'Get-ExactReplayPsCustomObject'; input = '-InputObject $result'; paths = @("@('look', 'observable')"); extra = '' },
        [pscustomobject]@{ fn = 'Write-FinalPublicCheckpoint'; getter = 'Get-ExactReplayString'; input = '-InputObject $result'; paths = @("@('trace', 'after_fingerprint')"); extra = '' },
        [pscustomobject]@{ fn = 'Write-FinalPublicCheckpoint'; getter = 'Get-ExactReplayString'; input = '-InputObject $observation'; paths = @("@('checkpoint_fingerprint')", "@('screen', 'run_report', 'seed')"); extra = '' },
        [pscustomobject]@{ fn = 'Get-PlanningTableProjection'; getter = 'Get-ExactReplayObjectArray'; input = '-InputObject $script:LastResult'; paths = @("@('look', 'clickable', 'room_actions')"); extra = '-ElementType PSCustomObject' },
        [pscustomobject]@{ fn = 'Get-PlanningTableProjection'; getter = 'Get-ExactReplayString'; input = '-InputObject $row'; paths = @("@('emit_object_id')", "@('label')", "@('disabled_reason')"); extra = '' },
        [pscustomobject]@{ fn = 'Get-PlanningTableProjection'; getter = 'Get-ExactReplayBoolean'; input = '-InputObject $row'; paths = @("@('enabled')", "@('rendered')"); extra = '' },
        [pscustomobject]@{ fn = 'Assert-ExactFinalPublicCheckpoint'; getter = 'Get-ExactReplayString'; input = '-InputObject $Checkpoint'; paths = @('record_kind', 'observed_seed', 'outcome_key', 'public_fingerprint', 'checkpoint_fingerprint' | ForEach-Object { "@('$_')" }); extra = '' },
        [pscustomobject]@{ fn = 'Assert-ExactFinalPublicCheckpoint'; getter = 'Get-ExactReplayBoolean'; input = '-InputObject $Checkpoint'; paths = @("@('won')"); extra = '' },
        [pscustomobject]@{ fn = 'Assert-ExactFinalPublicCheckpoint'; getter = 'Get-ExactReplayInt32'; input = '-InputObject $Checkpoint'; paths = @('schema_version', 'bankroll', 'chips', 'heat' | ForEach-Object { "@('$_')" }); extra = '' }
    )

    $summaryStringFields = @(
        'role', 'requested_evidence_role', 'repeat_profile_scope',
        'fixed_repeat_qualification_authority', 'qualification', 'ending', 'seed', 'session',
        'outcome', 'observed_terminal_seed', 'transcript', 'transcript_sha256', 'money_curve',
        'money_curve_sha256', 'persistence_checkpoint_before',
        'persistence_checkpoint_before_sha256', 'persistence_checkpoint_after',
        'persistence_checkpoint_after_sha256', 'failure'
    )
    $groups += [pscustomobject]@{ fn = 'Assert-ExactReplayRunSummary'; getter = 'Get-ExactReplayString'; input = '-InputObject $Summary'; paths = @($summaryStringFields | ForEach-Object { "@('$_')" }); extra = '' }
    $groups += [pscustomobject]@{ fn = 'Assert-ExactReplayRunSummary'; getter = 'Get-ExactReplayBoolean'; input = '-InputObject $Summary'; paths = @('release_qualifying', 'passed', 'midpoint_save_relaunch_continue', 'persistence_checkpoint_equal', 'persistence_checkpoint_complete' | ForEach-Object { "@('$_')" }); extra = '' }
    $groups += [pscustomobject]@{ fn = 'Assert-ExactReplayRunSummary'; getter = 'Get-ExactReplayInt32'; input = '-InputObject $Summary'; paths = @('iteration', 'action_count' | ForEach-Object { "@('$_')" }); extra = '' }
    $groups += [pscustomobject]@{ fn = 'Assert-ExactReplayRunSummary'; getter = 'Get-ExactReplayPsCustomObject'; input = '-InputObject $Summary'; paths = @('replay_admission', 'heist_seed_preflight', 'heist_preflight_admission', 'heist_launch_setup', 'final_public_checkpoint' | ForEach-Object { "@('$_')" }); extra = '' }
    $finalStringFields = @(
        'check_id', 'role', 'requested_evidence_role', 'repeat_profile_scope',
        'fixed_repeat_qualification_authority', 'ending', 'seed', 'qualification',
        'public_observation_schema', 'evidence_root'
    )
    $groups += [pscustomobject]@{ fn = 'Assert-ExactReplayFinalSummary'; getter = 'Get-ExactReplayString'; input = '-InputObject $Summary'; paths = @($finalStringFields | ForEach-Object { "@('$_')" }); extra = '' }
    $groups += [pscustomobject]@{ fn = 'Assert-ExactReplayFinalSummary'; getter = 'Get-ExactReplayBoolean'; input = '-InputObject $Summary'; paths = @('deterministic', 'checkpoint_evidence_complete', 'release_qualifying' | ForEach-Object { "@('$_')" }); extra = '' }
    $groups += [pscustomobject]@{ fn = 'Assert-ExactReplayFinalSummary'; getter = 'Get-ExactReplayInt32'; input = '-InputObject $Summary'; paths = @('schema_version', 'repeat', 'public_observation_schema_version' | ForEach-Object { "@('$_')" }); extra = '' }
    $groups += [pscustomobject]@{ fn = 'Assert-ExactReplayFinalSummary'; getter = 'Get-ExactReplayPsCustomObject'; input = '-InputObject $Summary'; paths = @('replay_admission', 'heist_seed_preflight', 'heist_preflight_admission' | ForEach-Object { "@('$_')" }); extra = '' }
    $groups += [pscustomobject]@{ fn = 'Assert-ExactReplayFinalSummary'; getter = 'Get-ExactReplayObjectArray'; input = '-InputObject $Summary'; paths = @("@('observed_terminal_seeds')"); extra = '-ElementType String' }
    $groups += [pscustomobject]@{ fn = 'Assert-ExactReplayFinalSummary'; getter = 'Get-ExactReplayObjectArray'; input = '-InputObject $Summary'; paths = @("@('runs')"); extra = '-ElementType PSCustomObject' }

    foreach ($group in $groups) {
        $functionAst = $functionAsts[[string]$group.fn]
        foreach ($pathToken in $group.paths) {
            if (-not (Test-ExactGetterBinding `
                    -FunctionAst $functionAst `
                    -Getter ([string]$group.getter) `
                    -InputToken ([string]$group.input) `
                    -PathToken ([string]$pathToken) `
                    -ExtraToken ([string]$group.extra))) {
                return $false
            }
        }
    }

    $retainedValidatorSpecs = @(
        [pscustomobject]@{
            fn = 'Assert-ExactFinalPublicCheckpoint'
            input = '$Checkpoint'
            context = '$Context'
            keys = @(
                'schema_version', 'record_kind', 'observed_seed', 'outcome_key', 'won',
                'public_fingerprint', 'checkpoint_fingerprint', 'bankroll', 'chips', 'heat'
            )
            bindings = @(
                [pscustomobject]@{ field = 'schema_version'; target = 'schemaVersion'; getter = 'Get-ExactReplayInt32'; context = '"$Context schema version"' },
                [pscustomobject]@{ field = 'record_kind'; target = 'recordKind'; getter = 'Get-ExactReplayString'; context = '"$Context record kind"' },
                [pscustomobject]@{ field = 'observed_seed'; target = 'observedSeed'; getter = 'Get-ExactReplayString'; context = '"$Context observed seed"' },
                [pscustomobject]@{ field = 'outcome_key'; target = 'outcomeKey'; getter = 'Get-ExactReplayString'; context = '"$Context outcome key"' },
                [pscustomobject]@{ field = 'won'; target = 'won'; getter = 'Get-ExactReplayBoolean'; context = '"$Context win witness"' },
                [pscustomobject]@{ field = 'public_fingerprint'; target = 'publicFingerprint'; getter = 'Get-ExactReplayString'; context = '"$Context public fingerprint"' },
                [pscustomobject]@{ field = 'checkpoint_fingerprint'; target = 'checkpointFingerprint'; getter = 'Get-ExactReplayString'; context = '"$Context checkpoint fingerprint"' },
                [pscustomobject]@{ field = 'bankroll'; target = 'bankroll'; getter = 'Get-ExactReplayInt32'; context = '"$Context bankroll"' },
                [pscustomobject]@{ field = 'chips'; target = 'chips'; getter = 'Get-ExactReplayInt32'; context = '"$Context chips"' },
                [pscustomobject]@{ field = 'heat'; target = 'heat'; getter = 'Get-ExactReplayInt32'; context = '"$Context heat"' }
            )
        },
        [pscustomobject]@{
            fn = 'Assert-ExactReplayRunSummary'
            input = '$Summary'
            context = '$context'
            keys = @(
                'role', 'requested_evidence_role', 'repeat_profile_scope',
                'fixed_repeat_qualification_authority', 'release_qualifying', 'qualification',
                'replay_admission', 'iteration', 'ending', 'seed', 'session', 'passed', 'outcome',
                'observed_terminal_seed', 'action_count', 'midpoint_save_relaunch_continue',
                'heist_seed_preflight', 'heist_preflight_admission', 'heist_launch_setup',
                'transcript', 'transcript_sha256', 'money_curve', 'money_curve_sha256',
                'persistence_checkpoint_before', 'persistence_checkpoint_before_sha256',
                'persistence_checkpoint_after', 'persistence_checkpoint_after_sha256',
                'persistence_checkpoint_equal', 'persistence_checkpoint_complete',
                'final_public_checkpoint', 'failure'
            )
            bindings = @(
                [pscustomobject]@{ field = 'role'; target = 'role'; getter = 'Get-ExactReplayString'; context = '"$context role"' },
                [pscustomobject]@{ field = 'requested_evidence_role'; target = 'requestedRole'; getter = 'Get-ExactReplayString'; context = '"$context requested evidence role"' },
                [pscustomobject]@{ field = 'repeat_profile_scope'; target = 'profileScope'; getter = 'Get-ExactReplayString'; context = '"$context profile scope"' },
                [pscustomobject]@{ field = 'fixed_repeat_qualification_authority'; target = 'qualificationAuthority'; getter = 'Get-ExactReplayString'; context = '"$context qualification authority"' },
                [pscustomobject]@{ field = 'release_qualifying'; target = 'releaseQualificationValue'; getter = 'Get-ExactReplayBoolean'; context = '"$context release qualification"' },
                [pscustomobject]@{ field = 'qualification'; target = 'qualification'; getter = 'Get-ExactReplayString'; context = '"$context qualification label"' },
                [pscustomobject]@{ field = 'replay_admission'; target = 'null'; getter = 'Get-ExactReplayPsCustomObject'; context = '"$context replay admission"' },
                [pscustomobject]@{ field = 'iteration'; target = 'iterationValue'; getter = 'Get-ExactReplayInt32'; context = '"$context iteration"' },
                [pscustomobject]@{ field = 'ending'; target = 'endingValue'; getter = 'Get-ExactReplayString'; context = '"$context ending"' },
                [pscustomobject]@{ field = 'seed'; target = 'seedValue'; getter = 'Get-ExactReplayString'; context = '"$context seed"' },
                [pscustomobject]@{ field = 'session'; target = 'sessionValue'; getter = 'Get-ExactReplayString'; context = '"$context session"' },
                [pscustomobject]@{ field = 'passed'; target = 'passed'; getter = 'Get-ExactReplayBoolean'; context = '"$context passed witness"' },
                [pscustomobject]@{ field = 'outcome'; target = 'outcome'; getter = 'Get-ExactReplayString'; context = '"$context outcome"' },
                [pscustomobject]@{ field = 'observed_terminal_seed'; target = 'observedSeed'; getter = 'Get-ExactReplayString'; context = '"$context terminal seed"' },
                [pscustomobject]@{ field = 'action_count'; target = 'actionCount'; getter = 'Get-ExactReplayInt32'; context = '"$context action count"' },
                [pscustomobject]@{ field = 'midpoint_save_relaunch_continue'; target = 'midpointSaved'; getter = 'Get-ExactReplayBoolean'; context = '"$context midpoint witness"' },
                [pscustomobject]@{ field = 'heist_seed_preflight'; target = 'heistPreflight'; getter = 'Get-ExactReplayPsCustomObject'; context = '"$context Heist seed preflight"'; allow_null = $true },
                [pscustomobject]@{ field = 'heist_preflight_admission'; target = 'heistAdmission'; getter = 'Get-ExactReplayPsCustomObject'; context = '"$context Heist preflight admission"'; allow_null = $true },
                [pscustomobject]@{ field = 'heist_launch_setup'; target = 'heistLaunchSetup'; getter = 'Get-ExactReplayPsCustomObject'; context = '"$context Heist launch setup"'; allow_null = $true },
                [pscustomobject]@{ field = 'transcript'; target = 'transcript'; getter = 'Get-ExactReplayString'; context = '"$context transcript path"' },
                [pscustomobject]@{ field = 'transcript_sha256'; target = 'transcriptHash'; getter = 'Get-ExactReplayString'; context = '"$context transcript hash"' },
                [pscustomobject]@{ field = 'money_curve'; target = 'moneyCurve'; getter = 'Get-ExactReplayString'; context = '"$context money-curve path"' },
                [pscustomobject]@{ field = 'money_curve_sha256'; target = 'moneyHash'; getter = 'Get-ExactReplayString'; context = '"$context money-curve hash"' },
                [pscustomobject]@{ field = 'persistence_checkpoint_before'; target = 'checkpointBefore'; getter = 'Get-ExactReplayString'; context = '"$context pre-Continue checkpoint path"' },
                [pscustomobject]@{ field = 'persistence_checkpoint_before_sha256'; target = 'checkpointBeforeHash'; getter = 'Get-ExactReplayString'; context = '"$context pre-Continue checkpoint hash"' },
                [pscustomobject]@{ field = 'persistence_checkpoint_after'; target = 'checkpointAfter'; getter = 'Get-ExactReplayString'; context = '"$context post-Continue checkpoint path"' },
                [pscustomobject]@{ field = 'persistence_checkpoint_after_sha256'; target = 'checkpointAfterHash'; getter = 'Get-ExactReplayString'; context = '"$context post-Continue checkpoint hash"' },
                [pscustomobject]@{ field = 'persistence_checkpoint_equal'; target = 'checkpointEqual'; getter = 'Get-ExactReplayBoolean'; context = '"$context checkpoint equality witness"' },
                [pscustomobject]@{ field = 'persistence_checkpoint_complete'; target = 'checkpointComplete'; getter = 'Get-ExactReplayBoolean'; context = '"$context checkpoint completeness witness"' },
                [pscustomobject]@{ field = 'final_public_checkpoint'; target = 'finalCheckpoint'; getter = 'Get-ExactReplayPsCustomObject'; context = '"$context final checkpoint"'; allow_null = $true },
                [pscustomobject]@{ field = 'failure'; target = 'failure'; getter = 'Get-ExactReplayString'; context = '"$context failure text"' }
            )
        },
        [pscustomobject]@{
            fn = 'Assert-ExactReplayFinalSummary'
            input = '$Summary'
            context = '$context'
            keys = @(
                'schema_version', 'check_id', 'role', 'requested_evidence_role',
                'repeat_profile_scope', 'fixed_repeat_qualification_authority', 'ending', 'seed',
                'observed_terminal_seeds', 'repeat', 'deterministic', 'checkpoint_evidence_complete',
                'release_qualifying', 'qualification', 'replay_admission',
                'public_observation_schema', 'public_observation_schema_version',
                'heist_seed_preflight', 'heist_preflight_admission', 'evidence_root', 'runs'
            )
            bindings = @(
                [pscustomobject]@{ field = 'schema_version'; target = 'schemaVersion'; getter = 'Get-ExactReplayInt32'; context = '"$context schema version"' },
                [pscustomobject]@{ field = 'check_id'; target = 'checkId'; getter = 'Get-ExactReplayString'; context = '"$context check id"' },
                [pscustomobject]@{ field = 'role'; target = 'role'; getter = 'Get-ExactReplayString'; context = '"$context role"' },
                [pscustomobject]@{ field = 'requested_evidence_role'; target = 'requestedRole'; getter = 'Get-ExactReplayString'; context = '"$context requested evidence role"' },
                [pscustomobject]@{ field = 'repeat_profile_scope'; target = 'profileScope'; getter = 'Get-ExactReplayString'; context = '"$context profile scope"' },
                [pscustomobject]@{ field = 'fixed_repeat_qualification_authority'; target = 'authority'; getter = 'Get-ExactReplayString'; context = '"$context qualification authority"' },
                [pscustomobject]@{ field = 'ending'; target = 'endingValue'; getter = 'Get-ExactReplayString'; context = '"$context ending"' },
                [pscustomobject]@{ field = 'seed'; target = 'seedValue'; getter = 'Get-ExactReplayString'; context = '"$context seed"' },
                [pscustomobject]@{ field = 'observed_terminal_seeds'; target = 'observedSeeds'; getter = 'Get-ExactReplayObjectArray'; context = '"$context observed terminal seeds"'; element_type = 'String' },
                [pscustomobject]@{ field = 'repeat'; target = 'repeatValue'; getter = 'Get-ExactReplayInt32'; context = '"$context repeat count"' },
                [pscustomobject]@{ field = 'deterministic'; target = 'deterministicWitness'; getter = 'Get-ExactReplayBoolean'; context = '"$context deterministic witness"' },
                [pscustomobject]@{ field = 'checkpoint_evidence_complete'; target = 'checkpointComplete'; getter = 'Get-ExactReplayBoolean'; context = '"$context checkpoint completeness witness"' },
                [pscustomobject]@{ field = 'release_qualifying'; target = 'releaseQualificationValue'; getter = 'Get-ExactReplayBoolean'; context = '"$context release qualification"' },
                [pscustomobject]@{ field = 'qualification'; target = 'qualification'; getter = 'Get-ExactReplayString'; context = '"$context qualification label"' },
                [pscustomobject]@{ field = 'replay_admission'; target = 'null'; getter = 'Get-ExactReplayPsCustomObject'; context = '"$context replay admission"' },
                [pscustomobject]@{ field = 'public_observation_schema'; target = 'schemaName'; getter = 'Get-ExactReplayString'; context = '"$context public schema"' },
                [pscustomobject]@{ field = 'public_observation_schema_version'; target = 'publicSchemaVersion'; getter = 'Get-ExactReplayInt32'; context = '"$context public schema version"' },
                [pscustomobject]@{ field = 'heist_seed_preflight'; target = 'heistPreflight'; getter = 'Get-ExactReplayPsCustomObject'; context = '"$context Heist seed preflight"'; allow_null = $true },
                [pscustomobject]@{ field = 'heist_preflight_admission'; target = 'heistAdmission'; getter = 'Get-ExactReplayPsCustomObject'; context = '"$context Heist preflight admission"'; allow_null = $true },
                [pscustomobject]@{ field = 'evidence_root'; target = 'evidenceRootValue'; getter = 'Get-ExactReplayString'; context = '"$context evidence root"' },
                [pscustomobject]@{ field = 'runs'; target = 'runs'; getter = 'Get-ExactReplayObjectArray'; context = '"$context child runs"'; element_type = 'PSCustomObject' }
            )
        }
    )
    foreach ($validator in $retainedValidatorSpecs) {
        $functionAst = $functionAsts[[string]$validator.fn]
        if (-not (Test-NoDirectRetainedObjectAccess `
                -FunctionAst $functionAst `
                -VariableName ([string]$validator.input).Substring(1)) -or
            -not (Test-ExactKeyClosureCall `
                -FunctionAst $functionAst `
                -ValueExpression ([string]$validator.input) `
                -ExpectedKeys @($validator.keys) `
                -ContextExpression ([string]$validator.context))) {
            return $false
        }
        foreach ($binding in $validator.bindings) {
            $expectedArguments = [ordered]@{
                InputObject = [string]$validator.input
                Path = "@('$([string]$binding.field)')"
                Context = [string]$binding.context
            }
            if ($binding.PSObject.Properties.Name -ccontains 'element_type') {
                $expectedArguments['ElementType'] = [string]$binding.element_type
            }
            if ($binding.PSObject.Properties.Name -ccontains 'allow_null' -and $binding.allow_null) {
                $expectedArguments['AllowNull'] = $null
            }
            if (-not (Test-ExactAssignedGetterBinding `
                    -FunctionAst $functionAst `
                    -TargetVariable ([string]$binding.target) `
                    -Getter ([string]$binding.getter) `
                    -ExpectedArguments $expectedArguments)) {
                return $false
            }
        }
    }

    foreach ($token in @(
        'Assert-ExactReplayObjectKeys -Value $Checkpoint',
        'Assert-ExactReplayObjectKeys -Value $Summary',
        'Assert-ExactFinalPublicCheckpoint -Checkpoint $finalObject',
        '[Array]::Sort($choiceIds, [StringComparer]::Ordinal)',
        '$uniqueChoiceIds.Add($choiceId)',
        '$_.choice_id -ceq ''lock_the_count'' -and $_.enabled -and $_.rendered'
    )) {
        if ($Source.IndexOf($token, [StringComparison]::Ordinal) -lt 0) { return $false }
    }
    if (-not [regex]::IsMatch(
            [string]$functionSources['New-CanonicalRecord'],
            '(?m)^\s*\$talkTypewriterPresent\s*=\s*Test-ReplayPathPresent\s+-InputObject\s+\$talk\s+-Path\s+@\(''typewriter_active''\)(?=\s|$)'
        )) {
        return $false
    }

    $topLevel = Get-PowerShellTopLevelSource -Analysis $analysis
    foreach ($token in @(
        '$runReceipt = Assert-ExactReplayRunSummary',
        '-Summary $runSummaryObject',
        '-ExpectedEnding $Ending',
        '-ExpectedSeed $Seed',
        '-ExpectedIteration ([int32]$iteration)',
        '$runSummaryObject | ConvertTo-Json',
        '$validatedRunReceipts += $runReceipt',
        '$latestRunReceipt = $validatedRunReceipts[$validatedRunReceipts.Count - 1]',
        '$_.persistence_checkpoint_complete -isnot [bool] -or -not $_.persistence_checkpoint_complete',
        '$finalSummaryObject = [pscustomobject]$finalSummary',
        'Assert-ExactReplayFinalSummary',
        '-Summary $finalSummaryObject',
        '-ExpectedRepeat ([int32]$Repeat)',
        '$finalSummaryObject | ConvertTo-Json'
    )) {
        if ($topLevel.IndexOf($token, [StringComparison]::Ordinal) -lt 0) { return $false }
    }
    if ([regex]::IsMatch($topLevel, '\[(?:bool|string|int|int32)\]\s*\$runSummaries|\[(?:bool|string|int|int32)\]\s*\$runSummaries\[') -or
        [regex]::IsMatch($topLevel, 'Where-Object\s*\{\s*-not\s+\[bool\]\$_.persistence_checkpoint_complete')) {
        return $false
    }
    return $true
}


foreach ($path in @(
    $RunnerPath, $ReplayPolicyPath, $EvidenceAdmissionPath, $EvidenceAdmissionContractPath,
    $HeistSeedPreflightPath, $FinalEvidencePath, $LauncherPath, $BridgePath, $SanitizerPath,
    $ObservationContractPath, $FoundationMainPath, $FoundationHudBarPath,
    $FoundationScreenBuilderPath, $PixelSceneCanvasPath, $TalkDockPath, $RunStatePath,
    $RunActionServicePath, $CrewRunFacadePath, $WorldMapPath, $FoundationWorldTestPath,
    $CrewHeistTestPath, $UiMainFlowTestPath,
    $EventsPath, $ServicesPath, $ArchetypesPath
)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        Add-Failure "Required rw06_2 source is missing: $path"
    }
}

if ($failures.Count -eq 0) {
    Assert-PowerShellParses $RunnerPath
    Assert-PowerShellParses $ReplayPolicyPath
    Assert-PowerShellParses $EvidenceAdmissionPath
    Assert-PowerShellParses $EvidenceAdmissionContractPath
    Assert-PowerShellParses $HeistSeedPreflightPath
    Assert-PowerShellParses $LauncherPath

    $runner = Get-Content -LiteralPath $RunnerPath -Raw
    $replayPolicy = Get-Content -LiteralPath $ReplayPolicyPath -Raw
    $evidenceAdmission = Get-Content -LiteralPath $EvidenceAdmissionPath -Raw
    $evidenceAdmissionContract = Get-Content -LiteralPath $EvidenceAdmissionContractPath -Raw
    $heistSeedPreflight = Get-Content -LiteralPath $HeistSeedPreflightPath -Raw
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
    $runActionService = Get-Content -LiteralPath $RunActionServicePath -Raw
    $crewRunFacade = Get-Content -LiteralPath $CrewRunFacadePath -Raw
    $worldMap = Get-Content -LiteralPath $WorldMapPath -Raw
    $foundationWorldTest = Get-Content -LiteralPath $FoundationWorldTestPath -Raw
    $crewHeistTest = Get-Content -LiteralPath $CrewHeistTestPath -Raw
    $uiMainFlowTest = Get-Content -LiteralPath $UiMainFlowTestPath -Raw

    $validEndingNormalizationFixture = @'
$Ending = $Ending.ToLowerInvariant()
$EvidenceRole = $EvidenceRole.ToLowerInvariant()
$script:ReplayAdmission = Resolve-Rw062ReplayAdmission
if ($Ending -ceq 'heist') { Invoke-HeistSeedPreflight }
'@
    $hostileMixedCaseEndingFixture = @'
$Ending = $Ending.ToLowerInvariant()
$script:ReplayAdmission = Resolve-Rw062ReplayAdmission
if ($Ending -ceq 'heist') { Invoke-HeistSeedPreflight }
'@
    if (-not (Test-EndingNormalizationSequence -Source $validEndingNormalizationFixture) -or
        -not (Test-EndingNormalizationSequence -Source $runner)) {
        Add-Failure 'Ending and evidence-role inputs must normalize once before fail-closed admission or Heist preflight.'
    }
    if (Test-EndingNormalizationSequence -Source $hostileMixedCaseEndingFixture) {
        Add-Failure 'A mixed-case evidence-role hostile without normalization did not fail closed.'
    }

    $validExclusiveEvidenceFixture = @'
function New-ExclusiveEvidenceDirectory {
    $absolutePath = [IO.Path]::GetFullPath($Path)
    if (Test-Path -LiteralPath $absolutePath) { throw 'refusing stale artifact reuse' }
    [void](New-Item -ItemType Directory -Path $absolutePath -ErrorAction Stop)
}
'@
    $hostileForcedEvidenceFixture = $validExclusiveEvidenceFixture.Replace('-ErrorAction Stop)', '-Force -ErrorAction Stop)')
    $hostileUncheckedEvidenceFixture = $validExclusiveEvidenceFixture.Replace("if (Test-Path -LiteralPath `$absolutePath) { throw 'refusing stale artifact reuse' }", '')
    if (-not (Test-ExclusiveEvidenceDirectorySource -Source $validExclusiveEvidenceFixture) -or
        -not (Test-ExclusiveEvidenceDirectorySource -Source $runner)) {
        Add-Failure 'Invocation and run evidence directories must be absolute, new, and created without stale-target reuse.'
    }
    foreach ($hostileEvidenceFixture in @($hostileForcedEvidenceFixture, $hostileUncheckedEvidenceFixture)) {
        if (Test-ExclusiveEvidenceDirectorySource -Source $hostileEvidenceFixture) {
            Add-Failure 'A stale-evidence directory hostile did not fail closed.'
        }
    }
    Assert-Match $runner '(?s)\$invocationRoot\s*=\s*New-ExclusiveEvidenceDirectory\s+-Path.*?\$script:RunRoot\s*=\s*New-ExclusiveEvidenceDirectory\s+-Path' 'Both invocation and per-run evidence roots must use exclusive non-reusing creation.'

    if (-not (Test-CleanSilverPersistenceSource -Source $runner)) {
        Add-Failure 'Clean Save/Continue must retain the exact rendered Silver-to-Gold Cage ledger and its public controls before and after process exit.'
    }
    $hostilePrivateCleanState = $runner.Replace("Get-ExactReplayString -InputObject `$talk -Path @('summary')", 'Get-PrivatePlayersCardTier')
    $hostileMissingCleanAfter = $runner.Replace('clean_players_card = $afterCleanPlayersCard', 'clean_players_card = $null')
    foreach ($hostileCleanFixture in @($hostilePrivateCleanState, $hostileMissingCleanAfter)) {
        if ($hostileCleanFixture -ceq $runner -or (Test-CleanSilverPersistenceSource -Source $hostileCleanFixture)) {
            Add-Failure 'A missing or private Clean Silver persistence hostile did not fail closed.'
        }
    }

    if (-not (Test-CheckpointDeterminismFailureSource -Source $runner)) {
        Add-Failure 'Repeat-2 determinism must compare both retained checkpoint hashes inside the outward mismatch throw.'
    }
    $hostileCheckpointDeterminism = $runner.Replace('$currentCheckpointBeforeHash -cne $referenceCheckpointBeforeHash', '$currentCheckpointBeforeHash -ceq $currentCheckpointBeforeHash')
    if ($hostileCheckpointDeterminism -ceq $runner -or (Test-CheckpointDeterminismFailureSource -Source $hostileCheckpointDeterminism)) {
        Add-Failure 'A repeat mismatch that omits one retained checkpoint hash did not fail closed.'
    }

    if (-not (Test-MidpointCheckpointCompletenessSource -Source $runner)) {
        Add-Failure 'Per-run checkpoint completeness must require the current run to have reached its authenticated midpoint.'
    }
    $hostileStaleCheckpointCompleteness = $runner.Replace('$checkpointEvidenceComplete = $script:MidpointSaved -and', '$checkpointEvidenceComplete =')
    if ($hostileStaleCheckpointCompleteness -ceq $runner -or (Test-MidpointCheckpointCompletenessSource -Source $hostileStaleCheckpointCompleteness)) {
        Add-Failure 'A stale equal-file completeness hostile without MidpointSaved did not fail closed.'
    }

    $validDirectDevelopmentQualificationFixture = @'
$runSummary = [ordered]@{
    role = 'child_development_iteration'
    repeat_profile_scope = 'shared_caller_appdata'
    fixed_repeat_qualification_authority = 'outer_independent_profile_aggregate_only'
    release_qualifying = $false
    qualification = 'non_qualifying_development_iteration'
}
$deterministic = $Repeat -ceq 2 -and
    @($validatedRunReceipts | Select-Object -ExpandProperty transcript_sha256 -Unique).Count -ceq 1 -and
    @($validatedRunReceipts | Select-Object -ExpandProperty money_curve_sha256 -Unique).Count -ceq 1 -and
    @($validatedRunReceipts | Select-Object -ExpandProperty persistence_checkpoint_before_sha256 -Unique).Count -ceq 1 -and
    @($validatedRunReceipts | Select-Object -ExpandProperty persistence_checkpoint_after_sha256 -Unique).Count -ceq 1 -and
    @($validatedRunReceipts | ForEach-Object { $_.final_public_checkpoint | ConvertTo-Json -Depth 10 -Compress } | Select-Object -Unique).Count -ceq 1
$checkpointEvidenceComplete = $true
$finalSummary = [ordered]@{
    role = 'child_development_run'
    repeat_profile_scope = 'shared_caller_appdata'
    fixed_repeat_qualification_authority = 'outer_independent_profile_aggregate_only'
    deterministic = $deterministic
    release_qualifying = $false
    qualification = 'non_qualifying_development_run'
}
'@
    if (-not (Test-DirectDevelopmentQualificationSource -Source $validDirectDevelopmentQualificationFixture) -or
        -not (Test-DirectDevelopmentQualificationSource -Source $runner)) {
        Add-Failure 'The direct replay must stay explicitly child/development/non-qualifying even when Repeat=2 is deterministic.'
    }
    $directQualificationValidFixtures = 2
    $hostileDirectQualificationFixtures = @(
        $validDirectDevelopmentQualificationFixture.Replace('release_qualifying = $false', 'release_qualifying = $true'),
        $validDirectDevelopmentQualificationFixture.Replace('release_qualifying = $false', 'release_qualifying = $deterministic'),
        $validDirectDevelopmentQualificationFixture.Replace('release_qualifying = $false', 'release_qualifying = ($Repeat -ceq 2)'),
        $validDirectDevelopmentQualificationFixture.Replace('release_qualifying = $false', 'release_qualifying = $releaseQualifying'),
        $validDirectDevelopmentQualificationFixture.Replace("qualification = 'non_qualifying_development_run'", "qualification = 'two_identical_repeats'"),
        $validDirectDevelopmentQualificationFixture.Replace("role = 'child_development_run'", "role = 'fixed_route_repeat'"),
        $validDirectDevelopmentQualificationFixture.Replace("fixed_repeat_qualification_authority = 'outer_independent_profile_aggregate_only'", "fixed_repeat_qualification_authority = 'direct_runner'"),
        $validDirectDevelopmentQualificationFixture.Replace('deterministic = $deterministic', 'deterministic = $true'),
        $validDirectDevelopmentQualificationFixture.Replace("role = 'child_development_iteration'", "role = 'fixed_route_repeat'"),
        $validDirectDevelopmentQualificationFixture.Replace("qualification = 'non_qualifying_development_iteration'", "qualification = 'fixed_route_repeat'"),
        $validDirectDevelopmentQualificationFixture.Replace('$deterministic = $Repeat -ceq 2 -and', '$deterministic = $Repeat -ceq 2 -or'),
        $validDirectDevelopmentQualificationFixture.Replace('@($validatedRunReceipts | Select-Object -ExpandProperty persistence_checkpoint_after_sha256 -Unique).Count -ceq 1 -and', '$true -and'),
        $validDirectDevelopmentQualificationFixture.Replace('release_qualifying = $false', "fixed_repeat_qualifying = `$true`n    release_qualifying = `$false"),
        ('$runSummary = [ordered]@{ fixed_repeat_qualifying = $true }' + [Environment]::NewLine + $validDirectDevelopmentQualificationFixture),
        ('$inlineSummary = [ordered]@{ release_qualifying = $true }' + [Environment]::NewLine + $validDirectDevelopmentQualificationFixture),
        ($validDirectDevelopmentQualificationFixture + [Environment]::NewLine + '$finalSummary.release_qualifying = $true'),
        ($validDirectDevelopmentQualificationFixture + [Environment]::NewLine + '$alias = $finalSummary; $alias[''release_qualifying''] = $true'),
        ('$env:APPDATA = ''C:\hostile-profile''' + [Environment]::NewLine + $validDirectDevelopmentQualificationFixture),
        ('[Environment]::SetEnvironmentVariable(''LOCALAPPDATA'', ''C:\hostile-profile'', ''Process'')' + [Environment]::NewLine + $validDirectDevelopmentQualificationFixture),
        ('Start-Process pwsh -Environment @{ APPDATA = ''C:\hostile-profile'' }' + [Environment]::NewLine + $validDirectDevelopmentQualificationFixture),
        ("Start-Process pwsh ```r`n    -Environment @{ APPDATA = 'C:\hostile-profile' }" + [Environment]::NewLine + $validDirectDevelopmentQualificationFixture),
        ('$psi = [Diagnostics.ProcessStartInfo]::new(); $psi.Environment[''LOCALAPPDATA''] = ''C:\hostile-profile''' + [Environment]::NewLine + $validDirectDevelopmentQualificationFixture),
        $validDirectDevelopmentQualificationFixture.Replace("qualification = 'non_qualifying_development_run'", "qualification_alias = 'fixed_route_repeat'`n    qualification = 'non_qualifying_development_run'")
    )
    $directQualificationHostileFixtures = $hostileDirectQualificationFixtures.Count
    foreach ($hostileDirectQualificationFixture in $hostileDirectQualificationFixtures) {
        if ($hostileDirectQualificationFixture -ceq $validDirectDevelopmentQualificationFixture -or
            (Test-DirectDevelopmentQualificationSource -Source $hostileDirectQualificationFixture)) {
            Add-Failure 'A hardcoded or direct fixed-repeat qualification hostile did not fail closed.'
        }
    }

    if (-not (Test-ReplayExactEvidenceTypeSource -Source $runner)) {
        Add-Failure 'Replay retained evidence must validate every original bridge scalar, object, and array type before projection or qualification.'
    }
    else {
        $bridgeExactTypeValidFixtures = 1
    }
    $hostileExactTypeMutations = @(
        [pscustomobject]@{ name = 'path reader enumerates one-element arrays'; needle = 'Write-Output -NoEnumerate $current'; replacement = 'return $current' },
        [pscustomobject]@{ name = 'boolean getter accepts coercion'; needle = 'throw "$Context must be an exact boolean."'; replacement = '$null = $value' },
        [pscustomobject]@{ name = 'Int32 getter accepts coercion'; needle = 'throw "$Context must be an exact Int32."'; replacement = '$null = $value' },
        [pscustomobject]@{ name = 'array getter accepts scalar'; needle = 'throw "$Context must be an exact JSON array."'; replacement = '$null = $value' },
        [pscustomobject]@{ name = 'string-array getter accepts wrong element'; needle = 'throw "$Context contains a non-string element at index $index."'; replacement = '$null = $value[$index]' },
        [pscustomobject]@{ name = 'object-array getter accepts wrong element'; needle = 'throw "$Context contains a non-object element at index $index."'; replacement = '$null = $value[$index]' },
        [pscustomobject]@{ name = 'pause owner boolean bypass'; needle = '$applicationPaused = Get-ExactReplayBoolean'; replacement = '$applicationPaused = Get-Value' },
        [pscustomobject]@{ name = 'healthy accepted boolean bypass'; needle = '$accepted = Get-ExactReplayBoolean'; replacement = '$accepted = Get-Value' },
        [pscustomobject]@{ name = 'healthy pause object bypass'; needle = '$pauseBefore = Get-ExactReplayPsCustomObject'; replacement = '$pauseBefore = Get-Value' },
        [pscustomobject]@{ name = 'healthy log-alert array bypass'; needle = '$alerts = Get-ExactReplayObjectArray'; replacement = '$alerts = Get-Array' },
        [pscustomobject]@{ name = 'healthy schema-version bypass'; needle = '$schemaVersionValue = Get-ExactReplayInt32'; replacement = '$schemaVersionValue = Get-Value' },
        [pscustomobject]@{ name = 'healthy trace command bypass'; needle = '$traceCommand = Get-ExactReplayString'; replacement = '$traceCommand = Get-Value' },
        [pscustomobject]@{ name = 'healthy dealer-card array bypass'; needle = '$dealerCards = Get-ExactReplayObjectArray'; replacement = '$dealerCards = Get-Array' },
        [pscustomobject]@{ name = 'canonical command string bypass'; needle = 'command = Get-ExactReplayString -InputObject $Result'; replacement = 'command = Get-Value -InputObject $Result' },
        [pscustomobject]@{ name = 'canonical checkpoint Int32 bypass'; needle = 'bankroll = Get-ExactReplayInt32 -InputObject $checkpoint'; replacement = 'bankroll = Get-Value -InputObject $checkpoint' },
        [pscustomobject]@{ name = 'canonical dealer boolean bypass'; needle = 'dealer_hole_visible = Get-ExactReplayBoolean -InputObject $game'; replacement = 'dealer_hole_visible = Get-Value -InputObject $game' },
        [pscustomobject]@{ name = 'canonical player-hands array bypass'; needle = 'player_hands = Get-ExactReplayObjectArray -InputObject $game'; replacement = 'player_hands = Get-Array -InputObject $game' },
        [pscustomobject]@{ name = 'Clean choice-id array bypass'; needle = '$choiceIds = Get-ExactReplayObjectArray'; replacement = '$choiceIds = Get-Array' },
        [pscustomobject]@{ name = 'Clean location string bypass'; needle = '$locationArchetype = Get-ExactReplayString'; replacement = '$locationArchetype = Get-Value' },
        [pscustomobject]@{ name = 'persistence boss-hand Int32 bypass'; needle = "boss_hand_number = Get-ExactReplayInt32 -InputObject `$game -Path @('boss_hand_number') -Context 'Persistence checkpoint boss hand number' -AllowMissing"; replacement = "boss_hand_number = Get-Value -InputObject `$game -Path @('boss_hand_number') -Context 'Persistence checkpoint boss hand number' -AllowMissing" },
        [pscustomobject]@{ name = 'terminal outcome string bypass'; needle = '$outcome = Get-ExactReplayString -InputObject $script:LastObservation'; replacement = '$outcome = Get-Value -InputObject $script:LastObservation' },
        [pscustomobject]@{ name = 'final observed-seed string bypass'; needle = '$observedSeed = Get-ExactReplayString -InputObject $observation'; replacement = '$observedSeed = Get-Value -InputObject $observation' },
        [pscustomobject]@{ name = 'planning emit-id string bypass'; needle = '$emitId = Get-ExactReplayString -InputObject $row'; replacement = '$emitId = Get-Value -InputObject $row' },
        [pscustomobject]@{ name = 'planning ordinal sort removed'; needle = '[Array]::Sort($choiceIds, [StringComparer]::Ordinal)'; replacement = '$choiceIds = @($choiceIds)' },
        [pscustomobject]@{ name = 'visible talk typewriter presence removed'; needle = '$talkTypewriterPresent = Test-ReplayPathPresent'; replacement = '$talkTypewriterPresent = Test-ReplayPathPresentUnsafe' },
        [pscustomobject]@{ name = 'final checkpoint validation removed'; needle = "Assert-ExactFinalPublicCheckpoint -Checkpoint `$finalObject -ExpectedSeed `$Seed -Context 'Final public checkpoint'"; replacement = '$null = $finalObject' },
        [pscustomobject]@{ name = 'child summary validation removed'; needle = '$runReceipt = Assert-ExactReplayRunSummary'; replacement = '$runReceipt = New-UncheckedRunReceipt' },
        [pscustomobject]@{ name = 'checkpoint completeness bool coercion restored'; needle = '-not $_.persistence_checkpoint_complete'; replacement = '-not [bool]$_.persistence_checkpoint_complete' },
        [pscustomobject]@{ name = 'aggregate summary repeat detached'; needle = '-ExpectedRepeat ([int32]$Repeat)'; replacement = '-ExpectedRepeat ([int32]1)' },
        [pscustomobject]@{
            name = 'run summary decoy exact getter with direct member authority'
            function = 'Assert-ExactReplayRunSummary'
            needle = '$requestedRole = Get-ExactReplayString -InputObject $Summary -Path @(''requested_evidence_role'') -Context "$context requested evidence role"'
            replacement = '$null = Get-ExactReplayString -InputObject $Summary -Path @(''requested_evidence_role'') -Context "$context requested evidence role"' + [Environment]::NewLine + '    $requestedRole = $Summary.requested_evidence_role'
        },
        [pscustomobject]@{
            name = 'run summary misleading context preserves wrong path token'
            function = 'Assert-ExactReplayRunSummary'
            needle = '$requestedRole = Get-ExactReplayString -InputObject $Summary -Path @(''requested_evidence_role'') -Context "$context requested evidence role"'
            replacement = '$requestedRole = Get-ExactReplayString -InputObject $Summary -Path @(''role'') -Context "$context requested evidence role @(''requested_evidence_role'')"'
        },
        [pscustomobject]@{
            name = 'run summary boolean decoy exact getter with coercive member authority'
            function = 'Assert-ExactReplayRunSummary'
            needle = '$passed = Get-ExactReplayBoolean -InputObject $Summary -Path @(''passed'') -Context "$context passed witness"'
            replacement = '$null = Get-ExactReplayBoolean -InputObject $Summary -Path @(''passed'') -Context "$context passed witness"' + [Environment]::NewLine + '    $passed = [bool]$Summary.passed'
        },
        [pscustomobject]@{ name = 'checkpoint key closure removed'; function = 'Assert-ExactFinalPublicCheckpoint'; needle = 'Assert-ExactReplayObjectKeys'; replacement = 'Assert-ExactReplayPsCustomObject' },
        [pscustomobject]@{ name = 'run summary key closure removed'; function = 'Assert-ExactReplayRunSummary'; needle = 'Assert-ExactReplayObjectKeys'; replacement = 'Assert-ExactReplayPsCustomObject' },
        [pscustomobject]@{ name = 'final summary key closure removed'; function = 'Assert-ExactReplayFinalSummary'; needle = 'Assert-ExactReplayObjectKeys'; replacement = 'Assert-ExactReplayPsCustomObject' },
        [pscustomobject]@{
            name = 'checkpoint key closure reordered'
            function = 'Assert-ExactFinalPublicCheckpoint'
            needle = "        'schema_version'," + [Environment]::NewLine + "        'record_kind',"
            replacement = "        'record_kind'," + [Environment]::NewLine + "        'schema_version',"
        },
        [pscustomobject]@{
            name = 'run summary key closure reordered'
            function = 'Assert-ExactReplayRunSummary'
            needle = "        'role'," + [Environment]::NewLine + "        'requested_evidence_role',"
            replacement = "        'requested_evidence_role'," + [Environment]::NewLine + "        'role',"
        },
        [pscustomobject]@{
            name = 'final summary key closure reordered'
            function = 'Assert-ExactReplayFinalSummary'
            needle = "        'schema_version'," + [Environment]::NewLine + "        'check_id',"
            replacement = "        'check_id'," + [Environment]::NewLine + "        'schema_version',"
        },
        [pscustomobject]@{
            name = 'checkpoint key closure accepts extra authority field'
            function = 'Assert-ExactFinalPublicCheckpoint'
            needle = "        'bankroll'," + [Environment]::NewLine + "        'chips'," + [Environment]::NewLine + "        'heat'"
            replacement = "        'bankroll'," + [Environment]::NewLine + "        'chips'," + [Environment]::NewLine + "        'heat'," + [Environment]::NewLine + "        'qualification_authority'"
        },
        [pscustomobject]@{
            name = 'run summary key closure accepts extra authority field'
            function = 'Assert-ExactReplayRunSummary'
            needle = "        'final_public_checkpoint'," + [Environment]::NewLine + "        'failure'"
            replacement = "        'final_public_checkpoint'," + [Environment]::NewLine + "        'failure'," + [Environment]::NewLine + "        'fixed_repeat_qualifying'"
        },
        [pscustomobject]@{
            name = 'final summary key closure accepts extra authority field'
            function = 'Assert-ExactReplayFinalSummary'
            needle = "        'evidence_root'," + [Environment]::NewLine + "        'runs'"
            replacement = "        'evidence_root'," + [Environment]::NewLine + "        'runs'," + [Environment]::NewLine + "        'fixed_repeat_qualifying'"
        }
    )
    $bridgeExactTypeHostileFixtures = $hostileExactTypeMutations.Count
    foreach ($case in $hostileExactTypeMutations) {
        try {
            if ($case.PSObject.Properties.Name -ccontains 'function') {
                $hostileSource = Replace-PowerShellFunctionSourceOnce `
                    -Source $runner `
                    -FunctionName ([string]$case.function) `
                    -Needle ([string]$case.needle) `
                    -Replacement ([string]$case.replacement)
            }
            else {
                $hostileSource = Replace-SourceOnce `
                    -Source $runner `
                    -Needle ([string]$case.needle) `
                    -Replacement ([string]$case.replacement)
            }
            $hostileAnalysis = ConvertTo-PowerShellAnalysis -Source $hostileSource
            if ($hostileAnalysis.parse_errors.Count -cne 0) {
                Add-Failure "Exact-type hostile '$($case.name)' did not remain valid PowerShell: $($hostileAnalysis.parse_errors[0].Message)"
                continue
            }
            if (Test-ReplayExactEvidenceTypeSource -Source $hostileSource) {
                Add-Failure "Exact-type source contract accepted hostile '$($case.name)'."
            }
        }
        catch {
            Add-Failure "Exact-type hostile '$($case.name)' could not be evaluated: $($_.Exception.Message)"
        }
    }

    $worldMapNormalize = Get-GDScriptFunctionSource -Source $worldMap -Name 'normalize'
    $worldMapTopologyNormalize = Get-GDScriptFunctionSource -Source $worldMap -Name 'normalize_topology'
    $worldMapTravelTargets = Get-GDScriptFunctionSource -Source $worldMap -Name 'travel_target_ids'
    $worldMapBeachEnforcement = Get-GDScriptFunctionSource -Source $worldMap -Name '_enforce_beach_gateway_access'
    $foundationBeachRegression = Get-GDScriptFunctionSource -Source $foundationWorldTest -Name '_world_map_beach_route_gate_ok'
    $uiBeachRegression = Get-GDScriptFunctionSource -Source $uiMainFlowTest -Name '_check_beach_return_travel_choice'

    if (-not [string]::IsNullOrWhiteSpace($worldMapNormalize)) {
        Assert-Contains $worldMapNormalize 'return _enforce_beach_gateway_access(normalized)' 'World-map normalization must repair legacy hidden Beach state while the player is on the Delta Queen.'
    }
    if (-not [string]::IsNullOrWhiteSpace($worldMapTopologyNormalize)) {
        Assert-Contains $worldMapTopologyNormalize 'return _enforce_beach_gateway_access(normalized)' 'Topology-only Continue/UI projection must repair legacy hidden Beach state.'
    }
    if (-not [string]::IsNullOrWhiteSpace($worldMapBeachEnforcement)) {
        Assert-Match $worldMapBeachEnforcement '(?s)effective_source_id\s*==\s*BEACH_GATEWAY_ID.*?state.*?STATE_REVEALED.*?seen.*?true.*?unlocked.*?true.*?route_spawn_open.*?true' 'Delta-current normalization must reveal and unlock Beach through the production map model.'
    }
    if (-not [string]::IsNullOrWhiteSpace($worldMapTravelTargets)) {
        Assert-Match $worldMapTravelTargets '(?s)normalized\s*=\s*_enforce_beach_gateway_access\(normalized,\s*source_id\)' 'Production target selection must enforce the Beach invariant for an explicit Delta Queen source.'
        $genericPriorityIndex = $worldMapTravelTargets.IndexOf('result = _ensure_priority_targets', [StringComparison]::Ordinal)
        $mandatoryBeachIndex = $worldMapTravelTargets.IndexOf('if source_id == BEACH_GATEWAY_ID and total_limit > 0:', [StringComparison]::Ordinal)
        if ($genericPriorityIndex -lt 0 -or $mandatoryBeachIndex -le $genericPriorityIndex) {
            Add-Failure 'Mandatory Delta Queen Beach promotion must run after generic Grand/event/Tier-2 priority ordering so the three-card cap cannot evict it.'
        }
        Assert-Match $worldMapTravelTargets '(?s)if\s+source_id\s*==\s*BEACH_GATEWAY_ID\s+and\s+total_limit\s*>\s*0:.*?_ensure_visible_neighbor_target\(result,\s*source_id,\s*BEACH_ID,\s*total_limit' 'Production target selection must keep exactly one mandatory Beach connector inside the ordinary total-card cap.'
    }
    if (-not [string]::IsNullOrWhiteSpace($foundationBeachRegression)) {
        Assert-NotMatch $foundationBeachRegression 'WorldMapScript\.unlock_nodes\s*\([^\r\n]*beach' 'Foundation Q-011 coverage must not manually unlock Beach.'
        Assert-Match $foundationBeachRegression '(?s)node_id\s*==\s*"beach".*?STATE_HIDDEN.*?route_spawn_open.*?false.*?travel_target_ids\(no_beach_control,\s*"delta_queen",\s*32,\s*32\).*?expanded_competitors\.size\(\)\s*<=\s*WorldMapScript\.TRAVEL_TOTAL_TARGET_LIMIT.*?travel_target_ids\(gated_map,\s*"delta_queen"\).*?count\("beach"\)\s*!=\s*1' 'Foundation Q-011 coverage must drive a hidden Beach and more than three eligible competitors through the real capped target selector.'
        Assert-Match $foundationBeachRegression '(?s)travel_lock_remaining.*?2.*?travel_route_status\(access_route\).*?available.*?true.*?travel_lock_remaining.*?0.*?travel_route_status\(access_route\)' 'Foundation Q-011 coverage must keep Beach subject to the ordinary global travel lock and enable it after the lock clears.'
    }
    if (-not [string]::IsNullOrWhiteSpace($uiBeachRegression)) {
        Assert-NotMatch $uiBeachRegression 'WorldMapScript\.unlock_nodes\s*\([^\r\n]*beach' 'UI Q-011 coverage must not manually unlock Beach.'
        Assert-NotMatch $uiBeachRegression '_travel_choice\s*\(\s*"beach"\s*,\s*\[\s*"beach"\s*\]' 'UI Q-011 coverage must not inject Beach into the production choice builder.'
        Assert-Match $uiBeachRegression '(?s)access_targets.*?_travel_target_ids.*?count\("beach"\)\s*!=\s*1.*?open_world_map.*?select_world_map_node",\s*"beach".*?world_map_confirm_button.*?disabled' 'Fresh Delta Queen coverage must prove Beach through production selection and its rendered enabled Travel control.'
        Assert-Match $uiBeachRegression '(?s)travel_lock_remaining.*?2.*?locked_targets.*?_travel_target_ids.*?locked_choice.*?enabled.*?true.*?travel_lock_remaining.*?0' 'UI Q-011 coverage must prove Beach remains visible-but-disabled under the global lock and returns to normal availability.'
        Assert-Match $uiBeachRegression '(?s)hostile_id\s*==\s*"beach".*?STATE_HIDDEN.*?enabled_non_beach_competitors\.size\(\)\s*<=\s*WorldMapScript\.TRAVEL_TOTAL_TARGET_LIMIT.*?revisit_targets.*?_travel_target_ids.*?count\("beach"\)\s*!=\s*1.*?has\(ordinary_yield_id\)' 'Revisit coverage must prove Beach displaces the lowest-ranked card after more than three real enabled competitors.'
        Assert-Match $uiBeachRegression '(?s)save_service\.save_run.*?load_foundation_run.*?continued_targets.*?_travel_target_ids.*?continued_targets\.count\("beach"\)\s*!=\s*1.*?continued_choice.*?enabled.*?continued_beach_node.*?travel_enabled.*?select_world_map_node",\s*"beach"' 'Save plus production Continue coverage must restore exactly one enabled rendered Beach destination.'
    }

    try {
        $serviceCatalogValue = Get-Content -LiteralPath $ServicesPath -Raw | ConvertFrom-Json
        $serviceCatalog = @($serviceCatalogValue | ForEach-Object { $_ })
        $cashierTips = @($serviceCatalog | Where-Object {
            $_.id -is [string] -and [string]$_.id -ceq 'cashier_tip'
        })
        if ($cashierTips.Count -ne 1) {
            throw "Expected one exact cashier_tip service; found $($cashierTips.Count)."
        }
        $cashierTip = $cashierTips[0]
        $cashierFields = @($cashierTip.PSObject.Properties | ForEach-Object { [string]$_.Name })
        if (($cashierFields -join ',') -cne 'id,display_name,category,description,cost,effect' -or
            ($cashierTip.cost -isnot [int32] -and $cashierTip.cost -isnot [int64]) -or
            [int]$cashierTip.cost -ne 4) {
            throw 'Cashier Tip must remain an exact $4 zero-duration definition with no one-use or cooldown field.'
        }

        $archetypeCatalogValue = Get-Content -LiteralPath $ArchetypesPath -Raw | ConvertFrom-Json
        $archetypeCatalog = @($archetypeCatalogValue | ForEach-Object { $_ })
        $cornerStores = @($archetypeCatalog | Where-Object {
            $_.id -is [string] -and [string]$_.id -ceq 'corner_store'
        })
        if ($cornerStores.Count -ne 1 -or
            (@($cornerStores[0].service_pool) -join ',') -cne 'cashier_tip,house_drink' -or
            (@($cornerStores[0].lender_hooks) -join ',') -cne 'the_crew' -or
            (@($cornerStores[0].lender_count) -join ',') -cne '1,1') {
            throw 'Corner Store must guarantee one Crew lender and the repeatable Cashier Tip service.'
        }
    }
    catch {
        Add-Failure "Crew Cashier Tip catalog contract failed: $($_.Exception.Message)"
    }

    $serviceViewSource = Get-GDScriptFunctionSource -Source $runActionService -Name 'service_hook_view_list'
    $serviceUseSource = Get-GDScriptFunctionSource -Source $runActionService -Name 'use_hook'
    $serviceCommitSource = Get-GDScriptFunctionSource -Source $runActionService -Name '_commit_hook_transaction'
    $serviceBoundarySource = Get-GDScriptFunctionSource -Source $runActionService -Name '_advance_transaction_hook_clock'
    $normalTravelSource = Get-GDScriptFunctionSource -Source $foundationMain -Name '_travel_to'
    if (-not [string]::IsNullOrWhiteSpace($serviceViewSource)) {
        Assert-Match $serviceViewSource '(?s)current_environment\.get\("service_ids".*?hook_option\("service",\s*service_id' 'Service projection must rebuild Cashier Tip from the current public environment on every use.'
    }
    if (-not [string]::IsNullOrWhiteSpace($serviceUseSource)) {
        Assert-Match $serviceUseSource '(?s)_hook_present_in_current_environment.*?hook_option\(kind,\s*hook_id\).*?_commit_hook_transaction\(transaction_price,\s*kind,\s*hook_id,\s*definition\)' 'Cashier Tip must commit through the ordinary revalidated service transaction path.'
        Assert-NotMatch $serviceUseSource 'remove_service|service_ids.*(?:erase|remove)' 'Using Cashier Tip must not consume its service definition.'
    }
    if (-not [string]::IsNullOrWhiteSpace($serviceCommitSource)) {
        Assert-Match $serviceCommitSource '(?s)_advance_transaction_hook_clock\(candidate,\s*transaction_kind,\s*definition\).*?_hook_present_in_current_environment.*?hook_option\(transaction_kind,\s*source_id.*?publish_host_action_candidate' 'Service transaction must advance and publish only after revalidating the live Cashier Tip option.'
        Assert-NotMatch $serviceCommitSource 'remove_service|service_ids.*(?:erase|remove)' 'Cashier Tip transaction must remain repeatable after publication.'
    }
    if (-not [string]::IsNullOrWhiteSpace($serviceBoundarySource)) {
        Assert-Match $serviceBoundarySource '(?s)duration_minutes.*?definition\.get\("duration_minutes",\s*0\).*?duration_minutes\s*>\s*0.*?advance_game_clock_minutes\(duration_minutes\).*?advance_environment_turns\(1\)' 'A zero-duration Cashier Tip must advance exactly one environment action boundary.'
    }
    if (-not [string]::IsNullOrWhiteSpace($normalTravelSource)) {
        Assert-Contains $normalTravelSource 'run_state.advance_game_clock_minutes(travel_minutes)' 'Normal travel must advance its published clock duration.'
        Assert-NotMatch $normalTravelSource 'advance_environment_turns' 'Normal travel must not masquerade as a Crew debt action boundary.'
    }

    $crewWorldHookSource = Get-GDScriptFunctionSource -Source $crewRunFacade -Name '_crew_heist_world_has_hook'
    if (-not [string]::IsNullOrWhiteSpace($crewWorldHookSource)) {
        Assert-Contains $crewRunFacade 'const COUNT_AUDIT_KNOWLEDGE_FLAG := "crew_heist_count_audit_roster_read"' 'The Count Audit fact must have one canonical story-flag id.'
        $auditBranchIndex = $crewWorldHookSource.IndexOf('if hook_id == "audit_night":', [StringComparison]::Ordinal)
        $genericNodeScanIndex = $crewWorldHookSource.IndexOf('for node_value in JsonCoerceScript._copy_array(_run.world_map.get("nodes", [])):', [StringComparison]::Ordinal)
        if ($auditBranchIndex -lt 0 -or $genericNodeScanIndex -le $auditBranchIndex) {
            Add-Failure 'Audit gating must return before the generic stored/seeded world-node scan.'
        }
        else {
            $auditBranch = $crewWorldHookSource.Substring($auditBranchIndex, $genericNodeScanIndex - $auditBranchIndex)
            Assert-Match $auditBranch '(?s)var\s+current_hook_value\s*=.*?current_environment\.get\("scenario_hook_flags".*?get\(hook_id,\s*false\).*?var\s+learned_audit_value\s*=\s*_run\.story_flags\.get\(COUNT_AUDIT_KNOWLEDGE_FLAG,\s*false\).*?typeof\(current_hook_value\)\s*==\s*TYPE_BOOL\s+and\s+bool\(current_hook_value\).*?or\s+\(typeof\(learned_audit_value\)\s*==\s*TYPE_BOOL\s+and\s+bool\(learned_audit_value\)\)' 'The Count must accept only exact boolean current Audit or authored story facts.'
            Assert-NotMatch $auditBranch 'get\([^\r\n]*\)\s*==\s*true' 'The Count Audit gate must type-check hostile Variant values before comparing or coercing them.'
            Assert-NotMatch $auditBranch 'narrative_flags|_seeded_scenario_definition_for_node_readonly|world_map' 'The Count Audit early return must not consume narrative mirrors, stored nodes, or private seed definitions.'
        }
    }

    $auditKnowledgeTestSource = Get-GDScriptFunctionSource -Source $crewHeistTest -Name '_check_audit_knowledge_gating'
    if (-not [string]::IsNullOrWhiteSpace($auditKnowledgeTestSource)) {
        Assert-Match $auditKnowledgeTestSource '(?s)HEIST-AUDIT-SEEDED-ONLY.*?seed_scenario_for_node\("grand_casino".*?grand_casino_audit_night.*?unvisited seeded Audit.*?HEIST-AUDIT-HOSTILE.*?narrative_flags\[KNOWLEDGE_FLAG\]\s*=\s*true.*?story_flags\[KNOWLEDGE_FLAG\]\s*=\s*"true".*?audit_night":\s*"true".*?malformed/forged knowledge' 'Audit gating coverage must reject unvisited seed selection, narrative-only forgery, non-boolean story data, and non-boolean active hooks.'
        Assert-Match $auditKnowledgeTestSource '(?s)HEIST-AUDIT-DECLINED.*?leave_the_count_clean.*?grand_casino_convention_crowd.*?remained live.*?HEIST-AUDIT-OBSERVED.*?read_the_shift.*?heat_before_read\s*\+\s*3.*?resolved_event_ids.*?scenario_audit_roster.*?replayed or charged its Heat twice.*?grand_casino_convention_crowd.*?to_save_snapshot\(\).*?Save/Continue restore' 'Audit gating coverage must bind the exact natural read, single +3 Heat result, resolved receipt, replay rejection, rollover/revisit, and real save projection.'
        Assert-NotMatch $auditKnowledgeTestSource 'story_flags\[KNOWLEDGE_FLAG\]\s*=\s*true' 'The valid Audit knowledge fixture must not inject its positive story fact directly.'
    }

    try {
        $eventCatalogValue = Get-Content -LiteralPath $EventsPath -Raw | ConvertFrom-Json
        $eventCatalog = @($eventCatalogValue | ForEach-Object { $_ })
        $auditEvents = @($eventCatalog | Where-Object { $_.id -is [string] -and [string]$_.id -ceq 'scenario_audit_roster' })
        if ($auditEvents.Count -ne 1) {
            throw "Expected one exact scenario_audit_roster event; found $($auditEvents.Count)."
        }
        $auditChoices = @($auditEvents[0].payload.choices)
        $readChoices = @($auditChoices | Where-Object { $_.id -is [string] -and [string]$_.id -ceq 'read_the_shift' })
        $leaveChoices = @($auditChoices | Where-Object { $_.id -is [string] -and [string]$_.id -ceq 'leave_the_count_clean' })
        if ($auditChoices.Count -ne 2 -or $readChoices.Count -ne 1 -or $leaveChoices.Count -ne 1 -or
            [string]$readChoices[0].label -cne 'Read the shift' -or
            [string]$readChoices[0].consequence_summary -cne 'Heat +3; Count route learned' -or
            [int]$readChoices[0].consequences.suspicion_delta -ne 3 -or
            $readChoices[0].consequences.resolve_event -isnot [bool] -or -not [bool]$readChoices[0].consequences.resolve_event -or
            $readChoices[0].consequences.story_flags_set.crew_heist_count_audit_roster_read -isnot [bool] -or
            -not [bool]$readChoices[0].consequences.story_flags_set.crew_heist_count_audit_roster_read -or
            $leaveChoices[0].consequences.PSObject.Properties.Name -contains 'story_flags_set') {
            throw 'Audit knowledge must be one disclosed exact boolean story fact granted only by read_the_shift.'
        }
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
        $interrogationChoices = @($showdownEvents[0].payload.interrogation.choices)
        $takeEdgeChoices = @($interrogationChoices | Where-Object {
            $_.id -is [string] -and [string]$_.id -ceq 'take_the_edge'
        })
        if ($interrogationChoices.Count -ne 3 -or
            (@($interrogationChoices.id) -join ',') -cne 'hold_steady,talk_down,take_the_edge' -or
            $takeEdgeChoices.Count -ne 1 -or
            $takeEdgeChoices[0].label -isnot [string] -or [string]$takeEdgeChoices[0].label -cne 'Take the Edge') {
            throw 'Showdown interrogation changed without an updated public take_the_edge replay policy.'
        }
    }
    catch {
        Add-Failure "Event source contract failed: $($_.Exception.Message)"
    }

    try {
        . $ReplayPolicyPath
    }
    catch {
        Add-Failure "Replay policy helper could not be loaded: $($_.Exception.Message)"
    }

    if ($null -ne (Get-Command 'Assert-HeistFreshStandardRunSetup' -ErrorAction SilentlyContinue)) {
        try {
            $validSetup = New-HeistFreshSetupPolicyFixture
            $selectedSetup = Assert-HeistFreshStandardRunSetup -Observation $validSetup
            if ([string]$selectedSetup.selected_challenge_id -cne '' -or
                [string]$selectedSetup.selected_home_type_id -cne 'random' -or
                @($selectedSetup.selected_content_groups).Count -ne 14) {
                throw 'Valid fresh Heist launch setup returned a changed selection.'
            }
            $heistLaunchSetupValidFixtures = 1
        }
        catch {
            Add-Failure "Valid fresh Heist launch setup threw: $($_.Exception.Message)"
        }

        $hostileSetupFixtures = [Collections.Generic.List[object]]::new()
        $fixture = New-HeistFreshSetupPolicyFixture; $fixture.screen.screen = 'ENVIRONMENT'
        $hostileSetupFixtures.Add([pscustomobject]@{ label = 'wrong-screen'; fixture = $fixture })
        $fixture = New-HeistFreshSetupPolicyFixture; $fixture.screen.PSObject.Properties.Remove('start_menu')
        $hostileSetupFixtures.Add([pscustomobject]@{ label = 'start-menu-missing'; fixture = $fixture })
        $fixture = New-HeistFreshSetupPolicyFixture; $fixture.screen.start_menu.run_config_visible = $false
        $hostileSetupFixtures.Add([pscustomobject]@{ label = 'run-config-hidden'; fixture = $fixture })
        $fixture = New-HeistFreshSetupPolicyFixture; $fixture.screen.start_menu.run_config_visible = 'true'
        $hostileSetupFixtures.Add([pscustomobject]@{ label = 'run-config-non-boolean'; fixture = $fixture })
        $fixture = New-HeistFreshSetupPolicyFixture; $fixture.screen.start_menu.selected_challenge_id = 'standard'
        $hostileSetupFixtures.Add([pscustomobject]@{ label = 'challenge-not-default'; fixture = $fixture })
        $fixture = New-HeistFreshSetupPolicyFixture; $fixture.screen.start_menu.selected_challenge_id = 0
        $hostileSetupFixtures.Add([pscustomobject]@{ label = 'challenge-non-string'; fixture = $fixture })
        $fixture = New-HeistFreshSetupPolicyFixture; $fixture.screen.start_menu.selected_home_type_id = 'back_alley'
        $hostileSetupFixtures.Add([pscustomobject]@{ label = 'home-not-random'; fixture = $fixture })
        $fixture = New-HeistFreshSetupPolicyFixture; $fixture.screen.start_menu.selected_home_type_id = $true
        $hostileSetupFixtures.Add([pscustomobject]@{ label = 'home-non-string'; fixture = $fixture })
        $fixture = New-HeistFreshSetupPolicyFixture; $fixture.screen.start_menu.selected_content_groups = @($fixture.screen.start_menu.selected_content_groups | Select-Object -Skip 1)
        $hostileSetupFixtures.Add([pscustomobject]@{ label = 'content-group-missing'; fixture = $fixture })
        $fixture = New-HeistFreshSetupPolicyFixture; $fixture.screen.start_menu.selected_content_groups += 'bonus_pack'
        $hostileSetupFixtures.Add([pscustomobject]@{ label = 'content-group-extra'; fixture = $fixture })
        $fixture = New-HeistFreshSetupPolicyFixture; $swap = $fixture.screen.start_menu.selected_content_groups[0]; $fixture.screen.start_menu.selected_content_groups[0] = $fixture.screen.start_menu.selected_content_groups[1]; $fixture.screen.start_menu.selected_content_groups[1] = $swap
        $hostileSetupFixtures.Add([pscustomobject]@{ label = 'content-group-reordered'; fixture = $fixture })
        $fixture = New-HeistFreshSetupPolicyFixture; $fixture.screen.start_menu.selected_content_groups[0] = 'Universal_Passive_Items'
        $hostileSetupFixtures.Add([pscustomobject]@{ label = 'content-group-case'; fixture = $fixture })
        $fixture = New-HeistFreshSetupPolicyFixture; $fixture.screen.start_menu.selected_content_groups[0] = 1
        $hostileSetupFixtures.Add([pscustomobject]@{ label = 'content-group-non-string'; fixture = $fixture })
        $fixture = New-HeistFreshSetupPolicyFixture; $fixture.screen.start_menu.selected_content_groups = 'universal_passive_items'
        $hostileSetupFixtures.Add([pscustomobject]@{ label = 'content-groups-non-array'; fixture = $fixture })

        $heistLaunchSetupHostileFixtures = $hostileSetupFixtures.Count
        foreach ($case in $hostileSetupFixtures) {
            $threw = $false
            try {
                $null = Assert-HeistFreshStandardRunSetup -Observation $case.fixture
            }
            catch {
                $threw = $true
            }
            if (-not $threw) {
                Add-Failure "Hostile fresh Heist launch fixture '$($case.label)' did not fail closed."
            }
        }
    }
    else {
        Add-Failure 'Replay policy helper did not export the fresh Standard-run setup assertion.'
    }

    try {
        $heistSeedOutput = @(& $HeistSeedPreflightPath `
            -Contract `
            -ReportPath (Join-Path $Worktree '.tmp\rw06_2\heist_seed_preflight_contract.json'))
        if ($heistSeedOutput.Count -cne 1 -or $heistSeedOutput[0] -isnot [string]) {
            throw "Heist seed preflight returned $($heistSeedOutput.Count) records instead of one report."
        }
        $heistSeedReport = $heistSeedOutput[0] | ConvertFrom-Json
        $heistSeedReceipt = Assert-ExactHeistSeedContractReport -Report $heistSeedReport
        $heistSeedReportHostiles = @(Get-UniversalContractSchemaHostiles `
            -ValidRoot $heistSeedReport `
            -Prefix 'Heist seed report')
        $heistSeedReportSchemaHostileFixtures = $heistSeedReportHostiles.Count
        if ($heistSeedReportSchemaHostileFixtures -cne 626) {
            throw "Heist seed report universal hostile count drifted to $heistSeedReportSchemaHostileFixtures."
        }
        foreach ($case in $heistSeedReportHostiles) {
            $threw = $false
            try {
                $null = Assert-ExactHeistSeedContractReport -Report $case.value
            }
            catch {
                $threw = $true
            }
            if (-not $threw) {
                Add-Failure "Heist seed report schema accepted hostile '$($case.name)'."
            }
        }
        $heistSeedValidFixtures = $heistSeedReceipt.valid_fixtures
        $heistSeedHostileFixtures = $heistSeedReceipt.hostile_fixtures
    }
    catch {
        Add-Failure "Heist seed preflight contract failed: $($_.Exception.Message)"
    }

    try {
        $admissionOutput = @(& $EvidenceAdmissionContractPath -ReportPath $EvidenceAdmissionReportPath)
        if ($admissionOutput.Count -cne 1 -or
            $admissionOutput[0] -isnot [string] -or
            $admissionOutput[0] -cnotmatch '^RW06_2_EVIDENCE_ADMISSION_CONTRACT PASS;') {
            throw "Evidence admission contract returned an unexpected result: $($admissionOutput -join ' | ')"
        }
        $admissionReportRaw = Get-Content -Raw -LiteralPath $EvidenceAdmissionReportPath -Encoding utf8
        if ($admissionReportRaw -isnot [string] -or [string]::IsNullOrWhiteSpace($admissionReportRaw)) {
            throw 'Evidence admission contract report is not one exact non-empty JSON string.'
        }
        $admissionReport = $admissionReportRaw | ConvertFrom-Json
        $expectedAdmissionSourceHashes = [ordered]@{
            admission = (Get-FileHash -LiteralPath $EvidenceAdmissionPath -Algorithm SHA256).Hash.ToUpperInvariant()
            preflight = (Get-FileHash -LiteralPath $HeistSeedPreflightPath -Algorithm SHA256).Hash.ToUpperInvariant()
            runner = (Get-FileHash -LiteralPath $RunnerPath -Algorithm SHA256).Hash.ToUpperInvariant()
            fixed_launcher = (Get-FileHash -LiteralPath $FinalEvidencePath -Algorithm SHA256).Hash.ToUpperInvariant()
        }
        $admissionReceipt = Assert-ExactEvidenceAdmissionContractReport `
            -Report $admissionReport `
            -ExpectedSourceHashes $expectedAdmissionSourceHashes
        $admissionReportHostiles = @(Get-UniversalContractSchemaHostiles `
            -ValidRoot $admissionReport `
            -Prefix 'Evidence admission report')
        $evidenceAdmissionReportSchemaHostileFixtures = $admissionReportHostiles.Count
        if ($evidenceAdmissionReportSchemaHostileFixtures -cne 130) {
            throw "Evidence admission report universal hostile count drifted to $evidenceAdmissionReportSchemaHostileFixtures."
        }
        foreach ($case in $admissionReportHostiles) {
            $threw = $false
            try {
                $null = Assert-ExactEvidenceAdmissionContractReport `
                    -Report $case.value `
                    -ExpectedSourceHashes $expectedAdmissionSourceHashes
            }
            catch {
                $threw = $true
            }
            if (-not $threw) {
                Add-Failure "Evidence admission report schema accepted hostile '$($case.name)'."
            }
        }
        $evidenceAdmissionValidFixtures = $admissionReceipt.valid_fixtures
        $evidenceAdmissionHostileFixtures = $admissionReceipt.hostile_fixtures
    }
    catch {
        Add-Failure "Evidence admission contract failed: $($_.Exception.Message)"
    }

    if ($null -ne (Get-Command 'Select-HeistAuditNightPublicHook' -ErrorAction SilentlyContinue)) {
        $validAuditFixture = New-HeistAuditHookPolicyFixture
        try {
            $selectedAuditHook = Select-HeistAuditNightPublicHook `
                -Observation $validAuditFixture.observation `
                -CanvasObjects @($validAuditFixture.canvas_objects)
            if ([string]$selectedAuditHook.semantic_id -cne 'event:scenario_audit_roster') {
                Add-Failure 'Valid rendered Audit Night hook did not return the exact public event.'
            }
            else {
                $heistAuditHookValidFixtures = 1
            }
        }
        catch {
            Add-Failure "Valid rendered Audit Night hook threw: $($_.Exception.Message)"
        }

        $hostileAuditFixtures = [Collections.Generic.List[object]]::new()
        $fixture = New-HeistAuditHookPolicyFixture; $fixture.observation.screen.screen = 'RESULT'
        $hostileAuditFixtures.Add([pscustomobject]@{ label = 'wrong-screen'; fixture = $fixture })
        $fixture = New-HeistAuditHookPolicyFixture; $fixture.observation.environment.archetype_id = 'grand_casino_cage'
        $hostileAuditFixtures.Add([pscustomobject]@{ label = 'wrong-room'; fixture = $fixture })
        $fixture = New-HeistAuditHookPolicyFixture; $fixture.canvas_objects = @($fixture.canvas_objects | Where-Object { $_.semantic_id -cne 'event:scenario_audit_roster' })
        $hostileAuditFixtures.Add([pscustomobject]@{ label = 'hook-missing'; fixture = $fixture })
        $fixture = New-HeistAuditHookPolicyFixture; $fixture.canvas_objects += [pscustomobject]@{ semantic_id = 'event:scenario_audit_roster'; label = 'The Audit Roster'; object_type = 'event'; rendered = $true; enabled = $true }
        $hostileAuditFixtures.Add([pscustomobject]@{ label = 'hook-duplicate'; fixture = $fixture })
        $fixture = New-HeistAuditHookPolicyFixture; $fixture.canvas_objects[0].semantic_id = 'event:Scenario_Audit_Roster'
        $hostileAuditFixtures.Add([pscustomobject]@{ label = 'semantic-id-case'; fixture = $fixture })
        $fixture = New-HeistAuditHookPolicyFixture; $fixture.canvas_objects[0].label = 'Audit Roster'
        $hostileAuditFixtures.Add([pscustomobject]@{ label = 'wrong-label'; fixture = $fixture })
        $fixture = New-HeistAuditHookPolicyFixture; $fixture.canvas_objects[0].object_type = 'security'
        $hostileAuditFixtures.Add([pscustomobject]@{ label = 'wrong-object-type'; fixture = $fixture })
        $fixture = New-HeistAuditHookPolicyFixture; $fixture.canvas_objects[0].rendered = $false
        $hostileAuditFixtures.Add([pscustomobject]@{ label = 'not-rendered'; fixture = $fixture })
        $fixture = New-HeistAuditHookPolicyFixture; $fixture.canvas_objects[0].rendered = 'true'
        $hostileAuditFixtures.Add([pscustomobject]@{ label = 'rendered-non-boolean'; fixture = $fixture })
        $fixture = New-HeistAuditHookPolicyFixture; $fixture.canvas_objects[0].enabled = $false
        $hostileAuditFixtures.Add([pscustomobject]@{ label = 'disabled'; fixture = $fixture })
        $fixture = New-HeistAuditHookPolicyFixture; $fixture.canvas_objects[0].enabled = 1
        $hostileAuditFixtures.Add([pscustomobject]@{ label = 'enabled-non-boolean'; fixture = $fixture })
        $fixture = New-HeistAuditHookPolicyFixture; $fixture.canvas_objects[0].PSObject.Properties.Remove('rendered')
        $hostileAuditFixtures.Add([pscustomobject]@{ label = 'rendered-missing'; fixture = $fixture })
        $fixture = New-HeistAuditHookPolicyFixture; $fixture.canvas_objects = @($fixture.canvas_objects | Where-Object { $_.semantic_id -cne 'event:scenario_audit_roster' }); $fixture.observation.environment | Add-Member -NotePropertyName scenario_hook_flags -NotePropertyValue ([pscustomobject]@{ audit_night = $true })
        $hostileAuditFixtures.Add([pscustomobject]@{ label = 'private-hook-without-rendered-event'; fixture = $fixture })

        $heistAuditHookHostileFixtures = $hostileAuditFixtures.Count
        foreach ($case in $hostileAuditFixtures) {
            $threw = $false
            try {
                $null = Select-HeistAuditNightPublicHook `
                    -Observation $case.fixture.observation `
                    -CanvasObjects @($case.fixture.canvas_objects)
            }
            catch {
                $threw = $true
            }
            if (-not $threw) {
                Add-Failure "Hostile rendered Audit Night fixture '$($case.label)' did not fail closed."
            }
        }
    }
    else {
        Add-Failure 'Replay policy helper did not export the rendered Audit Night hook selector.'
    }

    if ($null -ne (Get-Command 'Select-HeistConventionCrowdPublicHook' -ErrorAction SilentlyContinue)) {
        $validConventionFixture = New-HeistConventionHookPolicyFixture
        try {
            $selectedConventionHook = Select-HeistConventionCrowdPublicHook `
                -Observation $validConventionFixture.observation `
                -CanvasObjects @($validConventionFixture.canvas_objects)
            if ([string]$selectedConventionHook.semantic_id -cne 'event:scenario_convention_badge') {
                Add-Failure 'Valid rendered Convention Crowd hook did not return the exact public event.'
            }
            else {
                $heistConventionHookValidFixtures = 1
            }
        }
        catch {
            Add-Failure "Valid rendered Convention Crowd hook threw: $($_.Exception.Message)"
        }

        $hostileConventionFixtures = [Collections.Generic.List[object]]::new()
        $fixture = New-HeistConventionHookPolicyFixture; $fixture.observation.screen.screen = 'RESULT'
        $hostileConventionFixtures.Add([pscustomobject]@{ label = 'wrong-screen'; fixture = $fixture })
        $fixture = New-HeistConventionHookPolicyFixture; $fixture.observation.environment.archetype_id = 'grand_casino_cage'
        $hostileConventionFixtures.Add([pscustomobject]@{ label = 'wrong-room'; fixture = $fixture })
        $fixture = New-HeistConventionHookPolicyFixture; $fixture.canvas_objects = @($fixture.canvas_objects | Where-Object { $_.semantic_id -cne 'event:scenario_convention_badge' })
        $hostileConventionFixtures.Add([pscustomobject]@{ label = 'hook-missing'; fixture = $fixture })
        $fixture = New-HeistConventionHookPolicyFixture; $fixture.canvas_objects += [pscustomobject]@{ semantic_id = 'event:scenario_convention_badge'; label = 'Borrowed Badge'; object_type = 'event'; rendered = $true; enabled = $true }
        $hostileConventionFixtures.Add([pscustomobject]@{ label = 'hook-duplicate'; fixture = $fixture })
        $fixture = New-HeistConventionHookPolicyFixture; $fixture.canvas_objects += [pscustomobject]@{ semantic_id = 'event:scenario_audit_roster'; label = 'The Audit Roster'; object_type = 'event'; rendered = $true; enabled = $true }
        $hostileConventionFixtures.Add([pscustomobject]@{ label = 'audit-still-rendered'; fixture = $fixture })
        $fixture = New-HeistConventionHookPolicyFixture; $fixture.canvas_objects[0].semantic_id = 'event:Scenario_Convention_Badge'
        $hostileConventionFixtures.Add([pscustomobject]@{ label = 'semantic-id-case'; fixture = $fixture })
        $fixture = New-HeistConventionHookPolicyFixture; $fixture.canvas_objects[0].label = 'Convention Badge'
        $hostileConventionFixtures.Add([pscustomobject]@{ label = 'wrong-label'; fixture = $fixture })
        $fixture = New-HeistConventionHookPolicyFixture; $fixture.canvas_objects[0].object_type = 'security'
        $hostileConventionFixtures.Add([pscustomobject]@{ label = 'wrong-object-type'; fixture = $fixture })
        $fixture = New-HeistConventionHookPolicyFixture; $fixture.canvas_objects[0].rendered = $false
        $hostileConventionFixtures.Add([pscustomobject]@{ label = 'not-rendered'; fixture = $fixture })
        $fixture = New-HeistConventionHookPolicyFixture; $fixture.canvas_objects[0].rendered = 'true'
        $hostileConventionFixtures.Add([pscustomobject]@{ label = 'rendered-non-boolean'; fixture = $fixture })
        $fixture = New-HeistConventionHookPolicyFixture; $fixture.canvas_objects[0].enabled = $false
        $hostileConventionFixtures.Add([pscustomobject]@{ label = 'disabled'; fixture = $fixture })
        $fixture = New-HeistConventionHookPolicyFixture; $fixture.canvas_objects[0].enabled = 1
        $hostileConventionFixtures.Add([pscustomobject]@{ label = 'enabled-non-boolean'; fixture = $fixture })
        $fixture = New-HeistConventionHookPolicyFixture; $fixture.canvas_objects[0].PSObject.Properties.Remove('rendered')
        $hostileConventionFixtures.Add([pscustomobject]@{ label = 'rendered-missing'; fixture = $fixture })

        $heistConventionHookHostileFixtures = $hostileConventionFixtures.Count
        foreach ($case in $hostileConventionFixtures) {
            $threw = $false
            try {
                $null = Select-HeistConventionCrowdPublicHook `
                    -Observation $case.fixture.observation `
                    -CanvasObjects @($case.fixture.canvas_objects)
            }
            catch {
                $threw = $true
            }
            if (-not $threw) {
                Add-Failure "Hostile rendered Convention Crowd fixture '$($case.label)' did not fail closed."
            }
        }
    }
    else {
        Add-Failure 'Replay policy helper did not export the rendered Convention Crowd hook selector.'
    }

    if ($null -ne (Get-Command 'Assert-DeltaQueenBeachPublicRoute' -ErrorAction SilentlyContinue)) {
        $validBeachFixtures = @(
            [pscustomobject]@{ label = 'normal-travel-enabled'; fixture = (New-DeltaQueenBeachPolicyFixture) },
            [pscustomobject]@{ label = 'exact-transient-boat-lock'; fixture = (New-DeltaQueenBeachPolicyFixture -Locked) }
        )
        $deltaQueenBeachValidFixtures = $validBeachFixtures.Count
        foreach ($case in $validBeachFixtures) {
            try {
                $actual = Assert-DeltaQueenBeachPublicRoute -ArchetypeId ([string]$case.fixture.archetype_id) -MapNodes @($case.fixture.nodes)
                if ($actual -isnot [bool] -or -not [bool]$actual) {
                    Add-Failure "Valid Delta Queen Beach fixture '$($case.label)' did not return exact true."
                }
            }
            catch {
                Add-Failure "Valid Delta Queen Beach fixture '$($case.label)' threw: $($_.Exception.Message)"
            }
        }

        $hostileBeachFixtures = [Collections.Generic.List[object]]::new()
        $fixture = New-DeltaQueenBeachPolicyFixture; $fixture.nodes = @($fixture.nodes | Where-Object { $_.archetype_id -cne 'beach' })
        $hostileBeachFixtures.Add([pscustomobject]@{ label = 'beach-missing'; fixture = $fixture })
        $fixture = New-DeltaQueenBeachPolicyFixture; $fixture.nodes += $fixture.nodes[0]
        $hostileBeachFixtures.Add([pscustomobject]@{ label = 'beach-duplicate'; fixture = $fixture })
        $fixture = New-DeltaQueenBeachPolicyFixture; $fixture.archetype_id = 'Delta_Queen'
        $hostileBeachFixtures.Add([pscustomobject]@{ label = 'current-archetype-case'; fixture = $fixture })
        $fixture = New-DeltaQueenBeachPolicyFixture; $fixture.nodes[0].cost = 1
        $hostileBeachFixtures.Add([pscustomobject]@{ label = 'beach-not-free'; fixture = $fixture })
        $fixture = New-DeltaQueenBeachPolicyFixture; $fixture.nodes[0].travel_enabled = 'true'
        $hostileBeachFixtures.Add([pscustomobject]@{ label = 'beach-enabled-non-boolean'; fixture = $fixture })
        $fixture = New-DeltaQueenBeachPolicyFixture; $fixture.nodes[0].travel_target = $false
        $hostileBeachFixtures.Add([pscustomobject]@{ label = 'beach-not-final-travel-target'; fixture = $fixture })
        $fixture = New-DeltaQueenBeachPolicyFixture; $fixture.nodes[0].state = 'hidden'
        $hostileBeachFixtures.Add([pscustomobject]@{ label = 'beach-hidden-state'; fixture = $fixture })
        $fixture = New-DeltaQueenBeachPolicyFixture; $fixture.nodes[0].id = 'Beach_011'
        $hostileBeachFixtures.Add([pscustomobject]@{ label = 'beach-id-case'; fixture = $fixture })
        $fixture = New-DeltaQueenBeachPolicyFixture -Locked; $fixture.nodes[0].travel_disabled_reason = 'Boat closed.'
        $hostileBeachFixtures.Add([pscustomobject]@{ label = 'wrong-disabled-reason'; fixture = $fixture })
        $fixture = New-DeltaQueenBeachPolicyFixture -Locked; $fixture.nodes[1].travel_enabled = $true
        $hostileBeachFixtures.Add([pscustomobject]@{ label = 'another-route-enabled'; fixture = $fixture })
        $fixture = New-DeltaQueenBeachPolicyFixture; $fixture.nodes[0] = [pscustomobject]@{ id = 'beach_011'; Archetype_Id = 'beach'; state = 'revealed'; cost = 0; travel_target = $true; travel_enabled = $true; travel_disabled_reason = '' }
        $hostileBeachFixtures.Add([pscustomobject]@{ label = 'beach-archetype-property-case'; fixture = $fixture })
        $fixture = New-DeltaQueenBeachPolicyFixture -Locked; $fixture.nodes[1].travel_enabled = 0
        $hostileBeachFixtures.Add([pscustomobject]@{ label = 'comparison-enabled-non-boolean'; fixture = $fixture })
        $fixture = New-DeltaQueenBeachPolicyFixture
        $fixture.nodes = @(
            [pscustomobject]@{ id = 'grand_101'; archetype_id = 'grand_casino'; state = 'revealed'; cost = 50; travel_target = $true; travel_enabled = $true; travel_disabled_reason = '' },
            [pscustomobject]@{ id = 'event_102'; archetype_id = 'bar'; state = 'revealed'; cost = 8; travel_target = $true; travel_enabled = $true; travel_disabled_reason = '' },
            [pscustomobject]@{ id = 'tier2_103'; archetype_id = 'kitty_cat_lounge'; state = 'revealed'; cost = 15; travel_target = $true; travel_enabled = $true; travel_disabled_reason = '' },
            [pscustomobject]@{ id = 'visited_104'; archetype_id = 'motel'; state = 'visited'; cost = 6; travel_target = $true; travel_enabled = $true; travel_disabled_reason = '' },
            [pscustomobject]@{ id = 'delta_queen_009'; archetype_id = 'delta_queen'; state = 'current'; cost = 0; travel_target = $false; travel_enabled = $false; travel_disabled_reason = 'Already here.' }
        )
        $hostileBeachFixtures.Add([pscustomobject]@{ label = 'beach-evicted-by-four-competing-visible-targets'; fixture = $fixture })

        $deltaQueenBeachHostileFixtures = $hostileBeachFixtures.Count
        foreach ($case in $hostileBeachFixtures) {
            $threw = $false
            try {
                $null = Assert-DeltaQueenBeachPublicRoute -ArchetypeId ([string]$case.fixture.archetype_id) -MapNodes @($case.fixture.nodes)
            }
            catch {
                $threw = $true
            }
            if (-not $threw) {
                Add-Failure "Hostile Delta Queen Beach fixture '$($case.label)' did not fail closed."
            }
        }
    }
    else {
        Add-Failure 'Replay policy helper did not export the Q-011 Delta Queen Beach invariant.'
    }

    $duelCheckpointPolicyCommand = Get-Command 'Select-CheatReplayDuelCheckpointAction' -ErrorAction SilentlyContinue
    if ($null -ne $duelCheckpointPolicyCommand) {
        $validDuelCheckpoint = New-CheatReplayDuelCheckpointPolicyFixture
        try {
            $selection = Select-CheatReplayDuelCheckpointAction `
                -Game $validDuelCheckpoint.game `
                -SurfaceActions $validDuelCheckpoint.surface_actions
            if ($selection -isnot [System.Management.Automation.PSCustomObject] -or
                $selection.action -isnot [string] -or $selection.action -cne 'blackjack_deal' -or
                $selection.index -isnot [int32] -or $selection.index -ne 0) {
                Add-Failure 'Valid Rourke duel checkpoint fixture returned the wrong exact Deal selection.'
            }
            else { $cheatDuelCheckpointValidFixtures++ }
        }
        catch {
            Add-Failure "Valid Rourke duel checkpoint fixture threw: $($_.Exception.Message)"
        }

        $hostileDuelCheckpoints = [Collections.Generic.List[object]]::new()
        foreach ($field in @('game_id', 'phase', 'boss_duel_active', 'boss_hand_number', 'can_deal')) {
            foreach ($variant in @('missing', 'null', 'object', 'array', 'wrong-scalar')) {
                $fixture = New-CheatReplayDuelCheckpointPolicyFixture
                switch ($variant) {
                    'missing' { $fixture.game.PSObject.Properties.Remove($field) }
                    'null' { $fixture.game.$field = $null }
                    'object' { $fixture.game.$field = [pscustomobject]@{} }
                    'array' { $fixture.game.$field = [object[]]@(,$fixture.game.$field) }
                    'wrong-scalar' {
                        $fixture.game.$field = if ($field -cin @('boss_duel_active', 'can_deal')) { 'true' }
                            elseif ($field -ceq 'boss_hand_number') { '1' }
                            else { [int32]1 }
                    }
                }
                $hostileDuelCheckpoints.Add([pscustomobject]@{ label = "game-$field-$variant"; fixture = $fixture })
            }
        }
        foreach ($spec in @(
            [pscustomobject]@{ label = 'wrong-game'; field = 'game_id'; value = 'roulette' },
            [pscustomobject]@{ label = 'wrong-phase'; field = 'phase'; value = 'decision' },
            [pscustomobject]@{ label = 'inactive-duel'; field = 'boss_duel_active'; value = $false },
            [pscustomobject]@{ label = 'hand-zero'; field = 'boss_hand_number'; value = [int32]0 },
            [pscustomobject]@{ label = 'hand-two'; field = 'boss_hand_number'; value = [int32]2 },
            [pscustomobject]@{ label = 'cannot-deal'; field = 'can_deal'; value = $false }
        )) {
            $fixture = New-CheatReplayDuelCheckpointPolicyFixture
            $fixture.game.($spec.field) = $spec.value
            $hostileDuelCheckpoints.Add([pscustomobject]@{ label = $spec.label; fixture = $fixture })
        }
        foreach ($field in @('action', 'index', 'enabled')) {
            foreach ($variant in @('missing', 'null', 'object', 'array', 'wrong-scalar')) {
                $fixture = New-CheatReplayDuelCheckpointPolicyFixture
                switch ($variant) {
                    'missing' { $fixture.surface_actions[0].PSObject.Properties.Remove($field) }
                    'null' { $fixture.surface_actions[0].$field = $null }
                    'object' { $fixture.surface_actions[0].$field = [pscustomobject]@{} }
                    'array' { $fixture.surface_actions[0].$field = [object[]]@(,$fixture.surface_actions[0].$field) }
                    'wrong-scalar' {
                        $fixture.surface_actions[0].$field = if ($field -ceq 'index') { '0' }
                            elseif ($field -ceq 'enabled') { 'true' }
                            else { [int32]1 }
                    }
                }
                $hostileDuelCheckpoints.Add([pscustomobject]@{ label = "deal-$field-$variant"; fixture = $fixture })
            }
        }
        foreach ($spec in @(
            [pscustomobject]@{ label = 'deal-missing'; action = { param($fixture) $fixture.surface_actions = [object[]]@($fixture.surface_actions[1]) } },
            [pscustomobject]@{ label = 'deal-duplicate'; action = { param($fixture) $fixture.surface_actions += [pscustomobject]@{ action = 'blackjack_deal'; index = [int32]0; enabled = $true } } },
            [pscustomobject]@{ label = 'deal-case-drift'; action = { param($fixture) $fixture.surface_actions[0].action = 'Blackjack_Deal' } },
            [pscustomobject]@{ label = 'deal-disabled'; action = { param($fixture) $fixture.surface_actions[0].enabled = $false } },
            [pscustomobject]@{ label = 'deal-wrong-index'; action = { param($fixture) $fixture.surface_actions[0].index = [int32]1 } },
            [pscustomobject]@{ label = 'actions-empty'; action = { param($fixture) $fixture.surface_actions = [object[]]@() } },
            [pscustomobject]@{ label = 'actions-scalar'; action = { param($fixture) $fixture.surface_actions = 'blackjack_deal' } },
            [pscustomobject]@{ label = 'actions-object'; action = { param($fixture) $fixture.surface_actions = [pscustomobject]@{ action = 'blackjack_deal'; index = [int32]0; enabled = $true } } },
            [pscustomobject]@{ label = 'actions-nested-array'; action = { param($fixture) $fixture.surface_actions = [object[]]@(,([object[]]@($fixture.surface_actions[0]))) } },
            [pscustomobject]@{ label = 'actions-wrong-element'; action = { param($fixture) $fixture.surface_actions = [object[]]@('blackjack_deal') } }
        )) {
            $fixture = New-CheatReplayDuelCheckpointPolicyFixture
            & $spec.action $fixture
            $hostileDuelCheckpoints.Add([pscustomobject]@{ label = $spec.label; fixture = $fixture })
        }
        $cheatDuelCheckpointHostileFixtures = $hostileDuelCheckpoints.Count
        foreach ($case in $hostileDuelCheckpoints) {
            $threw = $false
            try {
                $null = Select-CheatReplayDuelCheckpointAction `
                    -Game $case.fixture.game `
                    -SurfaceActions $case.fixture.surface_actions
            }
            catch { $threw = $true }
            if (-not $threw) {
                Add-Failure "Hostile Rourke duel checkpoint fixture '$($case.label)' did not fail closed."
            }
        }
    }
    else {
        Add-Failure 'Replay policy helper did not export Select-CheatReplayDuelCheckpointAction.'
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

    $postPeekPolicyCommand = Get-Command 'Select-CheatReplayPostPeekTransition' -ErrorAction SilentlyContinue
    if ($null -ne $postPeekPolicyCommand) {
        $validPostPeekCases = @(
            New-CheatReplayPostPeekPolicyFixture -Stage continue_hand
            New-CheatReplayPostPeekPolicyFixture -Stage leave_for_showdown
        )
        $cheatPostPeekValidFixtures = $validPostPeekCases.Count
        foreach ($fixture in $validPostPeekCases) {
            try {
                $selection = Select-CheatReplayPostPeekTransition `
                    -Game $fixture.game `
                    -StatusHud $fixture.status_hud `
                    -SurfaceActions @($fixture.surface_actions)
                if ([string]$selection.stage -cne [string]$fixture.expected_stage -or
                    ([string]$fixture.expected_stage -ceq 'leave_for_showdown' -and
                        ([string]$selection.action -cne 'surface_back' -or [int]$selection.index -ne -1))) {
                    Add-Failure "Valid post-Peek fixture '$($fixture.expected_stage)' selected the wrong public transition."
                }
            }
            catch {
                Add-Failure "Valid post-Peek fixture '$($fixture.expected_stage)' threw: $($_.Exception.Message)"
            }
        }

        $hostilePostPeekCases = [Collections.Generic.List[object]]::new()
        $fixture = New-CheatReplayPostPeekPolicyFixture; $fixture.game.phase = 'Barred'
        $hostilePostPeekCases.Add([pscustomobject]@{ label = 'phase-case'; fixture = $fixture })
        $fixture = New-CheatReplayPostPeekPolicyFixture; $fixture.game.PSObject.Properties.Remove('phase')
        $hostilePostPeekCases.Add([pscustomobject]@{ label = 'phase-missing'; fixture = $fixture })
        $fixture = New-CheatReplayPostPeekPolicyFixture; $fixture.status_hud.heat_rendered = 'true'
        $hostilePostPeekCases.Add([pscustomobject]@{ label = 'heat-rendered-non-boolean'; fixture = $fixture })
        $fixture = New-CheatReplayPostPeekPolicyFixture; $fixture.status_hud.heat_rendered = $false
        $hostilePostPeekCases.Add([pscustomobject]@{ label = 'heat-not-rendered'; fixture = $fixture })
        $fixture = New-CheatReplayPostPeekPolicyFixture; $fixture.status_hud.heat_level = '90'
        $hostilePostPeekCases.Add([pscustomobject]@{ label = 'heat-non-integral'; fixture = $fixture })
        $fixture = New-CheatReplayPostPeekPolicyFixture; $fixture.status_hud.heat_level = 69
        $hostilePostPeekCases.Add([pscustomobject]@{ label = 'heat-below-showdown'; fixture = $fixture })
        $fixture = New-CheatReplayPostPeekPolicyFixture; $fixture.status_hud.heat_level = 101
        $hostilePostPeekCases.Add([pscustomobject]@{ label = 'heat-above-public-range'; fixture = $fixture })
        $fixture = New-CheatReplayPostPeekPolicyFixture; $fixture.surface_actions = @($fixture.surface_actions | Where-Object { $_.action -cne 'surface_back' })
        $hostilePostPeekCases.Add([pscustomobject]@{ label = 'surface-back-missing'; fixture = $fixture })
        $fixture = New-CheatReplayPostPeekPolicyFixture; $fixture.surface_actions += [pscustomobject]@{ action = 'surface_back'; index = -1; enabled = $true }
        $hostilePostPeekCases.Add([pscustomobject]@{ label = 'surface-back-duplicate'; fixture = $fixture })
        $fixture = New-CheatReplayPostPeekPolicyFixture; $fixture.surface_actions[0].enabled = $false
        $hostilePostPeekCases.Add([pscustomobject]@{ label = 'surface-back-disabled'; fixture = $fixture })
        $fixture = New-CheatReplayPostPeekPolicyFixture; $fixture.surface_actions[0].enabled = 1
        $hostilePostPeekCases.Add([pscustomobject]@{ label = 'surface-back-enabled-non-boolean'; fixture = $fixture })
        $fixture = New-CheatReplayPostPeekPolicyFixture; $fixture.surface_actions[0].index = 0
        $hostilePostPeekCases.Add([pscustomobject]@{ label = 'surface-back-index-changed'; fixture = $fixture })
        $fixture = New-CheatReplayPostPeekPolicyFixture; $fixture.surface_actions[0].index = '-1'
        $hostilePostPeekCases.Add([pscustomobject]@{ label = 'surface-back-index-non-integral'; fixture = $fixture })

        $cheatPostPeekHostileFixtures = $hostilePostPeekCases.Count
        foreach ($case in $hostilePostPeekCases) {
            $threw = $false
            try {
                $null = Select-CheatReplayPostPeekTransition `
                    -Game $case.fixture.game `
                    -StatusHud $case.fixture.status_hud `
                    -SurfaceActions @($case.fixture.surface_actions)
            }
            catch { $threw = $true }
            if (-not $threw) {
                Add-Failure "Hostile post-Peek fixture '$($case.label)' did not fail closed."
            }
        }
    }
    else {
        Add-Failure 'Replay policy helper did not export Select-CheatReplayPostPeekTransition.'
    }
    if (-not (Test-CheatReplayBarredPeekExitOrder -Source $runner)) {
        Add-Failure 'Play-OneBlackjackRound must inspect the public post-Peek barred transition and return before settlement or Hit/Stand.'
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

    $interrogationPolicyCommand = Get-Command 'Select-CheatReplayShowdownInterrogationChoice' -ErrorAction SilentlyContinue
    if ($null -ne $interrogationPolicyCommand) {
        $validInterrogationCases = @(
            New-CheatReplayInterrogationPolicyFixture
        )
        $cheatInterrogationValidFixtures = $validInterrogationCases.Count
        foreach ($fixture in $validInterrogationCases) {
            try {
                $choice = Select-CheatReplayShowdownInterrogationChoice -EventPopup $fixture.popup
                if ($choice -isnot [string] -or [string]$choice -cne [string]$fixture.expected_choice) {
                    Add-Failure "Valid Cheat interrogation fixture selected '$choice' instead of take_the_edge."
                }
            }
            catch {
                Add-Failure "Valid Cheat interrogation fixture threw: $($_.Exception.Message)"
            }
        }

        $hostileInterrogationCases = [Collections.Generic.List[object]]::new()
        $fixture = New-CheatReplayInterrogationPolicyFixture; $fixture.popup.visible = $false
        $hostileInterrogationCases.Add([pscustomobject]@{ label = 'popup-hidden'; fixture = $fixture })
        $fixture = New-CheatReplayInterrogationPolicyFixture; $fixture.popup.visible = 'true'
        $hostileInterrogationCases.Add([pscustomobject]@{ label = 'popup-visible-non-boolean'; fixture = $fixture })
        $fixture = New-CheatReplayInterrogationPolicyFixture; $fixture.popup.render_valid = $false
        $hostileInterrogationCases.Add([pscustomobject]@{ label = 'popup-clipped'; fixture = $fixture })
        $fixture = New-CheatReplayInterrogationPolicyFixture; $fixture.popup.event_id = 'The_House_Calls'
        $hostileInterrogationCases.Add([pscustomobject]@{ label = 'event-id-case'; fixture = $fixture })
        $fixture = New-CheatReplayInterrogationPolicyFixture; $fixture.popup.choice_ids = @('hold_steady', 'talk_down')
        $hostileInterrogationCases.Add([pscustomobject]@{ label = 'take-edge-id-missing'; fixture = $fixture })
        $fixture = New-CheatReplayInterrogationPolicyFixture; $fixture.popup.choice_ids = @('hold_steady', 'take_the_edge', 'take_the_edge')
        $hostileInterrogationCases.Add([pscustomobject]@{ label = 'take-edge-id-duplicate'; fixture = $fixture })
        $fixture = New-CheatReplayInterrogationPolicyFixture; $fixture.popup.choices = @($fixture.popup.choices | Where-Object { $_.id -cne 'take_the_edge' })
        $hostileInterrogationCases.Add([pscustomobject]@{ label = 'take-edge-control-missing'; fixture = $fixture })
        $fixture = New-CheatReplayInterrogationPolicyFixture; $fixture.popup.choices[2].enabled = $false
        $hostileInterrogationCases.Add([pscustomobject]@{ label = 'take-edge-disabled'; fixture = $fixture })
        $fixture = New-CheatReplayInterrogationPolicyFixture; $fixture.popup.choices[2].enabled = 'true'
        $hostileInterrogationCases.Add([pscustomobject]@{ label = 'take-edge-enabled-non-boolean'; fixture = $fixture })
        $fixture = New-CheatReplayInterrogationPolicyFixture; $fixture.popup.choices[2].label = ''
        $hostileInterrogationCases.Add([pscustomobject]@{ label = 'take-edge-label-blank'; fixture = $fixture })
        $fixture = New-CheatReplayInterrogationPolicyFixture; $fixture.popup.choices[2] = [pscustomobject]@{ Id = 'take_the_edge'; label = 'Take the Edge'; text = 'Risk it.'; enabled = $true }
        $hostileInterrogationCases.Add([pscustomobject]@{ label = 'take-edge-property-case'; fixture = $fixture })

        $cheatInterrogationHostileFixtures = $hostileInterrogationCases.Count
        foreach ($case in $hostileInterrogationCases) {
            $threw = $false
            try { $null = Select-CheatReplayShowdownInterrogationChoice -EventPopup $case.fixture.popup }
            catch { $threw = $true }
            if (-not $threw) {
                Add-Failure "Hostile Cheat interrogation fixture '$($case.label)' did not fail closed."
            }
        }
    }
    else {
        Add-Failure 'Replay policy helper did not export Select-CheatReplayShowdownInterrogationChoice.'
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

    if ($null -ne (Get-Command 'Select-GrandArrivalGreetingChoice' -ErrorAction SilentlyContinue)) {
        $validGrandArrivalGreetingFixtures = @(
            [pscustomobject]@{ label = 'exact-rendered-greeting'; fixture = (New-GrandArrivalGreetingPolicyFixture) },
            [pscustomobject]@{ label = 'hidden-private-sentinels-are-inert'; fixture = (New-GrandArrivalGreetingPolicyFixture -WithHiddenSentinels) }
        )
        $grandArrivalGreetingValidFixtures = $validGrandArrivalGreetingFixtures.Count
        foreach ($case in $validGrandArrivalGreetingFixtures) {
            try {
                $actual = Select-GrandArrivalGreetingChoice `
                    -Talk $case.fixture.talk `
                    -TalkChoices @($case.fixture.talk_choices) `
                    -EventPopup $case.fixture.event_popup
                if ($actual -isnot [string] -or [string]$actual -cne 'continue') {
                    Add-Failure "Valid Grand arrival fixture '$($case.label)' did not choose the exact visible continuation."
                }
            }
            catch {
                Add-Failure "Valid Grand arrival fixture '$($case.label)' threw: $($_.Exception.Message)"
            }
        }

        $hostileGrandArrivalGreetingFixtures = [Collections.Generic.List[object]]::new()
        $fixture = New-GrandArrivalGreetingPolicyFixture; $fixture.event_popup.visible = $true
        $hostileGrandArrivalGreetingFixtures.Add([pscustomobject]@{ label = 'event-popup-visible'; fixture = $fixture })
        $fixture = New-GrandArrivalGreetingPolicyFixture; $fixture.event_popup.visible = 'false'
        $hostileGrandArrivalGreetingFixtures.Add([pscustomobject]@{ label = 'event-popup-visible-non-boolean'; fixture = $fixture })
        $fixture = New-GrandArrivalGreetingPolicyFixture; $fixture.talk.visible = $false
        $hostileGrandArrivalGreetingFixtures.Add([pscustomobject]@{ label = 'talk-hidden'; fixture = $fixture })
        $fixture = New-GrandArrivalGreetingPolicyFixture; $fixture.talk.visible = 1
        $hostileGrandArrivalGreetingFixtures.Add([pscustomobject]@{ label = 'talk-visible-non-boolean'; fixture = $fixture })
        $fixture = New-GrandArrivalGreetingPolicyFixture; $fixture.talk.expanded = $false
        $hostileGrandArrivalGreetingFixtures.Add([pscustomobject]@{ label = 'talk-collapsed'; fixture = $fixture })
        $fixture = New-GrandArrivalGreetingPolicyFixture; $fixture.talk.render_valid = $false
        $hostileGrandArrivalGreetingFixtures.Add([pscustomobject]@{ label = 'talk-render-invalid'; fixture = $fixture })
        $fixture = New-GrandArrivalGreetingPolicyFixture; $fixture.talk.body_complete = $false
        $hostileGrandArrivalGreetingFixtures.Add([pscustomobject]@{ label = 'talk-body-incomplete'; fixture = $fixture })
        $fixture = New-GrandArrivalGreetingPolicyFixture; $fixture.talk.typewriter_active = $true
        $hostileGrandArrivalGreetingFixtures.Add([pscustomobject]@{ label = 'talk-typewriter-active'; fixture = $fixture })
        $fixture = New-GrandArrivalGreetingPolicyFixture; $fixture.talk.typewriter_active = 0
        $hostileGrandArrivalGreetingFixtures.Add([pscustomobject]@{ label = 'talk-typewriter-non-boolean'; fixture = $fixture })
        $fixture = New-GrandArrivalGreetingPolicyFixture; $fixture.talk.event_id = 'dialogue:Normal_Grand_Host_Greeting'
        $hostileGrandArrivalGreetingFixtures.Add([pscustomobject]@{ label = 'event-id-case'; fixture = $fixture })
        $fixture = New-GrandArrivalGreetingPolicyFixture; $fixture.talk.summary = 'Welcome to the Grand.'
        $hostileGrandArrivalGreetingFixtures.Add([pscustomobject]@{ label = 'summary-copy'; fixture = $fixture })
        $fixture = New-GrandArrivalGreetingPolicyFixture; $fixture.talk.choice_ids = @()
        $hostileGrandArrivalGreetingFixtures.Add([pscustomobject]@{ label = 'choice-id-missing'; fixture = $fixture })
        $fixture = New-GrandArrivalGreetingPolicyFixture; $fixture.talk.choice_ids = @('continue', 'leave')
        $hostileGrandArrivalGreetingFixtures.Add([pscustomobject]@{ label = 'choice-id-extra'; fixture = $fixture })
        $fixture = New-GrandArrivalGreetingPolicyFixture; $fixture.talk.choice_ids = @('continue', 'continue')
        $hostileGrandArrivalGreetingFixtures.Add([pscustomobject]@{ label = 'choice-id-duplicate'; fixture = $fixture })
        $fixture = New-GrandArrivalGreetingPolicyFixture; $fixture.talk.choice_ids = @('Continue')
        $hostileGrandArrivalGreetingFixtures.Add([pscustomobject]@{ label = 'choice-id-case'; fixture = $fixture })
        $fixture = New-GrandArrivalGreetingPolicyFixture; $fixture.talk_choices = @()
        $hostileGrandArrivalGreetingFixtures.Add([pscustomobject]@{ label = 'choice-row-missing'; fixture = $fixture })
        $fixture = New-GrandArrivalGreetingPolicyFixture; $fixture.talk_choices = @($fixture.talk_choices[0], $fixture.talk_choices[0])
        $hostileGrandArrivalGreetingFixtures.Add([pscustomobject]@{ label = 'choice-row-duplicate'; fixture = $fixture })
        $fixture = New-GrandArrivalGreetingPolicyFixture; $fixture.talk_choices[0].event_id = 'dialogue:other'
        $hostileGrandArrivalGreetingFixtures.Add([pscustomobject]@{ label = 'choice-row-event-id'; fixture = $fixture })
        $fixture = New-GrandArrivalGreetingPolicyFixture; $fixture.talk_choices[0].id = 'Continue'
        $hostileGrandArrivalGreetingFixtures.Add([pscustomobject]@{ label = 'choice-row-id-case'; fixture = $fixture })
        $fixture = New-GrandArrivalGreetingPolicyFixture; $fixture.talk_choices[0].label = 'Enter'
        $hostileGrandArrivalGreetingFixtures.Add([pscustomobject]@{ label = 'choice-row-copy'; fixture = $fixture })
        $fixture = New-GrandArrivalGreetingPolicyFixture; $fixture.talk_choices[0].enabled = $false
        $hostileGrandArrivalGreetingFixtures.Add([pscustomobject]@{ label = 'choice-row-disabled'; fixture = $fixture })
        $fixture = New-GrandArrivalGreetingPolicyFixture; $fixture.talk_choices[0].enabled = 'true'
        $hostileGrandArrivalGreetingFixtures.Add([pscustomobject]@{ label = 'choice-row-enabled-non-boolean'; fixture = $fixture })
        $fixture = New-GrandArrivalGreetingPolicyFixture
        $fixture.talk_choices = @([pscustomobject]@{
            event_id = 'dialogue:normal_grand_host_greeting'; ID = 'continue'; label = 'Enter the floor'; enabled = $true
        })
        $hostileGrandArrivalGreetingFixtures.Add([pscustomobject]@{ label = 'choice-row-property-case'; fixture = $fixture })

        $grandArrivalGreetingHostileFixtures = $hostileGrandArrivalGreetingFixtures.Count
        foreach ($case in $hostileGrandArrivalGreetingFixtures) {
            $threw = $false
            try {
                $null = Select-GrandArrivalGreetingChoice `
                    -Talk $case.fixture.talk `
                    -TalkChoices @($case.fixture.talk_choices) `
                    -EventPopup $case.fixture.event_popup
            }
            catch {
                $threw = $true
            }
            if (-not $threw) {
                Add-Failure "Hostile Grand arrival fixture '$($case.label)' did not fail closed."
            }
        }
    }
    else {
        Add-Failure 'Replay policy helper did not export Select-GrandArrivalGreetingChoice.'
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
        'function Invoke-HeistSeedPreflight',
        'function Test-CrewFavorPublicSurface',
        'function Invoke-CrewFavorCashierTipBoundary',
        'function Establish-CrewMarker',
        'function Clear-CrewMarkerFavors',
        'function Assert-RenderedAuditNightHook',
        'function Observe-RenderedAuditNightHook',
        'function Assert-RenderedConventionCrowdHook',
        'function Assert-HeistAuditKnowledgeUnderHostileRevisit',
        'function Assert-HeistAuditKnowledgeSaveRelaunchContinue',
        'Select-CheatReplayDuelCheckpointAction',
        'Select-CheatReplayBlackjackCheatAction',
        'Select-CheatReplayPostPeekTransition',
        'Select-CheatReplayBossCalloutAction',
        'Select-CheatReplayShowdownInterrogationChoice',
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
        "`$EvidenceAdmissionTool = Join-Path `$PSScriptRoot 'rw06_2_evidence_admission.ps1'",
        'Resolve-Rw062ReplayAdmission',
        'Assert-Rw062HeistPreflightAdmission',
        'requested_evidence_role = $EvidenceRole',
        'replay_admission = $script:ReplayAdmission',
        'heist_preflight_admission = $script:HeistPreflightAdmissionReceipt',
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
        'function Recover-CleanGrandFareAtCurrentStop',
        'function Recover-GrandFareThroughPublicFunding',
        'function Invoke-CleanScoutingCashOpportunity',
        'function Resolve-VisibleBlockingPresentation',
        'function Restore-EnvironmentSurfaceAfterTravelResult',
        'function Get-PublicTalkChoices',
        'function Get-VisibleTutorialGuideAcknowledgment',
        'function Assert-DeltaQueenBeachRouteInvariant',
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
        "Join-Path `$script:RunRoot 'checkpoint_before.json'",
        "Join-Path `$script:RunRoot 'checkpoint_after.json'",
        'persistence_checkpoint_before_sha256 = $checkpointBeforeHash',
        'persistence_checkpoint_after_sha256 = $checkpointAfterHash',
        'persistence_checkpoint_complete = $checkpointEvidenceComplete',
        'checkpoint_evidence_complete = $checkpointEvidenceComplete',
        "record_kind = 'final_public_checkpoint'",
        'public_fingerprint = $publicFingerprint',
        'checkpoint_fingerprint = $checkpointFingerprint',
        'observed_seed = $observedSeed',
        '$observedSeed -cne $Seed',
        '$currentFinalCheckpointJson -cne $referenceFinalCheckpointJson',
        '$saveText -cne $expectedVisibleText',
        "`$acknowledgment = 'Saved to Resume Slot.'",
        'Assert-ExplicitSaveAcknowledged -Milestone $Milestone',
        "Assert-ExplicitSaveAcknowledged -Milestone 'The Count learned Audit route before plan lock'",
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
        "Get-ExactReplayBoolean -InputObject `$script:LastObservation -Path @('screen', 'run_report_visible')",
        '$Repeat -ceq 2',
        "role = 'child_development_run'",
        "repeat_profile_scope = 'shared_caller_appdata'",
        "fixed_repeat_qualification_authority = 'outer_independent_profile_aggregate_only'",
        'release_qualifying = $false',
        "qualification = 'non_qualifying_development_run'",
        'heist_seed_preflight = $heistSeedPreflight',
        'heist_launch_setup = $script:HeistLaunchSetup',
        'PLAY did not visibly enter a live first-night lesson',
        "StartsWith('tutorial_guide:', [StringComparison]::Ordinal)",
        "`$choiceIds.Count -cne 1 -or [string]`$choiceIds[0] -cne 'continue'",
        "Choose-VisibleChoice -ChoiceId 'continue'",
        'follow Pal''s visible tutorial guidance: $label',
        'The live first-night lesson did not render its run menu.',
        'The semantic seed entry was not preserved as exact visible public evidence',
        'Main Menu did not visibly return the learned Count checkpoint to START before relaunch.'
    )) {
        Assert-Contains $runner $required "Replay runner is missing required source contract token: $required"
    }

    foreach ($required in @(
        'func _public_observation() -> Dictionary:',
        'return PublicObservation.sanitize(snapshot)',
        'const REPLAY_PAUSE_OWNER := "agent_replay"',
        'const SHUTDOWN_DRAIN_FRAMES := 12',
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
    Assert-Match $bridge '(?s)while not shutting_down:\s*await _poll_once\(\)\s*if shutting_down:\s*break\s*await create_timer\(0\.05\)\.timeout' 'The production-input bridge must not create another SceneTreeTimer after a quit command starts shutdown.'
    $pollMatch = [regex]::Match($bridge, '(?ms)^func _poll_once\(\) -> void:\s*(?<body>.*?)(?=^func |\z)')
    if (-not $pollMatch.Success) {
        Add-Failure 'The production-input bridge has no uniquely bounded _poll_once body for shutdown custody.'
    }
    else {
        $pollBody = $pollMatch.Groups['body'].Value
        $writeIndex = $pollBody.IndexOf('_write_json(_path("%04d.result.json" % next_command), result)', [StringComparison]::Ordinal)
        $shutdownIndex = $pollBody.IndexOf('if bool(result.get("quit", false)):', [StringComparison]::Ordinal)
        $queueIndex = $pollBody.IndexOf('app.queue_free()', [StringComparison]::Ordinal)
        $nullIndex = $pollBody.IndexOf('app = null', [StringComparison]::Ordinal)
        $drainIndex = $pollBody.IndexOf('for _frame in range(SHUTDOWN_DRAIN_FRAMES):', [StringComparison]::Ordinal)
        $awaitIndex = if ($drainIndex -ge 0) { $pollBody.IndexOf('await process_frame', $drainIndex, [StringComparison]::Ordinal) } else { -1 }
        $quitIndex = $pollBody.IndexOf('quit(0)', [StringComparison]::Ordinal)
        $quitCount = [regex]::Matches($pollBody, [regex]::Escape('quit(0)')).Count
        $ordered = $writeIndex -ge 0 -and $shutdownIndex -gt $writeIndex -and $queueIndex -gt $shutdownIndex -and
            $nullIndex -gt $queueIndex -and $drainIndex -gt $nullIndex -and $awaitIndex -gt $drainIndex -and
            $quitIndex -gt $awaitIndex -and $quitCount -ceq 1
        if (-not $ordered) {
            Add-Failure 'The production-input bridge must persist the accepted quit result, free/null the production host, drain a bounded frame window, and only then issue its sole quit.'
        }
        if ($shutdownIndex -ge 0 -and $drainIndex -gt $shutdownIndex) {
            $beforeDrain = $pollBody.Substring($shutdownIndex, $drainIndex - $shutdownIndex)
            if ($beforeDrain -match 'create_timer\s*\(' -or $beforeDrain -match 'quit\s*\(') {
                Add-Failure 'The production-input bridge must not create a timer or quit between entering shutdown and starting its bounded frame drain.'
            }
        }
        if ($shutdownIndex -ge 0) {
            $shutdownSlice = $pollBody.Substring($shutdownIndex)
            if ($shutdownSlice -match 'create_timer\s*\(') {
                Add-Failure 'The production-input bridge must not create any SceneTreeTimer after entering shutdown.'
            }
        }
    }

    $validPersistenceCheckpointFixture = @'
function Assert-SaveRelaunchContinue {
    $beforeJson = $before | ConvertTo-Json -Depth 10 -Compress
    $afterJson = $after | ConvertTo-Json -Depth 10 -Compress
    $before | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $script:RunRoot 'checkpoint_before.json') -Encoding utf8
    $after | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $script:RunRoot 'checkpoint_after.json') -Encoding utf8
    if ($afterJson -cne $beforeJson) {
        throw 'mismatch'
    }
    $script:MidpointSaved = $true
}
'@
    $persistenceCheckpointValidFixtures = 3
    if (-not (Test-PersistenceCheckpointWriteSequence -Source $validPersistenceCheckpointFixture -FunctionName 'Assert-SaveRelaunchContinue' -Depth 10)) {
        Add-Failure 'Valid persistence checkpoint write-order fixture was rejected.'
    }
    if (-not (Test-PersistenceCheckpointWriteSequence -Source $runner -FunctionName 'Assert-SaveRelaunchContinue' -Depth 10)) {
        Add-Failure 'Generic Save/Continue must write distinct before/after checkpoints after capture and before comparison or success.'
    }
    if (-not (Test-PersistenceCheckpointWriteSequence -Source $runner -FunctionName 'Assert-HeistAuditKnowledgeSaveRelaunchContinue' -Depth 20)) {
        Add-Failure 'Q-013 Save/Continue must write distinct learned-Count before/after checkpoints after capture and before comparison or success.'
    }
    $hostilePersistenceCheckpointFixtures = @(
        [pscustomobject]@{ label = 'missing-before-write'; source = @'
function Assert-SaveRelaunchContinue {
    $beforeJson = $before | ConvertTo-Json -Depth 10 -Compress
    $afterJson = $after | ConvertTo-Json -Depth 10 -Compress
    $after | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $script:RunRoot 'checkpoint_after.json') -Encoding utf8
    if ($afterJson -cne $beforeJson) { throw 'mismatch' }
    $script:MidpointSaved = $true
}
'@ },
        [pscustomobject]@{ label = 'missing-after-write'; source = @'
function Assert-SaveRelaunchContinue {
    $beforeJson = $before | ConvertTo-Json -Depth 10 -Compress
    $afterJson = $after | ConvertTo-Json -Depth 10 -Compress
    $before | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $script:RunRoot 'checkpoint_before.json') -Encoding utf8
    if ($afterJson -cne $beforeJson) { throw 'mismatch' }
    $script:MidpointSaved = $true
}
'@ },
        [pscustomobject]@{ label = 'same-path'; source = @'
function Assert-SaveRelaunchContinue {
    $beforeJson = $before | ConvertTo-Json -Depth 10 -Compress
    $afterJson = $after | ConvertTo-Json -Depth 10 -Compress
    $before | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $script:RunRoot 'checkpoint_before.json') -Encoding utf8
    $after | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $script:RunRoot 'checkpoint_before.json') -Encoding utf8
    if ($afterJson -cne $beforeJson) { throw 'mismatch' }
    $script:MidpointSaved = $true
}
'@ },
        [pscustomobject]@{ label = 'swapped-snapshots'; source = @'
function Assert-SaveRelaunchContinue {
    $beforeJson = $before | ConvertTo-Json -Depth 10 -Compress
    $afterJson = $after | ConvertTo-Json -Depth 10 -Compress
    $after | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $script:RunRoot 'checkpoint_before.json') -Encoding utf8
    $before | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $script:RunRoot 'checkpoint_after.json') -Encoding utf8
    if ($afterJson -cne $beforeJson) { throw 'mismatch' }
    $script:MidpointSaved = $true
}
'@ },
        [pscustomobject]@{ label = 'writes-only-on-mismatch'; source = @'
function Assert-SaveRelaunchContinue {
    $beforeJson = $before | ConvertTo-Json -Depth 10 -Compress
    $afterJson = $after | ConvertTo-Json -Depth 10 -Compress
    if ($afterJson -cne $beforeJson) {
        $before | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $script:RunRoot 'checkpoint_before.json') -Encoding utf8
        $after | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $script:RunRoot 'checkpoint_after.json') -Encoding utf8
        throw 'mismatch'
    }
    $script:MidpointSaved = $true
}
'@ },
        [pscustomobject]@{ label = 'writes-after-comparison'; source = @'
function Assert-SaveRelaunchContinue {
    $beforeJson = $before | ConvertTo-Json -Depth 10 -Compress
    $afterJson = $after | ConvertTo-Json -Depth 10 -Compress
    if ($afterJson -cne $beforeJson) { throw 'mismatch' }
    $before | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $script:RunRoot 'checkpoint_before.json') -Encoding utf8
    $after | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $script:RunRoot 'checkpoint_after.json') -Encoding utf8
    $script:MidpointSaved = $true
}
'@ },
        [pscustomobject]@{ label = 'success-before-writes'; source = @'
function Assert-SaveRelaunchContinue {
    $beforeJson = $before | ConvertTo-Json -Depth 10 -Compress
    $afterJson = $after | ConvertTo-Json -Depth 10 -Compress
    $script:MidpointSaved = $true
    $before | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $script:RunRoot 'checkpoint_before.json') -Encoding utf8
    $after | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $script:RunRoot 'checkpoint_after.json') -Encoding utf8
    if ($afterJson -cne $beforeJson) { throw 'mismatch' }
}
'@ },
        [pscustomobject]@{ label = 'writes-in-unreachable-branch'; source = @'
function Assert-SaveRelaunchContinue {
    $beforeJson = $before | ConvertTo-Json -Depth 10 -Compress
    $afterJson = $after | ConvertTo-Json -Depth 10 -Compress
    if ($false) {
        $before | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $script:RunRoot 'checkpoint_before.json') -Encoding utf8
        $after | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $script:RunRoot 'checkpoint_after.json') -Encoding utf8
    }
    if ($afterJson -cne $beforeJson) { throw 'mismatch' }
    $script:MidpointSaved = $true
}
'@ },
        [pscustomobject]@{ label = 'unconditional-return-before-writes'; source = @'
function Assert-SaveRelaunchContinue {
    $beforeJson = $before | ConvertTo-Json -Depth 10 -Compress
    $afterJson = $after | ConvertTo-Json -Depth 10 -Compress
    return
    $before | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $script:RunRoot 'checkpoint_before.json') -Encoding utf8
    $after | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $script:RunRoot 'checkpoint_after.json') -Encoding utf8
    if ($afterJson -cne $beforeJson) { throw 'mismatch' }
    $script:MidpointSaved = $true
}
'@ },
        [pscustomobject]@{ label = 'missing-before-capture'; source = @'
function Assert-SaveRelaunchContinue {
    $afterJson = $after | ConvertTo-Json -Depth 10 -Compress
    $before | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $script:RunRoot 'checkpoint_before.json') -Encoding utf8
    $after | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $script:RunRoot 'checkpoint_after.json') -Encoding utf8
    if ($afterJson -cne $beforeJson) { throw 'mismatch' }
    $script:MidpointSaved = $true
}
'@ }
    )
    $persistenceCheckpointHostileFixtures = $hostilePersistenceCheckpointFixtures.Count
    foreach ($fixture in $hostilePersistenceCheckpointFixtures) {
        if (Test-PersistenceCheckpointWriteSequence -Source ([string]$fixture.source) -FunctionName 'Assert-SaveRelaunchContinue' -Depth 10) {
            Add-Failure "Hostile persistence checkpoint fixture '$($fixture.label)' did not fail closed."
        }
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
    Assert-Match $launcher '(?s)\$EngineLogPath\s*=\s*Join-Path\s+\$SessionRoot\s+''godot\.engine\.log''.*?''--log-file'',\s*\$EngineLogPath' 'Every agent playtest session must use its own Godot --log-file inside the isolated session root.'
    Assert-Contains $bridge 'action_id == "blackjack_deal"' 'The bridge must recognize blackjack''s invisible compatibility Deal hit.'
    Assert-Contains $bridge 'not bool(public_game.get("can_deal", false))' 'The bridge must reject the invisible Deal hit unless the public DEAL control is available.'
    Assert-NotMatch $bridge 'set_application_pause_owner[^\r\n]+false' 'The bridge must retain its deterministic replay pause owner for the entire process lifetime.'
    Assert-Contains $bridge 'var choice_list := talk_dock.get("choice_list") as Control if talk_dock != null else null' 'Semantic TalkDock choices must bind to the actual rendered choice list.'
    Assert-Contains $runner "@('look', 'clickable', 'talk_choices')" 'Replay routes must consume the rendered TalkDock enabled-state mapping.'
    Assert-Contains $runner "@('look', 'clickable', 'scroll_surfaces')" 'Replay routes must consume only the public rendered scroll-surface mapping.'
    Assert-Match $runner '(?s)function Get-VisibleTutorialGuideAcknowledgment.*?render_valid.*?tutorial_guide:.*?choiceIds\.Count\s+-cne\s+1.*?choiceIds\[0\].*?continue.*?Get-PublicTalkChoices.*?enabled\s+-is\s+\[bool\]' 'Coach recovery must accept only one fully rendered, exactly typed, enabled continue choice from the public tutorial-guide TalkDock.'
    Assert-NotMatch $runner 'PLAYTEST-CATALOG-01' 'The stale historical Heist seed must not remain in the live replay runner.'
    Assert-Contains $runner "`$HeistSeedPreflightTool = Join-Path `$PSScriptRoot 'rw06_2_heist_seed_preflight.ps1'" 'Heist replay must bind its engine-free preflight from the checked-in tool path.'
    Assert-Contains $runner "`$EvidenceAdmissionTool = Join-Path `$PSScriptRoot 'rw06_2_evidence_admission.ps1'" 'Heist replay must bind its fail-closed evidence role/seed admission from the checked-in helper.'
    Assert-Match $runner '(?s)\$EvidenceRole\s*=\s*\$EvidenceRole\.ToLowerInvariant\(\).*?Resolve-Rw062ReplayAdmission.*?function Invoke-HeistSeedPreflight.*?& \$HeistSeedPreflightTool.*?Assert-Rw062HeistPreflightAdmission.*?function ConvertTo-BridgeBase64Token' 'Q-013A/Q-017A Heist replay must resolve exact role/seed admission, then bind the production-tree preflight receipt before engine launch.'
    Assert-NotMatch $runner 'heist\s*=\s*''RW06-HEIST-AUDIT-0013''' 'The rejected Convention seed must not remain the live Heist runner default.'
    Assert-Match $evidenceAdmission '(?s)fixed\s*=.*?heist\s*=\s*''RW06-HEIST-AUDIT-0002''.*?fresh_interactive\s*=.*?heist\s*=\s*''RW06-HEIST-AUDIT-0000''.*?\$EvidenceRole\s+-ceq\s+''fresh-interactive''.*?\$Ending\s+-cne\s+''heist''.*?\$Repeat\s+-ne\s+1.*?authorizedFreshSeed.*?if\s*\(\$Ending\s+-ceq\s+''heist''\s+-and\s+\$resolvedSeed\s+-cne\s+\$fixedHeistSeed\)' 'Q-013A/Q-017A admission must keep fixed Heist on exact 0002 and admit only one explicit Heist/Repeat-1 fresh seed 0000.'
    Assert-Match $runner '(?s)\$runSummary\s*=\s*\[ordered\]@\{.*?requested_evidence_role\s*=\s*\$EvidenceRole.*?replay_admission\s*=\s*\$script:ReplayAdmission.*?heist_preflight_admission\s*=\s*\$script:HeistPreflightAdmissionReceipt.*?\$finalSummary\s*=\s*\[ordered\]@\{.*?requested_evidence_role\s*=\s*\$EvidenceRole.*?replay_admission\s*=\s*\$script:ReplayAdmission.*?heist_preflight_admission\s*=\s*\$script:HeistPreflightAdmissionReceipt' 'Every direct replay report level must retain its exact evidence role, seed admission, and authenticated Heist preflight receipt.'
    Assert-Match $runner '(?s)\$invocationRoot\s*=.*?Invoke-HeistSeedPreflight.*?for \(\$iteration.*?Start-BridgeSession' 'Heist seed preflight must finish before any live replay iteration can start an engine session.'
    Assert-Match $runner '(?ms)^function Start-NormalSeededRun\s*\{.*?Click-Button\s+-Text\s+''RUN SETUP''.*?run_config_visible.*?\$Ending\s+-ceq\s+''heist''.*?Assert-HeistFreshStandardRunSetup\s+-Observation\s+\$script:LastObservation.*?set_field seed \$Seed.*?(?=^function |\z)' 'The live Heist route must authenticate exact visible fresh Standard/Random/default-content setup before typing its seed.'
    Assert-Match $replayPolicy '(?ms)^function Assert-HeistFreshStandardRunSetup.*?screen.*?START.*?run_config_visible.*?selected_challenge_id.*?selected_home_type_id.*?selected_content_groups.*?universal_passive_items.*?numbers_pack.*?challengeId\s+-isnot\s+\[string\].*?challengeId\s+-cne\s+''''.*?homeTypeId\s+-cne\s+''random''.*?contentGroups\s+-isnot\s+\[array\].*?non-default visible content group index.*?(?=^function |\z)' 'Fresh Heist launch policy must fail closed on screen, type, challenge, home, content-group membership, case, or order drift.'
    Assert-Match $runner '(?ms)^function Assert-RenderedAuditNightHook\s*\{.*?canvas_objects.*?Select-HeistAuditNightPublicHook.*?-Observation \$script:LastObservation.*?-CanvasObjects \$canvasObjects.*?(?=^function |\z)' 'The live route must bind its Audit assertion only to the public observation and rendered canvas-object list.'
    Assert-Match $runner '(?ms)^function Observe-RenderedAuditNightHook\s*\{.*?Assert-RenderedAuditNightHook.*?Invoke-EventObjectChoice\s*`?\s*-EventId\s+''scenario_audit_roster''\s*`?\s*-ChoiceId\s+''read_the_shift''.*?Restore-EnvironmentSurfaceAfterTravelResult.*?(?=^function |\z)' 'The live route must resolve the exact visible Audit roster/read_the_shift choice and restore the ordinary public room surface.'
    Assert-Match $runner '(?ms)^function Assert-RenderedConventionCrowdHook\s*\{.*?canvas_objects.*?Select-HeistConventionCrowdPublicHook.*?-Observation \$script:LastObservation.*?-CanvasObjects \$canvasObjects.*?(?=^function |\z)' 'The live route must bind its hostile Convention revisit only to the public observation and rendered canvas-object list.'
    Assert-Match $runner '(?ms)^function Assert-HeistAuditKnowledgeUnderHostileRevisit\s*\{.*?Reach-GrandCasino.*?Restore-EnvironmentSurfaceAfterTravelResult.*?Assert-RenderedConventionCrowdHook.*?Enter-PunchlineBackRoom.*?Test-CountPlanLive.*?(?=^function |\z)' 'The learned Audit route must revisit the real Grand, prove the visible non-Audit Convention hook, return to the planning table, and keep Count live.'
    Assert-Match $runner '(?ms)^function Test-CountPlanLive\s*\{.*?Get-EventChoiceRoomAction.*?lock_the_count.*?enabled.*?-isnot\s+\[bool\].*?rendered.*?-isnot\s+\[bool\].*?\[bool\]\$enabled\s+-and\s+\[bool\]\$rendered.*?(?=^function |\z)' 'Every Count-live decision must require exact boolean enabled and rendered witnesses from the public planning-table row.'
    $planningProjectionSource = [regex]::Match($runner, '(?ms)^function Get-PlanningTableProjection\s*\{.*?(?=^function |\z)').Value
    Assert-Match $planningProjectionSource '(?s)Get-ExactReplayObjectArray.*?room_actions.*?Get-ExactReplayString.*?emit_object_id.*?Get-ExactReplayBoolean.*?enabled.*?Get-ExactReplayBoolean.*?rendered.*?StringComparer\]::Ordinal.*?duplicate exact choice id.*?lock_the_count.*?exactly one rendered and enabled Count lock' 'The persisted planning projection must retain exact room-action types, reject blank/duplicate identities, sort ordinally, and require one rendered/enabled Count lock.'
    Assert-NotMatch $planningProjectionSource 'event_popup|Get-VisibleChoiceIds|Get-PublicTalkChoices' 'The Q-013 persistence projection must not replace rendered room-action proof with modal choice metadata.'
    $heistPersistenceSource = [regex]::Match($runner, '(?ms)^function Assert-HeistAuditKnowledgeSaveRelaunchContinue\s*\{.*?(?=^function |\z)').Value
    Assert-Match $heistPersistenceSource '(?s)\$before\s*=\s*\[ordered\]@\{\s*checkpoint\s*=\s*Get-PersistenceCheckpoint\s*planning_choices\s*=\s*\$beforeProjection\s*\}.*?\$beforeJson.*?\$after\s*=\s*\[ordered\]@\{\s*checkpoint\s*=\s*Get-PersistenceCheckpoint\s*planning_choices\s*=\s*\$afterProjection\s*\}.*?\$afterJson' 'Q-013 retained checkpoint files must include both the public economy/location checkpoint and the exact rendered planning-table projection before and after Continue.'
    Assert-Match $runner '(?ms)^function Assert-HeistAuditKnowledgeSaveRelaunchContinue\s*\{.*?Get-PlanningTableProjection.*?choice_id\s+-ceq\s+''lock_the_count''.*?Count\s+-cne\s+1.*?enabled\s+-isnot\s+\[bool\].*?rendered\s+-isnot\s+\[bool\].*?Click-RunMenuButton\s+-Text\s+''Save''.*?The Count learned Audit route before plan lock.*?Start-BridgeSession.*?CONTINUE.*?Get-PlanningTableProjection.*?choice_id\s+-ceq\s+''lock_the_count''.*?enabled\s+-isnot\s+\[bool\].*?rendered\s+-isnot\s+\[bool\].*?Public learned-Audit planning state changed.*?(?=^function |\z)' 'Q-013 persistence must require one exactly rendered and enabled Count lock before Save and after a full process relaunch/Continue, before the plan itself is locked.'
    Assert-Match $runner '(?ms)^function Invoke-HeistEndingRoute\s*\{\s*Establish-CrewMarker\s*\r?\n\s*Reach-GrandCasino\s*\r?\n\s*Restore-EnvironmentSurfaceAfterTravelResult\s*\r?\n\s*Observe-RenderedAuditNightHook\s*\r?\n\s*Clear-CrewMarkerFavors\s*\r?\n\s*Ensure-PunchlineCasinoDiscovered\s*\r?\n\s*Recruit-Bishop\s*\r?\n\s*Promote-BishopToInnerCircle\s*\r?\n\s*Assert-HeistAuditKnowledgeUnderHostileRevisit\s*\r?\n\s*Assert-HeistAuditKnowledgeSaveRelaunchContinue.*?(?=^function |\z)' 'The Count route must naturally read fresh Audit, prove a hostile revisit, and prove restored learned knowledge before it locks Plan A.'
    Assert-Match $runner '(?ms)^function Ensure-PunchlineCasinoDiscovered\s*\{.*?Invoke-OverflowRoomActionButton.*?Parking Lot Tip: Follow the tip.*?afterEventVisible.*?Select-GrandFareMachineJamChoice.*?choiceId\s+-cne\s+''wait''.*?Choose-VisibleChoice.*?post-tip machine_jam.*?afterScreen.*?RESULT.*?gas_station_casino.*?afterNodeId.*?\$nodeId.*?The package changes hands\. Nothing else does\..*?Restore-EnvironmentSurfaceAfterTravelResult.*?afterScreen.*?ENVIRONMENT.*?afterEventVisible.*?afterTalkVisible.*?afterTransitionActive.*?Punchline on the public map.*?(?=^function |\z)' 'The overflow Parking Lot Tip may resolve only to an uninterrupted room or its exact rendered machine_jam de-escalation and authenticated Result, then must restore a modal-free room before unchanged Punchline discovery verification.'
    if (-not (Test-HeistRouteExactCommandInventory -Source $runner)) {
        Add-Failure 'The Count route command inventory/order drifted or gained an unconditional alternate-route call.'
    }
    $heistRouteHostile = $runner.Replace(
        '    Assert-HeistAuditKnowledgeSaveRelaunchContinue',
        "    Assert-HeistAuditKnowledgeSaveRelaunchContinue`r`n    Invoke-HeistAlternateRoute"
    )
    if ($heistRouteHostile -ceq $runner) {
        Add-Failure 'The Count route command-inventory hostile could not find its exact mutation token.'
    }
    elseif (Test-HeistRouteExactCommandInventory -Source $heistRouteHostile) {
        Add-Failure 'The Count route command inventory accepted an unconditional alternate-route call.'
    }
    $heistRouteSource = [regex]::Match($runner, '(?ms)^function Invoke-HeistEndingRoute\s*\{.*?(?=^function |\z)').Value
    $heistSaveCount = [regex]::Matches($heistRouteSource, '\bAssert-HeistAuditKnowledgeSaveRelaunchContinue\b').Count
    $heistSaveIndex = $heistRouteSource.IndexOf('Assert-HeistAuditKnowledgeSaveRelaunchContinue', [StringComparison]::Ordinal)
    $heistLockIndex = $heistRouteSource.IndexOf("-ChoiceId 'lock_the_count'", [StringComparison]::Ordinal)
    $heistSetupIndex = $heistRouteSource.IndexOf('Complete-CountIdentitySessions', [StringComparison]::Ordinal)
    if ($heistSaveCount -cne 1 -or $heistSaveIndex -lt 0 -or $heistLockIndex -le $heistSaveIndex -or $heistSetupIndex -le $heistLockIndex) {
        Add-Failure 'The live Heist route must perform its sole Save/Continue proof after hostile learned-Audit verification but before Count lock and setup.'
    }
    Assert-NotMatch $heistRouteSource 'whale|the_whale_game|Plan B' 'The fixed Heist replay must not claim or silently select an unproved Plan B fallback.'
    $crewBoundarySource = [regex]::Match($runner, '(?ms)^function Invoke-CrewFavorCashierTipBoundary\s*\{.*?(?=^function |\z)').Value
    $crewMarkerSource = [regex]::Match($runner, '(?ms)^function Establish-CrewMarker\s*\{.*?(?=^function |\z)').Value
    $crewClearSource = [regex]::Match($runner, '(?ms)^function Clear-CrewMarkerFavors\s*\{.*?(?=^function |\z)').Value
    Assert-Match $crewBoundarySource '(?s)Navigate-ToArchetype\s+-ArchetypeId\s+''corner_store''.*?Find-CanvasObject\s+-SemanticId\s+''service:cashier_tip''.*?Cashier Tip.*?object_type.*?service.*?Get-RenderedHudInteger\s+-Name bankroll.*?Open-SemanticObject.*?-SemanticId\s+''service:cashier_tip''.*?-PreferredActions\s+@\(''Use''\).*?afterCash\s+-ne\s+\$beforeCash\s+-\s*4' 'Crew marker aging must use the exact rendered Corner Store Cashier Tip action and verify its visible $4 bankroll charge.'
    Assert-NotMatch $crewBoundarySource 'run_state|debt|turns_remaining|narrative_flags|crew_state|Open-CageCounter|cage_buy|cage_cashout' 'Crew Cashier Tip boundary must not read private timing/state or return to the wider Grand/Cage exchange.'
    Assert-Match $crewMarkerSource '(?s)Navigate-ToArchetype\s+-ArchetypeId\s+''corner_store''.*?Select-GrandFareFundingObject.*?lender_id\s+-cne\s+''the_crew''.*?beforeDebtCount\s+-ne\s+0.*?click_object lender:the_crew.*?Select-GrandFareFundingObjectAction.*?lender_conversation:borrow:the_crew.*?Select-GrandFareFundingTalkOffer.*?principal\s+-ne\s+45.*?click_choice accept.*?Assert-GrandFareFundingConfirmation.*?click_choice accept.*?Assert-GrandFareFundingResult.*?GrandFareAcceptedLenderIds\.Add\(''the_crew''\)' 'Crew marker funding must validate the exact debt-free public offer, both confirmation presses, $45 principal, and exact bankroll/debt result.'
    Assert-Match $crewClearSource '(?s)for\s*\(\$favor\s*=\s*1;\s*\$favor\s*-le\s*2.*?for\s*\(\$boundary\s*=\s*1;\s*\$boundary\s*-le\s*3\s+-and\s+-not\s+\(Test-CrewFavorPublicSurface\).*?Invoke-CrewFavorCashierTipBoundary.*?Test-CrewFavorPublicSurface.*?run_package.*?Complete-PublicDelivery' 'Crew route must clear both favors, using at most three exact Cashier Tip boundaries only while no public favor is due, then complete each visible delivery.'
    Assert-NotMatch ($crewMarkerSource + $crewClearSource) 'Travel-ToNode|Reach-GrandCasino|Open-CageCounter|Invoke-CrewFavorPublicActionBoundary' 'Crew marker aging must not fall back to travel or the removed Grand/Cage boundary.'
    Assert-NotMatch $runner '(?ms)^function Invoke-CrewFavorPublicActionBoundary\s*\{' 'The obsolete Grand/Cage Crew boundary helper must stay removed.'
    Assert-Match $replayPolicy '(?ms)^function Select-HeistAuditNightPublicHook.*?screen.*?ENVIRONMENT.*?archetype_id.*?grand_casino.*?semantic_id.*?event:scenario_audit_roster.*?matches\.Count\s+-ne\s+1.*?The Audit Roster.*?object_type.*?rendered\s+-isnot\s+\[bool\].*?enabled\s+-isnot\s+\[bool\].*?(?=^function |\z)' 'Audit route policy must require exactly one enabled and rendered public Audit Roster event on Grand Main.'
    $auditPolicySource = [regex]::Match($replayPolicy, '(?ms)^function Select-HeistAuditNightPublicHook.*?(?=^function |\z)').Value
    Assert-NotMatch $auditPolicySource 'scenario_hook_flags|narrative_flags|run_state|crew_heist_state' 'Audit route policy must not infer the hook from private model state.'
    Assert-Match $replayPolicy '(?ms)^function Select-HeistConventionCrowdPublicHook.*?screen.*?ENVIRONMENT.*?archetype_id.*?grand_casino.*?event:scenario_audit_roster.*?Count\s+-ne\s+0.*?event:scenario_convention_badge.*?matches\.Count\s+-ne\s+1.*?Borrowed Badge.*?object_type.*?rendered\s+-isnot\s+\[bool\].*?enabled\s+-isnot\s+\[bool\].*?(?=^function |\z)' 'Hostile revisit policy must reject any rendered Audit hook and require exactly one enabled public Convention badge on Grand Main.'
    $conventionPolicySource = [regex]::Match($replayPolicy, '(?ms)^function Select-HeistConventionCrowdPublicHook.*?(?=^function |\z)').Value
    Assert-NotMatch $conventionPolicySource 'scenario_hook_flags|narrative_flags|run_state|crew_heist_state' 'Convention revisit policy must not infer hostile or learned state from private model data.'
    Assert-Match $heistSeedPreflight '(?s)function Get-Rw062ProductionScenarioContract.*?\$TownStatePath.*?\$PoliceSweepPath.*?\$CharacterChainPath.*?\$townState\s*=\s*Get-Content.*?\$policeSweep\s*=\s*Get-Content.*?\$characterChain\s*=\s*Get-Content' 'Engine-free Heist preflight must load the complete production multiplier chain.'
    foreach ($requiredPreflightToken in @(
        '_on_start_pressed', 'normal_run_start_modifiers', 'carried_container_rows',
        'text_to_seed', 'challenge_key', 'ENVIRONMENT_SITUATION_NONE_PERCENT',
        'recent_scenario_ids', 'town_state', 'CharacterChainModelScript',
        'police_sweep', 'GRAND_CASINO_IDS', 'pawn_shop_sals_mood'
    )) {
        Assert-Contains $heistSeedPreflight $requiredPreflightToken "Engine-free Heist preflight is missing production binding token: $requiredPreflightToken"
    }
    Assert-Match $heistSeedPreflight '(?s)function Get-Rw062GrandScenarioSelection.*?Get-Rw062FreshProfileChallengeKey.*?grand_casino.*?function Assert-Rw062AuditNightSelection' 'Engine-free Heist preflight must model the exact Grand weighted selection and fail-closed Audit assertion.'
    Assert-Match $heistSeedPreflight '(?s)RW06-CLEAN-ROUTE-01.*?6620395.*?RW06-HEIST-AUDIT-0002.*?run_seed\s*-ne\s*919325714.*?stream_seed\s*-ne\s*1392077385.*?none_roll\s*-ne\s*59.*?weighted_roll\s*-ne\s*24088.*?RW06-HEIST-AUDIT-0013.*?run_seed\s*=\s*1868801668.*?selected\s*=\s*''grand_casino_convention_crowd''.*?PLAYTEST-CATALOG-01.*?FIRST-NIGHT-ACE-17.*?RecentScenarioIds\s+@\(''grand_casino_audit_night''\).*?Recent Audit history did not fail closed' 'Heist seed contract must preserve the packed-save calibration, exact `0002` candidate, rejected `0013`, empty/non-Audit hostiles, and recent-Audit suppression.'
    Assert-NotMatch $heistSeedPreflight 'scenario_pins|tutorial_overrides|debug|inject' 'Natural Heist preflight must not pin, inject, or use tutorial/debug scenario authority.'
    Assert-Match $replayPolicy '(?s)function Assert-DeltaQueenBeachPublicRoute.*?ArchetypeId\s+-cne\s+''delta_queen''.*?beachNodes\.Count\s+-cne\s+1.*?state.*?revealed.*?visited.*?beachCost.*?-cne\s+0.*?beachTravelTarget\s+-isnot\s+\[bool\].*?-not\s+\[bool\]\$beachTravelTarget.*?beachEnabled\s+-isnot\s+\[bool\].*?exact transient boat travel lock.*?another normal Delta Queen travel destination was enabled' 'Q-011 policy must require one visible final-selection zero-fare Beach route and allow it disabled only during the exact global boat travel lock.'
    Assert-Match $runner '(?s)function Assert-DeltaQueenBeachRouteInvariant.*?Open-WorldMap.*?Assert-DeltaQueenBeachPublicRoute.*?finally.*?Close-WorldMap.*?function Travel-ToNode.*?Assert-DeltaQueenBeachRouteInvariant.*?function Assert-SaveRelaunchContinue.*?Public persistence checkpoint changed.*?Assert-DeltaQueenBeachRouteInvariant' 'Every real Delta Queen arrival and restored Continue checkpoint must verify the Q-011 Beach route through the public map.'
    Assert-Match $runner '(?s)\$checkpointBeforePath\s*=\s*\[IO\.Path\]::GetFullPath\(\(Join-Path \$script:RunRoot ''checkpoint_before\.json''\)\).*?\$checkpointAfterPath\s*=\s*\[IO\.Path\]::GetFullPath\(\(Join-Path \$script:RunRoot ''checkpoint_after\.json''\)\).*?Get-FileHash\s+-LiteralPath\s+\$checkpointBeforePath\s+-Algorithm\s+SHA256.*?Get-FileHash\s+-LiteralPath\s+\$checkpointAfterPath\s+-Algorithm\s+SHA256' 'Each run must hash exact absolute before/after checkpoint files after the process-relaunch comparison.'
    Assert-Match $runner '(?s)\$checkpointEvidenceComplete\s*=\s*\$script:MidpointSaved\s+-and\s*\$checkpointBeforeHash\s+-cmatch\s+''\^\[a-f0-9\]\{64\}\$''.*?\$checkpointAfterHash\s+-cmatch\s+''\^\[a-f0-9\]\{64\}\$''.*?\$checkpointBeforeHash\s+-ceq\s+\$checkpointAfterHash.*?if\s*\(\$passed\s+-and\s+-not\s+\$checkpointEvidenceComplete\).*?\$passed\s*=\s*\$false.*?missing, unhashed, or unequal' 'A route cannot remain passed when its authenticated midpoint was not reached or either retained checkpoint is missing, unhashed, or unequal.'
    Assert-Match $runner '(?s)\$runSummary\s*=\s*\[ordered\]@\{.*?persistence_checkpoint_before\s*=.*?\$checkpointBeforePath.*?persistence_checkpoint_before_sha256\s*=\s*\$checkpointBeforeHash.*?persistence_checkpoint_after\s*=.*?\$checkpointAfterPath.*?persistence_checkpoint_after_sha256\s*=\s*\$checkpointAfterHash.*?persistence_checkpoint_equal\s*=\s*\$checkpointEvidenceComplete.*?persistence_checkpoint_complete\s*=\s*\$checkpointEvidenceComplete.*?\}.*?\$runReceipt\s*=\s*Assert-ExactReplayRunSummary.*?if\s*\(\$latestRunReceipt\.passed\s+-isnot\s+\[bool\]\s+-or\s+-not\s+\$latestRunReceipt\.passed\).*?throw' 'Each run summary must retain exact checkpoint paths/hashes, exact-close before writing, and fail outward without scalar coercion.'
    Assert-Match $runner '(?s)\$checkpointEvidenceComplete\s*=\s*\$validatedRunReceipts\.Count\s+-eq\s+\$Repeat.*?persistence_checkpoint_complete\s+-isnot\s+\[bool\].*?checkpoint_evidence_complete\s*=\s*\$checkpointEvidenceComplete' 'Invocation reporting must require exact-boolean complete checkpoint evidence for every validated run.'
    if (-not (Test-DirectDevelopmentQualificationSource -Source $runner)) {
        Add-Failure 'Direct replay output regained fixed-repeat authority; only the outer independent-profile aggregate may qualify release evidence.'
    }
    Assert-Match $runner '(?s)function Clear-VisibleCoach.*?Get-VisibleTutorialGuideAcknowledgment.*?Choose-VisibleChoice\s+-ChoiceId\s+''continue''.*?Wait-Frames.*?continue.*?dismissLabel.*?Select-UniqueFullyVisibleButton\s+-Buttons\s+@\(Get-Buttons\)\s+-Text\s+\$dismissLabel.*?Select-UniqueFullyVisibleButton\s+-Buttons\s+@\(Get-Buttons\)\s+-Text\s+''Skip tip''.*?fully visible public dismiss control' 'Coach recovery must follow the narrow public tutorial-guide acknowledgement, then require a unique boolean-true fully-visible dismiss control before input.'
    Assert-Match $runner '(?s)function Accept-GrandCasinoInviteIfVisible\s*\{.*?Invoke-EventObjectChoice\s+-EventId\s+''grand_casino_invite''\s+-ChoiceId\s+''accept_invite''\s+-Intent\s+''accept the visible invitation to the Grand Casino''.*?return \$true\s*\}' 'The clean replay must choose the exact visible invitation action instead of asking a selected multi-action object for a generic open action.'
    Assert-NotMatch $runner 'Open-EventObject\s+-EventId\s+''grand_casino_invite''' 'The Grand Casino invitation must not use the generic event-open path when the selected object already exposes explicit actions.'
    Assert-Match $runner '(?s)function Reach-GrandCasino.*?\$grand\s*=\s*@\(\$nodes.*?archetype_id.*?grand_casino.*?\$grand\.Count\s+-gt\s+1.*?\$requiredCash.*?GrandCasinoChipReserve.*?\$Ending\s+-ceq\s+''clean''.*?Recover-CleanGrandFareAtCurrentStop\s+-RequiredCash\s+\$requiredCash.*?Recover-GrandFareThroughPublicFunding\s+-RequiredCash\s+\$requiredCash.*?travel_enabled.*?Travel-ToNode' 'The replay must recompute the published Grand fare plus its documented chip reserve, use deterministic current-stop recovery for Clean, and only then take the visible route.'
    Assert-Match $runner '(?s)function Recover-CleanGrandFareAtCurrentStop.*?GrandFareRecoveryActive.*?Invoke-GrandFarePublicFundingOffer.*?Invoke-GrandFarePublicCashEvent.*?Get-PublicGrandFareRequirement.*?shortfall=.*?finally.*?GrandFareRecoveryActive\s*=\s*\$false' 'Clean recovery must remain current-stop-only, publicly measured, exact-shortfall reporting, and scope-safe.'
    Assert-NotMatch $runner '(?s)function Recover-CleanGrandFareAtCurrentStop\b(?:(?!\r?\nfunction ).)*(?:Travel-ToNode|Earn-GrandFareThroughVisibleSlot)' 'Clean qualifying recovery must not roam to another fare or depend on Slot luck.'
    Assert-Match $runner '(?s)function Wait-ForFullyRenderedFundingTalk.*?MaximumOpenPolls\s*=\s*6.*?\$talkOpened\s*=\s*\$false.*?\[bool\]\$talkVisible.*?\$talkOpened\s*=\s*\$true.*?elseif\s*\(-not\s+\$talkOpened.*?\$poll\s*\+\s*1\s*-ge\s*\$MaximumOpenPolls\).*?advertised lender action did not open TalkDock' 'An advertised lender that production rejects must fail fast instead of consuming the full rendered-terms timeout.'
    Assert-Match $runner '(?s)function Invoke-CleanScoutingCashOpportunity.*?\$Ending\s+-cne\s+''clean''.*?GrandFareRecoveryActive\s*=\s*\$true.*?Invoke-GrandFarePublicCashEvent.*?finally.*?GrandFareRecoveryActive\s*=\s*\$false.*?function Reach-GrandCasino.*?Invoke-CleanScoutingCashOpportunity.*?Accept-GrandCasinoInviteIfVisible' 'The Clean route must take a strictly verified positive cash event while already scouting, before paying a second recovery trip or depending on the probabilistic family phone.'
    Assert-Match $runner '(?s)function Invoke-GrandFarePublicFundingOffer.*?Select-GrandFareFundingObject.*?Test-GrandFareFundingPreflight.*?click_object.*?Select-GrandFareFundingObjectAction.*?Invoke-RoomActionRow.*?Select-GrandFareFundingTalkOffer.*?click_choice accept.*?Assert-GrandFareFundingConfirmation.*?click_choice accept.*?Assert-GrandFareFundingResult.*?GrandFareAcceptedOfferKeys\.Add.*?GrandFareAcceptedLenderIds\.Add' 'Grand fare lender recovery must validate one public object and debt preflight before focus, validate its unique action and rendered terms, verify confirmation and the exact bankroll/debt result, then record both one-use keys.'
    Assert-Match $runner '(?s)function Restore-EnvironmentSurfaceAfterTravelResult.*?screen.*?-ceq\s+''ENVIRONMENT''.*?-cne\s+''RESULT''.*?Open-WorldMap\s*Close-WorldMap.*?restoredScreen.*?-cne\s+''ENVIRONMENT''.*?function Invoke-GrandFarePublicFundingOffer.*?Restore-EnvironmentSurfaceAfterTravelResult.*?function Invoke-GrandFarePublicCashEvent.*?Restore-EnvironmentSurfaceAfterTravelResult' 'Grand fare recovery must clear a travel Result panel only through a real public map round trip before physical room actions.'
    Assert-Match $replayPolicy '(?ms)^function Select-GrandArrivalGreetingChoice.*?event popup.*?visible.*?Grand arrival TalkDock.*?expanded.*?render_valid.*?body_complete.*?typewriter_active.*?dialogue:normal_grand_host_greeting.*?Welcome to the Grand\. I''m Vivienne, your host\. The floor is yours\..*?choice_ids.*?Count\s+-ne\s+1.*?Enter the floor.*?enabled.*?return ''continue''.*?(?=^function |\z)' 'Grand arrival policy must authenticate the exact settled Vivienne greeting, its sole enabled continuation, and rendered copy.'
    $grandSurfaceNormalizerSource = [regex]::Match($runner, '(?ms)^function Restore-GrandCasinoEnvironmentSurface\s*\{.*?(?=^function |\z)').Value
    if ([string]::IsNullOrWhiteSpace($grandSurfaceNormalizerSource)) {
        Add-Failure 'Replay runner did not export Restore-GrandCasinoEnvironmentSurface.'
    }
    else {
        Assert-Match $grandSurfaceNormalizerSource '(?s)grand_casino.*?grand_casino_cage.*?grand_casino_high_limit.*?event_popup.*?talk.*?dialogue:normal_grand_host_greeting.*?Select-GrandArrivalGreetingChoice.*?Get-PublicTalkChoices.*?Choose-VisibleChoice.*?remained visible or chained into another modal.*?Restore-EnvironmentSurfaceAfterTravelResult.*?modal-free public room' 'Grand surface normalization must fail closed on unrelated modals, resolve only the exact rendered greeting, then restore a modal-free Environment surface through the public map round trip.'
        Assert-NotMatch $grandSurfaceNormalizerSource 'Resolve-VisibleBlockingPresentation|Get-FirstEnabledVisibleChoiceId' 'Grand surface normalization must never choose a generic visible modal response.'
    }
    $reachGrandSource = [regex]::Match($runner, '(?ms)^function Reach-GrandCasino\s*\{.*?(?=^function |\z)').Value
    Assert-Match $reachGrandSource '(?s)grand_casino.*?grand_casino_cage.*?grand_casino_high_limit.*?screen.*?GAME.*?Restore-GrandCasinoEnvironmentSurface.*?return' 'Every shared Grand arrival must preserve a restored live game or normalize the public Grand room surface before returning.'
    $enterGrandRoomSource = [regex]::Match($runner, '(?ms)^function Enter-GrandRoom\s*\{.*?(?=^function |\z)').Value
    if ([regex]::Matches($enterGrandRoomSource, 'Restore-GrandCasinoEnvironmentSurface', [Text.RegularExpressions.RegexOptions]::CultureInvariant).Count -lt 2) {
        Add-Failure 'Grand room navigation must normalize both an already-current target and every completed real door transition.'
    }
    Assert-Match $enterGrandRoomSource '(?s)\$archetype\s+-ceq\s+\$expected.*?screen.*?GAME.*?Restore-GrandCasinoEnvironmentSurface.*?Open-SemanticObject.*?Wait-ForTravelToSettle.*?archetype_id.*?-cne\s+\$expected.*?Restore-GrandCasinoEnvironmentSurface' 'Grand room navigation must preserve restored games, normalize an already-current room, and normalize every successful Main/Cage door transition.'
    Assert-Match $runner '(?ms)^function Invoke-CleanEndingRoute\s*\{\s*Reach-GrandCasino.*?(?=^function |\z)' 'The Clean route must enter the shared normalized Grand arrival boundary.'
    Assert-Match $runner '(?ms)^function Invoke-CheatEndingRoute\s*\{\s*Reach-GrandCasino.*?(?=^function |\z)' 'The Cheat route must enter the shared normalized Grand arrival boundary.'
    Assert-Match $runner '(?ms)^function Invoke-HeistEndingRoute\s*\{.*?Reach-GrandCasino.*?(?=^function |\z)' 'The Heist route must enter the shared normalized Grand arrival boundary.'
    Assert-Match $runner '(?s)function Invoke-GrandFarePublicCashEvent.*?Select-GrandFareCashEventChoice.*?Invoke-RoomActionRow.*?Assert-GrandFareCashEventResult.*?GrandFareResolvedCashEventKeys\.Add' 'Grand fare cash-event recovery must use the exact public allowlist, one direct-resolve rendered room action, a positive public HUD delta, and one-use bookkeeping.'
    Assert-Match $runner '(?s)function Invoke-GrandFarePublicCashEvent.*?\$eventObjects\s*=\s*@\(.*?\$eventObjects\.Count.*?Get-Value\s+\$eventObjects\[0\].*?-cnotmatch.*?Select-GrandFareCashEventChoice.*?-EventObject\s+\$eventObjects\[0\]' 'Grand fare cash-event recovery must preserve its selected public event across regex validation instead of colliding with PowerShell automatic $Matches state.'
    Assert-Match $runner '(?s)function Get-GrandFareRecoveryNodePreference.*?motel''\) \{ return 0 \}.*?back_alley''\) \{ return 1 \}.*?small_underground_casino''\) \{ return 2 \}.*?delta_queen''\) \{ return 4 \}' 'Grand fare recovery must prefer distinct public lender pools before revisiting another Crew-only casino.'
    Assert-Match $runner '(?s)function Recover-GrandFareThroughPublicFunding.*?MaximumFundingStops\s*=\s*6.*?GrandFareRecoveryActive.*?RequiredCash.*?GrandFareRecoveryVisitedNodes\.Add.*?Invoke-GrandFarePublicFundingOffer.*?Invoke-GrandFarePublicCashEvent.*?Get-MapNodes.*?Earn-GrandFareThroughVisibleSlot.*?finally.*?GrandFareRecoveryActive\s*=\s*\$false' 'The funding helper must be recovery-scoped, bounded, lender-first, public-map driven, and leave slot play as its final fallback.'
    Assert-Match $runner '(?s)function Earn-GrandFareThroughVisibleSlot.*?MaximumSpins\s*=\s*6.*?MaximumLosses\s*=\s*3.*?Enter-VisibleSlotForGrandFare.*?startingCash.*?losses.*?Wait-ForVisibleSlotActionBoundary.*?status_hud.*?bankroll.*?slot_spin.*?loss-stopped.*?Leave-GameSurface' 'Grand fare slot fallback must be capped at six spins, stop after three losses, and use only visible actions and public bankroll evidence.'
    Assert-Match $runner '(?s)function Resolve-GrandFareMachineJamIfVisible.*?Select-GrandFareMachineJamChoice.*?Choose-VisibleChoice.*?visible de-escalation choice.*?Wait-Frames.*?modal remained visible or chained into another modal' 'Grand fare recovery must route the exact rendered machine_jam policy through the confirmation-aware visible-choice path and fail closed if any modal remains.'
    Assert-Match $runner '(?s)function Wait-ForVisibleSlotActionBoundary.*?Resolve-GrandFareMachineJamIfVisible.*?continue.*?slot_handpay_acknowledge' 'Only the Grand fare slot boundary may resolve the allowlisted public machine_jam before normal slot actions resume.'
    Assert-Match $replayPolicy '(?s)function Select-GrandFareMachineJamChoice.*?TalkDock state.*?rendered event-popup witness.*?machine_jam.*?Machine Jam.*?exactly ordered wait, push.*?Wait it out.*?Push through.*?return ''wait''' 'The shared replay policy must strictly validate the rendered machine_jam identity, copy, choice order, controls, and visible de-escalation response.'
    Assert-Match $replayPolicy '(?s)function Select-GrandFareFundingObject.*?lender:.*?rendered.*?AcceptedOfferKeys.*?AcceptedLenderIds.*?Sort-Object.*?-CaseSensitive.*?function Select-GrandFareFundingObjectAction.*?exact public Use action.*?function Select-GrandFareFundingTalkOffer' 'The shared funding policy must validate exact rendered lender identity, skip used or disabled offers, deterministically select among multiple lenders, and require the unique Use action.'
    Assert-Match $replayPolicy '(?s)function Select-GrandFareFundingTalkOffer.*?lender_conversation:borrow:.*?Borrow.*?Repay.*?Accept Offer.*?function Assert-GrandFareFundingConfirmation' 'The shared funding policy must validate the exact lender talk identity, rendered principal and obligation terms, and accept control.'
    Assert-Match $replayPolicy '(?s)function Select-GrandFareFundingTalkOffer.*?RegexOptions\]::CultureInvariant\s+-bor\s+\[Text\.RegularExpressions\.RegexOptions\]::Singleline.*?\[regex\]::Match' 'Rendered lender narration may precede the exact disclosed terms on another line without weakening the anchored obligation parser.'
    Assert-Match $replayPolicy '(?s)function Assert-GrandFareFundingConfirmation.*?Confirm: Accept Offer.*?function Assert-GrandFareFundingResult' 'The shared funding policy must require the visibly armed lender confirmation.'
    Assert-Match $replayPolicy '(?s)function Assert-GrandFareFundingResult.*?bankroll_rendered.*?expectedBankrollLong.*?Get-GrandFarePublicDebtCount.*?afterDebtCount\s+-ne\s+\$beforeDebtCount\s+\+\s+1.*?exact disclosed terms.*?exact positive bankroll delta' 'The shared funding policy must verify exact rendered bankroll, one additional rendered debt indicator, and Result feedback bound to the disclosed terms and delta.'
    Assert-Match $replayPolicy '(?s)function Get-Rw062ExactPublicPropertyMatches.*?Name\s+-ceq.*?function Get-Rw062RequiredPublicProperty.*?properties\.Count\s+-ne\s+1' 'Critical replay-policy schema keys must be matched by exact property-name casing.'
    Assert-Match $replayPolicy '(?s)function Select-GrandFareFundingObject.*?-cnotmatch.*?StartsWith\(''lender:'', \[StringComparison\]::Ordinal\).*?-cnotin.*?function Select-GrandFareFundingObjectAction.*?-cne ''Use''.*?IsNullOrEmpty' 'Grand fare lender schema matching must remain case-sensitive for world ids, lender prefixes/suffixes, object types, the Use label, and blank compatibility identities.'
    Assert-Match $replayPolicy '(?s)function Select-GrandFareCashEventChoice.*?back_alley_offer.*?Back Alley Offer.*?Small cash.*?scenario_wedding_overflow_hallway.*?Hallway Table.*?pays out.*?function Assert-GrandFareCashEventResult.*?strictly positive public HUD bankroll delta' 'The shared cash-event policy must strictly allowlist exact rendered event objects/actions and require only the positive public HUD result promised by their visible copy.'
    Assert-Match $replayPolicy '(?s)function Assert-GrandFareCashEventResult.*?Cash change: \+\{1\}\..*?\$\+\{1\} / Heat \+\{2\}.*?feedbackText -cne \$expectedFeedback' 'Cash-event result verification must bind Foundation''s exact cash settlement sentence and compact rendered cash/heat deltas.'
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
    Assert-Match $bridge '(?s)func _public_rendered_status_hud\(_source: Dictionary\).*?wallet_label\.text.*?bankroll_rendered.*?chips_chip.*?chips_label\.text.*?chips_rendered.*?heat_label\.text.*?heat_rendered.*?drunk_label\.text.*?drunk_rendered.*?_public_status_indicator\("save"\)' 'Bankroll, chips, heat, Drunk, and save evidence must be derived from their actual fully rendered HUD controls.'
    Assert-NotMatch $bridge '(?ms)^func _public_rendered_status_hud\(.*?(?=^func |\z).*?_source\.get' 'Rendered HUD construction must not copy raw host HUD values.'
    Assert-Match $bridge '(?s)func _public_rendered_talk\(source: Dictionary\).*?_control_is_rendered\(panel\).*?"visible": true.*?"render_valid": false.*?_control_is_fully_rendered\(panel\).*?_label_text_is_fully_rendered\(body_label\).*?result\["render_valid"\] = true' 'A present but clipped TalkDock must stay visibly invalid until its complete rendered surface is authenticated.'
    Assert-Match $bridge '(?s)func _public_rendered_event_popup\(_source: Dictionary\).*?_control_is_rendered\(panel\).*?"visible": true, "render_valid": false.*?_control_is_fully_rendered\(panel\).*?result\["render_valid"\] = true' 'A present but clipped event popup must stay visibly invalid until every rendered card is authenticated.'
    Assert-Match $bridge '(?s)func _canvas_objects\(canvas: Control\).*?_control_is_fully_rendered\(canvas\).*?global_rect_for_object.*?_rect_encloses_with_tolerance.*?"rendered": rendered' 'Clickable room objects must carry an exact fully rendered geometry witness.'
    Assert-Match $bridge '(?s)func _room_selected_actions\(canvas: Control\).*?_control_is_fully_rendered\(canvas\).*?selected_object_id.*?button_rect.*?_room_action_label_is_fully_rendered.*?"rendered": rendered.*?"rect": global_rect if rendered else Rect2\(\)' 'Selected room actions must publish their exact selected-object identity, live row, fully rendered label/geometry witness, and hit rectangle.'
    Assert-Match $bridge '(?s)func _click_action\(argument: String\).*?parts\[0\].*?room.*?_click_room_action.*?func _click_room_action\(parts: PackedStringArray\).*?identity_matches\.size\(\) != 1.*?live_index_value.*?TYPE_BOOL.*?TYPE_RECT2.*?distance_to.*?_push_mouse_click\(live_rect\.get_center\(\), false\)' 'Room actions must revalidate one exact live object/identity/index, boolean enabled/rendered signals, unchanged hit geometry, and then use a physical click.'
    Assert-Match $bridge '(?s)var\s+live_center:\s*Vector2\s*=\s*room\.get_global_transform_with_canvas\(\)\s*\*\s*local.*?var\s+global_start:\s*Vector2\s*=\s*canvas\.get_global_transform_with_canvas\(\)\s*\*.*?var\s+global_end:\s*Vector2\s*=\s*canvas\.get_global_transform_with_canvas\(\)\s*\*' 'Public room-action geometry must keep explicit Vector2 types and use the Control canvas transform that matches the physical input viewport.'
    Assert-NotMatch $sanitizer '"(?:demo_objective|objective_guidance|next_objective|run_status|run_text|debt_items)"' 'Public sanitization must omit raw objective, run-state, and debt-model fields.'
    Assert-Match $sanitizer '(?s)static func _status_hud\(source: Dictionary\).*?drunk_rendered.*?drunk_text' 'Public HUD sanitization must retain only the rendered Drunk projection used by the replay boundary.'

    Assert-Match $runner '(?s)function Get-Value\s*\{.*?IDictionary.*?Keys.*?-ceq\s+\$segment.*?PSObject\.Properties.*?Name\s+-ceq\s+\$segment.*?Ambiguous exact property' 'Runner property traversal must use exact dictionary/property names and reject ambiguity.'
    Assert-Match $runner '(?s)function Invoke-BishopGrandDrinkSobrietyDetour.*?event:comped_suite_offer.*?Comped Suite Offer.*?Decline.*?ChoiceId ''decline''.*?afterCompCash\s+-cne\s+\$beforeCompCash.*?afterCompHeat\s+-cne\s+\(\$beforeCompHeat\s+-\s+3\).*?drunkText\s+-cne\s+''100''.*?feedbackTitle\s+-cne\s+''Result''.*?feedbackText\s+-cne\s+''You keep your distance from the kindness\.  Heat -2''.*?screen.*?RESULT.*?Restore-EnvironmentSurfaceAfterTravelResult.*?restoredCompCash\s+-cne\s+\$afterCompCash.*?restoredCompHeat\s+-cne\s+\$afterCompHeat.*?restoredDrunkText\s+-cne\s+''100''.*?ENVIRONMENT.*?final sobriety loop' 'The final Bishop sobriety loop must authenticate the exact rendered Comped Suite result, bind its declared consequence plus ordinary-boundary decay, restore the public Grand environment, and retain one bounded public loop.'
    Assert-NotMatch $runner '(?s)function Invoke-BishopGrandDrinkSobrietyDetour.*?Wait-Frames\s+`?\s*-Frames\s+720' 'The Bishop sobriety route must not treat wall-time frames as simulation-time drink absorption.'
    $getValueFunction = [regex]::Match($runner, '(?ms)^function Get-Value\s*\{.*?(?=^function |\z)')
    if (-not $getValueFunction.Success -or $getValueFunction.Value.Contains('OrdinalIgnoreCase')) {
        Add-Failure 'Runner Get-Value must not perform case-insensitive property lookup.'
    }
    Assert-NotMatch $runner 'Get-Value[^\r\n]+(?:demo_objective|objective_guidance|next_objective|run_status|run_text)' 'Replay routes must not consume raw objective or run-status fields.'
    Assert-Match $runner '(?s)function Select-ExactRenderedCanvasObject.*?matches\.Count\s+-gt\s+1.*?rendered\s+-isnot\s+\[bool\].*?enabled\s+-isnot\s+\[bool\].*?function Select-FirstRenderedCanvasObjectByPrefix.*?duplicate semantic id.*?Sort-Object.*?-CaseSensitive' 'Canvas-object route decisions must require unique exact identities, true boolean rendered/enabled witnesses, and deterministic ordinal prefix selection.'
    Assert-Match $runner '(?s)function Reveal-WorldMapLeaveByPublicRefocus.*?leaveMatches\.Count\s+-cne\s+1.*?leaveEnabled\s+-isnot\s+\[bool\].*?leaveRendered\s+-isnot\s+\[bool\].*?Select-Object\s+-First\s+12.*?click_object \$semanticId.*?blocking modal.*?liveLeave\.Count\s+-cne\s+1.*?liveEnabled\s+-isnot\s+\[bool\].*?liveRendered\s+-isnot\s+\[bool\].*?function Open-WorldMap.*?Clear-VisibleCoach\s*Reveal-WorldMapLeaveByPublicRefocus\s*\$null = Open-SemanticObject' 'World-map entry must use only bounded real focus clicks and exact public witnesses to uncover an occluded Leave target before its physical action.'
    Assert-Match $runner '(?s)function Assert-ExactRenderedRoomActionBinding.*?matches\.Count\s+-cne\s+1.*?changed row order.*?disabled, clipped.*?function Invoke-RoomActionRow.*?selected_object_id.*?ConvertTo-BridgeBase64Token.*?click_action room' 'Room-action commands must bind one exact selected object, identity, row index, rendered/enabled state, and encoded bridge command.'
    Assert-Match $runner '(?s)function Assert-ExplicitSaveAcknowledgmentObservation.*?hasSave\s+-isnot\s+\[bool\].*?saveTextVisible\s+-isnot\s+\[bool\].*?saveText\s+-isnot\s+\[string\].*?-cne\s+\$expectedVisibleText' 'Save acknowledgment must reject missing, non-boolean, and inexact public witnesses.'
    Assert-Match $runner '(?s)function Test-PublicTerminalSurface.*?Get-ExactReplayString.*?screen.*?screen\s+-cnotin\s+@\(''VICTORY'', ''FAILURE''\).*?Get-ExactReplayBoolean.*?run_report_visible.*?function Assert-TerminalOutcome.*?Get-ExactReplayString.*?run_report.*?outcome.*?Get-ExactReplayBoolean.*?won.*?outcome\s+-cnotin\s+\$ExpectedOutcomes' 'Terminal routing must require exact terminal screen/outcome strings, exact boolean witnesses, and exact allowlisted outcome ids.'
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
    Assert-Match $bridge '(?s)var look := await _capture_look\(command_number, not should_quit\).*?func _capture_look\(command_number: int, capture_png: bool = true\).*?if capture_png:.*?RenderingServer\.frame_post_draw.*?save_png' 'Quit must retain its authenticated public observation while skipping only the redundant framebuffer PNG capture.'
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
    Assert-Match $replayPolicy '(?s)function Get-Rw062RequiredPublicPropertyDescriptor.*?PSCustomObject.*?Properties.*?Count\s+-ne\s+1.*?return\s+\$properties\[0\]' 'Rourke checkpoint policy must read exact property descriptors without scalar enumeration.'
    Assert-Match $replayPolicy '(?s)function Select-CheatReplayDuelCheckpointAction.*?game_id.*?phase.*?boss_duel_active.*?boss_hand_number.*?can_deal.*?blackjack.*?betting.*?SurfaceActions\s+-isnot\s+\[object\[\]\].*?blackjack_deal.*?\$index\s+-ne\s+0.*?\$dealRows\.Count\s+-ne\s+1' 'Rourke checkpoint policy must require exact active/dealable pre-hand-one state and one enabled index-zero Deal action.'
    Assert-Match $runner '(?s)function Assert-SaveRelaunchContinue.*?Assert-CheatRourkeDuelBeforeHandOne\s+-Context\s+''before Save''.*?\$before\s*=\s*\[ordered\].*?Click-Button\s+-Text\s+''CONTINUE''.*?Clear-VisibleCoach.*?Assert-CheatRourkeDuelBeforeHandOne\s+-Context\s+''after relaunch and Continue''.*?\$after\s*=\s*\[ordered\]' 'Cheat replay must prove the exact duel Deal surface both before Save and immediately after Continue.'
    Assert-NotMatch $runner '\$preferred\s*=\s*@\(''blackjack_distraction'',\s*''blackjack_peek''\)' 'Cheat replay must not return after the old control-id preference loop before performing Peek.'
    Assert-Match $replayPolicy '(?s)function Select-CheatReplayBlackjackCheatAction.*?''peek_hole_card''.*?''blackjack_distraction''.*?''blackjack_peek''' 'Cheat replay policy must distinguish the published semantic cheat id from the two rendered control ids.'
    Assert-Match $replayPolicy '(?s)function Select-CheatReplayPostPeekTransition.*?phase.*?''barred''.*?heat_rendered.*?heat_level.*?-lt\s+70.*?surface_back.*?Count\s+-ne\s+1.*?enabled.*?index.*?-ne\s+-1.*?leave_for_showdown' 'Post-Peek policy must require exact public barred phase, rendered showdown Heat, and one enabled surface_back binding.'
    Assert-Match $runner '(?s)\$peekApplied\s*=\s*Invoke-VisibleCheatIfAvailable.*?Select-CheatReplayPostPeekTransition.*?leave_for_showdown.*?return.*?blackjack_settle' 'A successfully applied Peek must inspect and escape a public barred showdown state before settlement.'
    Assert-Match $runner '(?s)function Invoke-PublicBossCalloutIfShown.*?Select-CheatReplayBossCalloutAction.*?stage\s+-cne\s+''call''.*?blackjack_boss_callout.*?Wait-Frames.*?if\s*\(Test-PublicTerminalSurface\)\s*\{\s*return\s*\}.*?boss_callout_used' 'Rourke replay must accept an immediate exact terminal surface after the physical callout, otherwise require the post-deal rendered used witness.'
    Assert-Match $runner '(?s)function Resolve-ShowdownChoiceSurface.*?Select-CheatReplayShowdownInterrogationChoice.*?take the exact visible edge against Rourke' 'Rourke interrogation must select take_the_edge through its exact public policy.'
    Assert-Match $replayPolicy '(?s)function Select-CheatReplayShowdownInterrogationChoice.*?hold_steady.*?talk_down.*?take_the_edge.*?return\s+''take_the_edge''' 'Cheat interrogation policy must validate the exact rendered choice set and return take_the_edge.'
    $showdownChoiceFunction = [regex]::Match($runner, '(?ms)^function Resolve-ShowdownChoiceSurface\s*\{.*?(?=^function |\z)')
    if (-not $showdownChoiceFunction.Success -or
        [regex]::IsMatch($showdownChoiceFunction.Value, '(?:Choose-VisibleChoice\s+-ChoiceId\s+[''\"]hold_steady|hold_steady\s*=\s*)')) {
        Add-Failure 'Cheat showdown routing must not directly select or intent-map hold_steady.'
    }
    Assert-Match $runner '(?s)function Resolve-ShowdownChoiceSurface.*?Select-CheatReplayShowdownWalkChoice.*?keep_everything.*?hand_to_crew__.*?trash' 'Showdown walk must use the public classified-item policy instead of blindly keeping every inventory.'
    Assert-Match $replayPolicy '(?s)function Select-CheatReplayShowdownWalkChoice.*?marked_cards.*?foil_sleeve.*?weighted_keyring.*?xray_glasses.*?tab_detector.*?tarot_card.*?multiple classified items' 'Showdown walk policy must fail closed when its one pocket change cannot remove every classified item.'
    Assert-Contains $runner "Invoke-GameAction -Action 'blackjack_boss_callout' -Index `$index" 'Rourke callouts must click the matching rendered indexed control.'
    Assert-Contains $replayPolicy '$handNumber -isnot [int32] -or $handNumber -ne 1 -or' 'Rourke persistence must recognize the publicly numbered first hand.'
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
        Assert-ExactSemanticScrollReport -Report $scrollReport -ExpectedReportPath $SemanticScrollReportPath
        $semanticReportSchemaValidFixtures = 1
        $semanticReportHostiles = [Collections.Generic.List[object]]::new()
        $semanticReportHostiles.Add([pscustomobject]@{ name = 'root null'; value = $null })
        $semanticReportHostiles.Add([pscustomobject]@{ name = 'root scalar'; value = 'semantic-report' })
        $semanticReportHostiles.Add([pscustomobject]@{ name = 'root one-element array'; value = [object[]]@($scrollReport) })
        $semanticKeys = @($scrollReport.PSObject.Properties | ForEach-Object { $_.Name })
        foreach ($name in $semanticKeys) {
            $clone = ConvertTo-ContractClone -InputObject $scrollReport
            $clone.PSObject.Properties.Remove($name)
            $semanticReportHostiles.Add([pscustomobject]@{ name = "missing $name"; value = $clone })
        }
        $clone = ConvertTo-ContractClone -InputObject $scrollReport
        $clone | Add-Member -NotePropertyName authority_override -NotePropertyValue 'hostile'
        $semanticReportHostiles.Add([pscustomobject]@{ name = 'extra authority key'; value = $clone })
        $reordered = [ordered]@{}
        $reordered[$semanticKeys[1]] = $scrollReport.PSObject.Properties[$semanticKeys[1]].Value
        $reordered[$semanticKeys[0]] = $scrollReport.PSObject.Properties[$semanticKeys[0]].Value
        for ($index = 2; $index -lt $semanticKeys.Count; $index++) {
            $reordered[$semanticKeys[$index]] = $scrollReport.PSObject.Properties[$semanticKeys[$index]].Value
        }
        $semanticReportHostiles.Add([pscustomobject]@{ name = 'property order drift'; value = [pscustomobject]$reordered })

        $semanticIntFields = @(
            'schema_version', 'valid_button_fixtures', 'hostile_button_fixtures',
            'valid_dialog_fixtures', 'hostile_dialog_fixtures', 'valid_fixtures',
            'hostile_fixtures', 'valid_confirmation_fixtures',
            'hostile_confirmation_fixtures', 'valid_canvas_object_fixtures',
            'hostile_canvas_object_fixtures', 'valid_room_action_fixtures',
            'hostile_room_action_fixtures', 'valid_save_acknowledgment_fixtures',
            'hostile_save_acknowledgment_fixtures', 'valid_terminal_fixtures',
            'hostile_terminal_fixtures'
        )
        foreach ($name in $semanticIntFields) {
            foreach ($kind in @('null', 'object', 'array', 'boolean', 'string')) {
                $clone = ConvertTo-ContractClone -InputObject $scrollReport
                switch ($kind) {
                    'null' { $clone.$name = $null }
                    'object' { $clone.$name = [pscustomobject]@{ value = 1 } }
                    'array' { $clone.$name = [object[]]@(1) }
                    'boolean' { $clone.$name = $true }
                    'string' { $clone.$name = [string]$scrollReport.$name }
                }
                $semanticReportHostiles.Add([pscustomobject]@{ name = "$name $kind"; value = $clone })
            }
        }
        foreach ($name in @('check_id', 'report')) {
            foreach ($kind in @('null', 'object', 'array', 'boolean', 'integer')) {
                $clone = ConvertTo-ContractClone -InputObject $scrollReport
                switch ($kind) {
                    'null' { $clone.$name = $null }
                    'object' { $clone.$name = [pscustomobject]@{ value = 'x' } }
                    'array' { $clone.$name = [object[]]@([string]$scrollReport.$name) }
                    'boolean' { $clone.$name = $true }
                    'integer' { $clone.$name = [int32]1 }
                }
                $semanticReportHostiles.Add([pscustomobject]@{ name = "$name $kind"; value = $clone })
            }
        }
        foreach ($kind in @('null', 'object', 'array', 'integer', 'string')) {
            $clone = ConvertTo-ContractClone -InputObject $scrollReport
            switch ($kind) {
                'null' { $clone.passed = $null }
                'object' { $clone.passed = [pscustomobject]@{ value = $true } }
                'array' { $clone.passed = [object[]]@($true) }
                'integer' { $clone.passed = [int32]1 }
                'string' { $clone.passed = 'true' }
            }
            $semanticReportHostiles.Add([pscustomobject]@{ name = "passed $kind"; value = $clone })
        }
        foreach ($kind in @('null', 'scalar', 'object', 'nested array', 'wrong element')) {
            $clone = ConvertTo-ContractClone -InputObject $scrollReport
            switch ($kind) {
                'null' { $clone.failures = $null }
                'scalar' { $clone.failures = 'failure' }
                'object' { $clone.failures = [pscustomobject]@{} }
                'nested array' { $clone.failures = [object[]]@(,[object[]]@('failure')) }
                'wrong element' { $clone.failures = [object[]]@('failure') }
            }
            $semanticReportHostiles.Add([pscustomobject]@{ name = "failures $kind"; value = $clone })
        }
        $semanticReportSchemaHostileFixtures = $semanticReportHostiles.Count
        foreach ($case in $semanticReportHostiles) {
            $threw = $false
            try {
                Assert-ExactSemanticScrollReport -Report $case.value -ExpectedReportPath $SemanticScrollReportPath
            }
            catch {
                $threw = $true
            }
            if (-not $threw) {
                Add-Failure "Semantic-report schema accepted hostile '$($case.name)'."
            }
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
    grand_arrival_greeting_valid_fixtures = $grandArrivalGreetingValidFixtures
    grand_arrival_greeting_hostile_fixtures = $grandArrivalGreetingHostileFixtures
    machine_jam_valid_fixtures = $machineJamValidFixtures
    machine_jam_hostile_fixtures = $machineJamHostileFixtures
    delta_queen_beach_valid_fixtures = $deltaQueenBeachValidFixtures
    delta_queen_beach_hostile_fixtures = $deltaQueenBeachHostileFixtures
    grand_fare_funding_valid_fixtures = $grandFareFundingValidFixtures
    grand_fare_funding_hostile_fixtures = $grandFareFundingHostileFixtures
    grand_fare_cash_event_valid_fixtures = $grandFareCashEventValidFixtures
    grand_fare_cash_event_hostile_fixtures = $grandFareCashEventHostileFixtures
    command_open_valid_fixtures = $commandOpenValidFixtures
    command_open_hostile_fixtures = $commandOpenHostileFixtures
    cheat_duel_checkpoint_valid_fixtures = $cheatDuelCheckpointValidFixtures
    cheat_duel_checkpoint_hostile_fixtures = $cheatDuelCheckpointHostileFixtures
    cheat_blackjack_valid_fixtures = $cheatBlackjackValidFixtures
    cheat_blackjack_hostile_fixtures = $cheatBlackjackHostileFixtures
    cheat_post_peek_valid_fixtures = $cheatPostPeekValidFixtures
    cheat_post_peek_hostile_fixtures = $cheatPostPeekHostileFixtures
    cheat_interrogation_valid_fixtures = $cheatInterrogationValidFixtures
    cheat_interrogation_hostile_fixtures = $cheatInterrogationHostileFixtures
    cheat_boss_callout_valid_fixtures = $cheatBossCalloutValidFixtures
    cheat_boss_callout_hostile_fixtures = $cheatBossCalloutHostileFixtures
    cheat_showdown_walk_valid_fixtures = $cheatShowdownWalkValidFixtures
    cheat_showdown_walk_hostile_fixtures = $cheatShowdownWalkHostileFixtures
    cheat_duel_continuation_valid_fixtures = $cheatDuelContinuationValidFixtures
    cheat_duel_continuation_hostile_fixtures = $cheatDuelContinuationHostileFixtures
    heist_seed_valid_fixtures = $heistSeedValidFixtures
    heist_seed_hostile_fixtures = $heistSeedHostileFixtures
    heist_seed_report_schema_hostile_fixtures = $heistSeedReportSchemaHostileFixtures
    heist_launch_setup_valid_fixtures = $heistLaunchSetupValidFixtures
    heist_launch_setup_hostile_fixtures = $heistLaunchSetupHostileFixtures
    heist_audit_hook_valid_fixtures = $heistAuditHookValidFixtures
    heist_audit_hook_hostile_fixtures = $heistAuditHookHostileFixtures
    heist_convention_hook_valid_fixtures = $heistConventionHookValidFixtures
    heist_convention_hook_hostile_fixtures = $heistConventionHookHostileFixtures
    persistence_checkpoint_valid_fixtures = $persistenceCheckpointValidFixtures
    persistence_checkpoint_hostile_fixtures = $persistenceCheckpointHostileFixtures
    direct_qualification_valid_fixtures = $directQualificationValidFixtures
    direct_qualification_hostile_fixtures = $directQualificationHostileFixtures
    evidence_admission_valid_fixtures = $evidenceAdmissionValidFixtures
    evidence_admission_hostile_fixtures = $evidenceAdmissionHostileFixtures
    evidence_admission_report_schema_hostile_fixtures = $evidenceAdmissionReportSchemaHostileFixtures
    bridge_exact_type_valid_fixtures = $bridgeExactTypeValidFixtures
    bridge_exact_type_hostile_fixtures = $bridgeExactTypeHostileFixtures
    semantic_report_schema_valid_fixtures = $semanticReportSchemaValidFixtures
    semantic_report_schema_hostile_fixtures = $semanticReportSchemaHostileFixtures
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
