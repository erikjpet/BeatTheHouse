[CmdletBinding()]
param(
    [ValidatePattern('^[A-Za-z0-9_-]+$')]
    [string]$SeedText = 'RW06-HEIST-AUDIT-0002',
    [ValidatePattern('^[a-z0-9_]+$')]
    [string]$ExpectedScenario = 'grand_casino_audit_night',
    [switch]$Contract,
    [string]$ReportPath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Worktree = Split-Path -Parent $PSScriptRoot
$RunStatePath = Join-Path $Worktree 'scripts\core\run_state.gd'
$RngStreamPath = Join-Path $Worktree 'scripts\core\rng_stream.gd'
$RunGeneratorPath = Join-Path $Worktree 'scripts\core\run_generator.gd'
$EnvironmentHoursPath = Join-Path $Worktree 'scripts\core\environment_hours.gd'
$FoundationMainPath = Join-Path $Worktree 'scripts\ui\foundation_main.gd'
$MetaCollectionPath = Join-Path $Worktree 'scripts\core\meta_collection_service.gd'
$TownStatePath = Join-Path $Worktree 'scripts\core\town_state.gd'
$PoliceSweepPath = Join-Path $Worktree 'scripts\core\police_sweep_model.gd'
$CharacterChainPath = Join-Path $Worktree 'scripts\core\character_chain_model.gd'
$ArchetypesPath = Join-Path $Worktree 'data\environments\archetypes.json'
$ScenariosPath = Join-Path $Worktree 'data\environments\scenarios.json'
$TownConditionsPath = Join-Path $Worktree 'data\town\conditions.json'

$FreshProfileModifierText = 'home_archetype_id=back_alley;meta_collection_carried_instance_ids=[];meta_collection_containers=[{ "id": "meta_bag_01", "item_id": "bag", "capacity": 3, "items": [], "item_definitions": {  }, "meta_loadout": true, "meta_container_instance_id": 0 }];meta_collection_enabled=true;meta_collection_loadout=[]'
$FreshProfileContentGroups = @(
    'universal_passive_items', 'universal_active_items', 'scratch_tickets_pack',
    'pull_tabs_pack', 'slot_pack', 'coin_pusher_pack', 'bar_dice_pack',
    'craps_pack', 'crew_poker_pack', 'blackjack_pack', 'baccarat_pack',
    'roulette_pack', 'video_poker_pack', 'numbers_pack'
)


function Assert-Rw062SourcePattern {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Pattern,
        [Parameter(Mandatory = $true)][string]$Message
    )
    if (-not [regex]::IsMatch(
        $Source,
        $Pattern,
        [Text.RegularExpressions.RegexOptions]::Multiline -bor
            [Text.RegularExpressions.RegexOptions]::Singleline -bor
            [Text.RegularExpressions.RegexOptions]::CultureInvariant
    )) {
        throw $Message
    }
}


function Get-Rw062ExactProperty {
    param(
        [Parameter(Mandatory = $true)]$InputObject,
        [Parameter(Mandatory = $true)][string]$Name
    )
    $matches = @($InputObject.PSObject.Properties | Where-Object { $_.Name -ceq $Name })
    if ($matches.Count -ne 1) {
        throw "Expected one exact '$Name' property; found $($matches.Count)."
    }
    return $matches[0].Value
}


function Get-Rw062OptionalProperty {
    param(
        [Parameter(Mandatory = $true)]$InputObject,
        [Parameter(Mandatory = $true)][string]$Name,
        [AllowNull()]$Default = $null
    )
    $matches = @($InputObject.PSObject.Properties | Where-Object { $_.Name -ceq $Name })
    if ($matches.Count -gt 1) {
        throw "Property '$Name' is ambiguous."
    }
    if ($matches.Count -eq 0) { return $Default }
    return $matches[0].Value
}


function Get-Rw062ScenarioWeightTables {
    param([AllowNull()]$InputObject)

    if ($null -eq $InputObject -or $InputObject -is [string] -or
        $InputObject -is [bool] -or $InputObject -is [ValueType]) {
        return
    }
    if ($InputObject -is [Collections.IEnumerable] -and $InputObject -isnot [pscustomobject]) {
        foreach ($item in $InputObject) {
            Get-Rw062ScenarioWeightTables -InputObject $item
        }
        return
    }
    foreach ($property in @($InputObject.PSObject.Properties)) {
        if ($property.Name -cin @(
            'scenario_weight_by_archetype',
            'scenario_weight_by_id',
            'scenario_weight_by_tag'
        )) {
            [pscustomobject]@{
                kind = [string]$property.Name
                value = $property.Value
            }
        }
        Get-Rw062ScenarioWeightTables -InputObject $property.Value
    }
}


