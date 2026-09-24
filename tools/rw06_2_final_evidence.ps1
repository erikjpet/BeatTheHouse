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
$ReplayTool = Join-Path $PSScriptRoot 'rw06_2_ending_replay.ps1'
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
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
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
            $record = Get-Content -Raw -LiteralPath $Lease.FullName -Encoding utf8 | ConvertFrom-Json
            $ownerPid = [int](Get-ExactValue $record @('pid') 0)
            $guardPids = @(Get-ExactValue $record @('guard_pids') @() | ForEach-Object { [int]$_ })
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
                } | ConvertTo-Json -Compress))
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
        $record = Get-Content -Raw -LiteralPath $LeasePath -Encoding utf8 | ConvertFrom-Json
        return [int](Get-ExactValue $record @('pid') 0) -eq $PID -and
            [string](Get-ExactValue $record @('kind') '') -ceq 'exclusive-real-input-fixed-repeat-final-evidence'
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
        } | ConvertTo-Json
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
        $candidatePid = [int](Get-ExactValue $survivor @('pid') 0)
        if ($candidatePid -le 0) { $candidatePid = [int](Get-ExactValue $survivor @('ProcessId') 0) }
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
        $record = Get-Content -Raw -LiteralPath $LeasePath -Encoding utf8 | ConvertFrom-Json
        $kind = [string](Get-ExactValue $record @('kind') '')
        return ($kind -ceq 'exclusive-real-input-fixed-repeat-final-evidence' -and
                [int](Get-ExactValue $record @('pid') 0) -eq $PID) -or
            ($kind -ceq 'exclusive-survivor-custody' -and
                [int](Get-ExactValue $record @('original_launcher_pid') 0) -eq $PID)
    }
    catch { return $false }
}


