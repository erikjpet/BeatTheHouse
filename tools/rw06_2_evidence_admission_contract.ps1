[CmdletBinding()]
param(
    [string]$ReportPath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Worktree = Split-Path -Parent $PSScriptRoot
$AdmissionPath = Join-Path $PSScriptRoot 'rw06_2_evidence_admission.ps1'
$PreflightPath = Join-Path $PSScriptRoot 'rw06_2_heist_seed_preflight.ps1'
$RunnerPath = Join-Path $PSScriptRoot 'rw06_2_ending_replay.ps1'
$FixedLauncherPath = Join-Path $PSScriptRoot 'rw06_2_final_evidence.ps1'
if ([string]::IsNullOrWhiteSpace($ReportPath)) {
    $ReportPath = Join-Path $Worktree '.tmp\rw06_2\evidence_admission_contract.json'
}

$failures = [Collections.Generic.List[string]]::new()
$resolverValidFixtures = 0
$resolverHostileFixtures = 0
$preflightValidFixtures = 0
$admissionObjectHostileFixtures = 0
$admissionUniversalSchemaHostileFixtures = 0
$preflightHostileFixtures = 0
$preflightUniversalSchemaHostileFixtures = 0
$sourceValidFixtures = 0
$sourceHostileFixtures = 0
$outerValidFixtures = 0
$outerHostileFixtures = 0
$outerUniversalSchemaHostileFixtures = 0


function Add-Failure {
    param([Parameter(Mandatory = $true)][string]$Message)
    $failures.Add($Message)
}


function ConvertTo-ContractClone {
    param([Parameter(Mandatory = $true)]$InputObject)
    return ($InputObject | ConvertTo-Json -Depth 30 -Compress | ConvertFrom-Json)
}


function Get-ContractPathValueNoEnumerate {
    param(
        [AllowNull()]$Root,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Path
    )
    $current = $Root
    foreach ($segment in $Path) {
        if ($segment -is [int32]) {
            if ($current -isnot [Array] -or $segment -lt 0 -or $segment -ge $current.Count) {
                throw "Contract fixture path has no array index '$segment'."
            }
            $current = $current[[int]$segment]
            continue
        }
        if ($segment -isnot [string] -or $current -isnot [System.Management.Automation.PSCustomObject]) {
            throw 'Contract fixture path traverses a non-object value.'
        }
        $properties = @($current.PSObject.Properties | Where-Object { $_.Name -ceq $segment })
        if ($properties.Count -cne 1) {
            throw "Contract fixture path has no exact property '$segment'."
        }
        $current = $properties[0].Value
    }
    Write-Output -NoEnumerate $current
}


function Set-ContractPathValue {
    param(
        [Parameter(Mandatory = $true)]$Root,
        [Parameter(Mandatory = $true)][object[]]$Path,
        [AllowNull()]$Value
    )
    if ($Path.Count -ceq 0) { throw 'Contract fixture root replacement must be explicit.' }
    [object[]]$parentPath = [object[]]::new(0)
    if ($Path.Count -gt 1) {
        $parentPath = [object[]]@($Path[0..($Path.Count - 2)])
    }
    $parent = Get-ContractPathValueNoEnumerate -Root $Root -Path $parentPath
    $leaf = $Path[$Path.Count - 1]
    if ($leaf -is [int32]) {
        if ($parent -isnot [Array] -or $leaf -lt 0 -or $leaf -ge $parent.Count) {
            throw "Contract fixture path has no writable array index '$leaf'."
        }
        $parent[[int]$leaf] = $Value
        return
    }
    if ($leaf -isnot [string] -or $parent -isnot [System.Management.Automation.PSCustomObject]) {
        throw 'Contract fixture path has no writable object property.'
    }
    $properties = @($parent.PSObject.Properties | Where-Object { $_.Name -ceq $leaf })
    if ($properties.Count -cne 1) { throw "Contract fixture path has no exact writable property '$leaf'." }
    $properties[0].Value = $Value
}


function Remove-ContractPathProperty {
    param(
        [Parameter(Mandatory = $true)]$Root,
        [Parameter(Mandatory = $true)][object[]]$Path
    )
    if ($Path.Count -ceq 0 -or $Path[$Path.Count - 1] -isnot [string]) {
        throw 'Contract fixture removal requires a non-root object property.'
    }
    [object[]]$parentPath = [object[]]::new(0)
    if ($Path.Count -gt 1) {
        $parentPath = [object[]]@($Path[0..($Path.Count - 2)])
    }
    $parent = Get-ContractPathValueNoEnumerate -Root $Root -Path $parentPath
    if ($parent -isnot [System.Management.Automation.PSCustomObject]) {
        throw 'Contract fixture removal parent is not an exact object.'
    }
    $parent.PSObject.Properties.Remove([string]$Path[$Path.Count - 1])
}


function Format-ContractPath {
    param([Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Path)
    if ($Path.Count -ceq 0) { return '<root>' }
    return (($Path | ForEach-Object {
        if ($_ -is [int32]) { "[$_]" } else { [string]$_ }
    }) -join '.')
}


function Add-UniversalContractNodeHostiles {
    param(
        [Parameter(Mandatory = $true)]$ValidRoot,
        [AllowNull()]$Node,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Path,
        [Parameter(Mandatory = $true)][Collections.Generic.List[object]]$Cases,
        [Parameter(Mandatory = $true)][string]$Prefix
    )
    $pathLabel = Format-ContractPath -Path $Path
    if ($Node -is [System.Management.Automation.PSCustomObject]) {
        $extraClone = ConvertTo-ContractClone $ValidRoot
        $extraTarget = Get-ContractPathValueNoEnumerate -Root $extraClone -Path $Path
        $extraTarget | Add-Member -NotePropertyName authority_override -NotePropertyValue 'hostile'
        $Cases.Add([pscustomobject]@{ name = "$Prefix $pathLabel extra authority key"; value = $extraClone })
        if ($Path.Count -gt 0) {
            foreach ($replacement in @(
                [pscustomobject]@{ suffix = 'null object'; value = $null },
                [pscustomobject]@{ suffix = 'scalar object'; value = 'hostile' },
                [pscustomobject]@{ suffix = 'array object'; value = [object[]]@([pscustomobject]@{}) },
                [pscustomobject]@{ suffix = 'empty object'; value = [pscustomobject]@{} }
            )) {
                $clone = ConvertTo-ContractClone $ValidRoot
                Set-ContractPathValue -Root $clone -Path $Path -Value $replacement.value
                $Cases.Add([pscustomobject]@{ name = "$Prefix $pathLabel $($replacement.suffix)"; value = $clone })
            }
        }
        foreach ($property in @($Node.PSObject.Properties)) {
            $childPath = [object[]]@($Path + [object[]]@([string]$property.Name))
            $clone = ConvertTo-ContractClone $ValidRoot
            Remove-ContractPathProperty -Root $clone -Path $childPath
            $Cases.Add([pscustomobject]@{ name = "$Prefix $(Format-ContractPath $childPath) missing"; value = $clone })
            Add-UniversalContractNodeHostiles -ValidRoot $ValidRoot -Node $property.Value -Path $childPath -Cases $Cases -Prefix $Prefix
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
            $clone = ConvertTo-ContractClone $ValidRoot
            Set-ContractPathValue -Root $clone -Path $Path -Value $replacement.value
            $Cases.Add([pscustomobject]@{ name = "$Prefix $pathLabel $($replacement.suffix)"; value = $clone })
        }
        $countClone = ConvertTo-ContractClone $ValidRoot
        $countValue = Get-ContractPathValueNoEnumerate -Root $countClone -Path $Path
        [object[]]$countReplacement = [object[]]::new(0)
        if ($countValue.Count -ceq 0) {
            $countReplacement = [object[]]@('hostile')
        }
        elseif ($countValue.Count -gt 1) {
            $countReplacement = [object[]]@($countValue[0..($countValue.Count - 2)])
        }
        Set-ContractPathValue -Root $countClone -Path $Path -Value $countReplacement
        $Cases.Add([pscustomobject]@{ name = "$Prefix $pathLabel count drift"; value = $countClone })
        if ($Node.Count -gt 0) {
            $elementClone = ConvertTo-ContractClone $ValidRoot
            $elementValue = Get-ContractPathValueNoEnumerate -Root $elementClone -Path $Path
            $elementValue[0] = if ($Node[0] -is [string]) { [pscustomobject]@{} } else { 'hostile' }
            $Cases.Add([pscustomobject]@{ name = "$Prefix $pathLabel wrong element"; value = $elementClone })
        }
        if ($Node.Count -gt 1) {
            $orderClone = ConvertTo-ContractClone $ValidRoot
            $orderValue = Get-ContractPathValueNoEnumerate -Root $orderClone -Path $Path
            $temporary = $orderValue[0]
            $orderValue[0] = $orderValue[1]
            $orderValue[1] = $temporary
            $Cases.Add([pscustomobject]@{ name = "$Prefix $pathLabel order drift"; value = $orderClone })
        }
        for ($index = 0; $index -lt $Node.Count; $index++) {
            if ($Node[$index] -is [System.Management.Automation.PSCustomObject]) {
                Add-UniversalContractNodeHostiles `
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
        $clone = ConvertTo-ContractClone $ValidRoot
        Set-ContractPathValue -Root $clone -Path $Path -Value $replacement.value
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
    Add-UniversalContractNodeHostiles `
        -ValidRoot $ValidRoot `
        -Node $ValidRoot `
        -Path ([object[]]@()) `
        -Cases $cases `
        -Prefix $Prefix
    return $cases.ToArray()
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
        throw "$Context property count drifted."
    }
    for ($index = 0; $index -lt $ExpectedKeys.Count; $index++) {
        if ($actualKeys[$index] -cne $ExpectedKeys[$index]) {
            throw "$Context property $index must be '$($ExpectedKeys[$index])'."
        }
    }
}


function Get-ExactContractField {
    param(
        [Parameter(Mandatory = $true)]$Value,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Context
    )
    $properties = @($Value.PSObject.Properties | Where-Object { $_.Name -ceq $Name })
    if ($properties.Count -cne 1) { throw "$Context is missing exact field '$Name'." }
    Write-Output -NoEnumerate $properties[0].Value
}


function Assert-ExactAdmissionObject {
    param(
        [AllowNull()]$Admission,
        [Parameter(Mandatory = $true)][string]$ExpectedRole,
        [Parameter(Mandatory = $true)][string]$ExpectedSeed,
        [Parameter(Mandatory = $true)][int32]$ExpectedRepeat,
        [Parameter(Mandatory = $true)][string]$Context
    )
    Assert-ExactContractObjectKeys -Value $Admission -ExpectedKeys @(
        'evidence_role', 'ending', 'seed', 'repeat', 'route_plan',
        'expected_initial_scenario', 'scenario_authority', 'scenario_injection_allowed',
        'plan_b_allowed', 'requires_isolated_profile', 'release_qualifying',
        'qualification_authority', 'owner_decisions'
    ) -Context $Context
    $expectedAuthority = if ($ExpectedRole -ceq 'fresh-interactive') {
        'post_run_interactive_review_only'
    }
    else { 'outer_independent_profile_aggregate_only' }
    $role = Get-ExactContractField $Admission 'evidence_role' $Context
    $ending = Get-ExactContractField $Admission 'ending' $Context
    $seed = Get-ExactContractField $Admission 'seed' $Context
    $repeat = Get-ExactContractField $Admission 'repeat' $Context
    $routePlan = Get-ExactContractField $Admission 'route_plan' $Context
    $scenario = Get-ExactContractField $Admission 'expected_initial_scenario' $Context
    $scenarioAuthority = Get-ExactContractField $Admission 'scenario_authority' $Context
    $scenarioAllowed = Get-ExactContractField $Admission 'scenario_injection_allowed' $Context
    $planBAllowed = Get-ExactContractField $Admission 'plan_b_allowed' $Context
    $isolated = Get-ExactContractField $Admission 'requires_isolated_profile' $Context
    $qualifying = Get-ExactContractField $Admission 'release_qualifying' $Context
    $authority = Get-ExactContractField $Admission 'qualification_authority' $Context
    $decisions = Get-ExactContractField $Admission 'owner_decisions' $Context
    if ($role -isnot [string] -or $role -cne $ExpectedRole -or
        $ending -isnot [string] -or $ending -cne 'heist' -or
        $seed -isnot [string] -or $seed -cne $ExpectedSeed -or
        $repeat -isnot [int32] -or $repeat -cne $ExpectedRepeat -or
        $routePlan -isnot [string] -or $routePlan -cne 'count' -or
        $scenario -isnot [string] -or $scenario -cne 'grand_casino_audit_night' -or
        $scenarioAuthority -isnot [string] -or $scenarioAuthority -cne 'natural_fresh_profile_first_arrival_preflight' -or
        $scenarioAllowed -isnot [bool] -or $scenarioAllowed -or
        $planBAllowed -isnot [bool] -or $planBAllowed -or
        $isolated -isnot [bool] -or -not $isolated -or
        $qualifying -isnot [bool] -or $qualifying -or
        $authority -isnot [string] -or $authority -cne $expectedAuthority -or
        $decisions -isnot [Array] -or $decisions.Count -cne 2 -or
        $decisions[0] -isnot [string] -or $decisions[0] -cne 'Q-013A' -or
        $decisions[1] -isnot [string] -or $decisions[1] -cne 'Q-017A') {
        throw "$Context lost its exact schema or values."
    }
}


function Assert-ExactAdmissionReceipt {
    param(
        [AllowNull()]$Receipt,
        [Parameter(Mandatory = $true)][string]$ExpectedRole,
        [Parameter(Mandatory = $true)][string]$ExpectedSeed,
        [Parameter(Mandatory = $true)][string]$Context
    )
    Assert-ExactContractObjectKeys -Value $Receipt -ExpectedKeys @(
        'evidence_role', 'ending', 'seed', 'route_plan', 'selected_scenario', 'cycle_id',
        'run_seed', 'stream_seed', 'none_roll', 'total_weight', 'weighted_roll',
        'natural_first_arrival', 'scenario_injection_used', 'plan_b_used'
    ) -Context $Context
    $role = Get-ExactContractField $Receipt 'evidence_role' $Context
    $ending = Get-ExactContractField $Receipt 'ending' $Context
    $seed = Get-ExactContractField $Receipt 'seed' $Context
    $routePlan = Get-ExactContractField $Receipt 'route_plan' $Context
    $scenario = Get-ExactContractField $Receipt 'selected_scenario' $Context
    $cycle = Get-ExactContractField $Receipt 'cycle_id' $Context
    $runSeed = Get-ExactContractField $Receipt 'run_seed' $Context
    $streamSeed = Get-ExactContractField $Receipt 'stream_seed' $Context
    $noneRoll = Get-ExactContractField $Receipt 'none_roll' $Context
    $totalWeight = Get-ExactContractField $Receipt 'total_weight' $Context
    $weightedRoll = Get-ExactContractField $Receipt 'weighted_roll' $Context
    $natural = Get-ExactContractField $Receipt 'natural_first_arrival' $Context
    $scenarioUsed = Get-ExactContractField $Receipt 'scenario_injection_used' $Context
    $planBUsed = Get-ExactContractField $Receipt 'plan_b_used' $Context
    $expectedRunSeed = if ($ExpectedRole -ceq 'fresh-interactive') { [int64]1262406216 } else { [int64]919325714 }
    $expectedStreamSeed = if ($ExpectedRole -ceq 'fresh-interactive') { [int64]501255064 } else { [int64]1392077385 }
    $expectedNoneRoll = if ($ExpectedRole -ceq 'fresh-interactive') { [int32]96 } else { [int32]59 }
    $expectedWeightedRoll = if ($ExpectedRole -ceq 'fresh-interactive') { [int32]22402 } else { [int32]24088 }
    if ($role -isnot [string] -or $role -cne $ExpectedRole -or
        $ending -isnot [string] -or $ending -cne 'heist' -or
        $seed -isnot [string] -or $seed -cne $ExpectedSeed -or
        $routePlan -isnot [string] -or $routePlan -cne 'count' -or
        $scenario -isnot [string] -or $scenario -cne 'grand_casino_audit_night' -or
        $cycle -isnot [string] -or $cycle -cne 'day:0' -or
        $runSeed -isnot [int64] -or $runSeed -cne $expectedRunSeed -or
        $streamSeed -isnot [int64] -or $streamSeed -cne $expectedStreamSeed -or
        $noneRoll -isnot [int32] -or $noneRoll -cne $expectedNoneRoll -or
        $totalWeight -isnot [int32] -or $totalWeight -cne 26000 -or
        $weightedRoll -isnot [int32] -or $weightedRoll -cne $expectedWeightedRoll -or
        $natural -isnot [bool] -or -not $natural -or
        $scenarioUsed -isnot [bool] -or $scenarioUsed -or
        $planBUsed -isnot [bool] -or $planBUsed) {
        throw "$Context lost its exact schema or values."
    }
}


function Test-Throws {
    param([Parameter(Mandatory = $true)][scriptblock]$Action)
    try {
        & $Action
        return $false
    }
    catch {
        return $true
    }
}


function Invoke-PreflightReport {
    param([Parameter(Mandatory = $true)][string]$Seed)
    $safeSeed = $Seed -replace '[^A-Za-z0-9_-]', '_'
    $path = Join-Path $Worktree ".tmp\rw06_2\q017_contract\$safeSeed.json"
    $lines = @(& $PreflightPath -SeedText $Seed -ReportPath $path)
    if ($lines.Count -ne 1) {
        throw "Preflight for '$Seed' returned $($lines.Count) records instead of one."
    }
    return ([string]$lines[0] | ConvertFrom-Json)
}


function Get-ExactOuterAdmissionFunctionSource {
    param([Parameter(Mandatory = $true)][string]$Path)
    $tokens = $null
    $errors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors)
    if ($errors.Count -ne 0) {
        throw "Could not parse fixed launcher for exact admission-function extraction: $($errors[0].Message)"
    }
    $allFunctions = @($ast.FindAll({
        param($node)
        return $node -is [Management.Automation.Language.FunctionDefinitionAst]
    }, $true))
    $definitions = [Collections.Generic.List[string]]::new()
    foreach ($name in @('Get-ExactValue', 'Get-ExactValueNoEnumerate', 'Test-ExactStringArray', 'Assert-FixedReplayAdmission')) {
        $matches = @($allFunctions | Where-Object { $_.Name -ceq $name })
        if ($matches.Count -ne 1) {
            throw "Fixed launcher must contain exactly one '$name' function; observed $($matches.Count)."
        }
        $definitions.Add([string]$matches[0].Extent.Text)
    }
    return ($definitions -join "`r`n`r`n")
}


function Get-AstContainingFunctionName {
    param([Parameter(Mandatory = $true)][Management.Automation.Language.Ast]$Node)
    $ancestor = $Node.Parent
    while ($null -ne $ancestor) {
        if ($ancestor -is [Management.Automation.Language.FunctionDefinitionAst]) {
            return [string]$ancestor.Name
        }
        $ancestor = $ancestor.Parent
    }
    return ''
}


function Invoke-CustodyOrderingSourceMutation {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)]
        [ValidateSet('missing_pre', 'missing_post', 'pre_after_launch', 'post_before_launch')]
        [string]$Mode
    )
    $tokens = $null
    $errors = $null
    $ast = [Management.Automation.Language.Parser]::ParseInput(
        $Source,
        [ref]$tokens,
        [ref]$errors
    )
    if ($errors.Count -ne 0) {
        throw "Cannot construct custody-ordering hostile '$Mode' from source with parser errors."
    }
    $custodyCalls = @($ast.FindAll({
        param($node)
        return $node -is [Management.Automation.Language.CommandAst] -and
            $node.GetCommandName() -ceq 'Assert-SourceCustody' -and
            (Get-AstContainingFunctionName -Node $node) -ceq 'Invoke-OneFixedRun'
    }, $true) | Sort-Object { $_.Extent.StartOffset })
    $startCalls = @($ast.FindAll({
        param($node)
        if ($node -isnot [Management.Automation.Language.CommandAst]) { return $false }
        $commandName = $node.GetCommandName()
        return ($commandName -ceq 'Start-Process' -or
            $commandName -cmatch '(?:^|\\)Start-Process$') -and
            (Get-AstContainingFunctionName -Node $node) -ceq 'Invoke-OneFixedRun'
    }, $true))
    if ($custodyCalls.Count -cne 2 -or $startCalls.Count -cne 1) {
        throw "Cannot construct custody-ordering hostile '$Mode': expected two custody calls and one replay launch."
    }
    $edits = [Collections.Generic.List[object]]::new()
    switch ($Mode) {
        'missing_pre' {
            $edits.Add([pscustomobject]@{
                start = [int]$custodyCalls[0].Extent.StartOffset
                length = [int]($custodyCalls[0].Extent.EndOffset - $custodyCalls[0].Extent.StartOffset)
                replacement = ''
            })
        }
        'missing_post' {
            $edits.Add([pscustomobject]@{
                start = [int]$custodyCalls[1].Extent.StartOffset
                length = [int]($custodyCalls[1].Extent.EndOffset - $custodyCalls[1].Extent.StartOffset)
                replacement = ''
            })
        }
        'pre_after_launch' {
            $edits.Add([pscustomobject]@{
                start = [int]$custodyCalls[0].Extent.StartOffset
                length = [int]($custodyCalls[0].Extent.EndOffset - $custodyCalls[0].Extent.StartOffset)
                replacement = ''
            })
            $edits.Add([pscustomobject]@{
                start = [int]$startCalls[0].Extent.EndOffset
                length = [int]0
                replacement = "`n        Assert-SourceCustody"
            })
        }
        'post_before_launch' {
            $edits.Add([pscustomobject]@{
                start = [int]$custodyCalls[1].Extent.StartOffset
                length = [int]($custodyCalls[1].Extent.EndOffset - $custodyCalls[1].Extent.StartOffset)
                replacement = ''
            })
            $edits.Add([pscustomobject]@{
                start = [int]$startCalls[0].Extent.StartOffset
                length = [int]0
                replacement = "Assert-SourceCustody`n        "
            })
        }
    }
    foreach ($edit in @($edits | Sort-Object { $_.start } -Descending)) {
        $Source = $Source.Remove([int]$edit.start, [int]$edit.length).Insert(
            [int]$edit.start,
            [string]$edit.replacement
        )
    }
    return $Source
}