function Get-Rw062ProductionScenarioContract {
    foreach ($path in @(
        $RunStatePath, $RngStreamPath, $RunGeneratorPath,
        $EnvironmentHoursPath, $FoundationMainPath, $MetaCollectionPath,
        $TownStatePath, $PoliceSweepPath, $CharacterChainPath,
        $ArchetypesPath, $ScenariosPath, $TownConditionsPath
    )) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "Heist seed preflight source is missing: $path"
        }
    }

    $runState = Get-Content -LiteralPath $RunStatePath -Raw
    $rngStream = Get-Content -LiteralPath $RngStreamPath -Raw
    $runGenerator = Get-Content -LiteralPath $RunGeneratorPath -Raw
    $environmentHours = Get-Content -LiteralPath $EnvironmentHoursPath -Raw
    $foundationMain = Get-Content -LiteralPath $FoundationMainPath -Raw
    $metaCollection = Get-Content -LiteralPath $MetaCollectionPath -Raw
    $townState = Get-Content -LiteralPath $TownStatePath -Raw
    $policeSweep = Get-Content -LiteralPath $PoliceSweepPath -Raw
    $characterChain = Get-Content -LiteralPath $CharacterChainPath -Raw

    Assert-Rw062SourcePattern $runState 'seed_value\s*=\s*text_to_seed\(challenge_key\(challenge_config\)\)' 'RunState no longer derives the run seed through challenge_key/text_to_seed.'
    Assert-Rw062SourcePattern $runState 'static func text_to_seed\(text: String\).*?2166136261.*?hash_value\s*=\s*hash_value\s*\^\s*text\.unicode_at\(index\).*?16777619.*?0x7fffffff.*?return max\(1, hash_value\)' 'RunState text seed algorithm drifted from the engine-free preflight.'
    Assert-Rw062SourcePattern $runState 'static func challenge_key\(config: Dictionary\).*?return "%s\|%s\|%s\|%s".*?mode.*?id.*?seed_text.*?_mods_text' 'RunState standard challenge-key serialization drifted from the preflight.'
    Assert-Rw062SourcePattern $runState 'static func _mods_text\(modifiers: Dictionary\).*?modifiers\.keys\(\).*?keys\.sort\(\).*?parts\.append\("%s=%s" % \[key, modifiers\[key\]\]\).*?";"\.join\(parts\)' 'RunState modifier serialization drifted from stable sorted Godot Variant text.'
    Assert-Rw062SourcePattern $runState 'const GAME_CLOCK_START_MINUTE\s*:=\s*\d+\s*\*\s*\d+' 'RunState no longer publishes a simple deterministic starting clock constant.'
    Assert-Rw062SourcePattern $runState 'func scenario_weight_multiplier\(archetype_id: String, scenario_id: String, tags: Array\).*?town_state\.scenario_weight_multiplier\(archetype_id, scenario_id, tags\) \* CharacterChainModelScript\.scenario_weight_multiplier\(self, archetype_id, scenario_id\)' 'RunState no longer composes TownState and CharacterChain scenario multipliers.'

    Assert-Rw062SourcePattern $foundationMain 'func _on_start_pressed\(\).*?start_foundation_run\(seed_text, _new_run_challenge_for_seed\(seed_text\)\)' 'The visible seeded-run button no longer uses the normal new-run challenge path.'
    Assert-Rw062SourcePattern $foundationMain 'func start_foundation_run\(seed_text: String = DEFAULT_SEED, challenge_config: Dictionary = \{\}, include_meta_home_modifiers: bool = true\).*?_challenge_with_meta_home_for_run\(resolved_seed, challenge_config\).*?run_state\.start_new\(resolved_seed, resolved_challenge_config\)' 'Visible standard runs no longer merge meta-home modifiers before RunState seeding.'
    Assert-Rw062SourcePattern $foundationMain 'func _content_group_challenge_for_seed\(seed_text: String\).*?selected := _selected_content_groups_for_new_run\(\).*?defaults := library\.default_content_group_ids\(\).*?JSON\.stringify\(selected\) == JSON\.stringify\(defaults\).*?RunState\.standard_challenge\(seed_text\)' 'Default visible content groups no longer select the standard challenge.'
    Assert-Rw062SourcePattern $foundationMain 'func _challenge_with_home_selection\(seed_text: String, config: Dictionary\).*?HOME_SELECTION_RANDOM.*?modifiers\.erase\("home_archetype_id"\)' 'Random visible home selection no longer defers to the fresh meta-home modifier.'
    Assert-Rw062SourcePattern $foundationMain 'func _challenge_with_meta_home_for_run\(seed_text: String, config: Dictionary\).*?mode != "standard".*?normal_run_start_modifiers\(\).*?modifiers\[str\(key\)\] = meta_modifiers\[key\]' 'Standard-run fresh meta modifiers no longer merge through the production path.'
    Assert-Rw062SourcePattern $metaCollection 'func normal_run_start_modifiers\(\).*?"home_archetype_id".*?"meta_collection_enabled": true.*?"meta_collection_carried_instance_ids": carried_ids.*?"meta_collection_loadout": run_items.*?"meta_collection_containers": carried_container_rows\(\)' 'Fresh meta modifier construction drifted from the modeled launch key.'
    Assert-Rw062SourcePattern $metaCollection 'func carried_container_rows\(\).*?rows\.append\(\{.*?"id": "meta_%s_%02d".*?"item_id": item_id.*?"capacity": capacity.*?"items": item_ids.*?"item_definitions": item_definitions.*?"meta_loadout": true.*?"meta_container_instance_id"' 'Fresh carried-container field order drifted from the Godot Variant calibration.'
    Assert-Rw062SourcePattern $metaCollection 'func _default_store\(\).*?"owned_instances": \[\].*?"housing_tier": HOUSING_BACK_ALLEY.*?"owned_containers": \[\{"item_id": "bag", "instance_id": 0, "capacity": 3\}\].*?"loadout": \[\]' 'Fresh isolated profile defaults drifted from the modeled empty bag loadout.'

    Assert-Rw062SourcePattern $rngStream 'const MODULUS\s*:=\s*\d+.*?const MULTIPLIER\s*:=\s*\d+' 'RngStream constants are missing.'
    Assert-Rw062SourcePattern $rngStream 'func randi_range\(min_value: int, max_value: int\).*?var value\s*:=\s*_next\(\).*?return min_value \+ \(value % span\)' 'RngStream integer-range selection drifted from the preflight.'
    Assert-Rw062SourcePattern $rngStream 'static func derive_seed\(base_seed: int, base_state: int, stream_key: String\).*?"%s\|%s\|%s".*?value\s*=\s*value\s*\^\s*text\.unicode_at\(index\).*?value \* MULTIPLIER\) % MODULUS' 'RngStream fork derivation drifted from the preflight.'
    Assert-Rw062SourcePattern $rngStream 'func _next\(\).*?state_value\s*=\s*int\(\(state_value \* MULTIPLIER\) % MODULUS\)' 'RngStream next-state algorithm drifted from the preflight.'

    Assert-Rw062SourcePattern $runGenerator 'const ENVIRONMENT_SITUATION_NONE_PERCENT\s*:=\s*\d+' 'Scenario none-percent constant is missing.'
    Assert-Rw062SourcePattern $runGenerator 'func _prime_town_scenarios\(.*?node_ids\.sort\(\).*?_select_scenario\(run_state, node_id, scenario_rng, false\)' 'Town generation no longer primes sorted node scenarios through _select_scenario.'
    Assert-Rw062SourcePattern $runGenerator 'situation_rng\.configure\(run_state\.seed_value, run_state\.seed_value\).*?situation_rng\.fork\("environment_situation:%s:%s".*?randi_range\(1, 100\).*?ENVIRONMENT_SITUATION_NONE_PERCENT' 'Scenario stream identity or empty-situation roll drifted from the preflight.'
    Assert-Rw062SourcePattern $runGenerator 'var recent := run_state\.recent_scenario_ids\(archetype_id\).*?recent_index == 0.*?repeat_multiplier = 0\.0.*?recent_index == 1.*?repeat_multiplier = 0\.35.*?recent_index >= 2.*?repeat_multiplier = 0\.60' 'Scenario repeat suppression drifted from the preflight arrival-history model.'
    Assert-Rw062SourcePattern $runGenerator 'scaled_weight\s*:=\s*maxi\(0, int\(round\(float\(definition\.get\("weight", 1\.0\)\) \* repeat_multiplier \* town_multiplier \* 1000\.0\)\)\).*?randi_range\(1, total_weight\).*?roll <= int\(entry\.get\("ceiling"' 'Scenario weighted selection drifted from the preflight.'
    Assert-Rw062SourcePattern $environmentHours 'static func operating_cycle_id\(.*?hours\.is_empty\(\).*?return "day:%d".*?return "open:%d:%d"' 'Environment operating-cycle selection drifted from the preflight.'
    Assert-Rw062SourcePattern $townState 'func scenario_weight_multiplier\(archetype_id: String, scenario_id: String, tags: Array\).*?_scenario_weight_by_archetype\.get\(archetype_id, 1\.0\).*?_scenario_weight_by_id\.get\(scenario_id, 1\.0\).*?_scenario_weight_by_tag\.get\(str\(tag_value\), 1\.0\).*?police_sweep\s*!=\s*null.*?police_sweep\.scenario_pressure_multiplier\(archetype_id, scenario_id, tags\).*?return maxf\(0\.0, multiplier\)' 'TownState scenario multiplier composition drifted from the neutral Grand contract.'
    Assert-Rw062SourcePattern $policeSweep 'func scenario_pressure_multiplier\(node_id: String, scenario_id: String, tags: Array\).*?GRAND_CASINO_IDS\.has\(node_id\).*?return 1\.0' 'Police sweep no longer explicitly leaves Grand Casino scenario weights neutral.'
    Assert-Rw062SourcePattern $characterChain 'static func scenario_weight_multiplier\(run_state: RunState, archetype_id: String, scenario_id: String\).*?archetype_id == "pawn_shop".*?scenario_id == "pawn_shop_sals_mood".*?return maxf\(1\.0.*?return 1\.0' 'Character-chain scenario weighting is no longer isolated to Sal at the pawn shop.'

    $conditions = Get-Content -LiteralPath $TownConditionsPath -Raw | ConvertFrom-Json
    $weightTables = @(Get-Rw062ScenarioWeightTables -InputObject $conditions)
    foreach ($table in $weightTables) {
        $keys = @($table.value.PSObject.Properties | ForEach-Object { [string]$_.Name })
        if ([string]$table.kind -ceq 'scenario_weight_by_archetype' -and 'grand_casino' -cin $keys) {
            throw 'Town conditions gained a Grand Casino archetype multiplier; model it before trusting the seed witness.'
        }
        if ([string]$table.kind -ceq 'scenario_weight_by_id' -and @($keys | Where-Object { $_ -clike 'grand_casino_*' }).Count -gt 0) {
            throw 'Town conditions gained a Grand Casino scenario-id multiplier; model it before trusting the seed witness.'
        }
    }

    $modulusMatch = [regex]::Match($rngStream, '(?m)^const MODULUS\s*:=\s*(\d+)\s*$')
    $multiplierMatch = [regex]::Match($rngStream, '(?m)^const MULTIPLIER\s*:=\s*(\d+)\s*$')
    $noneMatch = [regex]::Match($runGenerator, '(?m)^const ENVIRONMENT_SITUATION_NONE_PERCENT\s*:=\s*(\d+)\s*$')
    $clockMatch = [regex]::Match($runState, '(?m)^const GAME_CLOCK_START_MINUTE\s*:=\s*(\d+)\s*\*\s*(\d+)\s*$')
    if (-not $modulusMatch.Success -or -not $multiplierMatch.Success -or
        -not $noneMatch.Success -or -not $clockMatch.Success) {
        throw 'Could not extract the production RNG/scenario constants exactly.'
    }
    $startMinutes = [int64]$clockMatch.Groups[1].Value * [int64]$clockMatch.Groups[2].Value
    if ($startMinutes -lt 0 -or $startMinutes -gt [int]::MaxValue) {
        throw 'Production starting clock is outside the supported deterministic range.'
    }
    return [pscustomobject]@{
        modulus = [int64]$modulusMatch.Groups[1].Value
        multiplier = [int64]$multiplierMatch.Groups[1].Value
        none_percent = [int]$noneMatch.Groups[1].Value
        start_minutes = [int]$startMinutes
        grand_town_multiplier = 1.0
        fresh_profile_modifier_text = $FreshProfileModifierText
        fresh_profile_content_groups = @($FreshProfileContentGroups)
    }
}