function Test-ExclusiveSurvivorCustody {
    param([Parameter(Mandatory = $true)][int[]]$ExpectedLivePids)
    if ($ExpectedLivePids.Count -eq 0 -or -not (Test-Path -LiteralPath $LeasePath -PathType Leaf)) { return $false }
    try {
        $record = Get-Content -Raw -LiteralPath $LeasePath -Encoding utf8 | ConvertFrom-Json
        $ownerPid = [int](Get-ExactValue $record @('pid') 0)
        $guardPids = @(Get-ExactValue $record @('guard_pids') @() | ForEach-Object { [int]$_ } | Sort-Object -Unique)
        $expected = @($ExpectedLivePids | Sort-Object -Unique)
        if ([string](Get-ExactValue $record @('kind') '') -cne 'exclusive-survivor-custody' -or
            [int](Get-ExactValue $record @('original_launcher_pid') 0) -ne $PID -or
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
        $recordBytes = [Text.Encoding]::UTF8.GetBytes(($record | ConvertTo-Json -Depth 8))
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
        [Parameter(Mandatory = $true)][string]$PublishedPath,
        [Parameter(Mandatory = $true)][string]$ExpectedPath,
        [Parameter(Mandatory = $true)][string]$Label
    )
    if ([string]::IsNullOrWhiteSpace($PublishedPath) -or -not [IO.Path]::IsPathRooted($PublishedPath)) {
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
        $issues = @(Get-Content -LiteralPath $path -Encoding utf8 | Where-Object {
            $_ -match 'SCRIPT ERROR|(^|\s)ERROR[: ]|(^|\s)WARNING[: ]'
        })
        if ($issues.Count -ne 0) {
            throw "Retained final session log contains failing diagnostics: $name`: $($issues -join ' | ')"
        }
        $hashes[$name] = Get-Sha256 -Path $path
    }
    return [pscustomobject]$hashes
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

    $invocations = @(Get-ChildItem -LiteralPath $ReplayEvidenceRoot -Directory -ErrorAction Stop)
    if ($invocations.Count -ne 1) {
        throw "Run $RunIndex produced $($invocations.Count) replay invocation directories instead of one."
    }
    $summaryPath = Join-Path $invocations[0].FullName 'summary.json'
    if (-not (Test-Path -LiteralPath $summaryPath -PathType Leaf)) {
        throw "Run $RunIndex did not write its invocation summary."
    }
    $summary = Get-Content -Raw -LiteralPath $summaryPath -Encoding utf8 | ConvertFrom-Json
    Assert-ExactPublishedPath `
        -PublishedPath ([string](Get-ExactValue $summary @('evidence_root') '')) `
        -ExpectedPath $invocations[0].FullName `
        -Label "Run $RunIndex invocation evidence root"
    if ([string](Get-ExactValue $summary @('check_id') '') -cne 'rw06_2_ending_replay' -or
        [string](Get-ExactValue $summary @('ending') '') -cne $Ending -or
        [string](Get-ExactValue $summary @('seed') '') -cne $Seed -or
        [int](Get-ExactValue $summary @('repeat') 0) -ne 1 -or
        (Get-ExactValue $summary @('deterministic') $null) -isnot [bool] -or [bool](Get-ExactValue $summary @('deterministic') $true) -or
        (Get-ExactValue $summary @('release_qualifying') $null) -isnot [bool] -or [bool](Get-ExactValue $summary @('release_qualifying') $true) -or
        [string](Get-ExactValue $summary @('qualification') '') -cne 'non_qualifying_development_run') {
        throw "Run $RunIndex invocation summary did not match the exact one-run child contract."
    }
    $terminalSeeds = @(Get-ExactValue $summary @('observed_terminal_seeds') @() | ForEach-Object { [string]$_ })
    if ($terminalSeeds.Count -ne 1 -or $terminalSeeds[0] -cne $Seed) {
        throw "Run $RunIndex did not report the exact fixed terminal seed."
    }
    $runs = @(Get-ExactValue $summary @('runs') @())
    if ($runs.Count -ne 1) {
        throw "Run $RunIndex invocation summary contained $($runs.Count) run records instead of one."
    }
    $run = $runs[0]
    $actionCount = [int](Get-ExactValue $run @('action_count') 0)
    $outcome = [string](Get-ExactValue $run @('outcome') '')
    if ([string](Get-ExactValue $run @('role') '') -cne 'child_development_iteration' -or
        [string](Get-ExactValue $run @('repeat_profile_scope') '') -cne 'shared_caller_appdata' -or
        [string](Get-ExactValue $run @('fixed_repeat_qualification_authority') '') -cne 'outer_independent_profile_aggregate_only' -or
        (Get-ExactValue $run @('release_qualifying') $null) -isnot [bool] -or [bool](Get-ExactValue $run @('release_qualifying') $true) -or
        [string](Get-ExactValue $run @('qualification') '') -cne 'non_qualifying_development_iteration' -or
        (Get-ExactValue $run @('passed') $null) -isnot [bool] -or -not [bool](Get-ExactValue $run @('passed') $false) -or
        [string](Get-ExactValue $run @('seed') '') -cne $Seed -or
        [string](Get-ExactValue $run @('observed_terminal_seed') '') -cne $Seed -or
        $outcome -cnotin $ExpectedOutcomes[$Ending] -or
        (Get-ExactValue $run @('midpoint_save_relaunch_continue') $null) -isnot [bool] -or -not [bool](Get-ExactValue $run @('midpoint_save_relaunch_continue') $false) -or
        -not [string]::IsNullOrEmpty([string](Get-ExactValue $run @('failure') '')) -or
        $actionCount -le 0 -or $actionCount -gt 350) {
        throw "Run $RunIndex did not prove its terminal win, midpoint persistence, exact seed, and 1..350 action bound."
    }

    if ($Ending -ceq 'heist') {
        $preflight = Get-ExactValue $summary @('heist_seed_preflight') $null
        if ((Get-ExactValue $preflight @('passed') $null) -isnot [bool] -or -not [bool](Get-ExactValue $preflight @('passed') $false) -or
            [string](Get-ExactValue $preflight @('selection', 'seed_text') '') -cne 'RW06-HEIST-AUDIT-0002' -or
            [string](Get-ExactValue $preflight @('selection', 'selected_scenario') '') -cne 'grand_casino_audit_night') {
            throw "Run $RunIndex did not retain the exact Q-013 seed/Audit preflight."
        }
        $launchSetup = Get-ExactValue $run @('heist_launch_setup') $null
        $contentGroups = @(Get-ExactValue $launchSetup @('selected_content_groups') @())
        if ([string](Get-ExactValue $launchSetup @('selected_challenge_id') '<missing>') -cne '' -or
            [string](Get-ExactValue $launchSetup @('selected_home_type_id') '') -cne 'random' -or
            $contentGroups.Count -ne 14) {
            throw "Run $RunIndex did not retain the visible fresh Standard/Random/default-content Heist setup."
        }
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
    $retainedRunSummary = Get-Content -Raw -LiteralPath (Join-Path $runRoot 'summary.json') -Encoding utf8 | ConvertFrom-Json
    if (($retainedRunSummary | ConvertTo-Json -Depth 30 -Compress) -cne ($run | ConvertTo-Json -Depth 30 -Compress)) {
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
    Assert-ExactPublishedPath `
        -PublishedPath ([string](Get-ExactValue $run @('transcript') '')) `
        -ExpectedPath $transcriptPath `
        -Label "Run $RunIndex transcript"
    Assert-ExactPublishedPath `
        -PublishedPath ([string](Get-ExactValue $run @('money_curve') '')) `
        -ExpectedPath $moneyPath `
        -Label "Run $RunIndex money curve"
    Assert-ExactPublishedPath `
        -PublishedPath ([string](Get-ExactValue $run @('persistence_checkpoint_before') '')) `
        -ExpectedPath $checkpointBeforePath `
        -Label "Run $RunIndex checkpoint before"
    Assert-ExactPublishedPath `
        -PublishedPath ([string](Get-ExactValue $run @('persistence_checkpoint_after') '')) `
        -ExpectedPath $checkpointAfterPath `
        -Label "Run $RunIndex checkpoint after"
    if ($transcriptHash -cne [string](Get-ExactValue $run @('transcript_sha256') '') -or
        $moneyHash -cne [string](Get-ExactValue $run @('money_curve_sha256') '') -or
        $checkpointBeforeHash -cne [string](Get-ExactValue $run @('persistence_checkpoint_before_sha256') '') -or
        $checkpointAfterHash -cne [string](Get-ExactValue $run @('persistence_checkpoint_after_sha256') '') -or
        (Get-ExactValue $run @('persistence_checkpoint_equal') $null) -isnot [bool] -or
        -not [bool](Get-ExactValue $run @('persistence_checkpoint_equal') $false) -or
        (Get-ExactValue $run @('persistence_checkpoint_complete') $null) -isnot [bool] -or
        -not [bool](Get-ExactValue $run @('persistence_checkpoint_complete') $false)) {
        throw "Run $RunIndex retained evidence hashes do not match its run summary."
    }
    if ($checkpointBeforeHash -cne $checkpointAfterHash) {
        throw "Run $RunIndex persistence checkpoint hashes differ across Save/relaunch/Continue."
    }
    $checkpointBefore = Get-Content -Raw -LiteralPath $checkpointBeforePath -Encoding utf8 | ConvertFrom-Json
    $checkpointAfter = Get-Content -Raw -LiteralPath $checkpointAfterPath -Encoding utf8 | ConvertFrom-Json
    if (($checkpointBefore | ConvertTo-Json -Depth 30 -Compress) -cne ($checkpointAfter | ConvertTo-Json -Depth 30 -Compress)) {
        throw "Run $RunIndex persistence checkpoint JSON differs across Save/relaunch/Continue."
    }

    $finalCheckpoint = Get-Content -Raw -LiteralPath $finalCheckpointPath -Encoding utf8 | ConvertFrom-Json
    $publishedFinalCheckpoint = Get-ExactValue $run @('final_public_checkpoint') $null
    if (($finalCheckpoint | ConvertTo-Json -Depth 30 -Compress) -cne ($publishedFinalCheckpoint | ConvertTo-Json -Depth 30 -Compress)) {
        throw "Run $RunIndex final public checkpoint file differs from its published run summary object."
    }
    if ([string](Get-ExactValue $finalCheckpoint @('record_kind') '') -cne 'final_public_checkpoint' -or
        [string](Get-ExactValue $finalCheckpoint @('observed_seed') '') -cne $Seed -or
        [string](Get-ExactValue $finalCheckpoint @('outcome_key') '') -cne $outcome -or
        (Get-ExactValue $finalCheckpoint @('won') $null) -isnot [bool] -or -not [bool](Get-ExactValue $finalCheckpoint @('won') $false) -or
        [string](Get-ExactValue $finalCheckpoint @('public_fingerprint') '') -notmatch '^[a-f0-9]{64}$' -or
        [string](Get-ExactValue $finalCheckpoint @('checkpoint_fingerprint') '') -notmatch '^[a-f0-9]{64}$') {
        throw "Run $RunIndex final public checkpoint is incomplete or does not prove the requested win."
    }
    foreach ($name in @('bankroll', 'chips', 'heat')) {
        $value = Get-ExactValue $finalCheckpoint @($name) $null
        if (($value -isnot [int32] -and $value -isnot [int64]) -or [long]$value -lt 0) {
            throw "Run $RunIndex final public checkpoint has an invalid $name value."
        }
    }

    $session = [string](Get-ExactValue $run @('session') '')
    $expectedSessionPrefix = "rw062-$Ending-$([int]$Identity.pid)-1-"
    $expectedSessionPattern = '^' + [regex]::Escape($expectedSessionPrefix) + '[0-9a-f]{10}$'
    if ($session -cnotmatch $expectedSessionPattern) {
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
            $profilePayload = Get-Content -Raw -LiteralPath $profileArtifact -Encoding utf8 | ConvertFrom-Json
            if ($null -eq $profilePayload -or $profilePayload -isnot [pscustomobject]) {
                throw 'Expected a non-null JSON object.'
            }
        }
        catch {
            throw "Run $RunIndex isolated profile artifact is not valid JSON: $profileArtifact. $($_.Exception.Message)"
        }
    }
    $profileInventoryHash = Get-Sha256 -Path $profileInventoryPath
    $autosaveHash = Get-Sha256 -Path $autosavePath

    return [pscustomobject][ordered]@{
        run_index = $RunIndex
        role = 'fixed_route_repeat'
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
        replay_summary_sha256 = Get-Sha256 -Path $summaryPath
        run_root = $runRoot
        session = $session
        session_root = $sessionRoot
        outcome = $outcome
        action_count = $actionCount
        transcript_sha256 = $transcriptHash
        money_curve_sha256 = $moneyHash
        persistence_checkpoint_before_sha256 = $checkpointBeforeHash
        persistence_checkpoint_after_sha256 = $checkpointAfterHash
        final_public_checkpoint_sha256 = $finalCheckpointHash
        godot_stdout_sha256 = [string]$logHashes.'godot.stdout.log'
        godot_stderr_sha256 = [string]$logHashes.'godot.stderr.log'
        godot_engine_sha256 = [string]$logHashes.'godot.engine.log'
    }
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
        $arguments = @(
            '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', $ReplayTool,
            '-Ending', $Ending, '-Seed', $Seed, '-Repeat', '1',
            '-TimeoutSeconds', [string]$CommandTimeoutSeconds, '-EvidenceRoot', $replayEvidenceRoot
        )
        $process = Start-Process -FilePath $powerShellExe -ArgumentList $arguments `
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


function Compare-FixedRunProofs {
    param([Parameter(Mandatory = $true)][object[]]$Proofs)
    if ($Proofs.Count -ne 2) {
        throw "Fixed-repeat qualification requires two run proofs; found $($Proofs.Count)."
    }
    $first = $Proofs[0]
    $second = $Proofs[1]
    foreach ($proof in $Proofs) {
        if ([string]$proof.role -cne 'fixed_route_repeat' -or
            [string]$proof.ending -cne $Ending -or [string]$proof.seed -cne $Seed -or
            [string]$proof.persistence_checkpoint_before_sha256 -cne [string]$proof.persistence_checkpoint_after_sha256 -or
            [string]$proof.profile_inventory_sha256 -notmatch '^[a-f0-9]{64}$' -or
            [string]$proof.autosave_sha256 -notmatch '^[a-f0-9]{64}$') {
            throw "Run $($proof.run_index) is not an exact successful fixed-route persistence proof."
        }
    }
    foreach ($property in @(
        'transcript_sha256', 'money_curve_sha256', 'final_public_checkpoint_sha256',
        'persistence_checkpoint_before_sha256', 'persistence_checkpoint_after_sha256'
    )) {
        if ([string]$first.$property -notmatch '^[a-f0-9]{64}$' -or [string]$first.$property -cne [string]$second.$property) {
            throw "Independent fixed-route profiles differ at canonical evidence field '$property'."
        }
    }
    if ([string]$first.profile_roaming -ceq [string]$second.profile_roaming -or
        [string]$first.profile_local -ceq [string]$second.profile_local -or
        [string]$first.session -ceq [string]$second.session -or
        [string]$first.session_root -ceq [string]$second.session_root -or
        [string]$first.replay_invocation_root -ceq [string]$second.replay_invocation_root -or
        [string]$first.run_root -ceq [string]$second.run_root -or
        [string]$first.profile_session_root -ceq [string]$second.profile_session_root -or
        [string]$first.profile_inventory -ceq [string]$second.profile_inventory -or
        [string]$first.autosave -ceq [string]$second.autosave -or
        [int]$first.replay_pid -eq [int]$second.replay_pid) {
        throw 'Fixed-repeat runs did not use two distinct profiles, sessions, roots, and replay processes.'
    }
    return [pscustomobject][ordered]@{
        deterministic = $true
        isolated_profiles = $true
        transcript_sha256 = [string]$first.transcript_sha256
        money_curve_sha256 = [string]$first.money_curve_sha256
        persistence_checkpoint_sha256 = [string]$first.persistence_checkpoint_before_sha256
        final_public_checkpoint_sha256 = [string]$first.final_public_checkpoint_sha256
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
    return @($paths | Sort-Object -Unique)
}


if ($Ending -ceq 'heist' -and $Seed -cne 'RW06-HEIST-AUDIT-0002') {
    throw 'Q-013 fixed-repeat evidence requires exact Heist seed RW06-HEIST-AUDIT-0002.'
}
if (-not (Test-Path -LiteralPath $ReplayTool -PathType Leaf)) {
    throw "Replay tool is missing: $ReplayTool"
}
if (-not (Test-Path -LiteralPath $GodotBin -PathType Leaf)) {
    throw "Pinned Godot console is missing: $GodotBin"
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

    foreach ($runIndex in 1..2) {
        $betweenLock = $null
        try {
            $betweenLock = Enter-LaunchLock
            Assert-RepositoryIdentity
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
                Add-TerminalFailure -Failure "Replay/Godot processes survived teardown; exclusive_survivor_custody_transferred=$custodyTransferred`: $($survivorCustody | ConvertTo-Json -Compress)"
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

$fixedRepeatQualifying = $null -eq $script:TerminalError -and
    $script:Outcome -ceq 'green' -and
    $script:RunProofs.Count -eq 2 -and
    $null -ne $script:CanonicalProof -and
    -not $script:LeaseOwned -and
    $script:FinalProcessCensus.Count -eq 0 -and
    $script:FinalHead -ceq $ExpectedHead.ToLowerInvariant() -and
    $script:FinalTree -ceq $ExpectedTree.ToLowerInvariant()
if (-not $fixedRepeatQualifying -and $null -eq $script:TerminalError) {
    Add-TerminalFailure -Failure 'Fixed-repeat evidence did not satisfy every aggregate qualification condition.'
}

$aggregateSummary = [ordered]@{
    schema_version = 1
    check_id = 'rw06_2_final_evidence'
    role = 'fixed_route_repeat'
    ending = $Ending
    seed = $Seed
    repeat = 2
    outcome = $script:Outcome
    error = Get-FailureMessage -Failure $script:TerminalError
    expected_head = $ExpectedHead.ToLowerInvariant()
    expected_tree = $ExpectedTree.ToLowerInvariant()
    observed_head = $script:FinalHead
    observed_tree = $script:FinalTree
    independent_profiles = if ($null -ne $script:CanonicalProof) { [bool]$script:CanonicalProof.isolated_profiles } else { $false }
    fresh_interactive_authorized = $false
    q017_status = if ($Ending -ceq 'heist') { 'OPEN_NOT_IN_SCOPE' } else { 'NOT_APPLICABLE' }
    deterministic = if ($null -ne $script:CanonicalProof) { [bool]$script:CanonicalProof.deterministic } else { $false }
    fixed_repeat_qualifying = [bool]$fixedRepeatQualifying
    canonical_proof = $script:CanonicalProof
    runs = @($script:RunProofs)
    evidence_root = $EvidenceRoot
}
$aggregateSummary | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $AggregateSummaryPath -Encoding utf8

$metadata = [ordered]@{
    lane = 'rw06_2p'
    kind = 'exclusive-real-input-fixed-repeat-final-evidence'
    ending = $Ending
    seed = $Seed
    role = 'fixed_route_repeat'
    outcome = $script:Outcome
    error = Get-FailureMessage -Failure $script:TerminalError
    expected_head = $ExpectedHead.ToLowerInvariant()
    expected_tree = $ExpectedTree.ToLowerInvariant()
    observed_head = $script:FinalHead
    observed_tree = $script:FinalTree
    launcher_snapshot = $LauncherSnapshotPath
    launcher_initial_sha256 = $script:LauncherInitialSha256
    launcher_current_sha256 = $script:LauncherCurrentSha256
    initial_process_census = $script:InitialProcessCensus
    final_process_census = $script:FinalProcessCensus
    owned_processes_remaining = @(Get-OwnedSurvivors)
    lease_path = $LeasePath
    lease_removed = -not (Test-Path -LiteralPath $LeasePath)
    fixed_repeat_qualifying = [bool]$fixedRepeatQualifying
    started = $StartedAt.ToString('o')
    completed = [DateTimeOffset]::Now.ToString('o')
}
$metadata | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $MetadataPath -Encoding utf8

$artifactRows = @(Get-ManifestArtifactPaths | ForEach-Object {
    [ordered]@{ path = $_; sha256 = Get-Sha256 -Path $_ }
})
$launcherSnapshotRows = @($artifactRows | Where-Object {
    ([IO.Path]::GetFullPath([string]$_.path)).Equals([IO.Path]::GetFullPath($LauncherSnapshotPath), [StringComparison]::OrdinalIgnoreCase)
})
if ($launcherSnapshotRows.Count -ne 1 -or
    [string]$launcherSnapshotRows[0].sha256 -cne $script:LauncherInitialSha256) {
    throw 'Aggregate manifest did not bind the exact immutable launcher snapshot hash.'
}
$manifestPathKeys = @($artifactRows | ForEach-Object { [IO.Path]::GetFullPath([string]$_.path).ToLowerInvariant() })
$requiredManifestArtifacts = [Collections.Generic.List[string]]::new()
foreach ($requiredArtifact in @($LauncherSnapshotPath, $AggregateSummaryPath, $MetadataPath)) {
    $requiredManifestArtifacts.Add([IO.Path]::GetFullPath($requiredArtifact))
}
foreach ($proof in @($script:RunProofs)) {
    foreach ($requiredArtifact in @(
        [string]$proof.replay_summary,
        (Join-Path ([string]$proof.run_root) 'summary.json'),
        (Join-Path ([string]$proof.run_root) 'public_trace.ndjson'),
        (Join-Path ([string]$proof.run_root) 'money_curve.ndjson'),
        (Join-Path ([string]$proof.run_root) 'checkpoint_before.json'),
        (Join-Path ([string]$proof.run_root) 'checkpoint_after.json'),
        (Join-Path ([string]$proof.run_root) 'final_public_checkpoint.json'),
        [string]$proof.profile_inventory,
        [string]$proof.autosave,
        (Join-Path ([string]$proof.session_root) 'godot.stdout.log'),
        (Join-Path ([string]$proof.session_root) 'godot.stderr.log'),
        (Join-Path ([string]$proof.session_root) 'godot.engine.log')
    )) {
        $requiredManifestArtifacts.Add([IO.Path]::GetFullPath($requiredArtifact))
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
    ending = $Ending
    seed = $Seed
    fixed_repeat_qualifying = [bool]$fixedRepeatQualifying
    evidence_root = $EvidenceRoot
    artifact_count = $artifactRows.Count
    artifacts = $artifactRows
}
$manifest | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $ManifestPath -Encoding utf8
foreach ($artifact in $artifactRows) {
    if ((Get-Sha256 -Path ([string]$artifact.path)) -cne [string]$artifact.sha256) {
        throw "Evidence artifact changed during manifest finalization: $([string]$artifact.path)"
    }
}

$result = [ordered]@{
    evidence_root = $EvidenceRoot
    outcome = $script:Outcome
    fixed_repeat_qualifying = [bool]$fixedRepeatQualifying
    head = $script:FinalHead
    tree = $script:FinalTree
    aggregate_summary_sha256 = Get-Sha256 -Path $AggregateSummaryPath
    metadata_sha256 = Get-Sha256 -Path $MetadataPath
    manifest_sha256 = Get-Sha256 -Path $ManifestPath
}
$result | ConvertTo-Json -Depth 8
if ($null -ne $script:TerminalError) { throw $script:TerminalError }
