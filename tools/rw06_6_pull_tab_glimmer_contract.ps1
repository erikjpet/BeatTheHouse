param(
    [string]$GodotPath = 'D:\Projects\Beat-The-House\.tools\godot-4.6-stable\Godot_v4.6-stable_win64_console.exe',
    [string]$EvidenceRoot = '',
    [string]$ExpectedCommit = '',
    [string]$ExpectedTree = '',
    [ValidateSet('Red', 'Green')]
    [string]$ExpectedOutcome = '',
    [int]$LeaseWaitTimeoutSec = 900,
    [int]$ProcessTimeoutSec = 180,
    [switch]$AuthorizeGreen,
    [switch]$ValidateOnly,
    [switch]$ProcessProbeChild,
    [int]$ProbeExitCode = 0,
    [int]$ProbeSleepMsec = 0,
    [int]$ProbeVolumeBytes = 0,
    [string]$ProbeEcho = '',
    [string]$ProbeTrailing = '',
    [string]$ProbeEmpty = '__unset__'
)

$ErrorActionPreference = 'Stop'

if ($ProcessProbeChild) {
    if ($ProbeSleepMsec -gt 0) {
        Start-Sleep -Milliseconds $ProbeSleepMsec
    }
    $probePayload = [ordered]@{
        echo = $ProbeEcho
        trailing = $ProbeTrailing
        empty = $ProbeEmpty
    } | ConvertTo-Json -Compress
    [Console]::Out.WriteLine('RW06_6_PROCESS_PROBE_STDOUT ' + $probePayload)
    [Console]::Error.WriteLine('RW06_6_PROCESS_PROBE_STDERR ' + $probePayload)
    if ($ProbeVolumeBytes -gt 0) {
        [Console]::Out.Write(('O' * $ProbeVolumeBytes))
        [Console]::Error.Write(('E' * $ProbeVolumeBytes))
        [Console]::Out.WriteLine('RW06_6_PROCESS_PROBE_STDOUT_END')
        [Console]::Error.WriteLine('RW06_6_PROCESS_PROBE_STDERR_END')
    }
    exit $ProbeExitCode
}

$projectRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$canonicalLeaseRoot = 'D:\Projects\Beat-The-House-worktrees\.godot_leases'
$leaseRoot = [System.IO.Path]::GetFullPath($canonicalLeaseRoot)
$exclusiveLeasePath = Join-Path $leaseRoot 'EXCLUSIVE.lease'
$launchMutexName = 'Global\BeatTheHouse-Q009-GodotLaunch'
$guardRelativePath = 'scripts/tests/fixtures/rw06_6_pull_tab_glimmer_source_guard.gd'
$guardScriptPath = 'res://scripts/tests/fixtures/rw06_6_pull_tab_glimmer_source_guard.gd'
$fullContractRelativePath = 'scripts/tests/rw06_6_pull_tab_glimmer_contract.gd'
$fullContractScriptPath = 'res://scripts/tests/rw06_6_pull_tab_glimmer_contract.gd'
$productRelativePath = 'scripts/games/pull_tabs.gd'
$launcherRelativePath = 'tools/rw06_6_pull_tab_glimmer_contract.ps1'
$canonicalRepoRoot = 'D:\Projects\Beat-The-House'
$ownerQuestionsRelativePath = 'docs/todo/rw06_owner_questions.md'
$ownerQuestionsPath = 'D:\Projects\Beat-The-House\docs\todo\rw06_owner_questions.md'
$projectCacheRoot = [System.IO.Path]::GetFullPath((Join-Path $projectRoot '.godot'))
$globalClassCachePath = Join-Path $projectCacheRoot 'global_script_class_cache.cfg'
$uidCachePath = Join-Path $projectCacheRoot 'uid_cache.bin'
$importedRoot = Join-Path $projectCacheRoot 'imported'
$nativeExitSentinel = [int]::MinValue


function Assert-LauncherContract {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}


function Test-FocusedLaunchCapacity {
    param(
        [bool]$ExclusivePresent,
        [int]$LiveFocusedLeaseCount,
        [int]$LiveGodotProcessCount
    )
    return (-not $ExclusivePresent) -and $LiveFocusedLeaseCount -lt 2 -and ($LiveGodotProcessCount + 2) -le 4
}


function Test-ReservedLaunchCapacity {
    param(
        [bool]$ExclusivePresent,
        [int]$LiveFocusedLeaseCount,
        [int]$LiveGodotProcessCount
    )
    return (-not $ExclusivePresent) -and $LiveFocusedLeaseCount -le 2 -and ($LiveGodotProcessCount + 2) -le 4
}


function Assert-ExactCandidateIdentity {
    param(
        [string]$RequiredCommit,
        [string]$RequiredTree,
        [string]$ActualCommit,
        [string]$ActualTree
    )
    if ([string]::IsNullOrWhiteSpace($RequiredCommit) -or [string]::IsNullOrWhiteSpace($RequiredTree)) {
        throw 'ExpectedCommit and ExpectedTree are both required for every evidence run.'
    }
    if ($ActualCommit -ne $RequiredCommit.Trim()) {
        throw "Candidate commit mismatch: expected $RequiredCommit, found $ActualCommit."
    }
    if ($ActualTree -ne $RequiredTree.Trim()) {
        throw "Candidate tree mismatch: expected $RequiredTree, found $ActualTree."
    }
}


function Assert-CleanExactCandidate {
    param(
        [string]$Root,
        [string]$RequiredCommit,
        [string]$RequiredTree
    )
    $dirty = @(& git -C $Root status --porcelain)
    $statusExitCode = $LASTEXITCODE
    if ($statusExitCode -ne 0 -or $dirty.Count -ne 0) {
        throw 'RW06_6 evidence requires a clean committed candidate tree.'
    }
    $actualCommit = (& git -C $Root rev-parse HEAD).Trim()
    $commitExitCode = $LASTEXITCODE
    $actualTree = (& git -C $Root rev-parse 'HEAD^{tree}').Trim()
    $treeExitCode = $LASTEXITCODE
    if (
        $commitExitCode -ne 0 `
        -or $treeExitCode -ne 0 `
        -or [string]::IsNullOrWhiteSpace($actualCommit) `
        -or [string]::IsNullOrWhiteSpace($actualTree)
    ) {
        throw 'Could not resolve the exact candidate commit/tree.'
    }
    Assert-ExactCandidateIdentity $RequiredCommit $RequiredTree $actualCommit $actualTree
    return [ordered]@{ commit = $actualCommit; tree = $actualTree }
}


function Get-LiveGodotProcesses {
    return @(Get-Process -ErrorAction SilentlyContinue | Where-Object {
        $_.ProcessName -in @('Godot_v4.6-stable_win64_console', 'Godot_v4.6-stable_win64')
    })
}


function Clear-StaleGodotLeases {
    Get-ChildItem -LiteralPath $leaseRoot -Filter '*.lease' -File -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_.Name -eq 'EXCLUSIVE.lease') {
            $exclusivePid = 0
            try {
                $exclusiveFields = Read-LeaseFields -Path $_.FullName
                $exclusivePid = [int]$exclusiveFields['pid']
            }
            catch {
                return
            }
            if ($exclusivePid -gt 0 -and -not (Get-Process -Id $exclusivePid -ErrorAction SilentlyContinue)) {
                Remove-Item -LiteralPath $_.FullName -Force
            }
            return
        }
        $match = [regex]::Match($_.Name, '-(?<pid>\d+)\.lease$')
        if (-not $match.Success) { return }
        $leasePid = [int]$match.Groups['pid'].Value
        if (-not (Get-Process -Id $leasePid -ErrorAction SilentlyContinue)) {
            Remove-Item -LiteralPath $_.FullName -Force
        }
    }
}


function Get-ProcessIdentityRecord {
    param([System.Diagnostics.Process]$Process)
    $startUtc = $Process.StartTime.ToUniversalTime()
    return [ordered]@{
        pid = [int]$Process.Id
        name = [string]$Process.ProcessName
        start_utc = $startUtc.ToString('o')
        start_ticks = [long]$startUtc.Ticks
        key = ('{0}|{1}|{2}' -f $Process.Id, $startUtc.Ticks, $Process.ProcessName)
    }
}


function Test-LiveProcessMatchesIdentity {
    param([object]$ExpectedIdentity)
    if ($null -eq $ExpectedIdentity -or [int]$ExpectedIdentity.pid -le 0 -or [string]::IsNullOrWhiteSpace([string]$ExpectedIdentity.key)) {
        return $false
    }
    $live = Get-Process -Id ([int]$ExpectedIdentity.pid) -ErrorAction SilentlyContinue
    if ($null -eq $live) { return $false }
    try {
        $liveIdentity = Get-ProcessIdentityRecord -Process $live
        return [string]$liveIdentity.key -ceq [string]$ExpectedIdentity.key
    }
    catch {
        return $false
    }
}


function Test-ProcessIdentityProofShape {
    param([AllowNull()][object]$Identity)
    if ($null -eq $Identity) { return $false }
    try {
        $pidValue = [int]$Identity.pid
        $nameValue = [string]$Identity.name
        $startTicks = [long]$Identity.start_ticks
        $keyValue = [string]$Identity.key
        $parsedStart = [datetime]::MinValue
        if (
            $pidValue -le 0 `
            -or [string]::IsNullOrWhiteSpace($nameValue) `
            -or $startTicks -le 0 `
            -or [string]::IsNullOrWhiteSpace([string]$Identity.start_utc) `
            -or -not [datetime]::TryParse(
                [string]$Identity.start_utc,
                [System.Globalization.CultureInfo]::InvariantCulture,
                [System.Globalization.DateTimeStyles]::RoundtripKind,
                [ref]$parsedStart
            )
        ) {
            return $false
        }
        $expectedKey = ('{0}|{1}|{2}' -f $pidValue, $startTicks, $nameValue)
        return (
            [long]$parsedStart.ToUniversalTime().Ticks -eq $startTicks `
            -and $keyValue -ceq $expectedKey
        )
    }
    catch {
        return $false
    }
}


function Get-OwnedProcessStartProofFromException {
    param([System.Exception]$Exception)
    $missing = [ordered]@{
        started = $false
        process_id = 0
        process_identity = $null
        provenance = 'none'
    }
    if (
        $null -eq $Exception `
        -or -not $Exception.Data.Contains('owned_process_id') `
        -or -not $Exception.Data.Contains('owned_process_identity')
    ) {
        return $missing
    }
    $rawPid = $Exception.Data['owned_process_id']
    $identity = $Exception.Data['owned_process_identity']
    if (
        -not ($rawPid -is [int]) `
        -or -not (Test-ProcessIdentityProofShape -Identity $identity) `
        -or [int]$rawPid -ne [int]$identity.pid
    ) {
        return $missing
    }
    return [ordered]@{
        started = $true
        process_id = [int]$rawPid
        process_identity = $identity
        provenance = 'start_setup_exception'
    }
}


function Test-CimCreationMatchesProcessStartTicks {
    param(
        [long]$CreationTicks,
        [long]$ProcessStartTicks
    )
    if ($CreationTicks -le 0 -or $ProcessStartTicks -le 0) { return $false }
    # Win32_Process.CreationDate is microsecond-truncated, while
    # Process.StartTime retains 100 ns ticks. Compare the exact representable
    # CIM value instead of allowing a time window that PID reuse could cross.
    $cimRepresentableStartTicks = $ProcessStartTicks - ($ProcessStartTicks % 10)
    return $CreationTicks -eq $cimRepresentableStartTicks
}