function Get-Rw062TextSeed {
    param([Parameter(Mandatory = $true)][string]$Text)
    [int64]$hashValue = 2166136261
    foreach ($character in $Text.ToCharArray()) {
        $hashValue = $hashValue -bxor [int][char]$character
        $hashValue = ($hashValue * 16777619) -band 0x7fffffff
    }
    return [int64][Math]::Max(1, $hashValue)
}


function Get-Rw062FreshProfileChallengeKey {
    param([Parameter(Mandatory = $true)][string]$CandidateSeed)
    return "standard|standard|$CandidateSeed|$FreshProfileModifierText"
}


function Assert-Rw062FreshProfileSerializationCalibration {
    $calibrationKey = Get-Rw062FreshProfileChallengeKey -CandidateSeed 'RW06-CLEAN-ROUTE-01'
    $calibrationSeed = Get-Rw062TextSeed -Text $calibrationKey
    if ($calibrationSeed -ne 6620395) {
        throw "Fresh-profile Godot Variant serialization no longer reproduces the packed production-save calibration (found $calibrationSeed)."
    }
    return [pscustomobject]@{
        seed_text = 'RW06-CLEAN-ROUTE-01'
        challenge_key = $calibrationKey
        run_seed = [int64]$calibrationSeed
        packed_save_witness = 6620395
    }
}


