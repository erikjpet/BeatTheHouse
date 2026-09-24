Set-StrictMode -Version Latest

function Get-Rw062ExactPublicPropertyMatches {
    param(
        [AllowNull()]$InputObject,
        [Parameter(Mandatory = $true)][string]$Name
    )
    if ($null -eq $InputObject) { return @() }
    return @($InputObject.PSObject.Properties | Where-Object { [string]$_.Name -ceq $Name })
}


function Get-Rw062RequiredPublicProperty {
    param(
        [AllowNull()]$InputObject,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Context
    )
    if ($null -eq $InputObject) {
        throw "$Context is missing."
    }
    $properties = @(Get-Rw062ExactPublicPropertyMatches -InputObject $InputObject -Name $Name)
    if ($properties.Count -ne 1 -or $null -eq $properties[0].Value) {
        throw "$Context is missing required public property '$Name'."
    }
    return $properties[0].Value
}


function Get-Rw062PublicSurfaceActionMatches {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$SurfaceActions,
        [Parameter(Mandatory = $true)][string]$Action
    )

    return @($SurfaceActions | Where-Object {
        $properties = @(Get-Rw062ExactPublicPropertyMatches -InputObject $_ -Name 'action')
        $properties.Count -eq 1 -and $properties[0].Value -is [string] -and
            [string]$properties[0].Value -ceq $Action
    })
}


function Select-CheatReplayBlackjackCheatAction {
    param(
        [Parameter(Mandatory = $true)]$Game,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$SurfaceActions
    )

    $peekAvailable = Get-Rw062RequiredPublicProperty -InputObject $Game -Name 'peek_available' -Context 'Blackjack public game state'
    $peekWindowOpen = Get-Rw062RequiredPublicProperty -InputObject $Game -Name 'peek_window_open' -Context 'Blackjack public game state'
    $dealerHoleVisible = Get-Rw062RequiredPublicProperty -InputObject $Game -Name 'dealer_hole_visible' -Context 'Blackjack public game state'
    $canDeal = Get-Rw062RequiredPublicProperty -InputObject $Game -Name 'can_deal' -Context 'Blackjack public game state'
    foreach ($signal in @(
        [pscustomobject]@{ name = 'peek_available'; value = $peekAvailable },
        [pscustomobject]@{ name = 'peek_window_open'; value = $peekWindowOpen },
        [pscustomobject]@{ name = 'dealer_hole_visible'; value = $dealerHoleVisible },
        [pscustomobject]@{ name = 'can_deal'; value = $canDeal }
    )) {
        if ($signal.value -isnot [bool]) {
            throw "Blackjack public game state has a missing or non-boolean '$($signal.name)' witness."
        }
    }
    if ([bool]$peekAvailable -and [bool]$canDeal) {
        throw 'Blackjack cannot publicly offer Peek while Deal is still available.'
    }
    if ([bool]$dealerHoleVisible -and [bool]$peekAvailable) {
        throw 'Blackjack publicly exposes an impossible visible-hole-card Peek state.'
    }
    if ([bool]$peekWindowOpen -and -not [bool]$peekAvailable -and -not [bool]$dealerHoleVisible) {
        throw 'Blackjack exposes a Peek window without an active Peek or visible hole card.'
    }

    $cheatActions = @(Get-Rw062RequiredPublicProperty -InputObject $Game -Name 'cheat_actions' -Context 'Blackjack public game state')
    $publishedPeek = @($cheatActions | Where-Object {
        $idProperties = @(Get-Rw062ExactPublicPropertyMatches -InputObject $_ -Name 'id')
        $idProperties.Count -eq 1 -and $idProperties[0].Value -is [string] -and
            [string]$idProperties[0].Value -ceq 'peek_hole_card'
    })
    if ($publishedPeek.Count -ne 1) {
        throw "Blackjack must publish exactly one semantic 'peek_hole_card' cheat; found $($publishedPeek.Count)."
    }
    $publishedKind = Get-Rw062RequiredPublicProperty -InputObject $publishedPeek[0] -Name 'kind' -Context "Published 'peek_hole_card' cheat"
    $publishedLabel = Get-Rw062RequiredPublicProperty -InputObject $publishedPeek[0] -Name 'label' -Context "Published 'peek_hole_card' cheat"
    if ($publishedKind -isnot [string] -or [string]$publishedKind -cne 'cheat' -or
        $publishedLabel -isnot [string] -or [string]::IsNullOrWhiteSpace([string]$publishedLabel)) {
        throw "Published 'peek_hole_card' cheat has changed kind or lost its rendered label."
    }

    if ([bool]$dealerHoleVisible) {
        return [pscustomobject][ordered]@{ stage = 'complete'; action = ''; index = -1 }
    }
    if (-not [bool]$peekAvailable) {
        return [pscustomobject][ordered]@{ stage = 'wait_for_deal'; action = ''; index = -1 }
    }

    if (-not [bool]$peekWindowOpen) {
        $distractions = @(Get-Rw062PublicSurfaceActionMatches -SurfaceActions $SurfaceActions -Action 'blackjack_distraction')
        if ($distractions.Count -eq 0) {
            throw "Published 'peek_hole_card' is available, but no rendered Distraction control can open its public window."
        }
        $validated = @()
        foreach ($row in $distractions) {
            $enabled = Get-Rw062RequiredPublicProperty -InputObject $row -Name 'enabled' -Context 'Blackjack Distraction control'
            $index = Get-Rw062RequiredPublicProperty -InputObject $row -Name 'index' -Context 'Blackjack Distraction control'
            if ($enabled -isnot [bool] -or -not [bool]$enabled -or
                ($index -isnot [int32] -and $index -isnot [int64]) -or [long]$index -lt 0 -or [long]$index -gt [int]::MaxValue) {
                throw 'Blackjack Distraction control is disabled or has no exact non-negative integral index.'
            }
            $validated += [pscustomobject]@{ row = $row; index = [int]$index }
        }
        $duplicateIndices = @($validated | Group-Object -Property index | Where-Object { $_.Count -gt 1 })
        if ($duplicateIndices.Count -gt 0) {
            throw 'Blackjack exposes duplicate rendered Distraction indices.'
        }
        $selected = @($validated | Sort-Object -Property index)[0]
        return [pscustomobject][ordered]@{ stage = 'open_window'; action = 'blackjack_distraction'; index = [int]$selected.index }
    }

    $peekControls = @(Get-Rw062PublicSurfaceActionMatches -SurfaceActions $SurfaceActions -Action 'blackjack_peek')
    if ($peekControls.Count -ne 1) {
        throw "The open public Peek window must expose exactly one rendered Peek control; found $($peekControls.Count)."
    }
    $peekEnabled = Get-Rw062RequiredPublicProperty -InputObject $peekControls[0] -Name 'enabled' -Context 'Blackjack Peek control'
    $peekIndex = Get-Rw062RequiredPublicProperty -InputObject $peekControls[0] -Name 'index' -Context 'Blackjack Peek control'
    if ($peekEnabled -isnot [bool] -or -not [bool]$peekEnabled -or
        ($peekIndex -isnot [int32] -and $peekIndex -isnot [int64]) -or [long]$peekIndex -ne 0) {
        throw 'The rendered Blackjack Peek control is disabled or no longer has its exact index zero binding.'
    }
    return [pscustomobject][ordered]@{ stage = 'peek'; action = 'blackjack_peek'; index = 0 }
}