function Resolve-VerifiedDescendantIdentityRecords {
    param(
        [object]$RootIdentity,
        [long]$OwnershipEndTicks,
        [string[]]$BaselineIdentityKeys,
        [object[]]$Candidates
    )
    $rootPid = [int]$RootIdentity.pid
    $rootKey = [string]$RootIdentity.key
    $rootStartTicks = [long]$RootIdentity.start_ticks
    if ($rootPid -le 0 -or [string]::IsNullOrWhiteSpace($rootKey) -or $rootStartTicks -le 0 -or $OwnershipEndTicks -lt $rootStartTicks) {
        return @()
    }
    $verifiedIdentityByKey = @{}
    $verifiedIdentityByKey[$rootKey] = $RootIdentity
    $records = [System.Collections.Generic.List[object]]::new()
    $changed = $true
    while ($changed) {
        $changed = $false
        foreach ($candidate in @($Candidates)) {
            $record = $candidate.identity
            $recordKey = [string]$record.key
            $pidValue = [int]$record.pid
            $parentPid = [int]$candidate.parent_pid
            $parentIdentity = $candidate.parent_identity
            if ($null -eq $parentIdentity) { continue }
            $parentKey = [string]$parentIdentity.key
            if (
                $pidValue -le 0 `
                -or $pidValue -eq $rootPid `
                -or [string]::IsNullOrWhiteSpace($recordKey) `
                -or $verifiedIdentityByKey.ContainsKey($recordKey) `
                -or -not $verifiedIdentityByKey.ContainsKey($parentKey) `
                -or $BaselineIdentityKeys -contains $recordKey
            ) { continue }
            $verifiedParent = $verifiedIdentityByKey[$parentKey]
            if (
                $parentPid -ne [int]$parentIdentity.pid `
                -or $parentPid -ne [int]$verifiedParent.pid `
                -or [string]$parentIdentity.key -cne [string]$verifiedParent.key `
                -or [long]$parentIdentity.start_ticks -ne [long]$verifiedParent.start_ticks `
                -or [string]$parentIdentity.name -cne [string]$verifiedParent.name
            ) { continue }
            $parentStartTicks = [long]$verifiedParent.start_ticks
            $recordStartTicks = [long]$record.start_ticks
            if ($recordStartTicks -lt $rootStartTicks -or $recordStartTicks -lt $parentStartTicks -or $recordStartTicks -gt $OwnershipEndTicks) { continue }
            if (-not (Test-CimCreationMatchesProcessStartTicks -CreationTicks ([long]$candidate.creation_ticks) -ProcessStartTicks $recordStartTicks)) { continue }
            $verifiedIdentityByKey[$recordKey] = $record
            [void]$records.Add($record)
            $changed = $true
        }
    }
    return @($records)
}


function Get-VerifiedDescendantProcessRecords {
    param(
        [object]$RootIdentity,
        [string[]]$BaselineIdentityKeys,
        [AllowNull()][object]$RootExitTimeUtc = $null
    )
    if (-not (Test-ProcessIdentityProofShape -Identity $RootIdentity)) { return @() }
    $rootLiveAtStart = Test-LiveProcessMatchesIdentity -ExpectedIdentity $RootIdentity
    if (-not $rootLiveAtStart -and $null -eq $RootExitTimeUtc) { return @() }
    $all = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue)
    $ownershipEndTicks = if ($null -eq $RootExitTimeUtc) { [long]([DateTime]::UtcNow.Ticks) } else { [long]([datetime]$RootExitTimeUtc).ToUniversalTime().Ticks }
    $candidates = [System.Collections.Generic.List[object]]::new()
    foreach ($entry in $all) {
        $pidValue = [int]$entry.ProcessId
        $parentPid = [int]$entry.ParentProcessId
        $live = Get-Process -Id $pidValue -ErrorAction SilentlyContinue
        if ($null -eq $live) { continue }
        try {
            $record = Get-ProcessIdentityRecord -Process $live
            $parentIdentity = $null
            if ($parentPid -eq [int]$RootIdentity.pid) {
                # The exact root identity came from our owned process handle.
                # Its observed exit bound disambiguates a later PID reuse.
                $parentIdentity = $RootIdentity
            }
            else {
                $liveParent = Get-Process -Id $parentPid -ErrorAction SilentlyContinue
                if ($null -eq $liveParent) { continue }
                $parentIdentity = Get-ProcessIdentityRecord -Process $liveParent
                if (-not (Test-ProcessIdentityProofShape -Identity $parentIdentity)) { continue }
            }
            $creationValue = $entry.CreationDate
            $creationUtc = ([datetime]$creationValue).ToUniversalTime()
            [void]$candidates.Add([ordered]@{
                parent_pid = $parentPid
                parent_identity = $parentIdentity
                creation_ticks = [long]$creationUtc.Ticks
                identity = $record
            })
        }
        catch {
            # An exiting or inaccessible process cannot establish lineage.
        }
    }
    if ($null -eq $RootExitTimeUtc -and -not (Test-LiveProcessMatchesIdentity -ExpectedIdentity $RootIdentity)) {
        # Root ownership changed during the census. A caller may retry with the
        # exact observed ExitTime, which bounds post-exit lineage safely.
        return @()
    }
    return @(Resolve-VerifiedDescendantIdentityRecords -RootIdentity $RootIdentity -OwnershipEndTicks $ownershipEndTicks -BaselineIdentityKeys $BaselineIdentityKeys -Candidates @($candidates))
}


function Stop-ExactStartedProcess {
    param(
        [System.Diagnostics.Process]$Process,
        [object]$ProcessIdentity
    )
    if ($null -eq $Process -or $null -eq $ProcessIdentity) { return }
    $live = Get-Process -Id ([int]$ProcessIdentity.pid) -ErrorAction SilentlyContinue
    if ($null -eq $live) { return }
    try {
        $liveIdentity = Get-ProcessIdentityRecord -Process $live
        if ([string]$liveIdentity.key -ceq [string]$ProcessIdentity.key) {
            Stop-Process -InputObject $live -Force -ErrorAction SilentlyContinue
        }
    }
    catch {
        # An exact child exiting during cleanup is already clean.
    }
}


function Add-RetainedDescendantProcessRecords {
    param(
        [object]$RootIdentity,
        [string[]]$BaselineIdentityKeys,
        [System.Collections.Generic.List[object]]$RetainedRecords,
        [AllowNull()][object]$RootExitTimeUtc = $null
    )
    if ($null -eq $RootIdentity -or $null -eq $RetainedRecords) { return }
    $knownKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($record in @($RetainedRecords)) {
        [void]$knownKeys.Add([string]$record.key)
    }
    foreach ($record in @(Get-VerifiedDescendantProcessRecords -RootIdentity $RootIdentity -BaselineIdentityKeys $BaselineIdentityKeys -RootExitTimeUtc $RootExitTimeUtc)) {
        if ($knownKeys.Add([string]$record.key)) {
            [void]$RetainedRecords.Add($record)
        }
    }
}


function Stop-ExactStartedProcessTree {
    param(
        [System.Diagnostics.Process]$ConsoleProcess,
        [object]$ConsoleIdentity,
        [string[]]$BaselineIdentityKeys,
        [System.Collections.Generic.List[object]]$RetainedDescendantRecords,
        [string[]]$AllowedDescendantNames = @('Godot_v4.6-stable_win64_console', 'Godot_v4.6-stable_win64')
    )
    if ($null -eq $ConsoleProcess -or $null -eq $ConsoleIdentity) { return }
    Add-RetainedDescendantProcessRecords -RootIdentity $ConsoleIdentity -BaselineIdentityKeys $BaselineIdentityKeys -RetainedRecords $RetainedDescendantRecords
    foreach ($record in (@($RetainedDescendantRecords) | Sort-Object { [int]$_.pid } -Descending)) {
        $child = Get-Process -Id ([int]$record.pid) -ErrorAction SilentlyContinue
        if ($child -and $child.ProcessName -in $AllowedDescendantNames) {
            try {
                $currentIdentity = Get-ProcessIdentityRecord -Process $child
                if ([string]$currentIdentity.key -ceq [string]$record.key) {
                    Stop-Process -InputObject $child -Force -ErrorAction SilentlyContinue
                }
            }
            catch {
                # PID exit/reuse between census and stop is not ours to kill.
            }
        }
    }
    $liveConsole = Get-Process -Id ([int]$ConsoleIdentity.pid) -ErrorAction SilentlyContinue
    if ($liveConsole) {
        try {
            $currentConsoleIdentity = Get-ProcessIdentityRecord -Process $liveConsole
            if ([string]$currentConsoleIdentity.key -ceq [string]$ConsoleIdentity.key) {
                Stop-Process -InputObject $liveConsole -Force -ErrorAction SilentlyContinue
            }
        }
        catch {
            # A process exiting between identity verification and cleanup is already clean.
        }
    }
}


function Get-ExactOwnedGodotResidualPids {
    param(
        [object]$RootIdentity,
        [string[]]$BaselineIdentityKeys,
        [System.Collections.Generic.List[object]]$RetainedDescendantRecords
    )
    if ($null -eq $RootIdentity -or [int]$RootIdentity.pid -le 0) { return @() }
    $residuals = [System.Collections.Generic.List[int]]::new()
    if (Test-LiveProcessMatchesIdentity -ExpectedIdentity $RootIdentity) {
        $residuals.Add([int]$RootIdentity.pid)
    }
    Add-RetainedDescendantProcessRecords -RootIdentity $RootIdentity -BaselineIdentityKeys $BaselineIdentityKeys -RetainedRecords $RetainedDescendantRecords
    foreach ($record in @($RetainedDescendantRecords)) {
        $child = Get-Process -Id ([int]$record.pid) -ErrorAction SilentlyContinue
        if ($child -and $child.ProcessName -in @('Godot_v4.6-stable_win64_console', 'Godot_v4.6-stable_win64')) {
            try {
                $currentIdentity = Get-ProcessIdentityRecord -Process $child
                if ([string]$currentIdentity.key -ceq [string]$record.key) {
                    $residuals.Add([int]$record.pid)
                }
            }
            catch {}
        }
    }
    return @($residuals | Sort-Object -Unique)
}


function ConvertTo-WindowsCommandLineArgument {
    param([AllowEmptyString()][string]$Value)
    if ($Value.IndexOf([char]0) -ge 0 -or $Value.Contains("`r") -or $Value.Contains("`n")) {
        throw 'Native arguments may not contain NUL or newline characters.'
    }
    if ($Value.Length -gt 0 -and $Value -notmatch '[\s"]') {
        return $Value
    }
    $builder = [System.Text.StringBuilder]::new()
    [void]$builder.Append([char]34)
    $backslashCount = 0
    foreach ($character in $Value.ToCharArray()) {
        if ($character -eq [char]92) {
            $backslashCount += 1
            continue
        }
        if ($character -eq [char]34) {
            if ($backslashCount -gt 0) {
                [void]$builder.Append([char]92, $backslashCount * 2)
            }
            [void]$builder.Append([char]92)
            [void]$builder.Append([char]34)
            $backslashCount = 0
            continue
        }
        if ($backslashCount -gt 0) {
            [void]$builder.Append([char]92, $backslashCount)
            $backslashCount = 0
        }
        [void]$builder.Append($character)
    }
    if ($backslashCount -gt 0) {
        [void]$builder.Append([char]92, $backslashCount * 2)
    }
    [void]$builder.Append([char]34)
    return $builder.ToString()
}


function Join-ProcessArguments {
    param([string[]]$Arguments)
    return ((@($Arguments) | ForEach-Object { ConvertTo-WindowsCommandLineArgument -Value ([string]$_) }) -join ' ')
}


function Get-StrictNativeExitCode {
    param([object]$RawValue)
    if (-not ($RawValue -is [int])) {
        $typeName = if ($null -eq $RawValue) { 'null' } else { $RawValue.GetType().FullName }
        throw "Process exited without a System.Int32 native exit code (found $typeName)."
    }
    return [int]$RawValue
}


function Start-RedirectedProcess {
    param(
        [string]$FilePath,
        [string[]]$Arguments,
        [string]$StdoutPath,
        [string]$StderrPath,
        [ValidateSet('Godot', 'Exact')]
        [string]$ProcessKind,
        [string[]]$BaselineGodotIdentityKeys = @(),
        [int]$TimeoutSec,
        [switch]$ForceSecondPumpFailureForTest
    )
    $stdoutStream = $null
    $stderrStream = $null
    $process = $null
    $processStarted = $false
    $processId = 0
    $processStartTime = [datetime]::MinValue
    $processIdentity = $null
    $stdoutTask = $null
    $stderrTask = $null
    $retainedDescendantRecords = [System.Collections.Generic.List[object]]::new()
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $stdoutStream = [System.IO.FileStream]::new($StdoutPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::Read)
        $stderrStream = [System.IO.FileStream]::new($StderrPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::Read)
        $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
        $startInfo.FileName = $FilePath
        $startInfo.Arguments = Join-ProcessArguments -Arguments $Arguments
        $startInfo.UseShellExecute = $false
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        $startInfo.CreateNoWindow = $true
        $process = [System.Diagnostics.Process]::new()
        $process.StartInfo = $startInfo
        if (-not $process.Start()) {
            throw "Could not start process: $FilePath"
        }
        $processStarted = $true
        $processId = [int]$process.Id
        $processStartTime = $process.StartTime
        $processIdentity = Get-ProcessIdentityRecord -Process $process
        # Both pumps must be active before the bounded wait. A verbose Godot
        # failure can fill both native pipes under Windows PowerShell 5.1.
        $stdoutTask = $process.StandardOutput.BaseStream.CopyToAsync($stdoutStream)
        if ($ForceSecondPumpFailureForTest) {
            throw 'Forced second redirect-pump setup failure for hostile validation.'
        }
        $stderrTask = $process.StandardError.BaseStream.CopyToAsync($stderrStream)
        if ($ProcessKind -eq 'Godot') {
            # Capture the console child's immutable identity while the exact
            # root is alive and the global launch mutex is still held. Keep
            # sampling during completion as a defense against delayed spawn.
            $initialCaptureDeadline = [DateTime]::UtcNow.AddSeconds(2)
            do {
                Add-RetainedDescendantProcessRecords -RootIdentity $processIdentity -BaselineIdentityKeys $BaselineGodotIdentityKeys -RetainedRecords $retainedDescendantRecords
                if (@($retainedDescendantRecords | Where-Object { $_.name -in @('Godot_v4.6-stable_win64_console', 'Godot_v4.6-stable_win64') }).Count -gt 0) { break }
                if ($process.WaitForExit(25)) { break }
            } while ([DateTime]::UtcNow -lt $initialCaptureDeadline)
        }
        return [pscustomobject]@{
            process = $process
            process_id = $processId
            process_start_time = $processStartTime
            process_identity = $processIdentity
            retained_descendant_records = $retainedDescendantRecords
            stdout_task = $stdoutTask
            stderr_task = $stderrTask
            stdout_stream = $stdoutStream
            stderr_stream = $stderrStream
            stopwatch = $stopwatch
            deadline_utc = [DateTime]::UtcNow.AddSeconds($TimeoutSec)
            file_path = $FilePath
            arguments = @($Arguments)
        }
    }
    catch {
        $startException = $_.Exception
        if ($processId -gt 0) {
            $startException.Data['owned_process_id'] = [int]$processId
        }
        if (Test-ProcessIdentityProofShape -Identity $processIdentity) {
            $startException.Data['owned_process_identity'] = $processIdentity
        }
        if ($processStarted -and $null -ne $process) {
            if ($ProcessKind -eq 'Godot' -and $null -ne $processIdentity) {
                Stop-ExactStartedProcessTree -ConsoleProcess $process -ConsoleIdentity $processIdentity -BaselineIdentityKeys $BaselineGodotIdentityKeys -RetainedDescendantRecords $retainedDescendantRecords
            }
            # If the root StartTime could not be captured, do not infer child
            # ownership from PID lineage. The owned process handle is still
            # safe to terminate below; any survivor is reported as unowned.
            try { if (-not $process.HasExited) { $process.Kill() } } catch {}
            try { [void]$process.WaitForExit(5000) } catch {}
            if ($ProcessKind -eq 'Godot' -and $null -ne $processIdentity) {
                try {
                    $process.Refresh()
                    if ($process.HasExited) {
                        $setupExitTimeUtc = $process.ExitTime.ToUniversalTime()
                        Add-RetainedDescendantProcessRecords -RootIdentity $processIdentity -BaselineIdentityKeys $BaselineGodotIdentityKeys -RetainedRecords $retainedDescendantRecords -RootExitTimeUtc $setupExitTimeUtc
                        Stop-ExactStartedProcessTree -ConsoleProcess $process -ConsoleIdentity $processIdentity -BaselineIdentityKeys $BaselineGodotIdentityKeys -RetainedDescendantRecords $retainedDescendantRecords
                    }
                }
                catch {}
            }
        }
        $startedPumpTasks = [System.Collections.Generic.List[System.Threading.Tasks.Task]]::new()
        if ($null -ne $stdoutTask) { [void]$startedPumpTasks.Add($stdoutTask) }
        if ($null -ne $stderrTask) { [void]$startedPumpTasks.Add($stderrTask) }
        if ($startedPumpTasks.Count -gt 0) {
            try { [void][System.Threading.Tasks.Task]::WaitAll($startedPumpTasks.ToArray(), 5000) } catch {}
        }
        if ($null -ne $stdoutStream) { try { $stdoutStream.Flush() } catch {} }
        if ($null -ne $stderrStream) { try { $stderrStream.Flush() } catch {} }
        if ($null -ne $stdoutStream) { try { $stdoutStream.Dispose() } catch {} }
        if ($null -ne $stderrStream) { try { $stderrStream.Dispose() } catch {} }
        if ($null -ne $process) { try { $process.Dispose() } catch {} }
        $stopwatch.Stop()
        throw
    }
}


function Complete-RedirectedProcess {
    param(
        [pscustomobject]$Started,
        [int]$TimeoutSec,
        [ValidateSet('Godot', 'Exact')]
        [string]$ProcessKind,
        [string[]]$BaselineGodotIdentityKeys = @()
    )
    $process = $Started.process
    $processId = [int]$Started.process_id
    $timedOut = $false
    $nativeObserved = $false
    $nativeExitCode = [int]$nativeExitSentinel
    $effectiveExitCode = 125
    $errorText = ''
    try {
        $exited = $false
        while ([DateTime]::UtcNow -lt $Started.deadline_utc) {
            $hasRetainedGodotChild = @($Started.retained_descendant_records | Where-Object { $_.name -in @('Godot_v4.6-stable_win64_console', 'Godot_v4.6-stable_win64') }).Count -gt 0
            if ($ProcessKind -eq 'Godot' -and -not $hasRetainedGodotChild) {
                Add-RetainedDescendantProcessRecords -RootIdentity $Started.process_identity -BaselineIdentityKeys $BaselineGodotIdentityKeys -RetainedRecords $Started.retained_descendant_records
            }
            $remainingMsec = [Math]::Max(1, [int]([DateTime]::UtcNow.Subtract($Started.deadline_utc).Negate().TotalMilliseconds))
            $waitSliceMsec = [Math]::Min(250, $remainingMsec)
            if ($process.WaitForExit($waitSliceMsec)) {
                $exited = $true
                break
            }
        }
        if (-not $exited) {
            $timedOut = $true
            if ($ProcessKind -eq 'Godot') {
                Stop-ExactStartedProcessTree -ConsoleProcess $process -ConsoleIdentity $Started.process_identity -BaselineIdentityKeys $BaselineGodotIdentityKeys -RetainedDescendantRecords $Started.retained_descendant_records
            }
            else {
                Stop-ExactStartedProcess -Process $process -ProcessIdentity $Started.process_identity
            }
            if (-not $process.WaitForExit(5000)) {
                throw 'Timed-out process did not exit after exact-process cleanup.'
            }
        }
        $process.Refresh()
        if (-not $process.HasExited) {
            throw 'Bounded wait returned without a completed process.'
        }
        if ($ProcessKind -eq 'Godot') {
            $rootExitTimeUtc = $process.ExitTime.ToUniversalTime()
            Add-RetainedDescendantProcessRecords -RootIdentity $Started.process_identity -BaselineIdentityKeys $BaselineGodotIdentityKeys -RetainedRecords $Started.retained_descendant_records -RootExitTimeUtc $rootExitTimeUtc
            Stop-ExactStartedProcessTree -ConsoleProcess $process -ConsoleIdentity $Started.process_identity -BaselineIdentityKeys $BaselineGodotIdentityKeys -RetainedDescendantRecords $Started.retained_descendant_records
        }
        $nativeExitCode = Get-StrictNativeExitCode -RawValue $process.ExitCode
        $nativeObserved = $true
        $pumpDeadline = if ($timedOut) { [DateTime]::UtcNow.AddSeconds(5) } else { $Started.deadline_utc }
        $pumpRemainingMsec = [Math]::Max(1, [int]([DateTime]::UtcNow.Subtract($pumpDeadline).Negate().TotalMilliseconds))
        $pumpTasks = [System.Threading.Tasks.Task[]]@($Started.stdout_task, $Started.stderr_task)
        if (-not [System.Threading.Tasks.Task]::WaitAll($pumpTasks, $pumpRemainingMsec)) {
            throw 'Redirected process streams did not drain within the shared deadline.'
        }
        if ($Started.stdout_task.IsFaulted -or $Started.stderr_task.IsFaulted) {
            throw 'A redirected process stream pump faulted.'
        }
        $Started.stdout_stream.Flush()
        $Started.stderr_stream.Flush()
        $effectiveExitCode = if ($timedOut) { 124 } else { $nativeExitCode }
    }
    catch {
        $errorText = $_.Exception.Message
        $effectiveExitCode = if ($timedOut) { 124 } else { 125 }
        if ($ProcessKind -eq 'Godot') {
            Stop-ExactStartedProcessTree -ConsoleProcess $process -ConsoleIdentity $Started.process_identity -BaselineIdentityKeys $BaselineGodotIdentityKeys -RetainedDescendantRecords $Started.retained_descendant_records
        }
        else {
            Stop-ExactStartedProcess -Process $process -ProcessIdentity $Started.process_identity
        }
        try { [void]$process.WaitForExit(5000) } catch {}
        if ($ProcessKind -eq 'Godot') {
            try {
                $process.Refresh()
                if ($process.HasExited) {
                    $catchExitTimeUtc = $process.ExitTime.ToUniversalTime()
                    Add-RetainedDescendantProcessRecords -RootIdentity $Started.process_identity -BaselineIdentityKeys $BaselineGodotIdentityKeys -RetainedRecords $Started.retained_descendant_records -RootExitTimeUtc $catchExitTimeUtc
                    Stop-ExactStartedProcessTree -ConsoleProcess $process -ConsoleIdentity $Started.process_identity -BaselineIdentityKeys $BaselineGodotIdentityKeys -RetainedDescendantRecords $Started.retained_descendant_records
                }
            }
            catch {}
        }
        try {
            $cleanupTasks = [System.Threading.Tasks.Task[]]@($Started.stdout_task, $Started.stderr_task)
            [void][System.Threading.Tasks.Task]::WaitAll($cleanupTasks, 5000)
        }
        catch {}
    }
    finally {
        if ($ProcessKind -eq 'Godot') {
            Stop-ExactStartedProcessTree -ConsoleProcess $process -ConsoleIdentity $Started.process_identity -BaselineIdentityKeys $BaselineGodotIdentityKeys -RetainedDescendantRecords $Started.retained_descendant_records
        }
        else {
            Stop-ExactStartedProcess -Process $process -ProcessIdentity $Started.process_identity
        }
        try { $Started.stdout_stream.Flush() } catch {}
        try { $Started.stderr_stream.Flush() } catch {}
        try { $Started.stdout_stream.Dispose() } catch {}
        try { $Started.stderr_stream.Dispose() } catch {}
        $Started.stopwatch.Stop()
        try { $process.Dispose() } catch {}
    }
    return [ordered]@{
        process_started = $true
        process_start_provenance = 'completed'
        native_exit_code = [int]$nativeExitCode
        native_exit_observed = $nativeObserved
        native_exit_type = if ($nativeObserved) { 'System.Int32' } else { '' }
        effective_exit_code = [int]$effectiveExitCode
        timed_out = $timedOut
        elapsed_seconds = [Math]::Round($Started.stopwatch.Elapsed.TotalSeconds, 3)
        process_id = $processId
        started_utc = $Started.process_start_time.ToUniversalTime().ToString('o')
        process_identity = $Started.process_identity
        retained_descendant_identities = @($Started.retained_descendant_records)
        error = $errorText
    }
}


function Get-DiagnosticLines {
    param([string]$Text)
    $patterns = @(
        '(?im)^.*SCRIPT ERROR.*$',
        '(?im)^\s*ERROR(?:\s|:).*$',
        '(?im)^\s*WARNING(?:\s|:).*$',
        '(?im)^.*ObjectDB.*(?:leak|still alive|instance).*$',
        '(?im)^\s*Orphan StringName:.*$',
        '(?im)^\s*StringName:.*\bunclaimed string names?\b.*$'
    )
    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($pattern in $patterns) {
        foreach ($match in [regex]::Matches($Text, $pattern)) {
            $line = $match.Value.Trim()
            if (-not [string]::IsNullOrWhiteSpace($line) -and -not $lines.Contains($line)) {
                $lines.Add($line)
            }
        }
    }
    return @($lines)
}


function Get-UnexpectedRedDiagnostics {
    param([string[]]$Diagnostics)
    return @($Diagnostics | Where-Object { $_ -notmatch '^ERROR:\s+RW06_6_PRODUCT_RED:' })
}


function Resolve-GuardDisposition {
    param(
        [int]$NativeExitCode,
        [bool]$NativeExitObserved,
        [int]$EffectiveExitCode,
        [bool]$TimedOut,
        [string]$RunnerError,
        [bool]$ProductRedMarkerSeen,
        [bool]$GuardPassMarkerSeen,
        [bool]$InfraFailureMarkerSeen,
        [bool]$FullPassMarkerSeen,
        [int]$UnexpectedDiagnosticCount
    )
    if (
        -not $NativeExitObserved `
        -or $TimedOut `
        -or -not [string]::IsNullOrWhiteSpace($RunnerError) `
        -or $InfraFailureMarkerSeen `
        -or $FullPassMarkerSeen `
        -or $UnexpectedDiagnosticCount -gt 0
    ) {
        return 'invalid'
    }
    if ($ProductRedMarkerSeen -and -not $GuardPassMarkerSeen -and $NativeExitCode -eq 10 -and $EffectiveExitCode -eq 10) {
        return 'valid_red'
    }
    if ($GuardPassMarkerSeen -and -not $ProductRedMarkerSeen -and $NativeExitCode -eq 0 -and $EffectiveExitCode -eq 0) {
        return 'green_handoff'
    }
    return 'invalid'
}


function Test-PhaseMarkerContract {
    param(
        [ValidateSet('Registry', 'Full')]
        [string]$Phase,
        [bool]$ProductRedMarkerSeen,
        [bool]$GuardPassMarkerSeen,
        [bool]$InfraFailureMarkerSeen,
        [bool]$FullPassMarkerSeen
    )
    if ($ProductRedMarkerSeen -or $GuardPassMarkerSeen -or $InfraFailureMarkerSeen) {
        return $false
    }
    if ($Phase -eq 'Registry') {
        return -not $FullPassMarkerSeen
    }
    return $FullPassMarkerSeen
}


function Test-Q016ApprovalText {
    param([string]$Text)
    $sectionMatches = [regex]::Matches($Text, '(?ims)^### Q-016\b(?<body>.*?)(?=^### |\z)')
    if ($sectionMatches.Count -ne 1) { return $false }
    $body = $sectionMatches[0].Groups['body'].Value
    return $body -match '(?im)^Status:\s*ANSWERED\s*$' -and $body -match '(?im)^Answer:\s*(?:\r?\n\s*)?A(?:\.|\s|$)'
}


function Get-StringSha256 {
    param([string]$Value)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
        return ([System.BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '')
    }
    finally {
        $sha.Dispose()
    }
}


function Get-Q016ApprovalSnapshot {
    if (-not (Test-Path -LiteralPath $ownerQuestionsPath -PathType Leaf)) {
        throw 'Canonical owner-question file is unavailable; Q-016 cannot be verified.'
    }
    $text = [System.IO.File]::ReadAllText($ownerQuestionsPath)
    $sectionMatches = [regex]::Matches($text, '(?ims)^### Q-016\b(?<section>.*?)(?=^### |\z)')
    if ($sectionMatches.Count -ne 1) {
        throw "Canonical owner-question file must contain exactly one Q-016 section; found $($sectionMatches.Count)."
    }
    $section = '### Q-016' + $sectionMatches[0].Groups['section'].Value
    & git -C $canonicalRepoRoot diff --quiet origin/main -- $ownerQuestionsRelativePath
    if ($LASTEXITCODE -ne 0) {
        throw 'Q-016 owner-question state is not byte-identical to canonical origin/main.'
    }
    $originMainCommit = (& git -C $canonicalRepoRoot rev-parse origin/main).Trim()
    $originBlobSpec = 'origin/main:{0}' -f $ownerQuestionsRelativePath
    $originBlob = (& git -C $canonicalRepoRoot rev-parse $originBlobSpec).Trim()
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($originMainCommit) -or [string]::IsNullOrWhiteSpace($originBlob)) {
        throw 'Could not bind Q-016 to canonical origin/main identity.'
    }
    return [ordered]@{
        answered_a = [bool](Test-Q016ApprovalText -Text $text)
        section_sha256 = Get-StringSha256 -Value $section
        file_sha256 = (Get-FileHash -LiteralPath $ownerQuestionsPath -Algorithm SHA256).Hash
        origin_main_commit = $originMainCommit
        origin_main_blob = $originBlob
        on_origin_main = $true
    }
}


function Assert-Q016ApprovalSnapshot {
    param([string]$ExpectedSectionSha256)
    $snapshot = Get-Q016ApprovalSnapshot
    if (-not $snapshot.answered_a) {
        throw 'Q-016 is not canonically ANSWERED A; no rw06_6 Godot phase is authorized.'
    }
    if (-not [string]::IsNullOrWhiteSpace($ExpectedSectionSha256) -and $snapshot.section_sha256 -ne $ExpectedSectionSha256) {
        throw 'Q-016 changed after authorization was captured; refusing engine launch.'
    }
    return $snapshot
}


function Read-LeaseFields {
    param([string]$Path)
    $fields = @{}
    foreach ($line in [System.IO.File]::ReadAllLines($Path)) {
        $separator = $line.IndexOf('=')
        if ($separator -le 0) { continue }
        $fields[$line.Substring(0, $separator)] = $line.Substring($separator + 1)
    }
    return $fields
}


function Assert-OwnedLease {
    param(
        [string]$Path,
        [string]$Root,
        [string]$Commit,
        [string]$Tree
    )
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw 'The owned Q-009 focused reservation disappeared before launch.'
    }
    $fields = Read-LeaseFields -Path $Path
    if ([int]$fields['pid'] -ne $PID -or -not (Get-Process -Id $PID -ErrorAction SilentlyContinue)) {
        throw 'The owned Q-009 lease PID is not this live launcher.'
    }
    if (-not [string]::Equals([System.IO.Path]::GetFullPath([string]$fields['worktree']), [System.IO.Path]::GetFullPath($Root), [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'The owned Q-009 lease worktree does not match the candidate.'
    }
    if ([string]$fields['candidate_commit'] -ne $Commit -or [string]$fields['candidate_tree'] -ne $Tree) {
        throw 'The owned Q-009 lease identity does not match the exact candidate.'
    }
}


function New-OwnedLeaseFile {
    param(
        [string]$Path,
        [string]$Text,
        [switch]$ForceWriteFailureForTest
    )
    $stream = $null
    $created = $false
    try {
        $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        $created = $true
        if ($ForceWriteFailureForTest) {
            throw 'Forced lease write failure for hostile validation.'
        }
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Flush()
        $stream.Dispose()
        $stream = $null
    }
    catch {
        if ($null -ne $stream) {
            try { $stream.Dispose() } catch {}
        }
        if ($created -and (Test-Path -LiteralPath $Path -PathType Leaf)) {
            Remove-Item -LiteralPath $Path -Force
        }
        throw
    }
}


function Restore-ProcessEnvironmentSafely {
    param(
        [System.Collections.IDictionary]$Snapshot,
        [switch]$ForceFailureForTest
    )
    try {
        if ($ForceFailureForTest) {
            throw 'Forced environment restoration failure for hostile validation.'
        }
        foreach ($entry in $Snapshot.GetEnumerator()) {
            if ($null -eq $entry.Value) {
                [Environment]::SetEnvironmentVariable([string]$entry.Key, $null, 'Process')
            }
            else {
                [Environment]::SetEnvironmentVariable([string]$entry.Key, [string]$entry.Value, 'Process')
            }
        }
        return [ordered]@{ succeeded = $true; error = '' }
    }
    catch {
        return [ordered]@{ succeeded = $false; error = $_.Exception.Message }
    }
}


function Invoke-GodotPhase {
    param(
        [string]$Name,
        [string[]]$Arguments,
        [string]$Root,
        [string]$RequiredCommit,
        [string]$RequiredTree,
        [string]$OwnedLeasePath,
        [string]$Q016SectionSha256,
        [string]$PhaseEvidenceRoot,
        [int]$TimeoutSec
    )
    New-Item -ItemType Directory -Force -Path $PhaseEvidenceRoot | Out-Null
    $stdoutPath = Join-Path $PhaseEvidenceRoot 'stdout.log'
    $stderrPath = Join-Path $PhaseEvidenceRoot 'stderr.log'
    $godotLogPath = Join-Path $PhaseEvidenceRoot 'godot.log'
    [System.IO.File]::WriteAllText($stdoutPath, '')
    [System.IO.File]::WriteAllText($stderrPath, '')
    [System.IO.File]::WriteAllText($godotLogPath, '')
    $phaseArguments = @('--log-file', $godotLogPath) + @($Arguments)
    $started = $null
    $baselineGodotRecords = @()
    $baselineGodotIdentityKeys = @()
    $startError = ''
    $startProof = [ordered]@{
        started = $false
        process_id = 0
        process_identity = $null
        provenance = 'none'
    }
    $mutex = [System.Threading.Mutex]::new($false, $launchMutexName)
    $mutexOwned = $false
    try {
        $mutexOwned = $mutex.WaitOne(5000)
        if (-not $mutexOwned) {
            throw 'Could not acquire the Q-009 launch lock for final identity and capacity checks.'
        }
        # This is intentionally the first candidate operation after acquiring
        # the launch lock for every phase.
        [void](Assert-CleanExactCandidate $Root $RequiredCommit $RequiredTree)
        [void](Assert-Q016ApprovalSnapshot -ExpectedSectionSha256 $Q016SectionSha256)
        Clear-StaleGodotLeases
        $exclusivePresent = Test-Path -LiteralPath $exclusiveLeasePath
        $focusedReservations = @(Get-ChildItem -LiteralPath $leaseRoot -Filter '*.lease' -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'EXCLUSIVE.lease' })
        $preLaunchGodotProcesses = @(Get-LiveGodotProcesses)
        $unleasedGodotRecords = @(Get-NewUnownedGodotRecords -BaselineKeys @())
        if ($exclusivePresent) { throw 'EXCLUSIVE.lease appeared after focused reservation; refusing launch.' }
        Assert-OwnedLease -Path $OwnedLeasePath -Root $Root -Commit $RequiredCommit -Tree $RequiredTree
        if ($unleasedGodotRecords.Count -gt 0) { throw 'An unleased Godot process exists; refusing rw06_6 launch.' }
        if ($focusedReservations.Count -gt 2) { throw "Q-009 focused reservation ceiling changed before launch: $($focusedReservations.Count) > 2." }
        if (($preLaunchGodotProcesses.Count + 2) -gt 4) { throw "Q-009 process ceiling changed before launch: $($preLaunchGodotProcesses.Count) + 2 > 4." }
        if (-not (Test-ReservedLaunchCapacity $exclusivePresent $focusedReservations.Count $preLaunchGodotProcesses.Count)) {
            throw 'Q-009 final reserved launch capacity check failed closed.'
        }
        $baselineGodotRecords = @(Get-LiveGodotIdentityRecords)
        $baselineGodotIdentityKeys = @($baselineGodotRecords | ForEach-Object { [string]$_.key })
        $started = Start-RedirectedProcess -FilePath $GodotPath -Arguments $phaseArguments -StdoutPath $stdoutPath -StderrPath $stderrPath -ProcessKind Godot -BaselineGodotIdentityKeys $baselineGodotIdentityKeys -TimeoutSec $TimeoutSec
    }
    catch {
        $startError = $_.Exception.Message
        $startProof = Get-OwnedProcessStartProofFromException -Exception $_.Exception
    }
    finally {
        if ($mutexOwned) { $mutex.ReleaseMutex() }
        $mutex.Dispose()
    }

    if ($null -eq $started) {
        [System.IO.File]::WriteAllText($stderrPath, $startError + [Environment]::NewLine)
        $processResult = [ordered]@{
            process_started = [bool]$startProof.started
            process_start_provenance = [string]$startProof.provenance
            native_exit_code = [int]$nativeExitSentinel
            native_exit_observed = $false
            native_exit_type = ''
            effective_exit_code = 125
            timed_out = $false
            elapsed_seconds = 0.0
            process_id = [int]$startProof.process_id
            started_utc = if ([bool]$startProof.started) { [string]$startProof.process_identity.start_utc } else { '' }
            process_identity = $startProof.process_identity
            retained_descendant_identities = @()
            error = $startError
        }
    }
    else {
        $processResult = Complete-RedirectedProcess -Started $started -TimeoutSec $TimeoutSec -ProcessKind Godot -BaselineGodotIdentityKeys $baselineGodotIdentityKeys
    }

    $ownedResidualPids = @()
    if ($null -ne $started) {
        $ownedResidualPids = @(Get-ExactOwnedGodotResidualPids -RootIdentity $started.process_identity -BaselineIdentityKeys $baselineGodotIdentityKeys -RetainedDescendantRecords $started.retained_descendant_records)
        if ($ownedResidualPids.Count -gt 0) {
            $residualError = 'Owned Godot process tree remained after bounded completion: ' + ($ownedResidualPids -join ',')
            if ([string]::IsNullOrWhiteSpace([string]$processResult.error)) { $processResult.error = $residualError }
            else { $processResult.error = [string]$processResult.error + ' | ' + $residualError }
            $processResult.effective_exit_code = 125
        }
    }
    elseif ([bool]$startProof.started -and (Test-LiveProcessMatchesIdentity -ExpectedIdentity $startProof.process_identity)) {
        $ownedResidualPids = @([int]$startProof.process_id)
        $residualError = 'Exact process remained after start/setup exception: ' + [string]$startProof.process_id
        if ([string]::IsNullOrWhiteSpace([string]$processResult.error)) { $processResult.error = $residualError }
        else { $processResult.error = [string]$processResult.error + ' | ' + $residualError }
        $processResult.effective_exit_code = 125
    }

    $combinedText = ''
    foreach ($path in @($stdoutPath, $stderrPath, $godotLogPath)) {
        if (Test-Path -LiteralPath $path) {
            $combinedText += "`n--- $([System.IO.Path]::GetFileName($path)) ---`n"
            $combinedText += [System.IO.File]::ReadAllText($path)
        }
    }
    $diagnostics = @(Get-DiagnosticLines -Text $combinedText)
    $hashes = [ordered]@{}
    foreach ($path in @($stdoutPath, $stderrPath, $godotLogPath)) {
        if (Test-Path -LiteralPath $path) {
            $hashes[[System.IO.Path]::GetFileName($path)] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
        }
    }
    return [ordered]@{
        name = $Name
        command = $GodotPath
        arguments = $phaseArguments
        process_started = [bool]$processResult.process_started
        process_start_provenance = [string]$processResult.process_start_provenance
        native_exit_code = $processResult.native_exit_code
        native_exit_observed = [bool]$processResult.native_exit_observed
        native_exit_type = $processResult.native_exit_type
        effective_exit_code = [int]$processResult.effective_exit_code
        timed_out = [bool]$processResult.timed_out
        elapsed_seconds = $processResult.elapsed_seconds
        process_id = $processResult.process_id
        started_utc = $processResult.started_utc
        process_identity = $processResult.process_identity
        retained_descendant_identities = @($processResult.retained_descendant_identities)
        launcher_error = $processResult.error
        baseline_godot = @($baselineGodotRecords)
        owned_residual_process_ids = @($ownedResidualPids)
        product_red_marker = $combinedText.Contains('RW06_6_PRODUCT_RED')
        guard_pass_marker = $combinedText.Contains('RW06_6_GUARD_PASS')
        infra_failure_marker = $combinedText.Contains('RW06_6_GUARD_INFRA_FAILURE')
        full_pass_marker = $combinedText.Contains('RW06_6_PULL_TAB_GLIMMER PASS')
        diagnostics_clean = ($diagnostics.Count -eq 0)
        diagnostics = $diagnostics
        evidence_root = $PhaseEvidenceRoot
        sha256 = $hashes
    }
}


function Remove-DedicatedProjectCache {
    param([string]$Root, [string]$CacheRoot)
    $resolvedRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd([char[]]@([char]'\', [char]'/'))
    $resolvedCache = [System.IO.Path]::GetFullPath($CacheRoot).TrimEnd([char[]]@([char]'\', [char]'/'))
    $expectedCache = [System.IO.Path]::GetFullPath((Join-Path $resolvedRoot '.godot')).TrimEnd([char[]]@([char]'\', [char]'/'))
    if ($resolvedCache -ne $expectedCache -or -not $resolvedCache.StartsWith($resolvedRoot + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove unexpected cache path: $resolvedCache"
    }
    if (Test-Path -LiteralPath $resolvedCache) {
        $cacheItem = Get-Item -LiteralPath $resolvedCache -Force
        if (($cacheItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Refusing to remove reparse-point cache: $resolvedCache"
        }
        Remove-Item -LiteralPath $resolvedCache -Recurse -Force
    }
}


function Assert-ProjectCacheAbsent {
    param([string]$Context)
    if (Test-Path -LiteralPath $projectCacheRoot) {
        throw "$Context requires candidate-local .godot, class, UID, and imported artifacts to be absent."
    }
}


function Assert-ProjectCacheIgnored {
    foreach ($probe in @('.godot/global_script_class_cache.cfg', '.godot/uid_cache.bin', '.godot/imported/rw06_6-probe.ctex')) {
        & git -C $projectRoot check-ignore -q -- $probe
        if ($LASTEXITCODE -ne 0) {
            throw "Candidate-local registry artifact is not git-ignored: $probe"
        }
    }
}


function Assert-RequiredGlobalClassEntries {
    param([string]$CachePath)
    $cacheText = [System.IO.File]::ReadAllText($CachePath)
    $requiredEntries = [ordered]@{
        RunState = 'res://scripts/core/run_state.gd'
        ContentLibrary = 'res://scripts/core/content_library.gd'
        GameModule = 'res://scripts/core/game_module.gd'
        RngStream = 'res://scripts/core/rng_stream.gd'
        PullTabsGame = 'res://scripts/games/pull_tabs.gd'
    }
    foreach ($className in $requiredEntries.Keys) {
        $escapedClass = [regex]::Escape([string]$className)
        $escapedPath = [regex]::Escape([string]$requiredEntries[$className])
        $pattern = '(?s)"class"\s*:\s*&?"' + $escapedClass + '".{0,1200}?"path"\s*:\s*"' + $escapedPath + '"'
        if (-not [regex]::IsMatch($cacheText, $pattern)) {
            throw "Global class cache lacks exact class/path entry: $className -> $($requiredEntries[$className])"
        }
    }
}


function Write-ImportedArtifactManifest {
    param([string]$DestinationPath)
    if (-not (Test-Path -LiteralPath $importedRoot -PathType Container)) {
        throw 'Godot registry import produced no canonical .godot/imported directory.'
    }
    $importedItem = Get-Item -LiteralPath $importedRoot -Force
    if (($importedItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw 'Godot registry import produced a reparse-point imported directory.'
    }
    $entries = [System.Collections.Generic.List[object]]::new()
    foreach ($file in (Get-ChildItem -LiteralPath $importedRoot -File -Recurse -Force | Sort-Object FullName)) {
        $relativePath = $file.FullName.Substring($projectCacheRoot.Length).TrimStart([char[]]@([char]'\', [char]'/')).Replace('\', '/')
        $entries.Add([ordered]@{
            path = $relativePath
            length = [long]$file.Length
            sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
        })
    }
    if ($entries.Count -eq 0) {
        throw 'Godot registry import produced an empty canonical imported-artifact census.'
    }
    $manifest = [ordered]@{
        root = '.godot/imported'
        count = $entries.Count
        files = @($entries)
    }
    [System.IO.File]::WriteAllText($DestinationPath, (($manifest | ConvertTo-Json -Depth 6) + "`n"))
    return [ordered]@{
        count = $entries.Count
        path = $DestinationPath
        sha256 = (Get-FileHash -LiteralPath $DestinationPath -Algorithm SHA256).Hash
    }
}


function Get-TrackedFileIdentity {
    param(
        [string]$Root,
        [string]$Commit,
        [string]$RelativePath
    )
    $fullPath = Join-Path $Root ($RelativePath.Replace('/', '\'))
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        throw "Required harness/product file is missing: $RelativePath"
    }
    $treeSpec = '{0}:{1}' -f $Commit, $RelativePath
    $blob = (& git -C $Root rev-parse $treeSpec).Trim()
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($blob)) {
        throw "Could not bind tracked blob identity for $RelativePath"
    }
    return [ordered]@{
        path = $RelativePath
        git_blob = $blob
        length = [long](Get-Item -LiteralPath $fullPath).Length
        sha256 = (Get-FileHash -LiteralPath $fullPath -Algorithm SHA256).Hash
    }
}


function Get-LiveGodotIdentityRecords {
    $records = [System.Collections.Generic.List[object]]::new()
    foreach ($process in @(Get-LiveGodotProcesses)) {
        try {
            $records.Add((Get-ProcessIdentityRecord -Process $process))
        }
        catch {
            throw "Could not bind live Godot process identity for PID $($process.Id)."
        }
    }
    return @($records)
}


function Get-LiveFocusedLeaseOwnerPids {
    $ownerPids = [System.Collections.Generic.List[int]]::new()
    foreach ($lease in @(Get-ChildItem -LiteralPath $leaseRoot -Filter '*.lease' -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'EXCLUSIVE.lease' })) {
        $match = [regex]::Match($lease.Name, '-(?<pid>\d+)\.lease$')
        if (-not $match.Success) { continue }
        $ownerPid = [int]$match.Groups['pid'].Value
        if (Get-Process -Id $ownerPid -ErrorAction SilentlyContinue) {
            $ownerPids.Add($ownerPid)
        }
    }
    return @($ownerPids)
}


function Test-ProcessHasLeaseAncestor {
    param([int]$ProcessId, [int[]]$LeaseOwnerPids)
    if ($LeaseOwnerPids.Count -eq 0) { return $false }
    $processTable = @{}
    foreach ($entry in @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue)) {
        $processTable[[int]$entry.ProcessId] = [int]$entry.ParentProcessId
    }
    $cursor = $ProcessId
    for ($depth = 0; $depth -lt 32; $depth += 1) {
        if ($LeaseOwnerPids -contains $cursor) { return $true }
        if (-not $processTable.ContainsKey($cursor)) { return $false }
        $parent = [int]$processTable[$cursor]
        if ($parent -le 0 -or $parent -eq $cursor) { return $false }
        $cursor = $parent
    }
    return $false
}


function Get-NewUnownedGodotRecords {
    param([string[]]$BaselineKeys)
    $leaseOwnerPids = @(Get-LiveFocusedLeaseOwnerPids)
    return @(Get-LiveGodotIdentityRecords | Where-Object {
        $record = $_
        $BaselineKeys -notcontains [string]$record.key -and -not (Test-ProcessHasLeaseAncestor -ProcessId ([int]$record.pid) -LeaseOwnerPids $leaseOwnerPids)
    })
}


if ($ValidateOnly) {
    Assert-LauncherContract ($leaseRoot -ceq $canonicalLeaseRoot) 'Q-009 launcher did not resolve the exact canonical lease root.'
    Assert-LauncherContract (Test-FocusedLaunchCapacity $false 0 0) 'Q-009 capacity rejected an empty machine.'
    Assert-LauncherContract (Test-FocusedLaunchCapacity $false 1 2) 'Q-009 capacity rejected the second focused console/child pair.'
    Assert-LauncherContract (-not (Test-FocusedLaunchCapacity $true 0 0)) 'Q-009 capacity ignored EXCLUSIVE.lease.'
    Assert-LauncherContract (-not (Test-FocusedLaunchCapacity $false 2 0)) 'Q-009 capacity allowed a third focused pair.'
    Assert-LauncherContract (-not (Test-FocusedLaunchCapacity $false 1 3)) 'Q-009 capacity allowed current processes plus two to exceed four.'
    Assert-LauncherContract (Test-ReservedLaunchCapacity $false 2 2) 'Q-009 reserved capacity rejected the valid ceiling.'
    Assert-LauncherContract (-not (Test-ReservedLaunchCapacity $true 1 0)) 'Q-009 reserved capacity ignored EXCLUSIVE.lease.'
    Assert-LauncherContract (-not (Test-ReservedLaunchCapacity $false 3 0)) 'Q-009 reserved capacity allowed more than two focused reservations.'
    Assert-LauncherContract (-not (Test-ReservedLaunchCapacity $false 2 3)) 'Q-009 reserved capacity allowed more than four projected processes.'
    $selfProcess = Get-Process -Id $PID
    $selfIdentity = Get-ProcessIdentityRecord -Process $selfProcess
    Assert-LauncherContract (Test-LiveProcessMatchesIdentity -ExpectedIdentity $selfIdentity) 'PID/start-time/name identity matcher rejected the current process.'
    $wrongNameIdentity = [ordered]@{
        pid = [int]$selfIdentity.pid
        name = [string]$selfIdentity.name + '-wrong'
        start_utc = [string]$selfIdentity.start_utc
        start_ticks = [long]$selfIdentity.start_ticks
        key = ('{0}|{1}|{2}-wrong' -f $selfIdentity.pid, $selfIdentity.start_ticks, $selfIdentity.name)
    }
    Assert-LauncherContract (-not (Test-LiveProcessMatchesIdentity -ExpectedIdentity $wrongNameIdentity)) 'PID/start-time/name identity matcher accepted a wrong process name.'
    $wrongStartIdentity = [ordered]@{
        pid = [int]$selfIdentity.pid
        name = [string]$selfIdentity.name
        start_utc = $selfProcess.StartTime.AddSeconds(-1).ToUniversalTime().ToString('o')
        start_ticks = [long]$selfProcess.StartTime.AddSeconds(-1).ToUniversalTime().Ticks
        key = ('{0}|{1}|{2}' -f $selfIdentity.pid, $selfProcess.StartTime.AddSeconds(-1).ToUniversalTime().Ticks, $selfIdentity.name)
    }
    Assert-LauncherContract (-not (Test-LiveProcessMatchesIdentity -ExpectedIdentity $wrongStartIdentity)) 'PID/start-time/name identity matcher accepted a reused-process timestamp.'
    Assert-LauncherContract ([string]$selfIdentity.key -eq ('{0}|{1}|{2}' -f $PID, $selfProcess.StartTime.ToUniversalTime().Ticks, $selfProcess.ProcessName)) 'Process identity key is not PID + UTC start ticks + name.'
    Assert-LauncherContract (Test-ProcessIdentityProofShape -Identity $selfIdentity) 'Exact process identity proof validator rejected a real PID/start/name identity.'
    $validStartException = [System.InvalidOperationException]::new('valid exact start proof')
    $validStartException.Data['owned_process_id'] = [int]$selfIdentity.pid
    $validStartException.Data['owned_process_identity'] = $selfIdentity
    $validStartProof = Get-OwnedProcessStartProofFromException -Exception $validStartException
    Assert-LauncherContract ([bool]$validStartProof.started -and [int]$validStartProof.process_id -eq [int]$selfIdentity.pid -and [string]$validStartProof.process_identity.key -ceq [string]$selfIdentity.key) 'Exact process start proof was not recovered from an exception.'
    $pidOnlyStartException = [System.InvalidOperationException]::new('pid only is not exact proof')
    $pidOnlyStartException.Data['owned_process_id'] = [int]$selfIdentity.pid
    $pidOnlyStartProof = Get-OwnedProcessStartProofFromException -Exception $pidOnlyStartException
    Assert-LauncherContract (-not [bool]$pidOnlyStartProof.started) 'PID-only exception metadata was accepted as exact process-start proof.'
    $malformedStartException = [System.InvalidOperationException]::new('malformed identity is not exact proof')
    $malformedIdentity = [ordered]@{}
    foreach ($entry in $selfIdentity.GetEnumerator()) { $malformedIdentity[$entry.Key] = $entry.Value }
    $malformedIdentity.key = [string]$malformedIdentity.key + '|wrong'
    $malformedStartException.Data['owned_process_id'] = [int]$selfIdentity.pid
    $malformedStartException.Data['owned_process_identity'] = $malformedIdentity
    $malformedStartProof = Get-OwnedProcessStartProofFromException -Exception $malformedStartException
    Assert-LauncherContract (-not [bool]$malformedStartProof.started) 'Malformed identity metadata was accepted as exact process-start proof.'

    Assert-LauncherContract (Test-CimCreationMatchesProcessStartTicks -CreationTicks 150 -ProcessStartTicks 159) 'CIM/process start comparison rejected exact microsecond truncation.'
    Assert-LauncherContract (-not (Test-CimCreationMatchesProcessStartTicks -CreationTicks 140 -ProcessStartTicks 159)) 'CIM/process start comparison accepted a predecessor timestamp one microsecond away.'
    Assert-LauncherContract (-not (Test-CimCreationMatchesProcessStartTicks -CreationTicks 1000000 -ProcessStartTicks 1099999)) 'CIM/process start comparison accepted a replacement 99,999 ticks inside the former 10 ms tolerance.'

    $syntheticRootIdentity = [ordered]@{ pid = 100; name = 'root'; start_utc = ''; start_ticks = [long]100; key = '100|100|root' }
    $oldBridgeIdentity = [ordered]@{ pid = 200; name = 'old-bridge'; start_utc = ''; start_ticks = [long]50; key = '200|50|old-bridge' }
    $goodChildIdentity = [ordered]@{ pid = 201; name = 'good-child'; start_utc = ''; start_ticks = [long]150; key = '201|150|good-child' }
    $baselineChildIdentity = [ordered]@{ pid = 203; name = 'baseline-child'; start_utc = ''; start_ticks = [long]160; key = '203|160|baseline-child' }
    $acceptedParentIdentity = [ordered]@{ pid = 205; name = 'accepted-parent'; start_utc = ''; start_ticks = [long]180; key = '205|180|accepted-parent' }
    $reusedParentIdentity = [ordered]@{ pid = 205; name = 'reused-parent'; start_utc = ''; start_ticks = [long]240; key = '205|240|reused-parent' }
    $syntheticCandidates = @(
        [ordered]@{ parent_pid = 100; parent_identity = $syntheticRootIdentity; creation_ticks = [long]50; identity = $oldBridgeIdentity },
        [ordered]@{ parent_pid = 200; parent_identity = $oldBridgeIdentity; creation_ticks = [long]200; identity = [ordered]@{ pid = 300; name = 'bridged-godot'; start_utc = ''; start_ticks = [long]200; key = '300|200|bridged-godot' } },
        [ordered]@{ parent_pid = 100; parent_identity = $syntheticRootIdentity; creation_ticks = [long]150; identity = $goodChildIdentity },
        [ordered]@{ parent_pid = 201; parent_identity = $goodChildIdentity; creation_ticks = [long]220; identity = [ordered]@{ pid = 301; name = 'good-grandchild'; start_utc = ''; start_ticks = [long]220; key = '301|220|good-grandchild' } },
        [ordered]@{ parent_pid = 100; parent_identity = $syntheticRootIdentity; creation_ticks = [long]500; identity = [ordered]@{ pid = 202; name = 'late-child'; start_utc = ''; start_ticks = [long]501; key = '202|501|late-child' } },
        [ordered]@{ parent_pid = 100; parent_identity = $syntheticRootIdentity; creation_ticks = [long]160; identity = $baselineChildIdentity },
        [ordered]@{ parent_pid = 203; parent_identity = $baselineChildIdentity; creation_ticks = [long]230; identity = [ordered]@{ pid = 303; name = 'baseline-grandchild'; start_utc = ''; start_ticks = [long]230; key = '303|230|baseline-grandchild' } },
        [ordered]@{ parent_pid = 100; parent_identity = $syntheticRootIdentity; creation_ticks = [long]500000; identity = [ordered]@{ pid = 204; name = 'creation-mismatch'; start_utc = ''; start_ticks = [long]170; key = '204|170|creation-mismatch' } },
        [ordered]@{ parent_pid = 100; parent_identity = $syntheticRootIdentity; creation_ticks = [long]180; identity = $acceptedParentIdentity },
        [ordered]@{ parent_pid = 205; parent_identity = $reusedParentIdentity; creation_ticks = [long]260; identity = [ordered]@{ pid = 305; name = 'reused-parent-child'; start_utc = ''; start_ticks = [long]260; key = '305|260|reused-parent-child' } },
        [ordered]@{ parent_pid = 100; parent_identity = $syntheticRootIdentity; creation_ticks = [long]180; identity = [ordered]@{ pid = 206; name = 'near-tolerance-replacement'; start_utc = ''; start_ticks = [long]190; key = '206|190|near-tolerance-replacement' } }
    )
    $syntheticVerified = @(Resolve-VerifiedDescendantIdentityRecords -RootIdentity $syntheticRootIdentity -OwnershipEndTicks 500 -BaselineIdentityKeys @('203|160|baseline-child') -Candidates $syntheticCandidates)
    $syntheticVerifiedKeys = @($syntheticVerified | ForEach-Object { [string]$_.key })
    Assert-LauncherContract ($syntheticVerifiedKeys.Count -eq 3 -and $syntheticVerifiedKeys -contains '201|150|good-child' -and $syntheticVerifiedKeys -contains '301|220|good-grandchild' -and $syntheticVerifiedKeys -contains '205|180|accepted-parent') 'Verified lineage resolver rejected a valid direct/deeper chain.'
    Assert-LauncherContract ($syntheticVerifiedKeys -notcontains '300|200|bridged-godot' -and $syntheticVerifiedKeys -notcontains '303|230|baseline-grandchild' -and $syntheticVerifiedKeys -notcontains '202|501|late-child' -and $syntheticVerifiedKeys -notcontains '204|170|creation-mismatch' -and $syntheticVerifiedKeys -notcontains '305|260|reused-parent-child' -and $syntheticVerifiedKeys -notcontains '206|190|near-tolerance-replacement') 'Verified lineage resolver admitted an unverified intermediate, baseline bridge, late child, reused-parent child, or non-representable creation time.'

    Assert-LauncherContract ((Resolve-GuardDisposition -NativeExitCode 10 -NativeExitObserved $true -EffectiveExitCode 10 -TimedOut $false -RunnerError '' -ProductRedMarkerSeen $true -GuardPassMarkerSeen $false -InfraFailureMarkerSeen $false -FullPassMarkerSeen $false -UnexpectedDiagnosticCount 0) -eq 'valid_red') 'Guard classifier rejected a deliberate clean RED.'
    Assert-LauncherContract ((Resolve-GuardDisposition -NativeExitCode 0 -NativeExitObserved $true -EffectiveExitCode 0 -TimedOut $false -RunnerError '' -ProductRedMarkerSeen $false -GuardPassMarkerSeen $true -InfraFailureMarkerSeen $false -FullPassMarkerSeen $false -UnexpectedDiagnosticCount 0) -eq 'green_handoff') 'Guard classifier rejected a clean GREEN handoff.'
    Assert-LauncherContract ((Resolve-GuardDisposition -NativeExitCode 2 -NativeExitObserved $true -EffectiveExitCode 2 -TimedOut $false -RunnerError '' -ProductRedMarkerSeen $false -GuardPassMarkerSeen $false -InfraFailureMarkerSeen $true -FullPassMarkerSeen $false -UnexpectedDiagnosticCount 0) -eq 'invalid') 'Guard classifier accepted an infrastructure failure.'
    Assert-LauncherContract ((Resolve-GuardDisposition -NativeExitCode 10 -NativeExitObserved $true -EffectiveExitCode 10 -TimedOut $false -RunnerError '' -ProductRedMarkerSeen $true -GuardPassMarkerSeen $false -InfraFailureMarkerSeen $false -FullPassMarkerSeen $false -UnexpectedDiagnosticCount 1) -eq 'invalid') 'Guard classifier accepted a parser/import diagnostic.'
    $orphanDiagnostics = @(Get-DiagnosticLines -Text "Orphan StringName: Node (static: 3, total: 4)`nStringName: 1 unclaimed string names at exit.`n")
    Assert-LauncherContract ($orphanDiagnostics.Count -eq 2) 'Diagnostic classifier did not fail closed on both registry StringName orphan forms.'
    Assert-LauncherContract ($orphanDiagnostics -contains 'Orphan StringName: Node (static: 3, total: 4)') 'Diagnostic classifier missed the Orphan StringName form.'
    Assert-LauncherContract ($orphanDiagnostics -contains 'StringName: 1 unclaimed string names at exit.') 'Diagnostic classifier missed the unclaimed StringName form.'
    Assert-LauncherContract ((Resolve-GuardDisposition -NativeExitCode 0 -NativeExitObserved $true -EffectiveExitCode 0 -TimedOut $false -RunnerError '' -ProductRedMarkerSeen $true -GuardPassMarkerSeen $true -InfraFailureMarkerSeen $false -FullPassMarkerSeen $false -UnexpectedDiagnosticCount 0) -eq 'invalid') 'Guard classifier accepted mixed RED/GREEN markers.'
    Assert-LauncherContract ((Resolve-GuardDisposition -NativeExitCode $nativeExitSentinel -NativeExitObserved $false -EffectiveExitCode 125 -TimedOut $false -RunnerError 'missing exit' -ProductRedMarkerSeen $true -GuardPassMarkerSeen $false -InfraFailureMarkerSeen $false -FullPassMarkerSeen $false -UnexpectedDiagnosticCount 0) -eq 'invalid') 'Guard classifier accepted an unobserved native exit.'
    Assert-LauncherContract (Test-PhaseMarkerContract -Phase Registry -ProductRedMarkerSeen $false -GuardPassMarkerSeen $false -InfraFailureMarkerSeen $false -FullPassMarkerSeen $false) 'Registry marker classifier rejected a marker-free phase.'
    Assert-LauncherContract (-not (Test-PhaseMarkerContract -Phase Registry -ProductRedMarkerSeen $true -GuardPassMarkerSeen $false -InfraFailureMarkerSeen $false -FullPassMarkerSeen $false)) 'Registry marker classifier accepted PRODUCT_RED.'
    Assert-LauncherContract (-not (Test-PhaseMarkerContract -Phase Registry -ProductRedMarkerSeen $false -GuardPassMarkerSeen $true -InfraFailureMarkerSeen $false -FullPassMarkerSeen $false)) 'Registry marker classifier accepted GUARD_PASS.'
    Assert-LauncherContract (-not (Test-PhaseMarkerContract -Phase Registry -ProductRedMarkerSeen $false -GuardPassMarkerSeen $false -InfraFailureMarkerSeen $true -FullPassMarkerSeen $false)) 'Registry marker classifier accepted GUARD_INFRA_FAILURE.'
    Assert-LauncherContract (-not (Test-PhaseMarkerContract -Phase Registry -ProductRedMarkerSeen $false -GuardPassMarkerSeen $false -InfraFailureMarkerSeen $false -FullPassMarkerSeen $true)) 'Registry marker classifier accepted the full-contract PASS marker.'
    Assert-LauncherContract (Test-PhaseMarkerContract -Phase Full -ProductRedMarkerSeen $false -GuardPassMarkerSeen $false -InfraFailureMarkerSeen $false -FullPassMarkerSeen $true) 'Full marker classifier rejected its sole expected PASS marker.'
    Assert-LauncherContract (-not (Test-PhaseMarkerContract -Phase Full -ProductRedMarkerSeen $false -GuardPassMarkerSeen $false -InfraFailureMarkerSeen $false -FullPassMarkerSeen $false)) 'Full marker classifier accepted a missing PASS marker.'
    Assert-LauncherContract (-not (Test-PhaseMarkerContract -Phase Full -ProductRedMarkerSeen $true -GuardPassMarkerSeen $false -InfraFailureMarkerSeen $false -FullPassMarkerSeen $true)) 'Full marker classifier accepted PRODUCT_RED alongside PASS.'
    Assert-LauncherContract (-not (Test-PhaseMarkerContract -Phase Full -ProductRedMarkerSeen $false -GuardPassMarkerSeen $true -InfraFailureMarkerSeen $false -FullPassMarkerSeen $true)) 'Full marker classifier accepted GUARD_PASS alongside PASS.'
    Assert-LauncherContract (-not (Test-PhaseMarkerContract -Phase Full -ProductRedMarkerSeen $false -GuardPassMarkerSeen $false -InfraFailureMarkerSeen $true -FullPassMarkerSeen $true)) 'Full marker classifier accepted GUARD_INFRA_FAILURE alongside PASS.'

    Assert-LauncherContract (Test-Q016ApprovalText "### Q-016`nStatus: ANSWERED`nAnswer:`nA`n") 'Q-016 parser rejected a multiline ANSWERED A.'
    Assert-LauncherContract (-not (Test-Q016ApprovalText "### Q-016`nStatus: OPEN`nAnswer:`n")) 'Q-016 parser accepted OPEN.'
    Assert-LauncherContract (-not (Test-Q016ApprovalText "### Q-016`nStatus: ANSWERED`nAnswer: B. Refactor.`n")) 'Q-016 parser accepted option B.'
    Assert-LauncherContract (-not (Test-Q016ApprovalText "### Q-016`nStatus: ANSWERED`nAnswer: A`n### Q-016`nStatus: ANSWERED`nAnswer: A`n")) 'Q-016 parser accepted duplicate Q-016 sections.'

    $leaseProbeRoot = Join-Path $projectRoot ('.tmp\rw06_6\lease-selftest-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $leaseProbeRoot | Out-Null
    $partialLeasePath = Join-Path $leaseProbeRoot 'forced-partial.lease'
    $forcedLeaseFailure = $false
    try {
        New-OwnedLeaseFile -Path $partialLeasePath -Text "pid=$PID`n" -ForceWriteFailureForTest
    }
    catch {
        $forcedLeaseFailure = $true
    }
    Assert-LauncherContract $forcedLeaseFailure 'Lease hostile probe did not execute its forced post-CreateNew failure.'
    Assert-LauncherContract (-not (Test-Path -LiteralPath $partialLeasePath)) 'Lease hostile probe left an unowned partial reservation.'

    $environmentProbeName = 'RW06_6_ENV_RESTORE_PROBE'
    $environmentProbeOriginal = [Environment]::GetEnvironmentVariable($environmentProbeName, 'Process')
    try {
        [Environment]::SetEnvironmentVariable($environmentProbeName, 'mutated', 'Process')
        $environmentProbeSnapshot = [ordered]@{ $environmentProbeName = $environmentProbeOriginal }
        $environmentProbeResult = Restore-ProcessEnvironmentSafely -Snapshot $environmentProbeSnapshot
        Assert-LauncherContract ([bool]$environmentProbeResult.succeeded) 'Environment restoration helper rejected a valid snapshot.'
        Assert-LauncherContract ([Environment]::GetEnvironmentVariable($environmentProbeName, 'Process') -eq $environmentProbeOriginal) 'Environment restoration helper did not restore the exact prior value.'
        $environmentFailureProbe = Restore-ProcessEnvironmentSafely -Snapshot $environmentProbeSnapshot -ForceFailureForTest
        Assert-LauncherContract (-not [bool]$environmentFailureProbe.succeeded -and -not [string]::IsNullOrWhiteSpace([string]$environmentFailureProbe.error)) 'Environment restoration helper did not contain a forced failure.'
    }
    finally {
        [Environment]::SetEnvironmentVariable($environmentProbeName, $environmentProbeOriginal, 'Process')
    }

    $guardPath = Join-Path $projectRoot ($guardRelativePath.Replace('/', '\'))
    $fullContractPath = Join-Path $projectRoot ($fullContractRelativePath.Replace('/', '\'))
    $guardSource = [System.IO.File]::ReadAllText($guardPath)
    $fullContractSource = [System.IO.File]::ReadAllText($fullContractPath)
    Assert-LauncherContract (-not $guardPath.EndsWith('_contract.gd', [System.StringComparison]::OrdinalIgnoreCase)) 'Zero-preload guard would be auto-discovered as a root contract.'
    Assert-LauncherContract (-not [regex]::IsMatch($guardSource, '(?im)^\s*(?!#).*\b(?:preload|load|ResourceLoader)\s*\(')) 'Zero-preload guard contains a project resource load.'
    Assert-LauncherContract (-not [regex]::IsMatch($guardSource, '(?im)^\s*(?:extends|class_name|var|const|func)\b[^\r\n]*(?:RunState|GameModule|ContentLibrary|RngStream|PullTabsGame)')) 'Zero-preload guard has an executable project-global dependency.'
    Assert-LauncherContract (-not $guardSource.Contains('push_error')) 'Deliberate product RED must be print-only.'
    $fileCheckIndex = $guardSource.IndexOf('FileAccess.file_exists(PULL_TABS_SCRIPT_PATH)')
    $readIndex = $guardSource.IndexOf('FileAccess.get_file_as_string(PULL_TABS_SCRIPT_PATH)')
    $redIndex = $guardSource.IndexOf('RW06_6_PRODUCT_RED')
    $passIndex = $guardSource.IndexOf('RW06_6_GUARD_PASS')
    Assert-LauncherContract ($fileCheckIndex -ge 0 -and $fileCheckIndex -lt $readIndex -and $readIndex -lt $redIndex -and $redIndex -lt $passIndex) 'Guard source order is not fixture-check, read, PRODUCT_RED, GUARD_PASS.'
    Assert-LauncherContract ($guardSource.Contains('quit(10)') -and $guardSource.Contains('quit(2)') -and $guardSource.Contains('quit(0)')) 'Guard lacks distinct product-red, infrastructure, and pass native exits.'
    Assert-LauncherContract ($fullContractSource.Contains('const PullTabsScript := preload("res://scripts/games/pull_tabs.gd")')) 'Full root contract no longer exercises the production pull-tabs script.'
    Assert-LauncherContract ($fullContractSource.Contains('RW06_6_PULL_TAB_GLIMMER PASS')) 'Full root contract lost its PASS marker.'
    Assert-LauncherContract (-not [regex]::IsMatch($fullContractSource, '(?im)^\s*var\s+[A-Za-z_][A-Za-z0-9_]*\s*:=\s*game\.surface_action_command\s*\(')) 'Full root contract still relies on unsafe dynamic surface-action type inference.'

    $launcherSource = [System.IO.File]::ReadAllText($PSCommandPath)
    Assert-LauncherContract (-not [regex]::IsMatch($launcherSource, '(?im)^\s*Start-Process\b')) 'Launcher still invokes Start-Process.'
    Assert-LauncherContract (-not [regex]::IsMatch($launcherSource, '\.WaitForExit\(\s*\)')) 'Launcher contains an unbounded parameterless WaitForExit.'
    $launcherTokens = $null
    $launcherParseErrors = $null
    $launcherAst = [System.Management.Automation.Language.Parser]::ParseInput($launcherSource, [ref]$launcherTokens, [ref]$launcherParseErrors)
    Assert-LauncherContract ($launcherParseErrors.Count -eq 0) 'Launcher could not parse its own source for scoped static validation.'
    $validateOnlyAsts = @($launcherAst.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.IfStatementAst] `
            -and $node.Clauses.Count -eq 1 `
            -and $node.Clauses[0].Item1.Extent.Text.Trim() -ceq '$ValidateOnly'
    }, $true))
    Assert-LauncherContract ($validateOnlyAsts.Count -eq 1) 'Launcher must contain exactly one ValidateOnly statement AST.'
    $validateOnlyExtent = $validateOnlyAsts[0].Extent
    $runtimeLauncherSource = $launcherSource.Substring(0, $validateOnlyExtent.StartOffset) + $launcherSource.Substring($validateOnlyExtent.EndOffset)
    Assert-LauncherContract (-not $runtimeLauncherSource.Contains('Launcher source contract is missing:')) 'Runtime source-check region includes its own ValidateOnly checklist.'
    foreach ($required in @(
        'System.Diagnostics.ProcessStartInfo',
        'System.IO.FileStream',
        'BaseStream.CopyToAsync',
        'ConvertTo-WindowsCommandLineArgument',
        'Get-StrictNativeExitCode',
        'Get-OwnedProcessStartProofFromException',
        'Test-CimCreationMatchesProcessStartTicks',
        "owned_process_identity",
        'parent_identity',
        'process_start_provenance',
        'registration_process_identity',
        '$process.Refresh()',
        '$process.HasExited',
        "'--import'",
        'Assert-CleanExactCandidate',
        'Assert-Q016ApprovalSnapshot',
        'Assert-OwnedLease',
        'Test-ReservedLaunchCapacity',
        '$unleasedGodotRecords = @(Get-NewUnownedGodotRecords -BaselineKeys @())',
        'Get-ProcessIdentityRecord -Process $child',
        'if ([string]$currentIdentity.key -ceq [string]$record.key)',
        'if ([string]$currentConsoleIdentity.key -ceq [string]$ConsoleIdentity.key)',
        'retained_descendant_records',
        '-RootExitTimeUtc $rootExitTimeUtc',
        'Test-PhaseMarkerContract -Phase Registry',
        'Test-PhaseMarkerContract -Phase Full',
        'Restore-ProcessEnvironmentSafely -Snapshot $oldEnvironment',
        'Remove-DedicatedProjectCache',
        'Write-ImportedArtifactManifest'
    )) {
        Assert-LauncherContract ($runtimeLauncherSource.Contains($required)) "Launcher runtime contract is missing: $required"
    }
    $environmentRestoreIndex = $runtimeLauncherSource.IndexOf('$environmentRestoreResult = Restore-ProcessEnvironmentSafely -Snapshot $oldEnvironment')
    $leaseCleanupIndex = $runtimeLauncherSource.IndexOf('if ($leaseOwned -and (Test-Path -LiteralPath $leasePath))', [Math]::Max(0, $environmentRestoreIndex))
    Assert-LauncherContract ($environmentRestoreIndex -ge 0 -and $leaseCleanupIndex -gt $environmentRestoreIndex) 'Environment restoration is not contained ahead of exact lease cleanup.'

    $malformedRejected = $false
    try { [void](Get-StrictNativeExitCode -RawValue $null) } catch { $malformedRejected = $true }
    Assert-LauncherContract $malformedRejected 'Strict native-exit validator accepted null.'
    $malformedRejected = $false
    try { [void](Get-StrictNativeExitCode -RawValue '0') } catch { $malformedRejected = $true }
    Assert-LauncherContract $malformedRejected 'Strict native-exit validator accepted a string exit.'

    $probeRoot = Join-Path $projectRoot ('.tmp\rw06_6\launcher-selftest-' + $PID)
    New-Item -ItemType Directory -Force -Path $probeRoot | Out-Null
    $powerShellExe = Join-Path $PSHOME 'powershell.exe'
    Assert-LauncherContract (Test-Path -LiteralPath $powerShellExe -PathType Leaf) 'Windows PowerShell 5.1 process probe executable is unavailable.'
    $godotBeforeKeys = @(Get-LiveGodotIdentityRecords | ForEach-Object { [string]$_.key })
    $quoteEcho = 'space "quoted" value'
    $quoteTrailing = 'C:\path with space\'
    $zeroStdout = Join-Path $probeRoot 'zero.stdout.log'
    $zeroStderr = Join-Path $probeRoot 'zero.stderr.log'
    $zeroStarted = Start-RedirectedProcess -FilePath $powerShellExe -Arguments @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath, '-ProcessProbeChild', '-ProbeExitCode', '0', '-ProbeEcho', $quoteEcho, '-ProbeTrailing', $quoteTrailing, '-ProbeEmpty', '') -StdoutPath $zeroStdout -StderrPath $zeroStderr -ProcessKind Exact -TimeoutSec 10
    $zeroResult = Complete-RedirectedProcess -Started $zeroStarted -TimeoutSec 10 -ProcessKind Exact
    $zeroOut = [System.IO.File]::ReadAllText($zeroStdout)
    $zeroErr = [System.IO.File]::ReadAllText($zeroStderr)
    Assert-LauncherContract (-not $zeroResult.timed_out -and $zeroResult.native_exit_observed -and $zeroResult.native_exit_code -eq 0 -and $zeroResult.native_exit_type -eq 'System.Int32' -and $zeroResult.effective_exit_code -eq 0 -and [string]::IsNullOrWhiteSpace($zeroResult.error)) 'Direct-process zero probe did not return a clean integer zero.'
    Assert-LauncherContract ($zeroOut.Contains('RW06_6_PROCESS_PROBE_STDOUT') -and $zeroErr.Contains('RW06_6_PROCESS_PROBE_STDERR')) 'Direct-process zero probe did not drain both streams.'
    Assert-LauncherContract ($zeroOut.Contains('"echo":"space \"quoted\" value"') -and $zeroOut.Contains('"trailing":"C:\\path with space\\"') -and $zeroOut.Contains('"empty":""')) 'PS5.1 fallback quoting changed spaces, an embedded quote, trailing slash, or empty argument.'

    $retainedStdout = Join-Path $probeRoot 'retained-child.stdout.log'
    $retainedStderr = Join-Path $probeRoot 'retained-child.stderr.log'
    $retainedPidPath = Join-Path $probeRoot 'retained-child.pid'
    $lineageChildArguments = Join-ProcessArguments -Arguments @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath, '-ProcessProbeChild', '-ProbeSleepMsec', '10000')
    $lineageExeLiteral = $powerShellExe.Replace("'", "''")
    $lineageArgumentsLiteral = $lineageChildArguments.Replace("'", "''")
    $lineagePidPathLiteral = $retainedPidPath.Replace("'", "''")
    $lineageRootSource = @"
`$startInfo = [System.Diagnostics.ProcessStartInfo]::new()
`$startInfo.FileName = '$lineageExeLiteral'
`$startInfo.Arguments = '$lineageArgumentsLiteral'
`$startInfo.UseShellExecute = `$false
`$startInfo.CreateNoWindow = `$true
`$startInfo.RedirectStandardOutput = `$true
`$startInfo.RedirectStandardError = `$true
`$child = [System.Diagnostics.Process]::Start(`$startInfo)
[System.IO.File]::WriteAllText('$lineagePidPathLiteral', [string]`$child.Id)
exit 0
"@
    $lineageEncodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($lineageRootSource))
    $retainedStarted = Start-RedirectedProcess -FilePath $powerShellExe -Arguments @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', $lineageEncodedCommand) -StdoutPath $retainedStdout -StderrPath $retainedStderr -ProcessKind Exact -TimeoutSec 15
    $retainedCompleted = $false
    $lineageChildIdentity = $null
    try {
        if (-not $retainedStarted.process.WaitForExit(5000)) {
            throw 'Retained-lineage hostile probe root did not exit promptly.'
        }
        $retainedStarted.process.Refresh()
        $lineageRootExitUtc = $retainedStarted.process.ExitTime.ToUniversalTime()
        Assert-LauncherContract (Test-Path -LiteralPath $retainedPidPath -PathType Leaf) 'Retained-lineage hostile probe root did not record its child PID.'
        $lineageChildPid = 0
        Assert-LauncherContract ([int]::TryParse([System.IO.File]::ReadAllText($retainedPidPath).Trim(), [ref]$lineageChildPid) -and $lineageChildPid -gt 0) 'Retained-lineage hostile probe wrote a malformed child PID.'
        $lineageChildProcess = Get-Process -Id $lineageChildPid -ErrorAction SilentlyContinue
        Assert-LauncherContract ($null -ne $lineageChildProcess) 'Retained-lineage hostile probe child did not survive its root.'
        $lineageChildIdentity = Get-ProcessIdentityRecord -Process $lineageChildProcess
        Assert-LauncherContract ([long]$lineageChildIdentity.start_ticks -ge [long]$retainedStarted.process_identity.start_ticks -and [long]$lineageChildIdentity.start_ticks -le [long]$lineageRootExitUtc.Ticks) 'Retained-lineage hostile probe child was outside its exact root lifetime.'
        $invalidExitedRootLineageIdentity = [ordered]@{
            pid = [int]$retainedStarted.process_identity.pid
            name = [string]$retainedStarted.process_identity.name + '-confirmed-exited'
            start_utc = [string]$retainedStarted.process_identity.start_utc
            start_ticks = [long]$retainedStarted.process_identity.start_ticks
            key = [string]$retainedStarted.process_identity.key + '|confirmed-exited'
        }
        $invalidRootDescendants = [System.Collections.Generic.List[object]]::new()
        Add-RetainedDescendantProcessRecords -RootIdentity $invalidExitedRootLineageIdentity -BaselineIdentityKeys @() -RetainedRecords $invalidRootDescendants -RootExitTimeUtc $lineageRootExitUtc
        Assert-LauncherContract ($invalidRootDescendants.Count -eq 0) 'Exit-bounded lineage accepted a malformed root identity proof.'
        $exitedRootLineageIdentity = $retainedStarted.process_identity

        $capturedDescendants = [System.Collections.Generic.List[object]]::new()
        $captureDeadline = [DateTime]::UtcNow.AddSeconds(3)
        $capturedProbeRecord = $null
        do {
            Add-RetainedDescendantProcessRecords -RootIdentity $exitedRootLineageIdentity -BaselineIdentityKeys @() -RetainedRecords $capturedDescendants -RootExitTimeUtc $lineageRootExitUtc
            $capturedProbeRecord = @($capturedDescendants | Where-Object { [string]$_.key -ceq [string]$lineageChildIdentity.key } | Select-Object -First 1)
            if ($capturedProbeRecord.Count -eq 1) { break }
            Start-Sleep -Milliseconds 25
        } while ([DateTime]::UtcNow -lt $captureDeadline)
        Assert-LauncherContract ($capturedProbeRecord.Count -eq 1) 'Exit-bounded lineage probe did not capture the exact surviving child after its root exited.'
        $baselineRejectedDescendants = [System.Collections.Generic.List[object]]::new()
        Add-RetainedDescendantProcessRecords -RootIdentity $exitedRootLineageIdentity -BaselineIdentityKeys @([string]$lineageChildIdentity.key) -RetainedRecords $baselineRejectedDescendants -RootExitTimeUtc $lineageRootExitUtc
        Assert-LauncherContract (@($baselineRejectedDescendants | Where-Object { [string]$_.key -ceq [string]$lineageChildIdentity.key }).Count -eq 0) 'Exit-bounded lineage probe accepted a baseline-owned child.'
        $lateRejectedDescendants = [System.Collections.Generic.List[object]]::new()
        $beforeChildBoundUtc = [datetime]::new([long]$lineageChildIdentity.start_ticks - 1, [DateTimeKind]::Utc)
        Add-RetainedDescendantProcessRecords -RootIdentity $exitedRootLineageIdentity -BaselineIdentityKeys @() -RetainedRecords $lateRejectedDescendants -RootExitTimeUtc $beforeChildBoundUtc
        Assert-LauncherContract (@($lateRejectedDescendants | Where-Object { [string]$_.key -ceq [string]$lineageChildIdentity.key }).Count -eq 0) 'Exit-bounded lineage probe accepted a child starting after the supplied root-lifetime bound.'
        $retainedOwnedRecords = [System.Collections.Generic.List[object]]::new()
        [void]$retainedOwnedRecords.Add($capturedProbeRecord[0])
        Stop-ExactStartedProcessTree -ConsoleProcess $retainedStarted.process -ConsoleIdentity $retainedStarted.process_identity -BaselineIdentityKeys @() -RetainedDescendantRecords $retainedOwnedRecords -AllowedDescendantNames @([string]$lineageChildIdentity.name)
        [void](Complete-RedirectedProcess -Started $retainedStarted -TimeoutSec 15 -ProcessKind Exact)
        $retainedCompleted = $true
        Assert-LauncherContract (-not (Get-Process -Id ([int]$lineageChildIdentity.pid) -ErrorAction SilentlyContinue)) 'Exit-bounded lineage probe could not clean its exact retained child after root loss.'
    }
    finally {
        if (-not $retainedCompleted) {
            if ($null -ne $lineageChildIdentity) {
                $lineageChild = Get-Process -Id ([int]$lineageChildIdentity.pid) -ErrorAction SilentlyContinue
                if ($lineageChild) {
                    Stop-ExactStartedProcess -Process $lineageChild -ProcessIdentity $lineageChildIdentity
                }
            }
            Stop-ExactStartedProcess -Process $retainedStarted.process -ProcessIdentity $retainedStarted.process_identity
            [void](Complete-RedirectedProcess -Started $retainedStarted -TimeoutSec 15 -ProcessKind Exact)
        }
    }

    $pumpFailureStdout = Join-Path $probeRoot 'pump-failure.stdout.log'
    $pumpFailureStderr = Join-Path $probeRoot 'pump-failure.stderr.log'
    $pumpFailureObserved = $false
    $pumpFailurePid = 0
    $pumpFailureProof = [ordered]@{ started = $false; process_id = 0; process_identity = $null; provenance = 'none' }
    try {
        [void](Start-RedirectedProcess -FilePath $powerShellExe -Arguments @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath, '-ProcessProbeChild', '-ProbeSleepMsec', '10000') -StdoutPath $pumpFailureStdout -StderrPath $pumpFailureStderr -ProcessKind Exact -TimeoutSec 15 -ForceSecondPumpFailureForTest)
    }
    catch {
        $pumpFailureObserved = $true
        $pumpFailureProof = Get-OwnedProcessStartProofFromException -Exception $_.Exception
        $pumpFailurePid = [int]$pumpFailureProof.process_id
    }
    Assert-LauncherContract ($pumpFailureObserved -and [bool]$pumpFailureProof.started -and $pumpFailurePid -gt 0 -and (Test-ProcessIdentityProofShape -Identity $pumpFailureProof.process_identity) -and [string]$pumpFailureProof.provenance -ceq 'start_setup_exception') 'Redirect setup hostile probe did not preserve exact process-start identity proof.'
    Assert-LauncherContract (-not (Get-Process -Id $pumpFailurePid -ErrorAction SilentlyContinue)) 'Redirect setup hostile probe left its exact child alive.'

    $volumeBytes = 262144
    $exitStdout = Join-Path $probeRoot 'exit.stdout.log'
    $exitStderr = Join-Path $probeRoot 'exit.stderr.log'
    $probeStarted = Start-RedirectedProcess -FilePath $powerShellExe -Arguments @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath, '-ProcessProbeChild', '-ProbeExitCode', '37', '-ProbeVolumeBytes', "$volumeBytes") -StdoutPath $exitStdout -StderrPath $exitStderr -ProcessKind Exact -TimeoutSec 15
    $probeResult = Complete-RedirectedProcess -Started $probeStarted -TimeoutSec 15 -ProcessKind Exact
    Assert-LauncherContract (-not $probeResult.timed_out -and $probeResult.native_exit_observed -and $probeResult.native_exit_code -eq 37 -and $probeResult.native_exit_type -eq 'System.Int32' -and $probeResult.effective_exit_code -eq 37 -and [string]::IsNullOrWhiteSpace($probeResult.error)) 'Direct-process nonzero probe did not return integer 37.'
    Assert-LauncherContract ((Get-Item -LiteralPath $exitStdout).Length -ge $volumeBytes -and (Get-Item -LiteralPath $exitStderr).Length -ge $volumeBytes) 'High-volume dual-pipe probe did not capture at least 256 KiB on each stream.'
    Assert-LauncherContract ([System.IO.File]::ReadAllText($exitStdout).Contains('RW06_6_PROCESS_PROBE_STDOUT_END') -and [System.IO.File]::ReadAllText($exitStderr).Contains('RW06_6_PROCESS_PROBE_STDERR_END')) 'High-volume dual-pipe probe did not drain both streams to their end markers.'

    $timeoutStdout = Join-Path $probeRoot 'timeout.stdout.log'
    $timeoutStderr = Join-Path $probeRoot 'timeout.stderr.log'
    $timeoutStarted = Start-RedirectedProcess -FilePath $powerShellExe -Arguments @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath, '-ProcessProbeChild', '-ProbeSleepMsec', '10000', '-ProbeExitCode', '0') -StdoutPath $timeoutStdout -StderrPath $timeoutStderr -ProcessKind Exact -TimeoutSec 1
    $timeoutPid = $timeoutStarted.process_id
    $timeoutResult = Complete-RedirectedProcess -Started $timeoutStarted -TimeoutSec 1 -ProcessKind Exact
    Assert-LauncherContract ($timeoutResult.timed_out -and $timeoutResult.effective_exit_code -eq 124) 'Direct-process timeout probe did not fail with 124.'
    Assert-LauncherContract (-not (Get-Process -Id $timeoutPid -ErrorAction SilentlyContinue)) 'Direct-process timeout probe left its exact child alive.'
    Assert-LauncherContract (@(Get-NewUnownedGodotRecords -BaselineKeys $godotBeforeKeys).Count -eq 0) 'ValidateOnly observed a new unowned Godot process.'
    Write-Host 'rw06_6 Q-009/multiphase launcher static and hostile contracts passed.'
    exit 0
}


$stamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')
if ([string]::IsNullOrWhiteSpace($EvidenceRoot)) {
    $EvidenceRoot = Join-Path $projectRoot ".tmp\rw06_6\contract-$stamp-$PID"
}
$EvidenceRoot = [System.IO.Path]::GetFullPath($EvidenceRoot)
New-Item -ItemType Directory -Force -Path $EvidenceRoot | Out-Null
$summaryPath = Join-Path $EvidenceRoot 'summary.json'
$summaryShaPath = Join-Path $EvidenceRoot 'summary.sha256'
$phases = [System.Collections.Generic.List[object]]::new()
$skippedPhases = [System.Collections.Generic.List[object]]::new()
$overallExitCode = 1
$outcome = 'invalid'
$launcherError = ''
$candidateCommit = ''
$candidateTree = ''
$leasePath = Join-Path $leaseRoot ("rw06_6-pull-tab-glimmer-{0}.lease" -f $PID)
$leaseOwned = $false
$cacheAbsentInitially = $false
$cacheCleanupAuthorized = $false
$cacheCleanupSucceeded = $false
$environmentRestorationSucceeded = $false
$guardCacheAbsent = $false
$registrationPhaseStarted = $false
$registrationProcessIdentity = $null
$q016Snapshot = [ordered]@{
    answered_a = $false
    section_sha256 = ''
    file_sha256 = ''
    origin_main_commit = ''
    origin_main_blob = ''
    on_origin_main = $false
}
$harnessFiles = [ordered]@{}
$baselineGodotRecords = @()
$baselineGodotKeys = @()
$cacheSummary = [ordered]@{
    preexisting = $false
    absent_before_guard = $false
    absent_after_guard = $false
    registration_allowed = $false
    registration_started = $false
    registration_process_identity = $null
    created = $false
    global_class_cache_sha256 = ''
    uid_cache_sha256 = ''
    imported_manifest = [ordered]@{ count = 0; path = ''; sha256 = '' }
    cleanup_authorized = $false
    removed_after_evidence = $false
}
$oldEnvironment = [ordered]@{
    APPDATA = [Environment]::GetEnvironmentVariable('APPDATA', 'Process')
    LOCALAPPDATA = [Environment]::GetEnvironmentVariable('LOCALAPPDATA', 'Process')
    XDG_DATA_HOME = [Environment]::GetEnvironmentVariable('XDG_DATA_HOME', 'Process')
    XDG_CACHE_HOME = [Environment]::GetEnvironmentVariable('XDG_CACHE_HOME', 'Process')
    XDG_CONFIG_HOME = [Environment]::GetEnvironmentVariable('XDG_CONFIG_HOME', 'Process')
}
$startedUtc = [DateTime]::UtcNow
$postStatus = @('preflight-not-complete')
$postCommit = ''
$postTree = ''
$identityStable = $false
$newUnownedGodot = @()
$postGodotRecords = @()
$postLeases = @()

try {
    if ([string]::IsNullOrWhiteSpace($ExpectedOutcome)) { throw 'ExpectedOutcome Red or Green is required.' }
    if ($ExpectedOutcome -eq 'Green' -and -not $AuthorizeGreen) { throw 'ExpectedOutcome Green also requires -AuthorizeGreen.' }
    if ($ExpectedOutcome -eq 'Red' -and $AuthorizeGreen) { throw '-AuthorizeGreen is invalid for ExpectedOutcome Red.' }
    if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) { throw "Canonical Godot 4.6 console not found: $GodotPath" }
    if ($ProcessTimeoutSec -lt 1) { throw 'ProcessTimeoutSec must be positive.' }
    if ($LeaseWaitTimeoutSec -lt 1) { throw 'LeaseWaitTimeoutSec must be positive.' }
    Assert-LauncherContract ($leaseRoot -ceq $canonicalLeaseRoot) 'Q-009 launcher did not resolve the exact canonical lease root.'
    Assert-LauncherContract ($projectCacheRoot -eq [System.IO.Path]::GetFullPath((Join-Path $projectRoot '.godot'))) 'Dedicated cache root resolution failed.'

    # Q-016 is a pre-lease gate for every rw06_6 engine phase, including RED.
    $q016Snapshot = Get-Q016ApprovalSnapshot
    if (-not $q016Snapshot.answered_a) {
        throw 'Q-016 is not canonically ANSWERED A; no rw06_6 Godot phase is authorized.'
    }
    Assert-ProjectCacheAbsent -Context 'RW06_6 preflight'
    Assert-ProjectCacheIgnored
    $cacheAbsentInitially = $true
    $cacheSummary.absent_before_guard = $true

    $candidateIdentity = Assert-CleanExactCandidate $projectRoot $ExpectedCommit $ExpectedTree
    $candidateCommit = [string]$candidateIdentity.commit
    $candidateTree = [string]$candidateIdentity.tree
    $harnessFiles.launcher = Get-TrackedFileIdentity -Root $projectRoot -Commit $candidateCommit -RelativePath $launcherRelativePath
    $harnessFiles.guard = Get-TrackedFileIdentity -Root $projectRoot -Commit $candidateCommit -RelativePath $guardRelativePath
    $harnessFiles.full_contract = Get-TrackedFileIdentity -Root $projectRoot -Commit $candidateCommit -RelativePath $fullContractRelativePath
    $harnessFiles.product = Get-TrackedFileIdentity -Root $projectRoot -Commit $candidateCommit -RelativePath $productRelativePath

    $profileRoot = Join-Path $EvidenceRoot 'profile'
    $appData = Join-Path $profileRoot 'AppData\Roaming'
    $localAppData = Join-Path $profileRoot 'AppData\Local'
    $xdgData = Join-Path $profileRoot 'xdg\data'
    $xdgCache = Join-Path $profileRoot 'xdg\cache'
    $xdgConfig = Join-Path $profileRoot 'xdg\config'
    @($appData, $localAppData, $xdgData, $xdgCache, $xdgConfig) | ForEach-Object {
        New-Item -ItemType Directory -Force -Path $_ | Out-Null
    }

    New-Item -ItemType Directory -Force -Path $leaseRoot | Out-Null
    $baselineGodotRecords = @(Get-LiveGodotIdentityRecords)
    $baselineGodotKeys = @($baselineGodotRecords | ForEach-Object { [string]$_.key })
    $leaseDeadline = [DateTime]::UtcNow.AddSeconds($LeaseWaitTimeoutSec)
    while (-not $leaseOwned) {
        if ([DateTime]::UtcNow -ge $leaseDeadline) { throw 'Timed out waiting for a Q-009 focused Godot pair slot.' }
        $mutex = [System.Threading.Mutex]::new($false, $launchMutexName)
        $mutexOwned = $false
        try {
            $mutexOwned = $mutex.WaitOne(5000)
            if (-not $mutexOwned) { continue }
            [void](Assert-Q016ApprovalSnapshot -ExpectedSectionSha256 $q016Snapshot.section_sha256)
            [void](Assert-CleanExactCandidate $projectRoot $ExpectedCommit $ExpectedTree)
            Clear-StaleGodotLeases
            $exclusivePresent = Test-Path -LiteralPath $exclusiveLeasePath
            $focusedLeaseCount = @(Get-ChildItem -LiteralPath $leaseRoot -Filter '*.lease' -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'EXCLUSIVE.lease' }).Count
            $godotProcessCount = @(Get-LiveGodotProcesses).Count
            $unleasedGodotCount = @(Get-NewUnownedGodotRecords -BaselineKeys @()).Count
            if ($unleasedGodotCount -gt 0) {
                throw 'An unleased Godot process exists; refusing rw06_6 lease acquisition.'
            }
            if (Test-FocusedLaunchCapacity $exclusivePresent $focusedLeaseCount $godotProcessCount) {
                $leaseText = "pid=$PID`nworktree=$projectRoot`ncandidate_commit=$candidateCommit`ncandidate_tree=$candidateTree`nstarted_utc=$([DateTime]::UtcNow.ToString('o'))`n"
                New-OwnedLeaseFile -Path $leasePath -Text $leaseText
                $leaseOwned = $true
            }
        }
        finally {
            if ($mutexOwned) { $mutex.ReleaseMutex() }
            $mutex.Dispose()
        }
        if (-not $leaseOwned) { Start-Sleep -Seconds 2 }
    }

    [void](Assert-Q016ApprovalSnapshot -ExpectedSectionSha256 $q016Snapshot.section_sha256)
    [void](Assert-CleanExactCandidate $projectRoot $ExpectedCommit $ExpectedTree)
    Assert-OwnedLease -Path $leasePath -Root $projectRoot -Commit $candidateCommit -Tree $candidateTree
    $env:APPDATA = $appData
    $env:LOCALAPPDATA = $localAppData
    $env:XDG_DATA_HOME = $xdgData
    $env:XDG_CACHE_HOME = $xdgCache
    $env:XDG_CONFIG_HOME = $xdgConfig

    $guardArguments = @(
        '--headless', '--verbose', '--disable-crash-handler',
        '--audio-driver', 'Dummy', '--path', $projectRoot,
        '--script', $guardScriptPath
    )
    $guardPhase = Invoke-GodotPhase -Name 'source_guard' -Arguments $guardArguments -Root $projectRoot -RequiredCommit $ExpectedCommit -RequiredTree $ExpectedTree -OwnedLeasePath $leasePath -Q016SectionSha256 $q016Snapshot.section_sha256 -PhaseEvidenceRoot (Join-Path $EvidenceRoot '01-source-guard') -TimeoutSec $ProcessTimeoutSec
    [void]$phases.Add($guardPhase)
    $unexpectedRedDiagnostics = @(Get-UnexpectedRedDiagnostics -Diagnostics @($guardPhase.diagnostics))
    $disposition = Resolve-GuardDisposition -NativeExitCode ([int]$guardPhase.native_exit_code) -NativeExitObserved ([bool]$guardPhase.native_exit_observed) -EffectiveExitCode ([int]$guardPhase.effective_exit_code) -TimedOut ([bool]$guardPhase.timed_out) -RunnerError ([string]$guardPhase.launcher_error) -ProductRedMarkerSeen ([bool]$guardPhase.product_red_marker) -GuardPassMarkerSeen ([bool]$guardPhase.guard_pass_marker) -InfraFailureMarkerSeen ([bool]$guardPhase.infra_failure_marker) -FullPassMarkerSeen ([bool]$guardPhase.full_pass_marker) -UnexpectedDiagnosticCount $unexpectedRedDiagnostics.Count

    $guardCacheAbsent = -not (Test-Path -LiteralPath $projectCacheRoot)
    $cacheSummary.absent_after_guard = $guardCacheAbsent
    if (-not $guardCacheAbsent) {
        throw 'Zero-preload source guard created or borrowed .godot/global-class/UID/imported state; evidence is invalid.'
    }

    if ($ExpectedOutcome -eq 'Red' -and $disposition -eq 'valid_red') {
        $outcome = 'valid_red'
        $overallExitCode = 0
        [void]$skippedPhases.Add([ordered]@{ name = 'global_class_registration'; reason = 'ExpectedOutcome Red stops after exact guard native exit 10.' })
        [void]$skippedPhases.Add([ordered]@{ name = 'full_contract'; reason = 'ExpectedOutcome Red stops before registry/full contract.' })
    }
    elseif ($ExpectedOutcome -eq 'Green' -and $disposition -eq 'green_handoff') {
        [void](Assert-Q016ApprovalSnapshot -ExpectedSectionSha256 $q016Snapshot.section_sha256)
        $cacheSummary.registration_allowed = $true
        Assert-ProjectCacheAbsent -Context 'RW06_6 pre-import handoff'
        $importArguments = @(
            '--headless', '--verbose', '--disable-crash-handler',
            '--audio-driver', 'Dummy', '--path', $projectRoot, '--import'
        )
        $importEvidenceRoot = Join-Path $EvidenceRoot '02-global-class-registration'
        $importPhase = Invoke-GodotPhase -Name 'global_class_registration' -Arguments $importArguments -Root $projectRoot -RequiredCommit $ExpectedCommit -RequiredTree $ExpectedTree -OwnedLeasePath $leasePath -Q016SectionSha256 $q016Snapshot.section_sha256 -PhaseEvidenceRoot $importEvidenceRoot -TimeoutSec $ProcessTimeoutSec
        [void]$phases.Add($importPhase)
        $registrationPhaseStarted = (
            [bool]$importPhase.process_started `
            -and (Test-ProcessIdentityProofShape -Identity $importPhase.process_identity) `
            -and [int]$importPhase.process_id -eq [int]$importPhase.process_identity.pid
        )
        if ($registrationPhaseStarted) {
            $registrationProcessIdentity = $importPhase.process_identity
        }
        $cacheSummary.registration_started = $registrationPhaseStarted
        $cacheSummary.registration_process_identity = $registrationProcessIdentity
        $cacheCleanupAuthorized = $cacheAbsentInitially -and $registrationPhaseStarted
        $cacheSummary.cleanup_authorized = $cacheCleanupAuthorized
        if (
            -not $importPhase.native_exit_observed `
            -or $importPhase.native_exit_code -ne 0 `
            -or $importPhase.effective_exit_code -ne 0 `
            -or $importPhase.timed_out `
            -or -not [string]::IsNullOrWhiteSpace([string]$importPhase.launcher_error) `
            -or -not (Test-PhaseMarkerContract -Phase Registry -ProductRedMarkerSeen ([bool]$importPhase.product_red_marker) -GuardPassMarkerSeen ([bool]$importPhase.guard_pass_marker) -InfraFailureMarkerSeen ([bool]$importPhase.infra_failure_marker) -FullPassMarkerSeen ([bool]$importPhase.full_pass_marker)) `
            -or -not $importPhase.diagnostics_clean
        ) {
            throw 'Explicit Godot --import global-class registration failed closed.'
        }
        if (-not (Test-Path -LiteralPath $globalClassCachePath -PathType Leaf) -or (Get-Item -LiteralPath $globalClassCachePath).Length -le 0) {
            throw 'Explicit Godot --import did not produce a nonempty global script class cache.'
        }
        if (-not (Test-Path -LiteralPath $uidCachePath -PathType Leaf) -or (Get-Item -LiteralPath $uidCachePath).Length -le 0) {
            throw 'Explicit Godot --import did not produce a nonempty UID cache.'
        }
        $cacheItem = Get-Item -LiteralPath $projectCacheRoot -Force
        if (($cacheItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw 'Explicit Godot --import produced a reparse-point .godot cache.'
        }
        Assert-RequiredGlobalClassEntries -CachePath $globalClassCachePath
        $cacheSummary.created = $true
        $cacheSummary.global_class_cache_sha256 = (Get-FileHash -LiteralPath $globalClassCachePath -Algorithm SHA256).Hash
        $cacheSummary.uid_cache_sha256 = (Get-FileHash -LiteralPath $uidCachePath -Algorithm SHA256).Hash
        $cacheSummary.imported_manifest = Write-ImportedArtifactManifest -DestinationPath (Join-Path $importEvidenceRoot 'imported-artifacts.json')

        $fullArguments = @(
            '--headless', '--verbose', '--disable-crash-handler',
            '--audio-driver', 'Dummy', '--path', $projectRoot,
            '--script', $fullContractScriptPath
        )
        $fullPhase = Invoke-GodotPhase -Name 'full_contract' -Arguments $fullArguments -Root $projectRoot -RequiredCommit $ExpectedCommit -RequiredTree $ExpectedTree -OwnedLeasePath $leasePath -Q016SectionSha256 $q016Snapshot.section_sha256 -PhaseEvidenceRoot (Join-Path $EvidenceRoot '03-full-contract') -TimeoutSec $ProcessTimeoutSec
        [void]$phases.Add($fullPhase)
        if (
            -not $fullPhase.native_exit_observed `
            -or $fullPhase.native_exit_code -ne 0 `
            -or $fullPhase.effective_exit_code -ne 0 `
            -or $fullPhase.timed_out `
            -or -not [string]::IsNullOrWhiteSpace([string]$fullPhase.launcher_error) `
            -or -not (Test-PhaseMarkerContract -Phase Full -ProductRedMarkerSeen ([bool]$fullPhase.product_red_marker) -GuardPassMarkerSeen ([bool]$fullPhase.guard_pass_marker) -InfraFailureMarkerSeen ([bool]$fullPhase.infra_failure_marker) -FullPassMarkerSeen ([bool]$fullPhase.full_pass_marker)) `
            -or -not $fullPhase.diagnostics_clean
        ) {
            throw 'Full RW06_6 contract failed GREEN acceptance.'
        }
        $outcome = 'green_pass'
        $overallExitCode = 0
    }
    else {
        throw "Source guard disposition '$disposition' did not match ExpectedOutcome $ExpectedOutcome."
    }
}
catch {
    $launcherError = $_.Exception.Message
    $outcome = 'invalid'
    $overallExitCode = 1
}
finally {
    try {
        if (Test-Path -LiteralPath $projectCacheRoot) {
            $cacheSummary.created = $true
            if ([string]::IsNullOrWhiteSpace([string]$cacheSummary.global_class_cache_sha256) -and (Test-Path -LiteralPath $globalClassCachePath -PathType Leaf)) {
                $cacheSummary.global_class_cache_sha256 = (Get-FileHash -LiteralPath $globalClassCachePath -Algorithm SHA256).Hash
            }
            if ([string]::IsNullOrWhiteSpace([string]$cacheSummary.uid_cache_sha256) -and (Test-Path -LiteralPath $uidCachePath -PathType Leaf)) {
                $cacheSummary.uid_cache_sha256 = (Get-FileHash -LiteralPath $uidCachePath -Algorithm SHA256).Hash
            }
            # Only the registry phase is authorized to create this cache. A
            # merely absent preflight path is not proof that a later cache is
            # ours, so require an exact owned registry process to have started.
            if (
                $cacheAbsentInitially `
                -and $registrationPhaseStarted `
                -and (Test-ProcessIdentityProofShape -Identity $registrationProcessIdentity)
            ) {
                $cacheCleanupAuthorized = $true
                $cacheSummary.cleanup_authorized = $true
            }
            if (-not $cacheCleanupAuthorized) {
                throw 'A pre-existing or unowned .godot cache appeared; refusing destructive cleanup.'
            }
            Remove-DedicatedProjectCache -Root $projectRoot -CacheRoot $projectCacheRoot
        }
        $cacheCleanupSucceeded = -not (Test-Path -LiteralPath $projectCacheRoot)
        $cacheSummary.removed_after_evidence = $cacheCleanupSucceeded
    }
    catch {
        $cacheCleanupSucceeded = $false
        if ([string]::IsNullOrWhiteSpace($launcherError)) { $launcherError = $_.Exception.Message }
        else { $launcherError += ' | Cache cleanup: ' + $_.Exception.Message }
        $outcome = 'invalid'
        $overallExitCode = 1
    }
    try {
        $environmentRestoreResult = Restore-ProcessEnvironmentSafely -Snapshot $oldEnvironment
        $environmentRestorationSucceeded = [bool]$environmentRestoreResult.succeeded
        if (-not $environmentRestorationSucceeded) {
            throw [string]$environmentRestoreResult.error
        }
    }
    catch {
        $environmentRestorationSucceeded = $false
        $environmentRestoreError = $_.Exception.Message
        if ([string]::IsNullOrWhiteSpace($launcherError)) { $launcherError = $environmentRestoreError }
        else { $launcherError += ' | Environment restoration: ' + $environmentRestoreError }
        $outcome = 'invalid'
        $overallExitCode = 1
    }
    try {
        if ($leaseOwned -and (Test-Path -LiteralPath $leasePath)) {
            Assert-OwnedLease -Path $leasePath -Root $projectRoot -Commit $candidateCommit -Tree $candidateTree
            Remove-Item -LiteralPath $leasePath -Force
        }
    }
    catch {
        if ([string]::IsNullOrWhiteSpace($launcherError)) { $launcherError = $_.Exception.Message }
        else { $launcherError += ' | Lease cleanup: ' + $_.Exception.Message }
        $outcome = 'invalid'
        $overallExitCode = 1
    }
}

try {
    $postGodotRecords = @(Get-LiveGodotIdentityRecords)
    $newUnownedGodot = @(Get-NewUnownedGodotRecords -BaselineKeys $baselineGodotKeys)
    $postLeases = @(Get-ChildItem -LiteralPath $leaseRoot -Filter '*.lease' -File -ErrorAction SilentlyContinue)
    $postStatus = @(& git -C $projectRoot status --porcelain)
    $postCommit = (& git -C $projectRoot rev-parse HEAD).Trim()
    $postTree = (& git -C $projectRoot rev-parse 'HEAD^{tree}').Trim()
    $identityStable = ($postStatus.Count -eq 0 -and $postCommit -eq $ExpectedCommit.Trim() -and $postTree -eq $ExpectedTree.Trim())
}
catch {
    if ([string]::IsNullOrWhiteSpace($launcherError)) { $launcherError = $_.Exception.Message }
    else { $launcherError += ' | Final census: ' + $_.Exception.Message }
}
if (-not $identityStable -or $newUnownedGodot.Count -gt 0 -or (Test-Path -LiteralPath $leasePath) -or -not $cacheCleanupSucceeded) {
    $outcome = 'invalid'
    $overallExitCode = 1
}

if (-not ($phases | Where-Object { $_.name -eq 'global_class_registration' })) {
    if (-not ($skippedPhases | Where-Object { $_.name -eq 'global_class_registration' })) {
        [void]$skippedPhases.Add([ordered]@{ name = 'global_class_registration'; reason = 'Earlier preflight or source-guard failure.' })
    }
}
if (-not ($phases | Where-Object { $_.name -eq 'full_contract' })) {
    if (-not ($skippedPhases | Where-Object { $_.name -eq 'full_contract' })) {
        [void]$skippedPhases.Add([ordered]@{ name = 'full_contract'; reason = 'Earlier preflight, guard, or registry failure.' })
    }
}

$summary = [ordered]@{
    contract = 'rw06_6_pull_tab_glimmer'
    expected_outcome = $ExpectedOutcome
    candidate_commit = $candidateCommit
    candidate_tree = $candidateTree
    outcome = $outcome
    exit_code = [int]$overallExitCode
    launcher_error = $launcherError
    green_authorization_switch = [bool]$AuthorizeGreen
    q016 = $q016Snapshot
    started_utc = $startedUtc.ToString('o')
    completed_utc = [DateTime]::UtcNow.ToString('o')
    evidence_root = $EvidenceRoot
    phases = @($phases)
    skipped_phases = @($skippedPhases)
    files = $harnessFiles
    cache = $cacheSummary
    final = [ordered]@{
        clean_tree = ($postStatus.Count -eq 0)
        commit = $postCommit
        tree = $postTree
        identity_stable = $identityStable
        baseline_godot = @($baselineGodotRecords)
        live_godot = @($postGodotRecords)
        new_unowned_godot = @($newUnownedGodot)
        live_lease_count = $postLeases.Count
        owned_lease_removed = -not (Test-Path -LiteralPath $leasePath)
        environment_restored = $environmentRestorationSucceeded
        project_cache_absent = -not (Test-Path -LiteralPath $projectCacheRoot)
    }
}
[System.IO.File]::WriteAllText($summaryPath, (($summary | ConvertTo-Json -Depth 10) + "`n"))
$summarySha256 = (Get-FileHash -LiteralPath $summaryPath -Algorithm SHA256).Hash
[System.IO.File]::WriteAllText($summaryShaPath, ($summarySha256 + '  summary.json' + "`n"))
Write-Host ("RW06_6 outcome={0} exit={1} phases={2} evidence={3}" -f $outcome, $overallExitCode, $phases.Count, $EvidenceRoot)
if (-not [string]::IsNullOrWhiteSpace($launcherError)) {
    Write-Host ("RW06_6 launcher error: {0}" -f $launcherError)
}
exit $overallExitCode
