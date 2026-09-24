[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9a-fA-F]{40}$')]
    [string]$ExpectedHead,
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9a-fA-F]{40}$')]
    [string]$ExpectedTree,
    [Parameter(Mandatory = $true)]
    [ValidateSet('clean', 'cheat', 'heist')]
    [string]$Ending,
    [ValidateRange(300, 3600)]
    [int]$PerRunTimeoutSeconds = 1800,
    [ValidateRange(30, 300)]
    [int]$CommandTimeoutSeconds = 120
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Ending = $Ending.ToLowerInvariant()
$Worktree = Split-Path -Parent $PSScriptRoot
$EvidenceAdmissionTool = Join-Path $PSScriptRoot 'rw06_2_evidence_admission.ps1'
$GodotBin = 'D:\Projects\Beat-The-House\.tools\godot-4.6-stable\Godot_v4.6-stable_win64_console.exe'
$LeaseRoot = 'D:\Projects\Beat-The-House-worktrees\.godot_leases'
$LaunchLockPath = Join-Path $LeaseRoot '.launch.lock'
$FixedSeeds = @{
    clean = 'RW06-CLEAN-ROUTE-01'
    cheat = 'RW06-CHEAT-ROUTE-01'
    heist = 'RW06-HEIST-AUDIT-0002'
}
$ExpectedOutcomes = @{
    clean = @('players_card')
    cheat = @('showdown_survived')
    heist = @('heist_clean_sweep', 'heist_out_hot', 'heist_somebody_got_pinched')
}
$Seed = [string]$FixedSeeds[$Ending]
$Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$Nonce = [Guid]::NewGuid().ToString('N').Substring(0, 8)
$EvidenceRoot = Join-Path $Worktree ".tmp\rw06_2\final_fixed\$Ending-$Stamp-$PID-$Nonce"
$LeasePath = Join-Path $LeaseRoot 'EXCLUSIVE.lease'
$LauncherSnapshotPath = Join-Path $EvidenceRoot 'launcher.invoked.ps1'
$AggregateSummaryPath = Join-Path $EvidenceRoot 'aggregate_summary.json'
$MetadataPath = Join-Path $EvidenceRoot 'run_metadata.json'
$ManifestPath = Join-Path $EvidenceRoot 'artifact_manifest.json'
$SourceCustodyPrePath = Join-Path $EvidenceRoot 'source_custody_pre.json'
$SourceCustodyFinalPath = Join-Path $EvidenceRoot 'source_custody_final.json'
$GodotRuntimeBin = Join-Path (Split-Path -Parent $GodotBin) 'Godot_v4.6-stable_win64.exe'
$StartedAt = [DateTimeOffset]::Now

$script:TerminalError = $null
$script:Outcome = 'error'
$script:LeaseOwned = $false
$script:LauncherInitialSha256 = ''
$script:LauncherCurrentSha256 = ''
$script:OwnedReplayIdentities = [Collections.Generic.List[object]]::new()
$script:ProvisionalReplayProcesses = [Collections.Generic.List[object]]::new()
$script:RunProofs = [Collections.Generic.List[object]]::new()
$script:CanonicalProof = $null
$script:InitialProcessCensus = @()
$script:FinalProcessCensus = @()
$script:FinalHead = ''
$script:FinalTree = ''
$script:SourceCustodyStreams = [Collections.Generic.List[IO.FileStream]]::new()
$script:SourceCustodyRows = [Collections.Generic.List[object]]::new()
$script:SourceCustodyPreStream = $null
$script:SourceCustodyFinalStream = $null
$script:EvidenceArtifactStreams = [Collections.Generic.List[IO.FileStream]]::new()
$script:SourceCustodyPreSha256 = ''
$script:SourceCustodyFinalSha256 = ''
$script:SourceCustodyComplete = $false

function Get-FailureMessage {
    param([AllowNull()]$Failure)
    if ($null -eq $Failure) { return '' }
    if ($Failure -is [Management.Automation.ErrorRecord]) { return $Failure.Exception.Message }
    if ($Failure -is [Exception]) { return $Failure.Message }
    return [string]$Failure
}


function Add-TerminalFailure {
    param([Parameter(Mandatory = $true)]$Failure)
    $message = Get-FailureMessage -Failure $Failure
    if ($null -eq $script:TerminalError) {
        $script:TerminalError = [InvalidOperationException]::new($message)
    }
    else {
        $prior = Get-FailureMessage -Failure $script:TerminalError
        $script:TerminalError = [InvalidOperationException]::new("$prior | $message")
    }
    $script:Outcome = 'red'
}


function Get-ExactValue {
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
            if ($matches.Count -ne 1) { throw "Ambiguous exact property '$segment'." }
            $current = $current[$matches[0]]
        }
        else {
            $properties = @($current.PSObject.Properties | Where-Object { $_.Name -ceq $segment })
            if ($properties.Count -eq 0) { return $Default }
            if ($properties.Count -ne 1) { throw "Ambiguous exact property '$segment'." }
            $current = $properties[0].Value
        }
    }
    if ($null -eq $current) { return $Default }
    return $current
}


function Get-ExactValueNoEnumerate {
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
            if ($matches.Count -ne 1) { throw "Ambiguous exact property '$segment'." }
            $current = $current[$matches[0]]
        }
        else {
            $properties = @($current.PSObject.Properties | Where-Object { $_.Name -ceq $segment })
            if ($properties.Count -eq 0) {
                Write-Output -NoEnumerate $Default
                return
            }
            if ($properties.Count -ne 1) { throw "Ambiguous exact property '$segment'." }
            $current = $properties[0].Value
        }
    }
    if ($null -eq $current) {
        Write-Output -NoEnumerate $Default
        return
    }
    Write-Output -NoEnumerate $current
}


function Test-ExactStringArray {
    param(
        [AllowNull()]$Value,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$Expected
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


function Get-ExactPositivePid {
    param(
        [Parameter(Mandatory = $true)]$InputObject,
        [Parameter(Mandatory = $true)][string]$Name
    )
    $value = Get-ExactValueNoEnumerate $InputObject @($Name) $null
    if (($value -isnot [int32] -and $value -isnot [int64]) -or
        [int64]$value -le 0 -or [int64]$value -gt [int32]::MaxValue) {
        throw "Lease/process field '$Name' is not one exact positive PID."
    }
    return [int]$value
}


function Get-ExactPidArray {
    param(
        [Parameter(Mandatory = $true)]$InputObject,
        [Parameter(Mandatory = $true)][string]$Name
    )
    $raw = Get-ExactValueNoEnumerate $InputObject @($Name) $null
    if ($null -eq $raw -or $raw -is [string] -or
        $raw -isnot [Collections.IEnumerable]) {
        throw "Lease/process field '$Name' is not one exact PID collection."
    }
    $pids = [Collections.Generic.List[int]]::new()
    foreach ($value in @($raw)) {
        if (($value -isnot [int32] -and $value -isnot [int64]) -or
            [int64]$value -le 0 -or [int64]$value -gt [int32]::MaxValue) {
            throw "Lease/process field '$Name' contains an invalid PID."
        }
        $pids.Add([int]$value)
    }
    return @($pids)
}


function Assert-FixedReplayAdmission {
    param(
        [Parameter(Mandatory = $true)]$Admission,
        [Parameter(Mandatory = $true)][string]$Label
    )
    Assert-Rw062ExactPropertyNames -InputObject $Admission -Label "$Label replay admission" -Expected @(
        'evidence_role', 'ending', 'seed', 'repeat', 'route_plan',
        'expected_initial_scenario', 'scenario_authority', 'scenario_injection_allowed',
        'plan_b_allowed', 'requires_isolated_profile', 'release_qualifying',
        'qualification_authority', 'owner_decisions'
    )
    $expectedRoutePlan = if ($Ending -ceq 'heist') { 'count' } else { '' }
    $expectedScenario = if ($Ending -ceq 'heist') { 'grand_casino_audit_night' } else { '' }
    $expectedAuthority = if ($Ending -ceq 'heist') { 'natural_fresh_profile_first_arrival_preflight' } else { 'route_seed' }
    $expectedOwnerDecisions = [string[]]@()
    if ($Ending -ceq 'heist') { $expectedOwnerDecisions = [string[]]@('Q-013A', 'Q-017A') }
    $actualEvidenceRole = Get-ExactValueNoEnumerate $Admission @('evidence_role') $null
    $actualEnding = Get-ExactValueNoEnumerate $Admission @('ending') $null
    $actualSeed = Get-ExactValueNoEnumerate $Admission @('seed') $null
    $actualRepeat = Get-ExactValueNoEnumerate $Admission @('repeat') $null
    $actualRoutePlan = Get-ExactValueNoEnumerate $Admission @('route_plan') $null
    $actualExpectedScenario = Get-ExactValueNoEnumerate $Admission @('expected_initial_scenario') $null
    $actualScenarioAuthority = Get-ExactValueNoEnumerate $Admission @('scenario_authority') $null
    $actualScenarioInjectionAllowed = Get-ExactValueNoEnumerate $Admission @('scenario_injection_allowed') $null
    $actualPlanBAllowed = Get-ExactValueNoEnumerate $Admission @('plan_b_allowed') $null
    $actualRequiresIsolatedProfile = Get-ExactValueNoEnumerate $Admission @('requires_isolated_profile') $null
    $actualReleaseQualifying = Get-ExactValueNoEnumerate $Admission @('release_qualifying') $null
    $actualQualificationAuthority = Get-ExactValueNoEnumerate $Admission @('qualification_authority') $null
    $actualOwnerDecisions = Get-ExactValueNoEnumerate $Admission @('owner_decisions') '__missing_owner_decisions__'
    $ownerDecisionsValid = Test-ExactStringArray -Value $actualOwnerDecisions -Expected $expectedOwnerDecisions
    if ($actualEvidenceRole -isnot [string] -or $actualEvidenceRole -cne 'fixed-repeat' -or
        $actualEnding -isnot [string] -or $actualEnding -cne $Ending -or
        $actualSeed -isnot [string] -or $actualSeed -cne $Seed -or
        $actualRepeat -isnot [int32] -or [int]$actualRepeat -ne 1 -or
        $actualRoutePlan -isnot [string] -or $actualRoutePlan -cne $expectedRoutePlan -or
        $actualExpectedScenario -isnot [string] -or $actualExpectedScenario -cne $expectedScenario -or
        $actualScenarioAuthority -isnot [string] -or $actualScenarioAuthority -cne $expectedAuthority -or
        $actualScenarioInjectionAllowed -isnot [bool] -or [bool]$actualScenarioInjectionAllowed -or
        $actualPlanBAllowed -isnot [bool] -or [bool]$actualPlanBAllowed -or
        $actualRequiresIsolatedProfile -isnot [bool] -or -not [bool]$actualRequiresIsolatedProfile -or
        $actualReleaseQualifying -isnot [bool] -or [bool]$actualReleaseQualifying -or
        $actualQualificationAuthority -isnot [string] -or
        $actualQualificationAuthority -cne 'outer_independent_profile_aggregate_only' -or
        -not $ownerDecisionsValid) {
        throw "$Label did not retain the exact fixed-repeat replay admission."
    }
}


function Get-GitValue {
    param([Parameter(Mandatory = $true)][string]$Revision)
    $value = @(& git -C $Worktree rev-parse $Revision)
    if ($LASTEXITCODE -ne 0 -or $value.Count -ne 1) {
        throw "Could not resolve git revision $Revision."
    }
    return ([string]$value[0]).Trim().ToLowerInvariant()
}


function Get-Sha256 {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Required evidence file is missing: $Path"
    }
    return (Microsoft.PowerShell.Utility\Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}


function Test-ExactPsCustomObject {
    param([AllowNull()]$Value)
    return $null -ne $Value -and
        $Value.GetType().FullName -ceq 'System.Management.Automation.PSCustomObject'
}


function Assert-LocalExactPropertyNames {
    param(
        [Parameter(Mandatory = $true)]$InputObject,
        [Parameter(Mandatory = $true)][string[]]$Expected,
        [Parameter(Mandatory = $true)][string]$Label
    )
    if (-not (Test-ExactPsCustomObject -Value $InputObject)) {
        throw "$Label must be one exact object."
    }
    $actual = @($InputObject.PSObject.Properties | ForEach-Object { [string]$_.Name })
    if ($actual.Count -ne $Expected.Count) {
        throw "$Label property count drifted: expected $($Expected.Count), observed $($actual.Count)."
    }
    for ($index = 0; $index -lt $Expected.Count; $index++) {
        if ($actual[$index] -cne $Expected[$index]) {
            throw "$Label property order/name drifted at index $index; expected '$($Expected[$index])', observed '$($actual[$index])'."
        }
    }
}


function ConvertFrom-ExactJsonObjectText {
    param(
        [Parameter(Mandatory = $true)][string]$Json,
        [Parameter(Mandatory = $true)][string]$Label
    )
    $trimmed = $Json.Trim()
    if ([string]::IsNullOrWhiteSpace($trimmed) -or
        $trimmed[0] -cne '{' -or $trimmed[$trimmed.Length - 1] -cne '}') {
        throw "$Label is not one exact JSON object."
    }
    try { $value = $trimmed | Microsoft.PowerShell.Utility\ConvertFrom-Json }
    catch { throw "$Label is not valid JSON: $($_.Exception.Message)" }
    if (-not (Test-ExactPsCustomObject -Value $value)) {
        throw "$Label is not one exact JSON object."
    }
    Write-Output -NoEnumerate $value
}


function ConvertTo-CanonicalExactObjectJson {
    param(
        [Parameter(Mandatory = $true)]$InputObject,
        [Parameter(Mandatory = $true)][string]$Label,
        [ValidateRange(2, 100)][int]$Depth = 30
    )
    if (-not (Test-ExactPsCustomObject -Value $InputObject)) {
        throw "$Label is not one exact object."
    }
    return Microsoft.PowerShell.Utility\ConvertTo-Json -InputObject $InputObject -Depth $Depth -Compress
}


function Get-CanonicalExactObjectSha256 {
    param(
        [Parameter(Mandatory = $true)]$InputObject,
        [Parameter(Mandatory = $true)][string]$Label
    )
    $canonicalJson = ConvertTo-CanonicalExactObjectJson `
        -InputObject $InputObject `
        -Label $Label `
        -Depth 30
    if ($canonicalJson -isnot [string]) {
        throw "$Label canonical JSON is not one exact string."
    }
    $canonicalBytes = [Text.UTF8Encoding]::new($false).GetBytes($canonicalJson)
    $sha256 = [Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($sha256.ComputeHash($canonicalBytes))).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $sha256.Dispose()
    }
}


function Get-HeldFileDigests {
    param([Parameter(Mandatory = $true)][IO.FileStream]$Stream)
    if (-not $Stream.CanRead -or -not $Stream.CanSeek) {
        throw 'Held file stream is not readable and seekable.'
    }
    $originalPosition = $Stream.Position
    $sha1 = [Security.Cryptography.SHA1]::Create()
    $sha256 = [Security.Cryptography.SHA256]::Create()
    try {
        $length = [int64]$Stream.Length
        $header = [Text.Encoding]::UTF8.GetBytes("blob $length`0")
        $null = $sha1.TransformBlock($header, 0, $header.Length, $header, 0)
        $Stream.Position = 0
        $buffer = [byte[]]::new(1048576)
        while (($read = $Stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
            $null = $sha1.TransformBlock($buffer, 0, $read, $buffer, 0)
            $null = $sha256.TransformBlock($buffer, 0, $read, $buffer, 0)
        }
        $empty = [byte[]]::new(0)
        $null = $sha1.TransformFinalBlock($empty, 0, 0)
        $null = $sha256.TransformFinalBlock($empty, 0, 0)
        return [pscustomobject][ordered]@{
            byte_length = $length
            raw_git_blob = ([BitConverter]::ToString($sha1.Hash)).Replace('-', '').ToLowerInvariant()
            sha256 = ([BitConverter]::ToString($sha256.Hash)).Replace('-', '').ToLowerInvariant()
        }
    }
    finally {
        $Stream.Position = $originalPosition
        $sha1.Dispose()
        $sha256.Dispose()
    }
}


function Get-HeldUtf8Text {
    param([Parameter(Mandatory = $true)][IO.FileStream]$Stream)
    if (-not $Stream.CanRead -or -not $Stream.CanSeek) {
        throw 'Held UTF-8 file stream is not readable and seekable.'
    }
    $originalPosition = $Stream.Position
    $reader = $null
    try {
        $Stream.Position = 0
        $reader = [IO.StreamReader]::new($Stream, [Text.Encoding]::UTF8, $true, 4096, $true)
        return $reader.ReadToEnd()
    }
    finally {
        if ($null -ne $reader) { $reader.Dispose() }
        $Stream.Position = $originalPosition
    }
}


function New-LockedJsonReceipt {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]$Receipt,
        [Parameter(Mandatory = $true)][string]$Label
    )
    if (Test-Path -LiteralPath $Path) { throw "$Label path already exists: $Path" }
    $receiptObject = if (Test-ExactPsCustomObject -Value $Receipt) { $Receipt } else { [pscustomobject]$Receipt }
    $json = (Microsoft.PowerShell.Utility\ConvertTo-Json -InputObject $receiptObject -Depth 10) + [Environment]::NewLine
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($json)
    $stream = $null
    try {
        $stream = [IO.File]::Open($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::ReadWrite, [IO.FileShare]::Read)
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Flush($true)
        $stream.Position = 0
        $digests = Get-HeldFileDigests -Stream $stream
        $parsed = ConvertFrom-ExactJsonObjectText -Json (Get-HeldUtf8Text -Stream $stream) -Label $Label
        if ((ConvertTo-CanonicalExactObjectJson -InputObject $parsed -Label "$Label parsed receipt" -Depth 30) -cne
            (ConvertTo-CanonicalExactObjectJson -InputObject $receiptObject -Label "$Label in-memory receipt" -Depth 30)) {
            throw "$Label bytes differ from the in-memory receipt."
        }
        return [pscustomobject][ordered]@{ stream = $stream; sha256 = $digests.sha256 }
    }
    catch {
        if ($null -ne $stream) { $stream.Dispose() }
        throw
    }
}


function Get-TrackedSourceDescriptors {
    $lines = @(& git -C $Worktree -c core.quotepath=false ls-tree -r --full-tree $ExpectedHead)
    if ($LASTEXITCODE -ne 0 -or $lines.Count -eq 0) {
        throw 'Could not enumerate the immutable HEAD production input tree.'
    }
    $rows = [Collections.Generic.List[object]]::new()
    foreach ($line in $lines) {
        $match = [regex]::Match([string]$line, '^(?<mode>100644|100755) blob (?<blob>[a-f0-9]{40})\t(?<path>.+)$')
        if (-not $match.Success) {
            throw "Immutable HEAD production input row is not one exact regular blob: $line"
        }
        $relativePath = [string]$match.Groups['path'].Value
        $absolutePath = [IO.Path]::GetFullPath((Join-Path $Worktree $relativePath))
        $rows.Add([pscustomobject][ordered]@{
            id = "repository:$relativePath"
            scope = 'repository_tracked_production_tree'
            repository_path = $relativePath
            absolute_path = $absolutePath
            expected_git_mode = [string]$match.Groups['mode'].Value
            expected_git_blob = [string]$match.Groups['blob'].Value
        })
    }
    foreach ($external in @(
        [pscustomobject]@{ id = 'godot:console'; scope = 'pinned_engine'; path = $GodotBin },
        [pscustomobject]@{ id = 'godot:runtime'; scope = 'pinned_engine'; path = $GodotRuntimeBin },
        [pscustomobject]@{ id = 'powershell:host'; scope = 'process_host'; path = [Diagnostics.Process]::GetCurrentProcess().MainModule.FileName }
    )) {
        $rows.Add([pscustomobject][ordered]@{
            id = [string]$external.id
            scope = [string]$external.scope
            repository_path = ''
            absolute_path = [IO.Path]::GetFullPath([string]$external.path)
            expected_git_mode = ''
            expected_git_blob = ''
        })
    }
    return @($rows)
}