function Select-CheatReplayBossCalloutAction {
    param(
        [Parameter(Mandatory = $true)]$Game,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$SurfaceActions
    )

    $bossActive = Get-Rw062RequiredPublicProperty -InputObject $Game -Name 'boss_duel_active' -Context 'Rourke public game state'
    $tell = Get-Rw062RequiredPublicProperty -InputObject $Game -Name 'boss_tell' -Context 'Rourke public game state'
    if ($bossActive -isnot [bool] -or -not [bool]$bossActive -or $tell -isnot [string]) {
        throw 'Rourke callout policy requires an exact active-duel boolean and rendered tell text.'
    }
    if ([string]::IsNullOrWhiteSpace([string]$tell) -or [string]$tell -match 'gives\s+nothing\s+away') {
        return [pscustomobject][ordered]@{ stage = 'none'; action = ''; index = -1 }
    }

    $expectedLabelFragment = if ([string]$tell -match '(slug|squares\s+one)') {
        'stack'
    } elseif ([string]$tell -match '(thumb|down\s+card)') {
        'swap'
    } else {
        throw "Rourke exposed an unrecognized public tell: $tell"
    }

    $callouts = @(Get-Rw062RequiredPublicProperty -InputObject $Game -Name 'boss_callouts' -Context 'Rourke public game state')
    if ($callouts.Count -ne 2) {
        throw "Rourke must expose exactly two public callout labels; found $($callouts.Count)."
    }
    $matchingIndices = @()
    $seenIds = @()
    for ($index = 0; $index -lt $callouts.Count; $index++) {
        $id = Get-Rw062RequiredPublicProperty -InputObject $callouts[$index] -Name 'id' -Context "Rourke callout $index"
        $label = Get-Rw062RequiredPublicProperty -InputObject $callouts[$index] -Name 'label' -Context "Rourke callout $index"
        if ($id -isnot [string] -or [string]$id -cnotmatch '^[a-z0-9_]+$' -or
            $label -isnot [string] -or [string]::IsNullOrWhiteSpace([string]$label)) {
            throw "Rourke callout $index has no stable public id and label."
        }
        if (@($seenIds | Where-Object { [string]$_ -ceq [string]$id }).Count -gt 0) {
            throw "Rourke exposes duplicate public callout id '$id'."
        }
        $seenIds += [string]$id
        $labelText = [string]$label
        if ($labelText.IndexOf($expectedLabelFragment, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
            $matchingIndices += $index
        }
    }
    if ($matchingIndices.Count -ne 1) {
        throw "Rourke's public tell '$tell' has no unique rendered '$expectedLabelFragment' callout."
    }

    $calloutUsed = Get-Rw062RequiredPublicProperty -InputObject $Game -Name 'boss_callout_used' -Context 'Rourke public game state'
    $canDeal = Get-Rw062RequiredPublicProperty -InputObject $Game -Name 'can_deal' -Context 'Rourke public game state'
    if ($calloutUsed -isnot [bool] -or $canDeal -isnot [bool]) {
        throw 'Rourke callout policy requires exact boolean used/deal witnesses.'
    }
    if ([bool]$calloutUsed) {
        return [pscustomobject][ordered]@{ stage = 'used'; action = ''; index = -1 }
    }
    $matchingIndex = [int]$matchingIndices[0]
    if ([bool]$canDeal) {
        # The tell is rendered before Deal, but production intentionally enables
        # its indexed callout only after cards are on the felt.
        return [pscustomobject][ordered]@{ stage = 'defer_until_dealt'; action = ''; index = $matchingIndex }
    }

    $surfaceMatches = @(Get-Rw062PublicSurfaceActionMatches -SurfaceActions $SurfaceActions -Action 'blackjack_boss_callout' | Where-Object {
        $indexProperties = @(Get-Rw062ExactPublicPropertyMatches -InputObject $_ -Name 'index')
        $indexProperties.Count -eq 1 -and
            ($indexProperties[0].Value -is [int32] -or $indexProperties[0].Value -is [int64]) -and
            [long]$indexProperties[0].Value -eq $matchingIndex
    })
    if ($surfaceMatches.Count -ne 1) {
        throw "Rourke's post-deal callout index $matchingIndex is missing or ambiguous on the rendered surface."
    }
    $enabled = Get-Rw062RequiredPublicProperty -InputObject $surfaceMatches[0] -Name 'enabled' -Context "Rourke callout index $matchingIndex"
    if ($enabled -isnot [bool] -or -not [bool]$enabled) {
        throw "Rourke's post-deal callout index $matchingIndex is not enabled."
    }
    return [pscustomobject][ordered]@{ stage = 'call'; action = 'blackjack_boss_callout'; index = $matchingIndex }
}


function Select-CheatReplayShowdownWalkChoice {
    param([Parameter(Mandatory = $true)]$EventPopup)

    $visible = Get-Rw062RequiredPublicProperty -InputObject $EventPopup -Name 'visible' -Context 'Showdown walk popup'
    $renderValid = Get-Rw062RequiredPublicProperty -InputObject $EventPopup -Name 'render_valid' -Context 'Showdown walk popup'
    $eventId = Get-Rw062RequiredPublicProperty -InputObject $EventPopup -Name 'event_id' -Context 'Showdown walk popup'
    if ($visible -isnot [bool] -or -not [bool]$visible -or
        $renderValid -isnot [bool] -or -not [bool]$renderValid -or
        $eventId -isnot [string] -or [string]$eventId -cne 'the_house_calls') {
        throw 'Showdown walk policy requires the exact fully rendered the_house_calls popup.'
    }

    $choiceIds = @(Get-Rw062RequiredPublicProperty -InputObject $EventPopup -Name 'choice_ids' -Context 'Showdown walk popup')
    $choices = @(Get-Rw062RequiredPublicProperty -InputObject $EventPopup -Name 'choices' -Context 'Showdown walk popup')
    if ($choiceIds.Count -eq 0 -or $choiceIds.Count -ne $choices.Count) {
        throw 'Showdown walk choice ids and rendered choices are empty or disagree in count.'
    }
    foreach ($choiceIdValue in $choiceIds) {
        if ($choiceIdValue -isnot [string]) {
            throw 'Showdown walk exposes a non-string public choice id.'
        }
        $choiceId = [string]$choiceIdValue
        if ($choiceId -cne 'keep_everything' -and
            $choiceId -cnotmatch '^(?:trash_item|hand_to_crew)__[a-z0-9_]+$') {
            throw "Showdown walk exposes unsupported public choice '$choiceId'."
        }
        if (@($choiceIds | Where-Object { $_ -is [string] -and [string]$_ -ceq $choiceId }).Count -ne 1) {
            throw "Showdown walk exposes duplicate public choice '$choiceId'."
        }
        $matches = @($choices | Where-Object {
            $idProperties = @(Get-Rw062ExactPublicPropertyMatches -InputObject $_ -Name 'id')
            $idProperties.Count -eq 1 -and $idProperties[0].Value -is [string] -and
                [string]$idProperties[0].Value -ceq $choiceId
        })
        if ($matches.Count -ne 1) {
            throw "Showdown walk choice '$choiceId' is missing or ambiguous in rendered choices."
        }
        $enabled = Get-Rw062RequiredPublicProperty -InputObject $matches[0] -Name 'enabled' -Context "Showdown walk choice '$choiceId'"
        $label = Get-Rw062RequiredPublicProperty -InputObject $matches[0] -Name 'label' -Context "Showdown walk choice '$choiceId'"
        $text = Get-Rw062RequiredPublicProperty -InputObject $matches[0] -Name 'text' -Context "Showdown walk choice '$choiceId'"
        if ($enabled -isnot [bool] -or -not [bool]$enabled -or
            $label -isnot [string] -or [string]::IsNullOrWhiteSpace([string]$label) -or
            $text -isnot [string] -or [string]::IsNullOrWhiteSpace([string]$text)) {
            throw "Showdown walk choice '$choiceId' is disabled or missing rendered copy."
        }
    }
    if (@($choiceIds | Where-Object { $_ -is [string] -and [string]$_ -ceq 'keep_everything' }).Count -ne 1) {
        throw "Showdown walk must expose exactly one 'keep_everything' control."
    }

    $classifiedItemIds = @(
        'marked_cards', 'foil_sleeve', 'weighted_keyring',
        'xray_glasses', 'tab_detector', 'tarot_card'
    )
    $presentClassifiedItems = @($classifiedItemIds | Where-Object {
        $itemId = [string]$_
        @($choiceIds | Where-Object { $_ -is [string] -and [string]$_ -ceq "trash_item__$itemId" }).Count -eq 1
    })
    if ($presentClassifiedItems.Count -gt 1) {
        throw "Showdown walk carries multiple classified items that cannot all be removed in its one public pocket change: $($presentClassifiedItems -join ', ')."
    }
    if ($presentClassifiedItems.Count -eq 0) {
        return 'keep_everything'
    }

    $classifiedItemId = [string]$presentClassifiedItems[0]
    $crewChoice = "hand_to_crew__$classifiedItemId"
    if (@($choiceIds | Where-Object { $_ -is [string] -and [string]$_ -ceq $crewChoice }).Count -eq 1) {
        return $crewChoice
    }
    $trashChoice = "trash_item__$classifiedItemId"
    if (@($choiceIds | Where-Object { $_ -is [string] -and [string]$_ -ceq $trashChoice }).Count -eq 1) {
        return $trashChoice
    }
    throw "Showdown walk exposed classified item '$classifiedItemId' without a rendered removal choice."
}


function Select-GrandFareMachineJamChoice {
    param(
        [Parameter(Mandatory = $true)]$EventPopup,
        [Parameter(Mandatory = $true)]$Talk
    )

    $talkVisible = Get-Rw062RequiredPublicProperty -InputObject $Talk -Name 'visible' -Context 'Talk surface'
    if ($talkVisible -isnot [bool] -or [bool]$talkVisible) {
        throw 'Grand fare recovery refuses a visible, missing, or non-boolean TalkDock state.'
    }

    $eventVisible = Get-Rw062RequiredPublicProperty -InputObject $EventPopup -Name 'visible' -Context 'Event popup'
    if ($eventVisible -isnot [bool] -or -not [bool]$eventVisible) {
        throw 'Grand fare recovery requires one explicitly visible event popup before applying its allowlist.'
    }
    $renderValid = Get-Rw062RequiredPublicProperty -InputObject $EventPopup -Name 'render_valid' -Context 'Event popup'
    if ($renderValid -isnot [bool] -or -not [bool]$renderValid) {
        throw 'Grand fare recovery requires an exact rendered event-popup witness.'
    }
    $eventId = Get-Rw062RequiredPublicProperty -InputObject $EventPopup -Name 'event_id' -Context 'Event popup'
    if ($eventId -isnot [string] -or [string]$eventId -cne 'machine_jam') {
        throw "Grand fare recovery refuses unknown event '$eventId'."
    }
    $title = Get-Rw062RequiredPublicProperty -InputObject $EventPopup -Name 'title' -Context 'machine_jam event'
    $summary = Get-Rw062RequiredPublicProperty -InputObject $EventPopup -Name 'summary' -Context 'machine_jam event'
    if ($title -isnot [string] -or [string]$title -cne 'Machine Jam' -or
        $summary -isnot [string] -or [string]$summary -cne "The machine stops. The room doesn't.") {
        throw 'The fully rendered machine_jam title or summary changed; Grand fare recovery will not guess through it.'
    }

    $choiceIds = @(Get-Rw062RequiredPublicProperty -InputObject $EventPopup -Name 'choice_ids' -Context 'machine_jam event')
    if ($choiceIds.Count -ne 2 -or $choiceIds[0] -isnot [string] -or [string]$choiceIds[0] -cne 'wait' -or
        $choiceIds[1] -isnot [string] -or [string]$choiceIds[1] -cne 'push') {
        throw 'The public machine_jam choice-id allowlist must be exactly ordered wait, push.'
    }

    $choices = @(Get-Rw062RequiredPublicProperty -InputObject $EventPopup -Name 'choices' -Context 'machine_jam event')
    if ($choices.Count -ne 2) {
        throw "The public machine_jam event must expose exactly two rendered choices; found $($choices.Count)."
    }
    $expectedCopy = @{
        wait = [pscustomobject]@{ label = 'Wait it out'; text = 'Play stops. Attention moves on.' }
        push = [pscustomobject]@{ label = 'Push through'; text = 'You keep playing. The room turns your way.' }
    }
    foreach ($choiceId in @('wait', 'push')) {
        $matches = @($choices | Where-Object {
            $idProperties = @(Get-Rw062ExactPublicPropertyMatches -InputObject $_ -Name 'id')
            $idProperties.Count -eq 1 -and $idProperties[0].Value -is [string] -and [string]$idProperties[0].Value -ceq $choiceId
        })
        if ($matches.Count -ne 1) {
            throw "The public machine_jam choice '$choiceId' is missing or ambiguous."
        }
        $choice = $matches[0]
        $enabled = Get-Rw062RequiredPublicProperty -InputObject $choice -Name 'enabled' -Context "machine_jam choice '$choiceId'"
        $label = Get-Rw062RequiredPublicProperty -InputObject $choice -Name 'label' -Context "machine_jam choice '$choiceId'"
        $text = Get-Rw062RequiredPublicProperty -InputObject $choice -Name 'text' -Context "machine_jam choice '$choiceId'"
        if ($enabled -isnot [bool] -or -not [bool]$enabled) {
            throw "The public machine_jam choice '$choiceId' is disabled or has a non-boolean enabled state."
        }
        $expected = $expectedCopy[$choiceId]
        if ($label -isnot [string] -or [string]$label -cne [string]$expected.label -or
            $text -isnot [string] -or [string]$text -cne [string]$expected.text) {
            throw "The rendered machine_jam copy for '$choiceId' changed; Grand fare recovery will not guess through it."
        }
    }

    # The popup renders no numeric consequence or confirmation step. Choose the
    # exact visible de-escalation copy; never infer hidden cash/heat deltas.
    return 'wait'
}


function Select-GrandFareFundingObject {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$CanvasObjects,
        [Parameter(Mandatory = $true)][string]$WorldNodeId,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$AcceptedOfferKeys,
        [AllowEmptyCollection()][string[]]$AcceptedLenderIds = @()
    )

    if ($WorldNodeId -cnotmatch '^[a-z0-9_]+$') {
        throw 'Grand fare funding requires one stable public world-node id.'
    }
    $visibleLenders = @($CanvasObjects | Where-Object {
        $properties = @(Get-Rw062ExactPublicPropertyMatches -InputObject $_ -Name 'semantic_id')
        $properties.Count -eq 1 -and $properties[0].Value -is [string] -and
            ([string]$properties[0].Value).StartsWith('lender:', [StringComparison]::Ordinal)
    })
    $eligible = @()
    $seenSemanticIds = @{}
    foreach ($candidate in $visibleLenders) {
        $semanticId = [string](Get-Rw062RequiredPublicProperty -InputObject $candidate -Name 'semantic_id' -Context 'Funding lender object')
        if ($seenSemanticIds.ContainsKey($semanticId)) {
            throw "Funding room exposes duplicate public semantic id '$semanticId'."
        }
        $seenSemanticIds[$semanticId] = $true
        $rendered = Get-Rw062RequiredPublicProperty -InputObject $candidate -Name 'rendered' -Context "Funding lender object '$semanticId'"
        $enabled = Get-Rw062RequiredPublicProperty -InputObject $candidate -Name 'enabled' -Context "Funding lender object '$semanticId'"
        if ($rendered -isnot [bool] -or $enabled -isnot [bool]) {
            throw "Funding lender object '$semanticId' has no exact rendered/enabled witnesses."
        }
        if (-not [bool]$rendered -or -not [bool]$enabled) { continue }
        $lenderId = $semanticId.Substring('lender:'.Length)
        $offerKey = "$WorldNodeId|$semanticId"
        if (@($AcceptedOfferKeys | Where-Object { [string]$_ -ceq $offerKey }).Count -gt 0 -or
            @($AcceptedLenderIds | Where-Object { [string]$_ -ceq $lenderId }).Count -gt 0) {
            continue
        }
        $eligible += $candidate
    }
    if ($eligible.Count -eq 0) {
        throw 'Grand fare funding found no rendered, enabled, unused public lender object.'
    }
    # A room may legitimately render several lenders. Public semantic id is the
    # stable tie-breaker, so fixed-seed replays choose the first ordinal id.
    $object = @($eligible | Sort-Object -Property @{ Expression = {
        [string](Get-Rw062RequiredPublicProperty -InputObject $_ -Name 'semantic_id' -Context 'Funding lender sort key')
    } } -CaseSensitive)[0]
    $semanticId = [string](Get-Rw062RequiredPublicProperty -InputObject $object -Name 'semantic_id' -Context 'Funding lender object')
    $lenderId = $semanticId.Substring('lender:'.Length)
    if ($lenderId -cnotmatch '^[a-z0-9_]+$') {
        throw 'The visible funding lender has no stable public lender suffix.'
    }
    $label = Get-Rw062RequiredPublicProperty -InputObject $object -Name 'label' -Context 'Funding lender object'
    $objectType = Get-Rw062RequiredPublicProperty -InputObject $object -Name 'object_type' -Context 'Funding lender object'
    $enabled = Get-Rw062RequiredPublicProperty -InputObject $object -Name 'enabled' -Context 'Funding lender object'
    $rendered = Get-Rw062RequiredPublicProperty -InputObject $object -Name 'rendered' -Context 'Funding lender object'
    if ($label -isnot [string] -or [string]::IsNullOrWhiteSpace([string]$label)) {
        throw 'The visible funding lender has no rendered public label.'
    }
    if ($objectType -isnot [string] -or [string]$objectType -cnotin @('lender', 'character')) {
        throw "The visible funding lender has unsupported public object type '$objectType'."
    }
    if ($enabled -isnot [bool] -or -not [bool]$enabled -or $rendered -isnot [bool] -or -not [bool]$rendered) {
        throw 'The visible funding lender is disabled, clipped, or has a non-boolean public witness.'
    }

    $offerKey = "$WorldNodeId|$semanticId"
    if (@($AcceptedOfferKeys | Where-Object { [string]$_ -ceq $offerKey }).Count -gt 0) {
        throw "Grand fare funding refuses repeat use of disclosed offer '$offerKey'."
    }

    return [pscustomobject][ordered]@{
        offer_key = $offerKey
        world_node_id = $WorldNodeId
        semantic_id = $semanticId
        lender_id = $lenderId
        lender_label = [string]$label
    }
}


