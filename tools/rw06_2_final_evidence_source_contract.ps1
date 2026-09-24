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
    }, $true))
    if ($assignments.Count -ne 1 -or
        -not [object]::ReferenceEquals($assignments[0].Parent, $Analysis.ast.EndBlock)) {
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
            '$process = Start-Process',
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
        '$RunProofs -isnot [Collections.IEnumerable]',
        '@($RunProofs).Count -ne 2',
        '$FinalProcessCensus -isnot [Collections.IEnumerable]',
        '@($FinalProcessCensus).Count -ne 0',
        '$FinalHead -isnot [string]',
        '$FinalTree -isnot [string]',
        '-not $SourceCustodyComplete',
        "`$canonicalRole = Get-ExactValueNoEnumerate `$CanonicalProof @('evidence_role') `$null",
        '$canonicalRole -isnot [string]',
        "`$canonicalRole -cne 'fixed-repeat'",
        "`$proofRole = Get-ExactValueNoEnumerate `$proof @('evidence_role') `$null",
        '$proofRole -isnot [string]',
        "`$proofRole -cne 'fixed-repeat'"
    )) -and
        (Test-TokensInOrder -Source $topLevel -Needles @(
            '$fixedRepeatQualifying = Test-FixedRepeatQualification',
            '-TerminalError $script:TerminalError',
            '-RunProofs $script:RunProofs',
            '-CanonicalProof $script:CanonicalProof',
            '-SourceCustodyComplete $script:SourceCustodyComplete'
        ))
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
    (Test-UniqueTokensInOrder -Source $topLevel -Needles @(
        '$aggregateSummary | ConvertTo-Json',
        '$metadata | ConvertTo-Json',
        '$artifactRows = @(Get-ManifestArtifactPaths',
        '$manifest | ConvertTo-Json',
        'manifest_sha256 = Get-Sha256 -Path $ManifestPath'
    )) -and
        $topLevel.IndexOf('$requiredManifestArtifacts', [StringComparison]::Ordinal) -ge 0 -and
        $topLevel.IndexOf('Evidence artifact changed during manifest finalization', [StringComparison]::Ordinal) -ge 0
}
$aggregateSummaryValidator = {
    param($analysis)
    Test-ExactTopLevelOrderedHashtableValues -Analysis $analysis -VariableName 'aggregateSummary' -Expected ([ordered]@{
        check_id = "'rw06_2_final_evidence'"
        role = "'fixed_route_repeat'"
        evidence_role = "'fixed-repeat'"
        repeat = '2'
        fresh_interactive_authorized = '$false'
        q017_status = "if (`$Ending -ceq 'heist') { 'ANSWERED_SEPARATE_FRESH_INTERACTIVE_SCOPE' } else { 'NOT_APPLICABLE' }"
    })
}
$metadataLabelValidator = {
    param($analysis)
    Test-ExactTopLevelOrderedHashtableValues -Analysis $analysis -VariableName 'metadata' -Expected ([ordered]@{
        lane = "'rw06_2p'"
        kind = "'exclusive-real-input-fixed-repeat-final-evidence'"
        role = "'fixed_route_repeat'"
        evidence_role = "'fixed-repeat'"
    })
}
$manifestLabelValidator = {
    param($analysis)
    Test-ExactTopLevelOrderedHashtableValues -Analysis $analysis -VariableName 'manifest' -Expected ([ordered]@{
        check_id = "'rw06_2_final_evidence_manifest'"
        role = "'fixed_route_repeat'"
        evidence_role = "'fixed-repeat'"
    })
}
$manifestClosureValidator = {
    param($analysis)
    $topLevel = Get-ExecutableTopLevelSource -Analysis $analysis
    Test-TokensInOrder -Source $topLevel -Needles @(
        '$requiredManifestArtifacts = [Collections.Generic.List[string]]::new()',
        '$SourceCustodyPrePath, $SourceCustodyFinalPath',
        'foreach ($proof in @($script:RunProofs))',
        '[string]$proof.replay_summary,',
        "(Join-Path ([string]`$proof.run_root) 'public_trace.ndjson')",
        '[string]$proof.profile_inventory,',
        '[string]$proof.autosave,',
        "(Join-Path ([string]`$proof.session_root) 'godot.engine.log')",
        '$requiredManifestArtifacts.Add([IO.Path]::GetFullPath($requiredArtifact))',
        '$requiredManifestArtifacts.Add([IO.Path]::GetFullPath([string]$proof.heist_seed_preflight))',
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
        '$ExpectedSha256 -isnot [string]', '$ExpectedSha256 -notmatch ''^[a-f0-9]{64}$''',
        '$candidatePath = Get-ExactValueNoEnumerate', '$manifestHash = Get-ExactValueNoEnumerate',
        '$manifestHash -isnot [string] -or $manifestHash -cne $ExpectedSha256'
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
    -Message 'Final launcher lost distinct-profile/session/process enforcement.'
Assert-Contains -Source $launcherSource -Needle "Fixed-repeat runs did not use two distinct exact replay processes." `
    -Message 'Final launcher lost distinct replay-process enforcement.'
Assert-Contains -Source $launcherSource -Needle "fixed_repeat_qualifying = [bool]`$fixedRepeatQualifying" `
    -Message 'Aggregate summary/manifest no longer publishes the fixed-repeat qualification result.'
Assert-Contains -Source $launcherSource -Needle "rw06_2_final_evidence_manifest" `
    -Message 'Final launcher no longer produces its aggregate artifact manifest.'
Assert-True -Condition ([bool](& $proofPromotionValidator $launcher)) `
    -Message 'Green promotion is no longer ordered strictly after cross-profile proof comparison.'
Assert-True -Condition ([bool](& $qualificationValidator $launcher)) `
    -Message 'Fixed-repeat qualification no longer has the exact fail-closed conjunction.'
Assert-True -Condition ([bool](& $aggregateSummaryValidator $launcher)) `
    -Message 'Aggregate summary no longer binds the exact fixed-repeat role, repeat, fresh authorization, and Q-017 status.'
Assert-True -Condition ([bool](& $metadataLabelValidator $launcher)) `
    -Message 'Retained aggregate metadata no longer binds the exact fixed-repeat role labels.'
Assert-True -Condition ([bool](& $manifestLabelValidator $launcher)) `
    -Message 'Retained aggregate manifest no longer binds its exact fixed-repeat role label.'
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
    $exactObjectType = Get-FunctionSource -Analysis $analysis -Name 'Test-ExactPsCustomObject'
    $exactJsonObject = Get-FunctionSource -Analysis $analysis -Name 'ConvertFrom-ExactJsonObjectText'
    $compare = Get-FunctionSource -Analysis $analysis -Name 'Compare-FixedRunProofs'
    $qualification = Get-FunctionSource -Analysis $analysis -Name 'Test-FixedRepeatQualification'
    if ([string]::IsNullOrWhiteSpace($admission) -or
        [string]::IsNullOrWhiteSpace($oneRun) -or
        [string]::IsNullOrWhiteSpace($oneRunShapes) -or
        [string]::IsNullOrWhiteSpace($finalShapes) -or
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
        'Assert-Rw062ExactPropertyNames -InputObject $Retained',
        'Assert-Rw062ExactPropertyNames -InputObject $Published',
        "path = @('schema_version'); type = 'int32'",
        "path = @('record_kind'); type = 'string'", "path = @('won'); type = 'bool'",
        "path = @('bankroll'); type = 'int32'", "path = @('heat'); type = 'int32'",
        '$schemaVersion -ne 1'
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
        'Assert-FinalCheckpointJsonShapes'
    ))) { return $false }
    if ($analysis.source -match '\[(?:string|int|bool|long)\]\(Get-ExactValue\s') { return $false }
    if ($compare -match '\[(?:string|int|bool|long)\]\$proof\.' -or
        $compare.IndexOf('$value -isnot [string] -or $value -cne [string]$entry.Value', [StringComparison]::Ordinal) -lt 0) {
        return $false
    }
    return $qualification.IndexOf('$canonicalRole -isnot [string]', [StringComparison]::Ordinal) -ge 0 -and
        $qualification.IndexOf('$proofRole -isnot [string]', [StringComparison]::Ordinal) -ge 0
}

