Set-StrictMode -Version Latest


function Get-Rw062EvidenceSeedPolicy {
    return [pscustomobject][ordered]@{
        fixed = [pscustomobject][ordered]@{
            clean = 'RW06-CLEAN-ROUTE-01'
            cheat = 'RW06-CHEAT-ROUTE-01'
            heist = 'RW06-HEIST-AUDIT-0002'
        }
        fresh_interactive = [pscustomobject][ordered]@{
            heist = 'RW06-HEIST-AUDIT-0000'
        }
    }
}


function Get-Rw062AdmissionValue {
    param(
        [AllowNull()]$InputObject,
        [Parameter(Mandatory = $true)][string[]]$Path,
        [AllowNull()]$Default = $null
    )
    $current = $InputObject
    foreach ($segment in $Path) {
        if ($null -eq $current) { return $Default }
        if ($current -is [Collections.IDictionary]) {
            $matches = @($current.Keys | Where-Object { [string]$_ -ceq $segment })
            if ($matches.Count -eq 0) { return $Default }
            if ($matches.Count -ne 1) { throw "Ambiguous exact admission property '$segment'." }
            $current = $current[$matches[0]]
        }
        else {
            $properties = @($current.PSObject.Properties | Where-Object { $_.Name -ceq $segment })
            if ($properties.Count -eq 0) { return $Default }
            if ($properties.Count -ne 1) { throw "Ambiguous exact admission property '$segment'." }
            $current = $properties[0].Value
        }
    }
    if ($null -eq $current) { return $Default }
    return $current
}


function Get-Rw062AdmissionValueNoEnumerate {
    param(
        [AllowNull()]$InputObject,
        [Parameter(Mandatory = $true)][string[]]$Path,
        [AllowNull()]$Default = $null
    )
    $current = $InputObject
    foreach ($segment in $Path) {
        if ($null -eq $current) {
            Write-Output -NoEnumerate $Default
            return
        }
        if ($current -is [Collections.IDictionary]) {
            $matches = @($current.Keys | Where-Object { [string]$_ -ceq $segment })
            if ($matches.Count -eq 0) {
                Write-Output -NoEnumerate $Default
                return
            }
            if ($matches.Count -ne 1) { throw "Ambiguous exact admission property '$segment'." }
            $current = $current[$matches[0]]
        }
        else {
            $properties = @($current.PSObject.Properties | Where-Object { $_.Name -ceq $segment })
            if ($properties.Count -eq 0) {
                Write-Output -NoEnumerate $Default
                return
            }
            if ($properties.Count -ne 1) { throw "Ambiguous exact admission property '$segment'." }
            $current = $properties[0].Value
        }
    }
    if ($null -eq $current) {
        Write-Output -NoEnumerate $Default
        return
    }
    # A normal PowerShell function return enumerates an empty array into no
    # output. Preserve it so present-empty, missing, and null remain distinct.
    Write-Output -NoEnumerate $current
}


function Assert-Rw062NoScenarioAuthorityFields {
    param([AllowNull()]$InputObject)
    if ($null -eq $InputObject -or $InputObject -is [string] -or
        $InputObject -is [bool] -or $InputObject -is [ValueType]) {
        return
    }
    if ($InputObject -is [Collections.IEnumerable] -and
        $InputObject -isnot [Collections.IDictionary] -and
        $InputObject -isnot [pscustomobject]) {
        foreach ($item in $InputObject) {
            Assert-Rw062NoScenarioAuthorityFields -InputObject $item
        }
        return
    }
    $properties = if ($InputObject -is [Collections.IDictionary]) {
        @($InputObject.Keys | ForEach-Object {
            [pscustomobject]@{ Name = [string]$_; Value = $InputObject[$_] }
        })
    }
    else {
        @($InputObject.PSObject.Properties)
    }
    foreach ($property in $properties) {
        $propertyName = [string]$property.Name
        $normalizedPropertyName = [regex]::Replace(
            $propertyName,
            '[^A-Za-z0-9]',
            ''
        ).ToLowerInvariant()
        if ($normalizedPropertyName -match '^(?:scenario(?:pin|pins|pinned|idoverride|override|injected|injection|injectionallowed|injectionused|force|forced|debug)|(?:pinned|forced|force|injected|debug)scenario|tutorial(?:scenario)?overrides?|planb(?:allowed|used)?|whaleplan|planwhale)$') {
            throw "Fresh-interactive admission contains forbidden scenario/plan authority '$($property.Name)'."
        }
        Assert-Rw062NoScenarioAuthorityFields -InputObject $property.Value
    }
}