function Select-GrandFareFundingObjectAction {
    param(
        [Parameter(Mandatory = $true)]$Selection,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$RoomActions
    )

    $offerKey = Get-Rw062RequiredPublicProperty -InputObject $Selection -Name 'offer_key' -Context 'Funding object selection'
    $worldNodeId = Get-Rw062RequiredPublicProperty -InputObject $Selection -Name 'world_node_id' -Context 'Funding object selection'
    $semanticId = Get-Rw062RequiredPublicProperty -InputObject $Selection -Name 'semantic_id' -Context 'Funding object selection'
    $lenderId = Get-Rw062RequiredPublicProperty -InputObject $Selection -Name 'lender_id' -Context 'Funding object selection'
    $label = Get-Rw062RequiredPublicProperty -InputObject $Selection -Name 'lender_label' -Context 'Funding object selection'
    if ($offerKey -isnot [string] -or [string]::IsNullOrWhiteSpace([string]$offerKey) -or
        $worldNodeId -isnot [string] -or [string]$worldNodeId -cnotmatch '^[a-z0-9_]+$' -or
        $semanticId -isnot [string] -or [string]$semanticId -cne "lender:$lenderId" -or
        $lenderId -isnot [string] -or [string]$lenderId -cnotmatch '^[a-z0-9_]+$' -or
        $label -isnot [string] -or [string]::IsNullOrWhiteSpace([string]$label)) {
        throw 'Funding object selection changed before its public action was validated.'
    }

    if ($RoomActions.Count -ne 1) {
        throw "Grand fare funding requires exactly one selected public lender action; found $($RoomActions.Count)."
    }
    $action = $RoomActions[0]
    $actionLabel = Get-Rw062RequiredPublicProperty -InputObject $action -Name 'label' -Context 'Funding lender action'
    $actionEnabled = Get-Rw062RequiredPublicProperty -InputObject $action -Name 'enabled' -Context 'Funding lender action'
    $actionIndex = Get-Rw062RequiredPublicProperty -InputObject $action -Name 'index' -Context 'Funding lender action'
    if ($actionLabel -isnot [string] -or [string]$actionLabel -cne 'Use' -or
        ($actionIndex -isnot [int32] -and $actionIndex -isnot [int64]) -or [long]$actionIndex -ne 0) {
        throw 'The selected funding lender no longer exposes the exact public Use action.'
    }
    if ($actionEnabled -isnot [bool] -or -not [bool]$actionEnabled) {
        throw 'The selected funding lender Use action is disabled or has a non-boolean enabled state.'
    }
    foreach ($blankIdentity in @('id', 'action', 'action_id', 'emit_object_id')) {
        $identity = Get-Rw062RequiredPublicProperty -InputObject $action -Name $blankIdentity -Context 'Funding lender action'
        if ($identity -isnot [string] -or -not [string]::IsNullOrEmpty([string]$identity)) {
            throw "The rendered lender Use row unexpectedly claims public identity '$blankIdentity'."
        }
    }

    return [pscustomobject][ordered]@{
        offer_key = [string]$offerKey
        world_node_id = [string]$worldNodeId
        semantic_id = $semanticId
        lender_id = $lenderId
        lender_label = [string]$label
        action = $action
    }
}