function Get-Rw062NormalizedRngValue {
    param(
        [Parameter(Mandatory = $true)][int64]$Value,
        [Parameter(Mandatory = $true)][int64]$Modulus
    )
    $normalized = [Math]::Abs($Value) % $Modulus
    if ($normalized -eq 0) { return [int64]1 }
    return [int64]$normalized
}


function Get-Rw062DerivedSeed {
    param(
        [Parameter(Mandatory = $true)][int64]$BaseSeed,
        [Parameter(Mandatory = $true)][string]$StreamKey,
        [Parameter(Mandatory = $true)]$Production
    )
    [int64]$value = Get-Rw062NormalizedRngValue -Value $BaseSeed -Modulus ([int64]$Production.modulus)
    $text = "$BaseSeed|$BaseSeed|$StreamKey"
    foreach ($character in $text.ToCharArray()) {
        $value = $value -bxor [int][char]$character
        $value = ($value * [int64]$Production.multiplier) % [int64]$Production.modulus
    }
    return Get-Rw062NormalizedRngValue -Value $value -Modulus ([int64]$Production.modulus)
}


function Get-Rw062NextRngState {
    param(
        [Parameter(Mandatory = $true)][int64]$State,
        [Parameter(Mandatory = $true)]$Production
    )
    return [int64](($State * [int64]$Production.multiplier) % [int64]$Production.modulus)
}