function Assert-Rw062ExactPropertyNames {
    param(
        [Parameter(Mandatory = $true)]$InputObject,
        [Parameter(Mandatory = $true)][string[]]$Expected,
        [Parameter(Mandatory = $true)][string]$Label
    )
    if ($null -eq $InputObject -or $InputObject -is [string] -or
        $InputObject -is [ValueType] -or
        ($InputObject -is [Collections.IEnumerable] -and
            $InputObject -isnot [Collections.IDictionary])) {
        throw "$Label must be an exact object."
    }
    $actual = if ($InputObject -is [Collections.IDictionary]) {
        @($InputObject.Keys | ForEach-Object { [string]$_ })
    }
    else {
        @($InputObject.PSObject.Properties | ForEach-Object { [string]$_.Name })
    }
    if ($actual.Count -ne $Expected.Count) {
        throw "$Label property count drifted: expected $($Expected.Count), observed $($actual.Count)."
    }
    foreach ($name in $Expected) {
        if (@($actual | Where-Object { $_ -ceq $name }).Count -ne 1) {
            throw "$Label is missing exact property '$name'."
        }
    }
}


function Test-Rw062ExactNullProperty {
    param(
        [Parameter(Mandatory = $true)]$InputObject,
        [Parameter(Mandatory = $true)][string]$Name
    )
    if ($InputObject -is [Collections.IDictionary]) {
        $matches = @($InputObject.Keys | Where-Object { [string]$_ -ceq $Name })
        return ($matches.Count -eq 1 -and $null -eq $InputObject[$matches[0]])
    }
    $properties = @($InputObject.PSObject.Properties | Where-Object { $_.Name -ceq $Name })
    return ($properties.Count -eq 1 -and $null -eq $properties[0].Value)
}


function Test-Rw062IntegralValue {
    param([AllowNull()]$Value)
    return ($Value -is [int32] -or $Value -is [int64])
}


function Test-Rw062ExactStringArray {
    param(
        [AllowNull()]$Value,
        [Parameter(Mandatory = $true)][string[]]$Expected
    )
    if ($null -eq $Value -or $Value -isnot [Array]) {
        return $false
    }
    $actual = @($Value)
    if ($actual.Count -ne $Expected.Count) { return $false }
    for ($index = 0; $index -lt $Expected.Count; $index++) {
        if ($actual[$index] -isnot [string] -or
            [string]$actual[$index] -cne [string]$Expected[$index]) {
            return $false
        }
    }
    return $true
}