function Get-GrandFarePublicDebtCount {
    param(
        [Parameter(Mandatory = $true)]$DebtIndicator,
        [Parameter(Mandatory = $true)][string]$Context
    )

    $rendered = Get-Rw062RequiredPublicProperty -InputObject $DebtIndicator -Name 'rendered' -Context $Context
    $present = Get-Rw062RequiredPublicProperty -InputObject $DebtIndicator -Name 'present' -Context $Context
    if ($rendered -isnot [bool] -or -not [bool]$rendered -or $present -isnot [bool]) {
        throw "$Context has no trustworthy rendered debt-indicator witness."
    }
    if (-not [bool]$present) {
        if (@(Get-Rw062ExactPublicPropertyMatches -InputObject $DebtIndicator -Name 'tooltip').Count -ne 0) {
            throw "$Context claims no debt icon but still exposes debt tooltip text."
        }
        return 0
    }

    $tooltip = Get-Rw062RequiredPublicProperty -InputObject $DebtIndicator -Name 'tooltip' -Context $Context
    if ($tooltip -isnot [string] -or [string]::IsNullOrWhiteSpace([string]$tooltip) -or
        [string]$tooltip -ceq 'none') {
        throw "$Context has a malformed rendered debt tooltip."
    }
    $multiple = [regex]::Match([string]$tooltip, '^(?<count>[2-9][0-9]*) active debts$', [Text.RegularExpressions.RegexOptions]::CultureInvariant)
    if ($multiple.Success) {
        $count = [long]$multiple.Groups['count'].Value
        if ($count -gt [int]::MaxValue) {
            throw "$Context debt count exceeds the supported public integer range."
        }
        return [int]$count
    }
    if ([string]$tooltip -imatch '^[0-9]+ active debts$') {
        throw "$Context has an impossible rendered multi-debt count."
    }
    if (([string]$tooltip).Length -gt 30) {
        throw "$Context single-debt tooltip exceeds the rendered HUD limit."
    }
    return 1
}