function Assert-SourceCustodyRowSchema {
    param(
        [Parameter(Mandatory = $true)]$Row,
        [Parameter(Mandatory = $true)][ValidateSet('pre', 'final')][string]$Phase,
        [Parameter(Mandatory = $true)][ValidateSet('in_memory', 'json')][string]$Representation,
        [Parameter(Mandatory = $true)][string]$Label
    )
    $preProperties = @(
        'id', 'scope', 'repository_path', 'absolute_path', 'expected_git_mode',
        'expected_git_blob', 'byte_length', 'raw_git_blob', 'pre_sha256'
    )
    $finalProperties = @(
        'id', 'scope', 'repository_path', 'absolute_path', 'expected_git_mode',
        'expected_git_blob', 'byte_length', 'raw_git_blob', 'pre_sha256',
        'post_sha256', 'stable'
    )
    Assert-LocalExactPropertyNames `
        -InputObject $Row `
        -Expected $(if ($Phase -ceq 'pre') { $preProperties } else { $finalProperties }) `
        -Label $Label

    $id = Get-ExactValueNoEnumerate $Row @('id') $null
    $scope = Get-ExactValueNoEnumerate $Row @('scope') $null
    $repositoryPath = Get-ExactValueNoEnumerate $Row @('repository_path') $null
    $absolutePath = Get-ExactValueNoEnumerate $Row @('absolute_path') $null
    $expectedMode = Get-ExactValueNoEnumerate $Row @('expected_git_mode') $null
    $expectedBlob = Get-ExactValueNoEnumerate $Row @('expected_git_blob') $null
    $byteLength = Get-ExactValueNoEnumerate $Row @('byte_length') $null
    $rawBlob = Get-ExactValueNoEnumerate $Row @('raw_git_blob') $null
    $preHash = Get-ExactValueNoEnumerate $Row @('pre_sha256') $null
    $byteLengthHasExactType = if ($Representation -ceq 'in_memory') {
        $byteLength -is [int64]
    }
    else {
        $byteLength -is [int32] -or $byteLength -is [int64]
    }
    if ($id -isnot [string] -or [string]::IsNullOrWhiteSpace($id) -or
        $scope -isnot [string] -or [string]::IsNullOrWhiteSpace($scope) -or
        $repositoryPath -isnot [string] -or
        $absolutePath -isnot [string] -or [string]::IsNullOrWhiteSpace($absolutePath) -or
        $expectedMode -isnot [string] -or $expectedBlob -isnot [string] -or
        -not $byteLengthHasExactType -or [int64]$byteLength -lt 0 -or
        $rawBlob -isnot [string] -or $rawBlob -cnotmatch '^[a-f0-9]{40}$' -or
        $preHash -isnot [string] -or $preHash -cnotmatch '^[a-f0-9]{64}$') {
        throw "$Label has an invalid exact scalar type or format."
    }
    if ([IO.Path]::GetFullPath($absolutePath) -cne $absolutePath) {
        throw "$Label absolute_path is not one normalized absolute path."
    }

    if ($scope -ceq 'repository_tracked_production_tree') {
        if ($repositoryPath.Length -eq 0 -or [IO.Path]::IsPathRooted($repositoryPath) -or
            $id -cne "repository:$repositoryPath" -or
            $expectedMode -notmatch '^100(644|755)$' -or
            $expectedBlob -cnotmatch '^[a-f0-9]{40}$' -or
            $rawBlob -cne $expectedBlob -or
            [IO.Path]::GetFullPath((Join-Path $Worktree $repositoryPath)) -cne $absolutePath) {
            throw "$Label does not bind raw held bytes to its immutable HEAD repository blob."
        }
    }
    else {
        $validExternal = ($id -ceq 'godot:console' -and $scope -ceq 'pinned_engine') -or
            ($id -ceq 'godot:runtime' -and $scope -ceq 'pinned_engine') -or
            ($id -ceq 'powershell:host' -and $scope -ceq 'process_host')
        $expectedExternalPath = switch ($id) {
            'godot:console' { [IO.Path]::GetFullPath($GodotBin) }
            'godot:runtime' { [IO.Path]::GetFullPath($GodotRuntimeBin) }
            'powershell:host' { [IO.Path]::GetFullPath([Diagnostics.Process]::GetCurrentProcess().MainModule.FileName) }
            default { '' }
        }
        if (-not $validExternal -or $repositoryPath.Length -ne 0 -or
            $expectedMode.Length -ne 0 -or $expectedBlob.Length -ne 0 -or
            -not $absolutePath.Equals($expectedExternalPath, [StringComparison]::OrdinalIgnoreCase)) {
            throw "$Label has an invalid exact external-input identity."
        }
    }

    if ($Phase -ceq 'final') {
        $postHash = Get-ExactValueNoEnumerate $Row @('post_sha256') $null
        $stable = Get-ExactValueNoEnumerate $Row @('stable') $null
        if ($postHash -isnot [string] -or $postHash -cnotmatch '^[a-f0-9]{64}$' -or
            $postHash -cne $preHash -or $stable -isnot [bool] -or -not $stable) {
            throw "$Label does not prove exact stable pre/post bytes."
        }
    }
}


function Assert-SourceCustodyRowMatches {
    param(
        [Parameter(Mandatory = $true)]$ExpectedRow,
        [Parameter(Mandatory = $true)]$ObservedRow,
        [Parameter(Mandatory = $true)][ValidateSet('in_memory', 'json')][string]$ExpectedRepresentation,
        [Parameter(Mandatory = $true)][ValidateSet('in_memory', 'json')][string]$ObservedRepresentation,
        [Parameter(Mandatory = $true)][string]$Label
    )
    foreach ($name in @(
        'id', 'scope', 'repository_path', 'absolute_path', 'expected_git_mode',
        'expected_git_blob', 'byte_length', 'raw_git_blob', 'pre_sha256'
    )) {
        $expectedValue = Get-ExactValueNoEnumerate $ExpectedRow @($name) $null
        $observedValue = Get-ExactValueNoEnumerate $ObservedRow @($name) $null
        if ($name -ceq 'byte_length') {
            $expectedTypeValid = if ($ExpectedRepresentation -ceq 'in_memory') {
                $expectedValue -is [int64]
            }
            else { $expectedValue -is [int32] -or $expectedValue -is [int64] }
            $observedTypeValid = if ($ObservedRepresentation -ceq 'in_memory') {
                $observedValue -is [int64]
            }
            else { $observedValue -is [int32] -or $observedValue -is [int64] }
            if (-not $expectedTypeValid -or -not $observedTypeValid -or
                [int64]$observedValue -ne [int64]$expectedValue) {
                throw "$Label differs at exact field '$name'."
            }
        }
        elseif ($expectedValue -isnot [string] -or $observedValue -isnot [string] -or
            $observedValue -cne $expectedValue) {
            throw "$Label differs at exact field '$name'."
        }
    }
}


function Assert-SourceCustodyReceiptSchema {
    param(
        [Parameter(Mandatory = $true)]$Receipt,
        [Parameter(Mandatory = $true)][ValidateSet('pre', 'final')][string]$Phase,
        [Parameter(Mandatory = $true)][ValidateSet('in_memory', 'json')][string]$Representation,
        [AllowNull()]$PreReceipt,
        [Parameter(Mandatory = $true)][string]$Label
    )
    $expectedProperties = if ($Phase -ceq 'pre') {
        @('schema_version', 'check_id', 'expected_head', 'expected_tree', 'file_share', 'input_count', 'inputs')
    }
    else {
        @(
            'schema_version', 'check_id', 'expected_head', 'expected_tree', 'pre_receipt',
            'pre_receipt_sha256', 'file_share', 'input_count', 'inputs', 'custody_complete'
        )
    }
    Assert-LocalExactPropertyNames -InputObject $Receipt -Expected $expectedProperties -Label $Label
    $schemaVersion = Get-ExactValueNoEnumerate $Receipt @('schema_version') $null
    $checkId = Get-ExactValueNoEnumerate $Receipt @('check_id') $null
    $expectedHead = Get-ExactValueNoEnumerate $Receipt @('expected_head') $null
    $expectedTree = Get-ExactValueNoEnumerate $Receipt @('expected_tree') $null
    $fileShare = Get-ExactValueNoEnumerate $Receipt @('file_share') $null
    $inputCount = Get-ExactValueNoEnumerate $Receipt @('input_count') $null
    $inputs = Get-ExactValueNoEnumerate $Receipt @('inputs') $null
    $expectedCheckId = if ($Phase -ceq 'pre') { 'rw06_2_source_custody_pre' } else { 'rw06_2_source_custody_final' }
    if ($schemaVersion -isnot [int32] -or $schemaVersion -ne 1 -or
        $checkId -isnot [string] -or $checkId -cne $expectedCheckId -or
        $expectedHead -isnot [string] -or $expectedHead -cne $ExpectedHead.ToLowerInvariant() -or
        $expectedTree -isnot [string] -or $expectedTree -cne $ExpectedTree.ToLowerInvariant() -or
        $fileShare -isnot [string] -or $fileShare -cne 'Read' -or
        $inputCount -isnot [int32] -or [int]$inputCount -le 0 -or
        $inputs -isnot [object[]] -or $inputs.Count -ne [int]$inputCount -or
        $inputs.Count -ne $script:SourceCustodyRows.Count) {
        throw "$Label has an invalid exact receipt schema or identity."
    }

    $seenIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $seenPaths = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $preInputs = $null
    if ($Phase -ceq 'final') {
        if (-not (Test-ExactPsCustomObject -Value $PreReceipt)) {
            throw "$Label has no exact pre-execution receipt to cross-compare."
        }
        Assert-SourceCustodyReceiptSchema -Receipt $PreReceipt -Phase pre -Representation json -Label "$Label pre-execution receipt"
        $preInputs = Get-ExactValueNoEnumerate $PreReceipt @('inputs') $null
        $preReceiptPath = Get-ExactValueNoEnumerate $Receipt @('pre_receipt') $null
        $preReceiptHash = Get-ExactValueNoEnumerate $Receipt @('pre_receipt_sha256') $null
        $custodyComplete = Get-ExactValueNoEnumerate $Receipt @('custody_complete') $null
        if ($preReceiptPath -isnot [string] -or $preReceiptPath -cne $SourceCustodyPrePath -or
            $preReceiptHash -isnot [string] -or $preReceiptHash -cnotmatch '^[a-f0-9]{64}$' -or
            $preReceiptHash -cne $script:SourceCustodyPreSha256 -or
            $custodyComplete -isnot [bool] -or -not $custodyComplete) {
            throw "$Label does not exactly bind its pre-execution receipt or completion state."
        }
    }

    for ($index = 0; $index -lt $inputs.Count; $index++) {
        $row = $inputs[$index]
        Assert-SourceCustodyRowSchema -Row $row -Phase $Phase -Representation $Representation -Label "$Label input $index"
        $rowId = Get-ExactValueNoEnumerate $row @('id') $null
        $rowPath = Get-ExactValueNoEnumerate $row @('absolute_path') $null
        if (-not $seenIds.Add($rowId) -or -not $seenPaths.Add($rowPath)) {
            throw "$Label contains a duplicate input id or absolute path."
        }
        Assert-SourceCustodyRowMatches `
            -ExpectedRow $script:SourceCustodyRows[$index] `
            -ObservedRow $row `
            -ExpectedRepresentation in_memory `
            -ObservedRepresentation $Representation `
            -Label "$Label input $index versus held source"
        if ($Phase -ceq 'final') {
            Assert-SourceCustodyRowMatches `
                -ExpectedRow $preInputs[$index] `
                -ObservedRow $row `
                -ExpectedRepresentation json `
                -ObservedRepresentation $Representation `
                -Label "$Label input $index versus pre-execution receipt"
        }
    }
}


function Assert-RepositoryBlobIdentity {
    $repositoryRows = @($script:SourceCustodyRows | Where-Object {
        $scope = Get-ExactValueNoEnumerate $_ @('scope') $null
        $scope -is [string] -and $scope -ceq 'repository_tracked_production_tree'
    })
    if ($repositoryRows.Count -eq 0) {
        throw 'Source custody has no immutable HEAD repository rows.'
    }
    foreach ($row in $repositoryRows) {
        $expectedBlob = Get-ExactValueNoEnumerate $row @('expected_git_blob') $null
        $rawBlob = Get-ExactValueNoEnumerate $row @('raw_git_blob') $null
        if ($expectedBlob -isnot [string] -or $expectedBlob -cnotmatch '^[a-f0-9]{40}$' -or
            $rawBlob -isnot [string] -or $rawBlob -cnotmatch '^[a-f0-9]{40}$' -or
            $rawBlob -cne $expectedBlob) {
            throw "Raw held worktree bytes do not match immutable HEAD blob: $($row.repository_path)"
        }
    }
}


function Get-ValidatedReplayToolPath {
    $expectedRepositoryPath = 'tools/rw06_2_ending_replay.ps1'
    $expectedReplayPath = [IO.Path]::GetFullPath(
        [IO.Path]::Combine($PSScriptRoot, 'rw06_2_ending_replay.ps1')
    )
    if (-not [IO.File]::Exists($expectedReplayPath)) {
        throw 'The exact checked-in replay tool is missing.'
    }
    $rows = @($script:SourceCustodyRows | Where-Object {
        $id = Get-ExactValueNoEnumerate $_ @('id') $null
        $id -is [string] -and $id -ceq "repository:$expectedRepositoryPath"
    })
    if ($rows.Count -ne 1) {
        throw 'Source custody does not contain exactly one executed replay-tool row.'
    }
    $row = $rows[0]
    Assert-SourceCustodyRowSchema -Row $row -Phase pre -Representation in_memory -Label 'Executed replay-tool custody row'
    $scope = Get-ExactValueNoEnumerate $row @('scope') $null
    $repositoryPath = Get-ExactValueNoEnumerate $row @('repository_path') $null
    $absolutePath = Get-ExactValueNoEnumerate $row @('absolute_path') $null
    $expectedBlob = Get-ExactValueNoEnumerate $row @('expected_git_blob') $null
    $rawBlob = Get-ExactValueNoEnumerate $row @('raw_git_blob') $null
    if ($scope -isnot [string] -or $scope -cne 'repository_tracked_production_tree' -or
        $repositoryPath -isnot [string] -or $repositoryPath -cne $expectedRepositoryPath -or
        $absolutePath -isnot [string] -or
        -not $absolutePath.Equals($expectedReplayPath, [StringComparison]::OrdinalIgnoreCase) -or
        $expectedBlob -isnot [string] -or $expectedBlob -cnotmatch '^[a-f0-9]{40}$' -or
        $rawBlob -isnot [string] -or $rawBlob -cnotmatch '^[a-f0-9]{40}$' -or
        $rawBlob -cne $expectedBlob) {
        throw 'Executed replay tool is not bound to one held immutable-HEAD source row.'
    }
    return $expectedReplayPath
}


function Assert-SourceCustody {
    if ($script:SourceCustodyRows.Count -eq 0 -or
        $script:SourceCustodyStreams.Count -ne $script:SourceCustodyRows.Count) {
        throw 'Source custody is absent or incomplete.'
    }
    for ($index = 0; $index -lt $script:SourceCustodyRows.Count; $index++) {
        $row = $script:SourceCustodyRows[$index]
        $stream = $script:SourceCustodyStreams[$index]
        Assert-SourceCustodyRowSchema -Row $row -Phase pre -Representation in_memory -Label "Held source custody row $index"
        if ($null -eq $stream -or -not $stream.CanRead) {
            throw "Source custody handle is not readable: $($row.id)"
        }
        $path = Get-ExactValueNoEnumerate $row @('absolute_path') $null
        $preHash = Get-ExactValueNoEnumerate $row @('pre_sha256') $null
        $byteLength = Get-ExactValueNoEnumerate $row @('byte_length') $null
        $scope = Get-ExactValueNoEnumerate $row @('scope') $null
        $expectedBlob = Get-ExactValueNoEnumerate $row @('expected_git_blob') $null
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "Source custody path is no longer one file: $($row.id)"
        }
        $digests = Get-HeldFileDigests -Stream $stream
        if ([int64]$digests.byte_length -ne [int64]$byteLength -or
            $digests.sha256 -cne $preHash -or
            $digests.raw_git_blob -cne $row.raw_git_blob -or
            ($scope -ceq 'repository_tracked_production_tree' -and
                $digests.raw_git_blob -cne $expectedBlob)) {
            throw "Custodied source input changed: $($row.id)"
        }
    }
    $heldPreReceipt = $null
    if ($null -ne $script:SourceCustodyPreStream) {
        $preReceiptDigests = Get-HeldFileDigests -Stream $script:SourceCustodyPreStream
        if (-not $script:SourceCustodyPreStream.CanRead -or
            $preReceiptDigests.sha256 -cne $script:SourceCustodyPreSha256) {
            throw 'Source custody pre-execution receipt changed while held.'
        }
        $heldPreReceipt = ConvertFrom-ExactJsonObjectText `
            -Json (Get-HeldUtf8Text -Stream $script:SourceCustodyPreStream) `
            -Label 'Held source custody pre-execution receipt'
        Assert-SourceCustodyReceiptSchema `
            -Receipt $heldPreReceipt `
            -Phase pre `
            -Representation json `
            -Label 'Held source custody pre-execution receipt'
    }
    if ($null -ne $script:SourceCustodyFinalStream) {
        $finalReceiptDigests = Get-HeldFileDigests -Stream $script:SourceCustodyFinalStream
        if (-not $script:SourceCustodyFinalStream.CanRead -or
            $finalReceiptDigests.sha256 -cne $script:SourceCustodyFinalSha256) {
            throw 'Source custody final receipt changed while held.'
        }
        $heldFinalReceipt = ConvertFrom-ExactJsonObjectText `
            -Json (Get-HeldUtf8Text -Stream $script:SourceCustodyFinalStream) `
            -Label 'Held source custody final receipt'
        Assert-SourceCustodyReceiptSchema `
            -Receipt $heldFinalReceipt `
            -Phase final `
            -Representation json `
            -PreReceipt $heldPreReceipt `
            -Label 'Held source custody final receipt'
    }
}


function Open-SourceCustodyHandle {
    param([Parameter(Mandatory = $true)][string]$Path)
    return [IO.File]::Open(
        $Path,
        [IO.FileMode]::Open,
        [IO.FileAccess]::Read,
        [IO.FileShare]::Read
    )
}


function New-SourceCustody {
    if ($script:SourceCustodyRows.Count -ne 0 -or $script:SourceCustodyStreams.Count -ne 0) {
        throw 'Source custody cannot be acquired twice.'
    }
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    try {
        foreach ($descriptor in @(Get-TrackedSourceDescriptors)) {
            $path = Get-ExactValueNoEnumerate $descriptor @('absolute_path') $null
            if ($path -isnot [string] -or -not $seen.Add($path)) {
                throw "Source custody input path is invalid or duplicated: $path"
            }
            if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
                throw "Required source custody input is missing: $path"
            }
            $stream = Open-SourceCustodyHandle -Path $path
            $script:SourceCustodyStreams.Add($stream)
            $digests = Get-HeldFileDigests -Stream $stream
            $script:SourceCustodyRows.Add([pscustomobject][ordered]@{
                id = [string]$descriptor.id
                scope = [string]$descriptor.scope
                repository_path = [string]$descriptor.repository_path
                absolute_path = $path
                expected_git_mode = [string]$descriptor.expected_git_mode
                expected_git_blob = [string]$descriptor.expected_git_blob
                byte_length = [int64]$digests.byte_length
                raw_git_blob = [string]$digests.raw_git_blob
                pre_sha256 = [string]$digests.sha256
            })
        }
        Assert-RepositoryBlobIdentity
        Assert-SourceCustody
        $preReceipt = [pscustomobject][ordered]@{
            schema_version = 1
            check_id = 'rw06_2_source_custody_pre'
            expected_head = $ExpectedHead.ToLowerInvariant()
            expected_tree = $ExpectedTree.ToLowerInvariant()
            file_share = 'Read'
            input_count = $script:SourceCustodyRows.Count
            inputs = @($script:SourceCustodyRows)
        }
        Assert-SourceCustodyReceiptSchema `
            -Receipt $preReceipt `
            -Phase pre `
            -Representation in_memory `
            -Label 'In-memory source custody pre-execution receipt'
        $lockedPreReceipt = New-LockedJsonReceipt -Path $SourceCustodyPrePath -Receipt $preReceipt -Label 'Source custody pre-execution receipt'
        $script:SourceCustodyPreStream = $lockedPreReceipt.stream
        $script:SourceCustodyPreSha256 = [string]$lockedPreReceipt.sha256
        Assert-SourceCustody
    }
    catch {
        if ($null -ne $script:SourceCustodyPreStream) {
            $script:SourceCustodyPreStream.Dispose()
            $script:SourceCustodyPreStream = $null
        }
        if ($null -ne $script:SourceCustodyFinalStream) {
            $script:SourceCustodyFinalStream.Dispose()
            $script:SourceCustodyFinalStream = $null
        }
        foreach ($stream in @($script:SourceCustodyStreams)) {
            try { $stream.Dispose() } catch {}
        }
        $script:SourceCustodyStreams.Clear()
        $script:SourceCustodyRows.Clear()
        throw
    }
}


