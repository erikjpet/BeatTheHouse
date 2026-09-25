[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('clean', 'cheat', 'heist')]
    [string]$Ending,
    [ValidateSet('fixed-repeat', 'fresh-interactive')]
    [string]$EvidenceRole = 'fixed-repeat',
    [ValidatePattern('^[A-Za-z0-9_-]+$')]
    [string]$Seed = '',
    [ValidateRange(1, 2)]
    [int]$Repeat = 2,
    [ValidateRange(30, 1800)]
    [int]$TimeoutSeconds = 120,
    [string]$EvidenceRoot = '',
    [switch]$ConfirmationOnly,
    [switch]$BridgeTransportContract,
    [switch]$BridgeStatusContract,
    [switch]$SemanticScrollContract
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Ending = $Ending.ToLowerInvariant()
$EvidenceRole = $EvidenceRole.ToLowerInvariant()

$Worktree = Split-Path -Parent $PSScriptRoot
$SessionTool = Join-Path $PSScriptRoot 'agent_playtest_session.ps1'
$ReplayPolicyTool = Join-Path $PSScriptRoot 'rw06_2_replay_policies.ps1'
$EvidenceAdmissionTool = Join-Path $PSScriptRoot 'rw06_2_evidence_admission.ps1'
$HeistSeedPreflightTool = Join-Path $PSScriptRoot 'rw06_2_heist_seed_preflight.ps1'
$GodotBin = 'D:\Projects\Beat-The-House\.tools\godot-4.6-stable\Godot_v4.6-stable_win64_console.exe'
$Schema = 'beat_the_house.agent_public_observation'
$SchemaVersion = 1
$BridgeCallRoot = Join-Path $Worktree '.tmp\rw06_2\bridge_calls'
$ExpectedOutcomes = @{
    clean = @('players_card')
    cheat = @('showdown_survived')
    heist = @('heist_clean_sweep', 'heist_out_hot', 'heist_somebody_got_pinched')
}
$GrandCasinoChipReserve = 50

if (-not (Test-Path -LiteralPath $SessionTool)) {
    throw "Production-input launcher is missing: $SessionTool"
}
if (-not (Test-Path -LiteralPath $ReplayPolicyTool)) {
    throw "Replay policy helper is missing: $ReplayPolicyTool"
}
if (-not $ConfirmationOnly -and -not (Test-Path -LiteralPath $EvidenceAdmissionTool)) {
    throw "Replay evidence admission helper is missing: $EvidenceAdmissionTool"
}
if (-not $ConfirmationOnly -and -not (Test-Path -LiteralPath $HeistSeedPreflightTool)) {
    throw "Heist seed preflight is missing: $HeistSeedPreflightTool"
}
. $ReplayPolicyTool
if (-not (Test-Path -LiteralPath $GodotBin)) {
    throw "Pinned Godot binary is missing: $GodotBin"
}
if ($ConfirmationOnly) {
    $confirmationSeeds = @{
        clean = 'RW06-CLEAN-ROUTE-01'
        cheat = 'RW06-CHEAT-ROUTE-01'
        heist = 'RW06-HEIST-AUDIT-0002'
    }
    if ([string]::IsNullOrWhiteSpace($Seed)) {
        $Seed = [string]$confirmationSeeds[$Ending]
    }
    $Repeat = 1
    $script:ReplayAdmission = $null
}
else {
    . $EvidenceAdmissionTool
    $script:ReplayAdmission = Resolve-Rw062ReplayAdmission `
        -Ending $Ending `
        -EvidenceRole $EvidenceRole `
        -Seed $Seed `
        -Repeat $Repeat
    $EvidenceRole = [string]$script:ReplayAdmission.evidence_role
    $Seed = [string]$script:ReplayAdmission.seed
    if ([string]::IsNullOrWhiteSpace($EvidenceRoot)) {
        $evidenceScope = if ($EvidenceRole -ceq 'fresh-interactive') { 'fresh_interactive' } else { $Ending }
        $EvidenceRoot = Join-Path $Worktree ".tmp\rw06_2\$evidenceScope"
    }
}

$env:GODOT_BIN = $GodotBin
$script:PowerShellExe = [Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
$script:Session = ''
$script:RunRoot = ''
$script:TranscriptPath = ''
$script:MoneyCurvePath = ''
$script:LastResult = $null
$script:LastObservation = $null
$script:ActionCount = 0
$script:TraceOrdinal = 0
$script:LastMoneySignature = ''
$script:MidpointSaved = $false
$script:OwnedSessionPid = 0
$script:OwnedSessionStartUtcTicks = 0L
$script:OwnedSessionExecutablePath = ''
$script:SessionRoot = ''
$script:GrandFareRecoveryActive = $false
$script:GrandFareAcceptedOfferKeys = New-Object 'System.Collections.Generic.HashSet[string]'
$script:GrandFareAcceptedLenderIds = New-Object 'System.Collections.Generic.HashSet[string]'
$script:GrandFareResolvedCashEventKeys = New-Object 'System.Collections.Generic.HashSet[string]'
$script:GrandFareRecoveryVisitedNodes = New-Object 'System.Collections.Generic.HashSet[string]'
$script:HeistLaunchSetup = $null
$script:HeistPreflightAdmissionReceipt = $null


function Get-Value {
    param(
        [AllowNull()]$InputObject,
        [Parameter(Mandatory = $true)][string[]]$Path,
        [AllowNull()]$Default = $null
    )
    $current = $InputObject
    foreach ($segment in $Path) {
        if ($null -ceq $current) { return $Default }
        if ($current -is [System.Collections.IDictionary]) {
            $matchingKeys = @($current.Keys | Where-Object { [string]$_ -ceq $segment })
            if ($matchingKeys.Count -ceq 0) { return $Default }
            if ($matchingKeys.Count -cne 1) { throw "Ambiguous exact property '$segment'." }
            $current = $current[$matchingKeys[0]]
        }
        else {
            $properties = @($current.PSObject.Properties | Where-Object { $_.Name -ceq $segment })
            if ($properties.Count -ceq 0) { return $Default }
            if ($properties.Count -cne 1) { throw "Ambiguous exact property '$segment'." }
            $current = $properties[0].Value
        }
    }
    if ($null -ceq $current) { return $Default }
    return $current
}


function Get-Array {
    param([AllowNull()]$Value)
    if ($null -ceq $Value) { return @() }
    return @($Value)
}


function Get-ReplayPathValue {
    param(
        [AllowNull()]$InputObject,
        [Parameter(Mandatory = $true)][string[]]$Path,
        [Parameter(Mandatory = $true)][ref]$Found,
        [Parameter(Mandatory = $true)][string]$Context
    )
    $Found.Value = $false
    $current = $InputObject
    foreach ($segment in $Path) {
        if ($null -ceq $current) {
            return $null
        }
        if ($current -is [System.Collections.IDictionary]) {
            $matchingKeys = @($current.Keys | Where-Object { $_ -is [string] -and $_ -ceq $segment })
            if ($matchingKeys.Count -ceq 0) {
                return $null
            }
            if ($matchingKeys.Count -cne 1) {
                throw "$Context has an ambiguous exact property '$segment'."
            }
            $current = $current[$matchingKeys[0]]
            continue
        }
        if ($current -isnot [System.Management.Automation.PSCustomObject]) {
            throw "$Context traverses a non-object value before exact property '$segment'."
        }
        $properties = @($current.PSObject.Properties | Where-Object { $_.Name -ceq $segment })
        if ($properties.Count -ceq 0) {
            return $null
        }
        if ($properties.Count -cne 1) {
            throw "$Context has an ambiguous exact property '$segment'."
        }
        $current = $properties[0].Value
    }
    $Found.Value = $true
    Write-Output -NoEnumerate $current
}


function Test-ReplayPathPresent {
    param(
        [AllowNull()]$InputObject,
        [Parameter(Mandatory = $true)][string[]]$Path,
        [Parameter(Mandatory = $true)][string]$Context
    )
    $found = $false
    $null = Get-ReplayPathValue -InputObject $InputObject -Path $Path -Found ([ref]$found) -Context $Context
    return $found
}


function Get-ExactReplayString {
    param(
        [AllowNull()]$InputObject,
        [Parameter(Mandatory = $true)][string[]]$Path,
        [Parameter(Mandatory = $true)][string]$Context,
        [switch]$AllowMissing,
        [string]$Default = ''
    )
    $found = $false
    $value = Get-ReplayPathValue -InputObject $InputObject -Path $Path -Found ([ref]$found) -Context $Context
    if (-not $found) {
        if ($AllowMissing) { return $Default }
        throw "$Context is missing its exact string value."
    }
    if ($value -isnot [string]) {
        throw "$Context must be an exact string."
    }
    return $value
}


function Get-ExactReplayBoolean {
    param(
        [AllowNull()]$InputObject,
        [Parameter(Mandatory = $true)][string[]]$Path,
        [Parameter(Mandatory = $true)][string]$Context,
        [switch]$AllowMissing,
        [bool]$Default = $false
    )
    $found = $false
    $value = Get-ReplayPathValue -InputObject $InputObject -Path $Path -Found ([ref]$found) -Context $Context
    if (-not $found) {
        if ($AllowMissing) { return $Default }
        throw "$Context is missing its exact boolean value."
    }
    if ($value -isnot [bool]) {
        throw "$Context must be an exact boolean."
    }
    return $value
}


function Get-ExactReplayInt32 {
    param(
        [AllowNull()]$InputObject,
        [Parameter(Mandatory = $true)][string[]]$Path,
        [Parameter(Mandatory = $true)][string]$Context,
        [switch]$AllowMissing,
        [int32]$Default = 0
    )
    $found = $false
    $value = Get-ReplayPathValue -InputObject $InputObject -Path $Path -Found ([ref]$found) -Context $Context
    if (-not $found) {
        if ($AllowMissing) { return $Default }
        throw "$Context is missing its exact Int32 value."
    }
    if ($value -isnot [int32]) {
        throw "$Context must be an exact Int32."
    }
    return $value
}


function Get-ExactReplayObjectArray {
    param(
        [AllowNull()]$InputObject,
        [Parameter(Mandatory = $true)][string[]]$Path,
        [Parameter(Mandatory = $true)][string]$Context,
        [ValidateSet('Any', 'String', 'PSCustomObject')][string]$ElementType = 'Any',
        [switch]$AllowMissing
    )
    $found = $false
    $value = Get-ReplayPathValue -InputObject $InputObject -Path $Path -Found ([ref]$found) -Context $Context
    if (-not $found) {
        if ($AllowMissing) {
            Write-Output -NoEnumerate ([object[]]@())
            return
        }
        throw "$Context is missing its exact array value."
    }
    if ($value -isnot [object[]]) {
        throw "$Context must be an exact JSON array."
    }
    for ($index = 0; $index -lt $value.Count; $index++) {
        if ($ElementType -ceq 'String' -and $value[$index] -isnot [string]) {
            throw "$Context contains a non-string element at index $index."
        }
        if ($ElementType -ceq 'PSCustomObject' -and
            $value[$index] -isnot [System.Management.Automation.PSCustomObject]) {
            throw "$Context contains a non-object element at index $index."
        }
    }
    Write-Output -NoEnumerate $value
}


function Get-ExactReplayPsCustomObject {
    param(
        [AllowNull()]$InputObject,
        [Parameter(Mandatory = $true)][string[]]$Path,
        [Parameter(Mandatory = $true)][string]$Context,
        [switch]$AllowMissing,
        [switch]$AllowNull
    )
    $found = $false
    $value = Get-ReplayPathValue -InputObject $InputObject -Path $Path -Found ([ref]$found) -Context $Context
    if (-not $found) {
        if ($AllowMissing) { return $null }
        throw "$Context is missing its exact object value."
    }
    if ($null -ceq $value) {
        if ($AllowNull) { return $null }
        throw "$Context must not be null."
    }
    if ($value -isnot [System.Management.Automation.PSCustomObject]) {
        throw "$Context must be an exact JSON object."
    }
    return $value
}


function Assert-ExactReplayPsCustomObject {
    param(
        [AllowNull()]$Value,
        [Parameter(Mandatory = $true)][string]$Context
    )
    if ($Value -isnot [System.Management.Automation.PSCustomObject]) {
        throw "$Context must be an exact JSON object."
    }
}


function Assert-ExactReplayObjectKeys {
    param(
        [AllowNull()]$Value,
        [Parameter(Mandatory = $true)][string[]]$ExpectedKeys,
        [Parameter(Mandatory = $true)][string]$Context
    )
    Assert-ExactReplayPsCustomObject -Value $Value -Context $Context
    $actualKeys = @($Value.PSObject.Properties | ForEach-Object { $_.Name })
    if ($actualKeys.Count -cne $ExpectedKeys.Count) {
        throw "$Context must contain exactly $($ExpectedKeys.Count) properties; found $($actualKeys.Count)."
    }
    for ($index = 0; $index -lt $ExpectedKeys.Count; $index++) {
        if ($actualKeys[$index] -cne $ExpectedKeys[$index]) {
            throw "$Context property $index must be '$($ExpectedKeys[$index])', not '$($actualKeys[$index])'."
        }
    }
}


function Assert-ExactFinalPublicCheckpoint {
    param(
        [AllowNull()]$Checkpoint,
        [Parameter(Mandatory = $true)][string]$ExpectedSeed,
        [Parameter(Mandatory = $true)][string]$Context
    )
    Assert-ExactReplayObjectKeys -Value $Checkpoint -ExpectedKeys @(
        'schema_version',
        'record_kind',
        'observed_seed',
        'outcome_key',
        'won',
        'public_fingerprint',
        'checkpoint_fingerprint',
        'bankroll',
        'chips',
        'heat'
    ) -Context $Context
    $schemaVersion = Get-ExactReplayInt32 -InputObject $Checkpoint -Path @('schema_version') -Context "$Context schema version"
    $recordKind = Get-ExactReplayString -InputObject $Checkpoint -Path @('record_kind') -Context "$Context record kind"
    $observedSeed = Get-ExactReplayString -InputObject $Checkpoint -Path @('observed_seed') -Context "$Context observed seed"
    $outcomeKey = Get-ExactReplayString -InputObject $Checkpoint -Path @('outcome_key') -Context "$Context outcome key"
    $won = Get-ExactReplayBoolean -InputObject $Checkpoint -Path @('won') -Context "$Context win witness"
    $publicFingerprint = Get-ExactReplayString -InputObject $Checkpoint -Path @('public_fingerprint') -Context "$Context public fingerprint"
    $checkpointFingerprint = Get-ExactReplayString -InputObject $Checkpoint -Path @('checkpoint_fingerprint') -Context "$Context checkpoint fingerprint"
    $bankroll = Get-ExactReplayInt32 -InputObject $Checkpoint -Path @('bankroll') -Context "$Context bankroll"
    $chips = Get-ExactReplayInt32 -InputObject $Checkpoint -Path @('chips') -Context "$Context chips"
    $heat = Get-ExactReplayInt32 -InputObject $Checkpoint -Path @('heat') -Context "$Context heat"
    if ($schemaVersion -cne 1 -or
        $recordKind -cne 'final_public_checkpoint' -or
        $observedSeed -cne $ExpectedSeed -or
        [string]::IsNullOrWhiteSpace($outcomeKey) -or
        -not $won -or
        $publicFingerprint -cnotmatch '^[a-f0-9]{64}$' -or
        $checkpointFingerprint -cnotmatch '^[a-f0-9]{64}$' -or
        $bankroll -lt 0 -or $chips -lt 0 -or $heat -lt 0) {
        throw "$Context did not retain its exact successful public terminal values."
    }
}


function Assert-ExactReplayRunSummary {
    param(
        [AllowNull()]$Summary,
        [Parameter(Mandatory = $true)][string]$ExpectedEnding,
        [Parameter(Mandatory = $true)][string]$ExpectedSeed,
        [Parameter(Mandatory = $true)][int32]$ExpectedIteration
    )
    $context = "Replay child summary $ExpectedIteration"
    Assert-ExactReplayObjectKeys -Value $Summary -ExpectedKeys @(
        'role',
        'requested_evidence_role',
        'repeat_profile_scope',
        'fixed_repeat_qualification_authority',
        'release_qualifying',
        'qualification',
        'replay_admission',
        'iteration',
        'ending',
        'seed',
        'session',
        'passed',
        'outcome',
        'observed_terminal_seed',
        'action_count',
        'midpoint_save_relaunch_continue',
        'heist_seed_preflight',
        'heist_preflight_admission',
        'heist_launch_setup',
        'transcript',
        'transcript_sha256',
        'money_curve',
        'money_curve_sha256',
        'persistence_checkpoint_before',
        'persistence_checkpoint_before_sha256',
        'persistence_checkpoint_after',
        'persistence_checkpoint_after_sha256',
        'persistence_checkpoint_equal',
        'persistence_checkpoint_complete',
        'final_public_checkpoint',
        'failure'
    ) -Context $context
    $role = Get-ExactReplayString -InputObject $Summary -Path @('role') -Context "$context role"
    $requestedRole = Get-ExactReplayString -InputObject $Summary -Path @('requested_evidence_role') -Context "$context requested evidence role"
    $profileScope = Get-ExactReplayString -InputObject $Summary -Path @('repeat_profile_scope') -Context "$context profile scope"
    $qualificationAuthority = Get-ExactReplayString -InputObject $Summary -Path @('fixed_repeat_qualification_authority') -Context "$context qualification authority"
    $releaseQualificationValue = Get-ExactReplayBoolean -InputObject $Summary -Path @('release_qualifying') -Context "$context release qualification"
    $qualification = Get-ExactReplayString -InputObject $Summary -Path @('qualification') -Context "$context qualification label"
    $null = Get-ExactReplayPsCustomObject -InputObject $Summary -Path @('replay_admission') -Context "$context replay admission"
    $iterationValue = Get-ExactReplayInt32 -InputObject $Summary -Path @('iteration') -Context "$context iteration"
    $endingValue = Get-ExactReplayString -InputObject $Summary -Path @('ending') -Context "$context ending"
    $seedValue = Get-ExactReplayString -InputObject $Summary -Path @('seed') -Context "$context seed"
    $sessionValue = Get-ExactReplayString -InputObject $Summary -Path @('session') -Context "$context session"
    $passed = Get-ExactReplayBoolean -InputObject $Summary -Path @('passed') -Context "$context passed witness"
    $outcome = Get-ExactReplayString -InputObject $Summary -Path @('outcome') -Context "$context outcome"
    $observedSeed = Get-ExactReplayString -InputObject $Summary -Path @('observed_terminal_seed') -Context "$context terminal seed"
    $actionCount = Get-ExactReplayInt32 -InputObject $Summary -Path @('action_count') -Context "$context action count"
    $midpointSaved = Get-ExactReplayBoolean -InputObject $Summary -Path @('midpoint_save_relaunch_continue') -Context "$context midpoint witness"
    $heistPreflight = Get-ExactReplayPsCustomObject -InputObject $Summary -Path @('heist_seed_preflight') -Context "$context Heist seed preflight" -AllowNull
    $heistAdmission = Get-ExactReplayPsCustomObject -InputObject $Summary -Path @('heist_preflight_admission') -Context "$context Heist preflight admission" -AllowNull
    $heistLaunchSetup = Get-ExactReplayPsCustomObject -InputObject $Summary -Path @('heist_launch_setup') -Context "$context Heist launch setup" -AllowNull
    $transcript = Get-ExactReplayString -InputObject $Summary -Path @('transcript') -Context "$context transcript path"
    $transcriptHash = Get-ExactReplayString -InputObject $Summary -Path @('transcript_sha256') -Context "$context transcript hash"
    $moneyCurve = Get-ExactReplayString -InputObject $Summary -Path @('money_curve') -Context "$context money-curve path"
    $moneyHash = Get-ExactReplayString -InputObject $Summary -Path @('money_curve_sha256') -Context "$context money-curve hash"
    $checkpointBefore = Get-ExactReplayString -InputObject $Summary -Path @('persistence_checkpoint_before') -Context "$context pre-Continue checkpoint path"
    $checkpointBeforeHash = Get-ExactReplayString -InputObject $Summary -Path @('persistence_checkpoint_before_sha256') -Context "$context pre-Continue checkpoint hash"
    $checkpointAfter = Get-ExactReplayString -InputObject $Summary -Path @('persistence_checkpoint_after') -Context "$context post-Continue checkpoint path"
    $checkpointAfterHash = Get-ExactReplayString -InputObject $Summary -Path @('persistence_checkpoint_after_sha256') -Context "$context post-Continue checkpoint hash"
    $checkpointEqual = Get-ExactReplayBoolean -InputObject $Summary -Path @('persistence_checkpoint_equal') -Context "$context checkpoint equality witness"
    $checkpointComplete = Get-ExactReplayBoolean -InputObject $Summary -Path @('persistence_checkpoint_complete') -Context "$context checkpoint completeness witness"
    $finalCheckpoint = Get-ExactReplayPsCustomObject -InputObject $Summary -Path @('final_public_checkpoint') -Context "$context final checkpoint" -AllowNull
    $failure = Get-ExactReplayString -InputObject $Summary -Path @('failure') -Context "$context failure text"
    if ($role -cne 'child_development_iteration' -or
        $requestedRole -cnotin @('fixed-repeat', 'fresh-interactive') -or
        $profileScope -cne 'shared_caller_appdata' -or
        $qualificationAuthority -cne 'outer_independent_profile_aggregate_only' -or
        $releaseQualificationValue -or
        $qualification -cne 'non_qualifying_development_iteration' -or
        $iterationValue -cne $ExpectedIteration -or
        $endingValue -cne $ExpectedEnding -or
        $seedValue -cne $ExpectedSeed -or
        [string]::IsNullOrWhiteSpace($sessionValue) -or
        $actionCount -lt 0 -or $actionCount -gt 350) {
        throw "$context has malformed identity or qualification values."
    }
    if ($ExpectedEnding -ceq 'heist') {
        if ($null -ceq $heistPreflight -or $null -ceq $heistAdmission -or ($passed -and $null -ceq $heistLaunchSetup)) {
            throw "$context is missing its conditional Heist evidence objects."
        }
    }
    elseif ($null -cne $heistPreflight -or $null -cne $heistAdmission -or $null -cne $heistLaunchSetup) {
        throw "$context retained Heist-only evidence for a non-Heist route."
    }
    if ($passed) {
        Assert-ExactFinalPublicCheckpoint -Checkpoint $finalCheckpoint -ExpectedSeed $ExpectedSeed -Context "$context final checkpoint"
        if ([string]::IsNullOrWhiteSpace($outcome) -or
            $observedSeed -cne $ExpectedSeed -or
            -not $midpointSaved -or
            -not $checkpointEqual -or
            -not $checkpointComplete -or
            [string]::IsNullOrWhiteSpace($transcript) -or
            [string]::IsNullOrWhiteSpace($moneyCurve) -or
            [string]::IsNullOrWhiteSpace($checkpointBefore) -or
            [string]::IsNullOrWhiteSpace($checkpointAfter) -or
            $transcriptHash -cnotmatch '^[a-f0-9]{64}$' -or
            $moneyHash -cnotmatch '^[a-f0-9]{64}$' -or
            $checkpointBeforeHash -cnotmatch '^[a-f0-9]{64}$' -or
            $checkpointAfterHash -cnotmatch '^[a-f0-9]{64}$' -or
            $checkpointBeforeHash -cne $checkpointAfterHash -or
            -not [string]::IsNullOrEmpty($failure)) {
            throw "$context does not contain complete successful evidence."
        }
    }
    elseif ($null -cne $finalCheckpoint -or $failure.Length -ceq 0) {
        throw "$context has neither a successful final checkpoint nor a failure reason."
    }
    return [pscustomobject][ordered]@{
        passed = $passed
        failure = $failure
        outcome = $outcome
        observed_terminal_seed = $observedSeed
        transcript_sha256 = $transcriptHash
        money_curve_sha256 = $moneyHash
        persistence_checkpoint_before_sha256 = $checkpointBeforeHash
        persistence_checkpoint_after_sha256 = $checkpointAfterHash
        persistence_checkpoint_complete = $checkpointComplete
        final_public_checkpoint = $finalCheckpoint
    }
}


function Assert-ExactReplayFinalSummary {
    param(
        [AllowNull()]$Summary,
        [Parameter(Mandatory = $true)][string]$ExpectedEnding,
        [Parameter(Mandatory = $true)][string]$ExpectedSeed,
        [Parameter(Mandatory = $true)][int32]$ExpectedRepeat
    )
    $context = 'Replay aggregate summary'
    Assert-ExactReplayObjectKeys -Value $Summary -ExpectedKeys @(
        'schema_version',
        'check_id',
        'role',
        'requested_evidence_role',
        'repeat_profile_scope',
        'fixed_repeat_qualification_authority',
        'ending',
        'seed',
        'observed_terminal_seeds',
        'repeat',
        'deterministic',
        'checkpoint_evidence_complete',
        'release_qualifying',
        'qualification',
        'replay_admission',
        'public_observation_schema',
        'public_observation_schema_version',
        'heist_seed_preflight',
        'heist_preflight_admission',
        'evidence_root',
        'runs'
    ) -Context $context
    $schemaVersion = Get-ExactReplayInt32 -InputObject $Summary -Path @('schema_version') -Context "$context schema version"
    $checkId = Get-ExactReplayString -InputObject $Summary -Path @('check_id') -Context "$context check id"
    $role = Get-ExactReplayString -InputObject $Summary -Path @('role') -Context "$context role"
    $requestedRole = Get-ExactReplayString -InputObject $Summary -Path @('requested_evidence_role') -Context "$context requested evidence role"
    $profileScope = Get-ExactReplayString -InputObject $Summary -Path @('repeat_profile_scope') -Context "$context profile scope"
    $authority = Get-ExactReplayString -InputObject $Summary -Path @('fixed_repeat_qualification_authority') -Context "$context qualification authority"
    $endingValue = Get-ExactReplayString -InputObject $Summary -Path @('ending') -Context "$context ending"
    $seedValue = Get-ExactReplayString -InputObject $Summary -Path @('seed') -Context "$context seed"
    $observedSeeds = Get-ExactReplayObjectArray -InputObject $Summary -Path @('observed_terminal_seeds') -ElementType String -Context "$context observed terminal seeds"
    $repeatValue = Get-ExactReplayInt32 -InputObject $Summary -Path @('repeat') -Context "$context repeat count"
    $deterministicWitness = Get-ExactReplayBoolean -InputObject $Summary -Path @('deterministic') -Context "$context deterministic witness"
    $checkpointComplete = Get-ExactReplayBoolean -InputObject $Summary -Path @('checkpoint_evidence_complete') -Context "$context checkpoint completeness witness"
    $releaseQualificationValue = Get-ExactReplayBoolean -InputObject $Summary -Path @('release_qualifying') -Context "$context release qualification"
    $qualification = Get-ExactReplayString -InputObject $Summary -Path @('qualification') -Context "$context qualification label"
    $null = Get-ExactReplayPsCustomObject -InputObject $Summary -Path @('replay_admission') -Context "$context replay admission"
    $schemaName = Get-ExactReplayString -InputObject $Summary -Path @('public_observation_schema') -Context "$context public schema"
    $publicSchemaVersion = Get-ExactReplayInt32 -InputObject $Summary -Path @('public_observation_schema_version') -Context "$context public schema version"
    $heistPreflight = Get-ExactReplayPsCustomObject -InputObject $Summary -Path @('heist_seed_preflight') -Context "$context Heist seed preflight" -AllowNull
    $heistAdmission = Get-ExactReplayPsCustomObject -InputObject $Summary -Path @('heist_preflight_admission') -Context "$context Heist preflight admission" -AllowNull
    $evidenceRootValue = Get-ExactReplayString -InputObject $Summary -Path @('evidence_root') -Context "$context evidence root"
    $runs = Get-ExactReplayObjectArray -InputObject $Summary -Path @('runs') -ElementType PSCustomObject -Context "$context child runs"
    if ($schemaVersion -cne 1 -or
        $checkId -cne 'rw06_2_ending_replay' -or
        $role -cne 'child_development_run' -or
        $requestedRole -cnotin @('fixed-repeat', 'fresh-interactive') -or
        $profileScope -cne 'shared_caller_appdata' -or
        $authority -cne 'outer_independent_profile_aggregate_only' -or
        $endingValue -cne $ExpectedEnding -or
        $seedValue -cne $ExpectedSeed -or
        $repeatValue -cne $ExpectedRepeat -or
        $observedSeeds.Count -cne $ExpectedRepeat -or
        @($observedSeeds | Where-Object { $_ -cne $ExpectedSeed }).Count -cne 0 -or
        -not $checkpointComplete -or
        $releaseQualificationValue -or
        $qualification -cne 'non_qualifying_development_run' -or
        $schemaName -cne $Schema -or
        $publicSchemaVersion -cne $SchemaVersion -or
        [string]::IsNullOrWhiteSpace($evidenceRootValue) -or
        $runs.Count -cne $ExpectedRepeat) {
        throw "$context has malformed identity, schema, or qualification values."
    }
    if ($ExpectedRepeat -ceq 2 -and -not $deterministicWitness) {
        throw "$context did not retain deterministic fixed-repeat evidence."
    }
    if ($ExpectedRepeat -ceq 1 -and $deterministicWitness) {
        throw "$context mislabeled one fresh run as deterministic repeat evidence."
    }
    if ($ExpectedEnding -ceq 'heist') {
        if ($null -ceq $heistPreflight -or $null -ceq $heistAdmission) {
            throw "$context is missing its Heist preflight objects."
        }
    }
    elseif ($null -cne $heistPreflight -or $null -cne $heistAdmission) {
        throw "$context retained Heist-only evidence for a non-Heist route."
    }
    for ($index = 0; $index -lt $runs.Count; $index++) {
        $null = Assert-ExactReplayRunSummary `
            -Summary $runs[$index] `
            -ExpectedEnding $ExpectedEnding `
            -ExpectedSeed $ExpectedSeed `
            -ExpectedIteration ([int32]($index + 1))
    }
}


function Invoke-HeistSeedPreflight {
    param([Parameter(Mandatory = $true)][string]$OutputPath)

    $jsonLines = @(& $HeistSeedPreflightTool `
        -SeedText $Seed `
        -ExpectedScenario 'grand_casino_audit_night' `
        -ReportPath $OutputPath)
    if ($jsonLines.Count -ne 1) {
        throw "Heist seed preflight returned $($jsonLines.Count) output records instead of one exact JSON report."
    }
    try {
        $report = [string]$jsonLines[0] | ConvertFrom-Json
    }
    catch {
        throw "Heist seed preflight did not return valid JSON: $($_.Exception.Message)"
    }
    Assert-ExactReplayPsCustomObject -Value $report -Context 'Heist seed preflight report'
    $passed = Get-ExactReplayBoolean -InputObject $report -Path @('passed') -Context 'Heist seed preflight result'
    $reportedSeed = Get-ExactReplayString -InputObject $report -Path @('selection', 'seed_text') -Context 'Heist seed preflight seed'
    $selectedScenario = Get-ExactReplayString -InputObject $report -Path @('selection', 'selected_scenario') -Context 'Heist seed preflight scenario'
    $cycleId = Get-ExactReplayString -InputObject $report -Path @('selection', 'cycle_id') -Context 'Heist seed preflight cycle'
    if (-not $passed -or
        $reportedSeed -cne $Seed -or
        $selectedScenario -cne 'grand_casino_audit_night' -or
        [string]::IsNullOrWhiteSpace($cycleId)) {
        throw 'Heist seed preflight did not prove the exact requested seed selects Grand Casino Audit Night on the current production tree.'
    }
    $script:HeistPreflightAdmissionReceipt = Assert-Rw062HeistPreflightAdmission `
        -Admission $script:ReplayAdmission `
        -Report $report
    return $report
}


function ConvertTo-BridgeBase64Token {
    param([Parameter(Mandatory = $true)][string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw 'Bridge command tokens cannot encode blank public identities.'
    }
    return [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Value))
}


function Get-RenderedHudInteger {
    param(
        [Parameter(Mandatory = $true)][ValidateSet('bankroll', 'chips', 'heat_level')][string]$Name,
        [Parameter(Mandatory = $true)][string]$Context
    )
    $witnessName = if ($Name -ceq 'heat_level') { 'heat_rendered' } else { "${Name}_rendered" }
    $witness = Get-ExactReplayBoolean `
        -InputObject $script:LastObservation `
        -Path @('status_hud', $witnessName) `
        -Context "$Context rendered HUD $Name witness"
    $value = Get-ExactReplayInt32 `
        -InputObject $script:LastObservation `
        -Path @('status_hud', $Name) `
        -Context "$Context rendered HUD $Name value"
    if (-not $witness -or $value -lt 0) {
        throw "$Context has no exact fully rendered HUD $Name integer."
    }
    return $value
}


function Test-PublicTerminalSurface {
    $screen = Get-ExactReplayString -InputObject $script:LastObservation -Path @('screen', 'screen') -Context 'Public terminal screen'
    if ($screen -cnotin @('VICTORY', 'FAILURE')) { return $false }
    $visible = Get-ExactReplayBoolean -InputObject $script:LastObservation -Path @('screen', 'run_report_visible') -Context "Terminal RunReport visibility for '$screen'"
    if (-not $visible) {
        throw "Terminal screen '$screen' has no exact rendered RunReport witness."
    }
    return $true
}


function Assert-ReplayPauseOwnership {
    param(
        [AllowNull()]$Snapshot,
        [Parameter(Mandatory = $true)][string]$Context
    )
    Assert-ExactReplayPsCustomObject -Value $Snapshot -Context "$Context replay-pause snapshot"
    $owners = Get-ExactReplayObjectArray `
        -InputObject $Snapshot `
        -Path @('pause_owners') `
        -ElementType String `
        -Context "$Context replay-pause owners"
    $applicationPaused = Get-ExactReplayBoolean -InputObject $Snapshot -Path @('application_paused') -Context "$Context application pause witness"
    $simulationPaused = Get-ExactReplayBoolean -InputObject $Snapshot -Path @('simulation_paused') -Context "$Context simulation pause witness"
    $environmentPaused = Get-ExactReplayBoolean -InputObject $Snapshot -Path @('environment_canvas_paused') -Context "$Context environment pause witness"
    $gamePaused = Get-ExactReplayBoolean -InputObject $Snapshot -Path @('game_canvas_paused') -Context "$Context game pause witness"
    if ('agent_replay' -cnotin $owners -or
        -not $applicationPaused -or
        -not $simulationPaused -or
        -not $environmentPaused -or
        -not $gamePaused) {
        throw "Deterministic action-boundary pause ownership was absent $Context."
    }
}


function New-AnchoredSessionRoot {
    param(
        [Parameter(Mandatory = $true)][string]$Session,
        [string]$DateSegment = (Get-Date -Format 'yyyy-MM-dd')
    )
    if ($Session -notmatch '^[A-Za-z0-9_-]+$' -or $DateSegment -notmatch '^\d{4}-\d{2}-\d{2}$') {
        throw 'Cannot create an anchored session root from unsafe path segments.'
    }
    return [IO.Path]::GetFullPath((Join-Path $Worktree ".tmp\agent_playtest\$DateSegment\$Session"))
}


function New-ExclusiveEvidenceDirectory {
    param([Parameter(Mandatory = $true)][string]$Path)
    $absolutePath = [IO.Path]::GetFullPath($Path)
    $parentPath = Split-Path -Parent $absolutePath
    [void](New-Item -ItemType Directory -Path $parentPath -Force)
    if (Test-Path -LiteralPath $absolutePath) {
        throw "Evidence directory already exists; refusing stale artifact reuse: $absolutePath"
    }
    [void](New-Item -ItemType Directory -Path $absolutePath -ErrorAction Stop)
    if (-not (Test-Path -LiteralPath $absolutePath -PathType Container)) {
        throw "Evidence directory was not created as an exact directory: $absolutePath"
    }
    return $absolutePath
}


function ConvertFrom-BridgeOutput {
    param([Parameter(Mandatory = $true)][string]$Text)
    $trimmed = $Text.Trim()
    $opening = $trimmed.IndexOf('{')
    if ($opening -lt 0) {
        throw "Bridge returned no JSON object: $trimmed"
    }
    $json = $trimmed.Substring($opening)
    try {
        return $json | ConvertFrom-Json
    }
    catch {
        throw "Bridge returned malformed JSON: $($_.Exception.Message)"
    }
}


function Invoke-SessionTool {
    param(
        [Parameter(Mandatory = $true)][hashtable]$Parameters
    )
    [void](New-Item -ItemType Directory -Path $BridgeCallRoot -Force)
    $effectiveParameters = @{}
    foreach ($key in $Parameters.Keys) {
        $effectiveParameters[$key] = $Parameters[$key]
    }
    if (-not [string]::IsNullOrWhiteSpace($script:SessionRoot) -and -not $effectiveParameters.ContainsKey('SessionRoot')) {
        $effectiveParameters['SessionRoot'] = $script:SessionRoot
    }
    $bridgeToken = "$PID-$([Guid]::NewGuid().ToString('N'))"
    if ($bridgeToken -cnotmatch '^[0-9]+-[a-f0-9]{32}$') {
        throw 'Could not create a safe unique bridge-call token.'
    }
    $stdoutPath = Join-Path $BridgeCallRoot "$bridgeToken.stdout.tmp"
    $stderrPath = Join-Path $BridgeCallRoot "$bridgeToken.stderr.tmp"
    $parametersJson = $effectiveParameters | ConvertTo-Json -Compress
    $escapedSessionTool = $SessionTool.Replace("'", "''")
    $escapedParametersJson = $parametersJson.Replace("'", "''")
    $bootstrap = @"
`$ErrorActionPreference = 'Stop'
`$ProgressPreference = 'SilentlyContinue'
`$utf8 = New-Object Text.UTF8Encoding(`$false)
`$OutputEncoding = `$utf8
[Console]::OutputEncoding = `$utf8
`$sessionTool = '$escapedSessionTool'
`$parameterObject = '$escapedParametersJson' | ConvertFrom-Json
`$bridgeParameters = @{}
foreach (`$property in `$parameterObject.PSObject.Properties) {
    `$bridgeParameters[`$property.Name] = `$property.Value
}
& `$sessionTool @bridgeParameters
"@
    $encodedBootstrap = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($bootstrap))
    $declaredTimeout = 15
    if ($effectiveParameters.ContainsKey('TimeoutSeconds')) {
        $parsedTimeout = 0
        if ([int]::TryParse([string]$effectiveParameters['TimeoutSeconds'], [ref]$parsedTimeout)) {
            $declaredTimeout = [Math]::Max(1, $parsedTimeout)
        }
    }
    $deadline = (Get-Date).AddSeconds([Math]::Max(15, $declaredTimeout + 15))
    $bridgeProcess = $null
    try {
        $bridgeProcess = Start-Process -FilePath $script:PowerShellExe -ArgumentList @(
            '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
            '-OutputFormat', 'Text',
            '-EncodedCommand', $encodedBootstrap
        ) -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -WindowStyle Hidden -PassThru
        while (-not $bridgeProcess.HasExited -and (Get-Date) -lt $deadline) {
            Start-Sleep -Milliseconds 50
            $bridgeProcess.Refresh()
        }
        if (-not $bridgeProcess.HasExited) {
            Stop-Process -Id $bridgeProcess.Id -Force -ErrorAction SilentlyContinue
            throw "agent_playtest_session bridge PID $($bridgeProcess.Id) exceeded its bounded call timeout."
        }
        # HasExited is the only wait condition. This zero-duration finalization
        # makes Start-Process expose ExitCode reliably on Windows PowerShell.
        $bridgeProcess.WaitForExit()
        $bridgeProcess.Refresh()
        $bridgeExitCode = $bridgeProcess.ExitCode
        $stdoutValue = if (Test-Path -LiteralPath $stdoutPath) { Get-Content -LiteralPath $stdoutPath -Raw -Encoding utf8 } else { '' }
        $stderrValue = if (Test-Path -LiteralPath $stderrPath) { Get-Content -LiteralPath $stderrPath -Raw -Encoding utf8 } else { '' }
        $stdout = if ($null -ceq $stdoutValue) { '' } else { [string]$stdoutValue }
        $stderr = if ($null -ceq $stderrValue) { '' } else { [string]$stderrValue }
        $mergedOutput = @($stdout.Trim(), $stderr.Trim()) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        $mergedOutput = $mergedOutput -join [Environment]::NewLine
        # Some Windows PowerShell/Start-Process builds leave ExitCode unset
        # when both native streams are redirected. In that case the strict
        # stderr/stdout/JSON checks below are the authoritative result.
        if ($null -cne $bridgeExitCode -and [int]$bridgeExitCode -cne 0) {
            throw "agent_playtest_session failed with exit code $bridgeExitCode. $mergedOutput"
        }
        if (-not [string]::IsNullOrWhiteSpace($stderr)) {
            throw "agent_playtest_session emitted stderr despite exit 0. $mergedOutput"
        }
        if ([string]::IsNullOrWhiteSpace($stdout)) {
            throw 'agent_playtest_session returned no stdout.'
        }
        return $stdout
    }
    finally {
        if ($null -cne $bridgeProcess) {
            $bridgeProcess.Dispose()
        }
        Remove-Item -LiteralPath $stdoutPath -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $stderrPath -ErrorAction SilentlyContinue
    }
}


function Get-OwnedBridgeCaptureResidue {
    $ownedPattern = "^$([regex]::Escape([string]$PID))-[a-f0-9]{32}\.(?:stdout|stderr)\.tmp$"
    return @(Get-ChildItem -LiteralPath $BridgeCallRoot -File -Filter "$PID-*.tmp" -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -match $ownedPattern
    })
}


function Remove-OwnedBridgeCaptureResidue {
    # The start-only bridge can release its own capture path before Windows
    # releases a copy inherited by the live Godot child. Once that child has
    # exited, bounded retries must remove every capture owned by this runner.
    for ($attempt = 0; $attempt -lt 20; $attempt++) {
        $residue = @(Get-OwnedBridgeCaptureResidue)
        if ($residue.Count -ceq 0) { return }
        foreach ($file in $residue) {
            Remove-Item -LiteralPath $file.FullName -Force -ErrorAction SilentlyContinue
        }
        if (@(Get-OwnedBridgeCaptureResidue).Count -ceq 0) { return }
        Start-Sleep -Milliseconds 50
    }
    $paths = @(Get-OwnedBridgeCaptureResidue | ForEach-Object { $_.FullName })
    throw "Bridge capture cleanup remained locked after the host exited: $($paths -join ' | ')"
}


function Assert-NoForbiddenObservationKey {
    param(
        [AllowNull()]$Value,
        [string]$Path = 'observable'
    )
    if ($null -ceq $Value) { return }
    if ($Value -is [System.Management.Automation.PSCustomObject]) {
        foreach ($property in $Value.PSObject.Properties) {
            $name = [string]$property.Name
            if ($name -iin @(
                'run_state', 'narrative_flags', 'shoe', 'shoe_order', 'shoe_cards',
                'edge_schedule', 'trigger_context', 'scenario_layout_audit',
                'crew_heist_state', 'crew_heist_private_capsule', 'private_capsule',
                'rng_state', 'hidden_dealer_card', 'dealer_hole_card',
                'debt_items', 'debt_text', 'impact_summary', 'consequence_summary',
                'requires_confirm', 'loan_terms', 'demo_objective', 'objective_guidance',
                'next_objective', 'run_status', 'run_text'
            )) {
                throw "Private key escaped into the public observation at $Path.$name"
            }
            Assert-NoForbiddenObservationKey -Value $property.Value -Path "$Path.$name"
        }
        return
    }
    if ($Value -is [System.Collections.IDictionary]) {
        foreach ($key in $Value.Keys) {
            Assert-NoForbiddenObservationKey -Value $Value[$key] -Path "$Path.$key"
        }
        return
    }
    if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
        $index = 0
        foreach ($item in $Value) {
            Assert-NoForbiddenObservationKey -Value $item -Path "$Path[$index]"
            $index++
        }
    }
}


function Assert-HealthyResult {
    param(
        [Parameter(Mandatory = $true)]$Result,
        [Parameter(Mandatory = $true)][string]$Command
    )
    Assert-ExactReplayPsCustomObject -Value $Result -Context "Bridge result for '$Command'"
    $accepted = Get-ExactReplayBoolean -InputObject $Result -Path @('accepted') -Context "Bridge acceptance for '$Command'"
    $reason = Get-ExactReplayString -InputObject $Result -Path @('reason') -Context "Bridge rejection reason for '$Command'"
    if (-not $accepted) {
        throw "Production input was rejected for '$Command': $reason"
    }
    $pauseBefore = Get-ExactReplayPsCustomObject -InputObject $Result -Path @('replay_pause_before') -Context "Replay-pause snapshot before '$Command'"
    $pauseAfter = Get-ExactReplayPsCustomObject -InputObject $Result -Path @('look', 'replay_pause') -Context "Replay-pause snapshot after '$Command'"
    Assert-ReplayPauseOwnership -Snapshot $pauseBefore -Context "before '$Command'"
    Assert-ReplayPauseOwnership -Snapshot $pauseAfter -Context "after '$Command'"
    $alerts = Get-ExactReplayObjectArray `
        -InputObject $Result `
        -Path @('log_alerts') `
        -ElementType String `
        -Context "Godot log alerts after '$Command'"
    if ($alerts.Count -gt 0) {
        throw "Godot emitted a warning/error after '$Command': $($alerts -join ' | ')"
    }
    $pngError = Get-ExactReplayString -InputObject $Result -Path @('look', 'png_error') -Context "Screenshot result after '$Command'"
    if (-not [string]::IsNullOrWhiteSpace($pngError)) {
        throw "Screenshot capture failed after '$Command': $pngError"
    }
    $observation = Get-ExactReplayPsCustomObject `
        -InputObject $Result `
        -Path @('look', 'observable') `
        -Context "Public observation after '$Command'"
    $schemaName = Get-ExactReplayString -InputObject $observation -Path @('schema') -Context "Public observation schema after '$Command'"
    $schemaVersionValue = Get-ExactReplayInt32 -InputObject $observation -Path @('schema_version') -Context "Public observation schema version after '$Command'"
    if ($schemaName -cne $Schema -or $schemaVersionValue -cne $SchemaVersion) {
        throw "Unexpected public observation schema after '$Command'."
    }
    $privacyPolicy = Get-ExactReplayString -InputObject $observation -Path @('privacy', 'policy') -Context "Public observation privacy policy after '$Command'"
    if ($privacyPolicy -cne 'strict_allowlist') {
        throw "The bridge did not declare the strict public allowlist after '$Command'."
    }
    $trace = Get-ExactReplayPsCustomObject -InputObject $Result -Path @('trace') -Context "Public transition trace after '$Command'"
    $traceCommand = Get-ExactReplayString -InputObject $trace -Path @('command') -Context "Public transition command after '$Command'"
    $inputEmitted = Get-ExactReplayBoolean -InputObject $trace -Path @('input_emitted') -Context "Public transition input witness after '$Command'"
    if ($traceCommand -cne $Command -or -not $inputEmitted) {
        throw "The bridge did not return an authenticated public transition trace for '$Command'."
    }
    Assert-NoForbiddenObservationKey -Value $observation
    $gameId = Get-ExactReplayString -InputObject $observation -Path @('game', 'game_id') -Context "Public game id after '$Command'" -AllowMissing
    $terminalOutcomeKey = Get-ExactReplayString -InputObject $observation -Path @('checkpoint', 'terminal_outcome_key') -Context "Terminal outcome after '$Command'" -AllowMissing
    $isTerminalObservation = -not [string]::IsNullOrWhiteSpace($terminalOutcomeKey)
    $holeVisible = if ($gameId -ceq 'blackjack' -and -not $isTerminalObservation) {
        Get-ExactReplayBoolean -InputObject $observation -Path @('game', 'dealer_hole_visible') -Context "Blackjack dealer-hole witness after '$Command'"
    }
    else {
        Get-ExactReplayBoolean -InputObject $observation -Path @('game', 'dealer_hole_visible') -Context "Dealer-hole witness after '$Command'" -AllowMissing
    }
    $dealerCards = Get-ExactReplayObjectArray -InputObject $observation -Path @('game', 'dealer_cards') -ElementType PSCustomObject -Context "Public dealer cards after '$Command'"
    if ($gameId -ceq 'blackjack' -and -not $isTerminalObservation -and -not $holeVisible -and $dealerCards.Count -cne 0) {
        throw "Blackjack dealer cards escaped before the public reveal after '$Command'."
    }
}


function New-CanonicalRecord {
    param(
        [Parameter(Mandatory = $true)]$Result,
        [Parameter(Mandatory = $true)][string]$Intent
    )
    Assert-ExactReplayPsCustomObject -Value $Result -Context "Canonical result for '$Intent'"
    $observation = Get-ExactReplayPsCustomObject -InputObject $Result -Path @('look', 'observable') -Context "Canonical observation for '$Intent'"
    $checkpoint = Get-ExactReplayPsCustomObject -InputObject $observation -Path @('checkpoint') -Context "Canonical checkpoint for '$Intent'"
    $game = Get-ExactReplayPsCustomObject -InputObject $observation -Path @('game') -Context "Canonical game projection for '$Intent'"
    $event = Get-ExactReplayPsCustomObject -InputObject $observation -Path @('event_popup') -Context "Canonical event projection for '$Intent'"
    $talk = Get-ExactReplayPsCustomObject -InputObject $observation -Path @('talk') -Context "Canonical talk projection for '$Intent'"
    $feedback = Get-ExactReplayPsCustomObject -InputObject $observation -Path @('feedback') -Context "Canonical feedback projection for '$Intent'"
    $screen = Get-ExactReplayPsCustomObject -InputObject $observation -Path @('screen') -Context "Canonical screen projection for '$Intent'"
    $runReportVisible = Get-ExactReplayBoolean -InputObject $screen -Path @('run_report_visible') -Context "Canonical RunReport visibility for '$Intent'"
    $runReport = Get-ExactReplayPsCustomObject -InputObject $screen -Path @('run_report') -Context "Canonical RunReport for '$Intent'"
    $reportPresent = Test-ReplayPathPresent -InputObject $runReport -Path @('outcome') -Context "Canonical terminal projection for '$Intent'"
    if ($runReportVisible -and -not $reportPresent) {
        throw "Canonical visible RunReport for '$Intent' has no exact outcome object."
    }
    if (-not $runReportVisible -and $reportPresent) {
        throw "Canonical hidden RunReport for '$Intent' exposed an outcome object."
    }
    $report = if ($runReportVisible) {
        Get-ExactReplayPsCustomObject -InputObject $runReport -Path @('outcome') -Context "Canonical terminal projection for '$Intent'"
    }
    else {
        $null
    }
    $transition = Get-ExactReplayPsCustomObject -InputObject $Result -Path @('trace') -Context "Canonical transition for '$Intent'"
    $eventVisible = Get-ExactReplayBoolean -InputObject $event -Path @('visible') -Context "Canonical event visibility for '$Intent'"
    $eventRenderValid = Get-ExactReplayBoolean -InputObject $event -Path @('render_valid') -Context "Canonical event render witness for '$Intent'"
    $eventIdPresent = Test-ReplayPathPresent -InputObject $event -Path @('event_id') -Context "Canonical event id for '$Intent'"
    $eventChoicesPresent = Test-ReplayPathPresent -InputObject $event -Path @('choice_ids') -Context "Canonical event choices for '$Intent'"
    $eventId = Get-ExactReplayString -InputObject $event -Path @('event_id') -Context "Canonical event id for '$Intent'" -AllowMissing
    $eventChoices = Get-ExactReplayObjectArray -InputObject $event -Path @('choice_ids') -ElementType String -Context "Canonical event choices for '$Intent'" -AllowMissing
    if ($eventVisible -and $eventRenderValid -and
        (-not $eventIdPresent -or [string]::IsNullOrWhiteSpace($eventId) -or -not $eventChoicesPresent)) {
        throw "Canonical rendered event evidence for '$Intent' is incomplete."
    }
    if ((-not $eventVisible -or -not $eventRenderValid) -and ($eventIdPresent -or $eventChoicesPresent)) {
        throw "Canonical hidden or invalid event evidence for '$Intent' exposed private event fields."
    }
    $talkVisible = Get-ExactReplayBoolean -InputObject $talk -Path @('visible') -Context "Canonical talk visibility for '$Intent'"
    $talkExpanded = Get-ExactReplayBoolean -InputObject $talk -Path @('expanded') -Context "Canonical talk expansion for '$Intent'"
    $talkRenderValid = Get-ExactReplayBoolean -InputObject $talk -Path @('render_valid') -Context "Canonical talk render witness for '$Intent'"
    $talkBodyComplete = Get-ExactReplayBoolean -InputObject $talk -Path @('body_complete') -Context "Canonical talk body witness for '$Intent'"
    $talkTypewriterPresent = Test-ReplayPathPresent -InputObject $talk -Path @('typewriter_active') -Context "Canonical talk typewriter witness for '$Intent'"
    $talkTypewriterActive = Get-ExactReplayBoolean -InputObject $talk -Path @('typewriter_active') -Context "Canonical talk typewriter witness for '$Intent'" -AllowMissing
    $talkIdPresent = Test-ReplayPathPresent -InputObject $talk -Path @('event_id') -Context "Canonical talk id for '$Intent'"
    $talkChoicesPresent = Test-ReplayPathPresent -InputObject $talk -Path @('choice_ids') -Context "Canonical talk choices for '$Intent'"
    $talkId = Get-ExactReplayString -InputObject $talk -Path @('event_id') -Context "Canonical talk id for '$Intent'" -AllowMissing
    $talkChoices = Get-ExactReplayObjectArray -InputObject $talk -Path @('choice_ids') -ElementType String -Context "Canonical talk choices for '$Intent'" -AllowMissing
    if ($talkVisible -and -not $talkTypewriterPresent) {
        throw "Canonical visible talk evidence for '$Intent' has no exact typewriter witness."
    }
    if ($talkVisible -and $talkExpanded -and $talkRenderValid -and
        (-not $talkIdPresent -or [string]::IsNullOrWhiteSpace($talkId) -or -not $talkChoicesPresent)) {
        throw "Canonical rendered talk evidence for '$Intent' is incomplete."
    }
    if ((-not $talkVisible -or -not $talkExpanded -or -not $talkRenderValid) -and ($talkIdPresent -or $talkChoicesPresent)) {
        throw "Canonical hidden or invalid talk evidence for '$Intent' exposed private talk fields."
    }
    if (-not $talkVisible -and $talkTypewriterPresent) {
        throw "Canonical hidden talk evidence for '$Intent' exposed a typewriter witness."
    }
    $talkSummaryPresent = Test-ReplayPathPresent -InputObject $talk -Path @('summary') -Context "Canonical talk summary for '$Intent'"
    $talkSummary = Get-ExactReplayString -InputObject $talk -Path @('summary') -Context "Canonical talk summary for '$Intent'" -AllowMissing
    if ($talkVisible -and $talkExpanded -and $talkRenderValid -and $talkBodyComplete -and
        -not $talkTypewriterActive -and -not $talkSummaryPresent) {
        throw "Canonical complete talk evidence for '$Intent' has no exact summary."
    }
    if ((-not $talkVisible -or -not $talkExpanded -or -not $talkRenderValid -or -not $talkBodyComplete -or $talkTypewriterActive) -and $talkSummaryPresent) {
        throw "Canonical incomplete talk evidence for '$Intent' exposed a summary."
    }
    $feedbackVisible = Get-ExactReplayBoolean -InputObject $feedback -Path @('visible') -Context "Canonical feedback visibility for '$Intent'"
    $feedbackTitlePresent = Test-ReplayPathPresent -InputObject $feedback -Path @('title') -Context "Canonical feedback title for '$Intent'"
    $feedbackTextPresent = Test-ReplayPathPresent -InputObject $feedback -Path @('text') -Context "Canonical feedback text for '$Intent'"
    $feedbackTitle = Get-ExactReplayString -InputObject $feedback -Path @('title') -Context "Canonical feedback title for '$Intent'" -AllowMissing
    $feedbackText = Get-ExactReplayString -InputObject $feedback -Path @('text') -Context "Canonical feedback text for '$Intent'" -AllowMissing
    if ($feedbackVisible -and (-not $feedbackTitlePresent -or -not $feedbackTextPresent)) {
        throw "Canonical visible feedback for '$Intent' is incomplete."
    }
    if (-not $feedbackVisible -and ($feedbackTitlePresent -or $feedbackTextPresent)) {
        throw "Canonical hidden feedback for '$Intent' exposed feedback copy."
    }
    $terminalKey = if ($null -ceq $report) { '' } else { Get-ExactReplayString -InputObject $report -Path @('key') -Context "Canonical terminal key for '$Intent'" }
    $terminalWon = if ($null -ceq $report) { $false } else { Get-ExactReplayBoolean -InputObject $report -Path @('won') -Context "Canonical terminal win witness for '$Intent'" }
    return [ordered]@{
        ordinal = $script:TraceOrdinal
        intent = $Intent
        command = Get-ExactReplayString -InputObject $Result -Path @('command') -Context "Canonical command for '$Intent'"
        checkpoint = [ordered]@{
            screen = Get-ExactReplayString -InputObject $checkpoint -Path @('screen') -Context "Canonical checkpoint screen for '$Intent'"
            location_id = Get-ExactReplayString -InputObject $checkpoint -Path @('location_id') -Context "Canonical checkpoint location for '$Intent'"
            location_archetype = Get-ExactReplayString -InputObject $checkpoint -Path @('location_archetype') -Context "Canonical checkpoint archetype for '$Intent'"
            bankroll = Get-ExactReplayInt32 -InputObject $checkpoint -Path @('bankroll') -Context "Canonical checkpoint bankroll for '$Intent'"
            chips = Get-ExactReplayInt32 -InputObject $checkpoint -Path @('chips') -Context "Canonical checkpoint chips for '$Intent'"
            heat = Get-ExactReplayInt32 -InputObject $checkpoint -Path @('heat') -Context "Canonical checkpoint heat for '$Intent'"
        }
        game = [ordered]@{
            id = Get-ExactReplayString -InputObject $game -Path @('game_id') -Context "Canonical game id for '$Intent'" -AllowMissing
            phase = Get-ExactReplayString -InputObject $game -Path @('phase') -Context "Canonical game phase for '$Intent'" -AllowMissing
            outcome = Get-ExactReplayString -InputObject $game -Path @('outcome_message') -Context "Canonical game outcome for '$Intent'" -AllowMissing
            selected_stake = Get-ExactReplayInt32 -InputObject $game -Path @('selected_stake') -Context "Canonical selected stake for '$Intent'" -AllowMissing
            player_hands = Get-ExactReplayObjectArray -InputObject $game -Path @('player_hands') -ElementType PSCustomObject -Context "Canonical player hands for '$Intent'"
            dealer_up_card = Get-ExactReplayPsCustomObject -InputObject $game -Path @('dealer_up_card') -Context "Canonical dealer up-card for '$Intent'"
            dealer_hole_visible = Get-ExactReplayBoolean -InputObject $game -Path @('dealer_hole_visible') -Context "Canonical dealer-hole witness for '$Intent'" -AllowMissing
            dealer_cards = Get-ExactReplayObjectArray -InputObject $game -Path @('dealer_cards') -ElementType PSCustomObject -Context "Canonical dealer cards for '$Intent'"
            boss_hand_number = Get-ExactReplayInt32 -InputObject $game -Path @('boss_hand_number') -Context "Canonical boss hand number for '$Intent'" -AllowMissing
            boss_tell = Get-ExactReplayString -InputObject $game -Path @('boss_tell') -Context "Canonical boss tell for '$Intent'" -AllowMissing
        }
        event = [ordered]@{
            id = $eventId
            choices = $eventChoices
        }
        talk = [ordered]@{
            id = $talkId
            summary = $talkSummary
            choices = $talkChoices
        }
        feedback = [ordered]@{
            title = $feedbackTitle
            text = $feedbackText
        }
        transition = [ordered]@{
            before_fingerprint = Get-ExactReplayString -InputObject $transition -Path @('before_fingerprint') -Context "Canonical pre-transition fingerprint for '$Intent'"
            after_fingerprint = Get-ExactReplayString -InputObject $transition -Path @('after_fingerprint') -Context "Canonical post-transition fingerprint for '$Intent'"
            public_state_changed = Get-ExactReplayBoolean -InputObject $transition -Path @('public_state_changed') -Context "Canonical public-state transition for '$Intent'"
            screen_changed = Get-ExactReplayBoolean -InputObject $transition -Path @('screen_changed') -Context "Canonical screen transition for '$Intent'"
            location_changed = Get-ExactReplayBoolean -InputObject $transition -Path @('location_changed') -Context "Canonical location transition for '$Intent'"
            modal_changed = Get-ExactReplayBoolean -InputObject $transition -Path @('modal_changed') -Context "Canonical modal transition for '$Intent'"
            economy_changed = Get-ExactReplayBoolean -InputObject $transition -Path @('economy_changed') -Context "Canonical economy transition for '$Intent'"
            heat_changed = Get-ExactReplayBoolean -InputObject $transition -Path @('heat_changed') -Context "Canonical heat transition for '$Intent'"
        }
        terminal = [ordered]@{
            key = $terminalKey
            won = $terminalWon
        }
    }
}


function Write-ActionEvidence {
    param(
        [Parameter(Mandatory = $true)]$Result,
        [Parameter(Mandatory = $true)][string]$Intent
    )
    $script:TraceOrdinal++
    $script:ActionCount++
    if ($ConfirmationOnly) {
        return
    }
    $record = New-CanonicalRecord -Result $Result -Intent $Intent
    Add-Content -LiteralPath $script:TranscriptPath -Value ($record | ConvertTo-Json -Depth 40 -Compress) -Encoding utf8

    $checkpoint = $record.checkpoint
    $moneySignature = "$($checkpoint.bankroll)|$($checkpoint.chips)|$($checkpoint.heat)"
    if ($moneySignature -cne $script:LastMoneySignature) {
        $money = [ordered]@{
            action = $script:ActionCount
            intent = $Intent
            bankroll = $checkpoint.bankroll
            chips = $checkpoint.chips
            heat = $checkpoint.heat
        }
        Add-Content -LiteralPath $script:MoneyCurvePath -Value ($money | ConvertTo-Json -Compress) -Encoding utf8
        $script:LastMoneySignature = $moneySignature
    }
}


function Invoke-BridgeCommand {
    param(
        [Parameter(Mandatory = $true)][string]$Command,
        [Parameter(Mandatory = $true)][string]$Intent,
        [switch]$ObservationOnly
    )
    $output = Invoke-SessionTool -Parameters @{
        Session = $script:Session
        Command = $Command
        TimeoutSeconds = $TimeoutSeconds
    }
    $result = ConvertFrom-BridgeOutput -Text $output
    Assert-HealthyResult -Result $result -Command $Command
    $script:LastResult = $result
    $script:LastObservation = Get-Value $result @('look', 'observable') $null
    if (-not $ObservationOnly) {
        Write-ActionEvidence -Result $result -Intent $Intent
    }
    return $result
}


function Start-BridgeSession {
    param([switch]$SkipInitialLook)
    if ([string]::IsNullOrWhiteSpace($script:SessionRoot)) {
        throw "Session '$($script:Session)' has no anchored absolute session root."
    }
    $output = Invoke-SessionTool -Parameters @{
        Session = $script:Session
        Start = $true
        TimeoutSeconds = $TimeoutSeconds
    }
    $ready = ConvertFrom-BridgeOutput -Text $output
    Assert-ReplayPauseOwnership -Snapshot (Get-Value $ready @('replay_pause') $null) -Context "at session '$($script:Session)' ready"
    $status = Get-SessionStatus
    if (-not [bool](Get-Value $status @('running') $false)) {
        throw "Session '$($script:Session)' did not publish a running owned-process identity after start."
    }
    if (-not $SkipInitialLook) {
        $null = Invoke-BridgeCommand -Command 'look' -Intent 'observe the current player surface' -ObservationOnly
    }
}


function Get-SessionStatus {
    $output = Invoke-SessionTool -Parameters @{ Session = $script:Session }
    $status = ConvertFrom-BridgeOutput -Text $output
    if ([string](Get-Value $status @('session') '') -cne $script:Session) {
        throw "Session status returned the wrong owner id for '$($script:Session)'."
    }
    $reportedRoot = [string](Get-Value $status @('folder') '')
    if ([string]::IsNullOrWhiteSpace($reportedRoot) -or
        -not ([IO.Path]::GetFullPath($reportedRoot)).Equals([IO.Path]::GetFullPath($script:SessionRoot), [StringComparison]::OrdinalIgnoreCase)) {
        throw "Session status escaped the anchored root for '$($script:Session)'."
    }
    if ([bool](Get-Value $status @('running') $false)) {
        $ownedPid = [int](Get-Value $status @('pid') 0)
        $ownedStartUtcTicks = [long](Get-Value $status @('start_utc_ticks') 0L)
        $ownedExecutablePath = [string](Get-Value $status @('executable_path') '')
        if ($ownedPid -le 0 -or $ownedStartUtcTicks -le 0 -or [string]::IsNullOrWhiteSpace($ownedExecutablePath)) {
            throw "Running session '$($script:Session)' did not publish a complete owned-process identity."
        }
        if (-not ([IO.Path]::GetFullPath($ownedExecutablePath)).Equals([IO.Path]::GetFullPath($GodotBin), [StringComparison]::OrdinalIgnoreCase)) {
            throw "Running session '$($script:Session)' reported an unexpected executable path."
        }
        $script:OwnedSessionPid = $ownedPid
        $script:OwnedSessionStartUtcTicks = $ownedStartUtcTicks
        $script:OwnedSessionExecutablePath = $ownedExecutablePath
    }
    return $status
}


function Get-ExactOwnedSessionProcess {
    if ($script:OwnedSessionPid -le 0 -or $script:OwnedSessionStartUtcTicks -le 0 -or
        [string]::IsNullOrWhiteSpace($script:OwnedSessionExecutablePath)) {
        return $null
    }
    $process = Get-Process -Id $script:OwnedSessionPid -ErrorAction SilentlyContinue
    if (-not $process) { return $null }
    try {
        $actualStartUtcTicks = [long]$process.StartTime.ToUniversalTime().Ticks
        $actualExecutablePath = [IO.Path]::GetFullPath([string]$process.Path)
        $expectedExecutablePath = [IO.Path]::GetFullPath($script:OwnedSessionExecutablePath)
        if ($actualStartUtcTicks -cne $script:OwnedSessionStartUtcTicks -or
            -not $actualExecutablePath.Equals($expectedExecutablePath, [StringComparison]::OrdinalIgnoreCase)) {
            return $null
        }
        return $process
    }
    catch {
        return $null
    }
}


function Stop-ExactOwnedSessionProcess {
    $process = Get-ExactOwnedSessionProcess
    if (-not $process) { return $false }
    # PID reuse is not ownership. The exact start-time/path tuple above must
    # still match before this runner may force-stop its own Godot host.
    Stop-Process -Id $script:OwnedSessionPid -Force -ErrorAction Stop
    $deadline = (Get-Date).AddSeconds(5)
    while ((Get-Date) -lt $deadline) {
        if (-not (Get-ExactOwnedSessionProcess)) {
            return $true
        }
        Start-Sleep -Milliseconds 100
    }
    throw "Exact owned Godot PID $($script:OwnedSessionPid) remained alive after bounded force-stop."
}


function Assert-NoPostExitLogAlerts {
    if (Get-ExactOwnedSessionProcess) {
        throw "Cannot perform the final log rescan while session '$($script:Session)' is still running."
    }
    $alerts = @()
    foreach ($logName in @('godot.stdout.log', 'godot.stderr.log')) {
        $logPath = Join-Path $script:SessionRoot $logName
        if (-not (Test-Path -LiteralPath $logPath -PathType Leaf)) {
            $alerts += "$logName`: missing after process exit"
            continue
        }
        $alerts += @(Get-Content -LiteralPath $logPath -Encoding utf8 | Where-Object {
            $_ -match 'SCRIPT ERROR|(^|\s)ERROR[: ]|(^|\s)WARNING[: ]'
        } | ForEach-Object { "$logName`: $_" })
    }
    if ($alerts.Count -gt 0) {
        throw "Godot logs contained warning/error output after confirmed process exit: $($alerts -join ' | ')"
    }
}


function Stop-BridgeSessionSafely {
    param([switch]$BestEffort)
    $gracefulFailure = $null
    $logFailure = $null
    try {
        $status = Get-SessionStatus
        if ([bool](Get-Value $status @('running') $false)) {
            $null = Invoke-BridgeCommand -Command 'quit' -Intent 'close the playtest host' -ObservationOnly
            Wait-ForSessionExit
        }
    }
    catch {
        $gracefulFailure = $_
    }

    $forced = Stop-ExactOwnedSessionProcess
    if (Get-ExactOwnedSessionProcess) {
        throw "Session '$($script:Session)' retained its exact owned Godot process after cleanup."
    }
    try {
        Assert-NoPostExitLogAlerts
    }
    catch {
        $logFailure = $_
    }
    Remove-OwnedBridgeCaptureResidue

    if ($null -cne $gracefulFailure -or $null -cne $logFailure) {
        $details = @()
        if ($null -cne $gracefulFailure) { $details += "graceful=$($gracefulFailure.Exception.Message)" }
        if ($null -cne $logFailure) { $details += "post_exit_logs=$($logFailure.Exception.Message)" }
        $message = "Session '$($script:Session)' cleanup forced=$forced failed qualification: $($details -join '; ')"
        if ($BestEffort) {
            Write-Warning $message
            return
        }
        throw $message
    }
}


function Wait-ForSessionExit {
    $graceSeconds = [Math]::Min(10, [Math]::Max(1, $TimeoutSeconds))
    $deadline = (Get-Date).AddSeconds($graceSeconds)
    while ((Get-Date) -lt $deadline) {
        $status = Get-SessionStatus
        if (-not [bool](Get-Value $status @('running') $false) -and -not (Get-ExactOwnedSessionProcess)) {
            return
        }
        Start-Sleep -Milliseconds 100
    }
    throw "Session '$($script:Session)' did not exit within its bounded $graceSeconds-second graceful-close window."
}


function Refresh-Look {
    $null = Invoke-BridgeCommand -Command 'look' -Intent 'observe the current player surface' -ObservationOnly
}


function Get-Buttons {
    return @(Get-Array (Get-Value $script:LastResult @('look', 'clickable', 'buttons') @()))
}


function Find-Button {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [switch]$Contains
    )
    $matches = @()
    foreach ($button in Get-Buttons) {
        $buttonText = [string](Get-Value $button @('text') '')
        if (($Contains -and $buttonText.IndexOf($Text, [StringComparison]::OrdinalIgnoreCase) -ge 0) -or
            (-not $Contains -and $buttonText -ceq $Text)) {
            $matches += $button
        }
    }
    if ($matches.Count -gt 1) {
        throw "Visible button lookup is ambiguous for '$Text'."
    }
    if ($matches.Count -ceq 0) { return $null }
    return $matches[0]
}


function Select-UniqueFullyVisibleButton {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Buttons,
        [Parameter(Mandatory = $true)][string]$Text
    )
    $matches = @($Buttons | Where-Object {
        [string](Get-Value $_ @('text') '') -ceq $Text
    })
    if ($matches.Count -gt 1) {
        throw "Fully visible button lookup is ambiguous for '$Text'."
    }
    if ($matches.Count -ceq 0) { return $null }
    $button = $matches[0]
    $fullyVisible = Get-Value $button @('fully_visible') $null
    if ($fullyVisible -isnot [bool]) {
        throw "Public button '$Text' has no unambiguous fully_visible signal."
    }
    if (-not [bool]$fullyVisible) { return $null }
    return $button
}


function Select-UniquePublicTutorialDialogButton {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Buttons,
        [Parameter(Mandatory = $true)][ValidateSet('ok', 'cancel')][string]$Role
    )
    $expectedId = "tutorial_skip_dialog:$Role"
    $matches = @($Buttons | Where-Object {
        [string](Get-Value $_ @('surface_id') '') -ceq 'tutorial_skip_dialog' -and
        [string](Get-Value $_ @('dialog_role') '') -ceq $Role -and
        [string](Get-Value $_ @('id') '') -ceq $expectedId
    })
    if ($matches.Count -cne 1) {
        throw "Expected exactly one rendered tutorial confirmation '$Role' control at '$expectedId'; found $($matches.Count)."
    }
    $button = $matches[0]
    foreach ($signal in @('enabled', 'fully_visible', 'dialog_rendered')) {
        $value = Get-Value $button @($signal) $null
        if ($value -isnot [bool]) {
            throw "Tutorial confirmation '$Role' control has no unambiguous $signal signal."
        }
        if (-not [bool]$value) {
            throw "Tutorial confirmation '$Role' control is not publicly enabled, fully visible, and rendered."
        }
    }
    return $button
}


function Get-PublicScrollSurfaces {
    return @(Get-Array (Get-Value $script:LastResult @('look', 'clickable', 'scroll_surfaces') @()))
}


function Select-UniquePublicVerticalScrollSurface {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Surfaces,
        [Parameter(Mandatory = $true)][string]$SurfaceId,
        [Parameter(Mandatory = $true)][ValidateSet('up', 'down')][string]$Direction
    )
    if ($SurfaceId -cnotin @('run_menu', 'room_actions')) {
        throw "Unsupported public scroll surface '$SurfaceId'."
    }
    $matches = @($Surfaces | Where-Object {
        [string](Get-Value $_ @('id') '') -ceq $SurfaceId
    })
    if ($matches.Count -cne 1) {
        throw "Expected exactly one public '$SurfaceId' scroll surface; found $($matches.Count)."
    }
    $surface = $matches[0]
    $rendered = Get-Value $surface @('rendered') $null
    if ([string](Get-Value $surface @('axis') '') -cne 'vertical' -or
        $rendered -isnot [bool] -or -not [bool]$rendered) {
        throw "Public '$SurfaceId' scroll surface is not a rendered vertical control."
    }
    $capability = "can_scroll_$Direction"
    $canScroll = Get-Value $surface @($capability) $null
    if ($canScroll -isnot [bool] -or -not [bool]$canScroll) {
        throw "Public '$SurfaceId' scroll surface cannot scroll $Direction."
    }
    return $surface
}


function Reveal-ButtonByVerticalScroll {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][ValidateSet('up', 'down')][string]$Direction,
        [ValidateRange(1, 16)][int]$MaximumScrolls = 12
    )
    for ($attempt = 0; $attempt -le $MaximumScrolls; $attempt++) {
        $button = Select-UniqueFullyVisibleButton -Buttons @(Get-Buttons) -Text $Text
        if ($null -cne $button) { return $button }
        if ($attempt -ceq $MaximumScrolls) { break }
        $surface = Select-UniquePublicVerticalScrollSurface `
            -Surfaces @(Get-PublicScrollSurfaces) `
            -SurfaceId 'run_menu' `
            -Direction $Direction
        $surfaceId = [string](Get-Value $surface @('id') '')
        $null = Invoke-BridgeCommand `
            -Command "scroll_surface $surfaceId $Direction" `
            -Intent "scroll the visible run menu $Direction toward $Text"
        Wait-Frames -Frames 2
    }
    throw "Required run-menu button '$Text' did not become visible within $MaximumScrolls public scroll inputs."
}


function Click-RunMenuButton {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$Intent,
        [Parameter(Mandatory = $true)][ValidateSet('up', 'down')][string]$RevealDirection
    )
    if (-not [bool](Get-Value $script:LastObservation @('screen', 'run_menu_visible') $false)) {
        throw "Cannot click run-menu button '$Text' while the public run menu is closed."
    }
    $null = Reveal-ButtonByVerticalScroll -Text $Text -Direction $RevealDirection
    return Click-Button -Text $Text -Intent $Intent
}


function Click-Button {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$Intent,
        [switch]$Contains
    )
    $button = Find-Button -Text $Text -Contains:$Contains
    if ($null -ceq $button) {
        throw "Required visible button was not found: $Text"
    }
    $id = [string](Get-Value $button @('id') '')
    if ([string]::IsNullOrWhiteSpace($id)) {
        throw "Visible button '$Text' has no stable public id."
    }
    return Invoke-BridgeCommand -Command "click_button $id" -Intent $Intent
}


function Click-TutorialConfirmationButton {
    param(
        [Parameter(Mandatory = $true)][ValidateSet('ok', 'cancel')][string]$Role,
        [Parameter(Mandatory = $true)][string]$Intent
    )
    $button = Select-UniquePublicTutorialDialogButton -Buttons @(Get-Buttons) -Role $Role
    $id = [string](Get-Value $button @('id') '')
    $expectedId = "tutorial_skip_dialog:$Role"
    if ([string]::IsNullOrWhiteSpace($id) -or $id -cne $expectedId) {
        throw "Tutorial confirmation '$Role' control has no exact stable public id."
    }
    return Invoke-BridgeCommand -Command "click_button $id" -Intent $Intent
}


function Select-ExactRenderedCanvasObject {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Objects,
        [Parameter(Mandatory = $true)][string]$SemanticId
    )
    $matches = @($Objects | Where-Object {
        $id = Get-Value $_ @('semantic_id') $null
        $id -is [string] -and [string]$id -ceq $SemanticId
    })
    if ($matches.Count -gt 1) {
        throw "Canvas object '$SemanticId' is ambiguous."
    }
    if ($matches.Count -ceq 0) { return $null }
    $rendered = Get-Value $matches[0] @('rendered') $null
    $enabled = Get-Value $matches[0] @('enabled') $null
    if ($rendered -isnot [bool] -or $enabled -isnot [bool]) {
        throw "Canvas object '$SemanticId' has no exact rendered/enabled witnesses."
    }
    if (-not [bool]$rendered -or -not [bool]$enabled) { return $null }
    return $matches[0]
}


function Find-CanvasObject {
    param([Parameter(Mandatory = $true)][string]$SemanticId)
    return Select-ExactRenderedCanvasObject `
        -Objects @(Get-Array (Get-Value $script:LastResult @('look', 'clickable', 'canvas_objects') @())) `
        -SemanticId $SemanticId
}


function Get-RoomActions {
    return @(Get-Array (Get-Value $script:LastResult @('look', 'clickable', 'room_actions') @()))
}


function Open-SemanticObject {
    param(
        [Parameter(Mandatory = $true)][string]$SemanticId,
        [Parameter(Mandatory = $true)][string]$Intent,
        [string[]]$PreferredActions = @()
    )
    if ($null -ceq (Find-CanvasObject -SemanticId $SemanticId)) {
        throw "Required semantic object is not visible and enabled: $SemanticId"
    }
    $null = Invoke-BridgeCommand -Command "click_object $SemanticId" -Intent "focus $SemanticId"
    $enabled = @(Get-RoomActions | Where-Object {
        $enabledValue = Get-Value $_ @('enabled') $null
        $renderedValue = Get-Value $_ @('rendered') $null
        if ($enabledValue -isnot [bool] -or $renderedValue -isnot [bool]) {
            throw "Semantic object '$SemanticId' exposed a room action without exact rendered/enabled witnesses."
        }
        [bool]$enabledValue -and [bool]$renderedValue
    })
    if ($enabled.Count -ceq 0) {
        throw "Semantic object '$SemanticId' exposed no enabled player action."
    }
    $selected = $null
    foreach ($preferred in $PreferredActions) {
        $matches = @($enabled | Where-Object {
            ([string](Get-Value $_ @('id') '') -ceq $preferred) -or
            ([string](Get-Value $_ @('action') '') -ceq $preferred) -or
            ([string](Get-Value $_ @('action_id') '') -ceq $preferred) -or
            ([string](Get-Value $_ @('emit_object_id') '') -ceq $preferred) -or
            ([string](Get-Value $_ @('label') '') -ceq $preferred)
        })
        if ($matches.Count -ceq 1) {
            $selected = $matches[0]
            break
        }
        if ($matches.Count -gt 1) {
            throw "Action '$preferred' is ambiguous on '$SemanticId'."
        }
    }
    if ($null -ceq $selected -and $enabled.Count -ceq 1) {
        $selected = $enabled[0]
    }
    if ($null -ceq $selected) {
        $labels = @($enabled | ForEach-Object { [string](Get-Value $_ @('label') '') }) -join ', '
        throw "Semantic object '$SemanticId' needs an explicit action. Visible actions: $labels"
    }
    return Invoke-RoomActionRow -Row $selected -Intent $Intent
}


function Select-FirstRenderedCanvasObjectByPrefix {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Objects,
        [Parameter(Mandatory = $true)][string]$Prefix
    )
    $eligible = @()
    $seen = @{}
    foreach ($object in $Objects) {
        $semanticId = Get-Value $object @('semantic_id') $null
        if ($semanticId -isnot [string] -or -not ([string]$semanticId).StartsWith($Prefix, [StringComparison]::Ordinal)) {
            continue
        }
        if ($seen.ContainsKey([string]$semanticId)) {
            throw "Canvas prefix '$Prefix' exposes duplicate semantic id '$semanticId'."
        }
        $seen[[string]$semanticId] = $true
        $rendered = Get-Value $object @('rendered') $null
        $enabled = Get-Value $object @('enabled') $null
        if ($rendered -isnot [bool] -or $enabled -isnot [bool]) {
            throw "Canvas object '$semanticId' has no exact rendered/enabled witnesses."
        }
        if ([bool]$rendered -and [bool]$enabled) { $eligible += $object }
    }
    if ($eligible.Count -ceq 0) { return $null }
    return $eligible | Sort-Object -Property @{ Expression = { [string](Get-Value $_ @('semantic_id') '') } } -CaseSensitive | Select-Object -First 1
}


function Find-CanvasObjectByPrefix {
    param([Parameter(Mandatory = $true)][string]$Prefix)
    return Select-FirstRenderedCanvasObjectByPrefix `
        -Objects @(Get-Array (Get-Value $script:LastResult @('look', 'clickable', 'canvas_objects') @())) `
        -Prefix $Prefix
}


function Get-EventChoiceRoomAction {
    param(
        [Parameter(Mandatory = $true)][string]$EventId,
        [Parameter(Mandatory = $true)][string]$ChoiceId
    )
    $expected = "event_response:$EventId`:$ChoiceId"
    $matches = @(Get-RoomActions | Where-Object {
        ([string](Get-Value $_ @('emit_object_id') '') -ceq $expected) -or
        ([string](Get-Value $_ @('id') '') -ceq $expected) -or
        ([string](Get-Value $_ @('action') '') -ceq $expected) -or
        ([string](Get-Value $_ @('action_id') '') -ceq $expected)
    })
    if ($matches.Count -gt 1) {
        throw "Event choice '$EventId/$ChoiceId' exposed more than one room action."
    }
    if ($matches.Count -ceq 0) { return $null }
    return $matches[0]
}


function Assert-ExactRenderedRoomActionBinding {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Rows,
        [Parameter(Mandatory = $true)][string]$SelectedObjectId,
        [Parameter(Mandatory = $true)][int]$Index,
        [Parameter(Mandatory = $true)][ValidateSet('id', 'action', 'action_id', 'emit_object_id', 'label')][string]$IdentityKey,
        [Parameter(Mandatory = $true)][string]$IdentityValue
    )
    $matches = @($Rows | Where-Object {
        [string](Get-Value $_ @('selected_object_id') '') -ceq $SelectedObjectId -and
            [string](Get-Value $_ @($IdentityKey) '') -ceq $IdentityValue
    })
    if ($matches.Count -cne 1) {
        throw "Room action '$SelectedObjectId/$IdentityValue' is missing or ambiguous."
    }
    $liveIndex = Get-Value $matches[0] @('index') $null
    $liveEnabled = Get-Value $matches[0] @('enabled') $null
    $liveRendered = Get-Value $matches[0] @('rendered') $null
    if (($liveIndex -isnot [int32] -and $liveIndex -isnot [int64]) -or [long]$liveIndex -ne $Index) {
        throw "Room action '$SelectedObjectId/$IdentityValue' changed row order."
    }
    if ($liveEnabled -isnot [bool] -or $liveRendered -isnot [bool] -or
        -not [bool]$liveEnabled -or -not [bool]$liveRendered) {
        throw "Room action '$SelectedObjectId/$IdentityValue' is disabled, clipped, or lacks exact witnesses."
    }
    return $matches[0]
}


function Invoke-RoomActionRow {
    param(
        [Parameter(Mandatory = $true)]$Row,
        [Parameter(Mandatory = $true)][string]$Intent
    )
    $enabled = Get-Value $Row @('enabled') $null
    $rendered = Get-Value $Row @('rendered') $null
    if ($enabled -isnot [bool] -or $rendered -isnot [bool]) {
        throw 'Required room action has no exact rendered/enabled witnesses.'
    }
    if (-not [bool]$rendered) {
        throw 'Required room action is clipped or not fully rendered.'
    }
    if (-not [bool]$enabled) {
        $reason = [string](Get-Value $Row @('disabled_reason') 'no public reason supplied')
        throw "Required room action is disabled: $reason"
    }
    $selectedObjectId = Get-Value $Row @('selected_object_id') $null
    $indexValue = Get-Value $Row @('index') $null
    if ($selectedObjectId -isnot [string] -or [string]::IsNullOrWhiteSpace([string]$selectedObjectId) -or
        ($indexValue -isnot [int32] -and $indexValue -isnot [int64]) -or [long]$indexValue -lt 0 -or
        [long]$indexValue -gt [int]::MaxValue) {
        throw 'Visible room action has no stable selected-object identity and integral row index.'
    }
    $identityKey = ''
    $identityValue = ''
    foreach ($candidateKey in @('id', 'action', 'action_id', 'emit_object_id', 'label')) {
        $candidateValue = Get-Value $Row @($candidateKey) $null
        if ($candidateValue -is [string] -and -not [string]::IsNullOrWhiteSpace([string]$candidateValue)) {
            $identityKey = $candidateKey
            $identityValue = [string]$candidateValue
            break
        }
    }
    if ([string]::IsNullOrWhiteSpace($identityValue)) {
        throw 'Visible room action has no stable public action id or label.'
    }
    $null = Assert-ExactRenderedRoomActionBinding `
        -Rows @(Get-RoomActions) `
        -SelectedObjectId ([string]$selectedObjectId) `
        -Index ([int]$indexValue) `
        -IdentityKey $identityKey `
        -IdentityValue $identityValue
    $objectToken = ConvertTo-BridgeBase64Token -Value ([string]$selectedObjectId)
    $identityToken = ConvertTo-BridgeBase64Token -Value $identityValue
    return Invoke-BridgeCommand `
        -Command "click_action room $([int]$indexValue) $objectToken $identityKey $identityToken" `
        -Intent $Intent
}


function Select-EventObject {
    param([Parameter(Mandatory = $true)][string]$EventId)
    $semanticId = "event:$EventId"
    if ($null -ceq (Find-CanvasObject -SemanticId $semanticId)) {
        throw "Required player-facing event object is not visible: $EventId"
    }
    $null = Invoke-BridgeCommand -Command "click_object $semanticId" -Intent "focus the visible $EventId event"
}


function Invoke-EventObjectChoice {
    param(
        [Parameter(Mandatory = $true)][string]$EventId,
        [Parameter(Mandatory = $true)][string]$ChoiceId,
        [Parameter(Mandatory = $true)][string]$Intent
    )
    Select-EventObject -EventId $EventId
    if ($ChoiceId -cin @(Get-VisibleChoiceIds)) {
        $null = Choose-VisibleChoice -ChoiceId $ChoiceId -Intent $Intent
        Wait-Frames -Frames 10
        return
    }
    $row = Get-EventChoiceRoomAction -EventId $EventId -ChoiceId $ChoiceId
    if ($null -cne $row) {
        $null = Invoke-RoomActionRow -Row $row -Intent $Intent
        Wait-Frames -Frames 10
        if ($ChoiceId -cin @(Get-VisibleChoiceIds)) {
            $null = Choose-VisibleChoice -ChoiceId $ChoiceId -Intent $Intent
            Wait-Frames -Frames 10
        }
        return
    }
    $opening = @(Get-RoomActions | Where-Object {
        [bool](Get-Value $_ @('enabled') $false) -and
        [string](Get-Value $_ @('label') '') -cin @('Open', 'Talk', 'Answer', 'Respond', 'Inspect', 'Approach')
    })
    if ($opening.Count -ceq 0 -and @(Get-RoomActions).Count -ceq 1) {
        $opening = @(Get-RoomActions)
    }
    if ($opening.Count -cne 1) {
        $labels = @(Get-RoomActions | ForEach-Object { [string](Get-Value $_ @('label') '') }) -join ', '
        throw "Event '$EventId' does not expose the requested '$ChoiceId' response or one opening action. Visible actions: $labels"
    }
    $null = Invoke-RoomActionRow -Row $opening[0] -Intent "open the visible $EventId choice surface"
    Wait-Frames -Frames 8
    $null = Choose-VisibleChoice -ChoiceId $ChoiceId -Intent $Intent
    Wait-Frames -Frames 10
}


function Test-EventObjectChoiceEnabled {
    param(
        [Parameter(Mandatory = $true)][string]$EventId,
        [Parameter(Mandatory = $true)][string]$ChoiceId
    )
    Select-EventObject -EventId $EventId
    $row = Get-EventChoiceRoomAction -EventId $EventId -ChoiceId $ChoiceId
    if ($null -cne $row) {
        return [bool](Get-Value $row @('enabled') $false)
    }
    $eventChoices = @(Get-Array (Get-Value $script:LastObservation @('event_popup', 'choices') @()))
    foreach ($choice in $eventChoices) {
        if ([string](Get-Value $choice @('id') '') -ceq $ChoiceId) {
            return -not [bool](Get-Value $choice @('disabled') $false) -and [bool](Get-Value $choice @('enabled') $true)
        }
    }
    return $false
}


function Get-VisibleChoiceIds {
    $eventVisible = [bool](Get-Value $script:LastObservation @('event_popup', 'visible') $false)
    if ($eventVisible) {
        return @(Get-Array (Get-Value $script:LastObservation @('event_popup', 'choice_ids') @()))
    }
    $talkVisible = [bool](Get-Value $script:LastObservation @('talk', 'visible') $false)
    if ($talkVisible) {
        return @(Get-Array (Get-Value $script:LastObservation @('talk', 'choice_ids') @()))
    }
    return @()
}


function Get-PublicTalkChoices {
    return @(Get-Array (Get-Value $script:LastResult @('look', 'clickable', 'talk_choices') @()))
}


function Get-VisibleTutorialGuideAcknowledgment {
    $talkVisible = Get-Value $script:LastObservation @('talk', 'visible') $null
    $talkRenderValid = Get-Value $script:LastObservation @('talk', 'render_valid') $null
    if ($talkVisible -isnot [bool] -or -not [bool]$talkVisible -or
        $talkRenderValid -isnot [bool] -or -not [bool]$talkRenderValid) {
        return $null
    }
    $eventId = [string](Get-Value $script:LastObservation @('talk', 'event_id') '')
    if (-not $eventId.StartsWith('tutorial_guide:', [StringComparison]::Ordinal)) {
        return $null
    }
    $choiceIds = @(Get-VisibleChoiceIds)
    if ($choiceIds.Count -cne 1 -or [string]$choiceIds[0] -cne 'continue') {
        return $null
    }
    $rendered = @(Get-PublicTalkChoices | Where-Object {
        $enabled = Get-Value $_ @('enabled') $null
        [string](Get-Value $_ @('id') '') -ceq 'continue' -and
            $enabled -is [bool] -and [bool]$enabled
    })
    if ($rendered.Count -cne 1) {
        return $null
    }
    return $rendered[0]
}


function Assert-VisibleTalkChoiceConfirmation {
    param(
        [Parameter(Mandatory = $true)]$Observation,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$RenderedTalkChoices,
        [Parameter(Mandatory = $true)][string]$ChoiceId,
        [Parameter(Mandatory = $true)][string]$ExpectedEventId,
        [Parameter(Mandatory = $true)][string]$OriginalLabel
    )
    $eventVisible = Get-Value $Observation @('event_popup', 'visible') $null
    $talkVisible = Get-Value $Observation @('talk', 'visible') $null
    $talkRenderValid = Get-Value $Observation @('talk', 'render_valid') $null
    $eventId = Get-Value $Observation @('talk', 'event_id') $null
    if ($eventVisible -isnot [bool] -or [bool]$eventVisible -or
        $talkVisible -isnot [bool] -or -not [bool]$talkVisible -or
        $talkRenderValid -isnot [bool] -or -not [bool]$talkRenderValid -or
        $eventId -isnot [string] -or [string]$eventId -cne $ExpectedEventId) {
        throw "Choice '$ChoiceId' crossed to another rendered modal instead of arming in place."
    }
    $matches = @($RenderedTalkChoices | Where-Object {
        [string](Get-Value $_ @('id') '') -ceq $ChoiceId
    })
    if ($matches.Count -cne 1) {
        throw "Choice '$ChoiceId' did not retain one exact rendered TalkDock binding while arming."
    }
    $enabled = Get-Value $matches[0] @('enabled') $null
    $label = Get-Value $matches[0] @('label') $null
    $expectedConfirmLabel = "Confirm: $OriginalLabel"
    if ($enabled -isnot [bool] -or -not [bool]$enabled -or
        $label -isnot [string] -or [string]$label -cne $expectedConfirmLabel) {
        throw "Choice '$ChoiceId' remained visible without the exact confirmation label '$expectedConfirmLabel'."
    }
    return $true
}


function Choose-VisibleChoice {
    param(
        [Parameter(Mandatory = $true)][string]$ChoiceId,
        [Parameter(Mandatory = $true)][string]$Intent
    )
    $choices = @(Get-VisibleChoiceIds)
    if ($ChoiceId -cnotin $choices) {
        throw "Required player-facing choice '$ChoiceId' is not visible. Visible: $($choices -join ', ')"
    }
    $eventVisible = Get-Value $script:LastObservation @('event_popup', 'visible') $null
    $talkVisible = Get-Value $script:LastObservation @('talk', 'visible') $null
    if ($eventVisible -isnot [bool] -or $talkVisible -isnot [bool] -or ([bool]$eventVisible -ceq [bool]$talkVisible)) {
        throw "Choice '$ChoiceId' does not belong to exactly one rendered choice surface."
    }
    $surface = if ([bool]$eventVisible) { 'event_popup' } else { 'talk' }
    $eventId = [string](Get-Value $script:LastObservation @($surface, 'event_id') '')
    if ([string]::IsNullOrWhiteSpace($eventId)) {
        throw "Choice '$ChoiceId' has no exact rendered event binding."
    }
    $renderedChoices = if ($surface -ceq 'talk') {
        @(Get-PublicTalkChoices)
    }
    else {
        @(Get-Array (Get-Value $script:LastObservation @('event_popup', 'choices') @()))
    }
    $matches = @($renderedChoices | Where-Object { [string](Get-Value $_ @('id') '') -ceq $ChoiceId })
    if ($matches.Count -cne 1) {
        throw "Visible $surface choice '$ChoiceId' has no unique rendered button binding."
    }
    $enabled = Get-Value $matches[0] @('enabled') $null
    if ($enabled -isnot [bool] -or -not [bool]$enabled) {
        throw "Visible $surface choice '$ChoiceId' is disabled or clipped."
    }
    $label = [string](Get-Value $matches[0] @('label') '')
    if ([string]::IsNullOrWhiteSpace($label)) { throw "Choice '$ChoiceId' has no rendered label." }
    $result = Invoke-BridgeCommand -Command "click_choice $ChoiceId" -Intent $Intent

    # TalkDock visibly arms consequential choices on the first press by changing
    # the rendered label to "Confirm: ...". Some immediate service actions keep
    # the same dialogue node open after they resolve, so the choice remaining
    # visible is not by itself evidence that a second press is required.
    if ($surface -ceq 'talk' -and @(Get-VisibleChoiceIds) -ccontains $ChoiceId) {
        $remainingMatches = @(Get-PublicTalkChoices | Where-Object {
            [string](Get-Value $_ @('id') '') -ceq $ChoiceId
        })
        if ($remainingMatches.Count -cne 1) {
            throw "Choice '$ChoiceId' did not retain one exact rendered TalkDock binding after selection."
        }
        $remainingLabel = [string](Get-Value $remainingMatches[0] @('label') '')
        if ($remainingLabel -ceq "Confirm: $label") {
            $null = Assert-VisibleTalkChoiceConfirmation `
                -Observation $script:LastObservation `
                -RenderedTalkChoices @(Get-PublicTalkChoices) `
                -ChoiceId $ChoiceId `
                -ExpectedEventId $eventId `
                -OriginalLabel $label
            $result = Invoke-BridgeCommand -Command "click_choice $ChoiceId" -Intent "$Intent (confirm the visibly armed choice)"
        }
    }
    return $result
}


function Get-GameActions {
    return @(Get-Array (Get-Value $script:LastResult @('look', 'clickable', 'game_surface_actions') @()))
}


function Find-GameAction {
    param(
        [Parameter(Mandatory = $true)][string]$Action,
        [int]$Index = [int]::MinValue
    )
    $matches = @(Get-GameActions | Where-Object {
        [string](Get-Value $_ @('action') '') -ceq $Action -and
        [bool](Get-Value $_ @('enabled') $false) -and
        ($Index -ceq [int]::MinValue -or [int](Get-Value $_ @('index') 0) -ceq $Index)
    })
    if ($matches.Count -ceq 0) { return $null }
    if ($Index -ceq [int]::MinValue -and $matches.Count -gt 1) {
        return $matches | Sort-Object { [int](Get-Value $_ @('index') 0) } | Select-Object -First 1
    }
    if ($matches.Count -gt 1) {
        throw "Game action '$Action' index $Index is ambiguous."
    }
    return $matches[0]
}


function Invoke-GameAction {
    param(
        [Parameter(Mandatory = $true)][string]$Action,
        [Parameter(Mandatory = $true)][string]$Intent,
        [int]$Index = [int]::MinValue
    )
    $row = Find-GameAction -Action $Action -Index $Index
    if ($null -ceq $row) {
        throw "Required enabled game action is not visible: $Action"
    }
    $resolvedIndex = [int](Get-Value $row @('index') 0)
    return Invoke-BridgeCommand -Command "click_action $Action $resolvedIndex" -Intent $Intent
}


function Wait-Frames {
    param(
        [ValidateRange(1, 3600)][int]$Frames = 30,
        [string]$Intent = 'wait for the visible presentation to settle'
    )
    $null = Invoke-BridgeCommand -Command "wait $Frames" -Intent $Intent -ObservationOnly
}


function Clear-VisibleCoach {
    for ($attempt = 0; $attempt -lt 4; $attempt++) {
        $coachVisible = [bool](Get-Value $script:LastResult @('look', 'coach', 'visible') $false)
        if (-not $coachVisible) { return }
        $tutorialAcknowledgment = Get-VisibleTutorialGuideAcknowledgment
        if ($null -cne $tutorialAcknowledgment) {
            $label = [string](Get-Value $tutorialAcknowledgment @('label') 'Continue')
            $null = Choose-VisibleChoice -ChoiceId 'continue' -Intent "follow Pal's visible tutorial guidance: $label"
            Wait-Frames -Frames 8
            continue
        }
        $dismissLabel = [string](Get-Value $script:LastResult @('look', 'coach', 'dismiss_label') '')
        $button = $null
        if (-not [string]::IsNullOrWhiteSpace($dismissLabel)) {
            $button = Select-UniqueFullyVisibleButton -Buttons @(Get-Buttons) -Text $dismissLabel
        }
        if ($null -ceq $button) {
            $button = Select-UniqueFullyVisibleButton -Buttons @(Get-Buttons) -Text 'Skip tip'
        }
        if ($null -ceq $button) {
            throw "A visible coach card blocks the route without a fully visible public dismiss control."
        }
        $id = [string](Get-Value $button @('id') '')
        $null = Invoke-BridgeCommand -Command "click_button $id" -Intent 'dismiss the visible guidance card'
        Wait-Frames -Frames 8
    }
    if ([bool](Get-Value $script:LastResult @('look', 'coach', 'visible') $false)) {
        throw "The visible coach card did not clear after four player dismissals."
    }
}


function Normalize-HeistRunSetupControls {
    $startMenu = Get-Value $script:LastObservation @('screen', 'start_menu') $null
    $challengeId = Get-Value $startMenu @('selected_challenge_id') $null
    if ($challengeId -isnot [string]) {
        throw 'The visible Heist Run Setup has no exact selected challenge id.'
    }
    if (-not [string]::IsNullOrWhiteSpace([string]$challengeId)) {
        $null = Click-Button -Text 'Challenges' -Intent 'open the visible challenge selector for a Standard run'
        Wait-Frames -Frames 4 -Intent 'let the visible challenge selector settle'
        $null = Click-Button -Text 'Standard Run' -Intent 'select the visible Standard run option'
        Wait-Frames -Frames 4 -Intent 'let the visible Standard run selection settle'
    }

    # Run Content is built lazily. Opening this player-facing drawer makes the
    # production menu populate its own default groups when no prior selection
    # exists, while preserving the strict launch assertion as the authority.
    $null = Click-Button -Text 'RUN CONTENT' -Intent 'open the visible Run Content defaults'
    Wait-Frames -Frames 4 -Intent 'let the visible Run Content controls settle'
    if (-not [bool](Get-Value $script:LastObservation @('screen', 'start_menu', 'content_group_config_visible') $false)) {
        throw 'RUN CONTENT did not expose its visible default-content controls.'
    }
    $homeTypeId = Get-Value $script:LastObservation @('screen', 'start_menu', 'selected_home_type_id') $null
    if ($homeTypeId -isnot [string] -or [string]$homeTypeId -cne 'random') {
        throw 'The visible Heist Run Content controls did not retain the Random home selection.'
    }
    $null = Click-Button -Text 'Done' -Intent 'accept the visible default Run Content selection'
    Wait-Frames -Frames 4 -Intent 'return to the visible seeded Run Setup'
}


function Start-NormalSeededRun {
    $screen = [string](Get-Value $script:LastObservation @('screen', 'screen') '')
    if ($screen -cne 'START') {
        throw "A fresh isolated profile did not open on the start screen."
    }

    $primary = [string](Get-Value $script:LastObservation @('screen', 'start_menu', 'primary_action_text') '')
    if ($primary -ceq 'CONTINUE') {
        throw "The qualifying session is not fresh; CONTINUE was already present."
    }
    if ($primary -cne 'PLAY') {
        throw "The fresh start screen did not expose PLAY. Found '$primary'."
    }

    $replayLessonsButton = Select-UniqueFullyVisibleButton -Buttons @(Get-Buttons) -Text 'REPLAY LESSONS'
    if ($null -eq $replayLessonsButton) {
        $null = Click-Button -Text 'PLAY' -Intent 'start the mandatory first-night lesson on the fresh profile'
        Wait-Frames -Frames 30
        $lessonScreen = [string](Get-Value $script:LastObservation @('screen', 'screen') '')
        $lessonHasRun = Get-Value $script:LastObservation @('screen', 'has_run') $null
        if ($lessonHasRun -isnot [bool] -or -not [bool]$lessonHasRun -or
            $lessonScreen -cin @('START', 'VICTORY', 'FAILURE')) {
            throw "PLAY did not visibly enter a live first-night lesson (screen='$lessonScreen', has_run=$lessonHasRun)."
        }
        Clear-VisibleCoach

        $null = Click-Button -Text 'Menu' -Intent 'open the run menu to use the player-facing lesson skip'
        if (-not [bool](Get-Value $script:LastObservation @('screen', 'run_menu_visible') $false)) {
            throw 'The live first-night lesson did not render its run menu.'
        }
        $null = Click-RunMenuButton -Text 'Skip Lessons' -RevealDirection down -Intent 'request the player-facing lesson skip'
        $null = Click-TutorialConfirmationButton -Role ok -Intent 'confirm the lesson skip and return to the main menu'
        Wait-Frames -Frames 30

        if ([string](Get-Value $script:LastObservation @('screen', 'screen') '') -cne 'START' -or
            [bool](Get-Value $script:LastObservation @('screen', 'has_run') $true)) {
            throw "Skipping the mandatory lesson did not return to the start screen."
        }
        $postSkipPrimary = [string](Get-Value $script:LastObservation @('screen', 'start_menu', 'primary_action_text') '')
        if ($postSkipPrimary -ceq 'CONTINUE' -or $postSkipPrimary -cne 'PLAY') {
            throw "Lesson skip returned an unsafe start-menu primary action '$postSkipPrimary'."
        }
    }
    else {
        $replayLessonsEnabled = Get-Value $replayLessonsButton @('enabled') $null
        if ($replayLessonsEnabled -isnot [bool] -or -not [bool]$replayLessonsEnabled) {
            throw 'The rendered REPLAY LESSONS main-menu state is not unambiguously enabled.'
        }
    }
    $null = Click-Button -Text 'RUN SETUP' -Intent 'open the visible seeded-run setup' -Contains
    if ($Ending -ceq 'clean' -and
        -not [bool](Get-Value $script:LastObservation @('screen', 'start_menu', 'run_config_visible') $false)) {
        Wait-Frames -Frames 1 -Intent 'allow the visible Clean run setup action to settle'
        if (-not [bool](Get-Value $script:LastObservation @('screen', 'start_menu', 'run_config_visible') $false)) {
            $null = Click-Button -Text 'RUN SETUP' -Intent 'retry the still-visible Clean seeded-run setup' -Contains
        }
    }
    if (-not [bool](Get-Value $script:LastObservation @('screen', 'start_menu', 'run_config_visible') $false)) {
        throw 'RUN SETUP did not render the seeded-run configuration panel.'
    }
    $seedFieldReady = [bool](Get-Value $script:LastObservation @('screen', 'start_menu', 'seed_field_visible') $false) -and
        @(Get-Array (Get-Value $script:LastResult @('look', 'clickable', 'text_fields') @())).Count -gt 0
    for ($poll = 0; $poll -lt 4 -and -not $seedFieldReady; $poll++) {
        Wait-Frames -Frames 2 -Intent 'allow the visible seed field to finish rendering'
        $seedFieldReady = [bool](Get-Value $script:LastObservation @('screen', 'start_menu', 'seed_field_visible') $false) -and
            @(Get-Array (Get-Value $script:LastResult @('look', 'clickable', 'text_fields') @())).Count -gt 0
    }
    if (-not $seedFieldReady) {
        $null = Click-Button -Text 'Done' -Intent 'close the fixed first-night run setup'
        $null = Click-Button -Text 'PLAY' -Intent 'start the mandatory fixed-seed first-night lesson'
        Wait-Frames -Frames 30
        $lessonScreen = [string](Get-Value $script:LastObservation @('screen', 'screen') '')
        $lessonHasRun = Get-Value $script:LastObservation @('screen', 'has_run') $null
        if ($lessonHasRun -isnot [bool] -or -not [bool]$lessonHasRun -or
            $lessonScreen -cin @('START', 'VICTORY', 'FAILURE')) {
            throw "The fixed first-night setup did not visibly enter a live lesson (screen='$lessonScreen', has_run=$lessonHasRun)."
        }
        Clear-VisibleCoach
        $null = Click-Button -Text 'Menu' -Intent 'open the run menu to skip the fixed first-night lesson'
        if (-not [bool](Get-Value $script:LastObservation @('screen', 'run_menu_visible') $false)) {
            throw 'The fixed first-night lesson did not render its run menu.'
        }
        $null = Click-RunMenuButton -Text 'Skip Lessons' -RevealDirection down -Intent 'request the player-facing fixed first-night lesson skip'
        $null = Click-TutorialConfirmationButton -Role ok -Intent 'confirm the fixed first-night lesson skip and return to the main menu'
        Wait-Frames -Frames 30
        if ([string](Get-Value $script:LastObservation @('screen', 'screen') '') -cne 'START' -or
            [bool](Get-Value $script:LastObservation @('screen', 'has_run') $true)) {
            throw 'Skipping the fixed first-night lesson did not return to the start screen.'
        }
        $null = Click-Button -Text 'RUN SETUP' -Intent 'reopen the seeded-run setup after the fixed first-night lesson' -Contains
        $seedFieldReady = [bool](Get-Value $script:LastObservation @('screen', 'start_menu', 'seed_field_visible') $false) -and
            @(Get-Array (Get-Value $script:LastResult @('look', 'clickable', 'text_fields') @())).Count -gt 0
        for ($poll = 0; $poll -lt 4 -and -not $seedFieldReady; $poll++) {
            Wait-Frames -Frames 2 -Intent 'allow the post-lesson seed field to finish rendering'
            $seedFieldReady = [bool](Get-Value $script:LastObservation @('screen', 'start_menu', 'seed_field_visible') $false) -and
                @(Get-Array (Get-Value $script:LastResult @('look', 'clickable', 'text_fields') @())).Count -gt 0
        }
    }
    if (-not $seedFieldReady) {
        throw 'RUN SETUP did not expose its visible editable seed field.'
    }
    if ($Ending -ceq 'heist') {
        Normalize-HeistRunSetupControls
        $script:HeistLaunchSetup = Assert-HeistFreshStandardRunSetup -Observation $script:LastObservation
    }
    $null = Invoke-BridgeCommand -Command "set_field seed $Seed" -Intent "type route seed $Seed into the visible seed field"
    $visibleSeed = [string](Get-Value $script:LastObservation @('screen', 'start_menu', 'seed_text') '')
    if ($visibleSeed -cne $Seed) {
        throw "The semantic seed entry was not preserved as exact visible public evidence (found '$visibleSeed')."
    }
    $null = Click-Button -Text 'START NEW RUN' -Intent 'start the normal seeded run through the visible setup'
    Wait-Frames -Frames 45
    Clear-VisibleCoach

    $seededHasRun = Get-Value $script:LastObservation @('screen', 'has_run') $null
    if ($seededHasRun -isnot [bool] -or -not [bool]$seededHasRun) {
        throw "START NEW RUN did not produce a live run."
    }
    $seededScreen = [string](Get-Value $script:LastObservation @('screen', 'screen') '')
    if ($seededScreen -cin @('START', 'VICTORY', 'FAILURE')) {
        throw "The seeded run opened an invalid visible screen '$seededScreen'."
    }
}


function Wait-ForTravelToSettle {
    for ($attempt = 0; $attempt -lt 16; $attempt++) {
        if (-not [bool](Get-Value $script:LastObservation @('screen', 'travel_transition_active') $false)) {
            return
        }
        Wait-Frames -Frames 30
    }
    throw "The visible travel transition did not settle."
}


function Reveal-SemanticObjectByPublicRefocus {
    param([Parameter(Mandatory = $true)][string]$TargetSemanticId)
    $objects = @(Get-Array (Get-Value $script:LastResult @('look', 'clickable', 'canvas_objects') @()))
    $targetMatches = @($objects | Where-Object {
        $id = Get-Value $_ @('semantic_id') $null
        $id -is [string] -and [string]$id -ceq $TargetSemanticId
    })
    if ($targetMatches.Count -cne 1) {
        throw "The room does not expose one exact public '$TargetSemanticId' object."
    }
    $targetEnabled = Get-Value $targetMatches[0] @('enabled') $null
    $targetRendered = Get-Value $targetMatches[0] @('rendered') $null
    if ($targetEnabled -isnot [bool] -or $targetRendered -isnot [bool]) {
        throw "The public '$TargetSemanticId' object has no exact enabled/rendered witnesses."
    }
    if (-not [bool]$targetEnabled) {
        throw "The public '$TargetSemanticId' object is disabled."
    }
    if ([bool]$targetRendered) { return $true }

    $selectedId = [string](Get-Value $script:LastObservation @('room_canvas', 'selected_object_id') '')
    if (-not [string]::IsNullOrWhiteSpace($selectedId)) {
        $null = Invoke-BridgeCommand `
            -Command 'click_blank_room' `
            -Intent "click a blank part of the visible room to dismiss the $selectedId info card"
        Wait-Frames -Frames 6
        $roomSelectedId = [string](Get-Value $script:LastObservation @('room_canvas', 'selected_object_id') '')
        $spatialSelectedId = [string](Get-Value $script:LastObservation @('spatial', 'selected_object_id') '')
        if (-not [string]::IsNullOrWhiteSpace($roomSelectedId) -or
            -not [string]::IsNullOrWhiteSpace($spatialSelectedId)) {
            throw "The public blank-room click did not dismiss the selected '$selectedId' info card."
        }
        $liveTarget = @(Get-Array (Get-Value $script:LastResult @('look', 'clickable', 'canvas_objects') @()) | Where-Object {
            [string](Get-Value $_ @('semantic_id') '') -ceq $TargetSemanticId
        })
        if ($liveTarget.Count -cne 1) {
            throw "The public '$TargetSemanticId' object changed identity after dismissing the room info card."
        }
        $liveEnabled = Get-Value $liveTarget[0] @('enabled') $null
        $liveRendered = Get-Value $liveTarget[0] @('rendered') $null
        if ($liveEnabled -isnot [bool] -or $liveRendered -isnot [bool]) {
            throw "The public '$TargetSemanticId' object lost its exact witnesses after dismissing the room info card."
        }
        if ([bool]$liveEnabled -and [bool]$liveRendered) { return $true }
        $objects = @(Get-Array (Get-Value $script:LastResult @('look', 'clickable', 'canvas_objects') @()))
        $selectedId = ''
    }
    $candidates = @($objects | Where-Object {
        $semanticId = Get-Value $_ @('semantic_id') $null
        $enabled = Get-Value $_ @('enabled') $null
        $rendered = Get-Value $_ @('rendered') $null
        $semanticId -is [string] -and [string]$semanticId -cmatch '^[a-z0-9_.:-]+$' -and
            [string]$semanticId -cne $TargetSemanticId -and [string]$semanticId -cne $selectedId -and
            $enabled -is [bool] -and [bool]$enabled -and
            $rendered -is [bool] -and [bool]$rendered
    } | Sort-Object { [string](Get-Value $_ @('semantic_id') '') } -CaseSensitive | Select-Object -First 12)
    foreach ($candidate in $candidates) {
        $semanticId = [string](Get-Value $candidate @('semantic_id') '')
        $null = Invoke-BridgeCommand -Command "click_object $semanticId" -Intent "move the visible room focus so its card no longer covers $TargetSemanticId"
        Wait-Frames -Frames 6
        if ([bool](Get-Value $script:LastObservation @('event_popup', 'visible') $false) -or
            [bool](Get-Value $script:LastObservation @('talk', 'visible') $false)) {
            throw "A single room-focus click unexpectedly opened a blocking modal while uncovering '$TargetSemanticId'."
        }
        $liveTarget = @(Get-Array (Get-Value $script:LastResult @('look', 'clickable', 'canvas_objects') @()) | Where-Object {
            [string](Get-Value $_ @('semantic_id') '') -ceq $TargetSemanticId
        })
        if ($liveTarget.Count -cne 1) {
            throw "The public '$TargetSemanticId' object changed identity while uncovering it."
        }
        $liveEnabled = Get-Value $liveTarget[0] @('enabled') $null
        $liveRendered = Get-Value $liveTarget[0] @('rendered') $null
        if ($liveEnabled -isnot [bool] -or $liveRendered -isnot [bool]) {
            throw "The public '$TargetSemanticId' object lost its exact witnesses while uncovering it."
        }
        if ([bool]$liveEnabled -and [bool]$liveRendered) { return $true }
    }
    return $false
}


function Reveal-WorldMapLeaveByPublicRefocus {
    if (-not (Reveal-SemanticObjectByPublicRefocus -TargetSemanticId 'travel:leave')) {
        throw 'No bounded real room-focus click made the public Leave target fully visible.'
    }
}


function Open-OverflowWorldMapIfVisible {
    $launcher = Find-Button -Text 'More room actions' -Contains
    if ($null -ceq $launcher) {
        return $false
    }
    $launcherId = [string](Get-Value $launcher @('id') '')
    if ([string]::IsNullOrWhiteSpace($launcherId)) {
        throw 'The visible More room actions launcher has no public button id.'
    }
    $null = Invoke-BridgeCommand -Command "click_button $launcherId" -Intent 'open the visible list of room actions'
    Wait-Frames -Frames 2
    $mapButton = $null
    for ($attempt = 0; $attempt -le 48; $attempt++) {
        $mapButtons = @(Get-Buttons | Where-Object {
            $text = [string](Get-Value $_ @('text') '')
            $text -ceq 'Open Map' -or $text.EndsWith(': Open Map', [StringComparison]::Ordinal)
        })
        if ($mapButtons.Count -gt 1) {
            throw "The room action list exposes more than one visible Open Map action."
        }
        if ($mapButtons.Count -ceq 1 -and
            (Get-Value $mapButtons[0] @('fully_visible') $null) -is [bool] -and
            [bool](Get-Value $mapButtons[0] @('fully_visible') $false)) {
            Wait-Frames -Frames 12 -Intent 'let the visible room-action scroll settle before selecting Open Map'
            $settledMapButtons = @(Get-Buttons | Where-Object {
                $text = [string](Get-Value $_ @('text') '')
                $text -ceq 'Open Map' -or $text.EndsWith(': Open Map', [StringComparison]::Ordinal)
            })
            if ($settledMapButtons.Count -ceq 1 -and
                (Get-Value $settledMapButtons[0] @('fully_visible') $null) -is [bool] -and
                [bool](Get-Value $settledMapButtons[0] @('fully_visible') $false)) {
                $mapButton = $settledMapButtons[0]
                break
            }
        }
        if ($attempt -ceq 48) { break }
        $surfaces = @(Get-PublicScrollSurfaces)
        $roomSurface = @($surfaces | Where-Object {
            [string](Get-Value $_ @('id') '') -ceq 'room_actions'
        })
        if ($roomSurface.Count -cne 1) {
            throw "Expected exactly one visible room-actions scroll surface; found $($roomSurface.Count)."
        }
        $canDown = Get-Value $roomSurface[0] @('can_scroll_down') $null
        $canUp = Get-Value $roomSurface[0] @('can_scroll_up') $null
        if ($canDown -isnot [bool] -or $canUp -isnot [bool]) {
            throw 'The visible room-actions scroll surface lost its directional signals.'
        }
        $direction = if ([bool]$canDown) { 'down' } elseif ($mapButtons.Count -ceq 1 -and [bool]$canUp) { 'up' } else { '' }
        if ([string]::IsNullOrWhiteSpace($direction)) {
            break
        }
        $surface = Select-UniquePublicVerticalScrollSurface `
            -Surfaces $surfaces `
            -SurfaceId 'room_actions' `
            -Direction $direction
        $null = Invoke-BridgeCommand `
            -Command "scroll_surface room_actions $direction" `
            -Intent "scroll the visible room action list $direction toward Open Map"
        Wait-Frames -Frames 12 -Intent 'let the visible room-action scroll settle'
    }
    if ($null -ceq $mapButton) {
        throw 'The visible room action list did not expose a stable, fully visible Open Map control within forty-eight scroll inputs.'
    }
    $fullyVisible = Get-Value $mapButton @('fully_visible') $null
    $enabled = Get-Value $mapButton @('enabled') $null
    if ($fullyVisible -isnot [bool] -or -not [bool]$fullyVisible -or
        $enabled -isnot [bool] -or -not [bool]$enabled) {
        throw 'The room action list Open Map control is not fully visible and enabled.'
    }
    $mapButtonId = [string](Get-Value $mapButton @('id') '')
    if ([string]::IsNullOrWhiteSpace($mapButtonId)) {
        throw 'The room action list Open Map control has no public button id.'
    }
    $null = Invoke-BridgeCommand -Command "click_button $mapButtonId" -Intent 'open the city map from the visible room action list'
    Wait-Frames -Frames 8
    return $true
}


function Invoke-OverflowRoomActionButton {
    param(
        [Parameter(Mandatory = $true)][string]$ButtonText,
        [Parameter(Mandatory = $true)][string]$Intent
    )
    $launcher = Find-Button -Text 'More room actions' -Contains
    if ($null -ceq $launcher) {
        throw "The room does not expose More room actions while '$ButtonText' is needed."
    }
    $launcherId = [string](Get-Value $launcher @('id') '')
    if ([string]::IsNullOrWhiteSpace($launcherId)) {
        throw 'The visible More room actions launcher has no public button id.'
    }
    $null = Invoke-BridgeCommand -Command "click_button $launcherId" -Intent 'open the visible list of room actions'
    Wait-Frames -Frames 2

    # The overlay normally opens at its top, but it may retain a prior scroll
    # offset. Search to the bottom first, then reverse once if necessary.
    $direction = 'down'
    for ($attempt = 0; $attempt -le 32; $attempt++) {
        $matches = @(Get-Buttons | Where-Object {
            [string](Get-Value $_ @('text') '') -ceq $ButtonText
        })
        if ($matches.Count -gt 1) {
            throw "The room action list exposes more than one '$ButtonText' action."
        }
        if ($matches.Count -ceq 1 -and
            (Get-Value $matches[0] @('fully_visible') $null) -is [bool] -and
            [bool](Get-Value $matches[0] @('fully_visible') $false)) {
            Wait-Frames -Frames 12 -Intent "let the visible room-action scroll settle before selecting $ButtonText"
            $settled = @(Get-Buttons | Where-Object {
                [string](Get-Value $_ @('text') '') -ceq $ButtonText
            })
            if ($settled.Count -ceq 1 -and
                (Get-Value $settled[0] @('fully_visible') $null) -is [bool] -and
                [bool](Get-Value $settled[0] @('fully_visible') $false)) {
                $enabled = Get-Value $settled[0] @('enabled') $null
                if ($enabled -isnot [bool] -or -not [bool]$enabled) {
                    throw "The fully visible room action '$ButtonText' is not enabled."
                }
                $buttonId = [string](Get-Value $settled[0] @('id') '')
                if ([string]::IsNullOrWhiteSpace($buttonId)) {
                    throw "The fully visible room action '$ButtonText' has no public button id."
                }
                return Invoke-BridgeCommand -Command "click_button $buttonId" -Intent $Intent
            }
        }
        if ($attempt -ceq 32) { break }

        $surfaces = @(Get-PublicScrollSurfaces)
        $roomSurface = @($surfaces | Where-Object {
            [string](Get-Value $_ @('id') '') -ceq 'room_actions'
        })
        if ($roomSurface.Count -cne 1) {
            throw "Expected exactly one visible room-actions scroll surface; found $($roomSurface.Count)."
        }
        $canDown = Get-Value $roomSurface[0] @('can_scroll_down') $null
        $canUp = Get-Value $roomSurface[0] @('can_scroll_up') $null
        if ($canDown -isnot [bool] -or $canUp -isnot [bool]) {
            throw 'The visible room-actions scroll surface lost its directional signals.'
        }
        if ($direction -ceq 'down' -and -not [bool]$canDown) {
            if (-not [bool]$canUp) { break }
            $direction = 'up'
        }
        elseif ($direction -ceq 'up' -and -not [bool]$canUp) {
            break
        }
        $null = Select-UniquePublicVerticalScrollSurface `
            -Surfaces $surfaces `
            -SurfaceId 'room_actions' `
            -Direction $direction
        $null = Invoke-BridgeCommand `
            -Command "scroll_surface room_actions $direction" `
            -Intent "scroll the visible room action list $direction toward $ButtonText"
        Wait-Frames -Frames 12 -Intent 'let the visible room-action scroll settle'
    }
    throw "The visible room action list did not expose a stable, fully visible '$ButtonText' control."
}


function Open-WorldMap {
    if ([bool](Get-Value $script:LastObservation @('screen', 'world_map_overlay_visible') $false)) {
        return
    }
    Clear-VisibleCoach
    $leaveObjects = @(Get-Array (Get-Value $script:LastResult @('look', 'clickable', 'canvas_objects') @()) | Where-Object {
        [string](Get-Value $_ @('semantic_id') '') -ceq 'travel:leave'
    })
    if ($leaveObjects.Count -ceq 0) {
        if (-not (Open-OverflowWorldMapIfVisible)) {
            throw 'The room exposes neither a canvas Leave object nor a visible room-list Open Map action.'
        }
    }
    else {
        Reveal-WorldMapLeaveByPublicRefocus
        $null = Open-SemanticObject -SemanticId 'travel:leave' -PreferredActions @('Open Map') -Intent 'open the visible city map'
        Wait-Frames -Frames 8
    }
    if (-not [bool](Get-Value $script:LastObservation @('screen', 'world_map_overlay_visible') $false)) {
        throw "The world map did not become visible."
    }
}


function Get-MapNodes {
    return @(Get-Array (Get-Value $script:LastObservation @('screen', 'world_map', 'nodes') @()))
}


function Find-MapNode {
    param([Parameter(Mandatory = $true)][string]$NodeId)
    foreach ($node in Get-MapNodes) {
        if ([string](Get-Value $node @('id') '') -ceq $NodeId) { return $node }
    }
    return $null
}


function Assert-DeltaQueenBeachRouteInvariant {
    $archetypeId = [string](Get-Value $script:LastObservation @('environment', 'archetype_id') '')
    if ($archetypeId -cne 'delta_queen') { return }
    Open-WorldMap
    try {
        $null = Assert-DeltaQueenBeachPublicRoute -ArchetypeId $archetypeId -MapNodes @(Get-MapNodes)
    }
    finally {
        Close-WorldMap
    }
}


function Travel-ToNode {
    param(
        [Parameter(Mandatory = $true)][string]$NodeId,
        [Parameter(Mandatory = $true)][string]$Intent
    )
    Open-WorldMap
    $node = Find-MapNode -NodeId $NodeId
    if ($null -ceq $node) {
        throw "World-map destination is not player-visible: $NodeId"
    }
    if (-not [bool](Get-Value $node @('travel_enabled') $false)) {
        $reason = [string](Get-Value $node @('travel_disabled_reason') 'route unavailable')
        throw "World-map destination '$NodeId' is not travel-enabled: $reason"
    }
    $null = Invoke-BridgeCommand -Command "click_map $NodeId" -Intent "select $NodeId on the visible city map"
    if (-not [bool](Get-Value $script:LastObservation @('screen', 'world_map_confirm_enabled') $false)) {
        throw "Selecting '$NodeId' did not enable the visible Travel control."
    }
    $null = Click-Button -Text 'Travel' -Intent $Intent
    Wait-ForTravelToSettle
    Wait-Frames -Frames 12
    $arrived = [string](Get-Value $script:LastObservation @('environment', 'world_node_id') '')
    if ($arrived -cne $NodeId) {
        throw "Travel to '$NodeId' resolved at '$arrived'."
    }
    Clear-VisibleCoach
    Assert-DeltaQueenBeachRouteInvariant
}


function Close-WorldMap {
    if (-not [bool](Get-Value $script:LastObservation @('screen', 'world_map_overlay_visible') $false)) { return }
    $null = Click-Button -Text 'Close' -Intent 'close the visible city map'
    Wait-Frames -Frames 6
    if ($Ending -ceq 'clean' -and [bool](Get-Value $script:LastObservation @('screen', 'world_map_overlay_visible') $false)) {
        # The Clean route can reopen the map immediately after travel. If the
        # first accepted press lands while that surface is settling, retry the
        # still-visible public control once before treating it as a dead end.
        $null = Click-Button -Text 'Close' -Intent 'close the still-visible city map'
        Wait-Frames -Frames 6
    }
    if ([bool](Get-Value $script:LastObservation @('screen', 'world_map_overlay_visible') $false)) {
        throw 'The visible city map did not close.'
    }
}


function Get-MapEdges {
    return @(Get-Array (Get-Value $script:LastObservation @('screen', 'world_map', 'edges') @()))
}


function Get-PublicGraphDistance {
    param(
        [Parameter(Mandatory = $true)][string]$From,
        [Parameter(Mandatory = $true)][string]$To
    )
    if ($From -ceq $To) { return 0 }
    $adjacency = @{}
    foreach ($edge in Get-MapEdges) {
        if (-not [bool](Get-Value $edge @('enabled') $true)) { continue }
        $a = [string](Get-Value $edge @('a') '')
        $b = [string](Get-Value $edge @('b') '')
        if ([string]::IsNullOrWhiteSpace($a) -or [string]::IsNullOrWhiteSpace($b)) { continue }
        if (-not $adjacency.ContainsKey($a)) { $adjacency[$a] = @() }
        if (-not $adjacency.ContainsKey($b)) { $adjacency[$b] = @() }
        $adjacency[$a] = @($adjacency[$a]) + $b
        $adjacency[$b] = @($adjacency[$b]) + $a
    }
    $queue = New-Object 'System.Collections.Generic.Queue[object]'
    $queue.Enqueue(@($From, 0))
    $seen = @{$From = $true}
    while ($queue.Count -gt 0) {
        $entry = @($queue.Dequeue())
        $node = [string]$entry[0]
        $distance = [int]$entry[1]
        foreach ($neighborValue in @($adjacency[$node])) {
            $neighbor = [string]$neighborValue
            if ($neighbor -ceq $To) { return $distance + 1 }
            if ($seen.ContainsKey($neighbor)) { continue }
            $seen[$neighbor] = $true
            $queue.Enqueue(@($neighbor, ($distance + 1)))
        }
    }
    return [int]::MaxValue
}


function Navigate-ToNode {
    param(
        [Parameter(Mandatory = $true)][string]$NodeId,
        [Parameter(Mandatory = $true)][string]$Intent,
        [ValidateRange(1, 24)][int]$MaxLegs = 14
    )
    for ($leg = 0; $leg -lt $MaxLegs; $leg++) {
        $current = [string](Get-Value $script:LastObservation @('environment', 'world_node_id') '')
        if ($current -ceq $NodeId) { return }
        Open-WorldMap
        $target = Find-MapNode -NodeId $NodeId
        if ($null -ceq $target) {
            throw "World-map destination is not player-visible: $NodeId"
        }
        if ([bool](Get-Value $target @('travel_enabled') $false)) {
            Travel-ToNode -NodeId $NodeId -Intent $Intent
            continue
        }
        $enabled = @(Get-MapNodes | Where-Object {
            [bool](Get-Value $_ @('travel_enabled') $false) -and
            [string](Get-Value $_ @('id') '') -cne $current
        })
        if ($enabled.Count -ceq 0) {
            $reason = [string](Get-Value $target @('travel_disabled_reason') 'no public route is enabled')
            throw "No visible next map leg can reach '$NodeId': $reason"
        }
        $ranked = @($enabled | ForEach-Object {
            $candidateId = [string](Get-Value $_ @('id') '')
            [pscustomobject]@{
                node = $_
                distance = Get-PublicGraphDistance -From $candidateId -To $NodeId
                cost = [int](Get-Value $_ @('cost') 0)
                id = $candidateId
            }
        } | Sort-Object distance, cost, id)
        if ($ranked.Count -ceq 0 -or [int]$ranked[0].distance -ceq [int]::MaxValue) {
            throw "The public map graph has no visible path from '$current' to '$NodeId'."
        }
        $nextId = [string]$ranked[0].id
        Travel-ToNode -NodeId $nextId -Intent "$Intent (public route leg $($leg + 1) via $nextId)"
    }
    throw "The public map route did not reach '$NodeId' within $MaxLegs legs."
}


function Get-DeliveryTargetNodeId {
    Open-WorldMap
    $targets = @(Get-MapNodes | Where-Object {
        [bool](Get-Value $_ @('delivery_target') $false) -and
        [string](Get-Value $_ @('delivery_target_status') 'pending') -cne 'delivered'
    })
    $targetId = ''
    if ($targets.Count -gt 1) {
        Close-WorldMap
        throw 'The public delivery overlay exposed more than one active target for a single-stop route.'
    }
    if ($targets.Count -ceq 1) {
        $targetId = [string](Get-Value $targets[0] @('id') '')
    }
    Close-WorldMap
    return $targetId
}


function Get-FirstEnabledVisibleChoiceId {
    $eventVisible = [bool](Get-Value $script:LastObservation @('event_popup', 'visible') $false)
    if ($eventVisible) {
        $choices = @(Get-Array (Get-Value $script:LastObservation @('event_popup', 'choices') @()))
        foreach ($preferred in @('continue', 'acknowledge', 'move_on', 'keep_moving', 'leave', 'pocket', 'done')) {
            foreach ($choice in $choices) {
                $id = [string](Get-Value $choice @('id') '')
                $enabledProperty = $choice.PSObject.Properties['enabled']
                $enabled = -not [bool](Get-Value $choice @('disabled') $false) -and
                    ($null -ceq $enabledProperty -or [bool]$enabledProperty.Value)
                if ($enabled -and $id -ceq $preferred) { return $id }
            }
        }
        foreach ($choice in $choices) {
            $id = [string](Get-Value $choice @('id') '')
            $enabledProperty = $choice.PSObject.Properties['enabled']
            $enabled = -not [bool](Get-Value $choice @('disabled') $false) -and
                ($null -ceq $enabledProperty -or [bool]$enabledProperty.Value)
            if ($enabled -and -not [string]::IsNullOrWhiteSpace($id)) { return $id }
        }
        return ''
    }
    $talkVisible = [bool](Get-Value $script:LastObservation @('talk', 'visible') $false)
    if ($talkVisible) {
        $choices = @(Get-PublicTalkChoices | Where-Object {
            [bool](Get-Value $_ @('enabled') $false) -and
            -not [string]::IsNullOrWhiteSpace([string](Get-Value $_ @('id') ''))
        })
        foreach ($preferred in @('continue', 'acknowledge', 'move_on', 'keep_moving', 'leave', 'done')) {
            if (@($choices | Where-Object { [string](Get-Value $_ @('id') '') -ceq $preferred }).Count -ceq 1) {
                return $preferred
            }
        }
        if ($choices.Count -gt 0) { return [string](Get-Value $choices[0] @('id') '') }
    }
    return ''
}


function Resolve-VisibleBlockingPresentation {
    param([Parameter(Mandatory = $true)][string]$Context)
    :presentation for ($attempt = 0; $attempt -lt 12; $attempt++) {
        Clear-VisibleCoach
        $eventVisible = [bool](Get-Value $script:LastObservation @('event_popup', 'visible') $false)
        $talkVisible = [bool](Get-Value $script:LastObservation @('talk', 'visible') $false)
        if (-not $eventVisible -and -not $talkVisible) { return }

        $choiceId = Get-FirstEnabledVisibleChoiceId
        if (-not [string]::IsNullOrWhiteSpace($choiceId)) {
            $surfaceId = if ($eventVisible) {
                [string](Get-Value $script:LastObservation @('event_popup', 'event_id') 'event')
            }
            else {
                [string](Get-Value $script:LastObservation @('talk', 'event_id') 'talk')
            }
            $null = Choose-VisibleChoice -ChoiceId $choiceId -Intent "$Context`: resolve the visible $surfaceId beat with $choiceId"
            Wait-Frames -Frames 10
            continue
        }

        # Presentation-only cards and item toasts can own the overlay briefly
        # without publishing a choice. A player can only wait for that rendered
        # window or use its explicit close control.
        foreach ($label in @('Close', 'Back', 'OK')) {
            if ($null -cne (Find-Button -Text $label)) {
                $null = Click-Button -Text $label -Intent "$Context`: close the visible presentation card"
                Wait-Frames -Frames 8
                continue presentation
            }
        }
        Wait-Frames -Frames 210 -Intent "$Context`: wait for the visible presentation-only beat"
        if ([bool](Get-Value $script:LastObservation @('event_popup', 'visible') $false) -or
            [bool](Get-Value $script:LastObservation @('talk', 'visible') $false)) {
            throw "$Context is blocked by a visible choice surface with no enabled public response."
        }
        return
    }
    throw "$Context did not clear its visible blocking presentation within twelve public responses."
}


function Complete-PublicDelivery {
    param(
        [Parameter(Mandatory = $true)][string]$Intent,
        [ValidateSet('', 'main', 'cage')][string]$GrandRoom = ''
    )
    Wait-Frames -Frames 8
    Resolve-VisibleBlockingPresentation -Context $Intent
    $pickup = Find-CanvasObjectByPrefix -Prefix 'delivery:pickup:'
    if ($null -cne $pickup) {
        $pickupId = [string](Get-Value $pickup @('semantic_id') '')
        $null = Open-SemanticObject -SemanticId $pickupId -Intent "${Intent}: take the visible package"
        Wait-Frames -Frames 10
    }

    $targetSeen = $false
    for ($step = 0; $step -lt 24; $step++) {
        if (Test-PublicTerminalSurface) { return }
        Resolve-VisibleBlockingPresentation -Context $Intent
        $targetId = Get-DeliveryTargetNodeId
        if ([string]::IsNullOrWhiteSpace($targetId)) {
            if ($targetSeen) { return }
            throw "$Intent exposed no active target on the player-visible map."
        }
        $targetSeen = $true

        $currentNodeId = [string](Get-Value $script:LastObservation @('environment', 'world_node_id') '')
        if ($currentNodeId -cne $targetId) {
            Navigate-ToNode -NodeId $targetId -Intent "${Intent}: follow the marked real-map route"
            Wait-Frames -Frames 10
            continue
        }
        if (-not [string]::IsNullOrWhiteSpace($GrandRoom) -and $targetId -ceq 'grand_casino') {
            Enter-GrandRoom -Room $GrandRoom
            Resolve-VisibleBlockingPresentation -Context $Intent
        }

        $handoff = Find-CanvasObjectByPrefix -Prefix 'delivery:handoff:'
        if ($null -ceq $handoff) {
            $handoff = Find-CanvasObject -SemanticId 'crew::package_handoff'
        }
        if ($null -cne $handoff) {
            $handoffId = [string](Get-Value $handoff @('semantic_id') '')
            $null = Open-SemanticObject -SemanticId $handoffId -Intent "${Intent}: make the visible handoff"
            Wait-Frames -Frames 12
            Resolve-VisibleBlockingPresentation -Context $Intent
            $remainingTarget = Get-DeliveryTargetNodeId
            if ([string]::IsNullOrWhiteSpace($remainingTarget)) { return }
            if ($remainingTarget -ceq $targetId -and
                ($null -cne (Find-CanvasObjectByPrefix -Prefix 'delivery:handoff:') -or
                 $null -cne (Find-CanvasObject -SemanticId 'crew::package_handoff'))) {
                throw "$Intent left the same visible handoff and map marker active after the handoff click."
            }
            continue
        }
        $spatialHandoffs = @(Get-Array (Get-Value $script:LastObservation @('spatial', 'objects') @()) | Where-Object {
            [string](Get-Value $_ @('object_id') '') -ceq 'crew::package_handoff' -and
            [bool](Get-Value $_ @('visible') $false) -and
            [bool](Get-Value $_ @('enabled') $false)
        })
        if ($spatialHandoffs.Count -gt 1) {
            throw "$Intent exposed more than one public Crew handoff contact."
        }
        if ($spatialHandoffs.Count -ceq 1) {
            # A full room can present the authenticated person through the visible
            # room-actions grid instead of the canvas. This is the same normal-use
            # interaction surface, and the no-scroll layout exposes the complete
            # labeled action without hidden state or a debug shortcut.
            $null = Invoke-OverflowRoomActionButton `
                -ButtonText 'The Floor Contact: Hand Over The Package' `
                -Intent "${Intent}: hand the package to the visible room contact"
            Wait-Frames -Frames 12
            Resolve-VisibleBlockingPresentation -Context $Intent
            $remainingTarget = Get-DeliveryTargetNodeId
            if ([string]::IsNullOrWhiteSpace($remainingTarget)) { return }
            if ($remainingTarget -ceq $targetId) {
                throw "$Intent left the same visible room-action handoff and map marker active after selection."
            }
            continue
        }
        if ($null -cne (Find-Button -Text 'Hold Sightline')) {
            $null = Click-Button -Text 'Hold Sightline' -Intent "${Intent}: hold the marked sightline"
            Wait-Frames -Frames 8
            continue
        }
        if ($null -cne (Find-Button -Text 'Send Signal')) {
            $null = Click-Button -Text 'Send Signal' -Intent "${Intent}: send the visible route signal"
            Wait-Frames -Frames 8
            continue
        }
        $overflowDeliveryActions = @(
            @{ Verb = 'wait'; Label = 'Hold Sightline'; Intent = "${Intent}: hold the marked sightline through the visible room-action list" },
            @{ Verb = 'signal'; Label = 'Send Signal'; Intent = "${Intent}: send the route signal through the visible room-action list" }
        )
        $overflowDeliveryHandled = $false
        foreach ($deliveryAction in $overflowDeliveryActions) {
            $objectId = "delivery:$([string]$deliveryAction.Verb):$currentNodeId"
            $spatialActions = @(Get-Array (Get-Value $script:LastObservation @('spatial', 'objects') @()) | Where-Object {
                [string](Get-Value $_ @('object_id') '') -ceq $objectId
            })
            if ($spatialActions.Count -gt 1) {
                throw "$Intent exposed duplicate public $([string]$deliveryAction.Label) delivery controls."
            }
            if ($spatialActions.Count -ceq 0) { continue }
            if ([string](Get-Value $spatialActions[0] @('label') '') -cne [string]$deliveryAction.Label -or
                [string](Get-Value $spatialActions[0] @('object_type') '') -cne 'delivery' -or
                (Get-Value $spatialActions[0] @('visible') $null) -isnot [bool] -or -not [bool](Get-Value $spatialActions[0] @('visible') $false) -or
                (Get-Value $spatialActions[0] @('interactive') $null) -isnot [bool] -or -not [bool](Get-Value $spatialActions[0] @('interactive') $false) -or
                (Get-Value $spatialActions[0] @('enabled') $null) -isnot [bool] -or -not [bool](Get-Value $spatialActions[0] @('enabled') $false)) {
                throw "$Intent exposed a malformed overflow $([string]$deliveryAction.Label) delivery control."
            }
            $null = Invoke-OverflowRoomActionButton `
                -ButtonText "$([string]$deliveryAction.Label): $([string]$deliveryAction.Label)" `
                -Intent ([string]$deliveryAction.Intent)
            Wait-Frames -Frames 8
            $overflowDeliveryHandled = $true
            break
        }
        if ($overflowDeliveryHandled) { continue }

        # The Punchline map node opens on its exterior. Its marked contact is a
        # real person inside the casino, so follow the visible room door before
        # declaring the handoff missing.
        if ($null -cne (Find-CanvasObject -SemanticId 'environment_layer:casino')) {
            $null = Open-SemanticObject -SemanticId 'environment_layer:casino' -PreferredActions @('Enter Casino', 'Enter Room', 'Enter', 'Open') -Intent "${Intent}: enter the marked contact's visible casino room"
            Wait-Frames -Frames 12
            continue
        }
        throw "$Intent reached its marked target but exposed no public hold, signal, or handoff action."
    }
    throw "$Intent did not resolve through the visible delivery controls within twenty-four route actions."
}


function Open-EventObject {
    param(
        [Parameter(Mandatory = $true)][string]$EventId,
        [Parameter(Mandatory = $true)][string]$Intent
    )
    $null = Open-SemanticObject -SemanticId "event:$EventId" -PreferredActions @('Open', 'Answer', 'Respond', 'Talk', 'Inspect') -Intent $Intent
    Wait-Frames -Frames 8
    if (-not [bool](Get-Value $script:LastObservation @('event_popup', 'visible') $false) -and
        -not [bool](Get-Value $script:LastObservation @('talk', 'visible') $false)) {
        throw "Opening event '$EventId' did not expose a visible choice surface."
    }
}


function Accept-GrandCasinoInviteIfVisible {
    if ($null -ceq (Find-CanvasObject -SemanticId 'event:grand_casino_invite')) { return $false }
    Invoke-EventObjectChoice -EventId 'grand_casino_invite' -ChoiceId 'accept_invite' -Intent 'accept the visible invitation to the Grand Casino'
    Wait-Frames -Frames 15
    return $true
}


function Get-PublicGrandFareRequirement {
    Open-WorldMap
    $grand = @(Get-MapNodes | Where-Object {
        [string](Get-Value $_ @('archetype_id') '') -ceq 'grand_casino'
    })
    if ($grand.Count -cne 1) {
        throw "Grand fare recovery requires exactly one player-visible Grand Casino route; found $($grand.Count)."
    }
    $nodeId = Get-Value $grand[0] @('id') $null
    $cost = Get-Value $grand[0] @('cost') $null
    if ($nodeId -isnot [string] -or [string]$nodeId -cnotmatch '^[a-z0-9_]+$') {
        throw 'The player-visible Grand Casino route has no stable public node id.'
    }
    if (($cost -isnot [int32] -and $cost -isnot [int64]) -or [long]$cost -lt 0) {
        throw 'The player-visible Grand Casino route has no non-negative integral fare.'
    }
    $requiredCashLong = [long]$cost + [long]$GrandCasinoChipReserve
    if ($requiredCashLong -gt [int]::MaxValue) {
        throw 'The published Grand fare plus chip reserve exceeds the supported public integer range.'
    }
    return [pscustomobject][ordered]@{
        node = $grand[0]
        node_id = [string]$nodeId
        fare = [int]$cost
        required_cash = [int]$requiredCashLong
    }
}


function Restore-EnvironmentSurfaceAfterTravelResult {
    $screen = Get-Value $script:LastObservation @('screen', 'screen') $null
    if ($screen -isnot [string]) {
        throw 'Grand fare recovery lost its exact public screen identity.'
    }
    if ([string]$screen -ceq 'ENVIRONMENT') { return }
    if ([string]$screen -cne 'RESULT') {
        throw "Grand fare recovery cannot normalize unexpected public screen '$screen'."
    }

    # Travel leaves an informational Result state layered over the destination
    # room. Some room-action rows can be geometrically covered by that panel.
    # A real player can open and close the map to return to the ordinary room
    # surface without changing simulation state, so do the same through public
    # controls before clicking a lender or cash-event action.
    Open-WorldMap
    Close-WorldMap
    $restoredScreen = Get-Value $script:LastObservation @('screen', 'screen') $null
    if ($restoredScreen -isnot [string] -or [string]$restoredScreen -cne 'ENVIRONMENT') {
        throw 'The public map round trip did not restore the ordinary room surface after travel.'
    }
}


function Restore-GrandCasinoEnvironmentSurface {
    param([ValidateRange(1, 64)][int]$MaximumPolls = 48)

    $archetype = Get-Value $script:LastObservation @('environment', 'archetype_id') $null
    if ($archetype -isnot [string] -or [string]$archetype -cnotin @('grand_casino', 'grand_casino_cage', 'grand_casino_high_limit')) {
        throw "Grand surface normalization requires an exact Grand Casino room; found '$archetype'."
    }

    $greetingSettled = $false
    for ($poll = 0; $poll -lt $MaximumPolls; $poll++) {
        $eventVisible = Get-Value $script:LastObservation @('event_popup', 'visible') $null
        $talkVisible = Get-Value $script:LastObservation @('talk', 'visible') $null
        if ($eventVisible -isnot [bool] -or $talkVisible -isnot [bool]) {
            throw 'Grand surface normalization lost its exact boolean modal visibility signals.'
        }
        if ([bool]$eventVisible) {
            throw 'Grand surface normalization encountered an unrelated visible event popup.'
        }
        if (-not [bool]$talkVisible) {
            $greetingSettled = $true
            break
        }

        $eventId = Get-Value $script:LastObservation @('talk', 'event_id') $null
        if ($eventId -isnot [string] -or [string]$eventId -cne 'dialogue:normal_grand_host_greeting') {
            throw "Grand surface normalization refuses unexpected TalkDock '$eventId'."
        }
        $expanded = Get-Value $script:LastObservation @('talk', 'expanded') $null
        $renderValid = Get-Value $script:LastObservation @('talk', 'render_valid') $null
        $bodyComplete = Get-Value $script:LastObservation @('talk', 'body_complete') $null
        $typewriterActive = Get-Value $script:LastObservation @('talk', 'typewriter_active') $null
        if ($expanded -isnot [bool] -or $renderValid -isnot [bool] -or
            $bodyComplete -isnot [bool] -or $typewriterActive -isnot [bool]) {
            throw 'Grand host greeting lost an exact boolean render-state witness.'
        }
        if ([bool]$expanded -and [bool]$renderValid -and [bool]$bodyComplete -and -not [bool]$typewriterActive) {
            $choice = Select-GrandArrivalGreetingChoice `
                -Talk (Get-Value $script:LastObservation @('talk') $null) `
                -TalkChoices @(Get-PublicTalkChoices) `
                -EventPopup (Get-Value $script:LastObservation @('event_popup') $null)
            $null = Choose-VisibleChoice -ChoiceId $choice -Intent 'accept Vivienne''s exact visible Grand Casino welcome'
            Wait-Frames -Frames 8 -Intent 'let the exact Grand Casino welcome close'
            $afterEventVisible = Get-Value $script:LastObservation @('event_popup', 'visible') $null
            $afterTalkVisible = Get-Value $script:LastObservation @('talk', 'visible') $null
            if ($afterEventVisible -isnot [bool] -or $afterTalkVisible -isnot [bool] -or
                [bool]$afterEventVisible -or [bool]$afterTalkVisible) {
                throw 'The exact Grand Casino welcome remained visible or chained into another modal.'
            }
            $greetingSettled = $true
            break
        }
        Wait-Frames -Frames 4 -Intent 'wait for Vivienne''s exact Grand Casino welcome to finish rendering'
    }
    if (-not $greetingSettled) {
        throw 'The exact Grand Casino welcome did not settle within the bounded public wait.'
    }

    Restore-EnvironmentSurfaceAfterTravelResult
    $finalEventVisible = Get-Value $script:LastObservation @('event_popup', 'visible') $null
    $finalTalkVisible = Get-Value $script:LastObservation @('talk', 'visible') $null
    if ($finalEventVisible -isnot [bool] -or $finalTalkVisible -isnot [bool] -or
        [bool]$finalEventVisible -or [bool]$finalTalkVisible) {
        throw 'Grand surface normalization did not restore a modal-free public room.'
    }
}


function Wait-ForFullyRenderedFundingTalk {
    param(
        [Parameter(Mandatory = $true)][string]$ExpectedEventId,
        [ValidateRange(1, 64)][int]$MaximumPolls = 48,
        [ValidateRange(1, 16)][int]$MaximumOpenPolls = 6
    )

    $talkOpened = $false
    for ($poll = 0; $poll -lt $MaximumPolls; $poll++) {
        $eventVisible = Get-Value $script:LastObservation @('event_popup', 'visible') $null
        $talkVisible = Get-Value $script:LastObservation @('talk', 'visible') $null
        if ($eventVisible -isnot [bool] -or $talkVisible -isnot [bool]) {
            throw 'Funding wait lost its boolean public modal visibility signals.'
        }
        if ([bool]$eventVisible) {
            throw 'Funding wait encountered an unrelated visible event popup.'
        }
        if ([bool]$talkVisible) {
            $talkOpened = $true
            $eventId = Get-Value $script:LastObservation @('talk', 'event_id') $null
            if ($eventId -isnot [string] -or [string]$eventId -cne $ExpectedEventId) {
                throw "Funding wait opened unexpected TalkDock '$eventId'."
            }
            $choiceIds = @(Get-Array (Get-Value $script:LastObservation @('talk', 'choice_ids') @()))
            if ($choiceIds.Count -cne 2 -or $choiceIds[0] -isnot [string] -or [string]$choiceIds[0] -cne 'accept' -or
                $choiceIds[1] -isnot [string] -or [string]$choiceIds[1] -cne 'decline') {
                throw 'Funding wait observed a changed or unauthenticated TalkDock choice set.'
            }
            $expanded = Get-Value $script:LastObservation @('talk', 'expanded') $null
            $renderValid = Get-Value $script:LastObservation @('talk', 'render_valid') $null
            $bodyComplete = Get-Value $script:LastObservation @('talk', 'body_complete') $null
            $typewriterActive = Get-Value $script:LastObservation @('talk', 'typewriter_active') $null
            if ($renderValid -is [bool] -and [bool]$renderValid -and
                $expanded -is [bool] -and [bool]$expanded -and
                $bodyComplete -is [bool] -and [bool]$bodyComplete -and
                $typewriterActive -is [bool] -and -not [bool]$typewriterActive) {
                return
            }
        }
        elseif (-not $talkOpened -and $poll + 1 -ge $MaximumOpenPolls) {
            throw "The advertised lender action did not open TalkDock '$ExpectedEventId' within $MaximumOpenPolls bounded public observations."
        }
        Wait-Frames -Frames 4 -Intent 'wait for the visible lender terms to finish rendering'
    }
    throw "Funding TalkDock '$ExpectedEventId' did not become fully rendered within the bounded wait."
}


function Invoke-CleanScoutingCashOpportunity {
    if ($Ending -cne 'clean') { return $false }
    if ($script:GrandFareRecoveryActive) {
        throw 'Clean scouting cash collection cannot overlap Grand fare recovery.'
    }

    # The fixed route naturally passes the Motel before its invitation. Taking
    # a visibly positive cash event while already there avoids paying a second
    # round-trip fare later and keeps the route independent of the 75% family
    # phone event. Reuse the same strict public-result policy as fare recovery.
    $script:GrandFareRecoveryActive = $true
    try {
        return Invoke-GrandFarePublicCashEvent
    }
    finally {
        $script:GrandFareRecoveryActive = $false
    }
}


function Invoke-GrandFarePublicFundingOffer {
    if (-not $script:GrandFareRecoveryActive) {
        throw 'Public lender funding is permitted only inside Grand fare recovery.'
    }
    Restore-EnvironmentSurfaceAfterTravelResult
    Close-WorldMap
    if ([bool](Get-Value $script:LastObservation @('event_popup', 'visible') $false) -or
        [bool](Get-Value $script:LastObservation @('talk', 'visible') $false)) {
        throw 'Grand fare funding refuses to act through another visible modal.'
    }

    $canvasObjects = @(Get-Array (Get-Value $script:LastResult @('look', 'clickable', 'canvas_objects') @()))
    $lenders = @($canvasObjects | Where-Object {
        $semanticProperties = @(Get-Rw062ExactPublicPropertyMatches -InputObject $_ -Name 'semantic_id')
        $semanticProperties.Count -ceq 1 -and $semanticProperties[0].Value -is [string] -and
            ([string]$semanticProperties[0].Value).StartsWith('lender:', [StringComparison]::Ordinal)
    })
    if ($lenders.Count -ceq 0) { return $false }

    $worldNodeId = Get-Value $script:LastObservation @('environment', 'world_node_id') $null
    if ($worldNodeId -isnot [string] -or [string]$worldNodeId -cnotmatch '^[a-z0-9_]+$') {
        throw 'Grand fare funding cannot bind the visible offer to one public world node.'
    }
    foreach ($lender in $lenders) {
        $semanticId = [string](Get-Value $lender @('semantic_id') '')
        $rendered = Get-Value $lender @('rendered') $null
        $enabled = Get-Value $lender @('enabled') $null
        if ($rendered -isnot [bool] -or $enabled -isnot [bool]) {
            throw "Funding lender object '$semanticId' lost its exact rendered/enabled witnesses."
        }
    }
    $unusedEnabledLenders = @($lenders | Where-Object {
        $semanticId = [string](Get-Value $_ @('semantic_id') '')
        $lenderId = $semanticId.Substring('lender:'.Length)
        $offerKey = "$worldNodeId|$semanticId"
        $rendered = Get-Value $_ @('rendered') $null
        $enabled = Get-Value $_ @('enabled') $null
        $rendered -is [bool] -and [bool]$rendered -and
            $enabled -is [bool] -and [bool]$enabled -and
            -not $script:GrandFareAcceptedOfferKeys.Contains($offerKey) -and
            -not $script:GrandFareAcceptedLenderIds.Contains($lenderId)
    })
    if ($unusedEnabledLenders.Count -ceq 0) {
        return $false
    }
    $objectSelection = Select-GrandFareFundingObject `
        -CanvasObjects $canvasObjects `
        -WorldNodeId ([string]$worldNodeId) `
        -AcceptedOfferKeys @($script:GrandFareAcceptedOfferKeys) `
        -AcceptedLenderIds @($script:GrandFareAcceptedLenderIds)
    $preflightDebtIndicator = Get-Value $script:LastObservation @('status_hud', 'debt_indicator') $null
    if (-not (Test-GrandFareFundingPreflight `
        -Selection $objectSelection `
        -DebtIndicator $preflightDebtIndicator `
        -AcceptedLenderIds @($script:GrandFareAcceptedLenderIds))) {
        return $false
    }
    $semanticId = [string]$objectSelection.semantic_id
    $null = Invoke-BridgeCommand -Command "click_object $semanticId" -Intent 'focus the one visible lender offering Grand fare recovery'

    $selection = Select-GrandFareFundingObjectAction `
        -Selection $objectSelection `
        -RoomActions @(Get-RoomActions)
    $null = Invoke-RoomActionRow `
        -Row $selection.action `
        -Intent "open $($selection.lender_label)'s exact public Grand fare terms"
    $expectedTalkEventId = "lender_conversation:borrow:$($selection.lender_id)"
    Wait-ForFullyRenderedFundingTalk -ExpectedEventId $expectedTalkEventId

    $offer = Select-GrandFareFundingTalkOffer `
        -Selection $selection `
        -Talk (Get-Value $script:LastObservation @('talk') $null) `
        -TalkChoices @(Get-PublicTalkChoices)
    $beforeBankroll = Get-Value $script:LastObservation @('status_hud', 'bankroll') $null
    $beforeBankrollRendered = Get-Value $script:LastObservation @('status_hud', 'bankroll_rendered') $null
    if ($beforeBankrollRendered -isnot [bool] -or -not [bool]$beforeBankrollRendered -or
        ($beforeBankroll -isnot [int32] -and $beforeBankroll -isnot [int64])) {
        throw 'Grand fare funding cannot verify the pre-offer fully rendered HUD bankroll.'
    }
    $beforeDebtIndicator = Get-Value $script:LastObservation @('status_hud', 'debt_indicator') $null
    $null = Get-GrandFarePublicDebtCount -DebtIndicator $beforeDebtIndicator -Context 'Pre-acceptance HUD'

    $null = Invoke-BridgeCommand -Command 'click_choice accept' -Intent 'arm the visibly disclosed Grand fare funding offer'
    $null = Assert-GrandFareFundingConfirmation `
        -Offer $offer `
        -Talk (Get-Value $script:LastObservation @('talk') $null) `
        -TalkChoices @(Get-PublicTalkChoices)
    $null = Invoke-BridgeCommand -Command 'click_choice accept' -Intent 'confirm the visibly armed Grand fare funding offer'
    Wait-Frames -Frames 10
    $null = Assert-GrandFareFundingResult `
        -Offer $offer `
        -BeforeBankroll ([int]$beforeBankroll) `
        -BeforeDebtIndicator $beforeDebtIndicator `
        -AfterObservation $script:LastObservation
    $null = $script:GrandFareAcceptedOfferKeys.Add([string]$selection.offer_key)
    $null = $script:GrandFareAcceptedLenderIds.Add([string]$selection.lender_id)
    return $true
}


function Invoke-GrandFarePublicCashEvent {
    if (-not $script:GrandFareRecoveryActive) {
        throw 'Public cash events are permitted only inside Grand fare recovery.'
    }
    Restore-EnvironmentSurfaceAfterTravelResult
    Close-WorldMap
    if ([bool](Get-Value $script:LastObservation @('event_popup', 'visible') $false) -or
        [bool](Get-Value $script:LastObservation @('talk', 'visible') $false)) {
        throw 'Grand fare cash recovery refuses to act through another visible modal.'
    }

    $allowedSemanticIds = @(
        'event:back_alley_offer',
        'event:scenario_wedding_overflow_hallway'
    )
    # Do not call this collection $matches: PowerShell variable names are
    # case-insensitive, so the automatic regex variable $Matches would replace
    # it when the public world-node id is validated below.
    $eventObjects = @((Get-Array (Get-Value $script:LastResult @('look', 'clickable', 'canvas_objects') @())) | Where-Object {
        $semanticProperties = @(Get-Rw062ExactPublicPropertyMatches -InputObject $_ -Name 'semantic_id')
        $semanticProperties.Count -ceq 1 -and $semanticProperties[0].Value -is [string] -and
            [string]$semanticProperties[0].Value -cin $allowedSemanticIds
    })
    if ($eventObjects.Count -ceq 0) { return $false }
    if ($eventObjects.Count -cne 1) {
        throw "Grand fare cash recovery found $($eventObjects.Count) allowlisted public event objects instead of one."
    }
    $enabled = Get-Value $eventObjects[0] @('enabled') $null
    if ($enabled -isnot [bool] -or -not [bool]$enabled) {
        throw 'The allowlisted Grand fare cash event is disabled or has no boolean public enabled state.'
    }
    $semanticId = [string](Get-Value $eventObjects[0] @('semantic_id') '')
    $eventId = $semanticId.Substring('event:'.Length)
    $worldNodeId = Get-Value $script:LastObservation @('environment', 'world_node_id') $null
    if ($worldNodeId -isnot [string] -or [string]$worldNodeId -cnotmatch '^[a-z0-9_]+$') {
        throw 'Grand fare cash recovery cannot bind the visible event to one public world node.'
    }

    $null = Invoke-BridgeCommand -Command "click_object $semanticId" -Intent "focus the visible $eventId cash recovery event"
    $event = Select-GrandFareCashEventChoice `
        -EventId $eventId `
        -EventObject $eventObjects[0] `
        -RoomActions @(Get-RoomActions) `
        -Talk (Get-Value $script:LastObservation @('talk') $null) `
        -WorldNodeId ([string]$worldNodeId) `
        -ResolvedEventKeys @($script:GrandFareResolvedCashEventKeys)
    $beforeBankroll = Get-Value $script:LastObservation @('status_hud', 'bankroll') $null
    $beforeBankrollRendered = Get-Value $script:LastObservation @('status_hud', 'bankroll_rendered') $null
    $beforeHeat = Get-Value $script:LastObservation @('status_hud', 'heat_level') $null
    $beforeHeatRendered = Get-Value $script:LastObservation @('status_hud', 'heat_rendered') $null
    if ($beforeBankrollRendered -isnot [bool] -or -not [bool]$beforeBankrollRendered -or
        $beforeHeatRendered -isnot [bool] -or -not [bool]$beforeHeatRendered -or
        ($beforeBankroll -isnot [int32] -and $beforeBankroll -isnot [int64]) -or
        ($beforeHeat -isnot [int32] -and $beforeHeat -isnot [int64])) {
        throw 'Grand fare cash recovery cannot verify the pre-event fully rendered HUD bankroll and heat.'
    }
    $beforeFeedback = Get-Value $script:LastObservation @('feedback') $null
    if ($null -ceq $beforeFeedback) {
        throw 'Grand fare cash recovery cannot verify the pre-event public feedback surface.'
    }
    # This one rendered room-action click is the complete public interaction:
    # Foundation.activate_event_choice_action selects and confirms the inline
    # choice in its callback. No hidden confirmation or impact metadata is read.
    $null = Invoke-RoomActionRow -Row $event.action -Intent "take the exact visibly described $($event.choice_id) cash response"
    Wait-Frames -Frames 10
    $null = Assert-GrandFareCashEventResult `
        -Event $event `
        -BeforeBankroll ([int]$beforeBankroll) `
        -BeforeHeat ([int]$beforeHeat) `
        -BeforeFeedback $beforeFeedback `
        -AfterObservation $script:LastObservation
    $null = $script:GrandFareResolvedCashEventKeys.Add([string]$event.event_key)
    return $true
}


function Recover-CleanGrandFareAtCurrentStop {
    param([ValidateRange(1, 1000)][int]$RequiredCash)
    if ($Ending -cne 'clean') {
        throw 'Clean Grand fare recovery cannot run for another ending.'
    }
    if ($script:GrandFareRecoveryActive) {
        throw 'Clean Grand fare recovery cannot be nested.'
    }

    # Once the invited Grand card is public, keep the affordability diagnosis
    # anchored to that exact stop. Travelling elsewhere changes the published
    # fare and can spend more than a generated offer returns; Slot play is a
    # lucky outcome, not qualifying deterministic liquidity. Consume only the
    # current room's authenticated lender/event, then either proceed or report
    # the exact public shortfall for rw06_3.
    $script:GrandFareRecoveryActive = $true
    try {
        Close-WorldMap
        $null = Invoke-GrandFarePublicFundingOffer
        $null = Invoke-GrandFarePublicCashEvent
        $requirement = Get-PublicGrandFareRequirement
        $cash = Get-Value $script:LastObservation @('status_hud', 'bankroll') $null
        if ($cash -isnot [int32] -and $cash -isnot [int64]) {
            throw 'Clean Grand fare recovery lost its integral public bankroll signal.'
        }
        Close-WorldMap
        if ([int]$cash -ge [int]$requirement.required_cash) { return }
        $shortfall = [int]$requirement.required_cash - [int]$cash
        throw "Clean Grand entry remains unaffordable after deterministic current-stop liquidity: cash=`$$cash, fare=`$$($requirement.fare), chip_reserve=`$$GrandCasinoChipReserve, required=`$$($requirement.required_cash), initial_required=`$$RequiredCash, shortfall=`$$shortfall."
    }
    finally {
        $script:GrandFareRecoveryActive = $false
    }
}


function Get-GrandFareRecoveryNodePreference {
    param([Parameter(Mandatory = $true)][string]$ArchetypeId)
    # Prefer venues whose authored public lender pool is distinct from the
    # Crew-only invitation room. Returning to the Motel can expose a family or
    # friend offer; visiting another Crew-only casino cannot add a second
    # authenticated lender after the Kitty Cat Crew note was accepted.
    if ($ArchetypeId -ceq 'motel') { return 0 }
    if ($ArchetypeId -ceq 'back_alley') { return 1 }
    if ($ArchetypeId -ceq 'corner_store') { return 3 }
    if ($ArchetypeId -ceq 'small_underground_casino') { return 2 }
    if ($ArchetypeId -ceq 'delta_queen') { return 4 }
    if ($ArchetypeId -ceq 'bar') { return 5 }
    if ($ArchetypeId -ceq 'gas_station_casino') { return 6 }
    return 20
}


function Recover-GrandFareThroughPublicFunding {
    param(
        [ValidateRange(1, 1000)][int]$RequiredCash,
        [ValidateRange(1, 12)][int]$MaximumFundingStops = 6
    )
    if ($script:GrandFareRecoveryActive) {
        throw 'Grand fare recovery cannot be nested.'
    }
    $script:GrandFareRecoveryActive = $true
    try {
        $initialRequirement = Get-PublicGrandFareRequirement
        if ([int]$initialRequirement.required_cash -cne $RequiredCash) {
            throw "Grand fare recovery received stale public math: expected `$$RequiredCash, now `$$($initialRequirement.required_cash)."
        }
        Close-WorldMap

        for ($stop = 0; $stop -lt $MaximumFundingStops; $stop++) {
            $currentNodeId = Get-Value $script:LastObservation @('environment', 'world_node_id') $null
            if ($currentNodeId -isnot [string] -or [string]$currentNodeId -cnotmatch '^[a-z0-9_]+$') {
                throw 'Grand fare recovery lost its stable public world-node id.'
            }
            $null = $script:GrandFareRecoveryVisitedNodes.Add([string]$currentNodeId)

            $null = Invoke-GrandFarePublicFundingOffer
            $requirement = Get-PublicGrandFareRequirement
            $cash = Get-Value $script:LastObservation @('status_hud', 'bankroll') $null
            if ($cash -isnot [int32] -and $cash -isnot [int64]) {
                throw 'Grand fare recovery lost its integral public bankroll signal.'
            }
            if ([int]$cash -ge [int]$requirement.required_cash) {
                Close-WorldMap
                return
            }
            Close-WorldMap

            $null = Invoke-GrandFarePublicCashEvent
            $requirement = Get-PublicGrandFareRequirement
            $cash = Get-Value $script:LastObservation @('status_hud', 'bankroll') $null
            if ($cash -isnot [int32] -and $cash -isnot [int64]) {
                throw 'Grand fare recovery lost its integral public bankroll signal after a cash event.'
            }
            if ([int]$cash -ge [int]$requirement.required_cash) {
                Close-WorldMap
                return
            }

            $currentNodeId = [string](Get-Value $script:LastObservation @('environment', 'world_node_id') '')
            $candidates = @(Get-MapNodes | Where-Object {
                $id = [string](Get-Value $_ @('id') '')
                $state = [string](Get-Value $_ @('state') '')
                $archetype = [string](Get-Value $_ @('archetype_id') '')
                $id -cmatch '^[a-z0-9_]+$' -and
                    $id -cne $currentNodeId -and
                    $archetype -cne 'grand_casino' -and
                    $state -cin @('visited', 'revealed') -and
                    [bool](Get-Value $_ @('travel_enabled') $false) -and
                    (-not $script:GrandFareRecoveryVisitedNodes.Contains($id))
            } | Sort-Object `
                @{ Expression = { Get-GrandFareRecoveryNodePreference -ArchetypeId ([string](Get-Value $_ @('archetype_id') '')) } }, `
                @{ Expression = { [int](Get-Value $_ @('cost') 0) } }, `
                @{ Expression = { [string](Get-Value $_ @('id') '') } })
            if ($candidates.Count -ceq 0) {
                Close-WorldMap
                break
            }
            $nextNodeId = [string](Get-Value $candidates[0] @('id') '')
            Travel-ToNode -NodeId $nextNodeId -Intent "visit $nextNodeId for another bounded public Grand fare option"
        }

        $requirement = Get-PublicGrandFareRequirement
        $cash = Get-Value $script:LastObservation @('status_hud', 'bankroll') $null
        if ($cash -isnot [int32] -and $cash -isnot [int64]) {
            throw 'Grand fare recovery lost its integral public bankroll before slot fallback.'
        }
        if ([int]$cash -ge [int]$requirement.required_cash) {
            Close-WorldMap
            return
        }
        Close-WorldMap

        if ($null -ceq (Find-CanvasObject -SemanticId 'game:slot')) {
            Open-WorldMap
            $currentNodeId = [string](Get-Value $script:LastObservation @('environment', 'world_node_id') '')
            $slotStops = @(Get-MapNodes | Where-Object {
                $id = [string](Get-Value $_ @('id') '')
                $archetype = [string](Get-Value $_ @('archetype_id') '')
                [bool](Get-Value $_ @('travel_enabled') $false) -and
                    [string](Get-Value $_ @('state') '') -ceq 'visited' -and
                    $id -cne $currentNodeId -and
                    $archetype -cin @('kitty_cat_lounge', 'bar', 'gas_station_casino')
            } | Sort-Object @{ Expression = { [int](Get-Value $_ @('cost') 0) } }, @{ Expression = { [string](Get-Value $_ @('id') '') } })
            if ($slotStops.Count -ceq 0) {
                Close-WorldMap
                throw 'Bounded Grand fare recovery exhausted public offers and exposes no visited slot room.'
            }
            $slotNodeId = [string](Get-Value $slotStops[0] @('id') '')
            Travel-ToNode -NodeId $slotNodeId -Intent 'return to the nearest visited public slot for loss-stopped Grand fare fallback'
        }
        $requirement = Get-PublicGrandFareRequirement
        Close-WorldMap
        Earn-GrandFareThroughVisibleSlot -RequiredCash ([int]$requirement.required_cash)
    }
    finally {
        $script:GrandFareRecoveryActive = $false
    }
}


function Enter-VisibleSlotForGrandFare {
    Close-WorldMap
    if ([string](Get-Value $script:LastObservation @('screen', 'screen') '') -ceq 'GAME') {
        if ([string](Get-Value $script:LastObservation @('game', 'game_id') '') -ceq 'slot') { return }
        Leave-GameSurface
    }
    if ($null -ceq (Find-CanvasObject -SemanticId 'game:slot')) {
        throw 'The invited Grand route is short of cash, but this room exposes no visible slot for bounded fare recovery.'
    }
    $null = Open-SemanticObject -SemanticId 'game:slot' -PreferredActions @('Enter', 'Play') -Intent 'use the visible slot to earn the displayed Grand Casino fare shortfall'
    Wait-Frames -Frames 12
    if ([string](Get-Value $script:LastObservation @('screen', 'screen') '') -cne 'GAME' -or
        [string](Get-Value $script:LastObservation @('game', 'game_id') '') -cne 'slot') {
        throw 'The visible slot did not open its public game surface for Grand fare recovery.'
    }
}


function Resolve-GrandFareMachineJamIfVisible {
    $eventVisible = Get-Value $script:LastObservation @('event_popup', 'visible') $null
    $talkVisible = Get-Value $script:LastObservation @('talk', 'visible') $null
    if ($eventVisible -isnot [bool] -or $talkVisible -isnot [bool]) {
        throw 'Grand fare recovery requires boolean public modal visibility signals.'
    }
    if (-not [bool]$eventVisible -and -not [bool]$talkVisible) {
        return $false
    }

    $choiceId = Select-GrandFareMachineJamChoice `
        -EventPopup (Get-Value $script:LastObservation @('event_popup') $null) `
        -Talk (Get-Value $script:LastObservation @('talk') $null)
    $null = Choose-VisibleChoice `
        -ChoiceId $choiceId `
        -Intent 'resolve the exact fully rendered machine_jam with its visible de-escalation choice'
    Wait-Frames -Frames 10 -Intent 'wait for the confirmed public machine_jam choice to resolve'

    $postEventVisible = Get-Value $script:LastObservation @('event_popup', 'visible') $null
    $postTalkVisible = Get-Value $script:LastObservation @('talk', 'visible') $null
    if ($postEventVisible -isnot [bool] -or $postTalkVisible -isnot [bool]) {
        throw 'The public modal visibility schema disappeared after the machine_jam confirmation.'
    }
    if ([bool]$postEventVisible -or [bool]$postTalkVisible) {
        throw 'The allowlisted machine_jam modal remained visible or chained into another modal after confirmation.'
    }
    return $true
}


function Wait-ForVisibleSlotActionBoundary {
    for ($step = 0; $step -lt 24; $step++) {
        if ([string](Get-Value $script:LastObservation @('screen', 'screen') '') -cne 'GAME' -or
            [string](Get-Value $script:LastObservation @('game', 'game_id') '') -cne 'slot') {
            throw 'Grand fare recovery left the visible slot surface unexpectedly.'
        }
        if (Resolve-GrandFareMachineJamIfVisible) {
            continue
        }

        if ($null -cne (Find-GameAction -Action 'slot_handpay_acknowledge')) {
            $null = Invoke-GameAction -Action 'slot_handpay_acknowledge' -Intent 'acknowledge the visible sealed slot payout'
            Wait-Frames -Frames 20
            continue
        }
        $bonusActions = @(Get-GameActions | Where-Object {
            [bool](Get-Value $_ @('enabled') $false) -and
            ([string](Get-Value $_ @('action') '')).StartsWith('slot_bonus_', [StringComparison]::Ordinal)
        } | Sort-Object @{ Expression = { [string](Get-Value $_ @('action') '') } }, @{ Expression = { [int](Get-Value $_ @('index') 0) } })
        if ($bonusActions.Count -gt 0) {
            $bonusAction = [string](Get-Value $bonusActions[0] @('action') '')
            $bonusIndex = [int](Get-Value $bonusActions[0] @('index') 0)
            $null = Invoke-GameAction -Action $bonusAction -Index $bonusIndex -Intent "take the first deterministic visible slot bonus control $bonusAction"
            Wait-Frames -Frames 20
            continue
        }
        if ($null -cne (Find-GameAction -Action 'slot_spin')) { return }
        Wait-Frames -Frames 30 -Intent 'wait for the visible slot result to finish presenting'
    }
    throw 'The visible slot did not return to a legal Spin boundary within twelve seconds.'
}


function Earn-GrandFareThroughVisibleSlot {
    param(
        [ValidateRange(1, 1000)][int]$RequiredCash,
        [ValidateRange(1, 12)][int]$MaximumSpins = 6,
        [ValidateRange(1, 6)][int]$MaximumLosses = 3
    )
    Enter-VisibleSlotForGrandFare
    $startingCash = [int](Get-Value $script:LastObservation @('status_hud', 'bankroll') 0)
    $losses = 0
    for ($spin = 0; $spin -lt $MaximumSpins; $spin++) {
        Wait-ForVisibleSlotActionBoundary
        $beforeCash = [int](Get-Value $script:LastObservation @('status_hud', 'bankroll') 0)
        if ($beforeCash -ge $RequiredCash) {
            Leave-GameSurface
            return
        }
        if ($null -ceq (Find-GameAction -Action 'slot_spin')) {
            throw "The visible slot exposes no legal Spin while Grand fare recovery is short (`$$beforeCash of `$$RequiredCash)."
        }
        $null = Invoke-GameAction -Action 'slot_spin' -Intent "spin the visible slot at its rendered stake for Grand fare recovery ($($spin + 1)/$MaximumSpins)"
        Wait-Frames -Frames 30 -Intent 'watch the visible slot result begin resolving'
        Wait-ForVisibleSlotActionBoundary
        $afterCash = [int](Get-Value $script:LastObservation @('status_hud', 'bankroll') 0)
        if ($afterCash -lt $beforeCash) { $losses++ }
        if ($afterCash -ge $RequiredCash) {
            Leave-GameSurface
            return
        }
        if ($losses -ge $MaximumLosses) {
            Leave-GameSurface
            throw "Grand fare slot fallback loss-stopped after $losses losing spins: start=`$$startingCash, end=`$$afterCash, required=`$$RequiredCash."
        }
    }
    $endingCash = [int](Get-Value $script:LastObservation @('status_hud', 'bankroll') 0)
    Leave-GameSurface
    throw "Grand fare slot fallback exhausted $MaximumSpins spins without reaching the public target: start=`$$startingCash, end=`$$endingCash, required=`$$RequiredCash, losses=$losses."
}


function Advance-RiverboatTravelLockThroughVisibleAction {
    param([Parameter(Mandatory = $true)][string]$DisabledReason)

    $archetype = [string](Get-Value $script:LastObservation @('environment', 'archetype_id') '')
    if ($archetype -cne 'delta_queen' -or
        $DisabledReason -cnotmatch '^The River Queen is out on the river for [1-9][0-9]* more actions?\.$') {
        return $false
    }
    Close-WorldMap
    Restore-EnvironmentSurfaceAfterTravelResult

    $service = Find-CanvasObject -SemanticId 'service:riverboat_deck_walk'
    if ($null -ceq $service -or
        [string](Get-Value $service @('label') '') -cne 'Walk the Deck' -or
        [string](Get-Value $service @('object_type') '') -cne 'service') {
        throw 'The River Queen travel lock exposes no rendered, enabled Walk the Deck action.'
    }
    $beforeCash = Get-RenderedHudInteger -Name bankroll -Context 'River Queen travel-lock bankroll before Walk the Deck'
    if ($beforeCash -lt 10) {
        throw "Walk the Deck costs `$10, but only `$$beforeCash remains while the River Queen travel lock is active."
    }
    $null = Open-SemanticObject `
        -SemanticId 'service:riverboat_deck_walk' `
        -PreferredActions @('Use') `
        -Intent 'take one visible deck walk while the River Queen is away from the dock'
    Wait-Frames -Frames 10
    $afterCash = Get-RenderedHudInteger -Name bankroll -Context 'River Queen travel-lock bankroll after Walk the Deck'
    if ($afterCash -ne $beforeCash - 10) {
        throw "Walk the Deck did not charge its exact visible `$10 price (`$$beforeCash -> `$$afterCash)."
    }
    Restore-EnvironmentSurfaceAfterTravelResult
    return $true
}


function Reach-GrandCasino {
    $visitedByRunner = New-Object 'System.Collections.Generic.HashSet[string]'
    for ($step = 0; $step -lt 24; $step++) {
        $archetype = [string](Get-Value $script:LastObservation @('environment', 'archetype_id') '')
        if ($archetype -cin @('grand_casino', 'grand_casino_cage', 'grand_casino_high_limit')) {
            $screen = Get-Value $script:LastObservation @('screen', 'screen') $null
            if ($screen -isnot [string]) {
                throw 'Grand arrival lost its exact public screen identity.'
            }
            if ([string]$screen -ceq 'GAME') { return }
            Restore-GrandCasinoEnvironmentSurface
            return
        }

        $null = Invoke-CleanScoutingCashOpportunity
        if (Accept-GrandCasinoInviteIfVisible) { continue }
        Open-WorldMap
        $nodes = @(Get-MapNodes)
        $grand = @($nodes | Where-Object {
            [string](Get-Value $_ @('archetype_id') '') -ceq 'grand_casino'
        })
        if ($grand.Count -gt 1) {
            throw "The visible city map exposes more than one Grand Casino route."
        }
        if ($grand.Count -ceq 1) {
            $costValue = Get-Value $grand[0] @('cost') $null
            if (($costValue -isnot [int32] -and $costValue -isnot [int64]) -or [long]$costValue -lt 0) {
                throw 'The visible Grand Casino card has no non-negative integral route fare.'
            }
            $cost = [int]$costValue
            $requiredCashLong = [long]$cost + [long]$GrandCasinoChipReserve
            if ($requiredCashLong -gt [int]::MaxValue) {
                throw 'The visible Grand fare plus chip reserve exceeds the supported public integer range.'
            }
            $requiredCash = [int]$requiredCashLong
            $cashValue = Get-Value $script:LastObservation @('status_hud', 'bankroll') $null
            if ($cashValue -isnot [int32] -and $cashValue -isnot [int64]) {
                throw 'The clean replay cannot verify its public bankroll before Grand travel.'
            }
            $cash = [int]$cashValue
            if ($cash -lt $requiredCash) {
                Close-WorldMap
                if ($Ending -ceq 'clean') {
                    Recover-CleanGrandFareAtCurrentStop -RequiredCash $requiredCash
                }
                else {
                    Recover-GrandFareThroughPublicFunding -RequiredCash $requiredCash
                }
                continue
            }
            if ([bool](Get-Value $grand[0] @('travel_enabled') $false)) {
                Travel-ToNode -NodeId ([string](Get-Value $grand[0] @('id') '')) -Intent 'travel to the Grand Casino through the visible city map with its chip reserve intact'
                continue
            }
            $reason = [string](Get-Value $grand[0] @('travel_disabled_reason') 'The route is unavailable.')
            if (Advance-RiverboatTravelLockThroughVisibleAction -DisabledReason $reason) {
                continue
            }
            if ($reason -cmatch 'Not enough bankroll') {
                if ($cost -le $cash) {
                    throw "The Grand card claims insufficient bankroll but publishes cash=$cash and route_cost=$cost."
                }
            }
            throw "The invited Grand Casino route is visible but unavailable: $reason"
        }

        $candidates = @($nodes | Where-Object {
            $id = [string](Get-Value $_ @('id') '')
            $kind = [string](Get-Value $_ @('kind') '')
            $tier = [int](Get-Value $_ @('tier') 0)
            $state = [string](Get-Value $_ @('state') '')
            [bool](Get-Value $_ @('travel_enabled') $false) -and
            $kind -ceq 'casino' -and $id -cne '' -and
            (-not $visitedByRunner.Contains($id)) -and
            ($tier -ge 2 -or $state -cne 'visited')
        } | Sort-Object @{ Expression = { -[int](Get-Value $_ @('tier') 0) } }, @{ Expression = { [string](Get-Value $_ @('id') '') } })
        if ($candidates.Count -ceq 0) {
            $candidates = @($nodes | Where-Object {
                $id = [string](Get-Value $_ @('id') '')
                [bool](Get-Value $_ @('travel_enabled') $false) -and $id -cne '' -and
                (-not $visitedByRunner.Contains($id))
            } | Sort-Object { [int](Get-Value $_ @('cost') 0) })
        }
        if ($candidates.Count -ceq 0) {
            throw "No visible unvisited route can advance the Grand Casino invitation."
        }
        $target = [string](Get-Value $candidates[0] @('id') '')
        $null = $visitedByRunner.Add($target)
        Travel-ToNode -NodeId $target -Intent "travel to $target to scout a natural route toward the Grand Casino"
    }
    throw "The visible world route did not reach the Grand Casino within 24 travel decisions."
}


function Enter-GrandRoom {
    param(
        [Parameter(Mandatory = $true)][ValidateSet('main', 'cage')][string]$Room
    )
    $expected = if ($Room -ceq 'cage') { 'grand_casino_cage' } else { 'grand_casino' }
    $archetype = [string](Get-Value $script:LastObservation @('environment', 'archetype_id') '')
    if ($archetype -ceq $expected) {
        $screen = Get-Value $script:LastObservation @('screen', 'screen') $null
        if ($screen -isnot [string]) {
            throw 'Grand room navigation lost its exact public screen identity.'
        }
        if ([string]$screen -ceq 'GAME') { return }
        Restore-GrandCasinoEnvironmentSurface
        return
    }
    $semantic = if ($Room -ceq 'cage') { 'travel:grand_casino_cage' } else { 'travel:grand_casino' }
    $canvasMatches = @(Get-Array (Get-Value $script:LastResult @('look', 'clickable', 'canvas_objects') @()) | Where-Object {
        [string](Get-Value $_ @('semantic_id') '') -ceq $semantic
    })
    if ($canvasMatches.Count -cne 1) {
        throw "The Grand Casino exposes $($canvasMatches.Count) exact '$semantic' door records."
    }
    $doorRendered = Get-Value $canvasMatches[0] @('rendered') $null
    $doorEnabled = Get-Value $canvasMatches[0] @('enabled') $null
    if ($doorRendered -isnot [bool] -or $doorEnabled -isnot [bool] -or -not [bool]$doorEnabled) {
        throw "The Grand Casino door '$semantic' has no exact enabled public state."
    }
    if (-not [bool]$doorRendered) {
        $doorRendered = Reveal-SemanticObjectByPublicRefocus -TargetSemanticId $semantic
    }
    if ([bool]$doorRendered) {
        $null = Open-SemanticObject -SemanticId $semantic -PreferredActions @('Enter Room', 'Travel', 'Enter') -Intent "walk through the real Grand Casino door to $Room"
    }
    else {
        $doorLabel = [string](Get-Value $canvasMatches[0] @('label') '')
        if ([string]::IsNullOrWhiteSpace($doorLabel)) {
            throw "The overflow Grand Casino door '$semantic' has no public label."
        }
        $null = Invoke-OverflowRoomActionButton `
            -ButtonText "${doorLabel}: Enter Room" `
            -Intent "walk through the visible Grand Casino room action to $Room"
    }
    Wait-ForTravelToSettle
    Wait-Frames -Frames 12
    if ([string](Get-Value $script:LastObservation @('environment', 'archetype_id') '') -cne $expected) {
        throw "The real Grand Casino door did not reach '$expected'."
    }
    Restore-GrandCasinoEnvironmentSurface
}


function Open-CageCounter {
    Enter-GrandRoom -Room cage
    if ($null -ne (Find-CanvasObject -SemanticId 'casino_fixture:cage_counter')) {
        $null = Open-SemanticObject -SemanticId 'casino_fixture:cage_counter' -PreferredActions @('Talk', 'Open', 'Inspect') -Intent 'speak with Linda at the real Cage counter'
    }
    else {
        $null = Invoke-OverflowRoomActionButton `
            -ButtonText 'Cashout Counter: Inspect' `
            -Intent 'speak with Linda through the visible Cage room action'
    }
    Wait-Frames -Frames 8
    if (-not [bool](Get-Value $script:LastObservation @('talk', 'visible') $false)) {
        throw "Linda's Cage counter did not expose its visible dialogue choices."
    }
}


function Ensure-GrandCasinoChips {
    param([ValidateRange(0, 200)][int]$Minimum = 50)
    $chips = Get-RenderedHudInteger -Name chips -Context 'Grand Casino chip check'
    if ($chips -ge $Minimum) { return }
    Open-CageCounter
    $null = Choose-VisibleChoice -ChoiceId 'open_chips' -Intent 'open Linda''s visible chips and cashout menu'
    $maximumChipPurchases = 8 # 8 x the smallest $25 exchange covers the validated $200 ceiling.
    for ($purchase = 0; $purchase -lt $maximumChipPurchases; $purchase++) {
        $beforeChips = Get-RenderedHudInteger -Name chips -Context 'Pre-purchase Grand Casino chip check'
        if ($beforeChips -ge $Minimum) { break }
        $enabledChoices = @(Get-PublicTalkChoices | Where-Object {
            [bool](Get-Value $_ @('enabled') $false)
        } | ForEach-Object {
            [string](Get-Value $_ @('id') '')
        })
        if ('cage_buy_50' -cin $enabledChoices) {
            $null = Choose-VisibleChoice -ChoiceId 'cage_buy_50' -Intent 'exchange visible cash for 50 Grand Casino chips'
        }
        elseif ('cage_buy_25' -cin $enabledChoices) {
            $null = Choose-VisibleChoice -ChoiceId 'cage_buy_25' -Intent 'exchange visible cash for 25 Grand Casino chips'
        }
        else {
            throw "Linda exposes no affordable chip purchase while the route needs $Minimum chips."
        }
        $afterChips = Get-RenderedHudInteger -Name chips -Context 'Post-purchase Grand Casino chip check'
        if ($afterChips -le $beforeChips) {
            throw "Linda's visible chip exchange made no public chip progress ($beforeChips -> $afterChips)."
        }
    }
    $chips = Get-RenderedHudInteger -Name chips -Context 'Final Grand Casino chip check'
    if ($chips -lt $Minimum) {
        throw "Grand Casino chip exchange did not reach $Minimum within $maximumChipPurchases bounded purchases (found $chips)."
    }
    $null = Choose-VisibleChoice -ChoiceId 'back_main' -Intent 'return to Linda''s main counter choices'
    $null = Choose-VisibleChoice -ChoiceId 'leave_counter' -Intent 'step away from Linda''s counter'
    Wait-Frames -Frames 8
}


function Enter-BlackjackTable {
    if ([string](Get-Value $script:LastObservation @('screen', 'screen') '') -ceq 'GAME' -and
        [string](Get-Value $script:LastObservation @('game', 'game_id') '') -ceq 'blackjack') {
        # Save -> relaunch -> Continue restores the locked Rourke table directly.
        # Preserve any live Blackjack surface before attempting room navigation.
        return
    }
    Enter-GrandRoom -Room main
    $null = Open-SemanticObject -SemanticId 'game:blackjack' -PreferredActions @('Enter', 'Play') -Intent 'sit at the visible blackjack table'
    Wait-Frames -Frames 12
    if ([string](Get-Value $script:LastObservation @('screen', 'screen') '') -cne 'GAME' -or
        [string](Get-Value $script:LastObservation @('game', 'game_id') '') -cne 'blackjack') {
        throw "The visible blackjack table did not open the blackjack surface."
    }
}


function Leave-GameSurface {
    if ([string](Get-Value $script:LastObservation @('screen', 'screen') '') -cne 'GAME') { return }
    if ([bool](Get-Value $script:LastObservation @('event_popup', 'visible') $false) -or
        [bool](Get-Value $script:LastObservation @('talk', 'visible') $false)) {
        throw 'The game surface cannot be left while a visible decision is unresolved.'
    }
    $back = Find-GameAction -Action 'surface_back'
    if ($null -ceq $back) { $back = Find-GameAction -Action 'leave_game' }
    if ($null -ceq $back) {
        throw "The active game surface exposes no visible leave action."
    }
    $action = [string](Get-Value $back @('action') '')
    $index = [int](Get-Value $back @('index') 0)
    $null = Invoke-BridgeCommand -Command "click_action $action $index" -Intent 'leave the game through its visible back control'
    Wait-Frames -Frames 10
    if ([string](Get-Value $script:LastObservation @('screen', 'screen') '') -ceq 'GAME') {
        throw "The visible game back control did not return to the room."
    }
}


function Get-ActiveBlackjackTotal {
    # The rendered game projection publishes the active hand's total at the
    # surface level. Public player-hand rows intentionally expose cards and
    # status only, so reading a nonexistent per-row `total` silently produced
    # zero and made the normal policy hit even on completed 17+ hands.
    return Get-ExactReplayInt32 `
        -InputObject $script:LastObservation `
        -Path @('game', 'blackjack_total') `
        -Context 'Public active blackjack total'
}


function Invoke-PublicBlackjackDecision {
    $total = Get-ActiveBlackjackTotal
    $canHit = [bool](Get-Value $script:LastObservation @('game', 'can_hit') $false)
    $canStand = [bool](Get-Value $script:LastObservation @('game', 'can_stand') $false)
    if ($total -lt 17 -and $canHit -and $null -cne (Find-GameAction -Action 'blackjack_hit')) {
        $null = Invoke-GameAction -Action 'blackjack_hit' -Intent "hit the public $total blackjack hand"
        return
    }
    if ($canStand -and $null -cne (Find-GameAction -Action 'blackjack_stand')) {
        $null = Invoke-GameAction -Action 'blackjack_stand' -Intent "stand on the public $total blackjack hand"
        return
    }
    if ($canHit -and $null -cne (Find-GameAction -Action 'blackjack_hit')) {
        $null = Invoke-GameAction -Action 'blackjack_hit' -Intent "take the only visible legal hit on the public $total hand"
        return
    }
    throw "Blackjack decision phase exposes neither a public hit nor stand."
}


function Invoke-PublicBossCalloutIfShown {
    $tell = [string](Get-Value $script:LastObservation @('game', 'boss_tell') '')
    if ([string]::IsNullOrWhiteSpace($tell)) { return }

    # Rourke renders the tell while the wager is staged, but the matching
    # callout is intentionally disabled until Deal. The public policy therefore
    # validates the tell now and either defers or returns its exact post-deal row.
    $selection = Select-CheatReplayBossCalloutAction `
        -Game (Get-Value $script:LastObservation @('game') $null) `
        -SurfaceActions @(Get-GameActions)
    if ([string]$selection.stage -cne 'call') { return }

    $index = [int]$selection.index
    $label = [string](Get-Value (Get-Array (Get-Value $script:LastObservation @('game', 'boss_callouts') @()))[$index] @('label') '')
    $null = Invoke-GameAction -Action 'blackjack_boss_callout' -Index $index -Intent "call Rourke's publicly rendered $tell tell with $label"
    Wait-Frames -Frames 4
    if (Test-PublicTerminalSurface) { return }
    $used = Get-Value $script:LastObservation @('game', 'boss_callout_used') $null
    if ($used -isnot [bool] -or -not [bool]$used) {
        throw "Rourke's rendered callout did not produce an exact public used witness."
    }
}


function Invoke-VisibleCheatIfAvailable {
    $openedWindow = $false
    for ($transition = 0; $transition -lt 3; $transition++) {
        $selection = Select-CheatReplayBlackjackCheatAction `
            -Game (Get-Value $script:LastObservation @('game') $null) `
            -SurfaceActions @(Get-GameActions)
        switch ([string]$selection.stage) {
            'wait_for_deal' { return $false }
            'complete' { return $false }
            'open_window' {
                if ($openedWindow) {
                    throw 'The rendered Distraction control did not open its public Peek window.'
                }
                $null = Invoke-GameAction -Action 'blackjack_distraction' -Index ([int]$selection.index) -Intent "open the rendered lookaway window for the published peek_hole_card cheat"
                Wait-Frames -Frames 4
                $windowOpen = Get-Value $script:LastObservation @('game', 'peek_window_open') $null
                if ($windowOpen -isnot [bool] -or -not [bool]$windowOpen) {
                    throw 'The rendered Distraction control did not expose an exact open Peek-window witness.'
                }
                $openedWindow = $true
                continue
            }
            'peek' {
                $null = Invoke-GameAction -Action 'blackjack_peek' -Index ([int]$selection.index) -Intent "use the rendered Peek control authorized by published cheat id peek_hole_card"
                Wait-Frames -Frames 4
                $holeVisible = Get-Value $script:LastObservation @('game', 'dealer_hole_visible') $null
                if ($holeVisible -isnot [bool] -or -not [bool]$holeVisible) {
                    throw "The published 'peek_hole_card' cheat did not produce an exact visible-hole-card witness."
                }
                return $true
            }
            default { throw "Unknown public Blackjack cheat-policy stage '$($selection.stage)'." }
        }
    }
    throw "The published 'peek_hole_card' sequence did not finish within three public transitions."
}


function Ensure-BlackjackStakeRange {
    param(
        [ValidateRange(1, 500)][int]$Minimum = 8,
        [ValidateRange(1, 500)][int]$Maximum = 30
    )
    $stake = [int](Get-Value $script:LastObservation @('game', 'selected_stake') 0)
    if ($stake -ge $Minimum -and $stake -le $Maximum) { return }
    if ($stake -gt $Maximum) {
        $clearAction = @('blackjack_clear_bet', 'surface_stake_down') | Where-Object {
            $null -cne (Find-GameAction -Action $_)
        } | Select-Object -First 1
        if ([string]::IsNullOrWhiteSpace([string]$clearAction)) {
            throw "The visible blackjack stake is $stake, above the heist ceiling $Maximum, and exposes no clear control."
        }
        $null = Invoke-GameAction -Action ([string]$clearAction) -Intent 'clear the visible blackjack wager before setting a boring heist stake'
        Wait-Frames -Frames 6
    }
    for ($chip = 0; $chip -lt 40; $chip++) {
        $stake = [int](Get-Value $script:LastObservation @('game', 'selected_stake') 0)
        if ($stake -ge $Minimum -and $stake -le $Maximum) { return }
        if ($stake -gt $Maximum) {
            throw "The visible blackjack wager jumped above the heist ceiling ($stake > $Maximum)."
        }
        $placeAction = @('blackjack_wager_place_gesture', 'blackjack_chip', 'surface_stake_up') | Where-Object {
            $null -cne (Find-GameAction -Action $_)
        } | Select-Object -First 1
        if ([string]::IsNullOrWhiteSpace([string]$placeAction)) {
            throw "The blackjack surface exposes no production wager control below the heist minimum $Minimum."
        }
        $null = Invoke-GameAction -Action ([string]$placeAction) -Intent 'place one visible blackjack chip for a boring heist stake'
        Wait-Frames -Frames 4
    }
    throw "The visible blackjack wager could not be set inside $Minimum-$Maximum within 40 chip placements."
}


function Get-CleanPublicCasinoTotal {
    $bankroll = Get-RenderedHudInteger -Name bankroll -Context 'Clean Players Card bankroll'
    $chips = Get-RenderedHudInteger -Name chips -Context 'Clean Players Card chips'
    return $bankroll + $chips
}


function Set-CleanBlackjackStake {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('minimum', 'maximum', 'followup')]
        [string]$Mode
    )

    $phase = Get-ExactReplayString -InputObject $script:LastObservation -Path @('game', 'phase') -Context 'Clean blackjack wager phase'
    if ($phase -cne 'betting') {
        throw "Clean blackjack wager selection requires the visible betting phase, found '$phase'."
    }
    $minimum = Get-ExactReplayInt32 -InputObject $script:LastObservation -Path @('game', 'stake_min') -Context 'Clean blackjack table minimum'
    $maximum = Get-ExactReplayInt32 -InputObject $script:LastObservation -Path @('game', 'stake_max') -Context 'Clean blackjack table maximum'
    $selected = Get-ExactReplayInt32 -InputObject $script:LastObservation -Path @('game', 'selected_stake') -Context 'Clean blackjack selected stake'
    if ($minimum -le 0 -or $maximum -lt $minimum -or $selected -lt $minimum -or $selected -gt $maximum) {
        throw "Clean blackjack exposed an invalid public stake range ($minimum <= $selected <= $maximum)."
    }

    if ($Mode -ceq 'maximum') {
        if ($selected -ne $maximum) {
            if ($null -ceq (Find-GameAction -Action 'blackjack_max_bet')) {
                throw 'Clean blackjack exposes no visible MAX control during its public betting phase.'
            }
            $null = Invoke-GameAction -Action 'blackjack_max_bet' -Intent 'press the visible clean-route blackjack wager to the table maximum'
            Wait-Frames -Frames 4
        }
        $afterMaximum = Get-ExactReplayInt32 -InputObject $script:LastObservation -Path @('game', 'selected_stake') -Context 'Clean blackjack maximum stake result'
        if ($afterMaximum -cne $maximum) {
            throw "The visible blackjack MAX control did not select the published table maximum ($afterMaximum != $maximum)."
        }
        return
    }

    if ($selected -ne $minimum) {
        if ($null -ceq (Find-GameAction -Action 'blackjack_clear_bet')) {
            throw 'Clean blackjack exposes no visible CLR control while returning to the table minimum.'
        }
        $null = Invoke-GameAction -Action 'blackjack_clear_bet' -Intent 'return the visible clean-route blackjack wager to the table minimum'
        Wait-Frames -Frames 4
    }
    $afterClear = Get-ExactReplayInt32 -InputObject $script:LastObservation -Path @('game', 'selected_stake') -Context 'Clean blackjack minimum stake result'
    if ($afterClear -cne $minimum) {
        throw "The visible blackjack CLR control did not restore the published table minimum ($afterClear != $minimum)."
    }
    if ($Mode -ceq 'minimum') { return }

    # After a profitable hand leaves the Gold segment just short, build the
    # moderate follow-up wager entirely through ordinary rendered buttons. A
    # rail-chip tap is a captured pointer gesture whose release is intentionally
    # cancelled while this confirmation bridge owns the application pause.
    # MAX, REMOVE, and UNDO expose the same public wager authority without
    # depending on a gesture that cannot complete across that pause boundary.
    $followupTarget = [Math]::Min($maximum, $minimum + 10)
    if ($followupTarget -le $minimum) {
        return
    }
    if ($null -ceq (Find-GameAction -Action 'blackjack_max_bet')) {
        throw 'Clean blackjack exposes no visible MAX control for its moderate follow-up wager.'
    }
    $null = Invoke-GameAction -Action 'blackjack_max_bet' -Intent 'stage the visible maximum before trimming the clean-route follow-up wager'
    Wait-Frames -Frames 4
    $currentStake = Get-ExactReplayInt32 -InputObject $script:LastObservation -Path @('game', 'selected_stake') -Context 'Clean blackjack follow-up maximum result'
    if ($currentStake -cne $maximum) {
        throw "The visible MAX control did not stage the published follow-up ceiling ($currentStake != $maximum)."
    }

    $removeIndices = @(Get-GameActions | Where-Object {
        [string](Get-Value $_ @('action') '') -ceq 'blackjack_remove_chip' -and
            [bool](Get-Value $_ @('enabled') $false)
    } | ForEach-Object {
        [int](Get-Value $_ @('index') -1)
    } | Sort-Object -Descending -Unique)
    if ($removeIndices.Count -lt 1) {
        throw 'Clean blackjack exposes no visible chip-removal controls for its moderate follow-up wager.'
    }

    foreach ($removeIndex in $removeIndices) {
        while ($currentStake -gt $followupTarget) {
            $beforeRemove = $currentStake
            $null = Invoke-GameAction `
                -Action 'blackjack_remove_chip' `
                -Index ([int]$removeIndex) `
                -Intent 'trim the visible clean-route blackjack wager toward its moderate follow-up stake'
            Wait-Frames -Frames 4
            $currentStake = Get-ExactReplayInt32 -InputObject $script:LastObservation -Path @('game', 'selected_stake') -Context 'Clean blackjack trimmed follow-up stake'
            if ($currentStake -ge $followupTarget -and $currentStake -lt $beforeRemove) {
                continue
            }
            if ($currentStake -lt $followupTarget) {
                if ($null -ceq (Find-GameAction -Action 'blackjack_undo_bet')) {
                    throw 'Clean blackjack overshot its follow-up stake without a visible UNDO control.'
                }
                $null = Invoke-GameAction -Action 'blackjack_undo_bet' -Intent 'undo the visible chip removal that crossed the clean-route follow-up stake'
                Wait-Frames -Frames 4
                $currentStake = Get-ExactReplayInt32 -InputObject $script:LastObservation -Path @('game', 'selected_stake') -Context 'Clean blackjack restored follow-up stake'
                if ($currentStake -cne $beforeRemove) {
                    throw "The visible UNDO control restored an unexpected follow-up stake ($currentStake != $beforeRemove)."
                }
                break
            }
            throw "The visible chip-removal control did not reduce the follow-up stake ($beforeRemove -> $currentStake)."
        }
        if ($currentStake -ceq $followupTarget) { break }
    }
    if ($currentStake -cne $followupTarget) {
        throw "The visible wager controls did not reach the expected public follow-up stake ($currentStake != $followupTarget)."
    }
}


function Resolve-BlackjackRouteEventPopup {
    if (@('clean', 'cheat', 'heist') -cnotcontains $Ending) { return $false }

    $eventVisible = Get-Value $script:LastObservation @('event_popup', 'visible') $null
    if ($eventVisible -isnot [bool]) {
        throw 'The public event-popup visibility witness is missing during Blackjack.'
    }
    if (-not [bool]$eventVisible) { return $false }

    for ($poll = 0; $poll -lt 16; $poll++) {
        $renderValid = Get-Value $script:LastObservation @('event_popup', 'render_valid') $null
        if ($renderValid -is [bool] -and [bool]$renderValid) { break }
        Wait-Frames -Frames 4 -Intent 'let the visible Blackjack interruption finish rendering'
        $eventVisible = Get-Value $script:LastObservation @('event_popup', 'visible') $null
        if ($eventVisible -isnot [bool] -or -not [bool]$eventVisible) {
            throw 'The Blackjack interruption disappeared before its visible choices became actionable.'
        }
    }

    $renderValid = Get-Value $script:LastObservation @('event_popup', 'render_valid') $null
    if ($renderValid -isnot [bool] -or -not [bool]$renderValid) {
        throw 'The visible Blackjack interruption did not finish rendering within 64 public frames.'
    }
    $eventId = [string](Get-Value $script:LastObservation @('event_popup', 'event_id') '')
    if ($eventId -cne 'eye_in_the_sky') {
        throw "Unexpected visible event interrupted the $Ending Blackjack route: '$eventId'."
    }
    $choiceIds = @(Get-VisibleChoiceIds)
    $expectedChoiceIds = @('change_table', 'press_anyway')
    if (($choiceIds -join ',') -cne ($expectedChoiceIds -join ',')) {
        throw "Eye in the Sky exposed unexpected choices: $($choiceIds -join ', ')."
    }

    $choiceId = if ($Ending -ceq 'clean') { 'change_table' } else { 'press_anyway' }
    $intent = if ($Ending -ceq 'clean') {
        'change tables through the visible Eye in the Sky response and cool the clean route'
    }
    else {
        'press on through the visible Eye in the Sky response and keep drawing Rourke''s attention'
    }
    $null = Choose-VisibleChoice -ChoiceId $choiceId -Intent $intent
    Wait-Frames -Frames 12 -Intent 'let the visible Eye in the Sky response settle'
    if ([bool](Get-Value $script:LastObservation @('event_popup', 'visible') $false)) {
        throw "The visible Eye in the Sky response '$choiceId' did not close its decision surface."
    }
    return $true
}


function Play-OneBlackjackRound {
    param(
        [switch]$UseVisibleCheat,
        [switch]$UseHeistStake,
        [ValidateSet('unchanged', 'minimum', 'maximum', 'followup')]
        [string]$CleanStakeMode = 'unchanged'
    )
    Enter-BlackjackTable
    if ($UseHeistStake) {
        Ensure-BlackjackStakeRange -Minimum 8 -Maximum 30
    }
    if ($CleanStakeMode -cne 'unchanged') {
        if ($Ending -cne 'clean') {
            throw "Clean blackjack stake mode '$CleanStakeMode' was requested for ending '$Ending'."
        }
        Set-CleanBlackjackStake -Mode $CleanStakeMode
    }
    $beforeHand = [int](Get-Value $script:LastObservation @('game', 'boss_hand_number') 0)
    $roundStarted = [string](Get-Value $script:LastObservation @('game', 'phase') '') -cne 'betting'

    # A full hand can cross several intentionally paced presentation windows
    # (deal, each decision, dealer reveal, and settle). Keep the route bounded,
    # but do not spend the entire allowance merely waiting for controls to light.
    for ($step = 0; $step -lt 120; $step++) {
        if (Test-PublicTerminalSurface) { return }
        $eventVisible = [bool](Get-Value $script:LastObservation @('event_popup', 'visible') $false)
        $talkVisible = [bool](Get-Value $script:LastObservation @('talk', 'visible') $false)
        if ($eventVisible -and (@('clean', 'cheat') -ccontains $Ending)) {
            $null = Resolve-BlackjackRouteEventPopup
            continue
        }
        if ($talkVisible -and -not $eventVisible -and @('clean', 'cheat') -ccontains $Ending) {
            $talkEventId = [string](Get-Value $script:LastObservation @('talk', 'event_id') '')
            if ($Ending -ceq 'clean' -and $talkEventId -ceq 'shift_change') {
                $choiceIds = @(Get-VisibleChoiceIds)
                $expectedChoiceIds = @('position', 'ignore')
                if (($choiceIds -join ',') -cne ($expectedChoiceIds -join ',')) {
                    throw "The visible Clean shift change exposed unexpected choices: $($choiceIds -join ', ')."
                }
                $null = Choose-VisibleChoice `
                    -ChoiceId 'ignore' `
                    -Intent 'let the visible shift change pass without using it for an advantage'
                Wait-Frames -Frames 10 -Intent 'let the visible Clean shift-change response settle'
                continue
            }
            if ($talkEventId -ceq 'blackjack_counter_probe') {
                $choiceIds = @(Get-VisibleChoiceIds)
                $expectedChoiceIds = @('play_dumb', 'trade_count', 'ignore')
                if (($choiceIds -join ',') -cne ($expectedChoiceIds -join ',')) {
                    throw "The visible blackjack counter probe exposed unexpected choices: $($choiceIds -join ', ')."
                }
                $null = Choose-VisibleChoice `
                    -ChoiceId 'play_dumb' `
                    -Intent 'count badly for Mina and cool the normal blackjack table without taking an edge'
                Wait-Frames -Frames 10 -Intent 'let the visible counter-probe response settle'
                continue
            }
            if ($Ending -ceq 'cheat' -and $talkEventId -ceq 'floor_staff_heat_warning') {
                $choiceIds = @(Get-VisibleChoiceIds)
                $expectedChoiceIds = @('play_cool', 'buy_round', 'talk_back')
                if (($choiceIds -join ',') -cne ($expectedChoiceIds -join ',')) {
                    throw "The visible floor-staff warning exposed unexpected choices: $($choiceIds -join ', ')."
                }
                $null = Choose-VisibleChoice `
                    -ChoiceId 'talk_back' `
                    -Intent 'talk back through the visible floor-staff warning and draw Rourke''s attention'
                Wait-Frames -Frames 10 -Intent 'let the visible floor-staff response settle'
                continue
            }
            if ($Ending -ceq 'cheat' -and $talkEventId -ceq 'pit_boss_heat_warning') {
                $choiceIds = @(Get-VisibleChoiceIds)
                $expectedChoiceIds = @('walk_now', 'bluff', 'slip_bribe')
                if (($choiceIds -join ',') -cne ($expectedChoiceIds -join ',')) {
                    throw "The visible pit-boss warning exposed unexpected choices: $($choiceIds -join ', ')."
                }
                $null = Choose-VisibleChoice `
                    -ChoiceId 'walk_now' `
                    -Intent 'walk away through Rourke''s visible warning and answer the house call'
                Wait-Frames -Frames 10 -Intent 'let the visible pit-boss response settle'
                continue
            }
        }
        if ($eventVisible -or $talkVisible) {
            throw "A modal interrupted blackjack; the route must resolve it explicitly. Choices: $((Get-VisibleChoiceIds) -join ', ')"
        }

        $bossHandNow = [int](Get-Value $script:LastObservation @('game', 'boss_hand_number') 0)
        $outcomeNow = [string](Get-Value $script:LastObservation @('game', 'outcome_message') '')
        $phaseNow = [string](Get-Value $script:LastObservation @('game', 'phase') '')
        $cleanWagerControlsReady = $Ending -cne 'clean' -or $null -ne (Find-GameAction -Action 'blackjack_deal')
        if (($bossHandNow -gt $beforeHand) -or
            ($roundStarted -and -not [string]::IsNullOrWhiteSpace($outcomeNow) -and
                $phaseNow -ceq 'betting' -and $cleanWagerControlsReady)) {
            return
        }
        if ($UseVisibleCheat -and $phaseNow -ceq 'barred') {
            $barredTransition = Select-CheatReplayPostPeekTransition `
                -Game (Get-Value $script:LastObservation @('game') $null) `
                -StatusHud (Get-Value $script:LastObservation @('status_hud') $null) `
                -SurfaceActions @(Get-GameActions)
            if ([string]$barredTransition.stage -cne 'leave_for_showdown') {
                throw "Unknown public barred-table transition '$($barredTransition.stage)'."
            }
            return
        }
        $retryPendingAction = Find-GameAction -Action 'blackjack_retry_pending'
        if ($Ending -ceq 'clean' -and $null -cne $retryPendingAction) {
            $null = Invoke-GameAction `
                -Action 'blackjack_retry_pending' `
                -Intent 'retry the visible sealed blackjack action before continuing the Clean card ladder'
            Wait-Frames -Frames 12 -Intent 'let the visible sealed Clean blackjack action finish delivery'
            continue
        }
        if ([bool](Get-Value $script:LastObservation @('game', 'boss_duel_active') $false) -and
            $null -cne $retryPendingAction) {
            $null = Invoke-GameAction `
                -Action 'blackjack_retry_pending' `
                -Intent 'retry the visible sealed duel action before Rourke deals the next hand'
            Wait-Frames -Frames 12 -Intent 'let the visible sealed duel action finish delivery'
            continue
        }

        Invoke-PublicBossCalloutIfShown
        $phase = [string](Get-Value $script:LastObservation @('game', 'phase') '')
        $peekApplied = $false
        if ($UseVisibleCheat) {
            $peekApplied = Invoke-VisibleCheatIfAvailable
            if ($peekApplied -isnot [bool]) {
                throw 'Visible Peek did not return an exact public applied-state witness.'
            }
        }
        if ([bool]$peekApplied) {
            $postPeek = Select-CheatReplayPostPeekTransition `
                -Game (Get-Value $script:LastObservation @('game') $null) `
                -StatusHud (Get-Value $script:LastObservation @('status_hud') $null) `
                -SurfaceActions @(Get-GameActions)
            if ([string]$postPeek.stage -ceq 'leave_for_showdown') {
                return
            }
            if ([string]$postPeek.stage -cne 'continue_hand') {
                throw "Unknown public post-Peek transition '$($postPeek.stage)'."
            }
            $phase = [string](Get-Value $script:LastObservation @('game', 'phase') '')
        }
        if ($null -cne (Find-GameAction -Action 'blackjack_settle')) {
            $null = Invoke-GameAction -Action 'blackjack_settle' -Intent 'settle the publicly completed blackjack hand'
            Wait-Frames -Frames 12
            continue
        }
        $hitAction = Find-GameAction -Action 'blackjack_hit'
        $standAction = Find-GameAction -Action 'blackjack_stand'
        if ($null -ne $hitAction -or $null -ne $standAction) {
            Invoke-PublicBlackjackDecision
            Wait-Frames -Frames 24
            continue
        }
        if ($null -cne (Find-GameAction -Action 'blackjack_deal')) {
            $null = Invoke-GameAction -Action 'blackjack_deal' -Intent 'deal the next blackjack hand at the visible wager'
			$roundStarted = $true
            Wait-Frames -Frames 30
            continue
        }
        Wait-Frames -Frames 20
    }
    throw "Blackjack did not visibly settle within 120 public presentation or decision steps."
}


function Wait-ForFullyRenderedTalkSurface {
    param(
        [Parameter(Mandatory = $true)][string]$Intent,
        [ValidateRange(1, 64)][int]$MaximumPolls = 48
    )
    for ($poll = 0; $poll -lt $MaximumPolls; $poll++) {
        $eventVisible = Get-Value $script:LastObservation @('event_popup', 'visible') $null
        $talkVisible = Get-Value $script:LastObservation @('talk', 'visible') $null
        if ($eventVisible -isnot [bool] -or $talkVisible -isnot [bool]) {
            throw "$Intent lost its exact boolean modal visibility signals."
        }
        if ([bool]$eventVisible) {
            throw "$Intent encountered an unrelated visible event popup."
        }
        if ([bool]$talkVisible) {
            $expanded = Get-Value $script:LastObservation @('talk', 'expanded') $null
            $renderValid = Get-Value $script:LastObservation @('talk', 'render_valid') $null
            $bodyComplete = Get-Value $script:LastObservation @('talk', 'body_complete') $null
            $typewriterActive = Get-Value $script:LastObservation @('talk', 'typewriter_active') $null
            if ($expanded -is [bool] -and [bool]$expanded -and
                $renderValid -is [bool] -and [bool]$renderValid -and
                $bodyComplete -is [bool] -and [bool]$bodyComplete -and
                $typewriterActive -is [bool] -and -not [bool]$typewriterActive -and
                @(Get-PublicTalkChoices).Count -gt 0) {
                return
            }
        }
        Wait-Frames -Frames 4 -Intent "wait for $Intent to finish rendering"
    }
    throw "$Intent did not become fully rendered within the bounded public wait."
}


function Get-CleanSilverPlayersCardProjection {
    Open-CageCounter
    $null = Choose-VisibleChoice -ChoiceId 'open_card' -Intent "open Linda's rendered Silver Players Card ledger for persistence evidence"
    Wait-ForFullyRenderedTalkSurface -Intent "Linda's Silver Players Card ledger"

    $talk = Get-ExactReplayPsCustomObject -InputObject $script:LastObservation -Path @('talk') -Context "Clean Players Card talk projection"
    $talkVisible = Get-ExactReplayBoolean -InputObject $talk -Path @('visible') -Context 'Clean Players Card talk visibility'
    $talkExpanded = Get-ExactReplayBoolean -InputObject $talk -Path @('expanded') -Context 'Clean Players Card talk expansion'
    $talkRenderValid = Get-ExactReplayBoolean -InputObject $talk -Path @('render_valid') -Context 'Clean Players Card render witness'
    $talkBodyComplete = Get-ExactReplayBoolean -InputObject $talk -Path @('body_complete') -Context 'Clean Players Card body witness'
    $talkTypewriterActive = Get-ExactReplayBoolean -InputObject $talk -Path @('typewriter_active') -Context 'Clean Players Card typewriter witness'
    $talkEventId = Get-ExactReplayString -InputObject $talk -Path @('event_id') -Context 'Clean Players Card talk event id'
    $summary = Get-ExactReplayString -InputObject $talk -Path @('summary') -Context 'Clean Players Card summary'
    if (-not $talkVisible -or
        -not $talkExpanded -or
        -not $talkRenderValid -or
        -not $talkBodyComplete -or
        $talkTypewriterActive -or
        $talkEventId -cne 'dialogue:linda_cage_services' -or
        -not $summary.StartsWith('Silver. Gold:', [StringComparison]::Ordinal)) {
        throw "The Clean persistence checkpoint did not render Linda's exact Silver-to-Gold Players Card ledger."
    }

    $choiceIds = Get-ExactReplayObjectArray -InputObject $talk -Path @('choice_ids') -ElementType String -Context "Clean Players Card choice ids"
    $expectedChoiceIds = @('cage_claim_card', 'cage_ambient', 'back_main')
    if (($choiceIds -join ',') -cne ($expectedChoiceIds -join ',')) {
        throw "Linda's Silver Players Card ledger exposed unexpected rendered choices: $($choiceIds -join ', ')."
    }
    $renderedChoices = Get-ExactReplayObjectArray `
        -InputObject $script:LastResult `
        -Path @('look', 'clickable', 'talk_choices') `
        -ElementType PSCustomObject `
        -Context 'Clean Players Card rendered choices'
    if ($renderedChoices.Count -cne $expectedChoiceIds.Count) {
        throw "Linda's Silver Players Card ledger did not expose all three exact rendered controls."
    }
    $expectedLabels = @{
        cage_ambient = 'Ask Linda'
        back_main = 'Back'
    }
    $projectionChoices = @()
    for ($index = 0; $index -lt $expectedChoiceIds.Count; $index++) {
        $choice = $renderedChoices[$index]
        $choiceId = Get-ExactReplayString -InputObject $choice -Path @('id') -Context "Clean Players Card choice $index id"
        $choiceEventId = Get-ExactReplayString -InputObject $choice -Path @('event_id') -Context "Clean Players Card choice $index event id"
        $choiceLabel = Get-ExactReplayString -InputObject $choice -Path @('label') -Context "Clean Players Card choice $index label"
        $choiceEnabled = Get-ExactReplayBoolean -InputObject $choice -Path @('enabled') -Context "Clean Players Card choice $index enabled witness"
        $expectedChoiceId = $expectedChoiceIds[$index]
        $labelIsExact = if ($expectedChoiceId -ceq 'cage_claim_card') {
            $choiceLabel.StartsWith("Claim Players Card`n", [StringComparison]::Ordinal) -and
                $choiceLabel.Length -gt 'Claim Players Card'.Length + 1
        }
        else {
            $choiceLabel -ceq [string]$expectedLabels[$expectedChoiceId]
        }
        if ($choiceId -cne $expectedChoiceId -or
            $choiceEventId -cne 'dialogue:linda_cage_services' -or
            -not $labelIsExact) {
            throw "Linda's Silver Players Card control '$expectedChoiceId' lacked its exact rendered public binding."
        }
        $projectionChoices += [pscustomobject][ordered]@{
            id = $choiceId
            label = $choiceLabel
            enabled = $choiceEnabled
        }
    }
    if ($projectionChoices[0].enabled -or
        -not $projectionChoices[1].enabled -or
        -not $projectionChoices[2].enabled) {
        throw "Linda's post-Silver ledger did not show Gold as pending with only Ask Linda and Back enabled."
    }

    $locationArchetype = Get-ExactReplayString `
        -InputObject $script:LastObservation `
        -Path @('environment', 'archetype_id') `
        -Context "Clean Players Card location archetype"
    $projection = [ordered]@{
        location_archetype = $locationArchetype
        talk_event_id = $talkEventId
        tier_witness = 'Silver'
        next_tier_witness = 'Gold'
        summary = $summary
        choice_ids = @($choiceIds)
        choices = $projectionChoices
    }
    if ($projection.location_archetype -cne 'grand_casino_cage') {
        throw "Linda's rendered Silver Players Card ledger was not observed in the Grand Casino Cage."
    }
    $null = Choose-VisibleChoice -ChoiceId 'back_main' -Intent "return from Linda's rendered Silver Players Card ledger"
    $null = Choose-VisibleChoice -ChoiceId 'leave_counter' -Intent "close Linda's Cage counter after retaining the Silver Players Card evidence"
    Wait-Frames -Frames 8
    return [pscustomobject]$projection
}


function Get-PersistenceCheckpoint {
    $game = Get-ExactReplayPsCustomObject -InputObject $script:LastObservation -Path @('game') -Context 'Persistence checkpoint game projection'
    return [ordered]@{
        location_id = Get-ExactReplayString -InputObject $script:LastObservation -Path @('environment', 'id') -Context 'Persistence checkpoint location id'
        location_archetype = Get-ExactReplayString -InputObject $script:LastObservation -Path @('environment', 'archetype_id') -Context 'Persistence checkpoint location archetype'
        world_node_id = Get-ExactReplayString -InputObject $script:LastObservation -Path @('environment', 'world_node_id') -Context 'Persistence checkpoint world node id'
        bankroll = Get-RenderedHudInteger -Name bankroll -Context 'Persistence checkpoint'
        chips = Get-RenderedHudInteger -Name chips -Context 'Persistence checkpoint'
        heat = Get-RenderedHudInteger -Name heat_level -Context 'Persistence checkpoint'
        game_id = Get-ExactReplayString -InputObject $game -Path @('game_id') -Context 'Persistence checkpoint game id' -AllowMissing
        game_phase = Get-ExactReplayString -InputObject $game -Path @('phase') -Context 'Persistence checkpoint game phase' -AllowMissing
        boss_hand_number = Get-ExactReplayInt32 -InputObject $game -Path @('boss_hand_number') -Context 'Persistence checkpoint boss hand number' -AllowMissing
        boss_player_stack = Get-ExactReplayInt32 -InputObject $game -Path @('boss_player_stack') -Context 'Persistence checkpoint player stack' -AllowMissing
        boss_rourke_stack = Get-ExactReplayInt32 -InputObject $game -Path @('boss_rourke_stack') -Context 'Persistence checkpoint Rourke stack' -AllowMissing
    }
}


function Assert-CheatRourkeDuelBeforeHandOne {
    param([Parameter(Mandatory = $true)][string]$Context)

    $game = (Get-Rw062RequiredPublicPropertyDescriptor `
        -InputObject $script:LastObservation `
        -Name 'game' `
        -Context "Rourke's duel $Context observation").Value
    $look = (Get-Rw062RequiredPublicPropertyDescriptor `
        -InputObject $script:LastResult `
        -Name 'look' `
        -Context "Rourke's duel $Context bridge result").Value
    $clickable = (Get-Rw062RequiredPublicPropertyDescriptor `
        -InputObject $look `
        -Name 'clickable' `
        -Context "Rourke's duel $Context public look").Value
    $surfaceActions = (Get-Rw062RequiredPublicPropertyDescriptor `
        -InputObject $clickable `
        -Name 'game_surface_actions' `
        -Context "Rourke's duel $Context public clickable surface").Value
    $selection = Select-CheatReplayDuelCheckpointAction -Game $game -SurfaceActions $surfaceActions
    if ($selection -isnot [System.Management.Automation.PSCustomObject] -or
        $selection.action -isnot [string] -or $selection.action -cne 'blackjack_deal' -or
        $selection.index -isnot [int32] -or $selection.index -ne 0) {
        throw "Rourke's duel $Context did not return the exact public Deal selection."
    }
}


function Assert-ExplicitSaveAcknowledgmentObservation {
    param(
        [Parameter(Mandatory = $true)]$Observation,
        [Parameter(Mandatory = $true)][string]$Milestone
    )
    $hasSave = Get-Value $Observation @('screen', 'run_menu', 'has_save') $null
    $saveTextVisible = Get-Value $Observation @('status_hud', 'save_text_visible') $null
    $saveText = Get-Value $Observation @('status_hud', 'save_text') $null
    $separator = " $([char]0x00B7) "
    $acknowledgment = 'Saved to Resume Slot.'
    $expectedVisibleText = "Autosave On$separator$acknowledgment"
    if ($hasSave -isnot [bool] -or -not [bool]$hasSave -or
        $saveTextVisible -isnot [bool] -or -not [bool]$saveTextVisible -or
        $saveText -isnot [string] -or [string]$saveText -cne $expectedVisibleText) {
        throw "The explicit Save at $Milestone did not render the exact success acknowledgment '$acknowledgment' (found '$saveText', visible=$saveTextVisible, has_save=$hasSave)."
    }
    return $true
}


function Assert-ExplicitSaveAcknowledged {
    param([Parameter(Mandatory = $true)][string]$Milestone)
    return Assert-ExplicitSaveAcknowledgmentObservation -Observation $script:LastObservation -Milestone $Milestone
}


function Assert-SaveRelaunchContinue {
    param([Parameter(Mandatory = $true)][string]$Milestone)
    if ($Ending -ceq 'clean' -and $Milestone -cne 'Silver Players Card') {
        throw "The Clean route may retain persistence evidence only at the exact Silver Players Card milestone."
    }
    if ($Ending -ceq 'cheat' -and $Milestone -cne 'Rourke duel before hand one') {
        throw "The Cheat route may retain persistence evidence only before hand one of Rourke's active, dealable duel."
    }
    if ($Ending -ceq 'cheat') {
        Assert-CheatRourkeDuelBeforeHandOne -Context 'before Save'
    }
    $beforeCleanPlayersCard = if ($Ending -ceq 'clean') { Get-CleanSilverPlayersCardProjection } else { $null }
    $before = [ordered]@{
        checkpoint = Get-PersistenceCheckpoint
        clean_players_card = $beforeCleanPlayersCard
    }
    $beforeJson = $before | ConvertTo-Json -Depth 10 -Compress
    $null = Click-Button -Text 'Menu' -Intent "open the run menu at the $Milestone persistence checkpoint"
    $null = Click-RunMenuButton -Text 'Save' -RevealDirection up -Intent "save the run through the visible run menu at $Milestone"
    Assert-ExplicitSaveAcknowledged -Milestone $Milestone
    $null = Click-RunMenuButton -Text 'Main Menu' -RevealDirection down -Intent 'return to the main menu after the explicit save'
    if ([string](Get-Value $script:LastObservation @('screen', 'screen') '') -cne 'START') {
        throw "Main Menu did not return to the start screen after saving."
    }
    $null = Invoke-BridgeCommand -Command 'quit' -Intent 'quit the saved production host before relaunch' -ObservationOnly
    Wait-ForSessionExit
    Assert-NoPostExitLogAlerts
    Remove-OwnedBridgeCaptureResidue
    Start-BridgeSession
    if ([string](Get-Value $script:LastObservation @('screen', 'start_menu', 'primary_action_text') '') -cne 'CONTINUE') {
        throw "Relaunch after $Milestone did not expose CONTINUE."
    }
    $null = Click-Button -Text 'CONTINUE' -Intent "continue the saved $Milestone run after a full relaunch"
    Wait-Frames -Frames 45
    Clear-VisibleCoach
    if ($Ending -ceq 'cheat') {
        Assert-CheatRourkeDuelBeforeHandOne -Context 'after relaunch and Continue'
    }
    $afterCleanPlayersCard = if ($Ending -ceq 'clean') { Get-CleanSilverPlayersCardProjection } else { $null }
    $after = [ordered]@{
        checkpoint = Get-PersistenceCheckpoint
        clean_players_card = $afterCleanPlayersCard
    }
    $afterJson = $after | ConvertTo-Json -Depth 10 -Compress
    $before | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $script:RunRoot 'checkpoint_before.json') -Encoding utf8
    $after | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $script:RunRoot 'checkpoint_after.json') -Encoding utf8
    if ($afterJson -cne $beforeJson) {
        throw "Public persistence checkpoint changed across Save -> relaunch -> Continue at $Milestone."
    }
    Assert-DeltaQueenBeachRouteInvariant
    $script:MidpointSaved = $true
}


function Assert-TerminalOutcome {
    $screenName = Get-ExactReplayString -InputObject $script:LastObservation -Path @('screen', 'screen') -Context "Terminal screen for '$Ending'"
    $runReportVisible = Get-ExactReplayBoolean -InputObject $script:LastObservation -Path @('screen', 'run_report_visible') -Context "Terminal RunReport visibility for '$Ending'"
    $outcome = Get-ExactReplayString -InputObject $script:LastObservation -Path @('screen', 'run_report', 'outcome', 'key') -Context "Terminal outcome for '$Ending'"
    $won = Get-ExactReplayBoolean -InputObject $script:LastObservation -Path @('screen', 'run_report', 'outcome', 'won') -Context "Terminal win witness for '$Ending'"
    if ($screenName -cne 'VICTORY' -or -not $runReportVisible) {
        throw "Ending '$Ending' did not render the public VICTORY RunReport surface (screen='$screenName', visible=$runReportVisible)."
    }
    if (-not $won -or $outcome -cnotin $ExpectedOutcomes[$Ending]) {
        throw "Ending '$Ending' produced unexpected public outcome '$outcome' (won=$won)."
    }
    if (-not $ConfirmationOnly -and -not $script:MidpointSaved) {
        throw "Ending '$Ending' reached terminal state without the required Save -> relaunch -> Continue checkpoint."
    }
    if ($script:ActionCount -gt 350) {
        throw "Ending '$Ending' exceeded the 350-action normal-route ceiling ($($script:ActionCount))."
    }
    return $outcome
}


function Write-FinalPublicCheckpoint {
    # A terminal wait/look is observation-only and therefore is not written by
    # Write-ActionEvidence. Take one final authenticated public observation and
    # persist its outcome and visible economy explicitly into both hash streams.
    $result = Invoke-BridgeCommand -Command 'look' -Intent 'capture the final public terminal checkpoint' -ObservationOnly
    $outcome = Assert-TerminalOutcome
    $observation = Get-ExactReplayPsCustomObject -InputObject $result -Path @('look', 'observable') -Context 'Final public observation'
    $publicFingerprint = Get-ExactReplayString -InputObject $result -Path @('trace', 'after_fingerprint') -Context 'Final public fingerprint'
    $checkpointFingerprint = Get-ExactReplayString -InputObject $observation -Path @('checkpoint_fingerprint') -Context 'Final checkpoint fingerprint'
    $observedSeed = Get-ExactReplayString -InputObject $observation -Path @('screen', 'run_report', 'seed') -Context 'Final observed seed'
    if ($publicFingerprint -cnotmatch '^[a-f0-9]{64}$' -or $checkpointFingerprint -cnotmatch '^[a-f0-9]{64}$') {
        throw 'Final terminal observation did not publish complete authenticated public fingerprints.'
    }
    if ($observedSeed -cne $Seed) {
        throw "Terminal run report seed '$observedSeed' did not exactly match requested fixed seed '$Seed'."
    }
    $final = [ordered]@{
        schema_version = 1
        record_kind = 'final_public_checkpoint'
        observed_seed = $observedSeed
        outcome_key = $outcome
        won = $true
        public_fingerprint = $publicFingerprint
        checkpoint_fingerprint = $checkpointFingerprint
        bankroll = Get-RenderedHudInteger -Name bankroll -Context 'Final terminal checkpoint'
        chips = Get-RenderedHudInteger -Name chips -Context 'Final terminal checkpoint'
        heat = Get-RenderedHudInteger -Name heat_level -Context 'Final terminal checkpoint'
    }
    $finalObject = [pscustomobject]$final
    Assert-ExactFinalPublicCheckpoint -Checkpoint $finalObject -ExpectedSeed $Seed -Context 'Final public checkpoint'
    $finalJson = $finalObject | ConvertTo-Json -Compress
    Add-Content -LiteralPath $script:TranscriptPath -Value $finalJson -Encoding utf8
    Add-Content -LiteralPath $script:MoneyCurvePath -Value $finalJson -Encoding utf8
    $finalPath = Join-Path $script:RunRoot 'final_public_checkpoint.json'
    $finalObject | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $finalPath -Encoding utf8
    return $finalObject
}


function Visit-CageAndClaimReadyPlayersCard {
    Leave-GameSurface
    Open-CageCounter
    $null = Choose-VisibleChoice -ChoiceId 'open_card' -Intent "open Linda's visible Players Card review"
    Wait-ForFullyRenderedTalkSurface -Intent "Linda's Players Card review"

    $claimMatches = @(Get-PublicTalkChoices | Where-Object {
        [string](Get-Value $_ @('id') '') -ceq 'cage_claim_card'
    })
    if ($claimMatches.Count -cne 1) {
        throw "Linda's visible Players Card review has no unique claim control."
    }
    $claimEnabled = Get-Value $claimMatches[0] @('enabled') $null
    if ($claimEnabled -isnot [bool]) {
        throw "Linda's visible Players Card claim has no exact enabled witness."
    }
    if (-not [bool]$claimEnabled) {
        $null = Choose-VisibleChoice -ChoiceId 'back_main' -Intent 'return from Linda''s visible card-progress review'
        $null = Choose-VisibleChoice -ChoiceId 'leave_counter' -Intent 'step away from Linda until the visible card claim is ready'
        Wait-Frames -Frames 8
        return ''
    }

    $null = Choose-VisibleChoice -ChoiceId 'cage_claim_card' -Intent "ask Linda to issue the visibly enabled Players Card tier"
    Wait-ForFullyRenderedTalkSurface -Intent "Linda's Players Card recognition"

    $choices = @(Get-VisibleChoiceIds)
    $recognitionChoices = @($choices | Where-Object {
        @('thank_linda', 'take_silver', 'accept_gold_card') -ccontains [string]$_
    })
    if ($recognitionChoices.Count -cne 1) {
        throw "Players Card claim did not expose exactly one visible tier-recognition choice."
    }
    $recognitionChoice = [string]$recognitionChoices[0]
    if ($recognitionChoice -ceq 'thank_linda') {
        $null = Choose-VisibleChoice -ChoiceId 'thank_linda' -Intent 'accept Linda''s Bronze recognition'
        Wait-Frames -Frames 10
        return 'bronze'
    }
    if ($recognitionChoice -ceq 'take_silver') {
        $null = Choose-VisibleChoice -ChoiceId 'take_silver' -Intent 'accept Linda''s Silver recognition and High Limit access'
        Wait-Frames -Frames 10
        return 'silver'
    }
    if ($recognitionChoice -ceq 'accept_gold_card') {
        $null = Choose-VisibleChoice -ChoiceId 'accept_gold_card' -Intent 'accept the Gold Players Card and clean Grand Casino ending'
        Wait-Frames -Frames 45
        return 'gold'
    }
    throw "Linda exposed unknown Players Card recognition '$recognitionChoice'."
}


function Invoke-CleanEndingRoute {
    Reach-GrandCasino
    Ensure-GrandCasinoChips -Minimum 50
    Enter-GrandRoom -Room main
    $claimedTiers = @()

    # Each tier's ledger is segment-based. Track only rendered bankroll + chips
    # while playing, then visit Linda once the public money change and settled
    # hand count satisfy the rules she presents. Qualification is sticky, so a
    # Cage round trip after every hand only obscures the otherwise normal route.
    $segments = @(
        [pscustomobject]@{ tier = 'bronze'; minimum_games = 1; target_net = 5 },
        [pscustomobject]@{ tier = 'silver'; minimum_games = 3; target_net = 15 },
        [pscustomobject]@{ tier = 'gold'; minimum_games = 5; target_net = 30 }
    )
    $totalRounds = 0
    foreach ($segment in $segments) {
        $expectedTier = [string]$segment.tier
        $segmentBaseline = Get-CleanPublicCasinoTotal
        $segmentRounds = 0
        $consecutiveLosses = 0
        $lastRoundDelta = 0
        $qualified = $false

        while ($totalRounds -lt 80) {
            $segmentNetBefore = (Get-CleanPublicCasinoTotal) - $segmentBaseline
            $stakeMode = 'minimum'
            if ($expectedTier -ceq 'silver' -and $segmentRounds -ceq 0) {
                # Bronze's chip award visibly bankrolls one confident opening
                # Silver hand; the following hands return to the minimum.
                $stakeMode = 'maximum'
            }
            elseif ($consecutiveLosses -ge 2) {
                $stakeMode = 'maximum'
            }
            elseif ($lastRoundDelta -gt 0 -and $segmentNetBefore -gt 0 -and
                $segmentNetBefore -lt [int]$segment.target_net -and
                ([int]$segment.target_net - $segmentNetBefore) -le 12) {
                $stakeMode = 'followup'
            }

            $beforeRound = Get-CleanPublicCasinoTotal
            Play-OneBlackjackRound -CleanStakeMode $stakeMode
            $afterRound = Get-CleanPublicCasinoTotal
            $lastRoundDelta = $afterRound - $beforeRound
            if ($lastRoundDelta -lt 0) {
                $consecutiveLosses++
            }
            else {
                $consecutiveLosses = 0
            }
            $segmentRounds++
            $totalRounds++

            $segmentNet = $afterRound - $segmentBaseline
            $publicHeat = Get-RenderedHudInteger -Name heat_level -Context "Clean $expectedTier segment heat"
            if ($publicHeat -gt 30) {
                throw "Clean $expectedTier segment exceeded the visible Players Card heat ceiling ($publicHeat > 30)."
            }
            if ($segmentRounds -lt [int]$segment.minimum_games -or $segmentNet -lt [int]$segment.target_net) {
                continue
            }

            $tier = Visit-CageAndClaimReadyPlayersCard
            if ([string]::IsNullOrEmpty($tier)) {
                throw "Linda did not enable the visible $expectedTier claim after $segmentRounds hands and a public net change of $segmentNet."
            }
            if ($tier -cne $expectedTier) {
                throw "Visible Players Card recognition arrived out of order: expected '$expectedTier', found '$tier'."
            }
            $claimedTiers += $tier
            $qualified = $true
            if ($tier -ceq 'gold') {
                $null = Assert-TerminalOutcome
                return
            }
            if (-not $ConfirmationOnly -and $tier -ceq 'silver' -and -not $script:MidpointSaved) {
                Assert-SaveRelaunchContinue -Milestone 'Silver Players Card'
            }
            Enter-GrandRoom -Room main
            break
        }
        if (-not $qualified) {
            throw "Clean route did not claim the $expectedTier Players Card tier within 80 settled blackjack rounds."
        }
    }
    throw 'Clean route left the Players Card ladder without reaching the Gold terminal review.'
}


function Resolve-ShowdownChoiceSurface {
    $choices = @(Get-VisibleChoiceIds)
    $choiceIntents = @{
        enter_back_room = "follow Rourke into the visible back-room sequence"
        face_rourke = 'take the chair after the visible clean pat-down'
    }
    foreach ($choice in @('enter_back_room', 'face_rourke')) {
        if ($choices -ccontains $choice) {
            $intent = $choiceIntents[$choice]
            $null = Choose-VisibleChoice -ChoiceId $choice -Intent $intent
            Wait-Frames -Frames 12
            return $true
        }
    }

    $interrogationChoices = @($choices | Where-Object {
        [string]$_ -cin @('hold_steady', 'talk_down', 'take_the_edge')
    })
    if ($interrogationChoices.Count -gt 0) {
        $choice = Select-CheatReplayShowdownInterrogationChoice -EventPopup (Get-Value $script:LastObservation @('event_popup') $null)
        $null = Choose-VisibleChoice -ChoiceId $choice -Intent 'take the exact visible edge against Rourke during interrogation'
        Wait-Frames -Frames 12
        return $true
    }

    $walkChoices = @($choices | Where-Object {
        [string]$_ -ceq 'keep_everything' -or
            ([string]$_).StartsWith('trash_item__', [StringComparison]::Ordinal) -or
            ([string]$_).StartsWith('hand_to_crew__', [StringComparison]::Ordinal)
    })
    if ($walkChoices.Count -gt 0) {
        $choice = Select-CheatReplayShowdownWalkChoice -EventPopup (Get-Value $script:LastObservation @('event_popup') $null)
        $intent = if ($choice -ceq 'keep_everything') {
            'keep the publicly verified non-classified inventory during Rourke''s walk'
        } elseif ($choice.StartsWith('hand_to_crew__', [StringComparison]::Ordinal)) {
            "hand the one publicly identified classified item to the Crew before Rourke's search"
        } else {
            "trash the one publicly identified classified item before Rourke's search"
        }
        $null = Choose-VisibleChoice -ChoiceId $choice -Intent $intent
        Wait-Frames -Frames 12
        return $true
    }
    return $false
}


function Invoke-CheatEndingRoute {
    Reach-GrandCasino
    Ensure-GrandCasinoChips -Minimum 50
    Enter-GrandRoom -Room main

    $showdownCallOpened = $false
    for ($round = 0; $round -lt 60; $round++) {
        Play-OneBlackjackRound -UseVisibleCheat
        if (Test-PublicTerminalSurface) {
            throw 'Visible cheating ended the run before Rourke exposed the showdown route.'
        }
        Leave-GameSurface
        $renderedHeat = Get-RenderedHudInteger -Name heat_level -Context 'Cheat showdown pressure after leaving Blackjack'
        if ($renderedHeat -ge 70 -and
            $null -eq (Find-CanvasObject -SemanticId 'event:the_house_calls') -and
            $null -ne (Find-CanvasObject -SemanticId 'event:comped_suite_offer')) {
            Invoke-EventObjectChoice `
                -EventId 'comped_suite_offer' `
                -ChoiceId 'take_comp' `
                -Intent 'accept the visibly watched suite offer and force Rourke to answer the pressure'
            Wait-Frames -Frames 10 -Intent 'let the visible suite-offer pressure settle'
        }
        if ($renderedHeat -ge 70 -and
            $null -eq (Find-CanvasObject -SemanticId 'event:the_house_calls') -and
            $null -ne (Find-CanvasObject -SemanticId 'event:chain06_rourke_noticed')) {
            Invoke-EventObjectChoice `
                -EventId 'chain06_rourke_noticed' `
                -ChoiceId 'let_the_check_pass' `
                -Intent 'let the visible floor check pass and advance Rourke''s watched pressure'
            Wait-Frames -Frames 10 -Intent 'let the visible Rourke notice settle into the house call'
        }
        if ($null -cne (Find-CanvasObject -SemanticId 'event:the_house_calls')) {
            Open-EventObject -EventId 'the_house_calls' -Intent "answer Rourke's visible back-room call"
            $showdownCallOpened = $true
            break
        }
        $spatialHouseCalls = @(Get-Array (Get-Value $script:LastObservation @('spatial', 'objects') @()) | Where-Object {
            [string](Get-Value $_ @('object_id') '') -ceq 'event:the_house_calls' -and
            [bool](Get-Value $_ @('visible') $false) -and
            [bool](Get-Value $_ @('enabled') $false) -and
            [bool](Get-Value $_ @('interactive') $false)
        })
        if ($spatialHouseCalls.Count -gt 1) {
            throw "The public room model exposes duplicate House Calls objects."
        }
        if ($spatialHouseCalls.Count -ceq 1) {
            $null = Invoke-OverflowRoomActionButton `
                -ButtonText 'The House Calls: Follow Rourke' `
                -Intent "follow Rourke through the visible room-action list"
            Wait-Frames -Frames 10 -Intent 'let the visible House Calls response settle'
            $showdownCallOpened = $true
            break
        }
        $activeEventId = [string](Get-Value $script:LastObservation @('event_popup', 'event_id') '')
        $activeTalkId = [string](Get-Value $script:LastObservation @('talk', 'event_id') '')
        if ($activeEventId -ceq 'the_house_calls' -or $activeTalkId -ceq 'the_house_calls') {
            $showdownCallOpened = $true
            break
        }
    }
    if (-not $showdownCallOpened) {
        throw "Visible cheating did not naturally trigger Rourke's showdown within 60 settled hands."
    }
    for ($beat = 0; $beat -lt 12; $beat++) {
        if ([bool](Get-Value $script:LastObservation @('game', 'boss_duel_active') $false)) { break }
        if (-not (Resolve-ShowdownChoiceSurface)) {
            Wait-Frames -Frames 12
            if (-not [bool](Get-Value $script:LastObservation @('event_popup', 'visible') $false) -and
                -not [bool](Get-Value $script:LastObservation @('talk', 'visible') $false)) {
                throw "Rourke's showdown stopped before the duel became publicly active."
            }
        }
    }
    Assert-CheatRourkeDuelBeforeHandOne -Context 'after showdown choices'
    if (-not $ConfirmationOnly) {
        Assert-SaveRelaunchContinue -Milestone 'Rourke duel before hand one'
    }

    for ($hand = 0; $hand -lt 8; $hand++) {
        if (Test-PublicTerminalSurface) { break }
        if ([bool](Get-Value $script:LastObservation @('event_popup', 'visible') $false) -or
            [bool](Get-Value $script:LastObservation @('talk', 'visible') $false)) {
            if (-not (Resolve-ShowdownChoiceSurface)) {
                throw "Unexpected choice interrupted Rourke's duel: $((Get-VisibleChoiceIds) -join ', ')"
            }
            continue
        }
        Play-OneBlackjackRound
    }
    for ($beat = 0; $beat -lt 12 -and -not (Test-PublicTerminalSurface); $beat++) {
        if (Resolve-ShowdownChoiceSurface) { continue }
        $endingAction = @('ending.ack', 'showdown_exit', 'surface_back') | Where-Object { $null -cne (Find-GameAction -Action $_) } | Select-Object -First 1
        if (-not [string]::IsNullOrWhiteSpace([string]$endingAction)) {
            $null = Invoke-GameAction -Action ([string]$endingAction) -Intent 'acknowledge the visible Rourke duel outcome'
        }
        else {
            Wait-Frames -Frames 20
        }
    }
    Wait-Frames -Frames 30
    $null = Assert-TerminalOutcome
}


function Find-WorldNodeIdByArchetype {
    param([Parameter(Mandatory = $true)][string]$ArchetypeId)
    Open-WorldMap
    $matches = @(Get-MapNodes | Where-Object {
        [string](Get-Value $_ @('archetype_id') '') -ceq $ArchetypeId
    } | Sort-Object @{ Expression = { if ([string](Get-Value $_ @('id') '') -ceq $ArchetypeId) { 0 } else { 1 } } }, @{ Expression = { [string](Get-Value $_ @('id') '') } })
    $nodeId = ''
    if ($matches.Count -gt 0) {
        $nodeId = [string](Get-Value $matches[0] @('id') '')
    }
    Close-WorldMap
    return $nodeId
}


function Assert-RenderedAuditNightHook {
    $canvasObjects = @(Get-Array (Get-Value $script:LastResult @('look', 'clickable', 'canvas_objects') @()))
    $hook = Select-HeistAuditNightPublicHook `
        -Observation $script:LastObservation `
        -CanvasObjects $canvasObjects
    if ($null -eq $hook) {
        throw 'The public Audit Night hook selector returned no rendered hook.'
    }
    return $hook
}


function Observe-RenderedAuditNightHook {
    $null = Assert-RenderedAuditNightHook
    Invoke-EventObjectChoice `
        -EventId 'scenario_audit_roster' `
        -ChoiceId 'read_the_shift' `
        -Intent 'read the visible Audit roster and learn The Count route'

    $eventVisible = Get-Value $script:LastObservation @('event_popup', 'visible') $null
    $talkVisible = Get-Value $script:LastObservation @('talk', 'visible') $null
    if ($eventVisible -isnot [bool] -or $talkVisible -isnot [bool] -or
        ([bool]$eventVisible -and [bool]$talkVisible)) {
        throw 'The post-Audit route lost its exact public modal state.'
    }
    if ([bool]$eventVisible) {
        $eventId = Get-Value $script:LastObservation @('event_popup', 'event_id') $null
        if ($eventId -is [string] -and [string]$eventId -ceq 'crew_favor_delivery') {
            return
        }
        throw "Audit Night chained into unexpected event popup '$eventId'."
    }
    if ([bool]$talkVisible) {
        $talkId = Get-Value $script:LastObservation @('talk', 'event_id') $null
        if ($talkId -is [string] -and [string]$talkId -ceq 'crew_favor_delivery') {
            return
        }
        if ($talkId -isnot [string] -or [string]$talkId -cne 'the_collector') {
            throw "Audit Night chained into unexpected TalkDock '$talkId'."
        }
        $choiceIds = @(Get-VisibleChoiceIds)
        if ($choiceIds.Count -cne 3 -or
            $choiceIds[0] -isnot [string] -or [string]$choiceIds[0] -cne 'pay_now' -or
            $choiceIds[1] -isnot [string] -or [string]$choiceIds[1] -cne 'promise' -or
            $choiceIds[2] -isnot [string] -or [string]$choiceIds[2] -cne 'stand_ground') {
            throw "The post-Audit Collector exposed unexpected choices: $($choiceIds -join ', ')."
        }
        $null = Choose-VisibleChoice `
            -ChoiceId 'promise' `
            -Intent 'stall the visible Collector without spending the fixed heist route bankroll'
        Wait-Frames -Frames 10 -Intent 'let the visible Collector response settle'
    }

    if (Test-CrewFavorPublicSurface) {
        return
    }
    $eventVisible = Get-Value $script:LastObservation @('event_popup', 'visible') $null
    $talkVisible = Get-Value $script:LastObservation @('talk', 'visible') $null
    if ($eventVisible -isnot [bool] -or $talkVisible -isnot [bool] -or
        [bool]$eventVisible -or [bool]$talkVisible) {
        throw 'The post-Audit Collector response did not settle to the Crew favor or a modal-free room.'
    }
    Restore-EnvironmentSurfaceAfterTravelResult
}


function Assert-RenderedConventionCrowdHook {
    $canvasObjects = @(Get-Array (Get-Value $script:LastResult @('look', 'clickable', 'canvas_objects') @()))
    $hook = Select-HeistConventionCrowdPublicHook `
        -Observation $script:LastObservation `
        -CanvasObjects $canvasObjects
    if ($null -eq $hook) {
        throw 'The public Convention Crowd hook selector returned no rendered hook.'
    }
    return $hook
}


function Navigate-ToArchetype {
    param(
        [Parameter(Mandatory = $true)][string]$ArchetypeId,
        [Parameter(Mandatory = $true)][string]$Intent
    )
    if ([string](Get-Value $script:LastObservation @('environment', 'archetype_id') '') -ceq $ArchetypeId) {
        if ([string](Get-Value $script:LastObservation @('screen', 'screen') '') -ceq 'RESULT') {
            Restore-EnvironmentSurfaceAfterTravelResult
        }
        return
    }

    # The map intentionally caps the number of destination cards. A guaranteed
    # venue can therefore begin just beyond the currently rendered choices and
    # becomes public only as the player visits ordinary revealed stops. Follow
    # those real cards until the requested archetype enters the visible list.
    $scoutedNodeIds = New-Object 'System.Collections.Generic.HashSet[string]'
    for ($scout = 0; $scout -lt 24; $scout++) {
        Open-WorldMap
        $nodes = @(Get-MapNodes)
        $archetypeMatches = @($nodes | Where-Object {
            [string](Get-Value $_ @('archetype_id') '') -ceq $ArchetypeId
        } | Sort-Object @{ Expression = { if ([string](Get-Value $_ @('id') '') -ceq $ArchetypeId) { 0 } else { 1 } } }, @{ Expression = { [string](Get-Value $_ @('id') '') } })
        if ($archetypeMatches.Count -gt 1) {
            Close-WorldMap
            throw "The public map exposes more than one $ArchetypeId venue."
        }
        if ($archetypeMatches.Count -ceq 1) {
            $nodeId = [string](Get-Value $archetypeMatches[0] @('id') '')
            if ($nodeId -cnotmatch '^[a-z0-9_]+$') {
                Close-WorldMap
                throw "The public $ArchetypeId card has no stable node identity."
            }
            $travelEnabled = [bool](Get-Value $archetypeMatches[0] @('travel_enabled') $false)
            $state = [string](Get-Value $archetypeMatches[0] @('state') '')
            if (-not $travelEnabled -and $state -ceq 'visited') {
                Close-WorldMap
                Navigate-ToNode -NodeId $nodeId -Intent $Intent
                Restore-EnvironmentSurfaceAfterTravelResult
                return
            }
            if (-not $travelEnabled) {
                $reason = [string](Get-Value $archetypeMatches[0] @('travel_disabled_reason') 'route unavailable')
                Close-WorldMap
                throw "The public $ArchetypeId card is not travel-enabled: $reason"
            }
            $cost = Get-Value $archetypeMatches[0] @('cost') $null
            if (($cost -isnot [int32] -and $cost -isnot [int64]) -or [long]$cost -lt 0) {
                Close-WorldMap
                throw "The public $ArchetypeId card has no non-negative integral fare."
            }
            $cash = Get-RenderedHudInteger -Name bankroll -Context "$ArchetypeId travel fare"
            if ([long]$cost -gt [long]$cash) {
                Close-WorldMap
                throw "The public $ArchetypeId fare is `$${cost}, but only `$${cash} is rendered."
            }
            Travel-ToNode -NodeId $nodeId -Intent $Intent
            Restore-EnvironmentSurfaceAfterTravelResult
            return
        }

        $currentNodeId = [string](Get-Value $script:LastObservation @('environment', 'world_node_id') '')
        $candidates = @($nodes | Where-Object {
            $candidateId = [string](Get-Value $_ @('id') '')
            $candidateId -cmatch '^[a-z0-9_]+$' -and
                $candidateId -cne $currentNodeId -and
                [bool](Get-Value $_ @('travel_enabled') $false) -and
                (-not $scoutedNodeIds.Contains($candidateId))
        } | Sort-Object `
            @{ Expression = { if ([string](Get-Value $_ @('state') '') -ceq 'visited') { 1 } else { 0 } } }, `
            @{ Expression = { [int](Get-Value $_ @('cost') 0) } }, `
            @{ Expression = { [string](Get-Value $_ @('id') '') } })
        if ($candidates.Count -ceq 0) {
            Close-WorldMap
            throw "The public map exposed no untried travel card while scouting for $ArchetypeId."
        }
        $nextNodeId = [string](Get-Value $candidates[0] @('id') '')
        $nextCost = Get-Value $candidates[0] @('cost') $null
        if (($nextCost -isnot [int32] -and $nextCost -isnot [int64]) -or [long]$nextCost -lt 0) {
            Close-WorldMap
            throw "The visible scouting card '$nextNodeId' has no non-negative integral fare."
        }
        $cash = Get-RenderedHudInteger -Name bankroll -Context "$ArchetypeId scouting fare"
        if ([long]$nextCost -gt [long]$cash) {
            Close-WorldMap
            throw "The next visible scouting card costs `$${nextCost}, but only `$${cash} is rendered."
        }
        $null = $scoutedNodeIds.Add($nextNodeId)
        Travel-ToNode -NodeId $nextNodeId -Intent "$Intent (visible scouting stop $($scout + 1) via $nextNodeId)"
        Restore-EnvironmentSurfaceAfterTravelResult
    }
    throw "The public route did not reveal a $ArchetypeId venue within 24 normal travel decisions."
}


function Test-CrewFavorPublicSurface {
    $eventId = [string](Get-Value $script:LastObservation @('event_popup', 'event_id') '')
    $talkId = [string](Get-Value $script:LastObservation @('talk', 'event_id') '')
    return $eventId -ceq 'crew_favor_delivery' -or
        $talkId -ceq 'crew_favor_delivery' -or
        $null -cne (Find-CanvasObject -SemanticId 'event:crew_favor_delivery')
}


function Invoke-CrewFavorActionBoundary {
    param(
        [Parameter(Mandatory = $true)][ValidateRange(1, 2)][int]$FavorNumber,
        [Parameter(Mandatory = $true)][ValidateRange(1, 3)][int]$BoundaryNumber
    )
    $currentArchetype = Get-Value $script:LastObservation @('environment', 'archetype_id') $null
    if ($FavorNumber -ceq 2 -and
        $currentArchetype -is [string] -and [string]$currentArchetype -ceq 'back_alley') {
        if (Test-CrewFavorPublicSurface) {
            throw "Crew favor 2 boundary $BoundaryNumber reached Back Alley after its exact delivery surface was already visible."
        }
        $screen = Get-Value $script:LastObservation @('screen', 'screen') $null
        $eventVisible = Get-Value $script:LastObservation @('event_popup', 'visible') $null
        $talkVisible = Get-Value $script:LastObservation @('talk', 'visible') $null
        $transitionActive = Get-Value $script:LastObservation @('screen', 'travel_transition_active') $null
        if ($screen -isnot [string] -or [string]$screen -cne 'ENVIRONMENT' -or
            $eventVisible -isnot [bool] -or [bool]$eventVisible -or
            $talkVisible -isnot [bool] -or [bool]$talkVisible -or
            $transitionActive -isnot [bool] -or [bool]$transitionActive) {
            throw "Crew favor 2 boundary $BoundaryNumber cannot use its public Back Alley event through a malformed or interrupted room."
        }

        $beforeCash = Get-RenderedHudInteger -Name bankroll -Context "Crew favor 2 boundary $BoundaryNumber Back Alley bankroll"
        $beforeHeat = Get-RenderedHudInteger -Name heat_level -Context "Crew favor 2 boundary $BoundaryNumber Back Alley heat"
        if ($BoundaryNumber -ceq 1) {
            if ($null -ceq (Find-CanvasObject -SemanticId 'event:back_alley_offer')) {
                throw 'Crew favor 2 boundary 1 requires one exact rendered and enabled Back Alley Offer.'
            }
            Select-EventObject -EventId 'back_alley_offer'
            $roomCanvas = Get-Value $script:LastObservation @('room_canvas') $null
            $objects = @(Get-Array (Get-Value $roomCanvas @('objects') @()) | Where-Object {
                [string](Get-Value $_ @('id') '') -ceq 'event:back_alley_offer'
            })
            $selectedInfo = Get-Value $roomCanvas @('selected_info') $null
            $selectedActions = @(Get-Array (Get-Value $selectedInfo @('actions') @()))
            $roomActions = @(Get-RoomActions)
            if ($objects.Count -cne 1 -or
                [string](Get-Value $objects[0] @('id') '') -cne 'event:back_alley_offer' -or
                [string](Get-Value $objects[0] @('type') '') -cne 'event' -or
                [string](Get-Value $objects[0] @('label') '') -cne 'Back Alley Offer' -or
                [string](Get-Value $objects[0] @('description') '') -cne 'A trunk opens on a bad bargain.' -or
                (Get-Value $objects[0] @('interactive') $null) -isnot [bool] -or -not [bool](Get-Value $objects[0] @('interactive') $false) -or
                (Get-Value $objects[0] @('disabled') $null) -isnot [bool] -or [bool](Get-Value $objects[0] @('disabled') $true) -or
                [string](Get-Value $roomCanvas @('selected_object_id') '') -cne 'event:back_alley_offer' -or
                [string](Get-Value $selectedInfo @('object_id') '') -cne 'event:back_alley_offer' -or
                [string](Get-Value $selectedInfo @('title') '') -cne 'Back Alley Offer' -or
                $selectedActions.Count -cne 2 -or
                [string](Get-Value $selectedActions[0] @('emit_object_id') '') -cne 'event_response:back_alley_offer:take_cash' -or
                [string](Get-Value $selectedActions[0] @('label') '') -cne 'Take the cash' -or
                (Get-Value $selectedActions[0] @('enabled') $null) -isnot [bool] -or -not [bool](Get-Value $selectedActions[0] @('enabled') $false) -or
                [string](Get-Value $selectedActions[1] @('emit_object_id') '') -cne 'event_response:back_alley_offer:walk' -or
                [string](Get-Value $selectedActions[1] @('label') '') -cne 'Keep walking' -or
                (Get-Value $selectedActions[1] @('enabled') $null) -isnot [bool] -or -not [bool](Get-Value $selectedActions[1] @('enabled') $false) -or
                $roomActions.Count -cne 2 -or
                [string](Get-Value $roomActions[0] @('selected_object_id') '') -cne 'event:back_alley_offer' -or
                [string](Get-Value $roomActions[0] @('emit_object_id') '') -cne 'event_response:back_alley_offer:take_cash' -or
                [string](Get-Value $roomActions[0] @('label') '') -cne 'Take the cash' -or
                (Get-Value $roomActions[0] @('enabled') $null) -isnot [bool] -or -not [bool](Get-Value $roomActions[0] @('enabled') $false) -or
                (Get-Value $roomActions[0] @('rendered') $null) -isnot [bool] -or -not [bool](Get-Value $roomActions[0] @('rendered') $false) -or
                [string](Get-Value $roomActions[1] @('selected_object_id') '') -cne 'event:back_alley_offer' -or
                [string](Get-Value $roomActions[1] @('emit_object_id') '') -cne 'event_response:back_alley_offer:walk' -or
                [string](Get-Value $roomActions[1] @('label') '') -cne 'Keep walking' -or
                (Get-Value $roomActions[1] @('enabled') $null) -isnot [bool] -or -not [bool](Get-Value $roomActions[1] @('enabled') $false) -or
                (Get-Value $roomActions[1] @('rendered') $null) -isnot [bool] -or -not [bool](Get-Value $roomActions[1] @('rendered') $false) -or
                [bool](Get-Value $script:LastObservation @('event_popup', 'visible') $true) -or
                [bool](Get-Value $script:LastObservation @('talk', 'visible') $true)) {
                throw 'Crew favor 2 boundary 1 rejected a malformed or drifted inline Back Alley Offer surface.'
            }
            $null = Invoke-RoomActionRow `
                -Row $roomActions[0] `
                -Intent 'take the exact visible Back Alley cash offer for Crew favor 2 boundary 1'
            Wait-Frames -Frames 10
            $afterCash = Get-RenderedHudInteger -Name bankroll -Context 'Crew favor 2 boundary 1 bankroll after Back Alley Offer'
            $afterHeat = Get-RenderedHudInteger -Name heat_level -Context 'Crew favor 2 boundary 1 heat after Back Alley Offer'
            if ($afterCash -cne ($beforeCash + 8) -or $afterHeat -cne ($beforeHeat + 1)) {
                throw "The exact Back Alley Offer changed public economy unexpectedly (`$$beforeCash/$beforeHeat -> `$$afterCash/$afterHeat)."
            }
        }
        else {
            $beforeClockText = Get-Value $script:LastObservation @('environment', 'clock_text') $null
            if ($beforeClockText -isnot [string]) {
                throw "Crew favor 2 boundary $BoundaryNumber requires an exact rendered public clock before Switch."
            }
            $beforeClockMatch = [regex]::Match(
                [string]$beforeClockText,
                '^Day ([1-9][0-9]*) ([1-9]|1[0-2]):([0-5][0-9]) (AM|PM)$',
                [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
            )
            if (-not $beforeClockMatch.Success) {
                throw "Crew favor 2 boundary $BoundaryNumber rejected malformed public clock '$beforeClockText' before Switch."
            }
            $beforeClockDay = [int]$beforeClockMatch.Groups[1].Value
            $beforeClockHour = [int]$beforeClockMatch.Groups[2].Value
            $beforeClockMinute = [int]$beforeClockMatch.Groups[3].Value
            if ($beforeClockMatch.Groups[4].Value -ceq 'PM' -and $beforeClockHour -lt 12) {
                $beforeClockHour += 12
            }
            elseif ($beforeClockMatch.Groups[4].Value -ceq 'AM' -and $beforeClockHour -ceq 12) {
                $beforeClockHour = 0
            }
            $beforeClockOrdinal = (($beforeClockDay - 1) * 1440) + ($beforeClockHour * 60) + $beforeClockMinute

            $switchCanvas = Find-CanvasObject -SemanticId 'event:recruitment_switch'
            if ($null -eq $switchCanvas) {
                $switchSpatial = @(Get-Array (Get-Value $script:LastObservation @('spatial', 'objects') @()) | Where-Object {
                    [string](Get-Value $_ @('object_id') '') -ceq 'event:recruitment_switch'
                })
                if ($switchSpatial.Count -cne 1 -or
                    [string](Get-Value $switchSpatial[0] @('object_id') '') -cne 'event:recruitment_switch' -or
                    [string](Get-Value $switchSpatial[0] @('label') '') -cne 'Switch' -or
                    [string](Get-Value $switchSpatial[0] @('object_type') '') -cne 'event' -or
                    (Get-Value $switchSpatial[0] @('visible') $null) -isnot [bool] -or -not [bool](Get-Value $switchSpatial[0] @('visible') $false) -or
                    (Get-Value $switchSpatial[0] @('enabled') $null) -isnot [bool] -or -not [bool](Get-Value $switchSpatial[0] @('enabled') $false) -or
                    (Get-Value $switchSpatial[0] @('interactive') $null) -isnot [bool] -or -not [bool](Get-Value $switchSpatial[0] @('interactive') $false)) {
                    throw "Crew favor 2 boundary $BoundaryNumber requires one exact visible, enabled, interactive Switch spatial record."
                }
                $null = Invoke-OverflowRoomActionButton `
                    -ButtonText 'Switch: Talk' `
                    -Intent "open the exact public Switch talk overflow row for Crew favor 2 boundary $BoundaryNumber"
            }
            else {
                $null = Open-SemanticObject `
                    -SemanticId 'event:recruitment_switch' `
                    -PreferredActions @('Talk', 'inspect_event_choices', 'Open', 'Approach') `
                    -Intent "open the exact Switch contact for Crew favor 2 boundary $BoundaryNumber"
            }
            Wait-ForFullyRenderedTalkSurface -Intent "Crew favor 2 boundary $BoundaryNumber Switch contact"
            $talk = Get-Value $script:LastObservation @('talk') $null
            $talkChoices = @(Get-PublicTalkChoices)
            if ((Get-Value $talk @('visible') $null) -isnot [bool] -or -not [bool](Get-Value $talk @('visible') $false) -or
                (Get-Value $talk @('render_valid') $null) -isnot [bool] -or -not [bool](Get-Value $talk @('render_valid') $false) -or
                (Get-Value $talk @('body_complete') $null) -isnot [bool] -or -not [bool](Get-Value $talk @('body_complete') $false) -or
                [string](Get-Value $talk @('event_id') '') -cne 'recruitment_switch' -or
                [string](Get-Value $talk @('summary') '') -cne 'Switch taps two routes, then waits.' -or
                (@(Get-Array (Get-Value $talk @('choice_ids') @())) -join ',') -cne 'work_with_switch,leave_switch_waiting' -or
                $talkChoices.Count -cne 2 -or
                [string](Get-Value $talkChoices[0] @('event_id') '') -cne 'recruitment_switch' -or
                [string](Get-Value $talkChoices[0] @('id') '') -cne 'work_with_switch' -or
                [string](Get-Value $talkChoices[0] @('label') '') -cne 'Take the route' -or
                (Get-Value $talkChoices[0] @('enabled') $null) -isnot [bool] -or -not [bool](Get-Value $talkChoices[0] @('enabled') $false) -or
                [string](Get-Value $talkChoices[1] @('event_id') '') -cne 'recruitment_switch' -or
                [string](Get-Value $talkChoices[1] @('id') '') -cne 'leave_switch_waiting' -or
                [string](Get-Value $talkChoices[1] @('label') '') -cne 'Keep circling' -or
                (Get-Value $talkChoices[1] @('enabled') $null) -isnot [bool] -or -not [bool](Get-Value $talkChoices[1] @('enabled') $false) -or
                [bool](Get-Value $script:LastObservation @('event_popup', 'visible') $true)) {
                throw "Crew favor 2 boundary $BoundaryNumber rejected a malformed or drifted Switch talk surface."
            }
            $null = Choose-VisibleChoice `
                -ChoiceId 'leave_switch_waiting' `
                -Intent "keep circling through the exact visible Switch response at Crew favor 2 boundary $BoundaryNumber"
            Wait-Frames -Frames 10
            $afterCash = Get-RenderedHudInteger -Name bankroll -Context "Crew favor 2 boundary $BoundaryNumber bankroll after Switch"
            $afterHeat = Get-RenderedHudInteger -Name heat_level -Context "Crew favor 2 boundary $BoundaryNumber heat after Switch"
            $afterClockText = Get-Value $script:LastObservation @('environment', 'clock_text') $null
            if ($afterClockText -isnot [string]) {
                throw "Crew favor 2 boundary $BoundaryNumber requires an exact rendered public clock after Switch."
            }
            $afterClockMatch = [regex]::Match(
                [string]$afterClockText,
                '^Day ([1-9][0-9]*) ([1-9]|1[0-2]):([0-5][0-9]) (AM|PM)$',
                [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
            )
            if (-not $afterClockMatch.Success) {
                throw "Crew favor 2 boundary $BoundaryNumber rejected malformed public clock '$afterClockText' after Switch."
            }
            $afterClockDay = [int]$afterClockMatch.Groups[1].Value
            $afterClockHour = [int]$afterClockMatch.Groups[2].Value
            $afterClockMinute = [int]$afterClockMatch.Groups[3].Value
            if ($afterClockMatch.Groups[4].Value -ceq 'PM' -and $afterClockHour -lt 12) {
                $afterClockHour += 12
            }
            elseif ($afterClockMatch.Groups[4].Value -ceq 'AM' -and $afterClockHour -ceq 12) {
                $afterClockHour = 0
            }
            $afterClockOrdinal = (($afterClockDay - 1) * 1440) + ($afterClockHour * 60) + $afterClockMinute
            $clockDelta = $afterClockOrdinal - $beforeClockOrdinal
            if ($afterClockDay -cne $beforeClockDay -or $clockDelta -lt 0) {
                throw "Crew favor 2 boundary $BoundaryNumber rejected nonmonotonic public clock chronology '$beforeClockText' -> '$afterClockText'."
            }
            $favorSurfaced = Test-CrewFavorPublicSurface
            $acceptedTimedHeatDecay = $afterHeat -ceq ($beforeHeat - 1) -and
                $favorSurfaced -and
                $clockDelta -ceq 1 -and
                [string](Get-Value $script:LastObservation @('screen', 'screen') '') -ceq 'ENVIRONMENT' -and
                [string](Get-Value $script:LastObservation @('environment', 'world_node_id') '') -ceq 'back_alley' -and
                [string](Get-Value $script:LastObservation @('environment', 'archetype_id') '') -ceq 'back_alley' -and
                (Get-Value $script:LastObservation @('screen', 'travel_transition_active') $null) -is [bool] -and
                -not [bool](Get-Value $script:LastObservation @('screen', 'travel_transition_active') $true) -and
                -not [bool](Get-Value $script:LastObservation @('event_popup', 'visible') $true)
            if ($afterCash -cne $beforeCash -or
                ($afterHeat -cne $beforeHeat -and -not $acceptedTimedHeatDecay)) {
                throw "The exact Switch refusal changed public economy at Crew favor 2 boundary $BoundaryNumber (`$$beforeCash/$beforeHeat -> `$$afterCash/$afterHeat)."
            }
        }

        if (Test-CrewFavorPublicSurface) { return }
        $settledScreen = Get-Value $script:LastObservation @('screen', 'screen') $null
        if ($settledScreen -isnot [string] -or [string]$settledScreen -cnotin @('RESULT', 'ENVIRONMENT') -or
            [string](Get-Value $script:LastObservation @('environment', 'world_node_id') '') -cne 'back_alley' -or
            [string](Get-Value $script:LastObservation @('environment', 'archetype_id') '') -cne 'back_alley' -or
            [bool](Get-Value $script:LastObservation @('event_popup', 'visible') $true) -or
            [bool](Get-Value $script:LastObservation @('talk', 'visible') $true) -or
            [bool](Get-Value $script:LastObservation @('screen', 'travel_transition_active') $true)) {
            throw "Crew favor 2 boundary $BoundaryNumber did not settle at an uninterrupted Back Alley room."
        }
        Restore-EnvironmentSurfaceAfterTravelResult
        if (Test-CrewFavorPublicSurface) { return }
        if ([string](Get-Value $script:LastObservation @('environment', 'world_node_id') '') -cne 'back_alley' -or
            [string](Get-Value $script:LastObservation @('environment', 'archetype_id') '') -cne 'back_alley' -or
            [string](Get-Value $script:LastObservation @('screen', 'screen') '') -cne 'ENVIRONMENT' -or
            [bool](Get-Value $script:LastObservation @('event_popup', 'visible') $true) -or
            [bool](Get-Value $script:LastObservation @('talk', 'visible') $true) -or
            [bool](Get-Value $script:LastObservation @('screen', 'travel_transition_active') $true)) {
            throw "Crew favor 2 boundary $BoundaryNumber did not restore a modal-free Back Alley room."
        }
        return
    }

    $serviceId = ''
    $serviceLabel = ''
    $serviceType = 'service'
    $serviceCost = 0
    if ($null -cne (Find-CanvasObject -SemanticId 'service:cashier_tip')) {
        $serviceId = 'service:cashier_tip'
        $serviceLabel = 'Cashier Tip'
        $serviceCost = 4
    }
    elseif ($null -cne (Find-CanvasObject -SemanticId 'service:house_drink')) {
        # After a completed delivery, take the ordinary priced room action already
        # in front of the player. Forcing a map detour can cycle through the capped
        # revisit cards even though the marker accepts any normal action boundary.
        $serviceId = 'service:house_drink'
        $serviceLabel = 'Buy a Drink'
        $serviceType = 'drink'
        $serviceCost = 8
    }
    else {
        # A completed favor can leave the player at its delivery room, while the
        # visited Corner Store is no longer on the capped route list. Return to
        # the already-unlocked Grand main floor and use its ordinary room action.
        Reach-GrandCasino
        Enter-GrandRoom -Room main
        Restore-EnvironmentSurfaceAfterTravelResult
        $serviceId = 'service:house_drink'
        $serviceLabel = 'Buy a Drink'
        $serviceType = 'drink'
        $serviceCost = 8
    }

    $service = Find-CanvasObject -SemanticId $serviceId
    if ($null -ceq $service -or
        [string](Get-Value $service @('label') '') -cne $serviceLabel -or
        [string](Get-Value $service @('object_type') '') -cne $serviceType) {
        throw "Crew-marker timing does not expose the expected rendered, enabled $serviceLabel service."
    }
    $beforeCash = Get-RenderedHudInteger -Name bankroll -Context "Crew favor $FavorNumber boundary $BoundaryNumber bankroll before the visible $serviceLabel"
    if ($beforeCash -lt $serviceCost) {
        throw "The visible $serviceLabel costs `$$serviceCost, but only `$$beforeCash remains before Crew favor $FavorNumber boundary $BoundaryNumber."
    }
    $null = Open-SemanticObject `
        -SemanticId $serviceId `
        -PreferredActions @('Use') `
        -Intent "use the visible $serviceLabel for Crew favor $FavorNumber boundary $BoundaryNumber"
    Wait-Frames -Frames 10
    $afterCash = Get-RenderedHudInteger -Name bankroll -Context "Crew favor $FavorNumber boundary $BoundaryNumber bankroll after the visible $serviceLabel"
    if ($afterCash -ne $beforeCash - $serviceCost) {
        throw "The visible $serviceLabel did not charge its exact `$$serviceCost price at Crew favor $FavorNumber boundary $BoundaryNumber (`$$beforeCash -> `$$afterCash)."
    }
    if (-not (Test-CrewFavorPublicSurface)) {
        Restore-EnvironmentSurfaceAfterTravelResult
    }
}


function Establish-CrewMarker {
    Navigate-ToArchetype -ArchetypeId 'corner_store' -Intent 'visit the Corner Store for its visible Crew lender and repeatable cashier service'
    Restore-EnvironmentSurfaceAfterTravelResult
    $canvasObjects = @(Get-Array (Get-Value $script:LastResult @('look', 'clickable', 'canvas_objects') @()))
    $worldNodeId = Get-Value $script:LastObservation @('environment', 'world_node_id') $null
    if ($worldNodeId -isnot [string] -or [string]$worldNodeId -cnotmatch '^[a-z0-9_]+$') {
        throw 'The Corner Store Crew marker has no stable public world-node identity.'
    }
    $selection = Select-GrandFareFundingObject `
        -CanvasObjects $canvasObjects `
        -WorldNodeId ([string]$worldNodeId) `
        -AcceptedOfferKeys @($script:GrandFareAcceptedOfferKeys) `
        -AcceptedLenderIds @($script:GrandFareAcceptedLenderIds)
    if ([string]$selection.lender_id -cne 'the_crew' -or [string]$selection.semantic_id -cne 'lender:the_crew') {
        throw "The normal seeded Corner Store selected an unexpected lender '$($selection.semantic_id)'."
    }
    $beforeBankroll = Get-RenderedHudInteger -Name bankroll -Context 'Crew marker bankroll before the public offer'
    $beforeDebtIndicator = Get-Value $script:LastObservation @('status_hud', 'debt_indicator') $null
    $beforeDebtCount = Get-GrandFarePublicDebtCount -DebtIndicator $beforeDebtIndicator -Context 'Crew marker pre-acceptance HUD'
    if ($beforeDebtCount -ne 0) {
        throw 'The fixed Heist route reached its one Crew marker with another active debt already visible.'
    }

    $null = Invoke-BridgeCommand -Command 'click_object lender:the_crew' -Intent 'focus the visible Corner Store Crew lender'
    $selection = Select-GrandFareFundingObjectAction -Selection $selection -RoomActions @(Get-RoomActions)
    $null = Invoke-RoomActionRow -Row $selection.action -Intent 'open the Crew lender terms'
    Wait-ForFullyRenderedFundingTalk -ExpectedEventId 'lender_conversation:borrow:the_crew'
    $offer = Select-GrandFareFundingTalkOffer `
        -Selection $selection `
        -Talk (Get-Value $script:LastObservation @('talk') $null) `
        -TalkChoices @(Get-PublicTalkChoices)
    if ([int]$offer.principal -ne 70) {
        throw "The visible Crew marker principal changed from `$70 to `$$($offer.principal)."
    }
    $null = Invoke-BridgeCommand -Command 'click_choice accept' -Intent 'arm the visibly disclosed Crew marker offer'
    $null = Assert-GrandFareFundingConfirmation `
        -Offer $offer `
        -Talk (Get-Value $script:LastObservation @('talk') $null) `
        -TalkChoices @(Get-PublicTalkChoices)
    $null = Invoke-BridgeCommand -Command 'click_choice accept' -Intent 'confirm the visibly armed Crew marker offer'
    Wait-Frames -Frames 10
    $null = Assert-GrandFareFundingResult `
        -Offer $offer `
        -BeforeBankroll $beforeBankroll `
        -BeforeDebtIndicator $beforeDebtIndicator `
        -AfterObservation $script:LastObservation
    $null = $script:GrandFareAcceptedOfferKeys.Add([string]$selection.offer_key)
    $null = $script:GrandFareAcceptedLenderIds.Add('the_crew')
    Restore-EnvironmentSurfaceAfterTravelResult
}


function Clear-CrewMarkerFavors {

    # The release lender terms create one favor marker. Clear that favor now so
    # the heist route cannot be interrupted later by an overdue Crew call.
    # Normal travel advances only the clock, not RunState's action
    # index. Audit/invitation choices may already have consumed a boundary; use
    # an exact rendered, priced room service for the remaining boundaries.
    for ($favor = 1; $favor -le 1; $favor++) {
        for ($boundary = 1; $boundary -le 3 -and -not (Test-CrewFavorPublicSurface); $boundary++) {
            Invoke-CrewFavorActionBoundary -FavorNumber $favor -BoundaryNumber $boundary
        }
        if (-not (Test-CrewFavorPublicSurface)) {
            throw "Crew favor $favor did not surface after at most three visible service action boundaries."
        }
        $eventId = [string](Get-Value $script:LastObservation @('event_popup', 'event_id') '')
        $talkId = [string](Get-Value $script:LastObservation @('talk', 'event_id') '')
        if (($eventId -ceq 'crew_favor_delivery' -or $talkId -ceq 'crew_favor_delivery') -and
            'run_package' -cin @(Get-VisibleChoiceIds)) {
            $null = Choose-VisibleChoice -ChoiceId 'run_package' -Intent "honor the Crew's visible favor $favor of 1"
            Wait-Frames -Frames 10
            Complete-PublicDelivery -Intent "complete Crew favor $favor of 1"
            $debtCount = Get-GrandFarePublicDebtCount `
                -DebtIndicator (Get-Value $script:LastObservation @('status_hud', 'debt_indicator') $null) `
                -Context "HUD after Crew favor $favor of 1"
            if ($debtCount -ne (1 - $favor)) {
                throw "Crew favor $favor did not remove exactly one visible marker balance."
            }
            continue
        }
        if ($null -cne (Find-CanvasObject -SemanticId 'event:crew_favor_delivery')) {
            Invoke-EventObjectChoice -EventId 'crew_favor_delivery' -ChoiceId 'run_package' -Intent "honor the Crew's visible favor $favor of 1"
            Complete-PublicDelivery -Intent "complete Crew favor $favor of 1"
            $debtCount = Get-GrandFarePublicDebtCount `
                -DebtIndicator (Get-Value $script:LastObservation @('status_hud', 'debt_indicator') $null) `
                -Context "HUD after Crew favor $favor of 1"
            if ($debtCount -ne (1 - $favor)) {
                throw "Crew favor $favor did not remove exactly one visible marker balance."
            }
            continue
        }
        throw "Crew favor $favor surfaced without an enabled public Run the package response."
    }
}


function Ensure-PunchlineCasinoDiscovered {
    $smallNode = Find-WorldNodeIdByArchetype -ArchetypeId 'small_underground_casino'
    if ([string]::IsNullOrWhiteSpace($smallNode)) {
        $tipFound = $false
        $searchArchetypes = @('back_alley', 'gas_station_casino', 'motel', 'bar')
        $searchPriority = @{}
        for ($priority = 0; $priority -lt $searchArchetypes.Count; $priority++) {
            $searchPriority[$searchArchetypes[$priority]] = $priority
        }
        $searchedNodeIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        while (-not $tipFound) {
            $nodeId = [string](Get-Value $script:LastObservation @('environment', 'world_node_id') '')
            $archetype = [string](Get-Value $script:LastObservation @('environment', 'archetype_id') '')
            if ($nodeId -cmatch '^[a-z0-9_]+$' -and
                $searchPriority.ContainsKey($archetype) -and
                $searchedNodeIds.Add($nodeId)) {
                Restore-EnvironmentSurfaceAfterTravelResult
                $canvasTip = Find-CanvasObject -SemanticId 'event:parking_lot_tip'
                $spatialTips = @(Get-Array (Get-Value $script:LastObservation @('spatial', 'objects') @()) | Where-Object {
                    [string](Get-Value $_ @('object_id') '') -ceq 'event:parking_lot_tip'
                })
                if ($spatialTips.Count -gt 1) {
                    throw 'The public room model exposes duplicate Parking Lot Tip objects.'
                }
                $spatialTipReady = $false
                if ($spatialTips.Count -ceq 1) {
                    $tipVisible = Get-Value $spatialTips[0] @('visible') $null
                    $tipEnabled = Get-Value $spatialTips[0] @('enabled') $null
                    $tipInteractive = Get-Value $spatialTips[0] @('interactive') $null
                    if ($tipVisible -isnot [bool] -or $tipEnabled -isnot [bool] -or $tipInteractive -isnot [bool]) {
                        throw 'The public Parking Lot Tip spatial record has malformed visibility, enabled, or interactive state.'
                    }
                    if (-not [bool]$tipVisible -or -not [bool]$tipEnabled -or -not [bool]$tipInteractive) {
                        throw 'The public Parking Lot Tip spatial record is not exactly visible, enabled, and interactive.'
                    }
                    $spatialTipReady = $true
                }
                if ($null -cne $canvasTip) {
                    Invoke-EventObjectChoice -EventId 'parking_lot_tip' -ChoiceId 'follow_tip' -Intent 'follow the visible underground route tip'
                    $tipFound = $true
                    break
                }
                if ($spatialTipReady) {
                    $screen = Get-Value $script:LastObservation @('screen', 'screen') $null
                    $eventVisible = Get-Value $script:LastObservation @('event_popup', 'visible') $null
                    $talkVisible = Get-Value $script:LastObservation @('talk', 'visible') $null
                    $transitionActive = Get-Value $script:LastObservation @('screen', 'travel_transition_active') $null
                    if ($screen -isnot [string] -or [string]$screen -cne 'ENVIRONMENT' -or
                        $eventVisible -isnot [bool] -or [bool]$eventVisible -or
                        $talkVisible -isnot [bool] -or [bool]$talkVisible -or
                        $transitionActive -isnot [bool] -or [bool]$transitionActive) {
                        throw 'The overflow Parking Lot Tip is blocked by a malformed or conflicting public room state.'
                    }
                    $null = Invoke-OverflowRoomActionButton `
                        -ButtonText 'Parking Lot Tip: Follow the tip' `
                        -Intent 'follow the visible overflow underground route tip'
                    Wait-Frames -Frames 10 -Intent 'let the visible Parking Lot Tip response settle'
                    $afterScreen = Get-Value $script:LastObservation @('screen', 'screen') $null
                    $afterEventVisible = Get-Value $script:LastObservation @('event_popup', 'visible') $null
                    $afterTalkVisible = Get-Value $script:LastObservation @('talk', 'visible') $null
                    $afterTransitionActive = Get-Value $script:LastObservation @('screen', 'travel_transition_active') $null
                    if ($afterScreen -isnot [string] -or
                        $afterEventVisible -isnot [bool] -or
                        $afterTalkVisible -isnot [bool] -or [bool]$afterTalkVisible -or
                        $afterTransitionActive -isnot [bool] -or [bool]$afterTransitionActive) {
                        throw 'The overflow Parking Lot Tip response did not settle to an uninterrupted public room.'
                    }
                    if ([bool]$afterEventVisible) {
                        if ([string]$afterScreen -cne 'EVENT') {
                            throw 'The overflow Parking Lot Tip exposed an event outside the exact public event surface.'
                        }
                        $choiceId = Select-GrandFareMachineJamChoice `
                            -EventPopup (Get-Value $script:LastObservation @('event_popup') $null) `
                            -Talk (Get-Value $script:LastObservation @('talk') $null)
                        if ($choiceId -cne 'wait') {
                            throw 'The exact Parking Lot Tip machine_jam policy did not select its visible de-escalation choice.'
                        }
                        $null = Choose-VisibleChoice `
                            -ChoiceId $choiceId `
                            -Intent 'resolve the exact rendered post-tip machine_jam with its visible de-escalation choice'
                        Wait-Frames -Frames 10 -Intent 'wait for the exact post-tip machine_jam response to settle'
                        $afterScreen = Get-Value $script:LastObservation @('screen', 'screen') $null
                        $afterEventVisible = Get-Value $script:LastObservation @('event_popup', 'visible') $null
                        $afterTalkVisible = Get-Value $script:LastObservation @('talk', 'visible') $null
                        $afterTransitionActive = Get-Value $script:LastObservation @('screen', 'travel_transition_active') $null
                        $afterNodeId = Get-Value $script:LastObservation @('environment', 'world_node_id') $null
                        $afterArchetype = Get-Value $script:LastObservation @('environment', 'archetype_id') $null
                        $afterFeedbackTitle = Get-Value $script:LastObservation @('feedback', 'title') $null
                        $afterFeedbackText = Get-Value $script:LastObservation @('feedback', 'text') $null
                        if ([string]$archetype -cne 'gas_station_casino' -or
                            $afterScreen -isnot [string] -or [string]$afterScreen -cne 'RESULT' -or
                            $afterEventVisible -isnot [bool] -or [bool]$afterEventVisible -or
                            $afterTalkVisible -isnot [bool] -or [bool]$afterTalkVisible -or
                            $afterTransitionActive -isnot [bool] -or [bool]$afterTransitionActive -or
                            $afterNodeId -isnot [string] -or [string]$afterNodeId -cne $nodeId -or
                            $afterArchetype -isnot [string] -or [string]$afterArchetype -cne 'gas_station_casino' -or
                            $afterFeedbackTitle -isnot [string] -or [string]$afterFeedbackTitle -cne 'Result' -or
                            $afterFeedbackText -isnot [string] -or [string]$afterFeedbackText -cne 'The package changes hands. Nothing else does.') {
                            throw 'The exact post-tip machine_jam response did not settle to its authenticated public Result surface.'
                        }
                        Restore-EnvironmentSurfaceAfterTravelResult
                        $afterScreen = Get-Value $script:LastObservation @('screen', 'screen') $null
                        $afterEventVisible = Get-Value $script:LastObservation @('event_popup', 'visible') $null
                        $afterTalkVisible = Get-Value $script:LastObservation @('talk', 'visible') $null
                        $afterTransitionActive = Get-Value $script:LastObservation @('screen', 'travel_transition_active') $null
                    }
                    if ([string]$afterScreen -ceq 'RESULT') {
                        $afterFeedbackTitle = Get-Value $script:LastObservation @('feedback', 'title') $null
                        $afterFeedbackText = Get-Value $script:LastObservation @('feedback', 'text') $null
                        if ($afterEventVisible -isnot [bool] -or [bool]$afterEventVisible -or
                            $afterTalkVisible -isnot [bool] -or [bool]$afterTalkVisible -or
                            $afterTransitionActive -isnot [bool] -or [bool]$afterTransitionActive -or
                            $afterFeedbackTitle -isnot [string] -or [string]$afterFeedbackTitle -cne 'Result' -or
                            $afterFeedbackText -isnot [string] -or [string]$afterFeedbackText -cne 'The package changes hands. Nothing else does.') {
                            throw 'The overflow Parking Lot Tip did not settle to its authenticated public Result surface.'
                        }
                        Restore-EnvironmentSurfaceAfterTravelResult
                        $afterScreen = Get-Value $script:LastObservation @('screen', 'screen') $null
                        $afterEventVisible = Get-Value $script:LastObservation @('event_popup', 'visible') $null
                        $afterTalkVisible = Get-Value $script:LastObservation @('talk', 'visible') $null
                        $afterTransitionActive = Get-Value $script:LastObservation @('screen', 'travel_transition_active') $null
                    }
                    if ($afterScreen -isnot [string] -or [string]$afterScreen -cne 'ENVIRONMENT' -or
                        $afterEventVisible -isnot [bool] -or [bool]$afterEventVisible -or
                        $afterTalkVisible -isnot [bool] -or [bool]$afterTalkVisible -or
                        $afterTransitionActive -isnot [bool] -or [bool]$afterTransitionActive) {
                        throw 'The overflow Parking Lot Tip response left a malformed, interrupted, lingering, or chained public surface.'
                    }
                    $tipFound = $true
                    break
                }
            }

            Open-WorldMap
            $eligibleCards = @(Get-MapNodes | Where-Object {
                $candidateId = [string](Get-Value $_ @('id') '')
                $candidateArchetype = [string](Get-Value $_ @('archetype_id') '')
                $travelEnabled = Get-Value $_ @('travel_enabled') $null
                $candidateId -cmatch '^[a-z0-9_]+$' -and
                    $searchPriority.ContainsKey($candidateArchetype) -and
                    $travelEnabled -is [bool] -and [bool]$travelEnabled -and
                    (-not $searchedNodeIds.Contains($candidateId))
            } | Sort-Object `
                @{ Expression = { [int]$searchPriority[[string](Get-Value $_ @('archetype_id') '')] } }, `
                @{ Expression = { [string](Get-Value $_ @('id') '') } })
            Close-WorldMap
            if ($eligibleCards.Count -ceq 0) {
                throw 'No eligible Punchline search candidate remains among the current room and rendered, enabled public travel cards.'
            }
            $nextNodeId = [string](Get-Value $eligibleCards[0] @('id') '')
            $nextArchetype = [string](Get-Value $eligibleCards[0] @('archetype_id') '')
            Travel-ToNode -NodeId $nextNodeId -Intent "look for the visible route into the Punchline from $nextArchetype"
            Restore-EnvironmentSurfaceAfterTravelResult
        }
        $smallNode = Find-WorldNodeIdByArchetype -ArchetypeId 'small_underground_casino'
    }
    if ([string]::IsNullOrWhiteSpace($smallNode)) {
        throw 'Following the Parking Lot Tip did not expose the Punchline on the public map.'
    }
    Navigate-ToNode -NodeId $smallNode -Intent 'travel through the real map to the Punchline'
    Restore-EnvironmentSurfaceAfterTravelResult
    if ($null -cne (Find-CanvasObject -SemanticId 'event:side_door')) {
        Invoke-EventObjectChoice -EventId 'side_door' -ChoiceId 'punchline_password' -Intent 'use the visible password at the Punchline side door'
        Wait-Frames -Frames 12
    }
    elseif ($null -cne (Find-CanvasObject -SemanticId 'environment_layer:casino')) {
        $null = Open-SemanticObject -SemanticId 'environment_layer:casino' -PreferredActions @('Enter Casino', 'Enter Room', 'Enter', 'Open') -Intent 'return through the discovered Punchline casino door'
        Wait-Frames -Frames 12
    }
}


function Invoke-BishopGrandDrinkSobrietyDetour {
    param(
        [Parameter(Mandatory = $true)][ValidateRange(1, 12)][int]$BoundaryNumber
    )
    $archetype = Get-Value $script:LastObservation @('environment', 'archetype_id') $null
    $screen = Get-Value $script:LastObservation @('screen', 'screen') $null
    $eventVisible = Get-Value $script:LastObservation @('event_popup', 'visible') $null
    $talkVisible = Get-Value $script:LastObservation @('talk', 'visible') $null
    if ($archetype -isnot [string] -or [string]$archetype -cne 'grand_casino' -or
        $screen -isnot [string] -or [string]$screen -cne 'ENVIRONMENT' -or
        $eventVisible -isnot [bool] -or [bool]$eventVisible -or
        $talkVisible -isnot [bool] -or [bool]$talkVisible) {
        return $false
    }

    $canvasDrinks = @(Get-Array (Get-Value $script:LastResult @('look', 'clickable', 'canvas_objects') @()) | Where-Object {
        [string](Get-Value $_ @('semantic_id') '') -ceq 'service:house_drink'
    })
    $roomDrinks = @(Get-Array (Get-Value $script:LastObservation @('room_canvas', 'objects') @()) | Where-Object {
        [string](Get-Value $_ @('id') '') -ceq 'service:house_drink'
    })
    if ($canvasDrinks.Count -cne 1 -or $roomDrinks.Count -cne 1) { return $false }
    $rendered = Get-Value $canvasDrinks[0] @('rendered') $null
    $enabled = Get-Value $canvasDrinks[0] @('enabled') $null
    $disabled = Get-Value $roomDrinks[0] @('disabled') $null
    $reason = Get-Value $roomDrinks[0] @('disabled_reason') $null
    if ($rendered -isnot [bool] -or -not [bool]$rendered -or
        $enabled -isnot [bool] -or [bool]$enabled -or
        $disabled -isnot [bool] -or -not [bool]$disabled -or
        $reason -isnot [string] -or [string]$reason -cne 'Too drunk to make another drink help.') {
        return $false
    }

    $currentNodeId = Get-Value $script:LastObservation @('environment', 'world_node_id') $null
    if ($currentNodeId -isnot [string] -or [string]$currentNodeId -cnotmatch '^[a-z0-9_]+$') {
        throw "Bishop presence boundary $BoundaryNumber cannot identify the current Grand Casino map node for its sobriety detour."
    }
    $outboundCash = Get-RenderedHudInteger -Name bankroll -Context "Bishop presence boundary $BoundaryNumber sobriety-detour outbound fare check"
    $distanceRanks = @{
        remote = 0
        far = 1
        local = 2
        near = 3
        same = 4
    }
    Open-WorldMap
    $candidates = @()
    foreach ($node in @(Get-MapNodes)) {
        $nodeId = Get-Value $node @('id') $null
        $travelEnabled = Get-Value $node @('travel_enabled') $null
        if ($nodeId -isnot [string] -or [string]$nodeId -cnotmatch '^[a-z0-9_]+$' -or
            $travelEnabled -isnot [bool]) {
            throw "Bishop presence boundary $BoundaryNumber found a malformed rendered public travel card."
        }
        if (-not [bool]$travelEnabled -or [string]$nodeId -ceq [string]$currentNodeId) { continue }
        $cost = Get-Value $node @('cost') $null
        if (($cost -isnot [int32] -and $cost -isnot [int64]) -or [long]$cost -lt 0) {
            throw "Bishop presence boundary $BoundaryNumber found an enabled public travel card without an exact non-negative fare."
        }
        if ([long]$cost -gt [long]$outboundCash) {
            throw "Bishop presence boundary $BoundaryNumber found an enabled public travel card whose fare exceeds the rendered bankroll."
        }
        if ([long]$cost -eq [long]$outboundCash) {
            continue
        }
        $distance = Get-Value $node @('distance') $null
        if ($distance -isnot [string] -or [string]$distance -cnotin @('remote', 'far', 'local', 'near', 'same')) {
            throw "Bishop presence boundary $BoundaryNumber found an enabled public travel card with an unknown sobriety-decay distance."
        }
        $candidates += [pscustomobject]@{
            id = [string]$nodeId
            cost = [int]$cost
            distance_rank = [int]$distanceRanks[[string]$distance]
        }
    }
    $candidates = @($candidates | Sort-Object distance_rank, cost, id)
    if ($candidates.Count -ceq 0) {
        throw "Bishop presence boundary $BoundaryNumber has no rendered, enabled public destination for one sobriety detour."
    }
    $detourNodeId = [string]$candidates[0].id
    Travel-ToNode `
        -NodeId $detourNodeId `
        -Intent "take one visible sobriety detour from Grand Casino Main at Bishop presence boundary $BoundaryNumber"
    $outboundScreen = Get-Value $script:LastObservation @('screen', 'screen') $null
    $outboundEvent = Get-Value $script:LastObservation @('event_popup', 'visible') $null
    $outboundTalk = Get-Value $script:LastObservation @('talk', 'visible') $null
    if ($outboundScreen -isnot [string] -or [string]$outboundScreen -cnotin @('RESULT', 'ENVIRONMENT') -or
        $outboundEvent -isnot [bool] -or [bool]$outboundEvent -or
        $outboundTalk -isnot [bool] -or [bool]$outboundTalk) {
        throw "Bishop presence boundary $BoundaryNumber sobriety detour was interrupted on its outbound leg."
    }
    Restore-EnvironmentSurfaceAfterTravelResult

    $returnCash = Get-RenderedHudInteger -Name bankroll -Context "Bishop presence boundary $BoundaryNumber sobriety-detour return fare check"
    Open-WorldMap
    $grandCards = @(Get-MapNodes | Where-Object {
        [string](Get-Value $_ @('archetype_id') '') -ceq 'grand_casino'
    })
    if ($grandCards.Count -cne 1) {
        throw "Bishop presence boundary $BoundaryNumber sobriety detour exposes $($grandCards.Count) exact Grand Casino Main return cards."
    }
    $grandId = Get-Value $grandCards[0] @('id') $null
    $grandEnabled = Get-Value $grandCards[0] @('travel_enabled') $null
    $grandCost = Get-Value $grandCards[0] @('cost') $null
    $grandDistance = Get-Value $grandCards[0] @('distance') $null
    if ($grandId -isnot [string] -or [string]$grandId -cnotmatch '^[a-z0-9_]+$' -or
        $grandEnabled -isnot [bool] -or
        ($grandCost -isnot [int32] -and $grandCost -isnot [int64]) -or [long]$grandCost -lt 0 -or
        $grandDistance -isnot [string] -or [string]$grandDistance -cnotin @('remote', 'far', 'local', 'near', 'same')) {
        $returnReason = [string](Get-Value $grandCards[0] @('travel_disabled_reason') 'return unavailable')
        throw "Bishop presence boundary $BoundaryNumber sobriety detour found a malformed Grand Casino Main return card: $returnReason"
    }

    if (-not [bool]$grandEnabled) {
        $returnReason = Get-Value $grandCards[0] @('travel_disabled_reason') $null
        if ($returnReason -isnot [string] -or [string]$returnReason -cne 'Not enough bankroll for this route.' -or
            [long]$grandCost -le [long]$returnCash) {
            throw "Bishop presence boundary $BoundaryNumber sobriety detour cannot use the rendered Grand Casino Main return card: $returnReason"
        }

        $intermediateCandidates = @()
        foreach ($node in @(Get-MapNodes)) {
            $nodeId = Get-Value $node @('id') $null
            $travelEnabled = Get-Value $node @('travel_enabled') $null
            if ($nodeId -isnot [string] -or [string]$nodeId -cnotmatch '^[a-z0-9_]+$' -or
                $travelEnabled -isnot [bool]) {
                throw "Bishop presence boundary $BoundaryNumber found a malformed rendered public intermediate-return card."
            }
            if (-not [bool]$travelEnabled -or [string]$nodeId -ceq [string]$grandId) { continue }
            $cost = Get-Value $node @('cost') $null
            $distance = Get-Value $node @('distance') $null
            if (($cost -isnot [int32] -and $cost -isnot [int64]) -or [long]$cost -lt 0 -or
                [long]$cost -gt [long]$returnCash -or
                $distance -isnot [string] -or [string]$distance -cnotin @('remote', 'far', 'local', 'near', 'same')) {
                throw "Bishop presence boundary $BoundaryNumber found an enabled public intermediate-return card with invalid travel authority."
            }
            $graphDistance = Get-PublicGraphDistance -From ([string]$nodeId) -To ([string]$grandId)
            if ($graphDistance -ceq [int]::MaxValue) { continue }
            $intermediateCandidates += [pscustomobject]@{
                id = [string]$nodeId
                graph_distance = [int]$graphDistance
                cost = [int]$cost
            }
        }
        $intermediateCandidates = @($intermediateCandidates | Sort-Object graph_distance, cost, id)
        if ($intermediateCandidates.Count -ceq 0) {
            throw "Bishop presence boundary $BoundaryNumber has no rendered, enabled, affordable public intermediate return toward Grand Casino Main."
        }
        $intermediateNodeId = [string]$intermediateCandidates[0].id
        Travel-ToNode `
            -NodeId $intermediateNodeId `
            -Intent "take one visible intermediate return leg toward Grand Casino Main after Bishop presence boundary $BoundaryNumber sobriety detour"
        $intermediateScreen = Get-Value $script:LastObservation @('screen', 'screen') $null
        $intermediateEvent = Get-Value $script:LastObservation @('event_popup', 'visible') $null
        $intermediateTalk = Get-Value $script:LastObservation @('talk', 'visible') $null
        if ($intermediateScreen -isnot [string] -or [string]$intermediateScreen -cnotin @('RESULT', 'ENVIRONMENT') -or
            $intermediateEvent -isnot [bool] -or [bool]$intermediateEvent -or
            $intermediateTalk -isnot [bool] -or [bool]$intermediateTalk) {
            throw "Bishop presence boundary $BoundaryNumber sobriety detour was interrupted on its intermediate return leg."
        }
        Restore-EnvironmentSurfaceAfterTravelResult

        $returnCash = Get-RenderedHudInteger -Name bankroll -Context "Bishop presence boundary $BoundaryNumber post-intermediate Grand return fare check"
        Open-WorldMap
        $grandCards = @(Get-MapNodes | Where-Object {
            [string](Get-Value $_ @('archetype_id') '') -ceq 'grand_casino'
        })
        if ($grandCards.Count -cne 1) {
            throw "Bishop presence boundary $BoundaryNumber intermediate return exposes $($grandCards.Count) exact Grand Casino Main cards."
        }
        $grandId = Get-Value $grandCards[0] @('id') $null
        $grandEnabled = Get-Value $grandCards[0] @('travel_enabled') $null
        $grandCost = Get-Value $grandCards[0] @('cost') $null
        $grandDistance = Get-Value $grandCards[0] @('distance') $null
    }

    if ($grandId -isnot [string] -or [string]$grandId -cnotmatch '^[a-z0-9_]+$' -or
        $grandEnabled -isnot [bool] -or -not [bool]$grandEnabled -or
        ($grandCost -isnot [int32] -and $grandCost -isnot [int64]) -or [long]$grandCost -lt 0 -or
        [long]$grandCost -gt [long]$returnCash -or
        $grandDistance -isnot [string] -or [string]$grandDistance -cnotin @('remote', 'far', 'local', 'near', 'same')) {
        $returnReason = [string](Get-Value $grandCards[0] @('travel_disabled_reason') 'return unavailable')
        throw "Bishop presence boundary $BoundaryNumber sobriety detour did not restore an exact rendered, enabled, affordable Grand Casino Main return card: $returnReason"
    }
    Travel-ToNode `
        -NodeId ([string]$grandId) `
        -Intent "return through the visible Grand Casino Main card after Bishop presence boundary $BoundaryNumber sobriety detour"
    $returnArchetype = Get-Value $script:LastObservation @('environment', 'archetype_id') $null
    $returnScreen = Get-Value $script:LastObservation @('screen', 'screen') $null
    $returnEvent = Get-Value $script:LastObservation @('event_popup', 'visible') $null
    $returnTalk = Get-Value $script:LastObservation @('talk', 'visible') $null
    if ($returnArchetype -isnot [string] -or [string]$returnArchetype -cne 'grand_casino' -or
        $returnScreen -isnot [string] -or [string]$returnScreen -cnotin @('RESULT', 'ENVIRONMENT') -or
        $returnEvent -isnot [bool] -or [bool]$returnEvent -or
        $returnTalk -isnot [bool] -or [bool]$returnTalk) {
        throw "Bishop presence boundary $BoundaryNumber sobriety detour was interrupted on its Grand Casino Main return leg."
    }
    Restore-GrandCasinoEnvironmentSurface

    $restoredDrink = Find-CanvasObject -SemanticId 'service:house_drink'
    if ($null -eq $restoredDrink) {
        $disabledDrinks = @(Get-Array (Get-Value $script:LastObservation @('spatial', 'objects') @()) | Where-Object {
            [string](Get-Value $_ @('object_id') '') -ceq 'service:house_drink'
        })
        if ($disabledDrinks.Count -cne 1 -or
            [string](Get-Value $disabledDrinks[0] @('label') '') -cne 'Buy a Drink' -or
            [string](Get-Value $disabledDrinks[0] @('object_type') '') -cne 'service' -or
            (Get-Value $disabledDrinks[0] @('visible') $null) -isnot [bool] -or -not [bool](Get-Value $disabledDrinks[0] @('visible') $false) -or
            (Get-Value $disabledDrinks[0] @('interactive') $null) -isnot [bool] -or -not [bool](Get-Value $disabledDrinks[0] @('interactive') $false) -or
            (Get-Value $disabledDrinks[0] @('enabled') $null) -isnot [bool] -or [bool](Get-Value $disabledDrinks[0] @('enabled') $true) -or
            [string](Get-Value $disabledDrinks[0] @('disabled_reason') '') -cne 'Too drunk to make another drink help.' -or
            [string](Get-Value $script:LastObservation @('screen', 'screen') '') -cne 'ENVIRONMENT' -or
            [string](Get-Value $script:LastObservation @('environment', 'world_node_id') '') -cne [string]$currentNodeId -or
            [string](Get-Value $script:LastObservation @('environment', 'archetype_id') '') -cne 'grand_casino' -or
            [bool](Get-Value $script:LastObservation @('event_popup', 'visible') $true) -or
            [bool](Get-Value $script:LastObservation @('talk', 'visible') $true) -or
            (Get-Value $script:LastObservation @('screen', 'travel_transition_active') $null) -isnot [bool] -or
            [bool](Get-Value $script:LastObservation @('screen', 'travel_transition_active') $true)) {
            throw "Grand Casino Main did not restore either the enabled house drink or its exact sobriety-only disabled public state after Bishop presence boundary $BoundaryNumber."
        }

        $compedObjects = @(Get-Array (Get-Value $script:LastResult @('look', 'clickable', 'canvas_objects') @()) | Where-Object {
            [string](Get-Value $_ @('semantic_id') '') -ceq 'event:comped_suite_offer'
        })
        $compedOverflow = $false
        if ($compedObjects.Count -ceq 0) {
            $compedSpatial = @(Get-Array (Get-Value $script:LastObservation @('spatial', 'objects') @()) | Where-Object {
                [string](Get-Value $_ @('object_id') '') -ceq 'event:comped_suite_offer'
            })
            if ($compedSpatial.Count -cne 1 -or
                [string](Get-Value $compedSpatial[0] @('label') '') -cne 'Comped Suite Offer' -or
                [string](Get-Value $compedSpatial[0] @('object_type') '') -cne 'event' -or
                (Get-Value $compedSpatial[0] @('visible') $null) -isnot [bool] -or -not [bool](Get-Value $compedSpatial[0] @('visible') $false) -or
                (Get-Value $compedSpatial[0] @('interactive') $null) -isnot [bool] -or -not [bool](Get-Value $compedSpatial[0] @('interactive') $false) -or
                (Get-Value $compedSpatial[0] @('enabled') $null) -isnot [bool] -or -not [bool](Get-Value $compedSpatial[0] @('enabled') $false)) {
                throw "Bishop presence boundary $BoundaryNumber cannot authenticate the exact visible Comped Suite Offer before the final sobriety loop."
            }
            $compedOverflow = $true
        }
        elseif ($compedObjects.Count -cne 1 -or
            [string](Get-Value $compedObjects[0] @('label') '') -cne 'Comped Suite Offer' -or
            [string](Get-Value $compedObjects[0] @('object_type') '') -cne 'event' -or
            (Get-Value $compedObjects[0] @('rendered') $null) -isnot [bool] -or -not [bool](Get-Value $compedObjects[0] @('rendered') $false) -or
            (Get-Value $compedObjects[0] @('enabled') $null) -isnot [bool] -or -not [bool](Get-Value $compedObjects[0] @('enabled') $false)) {
            throw "Bishop presence boundary $BoundaryNumber cannot authenticate the exact rendered Comped Suite Offer before the final sobriety loop."
        }
        $beforeCompCash = Get-RenderedHudInteger -Name bankroll -Context "Bishop presence boundary $BoundaryNumber bankroll before declining the Comped Suite Offer"
        $beforeCompHeat = Get-RenderedHudInteger -Name heat_level -Context "Bishop presence boundary $BoundaryNumber heat before declining the Comped Suite Offer"
        if ($compedOverflow) {
            $null = Invoke-OverflowRoomActionButton `
                -ButtonText 'Comped Suite Offer: Decline' `
                -Intent "decline the exact visible overflow Comped Suite Offer before the final Bishop presence boundary $BoundaryNumber sobriety loop"
            Wait-Frames -Frames 10
        }
        else {
            Select-EventObject -EventId 'comped_suite_offer'
            Wait-Frames -Frames 2 -Intent "render the exact Comped Suite Offer choices at Bishop presence boundary $BoundaryNumber"
            $declineRow = Get-EventChoiceRoomAction -EventId 'comped_suite_offer' -ChoiceId 'decline'
            if ($null -eq $declineRow -or
                [string](Get-Value $declineRow @('label') '') -cne 'Decline' -or
                (Get-Value $declineRow @('rendered') $null) -isnot [bool] -or -not [bool](Get-Value $declineRow @('rendered') $false) -or
                (Get-Value $declineRow @('enabled') $null) -isnot [bool] -or -not [bool](Get-Value $declineRow @('enabled') $false)) {
                throw "Bishop presence boundary $BoundaryNumber cannot authenticate the exact rendered Decline choice on the Comped Suite Offer."
            }
            Invoke-EventObjectChoice `
                -EventId 'comped_suite_offer' `
                -ChoiceId 'decline' `
                -Intent "decline the exact visible Comped Suite Offer before the final Bishop presence boundary $BoundaryNumber sobriety loop"
        }
        $afterCompCash = Get-RenderedHudInteger -Name bankroll -Context "Bishop presence boundary $BoundaryNumber bankroll after declining the Comped Suite Offer"
        $afterCompHeat = Get-RenderedHudInteger -Name heat_level -Context "Bishop presence boundary $BoundaryNumber heat after declining the Comped Suite Offer"
        $drunkRendered = Get-ExactReplayBoolean `
            -InputObject $script:LastObservation `
            -Path @('status_hud', 'drunk_rendered') `
            -Context "Bishop presence boundary $BoundaryNumber rendered Drunk witness after declining the Comped Suite Offer"
        $drunkText = Get-ExactReplayString `
            -InputObject $script:LastObservation `
            -Path @('status_hud', 'drunk_text') `
            -Context "Bishop presence boundary $BoundaryNumber rendered Drunk projection after declining the Comped Suite Offer"
        $feedbackVisible = Get-ExactReplayBoolean `
            -InputObject $script:LastObservation `
            -Path @('feedback', 'visible') `
            -Context "Bishop presence boundary $BoundaryNumber Comped Suite decline feedback visibility"
        $feedbackTitle = Get-ExactReplayString `
            -InputObject $script:LastObservation `
            -Path @('feedback', 'title') `
            -Context "Bishop presence boundary $BoundaryNumber Comped Suite decline feedback title"
        $feedbackText = Get-ExactReplayString `
            -InputObject $script:LastObservation `
            -Path @('feedback', 'text') `
            -Context "Bishop presence boundary $BoundaryNumber Comped Suite decline feedback text"
        $messageVisible = Get-ExactReplayBoolean `
            -InputObject $script:LastObservation `
            -Path @('message', 'visible') `
            -Context "Bishop presence boundary $BoundaryNumber Comped Suite decline message visibility"
        $messageText = Get-ExactReplayString `
            -InputObject $script:LastObservation `
            -Path @('message', 'text') `
            -Context "Bishop presence boundary $BoundaryNumber Comped Suite decline message"
        if ($afterCompCash -cne $beforeCompCash -or
            $afterCompHeat -cne ($beforeCompHeat - 3) -or
            -not $drunkRendered -or $drunkText -cne '100' -or
            -not $feedbackVisible -or $feedbackTitle -cne 'Result' -or
            $feedbackText -cne 'You keep your distance from the kindness.  Heat -2' -or
            $messageVisible -or $messageText -cne 'You keep your distance from the kindness.' -or
            [string](Get-Value $script:LastObservation @('screen', 'screen') '') -cne 'RESULT' -or
            [string](Get-Value $script:LastObservation @('environment', 'world_node_id') '') -cne [string]$currentNodeId -or
            [string](Get-Value $script:LastObservation @('environment', 'archetype_id') '') -cne 'grand_casino' -or
            [bool](Get-Value $script:LastObservation @('event_popup', 'visible') $true) -or
            [bool](Get-Value $script:LastObservation @('talk', 'visible') $true) -or
            (Get-Value $script:LastObservation @('screen', 'travel_transition_active') $null) -isnot [bool] -or
            [bool](Get-Value $script:LastObservation @('screen', 'travel_transition_active') $true)) {
            throw "Bishop presence boundary $BoundaryNumber Comped Suite decline did not settle the exact public economy, Drunk projection, and modal-free Grand state."
        }
        Restore-EnvironmentSurfaceAfterTravelResult
        $restoredCompCash = Get-RenderedHudInteger -Name bankroll -Context "Bishop presence boundary $BoundaryNumber bankroll after restoring the Comped Suite decline"
        $restoredCompHeat = Get-RenderedHudInteger -Name heat_level -Context "Bishop presence boundary $BoundaryNumber heat after restoring the Comped Suite decline"
        $restoredDrunkRendered = Get-ExactReplayBoolean `
            -InputObject $script:LastObservation `
            -Path @('status_hud', 'drunk_rendered') `
            -Context "Bishop presence boundary $BoundaryNumber restored rendered Drunk witness after declining the Comped Suite Offer"
        $restoredDrunkText = Get-ExactReplayString `
            -InputObject $script:LastObservation `
            -Path @('status_hud', 'drunk_text') `
            -Context "Bishop presence boundary $BoundaryNumber restored rendered Drunk projection after declining the Comped Suite Offer"
        if ($restoredCompCash -cne $afterCompCash -or
            $restoredCompHeat -cne $afterCompHeat -or
            -not $restoredDrunkRendered -or $restoredDrunkText -cne '100' -or
            [string](Get-Value $script:LastObservation @('screen', 'screen') '') -cne 'ENVIRONMENT' -or
            [string](Get-Value $script:LastObservation @('environment', 'world_node_id') '') -cne [string]$currentNodeId -or
            [string](Get-Value $script:LastObservation @('environment', 'archetype_id') '') -cne 'grand_casino' -or
            [bool](Get-Value $script:LastObservation @('event_popup', 'visible') $true) -or
            [bool](Get-Value $script:LastObservation @('talk', 'visible') $true) -or
            (Get-Value $script:LastObservation @('screen', 'travel_transition_active') $null) -isnot [bool] -or
            [bool](Get-Value $script:LastObservation @('screen', 'travel_transition_active') $true)) {
            throw "Bishop presence boundary $BoundaryNumber Comped Suite decline did not restore the exact modal-free Grand environment before the final sobriety loop."
        }

        Open-WorldMap
        $loungeCards = @(Get-MapNodes | Where-Object {
            [string](Get-Value $_ @('archetype_id') '') -ceq 'kitty_cat_lounge'
        })
        if ($loungeCards.Count -cne 1) {
            throw "Bishop presence boundary $BoundaryNumber final sobriety loop exposes $($loungeCards.Count) exact Kitty Cat Lounge cards."
        }
        $loungeId = Get-Value $loungeCards[0] @('id') $null
        $loungeEnabled = Get-Value $loungeCards[0] @('travel_enabled') $null
        $loungeCost = Get-Value $loungeCards[0] @('cost') $null
        $loungeDistance = Get-Value $loungeCards[0] @('distance') $null
        if ($loungeId -isnot [string] -or [string]$loungeId -cnotmatch '^[a-z0-9_]+$' -or
            $loungeEnabled -isnot [bool] -or -not [bool]$loungeEnabled -or
            ($loungeCost -isnot [int32] -and $loungeCost -isnot [int64]) -or [long]$loungeCost -cne 0 -or
            $loungeDistance -isnot [string] -or [string]$loungeDistance -cne 'near') {
            $loungeReason = [string](Get-Value $loungeCards[0] @('travel_disabled_reason') 'Lounge unavailable')
            throw "Bishop presence boundary $BoundaryNumber final sobriety loop rejected the exact zero-fare near Lounge card: $loungeReason"
        }
        Travel-ToNode `
            -NodeId ([string]$loungeId) `
            -Intent "take the one final visible zero-fare near Lounge sobriety leg at Bishop presence boundary $BoundaryNumber"
        $loungeScreen = Get-Value $script:LastObservation @('screen', 'screen') $null
        if ($loungeScreen -isnot [string] -or [string]$loungeScreen -cnotin @('RESULT', 'ENVIRONMENT') -or
            [string](Get-Value $script:LastObservation @('environment', 'world_node_id') '') -cne [string]$loungeId -or
            [string](Get-Value $script:LastObservation @('environment', 'archetype_id') '') -cne 'kitty_cat_lounge' -or
            [bool](Get-Value $script:LastObservation @('event_popup', 'visible') $true) -or
            [bool](Get-Value $script:LastObservation @('talk', 'visible') $true) -or
            [bool](Get-Value $script:LastObservation @('screen', 'travel_transition_active') $true)) {
            throw "Bishop presence boundary $BoundaryNumber final sobriety loop was interrupted on its zero-fare Lounge leg."
        }
        Restore-EnvironmentSurfaceAfterTravelResult

        Open-WorldMap
        $finalGrandCards = @(Get-MapNodes | Where-Object {
            [string](Get-Value $_ @('id') '') -ceq [string]$currentNodeId -and
                [string](Get-Value $_ @('archetype_id') '') -ceq 'grand_casino'
        })
        if ($finalGrandCards.Count -cne 1) {
            throw "Bishop presence boundary $BoundaryNumber final sobriety loop exposes $($finalGrandCards.Count) exact Grand Casino Main return cards."
        }
        $finalGrandEnabled = Get-Value $finalGrandCards[0] @('travel_enabled') $null
        $finalGrandCost = Get-Value $finalGrandCards[0] @('cost') $null
        $finalGrandDistance = Get-Value $finalGrandCards[0] @('distance') $null
        if ($finalGrandEnabled -isnot [bool] -or -not [bool]$finalGrandEnabled -or
            ($finalGrandCost -isnot [int32] -and $finalGrandCost -isnot [int64]) -or [long]$finalGrandCost -cne 0 -or
            $finalGrandDistance -isnot [string] -or [string]$finalGrandDistance -cne 'near') {
            $finalGrandReason = [string](Get-Value $finalGrandCards[0] @('travel_disabled_reason') 'Grand return unavailable')
            throw "Bishop presence boundary $BoundaryNumber final sobriety loop rejected the exact zero-fare near Grand return card: $finalGrandReason"
        }
        Travel-ToNode `
            -NodeId ([string]$currentNodeId) `
            -Intent "return through the one final visible zero-fare near Grand card at Bishop presence boundary $BoundaryNumber"
        $finalReturnScreen = Get-Value $script:LastObservation @('screen', 'screen') $null
        if ($finalReturnScreen -isnot [string] -or [string]$finalReturnScreen -cnotin @('RESULT', 'ENVIRONMENT') -or
            [string](Get-Value $script:LastObservation @('environment', 'world_node_id') '') -cne [string]$currentNodeId -or
            [string](Get-Value $script:LastObservation @('environment', 'archetype_id') '') -cne 'grand_casino' -or
            [bool](Get-Value $script:LastObservation @('event_popup', 'visible') $true) -or
            [bool](Get-Value $script:LastObservation @('talk', 'visible') $true) -or
            [bool](Get-Value $script:LastObservation @('screen', 'travel_transition_active') $true)) {
            throw "Bishop presence boundary $BoundaryNumber final sobriety loop was interrupted on its zero-fare Grand return leg."
        }
        Restore-GrandCasinoEnvironmentSurface
        $restoredDrink = Find-CanvasObject -SemanticId 'service:house_drink'
    }
    if ($null -ceq $restoredDrink -or
        [string](Get-Value $restoredDrink @('label') '') -cne 'Buy a Drink' -or
        [string](Get-Value $restoredDrink @('object_type') '') -cne 'drink') {
        throw "Grand Casino Main did not restore the rendered, enabled house drink after Bishop presence boundary $BoundaryNumber sobriety detour."
    }
    return $true
}


function Invoke-BishopPresenceHouseDrinkBoundary {
    param(
        [Parameter(Mandatory = $true)][ValidateRange(1, 12)][int]$BoundaryNumber
    )
    # Bishop rotates through the Grand Casino. Keep his action boundary in that
    # same venue instead of forcing a detour to a disconnected Corner Store node.
    # The main-floor drink is an ordinary rendered, priced player action.
    Reach-GrandCasino
    Enter-GrandRoom -Room main
    Restore-EnvironmentSurfaceAfterTravelResult

    $service = Find-CanvasObject -SemanticId 'service:house_drink'
    if ($null -ceq $service -and (Invoke-BishopGrandDrinkSobrietyDetour -BoundaryNumber $BoundaryNumber)) {
        $service = Find-CanvasObject -SemanticId 'service:house_drink'
    }
    if ($null -ceq $service -or
        [string](Get-Value $service @('label') '') -cne 'Buy a Drink' -or
        [string](Get-Value $service @('object_type') '') -cne 'drink') {
        throw 'Grand Casino Main does not expose the rendered, enabled house drink used to advance Bishop presence.'
    }
    $beforeCash = Get-RenderedHudInteger -Name bankroll -Context "Bishop presence boundary $BoundaryNumber bankroll before the visible house drink"
    if ($beforeCash -lt 8) {
        throw "The visible house drink costs `$8, but only `$$beforeCash remains before Bishop presence boundary $BoundaryNumber."
    }
    $null = Open-SemanticObject `
        -SemanticId 'service:house_drink' `
        -PreferredActions @('Use') `
        -Intent "buy the visible `$8 house drink to advance Bishop presence boundary $BoundaryNumber"
    Wait-Frames -Frames 10
    $afterCash = Get-RenderedHudInteger -Name bankroll -Context "Bishop presence boundary $BoundaryNumber bankroll after the visible house drink"
    if ($afterCash -ne $beforeCash - 8) {
        throw "The visible house drink did not charge its exact `$8 price at Bishop presence boundary $BoundaryNumber (`$$beforeCash -> `$$afterCash)."
    }

    $eventVisible = Get-Value $script:LastObservation @('event_popup', 'visible') $null
    $talkVisible = Get-Value $script:LastObservation @('talk', 'visible') $null
    if ($eventVisible -isnot [bool] -or $talkVisible -isnot [bool]) {
        throw "Bishop presence boundary $BoundaryNumber lost its exact boolean modal visibility signals."
    }
    if ([bool]$talkVisible) {
        throw "Bishop presence boundary $BoundaryNumber encountered an unexpected visible TalkDock."
    }
    if ([bool]$eventVisible) {
        $renderValid = Get-Value $script:LastObservation @('event_popup', 'render_valid') $null
        $eventId = Get-Value $script:LastObservation @('event_popup', 'event_id') $null
        $choiceIds = @(Get-VisibleChoiceIds)
        if ($renderValid -isnot [bool] -or -not [bool]$renderValid -or
            $eventId -isnot [string] -or [string]$eventId -cne 'eye_in_the_sky' -or
            ($choiceIds -join ',') -cne 'change_table,press_anyway') {
            throw "Bishop presence boundary $BoundaryNumber encountered an unexpected or incomplete visible event."
        }
        $pressAnyway = @(Get-Array (Get-Value $script:LastObservation @('event_popup', 'choices') @()) | Where-Object {
            [string](Get-Value $_ @('id') '') -ceq 'press_anyway'
        })
        if ($pressAnyway.Count -cne 1 -or
            (Get-Value $pressAnyway[0] @('enabled') $null) -isnot [bool] -or
            -not [bool](Get-Value $pressAnyway[0] @('enabled') $false)) {
            throw "Bishop presence boundary $BoundaryNumber did not expose one exact rendered, enabled press_anyway choice."
        }
        $null = Choose-VisibleChoice `
            -ChoiceId 'press_anyway' `
            -Intent "press on through the visible Eye in the Sky response at Bishop presence boundary $BoundaryNumber"
        Wait-Frames -Frames 12 -Intent 'let the visible Eye in the Sky response close before returning to room actions'
        $afterEventVisible = Get-Value $script:LastObservation @('event_popup', 'visible') $null
        $afterTalkVisible = Get-Value $script:LastObservation @('talk', 'visible') $null
        if ($afterEventVisible -isnot [bool] -or $afterTalkVisible -isnot [bool] -or
            [bool]$afterEventVisible -or [bool]$afterTalkVisible) {
            throw "Bishop presence boundary $BoundaryNumber did not return to a modal-free public room after press_anyway."
        }
    }

    if (Test-CrewFavorPublicSurface) {
        throw 'A Crew favor resurfaced after the one-favor marker was visibly cleared.'
    }
    Restore-EnvironmentSurfaceAfterTravelResult
}


function Find-BishopSurfaceAtGrand {
    for ($boundary = 0; $boundary -le 12; $boundary++) {
        Reach-GrandCasino
        foreach ($room in @('main', 'cage')) {
            Enter-GrandRoom -Room $room
            foreach ($eventId in @('recruitment_bishop', 'crew_contact_bishop')) {
                if ($null -cne (Find-CanvasObject -SemanticId "event:$eventId")) { return $eventId }
                $spatial = @(Get-Array (Get-Value $script:LastObservation @('spatial', 'objects') @()) | Where-Object {
                    [string](Get-Value $_ @('object_id') '') -ceq "event:$eventId"
                })
                if ($spatial.Count -gt 1) {
                    throw "The public room model exposes duplicate Bishop $eventId objects."
                }
                if ($spatial.Count -ceq 1) {
                    $visible = Get-Value $spatial[0] @('visible') $null
                    $enabled = Get-Value $spatial[0] @('enabled') $null
                    $interactive = Get-Value $spatial[0] @('interactive') $null
                    if ($visible -isnot [bool] -or $enabled -isnot [bool] -or $interactive -isnot [bool] -or
                        -not [bool]$visible -or -not [bool]$enabled -or -not [bool]$interactive -or
                        [string](Get-Value $spatial[0] @('label') '') -cne 'Bishop' -or
                        [string](Get-Value $spatial[0] @('object_type') '') -cne 'event') {
                        throw "The public Bishop $eventId spatial record is not exactly visible, enabled, interactive, and event-backed."
                    }
                    return $eventId
                }
            }
        }
        if ($boundary -lt 12) {
            Invoke-BishopPresenceHouseDrinkBoundary -BoundaryNumber ($boundary + 1)
        }
    }
    throw "Bishop did not rotate onto either player-accessible Grand Casino room within twelve visible action boundaries."
}


function Open-BishopConversationSurface {
    param(
        [Parameter(Mandatory = $true)][string]$EventId,
        [Parameter(Mandatory = $true)][string]$Intent
    )
    $semanticId = "event:$EventId"
    if ($null -cne (Find-CanvasObject -SemanticId $semanticId)) {
        $null = Open-SemanticObject `
            -SemanticId $semanticId `
            -PreferredActions @('Talk', 'inspect_event_choices', 'Open', 'Approach') `
            -Intent $Intent
    }
    else {
        $spatial = @(Get-Array (Get-Value $script:LastObservation @('spatial', 'objects') @()) | Where-Object {
            [string](Get-Value $_ @('object_id') '') -ceq $semanticId
        })
        if ($spatial.Count -cne 1 -or
            [string](Get-Value $spatial[0] @('label') '') -cne 'Bishop' -or
            [string](Get-Value $spatial[0] @('object_type') '') -cne 'event' -or
            (Get-Value $spatial[0] @('visible') $null) -isnot [bool] -or -not [bool](Get-Value $spatial[0] @('visible') $false) -or
            (Get-Value $spatial[0] @('enabled') $null) -isnot [bool] -or -not [bool](Get-Value $spatial[0] @('enabled') $false) -or
            (Get-Value $spatial[0] @('interactive') $null) -isnot [bool] -or -not [bool](Get-Value $spatial[0] @('interactive') $false)) {
            throw "The public Bishop $EventId surface is neither a canvas object nor one exact visible, enabled, interactive spatial event."
        }
        $null = Invoke-OverflowRoomActionButton `
            -ButtonText 'Bishop: Talk' `
            -Intent $Intent
    }
    Wait-ForFullyRenderedTalkSurface -Intent $Intent
}


function Recruit-Bishop {
    $surface = Find-BishopSurfaceAtGrand
    if ($surface -ceq 'crew_contact_bishop') { return }
    Open-BishopConversationSurface -EventId $surface -Intent 'open Bishop''s exact visible appointment'
    if ('wait_for_bishop' -cin @(Get-VisibleChoiceIds)) {
        $null = Choose-VisibleChoice -ChoiceId 'wait_for_bishop' -Intent "wait through Bishop's visible first appointment beat"
    }
    else {
        throw "Bishop's authenticated appointment exposed no visible wait_for_bishop choice."
    }
    Wait-Frames -Frames 10
    if ('work_with_bishop' -cnotin @(Get-VisibleChoiceIds)) {
        Open-BishopConversationSurface `
            -EventId 'recruitment_bishop' `
            -Intent 'reopen Bishop''s exact visible appointment after waiting'
    }
    if ('work_with_bishop' -cin @(Get-VisibleChoiceIds)) {
        $null = Choose-VisibleChoice -ChoiceId 'work_with_bishop' -Intent 'keep the visible appointment and recruit Bishop'
    }
    else {
        throw "Bishop's authenticated appointment exposed no visible work_with_bishop choice."
    }
    Wait-Frames -Frames 12
    $eventVisible = Get-Value $script:LastObservation @('event_popup', 'visible') $null
    if ($eventVisible -isnot [bool]) {
        throw "Bishop's completed appointment lost its exact public event-popup visibility witness."
    }
    if ([bool]$eventVisible -and -not (Resolve-BlackjackRouteEventPopup)) {
        throw "Bishop's completed appointment exposed an unsupported visible route event."
    }
}


function Start-BishopContactJob {
    param([Parameter(Mandatory = $true)][string[]]$Preference)
    $surface = Find-BishopSurfaceAtGrand
    if ($surface -ceq 'recruitment_bishop') {
        Recruit-Bishop
        $surface = Find-BishopSurfaceAtGrand
    }
    Open-BishopConversationSurface `
        -EventId 'crew_contact_bishop' `
        -Intent 'open Bishop''s exact visible Crew contact'
    foreach ($choiceId in $Preference) {
        if ($choiceId -cin @(Get-VisibleChoiceIds)) {
            $null = Choose-VisibleChoice -ChoiceId $choiceId -Intent "accept Bishop's visible $choiceId job"
            Wait-Frames -Frames 10
            return $choiceId
        }
        $row = Get-EventChoiceRoomAction -EventId 'crew_contact_bishop' -ChoiceId $choiceId
        if ($null -cne $row -and [bool](Get-Value $row @('enabled') $false)) {
            $null = Invoke-RoomActionRow -Row $row -Intent "accept Bishop's visible $choiceId job"
            Wait-Frames -Frames 10
            return $choiceId
        }
    }
    $visible = @(Get-RoomActions | ForEach-Object { [string](Get-Value $_ @('emit_object_id') '') }) -join ', '
    throw "Bishop exposed none of the requested public jobs: $($Preference -join ', '). Visible actions: $visible"
}


function Enter-PunchlineBackRoom {
    param([switch]$AllowUnavailable)
    Ensure-PunchlineCasinoDiscovered
    if ($null -cne (Find-CanvasObject -SemanticId 'event:crew_planning_table')) { return $true }
    $layer = Find-CanvasObject -SemanticId 'environment_layer:back_room'
    if ($null -ceq $layer -and $null -cne (Find-CanvasObject -SemanticId 'environment_layer:casino')) {
        $null = Open-SemanticObject -SemanticId 'environment_layer:casino' -PreferredActions @('Enter Casino', 'Enter Room', 'Enter', 'Open') -Intent 'enter the discovered Punchline casino before the back-room door'
        Wait-Frames -Frames 12
        $layer = Find-CanvasObject -SemanticId 'environment_layer:back_room'
    }
    if ($null -ceq $layer) {
        if ($AllowUnavailable) { return $false }
        throw 'The visible Punchline route did not expose its Made-standing back room.'
    }
    $null = Open-SemanticObject -SemanticId 'environment_layer:back_room' -PreferredActions @('Enter Back Room', 'Enter Room', 'Enter', 'Open') -Intent 'enter the real Punchline back room'
    Wait-Frames -Frames 12
    if ($null -ceq (Find-CanvasObject -SemanticId 'event:crew_planning_table')) {
        if ($AllowUnavailable) { return $false }
        throw 'The back-room door did not reach the visible Crew planning table.'
    }
    return $true
}


function Close-VisibleChoiceSurface {
    foreach ($choiceId in @('leave', 'leave_counter', 'keep_moving')) {
        if ($choiceId -cin @(Get-VisibleChoiceIds)) {
            $null = Choose-VisibleChoice -ChoiceId $choiceId -Intent 'leave the visible choice surface without changing the route'
            Wait-Frames -Frames 8
            return
        }
    }
}


function Test-CountPlanLive {
    if ($null -ceq (Find-CanvasObject -SemanticId 'event:crew_planning_table')) { return $false }
    Select-EventObject -EventId 'crew_planning_table'
    $row = Get-EventChoiceRoomAction -EventId 'crew_planning_table' -ChoiceId 'lock_the_count'
    $live = $false
    if ($null -cne $row) {
        $enabled = Get-Value $row @('enabled') $null
        $rendered = Get-Value $row @('rendered') $null
        if ($enabled -isnot [bool] -or $rendered -isnot [bool]) {
            throw 'The Count planning row has no exact rendered/enabled public witnesses.'
        }
        $live = [bool]$enabled -and [bool]$rendered
    }
    Close-VisibleChoiceSurface
    return $live
}


function Assert-HeistAuditKnowledgeUnderHostileRevisit {
    Reach-GrandCasino
    Restore-EnvironmentSurfaceAfterTravelResult
    $null = Assert-RenderedConventionCrowdHook
    $null = Enter-PunchlineBackRoom
    if (-not (Test-CountPlanLive)) {
        throw 'The Count did not remain visibly live after the learned Audit rolled over to the hostile Convention revisit.'
    }
}


function Start-BishopBoardJob {
    if ($null -ceq (Find-CanvasObject -SemanticId 'event:crew_job_board')) {
        throw 'The real Punchline back room exposes no visible Job Board.'
    }
    Select-EventObject -EventId 'crew_job_board'
    foreach ($choiceId in @('accept_bishop_cage_packet', 'accept_bishop_camera_window')) {
        if ($choiceId -cin @(Get-VisibleChoiceIds)) {
            $null = Choose-VisibleChoice -ChoiceId $choiceId -Intent "take Bishop's visible Job Board work"
            Wait-Frames -Frames 10
            return $choiceId
        }
        $row = Get-EventChoiceRoomAction -EventId 'crew_job_board' -ChoiceId $choiceId
        if ($null -cne $row -and [bool](Get-Value $row @('enabled') $false)) {
            $null = Invoke-RoomActionRow -Row $row -Intent "take Bishop's visible Job Board work"
            Wait-Frames -Frames 10
            return $choiceId
        }
    }
    throw "The visible Job Board offered no Bishop work while his Inner Circle route remained locked."
}


function Promote-BishopToInnerCircle {
    # Recruitment starts Bishop at Associate (30). Five successful Camera
    # Windows reach Made (60) without relying on any private trust readout.
    for ($job = 1; $job -le 5; $job++) {
        $accepted = Start-BishopContactJob -Preference @('job_bishop_camera_window')
        Complete-PublicDelivery -Intent "complete Bishop Camera Window $job"
    }
    if (-not (Enter-PunchlineBackRoom -AllowUnavailable)) {
        throw 'Five successful public Camera Window jobs did not unlock the Made-standing Punchline back room.'
    }

    for ($job = 1; $job -le 7; $job++) {
        if (Test-CountPlanLive) { return }
        $accepted = Start-BishopBoardJob
        $grandRoom = if ($accepted -ceq 'accept_bishop_cage_packet') { 'cage' } else { '' }
        Complete-PublicDelivery -Intent "complete Bishop back-room job $job ($accepted)" -GrandRoom $grandRoom
        $null = Enter-PunchlineBackRoom
    }
    if (-not (Test-CountPlanLive)) {
        throw "Bishop's public work did not make The Count visibly live within the bounded Associate-to-Inner-Circle route."
    }
}


function Leave-GrandForDistinctVisit {
    Leave-GameSurface
    if ([string](Get-Value $script:LastObservation @('environment', 'world_node_id') '') -cne 'grand_casino') { return }
    Open-WorldMap
    $candidate = @(Get-MapNodes | Where-Object {
        [bool](Get-Value $_ @('travel_enabled') $false) -and
        [string](Get-Value $_ @('id') '') -cne 'grand_casino' -and
        [string](Get-Value $_ @('archetype_id') '') -cnotin @('grand_casino', 'grand_casino_cage', 'grand_casino_high_limit')
    } | Sort-Object @{ Expression = { [int](Get-Value $_ @('cost') 0) } }, @{ Expression = { [string](Get-Value $_ @('id') '') } } | Select-Object -First 1)
    if ($candidate.Count -ceq 0) {
        Close-WorldMap
        throw 'The Grand Casino exposes no public map leg for a distinct identity visit.'
    }
    $nodeId = [string](Get-Value $candidate[0] @('id') '')
    Travel-ToNode -NodeId $nodeId -Intent 'leave the Grand Casino between distinct identity sessions'
}


function Complete-CountIdentitySessions {
    Reach-GrandCasino
    # The release Count route requires one ordinary identity hand. Keep the
    # replay aligned with that public requirement instead of retaining the old
    # three-session / 125-chip grind from the broader deferred route.
    Ensure-GrandCasinoChips -Minimum 8
    Enter-GrandRoom -Room main
    for ($session = 1; $session -le 1; $session++) {
        if ([int](Get-Value $script:LastObservation @('status_hud', 'heat_level') 0) -gt 35) {
            throw "The Count identity route exceeded its public heat ceiling before session $session."
        }
        Play-OneBlackjackRound -UseHeistStake
        Leave-GameSurface
        if ($session -lt 1) {
            Leave-GrandForDistinctVisit
            Reach-GrandCasino
            Enter-GrandRoom -Room main
        }
    }
}


function Get-PlanningTableProjection {
    Select-EventObject -EventId 'crew_planning_table'
    $rows = @()
    $roomActions = Get-ExactReplayObjectArray `
        -InputObject $script:LastResult `
        -Path @('look', 'clickable', 'room_actions') `
        -ElementType PSCustomObject `
        -Context 'Heist planning-table room actions'
    foreach ($row in $roomActions) {
        $emitId = Get-ExactReplayString -InputObject $row -Path @('emit_object_id') -Context 'Heist planning-table emitted action id'
        if (-not $emitId.StartsWith('event_response:crew_planning_table:', [StringComparison]::Ordinal)) { continue }
        $choiceId = $emitId.Substring('event_response:crew_planning_table:'.Length)
        if ([string]::IsNullOrWhiteSpace($choiceId)) {
            throw "Planning row '$emitId' has no exact choice-id suffix."
        }
        $label = Get-ExactReplayString -InputObject $row -Path @('label') -Context "Planning row '$emitId' label"
        $enabled = Get-ExactReplayBoolean -InputObject $row -Path @('enabled') -Context "Planning row '$emitId' enabled witness"
        $rendered = Get-ExactReplayBoolean -InputObject $row -Path @('rendered') -Context "Planning row '$emitId' rendered witness"
        $disabledReason = Get-ExactReplayString -InputObject $row -Path @('disabled_reason') -Context "Planning row '$emitId' disabled reason"
        $rows += [pscustomobject][ordered]@{
            choice_id = $choiceId
            label = $label
            enabled = $enabled
            rendered = $rendered
            disabled_reason = $disabledReason
        }
    }
    if ($rows.Count -ceq 0) {
        throw 'The planning table exposes no public room-action rows with rendered witnesses.'
    }
    $choiceIds = [string[]]@($rows | ForEach-Object { $_.choice_id })
    $uniqueChoiceIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($choiceId in $choiceIds) {
        if (-not $uniqueChoiceIds.Add($choiceId)) {
            throw "The planning table exposes duplicate exact choice id '$choiceId'."
        }
    }
    [Array]::Sort($choiceIds, [StringComparer]::Ordinal)
    $sortedRows = @(
        foreach ($choiceId in $choiceIds) {
            @($rows | Where-Object { $_.choice_id -ceq $choiceId })[0]
        }
    )
    $countLocks = @($sortedRows | Where-Object {
        $_.choice_id -ceq 'lock_the_count' -and $_.enabled -and $_.rendered
    })
    if ($countLocks.Count -cne 1) {
        throw 'The planning table must expose exactly one rendered and enabled Count lock.'
    }
    return $sortedRows
}


function Assert-HeistAuditKnowledgeSaveRelaunchContinue {
    $beforeProjection = @(Get-PlanningTableProjection)
    $beforeLockRows = @($beforeProjection | Where-Object { [string]$_.choice_id -ceq 'lock_the_count' })
    if ($beforeLockRows.Count -cne 1 -or
        $beforeLockRows[0].enabled -isnot [bool] -or -not [bool]$beforeLockRows[0].enabled -or
        $beforeLockRows[0].rendered -isnot [bool] -or -not [bool]$beforeLockRows[0].rendered) {
        throw 'The pre-save planning table did not expose exactly one rendered and enabled Count lock under learned Audit knowledge.'
    }
    $before = [ordered]@{
        checkpoint = Get-PersistenceCheckpoint
        planning_choices = $beforeProjection
    }
    $beforeJson = $before | ConvertTo-Json -Depth 20 -Compress
    Close-VisibleChoiceSurface
    $null = Click-Button -Text 'Menu' -Intent 'open the run menu after proving learned Audit knowledge on the hostile revisit'
    $null = Click-RunMenuButton -Text 'Save' -RevealDirection up -Intent 'save the naturally learned Count route before locking the plan'
    Assert-ExplicitSaveAcknowledged -Milestone 'The Count learned Audit route before plan lock'
    $null = Click-RunMenuButton -Text 'Main Menu' -RevealDirection down -Intent 'return to the main menu after saving the learned Count route'
    if ([string](Get-Value $script:LastObservation @('screen', 'screen') '') -cne 'START') {
        throw 'Main Menu did not visibly return the learned Count checkpoint to START before relaunch.'
    }
    $null = Invoke-BridgeCommand -Command 'quit' -Intent 'quit the saved learned-Audit host before relaunch' -ObservationOnly
    Wait-ForSessionExit
    Assert-NoPostExitLogAlerts
    Remove-OwnedBridgeCaptureResidue
    Start-BridgeSession
    if ([string](Get-Value $script:LastObservation @('screen', 'start_menu', 'primary_action_text') '') -cne 'CONTINUE') {
        throw 'Relaunch after the learned Count checkpoint did not expose CONTINUE.'
    }
    $null = Click-Button -Text 'CONTINUE' -Intent 'continue the naturally learned Count route from the full relaunch checkpoint'
    Wait-Frames -Frames 45
    Clear-VisibleCoach
    if ($null -ceq (Find-CanvasObject -SemanticId 'event:crew_planning_table')) {
        throw 'Continue did not restore the real Punchline planning-table room.'
    }
    $afterProjection = @(Get-PlanningTableProjection)
    $afterLockRows = @($afterProjection | Where-Object { [string]$_.choice_id -ceq 'lock_the_count' })
    if ($afterLockRows.Count -cne 1 -or
        $afterLockRows[0].enabled -isnot [bool] -or -not [bool]$afterLockRows[0].enabled -or
        $afterLockRows[0].rendered -isnot [bool] -or -not [bool]$afterLockRows[0].rendered) {
        throw 'Continue did not preserve exactly one rendered and enabled Count lock under learned Audit knowledge.'
    }
    $after = [ordered]@{
        checkpoint = Get-PersistenceCheckpoint
        planning_choices = $afterProjection
    }
    $afterJson = $after | ConvertTo-Json -Depth 20 -Compress
    $before | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $script:RunRoot 'checkpoint_before.json') -Encoding utf8
    $after | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $script:RunRoot 'checkpoint_after.json') -Encoding utf8
    if ($afterJson -cne $beforeJson) {
        throw 'Public learned-Audit planning state changed across Save -> relaunch -> Continue.'
    }
    Close-VisibleChoiceSurface
    $script:MidpointSaved = $true
}


function Invoke-HeistEndingRoute {
    Establish-CrewMarker
    Reach-GrandCasino
    Restore-EnvironmentSurfaceAfterTravelResult
    Observe-RenderedAuditNightHook
    Clear-CrewMarkerFavors
    Ensure-PunchlineCasinoDiscovered
    Recruit-Bishop
    $null = Enter-PunchlineBackRoom
    if (-not $ConfirmationOnly) {
        Assert-HeistAuditKnowledgeSaveRelaunchContinue
    }

    if (-not (Test-CountPlanLive)) {
        throw 'The Count is not visibly live after Bishop reaches Associate and the Audit route is learned.'
    }
    Invoke-EventObjectChoice -EventId 'crew_planning_table' -ChoiceId 'lock_the_count' -Intent 'lock Bishop''s visible Count plan at the real planning table'
    Close-VisibleChoiceSurface

    Complete-CountIdentitySessions
    $null = Enter-PunchlineBackRoom
    Invoke-EventObjectChoice -EventId 'crew_planning_table' -ChoiceId 'count_schedule' -Intent 'start the visible Cage schedule watch'
    Close-VisibleChoiceSurface
    Complete-PublicDelivery -Intent 'complete The Count schedule hold at the Cage' -GrandRoom cage

    $null = Enter-PunchlineBackRoom
    Invoke-EventObjectChoice -EventId 'crew_planning_table' -ChoiceId 'count_cart' -Intent 'start the visible swap-cart route'
    Close-VisibleChoiceSurface
    Complete-PublicDelivery -Intent 'move The Count swap cart to Grand Casino Main' -GrandRoom main

    $null = Enter-PunchlineBackRoom
    if (-not (Test-EventObjectChoiceEnabled -EventId 'crew_planning_table' -ChoiceId 'begin_play')) {
        throw 'All public Count setup beats completed, but Begin the Play remains disabled.'
    }
    Close-VisibleChoiceSurface
    Invoke-EventObjectChoice -EventId 'crew_planning_table' -ChoiceId 'begin_play' -Intent 'begin The Count from the visible completed setup'
    Close-VisibleChoiceSurface

    Reach-GrandCasino
    Enter-GrandRoom -Room main
    $decisions = @('go_hold', 'distraction_sit', 'exit_dock')
    for ($round = 0; $round -lt $decisions.Count; $round++) {
        $choiceId = $decisions[$round]
        if ($null -ceq (Find-CanvasObject -SemanticId 'event:heist_live_table')) {
            throw "The Count live-table event is missing before round $($round + 1)."
        }
        Invoke-EventObjectChoice -EventId 'heist_live_table' -ChoiceId $choiceId -Intent "take the visible Count decision $choiceId before live round $($round + 1)"
        Close-VisibleChoiceSurface
        Play-OneBlackjackRound -UseHeistStake
        Leave-GameSurface
    }
    Invoke-EventObjectChoice -EventId 'heist_live_table' -ChoiceId 'begin_getaway' -Intent 'take the visible dock exit after all three Count rounds'
    Close-VisibleChoiceSurface
    Complete-PublicDelivery -Intent 'complete The Count dock getaway to its marked destination'
    Wait-Frames -Frames 30
    $null = Assert-TerminalOutcome
}


function Invoke-SelectedEndingRoute {
    switch ($Ending) {
        'clean' { Invoke-CleanEndingRoute }
        'cheat' { Invoke-CheatEndingRoute }
        'heist' { Invoke-HeistEndingRoute }
        default { throw "Unsupported ending '$Ending'." }
    }
}


function Invoke-BridgeTransportRegression {
    $invocationStamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
    $nonce = [Guid]::NewGuid().ToString('N').Substring(0, 10)
    $script:Session = "rw062-bridge-$PID-$nonce"
    $script:SessionRoot = New-AnchoredSessionRoot -Session $script:Session
    $script:RunRoot = Join-Path $EvidenceRoot "bridge-$invocationStamp-$PID"
    [void](New-Item -ItemType Directory -Path $script:RunRoot -Force)
    $script:TranscriptPath = Join-Path $script:RunRoot 'public_trace.ndjson'
    $script:MoneyCurvePath = Join-Path $script:RunRoot 'money_curve.ndjson'
    $script:LastResult = $null
    $script:LastObservation = $null
    $script:ActionCount = 0
    $script:TraceOrdinal = 0
    $script:LastMoneySignature = ''
    $script:MidpointSaved = $false
    $script:OwnedSessionPid = 0
    $script:OwnedSessionStartUtcTicks = 0L
    $script:OwnedSessionExecutablePath = ''

    $lookResult = $null
    $waitResult = $null
    $quitResult = $null
    $relaunchLookResult = $null
    $relaunchQuitResult = $null
    $status = $null
    $firstOwnedPid = 0
    $firstOwnedStartUtcTicks = 0L
    $secondOwnedPid = 0
    $secondOwnedStartUtcTicks = 0L
    $failure = $null
    try {
        Start-BridgeSession
        $lookResult = $script:LastResult
        if ([string](Get-Value $lookResult @('command') '') -cne 'look') {
            throw 'Bridge transport regression did not receive its initial look result.'
        }
        $waitResult = Invoke-BridgeCommand -Command 'wait 1' -Intent 'exercise a second atomically published command' -ObservationOnly
        $quitResult = Invoke-BridgeCommand -Command 'quit' -Intent 'close the bridge transport regression host' -ObservationOnly
        $firstOwnedPid = $script:OwnedSessionPid
        $firstOwnedStartUtcTicks = $script:OwnedSessionStartUtcTicks
        Wait-ForSessionExit
        Assert-NoPostExitLogAlerts
        Remove-OwnedBridgeCaptureResidue
        if (Get-ExactOwnedSessionProcess) {
            throw 'Bridge transport regression retained its first exact owned Godot process after quit.'
        }

        # Recreate a hostile stale cursor, then relaunch the same session. Start
        # must atomically reset it before any command is allowed to inspect the
        # newly truncated process logs.
        $firstStatus = Get-SessionStatus
        $sessionFolder = [string](Get-Value $firstStatus @('folder') '')
        if ([string]::IsNullOrWhiteSpace($sessionFolder) -or -not (Test-Path -LiteralPath $sessionFolder -PathType Container)) {
            throw 'Bridge transport regression could not resolve its session evidence folder.'
        }
        $logCursorPath = Join-Path $sessionFolder 'log_cursor.json'
        @{ stdout = 999999; stderr = 999999 } | ConvertTo-Json | Set-Content -LiteralPath $logCursorPath -Encoding utf8
        Start-BridgeSession -SkipInitialLook
        $secondOwnedPid = $script:OwnedSessionPid
        $secondOwnedStartUtcTicks = $script:OwnedSessionStartUtcTicks
        $resetCursor = Get-Content -Raw -LiteralPath $logCursorPath -Encoding utf8 | ConvertFrom-Json
        if ([int]$resetCursor.stdout -cne 0 -or [int]$resetCursor.stderr -cne 0) {
            throw 'Same-session relaunch did not reset the new process log cursor before its first command.'
        }
        $relaunchLookResult = Invoke-BridgeCommand -Command 'look' -Intent 'exercise the same-session relaunch after atomic log-cursor reset' -ObservationOnly
        $relaunchQuitResult = Invoke-BridgeCommand -Command 'quit' -Intent 'close the relaunched bridge transport host' -ObservationOnly
        Wait-ForSessionExit
        Assert-NoPostExitLogAlerts
        Remove-OwnedBridgeCaptureResidue
        $status = Get-SessionStatus
        if ([bool](Get-Value $status @('running') $true)) {
            throw 'Bridge transport regression left its Godot session running.'
        }
        if (Get-ExactOwnedSessionProcess) {
            throw 'Bridge transport regression retained its relaunched exact owned Godot process after quit.'
        }
        Remove-OwnedBridgeCaptureResidue
        $sessionTempResidue = @(Get-ChildItem -LiteralPath $sessionFolder -Recurse -File -Filter '*.tmp' -ErrorAction SilentlyContinue)
        $bridgeTempResidue = @(Get-ChildItem -LiteralPath $BridgeCallRoot -File -Filter '*.tmp' -ErrorAction SilentlyContinue)
        if ($sessionTempResidue.Count -gt 0 -or $bridgeTempResidue.Count -gt 0) {
            throw 'Bridge transport regression left temporary command or capture files behind.'
        }
    }
    catch {
        $failure = $_
    }
    finally {
        if ($null -cne $failure) {
            Stop-BridgeSessionSafely -BestEffort
        }
    }

    $summary = [ordered]@{
        schema_version = 1
        check_id = 'rw06_2_bridge_transport_contract'
        passed = ($null -ceq $failure)
        session = $script:Session
        evidence_root = $script:RunRoot
        session_folder = [string](Get-Value $status @('folder') '')
        owned_processes = @(
            [ordered]@{ pid = $firstOwnedPid; start_utc_ticks = $firstOwnedStartUtcTicks; residue = $false }
            [ordered]@{ pid = $secondOwnedPid; start_utc_ticks = $secondOwnedStartUtcTicks; residue = $false }
        )
        commands = @(
            [ordered]@{ command = [string](Get-Value $lookResult @('command') ''); accepted = [bool](Get-Value $lookResult @('accepted') $false) }
            [ordered]@{ command = [string](Get-Value $waitResult @('command') ''); accepted = [bool](Get-Value $waitResult @('accepted') $false) }
            [ordered]@{ command = [string](Get-Value $quitResult @('command') ''); accepted = [bool](Get-Value $quitResult @('accepted') $false) }
            [ordered]@{ command = [string](Get-Value $relaunchLookResult @('command') ''); accepted = [bool](Get-Value $relaunchLookResult @('accepted') $false) }
            [ordered]@{ command = [string](Get-Value $relaunchQuitResult @('command') ''); accepted = [bool](Get-Value $relaunchQuitResult @('accepted') $false) }
        )
        failure = if ($null -ceq $failure) { '' } else { [string]$failure.Exception.Message }
    }
    $summaryPath = Join-Path $script:RunRoot 'summary.json'
    $summary | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $summaryPath -Encoding utf8
    if ($null -cne $failure) {
        throw $failure
    }
    return [pscustomobject]$summary
}


function Invoke-BridgeStatusRegression {
    $invocationStamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
    $nonce = [Guid]::NewGuid().ToString('N').Substring(0, 10)
    $script:Session = "rw062-status-$PID-$nonce"
    # Prove commands remain anchored to the exact supplied folder even when its
    # date segment differs from today's wall clock.
    $script:SessionRoot = New-AnchoredSessionRoot -Session $script:Session -DateSegment '1999-12-31'
    $script:OwnedSessionPid = 0
    $script:OwnedSessionStartUtcTicks = 0L
    $script:OwnedSessionExecutablePath = ''
    $statusRoot = Join-Path $EvidenceRoot "status-$invocationStamp-$PID"
    [void](New-Item -ItemType Directory -Path $statusRoot -Force)
    $status = Get-SessionStatus
    if ([bool](Get-Value $status @('running') $true)) {
        throw 'No-Godot bridge status regression unexpectedly found a running session.'
    }
    if ([string](Get-Value $status @('session') '') -cne $script:Session) {
        throw 'No-Godot bridge status regression returned the wrong session id.'
    }
    if (-not ([IO.Path]::GetFullPath([string](Get-Value $status @('folder') ''))).Equals($script:SessionRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'No-Godot bridge status regression did not preserve its cross-date absolute session root.'
    }
    Remove-OwnedBridgeCaptureResidue
    $bridgeTempResidue = @(Get-ChildItem -LiteralPath $BridgeCallRoot -File -Filter '*.tmp' -ErrorAction SilentlyContinue)
    if ($bridgeTempResidue.Count -gt 0) {
        throw 'No-Godot bridge status regression left capture files behind.'
    }
    $summary = [ordered]@{
        schema_version = 1
        check_id = 'rw06_2_bridge_status_contract'
        passed = $true
        session = $script:Session
        running = $false
        session_folder = [string](Get-Value $status @('folder') '')
        evidence_root = $statusRoot
    }
    $summary | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $statusRoot 'summary.json') -Encoding utf8
    return [pscustomobject]$summary
}


function Invoke-SemanticScrollRegression {
    $failures = [Collections.Generic.List[string]]::new()
    $validButton = [pscustomobject][ordered]@{
        id = '/root/RunMenu/SkipLessons'
        text = 'Skip Lessons'
        enabled = $true
        fully_visible = $true
    }
    try {
        $selectedButton = Select-UniqueFullyVisibleButton -Buttons @($validButton) -Text 'Skip Lessons'
        if ([string](Get-Value $selectedButton @('id') '') -cne '/root/RunMenu/SkipLessons') {
            $failures.Add('Valid fully visible public button selection returned the wrong button.')
        }
    }
    catch {
        $failures.Add("Valid fully visible public button selection threw: $($_.Exception.Message)")
    }

    $buttonHostileFixtures = @(
        [pscustomobject]@{ label = 'target-missing'; buttons = @(); expect_throw = $false },
        [pscustomobject]@{ label = 'fully-visible-false'; buttons = @([pscustomobject]@{ id = '/root/partial'; text = 'Skip Lessons'; enabled = $true; fully_visible = $false }); expect_throw = $false },
        [pscustomobject]@{ label = 'fully-visible-absent'; buttons = @([pscustomobject]@{ id = '/root/absent'; text = 'Skip Lessons'; enabled = $true }); expect_throw = $true },
        [pscustomobject]@{ label = 'fully-visible-non-boolean'; buttons = @([pscustomobject]@{ id = '/root/nonbool'; text = 'Skip Lessons'; enabled = $true; fully_visible = 'true' }); expect_throw = $true },
        [pscustomobject]@{ label = 'fully-visible-property-case'; buttons = @([pscustomobject]@{ id = '/root/case'; text = 'Skip Lessons'; enabled = $true; Fully_Visible = $true }); expect_throw = $true },
        [pscustomobject]@{ label = 'ambiguous-buttons'; buttons = @($validButton, $validButton); expect_throw = $true }
    )
    foreach ($fixture in $buttonHostileFixtures) {
        $selected = $null
        $threw = $false
        try {
            $selected = Select-UniqueFullyVisibleButton -Buttons @($fixture.buttons) -Text 'Skip Lessons'
        }
        catch {
            $threw = $true
        }
        if ([bool]$fixture.expect_throw -cne $threw -or (-not $threw -and $null -cne $selected)) {
            $failures.Add("Hostile fully-visible fixture '$($fixture.label)' did not fail closed.")
        }
    }

    $validDialogOk = [pscustomobject][ordered]@{
        id = 'tutorial_skip_dialog:ok'
        text = 'OK'
        enabled = $true
        fully_visible = $true
        surface_id = 'tutorial_skip_dialog'
        dialog_role = 'ok'
        dialog_rendered = $true
    }
    $validDialogCancel = [pscustomobject][ordered]@{
        id = 'tutorial_skip_dialog:cancel'
        text = 'Cancel'
        enabled = $true
        fully_visible = $true
        surface_id = 'tutorial_skip_dialog'
        dialog_role = 'cancel'
        dialog_rendered = $true
    }
    foreach ($validDialogFixture in @(
        [pscustomobject]@{ role = 'ok'; expected_id = 'tutorial_skip_dialog:ok'; buttons = @($validDialogOk, $validDialogCancel) },
        [pscustomobject]@{ role = 'cancel'; expected_id = 'tutorial_skip_dialog:cancel'; buttons = @($validDialogOk, $validDialogCancel) }
    )) {
        try {
            $selectedDialogButton = Select-UniquePublicTutorialDialogButton `
                -Buttons @($validDialogFixture.buttons) `
                -Role ([string]$validDialogFixture.role)
            if ([string](Get-Value $selectedDialogButton @('id') '') -cne [string]$validDialogFixture.expected_id) {
                $failures.Add("Valid tutorial confirmation '$($validDialogFixture.role)' selection returned the wrong stable id.")
            }
        }
        catch {
            $failures.Add("Valid tutorial confirmation '$($validDialogFixture.role)' selection threw: $($_.Exception.Message)")
        }
    }

    $dialogHostileFixtures = @(
        [pscustomobject]@{ label = 'hidden-dialog'; role = 'ok'; buttons = @([pscustomobject]@{ id = 'tutorial_skip_dialog:ok'; text = 'OK'; enabled = $true; fully_visible = $true; surface_id = 'tutorial_skip_dialog'; dialog_role = 'ok'; dialog_rendered = $false }) },
        [pscustomobject]@{ label = 'disabled-button'; role = 'ok'; buttons = @([pscustomobject]@{ id = 'tutorial_skip_dialog:ok'; text = 'OK'; enabled = $false; fully_visible = $true; surface_id = 'tutorial_skip_dialog'; dialog_role = 'ok'; dialog_rendered = $true }) },
        [pscustomobject]@{ label = 'clipped-button'; role = 'ok'; buttons = @([pscustomobject]@{ id = 'tutorial_skip_dialog:ok'; text = 'OK'; enabled = $true; fully_visible = $false; surface_id = 'tutorial_skip_dialog'; dialog_role = 'ok'; dialog_rendered = $true }) },
        [pscustomobject]@{ label = 'ambiguous-dialog'; role = 'ok'; buttons = @($validDialogOk, $validDialogOk) },
        [pscustomobject]@{ label = 'wrong-stable-id'; role = 'ok'; buttons = @([pscustomobject]@{ id = '/root/internal/ok'; text = 'OK'; enabled = $true; fully_visible = $true; surface_id = 'tutorial_skip_dialog'; dialog_role = 'ok'; dialog_rendered = $true }) },
        [pscustomobject]@{ label = 'missing-rendered-signal'; role = 'ok'; buttons = @([pscustomobject]@{ id = 'tutorial_skip_dialog:ok'; text = 'OK'; enabled = $true; fully_visible = $true; surface_id = 'tutorial_skip_dialog'; dialog_role = 'ok' }) },
        [pscustomobject]@{ label = 'non-boolean-enabled-signal'; role = 'ok'; buttons = @([pscustomobject]@{ id = 'tutorial_skip_dialog:ok'; text = 'OK'; enabled = 'true'; fully_visible = $true; surface_id = 'tutorial_skip_dialog'; dialog_role = 'ok'; dialog_rendered = $true }) },
        [pscustomobject]@{ label = 'rendered-property-case'; role = 'ok'; buttons = @([pscustomobject]@{ id = 'tutorial_skip_dialog:ok'; text = 'OK'; enabled = $true; fully_visible = $true; surface_id = 'tutorial_skip_dialog'; dialog_role = 'ok'; Dialog_Rendered = $true }) }
    )
    foreach ($fixture in $dialogHostileFixtures) {
        $threw = $false
        try {
            $null = Select-UniquePublicTutorialDialogButton `
                -Buttons @($fixture.buttons) `
                -Role ([string]$fixture.role)
        }
        catch {
            $threw = $true
        }
        if (-not $threw) {
            $failures.Add("Hostile tutorial-confirmation fixture '$($fixture.label)' did not fail closed.")
        }
    }

    $validDown = [pscustomobject][ordered]@{
        id = 'run_menu'
        axis = 'vertical'
        rendered = $true
        can_scroll_up = $false
        can_scroll_down = $true
    }
    $validUp = [pscustomobject][ordered]@{
        id = 'run_menu'
        axis = 'vertical'
        rendered = $true
        can_scroll_up = $true
        can_scroll_down = $false
    }
    try {
        $selectedDown = Select-UniquePublicVerticalScrollSurface -Surfaces @($validDown) -SurfaceId 'run_menu' -Direction down
        if ([string](Get-Value $selectedDown @('id') '') -cne 'run_menu') {
            $failures.Add('Valid downward public scroll selection returned the wrong surface.')
        }
        $selectedUp = Select-UniquePublicVerticalScrollSurface -Surfaces @($validUp) -SurfaceId 'run_menu' -Direction up
        if ([string](Get-Value $selectedUp @('id') '') -cne 'run_menu') {
            $failures.Add('Valid upward public scroll selection returned the wrong surface.')
        }
    }
    catch {
        $failures.Add("Valid public scroll selection threw: $($_.Exception.Message)")
    }

    $hostileFixtures = @(
        [pscustomobject]@{ label = 'missing'; surfaces = @(); surface_id = 'run_menu'; direction = 'down' },
        [pscustomobject]@{ label = 'duplicate'; surfaces = @($validDown, $validDown); surface_id = 'run_menu'; direction = 'down' },
        [pscustomobject]@{ label = 'unsupported-id'; surfaces = @($validDown); surface_id = 'journal'; direction = 'down' },
        [pscustomobject]@{ label = 'not-rendered'; surfaces = @([pscustomobject]@{ id = 'run_menu'; axis = 'vertical'; rendered = $false; can_scroll_down = $true }); surface_id = 'run_menu'; direction = 'down' },
        [pscustomobject]@{ label = 'rendered-non-boolean'; surfaces = @([pscustomobject]@{ id = 'run_menu'; axis = 'vertical'; rendered = 'true'; can_scroll_down = $true }); surface_id = 'run_menu'; direction = 'down' },
        [pscustomobject]@{ label = 'wrong-axis'; surfaces = @([pscustomobject]@{ id = 'run_menu'; axis = 'horizontal'; rendered = $true; can_scroll_down = $true }); surface_id = 'run_menu'; direction = 'down' },
        [pscustomobject]@{ label = 'blocked-direction'; surfaces = @($validUp); surface_id = 'run_menu'; direction = 'down' },
        [pscustomobject]@{ label = 'direction-non-boolean'; surfaces = @([pscustomobject]@{ id = 'run_menu'; axis = 'vertical'; rendered = $true; can_scroll_down = 'true' }); surface_id = 'run_menu'; direction = 'down' },
        [pscustomobject]@{ label = 'direction-property-case'; surfaces = @([pscustomobject]@{ id = 'run_menu'; axis = 'vertical'; rendered = $true; Can_Scroll_Down = $true }); surface_id = 'run_menu'; direction = 'down' },
        [pscustomobject]@{ label = 'blank-public-id'; surfaces = @([pscustomobject]@{ id = ''; axis = 'vertical'; rendered = $true; can_scroll_down = $true }); surface_id = 'run_menu'; direction = 'down' }
    )
    foreach ($fixture in $hostileFixtures) {
        $threw = $false
        try {
            $null = Select-UniquePublicVerticalScrollSurface `
                -Surfaces @($fixture.surfaces) `
                -SurfaceId ([string]$fixture.surface_id) `
                -Direction ([string]$fixture.direction)
        }
        catch {
            $threw = $true
        }
        if (-not $threw) {
            $failures.Add("Hostile semantic-scroll fixture '$($fixture.label)' did not fail closed.")
        }
    }

    $validConfirmationObservation = [pscustomobject]@{
        event_popup = [pscustomobject]@{ visible = $false }
        talk = [pscustomobject]@{ visible = $true; render_valid = $true; event_id = 'lender_conversation:borrow:the_crew' }
    }
    $validConfirmationChoices = @(
        [pscustomobject]@{ id = 'accept'; label = 'Confirm: Accept Offer'; enabled = $true },
        [pscustomobject]@{ id = 'decline'; label = 'Not Now'; enabled = $true }
    )
    try {
        $null = Assert-VisibleTalkChoiceConfirmation -Observation $validConfirmationObservation -RenderedTalkChoices $validConfirmationChoices -ChoiceId 'accept' -ExpectedEventId 'lender_conversation:borrow:the_crew' -OriginalLabel 'Accept Offer'
    }
    catch {
        $failures.Add("Valid TalkDock confirmation fixture threw: $($_.Exception.Message)")
    }
    $confirmationHostileFixtures = @(
        [pscustomobject]@{
            label = 'same-choice-id-chained-event-modal'
            observation = [pscustomobject]@{ event_popup = [pscustomobject]@{ visible = $true }; talk = [pscustomobject]@{ visible = $false; render_valid = $true; event_id = 'lender_conversation:borrow:the_crew' } }
            choices = $validConfirmationChoices
        },
        [pscustomobject]@{
            label = 'changed-talk-event-id'
            observation = [pscustomobject]@{ event_popup = [pscustomobject]@{ visible = $false }; talk = [pscustomobject]@{ visible = $true; render_valid = $true; event_id = 'lender_conversation:borrow:brother_in_law' } }
            choices = $validConfirmationChoices
        },
        [pscustomobject]@{
            label = 'talk-visible-non-boolean'
            observation = [pscustomobject]@{ event_popup = [pscustomobject]@{ visible = $false }; talk = [pscustomobject]@{ visible = 'true'; render_valid = $true; event_id = 'lender_conversation:borrow:the_crew' } }
            choices = $validConfirmationChoices
        },
        [pscustomobject]@{
            label = 'confirmation-label-case'
            observation = $validConfirmationObservation
            choices = @([pscustomobject]@{ id = 'accept'; label = 'Confirm: accept offer'; enabled = $true }, $validConfirmationChoices[1])
        },
        [pscustomobject]@{
            label = 'confirmation-property-case'
            observation = $validConfirmationObservation
            choices = @([pscustomobject]@{ Id = 'accept'; label = 'Confirm: Accept Offer'; enabled = $true }, $validConfirmationChoices[1])
        }
    )
    foreach ($fixture in $confirmationHostileFixtures) {
        $threw = $false
        try {
            $null = Assert-VisibleTalkChoiceConfirmation -Observation $fixture.observation -RenderedTalkChoices @($fixture.choices) -ChoiceId 'accept' -ExpectedEventId 'lender_conversation:borrow:the_crew' -OriginalLabel 'Accept Offer'
        }
        catch {
            $threw = $true
        }
        if (-not $threw) {
            $failures.Add("Hostile TalkDock confirmation fixture '$($fixture.label)' did not fail closed.")
        }
    }

    $validCanvasObject = [pscustomobject]@{
        semantic_id = 'event:back_alley_offer'
        enabled = $true
        rendered = $true
    }
    try {
        $selectedCanvasObject = Select-ExactRenderedCanvasObject -Objects @($validCanvasObject) -SemanticId 'event:back_alley_offer'
        if ($null -ceq $selectedCanvasObject) {
            $failures.Add('Valid exact rendered canvas object was rejected.')
        }
        $prefixObjects = @(
            [pscustomobject]@{ semantic_id = 'lender:the_crew'; enabled = $true; rendered = $true },
            [pscustomobject]@{ semantic_id = 'lender:street_lender'; enabled = $true; rendered = $true }
        )
        $selectedPrefixObject = Select-FirstRenderedCanvasObjectByPrefix -Objects $prefixObjects -Prefix 'lender:'
        if ([string](Get-Value $selectedPrefixObject @('semantic_id') '') -cne 'lender:street_lender') {
            $failures.Add('Valid rendered canvas prefix selection did not use exact ordinal identity.')
        }
    }
    catch {
        $failures.Add("Valid rendered canvas object fixture threw: $($_.Exception.Message)")
    }
    $canvasObjectHostileFixtures = @(
        [pscustomobject]@{ label = 'exact-clipped'; mode = 'exact'; objects = @([pscustomobject]@{ semantic_id = 'event:back_alley_offer'; enabled = $true; rendered = $false }); expect_null = $true },
        [pscustomobject]@{ label = 'exact-rendered-missing'; mode = 'exact'; objects = @([pscustomobject]@{ semantic_id = 'event:back_alley_offer'; enabled = $true }); expect_null = $false },
        [pscustomobject]@{ label = 'exact-enabled-string'; mode = 'exact'; objects = @([pscustomobject]@{ semantic_id = 'event:back_alley_offer'; enabled = 'true'; rendered = $true }); expect_null = $false },
        [pscustomobject]@{ label = 'exact-duplicate'; mode = 'exact'; objects = @($validCanvasObject, $validCanvasObject); expect_null = $false },
        [pscustomobject]@{ label = 'prefix-rendered-string'; mode = 'prefix'; objects = @([pscustomobject]@{ semantic_id = 'lender:the_crew'; enabled = $true; rendered = 'true' }); expect_null = $false },
        [pscustomobject]@{ label = 'prefix-duplicate'; mode = 'prefix'; objects = @([pscustomobject]@{ semantic_id = 'lender:the_crew'; enabled = $true; rendered = $true }, [pscustomobject]@{ semantic_id = 'lender:the_crew'; enabled = $true; rendered = $true }); expect_null = $false }
    )
    foreach ($fixture in $canvasObjectHostileFixtures) {
        $threw = $false
        $selected = $null
        try {
            $selected = if ([string]$fixture.mode -ceq 'exact') {
                Select-ExactRenderedCanvasObject -Objects @($fixture.objects) -SemanticId 'event:back_alley_offer'
            }
            else {
                Select-FirstRenderedCanvasObjectByPrefix -Objects @($fixture.objects) -Prefix 'lender:'
            }
        }
        catch {
            $threw = $true
        }
        $expectedNull = [bool]$fixture.expect_null
        if (($expectedNull -and ($threw -or $null -cne $selected)) -or (-not $expectedNull -and -not $threw)) {
            $failures.Add("Hostile canvas-object fixture '$($fixture.label)' did not fail closed.")
        }
    }

    function New-RoomActionRegressionRow {
        return [pscustomobject][ordered]@{
            id = ''
            action = ''
            action_id = ''
            emit_object_id = 'event_response:back_alley_offer:take_cash'
            label = 'Take the cash'
            selected_object_id = 'event:back_alley_offer'
            index = 0
            enabled = $true
            rendered = $true
        }
    }
    try {
        $null = Assert-ExactRenderedRoomActionBinding `
            -Rows @((New-RoomActionRegressionRow)) `
            -SelectedObjectId 'event:back_alley_offer' `
            -Index 0 `
            -IdentityKey 'emit_object_id' `
            -IdentityValue 'event_response:back_alley_offer:take_cash'
    }
    catch {
        $failures.Add("Valid exact room-action binding threw: $($_.Exception.Message)")
    }
    $roomActionHostileFixtures = @(
        [pscustomobject]@{ label = 'duplicate'; mutate = { param($row) @($row, (New-RoomActionRegressionRow)) } },
        [pscustomobject]@{ label = 'reordered'; mutate = { param($row) $row.index = 1; @($row) } },
        [pscustomobject]@{ label = 'clipped'; mutate = { param($row) $row.rendered = $false; @($row) } },
        [pscustomobject]@{ label = 'stale-selection'; mutate = { param($row) $row.selected_object_id = 'event:other'; @($row) } },
        [pscustomobject]@{ label = 'enabled-string'; mutate = { param($row) $row.enabled = 'true'; @($row) } },
        [pscustomobject]@{ label = 'rendered-missing'; mutate = { param($row) $row.PSObject.Properties.Remove('rendered'); @($row) } }
    )
    foreach ($fixture in $roomActionHostileFixtures) {
        $row = New-RoomActionRegressionRow
        $mutator = $fixture.mutate
        $rows = @(& $mutator $row)
        $threw = $false
        try {
            $null = Assert-ExactRenderedRoomActionBinding `
                -Rows $rows `
                -SelectedObjectId 'event:back_alley_offer' `
                -Index 0 `
                -IdentityKey 'emit_object_id' `
                -IdentityValue 'event_response:back_alley_offer:take_cash'
        }
        catch {
            $threw = $true
        }
        if (-not $threw) {
            $failures.Add("Hostile room-action fixture '$($fixture.label)' did not fail closed.")
        }
    }

    function New-SaveAcknowledgmentRegressionObservation {
        $separator = " $([char]0x00B7) "
        return [pscustomobject]@{
            screen = [pscustomobject]@{ run_menu = [pscustomobject]@{ has_save = $true } }
            status_hud = [pscustomobject]@{
                save_text_visible = $true
                save_text = "Autosave On${separator}Saved to Resume Slot."
            }
        }
    }
    try {
        $null = Assert-ExplicitSaveAcknowledgmentObservation -Observation (New-SaveAcknowledgmentRegressionObservation) -Milestone 'fixture'
    }
    catch {
        $failures.Add("Valid exact save acknowledgment fixture threw: $($_.Exception.Message)")
    }
    $saveHostileFixtures = @(
        [pscustomobject]@{ label = 'has-save-string'; mutate = { param($observation) $observation.screen.run_menu.has_save = 'true' } },
        [pscustomobject]@{ label = 'has-save-number'; mutate = { param($observation) $observation.screen.run_menu.has_save = 1 } },
        [pscustomobject]@{ label = 'visible-string'; mutate = { param($observation) $observation.status_hud.save_text_visible = 'true' } },
        [pscustomobject]@{ label = 'visible-missing'; mutate = { param($observation) $observation.status_hud.PSObject.Properties.Remove('save_text_visible') } },
        [pscustomobject]@{ label = 'text-case'; mutate = { param($observation) $observation.status_hud.save_text = $observation.status_hud.save_text.Replace('Saved', 'saved') } }
    )
    foreach ($fixture in $saveHostileFixtures) {
        $observation = New-SaveAcknowledgmentRegressionObservation
        $mutator = $fixture.mutate
        $null = & $mutator $observation
        $threw = $false
        try {
            $null = Assert-ExplicitSaveAcknowledgmentObservation -Observation $observation -Milestone 'fixture'
        }
        catch {
            $threw = $true
        }
        if (-not $threw) {
            $failures.Add("Hostile save-acknowledgment fixture '$($fixture.label)' did not fail closed.")
        }
    }

    function New-TerminalRegressionObservation {
        return [pscustomobject]@{
            screen = [pscustomobject]@{
                screen = 'VICTORY'
                run_report_visible = $true
                run_report = [pscustomobject]@{
                    outcome = [pscustomobject]@{ key = 'players_card'; won = $true }
                }
            }
        }
    }
    $priorObservation = $script:LastObservation
    $priorMidpointSaved = $script:MidpointSaved
    $priorActionCount = $script:ActionCount
    try {
        $script:LastObservation = New-TerminalRegressionObservation
        $script:MidpointSaved = $true
        $script:ActionCount = 0
        if (-not (Test-PublicTerminalSurface) -or (Assert-TerminalOutcome) -cne 'players_card') {
            $failures.Add('Valid exact terminal fixture was rejected.')
        }
    }
    catch {
        $failures.Add("Valid exact terminal fixture threw: $($_.Exception.Message)")
    }
    $terminalHostileFixtures = @(
        [pscustomobject]@{ label = 'screen-case'; mutate = { param($observation) $observation.screen.screen = 'victory' } },
        [pscustomobject]@{ label = 'visible-string'; mutate = { param($observation) $observation.screen.run_report_visible = 'true' } },
        [pscustomobject]@{ label = 'won-number'; mutate = { param($observation) $observation.screen.run_report.outcome.won = 1 } },
        [pscustomobject]@{ label = 'outcome-case'; mutate = { param($observation) $observation.screen.run_report.outcome.key = 'Players_Card' } }
    )
    foreach ($fixture in $terminalHostileFixtures) {
        $script:LastObservation = New-TerminalRegressionObservation
        $mutator = $fixture.mutate
        $null = & $mutator $script:LastObservation
        $threw = $false
        try {
            $null = Assert-TerminalOutcome
        }
        catch {
            $threw = $true
        }
        if (-not $threw) {
            $failures.Add("Hostile terminal fixture '$($fixture.label)' did not fail closed.")
        }
    }
    $script:LastObservation = $priorObservation
    $script:MidpointSaved = $priorMidpointSaved
    $script:ActionCount = $priorActionCount

    $reportPath = Join-Path $Worktree '.tmp\rw06_2\semantic_scroll_contract.json'
    [void](New-Item -ItemType Directory -Path (Split-Path -Parent $reportPath) -Force)
    $summary = [ordered]@{
        schema_version = 1
        check_id = 'rw06_2_semantic_scroll_contract'
        passed = ($failures.Count -ceq 0)
        valid_button_fixtures = 1
        hostile_button_fixtures = $buttonHostileFixtures.Count
        valid_dialog_fixtures = 2
        hostile_dialog_fixtures = $dialogHostileFixtures.Count
        valid_fixtures = 2
        hostile_fixtures = $hostileFixtures.Count
        valid_confirmation_fixtures = 1
        hostile_confirmation_fixtures = $confirmationHostileFixtures.Count
        valid_canvas_object_fixtures = 2
        hostile_canvas_object_fixtures = $canvasObjectHostileFixtures.Count
        valid_room_action_fixtures = 1
        hostile_room_action_fixtures = $roomActionHostileFixtures.Count
        valid_save_acknowledgment_fixtures = 1
        hostile_save_acknowledgment_fixtures = $saveHostileFixtures.Count
        valid_terminal_fixtures = 1
        hostile_terminal_fixtures = $terminalHostileFixtures.Count
        failures = @($failures)
        report = $reportPath
    }
    $summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $reportPath -Encoding utf8
    if ($failures.Count -gt 0) {
        throw "RW06_2_SEMANTIC_SCROLL_CONTRACT FAIL ($($failures.Count) failure(s)); report: $reportPath"
    }
    return [pscustomobject]$summary
}


function Enter-ConfirmationLease {
    $leaseRoot = 'D:\Projects\Beat-The-House-worktrees\.godot_leases'
    [void](New-Item -ItemType Directory -Path $leaseRoot -Force)
    $leasePath = Join-Path $leaseRoot "reset-b-$PID.lease"
    $deadline = (Get-Date).AddMinutes(10)
    while ((Get-Date) -lt $deadline) {
        $exclusivePresent = Test-Path -LiteralPath (Join-Path $leaseRoot 'EXCLUSIVE.lease')
        $focusedLeases = @(Get-ChildItem -LiteralPath $leaseRoot -Filter '*.lease' -File -Force -ErrorAction Stop | Where-Object {
            $_.Name -cne 'EXCLUSIVE.lease'
        })
        if (-not $exclusivePresent -and $focusedLeases.Count -lt 4) {
            try {
                $stream = [IO.File]::Open($leasePath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
                try {
                    $bytes = [Text.Encoding]::UTF8.GetBytes([string]$PID)
                    $stream.Write($bytes, 0, $bytes.Length)
                    $stream.Flush($true)
                }
                finally {
                    $stream.Dispose()
                }
                return $leasePath
            }
            catch [IO.IOException] {
                if (Test-Path -LiteralPath $leasePath -PathType Leaf) {
                    throw "Lane B already owns or retained its confirmation lease: $leasePath"
                }
            }
        }
        Start-Sleep -Milliseconds 500
    }
    throw 'Timed out waiting for an ordinary Q-009 Godot confirmation slot.'
}


function Wait-ForConfirmationGodotCapacity {
    $deadline = (Get-Date).AddMinutes(10)
    while ((Get-Date) -lt $deadline) {
        $godotProcesses = @(Get-CimInstance Win32_Process -ErrorAction Stop | Where-Object {
            $_.Name -like 'Godot*'
        })
        if ($godotProcesses.Count -le 2) {
            return
        }
        Start-Sleep -Milliseconds 500
    }
    throw 'Timed out waiting for two free Godot process slots for the Lane B confirmation.'
}


function Initialize-ConfirmationClassRegistry {
    $classCache = Join-Path $Worktree '.godot\global_script_class_cache.cfg'
    if (Test-Path -LiteralPath $classCache -PathType Leaf) {
        return
    }
    Wait-ForConfirmationGodotCapacity
    $stdoutPath = Join-Path $script:RunRoot 'bootstrap.stdout.log'
    $stderrPath = Join-Path $script:RunRoot 'bootstrap.stderr.log'
    $engineLogPath = Join-Path $script:RunRoot 'bootstrap.engine.log'
    $arguments = @(
        '--headless', '--editor', '--path', $Worktree, '--import', '--quit',
        '--log-file', $engineLogPath
    )
    $process = Start-Process -FilePath $GodotBin -ArgumentList $arguments `
        -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath `
        -WindowStyle Hidden -PassThru
    $deadline = (Get-Date).AddMinutes(5)
    while (-not $process.HasExited -and (Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 100
        $process.Refresh()
    }
    if (-not $process.HasExited) {
        throw "Lane B's owned class-registry bootstrap exceeded five minutes (PID $($process.Id))."
    }
    $process.WaitForExit()
    $process.Refresh()
    if (($null -ne $process.ExitCode -and $process.ExitCode -ne 0) -or
        -not (Test-Path -LiteralPath $classCache -PathType Leaf)) {
        $stderr = if (Test-Path -LiteralPath $stderrPath -PathType Leaf) { Get-Content -Raw -LiteralPath $stderrPath } else { '' }
        throw "Lane B's isolated class-registry bootstrap failed (exit $($process.ExitCode)). $stderr"
    }
}


function Invoke-ConfirmationPlaythrough {
    $leasePath = Enter-ConfirmationLease
    $priorAppData = $env:APPDATA
    $priorLocalAppData = $env:LOCALAPPDATA
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
    $nonce = [Guid]::NewGuid().ToString('N').Substring(0, 10)
    $script:Session = "resetb-$Ending-$PID-$nonce"
    $script:SessionRoot = New-AnchoredSessionRoot -Session $script:Session
    $script:RunRoot = Join-Path $Worktree ".tmp\rw06_2\confirmation\$Ending-$stamp"
    $profileRoot = Join-Path $Worktree ".tmp\rw06_2\confirmation_profiles\$Ending-$stamp-$PID"
    $roamingProfile = Join-Path $profileRoot 'Roaming'
    $localProfile = Join-Path $profileRoot 'Local'
    [void](New-Item -ItemType Directory -Path $script:RunRoot, $roamingProfile, $localProfile -Force)
    $env:APPDATA = $roamingProfile
    $env:LOCALAPPDATA = $localProfile
    $script:TranscriptPath = Join-Path $script:RunRoot 'unused_trace.ndjson'
    $script:MoneyCurvePath = Join-Path $script:RunRoot 'unused_money.ndjson'
    $script:LastResult = $null
    $script:LastObservation = $null
    $script:ActionCount = 0
    $script:TraceOrdinal = 0
    $script:LastMoneySignature = ''
    $script:MidpointSaved = $false
    $script:OwnedSessionPid = 0
    $script:OwnedSessionStartUtcTicks = 0L
    $script:OwnedSessionExecutablePath = ''
    $script:GrandFareRecoveryActive = $false
    $script:GrandFareAcceptedOfferKeys = New-Object 'System.Collections.Generic.HashSet[string]'
    $script:GrandFareAcceptedLenderIds = New-Object 'System.Collections.Generic.HashSet[string]'
    $script:GrandFareResolvedCashEventKeys = New-Object 'System.Collections.Generic.HashSet[string]'
    $script:GrandFareRecoveryVisitedNodes = New-Object 'System.Collections.Generic.HashSet[string]'
    $script:HeistLaunchSetup = $null
    $screenshotPath = ''
    $outcome = ''
    $completed = $false
    try {
        Initialize-ConfirmationClassRegistry
        Wait-ForConfirmationGodotCapacity
        Start-BridgeSession
        Start-NormalSeededRun
        Invoke-SelectedEndingRoute
        $result = Invoke-BridgeCommand -Command 'look' -Intent 'save the requested win-screen confirmation' -ObservationOnly
        $outcome = Assert-TerminalOutcome
        $sourcePng = Get-ExactReplayString -InputObject $result -Path @('look', 'png') -Context "Win screenshot for '$Ending'"
        if (-not (Test-Path -LiteralPath $sourcePng -PathType Leaf)) {
            throw "The normal playthrough did not produce its final win screenshot: $sourcePng"
        }
        $ownerReviewRoot = 'D:\Projects\Beat-The-House\.tmp\owner_review'
        [void](New-Item -ItemType Directory -Path $ownerReviewRoot -Force)
        $screenshotPath = Join-Path $ownerReviewRoot "ending_$Ending.png"
        Copy-Item -LiteralPath $sourcePng -Destination $screenshotPath -Force
        $completed = $true
        return [pscustomobject][ordered]@{
            ending = $Ending
            outcome = $outcome
            seed = $Seed
            actions = $script:ActionCount
            screenshot = $screenshotPath
            session_log = Join-Path $script:SessionRoot 'godot.engine.log'
        }
    }
    finally {
        if ($script:OwnedSessionPid -gt 0) {
            Stop-BridgeSessionSafely -BestEffort
        }
        $env:APPDATA = $priorAppData
        $env:LOCALAPPDATA = $priorLocalAppData
        if (Test-Path -LiteralPath $leasePath -PathType Leaf) {
            Remove-Item -LiteralPath $leasePath -Force
        }
        if (-not $completed -and -not [string]::IsNullOrWhiteSpace($screenshotPath) -and (Test-Path -LiteralPath $screenshotPath -PathType Leaf)) {
            Remove-Item -LiteralPath $screenshotPath -Force
        }
    }
}


if ($ConfirmationOnly) {
    Invoke-ConfirmationPlaythrough | ConvertTo-Json -Depth 8
    exit 0
}


if ($SemanticScrollContract) {
    Invoke-SemanticScrollRegression | ConvertTo-Json -Depth 8
    exit 0
}


if ($BridgeStatusContract) {
    Invoke-BridgeStatusRegression | ConvertTo-Json -Depth 5
    exit 0
}


if ($BridgeTransportContract) {
    Invoke-BridgeTransportRegression | ConvertTo-Json -Depth 10
    exit 0
}


$invocationStamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
$invocationRoot = New-ExclusiveEvidenceDirectory -Path (Join-Path $EvidenceRoot "$invocationStamp-$PID")
$heistSeedPreflight = $null
if ($Ending -ceq 'heist') {
    $heistSeedPreflight = Invoke-HeistSeedPreflight -OutputPath (Join-Path $invocationRoot 'heist_seed_preflight.json')
}
$runSummaries = @()
$validatedRunReceipts = @()
$referenceTranscriptHash = ''
$referenceMoneyHash = ''
$referenceCheckpointBeforeHash = ''
$referenceCheckpointAfterHash = ''
$referenceFinalCheckpointJson = ''

for ($iteration = 1; $iteration -le $Repeat; $iteration++) {
    $nonce = [Guid]::NewGuid().ToString('N').Substring(0, 10)
    $script:Session = "rw062-$Ending-$PID-$iteration-$nonce"
    $script:SessionRoot = New-AnchoredSessionRoot -Session $script:Session
    $script:RunRoot = New-ExclusiveEvidenceDirectory -Path (Join-Path $invocationRoot ("run-{0:D2}" -f $iteration))
    $script:TranscriptPath = Join-Path $script:RunRoot 'public_trace.ndjson'
    $script:MoneyCurvePath = Join-Path $script:RunRoot 'money_curve.ndjson'
    $script:LastResult = $null
    $script:LastObservation = $null
    $script:ActionCount = 0
    $script:TraceOrdinal = 0
    $script:LastMoneySignature = ''
    $script:MidpointSaved = $false
    $script:OwnedSessionPid = 0
    $script:OwnedSessionStartUtcTicks = 0L
    $script:OwnedSessionExecutablePath = ''
    $script:GrandFareRecoveryActive = $false
    $script:GrandFareAcceptedOfferKeys = New-Object 'System.Collections.Generic.HashSet[string]'
    $script:GrandFareAcceptedLenderIds = New-Object 'System.Collections.Generic.HashSet[string]'
    $script:GrandFareResolvedCashEventKeys = New-Object 'System.Collections.Generic.HashSet[string]'
    $script:GrandFareRecoveryVisitedNodes = New-Object 'System.Collections.Generic.HashSet[string]'
    $script:HeistLaunchSetup = $null
    $passed = $false
    $failureMessage = ''
    $finalPublicCheckpoint = $null
    try {
        Start-BridgeSession
        Start-NormalSeededRun
        Invoke-SelectedEndingRoute
        $outcome = Assert-TerminalOutcome
        $finalPublicCheckpoint = Write-FinalPublicCheckpoint
        $passed = $true
    }
    catch {
        $failureMessage = $_.Exception.Message
        throw
    }
    finally {
        if ($passed) {
            Stop-BridgeSessionSafely
        }
        else {
            Stop-BridgeSessionSafely -BestEffort
        }
        $transcriptHash = if (Test-Path -LiteralPath $script:TranscriptPath) { (Get-FileHash -LiteralPath $script:TranscriptPath -Algorithm SHA256).Hash.ToLowerInvariant() } else { '' }
        $moneyHash = if (Test-Path -LiteralPath $script:MoneyCurvePath) { (Get-FileHash -LiteralPath $script:MoneyCurvePath -Algorithm SHA256).Hash.ToLowerInvariant() } else { '' }
        $checkpointBeforePath = [IO.Path]::GetFullPath((Join-Path $script:RunRoot 'checkpoint_before.json'))
        $checkpointAfterPath = [IO.Path]::GetFullPath((Join-Path $script:RunRoot 'checkpoint_after.json'))
        $checkpointBeforeHash = if (Test-Path -LiteralPath $checkpointBeforePath -PathType Leaf) { (Get-FileHash -LiteralPath $checkpointBeforePath -Algorithm SHA256).Hash.ToLowerInvariant() } else { '' }
        $checkpointAfterHash = if (Test-Path -LiteralPath $checkpointAfterPath -PathType Leaf) { (Get-FileHash -LiteralPath $checkpointAfterPath -Algorithm SHA256).Hash.ToLowerInvariant() } else { '' }
        $checkpointEvidenceComplete = $script:MidpointSaved -and
            $checkpointBeforeHash -cmatch '^[a-f0-9]{64}$' -and
            $checkpointAfterHash -cmatch '^[a-f0-9]{64}$' -and
            $checkpointBeforeHash -ceq $checkpointAfterHash
        if ($passed -and -not $checkpointEvidenceComplete) {
            $passed = $false
            $failureMessage = 'Successful Save -> process-exit -> Continue evidence is missing, unhashed, or unequal.'
            $finalPublicCheckpoint = $null
        }
        $summaryOutcome = ''
        $summaryObservedSeed = ''
        if ($passed) {
            Assert-ExactFinalPublicCheckpoint -Checkpoint $finalPublicCheckpoint -ExpectedSeed $Seed -Context "Replay child $iteration final checkpoint"
            $summaryOutcome = Get-ExactReplayString -InputObject $finalPublicCheckpoint -Path @('outcome_key') -Context "Replay child $iteration outcome"
            $summaryObservedSeed = Get-ExactReplayString -InputObject $finalPublicCheckpoint -Path @('observed_seed') -Context "Replay child $iteration terminal seed"
        }
        $runSummary = [ordered]@{
            role = 'child_development_iteration'
            requested_evidence_role = $EvidenceRole
            repeat_profile_scope = 'shared_caller_appdata'
            fixed_repeat_qualification_authority = 'outer_independent_profile_aggregate_only'
            release_qualifying = $false
            qualification = 'non_qualifying_development_iteration'
            replay_admission = $script:ReplayAdmission
            iteration = $iteration
            ending = $Ending
            seed = $Seed
            session = $script:Session
            passed = $passed
            outcome = $summaryOutcome
            observed_terminal_seed = $summaryObservedSeed
            action_count = $script:ActionCount
            midpoint_save_relaunch_continue = $script:MidpointSaved
            heist_seed_preflight = $heistSeedPreflight
            heist_preflight_admission = $script:HeistPreflightAdmissionReceipt
            heist_launch_setup = $script:HeistLaunchSetup
            transcript = $script:TranscriptPath
            transcript_sha256 = $transcriptHash
            money_curve = $script:MoneyCurvePath
            money_curve_sha256 = $moneyHash
            persistence_checkpoint_before = if ($checkpointBeforeHash) { $checkpointBeforePath } else { '' }
            persistence_checkpoint_before_sha256 = $checkpointBeforeHash
            persistence_checkpoint_after = if ($checkpointAfterHash) { $checkpointAfterPath } else { '' }
            persistence_checkpoint_after_sha256 = $checkpointAfterHash
            persistence_checkpoint_equal = $checkpointEvidenceComplete
            persistence_checkpoint_complete = $checkpointEvidenceComplete
            final_public_checkpoint = $finalPublicCheckpoint
            failure = $failureMessage
        }
        $runSummaryObject = [pscustomobject]$runSummary
        $runReceipt = Assert-ExactReplayRunSummary `
            -Summary $runSummaryObject `
            -ExpectedEnding $Ending `
            -ExpectedSeed $Seed `
            -ExpectedIteration ([int32]$iteration)
        $runSummaryObject | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $script:RunRoot 'summary.json') -Encoding utf8
        $runSummaries += $runSummaryObject
        $validatedRunReceipts += $runReceipt
    }

    $latestRunReceipt = $validatedRunReceipts[$validatedRunReceipts.Count - 1]
    if ($latestRunReceipt.passed -isnot [bool] -or -not $latestRunReceipt.passed) {
        throw $latestRunReceipt.failure
    }

    $currentTranscriptHash = $latestRunReceipt.transcript_sha256
    $currentMoneyHash = $latestRunReceipt.money_curve_sha256
    $currentCheckpointBeforeHash = $latestRunReceipt.persistence_checkpoint_before_sha256
    $currentCheckpointAfterHash = $latestRunReceipt.persistence_checkpoint_after_sha256
    $currentFinalCheckpointJson = $latestRunReceipt.final_public_checkpoint | ConvertTo-Json -Depth 10 -Compress
    if ($iteration -ceq 1) {
        $referenceTranscriptHash = $currentTranscriptHash
        $referenceMoneyHash = $currentMoneyHash
        $referenceCheckpointBeforeHash = $currentCheckpointBeforeHash
        $referenceCheckpointAfterHash = $currentCheckpointAfterHash
        $referenceFinalCheckpointJson = $currentFinalCheckpointJson
    }
    elseif ($currentTranscriptHash -cne $referenceTranscriptHash -or
        $currentMoneyHash -cne $referenceMoneyHash -or
        $currentCheckpointBeforeHash -cne $referenceCheckpointBeforeHash -or
        $currentCheckpointAfterHash -cne $referenceCheckpointAfterHash -or
        $currentFinalCheckpointJson -cne $referenceFinalCheckpointJson) {
        throw "Deterministic replay mismatch for '$Ending': repeat $iteration differs from repeat 1."
    }
}

$deterministic = $Repeat -ceq 2 -and
    @($validatedRunReceipts | Select-Object -ExpandProperty transcript_sha256 -Unique).Count -ceq 1 -and
    @($validatedRunReceipts | Select-Object -ExpandProperty money_curve_sha256 -Unique).Count -ceq 1 -and
    @($validatedRunReceipts | Select-Object -ExpandProperty persistence_checkpoint_before_sha256 -Unique).Count -ceq 1 -and
    @($validatedRunReceipts | Select-Object -ExpandProperty persistence_checkpoint_after_sha256 -Unique).Count -ceq 1 -and
    @($validatedRunReceipts | ForEach-Object { $_.final_public_checkpoint | ConvertTo-Json -Depth 10 -Compress } | Select-Object -Unique).Count -ceq 1
$checkpointEvidenceComplete = $validatedRunReceipts.Count -eq $Repeat -and
    @($validatedRunReceipts | Where-Object {
        $_.persistence_checkpoint_complete -isnot [bool] -or -not $_.persistence_checkpoint_complete
    }).Count -ceq 0
# Repeats inside this direct runner inherit one caller APPDATA/LOCALAPPDATA
# environment. They may prove deterministic behavior for development, but only
# the outer launcher can create and attest two independent profiles.
$finalSummary = [ordered]@{
    schema_version = 1
    check_id = 'rw06_2_ending_replay'
    role = 'child_development_run'
    requested_evidence_role = $EvidenceRole
    repeat_profile_scope = 'shared_caller_appdata'
    fixed_repeat_qualification_authority = 'outer_independent_profile_aggregate_only'
    ending = $Ending
    seed = $Seed
    observed_terminal_seeds = @($validatedRunReceipts | Select-Object -ExpandProperty observed_terminal_seed)
    repeat = $Repeat
    deterministic = $deterministic
    checkpoint_evidence_complete = $checkpointEvidenceComplete
    release_qualifying = $false
    qualification = 'non_qualifying_development_run'
    replay_admission = $script:ReplayAdmission
    public_observation_schema = $Schema
    public_observation_schema_version = $SchemaVersion
    heist_seed_preflight = $heistSeedPreflight
    heist_preflight_admission = $script:HeistPreflightAdmissionReceipt
    evidence_root = $invocationRoot
    runs = $runSummaries
}
$finalSummaryObject = [pscustomobject]$finalSummary
Assert-ExactReplayFinalSummary `
    -Summary $finalSummaryObject `
    -ExpectedEnding $Ending `
    -ExpectedSeed $Seed `
    -ExpectedRepeat ([int32]$Repeat)
$summaryPath = Join-Path $invocationRoot 'summary.json'
$finalSummaryObject | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $summaryPath -Encoding utf8
$finalSummaryObject | ConvertTo-Json -Depth 30