function Test-GrandFareFundingPreflight {
    param(
        [Parameter(Mandatory = $true)]$Selection,
        [Parameter(Mandatory = $true)]$DebtIndicator,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$AcceptedLenderIds
    )

    $lenderId = Get-Rw062RequiredPublicProperty -InputObject $Selection -Name 'lender_id' -Context 'Funding preflight selection'
    if ($lenderId -isnot [string] -or [string]$lenderId -cnotmatch '^[a-z0-9_]+$') {
        throw 'Funding preflight has no stable public lender id.'
    }
    $debtCount = Get-GrandFarePublicDebtCount -DebtIndicator $DebtIndicator -Context 'Pre-funding HUD'
    if (@($AcceptedLenderIds | Where-Object { [string]$_ -ceq [string]$lenderId }).Count -gt 0) {
        return $false
    }
    # RunState merges only Crew favor debt. Count-only public proof cannot
    # attribute a merge, so Crew is eligible only from a visibly debt-free HUD.
    if ([string]$lenderId -ceq 'the_crew' -and $debtCount -ne 0) {
        return $false
    }
    return $true
}


function Select-GrandFareFundingTalkOffer {
    param(
        [Parameter(Mandatory = $true)]$Selection,
        [Parameter(Mandatory = $true)]$Talk,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$TalkChoices
    )

    $lenderId = Get-Rw062RequiredPublicProperty -InputObject $Selection -Name 'lender_id' -Context 'Funding selection'
    $offerKey = Get-Rw062RequiredPublicProperty -InputObject $Selection -Name 'offer_key' -Context 'Funding selection'
    $lenderLabel = Get-Rw062RequiredPublicProperty -InputObject $Selection -Name 'lender_label' -Context 'Funding selection'
    if ($lenderId -isnot [string] -or [string]$lenderId -cnotmatch '^[a-z0-9_]+$' -or
        $offerKey -isnot [string] -or [string]::IsNullOrWhiteSpace([string]$offerKey) -or
        $lenderLabel -isnot [string] -or [string]::IsNullOrWhiteSpace([string]$lenderLabel)) {
        throw 'Funding selection identity is malformed.'
    }

    $talkVisible = Get-Rw062RequiredPublicProperty -InputObject $Talk -Name 'visible' -Context 'Funding TalkDock'
    if ($talkVisible -isnot [bool] -or -not [bool]$talkVisible) {
        throw 'Funding lender action did not open one visible TalkDock.'
    }
    $renderValid = Get-Rw062RequiredPublicProperty -InputObject $Talk -Name 'render_valid' -Context 'Funding TalkDock'
    $talkExpanded = Get-Rw062RequiredPublicProperty -InputObject $Talk -Name 'expanded' -Context 'Funding TalkDock'
    $bodyComplete = Get-Rw062RequiredPublicProperty -InputObject $Talk -Name 'body_complete' -Context 'Funding TalkDock'
    $typewriterActive = Get-Rw062RequiredPublicProperty -InputObject $Talk -Name 'typewriter_active' -Context 'Funding TalkDock'
    if ($renderValid -isnot [bool] -or -not [bool]$renderValid -or
        $talkExpanded -isnot [bool] -or -not [bool]$talkExpanded -or
        $bodyComplete -isnot [bool] -or -not [bool]$bodyComplete -or
        $typewriterActive -isnot [bool] -or [bool]$typewriterActive) {
        throw 'Funding TalkDock terms are not fully rendered yet.'
    }
    $eventId = Get-Rw062RequiredPublicProperty -InputObject $Talk -Name 'event_id' -Context 'Funding TalkDock'
    $expectedEventId = "lender_conversation:borrow:$lenderId"
    if ($eventId -isnot [string] -or [string]$eventId -cne $expectedEventId) {
        throw "Funding TalkDock identity '$eventId' does not match '$expectedEventId'."
    }
    $summary = Get-Rw062RequiredPublicProperty -InputObject $Talk -Name 'summary' -Context 'Funding TalkDock'
    if ($summary -isnot [string]) {
        throw 'Funding TalkDock terms are not rendered as public text.'
    }
    $termsPattern = '^(?<description>.+) Borrow \$(?<principal>[1-9][0-9]*)\. (?:(?:Repay (?<favor>[1-9][0-9]*) (?<favor_word>favor|favors) \(0% cash interest\))|(?:Repay \$(?<cash>[1-9][0-9]*) \((?<interest>[0-9]+)% interest\))) in (?<turns>[1-9][0-9]*) (?<turn_word>turn|turns)\.$'
    $terms = [regex]::Match([string]$summary, $termsPattern, [Text.RegularExpressions.RegexOptions]::CultureInvariant)
    if (-not $terms.Success) {
        throw 'Funding TalkDock does not disclose one exact positive principal and repayment obligation.'
    }
    $principal = [int]$terms.Groups['principal'].Value
    $deadlineTurns = [int]$terms.Groups['turns'].Value
    $favorText = [string]$terms.Groups['favor'].Value
    $cashText = [string]$terms.Groups['cash'].Value
    $debtKind = if (-not [string]::IsNullOrWhiteSpace($favorText)) { 'favor' } else { 'cash' }
    $repayment = if ($debtKind -eq 'favor') { [int]$favorText } else { [int]$cashText }
    if ($principal -le 0 -or $repayment -le 0 -or $deadlineTurns -le 0) {
        throw 'Funding TalkDock contains a non-positive disclosed term.'
    }
    if ($debtKind -ceq 'favor' -and
        (($repayment -eq 1) -ne ($terms.Groups['favor_word'].Value -ceq 'favor'))) {
        throw 'Funding TalkDock favor grammar does not match its disclosed obligation.'
    }
    if (($deadlineTurns -eq 1) -ne ($terms.Groups['turn_word'].Value -ceq 'turn')) {
        throw 'Funding TalkDock deadline grammar does not match its disclosed duration.'
    }
    $obligationStart = ([string]$summary).IndexOf('Borrow $', [StringComparison]::Ordinal)
    if ($obligationStart -lt 0) {
        throw 'Funding TalkDock has no exact rendered obligation suffix.'
    }
    $obligationSummary = ([string]$summary).Substring($obligationStart)

    $choiceIds = @(Get-Rw062RequiredPublicProperty -InputObject $Talk -Name 'choice_ids' -Context 'Funding TalkDock')
    if ($choiceIds.Count -ne 2 -or
        @($choiceIds | Where-Object { $_ -is [string] -and [string]$_ -ceq 'accept' }).Count -ne 1 -or
        @($choiceIds | Where-Object { $_ -is [string] -and [string]$_ -ceq 'decline' }).Count -ne 1) {
        throw 'Funding TalkDock must expose exactly one accept and one decline choice id.'
    }
    if ($TalkChoices.Count -ne 2) {
        throw "Funding TalkDock must render exactly two public choice controls; found $($TalkChoices.Count)."
    }
    foreach ($expected in @(
        [pscustomobject]@{ id = 'accept'; label = 'Accept Offer' },
        [pscustomobject]@{ id = 'decline'; label = 'Not Now' }
    )) {
        $matches = @($TalkChoices | Where-Object {
            $idProperties = @(Get-Rw062ExactPublicPropertyMatches -InputObject $_ -Name 'id')
            $idProperties.Count -eq 1 -and $idProperties[0].Value -is [string] -and [string]$idProperties[0].Value -ceq [string]$expected.id
        })
        if ($matches.Count -ne 1) {
            throw "Funding TalkDock choice '$($expected.id)' is missing or ambiguous."
        }
        $choiceEnabled = Get-Rw062RequiredPublicProperty -InputObject $matches[0] -Name 'enabled' -Context "Funding TalkDock choice '$($expected.id)'"
        $choiceLabel = Get-Rw062RequiredPublicProperty -InputObject $matches[0] -Name 'label' -Context "Funding TalkDock choice '$($expected.id)'"
        if ($choiceEnabled -isnot [bool] -or -not [bool]$choiceEnabled -or
            $choiceLabel -isnot [string] -or [string]$choiceLabel -cne [string]$expected.label) {
            throw "Funding TalkDock choice '$($expected.id)' is disabled, clipped, or relabeled."
        }
    }

    return [pscustomobject][ordered]@{
        offer_key = [string]$offerKey
        lender_id = [string]$lenderId
        lender_label = [string]$lenderLabel
        event_id = [string]$eventId
        talk_summary = [string]$summary
        terms_summary = $obligationSummary
        principal = $principal
        debt_kind = $debtKind
        repayment = $repayment
        interest_percent = if ($debtKind -eq 'cash') { [int]$terms.Groups['interest'].Value } else { 0 }
        deadline_turns = $deadlineTurns
    }
}