function Get-Rw062OperatingCycleId {
    param(
        [AllowNull()]$OpenHours,
        [Parameter(Mandatory = $true)][int]$AbsoluteMinutes
    )
    $minutesPerDay = 24 * 60
    $dayIndex = [int][Math]::Floor([double]$AbsoluteMinutes / [double]$minutesPerDay)
    if ($null -eq $OpenHours) { return "day:$dayIndex" }
    $openMinute = [int](Get-Rw062ExactProperty -InputObject $OpenHours -Name 'open_minute')
    $closeMinute = [int](Get-Rw062ExactProperty -InputObject $OpenHours -Name 'close_minute')
    $openMinute = (($openMinute % $minutesPerDay) + $minutesPerDay) % $minutesPerDay
    $closeMinute = (($closeMinute % $minutesPerDay) + $minutesPerDay) % $minutesPerDay
    if ($openMinute -eq $closeMinute) { return "day:$dayIndex" }
    $minute = (($AbsoluteMinutes % $minutesPerDay) + $minutesPerDay) % $minutesPerDay
    $openingDay = if ($closeMinute -lt $openMinute -and $minute -lt $closeMinute) { $dayIndex - 1 } else { $dayIndex }
    return "open:$openingDay`:$openMinute"
}


function Get-Rw062GrandScenarioSelection {
    param(
        [Parameter(Mandatory = $true)][string]$CandidateSeed,
        [Parameter(Mandatory = $true)]$Production,
        [int]$AbsoluteMinutes = -1,
        [AllowEmptyCollection()][string[]]$RecentScenarioIds = @()
    )
    $archetypeValue = Get-Content -LiteralPath $ArchetypesPath -Raw | ConvertFrom-Json
    $archetypes = @($archetypeValue)
    $grandMatches = @($archetypes | Where-Object {
        $id = Get-Rw062OptionalProperty -InputObject $_ -Name 'id' -Default $null
        $id -is [string] -and [string]$id -ceq 'grand_casino'
    })
    if ($grandMatches.Count -ne 1) {
        throw "Expected one exact grand_casino archetype; found $($grandMatches.Count)."
    }
    $openHours = Get-Rw062OptionalProperty -InputObject $grandMatches[0] -Name 'open_hours' -Default $null
    if ($AbsoluteMinutes -lt 0) {
        $AbsoluteMinutes = [int]$Production.start_minutes
    }
    $cycleId = Get-Rw062OperatingCycleId -OpenHours $openHours -AbsoluteMinutes $AbsoluteMinutes

    $scenarioRoot = Get-Content -LiteralPath $ScenariosPath -Raw | ConvertFrom-Json
    $scenarioPool = @(Get-Rw062ExactProperty -InputObject $scenarioRoot -Name 'grand_casino')
    if ($scenarioPool.Count -eq 0) {
        throw 'Grand Casino scenario pool is empty.'
    }

    $challengeKey = Get-Rw062FreshProfileChallengeKey -CandidateSeed $CandidateSeed
    $runSeed = Get-Rw062TextSeed -Text $challengeKey
    $streamKey = "environment_situation:grand_casino:$cycleId"
    $streamSeed = Get-Rw062DerivedSeed -BaseSeed $runSeed -StreamKey $streamKey -Production $Production
    $state = Get-Rw062NextRngState -State $streamSeed -Production $Production
    $noneRoll = 1 + ($state % 100)
    if ($noneRoll -le [int]$Production.none_percent) {
        return [pscustomobject]@{
            seed_text = $CandidateSeed
            challenge_key = $challengeKey
            run_seed = $runSeed
            cycle_id = $cycleId
            stream_key = $streamKey
            stream_seed = $streamSeed
            none_roll = [int]$noneRoll
            none_percent = [int]$Production.none_percent
            absolute_minutes = $AbsoluteMinutes
            recent_scenario_ids = @($RecentScenarioIds)
            town_multiplier = [double]$Production.grand_town_multiplier
            total_weight = 0
            weighted_roll = $null
            selected_scenario = ''
        }
    }

    $weighted = @()
    [int64]$totalWeight = 0
    foreach ($scenario in $scenarioPool) {
        $scenarioId = Get-Rw062ExactProperty -InputObject $scenario -Name 'id'
        $weightValue = Get-Rw062OptionalProperty -InputObject $scenario -Name 'weight' -Default 1
        $townTags = @(Get-Rw062OptionalProperty -InputObject $scenario -Name 'town_weight_tags' -Default @())
        if ($scenarioId -isnot [string] -or [string]::IsNullOrWhiteSpace([string]$scenarioId)) {
            throw 'Grand Casino scenario has no exact non-empty id.'
        }
        if ($weightValue -isnot [byte] -and $weightValue -isnot [int16] -and
            $weightValue -isnot [int32] -and $weightValue -isnot [int64] -and
            $weightValue -isnot [single] -and $weightValue -isnot [double] -and
            $weightValue -isnot [decimal]) {
            throw "Grand Casino scenario '$scenarioId' has a non-numeric weight."
        }
        if ($townTags.Count -ne 0) {
            throw "Grand Casino scenario '$scenarioId' gained town-weight tags; the fixed-seed preflight must model that production multiplier before continuing."
        }
        [double]$repeatMultiplier = 1.0
        $recentIndex = -1
        for ($index = 0; $index -lt $RecentScenarioIds.Count; $index++) {
            if ([string]$RecentScenarioIds[$index] -ceq [string]$scenarioId) {
                $recentIndex = $index
                break
            }
        }
        if ($recentIndex -eq 0 -and $scenarioPool.Count -gt 1) {
            $repeatMultiplier = 0.0
        }
        elseif ($recentIndex -eq 1) {
            $repeatMultiplier = 0.35
        }
        elseif ($recentIndex -ge 2) {
            $repeatMultiplier = 0.60
        }
        $scaledWeight = [int64][Math]::Round(
            [double]$weightValue * $repeatMultiplier * [double]$Production.grand_town_multiplier * 1000.0
        )
        if ($scaledWeight -le 0) { continue }
        $totalWeight += $scaledWeight
        $weighted += [pscustomobject]@{
            id = [string]$scenarioId
            repeat_multiplier = $repeatMultiplier
            town_multiplier = [double]$Production.grand_town_multiplier
            scaled_weight = $scaledWeight
            ceiling = $totalWeight
        }
    }
    if ($weighted.Count -eq 0 -or $totalWeight -le 0 -or $totalWeight -gt [int]::MaxValue) {
        throw 'Grand Casino scenario weights are empty or outside the supported range.'
    }

    $state = Get-Rw062NextRngState -State $state -Production $Production
    $weightedRoll = 1 + ($state % $totalWeight)
    $selected = [string]$weighted[$weighted.Count - 1].id
    foreach ($entry in $weighted) {
        if ($weightedRoll -le [int64]$entry.ceiling) {
            $selected = [string]$entry.id
            break
        }
    }
    return [pscustomobject]@{
        seed_text = $CandidateSeed
        challenge_key = $challengeKey
        run_seed = $runSeed
        cycle_id = $cycleId
        stream_key = $streamKey
        stream_seed = $streamSeed
        none_roll = [int]$noneRoll
        none_percent = [int]$Production.none_percent
        absolute_minutes = $AbsoluteMinutes
        recent_scenario_ids = @($RecentScenarioIds)
        town_multiplier = [double]$Production.grand_town_multiplier
        weighted_entries = @($weighted)
        total_weight = [int]$totalWeight
        weighted_roll = [int]$weightedRoll
        selected_scenario = $selected
    }
}