function Complete-SourceCustody {
    Assert-SourceCustody
    $completedRows = [Collections.Generic.List[object]]::new()
    for ($index = 0; $index -lt $script:SourceCustodyRows.Count; $index++) {
        $row = $script:SourceCustodyRows[$index]
        $postDigests = Get-HeldFileDigests -Stream $script:SourceCustodyStreams[$index]
        if ($postDigests.sha256 -cne $row.pre_sha256 -or
            [int64]$postDigests.byte_length -ne [int64]$row.byte_length) {
            throw "Custodied source input changed before final receipt: $($row.id)"
        }
        $completedRows.Add([pscustomobject][ordered]@{
            id = $row.id
            scope = $row.scope
            repository_path = $row.repository_path
            absolute_path = $row.absolute_path
            expected_git_mode = $row.expected_git_mode
            expected_git_blob = $row.expected_git_blob
            byte_length = $row.byte_length
            raw_git_blob = $row.raw_git_blob
            pre_sha256 = $row.pre_sha256
            post_sha256 = [string]$postDigests.sha256
            stable = $true
        })
    }
    $finalReceipt = [pscustomobject][ordered]@{
        schema_version = 1
        check_id = 'rw06_2_source_custody_final'
        expected_head = $ExpectedHead.ToLowerInvariant()
        expected_tree = $ExpectedTree.ToLowerInvariant()
        pre_receipt = $SourceCustodyPrePath
        pre_receipt_sha256 = $script:SourceCustodyPreSha256
        file_share = 'Read'
        input_count = $completedRows.Count
        inputs = @($completedRows)
        custody_complete = $true
    }
    $heldPreReceipt = ConvertFrom-ExactJsonObjectText `
        -Json (Get-HeldUtf8Text -Stream $script:SourceCustodyPreStream) `
        -Label 'Held source custody pre-execution receipt before completion'
    Assert-SourceCustodyReceiptSchema `
        -Receipt $finalReceipt `
        -Phase final `
        -Representation in_memory `
        -PreReceipt $heldPreReceipt `
        -Label 'In-memory source custody final receipt'
    $lockedFinalReceipt = New-LockedJsonReceipt -Path $SourceCustodyFinalPath -Receipt $finalReceipt -Label 'Source custody final receipt'
    $script:SourceCustodyFinalStream = $lockedFinalReceipt.stream
    $script:SourceCustodyFinalSha256 = [string]$lockedFinalReceipt.sha256
    $script:SourceCustodyComplete = $true
    Assert-SourceCustody
}


function Close-SourceCustody {
    if ($null -ne $script:SourceCustodyPreStream) {
        $script:SourceCustodyPreStream.Dispose()
        $script:SourceCustodyPreStream = $null
    }
    if ($null -ne $script:SourceCustodyFinalStream) {
        $script:SourceCustodyFinalStream.Dispose()
        $script:SourceCustodyFinalStream = $null
    }
    foreach ($stream in @($script:EvidenceArtifactStreams)) {
        try { $stream.Dispose() } catch {}
    }
    $script:EvidenceArtifactStreams.Clear()
    foreach ($stream in @($script:SourceCustodyStreams)) {
        try { $stream.Dispose() } catch {}
    }
    $script:SourceCustodyStreams.Clear()
}


function Assert-RepositoryIdentity {
    $head = Get-GitValue -Revision 'HEAD'
    $tree = Get-GitValue -Revision 'HEAD^{tree}'
    if ($head -cne $ExpectedHead.ToLowerInvariant()) {
        throw "HEAD changed: expected $ExpectedHead, observed $head."
    }
    if ($tree -cne $ExpectedTree.ToLowerInvariant()) {
        throw "Tree changed: expected $ExpectedTree, observed $tree."
    }
    $dirty = @(& git -C $Worktree status --porcelain --untracked-files=all)
    if ($LASTEXITCODE -ne 0) {
        throw 'Could not inspect implementation worktree status.'
    }
    if ($dirty.Count -ne 0) {
        throw "Implementation worktree is not clean: $($dirty -join ' | ')"
    }
}


function Get-GodotProcesses {
    return @(Get-CimInstance Win32_Process | Where-Object { $_.Name -match '^Godot.*\.exe$' })
}


function Get-ProcessCensus {
    return @(Get-GodotProcesses | ForEach-Object {
        [ordered]@{
            pid = [int]$_.ProcessId
            parent_pid = [int]$_.ParentProcessId
            name = [string]$_.Name
            command_line = [string]$_.CommandLine
        }
    })
}


function Get-LeaseOwnerPids {
    param([Parameter(Mandatory = $true)][IO.FileInfo]$Lease)
    if ($Lease.Name -ceq 'EXCLUSIVE.lease') {
        try {
            $record = Microsoft.PowerShell.Management\Get-Content -Raw -LiteralPath $Lease.FullName -Encoding utf8 | Microsoft.PowerShell.Utility\ConvertFrom-Json
            $ownerPid = Get-ExactPositivePid -InputObject $record -Name 'pid'
            $guardPids = @(Get-ExactPidArray -InputObject $record -Name 'guard_pids')
        }
        catch {
            throw "Could not read exclusive lease owner from $($Lease.FullName): $($_.Exception.Message)"
        }
        if ($ownerPid -le 0) {
            throw "Exclusive lease has no valid owner PID: $($Lease.FullName)"
        }
        $allPids = @($ownerPid) + @($guardPids | Where-Object { $_ -gt 0 })
        return @($allPids | Sort-Object -Unique)
    }
    if ($Lease.Name -notmatch '(\d+)\.lease$') {
        throw "Normal lease has no owner PID: $($Lease.FullName)"
    }
    return @([int]$matches[1])
}


function Clear-StaleGodotLeases {
    foreach ($lease in @(Get-ChildItem -LiteralPath $LeaseRoot -Filter '*.lease' -File -ErrorAction Stop)) {
        $ownerPids = @(Get-LeaseOwnerPids -Lease $lease)
        $liveOwnerPids = @($ownerPids | Where-Object { $null -ne (Get-Process -Id $_ -ErrorAction SilentlyContinue) })
        if ($liveOwnerPids.Count -ne 0) {
            continue
        }
        $leasePrefix = ([IO.Path]::GetFullPath($LeaseRoot)).TrimEnd('\') + '\'
        $resolvedLease = [IO.Path]::GetFullPath($lease.FullName)
        if (-not $resolvedLease.StartsWith($leasePrefix, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Refusing to clear lease outside lease root: $resolvedLease"
        }
        Remove-Item -LiteralPath $resolvedLease -Force
    }
}


function Clear-StaleExclusiveLease {
    if (-not (Test-Path -LiteralPath $LeasePath -PathType Leaf)) { return }
    $lease = Get-Item -LiteralPath $LeasePath
    $ownerPids = @(Get-LeaseOwnerPids -Lease $lease)
    if (@($ownerPids | Where-Object { $null -ne (Get-Process -Id $_ -ErrorAction SilentlyContinue) }).Count -ne 0) {
        return
    }
    Remove-Item -LiteralPath $LeasePath -Force -ErrorAction Stop
}


function Enter-LaunchLock {
    param([ValidateRange(1, 60)][int]$TimeoutSeconds = 60)
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    while ([DateTime]::UtcNow -lt $deadline) {
        try {
            $stream = [IO.FileStream]::new(
                $LaunchLockPath,
                [IO.FileMode]::CreateNew,
                [IO.FileAccess]::ReadWrite,
                [IO.FileShare]::None,
                4096,
                [IO.FileOptions]::DeleteOnClose
            )
            try {
                $body = [Text.Encoding]::UTF8.GetBytes(([ordered]@{
                    pid = $PID
                    agent = 'rw06_2p'
                    kind = 'fixed-repeat-final-evidence-launch-lock'
                    acquired = [DateTimeOffset]::Now.ToString('o')
                } | Microsoft.PowerShell.Utility\ConvertTo-Json -Compress))
                $stream.Write($body, 0, $body.Length)
                $stream.Flush()
                return $stream
            }
            catch {
                $stream.Dispose()
                throw
            }
        }
        catch [IO.IOException] {
            Start-Sleep -Milliseconds 200
        }
    }
    throw 'Timed out acquiring the Q-009 launch lock.'
}


function Exit-LaunchLock {
    param([AllowNull()]$Stream)
    if ($null -ne $Stream) { $Stream.Dispose() }
}


function Test-OwnedExclusiveLease {
    if (-not (Test-Path -LiteralPath $LeasePath -PathType Leaf)) { return $false }
    try {
        $record = Microsoft.PowerShell.Management\Get-Content -Raw -LiteralPath $LeasePath -Encoding utf8 | Microsoft.PowerShell.Utility\ConvertFrom-Json
        $ownerPid = Get-ExactPositivePid -InputObject $record -Name 'pid'
        $kind = Get-ExactValueNoEnumerate $record @('kind') $null
        return $kind -is [string] -and $ownerPid -eq $PID -and
            $kind -ceq 'exclusive-real-input-fixed-repeat-final-evidence'
    }
    catch {
        return $false
    }
}


function Assert-ExclusiveAdmission {
    param([switch]$AllowOwnedLease)
    if (-not $AllowOwnedLease) {
        Clear-StaleExclusiveLease
    }
    else {
        Clear-StaleGodotLeases
    }
    $exclusiveExists = Test-Path -LiteralPath $LeasePath -PathType Leaf
    if (-not $AllowOwnedLease -and $exclusiveExists) {
        throw 'Q-009 EXCLUSIVE lease is active.'
    }
    if (-not $AllowOwnedLease) { return }
    if (-not $exclusiveExists -or -not (Test-OwnedExclusiveLease)) {
        throw 'Owned aggregate EXCLUSIVE lease is missing or has the wrong live owner.'
    }
    $normalLeases = @(Get-ChildItem -LiteralPath $LeaseRoot -Filter '*.lease' -File -ErrorAction Stop | Where-Object { $_.Name -cne 'EXCLUSIVE.lease' })
    if ($normalLeases.Count -ne 0) {
        throw "Q-009 exclusive launch requires drained normal leases; active: $(@($normalLeases.Name) -join ', ')."
    }
    $godotProcesses = @(Get-GodotProcesses)
    if ($godotProcesses.Count -ne 0) {
        throw "Q-009 exclusive launch requires a drained engine census; observed $($godotProcesses.Count) Godot processes."
    }
}


function Assert-OwnedExclusiveReservation {
    Clear-StaleGodotLeases
    if (-not (Test-OwnedExclusiveLease)) {
        throw 'Owned aggregate EXCLUSIVE reservation is missing or has the wrong live owner.'
    }
}


function Wait-ExclusiveDrain {
    $deadline = [DateTime]::UtcNow.AddSeconds($PerRunTimeoutSeconds)
    $lastNormalLeaseNames = @()
    $lastGodotPids = @()
    while ([DateTime]::UtcNow -lt $deadline) {
        $drainLock = $null
        try {
            $drainLock = Enter-LaunchLock -TimeoutSeconds 5
            Assert-OwnedExclusiveReservation
            $normalLeases = @(Get-ChildItem -LiteralPath $LeaseRoot -Filter '*.lease' -File -ErrorAction Stop | Where-Object { $_.Name -cne 'EXCLUSIVE.lease' })
            $godotProcesses = @(Get-GodotProcesses)
            $lastNormalLeaseNames = @($normalLeases.Name)
            $lastGodotPids = @($godotProcesses.ProcessId)
            if ($normalLeases.Count -eq 0 -and $godotProcesses.Count -eq 0) {
                Assert-ExclusiveAdmission -AllowOwnedLease
                return
            }
        }
        finally {
            Exit-LaunchLock -Stream $drainLock
        }
        Start-Sleep -Milliseconds 250
    }
    throw "Timed out after $PerRunTimeoutSeconds seconds draining pre-existing Q-009 lanes while holding the exact EXCLUSIVE reservation; normal_leases=$($lastNormalLeaseNames -join ','); godot_pids=$($lastGodotPids -join ',')."
}


function New-OwnedExclusiveLease {
    $stream = $null
    $created = $false
    try {
        $stream = [IO.File]::Open($LeasePath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
        $created = $true
        $record = [ordered]@{
            pid = $PID
            agent = 'rw06_2p'
            kind = 'exclusive-real-input-fixed-repeat-final-evidence'
            ending = $Ending
            seed = $Seed
            role = 'fixed_route_repeat'
            repeat = 2
            worktree = $Worktree
            head = $ExpectedHead.ToLowerInvariant()
            tree = $ExpectedTree.ToLowerInvariant()
            evidence_root = $EvidenceRoot
            started = $StartedAt.ToString('o')
            guard_pids = @($PID)
        } | Microsoft.PowerShell.Utility\ConvertTo-Json
        $bytes = [Text.Encoding]::UTF8.GetBytes($record)
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Flush($true)
        $stream.Dispose()
        $stream = $null
        if (-not (Test-OwnedExclusiveLease)) {
            throw 'New aggregate EXCLUSIVE lease failed exact owner/content verification.'
        }
    }
    catch {
        $creationFailure = $_
        if ($null -ne $stream) {
            try { $stream.Dispose() } catch { }
            $stream = $null
        }
        if ($created) {
            while (Test-Path -LiteralPath $LeasePath) {
                try { Remove-Item -LiteralPath $LeasePath -Force -ErrorAction Stop }
                catch { Start-Sleep -Milliseconds 200 }
            }
        }
        throw $creationFailure
    }
}


function Get-LiveSurvivorPids {
    param([Parameter(Mandatory = $true)][object[]]$Survivors)
    $livePidList = [Collections.Generic.List[int]]::new()
    foreach ($survivor in $Survivors) {
        $candidatePid = 0
        try { $candidatePid = Get-ExactPositivePid -InputObject $survivor -Name 'pid' }
        catch {
            try { $candidatePid = Get-ExactPositivePid -InputObject $survivor -Name 'ProcessId' }
            catch { $candidatePid = 0 }
        }
        if ($candidatePid -gt 0 -and
            -not $livePidList.Contains($candidatePid) -and
            $null -ne (Get-Process -Id $candidatePid -ErrorAction SilentlyContinue)) {
            $livePidList.Add($candidatePid)
        }
    }
    return @($livePidList)
}


function Test-LauncherCustodyLease {
    if (-not (Test-Path -LiteralPath $LeasePath -PathType Leaf)) { return $false }
    try {
        $record = Microsoft.PowerShell.Management\Get-Content -Raw -LiteralPath $LeasePath -Encoding utf8 | Microsoft.PowerShell.Utility\ConvertFrom-Json
        $kind = Get-ExactValueNoEnumerate $record @('kind') $null
        if ($kind -isnot [string]) { return $false }
        if ($kind -ceq 'exclusive-real-input-fixed-repeat-final-evidence') {
            return (Get-ExactPositivePid -InputObject $record -Name 'pid') -eq $PID
        }
        if ($kind -ceq 'exclusive-survivor-custody') {
            return (Get-ExactPositivePid -InputObject $record -Name 'original_launcher_pid') -eq $PID
        }
        return $false
    }
    catch { return $false }
}


function Test-ExclusiveSurvivorCustody {
    param([Parameter(Mandatory = $true)][int[]]$ExpectedLivePids)
    if ($ExpectedLivePids.Count -eq 0 -or -not (Test-Path -LiteralPath $LeasePath -PathType Leaf)) { return $false }
    try {
        $record = Microsoft.PowerShell.Management\Get-Content -Raw -LiteralPath $LeasePath -Encoding utf8 | Microsoft.PowerShell.Utility\ConvertFrom-Json
        $ownerPid = Get-ExactPositivePid -InputObject $record -Name 'pid'
        $guardPids = @(Get-ExactPidArray -InputObject $record -Name 'guard_pids' | Sort-Object -Unique)
        $expected = @($ExpectedLivePids | Sort-Object -Unique)
        $kind = Get-ExactValueNoEnumerate $record @('kind') $null
        $originalLauncherPid = Get-ExactPositivePid -InputObject $record -Name 'original_launcher_pid'
        if ($kind -isnot [string] -or $kind -cne 'exclusive-survivor-custody' -or
            $originalLauncherPid -ne $PID -or
            $ownerPid -cnotin $expected -or
            $null -eq (Get-Process -Id $ownerPid -ErrorAction SilentlyContinue) -or
            $guardPids.Count -ne $expected.Count) {
            return $false
        }
        for ($index = 0; $index -lt $expected.Count; $index++) {
            if ($guardPids[$index] -ne $expected[$index] -or
                $null -eq (Get-Process -Id $guardPids[$index] -ErrorAction SilentlyContinue)) {
                return $false
            }
        }
        return $true
    }
    catch { return $false }
}


function Set-ExclusiveLeaseSurvivorCustody {
    param([Parameter(Mandatory = $true)][object[]]$Survivors)
    if (-not (Test-OwnedExclusiveLease)) {
        throw 'Cannot transfer EXCLUSIVE lease custody because the launcher no longer owns it.'
    }
    $transferAttempted = $false
    while ($true) {
        $livePids = @(Get-LiveSurvivorPids -Survivors $Survivors)
        if ($livePids.Count -eq 0) {
            if (-not $transferAttempted -and -not (Test-LauncherCustodyLease)) {
                throw 'Survivors exited, but the EXCLUSIVE lease no longer has verifiable launcher custody.'
            }
            while (Test-Path -LiteralPath $LeasePath) {
                try { Remove-Item -LiteralPath $LeasePath -Force -ErrorAction Stop }
                catch { Start-Sleep -Milliseconds 200 }
            }
            return [pscustomobject][ordered]@{ transferred = $false; lease_removed = $true; guard_pids = @() }
        }
        if (-not $transferAttempted -and -not (Test-LauncherCustodyLease)) {
            throw 'EXCLUSIVE lease custody changed before a verified survivor transfer completed.'
        }

        $record = [ordered]@{
            pid = [int]$livePids[0]
            guard_pids = @($livePids)
            original_launcher_pid = $PID
            agent = 'rw06_2p'
            kind = 'exclusive-survivor-custody'
            ending = $Ending
            seed = $Seed
            role = 'fixed_route_repeat'
            worktree = $Worktree
            head = $ExpectedHead.ToLowerInvariant()
            tree = $ExpectedTree.ToLowerInvariant()
            evidence_root = $EvidenceRoot
            started = $StartedAt.ToString('o')
            transferred = [DateTimeOffset]::Now.ToString('o')
        }
        $recordBytes = [Text.Encoding]::UTF8.GetBytes(($record | Microsoft.PowerShell.Utility\ConvertTo-Json -Depth 8))
        $temporaryLeasePath = Join-Path $LeaseRoot (".EXCLUSIVE.$PID.$([Guid]::NewGuid().ToString('N')).tmp")
        $atomicReplaceFailed = $false
        $transferAttempted = $true
        try {
            [IO.File]::WriteAllBytes($temporaryLeasePath, $recordBytes)
            try {
                [IO.File]::Replace($temporaryLeasePath, $LeasePath, $null)
            }
            catch {
                $atomicReplaceFailed = $true
            }
            if ($atomicReplaceFailed) {
                $fallbackStream = $null
                try {
                    $fallbackStream = [IO.File]::Open($LeasePath, [IO.FileMode]::Create, [IO.FileAccess]::Write, [IO.FileShare]::None)
                    $fallbackStream.Write($recordBytes, 0, $recordBytes.Length)
                    $fallbackStream.Flush($true)
                }
                finally {
                    if ($null -ne $fallbackStream) { $fallbackStream.Dispose() }
                }
            }
        }
        catch {
            # Keep the launcher alive and EXCLUSIVE present; retry until transfer verifies or every survivor exits.
        }
        finally {
            if (Test-Path -LiteralPath $temporaryLeasePath -PathType Leaf) {
                Remove-Item -LiteralPath $temporaryLeasePath -Force -ErrorAction SilentlyContinue
            }
        }

        $verifiedLivePids = @(Get-LiveSurvivorPids -Survivors $Survivors)
        if ($verifiedLivePids.Count -eq 0) {
            continue
        }
        if (Test-ExclusiveSurvivorCustody -ExpectedLivePids $verifiedLivePids) {
            return [pscustomobject][ordered]@{
                transferred = $true
                lease_removed = $false
                guard_pids = @($verifiedLivePids)
            }
        }
        Start-Sleep -Milliseconds 200
    }
}


function Get-ExactOwnedReplayProcess {
    param([Parameter(Mandatory = $true)]$Identity)
    $process = Get-Process -Id ([int]$Identity.pid) -ErrorAction SilentlyContinue
    if ($null -eq $process) { return $null }
    try { $observedTicks = $process.StartTime.ToUniversalTime().Ticks }
    catch { return $null }
    if ($observedTicks -ne [long]$Identity.start_utc_ticks) {
        return $null
    }
    return $process
}


function Get-OwnedGodotProcesses {
    $identities = @($script:OwnedReplayIdentities) + @($script:ProvisionalReplayProcesses)
    if ($identities.Count -eq 0) { return @() }
    return @(Get-GodotProcesses | Where-Object {
        $commandLine = [string]$_.CommandLine
        $owned = $false
        foreach ($identity in $identities) {
            if ($commandLine.IndexOf([string]$identity.session_prefix, [StringComparison]::Ordinal) -ge 0 -and
                $commandLine.IndexOf('--path', [StringComparison]::Ordinal) -ge 0 -and
                $commandLine.IndexOf($Worktree, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
                $owned = $true
                break
            }
        }
        $owned
    })
}


function Stop-UnregisteredReplayProcess {
    param(
        [Parameter(Mandatory = $true)][Diagnostics.Process]$Process,
        [Parameter(Mandatory = $true)][string]$SessionPrefix
    )
    $cleanupFailures = [Collections.Generic.List[string]]::new()
    try {
        if (-not $Process.HasExited) {
            $descendants = @(Get-DescendantProcessIds -RootPid ([int]$Process.Id))
            [Array]::Reverse($descendants)
            foreach ($childPid in $descendants) {
                Stop-Process -Id $childPid -Force -ErrorAction SilentlyContinue
            }
            $Process.Kill()
            if (-not $Process.WaitForExit(15000)) {
                $cleanupFailures.Add("Replay PID $($Process.Id) did not exit after exact process-tree termination.")
            }
        }
    }
    catch {
        try { $alreadyExited = $Process.HasExited } catch { $alreadyExited = $false }
        if (-not $alreadyExited) {
            $cleanupFailures.Add("Could not terminate unregistered replay PID $($Process.Id): $($_.Exception.Message)")
        }
    }

    $matchingGodot = @(Get-GodotProcesses | Where-Object {
        $commandLine = [string]$_.CommandLine
        $commandLine.IndexOf($SessionPrefix, [StringComparison]::Ordinal) -ge 0 -and
            $commandLine.IndexOf('--path', [StringComparison]::Ordinal) -ge 0 -and
            $commandLine.IndexOf($Worktree, [StringComparison]::OrdinalIgnoreCase) -ge 0
    })
    foreach ($ownedGodot in $matchingGodot) {
        Stop-Process -Id ([int]$ownedGodot.ProcessId) -Force -ErrorAction SilentlyContinue
    }
    $remainingGodot = @(Get-GodotProcesses | Where-Object {
        $commandLine = [string]$_.CommandLine
        $commandLine.IndexOf($SessionPrefix, [StringComparison]::Ordinal) -ge 0 -and
            $commandLine.IndexOf('--path', [StringComparison]::Ordinal) -ge 0 -and
            $commandLine.IndexOf($Worktree, [StringComparison]::OrdinalIgnoreCase) -ge 0
    })
    if ($remainingGodot.Count -ne 0) {
        $cleanupFailures.Add("Unregistered replay left owned Godot PIDs: $(@($remainingGodot.ProcessId) -join ',').")
    }
    if ($cleanupFailures.Count -ne 0) {
        throw ($cleanupFailures -join ' | ')
    }
}


function Get-DescendantProcessIds {
    param([Parameter(Mandatory = $true)][int]$RootPid)
    $all = @(Get-CimInstance Win32_Process)
    $result = [Collections.Generic.List[int]]::new()
    $frontier = [Collections.Generic.Queue[int]]::new()
    $frontier.Enqueue($RootPid)
    while ($frontier.Count -gt 0) {
        $parentPid = $frontier.Dequeue()
        foreach ($process in @($all | Where-Object { [int]$_.ParentProcessId -eq $parentPid })) {
            $childPid = [int]$process.ProcessId
            if ($result.Contains($childPid)) { continue }
            $result.Add($childPid)
            $frontier.Enqueue($childPid)
        }
    }
    return @($result)
}


function Stop-OwnedReplayIdentity {
    param([Parameter(Mandatory = $true)]$Identity)
    $process = Get-ExactOwnedReplayProcess -Identity $Identity
    if ($null -ne $process) {
        $descendants = @(Get-DescendantProcessIds -RootPid ([int]$Identity.pid))
        [Array]::Reverse($descendants)
        foreach ($childPid in $descendants) {
            Stop-Process -Id $childPid -Force -ErrorAction SilentlyContinue
        }
        Stop-Process -Id ([int]$Identity.pid) -Force -ErrorAction SilentlyContinue
    }
    foreach ($ownedGodot in @(Get-OwnedGodotProcesses)) {
        Stop-Process -Id ([int]$ownedGodot.ProcessId) -Force -ErrorAction SilentlyContinue
    }
}


function Stop-AllOwnedProcesses {
    foreach ($provisional in @($script:ProvisionalReplayProcesses)) {
        Stop-UnregisteredReplayProcess -Process $provisional.process -SessionPrefix ([string]$provisional.session_prefix)
        $null = $script:ProvisionalReplayProcesses.Remove($provisional)
    }
    foreach ($identity in @($script:OwnedReplayIdentities)) {
        Stop-OwnedReplayIdentity -Identity $identity
    }
    $deadline = [DateTime]::UtcNow.AddSeconds(15)
    do {
        $registeredReplayAlive = @($script:OwnedReplayIdentities | Where-Object {
            $null -ne (Get-Process -Id ([int]$_.pid) -ErrorAction SilentlyContinue)
        }).Count -gt 0
        $provisionalReplayAlive = @($script:ProvisionalReplayProcesses | Where-Object {
            try { -not $_.process.HasExited } catch { $true }
        }).Count -gt 0
        $godotAlive = @(Get-OwnedGodotProcesses).Count -gt 0
        if (-not $registeredReplayAlive -and -not $provisionalReplayAlive -and -not $godotAlive) { return }
        Start-Sleep -Milliseconds 200
    } while ([DateTime]::UtcNow -lt $deadline)
    throw 'Owned fixed-repeat process cleanup did not finish within 15 seconds.'
}


function Get-OwnedSurvivors {
    $replay = @($script:OwnedReplayIdentities | ForEach-Object {
        $identity = $_
        $exact = Get-ExactOwnedReplayProcess -Identity $identity
        if ($null -ne $exact) {
            [ordered]@{ kind = 'replay'; pid = [int]$identity.pid; session_prefix = [string]$identity.session_prefix }
        }
        elseif ($null -ne (Get-Process -Id ([int]$identity.pid) -ErrorAction SilentlyContinue)) {
            [ordered]@{ kind = 'unverified_replay_pid'; pid = [int]$identity.pid; session_prefix = [string]$identity.session_prefix }
        }
    })
    $provisional = @($script:ProvisionalReplayProcesses | Where-Object {
        try { -not $_.process.HasExited } catch { $true }
    } | ForEach-Object {
        [ordered]@{ kind = 'unregistered_replay'; pid = [int]$_.pid; session_prefix = [string]$_.session_prefix }
    })
    $godot = @(Get-OwnedGodotProcesses | ForEach-Object {
        [ordered]@{ kind = 'godot'; pid = [int]$_.ProcessId; command_line = [string]$_.CommandLine }
    })
    return @($replay + $provisional + $godot)
}


function Restore-ProcessEnvironmentValue {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [AllowNull()][string]$Value
    )
    if ($null -eq $Value) {
        Remove-Item -LiteralPath "Env:$Name" -ErrorAction SilentlyContinue
    }
    else {
        Set-Item -LiteralPath "Env:$Name" -Value $Value
    }
}


function Assert-ExactPublishedPath {
    param(
        [Parameter(Mandatory = $true)]$PublishedPath,
        [Parameter(Mandatory = $true)][string]$ExpectedPath,
        [Parameter(Mandatory = $true)][string]$Label
    )
    if ($PublishedPath -isnot [string] -or
        [string]::IsNullOrWhiteSpace($PublishedPath) -or
        -not [IO.Path]::IsPathRooted($PublishedPath)) {
        throw "$Label is missing or is not an absolute path."
    }
    $publishedFullPath = [IO.Path]::GetFullPath($PublishedPath)
    $expectedFullPath = [IO.Path]::GetFullPath($ExpectedPath)
    if (-not $publishedFullPath.Equals($expectedFullPath, [StringComparison]::OrdinalIgnoreCase)) {
        throw "$Label escaped its exact expected evidence file: expected $expectedFullPath, observed $publishedFullPath."
    }
}


function Resolve-ExactSessionRoot {
    param([Parameter(Mandatory = $true)][string]$Session)
    $base = Join-Path $Worktree '.tmp\agent_playtest'
    $matches = [Collections.Generic.List[string]]::new()
    foreach ($dateRoot in @(Get-ChildItem -LiteralPath $base -Directory -ErrorAction Stop)) {
        $candidate = Join-Path $dateRoot.FullName $Session
        if (Test-Path -LiteralPath $candidate -PathType Container) {
            $matches.Add([IO.Path]::GetFullPath($candidate))
        }
    }
    if ($matches.Count -ne 1) {
        throw "Expected one exact session root for '$Session', found $($matches.Count)."
    }
    $basePrefix = ([IO.Path]::GetFullPath($base)).TrimEnd('\') + '\'
    if (-not $matches[0].StartsWith($basePrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Resolved session root escaped the agent-playtest evidence root: $($matches[0])"
    }
    return $matches[0]
}


function Assert-StrictSessionLogs {
    param([Parameter(Mandatory = $true)][string]$SessionRoot)
    $hashes = [ordered]@{}
    foreach ($name in @('godot.stdout.log', 'godot.stderr.log', 'godot.engine.log')) {
        $path = Join-Path $SessionRoot $name
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "Retained final session log is missing: $path"
        }
        $issues = @(Microsoft.PowerShell.Management\Get-Content -LiteralPath $path -Encoding utf8 | Where-Object {
            $_ -match 'SCRIPT ERROR|(^|\s)ERROR[: ]|(^|\s)WARNING[: ]'
        })
        if ($issues.Count -ne 0) {
            throw "Retained final session log contains failing diagnostics: $name`: $($issues -join ' | ')"
        }
        $hashes[$name] = Get-Sha256 -Path $path
    }
    return [pscustomobject]$hashes
}


function Assert-RetainedHeistPreflightArtifact {
    param(
        [Parameter(Mandatory = $true)][int]$RunIndex,
        [Parameter(Mandatory = $true)][string]$InvocationRoot,
        [Parameter(Mandatory = $true)]$InvocationPreflight,
        [Parameter(Mandatory = $true)]$RunPreflight
    )
    $path = Join-Path $InvocationRoot 'heist_seed_preflight.json'
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Run $RunIndex did not retain its Heist seed preflight file."
    }
    if (-not (Test-ExactPsCustomObject -Value $InvocationPreflight) -or
        -not (Test-ExactPsCustomObject -Value $RunPreflight)) {
        throw "Run $RunIndex Heist seed preflight embeddings are not exact objects."
    }
    $stream = Open-SourceCustodyHandle -Path $path
    $script:EvidenceArtifactStreams.Add($stream)
    $item = Get-Item -LiteralPath $path
    if ($item.Length -le 0 -or
        ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Run $RunIndex retained Heist seed preflight is empty or is a reparse point."
    }
    $digests = Get-HeldFileDigests -Stream $stream
    $retained = ConvertFrom-ExactJsonObjectText `
        -Json (Get-HeldUtf8Text -Stream $stream) `
        -Label "Run $RunIndex retained Heist seed preflight"
    $passed = Get-ExactValueNoEnumerate $retained @('passed') $null
    $seed = Get-ExactValueNoEnumerate $retained @('selection', 'seed_text') $null
    $scenario = Get-ExactValueNoEnumerate $retained @('selection', 'selected_scenario') $null
    if ($passed -isnot [bool] -or -not [bool]$passed -or
        $seed -isnot [string] -or $seed -cne 'RW06-HEIST-AUDIT-0002' -or
        $scenario -isnot [string] -or $scenario -cne 'grand_casino_audit_night') {
        throw "Run $RunIndex retained Heist seed preflight has invalid exact witness fields."
    }
    $retainedJson = ConvertTo-CanonicalExactObjectJson -InputObject $retained -Label "Run $RunIndex retained Heist preflight"
    if ($retainedJson -cne (ConvertTo-CanonicalExactObjectJson -InputObject $InvocationPreflight -Label "Run $RunIndex invocation Heist preflight") -or
        $retainedJson -cne (ConvertTo-CanonicalExactObjectJson -InputObject $RunPreflight -Label "Run $RunIndex iteration Heist preflight")) {
        throw "Run $RunIndex retained Heist seed preflight differs from its invocation or run summary object."
    }
    return [pscustomobject][ordered]@{
        path = [IO.Path]::GetFullPath($path)
        sha256 = [string]$digests.sha256
        report = $retained
    }
}