function Assert-GrandFareFundingConfirmation {
    param(
        [Parameter(Mandatory = $true)]$Offer,
        [Parameter(Mandatory = $true)]$Talk,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$TalkChoices
    )

    $expectedEventId = Get-Rw062RequiredPublicProperty -InputObject $Offer -Name 'event_id' -Context 'Funding offer'
    $expectedSummary = Get-Rw062RequiredPublicProperty -InputObject $Offer -Name 'talk_summary' -Context 'Funding offer'
    $talkVisible = Get-Rw062RequiredPublicProperty -InputObject $Talk -Name 'visible' -Context 'Armed funding TalkDock'
    $renderValid = Get-Rw062RequiredPublicProperty -InputObject $Talk -Name 'render_valid' -Context 'Armed funding TalkDock'
    $eventId = Get-Rw062RequiredPublicProperty -InputObject $Talk -Name 'event_id' -Context 'Armed funding TalkDock'
    $summary = Get-Rw062RequiredPublicProperty -InputObject $Talk -Name 'summary' -Context 'Armed funding TalkDock'
    if ($talkVisible -isnot [bool] -or -not [bool]$talkVisible -or
        $renderValid -isnot [bool] -or -not [bool]$renderValid -or
        $eventId -isnot [string] -or [string]$eventId -cne [string]$expectedEventId -or
        $expectedSummary -isnot [string] -or $summary -isnot [string] -or
        [string]$summary -cne [string]$expectedSummary) {
        throw 'Funding confirmation did not remain on the exact visible lender TalkDock.'
    }
    $talkExpanded = Get-Rw062RequiredPublicProperty -InputObject $Talk -Name 'expanded' -Context 'Armed funding TalkDock'
    $bodyComplete = Get-Rw062RequiredPublicProperty -InputObject $Talk -Name 'body_complete' -Context 'Armed funding TalkDock'
    $typewriterActive = Get-Rw062RequiredPublicProperty -InputObject $Talk -Name 'typewriter_active' -Context 'Armed funding TalkDock'
    if ($talkExpanded -isnot [bool] -or -not [bool]$talkExpanded -or
        $bodyComplete -isnot [bool] -or -not [bool]$bodyComplete -or
        $typewriterActive -isnot [bool] -or [bool]$typewriterActive) {
        throw 'Funding confirmation terms are not fully rendered.'
    }
    $choiceIds = @(Get-Rw062RequiredPublicProperty -InputObject $Talk -Name 'choice_ids' -Context 'Armed funding TalkDock')
    if ($choiceIds.Count -ne 2 -or $choiceIds[0] -isnot [string] -or [string]$choiceIds[0] -cne 'accept' -or
        $choiceIds[1] -isnot [string] -or [string]$choiceIds[1] -cne 'decline') {
        throw 'Funding confirmation changed the exact ordered choice-id set.'
    }
    if ($TalkChoices.Count -ne 2) {
        throw 'Funding confirmation changed the exact rendered choice set.'
    }
    $expectedControls = @(
        [pscustomobject]@{ id = 'accept'; label = 'Confirm: Accept Offer' },
        [pscustomobject]@{ id = 'decline'; label = 'Not Now' }
    )
    for ($index = 0; $index -lt $expectedControls.Count; $index++) {
        $expected = $expectedControls[$index]
        $control = $TalkChoices[$index]
        $controlId = Get-Rw062RequiredPublicProperty -InputObject $control -Name 'id' -Context "Armed funding choice $index"
        $enabled = Get-Rw062RequiredPublicProperty -InputObject $control -Name 'enabled' -Context "Armed funding choice $index"
        $label = Get-Rw062RequiredPublicProperty -InputObject $control -Name 'label' -Context "Armed funding choice $index"
        if ($controlId -isnot [string] -or [string]$controlId -cne [string]$expected.id -or
            $enabled -isnot [bool] -or -not [bool]$enabled -or
            $label -isnot [string] -or [string]$label -cne [string]$expected.label) {
            throw "Funding confirmation changed rendered choice $index."
        }
    }
    return $true
}


