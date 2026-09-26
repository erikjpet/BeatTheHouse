param(
    [ValidateSet('Historical22', 'Generation100')]
    [string]$Mode = 'Historical22',
    [string]$ExpectedCommit = '',
    [string]$ExpectedTree = '',
    [int]$Visits = 6,
    [string]$GodotPath = 'D:\Projects\Beat-The-House\.tools\godot-4.6-stable\Godot_v4.6-stable_win64_console.exe',
    [string]$ExpectedGodotSha256 = '',
    [string]$PythonPath = 'C:\Users\theep\AppData\Local\Programs\Python\Python310\python.exe',
    [string]$ExpectedPythonSha256 = '',
    [int]$ProcessTimeoutSeconds = 300,
    [int]$LeaseWaitTimeoutSeconds = 900,
    [string]$EvidenceRoot = '',
    [switch]$ValidateOnly,
    [string]$SelfTestReport = '',
    [switch]$LoadAdmissionFunctionsOnly,
    [string]$ProjectRoot = ''
)

$ErrorActionPreference = 'Stop'
$projectRoot = if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
}
else {
    [System.IO.Path]::GetFullPath($ProjectRoot).TrimEnd('\', '/')
}
$supportPath = Join-Path $PSScriptRoot 'rw06_q009_process_support.ps1'
if (-not (Test-Path -LiteralPath $supportPath -PathType Leaf)) {
    throw "Missing Q-009 process support: $supportPath"
}
. $supportPath

# These two names are consumed by the reviewed shared support functions.
$leaseRoot = 'D:\Projects\Beat-The-House-worktrees\.godot_leases'
$leaseContainerRoot = 'D:\Projects\Beat-The-House-worktrees'
$nativeExitSentinel = [int]::MinValue
$exclusiveLeasePath = Join-Path $leaseRoot 'EXCLUSIVE.lease'
$launchMutexName = 'Global\BeatTheHouse-Q009-GodotLaunch'
$canonicalGodotPath = 'D:\Projects\Beat-The-House\.tools\godot-4.6-stable\Godot_v4.6-stable_win64_console.exe'
$canonicalPythonPath = 'C:\Users\theep\AppData\Local\Programs\Python\Python310\python.exe'
$manifestRelativePath = 'tools/fixtures/rw06_1_environment_exact_seed_manifest.json'
$auditRelativePath = 'tools/environment_generation_audit.gd'
$staticRelativePath = 'tools/environment_fixed_slot_static_check.py'
$supportRelativePath = 'tools/rw06_q009_process_support.ps1'
$launcherRelativePath = 'tools/rw06_1_environment_exact_seed_contract_test.ps1'
$scenarioRelativePath = 'data/environments/scenarios.json'
$fidelityRelativePath = 'scripts/tests/foundation/harness_production_fidelity.gd'
$foundationTravelRelativePath = 'scripts/ui/foundation_travel_view_model.gd'
$tutorialFlowRelativePath = 'scripts/core/tutorial_flow.gd'
$attributeBadgesRelativePath = 'scripts/core/attribute_badges.gd'
$manifestPath = Join-Path $projectRoot ($manifestRelativePath.Replace('/', '\'))
$auditPath = Join-Path $projectRoot ($auditRelativePath.Replace('/', '\'))
$staticCheckerPath = Join-Path $projectRoot ($staticRelativePath.Replace('/', '\'))
$scenarioPath = Join-Path $projectRoot ($scenarioRelativePath.Replace('/', '\'))
$foundationTravelPath = Join-Path $projectRoot ($foundationTravelRelativePath.Replace('/', '\'))
$tutorialFlowPath = Join-Path $projectRoot ($tutorialFlowRelativePath.Replace('/', '\'))
$attributeBadgesPath = Join-Path $projectRoot ($attributeBadgesRelativePath.Replace('/', '\'))
$projectCacheRoot = Join-Path $projectRoot '.godot'
$expectedManifestSha256 = '496E15978F18797A68D1E2ACB9B0EAFC964AE824FD94AF1B16A9E231B594B116'
$expectedManifestBlob = '7b0e4b5e92a64775e40d07b8850dffa40af79af7'
$generationSeedPrefix = 'RW06-1-GENERATION-100-0060'
$inactiveIndependentProjectionFingerprint = '78b558bd2357fbe7ad52804fb3af1b8664b23db096b1deb22d215dde25b152bf'

$historicalRows = @(
    'POSTFIX-UIENV-009-4151570434|bar|bar_fight_night|scenario_fight_night_swing_bet||scenario::bar_fight_night_safe_exit|',
    'POSTFIX-UIENV-015-1938529946|bar|bar_fight_night|scenario_fight_night_swing_bet||scenario::bar_fight_night_safe_exit|',
    'POSTFIX-UIENV-031-2491917705|bar|bar_fight_night|scenario_fight_night_swing_bet||scenario::bar_fight_night_safe_exit|',
    'POSTFIX-UIENV-036-3073861592|bar|bar_fight_night|scenario_fight_night_swing_bet||scenario::bar_fight_night_safe_exit|',
    'POSTFIX-UIENV-037-655530953|bar|bar_fight_night|scenario_fight_night_swing_bet||scenario::bar_fight_night_safe_exit|',
    'POSTFIX-UIENV-043-934268634|bar|bar_fight_night|scenario_fight_night_swing_bet||scenario::bar_fight_night_safe_exit|',
    'POSTFIX-UIENV-054-1002983031|bar|bar_fight_night|scenario_fight_night_swing_bet||scenario::bar_fight_night_safe_exit|',
    'POSTFIX-UIENV-073-140575119|bar|bar_fight_night|scenario_fight_night_swing_bet||scenario::bar_fight_night_safe_exit|',
    'POSTFIX-UIENV-093-397681310|bar|bar_fight_night|scenario_fight_night_swing_bet||scenario::bar_fight_night_safe_exit|',
    'POSTFIX-UIENV-098-1674379668|bar|bar_fight_night|scenario_fight_night_swing_bet||scenario::bar_fight_night_safe_exit|',
    'POSTFIX-UIENV-007-2898334884|gas_station_casino|gas_station_road_crew_payday|scenario_road_crew_payday_pool|side_door|scenario::gas_station_road_crew_payday_station|event::event:side_door',
    'POSTFIX-UIENV-008-2688401675|gas_station_casino|gas_station_road_crew_payday|scenario_road_crew_payday_pool|side_door|scenario::gas_station_road_crew_payday_station|event::event:side_door',
    'POSTFIX-UIENV-018-2408131097|gas_station_casino|gas_station_road_crew_payday|scenario_road_crew_payday_pool|side_door|scenario::gas_station_road_crew_payday_station|event::event:side_door',
    'POSTFIX-UIENV-033-405233240|gas_station_casino|gas_station_road_crew_payday|scenario_road_crew_payday_pool|side_door|scenario::gas_station_road_crew_payday_station|event::event:side_door',
    'POSTFIX-UIENV-082-1306411836|gas_station_casino|gas_station_road_crew_payday|scenario_road_crew_payday_pool|side_door|scenario::gas_station_road_crew_payday_station|event::event:side_door',
    'POSTFIX-UIENV-092-1191177531|gas_station_casino|gas_station_road_crew_payday|scenario_road_crew_payday_pool|side_door|scenario::gas_station_road_crew_payday_station|event::event:side_door',
    'POSTFIX-UIENV-061-1987792568|corner_store|corner_store_dead_shift|scenario_dead_shift_rumor|town_rumor_staff|scenario::corner_store_dead_shift_exit|event::event:town_rumor_staff',
    'POSTFIX-UIENV-062-84881432|corner_store|corner_store_dead_shift|scenario_dead_shift_rumor|town_rumor_staff|scenario::corner_store_dead_shift_exit|event::event:town_rumor_staff',
    'POSTFIX-UIENV-087-3894813921|corner_store|corner_store_dead_shift|scenario_dead_shift_rumor|town_rumor_staff|scenario::corner_store_dead_shift_exit|event::event:town_rumor_staff',
    'POSTFIX-UIENV-090-235429475|corner_store|corner_store_dead_shift|scenario_dead_shift_rumor|late_shift_discount|scenario::corner_store_dead_shift_exit|event::event:late_shift_discount',
    'POSTFIX-UIENV-040-2723440700|corner_store|corner_store_inventory_night|scenario_inventory_night_count|scenario_inventory_night_count|scenario::count_cage|event::event:scenario_inventory_night_count',
    'POSTFIX-UIENV-063-608418289|corner_store|corner_store_inventory_night|scenario_inventory_night_count|parking_lot_tip|scenario::count_cage|event::event:parking_lot_tip'
)

function Add-Issue {
    param([System.Collections.Generic.List[string]]$Issues, [string]$Message)
    [void]$Issues.Add($Message)
}

function Join-LauncherError {
    param([string]$Current,[string]$Message)
    if([string]::IsNullOrWhiteSpace($Current)){return $Message}
    return $Current+' | '+$Message
}

function Test-ExactBoolean {
    param([object]$Value, [bool]$Expected)
    return ($Value -is [bool]) -and ([bool]$Value -eq $Expected)
}

function Test-ExactInteger {
    param([object]$Value, [long]$Expected)
    return ($Value -is [int] -or $Value -is [long]) -and ([long]$Value -eq $Expected)
}

function Test-ExactPositiveJsonDecimal {
    param([AllowNull()][object]$Value)
    # Windows PowerShell 5.1 ConvertFrom-Json materializes the fractional JSON
    # number emitted by Time.get_unix_time_from_system() as System.Decimal.
    # Do not coerce integers, doubles, strings, arrays, or booleans into it.
    return ($Value -is [decimal]) -and ([decimal]$Value -gt [decimal]0)
}

function Test-ExactJsonString {
    param([AllowNull()][object]$Value,[switch]$AllowEmpty)
    if (-not ($Value -is [string])) { return $false }
    if ($AllowEmpty) { return $true }
    return -not [string]::IsNullOrWhiteSpace($Value)
}

function Test-ExactJsonStringValue {
    param([AllowNull()][object]$Value,[AllowEmptyString()][string]$Expected)
    return (Test-ExactJsonString $Value -AllowEmpty) -and ([string]$Value -ceq $Expected)
}

function Test-ExactJsonStringPair {
    param([AllowNull()][object]$Left,[AllowNull()][object]$Right,[switch]$AllowEmpty)
    if (-not (Test-ExactJsonString $Left -AllowEmpty:$AllowEmpty) -or -not (Test-ExactJsonString $Right -AllowEmpty:$AllowEmpty)) { return $false }
    return [string]$Left -ceq [string]$Right
}

function Get-Q009GdScriptTopLevelFunctionExtent {
    param([string]$Source,[string]$FunctionName)
    if([string]::IsNullOrWhiteSpace($Source)-or$FunctionName-cnotmatch'^[A-Za-z_][A-Za-z0-9_]*$'){throw 'GDScript function-extent lookup requires nonempty source and one exact identifier'}
    $declarations=[regex]::Matches($Source,'(?m)^(?:static[ \t]+)?func[ \t]+([A-Za-z_][A-Za-z0-9_]*)[ \t]*\(')
    $matches=@($declarations|Where-Object{[string]$_.Groups[1].Value-ceq$FunctionName})
    if($matches.Count-ne1){throw "GDScript top-level function extent was not unique: $FunctionName"}
    $start=[int]$matches[0].Index;$end=$Source.Length
    foreach($declaration in $declarations){if([int]$declaration.Index-gt$start){$end=[int]$declaration.Index;break}}
    $extent=$Source.Substring($start,$end-$start)
    if($extent.Contains('"""')-or$extent.Contains("'''")){throw "GDScript source contract refuses multiline-string ambiguity in $FunctionName"}
    return $extent
}

function Get-Q009GdScriptNestedFunctionExtent {
    param([string]$ClassExtent,[string]$FunctionName)
    if([string]::IsNullOrWhiteSpace($ClassExtent)-or$FunctionName-cnotmatch'^[A-Za-z_][A-Za-z0-9_]*$'){throw 'GDScript nested-function lookup requires nonempty class source and one exact identifier'}
    $declarations=[regex]::Matches($ClassExtent,'(?m)^\tfunc[ \t]+([A-Za-z_][A-Za-z0-9_]*)[ \t]*\(')
    $matches=@($declarations|Where-Object{[string]$_.Groups[1].Value-ceq$FunctionName})
    if($matches.Count-ne1){throw "GDScript nested function extent was not unique: $FunctionName"}
    $start=[int]$matches[0].Index;$end=$ClassExtent.Length
    foreach($declaration in $declarations){if([int]$declaration.Index-gt$start){$end=[int]$declaration.Index;break}}
    return $ClassExtent.Substring($start,$end-$start)
}

function Get-Q009EnvironmentAuditTravelSourceIssues {
    param([string]$Source)
    $issues=[Collections.Generic.List[string]]::new()
    try{
        # Source contracts compare exact GDScript tokens, not checkout newline
        # policy. Normalize CRLF so the end-of-line anchors below behave the
        # same in Windows worktrees and LF-only repository blobs.
        $Source=$Source.Replace("`r`n","`n")
        if($Source.Contains('"""')-or$Source.Contains("'''")){throw 'GDScript travel source contract refuses any multiline-string ambiguity'}
        $simulate=Get-Q009GdScriptTopLevelFunctionExtent $Source '_simulate_run'
        $record=Get-Q009GdScriptTopLevelFunctionExtent $Source '_record_environment'
        $choices=Get-Q009GdScriptTopLevelFunctionExtent $Source '_travel_choices'
        $targets=Get-Q009GdScriptTopLevelFunctionExtent $Source '_travel_target_ids'
        $productionHost=Get-Q009GdScriptTopLevelFunctionExtent $Source '_production_foundation_travel_host'
        $overlay=Get-Q009GdScriptTopLevelFunctionExtent $Source '_qualifying_world_travel_contract_holds'
        $travel=Get-Q009GdScriptTopLevelFunctionExtent $Source '_travel_to'
        $hostStart=$Source.IndexOf('class AuditFoundationTravelHost:',[StringComparison]::Ordinal)
        $hostEnd=$Source.IndexOf('var library: ContentLibrary',$hostStart,[StringComparison]::Ordinal)
        if($hostStart-lt0-or$hostEnd-le$hostStart-or$Source.IndexOf('class AuditFoundationTravelHost:',$hostStart+1,[StringComparison]::Ordinal)-ge0){throw 'production travel host adapter extent was not exact and unique'}
        $foundationHost=$Source.Substring($hostStart,$hostEnd-$hostStart)
        $hostMethodReturns=[ordered]@{
            _is_meta_session='return false'
            _travel_base_cache_key='return str(view_model_script.travel_base_cache_key(self))'
            _enabled_world_route_ids='return view_model_script.enabled_world_route_ids(self, source_id)'
            _world_route_for_target='return view_model_script.world_route_for_target(self, target_id, path_query)'
            _environment_archetype='return view_model_script.environment_archetype(self, archetype_id)'
            _travel_clock_minutes_for_route='return int(view_model_script.travel_clock_minutes_for_route(self, route, force_walk))'
            _arrival_minute_for_route='return int(view_model_script.arrival_minute_for_route(self, route, force_walk))'
            _environment_open_status_at='return view_model_script.environment_open_status_at(self, archetype, minute_of_day)'
            _travel_label_from_archetype='return str(view_model_script.travel_label_from_archetype(self, archetype, fallback_id))'
            _travel_full_preview_enabled='return bool(view_model_script.travel_full_preview_enabled(self))'
            _travel_full_preview_enabled_for='return bool(view_model_script.travel_full_preview_enabled_for(self, target_id))'
            _local_parent_home_door_travel_choice='return {}'
            _closing_time_blocks_environment_actions='return false'
            _closing_time_walk_fallback_target_id='return ""'
            _travel_target_ids='return view_model_script.travel_target_ids(self)'
            _travel_choice='return view_model_script.travel_choice(self, target_id, known_target_ids)'
        }
        foreach($methodName in @($hostMethodReturns.Keys)){
            $methodExtent=Get-Q009GdScriptNestedFunctionExtent $foundationHost ([string]$methodName)
            $expectedReturn=[string]$hostMethodReturns[$methodName]
            if([regex]::Matches($methodExtent,'(?m)^\t\treturn[ \t]+').Count-ne1-or[regex]::Matches($methodExtent,'(?m)^\t\t'+[regex]::Escape($expectedReturn)+'[ \t]*$').Count-ne1){[void]$issues.Add("production Foundation host adapter method was not exact: $methodName")}
        }
        foreach($preloadLine in @(
            'const FoundationTravelViewModelScript := preload("res://scripts/ui/foundation_travel_view_model.gd")',
            'const TutorialFlowScript := preload("res://scripts/core/tutorial_flow.gd")',
            'const AttributeBadgesScript := preload("res://scripts/core/attribute_badges.gd")'
        )){if([regex]::Matches($Source,'(?m)^'+[regex]::Escape($preloadLine)+'[ \t]*$').Count-ne1){[void]$issues.Add("production Foundation dependency binding was not exact: $preloadLine")}}
        foreach($hostConstant in @('const TRAVEL_CLOCK_MINUTES_PER_BLOCK := 6','const WALK_CLOCK_MINUTES_PER_BLOCK := 10')){if([regex]::Matches($foundationHost,'(?m)^\t'+[regex]::Escape($hostConstant)+'[ \t]*$').Count-ne1){[void]$issues.Add("production Foundation timing constant was not exact: $hostConstant")}}
        if([regex]::Matches($foundationHost,'(?m)^\tvar world_map_overlay: Variant = null[ \t]*$').Count-ne1){[void]$issues.Add('production Foundation host omitted the explicit null world-map overlay used by scouting preview gating')}
        $hostInit=Get-Q009GdScriptNestedFunctionExtent $foundationHost '_init'
        if([regex]::Matches($hostInit,'(?ms)^\tfunc _init\([ \t]*\r?\n\t\tp_view_model_script: Script,[ \t]*\r?\n\t\tp_world_map_script: Script,[ \t]*\r?\n\t\tp_tutorial_flow_script: Script,[ \t]*\r?\n\t\tp_attribute_badges_script: Script,[ \t]*\r?\n\t\tp_run_state: Variant,[ \t]*\r?\n\t\tp_generator: Variant,[ \t]*\r?\n\t\tp_library: Variant[ \t]*\r?\n\t\) -> void:[ \t]*$').Count-ne1){[void]$issues.Add('production Foundation host constructor signature/order was not exact')}
        foreach($assignment in @('view_model_script = p_view_model_script','WorldMapScript = p_world_map_script','TutorialFlowScript = p_tutorial_flow_script','AttributeBadgesScript = p_attribute_badges_script','run_state = p_run_state','generator = p_generator','library = p_library')){if([regex]::Matches($hostInit,'(?m)^\t\t'+[regex]::Escape($assignment)+'[ \t]*$').Count-ne1){[void]$issues.Add("production Foundation host constructor omitted exact assignment: $assignment")}}
        if([regex]::Matches($simulate,'(?m)^\t\trecord\["travel_after_events"\][ \t]*=[ \t]*_travel_choices\(run_state, false\)[ \t]*$').Count-ne1){[void]$issues.Add('post-event public catalog producer escaped _simulate_run')}
        if([regex]::Matches($record,'(?m)^\tvar[ \t]+travel_initial[ \t]*:=[ \t]*_travel_choices\(run_state, false\)[ \t]*$').Count-ne1-or[regex]::Matches($record,'(?m)^\t\t"travel_initial"[ \t]*:[ \t]*travel_initial,[ \t]*$').Count-ne1){[void]$issues.Add('initial public catalog producer/record escaped _record_environment')}
        if([regex]::Matches($Source,'(?m)^[ \t]*record\["travel_after_events"\][ \t]*=[ \t]*_travel_choices\(run_state, false\)[ \t]*$').Count-ne1-or[regex]::Matches($Source,'(?m)^[ \t]*var[ \t]+travel_initial[ \t]*:=[ \t]*_travel_choices\(run_state, false\)[ \t]*$').Count-ne1-or[regex]::Matches($Source,'(?m)^[ \t]*"travel_initial"[ \t]*:[ \t]*travel_initial,[ \t]*$').Count-ne1){[void]$issues.Add('public catalog producer tokens were duplicated or omitted')}
        if([regex]::IsMatch($Source,'(?m)^[ \t]*(?:record\["travel_after_events"\][ \t]*=|var[ \t]+travel_initial[ \t]*:=)[ \t]*_travel_choices\(run_state, true\)')){[void]$issues.Add('qualifying evidence admits hidden routes')}
        if([regex]::Matches($targets,'(?m)^\tif not _qualifying_world_travel_contract_holds\(run_state\):[ \t]*$').Count-ne1-or[regex]::Matches($targets,'(?m)^\t\treturn \[\][ \t]*$').Count-ne1-or[regex]::Matches($targets,'(?m)^\treturn _production_foundation_travel_host\(run_state\)\._travel_target_ids\(\)[ \t]*$').Count-ne1-or[regex]::Matches($targets,'(?m)^\t+return[ \t]+').Count-ne2-or$targets.Contains('WorldMapScript.travel_target_ids')-or$targets.Contains('generator._world_travel_target_ids')){[void]$issues.Add('world target catalog bypasses the exact production Foundation view or its overlay guard')}
        if([regex]::Matches($productionHost,'(?m)^\treturn[ \t]+').Count-ne1-or[regex]::Matches($productionHost,'(?ms)^\treturn AuditFoundationTravelHost\.new\([ \t]*\r?\n\t\tFoundationTravelViewModelScript,[ \t]*\r?\n\t\tWorldMapScript,[ \t]*\r?\n\t\tTutorialFlowScript,[ \t]*\r?\n\t\tAttributeBadgesScript,[ \t]*\r?\n\t\trun_state,[ \t]*\r?\n\t\tgenerator,[ \t]*\r?\n\t\tlibrary[ \t]*\r?\n\t\)[ \t]*$').Count-ne1){[void]$issues.Add('production Foundation travel host was not constructed in exact order from the shipped collaborators and run state')}
        if([regex]::Matches($choices,'(?m)^\tvar target_ids := _travel_target_ids\(run_state\)[ \t]*$').Count-ne1-or[regex]::Matches($choices,'(?m)^\tvar production_host := _production_foundation_travel_host\(run_state\)[ \t]*$').Count-ne1-or[regex]::Matches($choices,'(?m)^\t\tvar production_choice: Dictionary = production_host\._travel_choice\(str\(target_id\), target_ids\)[ \t]*$').Count-ne1-or[regex]::Matches($choices,'(?m)^\t\t\t"enabled": bool\(production_choice\.get\("enabled", false\)\),[ \t]*$').Count-ne1-or$choices.Contains('generator._world_target_is_available')){[void]$issues.Add('travel choice projection bypasses the production Foundation choice')}
        foreach($required in @(
            'not run_state.has_world_map()','run_state.is_tutorial_run()','run_state.narrative_flags.get("_meta_home_session", false)','run_state.delivery_has_active_run()',
            'run_state.closing_time_forced_travel_required()','run_state.travel_option_bonus() != 0',
            '_string_array(local_flags.get("casino_room_targets", [])).is_empty()'
        )){if(-not$overlay.Contains($required)){[void]$issues.Add("qualifying overlay guard omitted: $required")}}
        if([regex]::Matches($overlay,'(?m)^\t\t\tfailures\.append\(message\)[ \t]*$').Count-ne1-or[regex]::Matches($overlay,'(?m)^\t+return[ \t]+').Count-ne2-or[regex]::Matches($overlay,'(?m)^\t\treturn true[ \t]*$').Count-ne1-or[regex]::Matches($overlay,'(?m)^\treturn false[ \t]*$').Count-ne1){[void]$issues.Add('overlay violation is not bound to the exact qualifying failure control flow')}
        if([regex]::Matches($travel,'_travel_target_ids\(run_state\)').Count-ne2){[void]$issues.Add('pre/post-heat travel admission witnesses bypass the constrained production target catalog')}
    }catch{[void]$issues.Add($_.Exception.Message)}
    return @($issues)
}

function Test-JsonObject {
    param([AllowNull()][object]$Value)
    return $null -ne $Value -and $Value -is [pscustomobject]
}

function Test-ExactOrderedJsonObjectKeys {
    param([AllowNull()][object]$Value,[string[]]$ExpectedKeys)
    if (-not (Test-JsonObject $Value) -or $null -eq $ExpectedKeys) { return $false }
    $actual = @($Value.PSObject.Properties | Where-Object { $_.MemberType -eq [System.Management.Automation.PSMemberTypes]::NoteProperty } | ForEach-Object { [string]$_.Name })
    if ($actual.Count -ne $ExpectedKeys.Count -or @($actual | Sort-Object -Unique).Count -ne $actual.Count) { return $false }
    for ($index = 0; $index -lt $ExpectedKeys.Count; $index += 1) {
        if ([string]$actual[$index] -cne [string]$ExpectedKeys[$index]) { return $false }
    }
    return $true
}

function Test-ExactSha256 {
    param([AllowNull()][object]$Value)
    return ($Value -is [string]) -and ([string]$Value -cmatch '^[0-9a-f]{64}$|^[0-9A-F]{64}$')
}

$travelChoiceKeys = @(
    'id','label','kind','tier','enabled','hidden','disabled_reason','cost','risk','distance',
    'risk_decay','suspicion_delta','risk_text','risk_event','unlock_conditions',
    'travel_lock_remaining','availability_turn'
)

$travelRiskEventKeys=@('id','label','chance_percent','bankroll_delta','suspicion_delta','message')

function ConvertTo-Q009CanonicalJsonValue {
    param([AllowNull()][object]$Value)
    if($null-eq$Value){return $null}
    if($Value-is[System.Array]){return [object[]]@($Value|ForEach-Object{ConvertTo-Q009CanonicalJsonValue $_})}
    if($Value-is[System.Collections.IDictionary]){
        $result=[ordered]@{}
        foreach($key in @($Value.Keys|ForEach-Object{if($_-isnot[string]){throw 'Canonical JSON object contained a non-string key'};[string]$_}|Sort-Object -CaseSensitive)){$result[$key]=ConvertTo-Q009CanonicalJsonValue $Value[$key]}
        return $result
    }
    if(Test-JsonObject $Value){
        $result=[ordered]@{}
        foreach($property in @($Value.PSObject.Properties|Where-Object{$_.MemberType-eq[System.Management.Automation.PSMemberTypes]::NoteProperty}|Sort-Object Name -CaseSensitive)){$result[[string]$property.Name]=ConvertTo-Q009CanonicalJsonValue $property.Value}
        return $result
    }
    if($Value-is[string]-or$Value-is[bool]-or$Value-is[int]-or$Value-is[long]-or$Value-is[decimal]-or$Value-is[double]){return $Value}
    throw ('Canonical JSON rejected unsupported scalar type '+$Value.GetType().FullName)
}

function Get-Q009CanonicalJsonSha256 {
    param([AllowNull()][object]$Value)
    $canonical=ConvertTo-Q009CanonicalJsonValue $Value
    # Piping AutomationNull into ConvertTo-Json emits no object in Windows
    # PowerShell 5.1. Canonical JSON still has an exact representation for a
    # null value, so bind that literal explicitly before hashing.
    $json=if($null-eq$canonical){'null'}else{$canonical|ConvertTo-Json -Compress -Depth 100}
    $sha=[Security.Cryptography.SHA256]::Create()
    try{return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($json)))).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose()}
}

function Test-ExactTravelRiskEvent {
    param([AllowNull()][object]$RiskEvent)
    if(-not(Test-JsonObject $RiskEvent)){return $false}
    $properties=@($RiskEvent.PSObject.Properties|Where-Object{$_.MemberType-eq[System.Management.Automation.PSMemberTypes]::NoteProperty})
    if($properties.Count-eq0){return $true}
    if(-not(Test-ExactOrderedJsonObjectKeys $RiskEvent $travelRiskEventKeys)){return $false}
    foreach($field in @('id','label')){if(-not(Test-ExactJsonString $RiskEvent.$field)){return $false}}
    if(-not(Test-ExactJsonString $RiskEvent.message -AllowEmpty)){return $false}
    foreach($field in @('chance_percent','bankroll_delta','suspicion_delta')){if($RiskEvent.$field-isnot[int]-and$RiskEvent.$field-isnot[long]){return $false}}
    return [long]$RiskEvent.chance_percent-gt0-and[long]$RiskEvent.chance_percent-le100
}

function Test-ExactPublicTravelChoice {
    param([AllowNull()][object]$Choice)
    if (-not (Test-ExactOrderedJsonObjectKeys $Choice $travelChoiceKeys)) { return $false }
    foreach ($name in @('id','label','kind')) { if (-not (Test-ExactJsonString $Choice.$name)) { return $false } }
    foreach ($name in @('disabled_reason','risk','distance','risk_text')) { if (-not (Test-ExactJsonString $Choice.$name -AllowEmpty)) { return $false } }
    foreach ($name in @('tier','cost','risk_decay','suspicion_delta','travel_lock_remaining','availability_turn')) {
        if (-not ($Choice.$name -is [int] -or $Choice.$name -is [long])) { return $false }
    }
    if (-not ($Choice.enabled -is [bool]) -or -not (Test-ExactBoolean $Choice.hidden $false)) { return $false }
    if (-not (Test-ExactTravelRiskEvent $Choice.risk_event) -or -not (Test-StringArray $Choice.unlock_conditions)) { return $false }
    return $true
}

function Test-ExactPublicTravelCatalog {
    param([AllowNull()][object]$Catalog,[int]$MaximumCount=3)
    if (-not ($Catalog -is [System.Array])) { return $false }
    $ids = [System.Collections.Generic.List[string]]::new()
    foreach ($choice in @($Catalog)) {
        if (-not (Test-ExactPublicTravelChoice $choice)) { return $false }
        if ($ids.Contains([string]$choice.id)) { return $false }
        [void]$ids.Add([string]$choice.id)
    }
    return $MaximumCount -lt 0 -or $ids.Count -le $MaximumCount
}

function Test-JsonDeepEqual {
    param([AllowNull()][object]$Left,[AllowNull()][object]$Right)
    if($null -eq $Left -or $null -eq $Right){return $null -eq $Left -and $null -eq $Right}
    return ($Left|ConvertTo-Json -Compress -Depth 100) -ceq ($Right|ConvertTo-Json -Compress -Depth 100)
}

function Get-ExactNamedStringFieldIssues {
    param(
        [AllowNull()][object]$Value,
        [string[]]$FieldNames,
        [string]$Path = '$'
    )
    $issues = [System.Collections.Generic.List[string]]::new()
    if ($null -eq $Value) { return @($issues) }
    if ($Value -is [System.Array]) {
        $index = 0
        foreach ($item in @($Value)) {
            foreach ($issue in @(Get-ExactNamedStringFieldIssues $item $FieldNames "$Path[$index]")) { [void]$issues.Add($issue) }
            $index += 1
        }
        return @($issues)
    }
    if (Test-JsonObject $Value) {
        foreach ($property in @($Value.PSObject.Properties)) {
            $childPath = "$Path.$($property.Name)"
            if ($FieldNames -contains [string]$property.Name -and -not ($property.Value -is [string])) {
                [void]$issues.Add("$childPath was not a JSON string")
            }
            foreach ($issue in @(Get-ExactNamedStringFieldIssues $property.Value $FieldNames $childPath)) { [void]$issues.Add($issue) }
        }
    }
    return @($issues)
}

function Test-StringArray {
    param([AllowNull()][object]$Value,[int]$MaximumCount=-1,[switch]$RequireUnique)
    if(-not($Value -is [System.Array])){return $false}
    $items=@($Value)
    if($MaximumCount -ge 0 -and $items.Count -gt $MaximumCount){return $false}
    foreach($item in $items){if(-not($item -is [string]) -or [string]::IsNullOrWhiteSpace([string]$item)){return $false}}
    if($RequireUnique -and @($items|Sort-Object -Unique).Count -ne $items.Count){return $false}
    return $true
}

function Test-ExactIntegerRangeArray {
    param([AllowNull()][object]$Value,[int]$Start,[int]$Count)
    if(-not($Value -is [System.Array])){return $false}
    $items=@($Value)
    if($items.Count-ne$Count){return $false}
    for($index=0;$index-lt$Count;$index+=1){
        if(-not(Test-ExactInteger $items[$index] ($Start+$index))){return $false}
    }
    return $true
}

function Test-ExactRuntimeLayoutAuthorityShape {
    param([AllowNull()][object]$Layout,[AllowNull()][object]$Finalization)
    if(-not(Test-JsonObject $Layout)-or-not(Test-JsonObject $Finalization)){return $false}
    if(-not($Layout.authority_receipts -is [System.Array])-or-not($Layout.authority_identities -is [System.Array])){return $false}
    if(-not(Test-StringArray $Layout.authority_identities -RequireUnique)){return $false}
    $receipts=@($Layout.authority_receipts);$identities=@($Layout.authority_identities)
    if(-not(Test-ExactInteger $Layout.authority_count $receipts.Count)-or$identities.Count-ne$receipts.Count){return $false}
    for($index=0;$index-lt$receipts.Count;$index+=1){
        if(-not(Test-JsonObject $receipts[$index])-or-not(Test-ExactJsonStringPair $receipts[$index].identity $identities[$index])){return $false}
    }
    if(-not(Test-ExactInteger $Finalization.layout_authority_count $receipts.Count)){return $false}
    if(-not(Test-ExactJsonStringPair $Finalization.layout_authority_digest $Layout.authority_digest -AllowEmpty)){return $false}
    if(-not(Test-ExactJsonStringPair $Finalization.semantic_digest $Layout.semantic_digest -AllowEmpty)){return $false}
    return Test-OrdinaryAuthorityReceiptCollection $Layout
}

function Test-ExactArrivalErrorShape {
    param([AllowNull()][object]$Arrival)
    if(-not(Test-JsonObject $Arrival)-or-not($Arrival.errors -is [System.Array])-or-not($Arrival.travel_errors -is [System.Array])){return $false}
    if(-not(Test-StringArray $Arrival.errors)-or-not(Test-StringArray $Arrival.travel_errors)){return $false}
    return (Test-ExactInteger $Arrival.arrival_error_count @($Arrival.errors).Count) -and
        (Test-ExactInteger $Arrival.travel_error_count @($Arrival.travel_errors).Count)
}

function Get-ExecutableIdentity {
    param([string]$Path)
    $full=[IO.Path]::GetFullPath($Path)
    if(-not(Test-Path -LiteralPath $full -PathType Leaf)){throw "Executable is missing: $full"}
    $stream=$null;$hasher=$null
    try{
        # FileShare.Read excludes both writes and rename/delete while the hash,
        # metadata, and native file-index receipt are captured from one object.
        $stream=[IO.File]::Open($full,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
        $nativeIdentity=Get-Q009FileSystemHandleIdentity -Handle $stream.SafeFileHandle -Path $full -IsDirectory $false
        $hasher=[Security.Cryptography.SHA256]::Create();$hash=([BitConverter]::ToString($hasher.ComputeHash($stream))).Replace('-','').ToUpperInvariant()
        $item=Get-Item -LiteralPath $full -Force -ErrorAction Stop;$version=$item.VersionInfo
        return [ordered]@{
            path=$full
            length=[long]$stream.Length
            sha256=$hash
            last_write_utc=$item.LastWriteTimeUtc.ToString('o')
            last_write_ticks=[long]$item.LastWriteTimeUtc.Ticks
            file_version=[string]$version.FileVersion
            product_version=[string]$version.ProductVersion
            original_filename=[string]$version.OriginalFilename
            filesystem_identity=$nativeIdentity
        }
    }finally{
        if($null-ne$hasher){$hasher.Dispose()}
        if($null-ne$stream){$stream.Dispose()}
    }
}

function Assert-ExecutableIdentity {
    param([string]$Label,[string]$Path,[string]$ExpectedPath,[string]$ExpectedSha256,[AllowNull()][object]$CapturedIdentity=$null)
    if($ExpectedSha256 -cnotmatch '^[0-9A-F]{64}$'){throw "$Label expected SHA-256 must be exactly 64 uppercase hex characters"}
    $normalized=[IO.Path]::GetFullPath($Path)
    $normalizedExpected=[IO.Path]::GetFullPath($ExpectedPath)
    if(-not[string]::Equals($normalized,$normalizedExpected,[StringComparison]::OrdinalIgnoreCase)){throw "$Label executable path is not canonical: $normalized"}
    $actual=Get-ExecutableIdentity $normalized
    if([string]$actual.sha256 -cne $ExpectedSha256){throw "$Label executable SHA-256 differs from the explicit expected hash"}
    if($null -ne $CapturedIdentity -and -not(Test-JsonDeepEqual $actual $CapturedIdentity)){throw "$Label executable identity drifted after initial capture"}
    return $actual
}

function ConvertTo-SafeEvidenceName {
    param([string]$Value)
    return ($Value -replace '[^A-Za-z0-9._-]', '_')
}

function Get-ExpectationKey {
    param([object]$Expectation)
    return @(
        [string]$Expectation.seed,
        [string]$Expectation.destination,
        [string]$Expectation.scenario_id,
        [string]$Expectation.required_marker,
        [string]$Expectation.required_object,
        [string]$Expectation.required_interaction,
        [string]$Expectation.conflict_identity
    ) -join '|'
}

function Get-CanonicalManifestIssues {
    param(
        [object]$Manifest,
        [string]$RawSha256 = $expectedManifestSha256,
        [string]$GitBlob = $expectedManifestBlob,
        [switch]$SkipIdentity
    )
    $issues = [System.Collections.Generic.List[string]]::new()
    if (-not (Test-ExactInteger $Manifest.schema_version 1)) { Add-Issue $issues 'manifest schema_version must be integer 1' }
    if (-not (Test-ExactJsonStringValue $Manifest.source 'postfix06_2 exact historical UIENV contract')) { Add-Issue $issues 'manifest source changed or was not a string' }
    if(-not($Manifest.expectations -is [System.Array])){Add-Issue $issues 'manifest expectations was not a JSON array'}
    $rows = @($Manifest.expectations)
    if ($rows.Count -ne 22) { Add-Issue $issues "manifest must contain exactly 22 expectations; found $($rows.Count)" }
    foreach ($row in $rows) {
        if (-not (Test-JsonObject $row)) { Add-Issue $issues 'manifest expectation was not a JSON object'; continue }
        foreach ($field in @('seed','destination','scenario_id','required_marker','required_interaction')) {
            if (-not (Test-ExactJsonString $row.$field)) { Add-Issue $issues "manifest expectation $field was not a nonempty string" }
        }
        foreach ($field in @('required_object','conflict_identity')) {
            if ($row.PSObject.Properties.Name -contains $field -and -not (Test-ExactJsonString $row.$field -AllowEmpty)) { Add-Issue $issues "manifest expectation $field was not a string" }
        }
    }
    $actualKeys = @($rows | ForEach-Object { Get-ExpectationKey $_ })
    if ($actualKeys.Count -eq $historicalRows.Count) {
        for ($index = 0; $index -lt $historicalRows.Count; $index += 1) {
            if ([string]$actualKeys[$index] -cne [string]$historicalRows[$index]) {
                Add-Issue $issues "manifest row $index changed or moved"
            }
        }
    }
    $seeds = @($rows | ForEach-Object { [string]$_.seed })
    if (@($seeds | Sort-Object -Unique).Count -ne 22 -or $seeds -contains '') { Add-Issue $issues 'manifest seeds must be 22 unique nonempty identities' }
    $safeNames = @($seeds | ForEach-Object { ConvertTo-SafeEvidenceName $_ })
    if (@($safeNames | Sort-Object -Unique).Count -ne $safeNames.Count) { Add-Issue $issues 'manifest seeds collide after evidence filename sanitization' }
    if (@($rows | Where-Object { [string]$_.scenario_id -ceq 'bar_fight_night' }).Count -ne 10) { Add-Issue $issues 'Fight Night distribution must be 10' }
    if (@($rows | Where-Object { [string]$_.scenario_id -ceq 'gas_station_road_crew_payday' }).Count -ne 6) { Add-Issue $issues 'Road Crew distribution must be 6' }
    if (@($rows | Where-Object { [string]$_.scenario_id -ceq 'corner_store_dead_shift' }).Count -ne 4) { Add-Issue $issues 'Dead Shift distribution must be 4' }
    if (@($rows | Where-Object { [string]$_.scenario_id -ceq 'corner_store_inventory_night' }).Count -ne 2) { Add-Issue $issues 'Inventory Night distribution must be 2' }
    $combos = @($Manifest.legal_room_combinations)
    if(-not($Manifest.legal_room_combinations -is [System.Array])){Add-Issue $issues 'manifest legal_room_combinations was not a JSON array'}
    if ($combos.Count -ne 1) {
        Add-Issue $issues "manifest must contain exactly one legal-room combination; found $($combos.Count)"
    }
    else {
        $combo = $combos[0]
        foreach ($field in @('seed','destination','scenario_id','phase_id','base_event_id','base_slot_id','scenario_identity')) {
            if (-not (Test-ExactJsonString $combo.$field)) { Add-Issue $issues "legal-room combination $field was not a nonempty string" }
        }
        if (
            -not (Test-ExactJsonStringValue $combo.seed 'POSTFIX-UIENV-009-4151570434') -or
            -not (Test-ExactJsonStringValue $combo.destination 'corner_store') -or
            -not (Test-ExactJsonStringValue $combo.scenario_id 'corner_store_delivery_day') -or
            -not (Test-ExactJsonStringValue $combo.phase_id 'arrival') -or
            -not (Test-ExactJsonStringValue $combo.base_event_id 'town_rumor_staff') -or
            -not (Test-ExactJsonStringValue $combo.base_slot_id 'base.staff_shopkeeper') -or
            -not (Test-ExactJsonStringValue $combo.scenario_identity 'scenario::delivery_event_gate')
        ) { Add-Issue $issues 'seed 009 legal-room combination changed' }
    }
    if (-not $SkipIdentity) {
        if ($RawSha256 -cne $expectedManifestSha256) { Add-Issue $issues 'manifest raw SHA-256 changed' }
        if ($GitBlob -cne $expectedManifestBlob) { Add-Issue $issues 'manifest Git blob changed' }
    }
    return @($issues)
}

function Read-JsonFileStrict {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Missing JSON evidence: $Path" }
    try { return [System.IO.File]::ReadAllText($Path) | ConvertFrom-Json -ErrorAction Stop }
    catch { throw "Could not parse JSON evidence $Path`: $($_.Exception.Message)" }
}

function Get-StrictDiagnosticLines {
    param([string]$Text)
    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($line in @(Get-DiagnosticLines -Text $Text)) {
        if (-not $lines.Contains([string]$line)) { [void]$lines.Add([string]$line) }
    }
    foreach ($pattern in @(
        '(?im)^.*(?:leaked instance|instances? still alive|resources? still in use).*$',
        '(?im)^.*(?:orphan(?:ed)? node|orphan StringName).*$',
        '(?im)^.*StringName:\s*[0-9]+\s+unclaimed string names?\s+at exit\..*$',
        '(?im)^.*RID allocations?.*$'
    )) {
        foreach ($match in [regex]::Matches($Text, $pattern)) {
            $line = $match.Value.Trim()
            if (-not [string]::IsNullOrWhiteSpace($line) -and -not $lines.Contains($line)) { [void]$lines.Add($line) }
        }
    }
    return @($lines)
}

function Test-PrivateEvidenceLeak {
    param([string]$JsonText)
    $forbidden = '(?i)"(?:current_turn|turn_index|turn_card|hole_cards|truth_trace|traitor|traitor_id|traitor_grievance|local_state|rigged_draw|rigged-draw|draw_order|ticket_sleeve|ticket_stack|winning_ticket|ticket_secret|unrevealed_ticket|prize_value)"\s*:'
    return [regex]::IsMatch($JsonText, $forbidden)
}

function Test-SeedTupleMatches {
    param([object]$Value,[object]$Run,[string]$AttemptId)
    if(-not(Test-JsonObject $Value) -or -not(Test-JsonObject $Run)){return $false}
    foreach($name in @('attempt_id','requested_seed_text','seed_text','challenge_key','challenge_id','challenge_mode')){if(-not($Value.$name -is [string])){return $false}}
    foreach($name in @('attempt_id','seed','requested_seed_text','seed_text','challenge_key','challenge_id','challenge_mode')){if(-not(Test-ExactJsonString $Run.$name)){return $false}}
    foreach($name in @('seed_value','derived_seed_value')){if(-not($Value.$name -is [int] -or $Value.$name -is [long])){return $false}}
    foreach($name in @('seed_value','derived_seed_value')){if(-not($Run.$name -is [int] -or $Run.$name -is [long])){return $false}}
    if($Value.PSObject.Properties.Name -contains 'seed' -and (-not(Test-ExactJsonString $Value.seed) -or -not(Test-ExactJsonStringPair $Value.seed $Run.seed))){return $false}
    return (Test-ExactJsonStringValue $Value.attempt_id $AttemptId) -and
        (Test-ExactJsonStringPair $Value.requested_seed_text $Run.requested_seed_text) -and
        (Test-ExactJsonStringPair $Value.seed_text $Run.seed_text) -and
        (Test-ExactInteger $Value.seed_value ([long]$Run.seed_value)) -and
        (Test-ExactJsonStringPair $Value.challenge_key $Run.challenge_key) -and
        (Test-ExactJsonStringPair $Value.challenge_id $Run.challenge_id) -and
        (Test-ExactJsonStringPair $Value.challenge_mode $Run.challenge_mode) -and
        (Test-ExactInteger $Value.derived_seed_value ([long]$Run.derived_seed_value)) -and
        (Test-ExactBoolean $Value.seed_binding_valid $true)
}

function Test-RequiredSeedBinding {
    param([object]$Value,[object]$Run,[string]$AttemptId)
    if(-not(Test-SeedTupleMatches $Value $Run $AttemptId)-or-not(Test-ExactBoolean $Value.attempt_id_required $true)){return $false}
    foreach($name in @('challenge_seed_text','challenge_daily_id','expected_challenge_key')){if(-not($Value.$name -is [string])){return $false}}
    foreach($name in @('seed_text','expected_challenge_key')){if(-not(Test-ExactJsonString $Run.$name)){return $false}}
    if(-not(Test-ExactJsonString $Value.challenge_daily_id -AllowEmpty)){return $false}
    foreach($name in @('challenge_modifier_count','expected_seed_value')){if(-not($Value.$name -is [int] -or $Value.$name -is [long])){return $false}}
    if(-not($Run.expected_seed_value -is [int] -or $Run.expected_seed_value -is [long])){return $false}
    return (Test-ExactJsonStringPair $Value.challenge_seed_text $Run.seed_text) -and
        (Test-ExactJsonStringValue $Value.challenge_daily_id '') -and
        (Test-ExactBoolean $Value.challenge_hidden_seed $false) -and
        (Test-ExactInteger $Value.challenge_modifier_count 0) -and
        (Test-ExactJsonStringPair $Value.expected_challenge_key $Run.expected_challenge_key) -and
        (Test-ExactInteger $Value.expected_seed_value ([long]$Run.expected_seed_value))
}

function Test-ExactArrivalStatus {
    param(
        [object]$Arrival,
        [ValidateSet('initial','travel')][string]$ExpectedKind,
        [object]$ExpectedDestination,
        [AllowNull()][object]$ExpectedSource,
        [int]$ExpectedVisitIndex,
        [int]$ExpectedTravelIndex,
        [int]$ExpectedFromVisitIndex,
        [object]$ExpectedRun,
        [string]$AttemptId
    )
    if (-not (Test-JsonObject $Arrival) -or -not (Test-JsonObject $Arrival.finalization) -or -not (Test-JsonObject $Arrival.runtime_scenario_layout) -or -not(Test-JsonObject $ExpectedDestination) -or -not(Test-JsonObject $ExpectedRun)) { return $false }
    $expectedProductionPath = if ($ExpectedKind -ceq 'initial') { 'generate_and_finalize' } else { 'travel_and_finalize' }
    if (
        -not (Test-ExactJsonStringValue $Arrival.kind $ExpectedKind) `
        -or -not (Test-ExactJsonStringValue $Arrival.production_path $expectedProductionPath) `
        -or -not (Test-ExactJsonStringValue $Arrival.stage 'complete') `
        -or -not (Test-ExactInteger $Arrival.visit_index $ExpectedVisitIndex) `
        -or -not (Test-ExactInteger $Arrival.travel_index $ExpectedTravelIndex) `
        -or -not (Test-ExactInteger $Arrival.from_visit_index $ExpectedFromVisitIndex) `
        -or -not (Test-RequiredSeedBinding $Arrival $ExpectedRun $AttemptId)
    ) { return $false }
    $expectedSourceId=if($ExpectedKind-ceq'initial'){''}elseif(Test-JsonObject $ExpectedSource){[string]$ExpectedSource.world_node_id}else{return $false}
    if(
        -not(Test-ExactJsonStringValue $Arrival.source_id $expectedSourceId) -or
        -not(Test-ExactJsonStringValue $Arrival.travel_source_id $expectedSourceId) -or
        -not(Test-ExactJsonStringPair $Arrival.target_id $ExpectedDestination.world_node_id) -or
        -not(Test-ExactJsonStringPair $Arrival.travel_target_id $ExpectedDestination.world_node_id) -or
        -not(Test-ExactJsonStringPair $Arrival.installed_environment_id $ExpectedDestination.environment_id) -or
        -not(Test-ExactJsonStringPair $Arrival.installed_archetype_id $ExpectedDestination.archetype_id) -or
        -not(Test-ExactJsonStringPair $Arrival.installed_world_node_id $ExpectedDestination.world_node_id) -or
        -not(Test-ExactJsonStringPair $Arrival.installed_scenario_id $ExpectedDestination.scenario_id -AllowEmpty) -or
        -not(Test-ExactJsonStringPair $Arrival.travel_environment_id $ExpectedDestination.environment_id) -or
        -not(Test-ExactJsonStringPair $Arrival.travel_archetype_id $ExpectedDestination.archetype_id) -or
        -not(Test-ExactJsonStringPair $Arrival.travel_world_node_id $ExpectedDestination.world_node_id) -or
        -not(Test-ExactJsonStringPair $Arrival.travel_scenario_id $ExpectedDestination.scenario_id -AllowEmpty)
    ){return $false}
    if(-not(Test-ExactArrivalErrorShape $Arrival)-or-not(Test-ExactRuntimeLayoutAuthorityShape $Arrival.runtime_scenario_layout $Arrival.finalization)){return $false}
    foreach ($flag in @(
        'ok','travel_ok','production_boundary_valid',
        'arrival_contract_shape_valid','travel_contract_shape_valid','installed','installed_finalized',
        'source_binding_valid','target_binding_valid','current_install_binding_valid','travel_install_binding_valid',
        'installed_projection_binding_valid','live_projection_binding_valid','installed_live_projection_binding_valid',
        'travel_projection_binding_valid','finalization_projection_binding_valid','independent_projection_binding_valid',
        'projection_binding_valid','finalization_matches_runtime','runtime_layout_valid','finalization_clean'
    )) {
        if (-not (Test-ExactBoolean $Arrival.$flag $true)) { return $false }
    }
    if (-not (Test-ExactBoolean $Arrival.production_scenario_finalized ($ExpectedKind -ceq 'travel'))) { return $false }
    if (-not (Test-ExactBoolean $Arrival.travel_projection_binding_required ($ExpectedKind -ceq 'travel'))) { return $false }
    if (
        -not (Test-ExactBoolean $Arrival.finalization.ok $true) `
        -or -not ($Arrival.finalization.inactive -is [bool]) `
        -or -not ($Arrival.runtime_scenario_layout.semantic_ready -is [bool]) `
        -or -not ($Arrival.runtime_scenario_layout.live_semantic_ready -is [bool]) `
        -or -not ($Arrival.finalization.warnings -is [System.Array]) `
        -or -not ($Arrival.finalization.errors -is [System.Array]) `
        -or -not (Test-StringArray $Arrival.finalization.warnings) `
        -or -not (Test-StringArray $Arrival.finalization.errors) `
        -or -not (Test-ExactInteger $Arrival.finalization.warning_count @($Arrival.finalization.warnings).Count) `
        -or -not (Test-ExactInteger $Arrival.finalization.error_count @($Arrival.finalization.errors).Count) `
        -or -not (Test-ExactJsonString $Arrival.runtime_scenario_layout.status -AllowEmpty) `
        -or -not (Test-ExactJsonString $Arrival.runtime_scenario_layout.scenario_id -AllowEmpty)
    ) { return $false }
    $inactive = [bool]$Arrival.finalization.inactive
    if ($inactive) {
        return (Test-ExactBoolean $Arrival.runtime_scenario_layout.semantic_ready $false) -and
            (Test-ExactBoolean $Arrival.runtime_scenario_layout.live_semantic_ready $false) -and
            (Test-ExactJsonStringValue $Arrival.runtime_scenario_layout.scenario_id '')
    }
    return (Test-ExactBoolean $Arrival.runtime_scenario_layout.semantic_ready $true) -and
        (Test-ExactBoolean $Arrival.runtime_scenario_layout.live_semantic_ready $true) -and
        (Test-ExactJsonStringPair $Arrival.runtime_scenario_layout.scenario_id $Arrival.installed_scenario_id)
}

$nativeDiagnosticCountKeys=@(
    'receipt_count','receipt_missing_count','receipt_invalid_count','arrival_ok_invalid_count',
    'travel_ok_invalid_count','arrival_stage_invalid_count','arrival_error_count','travel_error_count',
    'finalization_warning_count','finalization_error_count','scenario_state_error_count','semantic_error_count',
    'renderer_error_count','arrival_contract_invalid_count','travel_contract_invalid_count',
    'finalization_contract_invalid_count','runtime_layout_invalid_count','layout_audit_invalid_count',
    'action_authority_invalid_count','installed_invalid_count','source_binding_invalid_count',
    'target_binding_invalid_count','current_install_binding_invalid_count','travel_install_binding_invalid_count',
    'production_boundary_invalid_count','projection_binding_invalid_count',
    'installed_live_projection_binding_invalid_count','travel_projection_binding_invalid_count',
    'finalization_projection_binding_invalid_count','independent_projection_binding_invalid_count',
    'finalization_runtime_invalid_count','finalization_clean_invalid_count','seed_binding_invalid_count',
    'attempt_binding_invalid_count','warning_count','failure_count'
)

function New-ZeroNativeDiagnostics {
    param([int]$ReceiptCount=6)
    $values=[ordered]@{}
    foreach($name in $nativeDiagnosticCountKeys){$values[$name]=0}
    $values.receipt_count=$ReceiptCount;$values.clean=$true
    return [pscustomobject]$values
}

function Get-NativeDiagnosticSchemaIssues {
    param([AllowNull()][object]$NativeDiagnostics,[int]$ExpectedReceiptCount=-1)
    $issues=[System.Collections.Generic.List[string]]::new()
    if(-not(Test-JsonObject $NativeDiagnostics)){Add-Issue $issues 'native_diagnostics was not a JSON object';return @($issues)}
    $required=@($nativeDiagnosticCountKeys+@('clean')|Sort-Object)
    $actual=@($NativeDiagnostics.PSObject.Properties.Name|Sort-Object)
    if(($actual-join"`n")-cne($required-join"`n")){Add-Issue $issues 'native_diagnostics fixed schema changed'}
    foreach($name in $nativeDiagnosticCountKeys){
        $value=$NativeDiagnostics.$name
        if(-not($value -is [int] -or $value -is [long]) -or [long]$value -lt 0){Add-Issue $issues "native_diagnostics.$name was not a nonnegative integer"}
    }
    if(-not($NativeDiagnostics.clean -is [bool])){Add-Issue $issues 'native_diagnostics.clean was not boolean'}
    if($issues.Count){return @($issues)}
    if($ExpectedReceiptCount -ge 0 -and -not(Test-ExactInteger $NativeDiagnostics.receipt_count $ExpectedReceiptCount)){Add-Issue $issues "native receipt_count must be $ExpectedReceiptCount"}
    $failureTotal=[long]0
    foreach($name in $nativeDiagnosticCountKeys){if($name -notin @('receipt_count','finalization_warning_count','warning_count','failure_count')){$failureTotal+=[long]$NativeDiagnostics.$name}}
    $warningTotal=[long]$NativeDiagnostics.finalization_warning_count
    if(-not(Test-ExactInteger $NativeDiagnostics.warning_count $warningTotal)){Add-Issue $issues 'native warning_count did not equal finalization_warning_count'}
    if(-not(Test-ExactInteger $NativeDiagnostics.failure_count $failureTotal)){Add-Issue $issues 'native failure_count did not equal the exact failure-counter sum'}
    if(-not(Test-ExactBoolean $NativeDiagnostics.clean ($failureTotal-eq0-and$warningTotal-eq0))){Add-Issue $issues 'native clean did not match exact failure/warning totals'}
    return @($issues)
}

function Get-RunCrossBindingIssues {
    param([object]$Run,[object[]]$EnvironmentRecords,[object[]]$TravelRecords,[string]$AttemptId)
    $issues=[System.Collections.Generic.List[string]]::new()
    $runIndex=if($Run.run_index -is [int] -or $Run.run_index -is [long]){[int]$Run.run_index}else{-1}
    if(-not($Run.visited -is [System.Array])){Add-Issue $issues "run $runIndex visited was not an array";return @($issues)}
    $records=@($EnvironmentRecords|Where-Object{($_.run_index -is [int] -or $_.run_index -is [long])-and[int]$_.run_index-eq$runIndex}|Sort-Object visit_index)
    $travels=@($TravelRecords|Where-Object{($_.run_index -is [int] -or $_.run_index -is [long])-and[int]$_.run_index-eq$runIndex}|Sort-Object travel_index)
    if($records.Count-ne6){Add-Issue $issues "run $runIndex did not have exactly six environment records"}
    if($travels.Count-ne5){Add-Issue $issues "run $runIndex did not have exactly five travel records"}
    if(@($Run.visited).Count-ne6){Add-Issue $issues "run $runIndex visited did not contain exactly six records"}
    if(-not(Test-JsonObject $Run.final_seed_binding) -or -not(Test-RequiredSeedBinding $Run.final_seed_binding $Run $AttemptId) -or -not(Test-ExactBoolean $Run.final_seed_binding_valid $true) -or -not(Test-ExactBoolean $Run.final_seed_binding_satisfied $true)){Add-Issue $issues "run $runIndex final seed binding was not exact and satisfied"}
    if(-not(Test-ExactBoolean $Run.attempt_binding_satisfied $true)){Add-Issue $issues "run $runIndex final attempt binding was not satisfied"}
    if(-not(Test-ExactInteger $Run.post_event_seed_binding_count 6)){Add-Issue $issues "run $runIndex post-event seed binding count was not six"}
    for($visitIndex=0;$visitIndex-lt[Math]::Min(6,$records.Count);$visitIndex+=1){
        $record=$records[$visitIndex]
        if(-not(Test-JsonObject $record)){Add-Issue $issues "run $runIndex visit $visitIndex record was not an object";continue}
        if(-not(Test-ExactInteger $record.visit_index $visitIndex)){Add-Issue $issues "run $runIndex visit $visitIndex record order drifted"}
        foreach($field in @('environment_id','archetype_id','world_node_id')){if(-not($record.$field -is [string])-or[string]::IsNullOrWhiteSpace([string]$record.$field)){Add-Issue $issues "run $runIndex visit $visitIndex record $field was not a nonempty string"}}
        if(-not(Test-ExactJsonString $record.scenario_id -AllowEmpty)){Add-Issue $issues "run $runIndex visit $visitIndex record scenario_id was not an exact string"}
        if(-not(Test-ExactJsonStringValue $record.capture_boundary 'arrival_before_event_policy')){Add-Issue $issues "run $runIndex visit $visitIndex capture boundary drifted or was mistyped"}
        if(-not(Test-ExactPublicTravelCatalog $record.travel_initial 3)-or-not(Test-ExactSha256 $record.travel_initial_digest)-or[string]$record.travel_initial_digest-cne(Get-Q009CanonicalJsonSha256 $record.travel_initial)){Add-Issue $issues "run $runIndex visit $visitIndex initial public route catalog was malformed, hidden, uncapped, or digest-unsealed"}
        if(-not(Test-ExactPublicTravelCatalog $record.travel_after_events 3)-or-not(Test-ExactSha256 $record.travel_after_events_digest)-or[string]$record.travel_after_events_digest-cne(Get-Q009CanonicalJsonSha256 $record.travel_after_events)){Add-Issue $issues "run $runIndex visit $visitIndex post-event public route catalog was malformed, hidden, uncapped, or digest-unsealed"}
        if(-not(Test-JsonObject $record.seed_binding_after_event_policy) -or -not(Test-RequiredSeedBinding $record.seed_binding_after_event_policy $Run $AttemptId) -or -not(Test-ExactBoolean $record.seed_binding_after_event_policy_valid $true)){Add-Issue $issues "run $runIndex visit $visitIndex post-event seed binding was invalid"}
        $arrival=$record.arrival_receipt
        if(-not(Test-JsonObject $arrival)){Add-Issue $issues "run $runIndex visit $visitIndex arrival receipt was not an object";continue}
        $expectedArrivalKind=if($visitIndex-eq0){'initial'}else{'travel'}
        $expectedSource=if($visitIndex-eq0){$null}else{$records[$visitIndex-1]}
        $expectedTravelIndex=if($visitIndex-eq0){-1}else{$visitIndex-1}
        if(-not(Test-ExactBoolean $record.installed_finalized $true)-or-not(Test-ExactArrivalStatus -Arrival $arrival -ExpectedKind $expectedArrivalKind -ExpectedDestination $record -ExpectedSource $expectedSource -ExpectedVisitIndex $visitIndex -ExpectedTravelIndex $expectedTravelIndex -ExpectedFromVisitIndex $expectedTravelIndex -ExpectedRun $Run -AttemptId $AttemptId)){Add-Issue $issues "run $runIndex visit $visitIndex arrival/install/status/identity contract was not independently exact"}
        if(-not(Test-JsonObject $record.runtime_scenario_layout) -or -not(Test-JsonObject $arrival.runtime_scenario_layout) -or -not(Test-JsonDeepEqual $record.runtime_scenario_layout $arrival.runtime_scenario_layout)){Add-Issue $issues "run $runIndex visit $visitIndex record/arrival runtime layout diverged"}
        if(-not(Test-ExactRuntimeLayoutAuthorityShape $record.runtime_scenario_layout $arrival.finalization)){Add-Issue $issues "run $runIndex visit $visitIndex finalized runtime authority collection was not exact"}
        if(-not(Test-ExactInteger $arrival.visit_index $visitIndex) -or -not(Test-ExactJsonStringPair $arrival.installed_environment_id $record.environment_id) -or -not(Test-ExactJsonStringPair $arrival.installed_archetype_id $record.archetype_id) -or -not(Test-ExactJsonStringPair $arrival.installed_world_node_id $record.world_node_id) -or -not(Test-ExactJsonStringPair $arrival.installed_scenario_id $record.scenario_id -AllowEmpty)){Add-Issue $issues "run $runIndex visit $visitIndex installed arrival identity diverged from record or was mistyped"}
        $visited=if($visitIndex-lt@($Run.visited).Count){@($Run.visited)[$visitIndex]}else{$null}
        if(Test-JsonObject $visited){
            foreach($field in @('environment_id','archetype_id','world_node_id','arrival_kind')){if(-not($visited.$field -is [string])-or[string]::IsNullOrWhiteSpace([string]$visited.$field)){Add-Issue $issues "run $runIndex visit $visitIndex visited $field was not a nonempty string"}}
            foreach($field in @('scenario_id','scenario_layout_authority_digest')){if(-not(Test-ExactJsonString $visited.$field -AllowEmpty)){Add-Issue $issues "run $runIndex visit $visitIndex visited $field was not an exact string"}}
        }
        if(-not(Test-JsonObject $visited) -or -not(Test-SeedTupleMatches $visited $Run $AttemptId) -or -not(Test-ExactInteger $visited.visit_index $visitIndex) -or -not(Test-ExactJsonStringPair $visited.environment_id $record.environment_id) -or -not(Test-ExactJsonStringPair $visited.archetype_id $record.archetype_id) -or -not(Test-ExactJsonStringPair $visited.world_node_id $record.world_node_id) -or -not(Test-ExactJsonStringPair $visited.scenario_id $record.scenario_id -AllowEmpty) -or -not(Test-ExactJsonStringPair $visited.arrival_kind $arrival.kind) -or -not(Test-ExactBoolean $visited.arrival_ok $true) -or -not(Test-ExactBoolean $visited.installed_finalized $true) -or -not(Test-ExactJsonStringPair $visited.scenario_layout_authority_digest $arrival.runtime_scenario_layout.authority_digest -AllowEmpty)){Add-Issue $issues "run $runIndex visit $visitIndex visited summary was not independently bound with exact true status"}
        if($visitIndex-eq0-and(-not(Test-JsonObject $Run.initial_arrival_receipt)-or-not(Test-JsonDeepEqual $Run.initial_arrival_receipt $arrival))){Add-Issue $issues "run $runIndex initial arrival did not deep-equal visit zero"}
    }
    for($travelIndex=0;$travelIndex-lt[Math]::Min(5,$travels.Count);$travelIndex+=1){
        $travel=$travels[$travelIndex]
        if(-not(Test-JsonObject $travel)){Add-Issue $issues "run $runIndex travel $travelIndex was not an object";continue}
        $source=if($travelIndex-lt$records.Count){$records[$travelIndex]}else{$null};$destination=if(($travelIndex+1)-lt$records.Count){$records[$travelIndex+1]}else{$null};$arrival=$travel.arrival_receipt
        foreach($field in @('source_id','from_world_node_id','from_environment_id','from_archetype_id','target_id','to_world_node_id','to_environment_id','to_archetype_id')){if(-not($travel.$field -is [string])-or[string]::IsNullOrWhiteSpace([string]$travel.$field)){Add-Issue $issues "run $runIndex travel $travelIndex $field was not a nonempty string"}}
        foreach($field in @('admitted_targets_before','admitted_targets_after_heat')){if(-not(Test-StringArray $travel.$field 3 -RequireUnique)){Add-Issue $issues "run $runIndex travel $travelIndex $field was not a unique nonempty string array within the three-target cap"}}
        foreach($field in @('admitted_targets_before_digest','admitted_targets_after_heat_digest','selected_choice_digest')){if(-not(Test-ExactSha256 $travel.$field)){Add-Issue $issues "run $runIndex travel $travelIndex $field was not an exact SHA-256 string"}}
        if($travel.admitted_targets_before-is[System.Array]-and(Test-ExactSha256 $travel.admitted_targets_before_digest)-and[string]$travel.admitted_targets_before_digest-cne(Get-Q009CanonicalJsonSha256 $travel.admitted_targets_before)){Add-Issue $issues "run $runIndex travel $travelIndex admitted_targets_before digest did not bind its exact ordered catalog"}
        if($travel.admitted_targets_after_heat-is[System.Array]-and(Test-ExactSha256 $travel.admitted_targets_after_heat_digest)-and[string]$travel.admitted_targets_after_heat_digest-cne(Get-Q009CanonicalJsonSha256 $travel.admitted_targets_after_heat)){Add-Issue $issues "run $runIndex travel $travelIndex admitted_targets_after_heat digest did not bind its exact ordered catalog"}
        if($travel.admitted_targets_before-is[System.Array]-and$travel.admitted_targets_after_heat-is[System.Array]){foreach($afterTarget in @($travel.admitted_targets_after_heat)){if(@($travel.admitted_targets_before|Where-Object{$_-is[string]-and$afterTarget-is[string]-and[string]$_-ceq[string]$afterTarget}).Count-ne1){Add-Issue $issues "run $runIndex travel $travelIndex post-heat admission introduced a target outside the exact pre-heat catalog"}}}
        if((Test-ExactPublicTravelChoice $travel.selected_choice)-and(Test-ExactSha256 $travel.selected_choice_digest)-and[string]$travel.selected_choice_digest-cne(Get-Q009CanonicalJsonSha256 $travel.selected_choice)){Add-Issue $issues "run $runIndex travel $travelIndex selected_choice digest did not bind its exact nested public choice"}
        if(-not(Test-ExactPublicTravelChoice $travel.selected_choice)-or-not(Test-ExactJsonStringPair $travel.selected_choice.id $travel.target_id)-or-not(Test-ExactBoolean $travel.selected_choice.enabled $true)){Add-Issue $issues "run $runIndex travel $travelIndex selected choice was not one exact enabled public choice for the target"}
        if($travel.admitted_targets_before -is [System.Array] -and @($travel.admitted_targets_before|Where-Object{$_ -is [string]-and[string]$_-ceq[string]$travel.target_id}).Count-ne1){Add-Issue $issues "run $runIndex travel $travelIndex target was not admitted exactly once before travel"}
        if($travel.admitted_targets_after_heat -is [System.Array] -and @($travel.admitted_targets_after_heat|Where-Object{$_ -is [string]-and[string]$_-ceq[string]$travel.target_id}).Count-ne1){Add-Issue $issues "run $runIndex travel $travelIndex target was not admitted exactly once after travel heat"}
        if($null-eq$source-or$null-eq$destination-or-not(Test-JsonObject $arrival)){Add-Issue $issues "run $runIndex travel $travelIndex lacked source/destination/arrival objects";continue}
        $sourceCatalogIds=if($source.travel_after_events-is[System.Array]){@($source.travel_after_events|ForEach-Object{if(Test-ExactPublicTravelChoice $_){[string]$_.id}else{''}})}else{@()}
        $admittedBefore=if($travel.admitted_targets_before-is[System.Array]){@($travel.admitted_targets_before)}else{@()}
        if(($sourceCatalogIds-join"`n")-cne($admittedBefore-join"`n")){Add-Issue $issues "run $runIndex travel $travelIndex admitted targets did not exactly equal the source post-event public catalog"}
        $selectedMatches=@($source.travel_after_events|Where-Object{(Test-ExactPublicTravelChoice $_)-and(Test-ExactJsonStringPair $_.id $travel.target_id)-and(Test-JsonDeepEqual $_ $travel.selected_choice)})
        if($selectedMatches.Count-ne1){Add-Issue $issues "run $runIndex travel $travelIndex selected choice was not the unique exact source-catalog member"}
        foreach($field in @('kind','source_id','travel_source_id','target_id','travel_target_id','installed_environment_id','installed_archetype_id','installed_world_node_id','travel_environment_id','travel_archetype_id','travel_world_node_id')){if(-not($arrival.$field -is [string])-or[string]::IsNullOrWhiteSpace([string]$arrival.$field)){Add-Issue $issues "run $runIndex travel $travelIndex arrival $field was not a nonempty string"}}
        foreach($field in @('installed_scenario_id','travel_scenario_id')){if(-not(Test-ExactJsonString $arrival.$field -AllowEmpty)){Add-Issue $issues "run $runIndex travel $travelIndex arrival $field was not an exact string"}}
        if(-not(Test-ExactBoolean $travel.ok $true) -or -not(Test-ExactInteger $travel.travel_index $travelIndex) -or -not(Test-ExactInteger $travel.from_visit_index $travelIndex) -or -not(Test-ExactInteger $travel.to_visit_index ($travelIndex+1)) -or -not(Test-SeedTupleMatches $travel $Run $AttemptId) -or -not(Test-SeedTupleMatches $arrival $Run $AttemptId) -or -not(Test-ExactArrivalStatus -Arrival $arrival -ExpectedKind 'travel' -ExpectedDestination $destination -ExpectedSource $source -ExpectedVisitIndex ($travelIndex+1) -ExpectedTravelIndex $travelIndex -ExpectedFromVisitIndex $travelIndex -ExpectedRun $Run -AttemptId $AttemptId)){Add-Issue $issues "run $runIndex travel $travelIndex tuple/order/status/identity contract failed"}
        if(-not(Test-ExactJsonStringPair $travel.source_id $source.world_node_id) -or -not(Test-ExactJsonStringPair $travel.from_world_node_id $source.world_node_id) -or -not(Test-ExactJsonStringPair $travel.from_environment_id $source.environment_id) -or -not(Test-ExactJsonStringPair $travel.from_archetype_id $source.archetype_id) -or -not(Test-ExactJsonStringPair $travel.target_id $destination.world_node_id) -or -not(Test-ExactJsonStringPair $travel.to_world_node_id $destination.world_node_id) -or -not(Test-ExactJsonStringPair $travel.to_environment_id $destination.environment_id) -or -not(Test-ExactJsonStringPair $travel.to_archetype_id $destination.archetype_id)){Add-Issue $issues "run $runIndex travel $travelIndex source/destination record linkage failed or was mistyped"}
        if(-not(Test-ExactJsonStringValue $arrival.kind 'travel') -or -not(Test-ExactInteger $arrival.travel_index $travelIndex) -or -not(Test-ExactInteger $arrival.from_visit_index $travelIndex) -or -not(Test-ExactInteger $arrival.visit_index ($travelIndex+1)) -or -not(Test-ExactJsonStringPair $arrival.source_id $source.world_node_id) -or -not(Test-ExactJsonStringPair $arrival.travel_source_id $source.world_node_id) -or -not(Test-ExactJsonStringPair $arrival.target_id $destination.world_node_id) -or -not(Test-ExactJsonStringPair $arrival.travel_target_id $destination.world_node_id) -or -not(Test-ExactJsonStringPair $arrival.installed_environment_id $destination.environment_id) -or -not(Test-ExactJsonStringPair $arrival.installed_archetype_id $destination.archetype_id) -or -not(Test-ExactJsonStringPair $arrival.installed_world_node_id $destination.world_node_id) -or -not(Test-ExactJsonStringPair $arrival.installed_scenario_id $destination.scenario_id -AllowEmpty) -or -not(Test-ExactJsonStringPair $arrival.travel_environment_id $destination.environment_id) -or -not(Test-ExactJsonStringPair $arrival.travel_archetype_id $destination.archetype_id) -or -not(Test-ExactJsonStringPair $arrival.travel_world_node_id $destination.world_node_id) -or -not(Test-ExactJsonStringPair $arrival.travel_scenario_id $destination.scenario_id -AllowEmpty)){Add-Issue $issues "run $runIndex travel $travelIndex raw arrival linkage failed or was mistyped"}
        foreach($flag in @('ok','travel_ok','production_scenario_finalized','production_boundary_valid','arrival_contract_shape_valid','travel_contract_shape_valid','installed','installed_finalized','source_binding_valid','target_binding_valid','current_install_binding_valid','travel_install_binding_valid','installed_projection_binding_valid','live_projection_binding_valid','installed_live_projection_binding_valid','travel_projection_binding_required','travel_projection_binding_valid','finalization_projection_binding_valid','independent_projection_binding_valid','projection_binding_valid','finalization_matches_runtime','runtime_layout_valid','finalization_clean')){if(-not(Test-ExactBoolean $arrival.$flag $true)){Add-Issue $issues "run $runIndex travel $travelIndex arrival flag $flag was not exact true"}}
        if(-not(Test-JsonDeepEqual $arrival $destination.arrival_receipt)){Add-Issue $issues "run $runIndex travel $travelIndex arrival receipt did not exactly equal its unique destination visit receipt"}
        if(-not(Test-JsonDeepEqual $travel.finalization_receipt $arrival.finalization)){Add-Issue $issues "run $runIndex travel $travelIndex finalization receipt was spliced"}
        if(-not(Test-JsonDeepEqual $arrival.runtime_scenario_layout $destination.runtime_scenario_layout)){Add-Issue $issues "run $runIndex travel $travelIndex arrival layout did not equal destination record layout"}
    }
    return @($issues|Sort-Object -Unique)
}

function Get-AuthorityReceipt {
    param([object]$EnvironmentRecord, [string]$Identity)
    $layout = $EnvironmentRecord.runtime_scenario_layout
    return @($layout.authority_receipts | Where-Object { (Test-ExactJsonString $_.identity) -and [string]$_.identity -ceq $Identity })
}

function Test-AuthorityReceipt {
    param(
        [object]$Receipt,
        [ValidateSet('semantic','base_record')][string]$ExpectedBranch,
        [switch]$AllowDisabled
    )
    if ($null -eq $Receipt) { return $false }
    if(
        -not (Test-ExactJsonStringValue $Receipt.authority_branch $ExpectedBranch) -or
        -not (Test-ExactBoolean $Receipt.authority_valid $true) -or
        -not (Test-ExactBoolean $Receipt.reachable $true) -or
        -not (Test-ExactBoolean $Receipt.presentation_required $true) -or
        -not (Test-ExactBoolean $Receipt.presentation_visible $true) -or
        -not (Test-ExactBoolean $Receipt.presentation_interactive $true) -or
        -not (Test-ExactBoolean $Receipt.runtime_visible $true) -or
        -not (Test-ExactBoolean $Receipt.runtime_interactive $true) -or
        -not (Test-ExactBoolean $Receipt.exact_sealed_authority $true) -or
        -not (Test-ExactBoolean $Receipt.sealed_geometry_valid $true) -or
        -not (Test-ExactBoolean $Receipt.action_authority_member $true) -or
        -not (Test-ExactBoolean $Receipt.action_authority_valid $true) -or
        -not (Test-ExactJsonString $Receipt.presentation_mode) -or
        [string]$Receipt.presentation_mode -notin @('room', 'overflow')
    ){return $false}
    $expectedBasis=''
    if($ExpectedBranch -ceq 'semantic'){
        $expectedBasis=if([string]$Receipt.presentation_mode -ceq 'room'){'layout_audit_room'}else{'layout_audit_overflow'}
        if(-not(Test-ExactBoolean $Receipt.semantic_interaction_member $true) -or -not(Test-ExactBoolean $Receipt.semantic_interaction_present $true) -or -not(Test-ExactBoolean $Receipt.semantic_interaction_sealed $true) -or -not(Test-ExactBoolean $Receipt.semantic_reachable $true) -or -not(Test-ExactBoolean $Receipt.base_reachable $false) -or -not(Test-ExactBoolean $Receipt.base_action_authority_member $false)){return $false}
    }else{
        $expectedBasis=if([string]$Receipt.presentation_mode -ceq 'room'){'sealed_base_room'}else{'sealed_base_overflow'}
        if(-not(Test-ExactBoolean $Receipt.semantic_interaction_member $false) -or -not(Test-ExactBoolean $Receipt.base_record_present $true) -or -not(Test-ExactBoolean $Receipt.base_record_sealed $true) -or -not(Test-ExactBoolean $Receipt.base_geometry_matches_seal $true) -or -not(Test-ExactBoolean $Receipt.base_action_authority_member $true) -or -not(Test-ExactBoolean $Receipt.base_reachable $true) -or -not(Test-ExactBoolean $Receipt.semantic_reachable $false)){return $false}
    }
    if(-not(Test-ExactJsonStringValue $Receipt.reachability_basis $expectedBasis)){return $false}
    if(Test-ExactBoolean $Receipt.runtime_enabled $true){
        return (Test-ExactBoolean $Receipt.action_authority_present $true) -and
            (Test-ExactBoolean $Receipt.actionable $true) -and
            ($Receipt.raw_action_count -is [int] -or $Receipt.raw_action_count -is [long]) -and
            [long]$Receipt.raw_action_count -gt 0 -and
            ($Receipt.enabled_action_count -is [int] -or $Receipt.enabled_action_count -is [long]) -and
            [long]$Receipt.enabled_action_count -gt 0 -and
            (Test-StringArray $Receipt.enabled_action_ids -RequireUnique) -and
            @($Receipt.enabled_action_ids).Count -eq [int]$Receipt.enabled_action_count
    }
    if(-not $AllowDisabled){return $false}
    return (Test-ExactBoolean $Receipt.disabled_authority_valid $true) -and
        (Test-ExactBoolean $Receipt.action_authority_present $false) -and
        (Test-ExactBoolean $Receipt.actionable $false) -and
        (Test-ExactInteger $Receipt.raw_action_count 0) -and
        (Test-ExactInteger $Receipt.enabled_action_count 0) -and
        (Test-StringArray $Receipt.enabled_action_ids -RequireUnique) -and
        @($Receipt.enabled_action_ids).Count -eq 0 -and
        (Test-ExactJsonString $Receipt.disabled_reason)
}

function Test-OrdinaryAuthorityReceiptCollection {
    param([AllowNull()][object]$Layout)
    if(-not(Test-JsonObject $Layout)-or-not($Layout.authority_receipts -is [System.Array])){return $false}
    $memberCount=0;$actionableCount=0;$invalidCount=0
    foreach($receipt in @($Layout.authority_receipts)){
        if(-not(Test-JsonObject $receipt)-or-not(Test-ExactJsonString $receipt.identity)){return $false}
        foreach($field in @('authority_valid','action_authority_member','action_authority_valid','actionable','runtime_enabled')){
            if(-not($receipt.$field -is [bool])){return $false}
        }
        if(-not(Test-StringArray $receipt.enabled_action_ids -RequireUnique)-or-not(Test-ExactInteger $receipt.enabled_action_count @($receipt.enabled_action_ids).Count)){return $false}
        if([bool]$receipt.action_authority_member){
            $memberCount+=1
            if([bool]$receipt.actionable){$actionableCount+=1}
            $branch=if(Test-ExactJsonStringValue $receipt.authority_branch 'semantic'){'semantic'}elseif(Test-ExactJsonStringValue $receipt.authority_branch 'base_record'){'base_record'}else{return $false}
            if(-not(Test-AuthorityReceipt -Receipt $receipt -ExpectedBranch $branch -AllowDisabled)){$invalidCount+=1}
        }else{
            if(-not(Test-ExactBoolean $receipt.authority_valid $true)-or-not(Test-ExactBoolean $receipt.action_authority_valid $true)-or-not(Test-ExactBoolean $receipt.actionable $false)){return $false}
        }
    }
    return (Test-ExactInteger $Layout.action_authority_member_count $memberCount) -and
        (Test-ExactInteger $Layout.actionable_authority_count $actionableCount) -and
        (Test-ExactInteger $Layout.invalid_action_authority_count $invalidCount) -and
        (Test-ExactInteger $Layout.invalid_action_authority_count 0) -and
        (Test-ExactBoolean $Layout.action_authority_contract_valid $true)
}

function Get-AuditEnvelopeIssues {
    param(
        [object]$Report,
        [string]$AttemptId,
        [int]$ExpectedRuns,
        [int]$ExpectedVisits,
        [int]$ExpectedTravels,
        [switch]$CustodyOnly
    )
    $issues = [System.Collections.Generic.List[string]]::new()
    $requiredKeys=@(
        'aggregate','attempt_id','attempt_id_required','attempt_id_valid','crew_state_unchanged',
        'environment_records','evidence_schema_version','exact_seed_requested','failure_count','failures',
        'generated_at_unix','installed_finalized_visit_count','method','native_diagnostics','native_diagnostics_clean',
        'passed','private_state_evidence_policy','requested_seed_text','requested_total_travel_count',
        'requested_total_visit_count','requested_visits_satisfied','run_count','runs','seed_prefix',
        'successful_linked_travel_count','tool','tool_failure_count','tool_warning_count','travel_records',
        'travels_per_run_target','visits_per_run_target','warning_count','warnings','warnings_clean'
    )|Sort-Object
    $actualKeys=@($Report.PSObject.Properties.Name|Sort-Object)
    if(($actualKeys -join "`n") -cne ($requiredKeys -join "`n")){Add-Issue $issues 'top-level evidence fields were missing, duplicated, extra, or renamed'}
    if (-not (Test-ExactJsonStringValue $Report.tool 'environment_generation_audit')) { Add-Issue $issues 'wrong or mistyped audit tool identity' }
    if (-not (Test-ExactInteger $Report.evidence_schema_version 2)) { Add-Issue $issues 'evidence schema must be integer 2' }
    if (-not (Test-ExactJsonStringValue $Report.attempt_id $AttemptId)) { Add-Issue $issues 'attempt id did not echo as an exact string' }
    foreach($field in @('private_state_evidence_policy','requested_seed_text','seed_prefix')){if(-not(Test-ExactJsonString $Report.$field -AllowEmpty)){Add-Issue $issues "$field was not a JSON string"}}
    if (-not (Test-ExactBoolean $Report.attempt_id_required $true) -or -not (Test-ExactBoolean $Report.attempt_id_valid $true)) { Add-Issue $issues 'attempt-id contract was not enforced' }
    $expectedExactSeedRequested=$ExpectedRuns-eq1
    if(-not(Test-ExactBoolean $Report.exact_seed_requested $expectedExactSeedRequested)){Add-Issue $issues 'exact_seed_requested did not have the exact boolean mode value'}
    if(-not(Test-ExactPositiveJsonDecimal $Report.generated_at_unix)){Add-Issue $issues 'generated_at_unix was not an exact positive fractional JSON number parsed as System.Decimal'}
    if($expectedExactSeedRequested-and[string]::IsNullOrWhiteSpace([string]$Report.requested_seed_text)){Add-Issue $issues 'exact-seed evidence omitted requested_seed_text'}
    if(-not$expectedExactSeedRequested-and-not[string]::IsNullOrEmpty([string]$Report.requested_seed_text)){Add-Issue $issues 'prefix generation falsely reported an exact seed'}
    if (-not (Test-ExactInteger $Report.run_count $ExpectedRuns)) { Add-Issue $issues "run_count must be $ExpectedRuns" }
    if (-not (Test-ExactInteger $Report.visits_per_run_target 6)) { Add-Issue $issues 'visits_per_run_target must be integer 6' }
    if (-not (Test-ExactInteger $Report.travels_per_run_target 5)) { Add-Issue $issues 'travels_per_run_target must be integer 5' }
    if (-not (Test-ExactInteger $Report.requested_total_visit_count $ExpectedVisits)) { Add-Issue $issues "requested visit count must be $ExpectedVisits" }
    if (-not (Test-ExactInteger $Report.requested_total_travel_count $ExpectedTravels)) { Add-Issue $issues "requested travel count must be $ExpectedTravels" }
    foreach($field in @('runs','environment_records','travel_records','failures','warnings','method')){if(-not($Report.$field -is [System.Array])){Add-Issue $issues "$field was not a JSON array"}}
    if($Report.method -is [System.Array] -and -not(Test-StringArray $Report.method -RequireUnique)){Add-Issue $issues 'method was not an exact unique string array'}
    foreach($field in @('aggregate','native_diagnostics')){if(-not(Test-JsonObject $Report.$field)){Add-Issue $issues "$field was not a JSON object"}}
    if (@($Report.runs).Count -ne $ExpectedRuns) { Add-Issue $issues 'run array count changed' }
    if(-not $CustodyOnly){
        if (@($Report.environment_records).Count -ne $ExpectedVisits) { Add-Issue $issues 'environment record count changed' }
        if (@($Report.travel_records).Count -ne $ExpectedTravels) { Add-Issue $issues 'travel record count changed' }
    }
    return @($issues)
}

function Get-AuditSemanticIssues {
    param(
        [object]$Report,
        [string]$AttemptId,
        [int]$ExpectedRuns,
        [int]$ExpectedVisits,
        [int]$ExpectedTravels,
        [AllowNull()][object]$Expectation = $null,
        [AllowNull()][object]$LegalCombination = $null,
        [string]$RawJson = ''
    )
    $issues = [System.Collections.Generic.List[string]]::new()
    foreach ($issue in @(Get-AuditEnvelopeIssues $Report $AttemptId $ExpectedRuns $ExpectedVisits $ExpectedTravels)) { Add-Issue $issues $issue }
    if (-not (Test-ExactBoolean $Report.requested_visits_satisfied $true)) { Add-Issue $issues 'report did not satisfy requested visits' }
    if (-not (Test-ExactInteger $Report.installed_finalized_visit_count $ExpectedVisits)) { Add-Issue $issues 'installed/finalized visit total changed' }
    if (-not (Test-ExactInteger $Report.successful_linked_travel_count $ExpectedTravels)) { Add-Issue $issues 'linked travel total changed' }
    if (-not (Test-ExactBoolean $Report.crew_state_unchanged $true)) { Add-Issue $issues 'Crew state changed during a Crew-no-op audit' }
    if (-not (Test-ExactJsonStringValue $Report.private_state_evidence_policy 'digest_only')) { Add-Issue $issues 'private-state evidence policy is not an exact digest_only string' }
    if (-not (Test-ExactBoolean $Report.native_diagnostics_clean $true)) { Add-Issue $issues 'native receipt diagnostics were not clean' }
    foreach($nativeIssue in @(Get-NativeDiagnosticSchemaIssues $Report.native_diagnostics $ExpectedVisits)){Add-Issue $issues $nativeIssue}
    if(Test-JsonObject $Report.native_diagnostics){foreach($name in $nativeDiagnosticCountKeys){if($name-ne'receipt_count'-and-not(Test-ExactInteger $Report.native_diagnostics.$name 0)){Add-Issue $issues "native diagnostic $name was nonzero"}}}
    if (-not (Test-ExactBoolean $Report.warnings_clean $true)) { Add-Issue $issues 'warning contract was not clean' }
    if (-not (Test-ExactBoolean $Report.passed $true)) { Add-Issue $issues 'report passed was not exact true' }
    if (-not (Test-ExactInteger $Report.failure_count 0) -or @($Report.failures).Count -ne 0) { Add-Issue $issues 'report contains failures' }
    if (-not (Test-ExactInteger $Report.warning_count 0) -or @($Report.warnings).Count -ne 0) { Add-Issue $issues 'report contains warnings' }
    if ($RawJson -and (Test-PrivateEvidenceLeak $RawJson)) { Add-Issue $issues 'report serialized a forbidden private gameplay field' }

    $runs = @($Report.runs)
    for ($index = 0; $index -lt $runs.Count; $index += 1) {
        $run = $runs[$index]
        if (-not (Test-ExactInteger $run.run_index $index)) { Add-Issue $issues "run index $index is missing or out of order" }
        if (-not(Test-SeedTupleMatches $run $run $AttemptId)) { Add-Issue $issues "run $index seed/attempt identity tuple mismatch" }
        if(-not(Test-ExactBoolean $run.attempt_id_required $true) -or -not(Test-ExactBoolean $run.attempt_id_valid $true)){Add-Issue $issues "run $index attempt contract was not required/valid"}
        if (-not (Test-ExactBoolean $run.seed_binding_valid $true) -or -not (Test-ExactBoolean $run.seed_binding_satisfied $true)) { Add-Issue $issues "run $index seed/challenge binding invalid" }
        if (-not(Test-ExactJsonStringPair $run.seed $run.seed_text) -or -not(Test-ExactJsonStringPair $run.seed $run.requested_seed_text)) { Add-Issue $issues "run $index seed text drift or mistype" }
        if (-not(Test-ExactJsonStringPair $run.challenge_key $run.expected_challenge_key) -or -not($run.seed_value -is [int] -or $run.seed_value -is [long]) -or -not($run.expected_seed_value -is [int] -or $run.expected_seed_value -is [long]) -or [long]$run.seed_value -ne [long]$run.expected_seed_value) { Add-Issue $issues "run $index challenge derivation drift or mistype" }
        if (-not(Test-ExactJsonStringValue $run.stopped_reason 'completed')) { Add-Issue $issues "run $index did not complete with an exact status string" }
        foreach ($pair in @(@('requested_visit_count',6),@('environment_count',6),@('installed_finalized_visit_count',6),@('identity_bound_visit_count',6),@('identity_bound_visited_summary_count',6),@('requested_travel_count',5),@('travel_count',5),@('travel_record_count',5),@('successful_linked_travel_count',5),@('terminal_visit_count',0))) {
            if (-not (Test-ExactInteger $run.($pair[0]) ([long]$pair[1]))) { Add-Issue $issues "run $index $($pair[0]) must be $($pair[1])" }
        }
        if (-not(Test-ExactIntegerRangeArray $run.visit_indices 0 6) -or -not(Test-ExactIntegerRangeArray $run.travel_indices 0 5)) { Add-Issue $issues "run $index visit/travel indices were not exact ordered unique integer arrays" }
        if (-not (Test-ExactBoolean $run.contiguous_visit_indices $true) -or -not (Test-ExactBoolean $run.contiguous_travel_indices $true) -or -not (Test-ExactBoolean $run.requested_visits_satisfied $true)) { Add-Issue $issues "run $index continuity contract failed" }
        if (-not (Test-ExactBoolean $run.crew_state_unchanged $true) -or -not(Test-ExactJsonStringPair $run.crew_state_before_sha256 $run.crew_state_after_sha256) -or ([string]$run.crew_state_before_sha256).Length -ne 64) { Add-Issue $issues "run $index Crew digest changed or was mistyped" }
        if(-not(Test-SeedTupleMatches $run.initial_arrival_receipt $run $AttemptId)){Add-Issue $issues "run $index initial arrival seed/attempt tuple drifted"}
        foreach($visited in @($run.visited)){if(-not(Test-SeedTupleMatches $visited $run $AttemptId)){Add-Issue $issues "run $index visited summary seed/attempt tuple drifted"}}
    }

    $environmentRecords=@($Report.environment_records)
    for($globalIndex=0;$globalIndex -lt $environmentRecords.Count;$globalIndex+=1){
        $expectedRunIndex=[Math]::Floor($globalIndex/6);$expectedVisitIndex=$globalIndex%6;$record=$environmentRecords[$globalIndex]
        if(-not(Test-ExactInteger $record.run_index $expectedRunIndex) -or -not(Test-ExactInteger $record.visit_index $expectedVisitIndex)){Add-Issue $issues "environment record $globalIndex was duplicated, missing, or out of order"}
    }
    $travelRecords=@($Report.travel_records)
    for($globalIndex=0;$globalIndex -lt $travelRecords.Count;$globalIndex+=1){
        $expectedRunIndex=[Math]::Floor($globalIndex/5);$expectedTravelIndex=$globalIndex%5;$travel=$travelRecords[$globalIndex]
        if(-not(Test-ExactInteger $travel.run_index $expectedRunIndex) -or -not(Test-ExactInteger $travel.travel_index $expectedTravelIndex) -or -not(Test-ExactInteger $travel.from_visit_index $expectedTravelIndex) -or -not(Test-ExactInteger $travel.to_visit_index ($expectedTravelIndex+1))){Add-Issue $issues "travel record $globalIndex was duplicated, missing, or out of order"}
    }
    foreach($run in $runs){foreach($crossIssue in @(Get-RunCrossBindingIssues $run $environmentRecords $travelRecords $AttemptId)){Add-Issue $issues $crossIssue}}

    $observedArrivalErrorTotal=[long]0;$observedTravelErrorTotal=[long]0
    foreach ($record in $environmentRecords) {
        $recordRunIndex=if($record.run_index -is [int] -or $record.run_index -is [long]){[int]$record.run_index}else{-1};$recordRun=if($recordRunIndex-ge0-and$recordRunIndex-lt$runs.Count){$runs[$recordRunIndex]}else{$null}
        if (-not(Test-SeedTupleMatches $record $recordRun $AttemptId) -or -not(Test-SeedTupleMatches $record.arrival_receipt $recordRun $AttemptId)) { Add-Issue $issues 'environment or nested arrival seed/attempt tuple drift' }
        if (-not (Test-ExactBoolean $record.installed_finalized $true)) { Add-Issue $issues 'environment was not installed/finalized' }
        $arrival = $record.arrival_receipt
        $layout = $record.runtime_scenario_layout
        if(-not(Test-ExactArrivalErrorShape $arrival)){Add-Issue $issues 'arrival errors collection/count was malformed'}
        else{$observedArrivalErrorTotal+=[long]$arrival.arrival_error_count;$observedTravelErrorTotal+=[long]$arrival.travel_error_count}
        if(-not(Test-ExactRuntimeLayoutAuthorityShape $layout $arrival.finalization)){Add-Issue $issues 'runtime layout authority receipts did not bind exactly to finalized authority'}
        if (
            -not (Test-ExactBoolean $arrival.installed_finalized $true) -or
            -not (Test-ExactBoolean $arrival.installed $true) -or
            -not (Test-ExactBoolean $arrival.production_boundary_valid $true) -or
            -not (Test-ExactBoolean $arrival.arrival_contract_shape_valid $true) -or
            -not (Test-ExactBoolean $arrival.travel_contract_shape_valid $true) -or
            -not (Test-ExactBoolean $arrival.source_binding_valid $true) -or
            -not (Test-ExactBoolean $arrival.target_binding_valid $true) -or
            -not (Test-ExactBoolean $arrival.current_install_binding_valid $true) -or
            -not (Test-ExactBoolean $arrival.travel_install_binding_valid $true) -or
            -not (Test-ExactBoolean $arrival.installed_projection_binding_valid $true) -or
            -not (Test-ExactBoolean $arrival.live_projection_binding_valid $true) -or
            -not (Test-ExactBoolean $arrival.installed_live_projection_binding_valid $true) -or
            -not (Test-ExactBoolean $arrival.travel_projection_binding_valid $true) -or
            -not (Test-ExactBoolean $arrival.finalization_projection_binding_valid $true) -or
            -not (Test-ExactBoolean $arrival.independent_projection_binding_valid $true) -or
            -not (Test-ExactBoolean $arrival.projection_binding_valid $true) -or
            -not (Test-ExactBoolean $arrival.finalization_matches_runtime $true) -or
            -not (Test-ExactBoolean $arrival.finalization_clean $true) -or
            -not (Test-ExactBoolean $arrival.runtime_layout_valid $true)
        ) { Add-Issue $issues 'arrival installed/live/travel/finalization binding contract failed' }
        if(
            -not(Test-ExactJsonString $arrival.installed_projection_fingerprint) -or ([string]$arrival.installed_projection_fingerprint).Length -ne 64 -or
            -not(Test-ExactJsonStringPair $arrival.installed_projection_fingerprint $arrival.live_projection_fingerprint) -or
            -not(Test-ExactJsonString $arrival.kind) -or -not(Test-ExactBoolean $arrival.travel_projection_binding_required ([string]$arrival.kind -cne 'initial')) -or
            ((Test-ExactBoolean $arrival.travel_projection_binding_required $true) -and (-not(Test-ExactJsonString $arrival.travel_projection_fingerprint) -or ([string]$arrival.travel_projection_fingerprint).Length -ne 64)) -or
            ((Test-ExactBoolean $arrival.finalization.inactive $true) -and (-not(Test-ExactJsonStringValue $arrival.finalization_projection_fingerprint '') -or -not(Test-ExactJsonStringValue $arrival.independent_projection_fingerprint $inactiveIndependentProjectionFingerprint))) -or
            ((Test-ExactBoolean $arrival.finalization.inactive $false) -and (-not(Test-ExactJsonString $arrival.finalization_projection_fingerprint) -or ([string]$arrival.finalization_projection_fingerprint).Length -ne 64 -or -not(Test-ExactJsonString $arrival.independent_projection_fingerprint) -or ([string]$arrival.independent_projection_fingerprint).Length -ne 64 -or [string]$arrival.independent_projection_fingerprint -ceq $inactiveIndependentProjectionFingerprint)) -or
            -not($arrival.finalization.inactive -is [bool])
        ){Add-Issue $issues 'arrival projection fingerprints were absent or inconsistent'}
        if(
            -not (Test-ExactBoolean $arrival.finalization.ok $true) -or
            -not($arrival.finalization.inactive -is [bool]) -or
            -not (Test-ExactBoolean $arrival.finalization.contract_shape_valid $true) -or
            -not (Test-ExactBoolean $arrival.finalization.projection_binding_valid $true) -or
            -not (Test-ExactInteger $arrival.finalization.warning_count 0) -or
            -not (Test-ExactInteger $arrival.finalization.error_count 0) -or
            @($arrival.finalization.warnings).Count -ne 0 -or @($arrival.finalization.errors).Count -ne 0
        ){Add-Issue $issues 'finalization receipt was not exact and clean'}
        if(-not (Test-ExactBoolean $arrival.finalization.inactive $true)){
            if (-not (Test-ExactBoolean $layout.action_authority_contract_valid $true) -or -not (Test-ExactBoolean $layout.layout_audit_valid $true) -or -not (Test-ExactBoolean $layout.authority_count_matches_audit $true) -or -not (Test-ExactBoolean $layout.authority_digest_matches_audit $true) -or -not (Test-ExactBoolean $layout.renderer_digest_matches_authority $true)) { Add-Issue $issues 'runtime scenario-layout authority contract failed' }
            if (-not(Test-ExactJsonString $layout.semantic_digest) -or ([string]$layout.semantic_digest).Length -ne 64 -or -not(Test-ExactJsonString $layout.authority_digest) -or ([string]$layout.authority_digest).Length -ne 64) { Add-Issue $issues 'runtime scenario-layout digest missing or mistyped' }
        }
    }
    if(Test-JsonObject $Report.native_diagnostics){
        if(-not(Test-ExactInteger $Report.native_diagnostics.arrival_error_count $observedArrivalErrorTotal)-or-not(Test-ExactInteger $Report.native_diagnostics.travel_error_count $observedTravelErrorTotal)){Add-Issue $issues 'native arrival/travel error totals did not equal every unique visit receipt'}
    }
    foreach ($travel in $travelRecords) {
        $travelRunIndex=if($travel.run_index -is [int] -or $travel.run_index -is [long]){[int]$travel.run_index}else{-1};$travelRun=if($travelRunIndex-ge0-and$travelRunIndex-lt$runs.Count){$runs[$travelRunIndex]}else{$null}
        if (-not(Test-SeedTupleMatches $travel $travelRun $AttemptId) -or -not(Test-SeedTupleMatches $travel.arrival_receipt $travelRun $AttemptId) -or -not(Test-ExactArrivalErrorShape $travel.arrival_receipt) -or -not(Test-ExactRuntimeLayoutAuthorityShape $travel.arrival_receipt.runtime_scenario_layout $travel.arrival_receipt.finalization) -or -not (Test-ExactBoolean $travel.ok $true) -or -not (Test-ExactBoolean $travel.linked_to_recorded_visits $true)) { Add-Issue $issues 'travel or nested arrival identity/error/authority/link contract failed' }
        if ([int]$travel.to_visit_index -ne ([int]$travel.from_visit_index + 1) -or [int]$travel.travel_index -ne [int]$travel.from_visit_index) { Add-Issue $issues 'travel visit indices are not adjacent' }
    }

    $targetRecords=@()
    if ($null -ne $Expectation) {
        foreach($field in @('seed','destination','scenario_id','required_marker','required_interaction')){if(-not(Test-ExactJsonString $Expectation.$field)){Add-Issue $issues "historical expectation $field was not a nonempty string"}}
        foreach($field in @('required_object','conflict_identity')){if($Expectation.PSObject.Properties.Name-contains$field-and-not(Test-ExactJsonString $Expectation.$field -AllowEmpty)){Add-Issue $issues "historical expectation $field was not a string"}}
        $seed = [string]$Expectation.seed
        if ($runs.Count -ne 1 -or -not(Test-ExactJsonStringValue $runs[0].seed $seed)) { Add-Issue $issues "historical report seed did not equal $seed as an exact string" }
        $targetRecords = @($Report.environment_records | Where-Object {
            (Test-ExactJsonStringValue $_.seed $seed) -and
            (Test-ExactJsonStringPair $_.archetype_id $Expectation.destination) -and
            (Test-ExactJsonStringPair $_.scenario_id $Expectation.scenario_id) -and
            (Test-StringArray $_.events -RequireUnique) -and @($_.events) -ccontains [string]$Expectation.required_marker
        })
        if (-not [string]::IsNullOrWhiteSpace([string]$Expectation.required_object)) {
            $targetRecords = @($targetRecords | Where-Object { (Test-StringArray $_.events -RequireUnique) -and @($_.events) -ccontains [string]$Expectation.required_object })
        }
        if ($targetRecords.Count -ne 1) { Add-Issue $issues 'historical target/scenario/marker composition was not observed exactly once' }
        else {
            $authorityRecord = $targetRecords[0]
            if(-not(Test-JsonDeepEqual $authorityRecord.runtime_scenario_layout $authorityRecord.arrival_receipt.runtime_scenario_layout)){Add-Issue $issues 'historical authority layout did not bind to the arrival receipt'}
            $arrivalAuthorityRecord=[pscustomobject]@{runtime_scenario_layout=$authorityRecord.arrival_receipt.runtime_scenario_layout}
            $requiredReceipt = @(Get-AuthorityReceipt $arrivalAuthorityRecord ([string]$Expectation.required_interaction))
            if ($requiredReceipt.Count -ne 1 -or -not (Test-AuthorityReceipt $requiredReceipt[0] 'semantic')) { Add-Issue $issues 'required semantic interaction lacked enabled finalized action authority/reachability' }
            if (-not [string]::IsNullOrWhiteSpace([string]$Expectation.conflict_identity)) {
                $conflictReceipt = @(Get-AuthorityReceipt $arrivalAuthorityRecord ([string]$Expectation.conflict_identity))
                if ($conflictReceipt.Count -ne 1 -or -not (Test-AuthorityReceipt $conflictReceipt[0] 'base_record' -AllowDisabled)) { Add-Issue $issues 'projected base conflict identity lacked unique sealed reachable authority' }
            }
        }
        $targetTravels=@()
        if($targetRecords.Count-eq1){
            $target=$targetRecords[0]
            $targetTravels=@($Report.travel_records|Where-Object{
                (Test-ExactJsonStringValue $_.seed $seed) -and [int]$_.run_index-eq[int]$target.run_index -and [int]$_.to_visit_index-eq[int]$target.visit_index -and
                (Test-ExactJsonStringPair $_.target_id $target.world_node_id) -and (Test-ExactJsonStringPair $_.to_world_node_id $target.world_node_id) -and
                (Test-ExactJsonStringPair $_.to_environment_id $target.environment_id) -and (Test-ExactJsonStringPair $_.to_archetype_id $target.archetype_id) -and
                (Test-JsonDeepEqual $_.arrival_receipt $target.arrival_receipt)
            })
        }
        if ($targetTravels.Count -ne 1) { Add-Issue $issues 'historical destination lacked one exact incoming recorded travel' }
    }

    if ($null -ne $LegalCombination) {
        foreach($field in @('seed','destination','scenario_id','phase_id','base_event_id','base_slot_id','scenario_identity')){if(-not(Test-ExactJsonString $LegalCombination.$field)){Add-Issue $issues "legal-room expectation $field was not a nonempty string"}}
        $comboRecords = @($Report.environment_records | Where-Object {
            (Test-ExactJsonStringPair $_.seed $LegalCombination.seed) -and
            (Test-ExactJsonStringPair $_.archetype_id $LegalCombination.destination) -and
            (Test-ExactJsonStringPair $_.scenario_id $LegalCombination.scenario_id) -and
            (Test-ExactJsonStringPair $_.runtime_scenario_layout.phase_id $LegalCombination.phase_id) -and
            (Test-StringArray $_.events -RequireUnique) -and @($_.events) -ccontains [string]$LegalCombination.base_event_id
        })
        $comboValid = $false
        foreach ($record in $comboRecords) {
            if(-not(Test-JsonDeepEqual $record.runtime_scenario_layout $record.arrival_receipt.runtime_scenario_layout)){continue}
            $arrivalAuthorityRecord=[pscustomobject]@{runtime_scenario_layout=$record.arrival_receipt.runtime_scenario_layout}
            $scenarioReceipt = @(Get-AuthorityReceipt $arrivalAuthorityRecord ([string]$LegalCombination.scenario_identity))
            $expectedBaseObjectId = 'event:' + [string]$LegalCombination.base_event_id
            $expectedBaseIdentity = 'event::event:' + [string]$LegalCombination.base_event_id
            $baseReceipt = @($record.arrival_receipt.runtime_scenario_layout.authority_receipts | Where-Object { (Test-ExactJsonStringValue $_.identity $expectedBaseIdentity) -and (Test-ExactJsonStringPair $_.slot_id $LegalCombination.base_slot_id) -and (Test-ExactJsonStringValue $_.base_object_id $expectedBaseObjectId) })
            $destinationCandidates=@($targetRecords|Where-Object{[int]$_.run_index-eq[int]$record.run_index}|Sort-Object visit_index)
            $chronologyValid=$false
            if($destinationCandidates.Count-gt0){$targetVisit=[int]$destinationCandidates[0].visit_index;$comboVisit=[int]$record.visit_index;if($comboVisit-lt$targetVisit){$path=@($Report.travel_records|Where-Object{[int]$_.run_index-eq[int]$record.run_index-and[int]$_.from_visit_index-ge$comboVisit-and[int]$_.to_visit_index-le$targetVisit}|Sort-Object from_visit_index);$chronologyValid=$path.Count-eq($targetVisit-$comboVisit);for($step=$comboVisit;$chronologyValid-and$step-lt$targetVisit;$step+=1){$link=@($path|Where-Object{[int]$_.from_visit_index-eq$step-and[int]$_.to_visit_index-eq($step+1)});if($link.Count-ne1){$chronologyValid=$false}}}}
            if ($chronologyValid -and $scenarioReceipt.Count -eq 1 -and $baseReceipt.Count -eq 1 -and (Test-AuthorityReceipt $scenarioReceipt[0] 'semantic') -and (Test-AuthorityReceipt $baseReceipt[0] 'base_record' -AllowDisabled)) { $comboValid = $true; break }
        }
        if (-not $comboValid) { Add-Issue $issues 'seed 009 pre-destination legal room combination was not proved with base+scenario authority' }
    }
    return @($issues | Sort-Object -Unique)
}

function Get-StaticReportIssues {
    param([object]$Report)
    $issues = [System.Collections.Generic.List[string]]::new()
    $requiredTop=@('active_scenarios','complete_scenarios','contact_sheet','counts','day2_samples','error_count','errors','passed','tool')|Sort-Object
    $actualTop=@($Report.PSObject.Properties.Name|Sort-Object)
    if(($actualTop-join"`n")-cne($requiredTop-join"`n")){Add-Issue $issues 'static report top-level schema changed'}
    if (-not(Test-ExactJsonStringValue $Report.tool 'environment_fixed_slot_static_check')) { Add-Issue $issues 'static tool identity changed or was mistyped' }
    foreach($issue in @(Get-ExactNamedStringFieldIssues $Report @('tool','map_id','scenario_id','archetype_id','layer_id','phase_id','requested_scenario_id','selection_reason'))){Add-Issue $issues $issue}
    if (-not (Test-ExactBoolean $Report.passed $true) -or -not (Test-ExactInteger $Report.error_count 0) -or -not($Report.errors -is [System.Array]) -or @($Report.errors).Count -ne 0) { Add-Issue $issues 'static report contains errors or mistyped error fields' }
    $requiredCountKeys=@('active_bindings','active_nonphysical','active_nonphysical_room','active_overflow','active_overflow_rate','active_physical_room','active_snapshots','archetypes','authored_actions','authored_visuals','base_base_conflicts','base_base_pair_tests','base_label_slots','base_scenario_authorities','base_scenario_base_slot_observations','base_scenario_conflicts','base_scenario_legal_scenarios','base_scenario_pair_tests','base_scenario_snapshots','complete_bindings','complete_overflow','complete_snapshots','historical_exact_seeds','historical_legal_room_combinations','legal_hosts','mandatory_lane_obstacle_checks','mandatory_lane_obstacle_states','mandatory_lane_overflow_states','maps','scenarios')|Sort-Object
    $actualCountKeys=@($Report.counts.PSObject.Properties.Name|Sort-Object)
    if(($actualCountKeys-join"`n")-cne($requiredCountKeys-join"`n")){Add-Issue $issues 'static report count schema changed'}
    foreach($property in @($Report.counts.PSObject.Properties)){
        if($property.Name -eq 'active_overflow_rate'){
            $isFloating=$property.Value -is [double] -or $property.Value -is [decimal]
            $rate=if($isFloating){[double]$property.Value}else{[double]::NaN}
            if(-not$isFloating-or[double]::IsNaN($rate)-or[double]::IsInfinity($rate)-or$rate-lt0.0-or$rate-gt1.0){Add-Issue $issues 'active_overflow_rate was mistyped, non-finite, or out of range'}
        }elseif(-not($property.Value -is [int] -or $property.Value -is [long]) -or [long]$property.Value -lt 0){Add-Issue $issues "static count $($property.Name) was mistyped or negative"}
    }
    foreach ($pair in @(@('maps',21),@('archetypes',18),@('scenarios',55),@('legal_hosts',55),@('historical_exact_seeds',22),@('historical_legal_room_combinations',1))) {
        if (-not (Test-ExactInteger $Report.counts.($pair[0]) ([long]$pair[1]))) { Add-Issue $issues "static count $($pair[0]) must be $($pair[1])" }
    }
    foreach($field in @('active_scenarios','complete_scenarios','contact_sheet','day2_samples')){if(-not($Report.$field -is [System.Array])){Add-Issue $issues "static $field was not an array"}}
    $activeKeys=@($Report.active_scenarios|ForEach-Object{if((Test-ExactJsonString $_.map_id)-and(Test-ExactJsonString $_.scenario_id)){([string]$_.map_id)+'|'+([string]$_.scenario_id)}else{'|'}})
    $completeKeys=@($Report.complete_scenarios|ForEach-Object{if((Test-ExactJsonString $_.map_id)-and(Test-ExactJsonString $_.scenario_id)){([string]$_.map_id)+'|'+([string]$_.scenario_id)}else{'|'}})
    if ($activeKeys.Count -ne 55 -or @($activeKeys|Where-Object{$_ -match '^\|' -or $_ -match '\|$'}|Sort-Object -Unique).Count -ne 0 -or @($activeKeys|Sort-Object -Unique).Count -ne 55) { Add-Issue $issues 'active scenario identities must be 55 unique map/scenario pairs' }
    if ($completeKeys.Count -ne 55 -or @($completeKeys|Where-Object{$_ -match '^\|' -or $_ -match '\|$'}|Sort-Object -Unique).Count -ne 0 -or @($completeKeys|Sort-Object -Unique).Count -ne 55) { Add-Issue $issues 'complete scenario identities must be 55 unique map/scenario pairs' }
    if((@($activeKeys|Sort-Object)-join"`n")-cne(@($completeKeys|Sort-Object)-join"`n")){Add-Issue $issues 'active and complete scenario identity coverage diverged'}
    $contactIds=@($Report.contact_sheet|ForEach-Object{if(Test-ExactJsonString $_.archetype_id){[string]$_.archetype_id}else{''}})
    if($contactIds.Count-ne18-or@($contactIds|Where-Object{[string]::IsNullOrWhiteSpace($_)}).Count-ne0-or@($contactIds|Sort-Object -Unique).Count-ne18){Add-Issue $issues 'contact sheet must cover 18 unique room identities'}
    if(@($Report.contact_sheet|Where-Object{-not($_.day2_sample -is [bool])}).Count-ne0){Add-Issue $issues 'contact sheet day2_sample fields were mistyped'}
    $contactDay2=@($Report.contact_sheet|Where-Object{Test-ExactBoolean $_.day2_sample $true}|ForEach-Object{[string]$_.archetype_id})
    if(($contactDay2-join',')-cne'bar,corner_store,grand_casino'){Add-Issue $issues 'contact sheet day-2 modes changed'}
    $day2Ids=@($Report.day2_samples|ForEach-Object{if(Test-ExactJsonString $_.map_id){[string]$_.map_id}else{''}})
    if(($day2Ids-join',')-cne'corner_store,bar,grand_casino'){Add-Issue $issues 'day-2 sample identity/order changed'}
    if ([long]$Report.counts.active_snapshots -le 0 -or [long]$Report.counts.complete_snapshots -le 0 -or [long]$Report.counts.base_scenario_snapshots -le 0) { Add-Issue $issues 'normal/expanded snapshot counters are empty' }
    return @($issues)
}

function Get-EnvironmentSnapshot {
    return [ordered]@{
        APPDATA = [Environment]::GetEnvironmentVariable('APPDATA','Process')
        LOCALAPPDATA = [Environment]::GetEnvironmentVariable('LOCALAPPDATA','Process')
        XDG_DATA_HOME = [Environment]::GetEnvironmentVariable('XDG_DATA_HOME','Process')
        XDG_CACHE_HOME = [Environment]::GetEnvironmentVariable('XDG_CACHE_HOME','Process')
        XDG_CONFIG_HOME = [Environment]::GetEnvironmentVariable('XDG_CONFIG_HOME','Process')
    }
}

function Set-EnvironmentOverrides {
    param([System.Collections.IDictionary]$Overrides)
    foreach ($entry in $Overrides.GetEnumerator()) { [Environment]::SetEnvironmentVariable([string]$entry.Key,[string]$entry.Value,'Process') }
}

function Test-EnvironmentMatchesSnapshot {
    param([System.Collections.IDictionary]$Snapshot)
    foreach ($entry in $Snapshot.GetEnumerator()) {
        $current=[Environment]::GetEnvironmentVariable([string]$entry.Key,'Process')
        if($null -eq $entry.Value){if($null -ne $current){return $false}}
        elseif([string]$current -cne [string]$entry.Value){return $false}
    }
    return $true
}

function Assert-NoReparsePathChain {
    param([string]$Root,[string]$Path)
    $rootFull=[IO.Path]::GetFullPath($Root).TrimEnd('\','/')
    $pathFull=[IO.Path]::GetFullPath($Path).TrimEnd('\','/')
    if(-not[string]::Equals($pathFull,$rootFull,[StringComparison]::OrdinalIgnoreCase)-and-not$pathFull.StartsWith($rootFull+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw "Path escapes owned root: $pathFull"}
    $cursor=$pathFull
    while($true){
        if(Test-Path -LiteralPath $cursor){$item=Get-Item -LiteralPath $cursor -Force;if(($item.Attributes-band[IO.FileAttributes]::ReparsePoint)-ne0){throw "Reparse point is forbidden in owned path chain: $cursor"}}
        if([string]::Equals($cursor,$rootFull,[StringComparison]::OrdinalIgnoreCase)){break}
        $parent=[IO.Path]::GetDirectoryName($cursor)
        if([string]::IsNullOrWhiteSpace($parent)-or[string]::Equals($parent,$cursor,[StringComparison]::OrdinalIgnoreCase)){throw "Could not prove owned path ancestry: $pathFull"}
        $cursor=$parent.TrimEnd('\','/')
    }
}

function Assert-CanonicalLeaseRootPath {
    param([object]$RunContext)
    if(-not(Test-Q009RunContextShape $RunContext)){throw 'Canonical lease-root proof requires one exact sealed run context'}
    $actualRoot=[IO.Path]::GetFullPath([string]$RunContext.canonical_lease_root).TrimEnd('\','/')
    $expectedRoot=[IO.Path]::GetFullPath('D:\Projects\Beat-The-House-worktrees\.godot_leases').TrimEnd('\','/')
    if(-not[string]::Equals($actualRoot,$expectedRoot,[StringComparison]::OrdinalIgnoreCase)){throw "Canonical Q-009 lease root changed: $actualRoot"}
    Assert-NoReparsePathChain ([IO.Path]::GetDirectoryName($expectedRoot)) $actualRoot
    if(-not(Test-Q009FileSystemIdentityMatch $RunContext.canonical_lease_root_identity)){throw 'Canonical lease-root native identity drifted'}
}

function Assert-CanonicalLeaseRootBootstrap {
    param([string]$Path)
    $actual=[IO.Path]::GetFullPath($Path).TrimEnd('\','/')
    $expected=[IO.Path]::GetFullPath('D:\Projects\Beat-The-House-worktrees\.godot_leases').TrimEnd('\','/')
    if($actual-cne$expected){throw "Canonical Q-009 lease bootstrap path changed: $actual"}
    if(-not(Test-Path -LiteralPath $actual -PathType Container)){throw 'Canonical Q-009 lease root must preexist before run-context sealing'}
    Assert-NoReparsePathChain ([IO.Path]::GetDirectoryName($expected)) $actual
}

function Get-StrictLeaseFilesAtPath {
    param(
        [string]$DirectoryPath,
        [switch]$ForceEnumerationFailureForTest
    )
    $directoryFull = [IO.Path]::GetFullPath($DirectoryPath).TrimEnd('\','/')
    if (-not (Test-Path -LiteralPath $directoryFull -PathType Container)) {
        throw "Lease directory is missing or is not a directory: $directoryFull"
    }
    $directoryItem = Get-Item -LiteralPath $directoryFull -Force -ErrorAction Stop
    if (($directoryItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Lease directory is a forbidden reparse point: $directoryFull"
    }
    if ($ForceEnumerationFailureForTest) {
        throw "Forced lease enumeration failure for hostile validation: $directoryFull"
    }
    try {
        # Enumerate every matching object so a directory/junction/symlink named
        # *.lease cannot be hidden by a -File prefilter.
        $files = @(Get-ChildItem -LiteralPath $directoryFull -Filter '*.lease' -Force -ErrorAction Stop)
    }
    catch {
        throw "Lease directory enumeration failed closed for $directoryFull`: $($_.Exception.Message)"
    }
    foreach ($file in $files) {
        $fileFull = [IO.Path]::GetFullPath($file.FullName)
        Assert-NoReparsePathChain $directoryFull $fileFull
        $verified = Get-Item -LiteralPath $fileFull -Force -ErrorAction Stop
        if (-not ($verified -is [IO.FileInfo]) -or ($verified.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Lease enumeration returned a non-file or reparse point: $fileFull"
        }
    }
    return @($files)
}

function Get-CanonicalLeaseFilesStrict {
    param([object]$RunContext,[switch]$ExcludeExclusive)
    if(-not(Test-Q009RunContextShape $RunContext)){throw 'Canonical lease enumeration requires this attempt immutable run context'}
    Assert-CanonicalLeaseRootPath $RunContext
    $files = @(Get-StrictLeaseFilesAtPath ([string]$RunContext.canonical_lease_root))
    if ($ExcludeExclusive) {
        $exclusive=[IO.Path]::GetFullPath((Join-Path ([string]$RunContext.canonical_lease_root) 'EXCLUSIVE.lease'))
        return @($files | Where-Object { [IO.Path]::GetFullPath($_.FullName) -cne $exclusive })
    }
    return @($files)
}

function Assert-ExactAttemptOwner {
    param([string]$Path,[string]$ExpectedText,[string]$ExpectedSha256,[string]$OwnedRoot,[object]$OwnershipReceipt)
    if($null-eq$OwnershipReceipt-or-not(Test-Q009FileSystemIdentityShape $OwnershipReceipt.root_identity)-or-not(Test-Q009FileSystemIdentityShape $OwnershipReceipt.claim_identity)){throw 'Attempt-owner native root/claim receipt is missing or malformed'}
    if([string]$OwnershipReceipt.root_identity.path-cne[IO.Path]::GetFullPath($OwnedRoot).TrimEnd('\','/')-or-not[bool]$OwnershipReceipt.root_identity.is_directory-or-not(Test-Q009FileSystemIdentityMatch $OwnershipReceipt.root_identity)){throw 'Attempt evidence root native identity drifted'}
    if([string]$OwnershipReceipt.claim_identity.path-cne[IO.Path]::GetFullPath($Path)-or[bool]$OwnershipReceipt.claim_identity.is_directory-or-not(Test-Q009FileSystemIdentityMatch $OwnershipReceipt.claim_identity)){throw 'Attempt-owner claim native identity drifted'}
    Assert-NoReparsePathChain $OwnedRoot $Path
    if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){throw 'Attempt-owner claim disappeared'}
    $item=Get-Item -LiteralPath $Path -Force
    if(($item.Attributes-band[IO.FileAttributes]::ReparsePoint)-ne0){throw 'Attempt-owner claim became a reparse point'}
    $actual=[IO.File]::ReadAllText($Path,[Text.UTF8Encoding]::new($false))
    if($actual-cne$ExpectedText){throw 'Attempt-owner claim content drifted'}
    if((Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash-cne$ExpectedSha256){throw 'Attempt-owner claim hash drifted'}
}

function Get-StrictLeaseRecord {
    param([string]$Path,[object]$RunContext)
    if(-not(Test-Q009RunContextShape $RunContext)-or[IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($Path))-cne[string]$RunContext.canonical_lease_root){throw 'Lease parsing requires this attempt immutable canonical-root context'}
    Assert-CanonicalLeaseRootPath $RunContext;Assert-NoReparsePathChain ([string]$RunContext.canonical_lease_root) $Path
    $fileIdentity=Get-Q009FileSystemEntryIdentity $Path
    if([bool]$fileIdentity.is_directory){throw "Lease candidate is not a regular file: $Path"}
    $lines = [System.IO.File]::ReadAllLines($Path)
    $fields = @{}
    foreach ($line in $lines) {
        $separator = $line.IndexOf('=')
        if ($separator -le 0) { throw "Malformed lease line in $Path" }
        $key = $line.Substring(0,$separator)
        if ($fields.ContainsKey($key)) { throw "Duplicate lease field $key in $Path" }
        $fields[$key] = $line.Substring($separator+1)
    }
    foreach ($required in @('mode','pid','launcher_name','launcher_start_utc','launcher_start_ticks','launcher_key','worktree','candidate_commit','candidate_tree')) {
        if (-not $fields.ContainsKey($required) -or [string]::IsNullOrWhiteSpace([string]$fields[$required])) { throw "Lease lacks $required in $Path" }
    }
    if([string]$fields.mode-ceq'exclusive'-and(-not$fields.ContainsKey('attempt_id')-or[string]::IsNullOrWhiteSpace([string]$fields.attempt_id))){throw "EXCLUSIVE lease lacks attempt_id in $Path"}
    $pidValue = 0; $ticksValue = [long]0; $startUtc = [datetime]::MinValue
    if (-not [int]::TryParse([string]$fields.pid,[ref]$pidValue) -or $pidValue -le 0) { throw "Lease PID malformed in $Path" }
    if (-not [long]::TryParse([string]$fields.launcher_start_ticks,[ref]$ticksValue) -or $ticksValue -le 0) { throw "Lease start ticks malformed in $Path" }
    if (-not [datetime]::TryParse([string]$fields.launcher_start_utc,[ref]$startUtc) -or $startUtc.ToUniversalTime().Ticks -ne $ticksValue) { throw "Lease UTC start malformed in $Path" }
    $expectedKey = '{0}|{1}|{2}' -f $pidValue,$ticksValue,[string]$fields.launcher_name
    if ([string]$fields.launcher_key -cne $expectedKey) { throw "Lease identity key malformed in $Path" }
    if(-not(Test-Q009FileSystemIdentityMatch $fileIdentity)){throw "Lease file identity changed while its exact fields were being read: $Path"}
    return [ordered]@{ fields=$fields; identity=[ordered]@{pid=$pidValue;name=[string]$fields.launcher_name;start_utc=$startUtc.ToUniversalTime().ToString('o');start_ticks=$ticksValue;key=$expectedKey};file_identity=$fileIdentity }
}

function Get-CanonicalFocusedLeaseRecord {
    param([System.IO.FileInfo]$File,[object]$RunContext)
    if(-not(Test-Q009RunContextShape $RunContext)){throw 'Focused lease parsing requires one exact immutable run context'}
    Assert-CanonicalLeaseRootPath $RunContext;Assert-NoReparsePathChain ([string]$RunContext.canonical_lease_root) $File.FullName
    if($File.Name-ceq'EXCLUSIVE.lease'){throw 'Focused lease parser received EXCLUSIVE.lease'}
    $record=Get-StrictLeaseOwnerRecord -Lease $File
    if([string]$record.fields.mode-cne'focused'){throw "Focused lease mode mismatch: $($File.FullName)"}
    return [ordered]@{fields=$record.fields;pid=[int]$record.identity.pid;identity=$record.identity;file_identity=$record.file_identity;path=$File.FullName}
}

function Clear-ProvablyDeadWellFormedLeases {
    param([object]$RunContext,[switch]$ExcludeExclusive)
    if(-not(Test-Q009RunContextShape $RunContext)){throw 'Stale-lease cleanup requires one exact immutable run context'}
    Assert-CanonicalLeaseRootPath $RunContext
    $cleared = [System.Collections.Generic.List[string]]::new()
    $blockedMalformed = [System.Collections.Generic.List[string]]::new()
    foreach ($file in @(Get-CanonicalLeaseFilesStrict -RunContext $RunContext -ExcludeExclusive:$ExcludeExclusive)) {
        try {
            Assert-NoReparsePathChain ([string]$RunContext.canonical_lease_root) $file.FullName
            $fileIdentity=Get-Q009FileSystemEntryIdentity $file.FullName
            if([bool]$fileIdentity.is_directory){throw "Lease candidate is not a regular file: $($file.FullName)"}
            $isLive=$false
            if($file.Name-eq'EXCLUSIVE.lease'){
                $record=Get-StrictLeaseRecord $file.FullName $RunContext
                if([string]$record.fields.mode-cne'exclusive'){throw 'EXCLUSIVE lease mode mismatch'}
                $isLive=Test-LiveProcessMatchesIdentity $record.identity
            }else{
                $record=Get-CanonicalFocusedLeaseRecord $file $RunContext
                $isLive=Test-LiveProcessMatchesIdentity $record.identity
            }
            if (-not$isLive) {
                Assert-CanonicalLeaseRootPath $RunContext;Assert-NoReparsePathChain ([string]$RunContext.canonical_lease_root) $file.FullName
                Remove-Q009ExactOwnedFile -Path $file.FullName -ExpectedIdentity $fileIdentity
                [void]$cleared.Add($file.FullName)
            }
        }
        catch { [void]$blockedMalformed.Add($file.FullName) }
    }
    return [ordered]@{ cleared=@($cleared); malformed=@($blockedMalformed) }
}

function Assert-ExactExclusiveLease {
    param([object]$HeldExclusiveLease,[object]$RunContext)
    Assert-CanonicalLeaseRootPath $RunContext
    [void](Assert-Q009HeldExclusiveLease $HeldExclusiveLease $RunContext)
}

function New-TrackedExclusiveLeaseFile {
    param([string]$Path,[string]$Text,[System.Collections.IDictionary]$Ownership)
    if(-not(Test-ExclusiveLeaseOwnershipShape $Ownership $false $Path)){throw 'EXCLUSIVE lease ownership tracker was malformed before CreateNew'}
    # New-OwnedLeaseFile flips shared ownership immediately after CreateNew,
    # before write/flush/close.  A partial reservation therefore remains
    # accounted for even if both the write and its exact removal fail.
    New-OwnedLeaseFile -Path $Path -Text $Text -Ownership $Ownership
    if(-not(Test-ExclusiveLeaseOwnershipShape $Ownership $true $Path)-or-not(Test-Q009FileSystemIdentityMatch $Ownership.identity)){throw 'EXCLUSIVE lease CreateNew/write/native ownership was not sealed'}
}

function Test-ExclusiveLeaseOwnershipShape {
    param([AllowNull()][object]$Ownership,[bool]$RequireOwned,[string]$ExpectedPath)
    if(-not(Test-Q009ExactPublicReceiptKeys $Ownership @('created','validated','path','identity','write_complete','removal_failed','removal_error'))){return $false}
    if([string]::IsNullOrWhiteSpace($ExpectedPath)-or$Ownership.created-isnot[bool]-or$Ownership.validated-isnot[bool]-or$Ownership.path-isnot[string]-or[string]::IsNullOrWhiteSpace([string]$Ownership.path)-or[IO.Path]::GetFullPath([string]$Ownership.path)-cne[IO.Path]::GetFullPath($ExpectedPath)-or$Ownership.write_complete-isnot[bool]-or$Ownership.removal_failed-isnot[bool]-or$Ownership.removal_error-isnot[string]){return $false}
    if($RequireOwned){return [bool]$Ownership.created-and[bool]$Ownership.write_complete-and-not[bool]$Ownership.removal_failed-and(Test-Q009FileSystemIdentityShape $Ownership.identity)-and-not[bool]$Ownership.identity.is_directory-and[string]$Ownership.identity.path-ceq[IO.Path]::GetFullPath($ExpectedPath)}
    if([bool]$Ownership.created){return (Test-Q009FileSystemIdentityShape $Ownership.identity)-and-not[bool]$Ownership.identity.is_directory}
    return $null-eq$Ownership.identity
}

function Get-ExclusiveWaitDisposition {
    param([int]$OtherLeaseCount,[int]$GodotCount,[int]$MalformedLeaseCount)
    if($OtherLeaseCount-lt0-or$GodotCount-lt0-or$MalformedLeaseCount-lt0){throw 'EXCLUSIVE wait census counts must be nonnegative'}
    if($MalformedLeaseCount-gt0){return 'invalid'}
    if($OtherLeaseCount-gt0-or$GodotCount-gt0){return 'wait'}
    return 'ready'
}

function Invoke-Q009MutexCritical {
    param([scriptblock]$Body,[object]$RunContext,[int]$WaitMilliseconds=5000,[string]$MutexName='',[switch]$ForceTeardownFailureForTest)
    if(-not(Test-Q009RunContextShape $RunContext)){throw 'Q-009 launch mutex requires one exact sealed run context'}
    if([string]::IsNullOrWhiteSpace($MutexName)){$MutexName=[string]$RunContext.launch_mutex_name}
    $mutex=$null;$owned=$false;$result=$null;$primaryError='';$teardownError=''
    try{
        $mutex=[Threading.Mutex]::new($false,$MutexName)
        try{$owned=$mutex.WaitOne($WaitMilliseconds)}catch [Threading.AbandonedMutexException] {$owned=$true;throw 'Q-009 launch mutex was abandoned; ownership was recovered only for safe release'}
        if(-not$owned){throw 'Could not acquire the Q-009 launch mutex within the bounded wait'}
        $result=&$Body
    }catch{$primaryError=$_.Exception.Message}
    finally{
        if($owned-and$null-ne$mutex){try{$mutex.ReleaseMutex()}catch{$teardownError=Join-LauncherError $teardownError ('mutex release: '+$_.Exception.Message)}}
        if($null-ne$mutex){try{$mutex.Dispose()}catch{$teardownError=Join-LauncherError $teardownError ('mutex dispose: '+$_.Exception.Message)}}
        if($ForceTeardownFailureForTest){$teardownError=Join-LauncherError $teardownError 'forced mutex teardown failure after body result'}
    }
    if($primaryError-or$teardownError){throw (Join-LauncherError $primaryError $teardownError)}
    return $result
}

function Assert-ExclusiveReservationOwned {
    param([object]$LauncherIdentity,[string]$Commit,[string]$Tree,[string]$AttemptId,[System.Collections.IDictionary]$Pinned,[System.Collections.IDictionary]$DependencyPins,[System.Collections.IDictionary]$EnvironmentBaseline,[string]$OwnerClaimPath,[string]$OwnerClaimText,[string]$OwnerClaimSha256,[string]$OwnedRoot,[object]$OwnerReceipt,[object]$HeldExclusiveLease,[object]$RunContext)
    if(-not(Test-Q009RunContextShape $RunContext)-or[string]$RunContext.attempt_id-cne$AttemptId-or[string]$RunContext.candidate_commit-cne$Commit-or[string]$RunContext.candidate_tree-cne$Tree-or[string]$RunContext.launcher_identity.key-cne[string]$LauncherIdentity.key){throw 'EXCLUSIVE ownership check rejected a mismatched immutable run context'}
    Assert-CanonicalLeaseRootPath $RunContext
    [void](Assert-CleanExactCandidate ([string]$RunContext.project_root) $Commit $Tree)
    Assert-PinnedFilesStable $Pinned $RunContext $DependencyPins
    Assert-ExactExclusiveLease $HeldExclusiveLease $RunContext
    Assert-ExactAttemptOwner $OwnerClaimPath $OwnerClaimText $OwnerClaimSha256 $OwnedRoot $OwnerReceipt
    if(-not(Test-EnvironmentMatchesSnapshot $EnvironmentBaseline)){throw 'Launcher process environment drifted while waiting for EXCLUSIVE readiness'}
}

function Get-StrictGodotIdentityCensus {
    param(
        [ValidateSet('readiness','residual','pre_cleanup','release','postcheck')][string]$Context,
        [switch]$ForceEnumerationFailureForTest
    )
    try{$records=@(Get-LiveGodotIdentityRecords -ForceEnumerationFailureForTest:$ForceEnumerationFailureForTest)}catch{throw "Godot $Context census failed closed: $($_.Exception.Message)"}
    return [ordered]@{context=$Context;observed_utc=[DateTime]::UtcNow.ToString('o');identity_records=@($records);count=$records.Count}
}

function Select-ExactRemoteCandidateRefs {
    param([string[]]$Rows,[string]$Commit)
    return @($rows|ForEach-Object{$parts=[string]$_ -split '\|',3;if($parts.Count-eq3-and[string]::IsNullOrWhiteSpace($parts[2])-and$parts[1]-cne'refs/remotes/origin/HEAD'-and$parts[0]-ceq$Commit){$parts[1]}}|Sort-Object -Unique)
}

function Get-ExactRemoteCandidateRefs {
    param([string]$Commit,[string]$CandidateRoot)
    if([string]::IsNullOrWhiteSpace($CandidateRoot)){throw 'Remote-ref proof requires an explicit candidate root'}
    $rows=@(& git -C ([IO.Path]::GetFullPath($CandidateRoot)) for-each-ref '--format=%(objectname)|%(refname)|%(symref)' refs/remotes/origin 2>$null)
    if($LASTEXITCODE-ne0){return @()}
    return @(Select-ExactRemoteCandidateRefs $rows $Commit)
}

function Test-PushedCandidate {
    param([string]$Commit,[string]$CandidateRoot)
    return @(Get-ExactRemoteCandidateRefs $Commit $CandidateRoot).Count -gt 0
}

function Assert-PinnedFilesStable {
    param(
        [System.Collections.IDictionary]$Pinned,
        [object]$RunContext,
        [AllowNull()][System.Collections.IDictionary]$DependencyPins=$null
    )
    if(-not(Test-Q009RunContextShape $RunContext)){throw 'Pinned-file verification requires one exact sealed run context'}
    $candidateRoot=[string]$RunContext.project_root
    if($null-ne$DependencyPins){
        [void](Assert-Q009TrackedDependencyPinsStable $Pinned $DependencyPins $RunContext)
        return
    }
    foreach ($entry in $Pinned.GetEnumerator()) {
        $identity = $entry.Value
        $path = Join-Path $candidateRoot (([string]$identity.path).Replace('/','\'))
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Pinned file disappeared: $($identity.path)" }
        if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -cne [string]$identity.sha256) { throw "Pinned raw file drift: $($identity.path)" }
        $blob = (& git -C $candidateRoot hash-object -- $path).Trim()
        if ($LASTEXITCODE -ne 0 -or $blob -cne [string]$identity.git_blob) { throw "Pinned Git blob drift: $($identity.path)" }
    }
}

function Test-Q009TrackedDependencyPinReceiptsShape {
    param(
        [AllowNull()][object]$Receipts,
        [System.Collections.IDictionary]$Pinned,
        [object]$RunContext
    )
    if($Receipts-isnot[System.Collections.IDictionary]-or-not(Test-Q009RunContextShape $RunContext)){return $false}
    $expectedKeys=@($Pinned.Keys);$actualKeys=@($Receipts.Keys)
    if($actualKeys.Count-ne$expectedKeys.Count-or($actualKeys-join"`n")-cne($expectedKeys-join"`n")){return $false}
    foreach($key in $expectedKeys){
        $tracked=$Pinned[$key];$receipt=$Receipts[$key]
        if(-not(Test-Q009ExecutablePinReceiptShape $receipt ([string]$RunContext.attempt_id))){return $false}
        $expectedPath=[IO.Path]::GetFullPath((Join-Path ([string]$RunContext.project_root) (([string]$tracked.path).Replace('/','\'))))
        if([string]$receipt.path-cne$expectedPath-or[long]$receipt.length-ne[long]$tracked.length-or[string]$receipt.sha256-cne[string]$tracked.sha256){return $false}
    }
    return $true
}

function New-Q009TrackedDependencyPins {
    param([System.Collections.IDictionary]$Pinned,[object]$RunContext)
    if(-not(Test-Q009RunContextShape $RunContext)){throw 'Tracked dependency pins require one exact sealed run context'}
    $pins=[ordered]@{};$failure=$null
    try{
        foreach($key in @($Pinned.Keys)){
            $tracked=$Pinned[$key]
            $path=[IO.Path]::GetFullPath((Join-Path ([string]$RunContext.project_root) (([string]$tracked.path).Replace('/','\'))))
            $filesystemIdentity=Get-Q009FileSystemEntryIdentity $path
            $expected=[ordered]@{path=$path;length=[long]$tracked.length;sha256=[string]$tracked.sha256;filesystem_identity=$filesystemIdentity}
            $pins[$key]=New-Q009ExecutablePin -Path $path -AttemptId ([string]$RunContext.attempt_id) -ExpectedExecutableIdentity $expected
        }
        [void](Assert-Q009TrackedDependencyPinsStable $Pinned $pins $RunContext)
        return $pins
    }catch{$failure=$_.Exception}
    finally{
        if($null-ne$failure){
            $cleanupErrors=[Collections.Generic.List[string]]::new()
            foreach($key in @($pins.Keys)){
                try{if($null-ne$pins[$key]-and-not[bool]$pins[$key].released){[void](Close-Q009ExecutablePin $pins[$key] ([string]$RunContext.attempt_id))}}catch{[void]$cleanupErrors.Add("$key`: $($_.Exception.Message)")}
            }
            if($cleanupErrors.Count-ne0){throw [InvalidOperationException]::new(('Tracked dependency pin setup failed and exact pin cleanup was incomplete: '+(@($cleanupErrors)-join'; ')),$failure)}
        }
    }
    throw $failure
}

function Assert-Q009TrackedDependencyPinsStable {
    param([System.Collections.IDictionary]$Pinned,[System.Collections.IDictionary]$DependencyPins,[object]$RunContext)
    if(-not(Test-Q009RunContextShape $RunContext)){throw 'Tracked dependency pin proof requires one exact sealed run context'}
    $expectedKeys=@($Pinned.Keys);$actualKeys=@($DependencyPins.Keys)
    if($actualKeys.Count-ne$expectedKeys.Count-or($actualKeys-join"`n")-cne($expectedKeys-join"`n")){throw 'Tracked dependency pin key order/count drifted'}
    $receipts=[ordered]@{}
    foreach($key in $expectedKeys){
        $pin=$DependencyPins[$key];$tracked=$Pinned[$key]
        $receipt=Assert-Q009ExecutablePinStable $pin ([string]$RunContext.attempt_id)
        $expectedPath=[IO.Path]::GetFullPath((Join-Path ([string]$RunContext.project_root) (([string]$tracked.path).Replace('/','\'))))
        if([string]$receipt.path-cne$expectedPath-or[long]$receipt.length-ne[long]$tracked.length-or[string]$receipt.sha256-cne[string]$tracked.sha256){throw "Tracked dependency held receipt drifted: $key"}
        $receipts[$key]=$receipt
    }
    if(-not(Test-Q009TrackedDependencyPinReceiptsShape $receipts $Pinned $RunContext)){throw 'Tracked dependency held receipts failed their exact closed schema'}
    return $receipts
}

function Test-Q009TrackedDependencyPinReleasesShape {
    param(
        [AllowNull()][object]$Releases,
        [AllowNull()][object]$Receipts,
        [System.Collections.IDictionary]$Pinned,
        [object]$RunContext
    )
    if(-not(Test-Q009TrackedDependencyPinReceiptsShape $Receipts $Pinned $RunContext)-or$Releases-isnot[System.Collections.IDictionary]){return $false}
    $expectedKeys=@($Pinned.Keys);$actualKeys=@($Releases.Keys)
    if($actualKeys.Count-ne$expectedKeys.Count-or($actualKeys-join"`n")-cne($expectedKeys-join"`n")){return $false}
    foreach($key in $expectedKeys){
        $release=$Releases[$key]
        if(-not(Test-Q009ExecutablePinReleaseReceiptShape $release)-or-not[bool]$release.released-or-not[bool]$release.all_terminal-or[string]$release.receipt_sha256-cne[string]$Receipts[$key].receipt_sha256){return $false}
    }
    return $true
}

function Close-Q009TrackedDependencyPins {
    param(
        [System.Collections.IDictionary]$Pinned,
        [System.Collections.IDictionary]$DependencyPins,
        [object]$RunContext,
        [object]$ExpectedReceipts
    )
    [void](Assert-Q009TrackedDependencyPinsStable $Pinned $DependencyPins $RunContext)
    if(-not(Test-Q009TrackedDependencyPinReceiptsShape $ExpectedReceipts $Pinned $RunContext)){throw 'Tracked dependency release requires the exact held receipt set'}
    $releases=[ordered]@{};$errors=[Collections.Generic.List[string]]::new()
    foreach($key in @($Pinned.Keys)){
        try{$releases[$key]=Close-Q009ExecutablePin $DependencyPins[$key] ([string]$RunContext.attempt_id)}catch{[void]$errors.Add("$key`: $($_.Exception.Message)")}
    }
    if($errors.Count-ne0){throw 'Tracked dependency pin release retained native custody: '+(@($errors)-join'; ')}
    if(-not(Test-Q009TrackedDependencyPinReleasesShape $releases $ExpectedReceipts $Pinned $RunContext)){throw 'Tracked dependency releases failed their exact closed schema'}
    return $releases
}

function Assert-ExclusiveReady {
    param(
        [object]$LauncherIdentity,[string]$Commit,[string]$Tree,[string]$AttemptId,
        [System.Collections.IDictionary]$Pinned,[System.Collections.IDictionary]$DependencyPins,[System.Collections.IDictionary]$EnvironmentBaseline,
        [string]$OwnerClaimPath,[string]$OwnerClaimText,[string]$OwnerClaimSha256,[string]$OwnedRoot,
        [object]$OwnerReceipt,
        [object]$HeldExclusiveLease,
        [object]$RunContext,
        [switch]$ForceGodotEnumerationFailureForTest
    )
    Assert-ExclusiveReservationOwned $LauncherIdentity $Commit $Tree $AttemptId $Pinned $DependencyPins $EnvironmentBaseline $OwnerClaimPath $OwnerClaimText $OwnerClaimSha256 $OwnedRoot $OwnerReceipt $HeldExclusiveLease $RunContext
    Assert-CanonicalLeaseRootPath $RunContext
    $otherLeases = @(Get-CanonicalLeaseFilesStrict -RunContext $RunContext -ExcludeExclusive)
    if ($otherLeases.Count -ne 0) { throw "Other Q-009 leases remain during EXCLUSIVE custody: $($otherLeases.Count)" }
    $godotCensus=Get-StrictGodotIdentityCensus readiness -ForceEnumerationFailureForTest:$ForceGodotEnumerationFailureForTest
    $godot=@($godotCensus.identity_records)
    if ($godot.Count -ne 0) { throw "Godot census is not zero during EXCLUSIVE custody: $($godot.Count)" }
}

function Assert-OwnedCacheAbsentImmediatelyBeforeImport {
    param(
        [string]$CachePath,
        [string]$CandidateRoot,
        [switch]$ForceRaceCreationForTest
    )
    Assert-NoReparsePathChain $CandidateRoot $CachePath
    if($ForceRaceCreationForTest-and-not(Test-Path -LiteralPath $CachePath)){[void][IO.Directory]::CreateDirectory($CachePath)}
    $strictAbsence=Assert-Q009PathAbsentStrict $CachePath
    $receipt=[ordered]@{proved=[bool]$true;observed_utc=[string][DateTime]::UtcNow.ToString('o');path=[string][IO.Path]::GetFullPath($CachePath);absent=[bool]$true;under_launch_mutex=[bool]$true;strict_parent_identity=$strictAbsence.parent_identity}
    if(-not(Test-OwnedCacheAbsenceReceiptShape $receipt)){throw 'Mutex-bound cache absence receipt was malformed'}
    return $receipt
}

function Test-OwnedCacheAbsenceReceiptShape {
    param([AllowNull()][object]$Receipt)
    if(-not(Test-Q009ExactPublicReceiptKeys $Receipt @('proved','observed_utc','path','absent','under_launch_mutex','strict_parent_identity'))){return $false}
    return $Receipt.proved-is[bool]-and[bool]$Receipt.proved-and(Test-Q009ExactRoundtripTimestamp $Receipt.observed_utc)-and$Receipt.path-is[string]-and-not[string]::IsNullOrWhiteSpace($Receipt.path)-and$Receipt.absent-is[bool]-and[bool]$Receipt.absent-and$Receipt.under_launch_mutex-is[bool]-and[bool]$Receipt.under_launch_mutex-and(Test-Q009FileSystemIdentityShape $Receipt.strict_parent_identity)-and[bool]$Receipt.strict_parent_identity.is_directory
}

function Get-StrictGlobalQuiescenceEvidence {
    param(
        [object]$LauncherIdentity,[string]$Commit,[string]$Tree,[string]$AttemptId,
        [System.Collections.IDictionary]$Pinned,[System.Collections.IDictionary]$DependencyPins,[System.Collections.IDictionary]$EnvironmentBaseline,
        [string]$OwnerClaimPath,[string]$OwnerClaimText,[string]$OwnerClaimSha256,[string]$OwnedRoot,
        [object]$OwnerReceipt,
        [object]$HeldExclusiveLease,
        [object]$RunContext,
        [ValidateSet('pre_cleanup','release')][string]$Context='pre_cleanup',
        [switch]$ForceGodotEnumerationFailureForTest,
        [switch]$ForceLeaseEnumerationFailureForTest
    )
    Assert-ExclusiveReservationOwned $LauncherIdentity $Commit $Tree $AttemptId $Pinned $DependencyPins $EnvironmentBaseline $OwnerClaimPath $OwnerClaimText $OwnerClaimSha256 $OwnedRoot $OwnerReceipt $HeldExclusiveLease $RunContext
    $godotCensus=Get-StrictGodotIdentityCensus $Context -ForceEnumerationFailureForTest:$ForceGodotEnumerationFailureForTest
    $godot=@($godotCensus.identity_records)
    $exclusive=[IO.Path]::GetFullPath((Join-Path ([string]$RunContext.canonical_lease_root) 'EXCLUSIVE.lease'))
    $otherLeases=if($ForceLeaseEnumerationFailureForTest){@(Get-StrictLeaseFilesAtPath ([string]$RunContext.canonical_lease_root) -ForceEnumerationFailureForTest|Where-Object{[IO.Path]::GetFullPath($_.FullName)-cne$exclusive})}else{@(Get-CanonicalLeaseFilesStrict -RunContext $RunContext -ExcludeExclusive)}
    $proved=$godot.Count-eq0-and$otherLeases.Count-eq0
    if(-not$proved){throw "Global Q-009 quiescence was not exact: Godot=$($godot.Count), other_leases=$($otherLeases.Count)"}
    return [ordered]@{proved=$true;observed_utc=[DateTime]::UtcNow.ToString('o');godot_count=$godot.Count;godot_identities=$godot;other_lease_count=$otherLeases.Count;under_mutex=$true}
}

function Test-GlobalQuiescenceEvidenceShape {
    param([AllowNull()][object]$Evidence)
    if(-not(Test-Q009ExactPublicReceiptKeys $Evidence @('proved','observed_utc','godot_count','godot_identities','other_lease_count','under_mutex'))){return $false}
    if($Evidence.proved-isnot[bool]-or-not[bool]$Evidence.proved-or-not(Test-Q009ExactRoundtripTimestamp $Evidence.observed_utc)-or$Evidence.godot_count-isnot[int]-or[int]$Evidence.godot_count-ne0-or$Evidence.godot_identities-isnot[System.Array]-or$Evidence.other_lease_count-isnot[int]-or[int]$Evidence.other_lease_count-ne0-or$Evidence.under_mutex-isnot[bool]-or-not[bool]$Evidence.under_mutex){return $false}
    foreach($identity in @($Evidence.godot_identities)){if(-not(Test-ProcessIdentityProofShape $identity)){return $false}}
    return $true
}

function Remove-ExactOwnedTree {
    param(
        [string]$Root,
        [string]$Path,
        [object]$ExpectedRootIdentity,
        [object]$AuthorizedChainHead,
        [string]$ExpectedAttemptId,
        [switch]$ForceQuarantineReplacementForTest
    )
    $rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd('\','/')
    $pathFull = [System.IO.Path]::GetFullPath($Path).TrimEnd('\','/')
    if (-not $pathFull.StartsWith($rootFull + [System.IO.Path]::DirectorySeparatorChar,[System.StringComparison]::OrdinalIgnoreCase)) { throw "Refusing cleanup outside owned root: $pathFull" }
    Assert-NoReparsePathChain $rootFull $pathFull
    if(-not(Test-Path -LiteralPath $pathFull)){throw "Exact owned cleanup root disappeared before cleanup: $pathFull"}
    if(-not(Test-Q009FileSystemIdentityShape $ExpectedRootIdentity)-or-not[bool]$ExpectedRootIdentity.is_directory-or[string]$ExpectedRootIdentity.path-cne$pathFull){throw "Exact owned cleanup receipt is malformed or names another root: $pathFull"}
    if($null-eq$AuthorizedChainHead){throw "Exact owned cleanup requires an explicit authoritative terminal child manifest: $pathFull"}
    if([string]::IsNullOrWhiteSpace($ExpectedAttemptId)){throw "Exact owned cleanup requires its exact attempt identity: $pathFull"}
    $quarantine=Join-Path ([IO.Path]::GetDirectoryName($pathFull)) ('.q009-delete-{0}-{1}'-f[IO.Path]::GetFileName($pathFull),[guid]::NewGuid().ToString('N'))
    return Remove-Q009ExactOwnedTree -OwnedPath $pathFull -QuarantinePath $quarantine -ExpectedRootIdentity $ExpectedRootIdentity -AuthorizedChainHead $AuthorizedChainHead -ExpectedAttemptId $ExpectedAttemptId -ForceQuarantineReplacementForTest:$ForceQuarantineReplacementForTest
}

function Remove-ValidateOnlyOwnedTree {
    param(
        [string]$Root,[string]$Path,[object]$ExpectedRootIdentity,
        [object]$RunContext,[object]$OwnerReceipt,
        [switch]$ForceQuarantineReplacementForTest
    )
    if(-not(Test-Q009RunContextShape $RunContext)){throw 'ValidateOnly cleanup requires one explicit sealed run context'}
    if($null-eq$OwnerReceipt){throw 'ValidateOnly cleanup requires one explicit owner receipt'}
    $pathFull=[IO.Path]::GetFullPath($Path).TrimEnd('\','/')
    $rootFull=[IO.Path]::GetFullPath($Root).TrimEnd('\','/')
    if($pathFull-cne$rootFull-and-not$pathFull.StartsWith($rootFull+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'ValidateOnly cleanup path escapes its explicit fixture root'}
    $chain=New-Q009OwnedChildManifestChainHead -RootPath $pathFull -RootIdentity $ExpectedRootIdentity -AttemptId ([string]$RunContext.attempt_id) -Boundary ('validate_only_terminal_'+[guid]::NewGuid().ToString('N')) -OwnerKind launcher_fixture -OwnerReceipt $OwnerReceipt
    return Remove-ExactOwnedTree -Root $Root -Path $Path -ExpectedRootIdentity $ExpectedRootIdentity -AuthorizedChainHead $chain -ExpectedAttemptId ([string]$RunContext.attempt_id) -ForceQuarantineReplacementForTest:$ForceQuarantineReplacementForTest
}

function New-AtomicOwnedEvidenceRoot {
    param([string]$DestinationPath,[string]$AllowedRoot,[string]$OwnerClaimText,[string]$AttemptId,[switch]$ForcePostMoveReplacementForTest)
    $allowed=[IO.Path]::GetFullPath($AllowedRoot).TrimEnd('\','/')
    $destination=[IO.Path]::GetFullPath($DestinationPath).TrimEnd('\','/')
    if(-not$destination.StartsWith($allowed+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Evidence destination escapes the allowed root'}
    $parent=[IO.Path]::GetDirectoryName($destination)
    if(-not(Test-Path -LiteralPath $parent -PathType Container)){throw "Evidence destination parent is missing: $parent"}
    Assert-NoReparsePathChain $allowed $parent
    if(Test-Path -LiteralPath $destination){throw 'Evidence destination already exists'}
    $stage=Join-Path $parent ('.q009-evidence-stage-'+[guid]::NewGuid().ToString('N'))
    $parentIdentity=Get-Q009FileSystemEntryIdentity $parent
    $stageIdentity=$null;$stageChain=$null;$claimOwnership=[ordered]@{created=$false;path='';identity=$null;write_complete=$false;removal_failed=$false;removal_error=''};$published=$false;$saved='';$replacementIdentity=$null
    try{
        $stageIdentity=New-Q009ExactOwnedDirectory $stage
        $claimStage=Join-Path $stage '.attempt-owner';$claimOwnership.path=$claimStage
        New-OwnedLeaseFile -Path $claimStage -Text $OwnerClaimText -Ownership $claimOwnership
        if(-not[bool]$claimOwnership.created-or-not[bool]$claimOwnership.write_complete-or-not(Test-Q009FileSystemIdentityMatch $claimOwnership.identity)){throw 'Evidence owner claim was not atomically created and identity-bound inside the stage root'}
        $claimSha=(Get-FileHash -LiteralPath $claimStage -Algorithm SHA256).Hash
        $stageOwner=[ordered]@{claim_identity=$claimOwnership.identity;claim_sha256=[string]$claimSha;parent_identity=$parentIdentity}
        $stageChain=New-Q009OwnedChildManifestChainHead -RootPath $stage -RootIdentity $stageIdentity -AttemptId $AttemptId -Boundary 'evidence_stage_complete' -OwnerKind evidence_owner -OwnerReceipt $stageOwner
        Publish-Q009EvidenceStageDirectory -SourcePath $stage -DestinationPath $destination -SourceIdentity $stageIdentity -ExpectedParentIdentity $parentIdentity;$published=$true
        $rootIdentity=Copy-Q009FileSystemIdentityToPath $stageIdentity $destination
        $claimPath=Join-Path $destination '.attempt-owner';$claimIdentity=Copy-Q009FileSystemIdentityToPath $claimOwnership.identity $claimPath
        if($ForcePostMoveReplacementForTest){
            $saved=$destination+'.owned-original-'+[guid]::NewGuid().ToString('N')
            Move-Q009PublishedEvidenceRootAsideForHostile -SourcePath $destination -DestinationPath $saved -SourceIdentity $rootIdentity -ExpectedParentIdentity $parentIdentity
            $replacementIdentity=New-Q009ExactOwnedDirectory $destination
            [IO.File]::WriteAllText((Join-Path $destination '.attempt-owner'),$OwnerClaimText,[Text.UTF8Encoding]::new($false))
        }
        if(-not(Test-Q009FileSystemIdentityMatch $rootIdentity)-or-not(Test-Q009FileSystemIdentityMatch $claimIdentity)){throw 'Evidence root or owner claim identity changed across the handle-bound publication rename'}
        if((Get-FileHash -LiteralPath $claimPath -Algorithm SHA256).Hash-cne$claimSha){throw 'Evidence owner claim bytes changed across publication'}
        $publishedOwner=[ordered]@{stage_chain_head=$stageChain;root_identity=$rootIdentity;claim_identity=$claimIdentity;claim_sha256=[string]$claimSha;parent_identity=$parentIdentity;attempt_id=[string]$AttemptId}
        $publishedChain=New-Q009OwnedChildManifestChainHead -RootPath $destination -RootIdentity $rootIdentity -AttemptId $AttemptId -Boundary 'evidence_published_identity_bound' -OwnerKind evidence_owner -OwnerReceipt $publishedOwner -PreviousHead $stageChain
        return [ordered]@{root_path=$destination;root_identity=$rootIdentity;claim_path=$claimPath;claim_identity=$claimIdentity;claim_sha256=$claimSha;parent_identity=$parentIdentity;owned_child_chain_head=$publishedChain;stage_chain_head=$stageChain;stage_path=$stage;handle_bound=$true}
    }catch{
        $failure=$_.Exception
        if($ForcePostMoveReplacementForTest-and-not[string]::IsNullOrWhiteSpace($saved)-and$null-ne$replacementIdentity){
            $failure.Data['owned_original_path']=$saved
            $failure.Data['owned_original_identity']=Copy-Q009FileSystemIdentityToPath $stageIdentity $saved
            $failure.Data['replacement_path']=$destination
            $failure.Data['replacement_identity']=$replacementIdentity
        }elseif(-not$published-and$null-ne$stageIdentity-and(Test-Q009FileSystemIdentityMatch $stageIdentity)){
            try{[void](Remove-ExactOwnedTree $parent $stage $stageIdentity $stageChain $AttemptId)}catch{throw [InvalidOperationException]::new(('Evidence-root creation failed and exact stage cleanup failed: '+$_.Exception.Message),$failure)}
        }
        throw $failure
    }
}

function Test-SentinelPinnedCacheProofShape {
    param([AllowNull()][object]$Proof,[string]$AttemptId,[string]$Commit,[string]$Tree)
    if(-not(Test-Q009ExactPublicReceiptKeys $Proof @('proved','attempt_id','candidate_commit','candidate_tree','creator_identity','entry_identity','sentinel_identity','root_handle_state','sentinel_handle_state','creation_chain','sentinel_sha256','sentinel_length','self_authored_claim_used','timing_window_used'))){return $false}
    return $Proof.proved-is[bool]-and[bool]$Proof.proved-and
        $Proof.attempt_id-is[string]-and[string]$Proof.attempt_id-ceq$AttemptId-and
        $Proof.candidate_commit-is[string]-and[string]$Proof.candidate_commit-ceq$Commit-and
        $Proof.candidate_tree-is[string]-and[string]$Proof.candidate_tree-ceq$Tree-and
        (Test-ProcessIdentityProofShape $Proof.creator_identity)-and
        (Test-Q009FileSystemIdentityShape $Proof.entry_identity)-and[bool]$Proof.entry_identity.is_directory-and
        (Test-Q009FileSystemIdentityShape $Proof.sentinel_identity)-and-not[bool]$Proof.sentinel_identity.is_directory-and
        $Proof.root_handle_state-is[string]-and[string]$Proof.root_handle_state-in@('OPEN','CLOSED_NATIVE_SUCCESS')-and
        $Proof.sentinel_handle_state-is[string]-and[string]$Proof.sentinel_handle_state-ceq'OPEN'-and
        $Proof.creation_chain-is[string]-and[string]$Proof.creation_chain-ceq'root_FILE_CREATE -> sentinel_relative_FILE_CREATE -> final_root_OPEN_EXISTING'-and
        $Proof.sentinel_sha256-is[string]-and[string]$Proof.sentinel_sha256-cmatch'^[0-9A-F]{64}$'-and
        $Proof.sentinel_length-is[int]-and[int]$Proof.sentinel_length-gt0-and
        $Proof.self_authored_claim_used-is[bool]-and-not[bool]$Proof.self_authored_claim_used-and
        $Proof.timing_window_used-is[bool]-and-not[bool]$Proof.timing_window_used
}

function Test-SentinelCapabilityReceiptShape {
    param([AllowNull()][object]$Receipt)
    $keys=@('proved','drive_name','drive_type','drive_format','sibling_file_cycle','sibling_directory_cycle','deep_child_cycle','root_rename_denied','cross_parent_rename_denied','native_root_rename_denied','posix_root_rename_denied','root_delete_denied','native_root_delete_denied','sentinel_rename_denied','sentinel_delete_denied','sentinel_overwrite_denied','replacement_denied','root_absent','all_handles_terminal','observed_utc')
    if(-not(Test-Q009ExactPublicReceiptKeys $Receipt $keys)){return $false}
    foreach($name in @('drive_name','drive_type','drive_format')){if($Receipt[$name]-isnot[string]-or[string]::IsNullOrWhiteSpace([string]$Receipt[$name])){return $false}}
    foreach($name in @('proved','sibling_file_cycle','sibling_directory_cycle','deep_child_cycle','root_rename_denied','cross_parent_rename_denied','native_root_rename_denied','posix_root_rename_denied','root_delete_denied','native_root_delete_denied','sentinel_rename_denied','sentinel_delete_denied','sentinel_overwrite_denied','replacement_denied','root_absent','all_handles_terminal')){if($Receipt[$name]-isnot[bool]-or-not[bool]$Receipt[$name]){return $false}}
    return Test-Q009ExactRoundtripTimestamp $Receipt.observed_utc
}

function Get-Q009Win32ErrorCodeFromException {
    param([AllowNull()][Exception]$Exception)
    $cursor=$Exception
    for($depth=0;$depth-lt8-and$null-ne$cursor;$depth+=1){if($cursor-is[System.ComponentModel.Win32Exception]){return [int]$cursor.NativeErrorCode};$cursor=$cursor.InnerException}
    return $null
}

function Assert-Q009KnownSentinelDenial {
    param([Exception]$Exception,[string]$Context)
    $code=Get-Q009Win32ErrorCodeFromException $Exception
    if($null-eq$code-or[int]$code-notin@(5,32,145)){throw "$Context produced an unknown/unsupported native result instead of a proved sentinel denial: $($Exception.Message)"}
}

function Get-SentinelPinnedCacheProof {
    param(
        [System.Collections.IDictionary]$Custody,[object]$CreatorIdentity,[string]$CachePath,
        [string]$AttemptId,[string]$Commit,[string]$Tree,[switch]$RequireInitialRootOpen
    )
    if(-not(Test-ProcessIdentityProofShape $CreatorIdentity)-or-not(Test-LiveProcessMatchesIdentity $CreatorIdentity)){throw 'Cache creator is not the exact live supervisor identity'}
    $currentIdentity=Get-ProcessIdentityRecord ([Diagnostics.Process]::GetCurrentProcess())
    if([string]$currentIdentity.key-cne[string]$CreatorIdentity.key){throw 'Cache creator identity is not this exact supervisor process'}
    if($null-eq$Custody-or-not$Custody.Contains('native_cell')-or-not$Custody.Contains('root_receipt')-or-not$Custody.Contains('sentinel_receipt')){throw 'Sentinel cache custody registry is missing its closed private schema'}
    $cell=$Custody.native_cell;$root=$Custody.root_receipt;$sentinel=$Custody.sentinel_receipt
    if($null-eq$cell-or$null-eq$root-or$null-eq$sentinel){throw 'Sentinel cache custody was not fully registered'}
    if(-not(Test-Q009CacheRootReceiptShape $root)){throw 'Cache root creation receipt is mistyped or not an atomic no-share-delete FILE_CREATE receipt'}
    if(-not(Test-Q009SentinelReceiptShape $sentinel)){throw 'Cache sentinel receipt is mistyped or does not prove an exact private FILE_CREATE pin'}
    $expected=$root.identity;$sentinelExpected=$sentinel.identity;$resolvedCache=[IO.Path]::GetFullPath($CachePath).TrimEnd('\','/')
    if(-not(Test-Q009FileSystemIdentityShape $expected)-or-not[bool]$expected.is_directory-or[string]$expected.path-cne$resolvedCache){throw 'Cache native creation identity is malformed or names another path'}
    if(-not(Test-Q009FileSystemIdentityShape $sentinelExpected)-or[bool]$sentinelExpected.is_directory-or[IO.Path]::GetDirectoryName([string]$sentinelExpected.path)-cne$resolvedCache){throw 'Cache sentinel identity is malformed or outside the exact cache root'}
    $rootState=[string]$cell.StateOf('root_creation');$sentinelState=[string]$cell.StateOf('sentinel')
    if($RequireInitialRootOpen){if($rootState-cne'OPEN'){throw 'Initial cache-root creation handle is not OPEN before sentinel handoff'}}elseif($rootState-cne'CLOSED_NATIVE_SUCCESS'){throw 'Initial cache-root creation handle did not close with native success after sentinel handoff'}
    if($sentinelState-cne'OPEN'){throw "Cache sentinel handle is not OPEN; state=$sentinelState"}
    if($RequireInitialRootOpen){$rootHandleIdentity=Get-Q009FileSystemHandleIdentity -CustodyCell $cell -Slot root_creation -Path $resolvedCache -IsDirectory $true;if([string]$rootHandleIdentity.key-cne[string]$expected.key){throw 'Cache root creation handle identity changed before handoff'}}else{$rootHandleIdentity=$expected}
    $sentinelHandleIdentity=Get-Q009FileSystemHandleIdentity -CustodyCell $cell -Slot sentinel -Path ([string]$sentinelExpected.path) -IsDirectory $false
    if([string]$sentinelHandleIdentity.key-cne[string]$sentinelExpected.key-or-not(Test-Q009FileSystemIdentityMatch $sentinelExpected)-or-not(Test-Q009FileSystemIdentityMatch $expected)){throw 'Sentinel pin no longer binds the exact cache root and sentinel path'}
    $sentinelArtifact=Get-FileArtifact ([string]$sentinelExpected.path)
    if($sentinelArtifact.present-isnot[bool]-or-not$sentinelArtifact.present-or$sentinelArtifact.length-isnot[long]-or[long]$sentinelArtifact.length-ne[int]$sentinel.payload_length-or$sentinelArtifact.sha256-isnot[string]-or[string]$sentinelArtifact.sha256-cne[string]$sentinel.payload_sha256){throw 'Cache sentinel bytes changed after native initialization'}
    if([long]$expected.creation_ticks-lt[long]$CreatorIdentity.start_ticks-or[long]$sentinelExpected.creation_ticks-lt[long]$expected.creation_ticks){throw 'Cache creation chain predates its exact supervisor/root creator'}
    $proof=[ordered]@{proved=[bool]$true;attempt_id=[string]$AttemptId;candidate_commit=[string]$Commit;candidate_tree=[string]$Tree;creator_identity=$CreatorIdentity;entry_identity=$expected;sentinel_identity=$sentinelExpected;root_handle_state=[string]$rootState;sentinel_handle_state=[string]$sentinelState;creation_chain=[string]'root_FILE_CREATE -> sentinel_relative_FILE_CREATE -> final_root_OPEN_EXISTING';sentinel_sha256=[string]$sentinel.payload_sha256;sentinel_length=[int]$sentinel.payload_length;self_authored_claim_used=[bool]$false;timing_window_used=[bool]$false}
    if(-not(Test-SentinelPinnedCacheProofShape $proof $AttemptId $Commit $Tree)){throw 'Sentinel-pinned cache proof failed its exact public receipt schema'}
    return $proof
}

function Invoke-Q009SentinelFilesystemCapabilityProbe {
    param([string]$ProbeParent,[string]$AttemptId,[string]$ProjectRoot)
    $parent=[IO.Path]::GetFullPath($ProbeParent).TrimEnd('\','/');Assert-NoReparsePathChain ([IO.Path]::GetFullPath($ProjectRoot).TrimEnd('\','/')) $parent
    $drive=[IO.DriveInfo]::new([IO.Path]::GetPathRoot($parent));if($drive.DriveType-ne[IO.DriveType]::Fixed-or[string]::IsNullOrWhiteSpace($drive.DriveFormat)){throw 'Sentinel capability probe requires a known fixed local filesystem'}
    $root=Join-Path $parent ('.rw06-q009-sentinel-capability-'+[guid]::NewGuid().ToString('N'));$cell=New-Q009CacheCustodyCell ($AttemptId+'-capability');$rootReceipt=$null;$sentinelReceipt=$null
    try{
        $rootReceipt=New-Q009ExactOwnedDirectoryHeld -Path $root -CustodyCell $cell -Slot root_creation
        if(-not(Test-Q009CacheRootReceiptShape $rootReceipt)){throw 'Capability root creation receipt failed its exact public schema'}
        $sentinel=Join-Path $root '.pin';$payload=[Text.Encoding]::UTF8.GetBytes("attempt_id=$AttemptId`ncapability_probe=true`n")
        $sentinelReceipt=New-Q009ExactOwnedFileHeld -Path $sentinel -Payload $payload -CustodyCell $cell -ParentSlot root_creation -Slot sentinel -ExpectedParentIdentity $rootReceipt.identity
        if(-not(Test-Q009SentinelReceiptShape $sentinelReceipt)){throw 'Capability sentinel creation receipt failed its exact public schema'}
        $initialClose=Close-Q009CheckedNativeHandle $cell root_creation 'Capability initial-root handoff';if(-not(Test-Q009CheckedCloseReceipt $initialClose)){throw 'Capability initial-root close receipt was malformed'}
        $siblingFile=Join-Path $root 'sibling.tmp';$siblingMoved=Join-Path $root 'sibling-moved.tmp';$siblingOwnership=[ordered]@{created=$false;identity=$null;write_complete=$false;removal_failed=$false;removal_error=''};New-OwnedLeaseFile $siblingFile 'sibling' $siblingOwnership;[IO.File]::Move($siblingFile,$siblingMoved);$siblingMovedIdentity=Copy-Q009FileSystemIdentityToPath $siblingOwnership.identity $siblingMoved;Remove-Q009ExactOwnedFile $siblingMoved $siblingMovedIdentity
        $siblingDirectory=Join-Path $root 'sibling-dir';$siblingDirectoryMoved=Join-Path $root 'sibling-dir-moved';$siblingDirectoryIdentity=New-Q009ExactOwnedDirectory $siblingDirectory;$deep=Join-Path $siblingDirectory 'deep';$deepIdentity=New-Q009ExactOwnedDirectory $deep;$deepFile=Join-Path $deep 'child.tmp';$deepMoved=Join-Path $deep 'child-moved.tmp';$deepOwnership=[ordered]@{created=$false;identity=$null;write_complete=$false;removal_failed=$false;removal_error=''};New-OwnedLeaseFile $deepFile 'deep' $deepOwnership;[IO.File]::Move($deepFile,$deepMoved);$deepMovedIdentity=Copy-Q009FileSystemIdentityToPath $deepOwnership.identity $deepMoved;Remove-Q009ExactOwnedFile $deepMoved $deepMovedIdentity;$deepOwner=[ordered]@{attempt_id=[string]$AttemptId;root_identity=$rootReceipt.identity;sentinel_identity=$sentinelReceipt.identity;operation='deep_child_cycle'};$deepChain=New-Q009OwnedChildManifestChainHead $deep $deepIdentity $AttemptId 'capability_deep_terminal' launcher_fixture $deepOwner;[void](Remove-ExactOwnedTree $siblingDirectory $deep $deepIdentity $deepChain $AttemptId);[IO.Directory]::Move($siblingDirectory,$siblingDirectoryMoved);$siblingDirectoryMovedIdentity=Copy-Q009FileSystemIdentityToPath $siblingDirectoryIdentity $siblingDirectoryMoved;$siblingOwner=[ordered]@{attempt_id=[string]$AttemptId;root_identity=$rootReceipt.identity;sentinel_identity=$sentinelReceipt.identity;operation='sibling_directory_cycle'};$siblingChain=New-Q009OwnedChildManifestChainHead $siblingDirectoryMoved $siblingDirectoryMovedIdentity $AttemptId 'capability_sibling_terminal' launcher_fixture $siblingOwner;[void](Remove-ExactOwnedTree $root $siblingDirectoryMoved $siblingDirectoryMovedIdentity $siblingChain $AttemptId)
        $sameParentMove=$root+'.same-parent-move';$nativeMove=$root+'.native-move';$posixMove=$root+'.posix-move';$crossContainer=Join-Path $parent ('capability-cross-parent-'+[guid]::NewGuid().ToString('N'));$crossContainerIdentity=New-Q009ExactOwnedDirectory $crossContainer;$crossParent=Join-Path $crossContainer 'moved-root';$rootRenameDenied=$false;$crossRenameDenied=$false;$nativeRenameDenied=$false;$posixRenameDenied=$false;$rootDeleteDenied=$false;$nativeDeleteDenied=$false;$sentinelRenameDenied=$false;$sentinelDeleteDenied=$false;$sentinelOverwriteDenied=$false;$replacementDenied=$false
        try{[IO.Directory]::Move($root,$sameParentMove)}catch{$rootRenameDenied=$true}
        try{[IO.Directory]::Move($root,$crossParent)}catch{$crossRenameDenied=$true}
        try{Invoke-Q009PinnedCapabilityRootRenameHostile -CustodyCell $cell -Slot sentinel -SourcePath $root -DestinationPath $nativeMove -SourceIdentity $rootReceipt.identity}catch{Assert-Q009KnownSentinelDenial $_.Exception 'Native root rename';$nativeRenameDenied=$true}
        try{Invoke-Q009PinnedCapabilityRootRenameHostile -CustodyCell $cell -Slot sentinel -SourcePath $root -DestinationPath $posixMove -SourceIdentity $rootReceipt.identity -Posix}catch{Assert-Q009KnownSentinelDenial $_.Exception 'POSIX root rename';$posixRenameDenied=$true}
        try{[IO.Directory]::Delete($root,$true)}catch{$rootDeleteDenied=$true}
        try{[Q009ExactFileSystemNative]::DeleteEntryExact($root,[string]$rootReceipt.identity.native_key,[long]$rootReceipt.identity.creation_ticks,$true)}catch{Assert-Q009KnownSentinelDenial $_.Exception 'Native root delete';$nativeDeleteDenied=$true}
        try{[IO.File]::Move($sentinel,($sentinel+'.moved'))}catch{$sentinelRenameDenied=$true}
        try{[IO.File]::Delete($sentinel)}catch{$sentinelDeleteDenied=$true}
        try{[IO.File]::WriteAllText($sentinel,'overwrite',[Text.UTF8Encoding]::new($false))}catch{$sentinelOverwriteDenied=$true}
        try{[void](New-Q009ExactOwnedDirectory $root)}catch{$replacementDenied=$true}
        if(-not($rootRenameDenied-and$crossRenameDenied-and$nativeRenameDenied-and$posixRenameDenied-and$rootDeleteDenied-and$nativeDeleteDenied-and$sentinelRenameDenied-and$sentinelDeleteDenied-and$sentinelOverwriteDenied-and$replacementDenied)){throw 'Local filesystem failed the sentinel ancestor/sentinel denial capability contract'}
        if((Test-Path -LiteralPath $sameParentMove)-or(Test-Path -LiteralPath $nativeMove)-or(Test-Path -LiteralPath $posixMove)-or(Test-Path -LiteralPath $crossParent)-or-not(Test-Q009FileSystemIdentityMatch $rootReceipt.identity)-or-not(Test-Q009FileSystemIdentityMatch $sentinelReceipt.identity)){throw 'Capability hostile changed the exact root/sentinel identity'}
        $capabilityOwner=[ordered]@{root_receipt=$rootReceipt;sentinel_receipt=$sentinelReceipt;initial_close=$initialClose}
        $chainHead=New-Q009OwnedChildManifestChainHead -RootPath $root -RootIdentity $rootReceipt.identity -AttemptId $AttemptId -Boundary 'capability_operations_complete' -OwnerKind launcher_fixture -OwnerReceipt $capabilityOwner -HeldFileCustodyCell $cell -HeldFileSlot sentinel -HeldFileIdentity $sentinelReceipt.identity
        $ordinaryCleanup=Remove-Q009ManifestChildrenExceptSentinel $root $rootReceipt.identity $sentinelReceipt.identity $chainHead $AttemptId $cell;if(-not(Test-Q009ManifestCleanupReceiptShape $ordinaryCleanup)){throw 'Capability ordinary-child cleanup receipt was malformed'}
        $finalRoot=Open-Q009ExactDirectoryHeld $root $rootReceipt.identity $cell final_root;if(-not(Test-Q009FinalRootReceiptShape $finalRoot)){throw 'Capability final-root acquisition receipt was malformed'}
        $sentinelDisposition=Set-Q009HeldHandleDeletePending $cell sentinel 'Capability sentinel';if(-not(Test-Q009HeldHandleStateShape $sentinelDisposition $sentinelReceipt.identity $false)-or-not[bool]$sentinelDisposition.delete_pending){throw 'Capability sentinel disposition receipt was malformed'}
        $sentinelState=Get-Q009HeldHandleState $cell sentinel;if(-not(Test-Q009HeldHandleStateShape $sentinelState $sentinelReceipt.identity $false)-or-not[bool]$sentinelState.delete_pending){throw 'Capability sentinel was not exactly delete-pending after final-root handoff'}
        $sentinelClose=Close-Q009CheckedNativeHandle $cell sentinel 'Capability sentinel close';if(-not(Test-Q009CheckedCloseReceipt $sentinelClose)){throw 'Capability sentinel close receipt was malformed'};if(Test-Path -LiteralPath $sentinel){throw 'Capability sentinel remained after checked close'};if(@([IO.Directory]::GetFileSystemEntries($root)).Count-ne0){throw 'Capability root was not empty after sentinel close'}
        $rootDisposition=Set-Q009HeldHandleDeletePending $cell final_root 'Capability final root';if(-not(Test-Q009HeldHandleStateShape $rootDisposition $rootReceipt.identity $true)-or-not[bool]$rootDisposition.delete_pending){throw 'Capability root disposition receipt was malformed'}
        $rootClose=Close-Q009CheckedNativeHandle $cell final_root 'Capability final-root close';if(-not(Test-Q009CheckedCloseReceipt $rootClose)){throw 'Capability final-root close receipt was malformed'}
        $rootAbsence=Assert-Q009PathAbsentStrict $root;if(-not(Test-Q009StrictAbsenceReceipt $rootAbsence)){throw 'Capability root absence receipt was malformed'};$crossOwner=[ordered]@{attempt_id=[string]$AttemptId;capability_root_absence=$rootAbsence;operation='cross_container_cleanup'};$crossChain=New-Q009OwnedChildManifestChainHead $crossContainer $crossContainerIdentity $AttemptId 'capability_cross_terminal' launcher_fixture $crossOwner;[void](Remove-ExactOwnedTree $parent $crossContainer $crossContainerIdentity $crossChain $AttemptId)
        $nonterminal=@($cell.NonTerminalSlots());if($nonterminal.Count){throw ('Capability probe retained native handles: '+($nonterminal-join', '))}
        $receipt=[ordered]@{proved=[bool]$true;drive_name=[string]$drive.Name;drive_type=[string]$drive.DriveType;drive_format=[string]$drive.DriveFormat;sibling_file_cycle=[bool]$true;sibling_directory_cycle=[bool]$true;deep_child_cycle=[bool]$true;root_rename_denied=[bool]$true;cross_parent_rename_denied=[bool]$true;native_root_rename_denied=[bool]$true;posix_root_rename_denied=[bool]$true;root_delete_denied=[bool]$true;native_root_delete_denied=[bool]$true;sentinel_rename_denied=[bool]$true;sentinel_delete_denied=[bool]$true;sentinel_overwrite_denied=[bool]$true;replacement_denied=[bool]$true;root_absent=[bool]$true;all_handles_terminal=[bool]$true;observed_utc=[string][DateTime]::UtcNow.ToString('o')}
        if(-not(Test-SentinelCapabilityReceiptShape $receipt)){throw 'Sentinel filesystem capability receipt failed its exact public schema'}
        return $receipt
    }catch{
        $failure=$_.Exception.Message
        try{$release=Close-Q009AllOpenNativeHandles $cell 'Capability failure release';if(@($release.errors).Count){$failure=Join-LauncherError $failure ('handle release: '+(@($release.errors)-join'; '))}}catch{$failure=Join-LauncherError $failure ('handle release threw: '+$_.Exception.Message)}
        throw ('Sentinel filesystem capability probe failed closed; exact probe artifacts were preserved: '+$failure)
    }
}

function Convert-ToResourcePath {
    param([string]$FullPath,[object]$RunContext)
    if(-not(Test-Q009RunContextShape $RunContext)){throw 'Resource-path conversion requires one exact sealed run context'}
    $rootPrefix = ([string]$RunContext.project_root).TrimEnd('\','/') + [System.IO.Path]::DirectorySeparatorChar
    $resolved = [System.IO.Path]::GetFullPath($FullPath)
    if (-not $resolved.StartsWith($rootPrefix,[System.StringComparison]::OrdinalIgnoreCase)) { throw "Evidence path is outside project: $resolved" }
    return 'res://' + $resolved.Substring($rootPrefix.Length).Replace('\','/')
}

function Get-FileArtifact {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return [ordered]@{path=[string]$Path;present=[bool]$false;length=[long]0;sha256=[string]''} }
    return [ordered]@{path=$Path;present=$true;length=[long](Get-Item -LiteralPath $Path).Length;sha256=(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash}
}

function Get-FileArtifacts {
    param([string[]]$Paths)
    $artifacts=[System.Collections.Generic.List[object]]::new()
    foreach($path in $Paths){[void]$artifacts.Add((Get-FileArtifact $path))}
    return @($artifacts)
}

function Assert-Q009ArtifactsBoundToClosedPhaseManifest {
    param([object]$Completion,[string]$PhaseRoot,[string[]]$ArtifactPaths,[object]$RunContext)
    if(-not(Test-Q009CompletionResultShape $Completion)){throw 'Artifact binding requires one exact completion receipt'}
    $phaseReceipts=@($Completion.owned_artifact_manifests|Where-Object{[string]$_.role-ceq'phase_output'})
    if($phaseReceipts.Count-ne1){throw 'Artifact binding requires exactly one closed phase-output manifest'}
    $receipt=$phaseReceipts[0]
    if(-not(Test-Q009ClosedArtifactManifestReceiptShape $receipt $RunContext $Completion.process_identity)){throw 'Closed phase-output manifest receipt was malformed'}
    $root=[IO.Path]::GetFullPath($PhaseRoot).TrimEnd('\','/')
    if([string]$receipt.path-cne$root){throw 'Closed phase-output manifest names another root'}
    foreach($artifactPath in @($ArtifactPaths)){
        $full=[IO.Path]::GetFullPath($artifactPath)
        if(-not$full.StartsWith($root+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw "Declared phase artifact escapes its closed producer root: $full"}
        $relative=$full.Substring($root.Length).TrimStart('\','/').Replace('\','/')
        $matches=@($receipt.manifest.entries|Where-Object{[string]$_.path-ceq$relative})
        if($matches.Count-ne1-or[bool]$matches[0].is_directory){throw "Closed producer manifest omitted or mistyped phase artifact: $relative"}
        $identity=Get-Q009FileSystemEntryIdentity $full
        $artifact=Get-FileArtifact $full
        if([string]$identity.native_key-cne[string]$matches[0].native_key-or[long]$identity.creation_ticks-ne[long]$matches[0].creation_ticks-or
            -not[bool]$artifact.present-or[long]$artifact.length-ne[long]$matches[0].length-or[string]$artifact.sha256-cne[string]$matches[0].sha256){throw "Phase artifact changed after its owned process closed: $relative"}
    }
    foreach($pair in @(@('stdout.log',$Completion.stdout_identity),@('stderr.log',$Completion.stderr_identity))){
        $matches=@($receipt.manifest.entries|Where-Object{[string]$_.path-ceq[string]$pair[0]})
        if($matches.Count-ne1-or-not(Test-Q009FileSystemIdentityShape $pair[1])-or[string]$pair[1].native_key-cne[string]$matches[0].native_key-or[long]$pair[1].creation_ticks-ne[long]$matches[0].creation_ticks){throw "Redirect channel was not the exact file sealed in the closed producer manifest: $($pair[0])"}
    }
    return $receipt
}

function Test-Q009ArtifactReceiptShape {
    param([AllowNull()][object]$Receipt)
    if(-not(Test-Q009ExactPublicReceiptKeys $Receipt @('path','present','length','sha256'))-or
        $Receipt.path-isnot[string]-or[string]::IsNullOrWhiteSpace([string]$Receipt.path)-or
        $Receipt.present-isnot[bool]-or$Receipt.length-isnot[long]-or[long]$Receipt.length-lt0-or
        $Receipt.sha256-isnot[string]){return $false}
    if([bool]$Receipt.present){return [string]$Receipt.sha256-cmatch'^[0-9A-F]{64}$'}
    return [long]$Receipt.length-eq0-and[string]$Receipt.sha256-ceq''
}

function Test-Q009SetupCleanupReceiptShape {
    param([AllowNull()][object]$Receipt)
    $keys=@(
        'attempted_keys','proved_identities','residual_identities','unowned_godot_identities',
        'identity_capture_complete','root_handle_cleanup_succeeded','job_assignment_succeeded',
        'job_accounting_succeeded','job_cleanup_succeeded','job_pretermination_active_process_count',
        'job_pretermination_membership_count','job_final_active_process_count',
        'job_final_membership_empty','identity_ambiguity','known_processes_clean',
        'setup_cleanup_error','physical_clean','clean'
    )
    if(-not(Test-Q009ExactPublicReceiptKeys $Receipt $keys)){return $false}
    foreach($field in @('attempted_keys','proved_identities','residual_identities','unowned_godot_identities')){if($Receipt.$field-isnot[System.Array]){return $false}}
    foreach($value in @($Receipt.attempted_keys)){if($value-isnot[string]-or[string]::IsNullOrWhiteSpace([string]$value)){return $false}}
    foreach($field in @('proved_identities','residual_identities','unowned_godot_identities')){foreach($identity in @($Receipt.$field)){if(-not(Test-ProcessIdentityProofShape $identity)){return $false}}}
    foreach($field in @('identity_capture_complete','root_handle_cleanup_succeeded','job_assignment_succeeded','job_accounting_succeeded','job_cleanup_succeeded','job_final_membership_empty','identity_ambiguity','known_processes_clean','physical_clean','clean')){if($Receipt.$field-isnot[bool]){return $false}}
    foreach($field in @('job_pretermination_active_process_count','job_pretermination_membership_count','job_final_active_process_count')){if($Receipt.$field-isnot[int]){return $false}}
    if($Receipt.setup_cleanup_error-isnot[string]){return $false}
    return $true
}

function Test-Q009PhasePostcheckReceiptShape {
    param([AllowNull()][object]$Receipt)
    if(-not(Test-Q009ExactPublicReceiptKeys $Receipt @('clean','error','godot_identities','unowned_godot_identities','other_lease_count','residual_process_ids'))-or
        $Receipt.clean-isnot[bool]-or$Receipt.error-isnot[string]-or
        $Receipt.godot_identities-isnot[System.Array]-or$Receipt.unowned_godot_identities-isnot[System.Array]-or
        $Receipt.other_lease_count-isnot[int]-or$Receipt.residual_process_ids-isnot[System.Array]){return $false}
    foreach($field in @('godot_identities','unowned_godot_identities')){foreach($identity in @($Receipt.$field)){if(-not(Test-ProcessIdentityProofShape $identity)){return $false}}}
    foreach($processId in @($Receipt.residual_process_ids)){if($processId-isnot[int]-or[int]$processId-le0){return $false}}
    return $true
}

function Test-Q009ExecutableIdentityEvidenceShape {
    param([AllowNull()][object]$Receipt)
    if(-not(Test-Q009ExactPublicReceiptKeys $Receipt @('path','length','sha256','last_write_utc','last_write_ticks','file_version','product_version','original_filename','filesystem_identity'))-or
        $Receipt.path-isnot[string]-or[string]::IsNullOrWhiteSpace([string]$Receipt.path)-or
        $Receipt.length-isnot[long]-or[long]$Receipt.length-le0-or
        $Receipt.sha256-isnot[string]-or[string]$Receipt.sha256-cnotmatch'^[0-9A-F]{64}$'-or
        $Receipt.last_write_utc-isnot[string]-or-not(Test-Q009ExactRoundtripTimestamp $Receipt.last_write_utc)-or
        $Receipt.last_write_ticks-isnot[long]-or[long]$Receipt.last_write_ticks-le0-or
        $Receipt.file_version-isnot[string]-or$Receipt.product_version-isnot[string]-or$Receipt.original_filename-isnot[string]-or
        -not(Test-Q009FileSystemIdentityShape $Receipt.filesystem_identity)){return $false}
    $parsed=[datetime]::MinValue
    return [datetime]::TryParse([string]$Receipt.last_write_utc,[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::RoundtripKind,[ref]$parsed)-and
        [long]$parsed.ToUniversalTime().Ticks-eq[long]$Receipt.last_write_ticks
}

function Test-Q009PhaseReceiptShape {
    param([AllowNull()][object]$Phase,[AllowNull()][object]$RunContext=$null)
    $keys=@(
        'name','process_kind','command','arguments','expected_executable_path','expected_executable_sha256',
        'executable_identity','cache_handle_revalidated','run_context_sha256','process_started','start_observed',
        'process_id_observed','process_start_time_observed','process_name_observed','root_handle_cleanup_succeeded',
        'identity_ambiguity','identity_capture_complete','observed_start','process_start_provenance',
        'native_exit_source','native_exit_code','native_exit_observed','native_exit_type','effective_exit_code',
        'timed_out','elapsed_seconds','process_id','process_identity','job_assignment_succeeded',
        'job_accounting_succeeded','job_cleanup_succeeded','job_pretermination_active_process_count',
        'job_pretermination_membership_count','job_final_active_process_count','job_final_membership_empty',
        'baseline_godot_identities','prelaunch_absence','retained_descendant_identities',
        'unowned_godot_identities','owned_residual_process_ids','setup_exception_cleanup','postcheck',
        'launcher_error','diagnostics','diagnostics_clean','environment_overrides','artifacts',
        'launched_image_path','executable_pin_receipt','executable_pin_release','executable_pin_clean',
        'stdout_identity','stderr_identity','closed_artifact_manifests'
    )
    if(-not(Test-Q009ExactPublicReceiptKeys $Phase $keys)){return $false}
    foreach($field in @('name','process_kind','command','expected_executable_path','expected_executable_sha256','run_context_sha256','process_start_provenance','native_exit_source','native_exit_type','launcher_error','launched_image_path')){if($Phase.$field-isnot[string]){return $false}}
    if([string]::IsNullOrWhiteSpace([string]$Phase.name)-or[string]$Phase.process_kind-notin@('Godot','Python','Exact')-or
        [string]::IsNullOrWhiteSpace([string]$Phase.command)-or[string]::IsNullOrWhiteSpace([string]$Phase.expected_executable_path)-or
        [string]$Phase.expected_executable_sha256-cnotmatch'^[0-9A-F]{64}$'-or[string]$Phase.run_context_sha256-cnotmatch'^[0-9A-F]{64}$'-or
        -not(Test-Q009ExecutableIdentityEvidenceShape $Phase.executable_identity)){return $false}
    if($null-ne$RunContext){if(-not(Test-Q009RunContextShape $RunContext)-or[string]$Phase.run_context_sha256-cne[string]$RunContext.context_sha256){return $false}}
    foreach($field in @('cache_handle_revalidated','process_started','start_observed','process_id_observed','process_start_time_observed','process_name_observed','root_handle_cleanup_succeeded','identity_ambiguity','identity_capture_complete','native_exit_observed','timed_out','job_assignment_succeeded','job_accounting_succeeded','job_cleanup_succeeded','job_final_membership_empty','diagnostics_clean','executable_pin_clean')){if($Phase.$field-isnot[bool]){return $false}}
    foreach($field in @('native_exit_code','effective_exit_code','process_id','job_pretermination_active_process_count','job_pretermination_membership_count','job_final_active_process_count')){if($Phase.$field-isnot[int]){return $false}}
    if($Phase.elapsed_seconds-isnot[double]-or[double]$Phase.elapsed_seconds-lt0-or$Phase.arguments-isnot[System.Array]-or$Phase.baseline_godot_identities-isnot[System.Array]-or
        $Phase.retained_descendant_identities-isnot[System.Array]-or$Phase.unowned_godot_identities-isnot[System.Array]-or$Phase.owned_residual_process_ids-isnot[System.Array]-or
        $Phase.diagnostics-isnot[System.Array]-or$Phase.artifacts-isnot[System.Array]-or$Phase.environment_overrides-isnot[System.Collections.IDictionary]-or
        $Phase.closed_artifact_manifests-isnot[System.Array]){return $false}
    foreach($argument in @($Phase.arguments)){if($argument-isnot[string]){return $false}}
    foreach($field in @('baseline_godot_identities','retained_descendant_identities','unowned_godot_identities')){foreach($identity in @($Phase.$field)){if(-not(Test-ProcessIdentityProofShape $identity)){return $false}}}
    foreach($processId in @($Phase.owned_residual_process_ids)){if($processId-isnot[int]-or[int]$processId-le0){return $false}}
    foreach($diagnostic in @($Phase.diagnostics)){if($diagnostic-isnot[string]-or[string]::IsNullOrWhiteSpace([string]$diagnostic)){return $false}}
    foreach($artifact in @($Phase.artifacts)){if(-not(Test-Q009ArtifactReceiptShape $artifact)){return $false}}
    foreach($closedManifest in @($Phase.closed_artifact_manifests)){if(-not(Test-Q009ClosedArtifactManifestReceiptShape $closedManifest $RunContext $Phase.process_identity)){return $false}}
    if($null-ne$Phase.prelaunch_absence-and-not(Test-OwnedCacheAbsenceReceiptShape $Phase.prelaunch_absence)){return $false}
    if($null-ne$Phase.setup_exception_cleanup-and-not(Test-Q009SetupCleanupReceiptShape $Phase.setup_exception_cleanup)){return $false}
    if(-not(Test-Q009PhasePostcheckReceiptShape $Phase.postcheck)){return $false}
    if([bool]$Phase.process_started){
        if(-not[bool]$Phase.start_observed-or-not(Test-Q009ObservedStartReceiptShape $Phase.observed_start)){return $false}
        if([bool]$Phase.identity_capture_complete){if(-not(Test-ProcessIdentityProofShape $Phase.process_identity)-or[int]$Phase.process_id-ne[int]$Phase.process_identity.pid){return $false}}
    }elseif([bool]$Phase.start_observed-or[int]$Phase.process_id-ne0-or$null-ne$Phase.process_identity){return $false}
    if($null-ne$Phase.executable_pin_receipt-and-not(Test-Q009ExecutablePinReceiptShape $Phase.executable_pin_receipt)){return $false}
    if($null-ne$Phase.executable_pin_release-and-not(Test-Q009ExecutablePinReleaseReceiptShape $Phase.executable_pin_release)){return $false}
    if([bool]$Phase.executable_pin_clean-and($null-eq$Phase.executable_pin_receipt-or$null-eq$Phase.executable_pin_release)){return $false}
    if([bool]$Phase.native_exit_observed){
        if(-not(Test-Q009FileSystemIdentityShape $Phase.stdout_identity)-or[bool]$Phase.stdout_identity.is_directory-or
            -not(Test-Q009FileSystemIdentityShape $Phase.stderr_identity)-or[bool]$Phase.stderr_identity.is_directory){return $false}
    }elseif($null-ne$Phase.stdout_identity-or$null-ne$Phase.stderr_identity-or@($Phase.closed_artifact_manifests).Count-ne0){return $false}
    return $true
}

function Complete-Q009PhaseReceipt {
    param([System.Collections.IDictionary]$Receipt,[object]$RunContext)
    if(-not(Test-Q009PhaseReceiptShape $Receipt $RunContext)){throw 'Phase result failed its exact closed schema before publication or admission'}
    return $Receipt
}

function Invoke-ExactStartProofCleanup {
    param([object]$StartProof,[ValidateSet('Godot','Python','Exact')][string]$ProcessKind)
    if(-not(Test-Q009StartProofShape $StartProof)-or-not[bool]$StartProof.receipt_valid){throw 'Start-proof cleanup requires one valid exact closed start receipt'}
    if([bool]$StartProof.started-and[string]$StartProof.process_kind-cne$ProcessKind){throw 'Start-proof cleanup process kind differs from the exact receipt'}
    $records=[System.Collections.Generic.List[object]]::new()
    if([bool]$StartProof.started-and(Test-ProcessIdentityProofShape $StartProof.process_identity)){[void]$records.Add($StartProof.process_identity)}
    foreach($record in @($StartProof.retained_descendant_identities)){if(Test-ProcessIdentityProofShape $record){[void]$records.Add($record)}}
    $attempted=[System.Collections.Generic.List[string]]::new()
    foreach($record in @($records|Sort-Object{[int]$_.pid}-Descending)){
        $live=Get-ProcessByIdStrict -ProcessId ([int]$record.pid)
        if($null-ne$live){
            try{
                $liveIdentity=Get-ProcessIdentityRecord $live
                if([string]$liveIdentity.key-ceq[string]$record.key){[void]$attempted.Add([string]$record.key);Stop-ExactStartedProcess -Process $live -ProcessIdentity $record}
            }catch{throw "Exact setup-exception cleanup failed for PID $([int]$record.pid): $($_.Exception.Message)"}
        }
    }
    $deadline=[DateTime]::UtcNow.AddSeconds(5)
    do{
        $residual=@($records|Where-Object{Test-LiveProcessMatchesIdentity $_})
        if($residual.Count-eq0){break}
        Start-Sleep -Milliseconds 25
    }while([DateTime]::UtcNow-lt$deadline)
    $residual=@($records|Where-Object{Test-LiveProcessMatchesIdentity $_})
    $unownedGodot=[System.Collections.Generic.List[object]]::new()
    foreach($record in @($StartProof.unowned_godot_identities)){if(Test-ProcessIdentityProofShape $record){[void]$unownedGodot.Add($record)}}
    if($ProcessKind-ceq'Godot'){
        foreach($record in @(Get-NewGodotIdentityRecordsStrict -BaselineIdentityKeys @($StartProof.baseline_godot_identity_keys) -OwnedIdentityRecords @($records))){if(@($unownedGodot|Where-Object{[string]$_.key-ceq[string]$record.key}).Count-eq0){[void]$unownedGodot.Add($record)}}
    }
    $identityComplete=[bool]$StartProof.identity_capture_complete-and(Test-ProcessIdentityProofShape $StartProof.process_identity)
    $setupError=[string]$StartProof.setup_cleanup_error
    $rootHandleClean = [bool]$StartProof.root_handle_cleanup_succeeded
    $jobClean=[bool]$StartProof.job_assignment_succeeded-and[bool]$StartProof.job_accounting_succeeded-and[bool]$StartProof.job_cleanup_succeeded-and[int]$StartProof.job_pretermination_active_process_count-ge0-and[int]$StartProof.job_pretermination_membership_count-ge0-and[int]$StartProof.job_final_active_process_count-eq0-and[bool]$StartProof.job_final_membership_empty
    $knownProcessesClean=$rootHandleClean-and$jobClean-and$residual.Count-eq0-and$unownedGodot.Count-eq0
    # An incomplete root identity cannot prove that an unobserved child was not
    # spawned between the last live-handle census and root termination. Record
    # exact known-process cleanup separately, but never call the physical tree
    # clean or release custody while that ambiguity exists.
    $physicalClean=$knownProcessesClean-and-not[bool]$StartProof.identity_ambiguity
    $receipt=[ordered]@{attempted_keys=@($attempted);proved_identities=@($records);residual_identities=@($residual);unowned_godot_identities=@($unownedGodot);identity_capture_complete=[bool]$identityComplete;root_handle_cleanup_succeeded=[bool]$rootHandleClean;job_assignment_succeeded=[bool]$StartProof.job_assignment_succeeded;job_accounting_succeeded=[bool]$StartProof.job_accounting_succeeded;job_cleanup_succeeded=[bool]$StartProof.job_cleanup_succeeded;job_pretermination_active_process_count=[int]$StartProof.job_pretermination_active_process_count;job_pretermination_membership_count=[int]$StartProof.job_pretermination_membership_count;job_final_active_process_count=[int]$StartProof.job_final_active_process_count;job_final_membership_empty=[bool]$StartProof.job_final_membership_empty;identity_ambiguity=[bool]$StartProof.identity_ambiguity;known_processes_clean=[bool]$knownProcessesClean;setup_cleanup_error=[string]$setupError;physical_clean=[bool]$physicalClean;clean=[bool]($physicalClean-and$identityComplete-and[string]::IsNullOrWhiteSpace($setupError))}
    if(-not(Test-Q009SetupCleanupReceiptShape $receipt)){throw 'Start-proof cleanup result failed its exact closed schema'}
    return $receipt
}

function Register-ProcessCustodyStart {
    param([System.Collections.IDictionary]$Custody)
    if(-not(Test-ProcessCustodyTrackerShape $Custody)){throw 'Process custody tracker was malformed before start registration'}
    $Custody.start_count=[int]$Custody.start_count+1
    $Custody.start_observed=$true
    $Custody.cleanup_proved=$false
}

function Register-ProcessCustodyCleanup {
    param([System.Collections.IDictionary]$Custody,[bool]$Clean)
    if(-not(Test-ProcessCustodyTrackerShape $Custody)){throw 'Process custody tracker was malformed before cleanup registration'}
    if($Clean){$Custody.cleanup_count=[int]$Custody.cleanup_count+1}
    $Custody.cleanup_proved=([int]$Custody.cleanup_count-eq[int]$Custody.start_count)
}

function Test-ProcessCustodyTrackerShape {
    param([AllowNull()][object]$Custody)
    if(-not(Test-Q009ExactPublicReceiptKeys $Custody @('start_observed','start_count','cleanup_count','cleanup_proved'))){return $false}
    if($Custody.start_observed-isnot[bool]-or$Custody.start_count-isnot[int]-or[int]$Custody.start_count-lt0-or$Custody.cleanup_count-isnot[int]-or[int]$Custody.cleanup_count-lt0-or[int]$Custody.cleanup_count-gt[int]$Custody.start_count-or$Custody.cleanup_proved-isnot[bool]){return $false}
    return [bool]$Custody.start_observed-eq([int]$Custody.start_count-gt0)-and[bool]$Custody.cleanup_proved-eq([int]$Custody.cleanup_count-eq[int]$Custody.start_count)
}

function Get-FinalOwnedProcessResidualEvidence {
    param(
        [object[]]$Phases,
        [System.Collections.IDictionary]$ProcessCustody,
        [object]$RunContext,
        [switch]$ForceEnumerationFailureForTest
    )
    if(-not(Test-ProcessCustodyTrackerShape $ProcessCustody)){throw 'Final process proof requires one exact closed process-custody tracker'}
    if(-not(Test-Q009RunContextShape $RunContext)){throw 'Final process proof requires one exact sealed Q-009 run context'}
    $proofIssues = [System.Collections.Generic.List[string]]::new()
    $residualIdentities = [System.Collections.Generic.List[object]]::new()
    $residualPids = [System.Collections.Generic.List[int]]::new()
    $provedIdentityKeys = [System.Collections.Generic.List[string]]::new()
    $unownedGodotIdentities = [System.Collections.Generic.List[object]]::new()
    $startedPhaseCount = 0
    foreach ($phase in @($Phases)) {
        if(-not(Test-Q009PhaseReceiptShape $phase $RunContext)){throw "Final process proof rejected a malformed or context-unbound phase receipt before admission: $([string]$phase.name)"}
        $startObserved=[bool]$phase.start_observed-or[bool]$phase.process_started
        foreach($unowned in @($phase.unowned_godot_identities)){
            if((Test-ProcessIdentityProofShape $unowned)-and@($unownedGodotIdentities|Where-Object{[string]$_.key-ceq[string]$unowned.key}).Count-eq0){[void]$unownedGodotIdentities.Add($unowned)}
        }
        if(@($phase.unowned_godot_identities).Count-ne0){[void]$proofIssues.Add("phase $([string]$phase.name) observed unowned/new Godot identities")}
        if(-not[string]::IsNullOrWhiteSpace([string]$phase.launcher_error)){[void]$proofIssues.Add("phase $([string]$phase.name) retained a launcher error")}
        if($null-ne$phase.postcheck-and-not[bool]$phase.postcheck.clean){[void]$proofIssues.Add("phase $([string]$phase.name) failed its postcheck")}
        if($null-ne$phase.setup_exception_cleanup){
            if(-not[bool]$phase.setup_exception_cleanup.clean){[void]$proofIssues.Add("phase $([string]$phase.name) setup-exception cleanup was not exact")}
            foreach($unowned in @($phase.setup_exception_cleanup.unowned_godot_identities)){if((Test-ProcessIdentityProofShape $unowned)-and@($unownedGodotIdentities|Where-Object{[string]$_.key-ceq[string]$unowned.key}).Count-eq0){[void]$unownedGodotIdentities.Add($unowned)}}
        }
        if (-not $startObserved) { continue }
        $startedPhaseCount += 1
        $kind = [string]$phase.process_kind
        if ($kind -notin @('Godot','Python','Exact')) {
            [void]$proofIssues.Add("phase $([string]$phase.name) lacked an exact process_kind")
            continue
        }
        if (-not [bool]$phase.identity_capture_complete) {
            [void]$proofIssues.Add("phase $([string]$phase.name) started before exact identity capture completed")
        }
        if (-not (Test-ProcessIdentityProofShape $phase.process_identity)) {
            [void]$proofIssues.Add("phase $([string]$phase.name) lacked an exact root identity")
        }
        $records = [System.Collections.Generic.List[object]]::new()
        if(Test-ProcessIdentityProofShape $phase.process_identity){[void]$records.Add($phase.process_identity)}
        foreach ($record in @($phase.retained_descendant_identities)) {
            if (-not (Test-ProcessIdentityProofShape $record)) {
                [void]$proofIssues.Add("phase $([string]$phase.name) retained a malformed descendant identity")
                continue
            }
            [void]$records.Add($record)
        }
        foreach ($record in @($records)) {
            if (-not $provedIdentityKeys.Contains([string]$record.key)) { [void]$provedIdentityKeys.Add([string]$record.key) }
        }
        if (Test-ProcessIdentityProofShape $phase.process_identity) {
            $retainedProcessRecords = [System.Collections.Generic.List[object]]::new()
            foreach ($record in @($phase.retained_descendant_identities)) { [void]$retainedProcessRecords.Add($record) }
            $livePids = @(Get-ExactOwnedProcessResidualPids -RootIdentity $phase.process_identity -BaselineIdentityKeys @() -RetainedDescendantRecords $retainedProcessRecords -ForceEnumerationFailureForTest:$ForceEnumerationFailureForTest)
            foreach ($livePid in $livePids) {
                if (-not $residualPids.Contains([int]$livePid)) { [void]$residualPids.Add([int]$livePid) }
                $matching = @($records | Where-Object { [int]$_.pid -eq [int]$livePid })
                foreach ($record in $matching) {
                    if (@($residualIdentities | Where-Object { [string]$_.key -ceq [string]$record.key }).Count -eq 0) { [void]$residualIdentities.Add($record) }
                }
            }
        }
        if (@($phase.owned_residual_process_ids).Count -ne 0) {
            [void]$proofIssues.Add("phase $([string]$phase.name) previously failed its exact residual proof")
        }
    }
    $globalCensus=Get-StrictGodotIdentityCensus residual -ForceEnumerationFailureForTest:$ForceEnumerationFailureForTest
    $globalGodot=@($globalCensus.identity_records)
    foreach($record in $globalGodot){if(@($unownedGodotIdentities|Where-Object{[string]$_.key-ceq[string]$record.key}).Count-eq0){[void]$unownedGodotIdentities.Add($record)}}
    if($globalGodot.Count-ne0){[void]$proofIssues.Add('global Godot census was nonzero during final process proof')}
    if ($startedPhaseCount -ne [int]$ProcessCustody.start_count) { [void]$proofIssues.Add('started phase count did not match process custody start_count') }
    if (-not [bool]$ProcessCustody.cleanup_proved -or [int]$ProcessCustody.cleanup_count -ne [int]$ProcessCustody.start_count) {
        [void]$proofIssues.Add('process custody cleanup counts were not exact and complete')
    }
    return [ordered]@{
        checked = $true
        run_context_sha256 = [string]$RunContext.context_sha256
        started_phase_count = $startedPhaseCount
        proved_identity_keys = @($provedIdentityKeys)
        residual_process_ids = @($residualPids)
        residual_identities = @($residualIdentities)
        unowned_godot_identities = @($unownedGodotIdentities)
        global_godot_identities = @($globalGodot)
        proof_issues = @($proofIssues)
        clean = ($proofIssues.Count -eq 0 -and $residualPids.Count -eq 0 -and $unownedGodotIdentities.Count-eq0 -and $globalGodot.Count-eq0)
    }
}

function Test-MayRemoveOwnedRuntimeArtifacts {
    param([object]$FinalProcessEvidence,[AllowNull()][object]$RunContext=$null)
    return (Test-FinalOwnedProcessResidualEvidenceShape $FinalProcessEvidence $RunContext) -and
        [bool]$FinalProcessEvidence.checked -and[bool]$FinalProcessEvidence.clean -and
        @($FinalProcessEvidence.residual_process_ids).Count -eq 0 -and
        @($FinalProcessEvidence.unowned_godot_identities).Count -eq 0 -and
        @($FinalProcessEvidence.global_godot_identities).Count -eq 0 -and
        @($FinalProcessEvidence.proof_issues).Count -eq 0
}

function Test-FinalOwnedProcessResidualEvidenceShape {
    param([AllowNull()][object]$Evidence,[AllowNull()][object]$RunContext=$null)
    if(-not(Test-Q009ExactPublicReceiptKeys $Evidence @('checked','run_context_sha256','started_phase_count','proved_identity_keys','residual_process_ids','residual_identities','unowned_godot_identities','global_godot_identities','proof_issues','clean'))){return $false}
    if($Evidence.checked-isnot[bool]-or$Evidence.clean-isnot[bool]-or$Evidence.run_context_sha256-isnot[string]-or[string]$Evidence.run_context_sha256-cnotmatch'^[0-9A-F]{64}$'-or$Evidence.started_phase_count-isnot[int]-or[int]$Evidence.started_phase_count-lt0){return $false}
    if($null-ne$RunContext-and(-not(Test-Q009RunContextShape $RunContext)-or[string]$Evidence.run_context_sha256-cne[string]$RunContext.context_sha256)){return $false}
    foreach($field in @('proved_identity_keys','residual_process_ids','residual_identities','unowned_godot_identities','global_godot_identities','proof_issues')){if($Evidence[$field]-isnot[System.Array]){return $false}}
    foreach($value in @($Evidence.proved_identity_keys)){if($value-isnot[string]-or[string]::IsNullOrWhiteSpace([string]$value)){return $false}}
    foreach($value in @($Evidence.residual_process_ids)){if($value-isnot[int]-or[int]$value-le0){return $false}}
    foreach($field in @('residual_identities','unowned_godot_identities','global_godot_identities')){foreach($value in @($Evidence[$field])){if(-not(Test-ProcessIdentityProofShape $value)){return $false}}}
    foreach($value in @($Evidence.proof_issues)){if($value-isnot[string]-or[string]::IsNullOrWhiteSpace([string]$value)){return $false}}
    return $true
}

function Test-MayReleaseExclusiveReservation {
    param([bool]$LeaseOwned,[bool]$CleanupSucceeded,[bool]$FinalProvenanceValid,[System.Collections.IDictionary]$ProcessCustody)
    if(-not(Test-ProcessCustodyTrackerShape $ProcessCustody)){return $false}
    return $LeaseOwned-and$CleanupSucceeded-and$FinalProvenanceValid-and[bool]$ProcessCustody.cleanup_proved-and[int]$ProcessCustody.start_count-eq[int]$ProcessCustody.cleanup_count
}

function Invoke-ExclusiveProcessPhase {
    param(
        [string]$Name,[string]$FilePath,[string[]]$Arguments,[string]$PhaseRoot,
        [ValidateSet('Godot','Python','Exact')][string]$ProcessKind,
        [string]$Commit,[string]$Tree,[string]$AttemptId,[object]$LauncherIdentity,
        [System.Collections.IDictionary]$Pinned,[System.Collections.IDictionary]$DependencyPins,[System.Collections.IDictionary]$EnvironmentBaseline,
        [string]$OwnerClaimPath,[string]$OwnerClaimText,[string]$OwnerClaimSha256,[string]$OwnedRoot,
        [object]$ExecutableIdentity,[string]$ExpectedExecutablePath,[string]$ExpectedExecutableSha256,
        [System.Collections.IDictionary]$EnvironmentOverrides,
        [string[]]$AdditionalLogPaths=@(),[int]$TimeoutSeconds,
        [System.Collections.IDictionary]$ProcessCustody,
        [string]$RequireAbsentPathBeforeLaunch='',
        [object]$OwnerReceipt=$null,
        [object]$HeldExclusiveLease=$null,
        [System.Collections.IDictionary]$CacheCustody=$null,
        [object]$CacheCreatorIdentity=$null,
        [string[]]$AdditionalArtifactPaths=@(),
        [object[]]$OwnedArtifactRoots=@(),
        [object]$RunContext
    )
    if(-not(Test-Q009RunContextShape $RunContext)-or[string]$RunContext.attempt_id-cne$AttemptId-or[string]$RunContext.candidate_commit-cne$Commit-or[string]$RunContext.candidate_tree-cne$Tree-or[string]$RunContext.launcher_identity.key-cne[string]$LauncherIdentity.key){throw 'Process phase requires the exact immutable run context for this attempt/candidate/launcher'}
    $phaseRootFull=[IO.Path]::GetFullPath($PhaseRoot).TrimEnd('\','/')
    $ownedRootFull=[IO.Path]::GetFullPath($OwnedRoot).TrimEnd('\','/')
    if(-not$phaseRootFull.StartsWith($ownedRootFull+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Process phase root escapes the exact owned evidence root'}
    Assert-NoReparsePathChain $OwnedRoot ([IO.Path]::GetDirectoryName($phaseRootFull))
    if(Test-Path -LiteralPath $phaseRootFull){throw 'Process phase root already exists before exact atomic creation'}
    $phaseRootIdentity=New-Q009ExactOwnedDirectory $phaseRootFull
    Assert-NoReparsePathChain $OwnedRoot $PhaseRoot
    $stdoutPath = Join-Path $PhaseRoot 'stdout.log'; $stderrPath = Join-Path $PhaseRoot 'stderr.log'
    $completionArtifactRoots=[Collections.Generic.List[object]]::new()
    [void]$completionArtifactRoots.Add([ordered]@{role='phase_output';path=$phaseRootFull;root_identity=$phaseRootIdentity})
    foreach($ownedArtifactRoot in @($OwnedArtifactRoots)){
        if(-not(Test-Q009OwnedArtifactRootRequestShape $ownedArtifactRoot)){throw 'Process phase received a malformed closed-process artifact request'}
        if(@($completionArtifactRoots|Where-Object{[string]$_.role-ceq[string]$ownedArtifactRoot.role}).Count-ne0){throw 'Process phase received a duplicate closed-process artifact role'}
        [void]$completionArtifactRoots.Add($ownedArtifactRoot)
    }
    $started = $null; $startError=''; $restoreError=''; $mutexError=''; $prelaunchAbsence=$null;$cacheHandleRevalidated=$false;$baselineGodotIdentities=@();$startProof=New-Q009MissingStartProof
    $mutex=$null; $mutexOwned=$false
    try {
        $mutex=[System.Threading.Mutex]::new($false,[string]$RunContext.launch_mutex_name)
        try{$mutexOwned=$mutex.WaitOne(5000)}catch [Threading.AbandonedMutexException] {$mutexOwned=$true;throw 'Q-009 launch mutex was abandoned; phase launch failed closed after recovering ownership'}
        if(-not $mutexOwned){throw 'Could not acquire Q-009 launch mutex'}
        Assert-ExclusiveReady $LauncherIdentity $Commit $Tree $AttemptId $Pinned $DependencyPins $EnvironmentBaseline $OwnerClaimPath $OwnerClaimText $OwnerClaimSha256 $OwnedRoot $OwnerReceipt $HeldExclusiveLease $RunContext
        [void](Assert-ExecutableIdentity $Name $FilePath $ExpectedExecutablePath $ExpectedExecutableSha256 $ExecutableIdentity)
        if(($null-eq$CacheCustody)-ne($null-eq$CacheCreatorIdentity)){throw 'Cache custody and creator identity must be supplied together'}
        if($null-ne$CacheCustody){[void](Get-SentinelPinnedCacheProof $CacheCustody $CacheCreatorIdentity ([string]$RunContext.project_cache_root) $AttemptId $Commit $Tree);$cacheHandleRevalidated=$true}
        $baselineGodotIdentities=@((Get-StrictGodotIdentityCensus readiness).identity_records)
        if($baselineGodotIdentities.Count-ne0){throw 'Fresh pre-launch Godot census was nonzero under EXCLUSIVE custody'}
        if(-not[string]::IsNullOrWhiteSpace($RequireAbsentPathBeforeLaunch)){$prelaunchAbsence=Assert-OwnedCacheAbsentImmediatelyBeforeImport $RequireAbsentPathBeforeLaunch ([string]$RunContext.project_root)}
        Set-EnvironmentOverrides $EnvironmentOverrides
        $started=Start-RedirectedProcess -FilePath $FilePath -Arguments $Arguments -StdoutPath $stdoutPath -StderrPath $stderrPath -ProcessKind $ProcessKind -BaselineGodotIdentityKeys @($baselineGodotIdentities|ForEach-Object{[string]$_.key}) -TimeoutSec $TimeoutSeconds -ExpectedExecutableIdentity $ExecutableIdentity -RunContext $RunContext
        Register-ProcessCustodyStart $ProcessCustody
    }
    catch { $startError=$_.Exception.Message; $startProof=Get-OwnedProcessStartProofFromException $_.Exception;if(-not(Test-Q009StartProofShape $startProof)-or-not[bool]$startProof.receipt_valid){$startError=Join-LauncherError $startError ('invalid start receipt: '+[string]$startProof.validation_error)}elseif([bool]$startProof.started){Register-ProcessCustodyStart $ProcessCustody} }
    finally {
        try{$restore=Restore-ProcessEnvironmentSafely -Snapshot $EnvironmentBaseline;if(-not$restore.succeeded){$restoreError=[string]$restore.error}}catch{$restoreError=$_.Exception.Message}
        if($mutexOwned-and$null-ne$mutex){try{$mutex.ReleaseMutex()}catch{$mutexError=Join-LauncherError $mutexError ('mutex release: '+$_.Exception.Message)}}
        if($null-ne$mutex){try{$mutex.Dispose()}catch{$mutexError=Join-LauncherError $mutexError ('mutex dispose: '+$_.Exception.Message)}}
    }
    if($null -eq $started){
        try{$setupCleanup=Invoke-ExactStartProofCleanup $startProof $ProcessKind}catch{
            $conservativeResiduals=[System.Collections.Generic.List[object]]::new();$proofShape=Test-Q009StartProofShape $startProof
            if($proofShape-and(Test-ProcessIdentityProofShape $startProof.process_identity)){[void]$conservativeResiduals.Add($startProof.process_identity)}
            if($proofShape){foreach($record in @($startProof.retained_descendant_identities)){if(Test-ProcessIdentityProofShape $record){[void]$conservativeResiduals.Add($record)}}}
            $setupCleanup=[ordered]@{attempted_keys=[object[]]@();proved_identities=[object[]]@($conservativeResiduals);residual_identities=[object[]]@($conservativeResiduals);unowned_godot_identities=[object[]]@();identity_capture_complete=[bool]$false;root_handle_cleanup_succeeded=[bool]$false;job_assignment_succeeded=[bool]$false;job_accounting_succeeded=[bool]$false;job_cleanup_succeeded=[bool]$false;job_pretermination_active_process_count=[int]-1;job_pretermination_membership_count=[int]-1;job_final_active_process_count=[int]-1;job_final_membership_empty=[bool]$false;identity_ambiguity=[bool]$true;known_processes_clean=[bool]$false;setup_cleanup_error=[string]('cleanup census failed closed: '+$_.Exception.Message);physical_clean=[bool]$false;clean=[bool]$false}
            if(-not(Test-Q009SetupCleanupReceiptShape $setupCleanup)){throw 'Fail-closed setup cleanup receipt construction failed'}
        }
        $validStartProof=(Test-Q009StartProofShape $startProof)-and[bool]$startProof.receipt_valid
        if($validStartProof-and[bool]$startProof.started){Register-ProcessCustodyCleanup $ProcessCustody ([bool]$setupCleanup.clean)}
        $combinedError=$startError
        if($restoreError){$combinedError=Join-LauncherError $combinedError ('environment restore: '+$restoreError)}
        if($mutexError){$combinedError=Join-LauncherError $combinedError $mutexError}
        if(-not$setupCleanup.clean){$combinedError=Join-LauncherError $combinedError 'setup-exception exact-process cleanup or residual proof failed'}
        $setupPostcheck=[ordered]@{clean=[bool]$false;error=[string]$combinedError;godot_identities=[object[]]@($setupCleanup.unowned_godot_identities);unowned_godot_identities=[object[]]@($setupCleanup.unowned_godot_identities);other_lease_count=[int]-1;residual_process_ids=[object[]]@($setupCleanup.residual_identities|ForEach-Object{[int]$_.pid})}
        $phase=[ordered]@{
            name=[string]$Name;process_kind=[string]$ProcessKind;command=[string]$FilePath;arguments=[string[]]@($Arguments);expected_executable_path=[string]$ExpectedExecutablePath;expected_executable_sha256=[string]$ExpectedExecutableSha256;executable_identity=$ExecutableIdentity
            cache_handle_revalidated=[bool]$cacheHandleRevalidated;run_context_sha256=[string]$RunContext.context_sha256;process_started=[bool]($validStartProof-and[bool]$startProof.started);start_observed=[bool]($validStartProof-and[bool]$startProof.start_observed);process_id_observed=[bool]($validStartProof-and[bool]$startProof.process_id_observed);process_start_time_observed=[bool]($validStartProof-and[bool]$startProof.process_start_time_observed);process_name_observed=[bool]($validStartProof-and[bool]$startProof.process_name_observed);root_handle_cleanup_succeeded=[bool]($validStartProof-and[bool]$startProof.root_handle_cleanup_succeeded);identity_ambiguity=[bool](-not$validStartProof-or[bool]$startProof.identity_ambiguity);identity_capture_complete=[bool]($validStartProof-and[bool]$startProof.identity_capture_complete);observed_start=if($validStartProof){$startProof.observed_start}else{$null};process_start_provenance=if($validStartProof){[string]$startProof.provenance}else{'none'}
            native_exit_source=[string]'';native_exit_code=[int]$RunContext.native_exit_sentinel;native_exit_observed=[bool]$false;native_exit_type=[string]'';effective_exit_code=[int]125;timed_out=[bool]$false;elapsed_seconds=[double]0.0;process_id=if($validStartProof){[int]$startProof.process_id}else{[int]0};process_identity=if($validStartProof){$startProof.process_identity}else{$null}
            job_assignment_succeeded=[bool]($validStartProof-and[bool]$startProof.job_assignment_succeeded);job_accounting_succeeded=[bool]($validStartProof-and[bool]$startProof.job_accounting_succeeded);job_cleanup_succeeded=[bool]($validStartProof-and[bool]$startProof.job_cleanup_succeeded);job_pretermination_active_process_count=if($validStartProof){[int]$startProof.job_pretermination_active_process_count}else{[int]-1};job_pretermination_membership_count=if($validStartProof){[int]$startProof.job_pretermination_membership_count}else{[int]-1};job_final_active_process_count=if($validStartProof){[int]$startProof.job_final_active_process_count}else{[int]-1};job_final_membership_empty=[bool]($validStartProof-and[bool]$startProof.job_final_membership_empty)
            baseline_godot_identities=[object[]]@($baselineGodotIdentities);prelaunch_absence=$prelaunchAbsence;retained_descendant_identities=if($validStartProof){[object[]]@($startProof.retained_descendant_identities)}else{[object[]]@()};unowned_godot_identities=[object[]]@($setupCleanup.unowned_godot_identities);owned_residual_process_ids=[object[]]@($setupCleanup.residual_identities|ForEach-Object{[int]$_.pid});setup_exception_cleanup=$setupCleanup;postcheck=$setupPostcheck;launcher_error=[string]$combinedError;diagnostics=[object[]]@();diagnostics_clean=[bool]$false;environment_overrides=$EnvironmentOverrides;artifacts=[object[]]@(Get-FileArtifacts (@($stdoutPath,$stderrPath)+@($AdditionalLogPaths)))
            launched_image_path=if($validStartProof){[string]$startProof.launched_image_path}else{[string]''};executable_pin_receipt=if($validStartProof){$startProof.executable_pin_receipt}else{$null};executable_pin_release=if($validStartProof){$startProof.executable_pin_release}else{$null};executable_pin_clean=[bool]($validStartProof-and$null-ne$startProof.executable_pin_release-and[bool]$startProof.executable_pin_release.released-and[bool]$startProof.executable_pin_release.all_terminal)
            stdout_identity=$null;stderr_identity=$null;closed_artifact_manifests=[object[]]@()
        }
        return Complete-Q009PhaseReceipt $phase $RunContext
    }
    # Completion and exact-tree cleanup are mandatory once Start succeeded,
    # even when restoring the launcher's environment or mutex teardown failed.
    $result=$null;$completionError=''
    try{$result=Complete-RedirectedProcess -Started $started -TimeoutSec $TimeoutSeconds -ProcessKind $ProcessKind -BaselineGodotIdentityKeys @($baselineGodotIdentities|ForEach-Object{[string]$_.key}) -OwnedArtifactRoots @($completionArtifactRoots) -RunContext $RunContext;if(-not(Test-Q009CompletionResultShape $result)){throw 'Completion result failed its exact closed schema before phase admission'}}catch{$completionError=$_.Exception.Message;$result=$null}
    if($null-eq$result){
        throw ('Owned process completion produced no exact closed receipt: '+$completionError)
    }
    if(@($result.owned_artifact_manifests).Count-ne@($completionArtifactRoots).Count-or@($result.owned_artifact_manifests|Where-Object{[string]$_.role-ceq'phase_output'}).Count-ne1){throw 'Owned process completion omitted or duplicated a declared terminal artifact manifest'}
    $residuals=@(Get-ExactOwnedProcessResidualPids -RootIdentity $started.process_identity -BaselineIdentityKeys @($baselineGodotIdentities|ForEach-Object{[string]$_.key}) -RetainedDescendantRecords $started.retained_descendant_records)
    Register-ProcessCustodyCleanup $ProcessCustody ($residuals.Count-eq0)
    $allPaths=@($stdoutPath,$stderrPath)+@($AdditionalLogPaths)+@($AdditionalArtifactPaths);$combined='';$artifacts=[System.Collections.Generic.List[object]]::new()
    [void](Assert-Q009ArtifactsBoundToClosedPhaseManifest $result $phaseRootFull $allPaths $RunContext)
    foreach($path in $allPaths){[void]$artifacts.Add((Get-FileArtifact $path))}
    foreach($path in @($stdoutPath,$stderrPath)+@($AdditionalLogPaths)){if(Test-Path -LiteralPath $path -PathType Leaf){$combined+="`n---$([IO.Path]::GetFileName($path))---`n"+[IO.File]::ReadAllText($path)}}
    $diagnostics=@(Get-StrictDiagnosticLines $combined)
    $postError='';$postGodot=@();$postOtherLeaseCount=-1
    try {
        [void](Assert-CleanExactCandidate ([string]$RunContext.project_root) $Commit $Tree);Assert-PinnedFilesStable $Pinned $RunContext $DependencyPins
        if($null-ne$CacheCustody){[void](Get-SentinelPinnedCacheProof $CacheCustody $CacheCreatorIdentity ([string]$RunContext.project_cache_root) $AttemptId $Commit $Tree)}
        Assert-ExactExclusiveLease $HeldExclusiveLease $RunContext
        Assert-ExactAttemptOwner $OwnerClaimPath $OwnerClaimText $OwnerClaimSha256 $OwnedRoot $OwnerReceipt
        [void](Assert-ExecutableIdentity $Name $FilePath $ExpectedExecutablePath $ExpectedExecutableSha256 $ExecutableIdentity)
        $postOtherLeases=@(Get-CanonicalLeaseFilesStrict -RunContext $RunContext -ExcludeExclusive);$postOtherLeaseCount=$postOtherLeases.Count;if($postOtherLeaseCount-ne0){throw 'other Q-009 lease appeared during EXCLUSIVE phase'}
        if(-not (Test-EnvironmentMatchesSnapshot $EnvironmentBaseline)){throw 'environment did not restore'}
        $postGodot=@((Get-StrictGodotIdentityCensus postcheck).identity_records);if($postGodot.Count -ne 0){throw 'Godot process remained or appeared after phase'}
        if($residuals.Count -ne 0){throw "owned process residuals: $($residuals -join ',')"}
        $missingArtifacts=@($artifacts|Where-Object{-not $_.present});if($missingArtifacts.Count-ne0){throw "phase omitted $($missingArtifacts.Count) declared stdout/stderr/log artifacts"}
    } catch {$postError=$_.Exception.Message}
    $launcherError=[string]$result.error
    if($restoreError){$launcherError=Join-LauncherError $launcherError ('environment restore: '+$restoreError)}
    if($mutexError){$launcherError=Join-LauncherError $launcherError $mutexError}
    if($postError){if($launcherError){$launcherError+=' | '};$launcherError+=$postError}
    $unownedPost=@($postGodot|Where-Object{@($baselineGodotIdentities|ForEach-Object{[string]$_.key})-notcontains[string]$_.key})
    $postcheck=[ordered]@{clean=[bool][string]::IsNullOrWhiteSpace($postError);error=[string]$postError;godot_identities=[object[]]@($postGodot);unowned_godot_identities=[object[]]@($unownedPost);other_lease_count=[int]$postOtherLeaseCount;residual_process_ids=[object[]]@($residuals|ForEach-Object{[int]$_})}
    $observedStart=[ordered]@{
        process_id=[int]$result.process_id;process_name=[string]$result.process_identity.name
        launch_lower_utc=[string]$started.launch_lower_utc.ToUniversalTime().ToString('o');launch_lower_ticks=[long]$started.launch_lower_utc.ToUniversalTime().Ticks
        launch_upper_utc=[string]$started.launch_upper_utc.ToUniversalTime().ToString('o');launch_upper_ticks=[long]$started.launch_upper_utc.ToUniversalTime().Ticks
        process_start_utc=[string]$result.started_utc;process_start_ticks=[long]$result.process_identity.start_ticks
    }
    if(-not(Test-Q009ObservedStartReceiptShape $observedStart)){throw 'Completed phase observed-start receipt failed its exact schema'}
    $phase=[ordered]@{
        name=[string]$Name;process_kind=[string]$ProcessKind;command=[string]$FilePath;arguments=[string[]]@($Arguments);expected_executable_path=[string]$ExpectedExecutablePath;expected_executable_sha256=[string]$ExpectedExecutableSha256;executable_identity=$ExecutableIdentity
        cache_handle_revalidated=[bool]$cacheHandleRevalidated;run_context_sha256=[string]$RunContext.context_sha256;process_started=[bool]$true;start_observed=[bool]$true;process_id_observed=[bool]$true;process_start_time_observed=[bool]$true;process_name_observed=[bool]$true;root_handle_cleanup_succeeded=[bool]$true;identity_ambiguity=[bool]$false;identity_capture_complete=[bool]$true;observed_start=$observedStart;process_start_provenance=[string]$result.process_start_provenance
        native_exit_source=[string]$result.native_exit_source;native_exit_code=[int]$result.native_exit_code;native_exit_observed=[bool]$result.native_exit_observed;native_exit_type=[string]$result.native_exit_type;effective_exit_code=[int]$result.effective_exit_code;timed_out=[bool]$result.timed_out;elapsed_seconds=[double]$result.elapsed_seconds;process_id=[int]$result.process_id;process_identity=$result.process_identity
        job_assignment_succeeded=[bool]$result.job_assignment_succeeded;job_accounting_succeeded=[bool]$result.job_accounting_succeeded;job_cleanup_succeeded=[bool]$result.job_cleanup_succeeded;job_pretermination_active_process_count=[int]$result.job_pretermination_active_process_count;job_pretermination_membership_count=[int]$result.job_pretermination_membership_count;job_final_active_process_count=[int]$result.job_final_active_process_count;job_final_membership_empty=[bool]$result.job_final_membership_empty
        baseline_godot_identities=[object[]]@($baselineGodotIdentities);prelaunch_absence=$prelaunchAbsence;retained_descendant_identities=[object[]]@($result.retained_descendant_identities);unowned_godot_identities=[object[]]@($unownedPost);owned_residual_process_ids=[object[]]@($residuals|ForEach-Object{[int]$_});setup_exception_cleanup=$null;postcheck=$postcheck;launcher_error=[string]$launcherError;diagnostics=[object[]]@($diagnostics);diagnostics_clean=[bool]($diagnostics.Count-eq0);environment_overrides=$EnvironmentOverrides;artifacts=[object[]]@($artifacts)
        launched_image_path=[string]$result.launched_image_path;executable_pin_receipt=$result.executable_pin_receipt;executable_pin_release=$result.executable_pin_release;executable_pin_clean=[bool]$result.executable_pin_clean
        stdout_identity=$result.stdout_identity;stderr_identity=$result.stderr_identity;closed_artifact_manifests=[object[]]@($result.owned_artifact_manifests)
    }
    return Complete-Q009PhaseReceipt $phase $RunContext
}

function Update-Q009RuntimeArtifactManifestChains {
    param(
        [object]$Phase,[object]$RunContext,
        [string]$CacheRoot,[object]$CacheRootIdentity,[object]$CacheChain,
        [string]$ProfileAggregateRoot,[object]$ProfileAggregateRootIdentity,[object]$ProfileChain,
        [bool]$ExpectProfile,[object]$CacheCustody,[object]$CacheSentinelIdentity
    )
    if(-not(Test-Q009PhaseReceiptShape $Phase $RunContext)-or-not[bool]$Phase.native_exit_observed){throw 'Runtime artifact-chain update requires one completed exact phase receipt'}
    $cacheReceipts=@($Phase.closed_artifact_manifests|Where-Object{[string]$_.role-ceq'project_cache'})
    $profileReceipts=@($Phase.closed_artifact_manifests|Where-Object{[string]$_.role-ceq'profile'})
    $phaseReceipts=@($Phase.closed_artifact_manifests|Where-Object{[string]$_.role-ceq'phase_output'})
    $expectedProfileCount=if($ExpectProfile){1}else{0}
    if($cacheReceipts.Count-ne1-or$phaseReceipts.Count-ne1-or$profileReceipts.Count-ne$expectedProfileCount){throw 'Completed phase terminal artifact roles did not match its exact launch contract'}
    $cacheReceipt=$cacheReceipts[0]
    if([string]$cacheReceipt.root_identity.key-cne[string]$CacheRootIdentity.key-or[string]$cacheReceipt.path-cne[IO.Path]::GetFullPath($CacheRoot).TrimEnd('\','/')){throw 'Completed phase cache manifest names another cache root'}
    $nextCache=New-Q009OwnedChildManifestChainHead -RootPath $CacheRoot -RootIdentity $CacheRootIdentity -AttemptId ([string]$RunContext.attempt_id) -Boundary ('closed_process_cache_'+[string]$Phase.name) -OwnerKind closed_process_phase -OwnerReceipt $cacheReceipt -PreviousHead $CacheChain -HeldFileCustodyCell $CacheCustody -HeldFileSlot sentinel -HeldFileIdentity $CacheSentinelIdentity
    $nextProfile=$ProfileChain
    if($ExpectProfile){
        $profileReceipt=$profileReceipts[0]
        if(-not(Test-Q009FileSystemIdentityMatch $profileReceipt.root_identity)){throw 'Completed phase profile root was replaced before aggregate custody handoff'}
        $owner=[ordered]@{phase_name=[string]$Phase.name;phase_process_identity=$Phase.process_identity;profile_manifest=$profileReceipt;phase_output_manifest=$phaseReceipts[0]}
        $nextProfile=New-Q009OwnedChildManifestChainHead -RootPath $ProfileAggregateRoot -RootIdentity $ProfileAggregateRootIdentity -AttemptId ([string]$RunContext.attempt_id) -Boundary ('closed_process_profile_'+[string]$Phase.name) -OwnerKind closed_process_phase -OwnerReceipt $owner -PreviousHead $ProfileChain
    }
    return [ordered]@{cache_chain=$nextCache;profile_chain=$nextProfile;cache_receipt=$cacheReceipt;profile_receipt=if($ExpectProfile){$profileReceipts[0]}else{$null};phase_output_receipt=$phaseReceipts[0]}
}

function Test-PhaseInfrastructureClean {
    param([object]$Phase,[int[]]$AllowedNativeExitCodes=@(0),[AllowNull()][object]$RunContext=$null)
    if(-not(Test-Q009PhaseReceiptShape $Phase $RunContext)){return $false}
    return [bool]$Phase.cache_handle_revalidated -and [bool]$Phase.process_started -and [bool]$Phase.start_observed -and [bool]$Phase.identity_capture_complete -and [bool]$Phase.native_exit_observed -and [string]$Phase.native_exit_type -ceq 'System.Int32' -and [string]$Phase.native_exit_source -ceq 'owned_native_process_handle' -and [bool]$Phase.job_assignment_succeeded -and [bool]$Phase.job_accounting_succeeded -and [bool]$Phase.job_cleanup_succeeded -and [int]$Phase.job_pretermination_active_process_count-ge0 -and [int]$Phase.job_pretermination_membership_count-ge0 -and [int]$Phase.job_final_active_process_count-eq0 -and [bool]$Phase.job_final_membership_empty -and -not [bool]$Phase.timed_out -and [string]::IsNullOrWhiteSpace([string]$Phase.launcher_error) -and [bool]$Phase.diagnostics_clean -and $AllowedNativeExitCodes -contains [int]$Phase.native_exit_code -and [int]$Phase.effective_exit_code -eq [int]$Phase.native_exit_code -and @($Phase.owned_residual_process_ids).Count -eq 0 -and @($Phase.unowned_godot_identities).Count-eq0 -and $null-ne$Phase.postcheck -and [bool]$Phase.postcheck.clean
}

function Test-PhaseCustodyClean {
    param([object]$Phase,[int[]]$AllowedNativeExitCodes=@(0),[AllowNull()][object]$RunContext=$null)
    if(-not(Test-Q009PhaseReceiptShape $Phase $RunContext)){return $false}
    return [bool]$Phase.cache_handle_revalidated -and [bool]$Phase.process_started -and [bool]$Phase.start_observed -and [bool]$Phase.identity_capture_complete -and [bool]$Phase.native_exit_observed -and [string]$Phase.native_exit_type -ceq 'System.Int32' -and [string]$Phase.native_exit_source -ceq 'owned_native_process_handle' -and [bool]$Phase.job_assignment_succeeded -and [bool]$Phase.job_accounting_succeeded -and [bool]$Phase.job_cleanup_succeeded -and [int]$Phase.job_pretermination_active_process_count-ge0 -and [int]$Phase.job_pretermination_membership_count-ge0 -and [int]$Phase.job_final_active_process_count-eq0 -and [bool]$Phase.job_final_membership_empty -and -not [bool]$Phase.timed_out -and [string]::IsNullOrWhiteSpace([string]$Phase.launcher_error) -and $AllowedNativeExitCodes -contains [int]$Phase.native_exit_code -and [int]$Phase.effective_exit_code -eq [int]$Phase.native_exit_code -and @($Phase.owned_residual_process_ids).Count -eq 0 -and @($Phase.unowned_godot_identities).Count-eq0 -and $null-ne$Phase.postcheck -and [bool]$Phase.postcheck.clean
}

function New-Q009ClosedPhaseFixture {
    param(
        [string]$Name,
        [ValidateSet('Godot','Python','Exact')][string]$ProcessKind,
        [object]$RunContext,
        [object]$ExecutableIdentity,
        [AllowNull()][object]$ProcessIdentity=$null,
        [bool]$ProcessStarted=$false
    )
    if(-not(Test-Q009RunContextShape $RunContext)-or-not(Test-Q009ExecutableIdentityEvidenceShape $ExecutableIdentity)){throw 'Closed phase fixture requires exact context and executable identity receipts'}
    if($ProcessStarted-and-not(Test-ProcessIdentityProofShape $ProcessIdentity)){throw 'Started closed phase fixture requires one exact process identity'}
    $observedStart=if($ProcessStarted){
        [ordered]@{process_id=[int]$ProcessIdentity.pid;process_name=[string]$ProcessIdentity.name;launch_lower_utc=[string]$ProcessIdentity.start_utc;launch_lower_ticks=[long]$ProcessIdentity.start_ticks;launch_upper_utc=[string]$ProcessIdentity.start_utc;launch_upper_ticks=[long]$ProcessIdentity.start_ticks;process_start_utc=[string]$ProcessIdentity.start_utc;process_start_ticks=[long]$ProcessIdentity.start_ticks}
    }else{$null}
    $phase=[ordered]@{
        name=[string]$Name;process_kind=[string]$ProcessKind;command=[string]$ExecutableIdentity.path;arguments=[object[]]@();expected_executable_path=[string]$ExecutableIdentity.path;expected_executable_sha256=[string]$ExecutableIdentity.sha256;executable_identity=$ExecutableIdentity
        cache_handle_revalidated=[bool]$false;run_context_sha256=[string]$RunContext.context_sha256;process_started=[bool]$ProcessStarted;start_observed=[bool]$ProcessStarted;process_id_observed=[bool]$ProcessStarted;process_start_time_observed=[bool]$ProcessStarted;process_name_observed=[bool]$ProcessStarted;root_handle_cleanup_succeeded=[bool](-not$ProcessStarted);identity_ambiguity=[bool]$false;identity_capture_complete=[bool]$ProcessStarted;observed_start=$observedStart;process_start_provenance=if($ProcessStarted){[string]'closed_fixture'}else{[string]''}
        native_exit_source=[string]'';native_exit_code=[int]$RunContext.native_exit_sentinel;native_exit_observed=[bool]$false;native_exit_type=[string]'';effective_exit_code=[int]125;timed_out=[bool]$false;elapsed_seconds=[double]0.0;process_id=if($ProcessStarted){[int]$ProcessIdentity.pid}else{[int]0};process_identity=if($ProcessStarted){$ProcessIdentity}else{$null}
        job_assignment_succeeded=[bool]$false;job_accounting_succeeded=[bool]$false;job_cleanup_succeeded=[bool]$false;job_pretermination_active_process_count=[int]-1;job_pretermination_membership_count=[int]-1;job_final_active_process_count=[int]-1;job_final_membership_empty=[bool]$false
        baseline_godot_identities=[object[]]@();prelaunch_absence=$null;retained_descendant_identities=[object[]]@();unowned_godot_identities=[object[]]@();owned_residual_process_ids=[object[]]@();setup_exception_cleanup=$null;postcheck=[ordered]@{clean=[bool]$true;error=[string]'';godot_identities=[object[]]@();unowned_godot_identities=[object[]]@();other_lease_count=[int]0;residual_process_ids=[object[]]@()};launcher_error=[string]'';diagnostics=[object[]]@();diagnostics_clean=[bool]$true;environment_overrides=[ordered]@{};artifacts=[object[]]@()
        launched_image_path=[string]'';executable_pin_receipt=$null;executable_pin_release=$null;executable_pin_clean=[bool]$false;stdout_identity=$null;stderr_identity=$null;closed_artifact_manifests=[object[]]@()
    }
    if(-not(Test-Q009PhaseReceiptShape $phase $RunContext)){throw 'Closed phase fixture construction failed its exact public schema'}
    return $phase
}

function New-Q009ClosedSetupFailurePhaseFixture {
    param([string]$Name,[object]$StartProof,[object]$SetupCleanup,[object]$RunContext,[object]$ExecutableIdentity)
    if(-not(Test-Q009StartProofShape $StartProof)-or-not[bool]$StartProof.started-or-not(Test-Q009SetupCleanupReceiptShape $SetupCleanup)-or-not(Test-Q009RunContextShape $RunContext)-or-not(Test-Q009ExecutableIdentityEvidenceShape $ExecutableIdentity)){throw 'Setup-failure phase fixture requires exact closed input receipts'}
    $phase=[ordered]@{
        name=[string]$Name;process_kind=[string]$StartProof.process_kind;command=[string]$ExecutableIdentity.path;arguments=[object[]]@();expected_executable_path=[string]$ExecutableIdentity.path;expected_executable_sha256=[string]$ExecutableIdentity.sha256;executable_identity=$ExecutableIdentity
        cache_handle_revalidated=[bool]$false;run_context_sha256=[string]$RunContext.context_sha256;process_started=[bool]$true;start_observed=[bool]$StartProof.start_observed;process_id_observed=[bool]$StartProof.process_id_observed;process_start_time_observed=[bool]$StartProof.process_start_time_observed;process_name_observed=[bool]$StartProof.process_name_observed;root_handle_cleanup_succeeded=[bool]$StartProof.root_handle_cleanup_succeeded;identity_ambiguity=[bool]$StartProof.identity_ambiguity;identity_capture_complete=[bool]$StartProof.identity_capture_complete;observed_start=$StartProof.observed_start;process_start_provenance=[string]$StartProof.provenance
        native_exit_source=[string]'';native_exit_code=[int]$RunContext.native_exit_sentinel;native_exit_observed=[bool]$false;native_exit_type=[string]'';effective_exit_code=[int]125;timed_out=[bool]$false;elapsed_seconds=[double]0.0;process_id=[int]$StartProof.process_id;process_identity=$StartProof.process_identity
        job_assignment_succeeded=[bool]$StartProof.job_assignment_succeeded;job_accounting_succeeded=[bool]$StartProof.job_accounting_succeeded;job_cleanup_succeeded=[bool]$StartProof.job_cleanup_succeeded;job_pretermination_active_process_count=[int]$StartProof.job_pretermination_active_process_count;job_pretermination_membership_count=[int]$StartProof.job_pretermination_membership_count;job_final_active_process_count=[int]$StartProof.job_final_active_process_count;job_final_membership_empty=[bool]$StartProof.job_final_membership_empty
        baseline_godot_identities=[object[]]@();prelaunch_absence=$null;retained_descendant_identities=[object[]]@($StartProof.retained_descendant_identities);unowned_godot_identities=[object[]]@($StartProof.unowned_godot_identities);owned_residual_process_ids=[object[]]@($SetupCleanup.residual_identities|ForEach-Object{[int]$_.pid});setup_exception_cleanup=$SetupCleanup;postcheck=[ordered]@{clean=[bool]$false;error=[string]'forced setup failure';godot_identities=[object[]]@();unowned_godot_identities=[object[]]@($StartProof.unowned_godot_identities);other_lease_count=[int]-1;residual_process_ids=[object[]]@($SetupCleanup.residual_identities|ForEach-Object{[int]$_.pid})};launcher_error=[string]'forced setup failure';diagnostics=[object[]]@();diagnostics_clean=[bool]$false;environment_overrides=[ordered]@{};artifacts=[object[]]@()
        launched_image_path=[string]$StartProof.launched_image_path;executable_pin_receipt=$StartProof.executable_pin_receipt;executable_pin_release=$StartProof.executable_pin_release;executable_pin_clean=[bool]($null-ne$StartProof.executable_pin_release-and[bool]$StartProof.executable_pin_release.released-and[bool]$StartProof.executable_pin_release.all_terminal);stdout_identity=$null;stderr_identity=$null;closed_artifact_manifests=[object[]]@()
    }
    if(-not(Test-Q009PhaseReceiptShape $phase $RunContext)){throw 'Setup-failure phase fixture construction failed its exact public schema'}
    return $phase
}

function Get-ProductPhaseBindingIssues {
    param([object]$Phase,[object]$Report)
    $issues=[System.Collections.Generic.List[string]]::new()
    if(-not($Report.failures -is [System.Array]) -or -not($Report.warnings -is [System.Array])){Add-Issue $issues 'failure/warning collections were not JSON arrays';return @($issues)}
    $failures=@($Report.failures);$warnings=@($Report.warnings)
    foreach($nativeIssue in @(Get-NativeDiagnosticSchemaIssues $Report.native_diagnostics)){Add-Issue $issues $nativeIssue}
    if(-not(Test-JsonObject $Report.native_diagnostics)){return @($issues)}
    $nativeFailureTotal=[long]$Report.native_diagnostics.failure_count;$nativeWarningTotal=[long]$Report.native_diagnostics.warning_count
    $expectedNativeClean=($nativeFailureTotal-eq0-and$nativeWarningTotal-eq0)
    if(-not(Test-ExactBoolean $Report.native_diagnostics_clean $expectedNativeClean)){Add-Issue $issues 'top-level native diagnostics clean flag contradicted exact native counters'}
    $expectedWarningsClean=($warnings.Count-eq0-and$nativeWarningTotal-eq0)
    if(-not(Test-ExactBoolean $Report.warnings_clean $expectedWarningsClean) -or -not(Test-ExactInteger $Report.tool_warning_count $warnings.Count) -or -not(Test-ExactInteger $Report.warning_count ($warnings.Count+$nativeWarningTotal))){Add-Issue $issues 'warning totals/clean predicate did not recompute exactly'}
    if(-not(Test-ExactInteger $Report.tool_failure_count $failures.Count) -or -not(Test-ExactInteger $Report.failure_count ($failures.Count+$nativeFailureTotal))){Add-Issue $issues 'product failure totals did not bind exactly to public failures plus native receipt failures'}
    if(-not$expectedWarningsClean){Add-Issue $issues 'audit warning is not a valid product red'}
    $nativeExit=[int]$Phase.native_exit_code
    $evidenceSatisfied=(Test-ExactBoolean $Report.requested_visits_satisfied $true)-and(Test-ExactBoolean $Report.crew_state_unchanged $true)-and(Test-ExactBoolean $Report.attempt_id_valid $true)-and(Test-ExactInteger $Report.visits_per_run_target 6)-and(Test-ExactInteger $Report.travels_per_run_target 5)-and$expectedNativeClean
    $qualifyingPassed=$failures.Count-eq0-and$warnings.Count-eq0-and$evidenceSatisfied
    if(-not(Test-ExactBoolean $Report.passed $qualifyingPassed)){Add-Issue $issues 'report passed did not equal the independently recomputed qualifying predicate'}
    $expectedNativeExit=if($qualifyingPassed){0}else{1}
    if($nativeExit-ne$expectedNativeExit){Add-Issue $issues 'native exit did not equal the independently recomputed qualifying predicate'}
    $expectedDiagnostics=[System.Collections.Generic.List[string]]::new()
    foreach($failure in $failures){[void]$expectedDiagnostics.Add(('ERROR: '+[string]$failure).Trim())}
    if(-not $evidenceSatisfied){[void]$expectedDiagnostics.Add('ERROR: Environment generation audit did not satisfy its requested visit/travel or Crew no-op evidence contract.')}
    $actualDiagnostics=@($Phase.diagnostics|ForEach-Object{([string]$_).Trim()}|Sort-Object -Unique)
    $expectedUnique=@($expectedDiagnostics|Sort-Object -Unique)
    if(($actualDiagnostics -join "`n") -cne ($expectedUnique -join "`n")){Add-Issue $issues 'process diagnostics were not the exact report-bound product-error set'}
    if($nativeExit-eq1-and$expectedUnique.Count-eq0){Add-Issue $issues 'native product-red exit had no report-bound product failure'}
    if($nativeExit-eq0-and(-not$qualifyingPassed-or$failures.Count-ne0-or$nativeFailureTotal-ne0-or-not$evidenceSatisfied)){Add-Issue $issues 'exit-zero phase contained failure/native/evidence contradictions'}
    return @($issues)
}

function New-ProfileEnvironment {
    param([string]$ProfileRoot,[string]$OwnedRoot,[object]$RunContext)
    if(-not(Test-Q009RunContextShape $RunContext)){throw 'Profile creation requires one exact sealed run context'}
    Assert-NoReparsePathChain $OwnedRoot $ProfileRoot
    if(Test-Path -LiteralPath $ProfileRoot){throw 'Profile root already exists before exact atomic creation'}
    $profileIdentity=New-Q009ExactOwnedDirectory $ProfileRoot
    $paths=[ordered]@{APPDATA=(Join-Path $ProfileRoot 'AppData\Roaming');LOCALAPPDATA=(Join-Path $ProfileRoot 'AppData\Local');XDG_DATA_HOME=(Join-Path $ProfileRoot 'xdg\data');XDG_CACHE_HOME=(Join-Path $ProfileRoot 'xdg\cache');XDG_CONFIG_HOME=(Join-Path $ProfileRoot 'xdg\config')}
    foreach($path in $paths.Values){Assert-NoReparsePathChain $OwnedRoot $path;[void][IO.Directory]::CreateDirectory($path);Assert-NoReparsePathChain $OwnedRoot $path}
    $owner=[ordered]@{run_context_sha256=[string]$RunContext.context_sha256;profile_root_identity=$profileIdentity;environment_keys=[object[]]@($paths.Keys)}
    $chain=New-Q009OwnedChildManifestChainHead -RootPath $ProfileRoot -RootIdentity $profileIdentity -AttemptId ([string]$RunContext.attempt_id) -Boundary 'profile_initialized_before_process' -OwnerKind profile_creator -OwnerReceipt $owner
    return [ordered]@{environment=$paths;root_path=[IO.Path]::GetFullPath($ProfileRoot).TrimEnd('\','/');root_identity=$profileIdentity;initial_manifest_chain=$chain}
}

function Write-ImportedManifest {
    param([string]$Destination,[object]$RunContext)
    if(-not(Test-Q009RunContextShape $RunContext)){throw 'Imported-manifest capture requires one exact sealed run context'}
    $cacheRoot=[string]$RunContext.project_cache_root
    $imported=Join-Path $cacheRoot 'imported';if(-not(Test-Path -LiteralPath $imported -PathType Container)){throw 'Godot import produced no imported directory'}
    $files=[System.Collections.Generic.List[object]]::new();foreach($file in Get-ChildItem -LiteralPath $imported -File -Recurse -Force|Sort-Object FullName){[void]$files.Add([ordered]@{path=$file.FullName.Substring($cacheRoot.Length).TrimStart('\','/').Replace('\','/');length=[long]$file.Length;sha256=(Get-FileHash $file.FullName -Algorithm SHA256).Hash})}
    if($files.Count -eq 0){throw 'Godot imported-artifact manifest is empty'}
    if(Test-Path -LiteralPath $Destination){throw 'Imported manifest destination already exists'}
    $parentIdentity=Get-Q009FileSystemEntryIdentity ([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($Destination)))
    $temp=$Destination+'.tmp-'+[guid]::NewGuid().ToString('N');$ownership=[ordered]@{created=$false;identity=$null;write_complete=$false;removal_failed=$false;removal_error=''}
    try{
        New-OwnedLeaseFile $temp (([ordered]@{schema_version=1;files=@($files);count=$files.Count}|ConvertTo-Json -Depth 6)+"`n") $ownership
        Publish-Q009OwnedEvidenceArtifact -SourcePath $temp -DestinationPath $Destination -SourceIdentity $ownership.identity -ExpectedParentIdentity $parentIdentity
        $publishedIdentity=Copy-Q009FileSystemIdentityToPath $ownership.identity $Destination
        if(-not(Test-Q009FileSystemIdentityMatch $publishedIdentity)){throw 'Imported manifest identity changed during no-replace publication'}
    }catch{
        if([bool]$ownership.created-and(Test-Q009FileSystemIdentityMatch $ownership.identity)){Remove-Q009ExactOwnedFile $temp $ownership.identity}
        throw
    }
    return [ordered]@{count=$files.Count;path=$Destination;sha256=(Get-FileHash $Destination -Algorithm SHA256).Hash}
}

function Write-AtomicJson {
    param([string]$Path,[object]$Value)
    if(Test-Path -LiteralPath $Path){throw "Refusing to overwrite evidence: $Path"}
    $parentIdentity=Get-Q009FileSystemEntryIdentity ([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($Path)))
    $temp=$Path+'.tmp-'+[guid]::NewGuid().ToString('N');$ownership=[ordered]@{created=$false;identity=$null;write_complete=$false;removal_failed=$false;removal_error=''}
    try{
        New-OwnedLeaseFile $temp (($Value|ConvertTo-Json -Depth 20)+"`n") $ownership
        Publish-Q009OwnedEvidenceArtifact -SourcePath $temp -DestinationPath $Path -SourceIdentity $ownership.identity -ExpectedParentIdentity $parentIdentity
        $publishedIdentity=Copy-Q009FileSystemIdentityToPath $ownership.identity $Path
        if(-not(Test-Q009FileSystemIdentityMatch $publishedIdentity)){throw 'Atomic JSON identity changed during no-replace publication'}
    }catch{
        if([bool]$ownership.created-and(Test-Q009FileSystemIdentityMatch $ownership.identity)){Remove-Q009ExactOwnedFile $temp $ownership.identity}
        throw
    }
    $artifact=Get-FileArtifact $Path
    if(-not[bool]$artifact.present-or-not(Test-ExactSha256 $artifact.sha256)){throw 'Atomic JSON publication did not survive exact byte readback'}
    return [ordered]@{path=[IO.Path]::GetFullPath($Path);identity=$publishedIdentity;length=[long]$artifact.length;sha256=[string]$artifact.sha256}
}

function Test-Q009ReleaseEvidenceShape {
    param(
        [AllowNull()][object]$Receipt,
        [AllowNull()][object]$RunContext,
        [AllowNull()][object]$HeldExclusiveReceipt,
        [System.Collections.IDictionary]$Pinned=[ordered]@{},
        [AllowNull()][object]$DependencyPinReceipts=[ordered]@{}
    )
    $keys=@('proved','observed_utc','count','identity_records','other_lease_count','under_mutex','strict_zero_required','process_custody','profile_absence','cache_absence','dependency_pin_releases','exclusive_release','run_context_sha256')
    if(-not(Test-Q009ExactPublicReceiptKeys $Receipt $keys)-or-not(Test-Q009RunContextShape $RunContext)-or
        $Receipt.proved-isnot[bool]-or-not[bool]$Receipt.proved-or-not(Test-Q009ExactRoundtripTimestamp $Receipt.observed_utc)-or
        $Receipt.count-isnot[int]-or[int]$Receipt.count-ne0-or$Receipt.identity_records-isnot[System.Array]-or@($Receipt.identity_records).Count-ne0-or
        $Receipt.other_lease_count-isnot[int]-or[int]$Receipt.other_lease_count-ne0-or$Receipt.under_mutex-isnot[bool]-or-not[bool]$Receipt.under_mutex-or
        $Receipt.strict_zero_required-isnot[bool]-or-not[bool]$Receipt.strict_zero_required-or
        -not(Test-FinalOwnedProcessResidualEvidenceShape $Receipt.process_custody $RunContext)-or-not[bool]$Receipt.process_custody.clean-or
        -not(Test-Q009StrictAbsenceReceipt $Receipt.profile_absence)-or-not(Test-Q009StrictAbsenceReceipt $Receipt.cache_absence)-or
        -not(Test-Q009TrackedDependencyPinReleasesShape $Receipt.dependency_pin_releases $DependencyPinReceipts $Pinned $RunContext)-or
        -not(Test-Q009HeldExclusiveReleaseReceiptShape $Receipt.exclusive_release $HeldExclusiveReceipt $RunContext)-or
        $Receipt.run_context_sha256-isnot[string]-or[string]$Receipt.run_context_sha256-cne[string]$RunContext.context_sha256){return $false}
    return $true
}

function Test-Q009PrePublicationCustodyShape {
    param(
        [AllowNull()][object]$Receipt,
        [AllowNull()][object]$RunContext,
        [AllowNull()][object]$HeldExclusiveReceipt,
        [System.Collections.IDictionary]$Pinned=[ordered]@{},
        [AllowNull()][object]$ExpectedDependencyPinReceipts=[ordered]@{}
    )
    $keys=@('proved','observed_utc','count','identity_records','other_lease_count','under_mutex','strict_zero_required','process_custody','profile_absence','cache_absence','dependency_pins_held','dependency_pin_receipts','exclusive_held','exclusive_receipt_sha256','run_context_sha256')
    if(-not(Test-Q009ExactPublicReceiptKeys $Receipt $keys)-or-not(Test-Q009RunContextShape $RunContext)-or
        $Receipt.proved-isnot[bool]-or-not[bool]$Receipt.proved-or-not(Test-Q009ExactRoundtripTimestamp $Receipt.observed_utc)-or
        $Receipt.count-isnot[int]-or[int]$Receipt.count-ne0-or$Receipt.identity_records-isnot[System.Array]-or@($Receipt.identity_records).Count-ne0-or
        $Receipt.other_lease_count-isnot[int]-or[int]$Receipt.other_lease_count-ne0-or$Receipt.under_mutex-isnot[bool]-or-not[bool]$Receipt.under_mutex-or
        $Receipt.strict_zero_required-isnot[bool]-or-not[bool]$Receipt.strict_zero_required-or
        -not(Test-FinalOwnedProcessResidualEvidenceShape $Receipt.process_custody $RunContext)-or-not[bool]$Receipt.process_custody.clean-or
        -not(Test-Q009StrictAbsenceReceipt $Receipt.profile_absence)-or-not(Test-Q009StrictAbsenceReceipt $Receipt.cache_absence)-or
        $Receipt.dependency_pins_held-isnot[bool]-or-not[bool]$Receipt.dependency_pins_held-or
        -not(Test-Q009TrackedDependencyPinReceiptsShape $Receipt.dependency_pin_receipts $Pinned $RunContext)-or
        (($Receipt.dependency_pin_receipts|ConvertTo-Json -Depth 20 -Compress)-cne($ExpectedDependencyPinReceipts|ConvertTo-Json -Depth 20 -Compress))-or
        $Receipt.exclusive_held-isnot[bool]-or-not[bool]$Receipt.exclusive_held-or
        $Receipt.exclusive_receipt_sha256-isnot[string]-or-not(Test-ExactSha256 $Receipt.exclusive_receipt_sha256)-or
        $null-eq$HeldExclusiveReceipt-or[string]$Receipt.exclusive_receipt_sha256-cne[string]$HeldExclusiveReceipt.receipt_sha256-or
        $Receipt.run_context_sha256-isnot[string]-or[string]$Receipt.run_context_sha256-cne[string]$RunContext.context_sha256){return $false}
    return $true
}

function Test-Q009EvidenceTerminalOwnerReceiptShape {
    param(
        [AllowNull()][object]$Receipt,
        [AllowNull()][object]$RunContext,
        [AllowNull()][object]$EvidenceRootOwnership,
        [AllowNull()][object]$HeldExclusiveReceipt,
        [System.Collections.IDictionary]$Pinned=[ordered]@{},
        [AllowNull()][object]$DependencyPinReceipts=[ordered]@{}
    )
    $keys=@('schema_version','attempt_id','qualifying_safe','outcome','exit_code','run_context_sha256','candidate_commit','candidate_tree','final_process_evidence','pre_cleanup_quiescence','pre_publication_custody','exclusive_held_receipt_sha256','profile_manifest_chain','cache_manifest_chain','evidence_root_identity','owner_claim_identity','owner_claim_sha256','cleanup_succeeded','provenance_valid')
    if(-not(Test-Q009ExactPublicReceiptKeys $Receipt $keys)-or$Receipt.schema_version-isnot[int]-or[int]$Receipt.schema_version-ne1-or
        $Receipt.attempt_id-isnot[string]-or[string]::IsNullOrWhiteSpace([string]$Receipt.attempt_id)-or$Receipt.qualifying_safe-isnot[bool]-or
        $Receipt.outcome-isnot[string]-or[string]$Receipt.outcome-notin@('pass','product_red','invalid')-or$Receipt.exit_code-isnot[int]-or
        $Receipt.run_context_sha256-isnot[string]-or$Receipt.candidate_commit-isnot[string]-or$Receipt.candidate_tree-isnot[string]-or
        -not(Test-Q009FileSystemIdentityShape $Receipt.evidence_root_identity)-or-not[bool]$Receipt.evidence_root_identity.is_directory-or
        -not(Test-Q009FileSystemIdentityShape $Receipt.owner_claim_identity)-or[bool]$Receipt.owner_claim_identity.is_directory-or
        $Receipt.owner_claim_sha256-isnot[string]-or-not(Test-ExactSha256 $Receipt.owner_claim_sha256)-or
        $Receipt.cleanup_succeeded-isnot[bool]-or$Receipt.provenance_valid-isnot[bool]-or
        $Receipt.exclusive_held_receipt_sha256-isnot[string]){return $false}
    if($null-eq$EvidenceRootOwnership-or[string]$Receipt.evidence_root_identity.key-cne[string]$EvidenceRootOwnership.root_identity.key-or[string]$Receipt.owner_claim_identity.key-cne[string]$EvidenceRootOwnership.claim_identity.key-or[string]$Receipt.owner_claim_sha256-cne[string]$EvidenceRootOwnership.claim_sha256){return $false}
    if (([string]$Receipt.outcome -ceq 'pass') -ne ([int]$Receipt.exit_code -eq 0)) { return $false }
    if(-not[bool]$Receipt.qualifying_safe){return $true}
    if(-not(Test-Q009RunContextShape $RunContext)-or[string]$Receipt.attempt_id-cne[string]$RunContext.attempt_id-or[string]$Receipt.run_context_sha256-cne[string]$RunContext.context_sha256-or
        [string]$Receipt.candidate_commit-cne[string]$RunContext.candidate_commit-or[string]$Receipt.candidate_tree-cne[string]$RunContext.candidate_tree-or
        -not[bool]$Receipt.cleanup_succeeded-or-not[bool]$Receipt.provenance_valid-or
        -not(Test-FinalOwnedProcessResidualEvidenceShape $Receipt.final_process_evidence $RunContext)-or-not[bool]$Receipt.final_process_evidence.clean-or
        -not(Test-GlobalQuiescenceEvidenceShape $Receipt.pre_cleanup_quiescence)-or
        -not(Test-Q009PrePublicationCustodyShape $Receipt.pre_publication_custody $RunContext $HeldExclusiveReceipt $Pinned $DependencyPinReceipts)-or
        -not(Test-ExactSha256 $Receipt.exclusive_held_receipt_sha256)-or[string]$Receipt.exclusive_held_receipt_sha256-cne[string]$HeldExclusiveReceipt.receipt_sha256-or
        -not(Test-Q009OwnedChildManifestChainHeadShape $Receipt.profile_manifest_chain $Receipt.profile_manifest_chain.root_identity $Receipt.attempt_id 'profile_terminal_after_process_quiescence')-or
        -not(Test-Q009OwnedChildManifestChainHeadShape $Receipt.cache_manifest_chain $Receipt.cache_manifest_chain.root_identity $Receipt.attempt_id 'cache_terminal_after_process_quiescence')){return $false}
    return $true
}

function Test-Q009TerminalCompletionReceiptShape {
    param(
        [AllowNull()][object]$Receipt,
        [AllowNull()][object]$RunContext,
        [AllowNull()][object]$HeldExclusiveReceipt,
        [AllowNull()][object]$SummaryPublication,
        [System.Collections.IDictionary]$Pinned=[ordered]@{},
        [AllowNull()][object]$DependencyPinReceipts=[ordered]@{}
    )
    $keys=@('schema_version','attempt_id','qualifying_pass','outcome','exit_code','run_context_sha256','summary_publication','summary_published_under_exclusive','terminal_release','completed_utc')
    $expectedQualifyingPass = $false
    if ($null -ne $Receipt -and $Receipt.outcome -is [string] -and $Receipt.exit_code -is [int]) {
        $expectedQualifyingPass = ([string]$Receipt.outcome -ceq 'pass') -and ([int]$Receipt.exit_code -eq 0)
    }
    if(-not(Test-Q009ExactPublicReceiptKeys $Receipt $keys)-or-not(Test-Q009RunContextShape $RunContext)-or
        $Receipt.schema_version-isnot[int]-or[int]$Receipt.schema_version-ne1-or
        $Receipt.attempt_id-isnot[string]-or[string]$Receipt.attempt_id-cne[string]$RunContext.attempt_id-or
        $Receipt.qualifying_pass-isnot[bool]-or$Receipt.outcome-isnot[string]-or[string]$Receipt.outcome-notin@('pass','product_red','invalid')-or
        $Receipt.exit_code-isnot[int]-or(([string]$Receipt.outcome-ceq'pass')-ne([int]$Receipt.exit_code-eq0))-or
        ([bool]$Receipt.qualifying_pass-ne$expectedQualifyingPass)-or
        $Receipt.run_context_sha256-isnot[string]-or[string]$Receipt.run_context_sha256-cne[string]$RunContext.context_sha256-or
        -not(Test-Q009SummaryPublicationReceiptShape $Receipt.summary_publication)-or
        -not(Test-Q009SummaryPublicationReceiptShape $SummaryPublication)-or
        (($Receipt.summary_publication|ConvertTo-Json -Depth 12 -Compress)-cne($SummaryPublication|ConvertTo-Json -Depth 12 -Compress))-or
        $Receipt.summary_published_under_exclusive-isnot[bool]-or-not[bool]$Receipt.summary_published_under_exclusive-or
        -not(Test-Q009ReleaseEvidenceShape $Receipt.terminal_release $RunContext $HeldExclusiveReceipt $Pinned $DependencyPinReceipts)-or
        -not(Test-Q009ExactRoundtripTimestamp $Receipt.completed_utc)){return $false}
    return $true
}

function Test-Q009SummaryPublicationReceiptShape {
    param([AllowNull()][object]$Receipt)
    if(-not(Test-Q009ExactPublicReceiptKeys $Receipt @('published','sha256','precommit_manifest_head_sha256','json','sidecar'))-or$Receipt.published-isnot[bool]-or-not[bool]$Receipt.published-or-not(Test-ExactSha256 $Receipt.sha256)-or-not(Test-ExactSha256 $Receipt.precommit_manifest_head_sha256)){return $false}
    foreach($name in @('json','sidecar')){
        $artifact=$Receipt.$name
        if(-not(Test-Q009ExactPublicReceiptKeys $artifact @('path','identity','present','length','sha256'))-or$artifact.path-isnot[string]-or[string]::IsNullOrWhiteSpace([string]$artifact.path)-or-not(Test-Q009FileSystemIdentityShape $artifact.identity)-or[bool]$artifact.identity.is_directory-or[string]$artifact.identity.path-cne[IO.Path]::GetFullPath([string]$artifact.path)-or$artifact.present-isnot[bool]-or-not[bool]$artifact.present-or$artifact.length-isnot[long]-or[long]$artifact.length-le0-or-not(Test-ExactSha256 $artifact.sha256)){return $false}
    }
    return [string]$Receipt.json.sha256-ceq[string]$Receipt.sha256
}

function Test-Q009TerminalTreeDelta {
    param(
        [AllowNull()][object]$BeforeManifest,
        [AllowNull()][object]$AfterManifest,
        [AllowNull()][object]$TerminalPublication
    )
    if(-not(Test-Q009ExactOwnedTreeManifestShape $BeforeManifest)-or-not(Test-Q009ExactOwnedTreeManifestShape $AfterManifest)-or-not(Test-Q009SummaryPublicationReceiptShape $TerminalPublication)){return $false}
    if([string]$BeforeManifest.root_identity.key-cne[string]$AfterManifest.root_identity.key){return $false}
    $before=@{};foreach($entry in @($BeforeManifest.entries)){$before[[string]$entry.path]=$entry}
    $after=@{};foreach($entry in @($AfterManifest.entries)){$after[[string]$entry.path]=$entry}
    if($after.Count-ne$before.Count+2){return $false}
    foreach($path in @($before.Keys)){if(-not$after.ContainsKey($path)-or(($after[$path]|ConvertTo-Json -Compress -Depth 6)-cne($before[$path]|ConvertTo-Json -Compress -Depth 6))){return $false}}
    $terminalJson=$after['terminal.json'];$terminalSha=$after['terminal.sha256']
    if($null-eq$terminalJson-or$null-eq$terminalSha-or[bool]$terminalJson.is_directory-or[bool]$terminalSha.is_directory){return $false}
    return [string]$terminalJson.native_key-ceq[string]$TerminalPublication.json.identity.native_key-and
        [long]$terminalJson.creation_ticks-eq[long]$TerminalPublication.json.identity.creation_ticks-and
        [long]$terminalJson.length-eq[long]$TerminalPublication.json.length-and[string]$terminalJson.sha256-ceq[string]$TerminalPublication.json.sha256-and
        [string]$terminalSha.native_key-ceq[string]$TerminalPublication.sidecar.identity.native_key-and
        [long]$terminalSha.creation_ticks-eq[long]$TerminalPublication.sidecar.identity.creation_ticks-and
        [long]$terminalSha.length-eq[long]$TerminalPublication.sidecar.length-and[string]$terminalSha.sha256-ceq[string]$TerminalPublication.sidecar.sha256
}

function Publish-SummaryPairNoOverwrite {
    param(
        [string]$OwnedRoot,
        [string]$JsonPath,
        [string]$ShaPath,
        [object]$Value,
        [object]$AuthorizedChainHead,
        [string]$ExpectedAttemptId,
        [string]$ArtifactName='summary.json',
        [switch]$ForceSidecarStageFailureForTest,
        [switch]$ForceSidecarMoveCollisionForTest,
        [switch]$ForceJsonPublishFailureForTest
    )
    if([IO.Path]::GetFileName([IO.Path]::GetFullPath($JsonPath))-cne$ArtifactName-or[IO.Path]::GetFileName([IO.Path]::GetFullPath($ShaPath))-cne([IO.Path]::GetFileNameWithoutExtension($ArtifactName)+'.sha256')){throw 'Atomic JSON pair destination names do not match their exact artifact contract'}
    Assert-NoReparsePathChain $OwnedRoot $JsonPath
    Assert-NoReparsePathChain $OwnedRoot $ShaPath
    if((Test-Path -LiteralPath $JsonPath)-or(Test-Path -LiteralPath $ShaPath)){throw 'Refusing to overwrite an existing summary pair'}
    $stageToken=[guid]::NewGuid().ToString('N')
    $stageStem='.'+[IO.Path]::GetFileNameWithoutExtension($ArtifactName)+'-stage-'+$stageToken
    $stageJson=Join-Path $OwnedRoot ($stageStem+'.json')
    $stageSha=Join-Path $OwnedRoot ($stageStem+'.sha256')
    $ownedRootIdentity=Get-Q009FileSystemEntryIdentity $OwnedRoot
    if(-not(Test-Q009OwnedChildManifestChainHeadShape $AuthorizedChainHead $ownedRootIdentity $ExpectedAttemptId)){throw 'Summary publication requires the exact terminal evidence-root manifest chain'}
    $authorizedManifest=Get-Q009ExactOwnedTreeManifest $OwnedRoot
    if([string]$authorizedManifest.sha256-cne[string]$AuthorizedChainHead.manifest.sha256-or(($authorizedManifest|ConvertTo-Json -Depth 8 -Compress)-cne($AuthorizedChainHead.manifest|ConvertTo-Json -Depth 8 -Compress))){throw 'Evidence root changed after its terminal manifest and before summary staging'}
    $committed=$false;$jsonOwnership=[ordered]@{created=$false;identity=$null;write_complete=$false;removal_failed=$false;removal_error=''};$shaOwnership=[ordered]@{created=$false;identity=$null;write_complete=$false;removal_failed=$false;removal_error=''}
    try{
        Assert-NoReparsePathChain $OwnedRoot $stageJson;Assert-NoReparsePathChain $OwnedRoot $stageSha
        New-OwnedLeaseFile $stageJson (($Value|ConvertTo-Json -Depth 30)+"`n") $jsonOwnership
        $hash=(Get-FileHash -LiteralPath $stageJson -Algorithm SHA256).Hash.ToUpperInvariant()
        $jsonLength=[long](Get-Item -LiteralPath $stageJson).Length
        if($ForceSidecarStageFailureForTest){throw 'Forced sidecar staging failure'}
        New-OwnedLeaseFile $stageSha ($hash+'  '+$ArtifactName+"`n") $shaOwnership
        if((Get-FileHash -LiteralPath $stageJson -Algorithm SHA256).Hash.ToUpperInvariant()-cne$hash){throw 'Staged summary bytes changed before publication'}
        if([IO.File]::ReadAllText($stageSha,[Text.UTF8Encoding]::new($false))-cne($hash+'  '+$ArtifactName+"`n")){throw 'Staged JSON sidecar changed before publication'}
        $shaLength=[long](Get-Item -LiteralPath $stageSha).Length
        $shaContentHash=(Get-FileHash -LiteralPath $stageSha -Algorithm SHA256).Hash.ToUpperInvariant()
        $predictedShaIdentity=Copy-Q009FileSystemIdentityToPath $shaOwnership.identity $ShaPath
        $predictedJsonIdentity=Copy-Q009FileSystemIdentityToPath $jsonOwnership.identity $JsonPath
        $stagedOwner=[ordered]@{json_identity=$jsonOwnership.identity;json_sha256=$hash;sidecar_identity=$shaOwnership.identity;sidecar_sha256=$shaContentHash;authorized_head_sha256=[string]$AuthorizedChainHead.head_sha256}
        $stagedChain=New-Q009OwnedChildManifestChainHead -RootPath $OwnedRoot -RootIdentity $ownedRootIdentity -AttemptId $ExpectedAttemptId -Boundary 'summary_pair_staged' -OwnerKind evidence_owner -OwnerReceipt $stagedOwner -PreviousHead $AuthorizedChainHead
        # Publish the immutable hash sidecar first. Therefore a PASS JSON can
        # never be visible without its already-published matching sidecar.
        if($ForceSidecarMoveCollisionForTest){[IO.File]::WriteAllText($ShaPath,'foreign',[Text.UTF8Encoding]::new($false))}
        Publish-Q009OwnedEvidenceArtifact -SourcePath $stageSha -DestinationPath $ShaPath -SourceIdentity $shaOwnership.identity -ExpectedParentIdentity $ownedRootIdentity
        $publishedShaIdentity=Copy-Q009FileSystemIdentityToPath $shaOwnership.identity $ShaPath
        if(-not(Test-Q009FileSystemIdentityMatch $publishedShaIdentity)){throw 'Summary sidecar identity changed during no-replace publication'}
        if($ForceJsonPublishFailureForTest){throw 'Forced JSON publication failure after sidecar publication'}
        $precommitOwner=[ordered]@{json_stage_identity=$jsonOwnership.identity;json_destination_identity=$predictedJsonIdentity;json_sha256=$hash;sidecar_destination_identity=$publishedShaIdentity;sidecar_sha256=$shaContentHash;staged_head_sha256=[string]$stagedChain.head_sha256}
        $precommitChain=New-Q009OwnedChildManifestChainHead -RootPath $OwnedRoot -RootIdentity $ownedRootIdentity -AttemptId $ExpectedAttemptId -Boundary 'summary_sidecar_committed_json_staged' -OwnerKind evidence_owner -OwnerReceipt $precommitOwner -PreviousHead $stagedChain
        $publication=[ordered]@{published=$true;sha256=$hash;precommit_manifest_head_sha256=[string]$precommitChain.head_sha256;json=[ordered]@{path=$JsonPath;identity=$predictedJsonIdentity;present=$true;length=$jsonLength;sha256=$hash};sidecar=[ordered]@{path=$ShaPath;identity=$predictedShaIdentity;present=$true;length=$shaLength;sha256=$shaContentHash}}
        if(-not(Test-Q009SummaryPublicationReceiptShape $publication)){throw 'Predicted summary publication receipt failed its exact closed schema'}
        Publish-Q009OwnedEvidenceArtifact -SourcePath $stageJson -DestinationPath $JsonPath -SourceIdentity $jsonOwnership.identity -ExpectedParentIdentity $ownedRootIdentity
        $committed=$true
        # The native no-replace publication verifies the exact destination
        # identity before returning. No fallible operation follows this commit.
        return $publication
    }finally{
        if(-not$committed){
            foreach($stage in @([pscustomobject]@{path=$stageJson;ownership=$jsonOwnership},[pscustomobject]@{path=$stageSha;ownership=$shaOwnership})){$stagePath=[string]$stage.path;$stageOwnership=$stage.ownership;if(Test-Path -LiteralPath $stagePath){Assert-NoReparsePathChain $OwnedRoot $stagePath;if([bool]$stageOwnership.created-and(Test-Q009FileSystemIdentityMatch $stageOwnership.identity)){Remove-Q009ExactOwnedFile $stagePath $stageOwnership.identity}}}
        }
    }
}

function Add-SelfTestResult {
    param([System.Collections.Generic.List[object]]$Cases,[string]$Name,[scriptblock]$Body)
    try{&$Body;[void]$Cases.Add([ordered]@{name=$Name;passed=$true;detail=''})}catch{[void]$Cases.Add([ordered]@{name=$Name;passed=$false;detail=$_.Exception.Message})}
}

function New-CrossBindingSelfTestFixture {
    $attempt='attempt-selftest';$seed='seed-selftest'
    $newChoice={param([string]$Id,[bool]$Enabled=$true)[pscustomobject][ordered]@{id=$Id;label=$Id;kind='casino';tier=1;enabled=$Enabled;hidden=$false;disabled_reason=if($Enabled){''}else{'Locked'};cost=0;risk='';distance='near';risk_decay=0;suspicion_delta=0;risk_text='';risk_event=[pscustomobject][ordered]@{};unlock_conditions=[object[]]@();travel_lock_remaining=0;availability_turn=-1}}
    $run=[pscustomobject][ordered]@{run_index=0;attempt_id=$attempt;seed=$seed;requested_seed_text=$seed;seed_text=$seed;seed_value=7;challenge_key='standard|seed-selftest';challenge_id='standard';challenge_mode='standard';derived_seed_value=7;expected_challenge_key='standard|seed-selftest';expected_seed_value=7;seed_binding_valid=$true;attempt_id_required=$true;final_seed_binding=$null;final_seed_binding_valid=$true;final_seed_binding_satisfied=$true;attempt_binding_satisfied=$true;post_event_seed_binding_count=6;visited=[object[]]@();initial_arrival_receipt=$null}
    $tuple={param([switch]$Required)[pscustomobject][ordered]@{attempt_id=$attempt;attempt_id_required=if($Required){$true}else{$false};requested_seed_text=$seed;seed_text=$seed;seed_value=7;challenge_key='standard|seed-selftest';challenge_id='standard';challenge_mode='standard';challenge_seed_text=$seed;challenge_daily_id='';challenge_hidden_seed=$false;challenge_modifier_count=0;derived_seed_value=7;expected_challenge_key='standard|seed-selftest';expected_seed_value=7;seed_binding_valid=$true}}
    $run.final_seed_binding=&$tuple -Required
    $records=[System.Collections.Generic.List[object]]::new();$visited=[System.Collections.Generic.List[object]]::new()
    for($index=0;$index-lt6;$index+=1){
        $semanticDigest=('s'+$index.ToString().PadLeft(63,'0'));$authorityDigest=('a'+$index.ToString().PadLeft(63,'0'))
        $layout=[pscustomobject][ordered]@{scenario_id="scenario-$index";status='active';semantic_ready=$true;live_semantic_ready=$true;semantic_digest=$semanticDigest;authority_digest=$authorityDigest;authority_count=0;authority_identities=[object[]]@();authority_receipts=[object[]]@();action_authority_member_count=0;actionable_authority_count=0;invalid_action_authority_count=0;action_authority_contract_valid=$true}
        $finalization=[pscustomobject][ordered]@{ok=$true;inactive=$false;contract_shape_valid=$true;projection_binding_valid=$true;semantic_digest=$semanticDigest;layout_authority_digest=$authorityDigest;layout_authority_count=0;warning_count=0;error_count=0;warnings=[object[]]@();errors=[object[]]@()}
        $arrival=&$tuple -Required;$arrival|Add-Member -NotePropertyName kind -NotePropertyValue $(if($index-eq0){'initial'}else{'travel'});$arrival|Add-Member -NotePropertyName production_path -NotePropertyValue $(if($index-eq0){'generate_and_finalize'}else{'travel_and_finalize'});$arrival|Add-Member -NotePropertyName stage -NotePropertyValue 'complete';$arrival|Add-Member -NotePropertyName visit_index -NotePropertyValue $index;$arrival|Add-Member -NotePropertyName travel_index -NotePropertyValue ($index-1);$arrival|Add-Member -NotePropertyName from_visit_index -NotePropertyValue ($index-1)
        $arrival|Add-Member -NotePropertyName source_id -NotePropertyValue $(if($index-eq0){''}else{"node-$($index-1)"});$arrival|Add-Member -NotePropertyName travel_source_id -NotePropertyValue $(if($index-eq0){''}else{"node-$($index-1)"});$arrival|Add-Member -NotePropertyName target_id -NotePropertyValue "node-$index";$arrival|Add-Member -NotePropertyName travel_target_id -NotePropertyValue "node-$index"
        foreach($pair in @(@('installed_environment_id',"environment-$index"),@('installed_archetype_id',"archetype-$index"),@('installed_world_node_id',"node-$index"),@('installed_scenario_id',"scenario-$index"),@('travel_environment_id',"environment-$index"),@('travel_archetype_id',"archetype-$index"),@('travel_world_node_id',"node-$index"),@('travel_scenario_id',"scenario-$index"))){$arrival|Add-Member -NotePropertyName $pair[0] -NotePropertyValue $pair[1]}
        foreach($flag in @('ok','travel_ok','production_boundary_valid','arrival_contract_shape_valid','travel_contract_shape_valid','installed','installed_finalized','source_binding_valid','target_binding_valid','current_install_binding_valid','travel_install_binding_valid','installed_projection_binding_valid','live_projection_binding_valid','installed_live_projection_binding_valid','travel_projection_binding_valid','finalization_projection_binding_valid','independent_projection_binding_valid','projection_binding_valid','finalization_matches_runtime','runtime_layout_valid','finalization_clean')){$arrival|Add-Member -NotePropertyName $flag -NotePropertyValue $true};$arrival|Add-Member -NotePropertyName production_scenario_finalized -NotePropertyValue ($index-ne0);$arrival|Add-Member -NotePropertyName travel_projection_binding_required -NotePropertyValue ($index-ne0);$arrival|Add-Member -NotePropertyName runtime_scenario_layout -NotePropertyValue $layout;$arrival|Add-Member -NotePropertyName finalization -NotePropertyValue $finalization;$arrival|Add-Member -NotePropertyName arrival_error_count -NotePropertyValue 0;$arrival|Add-Member -NotePropertyName travel_error_count -NotePropertyValue 0;$arrival|Add-Member -NotePropertyName errors -NotePropertyValue ([object[]]@());$arrival|Add-Member -NotePropertyName travel_errors -NotePropertyValue ([object[]]@())
        $catalog=[object[]]@()
        if($index-lt5){$catalog=[object[]]@((&$newChoice "node-$($index+1)"),(&$newChoice 'spare-a'),(&$newChoice 'spare-b'))}
        $record=&$tuple;$record|Add-Member -NotePropertyName run_index -NotePropertyValue 0;$record|Add-Member -NotePropertyName visit_index -NotePropertyValue $index;$record|Add-Member -NotePropertyName capture_boundary -NotePropertyValue 'arrival_before_event_policy';$record|Add-Member -NotePropertyName seed_binding_after_event_policy -NotePropertyValue (&$tuple -Required);$record|Add-Member -NotePropertyName seed_binding_after_event_policy_valid -NotePropertyValue $true;$record|Add-Member -NotePropertyName arrival_receipt -NotePropertyValue $arrival;$record|Add-Member -NotePropertyName installed_finalized -NotePropertyValue $true;$record|Add-Member -NotePropertyName environment_id -NotePropertyValue "environment-$index";$record|Add-Member -NotePropertyName archetype_id -NotePropertyValue "archetype-$index";$record|Add-Member -NotePropertyName world_node_id -NotePropertyValue "node-$index";$record|Add-Member -NotePropertyName scenario_id -NotePropertyValue "scenario-$index";$record|Add-Member -NotePropertyName runtime_scenario_layout -NotePropertyValue $layout;$record|Add-Member -NotePropertyName travel_initial -NotePropertyValue $catalog;$record|Add-Member -NotePropertyName travel_initial_digest -NotePropertyValue ('1'.PadLeft(64,'1'));$record|Add-Member -NotePropertyName travel_after_events -NotePropertyValue $catalog;$record|Add-Member -NotePropertyName travel_after_events_digest -NotePropertyValue ('2'.PadLeft(64,'2'));[void]$records.Add($record)
        $visit=&$tuple;$visit|Add-Member -NotePropertyName visit_index -NotePropertyValue $index;$visit|Add-Member -NotePropertyName environment_id -NotePropertyValue "environment-$index";$visit|Add-Member -NotePropertyName archetype_id -NotePropertyValue "archetype-$index";$visit|Add-Member -NotePropertyName world_node_id -NotePropertyValue "node-$index";$visit|Add-Member -NotePropertyName scenario_id -NotePropertyValue "scenario-$index";$visit|Add-Member -NotePropertyName arrival_kind -NotePropertyValue $(if($index-eq0){'initial'}else{'travel'});$visit|Add-Member -NotePropertyName arrival_ok -NotePropertyValue $true;$visit|Add-Member -NotePropertyName installed_finalized -NotePropertyValue $true;$visit|Add-Member -NotePropertyName scenario_layout_authority_digest -NotePropertyValue $layout.authority_digest;[void]$visited.Add($visit)
    }
    foreach($record in @($records)){$record.travel_initial_digest=Get-Q009CanonicalJsonSha256 $record.travel_initial;$record.travel_after_events_digest=Get-Q009CanonicalJsonSha256 $record.travel_after_events}
    $run.visited=[object[]]@($visited);$run.initial_arrival_receipt=$records[0].arrival_receipt
    $travels=[System.Collections.Generic.List[object]]::new()
    for($index=0;$index-lt5;$index+=1){$source=$records[$index];$destination=$records[$index+1];$travel=&$tuple;$travel|Add-Member -NotePropertyName run_index -NotePropertyValue 0;$travel|Add-Member -NotePropertyName ok -NotePropertyValue $true;$travel|Add-Member -NotePropertyName travel_index -NotePropertyValue $index;$travel|Add-Member -NotePropertyName from_visit_index -NotePropertyValue $index;$travel|Add-Member -NotePropertyName to_visit_index -NotePropertyValue ($index+1);$travel|Add-Member -NotePropertyName source_id -NotePropertyValue $source.world_node_id;$travel|Add-Member -NotePropertyName from_world_node_id -NotePropertyValue $source.world_node_id;$travel|Add-Member -NotePropertyName from_environment_id -NotePropertyValue $source.environment_id;$travel|Add-Member -NotePropertyName from_archetype_id -NotePropertyValue $source.archetype_id;$travel|Add-Member -NotePropertyName target_id -NotePropertyValue $destination.world_node_id;$travel|Add-Member -NotePropertyName to_world_node_id -NotePropertyValue $destination.world_node_id;$travel|Add-Member -NotePropertyName to_environment_id -NotePropertyValue $destination.environment_id;$travel|Add-Member -NotePropertyName to_archetype_id -NotePropertyValue $destination.archetype_id;$travel|Add-Member -NotePropertyName arrival_receipt -NotePropertyValue $destination.arrival_receipt;$travel|Add-Member -NotePropertyName finalization_receipt -NotePropertyValue $destination.arrival_receipt.finalization;$travel|Add-Member -NotePropertyName admitted_targets_before -NotePropertyValue ([object[]]@($destination.world_node_id,'spare-a','spare-b'));$travel|Add-Member -NotePropertyName admitted_targets_after_heat -NotePropertyValue ([object[]]@($destination.world_node_id,'spare-a'));$travel|Add-Member -NotePropertyName admitted_targets_before_digest -NotePropertyValue ('3'.PadLeft(64,'3'));$travel|Add-Member -NotePropertyName admitted_targets_after_heat_digest -NotePropertyValue ('4'.PadLeft(64,'4'));$travel|Add-Member -NotePropertyName selected_choice -NotePropertyValue $source.travel_after_events[0];$travel|Add-Member -NotePropertyName selected_choice_digest -NotePropertyValue ('5'.PadLeft(64,'5'));[void]$travels.Add($travel)}
    foreach($travel in @($travels)){$travel.admitted_targets_before_digest=Get-Q009CanonicalJsonSha256 $travel.admitted_targets_before;$travel.admitted_targets_after_heat_digest=Get-Q009CanonicalJsonSha256 $travel.admitted_targets_after_heat;$travel.selected_choice_digest=Get-Q009CanonicalJsonSha256 $travel.selected_choice}
    return [pscustomobject][ordered]@{attempt_id=$attempt;run=$run;records=[object[]]@($records);travels=[object[]]@($travels)}
}

function New-SemanticAuthoritySelfTestReceipt {
    param(
        [string]$Identity,
        [ValidateSet('semantic','base_record')][string]$Branch,
        [bool]$Enabled=$true,
        [string]$SlotId='',
        [string]$BaseObjectId=''
    )
    $mode='room'
    $enabledActionIds=[object[]]@()
    if($Enabled){$enabledActionIds=[object[]]@('use')}
    return [pscustomobject][ordered]@{
        identity=$Identity;slot_id=$SlotId;base_object_id=$BaseObjectId;authority_branch=$Branch;authority_valid=$true;reachable=$true
        presentation_required=$true;presentation_visible=$true;presentation_interactive=$true;runtime_visible=$true;runtime_interactive=$true
        exact_sealed_authority=$true;sealed_geometry_valid=$true;action_authority_member=$true;action_authority_valid=$true
        semantic_interaction_member=($Branch-ceq'semantic');semantic_interaction_present=($Branch-ceq'semantic');semantic_interaction_sealed=($Branch-ceq'semantic');semantic_reachable=($Branch-ceq'semantic')
        base_record_present=($Branch-ceq'base_record');base_record_sealed=($Branch-ceq'base_record');base_geometry_matches_seal=($Branch-ceq'base_record');base_action_authority_member=($Branch-ceq'base_record');base_reachable=($Branch-ceq'base_record')
        reachability_basis=if($Branch-ceq'semantic'){'layout_audit_room'}else{'sealed_base_room'};presentation_mode=$mode;runtime_enabled=$Enabled
        action_authority_present=$Enabled;actionable=$Enabled;raw_action_count=if($Enabled){1}else{0};enabled_action_count=if($Enabled){1}else{0};enabled_action_ids=$enabledActionIds
        disabled_authority_valid=(-not$Enabled);disabled_reason=if($Enabled){''}else{'Requires a live event state.'}
    }
}

function New-HistoricalSemanticSelfTestFixture {
    $fixture=New-CrossBindingSelfTestFixture
    $run=$fixture.run;$records=@($fixture.records);$travels=@($fixture.travels);$attempt=[string]$fixture.attempt_id;$seed=[string]$run.seed
    $run|Add-Member -NotePropertyName attempt_id_valid -NotePropertyValue $true
    $run|Add-Member -NotePropertyName seed_binding_satisfied -NotePropertyValue $true
    $run|Add-Member -NotePropertyName stopped_reason -NotePropertyValue 'completed'
    foreach($pair in @(@('requested_visit_count',6),@('environment_count',6),@('installed_finalized_visit_count',6),@('identity_bound_visit_count',6),@('identity_bound_visited_summary_count',6),@('requested_travel_count',5),@('travel_count',5),@('travel_record_count',5),@('successful_linked_travel_count',5),@('terminal_visit_count',0))){$run|Add-Member -NotePropertyName $pair[0] -NotePropertyValue $pair[1]}
    $run|Add-Member -NotePropertyName visit_indices -NotePropertyValue ([object[]]@(0,1,2,3,4,5));$run|Add-Member -NotePropertyName travel_indices -NotePropertyValue ([object[]]@(0,1,2,3,4))
    foreach($name in @('contiguous_visit_indices','contiguous_travel_indices','requested_visits_satisfied','crew_state_unchanged')){$run|Add-Member -NotePropertyName $name -NotePropertyValue $true}
    $crewDigest='c'.PadLeft(64,'c');$run|Add-Member -NotePropertyName crew_state_before_sha256 -NotePropertyValue $crewDigest;$run|Add-Member -NotePropertyName crew_state_after_sha256 -NotePropertyValue $crewDigest
    for($index=0;$index-lt6;$index+=1){
        $record=$records[$index];$arrival=$record.arrival_receipt;$layout=$record.runtime_scenario_layout
        $record|Add-Member -NotePropertyName seed -NotePropertyValue $seed
        $record|Add-Member -NotePropertyName events -NotePropertyValue ([object[]]@())
        $layout|Add-Member -NotePropertyName phase_id -NotePropertyValue 'arrival'
        $layout.semantic_digest=('s'+$index.ToString().PadLeft(63,'0'))
        foreach($flag in @('action_authority_contract_valid','layout_audit_valid','authority_count_matches_audit','authority_digest_matches_audit','renderer_digest_matches_authority')){if($layout.PSObject.Properties.Name-contains$flag){$layout.$flag=$true}else{$layout|Add-Member -NotePropertyName $flag -NotePropertyValue $true}}
        foreach($pair in @(@('installed_projection_fingerprint','1'.PadLeft(64,'1')),@('live_projection_fingerprint','1'.PadLeft(64,'1')),@('travel_projection_fingerprint',$(if($index-eq0){''}else{'4'.PadLeft(64,'4')})),@('finalization_projection_fingerprint','3'.PadLeft(64,'3')),@('independent_projection_fingerprint','2'.PadLeft(64,'2')))){$arrival|Add-Member -NotePropertyName $pair[0] -NotePropertyValue $pair[1]}
    }
    $records[0].events=[object[]]@('combo_base')
    $records[0].runtime_scenario_layout.authority_receipts=[object[]]@(
        (New-SemanticAuthoritySelfTestReceipt 'scenario::combo' 'semantic'),
        (New-SemanticAuthoritySelfTestReceipt 'event::event:combo_base' 'base_record' $false 'base.staff' 'event:combo_base')
    )
    $records[2].events=[object[]]@('marker')
    $records[2].runtime_scenario_layout.authority_receipts=[object[]]@(
        (New-SemanticAuthoritySelfTestReceipt 'scenario::required' 'semantic'),
        (New-SemanticAuthoritySelfTestReceipt 'event::event:conflict' 'base_record' $false 'base.conflict' 'event:conflict')
    )
    foreach($receiptIndex in @(0,2)){
        $receiptLayout=$records[$receiptIndex].runtime_scenario_layout;$receiptIdentities=[object[]]@($receiptLayout.authority_receipts|ForEach-Object{[string]$_.identity})
        $receiptLayout.authority_identities=$receiptIdentities;$receiptLayout.authority_count=$receiptIdentities.Count
        $receiptLayout.action_authority_member_count=2;$receiptLayout.actionable_authority_count=1;$receiptLayout.invalid_action_authority_count=0;$receiptLayout.action_authority_contract_valid=$true
        $records[$receiptIndex].arrival_receipt.finalization.layout_authority_count=$receiptIdentities.Count
    }
    foreach($travel in $travels){$travel|Add-Member -NotePropertyName seed -NotePropertyValue $seed;$travel|Add-Member -NotePropertyName linked_to_recorded_visits -NotePropertyValue $true}
    $native=New-ZeroNativeDiagnostics 6
    $report=[pscustomobject][ordered]@{
        aggregate=[pscustomobject]@{};attempt_id=$attempt;attempt_id_required=$true;attempt_id_valid=$true;crew_state_unchanged=$true
        environment_records=[object[]]$records;evidence_schema_version=2;exact_seed_requested=$true;failure_count=0;failures=[object[]]@();generated_at_unix=[decimal]1.25
        installed_finalized_visit_count=6;method=[object[]]@('production');native_diagnostics=$native;native_diagnostics_clean=$true;passed=$true
        private_state_evidence_policy='digest_only';requested_seed_text=$seed;requested_total_travel_count=5;requested_total_visit_count=6;requested_visits_satisfied=$true
        run_count=1;runs=[object[]]@($run);seed_prefix='';successful_linked_travel_count=5;tool='environment_generation_audit';tool_failure_count=0;tool_warning_count=0
        travel_records=[object[]]$travels;travels_per_run_target=5;visits_per_run_target=6;warning_count=0;warnings=[object[]]@();warnings_clean=$true
    }
    $expectation=[pscustomobject]@{seed=$seed;destination='archetype-2';scenario_id='scenario-2';required_marker='marker';required_object='';required_interaction='scenario::required';conflict_identity='event::event:conflict'}
    $combo=[pscustomobject]@{seed=$seed;destination='archetype-0';scenario_id='scenario-0';phase_id='arrival';base_event_id='combo_base';base_slot_id='base.staff';scenario_identity='scenario::combo'}
    return [pscustomobject][ordered]@{attempt_id=$attempt;report=$report;expectation=$expectation;combo=$combo}
}

function Invoke-ValidateOnlySelfTest {
    $cases=[System.Collections.Generic.List[object]]::new()
    $tempParent=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\','/')
    $tempRoot=Join-Path $tempParent ('rw06-q009-selftest-'+[guid]::NewGuid().ToString('N'))
    $tempRootIdentity=$null;$selfTestRunContext=$null;$selfTestOwnerReceipt=$null
    $selfTestAttemptId='rw06-1-selftest-'+[guid]::NewGuid().ToString('N')
    try{
        if([string]::IsNullOrWhiteSpace($SelfTestReport)){throw '-SelfTestReport is required with -ValidateOnly'}
        $reportPath=[IO.Path]::GetFullPath($SelfTestReport);$forbiddenRoots=@([IO.Path]::GetFullPath($leaseRoot),[IO.Path]::GetFullPath($projectCacheRoot))
        foreach($root in $forbiddenRoots){if($reportPath.StartsWith($root,[StringComparison]::OrdinalIgnoreCase)){throw 'ValidateOnly report may not touch canonical lease/cache roots'}}
        if(Test-Path -LiteralPath $reportPath){throw 'ValidateOnly refuses to overwrite SelfTestReport'}
        [void][IO.Directory]::CreateDirectory((Split-Path -Parent $reportPath))
        $tempRootIdentity=New-Q009ExactOwnedDirectory $tempRoot
        $selfTestOwnerReceipt=[ordered]@{scope='ValidateOnly';attempt_id=[string]$selfTestAttemptId;root_identity=$tempRootIdentity}
        $selfTestLeaseRoot=Join-Path $tempRoot 'leases';[void](New-Q009ExactOwnedDirectory $selfTestLeaseRoot)
        $selfTestLauncherProcess=Get-ProcessByIdStrict -ProcessId $PID;if($null-eq$selfTestLauncherProcess){throw 'ValidateOnly launcher disappeared before immutable self-test context capture'}
        $selfTestLauncherIdentity=Get-ProcessIdentityRecord $selfTestLauncherProcess
        if(-not(Test-ProcessIdentityProofShape $selfTestLauncherIdentity)){throw 'ValidateOnly launcher identity capture returned no exact record'}
        $selfTestRunContext=New-Q009RunContext -AttemptId $selfTestAttemptId -CandidateCommit ('a'*40) -CandidateTree ('b'*40) -LauncherIdentity $selfTestLauncherIdentity -CanonicalLeaseRoot $selfTestLeaseRoot -WorkingDirectory $tempRoot -ProjectRoot $projectRoot -LaunchMutexName ('Local\BeatTheHouse-Q009-selftest-'+[guid]::NewGuid().ToString('N'))
        $selfTestOwnerReceipt=[ordered]@{scope='ValidateOnly';attempt_id=[string]$selfTestAttemptId;run_context_sha256=[string]$selfTestRunContext.context_sha256;launcher_identity=$selfTestLauncherIdentity;root_identity=$tempRootIdentity}
        $selfTestExecutableIdentity=Get-ExecutableIdentity (Join-Path $PSHOME 'powershell.exe')
        Add-SelfTestResult $cases 'manifest-exact-order-distribution-and-identity' { $m=Read-JsonFileStrict $manifestPath;$i=@(Get-CanonicalManifestIssues $m $expectedManifestSha256 $expectedManifestBlob);Assert-LauncherContract ($i.Count -eq 0) ($i -join '; ') }
        Add-SelfTestResult $cases 'manifest-substitution-order-extra-types-and-safe-name-collision' { $m=Read-JsonFileStrict $manifestPath|ConvertTo-Json -Depth 20|ConvertFrom-Json;$tmp=$m.expectations[0];$m.expectations[0]=$m.expectations[1];$m.expectations[1]=$tmp;Assert-LauncherContract (@(Get-CanonicalManifestIssues $m -SkipIdentity).Count -gt 0) 'order substitution accepted';$m=Read-JsonFileStrict $manifestPath|ConvertTo-Json -Depth 20|ConvertFrom-Json;$m.expectations[1].seed='POSTFIX/UIENV';$m.expectations[2].seed='POSTFIX?UIENV';Assert-LauncherContract (@(Get-CanonicalManifestIssues $m -SkipIdentity).Count -gt 0) 'safe-name collision accepted';$m=Read-JsonFileStrict $manifestPath|ConvertTo-Json -Depth 20|ConvertFrom-Json;$m.schema_version='1';Assert-LauncherContract (@(Get-CanonicalManifestIssues $m -SkipIdentity).Count -gt 0) 'wrong manifest scalar type accepted';$m=Read-JsonFileStrict $manifestPath|ConvertTo-Json -Depth 20|ConvertFrom-Json;$m.expectations=@($m.expectations)+@($m.expectations[0]);Assert-LauncherContract (@(Get-CanonicalManifestIssues $m -SkipIdentity).Count -gt 0) 'extra/duplicate manifest row accepted';foreach($mutation in @('source-array','row-seed-array','row-interaction-array','combo-phase-array')){$m=Read-JsonFileStrict $manifestPath|ConvertTo-Json -Depth 20|ConvertFrom-Json;switch($mutation){'source-array'{$m.source=[object[]]@([string]$m.source)}'row-seed-array'{$m.expectations[0].seed=[object[]]@([string]$m.expectations[0].seed)}'row-interaction-array'{$m.expectations[0].required_interaction=[object[]]@([string]$m.expectations[0].required_interaction)}'combo-phase-array'{$m.legal_room_combinations[0].phase_id=[object[]]@([string]$m.legal_room_combinations[0].phase_id)}};Assert-LauncherContract (@(Get-CanonicalManifestIssues $m -SkipIdentity).Count-gt0) "manifest one-element string array accepted: $mutation"} }
        Add-SelfTestResult $cases 'authority-conflict-and-seed009-combination-shapes' { $good=[pscustomobject]@{authority_branch='semantic';authority_valid=$true;reachable=$true;presentation_required=$true;presentation_visible=$true;presentation_interactive=$true;runtime_visible=$true;runtime_interactive=$true;exact_sealed_authority=$true;sealed_geometry_valid=$true;action_authority_member=$true;action_authority_valid=$true;semantic_interaction_member=$true;semantic_interaction_present=$true;semantic_interaction_sealed=$true;semantic_reachable=$true;base_reachable=$false;base_action_authority_member=$false;reachability_basis='layout_audit_room';runtime_enabled=$true;action_authority_present=$true;actionable=$true;raw_action_count=1;enabled_action_count=1;enabled_action_ids=@('use');presentation_mode='room';disabled_authority_valid=$false;disabled_reason=''};Assert-LauncherContract (Test-AuthorityReceipt $good 'semantic') 'valid semantic authority rejected';Assert-LauncherContract (-not(Test-AuthorityReceipt $good 'base_record')) 'wrong branch accepted';$good.semantic_interaction_sealed=$false;Assert-LauncherContract (-not(Test-AuthorityReceipt $good 'semantic')) 'unsealed semantic authority accepted';$good.semantic_interaction_sealed=$true;$good.runtime_visible=$false;Assert-LauncherContract (-not(Test-AuthorityReceipt $good 'semantic')) 'hidden authority accepted' }
        Add-SelfTestResult $cases 'base-authority-enabled-disabled-and-seal-geometry' { $base=[pscustomobject]@{authority_branch='base_record';authority_valid=$true;reachable=$true;presentation_required=$true;presentation_visible=$true;presentation_interactive=$true;runtime_visible=$true;runtime_interactive=$true;exact_sealed_authority=$true;sealed_geometry_valid=$true;action_authority_member=$true;action_authority_valid=$true;semantic_interaction_member=$false;base_record_present=$true;base_record_sealed=$true;base_geometry_matches_seal=$true;base_action_authority_member=$true;base_reachable=$true;semantic_reachable=$false;reachability_basis='sealed_base_room';runtime_enabled=$true;action_authority_present=$true;actionable=$true;raw_action_count=1;enabled_action_count=1;enabled_action_ids=@('use');presentation_mode='room';disabled_authority_valid=$false;disabled_reason=''};Assert-LauncherContract (Test-AuthorityReceipt $base 'base_record') 'valid enabled base authority rejected';$base.runtime_enabled=$false;$base.action_authority_present=$false;$base.actionable=$false;$base.raw_action_count=0;$base.enabled_action_count=0;$base.enabled_action_ids=[object[]]@();$base.disabled_authority_valid=$true;$base.disabled_reason='Requires a live event state.';Assert-LauncherContract (Test-AuthorityReceipt $base 'base_record' -AllowDisabled) 'valid disabled-with-reason base authority rejected';Assert-LauncherContract (-not(Test-AuthorityReceipt $base 'base_record')) 'disabled base authority accepted without AllowDisabled';$base.disabled_reason='';Assert-LauncherContract (-not(Test-AuthorityReceipt $base 'base_record' -AllowDisabled)) 'disabled base authority without reason accepted';$base.disabled_reason='Requires a live event state.';$base.base_geometry_matches_seal=$false;Assert-LauncherContract (-not(Test-AuthorityReceipt $base 'base_record' -AllowDisabled)) 'base geometry drift accepted' }
        Add-SelfTestResult $cases 'nested-attempt-and-seed-tuple-binding' { $run=[pscustomobject]@{attempt_id='a';seed='s';requested_seed_text='s';seed_text='s';seed_value=7;challenge_key='k';challenge_id='i';challenge_mode='m';derived_seed_value=8;seed_binding_valid=$true};$nested=[pscustomobject]@{attempt_id='a';requested_seed_text='s';seed_text='s';seed_value=7;challenge_key='k';challenge_id='i';challenge_mode='m';derived_seed_value=8;seed_binding_valid=$true};Assert-LauncherContract (Test-SeedTupleMatches $nested $run 'a') 'valid nested tuple rejected';$nested.attempt_id='other';Assert-LauncherContract (-not(Test-SeedTupleMatches $nested $run 'a')) 'nested attempt mismatch accepted';$nested.attempt_id='a';$nested.seed_value=9;Assert-LauncherContract (-not(Test-SeedTupleMatches $nested $run 'a')) 'nested seed mismatch accepted';$nested.seed_value=7;$nested.challenge_key=[object[]]@('k');Assert-LauncherContract (-not(Test-SeedTupleMatches $nested $run 'a')) 'nested one-element challenge-key array accepted';$nested.challenge_key='k';$run.seed_text=[object[]]@('s');Assert-LauncherContract (-not(Test-SeedTupleMatches $nested $run 'a')) 'run one-element seed-text array accepted' }
        Add-SelfTestResult $cases 'final-post-event-visited-arrival-travel-and-admission-cross-binding' {
            $fixture=New-CrossBindingSelfTestFixture
            Assert-LauncherContract (@(Get-RunCrossBindingIssues $fixture.run $fixture.records $fixture.travels $fixture.attempt_id).Count-eq0) 'valid six-visit cross-binding fixture rejected'
            foreach($mutation in @(
                'final','post','visited','capture','initial','raw-travel','projection','admission','admission-after','layout','raw-type',
                'arrival-false','arrival-string-true','visited-false','visited-array-true','travel-false','travel-string-true','installed-id-array',
                'kind-array','semantic-status-string','initial-finalized-true','travel-finalized-false','missing-challenge-daily','initial-catalog-hidden',
                'after-catalog-hidden','catalog-empty','catalog-target-omission','selected-choice-disabled','selected-choice-splice',
                'catalog-admission-synchronized-splice','initial-catalog-digest','after-catalog-digest','admission-digest','admission-after-digest',
                'selected-choice-digest','risk-event-extra-key','risk-event-key-order','unlock-conditions-scalar','selected-choice-resealed-splice',
                'catalog-extra-resealed','catalog-reordered-resealed','catalog-null-resealed','admission-extra-resealed','admission-reordered-resealed','admission-null','post-heat-extra-resealed'
            )){
                $copy=($fixture|ConvertTo-Json -Depth 100|ConvertFrom-Json)
                switch($mutation){
                    'final'{$copy.run.final_seed_binding.attempt_id='other'}
                    'post'{$copy.records[2].seed_binding_after_event_policy.seed_value=99}
                    'visited'{$copy.run.visited[3].world_node_id='spliced'}
                    'capture'{$copy.records[4].capture_boundary='after_event_policy'}
                    'initial'{$copy.run.initial_arrival_receipt.installed_environment_id='spliced'}
                    'raw-travel'{$copy.travels[1].arrival_receipt.travel_scenario_id='spliced'}
                    'projection'{$copy.travels[2].arrival_receipt.independent_projection_binding_valid=$false}
                    'admission'{$copy.travels[3].admitted_targets_before=@('other')}
                    'admission-after'{$copy.travels[3].admitted_targets_after_heat=@('other')}
                    'layout'{$copy.records[5].runtime_scenario_layout.authority_digest='spliced'}
                    'raw-type'{$copy.travels[0].target_id=17}
                    'arrival-false'{$copy.records[0].arrival_receipt.ok=$false}
                    'arrival-string-true'{$copy.records[1].arrival_receipt.travel_ok='true'}
                    'visited-false'{$copy.run.visited[2].arrival_ok=$false}
                    'visited-array-true'{$copy.run.visited[2].installed_finalized=[object[]]@($true)}
                    'travel-false'{$copy.travels[1].ok=$false}
                    'travel-string-true'{$copy.travels[1].ok='true'}
                    'installed-id-array'{$copy.records[3].arrival_receipt.installed_environment_id=[object[]]@([string]$copy.records[3].environment_id)}
                    'kind-array'{$copy.records[4].arrival_receipt.kind=[object[]]@('travel')}
                    'semantic-status-string'{$copy.records[5].arrival_receipt.runtime_scenario_layout.semantic_ready='true'}
                    'initial-finalized-true'{$copy.records[0].arrival_receipt.production_scenario_finalized=$true;$copy.run.initial_arrival_receipt.production_scenario_finalized=$true}
                    'travel-finalized-false'{$copy.records[1].arrival_receipt.production_scenario_finalized=$false;$copy.travels[0].arrival_receipt.production_scenario_finalized=$false}
                    'missing-challenge-daily'{$copy.records[2].arrival_receipt.PSObject.Properties.Remove('challenge_daily_id');$copy.travels[1].arrival_receipt.PSObject.Properties.Remove('challenge_daily_id')}
                    'initial-catalog-hidden'{$copy.records[0].travel_initial[0].hidden=$true}
                    'after-catalog-hidden'{$copy.records[1].travel_after_events[0].hidden=$true}
                    'catalog-empty'{$copy.records[2].travel_after_events=[object[]]@()}
                    'catalog-target-omission'{$copy.records[3].travel_after_events=[object[]]@($copy.records[3].travel_after_events|Where-Object{[string]$_.id-cne[string]$copy.travels[3].target_id})}
                    'selected-choice-disabled'{$copy.travels[1].selected_choice.enabled=$false}
                    'selected-choice-splice'{$copy.travels[2].selected_choice.label='spliced'}
                    'catalog-admission-synchronized-splice'{$copy.records[4].travel_after_events[0].id='fake-target';$copy.travels[4].admitted_targets_before[0]='fake-target';$copy.travels[4].selected_choice.id='fake-target';$copy.travels[4].target_id='fake-target'}
                    'initial-catalog-digest'{$copy.records[0].travel_initial_digest='0'.PadLeft(64,'0')}
                    'after-catalog-digest'{$copy.records[1].travel_after_events_digest='0'.PadLeft(64,'0')}
                    'admission-digest'{$copy.travels[2].admitted_targets_before_digest='0'.PadLeft(64,'0')}
                    'admission-after-digest'{$copy.travels[2].admitted_targets_after_heat_digest='0'.PadLeft(64,'0')}
                    'selected-choice-digest'{$copy.travels[3].selected_choice_digest='0'.PadLeft(64,'0')}
                    'risk-event-extra-key'{$copy.records[0].travel_after_events[0].risk_event=[pscustomobject][ordered]@{extra='forbidden'}}
                    'risk-event-key-order'{$copy.records[0].travel_after_events[0].risk_event=[pscustomobject][ordered]@{label='risk';id='risk';chance_percent=1;bankroll_delta=0;suspicion_delta=0;message=''}}
                    'unlock-conditions-scalar'{$copy.records[0].travel_after_events[0].unlock_conditions='none'}
                    'selected-choice-resealed-splice'{$copy.travels[0].selected_choice.label='resealed-splice';$copy.travels[0].selected_choice_digest=Get-Q009CanonicalJsonSha256 $copy.travels[0].selected_choice}
                    'catalog-extra-resealed'{$extra=$copy.records[0].travel_after_events[0]|ConvertTo-Json -Depth 20|ConvertFrom-Json;$extra.id='extra-route';$extra.label='extra-route';$copy.records[0].travel_after_events=[object[]]@($copy.records[0].travel_after_events)+@($extra);$copy.records[0].travel_after_events_digest=Get-Q009CanonicalJsonSha256 $copy.records[0].travel_after_events}
                    'catalog-reordered-resealed'{$copy.records[0].travel_after_events=[object[]]@($copy.records[0].travel_after_events[2],$copy.records[0].travel_after_events[1],$copy.records[0].travel_after_events[0]);$copy.records[0].travel_after_events_digest=Get-Q009CanonicalJsonSha256 $copy.records[0].travel_after_events}
                    'catalog-null-resealed'{$copy.records[0].travel_after_events[1].risk_event=$null;$copy.records[0].travel_after_events_digest=Get-Q009CanonicalJsonSha256 $copy.records[0].travel_after_events}
                    'admission-extra-resealed'{$copy.travels[0].admitted_targets_before=[object[]]@($copy.travels[0].admitted_targets_before)+@('extra-route');$copy.travels[0].admitted_targets_before_digest=Get-Q009CanonicalJsonSha256 $copy.travels[0].admitted_targets_before}
                    'admission-reordered-resealed'{$copy.travels[0].admitted_targets_before=[object[]]@($copy.travels[0].admitted_targets_before[2],$copy.travels[0].admitted_targets_before[1],$copy.travels[0].admitted_targets_before[0]);$copy.travels[0].admitted_targets_before_digest=Get-Q009CanonicalJsonSha256 $copy.travels[0].admitted_targets_before}
                    'admission-null'{$copy.travels[0].admitted_targets_before=$null;$copy.travels[0].admitted_targets_before_digest=Get-Q009CanonicalJsonSha256 $copy.travels[0].admitted_targets_before}
                    'post-heat-extra-resealed'{$copy.travels[0].admitted_targets_after_heat=[object[]]@($copy.travels[0].admitted_targets_after_heat)+@('extra-route');$copy.travels[0].admitted_targets_after_heat_digest=Get-Q009CanonicalJsonSha256 $copy.travels[0].admitted_targets_after_heat}
                }
                Assert-LauncherContract (@(Get-RunCrossBindingIssues $copy.run @($copy.records) @($copy.travels) $copy.attempt_id).Count-gt0) "cross-binding mutation accepted: $mutation"
            }
        }
        Add-SelfTestResult $cases 'initial-arrival-independent-identity-index-and-type-hostiles' {
            $fixture=New-CrossBindingSelfTestFixture
            foreach($mutation in @('synchronized-target','synchronized-source','target-array','visit-index-array','travel-index-string','from-index-fraction','attempt-array')){
                $copy=$fixture|ConvertTo-Json -Depth 100|ConvertFrom-Json;$recordArrival=$copy.records[0].arrival_receipt;$runArrival=$copy.run.initial_arrival_receipt
                switch($mutation){
                    'synchronized-target'{foreach($arrival in @($recordArrival,$runArrival)){$arrival.target_id='spliced-target';$arrival.travel_target_id='spliced-target'}}
                    'synchronized-source'{foreach($arrival in @($recordArrival,$runArrival)){$arrival.source_id='spliced-source';$arrival.travel_source_id='spliced-source'}}
                    'target-array'{foreach($arrival in @($recordArrival,$runArrival)){$arrival.target_id=[object[]]@('node-0')}}
                    'visit-index-array'{foreach($arrival in @($recordArrival,$runArrival)){$arrival.visit_index=[object[]]@(0)}}
                    'travel-index-string'{foreach($arrival in @($recordArrival,$runArrival)){$arrival.travel_index='-1'}}
                    'from-index-fraction'{foreach($arrival in @($recordArrival,$runArrival)){$arrival.from_visit_index=[double]-1.0}}
                    'attempt-array'{foreach($arrival in @($recordArrival,$runArrival)){$arrival.attempt_id=[object[]]@($copy.attempt_id)}}
                }
                Assert-LauncherContract (@(Get-RunCrossBindingIssues $copy.run @($copy.records) @($copy.travels) $copy.attempt_id).Count-gt0) "independent initial-arrival hostile accepted: $mutation"
            }
        }
        Add-SelfTestResult $cases 'historical-six-visit-five-link-semantic-mutation-matrix' {
            $fixture=New-HistoricalSemanticSelfTestFixture
            $raw=$fixture.report|ConvertTo-Json -Compress -Depth 100
            $valid=@(Get-AuditSemanticIssues $fixture.report $fixture.attempt_id 1 6 5 $fixture.expectation $fixture.combo $raw)
            Assert-LauncherContract ($valid.Count-eq0) ('valid historical semantic fixture rejected: '+($valid-join'; '))
            $expectedTexts=@{
                'wrong-scenario'='historical target/scenario';'required-interaction'='required semantic interaction';'conflict'='projected base conflict'
                'missing-seed009-combo'='seed 009 pre-destination';'broken-chronology'='environment record';'duplicate-target'='exactly once'
                'wrong-incoming-link'='incoming recorded travel';'duplicate-environment'='environment record';'extra-environment'='environment record'
                'out-of-order-environment'='environment record';'duplicate-travel'='travel record';'extra-travel'='travel record';'out-of-order-travel'='travel record'
            }
            foreach($mutation in $expectedTexts.Keys|Sort-Object){
                $copy=($fixture|ConvertTo-Json -Depth 100|ConvertFrom-Json)
                switch($mutation){
                    'wrong-scenario'{$copy.report.environment_records[2].scenario_id='wrong';$copy.report.environment_records[2].arrival_receipt.installed_scenario_id='wrong';$copy.report.environment_records[2].arrival_receipt.travel_scenario_id='wrong';$copy.report.runs[0].visited[2].scenario_id='wrong'}
                    'required-interaction'{
                        foreach($layout in @($copy.report.environment_records[2].runtime_scenario_layout,$copy.report.environment_records[2].arrival_receipt.runtime_scenario_layout,$copy.report.travel_records[1].arrival_receipt.runtime_scenario_layout)){
                            $receipt=@($layout.authority_receipts|Where-Object{[string]$_.identity-ceq'scenario::required'})
                            Assert-LauncherContract ($receipt.Count-eq1) 'required-interaction hostile fixture lost its exact receipt'
                            $receipt[0].semantic_interaction_present=$false
                        }
                    }
                    'conflict'{
                        foreach($layout in @($copy.report.environment_records[2].runtime_scenario_layout,$copy.report.environment_records[2].arrival_receipt.runtime_scenario_layout,$copy.report.travel_records[1].arrival_receipt.runtime_scenario_layout)){
                            $receipt=@($layout.authority_receipts|Where-Object{[string]$_.identity-ceq'event::event:conflict'})
                            Assert-LauncherContract ($receipt.Count-eq1) 'conflict hostile fixture lost its exact receipt'
                            $receipt[0].base_geometry_matches_seal=$false
                        }
                    }
                    'missing-seed009-combo'{$copy.report.environment_records[0].events=[object[]]@()}
                    'broken-chronology'{$copy.report.environment_records[0].visit_index=4}
                    'duplicate-target'{$copy.report.environment_records[4].seed=$copy.expectation.seed;$copy.report.environment_records[4].archetype_id=$copy.expectation.destination;$copy.report.environment_records[4].scenario_id=$copy.expectation.scenario_id;$copy.report.environment_records[4].events=[object[]]@($copy.expectation.required_marker)}
                    'wrong-incoming-link'{$copy.report.travel_records[1].target_id='other'}
                    'duplicate-environment'{$copy.report.environment_records[1]=$copy.report.environment_records[0]}
                    'extra-environment'{$copy.report.environment_records=@($copy.report.environment_records)+@($copy.report.environment_records[5])}
                    'out-of-order-environment'{$tmp=$copy.report.environment_records[1];$copy.report.environment_records[1]=$copy.report.environment_records[2];$copy.report.environment_records[2]=$tmp}
                    'duplicate-travel'{$copy.report.travel_records[1]=$copy.report.travel_records[0]}
                    'extra-travel'{$copy.report.travel_records=@($copy.report.travel_records)+@($copy.report.travel_records[4])}
                    'out-of-order-travel'{$tmp=$copy.report.travel_records[1];$copy.report.travel_records[1]=$copy.report.travel_records[2];$copy.report.travel_records[2]=$tmp}
                }
                $mutatedRaw=$copy.report|ConvertTo-Json -Compress -Depth 100
                $mutated=@(Get-AuditSemanticIssues $copy.report $copy.attempt_id 1 6 5 $copy.expectation $copy.combo $mutatedRaw)
                Assert-LauncherContract ($mutated.Count-gt0) "semantic mutation accepted: $mutation"
                Assert-LauncherContract (($mutated-join"`n").Contains([string]$expectedTexts[$mutation])) "semantic mutation did not exercise intended diagnostic: $mutation -> $($mutated-join'; ')"
            }
        }
        Add-SelfTestResult $cases 'exact-index-arrays-envelope-bool-and-decimal-time-hostiles' {
            $fixture=New-HistoricalSemanticSelfTestFixture
            foreach($mutation in @('visit-scalar','travel-scalar','visit-string-element','travel-fraction','visit-duplicate','travel-extra','exact-bool-array','exact-bool-string','exact-bool-false','unix-int','unix-long','unix-double','unix-string','unix-array','unix-bool','unix-zero','unix-negative')){
                $copy=$fixture|ConvertTo-Json -Depth 100|ConvertFrom-Json
                switch($mutation){
                    'visit-scalar'{$copy.report.runs[0].visit_indices='0,1,2,3,4,5'}
                    'travel-scalar'{$copy.report.runs[0].travel_indices='0,1,2,3,4'}
                    'visit-string-element'{$copy.report.runs[0].visit_indices[2]='2'}
                    'travel-fraction'{$copy.report.runs[0].travel_indices[2]=[double]2.5}
                    'visit-duplicate'{$copy.report.runs[0].visit_indices=[object[]]@(0,1,2,2,4,5)}
                    'travel-extra'{$copy.report.runs[0].travel_indices=[object[]]@(0,1,2,3,4,5)}
                    'exact-bool-array'{$copy.report.exact_seed_requested=[object[]]@($true)}
                    'exact-bool-string'{$copy.report.exact_seed_requested='true'}
                    'exact-bool-false'{$copy.report.exact_seed_requested=$false}
                    'unix-int'{$copy.report.generated_at_unix=[int]1}
                    'unix-long'{$copy.report.generated_at_unix=[long]2147483648}
                    'unix-double'{$copy.report.generated_at_unix=[double]1.5}
                    'unix-string'{$copy.report.generated_at_unix='1.5'}
                    'unix-array'{$copy.report.generated_at_unix=[object[]]@(1)}
                    'unix-bool'{$copy.report.generated_at_unix=$true}
                    'unix-zero'{$copy.report.generated_at_unix=[decimal]0}
                    'unix-negative'{$copy.report.generated_at_unix=[decimal]-1.25}
                }
                $raw=$copy.report|ConvertTo-Json -Compress -Depth 100
                Assert-LauncherContract (@(Get-AuditSemanticIssues $copy.report $copy.attempt_id 1 6 5 $copy.expectation $copy.combo $raw).Count-gt0) "index/envelope scalar hostile accepted: $mutation"
            }
        }
        Add-SelfTestResult $cases 'ordinary-row-arrival-errors-and-authority-collection-hostiles' {
            $fixture=New-HistoricalSemanticSelfTestFixture
            foreach($mutation in @('duplicated-forged-errors','travel-only-forged-errors','errors-nonempty-zero-count','errors-null','travel-errors-nonempty-zero-count','travel-errors-null','travel-error-count-string','authority-null','authority-scalar','authority-wrong-element','authority-count-splice','authority-action-invalid','authority-count-invalid','layout-scalar')){
                $copy=$fixture|ConvertTo-Json -Depth 100|ConvertFrom-Json
                switch($mutation){
                    'duplicated-forged-errors'{foreach($arrival in @($copy.report.environment_records[3].arrival_receipt,$copy.report.travel_records[2].arrival_receipt)){$arrival.errors=[object[]]@('forged');$arrival.arrival_error_count=1}}
                    'travel-only-forged-errors'{$copy.report.travel_records[2].arrival_receipt.errors=[object[]]@('forged');$copy.report.travel_records[2].arrival_receipt.arrival_error_count=1}
                    'errors-nonempty-zero-count'{$copy.report.environment_records[4].arrival_receipt.errors=[object[]]@('forged')}
                    'errors-null'{$copy.report.environment_records[4].arrival_receipt.errors=$null}
                    'travel-errors-nonempty-zero-count'{$copy.report.environment_records[4].arrival_receipt.travel_errors=[object[]]@('forged');$copy.report.travel_records[3].arrival_receipt.travel_errors=[object[]]@('forged')}
                    'travel-errors-null'{$copy.report.environment_records[4].arrival_receipt.travel_errors=$null;$copy.report.travel_records[3].arrival_receipt.travel_errors=$null}
                    'travel-error-count-string'{$copy.report.environment_records[4].arrival_receipt.travel_error_count='0';$copy.report.travel_records[3].arrival_receipt.travel_error_count='0'}
                    'authority-null'{$copy.report.environment_records[4].runtime_scenario_layout.authority_receipts=$null;$copy.report.environment_records[4].arrival_receipt.runtime_scenario_layout.authority_receipts=$null;$copy.report.travel_records[3].arrival_receipt.runtime_scenario_layout.authority_receipts=$null}
                    'authority-scalar'{$copy.report.environment_records[4].runtime_scenario_layout.authority_receipts='none';$copy.report.environment_records[4].arrival_receipt.runtime_scenario_layout.authority_receipts='none';$copy.report.travel_records[3].arrival_receipt.runtime_scenario_layout.authority_receipts='none'}
                    'authority-wrong-element'{$wrong=[object[]]@('not-an-object');$copy.report.environment_records[4].runtime_scenario_layout.authority_receipts=$wrong;$copy.report.environment_records[4].arrival_receipt.runtime_scenario_layout.authority_receipts=$wrong;$copy.report.travel_records[3].arrival_receipt.runtime_scenario_layout.authority_receipts=$wrong;$copy.report.environment_records[4].runtime_scenario_layout.authority_count=1;$copy.report.environment_records[4].runtime_scenario_layout.authority_identities=[object[]]@('not-an-object')}
                    'authority-count-splice'{foreach($layout in @($copy.report.environment_records[4].runtime_scenario_layout,$copy.report.environment_records[4].arrival_receipt.runtime_scenario_layout,$copy.report.travel_records[3].arrival_receipt.runtime_scenario_layout)){$layout.authority_receipts=[object[]]@([pscustomobject]@{identity='forged::authority'});$layout.authority_identities=[object[]]@('forged::authority')}}
                    'authority-action-invalid'{foreach($layout in @($copy.report.environment_records[2].runtime_scenario_layout,$copy.report.environment_records[2].arrival_receipt.runtime_scenario_layout,$copy.report.travel_records[1].arrival_receipt.runtime_scenario_layout)){$layout.authority_receipts[0].action_authority_valid=$false}}
                    'authority-count-invalid'{foreach($layout in @($copy.report.environment_records[2].runtime_scenario_layout,$copy.report.environment_records[2].arrival_receipt.runtime_scenario_layout,$copy.report.travel_records[1].arrival_receipt.runtime_scenario_layout)){$layout.action_authority_member_count=1;$layout.actionable_authority_count=0}}
                    'layout-scalar'{$copy.report.environment_records[4].runtime_scenario_layout='layout';$copy.report.environment_records[4].arrival_receipt.runtime_scenario_layout='layout';$copy.report.travel_records[3].arrival_receipt.runtime_scenario_layout='layout'}
                }
                $raw=$copy.report|ConvertTo-Json -Compress -Depth 100
                Assert-LauncherContract (@(Get-AuditSemanticIssues $copy.report $copy.attempt_id 1 6 5 $null $null $raw).Count-gt0) "ordinary qualifying row hostile accepted: $mutation"
            }
        }
        Add-SelfTestResult $cases 'inactive-independent-projection-sentinel' {
            $auditProducerSource=[IO.File]::ReadAllText($auditPath,[Text.UTF8Encoding]::new($false))
            Assert-LauncherContract ([regex]::Matches($auditProducerSource,'(?m)^\s*"fingerprint"\s*:\s*_json_sha256\(\{"active"\s*:\s*false\}\),\s*$').Count-eq1) 'canonical inactive projection producer witness was missing or ambiguous'
            $canonicalInactiveProducerFingerprint=Get-Q009CanonicalJsonSha256 ([ordered]@{active=[bool]$false})
            Assert-LauncherContract ([string]$canonicalInactiveProducerFingerprint-ceq$inactiveIndependentProjectionFingerprint) 'consumer inactive sentinel did not equal the canonical producer payload fingerprint'
            $fixture=New-HistoricalSemanticSelfTestFixture
            $record=$fixture.report.environment_records[5]
            $arrival=$record.arrival_receipt
            $layout=$record.runtime_scenario_layout
            $record.scenario_id=''
            $fixture.report.runs[0].visited[5].scenario_id=''
            $fixture.report.runs[0].visited[5].scenario_layout_authority_digest=''
            $arrival.installed_scenario_id=''
            $arrival.travel_scenario_id=''
            $arrival.runtime_scenario_layout.scenario_id=''
            $arrival.runtime_scenario_layout.status='inactive'
            $arrival.runtime_scenario_layout.semantic_ready=$false
            $arrival.runtime_scenario_layout.live_semantic_ready=$false
            $arrival.runtime_scenario_layout.semantic_digest=''
            $arrival.runtime_scenario_layout.authority_digest=''
            $arrival.runtime_scenario_layout.authority_count=0
            $arrival.runtime_scenario_layout.authority_identities=[object[]]@()
            $arrival.runtime_scenario_layout.authority_receipts=[object[]]@()
            $arrival.runtime_scenario_layout.action_authority_member_count=0
            $arrival.runtime_scenario_layout.actionable_authority_count=0
            $arrival.runtime_scenario_layout.invalid_action_authority_count=0
            $arrival.finalization.inactive=$true
            $arrival.finalization.semantic_digest=''
            $arrival.finalization.layout_authority_digest=''
            $arrival.finalization.layout_authority_count=0
            $arrival.finalization_projection_fingerprint=''
            $arrival.independent_projection_fingerprint=$inactiveIndependentProjectionFingerprint
            $fixture.report.travel_records[4].finalization_receipt=$arrival.finalization
            $raw=$fixture.report|ConvertTo-Json -Compress -Depth 100
            $valid=@(Get-AuditSemanticIssues $fixture.report $fixture.attempt_id 1 6 5 $fixture.expectation $fixture.combo $raw)
            Assert-LauncherContract ($valid.Count-eq0) ('production-shaped inactive arrival rejected: '+($valid-join'; '))
            $copy=$fixture|ConvertTo-Json -Depth 100|ConvertFrom-Json
            $copy.report.environment_records[5].arrival_receipt.independent_projection_fingerprint='0'.PadLeft(64,'0')
            $mutatedRaw=$copy.report|ConvertTo-Json -Compress -Depth 100
            $mutated=@(Get-AuditSemanticIssues $copy.report $copy.attempt_id 1 6 5 $copy.expectation $copy.combo $mutatedRaw)
            Assert-LauncherContract ($mutated.Count-gt0-and(($mutated-join"`n").Contains('arrival projection fingerprints'))) 'inactive sentinel mutation was accepted by the full production-shaped semantic contract'
        }
        Add-SelfTestResult $cases 'private-turn-traitor-rigged-ticket-field-scan' { foreach($key in @('turn_index','truth_trace','traitor_grievance','local_state','rigged_draw','unrevealed_ticket','traitor_id','ticket_sleeve')){Assert-LauncherContract (Test-PrivateEvidenceLeak ('{"'+$key+'":"secret"}')) "private key leak missed: $key"};Assert-LauncherContract (-not(Test-PrivateEvidenceLeak '{"private_state_evidence_policy":"digest_only","turn_index_count":2,"local_state_digest":"abc","prize_count":2}')) 'safe digest/count rejected' }
        Add-SelfTestResult $cases 'diagnostics-log-only-warning-leak-orphan-rid' { $d=@(Get-StrictDiagnosticLines "---stdout.log---`nWARNING: log only`n---stderr.log---`nObjectDB instances still alive`n---godot.log---`norphan node`nRID allocations: 1`nStringName: 1 unclaimed string name at exit.`nStringName: 7 unclaimed string names at exit.");Assert-LauncherContract ($d.Count -ge 6) 'strict diagnostic scan missed a class';Assert-LauncherContract (@($d|Where-Object{$_-ceq'StringName: 1 unclaimed string name at exit.'}).Count-eq1) 'unprefixed singular StringName leak was missed';Assert-LauncherContract (@($d|Where-Object{$_-ceq'StringName: 7 unclaimed string names at exit.'}).Count-eq1) 'unprefixed plural StringName leak was missed' }
        Add-SelfTestResult $cases 'qualifying-predicate-and-product-red-diagnostics-exactly-report-bound' { $report=[pscustomobject]@{native_diagnostics_clean=$true;native_diagnostics=(New-ZeroNativeDiagnostics 6);warnings_clean=$true;tool_warning_count=0;warning_count=0;warnings=[object[]]@();tool_failure_count=1;failure_count=1;failures=[object[]]@('known product failure');passed=$false;requested_visits_satisfied=$true;crew_state_unchanged=$true;attempt_id_valid=$true;visits_per_run_target=6;travels_per_run_target=5};$phase=[pscustomobject]@{native_exit_code=1;diagnostics=[object[]]@('ERROR: known product failure')};Assert-LauncherContract (@(Get-ProductPhaseBindingIssues $phase $report).Count-eq0) 'report-bound product red rejected';$phase.native_exit_code=0;$report.passed=$true;Assert-LauncherContract (@(Get-ProductPhaseBindingIssues $phase $report).Count-gt0) 'exit zero with public failure accepted';$report.failures=[object[]]@();$report.tool_failure_count=0;$report.failure_count=0;$report.passed=$true;$phase.diagnostics=[object[]]@();Assert-LauncherContract (@(Get-ProductPhaseBindingIssues $phase $report).Count-eq0) 'valid qualifying success rejected';$report.requested_visits_satisfied=$false;Assert-LauncherContract (@(Get-ProductPhaseBindingIssues $phase $report).Count-gt0) 'exit zero with unsatisfied evidence accepted';$report.requested_visits_satisfied=$true;$report.native_diagnostics|Add-Member -NotePropertyName extra_count -NotePropertyValue 0;Assert-LauncherContract (@(Get-ProductPhaseBindingIssues $phase $report).Count-gt0) 'native diagnostic schema extension accepted';$report.native_diagnostics.PSObject.Properties.Remove('extra_count');$report.warnings=[object[]]@('warn');$report.tool_warning_count=1;$report.warning_count=1;$report.warnings_clean=$false;$report.passed=$false;$phase.native_exit_code=1;$phase.diagnostics=[object[]]@();Assert-LauncherContract (@(Get-ProductPhaseBindingIssues $phase $report).Count-gt0) 'warning accepted as product red' }
        Add-SelfTestResult $cases 'native-diagnostic-fixed-schema-types-and-derived-totals' { $native=New-ZeroNativeDiagnostics 6;Assert-LauncherContract (@(Get-NativeDiagnosticSchemaIssues $native 6).Count-eq0) 'valid native diagnostic object rejected';$bad=($native|ConvertTo-Json|ConvertFrom-Json);$bad.receipt_invalid_count='0';Assert-LauncherContract (@(Get-NativeDiagnosticSchemaIssues $bad 6).Count-gt0) 'string diagnostic counter accepted';$bad=($native|ConvertTo-Json|ConvertFrom-Json);$bad.receipt_invalid_count=1;$bad.failure_count=0;$bad.clean=$true;Assert-LauncherContract (@(Get-NativeDiagnosticSchemaIssues $bad 6).Count-gt0) 'contradictory diagnostic totals accepted';$bad=($native|ConvertTo-Json|ConvertFrom-Json);$bad.finalization_warning_count=1;$bad.warning_count=0;Assert-LauncherContract (@(Get-NativeDiagnosticSchemaIssues $bad 6).Count-gt0) 'contradictory warning total accepted';$bad=($native|ConvertTo-Json|ConvertFrom-Json);$bad.PSObject.Properties.Remove('attempt_binding_invalid_count');Assert-LauncherContract (@(Get-NativeDiagnosticSchemaIssues $bad 6).Count-gt0) 'missing diagnostic field accepted' }
        Add-SelfTestResult $cases 'envelope-collection-object-types-and-incomplete-product-matrix' { $r=[pscustomobject][ordered]@{tool='environment_generation_audit';evidence_schema_version=2;generated_at_unix=[decimal]1.25;attempt_id='attempt';attempt_id_required=$true;attempt_id_valid=$true;run_count=1;visits_per_run_target=6;travels_per_run_target=5;seed_prefix='';exact_seed_requested=$true;requested_seed_text='seed';requested_total_visit_count=6;requested_total_travel_count=5;installed_finalized_visit_count=5;successful_linked_travel_count=4;requested_visits_satisfied=$false;crew_state_unchanged=$true;private_state_evidence_policy='digest_only';native_diagnostics_clean=$true;native_diagnostics=[pscustomobject]@{};tool_failure_count=1;tool_warning_count=0;warnings_clean=$true;passed=$false;failure_count=1;warning_count=0;method=[object[]]@();aggregate=[pscustomobject]@{};runs=[object[]]@([pscustomobject]@{});environment_records=[object[]]@(1,2,3,4,5);travel_records=[object[]]@(1,2,3,4);failures=[object[]]@('short run');warnings=[object[]]@()};Assert-LauncherContract (@(Get-AuditEnvelopeIssues $r 'attempt' 1 6 5 -CustodyOnly).Count-eq0) 'short product matrix treated as custody invalid';Assert-LauncherContract (@(Get-AuditEnvelopeIssues $r 'attempt' 1 6 5).Count-gt0) 'short product matrix was not rejected for qualification';foreach($field in @('runs','environment_records','travel_records','failures','warnings','method')){$copy=($r|ConvertTo-Json -Depth 10|ConvertFrom-Json);$copy.$field=[pscustomobject]@{not='array'};Assert-LauncherContract (@(Get-AuditEnvelopeIssues $copy 'attempt' 1 6 5 -CustodyOnly).Count-gt0) "non-array $field accepted"};foreach($field in @('aggregate','native_diagnostics')){$copy=($r|ConvertTo-Json -Depth 10|ConvertFrom-Json);$copy.$field=[object[]]@();Assert-LauncherContract (@(Get-AuditEnvelopeIssues $copy 'attempt' 1 6 5 -CustodyOnly).Count-gt0) "non-object $field accepted"};foreach($field in @('tool','attempt_id','private_state_evidence_policy','requested_seed_text','seed_prefix')){$copy=($r|ConvertTo-Json -Depth 10|ConvertFrom-Json);$copy.$field=[object[]]@([string]$copy.$field);Assert-LauncherContract (@(Get-AuditEnvelopeIssues $copy 'attempt' 1 6 5 -CustodyOnly).Count-gt0) "one-element string array accepted for envelope $field"} }
        Add-SelfTestResult $cases 'native-exit-strict-types' { $bad=$false;try{[void](Get-StrictNativeExitCode $null)}catch{$bad=$true};Assert-LauncherContract $bad 'null native exit accepted';$bad=$false;try{[void](Get-StrictNativeExitCode '0')}catch{$bad=$true};Assert-LauncherContract $bad 'string native exit accepted' }
        Add-SelfTestResult $cases 'lineage-reused-intermediate-negative-and-exact-cim-ticks' { Assert-LauncherContract (Test-CimCreationMatchesProcessStartTicks 150 159) 'microsecond match rejected';Assert-LauncherContract (-not(Test-CimCreationMatchesProcessStartTicks 1000000 1099999)) '99,999 tick reuse accepted';$root=[ordered]@{pid=1;name='root';start_ticks=[long]100;key='1|100|root'};$intermediate=[ordered]@{pid=2;name='intermediate';start_ticks=[long]150;key='2|150|intermediate'};$reusedIntermediate=[ordered]@{pid=2;name='reused-intermediate';start_ticks=[long]200;key='2|200|reused-intermediate'};$leaf=[ordered]@{pid=3;name='leaf';start_ticks=[long]210;key='3|210|leaf'};$c=@([ordered]@{parent_pid=1;parent_identity=$root;creation_ticks=[long]150;identity=$intermediate},[ordered]@{parent_pid=2;parent_identity=$reusedIntermediate;creation_ticks=[long]210;identity=$leaf});$v=@(Resolve-VerifiedDescendantIdentityRecords $root 300 @() $c);Assert-LauncherContract ($v.Count -eq 1 -and [string]$v[0].key -ceq [string]$intermediate.key -and @($v|Where-Object{[string]$_.key-ceq[string]$leaf.key}).Count-eq0) 'leaf beneath a reused intermediate PID was accepted' }
        Add-SelfTestResult $cases 'lease-create-write-removal-failure-contention-and-replacement' {
            $p=Join-Path $tempRoot 'probe.lease';$failed=$false
            $pinnedSibling=Join-Path $tempRoot 'pinned-sibling.txt';[IO.File]::WriteAllText($pinnedSibling,'held',[Text.UTF8Encoding]::new($false));$pinnedSiblingIdentity=Get-Q009FileSystemEntryIdentity $pinnedSibling;$pinnedSiblingStream=$null
            try{$pinnedSiblingStream=[IO.FileStream]::new($pinnedSibling,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read);$pinnedPublish=Join-Path $tempRoot 'pinned-parent-publish.txt';$pinnedPublishOwnership=[ordered]@{created=$false;identity=$null;write_complete=$false;removal_failed=$false;removal_error=''};New-OwnedLeaseFile $pinnedPublish 'published beside held sibling' $pinnedPublishOwnership;Assert-LauncherContract ([bool]$pinnedPublishOwnership.write_complete-and(Test-Q009FileSystemIdentityMatch $pinnedPublishOwnership.identity)) 'atomic child publication conflicted with a legitimate held sibling read pin';Remove-Q009ExactOwnedFile $pinnedPublish $pinnedPublishOwnership.identity}finally{if($null-ne$pinnedSiblingStream){$pinnedSiblingStream.Dispose()};if(Test-Q009FileSystemIdentityMatch $pinnedSiblingIdentity){Remove-Q009ExactOwnedFile $pinnedSibling $pinnedSiblingIdentity}}
            $heldParent=Join-Path $tempRoot 'held-report-parent';$heldParentCell=New-Q009CacheCustodyCell 'held-report-parent';$heldParentReceipt=New-Q009ExactOwnedDirectoryHeld -Path $heldParent -CustodyCell $heldParentCell -Slot parent_creation;$heldParentRead=Convert-Q009HeldDirectoryToReadOnly $heldParentCell parent_creation parent_runtime $heldParentReceipt.identity 'Self-test report-parent transition';$heldChild=Join-Path $heldParent 'report.json';$heldChildOwnership=[ordered]@{created=$false;identity=$null;write_complete=$false;removal_failed=$false;removal_error=''};New-OwnedLeaseFile $heldChild '{}' $heldChildOwnership;Assert-LauncherContract ([bool]$heldParentRead.continuous_custody-and[bool]$heldChildOwnership.write_complete) 'atomic child publication conflicted with continuously held read-only parent custody';Remove-Q009ExactOwnedFile $heldChild $heldChildOwnership.identity;$heldParentRelease=Close-Q009AllOpenNativeHandles $heldParentCell 'Self-test report-parent release';Assert-LauncherContract ([bool]$heldParentRelease.all_terminal-and@($heldParentRelease.errors).Count-eq0) 'read-only report-parent custody did not release cleanly'
            $leaseShape=[ordered]@{created=[bool]$false;validated=[bool]$false;path=[string]$p;identity=$null;write_complete=[bool]$false;removal_failed=[bool]$false;removal_error=[string]''};Assert-LauncherContract (Test-ExclusiveLeaseOwnershipShape $leaseShape $false $p) 'valid empty lease ownership receipt was rejected';$badLeaseShape=[ordered]@{};foreach($key in $leaseShape.Keys){$badLeaseShape[$key]=$leaseShape[$key]};$badLeaseShape.created=@($false);Assert-LauncherContract (-not(Test-ExclusiveLeaseOwnershipShape $badLeaseShape $false $p)) 'lease ownership validator accepted an array-coerced created flag'
            try{New-OwnedLeaseFile $p 'pid=1' -ForceWriteFailureForTest}catch{$failed=$true}
            Assert-LauncherContract ($failed-and-not(Test-Path $p)) 'removable partial lease survived'
            $partial=[ordered]@{created=$false;validated=$false;path='';identity=$null;write_complete=$false;removal_failed=$false;removal_error=''};$failed=$false
            try{New-OwnedLeaseFile -Path $p -Text 'pid=partial' -Ownership $partial -ForceWriteFailureForTest -ForceRemovalFailureForTest}catch{$failed=$true}
            Assert-LauncherContract ($failed-and[bool]$partial.created-and-not[bool]$partial.write_complete-and[bool]$partial.removal_failed-and(Test-Q009FileSystemIdentityMatch $partial.identity)) 'write+removal failure lost exact partial lease ownership'
            Remove-Q009ExactOwnedFile $p $partial.identity;$partial.created=$false;$partial.identity=$null
            $existing=[ordered]@{created=$false;identity=$null;write_complete=$false;removal_failed=$false;removal_error=''};New-OwnedLeaseFile $p 'pid=1' $existing
            $contended=$false;try{New-OwnedLeaseFile $p 'pid=2'}catch{$contended=$true};Assert-LauncherContract $contended 'CreateNew contention accepted';Remove-Q009ExactOwnedFile $p $existing.identity
            $tracker=[ordered]@{created=$false;validated=$false;path=$p;identity=$null;write_complete=$false;removal_failed=$false;removal_error=''};$downstreamFailed=$false
            try{New-TrackedExclusiveLeaseFile $p 'pid=3' $tracker;throw 'forced post-create validation/mutex failure'}catch{$downstreamFailed=$true}
            Assert-LauncherContract ($downstreamFailed-and[bool]$tracker.created-and[bool]$tracker.write_complete-and(Test-Q009FileSystemIdentityMatch $tracker.identity)) 'post-CreateNew failure lost exact lease ownership';Remove-Q009ExactOwnedFile $p $tracker.identity;$tracker.created=$false;$tracker.identity=$null
            $replacement=[ordered]@{created=$false;identity=$null;write_complete=$false;removal_failed=$false;removal_error=''};$replacementRejected=$false
            try{New-OwnedLeaseFile -Path $p -Text 'partial' -Ownership $replacement -ForceWriteFailureForTest -ForceReplacementBeforeRemovalForTest}catch{$replacementRejected=$true}
            Assert-LauncherContract ($replacementRejected-and(Test-Path -LiteralPath $p -PathType Leaf)-and[IO.File]::ReadAllText($p)-ceq'foreign replacement'-and-not(Test-Q009FileSystemIdentityMatch $replacement.identity)) 'partial-lease replacement was deleted or accepted as owned'
            $foreignIdentity=Get-Q009FileSystemEntryIdentity $p;Remove-Q009ExactOwnedFile $p $foreignIdentity
            $saved=[string]$replacement.test_original_path;Assert-LauncherContract (Test-Path -LiteralPath $saved -PathType Leaf) 'exact original partial lease was not retained after replacement hostile'
            $savedIdentity=Copy-Q009FileSystemIdentityToPath $replacement.identity $saved;Remove-Q009ExactOwnedFile $saved $savedIdentity
            $heldPath=Join-Path $selfTestLeaseRoot 'EXCLUSIVE.lease';$heldFailed=$false
            try{[void](New-Q009HeldExclusiveLease -Path $heldPath -Text 'mode=exclusive' -RunContext $selfTestRunContext -ForcePostCreateFailureForTest -ForceReplacementAttemptBeforeRollbackForTest)}catch{$heldFailed=$true}
            Assert-LauncherContract ($heldFailed-and-not(Test-Path -LiteralPath $heldPath)) 'held EXCLUSIVE post-create failure did not use exact delete-pending rollback'
            $foreignHeld=[ordered]@{created=$false;identity=$null;write_complete=$false;removal_failed=$false;removal_error=''};New-OwnedLeaseFile $heldPath 'foreign exclusive' $foreignHeld;$heldCollision=$false
            try{[void](New-Q009HeldExclusiveLease -Path $heldPath -Text 'mode=exclusive' -RunContext $selfTestRunContext)}catch{$heldCollision=$true}
            Assert-LauncherContract ($heldCollision-and(Test-Q009FileSystemIdentityMatch $foreignHeld.identity)-and[IO.File]::ReadAllText($heldPath)-ceq'foreign exclusive') 'held EXCLUSIVE CreateNew collision deleted or adopted a foreign reservation'
            Remove-Q009ExactOwnedFile $heldPath $foreignHeld.identity
            $terminalHeld=New-Q009HeldExclusiveLease -Path $heldPath -Text 'mode=exclusive' -RunContext $selfTestRunContext;$terminalReplacementRejected=$false
            try{[void](Close-Q009HeldExclusiveLease $terminalHeld $selfTestRunContext -ForceReplacementAfterFileCloseForTest)}catch{$terminalReplacementRejected=$true}
            Assert-LauncherContract ($terminalReplacementRejected-and(Test-Path -LiteralPath $heldPath -PathType Leaf)-and[IO.File]::ReadAllText($heldPath)-ceq'foreign replacement after exact lease close'-and-not[bool]$terminalHeld.released) 'terminal EXCLUSIVE close deleted/adopted a post-close foreign replacement or reported release'
            $terminalRelease=Close-Q009AllOpenNativeHandles $terminalHeld.custody_cell 'Terminal replacement hostile parent release';Assert-LauncherContract ([bool]$terminalRelease.all_terminal-and@($terminalRelease.errors).Count-eq0) 'terminal EXCLUSIVE replacement hostile retained native parent custody'
            $terminalForeignIdentity=Get-Q009FileSystemEntryIdentity $heldPath;Remove-Q009ExactOwnedFile $heldPath $terminalForeignIdentity
            $releaseHeld=New-Q009HeldExclusiveLease -Path $heldPath -Text 'mode=exclusive' -RunContext $selfTestRunContext;$releaseHeldReceipt=$releaseHeld.receipt
            $releaseCustody=[ordered]@{start_observed=[bool]$false;start_count=[int]0;cleanup_count=[int]0;cleanup_proved=[bool]$true};$releaseProcess=Get-FinalOwnedProcessResidualEvidence @() $releaseCustody $selfTestRunContext
            $releaseProfileAbsence=Assert-Q009PathAbsentStrict (Join-Path $tempRoot 'release-shape-profile');$releaseCacheAbsence=Assert-Q009PathAbsentStrict (Join-Path $tempRoot 'release-shape-cache')
            $terminalPinned=[ordered]@{};$terminalPinReceipts=[ordered]@{};$terminalPinReleases=[ordered]@{}
            $prePublicationShape=[ordered]@{proved=[bool]$true;observed_utc=[string][DateTime]::UtcNow.ToString('o');count=[int]0;identity_records=[object[]]@();other_lease_count=[int]0;under_mutex=[bool]$true;strict_zero_required=[bool]$true;process_custody=$releaseProcess;profile_absence=$releaseProfileAbsence;cache_absence=$releaseCacheAbsence;dependency_pins_held=[bool]$true;dependency_pin_receipts=$terminalPinReceipts;exclusive_held=[bool]$true;exclusive_receipt_sha256=[string]$releaseHeldReceipt.receipt_sha256;run_context_sha256=[string]$selfTestRunContext.context_sha256}
            Assert-LauncherContract (Test-Q009PrePublicationCustodyShape $prePublicationShape $selfTestRunContext $releaseHeldReceipt) 'valid pre-publication EXCLUSIVE custody was rejected'
            foreach($mutation in @('bool-array','int-string','pins-false','held-false','receipt-drift','extra-key','missing-key','wrong-order')){
                $copy=[ordered]@{};foreach($key in $prePublicationShape.Keys){$copy[$key]=$prePublicationShape[$key]}
                switch($mutation){
                    'bool-array'{$copy.proved=[object[]]@($true)}
                    'int-string'{$copy.count=[string]$copy.count}
                    'pins-false'{$copy.dependency_pins_held=[bool]$false}
                    'held-false'{$copy.exclusive_held=[bool]$false}
                    'receipt-drift'{$copy.exclusive_receipt_sha256='0'*64}
                    'extra-key'{$copy.unexpected=$true}
                    'missing-key'{$copy.Remove('run_context_sha256')}
                    'wrong-order'{$reordered=[ordered]@{observed_utc=[string]$copy.observed_utc;proved=[bool]$copy.proved};foreach($key in @($copy.Keys|Where-Object{$_-notin@('observed_utc','proved')})){$reordered[$key]=$copy[$key]};$copy=$reordered}
                }
                Assert-LauncherContract (-not(Test-Q009PrePublicationCustodyShape $copy $selfTestRunContext $releaseHeldReceipt)) "pre-publication custody accepted $mutation"
            }
            $terminalEvidencePath=Join-Path $tempRoot 'terminal-owner-evidence';$terminalEvidenceOwnership=New-AtomicOwnedEvidenceRoot $terminalEvidencePath $tempRoot 'owner=terminal-owner-selftest' $selfTestRunContext.attempt_id
            $terminalProfilePath=Join-Path $tempRoot 'terminal-owner-profile';$terminalProfileIdentity=New-Q009ExactOwnedDirectory $terminalProfilePath
            $terminalProfileOwner=[ordered]@{run_context_sha256=[string]$selfTestRunContext.context_sha256;root_identity=$terminalProfileIdentity;case_name='terminal-owner-profile'}
            $terminalProfileChain=New-Q009OwnedChildManifestChainHead $terminalProfilePath $terminalProfileIdentity $selfTestRunContext.attempt_id 'profile_terminal_after_process_quiescence' launcher_fixture $terminalProfileOwner
            $terminalCachePath=Join-Path $tempRoot 'terminal-owner-cache';$terminalCacheIdentity=New-Q009ExactOwnedDirectory $terminalCachePath
            $terminalCacheOwner=[ordered]@{run_context_sha256=[string]$selfTestRunContext.context_sha256;root_identity=$terminalCacheIdentity;case_name='terminal-owner-cache'}
            $terminalCacheChain=New-Q009OwnedChildManifestChainHead $terminalCachePath $terminalCacheIdentity $selfTestRunContext.attempt_id 'cache_terminal_after_process_quiescence' launcher_fixture $terminalCacheOwner
            $terminalQuiescence=[ordered]@{proved=[bool]$true;observed_utc=[string][DateTime]::UtcNow.ToString('o');godot_count=[int]0;godot_identities=[object[]]@();other_lease_count=[int]0;under_mutex=[bool]$true}
            $terminalOwner=[ordered]@{
                schema_version=[int]1;attempt_id=[string]$selfTestRunContext.attempt_id;qualifying_safe=[bool]$true;outcome=[string]'pass';exit_code=[int]0
                run_context_sha256=[string]$selfTestRunContext.context_sha256;candidate_commit=[string]$selfTestRunContext.candidate_commit;candidate_tree=[string]$selfTestRunContext.candidate_tree
                final_process_evidence=$releaseProcess;pre_cleanup_quiescence=$terminalQuiescence;pre_publication_custody=$prePublicationShape;exclusive_held_receipt_sha256=[string]$releaseHeldReceipt.receipt_sha256
                profile_manifest_chain=$terminalProfileChain;cache_manifest_chain=$terminalCacheChain;evidence_root_identity=$terminalEvidenceOwnership.root_identity;owner_claim_identity=$terminalEvidenceOwnership.claim_identity;owner_claim_sha256=[string]$terminalEvidenceOwnership.claim_sha256
                cleanup_succeeded=[bool]$true;provenance_valid=[bool]$true
            }
            Assert-LauncherContract (Test-Q009EvidenceTerminalOwnerReceiptShape $terminalOwner $selfTestRunContext $terminalEvidenceOwnership $releaseHeldReceipt) 'valid terminal evidence-owner receipt was rejected'
            foreach($mutation in @('safe-bool-array','exit-int-string','outcome-exit-contradiction','extra-key','missing-key','wrong-order')){
                $copy=[ordered]@{};foreach($key in $terminalOwner.Keys){$copy[$key]=$terminalOwner[$key]}
                switch($mutation){
                    'safe-bool-array'{$copy.qualifying_safe=[object[]]@($true)}
                    'exit-int-string'{$copy.exit_code=[string]$copy.exit_code}
                    'outcome-exit-contradiction'{$copy.exit_code=[int]1}
                    'extra-key'{$copy.unexpected=$true}
                    'missing-key'{$copy.Remove('run_context_sha256')}
                    'wrong-order'{$reordered=[ordered]@{attempt_id=[string]$copy.attempt_id;schema_version=[int]$copy.schema_version};foreach($key in @($copy.Keys|Where-Object{$_-notin@('attempt_id','schema_version')})){$reordered[$key]=$copy[$key]};$copy=$reordered}
                }
                Assert-LauncherContract (-not(Test-Q009EvidenceTerminalOwnerReceiptShape $copy $selfTestRunContext $terminalEvidenceOwnership $releaseHeldReceipt)) "terminal evidence-owner receipt accepted $mutation"
            }
            $terminalEvidenceChain=New-Q009OwnedChildManifestChainHead $terminalEvidencePath $terminalEvidenceOwnership.root_identity $selfTestRunContext.attempt_id 'evidence_terminal_before_summary' evidence_owner $terminalOwner $terminalEvidenceOwnership.owned_child_chain_head
            $selfSummaryPath=Join-Path $terminalEvidencePath 'summary.json';$selfSummarySha=Join-Path $terminalEvidencePath 'summary.sha256'
            $selfSummaryPublication=Publish-SummaryPairNoOverwrite $terminalEvidencePath $selfSummaryPath $selfSummarySha ([ordered]@{passed=$false;workload_passed=$true;terminal_release_required=$true}) $terminalEvidenceChain $selfTestRunContext.attempt_id -ArtifactName 'summary.json'
            Assert-LauncherContract (Test-Q009SummaryPublicationReceiptShape $selfSummaryPublication) 'summary publication under held EXCLUSIVE failed its exact receipt'
            [void](Assert-Q009HeldExclusiveLease $releaseHeld $selfTestRunContext)
            $postSummaryChain=New-Q009OwnedChildManifestChainHead $terminalEvidencePath $terminalEvidenceOwnership.root_identity $selfTestRunContext.attempt_id 'summary_published_under_exclusive' evidence_owner $selfSummaryPublication $terminalEvidenceChain
            $releaseClose=Close-Q009HeldExclusiveLease $releaseHeld $selfTestRunContext
            $releaseShape=[ordered]@{proved=[bool]$true;observed_utc=[string][DateTime]::UtcNow.ToString('o');count=[int]0;identity_records=[object[]]@();other_lease_count=[int]0;under_mutex=[bool]$true;strict_zero_required=[bool]$true;process_custody=$releaseProcess;profile_absence=$releaseProfileAbsence;cache_absence=$releaseCacheAbsence;dependency_pin_releases=$terminalPinReleases;exclusive_release=$releaseClose;run_context_sha256=[string]$selfTestRunContext.context_sha256}
            Assert-LauncherContract (Test-Q009ReleaseEvidenceShape $releaseShape $selfTestRunContext $releaseHeldReceipt) 'valid exact post-summary EXCLUSIVE release evidence was rejected'
            foreach($mutation in @('bool-array','int-string','pins-null','extra-key','missing-key','wrong-order')){
                $copy=[ordered]@{};foreach($key in $releaseShape.Keys){$copy[$key]=$releaseShape[$key]}
                switch($mutation){'bool-array'{$copy.proved=[object[]]@($true)}'int-string'{$copy.count=[string]$copy.count}'pins-null'{$copy.dependency_pin_releases=$null}'extra-key'{$copy.unexpected=$true}'missing-key'{$copy.Remove('run_context_sha256')}'wrong-order'{$reordered=[ordered]@{observed_utc=[string]$copy.observed_utc;proved=[bool]$copy.proved};foreach($key in @($copy.Keys|Where-Object{$_-notin@('observed_utc','proved')})){$reordered[$key]=$copy[$key]};$copy=$reordered}}
                Assert-LauncherContract (-not(Test-Q009ReleaseEvidenceShape $copy $selfTestRunContext $releaseHeldReceipt)) "release evidence accepted $mutation"
            }
            $terminalCompletion=[ordered]@{schema_version=[int]1;attempt_id=[string]$selfTestRunContext.attempt_id;qualifying_pass=[bool]$true;outcome='pass';exit_code=[int]0;run_context_sha256=[string]$selfTestRunContext.context_sha256;summary_publication=$selfSummaryPublication;summary_published_under_exclusive=[bool]$true;terminal_release=$releaseShape;completed_utc=[DateTime]::UtcNow.ToString('o')}
            Assert-LauncherContract (Test-Q009TerminalCompletionReceiptShape $terminalCompletion $selfTestRunContext $releaseHeldReceipt $selfSummaryPublication) 'valid terminal completion receipt was rejected'
            foreach($mutation in @('pass-array','published-false','summary-drift','release-null','extra-key','missing-key','wrong-order')){
                $copy=[ordered]@{};foreach($key in $terminalCompletion.Keys){$copy[$key]=$terminalCompletion[$key]}
                switch($mutation){'pass-array'{$copy.qualifying_pass=[object[]]@($true)}'published-false'{$copy.summary_published_under_exclusive=[bool]$false}'summary-drift'{$copy.summary_publication=($selfSummaryPublication|ConvertTo-Json -Depth 20|ConvertFrom-Json);$copy.summary_publication.sha256='0'*64}'release-null'{$copy.terminal_release=$null}'extra-key'{$copy.unexpected=$true}'missing-key'{$copy.Remove('run_context_sha256')}'wrong-order'{$reordered=[ordered]@{attempt_id=[string]$copy.attempt_id;schema_version=[int]$copy.schema_version};foreach($key in @($copy.Keys|Where-Object{$_-notin@('attempt_id','schema_version')})){$reordered[$key]=$copy[$key]};$copy=$reordered}}
                Assert-LauncherContract (-not(Test-Q009TerminalCompletionReceiptShape $copy $selfTestRunContext $releaseHeldReceipt $selfSummaryPublication)) "terminal completion receipt accepted $mutation"
            }
            $selfTerminalPath=Join-Path $terminalEvidencePath 'terminal.json';$selfTerminalSha=Join-Path $terminalEvidencePath 'terminal.sha256';$selfTerminalPublication=Publish-SummaryPairNoOverwrite $terminalEvidencePath $selfTerminalPath $selfTerminalSha $terminalCompletion $postSummaryChain $selfTestRunContext.attempt_id -ArtifactName 'terminal.json'
            $selfFinalManifest=Get-Q009ExactOwnedTreeManifest $terminalEvidencePath
            Assert-LauncherContract ((Test-Q009SummaryPublicationReceiptShape $selfTerminalPublication)-and(Test-Q009ExactOwnedTreeManifestShape $selfFinalManifest $terminalEvidenceOwnership.root_identity)-and(Test-Q009TerminalTreeDelta $postSummaryChain.manifest $selfFinalManifest $selfTerminalPublication)) 'terminal completion publication/final exact tree delta readback failed'
            $latePath=Join-Path $terminalEvidencePath 'foreign-after-terminal.txt';$lateOwnership=[ordered]@{created=$false;identity=$null;write_complete=$false;removal_failed=$false;removal_error=''};New-OwnedLeaseFile $latePath 'foreign' $lateOwnership
            Assert-LauncherContract (-not(Test-Q009TerminalTreeDelta $postSummaryChain.manifest (Get-Q009ExactOwnedTreeManifest $terminalEvidencePath) $selfTerminalPublication)) 'late foreign terminal-tree addition was accepted';Remove-Q009ExactOwnedFile $latePath $lateOwnership.identity
        }
        Add-SelfTestResult $cases 'exclusive-reservation-waits-for-focused-lease-or-godot' {
            Assert-LauncherContract ((Get-ExclusiveWaitDisposition 0 0 0)-ceq'ready') 'empty EXCLUSIVE census was not ready'
            Assert-LauncherContract ((Get-ExclusiveWaitDisposition 1 0 0)-ceq'wait') 'focused lease was not a wait state'
            Assert-LauncherContract ((Get-ExclusiveWaitDisposition 0 2 0)-ceq'wait') 'live Godot was not a wait state'
            Assert-LauncherContract ((Get-ExclusiveWaitDisposition 1 2 0)-ceq'wait') 'combined peer activity was not a wait state'
            Assert-LauncherContract ((Get-ExclusiveWaitDisposition 0 0 1)-ceq'invalid') 'malformed lease was not invalid'
            $leaseProbe=Join-Path $tempRoot 'lease-enumeration';[void][IO.Directory]::CreateDirectory($leaseProbe)
            $deadLeasePid=2147483000;$deadLeaseStart=[DateTime]::UtcNow.AddYears(-5);$deadLeaseName='dead-owner';$deadLeaseKey=('{0}|{1}|{2}'-f$deadLeasePid,$deadLeaseStart.Ticks,$deadLeaseName)
            [IO.File]::WriteAllText((Join-Path $leaseProbe ("focused-$deadLeasePid.lease")),("mode=focused`npid=$deadLeasePid`nlauncher_name=$deadLeaseName`nlauncher_start_utc=$($deadLeaseStart.ToString('o'))`nlauncher_start_ticks=$($deadLeaseStart.Ticks)`nlauncher_key=$deadLeaseKey`n"),[Text.UTF8Encoding]::new($false))
            Assert-LauncherContract (@(Get-StrictLeaseFilesAtPath $leaseProbe).Count-eq1) 'strict lease enumeration rejected a valid directory'
            $leaseProbeContext=New-Q009RunContext -AttemptId ($selfTestRunContext.attempt_id+'-lease-probe') -CandidateCommit $selfTestRunContext.candidate_commit -CandidateTree $selfTestRunContext.candidate_tree -LauncherIdentity $selfTestLauncherIdentity -CanonicalLeaseRoot $leaseProbe -WorkingDirectory $tempRoot -ProjectRoot $tempRoot -LaunchMutexName $selfTestRunContext.launch_mutex_name
            Assert-LauncherContract (@(Get-StrictSharedLeaseFiles -RunContext $leaseProbeContext).Count-eq1) 'shared support rejected an ordinary lease file'
            $directoryLease=Join-Path $leaseProbe 'directory.lease';[void][IO.Directory]::CreateDirectory($directoryLease)
            foreach($surface in @('supervisor','support')){
                $rejected=$false
                try{if($surface-ceq'supervisor'){[void](Get-StrictLeaseFilesAtPath $leaseProbe)}else{[void](Get-StrictSharedLeaseFiles -RunContext $leaseProbeContext)}}catch{$rejected=$true}
                Assert-LauncherContract $rejected "$surface lease enumeration accepted a directory named *.lease"
            }
            [IO.Directory]::Delete($directoryLease)
            $junctionTarget=Join-Path $tempRoot 'lease-junction-target';[void][IO.Directory]::CreateDirectory($junctionTarget)
            $junctionLease=Join-Path $leaseProbe 'junction.lease';[void](New-Item -ItemType Junction -Path $junctionLease -Target $junctionTarget -ErrorAction Stop)
            foreach($surface in @('supervisor','support')){
                $rejected=$false
                try{if($surface-ceq'supervisor'){[void](Get-StrictLeaseFilesAtPath $leaseProbe)}else{[void](Get-StrictSharedLeaseFiles -RunContext $leaseProbeContext)}}catch{$rejected=$true}
                Assert-LauncherContract $rejected "$surface lease enumeration accepted a junction named *.lease"
            }
            [IO.Directory]::Delete($junctionLease)
            $readyAccepted=$false;$releaseAccepted=$false;$launchAccepted=$false;$enumerationRejected=$false
            try{$count=@(Get-StrictLeaseFilesAtPath $leaseProbe -ForceEnumerationFailureForTest).Count;$readyAccepted=((Get-ExclusiveWaitDisposition $count 0 0)-ceq'ready');$releaseAccepted=Test-MayReleaseExclusiveReservation $true $true $true ([ordered]@{start_observed=$false;start_count=0;cleanup_count=0;cleanup_proved=$true});$launchAccepted=$true}catch{$enumerationRejected=$true}
            Assert-LauncherContract ($enumerationRejected-and-not$readyAccepted-and-not$releaseAccepted-and-not$launchAccepted) 'lease enumeration failure allowed readiness, release, or launch acceptance'
            $supportEnumerationRejected=$false;try{[void](Get-StrictSharedLeaseFiles -RunContext $leaseProbeContext -ForceEnumerationFailureForTest)}catch{$supportEnumerationRejected=$true}
            Assert-LauncherContract $supportEnumerationRejected 'support lease enumeration failure was not fail-closed'
            $liveOwner=Get-ProcessIdentityRecord (Get-ProcessByIdStrict -ProcessId $PID);$liveLease=Join-Path $leaseProbe ("live-$PID.lease");$liveLeaseText="mode=focused`npid=$PID`nlauncher_name=$($liveOwner.name)`nlauncher_start_utc=$($liveOwner.start_utc)`nlauncher_start_ticks=$($liveOwner.start_ticks)`nlauncher_key=$($liveOwner.key)`n";[IO.File]::WriteAllText($liveLease,$liveLeaseText,[Text.UTF8Encoding]::new($false))
            $validCimFixture=@([pscustomobject]@{ProcessId=0;ParentProcessId=0;Name='System Idle Process'},[pscustomobject]@{ProcessId=42;ParentProcessId=0;Name='fixture'})
            $strictCimTable=ConvertTo-Q009StrictCimAncestryTable $validCimFixture;Assert-LauncherContract ($strictCimTable.Count-eq1-and$strictCimTable.ContainsKey(42)-and-not$strictCimTable.ContainsKey(0)) 'unique legitimate System Idle PID 0 was not excluded exactly once'
            $badCimFixtures=[Collections.Generic.List[object]]::new();[void]$badCimFixtures.Add([object[]]@($validCimFixture[0],$validCimFixture[0],$validCimFixture[1]));[void]$badCimFixtures.Add([object[]]@([pscustomobject]@{ProcessId=0;ParentProcessId=1;Name='System Idle Process'},$validCimFixture[1]));[void]$badCimFixtures.Add([object[]]@($validCimFixture[0],[pscustomobject]@{ProcessId=-1;ParentProcessId=0;Name='invalid'}));[void]$badCimFixtures.Add([object[]]@($validCimFixture[0],$validCimFixture[1],$validCimFixture[1]))
            foreach($badCimFixture in $badCimFixtures){$rejected=$false;try{[void](ConvertTo-Q009StrictCimAncestryTable ([object[]]$badCimFixture))}catch{$rejected=$true};Assert-LauncherContract $rejected 'malformed/duplicate/nonpositive CIM ancestry fixture was accepted'}
            $liveRecord=Get-StrictLeaseOwnerRecord (Get-Item -LiteralPath $liveLease -Force);Assert-LauncherContract ((Test-LiveProcessMatchesIdentity $liveRecord.identity)-and(Test-ProcessHasLeaseAncestor -ProcessId $PID -LeaseOwnerIdentities @($liveRecord.identity))) 'exact live focused lease owner/ancestry was rejected'
            $rejected=$false;try{[void](Test-ProcessHasLeaseAncestor -ProcessId 0 -LeaseOwnerIdentities @($liveRecord.identity))}catch{$rejected=$true};Assert-LauncherContract $rejected 'nonpositive ancestry child PID was accepted'
            $invalidOwner=($liveRecord.identity|ConvertTo-Json|ConvertFrom-Json);$invalidOwner.pid=0;$invalidOwner.key=('0|{0}|{1}'-f[long]$invalidOwner.start_ticks,[string]$invalidOwner.name);$rejected=$false;try{[void](Test-ProcessHasLeaseAncestor -ProcessId $PID -LeaseOwnerIdentities @($invalidOwner))}catch{$rejected=$true};Assert-LauncherContract $rejected 'nonpositive focused lease owner identity was accepted'
            $reused=($liveRecord.identity|ConvertTo-Json|ConvertFrom-Json);$reused.start_ticks=[long]$reused.start_ticks+10;$reused.start_utc=([datetime]::new([long]$reused.start_ticks,[DateTimeKind]::Utc)).ToString('o');$reused.key=('{0}|{1}|{2}'-f$PID,[long]$reused.start_ticks,[string]$reused.name);$rejected=$false;try{[void](Test-ProcessHasLeaseAncestor -ProcessId $PID -LeaseOwnerIdentities @($reused))}catch{$rejected=$true};Assert-LauncherContract $rejected 'PID-reused focused lease owner was accepted as a live ancestor'
        }
        Add-SelfTestResult $cases 'process-cim-enumeration-failures-block-readiness-residual-and-release' { foreach($context in @('readiness','residual','pre_cleanup','release','postcheck')){$rejected=$false;try{[void](Get-StrictGodotIdentityCensus $context -ForceEnumerationFailureForTest)}catch{$rejected=$true};Assert-LauncherContract $rejected "Godot enumeration failure was accepted for $context"};$rootIdentity=Get-ProcessIdentityRecord (Get-ProcessByIdStrict -ProcessId $PID);$lineageRejected=$false;try{[void](Get-VerifiedDescendantProcessRecords $rootIdentity @() $null -ForceEnumerationFailureForTest)}catch{$lineageRejected=$true};Assert-LauncherContract $lineageRejected 'CIM lineage enumeration failure collapsed to an empty descendant set';$custody=[ordered]@{start_observed=$false;start_count=0;cleanup_count=0;cleanup_proved=$true};$phase=New-Q009ClosedPhaseFixture 'enumeration-hostile' Exact $selfTestRunContext $selfTestExecutableIdentity;$residualRejected=$false;try{[void](Get-FinalOwnedProcessResidualEvidence @($phase) $custody $selfTestRunContext -ForceEnumerationFailureForTest)}catch{$residualRejected=$true};Assert-LauncherContract $residualRejected 'final residual proof accepted a failed process census' }
        Add-SelfTestResult $cases 'import-cache-immediate-prelaunch-race-is-not-owned-or-deleted' { $candidate=Join-Path $tempRoot 'cache-race-candidate';[void][IO.Directory]::CreateDirectory($candidate);$cache=Join-Path $candidate '.godot';$cacheIdentity=New-Q009ExactOwnedDirectory $cache;$rejected=$false;try{[void](Assert-OwnedCacheAbsentImmediatelyBeforeImport $cache $candidate)}catch{$rejected=$true};Assert-LauncherContract ($rejected-and(Test-Path -LiteralPath $cache -PathType Container)) 'cache created during wait/prelaunch was accepted as owned or deleted';[void](Remove-ValidateOnlyOwnedTree $candidate $cache $cacheIdentity $selfTestRunContext $selfTestOwnerReceipt) }
        Add-SelfTestResult $cases 'cache-exclusive-creator-claim-not-lifetime-adoption' {
            $creatorIdentity=Get-ProcessIdentityRecord (Get-ProcessByIdStrict -ProcessId $PID)
            $capability=Invoke-Q009SentinelFilesystemCapabilityProbe $tempRoot 'selftest-capability' $tempParent;Assert-LauncherContract (Test-SentinelCapabilityReceiptShape $capability) 'same-volume sentinel capability probe did not prove sibling liveness plus every native ancestor denial with an exact receipt';$badCapability=[ordered]@{};foreach($key in $capability.Keys){$badCapability[$key]=$capability[$key]};$badCapability.proved=@($true);Assert-LauncherContract (-not(Test-SentinelCapabilityReceiptShape $badCapability)) 'capability validator accepted an array-coerced proved value'

            foreach($mode in @('after_acquire','after_proof')){
                $path=Join-Path $tempRoot ('root-'+$mode);$cell=New-Q009CacheCustodyCell ('root-'+$mode);$caught=$false
                try{[void](New-Q009ExactOwnedDirectoryHeld -Path $path -CustodyCell $cell -Slot root_creation -HostileMode $mode)}catch{$caught=$true}
                Assert-LauncherContract ($caught-and[string]$cell.StateOf('root_creation')-ceq'OPEN'-and(Test-Path -LiteralPath $path -PathType Container)) "root $mode failure lost native custody"
                $identity=Get-Q009FileSystemEntryIdentity $path;[void](Close-Q009AllOpenNativeHandles $cell "root $mode release");[void](Remove-ValidateOnlyOwnedTree $tempRoot $path $identity $selfTestRunContext $selfTestOwnerReceipt)
            }
            $sentinelRoot=Join-Path $tempRoot 'sentinel-proof-failure';$sentinelCell=New-Q009CacheCustodyCell 'sentinel-proof-failure';$sentinelRootReceipt=New-Q009ExactOwnedDirectoryHeld $sentinelRoot $sentinelCell root_creation;$sentinelCaught=$false
            try{[void](New-Q009ExactOwnedFileHeld (Join-Path $sentinelRoot '.pin') ([Text.Encoding]::UTF8.GetBytes('sentinel')) $sentinelCell root_creation sentinel $sentinelRootReceipt.identity after_proof)}catch{$sentinelCaught=$true}
            Assert-LauncherContract ($sentinelCaught-and[string]$sentinelCell.StateOf('sentinel')-ceq'OPEN') 'sentinel post-proof failure lost native custody';[void](Close-Q009AllOpenNativeHandles $sentinelCell 'sentinel proof failure release');[void](Remove-ValidateOnlyOwnedTree $tempRoot $sentinelRoot $sentinelRootReceipt.identity $selfTestRunContext $selfTestOwnerReceipt)

            $closeRoot=Join-Path $tempRoot 'close-state';$closeCell=New-Q009CacheCustodyCell 'close-state';$closeReceipt=New-Q009ExactOwnedDirectoryHeld $closeRoot $closeCell root_creation;Assert-LauncherContract (Test-Q009CacheRootReceiptShape $closeReceipt) 'valid root creation receipt was rejected';$badRootReceipt=[ordered]@{};foreach($key in $closeReceipt.Keys){$badRootReceipt[$key]=$closeReceipt[$key]};$badRootReceipt.creation_handle_retained=@($true);Assert-LauncherContract (-not(Test-Q009CacheRootReceiptShape $badRootReceipt)) 'root receipt validator accepted an array-coerced ownership flag';$beforeRejected=$false;try{[void](Close-Q009CheckedNativeHandle $closeCell root_creation 'before-close hostile' before)}catch{$beforeRejected=$true};Assert-LauncherContract ($beforeRejected-and[string]$closeCell.StateOf('root_creation')-ceq'CLOSE_FAILED_HANDLE_RETAINED'-and@($closeCell.OpenSlots()).Count-eq0-and@($closeCell.ClosableSlots()).Count-eq1) 'pre-native close failure did not preserve the positively live handle in CLOSE_FAILED_HANDLE_RETAINED';$beforeRecovery=Close-Q009CheckedNativeHandle $closeCell root_creation 'before-close recovery';Assert-LauncherContract ((Test-Q009CheckedCloseReceipt $beforeRecovery)-and[string]$closeCell.StateOf('root_creation')-ceq'CLOSED_NATIVE_SUCCESS') 'pre-native retained close did not recover through one checked native close';$badCloseReceipt=[ordered]@{};foreach($key in $beforeRecovery.Keys){$badCloseReceipt[$key]=$beforeRecovery[$key]};$badCloseReceipt.state=@('CLOSED_NATIVE_SUCCESS');Assert-LauncherContract (-not(Test-Q009CheckedCloseReceipt $badCloseReceipt)) 'checked-close validator accepted an array-coerced state';[void](Remove-ValidateOnlyOwnedTree $tempRoot $closeRoot $closeReceipt.identity $selfTestRunContext $selfTestOwnerReceipt)
            $afterRoot=Join-Path $tempRoot 'close-after-success';$afterCell=New-Q009CacheCustodyCell 'close-after-success';$afterReceipt=New-Q009ExactOwnedDirectoryHeld $afterRoot $afterCell root_creation;$afterRejected=$false;try{[void](Close-Q009CheckedNativeHandle $afterCell root_creation 'after-close hostile' after_success)}catch{$afterRejected=$true};Assert-LauncherContract ($afterRejected-and[string]$afterCell.StateOf('root_creation')-ceq'CLOSED_NATIVE_SUCCESS'-and@($afterCell.OpenSlots()).Count-eq0) 'success-but-reporting-failure did not retain terminal native-close truth';[void](Remove-ValidateOnlyOwnedTree $tempRoot $afterRoot $afterReceipt.identity $selfTestRunContext $selfTestOwnerReceipt)

            $teardownRoot=Join-Path $tempRoot 'mutex-teardown';$teardownCell=New-Q009CacheCustodyCell 'mutex-teardown';$teardownBox=[ordered]@{root=$null;sentinel=$null};$teardownCaught=$false
            try{[void](Invoke-Q009MutexCritical -RunContext $selfTestRunContext -MutexName ('Local\BeatTheHouse-Q009-cache-teardown-'+[guid]::NewGuid().ToString('N')) -ForceTeardownFailureForTest -Body {$teardownBox.root=New-Q009ExactOwnedDirectoryHeld $teardownRoot $teardownCell root_creation;$teardownBox.sentinel=New-Q009ExactOwnedFileHeld (Join-Path $teardownRoot '.pin') ([Text.Encoding]::UTF8.GetBytes('teardown')) $teardownCell root_creation sentinel $teardownBox.root.identity;[void](Close-Q009CheckedNativeHandle $teardownCell root_creation 'teardown handoff');return $true})}catch{$teardownCaught=$true}
            Assert-LauncherContract ($teardownCaught-and[string]$teardownCell.StateOf('root_creation')-ceq'CLOSED_NATIVE_SUCCESS'-and[string]$teardownCell.StateOf('sentinel')-ceq'OPEN'-and(Test-Q009FileSystemIdentityMatch $teardownBox.sentinel.identity)) 'mutex return/teardown failure lost the outer pre-registered sentinel custody';[void](Close-Q009AllOpenNativeHandles $teardownCell 'teardown failure release');[void](Remove-ValidateOnlyOwnedTree $tempRoot $teardownRoot $teardownBox.root.identity $selfTestRunContext $selfTestOwnerReceipt)

            $raceRoot=Join-Path $tempRoot 'manifest-race';$raceCell=New-Q009CacheCustodyCell 'manifest-race';$raceRootReceipt=New-Q009ExactOwnedDirectoryHeld $raceRoot $raceCell root_creation;$raceSentinel=New-Q009ExactOwnedFileHeld (Join-Path $raceRoot '.pin') ([Text.Encoding]::UTF8.GetBytes('race')) $raceCell root_creation sentinel $raceRootReceipt.identity;[void](Close-Q009CheckedNativeHandle $raceCell root_creation 'race handoff');[IO.File]::WriteAllText((Join-Path $raceRoot 'owned.txt'),'owned')
            $raceOwner=[ordered]@{run_context_sha256=[string]$selfTestRunContext.context_sha256;root_identity=$raceRootReceipt.identity;sentinel_identity=$raceSentinel.identity};$raceChain=New-Q009OwnedChildManifestChainHead -RootPath $raceRoot -RootIdentity $raceRootReceipt.identity -AttemptId $selfTestRunContext.attempt_id -Boundary 'manifest_race_terminal' -OwnerKind launcher_fixture -OwnerReceipt $raceOwner -HeldFileCustodyCell $raceCell -HeldFileSlot sentinel -HeldFileIdentity $raceSentinel.identity
            [IO.File]::WriteAllText((Join-Path $raceRoot 'injected.txt'),'foreign');$raceRejected=$false;try{[void](Remove-Q009ManifestChildrenExceptSentinel $raceRoot $raceRootReceipt.identity $raceSentinel.identity $raceChain $selfTestRunContext.attempt_id $raceCell)}catch{$raceRejected=$true};Assert-LauncherContract ($raceRejected-and(Test-Path -LiteralPath (Join-Path $raceRoot 'injected.txt') -PathType Leaf)) 'manifest addition race was accepted or foreign entry deleted';[void](Close-Q009AllOpenNativeHandles $raceCell 'manifest race release');[void](Remove-ValidateOnlyOwnedTree $tempRoot $raceRoot $raceRootReceipt.identity $selfTestRunContext $selfTestOwnerReceipt)

            $finalRootPath=Join-Path $tempRoot 'final-root-acquire';$finalCell=New-Q009CacheCustodyCell 'final-root-acquire';$finalRootReceipt=New-Q009ExactOwnedDirectoryHeld $finalRootPath $finalCell root_creation;$finalSentinel=New-Q009ExactOwnedFileHeld (Join-Path $finalRootPath '.pin') ([Text.Encoding]::UTF8.GetBytes('final')) $finalCell root_creation sentinel $finalRootReceipt.identity;Assert-LauncherContract (Test-Q009SentinelReceiptShape $finalSentinel) 'valid sentinel creation receipt was rejected';$badSentinel=[ordered]@{};foreach($key in $finalSentinel.Keys){$badSentinel[$key]=$finalSentinel[$key]};$badSentinel.payload_length=[string]$finalSentinel.payload_length;Assert-LauncherContract (-not(Test-Q009SentinelReceiptShape $badSentinel)) 'sentinel validator accepted a numeric string payload length';[void](Close-Q009CheckedNativeHandle $finalCell root_creation 'final hostile handoff');$finalManifest=Get-Q009ExactOwnedTreeManifest $finalRootPath $finalCell sentinel $finalSentinel.identity;Assert-LauncherContract (Test-Q009ExactOwnedTreeManifestShape $finalManifest $finalRootReceipt.identity) 'valid final manifest was rejected';$badManifest=[ordered]@{root_identity=$finalManifest.root_identity;entries='not-an-array';sha256=[string]$finalManifest.sha256};Assert-LauncherContract (-not(Test-Q009ExactOwnedTreeManifestShape $badManifest $finalRootReceipt.identity)) 'manifest validator accepted a scalar entry collection'
            $finalOwner=[ordered]@{run_context_sha256=[string]$selfTestRunContext.context_sha256;root_identity=$finalRootReceipt.identity;sentinel_identity=$finalSentinel.identity};$finalChain=New-Q009OwnedChildManifestChainHead -RootPath $finalRootPath -RootIdentity $finalRootReceipt.identity -AttemptId $selfTestRunContext.attempt_id -Boundary 'final_root_terminal' -OwnerKind launcher_fixture -OwnerReceipt $finalOwner -HeldFileCustodyCell $finalCell -HeldFileSlot sentinel -HeldFileIdentity $finalSentinel.identity
            $finalOrdinaryCleanup=Remove-Q009ManifestChildrenExceptSentinel $finalRootPath $finalRootReceipt.identity $finalSentinel.identity $finalChain $selfTestRunContext.attempt_id $finalCell;Assert-LauncherContract (Test-Q009ManifestCleanupReceiptShape $finalOrdinaryCleanup) 'valid ordinary-child cleanup receipt was rejected';$dispositionRejected=$false;try{[void](Set-Q009HeldHandleDeletePending $finalCell sentinel 'forced disposition' before)}catch{$dispositionRejected=$true};Assert-LauncherContract ($dispositionRejected-and-not[bool](Get-Q009HeldHandleState $finalCell sentinel).delete_pending) 'pre-disposition hostile changed sentinel state';$finalAcquireRejected=$false;try{[void](Open-Q009ExactDirectoryHeld $finalRootPath $finalRootReceipt.identity $finalCell final_root after_proof)}catch{$finalAcquireRejected=$true};Assert-LauncherContract ($finalAcquireRejected-and[string]$finalCell.StateOf('final_root')-ceq'OPEN') 'final-root post-acquire/proof failure lost native custody';$finalRootPublic=[ordered]@{path=$finalRootPath;identity=$finalRootReceipt.identity;handle_slot='final_root';handle_state=[string]$finalCell.StateOf('final_root');share_delete=[bool]$false;delete_access=[bool]$true};Assert-LauncherContract (Test-Q009FinalRootReceiptShape $finalRootPublic) 'valid final-root receipt was rejected';$finalSentinelState=Set-Q009HeldHandleDeletePending $finalCell sentinel 'final sentinel';Assert-LauncherContract (Test-Q009HeldHandleStateShape $finalSentinelState $finalSentinel.identity $false) 'valid held-sentinel disposition receipt was rejected';$badHeldState=[ordered]@{};foreach($key in $finalSentinelState.Keys){$badHeldState[$key]=$finalSentinelState[$key]};$badHeldState.handle_state='CLOSED_NATIVE_SUCCESS';Assert-LauncherContract (-not(Test-Q009HeldHandleStateShape $badHeldState $finalSentinel.identity $false)) 'held-handle validator accepted a non-OPEN state';[void](Close-Q009CheckedNativeHandle $finalCell sentinel 'final hostile sentinel close');[void](Set-Q009HeldHandleDeletePending $finalCell final_root 'final hostile root');[void](Close-Q009CheckedNativeHandle $finalCell final_root 'final hostile root close');$finalAbsence=Assert-Q009PathAbsentStrict $finalRootPath;Assert-LauncherContract (Test-Q009StrictAbsenceReceipt $finalAbsence) 'valid strict absence receipt was rejected';$badAbsence=[ordered]@{};foreach($key in $finalAbsence.Keys){$badAbsence[$key]=$finalAbsence[$key]};$badAbsence.proved=@($true);Assert-LauncherContract (-not(Test-Q009StrictAbsenceReceipt $badAbsence)) 'strict absence validator accepted an array-coerced proved value'
            $replacement=New-Q009ExactOwnedDirectory $finalRootPath;$postCloseRejected=$false;try{[void](Assert-Q009PathAbsentStrict $finalRootPath)}catch{$postCloseRejected=$true};Assert-LauncherContract ($postCloseRejected-and(Test-Q009FileSystemIdentityMatch $replacement)) 'post-root-close replacement was accepted or deleted';[void](Remove-ValidateOnlyOwnedTree $tempRoot $finalRootPath $replacement $selfTestRunContext $selfTestOwnerReceipt)
            $additionRoot=Join-Path $tempRoot 'sentinel-close-addition';$additionCell=New-Q009CacheCustodyCell 'sentinel-close-addition';$additionRootReceipt=New-Q009ExactOwnedDirectoryHeld $additionRoot $additionCell root_creation;$additionSentinel=New-Q009ExactOwnedFileHeld (Join-Path $additionRoot '.pin') ([Text.Encoding]::UTF8.GetBytes('addition')) $additionCell root_creation sentinel $additionRootReceipt.identity;[void](Close-Q009CheckedNativeHandle $additionCell root_creation 'addition handoff')
            $additionOwner=[ordered]@{run_context_sha256=[string]$selfTestRunContext.context_sha256;root_identity=$additionRootReceipt.identity;sentinel_identity=$additionSentinel.identity};$additionChain=New-Q009OwnedChildManifestChainHead -RootPath $additionRoot -RootIdentity $additionRootReceipt.identity -AttemptId $selfTestRunContext.attempt_id -Boundary 'addition_terminal' -OwnerKind launcher_fixture -OwnerReceipt $additionOwner -HeldFileCustodyCell $additionCell -HeldFileSlot sentinel -HeldFileIdentity $additionSentinel.identity
            [void](Remove-Q009ManifestChildrenExceptSentinel $additionRoot $additionRootReceipt.identity $additionSentinel.identity $additionChain $selfTestRunContext.attempt_id $additionCell);$additionFinalRoot=Open-Q009ExactDirectoryHeld $additionRoot $additionRootReceipt.identity $additionCell final_root;[void](Set-Q009HeldHandleDeletePending $additionCell sentinel 'addition sentinel');[void](Close-Q009CheckedNativeHandle $additionCell sentinel 'addition sentinel close');$lateChild=Join-Path $additionRoot 'foreign-after-sentinel-close.txt';[IO.File]::WriteAllText($lateChild,'foreign',[Text.UTF8Encoding]::new($false));$additionRejected=$false;try{[void](Set-Q009HeldHandleDeletePending $additionCell final_root 'addition root')}catch{$additionRejected=$true};Assert-LauncherContract ($additionRejected-and(Test-Path -LiteralPath $lateChild -PathType Leaf)-and[string]$additionCell.StateOf('final_root')-ceq'OPEN') 'post-sentinel-close addition was deleted or accepted by final-root disposition';[void](Close-Q009CheckedNativeHandle $additionCell final_root 'addition root release');[void](Remove-ValidateOnlyOwnedTree $tempRoot $additionRoot $additionRootReceipt.identity $selfTestRunContext $selfTestOwnerReceipt)
        }
        Add-SelfTestResult $cases 'handle-bound-tree-quarantine-rejects-path-replacement' {
            $owned=Join-Path $tempRoot 'tree-race';$ownedIdentity=New-Q009ExactOwnedDirectory $owned;[IO.File]::WriteAllText((Join-Path $owned 'owned.txt'),'owned');$quarantine=$owned+'.quarantine';$rejected=$false
            $treeRaceOwner=[ordered]@{scope='replacement-hostile';run_context_sha256=[string]$selfTestRunContext.context_sha256;root_identity=$ownedIdentity}
            $treeRaceChain=New-Q009OwnedChildManifestChainHead -RootPath $owned -RootIdentity $ownedIdentity -AttemptId ([string]$selfTestRunContext.attempt_id) -Boundary 'replacement_hostile_terminal' -OwnerKind launcher_fixture -OwnerReceipt $treeRaceOwner
            try{[void](Remove-Q009ExactOwnedTree $owned $quarantine $ownedIdentity $treeRaceChain ([string]$selfTestRunContext.attempt_id) -ForceQuarantineReplacementForTest)}catch{$rejected=$true}
            $saved=@(Get-ChildItem -LiteralPath $tempRoot -Directory -Force|Where-Object{$_.Name-like'tree-race.owned-original-*'})
            Assert-LauncherContract ($rejected-and(Test-Path -LiteralPath $owned -PathType Container)-and(Test-Path -LiteralPath (Join-Path $owned 'foreign.txt') -PathType Leaf)-and-not(Test-Path -LiteralPath $quarantine)-and$saved.Count-eq1) 'handle-bound quarantine mutated/deleted a replacement or lost the exact original'
            $foreignIdentity=Get-Q009FileSystemEntryIdentity $owned;[void](Remove-ValidateOnlyOwnedTree $tempRoot $owned $foreignIdentity $selfTestRunContext $selfTestOwnerReceipt)
            $savedIdentity=Copy-Q009FileSystemIdentityToPath $ownedIdentity $saved[0].FullName;[void](Remove-ValidateOnlyOwnedTree $tempRoot $saved[0].FullName $savedIdentity $selfTestRunContext $selfTestOwnerReceipt)
        }
        Add-SelfTestResult $cases 'stale-cache-and-cleanup-retains-exclusive-policy' {
            $cache=Join-Path $tempRoot '.godot';$cacheIdentity=New-Q009ExactOwnedDirectory $cache;[IO.File]::WriteAllText((Join-Path $cache 'owned-cache.txt'),'owned');$cacheReplacementRejected=$false
            try{[void](Remove-ValidateOnlyOwnedTree $tempRoot $cache $cacheIdentity $selfTestRunContext $selfTestOwnerReceipt -ForceQuarantineReplacementForTest)}catch{$cacheReplacementRejected=$true}
            $savedCaches=@(Get-ChildItem -LiteralPath $tempRoot -Directory -Force|Where-Object{$_.Name-like'.godot.owned-original-*'})
            Assert-LauncherContract ($cacheReplacementRejected-and(Test-Path -LiteralPath (Join-Path $cache 'foreign.txt') -PathType Leaf)-and$savedCaches.Count-eq1) 'cache cleanup adopted or deleted a foreign replacement'
            $replacementIdentity=Get-Q009FileSystemEntryIdentity $cache;[void](Remove-ValidateOnlyOwnedTree $tempRoot $cache $replacementIdentity $selfTestRunContext $selfTestOwnerReceipt)
            $savedCacheIdentity=Copy-Q009FileSystemIdentityToPath $cacheIdentity $savedCaches[0].FullName;[void](Remove-ValidateOnlyOwnedTree $tempRoot $savedCaches[0].FullName $savedCacheIdentity $selfTestRunContext $selfTestOwnerReceipt)
            $releaseProfile=Join-Path $tempRoot 'release-profile-absent';$releaseCache=Join-Path $tempRoot 'release-cache-absent';[void](Assert-Q009PathAbsentStrict $releaseProfile);[void](Assert-Q009PathAbsentStrict $releaseCache)
            $lateCacheIdentity=New-Q009ExactOwnedDirectory $releaseCache;$releaseRejected=$false;try{[void](Assert-Q009PathAbsentStrict $releaseCache)}catch{$releaseRejected=$true};Assert-LauncherContract ($releaseRejected-and(Test-Q009FileSystemIdentityMatch $lateCacheIdentity)) 'late cache path did not block strict pre-EXCLUSIVE-release absence or was mutated';[void](Remove-ValidateOnlyOwnedTree $tempRoot $releaseCache $lateCacheIdentity $selfTestRunContext $selfTestOwnerReceipt)
            $custody=[ordered]@{start_observed=$false;start_count=0;cleanup_count=0;cleanup_proved=$true}
            $badCustody=[ordered]@{start_observed=@($false);start_count=0;cleanup_count=0;cleanup_proved=$true};Assert-LauncherContract (-not(Test-MayReleaseExclusiveReservation $true $true $true $badCustody)) 'array-coerced process custody flag allowed EXCLUSIVE release'
            $contradictoryCustody=[ordered]@{start_observed=$false;start_count=0;cleanup_count=0;cleanup_proved=$false};Assert-LauncherContract (-not(Test-MayReleaseExclusiveReservation $true $true $true $contradictoryCustody)) 'contradictory process custody counts/cleanup flag allowed EXCLUSIVE release'
            Assert-LauncherContract (-not(Test-MayReleaseExclusiveReservation $true $false $true $custody)) 'cleanup failure allowed exclusive release'
            Assert-LauncherContract (-not(Test-MayReleaseExclusiveReservation $true $true $false $custody)) 'provenance failure allowed exclusive release'
            Assert-LauncherContract (Test-MayReleaseExclusiveReservation $true $true $true $custody) 'clean no-process custody could not release'
            Register-ProcessCustodyStart $custody
            Assert-LauncherContract ([bool]$custody.start_observed-and-not[bool]$custody.cleanup_proved-and-not(Test-MayReleaseExclusiveReservation $true $true $true $custody)) 'started process did not block release before cleanup proof'
            Register-ProcessCustodyCleanup $custody $false;Register-ProcessCustodyStart $custody;Register-ProcessCustodyCleanup $custody $true
            Assert-LauncherContract (-not[bool]$custody.cleanup_proved-and[int]$custody.start_count-eq2-and[int]$custody.cleanup_count-eq1-and-not(Test-MayReleaseExclusiveReservation $true $true $true $custody)) 'later clean phase erased an earlier unresolved start'
            $liveIdentity=Get-ProcessIdentityRecord (Get-ProcessByIdStrict -ProcessId $PID);$liveCustody=[ordered]@{start_observed=$true;start_count=1;cleanup_count=1;cleanup_proved=$true}
            $livePhase=New-Q009ClosedPhaseFixture 'live-hostile' Exact $selfTestRunContext $selfTestExecutableIdentity $liveIdentity $true
            $liveEvidence=Get-FinalOwnedProcessResidualEvidence @($livePhase) $liveCustody $selfTestRunContext
            Assert-LauncherContract (-not[bool]$liveEvidence.clean-and@($liveEvidence.residual_process_ids)-contains$PID-and-not(Test-MayRemoveOwnedRuntimeArtifacts $liveEvidence $selfTestRunContext)) 'live exact root did not retain profile/cache custody'
            $deadStart=[DateTime]::UtcNow.AddYears(-5);$deadPid=2147483000;$deadIdentity=[ordered]@{pid=$deadPid;name='dead-hostile';start_utc=$deadStart.ToString('o');start_ticks=[long]$deadStart.Ticks;key=('{0}|{1}|dead-hostile'-f$deadPid,$deadStart.Ticks)}
            $deadPhase=New-Q009ClosedPhaseFixture 'dead-hostile' Exact $selfTestRunContext $selfTestExecutableIdentity $deadIdentity $true
            $deadEvidence=Get-FinalOwnedProcessResidualEvidence @($deadPhase) $liveCustody $selfTestRunContext
            Assert-LauncherContract ([bool]$deadEvidence.clean-and(Test-MayRemoveOwnedRuntimeArtifacts $deadEvidence $selfTestRunContext)) 'residual-free exact proof did not admit later owned-artifact cleanup'
            $badDeadEvidence=[ordered]@{};foreach($key in $deadEvidence.Keys){$badDeadEvidence[$key]=$deadEvidence[$key]};$badDeadEvidence.clean=@($true);Assert-LauncherContract (-not(Test-MayRemoveOwnedRuntimeArtifacts $badDeadEvidence $selfTestRunContext)) 'array-coerced final process-evidence flag allowed owned-artifact cleanup'
            $deadGodotPid=2147482999;$deadGodotIdentity=[ordered]@{pid=$deadGodotPid;name='Godot_v4.6-stable_win64_console';start_utc=$deadStart.ToString('o');start_ticks=[long]$deadStart.Ticks;key=('{0}|{1}|Godot_v4.6-stable_win64_console'-f$deadGodotPid,$deadStart.Ticks)}
            $deadGodotPhase=New-Q009ClosedPhaseFixture 'dead-godot-hostile' Godot $selfTestRunContext $selfTestExecutableIdentity $deadGodotIdentity $true
            $deadGodotEvidence=Get-FinalOwnedProcessResidualEvidence @($deadGodotPhase) $liveCustody $selfTestRunContext
            Assert-LauncherContract ([bool]$deadGodotEvidence.clean-and(Test-MayRemoveOwnedRuntimeArtifacts $deadGodotEvidence $selfTestRunContext)) 'residual-free Godot root/descendant proof path rejected typed retained records'
        }
        Add-SelfTestResult $cases 'atomic-evidence-root-pre-post-move-native-identity' {
            $valid=Join-Path $tempRoot 'evidence-valid';$receipt=New-AtomicOwnedEvidenceRoot $valid $tempRoot 'owner=valid' $selfTestRunContext.attempt_id;Assert-LauncherContract ((Test-Q009FileSystemIdentityMatch $receipt.root_identity)-and(Test-Q009FileSystemIdentityMatch $receipt.claim_identity)-and(Test-Q009OwnedChildManifestChainHeadShape $receipt.owned_child_chain_head $receipt.root_identity $selfTestRunContext.attempt_id 'evidence_published_identity_bound')) 'valid atomic evidence-root native identities rejected';[void](Remove-ValidateOnlyOwnedTree $tempRoot $valid $receipt.root_identity $selfTestRunContext $selfTestOwnerReceipt)
            $collision=Join-Path $tempRoot 'evidence-collision';$collisionIdentity=New-Q009ExactOwnedDirectory $collision;$rejected=$false;try{[void](New-AtomicOwnedEvidenceRoot $collision $tempRoot 'owner=collision' $selfTestRunContext.attempt_id)}catch{$rejected=$true};Assert-LauncherContract ($rejected-and(Test-Q009FileSystemIdentityMatch $collisionIdentity)) 'preexisting evidence destination was adopted or removed';[void](Remove-ValidateOnlyOwnedTree $tempRoot $collision $collisionIdentity $selfTestRunContext $selfTestOwnerReceipt)
            $replacement=Join-Path $tempRoot 'evidence-post-move-replacement';$caught=$null;try{[void](New-AtomicOwnedEvidenceRoot $replacement $tempRoot 'owner=post-move' $selfTestRunContext.attempt_id -ForcePostMoveReplacementForTest)}catch{$caught=$_.Exception}
            Assert-LauncherContract ($null-ne$caught-and$caught.Data.Contains('owned_original_path')-and$caught.Data.Contains('replacement_identity')) 'post-move replacement hostile did not retain exact ownership evidence'
            $replacementIdentity=$caught.Data['replacement_identity'];$originalIdentity=$caught.Data['owned_original_identity'];$originalPath=[string]$caught.Data['owned_original_path']
            Assert-LauncherContract ((Test-Q009FileSystemIdentityMatch $replacementIdentity)-and(Test-Q009FileSystemIdentityMatch $originalIdentity)-and[IO.File]::ReadAllText((Join-Path $replacement '.attempt-owner'))-ceq'owner=post-move') 'post-move copied-claim replacement or exact original did not survive rejection'
            [void](Remove-ValidateOnlyOwnedTree $tempRoot $replacement $replacementIdentity $selfTestRunContext $selfTestOwnerReceipt);[void](Remove-ValidateOnlyOwnedTree $tempRoot $originalPath $originalIdentity $selfTestRunContext $selfTestOwnerReceipt)
        }
        Add-SelfTestResult $cases 'attempt-owner-hash-containment-and-executable-provenance' { $owned=Join-Path $tempRoot 'owned';$ownedIdentity=New-Q009ExactOwnedDirectory $owned;$claim=Join-Path $owned '.attempt-owner';$text="attempt_id=test`npid=$PID`n";$claimOwnership=[ordered]@{created=$false;identity=$null;write_complete=$false;removal_failed=$false;removal_error=''};New-OwnedLeaseFile $claim $text $claimOwnership;$hash=(Get-FileHash $claim -Algorithm SHA256).Hash;$receipt=[ordered]@{root_identity=$ownedIdentity;claim_identity=$claimOwnership.identity};Assert-ExactAttemptOwner $claim $text $hash $owned $receipt;[IO.File]::AppendAllText($claim,'tamper');$rejected=$false;try{Assert-ExactAttemptOwner $claim $text $hash $owned $receipt}catch{$rejected=$true};Assert-LauncherContract $rejected 'tampered owner claim accepted';$outsideRejected=$false;try{Assert-NoReparsePathChain $owned (Join-Path $tempRoot 'outside')}catch{$outsideRejected=$true};Assert-LauncherContract $outsideRejected 'outside cleanup/evidence path accepted';$psPath=Join-Path $PSHOME 'powershell.exe';$identity=Get-ExecutableIdentity $psPath;[void](Assert-ExecutableIdentity 'probe' $psPath $psPath $identity.sha256 $identity);foreach($badHash in @('',('0'*64))){$rejected=$false;try{[void](Assert-ExecutableIdentity 'probe' $psPath $psPath $badHash $identity)}catch{$rejected=$true};Assert-LauncherContract $rejected 'missing/wrong expected executable hash accepted'};$rejected=$false;try{[void](Assert-ExecutableIdentity 'probe' $psPath (Join-Path $tempRoot 'other.exe') $identity.sha256 $identity)}catch{$rejected=$true};Assert-LauncherContract $rejected 'executable path drift accepted';$drift=($identity|ConvertTo-Json|ConvertFrom-Json);$drift.length=[long]$drift.length+1;$rejected=$false;try{[void](Assert-ExecutableIdentity 'probe' $psPath $psPath $identity.sha256 $drift)}catch{$rejected=$true};Assert-LauncherContract $rejected 'captured executable metadata drift accepted' }
        Add-SelfTestResult $cases 'executable-swap-before-handle-locked-launch-is-rejected' {
            $source=Join-Path $PSHOME 'powershell.exe';$replacementSource=Join-Path $env:SystemRoot 'System32\cmd.exe';$victim=Join-Path $tempRoot 'launch-victim.exe';$saved=Join-Path $tempRoot 'launch-victim-owned.exe'
            [IO.File]::Copy($source,$victim,$false);$expected=Get-ExecutableIdentity $victim;[IO.File]::Move($victim,$saved);[IO.File]::Copy($replacementSource,$victim,$false)
            $caught=$null;try{[void](Start-RedirectedProcess -FilePath $victim -Arguments @('/c','exit','0') -StdoutPath (Join-Path $tempRoot 'swap.out') -StderrPath (Join-Path $tempRoot 'swap.err') -ProcessKind Exact -BaselineGodotIdentityKeys @() -TimeoutSec 5 -ExpectedExecutableIdentity $expected -RunContext $selfTestRunContext)}catch{$caught=$_.Exception}
            Assert-LauncherContract ($null-ne$caught-and-not[bool](Get-OwnedProcessStartProofFromException $caught).started-and(Test-Path -LiteralPath $victim -PathType Leaf)) 'executable swap was launched or replacement was mutated'
        }
        Add-SelfTestResult $cases 'runtime-source-custody-lifecycle-provenance-seams' {
            $src=[IO.File]::ReadAllText($PSCommandPath);$tokens=$null;$parseErrors=$null
            $supportSource=[IO.File]::ReadAllText($supportPath)
            $ast=[Management.Automation.Language.Parser]::ParseInput($src,[ref]$tokens,[ref]$parseErrors)
            Assert-LauncherContract ($parseErrors.Count-eq0) 'launcher source did not parse'
            $supportTokens=$null;$supportParseErrors=$null;$supportAst=[Management.Automation.Language.Parser]::ParseInput($supportSource,[ref]$supportTokens,[ref]$supportParseErrors)
            Assert-LauncherContract ($supportParseErrors.Count-eq0) 'shared process-support source did not parse'
            $selfTestFunctions=@($ast.FindAll({param($node)$node -is [Management.Automation.Language.FunctionDefinitionAst]-and$node.Name-ceq'Invoke-ValidateOnlySelfTest'},$true))
            Assert-LauncherContract ($selfTestFunctions.Count-eq1) 'ValidateOnly function extent was not unique'
            $extent=$selfTestFunctions[0].Extent;$runtimeSource=$src.Substring(0,$extent.StartOffset)+$src.Substring($extent.EndOffset)
            Assert-LauncherContract (-not$runtimeSource.Contains('runtime-source-custody-lifecycle-provenance-seams')) 'runtime source retained self-test checklist'
            $entryMarker='if($LoadAdmissionFunctionsOnly){return}'
            $entryPosition=$runtimeSource.IndexOf($entryMarker,[StringComparison]::Ordinal)
            Assert-LauncherContract ($entryPosition-ge0) 'qualifying runtime entry marker was not unique and discoverable'
            $runtimeEntrySource=$runtimeSource.Substring($entryPosition+$entryMarker.Length)
            Assert-LauncherContract (-not$runtimeEntrySource.Contains('runtime-source-custody-lifecycle-provenance-seams')) 'qualifying runtime entry accidentally retained the self-test checklist'
            $leaseAncestorFunctions=@($supportAst.FindAll({param($node)$node-is[Management.Automation.Language.FunctionDefinitionAst]-and$node.Name-ceq'Test-ProcessHasLeaseAncestor'},$true))
            Assert-LauncherContract ($leaseAncestorFunctions.Count-eq1) 'exact focused-lease ancestry function extent was not unique'
            $automaticPidWrites=[Collections.Generic.List[object]]::new()
            foreach($node in @($leaseAncestorFunctions[0].Body.FindAll({param($candidate)$candidate-is[Management.Automation.Language.AssignmentStatementAst]-or$candidate-is[Management.Automation.Language.ForEachStatementAst]-or$candidate-is[Management.Automation.Language.ParameterAst]},$true))){
                $variableName=''
                if($node-is[Management.Automation.Language.AssignmentStatementAst]-and$node.Left-is[Management.Automation.Language.VariableExpressionAst]){$variableName=[string]$node.Left.VariablePath.UserPath}
                elseif($node-is[Management.Automation.Language.ForEachStatementAst]){$variableName=[string]$node.Variable.VariablePath.UserPath}
                elseif($node-is[Management.Automation.Language.ParameterAst]){$variableName=[string]$node.Name.VariablePath.UserPath}
                if($variableName-ieq'PID'){[void]$automaticPidWrites.Add($node)}
            }
            Assert-LauncherContract ($automaticPidWrites.Count-eq0-and-not[regex]::IsMatch($leaseAncestorFunctions[0].Extent.Text,'(?i)(?<![A-Za-z0-9_])\$pid\s*(?:=|\+=|-=|\*=|/=|%=|\+\+|--)')) 'exact focused-lease ancestry attempts to assign the read-only automatic $PID variable'
            $stdoutCommands=@($selfTestFunctions[0].Body.FindAll({param($node)$node-is[Management.Automation.Language.CommandAst]-and$node.GetCommandName()-in@('Write-Host','Write-Output','Write-Information')},$true))
            $successEmitters=@($stdoutCommands|Where-Object{$_.GetCommandName()-ceq'Write-Host'-and$_.Extent.Text.Contains('RW06_1_Q009_VALIDATE_ONLY_PASS report=')})
            Assert-LauncherContract ($stdoutCommands.Count-eq1-and$successEmitters.Count-eq1) 'ValidateOnly source does not have exactly one explicit stdout success emitter'
            $receiptCommands=@($selfTestFunctions[0].Body.FindAll({param($node)$node-is[Management.Automation.Language.CommandAst]-and$node.GetCommandName()-in@('Remove-Q009ExactOwnedTree','Remove-ExactOwnedTree')},$true))
            foreach($receiptCommand in $receiptCommands){$ancestor=$receiptCommand.Parent;$suppressed=$false;while($null-ne$ancestor){if($ancestor-is[Management.Automation.Language.ConvertExpressionAst]-and$ancestor.Type.TypeName.FullName-ceq'void'){$suppressed=$true;break};$ancestor=$ancestor.Parent};Assert-LauncherContract $suppressed "ValidateOnly cleanup receipt can leak to stdout at line $($receiptCommand.Extent.StartLineNumber)"}
            Assert-LauncherContract (-not[regex]::IsMatch($runtimeSource,'(?im)^\s*Start-Process\b')) 'Start-Process present'
            Assert-LauncherContract (-not[regex]::IsMatch($runtimeSource,'\.WaitForExit\(\s*\)')) 'unbounded wait present'
            Assert-LauncherContract (-not[regex]::IsMatch($runtimeSource,'(?im)^\s*Remove-Item\b')) 'path-based Remove-Item present in qualifying runtime'
            $runtimeTokens=$null;$runtimeParseErrors=$null;$runtimeAst=[Management.Automation.Language.Parser]::ParseInput($runtimeSource,[ref]$runtimeTokens,[ref]$runtimeParseErrors);Assert-LauncherContract ($runtimeParseErrors.Count-eq0) 'runtime source without self-test did not parse'
            $capabilityFunctions=@($runtimeAst.FindAll({param($node)$node-is[Management.Automation.Language.FunctionDefinitionAst]-and$node.Name-ceq'Invoke-Q009SentinelFilesystemCapabilityProbe'},$true));Assert-LauncherContract ($capabilityFunctions.Count-eq1) 'sentinel capability function extent was not unique'
            $capabilityExtent=$capabilityFunctions[0].Extent;$runtimeWithoutCapability=$runtimeSource.Substring(0,$capabilityExtent.StartOffset)+$runtimeSource.Substring($capabilityExtent.EndOffset)
            Assert-LauncherContract (-not[regex]::IsMatch($runtimeWithoutCapability,'(?i)\[(?:System\.)?IO\.(?:File|Directory)\]::Delete\s*\(')) 'path-based File/Directory delete escaped the isolated sentinel-denial capability hostile'
            Assert-LauncherContract ([regex]::Matches($capabilityExtent.Text,'\[IO\.Directory\]::Delete\(\$root,\$true\)').Count-eq1-and[regex]::Matches($capabilityExtent.Text,'\[IO\.File\]::Delete\(\$sentinel\)').Count-eq1) 'sentinel capability does not contain exactly the two deliberate path-delete denial attacks'
            Assert-LauncherContract (-not[regex]::IsMatch($runtimeSource,'Get-ChildItem\s+-LiteralPath\s+\$leaseRoot')) 'runtime bypassed strict lease enumeration'
            $jobAssignPosition=$supportSource.IndexOf('AssignProcessToJobObject(job, pi.hProcess)',[StringComparison]::Ordinal)
            $managedWrapperPosition=$supportSource.IndexOf('managedProcess = Process.GetProcessById',[StringComparison]::Ordinal)
            $managedIdentityPosition=$supportSource.IndexOf('managedRootStartUtc = managedProcess.StartTime.ToUniversalTime()',[StringComparison]::Ordinal)
            $resumePosition=$supportSource.IndexOf('ResumeThread(pi.hThread)',[StringComparison]::Ordinal)
            $jobTransferPosition=$supportSource.IndexOf('result.JobHandle = job',[StringComparison]::Ordinal)
            $jobLocalReleasePosition=$supportSource.LastIndexOf('job = IntPtr.Zero',[StringComparison]::Ordinal)
            Assert-LauncherContract ($jobAssignPosition-ge0-and$managedWrapperPosition-gt$jobAssignPosition-and$managedIdentityPosition-gt$managedWrapperPosition-and$resumePosition-gt$managedIdentityPosition-and$jobTransferPosition-gt$resumePosition-and$jobLocalReleasePosition-gt$jobTransferPosition) 'suspended native root was not assigned, identity/pipe wrapped, resumed, and transactionally transferred in the required order'
            Assert-LauncherContract ($supportSource.Contains('0x00002000u')-and$supportSource.Contains('GetExactExitCode')-and$supportSource.Contains('QueryMembershipCount')-and$supportSource.Contains('WaitForRootExit')) 'owned Job Object kill-on-close, membership, native wait, or native exit custody seam was missing'
            Assert-LauncherContract (-not$supportSource.Contains('0x01000000u')-and-not$supportSource.Contains('0x00000800u')-and-not$supportSource.Contains('0x00001000u')) 'owned Job Object source enabled a process/job breakaway flag'
            $diagnosticInputPosition=$runtimeSource.IndexOf('$allPaths=@($stdoutPath,$stderrPath)+@($AdditionalLogPaths)',[StringComparison]::Ordinal)
            $diagnosticScanPosition=$runtimeSource.IndexOf('$diagnostics=@(Get-StrictDiagnosticLines $combined)',[StringComparison]::Ordinal)
            Assert-LauncherContract ($diagnosticInputPosition-ge0-and$diagnosticScanPosition-gt$diagnosticInputPosition) 'strict diagnostics did not consume both phase streams and every declared log'
            $cacheCellToken='$cacheHandleCustody.native_cell=New-Q009CacheCustodyCell $attemptId'
            $cacheCreateToken='$cacheCreation=Invoke-Q009MutexCritical -RunContext $runContext -Body {'
            $rootCreateToken='$rootReceipt=New-Q009ExactOwnedDirectoryHeld -Path $projectCacheRoot -CustodyCell $cacheHandleCustody.native_cell -Slot root_creation'
            $sentinelCreateToken='$sentinelReceipt=New-Q009ExactOwnedFileHeld -Path $cacheSentinelPath'
            $preHandoffProofToken='$preCloseProof=Get-SentinelPinnedCacheProof $cacheHandleCustody'
            $initialRootCloseToken='$initialRootClose=Close-Q009CheckedNativeHandle $cacheHandleCustody.native_cell root_creation'
            $postHandoffProofToken='$proof=Get-SentinelPinnedCacheProof $cacheHandleCustody'
            $finalPinProofToken='$finalPinProof=Get-SentinelPinnedCacheProof $cacheHandleCustody'
            $manifestToken='$cacheManifest=$cacheManifestChain.manifest'
            $ordinaryCleanupToken='$ordinaryCleanup=Remove-Q009ManifestChildrenExceptSentinel -RootPath $projectCacheRoot'
            $sentinelDispositionToken='$sentinelDisposition=Set-Q009HeldHandleDeletePending $cacheHandleCustody.native_cell sentinel'
            $finalRootOpenToken='$finalRootReceipt=Open-Q009ExactDirectoryHeld -Path $projectCacheRoot'
            $sentinelCloseToken='$cacheEvidence.sentinel_close=Close-Q009CheckedNativeHandle $cacheHandleCustody.native_cell sentinel'
            $rootDispositionToken='$rootDisposition=Set-Q009HeldHandleDeletePending $cacheHandleCustody.native_cell final_root'
            $rootCloseToken='$cacheEvidence.final_root_close=Close-Q009CheckedNativeHandle $cacheHandleCustody.native_cell final_root'
            $finalCacheAbsenceToken='$cacheAbsenceAfterCleanup=Assert-Q009PathAbsentStrict $projectCacheRoot'
            foreach($token in @($cacheCellToken,$cacheCreateToken,$rootCreateToken,$sentinelCreateToken,$preHandoffProofToken,$initialRootCloseToken,$postHandoffProofToken,$finalPinProofToken,$manifestToken,$ordinaryCleanupToken,$sentinelDispositionToken,$finalRootOpenToken,$sentinelCloseToken,$rootDispositionToken,$rootCloseToken,$finalCacheAbsenceToken)){Assert-LauncherContract ([regex]::Matches($runtimeSource,[regex]::Escape($token)).Count-eq1) "sentinel-pinned cache lifecycle seam is missing or ambiguous: $token"}
            Assert-LauncherContract (-not$runtimeSource.Contains('Move-Q009HeldExactOwnedTreeToQuarantine')-and-not$runtimeSource.Contains('Remove-Q009ExactQuarantinedTree')-and-not$runtimeSource.Contains('Close-Q009HeldDirectoryHandle')-and-not$runtimeSource.Contains('Register-CacheHandleCustody')-and-not$runtimeSource.Contains('$cacheHeldDirectory')-and-not$runtimeSource.Contains('$cacheQuarantine')) 'retired cache quarantine/reopen custody survived in qualifying runtime'
            Assert-LauncherContract (-not$runtimeSource.Contains('Remove-ExactOwnedTree $projectRoot $projectCacheRoot')-and-not$runtimeSource.Contains('$cacheHandleCustody.native_cell.Dispose')-and-not$runtimeSource.Contains('$cacheHandleCustody.handle')-and-not$runtimeSource.Contains('$cacheHandleCustody|ConvertTo-Json')) 'qualifying cache runtime bypasses checked native custody or serializes a native handle'
            $getCacheLifecyclePositions={
                param([string]$CandidateSource)
                return [ordered]@{
                    cell=$CandidateSource.IndexOf($cacheCellToken,[StringComparison]::Ordinal)
                    cache_mutex=$CandidateSource.IndexOf($cacheCreateToken,[StringComparison]::Ordinal)
                    root_create=$CandidateSource.IndexOf($rootCreateToken,[StringComparison]::Ordinal)
                    sentinel_create=$CandidateSource.IndexOf($sentinelCreateToken,[StringComparison]::Ordinal)
                    pre_handoff_proof=$CandidateSource.IndexOf($preHandoffProofToken,[StringComparison]::Ordinal)
                    initial_root_close=$CandidateSource.IndexOf($initialRootCloseToken,[StringComparison]::Ordinal)
                    post_handoff_proof=$CandidateSource.IndexOf($postHandoffProofToken,[StringComparison]::Ordinal)
                    process_gate=$CandidateSource.IndexOf('$phaseResidualFree=Test-MayRemoveOwnedRuntimeArtifacts $finalOwnedProcessEvidence $runContext',[StringComparison]::Ordinal)
                    quiescence=$CandidateSource.IndexOf('$preCleanupQuiescence=Invoke-Q009MutexCritical',[StringComparison]::Ordinal)
                    profile_cleanup=$CandidateSource.IndexOf('Remove-ExactOwnedTree $EvidenceRoot $profileRoot',[StringComparison]::Ordinal)
                    import_phase=$CandidateSource.IndexOf('$import=Invoke-ExclusiveProcessPhase',[StringComparison]::Ordinal)
                    final_pin_proof=$CandidateSource.IndexOf($finalPinProofToken,[StringComparison]::Ordinal)
                    manifest=$CandidateSource.IndexOf($manifestToken,[StringComparison]::Ordinal)
                    ordinary_cleanup=$CandidateSource.IndexOf($ordinaryCleanupToken,[StringComparison]::Ordinal)
                    sentinel_disposition=$CandidateSource.IndexOf($sentinelDispositionToken,[StringComparison]::Ordinal)
                    final_root_open=$CandidateSource.IndexOf($finalRootOpenToken,[StringComparison]::Ordinal)
                    sentinel_close=$CandidateSource.IndexOf($sentinelCloseToken,[StringComparison]::Ordinal)
                    root_disposition=$CandidateSource.IndexOf($rootDispositionToken,[StringComparison]::Ordinal)
                    root_close=$CandidateSource.IndexOf($rootCloseToken,[StringComparison]::Ordinal)
                    final_absence=$CandidateSource.IndexOf($finalCacheAbsenceToken,[StringComparison]::Ordinal)
                    retain_custody=$CandidateSource.IndexOf('Owned profiles and candidate cache were retained because exact process/root/descendant cleanup plus mutex-proved global quiescence was not proved',[StringComparison]::Ordinal)
                }
            }
            $cacheLifecycle=&$getCacheLifecyclePositions $runtimeSource
            $creationCustodyOrdered=$cacheLifecycle.cell-ge0-and$cacheLifecycle.cache_mutex-gt$cacheLifecycle.cell-and$cacheLifecycle.root_create-gt$cacheLifecycle.cache_mutex-and$cacheLifecycle.sentinel_create-gt$cacheLifecycle.root_create-and$cacheLifecycle.pre_handoff_proof-gt$cacheLifecycle.sentinel_create-and$cacheLifecycle.initial_root_close-gt$cacheLifecycle.pre_handoff_proof-and$cacheLifecycle.post_handoff_proof-gt$cacheLifecycle.initial_root_close-and$cacheLifecycle.import_phase-gt$cacheLifecycle.post_handoff_proof
            $successCleanupOrdered=$cacheLifecycle.process_gate-ge0-and$cacheLifecycle.quiescence-gt$cacheLifecycle.process_gate-and$cacheLifecycle.profile_cleanup-gt$cacheLifecycle.quiescence-and$cacheLifecycle.final_pin_proof-gt$cacheLifecycle.profile_cleanup-and$cacheLifecycle.final_pin_proof-gt$cacheLifecycle.import_phase-and$cacheLifecycle.manifest-gt$cacheLifecycle.final_pin_proof-and$cacheLifecycle.ordinary_cleanup-gt$cacheLifecycle.manifest-and$cacheLifecycle.final_root_open-gt$cacheLifecycle.ordinary_cleanup-and$cacheLifecycle.sentinel_disposition-gt$cacheLifecycle.final_root_open-and$cacheLifecycle.sentinel_close-gt$cacheLifecycle.sentinel_disposition-and$cacheLifecycle.root_disposition-gt$cacheLifecycle.sentinel_close-and$cacheLifecycle.root_close-gt$cacheLifecycle.root_disposition-and$cacheLifecycle.final_absence-gt$cacheLifecycle.root_close-and$cacheLifecycle.retain_custody-gt$cacheLifecycle.quiescence
            Assert-LauncherContract $creationCustodyOrdered 'cache custody is not pre-registered and handed from exact root FILE_CREATE to relative sentinel FILE_CREATE before the initial root close and first engine phase'
            Assert-LauncherContract $successCleanupOrdered 'successful cache cleanup lost the process/quiescence gate or exact sentinel-disposition/final-root-disposition checked-close sequence'
            foreach($criticalToken in @($rootCreateToken,$sentinelCreateToken,$preHandoffProofToken,$initialRootCloseToken,$postHandoffProofToken,$ordinaryCleanupToken,$sentinelDispositionToken,$finalRootOpenToken,$sentinelCloseToken,$rootDispositionToken,$rootCloseToken,$finalCacheAbsenceToken)){
                $position=$runtimeSource.IndexOf($criticalToken,[StringComparison]::Ordinal);$mutated=$runtimeSource.Remove($position,$criticalToken.Length);$mutatedLifecycle=&$getCacheLifecyclePositions $mutated
                $mutatedCreation=$mutatedLifecycle.cell-ge0-and$mutatedLifecycle.cache_mutex-gt$mutatedLifecycle.cell-and$mutatedLifecycle.root_create-gt$mutatedLifecycle.cache_mutex-and$mutatedLifecycle.sentinel_create-gt$mutatedLifecycle.root_create-and$mutatedLifecycle.pre_handoff_proof-gt$mutatedLifecycle.sentinel_create-and$mutatedLifecycle.initial_root_close-gt$mutatedLifecycle.pre_handoff_proof-and$mutatedLifecycle.post_handoff_proof-gt$mutatedLifecycle.initial_root_close-and$mutatedLifecycle.import_phase-gt$mutatedLifecycle.post_handoff_proof
                $mutatedSuccess=$mutatedLifecycle.process_gate-ge0-and$mutatedLifecycle.quiescence-gt$mutatedLifecycle.process_gate-and$mutatedLifecycle.final_pin_proof-gt$mutatedLifecycle.quiescence-and$mutatedLifecycle.manifest-gt$mutatedLifecycle.final_pin_proof-and$mutatedLifecycle.ordinary_cleanup-gt$mutatedLifecycle.manifest-and$mutatedLifecycle.final_root_open-gt$mutatedLifecycle.ordinary_cleanup-and$mutatedLifecycle.sentinel_disposition-gt$mutatedLifecycle.final_root_open-and$mutatedLifecycle.sentinel_close-gt$mutatedLifecycle.sentinel_disposition-and$mutatedLifecycle.root_disposition-gt$mutatedLifecycle.sentinel_close-and$mutatedLifecycle.root_close-gt$mutatedLifecycle.root_disposition-and$mutatedLifecycle.final_absence-gt$mutatedLifecycle.root_close
                Assert-LauncherContract (-not($mutatedCreation-and$mutatedSuccess)) "cache lifecycle source hostile still passed after removing $criticalToken"
            }
            Assert-LauncherContract ($runtimeEntrySource.Contains('[void](Remove-ExactOwnedTree $EvidenceRoot $profileRoot $profileRootIdentity $profileManifestChain $attemptId)')) 'profile cleanup lost its terminal manifest chain, atomically captured root identity, or attempt identity'
            Assert-LauncherContract ($runtimeEntrySource.Contains('$releaseReceipt=Close-Q009HeldExclusiveLease $heldExclusiveLease $runContext')) 'EXCLUSIVE release lost its held handle-bound delete/close receipt'
            Assert-LauncherContract ($runtimeSource.Contains('Remove-Q009ExactOwnedFile -Path $file.FullName -ExpectedIdentity $fileIdentity')) 'stale-lease cleanup lost its exact enumerated file identity'
            $releaseBlockPosition=$runtimeEntrySource.IndexOf('$preReleaseZeroGodot=Invoke-Q009MutexCritical',[StringComparison]::Ordinal)
            $releaseProcessToken='$releaseProcessEvidence=Get-FinalOwnedProcessResidualEvidence @($phases) $processCustody $runContext'
            $releaseProfileToken='$releaseProfileAbsence=Assert-Q009PathAbsentStrict $profileRoot'
            $releaseCacheToken='$releaseCacheAbsence=Assert-Q009PathAbsentStrict $projectCacheRoot'
            $releaseDependencyToken='$releaseDependencyPins=Close-Q009TrackedDependencyPins $pinned $dependencyPins $runContext $dependencyPinReceipts'
            $releaseCloseToken='$releaseReceipt=Close-Q009HeldExclusiveLease $heldExclusiveLease $runContext'
            $releaseProcessPosition=$runtimeEntrySource.IndexOf($releaseProcessToken,$releaseBlockPosition,[StringComparison]::Ordinal)
            $releaseProfileAbsencePosition=$runtimeEntrySource.IndexOf($releaseProfileToken,$releaseBlockPosition,[StringComparison]::Ordinal)
            $releaseCacheAbsencePosition=$runtimeEntrySource.IndexOf($releaseCacheToken,$releaseBlockPosition,[StringComparison]::Ordinal)
            $releaseDependencyPosition=$runtimeEntrySource.IndexOf($releaseDependencyToken,$releaseBlockPosition,[StringComparison]::Ordinal)
            $releaseLeaseDeletePosition=$runtimeEntrySource.IndexOf($releaseCloseToken,$releaseBlockPosition,[StringComparison]::Ordinal)
            Assert-LauncherContract ($releaseBlockPosition-ge0-and$releaseProcessPosition-gt$releaseBlockPosition-and$releaseProfileAbsencePosition-gt$releaseProcessPosition-and$releaseCacheAbsencePosition-gt$releaseProfileAbsencePosition-and$releaseDependencyPosition-gt$releaseCacheAbsencePosition-and$releaseLeaseDeletePosition-gt$releaseDependencyPosition) 'process/job/lease zero, profile/cache absence, and tracked dependency release are not ordered inside the release mutex before exact EXCLUSIVE deletion'
            foreach($releaseToken in @($releaseProcessToken,$releaseProfileToken,$releaseCacheToken,$releaseDependencyToken,$releaseCloseToken)){$position=$runtimeEntrySource.IndexOf($releaseToken,$releaseBlockPosition,[StringComparison]::Ordinal);Assert-LauncherContract ($position-ge0) "EXCLUSIVE release token was absent before hostile mutation: $releaseToken";$mutated=$runtimeEntrySource.Remove($position,$releaseToken.Length);$mutatedProcess=$mutated.IndexOf($releaseProcessToken,$releaseBlockPosition,[StringComparison]::Ordinal);$mutatedProfile=$mutated.IndexOf($releaseProfileToken,$releaseBlockPosition,[StringComparison]::Ordinal);$mutatedCache=$mutated.IndexOf($releaseCacheToken,$releaseBlockPosition,[StringComparison]::Ordinal);$mutatedDependency=$mutated.IndexOf($releaseDependencyToken,$releaseBlockPosition,[StringComparison]::Ordinal);$mutatedDelete=$mutated.IndexOf($releaseCloseToken,$releaseBlockPosition,[StringComparison]::Ordinal);Assert-LauncherContract (-not($mutatedProcess-gt$releaseBlockPosition-and$mutatedProfile-gt$mutatedProcess-and$mutatedCache-gt$mutatedProfile-and$mutatedDependency-gt$mutatedCache-and$mutatedDelete-gt$mutatedDependency)) "EXCLUSIVE release source hostile still passed after removing $releaseToken"}
            $prePublicationToken='$prePublicationCustody=Invoke-Q009MutexCritical -RunContext $runContext -Body {'
            $terminalSafeToken='$terminalEvidenceSafe=$cleanupSucceeded-and$finalProvenanceValid-and$leaseOwned-and(Test-Q009RunContextShape $runContext)-and(Test-Q009PrePublicationCustodyShape $prePublicationCustody $runContext $heldExclusiveReceipt $pinned $dependencyPinReceipts)'
            $terminalOwnerToken='$evidenceTerminalOwnerReceipt=[ordered]@{'
            $terminalOwnerShapeToken='if(-not(Test-Q009EvidenceTerminalOwnerReceiptShape $evidenceTerminalOwnerReceipt $runContext $evidenceRootOwnership $heldExclusiveReceipt $pinned $dependencyPinReceipts))'
            Assert-LauncherContract ([regex]::Matches($runtimeEntrySource,[regex]::Escape($terminalOwnerShapeToken)).Count-eq2) 'terminal evidence owner must be validated once before repair and once after fail-closed downgrade'
            $terminalManifestToken="`$evidenceTerminalManifestChain=New-Q009OwnedChildManifestChainHead -RootPath `$EvidenceRoot -RootIdentity `$evidenceRootOwnership.root_identity -AttemptId `$attemptId -Boundary 'evidence_terminal_before_summary'"
            $summaryConstructionToken='$summary=[ordered]@{'
            Assert-LauncherContract ([regex]::Matches($runtimeEntrySource,[regex]::Escape($summaryConstructionToken)).Count-eq2) 'terminal evidence must construct both the qualifying summary and its fail-closed fallback'
            $summaryPublishToken='$summaryPublication=Publish-SummaryPairNoOverwrite $EvidenceRoot $summaryPath $summaryShaPath $summary $evidenceTerminalManifestChain $attemptId'
            $postSummaryManifestToken="`$postSummaryManifestChain=New-Q009OwnedChildManifestChainHead -RootPath `$EvidenceRoot -RootIdentity `$evidenceRootOwnership.root_identity -AttemptId `$attemptId -Boundary 'summary_published_under_exclusive'"
            $releaseShapeToken='if(-not(Test-Q009ReleaseEvidenceShape $preReleaseZeroGodot $runContext $heldExclusiveReceipt $pinned $dependencyPinReceipts))'
            $terminalCompletionToken='$terminalReceipt=[ordered]@{'
            $terminalCompletionShapeToken='if(-not(Test-Q009TerminalCompletionReceiptShape $terminalReceipt $runContext $heldExclusiveReceipt $summaryPublication $pinned $dependencyPinReceipts))'
            $terminalPublishToken="`$terminalPublication=Publish-SummaryPairNoOverwrite `$EvidenceRoot `$terminalPath `$terminalShaPath `$terminalReceipt `$postSummaryManifestChain `$attemptId -ArtifactName 'terminal.json'"
            $finalTreeToken='$finalEvidenceTree=Get-Q009ExactOwnedTreeManifest $EvidenceRoot'
            $finalTreeGateToken='Test-Q009TerminalTreeDelta $postSummaryManifestChain.manifest $finalEvidenceTree $terminalPublication'
            $summaryReceiptToken='$summaryReceiptHash=if($summaryPublished)'
            $getTerminalLifecyclePositions={
                param([string]$CandidateSource)
                return [ordered]@{
                    pre_publication=$CandidateSource.IndexOf($prePublicationToken,[StringComparison]::Ordinal)
                    terminal_safe=$CandidateSource.IndexOf($terminalSafeToken,[StringComparison]::Ordinal)
                    terminal_owner=$CandidateSource.IndexOf($terminalOwnerToken,[StringComparison]::Ordinal)
                    terminal_owner_shape=$CandidateSource.IndexOf($terminalOwnerShapeToken,[StringComparison]::Ordinal)
                    terminal_manifest=$CandidateSource.IndexOf($terminalManifestToken,[StringComparison]::Ordinal)
                    summary_construction=$CandidateSource.IndexOf($summaryConstructionToken,[StringComparison]::Ordinal)
                    summary_publish=$CandidateSource.IndexOf($summaryPublishToken,[StringComparison]::Ordinal)
                    post_summary_manifest=$CandidateSource.IndexOf($postSummaryManifestToken,[StringComparison]::Ordinal)
                    release_block=$CandidateSource.IndexOf('$preReleaseZeroGodot=Invoke-Q009MutexCritical',[StringComparison]::Ordinal)
                    release_shape=$CandidateSource.IndexOf($releaseShapeToken,[StringComparison]::Ordinal)
                    terminal_completion=$CandidateSource.IndexOf($terminalCompletionToken,[StringComparison]::Ordinal)
                    terminal_completion_shape=$CandidateSource.IndexOf($terminalCompletionShapeToken,[StringComparison]::Ordinal)
                    terminal_publish=$CandidateSource.IndexOf($terminalPublishToken,[StringComparison]::Ordinal)
                    final_tree=$CandidateSource.IndexOf($finalTreeToken,[StringComparison]::Ordinal)
                    final_tree_gate=$CandidateSource.IndexOf($finalTreeGateToken,[StringComparison]::Ordinal)
                    summary_receipt=$CandidateSource.IndexOf($summaryReceiptToken,[StringComparison]::Ordinal)
                }
            }
            $terminalLifecycle=&$getTerminalLifecyclePositions $runtimeEntrySource
            $terminalLifecycleOrdered=$terminalLifecycle.pre_publication-ge0-and$terminalLifecycle.terminal_safe-gt$terminalLifecycle.pre_publication-and$terminalLifecycle.terminal_owner-gt$terminalLifecycle.terminal_safe-and$terminalLifecycle.terminal_owner_shape-gt$terminalLifecycle.terminal_owner-and$terminalLifecycle.terminal_manifest-gt$terminalLifecycle.terminal_owner_shape-and$terminalLifecycle.summary_construction-gt$terminalLifecycle.terminal_manifest-and$terminalLifecycle.summary_publish-gt$terminalLifecycle.summary_construction-and$terminalLifecycle.post_summary_manifest-gt$terminalLifecycle.summary_publish-and$terminalLifecycle.release_block-gt$terminalLifecycle.post_summary_manifest-and$terminalLifecycle.release_shape-gt$releaseLeaseDeletePosition-and$terminalLifecycle.terminal_completion-gt$terminalLifecycle.release_shape-and$terminalLifecycle.terminal_completion_shape-gt$terminalLifecycle.terminal_completion-and$terminalLifecycle.terminal_publish-gt$terminalLifecycle.terminal_completion_shape-and$terminalLifecycle.final_tree-gt$terminalLifecycle.terminal_publish-and$terminalLifecycle.final_tree_gate-gt$terminalLifecycle.final_tree-and$terminalLifecycle.summary_receipt-gt$terminalLifecycle.final_tree_gate
            Assert-LauncherContract $terminalLifecycleOrdered 'qualifying runtime lost EXCLUSIVE-through-summary, exact release, terminal completion publication, or final whole-tree readback order'
            foreach($terminalToken in @($prePublicationToken,$terminalSafeToken,$terminalOwnerToken,$terminalOwnerShapeToken,$terminalManifestToken,$summaryConstructionToken,$summaryPublishToken,$postSummaryManifestToken,$releaseShapeToken,$terminalCompletionToken,$terminalCompletionShapeToken,$terminalPublishToken,$finalTreeToken,$finalTreeGateToken,$summaryReceiptToken)){
                $position=$runtimeEntrySource.IndexOf($terminalToken,[StringComparison]::Ordinal)
                Assert-LauncherContract ($position-ge0) "terminal evidence lifecycle token was absent before hostile mutation: $terminalToken"
                $mutated=if($terminalToken-in@($terminalOwnerShapeToken,$summaryConstructionToken)){$runtimeEntrySource.Replace($terminalToken,'')}else{$runtimeEntrySource.Remove($position,$terminalToken.Length)};$mutatedLifecycle=&$getTerminalLifecyclePositions $mutated
                $mutatedOrdered=$mutatedLifecycle.pre_publication-ge0-and$mutatedLifecycle.terminal_safe-gt$mutatedLifecycle.pre_publication-and$mutatedLifecycle.terminal_owner-gt$mutatedLifecycle.terminal_safe-and$mutatedLifecycle.terminal_owner_shape-gt$mutatedLifecycle.terminal_owner-and$mutatedLifecycle.terminal_manifest-gt$mutatedLifecycle.terminal_owner_shape-and$mutatedLifecycle.summary_construction-gt$mutatedLifecycle.terminal_manifest-and$mutatedLifecycle.summary_publish-gt$mutatedLifecycle.summary_construction-and$mutatedLifecycle.post_summary_manifest-gt$mutatedLifecycle.summary_publish-and$mutatedLifecycle.release_block-gt$mutatedLifecycle.post_summary_manifest-and$mutatedLifecycle.release_shape-gt$releaseLeaseDeletePosition-and$mutatedLifecycle.terminal_completion-gt$mutatedLifecycle.release_shape-and$mutatedLifecycle.terminal_completion_shape-gt$mutatedLifecycle.terminal_completion-and$mutatedLifecycle.terminal_publish-gt$mutatedLifecycle.terminal_completion_shape-and$mutatedLifecycle.final_tree-gt$mutatedLifecycle.terminal_publish-and$mutatedLifecycle.final_tree_gate-gt$mutatedLifecycle.final_tree-and$mutatedLifecycle.summary_receipt-gt$mutatedLifecycle.final_tree_gate
                Assert-LauncherContract (-not$mutatedOrdered) "terminal evidence source hostile still passed after removing $terminalToken"
            }
            $publicationFunction=@($runtimeAst.FindAll({param($node)$node-is[Management.Automation.Language.FunctionDefinitionAst]-and$node.Name-ceq'Publish-SummaryPairNoOverwrite'},$true))
            Assert-LauncherContract ($publicationFunction.Count-eq1) 'summary publication function extent was not unique'
            $publicationSource=$publicationFunction[0].Extent.Text
            $publicationAuthorizedManifestPosition=$publicationSource.IndexOf('$authorizedManifest=Get-Q009ExactOwnedTreeManifest $OwnedRoot',[StringComparison]::Ordinal)
            $publicationStageChainPosition=$publicationSource.IndexOf("-Boundary 'summary_pair_staged'",[StringComparison]::Ordinal)
            $publicationSidecarPosition=$publicationSource.IndexOf('Publish-Q009OwnedEvidenceArtifact -SourcePath $stageSha -DestinationPath $ShaPath',[StringComparison]::Ordinal)
            $publicationPrecommitPosition=$publicationSource.IndexOf("-Boundary 'summary_sidecar_committed_json_staged'",[StringComparison]::Ordinal)
            $publicationShapePosition=$publicationSource.IndexOf('Test-Q009SummaryPublicationReceiptShape $publication',[StringComparison]::Ordinal)
            $publicationJsonPosition=$publicationSource.IndexOf('Publish-Q009OwnedEvidenceArtifact -SourcePath $stageJson -DestinationPath $JsonPath',[StringComparison]::Ordinal)
            $publicationCommitPosition=$publicationSource.IndexOf('$committed=$true',[StringComparison]::Ordinal)
            Assert-LauncherContract ($publicationAuthorizedManifestPosition-ge0-and$publicationStageChainPosition-gt$publicationAuthorizedManifestPosition-and$publicationSidecarPosition-gt$publicationStageChainPosition-and$publicationPrecommitPosition-gt$publicationSidecarPosition-and$publicationShapePosition-gt$publicationPrecommitPosition-and$publicationJsonPosition-gt$publicationShapePosition-and$publicationCommitPosition-gt$publicationJsonPosition) 'summary publisher lost terminal-manifest admission, sidecar-first ordering, precommit seal, exact receipt validation, or final JSON commit ordering'
            $summaryStart=$runtimeSource.IndexOf('$summary=[ordered]@{',[StringComparison]::Ordinal);$summaryEnd=$runtimeSource.IndexOf('$summaryPublication=Publish-SummaryPairNoOverwrite',$summaryStart,[StringComparison]::Ordinal);Assert-LauncherContract ($summaryStart-ge0-and$summaryEnd-gt$summaryStart) 'summary source extent could not be isolated';$summarySource=$runtimeSource.Substring($summaryStart,$summaryEnd-$summaryStart);foreach($privateToken in @('cacheHandleCustody','native_cell','CacheCustodyCell','SafeFileHandle','IntPtr')){Assert-LauncherContract (-not$summarySource.Contains($privateToken)) "summary serializes private native custody token $privateToken"}
            foreach($needle in @('Global\BeatTheHouse-Q009-GodotLaunch','Assert-ExclusiveReservationOwned','Get-ExclusiveWaitDisposition','Assert-ExclusiveReady','Get-StrictGodotIdentityCensus','Get-StrictGlobalQuiescenceEvidence','Test-GlobalQuiescenceEvidenceShape','Assert-OwnedCacheAbsentImmediatelyBeforeImport','Assert-Q009PathAbsentStrict','Clear-ProvablyDeadWellFormedLeases','Get-CanonicalLeaseFilesStrict','Get-StrictLeaseOwnerRecord','Assert-PinnedFilesStable','Test-EnvironmentMatchesSnapshot','Get-Q009GdScriptTopLevelFunctionExtent','Get-Q009EnvironmentAuditTravelSourceIssues','Remove-ExactOwnedTree','Remove-Q009ExactOwnedTree','Remove-Q009ExactOwnedFile','New-Q009ExactOwnedDirectory','New-Q009ExactOwnedDirectoryHeld','New-Q009ExactOwnedFileHeld','Open-Q009ExactDirectoryHeld','Set-Q009HeldHandleDeletePending','Remove-Q009ManifestChildrenExceptSentinel','Close-Q009CheckedNativeHandle','Close-Q009AllOpenNativeHandles','Get-SentinelPinnedCacheProof','Invoke-Q009SentinelFilesystemCapabilityProbe','NtCreateFile(FILE_CREATE)','root_FILE_CREATE -> sentinel_relative_FILE_CREATE -> final_root_OPEN_EXISTING','sentinel_retained_through_phases','Get-FinalOwnedProcessResidualEvidence','Test-MayRemoveOwnedRuntimeArtifacts','Assert-ExactAttemptOwner','Assert-CanonicalLeaseRootPath','Assert-ExecutableIdentity','ExpectedGodotSha256','ExpectedPythonSha256','evidenceRootReady','Publish-SummaryPairNoOverwrite','Test-Q009SummaryPublicationReceiptShape','Test-Q009TerminalTreeDelta','Test-Q009PrePublicationCustodyShape','Test-Q009EvidenceTerminalOwnerReceiptShape','Test-Q009TerminalCompletionReceiptShape','Register-ProcessCustodyStart','process_start_provenance','pre_publication_custody','terminal_release_required','LoadAdmissionFunctionsOnly')){$sourceForNeedle=if($needle-ceq'NtCreateFile(FILE_CREATE)'){$supportSource}else{$runtimeSource};Assert-LauncherContract ($sourceForNeedle.Contains($needle)) "missing runtime seam $needle"}
            foreach($needle in @('New-Q009RunContext','New-Q009TrackedDependencyPins $pinned $runContext','Assert-Q009TrackedDependencyPinsStable $pinned $dependencyPins $runContext','Close-Q009TrackedDependencyPins $pinned $dependencyPins $runContext $dependencyPinReceipts','New-Q009HeldExclusiveLease','Close-Q009HeldExclusiveLease','New-Q009OwnedChildManifestChainHead','ExpectedExecutableIdentity $ExecutableIdentity','Get-FinalOwnedProcessResidualEvidence @($phases) $processCustody $runContext','Test-MayRemoveOwnedRuntimeArtifacts $finalOwnedProcessEvidence $runContext','evidence_terminal_before_summary','Publish-SummaryPairNoOverwrite $EvidenceRoot $summaryPath $summaryShaPath $summary $evidenceTerminalManifestChain $attemptId')){$sourceForNeedle=if($needle-ceq'ExpectedExecutableIdentity $ExecutableIdentity'){$runtimeSource}else{$runtimeEntrySource};Assert-LauncherContract ($sourceForNeedle.Contains($needle)) "qualifying runtime entry lost exact immutable custody seam $needle"}
            $staleExclusiveDelete='Remove-Q009ExactOwnedFile -Path $exclusiveLeasePath -ExpectedIdentity $record.file_identity'
            Assert-LauncherContract ([regex]::Matches($runtimeEntrySource,[regex]::Escape($staleExclusiveDelete)).Count-eq1-and$runtimeEntrySource.IndexOf($staleExclusiveDelete,[StringComparison]::Ordinal)-gt$runtimeEntrySource.IndexOf('$record=Get-StrictLeaseRecord $exclusiveLeasePath $runContext',[StringComparison]::Ordinal)) 'dead preexisting EXCLUSIVE cleanup lost its exact enumerated identity gate'
            foreach($forbiddenInvocation in @('New-TrackedExclusiveLeaseFile','Remove-Item','[IO.File]::Delete($exclusiveLeasePath)','[IO.Directory]::Delete($profileRoot')){Assert-LauncherContract (-not$runtimeEntrySource.Contains($forbiddenInvocation)) "qualifying runtime entry retained superseded path/PID custody seam $forbiddenInvocation"}
            foreach($removedSeam in @('Get-CacheCreationProof','RW06_1_CACHE_OWNER_CREATED','cache_create_error','rw06_1_cache_owner_bootstrap')){Assert-LauncherContract (-not$runtimeSource.Contains($removedSeam)) "timing/self-authored cache admission seam survived: $removedSeam"}
            foreach($needle in @('NativeHandleState','CLOSE_IN_PROGRESS','CLOSED_NATIVE_SUCCESS','CLOSE_FAILED_HANDLE_RETAINED','UNKNOWN','CacheCustodyCell','CreateDirectoryNewHeld','CreateFileNewHeld','OpenDirectoryHeldExact','MarkHeldHandleDeletePending','DeleteManifestChildrenExcept','CloseCheckedNativeHandle','Get-Q009ExactOwnedTreeManifest','Test-Q009CacheRootReceiptShape','Test-Q009SentinelReceiptShape','Test-Q009FinalRootReceiptShape','Test-Q009HeldHandleStateShape','Test-Q009ManifestCleanupReceiptShape','RenameEntryExactNoReplace','RenameEntryExactNoReplacePosix','MoveOwnedCleanupTreeToQuarantineNoReplace','DeleteEntryExact','DeleteTreeExact','ForceReplacementAfterFileCloseForTest','Get-LiveFocusedLeaseOwnerIdentities','ConvertTo-Q009StrictCimAncestryTable','Test-ProcessHasLeaseAncestor','NativeJobLauncher','CreateProcessW(CREATE_SUSPENDED)','AssignProcessToJobObject')){Assert-LauncherContract ($supportSource.Contains($needle)) "missing exact support seam $needle"}
            $auditSource=[IO.File]::ReadAllText($auditPath)
            Assert-LauncherContract (@(Get-Q009EnvironmentAuditTravelSourceIssues $auditSource).Count-eq0) 'environment audit travel source failed its function-scoped production-route contract'
            $misScoped=$auditSource.Replace('func _simulate_run(','func _misplaced_simulate_run(')+"`nfunc _simulate_run() -> void:`n`tpass`n"
            Assert-LauncherContract (@(Get-Q009EnvironmentAuditTravelSourceIssues $misScoped).Count-gt0) 'function-scoped route contract accepted the post-event producer in another function'
            $missingDeliveryGuard=$auditSource.Replace('if run_state != null and run_state.delivery_has_active_run():','if run_state != null and false:')
            Assert-LauncherContract (@(Get-Q009EnvironmentAuditTravelSourceIssues $missingDeliveryGuard).Count-gt0) 'function-scoped route contract accepted a missing delivery-overlay exclusion'
            $manualCatalog=$auditSource.Replace('return _production_foundation_travel_host(run_state)._travel_target_ids()','return WorldMapScript.travel_target_ids(run_state.world_map, run_state.current_world_node_id(), 2, 3, [])')
            Assert-LauncherContract (@(Get-Q009EnvironmentAuditTravelSourceIssues $manualCatalog).Count-gt0) 'function-scoped route contract accepted a hand-built target catalog'
            $extraEarlyReturn=$auditSource.Replace('func _travel_target_ids(run_state: RunState) -> Array:',"func _travel_target_ids(run_state: RunState) -> Array:`n`treturn []")
            Assert-LauncherContract (@(Get-Q009EnvironmentAuditTravelSourceIssues $extraEarlyReturn).Count-gt0) 'function-scoped route contract accepted an extra early return before the production view'
            $choiceAdapterBypass=$auditSource.Replace('return view_model_script.travel_choice(self, target_id, known_target_ids)','return {}')
            Assert-LauncherContract (@(Get-Q009EnvironmentAuditTravelSourceIssues $choiceAdapterBypass).Count-gt0) 'function-scoped route contract accepted a bypassed Foundation travel choice'
            $walkTimingBypass=$auditSource.Replace('const WALK_CLOCK_MINUTES_PER_BLOCK := 10','const WALK_CLOCK_MINUTES_PER_BLOCK := 6')
            Assert-LauncherContract (@(Get-Q009EnvironmentAuditTravelSourceIssues $walkTimingBypass).Count-gt0) 'function-scoped route contract accepted generator-style timing for authored Walk routes'
            $multilineAmbiguity='"""hostile`n'+$auditSource
            Assert-LauncherContract (@(Get-Q009EnvironmentAuditTravelSourceIssues $multilineAmbiguity).Count-gt0) 'function-scoped route contract accepted multiline-string source ambiguity'
        }

        $probe=Join-Path $tempRoot 'probe.ps1';$probeSource=@'
param([int]$ExitCode=0,[int]$SleepMsec=0,[int]$VolumeBytes=0,[string]$Echo='',[string]$Trailing='',[string]$Empty='unset',[string]$AbandonMutex='',[string]$SpawnChildPidPath='',[string]$SpawnIntermediatePidPath='',[string]$SpawnLeafPidPath='',[int]$ParentSleepMsec=10000,[int]$IntermediateSleepMsec=25,[int]$ChildSleepMsec=10000,[int]$LeafSleepMsec=10000)
function ConvertTo-ProbeNativeArgument([AllowEmptyString()][string]$Value){if($Value.Length-gt0-and$Value-notmatch'[\s"]'){return $Value};$builder=[Text.StringBuilder]::new();[void]$builder.Append([char]34);$slashes=0;foreach($character in $Value.ToCharArray()){if($character-eq[char]92){$slashes+=1;continue};if($character-eq[char]34){if($slashes-gt0){[void]$builder.Append([char]92,$slashes*2)};[void]$builder.Append([char]92);[void]$builder.Append([char]34);$slashes=0;continue};if($slashes-gt0){[void]$builder.Append([char]92,$slashes);$slashes=0};[void]$builder.Append($character)};if($slashes-gt0){[void]$builder.Append([char]92,$slashes*2)};[void]$builder.Append([char]34);return $builder.ToString()}
function Start-ProbeChild([string[]]$ChildArguments){$childInfo=[Diagnostics.ProcessStartInfo]::new();$childInfo.FileName=(Join-Path $PSHOME 'powershell.exe');$childInfo.Arguments=(@($ChildArguments|ForEach-Object{ConvertTo-ProbeNativeArgument ([string]$_)})-join' ');$childInfo.UseShellExecute=$false;$childInfo.CreateNoWindow=$true;return [Diagnostics.Process]::Start($childInfo)}
if(-not[string]::IsNullOrWhiteSpace($AbandonMutex)){$mutex=[Threading.Mutex]::new($false,$AbandonMutex);[void]$mutex.WaitOne();[Console]::Out.WriteLine('MUTEX_HELD');exit 0}
if(-not[string]::IsNullOrWhiteSpace($SpawnIntermediatePidPath)){$intermediate=Start-ProbeChild @('-NoProfile','-File',$PSCommandPath,'-SpawnLeafPidPath',$SpawnLeafPidPath,'-IntermediateSleepMsec',[string]$IntermediateSleepMsec,'-LeafSleepMsec',[string]$LeafSleepMsec);[IO.File]::WriteAllText($SpawnIntermediatePidPath,[string]$intermediate.Id,[Text.UTF8Encoding]::new($false));if($ParentSleepMsec-gt0){Start-Sleep -Milliseconds $ParentSleepMsec};exit 0}
if(-not[string]::IsNullOrWhiteSpace($SpawnLeafPidPath)){$leaf=Start-ProbeChild @('-NoProfile','-File',$PSCommandPath,'-SleepMsec',[string]$LeafSleepMsec);[IO.File]::WriteAllText($SpawnLeafPidPath,[string]$leaf.Id,[Text.UTF8Encoding]::new($false));if($IntermediateSleepMsec-gt0){Start-Sleep -Milliseconds $IntermediateSleepMsec};exit 0}
if(-not[string]::IsNullOrWhiteSpace($SpawnChildPidPath)){$child=Start-ProbeChild @('-NoProfile','-File',$PSCommandPath,'-SleepMsec',[string]$ChildSleepMsec);[IO.File]::WriteAllText($SpawnChildPidPath,[string]$child.Id,[Text.UTF8Encoding]::new($false));if($ParentSleepMsec-gt0){Start-Sleep -Milliseconds $ParentSleepMsec};exit 0}
if($SleepMsec -gt 0){Start-Sleep -Milliseconds $SleepMsec}
$payload=[ordered]@{echo=$Echo;trailing=$Trailing;empty=$Empty}|ConvertTo-Json -Compress
[Console]::Out.WriteLine($payload);[Console]::Error.WriteLine($payload)
if($VolumeBytes -gt 0){[Console]::Out.Write('O'*$VolumeBytes);[Console]::Error.Write('E'*$VolumeBytes);[Console]::Out.WriteLine('OUT_END');[Console]::Error.WriteLine('ERR_END')}
exit $ExitCode
'@;[IO.File]::WriteAllText($probe,$probeSource,[Text.UTF8Encoding]::new($false));$ps=Join-Path $PSHOME 'powershell.exe'
        Add-SelfTestResult $cases 'abandoned-launch-mutex-owned-release-and-fail-closed' { $name='Local\BeatTheHouse-Q009-hostile-'+[guid]::NewGuid().ToString('N');$parentHandle=[Threading.Mutex]::new($false,$name);$acquired=$false;try{$o=Join-Path $tempRoot 'abandoned.out';$e=Join-Path $tempRoot 'abandoned.err';$s=Start-RedirectedProcess $ps @('-NoProfile','-File',$probe,'-AbandonMutex',$name) $o $e Exact @() 10 -ExpectedExecutableIdentity $selfTestExecutableIdentity -RunContext $selfTestRunContext;$r=Complete-RedirectedProcess $s 10 Exact @() -RunContext $selfTestRunContext;Assert-LauncherContract ($r.native_exit_code-eq0-and[IO.File]::ReadAllText($o).Contains('MUTEX_HELD')) 'abandoned mutex child did not establish custody';$body=[ordered]@{ran=$false};$rejected=$false;try{[void](Invoke-Q009MutexCritical -Body {$body.ran=$true;throw 'BODY_EXECUTED'} -RunContext $selfTestRunContext -WaitMilliseconds 5000 -MutexName $name)}catch{$rejected=$_.Exception.Message.Contains('Q-009 launch mutex was abandoned')};Assert-LauncherContract ($rejected-and-not[bool]$body.ran) 'abandoned mutex did not fail closed before the body';try{$acquired=$parentHandle.WaitOne(1000)}catch [Threading.AbandonedMutexException] {throw 'abandoned state remained after guarded release'};Assert-LauncherContract $acquired 'recovered abandoned mutex ownership was not released'}finally{if($acquired){$parentHandle.ReleaseMutex()};$parentHandle.Dispose()} }
        Add-SelfTestResult $cases 'windows-argv-space-quote-trailing-slash-empty' { $o=Join-Path $tempRoot 'quote.out';$e=Join-Path $tempRoot 'quote.err';$s=Start-RedirectedProcess $ps @('-NoProfile','-File',$probe,'-Echo','space "quoted" value','-Trailing','C:\path with space\','-Empty','') $o $e Exact @() 10 -ExpectedExecutableIdentity $selfTestExecutableIdentity -RunContext $selfTestRunContext;$r=Complete-RedirectedProcess $s 10 Exact @() -RunContext $selfTestRunContext;Assert-LauncherContract ((Test-Q009CompletionResultShape $r)-and$r.native_exit_code -eq 0 -and $r.native_exit_type -ceq 'System.Int32' -and $r.native_exit_source -ceq 'owned_native_process_handle') 'short-lived quote probe exit was not bound to the exact native root handle';$t=[IO.File]::ReadAllText($o);Assert-LauncherContract ($t.Contains('space \"quoted\" value') -and $t.Contains('C:\\path with space\\') -and $t.Contains('"empty":""')) 'argv changed' }
        Add-SelfTestResult $cases 'dual-256k-pipes-and-nonzero-int-exit' { $o=Join-Path $tempRoot 'volume.out';$e=Join-Path $tempRoot 'volume.err';$s=Start-RedirectedProcess $ps @('-NoProfile','-File',$probe,'-ExitCode','37','-VolumeBytes','262144') $o $e Exact @() 15 -ExpectedExecutableIdentity $selfTestExecutableIdentity -RunContext $selfTestRunContext;$r=Complete-RedirectedProcess $s 15 Exact @() -RunContext $selfTestRunContext;Assert-LauncherContract ((Test-Q009CompletionResultShape $r)-and$r.native_exit_code -eq 37 -and $r.effective_exit_code -eq 37 -and $r.native_exit_type -ceq 'System.Int32') 'nonzero exit invalid';Assert-LauncherContract ((Get-Item $o).Length -ge 262144 -and (Get-Item $e).Length -ge 262144) 'dual streams truncated';Assert-LauncherContract ([IO.File]::ReadAllText($o).Contains('OUT_END') -and [IO.File]::ReadAllText($e).Contains('ERR_END')) 'end marker missing' }
        Add-SelfTestResult $cases 'owned-job-three-level-setup-exception-exact-python-godot' {
            foreach($kind in @('Exact','Python','Godot')){
                $prefix=('setup-three-'+$kind.ToLowerInvariant());$o=Join-Path $tempRoot ($prefix+'.out');$e=Join-Path $tempRoot ($prefix+'.err');$intermediatePidPath=Join-Path $tempRoot ($prefix+'-intermediate.pid');$leafPidPath=Join-Path $tempRoot ($prefix+'-leaf.pid');$caught=$null
                try{[void](Start-RedirectedProcess $ps @('-NoProfile','-File',$probe,'-SpawnIntermediatePidPath',$intermediatePidPath,'-SpawnLeafPidPath',$leafPidPath,'-ParentSleepMsec','10000','-IntermediateSleepMsec','25','-LeafSleepMsec','10000') $o $e $kind @() 15 -ForceSecondPumpFailureForTest -ForceIdentityCaptureFailureDelayMsecForTest 1000 -ExpectedExecutableIdentity $selfTestExecutableIdentity -RunContext $selfTestRunContext)}catch{$caught=$_.Exception}
                Assert-LauncherContract ($null-ne$caught) "$kind three-level setup exception did not occur"
                Assert-LauncherContract ((Test-Path -LiteralPath $intermediatePidPath -PathType Leaf)-and(Test-Path -LiteralPath $leafPidPath -PathType Leaf)) "$kind three-level setup fixture did not publish both descendant PIDs"
                $intermediatePid=[int][IO.File]::ReadAllText($intermediatePidPath);$leafPid=[int][IO.File]::ReadAllText($leafPidPath);$proof=Get-OwnedProcessStartProofFromException $caught
                $leafIdentities=@($proof.retained_descendant_identities|Where-Object{[int]$_.pid-eq$leafPid})
                Assert-LauncherContract ([bool]$proof.started-and[bool]$proof.start_observed-and[bool]$proof.identity_capture_complete-and[string]$proof.process_kind-ceq$kind-and[string]$proof.provenance-ceq'start_setup_exception'-and(Test-ProcessIdentityProofShape $proof.process_identity)) "$kind setup exception omitted exact start proof"
                Assert-LauncherContract ([bool]$proof.job_assignment_succeeded-and[bool]$proof.job_accounting_succeeded-and[bool]$proof.job_cleanup_succeeded-and[int]$proof.job_pretermination_active_process_count-gt0-and[int]$proof.job_pretermination_membership_count-gt0-and[int]$proof.job_final_active_process_count-eq0-and[bool]$proof.job_final_membership_empty-and$leafIdentities.Count-eq1) "$kind setup exception did not retain and empty its exact owned job"
                $cleanup=Invoke-ExactStartProofCleanup $proof $kind
                Assert-LauncherContract ([bool]$cleanup.clean-and@($cleanup.residual_identities).Count-eq0-and-not(Test-LiveProcessMatchesIdentity $proof.process_identity)-and$null-eq(Get-ProcessByIdStrict -ProcessId $intermediatePid)-and-not(Test-LiveProcessMatchesIdentity $leafIdentities[0])) ("$kind setup exception exact three-level re-cleanup failed: "+($cleanup|ConvertTo-Json -Compress -Depth 10))
            }
            $prefix='setup-native-post-wrapper';$o=Join-Path $tempRoot ($prefix+'.out');$e=Join-Path $tempRoot ($prefix+'.err');$intermediatePidPath=Join-Path $tempRoot ($prefix+'-intermediate.pid');$leafPidPath=Join-Path $tempRoot ($prefix+'-leaf.pid');$caught=$null
            try{[void](Start-RedirectedProcess $ps @('-NoProfile','-File',$probe,'-SpawnIntermediatePidPath',$intermediatePidPath,'-SpawnLeafPidPath',$leafPidPath,'-ParentSleepMsec','10000','-IntermediateSleepMsec','25','-LeafSleepMsec','10000') $o $e Exact @() 15 -ForceNativePostWrapperSetupFailureForTest -ExpectedExecutableIdentity $selfTestExecutableIdentity -RunContext $selfTestRunContext)}catch{$caught=$_.Exception}
            Assert-LauncherContract ($null-ne$caught-and(Test-Path -LiteralPath $intermediatePidPath -PathType Leaf)-and(Test-Path -LiteralPath $leafPidPath -PathType Leaf)) 'native post-wrapper setup hostile did not launch the full three-level fixture and throw'
            $intermediatePid=[int][IO.File]::ReadAllText($intermediatePidPath);$leafPid=[int][IO.File]::ReadAllText($leafPidPath);$proof=Get-OwnedProcessStartProofFromException $caught
            Assert-LauncherContract ([bool]$proof.started-and[bool]$proof.start_observed-and-not[bool]$proof.identity_capture_complete-and[bool]$proof.job_assignment_succeeded-and[bool]$proof.job_accounting_succeeded-and[bool]$proof.job_cleanup_succeeded-and[int]$proof.job_pretermination_active_process_count-gt0-and[int]$proof.job_pretermination_membership_count-gt0-and[int]$proof.job_final_active_process_count-eq0-and[bool]$proof.job_final_membership_empty-and[bool]$proof.root_handle_cleanup_succeeded) ('native post-wrapper setup exception did not prove exact job termination: '+($proof|ConvertTo-Json -Compress -Depth 10))
            Assert-LauncherContract ($null-eq(Get-ProcessByIdStrict -ProcessId $proof.process_id)-and$null-eq(Get-ProcessByIdStrict -ProcessId $intermediatePid)-and$null-eq(Get-ProcessByIdStrict -ProcessId $leafPid)) 'native post-wrapper setup exception left a root, intermediate, or leaf alive'
            $cleanup=Invoke-ExactStartProofCleanup $proof Exact
            Assert-LauncherContract ([bool]$cleanup.known_processes_clean-and-not[bool]$cleanup.physical_clean-and-not[bool]$cleanup.clean) 'native pre-return identity ambiguity was not kept fail-closed after exact job cleanup'
        }
        Add-SelfTestResult $cases 'true-post-start-property-failure-matrix-and-child-custody' {
            $proofs=[ordered]@{}
            foreach($point in @('no-id','after-id','after-start-time','after-name')){
                $o=Join-Path $tempRoot ("preidentity-$point.out");$e=Join-Path $tempRoot ("preidentity-$point.err");$caught=$null
                if($point-ceq'no-id'){try{[void](Start-RedirectedProcess $ps @('-NoProfile','-File',$probe,'-SleepMsec','10000') $o $e Exact @() 15 -ForceFailureImmediatelyAfterStartForTest -ExpectedExecutableIdentity $selfTestExecutableIdentity -RunContext $selfTestRunContext)}catch{$caught=$_.Exception}}
                elseif($point-ceq'after-id'){$childPidPath=Join-Path $tempRoot 'preidentity-child.pid';try{[void](Start-RedirectedProcess $ps @('-NoProfile','-File',$probe,'-SpawnChildPidPath',$childPidPath) $o $e Exact @() 15 -ForceFailureAfterProcessIdForTest -ForceIdentityCaptureFailureDelayMsecForTest 1500 -ExpectedExecutableIdentity $selfTestExecutableIdentity -RunContext $selfTestRunContext)}catch{$caught=$_.Exception}}
                elseif($point-ceq'after-start-time'){try{[void](Start-RedirectedProcess $ps @('-NoProfile','-File',$probe,'-SleepMsec','10000') $o $e Exact @() 15 -ForceFailureAfterStartTimeForTest -ExpectedExecutableIdentity $selfTestExecutableIdentity -RunContext $selfTestRunContext)}catch{$caught=$_.Exception}}
                else{try{[void](Start-RedirectedProcess $ps @('-NoProfile','-File',$probe,'-SleepMsec','10000') $o $e Exact @() 15 -ForceFailureAfterProcessNameForTest -ExpectedExecutableIdentity $selfTestExecutableIdentity -RunContext $selfTestRunContext)}catch{$caught=$_.Exception}}
                Assert-LauncherContract ($null-ne$caught) "post-start hostile did not throw at $point"
                $proof=Get-OwnedProcessStartProofFromException $caught;$proofs[$point]=$proof
                Assert-LauncherContract ([bool]$proof.started-and[bool]$proof.start_observed-and-not[bool]$proof.identity_capture_complete-and[bool]$proof.root_handle_cleanup_succeeded-and[bool]$proof.identity_ambiguity-and[string]$proof.provenance-ceq'start_before_identity_exception') "post-start proof was incomplete at $point"
                if($point-ceq'no-id'){Assert-LauncherContract (-not[bool]$proof.process_id_observed-and[int]$proof.process_id-eq0-and-not[bool]$proof.process_start_time_observed-and-not[bool]$proof.process_name_observed) 'immediate post-Start failure read an identity property'}
                elseif($point-ceq'after-id'){Assert-LauncherContract ([bool]$proof.process_id_observed-and[int]$proof.process_id-gt0-and-not[bool]$proof.process_start_time_observed-and-not[bool]$proof.process_name_observed) 'post-ID failure flags were wrong'}
                elseif($point-ceq'after-start-time'){Assert-LauncherContract ([bool]$proof.process_id_observed-and[bool]$proof.process_start_time_observed-and-not[bool]$proof.process_name_observed) 'post-StartTime failure flags were wrong'}
                else{Assert-LauncherContract ([bool]$proof.process_id_observed-and[bool]$proof.process_start_time_observed-and[bool]$proof.process_name_observed-and(Test-ProcessIdentityProofShape $proof.process_identity)) 'post-name failure did not retain observed exact identity'}
                $cleanup=Invoke-ExactStartProofCleanup $proof Exact
                Assert-LauncherContract ([bool]$cleanup.known_processes_clean-and-not[bool]$cleanup.physical_clean-and-not[bool]$cleanup.clean-and-not[bool]$cleanup.identity_capture_complete) "post-start ambiguity did not remain fail-closed at $point"
                if([int]$proof.process_id-gt0){Assert-LauncherContract ($null-eq(Get-ProcessByIdStrict -ProcessId $proof.process_id)) "post-start root survived at $point"}
            }
            Assert-LauncherContract (Test-Path -LiteralPath $childPidPath -PathType Leaf) 'post-ID hostile child did not publish its PID'
            $childPid=[int][IO.File]::ReadAllText($childPidPath);$childProof=$proofs['after-id']
            Assert-LauncherContract (@($childProof.retained_descendant_identities|Where-Object{[int]$_.pid-eq$childPid}).Count-eq1) ('post-ID child was not retained by the live-handle lineage proof: '+($childProof|ConvertTo-Json -Compress -Depth 10))
            Assert-LauncherContract ($null-eq(Get-ProcessByIdStrict -ProcessId $childPid)) 'post-ID exact child survived cleanup'
            $custody=[ordered]@{start_observed=$true;start_count=1;cleanup_count=0;cleanup_proved=$false};$cleanup=Invoke-ExactStartProofCleanup $childProof Exact
            $phase=New-Q009ClosedSetupFailurePhaseFixture 'preidentity-hostile' $childProof $cleanup $selfTestRunContext $selfTestExecutableIdentity
            $final=Get-FinalOwnedProcessResidualEvidence @($phase) $custody $selfTestRunContext
            Assert-LauncherContract (-not[bool]$final.clean-and-not(Test-MayRemoveOwnedRuntimeArtifacts $final $selfTestRunContext)-and-not(Test-MayReleaseExclusiveReservation $true $true $true $custody)) 'incomplete identity start allowed artifact cleanup or EXCLUSIVE release'
            $shapeProof=$proofs['after-name']
            foreach($mutation in @('bool-array','int-string','extra-key','missing-key','wrong-order')){
                $copy=$shapeProof|ConvertTo-Json -Depth 30|ConvertFrom-Json
                switch($mutation){
                    'bool-array'{$copy.started=[object[]]@($true)}
                    'int-string'{$copy.process_id=[string]$copy.process_id}
                    'extra-key'{$copy|Add-Member -NotePropertyName unexpected -NotePropertyValue $true}
                    'missing-key'{$copy.PSObject.Properties.Remove('process_kind')}
                    'wrong-order'{$reordered=[ordered]@{validation_error=[string]$copy.validation_error;receipt_valid=[bool]$copy.receipt_valid};foreach($key in @($copy.PSObject.Properties.Name|Where-Object{$_-notin@('validation_error','receipt_valid')})){$reordered[$key]=$copy.$key};$copy=$reordered}
                }
                Assert-LauncherContract (-not(Test-Q009StartProofShape $copy -AllowInvalid)) "closed start-proof schema accepted $mutation"
                $transport=[InvalidOperationException]::new('transport hostile');$transport.Data['owned_start_proof_receipt']=$copy
                $transported=Get-OwnedProcessStartProofFromException $transport
                Assert-LauncherContract (-not[bool]$transported.receipt_valid-and(Test-Q009StartProofShape $transported -AllowInvalid)) "malformed transported start proof was normalized into a valid receipt: $mutation"
            }
            foreach($mutation in @('cleanup-bool-array','cleanup-int-string','cleanup-extra','cleanup-missing','cleanup-wrong-order','phase-bool-array','phase-int-string','phase-extra','phase-missing','phase-wrong-order','residual-bool-array','residual-int-string','residual-context-array','residual-extra','residual-missing','residual-wrong-order')){
                if($mutation-like'cleanup-*'){
                    $copy=$cleanup|ConvertTo-Json -Depth 30|ConvertFrom-Json
                    switch($mutation){
                        'cleanup-bool-array'{$copy.clean=[object[]]@($false)}
                        'cleanup-int-string'{$copy.job_final_active_process_count=[string]$copy.job_final_active_process_count}
                        'cleanup-extra'{$copy|Add-Member -NotePropertyName unexpected -NotePropertyValue $true}
                        'cleanup-missing'{$copy.PSObject.Properties.Remove('known_processes_clean')}
                        'cleanup-wrong-order'{$reordered=[ordered]@{proved_identities=$copy.proved_identities;attempted_keys=$copy.attempted_keys};foreach($key in @($copy.PSObject.Properties.Name|Where-Object{$_-notin@('proved_identities','attempted_keys')})){$reordered[$key]=$copy.$key};$copy=$reordered}
                    }
                    Assert-LauncherContract (-not(Test-Q009SetupCleanupReceiptShape $copy)) "setup-cleanup schema accepted $mutation"
                }elseif($mutation-like'phase-*'){
                    $copy=$phase|ConvertTo-Json -Depth 50|ConvertFrom-Json
                    switch($mutation){
                        'phase-bool-array'{$copy.timed_out=[object[]]@($false)}
                        'phase-int-string'{$copy.effective_exit_code=[string]$copy.effective_exit_code}
                        'phase-extra'{$copy|Add-Member -NotePropertyName unexpected -NotePropertyValue $true}
                        'phase-missing'{$copy.PSObject.Properties.Remove('run_context_sha256')}
                        'phase-wrong-order'{$reordered=[ordered]@{process_kind=$copy.process_kind;name=$copy.name};foreach($key in @($copy.PSObject.Properties.Name|Where-Object{$_-notin@('process_kind','name')})){$reordered[$key]=$copy.$key};$copy=$reordered}
                    }
                    Assert-LauncherContract (-not(Test-Q009PhaseReceiptShape $copy $selfTestRunContext)) "phase schema accepted $mutation"
                }else{
                    $copy=$final|ConvertTo-Json -Depth 30|ConvertFrom-Json
                    switch($mutation){
                        'residual-bool-array'{$copy.checked=[object[]]@($true)}
                        'residual-int-string'{$copy.started_phase_count=[string]$copy.started_phase_count}
                        'residual-context-array'{$copy.run_context_sha256=[object[]]@([string]$copy.run_context_sha256)}
                        'residual-extra'{$copy|Add-Member -NotePropertyName unexpected -NotePropertyValue $true}
                        'residual-missing'{$copy.PSObject.Properties.Remove('proof_issues')}
                        'residual-wrong-order'{$reordered=[ordered]@{run_context_sha256=$copy.run_context_sha256;checked=$copy.checked};foreach($key in @($copy.PSObject.Properties.Name|Where-Object{$_-notin@('run_context_sha256','checked')})){$reordered[$key]=$copy.$key};$copy=$reordered}
                    }
                    Assert-LauncherContract (-not(Test-MayRemoveOwnedRuntimeArtifacts $copy $selfTestRunContext)) "destructive removal gate accepted $mutation"
                }
            }
        }
        Add-SelfTestResult $cases 'owned-job-three-level-normal-exact-python-godot' {
            foreach($kind in @('Exact','Python','Godot')){
                $prefix=('normal-three-'+$kind.ToLowerInvariant());$o=Join-Path $tempRoot ($prefix+'.out');$e=Join-Path $tempRoot ($prefix+'.err');$intermediatePidPath=Join-Path $tempRoot ($prefix+'-intermediate.pid');$leafPidPath=Join-Path $tempRoot ($prefix+'-leaf.pid')
                $s=Start-RedirectedProcess $ps @('-NoProfile','-File',$probe,'-SpawnIntermediatePidPath',$intermediatePidPath,'-SpawnLeafPidPath',$leafPidPath,'-ParentSleepMsec','750','-IntermediateSleepMsec','25','-LeafSleepMsec','10000') $o $e $kind @() 10 -ExpectedExecutableIdentity $selfTestExecutableIdentity -RunContext $selfTestRunContext;$rootIdentity=$s.process_identity
                $r=Complete-RedirectedProcess $s 10 $kind @() -RunContext $selfTestRunContext;Assert-LauncherContract ((Test-Q009CompletionResultShape $r)-and(Test-Path -LiteralPath $intermediatePidPath -PathType Leaf)-and(Test-Path -LiteralPath $leafPidPath -PathType Leaf)) "$kind normal three-level fixture did not publish both descendant PIDs"
                $intermediatePid=[int][IO.File]::ReadAllText($intermediatePidPath);$leafPid=[int][IO.File]::ReadAllText($leafPidPath);$leafIdentities=@($r.retained_descendant_identities|Where-Object{[int]$_.pid-eq$leafPid})
                Assert-LauncherContract ($r.native_exit_code-eq0-and-not$r.timed_out-and[bool]$r.job_assignment_succeeded-and[bool]$r.job_accounting_succeeded-and[bool]$r.job_cleanup_succeeded-and[int]$r.job_pretermination_active_process_count-gt0-and[int]$r.job_pretermination_membership_count-gt0-and[int]$r.job_final_active_process_count-eq0-and[bool]$r.job_final_membership_empty-and$leafIdentities.Count-eq1) "$kind normal completion did not retain and empty the three-level owned job"
                $retained=[Collections.Generic.List[object]]::new();foreach($identity in @($r.retained_descendant_identities)){[void]$retained.Add($identity)};$residuals=@(Get-ExactOwnedProcessResidualPids -RootIdentity $rootIdentity -BaselineIdentityKeys @() -RetainedDescendantRecords $retained)
                Assert-LauncherContract ($residuals.Count-eq0-and-not(Test-LiveProcessMatchesIdentity $rootIdentity)-and$null-eq(Get-ProcessByIdStrict -ProcessId $intermediatePid)-and-not(Test-LiveProcessMatchesIdentity $leafIdentities[0])) "$kind normal completion failed exact root/intermediate/leaf residual proof"
            }
        }
        Add-SelfTestResult $cases 'owned-job-three-level-timeout-124-exact-python-godot' {
            foreach($kind in @('Exact','Python','Godot')){
                $prefix=('timeout-three-'+$kind.ToLowerInvariant());$o=Join-Path $tempRoot ($prefix+'.out');$e=Join-Path $tempRoot ($prefix+'.err');$intermediatePidPath=Join-Path $tempRoot ($prefix+'-intermediate.pid');$leafPidPath=Join-Path $tempRoot ($prefix+'-leaf.pid')
                $s=Start-RedirectedProcess $ps @('-NoProfile','-File',$probe,'-SpawnIntermediatePidPath',$intermediatePidPath,'-SpawnLeafPidPath',$leafPidPath,'-ParentSleepMsec','10000','-IntermediateSleepMsec','25','-LeafSleepMsec','10000') $o $e $kind @() 1 -ExpectedExecutableIdentity $selfTestExecutableIdentity -RunContext $selfTestRunContext;$rootIdentity=$s.process_identity
                $r=Complete-RedirectedProcess $s 1 $kind @() -RunContext $selfTestRunContext;Assert-LauncherContract ((Test-Q009CompletionResultShape $r)-and(Test-Path -LiteralPath $intermediatePidPath -PathType Leaf)-and(Test-Path -LiteralPath $leafPidPath -PathType Leaf)) "$kind timeout three-level fixture did not publish both descendant PIDs"
                $intermediatePid=[int][IO.File]::ReadAllText($intermediatePidPath);$leafPid=[int][IO.File]::ReadAllText($leafPidPath);$leafIdentities=@($r.retained_descendant_identities|Where-Object{[int]$_.pid-eq$leafPid})
                Assert-LauncherContract ($r.timed_out-and$r.effective_exit_code-eq124-and[bool]$r.job_assignment_succeeded-and[bool]$r.job_accounting_succeeded-and[bool]$r.job_cleanup_succeeded-and[int]$r.job_pretermination_active_process_count-gt0-and[int]$r.job_pretermination_membership_count-gt0-and[int]$r.job_final_active_process_count-eq0-and[bool]$r.job_final_membership_empty-and$leafIdentities.Count-eq1) "$kind timeout did not retain and empty the three-level owned job"
                $retained=[Collections.Generic.List[object]]::new();foreach($identity in @($r.retained_descendant_identities)){[void]$retained.Add($identity)};$residuals=@(Get-ExactOwnedProcessResidualPids -RootIdentity $rootIdentity -BaselineIdentityKeys @() -RetainedDescendantRecords $retained)
                Assert-LauncherContract ($residuals.Count-eq0-and-not(Test-LiveProcessMatchesIdentity $rootIdentity)-and$null-eq(Get-ProcessByIdStrict -ProcessId $intermediatePid)-and-not(Test-LiveProcessMatchesIdentity $leafIdentities[0])) "$kind timeout failed exact root/intermediate/leaf residual proof"
            }
        }
        Add-SelfTestResult $cases 'tip-blob-environment-drift-pure-guards' {
            $snap=Get-EnvironmentSnapshot;Assert-LauncherContract (Test-EnvironmentMatchesSnapshot $snap) 'baseline environment rejected'
            $fake=[ordered]@{path=$manifestRelativePath;sha256='BAD';git_blob=$expectedManifestBlob};$failed=$false
            try{Assert-PinnedFilesStable ([ordered]@{manifest=$fake}) $selfTestRunContext}catch{$failed=$true};Assert-LauncherContract $failed 'raw drift accepted'
            $fake.sha256=(Get-FileHash $manifestPath -Algorithm SHA256).Hash;$fake.git_blob='BAD';$failed=$false
            try{Assert-PinnedFilesStable ([ordered]@{manifest=$fake}) $selfTestRunContext}catch{$failed=$true};Assert-LauncherContract $failed 'blob drift accepted'
            $pinRoot=Join-Path (Join-Path $projectRoot '.tmp') ('rw06-q009-dependency-pin-'+[guid]::NewGuid().ToString('N'));$pinRootIdentity=New-Q009ExactOwnedDirectory $pinRoot
            $pinPath=Join-Path $pinRoot 'tracked-dependency-pin.txt';$pinOwnership=[ordered]@{created=$false;identity=$null;write_complete=$false;removal_failed=$false;removal_error=''};New-OwnedLeaseFile $pinPath 'held dependency bytes' $pinOwnership
            $pinRelative=$pinPath.Substring($projectRoot.Length).TrimStart('\','/').Replace('\','/');$pinTracked=[ordered]@{probe=[ordered]@{path=$pinRelative;git_blob='0'*40;length=[long](Get-Item $pinPath).Length;sha256=(Get-FileHash $pinPath -Algorithm SHA256).Hash}}
            $pinSet=$null;$pinReceipts=$null;$pinReleases=$null
            try{
                $pinSet=New-Q009TrackedDependencyPins $pinTracked $selfTestRunContext;$pinReceipts=Assert-Q009TrackedDependencyPinsStable $pinTracked $pinSet $selfTestRunContext
                $writeDenied=$false;$moveDenied=$false;try{[IO.File]::WriteAllText($pinPath,'foreign')}catch{$writeDenied=$true};try{[IO.File]::Move($pinPath,$pinPath+'.moved')}catch{$moveDenied=$true}
                Assert-LauncherContract ($writeDenied-and$moveDenied-and(Test-Q009FileSystemIdentityMatch $pinOwnership.identity)) 'held tracked dependency allowed write/delete-share replacement'
                $pinReleases=Close-Q009TrackedDependencyPins $pinTracked $pinSet $selfTestRunContext $pinReceipts;Assert-LauncherContract (Test-Q009TrackedDependencyPinReleasesShape $pinReleases $pinReceipts $pinTracked $selfTestRunContext) 'tracked dependency release receipts were malformed'
            }finally{
                if($null-ne$pinSet-and-not[bool]$pinSet.probe.released){try{[void](Close-Q009ExecutablePin $pinSet.probe ([string]$selfTestRunContext.attempt_id))}catch{}}
                if((Test-Path -LiteralPath $pinPath -PathType Leaf)-and$null-ne$pinOwnership.identity-and(Test-Q009FileSystemIdentityMatch $pinOwnership.identity)){Remove-Q009ExactOwnedFile $pinPath $pinOwnership.identity}
                if((Test-Path -LiteralPath $pinRoot -PathType Container)-and(Test-Q009FileSystemIdentityMatch $pinRootIdentity)){[void](Remove-ValidateOnlyOwnedTree $projectRoot $pinRoot $pinRootIdentity $selfTestRunContext $selfTestOwnerReceipt)}
            }
            $prior=[Environment]::GetEnvironmentVariable('XDG_CONFIG_HOME','Process');try{[Environment]::SetEnvironmentVariable('XDG_CONFIG_HOME',(Join-Path $tempRoot 'drift'),'Process');Assert-LauncherContract (-not(Test-EnvironmentMatchesSnapshot $snap)) 'environment drift accepted'}finally{[Environment]::SetEnvironmentVariable('XDG_CONFIG_HOME',$prior,'Process')}
        }
        Add-SelfTestResult $cases 'exact-remote-tip-not-ancestor-or-symbolic' { $commit='aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';$ancestor='bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';$rows=@("$ancestor|refs/remotes/origin/topic|","$commit|refs/remotes/origin/HEAD|refs/remotes/origin/main","$commit|refs/remotes/origin/exact|");$refs=@(Select-ExactRemoteCandidateRefs $rows $commit);Assert-LauncherContract ($refs.Count-eq1-and$refs[0]-ceq'refs/remotes/origin/exact') 'exact remote-tip predicate accepted ancestor/symbolic or lost exact ref';Assert-LauncherContract (@(Select-ExactRemoteCandidateRefs @("$ancestor|refs/remotes/origin/topic|") $commit).Count-eq0) 'ancestor-only remote accepted' }
        Add-SelfTestResult $cases 'static-count-schema-json-fraction-finite-range-and-identity' { $countNames=@('active_bindings','active_nonphysical','active_nonphysical_room','active_overflow','active_physical_room','active_snapshots','archetypes','authored_actions','authored_visuals','base_base_conflicts','base_base_pair_tests','base_label_slots','base_scenario_authorities','base_scenario_base_slot_observations','base_scenario_conflicts','base_scenario_legal_scenarios','base_scenario_pair_tests','base_scenario_snapshots','complete_bindings','complete_overflow','complete_snapshots','historical_exact_seeds','historical_legal_room_combinations','legal_hosts','mandatory_lane_obstacle_checks','mandatory_lane_obstacle_states','mandatory_lane_overflow_states','maps','scenarios');$counts=[ordered]@{};foreach($name in $countNames){$counts[$name]=1};$jsonFraction=('{"rate":0.125}'|ConvertFrom-Json).rate;Assert-LauncherContract ($jsonFraction-is[decimal]-or$jsonFraction-is[double]) 'PS5.1 JSON fraction was not Decimal/Double';$counts.active_overflow_rate=$jsonFraction;$counts.maps=21;$counts.archetypes=18;$counts.scenarios=55;$counts.legal_hosts=55;$counts.historical_exact_seeds=22;$counts.historical_legal_room_combinations=1;$active=@(1..55|ForEach-Object{[pscustomobject]@{map_id=('map'+$_);scenario_id=('scenario'+$_)}});$contact=@([pscustomobject]@{archetype_id='bar';day2_sample=$true},[pscustomobject]@{archetype_id='corner_store';day2_sample=$true},[pscustomobject]@{archetype_id='grand_casino';day2_sample=$true})+@(4..18|ForEach-Object{[pscustomobject]@{archetype_id=('room'+$_);day2_sample=$false}});$good=[pscustomobject]@{tool='environment_fixed_slot_static_check';passed=$true;error_count=0;errors=[object[]]@();counts=[pscustomobject]$counts;day2_samples=[object[]]@([pscustomobject]@{map_id='corner_store'},[pscustomobject]@{map_id='bar'},[pscustomobject]@{map_id='grand_casino'});contact_sheet=[object[]]$contact;active_scenarios=[object[]]$active;complete_scenarios=[object[]]@($active|ForEach-Object{[pscustomobject]@{map_id=$_.map_id;scenario_id=$_.scenario_id}})};Assert-LauncherContract (@(Get-StaticReportIssues $good).Count-eq0) 'valid static shape with parsed JSON fraction rejected';foreach($badRate in @([int]1,'0.125',[double]::NaN,[double]::PositiveInfinity,[double]-0.1,[double]1.1)){$good.counts.active_overflow_rate=$badRate;Assert-LauncherContract (@(Get-StaticReportIssues $good).Count-gt0) "invalid overflow rate accepted: $badRate"};$good.counts.active_overflow_rate=$jsonFraction;$good.counts.maps='21';Assert-LauncherContract (@(Get-StaticReportIssues $good).Count-gt0) 'wrong count type accepted';$good.counts.maps=21;$good.complete_scenarios[1]=$good.complete_scenarios[0];Assert-LauncherContract (@(Get-StaticReportIssues $good).Count-gt0) 'duplicate scenario identity accepted';$good.complete_scenarios=[object[]]@($active|ForEach-Object{[pscustomobject]@{map_id=$_.map_id;scenario_id=$_.scenario_id}});foreach($mutation in @('tool','active-map','complete-scenario','contact-archetype','day2-map')){$copy=$good|ConvertTo-Json -Depth 100|ConvertFrom-Json;switch($mutation){'tool'{$copy.tool=[object[]]@('environment_fixed_slot_static_check')}'active-map'{$copy.active_scenarios[0].map_id=[object[]]@('map1')}'complete-scenario'{$copy.complete_scenarios[0].scenario_id=[object[]]@('scenario1')}'contact-archetype'{$copy.contact_sheet[0].archetype_id=[object[]]@('bar')}'day2-map'{$copy.day2_samples[0].map_id=[object[]]@('corner_store')}};Assert-LauncherContract (@(Get-StaticReportIssues $copy).Count-gt0) "static one-element string array accepted: $mutation"};$good|Add-Member -NotePropertyName extra -NotePropertyValue 1;Assert-LauncherContract (@(Get-StaticReportIssues $good).Count-gt0) 'extra top-level field accepted' }
        Add-SelfTestResult $cases 'summary-pair-staging-collisions-and-commit-marker' {
            $value=[ordered]@{passed=$true;outcome='pass'}
            $newAuthority={
                param([string]$Name)
                $root=Join-Path $tempRoot $Name
                $identity=New-Q009ExactOwnedDirectory $root
                $owner=[ordered]@{run_context_sha256=[string]$selfTestRunContext.context_sha256;case_name=[string]$Name;root_identity=$identity}
                $chain=New-Q009OwnedChildManifestChainHead -RootPath $root -RootIdentity $identity -AttemptId $selfTestRunContext.attempt_id -Boundary 'summary_test_terminal' -OwnerKind launcher_fixture -OwnerReceipt $owner
                return [ordered]@{root=$root;identity=$identity;chain=$chain}
            }
            $success=&$newAuthority 'summary-success'
            $published=Publish-SummaryPairNoOverwrite $success.root (Join-Path $success.root 'summary.json') (Join-Path $success.root 'summary.sha256') $value $success.chain $selfTestRunContext.attempt_id
            Assert-LauncherContract ((Test-Q009SummaryPublicationReceiptShape $published)-and(Test-Path (Join-Path $success.root 'summary.json'))-and(Test-Path (Join-Path $success.root 'summary.sha256'))) 'summary pair success did not publish its exact closed receipt and both files'
            $actual=(Get-FileHash (Join-Path $success.root 'summary.json') -Algorithm SHA256).Hash.ToUpperInvariant()
            Assert-LauncherContract ([string]$published.sha256-ceq$actual-and[IO.File]::ReadAllText((Join-Path $success.root 'summary.sha256')).StartsWith($actual+'  summary.json')) 'summary sidecar did not bind exact JSON'
            foreach($mutation in @('published-array','json-length-string','extra-key','missing-key','wrong-order')){
                $copy=[ordered]@{published=[bool]$published.published;sha256=[string]$published.sha256;precommit_manifest_head_sha256=[string]$published.precommit_manifest_head_sha256;json=[ordered]@{path=[string]$published.json.path;identity=$published.json.identity;present=[bool]$published.json.present;length=[long]$published.json.length;sha256=[string]$published.json.sha256};sidecar=[ordered]@{path=[string]$published.sidecar.path;identity=$published.sidecar.identity;present=[bool]$published.sidecar.present;length=[long]$published.sidecar.length;sha256=[string]$published.sidecar.sha256}}
                switch($mutation){
                    'published-array'{$copy.published=[object[]]@($true)}
                    'json-length-string'{$copy.json.length=[string]$copy.json.length}
                    'extra-key'{$copy.unexpected=$true}
                    'missing-key'{$copy.Remove('precommit_manifest_head_sha256')}
                    'wrong-order'{$copy=[ordered]@{sha256=[string]$copy.sha256;published=[bool]$copy.published;precommit_manifest_head_sha256=[string]$copy.precommit_manifest_head_sha256;json=$copy.json;sidecar=$copy.sidecar}}
                }
                Assert-LauncherContract (-not(Test-Q009SummaryPublicationReceiptShape $copy)) "summary publication receipt accepted $mutation"
            }
            $stageFail=&$newAuthority 'summary-stage-fail';$failed=$false
            try{[void](Publish-SummaryPairNoOverwrite $stageFail.root (Join-Path $stageFail.root 'summary.json') (Join-Path $stageFail.root 'summary.sha256') $value $stageFail.chain $selfTestRunContext.attempt_id -ForceSidecarStageFailureForTest)}catch{$failed=$true}
            Assert-LauncherContract ($failed-and-not(Test-Path (Join-Path $stageFail.root 'summary.json'))-and-not(Test-Path (Join-Path $stageFail.root 'summary.sha256'))) 'sidecar staging failure exposed a final artifact'
            $sideCollision=&$newAuthority 'summary-side-collision';$failed=$false
            try{[void](Publish-SummaryPairNoOverwrite $sideCollision.root (Join-Path $sideCollision.root 'summary.json') (Join-Path $sideCollision.root 'summary.sha256') $value $sideCollision.chain $selfTestRunContext.attempt_id -ForceSidecarMoveCollisionForTest)}catch{$failed=$true}
            Assert-LauncherContract ($failed-and-not(Test-Path (Join-Path $sideCollision.root 'summary.json'))-and[IO.File]::ReadAllText((Join-Path $sideCollision.root 'summary.sha256'))-ceq'foreign') 'sidecar collision exposed PASS JSON or removed the foreign destination'
            $jsonFail=&$newAuthority 'summary-json-fail';$failed=$false
            try{[void](Publish-SummaryPairNoOverwrite $jsonFail.root (Join-Path $jsonFail.root 'summary.json') (Join-Path $jsonFail.root 'summary.sha256') $value $jsonFail.chain $selfTestRunContext.attempt_id -ForceJsonPublishFailureForTest)}catch{$failed=$true}
            Assert-LauncherContract ($failed-and-not(Test-Path (Join-Path $jsonFail.root 'summary.json'))-and(Test-Path (Join-Path $jsonFail.root 'summary.sha256'))) 'JSON publication failure exposed PASS JSON or lost commit ordering'
            $drift=&$newAuthority 'summary-terminal-drift';[IO.File]::WriteAllText((Join-Path $drift.root 'foreign-after-terminal.txt'),'foreign');$failed=$false
            try{[void](Publish-SummaryPairNoOverwrite $drift.root (Join-Path $drift.root 'summary.json') (Join-Path $drift.root 'summary.sha256') $value $drift.chain $selfTestRunContext.attempt_id)}catch{$failed=$true}
            Assert-LauncherContract ($failed-and-not(Test-Path (Join-Path $drift.root 'summary.json'))-and(Test-Path (Join-Path $drift.root 'foreign-after-terminal.txt'))) 'terminal evidence-root manifest drift was accepted or foreign evidence was removed'
        }
    } finally {
        try{
            if((Test-Path -LiteralPath $tempRoot)-and$null-ne$tempRootIdentity){
                $cleanupOwner=if($null-ne$selfTestOwnerReceipt){$selfTestOwnerReceipt}else{[ordered]@{scope='ValidateOnly';attempt_id=[string]$selfTestAttemptId;root_identity=$tempRootIdentity}}
                $cleanupChain=New-Q009OwnedChildManifestChainHead -RootPath $tempRoot -RootIdentity $tempRootIdentity -AttemptId $selfTestAttemptId -Boundary 'validate_only_outer_finally' -OwnerKind launcher_fixture -OwnerReceipt $cleanupOwner
                [void](Remove-ExactOwnedTree -Root $tempParent -Path $tempRoot -ExpectedRootIdentity $tempRootIdentity -AuthorizedChainHead $cleanupChain -ExpectedAttemptId $selfTestAttemptId)
            }
            if(Test-Path -LiteralPath $tempRoot){throw 'ValidateOnly exact-owned temporary root remained after cleanup'}
        }catch{
            [Console]::Error.WriteLine('ValidateOnly exact-owned cleanup failed closed: '+$_.Exception.Message)
            exit 1
        }
    }
    $failedCases=@($cases|Where-Object{-not $_.passed})
    $report=[ordered]@{
        tool='rw06_1_environment_qualifying_supervisor_selftest';schema_version=2;marker='RW06_1_Q009_VALIDATE_ONLY_PASS';passed=($failedCases.Count-eq0);mode=$Mode;godot_started=$false;canonical_lease_touched=$false;canonical_cache_touched=$false;case_count=$cases.Count;case_names=@($cases|ForEach-Object{[string]$_.name});cases=@($cases)
        hashes=[ordered]@{
            launcher_sha256=(Get-FileHash $PSCommandPath -Algorithm SHA256).Hash;launcher_git_blob=(&git -C $projectRoot hash-object -- $PSCommandPath).Trim()
            support_sha256=(Get-FileHash $supportPath -Algorithm SHA256).Hash;support_git_blob=(&git -C $projectRoot hash-object -- $supportPath).Trim()
            manifest_sha256=(Get-FileHash $manifestPath -Algorithm SHA256).Hash;manifest_git_blob=(&git -C $projectRoot hash-object -- $manifestPath).Trim()
            audit_gd_sha256=(Get-FileHash $auditPath -Algorithm SHA256).Hash;audit_gd_git_blob=(&git -C $projectRoot hash-object -- $auditPath).Trim()
            static_checker_sha256=(Get-FileHash $staticCheckerPath -Algorithm SHA256).Hash;static_checker_git_blob=(&git -C $projectRoot hash-object -- $staticCheckerPath).Trim()
            scenario_catalog_sha256=(Get-FileHash $scenarioPath -Algorithm SHA256).Hash;scenario_catalog_git_blob=(&git -C $projectRoot hash-object -- $scenarioPath).Trim()
            fidelity_helper_sha256=(Get-FileHash (Join-Path $projectRoot ($fidelityRelativePath.Replace('/','\'))) -Algorithm SHA256).Hash;fidelity_helper_git_blob=(&git -C $projectRoot hash-object -- (Join-Path $projectRoot ($fidelityRelativePath.Replace('/','\')))).Trim()
            foundation_travel_view_model_sha256=(Get-FileHash $foundationTravelPath -Algorithm SHA256).Hash;foundation_travel_view_model_git_blob=(&git -C $projectRoot hash-object -- $foundationTravelPath).Trim()
            tutorial_flow_sha256=(Get-FileHash $tutorialFlowPath -Algorithm SHA256).Hash;tutorial_flow_git_blob=(&git -C $projectRoot hash-object -- $tutorialFlowPath).Trim()
            attribute_badges_sha256=(Get-FileHash $attributeBadgesPath -Algorithm SHA256).Hash;attribute_badges_git_blob=(&git -C $projectRoot hash-object -- $attributeBadgesPath).Trim()
        }
        completed_utc=[DateTime]::UtcNow.ToString('o')
    }
    $reportReceipt=Write-AtomicJson $reportPath $report
    if($failedCases.Count -gt 0){foreach($case in $failedCases){[Console]::Error.WriteLine("SELFTEST FAIL $($case.name): $($case.detail)")};exit 1}
    Write-Host ("RW06_1_Q009_VALIDATE_ONLY_PASS report={0} cases={1} sha256={2} native_key={3} creation_ticks={4}"-f$reportReceipt.path,$cases.Count,$reportReceipt.sha256,$reportReceipt.identity.native_key,$reportReceipt.identity.creation_ticks);exit 0
}

if($LoadAdmissionFunctionsOnly){return}
if($ValidateOnly){Invoke-ValidateOnlySelfTest}

$stamp=[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ');$attemptId=('rw06-1-{0}-{1}-{2}' -f $Mode,$stamp,[guid]::NewGuid().ToString('N'))
$startedUtc=[DateTime]::UtcNow;$overallExit=1;$outcome='invalid';$launcherError='';$evidenceRootReady=$false;$summaryPublished=$false
$requestedEvidenceRoot=$EvidenceRoot;$preRootError='';$tmpRoot=[IO.Path]::GetFullPath((Join-Path $projectRoot '.tmp')).TrimEnd('\','/');$legacyRoot=[IO.Path]::GetFullPath((Join-Path $projectRoot '.tmp\rw06_1\exact_seed')).TrimEnd('\','/')
try{
    if([string]::IsNullOrWhiteSpace($EvidenceRoot)){$EvidenceRoot=Join-Path $projectRoot ('.tmp\rw06_1\qualified\{0}' -f $attemptId)}
    $EvidenceRoot=[IO.Path]::GetFullPath($EvidenceRoot)
    if(-not$EvidenceRoot.StartsWith($tmpRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'EvidenceRoot must be below this worktree .tmp'}
    if($EvidenceRoot-eq$legacyRoot-or$EvidenceRoot.StartsWith($legacyRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Legacy fixed .tmp/rw06_1/exact_seed evidence is forbidden'}
    if(Test-Path -LiteralPath $EvidenceRoot){throw 'EvidenceRoot must be new and collision-free'}
    Assert-NoReparsePathChain $projectRoot $tmpRoot;Assert-NoReparsePathChain $tmpRoot $EvidenceRoot
    $evidenceParent=[IO.Path]::GetDirectoryName($EvidenceRoot)
    if(-not(Test-Path -LiteralPath $evidenceParent -PathType Container)){
        $evidenceGrandparent=[IO.Path]::GetDirectoryName($evidenceParent)
        if(-not(Test-Path -LiteralPath $evidenceGrandparent -PathType Container)-or-not$evidenceParent.StartsWith($tmpRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'EvidenceRoot parent must exist or be one direct child below the worktree .tmp hierarchy'}
        [void](New-Q009ExactOwnedDirectory $evidenceParent)
    }
    Assert-NoReparsePathChain $tmpRoot $evidenceParent
}catch{
    $preRootError=$_.Exception.Message
    $EvidenceRoot=[IO.Path]::GetFullPath((Join-Path $projectRoot ('.tmp\rw06_1\qualified\{0}-invalid' -f $attemptId)))
}
try{
    $selectedParent=[IO.Path]::GetDirectoryName($EvidenceRoot)
    if(-not(Test-Path -LiteralPath $selectedParent -PathType Container)){
        $selectedGrandparent=[IO.Path]::GetDirectoryName($selectedParent)
        if(-not(Test-Path -LiteralPath $selectedGrandparent -PathType Container)){throw 'Selected evidence-root parent and grandparent are missing'}
        [void](New-Q009ExactOwnedDirectory $selectedParent)
    }
    Assert-NoReparsePathChain $tmpRoot $selectedParent
}catch{$preRootError=Join-LauncherError $preRootError ('Evidence parent establishment: '+$_.Exception.Message)}
$summaryPath=Join-Path $EvidenceRoot 'summary.json';$summaryShaPath=Join-Path $EvidenceRoot 'summary.sha256';$terminalPath=Join-Path $EvidenceRoot 'terminal.json';$terminalShaPath=Join-Path $EvidenceRoot 'terminal.sha256';$ownerClaim=Join-Path $EvidenceRoot '.attempt-owner';$ownerClaimText='';$ownerClaimSha256='';$ownerClaimEstablished=$false;$ownerClaimValid=$false
$leaseOwned=$false;$heldExclusiveLease=$null;$heldExclusiveRelease=$null;$runContext=$null;$exclusiveLeaseOwnership=[ordered]@{created=$false;validated=$false;path=$exclusiveLeasePath;identity=$null;write_complete=$false;removal_failed=$false;removal_error=''};$processCustody=[ordered]@{start_observed=$false;start_count=0;cleanup_count=0;cleanup_proved=$true};$cacheAbsentInitially=$false;$cacheOwned=$false;$cleanupSucceeded=$false;$environmentRestored=$false;$finalProvenanceValid=$false
$phases=[System.Collections.Generic.List[object]]::new();$results=[System.Collections.Generic.List[object]]::new();$failures=[System.Collections.Generic.List[string]]::new();$pinned=[ordered]@{};$dependencyPins=[ordered]@{};$dependencyPinReceipts=[ordered]@{};$dependencyPinReleases=[ordered]@{};$dependencyPinsReleased=$false;$candidateCommit='';$candidateTree='';$exactRemoteRefs=@();$postRemoteRefs=@();$postStatus=@();$postCommit='';$postTree='';$remoteRefsStable=$false;$identityStable=$false
$profileManifestChain=$null;$cacheManifestChain=$null;$evidenceTerminalManifestChain=$null;$evidenceTerminalOwnerReceipt=$null;$terminalEvidenceSafe=$false
$launcherIdentity=$null;$environmentBaseline=$null;$evidenceRootOwnership=$null;$profileRoot=Join-Path $EvidenceRoot 'profiles';$profileRootIdentity=$null;$cacheHandleReleased=$false;$cacheRootIdentity=$null;$cacheCreationProof=$null;$cacheSentinelPath='';$cacheHandleCustody=[ordered]@{native_cell=$null;root_receipt=$null;sentinel_receipt=$null;final_root_receipt=$null;absence=$null;proof=$null;registered_utc=''};$cacheEvidence=[ordered]@{absent_initially=$false;initial_absence_observed_utc='';filesystem_capability=$null;pre_creator_absence=$null;creator_phase=$null;creation_proof=$null;creation_chain='';sentinel_path='';sentinel_sha256='';sentinel_length=0;initial_root_close=$null;sentinel_retained_through_phases=$false;created_after_owned_import=$false;owned=$false;ordinary_child_cleanup=$null;final_manifest_sha256='';sentinel_delete_pending=$false;sentinel_close=$null;final_root_acquisition=$null;final_root_delete_pending=$false;final_root_close=$null;all_native_handles_terminal=$false;global_class_sha256='';uid_sha256='';imported_manifest=$null;removed=$false};$executableEvidence=[ordered]@{godot=[ordered]@{expected_path=$canonicalGodotPath;expected_sha256=$ExpectedGodotSha256;actual=$null;final_stable=$false};python=[ordered]@{expected_path=$canonicalPythonPath;expected_sha256=$ExpectedPythonSha256;actual=$null;final_stable=$false}};$staticEvidence=$null;$manifest=$null;$observedVisits=0;$observedTravels=0;$exclusiveLeaseEvidence=$null
$preCleanupQuiescence=[ordered]@{proved=[bool]$false;observed_utc=[string]'';godot_count=[int]-1;godot_identities=@();other_lease_count=[int]-1;under_mutex=[bool]$false};$prePublicationCustody=$null;$preReleaseZeroGodot=$null;$summaryPublication=$null;$terminalPublication=$null;$terminalReceipt=$null;$postSummaryManifestChain=$null;$finalEvidenceTree=$null
$finalOwnedProcessEvidence=[ordered]@{checked=$false;run_context_sha256=[string]'';started_phase_count=[int]0;proved_identity_keys=@();residual_process_ids=@();residual_identities=@();unowned_godot_identities=@();global_godot_identities=@();proof_issues=@('final process proof not reached');clean=$false}
$exclusiveWaitObservations=[System.Collections.Generic.List[object]]::new()

try{
    $launcherProcess=Get-ProcessByIdStrict -ProcessId $PID;if($null-eq$launcherProcess){throw 'Launcher process disappeared before identity capture'};$launcherIdentity=Get-ProcessIdentityRecord $launcherProcess;$environmentBaseline=Get-EnvironmentSnapshot
    $cacheHandleCustody.native_cell=New-Q009CacheCustodyCell $attemptId
    $environmentSha=Get-StringSha256 (($environmentBaseline|ConvertTo-Json -Compress -Depth 5))
    $ownerClaimText="attempt_id=$attemptId`npid=$PID`nlauncher_key=$($launcherIdentity.key)`nevidence_root=$EvidenceRoot`nenvironment_sha256=$environmentSha`n"
    Assert-NoReparsePathChain $projectRoot $tmpRoot;Assert-NoReparsePathChain $tmpRoot ([IO.Path]::GetDirectoryName($EvidenceRoot))
    $evidenceRootOwnership=New-AtomicOwnedEvidenceRoot -DestinationPath $EvidenceRoot -AllowedRoot $tmpRoot -OwnerClaimText $ownerClaimText -AttemptId $attemptId
    $ownerClaim=[string]$evidenceRootOwnership.claim_path;$ownerClaimSha256=[string]$evidenceRootOwnership.claim_sha256;$ownerClaimEstablished=$true;$evidenceRootReady=$true
    Assert-ExactAttemptOwner $ownerClaim $ownerClaimText $ownerClaimSha256 $EvidenceRoot $evidenceRootOwnership;$ownerClaimValid=$true
    if($preRootError){throw ('Requested evidence root was refused safely: '+$preRootError)}
    if($Visits-ne6){throw "Qualifying environment audit requires Visits exactly 6; got $Visits"}
    if([IO.Path]::GetFullPath($GodotPath)-cne[IO.Path]::GetFullPath($canonicalGodotPath)){throw "GodotPath must be canonical: $canonicalGodotPath"}
    if(-not[IO.Path]::IsPathRooted($PythonPath)-or[IO.Path]::GetFullPath($PythonPath)-cne[IO.Path]::GetFullPath($canonicalPythonPath)){throw "PythonPath must be canonical and absolute: $canonicalPythonPath"}
    if($ExpectedGodotSha256-cnotmatch'^[0-9A-Fa-f]{64}$'){throw 'ExpectedGodotSha256 must be exactly 64 hexadecimal characters'}
    if($ExpectedPythonSha256-cnotmatch'^[0-9A-Fa-f]{64}$'){throw 'ExpectedPythonSha256 must be exactly 64 hexadecimal characters'}
    $ExpectedGodotSha256=$ExpectedGodotSha256.ToUpperInvariant();$ExpectedPythonSha256=$ExpectedPythonSha256.ToUpperInvariant();$executableEvidence.godot.expected_sha256=$ExpectedGodotSha256;$executableEvidence.python.expected_sha256=$ExpectedPythonSha256
    if([string]::IsNullOrWhiteSpace($ExpectedCommit)-or[string]::IsNullOrWhiteSpace($ExpectedTree)){throw 'ExpectedCommit and ExpectedTree are mandatory'}
    if($ProcessTimeoutSeconds-lt1-or$LeaseWaitTimeoutSeconds-lt1){throw 'Timeouts must be positive'}
    $executableEvidence.godot.actual=Assert-ExecutableIdentity 'Godot' $GodotPath $canonicalGodotPath $ExpectedGodotSha256
    if(([string]$executableEvidence.godot.actual.file_version+[string]$executableEvidence.godot.actual.product_version)-notmatch'4\.6'){throw 'Canonical Godot binary version metadata does not identify 4.6'}
    $executableEvidence.python.actual=Assert-ExecutableIdentity 'Python' $PythonPath $canonicalPythonPath $ExpectedPythonSha256
    Assert-NoReparsePathChain $projectRoot $projectCacheRoot;[void](Assert-Q009PathAbsentStrict $projectCacheRoot);$cacheAbsentInitially=$true;$cacheEvidence.absent_initially=$true;$cacheEvidence.initial_absence_observed_utc=[DateTime]::UtcNow.ToString('o')
    $candidate=Assert-CleanExactCandidate $projectRoot $ExpectedCommit $ExpectedTree;$candidateCommit=[string]$candidate.commit;$candidateTree=[string]$candidate.tree
    $exactRemoteRefs=@(Get-ExactRemoteCandidateRefs $candidateCommit $projectRoot);if($exactRemoteRefs.Count-eq0){throw 'Exact candidate is not the exact tip of a non-symbolic origin remote-tracking ref'}
    $requiredTrackedFiles=[ordered]@{launcher=$launcherRelativePath;support=$supportRelativePath;manifest=$manifestRelativePath;audit_gd=$auditRelativePath;static_checker=$staticRelativePath;scenario_catalog=$scenarioRelativePath;fidelity_helper=$fidelityRelativePath;foundation_travel_view_model=$foundationTravelRelativePath;tutorial_flow=$tutorialFlowRelativePath;attribute_badges=$attributeBadgesRelativePath}
    foreach($entry in $requiredTrackedFiles.GetEnumerator()){$pinned[$entry.Key]=Get-TrackedFileIdentity $projectRoot $candidateCommit $entry.Value}
    $manifest=Read-JsonFileStrict $manifestPath;$manifestIssues=@(Get-CanonicalManifestIssues $manifest $pinned.manifest.sha256 $pinned.manifest.git_blob);if($manifestIssues.Count){throw ($manifestIssues -join '; ')}
    Assert-ExactAttemptOwner $ownerClaim $ownerClaimText $ownerClaimSha256 $EvidenceRoot $evidenceRootOwnership
    Assert-CanonicalLeaseRootBootstrap -Path $leaseRoot
    $runContext=New-Q009RunContext -AttemptId $attemptId -CandidateCommit $candidateCommit -CandidateTree $candidateTree -LauncherIdentity $launcherIdentity -CanonicalLeaseRoot $leaseRoot -WorkingDirectory $projectRoot -ProjectRoot $projectRoot -LaunchMutexName $launchMutexName -NativeExitSentinel $nativeExitSentinel
    $dependencyPins=New-Q009TrackedDependencyPins $pinned $runContext
    $dependencyPinReceipts=Assert-Q009TrackedDependencyPinsStable $pinned $dependencyPins $runContext
    if(-not(Test-Q009TrackedDependencyPinReceiptsShape $dependencyPinReceipts $pinned $runContext)){throw 'Tracked dependency pins failed their exact pre-child custody contract'}
    $deadline=[DateTime]::UtcNow.AddSeconds($LeaseWaitTimeoutSeconds)
    $heldExclusiveBox=[ordered]@{value=$null}
    while(-not$leaseOwned){
        if([DateTime]::UtcNow-ge$deadline){throw 'Timed out acquiring canonical EXCLUSIVE reservation'}
        $leaseOwned=[bool](Invoke-Q009MutexCritical -RunContext $runContext -Body {
            Assert-CanonicalLeaseRootPath $runContext
            [void](Assert-CleanExactCandidate ([string]$runContext.project_root) $candidateCommit $candidateTree);Assert-PinnedFilesStable $pinned $runContext $dependencyPins;Assert-ExactAttemptOwner $ownerClaim $ownerClaimText $ownerClaimSha256 $EvidenceRoot $evidenceRootOwnership
            $stale=Clear-ProvablyDeadWellFormedLeases -RunContext $runContext -ExcludeExclusive;if(@($stale.malformed).Count){throw 'Malformed focused lease blocks safe EXCLUSIVE reservation'}
            if($null-ne$heldExclusiveBox.value){[void](Assert-Q009HeldExclusiveLease $heldExclusiveBox.value $runContext);return $true}
            if(Test-Path -LiteralPath $exclusiveLeasePath){
                try{
                    $record=Get-StrictLeaseRecord $exclusiveLeasePath $runContext
                    if(Test-LiveProcessMatchesIdentity $record.identity){return $false}
                    Remove-Q009ExactOwnedFile -Path $exclusiveLeasePath -ExpectedIdentity $record.file_identity
                }catch [System.IO.IOException]{return $false}
            }
            $text="mode=exclusive`npid=$PID`nlauncher_name=$($launcherIdentity.name)`nlauncher_start_utc=$($launcherIdentity.start_utc)`nlauncher_start_ticks=$($launcherIdentity.start_ticks)`nlauncher_key=$($launcherIdentity.key)`nworktree=$projectRoot`ncandidate_commit=$candidateCommit`ncandidate_tree=$candidateTree`nattempt_id=$attemptId`n"
            Assert-NoReparsePathChain $leaseRoot $exclusiveLeasePath;$heldExclusiveBox.value=New-Q009HeldExclusiveLease -Path $exclusiveLeasePath -Text $text -RunContext $runContext
            [void](Assert-Q009HeldExclusiveLease $heldExclusiveBox.value $runContext)
            $exclusiveLeaseOwnership.created=$true;$exclusiveLeaseOwnership.validated=$true;$exclusiveLeaseOwnership.identity=$heldExclusiveBox.value.receipt.file_identity;$exclusiveLeaseOwnership.write_complete=$true
            return $true
        })
        if($leaseOwned){$heldExclusiveLease=$heldExclusiveBox.value}
        if(-not$leaseOwned){Start-Sleep -Seconds 2}
    }
    while($true){
        if([DateTime]::UtcNow-ge$deadline){throw 'Timed out waiting after EXCLUSIVE reservation for focused leases/Godot to clear'}
        $waitEvidence=Invoke-Q009MutexCritical -RunContext $runContext -Body {
            Assert-ExclusiveReservationOwned $launcherIdentity $candidateCommit $candidateTree $attemptId $pinned $dependencyPins $environmentBaseline $ownerClaim $ownerClaimText $ownerClaimSha256 $EvidenceRoot $evidenceRootOwnership $heldExclusiveLease $runContext
            [void](Assert-ExecutableIdentity 'Godot wait' $GodotPath $canonicalGodotPath $ExpectedGodotSha256 $executableEvidence.godot.actual);[void](Assert-ExecutableIdentity 'Python wait' $PythonPath $canonicalPythonPath $ExpectedPythonSha256 $executableEvidence.python.actual)
            $stale=Clear-ProvablyDeadWellFormedLeases -RunContext $runContext -ExcludeExclusive
            Assert-CanonicalLeaseRootPath $runContext
            $others=@(Get-CanonicalLeaseFilesStrict -RunContext $runContext -ExcludeExclusive)
            $godot=@(Get-LiveGodotIdentityRecords)
            $disposition=Get-ExclusiveWaitDisposition $others.Count $godot.Count @($stale.malformed).Count
            if($disposition-ceq'invalid'){throw 'Malformed lease blocks EXCLUSIVE readiness'}
            if($disposition-ceq'ready'){Assert-ExclusiveReady $launcherIdentity $candidateCommit $candidateTree $attemptId $pinned $dependencyPins $environmentBaseline $ownerClaim $ownerClaimText $ownerClaimSha256 $EvidenceRoot $evidenceRootOwnership $heldExclusiveLease $runContext}
            return [ordered]@{observed_utc=[DateTime]::UtcNow.ToString('o');disposition=$disposition;focused_lease_count=$others.Count;godot_count=$godot.Count;godot_identities=$godot;cleared_stale=@($stale.cleared)}
        }
        [void]$exclusiveWaitObservations.Add($waitEvidence)
        if([string]$waitEvidence.disposition-ceq'ready'){break}
        Start-Sleep -Seconds 2
    }
    [void](Assert-Q009HeldExclusiveLease $heldExclusiveLease $runContext);$exclusiveLeaseEvidence=[ordered]@{artifact=[ordered]@{path=[string]$heldExclusiveLease.receipt.path;present=[bool]$true;length=[long]$heldExclusiveLease.receipt.payload_length;sha256=[string]$heldExclusiveLease.receipt.payload_sha256};mode=[string]'exclusive';launcher_key=[string]$heldExclusiveLease.receipt.owner_identity.key;worktree=[string]$projectRoot;candidate_commit=[string]$heldExclusiveLease.receipt.candidate_commit;candidate_tree=[string]$heldExclusiveLease.receipt.candidate_tree;attempt_id=[string]$heldExclusiveLease.receipt.attempt_id;receipt_sha256=[string]$heldExclusiveLease.receipt.receipt_sha256;run_context_sha256=[string]$runContext.context_sha256}

    $profileRootIdentity=New-Q009ExactOwnedDirectory $profileRoot
    $profileManifestChain=New-Q009OwnedChildManifestChainHead -RootPath $profileRoot -RootIdentity $profileRootIdentity -AttemptId $attemptId -Boundary 'profile_root_created' -OwnerKind profile_creator -OwnerReceipt ([ordered]@{run_context_sha256=[string]$runContext.context_sha256;root_identity=$profileRootIdentity;exclusive_receipt_sha256=[string]$heldExclusiveLease.receipt.receipt_sha256})
    $cacheCreation=$null
    $cacheCreation=Invoke-Q009MutexCritical -RunContext $runContext -Body {
        Assert-ExclusiveReservationOwned $launcherIdentity $candidateCommit $candidateTree $attemptId $pinned $dependencyPins $environmentBaseline $ownerClaim $ownerClaimText $ownerClaimSha256 $EvidenceRoot $evidenceRootOwnership $heldExclusiveLease $runContext
        [void](Assert-ExecutableIdentity 'Godot cache-create' $GodotPath $canonicalGodotPath $ExpectedGodotSha256 $executableEvidence.godot.actual);[void](Assert-ExecutableIdentity 'Python cache-create' $PythonPath $canonicalPythonPath $ExpectedPythonSha256 $executableEvidence.python.actual)
        $cacheEvidence.filesystem_capability=Invoke-Q009SentinelFilesystemCapabilityProbe $EvidenceRoot $attemptId $projectRoot
        if(-not(Test-SentinelCapabilityReceiptShape $cacheEvidence.filesystem_capability)){throw 'Sentinel filesystem capability evidence was malformed'}
        $cacheAbsence=Assert-OwnedCacheAbsentImmediatelyBeforeImport $projectCacheRoot $projectRoot;$cacheHandleCustody.absence=$cacheAbsence
        $rootReceipt=New-Q009ExactOwnedDirectoryHeld -Path $projectCacheRoot -CustodyCell $cacheHandleCustody.native_cell -Slot root_creation;$cacheHandleCustody.root_receipt=$rootReceipt
        if(-not(Test-Q009CacheRootReceiptShape $rootReceipt)){throw 'Cache root creation receipt failed its exact public schema'}
        $cacheSentinelPath=Join-Path $projectCacheRoot ('.rw06-q009-cache-pin-'+[guid]::NewGuid().ToString('N')+'.pin')
        $sentinelPayloadObject=[ordered]@{schema_version=1;attempt_id=$attemptId;candidate_commit=$candidateCommit;candidate_tree=$candidateTree;creator_key=[string]$launcherIdentity.key;root_key=[string]$rootReceipt.identity.key;sentinel_name=[IO.Path]::GetFileName($cacheSentinelPath)}
        $sentinelPayload=[Text.Encoding]::UTF8.GetBytes(($sentinelPayloadObject|ConvertTo-Json -Compress))
        $sentinelReceipt=New-Q009ExactOwnedFileHeld -Path $cacheSentinelPath -Payload $sentinelPayload -CustodyCell $cacheHandleCustody.native_cell -ParentSlot root_creation -Slot sentinel -ExpectedParentIdentity $rootReceipt.identity;$cacheHandleCustody.sentinel_receipt=$sentinelReceipt
        if(-not(Test-Q009SentinelReceiptShape $sentinelReceipt)){throw 'Cache sentinel creation receipt failed its exact public schema'}
        $preCloseProof=Get-SentinelPinnedCacheProof $cacheHandleCustody $launcherIdentity $projectCacheRoot $attemptId $candidateCommit $candidateTree -RequireInitialRootOpen
        if(-not(Test-SentinelPinnedCacheProofShape $preCloseProof $attemptId $candidateCommit $candidateTree)){throw 'Pre-handoff sentinel proof was malformed'}
        $initialRootClose=Close-Q009CheckedNativeHandle $cacheHandleCustody.native_cell root_creation 'Initial cache-root handoff'
        if(-not(Test-Q009CheckedCloseReceipt $initialRootClose)){throw 'Initial cache-root checked-close receipt was malformed'}
        $proof=Get-SentinelPinnedCacheProof $cacheHandleCustody $launcherIdentity $projectCacheRoot $attemptId $candidateCommit $candidateTree
        if(-not(Test-SentinelPinnedCacheProofShape $proof $attemptId $candidateCommit $candidateTree)){throw 'Post-handoff sentinel proof was malformed'}
        $initialCacheChain=New-Q009OwnedChildManifestChainHead -RootPath $projectCacheRoot -RootIdentity $proof.entry_identity -AttemptId $attemptId -Boundary 'cache_creator_sentinel_bound' -OwnerKind cache_creator -OwnerReceipt ([ordered]@{run_context_sha256=[string]$runContext.context_sha256;creation_proof=$proof;root_receipt=$rootReceipt;sentinel_receipt=$sentinelReceipt;initial_root_close=$initialRootClose}) -HeldFileCustodyCell $cacheHandleCustody.native_cell -HeldFileSlot sentinel -HeldFileIdentity $sentinelReceipt.identity
        $cacheHandleCustody.proof=$proof;$cacheHandleCustody.registered_utc=[DateTime]::UtcNow.ToString('o')
        return [pscustomobject]@{absence=$cacheAbsence;pre_close_proof=$preCloseProof;proof=$proof;initial_root_close=$initialRootClose;manifest_chain=$initialCacheChain}
    }
    $cacheCreationProof=$cacheCreation.proof;$cacheRootIdentity=$cacheCreationProof.entry_identity;$cacheOwned=$true;$cacheEvidence.owned=$true;$cacheEvidence.creator_phase='supervisor_native_FILE_CREATE_plus_relative_sentinel';$cacheEvidence.creation_chain=[string]$cacheCreationProof.creation_chain;$cacheEvidence.pre_creator_absence=$cacheCreation.absence;$cacheEvidence.creation_proof=$cacheCreationProof;$cacheEvidence.initial_root_close=$cacheCreation.initial_root_close;$cacheEvidence.sentinel_path=[string]$cacheHandleCustody.sentinel_receipt.path;$cacheEvidence.sentinel_sha256=[string]$cacheHandleCustody.sentinel_receipt.payload_sha256;$cacheEvidence.sentinel_length=[int]$cacheHandleCustody.sentinel_receipt.payload_length
    $cacheManifestChain=$cacheCreation.manifest_chain
    if($null-eq$cacheCreation-or$null-eq$cacheCreation.proof-or$null-eq$cacheHandleCustody.root_receipt-or$null-eq$cacheHandleCustody.sentinel_receipt){throw 'Native cache creation did not return its registered sentinel-pinned proof'}
    if(-not(Test-OwnedCacheAbsenceReceiptShape $cacheEvidence.pre_creator_absence)){throw 'Native cache creation lacked an exact immediate mutex-bound cache-absence proof'}
    $cacheArtifactRequest=[ordered]@{role='project_cache';path=[string]$projectCacheRoot;root_identity=$cacheRootIdentity;held_file_custody=$cacheHandleCustody.native_cell;held_file_slot='sentinel';held_file_identity=$cacheHandleCustody.sentinel_receipt.identity}
    $importRoot=Join-Path $EvidenceRoot '01-import';$importLog=Join-Path $importRoot 'godot.log';$importProfile=New-ProfileEnvironment (Join-Path $profileRoot 'import') $EvidenceRoot $runContext;$importArgs=@('--headless','--verbose','--disable-crash-handler','--audio-driver','Dummy','--path',$projectRoot,'--log-file',$importLog,'--editor','--quit')
    $import=Invoke-ExclusiveProcessPhase -Name 'import' -FilePath $GodotPath -Arguments $importArgs -PhaseRoot $importRoot -ProcessKind Godot -Commit $candidateCommit -Tree $candidateTree -AttemptId $attemptId -LauncherIdentity $launcherIdentity -Pinned $pinned -DependencyPins $dependencyPins -EnvironmentBaseline $environmentBaseline -OwnerClaimPath $ownerClaim -OwnerClaimText $ownerClaimText -OwnerClaimSha256 $ownerClaimSha256 -OwnedRoot $EvidenceRoot -ExecutableIdentity $executableEvidence.godot.actual -ExpectedExecutablePath $canonicalGodotPath -ExpectedExecutableSha256 $ExpectedGodotSha256 -EnvironmentOverrides $importProfile.environment -AdditionalLogPaths @($importLog) -TimeoutSeconds $ProcessTimeoutSeconds -ProcessCustody $processCustody -OwnerReceipt $evidenceRootOwnership -HeldExclusiveLease $heldExclusiveLease -CacheCustody $cacheHandleCustody -CacheCreatorIdentity $launcherIdentity -OwnedArtifactRoots @($cacheArtifactRequest,[ordered]@{role='profile';path=[string]$importProfile.root_path;root_identity=$importProfile.root_identity}) -RunContext $runContext;[void]$phases.Add($import)
    $importChains=Update-Q009RuntimeArtifactManifestChains $import $runContext $projectCacheRoot $cacheRootIdentity $cacheManifestChain $profileRoot $profileRootIdentity $profileManifestChain $true $cacheHandleCustody.native_cell $cacheHandleCustody.sentinel_receipt.identity;$cacheManifestChain=$importChains.cache_chain;$profileManifestChain=$importChains.profile_chain
    if(-not(Test-PhaseInfrastructureClean $import @(0) $runContext)){throw 'Canonical Godot import phase failed closed'}
    [void](Get-SentinelPinnedCacheProof $cacheHandleCustody $launcherIdentity $projectCacheRoot $attemptId $candidateCommit $candidateTree);$cacheEvidence.created_after_owned_import=$true
    $classCache=Join-Path $projectCacheRoot 'global_script_class_cache.cfg';$uidCache=Join-Path $projectCacheRoot 'uid_cache.bin';if(-not(Test-Path $classCache)-or-not(Test-Path $uidCache)){throw 'Godot import omitted class or UID cache'};$cacheEvidence.global_class_sha256=(Get-FileHash $classCache -Algorithm SHA256).Hash;$cacheEvidence.uid_sha256=(Get-FileHash $uidCache -Algorithm SHA256).Hash;$cacheEvidence.imported_manifest=Write-ImportedManifest (Join-Path $importRoot 'imported-manifest.json') $runContext

    $staticRoot=Join-Path $EvidenceRoot '02-static';$staticReportPath=Join-Path $staticRoot 'report.json'
    $static=Invoke-ExclusiveProcessPhase 'static_preflight' $PythonPath @($staticCheckerPath,$projectRoot,$staticReportPath) $staticRoot Python $candidateCommit $candidateTree $attemptId $launcherIdentity $pinned $dependencyPins $environmentBaseline $ownerClaim $ownerClaimText $ownerClaimSha256 $EvidenceRoot $executableEvidence.python.actual $canonicalPythonPath $ExpectedPythonSha256 ([ordered]@{}) @() $ProcessTimeoutSeconds $processCustody -OwnerReceipt $evidenceRootOwnership -HeldExclusiveLease $heldExclusiveLease -CacheCustody $cacheHandleCustody -CacheCreatorIdentity $launcherIdentity -AdditionalArtifactPaths @($staticReportPath) -OwnedArtifactRoots @($cacheArtifactRequest) -RunContext $runContext;[void]$phases.Add($static)
    $staticChains=Update-Q009RuntimeArtifactManifestChains $static $runContext $projectCacheRoot $cacheRootIdentity $cacheManifestChain $profileRoot $profileRootIdentity $profileManifestChain $false $cacheHandleCustody.native_cell $cacheHandleCustody.sentinel_receipt.identity;$cacheManifestChain=$staticChains.cache_chain;$profileManifestChain=$staticChains.profile_chain
    if(-not(Test-PhaseInfrastructureClean $static @(0) $runContext)){throw 'Static preflight process failed closed'};$staticReport=Read-JsonFileStrict $staticReportPath;$staticIssues=@(Get-StaticReportIssues $staticReport);if($staticIssues.Count){throw ($staticIssues-join'; ')};$staticEvidence=Get-FileArtifact $staticReportPath

    if($Mode-eq'Historical22'){
        $index=0
        foreach($expectation in @($manifest.expectations)){
            $index+=1;$seed=[string]$expectation.seed;$safe=ConvertTo-SafeEvidenceName $seed;$seedRoot=Join-Path $EvidenceRoot ('seeds\{0:D2}-{1}'-f$index,$safe)
            $json=Join-Path $seedRoot 'report.json';$md=Join-Path $seedRoot 'report.md';$log=Join-Path $seedRoot 'godot.log';$stdout=Join-Path $seedRoot 'stdout.log';$stderr=Join-Path $seedRoot 'stderr.log';$profile=New-ProfileEnvironment (Join-Path $profileRoot ('seed-{0:D2}'-f$index)) $EvidenceRoot $runContext
            $args=@('--headless','--verbose','--disable-crash-handler','--audio-driver','Dummy','--path',$projectRoot,'--log-file',$log,'--script','res://tools/environment_generation_audit.gd','--',"--runs=1","--visits=6","--exact-seed=$seed","--attempt-id=$attemptId",'--require-attempt-id',"--output=$(Convert-ToResourcePath $json $runContext)","--report=$(Convert-ToResourcePath $md $runContext)")
            $phase=Invoke-ExclusiveProcessPhase ("historical_{0:D2}"-f$index) $GodotPath $args $seedRoot Godot $candidateCommit $candidateTree $attemptId $launcherIdentity $pinned $dependencyPins $environmentBaseline $ownerClaim $ownerClaimText $ownerClaimSha256 $EvidenceRoot $executableEvidence.godot.actual $canonicalGodotPath $ExpectedGodotSha256 $profile.environment @($log) $ProcessTimeoutSeconds $processCustody -OwnerReceipt $evidenceRootOwnership -HeldExclusiveLease $heldExclusiveLease -CacheCustody $cacheHandleCustody -CacheCreatorIdentity $launcherIdentity -AdditionalArtifactPaths @($json,$md) -OwnedArtifactRoots @($cacheArtifactRequest,[ordered]@{role='profile';path=[string]$profile.root_path;root_identity=$profile.root_identity}) -RunContext $runContext;[void]$phases.Add($phase)
            $phaseChains=Update-Q009RuntimeArtifactManifestChains $phase $runContext $projectCacheRoot $cacheRootIdentity $cacheManifestChain $profileRoot $profileRootIdentity $profileManifestChain $true $cacheHandleCustody.native_cell $cacheHandleCustody.sentinel_receipt.identity;$cacheManifestChain=$phaseChains.cache_chain;$profileManifestChain=$phaseChains.profile_chain
            if(-not(Test-PhaseCustodyClean $phase @(0,1) $runContext)){throw "Historical seed custody/process envelope failed: $seed"}
            foreach($requiredArtifact in @($json,$md,$log,$stdout,$stderr)){if(-not(Test-Path -LiteralPath $requiredArtifact -PathType Leaf)){throw "Historical seed missing fresh artifact $requiredArtifact"}}
            if((Get-Item $json).Length-le0-or(Get-Item $md).Length-le0){throw "Historical seed produced empty JSON/Markdown: $seed"}
            $raw=[IO.File]::ReadAllText($json);$report=$raw|ConvertFrom-Json -ErrorAction Stop;$envelope=@(Get-AuditEnvelopeIssues $report $attemptId 1 6 5 -CustodyOnly);if($envelope.Count){throw "Historical seed evidence envelope invalid $seed`: $($envelope-join'; ')"};$bindingIssues=@(Get-ProductPhaseBindingIssues $phase $report);if($bindingIssues.Count){throw "Historical seed diagnostic/exit binding invalid $seed`: $($bindingIssues-join'; ')"}
            $observedVisits+=@($report.environment_records).Count;$observedTravels+=@($report.travel_records).Count;$combo=$null;if($seed-ceq'POSTFIX-UIENV-009-4151570434'){$combo=@($manifest.legal_room_combinations)[0]};$issues=@(Get-AuditSemanticIssues $report $attemptId 1 6 5 $expectation $combo $raw);foreach($productFailure in @($report.failures)){$issues+="product failure: $productFailure"};if([int]$phase.native_exit_code-ne0){$issues+="native product exit $($phase.native_exit_code)"}
            if($phase.native_exit_code-eq0-and$issues.Count-eq0){$state='PASS'}else{$state='PRODUCT_RED';foreach($issue in $issues){[void]$failures.Add("$seed`: $issue")}};$artifacts=@(Get-FileArtifacts @($json,$md,$log,$stdout,$stderr));[void]$results.Add([ordered]@{index=$index;seed=$seed;outcome=$state;native_exit_code=$phase.native_exit_code;issues=$issues;artifacts=$artifacts})
        }
        if($results.Count-ne22){throw 'Historical matrix did not execute exactly 22 rows'}
    }else{
        $root=Join-Path $EvidenceRoot 'generation100';$json=Join-Path $root 'report.json';$md=Join-Path $root 'report.md';$log=Join-Path $root 'godot.log';$stdout=Join-Path $root 'stdout.log';$stderr=Join-Path $root 'stderr.log';$profile=New-ProfileEnvironment (Join-Path $profileRoot 'generation100') $EvidenceRoot $runContext
        $args=@('--headless','--verbose','--disable-crash-handler','--audio-driver','Dummy','--path',$projectRoot,'--log-file',$log,'--script','res://tools/environment_generation_audit.gd','--','--runs=100','--visits=6',"--seed-prefix=$generationSeedPrefix","--attempt-id=$attemptId",'--require-attempt-id',"--output=$(Convert-ToResourcePath $json $runContext)","--report=$(Convert-ToResourcePath $md $runContext)")
        $phase=Invoke-ExclusiveProcessPhase 'generation100' $GodotPath $args $root Godot $candidateCommit $candidateTree $attemptId $launcherIdentity $pinned $dependencyPins $environmentBaseline $ownerClaim $ownerClaimText $ownerClaimSha256 $EvidenceRoot $executableEvidence.godot.actual $canonicalGodotPath $ExpectedGodotSha256 $profile.environment @($log) ([Math]::Max($ProcessTimeoutSeconds,1800)) $processCustody -OwnerReceipt $evidenceRootOwnership -HeldExclusiveLease $heldExclusiveLease -CacheCustody $cacheHandleCustody -CacheCreatorIdentity $launcherIdentity -AdditionalArtifactPaths @($json,$md) -OwnedArtifactRoots @($cacheArtifactRequest,[ordered]@{role='profile';path=[string]$profile.root_path;root_identity=$profile.root_identity}) -RunContext $runContext;[void]$phases.Add($phase)
        $phaseChains=Update-Q009RuntimeArtifactManifestChains $phase $runContext $projectCacheRoot $cacheRootIdentity $cacheManifestChain $profileRoot $profileRootIdentity $profileManifestChain $true $cacheHandleCustody.native_cell $cacheHandleCustody.sentinel_receipt.identity;$cacheManifestChain=$phaseChains.cache_chain;$profileManifestChain=$phaseChains.profile_chain
        if(-not(Test-PhaseCustodyClean $phase @(0,1) $runContext)){throw 'Generation100 custody/process envelope failed'};foreach($requiredArtifact in @($json,$md,$log,$stdout,$stderr)){if(-not(Test-Path -LiteralPath $requiredArtifact -PathType Leaf)){throw "Generation100 missing fresh artifact $requiredArtifact"}};if((Get-Item $json).Length-le0-or(Get-Item $md).Length-le0){throw 'Generation100 produced empty JSON/Markdown'}
        $raw=[IO.File]::ReadAllText($json);$report=$raw|ConvertFrom-Json -ErrorAction Stop;$envelope=@(Get-AuditEnvelopeIssues $report $attemptId 100 600 500 -CustodyOnly);if($envelope.Count){throw "Generation100 evidence envelope invalid: $($envelope-join'; ')"};$bindingIssues=@(Get-ProductPhaseBindingIssues $phase $report);if($bindingIssues.Count){throw "Generation100 diagnostic/exit binding invalid: $($bindingIssues-join'; ')"};$observedVisits=@($report.environment_records).Count;$observedTravels=@($report.travel_records).Count
        $issues=@(Get-AuditSemanticIssues $report $attemptId 100 600 500 $null $null $raw);foreach($productFailure in @($report.failures)){$issues+="product failure: $productFailure"};$seeds=@($report.runs|ForEach-Object{[string]$_.seed});if([string]$report.seed_prefix-cne$generationSeedPrefix-or@($seeds|Sort-Object -Unique).Count-ne100-or@($seeds|Where-Object{-not$_.StartsWith($generationSeedPrefix+'-',[StringComparison]::Ordinal)}).Count){$issues+='Generation100 fixed prefix/unique recorded seed contract failed'};if([int]$phase.native_exit_code-ne0){$issues+="native product exit $($phase.native_exit_code)"};if($phase.native_exit_code-eq0-and$issues.Count-eq0){$state='PASS'}else{$state='PRODUCT_RED';foreach($issue in $issues){[void]$failures.Add("Generation100: $issue")}};[void]$results.Add([ordered]@{seed_prefix=$generationSeedPrefix;recorded_seeds=$seeds;outcome=$state;native_exit_code=$phase.native_exit_code;issues=$issues;artifacts=@(Get-FileArtifacts @($json,$md,$log,$stdout,$stderr))})
    }
    if($failures.Count-eq0){$outcome='pass';$overallExit=0}else{$outcome='product_red';$overallExit=1}
}catch{$launcherError=Join-LauncherError $launcherError $_.Exception.Message;$outcome='invalid';$overallExit=1}
finally{
    $leaseOwned=$null-ne$heldExclusiveLease-and$heldExclusiveLease.released-is[bool]-and-not[bool]$heldExclusiveLease.released
    $expectedRuns=if($Mode-eq'Historical22'){22}else{100};$expectedVisits=if($Mode-eq'Historical22'){132}else{600};$expectedTravels=if($Mode-eq'Historical22'){110}else{500}
    $cacheEvidence.sentinel_retained_through_phases=$cacheOwned-and$null-ne$cacheHandleCustody.native_cell-and[string]$cacheHandleCustody.native_cell.StateOf('sentinel')-ceq'OPEN'-and$phases.Count-gt0-and@($phases|Where-Object{-not[bool]$_.cache_handle_revalidated}).Count-eq0
    if($overallExit-eq0-and($observedVisits-ne$expectedVisits-or$observedTravels-ne$expectedTravels)){$launcherError=Join-LauncherError $launcherError 'A passing candidate did not produce the exact aggregate visit/travel matrix';$outcome='invalid';$overallExit=1}
    try{
        if($null-ne$environmentBaseline){$envRestore=Restore-ProcessEnvironmentSafely $environmentBaseline;$environmentRestored=[bool]$envRestore.succeeded;if(-not$environmentRestored){throw ('Environment restore: '+[string]$envRestore.error)}}else{$environmentRestored=$false}
    }catch{$environmentRestored=$false;$launcherError=Join-LauncherError $launcherError ('Final environment restoration: '+$_.Exception.Message)}
    try{
        if(-not$ownerClaimEstablished){throw 'Attempt-owner claim was never established'}
        Assert-ExactAttemptOwner $ownerClaim $ownerClaimText $ownerClaimSha256 $EvidenceRoot $evidenceRootOwnership;$ownerClaimValid=$true
    }catch{$ownerClaimValid=$false;$launcherError=Join-LauncherError $launcherError ('Final owner claim: '+$_.Exception.Message)}
    try{
        if([string]::IsNullOrWhiteSpace($candidateCommit)){throw 'Candidate identity was never established'}
        $finalCandidate=Assert-CleanExactCandidate ([string]$runContext.project_root) $candidateCommit $candidateTree;$postCommit=[string]$finalCandidate.commit;$postTree=[string]$finalCandidate.tree;Assert-PinnedFilesStable $pinned $runContext $dependencyPins
        $postStatus=@(&git -C $projectRoot status --porcelain);$postRemoteRefs=@(Get-ExactRemoteCandidateRefs $candidateCommit $projectRoot);$remoteRefsStable=($postRemoteRefs-join"`n")-ceq(@($exactRemoteRefs)-join"`n")-and$postRemoteRefs.Count-gt0
        $identityStable=$postStatus.Count-eq0-and$postCommit-ceq$candidateCommit-and$postTree-ceq$candidateTree-and$remoteRefsStable
        if(-not$identityStable){throw 'Final candidate or remote-tip identity drifted'}
    }catch{$identityStable=$false;$launcherError=Join-LauncherError $launcherError ('Final candidate: '+$_.Exception.Message)}
    try{if($null-eq$executableEvidence.godot.actual){throw 'Godot identity was never captured'};[void](Assert-ExecutableIdentity 'Godot final' $GodotPath $canonicalGodotPath $ExpectedGodotSha256 $executableEvidence.godot.actual);$executableEvidence.godot.final_stable=$true}catch{$launcherError=Join-LauncherError $launcherError ('Godot final: '+$_.Exception.Message)}
    try{if($null-eq$executableEvidence.python.actual){throw 'Python identity was never captured'};[void](Assert-ExecutableIdentity 'Python final' $PythonPath $canonicalPythonPath $ExpectedPythonSha256 $executableEvidence.python.actual);$executableEvidence.python.final_stable=$true}catch{$launcherError=Join-LauncherError $launcherError ('Python final: '+$_.Exception.Message)}
    $profilesRemoved=$false;$phaseResidualFree=$false;$preCleanupQuiescent=$false
    try{
        $finalOwnedProcessEvidence=Get-FinalOwnedProcessResidualEvidence @($phases) $processCustody $runContext
        $phaseResidualFree=Test-MayRemoveOwnedRuntimeArtifacts $finalOwnedProcessEvidence $runContext
        if(-not$phaseResidualFree){$residualDetail=@(@($finalOwnedProcessEvidence.proof_issues)+@($finalOwnedProcessEvidence.residual_process_ids)+@($finalOwnedProcessEvidence.unowned_godot_identities|ForEach-Object{[string]$_.key})|ForEach-Object{[string]$_})-join'; ';throw ('Final exact root/descendant residual proof failed: '+$residualDetail)}
    }catch{$phaseResidualFree=$false;$launcherError=Join-LauncherError $launcherError ('Process custody before profile/cache cleanup: '+$_.Exception.Message)}
    if($phaseResidualFree-and$leaseOwned){
        try{
            $preCleanupQuiescence=Invoke-Q009MutexCritical -RunContext $runContext -Body {
                [void](Assert-ExecutableIdentity 'Godot pre-cleanup' $GodotPath $canonicalGodotPath $ExpectedGodotSha256 $executableEvidence.godot.actual);[void](Assert-ExecutableIdentity 'Python pre-cleanup' $PythonPath $canonicalPythonPath $ExpectedPythonSha256 $executableEvidence.python.actual)
                Get-StrictGlobalQuiescenceEvidence $launcherIdentity $candidateCommit $candidateTree $attemptId $pinned $dependencyPins $environmentBaseline $ownerClaim $ownerClaimText $ownerClaimSha256 $EvidenceRoot $evidenceRootOwnership $heldExclusiveLease $runContext -Context pre_cleanup
            }
            if(-not(Test-GlobalQuiescenceEvidenceShape $preCleanupQuiescence)){throw 'Mutex-bound pre-cleanup quiescence receipt was malformed'}
            $preCleanupQuiescent=[bool]$preCleanupQuiescence.proved
        }catch{$preCleanupQuiescent=$false;$launcherError=Join-LauncherError $launcherError ('Pre-cleanup global quiescence: '+$_.Exception.Message)}
    }
    if($phaseResidualFree-and$preCleanupQuiescent){
        try{
            if(Test-Path -LiteralPath $profileRoot){
                if(-not(Test-Q009FileSystemIdentityShape $profileRootIdentity)){throw 'Profile root lacks its atomic creation receipt'}
                $profileOwner=[ordered]@{run_context_sha256=[string]$runContext.context_sha256;final_process_evidence=$finalOwnedProcessEvidence;pre_cleanup_quiescence=$preCleanupQuiescence;root_identity=$profileRootIdentity}
                $profileManifestChain=New-Q009OwnedChildManifestChainHead -RootPath $profileRoot -RootIdentity $profileRootIdentity -AttemptId $attemptId -Boundary 'profile_terminal_after_process_quiescence' -OwnerKind profile_creator -OwnerReceipt $profileOwner -PreviousHead $profileManifestChain
                [void](Remove-ExactOwnedTree $EvidenceRoot $profileRoot $profileRootIdentity $profileManifestChain $attemptId)
            }
            [void](Assert-Q009PathAbsentStrict $profileRoot);$profilesRemoved=$true
        }catch{$profilesRemoved=$false;$launcherError=Join-LauncherError $launcherError ('Profile cleanup: '+$_.Exception.Message)}
        try{
            if(-not$cacheOwned-or-not(Test-Path -LiteralPath $projectCacheRoot -PathType Container)){throw 'Creator-bound project cache disappeared or was never owned before exact cleanup'}
            if(-not($cacheAbsentInitially-and(Test-OwnedCacheAbsenceReceiptShape $cacheEvidence.pre_creator_absence)-and(Test-SentinelPinnedCacheProofShape $cacheCreationProof $attemptId $candidateCommit $candidateTree)-and$cacheEvidence.sentinel_retained_through_phases-is[bool]-and[bool]$cacheEvidence.sentinel_retained_through_phases-and$cacheEvidence.created_after_owned_import-is[bool]-and[bool]$cacheEvidence.created_after_owned_import)){throw 'Cache lacks exact initial/pre-creator/sentinel-pin/import proof'}
            $finalPinProof=Get-SentinelPinnedCacheProof $cacheHandleCustody $launcherIdentity $projectCacheRoot $attemptId $candidateCommit $candidateTree
            if(-not(Test-SentinelPinnedCacheProofShape $finalPinProof $attemptId $candidateCommit $candidateTree)){throw 'Final sentinel pin proof was malformed'}
            $cacheOwner=[ordered]@{run_context_sha256=[string]$runContext.context_sha256;creation_proof=$cacheCreationProof;final_pin_proof=$finalPinProof;final_process_evidence=$finalOwnedProcessEvidence;pre_cleanup_quiescence=$preCleanupQuiescence}
            $cacheManifestChain=New-Q009OwnedChildManifestChainHead -RootPath $projectCacheRoot -RootIdentity $cacheRootIdentity -AttemptId $attemptId -Boundary 'cache_terminal_after_process_quiescence' -OwnerKind cache_creator -OwnerReceipt $cacheOwner -PreviousHead $cacheManifestChain -HeldFileCustodyCell $cacheHandleCustody.native_cell -HeldFileSlot sentinel -HeldFileIdentity $cacheHandleCustody.sentinel_receipt.identity
            $cacheManifest=$cacheManifestChain.manifest;if(-not(Test-Q009ExactOwnedTreeManifestShape $cacheManifest $cacheRootIdentity)){throw 'Final cache manifest failed its exact public schema'};$cacheEvidence.final_manifest_sha256=[string]$cacheManifest.sha256
            $ordinaryCleanup=Remove-Q009ManifestChildrenExceptSentinel -RootPath $projectCacheRoot -RootIdentity $cacheRootIdentity -SentinelIdentity $cacheHandleCustody.sentinel_receipt.identity -AuthorizedChainHead $cacheManifestChain -ExpectedAttemptId $attemptId -CustodyCell $cacheHandleCustody.native_cell;if(-not(Test-Q009ManifestCleanupReceiptShape $ordinaryCleanup)){throw 'Ordinary cache-child cleanup receipt was malformed'};$cacheEvidence.ordinary_child_cleanup=$ordinaryCleanup
            $finalRootReceipt=Open-Q009ExactDirectoryHeld -Path $projectCacheRoot -ExpectedIdentity $cacheRootIdentity -CustodyCell $cacheHandleCustody.native_cell -Slot final_root;if(-not(Test-Q009FinalRootReceiptShape $finalRootReceipt)){throw 'Final cache-root acquisition receipt was malformed'};$cacheHandleCustody.final_root_receipt=$finalRootReceipt;$cacheEvidence.final_root_acquisition=$finalRootReceipt
            $sentinelDisposition=Set-Q009HeldHandleDeletePending $cacheHandleCustody.native_cell sentinel 'Cache sentinel';if(-not(Test-Q009HeldHandleStateShape $sentinelDisposition $cacheHandleCustody.sentinel_receipt.identity $false)-or-not[bool]$sentinelDisposition.delete_pending){throw 'Cache sentinel disposition receipt was malformed'};$cacheEvidence.sentinel_delete_pending=[bool]$sentinelDisposition.delete_pending
            $sentinelState=Get-Q009HeldHandleState $cacheHandleCustody.native_cell sentinel
            if(-not(Test-Q009HeldHandleStateShape $sentinelState $cacheHandleCustody.sentinel_receipt.identity $false)-or-not[bool]$sentinelState.delete_pending){throw 'Final root acquisition did not retain exactly the delete-pending sentinel'}
            $preSentinelCloseEntries=@([IO.Directory]::GetFileSystemEntries($projectCacheRoot));if($preSentinelCloseEntries.Count-ne1-or[IO.Path]::GetFullPath($preSentinelCloseEntries[0])-cne[IO.Path]::GetFullPath([string]$cacheHandleCustody.sentinel_receipt.path)){throw 'Final cache root did not contain exactly the held sentinel before its close'}
            $cacheEvidence.sentinel_close=Close-Q009CheckedNativeHandle $cacheHandleCustody.native_cell sentinel 'Cache sentinel final close';if(-not(Test-Q009CheckedCloseReceipt $cacheEvidence.sentinel_close)){throw 'Cache sentinel close receipt was malformed'}
            if(Test-Path -LiteralPath ([string]$cacheHandleCustody.sentinel_receipt.path)){throw 'Delete-pending sentinel remained after checked native close'}
            if(@([IO.Directory]::GetFileSystemEntries($projectCacheRoot)).Count-ne0){throw 'Final cache root gained an entry across sentinel close'}
            $rootHandleIdentity=Get-Q009FileSystemHandleIdentity -CustodyCell $cacheHandleCustody.native_cell -Slot final_root -Path $projectCacheRoot -IsDirectory $true;if([string]$rootHandleIdentity.key-cne[string]$cacheRootIdentity.key){throw 'Final root identity changed before its disposition'}
            $rootDisposition=Set-Q009HeldHandleDeletePending $cacheHandleCustody.native_cell final_root 'Final empty cache root';if(-not(Test-Q009HeldHandleStateShape $rootDisposition $cacheRootIdentity $true)-or-not[bool]$rootDisposition.delete_pending){throw 'Final cache-root disposition receipt was malformed'};$cacheEvidence.final_root_delete_pending=[bool]$rootDisposition.delete_pending
            $cacheEvidence.final_root_close=Close-Q009CheckedNativeHandle $cacheHandleCustody.native_cell final_root 'Final cache-root close';if(-not(Test-Q009CheckedCloseReceipt $cacheEvidence.final_root_close)){throw 'Final cache-root close receipt was malformed'}
            $cacheAbsenceAfterCleanup=Assert-Q009PathAbsentStrict $projectCacheRoot;if(-not(Test-Q009StrictAbsenceReceipt $cacheAbsenceAfterCleanup)){throw 'Final cache-root absence receipt was malformed'}
            $nonterminal=@($cacheHandleCustody.native_cell.NonTerminalSlots());if($nonterminal.Count-ne0){throw ('Cache native custody retained nonterminal handles: '+($nonterminal-join', '))}
            $cacheHandleReleased=$true;$cacheEvidence.all_native_handles_terminal=$true;$cacheEvidence.removed=$true
        }catch{
            $cacheCleanupFailure=$_.Exception.Message;$cacheEvidence.removed=$false;$cacheHandleReleased=$false
            try{$failureClose=Close-Q009AllOpenNativeHandles $cacheHandleCustody.native_cell 'Failed cache cleanup terminal release';$cacheEvidence.all_native_handles_terminal=[bool]$failureClose.all_terminal;if(@($failureClose.errors).Count){$cacheCleanupFailure=Join-LauncherError $cacheCleanupFailure ('terminal release: '+(@($failureClose.errors)-join'; '))}}catch{$cacheCleanupFailure=Join-LauncherError $cacheCleanupFailure ('terminal release threw: '+$_.Exception.Message)}
            $launcherError=Join-LauncherError $launcherError ('Sentinel-pinned cache cleanup: '+$cacheCleanupFailure)
        }
    }else{
        $profilesRemoved=$false;$cacheEvidence.removed=$false
        try{$blockedClose=Close-Q009AllOpenNativeHandles $cacheHandleCustody.native_cell 'Blocked cache custody release';$cacheHandleReleased=[bool]$blockedClose.all_terminal;$cacheEvidence.all_native_handles_terminal=$cacheHandleReleased;if(@($blockedClose.errors).Count){throw (@($blockedClose.errors)-join'; ')}}catch{$cacheHandleReleased=$false;$cacheEvidence.all_native_handles_terminal=$false;$launcherError=Join-LauncherError $launcherError ('Retained cache handle release after blocked cleanup: '+$_.Exception.Message)}
        $launcherError=Join-LauncherError $launcherError 'Owned profiles and candidate cache were retained because exact process/root/descendant cleanup plus mutex-proved global quiescence was not proved'
    }
    $finalProvenanceValid=$ownerClaimValid-and$identityStable-and$environmentRestored-and$profilesRemoved-and[bool]$cacheEvidence.removed-and$cacheHandleReleased-and$phaseResidualFree-and$preCleanupQuiescent-and[bool]$executableEvidence.godot.final_stable-and[bool]$executableEvidence.python.final_stable
    $cleanupSucceeded=$finalProvenanceValid
    if(Test-MayReleaseExclusiveReservation $leaseOwned $cleanupSucceeded $finalProvenanceValid $processCustody){
        try{
            $prePublicationCustody=Invoke-Q009MutexCritical -RunContext $runContext -Body {
                Assert-ExclusiveReservationOwned $launcherIdentity $candidateCommit $candidateTree $attemptId $pinned $dependencyPins $environmentBaseline $ownerClaim $ownerClaimText $ownerClaimSha256 $EvidenceRoot $evidenceRootOwnership $heldExclusiveLease $runContext
                [void](Assert-ExecutableIdentity 'Godot pre-publication' $GodotPath $canonicalGodotPath $ExpectedGodotSha256 $executableEvidence.godot.actual);[void](Assert-ExecutableIdentity 'Python pre-publication' $PythonPath $canonicalPythonPath $ExpectedPythonSha256 $executableEvidence.python.actual)
                $quiescence=Get-StrictGlobalQuiescenceEvidence $launcherIdentity $candidateCommit $candidateTree $attemptId $pinned $dependencyPins $environmentBaseline $ownerClaim $ownerClaimText $ownerClaimSha256 $EvidenceRoot $evidenceRootOwnership $heldExclusiveLease $runContext -Context release
                if(-not(Test-GlobalQuiescenceEvidenceShape $quiescence)){throw 'Pre-publication global quiescence receipt was malformed'}
                $publicationProcessEvidence=Get-FinalOwnedProcessResidualEvidence @($phases) $processCustody $runContext
                if(-not(Test-MayRemoveOwnedRuntimeArtifacts $publicationProcessEvidence $runContext)){throw 'Final process/job custody was not exactly clean before summary publication'}
                [void](Assert-Q009HeldExclusiveLease $heldExclusiveLease $runContext)
                $publicationProfileAbsence=Assert-Q009PathAbsentStrict $profileRoot;if(-not(Test-Q009StrictAbsenceReceipt $publicationProfileAbsence)){throw 'Pre-publication profile absence receipt was malformed'}
                $publicationCacheAbsence=Assert-Q009PathAbsentStrict $projectCacheRoot;if(-not(Test-Q009StrictAbsenceReceipt $publicationCacheAbsence)){throw 'Pre-publication cache absence receipt was malformed'}
                $publicationDependencyReceipts=Assert-Q009TrackedDependencyPinsStable $pinned $dependencyPins $runContext
                return [ordered]@{proved=[bool]$quiescence.proved;observed_utc=[string]$quiescence.observed_utc;count=[int]$quiescence.godot_count;identity_records=@($quiescence.godot_identities);other_lease_count=[int]$quiescence.other_lease_count;under_mutex=[bool]$true;strict_zero_required=[bool]$true;process_custody=$publicationProcessEvidence;profile_absence=$publicationProfileAbsence;cache_absence=$publicationCacheAbsence;dependency_pins_held=[bool]$true;dependency_pin_receipts=$publicationDependencyReceipts;exclusive_held=[bool]$true;exclusive_receipt_sha256=[string]$heldExclusiveLease.receipt.receipt_sha256;run_context_sha256=[string]$runContext.context_sha256}
            }
            if(-not(Test-Q009PrePublicationCustodyShape $prePublicationCustody $runContext $heldExclusiveLease.receipt $pinned $dependencyPinReceipts)){throw 'Pre-publication EXCLUSIVE/dependency custody failed its exact closed schema'}
        }catch{$launcherError=Join-LauncherError $launcherError ('Pre-publication custody: '+$_.Exception.Message);$cleanupSucceeded=$false;$finalProvenanceValid=$false;$prePublicationCustody=$null}
    }elseif($leaseOwned){
        $launcherError=Join-LauncherError $launcherError 'EXCLUSIVE reservation retained because final cleanup/provenance was not proved'
    }
    if($null-eq$prePublicationCustody){$launcherError=Join-LauncherError $launcherError 'Final mutex-proved zero-Godot/lease evidence before publication was absent';$cleanupSucceeded=$false;$finalProvenanceValid=$false}
    if(-not$cleanupSucceeded-or-not$leaseOwned){$outcome='invalid';$overallExit=1}
}

$zeroGodot=$null-ne$prePublicationCustody-and[bool]$prePublicationCustody.proved
$ownerArtifact=$null
try{if($evidenceRootReady){$ownerArtifact=Get-FileArtifact $ownerClaim;if($ownerClaimEstablished-and(-not$ownerArtifact.present-or[string]$ownerArtifact.sha256-cne$ownerClaimSha256)){throw 'Attempt-owner artifact was missing or hash-mismatched during summary sealing'}}}catch{$launcherError=Join-LauncherError $launcherError ('Owner artifact sealing: '+$_.Exception.Message);$ownerClaimValid=$false;$outcome='invalid';$overallExit=1}
$heldExclusiveReceipt=if($null-ne$heldExclusiveLease){$heldExclusiveLease.receipt}else{$null}
try{
    if(-not$evidenceRootReady-or-not$ownerClaimValid-or$null-eq$evidenceRootOwnership){throw 'Terminal evidence sealing requires the exact owned evidence root and owner claim'}
    $terminalEvidenceSafe=$cleanupSucceeded-and$finalProvenanceValid-and$leaseOwned-and(Test-Q009RunContextShape $runContext)-and(Test-Q009PrePublicationCustodyShape $prePublicationCustody $runContext $heldExclusiveReceipt $pinned $dependencyPinReceipts)
    if(-not$terminalEvidenceSafe){$outcome='invalid';$overallExit=1}
    $evidenceTerminalOwnerReceipt=[ordered]@{
        schema_version=[int]1;attempt_id=[string]$attemptId;qualifying_safe=[bool]$terminalEvidenceSafe;outcome=[string]$outcome;exit_code=[int]$overallExit
        run_context_sha256=if(Test-Q009RunContextShape $runContext){[string]$runContext.context_sha256}else{[string]''}
        candidate_commit=[string]$candidateCommit;candidate_tree=[string]$candidateTree;final_process_evidence=$finalOwnedProcessEvidence
        pre_cleanup_quiescence=$preCleanupQuiescence;pre_publication_custody=$prePublicationCustody;exclusive_held_receipt_sha256=if($leaseOwned-and$null-ne$heldExclusiveReceipt){[string]$heldExclusiveReceipt.receipt_sha256}else{[string]''}
        profile_manifest_chain=$profileManifestChain;cache_manifest_chain=$cacheManifestChain
        evidence_root_identity=$evidenceRootOwnership.root_identity;owner_claim_identity=$evidenceRootOwnership.claim_identity;owner_claim_sha256=[string]$ownerClaimSha256
        cleanup_succeeded=[bool]$cleanupSucceeded;provenance_valid=[bool]$finalProvenanceValid
    }
    if(-not(Test-Q009EvidenceTerminalOwnerReceiptShape $evidenceTerminalOwnerReceipt $runContext $evidenceRootOwnership $heldExclusiveReceipt $pinned $dependencyPinReceipts)){
        if($terminalEvidenceSafe){$launcherError=Join-LauncherError $launcherError 'Terminal evidence owner receipt rejected otherwise qualifying custody';$terminalEvidenceSafe=$false;$outcome='invalid';$overallExit=1;$evidenceTerminalOwnerReceipt.qualifying_safe=$false}
        if(-not(Test-Q009EvidenceTerminalOwnerReceiptShape $evidenceTerminalOwnerReceipt $runContext $evidenceRootOwnership $heldExclusiveReceipt $pinned $dependencyPinReceipts)){throw 'Terminal evidence owner receipt failed its exact closed schema'}
    }
    $evidenceTerminalManifestChain=New-Q009OwnedChildManifestChainHead -RootPath $EvidenceRoot -RootIdentity $evidenceRootOwnership.root_identity -AttemptId $attemptId -Boundary 'evidence_terminal_before_summary' -OwnerKind evidence_owner -OwnerReceipt $evidenceTerminalOwnerReceipt -PreviousHead $evidenceRootOwnership.owned_child_chain_head
    if(-not(Test-Q009OwnedChildManifestChainHeadShape $evidenceTerminalManifestChain $evidenceRootOwnership.root_identity $attemptId 'evidence_terminal_before_summary')){throw 'Terminal evidence-root manifest chain failed its exact closed schema'}
}catch{
    $launcherError=Join-LauncherError $launcherError ('Terminal evidence sealing: '+$_.Exception.Message);$terminalEvidenceSafe=$false;$outcome='invalid';$overallExit=1;$evidenceTerminalManifestChain=$null
}
$summary=$null
try{
    $summary=[ordered]@{
        schema_version=3;tool='rw06_1_environment_qualifying_supervisor';mode=$Mode;attempt_id=$attemptId;outcome=$outcome;passed=$false;workload_passed=($overallExit-eq0-and$terminalEvidenceSafe);terminal_release_required=$true;publication_state='awaiting_exclusive_release';exit_code=$overallExit;launcher_error=$launcherError;started_utc=$startedUtc.ToString('o');completed_utc=[DateTime]::UtcNow.ToString('o')
        candidate=[ordered]@{expected_commit=$ExpectedCommit;expected_tree=$ExpectedTree;final_commit=$postCommit;final_tree=$postTree;clean=$postStatus.Count-eq0;identity_stable=$identityStable;exact_remote_refs=@($exactRemoteRefs);final_remote_refs=@($postRemoteRefs);remote_refs_stable=$remoteRefsStable;pushed=($exactRemoteRefs.Count-gt0)}
        executables=$executableEvidence;files=$pinned;manifest=[ordered]@{sha256=$expectedManifestSha256;git_blob=$expectedManifestBlob;legacy_fixed_evidence_refused=$true}
        custody=[ordered]@{launcher_identity=$launcherIdentity;run_context=$runContext;attempt_owner=[ordered]@{established=$ownerClaimEstablished;valid=$ownerClaimValid;expected_sha256=$ownerClaimSha256;artifact=$ownerArtifact;ownership=$evidenceRootOwnership};exclusive_lease=$exclusiveLeaseEvidence;exclusive_held_through_summary_publication=$leaseOwned;exclusive_lease_ownership=$exclusiveLeaseOwnership;exclusive_wait_observations=@($exclusiveWaitObservations);dependency_pin_receipts=$dependencyPinReceipts;dependency_pins_held_through_summary_publication=(-not$dependencyPinsReleased);process_custody=$processCustody;final_owned_process_evidence=$finalOwnedProcessEvidence;pre_cleanup_quiescence=$preCleanupQuiescence;pre_publication_custody=$prePublicationCustody;profile_manifest_chain=$profileManifestChain;cache_manifest_chain=$cacheManifestChain;terminal_owner_receipt=$evidenceTerminalOwnerReceipt;evidence_terminal_manifest_chain=$evidenceTerminalManifestChain;environment_baseline=$environmentBaseline;canonical_lease_root=$leaseRoot;launch_mutex=$launchMutexName;requested_evidence_root=$requestedEvidenceRoot;evidence_root=$EvidenceRoot;evidence_root_ready=$evidenceRootReady}
        matrix=[ordered]@{expected_runs=$expectedRuns;expected_visits=$expectedVisits;expected_travels=$expectedTravels;observed_result_rows=$results.Count;observed_visits=$observedVisits;observed_travels=$observedTravels}
        static_report=$staticEvidence;cache=$cacheEvidence;phases=@($phases);results=@($results);failures=@($failures)
        final=[ordered]@{environment_restored=$environmentRestored;cache_removed=[bool]$cacheEvidence.removed;profiles_removed=$profilesRemoved;zero_godot=$zeroGodot;owned_exclusive_held=$leaseOwned;cleanup_succeeded=$cleanupSucceeded;provenance_valid=$finalProvenanceValid;terminal_manifest_safe=$terminalEvidenceSafe}
    }
}catch{
    $launcherError=Join-LauncherError $launcherError ('Summary construction: '+$_.Exception.Message);$outcome='invalid';$overallExit=1
    $summary=[ordered]@{schema_version=3;tool='rw06_1_environment_qualifying_supervisor';mode=$Mode;attempt_id=$attemptId;outcome='invalid';passed=$false;workload_passed=$false;terminal_release_required=$true;publication_state='awaiting_exclusive_release';exit_code=1;launcher_error=$launcherError;started_utc=$startedUtc.ToString('o');completed_utc=[DateTime]::UtcNow.ToString('o');custody=[ordered]@{evidence_root=$EvidenceRoot;evidence_root_ready=$evidenceRootReady;owned_exclusive_held=$leaseOwned}}
}
if($evidenceRootReady-and$null-ne$evidenceTerminalManifestChain){
    try{
        if(-not$leaseOwned){throw 'EXCLUSIVE reservation was not held at summary publication'}
        [void](Assert-Q009HeldExclusiveLease $heldExclusiveLease $runContext)
        Assert-NoReparsePathChain $tmpRoot $EvidenceRoot
        $summaryPublication=Publish-SummaryPairNoOverwrite $EvidenceRoot $summaryPath $summaryShaPath $summary $evidenceTerminalManifestChain $attemptId -ArtifactName 'summary.json'
        $summaryPublished=[bool]$summaryPublication.published
        $postSummaryManifestChain=New-Q009OwnedChildManifestChainHead -RootPath $EvidenceRoot -RootIdentity $evidenceRootOwnership.root_identity -AttemptId $attemptId -Boundary 'summary_published_under_exclusive' -OwnerKind evidence_owner -OwnerReceipt $summaryPublication -PreviousHead $evidenceTerminalManifestChain
        if(-not(Test-Q009OwnedChildManifestChainHeadShape $postSummaryManifestChain $evidenceRootOwnership.root_identity $attemptId 'summary_published_under_exclusive')){throw 'Post-summary evidence manifest failed its exact closed schema'}
    }catch{[Console]::Error.WriteLine("Summary pair publication failed: $($_.Exception.Message)");$summaryPublished=$false;$overallExit=1;$outcome='invalid'}
}else{[Console]::Error.WriteLine('Evidence root could not be established; no safe summary path exists.');$overallExit=1;$outcome='invalid'}

if($summaryPublished-and$terminalEvidenceSafe-and$leaseOwned){
    try{
        $preReleaseZeroGodot=Invoke-Q009MutexCritical -RunContext $runContext -Body {
            Assert-ExclusiveReservationOwned $launcherIdentity $candidateCommit $candidateTree $attemptId $pinned $dependencyPins $environmentBaseline $ownerClaim $ownerClaimText $ownerClaimSha256 $EvidenceRoot $evidenceRootOwnership $heldExclusiveLease $runContext
            [void](Assert-ExecutableIdentity 'Godot release' $GodotPath $canonicalGodotPath $ExpectedGodotSha256 $executableEvidence.godot.actual);[void](Assert-ExecutableIdentity 'Python release' $PythonPath $canonicalPythonPath $ExpectedPythonSha256 $executableEvidence.python.actual)
            $quiescence=Get-StrictGlobalQuiescenceEvidence $launcherIdentity $candidateCommit $candidateTree $attemptId $pinned $dependencyPins $environmentBaseline $ownerClaim $ownerClaimText $ownerClaimSha256 $EvidenceRoot $evidenceRootOwnership $heldExclusiveLease $runContext -Context release
            if(-not(Test-GlobalQuiescenceEvidenceShape $quiescence)){throw 'Release-time global quiescence receipt was malformed'}
            $releaseProcessEvidence=Get-FinalOwnedProcessResidualEvidence @($phases) $processCustody $runContext
            if(-not(Test-MayRemoveOwnedRuntimeArtifacts $releaseProcessEvidence $runContext)){throw 'Final process/job custody was not exactly clean inside the EXCLUSIVE release mutex'}
            [void](Assert-Q009HeldExclusiveLease $heldExclusiveLease $runContext)
            $releaseProfileAbsence=Assert-Q009PathAbsentStrict $profileRoot;if(-not(Test-Q009StrictAbsenceReceipt $releaseProfileAbsence)){throw 'Release-time profile absence receipt was malformed'}
            $releaseCacheAbsence=Assert-Q009PathAbsentStrict $projectCacheRoot;if(-not(Test-Q009StrictAbsenceReceipt $releaseCacheAbsence)){throw 'Release-time cache absence receipt was malformed'}
            $releaseDependencyPins=Close-Q009TrackedDependencyPins $pinned $dependencyPins $runContext $dependencyPinReceipts
            if(-not(Test-Q009TrackedDependencyPinReleasesShape $releaseDependencyPins $dependencyPinReceipts $pinned $runContext)){throw 'Release-time tracked dependency pin receipts were malformed'}
            [void](Assert-CleanExactCandidate ([string]$runContext.project_root) $candidateCommit $candidateTree)
            $releaseReceipt=Close-Q009HeldExclusiveLease $heldExclusiveLease $runContext
            if(-not(Test-Q009HeldExclusiveReleaseReceiptShape $releaseReceipt $heldExclusiveLease.receipt $runContext)){throw 'Released EXCLUSIVE receipt was malformed'}
            if(Test-Path -LiteralPath $exclusiveLeasePath){throw 'Exact held EXCLUSIVE reservation remained after terminal close'}
            return [ordered]@{proved=[bool]$quiescence.proved;observed_utc=[string]$quiescence.observed_utc;count=[int]$quiescence.godot_count;identity_records=@($quiescence.godot_identities);other_lease_count=[int]$quiescence.other_lease_count;under_mutex=[bool]$true;strict_zero_required=[bool]$true;process_custody=$releaseProcessEvidence;profile_absence=$releaseProfileAbsence;cache_absence=$releaseCacheAbsence;dependency_pin_releases=$releaseDependencyPins;exclusive_release=$releaseReceipt;run_context_sha256=[string]$runContext.context_sha256}
            }
        if(-not(Test-Q009ReleaseEvidenceShape $preReleaseZeroGodot $runContext $heldExclusiveReceipt $pinned $dependencyPinReceipts)){throw 'Post-summary dependency/EXCLUSIVE release evidence failed its exact closed schema'}
        $dependencyPinReleases=$preReleaseZeroGodot.dependency_pin_releases;$dependencyPinsReleased=$true;$heldExclusiveRelease=$preReleaseZeroGodot.exclusive_release;$leaseOwned=$false
        $exclusiveLeaseOwnership.created=$false;$exclusiveLeaseOwnership.validated=$false;$exclusiveLeaseOwnership.identity=$null
        if(-not(Test-ExclusiveLeaseOwnershipShape $exclusiveLeaseOwnership $false (Join-Path ([string]$runContext.canonical_lease_root) 'EXCLUSIVE.lease'))){throw 'Released EXCLUSIVE ownership receipt was malformed'}
        $terminalReceipt=[ordered]@{schema_version=[int]1;attempt_id=[string]$attemptId;qualifying_pass=[bool]($overallExit-eq0-and$outcome-ceq'pass');outcome=[string]$outcome;exit_code=[int]$overallExit;run_context_sha256=[string]$runContext.context_sha256;summary_publication=$summaryPublication;summary_published_under_exclusive=[bool]$true;terminal_release=$preReleaseZeroGodot;completed_utc=[string][DateTime]::UtcNow.ToString('o')}
        if(-not(Test-Q009TerminalCompletionReceiptShape $terminalReceipt $runContext $heldExclusiveReceipt $summaryPublication $pinned $dependencyPinReceipts)){throw 'Terminal completion receipt failed its exact closed schema'}
        $terminalPublication=Publish-SummaryPairNoOverwrite $EvidenceRoot $terminalPath $terminalShaPath $terminalReceipt $postSummaryManifestChain $attemptId -ArtifactName 'terminal.json'
        if(-not(Test-Q009SummaryPublicationReceiptShape $terminalPublication)){throw 'Terminal completion pair failed its exact publication schema'}
        $finalEvidenceTree=Get-Q009ExactOwnedTreeManifest $EvidenceRoot
        if(-not(Test-Q009ExactOwnedTreeManifestShape $finalEvidenceTree $evidenceRootOwnership.root_identity)-or-not(Test-Q009TerminalTreeDelta $postSummaryManifestChain.manifest $finalEvidenceTree $terminalPublication)){throw 'Final evidence tree failed exact terminal-only delta readback after publication'}
    }catch{
        $leaseOwned=$null-ne$heldExclusiveLease-and$heldExclusiveLease.released-is[bool]-and-not[bool]$heldExclusiveLease.released
        $launcherError=Join-LauncherError $launcherError ('Post-summary EXCLUSIVE release/terminal publication: '+$_.Exception.Message);$overallExit=1;$outcome='invalid';$terminalPublication=$null;$finalEvidenceTree=$null
    }
}elseif($leaseOwned){
    $launcherError=Join-LauncherError $launcherError 'EXCLUSIVE reservation retained because no exact safe summary publication authorized terminal release';$overallExit=1;$outcome='invalid'
}

$summaryReceiptHash=if($summaryPublished){[string]$summaryPublication.sha256}else{[string]''};$summaryPrecommitHead=if($summaryPublished){[string]$summaryPublication.precommit_manifest_head_sha256}else{[string]''};$terminalReceiptHash=if($null-ne$terminalPublication){[string]$terminalPublication.sha256}else{[string]''};$finalTreeHash=if($null-ne$finalEvidenceTree){[string]$finalEvidenceTree.sha256}else{[string]''}
[Console]::Out.WriteLine(("RW06_1_ENVIRONMENT_SUPERVISOR mode={0} outcome={1} evidence={2} summary_published={3} summary_sha256={4} precommit_manifest_head_sha256={5} terminal_published={6} terminal_sha256={7} final_tree_sha256={8} exclusive_released={9}"-f$Mode,$outcome,$EvidenceRoot,$summaryPublished,$summaryReceiptHash,$summaryPrecommitHead,($null-ne$terminalPublication),$terminalReceiptHash,$finalTreeHash,(-not$leaseOwned)));if($launcherError){[Console]::Error.WriteLine($launcherError)};exit $overallExit
