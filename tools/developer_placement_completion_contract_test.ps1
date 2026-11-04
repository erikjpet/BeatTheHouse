param([switch]$Quiet)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$validatorPath = Join-Path $PSScriptRoot 'validate_project.ps1'
$tokens = $null
$parseErrors = $null
$validatorAst = [Management.Automation.Language.Parser]::ParseFile($validatorPath, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -ne 0) { throw 'Validator syntax is invalid.' }

# Load only the exact pure production predicates; never invoke the full
# validator, engine, launcher, watcher or process/resource qualification paths.
foreach ($name in @('Test-JsonObjectRoot', 'Test-FinitePlacementCoordinate', 'Test-PlacementSlotLayer', 'Test-PlacementSlotScale', 'Test-PlacementPositionIdsMatch', 'Get-PlacementCompletionState')) {
    $definitions = @($validatorAst.FindAll({
        param($node)
        $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq $name
    }, $true))
    if ($definitions.Count -ne 1) { throw "Expected one exact production function $name." }
    Invoke-Expression $definitions[0].Extent.Text
}
$placementBlocks = @($validatorAst.FindAll({
    param($node)
    $node -is [Management.Automation.Language.TryStatementAst] -and
    $node.Body.Statements.Count -gt 0 -and
    $node.Body.Statements[0].Extent.Text.StartsWith('$placementSurfaceAuthority =')
}, $true))
if ($placementBlocks.Count -ne 1) { throw 'Expected one exact production placement-validation block.' }
$placementBlock = $placementBlocks[0].Extent.Text
$script:checks = 0
function Assert-Contract {
    param([bool]$Condition, [string]$Message)
    $script:checks++
    if (-not $Condition) { throw $Message }
}
function New-OrdinalSet {
    param([string[]]$Ids)
    return ,([Collections.Generic.HashSet[string]]::new($Ids, [StringComparer]::Ordinal))
}
function Copy-Fixture {
    param([object]$Value)
    return ConvertFrom-Json -InputObject (ConvertTo-Json -InputObject $Value -Depth 30)
}

$expectedShared = New-OrdinalSet @('fixed.a', 'exit.leave')
$expectedScenario = New-OrdinalSet @('scenario.actor')
$emptyExpected = New-OrdinalSet @()
$complete = ConvertFrom-Json '{"fixed.a":[10,20],"exit.leave":[30,40]}'
$reordered = ConvertFrom-Json '{"exit.leave":[30,40],"fixed.a":[10,20]}'
$partial = ConvertFrom-Json '{"fixed.a":[10,20]}'
$extra = ConvertFrom-Json '{"fixed.a":[10,20],"exit.leave":[30,40],"fixed.injected":[50,60]}'
$wrongIdentity = ConvertFrom-Json '{"fixed.a":[10,20],"fixed.injected":[30,40]}'
$wrongCase = ConvertFrom-Json '{"FIXED.A":[10,20],"exit.leave":[30,40]}'
$scenario = ConvertFrom-Json '{"scenario.actor":[50,60]}'
$empty = ConvertFrom-Json '{}'