function Assert-GrandFareFundingResult {
    param(
        [Parameter(Mandatory = $true)]$Offer,
        [Parameter(Mandatory = $true)][int]$BeforeBankroll,
        [Parameter(Mandatory = $true)]$BeforeDebtIndicator,
        [Parameter(Mandatory = $true)]$AfterObservation
    )

    $talkVisible = Get-Rw062RequiredPublicProperty -InputObject (Get-Rw062RequiredPublicProperty -InputObject $AfterObservation -Name 'talk' -Context 'Post-funding observation') -Name 'visible' -Context 'Post-funding TalkDock'
    if ($talkVisible -isnot [bool] -or [bool]$talkVisible) {
        throw 'Funding TalkDock remained visible or lost its boolean visibility signal after confirmation.'
    }

    $principal = Get-Rw062RequiredPublicProperty -InputObject $Offer -Name 'principal' -Context 'Funding offer'
    if (($principal -isnot [int32] -and $principal -isnot [int64]) -or [long]$principal -le 0) {
        throw 'Funding offer principal is not a positive integral public value.'
    }
    $statusHud = Get-Rw062RequiredPublicProperty -InputObject $AfterObservation -Name 'status_hud' -Context 'Post-funding observation'
    $bankrollRendered = Get-Rw062RequiredPublicProperty -InputObject $statusHud -Name 'bankroll_rendered' -Context 'Post-funding status HUD'
    $afterBankroll = Get-Rw062RequiredPublicProperty -InputObject $statusHud -Name 'bankroll' -Context 'Post-funding status HUD'
    if ($bankrollRendered -isnot [bool] -or -not [bool]$bankrollRendered -or
        ($afterBankroll -isnot [int32] -and $afterBankroll -isnot [int64])) {
        throw 'Post-funding bankroll is not an integral fully rendered HUD value.'
    }
    $expectedBankrollLong = [long]$BeforeBankroll + [long]$principal
    if ($expectedBankrollLong -gt [int]::MaxValue -or $expectedBankrollLong -lt [int]::MinValue) {
        throw 'Funding bankroll result exceeds the supported public integer range.'
    }
    if ([int]$afterBankroll -ne [int]$expectedBankrollLong) {
        throw "Funding bankroll change mismatched the disclosed principal: expected $expectedBankrollLong, found $afterBankroll."
    }

    $beforeDebtCount = Get-GrandFarePublicDebtCount -DebtIndicator $BeforeDebtIndicator -Context 'Pre-funding HUD'
    $afterDebtIndicator = Get-Rw062RequiredPublicProperty -InputObject $statusHud -Name 'debt_indicator' -Context 'Post-funding status HUD'
    $afterDebtCount = Get-GrandFarePublicDebtCount -DebtIndicator $afterDebtIndicator -Context 'Post-funding HUD'
    if ($afterDebtCount -ne $beforeDebtCount + 1) {
        throw "Funding did not add exactly one rendered debt indicator: before $beforeDebtCount, after $afterDebtCount."
    }

    $feedback = Get-Rw062RequiredPublicProperty -InputObject $AfterObservation -Name 'feedback' -Context 'Post-funding observation'
    $feedbackVisible = Get-Rw062RequiredPublicProperty -InputObject $feedback -Name 'visible' -Context 'Post-funding feedback'
    $feedbackTitle = Get-Rw062RequiredPublicProperty -InputObject $feedback -Name 'title' -Context 'Post-funding feedback'
    $feedbackText = Get-Rw062RequiredPublicProperty -InputObject $feedback -Name 'text' -Context 'Post-funding feedback'
    if ($feedbackVisible -isnot [bool] -or -not [bool]$feedbackVisible -or
        $feedbackTitle -isnot [string] -or [string]$feedbackTitle -cne 'Result' -or
        $feedbackText -isnot [string] -or [string]::IsNullOrWhiteSpace([string]$feedbackText)) {
        throw 'Funding result has no exact fully rendered Result feedback.'
    }
    $termsSummary = Get-Rw062RequiredPublicProperty -InputObject $Offer -Name 'terms_summary' -Context 'Funding offer'
    if ($termsSummary -isnot [string] -or [string]::IsNullOrWhiteSpace([string]$termsSummary)) {
        throw 'Funding offer has no exact rendered terms to bind to its result.'
    }
    $termsPattern = [regex]::Escape([string]$termsSummary)
    if ([regex]::Matches([string]$feedbackText, $termsPattern, [Text.RegularExpressions.RegexOptions]::CultureInvariant).Count -ne 1) {
        throw 'Funding Result feedback does not contain the exact disclosed terms exactly once.'
    }
    $tailPattern = "$termsPattern  \$\+$([int]$principal)(?: / Heat [+-][1-9][0-9]*)?$"
    if ([string]$feedbackText -cnotmatch $tailPattern) {
        throw 'Funding Result feedback does not bind the exact disclosed terms to the exact positive bankroll delta.'
    }
    return $true
}

function Select-GrandFareCashEventChoice {
    param(
        [Parameter(Mandatory = $true)][string]$EventId,
        [Parameter(Mandatory = $true)]$EventObject,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$RoomActions,
        [Parameter(Mandatory = $true)]$Talk,
        [Parameter(Mandatory = $true)][string]$WorldNodeId,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$ResolvedEventKeys
    )

    if ($WorldNodeId -cnotmatch '^[a-z0-9_]+$') {
        throw 'Grand fare cash recovery requires one stable public world-node id.'
    }
    $talkVisible = Get-Rw062RequiredPublicProperty -InputObject $Talk -Name 'visible' -Context 'Cash-event TalkDock'
    if ($talkVisible -isnot [bool] -or [bool]$talkVisible) {
        throw 'Grand fare cash recovery refuses a visible, missing, or non-boolean TalkDock state.'
    }

    $choiceId = ''
    $expectedObjectLabel = ''
    $expectedChoices = @()
    if ($EventId -ceq 'back_alley_offer') {
        $choiceId = 'take_cash'
        $expectedObjectLabel = 'Back Alley Offer'
        $expectedChoices = @(
            [pscustomobject]@{ id = 'take_cash'; label = 'Take the cash' },
            [pscustomobject]@{ id = 'walk'; label = 'Keep walking' }
        )
        $expectedResultText = 'Small cash. Small stain. Both travel light.'
    }
    elseif ($EventId -ceq 'scenario_wedding_overflow_hallway') {
        $choiceId = 'take_the_hallway_seat'
        $expectedObjectLabel = 'Hallway Table'
        $expectedChoices = @(
            [pscustomobject]@{ id = 'take_the_hallway_seat'; label = 'Take the hallway seat' },
            [pscustomobject]@{ id = 'step_over_the_coolers'; label = 'Step over the coolers' }
        )
        $expectedResultText = 'The wedding pays out to learn your face.'
    }
    else {
        throw "Grand fare cash recovery refuses unknown event '$EventId'."
    }

    $objectSemanticId = Get-Rw062RequiredPublicProperty -InputObject $EventObject -Name 'semantic_id' -Context "Cash event '$EventId' object"
    $objectLabel = Get-Rw062RequiredPublicProperty -InputObject $EventObject -Name 'label' -Context "Cash event '$EventId' object"
    $objectType = Get-Rw062RequiredPublicProperty -InputObject $EventObject -Name 'object_type' -Context "Cash event '$EventId' object"
    $objectEnabled = Get-Rw062RequiredPublicProperty -InputObject $EventObject -Name 'enabled' -Context "Cash event '$EventId' object"
    $objectRendered = Get-Rw062RequiredPublicProperty -InputObject $EventObject -Name 'rendered' -Context "Cash event '$EventId' object"
    if ($objectSemanticId -isnot [string] -or [string]$objectSemanticId -cne "event:$EventId" -or
        $objectLabel -isnot [string] -or [string]$objectLabel -cne $expectedObjectLabel -or
        $objectType -isnot [string] -or [string]$objectType -cne 'event' -or
        $objectEnabled -isnot [bool] -or -not [bool]$objectEnabled -or
        $objectRendered -isnot [bool] -or -not [bool]$objectRendered) {
        throw "Cash event '$EventId' object changed its exact rendered public identity or enabled state."
    }

    $eventKey = "$WorldNodeId|event:$EventId"
    if (@($ResolvedEventKeys | Where-Object { [string]$_ -ceq $eventKey }).Count -gt 0) {
        throw "Grand fare cash recovery refuses repeat use of '$eventKey'."
    }
    if ($RoomActions.Count -ne $expectedChoices.Count) {
        throw "Cash event '$EventId' changed its exact rendered action count."
    }
    $selectedAction = $null
    foreach ($expected in $expectedChoices) {
        $expectedActionId = "event_response:$EventId`:$($expected.id)"
        $matches = @($RoomActions | Where-Object {
            $idProperties = @(Get-Rw062ExactPublicPropertyMatches -InputObject $_ -Name 'emit_object_id')
            $idProperties.Count -eq 1 -and $idProperties[0].Value -is [string] -and [string]$idProperties[0].Value -ceq $expectedActionId
        })
        if ($matches.Count -ne 1) {
            throw "Cash event '$EventId' action '$($expected.id)' is missing or ambiguous."
        }
        $action = $matches[0]
        $enabled = Get-Rw062RequiredPublicProperty -InputObject $action -Name 'enabled' -Context "Cash event '$EventId/$($expected.id)'"
        $label = Get-Rw062RequiredPublicProperty -InputObject $action -Name 'label' -Context "Cash event '$EventId/$($expected.id)'"
        if ($enabled -isnot [bool] -or -not [bool]$enabled) {
            throw "Cash event '$EventId/$($expected.id)' is disabled or has a non-boolean enabled state."
        }
        if ($label -isnot [string] -or [string]$label -cne [string]$expected.label) {
            throw "Cash event '$EventId/$($expected.id)' changed its exact rendered action label."
        }
        if ([string]$expected.id -ceq $choiceId) {
            $selectedAction = $action
        }
    }
    if ($null -eq $selectedAction) {
        throw "Cash event '$EventId' did not resolve its allowlisted positive-cash action."
    }

    return [pscustomobject][ordered]@{
        event_key = $eventKey
        world_node_id = $WorldNodeId
        event_id = $EventId
        semantic_id = "event:$EventId"
        choice_id = $choiceId
        action = $selectedAction
        expected_result_text = $expectedResultText
    }
}