function Test-Q017SourceShape {
    param(
        [Parameter(Mandatory = $true)][string]$AdmissionSource,
        [Parameter(Mandatory = $true)][string]$PreflightSource,
        [Parameter(Mandatory = $true)][string]$RunnerSource,
        [Parameter(Mandatory = $true)][string]$FixedLauncherSource
    )
    foreach ($token in @(
        "heist = 'RW06-HEIST-AUDIT-0002'",
        "heist = 'RW06-HEIST-AUDIT-0000'",
        "if (`$EvidenceRole -ceq 'fresh-interactive')",
        "if (`$Ending -cne 'heist')",
        "if (`$Repeat -ne 1)",
        'requires the explicit separately preflighted seed',
        "route_plan = 'count'",
        "scenario_injection_allowed = `$false",
        "plan_b_allowed = `$false",
        "release_qualifying = `$false",
        'Assert-Rw062NoScenarioAuthorityFields -InputObject $Report',
        'Test-Rw062IntegralValue',
        "`$role = Get-Rw062AdmissionValueNoEnumerate `$Admission @('evidence_role') `$null",
        "`$ending = Get-Rw062AdmissionValueNoEnumerate `$Admission @('ending') `$null",
        "`$seed = Get-Rw062AdmissionValueNoEnumerate `$Admission @('seed') `$null",
        "`$repeat = Get-Rw062AdmissionValueNoEnumerate `$Admission @('repeat') `$null",
        "`$routePlan = Get-Rw062AdmissionValueNoEnumerate `$Admission @('route_plan') `$null",
        "`$expectedInitialScenario = Get-Rw062AdmissionValueNoEnumerate `$Admission @('expected_initial_scenario') `$null",
        "`$scenarioAuthority = Get-Rw062AdmissionValueNoEnumerate `$Admission @('scenario_authority') `$null",
        "`$scenarioInjectionAllowed = Get-Rw062AdmissionValueNoEnumerate `$Admission @('scenario_injection_allowed') `$null",
        "`$planBAllowed = Get-Rw062AdmissionValueNoEnumerate `$Admission @('plan_b_allowed') `$null",
        "`$requiresIsolatedProfile = Get-Rw062AdmissionValueNoEnumerate `$Admission @('requires_isolated_profile') `$null",
        "`$releaseQualifying = Get-Rw062AdmissionValueNoEnumerate `$Admission @('release_qualifying') `$null",
        "`$qualificationAuthority = Get-Rw062AdmissionValueNoEnumerate `$Admission @('qualification_authority') `$null",
        "@('Q-013A', 'Q-017A')"
    )) {
        if ($AdmissionSource.IndexOf($token, [StringComparison]::Ordinal) -lt 0) { return $false }
    }
    foreach ($token in @(
        "'RW06-HEIST-AUDIT-0000'",
        'run_seed -ne 1262406216',
        'stream_seed -ne 501255064',
        'none_roll -ne 96',
        'total_weight -ne 26000',
        'weighted_roll -ne 22402',
        "selected_scenario -cne 'grand_casino_audit_night'",
        "owner_decisions = @('Q-013A', 'Q-017A')"
    )) {
        if ($PreflightSource.IndexOf($token, [StringComparison]::Ordinal) -lt 0) { return $false }
    }
    $roleNormalization = '$EvidenceRole = $EvidenceRole.ToLowerInvariant()'
    $resolveCall = '$script:ReplayAdmission = Resolve-Rw062ReplayAdmission'
    $roleIndex = $RunnerSource.IndexOf($roleNormalization, [StringComparison]::Ordinal)
    $resolveIndex = $RunnerSource.IndexOf($resolveCall, [StringComparison]::Ordinal)
    if ($roleIndex -lt 0 -or $resolveIndex -le $roleIndex -or
        [regex]::Matches($RunnerSource, [regex]::Escape($roleNormalization)).Count -ne 1 -or
        [regex]::Matches($RunnerSource, '(?m)^\s*requested_evidence_role\s*=\s*\$EvidenceRole\s*$').Count -ne 2 -or
        [regex]::Matches($RunnerSource, '(?m)^\s*replay_admission\s*=\s*\$script:ReplayAdmission\s*$').Count -ne 2 -or
        [regex]::Matches($RunnerSource, '(?m)^\s*heist_preflight_admission\s*=\s*\$script:HeistPreflightAdmissionReceipt\s*$').Count -ne 2 -or
        $RunnerSource.IndexOf('Assert-Rw062HeistPreflightAdmission', [StringComparison]::Ordinal) -lt 0) {
        return $false
    }
    $route = [regex]::Match($RunnerSource, '(?ms)^function\s+Invoke-SelectedEndingRoute\s*\{.*?(?=^function |\z)').Value
    if ([string]::IsNullOrWhiteSpace($route) -or
        $route.IndexOf('switch ($Ending)', [StringComparison]::Ordinal) -lt 0 -or
        $route.IndexOf("'heist' { Invoke-HeistEndingRoute }", [StringComparison]::Ordinal) -lt 0 -or
        $route -match 'EvidenceRole|fresh-interactive|plan.?b|whale') {
        return $false
    }
    $heistRoute = [regex]::Match($RunnerSource, '(?ms)^function\s+Invoke-HeistEndingRoute\s*\{.*?(?=^function |\z)').Value
    if ([string]::IsNullOrWhiteSpace($heistRoute) -or
        $heistRoute -match '(?i)EvidenceRole|fresh-interactive|plan.?b|whale|\$Seed|\$script:ReplayAdmission') {
        return $false
    }
    $heistRouteTokens = $null
    $heistRouteErrors = $null
    $heistRouteAst = [Management.Automation.Language.Parser]::ParseInput(
        $heistRoute,
        [ref]$heistRouteTokens,
        [ref]$heistRouteErrors
    )
    if ($heistRouteErrors.Count -ne 0) { return $false }
    $allowedHeistRouteVariables = @('choiceId', 'decisions', 'null', 'round')
    $heistRouteVariables = @($heistRouteAst.FindAll({
        param($node)
        return $node -is [Management.Automation.Language.VariableExpressionAst]
    }, $true) | ForEach-Object { [string]$_.VariablePath.UserPath } | Sort-Object -Unique)
    foreach ($variableName in $heistRouteVariables) {
        if ($variableName -cnotin $allowedHeistRouteVariables) { return $false }
    }
    $expectedHeistRouteCommands = @(
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
    $actualHeistRouteCommands = @($heistRouteAst.FindAll({
        param($node)
        return $node -is [Management.Automation.Language.CommandAst]
    }, $true) | ForEach-Object { $_.GetCommandName() })
    if ($actualHeistRouteCommands.Count -cne $expectedHeistRouteCommands.Count) { return $false }
    for ($index = 0; $index -lt $expectedHeistRouteCommands.Count; $index++) {
        if ($actualHeistRouteCommands[$index] -cne $expectedHeistRouteCommands[$index]) { return $false }
    }
    foreach ($token in @(
        'function Get-ValidatedReplayToolPath {',
        "`$expectedRepositoryPath = 'tools/rw06_2_ending_replay.ps1'",
        "[IO.Path]::Combine(`$PSScriptRoot, 'rw06_2_ending_replay.ps1')",
        '$id -ceq "repository:$expectedRepositoryPath"',
        'if ($rows.Count -ne 1)',
        '$rawBlob -cne $expectedBlob',
        'return $expectedReplayPath',
        "'-File', (Get-ValidatedReplayToolPath),",
        '$null = Get-ValidatedReplayToolPath',
        "'-EvidenceRole', 'fixed-repeat'",
        '$summaryEvidenceRole -isnot [string]',
        "`$summaryEvidenceRole -cne 'fixed-repeat'",
        'Assert-FixedReplayAdmission -Admission $summaryAdmission',
        'Assert-FixedReplayAdmission -Admission $runAdmission',
        'Assert-Rw062HeistPreflightAdmission',
        "evidence_role = 'fixed-repeat'",
        'Assert-FixedRunProofShape -Proof $proof -ExpectedRunIndex $RunIndex -Label "Run $RunIndex proof"',
        "Assert-CanonicalFixedProofShape -Proof `$CanonicalProof -Label 'Qualification canonical proof'",
        "fresh_interactive_authorized = `$false",
        "'ANSWERED_SEPARATE_FRESH_INTERACTIVE_SCOPE'"
    )) {
        if ($FixedLauncherSource.IndexOf($token, [StringComparison]::Ordinal) -lt 0) { return $false }
    }
    if ([regex]::Matches($FixedLauncherSource, '(?m)''\-File''\s*,').Count -cne 1 -or
        [regex]::Matches($FixedLauncherSource, '(?m)''\-File''\s*,\s*\(Get-ValidatedReplayToolPath\)\s*,').Count -cne 1 -or
        [regex]::Matches($FixedLauncherSource, '(?m)^\s*\$null\s*=\s*Get-ValidatedReplayToolPath\s*$').Count -cne 1 -or
        $FixedLauncherSource.IndexOf('$ReplayTool', [StringComparison]::Ordinal) -ge 0 -or
        $FixedLauncherSource.IndexOf("'-File', `$EvidenceAdmissionTool,", [StringComparison]::Ordinal) -ge 0) {
        return $false
    }
    $fixedTokens = $null
    $fixedErrors = $null
    $fixedAst = [Management.Automation.Language.Parser]::ParseInput(
        $FixedLauncherSource,
        [ref]$fixedTokens,
        [ref]$fixedErrors
    )
    if ($fixedErrors.Count -ne 0) { return $false }
    $replayToolFunctions = @($fixedAst.FindAll({
        param($node)
        return $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
            $node.Name -ceq 'Get-ValidatedReplayToolPath'
    }, $true))
    if ($replayToolFunctions.Count -cne 1) {
        return $false
    }
    $replayFunctionSource = $replayToolFunctions[0].Extent.Text
    foreach ($token in @(
        "`$expectedRepositoryPath = 'tools/rw06_2_ending_replay.ps1'",
        "[IO.Path]::Combine(`$PSScriptRoot, 'rw06_2_ending_replay.ps1')",
        '$id -ceq "repository:$expectedRepositoryPath"',
        'if ($rows.Count -ne 1)',
        'Assert-SourceCustodyRowSchema -Row $row -Phase pre -Representation in_memory',
        '$scope -cne ''repository_tracked_production_tree''',
        '$repositoryPath -cne $expectedRepositoryPath',
        '$absolutePath.Equals($expectedReplayPath, [StringComparison]::OrdinalIgnoreCase)',
        '$expectedBlob -cnotmatch ''^[a-f0-9]{40}$''',
        '$rawBlob -cne $expectedBlob',
        'return $expectedReplayPath'
    )) {
        if ($replayFunctionSource.IndexOf($token, [StringComparison]::Ordinal) -lt 0) { return $false }
    }
    $replayToolCalls = @($fixedAst.FindAll({
        param($node)
        return $node -is [Management.Automation.Language.CommandAst] -and
            $node.GetCommandName() -ceq 'Get-ValidatedReplayToolPath'
    }, $true))
    if ($replayToolCalls.Count -cne 2) { return $false }
    $topLevelReplayCalls = @($replayToolCalls | Where-Object {
        (Get-AstContainingFunctionName -Node $_) -ceq ''
    })
    $invokeReplayCalls = @($replayToolCalls | Where-Object {
        (Get-AstContainingFunctionName -Node $_) -ceq 'Invoke-OneFixedRun'
    })
    $sourceCustodyCalls = @($fixedAst.FindAll({
        param($node)
        return $node -is [Management.Automation.Language.CommandAst] -and
            $node.GetCommandName() -ceq 'New-SourceCustody'
    }, $true) | Where-Object { (Get-AstContainingFunctionName -Node $_) -ceq '' })
    $runLoops = @($fixedAst.FindAll({
        param($node)
        return $node -is [Management.Automation.Language.ForEachStatementAst] -and
            $node.Extent.Text -cmatch '^foreach\s*\(\$runIndex\s+in\s+1\.\.2\)'
    }, $true) | Where-Object { (Get-AstContainingFunctionName -Node $_) -ceq '' })
    if ($topLevelReplayCalls.Count -cne 1 -or $invokeReplayCalls.Count -cne 1 -or
        $sourceCustodyCalls.Count -cne 1 -or $runLoops.Count -cne 1 -or
        $topLevelReplayCalls[0].Extent.StartOffset -le $sourceCustodyCalls[0].Extent.StartOffset -or
        $runLoops[0].Extent.StartOffset -le $topLevelReplayCalls[0].Extent.StartOffset) {
        return $false
    }
    $startProcessCalls = @($fixedAst.FindAll({
        param($node)
        if ($node -isnot [Management.Automation.Language.CommandAst]) { return $false }
        $commandName = $node.GetCommandName()
        return $commandName -ceq 'Start-Process' -or
            $commandName -cmatch '(?:^|\\)Start-Process$'
    }, $true))
    $invokeCustodyCalls = @($fixedAst.FindAll({
        param($node)
        return $node -is [Management.Automation.Language.CommandAst] -and
            $node.GetCommandName() -ceq 'Assert-SourceCustody' -and
            (Get-AstContainingFunctionName -Node $node) -ceq 'Invoke-OneFixedRun'
    }, $true))
    if ($startProcessCalls.Count -cne 1 -or
        $startProcessCalls[0].GetCommandName() -cne 'Microsoft.PowerShell.Management\Start-Process' -or
        (Get-AstContainingFunctionName -Node $startProcessCalls[0]) -cne 'Invoke-OneFixedRun' -or
        $invokeCustodyCalls.Count -cne 2 -or
        $startProcessCalls[0].Extent.StartOffset -le $invokeCustodyCalls[0].Extent.StartOffset -or
        $invokeCustodyCalls[1].Extent.StartOffset -le $startProcessCalls[0].Extent.StartOffset) {
        return $false
    }
    $startElements = @($startProcessCalls[0].CommandElements)
    if ($startElements.Count -cne 12 -or
        $startElements[0].Extent.Text -cne 'Microsoft.PowerShell.Management\Start-Process' -or
        $startElements[1] -isnot [Management.Automation.Language.CommandParameterAst] -or
        $startElements[1].ParameterName -cne 'FilePath' -or
        $startElements[2].Extent.Text -cne '$powerShellExe' -or
        $startElements[3] -isnot [Management.Automation.Language.CommandParameterAst] -or
        $startElements[3].ParameterName -cne 'ArgumentList' -or
        $startElements[4] -isnot [Management.Automation.Language.ArrayExpressionAst] -or
        $startElements[5].Extent.Text -cne '-RedirectStandardOutput' -or
        $startElements[6].Extent.Text -cne '$stdoutPath' -or
        $startElements[7].Extent.Text -cne '-RedirectStandardError' -or
        $startElements[8].Extent.Text -cne '$stderrPath' -or
        $startElements[9].Extent.Text -cne '-WindowStyle' -or
        $startElements[10].Extent.Text -cne 'Hidden' -or
        $startElements[11].Extent.Text -cne '-PassThru') {
        return $false
    }
    $argumentStatements = @($startElements[4].SubExpression.Statements)
    if ($argumentStatements.Count -cne 1 -or
        $argumentStatements[0] -isnot [Management.Automation.Language.PipelineAst] -or
        $argumentStatements[0].PipelineElements.Count -cne 1 -or
        $argumentStatements[0].PipelineElements[0] -isnot [Management.Automation.Language.CommandExpressionAst] -or
        $argumentStatements[0].PipelineElements[0].Expression -isnot [Management.Automation.Language.ArrayLiteralAst]) {
        return $false
    }
    $argumentElements = @($argumentStatements[0].PipelineElements[0].Expression.Elements)
    $expectedArgumentElements = @(
        "'-NoProfile'", "'-NonInteractive'", "'-ExecutionPolicy'", "'Bypass'",
        "'-File'", '(Get-ValidatedReplayToolPath)', "'-Ending'", '$Ending',
        "'-EvidenceRole'", "'fixed-repeat'", "'-Seed'", '$Seed', "'-Repeat'", "'1'",
        "'-TimeoutSeconds'", '[string]$CommandTimeoutSeconds', "'-EvidenceRoot'", '$replayEvidenceRoot'
    )
    if ($argumentElements.Count -cne $expectedArgumentElements.Count) { return $false }
    for ($index = 0; $index -lt $expectedArgumentElements.Count; $index++) {
        if ($argumentElements[$index].Extent.Text.Trim() -cne $expectedArgumentElements[$index]) { return $false }
    }
    if (
        [regex]::IsMatch(
            $FixedLauncherSource,
            '(?i)\b(?:Set|New|Remove|Clear)-Item\b[^\r\n]*\bfunction:[^\r\n]*\bGet-ValidatedReplayToolPath\b|\b(?:si|ni|ri|cli)\b[^\r\n]*\bfunction:[^\r\n]*\bGet-ValidatedReplayToolPath\b|\b(?:Set|New|Remove)-Alias\b[^\r\n]*\bGet-ValidatedReplayToolPath\b|\b(?:sal|nal|ral)\b[^\r\n]*\bGet-ValidatedReplayToolPath\b|\b(?:ExecutionContext|SessionState|PSVariable|Invoke-Expression|iex)\b'
        )) {
        return $false
    }
    $paramBlock = [regex]::Match($FixedLauncherSource, '(?ms)^\[CmdletBinding\(\)\]\s*param\((?<body>.*?)\)\s*Set-StrictMode').Groups['body'].Value
    if ([string]::IsNullOrWhiteSpace($paramBlock) -or
        $paramBlock -match '(?i)EvidenceRole|FreshSeed|Interactive|\bFresh\b') {
        return $false
    }
    return $true
}


foreach ($path in @($AdmissionPath, $PreflightPath, $RunnerPath, $FixedLauncherPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        Add-Failure "Required Q-017 admission source is missing: $path"
    }
}

$fixedReport = $null
$freshReport = $null
if ($failures.Count -eq 0) {
    foreach ($path in @($AdmissionPath, $PreflightPath, $RunnerPath, $FixedLauncherPath)) {
        $tokens = $null
        $errors = $null
        [void][Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors)
        if ($errors.Count -ne 0) {
            Add-Failure "PowerShell parse failed for $path`: $($errors[0].Message)"
        }
    }
}

if ($failures.Count -eq 0) {
    . $AdmissionPath
    try {
        $fixedReport = Invoke-PreflightReport -Seed 'RW06-HEIST-AUDIT-0002'
        $freshReport = Invoke-PreflightReport -Seed 'RW06-HEIST-AUDIT-0000'
    }
    catch {
        Add-Failure "Could not obtain exact engine-free Q-017 preflight reports: $($_.Exception.Message)"
    }
}

if ($failures.Count -eq 0) {
    $resolverValids = @(
        [pscustomobject]@{ name = 'fixed default'; role = 'fixed-repeat'; seed = ''; repeat = 2; expected_seed = 'RW06-HEIST-AUDIT-0002'; report = $fixedReport },
        [pscustomobject]@{ name = 'fixed explicit'; role = 'fixed-repeat'; seed = 'RW06-HEIST-AUDIT-0002'; repeat = 1; expected_seed = 'RW06-HEIST-AUDIT-0002'; report = $fixedReport },
        [pscustomobject]@{ name = 'fresh explicit'; role = 'fresh-interactive'; seed = 'RW06-HEIST-AUDIT-0000'; repeat = 1; expected_seed = 'RW06-HEIST-AUDIT-0000'; report = $freshReport }
    )
    foreach ($fixture in $resolverValids) {
        try {
            $admission = Resolve-Rw062ReplayAdmission -Ending heist -EvidenceRole $fixture.role -Seed $fixture.seed -Repeat $fixture.repeat
            Assert-ExactAdmissionObject `
                -Admission $admission `
                -ExpectedRole $fixture.role `
                -ExpectedSeed $fixture.expected_seed `
                -ExpectedRepeat $fixture.repeat `
                -Context "Valid resolver fixture '$($fixture.name)' admission"
            $null = Assert-Rw062HeistPreflightAdmission -Admission $admission -Report $fixture.report
            $resolverValidFixtures++
        }
        catch {
            Add-Failure "Valid resolver fixture '$($fixture.name)' failed: $($_.Exception.Message)"
        }
    }

    $resolverHostiles = @(
        [pscustomobject]@{ name = 'unknown role'; ending = 'heist'; role = 'fresh'; seed = 'RW06-HEIST-AUDIT-0000'; repeat = 1 },
        [pscustomobject]@{ name = 'case-drifted role'; ending = 'heist'; role = 'Fresh-Interactive'; seed = 'RW06-HEIST-AUDIT-0000'; repeat = 1 },
        [pscustomobject]@{ name = 'blank fresh seed'; ending = 'heist'; role = 'fresh-interactive'; seed = ''; repeat = 1 },
        [pscustomobject]@{ name = 'fixed seed in fresh role'; ending = 'heist'; role = 'fresh-interactive'; seed = 'RW06-HEIST-AUDIT-0002'; repeat = 1 },
        [pscustomobject]@{ name = 'unapproved natural Audit seed'; ending = 'heist'; role = 'fresh-interactive'; seed = 'RW06-HEIST-AUDIT-0007'; repeat = 1 },
        [pscustomobject]@{ name = 'historical non-Audit seed'; ending = 'heist'; role = 'fresh-interactive'; seed = 'RW06-HEIST-AUDIT-0013'; repeat = 1 },
        [pscustomobject]@{ name = 'fresh repeat two'; ending = 'heist'; role = 'fresh-interactive'; seed = 'RW06-HEIST-AUDIT-0000'; repeat = 2 },
        [pscustomobject]@{ name = 'fresh clean'; ending = 'clean'; role = 'fresh-interactive'; seed = 'RW06-HEIST-AUDIT-0000'; repeat = 1 },
        [pscustomobject]@{ name = 'fresh cheat'; ending = 'cheat'; role = 'fresh-interactive'; seed = 'RW06-HEIST-AUDIT-0000'; repeat = 1 },
        [pscustomobject]@{ name = 'fresh seed in fixed role'; ending = 'heist'; role = 'fixed-repeat'; seed = 'RW06-HEIST-AUDIT-0000'; repeat = 1 }
    )
    foreach ($fixture in $resolverHostiles) {
        $resolverHostileFixtures++
        $copy = $fixture
        if (-not (Test-Throws {
            $null = Resolve-Rw062ReplayAdmission -Ending $copy.ending -EvidenceRole $copy.role -Seed $copy.seed -Repeat $copy.repeat
        })) {
            Add-Failure "Hostile resolver fixture '$($fixture.name)' did not fail closed."
        }
    }

    foreach ($fixture in @(
        [pscustomobject]@{ role = 'fixed-repeat'; seed = 'RW06-HEIST-AUDIT-0002'; repeat = 2; report = $fixedReport },
        [pscustomobject]@{ role = 'fresh-interactive'; seed = 'RW06-HEIST-AUDIT-0000'; repeat = 1; report = $freshReport }
    )) {
        try {
            $admission = Resolve-Rw062ReplayAdmission -Ending heist -EvidenceRole $fixture.role -Seed $fixture.seed -Repeat $fixture.repeat
            Assert-ExactAdmissionObject `
                -Admission $admission `
                -ExpectedRole $fixture.role `
                -ExpectedSeed $fixture.seed `
                -ExpectedRepeat $fixture.repeat `
                -Context "Valid preflight fixture '$($fixture.role)' admission"
            $receipt = Assert-Rw062HeistPreflightAdmission -Admission $admission -Report $fixture.report
            Assert-ExactAdmissionReceipt `
                -Receipt $receipt `
                -ExpectedRole $fixture.role `
                -ExpectedSeed $fixture.seed `
                -Context "Valid preflight fixture '$($fixture.role)' receipt"
            $preflightValidFixtures++
        }
        catch {
            Add-Failure "Valid preflight admission '$($fixture.role)' failed: $($_.Exception.Message)"
        }
    }

    $freshAdmission = Resolve-Rw062ReplayAdmission -Ending heist -EvidenceRole fresh-interactive -Seed 'RW06-HEIST-AUDIT-0000' -Repeat 1
    $admissionMutations = @(
        [pscustomobject]@{ name = 'role'; mutate = { param($a) $a.evidence_role = 'fixed-repeat' } },
        [pscustomobject]@{ name = 'ending'; mutate = { param($a) $a.ending = 'clean' } },
        [pscustomobject]@{ name = 'seed'; mutate = { param($a) $a.seed = 'RW06-HEIST-AUDIT-0002' } },
        [pscustomobject]@{ name = 'repeat'; mutate = { param($a) $a.repeat = 2 } },
        [pscustomobject]@{ name = 'route plan'; mutate = { param($a) $a.route_plan = 'whale' } },
        [pscustomobject]@{ name = 'expected scenario'; mutate = { param($a) $a.expected_initial_scenario = 'Grand_Casino_Audit_Night' } },
        [pscustomobject]@{ name = 'scenario authority'; mutate = { param($a) $a.scenario_authority = 'caller_override' } },
        [pscustomobject]@{ name = 'scenario permission'; mutate = { param($a) $a.scenario_injection_allowed = $true } },
        [pscustomobject]@{ name = 'Plan B permission'; mutate = { param($a) $a.plan_b_allowed = $true } },
        [pscustomobject]@{ name = 'profile isolation'; mutate = { param($a) $a.requires_isolated_profile = $false } },
        [pscustomobject]@{ name = 'direct qualification'; mutate = { param($a) $a.release_qualifying = $true } },
        [pscustomobject]@{ name = 'qualification authority'; mutate = { param($a) $a.qualification_authority = 'direct' } },
        [pscustomobject]@{ name = 'owner decision'; mutate = { param($a) $a.owner_decisions = @('Q-013A') } },
        [pscustomobject]@{ name = 'owner decision order'; mutate = { param($a) $a.owner_decisions = @('Q-017A', 'Q-013A') } },
        [pscustomobject]@{ name = 'role one-element object array'; mutate = { param($a) $a.evidence_role = [object[]]@('fresh-interactive') } },
        [pscustomobject]@{ name = 'ending one-element object array'; mutate = { param($a) $a.ending = [object[]]@('heist') } },
        [pscustomobject]@{ name = 'seed one-element object array'; mutate = { param($a) $a.seed = [object[]]@('RW06-HEIST-AUDIT-0000') } },
        [pscustomobject]@{ name = 'route plan one-element object array'; mutate = { param($a) $a.route_plan = [object[]]@('count') } },
        [pscustomobject]@{ name = 'expected scenario one-element object array'; mutate = { param($a) $a.expected_initial_scenario = [object[]]@('grand_casino_audit_night') } },
        [pscustomobject]@{ name = 'scenario authority one-element object array'; mutate = { param($a) $a.scenario_authority = [object[]]@('natural_fresh_profile_first_arrival_preflight') } },
        [pscustomobject]@{ name = 'qualification authority one-element object array'; mutate = { param($a) $a.qualification_authority = [object[]]@('post_run_interactive_review_only') } },
        [pscustomobject]@{ name = 'repeat one-element object array'; mutate = { param($a) $a.repeat = [object[]]@(1) } },
        [pscustomobject]@{ name = 'scenario permission one-element object array'; mutate = { param($a) $a.scenario_injection_allowed = [object[]]@($false) } },
        [pscustomobject]@{ name = 'Plan B permission one-element object array'; mutate = { param($a) $a.plan_b_allowed = [object[]]@($false) } },
        [pscustomobject]@{ name = 'profile isolation one-element object array'; mutate = { param($a) $a.requires_isolated_profile = [object[]]@($true) } },
        [pscustomobject]@{ name = 'release qualification one-element object array'; mutate = { param($a) $a.release_qualifying = [object[]]@($false) } },
        [pscustomobject]@{ name = 'extra scenario pin'; mutate = { param($a) $a | Add-Member -NotePropertyName scenario_pin -NotePropertyValue 'grand_casino_audit_night' } },
        [pscustomobject]@{ name = 'extra scenario injection used'; mutate = { param($a) $a | Add-Member -NotePropertyName scenario_injection_used -NotePropertyValue $false } },
        [pscustomobject]@{ name = 'extra Plan B used'; mutate = { param($a) $a | Add-Member -NotePropertyName plan_b_used -NotePropertyValue $false } },
        [pscustomobject]@{ name = 'extra forced scenario'; mutate = { param($a) $a | Add-Member -NotePropertyName forced_scenario -NotePropertyValue '' } },
        [pscustomobject]@{ name = 'extra Whale plan'; mutate = { param($a) $a | Add-Member -NotePropertyName whale_plan -NotePropertyValue $false } }
    )
    foreach ($fixture in $admissionMutations) {
        $admissionObjectHostileFixtures++
        $hostileAdmission = ConvertTo-ContractClone $freshAdmission
        & $fixture.mutate $hostileAdmission
        if (-not (Test-Throws {
            $null = Assert-Rw062HeistPreflightAdmission -Admission $hostileAdmission -Report $freshReport
        })) {
            Add-Failure "Hostile admission-object fixture '$($fixture.name)' did not fail closed."
        }
    }
    $admissionObjectHostileFixtures++
    $admissionRootArray = [object[]]@($freshAdmission)
    if (-not (Test-Throws {
        $null = Assert-Rw062HeistPreflightAdmission -Admission $admissionRootArray -Report $freshReport
    })) {
        Add-Failure "Hostile admission-object fixture 'root one-element object array' did not fail closed."
    }
    $universalAdmissionHostiles = @(Get-UniversalContractSchemaHostiles `
        -ValidRoot $freshAdmission `
        -Prefix 'admission')
    $admissionUniversalSchemaHostileFixtures = $universalAdmissionHostiles.Count
    foreach ($fixture in $universalAdmissionHostiles) {
        $admissionObjectHostileFixtures++
        $hostileAdmission = Get-ExactContractField $fixture 'value' "Universal admission hostile '$($fixture.name)'"
        if (-not (Test-Throws {
            $null = Assert-Rw062HeistPreflightAdmission -Admission $hostileAdmission -Report $freshReport
        })) {
            Add-Failure "Universal hostile admission-object fixture '$($fixture.name)' did not fail closed."
        }
    }

    $reportMutations = @(
        [pscustomobject]@{ name = 'passed string'; mutate = { param($r) $r.passed = 'true' } },
        [pscustomobject]@{ name = 'passed false'; mutate = { param($r) $r.passed = $false } },
        [pscustomobject]@{ name = 'contract'; mutate = { param($r) $r.contract = 'hostile' } },
        [pscustomobject]@{ name = 'expected scenario'; mutate = { param($r) $r.expected_scenario = 'Grand_Casino_Audit_Night' } },
        [pscustomobject]@{ name = 'owner decisions'; mutate = { param($r) $r.owner_decisions = @('WRONG') } },
        [pscustomobject]@{ name = 'valid fixture count'; mutate = { param($r) $r.valid_fixtures = 2 } },
        [pscustomobject]@{ name = 'hostile fixture count'; mutate = { param($r) $r.hostile_fixtures = 1 } },
        [pscustomobject]@{ name = 'fresh companion selection'; mutate = { param($r) $r.fresh_interactive_selection = [pscustomobject]@{ seed_text = 'RW06-HEIST-AUDIT-0007'; selected_scenario = 'grand_casino_audit_night' } } },
        [pscustomobject]@{ name = 'serialization calibration payload'; mutate = { param($r) $r.serialization_calibration = [pscustomobject]@{ seed_text = 'RW06-HEIST-AUDIT-0000' } } },
        [pscustomobject]@{ name = 'arrival history hostile payload'; mutate = { param($r) $r.arrival_history_hostile = [pscustomobject]@{ whale_plan = $true } } },
        [pscustomobject]@{ name = 'seed'; mutate = { param($r) $r.selection.seed_text = 'rw06-heist-audit-0000' } },
        [pscustomobject]@{ name = 'challenge key'; mutate = { param($r) $r.selection.challenge_key += '-drift' } },
        [pscustomobject]@{ name = 'scenario blank'; mutate = { param($r) $r.selection.selected_scenario = '' } },
        [pscustomobject]@{ name = 'scenario convention'; mutate = { param($r) $r.selection.selected_scenario = 'grand_casino_convention_crowd' } },
        [pscustomobject]@{ name = 'scenario case'; mutate = { param($r) $r.selection.selected_scenario = 'Grand_Casino_Audit_Night' } },
        [pscustomobject]@{ name = 'cycle'; mutate = { param($r) $r.selection.cycle_id = 'day:1' } },
        [pscustomobject]@{ name = 'stream key'; mutate = { param($r) $r.selection.stream_key = 'environment_situation:grand_casino:day:1' } },
        [pscustomobject]@{ name = 'run seed value'; mutate = { param($r) $r.selection.run_seed++ } },
        [pscustomobject]@{ name = 'run seed floating type'; mutate = { param($r) $r.selection.run_seed = [double]1262406216 } },
        [pscustomobject]@{ name = 'stream seed value'; mutate = { param($r) $r.selection.stream_seed++ } },
        [pscustomobject]@{ name = 'stream seed decimal type'; mutate = { param($r) $r.selection.stream_seed = [decimal]501255064 } },
        [pscustomobject]@{ name = 'none roll value'; mutate = { param($r) $r.selection.none_roll-- } },
        [pscustomobject]@{ name = 'none roll floating type'; mutate = { param($r) $r.selection.none_roll = [double]96 } },
        [pscustomobject]@{ name = 'none percent'; mutate = { param($r) $r.selection.none_percent = 24 } },
        [pscustomobject]@{ name = 'absolute minutes'; mutate = { param($r) $r.selection.absolute_minutes = 721 } },
        [pscustomobject]@{ name = 'total weight value'; mutate = { param($r) $r.selection.total_weight-- } },
        [pscustomobject]@{ name = 'total weight floating type'; mutate = { param($r) $r.selection.total_weight = [double]26000 } },
        [pscustomobject]@{ name = 'weighted roll value'; mutate = { param($r) $r.selection.weighted_roll-- } },
        [pscustomobject]@{ name = 'weighted roll decimal type'; mutate = { param($r) $r.selection.weighted_roll = [decimal]22402 } },
        [pscustomobject]@{ name = 'arrival history'; mutate = { param($r) $r.selection.recent_scenario_ids = @('grand_casino_audit_night') } },
        [pscustomobject]@{ name = 'town multiplier type'; mutate = { param($r) $r.selection.town_multiplier = [double]1.0 } },
        [pscustomobject]@{ name = 'weighted entry count'; mutate = { param($r) $r.selection.weighted_entries = @($r.selection.weighted_entries | Select-Object -First 2) } },
        [pscustomobject]@{ name = 'weighted entry order'; mutate = { param($r) $r.selection.weighted_entries = @($r.selection.weighted_entries[1], $r.selection.weighted_entries[0], $r.selection.weighted_entries[2]) } },
        [pscustomobject]@{ name = 'weighted entry id'; mutate = { param($r) $r.selection.weighted_entries[0].id = 'grand_casino_audit_night' } },
        [pscustomobject]@{ name = 'weighted entry type'; mutate = { param($r) $r.selection.weighted_entries[0].scaled_weight = [double]8000 } },
        [pscustomobject]@{ name = 'screen'; mutate = { param($r) $r.launch_model.screen = 'RUN_CONFIG' } },
        [pscustomobject]@{ name = 'run config type'; mutate = { param($r) $r.launch_model.run_config = 'true' } },
        [pscustomobject]@{ name = 'selected challenge'; mutate = { param($r) $r.launch_model.selected_challenge = 'standard' } },
        [pscustomobject]@{ name = 'selected home'; mutate = { param($r) $r.launch_model.selected_home = 'back_alley' } },
        [pscustomobject]@{ name = 'challenge mode'; mutate = { param($r) $r.launch_model.challenge_mode = 'hostile' } },
        [pscustomobject]@{ name = 'challenge id'; mutate = { param($r) $r.launch_model.challenge_id = 'hostile' } },
        [pscustomobject]@{ name = 'modifier text'; mutate = { param($r) $r.launch_model.fresh_profile_modifier_text += ';scenario=hostile' } },
        [pscustomobject]@{ name = 'start minutes'; mutate = { param($r) $r.launch_model.start_absolute_minutes = 721 } },
        [pscustomobject]@{ name = 'content count'; mutate = { param($r) $r.launch_model.selected_content_groups = @($r.launch_model.selected_content_groups | Select-Object -First 13) } },
        [pscustomobject]@{ name = 'content order'; mutate = { param($r) $r.launch_model.selected_content_groups = @($r.launch_model.selected_content_groups[1], $r.launch_model.selected_content_groups[0]) + @($r.launch_model.selected_content_groups | Select-Object -Skip 2) } },
        [pscustomobject]@{ name = 'content type'; mutate = { param($r) $r.launch_model.selected_content_groups[0] = 7 } },
        [pscustomobject]@{ name = 'launch arrival history'; mutate = { param($r) $r.launch_model.first_arrival_recent_scenario_ids = @('grand_casino_audit_night') } },
        [pscustomobject]@{ name = 'scenario pin'; mutate = { param($r) $r.selection | Add-Member -NotePropertyName scenario_pin -NotePropertyValue 'grand_casino_audit_night' } },
        [pscustomobject]@{ name = 'scenario override'; mutate = { param($r) $r.launch_model | Add-Member -NotePropertyName Scenario_Override -NotePropertyValue 'grand_casino_audit_night' } },
        [pscustomobject]@{ name = 'injected scenario'; mutate = { param($r) $r | Add-Member -NotePropertyName injected_scenario -NotePropertyValue 'grand_casino_audit_night' } },
        [pscustomobject]@{ name = 'tutorial override'; mutate = { param($r) $r | Add-Member -NotePropertyName tutorial_overrides -NotePropertyValue @{} } },
        [pscustomobject]@{ name = 'debug scenario'; mutate = { param($r) $r | Add-Member -NotePropertyName debug_scenario -NotePropertyValue 'grand_casino_audit_night' } },
        [pscustomobject]@{ name = 'Plan B'; mutate = { param($r) $r | Add-Member -NotePropertyName plan_b -NotePropertyValue $true } },
        [pscustomobject]@{ name = 'Whale plan'; mutate = { param($r) $r | Add-Member -NotePropertyName whale_plan -NotePropertyValue $true } },
        [pscustomobject]@{ name = 'scenario injection used'; mutate = { param($r) $r | Add-Member -NotePropertyName scenario_injection_used -NotePropertyValue $false } },
        [pscustomobject]@{ name = 'scenario injection allowed'; mutate = { param($r) $r | Add-Member -NotePropertyName scenario_injection_allowed -NotePropertyValue $false } },
        [pscustomobject]@{ name = 'Plan B used'; mutate = { param($r) $r | Add-Member -NotePropertyName plan_b_used -NotePropertyValue $false } },
        [pscustomobject]@{ name = 'Plan B allowed'; mutate = { param($r) $r | Add-Member -NotePropertyName plan_b_allowed -NotePropertyValue $false } },
        [pscustomobject]@{ name = 'forced scenario'; mutate = { param($r) $r | Add-Member -NotePropertyName forced_scenario -NotePropertyValue '' } },
        [pscustomobject]@{ name = 'missing selection arrival history'; mutate = { param($r) $r.selection.PSObject.Properties.Remove('recent_scenario_ids') } },
        [pscustomobject]@{ name = 'null selection arrival history'; mutate = { param($r) $r.selection.recent_scenario_ids = $null } },
        [pscustomobject]@{ name = 'missing launch arrival history'; mutate = { param($r) $r.launch_model.PSObject.Properties.Remove('first_arrival_recent_scenario_ids') } },
        [pscustomobject]@{ name = 'null launch arrival history'; mutate = { param($r) $r.launch_model.first_arrival_recent_scenario_ids = $null } },
        [pscustomobject]@{ name = 'missing failures'; mutate = { param($r) $r.PSObject.Properties.Remove('failures') } },
        [pscustomobject]@{ name = 'null failures'; mutate = { param($r) $r.failures = $null } },
        [pscustomobject]@{ name = 'owner decisions nested array'; mutate = { param($r) $r.owner_decisions = [object[]]@(,([object[]]@('Q-013A', 'Q-017A'))) } },
        [pscustomobject]@{ name = 'selection arrival history nested array'; mutate = { param($r) $r.selection.recent_scenario_ids = [object[]]@(,([object[]]@())) } },
        [pscustomobject]@{ name = 'weighted entries nested array'; mutate = { param($r) $r.selection.weighted_entries = [object[]]@(,([object[]]@($r.selection.weighted_entries))) } },
        [pscustomobject]@{ name = 'weighted entry object array'; mutate = { param($r) $r.selection.weighted_entries[0] = [object[]]@($r.selection.weighted_entries[0]) } },
        [pscustomobject]@{ name = 'failures nested array'; mutate = { param($r) $r.failures = [object[]]@(,([object[]]@())) } },
        [pscustomobject]@{ name = 'content groups nested array'; mutate = { param($r) $r.launch_model.selected_content_groups = [object[]]@(,([object[]]@($r.launch_model.selected_content_groups))) } },
        [pscustomobject]@{ name = 'launch arrival history nested array'; mutate = { param($r) $r.launch_model.first_arrival_recent_scenario_ids = [object[]]@(,([object[]]@())) } },
        [pscustomobject]@{ name = 'fresh companion selection null array'; mutate = { param($r) $r.fresh_interactive_selection = [object[]]@($null) } },
        [pscustomobject]@{ name = 'serialization calibration null array'; mutate = { param($r) $r.serialization_calibration = [object[]]@($null) } },
        [pscustomobject]@{ name = 'arrival history hostile null array'; mutate = { param($r) $r.arrival_history_hostile = [object[]]@($null) } },
        [pscustomobject]@{ name = 'selection one-element object array'; mutate = { param($r) $r.selection = [object[]]@($r.selection) } },
        [pscustomobject]@{ name = 'launch model one-element object array'; mutate = { param($r) $r.launch_model = [object[]]@($r.launch_model) } },
        [pscustomobject]@{ name = 'contract one-element object array'; mutate = { param($r) $r.contract = [object[]]@('rw06_2_heist_seed_preflight') } },
        [pscustomobject]@{ name = 'expected scenario one-element object array'; mutate = { param($r) $r.expected_scenario = [object[]]@('grand_casino_audit_night') } },
        [pscustomobject]@{ name = 'valid fixtures one-element object array'; mutate = { param($r) $r.valid_fixtures = [object[]]@(1) } },
        [pscustomobject]@{ name = 'hostile fixtures one-element object array'; mutate = { param($r) $r.hostile_fixtures = [object[]]@(0) } },
        [pscustomobject]@{ name = 'passed one-element object array'; mutate = { param($r) $r.passed = [object[]]@($true) } },
        [pscustomobject]@{ name = 'selection seed one-element object array'; mutate = { param($r) $r.selection.seed_text = [object[]]@('RW06-HEIST-AUDIT-0000') } },
        [pscustomobject]@{ name = 'challenge key one-element object array'; mutate = { param($r) $r.selection.challenge_key = [object[]]@($r.selection.challenge_key) } },
        [pscustomobject]@{ name = 'selected scenario one-element object array'; mutate = { param($r) $r.selection.selected_scenario = [object[]]@('grand_casino_audit_night') } },
        [pscustomobject]@{ name = 'cycle one-element object array'; mutate = { param($r) $r.selection.cycle_id = [object[]]@('day:0') } },
        [pscustomobject]@{ name = 'stream key one-element object array'; mutate = { param($r) $r.selection.stream_key = [object[]]@('environment_situation:grand_casino:day:0') } },
        [pscustomobject]@{ name = 'run seed one-element object array'; mutate = { param($r) $r.selection.run_seed = [object[]]@(1262406216) } },
        [pscustomobject]@{ name = 'stream seed one-element object array'; mutate = { param($r) $r.selection.stream_seed = [object[]]@(501255064) } },
        [pscustomobject]@{ name = 'none roll one-element object array'; mutate = { param($r) $r.selection.none_roll = [object[]]@(96) } },
        [pscustomobject]@{ name = 'none percent one-element object array'; mutate = { param($r) $r.selection.none_percent = [object[]]@(25) } },
        [pscustomobject]@{ name = 'absolute minutes one-element object array'; mutate = { param($r) $r.selection.absolute_minutes = [object[]]@(720) } },
        [pscustomobject]@{ name = 'total weight one-element object array'; mutate = { param($r) $r.selection.total_weight = [object[]]@(26000) } },
        [pscustomobject]@{ name = 'weighted roll one-element object array'; mutate = { param($r) $r.selection.weighted_roll = [object[]]@(22402) } },
        [pscustomobject]@{ name = 'town multiplier one-element object array'; mutate = { param($r) $r.selection.town_multiplier = [object[]]@(1) } },
        [pscustomobject]@{ name = 'entry id one-element object array'; mutate = { param($r) $r.selection.weighted_entries[0].id = [object[]]@('grand_casino_gala_night') } },
        [pscustomobject]@{ name = 'entry repeat multiplier one-element object array'; mutate = { param($r) $r.selection.weighted_entries[0].repeat_multiplier = [object[]]@(1) } },
        [pscustomobject]@{ name = 'entry town multiplier one-element object array'; mutate = { param($r) $r.selection.weighted_entries[0].town_multiplier = [object[]]@(1) } },
        [pscustomobject]@{ name = 'entry scaled weight one-element object array'; mutate = { param($r) $r.selection.weighted_entries[0].scaled_weight = [object[]]@(8000) } },
        [pscustomobject]@{ name = 'entry ceiling one-element object array'; mutate = { param($r) $r.selection.weighted_entries[0].ceiling = [object[]]@(8000) } },
        [pscustomobject]@{ name = 'screen one-element object array'; mutate = { param($r) $r.launch_model.screen = [object[]]@('START') } },
        [pscustomobject]@{ name = 'run config one-element object array'; mutate = { param($r) $r.launch_model.run_config = [object[]]@($true) } },
        [pscustomobject]@{ name = 'selected challenge one-element object array'; mutate = { param($r) $r.launch_model.selected_challenge = [object[]]@('') } },
        [pscustomobject]@{ name = 'selected home one-element object array'; mutate = { param($r) $r.launch_model.selected_home = [object[]]@('random') } },
        [pscustomobject]@{ name = 'challenge mode one-element object array'; mutate = { param($r) $r.launch_model.challenge_mode = [object[]]@('standard') } },
        [pscustomobject]@{ name = 'challenge id one-element object array'; mutate = { param($r) $r.launch_model.challenge_id = [object[]]@('standard') } },
        [pscustomobject]@{ name = 'modifier text one-element object array'; mutate = { param($r) $r.launch_model.fresh_profile_modifier_text = [object[]]@($r.launch_model.fresh_profile_modifier_text) } },
        [pscustomobject]@{ name = 'start minutes one-element object array'; mutate = { param($r) $r.launch_model.start_absolute_minutes = [object[]]@(720) } }
    )
    foreach ($fixture in $reportMutations) {
        $preflightHostileFixtures++
        $hostileReport = ConvertTo-ContractClone $freshReport
        & $fixture.mutate $hostileReport
        if (-not (Test-Throws {
            $null = Assert-Rw062HeistPreflightAdmission -Admission $freshAdmission -Report $hostileReport
        })) {
            Add-Failure "Hostile preflight fixture '$($fixture.name)' did not fail closed."
        }
    }
    $preflightHostileFixtures++
    $reportRootArray = [object[]]@($freshReport)
    if (-not (Test-Throws {
        $null = Assert-Rw062HeistPreflightAdmission -Admission $freshAdmission -Report $reportRootArray
    })) {
        Add-Failure "Hostile preflight report fixture 'root one-element object array' did not fail closed."
    }
    $universalPreflightHostiles = @(Get-UniversalContractSchemaHostiles `
        -ValidRoot $freshReport `
        -Prefix 'preflight report')
    $preflightUniversalSchemaHostileFixtures = $universalPreflightHostiles.Count
    foreach ($fixture in $universalPreflightHostiles) {
        $preflightHostileFixtures++
        $hostileReport = Get-ExactContractField $fixture 'value' "Universal preflight hostile '$($fixture.name)'"
        if (-not (Test-Throws {
            $null = Assert-Rw062HeistPreflightAdmission -Admission $freshAdmission -Report $hostileReport
        })) {
            Add-Failure "Universal hostile preflight fixture '$($fixture.name)' did not fail closed."
        }
    }

    $admissionSource = Get-Content -Raw -LiteralPath $AdmissionPath
    $preflightSource = Get-Content -Raw -LiteralPath $PreflightPath
    $runnerSource = Get-Content -Raw -LiteralPath $RunnerPath
    $fixedLauncherSource = Get-Content -Raw -LiteralPath $FixedLauncherPath
    if (Test-Q017SourceShape -AdmissionSource $admissionSource -PreflightSource $preflightSource -RunnerSource $runnerSource -FixedLauncherSource $fixedLauncherSource) {
        $sourceValidFixtures = 1
    }
    else {
        Add-Failure 'Valid Q-017 source shape did not bind fresh admission, the shared Count route, and fixed-lane isolation.'
    }
    $sourceMutations = @(
        [pscustomobject]@{ name = 'fresh seed'; target = 'admission'; from = "heist = 'RW06-HEIST-AUDIT-0000'"; to = "heist = 'RW06-HEIST-AUDIT-0007'" },
        [pscustomobject]@{ name = 'fixed seed'; target = 'admission'; from = "heist = 'RW06-HEIST-AUDIT-0002'"; to = "heist = 'RW06-HEIST-AUDIT-0000'" },
        [pscustomobject]@{ name = 'fresh repeat guard'; target = 'admission'; from = 'if ($Repeat -ne 1)'; to = 'if ($Repeat -ne 2)' },
        [pscustomobject]@{ name = 'scenario permission'; target = 'admission'; from = 'scenario_injection_allowed = $false'; to = 'scenario_injection_allowed = $true' },
        [pscustomobject]@{ name = 'Plan B permission'; target = 'admission'; from = 'plan_b_allowed = $false'; to = 'plan_b_allowed = $true' },
        [pscustomobject]@{ name = '0000 witness'; target = 'preflight'; from = 'run_seed -ne 1262406216'; to = 'run_seed -ne 1262406217' },
        [pscustomobject]@{ name = 'role normalization'; target = 'runner'; from = '$EvidenceRole = $EvidenceRole.ToLowerInvariant()'; to = '$EvidenceRole = $EvidenceRole' },
        [pscustomobject]@{ name = 'summary role'; target = 'runner'; from = 'requested_evidence_role = $EvidenceRole'; to = 'requested_evidence_role = ''fixed-repeat''' },
        [pscustomobject]@{ name = 'shared Count route'; target = 'runner'; from = "'heist' { Invoke-HeistEndingRoute }"; to = "'heist' { Invoke-HeistPlanBRoute }" },
        [pscustomobject]@{ name = 'Heist route role branch'; target = 'runner'; from = 'function Invoke-HeistEndingRoute {'; to = "function Invoke-HeistEndingRoute {`r`n    if (`$EvidenceRole -ceq 'fresh-interactive') { Invoke-HeistPlanBRoute; return }" },
        [pscustomobject]@{ name = 'Heist route seed branch'; target = 'runner'; from = 'function Invoke-HeistEndingRoute {'; to = "function Invoke-HeistEndingRoute {`r`n    if (`$Seed -ceq 'RW06-HEIST-AUDIT-0000') { Invoke-HeistAlternateRoute; return }" },
        [pscustomobject]@{ name = 'Heist route admission-authority branch'; target = 'runner'; from = 'function Invoke-HeistEndingRoute {'; to = "function Invoke-HeistEndingRoute {`r`n    if (`$script:ReplayAdmission.qualification_authority -ceq 'post_run_interactive_review_only') { Invoke-HeistAlternateRoute; return }" },
        [pscustomobject]@{ name = 'Heist route receipt branch'; target = 'runner'; from = 'function Invoke-HeistEndingRoute {'; to = "function Invoke-HeistEndingRoute {`r`n    if (`$script:HeistPreflightAdmissionReceipt.evidence_role -ceq 'fresh-interactive') { Invoke-HeistAlternateRoute; return }" },
        [pscustomobject]@{ name = 'Heist route preflight-report branch'; target = 'runner'; from = 'function Invoke-HeistEndingRoute {'; to = "function Invoke-HeistEndingRoute {`r`n    if (`$heistSeedPreflight.selection.seed_text -ceq 'RW06-HEIST-AUDIT-0000') { Invoke-HeistAlternateRoute; return }" },
        [pscustomobject]@{ name = 'Heist route unconditional alternate call'; target = 'runner'; from = '    Assert-HeistAuditKnowledgeSaveRelaunchContinue'; to = "    Assert-HeistAuditKnowledgeSaveRelaunchContinue`r`n    Invoke-HeistAlternateRoute" },
        [pscustomobject]@{ name = 'fixed outer role argument'; target = 'outer'; from = "'-EvidenceRole', 'fixed-repeat'"; to = "'-EvidenceRole', 'fresh-interactive'" },
        [pscustomobject]@{ name = 'fixed replay custody repository path'; target = 'outer'; from = "`$expectedRepositoryPath = 'tools/rw06_2_ending_replay.ps1'"; to = "`$expectedRepositoryPath = 'tools/rw06_2_evidence_admission.ps1'" },
        [pscustomobject]@{ name = 'fixed replay duplicate custody rows accepted'; target = 'outer'; from = 'if ($rows.Count -ne 1)'; to = 'if ($rows.Count -lt 1)' },
        [pscustomobject]@{ name = 'fixed replay missing pre-launch source custody'; target = 'outer_custody'; mode = 'missing_pre' },
        [pscustomobject]@{ name = 'fixed replay missing post-child source custody'; target = 'outer_custody'; mode = 'missing_post' },
        [pscustomobject]@{ name = 'fixed replay pre-launch source custody reordered after launch'; target = 'outer_custody'; mode = 'pre_after_launch' },
        [pscustomobject]@{ name = 'fixed replay post-child source custody reordered before launch'; target = 'outer_custody'; mode = 'post_before_launch' },
        [pscustomobject]@{ name = 'fixed replay executed path resolver'; target = 'outer'; from = "'-File', (Get-ValidatedReplayToolPath),"; to = "'-File', `$EvidenceAdmissionTool," },
        [pscustomobject]@{ name = 'fixed replay literal execution path'; target = 'outer'; from = "'-File', (Get-ValidatedReplayToolPath),"; to = "'-File', (Join-Path `$PSScriptRoot 'rw06_2_ending_replay.ps1')," },
        [pscustomobject]@{ name = 'fixed replay Command execution with File decoy'; target = 'outer'; from = "'-File', (Get-ValidatedReplayToolPath),"; to = "'-Command', `$EvidenceAdmissionTool, '-Decoy', @('-File', (Get-ValidatedReplayToolPath))," },
        [pscustomobject]@{ name = 'fixed replay second unqualified Command child'; target = 'outer'; from = "`$process = Microsoft.PowerShell.Management\Start-Process -FilePath `$powerShellExe -ArgumentList @("; to = "`$decoyProcess = Start-Process -FilePath `$powerShellExe -ArgumentList @('-Command', `$EvidenceAdmissionTool) -PassThru`r`n        `$process = Microsoft.PowerShell.Management\Start-Process -FilePath `$powerShellExe -ArgumentList @(" },
        [pscustomobject]@{ name = 'fixed replay custody prevalidation removal'; target = 'outer'; from = '$null = Get-ValidatedReplayToolPath'; to = '$null = $true' },
        [pscustomobject]@{ name = 'fixed replay late Set-Item function-provider swap'; target = 'outer'; from = "'-File', (Get-ValidatedReplayToolPath),"; to = "Set-Item -Path function:Get-ValidatedReplayToolPath -Value { `$EvidenceAdmissionTool }`r`n        '-File', (Get-ValidatedReplayToolPath)," },
        [pscustomobject]@{ name = 'fixed replay late si function-provider alias swap'; target = 'outer'; from = "'-File', (Get-ValidatedReplayToolPath),"; to = "si -Path function:Get-ValidatedReplayToolPath -Value { `$EvidenceAdmissionTool }`r`n        '-File', (Get-ValidatedReplayToolPath)," },
        [pscustomobject]@{ name = 'fixed replay late Set-Alias swap'; target = 'outer'; from = "'-File', (Get-ValidatedReplayToolPath),"; to = "Set-Alias -Name Get-ValidatedReplayToolPath -Value Get-Item`r`n        '-File', (Get-ValidatedReplayToolPath)," },
        [pscustomobject]@{ name = 'fixed replay late sal alias swap'; target = 'outer'; from = "'-File', (Get-ValidatedReplayToolPath),"; to = "sal -Name Get-ValidatedReplayToolPath -Value Get-Item`r`n        '-File', (Get-ValidatedReplayToolPath)," },
        [pscustomobject]@{ name = 'fixed outer summary check'; target = 'outer'; from = '$summaryEvidenceRole -isnot [string]'; to = '$false' },
        [pscustomobject]@{
            name = 'fixed proof validation'
            target = 'outer'
            from = 'Assert-FixedRunProofShape -Proof $proof -ExpectedRunIndex $RunIndex -Label "Run $RunIndex proof"'
            to = '$null = $proof'
        }
    )
    foreach ($fixture in $sourceMutations) {
        $sourceHostileFixtures++
        $mutatedAdmission = $admissionSource
        $mutatedPreflight = $preflightSource
        $mutatedRunner = $runnerSource
        $mutatedOuter = $fixedLauncherSource
        switch ([string]$fixture.target) {
            'admission' { $mutatedAdmission = $mutatedAdmission.Replace([string]$fixture.from, [string]$fixture.to) }
            'preflight' { $mutatedPreflight = $mutatedPreflight.Replace([string]$fixture.from, [string]$fixture.to) }
            'runner' { $mutatedRunner = $mutatedRunner.Replace([string]$fixture.from, [string]$fixture.to) }
            'outer' { $mutatedOuter = $mutatedOuter.Replace([string]$fixture.from, [string]$fixture.to) }
            'outer_custody' {
                $mutatedOuter = Invoke-CustodyOrderingSourceMutation `
                    -Source $mutatedOuter `
                    -Mode ([string]$fixture.mode)
            }
        }
        if (($mutatedAdmission -ceq $admissionSource) -and ($mutatedPreflight -ceq $preflightSource) -and
            ($mutatedRunner -ceq $runnerSource) -and ($mutatedOuter -ceq $fixedLauncherSource)) {
            Add-Failure "Source hostile '$($fixture.name)' could not find its exact mutation token."
        }
        elseif (Test-Q017SourceShape -AdmissionSource $mutatedAdmission -PreflightSource $mutatedPreflight -RunnerSource $mutatedRunner -FixedLauncherSource $mutatedOuter) {
            Add-Failure "Source hostile '$($fixture.name)' did not fail closed."
        }
    }

    try {
        $outerAdmissionFunctionSource = Get-ExactOuterAdmissionFunctionSource -Path $FixedLauncherPath
        . ([scriptblock]::Create($outerAdmissionFunctionSource))

        foreach ($fixture in @(
            [pscustomobject]@{ name = 'clean'; ending = 'clean'; seed = 'RW06-CLEAN-ROUTE-01' },
            [pscustomobject]@{ name = 'cheat'; ending = 'cheat'; seed = 'RW06-CHEAT-ROUTE-01' },
            [pscustomobject]@{ name = 'heist'; ending = 'heist'; seed = 'RW06-HEIST-AUDIT-0002' }
        )) {
            $Ending = [string]$fixture.ending
            $Seed = [string]$fixture.seed
            $actualAdmission = Resolve-Rw062ReplayAdmission -Ending $Ending -EvidenceRole fixed-repeat -Seed $Seed -Repeat 1
            Assert-FixedReplayAdmission -Admission $actualAdmission -Label "valid $($fixture.name) outer admission"
            $outerValidFixtures++
        }

        $outerHostiles = @(
            [pscustomobject]@{
                name = 'fresh role'
                ending = 'heist'
                seed = 'RW06-HEIST-AUDIT-0000'
                admission = { Resolve-Rw062ReplayAdmission -Ending heist -EvidenceRole fresh-interactive -Seed 'RW06-HEIST-AUDIT-0000' -Repeat 1 }
            },
            [pscustomobject]@{
                name = 'clean missing owner decisions'
                ending = 'clean'
                seed = 'RW06-CLEAN-ROUTE-01'
                admission = {
                    $value = ConvertTo-ContractClone (Resolve-Rw062ReplayAdmission -Ending clean -EvidenceRole fixed-repeat -Seed 'RW06-CLEAN-ROUTE-01' -Repeat 1)
                    $value.PSObject.Properties.Remove('owner_decisions')
                    return $value
                }
            },
            [pscustomobject]@{
                name = 'clean nonempty owner decisions'
                ending = 'clean'
                seed = 'RW06-CLEAN-ROUTE-01'
                admission = {
                    $value = ConvertTo-ContractClone (Resolve-Rw062ReplayAdmission -Ending clean -EvidenceRole fixed-repeat -Seed 'RW06-CLEAN-ROUTE-01' -Repeat 1)
                    $value.owner_decisions = @('Q-017A')
                    return $value
                }
            },
            [pscustomobject]@{
                name = 'heist wrong owner decisions'
                ending = 'heist'
                seed = 'RW06-HEIST-AUDIT-0002'
                admission = {
                    $value = ConvertTo-ContractClone (Resolve-Rw062ReplayAdmission -Ending heist -EvidenceRole fixed-repeat -Seed 'RW06-HEIST-AUDIT-0002' -Repeat 1)
                    $value.owner_decisions = @('Q-017A', 'Q-013A')
                    return $value
                }
            },
            [pscustomobject]@{
                name = 'scenario injection allowed'
                ending = 'heist'
                seed = 'RW06-HEIST-AUDIT-0002'
                admission = {
                    $value = ConvertTo-ContractClone (Resolve-Rw062ReplayAdmission -Ending heist -EvidenceRole fixed-repeat -Seed 'RW06-HEIST-AUDIT-0002' -Repeat 1)
                    $value.scenario_injection_allowed = $true
                    return $value
                }
            },
            [pscustomobject]@{
                name = 'extra scenario pin authority'
                ending = 'clean'
                seed = 'RW06-CLEAN-ROUTE-01'
                admission = {
                    $value = Resolve-Rw062ReplayAdmission -Ending clean -EvidenceRole fixed-repeat -Seed 'RW06-CLEAN-ROUTE-01' -Repeat 1
                    $value | Add-Member -NotePropertyName scenario_pin -NotePropertyValue 'grand_casino_audit_night'
                    return $value
                }
            },
            [pscustomobject]@{
                name = 'evidence role one-element object array'
                ending = 'heist'
                seed = 'RW06-HEIST-AUDIT-0002'
                admission = {
                    $value = Resolve-Rw062ReplayAdmission -Ending heist -EvidenceRole fixed-repeat -Seed 'RW06-HEIST-AUDIT-0002' -Repeat 1
                    $value.evidence_role = [object[]]@('fixed-repeat')
                    return $value
                }
            },
            [pscustomobject]@{
                name = 'ending one-element object array'
                ending = 'heist'
                seed = 'RW06-HEIST-AUDIT-0002'
                admission = {
                    $value = Resolve-Rw062ReplayAdmission -Ending heist -EvidenceRole fixed-repeat -Seed 'RW06-HEIST-AUDIT-0002' -Repeat 1
                    $value.ending = [object[]]@('heist')
                    return $value
                }
            },
            [pscustomobject]@{
                name = 'seed one-element object array'
                ending = 'heist'
                seed = 'RW06-HEIST-AUDIT-0002'
                admission = {
                    $value = Resolve-Rw062ReplayAdmission -Ending heist -EvidenceRole fixed-repeat -Seed 'RW06-HEIST-AUDIT-0002' -Repeat 1
                    $value.seed = [object[]]@('RW06-HEIST-AUDIT-0002')
                    return $value
                }
            },
            [pscustomobject]@{
                name = 'route plan one-element object array'
                ending = 'heist'
                seed = 'RW06-HEIST-AUDIT-0002'
                admission = {
                    $value = Resolve-Rw062ReplayAdmission -Ending heist -EvidenceRole fixed-repeat -Seed 'RW06-HEIST-AUDIT-0002' -Repeat 1
                    $value.route_plan = [object[]]@('count')
                    return $value
                }
            },
            [pscustomobject]@{
                name = 'expected scenario one-element object array'
                ending = 'heist'
                seed = 'RW06-HEIST-AUDIT-0002'
                admission = {
                    $value = Resolve-Rw062ReplayAdmission -Ending heist -EvidenceRole fixed-repeat -Seed 'RW06-HEIST-AUDIT-0002' -Repeat 1
                    $value.expected_initial_scenario = [object[]]@('grand_casino_audit_night')
                    return $value
                }
            },
            [pscustomobject]@{
                name = 'scenario authority one-element object array'
                ending = 'heist'
                seed = 'RW06-HEIST-AUDIT-0002'
                admission = {
                    $value = Resolve-Rw062ReplayAdmission -Ending heist -EvidenceRole fixed-repeat -Seed 'RW06-HEIST-AUDIT-0002' -Repeat 1
                    $value.scenario_authority = [object[]]@('natural_fresh_profile_first_arrival_preflight')
                    return $value
                }
            },
            [pscustomobject]@{
                name = 'qualification authority one-element object array'
                ending = 'heist'
                seed = 'RW06-HEIST-AUDIT-0002'
                admission = {
                    $value = Resolve-Rw062ReplayAdmission -Ending heist -EvidenceRole fixed-repeat -Seed 'RW06-HEIST-AUDIT-0002' -Repeat 1
                    $value.qualification_authority = [object[]]@('outer_independent_profile_aggregate_only')
                    return $value
                }
            },
            [pscustomobject]@{
                name = 'repeat one-element object array'
                ending = 'heist'
                seed = 'RW06-HEIST-AUDIT-0002'
                admission = {
                    $value = Resolve-Rw062ReplayAdmission -Ending heist -EvidenceRole fixed-repeat -Seed 'RW06-HEIST-AUDIT-0002' -Repeat 1
                    $value.repeat = [object[]]@(1)
                    return $value
                }
            },
            [pscustomobject]@{
                name = 'scenario permission one-element object array'
                ending = 'heist'
                seed = 'RW06-HEIST-AUDIT-0002'
                admission = {
                    $value = Resolve-Rw062ReplayAdmission -Ending heist -EvidenceRole fixed-repeat -Seed 'RW06-HEIST-AUDIT-0002' -Repeat 1
                    $value.scenario_injection_allowed = [object[]]@($false)
                    return $value
                }
            },
            [pscustomobject]@{
                name = 'Plan B permission one-element object array'
                ending = 'heist'
                seed = 'RW06-HEIST-AUDIT-0002'
                admission = {
                    $value = Resolve-Rw062ReplayAdmission -Ending heist -EvidenceRole fixed-repeat -Seed 'RW06-HEIST-AUDIT-0002' -Repeat 1
                    $value.plan_b_allowed = [object[]]@($false)
                    return $value
                }
            },
            [pscustomobject]@{
                name = 'profile isolation one-element object array'
                ending = 'heist'
                seed = 'RW06-HEIST-AUDIT-0002'
                admission = {
                    $value = Resolve-Rw062ReplayAdmission -Ending heist -EvidenceRole fixed-repeat -Seed 'RW06-HEIST-AUDIT-0002' -Repeat 1
                    $value.requires_isolated_profile = [object[]]@($true)
                    return $value
                }
            },
            [pscustomobject]@{
                name = 'release qualification one-element object array'
                ending = 'heist'
                seed = 'RW06-HEIST-AUDIT-0002'
                admission = {
                    $value = Resolve-Rw062ReplayAdmission -Ending heist -EvidenceRole fixed-repeat -Seed 'RW06-HEIST-AUDIT-0002' -Repeat 1
                    $value.release_qualifying = [object[]]@($false)
                    return $value
                }
            },
            [pscustomobject]@{
                name = 'clean null owner decisions'
                ending = 'clean'
                seed = 'RW06-CLEAN-ROUTE-01'
                admission = {
                    $value = ConvertTo-ContractClone (Resolve-Rw062ReplayAdmission -Ending clean -EvidenceRole fixed-repeat -Seed 'RW06-CLEAN-ROUTE-01' -Repeat 1)
                    $value.owner_decisions = $null
                    return $value
                }
            },
            [pscustomobject]@{
                name = 'admission root one-element object array'
                ending = 'heist'
                seed = 'RW06-HEIST-AUDIT-0002'
                admission = {
                    $value = Resolve-Rw062ReplayAdmission -Ending heist -EvidenceRole fixed-repeat -Seed 'RW06-HEIST-AUDIT-0002' -Repeat 1
                    Write-Output -NoEnumerate ([object[]]@($value))
                }
            }
        )
        foreach ($fixture in $outerHostiles) {
            $outerHostileFixtures++
            $Ending = [string]$fixture.ending
            $Seed = [string]$fixture.seed
            $hostileAdmission = & $fixture.admission
            if (-not (Test-Throws {
                Assert-FixedReplayAdmission -Admission $hostileAdmission -Label "hostile $($fixture.name) outer admission"
            })) {
                Add-Failure "Hostile outer admission fixture '$($fixture.name)' did not fail closed."
            }
        }
        $Ending = 'heist'
        $Seed = 'RW06-HEIST-AUDIT-0002'
        $canonicalOuterAdmission = Resolve-Rw062ReplayAdmission `
            -Ending heist `
            -EvidenceRole fixed-repeat `
            -Seed $Seed `
            -Repeat 1
        $universalOuterHostiles = @(Get-UniversalContractSchemaHostiles `
            -ValidRoot $canonicalOuterAdmission `
            -Prefix 'outer admission')
        $outerUniversalSchemaHostileFixtures = $universalOuterHostiles.Count
        foreach ($fixture in $universalOuterHostiles) {
            $outerHostileFixtures++
            $hostileAdmission = Get-ExactContractField $fixture 'value' "Universal outer hostile '$($fixture.name)'"
            if (-not (Test-Throws {
                Assert-FixedReplayAdmission -Admission $hostileAdmission -Label "universal hostile $($fixture.name) outer admission"
            })) {
                Add-Failure "Universal hostile outer admission fixture '$($fixture.name)' did not fail closed."
            }
        }
    }
    catch {
        Add-Failure "Exact outer admission runtime contract could not execute: $($_.Exception.Message)"
    }
}

$reportDirectory = Split-Path -Parent $ReportPath
if (-not [string]::IsNullOrWhiteSpace($reportDirectory)) {
    [void](New-Item -ItemType Directory -Path $reportDirectory -Force)
}
$sourceHashes = [ordered]@{}
foreach ($entry in ([ordered]@{
    admission = $AdmissionPath
    preflight = $PreflightPath
    runner = $RunnerPath
    fixed_launcher = $FixedLauncherPath
}).GetEnumerator()) {
    $sourceHashes[$entry.Key] = if (Test-Path -LiteralPath $entry.Value -PathType Leaf) {
        (Get-FileHash -LiteralPath $entry.Value -Algorithm SHA256).Hash.ToUpperInvariant()
    }
    else { '' }
}
$report = [ordered]@{
    contract = 'rw06_2_evidence_admission'
    passed = ($failures.Count -eq 0)
    owner_decisions = @('Q-013A', 'Q-017A')
    fixed_heist_seed = 'RW06-HEIST-AUDIT-0002'
    fresh_interactive_seed = 'RW06-HEIST-AUDIT-0000'
    fresh_interactive_route_plan = 'count'
    resolver_valid_fixtures = $resolverValidFixtures
    resolver_hostile_fixtures = $resolverHostileFixtures
    preflight_valid_fixtures = $preflightValidFixtures
    admission_object_hostile_fixtures = $admissionObjectHostileFixtures
    admission_universal_schema_hostile_fixtures = $admissionUniversalSchemaHostileFixtures
    preflight_hostile_fixtures = $preflightHostileFixtures
    preflight_universal_schema_hostile_fixtures = $preflightUniversalSchemaHostileFixtures
    source_valid_fixtures = $sourceValidFixtures
    source_hostile_fixtures = $sourceHostileFixtures
    outer_valid_fixtures = $outerValidFixtures
    outer_hostile_fixtures = $outerHostileFixtures
    outer_universal_schema_hostile_fixtures = $outerUniversalSchemaHostileFixtures
    source_sha256 = $sourceHashes
    failures = @($failures)
}
$report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $ReportPath -Encoding utf8

if ($failures.Count -gt 0) {
    foreach ($failure in $failures) {
        Write-Error $failure -ErrorAction Continue
    }
    throw "RW06_2_EVIDENCE_ADMISSION_CONTRACT FAIL ($($failures.Count) failure(s)); report: $ReportPath"
}

Write-Output "RW06_2_EVIDENCE_ADMISSION_CONTRACT PASS; report: $ReportPath"