function Assert-Rw062AuditNightSelection {
    param(
        [Parameter(Mandatory = $true)][string]$CandidateSeed,
        [Parameter(Mandatory = $true)][string]$Expected,
        [Parameter(Mandatory = $true)]$Production,
        [int]$AbsoluteMinutes = -1,
        [AllowEmptyCollection()][string[]]$RecentScenarioIds = @()
    )
    $selection = Get-Rw062GrandScenarioSelection `
        -CandidateSeed $CandidateSeed `
        -Production $Production `
        -AbsoluteMinutes $AbsoluteMinutes `
        -RecentScenarioIds $RecentScenarioIds
    if ([string]$selection.selected_scenario -cne $Expected) {
        $observed = if ([string]::IsNullOrWhiteSpace([string]$selection.selected_scenario)) { '<none>' } else { [string]$selection.selected_scenario }
        throw "Heist seed '$CandidateSeed' selects Grand scenario '$observed', not required '$Expected' (cycle=$($selection.cycle_id), none_roll=$($selection.none_roll), weighted_roll=$($selection.weighted_roll))."
    }
    return $selection
}


$production = Get-Rw062ProductionScenarioContract
$failures = [Collections.Generic.List[string]]::new()
$validCount = 0
$hostileCount = 0
$selection = $null
$freshInteractiveSelection = $null
$serializationCalibration = $null
$arrivalHistoryHostile = $null

