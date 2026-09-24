[CmdletBinding()]
param(
    [string]$ReportPath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Worktree = Split-Path -Parent $PSScriptRoot
$LauncherPath = Join-Path $PSScriptRoot 'rw06_2_final_evidence.ps1'
$ReplayPath = Join-Path $PSScriptRoot 'rw06_2_ending_replay.ps1'
$AdmissionPath = Join-Path $PSScriptRoot 'rw06_2_evidence_admission.ps1'
if ([string]::IsNullOrWhiteSpace($ReportPath)) {
    $ReportPath = Join-Path $Worktree '.tmp\rw06_2\final_evidence_source_contract.json'
}

$failures = [Collections.Generic.List[string]]::new()
$checkCount = 0
$hostileCaseCount = 0
$runtimeValidCaseCount = 0
$runtimeHostileCaseCount = 0

function Add-Failure {
    param([Parameter(Mandatory = $true)][string]$Message)
    $failures.Add($Message)
}


function Assert-True {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )
    $script:checkCount++
    if (-not $Condition) { Add-Failure -Message $Message }
}


function Assert-Contains {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Needle,
        [Parameter(Mandatory = $true)][string]$Message
    )
    Assert-True -Condition ($Source.IndexOf($Needle, [StringComparison]::Ordinal) -ge 0) -Message $Message
}


function Assert-Match {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Pattern,
        [Parameter(Mandatory = $true)][string]$Message
    )
    Assert-True -Condition ([regex]::IsMatch($Source, $Pattern, [Text.RegularExpressions.RegexOptions]::Multiline)) -Message $Message
}


function Assert-NotMatch {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Pattern,
        [Parameter(Mandatory = $true)][string]$Message
    )
    Assert-True -Condition (-not [regex]::IsMatch($Source, $Pattern, [Text.RegularExpressions.RegexOptions]::Multiline)) -Message $Message
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


function Read-PowerShellSource {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Required PowerShell source is missing: $Path"
    }
    $tokens = $null
    $parseErrors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors.Count -ne 0) {
        Add-Failure -Message "PowerShell parse failed for $Path`: $($parseErrors[0].Message)"
    }
    return [pscustomobject][ordered]@{
        path = $Path
        source = Get-Content -Raw -LiteralPath $Path -Encoding utf8
        ast = $ast
        parameters = @($ast.ParamBlock.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath })
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


function ConvertTo-ContractClone {
    param([Parameter(Mandatory = $true)]$InputObject)
    $clone = $InputObject | ConvertTo-Json -Depth 40 -Compress | ConvertFrom-Json
    Write-Output -NoEnumerate $clone
}


function New-ReorderedContractObject {
    param([Parameter(Mandatory = $true)]$InputObject)
    if ($InputObject.GetType().FullName -cne 'System.Management.Automation.PSCustomObject') {
        throw 'Reordered contract fixture requires one PSCustomObject.'
    }
    $properties = @($InputObject.PSObject.Properties)
    if ($properties.Count -lt 2) { throw 'Reordered contract fixture requires at least two properties.' }
    $result = [ordered]@{}
    $result[[string]$properties[1].Name] = $properties[1].Value
    $result[[string]$properties[0].Name] = $properties[0].Value
    for ($index = 2; $index -lt $properties.Count; $index++) {
        $result[[string]$properties[$index].Name] = $properties[$index].Value
    }
    return [pscustomobject]$result
}


function Get-FunctionSource {
    param(
        [Parameter(Mandatory = $true)]$Analysis,
        [Parameter(Mandatory = $true)][string]$Name
    )
    $matches = @($Analysis.ast.FindAll({
        param($node)
        $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq $Name
    }, $true))
    if ($matches.Count -ne 1) { return '' }
    return [string]$matches[0].Extent.Text
}


function Get-UniqueFunctionAst {
    param(
        [Parameter(Mandatory = $true)]$Analysis,
        [Parameter(Mandatory = $true)][string]$Name
    )
    $matches = @($Analysis.ast.FindAll({
        param($node)
        $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq $Name
    }, $true))
    if ($matches.Count -ne 1) { return $null }
    return $matches[0]
}


function Get-ExecutableTopLevelSource {
    param([Parameter(Mandatory = $true)]$Analysis)
    return [string]::Join("`n", @($Analysis.ast.EndBlock.Statements | Where-Object {
        $_ -isnot [Management.Automation.Language.FunctionDefinitionAst]
    } | ForEach-Object { $_.Extent.Text }))
}


function Test-TokensInOrder {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string[]]$Needles
    )
    $offset = 0
    foreach ($needle in $Needles) {
        $index = $Source.IndexOf($needle, $offset, [StringComparison]::Ordinal)
        if ($index -lt 0) { return $false }
        $offset = $index + $needle.Length
    }
    return $true
}


function Test-UniqueTokensInOrder {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string[]]$Needles
    )
    foreach ($needle in $Needles) {
        $first = $Source.IndexOf($needle, [StringComparison]::Ordinal)
        if ($first -lt 0 -or $Source.LastIndexOf($needle, [StringComparison]::Ordinal) -ne $first) {
            return $false
        }
    }
    return Test-TokensInOrder -Source $Source -Needles $Needles
}


function Replace-SourceOnce {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Needle,
        [Parameter(Mandatory = $true)][string]$Replacement
    )
    $first = $Source.IndexOf($Needle, [StringComparison]::Ordinal)
    if ($first -lt 0 -or $Source.IndexOf($Needle, $first + $Needle.Length, [StringComparison]::Ordinal) -ge 0) {
        throw "Hostile fixture mutation requires exactly one source occurrence: $Needle"
    }
    return $Source.Substring(0, $first) + $Replacement + $Source.Substring($first + $Needle.Length)
}


function Replace-FunctionSourceOnce {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$FunctionName,
        [Parameter(Mandatory = $true)][string]$Needle,
        [Parameter(Mandatory = $true)][string]$Replacement
    )
    $analysis = ConvertTo-PowerShellAnalysis -Source $Source
    if ($analysis.parse_errors.Count -ne 0) {
        throw "Cannot mutate invalid PowerShell source for function '$FunctionName'."
    }
    $functionAst = Get-UniqueFunctionAst -Analysis $analysis -Name $FunctionName
    if ($null -eq $functionAst) { throw "Could not find unique function '$FunctionName' for hostile mutation." }
    $functionSource = [string]$functionAst.Extent.Text
    $effectiveNeedle = $Needle.Replace("`r`n", "`n")
    $effectiveReplacement = $Replacement.Replace("`r`n", "`n")
    if ($functionSource.Contains("`r`n")) {
        $effectiveNeedle = $effectiveNeedle.Replace("`n", "`r`n")
        $effectiveReplacement = $effectiveReplacement.Replace("`n", "`r`n")
    }
    $first = $functionSource.IndexOf($effectiveNeedle, [StringComparison]::Ordinal)
    if ($first -lt 0 -or
        $functionSource.IndexOf($effectiveNeedle, $first + $effectiveNeedle.Length, [StringComparison]::Ordinal) -ge 0) {
        throw "Hostile fixture requires exactly one occurrence in '$FunctionName': $Needle"
    }
    $absoluteOffset = $functionAst.Extent.StartOffset + $first
    return $Source.Substring(0, $absoluteOffset) + $effectiveReplacement +
        $Source.Substring($absoluteOffset + $effectiveNeedle.Length)
}


function Replace-SourceRegexOnce {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Pattern,
        [Parameter(Mandatory = $true)][string]$Replacement
    )
    $matches = @([regex]::Matches($Source, $Pattern))
    if ($matches.Count -ne 1) {
        throw "Expected one regex source mutation target but found $($matches.Count): $Pattern"
    }
    $match = $matches[0]
    return $Source.Substring(0, $match.Index) + $Replacement +
        $Source.Substring($match.Index + $match.Length)
}


function Get-UniqueTopLevelOrderedHashtable {
    param(
        [Parameter(Mandatory = $true)]$Analysis,
        [Parameter(Mandatory = $true)][string]$VariableName
    )
    $variableToken = '$' + $VariableName
    $assignments = @($Analysis.ast.FindAll({
        param($node)
        $node -is [Management.Automation.Language.AssignmentStatementAst] -and
            [string]$node.Left.Extent.Text -ceq $variableToken
    }, $true) | Where-Object {
        [object]::ReferenceEquals($_.Parent, $Analysis.ast.EndBlock)
    })
    if ($assignments.Count -ne 1) {
        return $null
    }
    $right = $assignments[0].Right
    if ($right -isnot [Management.Automation.Language.CommandExpressionAst] -or
        $right.Expression -isnot [Management.Automation.Language.ConvertExpressionAst] -or
        [string]$right.Expression.Type.TypeName.FullName -cne 'ordered' -or
        $right.Expression.Child -isnot [Management.Automation.Language.HashtableAst]) {
        return $null
    }
    return $right.Expression.Child
}


function ConvertTo-NormalizedSourceText {
    param([Parameter(Mandatory = $true)][string]$Text)
    return [regex]::Replace($Text.Trim(), '\s+', ' ')
}


function Test-ExactTopLevelOrderedHashtableValues {
    param(
        [Parameter(Mandatory = $true)]$Analysis,
        [Parameter(Mandatory = $true)][string]$VariableName,
        [Parameter(Mandatory = $true)][Collections.IDictionary]$Expected,
        [switch]$ValidateOptionalEvidenceRole
    )
    $table = Get-UniqueTopLevelOrderedHashtable -Analysis $Analysis -VariableName $VariableName
    if ($null -eq $table) { return $false }
    $expectedNames = @($Expected.Keys | ForEach-Object { [string]$_ })
    $actualNames = @($table.KeyValuePairs | ForEach-Object {
        if ($_.Item1 -isnot [Management.Automation.Language.StringConstantExpressionAst]) {
            return '__non_literal_key__'
        }
        [string]$_.Item1.Value
    })
    $expectedCount = $expectedNames.Count + $(if ($ValidateOptionalEvidenceRole -and 'evidence_role' -cnotin $expectedNames) { 1 } else { 0 })
    if ($actualNames.Count -ne $expectedCount -or
        @($actualNames | Where-Object { $_ -ceq '__non_literal_key__' }).Count -ne 0 -or
        @($actualNames | Group-Object -CaseSensitive | Where-Object Count -ne 1).Count -ne 0) {
        return $false
    }
    $orderedActualNames = if ($ValidateOptionalEvidenceRole -and 'evidence_role' -cnotin $expectedNames) {
        @($actualNames | Where-Object { $_ -cne 'evidence_role' })
    }
    else { @($actualNames) }
    if ($orderedActualNames.Count -ne $expectedNames.Count) { return $false }
    for ($index = 0; $index -lt $expectedNames.Count; $index++) {
        if ($orderedActualNames[$index] -cne $expectedNames[$index]) { return $false }
    }
    foreach ($actualName in $actualNames) {
        if ($actualName -cnotin $expectedNames -and
            -not ($ValidateOptionalEvidenceRole -and $actualName -ceq 'evidence_role')) {
            return $false
        }
    }
    foreach ($entry in $Expected.GetEnumerator()) {
        $matches = @($table.KeyValuePairs | Where-Object {
            $_.Item1 -is [Management.Automation.Language.StringConstantExpressionAst] -and
                [string]$_.Item1.Value -ceq [string]$entry.Key
        })
        if ($matches.Count -ne 1 -or
            (ConvertTo-NormalizedSourceText -Text ([string]$matches[0].Item2.Extent.Text)) -cne
                (ConvertTo-NormalizedSourceText -Text ([string]$entry.Value))) {
            return $false
        }
    }
    if ($ValidateOptionalEvidenceRole) {
        $evidenceRolePairs = @($table.KeyValuePairs | Where-Object {
            $_.Item1 -is [Management.Automation.Language.StringConstantExpressionAst] -and
                [string]$_.Item1.Value -ceq 'evidence_role'
        })
        if ($evidenceRolePairs.Count -gt 1 -or
            ($evidenceRolePairs.Count -eq 1 -and
                (ConvertTo-NormalizedSourceText -Text ([string]$evidenceRolePairs[0].Item2.Extent.Text)) -cne "'fixed-repeat'")) {
            return $false
        }
    }
    return $true
}


function Replace-TopLevelHashtableValue {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$VariableName,
        [Parameter(Mandatory = $true)][string]$PropertyName,
        [Parameter(Mandatory = $true)][string]$Replacement
    )
    $analysis = ConvertTo-PowerShellAnalysis -Source $Source
    if ($analysis.parse_errors.Count -ne 0) {
        throw "Cannot mutate invalid PowerShell source for '$VariableName.$PropertyName'."
    }
    $table = Get-UniqueTopLevelOrderedHashtable -Analysis $analysis -VariableName $VariableName
    if ($null -eq $table) { throw "Hostile fixture could not find unique ordered table '$VariableName'." }
    $matches = @($table.KeyValuePairs | Where-Object {
        $_.Item1 -is [Management.Automation.Language.StringConstantExpressionAst] -and
            [string]$_.Item1.Value -ceq $PropertyName
    })
    if ($matches.Count -ne 1) {
        throw "Hostile fixture requires exactly one '$VariableName.$PropertyName' value."
    }
    $extent = $matches[0].Item2.Extent
    return $Source.Substring(0, $extent.StartOffset) + $Replacement + $Source.Substring($extent.EndOffset)
}


function Add-TopLevelHashtableEntry {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$VariableName,
        [Parameter(Mandatory = $true)][string]$EntrySource
    )
    $analysis = ConvertTo-PowerShellAnalysis -Source $Source
    if ($analysis.parse_errors.Count -ne 0) {
        throw "Cannot mutate invalid PowerShell source for '$VariableName'."
    }
    $table = Get-UniqueTopLevelOrderedHashtable -Analysis $analysis -VariableName $VariableName
    if ($null -eq $table) { throw "Hostile fixture could not find unique ordered table '$VariableName'." }
    $insertOffset = $table.Extent.EndOffset - 1
    $insertion = "`r`n    $EntrySource`r`n"
    return $Source.Substring(0, $insertOffset) + $insertion + $Source.Substring($insertOffset)
}


function Assert-HostileMutationRejected {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][scriptblock]$Mutate,
        [Parameter(Mandatory = $true)][scriptblock]$Validator
    )
    $script:checkCount++
    $script:hostileCaseCount++
    try {
        $mutatedSource = & $Mutate $launcherSource
        if ($mutatedSource -ceq $launcherSource) {
            Add-Failure -Message "Hostile fixture '$Name' did not mutate the launcher."
            return
        }
        $analysis = ConvertTo-PowerShellAnalysis -Source $mutatedSource
        if ($analysis.parse_errors.Count -ne 0) {
            Add-Failure -Message "Hostile fixture '$Name' is not valid PowerShell: $($analysis.parse_errors[0].Message)"
            return
        }
        if ([bool](& $Validator $analysis)) {
            Add-Failure -Message "Source contract accepted hostile fixture '$Name'."
        }
    }
    catch {
        Add-Failure -Message "Hostile fixture '$Name' could not be evaluated: $($_.Exception.Message)"
    }
}


function ConvertTo-ExactStructuralSourceText {
    param([Parameter(Mandatory = $true)][string]$Text)
    return $Text.Replace("`r`n", "`n").Replace("`r", "`n").Trim()
}


function Get-ExactStructuralSourceSha256 {
    param([Parameter(Mandatory = $true)][string]$Text)
    $canonical = ConvertTo-ExactStructuralSourceText -Text $Text
    $utf8 = [Text.UTF8Encoding]::new($false)
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $digest = $sha.ComputeHash($utf8.GetBytes($canonical))
    }
    finally {
        $sha.Dispose()
    }
    return ([BitConverter]::ToString($digest)).Replace('-', '')
}


function Get-ExactNamedCommandArguments {
    param([Parameter(Mandatory = $true)]$CommandAst)

    if ($CommandAst -isnot [Management.Automation.Language.CommandAst] -or
        $CommandAst.InvocationOperator -ne [Management.Automation.Language.TokenKind]::Unknown -or
        $CommandAst.Redirections.Count -ne 0) {
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
        if ($null -eq $argument -and
            $index + 1 -lt $elements.Count -and
            $elements[$index + 1] -isnot [Management.Automation.Language.CommandParameterAst]) {
            $index++
            $argument = $elements[$index]
        }
        $arguments[$name] = $argument
    }
    return [pscustomobject]@{ valid = $true; arguments = $arguments }
}


function Get-ScopeEndBlock {
    param([Parameter(Mandatory = $true)]$ScopeAst)
    if ($ScopeAst -is [Management.Automation.Language.ScriptBlockAst]) { return $ScopeAst.EndBlock }
    if ($ScopeAst -is [Management.Automation.Language.FunctionDefinitionAst]) { return $ScopeAst.Body.EndBlock }
    return $null
}


function Test-DirectScopeStatement {
    param(
        [Parameter(Mandatory = $true)]$ScopeAst,
        [Parameter(Mandatory = $true)]$StatementAst
    )
    $endBlock = Get-ScopeEndBlock -ScopeAst $ScopeAst
    if ($null -eq $endBlock) { return $false }
    return @($endBlock.Statements | Where-Object {
        $_.Extent.StartOffset -eq $StatementAst.Extent.StartOffset -and
        $_.Extent.EndOffset -eq $StatementAst.Extent.EndOffset
    }).Count -eq 1
}


function Test-ExactCommandArguments {
    param(
        [Parameter(Mandatory = $true)]$CommandAst,
        [Parameter(Mandatory = $true)][Collections.IDictionary]$ExpectedArguments
    )
    $parsed = Get-ExactNamedCommandArguments -CommandAst $CommandAst
    if (-not $parsed.valid -or $parsed.arguments.Count -ne $ExpectedArguments.Count) { return $false }
    if (@($parsed.arguments.Keys | Where-Object { -not $ExpectedArguments.Contains([string]$_) }).Count -ne 0) {
        return $false
    }
    foreach ($name in $ExpectedArguments.Keys) {
        if (-not $parsed.arguments.ContainsKey([string]$name)) { return $false }
        $actual = $parsed.arguments[[string]$name]
        $expected = $ExpectedArguments[$name]
        if ($null -eq $expected) {
            if ($null -ne $actual) { return $false }
        }
        elseif ($null -eq $actual -or
            (ConvertTo-ExactStructuralSourceText -Text ([string]$actual.Extent.Text)) -cne
                (ConvertTo-ExactStructuralSourceText -Text ([string]$expected))) {
            return $false
        }
    }
    return $true
}


function Test-ExactDirectCommandSignatures {
    param(
        [Parameter(Mandatory = $true)]$ScopeAst,
        [Parameter(Mandatory = $true)][string]$CommandName,
        [Parameter(Mandatory = $true)][object[]]$ExpectedSignatures,
        [int]$ExpectedTotalCount = -1
    )
    $matches = @($ScopeAst.FindAll({
        param($node)
        $node -is [Management.Automation.Language.CommandAst] -and $node.GetCommandName() -ceq $CommandName
    }, $true))
    if ($ExpectedTotalCount -lt 0) { $ExpectedTotalCount = $ExpectedSignatures.Count }
    if ($matches.Count -ne $ExpectedTotalCount) { return $false }
    $direct = @($matches | Where-Object {
        $_.Parent -is [Management.Automation.Language.PipelineAst] -and
        $_.Parent.PipelineElements.Count -eq 1 -and
        (Test-DirectScopeStatement -ScopeAst $ScopeAst -StatementAst $_.Parent)
    } | Sort-Object { $_.Extent.StartOffset })
    if ($direct.Count -ne $ExpectedSignatures.Count) { return $false }
    for ($index = 0; $index -lt $ExpectedSignatures.Count; $index++) {
        $signature = $ExpectedSignatures[$index]
        if ($signature -isnot [Collections.IDictionary]) { return $false }
        if (-not (Test-ExactCommandArguments -CommandAst $direct[$index] -ExpectedArguments $signature)) {
            return $false
        }
    }
    return $true
}


function Test-ExactDirectStatementText {
    param(
        [Parameter(Mandatory = $true)]$ScopeAst,
        [Parameter(Mandatory = $true)][string]$ExpectedText
    )
    $endBlock = Get-ScopeEndBlock -ScopeAst $ScopeAst
    if ($null -eq $endBlock) { return $false }
    $normalizedExpected = ConvertTo-ExactStructuralSourceText -Text $ExpectedText
    $matches = @($endBlock.Statements | Where-Object {
        (ConvertTo-ExactStructuralSourceText -Text ([string]$_.Extent.Text)) -ceq $normalizedExpected
    })
    return $matches.Count -eq 1
}


function Test-ExactDirectStatementsInOrder {
    param(
        [Parameter(Mandatory = $true)]$ScopeAst,
        [Parameter(Mandatory = $true)][string[]]$ExpectedTexts
    )
    $endBlock = Get-ScopeEndBlock -ScopeAst $ScopeAst
    if ($null -eq $endBlock) { return $false }
    $lastOffset = -1
    foreach ($expectedText in $ExpectedTexts) {
        $normalizedExpected = ConvertTo-ExactStructuralSourceText -Text $expectedText
        $matches = @($endBlock.Statements | Where-Object {
            (ConvertTo-ExactStructuralSourceText -Text ([string]$_.Extent.Text)) -ceq $normalizedExpected
        })
        if ($matches.Count -ne 1 -or $matches[0].Extent.StartOffset -le $lastOffset) { return $false }
        $lastOffset = $matches[0].Extent.StartOffset
    }
    return $true
}


function Test-ExactTrailingDirectStatements {
    param(
        [Parameter(Mandatory = $true)]$ScopeAst,
        [Parameter(Mandatory = $true)][string[]]$ExpectedTexts
    )
    $endBlock = Get-ScopeEndBlock -ScopeAst $ScopeAst
    if ($null -eq $endBlock) { return $false }
    $statements = @($endBlock.Statements | Where-Object {
        $_ -isnot [Management.Automation.Language.FunctionDefinitionAst]
    })
    if ($statements.Count -lt $ExpectedTexts.Count) { return $false }
    foreach ($statement in $statements) {
        if (@($statement.FindAll({
            param($node)
            $node -is [Management.Automation.Language.ReturnStatementAst] -or
                $node -is [Management.Automation.Language.ExitStatementAst] -or
                $node -is [Management.Automation.Language.TrapStatementAst]
        }, $true)).Count -ne 0) {
            return $false
        }
    }
    $offset = $statements.Count - $ExpectedTexts.Count
    for ($index = 0; $index -lt $ExpectedTexts.Count; $index++) {
        if ((ConvertTo-ExactStructuralSourceText -Text ([string]$statements[$offset + $index].Extent.Text)) -cne
            (ConvertTo-ExactStructuralSourceText -Text $ExpectedTexts[$index])) {
            return $false
        }
    }
    return $true
}


function Test-ExactDirectStatementTailIdentity {
    param(
        [Parameter(Mandatory = $true)]$ScopeAst,
        [Parameter(Mandatory = $true)][string]$StartVariableName,
        [Parameter(Mandatory = $true)][int]$ExpectedStatementCount,
        [Parameter(Mandatory = $true)][string]$ExpectedSha256
    )
    if ($ExpectedStatementCount -lt 1 -or $ExpectedSha256 -cnotmatch '^[A-F0-9]{64}$') { return $false }
    $endBlock = Get-ScopeEndBlock -ScopeAst $ScopeAst
    if ($null -eq $endBlock) { return $false }
    $statements = @($endBlock.Statements | Where-Object {
        $_ -isnot [Management.Automation.Language.FunctionDefinitionAst]
    })
    $startToken = '$' + $StartVariableName
    $starts = @($statements | Where-Object {
        $_ -is [Management.Automation.Language.AssignmentStatementAst] -and
            $_.Left -is [Management.Automation.Language.VariableExpressionAst] -and
            [string]$_.Left.Extent.Text -ceq $startToken
    })
    if ($starts.Count -ne 1) { return $false }
    $startIndex = [Array]::IndexOf($statements, $starts[0])
    if ($startIndex -lt 0) { return $false }
    $tail = @($statements[$startIndex..($statements.Count - 1)])
    if ($tail.Count -ne $ExpectedStatementCount) { return $false }
    $canonicalTail = [string]::Join("`n`n", @($tail | ForEach-Object {
        ConvertTo-ExactStructuralSourceText -Text ([string]$_.Extent.Text)
    }))
    $utf8 = [Text.UTF8Encoding]::new($false)
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $digest = $sha.ComputeHash($utf8.GetBytes($canonicalTail))
    }
    finally { $sha.Dispose() }
    $observed = ([BitConverter]::ToString($digest)).Replace('-', '')
    return $observed -ceq $ExpectedSha256
}


function Test-ExactFunctionDefinitionInventory {
    param(
        [Parameter(Mandatory = $true)]$Analysis,
        [Parameter(Mandatory = $true)][string[]]$ExpectedNames
    )
    $definitions = @($Analysis.ast.FindAll({
        param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst]
    }, $true) | Sort-Object { $_.Extent.StartOffset })
    if ($definitions.Count -ne $ExpectedNames.Count) { return $false }
    for ($index = 0; $index -lt $ExpectedNames.Count; $index++) {
        if ($definitions[$index].Name -cne $ExpectedNames[$index] -or
            -not (Test-DirectScopeStatement -ScopeAst $Analysis.ast -StatementAst $definitions[$index])) {
            return $false
        }
    }
    return @($definitions.Name | Group-Object -CaseSensitive | Where-Object Count -ne 1).Count -eq 0
}


function Test-ExactFunctionStructuralHashes {
    param(
        [Parameter(Mandatory = $true)]$Analysis,
        [Parameter(Mandatory = $true)][Collections.Specialized.OrderedDictionary]$ExpectedHashes
    )
    $definitions = @($Analysis.ast.FindAll({
        param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst]
    }, $true))
    if ($definitions.Count -ne $ExpectedHashes.Count) { return $false }
    foreach ($name in @($ExpectedHashes.Keys)) {
        $functionAst = Get-UniqueFunctionAst -Analysis $Analysis -Name ([string]$name)
        $expectedHash = $ExpectedHashes[$name]
        if ($null -eq $functionAst -or
            $expectedHash -isnot [string] -or
            $expectedHash -cnotmatch '^[A-F0-9]{64}$' -or
            (Get-ExactStructuralSourceSha256 -Text ([string]$functionAst.Extent.Text)) -cne $expectedHash) {
            return $false
        }
    }
    return $true
}


function Test-ClosedFunctionVariables {
    param(
        [Parameter(Mandatory = $true)]$FunctionAst,
        [string[]]$AllowedAmbientVariables = @()
    )
    $defined = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($name in @('_', 'null', 'true', 'false', 'args', 'input', 'PSItem')) {
        $null = $defined.Add($name)
    }
    foreach ($parameter in @($FunctionAst.Body.ParamBlock.Parameters)) {
        $null = $defined.Add([string]$parameter.Name.VariablePath.UserPath)
    }
    foreach ($assignment in @($FunctionAst.FindAll({
        param($node)
        $node -is [Management.Automation.Language.AssignmentStatementAst] -and
            $node.Left -is [Management.Automation.Language.VariableExpressionAst]
    }, $true))) {
        $null = $defined.Add([string]$assignment.Left.VariablePath.UserPath)
    }
    foreach ($loop in @($FunctionAst.FindAll({
        param($node) $node -is [Management.Automation.Language.ForEachStatementAst]
    }, $true))) {
        $null = $defined.Add([string]$loop.Variable.VariablePath.UserPath)
    }
    foreach ($name in $AllowedAmbientVariables) { $null = $defined.Add($name) }
    foreach ($variable in @($FunctionAst.FindAll({
        param($node) $node -is [Management.Automation.Language.VariableExpressionAst]
    }, $true))) {
        if (-not $defined.Contains([string]$variable.VariablePath.UserPath)) { return $false }
    }
    $forbiddenTypes = @('Environment', 'System.Environment', 'AppDomain', 'System.AppDomain')
    if (@($FunctionAst.FindAll({
        param($node)
        $node -is [Management.Automation.Language.TypeExpressionAst] -and
            $forbiddenTypes -contains [string]$node.TypeName.FullName
    }, $true)).Count -ne 0) {
        return $false
    }
    return [string]$FunctionAst.Extent.Text -notmatch '(?i)\b(?:SessionState|PSVariable|Runspace|GetEnvironmentVariable)\b'
}


function Test-NoProtectedAliasMutationAfterOffset {
    param(
        [Parameter(Mandatory = $true)]$Analysis,
        [Parameter(Mandatory = $true)][int]$StartOffset,
        [Parameter(Mandatory = $true)][string[]]$ProtectedVariableNames
    )
    $tainted = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($name in $ProtectedVariableNames) { $null = $tainted.Add($name) }
    $assignments = @($Analysis.ast.FindAll({
        param($node) $node -is [Management.Automation.Language.AssignmentStatementAst]
    }, $true) | Where-Object { $_.Extent.StartOffset -gt $StartOffset } |
        Sort-Object { $_.Extent.StartOffset })
    $loops = @($Analysis.ast.FindAll({
        param($node) $node -is [Management.Automation.Language.ForEachStatementAst]
    }, $true) | Where-Object { $_.Extent.StartOffset -gt $StartOffset } |
        Sort-Object { $_.Extent.StartOffset })
    $changed = $true
    while ($changed) {
        $changed = $false
        foreach ($assignment in $assignments) {
            if ($assignment.Left -isnot [Management.Automation.Language.VariableExpressionAst]) { continue }
            $rhsVariables = @($assignment.Right.FindAll({
                param($node) $node -is [Management.Automation.Language.VariableExpressionAst]
            }, $true))
            if (@($rhsVariables | Where-Object { $tainted.Contains([string]$_.VariablePath.UserPath) }).Count -gt 0 -and
                $tainted.Add([string]$assignment.Left.VariablePath.UserPath)) {
                $changed = $true
            }
        }
        foreach ($loop in $loops) {
            $conditionVariables = @($loop.Condition.FindAll({
                param($node) $node -is [Management.Automation.Language.VariableExpressionAst]
            }, $true))
            if (@($conditionVariables | Where-Object { $tainted.Contains([string]$_.VariablePath.UserPath) }).Count -gt 0 -and
                $tainted.Add([string]$loop.Variable.VariablePath.UserPath)) {
                $changed = $true
            }
        }
    }
    foreach ($assignment in $assignments) {
        if ($assignment.Left -is [Management.Automation.Language.VariableExpressionAst]) {
            if ($ProtectedVariableNames -icontains [string]$assignment.Left.VariablePath.UserPath) { return $false }
            continue
        }
        $leftVariables = @($assignment.Left.FindAll({
            param($node) $node -is [Management.Automation.Language.VariableExpressionAst]
        }, $true))
        if (@($leftVariables | Where-Object { $tainted.Contains([string]$_.VariablePath.UserPath) }).Count -gt 0) {
            return $false
        }
    }
    foreach ($invocation in @($Analysis.ast.FindAll({
        param($node) $node -is [Management.Automation.Language.InvokeMemberExpressionAst]
    }, $true) | Where-Object { $_.Extent.StartOffset -gt $StartOffset })) {
        $receiverVariables = @($invocation.Expression.FindAll({
            param($node) $node -is [Management.Automation.Language.VariableExpressionAst]
        }, $true))
        if (@($receiverVariables | Where-Object { $tainted.Contains([string]$_.VariablePath.UserPath) }).Count -gt 0) {
            $memberName = if ($invocation.Member -is [Management.Automation.Language.StringConstantExpressionAst]) {
                [string]$invocation.Member.Value
            }
            else { '' }
            if ($memberName -cnotin @('ToLowerInvariant', 'Equals', 'ToString')) { return $false }
        }
    }
    foreach ($command in @($Analysis.ast.FindAll({
        param($node)
        $node -is [Management.Automation.Language.CommandAst] -and
            $node.GetCommandName() -ieq 'ForEach-Object'
    }, $true) | Where-Object { $_.Extent.StartOffset -gt $StartOffset })) {
        $pipelineVariables = @($command.Parent.FindAll({
            param($node) $node -is [Management.Automation.Language.VariableExpressionAst]
        }, $true))
        if (@($pipelineVariables | Where-Object { $tainted.Contains([string]$_.VariablePath.UserPath) }).Count -gt 0) {
            return $false
        }
    }
    return $true
}


function Test-NoAuthorityShadowing {
    param(
        [Parameter(Mandatory = $true)]$Analysis,
        [Parameter(Mandatory = $true)][string[]]$ProtectedFunctionNames
    )
    foreach ($name in $ProtectedFunctionNames) {
        $functionAst = Get-UniqueFunctionAst -Analysis $Analysis -Name $name
        if ($null -eq $functionAst -or
            -not (Test-DirectScopeStatement -ScopeAst $Analysis.ast -StatementAst $functionAst)) {
            return $false
        }
    }
    if ($Analysis.source -match '(?i)(?:function|variable|alias)\s*:') { return $false }
    $forbiddenCommands = @(
        'Get-Variable', 'Set-Variable', 'New-Variable', 'Remove-Variable', 'Clear-Variable',
        'Get-PSCallStack', 'Get-History', 'Get-Command', 'Trace-Command', 'Debug-Runspace',
        'Set-Alias', 'New-Alias', 'Remove-Alias', 'Import-Alias', 'Import-Module',
        'Invoke-Expression', 'Invoke-Command', 'Add-Member', 'Update-TypeData',
        'Set-ItemProperty', 'New-ItemProperty', 'Remove-ItemProperty', 'Clear-ItemProperty',
        'gv', 'sv', 'nv', 'rv', 'cv', 'sal', 'nal', 'ral', 'ipal', 'iex',
        'sp', 'np', 'rp', 'clp',
        'Out-File', 'Add-Content', 'Copy-Item', 'Move-Item', 'Rename-Item'
    )
    $forbidden = @($Analysis.ast.FindAll({
        param($node)
        $node -is [Management.Automation.Language.CommandAst] -and
            $null -ne $node.GetCommandName() -and
            $forbiddenCommands -contains $node.GetCommandName()
    }, $true))
    if ($forbidden.Count -ne 0) { return $false }
    if ($Analysis.source -match '(?i)\[(?:System\.)?Environment\]::(?:Exit|FailFast)\s*\(' -or
        $Analysis.source -match '(?i)\.\s*SetShouldExit\s*\(' -or
        $Analysis.source -match '(?i)\$(?:script|global|local|private):ReplayTool\s*=') {
        return $false
    }
    $dynamicInvocations = @($Analysis.ast.FindAll({
        param($node)
        $node -is [Management.Automation.Language.CommandAst] -and
            $node.InvocationOperator -ne [Management.Automation.Language.TokenKind]::Unknown
    }, $true))
    $dotAdmissionCount = 0
    foreach ($command in $dynamicInvocations) {
        if ($command.InvocationOperator -eq [Management.Automation.Language.TokenKind]::Ampersand -and
            $command.GetCommandName() -ceq 'git' -and
            $command.CommandElements.Count -gt 0 -and
            [string]$command.CommandElements[0].Extent.Text -ceq 'git') {
            continue
        }
        if ($command.InvocationOperator -eq [Management.Automation.Language.TokenKind]::Dot -and
            (ConvertTo-ExactStructuralSourceText -Text ([string]$command.Extent.Text)) -ceq '. $EvidenceAdmissionTool' -and
            $command.Parent -is [Management.Automation.Language.PipelineAst] -and
            $command.Parent.Parent -is [Management.Automation.Language.StatementBlockAst] -and
            $command.Parent.Parent.Parent -is [Management.Automation.Language.TryStatementAst] -and
            @($command.Parent.Parent.Statements | Where-Object {
                $_.Extent.StartOffset -eq $command.Parent.Extent.StartOffset -and
                    $_.Extent.EndOffset -eq $command.Parent.Extent.EndOffset
            }).Count -eq 1 -and
            (Test-DirectScopeStatement -ScopeAst $Analysis.ast -StatementAst $command.Parent.Parent.Parent)) {
            $dotAdmissionCount++
            continue
        }
        return $false
    }
    if ($dotAdmissionCount -ne 1) { return $false }
    $setItemCommands = @($Analysis.ast.FindAll({
        param($node)
        $node -is [Management.Automation.Language.CommandAst] -and $node.GetCommandName() -ieq 'Set-Item'
    }, $true))
    if ($setItemCommands.Count -ne 1 -or
        (ConvertTo-ExactStructuralSourceText -Text ([string]$setItemCommands[0].Extent.Text)) -cne
            'Set-Item -LiteralPath "Env:$Name" -Value $Value') {
        return $false
    }
    foreach ($newItem in @($Analysis.ast.FindAll({
        param($node)
        $node -is [Management.Automation.Language.CommandAst] -and $node.GetCommandName() -ieq 'New-Item'
    }, $true))) {
        $parsedNewItem = Get-ExactNamedCommandArguments -CommandAst $newItem
        if (-not $parsedNewItem.valid -or -not $parsedNewItem.arguments.ContainsKey('ItemType') -or
            $null -eq $parsedNewItem.arguments['ItemType'] -or
            [string]$parsedNewItem.arguments['ItemType'].Extent.Text -cne 'Directory') {
            return $false
        }
    }
    return $Analysis.source -notmatch '(?i)ScriptBlock\s*\]::Create|ExecutionContext\.InvokeCommand|InvokeProvider'
}


function Test-NoVariableControlledBypass {
    param(
        [Parameter(Mandatory = $true)]$FunctionAst,
        [Parameter(Mandatory = $true)][string]$VariableName
    )
    if (@($FunctionAst.FindAll({
        param($node)
        $node -is [Management.Automation.Language.ReturnStatementAst] -or
            $node -is [Management.Automation.Language.TrapStatementAst] -or
            $node -is [Management.Automation.Language.TryStatementAst]
    }, $true)).Count -ne 0) {
        return $false
    }
    $conditions = [Collections.Generic.List[object]]::new()
    foreach ($ifStatement in @($FunctionAst.FindAll({
        param($node) $node -is [Management.Automation.Language.IfStatementAst]
    }, $true))) {
        foreach ($clause in $ifStatement.Clauses) { $conditions.Add($clause.Item1) }
    }
    foreach ($statement in @($FunctionAst.FindAll({
        param($node)
        $node -is [Management.Automation.Language.WhileStatementAst] -or
            $node -is [Management.Automation.Language.DoWhileStatementAst] -or
            $node -is [Management.Automation.Language.DoUntilStatementAst] -or
            $node -is [Management.Automation.Language.ForStatementAst] -or
            $node -is [Management.Automation.Language.SwitchStatementAst]
    }, $true))) {
        if ($null -ne $statement.Condition) { $conditions.Add($statement.Condition) }
    }
    foreach ($condition in $conditions) {
        $labelUses = @($condition.FindAll({
            param($node)
            $node -is [Management.Automation.Language.VariableExpressionAst] -and
                $node.VariablePath.UserPath -ceq $VariableName
        }, $true))
        foreach ($labelUse in $labelUses) {
            $cursor = $labelUse.Parent
            $expandableStringSeen = $false
            $allowedDiagnosticArgument = $false
            while ($null -ne $cursor -and $cursor.Extent.StartOffset -ge $condition.Extent.StartOffset -and
                $cursor.Extent.EndOffset -le $condition.Extent.EndOffset) {
                if ($cursor -is [Management.Automation.Language.ExpandableStringExpressionAst]) {
                    $expandableStringSeen = $true
                }
                if ($expandableStringSeen -and
                    $cursor -is [Management.Automation.Language.CommandAst] -and
                    $cursor.GetCommandName() -ceq 'ConvertTo-CanonicalExactObjectJson') {
                    $allowedDiagnosticArgument = $true
                    break
                }
                $cursor = $cursor.Parent
            }
            if (-not $allowedDiagnosticArgument) { return $false }
        }
    }
    return $true
}


function Assert-ReplayHostileMutationRejected {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][scriptblock]$Mutate,
        [Parameter(Mandatory = $true)][scriptblock]$Validator
    )
    $script:checkCount++
    $script:hostileCaseCount++
    try {
        $mutatedSource = & $Mutate $replaySource
        if ($mutatedSource -ceq $replaySource) {
            Add-Failure -Message "Hostile fixture '$Name' did not mutate the replay."
            return
        }
        $analysis = ConvertTo-PowerShellAnalysis -Source $mutatedSource
        if ($analysis.parse_errors.Count -ne 0) {
            Add-Failure -Message "Hostile replay fixture '$Name' is not valid PowerShell: $($analysis.parse_errors[0].Message)"
            return
        }
        if ([bool](& $Validator $analysis)) {
            Add-Failure -Message "Source contract accepted hostile replay fixture '$Name'."
        }
    }
    catch {
        Add-Failure -Message "Hostile replay fixture '$Name' could not be evaluated: $($_.Exception.Message)"
    }
}


$launcher = Read-PowerShellSource -Path $LauncherPath
$replay = Read-PowerShellSource -Path $ReplayPath
$launcherSource = [string]$launcher.source
$replaySource = [string]$replay.source
if (-not (Test-Path -LiteralPath $AdmissionPath -PathType Leaf)) {
    throw "Required PowerShell source is missing: $AdmissionPath"
}
$admissionTokens = $null
$admissionParseErrors = $null
$admissionAst = [Management.Automation.Language.Parser]::ParseFile($AdmissionPath, [ref]$admissionTokens, [ref]$admissionParseErrors)
if ($admissionParseErrors.Count -ne 0) {
    Add-Failure -Message "PowerShell parse failed for $AdmissionPath`: $($admissionParseErrors[0].Message)"
}
$admissionSource = Get-Content -Raw -LiteralPath $AdmissionPath -Encoding utf8
$admissionAnalysis = [pscustomobject][ordered]@{
    path = $AdmissionPath
    source = $admissionSource
    ast = $admissionAst
    parameters = @()
}
$launcherTopLevel = Get-ExecutableTopLevelSource -Analysis $launcher
$expectedLauncherStructuralSha256 = '4B7278C63C2D508ADDA2BAC459EAE430345289D239A818AF38744A34B5790272'
$expectedLauncherFunctionHashes = [ordered]@{
    'Get-FailureMessage' = 'B9697A70DF70DBEC0D0AE3D97284DBF4F18D6B9EBC6339730B1404B084D8AC37'
    'Add-TerminalFailure' = 'B10F2F4D8C162E94A2AA23ACE9B2C08271894D706A677638362C06E0940CC208'
    'Get-ExactValue' = '4BC165881385D770A902C7261CE8E6A8CD9BBDC5E17637F81B290E92F9046AEC'
    'Get-ExactValueNoEnumerate' = '07225A75D9EE8E854C94F610A69A7BFB82BAA2766DDCAA09B5CCEB52DB9CFFE0'
    'Test-ExactStringArray' = '0DE6452771AB4E370B9402DE004D8040F0D36D4ED3212EA0A35E3C3293B8B3EF'
    'Get-ExactPositivePid' = '41841AF6568C7704AB2701B3B249AB58642C33F255D98905AC5A71FC6FAE78A6'
    'Get-ExactPidArray' = '722EC4B5995523F991FB3B17B39C8CA248FAF77788EE5CFCAB0CB0E6F12387EE'
    'Assert-FixedReplayAdmission' = '195E1CE704BD7AB68228A1665F550F1DB8293D53B35497B55AAE6299BBE586DF'
    'Get-GitValue' = '04DC697E72A632E7B36A7BB98162BBD3F5FA42498E0EF9FB765697944666283F'
    'Get-Sha256' = 'EF7958AD8CD27EC60D4AB2FF4D71B01476DFCE67DE1554B9C5BB84104CCC2479'
    'Test-ExactPsCustomObject' = 'C130DD450462849C0ADFA53D6191512438E4011191C80218D53F4FF65E44B34C'
    'Assert-LocalExactPropertyNames' = '092454AD9D05ED8F6C04C6081B361F23B63930622A51D28D021D0988D3C80BF7'
    'ConvertFrom-ExactJsonObjectText' = '1F1F21C3C9DE95A2FCC8C7C89875A00107AB114337BAEBFA4CB9691E4BC5FDDA'
    'ConvertTo-CanonicalExactObjectJson' = 'DB300F9B6BC2BC06A0995003FD4BA7E730B051B7BBD9C877718CEDD7B8253DAE'
    'Get-CanonicalExactObjectSha256' = '7356711494697C5E51E20B9B40038BFE00247D0D959089E5B7D20BA56C3DFEA5'
    'Get-HeldFileDigests' = 'D3E9C2BB3EFEAA650D3AD3C390932D9A31C9D34D6B0E1224D2F636FC537C52DC'
    'Get-HeldUtf8Text' = '1D2108F2F90E3A05D1DF17575996D5394B53BE58EEE12548D3E50B4EC6C859F6'
    'New-LockedJsonReceipt' = '49C5DC817883410663EBD7BA224D2F98D18D1F743C6B2161941A91577BB43707'
    'Get-TrackedSourceDescriptors' = 'B9BC155D4AEC15268B9751B187CEDFE3CF98C53E8CC4B6D5C0D1AB01AEF33AEF'
    'Assert-SourceCustodyRowSchema' = '9A871D49090EFFEE775EE155C6A196BA6DBA8AD68C42938D7E88E0950C4DB789'
    'Assert-SourceCustodyRowMatches' = 'D44A1540402A687EFDEF55827CDC1C602930E1F65E54A6AD393B891F3CFC0B7D'
    'Assert-SourceCustodyReceiptSchema' = 'D95FEE12661761FFDDDDAB323E4429BF836BA539184AD35917C9778635689036'
    'Assert-RepositoryBlobIdentity' = 'B64418F0FD4BB0742210849B5927CD075B1DA5B6729AA65412DFA409B7A9A3BC'
    'Get-ValidatedReplayToolPath' = 'D2DDCEA8835CE75DE73AE8995BEA3FD471326A2A356F880CD7FB6885F5C1ED9A'
    'Assert-SourceCustody' = '74DA54641A2950802F08DE078CCF37E79D68AA1A5663566D677764F98D0CB232'
    'Open-SourceCustodyHandle' = '345D4E350E7C85F03CCDC15B7AAD785DDE977B40D724D298198B71D507D99C60'
    'New-SourceCustody' = 'C087B56B754C970C80465E107C1B5EF908BB38C1A7477768D0BE6E76BD6E3086'
    'Complete-SourceCustody' = 'AC03E267C9517A3711CC7B4199B211D9879DBEC9971880DCFF4C604114D274A0'
    'Close-SourceCustody' = '76D9E5B3348898CC5FCCA07DCC744708F7FD65F7AEE628BAB5D78B9A0B4E0B95'
    'Assert-RepositoryIdentity' = '113D8B24A6560094A10D8071D4F9B9388D980F5FAB04AC6702CCAEB524E65DDD'
    'Get-GodotProcesses' = '7699DF661DF89F310672A1445DBA278641056096D7821C592A6B790FD61EEF42'
    'Get-ProcessCensus' = '14D84A62D4E0C6A49F00286297E68CDD98932685E3FBF2ACD9758EDD5D192580'
    'Get-LeaseOwnerPids' = '94118E1F03C5E5D448BC591C97480DA0B6B7BAD454F7EA61F169BE79126047AB'
    'Clear-StaleGodotLeases' = '9C3658E91DB6E0A00AB5B1BA63A5BCBDCE3846CD543D00A33CBD628C36EE1E9D'
    'Clear-StaleExclusiveLease' = '888D3ACE0F6DDDA804E415AC1DE5FBC55DAD07D7273C742E45F0D63B59CF843D'
    'Enter-LaunchLock' = 'C67946081651E2D0CC785E8DD355D19A32437D8C799CAF0800A57E02A8ABA291'
    'Exit-LaunchLock' = 'C6CFD8A44C8E80F661F38B251BF888D792CF6ED42C4EEE6334CA7262A2BC2CFD'
    'Test-OwnedExclusiveLease' = 'B96D566226145916ECDA5B178F1A5CD2526EDAA84703EC2CE29573E522534CF1'
    'Assert-ExclusiveAdmission' = '079DF12B4FBCE47F7B8058F7FECDB24E77916C615B5622952D4C5C4AC762613E'
    'Assert-OwnedExclusiveReservation' = '4ABFA5A68421E53192D7B67B1137F036F5FDE427F9D234370ACE308461871DD7'
    'Wait-ExclusiveDrain' = '307C28FF308A2742BF3F10EEC48DC24CAF31AB15F6A66D893DB415FBAD3190C0'
    'New-OwnedExclusiveLease' = '636F3B4CA4FAB99429DC4112AA728AC8F5C97BD6632D9C72FC75B32C526910BD'
    'Get-LiveSurvivorPids' = 'E0B97CD5C1AFB7E8C9D43D147CDBFAB09878B20568CAC1164064FC4CFFF8C45F'
    'Test-LauncherCustodyLease' = 'BB54740D4C950B9587CAE715944A78CE162DC3232B1CF850EC9C09158D434D08'
    'Test-ExclusiveSurvivorCustody' = 'DD717694DF7B0D4720B20ED20DAC52FD48600402F93FA3F6B6BF856C919A089A'
    'Set-ExclusiveLeaseSurvivorCustody' = 'CF3D50398406521306C9EE3A826EDB942C67A0C99DBA7B1B0C1BD10F3484FDC6'
    'Get-ExactOwnedReplayProcess' = '3B1B9BF3A22065DC3ADC7F8FED18299D119BD8AE582A45584BD51078F6B1FF37'
    'Get-OwnedGodotProcesses' = '18846AC488ACF1791E65CEE257510BEA2EF5064ACE1A01E4C727E058BD88A880'
    'Stop-UnregisteredReplayProcess' = '829FDB481BD6D43D5300B4983A6CB7536C8534A8514FC84B03209488514B710B'
    'Get-DescendantProcessIds' = '04C57C8249E31AA282B6EDD199866BC63248A9B230B4338AAAF07112536D06F4'
    'Stop-OwnedReplayIdentity' = '1CF9C31BB7ADCCA2E479736D654964421CB6291C60E251B35630A0B6C3C36DB8'
    'Stop-AllOwnedProcesses' = '9717CDA70E34CB6C256F735C5E5D9F901A545500D898F373BE77B09EDF721CF9'
    'Get-OwnedSurvivors' = '7E44AB653D5F2DC44451A6EC1D013FD01383E405DEB6955C3CEC0C1D7664731F'
    'Restore-ProcessEnvironmentValue' = '8942FD1F457CD6AB18AF7543D769B47B75FD9D1438005B8D7AB6F01F3ED48098'
    'Assert-ExactPublishedPath' = '1E218B95B2604CB804EF28FF3DC4EAB4274A02D16CF439BB06D985A58C938499'
    'Resolve-ExactSessionRoot' = '8A9618768743DEE842E829A3D274E34F01345F4B2D245ACEB46C9B7E4E3E58F7'
    'Assert-StrictSessionLogs' = '70CC1AAEDF8702B408DA9208048E56050F5E43C3CE15683CCFC438C4BD93A8F3'
    'Assert-RetainedHeistPreflightArtifact' = '8CC887199A43141E3588EF145B96804BB14C468A5773832C8042D238343AB42A'
    'Assert-OneRunJsonShapes' = '072C4D460BCD6F631201CB2BA684C713CE80DA63FA5A62D51BED4A7E2C812600'
    'Assert-FinalCheckpointJsonShapes' = '1EB1B3F6DD8548ECC01007E358638D9D652FE1F19D5A5D050CBACB969F875A94'
    'Assert-PersistenceCoreCheckpointShape' = '1331909FB2E32657C4D03DD974BC46937668F12F2911CFC159CA1C5F1B2E0E8A'
    'Assert-SaveContinueCheckpointJsonShape' = 'D6C83A4FB02C4C67DD969564CBC2FA7A3EDAE3A736D640AE2826083A5DCE9346'
    'Assert-OneRunEvidence' = 'D520EAD962B6EE9C3918B1F0A46E973C66BD61046A578BDB3F2B8DA8C71D132C'
    'Invoke-OneFixedRun' = 'F6584D0938229D19D83567E8A83FCDA7AF86291196070A08F4CA89BE31079FF3'
    'Assert-FixedRunProofShape' = '64E2A51EAC86EC1FE6900D074EA166D4F8CD62B993040039B50E747494672472'
    'Assert-CanonicalFixedProofShape' = '90C41E92E51CEEF3D502642B96C4628C54B72427123823A7F49DD71F871A99A4'
    'Compare-FixedRunProofs' = '959E26C73D7FB21D4EE93846E7990833896C50388B19308107620BE3C67CF122'
    'Test-FixedRepeatQualification' = '9466784AE70BC8A0BACBB0C68BB3452C6811A5E03853E1CAE9A1F3AA845AA5E1'
    'Assert-TerminalRecordKeys' = 'C8F9110A3F07435706C34360F661F7BA7D813A710696433DB1358D275E98A618'
    'Test-ExactLowerHexOrEmpty' = '78543CF6EAC2AA4EF6EC7C04843305EB4F3EEB5378DFC61279A15BF5A45061A6'
    'Assert-TerminalProcessCensusRowShape' = '0D1F0BDD66ACD76FD7D73D4A0F5D1663CAB8DDE40CB868C42747308C07E67792'
    'Assert-TerminalSurvivorRowShape' = '92A0438CD33EF8ED56749244F1562FD13A00E366CC0BC4F64E844BBB74AF79CE'
    'Assert-TerminalArtifactRowShape' = '559C9D65DE5A09DBB40263DE1AD7B82C84E7A08FB65B1C46A98BD8F243D41268'
    'Assert-TerminalAggregateShape' = 'A71BB67AD1B6508C1C4590E0ED629AFA9DF57B5CFF454A24E79CC9DDC0D18A0C'
    'Assert-TerminalMetadataShape' = '7CEC1B8BA539BE1AD99000F4A5921D05D18393B5228A4FED6414FD4F1ECECEDF'
    'Assert-TerminalManifestShape' = 'CCA61C53896C48C49E5EEC1118A01B31C14085657BC1A840AA5AD8E2EE1D2D9E'
    'Assert-TerminalResultShape' = '1737385AD2EB980066CA08F7BEA3EAABB0D2AD602AB1357EACF6E75A731606DB'
    'Get-ManifestArtifactPaths' = '1A7D40786877603FDBF6A28810C98EA8F7B9871783C244A6A61C3F4CB2A7E396'
    'Assert-ManifestArtifactHash' = '20CC4329CFDB43FDEE30A6901140056753D5C9C7FADF34083DA77D3FA722C4C5'
    'Assert-FixedRunManifestArtifactBindings' = 'E3B55E2F31ACF58D3226237D3E68A95E5233BDD9F4FE505BB38185EAC555FE1F'
}
$immutableLauncherValidator = {
    param($analysis)
    $analysis.parse_errors.Count -eq 0 -and
        (Get-ExactStructuralSourceSha256 -Text ([string]$analysis.source)) -ceq $expectedLauncherStructuralSha256 -and
        (Test-ExactFunctionStructuralHashes -Analysis $analysis -ExpectedHashes $expectedLauncherFunctionHashes)
}

$endingNormalizationValidator = {
    param($analysis)
    $topLevel = Get-ExecutableTopLevelSource -Analysis $analysis
    Test-TokensInOrder -Source $topLevel -Needles @(
        '$Ending = $Ending.ToLowerInvariant()',
        '$FixedSeeds = @{',
        '$Seed = [string]$FixedSeeds[$Ending]'
    )
}
$exclusiveAdmissionValidator = {
    param($analysis)
    $topLevel = Get-ExecutableTopLevelSource -Analysis $analysis
    $admission = Get-FunctionSource -Analysis $analysis -Name 'Assert-ExclusiveAdmission'
    $drain = Get-FunctionSource -Analysis $analysis -Name 'Wait-ExclusiveDrain'
    -not [string]::IsNullOrWhiteSpace($admission) -and
        (Test-TokensInOrder -Source $admission -Needles @(
            'if (-not $AllowOwnedLease)',
            'Clear-StaleExclusiveLease',
            'else',
            'Clear-StaleGodotLeases',
            '$exclusiveExists = Test-Path',
            'if (-not $AllowOwnedLease)',
            'return',
            'Test-OwnedExclusiveLease',
            '$normalLeases.Count -ne 0',
            '$godotProcesses.Count -ne 0'
        )) -and
        (Test-TokensInOrder -Source $drain -Needles @(
            '$deadline = [DateTime]::UtcNow.AddSeconds($PerRunTimeoutSeconds)',
            'while ([DateTime]::UtcNow -lt $deadline)',
            '$drainLock = Enter-LaunchLock -TimeoutSeconds 5',
            'Assert-OwnedExclusiveReservation',
            '$normalLeases = @(',
            '$godotProcesses = @(',
            'if ($normalLeases.Count -eq 0 -and $godotProcesses.Count -eq 0)',
            'Assert-ExclusiveAdmission -AllowOwnedLease',
            'return'
        )) -and
        (Test-TokensInOrder -Source $topLevel -Needles @(
            '$launchLock = Enter-LaunchLock',
            'Assert-ExclusiveAdmission',
            'New-OwnedExclusiveLease',
            '$script:LeaseOwned = $true',
            'Assert-OwnedExclusiveReservation',
            'Exit-LaunchLock -Stream $launchLock',
            'Wait-ExclusiveDrain',
            'foreach ($runIndex in 1..2)'
        ))
}
$exclusiveLeaseCreationValidator = {
    param($analysis)
    $create = Get-FunctionSource -Analysis $analysis -Name 'New-OwnedExclusiveLease'
    Test-TokensInOrder -Source $create -Needles @(
        '$created = $false',
        '[IO.FileMode]::CreateNew',
        '$created = $true',
        '$stream.Flush($true)',
        '$stream.Dispose()',
        'Test-OwnedExclusiveLease',
        'catch',
        'if ($created)',
        'while (Test-Path -LiteralPath $LeasePath)',
        'Remove-Item -LiteralPath $LeasePath -Force -ErrorAction Stop',
        'catch { Start-Sleep -Milliseconds 200 }',
        'throw $creationFailure'
    )
}
$spawnCustodyValidator = {
    param($analysis)
    $invoke = Get-FunctionSource -Analysis $analysis -Name 'Invoke-OneFixedRun'
    -not [string]::IsNullOrWhiteSpace($invoke) -and
        (Test-TokensInOrder -Source $invoke -Needles @(
            '$env:APPDATA = $profileRoaming',
            '$env:LOCALAPPDATA = $profileLocal',
            '$process = Microsoft.PowerShell.Management\Start-Process',
            '$sessionPrefix =',
            '$script:ProvisionalReplayProcesses.Add($provisionalIdentity)',
            '$script:OwnedReplayIdentities.Add($identity)',
            '$null = $script:ProvisionalReplayProcesses.Remove($provisionalIdentity)',
            'Stop-UnregisteredReplayProcess -Process $process -SessionPrefix $sessionPrefix',
            "Restore-ProcessEnvironmentValue -Name 'APPDATA'",
            "Restore-ProcessEnvironmentValue -Name 'LOCALAPPDATA'",
            '$process.WaitForExit('
        ))
}
$proofPromotionValidator = {
    param($analysis)
    $topLevel = Get-ExecutableTopLevelSource -Analysis $analysis
    Test-TokensInOrder -Source $topLevel -Needles @(
        '$script:CanonicalProof = Compare-FixedRunProofs -Proofs @($script:RunProofs)',
        '$script:Outcome = ''green'''
    )
}
$qualificationValidator = {
    param($analysis)
    $topLevel = Get-ExecutableTopLevelSource -Analysis $analysis
    $qualification = Get-FunctionSource -Analysis $analysis -Name 'Test-FixedRepeatQualification'
    (Test-TokensInOrder -Source $qualification -Needles @(
        '$Outcome -isnot [string]',
        "`$Outcome -cne 'green'",
        '$RunProofs -isnot [object[]]',
        '$RunProofs.Count -ne 2',
        '-not (Test-ExactPsCustomObject -Value $CanonicalProof)',
        '$FinalProcessCensus -isnot [object[]]',
        '$FinalProcessCensus.Count -ne 0',
        '$FinalHead -isnot [string]',
        '$FinalTree -isnot [string]',
        '$LeaseOwned -isnot [bool]',
        '$SourceCustodyComplete -isnot [bool]',
        'Assert-FixedRunProofShape',
        'Assert-CanonicalFixedProofShape',
        '$recomputedCanonicalProof = Compare-FixedRunProofs -Proofs $proofArray',
        'ConvertTo-CanonicalExactObjectJson -InputObject $CanonicalProof',
        'ConvertTo-CanonicalExactObjectJson -InputObject $recomputedCanonicalProof'
    )) -and
        (Test-TokensInOrder -Source $topLevel -Needles @(
            '$fixedRepeatQualifying = Test-FixedRepeatQualification',
            '-TerminalError $script:TerminalError',
            '-RunProofs @($script:RunProofs)',
            '-CanonicalProof $script:CanonicalProof',
            '-SourceCustodyComplete $script:SourceCustodyComplete'
        ))
}
$terminalCanonicalAuthorityValidator = {
    param($analysis)
    if (-not (Test-ExactFunctionStructuralHashes -Analysis $analysis -ExpectedHashes $expectedLauncherFunctionHashes)) {
        return $false
    }
    $aggregateAst = Get-UniqueFunctionAst -Analysis $analysis -Name 'Assert-TerminalAggregateShape'
    if ($null -eq $aggregateAst) { return $false }
    $recomputeCommands = @($aggregateAst.FindAll({
        param($node)
        $node -is [Management.Automation.Language.CommandAst] -and
            $node.GetCommandName() -ceq 'Compare-FixedRunProofs'
    }, $true))
    if ($recomputeCommands.Count -ne 1 -or
        -not (Test-ExactCommandArguments -CommandAst $recomputeCommands[0] -ExpectedArguments ([ordered]@{
            Proofs = '@($script:RunProofs)'
        }))) {
        return $false
    }
    $recomputeAssignment = $recomputeCommands[0].Parent.Parent
    if ($recomputeCommands[0].Parent -isnot [Management.Automation.Language.PipelineAst] -or
        $recomputeAssignment -isnot [Management.Automation.Language.AssignmentStatementAst] -or
        [string]$recomputeAssignment.Left.Extent.Text -cne '$recomputedCanonicalProof' -or
        $recomputeAssignment.Parent -isnot [Management.Automation.Language.StatementBlockAst] -or
        $recomputeAssignment.Parent.Parent -isnot [Management.Automation.Language.IfStatementAst]) {
        return $false
    }
    $recomputedAssignments = @($aggregateAst.FindAll({
        param($node)
        $node -is [Management.Automation.Language.AssignmentStatementAst] -and
            $node.Left -is [Management.Automation.Language.VariableExpressionAst] -and
            $node.Left.VariablePath.UserPath -ceq 'recomputedCanonicalProof'
    }, $true) | Sort-Object { $_.Extent.StartOffset })
    if ($recomputedAssignments.Count -ne 2 -or
        (ConvertTo-ExactStructuralSourceText -Text ([string]$recomputedAssignments[0].Right.Extent.Text)) -cne '$null' -or
        $recomputedAssignments[1].Extent.StartOffset -ne $recomputeAssignment.Extent.StartOffset) {
        return $false
    }
    $aggregateSource = [string]$aggregateAst.Extent.Text
    if (-not (Test-TokensInOrder -Source $aggregateSource -Needles @(
        '$recomputedCanonicalProof = Compare-FixedRunProofs -Proofs @($script:RunProofs)',
        "Assert-CanonicalFixedProofShape -Proof `$script:CanonicalProof -Label 'Held canonical proof at terminal publication'",
        "ConvertTo-CanonicalExactObjectJson -InputObject `$script:CanonicalProof -Label 'Held canonical proof at terminal publication'",
        "ConvertTo-CanonicalExactObjectJson -InputObject `$recomputedCanonicalProof -Label 'Freshly recomputed canonical proof at terminal publication'",
        '$expectedIndependent = if ($null -ne $recomputedCanonicalProof) { $recomputedCanonicalProof.isolated_profiles } else { $false }',
        '$expectedDeterministic = if ($null -ne $recomputedCanonicalProof) { $recomputedCanonicalProof.deterministic } else { $false }',
        'Assert-CanonicalFixedProofShape -Proof $canonicalProof -Label "$Label canonical proof"',
        'ConvertTo-CanonicalExactObjectJson -InputObject $canonicalProof -Label "$Label canonical proof"',
        "ConvertTo-CanonicalExactObjectJson -InputObject `$recomputedCanonicalProof -Label 'Freshly recomputed canonical proof at terminal publication'",
        '$null -eq $recomputedCanonicalProof -or'
    ))) {
        return $false
    }
    $canonicalAssignments = @($analysis.ast.FindAll({
        param($node)
        $node -is [Management.Automation.Language.AssignmentStatementAst] -and
            [string]$node.Left.Extent.Text -match '^\$script:CanonicalProof(?:$|\.|\[)'
    }, $true) | Sort-Object { $_.Extent.StartOffset })
    if ($canonicalAssignments.Count -ne 2 -or
        (ConvertTo-ExactStructuralSourceText -Text ([string]$canonicalAssignments[0].Extent.Text)) -cne '$script:CanonicalProof = $null' -or
        (ConvertTo-ExactStructuralSourceText -Text ([string]$canonicalAssignments[1].Extent.Text)) -cne
            '$script:CanonicalProof = Compare-FixedRunProofs -Proofs @($script:RunProofs)') {
        return $false
    }
    $promotionOffset = $canonicalAssignments[1].Extent.EndOffset
    $runProofWritesAfterPromotion = @($analysis.ast.FindAll({
        param($node)
        ($node -is [Management.Automation.Language.AssignmentStatementAst] -and
            [string]$node.Left.Extent.Text -match '^\$script:RunProofs(?:$|\.|\[)') -or
        ($node -is [Management.Automation.Language.InvokeMemberExpressionAst] -and
            [string]$node.Expression.Extent.Text -match '^\$script:RunProofs(?:$|\.|\[)')
    }, $true) | Where-Object { $_.Extent.StartOffset -gt $promotionOffset })
    return $runProofWritesAfterPromotion.Count -eq 0 -and
        (Test-NoProtectedAliasMutationAfterOffset `
            -Analysis $analysis `
            -StartOffset $promotionOffset `
            -ProtectedVariableNames @('script:RunProofs', 'script:CanonicalProof'))
}
$childIterationBoundaryValidator = {
    param($analysis)
    $oneRun = Get-FunctionSource -Analysis $analysis -Name 'Assert-OneRunEvidence'
    Test-TokensInOrder -Source $oneRun -Needles @(
        "`$runRole = Get-ExactValueNoEnumerate `$run @('role') `$null",
        "`$runEvidenceRole = Get-ExactValueNoEnumerate `$run @('requested_evidence_role') `$null",
        "`$runProfileScope = Get-ExactValueNoEnumerate `$run @('repeat_profile_scope') `$null",
        "`$runQualificationAuthority = Get-ExactValueNoEnumerate `$run @('fixed_repeat_qualification_authority') `$null",
        "`$runReleaseQualifying = Get-ExactValueNoEnumerate `$run @('release_qualifying') `$null",
        "`$runQualification = Get-ExactValueNoEnumerate `$run @('qualification') `$null",
        '$runRole -isnot [string]',
        "`$runRole -cne 'child_development_iteration'",
        '$runEvidenceRole -isnot [string]',
        "`$runEvidenceRole -cne 'fixed-repeat'",
        '$runProfileScope -isnot [string]',
        "`$runProfileScope -cne 'shared_caller_appdata'",
        '$runQualificationAuthority -isnot [string]',
        "`$runQualificationAuthority -cne 'outer_independent_profile_aggregate_only'",
        '$runReleaseQualifying -isnot [bool]',
        '$runQualification -isnot [string]',
        "`$runQualification -cne 'non_qualifying_development_iteration'"
    )
}
$fixedRoleIsolationValidator = {
    param($analysis)
    $oneRun = Get-FunctionSource -Analysis $analysis -Name 'Assert-OneRunEvidence'
    $invoke = Get-FunctionSource -Analysis $analysis -Name 'Invoke-OneFixedRun'
    $compare = Get-FunctionSource -Analysis $analysis -Name 'Compare-FixedRunProofs'
    -not [string]::IsNullOrWhiteSpace($oneRun) -and
        -not [string]::IsNullOrWhiteSpace($invoke) -and
        -not [string]::IsNullOrWhiteSpace($compare) -and
        (Test-TokensInOrder -Source $oneRun -Needles @(
            "`$summaryEvidenceRole = Get-ExactValueNoEnumerate `$summary @('requested_evidence_role') `$null",
            '$summaryEvidenceRole -isnot [string]',
            "`$summaryEvidenceRole -cne 'fixed-repeat'",
            "`$summaryAdmission = Get-ExactValueNoEnumerate `$summary @('replay_admission') `$null",
            'Assert-FixedReplayAdmission -Admission $summaryAdmission',
            "`$runEvidenceRole = Get-ExactValueNoEnumerate `$run @('requested_evidence_role') `$null",
            '$runEvidenceRole -isnot [string]',
            "`$runEvidenceRole -cne 'fixed-repeat'",
            "`$runAdmission = Get-ExactValueNoEnumerate `$run @('replay_admission') `$null",
            'Assert-FixedReplayAdmission -Admission $runAdmission',
            'Assert-Rw062HeistPreflightAdmission',
            'evidence_role = $summaryEvidenceRole'
        )) -and
        $invoke.IndexOf("'-Ending', `$Ending, '-EvidenceRole', 'fixed-repeat', '-Seed', `$Seed, '-Repeat', '1'", [StringComparison]::Ordinal) -ge 0 -and
        $compare.IndexOf("`$value = Get-ExactValueNoEnumerate `$proof @([string]`$entry.Key) `$null", [StringComparison]::Ordinal) -ge 0 -and
        [regex]::IsMatch($compare, "(?s)\`$expectedIdentity\s*=\s*\[ordered\]@\{.*?evidence_role\s*=\s*'fixed-repeat'.*?ending\s*=\s*\`$Ending") -and
        $compare.IndexOf("evidence_role = 'fixed-repeat'", [StringComparison]::Ordinal) -ge 0
}
$exactPathValidator = {
    param($analysis)
    $oneRun = Get-FunctionSource -Analysis $analysis -Name 'Assert-OneRunEvidence'
    $bindings = [ordered]@{
        publishedTranscriptPath = '$transcriptPath'
        publishedMoneyPath = '$moneyPath'
        publishedCheckpointBeforePath = '$checkpointBeforePath'
        publishedCheckpointAfterPath = '$checkpointAfterPath'
    }
    foreach ($entry in $bindings.GetEnumerator()) {
        $propertyName = switch ([string]$entry.Key) {
            'publishedTranscriptPath' { 'transcript' }
            'publishedMoneyPath' { 'money_curve' }
            'publishedCheckpointBeforePath' { 'persistence_checkpoint_before' }
            'publishedCheckpointAfterPath' { 'persistence_checkpoint_after' }
        }
        $assignment = '$' + [string]$entry.Key + ' = Get-ExactValueNoEnumerate $run @(''' + $propertyName + ''') $null'
        if ($oneRun.IndexOf($assignment, [StringComparison]::Ordinal) -lt 0) { return $false }
        $pattern = '(?s)Assert-ExactPublishedPath\s+`?\s*-PublishedPath\s+\$' +
            [regex]::Escape([string]$entry.Key) + '\s+`?\s*-ExpectedPath\s+' +
            [regex]::Escape([string]$entry.Value)
        if (-not [regex]::IsMatch($oneRun, $pattern)) { return $false }
    }
    return ([regex]::Matches($oneRun, 'Assert-ExactPublishedPath')).Count -ge 5
}
$profileArtifactValidator = {
    param($analysis)
    $oneRun = Get-FunctionSource -Analysis $analysis -Name 'Assert-OneRunEvidence'
    $manifest = Get-FunctionSource -Analysis $analysis -Name 'Get-ManifestArtifactPaths'
    (Test-TokensInOrder -Source $oneRun -Needles @(
        'Godot\app_userdata\Beat the House\agent_playtest\$session',
        "'profile_inventory.json'",
        "'saves\foundation_ui_autosave.json'",
        '(Get-Item -LiteralPath $profileArtifact).Length -le 0',
        '$profileInventoryHash = Get-Sha256',
        '$autosaveHash = Get-Sha256'
    )) -and
        $manifest.IndexOf('@([string]$proof.profile_inventory, [string]$proof.autosave)', [StringComparison]::Ordinal) -ge 0
}
$survivorCustodyValidator = {
    param($analysis)
    $topLevel = Get-ExecutableTopLevelSource -Analysis $analysis
    $transfer = Get-FunctionSource -Analysis $analysis -Name 'Set-ExclusiveLeaseSurvivorCustody'
    $verify = Get-FunctionSource -Analysis $analysis -Name 'Test-ExclusiveSurvivorCustody'
    -not [string]::IsNullOrWhiteSpace($transfer) -and
        (Test-TokensInOrder -Source $transfer -Needles @(
            'if (-not (Test-OwnedExclusiveLease))',
            '$transferAttempted = $false',
            'while ($true)',
            '$livePids = @(Get-LiveSurvivorPids -Survivors $Survivors)',
            'while (Test-Path -LiteralPath $LeasePath)',
            'catch { Start-Sleep -Milliseconds 200 }',
            'pid = [int]$livePids[0]',
            'guard_pids = @($livePids)',
            '[IO.File]::Replace($temporaryLeasePath, $LeasePath, $null)',
            '$atomicReplaceFailed = $true',
            '[IO.FileMode]::Create',
            '$fallbackStream.Flush($true)',
            '$verifiedLivePids = @(Get-LiveSurvivorPids -Survivors $Survivors)',
            'Test-ExclusiveSurvivorCustody -ExpectedLivePids $verifiedLivePids',
            'Start-Sleep -Milliseconds 200'
        )) -and
        (Test-TokensInOrder -Source $verify -Needles @(
            '$ownerPid -cnotin $expected',
            'Get-Process -Id $ownerPid',
            '$guardPids.Count -ne $expected.Count',
            '$guardPids[$index] -ne $expected[$index]',
            'Get-Process -Id $guardPids[$index]'
        )) -and
        (Test-TokensInOrder -Source $topLevel -Needles @(
            'if ($ownedSurvivors.Count -ne 0 -or $globalGodotSurvivors.Count -ne 0)',
            '$custodyResult = Set-ExclusiveLeaseSurvivorCustody -Survivors $survivorCustody',
            '$script:LeaseOwned = $false',
            'Add-TerminalFailure -Failure "Replay/Godot processes survived teardown'
        ))
}
$manifestOrderValidator = {
    param($analysis)
    $topLevel = Get-ExecutableTopLevelSource -Analysis $analysis
    $manifestPaths = Get-FunctionSource -Analysis $analysis -Name 'Get-ManifestArtifactPaths'
    (Test-UniqueTokensInOrder -Source $topLevel -Needles @(
        '$aggregateSummaryJson = $aggregateSummary | Microsoft.PowerShell.Utility\ConvertTo-Json',
        '$metadataJson = $metadata | Microsoft.PowerShell.Utility\ConvertTo-Json',
        '$artifactRows = @(Get-ManifestArtifactPaths',
        '$manifestJson = $manifest | Microsoft.PowerShell.Utility\ConvertTo-Json',
        '$finalRetainedManifest = ConvertFrom-ExactJsonObjectText',
        '-ArtifactRows (Get-ExactValueNoEnumerate $finalRetainedManifest',
        '$finalRecomputedCanonicalProof = Compare-FixedRunProofs -Proofs @($script:RunProofs)',
        '$manifestSha256 = Get-Sha256 -Path $ManifestPath',
        'manifest_sha256 = $manifestSha256'
    )) -and
        $topLevel.IndexOf('$requiredManifestArtifacts', [StringComparison]::Ordinal) -ge 0 -and
        $topLevel.IndexOf('Evidence artifact changed during manifest finalization', [StringComparison]::Ordinal) -ge 0 -and
        (Test-TokensInOrder -Source $manifestPaths -Needles @(
            '[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)',
            '[Collections.Generic.List[string]]::new()',
            '$canonicalPath = [IO.Path]::GetFullPath([string]$path)',
            'if ($seenPaths.Add($canonicalPath))', '$uniquePaths.Add($canonicalPath)',
            '$orderedPaths = $uniquePaths.ToArray()',
            '[Array]::Sort($orderedPaths, [StringComparer]::OrdinalIgnoreCase)',
            'return @($orderedPaths)'
        )) -and
        $manifestPaths.IndexOf('Sort-Object', [StringComparison]::OrdinalIgnoreCase) -lt 0
}
$aggregateSummaryValidator = {
    param($analysis)
    Test-ExactTopLevelOrderedHashtableValues -Analysis $analysis -VariableName 'aggregateSummary' -Expected ([ordered]@{
        schema_version = '1'
        check_id = "'rw06_2_final_evidence'"
        role = "'fixed_route_repeat'"
        evidence_role = "'fixed-repeat'"
        ending = '$Ending'
        seed = '$Seed'
        repeat = '2'
        outcome = '$script:Outcome'
        error = 'Get-FailureMessage -Failure $script:TerminalError'
        expected_head = '$ExpectedHead.ToLowerInvariant()'
        expected_tree = '$ExpectedTree.ToLowerInvariant()'
        observed_head = '$script:FinalHead'
        observed_tree = '$script:FinalTree'
        independent_profiles = 'if ($null -ne $script:CanonicalProof) { $script:CanonicalProof.isolated_profiles } else { $false }'
        fresh_interactive_authorized = '$false'
        q017_status = "if (`$Ending -ceq 'heist') { 'ANSWERED_SEPARATE_FRESH_INTERACTIVE_SCOPE' } else { 'NOT_APPLICABLE' }"
        deterministic = 'if ($null -ne $script:CanonicalProof) { $script:CanonicalProof.deterministic } else { $false }'
        fixed_repeat_qualifying = '$fixedRepeatQualifying'
        source_custody_complete = '$script:SourceCustodyComplete'
        source_custody_pre_sha256 = '$script:SourceCustodyPreSha256'
        source_custody_final_sha256 = '$script:SourceCustodyFinalSha256'
        canonical_proof = '$script:CanonicalProof'
        runs = '@($script:RunProofs)'
        evidence_root = '$EvidenceRoot'
    })
}
$metadataLabelValidator = {
    param($analysis)
    Test-ExactTopLevelOrderedHashtableValues -Analysis $analysis -VariableName 'metadata' -Expected ([ordered]@{
        lane = "'rw06_2p'"
        kind = "'exclusive-real-input-fixed-repeat-final-evidence'"
        ending = '$Ending'
        seed = '$Seed'
        role = "'fixed_route_repeat'"
        evidence_role = "'fixed-repeat'"
        outcome = '$script:Outcome'
        error = 'Get-FailureMessage -Failure $script:TerminalError'
        expected_head = '$ExpectedHead.ToLowerInvariant()'
        expected_tree = '$ExpectedTree.ToLowerInvariant()'
        observed_head = '$script:FinalHead'
        observed_tree = '$script:FinalTree'
        launcher_snapshot = '$LauncherSnapshotPath'
        launcher_initial_sha256 = '$script:LauncherInitialSha256'
        launcher_current_sha256 = '$script:LauncherCurrentSha256'
        source_custody_pre = '$SourceCustodyPrePath'
        source_custody_pre_sha256 = '$script:SourceCustodyPreSha256'
        source_custody_final = '$SourceCustodyFinalPath'
        source_custody_final_sha256 = '$script:SourceCustodyFinalSha256'
        source_custody_complete = '$script:SourceCustodyComplete'
        initial_process_census = '$script:InitialProcessCensus'
        final_process_census = '$script:FinalProcessCensus'
        owned_processes_remaining = '@(Get-OwnedSurvivors)'
        lease_path = '$LeasePath'
        lease_removed = '-not (Test-Path -LiteralPath $LeasePath)'
        fixed_repeat_qualifying = '$fixedRepeatQualifying'
        started = "`$StartedAt.ToString('o')"
        completed = "[DateTimeOffset]::Now.ToString('o')"
    })
}
$manifestLabelValidator = {
    param($analysis)
    Test-ExactTopLevelOrderedHashtableValues -Analysis $analysis -VariableName 'manifest' -Expected ([ordered]@{
        schema_version = '1'
        check_id = "'rw06_2_final_evidence_manifest'"
        role = "'fixed_route_repeat'"
        evidence_role = "'fixed-repeat'"
        ending = '$Ending'
        seed = '$Seed'
        fixed_repeat_qualifying = '$fixedRepeatQualifying'
        evidence_root = '$EvidenceRoot'
        artifact_count = '$artifactRows.Count'
        artifacts = '$artifactRows'
    })
}
$resultValidator = {
    param($analysis)
    Test-ExactTopLevelOrderedHashtableValues -Analysis $analysis -VariableName 'result' -Expected ([ordered]@{
        evidence_root = '$EvidenceRoot'
        outcome = '$script:Outcome'
        fixed_repeat_qualifying = '$fixedRepeatQualifying'
        head = '$script:FinalHead'
        tree = '$script:FinalTree'
        aggregate_summary_sha256 = '$aggregateSummarySha256'
        metadata_sha256 = '$metadataSha256'
        manifest_sha256 = '$manifestSha256'
        source_custody_pre_sha256 = '$script:SourceCustodyPreSha256'
        source_custody_final_sha256 = '$script:SourceCustodyFinalSha256'
    })
}
$terminalSchemaValidator = {
    param($analysis)
    if (-not (& $immutableLauncherValidator $analysis)) {
        return $false
    }
    if (-not (Test-ExactDirectStatementTailIdentity `
        -ScopeAst $analysis.ast `
        -StartVariableName 'fixedRepeatQualifying' `
        -ExpectedStatementCount 62 `
        -ExpectedSha256 '09118283E5CABA03EEEF48A2CEEA139C4D962C02F133038AC7935823B9804C51')) {
        return $false
    }
    $recordKeys = Get-FunctionSource -Analysis $analysis -Name 'Assert-TerminalRecordKeys'
    $aggregate = Get-FunctionSource -Analysis $analysis -Name 'Assert-TerminalAggregateShape'
    $metadata = Get-FunctionSource -Analysis $analysis -Name 'Assert-TerminalMetadataShape'
    $artifactRow = Get-FunctionSource -Analysis $analysis -Name 'Assert-TerminalArtifactRowShape'
    $processRow = Get-FunctionSource -Analysis $analysis -Name 'Assert-TerminalProcessCensusRowShape'
    $survivorRow = Get-FunctionSource -Analysis $analysis -Name 'Assert-TerminalSurvivorRowShape'
    $manifest = Get-FunctionSource -Analysis $analysis -Name 'Assert-TerminalManifestShape'
    $result = Get-FunctionSource -Analysis $analysis -Name 'Assert-TerminalResultShape'
    foreach ($source in @($recordKeys, $aggregate, $metadata, $artifactRow, $processRow, $survivorRow, $manifest, $result)) {
        if ([string]::IsNullOrWhiteSpace($source)) { return $false }
    }
    $protectedFunctions = @(
        'Assert-TerminalRecordKeys', 'Assert-TerminalAggregateShape', 'Assert-TerminalMetadataShape',
        'Assert-TerminalArtifactRowShape', 'Assert-TerminalProcessCensusRowShape',
        'Assert-TerminalSurvivorRowShape', 'Assert-TerminalManifestShape', 'Assert-TerminalResultShape',
        'Compare-FixedRunProofs', 'Assert-FixedRunManifestArtifactBindings', 'Assert-ManifestArtifactHash'
    )
    $expectedFunctionInventory = @(
        'Get-FailureMessage', 'Add-TerminalFailure', 'Get-ExactValue', 'Get-ExactValueNoEnumerate',
        'Test-ExactStringArray', 'Get-ExactPositivePid', 'Get-ExactPidArray', 'Assert-FixedReplayAdmission',
        'Get-GitValue', 'Get-Sha256', 'Test-ExactPsCustomObject', 'Assert-LocalExactPropertyNames',
        'ConvertFrom-ExactJsonObjectText', 'ConvertTo-CanonicalExactObjectJson',
        'Get-CanonicalExactObjectSha256', 'Get-HeldFileDigests', 'Get-HeldUtf8Text',
        'New-LockedJsonReceipt', 'Get-TrackedSourceDescriptors', 'Assert-SourceCustodyRowSchema',
        'Assert-SourceCustodyRowMatches', 'Assert-SourceCustodyReceiptSchema',
        'Assert-RepositoryBlobIdentity', 'Get-ValidatedReplayToolPath', 'Assert-SourceCustody',
        'Open-SourceCustodyHandle', 'New-SourceCustody', 'Complete-SourceCustody', 'Close-SourceCustody',
        'Assert-RepositoryIdentity', 'Get-GodotProcesses', 'Get-ProcessCensus', 'Get-LeaseOwnerPids',
        'Clear-StaleGodotLeases', 'Clear-StaleExclusiveLease', 'Enter-LaunchLock', 'Exit-LaunchLock',
        'Test-OwnedExclusiveLease', 'Assert-ExclusiveAdmission', 'Assert-OwnedExclusiveReservation',
        'Wait-ExclusiveDrain', 'New-OwnedExclusiveLease', 'Get-LiveSurvivorPids',
        'Test-LauncherCustodyLease', 'Test-ExclusiveSurvivorCustody', 'Set-ExclusiveLeaseSurvivorCustody',
        'Get-ExactOwnedReplayProcess', 'Get-OwnedGodotProcesses', 'Stop-UnregisteredReplayProcess',
        'Get-DescendantProcessIds', 'Stop-OwnedReplayIdentity', 'Stop-AllOwnedProcesses',
        'Get-OwnedSurvivors', 'Restore-ProcessEnvironmentValue', 'Assert-ExactPublishedPath',
        'Resolve-ExactSessionRoot', 'Assert-StrictSessionLogs', 'Assert-RetainedHeistPreflightArtifact',
        'Assert-OneRunJsonShapes', 'Assert-FinalCheckpointJsonShapes',
        'Assert-PersistenceCoreCheckpointShape', 'Assert-SaveContinueCheckpointJsonShape',
        'Assert-OneRunEvidence', 'Invoke-OneFixedRun', 'Assert-FixedRunProofShape',
        'Assert-CanonicalFixedProofShape', 'Compare-FixedRunProofs', 'Test-FixedRepeatQualification',
        'Assert-TerminalRecordKeys', 'Test-ExactLowerHexOrEmpty',
        'Assert-TerminalProcessCensusRowShape', 'Assert-TerminalSurvivorRowShape',
        'Assert-TerminalArtifactRowShape', 'Assert-TerminalAggregateShape',
        'Assert-TerminalMetadataShape', 'Assert-TerminalManifestShape', 'Assert-TerminalResultShape',
        'Get-ManifestArtifactPaths', 'Assert-ManifestArtifactHash', 'Assert-FixedRunManifestArtifactBindings'
    )
    if (-not (Test-ExactFunctionDefinitionInventory -Analysis $analysis -ExpectedNames $expectedFunctionInventory) -or
        -not (Test-NoAuthorityShadowing -Analysis $analysis -ProtectedFunctionNames $protectedFunctions)) {
        return $false
    }
    $authorityAmbientVariables = [ordered]@{
        'Assert-TerminalRecordKeys' = @()
        'Assert-TerminalAggregateShape' = @(
            'Ending', 'EvidenceRoot', 'ExpectedHead', 'ExpectedTree', 'fixedRepeatQualifying',
            'script:CanonicalProof', 'script:FinalHead', 'script:FinalTree', 'script:Outcome',
            'script:RunProofs', 'script:SourceCustodyComplete', 'script:SourceCustodyFinalSha256',
            'script:SourceCustodyPreSha256', 'script:TerminalError', 'Seed'
        )
        'Assert-TerminalMetadataShape' = @(
            'Ending', 'ExpectedHead', 'ExpectedTree', 'fixedRepeatQualifying', 'LauncherSnapshotPath',
            'LeasePath', 'script:FinalHead', 'script:FinalTree', 'script:LauncherCurrentSha256',
            'script:LauncherInitialSha256', 'script:Outcome', 'script:SourceCustodyComplete',
            'script:SourceCustodyFinalSha256', 'script:SourceCustodyPreSha256', 'script:TerminalError',
            'Seed', 'SourceCustodyFinalPath', 'SourceCustodyPrePath'
        )
        'Assert-TerminalArtifactRowShape' = @()
        'Assert-TerminalProcessCensusRowShape' = @()
        'Assert-TerminalSurvivorRowShape' = @()
        'Assert-TerminalManifestShape' = @('Ending', 'EvidenceRoot', 'fixedRepeatQualifying', 'Seed')
        'Assert-TerminalResultShape' = @(
            'EvidenceRoot', 'ExpectedHead', 'ExpectedTree', 'fixedRepeatQualifying',
            'script:FinalHead', 'script:FinalTree', 'script:Outcome',
            'script:SourceCustodyFinalSha256', 'script:SourceCustodyPreSha256'
        )
    }
    foreach ($functionName in @($authorityAmbientVariables.Keys)) {
        $functionAst = Get-UniqueFunctionAst -Analysis $analysis -Name $functionName
        if ($null -eq $functionAst -or
            -not (Test-NoVariableControlledBypass -FunctionAst $functionAst -VariableName 'Label') -or
            -not (Test-ClosedFunctionVariables `
                -FunctionAst $functionAst `
                -AllowedAmbientVariables @($authorityAmbientVariables[$functionName]))) {
            return $false
        }
    }
    if (-not (Test-TokensInOrder -Source $recordKeys -Needles @(
        "'System.Collections.Specialized.OrderedDictionary'", 'Test-ExactPsCustomObject',
        '$actual.Count -ne $Expected.Count', '$actual[$index] -cne $Expected[$index]'
    ))) { return $false }
    if (-not (Test-TokensInOrder -Source $aggregate -Needles @(
        'Assert-TerminalRecordKeys', "'schema_version', 'check_id', 'role', 'evidence_role'",
        "'canonical_proof', 'runs', 'evidence_root'", '$schemaVersion -isnot [int32]',
        '$independentProfiles -isnot [bool]', '$qualifying -isnot [bool]', '$runs -isnot [object[]]',
        'Assert-CanonicalFixedProofShape', 'Assert-FixedRunProofShape'
    ))) { return $false }
    if (-not (Test-TokensInOrder -Source $metadata -Needles @(
        'Assert-TerminalRecordKeys', "'initial_process_census', 'final_process_census'",
        '$custodyComplete -isnot [bool]', '$initialCensus -isnot [object[]]',
        'Assert-TerminalProcessCensusRowShape', 'Assert-TerminalSurvivorRowShape',
        '$initialCensus.Count -ne 0', '$finalCensus.Count -ne 0'
    ))) { return $false }
    if (-not (Test-TokensInOrder -Source $artifactRow -Needles @(
        "-Expected @('path', 'sha256')", '$path -isnot [string]', '[IO.Path]::IsPathRooted($path)',
        "`$sha256 -cnotmatch '^[a-f0-9]{64}$'"
    ))) { return $false }
    if (-not (Test-TokensInOrder -Source $processRow -Needles @(
        "-Expected @('pid', 'parent_pid', 'name', 'command_line')", '$pidValue -isnot [int32]',
        '$parentPid -isnot [int32]', '$name -isnot [string]', '$commandLine -isnot [string]'
    ))) { return $false }
    if (-not (Test-TokensInOrder -Source $survivorRow -Needles @(
        "`$kind -ceq 'godot'", "'unverified_replay_pid'", 'Assert-TerminalRecordKeys',
        '$pidValue -isnot [int32]', '$sessionPrefix -isnot [string]'
    ))) { return $false }
    if (-not (Test-TokensInOrder -Source $manifest -Needles @(
        'Assert-TerminalRecordKeys', "'artifact_count', 'artifacts'", '$artifactCount -isnot [int32]',
        '$artifacts -isnot [object[]]', 'Assert-TerminalArtifactRowShape',
        '[StringComparison]::OrdinalIgnoreCase', '$qualifying -and $artifacts.Count -eq 0'
    ))) { return $false }
    if (-not (Test-TokensInOrder -Source $result -Needles @(
        'Assert-TerminalRecordKeys', "'aggregate_summary_sha256', 'metadata_sha256', 'manifest_sha256'",
        '$qualifying -isnot [bool]', '$ExpectedAggregateSha256 -isnot [string]',
        "`$ExpectedAggregateSha256 -cnotmatch '^[a-f0-9]{64}$'",
        '$ExpectedMetadataSha256 -isnot [string]',
        "`$ExpectedMetadataSha256 -cnotmatch '^[a-f0-9]{64}$'",
        '$ExpectedManifestSha256 -isnot [string]',
        "`$ExpectedManifestSha256 -cnotmatch '^[a-f0-9]{64}$'",
        '$aggregateHash -isnot [string]', '$aggregateHash -cne $ExpectedAggregateSha256',
        '$metadataHash -isnot [string]', '$metadataHash -cne $ExpectedMetadataSha256',
        '$manifestHash -isnot [string]', '$manifestHash -cne $ExpectedManifestSha256'
    ))) { return $false }
    if (-not (Test-ExactDirectCommandSignatures -ScopeAst $analysis.ast -CommandName 'Assert-TerminalAggregateShape' -ExpectedSignatures @(
        [ordered]@{ Record = '$aggregateSummary'; Representation = 'ordered'; Label = "'In-memory aggregate summary'" },
        [ordered]@{ Record = '$expectedAggregateSummary'; Representation = 'json'; Label = "'Serialized aggregate summary'" },
        [ordered]@{ Record = '$retainedAggregateSummary'; Representation = 'json'; Label = "'Retained aggregate summary'" }
    ))) { return $false }
    if (-not (Test-ExactDirectCommandSignatures -ScopeAst $analysis.ast -CommandName 'Assert-TerminalMetadataShape' -ExpectedSignatures @(
        [ordered]@{ Record = '$metadata'; Representation = 'ordered'; Label = "'In-memory run metadata'" },
        [ordered]@{ Record = '$expectedMetadata'; Representation = 'json'; Label = "'Serialized run metadata'" },
        [ordered]@{ Record = '$retainedMetadata'; Representation = 'json'; Label = "'Retained run metadata'" }
    ))) { return $false }
    if (-not (Test-ExactDirectCommandSignatures -ScopeAst $analysis.ast -CommandName 'Assert-TerminalManifestShape' -ExpectedSignatures @(
        [ordered]@{ Record = '$manifest'; Representation = 'ordered'; Label = "'In-memory artifact manifest'" },
        [ordered]@{ Record = '$expectedManifest'; Representation = 'json'; Label = "'Serialized artifact manifest'" },
        [ordered]@{ Record = '$retainedManifest'; Representation = 'json'; Label = "'Retained artifact manifest'" },
        [ordered]@{ Record = '$finalRetainedManifest'; Representation = 'json'; Label = "'Final retained artifact manifest rebind'" }
    ))) { return $false }
    if (-not (Test-ExactDirectCommandSignatures -ScopeAst $analysis.ast -CommandName 'Assert-TerminalResultShape' -ExpectedSignatures @(
        [ordered]@{
            Record = '$result'; Representation = 'ordered'
            ExpectedAggregateSha256 = '$aggregateSummarySha256'; ExpectedMetadataSha256 = '$metadataSha256'
            ExpectedManifestSha256 = '$manifestSha256'; Label = "'In-memory terminal stdout result'"
        },
        [ordered]@{
            Record = '$retainedResult'; Representation = 'json'
            ExpectedAggregateSha256 = '$aggregateSummarySha256'; ExpectedMetadataSha256 = '$metadataSha256'
            ExpectedManifestSha256 = '$manifestSha256'; Label = "'Terminal stdout result'"
        }
    ))) { return $false }

    $aggregateEquality = @'
if ((ConvertTo-CanonicalExactObjectJson -InputObject $retainedAggregateSummary -Label 'Retained aggregate summary') -cne
    (ConvertTo-CanonicalExactObjectJson -InputObject $expectedAggregateSummary -Label 'Serialized aggregate summary')) {
    throw 'Retained aggregate summary differs from its exact in-memory serialization.'
}
'@
    $metadataEquality = @'
if ((ConvertTo-CanonicalExactObjectJson -InputObject $retainedMetadata -Label 'Retained run metadata') -cne
    (ConvertTo-CanonicalExactObjectJson -InputObject $expectedMetadata -Label 'Serialized run metadata')) {
    throw 'Retained run metadata differs from its exact in-memory serialization.'
}
'@
    $manifestEquality = @'
if ((ConvertTo-CanonicalExactObjectJson -InputObject $retainedManifest -Label 'Retained artifact manifest') -cne
    (ConvertTo-CanonicalExactObjectJson -InputObject $expectedManifest -Label 'Serialized artifact manifest')) {
    throw 'Retained artifact manifest differs from its exact in-memory serialization.'
}
'@
    foreach ($statement in @($aggregateEquality, $metadataEquality, $manifestEquality)) {
        if (-not (Test-ExactDirectStatementText -ScopeAst $analysis.ast -ExpectedText $statement)) { return $false }
    }
    $aggregateReadback = @'
$retainedAggregateSummary = ConvertFrom-ExactJsonObjectText `
    -Json (Microsoft.PowerShell.Management\Get-Content -Raw -LiteralPath $AggregateSummaryPath -Encoding utf8) `
    -Label 'Retained aggregate summary'
'@
    $metadataReadback = @'
$retainedMetadata = ConvertFrom-ExactJsonObjectText `
    -Json (Microsoft.PowerShell.Management\Get-Content -Raw -LiteralPath $MetadataPath -Encoding utf8) `
    -Label 'Retained run metadata'
'@
    $manifestReadback = @'
$retainedManifest = ConvertFrom-ExactJsonObjectText `
    -Json (Microsoft.PowerShell.Management\Get-Content -Raw -LiteralPath $ManifestPath -Encoding utf8) `
    -Label 'Retained artifact manifest'
'@
    $inMemoryResultValidation = @'
Assert-TerminalResultShape `
    -Record $result `
    -Representation ordered `
    -ExpectedAggregateSha256 $aggregateSummarySha256 `
    -ExpectedMetadataSha256 $metadataSha256 `
    -ExpectedManifestSha256 $manifestSha256 `
    -Label 'In-memory terminal stdout result'
'@
    $retainedResultReadback = @'
$retainedResult = ConvertFrom-ExactJsonObjectText `
    -Json (Microsoft.PowerShell.Utility\ConvertTo-Json -InputObject $result -Depth 8) `
    -Label 'Terminal stdout result'
'@
    $retainedResultValidation = @'
Assert-TerminalResultShape `
    -Record $retainedResult `
    -Representation json `
    -ExpectedAggregateSha256 $aggregateSummarySha256 `
    -ExpectedMetadataSha256 $metadataSha256 `
    -ExpectedManifestSha256 $manifestSha256 `
    -Label 'Terminal stdout result'
'@
    $sealedArtifactRehash = @'
foreach ($sealedArtifactRow in $finalRetainedManifest.artifacts) {
    $sealedArtifactPath = $sealedArtifactRow.path
    $sealedExpectedSha256 = $sealedArtifactRow.sha256
    if ($sealedArtifactPath -isnot [string] -or
        -not [IO.Path]::IsPathRooted($sealedArtifactPath) -or
        [IO.Path]::GetFullPath($sealedArtifactPath) -cne $sealedArtifactPath -or
        $sealedExpectedSha256 -isnot [string] -or
        $sealedExpectedSha256 -cnotmatch '^[a-f0-9]{64}$') {
        throw 'Sealed terminal artifact authority is not one exact canonical path/hash row.'
    }
    $sealedObservedSha256 = (Microsoft.PowerShell.Utility\Get-FileHash `
        -LiteralPath $sealedArtifactPath `
        -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($sealedObservedSha256 -cne $sealedExpectedSha256) {
        throw "Evidence artifact changed before sealed terminal output: $sealedArtifactPath"
    }
}
'@
    $sealedManifestRehash = @'
$sealedManifestSha256 = (Microsoft.PowerShell.Utility\Get-FileHash `
    -LiteralPath $ManifestPath `
    -Algorithm SHA256).Hash.ToLowerInvariant()
'@
    $sealedManifestBinding = @'
if ($sealedManifestSha256 -cne $manifestSha256 -or
    $retainedResult.manifest_sha256 -isnot [string] -or
    $retainedResult.manifest_sha256 -cne $sealedManifestSha256) {
    throw 'Retained manifest authority changed before sealed terminal output.'
}
'@
    if (-not (Test-ExactDirectStatementsInOrder -ScopeAst $analysis.ast -ExpectedTexts @(
        "Assert-TerminalAggregateShape -Record `$aggregateSummary -Representation ordered -Label 'In-memory aggregate summary'",
        '$aggregateSummaryJson = $aggregateSummary | Microsoft.PowerShell.Utility\ConvertTo-Json -Depth 20',
        "`$expectedAggregateSummary = ConvertFrom-ExactJsonObjectText -Json `$aggregateSummaryJson -Label 'Serialized aggregate summary'",
        "Assert-TerminalAggregateShape -Record `$expectedAggregateSummary -Representation json -Label 'Serialized aggregate summary'",
        '$aggregateSummaryJson | Microsoft.PowerShell.Management\Set-Content -LiteralPath $AggregateSummaryPath -Encoding utf8',
        $aggregateReadback,
        "Assert-TerminalAggregateShape -Record `$retainedAggregateSummary -Representation json -Label 'Retained aggregate summary'",
        $aggregateEquality,
        "Assert-TerminalMetadataShape -Record `$metadata -Representation ordered -Label 'In-memory run metadata'",
        '$metadataJson = $metadata | Microsoft.PowerShell.Utility\ConvertTo-Json -Depth 20',
        "`$expectedMetadata = ConvertFrom-ExactJsonObjectText -Json `$metadataJson -Label 'Serialized run metadata'",
        "Assert-TerminalMetadataShape -Record `$expectedMetadata -Representation json -Label 'Serialized run metadata'",
        '$metadataJson | Microsoft.PowerShell.Management\Set-Content -LiteralPath $MetadataPath -Encoding utf8',
        $metadataReadback,
        "Assert-TerminalMetadataShape -Record `$retainedMetadata -Representation json -Label 'Retained run metadata'",
        $metadataEquality,
        "Assert-TerminalManifestShape -Record `$manifest -Representation ordered -Label 'In-memory artifact manifest'",
        '$manifestJson = $manifest | Microsoft.PowerShell.Utility\ConvertTo-Json -Depth 10',
        "`$expectedManifest = ConvertFrom-ExactJsonObjectText -Json `$manifestJson -Label 'Serialized artifact manifest'",
        "Assert-TerminalManifestShape -Record `$expectedManifest -Representation json -Label 'Serialized artifact manifest'",
        '$manifestJson | Microsoft.PowerShell.Management\Set-Content -LiteralPath $ManifestPath -Encoding utf8',
        $manifestReadback,
        "Assert-TerminalManifestShape -Record `$retainedManifest -Representation json -Label 'Retained artifact manifest'",
        $manifestEquality,
        $inMemoryResultValidation,
        $retainedResultReadback,
        $retainedResultValidation,
        $sealedArtifactRehash,
        $sealedManifestRehash,
        $sealedManifestBinding,
        'if ($null -ne $script:TerminalError) { throw $script:TerminalError }',
        'Microsoft.PowerShell.Utility\ConvertTo-Json -InputObject $retainedResult -Depth 8'
    ))) { return $false }
    if (-not (Test-ExactTrailingDirectStatements -ScopeAst $analysis.ast -ExpectedTexts @(
        $sealedArtifactRehash,
        $sealedManifestRehash,
        $sealedManifestBinding,
        'if ($null -ne $script:TerminalError) { throw $script:TerminalError }',
        'Microsoft.PowerShell.Utility\ConvertTo-Json -InputObject $retainedResult -Depth 8'
    ))) { return $false }
    $plainCriticalCommands = @($analysis.ast.FindAll({
        param($node)
        $node -is [Management.Automation.Language.CommandAst] -and
            $node.GetCommandName() -in @(
                'Start-Process', 'Get-Content', 'Set-Content', 'Get-FileHash',
                'ConvertTo-Json', 'ConvertFrom-Json'
            )
    }, $true))
    $terminalWrites = @($analysis.ast.FindAll({
        param($node)
        $node -is [Management.Automation.Language.CommandAst] -and
            $node.GetCommandName() -ceq 'Microsoft.PowerShell.Management\Set-Content'
    }, $true))
    if ($plainCriticalCommands.Count -ne 0 -or $terminalWrites.Count -ne 3) { return $false }
    $topLevel = Get-ExecutableTopLevelSource -Analysis $analysis
    return $topLevel -notmatch '(?m)^\s*(?:independent_profiles|deterministic|fixed_repeat_qualifying|source_custody_complete)\s*=\s*\[bool\]'
}
$manifestProofBindingValidator = {
    param($analysis)
    if (-not (Test-ExactFunctionStructuralHashes -Analysis $analysis -ExpectedHashes $expectedLauncherFunctionHashes)) {
        return $false
    }
    $manifestHashFunction = Get-UniqueFunctionAst -Analysis $analysis -Name 'Assert-ManifestArtifactHash'
    $expectedManifestHashFunction = @'
function Assert-ManifestArtifactHash {
    param(
        [Parameter(Mandatory = $true)]$ArtifactRows,
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]$ExpectedSha256,
        [Parameter(Mandatory = $true)][string]$Label
    )
    if ($ArtifactRows -isnot [object[]]) {
        throw "$Label artifact rows are not one exact Object[]."
    }
    if ($ExpectedSha256 -isnot [string] -or $ExpectedSha256 -cnotmatch '^[a-f0-9]{64}$') {
        throw "$Label expected SHA-256 is not one exact hash."
    }
    $expectedPath = [IO.Path]::GetFullPath($Path)
    $matches = @($ArtifactRows | Where-Object {
        $candidatePath = Get-ExactValueNoEnumerate $_ @('path') $null
        $candidatePath -is [string] -and
            ([IO.Path]::GetFullPath($candidatePath)).Equals($expectedPath, [StringComparison]::OrdinalIgnoreCase)
    })
    if ($matches.Count -ne 1) {
        throw "$Label does not have one exact aggregate manifest row."
    }
    $manifestHash = Get-ExactValueNoEnumerate $matches[0] @('sha256') $null
    if ($manifestHash -isnot [string] -or $manifestHash -cne $ExpectedSha256) {
        throw "$Label aggregate manifest hash differs from its authenticated proof hash."
    }
}
'@
    if ($null -eq $manifestHashFunction -or
        (ConvertTo-ExactStructuralSourceText -Text ([string]$manifestHashFunction.Extent.Text)) -cne
            (ConvertTo-ExactStructuralSourceText -Text $expectedManifestHashFunction) -or
        -not (Test-ClosedFunctionVariables -FunctionAst $manifestHashFunction)) {
        return $false
    }
    if (-not (Test-ExactDirectCommandSignatures `
        -ScopeAst $analysis.ast `
        -CommandName 'Assert-ManifestArtifactHash' `
        -ExpectedSignatures @(
            [ordered]@{ ArtifactRows = '$artifactRows'; Path = '$LauncherSnapshotPath'; ExpectedSha256 = '$script:LauncherInitialSha256'; Label = "'Immutable launcher snapshot'" },
            [ordered]@{ ArtifactRows = '$artifactRows'; Path = '$SourceCustodyPrePath'; ExpectedSha256 = '$script:SourceCustodyPreSha256'; Label = "'Source custody pre-execution receipt'" },
            [ordered]@{ ArtifactRows = '$artifactRows'; Path = '$SourceCustodyFinalPath'; ExpectedSha256 = '$script:SourceCustodyFinalSha256'; Label = "'Source custody final receipt'" },
            [ordered]@{ ArtifactRows = '$artifactRows'; Path = '$AggregateSummaryPath'; ExpectedSha256 = '$aggregateSummarySha256'; Label = "'Aggregate summary'" },
            [ordered]@{ ArtifactRows = '$artifactRows'; Path = '$MetadataPath'; ExpectedSha256 = '$metadataSha256'; Label = "'Run metadata'" }
        ) `
        -ExpectedTotalCount 20)) {
        return $false
    }
    $bindingFunction = Get-UniqueFunctionAst -Analysis $analysis -Name 'Assert-FixedRunManifestArtifactBindings'
    if ($null -eq $bindingFunction -or
        @($bindingFunction.FindAll({
            param($node)
            $node -is [Management.Automation.Language.AssignmentStatementAst] -or
                $node -is [Management.Automation.Language.ContinueStatementAst] -or
                $node -is [Management.Automation.Language.BreakStatementAst] -or
                $node -is [Management.Automation.Language.ReturnStatementAst] -or
                $node -is [Management.Automation.Language.ExitStatementAst] -or
                $node -is [Management.Automation.Language.TrapStatementAst]
        }, $true)).Count -ne 0) {
        return $false
    }
    if (-not (Test-ExactDirectCommandSignatures -ScopeAst $bindingFunction -CommandName 'Assert-FixedRunProofShape' -ExpectedSignatures @(
        [ordered]@{
            Proof = '$Proof'; ExpectedRunIndex = '$ExpectedRunIndex'
            Label = '"Run $ExpectedRunIndex manifest-binding proof"'
        }
    ))) { return $false }

    $bindingSpecs = @(
        [pscustomobject]@{ path = "(Get-ExactValueNoEnumerate `$Proof @('replay_summary') `$null)"; hash = "(Get-ExactValueNoEnumerate `$Proof @('replay_summary_sha256') `$null)"; label = '"Run $ExpectedRunIndex replay summary"' },
        [pscustomobject]@{ path = "(Get-ExactValueNoEnumerate `$Proof @('launcher_stdout') `$null)"; hash = "(Get-ExactValueNoEnumerate `$Proof @('launcher_stdout_sha256') `$null)"; label = '"Run $ExpectedRunIndex outer launcher stdout"' },
        [pscustomobject]@{ path = "(Get-ExactValueNoEnumerate `$Proof @('launcher_stderr') `$null)"; hash = "(Get-ExactValueNoEnumerate `$Proof @('launcher_stderr_sha256') `$null)"; label = '"Run $ExpectedRunIndex outer launcher stderr"' },
        [pscustomobject]@{ path = "(Get-ExactValueNoEnumerate `$Proof @('run_summary') `$null)"; hash = "(Get-ExactValueNoEnumerate `$Proof @('run_summary_sha256') `$null)"; label = '"Run $ExpectedRunIndex retained run summary"' },
        [pscustomobject]@{ path = "(Get-ExactValueNoEnumerate `$Proof @('profile_inventory') `$null)"; hash = "(Get-ExactValueNoEnumerate `$Proof @('profile_inventory_sha256') `$null)"; label = '"Run $ExpectedRunIndex profile inventory"' },
        [pscustomobject]@{ path = "(Get-ExactValueNoEnumerate `$Proof @('autosave') `$null)"; hash = "(Get-ExactValueNoEnumerate `$Proof @('autosave_sha256') `$null)"; label = '"Run $ExpectedRunIndex profile autosave"' },
        [pscustomobject]@{ path = "(Join-Path (Get-ExactValueNoEnumerate `$Proof @('run_root') `$null) 'public_trace.ndjson')"; hash = "(Get-ExactValueNoEnumerate `$Proof @('transcript_sha256') `$null)"; label = '"Run $ExpectedRunIndex public trace"' },
        [pscustomobject]@{ path = "(Join-Path (Get-ExactValueNoEnumerate `$Proof @('run_root') `$null) 'money_curve.ndjson')"; hash = "(Get-ExactValueNoEnumerate `$Proof @('money_curve_sha256') `$null)"; label = '"Run $ExpectedRunIndex money curve"' },
        [pscustomobject]@{ path = "(Join-Path (Get-ExactValueNoEnumerate `$Proof @('run_root') `$null) 'checkpoint_before.json')"; hash = "(Get-ExactValueNoEnumerate `$Proof @('persistence_checkpoint_before_sha256') `$null)"; label = '"Run $ExpectedRunIndex persistence checkpoint before"' },
        [pscustomobject]@{ path = "(Join-Path (Get-ExactValueNoEnumerate `$Proof @('run_root') `$null) 'checkpoint_after.json')"; hash = "(Get-ExactValueNoEnumerate `$Proof @('persistence_checkpoint_after_sha256') `$null)"; label = '"Run $ExpectedRunIndex persistence checkpoint after"' },
        [pscustomobject]@{ path = "(Join-Path (Get-ExactValueNoEnumerate `$Proof @('run_root') `$null) 'final_public_checkpoint.json')"; hash = "(Get-ExactValueNoEnumerate `$Proof @('final_public_checkpoint_sha256') `$null)"; label = '"Run $ExpectedRunIndex final public checkpoint"' },
        [pscustomobject]@{ path = "(Join-Path (Get-ExactValueNoEnumerate `$Proof @('session_root') `$null) 'godot.stdout.log')"; hash = "(Get-ExactValueNoEnumerate `$Proof @('godot_stdout_sha256') `$null)"; label = '"Run $ExpectedRunIndex Godot stdout"' },
        [pscustomobject]@{ path = "(Join-Path (Get-ExactValueNoEnumerate `$Proof @('session_root') `$null) 'godot.stderr.log')"; hash = "(Get-ExactValueNoEnumerate `$Proof @('godot_stderr_sha256') `$null)"; label = '"Run $ExpectedRunIndex Godot stderr"' },
        [pscustomobject]@{ path = "(Join-Path (Get-ExactValueNoEnumerate `$Proof @('session_root') `$null) 'godot.engine.log')"; hash = "(Get-ExactValueNoEnumerate `$Proof @('godot_engine_sha256') `$null)"; label = '"Run $ExpectedRunIndex Godot engine log"' }
    )
    $bindingSignatures = @($bindingSpecs | ForEach-Object {
        [ordered]@{
            ArtifactRows = '$ArtifactRows'; Path = $_.path
            ExpectedSha256 = $_.hash; Label = $_.label
        }
    })
    if (-not (Test-ExactDirectCommandSignatures `
        -ScopeAst $bindingFunction `
        -CommandName 'Assert-ManifestArtifactHash' `
        -ExpectedSignatures $bindingSignatures `
        -ExpectedTotalCount 15)) {
        return $false
    }
    $heistBinding = @'
if ($Ending -ceq 'heist') {
        Assert-ManifestArtifactHash -ArtifactRows $ArtifactRows `
            -Path (Get-ExactValueNoEnumerate $Proof @('heist_seed_preflight') $null) `
            -ExpectedSha256 (Get-ExactValueNoEnumerate $Proof @('heist_seed_preflight_sha256') $null) `
            -Label "Run $ExpectedRunIndex retained Heist seed preflight"
    }
'@
    if (-not (Test-ExactDirectStatementText -ScopeAst $bindingFunction -ExpectedText $heistBinding)) {
        return $false
    }

    $proofLoops = @($analysis.ast.EndBlock.Statements | Where-Object {
        $_ -is [Management.Automation.Language.ForStatementAst] -and
            @($_.FindAll({
                param($node)
                $node -is [Management.Automation.Language.CommandAst] -and
                    $node.GetCommandName() -ceq 'Assert-FixedRunManifestArtifactBindings'
            }, $true)).Count -eq 1
    })
    if ($proofLoops.Count -ne 2) { return $false }
    $initialProofLoops = @($proofLoops | Where-Object {
        @($_.FindAll({
            param($node)
            $node -is [Management.Automation.Language.AssignmentStatementAst] -and
                $node.Left -is [Management.Automation.Language.VariableExpressionAst] -and
                $node.Left.VariablePath.UserPath -ceq 'proof'
        }, $true)).Count -eq 1
    })
    $finalProofLoops = @($proofLoops | Where-Object {
        @($_.FindAll({
            param($node)
            $node -is [Management.Automation.Language.AssignmentStatementAst] -and
                $node.Left -is [Management.Automation.Language.VariableExpressionAst] -and
                $node.Left.VariablePath.UserPath -ceq 'proof'
        }, $true)).Count -eq 0
    })
    if ($initialProofLoops.Count -ne 1 -or $finalProofLoops.Count -ne 1) { return $false }
    $proofLoop = $initialProofLoops[0]
    if (@($proofLoop.FindAll({
        param($node)
        $node -is [Management.Automation.Language.ContinueStatementAst] -or
            $node -is [Management.Automation.Language.BreakStatementAst] -or
            $node -is [Management.Automation.Language.ReturnStatementAst] -or
            $node -is [Management.Automation.Language.ExitStatementAst] -or
            $node -is [Management.Automation.Language.TrapStatementAst]
    }, $true)).Count -ne 0) {
        return $false
    }
    $proofAssignments = @($proofLoop.FindAll({
        param($node)
        $node -is [Management.Automation.Language.AssignmentStatementAst] -and
            $node.Left -is [Management.Automation.Language.VariableExpressionAst] -and
            $node.Left.VariablePath.UserPath -ceq 'proof'
    }, $true))
    if ($proofAssignments.Count -ne 1 -or
        (ConvertTo-ExactStructuralSourceText -Text ([string]$proofAssignments[0].Right.Extent.Text)) -cne '$script:RunProofs[$proofOffset]' -or
        @($proofLoop.Body.Statements | Where-Object {
            $_.Extent.StartOffset -eq $proofAssignments[0].Extent.StartOffset -and
                $_.Extent.EndOffset -eq $proofAssignments[0].Extent.EndOffset
        }).Count -ne 1) {
        return $false
    }
    $proofMemberWrites = @($proofLoop.FindAll({
        param($node)
        ($node -is [Management.Automation.Language.AssignmentStatementAst] -and
            [string]$node.Left.Extent.Text -match '(?i)^\s*\$(?:proof|script:RunProofs)(?:\.|\[)') -or
        ($node -is [Management.Automation.Language.InvokeMemberExpressionAst] -and
            [string]$node.Expression.Extent.Text -match '(?i)^\s*\$(?:proof|script:RunProofs)(?:\.|\[)')
    }, $true))
    if ($proofMemberWrites.Count -ne 0) { return $false }
    $bindingCalls = @($proofLoop.FindAll({
        param($node)
        $node -is [Management.Automation.Language.CommandAst] -and
            $node.GetCommandName() -ceq 'Assert-FixedRunManifestArtifactBindings'
    }, $true))
    $proofLoopStatements = @($proofLoop.Body.Statements)
    if ($bindingCalls.Count -ne 1 -or
        $bindingCalls[0].Parent -isnot [Management.Automation.Language.PipelineAst] -or
        @($proofLoop.Body.Statements | Where-Object {
            $_.Extent.StartOffset -eq $bindingCalls[0].Parent.Extent.StartOffset -and
                $_.Extent.EndOffset -eq $bindingCalls[0].Parent.Extent.EndOffset
        }).Count -ne 1 -or
        $proofLoopStatements.Count -lt 2 -or
        $proofLoopStatements[0].Extent.StartOffset -ne $proofAssignments[0].Extent.StartOffset -or
        $proofLoopStatements[1].Extent.StartOffset -ne $bindingCalls[0].Parent.Extent.StartOffset -or
        -not (Test-ExactCommandArguments -CommandAst $bindingCalls[0] -ExpectedArguments ([ordered]@{
            ArtifactRows = '$artifactRows'; Proof = '$proof'; ExpectedRunIndex = '($proofOffset + 1)'
        }))) {
        return $false
    }
    $finalProofLoop = $finalProofLoops[0]
    if (@($finalProofLoop.Body.FindAll({
        param($node)
        $node -is [Management.Automation.Language.AssignmentStatementAst] -or
            $node -is [Management.Automation.Language.InvokeMemberExpressionAst] -or
            $node -is [Management.Automation.Language.ContinueStatementAst] -or
            $node -is [Management.Automation.Language.BreakStatementAst] -or
            $node -is [Management.Automation.Language.ReturnStatementAst] -or
            $node -is [Management.Automation.Language.ExitStatementAst] -or
            $node -is [Management.Automation.Language.TrapStatementAst]
    }, $true)).Count -ne 0) {
        return $false
    }
    $finalBindingCalls = @($finalProofLoop.FindAll({
        param($node)
        $node -is [Management.Automation.Language.CommandAst] -and
            $node.GetCommandName() -ceq 'Assert-FixedRunManifestArtifactBindings'
    }, $true))
    if ($finalBindingCalls.Count -ne 1 -or $finalProofLoop.Body.Statements.Count -ne 1 -or
        $finalBindingCalls[0].Parent -isnot [Management.Automation.Language.PipelineAst] -or
        $finalProofLoop.Body.Statements[0].Extent.StartOffset -ne $finalBindingCalls[0].Parent.Extent.StartOffset -or
        -not (Test-ExactCommandArguments -CommandAst $finalBindingCalls[0] -ExpectedArguments ([ordered]@{
            ArtifactRows = "(Get-ExactValueNoEnumerate `$finalRetainedManifest @('artifacts') `$null)"
            Proof = '$script:RunProofs[$proofOffset]'
            ExpectedRunIndex = '($proofOffset + 1)'
        }))) {
        return $false
    }
    $topLevel = Get-ExecutableTopLevelSource -Analysis $analysis
    return Test-TokensInOrder -Source $topLevel -Needles @(
        'Close-SourceCustody',
        '$finalRetainedManifest = ConvertFrom-ExactJsonObjectText',
        "-Label 'Final retained artifact manifest rebind'",
        'Assert-TerminalManifestShape',
        "throw 'Final retained artifact manifest differs from its exact serialized authority.'",
        '-ArtifactRows (Get-ExactValueNoEnumerate $finalRetainedManifest',
        '$finalRecomputedCanonicalProof = Compare-FixedRunProofs -Proofs @($script:RunProofs)',
        "throw 'Held canonical proof differs from the complete run-proof authority at final retained-manifest rebind.'",
        '$manifestSha256 = Get-Sha256 -Path $ManifestPath',
        'Assert-TerminalResultShape',
        'foreach ($sealedArtifactRow in $finalRetainedManifest.artifacts)',
        'Microsoft.PowerShell.Utility\Get-FileHash',
        '$sealedManifestSha256 = (Microsoft.PowerShell.Utility\Get-FileHash',
        '$retainedResult.manifest_sha256 -cne $sealedManifestSha256',
        'if ($null -ne $script:TerminalError) { throw $script:TerminalError }',
        'Microsoft.PowerShell.Utility\ConvertTo-Json -InputObject $retainedResult -Depth 8'
    )
}
$manifestClosureValidator = {
    param($analysis)
    $topLevel = Get-ExecutableTopLevelSource -Analysis $analysis
    Test-TokensInOrder -Source $topLevel -Needles @(
        '$requiredManifestArtifacts = [Collections.Generic.List[string]]::new()',
        '$requiredManifestArtifactKeys = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)',
        '$SourceCustodyPrePath, $SourceCustodyFinalPath',
        '$canonicalRequiredArtifact = [IO.Path]::GetFullPath($requiredArtifact)',
        '$requiredManifestArtifactKeys.Add($canonicalRequiredArtifact)',
        '$requiredManifestArtifacts.Add($canonicalRequiredArtifact)',
        'for ($proofOffset = 0; $proofOffset -lt $script:RunProofs.Count; $proofOffset++)',
        '$proof = $script:RunProofs[$proofOffset]',
        "(Get-ExactValueNoEnumerate `$proof @('replay_summary') `$null)",
        "(Get-ExactValueNoEnumerate `$proof @('launcher_stdout') `$null)",
        "(Get-ExactValueNoEnumerate `$proof @('launcher_stderr') `$null)",
        "(Get-ExactValueNoEnumerate `$proof @('run_summary') `$null)",
        "(Join-Path (Get-ExactValueNoEnumerate `$proof @('run_root') `$null) 'public_trace.ndjson')",
        "(Get-ExactValueNoEnumerate `$proof @('profile_inventory') `$null)",
        "(Get-ExactValueNoEnumerate `$proof @('autosave') `$null)",
        "(Join-Path (Get-ExactValueNoEnumerate `$proof @('session_root') `$null) 'godot.engine.log')",
        '$canonicalRequiredArtifact = [IO.Path]::GetFullPath($requiredArtifact)',
        '$requiredManifestArtifactKeys.Add($canonicalRequiredArtifact)',
        '$requiredManifestArtifacts.Add($canonicalRequiredArtifact)',
        "(Get-ExactValueNoEnumerate `$proof @('heist_seed_preflight') `$null)",
        '$requiredManifestArtifactKeys.Add($canonicalRequiredArtifact)',
        '$requiredManifestArtifacts.Add($canonicalRequiredArtifact)',
        'foreach ($requiredArtifact in $requiredManifestArtifacts)',
        'Aggregate manifest omitted required evidence artifact'
    )
}
$snapshotBindingValidator = {
    param($analysis)
    $topLevel = Get-ExecutableTopLevelSource -Analysis $analysis
    $manifestHash = Get-FunctionSource -Analysis $analysis -Name 'Assert-ManifestArtifactHash'
    (Test-TokensInOrder -Source $topLevel -Needles @(
        '[IO.File]::WriteAllBytes($LauncherSnapshotPath, $launcherBytes)',
        '(Get-Sha256 -Path $LauncherSnapshotPath) -cne $script:LauncherInitialSha256',
        "throw 'Immutable launcher snapshot hash differs immediately after creation.'",
        '$script:LauncherCurrentSha256 = Get-Sha256 -Path $PSCommandPath',
        "Add-TerminalFailure -Failure 'Immutable launcher snapshot changed before teardown.'",
        'Assert-ManifestArtifactHash -ArtifactRows $artifactRows -Path $LauncherSnapshotPath',
        '-ExpectedSha256 $script:LauncherInitialSha256 -Label ''Immutable launcher snapshot'''
    )) -and (Test-TokensInOrder -Source $manifestHash -Needles @(
        '$ArtifactRows -isnot [object[]]', '$ExpectedSha256 -isnot [string]',
        '$ExpectedSha256 -cnotmatch ''^[a-f0-9]{64}$''',
        '$candidatePath = Get-ExactValueNoEnumerate', '$manifestHash = Get-ExactValueNoEnumerate',
        '$manifestHash -isnot [string] -or $manifestHash -cne $ExpectedSha256'
    ))
}
$replayExecutionBindingValidator = {
    param($analysis)
    if ($analysis.source -match '(?i)\$(?:[A-Za-z]+:)?ReplayTool\b|\b(?:SessionState|PSVariable|ExecutionContext)\b') {
        return $false
    }
    if (@($analysis.ast.FindAll({
        param($node)
        $node -is [Management.Automation.Language.CommandAst] -and
            $node.GetCommandName() -in @('Get-Variable', 'Set-Variable', 'New-Variable', 'Remove-Variable',
                'Clear-Variable', 'gv', 'sv', 'nv', 'rv', 'cv')
    }, $true)).Count -ne 0) {
        return $false
    }
    $invokeAst = Get-UniqueFunctionAst -Analysis $analysis -Name 'Invoke-OneFixedRun'
    $invoke = Get-FunctionSource -Analysis $analysis -Name 'Invoke-OneFixedRun'
    $getterAst = Get-UniqueFunctionAst -Analysis $analysis -Name 'Get-ValidatedReplayToolPath'
    $getter = Get-FunctionSource -Analysis $analysis -Name 'Get-ValidatedReplayToolPath'
    $topLevel = Get-ExecutableTopLevelSource -Analysis $analysis
    if ($null -eq $invokeAst -or $null -eq $getterAst -or
        [string]::IsNullOrWhiteSpace($invoke) -or
        [string]::IsNullOrWhiteSpace($getter) -or
        -not (Test-ExactFunctionStructuralHashes -Analysis $analysis -ExpectedHashes $expectedLauncherFunctionHashes)) {
        return $false
    }
    if (-not (Test-TokensInOrder -Source $topLevel -Needles @(
        'New-SourceCustody', '$null = Get-ValidatedReplayToolPath',
        '. $EvidenceAdmissionTool', 'foreach ($runIndex in 1..2)',
        '$proof = Invoke-OneFixedRun -RunIndex $runIndex'
    ))) { return $false }
    if (-not (Test-TokensInOrder -Source $getter -Needles @(
        "`$expectedRepositoryPath = 'tools/rw06_2_ending_replay.ps1'",
        "[IO.Path]::Combine(`$PSScriptRoot, 'rw06_2_ending_replay.ps1')",
        'if (-not [IO.File]::Exists($expectedReplayPath))',
        '$rows = @($script:SourceCustodyRows',
        '$id -is [string] -and $id -ceq "repository:$expectedRepositoryPath"',
        '$rows.Count -ne 1',
        'Assert-SourceCustodyRowSchema -Row $row -Phase pre -Representation in_memory',
        "`$scope -cne 'repository_tracked_production_tree'",
        '$repositoryPath -cne $expectedRepositoryPath',
        '$absolutePath.Equals($expectedReplayPath, [StringComparison]::OrdinalIgnoreCase)',
        "`$expectedBlob -cnotmatch '^[a-f0-9]{40}$'",
        '$rawBlob -cne $expectedBlob',
        'return $expectedReplayPath'
    ))) { return $false }
    if (@($invokeAst.FindAll({
        param($node)
        $node -is [Management.Automation.Language.VariableExpressionAst] -and
            $node.VariablePath.UserPath -ceq 'arguments'
    }, $true)).Count -ne 0) {
        return $false
    }
    if (@($invokeAst.FindAll({
        param($node)
        $node -is [Management.Automation.Language.AssignmentStatementAst] -and
            $node.Left -isnot [Management.Automation.Language.VariableExpressionAst]
    }, $true)).Count -ne 0) {
        return $false
    }
    $startCommands = @($invokeAst.FindAll({
        param($node)
        $node -is [Management.Automation.Language.CommandAst] -and
            $node.GetCommandName() -ceq 'Microsoft.PowerShell.Management\Start-Process'
    }, $true))
    if ($startCommands.Count -ne 1) { return $false }
    $argumentList = @'
@(
            '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', (Get-ValidatedReplayToolPath),
            '-Ending', $Ending, '-EvidenceRole', 'fixed-repeat', '-Seed', $Seed, '-Repeat', '1',
            '-TimeoutSeconds', [string]$CommandTimeoutSeconds, '-EvidenceRoot', $replayEvidenceRoot
        )
'@
    if (-not (Test-ExactCommandArguments -CommandAst $startCommands[0] -ExpectedArguments ([ordered]@{
        FilePath = '$powerShellExe'
        ArgumentList = $argumentList
        RedirectStandardOutput = '$stdoutPath'
        RedirectStandardError = '$stderrPath'
        WindowStyle = 'Hidden'
        PassThru = $null
    }))) { return $false }
    $startAssignment = $startCommands[0].Parent.Parent
    if ($startCommands[0].Parent -isnot [Management.Automation.Language.PipelineAst] -or
        $startAssignment -isnot [Management.Automation.Language.AssignmentStatementAst] -or
        [string]$startAssignment.Left.Extent.Text -cne '$process' -or
        $startAssignment.Parent -isnot [Management.Automation.Language.StatementBlockAst] -or
        $startAssignment.Parent.Parent -isnot [Management.Automation.Language.TryStatementAst] -or
        @($startAssignment.Parent.Statements | Where-Object {
            $_.Extent.StartOffset -eq $startAssignment.Extent.StartOffset -and
                $_.Extent.EndOffset -eq $startAssignment.Extent.EndOffset
        }).Count -ne 1 -or
        @($invokeAst.Body.EndBlock.Statements | Where-Object {
            $_.Extent.StartOffset -eq $startAssignment.Parent.Parent.Extent.StartOffset -and
                $_.Extent.EndOffset -eq $startAssignment.Parent.Parent.Extent.EndOffset
        }).Count -ne 1) {
        return $false
    }
    $getterCalls = @($analysis.ast.FindAll({
        param($node)
        $node -is [Management.Automation.Language.CommandAst] -and
            $node.GetCommandName() -ceq 'Get-ValidatedReplayToolPath'
    }, $true))
    if ($getterCalls.Count -ne 2) {
        return $false
    }
    return $invoke.IndexOf("'-File', `$EvidenceAdmissionTool", [StringComparison]::Ordinal) -lt 0 -and
        $invoke.IndexOf("'rw06_2_ending_replay.ps1'", [StringComparison]::OrdinalIgnoreCase) -lt 0 -and
        $invoke.IndexOf("'-Command'", [StringComparison]::OrdinalIgnoreCase) -lt 0 -and
        @([regex]::Matches($invoke, '\(Get-ValidatedReplayToolPath\)')).Count -eq 1 -and
        @([regex]::Matches($topLevel, '(?m)^\s*\$null\s*=\s*Get-ValidatedReplayToolPath\s*$')).Count -eq 1
}
$cheatContinuePlayabilityValidator = {
    param($analysis)
    $assertDuel = Get-FunctionSource -Analysis $analysis -Name 'Assert-CheatRourkeDuelBeforeHandOne'
    $saveContinue = Get-FunctionSource -Analysis $analysis -Name 'Assert-SaveRelaunchContinue'
    $cheatRoute = Get-FunctionSource -Analysis $analysis -Name 'Invoke-CheatEndingRoute'
    -not [string]::IsNullOrWhiteSpace($assertDuel) -and
        -not [string]::IsNullOrWhiteSpace($saveContinue) -and
        -not [string]::IsNullOrWhiteSpace($cheatRoute) -and
        (Test-TokensInOrder -Source $assertDuel -Needles @(
            '$game = (Get-Rw062RequiredPublicPropertyDescriptor',
            '-InputObject $script:LastObservation', "-Name 'game'",
            '$look = (Get-Rw062RequiredPublicPropertyDescriptor',
            '-InputObject $script:LastResult', "-Name 'look'",
            '$clickable = (Get-Rw062RequiredPublicPropertyDescriptor', "-Name 'clickable'",
            '$surfaceActions = (Get-Rw062RequiredPublicPropertyDescriptor', "-Name 'game_surface_actions'",
            '$selection = Select-CheatReplayDuelCheckpointAction -Game $game -SurfaceActions $surfaceActions',
            '$selection -isnot [System.Management.Automation.PSCustomObject]',
            '$selection.action -isnot [string]', "`$selection.action -cne 'blackjack_deal'",
            '$selection.index -isnot [int32]', '$selection.index -ne 0'
        )) -and
        (Test-UniqueTokensInOrder -Source $saveContinue -Needles @(
            "if (`$Ending -ceq 'cheat' -and `$Milestone -cne 'Rourke duel before hand one')",
            "Assert-CheatRourkeDuelBeforeHandOne -Context 'before Save'",
            '$before = [ordered]@{',
            "`$null = Click-Button -Text 'CONTINUE'",
            'Clear-VisibleCoach',
            "Assert-CheatRourkeDuelBeforeHandOne -Context 'after relaunch and Continue'",
            '$after = [ordered]@{'
        )) -and
        @([regex]::Matches($saveContinue, '(?m)^\s*Assert-CheatRourkeDuelBeforeHandOne\s+-Context\s+')).Count -eq 2 -and
        $cheatRoute.IndexOf("Assert-SaveRelaunchContinue -Milestone 'Rourke duel before hand one'", [StringComparison]::Ordinal) -ge 0
}
$proofPathGraphValidator = {
    param($analysis)
    $shape = Get-FunctionSource -Analysis $analysis -Name 'Assert-FixedRunProofShape'
    -not [string]::IsNullOrWhiteSpace($shape) -and
        (Test-TokensInOrder -Source $shape -Needles @(
            '$outerRunRoot = [IO.Path]::GetFullPath((Split-Path -Parent $profileRoaming))',
            "`$expectedOuterRunRoot = [IO.Path]::GetFullPath((Join-Path `$EvidenceRoot ('run-{0:D2}' -f `$runIndex)))",
            "`$expectedProfileRoaming = [IO.Path]::GetFullPath((Join-Path `$outerRunRoot 'profile_roaming'))",
            "`$expectedProfileLocal = [IO.Path]::GetFullPath((Join-Path `$outerRunRoot 'profile_local'))",
            "`$expectedReplayParent = [IO.Path]::GetFullPath((Join-Path `$outerRunRoot 'replay'))",
            '$expectedProfileSessionRoot = [IO.Path]::GetFullPath((Join-Path $profileRoaming "Godot\app_userdata\Beat the House\agent_playtest\$session"))',
            "`$expectedProfileInventory = [IO.Path]::GetFullPath((Join-Path `$profileSessionRoot 'profile_inventory.json'))",
            "`$expectedAutosave = [IO.Path]::GetFullPath((Join-Path `$profileSessionRoot 'saves\foundation_ui_autosave.json'))",
            "`$expectedReplaySummary = [IO.Path]::GetFullPath((Join-Path `$replayInvocationRoot 'summary.json'))",
            "`$expectedLauncherStdout = [IO.Path]::GetFullPath((Join-Path `$outerRunRoot 'launcher.stdout.txt'))",
            "`$expectedLauncherStderr = [IO.Path]::GetFullPath((Join-Path `$outerRunRoot 'launcher.stderr.txt'))",
            "`$expectedRunRoot = [IO.Path]::GetFullPath((Join-Path `$replayInvocationRoot 'run-01'))",
            "`$expectedRunSummary = [IO.Path]::GetFullPath((Join-Path `$runRoot 'summary.json'))",
            "`$expectedInvocationPattern = '^\d{8}-\d{6}-\d{3}-' + [regex]::Escape([string]`$replayPid) + '$'",
            "`$expectedSessionPattern = '^rw062-' + [regex]::Escape(`$Ending) + '-' + [regex]::Escape([string]`$replayPid) + '-1-[0-9a-f]{10}$'",
            '$sessionDateRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sessionRoot))',
            '$sessionBaseRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sessionDateRoot))',
            "`$expectedSessionBaseRoot = [IO.Path]::GetFullPath((Join-Path `$Worktree '.tmp\agent_playtest'))",
            '$invocationName = [IO.Path]::GetFileName($replayInvocationRoot)',
            '$sessionDateName = [IO.Path]::GetFileName($sessionDateRoot)',
            '$invocationName -cnotmatch $expectedInvocationPattern',
            "`$sessionDateName -cnotmatch '^\d{4}-\d{2}-\d{2}$'",
            '$expectedSessionDateName = $invocationName.Substring(0, 4)',
            '$outerRunRoot.Equals($expectedOuterRunRoot, [StringComparison]::OrdinalIgnoreCase)',
            '$profileSessionRoot.Equals($expectedProfileSessionRoot, [StringComparison]::OrdinalIgnoreCase)',
            '$replaySummary.Equals($expectedReplaySummary, [StringComparison]::OrdinalIgnoreCase)',
            '$launcherStdout.Equals($expectedLauncherStdout, [StringComparison]::OrdinalIgnoreCase)',
            '$launcherStderr.Equals($expectedLauncherStderr, [StringComparison]::OrdinalIgnoreCase)',
            '$runRoot.Equals($expectedRunRoot, [StringComparison]::OrdinalIgnoreCase)',
            '$runSummary.Equals($expectedRunSummary, [StringComparison]::OrdinalIgnoreCase)',
            '$session -cnotmatch $expectedSessionPattern',
            '$sessionDateName -cne $expectedSessionDateName',
            '$sessionBaseRoot.Equals($expectedSessionBaseRoot, [StringComparison]::OrdinalIgnoreCase)'
        ))
}
$freshEvidenceRootValidator = {
    param($analysis)
    $topLevel = Get-ExecutableTopLevelSource -Analysis $analysis
    Test-TokensInOrder -Source $topLevel -Needles @(
        'New-Item -ItemType Directory -Path $LeaseRoot -Force | Out-Null',
        'if (Test-Path -LiteralPath $EvidenceRoot)',
        'throw "Refusing to reuse pre-existing aggregate evidence root: $EvidenceRoot"',
        'New-Item -ItemType Directory -Path $EvidenceRoot | Out-Null',
        '$launcherBytes = [IO.File]::ReadAllBytes($PSCommandPath)'
    )
}

$expectedParameters = @('ExpectedHead', 'ExpectedTree', 'Ending', 'PerRunTimeoutSeconds', 'CommandTimeoutSeconds')
Assert-True -Condition ([bool](& $immutableLauncherValidator $launcher)) `
    -Message 'Final launcher structural identity or exact function-body authority drifted.'
Assert-HostileMutationRejected -Name 'launcher-structural-identity-drift' -Validator $immutableLauncherValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle "throw 'The exact checked-in replay tool is missing.'" `
        -Replacement "throw 'The checked-in replay tool is missing.'"
}
Assert-True -Condition ($launcher.parameters.Count -eq $expectedParameters.Count) `
    -Message 'Final-evidence launcher gained or lost a top-level parameter.'
foreach ($parameter in $expectedParameters) {
    Assert-True -Condition ($parameter -cin $launcher.parameters) `
        -Message "Final-evidence launcher is missing parameter '$parameter'."
}
foreach ($forbiddenParameter in @('Seed', 'Repeat', 'EvidenceRole', 'FreshSeed', 'Fresh', 'Interactive', 'Scenario', 'Plan')) {
    Assert-True -Condition ($forbiddenParameter -cnotin $launcher.parameters) `
        -Message "Fixed-repeat launcher must not admit '$forbiddenParameter' as a caller-controlled parameter."
}

Assert-Contains -Source $launcherSource -Needle "clean = 'RW06-CLEAN-ROUTE-01'" `
    -Message 'Clean fixed seed drifted from the accepted route seed.'
Assert-Contains -Source $launcherSource -Needle "cheat = 'RW06-CHEAT-ROUTE-01'" `
    -Message 'Cheat fixed seed drifted from the accepted route seed.'
Assert-Contains -Source $launcherSource -Needle "heist = 'RW06-HEIST-AUDIT-0002'" `
    -Message 'Heist fixed seed drifted from Q-013 exact 0002.'
Assert-Contains -Source $launcherSource -Needle "Q-013 fixed-repeat evidence requires exact Heist seed RW06-HEIST-AUDIT-0002." `
    -Message 'Final launcher lost its explicit Q-013 exact-seed guard.'
Assert-Contains -Source $launcherSource -Needle "fresh_interactive_authorized = `$false" `
    -Message 'Final launcher must record that fresh-interactive evidence is not authorized here.'
Assert-Contains -Source $launcherSource -Needle "'ANSWERED_SEPARATE_FRESH_INTERACTIVE_SCOPE'" `
    -Message 'Final launcher must record answered Q-017 as a separate fresh-interactive scope.'
Assert-NotMatch -Source $launcherSource -Pattern '(?i)(scenario_(?:pin|override)|injected_scenario|scenario_injection_allowed\s*=\s*\$true|plan_b_allowed\s*=\s*\$true|Invoke-[A-Za-z0-9_-]*(?:PlanB|Whale))' `
    -Message 'Final fixed-repeat launcher must not contain scenario-injection or Plan-B behavior.'
Assert-Contains -Source $launcherSource -Needle "`$EvidenceAdmissionTool = Join-Path `$PSScriptRoot 'rw06_2_evidence_admission.ps1'" `
    -Message 'Final launcher must load the checked-in exact admission helper.'
Assert-Contains -Source $launcherSource -Needle '. $EvidenceAdmissionTool' `
    -Message 'Final launcher must execute the checked-in exact admission helper before inspecting child evidence.'
Assert-Contains -Source $launcherSource -Needle "function Get-ValidatedReplayToolPath" `
    -Message 'Final launcher must derive and custody-validate the replay path without mutable path state.'
Assert-True -Condition ([bool](& $replayExecutionBindingValidator $launcher)) `
    -Message 'Final launcher can validate one replay tool while executing different bytes.'
Assert-True -Condition ([bool](& $cheatContinuePlayabilityValidator $replay)) `
    -Message 'Cheat Save/relaunch/Continue no longer proves the exact restored active, pre-hand-one, enabled Deal surface.'
Assert-Contains -Source $admissionSource -Needle "heist = 'RW06-HEIST-AUDIT-0000'" `
    -Message 'Admission helper lost the separately authorized Q-017 fresh-interactive seed.'
Assert-True -Condition ([bool](& $endingNormalizationValidator $launcher)) `
    -Message 'Ending must be canonicalized before any seed lookup or exact Heist/Q-017 guard.'

Assert-Contains -Source $launcherSource -Needle "Assert-RepositoryIdentity" `
    -Message 'Final launcher lost exact repository-identity admission.'
Assert-Contains -Source $launcherSource -Needle "status --porcelain --untracked-files=all" `
    -Message 'Final launcher no longer rejects a dirty implementation worktree.'
Assert-Contains -Source $launcherSource -Needle "HEAD^{tree}" `
    -Message 'Final launcher no longer pins the exact Git tree.'
Assert-Contains -Source $launcherSource -Needle "launcher.invoked.ps1" `
    -Message 'Final launcher no longer retains its immutable invocation snapshot.'
Assert-Contains -Source $launcherSource -Needle "LauncherCurrentSha256 -cne `$script:LauncherInitialSha256" `
    -Message 'Final launcher no longer rejects mutation after its snapshot.'
Assert-True -Condition ([bool](& $snapshotBindingValidator $launcher)) `
    -Message 'Launcher snapshot is not hash-bound at creation, teardown and manifest finalization.'
Assert-True -Condition ([bool](& $freshEvidenceRootValidator $launcher)) `
    -Message 'Aggregate evidence root can be reused instead of being created exactly once.'

Assert-Contains -Source $launcherSource -Needle "`$LeaseRoot = 'D:\Projects\Beat-The-House-worktrees\.godot_leases'" `
    -Message 'Final launcher must use the exact canonical Q-009 lease root even from the primary checkout.'
Assert-Contains -Source $launcherSource -Needle "Q-009 EXCLUSIVE lease is active." `
    -Message 'Final launcher lost its Q-009 EXCLUSIVE admission guard.'
Assert-Contains -Source $launcherSource -Needle "Q-009 exclusive launch requires a drained engine census" `
    -Message 'Final launcher lost the post-reservation zero-Godot launch gate.'
Assert-True -Condition (([regex]::Matches($launcherTopLevel, '(?m)^\s*New-OwnedExclusiveLease\s*$')).Count -eq 1) `
    -Message 'Final launcher must acquire exactly one aggregate EXCLUSIVE lease outside its two-run loop.'
Assert-Contains -Source $launcherSource -Needle "foreach (`$runIndex in 1..2)" `
    -Message 'Final launcher must execute exactly two fixed-route child runs.'
Assert-True -Condition ([bool](& $exclusiveAdmissionValidator $launcher)) `
    -Message 'EXCLUSIVE must be reserved first, then bounded-drain normal leases/Godot under exact owner rechecks before launch.'
Assert-True -Condition ([bool](& $exclusiveLeaseCreationValidator $launcher)) `
    -Message 'EXCLUSIVE creation does not remove a partial/malformed owned file before LeaseOwned can be set.'
Assert-True -Condition ([bool](& $survivorCustodyValidator $launcher)) `
    -Message 'EXCLUSIVE teardown no longer transfers custody atomically to a live replay/Godot survivor.'

Assert-Contains -Source $launcherSource -Needle "`$profileRoaming = Join-Path `$runEvidenceRoot 'profile_roaming'" `
    -Message 'Each child run must derive its roaming profile from its distinct run evidence root.'
Assert-Contains -Source $launcherSource -Needle "`$profileLocal = Join-Path `$runEvidenceRoot 'profile_local'" `
    -Message 'Each child run must derive its local profile from its distinct run evidence root.'
Assert-Contains -Source $launcherSource -Needle "`$env:APPDATA = `$profileRoaming" `
    -Message 'Child replay no longer receives its isolated APPDATA.'
Assert-Contains -Source $launcherSource -Needle "`$env:LOCALAPPDATA = `$profileLocal" `
    -Message 'Child replay no longer receives its isolated LOCALAPPDATA.'
Assert-Contains -Source $launcherSource -Needle "Restore-ProcessEnvironmentValue -Name 'APPDATA'" `
    -Message 'Aggregate launcher no longer restores its process APPDATA after child creation.'
Assert-Contains -Source $launcherSource -Needle "Restore-ProcessEnvironmentValue -Name 'LOCALAPPDATA'" `
    -Message 'Aggregate launcher no longer restores its process LOCALAPPDATA after child creation.'
Assert-Match -Source $launcherSource `
    -Pattern '(?s)''-Ending'', \$Ending, ''-EvidenceRole'', ''fixed-repeat'', ''-Seed'', \$Seed, ''-Repeat'', ''1''.*?''-TimeoutSeconds''.*?''-EvidenceRoot'', \$replayEvidenceRoot' `
    -Message 'Each child must be an exact fixed-repeat/Repeat=1 production replay with only the fixed seed and isolated evidence root.'
Assert-True -Condition ([bool](& $spawnCustodyValidator $launcher)) `
    -Message 'Child environment, spawn, identity registration/fail-clean cleanup, restoration and wait are not in the required order.'
Assert-True -Condition ([bool](& $profileArtifactValidator $launcher)) `
    -Message 'Final launcher does not prove and manifest the exact session-scoped profile inventory and autosave artifacts.'
Assert-True -Condition ([bool](& $proofPathGraphValidator $launcher)) `
    -Message 'Run proof validation no longer binds the exact outer-run, replay-invocation, session, profile, and retained-artifact path graph.'

foreach ($leaf in @(
    'public_trace.ndjson', 'money_curve.ndjson', 'checkpoint_before.json',
    'checkpoint_after.json', 'final_public_checkpoint.json'
)) {
    Assert-Contains -Source $launcherSource -Needle "'$leaf'" `
        -Message "Final launcher does not require retained evidence leaf '$leaf'."
}
Assert-Contains -Source $launcherSource -Needle "'SCRIPT ERROR|(^|\s)ERROR[: ]|(^|\s)WARNING[: ]'" `
    -Message 'Final launcher lost strict retained-log diagnostics.'
Assert-Contains -Source $launcherSource -Needle "[int]`$actionCount -le 0 -or [int]`$actionCount -gt 350" `
    -Message 'Final launcher lost the positive/350 action-count evidence bound.'
Assert-Contains -Source $launcherSource -Needle "midpoint_save_relaunch_continue" `
    -Message 'Final launcher no longer requires the midpoint Save/relaunch/Continue witness.'
Assert-True -Condition ([bool](& $childIterationBoundaryValidator $launcher)) `
    -Message 'Final launcher no longer requires each retained child iteration to remain explicitly development-only and non-qualifying.'
Assert-True -Condition ([bool](& $fixedRoleIsolationValidator $launcher)) `
    -Message 'Final launcher no longer binds, validates, and promotes only exact fixed-repeat child evidence.'
Assert-Contains -Source $launcherSource -Needle "persistence_checkpoint_equal" `
    -Message 'Final launcher no longer requires the replay checkpoint-comparison witness.'
Assert-Contains -Source $launcherSource -Needle "`$checkpointBeforeHash -cne `$checkpointAfterHash" `
    -Message 'Final launcher no longer independently compares successful before/after checkpoint hashes.'
Assert-True -Condition ([bool](& $exactPathValidator $launcher)) `
    -Message 'Final launcher does not bind every child-published trace/money/checkpoint path to its exact expected file.'

foreach ($field in @(
    'transcript_sha256', 'money_curve_sha256', 'final_public_checkpoint_sha256',
    'persistence_checkpoint_before_sha256', 'persistence_checkpoint_after_sha256'
)) {
    Assert-Contains -Source $launcherSource -Needle "'$field'" `
        -Message "Cross-profile comparison omits canonical field '$field'."
}
Assert-Contains -Source $launcherSource -Needle "Fixed-repeat runs did not use distinct exact values for" `
    -Message 'Final launcher lost distinct-profile/session/path enforcement.'
Assert-Contains -Source $launcherSource -Needle "fixed_repeat_qualifying = `$fixedRepeatQualifying" `
    -Message 'Aggregate summary/manifest no longer publishes the fixed-repeat qualification result.'
Assert-Contains -Source $launcherSource -Needle "rw06_2_final_evidence_manifest" `
    -Message 'Final launcher no longer produces its aggregate artifact manifest.'
Assert-True -Condition ([bool](& $proofPromotionValidator $launcher)) `
    -Message 'Green promotion is no longer ordered strictly after cross-profile proof comparison.'
Assert-True -Condition ([bool](& $qualificationValidator $launcher)) `
    -Message 'Fixed-repeat qualification no longer has the exact fail-closed conjunction.'
Assert-True -Condition ([bool](& $terminalCanonicalAuthorityValidator $launcher)) `
    -Message 'Terminal publication no longer recomputes canonical authority or rejects post-promotion proof mutation.'
Assert-True -Condition ([bool](& $aggregateSummaryValidator $launcher)) `
    -Message 'Aggregate summary no longer binds the exact fixed-repeat role, repeat, fresh authorization, and Q-017 status.'
Assert-True -Condition ([bool](& $metadataLabelValidator $launcher)) `
    -Message 'Retained aggregate metadata no longer binds the exact fixed-repeat role labels.'
Assert-True -Condition ([bool](& $manifestLabelValidator $launcher)) `
    -Message 'Retained aggregate manifest no longer binds its exact fixed-repeat role label.'
Assert-True -Condition ([bool](& $resultValidator $launcher)) `
    -Message 'Final stdout result no longer binds its exact fixed-repeat evidence identities and hashes.'
Assert-True -Condition ([bool](& $terminalSchemaValidator $launcher)) `
    -Message 'Terminal aggregate, metadata, manifest, artifact/process rows, or stdout schemas are not exactly closed and read back.'
Assert-True -Condition ([bool](& $manifestProofBindingValidator $launcher)) `
    -Message 'Final manifest no longer cross-binds every available run-proof artifact hash.'
Assert-True -Condition ([bool](& $manifestOrderValidator $launcher)) `
    -Message 'Summary/metadata/manifest creation and final manifest hashing are not in the required order.'
Assert-True -Condition ([bool](& $manifestClosureValidator $launcher)) `
    -Message 'Manifest closure is not populated from every proof-derived required artifact before publication.'

Assert-Match -Source $replaySource `
    -Pattern '(?s)\$before \| ConvertTo-Json -Depth 10 \| Set-Content[^\r\n]+checkpoint_before\.json.*?\$after \| ConvertTo-Json -Depth 10 \| Set-Content[^\r\n]+checkpoint_after\.json.*?if \(\$afterJson -cne \$beforeJson\)' `
    -Message 'Generic replay persistence no longer retains both successful checkpoint files before comparison.'
Assert-Match -Source $replaySource `
    -Pattern '(?s)\$before \| ConvertTo-Json -Depth 20 \| Set-Content[^\r\n]+checkpoint_before\.json.*?\$after \| ConvertTo-Json -Depth 20 \| Set-Content[^\r\n]+checkpoint_after\.json.*?if \(\$afterJson -cne \$beforeJson\)' `
    -Message 'Heist replay persistence no longer retains both successful checkpoint files before comparison.'
foreach ($field in @(
    'persistence_checkpoint_before_sha256', 'persistence_checkpoint_after_sha256',
    'persistence_checkpoint_equal', 'persistence_checkpoint_complete'
)) {
    Assert-Contains -Source $replaySource -Needle $field `
        -Message "Replay summary no longer publishes '$field'."
}
Assert-Contains -Source $replaySource -Needle "`$checkpointEvidenceComplete" `
    -Message 'Replay release qualification no longer requires complete checkpoint evidence.'

Assert-HostileMutationRejected -Name 'mixed-case-ending-bypass' -Validator $endingNormalizationValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source -Needle '$Ending = $Ending.ToLowerInvariant()' -Replacement '$null = $Ending'
}
Assert-HostileMutationRejected -Name 'fixed-role-launch-substitution' -Validator $fixedRoleIsolationValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source -Needle "'-EvidenceRole', 'fixed-repeat'" -Replacement "'-EvidenceRole', 'fresh-interactive'"
}
Assert-HostileMutationRejected -Name 'fixed-role-invocation-check-bypass' -Validator $fixedRoleIsolationValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle '        $summaryEvidenceRole -isnot [string] -or $summaryEvidenceRole -cne ''fixed-repeat'' -or' `
        -Replacement '        $false -or'
}
Assert-HostileMutationRejected -Name 'fixed-role-iteration-check-bypass' -Validator $fixedRoleIsolationValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle '        $runEvidenceRole -isnot [string] -or $runEvidenceRole -cne ''fixed-repeat'' -or' `
        -Replacement '        $false -or'
}
Assert-HostileMutationRejected -Name 'fixed-role-proof-check-bypass' -Validator $fixedRoleIsolationValidator -Mutate {
    param($source)
    $pattern = "(?m)^(        evidence_role = )'fixed-repeat'(?=\r?\n        ending = \`$Ending)"
    $matches = [regex]::Matches($source, $pattern)
    if ($matches.Count -ne 1) { throw 'Hostile fixture could not isolate the proof identity role.' }
    return [regex]::Replace($source, $pattern, "`$1'fresh-interactive'", 1)
}

$exactTypeValidator = {
    param($analysis)
    $admission = Get-FunctionSource -Analysis $analysis -Name 'Assert-FixedReplayAdmission'
    $oneRun = Get-FunctionSource -Analysis $analysis -Name 'Assert-OneRunEvidence'
    $oneRunShapes = Get-FunctionSource -Analysis $analysis -Name 'Assert-OneRunJsonShapes'
    $finalShapes = Get-FunctionSource -Analysis $analysis -Name 'Assert-FinalCheckpointJsonShapes'
    $saveContinueShapes = Get-FunctionSource -Analysis $analysis -Name 'Assert-SaveContinueCheckpointJsonShape'
    $persistenceCoreShapes = Get-FunctionSource -Analysis $analysis -Name 'Assert-PersistenceCoreCheckpointShape'
    $runProofShapes = Get-FunctionSource -Analysis $analysis -Name 'Assert-FixedRunProofShape'
    $canonicalProofShapes = Get-FunctionSource -Analysis $analysis -Name 'Assert-CanonicalFixedProofShape'
    $exactObjectType = Get-FunctionSource -Analysis $analysis -Name 'Test-ExactPsCustomObject'
    $exactJsonObject = Get-FunctionSource -Analysis $analysis -Name 'ConvertFrom-ExactJsonObjectText'
    $compare = Get-FunctionSource -Analysis $analysis -Name 'Compare-FixedRunProofs'
    $qualification = Get-FunctionSource -Analysis $analysis -Name 'Test-FixedRepeatQualification'
    if ([string]::IsNullOrWhiteSpace($admission) -or
        [string]::IsNullOrWhiteSpace($oneRun) -or
        [string]::IsNullOrWhiteSpace($oneRunShapes) -or
        [string]::IsNullOrWhiteSpace($finalShapes) -or
        [string]::IsNullOrWhiteSpace($saveContinueShapes) -or
        [string]::IsNullOrWhiteSpace($persistenceCoreShapes) -or
        [string]::IsNullOrWhiteSpace($runProofShapes) -or
        [string]::IsNullOrWhiteSpace($canonicalProofShapes) -or
        [string]::IsNullOrWhiteSpace($exactObjectType) -or
        [string]::IsNullOrWhiteSpace($exactJsonObject) -or
        [string]::IsNullOrWhiteSpace($compare) -or
        [string]::IsNullOrWhiteSpace($qualification)) {
        return $false
    }
    foreach ($token in @(
        "`$actualEvidenceRole = Get-ExactValueNoEnumerate `$Admission @('evidence_role') `$null",
        "`$actualEnding = Get-ExactValueNoEnumerate `$Admission @('ending') `$null",
        "`$actualSeed = Get-ExactValueNoEnumerate `$Admission @('seed') `$null",
        "`$actualRepeat = Get-ExactValueNoEnumerate `$Admission @('repeat') `$null",
        "`$actualRoutePlan = Get-ExactValueNoEnumerate `$Admission @('route_plan') `$null",
        "`$actualExpectedScenario = Get-ExactValueNoEnumerate `$Admission @('expected_initial_scenario') `$null",
        "`$actualScenarioAuthority = Get-ExactValueNoEnumerate `$Admission @('scenario_authority') `$null",
        "`$actualScenarioInjectionAllowed = Get-ExactValueNoEnumerate `$Admission @('scenario_injection_allowed') `$null",
        "`$actualPlanBAllowed = Get-ExactValueNoEnumerate `$Admission @('plan_b_allowed') `$null",
        "`$actualRequiresIsolatedProfile = Get-ExactValueNoEnumerate `$Admission @('requires_isolated_profile') `$null",
        "`$actualReleaseQualifying = Get-ExactValueNoEnumerate `$Admission @('release_qualifying') `$null",
        "`$actualQualificationAuthority = Get-ExactValueNoEnumerate `$Admission @('qualification_authority') `$null",
        '$actualEvidenceRole -isnot [string]', '$actualEnding -isnot [string]',
        '$actualSeed -isnot [string]', '$actualRepeat -isnot [int32]',
        '$actualRoutePlan -isnot [string]', '$actualExpectedScenario -isnot [string]',
        '$actualScenarioAuthority -isnot [string]', '$actualScenarioInjectionAllowed -isnot [bool]',
        '$actualPlanBAllowed -isnot [bool]', '$actualRequiresIsolatedProfile -isnot [bool]',
        '$actualReleaseQualifying -isnot [bool]', '$actualQualificationAuthority -isnot [string]'
    )) {
        if ($admission.IndexOf($token, [StringComparison]::Ordinal) -lt 0) { return $false }
    }
    foreach ($token in @(
        "`$summaryEvidenceRoot = Get-ExactValueNoEnumerate `$summary @('evidence_root') `$null",
        "`$summaryCheckId = Get-ExactValueNoEnumerate `$summary @('check_id') `$null",
        "`$summaryEvidenceRole = Get-ExactValueNoEnumerate `$summary @('requested_evidence_role') `$null",
        "`$summaryEnding = Get-ExactValueNoEnumerate `$summary @('ending') `$null",
        "`$summarySeed = Get-ExactValueNoEnumerate `$summary @('seed') `$null",
        "`$summaryRepeat = Get-ExactValueNoEnumerate `$summary @('repeat') `$null",
        "`$summaryDeterministic = Get-ExactValueNoEnumerate `$summary @('deterministic') `$null",
        "`$summaryReleaseQualifying = Get-ExactValueNoEnumerate `$summary @('release_qualifying') `$null",
        "`$summaryQualification = Get-ExactValueNoEnumerate `$summary @('qualification') `$null",
        "`$actionCount = Get-ExactValueNoEnumerate `$run @('action_count') `$null",
        "`$outcome = Get-ExactValueNoEnumerate `$run @('outcome') `$null",
        "`$runFailure = Get-ExactValueNoEnumerate `$run @('failure') `$null",
        "`$publishedTranscriptPath = Get-ExactValueNoEnumerate `$run @('transcript') `$null",
        "`$publishedMoneyPath = Get-ExactValueNoEnumerate `$run @('money_curve') `$null",
        "`$publishedCheckpointBeforePath = Get-ExactValueNoEnumerate `$run @('persistence_checkpoint_before') `$null",
        "`$publishedCheckpointAfterPath = Get-ExactValueNoEnumerate `$run @('persistence_checkpoint_after') `$null",
        "`$publishedTranscriptHash = Get-ExactValueNoEnumerate `$run @('transcript_sha256') `$null",
        "`$publishedMoneyHash = Get-ExactValueNoEnumerate `$run @('money_curve_sha256') `$null",
        "`$publishedCheckpointBeforeHash = Get-ExactValueNoEnumerate `$run @('persistence_checkpoint_before_sha256') `$null",
        "`$publishedCheckpointAfterHash = Get-ExactValueNoEnumerate `$run @('persistence_checkpoint_after_sha256') `$null",
        "`$finalRecordKind = Get-ExactValueNoEnumerate `$finalCheckpoint @('record_kind') `$null",
        "`$finalObservedSeed = Get-ExactValueNoEnumerate `$finalCheckpoint @('observed_seed') `$null",
        "`$finalOutcome = Get-ExactValueNoEnumerate `$finalCheckpoint @('outcome_key') `$null",
        "`$finalWon = Get-ExactValueNoEnumerate `$finalCheckpoint @('won') `$null",
        "`$session = Get-ExactValueNoEnumerate `$run @('session') `$null",
        '$summaryCheckId -isnot [string]',
        '$summaryEvidenceRole -isnot [string]', '$summaryEnding -isnot [string]',
        '$summarySeed -isnot [string]', '$summaryRepeat -isnot [int32]',
        '$summaryDeterministic -isnot [bool]', '$summaryReleaseQualifying -isnot [bool]',
        '$summaryQualification -isnot [string]', '$actionCount -isnot [int32]',
        '$outcome -isnot [string]', '$runFailure -isnot [string]',
        '$publishedTranscriptHash -isnot [string]', '$publishedMoneyHash -isnot [string]',
        '$publishedCheckpointBeforeHash -isnot [string]', '$publishedCheckpointAfterHash -isnot [string]',
        '$finalRecordKind -isnot [string]', '$finalObservedSeed -isnot [string]',
        '$finalOutcome -isnot [string]', '$finalWon -isnot [bool]', '$session -isnot [string]'
    )) {
        if ($oneRun.IndexOf($token, [StringComparison]::Ordinal) -lt 0) { return $false }
    }
    foreach ($token in @(
        '-not (Test-ExactPsCustomObject -Value $Summary)', '-not (Test-ExactPsCustomObject -Value $Run)',
        '$summaryPropertyNames = @(', '$runPropertyNames = @(',
        'Assert-Rw062ExactPropertyNames -InputObject $Summary',
        'Assert-Rw062ExactPropertyNames -InputObject $Run',
        "path = @('schema_version'); type = 'int32'", "path = @('evidence_root'); type = 'string'",
        "path = @('role'); type = 'string'", "path = @('repeat'); type = 'int32'",
        "path = @('deterministic'); type = 'bool'", "path = @('checkpoint_evidence_complete'); type = 'bool'",
        "path = @('public_observation_schema'); type = 'string'",
        "path = @('public_observation_schema_version'); type = 'int32'",
        "path = @('action_count'); type = 'int32'", "path = @('iteration'); type = 'int32'",
        "path = @('passed'); type = 'bool'", "path = @('session'); type = 'string'",
        '$summarySeeds -isnot [object[]]', '$summaryRuns -isnot [object[]]',
        "path = @('replay_admission')", "path = @('heist_seed_preflight')",
        "path = @('heist_preflight_admission')", "path = @('heist_launch_setup')",
        'Assert-Rw062ExactPropertyNames -InputObject $launchSetup',
        '$contentGroups -isnot [object[]]',
        "`$summaryRole -cne 'child_development_run'",
        "`$summaryObservationSchema -cne 'beat_the_house.agent_public_observation'",
        '$runIteration -ne 1', '$runEnding -cne $Ending',
        "Test-Rw062ExactNullProperty -InputObject `$Summary -Name 'heist_seed_preflight'",
        "Test-Rw062ExactNullProperty -InputObject `$Run -Name 'heist_launch_setup'"
    )) {
        if ($oneRunShapes.IndexOf($token, [StringComparison]::Ordinal) -lt 0) { return $false }
    }
    foreach ($token in @(
        '-not (Test-ExactPsCustomObject -Value $Retained)', '-not (Test-ExactPsCustomObject -Value $Published)',
        '$checkpointPropertyNames = @(',
        'Assert-LocalExactPropertyNames -InputObject $Retained',
        'Assert-LocalExactPropertyNames -InputObject $Published',
        "path = @('schema_version'); type = 'int32'",
        "path = @('record_kind'); type = 'string'", "path = @('won'); type = 'bool'",
        "path = @('bankroll'); type = 'int32'", "path = @('heat'); type = 'int32'",
        '$schemaVersion -ne 1', "`$publicFingerprint -cnotmatch '^[a-f0-9]{64}$'",
        "`$checkpointFingerprint -cnotmatch '^[a-f0-9]{64}$'"
    )) {
        if ($finalShapes.IndexOf($token, [StringComparison]::Ordinal) -lt 0) { return $false }
    }
    if (-not (Test-TokensInOrder -Source $exactObjectType -Needles @(
        '$null -ne $Value', '$Value.GetType().FullName', "'System.Management.Automation.PSCustomObject'"
    ))) { return $false }
    if (-not (Test-TokensInOrder -Source $exactJsonObject -Needles @(
        '$trimmed = $Json.Trim()', "`$trimmed[0] -cne '{'", "`$trimmed[`$trimmed.Length - 1] -cne '}'",
        'Test-ExactPsCustomObject -Value $value', 'Write-Output -NoEnumerate $value'
    ))) { return $false }
    if (-not (Test-TokensInOrder -Source $oneRun -Needles @(
        'ConvertFrom-ExactJsonObjectText', 'Assert-OneRunJsonShapes -Summary $summary -Run $run',
        'Assert-SaveContinueCheckpointJsonShape',
        'ConvertTo-CanonicalExactObjectJson -InputObject $checkpointBefore',
        'ConvertTo-CanonicalExactObjectJson -InputObject $checkpointAfter',
        'Assert-FinalCheckpointJsonShapes'
    ))) { return $false }
    if (-not (Test-TokensInOrder -Source $persistenceCoreShapes -Needles @(
        'Assert-LocalExactPropertyNames', "'location_id', 'location_archetype', 'world_node_id'",
        "'game_id', 'game_phase'", '$value -isnot [string]',
        "'bankroll', 'chips', 'heat', 'boss_hand_number', 'boss_player_stack', 'boss_rourke_stack'",
        '$value -isnot [int32]'
    ))) { return $false }
    if (-not (Test-TokensInOrder -Source $saveContinueShapes -Needles @(
        "-Expected @('checkpoint', 'planning_choices')", "-Expected @('checkpoint', 'clean_players_card')",
        'Assert-PersistenceCoreCheckpointShape', "'choice_ids', 'choices'", 'Test-ExactStringArray',
        "-Expected @('id', 'label', 'enabled')", '$planningChoices -isnot [object[]]',
        "'choice_id', 'label', 'enabled', 'rendered', 'disabled_reason'",
        '$enabled -isnot [bool]', '$rendered -isnot [bool]',
        "`$choiceId -ceq 'lock_the_count'", '$countLockRows -ne 1'
    ))) { return $false }
    if (-not (Test-TokensInOrder -Source $runProofShapes -Needles @(
        'Assert-LocalExactPropertyNames', "'run_index', 'role', 'evidence_role', 'ending', 'seed', 'replay_pid'",
        "'session_root', 'outcome', 'action_count'", '$runIndex -isnot [int32]', '$replayPid -isnot [int32]',
        '$outcome -isnot [string]', '$actionCount -isnot [int32]', 'source_custody_pre_sha256',
        "'heist_seed_preflight_sha256'"
    ))) { return $false }
    if (-not (Test-TokensInOrder -Source $canonicalProofShapes -Needles @(
        'Assert-LocalExactPropertyNames', "'evidence_role', 'deterministic', 'isolated_profiles'",
        "'run_1_proof_sha256', 'run_2_proof_sha256'",
        '$evidenceRole -isnot [string]', '$deterministic -isnot [bool]', '$isolatedProfiles -isnot [bool]',
        "'heist_seed_preflight_sha256'"
    ))) { return $false }
    if ($analysis.source -match '\[(?:string|int|bool|long)\]\(Get-ExactValue\s') { return $false }
    if ($compare -match '\[(?:string|int|bool|long)\]\$proof\.' -or
        $compare.IndexOf('$value -isnot [string] -or $value -cne [string]$entry.Value', [StringComparison]::Ordinal) -lt 0) {
        return $false
    }
    if ($compare.IndexOf('$Proofs -isnot [object[]] -or $Proofs.Count -ne 2', [StringComparison]::Ordinal) -lt 0) {
        return $false
    }
    if (-not (Test-TokensInOrder -Source $compare -Needles @(
        '$firstProofSha256 = Get-CanonicalExactObjectSha256',
        "-Label 'Fixed-route run 1 complete proof'",
        '$secondProofSha256 = Get-CanonicalExactObjectSha256',
        "-Label 'Fixed-route run 2 complete proof'",
        'run_1_proof_sha256 = $firstProofSha256',
        'run_2_proof_sha256 = $secondProofSha256'
    ))) { return $false }
    return (Test-TokensInOrder -Source $qualification -Needles @(
        '$RunProofs -isnot [object[]]', '-not (Test-ExactPsCustomObject -Value $CanonicalProof)',
        'Assert-FixedRunProofShape', 'Assert-CanonicalFixedProofShape',
        '$recomputedCanonicalProof = Compare-FixedRunProofs -Proofs $proofArray',
        'ConvertTo-CanonicalExactObjectJson -InputObject $CanonicalProof',
        'ConvertTo-CanonicalExactObjectJson -InputObject $recomputedCanonicalProof'
    ))
}

$sourceCustodyValidator = {
    param($analysis)
    if (-not (Test-ExactFunctionStructuralHashes -Analysis $analysis -ExpectedHashes $expectedLauncherFunctionHashes)) {
        return $false
    }
    $topLevel = Get-ExecutableTopLevelSource -Analysis $analysis
    $descriptors = Get-FunctionSource -Analysis $analysis -Name 'Get-TrackedSourceDescriptors'
    $rowSchema = Get-FunctionSource -Analysis $analysis -Name 'Assert-SourceCustodyRowSchema'
    $rowMatches = Get-FunctionSource -Analysis $analysis -Name 'Assert-SourceCustodyRowMatches'
    $receiptSchema = Get-FunctionSource -Analysis $analysis -Name 'Assert-SourceCustodyReceiptSchema'
    $blobIdentity = Get-FunctionSource -Analysis $analysis -Name 'Assert-RepositoryBlobIdentity'
    $open = Get-FunctionSource -Analysis $analysis -Name 'Open-SourceCustodyHandle'
    $receipt = Get-FunctionSource -Analysis $analysis -Name 'New-LockedJsonReceipt'
    $new = Get-FunctionSource -Analysis $analysis -Name 'New-SourceCustody'
    $assert = Get-FunctionSource -Analysis $analysis -Name 'Assert-SourceCustody'
    $complete = Get-FunctionSource -Analysis $analysis -Name 'Complete-SourceCustody'
    $close = Get-FunctionSource -Analysis $analysis -Name 'Close-SourceCustody'
    $invoke = Get-FunctionSource -Analysis $analysis -Name 'Invoke-OneFixedRun'
    (Test-TokensInOrder -Source $descriptors -Needles @(
        'ls-tree -r --full-tree $ExpectedHead', "'^(?<mode>100644|100755) blob (?<blob>[a-f0-9]{40})",
        'expected_git_mode =', 'expected_git_blob ='
    )) -and $descriptors.IndexOf('ls-files --stage', [StringComparison]::Ordinal) -lt 0 -and
        (Test-TokensInOrder -Source $blobIdentity -Needles @(
            '$repositoryRows = @($script:SourceCustodyRows',
            "`$rawBlob = Get-ExactValueNoEnumerate `$row @('raw_git_blob') `$null",
            '$expectedBlob -cnotmatch ''^[a-f0-9]{40}$''', '$rawBlob -cne $expectedBlob',
            'Raw held worktree bytes do not match immutable HEAD blob'
        )) -and $blobIdentity.IndexOf('hash-object', [StringComparison]::OrdinalIgnoreCase) -lt 0 -and
        (Test-TokensInOrder -Source $rowSchema -Needles @(
            "[ValidateSet('in_memory', 'json')]", 'Assert-LocalExactPropertyNames',
            '$byteLengthHasExactType = if ($Representation -ceq ''in_memory'')',
            '$byteLength -is [int64]', '$byteLength -is [int32] -or $byteLength -is [int64]',
            '-not $byteLengthHasExactType', "`$rawBlob -cnotmatch '^[a-f0-9]{40}$'",
            '$rawBlob -cne $expectedBlob', 'does not bind raw held bytes to its immutable HEAD repository blob'
        )) -and
        (Test-TokensInOrder -Source $rowMatches -Needles @(
            "`$ExpectedRepresentation -ceq 'in_memory'", '$expectedValue -is [int64]',
            "`$ObservedRepresentation -ceq 'in_memory'", '$observedValue -is [int64]',
            '-not $expectedTypeValid', '-not $observedTypeValid',
            '[int64]$observedValue -ne [int64]$expectedValue'
        )) -and
        (Test-TokensInOrder -Source $receiptSchema -Needles @(
            "[ValidateSet('in_memory', 'json')]", 'Assert-LocalExactPropertyNames',
            '$inputCount -isnot [int32]', '$inputs -isnot [object[]]',
            'Assert-SourceCustodyReceiptSchema', '-Receipt $PreReceipt', '-Phase pre', '-Representation json',
            '$custodyComplete -isnot [bool]',
            'Assert-SourceCustodyRowSchema', '-Row $row', '-Phase $Phase', '-Representation $Representation',
            '-ExpectedRepresentation in_memory', '-ObservedRepresentation $Representation',
            '-ExpectedRepresentation json', '-ObservedRepresentation $Representation'
        )) -and
        (Test-TokensInOrder -Source $open -Needles @(
        '[IO.FileMode]::Open', '[IO.FileAccess]::Read', '[IO.FileShare]::Read'
    )) -and $open.IndexOf('ReadWrite', [StringComparison]::Ordinal) -lt 0 -and
        $open.IndexOf('[IO.FileShare]::Delete', [StringComparison]::Ordinal) -lt 0 -and
        (Test-TokensInOrder -Source $receipt -Needles @(
            '[IO.FileMode]::CreateNew', '[IO.FileAccess]::ReadWrite', '[IO.FileShare]::Read',
            '$stream.Flush($true)', 'Get-HeldFileDigests -Stream $stream',
            'ConvertFrom-ExactJsonObjectText', 'bytes differ from the in-memory receipt'
        )) -and $receipt.IndexOf('[IO.FileShare]::ReadWrite', [StringComparison]::Ordinal) -lt 0 -and
        $receipt.IndexOf('[IO.FileShare]::Delete', [StringComparison]::Ordinal) -lt 0 -and
        (Test-TokensInOrder -Source $new -Needles @(
            'Get-TrackedSourceDescriptors',
            'Open-SourceCustodyHandle -Path $path',
            '$script:SourceCustodyStreams.Add($stream)',
            '$digests = Get-HeldFileDigests -Stream $stream',
            'expected_git_mode = [string]$descriptor.expected_git_mode',
            'raw_git_blob = [string]$digests.raw_git_blob',
            'pre_sha256 = [string]$digests.sha256',
            'Assert-RepositoryBlobIdentity',
            "check_id = 'rw06_2_source_custody_pre'",
            'Assert-SourceCustodyReceiptSchema',
            'New-LockedJsonReceipt -Path $SourceCustodyPrePath',
            '$script:SourceCustodyPreStream = $lockedPreReceipt.stream',
            '$script:SourceCustodyPreSha256 = [string]$lockedPreReceipt.sha256'
        )) -and
        (Test-TokensInOrder -Source $assert -Needles @(
            'Assert-SourceCustodyRowSchema', '$stream.CanRead', 'Get-HeldFileDigests -Stream $stream',
            '$digests.raw_git_blob -cne $row.raw_git_blob', '$digests.raw_git_blob -cne $expectedBlob',
            'Custodied source input changed', 'Get-HeldFileDigests -Stream $script:SourceCustodyPreStream',
            'Assert-SourceCustodyReceiptSchema',
            'Get-HeldFileDigests -Stream $script:SourceCustodyFinalStream'
        )) -and
        (Test-TokensInOrder -Source $invoke -Needles @(
            'Assert-SourceCustody', '$process = Microsoft.PowerShell.Management\Start-Process', '$process.WaitForExit()',
            'Assert-SourceCustody', '$proof = Assert-OneRunEvidence'
        )) -and
        (Test-TokensInOrder -Source $complete -Needles @(
            'Assert-SourceCustody', 'Get-HeldFileDigests -Stream $script:SourceCustodyStreams[$index]',
            'post_sha256 = [string]$postDigests.sha256',
            "check_id = 'rw06_2_source_custody_final'", 'custody_complete = $true',
            'New-LockedJsonReceipt -Path $SourceCustodyFinalPath',
            '$script:SourceCustodyFinalStream = $lockedFinalReceipt.stream',
            '$script:SourceCustodyComplete = $true', 'Assert-SourceCustody'
        )) -and (Test-TokensInOrder -Source $close -Needles @(
            '$script:SourceCustodyPreStream.Dispose()', '$script:SourceCustodyFinalStream.Dispose()',
            'foreach ($stream in @($script:EvidenceArtifactStreams))', '$script:SourceCustodyStreams.Clear()'
        )) -and
        (Test-TokensInOrder -Source $topLevel -Needles @(
            'Wait-ExclusiveDrain', 'Assert-RepositoryIdentity', 'New-SourceCustody',
            '. $EvidenceAdmissionTool', 'Assert-SourceCustody', 'foreach ($runIndex in 1..2)',
            'Complete-SourceCustody', '$fixedRepeatQualifying = Test-FixedRepeatQualification',
            'Assert-ManifestArtifactHash -ArtifactRows $artifactRows -Path $SourceCustodyPrePath',
            'Assert-ManifestArtifactHash -ArtifactRows $artifactRows -Path $SourceCustodyFinalPath',
            '$SourceCustodyPrePath, $SourceCustodyFinalPath',
            'Assert-SourceCustody',
            'Close-SourceCustody'
        ))
}

$retainedPreflightValidator = {
    param($analysis)
    $helper = Get-FunctionSource -Analysis $analysis -Name 'Assert-RetainedHeistPreflightArtifact'
    $oneRun = Get-FunctionSource -Analysis $analysis -Name 'Assert-OneRunEvidence'
    $compare = Get-FunctionSource -Analysis $analysis -Name 'Compare-FixedRunProofs'
    $manifestBinding = Get-FunctionSource -Analysis $analysis -Name 'Assert-FixedRunManifestArtifactBindings'
    $topLevel = Get-ExecutableTopLevelSource -Analysis $analysis
    (Test-TokensInOrder -Source $helper -Needles @(
        "'heist_seed_preflight.json'", 'Test-Path -LiteralPath $path -PathType Leaf',
        'Test-ExactPsCustomObject -Value $InvocationPreflight', 'Test-ExactPsCustomObject -Value $RunPreflight',
        'Open-SourceCustodyHandle -Path $path', '$script:EvidenceArtifactStreams.Add($stream)',
        '$item.Length -le 0', '[IO.FileAttributes]::ReparsePoint', 'Get-HeldFileDigests -Stream $stream',
        'ConvertFrom-ExactJsonObjectText', "`$seed = Get-ExactValueNoEnumerate `$retained @('selection', 'seed_text') `$null",
        '$seed -isnot [string]', 'ConvertTo-CanonicalExactObjectJson -InputObject $InvocationPreflight',
        'ConvertTo-CanonicalExactObjectJson -InputObject $RunPreflight', 'sha256 = [string]$digests.sha256'
    )) -and
        (Test-TokensInOrder -Source $oneRun -Needles @(
            'Test-ExactPsCustomObject -Value $preflight', 'Test-ExactPsCustomObject -Value $runPreflight',
            'ConvertTo-CanonicalExactObjectJson -InputObject $publishedSummaryPreflightAdmission',
            'ConvertTo-CanonicalExactObjectJson -InputObject $publishedRunPreflightAdmission',
            '$retainedPreflightProof = Assert-RetainedHeistPreflightArtifact',
            '$heistSeedPreflightPath = $retainedPreflightProof.path',
            '$heistSeedPreflightHash = $retainedPreflightProof.sha256',
            'heist_seed_preflight = $heistSeedPreflightPath',
            'heist_seed_preflight_sha256 = $heistSeedPreflightHash'
        )) -and
        $compare.IndexOf("'heist_seed_preflight_sha256'", [StringComparison]::Ordinal) -ge 0 -and
        (Test-TokensInOrder -Source $manifestBinding -Needles @(
            "-Path (Get-ExactValueNoEnumerate `$Proof @('heist_seed_preflight') `$null)",
            "-ExpectedSha256 (Get-ExactValueNoEnumerate `$Proof @('heist_seed_preflight_sha256') `$null)",
            '-Label "Run $ExpectedRunIndex retained Heist seed preflight"'
        )) -and
        (Test-TokensInOrder -Source $topLevel -Needles @(
            "(Get-ExactValueNoEnumerate `$proof @('heist_seed_preflight') `$null)",
            '$requiredManifestArtifactKeys.Add($canonicalRequiredArtifact)',
            '$requiredManifestArtifacts.Add($canonicalRequiredArtifact)'
        ))
}
Assert-True -Condition ([bool](& $exactTypeValidator $launcher)) `
    -Message 'Retained admissions, summaries, run records, proofs, or aggregate roles can launder scalar types.'
Assert-True -Condition ([bool](& $sourceCustodyValidator $launcher)) `
    -Message 'Final launcher does not hold and receipt-bind exact execution/production inputs through child execution.'
Assert-True -Condition ([bool](& $retainedPreflightValidator $launcher)) `
    -Message 'Final launcher does not authenticate and explicitly manifest each retained Heist seed preflight file.'
Assert-HostileMutationRejected -Name 'replay-tool-audited-path-substitution' -Validator $replayExecutionBindingValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle "    `$expectedRepositoryPath = 'tools/rw06_2_ending_replay.ps1'" `
        -Replacement "    `$expectedRepositoryPath = 'tools/rw06_2_evidence_admission.ps1'"
}
Assert-HostileMutationRejected -Name 'replay-tool-executed-variable-substitution' -Validator $replayExecutionBindingValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle "'-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', (Get-ValidatedReplayToolPath)," `
        -Replacement "'-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', `$EvidenceAdmissionTool,"
}
Assert-HostileMutationRejected -Name 'replay-tool-late-reassignment' -Validator $replayExecutionBindingValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle '    New-SourceCustody' `
        -Replacement '    New-SourceCustody; $ReplayTool = $EvidenceAdmissionTool'
}
Assert-HostileMutationRejected -Name 'replay-tool-scope-qualified-getter-mutation' -Validator $replayExecutionBindingValidator -Mutate {
    param($source)
    Replace-FunctionSourceOnce -Source $source -FunctionName 'Get-ValidatedReplayToolPath' `
        -Needle '    return $expectedReplayPath' `
        -Replacement "    `$script:ReplayTool = `$EvidenceAdmissionTool`n    return `$expectedReplayPath"
}
Assert-HostileMutationRejected -Name 'replay-tool-literal-execution' -Validator $replayExecutionBindingValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle "'-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', (Get-ValidatedReplayToolPath)," `
        -Replacement "'-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path `$PSScriptRoot 'rw06_2_ending_replay.ps1'),"
}
Assert-HostileMutationRejected -Name 'replay-tool-command-execution' -Validator $replayExecutionBindingValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle "'-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', (Get-ValidatedReplayToolPath)," `
        -Replacement "'-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-Command', (Get-ValidatedReplayToolPath),"
}
Assert-HostileMutationRejected -Name 'replay-tool-held-row-duplicate-accepted' -Validator $replayExecutionBindingValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source -Needle '    if ($rows.Count -ne 1) {' -Replacement '    if ($rows.Count -lt 1) {'
}
Assert-HostileMutationRejected -Name 'replay-tool-held-row-path-substituted' -Validator $replayExecutionBindingValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle "    `$expectedRepositoryPath = 'tools/rw06_2_ending_replay.ps1'" `
        -Replacement "    `$expectedRepositoryPath = 'tools/rw06_2_evidence_admission.ps1'"
}
Assert-HostileMutationRejected -Name 'replay-tool-post-custody-binding-removed' -Validator $replayExecutionBindingValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle '    $null = Get-ValidatedReplayToolPath' `
        -Replacement "    `$null = 'replay-custody-binding-bypassed'"
}
Assert-HostileMutationRejected -Name 'replay-tool-pre-spawn-binding-removed' -Validator $replayExecutionBindingValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle "'-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', (Get-ValidatedReplayToolPath)," `
        -Replacement "'-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', ([IO.Path]::Combine(`$PSScriptRoot, 'rw06_2_ending_replay.ps1')) ,"
}
Assert-HostileMutationRejected -Name 'replay-tool-set-variable-mutation' -Validator $replayExecutionBindingValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle '    New-SourceCustody' `
        -Replacement "    New-SourceCustody`r`n    Set-Variable -Name ReplayTool -Value `$EvidenceAdmissionTool"
}
Assert-HostileMutationRejected -Name 'replay-tool-variable-provider-mutation' -Validator $replayExecutionBindingValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle '    New-SourceCustody' `
        -Replacement "    New-SourceCustody`r`n    Set-Item -LiteralPath Variable:ReplayTool -Value `$EvidenceAdmissionTool"
}
Assert-HostileMutationRejected -Name 'replay-tool-get-variable-member-mutation' -Validator $replayExecutionBindingValidator -Mutate {
    param($source)
    Replace-FunctionSourceOnce `
        -Source $source `
        -FunctionName 'Get-ValidatedReplayToolPath' `
        -Needle '    return $expectedReplayPath' `
        -Replacement "    (Get-Variable -Name ReplayTool -Scope Script).Value = `$EvidenceAdmissionTool`n    return `$expectedReplayPath"
}
Assert-HostileMutationRejected -Name 'replay-tool-session-state-member-mutation' -Validator $replayExecutionBindingValidator -Mutate {
    param($source)
    Replace-FunctionSourceOnce `
        -Source $source `
        -FunctionName 'Get-ValidatedReplayToolPath' `
        -Needle '    return $expectedReplayPath' `
        -Replacement "    `$ExecutionContext.SessionState.PSVariable.Set('ReplayTool', `$EvidenceAdmissionTool)`n    return `$expectedReplayPath"
}
Assert-HostileMutationRejected -Name 'replay-tool-callstack-conditioned-getter-mutation' -Validator $replayExecutionBindingValidator -Mutate {
    param($source)
    Replace-FunctionSourceOnce `
        -Source $source `
        -FunctionName 'Get-ValidatedReplayToolPath' `
        -Needle '    return $expectedReplayPath' `
        -Replacement "    if ((Get-PSCallStack).Count -gt 1) { return `$EvidenceAdmissionTool }`n    return `$expectedReplayPath"
}
Assert-ReplayHostileMutationRejected -Name 'cheat-continue-post-restore-proof-removed' -Validator $cheatContinuePlayabilityValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle "        Assert-CheatRourkeDuelBeforeHandOne -Context 'after relaunch and Continue'" `
        -Replacement "        `$null = 'post-continue-duel-proof-bypassed'"
}
Assert-ReplayHostileMutationRejected -Name 'cheat-continue-visible-deal-identity-substituted' -Validator $cheatContinuePlayabilityValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle "        `$selection.action -isnot [string] -or `$selection.action -cne 'blackjack_deal' -or" `
        -Replacement "        `$selection.action -isnot [string] -or `$selection.action -cne 'blackjack_hit' -or"
}
Assert-ReplayHostileMutationRejected -Name 'cheat-continue-duel-bool-type-laundered' -Validator $cheatContinuePlayabilityValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle '        $selection.index -isnot [int32] -or $selection.index -ne 0) {' `
        -Replacement '        [int]$selection.index -ne 0) {'
}
Assert-HostileMutationRejected -Name 'exclusive-admission-bypass' -Validator $exclusiveAdmissionValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source -Needle '        New-OwnedExclusiveLease' -Replacement "        `$null = 'exclusive-lease-bypassed'"
}
Assert-HostileMutationRejected -Name 'exclusive-drain-bypass' -Validator $exclusiveAdmissionValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source -Needle '    Wait-ExclusiveDrain' -Replacement "    `$null = 'exclusive-drain-bypassed'"
}
Assert-HostileMutationRejected -Name 'partial-exclusive-cleanup-disabled' -Validator $exclusiveLeaseCreationValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source -Needle '        $created = $true' -Replacement '        $created = $false'
}
Assert-HostileMutationRejected -Name 'profile-env-after-spawn' -Validator $spawnCustodyValidator -Mutate {
    param($source)
    $mutated = Replace-SourceOnce -Source $source -Needle '        $env:APPDATA = $profileRoaming' -Replacement '        $null = $profileRoaming'
    Replace-SourceOnce -Source $mutated -Needle '            -WindowStyle Hidden -PassThru' `
        -Replacement "            -WindowStyle Hidden -PassThru`r`n        `$env:APPDATA = `$profileRoaming"
}
Assert-HostileMutationRejected -Name 'post-spawn-registration-cleanup-bypass' -Validator $spawnCustodyValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle '                Stop-UnregisteredReplayProcess -Process $process -SessionPrefix $sessionPrefix' `
        -Replacement '                $null = $registrationFailure'
}
Assert-HostileMutationRejected -Name 'proof-compare-bypass' -Validator $proofPromotionValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle '    $script:CanonicalProof = Compare-FixedRunProofs -Proofs @($script:RunProofs)' `
        -Replacement '    $script:CanonicalProof = [pscustomobject]@{ deterministic = $true; isolated_profiles = $true }'
}
Assert-HostileMutationRejected -Name 'qualification-hardcode' -Validator $qualificationValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source -Needle '$RunProofs.Count -ne 2' -Replacement '$false'
}
Assert-HostileMutationRejected -Name 'child-iteration-qualification-bypass' -Validator $childIterationBoundaryValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle '        $runQualification -isnot [string] -or $runQualification -cne ''non_qualifying_development_iteration'' -or' `
        -Replacement '        $false -or'
}
Assert-HostileMutationRejected -Name 'checkpoint-path-binding-bypass' -Validator $exactPathValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle "`$publishedCheckpointAfterPath = Get-ExactValueNoEnumerate `$run @('persistence_checkpoint_after') `$null" `
        -Replacement "`$publishedCheckpointAfterPath = Get-ExactValueNoEnumerate `$run @('untrusted_checkpoint_after') `$null"
}
Assert-HostileMutationRejected -Name 'checkpoint-expected-path-alias' -Validator $exactPathValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle '        -ExpectedPath $checkpointAfterPath `' `
        -Replacement '        -ExpectedPath $checkpointBeforePath `'
}
Assert-HostileMutationRejected -Name 'profile-artifact-substitution' -Validator $profileArtifactValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle "`$profileInventoryPath = Join-Path `$profileSessionRoot 'profile_inventory.json'" `
        -Replacement "`$profileInventoryPath = Join-Path `$profileSessionRoot 'profile_inventory.disabled'"
}
Assert-HostileMutationRejected -Name 'survivor-custody-bypass' -Validator $survivorCustodyValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle '                    $custodyResult = Set-ExclusiveLeaseSurvivorCustody -Survivors $survivorCustody' `
        -Replacement '                    $custodyResult = $null'
}
Assert-HostileMutationRejected -Name 'survivor-custody-launcher-owner' -Validator $survivorCustodyValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source -Needle '            pid = [int]$livePids[0]' -Replacement '            pid = $PID'
}
Assert-HostileMutationRejected -Name 'survivor-custody-nonsurvivor-guards' -Validator $survivorCustodyValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source -Needle '            guard_pids = @($livePids)' -Replacement '            guard_pids = @($PID)'
}
Assert-HostileMutationRejected -Name 'manifest-before-summary' -Validator $manifestOrderValidator -Mutate {
    param($source)
    $needle = '$aggregateSummaryJson = $aggregateSummary | Microsoft.PowerShell.Utility\ConvertTo-Json -Depth 20'
    $replacement = '$artifactRows = @(Get-ManifestArtifactPaths)' + "`r`n" + $needle
    Replace-SourceOnce -Source $source -Needle $needle -Replacement $replacement
}
Assert-HostileMutationRejected -Name 'launcher-snapshot-manifest-hash-bypass' -Validator $snapshotBindingValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle '-ExpectedSha256 $script:LauncherInitialSha256 -Label ''Immutable launcher snapshot''' `
        -Replacement '-ExpectedSha256 $script:SourceCustodyPreSha256 -Label ''Immutable launcher snapshot'''
}
Assert-HostileMutationRejected -Name 'aggregate-evidence-root-force-reuse' -Validator $freshEvidenceRootValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle 'New-Item -ItemType Directory -Path $EvidenceRoot | Out-Null' `
        -Replacement 'New-Item -ItemType Directory -Path $EvidenceRoot -Force | Out-Null'
}
Assert-HostileMutationRejected -Name 'proof-derived-manifest-population-omitted' -Validator $manifestClosureValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle "        (Get-ExactValueNoEnumerate `$proof @('replay_summary') `$null)," `
        -Replacement "        '',"
}
Assert-HostileMutationRejected -Name 'outer-launcher-stdout-manifest-population-omitted' -Validator $manifestClosureValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle "        (Get-ExactValueNoEnumerate `$proof @('launcher_stdout') `$null)," `
        -Replacement "        '',"
}
Assert-HostileMutationRejected -Name 'retained-run-summary-manifest-population-omitted' -Validator $manifestClosureValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle "        (Get-ExactValueNoEnumerate `$proof @('run_summary') `$null)," `
        -Replacement "        '',"
}
Assert-HostileMutationRejected -Name 'required-manifest-duplicate-guard-removed' -Validator $manifestClosureValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle '$requiredManifestArtifactKeys = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)' `
        -Replacement '$requiredManifestArtifactKeys = [Collections.Generic.List[string]]::new()'
}
Assert-HostileMutationRejected -Name 'aggregate-summary-role-relabel' -Validator $aggregateSummaryValidator -Mutate {
    param($source)
    Replace-TopLevelHashtableValue -Source $source -VariableName 'aggregateSummary' -PropertyName 'role' -Replacement "'fresh_interactive'"
}
Assert-HostileMutationRejected -Name 'aggregate-summary-check-id-relabel' -Validator $aggregateSummaryValidator -Mutate {
    param($source)
    Replace-TopLevelHashtableValue -Source $source -VariableName 'aggregateSummary' -PropertyName 'check_id' -Replacement "'rw06_2_fresh_interactive_evidence'"
}
Assert-HostileMutationRejected -Name 'aggregate-summary-evidence-role-relabel' -Validator $aggregateSummaryValidator -Mutate {
    param($source)
    Replace-TopLevelHashtableValue -Source $source -VariableName 'aggregateSummary' -PropertyName 'evidence_role' -Replacement "'fresh-interactive'"
}
Assert-HostileMutationRejected -Name 'aggregate-summary-repeat-relabel' -Validator $aggregateSummaryValidator -Mutate {
    param($source)
    Replace-TopLevelHashtableValue -Source $source -VariableName 'aggregateSummary' -PropertyName 'repeat' -Replacement '1'
}
Assert-HostileMutationRejected -Name 'aggregate-summary-fresh-authorization-enabled' -Validator $aggregateSummaryValidator -Mutate {
    param($source)
    Replace-TopLevelHashtableValue -Source $source -VariableName 'aggregateSummary' -PropertyName 'fresh_interactive_authorized' -Replacement '$true'
}
Assert-HostileMutationRejected -Name 'aggregate-summary-q017-status-relabel' -Validator $aggregateSummaryValidator -Mutate {
    param($source)
    Replace-TopLevelHashtableValue -Source $source -VariableName 'aggregateSummary' -PropertyName 'q017_status' `
        -Replacement "if (`$Ending -ceq 'heist') { 'OPEN' } else { 'NOT_APPLICABLE' }"
}
Assert-HostileMutationRejected -Name 'metadata-role-relabel' -Validator $metadataLabelValidator -Mutate {
    param($source)
    Replace-TopLevelHashtableValue -Source $source -VariableName 'metadata' -PropertyName 'role' -Replacement "'fresh_interactive'"
}
Assert-HostileMutationRejected -Name 'metadata-lane-relabel' -Validator $metadataLabelValidator -Mutate {
    param($source)
    Replace-TopLevelHashtableValue -Source $source -VariableName 'metadata' -PropertyName 'lane' -Replacement "'rw06_2p_fresh'"
}
Assert-HostileMutationRejected -Name 'metadata-kind-relabel' -Validator $metadataLabelValidator -Mutate {
    param($source)
    Replace-TopLevelHashtableValue -Source $source -VariableName 'metadata' -PropertyName 'kind' -Replacement "'fresh-interactive-final-evidence'"
}
Assert-HostileMutationRejected -Name 'metadata-evidence-role-relabel' -Validator $metadataLabelValidator -Mutate {
    param($source)
    Replace-TopLevelHashtableValue -Source $source -VariableName 'metadata' -PropertyName 'evidence_role' -Replacement "'fresh-interactive'"
}
Assert-HostileMutationRejected -Name 'manifest-role-relabel' -Validator $manifestLabelValidator -Mutate {
    param($source)
    Replace-TopLevelHashtableValue -Source $source -VariableName 'manifest' -PropertyName 'role' -Replacement "'fresh_interactive'"
}
Assert-HostileMutationRejected -Name 'manifest-check-id-relabel' -Validator $manifestLabelValidator -Mutate {
    param($source)
    Replace-TopLevelHashtableValue -Source $source -VariableName 'manifest' -PropertyName 'check_id' -Replacement "'rw06_2_fresh_interactive_manifest'"
}
Assert-HostileMutationRejected -Name 'manifest-evidence-role-relabel' -Validator $manifestLabelValidator -Mutate {
    param($source)
    Replace-TopLevelHashtableValue -Source $source -VariableName 'manifest' -PropertyName 'evidence_role' -Replacement "'fresh-interactive'"
}
Assert-HostileMutationRejected -Name 'manifest-culture-sensitive-order' -Validator $manifestOrderValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle '[Array]::Sort($orderedPaths, [StringComparer]::OrdinalIgnoreCase)' `
        -Replacement '$orderedPaths = @($orderedPaths | Sort-Object -Unique)'
}
Assert-HostileMutationRejected -Name 'proof-path-outer-run-unbound' -Validator $proofPathGraphValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle "`$expectedOuterRunRoot = [IO.Path]::GetFullPath((Join-Path `$EvidenceRoot ('run-{0:D2}' -f `$runIndex)))" `
        -Replacement "`$expectedOuterRunRoot = [IO.Path]::GetFullPath((Join-Path `$EvidenceRoot 'run-01'))"
}
Assert-HostileMutationRejected -Name 'proof-path-replay-pid-unbound' -Validator $proofPathGraphValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle "`$expectedInvocationPattern = '^\d{8}-\d{6}-\d{3}-' + [regex]::Escape([string]`$replayPid) + '$'" `
        -Replacement "`$expectedInvocationPattern = '^\d{8}-\d{6}-\d{3}-\d+$'"
}
Assert-HostileMutationRejected -Name 'proof-path-session-date-unbound' -Validator $proofPathGraphValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle '$sessionDateName -cne $expectedSessionDateName -or' `
        -Replacement '$false -or'
}
Assert-HostileMutationRejected -Name 'terminal-aggregate-schema-call-removed' -Validator $terminalSchemaValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle "Assert-TerminalAggregateShape -Record `$aggregateSummary -Representation ordered -Label 'In-memory aggregate summary'" `
        -Replacement '$null = $aggregateSummary'
}
Assert-HostileMutationRejected -Name 'terminal-metadata-schema-call-removed' -Validator $terminalSchemaValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle "Assert-TerminalMetadataShape -Record `$metadata -Representation ordered -Label 'In-memory run metadata'" `
        -Replacement '$null = $metadata'
}
Assert-HostileMutationRejected -Name 'terminal-manifest-schema-call-removed' -Validator $terminalSchemaValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle "Assert-TerminalManifestShape -Record `$manifest -Representation ordered -Label 'In-memory artifact manifest'" `
        -Replacement '$null = $manifest'
}
Assert-HostileMutationRejected -Name 'terminal-result-schema-call-removed' -Validator $terminalSchemaValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle "-Label 'In-memory terminal stdout result'" `
        -Replacement "-Label 'hostile terminal stdout result'"
}
Assert-HostileMutationRejected -Name 'terminal-retained-manifest-readback-removed' -Validator $terminalSchemaValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle "Assert-TerminalManifestShape -Record `$retainedManifest -Representation json -Label 'Retained artifact manifest'" `
        -Replacement '$null = $retainedManifest'
}
Assert-HostileMutationRejected -Name 'terminal-aggregate-schema-call-unreachable' -Validator $terminalSchemaValidator -Mutate {
    param($source)
    $call = "Assert-TerminalAggregateShape -Record `$aggregateSummary -Representation ordered -Label 'In-memory aggregate summary'"
    Replace-SourceOnce -Source $source -Needle $call -Replacement "if (`$false) { $call }"
}
Assert-HostileMutationRejected -Name 'terminal-serialized-metadata-schema-call-removed' -Validator $terminalSchemaValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle "Assert-TerminalMetadataShape -Record `$expectedMetadata -Representation json -Label 'Serialized run metadata'" `
        -Replacement '$null = $expectedMetadata'
}
Assert-HostileMutationRejected -Name 'terminal-serialized-manifest-schema-call-removed' -Validator $terminalSchemaValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle "Assert-TerminalManifestShape -Record `$expectedManifest -Representation json -Label 'Serialized artifact manifest'" `
        -Replacement '$null = $expectedManifest'
}
foreach ($labelBypassSpec in @(
    [pscustomobject]@{ function_name = 'Assert-TerminalAggregateShape'; label = 'In-memory aggregate summary' },
    [pscustomobject]@{ function_name = 'Assert-TerminalMetadataShape'; label = 'In-memory run metadata' },
    [pscustomobject]@{ function_name = 'Assert-TerminalManifestShape'; label = 'In-memory artifact manifest' },
    [pscustomobject]@{ function_name = 'Assert-TerminalResultShape'; label = 'In-memory terminal stdout result' }
)) {
    $capturedBypassSpec = $labelBypassSpec
    Assert-HostileMutationRejected `
        -Name ("terminal-production-label-bypass-{0}" -f $capturedBypassSpec.function_name) `
        -Validator $terminalSchemaValidator `
        -Mutate {
            param($source)
            $needle = "    )`n    Assert-TerminalRecordKeys"
            $replacement = "    )`n    if (`$Label -ceq '$($capturedBypassSpec.label)') { return }`n    Assert-TerminalRecordKeys"
            Replace-FunctionSourceOnce `
                -Source $source `
                -FunctionName $capturedBypassSpec.function_name `
                -Needle $needle `
                -Replacement $replacement
        }
}
Assert-HostileMutationRejected -Name 'terminal-function-provider-shadow' -Validator $terminalSchemaValidator -Mutate {
    param($source)
    $call = "Assert-TerminalAggregateShape -Record `$aggregateSummary -Representation ordered -Label 'In-memory aggregate summary'"
    Replace-SourceOnce -Source $source -Needle $call `
        -Replacement "Set-Item -Path Function:\Assert-TerminalAggregateShape -Value { param(`$Record, `$Representation, `$Label) }`r`n$call"
}
Assert-HostileMutationRejected -Name 'terminal-plain-start-process-function-shadow' -Validator $terminalSchemaValidator -Mutate {
    param($source)
    Replace-SourceOnce `
        -Source $source `
        -Needle 'function Get-FailureMessage {' `
        -Replacement "function Start-Process { param(`$ArgumentList) throw 'shadowed' }`n`nfunction Get-FailureMessage {"
}
Assert-HostileMutationRejected -Name 'terminal-contract-context-validator-wrapper' -Validator $terminalSchemaValidator -Mutate {
    param($source)
    Replace-FunctionSourceOnce `
        -Source $source `
        -FunctionName 'Assert-TerminalArtifactRowShape' `
        -Needle '    Assert-TerminalRecordKeys' `
        -Replacement "    if (`$null -ne (Get-Variable -Name runtimeValidCaseCount -Scope Script -ErrorAction SilentlyContinue)) {`n        throw 'contract-only branch'`n    }`n    Assert-TerminalRecordKeys"
}
foreach ($aliasCommand in @('Set-Alias', 'set-alias', 'sal')) {
    $capturedAliasCommand = $aliasCommand
    Assert-HostileMutationRejected `
        -Name ("terminal-alias-shadow-{0}" -f $capturedAliasCommand) `
        -Validator $terminalSchemaValidator `
        -Mutate {
            param($source)
            $call = "Assert-TerminalAggregateShape -Record `$aggregateSummary -Representation ordered -Label 'In-memory aggregate summary'"
            Replace-SourceOnce -Source $source -Needle $call `
                -Replacement "$capturedAliasCommand -Name Assert-TerminalAggregateShape -Value Write-Output`r`n$call"
        }
}
Assert-HostileMutationRejected -Name 'terminal-retained-manifest-equality-removed' -Validator $terminalSchemaValidator -Mutate {
    param($source)
    $needle = @'
if ((ConvertTo-CanonicalExactObjectJson -InputObject $retainedManifest -Label 'Retained artifact manifest') -cne
    (ConvertTo-CanonicalExactObjectJson -InputObject $expectedManifest -Label 'Serialized artifact manifest')) {
    throw 'Retained artifact manifest differs from its exact in-memory serialization.'
}
'@
    Replace-SourceOnce -Source $source -Needle $needle -Replacement '$null = $retainedManifest'
}
Assert-HostileMutationRejected -Name 'terminal-retained-aggregate-equality-removed' -Validator $terminalSchemaValidator -Mutate {
    param($source)
    $needle = @'
if ((ConvertTo-CanonicalExactObjectJson -InputObject $retainedAggregateSummary -Label 'Retained aggregate summary') -cne
    (ConvertTo-CanonicalExactObjectJson -InputObject $expectedAggregateSummary -Label 'Serialized aggregate summary')) {
    throw 'Retained aggregate summary differs from its exact in-memory serialization.'
}
'@
    Replace-SourceOnce -Source $source -Needle $needle -Replacement '$null = $retainedAggregateSummary'
}
Assert-HostileMutationRejected -Name 'terminal-retained-metadata-equality-removed' -Validator $terminalSchemaValidator -Mutate {
    param($source)
    $needle = @'
if ((ConvertTo-CanonicalExactObjectJson -InputObject $retainedMetadata -Label 'Retained run metadata') -cne
    (ConvertTo-CanonicalExactObjectJson -InputObject $expectedMetadata -Label 'Serialized run metadata')) {
    throw 'Retained run metadata differs from its exact in-memory serialization.'
}
'@
    Replace-SourceOnce -Source $source -Needle $needle -Replacement '$null = $retainedMetadata'
}
Assert-HostileMutationRejected -Name 'terminal-extra-aggregate-rewrite-after-validation' -Validator $terminalSchemaValidator -Mutate {
    param($source)
    $needle = @'
if ((ConvertTo-CanonicalExactObjectJson -InputObject $retainedAggregateSummary -Label 'Retained aggregate summary') -cne
    (ConvertTo-CanonicalExactObjectJson -InputObject $expectedAggregateSummary -Label 'Serialized aggregate summary')) {
    throw 'Retained aggregate summary differs from its exact in-memory serialization.'
}
'@
    Replace-SourceOnce -Source $source -Needle $needle `
        -Replacement ($needle + "`$forgedAggregate = '{}'`n`$forgedAggregate | Microsoft.PowerShell.Management\Set-Content -LiteralPath `$AggregateSummaryPath -Encoding utf8`n")
}
Assert-HostileMutationRejected -Name 'terminal-result-output-unreachable' -Validator $terminalSchemaValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle 'Microsoft.PowerShell.Utility\ConvertTo-Json -InputObject $retainedResult -Depth 8' `
        -Replacement 'if ($false) { Microsoft.PowerShell.Utility\ConvertTo-Json -InputObject $retainedResult -Depth 8 }'
}
Assert-HostileMutationRejected -Name 'terminal-result-output-preceded-by-environment-exit' -Validator $terminalSchemaValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle 'Microsoft.PowerShell.Utility\ConvertTo-Json -InputObject $retainedResult -Depth 8' `
        -Replacement "[Environment]::Exit(0)`nMicrosoft.PowerShell.Utility\ConvertTo-Json -InputObject `$retainedResult -Depth 8"
}
Assert-HostileMutationRejected -Name 'terminal-pre-tail-forged-output-environment-exit' -Validator $terminalSchemaValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle '$aggregateSummary = [ordered]@{' `
        -Replacement "Microsoft.PowerShell.Utility\Write-Output '{`"outcome`":`"green`"}'`n[Environment]::Exit(0)`n`$aggregateSummary = [ordered]@{"
}
Assert-HostileMutationRejected -Name 'terminal-pre-tail-host-set-should-exit' -Validator $terminalSchemaValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle '$aggregateSummary = [ordered]@{' `
        -Replacement "`$Host.SetShouldExit(0)`n`$aggregateSummary = [ordered]@{"
}
Assert-HostileMutationRejected -Name 'terminal-pre-tail-powershell-return' -Validator $terminalSchemaValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle '$aggregateSummary = [ordered]@{' `
        -Replacement "return`n`$aggregateSummary = [ordered]@{"
}
Assert-HostileMutationRejected -Name 'terminal-pre-tail-powershell-exit' -Validator $terminalSchemaValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle '$aggregateSummary = [ordered]@{' `
        -Replacement "exit 0`n`$aggregateSummary = [ordered]@{"
}
Assert-HostileMutationRejected -Name 'terminal-compare-callstack-context-bypass' -Validator $terminalCanonicalAuthorityValidator -Mutate {
    param($source)
    Replace-FunctionSourceOnce -Source $source -FunctionName 'Compare-FixedRunProofs' `
        -Needle '    param([Parameter(Mandatory = $true)]$Proofs)' `
        -Replacement "    param([Parameter(Mandatory = `$true)]`$Proofs)`n    if ((Get-PSCallStack).Count -gt 1) { `$Proofs[0].action_count = `$Proofs[1].action_count }"
}
Assert-HostileMutationRejected -Name 'terminal-close-custody-artifact-rewrite' -Validator $terminalSchemaValidator -Mutate {
    param($source)
    Replace-FunctionSourceOnce -Source $source -FunctionName 'Close-SourceCustody' `
        -Needle '    $script:EvidenceArtifactStreams.Clear()' `
        -Replacement "    `$script:EvidenceArtifactStreams.Clear()`n    'forged' | Microsoft.PowerShell.Management\Set-Content -LiteralPath `$script:RunProofs[0].run_summary -Encoding utf8"
}
Assert-HostileMutationRejected -Name 'terminal-post-seal-artifact-rewrite' -Validator $terminalSchemaValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle '$sealedManifestSha256 = (Microsoft.PowerShell.Utility\Get-FileHash `' `
        -Replacement @'
'forged' | Microsoft.PowerShell.Management\Set-Content -LiteralPath $finalRetainedManifest.artifacts[0].path -Encoding utf8
$sealedManifestSha256 = (Microsoft.PowerShell.Utility\Get-FileHash `
'@
}
Assert-HostileMutationRejected -Name 'terminal-retained-result-reflection-mutation' -Validator $terminalSchemaValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle 'Microsoft.PowerShell.Utility\ConvertTo-Json -InputObject $retainedResult -Depth 8' `
        -Replacement "(Get-Variable -Name retainedResult -Scope Script).Value = [pscustomobject]@{ outcome = 'green' }`nMicrosoft.PowerShell.Utility\ConvertTo-Json -InputObject `$retainedResult -Depth 8"
}
Assert-HostileMutationRejected -Name 'terminal-canonical-recompute-replaced-by-held-proof' -Validator $terminalCanonicalAuthorityValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle '$recomputedCanonicalProof = Compare-FixedRunProofs -Proofs @($script:RunProofs)' `
        -Replacement '$recomputedCanonicalProof = $script:CanonicalProof'
}
Assert-HostileMutationRejected -Name 'terminal-canonical-post-promotion-member-mutation' -Validator $terminalCanonicalAuthorityValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle '    $script:CanonicalProof = Compare-FixedRunProofs -Proofs @($script:RunProofs)' `
        -Replacement "    `$script:CanonicalProof = Compare-FixedRunProofs -Proofs @(`$script:RunProofs)`n    `$script:CanonicalProof.transcript_sha256 = 'f' * 64"
}
Assert-HostileMutationRejected -Name 'terminal-run-proof-post-promotion-member-mutation' -Validator $terminalCanonicalAuthorityValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle '    $script:CanonicalProof = Compare-FixedRunProofs -Proofs @($script:RunProofs)' `
        -Replacement "    `$script:CanonicalProof = Compare-FixedRunProofs -Proofs @(`$script:RunProofs)`n    `$script:RunProofs[0].transcript_sha256 = 'f' * 64"
}
Assert-HostileMutationRejected -Name 'terminal-run-proof-post-promotion-alias-mutation' -Validator $terminalCanonicalAuthorityValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle '    $script:CanonicalProof = Compare-FixedRunProofs -Proofs @($script:RunProofs)' `
        -Replacement @'
    $script:CanonicalProof = Compare-FixedRunProofs -Proofs @($script:RunProofs)
    $proofAlias0 = $script:RunProofs[0]
    $proofAlias1 = $script:RunProofs[1]
    $proofAlias0.action_count = [int32]1
    $proofAlias1.action_count = [int32]1
'@
}
Assert-HostileMutationRejected -Name 'terminal-canonical-proof-post-promotion-alias-mutation' -Validator $terminalCanonicalAuthorityValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle '    $script:CanonicalProof = Compare-FixedRunProofs -Proofs @($script:RunProofs)' `
        -Replacement @'
    $script:CanonicalProof = Compare-FixedRunProofs -Proofs @($script:RunProofs)
    $canonicalAlias = $script:CanonicalProof
    $canonicalAlias.transcript_sha256 = 'f' * 64
'@
}
$proofBindingCall = @'
    Assert-FixedRunManifestArtifactBindings `
        -ArtifactRows $artifactRows `
        -Proof $proof `
        -ExpectedRunIndex ($proofOffset + 1)
'@
Assert-HostileMutationRejected -Name 'manifest-proof-binding-call-unreachable' -Validator $manifestProofBindingValidator -Mutate {
    param($source)
    $wrapped = "    if (`$false) {`n" + $proofBindingCall + "    }"
    Replace-SourceOnce -Source $source -Needle $proofBindingCall -Replacement $wrapped
}
Assert-HostileMutationRejected -Name 'manifest-proof-binding-call-skipped-by-continue' -Validator $manifestProofBindingValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source -Needle $proofBindingCall -Replacement ("    continue`n" + $proofBindingCall)
}
Assert-HostileMutationRejected -Name 'manifest-run-proof-hash-binding-removed' -Validator $manifestProofBindingValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle "-ExpectedSha256 (Get-ExactValueNoEnumerate `$Proof @('replay_summary_sha256') `$null)" `
        -Replacement "-ExpectedSha256 (Get-Sha256 -Path (Get-ExactValueNoEnumerate `$Proof @('replay_summary') `$null))"
}
Assert-HostileMutationRejected -Name 'manifest-hash-production-context-self-authorization' -Validator $manifestProofBindingValidator -Mutate {
    param($source)
    Replace-FunctionSourceOnce `
        -Source $source `
        -FunctionName 'Assert-ManifestArtifactHash' `
        -Needle '    $expectedPath = [IO.Path]::GetFullPath($Path)' `
        -Replacement @'
    if ($null -eq (Get-Variable -Name runtimeValidCaseCount -Scope Script -ErrorAction SilentlyContinue)) {
        $ExpectedSha256 = Get-Sha256 -Path $Path
    }
    $expectedPath = [IO.Path]::GetFullPath($Path)
'@
}
Assert-HostileMutationRejected -Name 'manifest-hash-pscommandpath-self-authorization' -Validator $manifestProofBindingValidator -Mutate {
    param($source)
    Replace-FunctionSourceOnce `
        -Source $source `
        -FunctionName 'Assert-ManifestArtifactHash' `
        -Needle '    $expectedPath = [IO.Path]::GetFullPath($Path)' `
        -Replacement @'
    if ($PSCommandPath -like '*rw06_2_final_evidence.ps1') {
        $ExpectedSha256 = Get-Sha256 -Path $Path
    }
    $expectedPath = [IO.Path]::GetFullPath($Path)
'@
}
Assert-HostileMutationRejected -Name 'manifest-aggregate-summary-hash-binding-removed' -Validator $manifestProofBindingValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle '-ExpectedSha256 $aggregateSummarySha256 -Label ''Aggregate summary''' `
        -Replacement '-ExpectedSha256 $script:SourceCustodyPreSha256 -Label ''Aggregate summary'''
}
Assert-HostileMutationRejected -Name 'manifest-metadata-hash-binding-removed' -Validator $manifestProofBindingValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle '-ExpectedSha256 $metadataSha256 -Label ''Run metadata''' `
        -Replacement '-ExpectedSha256 $script:SourceCustodyPreSha256 -Label ''Run metadata'''
}
Assert-HostileMutationRejected -Name 'manifest-launcher-stdout-hash-binding-removed' -Validator $manifestProofBindingValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle '-Label "Run $ExpectedRunIndex outer launcher stdout"' `
        -Replacement '-Label "Run $ExpectedRunIndex outer launcher output"'
}
Assert-HostileMutationRejected -Name 'manifest-launcher-stderr-hash-binding-removed' -Validator $manifestProofBindingValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle '-Label "Run $ExpectedRunIndex outer launcher stderr"' `
        -Replacement '-Label "Run $ExpectedRunIndex outer launcher diagnostics"'
}
Assert-HostileMutationRejected -Name 'manifest-run-summary-hash-binding-removed' -Validator $manifestProofBindingValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle '-Label "Run $ExpectedRunIndex retained run summary"' `
        -Replacement '-Label "Run $ExpectedRunIndex retained child summary"'
}
Assert-HostileMutationRejected -Name 'admission-role-type-guard-removed' -Validator $exactTypeValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source -Needle '$actualEvidenceRole -isnot [string] -or $actualEvidenceRole -cne ''fixed-repeat'' -or' -Replacement '$actualEvidenceRole -cne ''fixed-repeat'' -or'
}
Assert-HostileMutationRejected -Name 'summary-role-type-guard-removed' -Validator $exactTypeValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source -Needle '$summaryEvidenceRole -isnot [string] -or $summaryEvidenceRole -cne ''fixed-repeat'' -or' -Replacement '$summaryEvidenceRole -cne ''fixed-repeat'' -or'
}
Assert-HostileMutationRejected -Name 'run-failure-type-guard-removed' -Validator $exactTypeValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source -Needle '$runFailure -isnot [string] -or -not [string]::IsNullOrEmpty($runFailure) -or' -Replacement '-not [string]::IsNullOrEmpty([string]$runFailure) -or'
}
Assert-HostileMutationRejected -Name 'final-won-type-guard-removed' -Validator $exactTypeValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source -Needle '$finalWon -isnot [bool] -or -not [bool]$finalWon -or' -Replacement '-not [bool]$finalWon -or'
}
Assert-HostileMutationRejected -Name 'compare-proof-type-guard-removed' -Validator $exactTypeValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source -Needle '$value -isnot [string] -or $value -cne [string]$entry.Value' -Replacement '[string]$value -cne [string]$entry.Value'
}
Assert-HostileMutationRejected -Name 'aggregate-canonical-role-type-guard-removed' -Validator $qualificationValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle "        Assert-CanonicalFixedProofShape -Proof `$CanonicalProof -Label 'Qualification canonical proof'" `
        -Replacement '        $null = $CanonicalProof'
}
Assert-HostileMutationRejected -Name 'source-custody-write-share-enabled' -Validator $sourceCustodyValidator -Mutate {
    param($source)
    $pattern = '(?s)(function Open-SourceCustodyHandle\s*\{.*?\[IO\.FileShare\]::)Read'
    if ([regex]::Matches($source, $pattern).Count -ne 1) { throw 'Could not isolate source-custody open share.' }
    return [regex]::Replace($source, $pattern, '${1}ReadWrite', 1)
}
Assert-HostileMutationRejected -Name 'source-custody-index-enumeration-restored' -Validator $sourceCustodyValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source -Needle 'ls-tree -r --full-tree $ExpectedHead' -Replacement 'ls-files --stage'
}
Assert-HostileMutationRejected -Name 'source-custody-moving-head-enumeration' -Validator $sourceCustodyValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source -Needle 'ls-tree -r --full-tree $ExpectedHead' -Replacement 'ls-tree -r --full-tree HEAD'
}
Assert-HostileMutationRejected -Name 'source-custody-head-blob-check-removed' -Validator $sourceCustodyValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source -Needle '        Assert-RepositoryBlobIdentity' -Replacement '        $null = ''blob-check-bypassed'''
}
Assert-HostileMutationRejected -Name 'source-custody-blob-mismatch-accepted' -Validator $sourceCustodyValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle '            $rawBlob -cne $expectedBlob) {' `
        -Replacement '            $false) {'
}
Assert-HostileMutationRejected -Name 'source-custody-receipt-overwrite-enabled' -Validator $sourceCustodyValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle '[IO.FileMode]::CreateNew, [IO.FileAccess]::ReadWrite, [IO.FileShare]::Read)' `
        -Replacement '[IO.FileMode]::Create, [IO.FileAccess]::ReadWrite, [IO.FileShare]::Read)'
}
Assert-HostileMutationRejected -Name 'source-custody-receipt-write-share-enabled' -Validator $sourceCustodyValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle '[IO.FileMode]::CreateNew, [IO.FileAccess]::ReadWrite, [IO.FileShare]::Read)' `
        -Replacement '[IO.FileMode]::CreateNew, [IO.FileAccess]::ReadWrite, [IO.FileShare]::ReadWrite)'
}
Assert-HostileMutationRejected -Name 'source-custody-pre-receipt-unheld' -Validator $sourceCustodyValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source -Needle '$script:SourceCustodyPreStream = $lockedPreReceipt.stream' -Replacement '$lockedPreReceipt.stream.Dispose()'
}
Assert-HostileMutationRejected -Name 'source-custody-final-receipt-unheld' -Validator $sourceCustodyValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source -Needle '$script:SourceCustodyFinalStream = $lockedFinalReceipt.stream' -Replacement '$lockedFinalReceipt.stream.Dispose()'
}
Assert-HostileMutationRejected -Name 'source-custody-pre-spawn-check-removed' -Validator $sourceCustodyValidator -Mutate {
    param($source)
    $pattern = '(?m)^(    Assert-SourceCustody)\r?\n\r?\n(?=    \$originalAppData\s*=)'
    if ([regex]::Matches($source, $pattern).Count -ne 1) { throw 'Could not isolate pre-spawn source-custody assertion.' }
    return [regex]::Replace($source, $pattern, "    `$null = 'pre-spawn-custody-bypassed'`r`n`r`n", 1)
}
Assert-HostileMutationRejected -Name 'source-custody-post-exit-check-removed' -Validator $sourceCustodyValidator -Mutate {
    param($source)
    $pattern = '(?m)^    Assert-SourceCustody\r?\n\r?\n(?=    \$ownedDeadline)'
    if ([regex]::Matches($source, $pattern).Count -ne 1) { throw 'Could not isolate post-exit source-custody assertion.' }
    return [regex]::Replace($source, $pattern, "    `$null = 'post-exit-custody-bypassed'`r`n`r`n", 1)
}
Assert-HostileMutationRejected -Name 'source-custody-completion-hardcoded' -Validator $sourceCustodyValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source -Needle '                Complete-SourceCustody' -Replacement '                $script:SourceCustodyComplete = $true'
}
Assert-HostileMutationRejected -Name 'source-custody-manifest-omitted' -Validator $sourceCustodyValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source -Needle '    $SourceCustodyPrePath, $SourceCustodyFinalPath' -Replacement '    $LauncherSnapshotPath'
}
Assert-HostileMutationRejected -Name 'retained-preflight-invocation-compare-removed' -Validator $retainedPreflightValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source -Needle 'ConvertTo-CanonicalExactObjectJson -InputObject $InvocationPreflight' -Replacement 'ConvertTo-CanonicalExactObjectJson -InputObject $retained'
}
Assert-HostileMutationRejected -Name 'retained-preflight-run-compare-removed' -Validator $retainedPreflightValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source -Needle 'ConvertTo-CanonicalExactObjectJson -InputObject $RunPreflight' -Replacement 'ConvertTo-CanonicalExactObjectJson -InputObject $retained'
}
Assert-HostileMutationRejected -Name 'retained-preflight-object-guards-removed' -Validator $retainedPreflightValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle '-not (Test-ExactPsCustomObject -Value $InvocationPreflight) -or' `
        -Replacement '$false -or'
}
Assert-HostileMutationRejected -Name 'retained-preflight-lock-removed' -Validator $retainedPreflightValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source -Needle '$script:EvidenceArtifactStreams.Add($stream)' -Replacement '$stream.Dispose()'
}
Assert-HostileMutationRejected -Name 'retained-preflight-manifest-omitted' -Validator $retainedPreflightValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle "            (Get-ExactValueNoEnumerate `$proof @('heist_seed_preflight') `$null)" `
        -Replacement '            $EvidenceRoot'
}
Assert-HostileMutationRejected -Name 'retained-preflight-manifest-hash-binding-omitted' -Validator $retainedPreflightValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle '-ExpectedSha256 (Get-ExactValueNoEnumerate $Proof @(''heist_seed_preflight_sha256'') $null)' `
        -Replacement '-ExpectedSha256 $script:SourceCustodyPreSha256'
}
Assert-HostileMutationRejected -Name 'one-run-shape-root-guard-removed' -Validator $exactTypeValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle '-not (Test-ExactPsCustomObject -Value $Summary) -or' `
        -Replacement '$false -or'
}
Assert-HostileMutationRejected -Name 'final-checkpoint-shape-root-guard-removed' -Validator $exactTypeValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle '-not (Test-ExactPsCustomObject -Value $Retained) -or' `
        -Replacement '$false -or'
}
Assert-HostileMutationRejected -Name 'exact-object-runtime-type-check-weakened' -Validator $exactTypeValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle "`$Value.GetType().FullName -ceq 'System.Management.Automation.PSCustomObject'" `
        -Replacement "`$Value.GetType().FullName -ceq 'System.Object[]'"
}
Assert-HostileMutationRejected -Name 'summary-exact-schema-closure-removed' -Validator $exactTypeValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle '    Assert-Rw062ExactPropertyNames -InputObject $Summary -Expected $summaryPropertyNames -Label "$Label summary"' `
        -Replacement '    $null = $summaryPropertyNames'
}
Assert-HostileMutationRejected -Name 'checkpoint-exact-schema-closure-removed' -Validator $exactTypeValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle '    Assert-LocalExactPropertyNames -InputObject $Retained -Expected $checkpointPropertyNames -Label "$Label retained"' `
        -Replacement '    $null = $checkpointPropertyNames'
}
Assert-HostileMutationRejected -Name 'summary-schema-value-check-removed' -Validator $exactTypeValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle "        `$summaryRole -cne 'child_development_run' -or" `
        -Replacement '        $false -or'
}
Assert-HostileMutationRejected -Name 'non-heist-null-check-removed' -Validator $exactTypeValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle "    elseif (-not (Test-Rw062ExactNullProperty -InputObject `$Summary -Name 'heist_seed_preflight') -or" `
        -Replacement '    elseif ($false -or'
}
Assert-HostileMutationRejected -Name 'checkpoint-int32-type-widened' -Validator $exactTypeValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle "        [pscustomobject]@{ path = @('bankroll'); type = 'int32' }," `
        -Replacement "        [pscustomobject]@{ path = @('bankroll'); type = 'integer' },"
}

try {
    $runtimeFunctionNames = @(
        'Get-FailureMessage', 'Get-ExactValueNoEnumerate', 'Test-ExactStringArray', 'Get-Sha256', 'Test-ExactPsCustomObject',
        'Assert-LocalExactPropertyNames',
        'ConvertFrom-ExactJsonObjectText', 'ConvertTo-CanonicalExactObjectJson',
        'Get-CanonicalExactObjectSha256',
        'Get-HeldFileDigests', 'Get-HeldUtf8Text', 'New-LockedJsonReceipt',
        'Get-TrackedSourceDescriptors', 'Assert-SourceCustodyRowSchema',
        'Assert-SourceCustodyRowMatches', 'Assert-SourceCustodyReceiptSchema',
        'Assert-RepositoryBlobIdentity',
        'Get-ExactPositivePid', 'Get-ExactPidArray',
        'Assert-SourceCustody', 'Open-SourceCustodyHandle', 'New-SourceCustody',
        'Complete-SourceCustody', 'Close-SourceCustody',
        'Assert-RetainedHeistPreflightArtifact', 'Assert-OneRunJsonShapes',
        'Assert-FinalCheckpointJsonShapes', 'Assert-PersistenceCoreCheckpointShape',
        'Assert-SaveContinueCheckpointJsonShape', 'Assert-ManifestArtifactHash',
        'Assert-FixedRunManifestArtifactBindings',
        'Assert-FixedRunProofShape', 'Assert-CanonicalFixedProofShape', 'Compare-FixedRunProofs',
        'Test-FixedRepeatQualification', 'Assert-TerminalRecordKeys', 'Test-ExactLowerHexOrEmpty',
        'Assert-TerminalProcessCensusRowShape', 'Assert-TerminalSurvivorRowShape',
        'Assert-TerminalArtifactRowShape', 'Assert-TerminalAggregateShape',
        'Assert-TerminalMetadataShape', 'Assert-TerminalManifestShape', 'Assert-TerminalResultShape'
    )
    $runtimeDefinitions = [Collections.Generic.List[string]]::new()
    foreach ($functionName in @('Assert-Rw062ExactPropertyNames', 'Test-Rw062ExactNullProperty')) {
        $definition = Get-FunctionSource -Analysis $admissionAnalysis -Name $functionName
        if ([string]::IsNullOrWhiteSpace($definition)) {
            throw "Could not extract runtime admission function '$functionName'."
        }
        $runtimeDefinitions.Add($definition)
    }
    foreach ($functionName in $runtimeFunctionNames) {
        $definition = Get-FunctionSource -Analysis $launcher -Name $functionName
        if ([string]::IsNullOrWhiteSpace($definition)) {
            throw "Could not extract runtime contract function '$functionName'."
        }
        $runtimeDefinitions.Add($definition)
    }
    . ([scriptblock]::Create($runtimeDefinitions -join "`r`n`r`n"))

    $Ending = 'heist'
    $Seed = 'RW06-HEIST-AUDIT-0002'
    $ExpectedOutcomes = @{ heist = @('heist_clean_sweep', 'heist_out_hot', 'heist_somebody_got_pinched') }
    $commonHash = 'a' * 64
    $EvidenceRoot = 'C:\proof-aggregate'
    $SourceCustodyPrePath = 'C:\shared\source_custody_pre.json'
    $script:SourceCustodyPreSha256 = $commonHash
    $proofs = @(
        [pscustomobject][ordered]@{
            run_index = [int32]1; role = 'fixed_route_repeat'; evidence_role = 'fixed-repeat'; ending = $Ending; seed = $Seed
            replay_pid = [int32]101
            profile_roaming = 'C:\proof-aggregate\run-01\profile_roaming'; profile_local = 'C:\proof-aggregate\run-01\profile_local'
            profile_session_root = 'C:\proof-aggregate\run-01\profile_roaming\Godot\app_userdata\Beat the House\agent_playtest\rw062-heist-101-1-aaaaaaaaaa'
            profile_inventory = 'C:\proof-aggregate\run-01\profile_roaming\Godot\app_userdata\Beat the House\agent_playtest\rw062-heist-101-1-aaaaaaaaaa\profile_inventory.json'
            profile_inventory_sha256 = 'b' * 64
            autosave = 'C:\proof-aggregate\run-01\profile_roaming\Godot\app_userdata\Beat the House\agent_playtest\rw062-heist-101-1-aaaaaaaaaa\saves\foundation_ui_autosave.json'
            autosave_sha256 = 'c' * 64
            replay_invocation_root = 'C:\proof-aggregate\run-01\replay\20260924-010203-004-101'
            replay_summary = 'C:\proof-aggregate\run-01\replay\20260924-010203-004-101\summary.json'
            replay_summary_sha256 = 'd' * 64
            launcher_stdout = 'C:\proof-aggregate\run-01\launcher.stdout.txt'; launcher_stdout_sha256 = '8' * 64
            launcher_stderr = 'C:\proof-aggregate\run-01\launcher.stderr.txt'; launcher_stderr_sha256 = '9' * 64
            run_root = 'C:\proof-aggregate\run-01\replay\20260924-010203-004-101\run-01'
            run_summary = 'C:\proof-aggregate\run-01\replay\20260924-010203-004-101\run-01\summary.json'; run_summary_sha256 = '0' * 64
            session = 'rw062-heist-101-1-aaaaaaaaaa'; session_root = (Join-Path $Worktree '.tmp\agent_playtest\2026-09-24\rw062-heist-101-1-aaaaaaaaaa')
            outcome = 'heist_clean_sweep'; action_count = [int32]42
            transcript_sha256 = $commonHash; money_curve_sha256 = $commonHash
            persistence_checkpoint_before_sha256 = $commonHash; persistence_checkpoint_after_sha256 = $commonHash
            final_public_checkpoint_sha256 = $commonHash
            heist_seed_preflight = 'C:\proof-aggregate\run-01\replay\20260924-010203-004-101\heist_seed_preflight.json'; heist_seed_preflight_sha256 = $commonHash
            source_custody_pre = 'C:\shared\source_custody_pre.json'; source_custody_pre_sha256 = $commonHash
            godot_stdout_sha256 = 'e' * 64; godot_stderr_sha256 = 'f' * 64; godot_engine_sha256 = '1' * 64
        },
        [pscustomobject][ordered]@{
            run_index = [int32]2; role = 'fixed_route_repeat'; evidence_role = 'fixed-repeat'; ending = $Ending; seed = $Seed
            replay_pid = [int32]202
            profile_roaming = 'C:\proof-aggregate\run-02\profile_roaming'; profile_local = 'C:\proof-aggregate\run-02\profile_local'
            profile_session_root = 'C:\proof-aggregate\run-02\profile_roaming\Godot\app_userdata\Beat the House\agent_playtest\rw062-heist-202-1-bbbbbbbbbb'
            profile_inventory = 'C:\proof-aggregate\run-02\profile_roaming\Godot\app_userdata\Beat the House\agent_playtest\rw062-heist-202-1-bbbbbbbbbb\profile_inventory.json'
            profile_inventory_sha256 = '2' * 64
            autosave = 'C:\proof-aggregate\run-02\profile_roaming\Godot\app_userdata\Beat the House\agent_playtest\rw062-heist-202-1-bbbbbbbbbb\saves\foundation_ui_autosave.json'
            autosave_sha256 = '3' * 64
            replay_invocation_root = 'C:\proof-aggregate\run-02\replay\20260924-010203-005-202'
            replay_summary = 'C:\proof-aggregate\run-02\replay\20260924-010203-005-202\summary.json'
            replay_summary_sha256 = '4' * 64
            launcher_stdout = 'C:\proof-aggregate\run-02\launcher.stdout.txt'; launcher_stdout_sha256 = '8' * 64
            launcher_stderr = 'C:\proof-aggregate\run-02\launcher.stderr.txt'; launcher_stderr_sha256 = '9' * 64
            run_root = 'C:\proof-aggregate\run-02\replay\20260924-010203-005-202\run-01'
            run_summary = 'C:\proof-aggregate\run-02\replay\20260924-010203-005-202\run-01\summary.json'; run_summary_sha256 = '0' * 64
            session = 'rw062-heist-202-1-bbbbbbbbbb'; session_root = (Join-Path $Worktree '.tmp\agent_playtest\2026-09-24\rw062-heist-202-1-bbbbbbbbbb')
            outcome = 'heist_clean_sweep'; action_count = [int32]42
            transcript_sha256 = $commonHash; money_curve_sha256 = $commonHash
            persistence_checkpoint_before_sha256 = $commonHash; persistence_checkpoint_after_sha256 = $commonHash
            final_public_checkpoint_sha256 = $commonHash
            heist_seed_preflight = 'C:\proof-aggregate\run-02\replay\20260924-010203-005-202\heist_seed_preflight.json'; heist_seed_preflight_sha256 = $commonHash
            source_custody_pre = 'C:\shared\source_custody_pre.json'; source_custody_pre_sha256 = $commonHash
            godot_stdout_sha256 = '5' * 64; godot_stderr_sha256 = '6' * 64; godot_engine_sha256 = '7' * 64
        }
    )
    $canonicalProof = Compare-FixedRunProofs -Proofs $proofs
    $runtimeValidCaseCount++
    $proofArtifactRowsList = [Collections.Generic.List[object]]::new()
    foreach ($proof in $proofs) {
        foreach ($binding in @(
            [pscustomobject]@{ path = $proof.replay_summary; hash = $proof.replay_summary_sha256 },
            [pscustomobject]@{ path = $proof.launcher_stdout; hash = $proof.launcher_stdout_sha256 },
            [pscustomobject]@{ path = $proof.launcher_stderr; hash = $proof.launcher_stderr_sha256 },
            [pscustomobject]@{ path = $proof.run_summary; hash = $proof.run_summary_sha256 },
            [pscustomobject]@{ path = $proof.profile_inventory; hash = $proof.profile_inventory_sha256 },
            [pscustomobject]@{ path = $proof.autosave; hash = $proof.autosave_sha256 },
            [pscustomobject]@{ path = (Join-Path $proof.run_root 'public_trace.ndjson'); hash = $proof.transcript_sha256 },
            [pscustomobject]@{ path = (Join-Path $proof.run_root 'money_curve.ndjson'); hash = $proof.money_curve_sha256 },
            [pscustomobject]@{ path = (Join-Path $proof.run_root 'checkpoint_before.json'); hash = $proof.persistence_checkpoint_before_sha256 },
            [pscustomobject]@{ path = (Join-Path $proof.run_root 'checkpoint_after.json'); hash = $proof.persistence_checkpoint_after_sha256 },
            [pscustomobject]@{ path = (Join-Path $proof.run_root 'final_public_checkpoint.json'); hash = $proof.final_public_checkpoint_sha256 },
            [pscustomobject]@{ path = (Join-Path $proof.session_root 'godot.stdout.log'); hash = $proof.godot_stdout_sha256 },
            [pscustomobject]@{ path = (Join-Path $proof.session_root 'godot.stderr.log'); hash = $proof.godot_stderr_sha256 },
            [pscustomobject]@{ path = (Join-Path $proof.session_root 'godot.engine.log'); hash = $proof.godot_engine_sha256 },
            [pscustomobject]@{ path = $proof.heist_seed_preflight; hash = $proof.heist_seed_preflight_sha256 }
        )) {
            $proofArtifactRowsList.Add([pscustomobject][ordered]@{
                path = [IO.Path]::GetFullPath([string]$binding.path)
                sha256 = [string]$binding.hash
            })
        }
    }
    $proofArtifactRows = [object[]]$proofArtifactRowsList.ToArray()
    Assert-FixedRunManifestArtifactBindings -ArtifactRows $proofArtifactRows -Proof $proofs[0] -ExpectedRunIndex ([int32]1)
    Assert-FixedRunManifestArtifactBindings -ArtifactRows $proofArtifactRows -Proof $proofs[1] -ExpectedRunIndex ([int32]2)
    $runtimeValidCaseCount++
    $hostileProofArtifactRows = [object[]]@($proofArtifactRows | ForEach-Object {
        [pscustomobject][ordered]@{ path = [string]$_.path; sha256 = [string]$_.sha256 }
    })
    if ($hostileProofArtifactRows.Count -ne $proofArtifactRows.Count -or
        -not ([string]$hostileProofArtifactRows[0].path).Equals(
            [string]$proofs[0].replay_summary,
            [StringComparison]::OrdinalIgnoreCase
        )) {
        throw 'Could not build hostile proof-artifact binding fixture.'
    }
    $hostileProofArtifactRows[0].sha256 = 'e' * 64
    $runtimeHostileCaseCount++
    if (-not (Test-Throws {
        Assert-FixedRunManifestArtifactBindings `
            -ArtifactRows $hostileProofArtifactRows `
            -Proof $proofs[0] `
            -ExpectedRunIndex ([int32]1)
    })) {
        Add-Failure -Message 'Fixed-run manifest binding accepted a recomputed hostile artifact digest.'
    }
    $validPidRecord = [pscustomobject]@{ pid = [int32]123; guard_pids = [object[]]@([int32]123, [int32]456) }
    if ((Get-ExactPositivePid -InputObject $validPidRecord -Name 'pid') -ne 123 -or
        @(Get-ExactPidArray -InputObject $validPidRecord -Name 'guard_pids').Count -ne 2) {
        throw 'Valid exact PID fixtures failed.'
    }
    $runtimeValidCaseCount++
    foreach ($fixture in @(
        [pscustomobject]@{ name = 'PID array'; record = [pscustomobject]@{ pid = [object[]]@([int32]123) }; action = 'pid' },
        [pscustomobject]@{ name = 'PID collection scalar'; record = [pscustomobject]@{ guard_pids = [int32]123 }; action = 'guard' },
        [pscustomobject]@{ name = 'PID collection nested array'; record = [pscustomobject]@{ guard_pids = [object[]]@(,([object[]]@([int32]123))) }; action = 'guard' }
    )) {
        $runtimeHostileCaseCount++
        if ($fixture.action -ceq 'pid') {
            $rejected = Test-Throws { $null = Get-ExactPositivePid -InputObject $fixture.record -Name 'pid' }
        }
        else {
            $rejected = Test-Throws { $null = @(Get-ExactPidArray -InputObject $fixture.record -Name 'guard_pids') }
        }
        if (-not $rejected) { Add-Failure -Message "Exact PID validator accepted $($fixture.name)." }
    }

    $shapeCheckpoint = [pscustomobject][ordered]@{
        schema_version = [int32]1
        record_kind = 'final_public_checkpoint'; observed_seed = $Seed; outcome_key = 'heist_clean_sweep'
        won = $true; public_fingerprint = 'a' * 64; checkpoint_fingerprint = 'b' * 64
        bankroll = [int32]100; chips = [int32]50; heat = [int32]0
    }
    $shapeRun = [pscustomobject][ordered]@{
        action_count = [int32]42; outcome = 'heist_clean_sweep'; role = 'child_development_iteration'
        requested_evidence_role = 'fixed-repeat'; repeat_profile_scope = 'shared_caller_appdata'
        fixed_repeat_qualification_authority = 'outer_independent_profile_aggregate_only'
        release_qualifying = $false; qualification = 'non_qualifying_development_iteration'; passed = $true
        seed = $Seed; observed_terminal_seed = $Seed; midpoint_save_relaunch_continue = $true; failure = ''
        replay_admission = [pscustomobject]@{ evidence_role = 'fixed-repeat' }
        iteration = [int32]1; ending = $Ending
        heist_seed_preflight = [pscustomobject]@{ passed = $true }
        heist_preflight_admission = [pscustomobject]@{ evidence_role = 'fixed-repeat' }
        heist_launch_setup = [pscustomobject]@{
            selected_challenge_id = ''; selected_home_type_id = 'random'
            selected_content_groups = [object[]]@('group-a', 'group-b')
        }
        transcript = 'C:\shape\trace.ndjson'; money_curve = 'C:\shape\money.ndjson'
        persistence_checkpoint_before = 'C:\shape\before.json'; persistence_checkpoint_after = 'C:\shape\after.json'
        transcript_sha256 = '1' * 64; money_curve_sha256 = '2' * 64
        persistence_checkpoint_before_sha256 = '3' * 64; persistence_checkpoint_after_sha256 = '3' * 64
        persistence_checkpoint_equal = $true; persistence_checkpoint_complete = $true
        session = 'rw062-heist-123-1-aaaaaaaaaa'; final_public_checkpoint = $shapeCheckpoint
    }
    $shapeSummary = [pscustomobject][ordered]@{
        schema_version = [int32]1; role = 'child_development_run'
        evidence_root = 'C:\shape'; check_id = 'rw06_2_ending_replay'; requested_evidence_role = 'fixed-repeat'
        repeat_profile_scope = 'shared_caller_appdata'
        fixed_repeat_qualification_authority = 'outer_independent_profile_aggregate_only'
        ending = 'heist'; seed = $Seed; repeat = [int32]1; deterministic = $false
        checkpoint_evidence_complete = $true
        release_qualifying = $false; qualification = 'non_qualifying_development_run'
        public_observation_schema = 'beat_the_house.agent_public_observation'
        public_observation_schema_version = [int32]1
        observed_terminal_seeds = [object[]]@($Seed); runs = [object[]]@($shapeRun)
        replay_admission = [pscustomobject]@{ evidence_role = 'fixed-repeat' }
        heist_seed_preflight = [pscustomobject]@{ passed = $true }
        heist_preflight_admission = [pscustomobject]@{ evidence_role = 'fixed-repeat' }
    }
    Assert-OneRunJsonShapes -Summary $shapeSummary -Run $shapeRun -Label 'valid shape fixture'
    Assert-FinalCheckpointJsonShapes -Retained $shapeCheckpoint -Published $shapeCheckpoint -Label 'valid checkpoint fixture'
    $saveContinueCheckpoint = [pscustomobject][ordered]@{
        checkpoint = [pscustomobject][ordered]@{
            location_id = 'grand_casino'; location_archetype = 'grand_casino_back_room'
            world_node_id = 'grand_casino'; bankroll = [int32]100; chips = [int32]50; heat = [int32]1
            game_id = ''; game_phase = ''; boss_hand_number = [int32]0
            boss_player_stack = [int32]0; boss_rourke_stack = [int32]0
        }
        planning_choices = [object[]]@(
            [pscustomobject][ordered]@{
                choice_id = 'crew_approach'; label = 'Review the Approach'; enabled = $true
                rendered = $true; disabled_reason = ''
            },
            [pscustomobject][ordered]@{
                choice_id = 'lock_the_count'; label = 'Lock the Count'; enabled = $true
                rendered = $true; disabled_reason = ''
            }
        )
    }
    Assert-SaveContinueCheckpointJsonShape -Checkpoint $saveContinueCheckpoint -Label 'valid Heist Save/Continue checkpoint'
    $Ending = 'clean'
    $cleanSaveContinueCheckpoint = [pscustomobject][ordered]@{
        checkpoint = ($saveContinueCheckpoint.checkpoint | ConvertTo-Json -Depth 10 -Compress | ConvertFrom-Json)
        clean_players_card = [pscustomobject][ordered]@{
            location_archetype = 'grand_casino_cage'; talk_event_id = 'dialogue:linda_cage_services'
            tier_witness = 'Silver'; next_tier_witness = 'Gold'; summary = 'Silver. Gold: pending'
            choice_ids = [object[]]@('cage_claim_card', 'cage_ambient', 'back_main')
            choices = [object[]]@(
                [pscustomobject][ordered]@{ id = 'cage_claim_card'; label = "Claim Players Card`nGold pending"; enabled = $false },
                [pscustomobject][ordered]@{ id = 'cage_ambient'; label = 'Ask Linda'; enabled = $true },
                [pscustomobject][ordered]@{ id = 'back_main'; label = 'Back'; enabled = $true }
            )
        }
    }
    Assert-SaveContinueCheckpointJsonShape -Checkpoint $cleanSaveContinueCheckpoint -Label 'valid Clean Save/Continue checkpoint'
    $Ending = 'cheat'
    $cheatSaveContinueCheckpoint = [pscustomobject][ordered]@{
        checkpoint = ($saveContinueCheckpoint.checkpoint | ConvertTo-Json -Depth 10 -Compress | ConvertFrom-Json)
        clean_players_card = $null
    }
    $cheatSaveContinueCheckpoint.checkpoint.location_archetype = 'grand_casino_back_room'
    $cheatSaveContinueCheckpoint.checkpoint.game_id = 'blackjack'
    $cheatSaveContinueCheckpoint.checkpoint.game_phase = 'betting'
    $cheatSaveContinueCheckpoint.checkpoint.boss_hand_number = [int32]1
    Assert-SaveContinueCheckpointJsonShape -Checkpoint $cheatSaveContinueCheckpoint -Label 'valid Cheat Save/Continue checkpoint'
    $Ending = 'heist'
    $runtimeValidCaseCount++

    foreach ($rootFixture in @(
        [pscustomobject]@{ name = 'null'; value = $null },
        [pscustomobject]@{ name = 'ordered-object'; value = [ordered]@{} },
        [pscustomobject]@{ name = 'empty-object'; value = [pscustomobject]@{} },
        [pscustomobject]@{ name = 'scalar'; value = 'checkpoint-scalar' },
        [pscustomobject]@{ name = 'array'; value = [object[]]@(,$saveContinueCheckpoint) },
        [pscustomobject]@{ name = 'nested-array'; value = [object[]]@(,([object[]]@($saveContinueCheckpoint))) }
    )) {
        $runtimeHostileCaseCount++
        if (-not (Test-Throws {
            Assert-SaveContinueCheckpointJsonShape -Checkpoint $rootFixture.value -Label "hostile checkpoint root $($rootFixture.name)"
        })) {
            Add-Failure -Message "Save/Continue checkpoint validator accepted hostile root '$($rootFixture.name)'."
        }
    }
    foreach ($field in @('checkpoint', 'planning_choices')) {
        foreach ($variant in @('missing','null','object','array','nested-array','wrong-scalar')) {
            $runtimeHostileCaseCount++
            $copy = $saveContinueCheckpoint | ConvertTo-Json -Depth 20 -Compress | ConvertFrom-Json
            switch ($variant) {
                'missing' { $copy.PSObject.Properties.Remove($field) }
                'null' { $copy.$field = $null }
                'object' { $copy.$field = [pscustomobject]@{ hostile = $true } }
                'array' { $copy.$field = [object[]]@('hostile') }
                'nested-array' { $copy.$field = [object[]]@(,([object[]]@('hostile'))) }
                'wrong-scalar' { $copy.$field = [int32]1 }
            }
            if (-not (Test-Throws { Assert-SaveContinueCheckpointJsonShape -Checkpoint $copy -Label "$variant $field" })) {
                Add-Failure -Message "Save/Continue checkpoint validator accepted $variant outer field '$field'."
            }
        }
    }
    $runtimeHostileCaseCount++
    $checkpointExtra = $saveContinueCheckpoint | ConvertTo-Json -Depth 20 -Compress | ConvertFrom-Json
    $checkpointExtra | Add-Member -NotePropertyName scenario_authority -NotePropertyValue 'hostile'
    if (-not (Test-Throws { Assert-SaveContinueCheckpointJsonShape -Checkpoint $checkpointExtra -Label 'extra checkpoint authority' })) {
        Add-Failure -Message 'Save/Continue checkpoint validator accepted an extra authority field.'
    }
    $runtimeHostileCaseCount++
    $checkpointReordered = New-ReorderedContractObject -InputObject (ConvertTo-ContractClone -InputObject $saveContinueCheckpoint)
    if (-not (Test-Throws { Assert-SaveContinueCheckpointJsonShape -Checkpoint $checkpointReordered -Label 'reordered Heist checkpoint root' })) {
        Add-Failure -Message 'Save/Continue checkpoint validator accepted reordered Heist root keys.'
    }
    $coreStringFields = @('location_id', 'location_archetype', 'world_node_id', 'game_id', 'game_phase')
    $coreIntFields = @('bankroll', 'chips', 'heat', 'boss_hand_number', 'boss_player_stack', 'boss_rourke_stack')
    foreach ($hostileCore in @($null, 'checkpoint-scalar', [ordered]@{}, [object[]]@('checkpoint'), [object[]]@(,([object[]]@('checkpoint'))))) {
        $runtimeHostileCaseCount++
        $copy = $saveContinueCheckpoint | ConvertTo-Json -Depth 20 -Compress | ConvertFrom-Json
        $copy.checkpoint = $hostileCore
        if (-not (Test-Throws { Assert-SaveContinueCheckpointJsonShape -Checkpoint $copy -Label 'hostile core checkpoint root' })) {
            Add-Failure -Message 'Save/Continue checkpoint validator accepted a hostile core checkpoint root.'
        }
    }
    $runtimeHostileCaseCount++
    $coreExtra = $saveContinueCheckpoint | ConvertTo-Json -Depth 20 -Compress | ConvertFrom-Json
    $coreExtra.checkpoint | Add-Member -NotePropertyName authority -NotePropertyValue 'hostile'
    if (-not (Test-Throws { Assert-SaveContinueCheckpointJsonShape -Checkpoint $coreExtra -Label 'extra core checkpoint authority' })) {
        Add-Failure -Message 'Save/Continue checkpoint validator accepted an extra core checkpoint field.'
    }
    $runtimeHostileCaseCount++
    $coreReordered = ConvertTo-ContractClone -InputObject $saveContinueCheckpoint
    $coreReordered.checkpoint = New-ReorderedContractObject -InputObject $coreReordered.checkpoint
    if (-not (Test-Throws { Assert-SaveContinueCheckpointJsonShape -Checkpoint $coreReordered -Label 'reordered core checkpoint' })) {
        Add-Failure -Message 'Save/Continue checkpoint validator accepted reordered core-checkpoint keys.'
    }
    foreach ($field in @($coreStringFields + $coreIntFields)) {
        $hostileValues = if ($field -cin $coreStringFields) {
            @($null, [pscustomobject]@{}, [object[]]@('value'), [int32]1)
        }
        else {
            @($null, [pscustomobject]@{}, [object[]]@([int32]1), '1', [int64]1, [double]1, [decimal]1, [uint32]1)
        }
        foreach ($hostileValue in $hostileValues) {
            $runtimeHostileCaseCount++
            $copy = $saveContinueCheckpoint | ConvertTo-Json -Depth 20 -Compress | ConvertFrom-Json
            $copy.checkpoint.$field = $hostileValue
            if (-not (Test-Throws { Assert-SaveContinueCheckpointJsonShape -Checkpoint $copy -Label "hostile core $field" })) {
                Add-Failure -Message "Save/Continue checkpoint validator accepted hostile core field '$field'."
            }
        }
        $runtimeHostileCaseCount++
        $missing = $saveContinueCheckpoint | ConvertTo-Json -Depth 20 -Compress | ConvertFrom-Json
        $missing.checkpoint.PSObject.Properties.Remove($field)
        if (-not (Test-Throws { Assert-SaveContinueCheckpointJsonShape -Checkpoint $missing -Label "missing core $field" })) {
            Add-Failure -Message "Save/Continue checkpoint validator accepted missing core field '$field'."
        }
    }
    foreach ($hostileChoices in @(
        $null,
        'planning-scalar',
        [pscustomobject]@{},
        [object[]]@(),
        [object[]]@('planning-row'),
        [object[]]@([ordered]@{}),
        [object[]]@(,([object[]]@($saveContinueCheckpoint.planning_choices)))
    )) {
        $runtimeHostileCaseCount++
        $copy = $saveContinueCheckpoint | ConvertTo-Json -Depth 20 -Compress | ConvertFrom-Json
        $copy.planning_choices = $hostileChoices
        if (-not (Test-Throws { Assert-SaveContinueCheckpointJsonShape -Checkpoint $copy -Label 'hostile planning choices' })) {
            Add-Failure -Message 'Save/Continue checkpoint validator accepted hostile planning_choices shape.'
        }
    }
    foreach ($field in @('choice_id', 'label', 'enabled', 'rendered', 'disabled_reason')) {
        $runtimeHostileCaseCount++
        $copy = $saveContinueCheckpoint | ConvertTo-Json -Depth 20 -Compress | ConvertFrom-Json
        $copy.planning_choices[0].PSObject.Properties.Remove($field)
        if (-not (Test-Throws { Assert-SaveContinueCheckpointJsonShape -Checkpoint $copy -Label "missing planning row $field" })) {
            Add-Failure -Message "Save/Continue checkpoint validator accepted missing planning-row field '$field'."
        }
        $wrongScalar = if ($field -cin @('enabled', 'rendered')) { 'true' } else { [bool]$true }
        foreach ($hostileValue in @(
            $null,
            [pscustomobject]@{},
            [object[]]@('value'),
            [object[]]@(,([object[]]@('value'))),
            $wrongScalar
        )) {
            $runtimeHostileCaseCount++
            $copy = $saveContinueCheckpoint | ConvertTo-Json -Depth 20 -Compress | ConvertFrom-Json
            $copy.planning_choices[0].$field = $hostileValue
            if (-not (Test-Throws { Assert-SaveContinueCheckpointJsonShape -Checkpoint $copy -Label "hostile planning row $field" })) {
                Add-Failure -Message "Save/Continue checkpoint validator accepted hostile planning-row field '$field'."
            }
        }
    }
    foreach ($mutation in @(
        'duplicate', 'reordered', 'missing-count-lock', 'multiple-count-locks',
        'count-lock-disabled', 'count-lock-not-rendered', 'extra-row-field', 'reordered-row-fields'
    )) {
        $runtimeHostileCaseCount++
        $copy = $saveContinueCheckpoint | ConvertTo-Json -Depth 20 -Compress | ConvertFrom-Json
        switch ($mutation) {
            'duplicate' { $copy.planning_choices[1].choice_id = $copy.planning_choices[0].choice_id }
            'reordered' { $copy.planning_choices = [object[]]@($copy.planning_choices[1], $copy.planning_choices[0]) }
            'missing-count-lock' { $copy.planning_choices = [object[]]@($copy.planning_choices[0]) }
            'multiple-count-locks' { $copy.planning_choices[0].choice_id = 'lock_the_count' }
            'count-lock-disabled' { $copy.planning_choices[1].enabled = $false }
            'count-lock-not-rendered' { $copy.planning_choices[1].rendered = $false }
            'extra-row-field' { $copy.planning_choices[0] | Add-Member -NotePropertyName scenario_pin -NotePropertyValue $false }
            'reordered-row-fields' { $copy.planning_choices[0] = New-ReorderedContractObject -InputObject $copy.planning_choices[0] }
        }
        if (-not (Test-Throws { Assert-SaveContinueCheckpointJsonShape -Checkpoint $copy -Label "hostile planning $mutation" })) {
            Add-Failure -Message "Save/Continue checkpoint validator accepted hostile planning mutation '$mutation'."
        }
    }
    $Ending = 'clean'
    foreach ($field in @('checkpoint','clean_players_card')) {
        foreach ($variant in @('missing','null','object','array','nested-array','wrong-scalar')) {
            $runtimeHostileCaseCount++
            $copy = ConvertTo-ContractClone -InputObject $cleanSaveContinueCheckpoint
            switch ($variant) {
                'missing' { $copy.PSObject.Properties.Remove($field) }
                'null' { $copy.$field = $null }
                'object' { $copy.$field = [pscustomobject]@{ hostile = $true } }
                'array' { $copy.$field = [object[]]@('hostile') }
                'nested-array' { $copy.$field = [object[]]@(,([object[]]@('hostile'))) }
                'wrong-scalar' { $copy.$field = [int32]1 }
            }
            if (-not (Test-Throws { Assert-SaveContinueCheckpointJsonShape -Checkpoint $copy -Label "$variant Clean outer $field" })) {
                Add-Failure -Message "Save/Continue checkpoint validator accepted $variant Clean outer field '$field'."
            }
        }
    }
    foreach ($mutation in @('extra','reordered')) {
        $runtimeHostileCaseCount++
        $copy = ConvertTo-ContractClone -InputObject $cleanSaveContinueCheckpoint
        if ($mutation -ceq 'extra') { $copy | Add-Member -NotePropertyName authority -NotePropertyValue 'hostile' }
        else { $copy = New-ReorderedContractObject -InputObject $copy }
        if (-not (Test-Throws { Assert-SaveContinueCheckpointJsonShape -Checkpoint $copy -Label "hostile Clean outer $mutation" })) {
            Add-Failure -Message "Save/Continue checkpoint validator accepted $mutation Clean outer object."
        }
    }
    foreach ($hostileCard in @(
        $null,
        'card-scalar',
        [ordered]@{},
        [object[]]@('card'),
        [object[]]@(,([object[]]@('card')))
    )) {
        $runtimeHostileCaseCount++
        $copy = ConvertTo-ContractClone -InputObject $cleanSaveContinueCheckpoint
        $copy.clean_players_card = $hostileCard
        if (-not (Test-Throws { Assert-SaveContinueCheckpointJsonShape -Checkpoint $copy -Label 'hostile Clean card root' })) {
            Add-Failure -Message 'Save/Continue checkpoint validator accepted a hostile Clean card root.'
        }
    }
    foreach ($field in @(
        'location_archetype', 'talk_event_id', 'tier_witness', 'next_tier_witness',
        'summary', 'choice_ids', 'choices'
    )) {
        foreach ($variant in @('missing','null','object','array','nested-array','wrong-scalar')) {
            $runtimeHostileCaseCount++
            $copy = ConvertTo-ContractClone -InputObject $cleanSaveContinueCheckpoint
            switch ($variant) {
                'missing' { $copy.clean_players_card.PSObject.Properties.Remove($field) }
                'null' { $copy.clean_players_card.$field = $null }
                'object' { $copy.clean_players_card.$field = [pscustomobject]@{ hostile = $true } }
                'array' { $copy.clean_players_card.$field = [object[]]@('hostile') }
                'nested-array' { $copy.clean_players_card.$field = [object[]]@(,([object[]]@('hostile'))) }
                'wrong-scalar' {
                    $copy.clean_players_card.$field = if ($field -cin @('choice_ids','choices')) { 'hostile' } else { [int32]1 }
                }
            }
            if (-not (Test-Throws { Assert-SaveContinueCheckpointJsonShape -Checkpoint $copy -Label "$variant clean card $field" })) {
                Add-Failure -Message "Save/Continue checkpoint validator accepted $variant Clean card field '$field'."
            }
        }
    }
    foreach ($mutation in @(
        'card-extra-field','card-reordered-fields','choice-ids-empty','choice-ids-extra',
        'choice-ids-duplicate','nested-choice-ids','wrong-choice-order','choices-empty',
        'choices-extra','choices-nested','choices-wrong-element','choices-reordered'
    )) {
        $runtimeHostileCaseCount++
        $copy = ConvertTo-ContractClone -InputObject $cleanSaveContinueCheckpoint
        switch ($mutation) {
            'card-extra-field' { $copy.clean_players_card | Add-Member -NotePropertyName authority -NotePropertyValue 'hostile' }
            'card-reordered-fields' { $copy.clean_players_card = New-ReorderedContractObject -InputObject $copy.clean_players_card }
            'choice-ids-empty' { $copy.clean_players_card.choice_ids = [object[]]@() }
            'choice-ids-extra' { $copy.clean_players_card.choice_ids = [object[]]@('cage_claim_card','cage_ambient','back_main','hostile') }
            'choice-ids-duplicate' { $copy.clean_players_card.choice_ids = [object[]]@('cage_claim_card','cage_claim_card','back_main') }
            'nested-choice-ids' { $copy.clean_players_card.choice_ids = [object[]]@(,([object[]]@($copy.clean_players_card.choice_ids))) }
            'wrong-choice-order' { $copy.clean_players_card.choice_ids = [object[]]@('back_main', 'cage_ambient', 'cage_claim_card') }
            'choices-empty' { $copy.clean_players_card.choices = [object[]]@() }
            'choices-extra' { $copy.clean_players_card.choices = [object[]]@($copy.clean_players_card.choices[0],$copy.clean_players_card.choices[1],$copy.clean_players_card.choices[2],$copy.clean_players_card.choices[2]) }
            'choices-nested' { $copy.clean_players_card.choices = [object[]]@(,([object[]]@($copy.clean_players_card.choices))) }
            'choices-wrong-element' { $copy.clean_players_card.choices = [object[]]@('choice',$copy.clean_players_card.choices[1],$copy.clean_players_card.choices[2]) }
            'choices-reordered' { $copy.clean_players_card.choices = [object[]]@($copy.clean_players_card.choices[1],$copy.clean_players_card.choices[0],$copy.clean_players_card.choices[2]) }
        }
        if (-not (Test-Throws { Assert-SaveContinueCheckpointJsonShape -Checkpoint $copy -Label "hostile clean card $mutation" })) {
            Add-Failure -Message "Save/Continue checkpoint validator accepted hostile Clean card mutation '$mutation'."
        }
    }
    for ($rowIndex = 0; $rowIndex -lt 3; $rowIndex++) {
        foreach ($field in @('id','label','enabled')) {
            foreach ($variant in @('missing','null','object','array','nested-array','wrong-scalar')) {
                $runtimeHostileCaseCount++
                $copy = ConvertTo-ContractClone -InputObject $cleanSaveContinueCheckpoint
                $row = $copy.clean_players_card.choices[$rowIndex]
                switch ($variant) {
                    'missing' { $row.PSObject.Properties.Remove($field) }
                    'null' { $row.$field = $null }
                    'object' { $row.$field = [pscustomobject]@{ hostile = $true } }
                    'array' { $row.$field = [object[]]@($row.$field) }
                    'nested-array' { $row.$field = [object[]]@(,([object[]]@($row.$field))) }
                    'wrong-scalar' { $row.$field = if ($field -ceq 'enabled') { 'true' } else { [int32]1 } }
                }
                if (-not (Test-Throws { Assert-SaveContinueCheckpointJsonShape -Checkpoint $copy -Label "hostile Clean choice $rowIndex $field $variant" })) {
                    Add-Failure -Message "Save/Continue checkpoint validator accepted $variant Clean choice $rowIndex field '$field'."
                }
            }
        }
        foreach ($mutation in @('extra','reordered')) {
            $runtimeHostileCaseCount++
            $copy = ConvertTo-ContractClone -InputObject $cleanSaveContinueCheckpoint
            if ($mutation -ceq 'extra') {
                $copy.clean_players_card.choices[$rowIndex] | Add-Member -NotePropertyName authority -NotePropertyValue 'hostile'
            }
            else {
                $copy.clean_players_card.choices[$rowIndex] = New-ReorderedContractObject -InputObject $copy.clean_players_card.choices[$rowIndex]
            }
            if (-not (Test-Throws { Assert-SaveContinueCheckpointJsonShape -Checkpoint $copy -Label "hostile Clean choice $rowIndex $mutation" })) {
                Add-Failure -Message "Save/Continue checkpoint validator accepted $mutation Clean choice row $rowIndex."
            }
        }
    }
    $Ending = 'cheat'
    foreach ($mutation in @('missing-checkpoint','missing-card','checkpoint-null','checkpoint-array','extra','reordered')) {
        $runtimeHostileCaseCount++
        $copy = ConvertTo-ContractClone -InputObject $cheatSaveContinueCheckpoint
        switch ($mutation) {
            'missing-checkpoint' { $copy.PSObject.Properties.Remove('checkpoint') }
            'missing-card' { $copy.PSObject.Properties.Remove('clean_players_card') }
            'checkpoint-null' { $copy.checkpoint = $null }
            'checkpoint-array' { $copy.checkpoint = [object[]]@($copy.checkpoint) }
            'extra' { $copy | Add-Member -NotePropertyName authority -NotePropertyValue 'hostile' }
            'reordered' { $copy = New-ReorderedContractObject -InputObject $copy }
        }
        if (-not (Test-Throws { Assert-SaveContinueCheckpointJsonShape -Checkpoint $copy -Label "hostile Cheat outer $mutation" })) {
            Add-Failure -Message "Save/Continue checkpoint validator accepted hostile Cheat outer '$mutation'."
        }
    }
    foreach ($hostileCard in @('non-null', [pscustomobject]@{}, [object[]]@())) {
        $runtimeHostileCaseCount++
        $copy = $cheatSaveContinueCheckpoint | ConvertTo-Json -Depth 20 -Compress | ConvertFrom-Json
        $copy.clean_players_card = $hostileCard
        if (-not (Test-Throws { Assert-SaveContinueCheckpointJsonShape -Checkpoint $copy -Label 'hostile Cheat card' })) {
            Add-Failure -Message 'Save/Continue checkpoint validator accepted non-null Cheat card evidence.'
        }
    }
    foreach ($fixture in @(
        [pscustomobject]@{ field = 'location_archetype'; value = 'grand_casino_main' },
        [pscustomobject]@{ field = 'game_id'; value = 'roulette' },
        [pscustomobject]@{ field = 'game_phase'; value = 'decision' },
        [pscustomobject]@{ field = 'boss_hand_number'; value = [int32]0 },
        [pscustomobject]@{ field = 'boss_hand_number'; value = [int32]2 }
    )) {
        $runtimeHostileCaseCount++
        $copy = $cheatSaveContinueCheckpoint | ConvertTo-Json -Depth 20 -Compress | ConvertFrom-Json
        $copy.checkpoint.($fixture.field) = $fixture.value
        if (-not (Test-Throws { Assert-SaveContinueCheckpointJsonShape -Checkpoint $copy -Label "hostile Cheat milestone $($fixture.field)" })) {
            Add-Failure -Message "Save/Continue checkpoint validator accepted wrong Cheat milestone field '$($fixture.field)'."
        }
    }
    $Ending = 'heist'

    $summarySchemaFields = @(
        'schema_version', 'check_id', 'role', 'requested_evidence_role',
        'repeat_profile_scope', 'fixed_repeat_qualification_authority', 'ending', 'seed',
        'observed_terminal_seeds', 'repeat', 'deterministic', 'checkpoint_evidence_complete',
        'release_qualifying', 'qualification', 'replay_admission',
        'public_observation_schema', 'public_observation_schema_version',
        'heist_seed_preflight', 'heist_preflight_admission', 'evidence_root', 'runs'
    )
    $runSchemaFields = @(
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
    $checkpointSchemaFields = @(
        'schema_version', 'record_kind', 'observed_seed', 'outcome_key', 'won',
        'public_fingerprint', 'checkpoint_fingerprint', 'bankroll', 'chips', 'heat'
    )
    $launchSchemaFields = @('selected_challenge_id', 'selected_home_type_id', 'selected_content_groups')

    foreach ($field in $summarySchemaFields) {
        $runtimeHostileCaseCount++
        $summaryCopy = $shapeSummary | ConvertTo-Json -Depth 20 -Compress | ConvertFrom-Json
        $runCopy = $shapeRun | ConvertTo-Json -Depth 20 -Compress | ConvertFrom-Json
        $summaryCopy.runs = [object[]]@($runCopy)
        $summaryCopy.PSObject.Properties.Remove($field)
        if (-not (Test-Throws { Assert-OneRunJsonShapes -Summary $summaryCopy -Run $runCopy -Label "missing summary $field" })) {
            Add-Failure -Message "One-run shape validator accepted missing summary property '$field'."
        }
    }
    foreach ($field in $runSchemaFields) {
        $runtimeHostileCaseCount++
        $summaryCopy = $shapeSummary | ConvertTo-Json -Depth 20 -Compress | ConvertFrom-Json
        $runCopy = $shapeRun | ConvertTo-Json -Depth 20 -Compress | ConvertFrom-Json
        $summaryCopy.runs = [object[]]@($runCopy)
        $runCopy.PSObject.Properties.Remove($field)
        if (-not (Test-Throws { Assert-OneRunJsonShapes -Summary $summaryCopy -Run $runCopy -Label "missing run $field" })) {
            Add-Failure -Message "One-run shape validator accepted missing run property '$field'."
        }
    }
    foreach ($field in $checkpointSchemaFields) {
        foreach ($targetName in @('retained', 'published')) {
            foreach ($variant in @('missing','null','object','array','nested-array','wrong-scalar')) {
                $runtimeHostileCaseCount++
                $retainedCopy = ConvertTo-ContractClone -InputObject $shapeCheckpoint
                $publishedCopy = ConvertTo-ContractClone -InputObject $shapeCheckpoint
                $target = if ($targetName -ceq 'retained') { $retainedCopy } else { $publishedCopy }
                switch ($variant) {
                    'missing' { $target.PSObject.Properties.Remove($field) }
                    'null' { $target.$field = $null }
                    'object' { $target.$field = [pscustomobject]@{ hostile = $true } }
                    'array' { $target.$field = [object[]]@($target.$field) }
                    'nested-array' { $target.$field = [object[]]@(,([object[]]@($target.$field))) }
                    'wrong-scalar' {
                        $target.$field = if ($field -cin @('schema_version','bankroll','chips','heat')) { '1' }
                            elseif ($field -ceq 'won') { 'true' }
                            else { [int32]1 }
                    }
                }
                if (-not (Test-Throws { Assert-FinalCheckpointJsonShapes -Retained $retainedCopy -Published $publishedCopy -Label "$variant $targetName $field" })) {
                    Add-Failure -Message "Final-checkpoint shape validator accepted $variant $targetName property '$field'."
                }
            }
        }
    }
    foreach ($field in $launchSchemaFields) {
        $runtimeHostileCaseCount++
        $summaryCopy = $shapeSummary | ConvertTo-Json -Depth 20 -Compress | ConvertFrom-Json
        $runCopy = $shapeRun | ConvertTo-Json -Depth 20 -Compress | ConvertFrom-Json
        $summaryCopy.runs = [object[]]@($runCopy)
        $runCopy.heist_launch_setup.PSObject.Properties.Remove($field)
        if (-not (Test-Throws { Assert-OneRunJsonShapes -Summary $summaryCopy -Run $runCopy -Label "missing launch $field" })) {
            Add-Failure -Message "One-run shape validator accepted missing Heist launch property '$field'."
        }
    }

    foreach ($fixture in @(
        [pscustomobject]@{ target = 'summary'; field = 'scenario_pin' },
        [pscustomobject]@{ target = 'run'; field = 'scenario_injection_used' },
        [pscustomobject]@{ target = 'launch'; field = 'plan_b_used' }
    )) {
        $runtimeHostileCaseCount++
        $summaryCopy = $shapeSummary | ConvertTo-Json -Depth 20 -Compress | ConvertFrom-Json
        $runCopy = $shapeRun | ConvertTo-Json -Depth 20 -Compress | ConvertFrom-Json
        $summaryCopy.runs = [object[]]@($runCopy)
        $target = switch ($fixture.target) {
            'summary' { $summaryCopy }
            'run' { $runCopy }
            'launch' { $runCopy.heist_launch_setup }
        }
        $target | Add-Member -NotePropertyName $fixture.field -NotePropertyValue $false
        if (-not (Test-Throws { Assert-OneRunJsonShapes -Summary $summaryCopy -Run $runCopy -Label "extra $($fixture.target) property" })) {
            Add-Failure -Message "One-run shape validator accepted extra $($fixture.target) property '$($fixture.field)'."
        }
    }
    foreach ($targetName in @('retained', 'published')) {
        $runtimeHostileCaseCount++
        $retainedCopy = $shapeCheckpoint | ConvertTo-Json -Depth 10 -Compress | ConvertFrom-Json
        $publishedCopy = $shapeCheckpoint | ConvertTo-Json -Depth 10 -Compress | ConvertFrom-Json
        $target = if ($targetName -ceq 'retained') { $retainedCopy } else { $publishedCopy }
        $target | Add-Member -NotePropertyName 'plan_b_used' -NotePropertyValue $false
        if (-not (Test-Throws { Assert-FinalCheckpointJsonShapes -Retained $retainedCopy -Published $publishedCopy -Label "extra $targetName checkpoint property" })) {
            Add-Failure -Message "Final-checkpoint shape validator accepted an extra $targetName property."
        }
    }

    foreach ($jsonFixture in @('[{"value":1}]', '"value"', 'null')) {
        $runtimeHostileCaseCount++
        if (-not (Test-Throws { $null = ConvertFrom-ExactJsonObjectText -Json $jsonFixture -Label 'hostile JSON root' })) {
            Add-Failure -Message "Exact JSON-object parser accepted hostile root: $jsonFixture"
        }
    }
    $runtimeValidCaseCount++
    $null = ConvertFrom-ExactJsonObjectText -Json '{"value":1}' -Label 'valid JSON root'

    $summaryScalarFields = @(
        'schema_version', 'evidence_root', 'check_id', 'role', 'requested_evidence_role',
        'repeat_profile_scope', 'fixed_repeat_qualification_authority', 'ending', 'seed', 'repeat',
        'deterministic', 'checkpoint_evidence_complete', 'release_qualifying', 'qualification',
        'public_observation_schema', 'public_observation_schema_version'
    )
    $runScalarFields = @(
        'action_count', 'outcome', 'role', 'requested_evidence_role', 'repeat_profile_scope',
        'fixed_repeat_qualification_authority', 'release_qualifying', 'qualification', 'passed',
        'iteration', 'ending', 'seed', 'observed_terminal_seed', 'midpoint_save_relaunch_continue', 'failure',
        'transcript', 'money_curve', 'persistence_checkpoint_before', 'persistence_checkpoint_after',
        'transcript_sha256', 'money_curve_sha256', 'persistence_checkpoint_before_sha256',
        'persistence_checkpoint_after_sha256', 'persistence_checkpoint_equal',
        'persistence_checkpoint_complete', 'session'
    )
    foreach ($scalarSpec in @(
        [pscustomobject]@{ target = 'summary'; fields = $summaryScalarFields },
        [pscustomobject]@{ target = 'run'; fields = $runScalarFields }
    )) {
        foreach ($field in $scalarSpec.fields) {
            foreach ($variant in @('null', 'object', 'array', 'nested-array', 'wrong-scalar', 'wrong-numeric-width')) {
                $summaryCopy = ConvertTo-ContractClone -InputObject $shapeSummary
                $runCopy = ConvertTo-ContractClone -InputObject $shapeRun
                $summaryCopy.runs = [object[]]@($runCopy)
                $target = if ($scalarSpec.target -ceq 'summary') { $summaryCopy } else { $runCopy }
                $prior = $target.$field
                if ($variant -ceq 'wrong-numeric-width' -and $prior -isnot [int32]) { continue }
                $runtimeHostileCaseCount++
                switch ($variant) {
                    'null' { $target.$field = $null }
                    'object' { $target.$field = [pscustomobject]@{ hostile = $true } }
                    'array' { $target.$field = [object[]]@(,$prior) }
                    'nested-array' { $target.$field = [object[]]@(,([object[]]@(,$prior))) }
                    'wrong-scalar' {
                        $target.$field = if ($prior -is [int32]) { '1' }
                            elseif ($prior -is [bool]) { 'true' }
                            else { [int32]1 }
                    }
                    'wrong-numeric-width' { $target.$field = [int64]$prior }
                }
                if (-not (Test-Throws { Assert-OneRunJsonShapes -Summary $summaryCopy -Run $runCopy -Label "$($scalarSpec.target) $field $variant" })) {
                    Add-Failure -Message "One-run shape validator accepted $variant $($scalarSpec.target) scalar '$field'."
                }
            }
        }
    }
    foreach ($fixture in @(
        [pscustomobject]@{ target = 'summary'; field = 'schema_version'; value = [int32]2 },
        [pscustomobject]@{ target = 'summary'; field = 'role'; value = 'wrong-role' },
        [pscustomobject]@{ target = 'summary'; field = 'repeat_profile_scope'; value = 'wrong-scope' },
        [pscustomobject]@{ target = 'summary'; field = 'fixed_repeat_qualification_authority'; value = 'wrong-authority' },
        [pscustomobject]@{ target = 'summary'; field = 'checkpoint_evidence_complete'; value = $false },
        [pscustomobject]@{ target = 'summary'; field = 'public_observation_schema'; value = 'wrong-schema' },
        [pscustomobject]@{ target = 'summary'; field = 'public_observation_schema_version'; value = [int32]2 },
        [pscustomobject]@{ target = 'run'; field = 'iteration'; value = [int32]2 },
        [pscustomobject]@{ target = 'run'; field = 'ending'; value = 'clean' }
    )) {
        $runtimeHostileCaseCount++
        $summaryCopy = $shapeSummary | ConvertTo-Json -Depth 20 -Compress | ConvertFrom-Json
        $runCopy = $shapeRun | ConvertTo-Json -Depth 20 -Compress | ConvertFrom-Json
        $summaryCopy.runs = [object[]]@($runCopy)
        $target = if ($fixture.target -ceq 'summary') { $summaryCopy } else { $runCopy }
        $target.($fixture.field) = $fixture.value
        if (-not (Test-Throws { Assert-OneRunJsonShapes -Summary $summaryCopy -Run $runCopy -Label "wrong $($fixture.target).$($fixture.field)" })) {
            Add-Failure -Message "One-run shape validator accepted wrong exact value '$($fixture.target).$($fixture.field)'."
        }
    }

    $originalEnding = $Ending
    try {
        $Ending = 'clean'
        $nonHeistSummary = $shapeSummary | ConvertTo-Json -Depth 20 -Compress | ConvertFrom-Json
        $nonHeistRun = $shapeRun | ConvertTo-Json -Depth 20 -Compress | ConvertFrom-Json
        $nonHeistSummary.ending = 'clean'
        $nonHeistRun.ending = 'clean'
        $nonHeistSummary.heist_seed_preflight = $null
        $nonHeistSummary.heist_preflight_admission = $null
        $nonHeistRun.heist_seed_preflight = $null
        $nonHeistRun.heist_preflight_admission = $null
        $nonHeistRun.heist_launch_setup = $null
        $nonHeistSummary.runs = [object[]]@($nonHeistRun)
        Assert-OneRunJsonShapes -Summary $nonHeistSummary -Run $nonHeistRun -Label 'valid non-Heist null fixture'
        $runtimeValidCaseCount++

        foreach ($fixture in @(
            [pscustomobject]@{ target = 'summary'; field = 'heist_seed_preflight' },
            [pscustomobject]@{ target = 'summary'; field = 'heist_preflight_admission' },
            [pscustomobject]@{ target = 'run'; field = 'heist_seed_preflight' },
            [pscustomobject]@{ target = 'run'; field = 'heist_preflight_admission' },
            [pscustomobject]@{ target = 'run'; field = 'heist_launch_setup' }
        )) {
            foreach ($kind in @('object', 'array', 'scalar')) {
                $runtimeHostileCaseCount++
                $summaryCopy = $nonHeistSummary | ConvertTo-Json -Depth 20 -Compress | ConvertFrom-Json
                $runCopy = $nonHeistRun | ConvertTo-Json -Depth 20 -Compress | ConvertFrom-Json
                $summaryCopy.runs = [object[]]@($runCopy)
                $target = if ($fixture.target -ceq 'summary') { $summaryCopy } else { $runCopy }
                switch ($kind) {
                    'object' { $target.($fixture.field) = [pscustomobject]@{ forbidden = $true } }
                    'array' { $target.($fixture.field) = [object[]]@(,([pscustomobject]@{ forbidden = $true })) }
                    'scalar' { $target.($fixture.field) = 'forbidden' }
                }
                if (-not (Test-Throws { Assert-OneRunJsonShapes -Summary $summaryCopy -Run $runCopy -Label "non-Heist $($fixture.field) $kind" })) {
                    Add-Failure -Message "One-run shape validator accepted non-null non-Heist field '$($fixture.target).$($fixture.field)' as $kind."
                }
            }
        }
    }
    finally {
        $Ending = $originalEnding
    }

    foreach ($fixture in @(
        [pscustomobject]@{ target = 'summary'; field = 'replay_admission' },
        [pscustomobject]@{ target = 'summary'; field = 'heist_seed_preflight' },
        [pscustomobject]@{ target = 'summary'; field = 'heist_preflight_admission' },
        [pscustomobject]@{ target = 'run'; field = 'replay_admission' },
        [pscustomobject]@{ target = 'run'; field = 'heist_seed_preflight' },
        [pscustomobject]@{ target = 'run'; field = 'heist_preflight_admission' },
        [pscustomobject]@{ target = 'run'; field = 'heist_launch_setup' },
        [pscustomobject]@{ target = 'run'; field = 'final_public_checkpoint' }
    )) {
        foreach ($variant in @('null', 'scalar', 'ordered-object', 'array', 'nested-array')) {
            $runtimeHostileCaseCount++
            $summaryCopy = ConvertTo-ContractClone -InputObject $shapeSummary
            $runCopy = ConvertTo-ContractClone -InputObject $shapeRun
            $summaryCopy.runs = [object[]]@($runCopy)
            $target = if ($fixture.target -ceq 'summary') { $summaryCopy } else { $runCopy }
            $prior = $target.($fixture.field)
            switch ($variant) {
                'null' { $target.($fixture.field) = $null }
                'scalar' { $target.($fixture.field) = 'not-an-object' }
                'ordered-object' { $target.($fixture.field) = [ordered]@{} }
                'array' { $target.($fixture.field) = [object[]]@(,$prior) }
                'nested-array' { $target.($fixture.field) = [object[]]@(,([object[]]@(,$prior))) }
            }
            if (-not (Test-Throws { Assert-OneRunJsonShapes -Summary $summaryCopy -Run $runCopy -Label "embedded $($fixture.field) $variant" })) {
                Add-Failure -Message "One-run shape validator accepted $variant embedded object '$($fixture.target).$($fixture.field)'."
            }
        }
    }
    foreach ($fixture in @(
        [pscustomobject]@{ target = 'summary'; field = 'observed_terminal_seeds'; expected = [object[]]@($Seed) },
        [pscustomobject]@{ target = 'summary'; field = 'runs'; expected = [object[]]@($shapeRun) },
        [pscustomobject]@{ target = 'launch'; field = 'selected_content_groups'; expected = [object[]]@('group-a', 'group-b') }
    )) {
        foreach ($variant in @('null', 'scalar', 'object', 'nested-array', 'wrong-element', 'empty', 'extra')) {
            if ($fixture.field -ceq 'selected_content_groups' -and $variant -cin @('empty','extra')) {
                continue
            }
            $runtimeHostileCaseCount++
            $summaryCopy = ConvertTo-ContractClone -InputObject $shapeSummary
            $runCopy = ConvertTo-ContractClone -InputObject $shapeRun
            $summaryCopy.runs = [object[]]@($runCopy)
            $target = if ($fixture.target -ceq 'launch') { $runCopy.heist_launch_setup } else { $summaryCopy }
            $prior = $target.($fixture.field)
            switch ($variant) {
                'null' { $target.($fixture.field) = $null }
                'scalar' { $target.($fixture.field) = 'not-an-array' }
                'object' { $target.($fixture.field) = [pscustomobject]@{ hostile = $true } }
                'nested-array' { $target.($fixture.field) = [object[]]@(,([object[]]@($prior))) }
                'wrong-element' {
                    if ($fixture.field -ceq 'runs') { $target.($fixture.field) = [object[]]@('not-a-run') }
                    else { $target.($fixture.field) = [object[]]@([int32]7) }
                }
                'empty' { $target.($fixture.field) = [object[]]@() }
                'extra' { $target.($fixture.field) = [object[]]@($prior) + [object[]]@($prior[0]) }
            }
            if (-not (Test-Throws { Assert-OneRunJsonShapes -Summary $summaryCopy -Run $runCopy -Label "$($fixture.field) array $variant" })) {
                Add-Failure -Message "One-run shape validator accepted $variant array '$($fixture.field)'."
            }
        }
    }
    foreach ($field in @('selected_challenge_id', 'selected_home_type_id')) {
        foreach ($variant in @('null', 'object', 'array', 'nested-array', 'wrong-scalar')) {
            $runtimeHostileCaseCount++
            $summaryCopy = ConvertTo-ContractClone -InputObject $shapeSummary
            $runCopy = ConvertTo-ContractClone -InputObject $shapeRun
            $summaryCopy.runs = [object[]]@($runCopy)
            $prior = $runCopy.heist_launch_setup.$field
            switch ($variant) {
                'null' { $runCopy.heist_launch_setup.$field = $null }
                'object' { $runCopy.heist_launch_setup.$field = [pscustomobject]@{ hostile = $true } }
                'array' { $runCopy.heist_launch_setup.$field = [object[]]@(,$prior) }
                'nested-array' { $runCopy.heist_launch_setup.$field = [object[]]@(,([object[]]@(,$prior))) }
                'wrong-scalar' { $runCopy.heist_launch_setup.$field = [int32]7 }
            }
            if (-not (Test-Throws { Assert-OneRunJsonShapes -Summary $summaryCopy -Run $runCopy -Label "launch $field $variant" })) {
                Add-Failure -Message "One-run shape validator accepted $variant launch scalar '$field'."
            }
        }
    }
    foreach ($rootName in @('summary', 'run')) {
        $originalRootValue = if ($rootName -ceq 'summary') { $shapeSummary } else { $shapeRun }
        foreach ($rootFixture in @(
            [pscustomobject]@{ name = 'null'; value = $null },
            [pscustomobject]@{ name = 'ordered-object'; value = [ordered]@{} },
            [pscustomobject]@{ name = 'scalar'; value = 'one-run-root' },
            [pscustomobject]@{ name = 'array'; value = [object[]]@(,$originalRootValue) },
            [pscustomobject]@{ name = 'nested-array'; value = [object[]]@(,([object[]]@(,$originalRootValue))) }
        )) {
            $runtimeHostileCaseCount++
            $summaryValue = $shapeSummary
            $runValue = $shapeRun
            if ($rootName -ceq 'summary') { $summaryValue = $rootFixture.value }
            else { $runValue = $rootFixture.value }
            if (-not (Test-Throws { Assert-OneRunJsonShapes -Summary $summaryValue -Run $runValue -Label "$rootName root $($rootFixture.name)" })) {
                Add-Failure -Message "One-run shape validator accepted $rootName root '$($rootFixture.name)'."
            }
        }
    }
    foreach ($targetName in @('summary', 'run', 'launch')) {
        $runtimeHostileCaseCount++
        $summaryCopy = ConvertTo-ContractClone -InputObject $shapeSummary
        $runCopy = ConvertTo-ContractClone -InputObject $shapeRun
        $summaryCopy.runs = [object[]]@($runCopy)
        switch ($targetName) {
            'summary' { $summaryCopy | Add-Member -NotePropertyName authority -NotePropertyValue 'hostile' }
            'run' {
                $runCopy | Add-Member -NotePropertyName authority -NotePropertyValue 'hostile'
                $summaryCopy.runs = [object[]]@($runCopy)
            }
            'launch' { $runCopy.heist_launch_setup | Add-Member -NotePropertyName authority -NotePropertyValue 'hostile' }
        }
        if (-not (Test-Throws { Assert-OneRunJsonShapes -Summary $summaryCopy -Run $runCopy -Label "$targetName extra" })) {
            Add-Failure -Message "One-run shape validator accepted extra $targetName object field."
        }
    }
    foreach ($arrayFixture in @(
        [pscustomobject]@{ name = 'observed terminal seeds'; value = [object[]]@($Seed); expected = [object[]]@($Seed) },
        [pscustomobject]@{ name = 'selected content groups'; value = [object[]]@('group-a','group-b'); expected = [object[]]@('group-a','group-b') }
    )) {
        $arrayHostiles = @(
            [pscustomobject]@{ value = $null },
            [pscustomobject]@{ value = 'array-scalar' },
            [pscustomobject]@{ value = [pscustomobject]@{ hostile = $true } },
            [pscustomobject]@{ value = [object[]]@(,([object[]]@($arrayFixture.value))) },
            [pscustomobject]@{ value = [object[]]@([int32]7) },
            [pscustomobject]@{ value = [object[]]@() },
            [pscustomobject]@{ value = ([object[]]@($arrayFixture.value) + [object[]]@('extra')) },
            [pscustomobject]@{ value = [object[]]@('wrong-value') }
        )
        if ($arrayFixture.value.Count -gt 1) {
            $reorderedArray = [object[]]@($arrayFixture.value)
            [Array]::Reverse($reorderedArray)
            $arrayHostiles += [pscustomobject]@{ value = $reorderedArray }
        }
        foreach ($hostileFixture in $arrayHostiles) {
            $runtimeHostileCaseCount++
            if (Test-ExactStringArray -Value $hostileFixture.value -Expected $arrayFixture.expected) {
                Add-Failure -Message "Exact string-array validator accepted hostile $($arrayFixture.name) fixture."
            }
        }
    }
    foreach ($field in @(
        'schema_version', 'record_kind', 'observed_seed', 'outcome_key', 'won', 'public_fingerprint',
        'checkpoint_fingerprint', 'bankroll', 'chips', 'heat'
    )) {
        foreach ($targetName in @('retained', 'published')) {
            $runtimeHostileCaseCount++
            $retainedCopy = $shapeCheckpoint | ConvertTo-Json -Depth 10 -Compress | ConvertFrom-Json
            $publishedCopy = $shapeCheckpoint | ConvertTo-Json -Depth 10 -Compress | ConvertFrom-Json
            $target = if ($targetName -ceq 'retained') { $retainedCopy } else { $publishedCopy }
            $target.$field = [object[]]@($target.$field)
            if (-not (Test-Throws { Assert-FinalCheckpointJsonShapes -Retained $retainedCopy -Published $publishedCopy -Label "$targetName $field array" })) {
                Add-Failure -Message "Final-checkpoint shape validator accepted $targetName scalar array '$field'."
            }
        }
    }
    foreach ($targetName in @('retained', 'published')) {
        $runtimeHostileCaseCount++
        $retainedCopy = $shapeCheckpoint | ConvertTo-Json -Depth 10 -Compress | ConvertFrom-Json
        $publishedCopy = $shapeCheckpoint | ConvertTo-Json -Depth 10 -Compress | ConvertFrom-Json
        $target = if ($targetName -ceq 'retained') { $retainedCopy } else { $publishedCopy }
        $target.schema_version = [int32]2
        if (-not (Test-Throws { Assert-FinalCheckpointJsonShapes -Retained $retainedCopy -Published $publishedCopy -Label "$targetName wrong schema" })) {
            Add-Failure -Message "Final-checkpoint shape validator accepted wrong $targetName schema_version."
        }
    }
    foreach ($field in @('schema_version', 'bankroll', 'chips', 'heat')) {
        foreach ($targetName in @('retained', 'published')) {
            foreach ($typedValue in @(
                [pscustomobject]@{ name = 'Int64'; value = [int64]1 },
                [pscustomobject]@{ name = 'Double'; value = [double]1 },
                [pscustomobject]@{ name = 'Decimal'; value = [decimal]1 },
                [pscustomobject]@{ name = 'UInt32'; value = [uint32]1 },
                [pscustomobject]@{ name = 'OutOfRangeInt64'; value = ([int64][int32]::MaxValue + 1) }
            )) {
                $runtimeHostileCaseCount++
                $retainedCopy = $shapeCheckpoint | ConvertTo-Json -Depth 10 -Compress | ConvertFrom-Json
                $publishedCopy = $shapeCheckpoint | ConvertTo-Json -Depth 10 -Compress | ConvertFrom-Json
                $target = if ($targetName -ceq 'retained') { $retainedCopy } else { $publishedCopy }
                $target.$field = $typedValue.value
                if (-not (Test-Throws { Assert-FinalCheckpointJsonShapes -Retained $retainedCopy -Published $publishedCopy -Label "$targetName $field $($typedValue.name)" })) {
                    Add-Failure -Message "Final-checkpoint shape validator accepted $($typedValue.name) $targetName field '$field'."
                }
            }
        }
    }
    foreach ($targetName in @('retained','published')) {
        foreach ($rootFixture in @(
            [pscustomobject]@{ name = 'null'; value = $null },
            [pscustomobject]@{ name = 'ordered-object'; value = [ordered]@{} },
            [pscustomobject]@{ name = 'scalar'; value = 'checkpoint-scalar' },
            [pscustomobject]@{ name = 'array'; value = [object[]]@(,$shapeCheckpoint) },
            [pscustomobject]@{ name = 'nested-array'; value = [object[]]@(,([object[]]@($shapeCheckpoint))) }
        )) {
            $runtimeHostileCaseCount++
            $retainedValue = $shapeCheckpoint
            $publishedValue = $shapeCheckpoint
            if ($targetName -ceq 'retained') { $retainedValue = $rootFixture.value }
            else { $publishedValue = $rootFixture.value }
            if (-not (Test-Throws { Assert-FinalCheckpointJsonShapes -Retained $retainedValue -Published $publishedValue -Label "$targetName checkpoint root $($rootFixture.name)" })) {
                Add-Failure -Message "Final-checkpoint shape validator accepted $targetName root '$($rootFixture.name)'."
            }
        }
    }
    foreach ($mutation in @('identical-empty','identical-extra','retained-reordered','published-reordered')) {
        $runtimeHostileCaseCount++
        $retainedCopy = ConvertTo-ContractClone -InputObject $shapeCheckpoint
        $publishedCopy = ConvertTo-ContractClone -InputObject $shapeCheckpoint
        switch ($mutation) {
            'identical-empty' { $retainedCopy = [pscustomobject]@{}; $publishedCopy = [pscustomobject]@{} }
            'identical-extra' {
                $retainedCopy | Add-Member -NotePropertyName authority -NotePropertyValue 'hostile'
                $publishedCopy | Add-Member -NotePropertyName authority -NotePropertyValue 'hostile'
            }
            'retained-reordered' { $retainedCopy = New-ReorderedContractObject -InputObject $retainedCopy }
            'published-reordered' { $publishedCopy = New-ReorderedContractObject -InputObject $publishedCopy }
        }
        if (-not (Test-Throws { Assert-FinalCheckpointJsonShapes -Retained $retainedCopy -Published $publishedCopy -Label "hostile final checkpoint $mutation" })) {
            Add-Failure -Message "Final-checkpoint shape validator accepted '$mutation'."
        }
    }
    foreach ($targetName in @('retained','published')) {
        foreach ($field in @('public_fingerprint','checkpoint_fingerprint')) {
            $runtimeHostileCaseCount++
            $retainedCopy = ConvertTo-ContractClone -InputObject $shapeCheckpoint
            $publishedCopy = ConvertTo-ContractClone -InputObject $shapeCheckpoint
            $target = if ($targetName -ceq 'retained') { $retainedCopy } else { $publishedCopy }
            $target.$field = 'A' * 64
            if (-not (Test-Throws { Assert-FinalCheckpointJsonShapes -Retained $retainedCopy -Published $publishedCopy -Label "uppercase $targetName $field" })) {
                Add-Failure -Message "Final-checkpoint shape validator accepted uppercase $targetName '$field'."
            }
        }
    }
    $proofScalarFields = @(
        'run_index', 'role', 'evidence_role', 'ending', 'seed', 'outcome', 'action_count',
        'profile_inventory_sha256', 'autosave_sha256', 'replay_summary_sha256',
        'launcher_stdout_sha256', 'launcher_stderr_sha256', 'run_summary_sha256',
        'transcript_sha256', 'money_curve_sha256', 'persistence_checkpoint_before_sha256',
        'persistence_checkpoint_after_sha256', 'final_public_checkpoint_sha256',
        'source_custody_pre_sha256', 'godot_stdout_sha256', 'godot_stderr_sha256', 'godot_engine_sha256',
        'profile_roaming', 'profile_local', 'profile_session_root', 'profile_inventory', 'autosave',
        'replay_invocation_root', 'replay_summary', 'launcher_stdout', 'launcher_stderr',
        'run_root', 'run_summary', 'session_root', 'source_custody_pre',
        'session', 'replay_pid', 'heist_seed_preflight', 'heist_seed_preflight_sha256'
    )
    foreach ($field in $proofScalarFields) {
        foreach ($variant in @('missing', 'null', 'object', 'array', 'nested-array', 'wrong-scalar')) {
            $runtimeHostileCaseCount++
            $decodedCopy = $proofs | ConvertTo-Json -Depth 10 -Compress | ConvertFrom-Json
            $copy = @($decodedCopy)
            switch ($variant) {
                'missing' { $copy[0].PSObject.Properties.Remove($field) }
                'null' { $copy[0].$field = $null }
                'object' { $copy[0].$field = [pscustomobject]@{} }
                'array' { $copy[0].$field = [object[]]@($copy[0].$field) }
                'nested-array' { $copy[0].$field = [object[]]@(,([object[]]@($copy[0].$field))) }
                'wrong-scalar' {
                    $copy[0].$field = if ($field -cin @('run_index', 'action_count', 'replay_pid')) { '1' } else { [bool]$true }
                }
            }
            if (-not (Test-Throws { $null = Compare-FixedRunProofs -Proofs $copy })) {
                Add-Failure -Message "Compare-FixedRunProofs accepted $variant field '$field'."
            }
        }
    }
    foreach ($mutation in @('extra', 'root-array', 'run-index-zero', 'run-index-three', 'run-index-swapped',
        'run-index-int64', 'replay-pid-int64', 'outcome-invalid', 'outcome-differs', 'action-zero', 'action-351',
        'action-int64', 'action-differs')) {
        $runtimeHostileCaseCount++
        $decodedCopy = $proofs | ConvertTo-Json -Depth 10 -Compress | ConvertFrom-Json
        $copy = @($decodedCopy)
        $proofArgument = $copy
        switch ($mutation) {
            'extra' { $copy[0] | Add-Member -NotePropertyName authority -NotePropertyValue 'hostile' }
            'root-array' { $proofArgument = [object[]]@(,([object[]]@($copy))) }
            'run-index-zero' { $copy[0].run_index = [int32]0 }
            'run-index-three' { $copy[1].run_index = [int32]3 }
            'run-index-swapped' { $copy[0].run_index = [int32]2; $copy[1].run_index = [int32]1 }
            'run-index-int64' { $copy[0].run_index = [int64]1 }
            'replay-pid-int64' { $copy[0].replay_pid = [int64]101 }
            'outcome-invalid' { $copy[0].outcome = 'not-a-win' }
            'outcome-differs' { $copy[1].outcome = 'heist_out_hot' }
            'action-zero' { $copy[0].action_count = [int32]0 }
            'action-351' { $copy[0].action_count = [int32]351 }
            'action-int64' { $copy[0].action_count = [int64]42 }
            'action-differs' { $copy[1].action_count = [int32]43 }
        }
        if (-not (Test-Throws { $null = Compare-FixedRunProofs -Proofs $proofArgument })) {
            Add-Failure -Message "Compare-FixedRunProofs accepted hostile mutation '$mutation'."
        }
    }

    foreach ($mutation in @(
        'outer-run-coherent', 'profile-local-leaf', 'profile-session-root-leaf',
        'profile-inventory-leaf', 'autosave-leaf', 'invocation-parent-coherent',
        'invocation-format-coherent', 'invocation-pid-coherent', 'invocation-date-coherent',
        'replay-summary-leaf', 'launcher-stdout-leaf', 'launcher-stderr-leaf',
        'inner-run-leaf', 'run-summary-leaf', 'session-ending-coherent',
        'session-pid-coherent', 'session-date-mismatch', 'session-base-root', 'replay-pid-only'
    )) {
        $runtimeHostileCaseCount++
        $decodedCopy = $proofs | ConvertTo-Json -Depth 20 -Compress | ConvertFrom-Json
        $copy = @($decodedCopy)
        $proof = $copy[0]
        switch ($mutation) {
            'outer-run-coherent' {
                $proof.profile_roaming = 'C:\proof-aggregate\run-03\profile_roaming'
                $proof.profile_session_root = 'C:\proof-aggregate\run-03\profile_roaming\Godot\app_userdata\Beat the House\agent_playtest\rw062-heist-101-1-aaaaaaaaaa'
                $proof.profile_inventory = $proof.profile_session_root + '\profile_inventory.json'
                $proof.autosave = $proof.profile_session_root + '\saves\foundation_ui_autosave.json'
            }
            'profile-local-leaf' { $proof.profile_local = 'C:\proof-aggregate\run-01\profile_local-hostile' }
            'profile-session-root-leaf' { $proof.profile_session_root = $proof.profile_session_root + '-hostile' }
            'profile-inventory-leaf' { $proof.profile_inventory = 'C:\proof-aggregate\run-01\profile_roaming\Godot\app_userdata\Beat the House\agent_playtest\rw062-heist-101-1-aaaaaaaaaa\inventory.json' }
            'autosave-leaf' { $proof.autosave = 'C:\proof-aggregate\run-01\profile_roaming\Godot\app_userdata\Beat the House\agent_playtest\rw062-heist-101-1-aaaaaaaaaa\saves\wrong.json' }
            'invocation-parent-coherent' {
                $proof.replay_invocation_root = 'C:\proof-aggregate\run-02\replay\20260924-010203-004-101'
                $proof.replay_summary = $proof.replay_invocation_root + '\summary.json'
                $proof.run_root = $proof.replay_invocation_root + '\run-01'
                $proof.run_summary = $proof.run_root + '\summary.json'
                $proof.heist_seed_preflight = $proof.replay_invocation_root + '\heist_seed_preflight.json'
            }
            'invocation-format-coherent' {
                $proof.replay_invocation_root = 'C:\proof-aggregate\run-01\replay\20260924-010203-101'
                $proof.replay_summary = $proof.replay_invocation_root + '\summary.json'
                $proof.run_root = $proof.replay_invocation_root + '\run-01'
                $proof.run_summary = $proof.run_root + '\summary.json'
                $proof.heist_seed_preflight = $proof.replay_invocation_root + '\heist_seed_preflight.json'
            }
            'invocation-pid-coherent' {
                $proof.replay_invocation_root = 'C:\proof-aggregate\run-01\replay\20260924-010203-004-999'
                $proof.replay_summary = $proof.replay_invocation_root + '\summary.json'
                $proof.run_root = $proof.replay_invocation_root + '\run-01'
                $proof.run_summary = $proof.run_root + '\summary.json'
                $proof.heist_seed_preflight = $proof.replay_invocation_root + '\heist_seed_preflight.json'
            }
            'invocation-date-coherent' {
                $proof.replay_invocation_root = 'C:\proof-aggregate\run-01\replay\20260923-010203-004-101'
                $proof.replay_summary = $proof.replay_invocation_root + '\summary.json'
                $proof.run_root = $proof.replay_invocation_root + '\run-01'
                $proof.run_summary = $proof.run_root + '\summary.json'
                $proof.heist_seed_preflight = $proof.replay_invocation_root + '\heist_seed_preflight.json'
            }
            'replay-summary-leaf' { $proof.replay_summary = $proof.replay_invocation_root + '\other.json' }
            'launcher-stdout-leaf' { $proof.launcher_stdout = 'C:\proof-aggregate\run-01\outer.stdout.txt' }
            'launcher-stderr-leaf' { $proof.launcher_stderr = 'C:\proof-aggregate\run-01\outer.stderr.txt' }
            'inner-run-leaf' {
                $proof.run_root = $proof.replay_invocation_root + '\run-02'
                $proof.run_summary = $proof.run_root + '\summary.json'
            }
            'run-summary-leaf' { $proof.run_summary = $proof.run_root + '\other.json' }
            'session-ending-coherent' {
                $proof.session = 'rw062-cheat-101-1-aaaaaaaaaa'
                $proof.profile_session_root = 'C:\proof-aggregate\run-01\profile_roaming\Godot\app_userdata\Beat the House\agent_playtest\rw062-cheat-101-1-aaaaaaaaaa'
                $proof.profile_inventory = $proof.profile_session_root + '\profile_inventory.json'
                $proof.autosave = $proof.profile_session_root + '\saves\foundation_ui_autosave.json'
                $proof.session_root = Join-Path $Worktree '.tmp\agent_playtest\2026-09-24\rw062-cheat-101-1-aaaaaaaaaa'
            }
            'session-pid-coherent' {
                $proof.session = 'rw062-heist-999-1-aaaaaaaaaa'
                $proof.profile_session_root = 'C:\proof-aggregate\run-01\profile_roaming\Godot\app_userdata\Beat the House\agent_playtest\rw062-heist-999-1-aaaaaaaaaa'
                $proof.profile_inventory = $proof.profile_session_root + '\profile_inventory.json'
                $proof.autosave = $proof.profile_session_root + '\saves\foundation_ui_autosave.json'
                $proof.session_root = Join-Path $Worktree '.tmp\agent_playtest\2026-09-24\rw062-heist-999-1-aaaaaaaaaa'
            }
            'session-date-mismatch' { $proof.session_root = Join-Path $Worktree '.tmp\agent_playtest\2026-09-23\rw062-heist-101-1-aaaaaaaaaa' }
            'session-base-root' { $proof.session_root = Join-Path $Worktree '.tmp\agent_playtest-hostile\2026-09-24\rw062-heist-101-1-aaaaaaaaaa' }
            'replay-pid-only' { $proof.replay_pid = [int32]999 }
        }
        if (-not (Test-Throws { $null = Compare-FixedRunProofs -Proofs $copy })) {
            Add-Failure -Message "Compare-FixedRunProofs accepted well-typed hostile path graph '$mutation'."
        }
    }

    foreach ($collectionFixture in @(
        [pscustomobject]@{ name = 'null'; value = $null },
        [pscustomobject]@{ name = 'scalar'; value = 'proofs-scalar' },
        [pscustomobject]@{ name = 'object'; value = $proofs[0] },
        [pscustomobject]@{ name = 'ordered-object'; value = [ordered]@{} },
        [pscustomobject]@{ name = 'array-list'; value = [Collections.ArrayList]@($proofs) },
        [pscustomobject]@{ name = 'empty'; value = [object[]]@() },
        [pscustomobject]@{ name = 'single'; value = [object[]]@($proofs[0]) },
        [pscustomobject]@{ name = 'nested'; value = [object[]]@(,([object[]]@($proofs))) },
        [pscustomobject]@{ name = 'wrong-element'; value = [object[]]@('not-a-proof',$proofs[1]) },
        [pscustomobject]@{ name = 'swapped'; value = [object[]]@($proofs[1],$proofs[0]) },
        [pscustomobject]@{ name = 'duplicate'; value = [object[]]@($proofs[0],$proofs[0]) },
        [pscustomobject]@{ name = 'extra'; value = [object[]]@($proofs[0],$proofs[1],$proofs[0]) }
    )) {
        $runtimeHostileCaseCount++
        if (-not (Test-Throws { $null = Compare-FixedRunProofs -Proofs $collectionFixture.value })) {
            Add-Failure -Message "Compare-FixedRunProofs accepted hostile proof collection '$($collectionFixture.name)'."
        }
    }
    foreach ($elementFixture in @(
        [pscustomobject]@{ name = 'null'; value = $null },
        [pscustomobject]@{ name = 'scalar'; value = 'proof-element' },
        [pscustomobject]@{ name = 'ordered-object'; value = [ordered]@{} },
        [pscustomobject]@{ name = 'object-array'; value = [object[]]@($proofs[0]) },
        [pscustomobject]@{ name = 'nested-array'; value = [object[]]@(,([object[]]@($proofs[0]))) }
    )) {
        $runtimeHostileCaseCount++
        $decodedCopy = $proofs | ConvertTo-Json -Depth 20 -Compress | ConvertFrom-Json
        $copy = [object[]]@($decodedCopy)
        $copy[0] = $elementFixture.value
        if (-not (Test-Throws { $null = Compare-FixedRunProofs -Proofs $copy })) {
            Add-Failure -Message "Compare-FixedRunProofs accepted hostile proof-element root '$($elementFixture.name)'."
        }
    }

    $ExpectedHead = 'a' * 40
    $ExpectedTree = 'b' * 40
    $emptyCensus = [object[]]@()
    foreach ($hashField in @(
        'profile_inventory_sha256','autosave_sha256','replay_summary_sha256',
        'launcher_stdout_sha256','launcher_stderr_sha256','run_summary_sha256',
        'transcript_sha256','money_curve_sha256','persistence_checkpoint_before_sha256',
        'persistence_checkpoint_after_sha256','final_public_checkpoint_sha256',
        'heist_seed_preflight_sha256','source_custody_pre_sha256','godot_stdout_sha256',
        'godot_stderr_sha256','godot_engine_sha256'
    )) {
        $runtimeHostileCaseCount++
        $decodedCopy = $proofs | ConvertTo-Json -Depth 20 -Compress | ConvertFrom-Json
        $copy = @($decodedCopy)
        $copy[0].$hashField = 'A' * 64
        if (-not (Test-Throws { $null = Compare-FixedRunProofs -Proofs $copy })) {
            Add-Failure -Message "Compare-FixedRunProofs accepted uppercase hash field '$hashField'."
        }
    }
    foreach ($hashField in @(
        'run_1_proof_sha256','run_2_proof_sha256',
        'transcript_sha256','money_curve_sha256','persistence_checkpoint_sha256',
        'final_public_checkpoint_sha256','heist_seed_preflight_sha256'
    )) {
        $runtimeHostileCaseCount++
        $hostileCanonical = ConvertTo-ContractClone -InputObject $canonicalProof
        $hostileCanonical.$hashField = if ($hostileCanonical.$hashField -cne ('f' * 64)) { 'f' * 64 } else { 'e' * 64 }
        if (Test-FixedRepeatQualification -TerminalError $null -Outcome 'green' -RunProofs $proofs `
            -CanonicalProof $hostileCanonical -LeaseOwned:$false -FinalProcessCensus $emptyCensus `
            -FinalHead $ExpectedHead -FinalTree $ExpectedTree -SourceCustodyComplete:$true) {
            Add-Failure -Message "Aggregate qualification accepted canonical well-formed mismatched hash '$hashField'."
        }
    }

    if (-not (Test-FixedRepeatQualification -TerminalError $null -Outcome 'green' -RunProofs $proofs `
        -CanonicalProof $canonicalProof -LeaseOwned:$false -FinalProcessCensus $emptyCensus `
        -FinalHead $ExpectedHead -FinalTree $ExpectedTree -SourceCustodyComplete:$true)) {
        throw 'Valid aggregate qualification fixture failed.'
    }
    $runtimeValidCaseCount++
    foreach ($identicalMutation in @('action_count', 'outcome')) {
        $runtimeHostileCaseCount++
        $decodedMutatedProofs = $proofs | ConvertTo-Json -Depth 20 -Compress | ConvertFrom-Json
        $mutatedProofs = @($decodedMutatedProofs)
        if ($identicalMutation -ceq 'action_count') {
            $mutatedProofs[0].action_count = [int32]1
            $mutatedProofs[1].action_count = [int32]1
        }
        else {
            $mutatedProofs[0].outcome = 'heist_out_hot'
            $mutatedProofs[1].outcome = 'heist_out_hot'
        }
        if (Test-FixedRepeatQualification -TerminalError $null -Outcome 'green' -RunProofs $mutatedProofs `
            -CanonicalProof $canonicalProof -LeaseOwned:$false -FinalProcessCensus $emptyCensus `
            -FinalHead $ExpectedHead -FinalTree $ExpectedTree -SourceCustodyComplete:$true) {
            Add-Failure -Message "Aggregate qualification accepted identical post-promotion $identicalMutation mutation in both complete run proofs."
        }
    }
    $canonicalFields = @(
        'evidence_role', 'deterministic', 'isolated_profiles',
        'run_1_proof_sha256', 'run_2_proof_sha256', 'transcript_sha256',
        'money_curve_sha256', 'persistence_checkpoint_sha256',
        'final_public_checkpoint_sha256', 'heist_seed_preflight_sha256'
    )
    foreach ($field in $canonicalFields) {
        foreach ($variant in @('missing', 'null', 'object', 'array', 'nested-array', 'wrong-scalar')) {
            $runtimeHostileCaseCount++
            $hostileCanonical = $canonicalProof | ConvertTo-Json -Depth 10 -Compress | ConvertFrom-Json
            switch ($variant) {
                'missing' { $hostileCanonical.PSObject.Properties.Remove($field) }
                'null' { $hostileCanonical.$field = $null }
                'object' { $hostileCanonical.$field = [pscustomobject]@{} }
                'array' { $hostileCanonical.$field = [object[]]@($hostileCanonical.$field) }
                'nested-array' { $hostileCanonical.$field = [object[]]@(,([object[]]@($hostileCanonical.$field))) }
                'wrong-scalar' {
                    $hostileCanonical.$field = if ($field -cin @('deterministic', 'isolated_profiles')) { 'true' } else { [int32]1 }
                }
            }
            if (Test-FixedRepeatQualification -TerminalError $null -Outcome 'green' -RunProofs $proofs `
                -CanonicalProof $hostileCanonical -LeaseOwned:$false -FinalProcessCensus $emptyCensus `
                -FinalHead $ExpectedHead -FinalTree $ExpectedTree -SourceCustodyComplete:$true) {
                Add-Failure -Message "Aggregate qualification accepted canonical $variant field '$field'."
            }
        }
    }
    foreach ($hashField in @(
        'run_1_proof_sha256','run_2_proof_sha256',
        'transcript_sha256','money_curve_sha256','persistence_checkpoint_sha256',
        'final_public_checkpoint_sha256','heist_seed_preflight_sha256'
    )) {
        $runtimeHostileCaseCount++
        $hostileCanonical = ConvertTo-ContractClone -InputObject $canonicalProof
        $hostileCanonical.$hashField = 'A' * 64
        if (Test-FixedRepeatQualification -TerminalError $null -Outcome 'green' -RunProofs $proofs `
            -CanonicalProof $hostileCanonical -LeaseOwned:$false -FinalProcessCensus $emptyCensus `
            -FinalHead $ExpectedHead -FinalTree $ExpectedTree -SourceCustodyComplete:$true) {
            Add-Failure -Message "Aggregate qualification accepted canonical uppercase hash '$hashField'."
        }
    }
    foreach ($mutation in @('canonical-extra', 'canonical-root-array', 'deterministic-false', 'isolated-false',
        'run-proofs-arraylist', 'census-arraylist', 'lease-string', 'custody-string')) {
        $runtimeHostileCaseCount++
        $canonicalArgument = $canonicalProof | ConvertTo-Json -Depth 10 -Compress | ConvertFrom-Json
        $proofArgument = $proofs
        $censusArgument = $emptyCensus
        $leaseArgument = $false
        $custodyArgument = $true
        switch ($mutation) {
            'canonical-extra' { $canonicalArgument | Add-Member -NotePropertyName authority -NotePropertyValue 'hostile' }
            'canonical-root-array' { $canonicalArgument = [object[]]@($canonicalArgument) }
            'deterministic-false' { $canonicalArgument.deterministic = $false }
            'isolated-false' { $canonicalArgument.isolated_profiles = $false }
            'run-proofs-arraylist' { $proofArgument = [Collections.ArrayList]@($proofs) }
            'census-arraylist' { $censusArgument = [Collections.ArrayList]@() }
            'lease-string' { $leaseArgument = 'false' }
            'custody-string' { $custodyArgument = 'true' }
        }
        if (Test-FixedRepeatQualification -TerminalError $null -Outcome 'green' -RunProofs $proofArgument `
            -CanonicalProof $canonicalArgument -LeaseOwned $leaseArgument -FinalProcessCensus $censusArgument `
            -FinalHead $ExpectedHead -FinalTree $ExpectedTree -SourceCustodyComplete $custodyArgument) {
            Add-Failure -Message "Aggregate qualification accepted hostile mutation '$mutation'."
        }
    }
    foreach ($canonicalRootFixture in @(
        [pscustomobject]@{ name = 'null'; value = $null },
        [pscustomobject]@{ name = 'scalar'; value = 'canonical-proof' },
        [pscustomobject]@{ name = 'ordered-object'; value = [ordered]@{} },
        [pscustomobject]@{ name = 'array'; value = [object[]]@($canonicalProof) },
        [pscustomobject]@{ name = 'nested-array'; value = [object[]]@(,([object[]]@($canonicalProof))) }
    )) {
        $runtimeHostileCaseCount++
        if (Test-FixedRepeatQualification -TerminalError $null -Outcome 'green' -RunProofs $proofs `
            -CanonicalProof $canonicalRootFixture.value -LeaseOwned:$false -FinalProcessCensus $emptyCensus `
            -FinalHead $ExpectedHead -FinalTree $ExpectedTree -SourceCustodyComplete:$true) {
            Add-Failure -Message "Aggregate qualification accepted canonical root '$($canonicalRootFixture.name)'."
        }
    }

    $originalProofEnding = $Ending
    $originalProofSeed = $Seed
    try {
        $Ending = 'clean'
        $Seed = 'RW06-CLEAN-ROUTE-01'
        $ExpectedOutcomes.clean = @('players_card')
        $decodedNonHeistProofs = $proofs | ConvertTo-Json -Depth 20 -Compress | ConvertFrom-Json
        $nonHeistProofs = [object[]]@($decodedNonHeistProofs[0], $decodedNonHeistProofs[1])
        foreach ($proof in $nonHeistProofs) {
            $proof.ending = $Ending
            $proof.seed = $Seed
            $proof.outcome = 'players_card'
            $proof.session = ([string]$proof.session).Replace('rw062-heist-', 'rw062-clean-')
            $proof.profile_session_root = ([string]$proof.profile_session_root).Replace('rw062-heist-', 'rw062-clean-')
            $proof.profile_inventory = ([string]$proof.profile_inventory).Replace('rw062-heist-', 'rw062-clean-')
            $proof.autosave = ([string]$proof.autosave).Replace('rw062-heist-', 'rw062-clean-')
            $proof.session_root = ([string]$proof.session_root).Replace('rw062-heist-', 'rw062-clean-')
            $proof.heist_seed_preflight = $null
            $proof.heist_seed_preflight_sha256 = $null
        }
        $nonHeistCanonical = Compare-FixedRunProofs -Proofs $nonHeistProofs
        Assert-CanonicalFixedProofShape -Proof $nonHeistCanonical -Label 'Valid non-Heist canonical proof'
        $runtimeValidCaseCount++
        foreach ($fixture in @(
            [pscustomobject]@{ name = 'run path string'; target = 'run'; field = 'heist_seed_preflight'; value = 'C:\hostile\heist_seed_preflight.json' },
            [pscustomobject]@{ name = 'run path array'; target = 'run'; field = 'heist_seed_preflight'; value = [object[]]@('C:\hostile\heist_seed_preflight.json') },
            [pscustomobject]@{ name = 'run hash string'; target = 'run'; field = 'heist_seed_preflight_sha256'; value = ('f' * 64) },
            [pscustomobject]@{ name = 'run hash array'; target = 'run'; field = 'heist_seed_preflight_sha256'; value = [object[]]@('f' * 64) },
            [pscustomobject]@{ name = 'canonical hash string'; target = 'canonical'; field = 'heist_seed_preflight_sha256'; value = ('f' * 64) },
            [pscustomobject]@{ name = 'canonical hash object'; target = 'canonical'; field = 'heist_seed_preflight_sha256'; value = [pscustomobject]@{} },
            [pscustomobject]@{ name = 'canonical hash array'; target = 'canonical'; field = 'heist_seed_preflight_sha256'; value = [object[]]@('f' * 64) }
        )) {
            $runtimeHostileCaseCount++
            $decodedHostileProofs = $nonHeistProofs | ConvertTo-Json -Depth 20 -Compress | ConvertFrom-Json
            $hostileProofs = [object[]]@($decodedHostileProofs[0], $decodedHostileProofs[1])
            $hostileCanonical = ConvertTo-ContractClone -InputObject $nonHeistCanonical
            if ($fixture.target -ceq 'run') { $hostileProofs[0].($fixture.field) = $fixture.value }
            else { $hostileCanonical.($fixture.field) = $fixture.value }
            if (Test-FixedRepeatQualification -TerminalError $null -Outcome 'green' -RunProofs $hostileProofs `
                -CanonicalProof $hostileCanonical -LeaseOwned:$false -FinalProcessCensus $emptyCensus `
                -FinalHead $ExpectedHead -FinalTree $ExpectedTree -SourceCustodyComplete:$true) {
                Add-Failure -Message "Aggregate qualification accepted non-Heist hostile '$($fixture.name)'."
            }
        }
    }
    finally {
        $Ending = $originalProofEnding
        $Seed = $originalProofSeed
    }

    $fixtureRoot = Join-Path $Worktree ('.tmp\rw06_2\final_source_runtime-' + $PID + '-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $fixtureRoot -Force | Out-Null
    try {
        $GodotBin = 'D:\Projects\Beat-The-House\.tools\godot-4.6-stable\Godot_v4.6-stable_win64_console.exe'
        $GodotRuntimeBin = 'D:\Projects\Beat-The-House\.tools\godot-4.6-stable\Godot_v4.6-stable_win64.exe'
        $originalWorktree = $Worktree
        $originalExpectedHead = $ExpectedHead
        $originalExpectedTree = $ExpectedTree
        $ExpectedHead = (& git -C $originalWorktree rev-parse HEAD).Trim().ToLowerInvariant()
        if ($LASTEXITCODE -ne 0) { throw 'Could not resolve production HEAD for custody inventory fixture.' }
        $productionDescriptors = @(Get-TrackedSourceDescriptors)
        $productionIds = @($productionDescriptors | ForEach-Object { [string]$_.id })
        foreach ($requiredId in @(
            'repository:tools/rw06_2_final_evidence.ps1',
            'repository:tools/rw06_2_ending_replay.ps1',
            'repository:tools/rw06_2_evidence_admission.ps1',
            'repository:tools/rw06_2_replay_policies.ps1',
            'repository:tools/rw06_2_heist_seed_preflight.ps1',
            'repository:tools/agent_playtest_session.ps1',
            'repository:tools/agent_playtest_session.gd',
            'repository:project.godot',
            'repository:scripts/core/run_state.gd',
            'repository:scripts/core/rng_stream.gd',
            'repository:scripts/core/run_generator.gd',
            'repository:scripts/core/environment_hours.gd',
            'repository:scripts/ui/foundation_main.gd',
            'repository:scripts/core/meta_collection_service.gd',
            'repository:scripts/core/town_state.gd',
            'repository:scripts/core/police_sweep_model.gd',
            'repository:scripts/core/character_chain_model.gd',
            'repository:data/environments/archetypes.json',
            'repository:data/environments/scenarios.json',
            'repository:data/town/conditions.json',
            'godot:console', 'godot:runtime', 'powershell:host'
        )) {
            if ($productionIds -cnotcontains $requiredId) {
                throw "Immutable production HEAD inventory omitted '$requiredId'."
            }
        }
        $runtimeValidCaseCount++

        $sourceFixtureRepo = Join-Path $fixtureRoot 'source-repo'
        New-Item -ItemType Directory -Path $sourceFixtureRepo -Force | Out-Null
        & git -C $sourceFixtureRepo init --quiet
        & git -C $sourceFixtureRepo config user.name 'rw06_2 source contract'
        & git -C $sourceFixtureRepo config user.email 'rw06_2-source-contract@example.invalid'
        $fixtureSourcePath = Join-Path $sourceFixtureRepo 'source.txt'
        $fixtureAttributesPath = Join-Path $sourceFixtureRepo '.gitattributes'
        [IO.File]::WriteAllText($fixtureAttributesPath, "source.txt text eol=lf`n", [Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllText($fixtureSourcePath, "stable`nsource`n", [Text.UTF8Encoding]::new($false))
        & git -C $sourceFixtureRepo add -- .gitattributes source.txt
        & git -C $sourceFixtureRepo commit --quiet -m 'source fixture'
        if ($LASTEXITCODE -ne 0) { throw 'Could not create immutable source-custody fixture commit.' }
        $Worktree = $sourceFixtureRepo
        $ExpectedHead = (& git -C $Worktree rev-parse HEAD).Trim().ToLowerInvariant()
        $ExpectedTree = (& git -C $Worktree rev-parse 'HEAD^{tree}').Trim().ToLowerInvariant()
        $EvidenceRoot = Join-Path $fixtureRoot 'actual-source-custody'
        New-Item -ItemType Directory -Path $EvidenceRoot -Force | Out-Null
        $SourceCustodyPrePath = Join-Path $EvidenceRoot 'source_custody_pre.json'
        $SourceCustodyFinalPath = Join-Path $EvidenceRoot 'source_custody_final.json'
        $script:SourceCustodyStreams = [Collections.Generic.List[IO.FileStream]]::new()
        $script:SourceCustodyRows = [Collections.Generic.List[object]]::new()
        $script:SourceCustodyPreStream = $null
        $script:SourceCustodyFinalStream = $null
        $script:EvidenceArtifactStreams = [Collections.Generic.List[IO.FileStream]]::new()
        $script:SourceCustodyPreSha256 = ''
        $script:SourceCustodyFinalSha256 = ''
        $script:SourceCustodyComplete = $false
        try {
            New-SourceCustody
            Assert-SourceCustody
            Complete-SourceCustody
            $custodyIds = @($script:SourceCustodyRows | ForEach-Object { [string]$_.id })
            foreach ($requiredId in @(
                'repository:.gitattributes',
                'repository:source.txt',
                'godot:console', 'godot:runtime', 'powershell:host'
            )) {
                if ($custodyIds -cnotcontains $requiredId) {
                    throw "Actual source-custody inventory omitted '$requiredId'."
                }
            }
            if (-not $script:SourceCustodyComplete -or
                $script:SourceCustodyRows.Count -ne 5 -or
                $script:SourceCustodyPreSha256 -cnotmatch '^[a-f0-9]{64}$' -or
                $script:SourceCustodyFinalSha256 -cnotmatch '^[a-f0-9]{64}$' -or
                $null -eq $script:SourceCustodyPreStream -or -not $script:SourceCustodyPreStream.CanRead -or
                $null -eq $script:SourceCustodyFinalStream -or -not $script:SourceCustodyFinalStream.CanRead) {
                throw 'Actual source-custody inventory did not complete with exact receipts.'
            }
            $preReceipt = ConvertFrom-ExactJsonObjectText `
                -Json (Get-HeldUtf8Text -Stream $script:SourceCustodyPreStream) `
                -Label 'Runtime source custody pre receipt'
            $finalReceipt = ConvertFrom-ExactJsonObjectText `
                -Json (Get-HeldUtf8Text -Stream $script:SourceCustodyFinalStream) `
                -Label 'Runtime source custody final receipt'
            Assert-SourceCustodyReceiptSchema `
                -Receipt $preReceipt `
                -Phase pre `
                -Representation json `
                -Label 'Runtime source custody pre receipt'
            Assert-SourceCustodyReceiptSchema `
                -Receipt $finalReceipt `
                -Phase final `
                -Representation json `
                -PreReceipt $preReceipt `
                -Label 'Runtime source custody final receipt'
            if ($preReceipt.input_count -isnot [int32] -or $preReceipt.input_count -ne 5 -or
                $finalReceipt.input_count -isnot [int32] -or $finalReceipt.input_count -ne 5 -or
                $finalReceipt.custody_complete -isnot [bool] -or -not $finalReceipt.custody_complete) {
                throw 'Runtime source custody receipts do not bind the exact held inventory.'
            }
            foreach ($receiptSpec in @(
                [pscustomobject]@{ phase = 'pre'; receipt = $preReceipt; fields = @('schema_version','check_id','expected_head','expected_tree','file_share','input_count','inputs') },
                [pscustomobject]@{ phase = 'final'; receipt = $finalReceipt; fields = @('schema_version','check_id','expected_head','expected_tree','pre_receipt','pre_receipt_sha256','file_share','input_count','inputs','custody_complete') }
            )) {
                foreach ($field in $receiptSpec.fields) {
                    foreach ($variant in @('missing','null','object','array','nested-array','wrong-scalar')) {
                        $runtimeHostileCaseCount++
                        $copy = $receiptSpec.receipt | ConvertTo-Json -Depth 30 -Compress | ConvertFrom-Json
                        switch ($variant) {
                            'missing' { $copy.PSObject.Properties.Remove($field) }
                            'null' { $copy.$field = $null }
                            'object' { $copy.$field = [pscustomobject]@{} }
                            'array' {
                                if ($field -ceq 'inputs') {
                                    $copy.$field = [object[]]@('not-a-custody-row')
                                }
                                else {
                                    $scalarValue = $copy.$field
                                    $copy.$field = [object[]]@(,$scalarValue)
                                }
                            }
                            'nested-array' { $copy.$field = [object[]]@(,([object[]]@($copy.$field))) }
                            'wrong-scalar' {
                                $copy.$field = if ($field -cin @('schema_version','input_count')) { '1' }
                                    elseif ($field -ceq 'custody_complete') { 'true' }
                                    elseif ($field -ceq 'inputs') { 'inputs' }
                                    else { [int32]1 }
                            }
                        }
                        $action = if ($receiptSpec.phase -ceq 'pre') {
                            { Assert-SourceCustodyReceiptSchema -Receipt $copy -Phase pre -Representation json -Label "hostile pre receipt $field $variant" }
                        }
                        else {
                            { Assert-SourceCustodyReceiptSchema -Receipt $copy -Phase final -Representation json -PreReceipt $preReceipt -Label "hostile final receipt $field $variant" }
                        }
                        if (-not (Test-Throws $action)) {
                            Add-Failure -Message "Source custody $($receiptSpec.phase) receipt accepted $variant field '$field'."
                        }
                    }
                }
                foreach ($rootFixture in @(
                    [pscustomobject]@{ name = 'null'; value = $null },
                    [pscustomobject]@{ name = 'ordered-object'; value = [ordered]@{} },
                    [pscustomobject]@{ name = 'scalar'; value = 'receipt-scalar' },
                    [pscustomobject]@{ name = 'array'; value = [object[]]@(,$receiptSpec.receipt) },
                    [pscustomobject]@{ name = 'nested-array'; value = [object[]]@(,([object[]]@($receiptSpec.receipt))) }
                )) {
                    $runtimeHostileCaseCount++
                    $action = if ($receiptSpec.phase -ceq 'pre') {
                        { Assert-SourceCustodyReceiptSchema -Receipt $rootFixture.value -Phase pre -Representation json -Label "hostile pre receipt root $($rootFixture.name)" }
                    }
                    else {
                        { Assert-SourceCustodyReceiptSchema -Receipt $rootFixture.value -Phase final -Representation json -PreReceipt $preReceipt -Label "hostile final receipt root $($rootFixture.name)" }
                    }
                    if (-not (Test-Throws $action)) {
                        Add-Failure -Message "Source custody $($receiptSpec.phase) receipt accepted hostile root '$($rootFixture.name)'."
                    }
                }
                foreach ($numericField in @('schema_version','input_count')) {
                    $originalNumericValue = Get-ExactValueNoEnumerate $receiptSpec.receipt @($numericField) $null
                    foreach ($typedValue in @(
                        [pscustomobject]@{ name = 'Int64'; value = [int64]$originalNumericValue },
                        [pscustomobject]@{ name = 'Double'; value = [double]$originalNumericValue },
                        [pscustomobject]@{ name = 'Decimal'; value = [decimal]$originalNumericValue },
                        [pscustomobject]@{ name = 'UInt32'; value = [uint32]$originalNumericValue }
                    )) {
                        $runtimeHostileCaseCount++
                        $copy = ConvertTo-ContractClone -InputObject $receiptSpec.receipt
                        $copy.$numericField = $typedValue.value
                        $action = if ($receiptSpec.phase -ceq 'pre') {
                            { Assert-SourceCustodyReceiptSchema -Receipt $copy -Phase pre -Representation json -Label "hostile pre receipt $numericField $($typedValue.name)" }
                        }
                        else {
                            { Assert-SourceCustodyReceiptSchema -Receipt $copy -Phase final -Representation json -PreReceipt $preReceipt -Label "hostile final receipt $numericField $($typedValue.name)" }
                        }
                        if (-not (Test-Throws $action)) {
                            Add-Failure -Message "Source custody $($receiptSpec.phase) receipt accepted $($typedValue.name) '$numericField'."
                        }
                    }
                }
            }
            foreach ($rowSpec in @(
                [pscustomobject]@{ phase = 'pre'; row = $preReceipt.inputs[0]; fields = @('id','scope','repository_path','absolute_path','expected_git_mode','expected_git_blob','byte_length','raw_git_blob','pre_sha256') },
                [pscustomobject]@{ phase = 'final'; row = $finalReceipt.inputs[0]; fields = @('id','scope','repository_path','absolute_path','expected_git_mode','expected_git_blob','byte_length','raw_git_blob','pre_sha256','post_sha256','stable') }
            )) {
                foreach ($field in $rowSpec.fields) {
                    foreach ($variant in @('missing','null','object','array','nested-array','wrong-scalar')) {
                        $runtimeHostileCaseCount++
                        $copy = $rowSpec.row | ConvertTo-Json -Depth 20 -Compress | ConvertFrom-Json
                        switch ($variant) {
                            'missing' { $copy.PSObject.Properties.Remove($field) }
                            'null' { $copy.$field = $null }
                            'object' { $copy.$field = [pscustomobject]@{} }
                            'array' { $copy.$field = [object[]]@($copy.$field) }
                            'nested-array' { $copy.$field = [object[]]@(,([object[]]@($copy.$field))) }
                            'wrong-scalar' {
                                $copy.$field = if ($field -ceq 'byte_length') { '1' }
                                    elseif ($field -ceq 'stable') { 'true' }
                                    else { [int32]1 }
                            }
                        }
                        if (-not (Test-Throws {
                            Assert-SourceCustodyRowSchema -Row $copy -Phase $rowSpec.phase -Representation json -Label "hostile $($rowSpec.phase) row $field $variant"
                        })) {
                            Add-Failure -Message "Source custody $($rowSpec.phase) row accepted $variant field '$field'."
                        }
                    }
                }
                foreach ($rootFixture in @(
                    [pscustomobject]@{ name = 'null'; value = $null },
                    [pscustomobject]@{ name = 'ordered-object'; value = [ordered]@{} },
                    [pscustomobject]@{ name = 'scalar'; value = 'custody-row' },
                    [pscustomobject]@{ name = 'array'; value = [object[]]@(,$rowSpec.row) },
                    [pscustomobject]@{ name = 'nested-array'; value = [object[]]@(,([object[]]@($rowSpec.row))) }
                )) {
                    $runtimeHostileCaseCount++
                    if (-not (Test-Throws {
                        Assert-SourceCustodyRowSchema -Row $rootFixture.value -Phase $rowSpec.phase -Representation json -Label "hostile $($rowSpec.phase) row root $($rootFixture.name)"
                    })) {
                        Add-Failure -Message "Source custody $($rowSpec.phase) row accepted hostile root '$($rootFixture.name)'."
                    }
                }
                foreach ($mutation in @('extra','reordered')) {
                    $runtimeHostileCaseCount++
                    $copy = ConvertTo-ContractClone -InputObject $rowSpec.row
                    if ($mutation -ceq 'extra') {
                        $copy | Add-Member -NotePropertyName authority -NotePropertyValue 'hostile'
                    }
                    else {
                        $copy = New-ReorderedContractObject -InputObject $copy
                    }
                    if (-not (Test-Throws {
                        Assert-SourceCustodyRowSchema -Row $copy -Phase $rowSpec.phase -Representation json -Label "hostile $($rowSpec.phase) row $mutation"
                    })) {
                        Add-Failure -Message "Source custody $($rowSpec.phase) row accepted $mutation keys."
                    }
                }
            }

            foreach ($externalId in @('godot:console','godot:runtime','powershell:host')) {
                $preExternalRows = @($preReceipt.inputs | Where-Object { $_.id -is [string] -and $_.id -ceq $externalId })
                $finalExternalRows = @($finalReceipt.inputs | Where-Object { $_.id -is [string] -and $_.id -ceq $externalId })
                if ($preExternalRows.Count -ne 1 -or $finalExternalRows.Count -ne 1) {
                    throw "Runtime custody receipt does not contain one exact external row '$externalId'."
                }
                foreach ($externalSpec in @(
                    [pscustomobject]@{ phase = 'pre'; row = $preExternalRows[0] },
                    [pscustomobject]@{ phase = 'final'; row = $finalExternalRows[0] }
                )) {
                    Assert-SourceCustodyRowSchema -Row $externalSpec.row -Phase $externalSpec.phase -Representation json -Label "valid $externalId $($externalSpec.phase) row"
                    $runtimeValidCaseCount++
                    foreach ($mutation in @(
                        'foreign-id','wrong-scope','repository-path','expected-mode','expected-blob','wrong-absolute-path'
                    )) {
                        $runtimeHostileCaseCount++
                        $copy = ConvertTo-ContractClone -InputObject $externalSpec.row
                        switch ($mutation) {
                            'foreign-id' { $copy.id = 'external:foreign' }
                            'wrong-scope' { $copy.scope = 'repository_tracked_production_tree' }
                            'repository-path' { $copy.repository_path = 'tools/hostile.exe' }
                            'expected-mode' { $copy.expected_git_mode = '100644' }
                            'expected-blob' { $copy.expected_git_blob = 'f' * 40 }
                            'wrong-absolute-path' { $copy.absolute_path = [IO.Path]::GetFullPath((Join-Path $fixtureRoot 'hostile-external.exe')) }
                        }
                        if (-not (Test-Throws {
                            Assert-SourceCustodyRowSchema -Row $copy -Phase $externalSpec.phase -Representation json -Label "hostile $externalId $mutation"
                        })) {
                            Add-Failure -Message "Source custody external row '$externalId' accepted '$mutation'."
                        }
                    }
                }
            }

            $memoryRow = $script:SourceCustodyRows[0]
            Assert-SourceCustodyRowSchema -Row $memoryRow -Phase pre -Representation in_memory -Label 'valid in-memory custody row'
            $runtimeValidCaseCount++
            $memoryLength = Get-ExactValueNoEnumerate $memoryRow @('byte_length') $null
            foreach ($hostileLength in @(
                [pscustomobject]@{ name = 'int32'; value = [int32]$memoryLength },
                [pscustomobject]@{ name = 'double'; value = [double]$memoryLength },
                [pscustomobject]@{ name = 'decimal'; value = [decimal]$memoryLength },
                [pscustomobject]@{ name = 'uint32'; value = [uint32]$memoryLength },
                [pscustomobject]@{ name = 'string'; value = [string]$memoryLength },
                [pscustomobject]@{ name = 'negative-int64'; value = [int64]-1 },
                [pscustomobject]@{ name = 'object'; value = [pscustomobject]@{ value = $memoryLength } },
                [pscustomobject]@{ name = 'array'; value = [object[]]@(,$memoryLength) }
            )) {
                $runtimeHostileCaseCount++
                $memoryCopy = [pscustomobject][ordered]@{
                    id = $memoryRow.id
                    scope = $memoryRow.scope
                    repository_path = $memoryRow.repository_path
                    absolute_path = $memoryRow.absolute_path
                    expected_git_mode = $memoryRow.expected_git_mode
                    expected_git_blob = $memoryRow.expected_git_blob
                    byte_length = $hostileLength.value
                    raw_git_blob = $memoryRow.raw_git_blob
                    pre_sha256 = $memoryRow.pre_sha256
                }
                if (-not (Test-Throws {
                    Assert-SourceCustodyRowSchema -Row $memoryCopy -Phase pre -Representation in_memory -Label "hostile in-memory byte_length $($hostileLength.name)"
                })) {
                    Add-Failure -Message "Source custody in-memory row accepted $($hostileLength.name) byte_length."
                }
            }

            foreach ($rowSpec in @(
                [pscustomobject]@{ phase = 'pre'; row = $preReceipt.inputs[0] },
                [pscustomobject]@{ phase = 'final'; row = $finalReceipt.inputs[0] }
            )) {
                $jsonLength = Get-ExactValueNoEnumerate $rowSpec.row @('byte_length') $null
                foreach ($hostileLength in @(
                    [pscustomobject]@{ name = 'double'; value = [double]$jsonLength },
                    [pscustomobject]@{ name = 'decimal'; value = [decimal]$jsonLength },
                    [pscustomobject]@{ name = 'uint32'; value = [uint32]$jsonLength },
                    [pscustomobject]@{ name = 'string'; value = [string]$jsonLength },
                    [pscustomobject]@{ name = 'negative-int32'; value = [int32]-1 }
                )) {
                    $runtimeHostileCaseCount++
                    $copy = ConvertTo-ContractClone -InputObject $rowSpec.row
                    $copy.byte_length = $hostileLength.value
                    if (-not (Test-Throws {
                        Assert-SourceCustodyRowSchema -Row $copy -Phase $rowSpec.phase -Representation json -Label "hostile JSON byte_length $($hostileLength.name)"
                    })) {
                        Add-Failure -Message "Source custody JSON $($rowSpec.phase) row accepted $($hostileLength.name) byte_length."
                    }
                }
            }

            foreach ($uppercaseSpec in @(
                [pscustomobject]@{ phase = 'pre'; field = 'expected_git_blob'; fields = @('expected_git_blob'); value = 'A' * 40 },
                [pscustomobject]@{ phase = 'pre'; field = 'raw_git_blob'; fields = @('raw_git_blob'); value = 'A' * 40 },
                [pscustomobject]@{ phase = 'pre'; field = 'pre_sha256'; fields = @('pre_sha256'); value = 'A' * 64 },
                [pscustomobject]@{ phase = 'final'; field = 'expected_git_blob'; fields = @('expected_git_blob'); value = 'A' * 40 },
                [pscustomobject]@{ phase = 'final'; field = 'raw_git_blob'; fields = @('raw_git_blob'); value = 'A' * 40 },
                [pscustomobject]@{ phase = 'final'; field = 'pre_sha256'; fields = @('pre_sha256','post_sha256'); value = 'A' * 64 },
                [pscustomobject]@{ phase = 'final'; field = 'post_sha256'; fields = @('pre_sha256','post_sha256'); value = 'A' * 64 }
            )) {
                $runtimeHostileCaseCount++
                $row = if ($uppercaseSpec.phase -ceq 'pre') { $preReceipt.inputs[0] } else { $finalReceipt.inputs[0] }
                $copy = ConvertTo-ContractClone -InputObject $row
                foreach ($field in $uppercaseSpec.fields) { $copy.$field = $uppercaseSpec.value }
                if (-not (Test-Throws {
                    Assert-SourceCustodyRowSchema -Row $copy -Phase $uppercaseSpec.phase -Representation json -Label "hostile uppercase $($uppercaseSpec.field)"
                })) {
                    Add-Failure -Message "Source custody $($uppercaseSpec.phase) row accepted uppercase '$($uppercaseSpec.field)'."
                }
            }

            foreach ($uppercaseSpec in @(
                [pscustomobject]@{ phase = 'pre'; field = 'expected_head' },
                [pscustomobject]@{ phase = 'pre'; field = 'expected_tree' },
                [pscustomobject]@{ phase = 'final'; field = 'expected_head' },
                [pscustomobject]@{ phase = 'final'; field = 'expected_tree' },
                [pscustomobject]@{ phase = 'final'; field = 'pre_receipt_sha256' }
            )) {
                $runtimeHostileCaseCount++
                $copy = ConvertTo-ContractClone -InputObject $(if ($uppercaseSpec.phase -ceq 'pre') { $preReceipt } else { $finalReceipt })
                $copy.($uppercaseSpec.field) = if ($uppercaseSpec.field -ceq 'pre_receipt_sha256') { 'A' * 64 } else { 'A' * 40 }
                $action = if ($uppercaseSpec.phase -ceq 'pre') {
                    { Assert-SourceCustodyReceiptSchema -Receipt $copy -Phase pre -Representation json -Label "hostile uppercase receipt $($uppercaseSpec.field)" }
                }
                else {
                    { Assert-SourceCustodyReceiptSchema -Receipt $copy -Phase final -Representation json -PreReceipt $preReceipt -Label "hostile uppercase receipt $($uppercaseSpec.field)" }
                }
                if (-not (Test-Throws $action)) {
                    Add-Failure -Message "Source custody $($uppercaseSpec.phase) receipt accepted uppercase '$($uppercaseSpec.field)'."
                }
            }
            foreach ($mutation in @('pre-extra','final-extra','pre-duplicate','final-duplicate','pre-reordered','final-reordered','pre-count','final-count','raw-blob-mismatch')) {
                $runtimeHostileCaseCount++
                $preCopy = $preReceipt | ConvertTo-Json -Depth 30 -Compress | ConvertFrom-Json
                $finalCopy = $finalReceipt | ConvertTo-Json -Depth 30 -Compress | ConvertFrom-Json
                switch ($mutation) {
                    'pre-extra' { $preCopy | Add-Member -NotePropertyName authority -NotePropertyValue 'hostile' }
                    'final-extra' { $finalCopy | Add-Member -NotePropertyName authority -NotePropertyValue 'hostile' }
                    'pre-duplicate' { $preCopy.inputs[1] = $preCopy.inputs[0] }
                    'final-duplicate' { $finalCopy.inputs[1] = $finalCopy.inputs[0] }
                    'pre-reordered' { $preCopy.inputs = [object[]]@($preCopy.inputs[1],$preCopy.inputs[0],$preCopy.inputs[2],$preCopy.inputs[3],$preCopy.inputs[4]) }
                    'final-reordered' { $finalCopy.inputs = [object[]]@($finalCopy.inputs[1],$finalCopy.inputs[0],$finalCopy.inputs[2],$finalCopy.inputs[3],$finalCopy.inputs[4]) }
                    'pre-count' { $preCopy.input_count = [int32]4 }
                    'final-count' { $finalCopy.input_count = [int32]4 }
                    'raw-blob-mismatch' { $preCopy.inputs[0].raw_git_blob = 'f' * 40 }
                }
                if (-not (Test-Throws {
                    Assert-SourceCustodyReceiptSchema -Receipt $preCopy -Phase pre -Representation json -Label "hostile pre receipt $mutation"
                    Assert-SourceCustodyReceiptSchema -Receipt $finalCopy -Phase final -Representation json -PreReceipt $preCopy -Label "hostile final receipt $mutation"
                })) {
                    Add-Failure -Message "Source custody receipt accepted hostile mutation '$mutation'."
                }
            }
            foreach ($receiptPath in @($SourceCustodyPrePath, $SourceCustodyFinalPath)) {
                foreach ($fixture in @(
                    [pscustomobject]@{ name = 'overwrite'; action = {
                        [IO.File]::WriteAllText($receiptPath, 'hostile receipt overwrite')
                    } },
                    [pscustomobject]@{ name = 'atomic replacement'; action = {
                        $replacementPath = $receiptPath + '.replacement'
                        $backupPath = $receiptPath + '.backup'
                        [IO.File]::WriteAllText($replacementPath, 'hostile receipt replacement')
                        [IO.File]::Replace($replacementPath, $receiptPath, $backupPath)
                    } },
                    [pscustomobject]@{ name = 'move-away'; action = {
                        [IO.File]::Move($receiptPath, ($receiptPath + '.moved'))
                    } }
                )) {
                    $runtimeHostileCaseCount++
                    if (-not (Test-Throws $fixture.action)) {
                        Add-Failure -Message "Held source receipt allowed $($fixture.name): $receiptPath"
                    }
                }
            }
            $runtimeValidCaseCount++
        }
        finally { Close-SourceCustody }

        & git -C $Worktree update-index --assume-unchanged -- source.txt
        [IO.File]::WriteAllText($fixtureSourcePath, "stable`r`nsource`r`n", [Text.UTF8Encoding]::new($false))
        $expectedFilteredBlob = (& git -C $Worktree rev-parse 'HEAD:source.txt').Trim().ToLowerInvariant()
        $actualFilteredBlob = (& git -C $Worktree hash-object -- source.txt).Trim().ToLowerInvariant()
        $actualRawBlob = (& git -C $Worktree hash-object --no-filters -- source.txt).Trim().ToLowerInvariant()
        if ($LASTEXITCODE -ne 0 -or $actualFilteredBlob -cne $expectedFilteredBlob -or
            $actualRawBlob -ceq $expectedFilteredBlob) {
            throw 'Could not construct the exact filtered-match/raw-mismatch custody hostile.'
        }
        $EvidenceRoot = Join-Path $fixtureRoot 'hostile-source-custody'
        New-Item -ItemType Directory -Path $EvidenceRoot -Force | Out-Null
        $SourceCustodyPrePath = Join-Path $EvidenceRoot 'source_custody_pre.json'
        $SourceCustodyFinalPath = Join-Path $EvidenceRoot 'source_custody_final.json'
        $script:SourceCustodyStreams = [Collections.Generic.List[IO.FileStream]]::new()
        $script:SourceCustodyRows = [Collections.Generic.List[object]]::new()
        $script:SourceCustodyPreStream = $null
        $script:SourceCustodyFinalStream = $null
        $script:EvidenceArtifactStreams = [Collections.Generic.List[IO.FileStream]]::new()
        $script:SourceCustodyPreSha256 = ''
        $script:SourceCustodyFinalSha256 = ''
        $script:SourceCustodyComplete = $false
        $runtimeHostileCaseCount++
        if (-not (Test-Throws { New-SourceCustody })) {
            Add-Failure -Message 'Immutable HEAD blob custody accepted assume-unchanged hostile bytes.'
        }
        Close-SourceCustody
        & git -C $Worktree update-index --no-assume-unchanged -- source.txt
        $Worktree = $originalWorktree
        $ExpectedHead = $originalExpectedHead
        $ExpectedTree = $originalExpectedTree

        $custodyPath = Join-Path $fixtureRoot 'custody.txt'
        [IO.File]::WriteAllText($custodyPath, 'stable', [Text.UTF8Encoding]::new($false))
        $handle = Open-SourceCustodyHandle -Path $custodyPath
        try {
            if (-not $handle.CanRead) { throw 'Custody handle is not readable.' }
        }
        finally { $handle.Dispose() }
        $runtimeValidCaseCount++

        $writer = [IO.File]::Open($custodyPath, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::ReadWrite)
        try {
            $runtimeHostileCaseCount++
            if (-not (Test-Throws { $candidate = Open-SourceCustodyHandle -Path $custodyPath; $candidate.Dispose() })) {
                Add-Failure -Message 'Source custody acquisition accepted a pre-existing writable handle.'
            }
        }
        finally { $writer.Dispose() }

        $handle = Open-SourceCustodyHandle -Path $custodyPath
        try {
            $runtimeHostileCaseCount++
            if (-not (Test-Throws { [IO.File]::WriteAllText($custodyPath, 'hostile') })) {
                Add-Failure -Message 'Source custody allowed overwrite while held.'
            }
            $replacement = Join-Path $fixtureRoot 'replacement.txt'
            $backup = Join-Path $fixtureRoot 'backup.txt'
            [IO.File]::WriteAllText($replacement, 'replacement')
            $runtimeHostileCaseCount++
            if (-not (Test-Throws { [IO.File]::Replace($replacement, $custodyPath, $backup) })) {
                Add-Failure -Message 'Source custody allowed atomic replacement while held.'
            }
            $moved = Join-Path $fixtureRoot 'moved.txt'
            $runtimeHostileCaseCount++
            if (-not (Test-Throws { [IO.File]::Move($custodyPath, $moved) })) {
                Add-Failure -Message 'Source custody allowed move-away while held.'
            }
        }
        finally { $handle.Dispose() }

        $preflightRoot = Join-Path $fixtureRoot 'preflight-valid'
        New-Item -ItemType Directory -Path $preflightRoot -Force | Out-Null
        $preflightPath = Join-Path $preflightRoot 'heist_seed_preflight.json'
        $preflight = [pscustomobject][ordered]@{
            passed = $true
            selection = [pscustomobject][ordered]@{
                seed_text = 'RW06-HEIST-AUDIT-0002'
                selected_scenario = 'grand_casino_audit_night'
            }
        }
        $preflight | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $preflightPath -Encoding utf8
        $preflightProof = Assert-RetainedHeistPreflightArtifact -RunIndex 1 -InvocationRoot $preflightRoot `
            -InvocationPreflight $preflight -RunPreflight $preflight
        $runtimeValidCaseCount++
        foreach ($fixture in @(
            [pscustomobject]@{ name = 'overwrite'; action = {
                [IO.File]::WriteAllText($preflightPath, 'hostile overwrite')
            } },
            [pscustomobject]@{ name = 'atomic replacement'; action = {
                $replacementPath = Join-Path $preflightRoot 'preflight-replacement.json'
                $backupPath = Join-Path $preflightRoot 'preflight-backup.json'
                [IO.File]::WriteAllText($replacementPath, 'hostile replacement')
                [IO.File]::Replace($replacementPath, $preflightPath, $backupPath)
            } },
            [pscustomobject]@{ name = 'move-away'; action = {
                [IO.File]::Move($preflightPath, (Join-Path $preflightRoot 'preflight-moved.json'))
            } }
        )) {
            $runtimeHostileCaseCount++
            if (-not (Test-Throws $fixture.action)) {
                Add-Failure -Message "Retained preflight custody allowed $($fixture.name) while held."
            }
        }
        $manifestRows = [object[]]@([ordered]@{ path = $preflightProof.path; sha256 = $preflightProof.sha256 })
        Assert-ManifestArtifactHash -ArtifactRows $manifestRows -Path $preflightProof.path `
            -ExpectedSha256 $preflightProof.sha256 -Label 'retained preflight manifest fixture'
        $runtimeValidCaseCount++
        $runtimeHostileCaseCount++
        if (-not (Test-Throws {
            Assert-ManifestArtifactHash -ArtifactRows ([object[]]@()) -Path $preflightProof.path `
                -ExpectedSha256 $preflightProof.sha256 -Label 'missing retained preflight manifest fixture'
        })) { Add-Failure -Message 'Manifest hash validator accepted a missing retained preflight row.' }
        $runtimeHostileCaseCount++
        if (-not (Test-Throws {
            Assert-ManifestArtifactHash -ArtifactRows $manifestRows -Path $preflightProof.path `
                -ExpectedSha256 ('f' * 64) -Label 'mismatched retained preflight manifest fixture'
        })) { Add-Failure -Message 'Manifest hash validator accepted a mismatched retained preflight hash.' }
        $artifactBindingRows = [object[]]@(
            [pscustomobject][ordered]@{ path = [IO.Path]::GetFullPath((Join-Path $fixtureRoot 'aggregate_summary.json')); sha256 = '1' * 64 },
            [pscustomobject][ordered]@{ path = [IO.Path]::GetFullPath((Join-Path $fixtureRoot 'run_metadata.json')); sha256 = '2' * 64 },
            [pscustomobject][ordered]@{ path = [IO.Path]::GetFullPath((Join-Path $fixtureRoot 'launcher.stdout.txt')); sha256 = '3' * 64 },
            [pscustomobject][ordered]@{ path = [IO.Path]::GetFullPath((Join-Path $fixtureRoot 'launcher.stderr.txt')); sha256 = '4' * 64 },
            [pscustomobject][ordered]@{ path = [IO.Path]::GetFullPath((Join-Path $fixtureRoot 'run_summary.json')); sha256 = '5' * 64 }
        )
        foreach ($artifactBinding in $artifactBindingRows) {
            Assert-ManifestArtifactHash -ArtifactRows $artifactBindingRows -Path $artifactBinding.path `
                -ExpectedSha256 $artifactBinding.sha256 -Label 'valid terminal artifact binding fixture'
            $runtimeValidCaseCount++
            $runtimeHostileCaseCount++
            $mismatchedHash = if ($artifactBinding.sha256 -cne ('f' * 64)) { 'f' * 64 } else { 'e' * 64 }
            if (-not (Test-Throws {
                Assert-ManifestArtifactHash -ArtifactRows $artifactBindingRows -Path $artifactBinding.path `
                    -ExpectedSha256 $mismatchedHash -Label 'well-formed mismatched terminal artifact binding fixture'
            })) {
                Add-Failure -Message "Manifest hash validator accepted a well-formed mismatched digest for '$($artifactBinding.path)'."
            }
        }
        Close-SourceCustody

        $missingRoot = Join-Path $fixtureRoot 'preflight-missing'
        New-Item -ItemType Directory -Path $missingRoot -Force | Out-Null
        $runtimeHostileCaseCount++
        if (-not (Test-Throws { $null = Assert-RetainedHeistPreflightArtifact -RunIndex 1 -InvocationRoot $missingRoot -InvocationPreflight $preflight -RunPreflight $preflight })) {
            Add-Failure -Message 'Retained preflight validator accepted a missing file.'
        }
        Close-SourceCustody
        foreach ($fixture in @(
            [pscustomobject]@{ name = 'empty'; text = '' },
            [pscustomobject]@{ name = 'invalid JSON'; text = '{' },
            [pscustomobject]@{ name = 'array JSON'; text = '[{"passed":true}]' }
        )) {
            Set-Content -LiteralPath $preflightPath -Value $fixture.text -Encoding utf8
            $runtimeHostileCaseCount++
            if (-not (Test-Throws { $null = Assert-RetainedHeistPreflightArtifact -RunIndex 1 -InvocationRoot $preflightRoot -InvocationPreflight $preflight -RunPreflight $preflight })) {
                Add-Failure -Message "Retained preflight validator accepted $($fixture.name)."
            }
            Close-SourceCustody
        }
        $preflight | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $preflightPath -Encoding utf8
        $mismatch = $preflight | ConvertTo-Json -Depth 8 -Compress | ConvertFrom-Json
        $mismatch.selection.selected_scenario = 'grand_casino_gala_night'
        foreach ($fixture in @(
            [pscustomobject]@{ name = 'invocation mismatch'; invocation = $mismatch; run = $preflight },
            [pscustomobject]@{ name = 'run mismatch'; invocation = $preflight; run = $mismatch }
        )) {
            $runtimeHostileCaseCount++
            if (-not (Test-Throws { $null = Assert-RetainedHeistPreflightArtifact -RunIndex 1 -InvocationRoot $preflightRoot -InvocationPreflight $fixture.invocation -RunPreflight $fixture.run })) {
                Add-Failure -Message "Retained preflight validator accepted $($fixture.name)."
            }
            Close-SourceCustody
        }
        foreach ($fixture in @(
            [pscustomobject]@{ name = 'invocation object array'; invocation = [object[]]@($preflight); run = $preflight },
            [pscustomobject]@{ name = 'run object array'; invocation = $preflight; run = [object[]]@($preflight) }
        )) {
            $preflight | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $preflightPath -Encoding utf8
            $runtimeHostileCaseCount++
            if (-not (Test-Throws { $null = Assert-RetainedHeistPreflightArtifact -RunIndex 1 -InvocationRoot $preflightRoot -InvocationPreflight $fixture.invocation -RunPreflight $fixture.run })) {
                Add-Failure -Message "Retained preflight validator accepted $($fixture.name)."
            }
            Close-SourceCustody
        }
        $arrayPreflight = $preflight | ConvertTo-Json -Depth 8 -Compress | ConvertFrom-Json
        $arrayPreflight.selection.seed_text = [object[]]@('RW06-HEIST-AUDIT-0002')
        $arrayPreflight | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $preflightPath -Encoding utf8
        $runtimeHostileCaseCount++
        if (-not (Test-Throws { $null = Assert-RetainedHeistPreflightArtifact -RunIndex 1 -InvocationRoot $preflightRoot -InvocationPreflight $arrayPreflight -RunPreflight $arrayPreflight })) {
            Add-Failure -Message 'Retained preflight validator accepted a one-element seed array.'
        }
        Close-SourceCustody
    }
    finally {
        try { Close-SourceCustody } catch {}
        if ($null -ne $originalWorktree) { $Worktree = $originalWorktree }
        if ($null -ne $originalExpectedHead) { $ExpectedHead = $originalExpectedHead }
        if ($null -ne $originalExpectedTree) { $ExpectedTree = $originalExpectedTree }
        if (Test-Path -LiteralPath $fixtureRoot) { Remove-Item -LiteralPath $fixtureRoot -Recurse -Force }
    }

    $Ending = 'heist'
    $Seed = 'RW06-HEIST-AUDIT-0002'
    $ExpectedHead = 'a' * 40
    $ExpectedTree = 'b' * 40
    $EvidenceRoot = 'C:\proof-aggregate'
    $LauncherSnapshotPath = 'C:\proof-aggregate\launcher.invoked.ps1'
    $SourceCustodyPrePath = 'C:\proof-aggregate\source_custody_pre.json'
    $SourceCustodyFinalPath = 'C:\proof-aggregate\source_custody_final.json'
    $LeasePath = 'C:\leases\EXCLUSIVE.lease'
    $script:TerminalError = $null
    $script:Outcome = 'green'
    $script:FinalHead = $ExpectedHead
    $script:FinalTree = $ExpectedTree
    $script:LauncherInitialSha256 = '8' * 64
    $script:LauncherCurrentSha256 = $script:LauncherInitialSha256
    $script:SourceCustodyPreSha256 = $commonHash
    $script:SourceCustodyFinalSha256 = '9' * 64
    $script:SourceCustodyComplete = $true
    $script:InitialProcessCensus = [object[]]@()
    $script:FinalProcessCensus = [object[]]@()
    foreach ($proof in $proofs) { $proof.source_custody_pre = $SourceCustodyPrePath }
    $canonicalProof = Compare-FixedRunProofs -Proofs $proofs
    $script:RunProofs = [Collections.Generic.List[object]]::new()
    foreach ($proof in $proofs) { $script:RunProofs.Add($proof) }
    $script:CanonicalProof = $canonicalProof
    $fixedRepeatQualifying = $true

    $terminalAggregate = [ordered]@{
        schema_version = [int32]1
        check_id = 'rw06_2_final_evidence'
        role = 'fixed_route_repeat'
        evidence_role = 'fixed-repeat'
        ending = $Ending
        seed = $Seed
        repeat = [int32]2
        outcome = $script:Outcome
        error = ''
        expected_head = $ExpectedHead
        expected_tree = $ExpectedTree
        observed_head = $script:FinalHead
        observed_tree = $script:FinalTree
        independent_profiles = $true
        fresh_interactive_authorized = $false
        q017_status = 'ANSWERED_SEPARATE_FRESH_INTERACTIVE_SCOPE'
        deterministic = $true
        fixed_repeat_qualifying = $true
        source_custody_complete = $true
        source_custody_pre_sha256 = $script:SourceCustodyPreSha256
        source_custody_final_sha256 = $script:SourceCustodyFinalSha256
        canonical_proof = $canonicalProof
        runs = [object[]]@($proofs)
        evidence_root = $EvidenceRoot
    }
    $heldCanonicalTranscript = [string]$script:CanonicalProof.transcript_sha256
    try {
        $script:CanonicalProof.transcript_sha256 = if ($heldCanonicalTranscript -cne ('f' * 64)) { 'f' * 64 } else { 'e' * 64 }
        $runtimeHostileCaseCount++
        if (-not (Test-Throws {
            Assert-TerminalAggregateShape `
                -Record $terminalAggregate `
                -Representation ordered `
                -Label 'In-memory aggregate summary'
        })) {
            Add-Failure -Message 'Terminal aggregate accepted canonical proof mutation after qualification.'
        }
    }
    finally {
        $script:CanonicalProof.transcript_sha256 = $heldCanonicalTranscript
    }
    $terminalMetadata = [ordered]@{
        lane = 'rw06_2p'
        kind = 'exclusive-real-input-fixed-repeat-final-evidence'
        ending = $Ending
        seed = $Seed
        role = 'fixed_route_repeat'
        evidence_role = 'fixed-repeat'
        outcome = $script:Outcome
        error = ''
        expected_head = $ExpectedHead
        expected_tree = $ExpectedTree
        observed_head = $script:FinalHead
        observed_tree = $script:FinalTree
        launcher_snapshot = $LauncherSnapshotPath
        launcher_initial_sha256 = $script:LauncherInitialSha256
        launcher_current_sha256 = $script:LauncherCurrentSha256
        source_custody_pre = $SourceCustodyPrePath
        source_custody_pre_sha256 = $script:SourceCustodyPreSha256
        source_custody_final = $SourceCustodyFinalPath
        source_custody_final_sha256 = $script:SourceCustodyFinalSha256
        source_custody_complete = $true
        initial_process_census = [object[]]@()
        final_process_census = [object[]]@()
        owned_processes_remaining = [object[]]@()
        lease_path = $LeasePath
        lease_removed = $true
        fixed_repeat_qualifying = $true
        started = '2026-09-24T00:00:00.0000000+00:00'
        completed = '2026-09-24T00:01:00.0000000+00:00'
    }
    $terminalArtifactRows = [object[]]@(
        [ordered]@{ path = 'C:\terminal-evidence\a.json'; sha256 = 'a' * 64 },
        [ordered]@{ path = 'C:\terminal-evidence\b.json'; sha256 = 'b' * 64 }
    )
    $terminalManifest = [ordered]@{
        schema_version = [int32]1
        check_id = 'rw06_2_final_evidence_manifest'
        role = 'fixed_route_repeat'
        evidence_role = 'fixed-repeat'
        ending = $Ending
        seed = $Seed
        fixed_repeat_qualifying = $true
        evidence_root = $EvidenceRoot
        artifact_count = [int32]$terminalArtifactRows.Count
        artifacts = $terminalArtifactRows
    }
    $terminalExpectedAggregateSha256 = 'c' * 64
    $terminalExpectedMetadataSha256 = 'd' * 64
    $terminalExpectedManifestSha256 = 'e' * 64
    $terminalResult = [ordered]@{
        evidence_root = $EvidenceRoot
        outcome = $script:Outcome
        fixed_repeat_qualifying = $true
        head = $script:FinalHead
        tree = $script:FinalTree
        aggregate_summary_sha256 = $terminalExpectedAggregateSha256
        metadata_sha256 = $terminalExpectedMetadataSha256
        manifest_sha256 = $terminalExpectedManifestSha256
        source_custody_pre_sha256 = $script:SourceCustodyPreSha256
        source_custody_final_sha256 = $script:SourceCustodyFinalSha256
    }
    $terminalFixtures = @(
        [pscustomobject]@{
            name = 'aggregate summary'; value = $terminalAggregate
            labels = @(
                [pscustomobject]@{ value = 'In-memory aggregate summary'; representation = 'ordered' },
                [pscustomobject]@{ value = 'Serialized aggregate summary'; representation = 'json' },
                [pscustomobject]@{ value = 'Retained aggregate summary'; representation = 'json' }
            )
            validator = {
                param($value, $representation, [string]$label = 'terminal aggregate fixture')
                Assert-TerminalAggregateShape -Record $value -Representation $representation -Label $label
            }
        },
        [pscustomobject]@{
            name = 'run metadata'; value = $terminalMetadata
            labels = @(
                [pscustomobject]@{ value = 'In-memory run metadata'; representation = 'ordered' },
                [pscustomobject]@{ value = 'Serialized run metadata'; representation = 'json' },
                [pscustomobject]@{ value = 'Retained run metadata'; representation = 'json' }
            )
            validator = {
                param($value, $representation, [string]$label = 'terminal metadata fixture')
                Assert-TerminalMetadataShape -Record $value -Representation $representation -Label $label
            }
        },
        [pscustomobject]@{
            name = 'artifact manifest'; value = $terminalManifest
            labels = @(
                [pscustomobject]@{ value = 'In-memory artifact manifest'; representation = 'ordered' },
                [pscustomobject]@{ value = 'Serialized artifact manifest'; representation = 'json' },
                [pscustomobject]@{ value = 'Retained artifact manifest'; representation = 'json' }
            )
            validator = {
                param($value, $representation, [string]$label = 'terminal manifest fixture')
                Assert-TerminalManifestShape -Record $value -Representation $representation -Label $label
            }
        },
        [pscustomobject]@{
            name = 'stdout result'; value = $terminalResult
            labels = @(
                [pscustomobject]@{ value = 'In-memory terminal stdout result'; representation = 'ordered' },
                [pscustomobject]@{ value = 'Terminal stdout result'; representation = 'json' }
            )
            validator = {
                param($value, $representation, [string]$label = 'terminal result fixture')
                Assert-TerminalResultShape `
                    -Record $value `
                    -Representation $representation `
                    -ExpectedAggregateSha256 $terminalExpectedAggregateSha256 `
                    -ExpectedMetadataSha256 $terminalExpectedMetadataSha256 `
                    -ExpectedManifestSha256 $terminalExpectedManifestSha256 `
                    -Label $label
            }
        }
    )
    foreach ($fixture in $terminalFixtures) {
        $jsonValue = ConvertTo-ContractClone -InputObject $fixture.value
        foreach ($productionLabel in @($fixture.labels)) {
            $productionValue = if ($productionLabel.representation -ceq 'ordered') { $fixture.value } else { $jsonValue }
            & $fixture.validator $productionValue $productionLabel.representation $productionLabel.value
            $runtimeValidCaseCount++
            $runtimeHostileCaseCount++
            if ($productionLabel.representation -ceq 'ordered') {
                $malformedProductionValue = [ordered]@{}
                foreach ($key in $fixture.value.Keys) { $malformedProductionValue[$key] = $fixture.value[$key] }
                $malformedProductionValue['authority'] = 'hostile'
            }
            else {
                $malformedProductionValue = ConvertTo-ContractClone -InputObject $jsonValue
                $malformedProductionValue | Add-Member -NotePropertyName authority -NotePropertyValue 'hostile'
            }
            if (-not (Test-Throws {
                & $fixture.validator $malformedProductionValue $productionLabel.representation $productionLabel.value
            })) {
                Add-Failure -Message "Terminal $($fixture.name) validator accepted malformed data under production label '$($productionLabel.value)'."
            }
        }
        foreach ($field in @($jsonValue.PSObject.Properties | ForEach-Object { [string]$_.Name })) {
            foreach ($variant in @('missing', 'null', 'object', 'array', 'wrong-scalar')) {
                $runtimeHostileCaseCount++
                $copy = ConvertTo-ContractClone -InputObject $fixture.value
                switch ($variant) {
                    'missing' { $copy.PSObject.Properties.Remove($field) }
                    'null' { $copy.$field = $null }
                    'object' { $copy.$field = [pscustomobject]@{ hostile = $true } }
                    'array' {
                        $prior = $copy.$field
                        $copy.$field = [object[]]@(,$prior)
                    }
                    'wrong-scalar' {
                        $prior = $copy.$field
                        $copy.$field = if ($prior -is [int32]) { '7' }
                            elseif ($prior -is [bool]) { 'true' }
                            else { [int32]7 }
                    }
                }
                if (-not (Test-Throws { & $fixture.validator $copy 'json' })) {
                    Add-Failure -Message "Terminal $($fixture.name) accepted $variant field '$field'."
                }
            }
        }
        $runtimeHostileCaseCount++
        $extra = ConvertTo-ContractClone -InputObject $fixture.value
        $extra | Add-Member -NotePropertyName authority -NotePropertyValue 'hostile'
        if (-not (Test-Throws { & $fixture.validator $extra 'json' })) {
            Add-Failure -Message "Terminal $($fixture.name) accepted an extra authority field."
        }
        $runtimeHostileCaseCount++
        $reordered = New-ReorderedContractObject -InputObject (ConvertTo-ContractClone -InputObject $fixture.value)
        if (-not (Test-Throws { & $fixture.validator $reordered 'json' })) {
            Add-Failure -Message "Terminal $($fixture.name) accepted reordered keys."
        }
        foreach ($rootFixture in @(
            [pscustomobject]@{ name = 'null'; value = $null },
            [pscustomobject]@{ name = 'ordered-object'; value = [ordered]@{} },
            [pscustomobject]@{ name = 'scalar'; value = 'terminal-scalar' },
            [pscustomobject]@{ name = 'array'; value = [object[]]@(,(ConvertTo-ContractClone -InputObject $fixture.value)) },
            [pscustomobject]@{ name = 'nested-array'; value = [object[]]@(,([object[]]@((ConvertTo-ContractClone -InputObject $fixture.value)))) }
        )) {
            $runtimeHostileCaseCount++
            if (-not (Test-Throws { & $fixture.validator $rootFixture.value 'json' })) {
                Add-Failure -Message "Terminal $($fixture.name) accepted hostile root '$($rootFixture.name)'."
            }
        }
    }
    foreach ($numericSpec in @(
        [pscustomobject]@{ name = 'aggregate schema_version'; fixture = $terminalAggregate; validator = $terminalFixtures[0].validator; field = 'schema_version' },
        [pscustomobject]@{ name = 'aggregate repeat'; fixture = $terminalAggregate; validator = $terminalFixtures[0].validator; field = 'repeat' },
        [pscustomobject]@{ name = 'manifest schema_version'; fixture = $terminalManifest; validator = $terminalFixtures[2].validator; field = 'schema_version' },
        [pscustomobject]@{ name = 'manifest artifact_count'; fixture = $terminalManifest; validator = $terminalFixtures[2].validator; field = 'artifact_count' }
    )) {
        $originalNumericValue = Get-ExactValueNoEnumerate $numericSpec.fixture @($numericSpec.field) $null
        foreach ($typedValue in @(
            [pscustomobject]@{ name = 'Int64'; value = [int64]$originalNumericValue },
            [pscustomobject]@{ name = 'Double'; value = [double]$originalNumericValue },
            [pscustomobject]@{ name = 'Decimal'; value = [decimal]$originalNumericValue },
            [pscustomobject]@{ name = 'UInt32'; value = [uint32]$originalNumericValue }
        )) {
            $runtimeHostileCaseCount++
            $copy = ConvertTo-ContractClone -InputObject $numericSpec.fixture
            $copy.($numericSpec.field) = $typedValue.value
            if (-not (Test-Throws { & $numericSpec.validator $copy 'json' })) {
                Add-Failure -Message "Terminal $($numericSpec.name) accepted $($typedValue.name) width."
            }
        }
    }

    foreach ($mutation in @('empty','single','scalar','object','nested','wrong-element','swapped','duplicate','extra')) {
        $runtimeHostileCaseCount++
        $copy = ConvertTo-ContractClone -InputObject $terminalAggregate
        switch ($mutation) {
            'empty' { $copy.runs = [object[]]@() }
            'single' { $copy.runs = [object[]]@($copy.runs[0]) }
            'scalar' { $copy.runs = 'run-scalar' }
            'object' { $copy.runs = [pscustomobject]@{ hostile = $true } }
            'nested' { $copy.runs = [object[]]@(,([object[]]@($copy.runs))) }
            'wrong-element' { $copy.runs = [object[]]@('not-a-proof', $copy.runs[1]) }
            'swapped' { $copy.runs = [object[]]@($copy.runs[1], $copy.runs[0]) }
            'duplicate' { $copy.runs = [object[]]@($copy.runs[0], $copy.runs[0]) }
            'extra' { $copy.runs = [object[]]@($copy.runs[0], $copy.runs[1], $copy.runs[0]) }
        }
        if (-not (Test-Throws { Assert-TerminalAggregateShape -Record $copy -Representation json -Label "hostile aggregate runs $mutation" })) {
            Add-Failure -Message "Terminal aggregate accepted hostile runs array '$mutation'."
        }
    }

    foreach ($arrayField in @('initial_process_census','final_process_census','owned_processes_remaining')) {
        foreach ($mutation in @('scalar','object','nested','wrong-element','nonempty-valid')) {
            $runtimeHostileCaseCount++
            $copy = ConvertTo-ContractClone -InputObject $terminalMetadata
            $validRow = if ($arrayField -ceq 'owned_processes_remaining') {
                [pscustomobject]@{ kind = 'replay'; pid = [int32]101; session_prefix = '--session=rw062-heist-101-' }
            }
            else {
                [pscustomobject]@{ pid = [int32]101; parent_pid = [int32]100; name = 'Godot.exe'; command_line = '--path C:\terminal-evidence' }
            }
            switch ($mutation) {
                'scalar' { $copy.$arrayField = 'census-scalar' }
                'object' { $copy.$arrayField = [pscustomobject]@{ hostile = $true } }
                'nested' { $copy.$arrayField = [object[]]@(,([object[]]@($validRow))) }
                'wrong-element' { $copy.$arrayField = [object[]]@('not-a-row') }
                'nonempty-valid' { $copy.$arrayField = [object[]]@($validRow) }
            }
            if (-not (Test-Throws { Assert-TerminalMetadataShape -Record $copy -Representation json -Label "hostile metadata $arrayField $mutation" })) {
                Add-Failure -Message "Terminal metadata accepted hostile $arrayField array '$mutation'."
            }
        }
    }

    foreach ($mutation in @(
        'empty','scalar','object','nested','wrong-element','duplicate','case-duplicate',
        'reordered','extra','count-mismatch','count-int64'
    )) {
        $runtimeHostileCaseCount++
        $copy = ConvertTo-ContractClone -InputObject $terminalManifest
        switch ($mutation) {
            'empty' { $copy.artifacts = [object[]]@(); $copy.artifact_count = [int32]0 }
            'scalar' { $copy.artifacts = 'artifact-scalar' }
            'object' { $copy.artifacts = [pscustomobject]@{ hostile = $true } }
            'nested' { $copy.artifacts = [object[]]@(,([object[]]@($copy.artifacts))) ; $copy.artifact_count = [int32]1 }
            'wrong-element' { $copy.artifacts = [object[]]@('not-an-artifact'); $copy.artifact_count = [int32]1 }
            'duplicate' { $copy.artifacts = [object[]]@($copy.artifacts[0], $copy.artifacts[0]) }
            'case-duplicate' { $copy.artifacts[1].path = 'C:\terminal-evidence\A.json' }
            'reordered' { $copy.artifacts = [object[]]@($copy.artifacts[1], $copy.artifacts[0]) }
            'extra' { $copy.artifacts = [object[]]@($copy.artifacts[0], $copy.artifacts[1], $copy.artifacts[1]); $copy.artifact_count = [int32]3 }
            'count-mismatch' { $copy.artifact_count = [int32]1 }
            'count-int64' { $copy.artifact_count = [int64]2 }
        }
        if (-not (Test-Throws { Assert-TerminalManifestShape -Record $copy -Representation json -Label "hostile manifest artifacts $mutation" })) {
            Add-Failure -Message "Terminal manifest accepted hostile artifacts array '$mutation'."
        }
    }

    foreach ($uppercaseFixture in @(
        [pscustomobject]@{ name = 'aggregate expected_head'; fixture = $terminalAggregate; validator = $terminalFixtures[0].validator; field = 'expected_head'; value = 'A' * 40 },
        [pscustomobject]@{ name = 'aggregate expected_tree'; fixture = $terminalAggregate; validator = $terminalFixtures[0].validator; field = 'expected_tree'; value = 'A' * 40 },
        [pscustomobject]@{ name = 'aggregate observed_head'; fixture = $terminalAggregate; validator = $terminalFixtures[0].validator; field = 'observed_head'; value = 'A' * 40 },
        [pscustomobject]@{ name = 'aggregate observed_tree'; fixture = $terminalAggregate; validator = $terminalFixtures[0].validator; field = 'observed_tree'; value = 'A' * 40 },
        [pscustomobject]@{ name = 'aggregate pre hash'; fixture = $terminalAggregate; validator = $terminalFixtures[0].validator; field = 'source_custody_pre_sha256'; value = 'A' * 64 },
        [pscustomobject]@{ name = 'aggregate final hash'; fixture = $terminalAggregate; validator = $terminalFixtures[0].validator; field = 'source_custody_final_sha256'; value = 'A' * 64 },
        [pscustomobject]@{ name = 'metadata expected_head'; fixture = $terminalMetadata; validator = $terminalFixtures[1].validator; field = 'expected_head'; value = 'A' * 40 },
        [pscustomobject]@{ name = 'metadata expected_tree'; fixture = $terminalMetadata; validator = $terminalFixtures[1].validator; field = 'expected_tree'; value = 'A' * 40 },
        [pscustomobject]@{ name = 'metadata observed_head'; fixture = $terminalMetadata; validator = $terminalFixtures[1].validator; field = 'observed_head'; value = 'A' * 40 },
        [pscustomobject]@{ name = 'metadata observed_tree'; fixture = $terminalMetadata; validator = $terminalFixtures[1].validator; field = 'observed_tree'; value = 'A' * 40 },
        [pscustomobject]@{ name = 'metadata launcher initial'; fixture = $terminalMetadata; validator = $terminalFixtures[1].validator; field = 'launcher_initial_sha256'; value = 'A' * 64 },
        [pscustomobject]@{ name = 'metadata launcher current'; fixture = $terminalMetadata; validator = $terminalFixtures[1].validator; field = 'launcher_current_sha256'; value = 'A' * 64 },
        [pscustomobject]@{ name = 'metadata pre hash'; fixture = $terminalMetadata; validator = $terminalFixtures[1].validator; field = 'source_custody_pre_sha256'; value = 'A' * 64 },
        [pscustomobject]@{ name = 'metadata final hash'; fixture = $terminalMetadata; validator = $terminalFixtures[1].validator; field = 'source_custody_final_sha256'; value = 'A' * 64 },
        [pscustomobject]@{ name = 'result head'; fixture = $terminalResult; validator = $terminalFixtures[3].validator; field = 'head'; value = 'A' * 40 },
        [pscustomobject]@{ name = 'result tree'; fixture = $terminalResult; validator = $terminalFixtures[3].validator; field = 'tree'; value = 'A' * 40 },
        [pscustomobject]@{ name = 'result aggregate hash'; fixture = $terminalResult; validator = $terminalFixtures[3].validator; field = 'aggregate_summary_sha256'; value = 'A' * 64 },
        [pscustomobject]@{ name = 'result metadata hash'; fixture = $terminalResult; validator = $terminalFixtures[3].validator; field = 'metadata_sha256'; value = 'A' * 64 },
        [pscustomobject]@{ name = 'result manifest hash'; fixture = $terminalResult; validator = $terminalFixtures[3].validator; field = 'manifest_sha256'; value = 'A' * 64 },
        [pscustomobject]@{ name = 'result pre hash'; fixture = $terminalResult; validator = $terminalFixtures[3].validator; field = 'source_custody_pre_sha256'; value = 'A' * 64 },
        [pscustomobject]@{ name = 'result final hash'; fixture = $terminalResult; validator = $terminalFixtures[3].validator; field = 'source_custody_final_sha256'; value = 'A' * 64 }
    )) {
        $runtimeHostileCaseCount++
        $copy = ConvertTo-ContractClone -InputObject $uppercaseFixture.fixture
        $copy.($uppercaseFixture.field) = $uppercaseFixture.value
        if (-not (Test-Throws { & $uppercaseFixture.validator $copy 'json' })) {
            Add-Failure -Message "Terminal schema accepted uppercase $($uppercaseFixture.name)."
        }
    }
    $runtimeHostileCaseCount++
    if (Test-ExactLowerHexOrEmpty -Value ('A' * 64) -Length 64) {
        Add-Failure -Message 'Exact lowercase-hex validator accepted uppercase SHA-256.'
    }
    $runtimeHostileCaseCount++
    if (-not (Test-Throws {
        Assert-ManifestArtifactHash `
            -ArtifactRows ([object[]]@([pscustomobject]@{ path = 'C:\terminal-evidence\artifact.json'; sha256 = 'A' * 64 })) `
            -Path 'C:\terminal-evidence\artifact.json' `
            -ExpectedSha256 ('A' * 64) `
            -Label 'uppercase manifest hash hostile'
    })) {
        Add-Failure -Message 'Manifest hash binding accepted uppercase SHA-256 values.'
    }

    foreach ($expectedHashSpec in @(
        [pscustomobject]@{ name = 'aggregate'; parameter = 'ExpectedAggregateSha256'; valid = $terminalExpectedAggregateSha256 },
        [pscustomobject]@{ name = 'metadata'; parameter = 'ExpectedMetadataSha256'; valid = $terminalExpectedMetadataSha256 },
        [pscustomobject]@{ name = 'manifest'; parameter = 'ExpectedManifestSha256'; valid = $terminalExpectedManifestSha256 }
    )) {
        foreach ($hostileExpectedHash in @(
            $null,
            [int32]7,
            [pscustomobject]@{ hostile = $true },
            [object[]]@(,$expectedHashSpec.valid),
            ('A' * 64),
            ('f' * 64)
        )) {
            $runtimeHostileCaseCount++
            $arguments = @{
                Record = $terminalResult
                Representation = 'ordered'
                ExpectedAggregateSha256 = $terminalExpectedAggregateSha256
                ExpectedMetadataSha256 = $terminalExpectedMetadataSha256
                ExpectedManifestSha256 = $terminalExpectedManifestSha256
                Label = 'terminal result expected-hash hostile fixture'
            }
            $arguments[$expectedHashSpec.parameter] = $hostileExpectedHash
            if (-not (Test-Throws { Assert-TerminalResultShape @arguments })) {
                Add-Failure -Message "Terminal result accepted hostile expected $($expectedHashSpec.name) hash."
            }
        }
    }

    foreach ($rowFixture in @(
        [pscustomobject]@{
            name = 'artifact row'; value = [ordered]@{ path = 'C:\terminal-evidence\artifact.json'; sha256 = 'f' * 64 }
            validator = { param($value, $representation) Assert-TerminalArtifactRowShape -Row $value -Representation $representation -Label 'artifact row fixture' }
        },
        [pscustomobject]@{
            name = 'process row'; value = [ordered]@{ pid = [int32]101; parent_pid = [int32]100; name = 'Godot.exe'; command_line = '--path C:\terminal-evidence' }
            validator = { param($value, $representation) Assert-TerminalProcessCensusRowShape -Row $value -Representation $representation -Label 'process row fixture' }
        },
        [pscustomobject]@{
            name = 'replay survivor row'; value = [ordered]@{ kind = 'replay'; pid = [int32]101; session_prefix = '--session=rw062-heist-101-' }
            validator = { param($value, $representation) Assert-TerminalSurvivorRowShape -Row $value -Representation $representation -Label 'replay survivor row fixture' }
        },
        [pscustomobject]@{
            name = 'Godot survivor row'; value = [ordered]@{ kind = 'godot'; pid = [int32]102; command_line = '--path C:\terminal-evidence' }
            validator = { param($value, $representation) Assert-TerminalSurvivorRowShape -Row $value -Representation $representation -Label 'Godot survivor row fixture' }
        }
    )) {
        & $rowFixture.validator $rowFixture.value 'ordered'
        $jsonRow = ConvertTo-ContractClone -InputObject $rowFixture.value
        & $rowFixture.validator $jsonRow 'json'
        $runtimeValidCaseCount++
        foreach ($field in @($jsonRow.PSObject.Properties | ForEach-Object { [string]$_.Name })) {
            foreach ($variant in @('missing', 'null', 'object', 'array', 'wrong-scalar')) {
                $runtimeHostileCaseCount++
                $copy = ConvertTo-ContractClone -InputObject $rowFixture.value
                switch ($variant) {
                    'missing' { $copy.PSObject.Properties.Remove($field) }
                    'null' { $copy.$field = $null }
                    'object' { $copy.$field = [pscustomobject]@{ hostile = $true } }
                    'array' {
                        $prior = $copy.$field
                        $copy.$field = [object[]]@(,$prior)
                    }
                    'wrong-scalar' {
                        $prior = $copy.$field
                        $copy.$field = if ($prior -is [int32]) { '7' }
                            elseif ($prior -is [bool]) { 'true' }
                            else { [int32]7 }
                    }
                }
                if (-not (Test-Throws { & $rowFixture.validator $copy 'json' })) {
                    Add-Failure -Message "Terminal $($rowFixture.name) accepted $variant field '$field'."
                }
            }
        }
        $runtimeHostileCaseCount++
        $extra = ConvertTo-ContractClone -InputObject $rowFixture.value
        $extra | Add-Member -NotePropertyName authority -NotePropertyValue 'hostile'
        if (-not (Test-Throws { & $rowFixture.validator $extra 'json' })) {
            Add-Failure -Message "Terminal $($rowFixture.name) accepted an extra field."
        }
        $runtimeHostileCaseCount++
        $reordered = New-ReorderedContractObject -InputObject (ConvertTo-ContractClone -InputObject $rowFixture.value)
        if (-not (Test-Throws { & $rowFixture.validator $reordered 'json' })) {
            Add-Failure -Message "Terminal $($rowFixture.name) accepted reordered keys."
        }
        foreach ($rootFixture in @(
            [pscustomobject]@{ name = 'null'; value = $null },
            [pscustomobject]@{ name = 'ordered-object'; value = [ordered]@{} },
            [pscustomobject]@{ name = 'scalar'; value = 'row-scalar' },
            [pscustomobject]@{ name = 'array'; value = [object[]]@(,$jsonRow) },
            [pscustomobject]@{ name = 'nested-array'; value = [object[]]@(,([object[]]@($jsonRow))) }
        )) {
            $runtimeHostileCaseCount++
            if (-not (Test-Throws { & $rowFixture.validator $rootFixture.value 'json' })) {
                Add-Failure -Message "Terminal $($rowFixture.name) accepted hostile root '$($rootFixture.name)'."
            }
        }
    }
    foreach ($pidSpec in @(
        [pscustomobject]@{ name = 'process pid'; fixture = [ordered]@{ pid = [int32]101; parent_pid = [int32]100; name = 'Godot.exe'; command_line = '--path C:\terminal-evidence' }; field = 'pid'; validator = { param($value) Assert-TerminalProcessCensusRowShape -Row $value -Representation json -Label 'process pid width' } },
        [pscustomobject]@{ name = 'process parent_pid'; fixture = [ordered]@{ pid = [int32]101; parent_pid = [int32]100; name = 'Godot.exe'; command_line = '--path C:\terminal-evidence' }; field = 'parent_pid'; validator = { param($value) Assert-TerminalProcessCensusRowShape -Row $value -Representation json -Label 'process parent PID width' } },
        [pscustomobject]@{ name = 'replay survivor pid'; fixture = [ordered]@{ kind = 'replay'; pid = [int32]101; session_prefix = '--session=rw062-heist-101-' }; field = 'pid'; validator = { param($value) Assert-TerminalSurvivorRowShape -Row $value -Representation json -Label 'replay survivor PID width' } },
        [pscustomobject]@{ name = 'Godot survivor pid'; fixture = [ordered]@{ kind = 'godot'; pid = [int32]102; command_line = '--path C:\terminal-evidence' }; field = 'pid'; validator = { param($value) Assert-TerminalSurvivorRowShape -Row $value -Representation json -Label 'Godot survivor PID width' } }
    )) {
        $originalPid = Get-ExactValueNoEnumerate $pidSpec.fixture @($pidSpec.field) $null
        foreach ($typedValue in @(
            [pscustomobject]@{ name = 'Int64'; value = [int64]$originalPid },
            [pscustomobject]@{ name = 'Double'; value = [double]$originalPid },
            [pscustomobject]@{ name = 'Decimal'; value = [decimal]$originalPid },
            [pscustomobject]@{ name = 'UInt32'; value = [uint32]$originalPid }
        )) {
            $runtimeHostileCaseCount++
            $copy = ConvertTo-ContractClone -InputObject $pidSpec.fixture
            $copy.($pidSpec.field) = $typedValue.value
            if (-not (Test-Throws { & $pidSpec.validator $copy })) {
                Add-Failure -Message "Terminal $($pidSpec.name) accepted $($typedValue.name) width."
            }
        }
    }
    $runtimeHostileCaseCount++
    $uppercaseArtifactRow = [pscustomobject]@{ path = 'C:\terminal-evidence\artifact.json'; sha256 = 'A' * 64 }
    if (-not (Test-Throws {
        Assert-TerminalArtifactRowShape -Row $uppercaseArtifactRow -Representation json -Label 'uppercase artifact-row hash'
    })) {
        Add-Failure -Message 'Terminal artifact row accepted uppercase SHA-256.'
    }
}
catch {
    Add-Failure -Message "Runtime final-evidence contract could not execute: $($_.Exception.Message)"
}

$reportDirectory = Split-Path -Parent $ReportPath
New-Item -ItemType Directory -Path $reportDirectory -Force | Out-Null
$report = [ordered]@{
    contract = 'rw06_2_final_evidence_source'
    passed = ($failures.Count -eq 0)
    check_count = $checkCount
    launcher = $LauncherPath
    launcher_sha256 = (Get-FileHash -LiteralPath $LauncherPath -Algorithm SHA256).Hash.ToLowerInvariant()
    replay = $ReplayPath
    replay_sha256 = (Get-FileHash -LiteralPath $ReplayPath -Algorithm SHA256).Hash.ToLowerInvariant()
    admission = $AdmissionPath
    admission_sha256 = (Get-FileHash -LiteralPath $AdmissionPath -Algorithm SHA256).Hash.ToLowerInvariant()
    fixed_seeds = [ordered]@{
        clean = 'RW06-CLEAN-ROUTE-01'
        cheat = 'RW06-CHEAT-ROUTE-01'
        heist = 'RW06-HEIST-AUDIT-0002'
    }
    fresh_interactive_in_scope = $false
    hostile_case_count = $hostileCaseCount
    runtime_valid_case_count = $runtimeValidCaseCount
    runtime_hostile_case_count = $runtimeHostileCaseCount
    failures = @($failures)
}
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $ReportPath -Encoding utf8

if ($failures.Count -ne 0) {
    foreach ($failure in $failures) {
        Write-Error $failure -ErrorAction Continue
    }
    throw "RW06_2_FINAL_EVIDENCE_SOURCE_CONTRACT FAIL ($($failures.Count) failure(s)); report: $ReportPath"
}

Write-Output "RW06_2_FINAL_EVIDENCE_SOURCE_CONTRACT PASS; report: $ReportPath"