function Resolve-Rw062ReplayAdmission {
    param(
        [Parameter(Mandatory = $true)][string]$Ending,
        [Parameter(Mandatory = $true)][string]$EvidenceRole,
        [AllowEmptyString()][string]$Seed,
        [Parameter(Mandatory = $true)][int]$Repeat
    )
    if ($Ending -cnotin @('clean', 'cheat', 'heist')) {
        throw "Unsupported exact ending '$Ending'."
    }
    if ($EvidenceRole -cnotin @('fixed-repeat', 'fresh-interactive')) {
        throw "Unsupported exact evidence role '$EvidenceRole'."
    }
    if ($Repeat -lt 1 -or $Repeat -gt 2) {
        throw "Replay repeat count '$Repeat' is outside the supported 1..2 range."
    }

    $policy = Get-Rw062EvidenceSeedPolicy
    $resolvedSeed = [string]$Seed
    if ($EvidenceRole -ceq 'fresh-interactive') {
        if ($Ending -cne 'heist') {
            throw 'Q-017A fresh-interactive admission is currently scoped only to the Heist ending.'
        }
        if ($Repeat -ne 1) {
            throw 'Q-017A fresh-interactive admission requires exactly one run.'
        }
        if ([string]::IsNullOrWhiteSpace($resolvedSeed)) {
            throw 'Q-017A fresh-interactive admission requires the explicit separately preflighted seed.'
        }
        $authorizedFreshSeed = [string](Get-Rw062AdmissionValue $policy @('fresh_interactive', 'heist') '')
        if ($resolvedSeed -cne $authorizedFreshSeed) {
            throw "Q-017A fresh-interactive admission accepts only separately preflighted seed '$authorizedFreshSeed'."
        }
        return [pscustomobject][ordered]@{
            evidence_role = 'fresh-interactive'
            ending = 'heist'
            seed = $authorizedFreshSeed
            repeat = 1
            route_plan = 'count'
            expected_initial_scenario = 'grand_casino_audit_night'
            scenario_authority = 'natural_fresh_profile_first_arrival_preflight'
            scenario_injection_allowed = $false
            plan_b_allowed = $false
            requires_isolated_profile = $true
            release_qualifying = $false
            qualification_authority = 'post_run_interactive_review_only'
            owner_decisions = @('Q-013A', 'Q-017A')
        }
    }

    if ([string]::IsNullOrWhiteSpace($resolvedSeed)) {
        $resolvedSeed = [string](Get-Rw062AdmissionValue $policy @('fixed', $Ending) '')
    }
    $fixedHeistSeed = [string](Get-Rw062AdmissionValue $policy @('fixed', 'heist') '')
    if ($Ending -ceq 'heist' -and $resolvedSeed -cne $fixedHeistSeed) {
        throw "Q-013A fixed-repeat Heist evidence requires exact seed '$fixedHeistSeed'."
    }
    $fixedOwnerDecisions = [string[]]@()
    if ($Ending -ceq 'heist') {
        $fixedOwnerDecisions = [string[]]@('Q-013A', 'Q-017A')
    }
    return [pscustomobject][ordered]@{
        evidence_role = 'fixed-repeat'
        ending = $Ending
        seed = $resolvedSeed
        repeat = $Repeat
        route_plan = if ($Ending -ceq 'heist') { 'count' } else { '' }
        expected_initial_scenario = if ($Ending -ceq 'heist') { 'grand_casino_audit_night' } else { '' }
        scenario_authority = if ($Ending -ceq 'heist') { 'natural_fresh_profile_first_arrival_preflight' } else { 'route_seed' }
        scenario_injection_allowed = $false
        plan_b_allowed = $false
        requires_isolated_profile = $true
        release_qualifying = $false
        qualification_authority = 'outer_independent_profile_aggregate_only'
        owner_decisions = $fixedOwnerDecisions
    }
}