if ($Contract) {
    try {
        $serializationCalibration = Assert-Rw062FreshProfileSerializationCalibration
    }
    catch {
        $failures.Add("Fresh-profile launch serialization calibration failed: $($_.Exception.Message)")
    }

    try {
        # Q-013A adopts only this exact fresh-profile witness. Lasting route
        # knowledge is earned separately through the visible Audit roster.
        $selection = Assert-Rw062AuditNightSelection -CandidateSeed 'RW06-HEIST-AUDIT-0002' -Expected 'grand_casino_audit_night' -Production $production
        $validCount = 1
        if ([int64]$selection.run_seed -ne 919325714 -or
            [string]$selection.cycle_id -cne 'day:0' -or
            [int64]$selection.stream_seed -ne 1392077385 -or
            [int]$selection.none_roll -ne 59 -or
            [int]$selection.total_weight -ne 26000 -or
            [int]$selection.weighted_roll -ne 24088 -or
            [double]$selection.town_multiplier -ne 1.0 -or
            @($selection.recent_scenario_ids).Count -ne 0) {
            throw 'Fresh-profile Audit candidate no longer has its exact current-tree first-arrival witness.'
        }
    }
    catch {
        $failures.Add("Valid fresh-profile Audit candidate failed: $($_.Exception.Message)")
    }

    try {
        # Q-017A authorizes exactly one distinct seed for the separate
        # fresh-interactive Plan A pass. This is still a natural fresh-profile
        # first-arrival selection; only the production selector participates.
        $freshInteractiveSelection = Assert-Rw062AuditNightSelection `
            -CandidateSeed 'RW06-HEIST-AUDIT-0000' `
            -Expected 'grand_casino_audit_night' `
            -Production $production
        $validCount++
        if ([int64]$freshInteractiveSelection.run_seed -ne 1262406216 -or
            [string]$freshInteractiveSelection.cycle_id -cne 'day:0' -or
            [int64]$freshInteractiveSelection.stream_seed -ne 501255064 -or
            [int]$freshInteractiveSelection.none_roll -ne 96 -or
            [int]$freshInteractiveSelection.total_weight -ne 26000 -or
            [int]$freshInteractiveSelection.weighted_roll -ne 22402 -or
            [string]$freshInteractiveSelection.selected_scenario -cne 'grand_casino_audit_night' -or
            [double]$freshInteractiveSelection.town_multiplier -ne 1.0 -or
            @($freshInteractiveSelection.recent_scenario_ids).Count -ne 0) {
            throw 'Q-017A fresh-interactive seed no longer has its exact current-tree first-arrival Audit witness.'
        }
    }
    catch {
        $failures.Add("Valid Q-017A fresh-interactive Audit candidate failed: $($_.Exception.Message)")
    }

    $hostiles = @(
        [pscustomobject]@{ seed = 'RW06-HEIST-AUDIT-0013'; run_seed = 1868801668; stream_seed = 1372636511; selected = 'grand_casino_convention_crowd'; none_roll = 44; total_weight = 26000; weighted_roll = 12067 },
        [pscustomobject]@{ seed = 'PLAYTEST-CATALOG-01'; run_seed = 442088822; stream_seed = 1137052244; selected = 'grand_casino_convention_crowd'; none_roll = 99; total_weight = 26000; weighted_roll = 18698 },
        [pscustomobject]@{ seed = 'FIRST-NIGHT-ACE-17'; run_seed = 1092180122; stream_seed = 975513235; selected = ''; none_roll = 17; total_weight = 0; weighted_roll = $null }
    )
    $hostileCount = $hostiles.Count + 1
    foreach ($hostile in $hostiles) {
        try {
            $observed = Get-Rw062GrandScenarioSelection -CandidateSeed ([string]$hostile.seed) -Production $production
            if ([string]$observed.selected_scenario -cne [string]$hostile.selected -or
                [int64]$observed.run_seed -ne [int64]$hostile.run_seed -or
                [int64]$observed.stream_seed -ne [int64]$hostile.stream_seed -or
                [int]$observed.none_roll -ne [int]$hostile.none_roll -or
                [int]$observed.total_weight -ne [int]$hostile.total_weight -or
                (($null -eq $hostile.weighted_roll) -and $null -ne $observed.weighted_roll) -or
                (($null -ne $hostile.weighted_roll) -and [int]$observed.weighted_roll -ne [int]$hostile.weighted_roll)) {
                throw "Hostile fresh-profile seed witness drifted: selected='$($observed.selected_scenario)', run_seed=$($observed.run_seed), stream_seed=$($observed.stream_seed), none_roll=$($observed.none_roll), total_weight=$($observed.total_weight), weighted_roll=$($observed.weighted_roll)."
            }
            $threw = $false
            try {
                $null = Assert-Rw062AuditNightSelection -CandidateSeed ([string]$hostile.seed) -Expected 'grand_casino_audit_night' -Production $production
            }
            catch {
                $threw = $true
            }
            if (-not $threw) {
                throw 'Non-Audit seed did not fail closed against the Plan A requirement.'
            }
        }
        catch {
            $failures.Add("Hostile seed '$($hostile.seed)' contract failed: $($_.Exception.Message)")
        }
    }

    try {
        $arrivalHistoryHostile = Get-Rw062GrandScenarioSelection `
            -CandidateSeed 'RW06-HEIST-AUDIT-0002' `
            -Production $production `
            -AbsoluteMinutes ([int]$production.start_minutes + (24 * 60)) `
            -RecentScenarioIds @('grand_casino_audit_night')
        $auditEntries = @($arrivalHistoryHostile.weighted_entries | Where-Object {
            [string]$_.id -ceq 'grand_casino_audit_night'
        })
        if ([string]$arrivalHistoryHostile.cycle_id -cne 'day:1' -or
            [int64]$arrivalHistoryHostile.run_seed -ne 919325714 -or
            [int64]$arrivalHistoryHostile.stream_seed -ne 1392125656 -or
            [int]$arrivalHistoryHostile.none_roll -ne 53 -or
            @($arrivalHistoryHostile.recent_scenario_ids).Count -ne 1 -or
            [string]$arrivalHistoryHostile.recent_scenario_ids[0] -cne 'grand_casino_audit_night' -or
            $auditEntries.Count -ne 0 -or
            [int]$arrivalHistoryHostile.total_weight -ne 19000 -or
            [int]$arrivalHistoryHostile.weighted_roll -ne 15327 -or
            [string]$arrivalHistoryHostile.selected_scenario -cne 'grand_casino_convention_crowd') {
            throw 'Immediate recent-history suppression did not remove Audit Night from the next Grand operating cycle.'
        }
        $threw = $false
        try {
            $null = Assert-Rw062AuditNightSelection `
                -CandidateSeed 'RW06-HEIST-AUDIT-0002' `
                -Expected 'grand_casino_audit_night' `
                -Production $production `
                -AbsoluteMinutes ([int]$production.start_minutes + (24 * 60)) `
                -RecentScenarioIds @('grand_casino_audit_night')
        }
        catch {
            $threw = $true
        }
        if (-not $threw) {
            throw 'Recent Audit history did not fail closed against a later-arrival Audit requirement.'
        }
    }
    catch {
        $failures.Add("Arrival-history hostile contract failed: $($_.Exception.Message)")
    }
}
else {
    try {
        $selection = Assert-Rw062AuditNightSelection -CandidateSeed $SeedText -Expected $ExpectedScenario -Production $production
        $validCount = 1
    }
    catch {
        $selectionFailure = $_.Exception.Message
        try {
            $selection = Get-Rw062GrandScenarioSelection -CandidateSeed $SeedText -Production $production
        }
        catch {
            $selection = $null
        }
        $failures.Add($selectionFailure)
    }
}

