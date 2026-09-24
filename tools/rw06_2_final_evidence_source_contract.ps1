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
[void][Management.Automation.Language.Parser]::ParseFile($AdmissionPath, [ref]$admissionTokens, [ref]$admissionParseErrors)
if ($admissionParseErrors.Count -ne 0) {
    Add-Failure -Message "PowerShell parse failed for $AdmissionPath`: $($admissionParseErrors[0].Message)"
}
$admissionSource = Get-Content -Raw -LiteralPath $AdmissionPath -Encoding utf8
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
    Test-TokensInOrder -Source $topLevel -Needles @(
        '$fixedRepeatQualifying = $null -eq $script:TerminalError -and',
        "`$script:Outcome -ceq 'green' -and",
        '$script:RunProofs.Count -eq 2 -and',
        '$null -ne $script:CanonicalProof -and',
        "[string]`$script:CanonicalProof.evidence_role -ceq 'fixed-repeat' -and",
        "@(`$script:RunProofs | Where-Object { [string]`$_.evidence_role -cne 'fixed-repeat' }).Count -eq 0 -and",
        '-not $script:LeaseOwned -and',
        '$script:FinalProcessCensus.Count -eq 0 -and',
        '$script:FinalHead -ceq $ExpectedHead.ToLowerInvariant() -and',
        '$script:FinalTree -ceq $ExpectedTree.ToLowerInvariant()'
    )
}
$childIterationBoundaryValidator = {
    param($analysis)
    $oneRun = Get-FunctionSource -Analysis $analysis -Name 'Assert-OneRunEvidence'
    Test-TokensInOrder -Source $oneRun -Needles @(
        "[string](Get-ExactValue `$run @('role') '') -cne 'child_development_iteration'",
        "[string](Get-ExactValue `$run @('requested_evidence_role') '') -cne 'fixed-repeat'",
        "[string](Get-ExactValue `$run @('repeat_profile_scope') '') -cne 'shared_caller_appdata'",
        "[string](Get-ExactValue `$run @('fixed_repeat_qualification_authority') '') -cne 'outer_independent_profile_aggregate_only'",
        "(Get-ExactValue `$run @('release_qualifying') `$null) -isnot [bool]",
        "[bool](Get-ExactValue `$run @('release_qualifying') `$true)",
        "[string](Get-ExactValue `$run @('qualification') '') -cne 'non_qualifying_development_iteration'"
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
            "[string](Get-ExactValue `$summary @('requested_evidence_role') '') -cne 'fixed-repeat'",
            "`$summaryAdmission = Get-ExactValue `$summary @('replay_admission') `$null",
            'Assert-FixedReplayAdmission -Admission $summaryAdmission',
            "[string](Get-ExactValue `$run @('requested_evidence_role') '') -cne 'fixed-repeat'",
            "`$runAdmission = Get-ExactValue `$run @('replay_admission') `$null",
            'Assert-FixedReplayAdmission -Admission $runAdmission',
            'Assert-Rw062HeistPreflightAdmission',
            "evidence_role = [string](Get-ExactValue `$summary @('requested_evidence_role') '')"
        )) -and
        $invoke.IndexOf("'-Ending', `$Ending, '-EvidenceRole', 'fixed-repeat', '-Seed', `$Seed, '-Repeat', '1'", [StringComparison]::Ordinal) -ge 0 -and
        $compare.IndexOf("[string]`$proof.evidence_role -cne 'fixed-repeat'", [StringComparison]::Ordinal) -ge 0 -and
        $compare.IndexOf("evidence_role = 'fixed-repeat'", [StringComparison]::Ordinal) -ge 0
}
$exactPathValidator = {
    param($analysis)
    $oneRun = Get-FunctionSource -Analysis $analysis -Name 'Assert-OneRunEvidence'
    $bindings = [ordered]@{
        transcript = '$transcriptPath'
        money_curve = '$moneyPath'
        persistence_checkpoint_before = '$checkpointBeforePath'
        persistence_checkpoint_after = '$checkpointAfterPath'
    }
    foreach ($entry in $bindings.GetEnumerator()) {
        $pattern = '(?s)Assert-ExactPublishedPath\s+`?\s*-PublishedPath\s+\(\[string\]\(Get-ExactValue \$run @\(''' +
            [regex]::Escape([string]$entry.Key) + '''\) ''''\)\)\s+`?\s*-ExpectedPath\s+' +
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
        'foreach ($proof in @($script:RunProofs))',
        '[string]$proof.replay_summary,',
        "(Join-Path ([string]`$proof.run_root) 'public_trace.ndjson')",
        '[string]$proof.profile_inventory,',
        '[string]$proof.autosave,',
        "(Join-Path ([string]`$proof.session_root) 'godot.engine.log')",
        '$requiredManifestArtifacts.Add([IO.Path]::GetFullPath($requiredArtifact))',
        'foreach ($requiredArtifact in $requiredManifestArtifacts)',
        'Aggregate manifest omitted required evidence artifact'
    )
}
$snapshotBindingValidator = {
    param($analysis)
    $topLevel = Get-ExecutableTopLevelSource -Analysis $analysis
    (Test-TokensInOrder -Source $topLevel -Needles @(
        '[IO.File]::WriteAllBytes($LauncherSnapshotPath, $launcherBytes)',
        '(Get-Sha256 -Path $LauncherSnapshotPath) -cne $script:LauncherInitialSha256',
        "throw 'Immutable launcher snapshot hash differs immediately after creation.'",
        '$script:LauncherCurrentSha256 = Get-Sha256 -Path $PSCommandPath',
        "Add-TerminalFailure -Failure 'Immutable launcher snapshot changed before teardown.'",
        '$launcherSnapshotRows = @($artifactRows',
        '[string]$launcherSnapshotRows[0].sha256 -cne $script:LauncherInitialSha256',
        "throw 'Aggregate manifest did not bind the exact immutable launcher snapshot hash.'"
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
Assert-Contains -Source $launcherSource -Needle "actionCount -le 0 -or `$actionCount -gt 350" `
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
Assert-Contains -Source $launcherSource -Needle "Fixed-repeat runs did not use two distinct profiles, sessions, roots, and replay processes." `
    -Message 'Final launcher lost distinct-profile/session/process enforcement.'
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
        -Needle "        [string](Get-ExactValue `$summary @('requested_evidence_role') '') -cne 'fixed-repeat' -or" `
        -Replacement '        $false -or'
}
Assert-HostileMutationRejected -Name 'fixed-role-iteration-check-bypass' -Validator $fixedRoleIsolationValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle "        [string](Get-ExactValue `$run @('requested_evidence_role') '') -cne 'fixed-repeat' -or" `
        -Replacement '        $false -or'
}
Assert-HostileMutationRejected -Name 'fixed-role-proof-check-bypass' -Validator $fixedRoleIsolationValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle "            [string]`$proof.evidence_role -cne 'fixed-repeat' -or" `
        -Replacement '            $false -or'
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
    Replace-SourceOnce -Source $source -Needle '    $script:RunProofs.Count -eq 2 -and' -Replacement '    $true -and'
}
Assert-HostileMutationRejected -Name 'child-iteration-qualification-bypass' -Validator $childIterationBoundaryValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle "        [string](Get-ExactValue `$run @('qualification') '') -cne 'non_qualifying_development_iteration' -or" `
        -Replacement '        $false -or'
}
Assert-HostileMutationRejected -Name 'checkpoint-path-binding-bypass' -Validator $exactPathValidator -Mutate {
    param($source)
    Replace-SourceOnce -Source $source `
        -Needle "@('persistence_checkpoint_after') ''))" `
        -Replacement "@('untrusted_checkpoint_after') ''))"
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
        -Needle '[string]$launcherSnapshotRows[0].sha256 -cne $script:LauncherInitialSha256' `
        -Replacement '$false'
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
    hostile_case_count = 36
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