function Assert-Rw062HeistPreflightAdmission {
    param(
        [Parameter(Mandatory = $true)]$Admission,
        [Parameter(Mandatory = $true)]$Report
    )
    Assert-Rw062ExactPropertyNames -InputObject $Admission -Label 'Heist replay admission' -Expected @(
        'evidence_role', 'ending', 'seed', 'repeat', 'route_plan',
        'expected_initial_scenario', 'scenario_authority', 'scenario_injection_allowed',
        'plan_b_allowed', 'requires_isolated_profile', 'release_qualifying',
        'qualification_authority', 'owner_decisions'
    )
    Assert-Rw062ExactPropertyNames -InputObject $Report -Label 'Heist preflight report' -Expected @(
        'contract', 'passed', 'expected_scenario', 'selection', 'fresh_interactive_selection',
        'launch_model', 'serialization_calibration', 'arrival_history_hostile',
        'owner_decisions', 'valid_fixtures', 'hostile_fixtures', 'failures'
    )
    $selectionObject = Get-Rw062AdmissionValueNoEnumerate $Report @('selection') $null
    $launchModelObject = Get-Rw062AdmissionValueNoEnumerate $Report @('launch_model') $null
    Assert-Rw062ExactPropertyNames -InputObject $selectionObject -Label 'Heist preflight selection' -Expected @(
        'seed_text', 'challenge_key', 'run_seed', 'cycle_id', 'stream_key', 'stream_seed',
        'none_roll', 'none_percent', 'absolute_minutes', 'recent_scenario_ids',
        'town_multiplier', 'weighted_entries', 'total_weight', 'weighted_roll',
        'selected_scenario'
    )
    Assert-Rw062ExactPropertyNames -InputObject $launchModelObject -Label 'Heist preflight launch model' -Expected @(
        'screen', 'run_config', 'selected_challenge', 'selected_home',
        'selected_content_groups', 'challenge_mode', 'challenge_id',
        'fresh_profile_modifier_text', 'start_absolute_minutes',
        'first_arrival_recent_scenario_ids'
    )
    Assert-Rw062NoScenarioAuthorityFields -InputObject $Report

    $role = Get-Rw062AdmissionValueNoEnumerate $Admission @('evidence_role') $null
    $ending = Get-Rw062AdmissionValueNoEnumerate $Admission @('ending') $null
    $seed = Get-Rw062AdmissionValueNoEnumerate $Admission @('seed') $null
    $repeat = Get-Rw062AdmissionValueNoEnumerate $Admission @('repeat') $null
    $routePlan = Get-Rw062AdmissionValueNoEnumerate $Admission @('route_plan') $null
    $expectedInitialScenario = Get-Rw062AdmissionValueNoEnumerate $Admission @('expected_initial_scenario') $null
    $scenarioAuthority = Get-Rw062AdmissionValueNoEnumerate $Admission @('scenario_authority') $null
    $scenarioInjectionAllowed = Get-Rw062AdmissionValueNoEnumerate $Admission @('scenario_injection_allowed') $null
    $planBAllowed = Get-Rw062AdmissionValueNoEnumerate $Admission @('plan_b_allowed') $null
    $requiresIsolatedProfile = Get-Rw062AdmissionValueNoEnumerate $Admission @('requires_isolated_profile') $null
    $releaseQualifying = Get-Rw062AdmissionValueNoEnumerate $Admission @('release_qualifying') $null
    $qualificationAuthority = Get-Rw062AdmissionValueNoEnumerate $Admission @('qualification_authority') $null
    $admissionOwnerDecisions = Get-Rw062AdmissionValueNoEnumerate $Admission @('owner_decisions') $null
    if ($role -isnot [string] -or $role -cnotin @('fixed-repeat', 'fresh-interactive') -or
        $ending -isnot [string] -or $ending -cne 'heist' -or
        $seed -isnot [string]) {
        throw 'Heist preflight admission string identity fields are not exact strings.'
    }
    $expectedQualificationAuthority = if ($role -ceq 'fresh-interactive') {
        'post_run_interactive_review_only'
    }
    else {
        'outer_independent_profile_aggregate_only'
    }
    if ($repeat -isnot [int32] -or [int]$repeat -lt 1 -or [int]$repeat -gt 2 -or
        ($role -ceq 'fresh-interactive' -and [int]$repeat -ne 1) -or
        $routePlan -isnot [string] -or [string]$routePlan -cne 'count' -or
        $expectedInitialScenario -isnot [string] -or [string]$expectedInitialScenario -cne 'grand_casino_audit_night' -or
        $scenarioAuthority -isnot [string] -or [string]$scenarioAuthority -cne 'natural_fresh_profile_first_arrival_preflight' -or
        $scenarioInjectionAllowed -isnot [bool] -or [bool]$scenarioInjectionAllowed -or
        $planBAllowed -isnot [bool] -or [bool]$planBAllowed -or
        $requiresIsolatedProfile -isnot [bool] -or -not [bool]$requiresIsolatedProfile -or
        $releaseQualifying -isnot [bool] -or [bool]$releaseQualifying -or
        $qualificationAuthority -isnot [string] -or [string]$qualificationAuthority -cne $expectedQualificationAuthority -or
        -not (Test-Rw062ExactStringArray $admissionOwnerDecisions @('Q-013A', 'Q-017A'))) {
        throw 'Heist preflight admission received an invalid exact role/ending/repeat tuple.'
    }

    $expected = if ($role -ceq 'fresh-interactive') {
        [pscustomobject]@{
            seed = 'RW06-HEIST-AUDIT-0000'
            run_seed = 1262406216L
            stream_seed = 501255064L
            none_roll = 96
            total_weight = 26000
            weighted_roll = 22402
        }
    }
    else {
        [pscustomobject]@{
            seed = 'RW06-HEIST-AUDIT-0002'
            run_seed = 919325714L
            stream_seed = 1392077385L
            none_roll = 59
            total_weight = 26000
            weighted_roll = 24088
        }
    }
    if ($seed -cne [string]$expected.seed) {
        throw "Heist admission seed '$seed' does not match the exact $role witness '$($expected.seed)'."
    }

    $contract = Get-Rw062AdmissionValueNoEnumerate $Report @('contract') $null
    $expectedScenario = Get-Rw062AdmissionValueNoEnumerate $Report @('expected_scenario') $null
    $reportOwnerDecisions = Get-Rw062AdmissionValueNoEnumerate $Report @('owner_decisions') $null
    $validFixtures = Get-Rw062AdmissionValueNoEnumerate $Report @('valid_fixtures') $null
    $hostileFixtures = Get-Rw062AdmissionValueNoEnumerate $Report @('hostile_fixtures') $null
    $passed = Get-Rw062AdmissionValueNoEnumerate $Report @('passed') $null
    $reportedSeed = Get-Rw062AdmissionValueNoEnumerate $Report @('selection', 'seed_text') $null
    $challengeKey = Get-Rw062AdmissionValueNoEnumerate $Report @('selection', 'challenge_key') $null
    $selectedScenario = Get-Rw062AdmissionValueNoEnumerate $Report @('selection', 'selected_scenario') $null
    $cycleId = Get-Rw062AdmissionValueNoEnumerate $Report @('selection', 'cycle_id') $null
    $streamKey = Get-Rw062AdmissionValueNoEnumerate $Report @('selection', 'stream_key') $null
    $runSeed = Get-Rw062AdmissionValueNoEnumerate $Report @('selection', 'run_seed') $null
    $streamSeed = Get-Rw062AdmissionValueNoEnumerate $Report @('selection', 'stream_seed') $null
    $noneRoll = Get-Rw062AdmissionValueNoEnumerate $Report @('selection', 'none_roll') $null
    $nonePercent = Get-Rw062AdmissionValueNoEnumerate $Report @('selection', 'none_percent') $null
    $absoluteMinutes = Get-Rw062AdmissionValueNoEnumerate $Report @('selection', 'absolute_minutes') $null
    $totalWeight = Get-Rw062AdmissionValueNoEnumerate $Report @('selection', 'total_weight') $null
    $weightedRoll = Get-Rw062AdmissionValueNoEnumerate $Report @('selection', 'weighted_roll') $null
    $recentScenarioIdsRaw = Get-Rw062AdmissionValueNoEnumerate $Report @('selection', 'recent_scenario_ids') '__missing_recent_scenario_ids__'
    $townMultiplier = Get-Rw062AdmissionValueNoEnumerate $Report @('selection', 'town_multiplier') $null
    $weightedEntriesRaw = Get-Rw062AdmissionValueNoEnumerate $Report @('selection', 'weighted_entries') $null
    $failuresRaw = Get-Rw062AdmissionValueNoEnumerate $Report @('failures') '__missing_failures__'
    $modifierText = 'home_archetype_id=back_alley;meta_collection_carried_instance_ids=[];meta_collection_containers=[{ "id": "meta_bag_01", "item_id": "bag", "capacity": 3, "items": [], "item_definitions": {  }, "meta_loadout": true, "meta_container_instance_id": 0 }];meta_collection_enabled=true;meta_collection_loadout=[]'
    $expectedChallengeKey = "standard|standard|$($expected.seed)|$modifierText"
    if ($contract -isnot [string] -or [string]$contract -cne 'rw06_2_heist_seed_preflight' -or
        -not (Test-Rw062ExactNullProperty $Report 'fresh_interactive_selection') -or
        -not (Test-Rw062ExactNullProperty $Report 'serialization_calibration') -or
        -not (Test-Rw062ExactNullProperty $Report 'arrival_history_hostile') -or
        $expectedScenario -isnot [string] -or [string]$expectedScenario -cne 'grand_casino_audit_night' -or
        -not (Test-Rw062ExactStringArray $reportOwnerDecisions @('Q-013A', 'Q-017A')) -or
        -not (Test-Rw062IntegralValue $validFixtures) -or [int64]$validFixtures -ne 1 -or
        -not (Test-Rw062IntegralValue $hostileFixtures) -or [int64]$hostileFixtures -ne 0 -or
        $passed -isnot [bool] -or -not [bool]$passed -or
        $reportedSeed -isnot [string] -or [string]$reportedSeed -cne [string]$expected.seed -or
        $challengeKey -isnot [string] -or [string]$challengeKey -cne $expectedChallengeKey -or
        $selectedScenario -isnot [string] -or [string]$selectedScenario -cne 'grand_casino_audit_night' -or
        $cycleId -isnot [string] -or [string]$cycleId -cne 'day:0' -or
        $streamKey -isnot [string] -or [string]$streamKey -cne 'environment_situation:grand_casino:day:0' -or
        -not (Test-Rw062IntegralValue $runSeed) -or [int64]$runSeed -ne [int64]$expected.run_seed -or
        -not (Test-Rw062IntegralValue $streamSeed) -or [int64]$streamSeed -ne [int64]$expected.stream_seed -or
        -not (Test-Rw062IntegralValue $noneRoll) -or [int64]$noneRoll -ne [int64]$expected.none_roll -or
        -not (Test-Rw062IntegralValue $nonePercent) -or [int64]$nonePercent -ne 25 -or
        -not (Test-Rw062IntegralValue $absoluteMinutes) -or [int64]$absoluteMinutes -ne 720 -or
        -not (Test-Rw062IntegralValue $totalWeight) -or [int64]$totalWeight -ne [int64]$expected.total_weight -or
        -not (Test-Rw062IntegralValue $weightedRoll) -or [int64]$weightedRoll -ne [int64]$expected.weighted_roll -or
        $recentScenarioIdsRaw -isnot [object[]] -or $recentScenarioIdsRaw.Count -ne 0 -or
        -not (Test-Rw062IntegralValue $townMultiplier) -or [int64]$townMultiplier -ne 1 -or
        $weightedEntriesRaw -isnot [object[]] -or
        $failuresRaw -isnot [object[]] -or $failuresRaw.Count -ne 0) {
        throw "Heist $role preflight did not preserve its exact natural first-arrival Audit witness."
    }
    $expectedWeightedEntries = @(
        [pscustomobject]@{ id = 'grand_casino_gala_night'; weight = 8000; ceiling = 8000 },
        [pscustomobject]@{ id = 'grand_casino_convention_crowd'; weight = 11000; ceiling = 19000 },
        [pscustomobject]@{ id = 'grand_casino_audit_night'; weight = 7000; ceiling = 26000 }
    )
    if ($weightedEntriesRaw.Count -ne $expectedWeightedEntries.Count) {
        throw "Heist $role preflight weighted-entry count drifted from the exact production witness."
    }
    for ($index = 0; $index -lt $expectedWeightedEntries.Count; $index++) {
        $entry = $weightedEntriesRaw[$index]
        $expectedEntry = $expectedWeightedEntries[$index]
        Assert-Rw062ExactPropertyNames -InputObject $entry -Label "Heist preflight weighted entry $index" -Expected @(
            'id', 'repeat_multiplier', 'town_multiplier', 'scaled_weight', 'ceiling'
        )
        $entryId = Get-Rw062AdmissionValueNoEnumerate $entry @('id') $null
        $repeatMultiplier = Get-Rw062AdmissionValueNoEnumerate $entry @('repeat_multiplier') $null
        $entryTownMultiplier = Get-Rw062AdmissionValueNoEnumerate $entry @('town_multiplier') $null
        $scaledWeight = Get-Rw062AdmissionValueNoEnumerate $entry @('scaled_weight') $null
        $ceiling = Get-Rw062AdmissionValueNoEnumerate $entry @('ceiling') $null
        if ($entryId -isnot [string] -or [string]$entryId -cne [string]$expectedEntry.id -or
            -not (Test-Rw062IntegralValue $repeatMultiplier) -or [int64]$repeatMultiplier -ne 1 -or
            -not (Test-Rw062IntegralValue $entryTownMultiplier) -or [int64]$entryTownMultiplier -ne 1 -or
            -not (Test-Rw062IntegralValue $scaledWeight) -or [int64]$scaledWeight -ne [int64]$expectedEntry.weight -or
            -not (Test-Rw062IntegralValue $ceiling) -or [int64]$ceiling -ne [int64]$expectedEntry.ceiling) {
            throw "Heist $role preflight weighted entry $index drifted from the exact production witness."
        }
    }

    $screen = Get-Rw062AdmissionValueNoEnumerate $Report @('launch_model', 'screen') $null
    $runConfig = Get-Rw062AdmissionValueNoEnumerate $Report @('launch_model', 'run_config') $null
    $selectedChallenge = Get-Rw062AdmissionValueNoEnumerate $Report @('launch_model', 'selected_challenge') $null
    $selectedHome = Get-Rw062AdmissionValueNoEnumerate $Report @('launch_model', 'selected_home') $null
    $challengeMode = Get-Rw062AdmissionValueNoEnumerate $Report @('launch_model', 'challenge_mode') $null
    $challengeId = Get-Rw062AdmissionValueNoEnumerate $Report @('launch_model', 'challenge_id') $null
    $reportedModifierText = Get-Rw062AdmissionValueNoEnumerate $Report @('launch_model', 'fresh_profile_modifier_text') $null
    $startAbsoluteMinutes = Get-Rw062AdmissionValueNoEnumerate $Report @('launch_model', 'start_absolute_minutes') $null
    $contentGroupsRaw = Get-Rw062AdmissionValueNoEnumerate $Report @('launch_model', 'selected_content_groups') $null
    $firstArrivalRecentRaw = Get-Rw062AdmissionValueNoEnumerate $Report @('launch_model', 'first_arrival_recent_scenario_ids') '__missing_first_arrival_recent_scenario_ids__'
    $expectedContentGroups = @(
        'universal_passive_items', 'universal_active_items', 'scratch_tickets_pack',
        'pull_tabs_pack', 'slot_pack', 'coin_pusher_pack', 'bar_dice_pack',
        'craps_pack', 'crew_poker_pack', 'blackjack_pack', 'baccarat_pack',
        'roulette_pack', 'video_poker_pack', 'numbers_pack'
    )
    if ($screen -isnot [string] -or [string]$screen -cne 'START' -or
        $runConfig -isnot [bool] -or -not [bool]$runConfig -or
        $selectedChallenge -isnot [string] -or [string]$selectedChallenge -cne '' -or
        $selectedHome -isnot [string] -or [string]$selectedHome -cne 'random' -or
        $challengeMode -isnot [string] -or [string]$challengeMode -cne 'standard' -or
        $challengeId -isnot [string] -or [string]$challengeId -cne 'standard' -or
        $reportedModifierText -isnot [string] -or [string]$reportedModifierText -cne $modifierText -or
        -not (Test-Rw062IntegralValue $startAbsoluteMinutes) -or [int64]$startAbsoluteMinutes -ne 720 -or
        -not (Test-Rw062ExactStringArray $contentGroupsRaw $expectedContentGroups) -or
        $firstArrivalRecentRaw -isnot [object[]] -or
        $firstArrivalRecentRaw.Count -ne 0) {
        throw "Heist $role preflight did not preserve fresh Standard/Random/default-content admission."
    }
    return [pscustomobject][ordered]@{
        evidence_role = $role
        ending = 'heist'
        seed = $seed
        route_plan = 'count'
        selected_scenario = 'grand_casino_audit_night'
        cycle_id = 'day:0'
        run_seed = [int64]$runSeed
        stream_seed = [int64]$streamSeed
        none_roll = [int]$noneRoll
        total_weight = [int]$totalWeight
        weighted_roll = [int]$weightedRoll
        natural_first_arrival = $true
        scenario_injection_used = $false
        plan_b_used = $false
    }
}