$report = [ordered]@{
    contract = 'rw06_2_heist_seed_preflight'
    passed = ($failures.Count -eq 0)
    expected_scenario = $ExpectedScenario
    selection = $selection
    fresh_interactive_selection = $freshInteractiveSelection
    launch_model = [ordered]@{
        screen = 'START'
        run_config = $true
        selected_challenge = ''
        selected_home = 'random'
        selected_content_groups = @($production.fresh_profile_content_groups)
        challenge_mode = 'standard'
        challenge_id = 'standard'
        fresh_profile_modifier_text = [string]$production.fresh_profile_modifier_text
        start_absolute_minutes = [int]$production.start_minutes
        first_arrival_recent_scenario_ids = @()
    }
    serialization_calibration = $serializationCalibration
    arrival_history_hostile = $arrivalHistoryHostile
    owner_decisions = @('Q-013A', 'Q-017A')
    valid_fixtures = $validCount
    hostile_fixtures = $hostileCount
    failures = @($failures)
}
if ([string]::IsNullOrWhiteSpace($ReportPath)) {
    $ReportPath = Join-Path $Worktree '.tmp\rw06_2\heist_seed_preflight.json'
}
$reportDirectory = Split-Path -Parent $ReportPath
if (-not [string]::IsNullOrWhiteSpace($reportDirectory)) {
    [void](New-Item -ItemType Directory -Path $reportDirectory -Force)
}
$report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $ReportPath -Encoding utf8

if ($failures.Count -gt 0) {
    foreach ($failure in $failures) {
        Write-Error $failure -ErrorAction Continue
    }
    throw "RW06_2_HEIST_SEED_PREFLIGHT FAIL ($($failures.Count) failure(s)); report: $ReportPath"
}

$report | ConvertTo-Json -Depth 10 -Compress