function Assert-OneRunJsonShapes {
    param(
        [Parameter(Mandatory = $true)]$Summary,
        [Parameter(Mandatory = $true)]$Run,
        [Parameter(Mandatory = $true)][string]$Label
    )
    if (-not (Test-ExactPsCustomObject -Value $Summary) -or
        -not (Test-ExactPsCustomObject -Value $Run)) {
        throw "$Label summary and run must each be one exact object."
    }
    $summaryPropertyNames = @(
        'schema_version', 'check_id', 'role', 'requested_evidence_role',
        'repeat_profile_scope', 'fixed_repeat_qualification_authority', 'ending', 'seed',
        'observed_terminal_seeds', 'repeat', 'deterministic', 'checkpoint_evidence_complete',
        'release_qualifying', 'qualification', 'replay_admission',
        'public_observation_schema', 'public_observation_schema_version',
        'heist_seed_preflight', 'heist_preflight_admission', 'evidence_root', 'runs'
    )
    $runPropertyNames = @(
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
    Assert-Rw062ExactPropertyNames -InputObject $Summary -Expected $summaryPropertyNames -Label "$Label summary"
    Assert-Rw062ExactPropertyNames -InputObject $Run -Expected $runPropertyNames -Label "$Label run"
    $scalarSpecs = @(
        [pscustomobject]@{ source = $Summary; path = @('schema_version'); type = 'int32' },
        [pscustomobject]@{ source = $Summary; path = @('evidence_root'); type = 'string' },
        [pscustomobject]@{ source = $Summary; path = @('check_id'); type = 'string' },
        [pscustomobject]@{ source = $Summary; path = @('role'); type = 'string' },
        [pscustomobject]@{ source = $Summary; path = @('requested_evidence_role'); type = 'string' },
        [pscustomobject]@{ source = $Summary; path = @('repeat_profile_scope'); type = 'string' },
        [pscustomobject]@{ source = $Summary; path = @('fixed_repeat_qualification_authority'); type = 'string' },
        [pscustomobject]@{ source = $Summary; path = @('ending'); type = 'string' },
        [pscustomobject]@{ source = $Summary; path = @('seed'); type = 'string' },
        [pscustomobject]@{ source = $Summary; path = @('repeat'); type = 'int32' },
        [pscustomobject]@{ source = $Summary; path = @('deterministic'); type = 'bool' },
        [pscustomobject]@{ source = $Summary; path = @('checkpoint_evidence_complete'); type = 'bool' },
        [pscustomobject]@{ source = $Summary; path = @('release_qualifying'); type = 'bool' },
        [pscustomobject]@{ source = $Summary; path = @('qualification'); type = 'string' },
        [pscustomobject]@{ source = $Summary; path = @('public_observation_schema'); type = 'string' },
        [pscustomobject]@{ source = $Summary; path = @('public_observation_schema_version'); type = 'int32' },
        [pscustomobject]@{ source = $Run; path = @('action_count'); type = 'int32' },
        [pscustomobject]@{ source = $Run; path = @('outcome'); type = 'string' },
        [pscustomobject]@{ source = $Run; path = @('role'); type = 'string' },
        [pscustomobject]@{ source = $Run; path = @('requested_evidence_role'); type = 'string' },
        [pscustomobject]@{ source = $Run; path = @('repeat_profile_scope'); type = 'string' },
        [pscustomobject]@{ source = $Run; path = @('fixed_repeat_qualification_authority'); type = 'string' },
        [pscustomobject]@{ source = $Run; path = @('release_qualifying'); type = 'bool' },
        [pscustomobject]@{ source = $Run; path = @('qualification'); type = 'string' },
        [pscustomobject]@{ source = $Run; path = @('iteration'); type = 'int32' },
        [pscustomobject]@{ source = $Run; path = @('ending'); type = 'string' },
        [pscustomobject]@{ source = $Run; path = @('passed'); type = 'bool' },
        [pscustomobject]@{ source = $Run; path = @('seed'); type = 'string' },
        [pscustomobject]@{ source = $Run; path = @('observed_terminal_seed'); type = 'string' },
        [pscustomobject]@{ source = $Run; path = @('midpoint_save_relaunch_continue'); type = 'bool' },
        [pscustomobject]@{ source = $Run; path = @('failure'); type = 'string' },
        [pscustomobject]@{ source = $Run; path = @('transcript'); type = 'string' },
        [pscustomobject]@{ source = $Run; path = @('money_curve'); type = 'string' },
        [pscustomobject]@{ source = $Run; path = @('persistence_checkpoint_before'); type = 'string' },
        [pscustomobject]@{ source = $Run; path = @('persistence_checkpoint_after'); type = 'string' },
        [pscustomobject]@{ source = $Run; path = @('transcript_sha256'); type = 'string' },
        [pscustomobject]@{ source = $Run; path = @('money_curve_sha256'); type = 'string' },
        [pscustomobject]@{ source = $Run; path = @('persistence_checkpoint_before_sha256'); type = 'string' },
        [pscustomobject]@{ source = $Run; path = @('persistence_checkpoint_after_sha256'); type = 'string' },
        [pscustomobject]@{ source = $Run; path = @('persistence_checkpoint_equal'); type = 'bool' },
        [pscustomobject]@{ source = $Run; path = @('persistence_checkpoint_complete'); type = 'bool' },
        [pscustomobject]@{ source = $Run; path = @('session'); type = 'string' }
    )
    foreach ($spec in $scalarSpecs) {
        $value = Get-ExactValueNoEnumerate $spec.source $spec.path $null
        $valid = switch ($spec.type) {
            'string' { $value -is [string] }
            'int32' { $value -is [int32] }
            'bool' { $value -is [bool] }
            default { $false }
        }
        if (-not $valid) {
            throw "$Label field '$($spec.path -join '.')' is not one exact $($spec.type) value."
        }
    }
    $summarySchemaVersion = Get-ExactValueNoEnumerate $Summary @('schema_version') $null
    $summaryRole = Get-ExactValueNoEnumerate $Summary @('role') $null
    $summaryProfileScope = Get-ExactValueNoEnumerate $Summary @('repeat_profile_scope') $null
    $summaryQualificationAuthority = Get-ExactValueNoEnumerate $Summary @('fixed_repeat_qualification_authority') $null
    $summaryCheckpointComplete = Get-ExactValueNoEnumerate $Summary @('checkpoint_evidence_complete') $null
    $summaryObservationSchema = Get-ExactValueNoEnumerate $Summary @('public_observation_schema') $null
    $summaryObservationSchemaVersion = Get-ExactValueNoEnumerate $Summary @('public_observation_schema_version') $null
    $runIteration = Get-ExactValueNoEnumerate $Run @('iteration') $null
    $runEnding = Get-ExactValueNoEnumerate $Run @('ending') $null
    if ($summarySchemaVersion -ne 1 -or
        $summaryRole -cne 'child_development_run' -or
        $summaryProfileScope -cne 'shared_caller_appdata' -or
        $summaryQualificationAuthority -cne 'outer_independent_profile_aggregate_only' -or
        -not $summaryCheckpointComplete -or
        $summaryObservationSchema -cne 'beat_the_house.agent_public_observation' -or
        $summaryObservationSchemaVersion -ne 1 -or
        $runIteration -ne 1 -or $runEnding -cne $Ending) {
        throw "$Label summary or run has drifted from the exact one-run evidence schema."
    }
    $summarySeeds = Get-ExactValueNoEnumerate $Summary @('observed_terminal_seeds') $null
    $summaryRuns = Get-ExactValueNoEnumerate $Summary @('runs') $null
    if ($summarySeeds -isnot [object[]] -or $summarySeeds.Count -ne 1 -or
        $summaryRuns -isnot [object[]] -or $summaryRuns.Count -ne 1 -or
        -not (Test-ExactPsCustomObject -Value $summaryRuns[0])) {
        throw "$Label observed-terminal-seeds and runs must be exact JSON arrays."
    }
    foreach ($seedValue in $summarySeeds) {
        if ($seedValue -isnot [string]) { throw "$Label observed-terminal-seeds contains a non-string value." }
    }
    foreach ($objectSpec in @(
        [pscustomobject]@{ source = $Summary; path = @('replay_admission') },
        [pscustomobject]@{ source = $Run; path = @('replay_admission') },
        [pscustomobject]@{ source = $Run; path = @('final_public_checkpoint') }
    )) {
        $objectValue = Get-ExactValueNoEnumerate $objectSpec.source $objectSpec.path $null
        if (-not (Test-ExactPsCustomObject -Value $objectValue)) {
            throw "$Label field '$($objectSpec.path -join '.')' is not one exact object."
        }
    }
    if ($Ending -ceq 'heist') {
        foreach ($objectSpec in @(
            [pscustomobject]@{ source = $Summary; path = @('heist_seed_preflight') },
            [pscustomobject]@{ source = $Run; path = @('heist_seed_preflight') },
            [pscustomobject]@{ source = $Summary; path = @('heist_preflight_admission') },
            [pscustomobject]@{ source = $Run; path = @('heist_preflight_admission') },
            [pscustomobject]@{ source = $Run; path = @('heist_launch_setup') }
        )) {
            $objectValue = Get-ExactValueNoEnumerate $objectSpec.source $objectSpec.path $null
            if (-not (Test-ExactPsCustomObject -Value $objectValue)) {
                throw "$Label Heist field '$($objectSpec.path -join '.')' is not one exact object."
            }
        }
        $launchSetup = Get-ExactValueNoEnumerate $Run @('heist_launch_setup') $null
        Assert-Rw062ExactPropertyNames -InputObject $launchSetup -Expected @(
            'selected_challenge_id', 'selected_home_type_id', 'selected_content_groups'
        ) -Label "$Label Heist launch setup"
        $launchChallenge = Get-ExactValueNoEnumerate $launchSetup @('selected_challenge_id') $null
        $launchHome = Get-ExactValueNoEnumerate $launchSetup @('selected_home_type_id') $null
        $contentGroups = Get-ExactValueNoEnumerate $launchSetup @('selected_content_groups') $null
        if ($launchChallenge -isnot [string] -or $launchHome -isnot [string] -or
            $contentGroups -isnot [object[]]) {
            throw "$Label Heist launch setup has a non-exact scalar or array shape."
        }
        foreach ($contentGroup in $contentGroups) {
            if ($contentGroup -isnot [string]) { throw "$Label Heist launch setup contains a non-string content group." }
        }
    }
    elseif (-not (Test-Rw062ExactNullProperty -InputObject $Summary -Name 'heist_seed_preflight') -or
        -not (Test-Rw062ExactNullProperty -InputObject $Summary -Name 'heist_preflight_admission') -or
        -not (Test-Rw062ExactNullProperty -InputObject $Run -Name 'heist_seed_preflight') -or
        -not (Test-Rw062ExactNullProperty -InputObject $Run -Name 'heist_preflight_admission') -or
        -not (Test-Rw062ExactNullProperty -InputObject $Run -Name 'heist_launch_setup')) {
        throw "$Label non-Heist evidence must retain exact null Heist-only fields."
    }
}


function Assert-FinalCheckpointJsonShapes {
    param(
        [Parameter(Mandatory = $true)]$Retained,
        [Parameter(Mandatory = $true)]$Published,
        [Parameter(Mandatory = $true)][string]$Label
    )
    if (-not (Test-ExactPsCustomObject -Value $Retained) -or
        -not (Test-ExactPsCustomObject -Value $Published)) {
        throw "$Label retained and published checkpoints must each be one exact object."
    }
    $checkpointPropertyNames = @(
        'schema_version', 'record_kind', 'observed_seed', 'outcome_key', 'won',
        'public_fingerprint', 'checkpoint_fingerprint', 'bankroll', 'chips', 'heat'
    )
    Assert-LocalExactPropertyNames -InputObject $Retained -Expected $checkpointPropertyNames -Label "$Label retained"
    Assert-LocalExactPropertyNames -InputObject $Published -Expected $checkpointPropertyNames -Label "$Label published"
    foreach ($spec in @(
        [pscustomobject]@{ path = @('schema_version'); type = 'int32' },
        [pscustomobject]@{ path = @('record_kind'); type = 'string' },
        [pscustomobject]@{ path = @('observed_seed'); type = 'string' },
        [pscustomobject]@{ path = @('outcome_key'); type = 'string' },
        [pscustomobject]@{ path = @('won'); type = 'bool' },
        [pscustomobject]@{ path = @('public_fingerprint'); type = 'string' },
        [pscustomobject]@{ path = @('checkpoint_fingerprint'); type = 'string' },
        [pscustomobject]@{ path = @('bankroll'); type = 'int32' },
        [pscustomobject]@{ path = @('chips'); type = 'int32' },
        [pscustomobject]@{ path = @('heat'); type = 'int32' }
    )) {
        foreach ($source in @($Retained, $Published)) {
            $value = Get-ExactValueNoEnumerate $source $spec.path $null
            $valid = switch ($spec.type) {
                'string' { $value -is [string] }
                'bool' { $value -is [bool] }
                'int32' { $value -is [int32] }
                default { $false }
            }
            if (-not $valid) {
                throw "$Label field '$($spec.path -join '.')' is not one exact $($spec.type) value."
            }
        }
    }
    foreach ($source in @($Retained, $Published)) {
        $schemaVersion = Get-ExactValueNoEnumerate $source @('schema_version') $null
        $publicFingerprint = Get-ExactValueNoEnumerate $source @('public_fingerprint') $null
        $checkpointFingerprint = Get-ExactValueNoEnumerate $source @('checkpoint_fingerprint') $null
        if ($schemaVersion -ne 1 -or
            $publicFingerprint -cnotmatch '^[a-f0-9]{64}$' -or
            $checkpointFingerprint -cnotmatch '^[a-f0-9]{64}$') {
            throw "$Label schema_version or exact lowercase fingerprint format is invalid."
        }
    }
}


function Assert-PersistenceCoreCheckpointShape {
    param(
        [Parameter(Mandatory = $true)]$Checkpoint,
        [Parameter(Mandatory = $true)][string]$Label
    )
    Assert-LocalExactPropertyNames -InputObject $Checkpoint -Expected @(
        'location_id', 'location_archetype', 'world_node_id', 'bankroll', 'chips',
        'heat', 'game_id', 'game_phase', 'boss_hand_number', 'boss_player_stack',
        'boss_rourke_stack'
    ) -Label $Label
    foreach ($name in @('location_id', 'location_archetype', 'world_node_id', 'game_id', 'game_phase')) {
        $value = Get-ExactValueNoEnumerate $Checkpoint @($name) $null
        if ($value -isnot [string]) {
            throw "$Label field '$name' is not one exact string."
        }
    }
    foreach ($name in @('bankroll', 'chips', 'heat', 'boss_hand_number', 'boss_player_stack', 'boss_rourke_stack')) {
        $value = Get-ExactValueNoEnumerate $Checkpoint @($name) $null
        if ($value -isnot [int32] -or [int]$value -lt 0) {
            throw "$Label field '$name' is not one exact nonnegative Int32."
        }
    }
}


function Assert-SaveContinueCheckpointJsonShape {
    param(
        [Parameter(Mandatory = $true)]$Checkpoint,
        [Parameter(Mandatory = $true)][string]$Label
    )
    if ($Ending -ceq 'heist') {
        Assert-LocalExactPropertyNames `
            -InputObject $Checkpoint `
            -Expected @('checkpoint', 'planning_choices') `
            -Label $Label
    }
    else {
        Assert-LocalExactPropertyNames `
            -InputObject $Checkpoint `
            -Expected @('checkpoint', 'clean_players_card') `
            -Label $Label
    }
    $core = Get-ExactValueNoEnumerate $Checkpoint @('checkpoint') $null
    Assert-PersistenceCoreCheckpointShape -Checkpoint $core -Label "$Label checkpoint"

    if ($Ending -ceq 'clean') {
        $playersCard = Get-ExactValueNoEnumerate $Checkpoint @('clean_players_card') $null
        Assert-LocalExactPropertyNames -InputObject $playersCard -Expected @(
            'location_archetype', 'talk_event_id', 'tier_witness', 'next_tier_witness',
            'summary', 'choice_ids', 'choices'
        ) -Label "$Label clean Players Card"
        foreach ($name in @('location_archetype', 'talk_event_id', 'tier_witness', 'next_tier_witness', 'summary')) {
            $value = Get-ExactValueNoEnumerate $playersCard @($name) $null
            if ($value -isnot [string]) {
                throw "$Label clean Players Card field '$name' is not one exact string."
            }
        }
        if ($playersCard.location_archetype -cne 'grand_casino_cage' -or
            $playersCard.talk_event_id -cne 'dialogue:linda_cage_services' -or
            $playersCard.tier_witness -cne 'Silver' -or
            $playersCard.next_tier_witness -cne 'Gold' -or
            -not $playersCard.summary.StartsWith('Silver. Gold:', [StringComparison]::Ordinal)) {
            throw "$Label clean Players Card witness values drifted from the exact Silver milestone."
        }
        $expectedChoiceIds = [string[]]@('cage_claim_card', 'cage_ambient', 'back_main')
        $choiceIds = Get-ExactValueNoEnumerate $playersCard @('choice_ids') $null
        if (-not (Test-ExactStringArray -Value $choiceIds -Expected $expectedChoiceIds)) {
            throw "$Label clean Players Card choice_ids is not the exact three-string array."
        }
        $choices = Get-ExactValueNoEnumerate $playersCard @('choices') $null
        if ($choices -isnot [object[]] -or $choices.Count -ne $expectedChoiceIds.Count) {
            throw "$Label clean Players Card choices is not the exact three-object array."
        }
        for ($index = 0; $index -lt $choices.Count; $index++) {
            $choice = $choices[$index]
            Assert-LocalExactPropertyNames `
                -InputObject $choice `
                -Expected @('id', 'label', 'enabled') `
                -Label "$Label clean Players Card choice $index"
            $choiceId = Get-ExactValueNoEnumerate $choice @('id') $null
            $choiceLabel = Get-ExactValueNoEnumerate $choice @('label') $null
            $choiceEnabled = Get-ExactValueNoEnumerate $choice @('enabled') $null
            $expectedEnabled = $index -ne 0
            $labelValid = if ($index -eq 0) {
                $choiceLabel -is [string] -and
                    $choiceLabel.StartsWith("Claim Players Card`n", [StringComparison]::Ordinal) -and
                    $choiceLabel.Length -gt 'Claim Players Card'.Length + 1
            }
            elseif ($index -eq 1) { $choiceLabel -is [string] -and $choiceLabel -ceq 'Ask Linda' }
            else { $choiceLabel -is [string] -and $choiceLabel -ceq 'Back' }
            if ($choiceId -isnot [string] -or $choiceId -cne $expectedChoiceIds[$index] -or
                -not $labelValid -or
                $choiceEnabled -isnot [bool] -or $choiceEnabled -ne $expectedEnabled) {
                throw "$Label clean Players Card choice $index has an invalid exact identity or type."
            }
        }
    }
    elseif ($Ending -ceq 'cheat') {
        if ($core.location_archetype -cne 'grand_casino_back_room' -or
            $core.game_id -cne 'blackjack' -or
            $core.game_phase -cne 'betting' -or
            $core.boss_hand_number -ne 1) {
            throw "$Label Cheat checkpoint is not the exact retained Rourke duel-before-hand-one milestone."
        }
        $playersCardProperty = @($Checkpoint.PSObject.Properties | Where-Object { $_.Name -ceq 'clean_players_card' })
        if ($playersCardProperty.Count -ne 1 -or $null -ne $playersCardProperty[0].Value) {
            throw "$Label Cheat checkpoint must retain exact null clean_players_card evidence."
        }
    }
    else {
        $planningChoices = Get-ExactValueNoEnumerate $Checkpoint @('planning_choices') $null
        if ($planningChoices -isnot [object[]] -or $planningChoices.Count -eq 0) {
            throw "$Label Heist planning_choices is not one nonempty exact JSON array."
        }
        $seenChoiceIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        $countLockRows = 0
        for ($index = 0; $index -lt $planningChoices.Count; $index++) {
            $choice = $planningChoices[$index]
            Assert-LocalExactPropertyNames `
                -InputObject $choice `
                -Expected @('choice_id', 'label', 'enabled', 'rendered', 'disabled_reason') `
                -Label "$Label Heist planning choice $index"
            $choiceId = Get-ExactValueNoEnumerate $choice @('choice_id') $null
            $choiceLabel = Get-ExactValueNoEnumerate $choice @('label') $null
            $enabled = Get-ExactValueNoEnumerate $choice @('enabled') $null
            $rendered = Get-ExactValueNoEnumerate $choice @('rendered') $null
            $disabledReason = Get-ExactValueNoEnumerate $choice @('disabled_reason') $null
            if ($choiceId -isnot [string] -or [string]::IsNullOrWhiteSpace($choiceId) -or
                -not $seenChoiceIds.Add($choiceId) -or
                $choiceLabel -isnot [string] -or
                $enabled -isnot [bool] -or $rendered -isnot [bool] -or
                $disabledReason -isnot [string]) {
                throw "$Label Heist planning choice $index has an invalid exact schema or duplicate id."
            }
            if ($index -gt 0 -and
                [string]::CompareOrdinal([string]$planningChoices[$index - 1].choice_id, $choiceId) -ge 0) {
                throw "$Label Heist planning choices are not in exact unique ordinal order."
            }
            if ($choiceId -ceq 'lock_the_count') {
                $countLockRows++
                if (-not $enabled -or -not $rendered) {
                    throw "$Label Heist Count lock is not exactly enabled and rendered."
                }
            }
        }
        if ($countLockRows -ne 1) {
            throw "$Label Heist planning choices do not contain exactly one Count lock."
        }
    }
}


function Assert-OneRunEvidence {
    param(
        [Parameter(Mandatory = $true)][int]$RunIndex,
        [Parameter(Mandatory = $true)][string]$RunEvidenceRoot,
        [Parameter(Mandatory = $true)][string]$ReplayEvidenceRoot,
        [Parameter(Mandatory = $true)][string]$ProfileRoaming,
        [Parameter(Mandatory = $true)][string]$ProfileLocal,
        [Parameter(Mandatory = $true)]$Identity
    )
    $stdoutPath = Join-Path $RunEvidenceRoot 'launcher.stdout.txt'
    $stderrPath = Join-Path $RunEvidenceRoot 'launcher.stderr.txt'
    if (-not (Test-Path -LiteralPath $stdoutPath -PathType Leaf)) {
        throw "Run $RunIndex did not retain launcher stdout."
    }
    if (-not (Test-Path -LiteralPath $stderrPath -PathType Leaf) -or (Get-Item -LiteralPath $stderrPath).Length -ne 0) {
        throw "Run $RunIndex launcher stderr is missing or nonempty."
    }
    $stdoutPath = [IO.Path]::GetFullPath($stdoutPath)
    $stderrPath = [IO.Path]::GetFullPath($stderrPath)
    $launcherStdoutHash = Get-Sha256 -Path $stdoutPath
    $launcherStderrHash = Get-Sha256 -Path $stderrPath

    $invocations = @(Get-ChildItem -LiteralPath $ReplayEvidenceRoot -Directory -ErrorAction Stop)
    if ($invocations.Count -ne 1) {
        throw "Run $RunIndex produced $($invocations.Count) replay invocation directories instead of one."
    }
    $summaryPath = Join-Path $invocations[0].FullName 'summary.json'
    if (-not (Test-Path -LiteralPath $summaryPath -PathType Leaf)) {
        throw "Run $RunIndex did not write its invocation summary."
    }
    $summaryPath = [IO.Path]::GetFullPath($summaryPath)
    $replaySummaryHash = Get-Sha256 -Path $summaryPath
    $summary = ConvertFrom-ExactJsonObjectText `
        -Json (Microsoft.PowerShell.Management\Get-Content -Raw -LiteralPath $summaryPath -Encoding utf8) `
        -Label "Run $RunIndex invocation summary"
    if ((Get-Sha256 -Path $summaryPath) -cne $replaySummaryHash) {
        throw "Run $RunIndex invocation summary changed while it was authenticated."
    }
    $summaryEvidenceRoot = Get-ExactValueNoEnumerate $summary @('evidence_root') $null
    $summaryCheckId = Get-ExactValueNoEnumerate $summary @('check_id') $null
    $summaryEvidenceRole = Get-ExactValueNoEnumerate $summary @('requested_evidence_role') $null
    $summaryEnding = Get-ExactValueNoEnumerate $summary @('ending') $null
    $summarySeed = Get-ExactValueNoEnumerate $summary @('seed') $null
    $summaryRepeat = Get-ExactValueNoEnumerate $summary @('repeat') $null
    $summaryDeterministic = Get-ExactValueNoEnumerate $summary @('deterministic') $null
    $summaryReleaseQualifying = Get-ExactValueNoEnumerate $summary @('release_qualifying') $null
    $summaryQualification = Get-ExactValueNoEnumerate $summary @('qualification') $null
    Assert-ExactPublishedPath `
        -PublishedPath $summaryEvidenceRoot `
        -ExpectedPath $invocations[0].FullName `
        -Label "Run $RunIndex invocation evidence root"
    if ($summaryCheckId -isnot [string] -or $summaryCheckId -cne 'rw06_2_ending_replay' -or
        $summaryEvidenceRole -isnot [string] -or $summaryEvidenceRole -cne 'fixed-repeat' -or
        $summaryEnding -isnot [string] -or $summaryEnding -cne $Ending -or
        $summarySeed -isnot [string] -or $summarySeed -cne $Seed -or
        $summaryRepeat -isnot [int32] -or [int]$summaryRepeat -ne 1 -or
        $summaryDeterministic -isnot [bool] -or [bool]$summaryDeterministic -or
        $summaryReleaseQualifying -isnot [bool] -or [bool]$summaryReleaseQualifying -or
        $summaryQualification -isnot [string] -or $summaryQualification -cne 'non_qualifying_development_run') {
        throw "Run $RunIndex invocation summary did not match the exact one-run child contract."
    }
    $summaryAdmission = Get-ExactValueNoEnumerate $summary @('replay_admission') $null
    Assert-FixedReplayAdmission -Admission $summaryAdmission -Label "Run $RunIndex invocation summary"
    $terminalSeedsRaw = Get-ExactValueNoEnumerate $summary @('observed_terminal_seeds') $null
    if (-not (Test-ExactStringArray -Value $terminalSeedsRaw -Expected @($Seed))) {
        throw "Run $RunIndex did not report the exact fixed terminal seed."
    }
    $runsRaw = Get-ExactValueNoEnumerate $summary @('runs') $null
    if ($null -eq $runsRaw -or $runsRaw -is [string] -or
        $runsRaw -isnot [Collections.IEnumerable]) {
        throw "Run $RunIndex invocation summary runs field is not an exact collection."
    }
    $runs = @($runsRaw)
    if ($runs.Count -ne 1) {
        throw "Run $RunIndex invocation summary contained $($runs.Count) run records instead of one."
    }
    $run = $runs[0]
    if (-not (Test-ExactPsCustomObject -Value $run)) {
        throw "Run $RunIndex invocation summary run record is not one exact object."
    }
    Assert-OneRunJsonShapes -Summary $summary -Run $run -Label "Run $RunIndex"
    $actionCount = Get-ExactValueNoEnumerate $run @('action_count') $null
    $outcome = Get-ExactValueNoEnumerate $run @('outcome') $null
    $runRole = Get-ExactValueNoEnumerate $run @('role') $null
    $runEvidenceRole = Get-ExactValueNoEnumerate $run @('requested_evidence_role') $null
    $runProfileScope = Get-ExactValueNoEnumerate $run @('repeat_profile_scope') $null
    $runQualificationAuthority = Get-ExactValueNoEnumerate $run @('fixed_repeat_qualification_authority') $null
    $runReleaseQualifying = Get-ExactValueNoEnumerate $run @('release_qualifying') $null
    $runQualification = Get-ExactValueNoEnumerate $run @('qualification') $null
    $runPassed = Get-ExactValueNoEnumerate $run @('passed') $null
    $runSeed = Get-ExactValueNoEnumerate $run @('seed') $null
    $runObservedSeed = Get-ExactValueNoEnumerate $run @('observed_terminal_seed') $null
    $runMidpointPersistence = Get-ExactValueNoEnumerate $run @('midpoint_save_relaunch_continue') $null
    $runFailure = Get-ExactValueNoEnumerate $run @('failure') $null
    if ($actionCount -isnot [int32] -or
        $outcome -isnot [string] -or
        $runRole -isnot [string] -or $runRole -cne 'child_development_iteration' -or
        $runEvidenceRole -isnot [string] -or $runEvidenceRole -cne 'fixed-repeat' -or
        $runProfileScope -isnot [string] -or $runProfileScope -cne 'shared_caller_appdata' -or
        $runQualificationAuthority -isnot [string] -or $runQualificationAuthority -cne 'outer_independent_profile_aggregate_only' -or
        $runReleaseQualifying -isnot [bool] -or [bool]$runReleaseQualifying -or
        $runQualification -isnot [string] -or $runQualification -cne 'non_qualifying_development_iteration' -or
        $runPassed -isnot [bool] -or -not [bool]$runPassed -or
        $runSeed -isnot [string] -or $runSeed -cne $Seed -or
        $runObservedSeed -isnot [string] -or $runObservedSeed -cne $Seed -or
        $outcome -cnotin $ExpectedOutcomes[$Ending] -or
        $runMidpointPersistence -isnot [bool] -or -not [bool]$runMidpointPersistence -or
        $runFailure -isnot [string] -or -not [string]::IsNullOrEmpty($runFailure) -or
        [int]$actionCount -le 0 -or [int]$actionCount -gt 350) {
        throw "Run $RunIndex did not prove its terminal win, midpoint persistence, exact seed, and 1..350 action bound."
    }
    $runAdmission = Get-ExactValueNoEnumerate $run @('replay_admission') $null
    Assert-FixedReplayAdmission -Admission $runAdmission -Label "Run $RunIndex iteration summary"
    if ((ConvertTo-CanonicalExactObjectJson -InputObject $runAdmission -Label "Run $RunIndex iteration replay admission" -Depth 20) -cne
        (ConvertTo-CanonicalExactObjectJson -InputObject $summaryAdmission -Label "Run $RunIndex invocation replay admission" -Depth 20)) {
        throw "Run $RunIndex iteration replay admission differs from its invocation admission."
    }

    $heistSeedPreflightPath = $null
    $heistSeedPreflightHash = $null
    if ($Ending -ceq 'heist') {
        $preflight = Get-ExactValueNoEnumerate $summary @('heist_seed_preflight') $null
        $runPreflight = Get-ExactValueNoEnumerate $run @('heist_seed_preflight') $null
        if (-not (Test-ExactPsCustomObject -Value $preflight) -or
            -not (Test-ExactPsCustomObject -Value $runPreflight)) {
            throw "Run $RunIndex did not retain exact-object Q-013 seed/Audit preflight embeddings."
        }
        $preflightPassed = Get-ExactValueNoEnumerate $preflight @('passed') $null
        $preflightSeed = Get-ExactValueNoEnumerate $preflight @('selection', 'seed_text') $null
        $preflightScenario = Get-ExactValueNoEnumerate $preflight @('selection', 'selected_scenario') $null
        if ($preflightPassed -isnot [bool] -or -not [bool]$preflightPassed -or
            $preflightSeed -isnot [string] -or $preflightSeed -cne 'RW06-HEIST-AUDIT-0002' -or
            $preflightScenario -isnot [string] -or $preflightScenario -cne 'grand_casino_audit_night') {
            throw "Run $RunIndex did not retain the exact Q-013 seed/Audit preflight."
        }
        $expectedPreflightAdmission = Assert-Rw062HeistPreflightAdmission `
            -Admission $summaryAdmission `
            -Report $preflight
        $publishedSummaryPreflightAdmission = Get-ExactValueNoEnumerate $summary @('heist_preflight_admission') $null
        $publishedRunPreflightAdmission = Get-ExactValueNoEnumerate $run @('heist_preflight_admission') $null
        $expectedPreflightJson = ConvertTo-CanonicalExactObjectJson -InputObject $expectedPreflightAdmission -Label "Run $RunIndex expected Heist preflight admission" -Depth 20
        if ((ConvertTo-CanonicalExactObjectJson -InputObject $publishedSummaryPreflightAdmission -Label "Run $RunIndex invocation Heist preflight admission" -Depth 20) -cne $expectedPreflightJson -or
            (ConvertTo-CanonicalExactObjectJson -InputObject $publishedRunPreflightAdmission -Label "Run $RunIndex iteration Heist preflight admission" -Depth 20) -cne $expectedPreflightJson) {
            throw "Run $RunIndex did not retain its exact fixed-repeat Heist preflight admission receipt."
        }
        $retainedPreflightProof = Assert-RetainedHeistPreflightArtifact `
            -RunIndex $RunIndex `
            -InvocationRoot $invocations[0].FullName `
            -InvocationPreflight $preflight `
            -RunPreflight $runPreflight
        $heistSeedPreflightPath = $retainedPreflightProof.path
        $heistSeedPreflightHash = $retainedPreflightProof.sha256
        $launchSetup = Get-ExactValueNoEnumerate $run @('heist_launch_setup') $null
        $launchChallenge = Get-ExactValueNoEnumerate $launchSetup @('selected_challenge_id') $null
        $launchHome = Get-ExactValueNoEnumerate $launchSetup @('selected_home_type_id') $null
        $contentGroupsRaw = Get-ExactValueNoEnumerate $launchSetup @('selected_content_groups') $null
        $expectedContentGroups = @(
            'universal_passive_items', 'universal_active_items', 'scratch_tickets_pack',
            'pull_tabs_pack', 'slot_pack', 'coin_pusher_pack', 'bar_dice_pack',
            'craps_pack', 'crew_poker_pack', 'blackjack_pack', 'baccarat_pack',
            'roulette_pack', 'video_poker_pack', 'numbers_pack'
        )
        if ($launchChallenge -isnot [string] -or $launchChallenge -cne '' -or
            $launchHome -isnot [string] -or $launchHome -cne 'random' -or
            -not (Test-ExactStringArray -Value $contentGroupsRaw -Expected $expectedContentGroups)) {
            throw "Run $RunIndex did not retain the visible fresh Standard/Random/default-content Heist setup."
        }
    }
    elseif ($null -ne (Get-ExactValueNoEnumerate $summary @('heist_preflight_admission') $null) -or
        $null -ne (Get-ExactValueNoEnumerate $run @('heist_preflight_admission') $null)) {
        throw "Run $RunIndex published a Heist admission receipt for a non-Heist fixed route."
    }

    $runRoot = Join-Path $invocations[0].FullName 'run-01'
    $requiredLeaves = @(
        'summary.json', 'public_trace.ndjson', 'money_curve.ndjson',
        'checkpoint_before.json', 'checkpoint_after.json', 'final_public_checkpoint.json'
    )
    foreach ($leaf in $requiredLeaves) {
        if (-not (Test-Path -LiteralPath (Join-Path $runRoot $leaf) -PathType Leaf)) {
            throw "Run $RunIndex evidence is missing $leaf."
        }
    }
    $runSummaryPath = [IO.Path]::GetFullPath((Join-Path $runRoot 'summary.json'))
    $runSummaryHash = Get-Sha256 -Path $runSummaryPath
    $retainedRunSummary = ConvertFrom-ExactJsonObjectText `
        -Json (Microsoft.PowerShell.Management\Get-Content -Raw -LiteralPath $runSummaryPath -Encoding utf8) `
        -Label "Run $RunIndex retained run summary"
    if ((Get-Sha256 -Path $runSummaryPath) -cne $runSummaryHash) {
        throw "Run $RunIndex retained run summary changed while it was authenticated."
    }
    if ((ConvertTo-CanonicalExactObjectJson -InputObject $retainedRunSummary -Label "Run $RunIndex retained run summary") -cne
        (ConvertTo-CanonicalExactObjectJson -InputObject $run -Label "Run $RunIndex embedded run summary")) {
        throw "Run $RunIndex retained run summary differs from its invocation summary record."
    }
    $transcriptPath = Join-Path $runRoot 'public_trace.ndjson'
    $moneyPath = Join-Path $runRoot 'money_curve.ndjson'
    $transcriptHash = Get-Sha256 -Path $transcriptPath
    $moneyHash = Get-Sha256 -Path $moneyPath
    $checkpointBeforePath = Join-Path $runRoot 'checkpoint_before.json'
    $checkpointAfterPath = Join-Path $runRoot 'checkpoint_after.json'
    $checkpointBeforeHash = Get-Sha256 -Path $checkpointBeforePath
    $checkpointAfterHash = Get-Sha256 -Path $checkpointAfterPath
    $finalCheckpointPath = Join-Path $runRoot 'final_public_checkpoint.json'
    $finalCheckpointHash = Get-Sha256 -Path $finalCheckpointPath
    $publishedTranscriptPath = Get-ExactValueNoEnumerate $run @('transcript') $null
    $publishedMoneyPath = Get-ExactValueNoEnumerate $run @('money_curve') $null
    $publishedCheckpointBeforePath = Get-ExactValueNoEnumerate $run @('persistence_checkpoint_before') $null
    $publishedCheckpointAfterPath = Get-ExactValueNoEnumerate $run @('persistence_checkpoint_after') $null
    Assert-ExactPublishedPath `
        -PublishedPath $publishedTranscriptPath `
        -ExpectedPath $transcriptPath `
        -Label "Run $RunIndex transcript"
    Assert-ExactPublishedPath `
        -PublishedPath $publishedMoneyPath `
        -ExpectedPath $moneyPath `
        -Label "Run $RunIndex money curve"
    Assert-ExactPublishedPath `
        -PublishedPath $publishedCheckpointBeforePath `
        -ExpectedPath $checkpointBeforePath `
        -Label "Run $RunIndex checkpoint before"
    Assert-ExactPublishedPath `
        -PublishedPath $publishedCheckpointAfterPath `
        -ExpectedPath $checkpointAfterPath `
        -Label "Run $RunIndex checkpoint after"
    $publishedTranscriptHash = Get-ExactValueNoEnumerate $run @('transcript_sha256') $null
    $publishedMoneyHash = Get-ExactValueNoEnumerate $run @('money_curve_sha256') $null
    $publishedCheckpointBeforeHash = Get-ExactValueNoEnumerate $run @('persistence_checkpoint_before_sha256') $null
    $publishedCheckpointAfterHash = Get-ExactValueNoEnumerate $run @('persistence_checkpoint_after_sha256') $null
    $publishedCheckpointEqual = Get-ExactValueNoEnumerate $run @('persistence_checkpoint_equal') $null
    $publishedCheckpointComplete = Get-ExactValueNoEnumerate $run @('persistence_checkpoint_complete') $null
    if ($publishedTranscriptHash -isnot [string] -or $transcriptHash -cne $publishedTranscriptHash -or
        $publishedMoneyHash -isnot [string] -or $moneyHash -cne $publishedMoneyHash -or
        $publishedCheckpointBeforeHash -isnot [string] -or $checkpointBeforeHash -cne $publishedCheckpointBeforeHash -or
        $publishedCheckpointAfterHash -isnot [string] -or $checkpointAfterHash -cne $publishedCheckpointAfterHash -or
        $publishedCheckpointEqual -isnot [bool] -or -not [bool]$publishedCheckpointEqual -or
        $publishedCheckpointComplete -isnot [bool] -or -not [bool]$publishedCheckpointComplete) {
        throw "Run $RunIndex retained evidence hashes do not match its run summary."
    }
    if ($checkpointBeforeHash -cne $checkpointAfterHash) {
        throw "Run $RunIndex persistence checkpoint hashes differ across Save/relaunch/Continue."
    }
    $checkpointBefore = ConvertFrom-ExactJsonObjectText `
        -Json (Microsoft.PowerShell.Management\Get-Content -Raw -LiteralPath $checkpointBeforePath -Encoding utf8) `
        -Label "Run $RunIndex persistence checkpoint before"
    $checkpointAfter = ConvertFrom-ExactJsonObjectText `
        -Json (Microsoft.PowerShell.Management\Get-Content -Raw -LiteralPath $checkpointAfterPath -Encoding utf8) `
        -Label "Run $RunIndex persistence checkpoint after"
    Assert-SaveContinueCheckpointJsonShape `
        -Checkpoint $checkpointBefore `
        -Label "Run $RunIndex persistence checkpoint before"
    Assert-SaveContinueCheckpointJsonShape `
        -Checkpoint $checkpointAfter `
        -Label "Run $RunIndex persistence checkpoint after"
    if ((ConvertTo-CanonicalExactObjectJson -InputObject $checkpointBefore -Label "Run $RunIndex persistence checkpoint before") -cne
        (ConvertTo-CanonicalExactObjectJson -InputObject $checkpointAfter -Label "Run $RunIndex persistence checkpoint after")) {
        throw "Run $RunIndex persistence checkpoint JSON differs across Save/relaunch/Continue."
    }

    $finalCheckpoint = ConvertFrom-ExactJsonObjectText `
        -Json (Microsoft.PowerShell.Management\Get-Content -Raw -LiteralPath $finalCheckpointPath -Encoding utf8) `
        -Label "Run $RunIndex retained final public checkpoint"
    $publishedFinalCheckpoint = Get-ExactValueNoEnumerate $run @('final_public_checkpoint') $null
    Assert-FinalCheckpointJsonShapes `
        -Retained $finalCheckpoint `
        -Published $publishedFinalCheckpoint `
        -Label "Run $RunIndex final public checkpoint"
    if ((ConvertTo-CanonicalExactObjectJson -InputObject $finalCheckpoint -Label "Run $RunIndex retained final public checkpoint") -cne
        (ConvertTo-CanonicalExactObjectJson -InputObject $publishedFinalCheckpoint -Label "Run $RunIndex published final public checkpoint")) {
        throw "Run $RunIndex final public checkpoint file differs from its published run summary object."
    }
    $finalRecordKind = Get-ExactValueNoEnumerate $finalCheckpoint @('record_kind') $null
    $finalObservedSeed = Get-ExactValueNoEnumerate $finalCheckpoint @('observed_seed') $null
    $finalOutcome = Get-ExactValueNoEnumerate $finalCheckpoint @('outcome_key') $null
    $finalWon = Get-ExactValueNoEnumerate $finalCheckpoint @('won') $null
    $finalPublicFingerprint = Get-ExactValueNoEnumerate $finalCheckpoint @('public_fingerprint') $null
    $finalCheckpointFingerprint = Get-ExactValueNoEnumerate $finalCheckpoint @('checkpoint_fingerprint') $null
    if ($finalRecordKind -isnot [string] -or $finalRecordKind -cne 'final_public_checkpoint' -or
        $finalObservedSeed -isnot [string] -or $finalObservedSeed -cne $Seed -or
        $finalOutcome -isnot [string] -or $finalOutcome -cne $outcome -or
        $finalWon -isnot [bool] -or -not [bool]$finalWon -or
        $finalPublicFingerprint -isnot [string] -or $finalPublicFingerprint -cnotmatch '^[a-f0-9]{64}$' -or
        $finalCheckpointFingerprint -isnot [string] -or $finalCheckpointFingerprint -cnotmatch '^[a-f0-9]{64}$') {
        throw "Run $RunIndex final public checkpoint is incomplete or does not prove the requested win."
    }
    foreach ($name in @('bankroll', 'chips', 'heat')) {
        $value = Get-ExactValueNoEnumerate $finalCheckpoint @($name) $null
        if ($value -isnot [int32] -or [int]$value -lt 0) {
            throw "Run $RunIndex final public checkpoint has an invalid $name value."
        }
    }

    $session = Get-ExactValueNoEnumerate $run @('session') $null
    $expectedSessionPrefix = "rw062-$Ending-$([int]$Identity.pid)-1-"
    $expectedSessionPattern = '^' + [regex]::Escape($expectedSessionPrefix) + '[0-9a-f]{10}$'
    if ($session -isnot [string] -or $session -cnotmatch $expectedSessionPattern) {
        throw "Run $RunIndex session '$session' is not owned by its exact replay child."
    }
    $sessionRoot = Resolve-ExactSessionRoot -Session $session
    $logHashes = Assert-StrictSessionLogs -SessionRoot $sessionRoot

    foreach ($profile in @($ProfileRoaming, $ProfileLocal)) {
        if (-not (Test-Path -LiteralPath $profile -PathType Container)) {
            throw "Run $RunIndex isolated profile root is missing: $profile"
        }
        $runPrefix = ([IO.Path]::GetFullPath($RunEvidenceRoot)).TrimEnd('\') + '\'
        if (-not ([IO.Path]::GetFullPath($profile)).StartsWith($runPrefix, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Run $RunIndex isolated profile escaped its evidence root: $profile"
        }
    }

    $profileSessionRoot = [IO.Path]::GetFullPath((Join-Path $ProfileRoaming "Godot\app_userdata\Beat the House\agent_playtest\$session"))
    $profileRoamingPrefix = ([IO.Path]::GetFullPath($ProfileRoaming)).TrimEnd('\') + '\'
    if (-not $profileSessionRoot.StartsWith($profileRoamingPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Run $RunIndex resolved user-data session root escaped its isolated roaming profile."
    }
    $profileInventoryPath = Join-Path $profileSessionRoot 'profile_inventory.json'
    $autosavePath = Join-Path $profileSessionRoot 'saves\foundation_ui_autosave.json'
    foreach ($profileArtifact in @($profileInventoryPath, $autosavePath)) {
        if (-not (Test-Path -LiteralPath $profileArtifact -PathType Leaf) -or
            (Get-Item -LiteralPath $profileArtifact).Length -le 0) {
            throw "Run $RunIndex did not write required nonempty isolated profile artifact: $profileArtifact"
        }
        try {
            $profilePayload = ConvertFrom-ExactJsonObjectText `
                -Json (Microsoft.PowerShell.Management\Get-Content -Raw -LiteralPath $profileArtifact -Encoding utf8) `
                -Label "Run $RunIndex isolated profile artifact $profileArtifact"
        }
        catch {
            throw "Run $RunIndex isolated profile artifact is not valid JSON: $profileArtifact. $($_.Exception.Message)"
        }
    }
    $profileInventoryHash = Get-Sha256 -Path $profileInventoryPath
    $autosaveHash = Get-Sha256 -Path $autosavePath

    $proof = [pscustomobject][ordered]@{
        run_index = $RunIndex
        role = 'fixed_route_repeat'
        evidence_role = $summaryEvidenceRole
        ending = $Ending
        seed = $Seed
        replay_pid = [int]$Identity.pid
        profile_roaming = [IO.Path]::GetFullPath($ProfileRoaming)
        profile_local = [IO.Path]::GetFullPath($ProfileLocal)
        profile_session_root = $profileSessionRoot
        profile_inventory = $profileInventoryPath
        profile_inventory_sha256 = $profileInventoryHash
        autosave = $autosavePath
        autosave_sha256 = $autosaveHash
        replay_invocation_root = $invocations[0].FullName
        replay_summary = $summaryPath
        replay_summary_sha256 = $replaySummaryHash
        launcher_stdout = $stdoutPath
        launcher_stdout_sha256 = $launcherStdoutHash
        launcher_stderr = $stderrPath
        launcher_stderr_sha256 = $launcherStderrHash
        run_root = $runRoot
        run_summary = $runSummaryPath
        run_summary_sha256 = $runSummaryHash
        session = $session
        session_root = $sessionRoot
        outcome = $outcome
        action_count = $actionCount
        transcript_sha256 = $transcriptHash
        money_curve_sha256 = $moneyHash
        persistence_checkpoint_before_sha256 = $checkpointBeforeHash
        persistence_checkpoint_after_sha256 = $checkpointAfterHash
        final_public_checkpoint_sha256 = $finalCheckpointHash
        heist_seed_preflight = $heistSeedPreflightPath
        heist_seed_preflight_sha256 = $heistSeedPreflightHash
        source_custody_pre = $SourceCustodyPrePath
        source_custody_pre_sha256 = $script:SourceCustodyPreSha256
        godot_stdout_sha256 = [string]$logHashes.'godot.stdout.log'
        godot_stderr_sha256 = [string]$logHashes.'godot.stderr.log'
        godot_engine_sha256 = [string]$logHashes.'godot.engine.log'
    }
    Assert-FixedRunProofShape -Proof $proof -ExpectedRunIndex $RunIndex -Label "Run $RunIndex proof"
    return $proof
}


function Invoke-OneFixedRun {
    param([Parameter(Mandatory = $true)][ValidateRange(1, 2)][int]$RunIndex)
    $runName = 'run-{0:D2}' -f $RunIndex
    $runEvidenceRoot = Join-Path $EvidenceRoot $runName
    $replayEvidenceRoot = Join-Path $runEvidenceRoot 'replay'
    $profileRoaming = Join-Path $runEvidenceRoot 'profile_roaming'
    $profileLocal = Join-Path $runEvidenceRoot 'profile_local'
    $stdoutPath = Join-Path $runEvidenceRoot 'launcher.stdout.txt'
    $stderrPath = Join-Path $runEvidenceRoot 'launcher.stderr.txt'
    New-Item -ItemType Directory -Path $runEvidenceRoot,$replayEvidenceRoot,$profileRoaming,$profileLocal -Force | Out-Null
    Assert-SourceCustody

    $originalAppData = [Environment]::GetEnvironmentVariable('APPDATA', 'Process')
    $originalLocalAppData = [Environment]::GetEnvironmentVariable('LOCALAPPDATA', 'Process')
    $originalGodotBin = [Environment]::GetEnvironmentVariable('GODOT_BIN', 'Process')
    $originalDeveloperPlacement = [Environment]::GetEnvironmentVariable('BTH_DEVELOPER_PLACEMENT_PATH', 'Process')
    $originalProjectPlacement = [Environment]::GetEnvironmentVariable('BTH_PROJECT_PLACEMENT_PATH', 'Process')
    $process = $null
    $identity = $null
    try {
        $env:APPDATA = $profileRoaming
        $env:LOCALAPPDATA = $profileLocal
        $env:GODOT_BIN = $GodotBin
        $env:BTH_DEVELOPER_PLACEMENT_PATH = Join-Path $profileRoaming 'developer_environment_placements.json'
        $env:BTH_PROJECT_PLACEMENT_PATH = ''
        $powerShellExe = [Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
        $process = Microsoft.PowerShell.Management\Start-Process -FilePath $powerShellExe -ArgumentList @(
            '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', (Get-ValidatedReplayToolPath),
            '-Ending', $Ending, '-EvidenceRole', 'fixed-repeat', '-Seed', $Seed, '-Repeat', '1',
            '-TimeoutSeconds', [string]$CommandTimeoutSeconds, '-EvidenceRoot', $replayEvidenceRoot
        ) `
            -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath `
            -WindowStyle Hidden -PassThru
        $sessionPrefix = "--session=rw062-$Ending-$($process.Id)-"
        $provisionalIdentity = [pscustomobject][ordered]@{
            run_index = $RunIndex
            pid = [int]$process.Id
            process = $process
            session_prefix = $sessionPrefix
        }
        $script:ProvisionalReplayProcesses.Add($provisionalIdentity)
        try {
            $identity = [pscustomobject][ordered]@{
                run_index = $RunIndex
                pid = [int]$process.Id
                start_utc_ticks = [long]$process.StartTime.ToUniversalTime().Ticks
                session_prefix = $sessionPrefix
            }
            $script:OwnedReplayIdentities.Add($identity)
            $null = $script:ProvisionalReplayProcesses.Remove($provisionalIdentity)
        }
        catch {
            $registrationFailure = $_.Exception.Message
            try {
                Stop-UnregisteredReplayProcess -Process $process -SessionPrefix $sessionPrefix
                $null = $script:ProvisionalReplayProcesses.Remove($provisionalIdentity)
            }
            catch {
                throw "Run $RunIndex replay identity registration failed ($registrationFailure), and exact fail-clean cleanup failed: $($_.Exception.Message)"
            }
            throw "Run $RunIndex replay identity registration failed and its exact process tree was stopped: $registrationFailure"
        }
    }
    finally {
        Restore-ProcessEnvironmentValue -Name 'APPDATA' -Value $originalAppData
        Restore-ProcessEnvironmentValue -Name 'LOCALAPPDATA' -Value $originalLocalAppData
        Restore-ProcessEnvironmentValue -Name 'GODOT_BIN' -Value $originalGodotBin
        Restore-ProcessEnvironmentValue -Name 'BTH_DEVELOPER_PLACEMENT_PATH' -Value $originalDeveloperPlacement
        Restore-ProcessEnvironmentValue -Name 'BTH_PROJECT_PLACEMENT_PATH' -Value $originalProjectPlacement
    }
    if ($null -eq $process) {
        throw "Run $RunIndex replay process did not start."
    }

    if (-not $process.WaitForExit($PerRunTimeoutSeconds * 1000)) {
        Stop-OwnedReplayIdentity -Identity $identity
        throw "Run $RunIndex $Ending replay timed out after $PerRunTimeoutSeconds seconds."
    }
    $process.WaitForExit()
    $process.Refresh()
    if ([int]$process.ExitCode -ne 0) {
        throw "Run $RunIndex $Ending replay exited $($process.ExitCode)."
    }
    if ((Get-Item -LiteralPath $stderrPath).Length -ne 0) {
        throw "Run $RunIndex replay launcher stderr is nonempty."
    }
    Assert-SourceCustody

    $ownedDeadline = [DateTime]::UtcNow.AddSeconds(15)
    while ([DateTime]::UtcNow -lt $ownedDeadline -and @(Get-OwnedGodotProcesses).Count -gt 0) {
        Start-Sleep -Milliseconds 200
    }
    if (@(Get-OwnedGodotProcesses).Count -ne 0) {
        Stop-OwnedReplayIdentity -Identity $identity
        throw "Run $RunIndex left an owned Godot session alive after replay exit."
    }
    $proof = Assert-OneRunEvidence `
        -RunIndex $RunIndex `
        -RunEvidenceRoot $runEvidenceRoot `
        -ReplayEvidenceRoot $replayEvidenceRoot `
        -ProfileRoaming $profileRoaming `
        -ProfileLocal $profileLocal `
        -Identity $identity
    Assert-RepositoryIdentity
    return $proof
}


function Assert-FixedRunProofShape {
    param(
        [Parameter(Mandatory = $true)]$Proof,
        [Parameter(Mandatory = $true)][ValidateRange(1, 2)][int]$ExpectedRunIndex,
        [Parameter(Mandatory = $true)][string]$Label
    )
    Assert-LocalExactPropertyNames -InputObject $Proof -Expected @(
        'run_index', 'role', 'evidence_role', 'ending', 'seed', 'replay_pid',
        'profile_roaming', 'profile_local', 'profile_session_root', 'profile_inventory',
        'profile_inventory_sha256', 'autosave', 'autosave_sha256',
        'replay_invocation_root', 'replay_summary', 'replay_summary_sha256',
        'launcher_stdout', 'launcher_stdout_sha256', 'launcher_stderr', 'launcher_stderr_sha256',
        'run_root', 'run_summary', 'run_summary_sha256',
        'session', 'session_root', 'outcome', 'action_count',
        'transcript_sha256', 'money_curve_sha256',
        'persistence_checkpoint_before_sha256', 'persistence_checkpoint_after_sha256',
        'final_public_checkpoint_sha256', 'heist_seed_preflight',
        'heist_seed_preflight_sha256', 'source_custody_pre',
        'source_custody_pre_sha256', 'godot_stdout_sha256', 'godot_stderr_sha256',
        'godot_engine_sha256'
    ) -Label $Label

    $runIndex = Get-ExactValueNoEnumerate $Proof @('run_index') $null
    $role = Get-ExactValueNoEnumerate $Proof @('role') $null
    $evidenceRole = Get-ExactValueNoEnumerate $Proof @('evidence_role') $null
    $proofEnding = Get-ExactValueNoEnumerate $Proof @('ending') $null
    $proofSeed = Get-ExactValueNoEnumerate $Proof @('seed') $null
    $replayPid = Get-ExactValueNoEnumerate $Proof @('replay_pid') $null
    $outcome = Get-ExactValueNoEnumerate $Proof @('outcome') $null
    $actionCount = Get-ExactValueNoEnumerate $Proof @('action_count') $null
    if ($runIndex -isnot [int32] -or $runIndex -ne $ExpectedRunIndex -or
        $role -isnot [string] -or $role -cne 'fixed_route_repeat' -or
        $evidenceRole -isnot [string] -or $evidenceRole -cne 'fixed-repeat' -or
        $proofEnding -isnot [string] -or $proofEnding -cne $Ending -or
        $proofSeed -isnot [string] -or $proofSeed -cne $Seed -or
        $replayPid -isnot [int32] -or $replayPid -le 0 -or
        $outcome -isnot [string] -or $outcome -cnotin $ExpectedOutcomes[$Ending] -or
        $actionCount -isnot [int32] -or $actionCount -lt 1 -or $actionCount -gt 350) {
        throw "$Label has an invalid exact run identity, outcome, or action count."
    }

    foreach ($name in @(
        'profile_roaming', 'profile_local', 'profile_session_root', 'profile_inventory',
        'autosave', 'replay_invocation_root', 'replay_summary', 'launcher_stdout',
        'launcher_stderr', 'run_root', 'run_summary', 'session', 'session_root',
        'source_custody_pre'
    )) {
        $value = Get-ExactValueNoEnumerate $Proof @($name) $null
        if ($value -isnot [string] -or [string]::IsNullOrWhiteSpace($value) -or
            ($name -cne 'session' -and
                (-not [IO.Path]::IsPathRooted($value) -or [IO.Path]::GetFullPath($value) -cne $value))) {
            throw "$Label field '$name' is not one exact canonical nonempty string/path."
        }
    }
    $profileRoaming = Get-ExactValueNoEnumerate $Proof @('profile_roaming') $null
    $profileLocal = Get-ExactValueNoEnumerate $Proof @('profile_local') $null
    $profileSessionRoot = Get-ExactValueNoEnumerate $Proof @('profile_session_root') $null
    $profileInventory = Get-ExactValueNoEnumerate $Proof @('profile_inventory') $null
    $autosave = Get-ExactValueNoEnumerate $Proof @('autosave') $null
    $replayInvocationRoot = Get-ExactValueNoEnumerate $Proof @('replay_invocation_root') $null
    $replaySummary = Get-ExactValueNoEnumerate $Proof @('replay_summary') $null
    $launcherStdout = Get-ExactValueNoEnumerate $Proof @('launcher_stdout') $null
    $launcherStderr = Get-ExactValueNoEnumerate $Proof @('launcher_stderr') $null
    $runRoot = Get-ExactValueNoEnumerate $Proof @('run_root') $null
    $runSummary = Get-ExactValueNoEnumerate $Proof @('run_summary') $null
    $session = Get-ExactValueNoEnumerate $Proof @('session') $null
    $sessionRoot = Get-ExactValueNoEnumerate $Proof @('session_root') $null
    $outerRunRoot = [IO.Path]::GetFullPath((Split-Path -Parent $profileRoaming))
    $expectedOuterRunRoot = [IO.Path]::GetFullPath((Join-Path $EvidenceRoot ('run-{0:D2}' -f $runIndex)))
    $expectedProfileRoaming = [IO.Path]::GetFullPath((Join-Path $outerRunRoot 'profile_roaming'))
    $expectedProfileLocal = [IO.Path]::GetFullPath((Join-Path $outerRunRoot 'profile_local'))
    $expectedReplayParent = [IO.Path]::GetFullPath((Join-Path $outerRunRoot 'replay'))
    $expectedProfileSessionRoot = [IO.Path]::GetFullPath((Join-Path $profileRoaming "Godot\app_userdata\Beat the House\agent_playtest\$session"))
    $expectedProfileInventory = [IO.Path]::GetFullPath((Join-Path $profileSessionRoot 'profile_inventory.json'))
    $expectedAutosave = [IO.Path]::GetFullPath((Join-Path $profileSessionRoot 'saves\foundation_ui_autosave.json'))
    $expectedReplaySummary = [IO.Path]::GetFullPath((Join-Path $replayInvocationRoot 'summary.json'))
    $expectedLauncherStdout = [IO.Path]::GetFullPath((Join-Path $outerRunRoot 'launcher.stdout.txt'))
    $expectedLauncherStderr = [IO.Path]::GetFullPath((Join-Path $outerRunRoot 'launcher.stderr.txt'))
    $expectedRunRoot = [IO.Path]::GetFullPath((Join-Path $replayInvocationRoot 'run-01'))
    $expectedRunSummary = [IO.Path]::GetFullPath((Join-Path $runRoot 'summary.json'))
    $expectedInvocationPattern = '^\d{8}-\d{6}-\d{3}-' + [regex]::Escape([string]$replayPid) + '$'
    $expectedSessionPattern = '^rw062-' + [regex]::Escape($Ending) + '-' + [regex]::Escape([string]$replayPid) + '-1-[0-9a-f]{10}$'
    $sessionDateRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sessionRoot))
    $sessionBaseRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sessionDateRoot))
    $expectedSessionBaseRoot = [IO.Path]::GetFullPath((Join-Path $Worktree '.tmp\agent_playtest'))
    $invocationName = [IO.Path]::GetFileName($replayInvocationRoot)
    $sessionDateName = [IO.Path]::GetFileName($sessionDateRoot)
    if ($invocationName -cnotmatch $expectedInvocationPattern -or
        $sessionDateName -cnotmatch '^\d{4}-\d{2}-\d{2}$') {
        throw "$Label has an invalid replay invocation or session-date identity."
    }
    $expectedSessionDateName = $invocationName.Substring(0, 4) + '-' +
        $invocationName.Substring(4, 2) + '-' + $invocationName.Substring(6, 2)
    if (-not $outerRunRoot.Equals($expectedOuterRunRoot, [StringComparison]::OrdinalIgnoreCase) -or
        -not $profileRoaming.Equals($expectedProfileRoaming, [StringComparison]::OrdinalIgnoreCase) -or
        -not $profileLocal.Equals($expectedProfileLocal, [StringComparison]::OrdinalIgnoreCase) -or
        -not ([IO.Path]::GetFullPath((Split-Path -Parent $replayInvocationRoot))).Equals($expectedReplayParent, [StringComparison]::OrdinalIgnoreCase) -or
        -not $profileSessionRoot.Equals($expectedProfileSessionRoot, [StringComparison]::OrdinalIgnoreCase) -or
        -not $profileInventory.Equals($expectedProfileInventory, [StringComparison]::OrdinalIgnoreCase) -or
        -not $autosave.Equals($expectedAutosave, [StringComparison]::OrdinalIgnoreCase) -or
        -not $replaySummary.Equals($expectedReplaySummary, [StringComparison]::OrdinalIgnoreCase) -or
        -not $launcherStdout.Equals($expectedLauncherStdout, [StringComparison]::OrdinalIgnoreCase) -or
        -not $launcherStderr.Equals($expectedLauncherStderr, [StringComparison]::OrdinalIgnoreCase) -or
        -not $runRoot.Equals($expectedRunRoot, [StringComparison]::OrdinalIgnoreCase) -or
        -not $runSummary.Equals($expectedRunSummary, [StringComparison]::OrdinalIgnoreCase) -or
        $session -cnotmatch $expectedSessionPattern -or
        [IO.Path]::GetFileName($sessionRoot) -cne $session -or
        $sessionDateName -cne $expectedSessionDateName -or
        -not $sessionBaseRoot.Equals($expectedSessionBaseRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw "$Label does not bind its exact profile, replay, run, session, or retained-artifact path graph."
    }
    if ($Proof.source_custody_pre -cne $SourceCustodyPrePath) {
        throw "$Label does not bind the exact source-custody pre-execution receipt path."
    }
    foreach ($name in @(
        'profile_inventory_sha256', 'autosave_sha256', 'replay_summary_sha256',
        'launcher_stdout_sha256', 'launcher_stderr_sha256', 'run_summary_sha256',
        'transcript_sha256', 'money_curve_sha256',
        'persistence_checkpoint_before_sha256', 'persistence_checkpoint_after_sha256',
        'final_public_checkpoint_sha256', 'source_custody_pre_sha256',
        'godot_stdout_sha256', 'godot_stderr_sha256', 'godot_engine_sha256'
    )) {
        $value = Get-ExactValueNoEnumerate $Proof @($name) $null
        if ($value -isnot [string] -or $value -cnotmatch '^[a-f0-9]{64}$') {
            throw "$Label field '$name' is not one exact lowercase SHA-256."
        }
    }
    if ($Proof.source_custody_pre_sha256 -cne $script:SourceCustodyPreSha256) {
        throw "$Label does not bind the held source-custody pre-execution receipt hash."
    }
    if ($Proof.persistence_checkpoint_before_sha256 -cne $Proof.persistence_checkpoint_after_sha256) {
        throw "$Label does not retain equal Save/Continue checkpoint hashes."
    }

    $heistPreflightPath = Get-ExactValueNoEnumerate $Proof @('heist_seed_preflight') $null
    $heistPreflightHash = Get-ExactValueNoEnumerate $Proof @('heist_seed_preflight_sha256') $null
    if ($Ending -ceq 'heist') {
        if ($heistPreflightPath -isnot [string] -or [string]::IsNullOrWhiteSpace($heistPreflightPath) -or
            -not [IO.Path]::IsPathRooted($heistPreflightPath) -or
            [IO.Path]::GetFullPath($heistPreflightPath) -cne $heistPreflightPath -or
            [IO.Path]::GetFullPath((Join-Path $Proof.replay_invocation_root 'heist_seed_preflight.json')) -cne $heistPreflightPath -or
            $heistPreflightHash -isnot [string] -or $heistPreflightHash -cnotmatch '^[a-f0-9]{64}$') {
            throw "$Label omits the exact retained Heist seed-preflight artifact."
        }
    }
    else {
        $pathProperty = @($Proof.PSObject.Properties | Where-Object { $_.Name -ceq 'heist_seed_preflight' })
        $hashProperty = @($Proof.PSObject.Properties | Where-Object { $_.Name -ceq 'heist_seed_preflight_sha256' })
        if ($pathProperty.Count -ne 1 -or $null -ne $pathProperty[0].Value -or
            $hashProperty.Count -ne 1 -or $null -ne $hashProperty[0].Value) {
            throw "$Label non-Heist proof must retain exact null Heist-only fields."
        }
    }
}


function Assert-CanonicalFixedProofShape {
    param(
        [Parameter(Mandatory = $true)]$Proof,
        [Parameter(Mandatory = $true)][string]$Label
    )
    Assert-LocalExactPropertyNames -InputObject $Proof -Expected @(
        'evidence_role', 'deterministic', 'isolated_profiles',
        'run_1_proof_sha256', 'run_2_proof_sha256',
        'transcript_sha256', 'money_curve_sha256', 'persistence_checkpoint_sha256',
        'final_public_checkpoint_sha256', 'heist_seed_preflight_sha256'
    ) -Label $Label
    $evidenceRole = Get-ExactValueNoEnumerate $Proof @('evidence_role') $null
    $deterministic = Get-ExactValueNoEnumerate $Proof @('deterministic') $null
    $isolatedProfiles = Get-ExactValueNoEnumerate $Proof @('isolated_profiles') $null
    if ($evidenceRole -isnot [string] -or $evidenceRole -cne 'fixed-repeat' -or
        $deterministic -isnot [bool] -or -not $deterministic -or
        $isolatedProfiles -isnot [bool] -or -not $isolatedProfiles) {
        throw "$Label has an invalid exact role or Boolean qualification field."
    }
    foreach ($name in @(
        'run_1_proof_sha256', 'run_2_proof_sha256',
        'transcript_sha256', 'money_curve_sha256', 'persistence_checkpoint_sha256',
        'final_public_checkpoint_sha256'
    )) {
        $value = Get-ExactValueNoEnumerate $Proof @($name) $null
        if ($value -isnot [string] -or $value -cnotmatch '^[a-f0-9]{64}$') {
            throw "$Label field '$name' is not one exact lowercase SHA-256."
        }
    }
    $heistHash = Get-ExactValueNoEnumerate $Proof @('heist_seed_preflight_sha256') $null
    if ($Ending -ceq 'heist') {
        if ($heistHash -isnot [string] -or $heistHash -cnotmatch '^[a-f0-9]{64}$') {
            throw "$Label has no exact Heist seed-preflight SHA-256."
        }
    }
    else {
        $hashProperty = @($Proof.PSObject.Properties | Where-Object { $_.Name -ceq 'heist_seed_preflight_sha256' })
        if ($hashProperty.Count -ne 1 -or $null -ne $hashProperty[0].Value) {
            throw "$Label non-Heist canonical proof must retain exact null Heist-only evidence."
        }
    }
}


function Compare-FixedRunProofs {
    param([Parameter(Mandatory = $true)]$Proofs)
    if ($Proofs -isnot [object[]] -or $Proofs.Count -ne 2) {
        $observedCount = if ($Proofs -is [object[]]) { $Proofs.Count } else { -1 }
        throw "Fixed-repeat qualification requires one exact two-element Object[]; observed count $observedCount."
    }
    for ($index = 0; $index -lt $Proofs.Count; $index++) {
        Assert-FixedRunProofShape `
            -Proof $Proofs[$index] `
            -ExpectedRunIndex ($index + 1) `
            -Label "Fixed-route run proof $($index + 1)"
    }
    $first = $Proofs[0]
    $second = $Proofs[1]
    $expectedIdentity = [ordered]@{
        role = 'fixed_route_repeat'
        evidence_role = 'fixed-repeat'
        ending = $Ending
        seed = $Seed
    }
    $requiredHashFields = @(
        'profile_inventory_sha256', 'autosave_sha256', 'replay_summary_sha256',
        'launcher_stdout_sha256', 'launcher_stderr_sha256', 'run_summary_sha256',
        'transcript_sha256', 'money_curve_sha256',
        'persistence_checkpoint_before_sha256', 'persistence_checkpoint_after_sha256',
        'final_public_checkpoint_sha256', 'source_custody_pre_sha256', 'godot_stdout_sha256',
        'godot_stderr_sha256', 'godot_engine_sha256'
    )
    $requiredPathFields = @(
        'profile_roaming', 'profile_local', 'profile_session_root', 'profile_inventory',
        'autosave', 'replay_invocation_root', 'replay_summary', 'launcher_stdout',
        'launcher_stderr', 'run_root', 'run_summary', 'session_root', 'source_custody_pre'
    )
    foreach ($proof in $Proofs) {
        foreach ($entry in $expectedIdentity.GetEnumerator()) {
            $value = Get-ExactValueNoEnumerate $proof @([string]$entry.Key) $null
            if ($value -isnot [string] -or $value -cne [string]$entry.Value) {
                throw "A fixed-route proof has an invalid exact identity field '$($entry.Key)'."
            }
        }
        foreach ($property in $requiredHashFields) {
            $value = Get-ExactValueNoEnumerate $proof @($property) $null
            if ($value -isnot [string] -or $value -cnotmatch '^[a-f0-9]{64}$') {
                throw "A fixed-route proof has an invalid exact hash field '$property'."
            }
        }
        foreach ($property in $requiredPathFields) {
            $value = Get-ExactValueNoEnumerate $proof @($property) $null
            if ($value -isnot [string] -or [string]::IsNullOrWhiteSpace($value)) {
                throw "A fixed-route proof has an invalid exact path field '$property'."
            }
        }
        $proofSession = Get-ExactValueNoEnumerate $proof @('session') $null
        $proofPid = Get-ExactValueNoEnumerate $proof @('replay_pid') $null
        if ($proofSession -isnot [string] -or [string]::IsNullOrWhiteSpace($proofSession) -or
            $proofPid -isnot [int32] -or [int]$proofPid -le 0) {
            throw 'A fixed-route proof has an invalid exact session or replay PID.'
        }
        $checkpointBefore = Get-ExactValueNoEnumerate $proof @('persistence_checkpoint_before_sha256') $null
        $checkpointAfter = Get-ExactValueNoEnumerate $proof @('persistence_checkpoint_after_sha256') $null
        if ($checkpointBefore -cne $checkpointAfter) {
            throw 'A fixed-route proof did not retain equal persistence checkpoint hashes.'
        }
        $heistPreflightPath = Get-ExactValueNoEnumerate $proof @('heist_seed_preflight') $null
        $heistPreflightHash = Get-ExactValueNoEnumerate $proof @('heist_seed_preflight_sha256') $null
        if ($Ending -ceq 'heist') {
            if ($heistPreflightPath -isnot [string] -or [string]::IsNullOrWhiteSpace($heistPreflightPath) -or
                $heistPreflightHash -isnot [string] -or $heistPreflightHash -cnotmatch '^[a-f0-9]{64}$') {
                throw 'A Heist fixed-route proof omitted its exact retained seed-preflight artifact.'
            }
        }
        elseif ($null -ne $heistPreflightPath -or $null -ne $heistPreflightHash) {
            throw 'A non-Heist fixed-route proof published a Heist seed-preflight artifact.'
        }
    }
    $canonicalHashFields = @(
        'transcript_sha256', 'money_curve_sha256', 'final_public_checkpoint_sha256',
        'persistence_checkpoint_before_sha256', 'persistence_checkpoint_after_sha256',
        'source_custody_pre_sha256'
    )
    if ($Ending -ceq 'heist') { $canonicalHashFields += 'heist_seed_preflight_sha256' }
    foreach ($property in $canonicalHashFields) {
        $firstValue = Get-ExactValueNoEnumerate $first @($property) $null
        $secondValue = Get-ExactValueNoEnumerate $second @($property) $null
        if ($firstValue -isnot [string] -or $secondValue -isnot [string] -or
            $firstValue -cnotmatch '^[a-f0-9]{64}$' -or $firstValue -cne $secondValue) {
            throw "Independent fixed-route profiles differ at canonical evidence field '$property'."
        }
    }
    foreach ($property in @('outcome', 'action_count')) {
        $firstValue = Get-ExactValueNoEnumerate $first @($property) $null
        $secondValue = Get-ExactValueNoEnumerate $second @($property) $null
        if (($property -ceq 'outcome' -and
                ($firstValue -isnot [string] -or $secondValue -isnot [string])) -or
            ($property -ceq 'action_count' -and
                ($firstValue -isnot [int32] -or $secondValue -isnot [int32])) -or
            $firstValue -cne $secondValue) {
            throw "Independent fixed-route profiles differ at canonical run field '$property'."
        }
    }
    foreach ($property in @(
        'profile_roaming', 'profile_local', 'session', 'session_root',
        'replay_invocation_root', 'run_root', 'profile_session_root',
        'profile_inventory', 'autosave', 'launcher_stdout', 'launcher_stderr',
        'run_summary', 'heist_seed_preflight'
    )) {
        $firstValue = Get-ExactValueNoEnumerate $first @($property) $null
        $secondValue = Get-ExactValueNoEnumerate $second @($property) $null
        if ($Ending -cne 'heist' -and $property -ceq 'heist_seed_preflight') { continue }
        if ($firstValue -isnot [string] -or $secondValue -isnot [string] -or
            $firstValue.Equals($secondValue, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Fixed-repeat runs did not use distinct exact values for '$property'."
        }
    }
    $firstProofSha256 = Get-CanonicalExactObjectSha256 `
        -InputObject $first `
        -Label 'Fixed-route run 1 complete proof'
    $secondProofSha256 = Get-CanonicalExactObjectSha256 `
        -InputObject $second `
        -Label 'Fixed-route run 2 complete proof'
    $canonicalProof = [pscustomobject][ordered]@{
        evidence_role = 'fixed-repeat'
        deterministic = $true
        isolated_profiles = $true
        run_1_proof_sha256 = $firstProofSha256
        run_2_proof_sha256 = $secondProofSha256
        transcript_sha256 = $first.transcript_sha256
        money_curve_sha256 = $first.money_curve_sha256
        persistence_checkpoint_sha256 = $first.persistence_checkpoint_before_sha256
        final_public_checkpoint_sha256 = $first.final_public_checkpoint_sha256
        heist_seed_preflight_sha256 = if ($Ending -ceq 'heist') { $first.heist_seed_preflight_sha256 } else { $null }
    }
    Assert-CanonicalFixedProofShape -Proof $canonicalProof -Label 'Canonical fixed-repeat proof'
    return $canonicalProof
}


function Test-FixedRepeatQualification {
    param(
        [AllowNull()]$TerminalError,
        [AllowNull()]$Outcome,
        [AllowNull()]$RunProofs,
        [AllowNull()]$CanonicalProof,
        [AllowNull()]$LeaseOwned,
        [AllowNull()]$FinalProcessCensus,
        [AllowNull()]$FinalHead,
        [AllowNull()]$FinalTree,
        [AllowNull()]$SourceCustodyComplete
    )
    if ($null -ne $TerminalError -or
        $Outcome -isnot [string] -or $Outcome -cne 'green' -or
        $RunProofs -isnot [object[]] -or $RunProofs.Count -ne 2 -or
        -not (Test-ExactPsCustomObject -Value $CanonicalProof) -or
        $FinalProcessCensus -isnot [object[]] -or $FinalProcessCensus.Count -ne 0 -or
        $FinalHead -isnot [string] -or $FinalHead -cne $ExpectedHead.ToLowerInvariant() -or
        $FinalTree -isnot [string] -or $FinalTree -cne $ExpectedTree.ToLowerInvariant() -or
        $LeaseOwned -isnot [bool] -or $LeaseOwned -or
        $SourceCustodyComplete -isnot [bool] -or -not $SourceCustodyComplete) {
        return $false
    }
    $proofArray = @($RunProofs)
    try {
        for ($index = 0; $index -lt $proofArray.Count; $index++) {
            Assert-FixedRunProofShape `
                -Proof $proofArray[$index] `
                -ExpectedRunIndex ($index + 1) `
                -Label "Qualification run proof $($index + 1)"
        }
        Assert-CanonicalFixedProofShape -Proof $CanonicalProof -Label 'Qualification canonical proof'
        $recomputedCanonicalProof = Compare-FixedRunProofs -Proofs $proofArray
        if ((ConvertTo-CanonicalExactObjectJson -InputObject $CanonicalProof -Label 'Published canonical fixed-repeat proof') -cne
            (ConvertTo-CanonicalExactObjectJson -InputObject $recomputedCanonicalProof -Label 'Recomputed canonical fixed-repeat proof')) {
            return $false
        }
    }
    catch {
        return $false
    }
    return $true
}


function Assert-TerminalRecordKeys {
    param(
        [Parameter(Mandatory = $true)]$Record,
        [Parameter(Mandatory = $true)][string[]]$Expected,
        [Parameter(Mandatory = $true)][ValidateSet('ordered', 'json')][string]$Representation,
        [Parameter(Mandatory = $true)][string]$Label
    )
    if ($Representation -ceq 'ordered') {
        if ($null -eq $Record -or
            $Record.GetType().FullName -cne 'System.Collections.Specialized.OrderedDictionary') {
            throw "$Label must be one exact in-memory ordered dictionary."
        }
        $actual = @($Record.Keys | ForEach-Object { [string]$_ })
    }
    else {
        if (-not (Test-ExactPsCustomObject -Value $Record)) {
            throw "$Label must be one exact retained JSON object."
        }
        $actual = @($Record.PSObject.Properties | ForEach-Object { [string]$_.Name })
    }
    if ($actual.Count -ne $Expected.Count) {
        throw "$Label key count drifted: expected $($Expected.Count), observed $($actual.Count)."
    }
    for ($index = 0; $index -lt $Expected.Count; $index++) {
        if ($actual[$index] -cne $Expected[$index]) {
            throw "$Label key order/name drifted at index $index; expected '$($Expected[$index])', observed '$($actual[$index])'."
        }
    }
}


function Test-ExactLowerHexOrEmpty {
    param(
        [AllowNull()]$Value,
        [Parameter(Mandatory = $true)][ValidateSet(40, 64)][int]$Length
    )
    if ($Value -isnot [string]) { return $false }
    if ($Value.Length -eq 0) { return $true }
    return $Value -cmatch ('^[a-f0-9]{' + $Length + '}$')
}


function Assert-TerminalProcessCensusRowShape {
    param(
        [Parameter(Mandatory = $true)]$Row,
        [Parameter(Mandatory = $true)][ValidateSet('ordered', 'json')][string]$Representation,
        [Parameter(Mandatory = $true)][string]$Label
    )
    Assert-TerminalRecordKeys `
        -Record $Row `
        -Expected @('pid', 'parent_pid', 'name', 'command_line') `
        -Representation $Representation `
        -Label $Label
    $pidValue = Get-ExactValueNoEnumerate $Row @('pid') $null
    $parentPid = Get-ExactValueNoEnumerate $Row @('parent_pid') $null
    $name = Get-ExactValueNoEnumerate $Row @('name') $null
    $commandLine = Get-ExactValueNoEnumerate $Row @('command_line') $null
    if ($pidValue -isnot [int32] -or $pidValue -le 0 -or
        $parentPid -isnot [int32] -or $parentPid -lt 0 -or
        $name -isnot [string] -or [string]::IsNullOrWhiteSpace($name) -or
        $commandLine -isnot [string]) {
        throw "$Label has an invalid exact process-census scalar."
    }
}


function Assert-TerminalSurvivorRowShape {
    param(
        [Parameter(Mandatory = $true)]$Row,
        [Parameter(Mandatory = $true)][ValidateSet('ordered', 'json')][string]$Representation,
        [Parameter(Mandatory = $true)][string]$Label
    )
    $kind = Get-ExactValueNoEnumerate $Row @('kind') $null
    if ($kind -isnot [string]) { throw "$Label kind is not one exact string." }
    $expectedKeys = if ($kind -ceq 'godot') {
        @('kind', 'pid', 'command_line')
    }
    elseif ($kind -cin @('replay', 'unverified_replay_pid', 'unregistered_replay')) {
        @('kind', 'pid', 'session_prefix')
    }
    else {
        throw "$Label has an unknown exact survivor kind."
    }
    Assert-TerminalRecordKeys -Record $Row -Expected $expectedKeys -Representation $Representation -Label $Label
    $pidValue = Get-ExactValueNoEnumerate $Row @('pid') $null
    if ($pidValue -isnot [int32] -or $pidValue -le 0) {
        throw "$Label pid is not one exact positive Int32."
    }
    if ($kind -ceq 'godot') {
        $commandLine = Get-ExactValueNoEnumerate $Row @('command_line') $null
        if ($commandLine -isnot [string]) { throw "$Label command_line is not one exact string." }
    }
    else {
        $sessionPrefix = Get-ExactValueNoEnumerate $Row @('session_prefix') $null
        if ($sessionPrefix -isnot [string] -or [string]::IsNullOrWhiteSpace($sessionPrefix)) {
            throw "$Label session_prefix is not one exact nonempty string."
        }
    }
}


function Assert-TerminalArtifactRowShape {
    param(
        [Parameter(Mandatory = $true)]$Row,
        [Parameter(Mandatory = $true)][ValidateSet('ordered', 'json')][string]$Representation,
        [Parameter(Mandatory = $true)][string]$Label
    )
    Assert-TerminalRecordKeys `
        -Record $Row `
        -Expected @('path', 'sha256') `
        -Representation $Representation `
        -Label $Label
    $path = Get-ExactValueNoEnumerate $Row @('path') $null
    $sha256 = Get-ExactValueNoEnumerate $Row @('sha256') $null
    if ($path -isnot [string] -or [string]::IsNullOrWhiteSpace($path) -or
        -not [IO.Path]::IsPathRooted($path) -or [IO.Path]::GetFullPath($path) -cne $path -or
        $sha256 -isnot [string] -or $sha256 -cnotmatch '^[a-f0-9]{64}$') {
        throw "$Label has an invalid exact artifact path or SHA-256."
    }
}


function Assert-TerminalAggregateShape {
    param(
        [Parameter(Mandatory = $true)]$Record,
        [Parameter(Mandatory = $true)][ValidateSet('ordered', 'json')][string]$Representation,
        [Parameter(Mandatory = $true)][string]$Label
    )
    Assert-TerminalRecordKeys -Record $Record -Expected @(
        'schema_version', 'check_id', 'role', 'evidence_role', 'ending', 'seed', 'repeat',
        'outcome', 'error', 'expected_head', 'expected_tree', 'observed_head', 'observed_tree',
        'independent_profiles', 'fresh_interactive_authorized', 'q017_status', 'deterministic',
        'fixed_repeat_qualifying', 'source_custody_complete', 'source_custody_pre_sha256',
        'source_custody_final_sha256', 'canonical_proof', 'runs', 'evidence_root'
    ) -Representation $Representation -Label $Label

    $schemaVersion = Get-ExactValueNoEnumerate $Record @('schema_version') $null
    $checkId = Get-ExactValueNoEnumerate $Record @('check_id') $null
    $role = Get-ExactValueNoEnumerate $Record @('role') $null
    $evidenceRole = Get-ExactValueNoEnumerate $Record @('evidence_role') $null
    $recordEnding = Get-ExactValueNoEnumerate $Record @('ending') $null
    $recordSeed = Get-ExactValueNoEnumerate $Record @('seed') $null
    $repeatValue = Get-ExactValueNoEnumerate $Record @('repeat') $null
    $outcome = Get-ExactValueNoEnumerate $Record @('outcome') $null
    $errorValue = Get-ExactValueNoEnumerate $Record @('error') $null
    $expectedHeadValue = Get-ExactValueNoEnumerate $Record @('expected_head') $null
    $expectedTreeValue = Get-ExactValueNoEnumerate $Record @('expected_tree') $null
    $observedHead = Get-ExactValueNoEnumerate $Record @('observed_head') $null
    $observedTree = Get-ExactValueNoEnumerate $Record @('observed_tree') $null
    $independentProfiles = Get-ExactValueNoEnumerate $Record @('independent_profiles') $null
    $freshInteractiveAuthorized = Get-ExactValueNoEnumerate $Record @('fresh_interactive_authorized') $null
    $q017Status = Get-ExactValueNoEnumerate $Record @('q017_status') $null
    $deterministic = Get-ExactValueNoEnumerate $Record @('deterministic') $null
    $qualifying = Get-ExactValueNoEnumerate $Record @('fixed_repeat_qualifying') $null
    $custodyComplete = Get-ExactValueNoEnumerate $Record @('source_custody_complete') $null
    $preHash = Get-ExactValueNoEnumerate $Record @('source_custody_pre_sha256') $null
    $finalHash = Get-ExactValueNoEnumerate $Record @('source_custody_final_sha256') $null
    $canonicalProof = Get-ExactValueNoEnumerate $Record @('canonical_proof') $null
    $runs = Get-ExactValueNoEnumerate $Record @('runs') $null
    $recordRoot = Get-ExactValueNoEnumerate $Record @('evidence_root') $null
    $expectedQ017Status = if ($Ending -ceq 'heist') { 'ANSWERED_SEPARATE_FRESH_INTERACTIVE_SCOPE' } else { 'NOT_APPLICABLE' }
    $expectedError = Get-FailureMessage -Failure $script:TerminalError
    $recomputedCanonicalProof = $null
    if ($null -ne $script:CanonicalProof -or ($qualifying -is [bool] -and $qualifying)) {
        $recomputedCanonicalProof = Compare-FixedRunProofs -Proofs @($script:RunProofs)
        Assert-CanonicalFixedProofShape -Proof $script:CanonicalProof -Label 'Held canonical proof at terminal publication'
        if ((ConvertTo-CanonicalExactObjectJson -InputObject $script:CanonicalProof -Label 'Held canonical proof at terminal publication') -cne
            (ConvertTo-CanonicalExactObjectJson -InputObject $recomputedCanonicalProof -Label 'Freshly recomputed canonical proof at terminal publication')) {
            throw "$Label held canonical proof differs from the freshly recomputed run-proof authority."
        }
    }
    $expectedIndependent = if ($null -ne $recomputedCanonicalProof) { $recomputedCanonicalProof.isolated_profiles } else { $false }
    $expectedDeterministic = if ($null -ne $recomputedCanonicalProof) { $recomputedCanonicalProof.deterministic } else { $false }
    if ($schemaVersion -isnot [int32] -or $schemaVersion -ne 1 -or
        $checkId -isnot [string] -or $checkId -cne 'rw06_2_final_evidence' -or
        $role -isnot [string] -or $role -cne 'fixed_route_repeat' -or
        $evidenceRole -isnot [string] -or $evidenceRole -cne 'fixed-repeat' -or
        $recordEnding -isnot [string] -or $recordEnding -cne $Ending -or
        $recordSeed -isnot [string] -or $recordSeed -cne $Seed -or
        $repeatValue -isnot [int32] -or $repeatValue -ne 2 -or
        $outcome -isnot [string] -or $outcome -cne $script:Outcome -or
        $errorValue -isnot [string] -or $errorValue -cne $expectedError -or
        $expectedHeadValue -isnot [string] -or $expectedHeadValue -cne $ExpectedHead.ToLowerInvariant() -or
        $expectedTreeValue -isnot [string] -or $expectedTreeValue -cne $ExpectedTree.ToLowerInvariant() -or
        $observedHead -isnot [string] -or $observedHead -cne $script:FinalHead -or
        $observedTree -isnot [string] -or $observedTree -cne $script:FinalTree -or
        $independentProfiles -isnot [bool] -or $independentProfiles -ne $expectedIndependent -or
        $freshInteractiveAuthorized -isnot [bool] -or $freshInteractiveAuthorized -or
        $q017Status -isnot [string] -or $q017Status -cne $expectedQ017Status -or
        $deterministic -isnot [bool] -or $deterministic -ne $expectedDeterministic -or
        $qualifying -isnot [bool] -or $qualifying -ne $fixedRepeatQualifying -or
        $custodyComplete -isnot [bool] -or $custodyComplete -ne $script:SourceCustodyComplete -or
        -not (Test-ExactLowerHexOrEmpty -Value $observedHead -Length 40) -or
        -not (Test-ExactLowerHexOrEmpty -Value $observedTree -Length 40) -or
        -not (Test-ExactLowerHexOrEmpty -Value $preHash -Length 64) -or
        -not (Test-ExactLowerHexOrEmpty -Value $finalHash -Length 64) -or
        $preHash -cne $script:SourceCustodyPreSha256 -or
        $finalHash -cne $script:SourceCustodyFinalSha256 -or
        $runs -isnot [object[]] -or $runs.Count -ne $script:RunProofs.Count -or
        $recordRoot -isnot [string] -or $recordRoot -cne $EvidenceRoot) {
        throw "$Label has an invalid exact aggregate scalar or cross-binding."
    }

    if ($null -eq $recomputedCanonicalProof) {
        if ($null -ne $canonicalProof) { throw "$Label publishes an unexpected canonical proof." }
    }
    else {
        Assert-CanonicalFixedProofShape -Proof $canonicalProof -Label "$Label canonical proof"
        if ((ConvertTo-CanonicalExactObjectJson -InputObject $canonicalProof -Label "$Label canonical proof") -cne
            (ConvertTo-CanonicalExactObjectJson -InputObject $recomputedCanonicalProof -Label 'Freshly recomputed canonical proof at terminal publication')) {
            throw "$Label canonical proof differs from the freshly recomputed run-proof authority."
        }
    }
    for ($index = 0; $index -lt $runs.Count; $index++) {
        Assert-FixedRunProofShape -Proof $runs[$index] -ExpectedRunIndex ($index + 1) -Label "$Label run $($index + 1)"
        if ((ConvertTo-CanonicalExactObjectJson -InputObject $runs[$index] -Label "$Label run $($index + 1)") -cne
            (ConvertTo-CanonicalExactObjectJson -InputObject $script:RunProofs[$index] -Label "Held run $($index + 1)")) {
            throw "$Label run $($index + 1) differs from the held proof."
        }
    }
    if ($qualifying -and
        ($outcome -cne 'green' -or $errorValue.Length -ne 0 -or -not $custodyComplete -or
            $observedHead -cne $expectedHeadValue -or $observedTree -cne $expectedTreeValue -or
            -not $independentProfiles -or -not $deterministic -or $runs.Count -ne 2 -or
            $null -eq $recomputedCanonicalProof -or
            $preHash -cnotmatch '^[a-f0-9]{64}$' -or $finalHash -cnotmatch '^[a-f0-9]{64}$')) {
        throw "$Label marks a nonqualifying aggregate state as qualifying."
    }
}


function Assert-TerminalMetadataShape {
    param(
        [Parameter(Mandatory = $true)]$Record,
        [Parameter(Mandatory = $true)][ValidateSet('ordered', 'json')][string]$Representation,
        [Parameter(Mandatory = $true)][string]$Label
    )
    Assert-TerminalRecordKeys -Record $Record -Expected @(
        'lane', 'kind', 'ending', 'seed', 'role', 'evidence_role', 'outcome', 'error',
        'expected_head', 'expected_tree', 'observed_head', 'observed_tree', 'launcher_snapshot',
        'launcher_initial_sha256', 'launcher_current_sha256', 'source_custody_pre',
        'source_custody_pre_sha256', 'source_custody_final', 'source_custody_final_sha256',
        'source_custody_complete', 'initial_process_census', 'final_process_census',
        'owned_processes_remaining', 'lease_path', 'lease_removed', 'fixed_repeat_qualifying',
        'started', 'completed'
    ) -Representation $Representation -Label $Label
    $lane = Get-ExactValueNoEnumerate $Record @('lane') $null
    $kind = Get-ExactValueNoEnumerate $Record @('kind') $null
    $recordEnding = Get-ExactValueNoEnumerate $Record @('ending') $null
    $recordSeed = Get-ExactValueNoEnumerate $Record @('seed') $null
    $role = Get-ExactValueNoEnumerate $Record @('role') $null
    $evidenceRole = Get-ExactValueNoEnumerate $Record @('evidence_role') $null
    $outcome = Get-ExactValueNoEnumerate $Record @('outcome') $null
    $errorValue = Get-ExactValueNoEnumerate $Record @('error') $null
    $expectedHeadValue = Get-ExactValueNoEnumerate $Record @('expected_head') $null
    $expectedTreeValue = Get-ExactValueNoEnumerate $Record @('expected_tree') $null
    $observedHead = Get-ExactValueNoEnumerate $Record @('observed_head') $null
    $observedTree = Get-ExactValueNoEnumerate $Record @('observed_tree') $null
    $launcherSnapshot = Get-ExactValueNoEnumerate $Record @('launcher_snapshot') $null
    $launcherInitialHash = Get-ExactValueNoEnumerate $Record @('launcher_initial_sha256') $null
    $launcherCurrentHash = Get-ExactValueNoEnumerate $Record @('launcher_current_sha256') $null
    $prePath = Get-ExactValueNoEnumerate $Record @('source_custody_pre') $null
    $preHash = Get-ExactValueNoEnumerate $Record @('source_custody_pre_sha256') $null
    $finalPath = Get-ExactValueNoEnumerate $Record @('source_custody_final') $null
    $finalHash = Get-ExactValueNoEnumerate $Record @('source_custody_final_sha256') $null
    $custodyComplete = Get-ExactValueNoEnumerate $Record @('source_custody_complete') $null
    $initialCensus = Get-ExactValueNoEnumerate $Record @('initial_process_census') $null
    $finalCensus = Get-ExactValueNoEnumerate $Record @('final_process_census') $null
    $ownedRemaining = Get-ExactValueNoEnumerate $Record @('owned_processes_remaining') $null
    $leasePathValue = Get-ExactValueNoEnumerate $Record @('lease_path') $null
    $leaseRemoved = Get-ExactValueNoEnumerate $Record @('lease_removed') $null
    $qualifying = Get-ExactValueNoEnumerate $Record @('fixed_repeat_qualifying') $null
    $started = Get-ExactValueNoEnumerate $Record @('started') $null
    $completed = Get-ExactValueNoEnumerate $Record @('completed') $null
    if ($lane -isnot [string] -or $lane -cne 'rw06_2p' -or
        $kind -isnot [string] -or $kind -cne 'exclusive-real-input-fixed-repeat-final-evidence' -or
        $recordEnding -isnot [string] -or $recordEnding -cne $Ending -or
        $recordSeed -isnot [string] -or $recordSeed -cne $Seed -or
        $role -isnot [string] -or $role -cne 'fixed_route_repeat' -or
        $evidenceRole -isnot [string] -or $evidenceRole -cne 'fixed-repeat' -or
        $outcome -isnot [string] -or $outcome -cne $script:Outcome -or
        $errorValue -isnot [string] -or $errorValue -cne (Get-FailureMessage -Failure $script:TerminalError) -or
        $expectedHeadValue -isnot [string] -or $expectedHeadValue -cne $ExpectedHead.ToLowerInvariant() -or
        $expectedTreeValue -isnot [string] -or $expectedTreeValue -cne $ExpectedTree.ToLowerInvariant() -or
        $observedHead -isnot [string] -or $observedHead -cne $script:FinalHead -or
        $observedTree -isnot [string] -or $observedTree -cne $script:FinalTree -or
        $launcherSnapshot -isnot [string] -or $launcherSnapshot -cne $LauncherSnapshotPath -or
        -not (Test-ExactLowerHexOrEmpty -Value $launcherInitialHash -Length 64) -or
        -not (Test-ExactLowerHexOrEmpty -Value $launcherCurrentHash -Length 64) -or
        $launcherInitialHash -cne $script:LauncherInitialSha256 -or
        $launcherCurrentHash -cne $script:LauncherCurrentSha256 -or
        $prePath -isnot [string] -or $prePath -cne $SourceCustodyPrePath -or
        $finalPath -isnot [string] -or $finalPath -cne $SourceCustodyFinalPath -or
        -not (Test-ExactLowerHexOrEmpty -Value $preHash -Length 64) -or
        -not (Test-ExactLowerHexOrEmpty -Value $finalHash -Length 64) -or
        $preHash -cne $script:SourceCustodyPreSha256 -or
        $finalHash -cne $script:SourceCustodyFinalSha256 -or
        $custodyComplete -isnot [bool] -or $custodyComplete -ne $script:SourceCustodyComplete -or
        $initialCensus -isnot [object[]] -or $finalCensus -isnot [object[]] -or
        $ownedRemaining -isnot [object[]] -or
        $leasePathValue -isnot [string] -or $leasePathValue -cne $LeasePath -or
        $leaseRemoved -isnot [bool] -or
        $qualifying -isnot [bool] -or $qualifying -ne $fixedRepeatQualifying -or
        $started -isnot [string] -or [string]::IsNullOrWhiteSpace($started) -or
        $completed -isnot [string] -or [string]::IsNullOrWhiteSpace($completed)) {
        throw "$Label has an invalid exact metadata scalar or cross-binding."
    }
    for ($index = 0; $index -lt $initialCensus.Count; $index++) {
        Assert-TerminalProcessCensusRowShape -Row $initialCensus[$index] -Representation $Representation -Label "$Label initial census row $index"
    }
    for ($index = 0; $index -lt $finalCensus.Count; $index++) {
        Assert-TerminalProcessCensusRowShape -Row $finalCensus[$index] -Representation $Representation -Label "$Label final census row $index"
    }
    for ($index = 0; $index -lt $ownedRemaining.Count; $index++) {
        Assert-TerminalSurvivorRowShape -Row $ownedRemaining[$index] -Representation $Representation -Label "$Label survivor row $index"
    }
    if ($qualifying -and
        ($initialCensus.Count -ne 0 -or $finalCensus.Count -ne 0 -or $ownedRemaining.Count -ne 0 -or -not $leaseRemoved -or
            -not $custodyComplete -or $observedHead -cne $expectedHeadValue -or
            $observedTree -cne $expectedTreeValue -or $launcherInitialHash -cnotmatch '^[a-f0-9]{64}$' -or
            $launcherCurrentHash -cne $launcherInitialHash -or $preHash -cnotmatch '^[a-f0-9]{64}$' -or
            $finalHash -cnotmatch '^[a-f0-9]{64}$')) {
        throw "$Label marks a nonqualifying metadata state as qualifying."
    }
}


function Assert-TerminalManifestShape {
    param(
        [Parameter(Mandatory = $true)]$Record,
        [Parameter(Mandatory = $true)][ValidateSet('ordered', 'json')][string]$Representation,
        [Parameter(Mandatory = $true)][string]$Label
    )
    Assert-TerminalRecordKeys -Record $Record -Expected @(
        'schema_version', 'check_id', 'role', 'evidence_role', 'ending', 'seed',
        'fixed_repeat_qualifying', 'evidence_root', 'artifact_count', 'artifacts'
    ) -Representation $Representation -Label $Label
    $schemaVersion = Get-ExactValueNoEnumerate $Record @('schema_version') $null
    $checkId = Get-ExactValueNoEnumerate $Record @('check_id') $null
    $role = Get-ExactValueNoEnumerate $Record @('role') $null
    $evidenceRole = Get-ExactValueNoEnumerate $Record @('evidence_role') $null
    $recordEnding = Get-ExactValueNoEnumerate $Record @('ending') $null
    $recordSeed = Get-ExactValueNoEnumerate $Record @('seed') $null
    $qualifying = Get-ExactValueNoEnumerate $Record @('fixed_repeat_qualifying') $null
    $recordRoot = Get-ExactValueNoEnumerate $Record @('evidence_root') $null
    $artifactCount = Get-ExactValueNoEnumerate $Record @('artifact_count') $null
    $artifacts = Get-ExactValueNoEnumerate $Record @('artifacts') $null
    if ($schemaVersion -isnot [int32] -or $schemaVersion -ne 1 -or
        $checkId -isnot [string] -or $checkId -cne 'rw06_2_final_evidence_manifest' -or
        $role -isnot [string] -or $role -cne 'fixed_route_repeat' -or
        $evidenceRole -isnot [string] -or $evidenceRole -cne 'fixed-repeat' -or
        $recordEnding -isnot [string] -or $recordEnding -cne $Ending -or
        $recordSeed -isnot [string] -or $recordSeed -cne $Seed -or
        $qualifying -isnot [bool] -or $qualifying -ne $fixedRepeatQualifying -or
        $recordRoot -isnot [string] -or $recordRoot -cne $EvidenceRoot -or
        $artifactCount -isnot [int32] -or $artifactCount -lt 0 -or
        $artifacts -isnot [object[]] -or $artifacts.Count -ne $artifactCount) {
        throw "$Label has an invalid exact manifest scalar or cross-binding."
    }
    $seenPaths = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $priorPath = $null
    for ($index = 0; $index -lt $artifacts.Count; $index++) {
        $row = $artifacts[$index]
        Assert-TerminalArtifactRowShape -Row $row -Representation $Representation -Label "$Label artifact row $index"
        $path = Get-ExactValueNoEnumerate $row @('path') $null
        if (-not $seenPaths.Add($path)) { throw "$Label contains a duplicate artifact path." }
        if ($null -ne $priorPath -and [string]::Compare($priorPath, $path, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
            throw "$Label artifact paths are not in exact unique case-insensitive ordinal order."
        }
        $priorPath = $path
    }
    if ($qualifying -and $artifacts.Count -eq 0) {
        throw "$Label marks an empty artifact manifest as qualifying."
    }
}


function Assert-TerminalResultShape {
    param(
        [Parameter(Mandatory = $true)]$Record,
        [Parameter(Mandatory = $true)][ValidateSet('ordered', 'json')][string]$Representation,
        [Parameter(Mandatory = $true)]$ExpectedAggregateSha256,
        [Parameter(Mandatory = $true)]$ExpectedMetadataSha256,
        [Parameter(Mandatory = $true)]$ExpectedManifestSha256,
        [Parameter(Mandatory = $true)][string]$Label
    )
    Assert-TerminalRecordKeys -Record $Record -Expected @(
        'evidence_root', 'outcome', 'fixed_repeat_qualifying', 'head', 'tree',
        'aggregate_summary_sha256', 'metadata_sha256', 'manifest_sha256',
        'source_custody_pre_sha256', 'source_custody_final_sha256'
    ) -Representation $Representation -Label $Label
    $recordRoot = Get-ExactValueNoEnumerate $Record @('evidence_root') $null
    $outcome = Get-ExactValueNoEnumerate $Record @('outcome') $null
    $qualifying = Get-ExactValueNoEnumerate $Record @('fixed_repeat_qualifying') $null
    $headValue = Get-ExactValueNoEnumerate $Record @('head') $null
    $treeValue = Get-ExactValueNoEnumerate $Record @('tree') $null
    $aggregateHash = Get-ExactValueNoEnumerate $Record @('aggregate_summary_sha256') $null
    $metadataHash = Get-ExactValueNoEnumerate $Record @('metadata_sha256') $null
    $manifestHash = Get-ExactValueNoEnumerate $Record @('manifest_sha256') $null
    $preHash = Get-ExactValueNoEnumerate $Record @('source_custody_pre_sha256') $null
    $finalHash = Get-ExactValueNoEnumerate $Record @('source_custody_final_sha256') $null
    if ($recordRoot -isnot [string] -or $recordRoot -cne $EvidenceRoot -or
        $outcome -isnot [string] -or $outcome -cne $script:Outcome -or
        $qualifying -isnot [bool] -or $qualifying -ne $fixedRepeatQualifying -or
        $headValue -isnot [string] -or $headValue -cne $script:FinalHead -or
        $treeValue -isnot [string] -or $treeValue -cne $script:FinalTree -or
        $ExpectedAggregateSha256 -isnot [string] -or $ExpectedAggregateSha256 -cnotmatch '^[a-f0-9]{64}$' -or
        $ExpectedMetadataSha256 -isnot [string] -or $ExpectedMetadataSha256 -cnotmatch '^[a-f0-9]{64}$' -or
        $ExpectedManifestSha256 -isnot [string] -or $ExpectedManifestSha256 -cnotmatch '^[a-f0-9]{64}$' -or
        $aggregateHash -isnot [string] -or $aggregateHash -cne $ExpectedAggregateSha256 -or
        $metadataHash -isnot [string] -or $metadataHash -cne $ExpectedMetadataSha256 -or
        $manifestHash -isnot [string] -or $manifestHash -cne $ExpectedManifestSha256 -or
        $preHash -isnot [string] -or $preHash -cne $script:SourceCustodyPreSha256 -or
        $finalHash -isnot [string] -or $finalHash -cne $script:SourceCustodyFinalSha256) {
        throw "$Label has an invalid exact result scalar or cross-binding."
    }
    if ($qualifying -and
        ($outcome -cne 'green' -or $headValue -cne $ExpectedHead.ToLowerInvariant() -or
            $treeValue -cne $ExpectedTree.ToLowerInvariant() -or
            $preHash -cnotmatch '^[a-f0-9]{64}$' -or $finalHash -cnotmatch '^[a-f0-9]{64}$')) {
        throw "$Label marks a nonqualifying terminal result as qualifying."
    }
}


function Get-ManifestArtifactPaths {
    $profilePrefixes = [Collections.Generic.List[string]]::new()
    foreach ($runIndex in 1..2) {
        $runRoot = Join-Path $EvidenceRoot ('run-{0:D2}' -f $runIndex)
        foreach ($profileName in @('profile_roaming', 'profile_local')) {
            $profilePrefixes.Add(([IO.Path]::GetFullPath((Join-Path $runRoot $profileName))).TrimEnd('\') + '\')
        }
    }
    $paths = @(Get-ChildItem -LiteralPath $EvidenceRoot -Recurse -File -ErrorAction Stop | Where-Object {
        $candidate = [IO.Path]::GetFullPath($_.FullName)
        $insideProfile = $false
        foreach ($prefix in $profilePrefixes) {
            if ($candidate.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
                $insideProfile = $true
                break
            }
        }
        -not $insideProfile -and $candidate -cne [IO.Path]::GetFullPath($ManifestPath)
    } | Select-Object -ExpandProperty FullName)
    foreach ($proof in @($script:RunProofs)) {
        foreach ($name in @('godot.stdout.log', 'godot.stderr.log', 'godot.engine.log')) {
            $path = Join-Path ([string]$proof.session_root) $name
            if (Test-Path -LiteralPath $path -PathType Leaf) { $paths += $path }
        }
        foreach ($profileArtifact in @([string]$proof.profile_inventory, [string]$proof.autosave)) {
            if (-not (Test-Path -LiteralPath $profileArtifact -PathType Leaf)) {
                throw "Required isolated profile artifact disappeared before manifest construction: $profileArtifact"
            }
            $paths += $profileArtifact
        }
    }
    $seenPaths = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $uniquePaths = [Collections.Generic.List[string]]::new()
    foreach ($path in $paths) {
        $canonicalPath = [IO.Path]::GetFullPath([string]$path)
        if ($seenPaths.Add($canonicalPath)) { $uniquePaths.Add($canonicalPath) }
    }
    $orderedPaths = $uniquePaths.ToArray()
    [Array]::Sort($orderedPaths, [StringComparer]::OrdinalIgnoreCase)
    return @($orderedPaths)
}


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


function Assert-FixedRunManifestArtifactBindings {
    param(
        [Parameter(Mandatory = $true)]$ArtifactRows,
        [Parameter(Mandatory = $true)]$Proof,
        [Parameter(Mandatory = $true)]$ExpectedRunIndex
    )
    if ($ExpectedRunIndex -isnot [int32] -or $ExpectedRunIndex -lt 1 -or $ExpectedRunIndex -gt 2) {
        throw 'Fixed-run manifest binding requires one exact Int32 run index in range 1..2.'
    }
    Assert-FixedRunProofShape `
        -Proof $Proof `
        -ExpectedRunIndex $ExpectedRunIndex `
        -Label "Run $ExpectedRunIndex manifest-binding proof"

    Assert-ManifestArtifactHash -ArtifactRows $ArtifactRows `
        -Path (Get-ExactValueNoEnumerate $Proof @('replay_summary') $null) `
        -ExpectedSha256 (Get-ExactValueNoEnumerate $Proof @('replay_summary_sha256') $null) `
        -Label "Run $ExpectedRunIndex replay summary"
    Assert-ManifestArtifactHash -ArtifactRows $ArtifactRows `
        -Path (Get-ExactValueNoEnumerate $Proof @('launcher_stdout') $null) `
        -ExpectedSha256 (Get-ExactValueNoEnumerate $Proof @('launcher_stdout_sha256') $null) `
        -Label "Run $ExpectedRunIndex outer launcher stdout"
    Assert-ManifestArtifactHash -ArtifactRows $ArtifactRows `
        -Path (Get-ExactValueNoEnumerate $Proof @('launcher_stderr') $null) `
        -ExpectedSha256 (Get-ExactValueNoEnumerate $Proof @('launcher_stderr_sha256') $null) `
        -Label "Run $ExpectedRunIndex outer launcher stderr"
    Assert-ManifestArtifactHash -ArtifactRows $ArtifactRows `
        -Path (Get-ExactValueNoEnumerate $Proof @('run_summary') $null) `
        -ExpectedSha256 (Get-ExactValueNoEnumerate $Proof @('run_summary_sha256') $null) `
        -Label "Run $ExpectedRunIndex retained run summary"
    Assert-ManifestArtifactHash -ArtifactRows $ArtifactRows `
        -Path (Get-ExactValueNoEnumerate $Proof @('profile_inventory') $null) `
        -ExpectedSha256 (Get-ExactValueNoEnumerate $Proof @('profile_inventory_sha256') $null) `
        -Label "Run $ExpectedRunIndex profile inventory"
    Assert-ManifestArtifactHash -ArtifactRows $ArtifactRows `
        -Path (Get-ExactValueNoEnumerate $Proof @('autosave') $null) `
        -ExpectedSha256 (Get-ExactValueNoEnumerate $Proof @('autosave_sha256') $null) `
        -Label "Run $ExpectedRunIndex profile autosave"
    Assert-ManifestArtifactHash -ArtifactRows $ArtifactRows `
        -Path (Join-Path (Get-ExactValueNoEnumerate $Proof @('run_root') $null) 'public_trace.ndjson') `
        -ExpectedSha256 (Get-ExactValueNoEnumerate $Proof @('transcript_sha256') $null) `
        -Label "Run $ExpectedRunIndex public trace"
    Assert-ManifestArtifactHash -ArtifactRows $ArtifactRows `
        -Path (Join-Path (Get-ExactValueNoEnumerate $Proof @('run_root') $null) 'money_curve.ndjson') `
        -ExpectedSha256 (Get-ExactValueNoEnumerate $Proof @('money_curve_sha256') $null) `
        -Label "Run $ExpectedRunIndex money curve"
    Assert-ManifestArtifactHash -ArtifactRows $ArtifactRows `
        -Path (Join-Path (Get-ExactValueNoEnumerate $Proof @('run_root') $null) 'checkpoint_before.json') `
        -ExpectedSha256 (Get-ExactValueNoEnumerate $Proof @('persistence_checkpoint_before_sha256') $null) `
        -Label "Run $ExpectedRunIndex persistence checkpoint before"
    Assert-ManifestArtifactHash -ArtifactRows $ArtifactRows `
        -Path (Join-Path (Get-ExactValueNoEnumerate $Proof @('run_root') $null) 'checkpoint_after.json') `
        -ExpectedSha256 (Get-ExactValueNoEnumerate $Proof @('persistence_checkpoint_after_sha256') $null) `
        -Label "Run $ExpectedRunIndex persistence checkpoint after"
    Assert-ManifestArtifactHash -ArtifactRows $ArtifactRows `
        -Path (Join-Path (Get-ExactValueNoEnumerate $Proof @('run_root') $null) 'final_public_checkpoint.json') `
        -ExpectedSha256 (Get-ExactValueNoEnumerate $Proof @('final_public_checkpoint_sha256') $null) `
        -Label "Run $ExpectedRunIndex final public checkpoint"
    Assert-ManifestArtifactHash -ArtifactRows $ArtifactRows `
        -Path (Join-Path (Get-ExactValueNoEnumerate $Proof @('session_root') $null) 'godot.stdout.log') `
        -ExpectedSha256 (Get-ExactValueNoEnumerate $Proof @('godot_stdout_sha256') $null) `
        -Label "Run $ExpectedRunIndex Godot stdout"
    Assert-ManifestArtifactHash -ArtifactRows $ArtifactRows `
        -Path (Join-Path (Get-ExactValueNoEnumerate $Proof @('session_root') $null) 'godot.stderr.log') `
        -ExpectedSha256 (Get-ExactValueNoEnumerate $Proof @('godot_stderr_sha256') $null) `
        -Label "Run $ExpectedRunIndex Godot stderr"
    Assert-ManifestArtifactHash -ArtifactRows $ArtifactRows `
        -Path (Join-Path (Get-ExactValueNoEnumerate $Proof @('session_root') $null) 'godot.engine.log') `
        -ExpectedSha256 (Get-ExactValueNoEnumerate $Proof @('godot_engine_sha256') $null) `
        -Label "Run $ExpectedRunIndex Godot engine log"
    if ($Ending -ceq 'heist') {
        Assert-ManifestArtifactHash -ArtifactRows $ArtifactRows `
            -Path (Get-ExactValueNoEnumerate $Proof @('heist_seed_preflight') $null) `
            -ExpectedSha256 (Get-ExactValueNoEnumerate $Proof @('heist_seed_preflight_sha256') $null) `
            -Label "Run $ExpectedRunIndex retained Heist seed preflight"
    }
}


if ($Ending -ceq 'heist' -and $Seed -cne 'RW06-HEIST-AUDIT-0002') {
    throw 'Q-013 fixed-repeat evidence requires exact Heist seed RW06-HEIST-AUDIT-0002.'
}
if (-not [IO.File]::Exists([IO.Path]::GetFullPath(
            [IO.Path]::Combine($PSScriptRoot, 'rw06_2_ending_replay.ps1')
        ))) {
    throw 'The exact checked-in replay tool is missing.'
}
if (-not (Test-Path -LiteralPath $EvidenceAdmissionTool -PathType Leaf)) {
    throw "Replay evidence admission helper is missing: $EvidenceAdmissionTool"
}
if (-not (Test-Path -LiteralPath $GodotBin -PathType Leaf)) {
    throw "Pinned Godot console is missing: $GodotBin"
}
if (-not (Test-Path -LiteralPath $GodotRuntimeBin -PathType Leaf)) {
    throw "Pinned Godot runtime is missing: $GodotRuntimeBin"
}

Assert-RepositoryIdentity
New-Item -ItemType Directory -Path $LeaseRoot -Force | Out-Null
if (Test-Path -LiteralPath $EvidenceRoot) {
    throw "Refusing to reuse pre-existing aggregate evidence root: $EvidenceRoot"
}
New-Item -ItemType Directory -Path $EvidenceRoot | Out-Null
$launcherBytes = [IO.File]::ReadAllBytes($PSCommandPath)
$hasher = [Security.Cryptography.SHA256]::Create()
try {
    $script:LauncherInitialSha256 = ([BitConverter]::ToString($hasher.ComputeHash($launcherBytes))).Replace('-', '').ToLowerInvariant()
}
finally {
    $hasher.Dispose()
}
[IO.File]::WriteAllBytes($LauncherSnapshotPath, $launcherBytes)
if ((Get-Sha256 -Path $LauncherSnapshotPath) -cne $script:LauncherInitialSha256) {
    throw 'Immutable launcher snapshot hash differs immediately after creation.'
}
$script:InitialProcessCensus = @(Get-ProcessCensus)

try {
    $launchLock = $null
    try {
        $launchLock = Enter-LaunchLock
        Assert-RepositoryIdentity
        Assert-ExclusiveAdmission
        New-OwnedExclusiveLease
        $script:LeaseOwned = $true
        Assert-OwnedExclusiveReservation
    }
    finally {
        Exit-LaunchLock -Stream $launchLock
    }
    Wait-ExclusiveDrain
    Assert-RepositoryIdentity
    New-SourceCustody
    $null = Get-ValidatedReplayToolPath
    . $EvidenceAdmissionTool
    Assert-SourceCustody

    foreach ($runIndex in 1..2) {
        $betweenLock = $null
        try {
            $betweenLock = Enter-LaunchLock
            Assert-RepositoryIdentity
            Assert-SourceCustody
            Assert-ExclusiveAdmission -AllowOwnedLease
        }
        finally {
            Exit-LaunchLock -Stream $betweenLock
        }
        $proof = Invoke-OneFixedRun -RunIndex $runIndex
        $script:RunProofs.Add($proof)
    }
    $script:CanonicalProof = Compare-FixedRunProofs -Proofs @($script:RunProofs)
    $script:Outcome = 'green'
}
catch {
    $script:TerminalError = $_
    if ($_.Exception.Message -match 'timed out') { $script:Outcome = 'timeout' }
    else { $script:Outcome = 'red' }
}
finally {
    try {
        if ((Get-OwnedSurvivors).Count -ne 0) {
            Stop-AllOwnedProcesses
        }
    }
    catch {
        Add-TerminalFailure -Failure $_
    }

    $teardownLock = $null
    try {
        $teardownLock = Enter-LaunchLock
        try {
            Assert-RepositoryIdentity
            $script:FinalHead = Get-GitValue -Revision 'HEAD'
            $script:FinalTree = Get-GitValue -Revision 'HEAD^{tree}'
        }
        catch { Add-TerminalFailure -Failure $_ }
        try {
            $script:LauncherCurrentSha256 = Get-Sha256 -Path $PSCommandPath
            if ($script:LauncherCurrentSha256 -cne $script:LauncherInitialSha256) {
                Add-TerminalFailure -Failure 'Final-evidence launcher changed after its immutable invocation snapshot.'
            }
            if ((Get-Sha256 -Path $LauncherSnapshotPath) -cne $script:LauncherInitialSha256) {
                Add-TerminalFailure -Failure 'Immutable launcher snapshot changed before teardown.'
            }
        }
        catch { Add-TerminalFailure -Failure $_ }
        try {
            if ($script:SourceCustodyRows.Count -gt 0) {
                Complete-SourceCustody
            }
        }
        catch { Add-TerminalFailure -Failure $_ }
        try {
            Clear-StaleGodotLeases
            if ($script:LeaseOwned -and -not (Test-OwnedExclusiveLease)) {
                Add-TerminalFailure -Failure 'Owned aggregate EXCLUSIVE lease disappeared or changed owner before teardown.'
            }
            $competingNormalLeases = @(Get-ChildItem -LiteralPath $LeaseRoot -Filter '*.lease' -File -ErrorAction Stop | Where-Object { $_.Name -cne 'EXCLUSIVE.lease' })
            if ($competingNormalLeases.Count -ne 0) {
                Add-TerminalFailure -Failure "Normal leases appeared during the Q-009 exclusive run: $(@($competingNormalLeases.Name) -join ',')."
            }
            $ownedSurvivors = @(Get-OwnedSurvivors)
            $globalGodotSurvivors = @(Get-GodotProcesses)
            $script:FinalProcessCensus = @(Get-ProcessCensus)
            if ($ownedSurvivors.Count -ne 0 -or $globalGodotSurvivors.Count -ne 0) {
                $survivorCustody = @($ownedSurvivors) + @($globalGodotSurvivors)
                $custodyTransferred = $false
                if ($script:LeaseOwned -and (Test-OwnedExclusiveLease)) {
                    $custodyResult = Set-ExclusiveLeaseSurvivorCustody -Survivors $survivorCustody
                    $custodyTransferred = [bool]$custodyResult.transferred
                    $script:LeaseOwned = $false
                }
                Add-TerminalFailure -Failure "Replay/Godot processes survived teardown; exclusive_survivor_custody_transferred=$custodyTransferred`: $($survivorCustody | Microsoft.PowerShell.Utility\ConvertTo-Json -Compress)"
            }
            elseif ($script:LeaseOwned -and (Test-OwnedExclusiveLease)) {
                Remove-Item -LiteralPath $LeasePath -Force
                $script:LeaseOwned = $false
            }
        }
        catch { Add-TerminalFailure -Failure $_ }
    }
    catch { Add-TerminalFailure -Failure $_ }
    finally { Exit-LaunchLock -Stream $teardownLock }
}

$fixedRepeatQualifying = Test-FixedRepeatQualification `
    -TerminalError $script:TerminalError `
    -Outcome $script:Outcome `
    -RunProofs @($script:RunProofs) `
    -CanonicalProof $script:CanonicalProof `
    -LeaseOwned $script:LeaseOwned `
    -FinalProcessCensus $script:FinalProcessCensus `
    -FinalHead $script:FinalHead `
    -FinalTree $script:FinalTree `
    -SourceCustodyComplete $script:SourceCustodyComplete
if (-not $fixedRepeatQualifying -and $null -eq $script:TerminalError) {
    Add-TerminalFailure -Failure 'Fixed-repeat evidence did not satisfy every aggregate qualification condition.'
}

$aggregateSummary = [ordered]@{
    schema_version = 1
    check_id = 'rw06_2_final_evidence'
    role = 'fixed_route_repeat'
    evidence_role = 'fixed-repeat'
    ending = $Ending
    seed = $Seed
    repeat = 2
    outcome = $script:Outcome
    error = Get-FailureMessage -Failure $script:TerminalError
    expected_head = $ExpectedHead.ToLowerInvariant()
    expected_tree = $ExpectedTree.ToLowerInvariant()
    observed_head = $script:FinalHead
    observed_tree = $script:FinalTree
    independent_profiles = if ($null -ne $script:CanonicalProof) { $script:CanonicalProof.isolated_profiles } else { $false }
    fresh_interactive_authorized = $false
    q017_status = if ($Ending -ceq 'heist') { 'ANSWERED_SEPARATE_FRESH_INTERACTIVE_SCOPE' } else { 'NOT_APPLICABLE' }
    deterministic = if ($null -ne $script:CanonicalProof) { $script:CanonicalProof.deterministic } else { $false }
    fixed_repeat_qualifying = $fixedRepeatQualifying
    source_custody_complete = $script:SourceCustodyComplete
    source_custody_pre_sha256 = $script:SourceCustodyPreSha256
    source_custody_final_sha256 = $script:SourceCustodyFinalSha256
    canonical_proof = $script:CanonicalProof
    runs = @($script:RunProofs)
    evidence_root = $EvidenceRoot
}
Assert-TerminalAggregateShape -Record $aggregateSummary -Representation ordered -Label 'In-memory aggregate summary'
$aggregateSummaryJson = $aggregateSummary | Microsoft.PowerShell.Utility\ConvertTo-Json -Depth 20
$expectedAggregateSummary = ConvertFrom-ExactJsonObjectText -Json $aggregateSummaryJson -Label 'Serialized aggregate summary'
Assert-TerminalAggregateShape -Record $expectedAggregateSummary -Representation json -Label 'Serialized aggregate summary'
$aggregateSummaryJson | Microsoft.PowerShell.Management\Set-Content -LiteralPath $AggregateSummaryPath -Encoding utf8
$retainedAggregateSummary = ConvertFrom-ExactJsonObjectText `
    -Json (Microsoft.PowerShell.Management\Get-Content -Raw -LiteralPath $AggregateSummaryPath -Encoding utf8) `
    -Label 'Retained aggregate summary'
Assert-TerminalAggregateShape -Record $retainedAggregateSummary -Representation json -Label 'Retained aggregate summary'
if ((ConvertTo-CanonicalExactObjectJson -InputObject $retainedAggregateSummary -Label 'Retained aggregate summary') -cne
    (ConvertTo-CanonicalExactObjectJson -InputObject $expectedAggregateSummary -Label 'Serialized aggregate summary')) {
    throw 'Retained aggregate summary differs from its exact in-memory serialization.'
}

$metadata = [ordered]@{
    lane = 'rw06_2p'
    kind = 'exclusive-real-input-fixed-repeat-final-evidence'
    ending = $Ending
    seed = $Seed
    role = 'fixed_route_repeat'
    evidence_role = 'fixed-repeat'
    outcome = $script:Outcome
    error = Get-FailureMessage -Failure $script:TerminalError
    expected_head = $ExpectedHead.ToLowerInvariant()
    expected_tree = $ExpectedTree.ToLowerInvariant()
    observed_head = $script:FinalHead
    observed_tree = $script:FinalTree
    launcher_snapshot = $LauncherSnapshotPath
    launcher_initial_sha256 = $script:LauncherInitialSha256
    launcher_current_sha256 = $script:LauncherCurrentSha256
    source_custody_pre = $SourceCustodyPrePath
    source_custody_pre_sha256 = $script:SourceCustodyPreSha256
    source_custody_final = $SourceCustodyFinalPath
    source_custody_final_sha256 = $script:SourceCustodyFinalSha256
    source_custody_complete = $script:SourceCustodyComplete
    initial_process_census = $script:InitialProcessCensus
    final_process_census = $script:FinalProcessCensus
    owned_processes_remaining = @(Get-OwnedSurvivors)
    lease_path = $LeasePath
    lease_removed = -not (Test-Path -LiteralPath $LeasePath)
    fixed_repeat_qualifying = $fixedRepeatQualifying
    started = $StartedAt.ToString('o')
    completed = [DateTimeOffset]::Now.ToString('o')
}
Assert-TerminalMetadataShape -Record $metadata -Representation ordered -Label 'In-memory run metadata'
$metadataJson = $metadata | Microsoft.PowerShell.Utility\ConvertTo-Json -Depth 20
$expectedMetadata = ConvertFrom-ExactJsonObjectText -Json $metadataJson -Label 'Serialized run metadata'
Assert-TerminalMetadataShape -Record $expectedMetadata -Representation json -Label 'Serialized run metadata'
$metadataJson | Microsoft.PowerShell.Management\Set-Content -LiteralPath $MetadataPath -Encoding utf8
$retainedMetadata = ConvertFrom-ExactJsonObjectText `
    -Json (Microsoft.PowerShell.Management\Get-Content -Raw -LiteralPath $MetadataPath -Encoding utf8) `
    -Label 'Retained run metadata'
Assert-TerminalMetadataShape -Record $retainedMetadata -Representation json -Label 'Retained run metadata'
if ((ConvertTo-CanonicalExactObjectJson -InputObject $retainedMetadata -Label 'Retained run metadata') -cne
    (ConvertTo-CanonicalExactObjectJson -InputObject $expectedMetadata -Label 'Serialized run metadata')) {
    throw 'Retained run metadata differs from its exact in-memory serialization.'
}

$aggregateSummarySha256 = Get-Sha256 -Path $AggregateSummaryPath
$metadataSha256 = Get-Sha256 -Path $MetadataPath
$artifactRows = @(Get-ManifestArtifactPaths | ForEach-Object {
    [ordered]@{ path = $_; sha256 = Get-Sha256 -Path $_ }
})
Assert-ManifestArtifactHash -ArtifactRows $artifactRows -Path $LauncherSnapshotPath `
    -ExpectedSha256 $script:LauncherInitialSha256 -Label 'Immutable launcher snapshot'
Assert-ManifestArtifactHash -ArtifactRows $artifactRows -Path $SourceCustodyPrePath `
    -ExpectedSha256 $script:SourceCustodyPreSha256 -Label 'Source custody pre-execution receipt'
Assert-ManifestArtifactHash -ArtifactRows $artifactRows -Path $SourceCustodyFinalPath `
    -ExpectedSha256 $script:SourceCustodyFinalSha256 -Label 'Source custody final receipt'
Assert-ManifestArtifactHash -ArtifactRows $artifactRows -Path $AggregateSummaryPath `
    -ExpectedSha256 $aggregateSummarySha256 -Label 'Aggregate summary'
Assert-ManifestArtifactHash -ArtifactRows $artifactRows -Path $MetadataPath `
    -ExpectedSha256 $metadataSha256 -Label 'Run metadata'
$manifestPathKeys = @($artifactRows | ForEach-Object { [IO.Path]::GetFullPath([string]$_.path).ToLowerInvariant() })
$requiredManifestArtifacts = [Collections.Generic.List[string]]::new()
$requiredManifestArtifactKeys = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($requiredArtifact in @(
    $LauncherSnapshotPath, $AggregateSummaryPath, $MetadataPath,
    $SourceCustodyPrePath, $SourceCustodyFinalPath
)) {
    $canonicalRequiredArtifact = [IO.Path]::GetFullPath($requiredArtifact)
    if (-not $requiredManifestArtifactKeys.Add($canonicalRequiredArtifact)) {
        throw "Required aggregate manifest artifact was registered more than once: $canonicalRequiredArtifact"
    }
    $requiredManifestArtifacts.Add($canonicalRequiredArtifact)
}
for ($proofOffset = 0; $proofOffset -lt $script:RunProofs.Count; $proofOffset++) {
    $proof = $script:RunProofs[$proofOffset]
    Assert-FixedRunManifestArtifactBindings `
        -ArtifactRows $artifactRows `
        -Proof $proof `
        -ExpectedRunIndex ($proofOffset + 1)
    foreach ($requiredArtifact in @(
        (Get-ExactValueNoEnumerate $proof @('replay_summary') $null),
        (Get-ExactValueNoEnumerate $proof @('launcher_stdout') $null),
        (Get-ExactValueNoEnumerate $proof @('launcher_stderr') $null),
        (Get-ExactValueNoEnumerate $proof @('run_summary') $null),
        (Join-Path (Get-ExactValueNoEnumerate $proof @('run_root') $null) 'public_trace.ndjson'),
        (Join-Path (Get-ExactValueNoEnumerate $proof @('run_root') $null) 'money_curve.ndjson'),
        (Join-Path (Get-ExactValueNoEnumerate $proof @('run_root') $null) 'checkpoint_before.json'),
        (Join-Path (Get-ExactValueNoEnumerate $proof @('run_root') $null) 'checkpoint_after.json'),
        (Join-Path (Get-ExactValueNoEnumerate $proof @('run_root') $null) 'final_public_checkpoint.json'),
        (Get-ExactValueNoEnumerate $proof @('profile_inventory') $null),
        (Get-ExactValueNoEnumerate $proof @('autosave') $null),
        (Join-Path (Get-ExactValueNoEnumerate $proof @('session_root') $null) 'godot.stdout.log'),
        (Join-Path (Get-ExactValueNoEnumerate $proof @('session_root') $null) 'godot.stderr.log'),
        (Join-Path (Get-ExactValueNoEnumerate $proof @('session_root') $null) 'godot.engine.log')
    )) {
        $canonicalRequiredArtifact = [IO.Path]::GetFullPath($requiredArtifact)
        if (-not $requiredManifestArtifactKeys.Add($canonicalRequiredArtifact)) {
            throw "Required aggregate manifest artifact was registered more than once: $canonicalRequiredArtifact"
        }
        $requiredManifestArtifacts.Add($canonicalRequiredArtifact)
    }
    if ($Ending -ceq 'heist') {
        $canonicalRequiredArtifact = [IO.Path]::GetFullPath(
            (Get-ExactValueNoEnumerate $proof @('heist_seed_preflight') $null)
        )
        if (-not $requiredManifestArtifactKeys.Add($canonicalRequiredArtifact)) {
            throw "Required aggregate manifest artifact was registered more than once: $canonicalRequiredArtifact"
        }
        $requiredManifestArtifacts.Add($canonicalRequiredArtifact)
    }
}
foreach ($requiredArtifact in $requiredManifestArtifacts) {
    if ($manifestPathKeys -cnotcontains $requiredArtifact.ToLowerInvariant()) {
        throw "Aggregate manifest omitted required evidence artifact: $requiredArtifact"
    }
}
$manifest = [ordered]@{
    schema_version = 1
    check_id = 'rw06_2_final_evidence_manifest'
    role = 'fixed_route_repeat'
    evidence_role = 'fixed-repeat'
    ending = $Ending
    seed = $Seed
    fixed_repeat_qualifying = $fixedRepeatQualifying
    evidence_root = $EvidenceRoot
    artifact_count = $artifactRows.Count
    artifacts = $artifactRows
}
Assert-TerminalManifestShape -Record $manifest -Representation ordered -Label 'In-memory artifact manifest'
$manifestJson = $manifest | Microsoft.PowerShell.Utility\ConvertTo-Json -Depth 10
$expectedManifest = ConvertFrom-ExactJsonObjectText -Json $manifestJson -Label 'Serialized artifact manifest'
Assert-TerminalManifestShape -Record $expectedManifest -Representation json -Label 'Serialized artifact manifest'
$manifestJson | Microsoft.PowerShell.Management\Set-Content -LiteralPath $ManifestPath -Encoding utf8
$retainedManifest = ConvertFrom-ExactJsonObjectText `
    -Json (Microsoft.PowerShell.Management\Get-Content -Raw -LiteralPath $ManifestPath -Encoding utf8) `
    -Label 'Retained artifact manifest'
Assert-TerminalManifestShape -Record $retainedManifest -Representation json -Label 'Retained artifact manifest'
if ((ConvertTo-CanonicalExactObjectJson -InputObject $retainedManifest -Label 'Retained artifact manifest') -cne
    (ConvertTo-CanonicalExactObjectJson -InputObject $expectedManifest -Label 'Serialized artifact manifest')) {
    throw 'Retained artifact manifest differs from its exact in-memory serialization.'
}
foreach ($artifact in (Get-ExactValueNoEnumerate $retainedManifest @('artifacts') $null)) {
    $retainedArtifactPath = Get-ExactValueNoEnumerate $artifact @('path') $null
    $retainedArtifactSha256 = Get-ExactValueNoEnumerate $artifact @('sha256') $null
    if ((Get-Sha256 -Path $retainedArtifactPath) -cne $retainedArtifactSha256) {
        throw "Evidence artifact changed during manifest finalization: $retainedArtifactPath"
    }
}
Assert-SourceCustody
if ((Get-HeldFileDigests -Stream $script:SourceCustodyPreStream).sha256 -cne $script:SourceCustodyPreSha256 -or
    (Get-HeldFileDigests -Stream $script:SourceCustodyFinalStream).sha256 -cne $script:SourceCustodyFinalSha256) {
    throw 'Retained source custody receipts changed during manifest finalization.'
}
Close-SourceCustody

$finalRetainedManifest = ConvertFrom-ExactJsonObjectText `
    -Json (Microsoft.PowerShell.Management\Get-Content -Raw -LiteralPath $ManifestPath -Encoding utf8) `
    -Label 'Final retained artifact manifest rebind'
Assert-TerminalManifestShape `
    -Record $finalRetainedManifest `
    -Representation json `
    -Label 'Final retained artifact manifest rebind'
if ((ConvertTo-CanonicalExactObjectJson -InputObject $finalRetainedManifest -Label 'Final retained artifact manifest rebind') -cne
    (ConvertTo-CanonicalExactObjectJson -InputObject $expectedManifest -Label 'Serialized artifact manifest authority')) {
    throw 'Final retained artifact manifest differs from its exact serialized authority.'
}
for ($proofOffset = 0; $proofOffset -lt $script:RunProofs.Count; $proofOffset++) {
    Assert-FixedRunManifestArtifactBindings `
        -ArtifactRows (Get-ExactValueNoEnumerate $finalRetainedManifest @('artifacts') $null) `
        -Proof $script:RunProofs[$proofOffset] `
        -ExpectedRunIndex ($proofOffset + 1)
}
if ($null -ne $script:CanonicalProof -or $fixedRepeatQualifying) {
    $finalRecomputedCanonicalProof = Compare-FixedRunProofs -Proofs @($script:RunProofs)
    Assert-CanonicalFixedProofShape `
        -Proof $script:CanonicalProof `
        -Label 'Held canonical proof at final retained-manifest rebind'
    if ((ConvertTo-CanonicalExactObjectJson -InputObject $script:CanonicalProof -Label 'Held canonical proof at final retained-manifest rebind') -cne
        (ConvertTo-CanonicalExactObjectJson -InputObject $finalRecomputedCanonicalProof -Label 'Recomputed canonical proof at final retained-manifest rebind')) {
        throw 'Held canonical proof differs from the complete run-proof authority at final retained-manifest rebind.'
    }
}
$manifestSha256 = Get-Sha256 -Path $ManifestPath
$result = [ordered]@{
    evidence_root = $EvidenceRoot
    outcome = $script:Outcome
    fixed_repeat_qualifying = $fixedRepeatQualifying
    head = $script:FinalHead
    tree = $script:FinalTree
    aggregate_summary_sha256 = $aggregateSummarySha256
    metadata_sha256 = $metadataSha256
    manifest_sha256 = $manifestSha256
    source_custody_pre_sha256 = $script:SourceCustodyPreSha256
    source_custody_final_sha256 = $script:SourceCustodyFinalSha256
}
Assert-TerminalResultShape `
    -Record $result `
    -Representation ordered `
    -ExpectedAggregateSha256 $aggregateSummarySha256 `
    -ExpectedMetadataSha256 $metadataSha256 `
    -ExpectedManifestSha256 $manifestSha256 `
    -Label 'In-memory terminal stdout result'
$retainedResult = ConvertFrom-ExactJsonObjectText `
    -Json (Microsoft.PowerShell.Utility\ConvertTo-Json -InputObject $result -Depth 8) `
    -Label 'Terminal stdout result'
Assert-TerminalResultShape `
    -Record $retainedResult `
    -Representation json `
    -ExpectedAggregateSha256 $aggregateSummarySha256 `
    -ExpectedMetadataSha256 $metadataSha256 `
    -ExpectedManifestSha256 $manifestSha256 `
    -Label 'Terminal stdout result'

# Sealed terminal tail: every potentially effectful caller-owned validator has
# completed. Rehash only exact retained-manifest paths with module-qualified,
# read-only primitives; no evidence write or caller-owned function follows.
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
$sealedManifestSha256 = (Microsoft.PowerShell.Utility\Get-FileHash `
    -LiteralPath $ManifestPath `
    -Algorithm SHA256).Hash.ToLowerInvariant()
if ($sealedManifestSha256 -cne $manifestSha256 -or
    $retainedResult.manifest_sha256 -isnot [string] -or
    $retainedResult.manifest_sha256 -cne $sealedManifestSha256) {
    throw 'Retained manifest authority changed before sealed terminal output.'
}
if ($null -ne $script:TerminalError) { throw $script:TerminalError }
Microsoft.PowerShell.Utility\ConvertTo-Json -InputObject $retainedResult -Depth 8