$completionCases = @(
    @{ Name = 'complete base'; Flag = $true; Shared = $complete; Saved = $true; Recovered = $false },
    @{ Name = 'property order'; Flag = $true; Shared = $reordered; Saved = $true; Recovered = $false },
    @{ Name = 'missing shared'; Flag = $true; Shared = $partial; Saved = $false; Recovered = $true },
    @{ Name = 'extra shared'; Flag = $true; Shared = $extra; Saved = $false; Recovered = $true },
    @{ Name = 'equal count wrong ID'; Flag = $true; Shared = $wrongIdentity; Saved = $false; Recovered = $true },
    @{ Name = 'case-sensitive ID'; Flag = $true; Shared = $wrongCase; Saved = $false; Recovered = $true },
    @{ Name = 'explicit false'; Flag = $false; Shared = $complete; Saved = $false; Recovered = $false },
    @{ Name = 'absent flag'; Flag = $null; Shared = $complete; Saved = $false; Recovered = $false },
    @{ Name = 'string flag'; Flag = 'true'; Shared = $complete; Saved = $false; Recovered = $false },
    @{ Name = 'integer flag'; Flag = 1; Shared = $complete; Saved = $false; Recovered = $false },
    @{ Name = 'array positions'; Flag = $true; Shared = @(@(10, 20), @(30, 40)); Saved = $false; Recovered = $true },
    @{ Name = 'hashtable positions'; Flag = $true; Shared = @{ 'fixed.a' = @(10, 20); 'exit.leave' = @(30, 40) }; Saved = $false; Recovered = $true }
)
foreach ($case in $completionCases) {
    $before = ConvertTo-Json -InputObject $case.Shared -Depth 10 -Compress
    $state = Get-PlacementCompletionState -SavedFlag $case.Flag -SharedPositions $case.Shared -ExpectedSharedIds $expectedShared
    Assert-Contract ($state.saved -is [bool] -and $state.saved -eq $case.Saved -and $state.recovered_catalog_drift -eq $case.Recovered) "Completion mismatch: $($case.Name)."
    Assert-Contract ((ConvertTo-Json -InputObject $case.Shared -Depth 10 -Compress) -ceq $before) "Completion mutated coordinates: $($case.Name)."
}
$state = Get-PlacementCompletionState -SavedFlag $true -SharedPositions $complete -ExpectedSharedIds $expectedShared -ScenarioPositions $scenario -ExpectedScenarioIds $expectedScenario
Assert-Contract ($state.saved -and -not $state.recovered_catalog_drift) 'Complete scenario was rejected.'
foreach ($missing in @('shared', 'scenario')) {
    $sharedInput = if ($missing -eq 'shared') { $partial } else { $complete }
    $scenarioInput = if ($missing -eq 'scenario') { $empty } else { $scenario }
    $state = Get-PlacementCompletionState -SavedFlag $true -SharedPositions $sharedInput -ExpectedSharedIds $expectedShared -ScenarioPositions $scenarioInput -ExpectedScenarioIds $expectedScenario
    Assert-Contract ($state.raw_saved -and -not $state.saved -and $state.recovered_catalog_drift) "Incomplete $missing scenario was accepted as complete."
}
$state = Get-PlacementCompletionState -SavedFlag $true -SharedPositions $null -ExpectedSharedIds $emptyExpected -ExpectedScenarioIds $emptyExpected
Assert-Contract $state.saved 'Absent position fields must match an empty authored set, as the runtime dictionary default does.'

# Geometry remains a separate strict gate, including exact numeric types.
foreach ($valid in @(0, -10, 0.25, [double]::MaxValue)) { Assert-Contract (Test-FinitePlacementCoordinate $valid) 'Finite numeric coordinate rejected.' }
foreach ($invalid in @($null, '10', $true, [double]::NaN, [double]::PositiveInfinity, [double]::NegativeInfinity, @())) { Assert-Contract (-not (Test-FinitePlacementCoordinate $invalid)) 'Non-numeric/non-finite coordinate accepted.' }
foreach ($valid in @(-1, 0, 1)) { Assert-Contract (Test-PlacementSlotLayer $valid) 'Valid layer rejected.' }
foreach ($invalid in @(-2, 2, 0.5, '1', $true, [double]::NaN)) { Assert-Contract (-not (Test-PlacementSlotLayer $invalid)) 'Invalid layer accepted.' }
foreach ($valid in @(0.5, 1, 2)) { Assert-Contract (Test-PlacementSlotScale $valid) 'Valid scale rejected.' }
foreach ($invalid in @(0.49, 2.01, '1', $null, [double]::PositiveInfinity)) { Assert-Contract (-not (Test-PlacementSlotScale $invalid)) 'Invalid scale accepted.' }