$sourceCustodyValidator = {
    param($analysis)
    $topLevel = Get-ExecutableTopLevelSource -Analysis $analysis
    $descriptors = Get-FunctionSource -Analysis $analysis -Name 'Get-TrackedSourceDescriptors'
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
            '$repositoryRows = @($script:SourceCustodyRows', 'hash-object -- $paths',
            '$expectedBlob -notmatch ''^[a-f0-9]{40}$''', '$actualBlob -cne $expectedBlob',
            'Held worktree bytes do not match immutable HEAD blob'
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
            'pre_sha256 = [string]$digests.sha256',
            'Assert-RepositoryBlobIdentity',
            "check_id = 'rw06_2_source_custody_pre'",
            'New-LockedJsonReceipt -Path $SourceCustodyPrePath',
            '$script:SourceCustodyPreStream = $lockedPreReceipt.stream',
            '$script:SourceCustodyPreSha256 = [string]$lockedPreReceipt.sha256'
        )) -and
        (Test-TokensInOrder -Source $assert -Needles @(
            '$stream.CanRead', 'Get-HeldFileDigests -Stream $stream', 'Custodied source input changed',
            'Get-HeldFileDigests -Stream $script:SourceCustodyPreStream',
            'Get-HeldFileDigests -Stream $script:SourceCustodyFinalStream'
        )) -and
        (Test-TokensInOrder -Source $invoke -Needles @(
            'Assert-SourceCustody', '$process = Start-Process', '$process.WaitForExit()',
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
        (Test-TokensInOrder -Source $topLevel -Needles @(
            '$requiredManifestArtifacts.Add([IO.Path]::GetFullPath([string]$proof.heist_seed_preflight))',
            'Assert-ManifestArtifactHash -ArtifactRows $artifactRows',
            '-ExpectedSha256 (Get-ExactValueNoEnumerate $proof'
        ))
}
Assert-True -Condition ([bool](& $exactTypeValidator $launcher)) `
    -Message 'Retained admissions, summaries, run records, proofs, or aggregate roles can launder scalar types.'
Assert-True -Condition ([bool](& $sourceCustodyValidator $launcher)) `
    -Message 'Final launcher does not hold and receipt-bind exact execution/production inputs through child execution.'
Assert-True -Condition ([bool](& $retainedPreflightValidator $launcher)) `
    -Message 'Final launcher does not authenticate and explicitly manifest each retained Heist seed preflight file.'
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
    Replace-SourceOnce -Source $source -Needle '        @($RunProofs).Count -ne 2 -or' -Replacement '        $false -or'
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
    Replace-SourceOnce -Source $source -Needle "'profile_inventory.json'" -Replacement "'profile_inventory.disabled'"
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
    $needle = '$aggregateSummary | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $AggregateSummaryPath -Encoding utf8'
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
    Replace-SourceOnce -Source $source -Needle '        [string]$proof.replay_summary,' -Replacement "        '',"
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
    Replace-SourceOnce -Source $source -Needle '$canonicalRole -isnot [string] -or $canonicalRole -cne ''fixed-repeat''' -Replacement '$canonicalRole -cne ''fixed-repeat'''
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
    Replace-SourceOnce -Source $source -Needle '$actualBlob -cne $expectedBlob' -Replacement '$false'
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
    $pattern = '(?m)^(    Assert-SourceCustody)\r?\n(?=\r?\n    \$originalAppData)'
    if ([regex]::Matches($source, $pattern).Count -ne 1) { throw 'Could not isolate pre-spawn source-custody assertion.' }
    return [regex]::Replace($source, $pattern, '    $null = ''pre-spawn-custody-bypassed''', 1)
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
    Replace-SourceOnce -Source $source -Needle '$requiredManifestArtifacts.Add([IO.Path]::GetFullPath([string]$proof.heist_seed_preflight))' -Replacement '$null = $proof.heist_seed_preflight'
}
Assert-HostileMutationRejected -Name 'retained-preflight-manifest-hash-binding-omitted' -Validator $retainedPreflightValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle '-ExpectedSha256 (Get-ExactValueNoEnumerate $proof @(''heist_seed_preflight_sha256'') $null)' `
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
        -Needle '    Assert-Rw062ExactPropertyNames -InputObject $Retained -Expected $checkpointPropertyNames -Label "$Label retained"' `
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
        'Get-ExactValueNoEnumerate', 'Get-Sha256', 'Test-ExactPsCustomObject',
        'ConvertFrom-ExactJsonObjectText', 'ConvertTo-CanonicalExactObjectJson',
        'Get-HeldFileDigests', 'Get-HeldUtf8Text', 'New-LockedJsonReceipt',
        'Get-TrackedSourceDescriptors', 'Assert-RepositoryBlobIdentity',
        'Get-ExactPositivePid', 'Get-ExactPidArray',
        'Assert-SourceCustody', 'Open-SourceCustodyHandle', 'New-SourceCustody',
        'Complete-SourceCustody', 'Close-SourceCustody',
        'Assert-RetainedHeistPreflightArtifact', 'Assert-OneRunJsonShapes',
        'Assert-FinalCheckpointJsonShapes', 'Assert-ManifestArtifactHash', 'Compare-FixedRunProofs',
        'Test-FixedRepeatQualification'
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
    $commonHash = 'a' * 64
    $proofs = @(
        [pscustomobject][ordered]@{
            role = 'fixed_route_repeat'; evidence_role = 'fixed-repeat'; ending = $Ending; seed = $Seed
            profile_inventory_sha256 = 'b' * 64; autosave_sha256 = 'c' * 64; replay_summary_sha256 = 'd' * 64
            transcript_sha256 = $commonHash; money_curve_sha256 = $commonHash
            persistence_checkpoint_before_sha256 = $commonHash; persistence_checkpoint_after_sha256 = $commonHash
            final_public_checkpoint_sha256 = $commonHash; source_custody_pre_sha256 = $commonHash
            godot_stdout_sha256 = 'e' * 64; godot_stderr_sha256 = 'f' * 64; godot_engine_sha256 = '1' * 64
            profile_roaming = 'C:\proof-01\roaming'; profile_local = 'C:\proof-01\local'
            profile_session_root = 'C:\proof-01\profile-session'; profile_inventory = 'C:\proof-01\profile.json'
            autosave = 'C:\proof-01\autosave.json'; replay_invocation_root = 'C:\proof-01\replay'
            replay_summary = 'C:\proof-01\replay\summary.json'; run_root = 'C:\proof-01\run'
            session_root = 'C:\proof-01\session-root'; source_custody_pre = 'C:\shared\source_custody_pre.json'
            session = 'rw062-heist-101-1-aaaaaaaaaa'; replay_pid = [int32]101
            heist_seed_preflight = 'C:\proof-01\replay\heist_seed_preflight.json'
            heist_seed_preflight_sha256 = $commonHash
        },
        [pscustomobject][ordered]@{
            role = 'fixed_route_repeat'; evidence_role = 'fixed-repeat'; ending = $Ending; seed = $Seed
            profile_inventory_sha256 = '2' * 64; autosave_sha256 = '3' * 64; replay_summary_sha256 = '4' * 64
            transcript_sha256 = $commonHash; money_curve_sha256 = $commonHash
            persistence_checkpoint_before_sha256 = $commonHash; persistence_checkpoint_after_sha256 = $commonHash
            final_public_checkpoint_sha256 = $commonHash; source_custody_pre_sha256 = $commonHash
            godot_stdout_sha256 = '5' * 64; godot_stderr_sha256 = '6' * 64; godot_engine_sha256 = '7' * 64
            profile_roaming = 'C:\proof-02\roaming'; profile_local = 'C:\proof-02\local'
            profile_session_root = 'C:\proof-02\profile-session'; profile_inventory = 'C:\proof-02\profile.json'
            autosave = 'C:\proof-02\autosave.json'; replay_invocation_root = 'C:\proof-02\replay'
            replay_summary = 'C:\proof-02\replay\summary.json'; run_root = 'C:\proof-02\run'
            session_root = 'C:\proof-02\session-root'; source_custody_pre = 'C:\shared\source_custody_pre.json'
            session = 'rw062-heist-202-1-bbbbbbbbbb'; replay_pid = [int32]202
            heist_seed_preflight = 'C:\proof-02\replay\heist_seed_preflight.json'
            heist_seed_preflight_sha256 = $commonHash
        }
    )
    $canonicalProof = Compare-FixedRunProofs -Proofs $proofs
    $runtimeValidCaseCount++
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
    $runtimeValidCaseCount++

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
            $runtimeHostileCaseCount++
            $retainedCopy = $shapeCheckpoint | ConvertTo-Json -Depth 10 -Compress | ConvertFrom-Json
            $publishedCopy = $shapeCheckpoint | ConvertTo-Json -Depth 10 -Compress | ConvertFrom-Json
            $target = if ($targetName -ceq 'retained') { $retainedCopy } else { $publishedCopy }
            $target.PSObject.Properties.Remove($field)
            if (-not (Test-Throws { Assert-FinalCheckpointJsonShapes -Retained $retainedCopy -Published $publishedCopy -Label "missing $targetName $field" })) {
                Add-Failure -Message "Final-checkpoint shape validator accepted missing $targetName property '$field'."
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

    foreach ($field in @(
        'schema_version', 'evidence_root', 'check_id', 'role', 'requested_evidence_role',
        'repeat_profile_scope', 'fixed_repeat_qualification_authority', 'ending', 'seed', 'repeat',
        'deterministic', 'checkpoint_evidence_complete', 'release_qualifying', 'qualification',
        'public_observation_schema', 'public_observation_schema_version'
    )) {
        $runtimeHostileCaseCount++
        $summaryCopy = $shapeSummary | ConvertTo-Json -Depth 20 -Compress | ConvertFrom-Json
        $runCopy = $shapeRun | ConvertTo-Json -Depth 20 -Compress | ConvertFrom-Json
        $summaryCopy.runs = [object[]]@($runCopy)
        $summaryCopy.$field = [object[]]@($summaryCopy.$field)
        if (-not (Test-Throws { Assert-OneRunJsonShapes -Summary $summaryCopy -Run $runCopy -Label "summary $field array" })) {
            Add-Failure -Message "One-run shape validator accepted summary scalar array '$field'."
        }
    }
    foreach ($field in @(
        'action_count', 'outcome', 'role', 'requested_evidence_role', 'repeat_profile_scope',
        'fixed_repeat_qualification_authority', 'release_qualifying', 'qualification', 'passed',
        'iteration', 'ending', 'seed', 'observed_terminal_seed', 'midpoint_save_relaunch_continue', 'failure',
        'transcript', 'money_curve', 'persistence_checkpoint_before', 'persistence_checkpoint_after',
        'transcript_sha256', 'money_curve_sha256', 'persistence_checkpoint_before_sha256',
        'persistence_checkpoint_after_sha256', 'persistence_checkpoint_equal',
        'persistence_checkpoint_complete', 'session'
    )) {
        $runtimeHostileCaseCount++
        $summaryCopy = $shapeSummary | ConvertTo-Json -Depth 20 -Compress | ConvertFrom-Json
        $runCopy = $shapeRun | ConvertTo-Json -Depth 20 -Compress | ConvertFrom-Json
        $summaryCopy.runs = [object[]]@($runCopy)
        $runCopy.$field = [object[]]@($runCopy.$field)
        if (-not (Test-Throws { Assert-OneRunJsonShapes -Summary $summaryCopy -Run $runCopy -Label "run $field array" })) {
            Add-Failure -Message "One-run shape validator accepted run scalar array '$field'."
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
        $runtimeHostileCaseCount++
        $summaryCopy = $shapeSummary | ConvertTo-Json -Depth 20 -Compress | ConvertFrom-Json
        $runCopy = $shapeRun | ConvertTo-Json -Depth 20 -Compress | ConvertFrom-Json
        $summaryCopy.runs = [object[]]@($runCopy)
        $target = if ($fixture.target -ceq 'summary') { $summaryCopy } else { $runCopy }
        $target.($fixture.field) = [object[]]@($target.($fixture.field))
        if (-not (Test-Throws { Assert-OneRunJsonShapes -Summary $summaryCopy -Run $runCopy -Label "embedded $($fixture.field) array" })) {
            Add-Failure -Message "One-run shape validator accepted embedded object array '$($fixture.target).$($fixture.field)'."
        }
    }
    foreach ($fixture in @(
        [pscustomobject]@{ target = 'summary'; field = 'observed_terminal_seeds' },
        [pscustomobject]@{ target = 'summary'; field = 'runs' },
        [pscustomobject]@{ target = 'launch'; field = 'selected_content_groups' }
    )) {
        $runtimeHostileCaseCount++
        $summaryCopy = $shapeSummary | ConvertTo-Json -Depth 20 -Compress | ConvertFrom-Json
        $runCopy = $shapeRun | ConvertTo-Json -Depth 20 -Compress | ConvertFrom-Json
        $summaryCopy.runs = [object[]]@($runCopy)
        if ($fixture.target -ceq 'launch') {
            $value = $runCopy.heist_launch_setup.($fixture.field)
            $runCopy.heist_launch_setup.($fixture.field) = [object[]]@(,([object[]]@($value)))
        }
        else {
            $value = $summaryCopy.($fixture.field)
            $summaryCopy.($fixture.field) = [object[]]@(,([object[]]@($value)))
        }
        if (-not (Test-Throws { Assert-OneRunJsonShapes -Summary $summaryCopy -Run $runCopy -Label "nested $($fixture.field) array" })) {
            Add-Failure -Message "One-run shape validator accepted nested array '$($fixture.field)'."
        }
    }
    foreach ($field in @('selected_challenge_id', 'selected_home_type_id')) {
        $runtimeHostileCaseCount++
        $summaryCopy = $shapeSummary | ConvertTo-Json -Depth 20 -Compress | ConvertFrom-Json
        $runCopy = $shapeRun | ConvertTo-Json -Depth 20 -Compress | ConvertFrom-Json
        $summaryCopy.runs = [object[]]@($runCopy)
        $runCopy.heist_launch_setup.$field = [object[]]@($runCopy.heist_launch_setup.$field)
        if (-not (Test-Throws { Assert-OneRunJsonShapes -Summary $summaryCopy -Run $runCopy -Label "launch $field array" })) {
            Add-Failure -Message "One-run shape validator accepted launch scalar array '$field'."
        }
    }
    foreach ($rootFixture in @('summary', 'run')) {
        $runtimeHostileCaseCount++
        $summaryValue = $shapeSummary
        $runValue = $shapeRun
        if ($rootFixture -ceq 'summary') { $summaryValue = [object[]]@($shapeSummary) }
        if ($rootFixture -ceq 'run') { $runValue = [object[]]@($shapeRun) }
        if (-not (Test-Throws { Assert-OneRunJsonShapes -Summary $summaryValue -Run $runValue -Label "$rootFixture root array" })) {
            Add-Failure -Message "One-run shape validator accepted $rootFixture root array."
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
    foreach ($field in @('bankroll', 'chips', 'heat')) {
        foreach ($targetName in @('retained', 'published')) {
            foreach ($value in @([int64]100, ([int64][int32]::MaxValue + 1))) {
                $runtimeHostileCaseCount++
                $retainedCopy = $shapeCheckpoint | ConvertTo-Json -Depth 10 -Compress | ConvertFrom-Json
                $publishedCopy = $shapeCheckpoint | ConvertTo-Json -Depth 10 -Compress | ConvertFrom-Json
                $target = if ($targetName -ceq 'retained') { $retainedCopy } else { $publishedCopy }
                $target.$field = [int64]$value
                if (-not (Test-Throws { Assert-FinalCheckpointJsonShapes -Retained $retainedCopy -Published $publishedCopy -Label "$targetName $field Int64" })) {
                    Add-Failure -Message "Final-checkpoint shape validator accepted Int64 $targetName field '$field'."
                }
            }
        }
    }
    foreach ($rootFixture in @('retained', 'published')) {
        $runtimeHostileCaseCount++
        $retainedValue = $shapeCheckpoint
        $publishedValue = $shapeCheckpoint
        if ($rootFixture -ceq 'retained') { $retainedValue = [object[]]@($shapeCheckpoint) }
        if ($rootFixture -ceq 'published') { $publishedValue = [object[]]@($shapeCheckpoint) }
        if (-not (Test-Throws { Assert-FinalCheckpointJsonShapes -Retained $retainedValue -Published $publishedValue -Label "$rootFixture checkpoint root array" })) {
            Add-Failure -Message "Final-checkpoint shape validator accepted $rootFixture root array."
        }
    }
    $proofScalarFields = @(
        'role', 'evidence_role', 'ending', 'seed',
        'profile_inventory_sha256', 'autosave_sha256', 'replay_summary_sha256',
        'transcript_sha256', 'money_curve_sha256', 'persistence_checkpoint_before_sha256',
        'persistence_checkpoint_after_sha256', 'final_public_checkpoint_sha256',
        'source_custody_pre_sha256', 'godot_stdout_sha256', 'godot_stderr_sha256', 'godot_engine_sha256',
        'profile_roaming', 'profile_local', 'profile_session_root', 'profile_inventory', 'autosave',
        'replay_invocation_root', 'replay_summary', 'run_root', 'session_root', 'source_custody_pre',
        'session', 'replay_pid', 'heist_seed_preflight', 'heist_seed_preflight_sha256'
    )
    foreach ($field in $proofScalarFields) {
        $runtimeHostileCaseCount++
        $decodedCopy = $proofs | ConvertTo-Json -Depth 10 -Compress | ConvertFrom-Json
        $copy = @($decodedCopy)
        $copy[0].$field = [object[]]@($copy[0].$field)
        if (-not (Test-Throws { $null = Compare-FixedRunProofs -Proofs $copy })) {
            Add-Failure -Message "Compare-FixedRunProofs accepted one-element array field '$field'."
        }
    }

    $ExpectedHead = '1' * 40
    $ExpectedTree = '2' * 40
    $emptyCensus = [object[]]@()
    if (-not (Test-FixedRepeatQualification -TerminalError $null -Outcome 'green' -RunProofs $proofs `
        -CanonicalProof $canonicalProof -LeaseOwned:$false -FinalProcessCensus $emptyCensus `
        -FinalHead $ExpectedHead -FinalTree $ExpectedTree -SourceCustodyComplete:$true)) {
        throw 'Valid aggregate qualification fixture failed.'
    }
    $runtimeValidCaseCount++
    $runtimeHostileCaseCount++
    $hostileCanonical = $canonicalProof | ConvertTo-Json -Depth 10 -Compress | ConvertFrom-Json
    $hostileCanonical.evidence_role = [object[]]@('fixed-repeat')
    if (Test-FixedRepeatQualification -TerminalError $null -Outcome 'green' -RunProofs $proofs `
        -CanonicalProof $hostileCanonical -LeaseOwned:$false -FinalProcessCensus $emptyCensus `
        -FinalHead $ExpectedHead -FinalTree $ExpectedTree -SourceCustodyComplete:$true) {
        Add-Failure -Message 'Aggregate qualification accepted a canonical evidence-role array.'
    }
    $runtimeHostileCaseCount++
    $decodedHostileProofs = $proofs | ConvertTo-Json -Depth 10 -Compress | ConvertFrom-Json
    $hostileProofs = @($decodedHostileProofs)
    $hostileProofs[0].evidence_role = [object[]]@('fixed-repeat')
    if (Test-FixedRepeatQualification -TerminalError $null -Outcome 'green' -RunProofs $hostileProofs `
        -CanonicalProof $canonicalProof -LeaseOwned:$false -FinalProcessCensus $emptyCensus `
        -FinalHead $ExpectedHead -FinalTree $ExpectedTree -SourceCustodyComplete:$true) {
        Add-Failure -Message 'Aggregate qualification accepted a run-proof evidence-role array.'
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
        [IO.File]::WriteAllText($fixtureSourcePath, 'stable-source', [Text.UTF8Encoding]::new($false))
        & git -C $sourceFixtureRepo add -- source.txt
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
                'repository:source.txt',
                'godot:console', 'godot:runtime', 'powershell:host'
            )) {
                if ($custodyIds -cnotcontains $requiredId) {
                    throw "Actual source-custody inventory omitted '$requiredId'."
                }
            }
            if (-not $script:SourceCustodyComplete -or
                $script:SourceCustodyRows.Count -ne 4 -or
                $script:SourceCustodyPreSha256 -notmatch '^[a-f0-9]{64}$' -or
                $script:SourceCustodyFinalSha256 -notmatch '^[a-f0-9]{64}$' -or
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
            if ($preReceipt.input_count -ne 4 -or $finalReceipt.input_count -ne 4 -or
                -not [bool]$finalReceipt.custody_complete) {
                throw 'Runtime source custody receipts do not bind the exact held inventory.'
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
        [IO.File]::WriteAllText($fixtureSourcePath, 'hostile-source', [Text.UTF8Encoding]::new($false))
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