function Assert-GrandFareCashEventResult {
    param(
        [Parameter(Mandatory = $true)]$Event,
        [Parameter(Mandatory = $true)][int]$BeforeBankroll,
        [Parameter(Mandatory = $true)][int]$BeforeHeat,
        [Parameter(Mandatory = $true)]$BeforeFeedback,
        [Parameter(Mandatory = $true)]$AfterObservation
    )

    $eventId = Get-Rw062RequiredPublicProperty -InputObject $Event -Name 'event_id' -Context 'Cash-event selection'
    $choiceId = Get-Rw062RequiredPublicProperty -InputObject $Event -Name 'choice_id' -Context 'Cash-event selection'
    $expectedChoiceId = if ($eventId -is [string] -and [string]$eventId -ceq 'back_alley_offer') {
        'take_cash'
    }
    elseif ($eventId -is [string] -and [string]$eventId -ceq 'scenario_wedding_overflow_hallway') {
        'take_the_hallway_seat'
    }
    else {
        ''
    }
    if ([string]::IsNullOrWhiteSpace($expectedChoiceId) -or
        $choiceId -isnot [string] -or [string]$choiceId -cne $expectedChoiceId) {
        throw 'Cash-event result is not bound to one allowlisted visible positive-cash response.'
    }

    $eventPopup = Get-Rw062RequiredPublicProperty -InputObject $AfterObservation -Name 'event_popup' -Context 'Post-cash-event observation'
    $eventVisible = Get-Rw062RequiredPublicProperty -InputObject $eventPopup -Name 'visible' -Context 'Post-cash-event popup'
    $talk = Get-Rw062RequiredPublicProperty -InputObject $AfterObservation -Name 'talk' -Context 'Post-cash-event observation'
    $talkVisible = Get-Rw062RequiredPublicProperty -InputObject $talk -Name 'visible' -Context 'Post-cash-event TalkDock'
    if ($eventVisible -isnot [bool] -or [bool]$eventVisible -or
        $talkVisible -isnot [bool] -or [bool]$talkVisible) {
        throw 'Cash event remained visible or chained into another modal after its public action.'
    }

    $statusHud = Get-Rw062RequiredPublicProperty -InputObject $AfterObservation -Name 'status_hud' -Context 'Post-cash-event observation'
    $bankrollRendered = Get-Rw062RequiredPublicProperty -InputObject $statusHud -Name 'bankroll_rendered' -Context 'Post-cash-event status HUD'
    $heatRendered = Get-Rw062RequiredPublicProperty -InputObject $statusHud -Name 'heat_rendered' -Context 'Post-cash-event status HUD'
    $afterBankroll = Get-Rw062RequiredPublicProperty -InputObject $statusHud -Name 'bankroll' -Context 'Post-cash-event status HUD'
    $afterHeat = Get-Rw062RequiredPublicProperty -InputObject $statusHud -Name 'heat_level' -Context 'Post-cash-event status HUD'
    if ($bankrollRendered -isnot [bool] -or -not [bool]$bankrollRendered -or
        $heatRendered -isnot [bool] -or -not [bool]$heatRendered -or
        ($afterBankroll -isnot [int32] -and $afterBankroll -isnot [int64]) -or
        ($afterHeat -isnot [int32] -and $afterHeat -isnot [int64])) {
        throw 'Post-cash-event bankroll or heat is not an integral fully rendered HUD value.'
    }
    $bankrollDeltaLong = [long]$afterBankroll - [long]$BeforeBankroll
    if ($bankrollDeltaLong -le 0 -or $bankrollDeltaLong -gt [int]::MaxValue) {
        throw 'Cash event did not produce a supported strictly positive public HUD bankroll delta.'
    }
    $bankrollDelta = [int]$bankrollDeltaLong
    $heatDeltaLong = [long]$afterHeat - [long]$BeforeHeat
    if ($heatDeltaLong -le 0 -or $heatDeltaLong -gt [int]::MaxValue) {
        throw 'Cash event did not produce a supported strictly positive public HUD heat delta.'
    }
    $heatDelta = [int]$heatDeltaLong

    $feedback = Get-Rw062RequiredPublicProperty -InputObject $AfterObservation -Name 'feedback' -Context 'Post-cash-event observation'
    $feedbackVisible = Get-Rw062RequiredPublicProperty -InputObject $feedback -Name 'visible' -Context 'Post-cash-event feedback'
    $feedbackTitle = Get-Rw062RequiredPublicProperty -InputObject $feedback -Name 'title' -Context 'Post-cash-event feedback'
    $feedbackText = Get-Rw062RequiredPublicProperty -InputObject $feedback -Name 'text' -Context 'Post-cash-event feedback'
    if ($feedbackVisible -isnot [bool] -or -not [bool]$feedbackVisible -or
        $feedbackTitle -isnot [string] -or [string]$feedbackTitle -cne 'Result' -or
        $feedbackText -isnot [string] -or [string]::IsNullOrWhiteSpace([string]$feedbackText)) {
        throw 'Cash event has no exact fully rendered Result feedback.'
    }

    $beforeVisibleMatches = @(Get-Rw062ExactPublicPropertyMatches -InputObject $BeforeFeedback -Name 'visible')
    if ($beforeVisibleMatches.Count -ne 1 -or $beforeVisibleMatches[0].Value -isnot [bool]) {
        throw 'Cash event has no trustworthy pre-action feedback visibility witness.'
    }
    if ([bool]$beforeVisibleMatches[0].Value) {
        $beforeText = Get-Rw062RequiredPublicProperty -InputObject $BeforeFeedback -Name 'text' -Context 'Pre-cash-event feedback'
        if ($beforeText -isnot [string] -or [string]$beforeText -ceq [string]$feedbackText) {
            throw 'Cash event Result feedback is stale or lacks exact pre-action text.'
        }
    }

    $expectedResultText = Get-Rw062RequiredPublicProperty -InputObject $Event -Name 'expected_result_text' -Context 'Cash-event selection'
    if ($expectedResultText -isnot [string] -or [string]::IsNullOrWhiteSpace([string]$expectedResultText)) {
        throw 'Cash-event selection has no exact allowlisted result message.'
    }
    $expectedFeedback = '{0}  $+{1} / Heat +{2}' -f $expectedResultText, $bankrollDelta, $heatDelta
    if ([string]$feedbackText -cne $expectedFeedback) {
        throw 'Cash event Result feedback does not exactly bind the allowlisted choice message to the rendered HUD cash and heat deltas.'
    }
    return $true
}