$placementPath = Join-Path $root 'data/environments/developer_placement_overrides.json'
$originalHash = (Get-FileHash -LiteralPath $placementPath -Algorithm SHA256).Hash
$originalBytes = [IO.File]::ReadAllBytes($placementPath)
$tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$tempName = 'bth-placement-completion-' + [guid]::NewGuid().ToString('N')
$tempRoot = Join-Path $tempBase $tempName
$created = $false
try {
    $null = New-Item -ItemType Directory -Path $tempRoot
    $created = $true
    $fixturePath = Join-Path $tempRoot 'placement.json'
    function Invoke-PlacementBlock {
        param([object]$Payload, [switch]$Actual)
        $placementOverridePath = $placementPath
        if (-not $Actual) {
            [IO.File]::WriteAllText($fixturePath, (ConvertTo-Json -InputObject $Payload -Depth 30), [Text.UTF8Encoding]::new($false))
            $placementOverridePath = $fixturePath
        }
        $failures = [Collections.Generic.List[string]]::new()
        $placementCompletionRecoveries = [Collections.Generic.List[object]]::new()
        $diagnostics = @(Invoke-Expression $placementBlock 6>&1 | ForEach-Object { [string]$_ })
        return [pscustomobject]@{
            Failures = @($failures); Recoveries = @($placementCompletionRecoveries); Diagnostics = $diagnostics
            Shared = $sharedPlacementSlots; Scenario = $scenarioPlacementSlots; Payload = $placementOverrides
        }
    }
    $actual = Invoke-PlacementBlock -Actual
    Assert-Contract ($actual.Failures.Count -eq 0) ('Current placement schema failed: ' + ($actual.Failures -join '; '))
    $expectedRecoveries = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($room in $actual.Payload.rooms.PSObject.Properties) {
        $state = Get-PlacementCompletionState -SavedFlag $room.Value.base_saved -SharedPositions $room.Value.slot_positions -ExpectedSharedIds $actual.Shared[$room.Name]
        if ($state.recovered_catalog_drift) { [void]$expectedRecoveries.Add($room.Name + '::__base') }
        foreach ($layout in $room.Value.scenario_layouts.PSObject.Properties) {
            $key = $room.Name + '::' + $layout.Name
            $state = Get-PlacementCompletionState -SavedFlag $layout.Value.saved -SharedPositions $room.Value.slot_positions -ExpectedSharedIds $actual.Shared[$room.Name] -ScenarioPositions $layout.Value.slot_positions -ExpectedScenarioIds $actual.Scenario[$key]
            if ($state.recovered_catalog_drift) { [void]$expectedRecoveries.Add($key) }
        }
    }
    $observedRecoveries = New-OrdinalSet @($actual.Recoveries | ForEach-Object layout_id)
    Assert-Contract ($observedRecoveries.SetEquals($expectedRecoveries)) 'Current catalog recoveries do not match exact effective incompleteness.'
    foreach ($recovery in $actual.Recoveries) {
        Assert-Contract ($recovery.completion.raw_saved -and -not $recovery.completion.saved -and $recovery.completion.recovered_catalog_drift) 'Stale current flag was accepted as complete.'
        Assert-Contract (@($actual.Diagnostics | Where-Object { $_.Contains($recovery.layout_id) -and $_.Contains('effective_saved=false') -and $_.Contains('incomplete') }).Count -eq 1) 'Recovered layout lacks an explicit incomplete diagnostic.'
    }

    $roomId = 'corner_store'
    $scenarioKey = @($actual.Scenario.Keys | Where-Object { $_.StartsWith($roomId + '::', [StringComparison]::Ordinal) } | Sort-Object)[0]
    Assert-Contract (-not [string]::IsNullOrEmpty($scenarioKey)) 'Fixture room requires a current scenario authority.'
    $scenarioId = $scenarioKey.Substring($roomId.Length + 2)
    $sharedPositions = [ordered]@{}
    foreach ($id in @($actual.Shared[$roomId] | Sort-Object)) { $sharedPositions[$id] = @(101, 202) }
    $scenarioPositions = [ordered]@{}
    foreach ($id in @($actual.Scenario[$scenarioKey] | Sort-Object)) { $scenarioPositions[$id] = @(303, 404) }
    $scenarioLayouts = [ordered]@{}
    $scenarioLayouts[$scenarioId] = [pscustomobject]@{ saved = $true; slot_positions = [pscustomobject]$scenarioPositions }
    $rooms = [ordered]@{}
    $rooms[$roomId] = [pscustomobject]@{ base_saved = $true; slot_positions = [pscustomobject]$sharedPositions; scenario_layouts = [pscustomobject]$scenarioLayouts }
    $validFixture = [pscustomobject]@{ schema_version = 3; rooms = [pscustomobject]$rooms }
    $baseline = Invoke-PlacementBlock -Payload $validFixture
    Assert-Contract ($baseline.Failures.Count -eq 0 -and $baseline.Recoveries.Count -eq 0) 'Complete fixture should be strictly valid without recovery.'
    $sharedId = @($actual.Shared[$roomId] | Sort-Object)[0]
    $scenarioSlotId = @($actual.Scenario[$scenarioKey] | Sort-Object)[0]
    foreach ($scope in @('shared', 'scenario')) {
        $fixture = Copy-Fixture $validFixture
        if ($scope -eq 'shared') { $fixture.rooms.$roomId.slot_positions.PSObject.Properties.Remove($sharedId) }
        else { $fixture.rooms.$roomId.scenario_layouts.$scenarioId.slot_positions.PSObject.Properties.Remove($scenarioSlotId) }
        $recovered = Invoke-PlacementBlock -Payload $fixture
        Assert-Contract ($recovered.Failures.Count -eq 0 -and $recovered.Recoveries.Count -gt 0) "Missing $scope slot must be recovered as incomplete."
        foreach ($row in $recovered.Recoveries) { Assert-Contract (-not $row.completion.saved) 'Hostile incomplete true flag escaped into effective completion.' }
    }

    $hostileCases = @(
        @{ Name = 'unsupported room field'; Pattern = 'unsupported field'; Mutate = { param($p) $p.rooms.corner_store | Add-Member -NotePropertyName injected -NotePropertyValue $true } },
        @{ Name = 'non-Boolean base marker'; Pattern = 'base_saved must be Boolean'; Mutate = { param($p) $p.rooms.corner_store.base_saved = 'true' } },
        @{ Name = 'unknown shared ID'; Pattern = 'unauthorised shared slot'; Mutate = { param($p) $p.rooms.corner_store.slot_positions | Add-Member -NotePropertyName 'fixed.injected' -NotePropertyValue @(10, 20) } },
        @{ Name = 'short coordinates'; Pattern = 'exactly two coordinates'; Mutate = { param($p) $p.rooms.corner_store.slot_positions.$sharedId = @(10) } },
        @{ Name = 'string coordinate'; Pattern = 'non-finite coordinate'; Mutate = { param($p) $p.rooms.corner_store.slot_positions.$sharedId = @('10', 20) } },
        @{ Name = 'fractional layer'; Pattern = 'must be -1, 0, or 1'; Mutate = { param($p) $fields = @{}; $fields[$sharedId] = 0.5; $p.rooms.corner_store | Add-Member -NotePropertyName slot_layers -NotePropertyValue ([pscustomobject]$fields) } },
        @{ Name = 'out of range scale'; Pattern = 'must be between 0.5 and 2.0'; Mutate = { param($p) $fields = @{}; $fields[$sharedId] = 2.01; $p.rooms.corner_store | Add-Member -NotePropertyName slot_scales -NotePropertyValue ([pscustomobject]$fields) } },
        @{ Name = 'non-Boolean scenario marker'; Pattern = 'saved must be Boolean'; Mutate = { param($p) $p.rooms.corner_store.scenario_layouts.$scenarioId.saved = 1 } },
        @{ Name = 'unknown scenario ID'; Pattern = 'not authored'; Mutate = { param($p) $p.rooms.corner_store.scenario_layouts | Add-Member -NotePropertyName 'unknown_scenario' -NotePropertyValue ([pscustomobject]@{ saved = $true; slot_positions = [pscustomobject]@{} }) } },
        @{ Name = 'unknown scenario slot'; Pattern = 'unauthorised slot'; Mutate = { param($p) $p.rooms.corner_store.scenario_layouts.$scenarioId.slot_positions | Add-Member -NotePropertyName 'scenario.injected' -NotePropertyValue @(10, 20) } },
        @{ Name = 'nonobject scenario positions'; Pattern = 'unsupported field'; Mutate = { param($p) $p.rooms.corner_store.scenario_layouts.$scenarioId.slot_positions = @() } }
    )
    foreach ($case in $hostileCases) {
        $fixture = Copy-Fixture $validFixture
        & $case.Mutate $fixture
        $result = Invoke-PlacementBlock -Payload $fixture
        Assert-Contract (@($result.Failures | Where-Object { $_.Contains($case.Pattern) }).Count -gt 0) "Strict schema/geometry check weakened: $($case.Name)."
    }

    # The read-only validator recovery does not relax the game's strict write
    # callback, complete base/scenario slot sets, or geometry normalization.
    $runtime = Get-Content -LiteralPath (Join-Path $root 'scripts/core/developer_placement_store.gd') -Raw
    function Get-RuntimeFunction {
        param([string]$Name)
        $match = [regex]::Match($runtime, '(?m)^static func ' + [regex]::Escape($Name) + '\(')
        if (-not $match.Success) { throw "Runtime seam missing: $Name" }
        $next = [regex]::Match($runtime.Substring($match.Index + 1), '(?m)^static func ')
        $end = if ($next.Success) { $match.Index + 1 + $next.Index } else { $runtime.Length }
        return $runtime.Substring($match.Index, $end - $match.Index)
    }
    $writer = Get-RuntimeFunction '_write_payload'
    $roomValidator = Get-RuntimeFunction '_room_payload_valid'
    Assert-Contract ($writer.Contains('DurableStoreScript.write_json(') -and $writer.Contains('return _placement_payload_valid(value)')) 'Strict runtime write callback was bypassed.'
    Assert-Contract ([regex]::Matches($roomValidator, '_position_ids_match\(').Count -eq 3 -and $roomValidator.Contains('_slot_field_valid(')) 'Strict runtime complete-set or geometry validation was removed.'
    Assert-Contract ((Get-RuntimeFunction '_slot_field_valid').Contains('_normalized_slot_value(')) 'Strict runtime geometry normalization was bypassed.'
    Assert-Contract ((Get-FileHash -LiteralPath $placementPath -Algorithm SHA256).Hash -ceq $originalHash) 'Runtime placement JSON hash changed.'
    Assert-Contract ([Linq.Enumerable]::SequenceEqual([byte[]]$originalBytes, [byte[]][IO.File]::ReadAllBytes($placementPath))) 'Runtime placement JSON bytes changed.'
    if (-not $Quiet) { Write-Host "Developer placement completion contract passed ($script:checks checks; $($actual.Recoveries.Count) current stale flags recovered as incomplete; $($hostileCases.Count) strict schema/geometry fixtures)." }
}
finally {
    if ($created) {
        $resolved = [IO.Path]::GetFullPath($tempRoot)
        if ([IO.Path]::GetDirectoryName($resolved).TrimEnd('\', '/') -cne $tempBase.TrimEnd('\', '/') -or [IO.Path]::GetFileName($resolved) -cne $tempName) { throw 'Refusing cleanup outside the exact owned temporary fixture directory.' }
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
