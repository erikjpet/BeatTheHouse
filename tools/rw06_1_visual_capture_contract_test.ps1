param(
    [string]$GodotPath = 'D:\Projects\Beat-The-House\.tools\godot-4.6-stable\Godot_v4.6-stable_win64_console.exe',
    [string]$StaticReportPath = '.tmp\rw06_1\static\slot_report.json',
    [string]$ExpectedCommit = '',
    [string]$ExpectedTree = '',
    [string]$ExpectedLauncherSha256 = '',
    [string]$ExpectedCaptureScriptSha256 = '',
    [string]$ExpectedStaticReportSha256 = '',
    [string]$ExpectedGodotSha256 = '',
    [string]$ExpectedGodotGuiSha256 = '',
    [string]$PythonPath = 'C:\Users\theep\AppData\Local\Programs\Python\Python310\python.exe',
    [string]$ExpectedPythonSha256 = '3093FCF263029CA1D799FEA250A4E032D2C930A516F1513EECA688B343C836B3',
    [string]$EvidenceRoot = '',
    [int]$LeaseWaitTimeoutSec = 900,
    [int]$ProcessTimeoutSec = 900,
    [switch]$AuthorizeCapture,
    [switch]$ValidateOnly,
    [switch]$ValidateOnlyWorker,
    [ValidateSet('all', 'identity', 'png', 'q008', 'all18', 'artifacts', 'source')][string]$ValidateOnlyStopAfter = 'all',
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
    if ($ProbeSleepMsec -gt 0) { Start-Sleep -Milliseconds $ProbeSleepMsec }
    $probePayload = [ordered]@{
        echo = $ProbeEcho
        trailing = $ProbeTrailing
        empty = $ProbeEmpty
    } | ConvertTo-Json -Compress
    [Console]::Out.WriteLine('RW06_1_VISUAL_PROCESS_PROBE_STDOUT ' + $probePayload)
    [Console]::Error.WriteLine('RW06_1_VISUAL_PROCESS_PROBE_STDERR ' + $probePayload)
    if ($ProbeVolumeBytes -gt 0) {
        [Console]::Out.Write(('O' * $ProbeVolumeBytes))
        [Console]::Error.Write(('E' * $ProbeVolumeBytes))
        [Console]::Out.WriteLine('RW06_1_VISUAL_PROCESS_PROBE_STDOUT_END')
        [Console]::Error.WriteLine('RW06_1_VISUAL_PROCESS_PROBE_STDERR_END')
    }
    exit $ProbeExitCode
}

$projectRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$canonicalGodotPath = 'D:\Projects\Beat-The-House\.tools\godot-4.6-stable\Godot_v4.6-stable_win64_console.exe'
$canonicalGodotGuiPath = 'D:\Projects\Beat-The-House\.tools\godot-4.6-stable\Godot_v4.6-stable_win64.exe'
$canonicalPythonPath = 'C:\Users\theep\AppData\Local\Programs\Python\Python310\python.exe'
$canonicalPythonSha256 = '3093FCF263029CA1D799FEA250A4E032D2C930A516F1513EECA688B343C836B3'
$canonicalLeaseRoot = 'D:\Projects\Beat-The-House-worktrees\.godot_leases'
$leaseRoot = [System.IO.Path]::GetFullPath($canonicalLeaseRoot)
$exclusiveLeasePath = Join-Path $leaseRoot 'EXCLUSIVE.lease'
$launchMutexName = 'Global\BeatTheHouse-Q009-GodotLaunch'
$launcherRelativePath = 'tools/rw06_1_visual_capture_contract_test.ps1'
$captureRelativePath = 'tools/environment_layout_screenshots.gd'
$captureScriptPath = 'res://tools/environment_layout_screenshots.gd'
$sourceContractRelativePath = 'tools/rw06_1_visual_capture_source_contract.py'
$staticCheckerRelativePath = 'tools/environment_fixed_slot_static_check.py'
$archetypesRelativePath = 'data/environments/archetypes.json'
$projectSettingsRelativePath = 'project.godot'
$projectCacheRoot = [System.IO.Path]::GetFullPath((Join-Path $projectRoot '.godot'))
$primaryOwnerReviewPath = 'D:\Projects\Beat-The-House\.tmp\owner_review\q008_rooms.png'
$nativeExitSentinel = [int]::MinValue
$shaPattern = '^[0-9A-Fa-f]{64}$'
$expectedQ008Rooms = @('bar', 'corner_store', 'grand_casino')
$expectedSourceWidth = 1280
$expectedSourceHeight = 720


function Assert-Contract {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}


function Normalize-FullPath {
    param([string]$Path)
    return [System.IO.Path]::GetFullPath($Path).TrimEnd([char[]]@([char]'\', [char]'/'))
}


function Assert-StrictChildPath {
    param([string]$Path, [string]$RequiredParent)
    $parent = Normalize-FullPath $RequiredParent
    $target = Normalize-FullPath $Path
    $prefix = $parent + [IO.Path]::DirectorySeparatorChar
    if (-not $target.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Path is not an exact child of required parent ${parent}: $target"
    }
    return $target
}


function Assert-PathOutsideRoot {
    param([string]$Path, [string]$ExcludedRoot)
    $root = Normalize-FullPath $ExcludedRoot
    $target = Normalize-FullPath $Path
    $prefix = $root + [IO.Path]::DirectorySeparatorChar
    if ($target -ieq $root -or $target.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Path must remain outside excluded root ${root}: $target"
    }
    return $target
}


function Assert-DisjointRoots {
    param([string]$LeftRoot, [string]$RightRoot, [string]$Label)
    $left = Normalize-FullPath $LeftRoot
    $right = Normalize-FullPath $RightRoot
    $leftPrefix = $left + [IO.Path]::DirectorySeparatorChar
    $rightPrefix = $right + [IO.Path]::DirectorySeparatorChar
    if ($left -ieq $right -or $left.StartsWith($rightPrefix, [StringComparison]::OrdinalIgnoreCase) -or $right.StartsWith($leftPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "$Label roots must be disjoint (neither equal nor ancestor/descendant): left=$left right=$right"
    }
}


function Assert-NoReparseAncestors {
    param([string]$Path, [string]$RequiredRoot)
    $root = Normalize-FullPath $RequiredRoot
    $target = Normalize-FullPath $Path
    if ($target -ine $root) { [void](Assert-StrictChildPath $target $root) }
    $cursor = $target
    while ($true) {
        if (Test-Path -LiteralPath $cursor) {
            $item = Get-Item -LiteralPath $cursor -Force
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "Refusing path with reparse-point ancestor: $cursor"
            }
        }
        if ($cursor -ieq $root) { break }
        $parent = Split-Path -Parent $cursor
        if ([string]::IsNullOrWhiteSpace($parent) -or $parent -ieq $cursor) { throw "Could not walk path containment to required root: $target" }
        $cursor = Normalize-FullPath $parent
    }
    return $target
}


function Test-SamePath {
    param([string]$Left, [string]$Right)
    if ([string]::IsNullOrWhiteSpace($Left) -or [string]::IsNullOrWhiteSpace($Right)) { return $false }
    try {
        return (Normalize-FullPath $Left) -ieq (Normalize-FullPath $Right)
    }
    catch { return $false }
}


function Assert-ExpectedSha256 {
    param([string]$Label, [string]$Expected, [string]$Actual)
    if ($Expected -notmatch $shaPattern) { throw "$Label expected SHA-256 is missing or malformed." }
    if ($Actual -notmatch $shaPattern) { throw "$Label actual SHA-256 is missing or malformed." }
    if ($Expected -ine $Actual) { throw "$Label SHA-256 drift: expected $Expected, found $Actual." }
}


function Assert-ExecutedBinaryIdentity {
    param([string]$Label, [string]$ExpectedPath, [string]$ExpectedSha256, [object]$ProcessIdentity)
    if (-not [IO.Path]::IsPathRooted($ExpectedPath) -or -not (Test-Path -LiteralPath $ExpectedPath -PathType Leaf)) {
        throw "$Label expected executable path is missing, relative, or not a file: $ExpectedPath"
    }
    if (-not (Test-ProcessIdentityProofShape $ProcessIdentity)) { throw "$Label process identity proof is malformed." }
    if (-not (Test-SamePath $ExpectedPath ([string]$ProcessIdentity.path))) {
        throw "$Label executed a different binary: expected $ExpectedPath, found $([string]$ProcessIdentity.path)."
    }
    Assert-ExpectedSha256 "$Label expected executable" $ExpectedSha256 (Get-Sha256 $ExpectedPath)
    Assert-ExpectedSha256 "$Label executed executable" $ExpectedSha256 (Get-Sha256 ([string]$ProcessIdentity.path))
}


function Get-Sha256 {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Required file is missing: $Path" }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}


function Get-OptionalSha256 {
    param([AllowEmptyString()][string]$Path)
    try {
        if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) { return '' }
        return Get-Sha256 $Path
    }
    catch { return '' }
}


function Assert-ExactCandidateIdentity {
    param(
        [string]$RequiredCommit,
        [string]$RequiredTree,
        [string]$ActualCommit,
        [string]$ActualTree
    )
    if ($RequiredCommit -notmatch '^[0-9A-Fa-f]{40}$' -or $RequiredTree -notmatch '^[0-9A-Fa-f]{40}$') {
        throw 'ExpectedCommit and ExpectedTree must both be exact 40-character object IDs.'
    }
    if ($ActualCommit -ine $RequiredCommit) { throw "Candidate commit mismatch: expected $RequiredCommit, found $ActualCommit." }
    if ($ActualTree -ine $RequiredTree) { throw "Candidate tree mismatch: expected $RequiredTree, found $ActualTree." }
}


function Assert-CleanStatusEntries {
    param([object[]]$Entries)
    if (@($Entries).Count -ne 0) { throw 'Visual evidence requires a clean committed candidate worktree.' }
}


function Get-ExactCandidateIdentity {
    param([string]$Root, [string]$RequiredCommit, [string]$RequiredTree)
    $dirty = @(& git -C $Root status --porcelain --untracked-files=all)
    if ($LASTEXITCODE -ne 0) { throw 'Could not read candidate worktree status.' }
    Assert-CleanStatusEntries $dirty
    $actualCommit = (& git -C $Root rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'Could not resolve candidate HEAD.' }
    $actualTree = (& git -C $Root rev-parse 'HEAD^{tree}').Trim()
    if ($LASTEXITCODE -ne 0) { throw 'Could not resolve candidate tree.' }
    Assert-ExactCandidateIdentity $RequiredCommit $RequiredTree $actualCommit $actualTree
    $remoteRefs = @(& git -C $Root for-each-ref --contains=$actualCommit '--format=%(refname)' refs/remotes/origin)
    if ($LASTEXITCODE -ne 0 -or @($remoteRefs | Where-Object { $_ -like 'refs/remotes/origin/*' }).Count -eq 0) {
        throw "Candidate $actualCommit is not present on any origin remote-tracking ref."
    }
    return [ordered]@{ commit = $actualCommit; tree = $actualTree; remote_refs = @($remoteRefs) }
}


function Get-TrackedFileIdentity {
    param([string]$Root, [string]$Commit, [string]$RelativePath)
    $absolute = Join-Path $Root ($RelativePath.Replace('/', '\'))
    $blob = (& git -C $Root rev-parse ("{0}:{1}" -f $Commit, $RelativePath)).Trim()
    if ($LASTEXITCODE -ne 0 -or $blob -notmatch '^[0-9A-Fa-f]{40}$') {
        throw "Tracked file is absent from exact commit ${Commit}: $RelativePath"
    }
    & git -C $Root diff --quiet $Commit -- $RelativePath
    if ($LASTEXITCODE -ne 0) { throw "Tracked file differs from exact commit ${Commit}: $RelativePath" }
    return [ordered]@{
        relative_path = $RelativePath
        blob = $blob
        sha256 = Get-Sha256 $absolute
        length = [long](Get-Item -LiteralPath $absolute).Length
    }
}


function Get-ProcessExecutablePath {
    param([System.Diagnostics.Process]$Process)
    try {
        $value = [string]$Process.MainModule.FileName
        if (-not [string]::IsNullOrWhiteSpace($value)) { return Normalize-FullPath $value }
    }
    catch {}
    try {
        $cim = Get-CimInstance Win32_Process -Filter ("ProcessId={0}" -f $Process.Id) -ErrorAction Stop
        $value = [string]$cim.ExecutablePath
        if (-not [string]::IsNullOrWhiteSpace($value)) { return Normalize-FullPath $value }
    }
    catch {}
    return ''
}


function Get-ProcessIdentityRecord {
    param([System.Diagnostics.Process]$Process)
    $startUtc = $Process.StartTime.ToUniversalTime()
    $path = Get-ProcessExecutablePath $Process
    if ([string]::IsNullOrWhiteSpace($path)) { throw "Could not prove executable path for PID $($Process.Id)." }
    return [ordered]@{
        pid = [int]$Process.Id
        name = [string]$Process.ProcessName
        path = $path
        start_utc = $startUtc.ToString('o')
        start_ticks = [long]$startUtc.Ticks
        key = ('{0}|{1}|{2}|{3}' -f $Process.Id, $startUtc.Ticks, $Process.ProcessName, $path.ToLowerInvariant())
    }
}


function Test-ProcessIdentityProofShape {
    param([AllowNull()][object]$Identity)
    if ($null -eq $Identity) { return $false }
    try {
        $parsedStart = [datetime]::MinValue
        if (
            [int]$Identity.pid -le 0 `
            -or [long]$Identity.start_ticks -le 0 `
            -or [string]::IsNullOrWhiteSpace([string]$Identity.name) `
            -or [string]::IsNullOrWhiteSpace([string]$Identity.path) `
            -or [string]::IsNullOrWhiteSpace([string]$Identity.key) `
            -or -not [System.IO.Path]::IsPathRooted([string]$Identity.path) `
            -or -not [datetime]::TryParse([string]$Identity.start_utc, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::RoundtripKind, [ref]$parsedStart)
        ) { return $false }
        $expectedKey = ('{0}|{1}|{2}|{3}' -f [int]$Identity.pid, [long]$Identity.start_ticks, [string]$Identity.name, (Normalize-FullPath ([string]$Identity.path)).ToLowerInvariant())
        return [long]$parsedStart.ToUniversalTime().Ticks -eq [long]$Identity.start_ticks -and [string]$Identity.key -ceq $expectedKey
    }
    catch { return $false }
}


function Test-LiveProcessMatchesIdentity {
    param([object]$ExpectedIdentity)
    if (-not (Test-ProcessIdentityProofShape $ExpectedIdentity)) { return $false }
    $live = Get-Process -Id ([int]$ExpectedIdentity.pid) -ErrorAction SilentlyContinue
    if ($null -eq $live) { return $false }
    try {
        $actual = Get-ProcessIdentityRecord $live
        return [string]$actual.key -ceq [string]$ExpectedIdentity.key
    }
    catch { return $false }
}


function Get-StrictOptionalProcessById {
    param([int]$ProcessId)
    try { return [Diagnostics.Process]::GetProcessById($ProcessId) }
    catch [ArgumentException] { return $null }
    catch { throw "Authoritative process lookup failed for PID ${ProcessId}: $($_.Exception.Message)" }
}


function Get-StrictCensusIdentityRecord {
    param(
        [System.Diagnostics.Process]$Process,
        [object]$CimEntry,
        [scriptblock]$IdentityResolverForTest = $null
    )
    if ($null -ne $IdentityResolverForTest) {
        $injected = & $IdentityResolverForTest $Process $CimEntry
        if (-not (Test-ProcessIdentityProofShape $injected)) { throw "Injected authoritative identity resolver returned invalid proof for PID $($Process.Id)." }
        return $injected
    }
    if ($null -eq $CimEntry) { throw "Authoritative CIM identity entry is missing for present PID $($Process.Id)." }
    $cimPid = [int]$CimEntry.ProcessId
    if ($cimPid -ne [int]$Process.Id) { throw "Authoritative CIM/process PID mismatch: process=$($Process.Id) cim=$cimPid" }
    $startUtc = $Process.StartTime.ToUniversalTime()
    $creationUtc = ([datetime]$CimEntry.CreationDate).ToUniversalTime()
    if (-not (Test-CimCreationMatchesProcessStartTicks $creationUtc.Ticks $startUtc.Ticks)) { throw "Authoritative CIM/process start identity mismatch for PID $($Process.Id)." }
    $path = [string]$CimEntry.ExecutablePath
    if ([string]::IsNullOrWhiteSpace($path)) { throw "Authoritative CIM executable path is missing for present PID $($Process.Id)." }
    $path = Normalize-FullPath $path
    $name = [string]$Process.ProcessName
    if ([string]::IsNullOrWhiteSpace($name)) { throw "Authoritative process name is missing for present PID $($Process.Id)." }
    $identity = [ordered]@{
        pid = [int]$Process.Id
        name = $name
        path = $path
        start_utc = $startUtc.ToString('o')
        start_ticks = [long]$startUtc.Ticks
        key = ('{0}|{1}|{2}|{3}' -f $Process.Id, $startUtc.Ticks, $name, $path.ToLowerInvariant())
    }
    if (-not (Test-ProcessIdentityProofShape $identity)) { throw "Authoritative process identity proof is invalid for present PID $($Process.Id)." }
    return $identity
}


function Get-OwnedProcessStartProofFromException {
    param([System.Exception]$Exception)
    $missing = [ordered]@{ started = $false; process_id = 0; process_identity = $null; provenance = 'none' }
    if ($null -eq $Exception -or -not $Exception.Data.Contains('owned_process_id') -or -not $Exception.Data.Contains('owned_process_identity')) { return $missing }
    $identity = $Exception.Data['owned_process_identity']
    $rawPid = $Exception.Data['owned_process_id']
    if (-not ($rawPid -is [int]) -or -not (Test-ProcessIdentityProofShape $identity) -or [int]$rawPid -ne [int]$identity.pid) { return $missing }
    return [ordered]@{ started = $true; process_id = [int]$rawPid; process_identity = $identity; provenance = 'start_setup_exception' }
}


function Test-CimCreationMatchesProcessStartTicks {
    param([long]$CreationTicks, [long]$ProcessStartTicks)
    if ($CreationTicks -le 0 -or $ProcessStartTicks -le 0) { return $false }
    return $CreationTicks -eq ($ProcessStartTicks - ($ProcessStartTicks % 10))
}


function Resolve-VerifiedDescendantIdentityRecords {
    param(
        [object]$RootIdentity,
        [long]$OwnershipEndTicks,
        [string[]]$BaselineIdentityKeys,
        [object[]]$Candidates
    )
    if (-not (Test-ProcessIdentityProofShape $RootIdentity) -or $OwnershipEndTicks -lt [long]$RootIdentity.start_ticks) { return @() }
    $verified = @{}
    $verified[[string]$RootIdentity.key] = $RootIdentity
    $result = [Collections.Generic.List[object]]::new()
    $changed = $true
    while ($changed) {
        $changed = $false
        foreach ($candidate in @($Candidates)) {
            $record = $candidate.identity
            $parent = $candidate.parent_identity
            if (-not (Test-ProcessIdentityProofShape $record) -or -not (Test-ProcessIdentityProofShape $parent)) { continue }
            $recordKey = [string]$record.key
            $parentKey = [string]$parent.key
            if ($verified.ContainsKey($recordKey) -or -not $verified.ContainsKey($parentKey) -or $BaselineIdentityKeys -contains $recordKey) { continue }
            $verifiedParent = $verified[$parentKey]
            if ([int]$candidate.parent_pid -ne [int]$verifiedParent.pid -or [string]$parent.key -cne [string]$verifiedParent.key) { continue }
            if ([long]$record.start_ticks -lt [long]$RootIdentity.start_ticks -or [long]$record.start_ticks -lt [long]$verifiedParent.start_ticks -or [long]$record.start_ticks -gt $OwnershipEndTicks) { continue }
            if (-not (Test-CimCreationMatchesProcessStartTicks ([long]$candidate.creation_ticks) ([long]$record.start_ticks))) { continue }
            $verified[$recordKey] = $record
            [void]$result.Add($record)
            $changed = $true
        }
    }
    return @($result)
}


function Get-VerifiedDescendantProcessRecords {
    param([object]$RootIdentity, [string[]]$BaselineIdentityKeys, [AllowNull()][object]$RootExitTimeUtc = $null)
    if (-not (Test-ProcessIdentityProofShape $RootIdentity)) { return @() }
    if (-not (Test-LiveProcessMatchesIdentity $RootIdentity) -and $null -eq $RootExitTimeUtc) { return @() }
    $ownershipEndTicks = if ($null -eq $RootExitTimeUtc) { [DateTime]::UtcNow.Ticks } else { ([datetime]$RootExitTimeUtc).ToUniversalTime().Ticks }
    $candidates = [Collections.Generic.List[object]]::new()
    foreach ($entry in @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue)) {
        $live = Get-Process -Id ([int]$entry.ProcessId) -ErrorAction SilentlyContinue
        if ($null -eq $live) { continue }
        try {
            $identity = Get-ProcessIdentityRecord $live
            $parentPid = [int]$entry.ParentProcessId
            if ($parentPid -eq [int]$RootIdentity.pid) {
                $parentIdentity = $RootIdentity
            }
            else {
                $parentProcess = Get-Process -Id $parentPid -ErrorAction SilentlyContinue
                if ($null -eq $parentProcess) { continue }
                $parentIdentity = Get-ProcessIdentityRecord $parentProcess
            }
            [void]$candidates.Add([ordered]@{
                parent_pid = $parentPid
                parent_identity = $parentIdentity
                creation_ticks = ([datetime]$entry.CreationDate).ToUniversalTime().Ticks
                identity = $identity
            })
        }
        catch {}
    }
    if ($null -eq $RootExitTimeUtc -and -not (Test-LiveProcessMatchesIdentity $RootIdentity)) { return @() }
    return @(Resolve-VerifiedDescendantIdentityRecords $RootIdentity $ownershipEndTicks $BaselineIdentityKeys @($candidates))
}


function Add-RetainedDescendantRecords {
    param(
        [object]$RootIdentity,
        [string[]]$BaselineIdentityKeys,
        [Collections.Generic.List[object]]$RetainedRecords,
        [AllowNull()][object]$RootExitTimeUtc = $null
    )
    $known = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($record in @($RetainedRecords)) { [void]$known.Add([string]$record.key) }
    foreach ($record in @(Get-VerifiedDescendantProcessRecords $RootIdentity $BaselineIdentityKeys $RootExitTimeUtc)) {
        if ($known.Add([string]$record.key)) { [void]$RetainedRecords.Add($record) }
    }
}


function Stop-ExactStartedProcess {
    param([System.Diagnostics.Process]$Process, [object]$Identity)
    if ($null -eq $Process -or -not (Test-ProcessIdentityProofShape $Identity)) { return }
    $live = Get-Process -Id ([int]$Identity.pid) -ErrorAction SilentlyContinue
    if ($null -eq $live) { return }
    try {
        $actual = Get-ProcessIdentityRecord $live
        if ([string]$actual.key -ceq [string]$Identity.key) { Stop-Process -InputObject $live -Force -ErrorAction SilentlyContinue }
    }
    catch {}
}


function Stop-ExactStartedProcessTree {
    param(
        [System.Diagnostics.Process]$RootProcess,
        [object]$RootIdentity,
        [string[]]$BaselineIdentityKeys,
        [Collections.Generic.List[object]]$RetainedRecords,
        [string[]]$AllowedPaths
    )
    if ($null -eq $RootProcess -or -not (Test-ProcessIdentityProofShape $RootIdentity)) { return }
    Add-RetainedDescendantRecords $RootIdentity $BaselineIdentityKeys $RetainedRecords
    foreach ($record in @($RetainedRecords | Sort-Object { [int]$_.pid } -Descending)) {
        if (@($AllowedPaths | Where-Object { Test-SamePath $_ ([string]$record.path) }).Count -ne 1) { continue }
        $live = Get-Process -Id ([int]$record.pid) -ErrorAction SilentlyContinue
        if ($null -eq $live) { continue }
        try {
            $actual = Get-ProcessIdentityRecord $live
            if ([string]$actual.key -ceq [string]$record.key) { Stop-Process -InputObject $live -Force -ErrorAction SilentlyContinue }
        }
        catch {}
    }
    Stop-ExactStartedProcess $RootProcess $RootIdentity
}


function Get-ExactOwnedResidualIdentityRecords {
    param([object]$RootIdentity, [string[]]$BaselineIdentityKeys, [Collections.Generic.List[object]]$RetainedRecords, [string[]]$AllowedPaths)
    $result = [Collections.Generic.List[object]]::new()
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    if (Test-LiveProcessMatchesIdentity $RootIdentity) {
        [void]$seen.Add([string]$RootIdentity.key)
        [void]$result.Add($RootIdentity)
    }
    Add-RetainedDescendantRecords $RootIdentity $BaselineIdentityKeys $RetainedRecords
    foreach ($record in @($RetainedRecords)) {
        if (@($AllowedPaths | Where-Object { Test-SamePath $_ ([string]$record.path) }).Count -ne 1) { continue }
        if ((Test-LiveProcessMatchesIdentity $record) -and $seen.Add([string]$record.key)) { [void]$result.Add($record) }
    }
    return @($result | Sort-Object { [int]$_.pid }, { [string]$_.key })
}


function Get-ExactOwnedResidualPids {
    param([object]$RootIdentity, [string[]]$BaselineIdentityKeys, [Collections.Generic.List[object]]$RetainedRecords, [string[]]$AllowedPaths)
    return @(
        Get-ExactOwnedResidualIdentityRecords $RootIdentity $BaselineIdentityKeys $RetainedRecords $AllowedPaths |
            ForEach-Object { [int]$_.pid } |
            Sort-Object -Unique
    )
}


function Get-AuthoritativeOwnedResidualIdentityRecords {
    param(
        [object]$RootIdentity,
        [string[]]$BaselineIdentityKeys,
        [Collections.Generic.List[object]]$RetainedRecords,
        [string[]]$AllowedPaths,
        [scriptblock]$CimProviderForTest = $null,
        [scriptblock]$IdentityResolverForTest = $null
    )
    if (-not (Test-ProcessIdentityProofShape $RootIdentity)) { throw 'Authoritative owned-process census requires a valid root identity proof.' }
    if ($null -eq $RetainedRecords) { throw 'Authoritative owned-process census requires a retained-descendant identity list.' }
    $allowed = @($AllowedPaths | ForEach-Object { Normalize-FullPath $_ } | Sort-Object -Unique)
    if ($allowed.Count -eq 0) { throw 'Authoritative owned-process census requires at least one allowed executable path.' }

    try {
        $cimEntries = if ($null -ne $CimProviderForTest) { @(& $CimProviderForTest) } else { @(Get-CimInstance Win32_Process -ErrorAction Stop) }
    }
    catch { throw "Authoritative CIM enumeration failed: $($_.Exception.Message)" }
    if ($cimEntries.Count -eq 0) { throw 'Authoritative CIM enumeration returned no process records.' }

    $cimByPid = @{}
    foreach ($entry in $cimEntries) {
        $entryPid = [int]$entry.ProcessId
        if ($entryPid -lt 0) { throw "Authoritative CIM record has an invalid PID: $entryPid" }
        if ($cimByPid.ContainsKey($entryPid)) { throw "Authoritative CIM enumeration returned duplicate PID $entryPid." }
        $cimByPid[$entryPid] = $entry
    }

    $rootPid = [int]$RootIdentity.pid
    $relevantPids = [Collections.Generic.HashSet[int]]::new()
    [void]$relevantPids.Add($rootPid)
    $changed = $true
    while ($changed) {
        $changed = $false
        foreach ($entry in $cimEntries) {
            $entryPid = [int]$entry.ProcessId
            $parentPid = [int]$entry.ParentProcessId
            if ($entryPid -gt 0 -and -not $relevantPids.Contains($entryPid) -and $relevantPids.Contains($parentPid)) {
                [void]$relevantPids.Add($entryPid)
                $changed = $true
            }
        }
    }

    $liveRelevant = @{}
    foreach ($relevantPid in @($relevantPids | Sort-Object)) {
        $process = Get-StrictOptionalProcessById $relevantPid
        $hasCim = $cimByPid.ContainsKey($relevantPid)
        if ($null -eq $process) {
            if ($hasCim) { throw "Authoritative identity race: CIM reported relevant PID $relevantPid but exact process lookup could not prove it." }
            continue
        }
        try {
            if (-not $hasCim) { throw "Authoritative identity ambiguity: present relevant PID $relevantPid has no CIM record." }
            $identity = Get-StrictCensusIdentityRecord $process $cimByPid[$relevantPid] $IdentityResolverForTest
            $liveRelevant[$relevantPid] = $identity
        }
        finally { $process.Dispose() }
    }

    $rootPidReused = $liveRelevant.ContainsKey($rootPid) -and [string]$liveRelevant[$rootPid].key -cne [string]$RootIdentity.key
    $descendantPids = @($relevantPids | Where-Object { $_ -ne $rootPid })
    if ($rootPidReused -and $descendantPids.Count -gt 0) { throw 'Authoritative ancestry ambiguity: root PID was reused while numeric descendants remain.' }

    $result = [Collections.Generic.List[object]]::new()
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    if ($liveRelevant.ContainsKey($rootPid) -and -not $rootPidReused) {
        [void]$seen.Add([string]$RootIdentity.key)
        [void]$result.Add($RootIdentity)
    }

    $descendantIdentities = @{}
    foreach ($descendantPid in $descendantPids) {
        if (-not $liveRelevant.ContainsKey($descendantPid)) { throw "Authoritative ancestry ambiguity: relevant descendant PID $descendantPid disappeared during census." }
        $identity = $liveRelevant[$descendantPid]
        if (@($allowed | Where-Object { Test-SamePath $_ ([string]$identity.path) }).Count -ne 1) { throw "Authoritative ancestry found an unexpected executable for relevant descendant PID ${descendantPid}: $($identity.path)" }
        if ($BaselineIdentityKeys -contains [string]$identity.key) { throw "Authoritative ancestry mapped a baseline process as an owned descendant: $($identity.key)" }
        if ([long]$identity.start_ticks -lt [long]$RootIdentity.start_ticks -or [long]$identity.start_ticks -gt [DateTime]::UtcNow.Ticks) { throw "Authoritative descendant lifetime is outside the owned root interval for PID $descendantPid." }
        $descendantIdentities[$descendantPid] = $identity
    }
    foreach ($descendantPid in $descendantPids) {
        $cursorPid = [int]$descendantPid
        $visited = [Collections.Generic.HashSet[int]]::new()
        while ($cursorPid -ne $rootPid) {
            if (-not $visited.Add($cursorPid)) { throw "Authoritative ancestry cycle detected at PID $cursorPid." }
            if (-not $cimByPid.ContainsKey($cursorPid)) { throw "Authoritative ancestry CIM record disappeared for PID $cursorPid." }
            $parentPid = [int]$cimByPid[$cursorPid].ParentProcessId
            if ($parentPid -eq $rootPid) {
                if ([long]$descendantIdentities[$cursorPid].start_ticks -lt [long]$RootIdentity.start_ticks) { throw "Authoritative direct child predates its root for PID $cursorPid." }
            }
            else {
                if (-not $descendantIdentities.ContainsKey($parentPid)) { throw "Authoritative parent identity/ancestry is unprovable for child PID $cursorPid (parent $parentPid)." }
                if ([long]$descendantIdentities[$cursorPid].start_ticks -lt [long]$descendantIdentities[$parentPid].start_ticks) { throw "Authoritative child predates its parent for PID $cursorPid." }
            }
            $cursorPid = $parentPid
        }
        $identity = $descendantIdentities[$descendantPid]
        if ($seen.Add([string]$identity.key)) { [void]$result.Add($identity) }
    }

    foreach ($retained in @($RetainedRecords)) {
        if (-not (Test-ProcessIdentityProofShape $retained)) { throw 'Authoritative census found malformed retained-descendant identity proof.' }
        if (@($allowed | Where-Object { Test-SamePath $_ ([string]$retained.path) }).Count -ne 1) { throw "Authoritative retained descendant has an unexpected executable path: $($retained.path)" }
        if ($seen.Contains([string]$retained.key)) { continue }
        $retainedPid = [int]$retained.pid
        $process = Get-StrictOptionalProcessById $retainedPid
        if ($null -eq $process) { continue }
        try {
            if (-not $cimByPid.ContainsKey($retainedPid)) { throw "Authoritative identity ambiguity: present retained PID $retainedPid has no CIM record." }
            $actual = Get-StrictCensusIdentityRecord $process $cimByPid[$retainedPid] $IdentityResolverForTest
            if ([string]$actual.key -ceq [string]$retained.key -and $seen.Add([string]$retained.key)) { [void]$result.Add($retained) }
        }
        finally { $process.Dispose() }
    }
    return @($result | Sort-Object { [int]$_.pid }, { [string]$_.key })
}


function ConvertTo-WindowsCommandLineArgument {
    param([AllowEmptyString()][string]$Value)
    if ($Value.IndexOf([char]0) -ge 0 -or $Value.Contains("`r") -or $Value.Contains("`n")) { throw 'Native arguments may not contain NUL or newline characters.' }
    if ($Value.Length -gt 0 -and $Value -notmatch '[\s"]') { return $Value }
    $builder = [Text.StringBuilder]::new()
    [void]$builder.Append([char]34)
    $slashes = 0
    foreach ($character in $Value.ToCharArray()) {
        if ($character -eq [char]92) { $slashes += 1; continue }
        if ($character -eq [char]34) {
            if ($slashes -gt 0) { [void]$builder.Append([char]92, $slashes * 2) }
            [void]$builder.Append([char]92)
            [void]$builder.Append([char]34)
            $slashes = 0
            continue
        }
        if ($slashes -gt 0) { [void]$builder.Append([char]92, $slashes); $slashes = 0 }
        [void]$builder.Append($character)
    }
    if ($slashes -gt 0) { [void]$builder.Append([char]92, $slashes * 2) }
    [void]$builder.Append([char]34)
    return $builder.ToString()
}


function Join-ProcessArguments {
    param([string[]]$Arguments)
    return ((@($Arguments) | ForEach-Object { ConvertTo-WindowsCommandLineArgument ([string]$_) }) -join ' ')
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
        [ValidateSet('Godot', 'Exact')][string]$ProcessKind,
        [string[]]$BaselineGodotIdentityKeys = @(),
        [hashtable]$ChildEnvironment = @{},
        [int]$TimeoutSec,
        [switch]$ForceIdentityFailureForTest,
        [switch]$ForceSecondPumpFailureForTest
    )
    $stdoutStream = $null
    $stderrStream = $null
    $process = $null
    $processIdentity = $null
    $startupFallbackIdentity = $null
    $stdoutTask = $null
    $stderrTask = $null
    $processStarted = $false
    $retained = [Collections.Generic.List[object]]::new()
    $stopwatch = [Diagnostics.Stopwatch]::StartNew()
    try {
        $stdoutStream = [IO.FileStream]::new($StdoutPath, [IO.FileMode]::Create, [IO.FileAccess]::Write, [IO.FileShare]::Read)
        $stderrStream = [IO.FileStream]::new($StderrPath, [IO.FileMode]::Create, [IO.FileAccess]::Write, [IO.FileShare]::Read)
        $startInfo = [Diagnostics.ProcessStartInfo]::new()
        $startInfo.FileName = $FilePath
        $startInfo.Arguments = Join-ProcessArguments $Arguments
        $startInfo.UseShellExecute = $false
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        $startInfo.CreateNoWindow = $true
        foreach ($key in $ChildEnvironment.Keys) { $startInfo.EnvironmentVariables[[string]$key] = [string]$ChildEnvironment[$key] }
        $process = [Diagnostics.Process]::new()
        $process.StartInfo = $startInfo
        if (-not $process.Start()) { throw "Could not start process: $FilePath" }
        $processStarted = $true
        $fallbackStartUtc = $process.StartTime.ToUniversalTime()
        $fallbackPath = Normalize-FullPath $FilePath
        $startupFallbackIdentity = [ordered]@{
            pid = [int]$process.Id
            name = [string]$process.ProcessName
            path = $fallbackPath
            start_utc = $fallbackStartUtc.ToString('o')
            start_ticks = [long]$fallbackStartUtc.Ticks
            key = ('{0}|{1}|{2}|{3}' -f $process.Id, $fallbackStartUtc.Ticks, $process.ProcessName, $fallbackPath.ToLowerInvariant())
        }
        if ($ForceIdentityFailureForTest) { throw 'Forced process-identity acquisition failure for hostile validation.' }
        $processIdentity = Get-ProcessIdentityRecord $process
        $stdoutTask = $process.StandardOutput.BaseStream.CopyToAsync($stdoutStream)
        if ($ForceSecondPumpFailureForTest) { throw 'Forced second redirect-pump setup failure for hostile validation.' }
        $stderrTask = $process.StandardError.BaseStream.CopyToAsync($stderrStream)
        if ($ProcessKind -eq 'Godot') {
            $deadline = [DateTime]::UtcNow.AddSeconds(2)
            do {
                Add-RetainedDescendantRecords $processIdentity $BaselineGodotIdentityKeys $retained
                if ($process.WaitForExit(25)) { break }
            } while ([DateTime]::UtcNow -lt $deadline)
        }
        return [pscustomobject]@{
            process = $process
            process_id = [int]$process.Id
            process_start_time = $process.StartTime
            process_identity = $processIdentity
            retained_descendant_records = $retained
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
        $exception = $_.Exception
        $cleanupIdentity = if ($null -ne $processIdentity) { $processIdentity } else { $startupFallbackIdentity }
        if ($null -ne $cleanupIdentity) {
            $exception.Data['owned_process_id'] = [int]$cleanupIdentity.pid
            $exception.Data['owned_process_identity'] = $cleanupIdentity
        }
        if ($processStarted -and $null -ne $process) {
            if ($null -ne $cleanupIdentity) {
                if ($ProcessKind -eq 'Godot') { Stop-ExactStartedProcessTree $process $cleanupIdentity $BaselineGodotIdentityKeys $retained @($canonicalGodotPath, $canonicalGodotGuiPath) }
                else { Stop-ExactStartedProcess $process $cleanupIdentity }
            }
            try {
                if (-not $process.HasExited) { $process.Kill() }
                [void]$process.WaitForExit(5000)
            }
            catch {}
        }
        $tasks = [Collections.Generic.List[Threading.Tasks.Task]]::new()
        if ($null -ne $stdoutTask) { [void]$tasks.Add($stdoutTask) }
        if ($null -ne $stderrTask) { [void]$tasks.Add($stderrTask) }
        if ($tasks.Count -gt 0) { try { [void][Threading.Tasks.Task]::WaitAll($tasks.ToArray(), 5000) } catch {} }
        foreach ($stream in @($stdoutStream, $stderrStream)) { if ($null -ne $stream) { try { $stream.Dispose() } catch {} } }
        if ($null -ne $process) { try { $process.Dispose() } catch {} }
        $stopwatch.Stop()
        throw
    }
}


function Complete-RedirectedProcess {
    param(
        [pscustomobject]$Started,
        [ValidateSet('Godot', 'Exact')][string]$ProcessKind,
        [string[]]$BaselineGodotIdentityKeys = @(),
        [scriptblock]$ContinuityCheck = $null
    )
    $process = $Started.process
    $timedOut = $false
    $nativeObserved = $false
    $nativeExitCode = [int]$nativeExitSentinel
    $effectiveExitCode = 125
    $errorText = ''
    try {
        $exited = $false
        while ([DateTime]::UtcNow -lt $Started.deadline_utc) {
            if ($null -ne $ContinuityCheck) { & $ContinuityCheck }
            if ($ProcessKind -eq 'Godot') { Add-RetainedDescendantRecords $Started.process_identity $BaselineGodotIdentityKeys $Started.retained_descendant_records }
            $remaining = [Math]::Max(1, [int]($Started.deadline_utc.Subtract([DateTime]::UtcNow).TotalMilliseconds))
            if ($process.WaitForExit([Math]::Min(250, $remaining))) { $exited = $true; break }
        }
        if (-not $exited) {
            $timedOut = $true
            if ($ProcessKind -eq 'Godot') { Stop-ExactStartedProcessTree $process $Started.process_identity $BaselineGodotIdentityKeys $Started.retained_descendant_records @($canonicalGodotPath, $canonicalGodotGuiPath) }
            else { Stop-ExactStartedProcess $process $Started.process_identity }
            if (-not $process.WaitForExit(5000)) { throw 'Timed-out process did not exit after exact cleanup.' }
        }
        $process.Refresh()
        if ($null -ne $ContinuityCheck) { & $ContinuityCheck }
        if (-not $process.HasExited) { throw 'Bounded wait returned without process completion.' }
        if ($ProcessKind -eq 'Godot') {
            $exitTime = $process.ExitTime.ToUniversalTime()
            Add-RetainedDescendantRecords $Started.process_identity $BaselineGodotIdentityKeys $Started.retained_descendant_records $exitTime
            Stop-ExactStartedProcessTree $process $Started.process_identity $BaselineGodotIdentityKeys $Started.retained_descendant_records @($canonicalGodotPath, $canonicalGodotGuiPath)
        }
        $nativeExitCode = Get-StrictNativeExitCode $process.ExitCode
        $nativeObserved = $true
        $pumpDeadline = if ($timedOut) { [DateTime]::UtcNow.AddSeconds(5) } else { $Started.deadline_utc }
        $pumpRemaining = [Math]::Max(1, [int]($pumpDeadline.Subtract([DateTime]::UtcNow).TotalMilliseconds))
        $pumpTasks = [Threading.Tasks.Task[]]@($Started.stdout_task, $Started.stderr_task)
        if (-not [Threading.Tasks.Task]::WaitAll($pumpTasks, $pumpRemaining)) { throw 'Redirected streams did not drain within the shared deadline.' }
        if ($Started.stdout_task.IsFaulted -or $Started.stderr_task.IsFaulted) { throw 'A redirected stream pump faulted.' }
        $Started.stdout_stream.Flush()
        $Started.stderr_stream.Flush()
        $effectiveExitCode = if ($timedOut) { 124 } else { $nativeExitCode }
    }
    catch {
        $errorText = $_.Exception.Message
        $effectiveExitCode = if ($timedOut) { 124 } else { 125 }
        if ($ProcessKind -eq 'Godot') { Stop-ExactStartedProcessTree $process $Started.process_identity $BaselineGodotIdentityKeys $Started.retained_descendant_records @($canonicalGodotPath, $canonicalGodotGuiPath) }
        else { Stop-ExactStartedProcess $process $Started.process_identity }
        try { [void]$process.WaitForExit(5000) } catch {}
    }
    finally {
        if ($ProcessKind -eq 'Godot') { Stop-ExactStartedProcessTree $process $Started.process_identity $BaselineGodotIdentityKeys $Started.retained_descendant_records @($canonicalGodotPath, $canonicalGodotGuiPath) }
        else { Stop-ExactStartedProcess $process $Started.process_identity }
        foreach ($stream in @($Started.stdout_stream, $Started.stderr_stream)) { try { $stream.Dispose() } catch {} }
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
        process_id = [int]$Started.process_id
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
        '(?im)^\s*ERROR(?:\s|:).*$' ,
        '(?im)^\s*WARNING(?:\s|:).*$' ,
        '(?im)^.*ObjectDB.*(?:leak|still alive|instance).*$' ,
        '(?im)^.*Resources still in use.*$',
        '(?im)^\s*Leaked instance:.*$',
        '(?im)^\s*Orphan Node:.*$',
        '(?im)^\s*Orphan StringName:.*$',
        '(?im)^\s*StringName:\s*\d+\s+unclaimed\b.*\bat exit\b.*$',
        '(?im)^\s*RID allocation(?:\s|:).*$',
        '(?im)^\s*RID allocations\b.*\bleaked at exit\b.*$',
        '(?im)^.*(?:CRASH|FATAL).*$'
    )
    $lines = [Collections.Generic.List[string]]::new()
    foreach ($pattern in $patterns) {
        foreach ($match in [regex]::Matches($Text, $pattern)) {
            $line = $match.Value.Trim()
            if (-not [string]::IsNullOrWhiteSpace($line) -and -not $lines.Contains($line)) { [void]$lines.Add($line) }
        }
    }
    return @($lines)
}


function Get-LiveGodotProcesses {
    return @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -in @('Godot_v4.6-stable_win64_console', 'Godot_v4.6-stable_win64') })
}


function Get-LiveGodotIdentityRecords {
    $census = Get-LiveGodotCensus
    return @($census.records)
}


function Get-LiveGodotCensus {
    $processes = @(Get-LiveGodotProcesses)
    $records = [Collections.Generic.List[object]]::new()
    $failures = [Collections.Generic.List[string]]::new()
    foreach ($process in $processes) {
        try { [void]$records.Add((Get-ProcessIdentityRecord $process)) }
        catch { [void]$failures.Add("PID $($process.Id): $($_.Exception.Message)") }
    }
    if ($failures.Count -gt 0 -or $records.Count -ne $processes.Count) {
        throw ('Godot census is ambiguous; live OS count={0}, proven identity count={1}, failures={2}' -f $processes.Count, $records.Count, ($failures -join ' | '))
    }
    $recordPids = @($records | ForEach-Object { [int]$_.pid } | Sort-Object -Unique)
    if ($recordPids.Count -ne $records.Count) { throw 'Godot census contains duplicate process identities.' }
    return [ordered]@{ process_count = $processes.Count; identity_count = $records.Count; records = @($records) }
}


function Read-LeaseFields {
    param([string]$Path)
    $fields = @{}
    foreach ($line in @([IO.File]::ReadAllLines($Path))) {
        $index = $line.IndexOf('=')
        if ($index -gt 0) { $fields[$line.Substring(0, $index)] = $line.Substring($index + 1) }
    }
    return $fields
}


function Get-LeaseBinding {
    param([System.IO.FileInfo]$File)
    $fields = Read-LeaseFields $File.FullName
    $contentPid = 0
    if (-not [int]::TryParse([string]$fields['pid'], [ref]$contentPid) -or $contentPid -le 0) {
        throw "Lease has no positive content PID: $($File.FullName)"
    }
    if ($File.Name -ceq 'EXCLUSIVE.lease') {
        return [ordered]@{ path = $File.FullName; kind = 'exclusive'; pid = $contentPid; fields = $fields }
    }
    $match = [regex]::Match($File.Name, '-(?<pid>[0-9]+)\.lease$', [Text.RegularExpressions.RegexOptions]::CultureInvariant)
    if (-not $match.Success) { throw "Focused lease filename has no terminal PID: $($File.FullName)" }
    $filePid = 0
    if (-not [int]::TryParse($match.Groups['pid'].Value, [ref]$filePid) -or $filePid -le 0 -or $filePid -ne $contentPid) {
        throw "Focused lease filename/content PID mismatch: $($File.FullName)"
    }
    return [ordered]@{ path = $File.FullName; kind = 'focused'; pid = $contentPid; fields = $fields }
}


function Get-ExactProcessIdentityByPid {
    param(
        [int]$ProcessId,
        [scriptblock]$IdentityByPidForTest = $null
    )
    if ($ProcessId -le 0) { throw "Exact process identity requires a positive PID: $ProcessId" }
    $identity = $null
    if ($null -ne $IdentityByPidForTest) {
        try { $identity = & $IdentityByPidForTest $ProcessId }
        catch { throw "Injected exact process-identity resolution failed for PID ${ProcessId}: $($_.Exception.Message)" }
    }
    else {
        $process = Get-StrictOptionalProcessById $ProcessId
        if ($null -eq $process) { return $null }
        try { $identity = Get-ProcessIdentityRecord $process }
        finally { $process.Dispose() }
    }
    if ($null -eq $identity) { return $null }
    if (-not (Test-ProcessIdentityProofShape $identity) -or [int]$identity.pid -ne $ProcessId) {
        throw "Exact process-identity resolution returned invalid proof for PID $ProcessId."
    }
    return $identity
}


function Get-ExactLeaseOwnerState {
    param(
        [object]$Binding,
        [scriptblock]$IdentityByPidForTest = $null
    )
    if ($null -eq $Binding -or [int]$Binding.pid -le 0 -or $null -eq $Binding.fields) {
        throw 'Lease binding is missing its positive PID or parsed fields.'
    }
    $actual = Get-ExactProcessIdentityByPid ([int]$Binding.pid) $IdentityByPidForTest
    if ($null -eq $actual) {
        return [ordered]@{ valid = $false; stale = $true; reason = 'owner_absent'; identity = $null }
    }
    $ownerKey = [string]$Binding.fields['owner_key']
    $ownerPath = [string]$Binding.fields['owner_path']
    if ([string]::IsNullOrWhiteSpace($ownerKey) -or [string]::IsNullOrWhiteSpace($ownerPath) -or -not [IO.Path]::IsPathRooted($ownerPath)) {
        throw "Live lease owner identity is incomplete or malformed for PID $($Binding.pid)."
    }
    try { $ownerPath = Normalize-FullPath $ownerPath }
    catch { throw "Live lease owner path is unprovable for PID $($Binding.pid): $($_.Exception.Message)" }
    if ($ownerKey -cne [string]$actual.key -or -not (Test-SamePath $ownerPath ([string]$actual.path))) {
        return [ordered]@{ valid = $false; stale = $true; reason = 'owner_identity_mismatch'; identity = $actual }
    }
    return [ordered]@{ valid = $true; stale = $false; reason = 'exact_owner_match'; identity = $actual }
}


function Remove-ExactProvablyStaleLease {
    param(
        [System.IO.FileInfo]$File,
        [string]$LeaseDirectory,
        [string]$ExpectedSha256
    )
    $root = Normalize-FullPath $LeaseDirectory
    $path = Assert-StrictChildPath $File.FullName $root
    [void](Assert-NoReparseAncestors $path $root)
    $current = Get-Item -LiteralPath $path -Force -ErrorAction Stop
    if ($current.PSIsContainer -or ($current.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Refusing stale-lease cleanup for a non-file or reparse point: $path"
    }
    Assert-ExpectedSha256 'Provably stale lease before exact cleanup' $ExpectedSha256 (Get-Sha256 $path)
    [IO.File]::Delete($path)
    if (Test-Path -LiteralPath $path) { throw "Provably stale exact lease survived cleanup: $path" }
}


function Clear-ProvablyStaleLeases {
    param(
        [string]$LeaseDirectory = $leaseRoot,
        [scriptblock]$IdentityByPidForTest = $null
    )
    if (-not (Test-Path -LiteralPath $LeaseDirectory)) { return }
    $mutex = [Threading.Mutex]::new($false, $launchMutexName)
    $mutexOwned = $false
    try {
        try { $mutexOwned = $mutex.WaitOne(5000) }
        catch [Threading.AbandonedMutexException] { $mutexOwned = $true }
        if (-not $mutexOwned) { throw 'Timed out acquiring the Q-009 launch mutex for stale-lease cleanup.' }
        $root = Normalize-FullPath $LeaseDirectory
        [void](Assert-NoReparseAncestors $root $root)
        foreach ($file in @(Get-ChildItem -LiteralPath $root -Filter '*.lease' -File -Force -ErrorAction Stop)) {
            [void](Assert-NoReparseAncestors $file.FullName $root)
            $expectedSha = Get-Sha256 $file.FullName
            $binding = Get-LeaseBinding $file
            $state = Get-ExactLeaseOwnerState $binding $IdentityByPidForTest
            if ([bool]$state.stale) { Remove-ExactProvablyStaleLease $file $root $expectedSha }
        }
    }
    finally {
        if ($mutexOwned) { $mutex.ReleaseMutex() }
        $mutex.Dispose()
    }
}


function Get-LiveLeaseOwnerIdentities {
    param(
        [string]$LeaseDirectory = $leaseRoot,
        [scriptblock]$IdentityByPidForTest = $null
    )
    $identities = [Collections.Generic.List[object]]::new()
    $keys = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    if (-not (Test-Path -LiteralPath $LeaseDirectory)) { return @() }
    $root = Normalize-FullPath $LeaseDirectory
    [void](Assert-NoReparseAncestors $root $root)
    foreach ($file in @(Get-ChildItem -LiteralPath $root -Filter '*.lease' -File -Force -ErrorAction Stop)) {
        [void](Assert-NoReparseAncestors $file.FullName $root)
        $leaseSha = Get-Sha256 $file.FullName
        $binding = Get-LeaseBinding $file
        $state = Get-ExactLeaseOwnerState $binding $IdentityByPidForTest
        [void](Assert-NoReparseAncestors $file.FullName $root)
        Assert-ExpectedSha256 'Live lease-owner census stable bytes' $leaseSha (Get-Sha256 $file.FullName)
        if ([bool]$state.valid -and $keys.Add([string]$state.identity.key)) { [void]$identities.Add($state.identity) }
    }
    return @($identities)
}


function Get-LiveLeaseOwnerPids {
    param(
        [string]$LeaseDirectory = $leaseRoot,
        [scriptblock]$IdentityByPidForTest = $null
    )
    $identities = @(Get-LiveLeaseOwnerIdentities $LeaseDirectory $IdentityByPidForTest)
    return @($identities | ForEach-Object { [int]$_.pid } | Sort-Object -Unique)
}


function Test-ProcessHasLeaseAncestor {
    param(
        [int]$ProcessId,
        [object[]]$LeaseOwnerIdentities,
        [AllowNull()][object]$ProcessIdentity = $null,
        [scriptblock]$CimProviderForTest = $null,
        [scriptblock]$IdentityByPidForTest = $null
    )
    if ($ProcessId -le 0) { throw "Lease ancestry requires a positive process PID: $ProcessId" }
    $ownersByPid = @{}
    foreach ($identity in @($LeaseOwnerIdentities)) {
        if (-not (Test-ProcessIdentityProofShape $identity)) { throw 'Lease ancestry received malformed owner identity proof.' }
        $ownerPid = [int]$identity.pid
        if ($ownersByPid.ContainsKey($ownerPid)) {
            $prior = $ownersByPid[$ownerPid]
            if ([string]$prior.key -cne [string]$identity.key -or -not (Test-SamePath ([string]$prior.path) ([string]$identity.path))) {
                throw "Lease ancestry received conflicting identities for PID $ownerPid."
            }
        }
        else { $ownersByPid[$ownerPid] = $identity }
    }
    if ($ownersByPid.Count -eq 0) { return $false }

    try {
        $entries = if ($null -ne $CimProviderForTest) { @(& $CimProviderForTest) } else { @(Get-CimInstance Win32_Process -ErrorAction Stop) }
    }
    catch { throw "Lease ancestry CIM enumeration failed: $($_.Exception.Message)" }
    $table = @{}
    foreach ($entry in $entries) {
        $entryPid = 0
        if (-not [int]::TryParse([string]$entry.ProcessId, [ref]$entryPid) -or $entryPid -lt 0) {
            throw 'Lease ancestry CIM census contains a malformed PID.'
        }
        if ($table.ContainsKey($entryPid)) { throw "Lease ancestry CIM census contains duplicate PID $entryPid." }
        $table[$entryPid] = $entry
    }

    $cursor = $ProcessId
    $cursorIdentity = $ProcessIdentity
    if ($null -eq $cursorIdentity) { $cursorIdentity = Get-ExactProcessIdentityByPid $cursor $IdentityByPidForTest }
    if ($null -eq $cursorIdentity) { return $false }
    if (-not (Test-ProcessIdentityProofShape $cursorIdentity) -or [int]$cursorIdentity.pid -ne $cursor) {
        throw "Lease ancestry starting identity is malformed or bound to the wrong PID $cursor."
    }
    $visited = [Collections.Generic.HashSet[int]]::new()
    while ($cursor -gt 0) {
        if (-not $visited.Add($cursor)) { throw "Lease ancestry census contains a cycle at PID $cursor." }
        if (-not $table.ContainsKey($cursor)) { throw "Lease ancestry is unprovable because PID $cursor is absent from the authoritative CIM census." }
        $cursorEntry = $table[$cursor]
        try { $cursorCreationUtc = ([datetime]$cursorEntry.CreationDate).ToUniversalTime() }
        catch { throw "Lease ancestry CIM creation time is unprovable for PID ${cursor}: $($_.Exception.Message)" }
        if (-not (Test-CimCreationMatchesProcessStartTicks $cursorCreationUtc.Ticks ([long]$cursorIdentity.start_ticks))) {
            throw "Lease ancestry CIM/process start identity mismatch for PID $cursor."
        }
        if ($ownersByPid.ContainsKey($cursor)) {
            $expected = $ownersByPid[$cursor]
            $actual = Get-ExactProcessIdentityByPid $cursor $IdentityByPidForTest
            if ($null -eq $actual) { return $false }
            if ([string]$actual.key -cne [string]$cursorIdentity.key -or -not (Test-SamePath ([string]$actual.path) ([string]$cursorIdentity.path))) { return $false }
            return [string]$actual.key -ceq [string]$expected.key -and (Test-SamePath ([string]$actual.path) ([string]$expected.path))
        }
        $parent = 0
        if (-not [int]::TryParse([string]$cursorEntry.ParentProcessId, [ref]$parent) -or $parent -lt 0) {
            throw "Lease ancestry CIM parent PID is malformed for PID $cursor."
        }
        if ($parent -eq $cursor) { throw "Lease ancestry census contains a self-parent cycle at PID $cursor." }
        if ($parent -le 0) { return $false }
        $parentIdentity = Get-ExactProcessIdentityByPid $parent $IdentityByPidForTest
        if ($null -eq $parentIdentity) { throw "Lease ancestry parent identity is unprovable because PID $parent is no longer live." }
        if ([long]$parentIdentity.start_ticks -gt [long]$cursorIdentity.start_ticks) { return $false }
        $cursor = $parent
        $cursorIdentity = $parentIdentity
    }
    return $false
}


function Get-NewUnownedGodotRecords {
    param([string[]]$BaselineKeys)
    $owners = @(Get-LiveLeaseOwnerIdentities)
    $census = Get-LiveGodotCensus
    return @($census.records | Where-Object {
        $BaselineKeys -notcontains [string]$_.key -and -not (Test-ProcessHasLeaseAncestor -ProcessId ([int]$_.pid) -LeaseOwnerIdentities $owners -ProcessIdentity $_)
    })
}


function Test-FocusedLaunchCapacity {
    param([bool]$ExclusivePresent, [int]$LiveFocusedLeaseCount, [int]$LiveGodotProcessCount)
    return (-not $ExclusivePresent) -and $LiveFocusedLeaseCount -lt 2 -and ($LiveGodotProcessCount + 2) -le 4
}


function New-OwnedLeaseFile {
    param([string]$Path, [string]$Text, [switch]$ForceWriteFailureForTest)
    $stream = $null
    $created = $false
    try {
        $stream = [IO.FileStream]::new($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
        $created = $true
        if ($ForceWriteFailureForTest) { throw 'Forced lease write failure.' }
        $bytes = [Text.Encoding]::UTF8.GetBytes($Text)
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Flush($true)
    }
    catch {
        if ($null -ne $stream) { try { $stream.Dispose() } catch {}; $stream = $null }
        if ($created -and (Test-Path -LiteralPath $Path)) { Remove-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue }
        throw
    }
    finally { if ($null -ne $stream) { $stream.Dispose() } }
}


function Assert-OwnedLease {
    param([string]$Path, [object]$OwnerIdentity, [string]$Root, [string]$Commit, [string]$Tree, [string]$Phase)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Owned Q-009 lease disappeared: $Path" }
    $binding = Get-LeaseBinding (Get-Item -LiteralPath $Path -Force)
    $fields = $binding.fields
    if (
        [int]$binding.pid -ne [int]$OwnerIdentity.pid `
        -or [string]$fields['owner_key'] -cne [string]$OwnerIdentity.key `
        -or -not (Test-SamePath ([string]$fields['owner_path']) ([string]$OwnerIdentity.path)) `
        -or [string]$fields['worktree'] -cne $Root `
        -or [string]$fields['candidate_commit'] -ine $Commit `
        -or [string]$fields['candidate_tree'] -ine $Tree `
        -or [string]$fields['phase'] -cne $Phase
    ) { throw 'Q-009 lease contents no longer prove exact ownership/candidate/phase.' }
}


function Read-JsonObject {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "JSON file is missing: $Path" }
    try { $value = [IO.File]::ReadAllText($Path) | ConvertFrom-Json }
    catch { throw "JSON file is malformed: $Path ($($_.Exception.Message))" }
    if ($null -eq $value -or $value -is [Array]) { throw "JSON root must be an object: $Path" }
    return $value
}


function Get-ArrayValue {
    param([AllowNull()][object]$Value)
    if ($null -eq $Value) { return @() }
    return @($Value)
}


function Get-RelativePathUnderRoot {
    param([string]$Root, [string]$Path)
    $rootFull = (Normalize-FullPath $Root) + '\'
    $pathFull = Normalize-FullPath $Path
    if (-not $pathFull.StartsWith($rootFull, [StringComparison]::OrdinalIgnoreCase)) { throw "Path is outside evidence root: $pathFull" }
    return $pathFull.Substring($rootFull.Length).Replace('\', '/')
}


function Assert-ExactRelativeFileSet {
    param([string]$Root, [string[]]$Expected)
    if (-not (Test-Path -LiteralPath $Root -PathType Container)) { throw "Artifact directory is missing: $Root" }
    $actual = @(Get-ChildItem -LiteralPath $Root -File -Recurse | ForEach-Object { Get-RelativePathUnderRoot $Root $_.FullName } | Sort-Object)
    $wanted = @($Expected | Sort-Object)
    if ($actual.Count -ne $wanted.Count -or (Compare-Object -ReferenceObject $wanted -DifferenceObject $actual).Count -ne 0) {
        throw "Artifact set mismatch under $Root. Expected $($wanted.Count), found $($actual.Count)."
    }
    return $actual
}


function Get-PngEvidence {
    param([string]$Path, [int]$ExpectedWidth, [int]$ExpectedHeight)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "PNG is missing: $Path" }
    $header = [IO.File]::ReadAllBytes($Path)
    $signature = [byte[]](137, 80, 78, 71, 13, 10, 26, 10)
    if ($header.Length -lt 8) { throw "PNG is truncated: $Path" }
    for ($index = 0; $index -lt 8; $index++) { if ($header[$index] -ne $signature[$index]) { throw "PNG signature is invalid: $Path" } }
    Add-Type -AssemblyName System.Drawing
    $bitmap = $null
    $normalized = $null
    $data = $null
    try {
        $bitmap = [Drawing.Bitmap]::new($Path)
        if ($bitmap.Width -ne $ExpectedWidth -or $bitmap.Height -ne $ExpectedHeight) {
            throw "PNG dimensions are wrong for ${Path}: $($bitmap.Width)x$($bitmap.Height), expected ${ExpectedWidth}x${ExpectedHeight}."
        }
        $normalized = $bitmap.Clone([Drawing.Rectangle]::new(0, 0, $bitmap.Width, $bitmap.Height), [Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $data = $normalized.LockBits([Drawing.Rectangle]::new(0, 0, $normalized.Width, $normalized.Height), [Drawing.Imaging.ImageLockMode]::ReadOnly, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $length = [Math]::Abs($data.Stride) * $normalized.Height
        $bytes = [byte[]]::new($length)
        [Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $length)
        if ($null -eq ('Rw061VisiblePixelInspector' -as [type])) {
            Add-Type -TypeDefinition @'
using System;
public static class Rw061VisiblePixelInspector {
    public static long[] Inspect(byte[] bytes) {
        long visible = 0;
        bool different = false;
        UInt32 first = 0;
        for (int offset = 0; offset <= bytes.Length - 4; offset += 4) {
            if (bytes[offset + 3] == 0) continue;
            UInt32 pixel = BitConverter.ToUInt32(bytes, offset);
            if (visible == 0) first = pixel;
            else if (pixel != first) different = true;
            visible++;
        }
        return new long[] { visible, different ? 1L : 0L };
    }
}
'@
        }
        $scan = [Rw061VisiblePixelInspector]::Inspect($bytes)
        $visible = [long]$scan[0]
        $differentVisible = [long]$scan[1] -eq 1
        if ($visible -eq 0) { throw "PNG has no visible pixels: $Path" }
        if (-not $differentVisible) { throw "PNG is blank/single-color across visible pixels: $Path" }
        return [ordered]@{ path = Normalize-FullPath $Path; width = $bitmap.Width; height = $bitmap.Height; visible_pixels = $visible; nonblank = $true; length = [long](Get-Item $Path).Length; sha256 = Get-Sha256 $Path }
    }
    catch { throw "PNG decode/nonblank validation failed for $Path ($($_.Exception.Message))" }
    finally {
        if ($null -ne $data -and $null -ne $normalized) { try { $normalized.UnlockBits($data) } catch {} }
        if ($null -ne $normalized) { $normalized.Dispose() }
        if ($null -ne $bitmap) { $bitmap.Dispose() }
    }
}


function Assert-StringSetEqual {
    param([string[]]$Expected, [string[]]$Actual, [string]$Label)
    $expectedUnique = @($Expected | Sort-Object -Unique)
    $actualUnique = @($Actual | Sort-Object -Unique)
    if ($expectedUnique.Count -ne $Expected.Count -or $actualUnique.Count -ne $Actual.Count -or (Compare-Object $expectedUnique $actualUnique).Count -ne 0) {
        throw "$Label exact identity set is wrong."
    }
}


function Assert-CleanCaptureRecord {
    param([object]$Record, [string]$ExpectedPath, [string]$ExpectedMode, [object]$Png)
    Assert-Contract ($null -ne $Record) "Capture report record is missing for $ExpectedPath."
    Assert-Contract ([bool]$Record.ok) "Capture report did not mark source OK: $ExpectedPath"
    Assert-Contract ([bool]$Record.player_view_clean) "Capture report did not prove clean player view: $ExpectedPath"
    Assert-Contract ([string]$Record.mode -eq $ExpectedMode -or [string]::IsNullOrWhiteSpace([string]$Record.mode)) "Capture report mode drift for $ExpectedPath."
    Assert-Contract (Test-SamePath ([string]$Record.path) $ExpectedPath) "Capture report path drift for $ExpectedPath."
    Assert-ExpectedSha256 "Capture $ExpectedPath" ([string]$Record.sha256) ([string]$Png.sha256)
    Assert-Contract ([string]$Record.capture_source -eq 'production_root_viewport_texture') "Capture did not use production root viewport: $ExpectedPath"
    Assert-Contract (-not [bool]$Record.post_processed) "Source capture was post-processed: $ExpectedPath"
    Assert-Contract ((Get-ArrayValue $Record.errors).Count -eq 0) "Capture record contains errors: $ExpectedPath"
    Assert-Contract ((Get-ArrayValue $Record.direct_interaction_overlaps).Count -eq 0) "Capture record contains direct interaction overlaps: $ExpectedPath"
    Assert-Contract ([bool]$Record.player_view_cleanliness.ok) "Capture cleanliness assertions failed: $ExpectedPath"
    Assert-SourceEvidenceDetails $Record $Record.selection $ExpectedPath $Png
}


function Assert-SourceEvidenceDetails {
    param([object]$Record, [object]$Selection, [string]$ExpectedPath, [object]$Png)
    $validation = $Record.image_validation
    Assert-Contract ([bool]$validation.ok -and [bool]$validation.decoded -and [bool]$validation.nonblank) "Godot-side PNG decode/nonblank validation failed: $ExpectedPath"
    Assert-Contract (Test-SamePath ([string]$validation.path) $ExpectedPath) "Godot-side PNG validation path drift: $ExpectedPath"
    Assert-ExpectedSha256 "Godot-side PNG $ExpectedPath" ([string]$validation.sha256) ([string]$Png.sha256)
    Assert-Contract ([int]$validation.expected_size.w -eq $expectedSourceWidth -and [int]$validation.expected_size.h -eq $expectedSourceHeight) "Godot-side expected dimensions drift: $ExpectedPath"
    Assert-Contract ([int]$validation.actual_size.w -eq $expectedSourceWidth -and [int]$validation.actual_size.h -eq $expectedSourceHeight) "Godot-side actual dimensions drift: $ExpectedPath"
    Assert-Contract ((Get-ArrayValue $validation.errors).Count -eq 0) "Godot-side PNG validation contains errors: $ExpectedPath"
    $rendered = $Record.rendered_identity
    Assert-Contract ([bool]$rendered.ok -and (Get-ArrayValue $rendered.errors).Count -eq 0) "Rendered identity failed: $ExpectedPath"
    $expectedMap = [string]$Selection.map_id
    $expectedScenario = [string]$Selection.scenario_id
    $expectedPhase = [string]$Selection.phase_id
    Assert-Contract ([string]$rendered.requested.map_id -eq $expectedMap -and [string]$rendered.run.map_id -eq $expectedMap -and [string]$rendered.rendered.map_id -eq $expectedMap) "Rendered map identity drift: $ExpectedPath"
    Assert-Contract ([string]$rendered.requested.scenario_id -eq $expectedScenario -and [string]$rendered.run.scenario_id -eq $expectedScenario -and [string]$rendered.rendered.scenario_id -eq $expectedScenario) "Rendered scenario identity drift: $ExpectedPath"
    if ($expectedPhase -eq 'base_inventory') {
        Assert-Contract ([string]::IsNullOrWhiteSpace([string]$rendered.run.phase_id) -and [string]::IsNullOrWhiteSpace([string]$rendered.rendered.phase_id)) "Base capture retained a scenario phase: $ExpectedPath"
    }
    else {
        Assert-Contract ([string]$rendered.run.phase_id -eq $expectedPhase -and [string]$rendered.rendered.phase_id -eq $expectedPhase) "Rendered phase identity drift: $ExpectedPath"
    }
    $generation = $Record.generation_identity
    Assert-Contract ([bool]$generation.ok -and (Get-ArrayValue $generation.errors).Count -eq 0) "Generation provenance failed: $ExpectedPath"
    Assert-Contract (-not [string]::IsNullOrWhiteSpace([string]$generation.identity_key) -and -not [string]::IsNullOrWhiteSpace([string]$generation.expected_seed_text) -and [string]$generation.seed_text -ceq [string]$generation.expected_seed_text) "Generation seed identity is missing or inexact: $ExpectedPath"
    Assert-Contract ([long]$generation.seed_value -ne 0 -and [long]$generation.rng_seed -ne 0 -and [long]$generation.rng_state -ne 0) "Generation RNG identity is zero: $ExpectedPath"
    foreach ($assertionName in @('seed_text_exact', 'world_seed_text_exact_when_present', 'seed_value_nonzero', 'rng_seed_nonzero', 'rng_state_nonzero', 'environment_map_exact', 'scenario_exact', 'phase_exact')) {
        Assert-Contract ([bool]$generation.assertions.$assertionName) "Generation assertion $assertionName failed: $ExpectedPath"
    }
    if (-not [string]::IsNullOrWhiteSpace([string]$generation.world_map_seed_text)) { Assert-Contract ([string]$generation.world_map_seed_text -ceq [string]$generation.expected_seed_text) "Generation world-map seed drifted: $ExpectedPath" }
    Assert-Contract ([string]$generation.environment_map_id -eq $expectedMap -and [string]$generation.scenario_id -eq $expectedScenario) "Generation map/scenario identity drift: $ExpectedPath"
    if ($expectedPhase -eq 'base_inventory') { Assert-Contract ([string]::IsNullOrWhiteSpace([string]$generation.phase_id)) "Base generation retained a phase: $ExpectedPath" }
    else { Assert-Contract ([string]$generation.phase_id -eq $expectedPhase) "Generation phase identity drift: $ExpectedPath" }
}


function Assert-SheetImageValidation {
    param([object]$SheetRecord, [string]$ExpectedPath, [object]$Png, [int]$Width, [int]$Height)
    Assert-Contract ([bool]$SheetRecord.ok -and (Test-SamePath ([string]$SheetRecord.path) $ExpectedPath)) "Sheet path/status mismatch: $ExpectedPath"
    Assert-ExpectedSha256 "Sheet $ExpectedPath" ([string]$SheetRecord.sha256) ([string]$Png.sha256)
    Assert-Contract ([int]$SheetRecord.expected_size.w -eq $Width -and [int]$SheetRecord.expected_size.h -eq $Height) "Sheet expected dimensions drift: $ExpectedPath"
    Assert-Contract ([int]$SheetRecord.size.w -eq $Width -and [int]$SheetRecord.size.h -eq $Height) "Sheet reported dimensions drift: $ExpectedPath"
    Assert-Contract ([bool]$SheetRecord.image_validation.ok -and [bool]$SheetRecord.image_validation.decoded -and [bool]$SheetRecord.image_validation.nonblank) "Godot-side sheet validation failed: $ExpectedPath"
    Assert-ExpectedSha256 "Godot-side sheet $ExpectedPath" ([string]$SheetRecord.image_validation.sha256) ([string]$Png.sha256)
    Assert-Contract ((Get-ArrayValue $SheetRecord.errors).Count -eq 0 -and (Get-ArrayValue $SheetRecord.image_validation.errors).Count -eq 0) "Sheet report contains errors: $ExpectedPath"
}


function Test-StaticReportContract {
    param([object]$Report, [string[]]$AuthoredRoomIds)
    Assert-Contract ([string]$Report.tool -eq 'environment_fixed_slot_static_check') 'Static slot report tool identity is wrong.'
    Assert-Contract ([bool]$Report.passed) 'Static slot report is not passing.'
    Assert-Contract ([int]$Report.error_count -eq 0 -and (Get-ArrayValue $Report.errors).Count -eq 0) 'Static slot report contains errors.'
    Assert-Contract ([int]$Report.counts.maps -ge 18 -and [int]$Report.counts.archetypes -eq 18) 'Static slot report does not cover at least 18 maps and exactly 18 archetypes.'
    Assert-Contract ([int]$Report.counts.scenarios -eq 55) 'Static slot report does not cover all 55 scenarios.'
    Assert-Contract ([int]$Report.counts.historical_exact_seeds -eq 22) 'Static slot report does not cover all 22 historical exact seeds.'
    $rows = @(Get-ArrayValue $Report.contact_sheet)
    Assert-Contract ($rows.Count -eq 18) "Static contact-sheet manifest must contain 18 rows; found $($rows.Count)."
    $ids = @($rows | ForEach-Object { [string]$_.archetype_id })
    Assert-Contract (@($ids | Where-Object { [string]::IsNullOrWhiteSpace($_) }).Count -eq 0) 'Static contact-sheet manifest contains an empty archetype ID.'
    Assert-StringSetEqual $AuthoredRoomIds $ids 'Static contact-sheet versus authored archetypes'
    $day2 = @($rows | Where-Object { [bool]$_.day2_sample } | ForEach-Object { [string]$_.archetype_id })
    Assert-StringSetEqual $expectedQ008Rooms $day2 'Static day2 sample'
    return [ordered]@{ room_ids = $ids; day2_ids = $day2 }
}


function Get-AuthoredArchetypeIds {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Authored archetype file is missing: $Path" }
    try { $parsed = [IO.File]::ReadAllText($Path) | ConvertFrom-Json }
    catch { throw "Authored archetype JSON is malformed: $Path ($($_.Exception.Message))" }
    $ids = [Collections.Generic.List[string]]::new()
    foreach ($entry in $parsed) {
        $id = [string]$entry.id
        if (-not [string]::IsNullOrWhiteSpace($id)) { [void]$ids.Add($id) }
    }
    Assert-Contract ($ids.Count -eq 18) "Authored archetype file must contain 18 IDs; found $($ids.Count)."
    Assert-StringSetEqual @($ids) @($ids) 'Authored archetypes'
    return @($ids)
}


function Test-Q008Artifacts {
    param([string]$CaptureRoot, [string]$StaticSnapshotPath, [string]$StaticSha)
    $expected = [Collections.Generic.List[string]]::new()
    foreach ($room in $expectedQ008Rooms) {
        [void]$expected.Add("q008_sources/${room}_base.png")
        [void]$expected.Add("q008_sources/${room}_busiest_physical.png")
    }
    [void]$expected.Add('q008_rooms.png')
    [void]$expected.Add('q008_rooms.json')
    [void](Assert-ExactRelativeFileSet $CaptureRoot @($expected))
    $reportPath = Join-Path $CaptureRoot 'q008_rooms.json'
    $report = Read-JsonObject $reportPath
    Assert-Contract ([string]$report.schema -eq 'rw06_1_q008_room_proof/v1') 'Q008 report schema mismatch.'
    Assert-Contract ([bool]$report.passed) 'Q008 report is not passing.'
    Assert-Contract ((Get-ArrayValue $report.failures).Count -eq 0) 'Q008 report contains failures.'
    Assert-Contract ([bool]$report.normal_only) 'Q008 report is not normal-only.'
    Assert-Contract ([string]$report.capture_source -eq 'production_root_viewport_texture' -and -not [bool]$report.source_post_processed -and [bool]$report.sheet_post_processed) 'Q008 capture/source processing authority drifted.'
    Assert-Contract ([int]$report.accepted_source_capture_count -eq 6) 'Q008 report did not accept exactly six source captures.'
    Assert-Contract ((Get-ArrayValue $report.captures).Count -eq 3 -and (Get-ArrayValue $report.capture_attempts).Count -eq 3) 'Q008 report did not complete exactly three rooms/attempts.'
    Assert-Contract (Test-SamePath ([string]$report.source_static_report) $StaticSnapshotPath) 'Q008 report did not consume the evidence-bound static snapshot.'
    Assert-ExpectedSha256 'Q008 static report link' $StaticSha ([string]$report.source_static_report_sha256)
    Assert-StringSetEqual $expectedQ008Rooms @($report.required_archetype_ids | ForEach-Object { [string]$_ }) 'Q008 required rooms'
    $q008GenerationRows = @(Get-ArrayValue $report.generation_identity.captures)
    Assert-Contract ([bool]$report.generation_identity.ok -and (Get-ArrayValue $report.generation_identity.errors).Count -eq 0 -and [string]$report.generation_identity.strategy -eq 'independent_named_seed_per_capture' -and [int]$report.generation_identity.capture_count -eq 6 -and $q008GenerationRows.Count -eq 6) 'Q008 generation identity does not cover six independent captures.'
    Assert-Contract (@($q008GenerationRows | Where-Object { [string]::IsNullOrWhiteSpace([string]$_.generation_identity.identity_key) }).Count -eq 0) 'Q008 generation identity contains an empty key.'
    Assert-StringSetEqual @($q008GenerationRows | ForEach-Object { [string]$_.generation_identity.identity_key }) @($q008GenerationRows | ForEach-Object { [string]$_.generation_identity.identity_key }) 'Q008 generation identity keys'
    $roomIds = [Collections.Generic.List[string]]::new()
    $images = [Collections.Generic.List[object]]::new()
    $q008Captures = @(Get-ArrayValue $report.captures)
    $sourceByKey = @{}
    $sourceGenerationKeys = [Collections.Generic.List[string]]::new()
    for ($captureIndex = 0; $captureIndex -lt $q008Captures.Count; $captureIndex++) {
        $capture = $q008Captures[$captureIndex]
        $room = [string]$capture.archetype_id
        [void]$roomIds.Add($room)
        foreach ($role in @('base', 'busiest_physical')) {
            $path = Join-Path $CaptureRoot ("q008_sources\{0}_{1}.png" -f $room, $role)
            $png = Get-PngEvidence $path $expectedSourceWidth $expectedSourceHeight
            [void]$images.Add($png)
            Assert-CleanCaptureRecord $capture.$role $path 'normal' $png
            [void]$sourceGenerationKeys.Add([string]$capture.$role.generation_identity.identity_key)
            $sourceByKey["${room}|${role}"] = [ordered]@{ path = Normalize-FullPath $path; sha256 = [string]$png.sha256; capture_index = $captureIndex; role_index = if ($role -eq 'base') { 0 } else { 1 } }
        }
        Assert-Contract ((Get-ArrayValue $capture.errors).Count -eq 0) "Q008 room $room contains errors."
    }
    Assert-StringSetEqual $expectedQ008Rooms @($roomIds) 'Q008 captured rooms'
    Assert-StringSetEqual @($q008GenerationRows | ForEach-Object { [string]$_.generation_identity.identity_key }) @($sourceGenerationKeys) 'Q008 aggregate versus source generation identities'
    Assert-Contract (@($images | ForEach-Object { $_.sha256 } | Sort-Object -Unique).Count -eq 6) 'Q008 source captures are not six distinct images.'
    $sheetPath = Join-Path $CaptureRoot 'q008_rooms.png'
    $sheet = Get-PngEvidence $sheetPath 960 360
    Assert-SheetImageValidation $report.sheet $sheetPath $sheet 960 360
    $sheetCells = @(Get-ArrayValue $report.sheet.cells)
    Assert-Contract ($sheetCells.Count -eq 6) 'Q008 sheet does not contain six cells.'
    $cellKeys = [Collections.Generic.List[string]]::new()
    foreach ($cell in $sheetCells) {
        $key = ('{0}|{1}' -f [string]$cell.archetype_id, [string]$cell.capture_role)
        [void]$cellKeys.Add($key)
        Assert-Contract ($sourceByKey.ContainsKey($key)) "Q008 sheet references an unknown source identity: $key"
        $source = $sourceByKey[$key]
        Assert-Contract ([string]$cell.mode -eq 'normal') "Q008 sheet cell mode drifted: $key"
        Assert-Contract (Test-SamePath ([string]$cell.source_path) ([string]$source.path)) "Q008 sheet cell source path drifted: $key"
        Assert-ExpectedSha256 "Q008 sheet cell source $key" ([string]$source.sha256) ([string]$cell.source_sha256)
        Assert-Contract ([int]$cell.rect.x -eq ([int]$source.capture_index * 320) -and [int]$cell.rect.y -eq ([int]$source.role_index * 180) -and [int]$cell.rect.w -eq 320 -and [int]$cell.rect.h -eq 180) "Q008 sheet cell rectangle drifted: $key"
    }
    Assert-StringSetEqual @($sourceByKey.Keys) @($cellKeys) 'Q008 sheet cells versus exact source identities'
    return [ordered]@{ report = [ordered]@{ path = Normalize-FullPath $reportPath; sha256 = Get-Sha256 $reportPath }; sheet = $sheet; sources = @($images); artifact_count = 8 }
}


function Test-AllRoomArtifacts {
    param([string]$CaptureRoot, [string]$StaticSnapshotPath, [string]$StaticSha, [string[]]$RoomIds)
    $expected = [Collections.Generic.List[string]]::new()
    foreach ($room in $RoomIds) {
        [void]$expected.Add("normal/${room}.png")
        [void]$expected.Add("expanded/${room}.png")
    }
    [void]$expected.Add('all_rooms_contact_sheet.png')
    [void]$expected.Add('day2_contact_sheet.png')
    [void]$expected.Add('contact_sheet_report.json')
    [void](Assert-ExactRelativeFileSet $CaptureRoot @($expected))
    $reportPath = Join-Path $CaptureRoot 'contact_sheet_report.json'
    $report = Read-JsonObject $reportPath
    Assert-Contract ([string]$report.schema -eq 'rw06_1_fixed_slot_contact_sheet/v1') 'All-room report schema mismatch.'
    Assert-Contract ([bool]$report.passed) 'All-room report is not passing.'
    Assert-Contract ((Get-ArrayValue $report.failures).Count -eq 0) 'All-room report contains failures.'
    Assert-Contract ([int]$report.room_count -eq 18 -and [int]$report.day2_room_count -eq 3) 'All-room report count mismatch.'
    Assert-Contract ((Get-ArrayValue $report.captures).Count -eq 18 -and (Get-ArrayValue $report.capture_attempts).Count -eq 18) 'All-room report does not contain exactly 18 captures/attempts.'
    Assert-Contract (Test-SamePath ([string]$report.source_static_report) $StaticSnapshotPath) 'All-room report did not consume the evidence-bound static snapshot.'
    Assert-ExpectedSha256 'All-room static report link' $StaticSha ([string]$report.source_static_report_sha256)
    $allGenerationRows = @(Get-ArrayValue $report.generation_identity.captures)
    Assert-Contract ([bool]$report.generation_identity.ok -and (Get-ArrayValue $report.generation_identity.errors).Count -eq 0 -and [string]$report.generation_identity.strategy -eq 'independent_named_seed_per_capture' -and [int]$report.generation_identity.capture_count -eq 18 -and $allGenerationRows.Count -eq 18) 'All-room generation identity does not cover 18 independent captures.'
    Assert-Contract (@($allGenerationRows | Where-Object { [string]::IsNullOrWhiteSpace([string]$_.generation_identity.identity_key) }).Count -eq 0) 'All-room generation identity contains an empty key.'
    Assert-StringSetEqual @($allGenerationRows | ForEach-Object { [string]$_.generation_identity.identity_key }) @($allGenerationRows | ForEach-Object { [string]$_.generation_identity.identity_key }) 'All-room generation identity keys'
    Assert-Contract ([bool]$report.player_view_cleanliness.required -and [bool]$report.player_view_cleanliness.passed) 'All-room report did not prove player-view cleanliness.'
    Assert-Contract ([int]$report.player_view_cleanliness.accepted_source_capture_count -eq 36) 'All-room report did not accept exactly 36 source captures.'
    $capturedIds = [Collections.Generic.List[string]]::new()
    $images = [Collections.Generic.List[object]]::new()
    $allCaptures = @(Get-ArrayValue $report.captures)
    $captureOrder = @{}
    $sourceHashByKey = @{}
    for ($captureIndex = 0; $captureIndex -lt $allCaptures.Count; $captureIndex++) {
        $capture = $allCaptures[$captureIndex]
        $room = [string]$capture.selection.archetype_id
        [void]$capturedIds.Add($room)
        $captureOrder[$room] = $captureIndex
        Assert-Contract ([bool]$capture.ok -and [bool]$capture.player_view_clean -and (Get-ArrayValue $capture.errors).Count -eq 0) "All-room capture failed for $room."
        Assert-Contract ([string]$capture.generation_identity.identity_key -ceq [string]$capture.normal.generation_identity.identity_key -and [string]$capture.generation_identity.identity_key -ceq [string]$capture.expanded.generation_identity.identity_key) "All-room aggregate/mode generation identity drifted for $room."
        foreach ($mode in @('normal', 'expanded')) {
            $path = Join-Path $CaptureRoot ("{0}\{1}.png" -f $mode, $room)
            $png = Get-PngEvidence $path $expectedSourceWidth $expectedSourceHeight
            [void]$images.Add($png)
            $record = $capture.$mode
            Assert-Contract (Test-SamePath ([string]$record.path) $path) "All-room $room/$mode path mismatch."
            Assert-ExpectedSha256 "All-room $room/$mode" ([string]$record.sha256) ([string]$png.sha256)
            Assert-Contract ([string]$record.capture_source -eq 'production_root_viewport_texture' -and -not [bool]$record.post_processed) "All-room $room/$mode is not a raw production capture."
            Assert-Contract ([bool]$record.player_view_cleanliness.ok) "All-room $room/$mode cleanliness failed."
            Assert-Contract ((Get-ArrayValue $record.direct_interaction_overlaps).Count -eq 0) "All-room $room/$mode contains direct overlaps."
            Assert-Contract ((Get-ArrayValue $record.errors).Count -eq 0) "All-room $room/$mode contains errors."
            Assert-SourceEvidenceDetails $record $capture.selection $path $png
            $sourceHashByKey["${room}|${mode}"] = [string]$png.sha256
        }
        Assert-Contract ([string]$sourceHashByKey["${room}|normal"] -ine [string]$sourceHashByKey["${room}|expanded"]) "All-room normal and expanded captures are byte-identical for $room."
    }
    Assert-StringSetEqual $RoomIds @($capturedIds) 'All-room captured rooms'
    Assert-StringSetEqual @($allGenerationRows | ForEach-Object { [string]$_.generation_identity.identity_key }) @($allCaptures | ForEach-Object { [string]$_.generation_identity.identity_key }) 'All-room aggregate versus capture generation identities'
    Assert-Contract (@($images | ForEach-Object { $_.sha256 } | Sort-Object -Unique).Count -eq 36) 'All-room source captures are not 36 distinct images.'
    $allSheetPath = Join-Path $CaptureRoot 'all_rooms_contact_sheet.png'
    $day2SheetPath = Join-Path $CaptureRoot 'day2_contact_sheet.png'
    $allSheet = Get-PngEvidence $allSheetPath 1920 1080
    $day2Sheet = Get-PngEvidence $day2SheetPath 640 540
    Assert-SheetImageValidation $report.all_rooms_sheet $allSheetPath $allSheet 1920 1080
    $allCells = @(Get-ArrayValue $report.all_rooms_sheet.cells)
    Assert-Contract ($allCells.Count -eq 36) 'All-room sheet does not contain 36 cells.'
    $allCellKeys = [Collections.Generic.List[string]]::new()
    foreach ($cell in $allCells) {
        $room = [string]$cell.archetype_id
        $mode = [string]$cell.mode
        $key = "${room}|${mode}"
        [void]$allCellKeys.Add($key)
        Assert-Contract ($sourceHashByKey.ContainsKey($key) -and $captureOrder.ContainsKey($room)) "All-room sheet references an unknown source identity: $key"
        $index = [int]$captureOrder[$room]
        $modeIndex = if ($mode -eq 'normal') { 0 } elseif ($mode -eq 'expanded') { 1 } else { -1 }
        Assert-Contract ($modeIndex -ge 0 -and [int]$cell.rect.x -eq (($index % 3) * 640 + $modeIndex * 320) -and [int]$cell.rect.y -eq ([Math]::Floor($index / 3) * 180) -and [int]$cell.rect.w -eq 320 -and [int]$cell.rect.h -eq 180) "All-room sheet cell rectangle drifted: $key"
    }
    Assert-StringSetEqual @($sourceHashByKey.Keys) @($allCellKeys) 'All-room sheet cells versus exact source identities'
    Assert-SheetImageValidation $report.day2_sheet $day2SheetPath $day2Sheet 640 540
    $day2Cells = @(Get-ArrayValue $report.day2_sheet.cells)
    Assert-Contract ($day2Cells.Count -eq 6) 'Day2 sheet does not contain six cells.'
    $day2RoomsInOrder = @($allCaptures | Where-Object { $expectedQ008Rooms -contains [string]$_.selection.archetype_id } | ForEach-Object { [string]$_.selection.archetype_id })
    Assert-StringSetEqual $expectedQ008Rooms $day2RoomsInOrder 'Day2 capture order source rooms'
    $day2Keys = [Collections.Generic.List[string]]::new()
    for ($day2Index = 0; $day2Index -lt $day2RoomsInOrder.Count; $day2Index++) {
        $room = $day2RoomsInOrder[$day2Index]
        foreach ($mode in @('normal', 'expanded')) { [void]$day2Keys.Add("${room}|${mode}") }
    }
    $actualDay2Keys = [Collections.Generic.List[string]]::new()
    foreach ($cell in $day2Cells) {
        $room = [string]$cell.archetype_id
        $mode = [string]$cell.mode
        $key = "${room}|${mode}"
        [void]$actualDay2Keys.Add($key)
        $day2Index = [Array]::IndexOf([string[]]$day2RoomsInOrder, $room)
        $modeIndex = if ($mode -eq 'normal') { 0 } elseif ($mode -eq 'expanded') { 1 } else { -1 }
        Assert-Contract ($sourceHashByKey.ContainsKey($key) -and $day2Index -ge 0 -and $modeIndex -ge 0 -and [int]$cell.rect.x -eq ($modeIndex * 320) -and [int]$cell.rect.y -eq ($day2Index * 180) -and [int]$cell.rect.w -eq 320 -and [int]$cell.rect.h -eq 180) "Day2 sheet cell identity/rectangle drifted: $key"
    }
    Assert-StringSetEqual @($day2Keys) @($actualDay2Keys) 'Day2 sheet cells versus exact source identities'
    return [ordered]@{ report = [ordered]@{ path = Normalize-FullPath $reportPath; sha256 = Get-Sha256 $reportPath }; all_rooms_sheet = $allSheet; day2_sheet = $day2Sheet; sources = @($images); artifact_count = 39 }
}


function Remove-OwnedDirectory {
    param([string]$Path, [string]$RequiredParent)
    if (-not (Test-Path -LiteralPath $Path)) { return }
    $target = Assert-StrictChildPath $Path $RequiredParent
    [void](Assert-NoReparseAncestors $target $RequiredParent)
    foreach ($item in @(Get-ChildItem -LiteralPath $target -Force -Recurse -ErrorAction SilentlyContinue)) {
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "Refusing cleanup through reparse point: $($item.FullName)" }
    }
    $rootItem = Get-Item -LiteralPath $target -Force
    if (($rootItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "Refusing cleanup of reparse point: $target" }
    Remove-Item -LiteralPath $target -Recurse -Force
}


function Complete-PhaseReservationCleanup {
    param(
        [bool]$LeaseOwned,
        [string]$LeasePath,
        [string]$ProfileRoot,
        [string]$PhaseRoot,
        [object]$LauncherIdentity,
        [string]$CandidateRoot,
        [string]$CandidateCommit,
        [string]$CandidateTree,
        [string]$PhaseName,
        [bool]$CensusCompleted,
        [object[]]$OwnedResidualIdentities,
        [AllowEmptyString()][string]$CensusError = ''
    )
    $residualIdentities = @($OwnedResidualIdentities)
    $releaseAuthorized = $CensusCompleted -and [string]::IsNullOrWhiteSpace($CensusError) -and $residualIdentities.Count -eq 0
    if (-not $releaseAuthorized) {
        if ($LeaseOwned) { Assert-OwnedLease $LeasePath $LauncherIdentity $CandidateRoot $CandidateCommit $CandidateTree $PhaseName }
        $leaseRetained = $LeaseOwned -and (Test-Path -LiteralPath $LeasePath -PathType Leaf)
        $profileRetained = Test-Path -LiteralPath $ProfileRoot -PathType Container
        return [ordered]@{
            census_completed = $CensusCompleted
            census_error = $CensusError
            owned_residual_identities = @($residualIdentities)
            owned_residual_process_ids = @($residualIdentities | ForEach-Object { [int]$_.pid } | Sort-Object -Unique)
            cleanup_authorized = $false
            lease_owned = $LeaseOwned
            lease_released = $false
            lease_retained = $leaseRetained
            profile_removed = $false
            profile_retained = $profileRetained
            reservation_retained_until_launcher_finalization = $leaseRetained -and $profileRetained
        }
    }

    if (Test-Path -LiteralPath $ProfileRoot) {
        Remove-OwnedDirectory $ProfileRoot $PhaseRoot
        Assert-Contract (-not (Test-Path -LiteralPath $ProfileRoot)) "Phase $PhaseName profile survived authorized cleanup."
    }
    if ($LeaseOwned) {
        Assert-OwnedLease $LeasePath $LauncherIdentity $CandidateRoot $CandidateCommit $CandidateTree $PhaseName
        Remove-Item -LiteralPath $LeasePath -Force
        Assert-Contract (-not (Test-Path -LiteralPath $LeasePath)) "Phase $PhaseName lease survived authorized cleanup."
    }
    return [ordered]@{
        census_completed = $true
        census_error = ''
        owned_residual_identities = @()
        owned_residual_process_ids = @()
        cleanup_authorized = $true
        lease_owned = $LeaseOwned
        lease_released = $LeaseOwned
        lease_retained = $false
        profile_removed = $true
        profile_retained = $false
        reservation_retained_until_launcher_finalization = $false
    }
}


function Write-VerifiedJsonSeal {
    param([object]$Value, [string]$JsonPath, [string]$HashPath, [string]$Label, [int]$Depth = 16)
    [void](Assert-NoReparseAncestors (Split-Path -Parent $JsonPath) $EvidenceRoot)
    $jsonTemporary = $JsonPath + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
    $hashTemporary = $HashPath + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
    try {
        $jsonText = ($Value | ConvertTo-Json -Depth $Depth) + "`n"
        [IO.File]::WriteAllText($jsonTemporary, $jsonText)
        Move-Item -LiteralPath $jsonTemporary -Destination $JsonPath -Force
        $sha = Get-Sha256 $JsonPath
        [IO.File]::WriteAllText($hashTemporary, ($sha + '  ' + [IO.Path]::GetFileName($JsonPath) + "`n"))
        Move-Item -LiteralPath $hashTemporary -Destination $HashPath -Force
        Assert-ExpectedSha256 $Label $sha (Get-Sha256 $JsonPath)
        $expectedHashText = $sha + '  ' + [IO.Path]::GetFileName($JsonPath)
        Assert-Contract ([IO.File]::ReadAllText($HashPath).Trim() -ceq $expectedHashText) "$Label hash receipt content drifted."
        return [ordered]@{ path = Normalize-FullPath $JsonPath; sha256 = $sha; hash_path = Normalize-FullPath $HashPath; verified = $true }
    }
    finally {
        foreach ($temporary in @($jsonTemporary, $hashTemporary)) { if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force } }
    }
}


function Get-OwnerReviewSidecars {
    param([string]$DestinationPath, [scriptblock]$BeforeEnumerationForTest = $null)
    $directory = Split-Path -Parent $DestinationPath
    if (-not (Test-Path -LiteralPath $directory -PathType Container -ErrorAction Stop)) { return @() }
    if ($null -ne $BeforeEnumerationForTest) { & $BeforeEnumerationForTest $directory }
    return @(
        Get-ChildItem -LiteralPath $directory -Force -ErrorAction Stop |
            Where-Object { $_.Name -match '^\.q008_rooms\.(?:prepublish|publish|rollback|restore)\.' } |
            Sort-Object FullName
    )
}


function Assert-NoOwnerReviewSidecars {
    param([string]$DestinationPath, [string]$Label)
    $sidecars = @(Get-OwnerReviewSidecars $DestinationPath)
    Assert-Contract ($sidecars.Count -eq 0) "$Label left owned owner-review sidecars: $(@($sidecars | ForEach-Object { $_.FullName }) -join ', ')"
}


function Move-OwnerReviewSidecarToPublicationRoot {
    param([object]$Plan, [string]$SidecarPath, [string]$Kind, [AllowEmptyString()][string]$ExpectedSha256 = '')
    Assert-Contract (Test-Path -LiteralPath $SidecarPath -PathType Leaf) "Retained owner-review sidecar is missing: $SidecarPath"
    $publicationRoot = Normalize-FullPath ([string]$Plan.publication_root)
    $planEvidenceRoot = Normalize-FullPath ([string]$Plan.evidence_root)
    $destinationRoot = Normalize-FullPath ([string]$Plan.destination_root)
    [void](Assert-DisjointRoots $destinationRoot $planEvidenceRoot 'Owner-review destination/evidence')
    Assert-Contract (Test-Path -LiteralPath $publicationRoot -PathType Container) 'Owner-review publication retention root is missing.'
    [void](Assert-StrictChildPath $publicationRoot $planEvidenceRoot)
    [void](Assert-PathOutsideRoot $publicationRoot $destinationRoot)
    [void](Assert-NoReparseAncestors $publicationRoot $planEvidenceRoot)
    Assert-Contract ([IO.Path]::GetPathRoot($publicationRoot) -ieq [IO.Path]::GetPathRoot((Normalize-FullPath $SidecarPath))) 'Owner-review sidecar retention must stay on the same volume for an atomic move.'
    $extension = [IO.Path]::GetExtension($SidecarPath)
    if ([string]::IsNullOrWhiteSpace($extension)) { $extension = '.bin' }
    $retainedPath = Join-Path $publicationRoot ('r.' + [guid]::NewGuid().ToString('N') + $extension)
    [void](Assert-StrictChildPath $retainedPath $publicationRoot)
    [void](Assert-StrictChildPath $retainedPath $planEvidenceRoot)
    [void](Assert-PathOutsideRoot $retainedPath $destinationRoot)
    [IO.File]::Move($SidecarPath, $retainedPath)
    [void](Assert-PathOutsideRoot $retainedPath $destinationRoot)
    $sha = Get-Sha256 $retainedPath
    if (-not [string]::IsNullOrWhiteSpace($ExpectedSha256)) { Assert-ExpectedSha256 "Retained owner-review ${Kind}" $ExpectedSha256 $sha }
    return [ordered]@{ kind = $Kind; path = Normalize-FullPath $retainedPath; sha256 = $sha; length = [long](Get-Item -LiteralPath $retainedPath).Length; confined_to_publication_root = $true }
}


function New-OwnerReviewPublicationPlan {
    param(
        [string]$SourcePath,
        [string]$PublicationRoot,
        [string]$DestinationPathOverride = '',
        [string]$DestinationRootOverride = '',
        [string]$EvidenceRootOverride = ''
    )
    $destination = Normalize-FullPath $(if ([string]::IsNullOrWhiteSpace($DestinationPathOverride)) { $primaryOwnerReviewPath } else { $DestinationPathOverride })
    $primaryRoot = Normalize-FullPath $(if ([string]::IsNullOrWhiteSpace($DestinationRootOverride)) { 'D:\Projects\Beat-The-House' } else { $DestinationRootOverride })
    $planEvidenceRoot = Normalize-FullPath $(if ([string]::IsNullOrWhiteSpace($EvidenceRootOverride)) { $EvidenceRoot } else { $EvidenceRootOverride })
    $normalizedPublicationRoot = Normalize-FullPath $PublicationRoot
    [void](Assert-DisjointRoots $primaryRoot $planEvidenceRoot 'Owner-review plan destination/evidence')
    [void](Assert-StrictChildPath $destination $primaryRoot)
    [void](Assert-StrictChildPath $normalizedPublicationRoot $planEvidenceRoot)
    [void](Assert-PathOutsideRoot $normalizedPublicationRoot $primaryRoot)
    Assert-Contract (Test-Path -LiteralPath $planEvidenceRoot -PathType Container) 'Owner-review plan evidence root is missing.'
    [void](Assert-NoReparseAncestors $planEvidenceRoot $planEvidenceRoot)
    $source = Get-PngEvidence $SourcePath 960 360
    $destinationDirectory = Split-Path -Parent $destination
    [void](Assert-NoReparseAncestors $destinationDirectory $primaryRoot)
    New-Item -ItemType Directory -Force -Path $destinationDirectory | Out-Null
    [void](Assert-NoReparseAncestors $destinationDirectory $primaryRoot)
    Assert-NoOwnerReviewSidecars $destination 'Owner-review publication preflight'
    New-Item -ItemType Directory -Path $normalizedPublicationRoot | Out-Null
    [void](Assert-NoReparseAncestors $normalizedPublicationRoot $planEvidenceRoot)
    $candidatePath = Join-Path $normalizedPublicationRoot 'candidate_q008_rooms.png'
    [IO.File]::Copy($SourcePath, $candidatePath, $false)
    $candidate = Get-PngEvidence $candidatePath 960 360
    Assert-ExpectedSha256 'Publication candidate' ([string]$source.sha256) ([string]$candidate.sha256)
    $previousExists = Test-Path -LiteralPath $destination -PathType Leaf
    $previousSha = ''
    $backupPath = ''
    if ($previousExists) {
        [void](Assert-NoReparseAncestors $destination $primaryRoot)
        $previousSha = Get-Sha256 $destination
        $backupPath = Join-Path $normalizedPublicationRoot 'previous_owner_review.backup'
        [IO.File]::Copy($destination, $backupPath, $false)
        Assert-ExpectedSha256 'Owner-review rollback backup' $previousSha (Get-Sha256 $backupPath)
    }
    return [ordered]@{
        source = Normalize-FullPath $SourcePath
        source_sha256 = [string]$source.sha256
        candidate_path = Normalize-FullPath $candidatePath
        candidate_sha256 = [string]$candidate.sha256
        destination = $destination
        destination_root = $primaryRoot
        evidence_root = $planEvidenceRoot
        publication_root = $normalizedPublicationRoot
        previous_exists = $previousExists
        previous_sha256 = $previousSha
        backup_path = $backupPath
        published = $false
    }
}


function Publish-OwnerReviewAfterSeal {
    param(
        [object]$Plan,
        [object]$EvidenceSeal,
        [scriptblock]$BeforeCandidateCommitForTest = $null,
        [scriptblock]$AfterPriorQuarantineForTest = $null
    )
    $destinationRoot = Normalize-FullPath ([string]$Plan.destination_root)
    $planEvidenceRoot = Normalize-FullPath ([string]$Plan.evidence_root)
    [void](Assert-DisjointRoots $destinationRoot $planEvidenceRoot 'Owner-review destination/evidence')
    [void](Assert-StrictChildPath ([string]$Plan.publication_root) $planEvidenceRoot)
    [void](Assert-StrictChildPath ([string]$Plan.candidate_path) $planEvidenceRoot)
    [void](Assert-PathOutsideRoot ([string]$Plan.publication_root) $destinationRoot)
    [void](Assert-PathOutsideRoot ([string]$Plan.candidate_path) $destinationRoot)
    $evidenceSealPath = Assert-StrictChildPath ([string]$EvidenceSeal.path) $planEvidenceRoot
    $evidenceSealHashPath = Assert-StrictChildPath ([string]$EvidenceSeal.hash_path) $planEvidenceRoot
    [void](Assert-PathOutsideRoot $evidenceSealPath $destinationRoot)
    [void](Assert-PathOutsideRoot $evidenceSealHashPath $destinationRoot)
    Assert-Contract ($evidenceSealPath -ine $evidenceSealHashPath) 'Pre-publication evidence seal and hash receipt paths must be distinct.'
    [void](Assert-NoReparseAncestors $evidenceSealPath $planEvidenceRoot)
    [void](Assert-NoReparseAncestors $evidenceSealHashPath $planEvidenceRoot)
    Assert-Contract (Test-Path -LiteralPath $evidenceSealPath -PathType Leaf) 'Pre-publication evidence seal is missing or not a regular file.'
    Assert-Contract (Test-Path -LiteralPath $evidenceSealHashPath -PathType Leaf) 'Pre-publication evidence seal hash receipt is missing or not a regular file.'
    Assert-ExpectedSha256 'Pre-publication evidence seal' ([string]$EvidenceSeal.sha256) (Get-Sha256 $evidenceSealPath)
    $expectedEvidenceSealReceipt = ([string]$EvidenceSeal.sha256).ToUpperInvariant() + '  ' + [IO.Path]::GetFileName($evidenceSealPath)
    Assert-Contract ([IO.File]::ReadAllText($evidenceSealHashPath).Trim() -ceq $expectedEvidenceSealReceipt) 'Pre-publication evidence seal hash receipt content drifted.'
    $candidate = Get-PngEvidence ([string]$Plan.candidate_path) 960 360
    Assert-ExpectedSha256 'Pre-publication candidate' ([string]$Plan.candidate_sha256) ([string]$candidate.sha256)
    $destination = [string]$Plan.destination
    $destinationDirectory = Split-Path -Parent $destination
    [void](Assert-NoReparseAncestors $destinationDirectory $destinationRoot)
    $priorQuarantine = ''
    $temporary = ''
    $candidateCommitted = $false
    try {
        if ([bool]$Plan.previous_exists) {
            Assert-Contract (Test-Path -LiteralPath $destination -PathType Leaf) 'Owner-review destination disappeared or became non-file before publication; external state was preserved.'
            [void](Assert-NoReparseAncestors $destination $destinationRoot)
            $priorQuarantine = Join-Path $destinationDirectory ('.q008_rooms.prepublish.' + $PID + '.' + [guid]::NewGuid().ToString('N') + '.quarantine')
            [IO.File]::Move($destination, $priorQuarantine)
            $Plan['publication_prior_quarantine_path'] = $priorQuarantine
            if ($null -ne $AfterPriorQuarantineForTest) { & $AfterPriorQuarantineForTest $destination }
            $priorQuarantineSha = Get-Sha256 $priorQuarantine
            Assert-ExpectedSha256 'Atomically quarantined prior owner-review image' ([string]$Plan.previous_sha256) $priorQuarantineSha
        }
        else { Assert-Contract (-not (Test-Path -LiteralPath $destination)) 'Owner-review destination appeared before publication; external state was preserved.' }

        $temporary = Join-Path $destinationDirectory ('.q008_rooms.publish.' + $PID + '.' + [guid]::NewGuid().ToString('N') + '.tmp')
        [IO.File]::Copy([string]$Plan.candidate_path, $temporary, $false)
        Assert-ExpectedSha256 'Owner-review prepared publication' ([string]$Plan.candidate_sha256) (Get-Sha256 $temporary)
        [void](Get-PngEvidence $temporary 960 360)
        if ($null -ne $BeforeCandidateCommitForTest) { & $BeforeCandidateCommitForTest $destination }
        [IO.File]::Move($temporary, $destination)
        $temporary = ''
        $candidateCommitted = $true
        $Plan['published'] = $true
        $published = Get-PngEvidence $destination 960 360
        Assert-ExpectedSha256 'Owner-review published destination' ([string]$Plan.candidate_sha256) ([string]$published.sha256)
        if (-not [string]::IsNullOrWhiteSpace($priorQuarantine)) {
            Assert-ExpectedSha256 'Pre-publication quarantine before exact cleanup' ([string]$Plan.previous_sha256) (Get-Sha256 $priorQuarantine)
            [IO.File]::Delete($priorQuarantine)
            Assert-Contract (-not (Test-Path -LiteralPath $priorQuarantine)) 'Exact prior-publication quarantine survived cleanup.'
            $Plan['publication_prior_quarantine_path'] = ''
            $priorQuarantine = ''
        }
        return [ordered]@{
            source = [string]$Plan.source
            destination = $destination
            sha256 = [string]$published.sha256
            byte_identical = $true
            evidence_seal_sha256 = [string]$EvidenceSeal.sha256
            published_after_complete_evidence_seal = $true
        }
    }
    catch {
        $publicationError = $_.Exception.Message
        if (-not [string]::IsNullOrWhiteSpace($priorQuarantine) -and (Test-Path -LiteralPath $priorQuarantine -PathType Leaf)) {
            if (-not $candidateCommitted) {
                try {
                    [IO.File]::Move($priorQuarantine, $destination)
                    $Plan['publication_prior_quarantine_path'] = ''
                    $priorQuarantine = ''
                }
                catch {
                    $Plan['publication_abort_restore_error'] = $_.Exception.Message
                    $Plan['publication_abort_retained_prior'] = Move-OwnerReviewSidecarToPublicationRoot $Plan $priorQuarantine 'prepublish_prior_or_external'
                    $Plan['publication_prior_quarantine_path'] = ''
                    $priorQuarantine = ''
                }
            }
            else {
                try {
                    Assert-ExpectedSha256 'Failed-publication prior quarantine cleanup' ([string]$Plan.previous_sha256) (Get-Sha256 $priorQuarantine)
                    [IO.File]::Delete($priorQuarantine)
                    $Plan['publication_prior_quarantine_path'] = ''
                    $priorQuarantine = ''
                }
                catch {
                    $Plan['publication_abort_retained_prior'] = Move-OwnerReviewSidecarToPublicationRoot $Plan $priorQuarantine 'prepublish_prior_cleanup' ([string]$Plan.previous_sha256)
                    $Plan['publication_prior_quarantine_path'] = ''
                    $priorQuarantine = ''
                }
            }
        }
        throw "Owner-review publication transaction failed; no-overwrite restore preserved concurrent destination state and restored or retained quarantined prior bytes: $publicationError"
    }
    finally {
        if (-not [string]::IsNullOrWhiteSpace($temporary) -and (Test-Path -LiteralPath $temporary -PathType Leaf)) {
            $temporarySha = Get-Sha256 $temporary
            if ($temporarySha -ieq [string]$Plan.candidate_sha256) {
                try { [IO.File]::Delete($temporary) }
                catch { $Plan['publication_abort_retained_candidate_temporary'] = Move-OwnerReviewSidecarToPublicationRoot $Plan $temporary 'publish_candidate_temporary' ([string]$Plan.candidate_sha256) }
            }
            else { $Plan['publication_abort_retained_external_temporary'] = Move-OwnerReviewSidecarToPublicationRoot $Plan $temporary 'publish_temporary_external' }
        }
        Assert-NoOwnerReviewSidecars $destination 'Owner-review publication transaction'
    }
}


function Restore-OwnerReviewPublication {
    param([object]$Plan, [scriptblock]$AfterQuarantineForTest = $null)
    if ($null -eq $Plan -or -not [bool]$Plan.published) { return [ordered]@{ required = $false; restored = $true } }
    $destination = [string]$Plan.destination
    $destinationRoot = [string]$Plan.destination_root
    $retentionRoot = [string]$Plan.publication_root
    Assert-Contract (-not [string]::IsNullOrWhiteSpace($destinationRoot)) 'Owner-review rollback destination root is missing.'
    Assert-Contract (-not [string]::IsNullOrWhiteSpace($retentionRoot)) 'Owner-review rollback retention root is missing.'
    $destinationDirectory = Split-Path -Parent $destination
    [void](Assert-NoReparseAncestors $destinationDirectory $destinationRoot)
    [void](Assert-NoReparseAncestors $retentionRoot $retentionRoot)

    if (-not (Test-Path -LiteralPath $destination -PathType Leaf)) {
        $Plan['published'] = $false
        $result = [ordered]@{
            required = $true; restored = $true; previous_exists = [bool]$Plan.previous_exists
            external_deletion_preserved = -not (Test-Path -LiteralPath $destination)
            external_non_file_preserved = Test-Path -LiteralPath $destination
        }
        Assert-NoOwnerReviewSidecars $destination 'Owner-review rollback disappearance path'
        return $result
    }
    try { [void](Assert-NoReparseAncestors $destination $destinationRoot) }
    catch {
        $Plan['published'] = $false
        $result = [ordered]@{ required = $true; restored = $true; previous_exists = [bool]$Plan.previous_exists; external_reparse_preserved = $true; error = $_.Exception.Message }
        Assert-NoOwnerReviewSidecars $destination 'Owner-review rollback reparse path'
        return $result
    }

    $quarantinePath = Join-Path $destinationDirectory ('.q008_rooms.rollback.' + $PID + '.' + [guid]::NewGuid().ToString('N') + '.quarantine')
    try { [IO.File]::Move($destination, $quarantinePath) }
    catch {
        if (-not (Test-Path -LiteralPath $destination -PathType Leaf)) {
            $Plan['published'] = $false
            $result = [ordered]@{
                required = $true; restored = $true; previous_exists = [bool]$Plan.previous_exists
                external_deletion_preserved = -not (Test-Path -LiteralPath $destination)
                external_non_file_preserved = Test-Path -LiteralPath $destination
                quarantine_race_observed = $true
            }
            Assert-NoOwnerReviewSidecars $destination 'Owner-review rollback quarantine-race path'
            return $result
        }
        throw "Could not atomically quarantine the current owner-review destination: $($_.Exception.Message)"
    }
    $Plan['published'] = $false
    $restoreTemporary = ''
    try {
        if ($null -ne $AfterQuarantineForTest) { & $AfterQuarantineForTest $destination }
        $quarantineSha = Get-Sha256 $quarantinePath

        if ($quarantineSha -ine [string]$Plan.candidate_sha256) {
            try {
                [IO.File]::Move($quarantinePath, $destination)
                $quarantinePath = ''
                return [ordered]@{
                    required = $true; restored = $true; previous_exists = [bool]$Plan.previous_exists
                    external_replacement_restored = $true; external_sha256 = $quarantineSha
                }
            }
            catch {
                $restoreError = $_.Exception.Message
                $retainedExternal = Move-OwnerReviewSidecarToPublicationRoot $Plan $quarantinePath 'rollback_external' $quarantineSha
                $quarantinePath = ''
                return [ordered]@{
                    required = $true; restored = $true; previous_exists = [bool]$Plan.previous_exists
                    external_replacement_preserved = $true; external_sha256 = $quarantineSha
                    quarantined_external = $retainedExternal; quarantine_restore_error = $restoreError
                }
            }
        }

        $retainedCandidate = Move-OwnerReviewSidecarToPublicationRoot $Plan $quarantinePath 'rollback_published_candidate' ([string]$Plan.candidate_sha256)
        $quarantinePath = ''
        if (-not [bool]$Plan.previous_exists) {
            return [ordered]@{
                required = $true; restored = $true; previous_exists = $false
                published_candidate_quarantined = $true; published_candidate_retained = $retainedCandidate
                published_candidate_retained_path = [string]$retainedCandidate.path
                external_destination_preserved = Test-Path -LiteralPath $destination
            }
        }

        Assert-ExpectedSha256 'Owner-review rollback backup' ([string]$Plan.previous_sha256) (Get-Sha256 ([string]$Plan.backup_path))
        $restoreTemporary = Join-Path $destinationDirectory ('.q008_rooms.restore.' + $PID + '.' + [guid]::NewGuid().ToString('N') + '.tmp')
        [IO.File]::Copy([string]$Plan.backup_path, $restoreTemporary, $false)
        Assert-ExpectedSha256 'Owner-review rollback prepared bytes' ([string]$Plan.previous_sha256) (Get-Sha256 $restoreTemporary)
        try {
            [IO.File]::Move($restoreTemporary, $destination)
            $restoreTemporary = ''
            return [ordered]@{
                required = $true; restored = $true; previous_exists = $true; previous_restored = $true
                previous_sha256 = [string]$Plan.previous_sha256
                published_candidate_quarantined = $true; published_candidate_retained = $retainedCandidate
                published_candidate_retained_path = [string]$retainedCandidate.path
            }
        }
        catch {
            $restoreError = $_.Exception.Message
            $retainedPrevious = Move-OwnerReviewSidecarToPublicationRoot $Plan $restoreTemporary 'rollback_unpublished_previous' ([string]$Plan.previous_sha256)
            $restoreTemporary = ''
            return [ordered]@{
                required = $true; restored = $true; previous_exists = $true; previous_restored = $false
                previous_sha256 = [string]$Plan.previous_sha256; unpublished_previous_retained = $retainedPrevious
                unpublished_previous_retained_path = [string]$retainedPrevious.path
                published_candidate_quarantined = $true; published_candidate_retained = $retainedCandidate
                published_candidate_retained_path = [string]$retainedCandidate.path
                external_destination_preserved = $true; previous_restore_error = $restoreError
            }
        }
    }
    catch {
        $rollbackError = $_.Exception.Message
        if (-not [string]::IsNullOrWhiteSpace($quarantinePath) -and (Test-Path -LiteralPath $quarantinePath -PathType Leaf)) {
            $Plan['rollback_abort_retained_quarantine'] = Move-OwnerReviewSidecarToPublicationRoot $Plan $quarantinePath 'rollback_abort_quarantine'
            $quarantinePath = ''
        }
        if (-not [string]::IsNullOrWhiteSpace($restoreTemporary) -and (Test-Path -LiteralPath $restoreTemporary -PathType Leaf)) {
            $Plan['rollback_abort_retained_previous'] = Move-OwnerReviewSidecarToPublicationRoot $Plan $restoreTemporary 'rollback_abort_previous'
            $restoreTemporary = ''
        }
        throw "Owner-review rollback failed after confining all owned sidecars (destination=$destination retention=$retentionRoot): $rollbackError"
    }
    finally {
        Assert-NoOwnerReviewSidecars $destination 'Owner-review rollback transaction'
    }
}


function Get-ArtifactManifest {
    param([string]$Root)
    $rootFull = Normalize-FullPath $Root
    [void](Assert-NoReparseAncestors $rootFull $rootFull)
    $items = [Collections.Generic.List[object]]::new()
    $children = @(Get-ChildItem -LiteralPath $rootFull -Force -Recurse | Sort-Object FullName)
    foreach ($child in $children) {
        if (($child.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "Evidence artifact tree contains a reparse point: $($child.FullName)" }
    }
    foreach ($file in @($children | Where-Object { -not $_.PSIsContainer })) {
        if ($file.Name -in @('manifest.json', 'manifest.sha256', 'evidence_seal.json', 'evidence_seal.sha256', 'publication_receipt.json', 'publication_receipt.sha256')) { continue }
        [void]$items.Add([ordered]@{ path = Get-RelativePathUnderRoot $rootFull $file.FullName; length = [long]$file.Length; sha256 = Get-Sha256 $file.FullName })
    }
    return @($items)
}


function Assert-RunInputs {
    param(
        [string]$StaticOriginal,
        [string]$StaticSnapshot,
        [bool]$CacheOwnershipAuthorized
    )
    $candidate = Get-ExactCandidateIdentity $projectRoot $ExpectedCommit $ExpectedTree
    Assert-Contract (Test-SamePath $GodotPath $canonicalGodotPath) 'Visual capture must use the canonical Godot 4.6 console executable.'
    Assert-Contract (Test-SamePath $PythonPath $canonicalPythonPath) 'Visual capture must use the release-pinned canonical Python executable.'
    Assert-Contract ($ExpectedPythonSha256 -ieq $canonicalPythonSha256) 'Visual capture Python expected SHA-256 is not the release-pinned value.'
    Assert-ExpectedSha256 'Canonical Godot binary' $ExpectedGodotSha256 (Get-Sha256 $GodotPath)
    Assert-ExpectedSha256 'Canonical Godot GUI binary' $ExpectedGodotGuiSha256 (Get-Sha256 $canonicalGodotGuiPath)
    Assert-ExpectedSha256 'Canonical Python binary' $ExpectedPythonSha256 (Get-Sha256 $PythonPath)
    Assert-ExpectedSha256 'Launcher' $ExpectedLauncherSha256 (Get-Sha256 $PSCommandPath)
    $capturePath = Join-Path $projectRoot ($captureRelativePath.Replace('/', '\'))
    Assert-ExpectedSha256 'Capture script' $ExpectedCaptureScriptSha256 (Get-Sha256 $capturePath)
    Assert-ExpectedSha256 'Static report original' $ExpectedStaticReportSha256 (Get-Sha256 $StaticOriginal)
    Assert-ExpectedSha256 'Static report snapshot' $ExpectedStaticReportSha256 (Get-Sha256 $StaticSnapshot)
    if ((Test-Path -LiteralPath $projectCacheRoot) -and -not $CacheOwnershipAuthorized) {
        throw 'A pre-existing or unowned project .godot cache exists; visual evidence refuses to borrow or delete it.'
    }
    return $candidate
}


function Invoke-WindowedCapturePhase {
    param(
        [string]$Name,
        [string]$ModeSwitch,
        [string]$PhaseRoot,
        [string]$StaticOriginal,
        [string]$StaticSnapshot,
        [bool]$CacheOwnershipAuthorized,
        [object]$LauncherIdentity
    )
    New-Item -ItemType Directory -Force -Path $PhaseRoot | Out-Null
    $captureRoot = Join-Path $PhaseRoot 'capture'
    $profileRoot = Join-Path $PhaseRoot 'profile'
    if ((Test-Path -LiteralPath $captureRoot) -or (Test-Path -LiteralPath $profileRoot)) { throw "Phase $Name has stale capture/profile artifacts." }
    $appData = Join-Path $profileRoot 'AppData\Roaming'
    $localAppData = Join-Path $profileRoot 'AppData\Local'
    $xdgData = Join-Path $profileRoot 'xdg\data'
    $xdgCache = Join-Path $profileRoot 'xdg\cache'
    $xdgConfig = Join-Path $profileRoot 'xdg\config'
    $userData = Join-Path $appData 'Godot\app_userdata\Beat the House'
    foreach ($path in @($captureRoot, $appData, $localAppData, $xdgData, $xdgCache, $xdgConfig)) { New-Item -ItemType Directory -Force -Path $path | Out-Null }
    $stdoutPath = Join-Path $PhaseRoot 'stdout.log'
    $stderrPath = Join-Path $PhaseRoot 'stderr.log'
    $godotLogPath = Join-Path $PhaseRoot 'godot.log'
    foreach ($path in @($stdoutPath, $stderrPath, $godotLogPath)) { [IO.File]::WriteAllText($path, '') }
    $arguments = @(
        '--verbose', '--disable-crash-handler',
        '--audio-driver', 'Dummy',
        '--path', $projectRoot,
        '--log-file', $godotLogPath,
        '--script', $captureScriptPath,
        '--',
        ("--out={0}" -f $captureRoot),
        $ModeSwitch,
        ("--rw06-1-static-report={0}" -f $StaticSnapshot)
    )
    Assert-Contract ($arguments -notcontains '--headless') "Phase $Name is not windowed."
    $childEnvironment = @{
        APPDATA = $appData
        LOCALAPPDATA = $localAppData
        XDG_DATA_HOME = $xdgData
        XDG_CACHE_HOME = $xdgCache
        XDG_CONFIG_HOME = $xdgConfig
    }
    $leasePath = Join-Path $leaseRoot ("rw06_1-visual-{0}-{1}.lease" -f $Name, $PID)
    $leaseOwned = $false
    $started = $null
    $startProof = [ordered]@{ started = $false; process_id = 0; process_identity = $null; provenance = 'none' }
    $startError = ''
    $baselineGodot = @()
    $baselineKeys = @()
    $phaseRecord = $null
    $deadline = [DateTime]::UtcNow.AddSeconds($LeaseWaitTimeoutSec)
    try {
        while ($null -eq $started -and [string]::IsNullOrWhiteSpace($startError)) {
            if ([DateTime]::UtcNow -ge $deadline) { throw "Timed out waiting for a Q-009 focused slot for phase $Name." }
            $mutex = [Threading.Mutex]::new($false, $launchMutexName)
            $mutexOwned = $false
            $capacityAvailable = $false
            try {
                $mutexOwned = $mutex.WaitOne(5000)
                if ($mutexOwned) {
                    [void](Assert-RunInputs $StaticOriginal $StaticSnapshot $CacheOwnershipAuthorized)
                    New-Item -ItemType Directory -Force -Path $leaseRoot | Out-Null
                    Clear-ProvablyStaleLeases
                    $exclusivePresent = Test-Path -LiteralPath $exclusiveLeasePath
                    $focusedLeases = @(Get-ChildItem -LiteralPath $leaseRoot -Filter '*.lease' -File -Force -ErrorAction Stop | Where-Object { $_.Name -ne 'EXCLUSIVE.lease' })
                    $godotCensus = Get-LiveGodotCensus
                    $unleased = @(Get-NewUnownedGodotRecords @())
                    if ($unleased.Count -gt 0) { throw "An unleased Godot process exists; refusing phase $Name." }
                    $capacityAvailable = Test-FocusedLaunchCapacity $exclusivePresent $focusedLeases.Count ([int]$godotCensus.process_count)
                    if ($capacityAvailable) {
                        if (Test-Path -LiteralPath $leasePath) { throw "Owned lease path unexpectedly exists: $leasePath" }
                        $leaseText = @(
                            "pid=$PID"
                            "owner_key=$($LauncherIdentity.key)"
                            "owner_path=$($LauncherIdentity.path)"
                            "worktree=$projectRoot"
                            "candidate_commit=$ExpectedCommit"
                            "candidate_tree=$ExpectedTree"
                            "phase=$Name"
                            "started_utc=$([DateTime]::UtcNow.ToString('o'))"
                        ) -join "`n"
                        New-OwnedLeaseFile $leasePath ($leaseText + "`n")
                        $leaseOwned = $true
                        Assert-OwnedLease $leasePath $LauncherIdentity $projectRoot $ExpectedCommit $ExpectedTree $Name
                        # Re-census after the atomic CreateNew reservation, still
                        # under the global launch mutex. This closes races.
                        if (Test-Path -LiteralPath $exclusiveLeasePath) { throw 'EXCLUSIVE.lease appeared during focused reservation.' }
                        $reservedLeases = @(Get-ChildItem -LiteralPath $leaseRoot -Filter '*.lease' -File -Force -ErrorAction Stop | Where-Object { $_.Name -ne 'EXCLUSIVE.lease' })
                        $preLaunchCensus = Get-LiveGodotCensus
                        $newlyUnleased = @(Get-NewUnownedGodotRecords @())
                        if ($newlyUnleased.Count -gt 0) { throw 'An unleased Godot process appeared during focused reservation.' }
                        if ($reservedLeases.Count -gt 2 -or ([int]$preLaunchCensus.process_count + 2) -gt 4) { throw 'Q-009 capacity changed after reservation.' }
                        $baselineGodot = @($preLaunchCensus.records)
                        $baselineKeys = @($baselineGodot | ForEach-Object { [string]$_.key })
                        $started = Start-RedirectedProcess -FilePath $GodotPath -Arguments $arguments -StdoutPath $stdoutPath -StderrPath $stderrPath -ProcessKind Godot -BaselineGodotIdentityKeys $baselineKeys -ChildEnvironment $childEnvironment -TimeoutSec $ProcessTimeoutSec
                        $script:visualOwnedProcessStarted = $true
                    }
                }
            }
            catch {
                $startError = $_.Exception.Message
                $startProof = Get-OwnedProcessStartProofFromException $_.Exception
                if ([bool]$startProof.started) { $script:visualOwnedProcessStarted = $true }
            }
            finally {
                if ($mutexOwned) { $mutex.ReleaseMutex() }
                $mutex.Dispose()
            }
            if ($null -eq $started -and [string]::IsNullOrWhiteSpace($startError)) { Start-Sleep -Seconds 2 }
        }

        if ($null -eq $started) {
            [IO.File]::WriteAllText($stderrPath, $startError + [Environment]::NewLine)
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
            $continuityCheck = { Assert-OwnedLease $leasePath $LauncherIdentity $projectRoot $ExpectedCommit $ExpectedTree $Name }
            $processResult = Complete-RedirectedProcess $started Godot $baselineKeys $continuityCheck
        }

        if ($leaseOwned) { Assert-OwnedLease $leasePath $LauncherIdentity $projectRoot $ExpectedCommit $ExpectedTree $Name }

        $residualIdentityRecords = @()
        $residuals = @()

        $combined = ''
        $hashes = [ordered]@{}
        foreach ($path in @($stdoutPath, $stderrPath, $godotLogPath)) {
            if (Test-Path -LiteralPath $path -PathType Leaf) {
                $combined += "`n--- $([IO.Path]::GetFileName($path)) ---`n" + [IO.File]::ReadAllText($path)
                $hashes[[IO.Path]::GetFileName($path)] = Get-Sha256 $path
            }
        }
        $stdoutText = if (Test-Path -LiteralPath $stdoutPath) { [IO.File]::ReadAllText($stdoutPath) } else { '' }
        $stderrText = if (Test-Path -LiteralPath $stderrPath) { [IO.File]::ReadAllText($stderrPath) } else { '' }
        $godotLogText = if (Test-Path -LiteralPath $godotLogPath) { [IO.File]::ReadAllText($godotLogPath) } else { '' }
        $marker = if ($Name -eq 'q008') { 'RW06_1_Q008 rooms=3 sources=6 failures=0' } else { 'RW06_1_CONTACT_SHEET rooms=18 day2=3 failures=0' }
        $diagnostics = @(Get-DiagnosticLines $combined)
        $valid = (
            [bool]$processResult.process_started `
            -and [bool]$processResult.native_exit_observed `
            -and [int]$processResult.native_exit_code -eq 0 `
            -and [string]$processResult.native_exit_type -eq 'System.Int32' `
            -and [int]$processResult.effective_exit_code -eq 0 `
            -and -not [bool]$processResult.timed_out `
            -and [string]::IsNullOrWhiteSpace([string]$processResult.error) `
            -and $residuals.Count -eq 0 `
            -and $diagnostics.Count -eq 0 `
            -and [string]::IsNullOrWhiteSpace($stderrText) `
            -and $stdoutText.Contains($marker) `
            -and $godotLogText.Contains($marker) `
            -and (Test-SamePath ([string]$processResult.process_identity.path) $canonicalGodotPath)
        )
        $phaseRecord = [ordered]@{
            name = $Name
            mode_switch = $ModeSwitch
            windowed = $true
            command = $GodotPath
            arguments = @($arguments)
            lease_path = $leasePath
            process_started = [bool]$processResult.process_started
            process_start_provenance = [string]$processResult.process_start_provenance
            native_exit_code = [int]$processResult.native_exit_code
            native_exit_observed = [bool]$processResult.native_exit_observed
            native_exit_type = [string]$processResult.native_exit_type
            effective_exit_code = [int]$processResult.effective_exit_code
            timed_out = [bool]$processResult.timed_out
            elapsed_seconds = $processResult.elapsed_seconds
            process_id = [int]$processResult.process_id
            process_identity = $processResult.process_identity
            retained_descendant_identities = @($processResult.retained_descendant_identities)
            owned_residual_process_ids = @($residuals)
            owned_residual_identities = @($residualIdentityRecords)
            launcher_error = [string]$processResult.error
            marker = $marker
            marker_seen_stdout = $stdoutText.Contains($marker)
            marker_seen_godot_log = $godotLogText.Contains($marker)
            stderr_empty = [string]::IsNullOrWhiteSpace($stderrText)
            diagnostics_clean = ($diagnostics.Count -eq 0)
            diagnostics = @($diagnostics)
            capture_root = $captureRoot
            profile_root = $profileRoot
            isolated_user_data_root = $userData
            baseline_godot = @($baselineGodot)
            sha256 = $hashes
            passed = $valid
        }
    }
    finally {
        $postCleanupCensusCompleted = $false
        $postCleanupCensusError = ''
        $postCleanupResidualIdentities = @()
        try {
            $postCleanupRootIdentity = $null
            $postCleanupRetainedRecords = [Collections.Generic.List[object]]::new()
            if ($null -ne $started) {
                $postCleanupRootIdentity = $started.process_identity
                $postCleanupRetainedRecords = $started.retained_descendant_records
            }
            elseif ([bool]$startProof.started) { $postCleanupRootIdentity = $startProof.process_identity }
            $ownedStartRequiresCensus = $null -ne $started -or [bool]$startProof.started
            if ($ownedStartRequiresCensus -and -not (Test-ProcessIdentityProofShape $postCleanupRootIdentity)) { throw 'Post-cleanup authoritative census is missing a valid owned root identity proof.' }
            if ($ownedStartRequiresCensus) {
                $postCleanupResidualIdentities = @(Get-AuthoritativeOwnedResidualIdentityRecords $postCleanupRootIdentity $baselineKeys $postCleanupRetainedRecords @($canonicalGodotPath, $canonicalGodotGuiPath))
            }
            $postCleanupCensusCompleted = $true
        }
        catch { $postCleanupCensusError = $_.Exception.Message }

        $reservationDisposition = Complete-PhaseReservationCleanup `
            $leaseOwned $leasePath $profileRoot $PhaseRoot $LauncherIdentity $projectRoot $ExpectedCommit $ExpectedTree $Name `
            $postCleanupCensusCompleted $postCleanupResidualIdentities $postCleanupCensusError
        if ($null -ne $phaseRecord) {
            $phaseRecord['post_cleanup_identity_census_completed'] = [bool]$reservationDisposition.census_completed
            $phaseRecord['post_cleanup_identity_census_error'] = [string]$reservationDisposition.census_error
            $phaseRecord['owned_residual_identities'] = @($reservationDisposition.owned_residual_identities)
            $phaseRecord['owned_residual_process_ids'] = @($reservationDisposition.owned_residual_process_ids)
            $phaseRecord['reservation_cleanup'] = $reservationDisposition
            if (-not [bool]$reservationDisposition.cleanup_authorized) {
                $phaseRecord['passed'] = $false
                $phaseRecord['effective_exit_code'] = 125
                $reservationError = if (-not [string]::IsNullOrWhiteSpace([string]$reservationDisposition.census_error)) {
                    'Post-cleanup owned-process identity census failed: ' + [string]$reservationDisposition.census_error
                }
                else {
                    'Owned process residuals retained reservation: ' + (@($reservationDisposition.owned_residual_process_ids) -join ',')
                }
                $phaseRecord['launcher_error'] = ([string]$phaseRecord.launcher_error + ' | ' + $reservationError).Trim(' ', '|')
            }
        }
    }
    return $phaseRecord
}


function New-HostileTestPng {
    param([string]$Path, [int]$Width, [int]$Height, [switch]$Blank, [switch]$Transparent, [int]$Variant = 1)
    Add-Type -AssemblyName System.Drawing
    $bitmap = [Drawing.Bitmap]::new($Width, $Height, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        try { $graphics.Clear($(if ($Transparent) { [Drawing.Color]::FromArgb(0, 16, 21, 31) } else { [Drawing.Color]::FromArgb(255, 16, 21, 31) })) } finally { $graphics.Dispose() }
        if ($Transparent) {
            $bitmap.SetPixel(0, 0, [Drawing.Color]::FromArgb(0, 245, 196, 81))
            $bitmap.SetPixel(1, 0, [Drawing.Color]::FromArgb(0, 88, 199, 255))
        }
        elseif (-not $Blank) {
            $red = 32 + (($Variant * 47) % 223)
            $green = 32 + (($Variant * 83) % 223)
            $blue = 32 + (($Variant * 131) % 223)
            $x = [Math]::Abs($Variant) % $Width
            $y = ([Math]::Abs($Variant) * 7) % $Height
            $bitmap.SetPixel($x, $y, [Drawing.Color]::FromArgb(255, $red, $green, $blue))
        }
        $bitmap.Save($Path, [Drawing.Imaging.ImageFormat]::Png)
    }
    finally { $bitmap.Dispose() }
}


function New-HostileEvidenceSeal {
    param([string]$EvidenceRoot, [string]$Label)
    Assert-Contract (Test-Path -LiteralPath $EvidenceRoot -PathType Container) "Hostile evidence root is missing: $EvidenceRoot"
    $sealPath = Join-Path $EvidenceRoot 'evidence_seal.json'
    $hashPath = Join-Path $EvidenceRoot 'evidence_seal.sha256'
    [IO.File]::WriteAllText($sealPath, (([ordered]@{ sealed = $true; fixture = $Label } | ConvertTo-Json -Compress) + "`n"))
    $sha = Get-Sha256 $sealPath
    [IO.File]::WriteAllText($hashPath, ($sha + '  ' + [IO.Path]::GetFileName($sealPath) + "`n"))
    return [ordered]@{ path = Normalize-FullPath $sealPath; sha256 = $sha; hash_path = Normalize-FullPath $hashPath; verified = $true }
}


function New-FixtureSourceRecord {
    param([string]$Path, [string]$Room, [string]$Phase, [string]$Mode, [int]$Variant)
    New-HostileTestPng $Path $expectedSourceWidth $expectedSourceHeight -Variant $Variant
    $sha = Get-Sha256 $Path
    $map = "${Room}_map"
    $scenario = if ($Phase -eq 'base_inventory') { '' } else { "${Room}_scenario" }
    $selection = [ordered]@{ archetype_id = $Room; map_id = $map; scenario_id = $scenario; phase_id = $Phase }
    $renderedPhase = if ($Phase -eq 'base_inventory') { '' } else { $Phase }
    return [ordered]@{
        ok = $true
        player_view_clean = $true
        mode = $Mode
        path = Normalize-FullPath $Path
        sha256 = $sha
        capture_source = 'production_root_viewport_texture'
        post_processed = $false
        errors = @()
        direct_interaction_overlaps = @()
        player_view_cleanliness = [ordered]@{ ok = $true }
        selection = $selection
        image_validation = [ordered]@{
            ok = $true; decoded = $true; nonblank = $true; path = Normalize-FullPath $Path; sha256 = $sha
            expected_size = [ordered]@{ w = $expectedSourceWidth; h = $expectedSourceHeight }
            actual_size = [ordered]@{ w = $expectedSourceWidth; h = $expectedSourceHeight }
            errors = @()
        }
        rendered_identity = [ordered]@{
            ok = $true; errors = @()
            requested = [ordered]@{ map_id = $map; scenario_id = $scenario; phase_id = $Phase }
            run = [ordered]@{ map_id = $map; scenario_id = $scenario; phase_id = $renderedPhase }
            rendered = [ordered]@{ map_id = $map; scenario_id = $scenario; phase_id = $renderedPhase }
        }
        generation_identity = [ordered]@{
            ok = $true; identity_key = "seed-${Variant}|${Variant}|$($Variant + 1)|$($Variant + 2)|${map}|${scenario}|${Phase}"
            expected_seed_text = "seed-$Variant"; seed_text = "seed-$Variant"; seed_value = $Variant; rng_seed = $Variant + 1; rng_state = $Variant + 2
            world_map_seed_text = if ($Phase -eq 'base_inventory') { '' } else { "seed-$Variant" }
            environment_map_id = $map; scenario_id = $scenario; phase_id = $renderedPhase
            assertions = [ordered]@{ seed_text_exact = $true; world_seed_text_exact_when_present = $true; seed_value_nonzero = $true; rng_seed_nonzero = $true; rng_state_nonzero = $true; environment_map_exact = $true; scenario_exact = $true; phase_exact = $true }
            errors = @()
        }
    }
}


function New-FixtureSheetRecord {
    param([string]$Path, [int]$Width, [int]$Height, [object[]]$Cells, [int]$Variant)
    New-HostileTestPng $Path $Width $Height -Variant $Variant
    $sha = Get-Sha256 $Path
    return [ordered]@{
        ok = $true
        path = Normalize-FullPath $Path
        sha256 = $sha
        expected_size = [ordered]@{ w = $Width; h = $Height }
        size = [ordered]@{ w = $Width; h = $Height }
        image_validation = [ordered]@{ ok = $true; decoded = $true; nonblank = $true; sha256 = $sha; errors = @() }
        cells = @($Cells)
        errors = @()
    }
}


function New-Q008ValidatorFixture {
    param([string]$Root, [string]$StaticPath, [string]$StaticSha)
    New-Item -ItemType Directory -Force -Path (Join-Path $Root 'q008_sources') | Out-Null
    $captures = [Collections.Generic.List[object]]::new()
    $cells = [Collections.Generic.List[object]]::new()
    $generationRows = [Collections.Generic.List[object]]::new()
    $variant = 100
    for ($roomIndex = 0; $roomIndex -lt $expectedQ008Rooms.Count; $roomIndex++) {
        $room = $expectedQ008Rooms[$roomIndex]
        $basePath = Join-Path $Root "q008_sources\${room}_base.png"
        $busyPath = Join-Path $Root "q008_sources\${room}_busiest_physical.png"
        $variant += 1
        $base = New-FixtureSourceRecord $basePath $room 'base_inventory' 'normal' $variant
        $variant += 1
        $busy = New-FixtureSourceRecord $busyPath $room 'fixture_peak' 'normal' $variant
        Write-Host ("RW06_1_VISUAL_LAUNCHER_VALIDATE_ONLY_PROGRESS stage=q008_built_room room={0}" -f $room)
        [void]$captures.Add([ordered]@{ archetype_id = $room; base = $base; busiest_physical = $busy; errors = @() })
        [void]$generationRows.Add([ordered]@{ archetype_id = $room; capture_role = 'base'; generation_identity = $base.generation_identity })
        [void]$generationRows.Add([ordered]@{ archetype_id = $room; capture_role = 'busiest_physical'; generation_identity = $busy.generation_identity })
        foreach ($roleIndex in 0, 1) {
            $role = if ($roleIndex -eq 0) { 'base' } else { 'busiest_physical' }
            $record = if ($roleIndex -eq 0) { $base } else { $busy }
            [void]$cells.Add([ordered]@{
                archetype_id = $room; capture_role = $role; scenario_id = [string]$record.selection.scenario_id
                phase_id = [string]$record.selection.phase_id; mode = 'normal'; source_path = [string]$record.path; source_sha256 = [string]$record.sha256
                rect = [ordered]@{ x = $roomIndex * 320; y = $roleIndex * 180; w = 320; h = 180 }
            })
        }
    }
    Write-Host 'RW06_1_VISUAL_LAUNCHER_VALIDATE_ONLY_PROGRESS stage=q008_build_sheet'
    $sheet = New-FixtureSheetRecord (Join-Path $Root 'q008_rooms.png') 960 360 @($cells) 901
    Write-Host 'RW06_1_VISUAL_LAUNCHER_VALIDATE_ONLY_PROGRESS stage=q008_serialize'
    $report = [ordered]@{
        schema = 'rw06_1_q008_room_proof/v1'; passed = $true; failures = @(); normal_only = $true
        capture_source = 'production_root_viewport_texture'; source_post_processed = $false; sheet_post_processed = $true
        accepted_source_capture_count = 6; captures = @($captures); capture_attempts = @({}, {}, {})
        source_static_report = Normalize-FullPath $StaticPath; source_static_report_sha256 = $StaticSha
        required_archetype_ids = @($expectedQ008Rooms)
        generation_identity = [ordered]@{ ok = $true; errors = @(); strategy = 'independent_named_seed_per_capture'; capture_count = 6; captures = @($generationRows) }
        sheet = $sheet
    }
    [IO.File]::WriteAllText((Join-Path $Root 'q008_rooms.json'), (($report | ConvertTo-Json -Depth 7) + "`n"))
}


function New-All18ValidatorFixture {
    param([string]$Root, [string]$StaticPath, [string]$StaticSha, [string[]]$RoomIds)
    New-Item -ItemType Directory -Force -Path (Join-Path $Root 'normal') | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $Root 'expanded') | Out-Null
    $captures = [Collections.Generic.List[object]]::new()
    $generationRows = [Collections.Generic.List[object]]::new()
    $allCells = [Collections.Generic.List[object]]::new()
    $day2Cells = [Collections.Generic.List[object]]::new()
    $variant = 200
    for ($index = 0; $index -lt $RoomIds.Count; $index++) {
        $room = $RoomIds[$index]
        $variant += 1
        $normal = New-FixtureSourceRecord (Join-Path $Root "normal\${room}.png") $room 'fixture_peak' 'normal' $variant
        $variant += 1
        $expanded = New-FixtureSourceRecord (Join-Path $Root "expanded\${room}.png") $room 'fixture_peak' 'expanded' $variant
        $expanded.generation_identity = $normal.generation_identity
        [void]$captures.Add([ordered]@{ ok = $true; player_view_clean = $true; errors = @(); selection = $normal.selection; generation_identity = $normal.generation_identity; normal = $normal; expanded = $expanded })
        [void]$generationRows.Add([ordered]@{ selection = $normal.selection; generation_identity = $normal.generation_identity })
        foreach ($modeIndex in 0, 1) {
            $mode = if ($modeIndex -eq 0) { 'normal' } else { 'expanded' }
            [void]$allCells.Add([ordered]@{
                archetype_id = $room; scenario_id = [string]$normal.selection.scenario_id; phase_id = [string]$normal.selection.phase_id; mode = $mode
                rect = [ordered]@{ x = (($index % 3) * 640 + $modeIndex * 320); y = ([Math]::Floor($index / 3) * 180); w = 320; h = 180 }
            })
        }
    }
    $day2Rooms = @($RoomIds | Where-Object { $expectedQ008Rooms -contains $_ })
    for ($index = 0; $index -lt $day2Rooms.Count; $index++) {
        foreach ($modeIndex in 0, 1) {
            $mode = if ($modeIndex -eq 0) { 'normal' } else { 'expanded' }
            [void]$day2Cells.Add([ordered]@{ archetype_id = $day2Rooms[$index]; scenario_id = "fixture"; phase_id = 'fixture_peak'; mode = $mode; rect = [ordered]@{ x = $modeIndex * 320; y = $index * 180; w = 320; h = 180 } })
        }
    }
    $allSheet = New-FixtureSheetRecord (Join-Path $Root 'all_rooms_contact_sheet.png') 1920 1080 @($allCells) 902
    $day2Sheet = New-FixtureSheetRecord (Join-Path $Root 'day2_contact_sheet.png') 640 540 @($day2Cells) 903
    $report = [ordered]@{
        schema = 'rw06_1_fixed_slot_contact_sheet/v1'; passed = $true; failures = @(); room_count = 18; day2_room_count = 3
        captures = @($captures); capture_attempts = @(1..18)
        source_static_report = Normalize-FullPath $StaticPath; source_static_report_sha256 = $StaticSha
        generation_identity = [ordered]@{ ok = $true; errors = @(); strategy = 'independent_named_seed_per_capture'; capture_count = 18; captures = @($generationRows) }
        player_view_cleanliness = [ordered]@{ required = $true; passed = $true; accepted_source_capture_count = 36 }
        all_rooms_sheet = $allSheet; day2_sheet = $day2Sheet
    }
    [IO.File]::WriteAllText((Join-Path $Root 'contact_sheet_report.json'), (($report | ConvertTo-Json -Depth 7) + "`n"))
}


function Invoke-ExpectedFailure {
    param([scriptblock]$Action, [string]$Label)
    $failed = $false
    try { & $Action } catch { $failed = $true }
    Assert-Contract $failed "$Label hostile probe unexpectedly passed."
}


function Invoke-StaticCheckerPhase {
    param([string]$PhaseRoot, [object]$StaticCheckerIdentity, [string]$OutputPath)
    New-Item -ItemType Directory -Force -Path $PhaseRoot | Out-Null
    if (Test-Path -LiteralPath $OutputPath) { throw "Fresh static-check output already exists: $OutputPath" }
    $stdoutPath = Join-Path $PhaseRoot 'stdout.log'
    $stderrPath = Join-Path $PhaseRoot 'stderr.log'
    $pythonInvocationPath = Normalize-FullPath $PythonPath
    $checkerPath = Join-Path $projectRoot ($staticCheckerRelativePath.Replace('/', '\'))
    Assert-ExpectedSha256 'Static checker exact candidate bytes' ([string]$StaticCheckerIdentity.sha256) (Get-Sha256 $checkerPath)
    Assert-ExpectedSha256 'Static checker Python pre-run' $ExpectedPythonSha256 (Get-Sha256 $pythonInvocationPath)
    [void](Get-ExactCandidateIdentity $projectRoot $ExpectedCommit $ExpectedTree)
    $arguments = @($checkerPath, $projectRoot, $OutputPath)
    $started = Start-RedirectedProcess -FilePath $pythonInvocationPath -Arguments $arguments -StdoutPath $stdoutPath -StderrPath $stderrPath -ProcessKind Exact -TimeoutSec 600
    $result = Complete-RedirectedProcess $started Exact
    $stdoutText = if (Test-Path -LiteralPath $stdoutPath) { [IO.File]::ReadAllText($stdoutPath) } else { '' }
    $stderrText = if (Test-Path -LiteralPath $stderrPath) { [IO.File]::ReadAllText($stderrPath) } else { '' }
    $diagnostics = @(Get-DiagnosticLines ($stdoutText + "`n" + $stderrText))
    $marker = 'ENVIRONMENT_FIXED_SLOT_STATIC_CHECK PASS'
    $outputSha = Get-OptionalSha256 $OutputPath
    $pythonIdentityError = ''
    try { Assert-ExecutedBinaryIdentity 'Static checker Python' $pythonInvocationPath $ExpectedPythonSha256 $result.process_identity }
    catch { $pythonIdentityError = $_.Exception.Message }
    $passed = (
        [bool]$result.process_started `
        -and [bool]$result.native_exit_observed `
        -and [int]$result.native_exit_code -eq 0 `
        -and [string]$result.native_exit_type -eq 'System.Int32' `
        -and [int]$result.effective_exit_code -eq 0 `
        -and -not [bool]$result.timed_out `
        -and [string]::IsNullOrWhiteSpace([string]$result.error) `
        -and [string]::IsNullOrWhiteSpace($stderrText) `
        -and $diagnostics.Count -eq 0 `
        -and $stdoutText.Contains($marker) `
        -and $outputSha -match $shaPattern `
        -and $outputSha -ieq $ExpectedStaticReportSha256 `
        -and [string]::IsNullOrWhiteSpace($pythonIdentityError)
    )
    [void](Get-ExactCandidateIdentity $projectRoot $ExpectedCommit $ExpectedTree)
    Assert-ExpectedSha256 'Static checker post-run bytes' ([string]$StaticCheckerIdentity.sha256) (Get-Sha256 $checkerPath)
    Assert-ExpectedSha256 'Static checker Python post-run' $ExpectedPythonSha256 (Get-Sha256 $pythonInvocationPath)
    return [ordered]@{
        name = 'fresh_static_checker'
        engine_free = $true
        invocation_command = $pythonInvocationPath
        command = [string]$result.process_identity.path
        command_sha256 = Get-OptionalSha256 ([string]$result.process_identity.path)
        interpreter_expected_path = $canonicalPythonPath
        interpreter_expected_sha256 = $canonicalPythonSha256
        arguments = @($arguments)
        process_started = [bool]$result.process_started
        native_exit_code = [int]$result.native_exit_code
        native_exit_observed = [bool]$result.native_exit_observed
        native_exit_type = [string]$result.native_exit_type
        effective_exit_code = [int]$result.effective_exit_code
        timed_out = [bool]$result.timed_out
        elapsed_seconds = $result.elapsed_seconds
        process_identity = $result.process_identity
        launcher_error = [string]$result.error
        interpreter_identity_error = $pythonIdentityError
        marker = $marker
        marker_seen = $stdoutText.Contains($marker)
        stderr_empty = [string]::IsNullOrWhiteSpace($stderrText)
        diagnostics = @($diagnostics)
        static_checker = $StaticCheckerIdentity
        generated_report = [ordered]@{ path = Normalize-FullPath $OutputPath; sha256 = $outputSha; expected_sha256 = $ExpectedStaticReportSha256 }
        sha256 = [ordered]@{ stdout = Get-Sha256 $stdoutPath; stderr = Get-Sha256 $stderrPath }
        passed = $passed
    }
}


function Invoke-SourceContractPhase {
    param([string]$PhaseRoot, [object]$SourceContractIdentity)
    New-Item -ItemType Directory -Force -Path $PhaseRoot | Out-Null
    $stdoutPath = Join-Path $PhaseRoot 'stdout.log'
    $stderrPath = Join-Path $PhaseRoot 'stderr.log'
    $pythonPath = Normalize-FullPath $PythonPath
    $contractPath = Join-Path $projectRoot ($sourceContractRelativePath.Replace('/', '\'))
    $capturePath = Join-Path $projectRoot ($captureRelativePath.Replace('/', '\'))
    Assert-ExpectedSha256 'Source contract exact candidate bytes' ([string]$SourceContractIdentity.sha256) (Get-Sha256 $contractPath)
    Assert-ExpectedSha256 'Source contract Python pre-run' $ExpectedPythonSha256 (Get-Sha256 $pythonPath)
    [void](Get-ExactCandidateIdentity $projectRoot $ExpectedCommit $ExpectedTree)
    $started = Start-RedirectedProcess -FilePath $pythonPath -Arguments @($contractPath, '--source', $capturePath) -StdoutPath $stdoutPath -StderrPath $stderrPath -ProcessKind Exact -TimeoutSec 120
    $result = Complete-RedirectedProcess $started Exact
    $stdoutText = if (Test-Path -LiteralPath $stdoutPath) { [IO.File]::ReadAllText($stdoutPath) } else { '' }
    $stderrText = if (Test-Path -LiteralPath $stderrPath) { [IO.File]::ReadAllText($stderrPath) } else { '' }
    $diagnostics = @(Get-DiagnosticLines ($stdoutText + "`n" + $stderrText))
    $marker = 'RW06_1_VISUAL_CAPTURE_SOURCE_CONTRACT PASS'
    $pythonIdentityError = ''
    try { Assert-ExecutedBinaryIdentity 'Source contract Python' $pythonPath $ExpectedPythonSha256 $result.process_identity }
    catch { $pythonIdentityError = $_.Exception.Message }
    $passed = (
        [bool]$result.process_started `
        -and [bool]$result.native_exit_observed `
        -and [int]$result.native_exit_code -eq 0 `
        -and [string]$result.native_exit_type -eq 'System.Int32' `
        -and [int]$result.effective_exit_code -eq 0 `
        -and -not [bool]$result.timed_out `
        -and [string]::IsNullOrWhiteSpace([string]$result.error) `
        -and [string]::IsNullOrWhiteSpace($stderrText) `
        -and $diagnostics.Count -eq 0 `
        -and $stdoutText.Contains($marker) `
        -and [string]::IsNullOrWhiteSpace($pythonIdentityError)
    )
    [void](Get-ExactCandidateIdentity $projectRoot $ExpectedCommit $ExpectedTree)
    Assert-ExpectedSha256 'Source contract post-run bytes' ([string]$SourceContractIdentity.sha256) (Get-Sha256 $contractPath)
    Assert-ExpectedSha256 'Source contract Python post-run' $ExpectedPythonSha256 (Get-Sha256 $pythonPath)
    return [ordered]@{
        name = 'source_contract'
        engine_free = $true
        invocation_command = $pythonPath
        command = [string]$result.process_identity.path
        command_sha256 = Get-OptionalSha256 ([string]$result.process_identity.path)
        interpreter_expected_path = $canonicalPythonPath
        interpreter_expected_sha256 = $canonicalPythonSha256
        arguments = @($contractPath, '--source', $capturePath)
        process_started = [bool]$result.process_started
        native_exit_code = [int]$result.native_exit_code
        native_exit_observed = [bool]$result.native_exit_observed
        native_exit_type = [string]$result.native_exit_type
        effective_exit_code = [int]$result.effective_exit_code
        timed_out = [bool]$result.timed_out
        elapsed_seconds = $result.elapsed_seconds
        process_identity = $result.process_identity
        launcher_error = [string]$result.error
        interpreter_identity_error = $pythonIdentityError
        marker = $marker
        marker_seen = $stdoutText.Contains($marker)
        stderr_empty = [string]::IsNullOrWhiteSpace($stderrText)
        diagnostics = @($diagnostics)
        source_contract = $SourceContractIdentity
        sha256 = [ordered]@{ stdout = Get-Sha256 $stdoutPath; stderr = Get-Sha256 $stderrPath }
        passed = $passed
    }
}


if ($ValidateOnly -and -not $ValidateOnlyWorker) {
    $outerBefore = @(Get-LiveGodotIdentityRecords)
    $outerBeforeKeys = @($outerBefore | ForEach-Object { [string]$_.key })
    $outerRoot = Join-Path $projectRoot ('.tmp\rw06_1\visual_launcher_outer\' + [guid]::NewGuid().ToString('N'))
    [void](Assert-NoReparseAncestors (Split-Path -Parent $outerRoot) $projectRoot)
    New-Item -ItemType Directory -Path $outerRoot | Out-Null
    $outerStdout = Join-Path $outerRoot 'stdout.log'
    $outerStderr = Join-Path $outerRoot 'stderr.log'
    $outerOutput = ''
    $outerError = ''
    $outerExit = 1
    try {
        $powerShellExe = Join-Path $PSHOME 'powershell.exe'
        $outerStarted = Start-RedirectedProcess -FilePath $powerShellExe -Arguments @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath, '-ValidateOnly', '-ValidateOnlyWorker') -StdoutPath $outerStdout -StderrPath $outerStderr -ProcessKind Exact -TimeoutSec 20
        $outerResult = Complete-RedirectedProcess $outerStarted Exact
        $outerOutput = if (Test-Path -LiteralPath $outerStdout) { [IO.File]::ReadAllText($outerStdout) } else { '' }
        $outerError = if (Test-Path -LiteralPath $outerStderr) { [IO.File]::ReadAllText($outerStderr) } else { '' }
        $outerDiagnostics = @(Get-DiagnosticLines ($outerOutput + "`n" + $outerError))
        $outerNewGodot = @(Get-NewUnownedGodotRecords $outerBeforeKeys)
        $outerPassed = (
            [bool]$outerResult.process_started -and [bool]$outerResult.native_exit_observed -and [int]$outerResult.native_exit_code -eq 0 `
            -and [string]$outerResult.native_exit_type -eq 'System.Int32' -and [int]$outerResult.effective_exit_code -eq 0 -and -not [bool]$outerResult.timed_out `
            -and [string]::IsNullOrWhiteSpace([string]$outerResult.error) -and [string]::IsNullOrWhiteSpace($outerError) -and $outerDiagnostics.Count -eq 0 `
            -and $outerOutput.Contains('RW06_1_VISUAL_LAUNCHER_VALIDATE_ONLY PASS') -and $outerNewGodot.Count -eq 0
        )
        if ($outerPassed) { $outerExit = 0 }
        else {
            $outerError = ($outerError + "`nouter_result=" + ($outerResult | ConvertTo-Json -Compress -Depth 8)).Trim()
            if ([bool]$outerResult.timed_out) { $outerError += "`nValidateOnly hard outer deadline exceeded 20 seconds." }
        }
    }
    catch { $outerError = ($outerError + "`n" + $_.Exception.Message).Trim() }
    finally { if (Test-Path -LiteralPath $outerRoot) { Remove-OwnedDirectory $outerRoot (Join-Path $projectRoot '.tmp\rw06_1\visual_launcher_outer') } }
    if (-not [string]::IsNullOrWhiteSpace($outerOutput)) { [Console]::Out.Write($outerOutput) }
    if (-not [string]::IsNullOrWhiteSpace($outerError)) { [Console]::Error.WriteLine($outerError) }
    exit $outerExit
}


if ($ValidateOnly) {
    $validateStopwatch = [Diagnostics.Stopwatch]::StartNew()
    $writeValidateProgress = {
        param([string]$Stage)
        if ($validateStopwatch.Elapsed.TotalSeconds -ge 18) { throw "ValidateOnly worker exceeded its 18-second internal deadline at stage $Stage." }
        Write-Host ("RW06_1_VISUAL_LAUNCHER_VALIDATE_ONLY_PROGRESS stage={0} elapsed={1}" -f $Stage, [Math]::Round($validateStopwatch.Elapsed.TotalSeconds, 3))
    }
    & $writeValidateProgress 'start'
    $godotBefore = @(Get-LiveGodotIdentityRecords)
    $godotBeforeKeys = @($godotBefore | ForEach-Object { [string]$_.key })
    $finishValidateStage = {
        param([string]$Stage)
        if ($ValidateOnlyStopAfter -ne $Stage) { return }
        Assert-Contract (@(Get-NewUnownedGodotRecords $godotBeforeKeys).Count -eq 0) "ValidateOnly $Stage stage observed a new unowned Godot process."
        Write-Host ("RW06_1_VISUAL_LAUNCHER_VALIDATE_ONLY_STAGE PASS stage={0} elapsed={1}" -f $Stage, [Math]::Round($validateStopwatch.Elapsed.TotalSeconds, 3))
        exit 0
    }
    Assert-Contract ($leaseRoot -ceq $canonicalLeaseRoot) 'Canonical Q-009 lease root did not resolve exactly.'
    Assert-Contract (Test-FocusedLaunchCapacity $false 0 0) 'Q-009 rejected an empty machine.'
    Assert-Contract (Test-FocusedLaunchCapacity $false 1 2) 'Q-009 rejected a valid second focused pair.'
    Assert-Contract (-not (Test-FocusedLaunchCapacity $true 0 0)) 'Q-009 ignored EXCLUSIVE.lease.'
    Assert-Contract (-not (Test-FocusedLaunchCapacity $false 2 0)) 'Q-009 allowed a third focused pair.'
    Assert-Contract (-not (Test-FocusedLaunchCapacity $false 1 3)) 'Q-009 allowed process count + 2 above four.'
    Assert-Contract (Test-SamePath $PythonPath $canonicalPythonPath) 'ValidateOnly is not using the release-pinned Python path.'
    Assert-Contract ($ExpectedPythonSha256 -ieq $canonicalPythonSha256) 'ValidateOnly is not using the release-pinned Python SHA-256.'
    Assert-ExpectedSha256 'ValidateOnly canonical Python' $canonicalPythonSha256 (Get-Sha256 $canonicalPythonPath)

    Assert-ExactCandidateIdentity ('a' * 40) ('b' * 40) ('a' * 40) ('b' * 40)
    Invoke-ExpectedFailure { Assert-ExactCandidateIdentity ('a' * 40) ('b' * 40) ('c' * 40) ('b' * 40) } 'Commit drift'
    Invoke-ExpectedFailure { Assert-ExactCandidateIdentity ('a' * 40) ('b' * 40) ('a' * 40) ('c' * 40) } 'Tree drift'
    Invoke-ExpectedFailure { Assert-ExactCandidateIdentity 'main' ('b' * 40) ('a' * 40) ('b' * 40) } 'Symbolic commit'
    Assert-CleanStatusEntries @()
    Invoke-ExpectedFailure { Assert-CleanStatusEntries @(' M scripts/ui/pixel_scene_canvas.gd') } 'Dirty candidate'

    $self = Get-Process -Id $PID
    $selfIdentity = Get-ProcessIdentityRecord $self
    Assert-Contract (Test-ProcessIdentityProofShape $selfIdentity) 'Exact PID/start/name/path proof rejected the launcher.'
    Assert-Contract (Test-LiveProcessMatchesIdentity $selfIdentity) 'Exact process identity did not match its live process.'
    $selfExecutableSha = Get-Sha256 ([string]$selfIdentity.path)
    Assert-ExecutedBinaryIdentity 'Synthetic exact interpreter' ([string]$selfIdentity.path) $selfExecutableSha $selfIdentity
    Invoke-ExpectedFailure { Assert-ExecutedBinaryIdentity 'Synthetic interpreter hash drift' ([string]$selfIdentity.path) ('0' * 64) $selfIdentity } 'Interpreter hash drift'
    $wrongPath = [ordered]@{}
    foreach ($entry in $selfIdentity.GetEnumerator()) { $wrongPath[$entry.Key] = $entry.Value }
    $wrongPath.path = 'C:\definitely-wrong\powershell.exe'
    $wrongPath.key = ('{0}|{1}|{2}|{3}' -f $wrongPath.pid, $wrongPath.start_ticks, $wrongPath.name, $wrongPath.path.ToLowerInvariant())
    Assert-Contract (-not (Test-LiveProcessMatchesIdentity $wrongPath)) 'Process identity accepted a wrong executable path.'
    Invoke-ExpectedFailure { Assert-ExecutedBinaryIdentity 'Synthetic interpreter path drift' ([string]$selfIdentity.path) $selfExecutableSha $wrongPath } 'Interpreter execution path drift'
    $wrongStart = [ordered]@{}
    foreach ($entry in $selfIdentity.GetEnumerator()) { $wrongStart[$entry.Key] = $entry.Value }
    $wrongStart.start_ticks = [long]$wrongStart.start_ticks - 10000000
    $wrongStart.start_utc = ([datetime]::new([long]$wrongStart.start_ticks, [DateTimeKind]::Utc)).ToString('o')
    $wrongStart.key = ('{0}|{1}|{2}|{3}' -f $wrongStart.pid, $wrongStart.start_ticks, $wrongStart.name, ([string]$wrongStart.path).ToLowerInvariant())
    Assert-Contract (-not (Test-LiveProcessMatchesIdentity $wrongStart)) 'Process identity accepted a reused PID/start time.'
    $validException = [InvalidOperationException]::new('valid start proof')
    $validException.Data['owned_process_id'] = [int]$selfIdentity.pid
    $validException.Data['owned_process_identity'] = $selfIdentity
    Assert-Contract ([bool](Get-OwnedProcessStartProofFromException $validException).started) 'Setup-exception start proof was lost.'
    $pidOnlyException = [InvalidOperationException]::new('pid only')
    $pidOnlyException.Data['owned_process_id'] = [int]$selfIdentity.pid
    Assert-Contract (-not [bool](Get-OwnedProcessStartProofFromException $pidOnlyException).started) 'PID-only setup proof was accepted.'
    Assert-Contract (Test-CimCreationMatchesProcessStartTicks 150 159) 'Exact CIM microsecond truncation was rejected.'
    Assert-Contract (-not (Test-CimCreationMatchesProcessStartTicks 140 159)) 'Nearby reused-process CIM time was accepted.'

    $identityFactory = {
        param([int]$PidValue, [long]$Ticks, [string]$Name, [string]$Path)
        $full = Normalize-FullPath $Path
        return [ordered]@{
            pid = $PidValue
            name = $Name
            path = $full
            start_utc = ([datetime]::new($Ticks, [DateTimeKind]::Utc)).ToString('o')
            start_ticks = $Ticks
            key = ('{0}|{1}|{2}|{3}' -f $PidValue, $Ticks, $Name, $full.ToLowerInvariant())
        }
    }
    $rootIdentity = & $identityFactory 100 100 'root' 'C:\probe\root.exe'
    $goodChild = & $identityFactory 201 150 'child' 'C:\probe\child.exe'
    $goodGrandchild = & $identityFactory 301 220 'grandchild' 'C:\probe\grandchild.exe'
    $baselineChild = & $identityFactory 203 160 'baseline' 'C:\probe\baseline.exe'
    $reusedParent = & $identityFactory 201 240 'child-reused' 'C:\probe\replacement.exe'
    $synthetic = @(
        [ordered]@{ parent_pid = 100; parent_identity = $rootIdentity; creation_ticks = 150; identity = $goodChild },
        [ordered]@{ parent_pid = 201; parent_identity = $goodChild; creation_ticks = 220; identity = $goodGrandchild },
        [ordered]@{ parent_pid = 100; parent_identity = $rootIdentity; creation_ticks = 160; identity = $baselineChild },
        [ordered]@{ parent_pid = 201; parent_identity = $reusedParent; creation_ticks = 260; identity = (& $identityFactory 401 260 'bad-descendant' 'C:\probe\bad.exe') },
        [ordered]@{ parent_pid = 100; parent_identity = $rootIdentity; creation_ticks = 510; identity = (& $identityFactory 501 510 'late' 'C:\probe\late.exe') }
    )
    $verified = @(Resolve-VerifiedDescendantIdentityRecords $rootIdentity 500 @([string]$baselineChild.key) $synthetic)
    $verifiedKeys = @($verified | ForEach-Object { [string]$_.key })
    Assert-Contract ($verifiedKeys.Count -eq 2 -and $verifiedKeys -contains [string]$goodChild.key -and $verifiedKeys -contains [string]$goodGrandchild.key) 'Lineage resolver lost an exact direct/deep descendant.'
    Assert-Contract ($verifiedKeys -notcontains [string]$baselineChild.key -and @($verified | Where-Object { $_.name -in @('bad-descendant', 'late') }).Count -eq 0) 'Lineage resolver accepted baseline, reused-parent, or late descendants.'
    & $writeValidateProgress 'identity_and_q009'
    & $finishValidateStage 'identity'

    $probeRoot = Join-Path $projectRoot ('.tmp\rw06_1\visual_launcher_selftest\' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $probeRoot | Out-Null
    try {
        $hashFile = Join-Path $probeRoot 'hash.txt'
        [IO.File]::WriteAllText($hashFile, 'exact bytes')
        $hash = Get-Sha256 $hashFile
        Assert-ExpectedSha256 'Hash equality' $hash $hash
        Invoke-ExpectedFailure { Assert-ExpectedSha256 'Hash drift' ('0' * 64) $hash } 'Hash drift'

        $leasePath = Join-Path $probeRoot 'lease.lease'
        New-OwnedLeaseFile $leasePath "pid=$PID`n"
        Invoke-ExpectedFailure { New-OwnedLeaseFile $leasePath "pid=1`n" } 'Lease CreateNew race'
        Assert-Contract ([IO.File]::ReadAllText($leasePath) -eq "pid=$PID`n") 'Lease race overwrote the first owner.'
        Remove-Item -LiteralPath $leasePath -Force
        Invoke-ExpectedFailure { New-OwnedLeaseFile $leasePath "pid=$PID`n" -ForceWriteFailureForTest } 'Partial lease write'
        Assert-Contract (-not (Test-Path -LiteralPath $leasePath)) 'Partial lease write left a reservation.'
        $boundLeasePath = Join-Path $probeRoot ("probe-{0}.lease" -f $PID)
        New-OwnedLeaseFile $boundLeasePath "pid=$PID`nowner_key=$($selfIdentity.key)`nowner_path=$($selfIdentity.path)`nworktree=$projectRoot`ncandidate_commit=$('a' * 40)`ncandidate_tree=$('b' * 40)`nphase=probe`n"
        $binding = Get-LeaseBinding (Get-Item -LiteralPath $boundLeasePath)
        Assert-Contract ([int]$binding.pid -eq $PID) 'Focused lease did not bind filename PID to content PID.'
        [IO.File]::WriteAllText($boundLeasePath, "pid=1`n")
        Invoke-ExpectedFailure { [void](Get-LeaseBinding (Get-Item -LiteralPath $boundLeasePath)) } 'Focused filename/content PID mismatch'
        Remove-Item -LiteralPath $boundLeasePath -Force
        Invoke-ExpectedFailure { Assert-OwnedLease $boundLeasePath $selfIdentity $projectRoot ('a' * 40) ('b' * 40) 'probe' } 'Disappeared owned lease'

        $staleLeaseRoot = Join-Path $probeRoot 'lease-owner-stale-reused-pid'
        New-Item -ItemType Directory -Path $staleLeaseRoot | Out-Null
        $staleWrongKeyLeasePath = Join-Path $staleLeaseRoot ("wrong-key-$PID.lease")
        $staleWrongPathLeasePath = Join-Path $staleLeaseRoot ("wrong-path-$PID.lease")
        $staleSentinelPath = Join-Path $staleLeaseRoot 'preserve.txt'
        [IO.File]::WriteAllText($staleSentinelPath, 'preserve-neighbor')
        $staleSentinelSha = Get-Sha256 $staleSentinelPath
        $staleWrongKeyLeaseText = @(
            "pid=$PID"
            'owner_key=forged-live-pid-owner-key'
            "owner_path=$($selfIdentity.path)"
            'worktree=C:\forged\worktree'
            'candidate_commit=forged'
            'candidate_tree=forged'
            'phase=stale-wrong-key'
        ) -join "`n"
        $staleWrongPathLeaseText = @(
            "pid=$PID"
            "owner_key=$($selfIdentity.key)"
            'owner_path=C:\forged\replacement-owner.exe'
            'worktree=C:\forged\worktree'
            'candidate_commit=forged'
            'candidate_tree=forged'
            'phase=stale-wrong-path'
        ) -join "`n"
        New-OwnedLeaseFile $staleWrongKeyLeasePath ($staleWrongKeyLeaseText + "`n")
        New-OwnedLeaseFile $staleWrongPathLeasePath ($staleWrongPathLeaseText + "`n")
        $staleLeaseOwners = @(Get-LiveLeaseOwnerIdentities -LeaseDirectory $staleLeaseRoot)
        $staleLeaseOwnerPids = @(Get-LiveLeaseOwnerPids -LeaseDirectory $staleLeaseRoot)
        Assert-Contract ($staleLeaseOwners.Count -eq 0 -and $staleLeaseOwnerPids -notcontains $PID) 'A live reused PID with an independently mismatched owner key or path entered the valid lease-owner census.'
        $leaseChildPid = if ($PID -eq 2000000000) { 1999999999 } else { 2000000000 }
        Assert-Contract (-not (Test-ProcessHasLeaseAncestor -ProcessId $leaseChildPid -LeaseOwnerIdentities $staleLeaseOwners)) 'A descendant of a stale reused-PID lease was classified as leased.'
        Clear-ProvablyStaleLeases -LeaseDirectory $staleLeaseRoot
        Assert-Contract (
            -not (Test-Path -LiteralPath $staleWrongKeyLeasePath) -and -not (Test-Path -LiteralPath $staleWrongPathLeasePath) `
            -and (Test-Path -LiteralPath $staleSentinelPath -PathType Leaf)
        ) 'Exact stale-lease cleanup removed the wrong path or retained a forged key/path lease.'
        Assert-ExpectedSha256 'Stale-lease cleanup neighboring bytes' $staleSentinelSha (Get-Sha256 $staleSentinelPath)

        $validLeaseRoot = Join-Path $probeRoot 'lease-owner-valid'
        New-Item -ItemType Directory -Path $validLeaseRoot | Out-Null
        $validLeasePath = Join-Path $validLeaseRoot ("valid-$PID.lease")
        $validLeaseText = @(
            "pid=$PID"
            "owner_key=$($selfIdentity.key)"
            "owner_path=$($selfIdentity.path)"
            "worktree=$projectRoot"
            "candidate_commit=$('a' * 40)"
            "candidate_tree=$('b' * 40)"
            'phase=valid-owner'
        ) -join "`n"
        New-OwnedLeaseFile $validLeasePath ($validLeaseText + "`n")
        $validLeaseSha = Get-Sha256 $validLeasePath
        $validLeaseOwners = @(Get-LiveLeaseOwnerIdentities -LeaseDirectory $validLeaseRoot)
        Assert-Contract ($validLeaseOwners.Count -eq 1 -and [string]$validLeaseOwners[0].key -ceq [string]$selfIdentity.key) 'An exact owner key/path lease was not retained as a full identity record.'
        Invoke-ExpectedFailure {
            [void]@(Get-LiveLeaseOwnerIdentities -LeaseDirectory $validLeaseRoot -IdentityByPidForTest { param([int]$LookupPid) throw "INJECTED_LEASE_CENSUS_IDENTITY_AMBIGUITY_$LookupPid" })
        } 'Live lease-owner identity ambiguity fail-closed'
        Invoke-ExpectedFailure {
            Clear-ProvablyStaleLeases -LeaseDirectory $validLeaseRoot -IdentityByPidForTest { param([int]$LookupPid) throw "INJECTED_STALE_CLEANUP_IDENTITY_AMBIGUITY_$LookupPid" }
        } 'Stale lease cleanup identity ambiguity fail-closed'
        Assert-ExpectedSha256 'Ambiguous live-owner lease preservation' $validLeaseSha (Get-Sha256 $validLeasePath)
        Clear-ProvablyStaleLeases -LeaseDirectory $validLeaseRoot
        Assert-ExpectedSha256 'Exact live-owner lease preservation' $validLeaseSha (Get-Sha256 $validLeasePath)

        $leaseChildIdentity = & $identityFactory $leaseChildPid ([long]$selfIdentity.start_ticks + 20000000) 'synthetic-godot-child' 'C:\probe\synthetic-godot.exe'
        $reusedOwnerIdentity = & $identityFactory ([int]$selfIdentity.pid) ([long]$selfIdentity.start_ticks + 10000000) ([string]$selfIdentity.name) ([string]$selfIdentity.path)
        $cimCreationForIdentity = {
            param([object]$Identity)
            $ticks = [long]$Identity.start_ticks
            return [datetime]::new(($ticks - ($ticks % 10)), [DateTimeKind]::Utc)
        }
        $leaseCimProvider = {
            @(
                [pscustomobject]@{ ProcessId = $leaseChildPid; ParentProcessId = $PID; CreationDate = (& $cimCreationForIdentity $leaseChildIdentity) },
                [pscustomobject]@{ ProcessId = $PID; ParentProcessId = 0; CreationDate = (& $cimCreationForIdentity $selfIdentity) }
            )
        }
        $secondReuseCimProvider = {
            @(
                [pscustomobject]@{ ProcessId = $leaseChildPid; ParentProcessId = $PID; CreationDate = (& $cimCreationForIdentity $leaseChildIdentity) },
                [pscustomobject]@{ ProcessId = $PID; ParentProcessId = 0; CreationDate = (& $cimCreationForIdentity $reusedOwnerIdentity) }
            )
        }
        $exactLeaseOwnerResolver = {
            param([int]$LookupPid)
            if ($LookupPid -eq [int]$selfIdentity.pid) { return $selfIdentity }
            return $null
        }
        $reusedLeaseOwnerResolver = {
            param([int]$LookupPid)
            if ($LookupPid -eq [int]$selfIdentity.pid) { return $reusedOwnerIdentity }
            return $null
        }
        Assert-Contract (Test-ProcessHasLeaseAncestor -ProcessId $leaseChildPid -LeaseOwnerIdentities @($selfIdentity) -ProcessIdentity $leaseChildIdentity -CimProviderForTest $leaseCimProvider -IdentityByPidForTest $exactLeaseOwnerResolver) 'Exact live lease-owner ancestry was rejected.'
        Assert-Contract (-not (Test-ProcessHasLeaseAncestor -ProcessId $leaseChildPid -LeaseOwnerIdentities @($selfIdentity) -ProcessIdentity $leaseChildIdentity -CimProviderForTest $secondReuseCimProvider -IdentityByPidForTest $reusedLeaseOwnerResolver)) 'A second PID reuse between owner census and ancestry matching masked an unleased descendant.'
        $predatingChildIdentity = & $identityFactory $leaseChildPid ([long]$selfIdentity.start_ticks - 10000000) 'predating-godot-child' 'C:\probe\predating-godot.exe'
        $parentPidReuseCimProvider = {
            @(
                [pscustomobject]@{ ProcessId = $leaseChildPid; ParentProcessId = $PID; CreationDate = (& $cimCreationForIdentity $predatingChildIdentity) },
                [pscustomobject]@{ ProcessId = $PID; ParentProcessId = 0; CreationDate = (& $cimCreationForIdentity $selfIdentity) }
            )
        }
        Assert-Contract (-not (Test-ProcessHasLeaseAncestor -ProcessId $leaseChildPid -LeaseOwnerIdentities @($selfIdentity) -ProcessIdentity $predatingChildIdentity -CimProviderForTest $parentPidReuseCimProvider -IdentityByPidForTest $exactLeaseOwnerResolver)) 'A replacement lease owner that started after the child masked an old unleased Godot parent edge.'

        $leaseIntermediatePid = [int]($leaseChildPid - 1)
        $leaseIntermediateIdentity = & $identityFactory $leaseIntermediatePid ([long]$selfIdentity.start_ticks + 10000000) 'synthetic-lease-intermediate' 'C:\probe\synthetic-lease-intermediate.exe'
        $replacementIntermediateIdentity = & $identityFactory $leaseIntermediatePid ([long]$leaseChildIdentity.start_ticks + 10000000) 'synthetic-lease-intermediate' 'C:\probe\synthetic-lease-intermediate.exe'
        $threeLevelCimProvider = {
            @(
                [pscustomobject]@{ ProcessId = $leaseChildPid; ParentProcessId = $leaseIntermediatePid; CreationDate = (& $cimCreationForIdentity $leaseChildIdentity) },
                [pscustomobject]@{ ProcessId = $leaseIntermediatePid; ParentProcessId = $PID; CreationDate = (& $cimCreationForIdentity $leaseIntermediateIdentity) },
                [pscustomobject]@{ ProcessId = $PID; ParentProcessId = 0; CreationDate = (& $cimCreationForIdentity $selfIdentity) }
            )
        }
        $threeLevelExactResolver = {
            param([int]$LookupPid)
            if ($LookupPid -eq $leaseChildPid) { return $leaseChildIdentity }
            if ($LookupPid -eq $leaseIntermediatePid) { return $leaseIntermediateIdentity }
            if ($LookupPid -eq [int]$selfIdentity.pid) { return $selfIdentity }
            return $null
        }
        Assert-Contract (
            Test-ProcessHasLeaseAncestor -ProcessId $leaseChildPid -LeaseOwnerIdentities @($selfIdentity) -ProcessIdentity $leaseChildIdentity `
                -CimProviderForTest $threeLevelCimProvider -IdentityByPidForTest $threeLevelExactResolver
        ) 'A valid three-level leaf/intermediate/exact-owner ancestry chain was rejected.'

        $threeLevelReplacementCimProvider = {
            @(
                [pscustomobject]@{ ProcessId = $leaseChildPid; ParentProcessId = $leaseIntermediatePid; CreationDate = (& $cimCreationForIdentity $leaseChildIdentity) },
                [pscustomobject]@{ ProcessId = $leaseIntermediatePid; ParentProcessId = $PID; CreationDate = (& $cimCreationForIdentity $replacementIntermediateIdentity) },
                [pscustomobject]@{ ProcessId = $PID; ParentProcessId = 0; CreationDate = (& $cimCreationForIdentity $selfIdentity) }
            )
        }
        $threeLevelReplacementResolver = {
            param([int]$LookupPid)
            if ($LookupPid -eq $leaseChildPid) { return $leaseChildIdentity }
            if ($LookupPid -eq $leaseIntermediatePid) { return $replacementIntermediateIdentity }
            if ($LookupPid -eq [int]$selfIdentity.pid) { return $selfIdentity }
            return $null
        }
        Assert-Contract (-not (
            Test-ProcessHasLeaseAncestor -ProcessId $leaseChildPid -LeaseOwnerIdentities @($selfIdentity) -ProcessIdentity $leaseChildIdentity `
                -CimProviderForTest $threeLevelReplacementCimProvider -IdentityByPidForTest $threeLevelReplacementResolver
        )) 'A reused intermediate PID that started after the Godot leaf masked an unleased three-level chain.'
        Invoke-ExpectedFailure {
            [void](Test-ProcessHasLeaseAncestor -ProcessId $leaseChildPid -LeaseOwnerIdentities @($selfIdentity) -ProcessIdentity $leaseChildIdentity -CimProviderForTest $leaseCimProvider -IdentityByPidForTest { param([int]$LookupPid) throw "INJECTED_LEASE_OWNER_IDENTITY_AMBIGUITY_$LookupPid" })
        } 'Lease ancestor identity ambiguity fail-closed'

        $setRoot = Join-Path $probeRoot 'artifact-set'
        New-Item -ItemType Directory -Path $setRoot | Out-Null
        [IO.File]::WriteAllText((Join-Path $setRoot 'a.txt'), 'a')
        [IO.File]::WriteAllText((Join-Path $setRoot 'b.txt'), 'b')
        [void](Assert-ExactRelativeFileSet $setRoot @('a.txt', 'b.txt'))
        [IO.File]::WriteAllText((Join-Path $setRoot 'stale.txt'), 'stale')
        Invoke-ExpectedFailure { [void](Assert-ExactRelativeFileSet $setRoot @('a.txt', 'b.txt')) } 'Stale artifact'
        Remove-Item -LiteralPath (Join-Path $setRoot 'stale.txt') -Force
        Remove-Item -LiteralPath (Join-Path $setRoot 'b.txt') -Force
        Invoke-ExpectedFailure { [void](Assert-ExactRelativeFileSet $setRoot @('a.txt', 'b.txt')) } 'Partial artifact'

        $badJson = Join-Path $probeRoot 'malformed.json'
        [IO.File]::WriteAllText($badJson, '{not-json')
        Invoke-ExpectedFailure { [void](Read-JsonObject $badJson) } 'Malformed JSON report'
        $arrayJson = Join-Path $probeRoot 'array.json'
        [IO.File]::WriteAllText($arrayJson, '[]')
        Invoke-ExpectedFailure { [void](Read-JsonObject $arrayJson) } 'Non-object JSON report'
        $structurallyRedStatic = [pscustomobject]@{ tool = 'environment_fixed_slot_static_check'; passed = $false; error_count = 1; errors = @('forced') }
        Invoke-ExpectedFailure { [void](Test-StaticReportContract $structurallyRedStatic @()) } 'Structurally failing static report'

        $goodPng = Join-Path $probeRoot 'good.png'
        $blankPng = Join-Path $probeRoot 'blank.png'
        $wrongSizePng = Join-Path $probeRoot 'wrong-size.png'
        $transparentPng = Join-Path $probeRoot 'transparent.png'
        $badPng = Join-Path $probeRoot 'bad.png'
        New-HostileTestPng $goodPng 4 3
        New-HostileTestPng $blankPng 4 3 -Blank
        New-HostileTestPng $wrongSizePng 3 4
        New-HostileTestPng $transparentPng 4 3 -Transparent
        [IO.File]::WriteAllBytes($badPng, [byte[]](137, 80, 78, 71, 13, 10, 26, 10, 0))
        $goodPngResult = Get-PngEvidence $goodPng 4 3
        Assert-Contract ([bool]$goodPngResult.nonblank) 'Valid nonblank PNG was rejected.'
        Invoke-ExpectedFailure { [void](Get-PngEvidence $blankPng 4 3) } 'Blank PNG'
        Invoke-ExpectedFailure { [void](Get-PngEvidence $wrongSizePng 4 3) } 'Wrong-dimension PNG'
        Invoke-ExpectedFailure { [void](Get-PngEvidence $transparentPng 4 3) } 'Fully transparent PNG'
        Invoke-ExpectedFailure { [void](Get-PngEvidence $badPng 4 3) } 'Malformed PNG'
        & $writeValidateProgress 'png_primitives'
        & $finishValidateStage 'png'

        $savedSourceWidth = $script:expectedSourceWidth
        $savedSourceHeight = $script:expectedSourceHeight
        try {
            # Selftest sources are deliberately small; the same full 8/39
            # validators still enforce their active exact dimensions, while
            # runtime keeps the production 1280x720 constants.
            $script:expectedSourceWidth = 32
            $script:expectedSourceHeight = 18
            $validatorStaticPath = Join-Path $probeRoot 'validator-static.json'
            [IO.File]::WriteAllText($validatorStaticPath, "{}`n")
            $validatorStaticSha = Get-Sha256 $validatorStaticPath
            $q008FixtureRoot = Join-Path $probeRoot 'q008-validator'
            New-Item -ItemType Directory -Path $q008FixtureRoot | Out-Null
            Write-Host ("RW06_1_VISUAL_LAUNCHER_VALIDATE_ONLY_PROGRESS stage=q008_build_start dims={0}x{1}" -f $expectedSourceWidth, $expectedSourceHeight)
            New-Q008ValidatorFixture $q008FixtureRoot $validatorStaticPath $validatorStaticSha
            & $writeValidateProgress 'q008_build_complete'
            $q008FixtureResult = Test-Q008Artifacts $q008FixtureRoot $validatorStaticPath $validatorStaticSha
            & $writeValidateProgress 'q008_green_complete'
            Assert-Contract ([int]$q008FixtureResult.artifact_count -eq 8) 'Q008 full validator fixture did not accept exactly eight artifacts.'
            $q008FixtureReportPath = Join-Path $q008FixtureRoot 'q008_rooms.json'
            $q008FixtureReport = Read-JsonObject $q008FixtureReportPath
            $q008FixtureReport.sheet.cells[0].source_sha256 = '0' * 64
            [IO.File]::WriteAllText($q008FixtureReportPath, (($q008FixtureReport | ConvertTo-Json -Depth 7) + "`n"))
            Invoke-ExpectedFailure { [void](Test-Q008Artifacts $q008FixtureRoot $validatorStaticPath $validatorStaticSha) } 'Q008 sheet/source linkage mutation'
            & $writeValidateProgress 'q008_validator'
            & $finishValidateStage 'q008'

            $validatorRooms = @($expectedQ008Rooms + @(1..15 | ForEach-Object { 'fixture_room_{0:d2}' -f $_ }))
            $allFixtureRoot = Join-Path $probeRoot 'all18-validator'
            New-Item -ItemType Directory -Path $allFixtureRoot | Out-Null
            New-All18ValidatorFixture $allFixtureRoot $validatorStaticPath $validatorStaticSha $validatorRooms
            $allFixtureResult = Test-AllRoomArtifacts $allFixtureRoot $validatorStaticPath $validatorStaticSha $validatorRooms
            Assert-Contract ([int]$allFixtureResult.artifact_count -eq 39) 'All18 full validator fixture did not accept exactly 39 artifacts.'
            $allFixtureReportPath = Join-Path $allFixtureRoot 'contact_sheet_report.json'
            $allFixtureReport = Read-JsonObject $allFixtureReportPath
            $firstRoom = $validatorRooms[0]
            $normalFixturePath = Join-Path $allFixtureRoot "normal\${firstRoom}.png"
            $expandedFixturePath = Join-Path $allFixtureRoot "expanded\${firstRoom}.png"
            [IO.File]::Copy($normalFixturePath, $expandedFixturePath, $true)
            $sameSha = Get-Sha256 $expandedFixturePath
            $firstCapture = @($allFixtureReport.captures | Where-Object { [string]$_.selection.archetype_id -eq $firstRoom })[0]
            $firstCapture.expanded.sha256 = $sameSha
            $firstCapture.expanded.image_validation.sha256 = $sameSha
            [IO.File]::WriteAllText($allFixtureReportPath, (($allFixtureReport | ConvertTo-Json -Depth 7) + "`n"))
            Invoke-ExpectedFailure { [void](Test-AllRoomArtifacts $allFixtureRoot $validatorStaticPath $validatorStaticSha $validatorRooms) } 'All18 normal/expanded identity collapse'
            & $writeValidateProgress 'all18_validator'
            & $finishValidateStage 'all18'
        }
        finally {
            $script:expectedSourceWidth = $savedSourceWidth
            $script:expectedSourceHeight = $savedSourceHeight
        }
        & $writeValidateProgress 'artifact_validators'
        & $finishValidateStage 'artifacts'

        Invoke-ExpectedFailure { [void](Assert-StrictChildPath (Join-Path $projectRoot '..\outside') $projectRoot) } 'Evidence path traversal'
        $reparseTarget = Join-Path $probeRoot 'reparse-target'
        $reparseLink = Join-Path $probeRoot 'reparse-link'
        New-Item -ItemType Directory -Path $reparseTarget | Out-Null
        $junctionCreated = $false
        try {
            New-Item -ItemType Junction -Path $reparseLink -Target $reparseTarget -ErrorAction Stop | Out-Null
            $junctionCreated = $true
            Invoke-ExpectedFailure { [void](Assert-NoReparseAncestors $reparseLink $probeRoot) } 'Reparse-point ancestor'
        }
        catch {
            if ($junctionCreated) { throw }
        }
        finally { if ($junctionCreated -and (Test-Path -LiteralPath $reparseLink)) { Remove-Item -LiteralPath $reparseLink -Force } }
        Assert-Contract $junctionCreated 'Reparse-point hostile fixture could not be created.'

        $rollbackPriorCaseRoot = Join-Path $probeRoot 'rollback-prior'
        $rollbackPriorRoot = Join-Path $rollbackPriorCaseRoot 'owner-root'
        $rollbackPriorEvidenceRoot = Join-Path $rollbackPriorCaseRoot 'evidence-root'
        New-Item -ItemType Directory -Path $rollbackPriorRoot | Out-Null
        New-Item -ItemType Directory -Path $rollbackPriorEvidenceRoot | Out-Null
        $rollbackPriorRetention = Join-Path $rollbackPriorEvidenceRoot 'evidence-retained'
        New-Item -ItemType Directory -Path $rollbackPriorRetention | Out-Null
        $rollbackPriorDestination = Join-Path $rollbackPriorRoot 'q008_rooms.png'
        $rollbackPriorCandidate = Join-Path $rollbackPriorEvidenceRoot 'candidate.png'
        $rollbackPriorBackup = Join-Path $rollbackPriorEvidenceRoot 'previous.backup'
        New-HostileTestPng $rollbackPriorDestination 960 360 -Variant 711
        New-HostileTestPng $rollbackPriorCandidate 960 360 -Variant 712
        [IO.File]::Copy($rollbackPriorDestination, $rollbackPriorBackup, $false)
        $rollbackSeal = New-HostileEvidenceSeal $rollbackPriorEvidenceRoot 'rollback-prior'

        $planNestedCaseRoot = Join-Path $probeRoot 'plan-nested-root-rejection'
        New-Item -ItemType Directory -Path $planNestedCaseRoot | Out-Null
        $planNestedSource = Join-Path $planNestedCaseRoot 'source.png'
        $planNestedOwnerRoot = Join-Path $planNestedCaseRoot 'owner-root'
        $planNestedEvidenceRoot = Join-Path $planNestedOwnerRoot 'nested-evidence-root'
        $planNestedPublicationRoot = Join-Path $planNestedEvidenceRoot 'publication-root'
        $planNestedDestination = Join-Path $planNestedOwnerRoot 'q008_rooms.png'
        New-HostileTestPng $planNestedSource 960 360 -Variant 673
        Invoke-ExpectedFailure {
            [void](New-OwnerReviewPublicationPlan $planNestedSource $planNestedPublicationRoot $planNestedDestination $planNestedOwnerRoot $planNestedEvidenceRoot)
        } 'Nested owner/evidence roots during publication-plan creation'
        Assert-Contract (
            -not (Test-Path -LiteralPath $planNestedOwnerRoot) -and -not (Test-Path -LiteralPath $planNestedEvidenceRoot) `
            -and -not (Test-Path -LiteralPath $planNestedPublicationRoot) -and -not (Test-Path -LiteralPath $planNestedDestination)
        ) 'Publication-plan nested-root rejection created owner/evidence/publication state before failing.'

        $nestedCaseRoot = Join-Path $probeRoot 'nested-root-rejection'
        $nestedOwnerRoot = Join-Path $nestedCaseRoot 'owner-root'
        $nestedEvidenceRoot = Join-Path $nestedOwnerRoot 'nested-evidence-root'
        $nestedPublicationRoot = Join-Path $nestedEvidenceRoot 'evidence-retained'
        New-Item -ItemType Directory -Path $nestedOwnerRoot | Out-Null
        New-Item -ItemType Directory -Path $nestedEvidenceRoot | Out-Null
        New-Item -ItemType Directory -Path $nestedPublicationRoot | Out-Null
        $nestedDestination = Join-Path $nestedOwnerRoot 'q008_rooms.png'
        $nestedCandidate = Join-Path $nestedEvidenceRoot 'candidate.png'
        New-HostileTestPng $nestedCandidate 960 360 -Variant 674
        $nestedSeal = New-HostileEvidenceSeal $nestedEvidenceRoot 'nested-root-rejection'
        $nestedPlan = [ordered]@{
            source = $nestedCandidate; candidate_path = $nestedCandidate
            destination = $nestedDestination; destination_root = $nestedOwnerRoot; evidence_root = $nestedEvidenceRoot; publication_root = $nestedPublicationRoot
            candidate_sha256 = Get-Sha256 $nestedCandidate; previous_exists = $false
            previous_sha256 = ''; backup_path = ''; published = $false
        }
        Invoke-ExpectedFailure { [void](Publish-OwnerReviewAfterSeal $nestedPlan $nestedSeal) } 'Nested owner/evidence roots'
        Assert-Contract (-not (Test-Path -LiteralPath $nestedDestination) -and -not [bool]$nestedPlan.published) 'Nested-root publication rejection mutated the owner destination.'
        $nestedHelperSidecar = Join-Path $nestedOwnerRoot '.q008_rooms.prepublish.nested-helper.bin'
        [IO.File]::WriteAllText($nestedHelperSidecar, 'nested-helper-bytes')
        $nestedHelperSha = Get-Sha256 $nestedHelperSidecar
        try {
            Invoke-ExpectedFailure { [void](Move-OwnerReviewSidecarToPublicationRoot $nestedPlan $nestedHelperSidecar 'nested_root_hostile' $nestedHelperSha) } 'Nested retention helper roots'
            Assert-ExpectedSha256 'Nested-root retention helper preserved source bytes' $nestedHelperSha (Get-Sha256 $nestedHelperSidecar)
        }
        finally {
            if (Test-Path -LiteralPath $nestedHelperSidecar -PathType Leaf) { [IO.File]::Delete($nestedHelperSidecar) }
        }
        Assert-NoOwnerReviewSidecars $nestedDestination 'Nested-root hostile cleanup'

        $foreignSealCaseRoot = Join-Path $probeRoot 'foreign-seal-rejection'
        $foreignSealOwnerRoot = Join-Path $foreignSealCaseRoot 'owner-root'
        $foreignSealEvidenceRoot = Join-Path $foreignSealCaseRoot 'evidence-root'
        $foreignSealPublicationRoot = Join-Path $foreignSealEvidenceRoot 'evidence-retained'
        New-Item -ItemType Directory -Path $foreignSealOwnerRoot | Out-Null
        New-Item -ItemType Directory -Path $foreignSealEvidenceRoot | Out-Null
        New-Item -ItemType Directory -Path $foreignSealPublicationRoot | Out-Null
        $foreignSealDestination = Join-Path $foreignSealOwnerRoot 'q008_rooms.png'
        $foreignSealCandidate = Join-Path $foreignSealEvidenceRoot 'candidate.png'
        New-HostileTestPng $foreignSealCandidate 960 360 -Variant 675
        $foreignSeal = New-HostileEvidenceSeal $foreignSealCaseRoot 'foreign-seal-rejection'
        $foreignSealPlan = [ordered]@{
            source = $foreignSealCandidate; candidate_path = $foreignSealCandidate
            destination = $foreignSealDestination; destination_root = $foreignSealOwnerRoot; evidence_root = $foreignSealEvidenceRoot; publication_root = $foreignSealPublicationRoot
            candidate_sha256 = Get-Sha256 $foreignSealCandidate; previous_exists = $false
            previous_sha256 = ''; backup_path = ''; published = $false
        }
        Invoke-ExpectedFailure { [void](Publish-OwnerReviewAfterSeal $foreignSealPlan $foreignSeal) } 'Foreign evidence seal path'
        Assert-Contract (-not (Test-Path -LiteralPath $foreignSealDestination) -and -not [bool]$foreignSealPlan.published) 'Foreign-seal publication rejection mutated the owner destination.'
        Assert-ExpectedSha256 'Foreign evidence seal rejection preserved candidate' ([string]$foreignSealPlan.candidate_sha256) (Get-Sha256 $foreignSealCandidate)
        Assert-NoOwnerReviewSidecars $foreignSealDestination 'Foreign-seal hostile cleanup'

        $foreignReceiptCaseRoot = Join-Path $probeRoot 'foreign-receipt-rejection'
        $foreignReceiptOwnerRoot = Join-Path $foreignReceiptCaseRoot 'owner-root'
        $foreignReceiptEvidenceRoot = Join-Path $foreignReceiptCaseRoot 'evidence-root'
        $foreignReceiptPublicationRoot = Join-Path $foreignReceiptEvidenceRoot 'evidence-retained'
        New-Item -ItemType Directory -Path $foreignReceiptOwnerRoot | Out-Null
        New-Item -ItemType Directory -Path $foreignReceiptEvidenceRoot | Out-Null
        New-Item -ItemType Directory -Path $foreignReceiptPublicationRoot | Out-Null
        $foreignReceiptDestination = Join-Path $foreignReceiptOwnerRoot 'q008_rooms.png'
        $foreignReceiptCandidate = Join-Path $foreignReceiptEvidenceRoot 'candidate.png'
        New-HostileTestPng $foreignReceiptCandidate 960 360 -Variant 676
        $foreignReceiptSeal = New-HostileEvidenceSeal $foreignReceiptEvidenceRoot 'foreign-receipt-rejection'
        $foreignReceiptPath = Join-Path $foreignReceiptCaseRoot 'foreign_evidence_seal.sha256'
        [IO.File]::Copy([string]$foreignReceiptSeal.hash_path, $foreignReceiptPath, $false)
        $foreignReceiptSeal.hash_path = $foreignReceiptPath
        $foreignReceiptPlan = [ordered]@{
            source = $foreignReceiptCandidate; candidate_path = $foreignReceiptCandidate
            destination = $foreignReceiptDestination; destination_root = $foreignReceiptOwnerRoot; evidence_root = $foreignReceiptEvidenceRoot; publication_root = $foreignReceiptPublicationRoot
            candidate_sha256 = Get-Sha256 $foreignReceiptCandidate; previous_exists = $false
            previous_sha256 = ''; backup_path = ''; published = $false
        }
        Invoke-ExpectedFailure { [void](Publish-OwnerReviewAfterSeal $foreignReceiptPlan $foreignReceiptSeal) } 'Foreign evidence seal receipt path'
        Assert-Contract (-not (Test-Path -LiteralPath $foreignReceiptDestination) -and -not [bool]$foreignReceiptPlan.published) 'Foreign-receipt publication rejection mutated the owner destination.'
        Assert-NoOwnerReviewSidecars $foreignReceiptDestination 'Foreign-receipt hostile cleanup'

        $mismatchedReceiptCaseRoot = Join-Path $probeRoot 'mismatched-receipt-rejection'
        $mismatchedReceiptOwnerRoot = Join-Path $mismatchedReceiptCaseRoot 'owner-root'
        $mismatchedReceiptEvidenceRoot = Join-Path $mismatchedReceiptCaseRoot 'evidence-root'
        $mismatchedReceiptPublicationRoot = Join-Path $mismatchedReceiptEvidenceRoot 'evidence-retained'
        New-Item -ItemType Directory -Path $mismatchedReceiptOwnerRoot | Out-Null
        New-Item -ItemType Directory -Path $mismatchedReceiptEvidenceRoot | Out-Null
        New-Item -ItemType Directory -Path $mismatchedReceiptPublicationRoot | Out-Null
        $mismatchedReceiptDestination = Join-Path $mismatchedReceiptOwnerRoot 'q008_rooms.png'
        $mismatchedReceiptCandidate = Join-Path $mismatchedReceiptEvidenceRoot 'candidate.png'
        New-HostileTestPng $mismatchedReceiptCandidate 960 360 -Variant 677
        $mismatchedReceiptSeal = New-HostileEvidenceSeal $mismatchedReceiptEvidenceRoot 'mismatched-receipt-rejection'
        [IO.File]::WriteAllText([string]$mismatchedReceiptSeal.hash_path, ('0' * 64) + '  evidence_seal.json' + "`n")
        $mismatchedReceiptPlan = [ordered]@{
            source = $mismatchedReceiptCandidate; candidate_path = $mismatchedReceiptCandidate
            destination = $mismatchedReceiptDestination; destination_root = $mismatchedReceiptOwnerRoot; evidence_root = $mismatchedReceiptEvidenceRoot; publication_root = $mismatchedReceiptPublicationRoot
            candidate_sha256 = Get-Sha256 $mismatchedReceiptCandidate; previous_exists = $false
            previous_sha256 = ''; backup_path = ''; published = $false
        }
        Invoke-ExpectedFailure { [void](Publish-OwnerReviewAfterSeal $mismatchedReceiptPlan $mismatchedReceiptSeal) } 'Mismatched evidence seal receipt content'
        Assert-Contract (-not (Test-Path -LiteralPath $mismatchedReceiptDestination) -and -not [bool]$mismatchedReceiptPlan.published) 'Mismatched-receipt publication rejection mutated the owner destination.'
        Assert-NoOwnerReviewSidecars $mismatchedReceiptDestination 'Mismatched-receipt hostile cleanup'

        $censusErrorCaseRoot = Join-Path $probeRoot 'sidecar-census-error'
        $censusErrorOwnerRoot = Join-Path $censusErrorCaseRoot 'owner-root'
        $censusErrorMovedRoot = Join-Path $censusErrorCaseRoot 'owner-root-moved'
        New-Item -ItemType Directory -Path $censusErrorOwnerRoot | Out-Null
        $censusErrorDestination = Join-Path $censusErrorOwnerRoot 'q008_rooms.png'
        $censusErrorHook = { param([string]$Directory) [IO.Directory]::Move($Directory, $censusErrorMovedRoot) }
        try {
            Invoke-ExpectedFailure { [void](Get-OwnerReviewSidecars $censusErrorDestination $censusErrorHook) } 'Owner-review sidecar enumeration error'
            Assert-Contract (-not (Test-Path -LiteralPath $censusErrorOwnerRoot) -and (Test-Path -LiteralPath $censusErrorMovedRoot -PathType Container)) 'Sidecar census error hostile did not execute its enumeration race.'
        }
        finally {
            if ((Test-Path -LiteralPath $censusErrorMovedRoot -PathType Container) -and -not (Test-Path -LiteralPath $censusErrorOwnerRoot)) {
                [IO.Directory]::Move($censusErrorMovedRoot, $censusErrorOwnerRoot)
            }
        }
        Assert-Contract (Test-Path -LiteralPath $censusErrorOwnerRoot -PathType Container) 'Sidecar census error hostile did not restore its owned fixture root.'

        $publishDisappearCaseRoot = Join-Path $probeRoot 'publish-disappearance-prior'
        $publishDisappearRoot = Join-Path $publishDisappearCaseRoot 'owner-root'
        $publishDisappearEvidenceRoot = Join-Path $publishDisappearCaseRoot 'evidence-root'
        New-Item -ItemType Directory -Path $publishDisappearRoot | Out-Null
        New-Item -ItemType Directory -Path $publishDisappearEvidenceRoot | Out-Null
        $publishDisappearRetention = Join-Path $publishDisappearEvidenceRoot 'evidence-retained'
        New-Item -ItemType Directory -Path $publishDisappearRetention | Out-Null
        $publishDisappearDestination = Join-Path $publishDisappearRoot 'q008_rooms.png'
        $publishDisappearCandidate = Join-Path $publishDisappearEvidenceRoot 'candidate.png'
        $publishDisappearBackup = Join-Path $publishDisappearEvidenceRoot 'previous.backup'
        New-HostileTestPng $publishDisappearDestination 960 360 -Variant 681
        New-HostileTestPng $publishDisappearCandidate 960 360 -Variant 682
        [IO.File]::Copy($publishDisappearDestination, $publishDisappearBackup, $false)
        $publishDisappearPlan = [ordered]@{
            source = $publishDisappearCandidate; candidate_path = $publishDisappearCandidate
            destination = $publishDisappearDestination; destination_root = $publishDisappearRoot; evidence_root = $publishDisappearEvidenceRoot; publication_root = $publishDisappearRetention
            candidate_sha256 = Get-Sha256 $publishDisappearCandidate; previous_exists = $true
            previous_sha256 = Get-Sha256 $publishDisappearBackup; backup_path = $publishDisappearBackup; published = $false
        }
        $publishDisappearSeal = New-HostileEvidenceSeal $publishDisappearEvidenceRoot 'publish-disappearance-prior'
        [IO.File]::Delete($publishDisappearDestination)
        Invoke-ExpectedFailure { [void](Publish-OwnerReviewAfterSeal $publishDisappearPlan $publishDisappearSeal) } 'Publication prior-destination disappearance'
        Assert-Contract (-not [bool]$publishDisappearPlan.published -and -not (Test-Path -LiteralPath $publishDisappearDestination)) 'Publication recreated a prior destination after external disappearance.'

        $publishReplacementCaseRoot = Join-Path $probeRoot 'publish-replacement-prior'
        $publishReplacementRoot = Join-Path $publishReplacementCaseRoot 'owner-root'
        $publishReplacementEvidenceRoot = Join-Path $publishReplacementCaseRoot 'evidence-root'
        New-Item -ItemType Directory -Path $publishReplacementRoot | Out-Null
        New-Item -ItemType Directory -Path $publishReplacementEvidenceRoot | Out-Null
        $publishReplacementRetention = Join-Path $publishReplacementEvidenceRoot 'evidence-retained'
        New-Item -ItemType Directory -Path $publishReplacementRetention | Out-Null
        $publishReplacementDestination = Join-Path $publishReplacementRoot 'q008_rooms.png'
        $publishReplacementCandidate = Join-Path $publishReplacementEvidenceRoot 'candidate.png'
        $publishReplacementBackup = Join-Path $publishReplacementEvidenceRoot 'previous.backup'
        New-HostileTestPng $publishReplacementDestination 960 360 -Variant 683
        New-HostileTestPng $publishReplacementCandidate 960 360 -Variant 684
        [IO.File]::Copy($publishReplacementDestination, $publishReplacementBackup, $false)
        $publishReplacementPlan = [ordered]@{
            source = $publishReplacementCandidate; candidate_path = $publishReplacementCandidate
            destination = $publishReplacementDestination; destination_root = $publishReplacementRoot; evidence_root = $publishReplacementEvidenceRoot; publication_root = $publishReplacementRetention
            candidate_sha256 = Get-Sha256 $publishReplacementCandidate; previous_exists = $true
            previous_sha256 = Get-Sha256 $publishReplacementBackup; backup_path = $publishReplacementBackup; published = $false
        }
        $publishReplacementSeal = New-HostileEvidenceSeal $publishReplacementEvidenceRoot 'publish-replacement-prior'
        [IO.File]::Delete($publishReplacementDestination)
        New-HostileTestPng $publishReplacementDestination 960 360 -Variant 685
        $publishExternalSha = Get-Sha256 $publishReplacementDestination
        Invoke-ExpectedFailure { [void](Publish-OwnerReviewAfterSeal $publishReplacementPlan $publishReplacementSeal) } 'Publication prior-destination replacement'
        Assert-Contract (-not [bool]$publishReplacementPlan.published) 'Publication accepted externally replaced prior bytes.'
        Assert-ExpectedSha256 'Publication restored externally replaced prior bytes' $publishExternalSha (Get-Sha256 $publishReplacementDestination)

        $publishAbortCaseRoot = Join-Path $probeRoot 'publish-post-quarantine-abort'
        $publishAbortRoot = Join-Path $publishAbortCaseRoot 'owner-root'
        $publishAbortEvidenceRoot = Join-Path $publishAbortCaseRoot 'evidence-root'
        New-Item -ItemType Directory -Path $publishAbortRoot | Out-Null
        New-Item -ItemType Directory -Path $publishAbortEvidenceRoot | Out-Null
        $publishAbortRetention = Join-Path $publishAbortEvidenceRoot 'evidence-retained'
        New-Item -ItemType Directory -Path $publishAbortRetention | Out-Null
        $publishAbortDestination = Join-Path $publishAbortRoot 'q008_rooms.png'
        $publishAbortCandidate = Join-Path $publishAbortEvidenceRoot 'candidate.png'
        $publishAbortBackup = Join-Path $publishAbortEvidenceRoot 'previous.backup'
        New-HostileTestPng $publishAbortDestination 960 360 -Variant 689
        New-HostileTestPng $publishAbortCandidate 960 360 -Variant 690
        [IO.File]::Copy($publishAbortDestination, $publishAbortBackup, $false)
        $publishAbortPriorSha = Get-Sha256 $publishAbortDestination
        $publishAbortPlan = [ordered]@{
            source = $publishAbortCandidate; candidate_path = $publishAbortCandidate
            destination = $publishAbortDestination; destination_root = $publishAbortRoot; evidence_root = $publishAbortEvidenceRoot; publication_root = $publishAbortRetention
            candidate_sha256 = Get-Sha256 $publishAbortCandidate; previous_exists = $true
            previous_sha256 = $publishAbortPriorSha; backup_path = $publishAbortBackup; published = $false
        }
        $publishAbortSeal = New-HostileEvidenceSeal $publishAbortEvidenceRoot 'publish-post-quarantine-abort'
        $publishAbortHook = { param([string]$Path) throw "Forced post-quarantine pre-commit failure for $Path" }
        Invoke-ExpectedFailure { [void](Publish-OwnerReviewAfterSeal $publishAbortPlan $publishAbortSeal $null $publishAbortHook) } 'Publication post-quarantine pre-commit abort'
        Assert-Contract (-not [bool]$publishAbortPlan.published -and (Test-Path -LiteralPath $publishAbortDestination -PathType Leaf)) 'Publication post-quarantine abort left the primary destination absent.'
        Assert-ExpectedSha256 'Publication post-quarantine abort restored prior bytes' $publishAbortPriorSha (Get-Sha256 $publishAbortDestination)

        $publishRacePriorCaseRoot = Join-Path $probeRoot 'publish-race-prior'
        $publishRacePriorRoot = Join-Path $publishRacePriorCaseRoot 'owner-root'
        $publishRacePriorEvidenceRoot = Join-Path $publishRacePriorCaseRoot 'evidence-root'
        New-Item -ItemType Directory -Path $publishRacePriorRoot | Out-Null
        New-Item -ItemType Directory -Path $publishRacePriorEvidenceRoot | Out-Null
        $publishRacePriorRetention = Join-Path $publishRacePriorEvidenceRoot 'evidence-retained'
        New-Item -ItemType Directory -Path $publishRacePriorRetention | Out-Null
        $publishRacePriorDestination = Join-Path $publishRacePriorRoot 'q008_rooms.png'
        $publishRacePriorCandidate = Join-Path $publishRacePriorEvidenceRoot 'candidate.png'
        $publishRacePriorBackup = Join-Path $publishRacePriorEvidenceRoot 'previous.backup'
        New-HostileTestPng $publishRacePriorDestination 960 360 -Variant 686
        New-HostileTestPng $publishRacePriorCandidate 960 360 -Variant 687
        [IO.File]::Copy($publishRacePriorDestination, $publishRacePriorBackup, $false)
        $publishRacePriorPlan = [ordered]@{
            source = $publishRacePriorCandidate; candidate_path = $publishRacePriorCandidate
            destination = $publishRacePriorDestination; destination_root = $publishRacePriorRoot; evidence_root = $publishRacePriorEvidenceRoot; publication_root = $publishRacePriorRetention
            candidate_sha256 = Get-Sha256 $publishRacePriorCandidate; previous_exists = $true
            previous_sha256 = Get-Sha256 $publishRacePriorBackup; backup_path = $publishRacePriorBackup; published = $false
        }
        $publishRacePriorSeal = New-HostileEvidenceSeal $publishRacePriorEvidenceRoot 'publish-race-prior'
        $publishRacePriorText = 'concurrent-publication-prior'
        $publishRacePriorHook = { param([string]$Path) [IO.File]::WriteAllText($Path, $publishRacePriorText) }
        Invoke-ExpectedFailure { [void](Publish-OwnerReviewAfterSeal $publishRacePriorPlan $publishRacePriorSeal $null $publishRacePriorHook) } 'Publication prior replacement race'
        Assert-Contract (-not [bool]$publishRacePriorPlan.published -and [IO.File]::ReadAllText($publishRacePriorDestination) -ceq $publishRacePriorText) 'Publication overwrote a concurrent prior-destination replacement.'
        Assert-ExpectedSha256 'Publication retained displaced prior bytes' ([string]$publishRacePriorPlan.previous_sha256) (Get-Sha256 ([string]$publishRacePriorPlan.publication_abort_retained_prior.path))
        Assert-Contract ((Normalize-FullPath ([string]$publishRacePriorPlan.publication_abort_retained_prior.path)).StartsWith((Normalize-FullPath $publishRacePriorRetention) + '\', [StringComparison]::OrdinalIgnoreCase)) 'Publication retained prior bytes outside the distinct evidence root.'

        $publishRaceNewCaseRoot = Join-Path $probeRoot 'publish-race-new'
        $publishRaceNewRoot = Join-Path $publishRaceNewCaseRoot 'owner-root'
        $publishRaceNewEvidenceRoot = Join-Path $publishRaceNewCaseRoot 'evidence-root'
        New-Item -ItemType Directory -Path $publishRaceNewRoot | Out-Null
        New-Item -ItemType Directory -Path $publishRaceNewEvidenceRoot | Out-Null
        $publishRaceNewRetention = Join-Path $publishRaceNewEvidenceRoot 'evidence-retained'
        New-Item -ItemType Directory -Path $publishRaceNewRetention | Out-Null
        $publishRaceNewDestination = Join-Path $publishRaceNewRoot 'q008_rooms.png'
        $publishRaceNewCandidate = Join-Path $publishRaceNewEvidenceRoot 'candidate.png'
        New-HostileTestPng $publishRaceNewCandidate 960 360 -Variant 688
        $publishRaceNewPlan = [ordered]@{
            source = $publishRaceNewCandidate; candidate_path = $publishRaceNewCandidate
            destination = $publishRaceNewDestination; destination_root = $publishRaceNewRoot; evidence_root = $publishRaceNewEvidenceRoot; publication_root = $publishRaceNewRetention
            candidate_sha256 = Get-Sha256 $publishRaceNewCandidate; previous_exists = $false
            previous_sha256 = ''; backup_path = ''; published = $false
        }
        $publishRaceNewSeal = New-HostileEvidenceSeal $publishRaceNewEvidenceRoot 'publish-race-new'
        $publishRaceNewText = 'concurrent-publication-new'
        $publishRaceNewHook = { param([string]$Path) [IO.File]::WriteAllText($Path, $publishRaceNewText) }
        Invoke-ExpectedFailure { [void](Publish-OwnerReviewAfterSeal $publishRaceNewPlan $publishRaceNewSeal $publishRaceNewHook) } 'Publication new-destination replacement race'
        Assert-Contract (-not [bool]$publishRaceNewPlan.published -and [IO.File]::ReadAllText($publishRaceNewDestination) -ceq $publishRaceNewText) 'Publication overwrote a concurrent new destination.'

        $rollbackPriorPreviousSha = Get-Sha256 $rollbackPriorDestination
        $rollbackPriorPlan = [ordered]@{
            source = $rollbackPriorCandidate; candidate_path = $rollbackPriorCandidate
            destination = $rollbackPriorDestination; destination_root = $rollbackPriorRoot; evidence_root = $rollbackPriorEvidenceRoot; publication_root = $rollbackPriorRetention
            candidate_sha256 = Get-Sha256 $rollbackPriorCandidate; previous_exists = $true
            previous_sha256 = Get-Sha256 $rollbackPriorBackup; backup_path = $rollbackPriorBackup; published = $true
        }
        $rollbackPriorPlan.published = $false
        [void](Publish-OwnerReviewAfterSeal $rollbackPriorPlan $rollbackSeal)
        Assert-ExpectedSha256 'Prior rollback hostile published candidate' ([string]$rollbackPriorPlan.candidate_sha256) (Get-Sha256 $rollbackPriorDestination)
        $rollbackPriorResult = Restore-OwnerReviewPublication $rollbackPriorPlan
        Assert-Contract ([bool]$rollbackPriorResult.restored -and -not [bool]$rollbackPriorPlan.published) 'Rollback did not restore a prior owner-review artifact.'
        Assert-ExpectedSha256 'Prior rollback hostile restored bytes' $rollbackPriorPreviousSha (Get-Sha256 $rollbackPriorDestination)

        $rollbackNewCaseRoot = Join-Path $probeRoot 'rollback-new'
        $rollbackNewRoot = Join-Path $rollbackNewCaseRoot 'owner-root'
        $rollbackNewEvidenceRoot = Join-Path $rollbackNewCaseRoot 'evidence-root'
        New-Item -ItemType Directory -Path $rollbackNewRoot | Out-Null
        New-Item -ItemType Directory -Path $rollbackNewEvidenceRoot | Out-Null
        $rollbackNewRetention = Join-Path $rollbackNewEvidenceRoot 'evidence-retained'
        New-Item -ItemType Directory -Path $rollbackNewRetention | Out-Null
        $rollbackNewDestination = Join-Path $rollbackNewRoot 'q008_rooms.png'
        $rollbackNewCandidate = Join-Path $rollbackNewEvidenceRoot 'candidate.png'
        New-HostileTestPng $rollbackNewCandidate 960 360 -Variant 713
        $rollbackNewPlan = [ordered]@{
            source = $rollbackNewCandidate; candidate_path = $rollbackNewCandidate
            destination = $rollbackNewDestination; destination_root = $rollbackNewRoot; evidence_root = $rollbackNewEvidenceRoot; publication_root = $rollbackNewRetention
            candidate_sha256 = Get-Sha256 $rollbackNewCandidate; previous_exists = $false
            previous_sha256 = ''; backup_path = ''; published = $false
        }
        $rollbackNewSeal = New-HostileEvidenceSeal $rollbackNewEvidenceRoot 'rollback-new'
        [void](Publish-OwnerReviewAfterSeal $rollbackNewPlan $rollbackNewSeal)
        Assert-ExpectedSha256 'New rollback hostile published candidate' ([string]$rollbackNewPlan.candidate_sha256) (Get-Sha256 $rollbackNewDestination)
        $rollbackNewResult = Restore-OwnerReviewPublication $rollbackNewPlan
        Assert-Contract ([bool]$rollbackNewResult.restored -and -not [bool]$rollbackNewPlan.published -and -not (Test-Path -LiteralPath $rollbackNewDestination)) 'Rollback did not remove a newly created owner-review artifact.'

        $rollbackExternalCaseRoot = Join-Path $probeRoot 'rollback-external'
        $rollbackExternalRoot = Join-Path $rollbackExternalCaseRoot 'owner-root'
        $rollbackExternalEvidenceRoot = Join-Path $rollbackExternalCaseRoot 'evidence-root'
        New-Item -ItemType Directory -Path $rollbackExternalRoot | Out-Null
        New-Item -ItemType Directory -Path $rollbackExternalEvidenceRoot | Out-Null
        $rollbackExternalRetention = Join-Path $rollbackExternalEvidenceRoot 'evidence-retained'
        New-Item -ItemType Directory -Path $rollbackExternalRetention | Out-Null
        $rollbackExternalDestination = Join-Path $rollbackExternalRoot 'q008_rooms.png'
        $rollbackExternalCandidate = Join-Path $rollbackExternalEvidenceRoot 'candidate.png'
        $rollbackExternalBackup = Join-Path $rollbackExternalEvidenceRoot 'previous.backup'
        New-HostileTestPng $rollbackExternalDestination 960 360 -Variant 714
        New-HostileTestPng $rollbackExternalCandidate 960 360 -Variant 715
        [IO.File]::Copy($rollbackExternalDestination, $rollbackExternalBackup, $false)
        $rollbackExternalPlan = [ordered]@{
            source = $rollbackExternalCandidate; candidate_path = $rollbackExternalCandidate
            destination = $rollbackExternalDestination; destination_root = $rollbackExternalRoot; evidence_root = $rollbackExternalEvidenceRoot; publication_root = $rollbackExternalRetention
            candidate_sha256 = Get-Sha256 $rollbackExternalCandidate; previous_exists = $true
            previous_sha256 = Get-Sha256 $rollbackExternalBackup; backup_path = $rollbackExternalBackup; published = $false
        }
        $rollbackExternalSeal = New-HostileEvidenceSeal $rollbackExternalEvidenceRoot 'rollback-external'
        [void](Publish-OwnerReviewAfterSeal $rollbackExternalPlan $rollbackExternalSeal)
        [IO.File]::WriteAllText($rollbackExternalDestination, 'external-replacement-bytes')
        $rollbackExternalSha = Get-Sha256 $rollbackExternalDestination
        $rollbackExternalResult = Restore-OwnerReviewPublication $rollbackExternalPlan
        Assert-Contract ([bool]$rollbackExternalResult.restored -and [bool]$rollbackExternalResult.external_replacement_restored -and -not [bool]$rollbackExternalPlan.published) 'Rollback did not restore a non-owned external replacement after atomic quarantine.'
        Assert-ExpectedSha256 'External replacement hostile preserved bytes' $rollbackExternalSha (Get-Sha256 $rollbackExternalDestination)

        foreach ($hadPrior in @($true, $false)) {
            $label = if ($hadPrior) { 'prior' } else { 'new' }
            $disappearanceCaseRoot = Join-Path $probeRoot ("rollback-disappearance-${label}")
            $disappearanceRoot = Join-Path $disappearanceCaseRoot 'owner-root'
            $disappearanceEvidenceRoot = Join-Path $disappearanceCaseRoot 'evidence-root'
            New-Item -ItemType Directory -Path $disappearanceRoot | Out-Null
            New-Item -ItemType Directory -Path $disappearanceEvidenceRoot | Out-Null
            $disappearanceRetention = Join-Path $disappearanceEvidenceRoot 'evidence-retained'
            New-Item -ItemType Directory -Path $disappearanceRetention | Out-Null
            $disappearanceDestination = Join-Path $disappearanceRoot 'q008_rooms.png'
            $disappearanceCandidate = Join-Path $disappearanceEvidenceRoot 'candidate.png'
            $disappearanceBackup = Join-Path $disappearanceEvidenceRoot 'previous.backup'
            New-HostileTestPng $disappearanceCandidate 960 360 -Variant $(if ($hadPrior) { 721 } else { 722 })
            $disappearancePreviousSha = ''
            if ($hadPrior) {
                New-HostileTestPng $disappearanceDestination 960 360 -Variant 723
                [IO.File]::Copy($disappearanceDestination, $disappearanceBackup, $false)
                $disappearancePreviousSha = Get-Sha256 $disappearanceBackup
            }
            $disappearancePlan = [ordered]@{
                source = $disappearanceCandidate; candidate_path = $disappearanceCandidate
                destination = $disappearanceDestination; destination_root = $disappearanceRoot; evidence_root = $disappearanceEvidenceRoot; publication_root = $disappearanceRetention
                candidate_sha256 = Get-Sha256 $disappearanceCandidate; previous_exists = $hadPrior
                previous_sha256 = $disappearancePreviousSha; backup_path = $(if ($hadPrior) { $disappearanceBackup } else { '' }); published = $false
            }
            $disappearanceSeal = New-HostileEvidenceSeal $disappearanceEvidenceRoot "rollback-disappearance-${label}"
            [void](Publish-OwnerReviewAfterSeal $disappearancePlan $disappearanceSeal)
            [IO.File]::Delete($disappearanceDestination)
            $disappearanceResult = Restore-OwnerReviewPublication $disappearancePlan
            Assert-Contract (
                [bool]$disappearanceResult.restored -and [bool]$disappearanceResult.external_deletion_preserved `
                -and -not [bool]$disappearancePlan.published -and -not (Test-Path -LiteralPath $disappearanceDestination)
            ) "Rollback recreated a ${label} owner-review artifact after external disappearance."
        }

        foreach ($hadPrior in @($true, $false)) {
            $label = if ($hadPrior) { 'prior' } else { 'new' }
            $raceCaseRoot = Join-Path $probeRoot ("rollback-replacement-race-${label}")
            $raceRoot = Join-Path $raceCaseRoot 'owner-root'
            $raceEvidenceRoot = Join-Path $raceCaseRoot 'evidence-root'
            New-Item -ItemType Directory -Path $raceRoot | Out-Null
            New-Item -ItemType Directory -Path $raceEvidenceRoot | Out-Null
            $raceRetention = Join-Path $raceEvidenceRoot 'evidence-retained'
            New-Item -ItemType Directory -Path $raceRetention | Out-Null
            $raceDestination = Join-Path $raceRoot 'q008_rooms.png'
            $raceCandidate = Join-Path $raceEvidenceRoot 'candidate.png'
            $raceBackup = Join-Path $raceEvidenceRoot 'previous.backup'
            New-HostileTestPng $raceCandidate 960 360 -Variant $(if ($hadPrior) { 731 } else { 732 })
            $racePreviousSha = ''
            if ($hadPrior) {
                New-HostileTestPng $raceDestination 960 360 -Variant 733
                [IO.File]::Copy($raceDestination, $raceBackup, $false)
                $racePreviousSha = Get-Sha256 $raceBackup
            }
            $racePlan = [ordered]@{
                source = $raceCandidate; candidate_path = $raceCandidate
                destination = $raceDestination; destination_root = $raceRoot; evidence_root = $raceEvidenceRoot; publication_root = $raceRetention
                candidate_sha256 = Get-Sha256 $raceCandidate; previous_exists = $hadPrior
                previous_sha256 = $racePreviousSha; backup_path = $(if ($hadPrior) { $raceBackup } else { '' }); published = $false
            }
            $raceSeal = New-HostileEvidenceSeal $raceEvidenceRoot "rollback-replacement-race-${label}"
            [void](Publish-OwnerReviewAfterSeal $racePlan $raceSeal)
            $raceExternalText = "concurrent-external-${label}"
            $raceHook = { param([string]$Path) [IO.File]::WriteAllText($Path, $raceExternalText) }
            $raceResult = Restore-OwnerReviewPublication $racePlan $raceHook
            Assert-Contract (
                [bool]$raceResult.restored -and [bool]$raceResult.external_destination_preserved `
                -and [bool]$raceResult.published_candidate_quarantined -and -not [bool]$racePlan.published `
                -and [IO.File]::ReadAllText($raceDestination) -ceq $raceExternalText
            ) "Rollback overwrote a concurrent ${label} owner-review replacement."
            Assert-ExpectedSha256 "Replacement-race ${label} retained candidate" ([string]$racePlan.candidate_sha256) (Get-Sha256 ([string]$raceResult.published_candidate_retained_path))
            if ($hadPrior) {
                Assert-Contract (-not [bool]$raceResult.previous_restored) 'Replacement-race rollback unexpectedly overwrote the concurrent destination with the prior image.'
                Assert-ExpectedSha256 'Replacement-race retained prior backup' $racePreviousSha (Get-Sha256 ([string]$raceResult.unpublished_previous_retained_path))
            }
        }

        $sidecarTypeCaseRoot = Join-Path $probeRoot 'sidecar-type-census'
        $sidecarTypeOwnerRoot = Join-Path $sidecarTypeCaseRoot 'owner-root'
        $sidecarTypeEvidenceRoot = Join-Path $sidecarTypeCaseRoot 'evidence-root'
        New-Item -ItemType Directory -Path $sidecarTypeOwnerRoot | Out-Null
        New-Item -ItemType Directory -Path $sidecarTypeEvidenceRoot | Out-Null
        $sidecarTypeDestination = Join-Path $sidecarTypeOwnerRoot 'q008_rooms.png'

        $directorySidecar = Join-Path $sidecarTypeOwnerRoot '.q008_rooms.publish.hostile-directory'
        New-Item -ItemType Directory -Path $directorySidecar | Out-Null
        try {
            $directorySidecars = @(Get-OwnerReviewSidecars $sidecarTypeDestination)
            Assert-Contract ($directorySidecars.Count -eq 1 -and $directorySidecars[0].FullName -ieq $directorySidecar -and [bool]$directorySidecars[0].PSIsContainer) 'Owner-review sidecar census did not report the hostile directory.'
            Assert-Contract (($directorySidecars[0].Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Ordinary owner-review sidecar fixture unexpectedly became a reparse point.'
            Invoke-ExpectedFailure { Assert-NoOwnerReviewSidecars $sidecarTypeDestination 'Hostile directory sidecar' } 'Owner-review non-file sidecar census'
            Assert-Contract (Test-Path -LiteralPath $directorySidecar -PathType Container) 'Owner-review sidecar gate modified the hostile directory instead of preserving it.'
        }
        finally {
            if (Test-Path -LiteralPath $directorySidecar -PathType Container) { [IO.Directory]::Delete($directorySidecar, $false) }
        }

        $junctionTarget = Join-Path $sidecarTypeEvidenceRoot 'junction-target'
        $junctionSidecar = Join-Path $sidecarTypeOwnerRoot '.q008_rooms.rollback.hostile-junction'
        New-Item -ItemType Directory -Path $junctionTarget | Out-Null
        try {
            New-Item -ItemType Junction -Path $junctionSidecar -Target $junctionTarget -ErrorAction Stop | Out-Null
            $junctionSidecars = @(Get-OwnerReviewSidecars $sidecarTypeDestination)
            Assert-Contract ($junctionSidecars.Count -eq 1 -and $junctionSidecars[0].FullName -ieq $junctionSidecar -and [bool]$junctionSidecars[0].PSIsContainer) 'Owner-review sidecar census did not report the hostile directory junction.'
            Assert-Contract (($junctionSidecars[0].Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) 'Owner-review sidecar census did not identify the hostile reparse point.'
            Invoke-ExpectedFailure { Assert-NoOwnerReviewSidecars $sidecarTypeDestination 'Hostile junction sidecar' } 'Owner-review reparse sidecar census'
            Assert-Contract ((Test-Path -LiteralPath $junctionSidecar -PathType Container) -and (Test-Path -LiteralPath $junctionTarget -PathType Container)) 'Owner-review sidecar gate modified the hostile junction or its target instead of preserving both.'
        }
        finally {
            if (Test-Path -LiteralPath $junctionSidecar) { Remove-Item -LiteralPath $junctionSidecar -Force }
        }
        Assert-Contract (Test-Path -LiteralPath $junctionTarget -PathType Container) 'Hostile sidecar junction cleanup traversed into or removed its target.'
        Assert-Contract (@(Get-OwnerReviewSidecars $sidecarTypeDestination).Count -eq 0) 'Owned sidecar fixture cleanup left residue.'

        $transactionSidecars = @(
            Get-ChildItem -LiteralPath $probeRoot -Force -Recurse |
                Where-Object { $_.Name -match '^\.q008_rooms\.(?:prepublish|publish|rollback|restore)\.' }
        )
        Assert-Contract ($transactionSidecars.Count -eq 0) 'Owner-review transaction hostiles left a destination-side owned sidecar.'
        $retainedTransactionArtifacts = @(Get-ChildItem -LiteralPath $probeRoot -File -Force -Recurse -Filter 'r.*')
        Assert-Contract ($retainedTransactionArtifacts.Count -ge 4) 'Owner-review transaction hostiles did not retain expected displaced bytes as evidence.'
        $transactionOwnerRoots = @(
            Get-ChildItem -LiteralPath $probeRoot -Directory -Force -Recurse |
                Where-Object { $_.Name -ceq 'owner-root' } |
                ForEach-Object { Normalize-FullPath $_.FullName }
        )
        Assert-Contract ($transactionOwnerRoots.Count -ge 10) 'Owner-review transaction hostiles did not create distinct owner roots.'
        foreach ($retainedArtifact in $retainedTransactionArtifacts) {
            Assert-Contract ($retainedArtifact.Directory.Name -ceq 'evidence-retained') "Retained transaction artifact escaped its distinct evidence root: $($retainedArtifact.FullName)"
            Assert-Contract ((Get-Sha256 $retainedArtifact.FullName) -match $shaPattern) "Retained transaction artifact was not hash-verifiable: $($retainedArtifact.FullName)"
            $retainedFullPath = Normalize-FullPath $retainedArtifact.FullName
            foreach ($ownerRoot in $transactionOwnerRoots) {
                Assert-Contract (-not $retainedFullPath.StartsWith($ownerRoot + '\', [StringComparison]::OrdinalIgnoreCase)) "Retained transaction artifact remained under an owner root: $retainedFullPath"
            }
        }

        $reservationFixtureIdentity = Get-ProcessIdentityRecord (Get-Process -Id $PID)
        $reservationFixtureCommit = 'validate-only-candidate-commit'
        $reservationFixtureTree = 'validate-only-candidate-tree'

        $residualReservationRoot = Join-Path $probeRoot 'reservation-residual-retained'
        $residualPhaseRoot = Join-Path $residualReservationRoot 'phase'
        $residualProfileRoot = Join-Path $residualPhaseRoot 'profile'
        $residualLeasePath = Join-Path $residualReservationRoot ("focused-$PID.lease")
        $residualPhaseName = 'validate-residual'
        New-Item -ItemType Directory -Force -Path $residualProfileRoot | Out-Null
        $residualProfileMarker = Join-Path $residualProfileRoot 'marker.txt'
        [IO.File]::WriteAllText($residualProfileMarker, 'profile-must-remain')
        $residualLeaseText = @(
            "pid=$PID"
            "owner_key=$($reservationFixtureIdentity.key)"
            "owner_path=$($reservationFixtureIdentity.path)"
            "worktree=$projectRoot"
            "candidate_commit=$reservationFixtureCommit"
            "candidate_tree=$reservationFixtureTree"
            "phase=$residualPhaseName"
        ) -join "`n"
        New-OwnedLeaseFile $residualLeasePath ($residualLeaseText + "`n")
        $residualLeaseSha = Get-Sha256 $residualLeasePath
        $residualProfileSha = Get-Sha256 $residualProfileMarker
        $residualDisposition = Complete-PhaseReservationCleanup `
            $true $residualLeasePath $residualProfileRoot $residualPhaseRoot $reservationFixtureIdentity $projectRoot `
            $reservationFixtureCommit $reservationFixtureTree $residualPhaseName $true @($reservationFixtureIdentity) ''
        Assert-Contract (
            -not [bool]$residualDisposition.cleanup_authorized -and [bool]$residualDisposition.lease_retained `
            -and [bool]$residualDisposition.profile_retained -and [bool]$residualDisposition.reservation_retained_until_launcher_finalization `
            -and @($residualDisposition.owned_residual_identities).Count -eq 1
        ) 'Owned-residual reservation hostile did not retain the lease/profile with structured identity evidence.'
        Assert-ExpectedSha256 'Owned-residual retained lease' $residualLeaseSha (Get-Sha256 $residualLeasePath)
        Assert-ExpectedSha256 'Owned-residual retained profile' $residualProfileSha (Get-Sha256 $residualProfileMarker)
        Assert-OwnedLease $residualLeasePath $reservationFixtureIdentity $projectRoot $reservationFixtureCommit $reservationFixtureTree $residualPhaseName
        Remove-Item -LiteralPath $residualLeasePath -Force
        Remove-OwnedDirectory $residualProfileRoot $residualPhaseRoot

        $zeroReservationRoot = Join-Path $probeRoot 'reservation-zero-cleaned'
        $zeroPhaseRoot = Join-Path $zeroReservationRoot 'phase'
        $zeroProfileRoot = Join-Path $zeroPhaseRoot 'profile'
        $zeroLeasePath = Join-Path $zeroReservationRoot ("focused-$PID.lease")
        $zeroOtherLeasePath = Join-Path $zeroReservationRoot 'unrelated.lease'
        $zeroPhaseSentinel = Join-Path $zeroPhaseRoot 'preserve.txt'
        $zeroPhaseName = 'validate-zero'
        New-Item -ItemType Directory -Force -Path $zeroProfileRoot | Out-Null
        [IO.File]::WriteAllText((Join-Path $zeroProfileRoot 'owned.txt'), 'owned-profile')
        [IO.File]::WriteAllText($zeroPhaseSentinel, 'unrelated-phase-state')
        [IO.File]::WriteAllText($zeroOtherLeasePath, 'unrelated-lease-state')
        $zeroLeaseText = @(
            "pid=$PID"
            "owner_key=$($reservationFixtureIdentity.key)"
            "owner_path=$($reservationFixtureIdentity.path)"
            "worktree=$projectRoot"
            "candidate_commit=$reservationFixtureCommit"
            "candidate_tree=$reservationFixtureTree"
            "phase=$zeroPhaseName"
        ) -join "`n"
        New-OwnedLeaseFile $zeroLeasePath ($zeroLeaseText + "`n")
        $zeroDisposition = Complete-PhaseReservationCleanup `
            $true $zeroLeasePath $zeroProfileRoot $zeroPhaseRoot $reservationFixtureIdentity $projectRoot `
            $reservationFixtureCommit $reservationFixtureTree $zeroPhaseName $true @() ''
        Assert-Contract (
            [bool]$zeroDisposition.cleanup_authorized -and [bool]$zeroDisposition.lease_released -and [bool]$zeroDisposition.profile_removed `
            -and -not [bool]$zeroDisposition.reservation_retained_until_launcher_finalization `
            -and -not (Test-Path -LiteralPath $zeroLeasePath) -and -not (Test-Path -LiteralPath $zeroProfileRoot)
        ) 'Zero-residual reservation hostile did not remove the exact owned lease/profile.'
        Assert-Contract ((Test-Path -LiteralPath $zeroOtherLeasePath -PathType Leaf) -and (Test-Path -LiteralPath $zeroPhaseSentinel -PathType Leaf)) 'Zero-residual reservation cleanup removed unrelated state.'

        $cimFailureRoot = Join-Path $probeRoot 'reservation-cim-failure-retained'
        $cimFailurePhaseRoot = Join-Path $cimFailureRoot 'phase'
        $cimFailureProfileRoot = Join-Path $cimFailurePhaseRoot 'profile'
        $cimFailureLeasePath = Join-Path $cimFailureRoot ("focused-$PID.lease")
        $cimFailureProfileMarker = Join-Path $cimFailureProfileRoot 'marker.txt'
        $cimFailurePhaseName = 'validate-cim-failure'
        New-Item -ItemType Directory -Force -Path $cimFailureProfileRoot | Out-Null
        [IO.File]::WriteAllText($cimFailureProfileMarker, 'cim-failure-profile-must-remain')
        $cimFailureLeaseText = @(
            "pid=$PID"
            "owner_key=$($reservationFixtureIdentity.key)"
            "owner_path=$($reservationFixtureIdentity.path)"
            "worktree=$projectRoot"
            "candidate_commit=$reservationFixtureCommit"
            "candidate_tree=$reservationFixtureTree"
            "phase=$cimFailurePhaseName"
        ) -join "`n"
        New-OwnedLeaseFile $cimFailureLeasePath ($cimFailureLeaseText + "`n")
        $cimFailureLeaseSha = Get-Sha256 $cimFailureLeasePath
        $cimFailureProfileSha = Get-Sha256 $cimFailureProfileMarker
        $cimFailureRetained = [Collections.Generic.List[object]]::new()
        $cimFailureCompleted = $false
        $cimFailureError = ''
        try {
            [void](Get-AuthoritativeOwnedResidualIdentityRecords `
                -RootIdentity $reservationFixtureIdentity -BaselineIdentityKeys @() -RetainedRecords $cimFailureRetained `
                -AllowedPaths @([string]$reservationFixtureIdentity.path) -CimProviderForTest { throw 'INJECTED_CIM_ENUMERATION_FAILURE' })
            $cimFailureCompleted = $true
        }
        catch { $cimFailureError = $_.Exception.Message }
        $cimFailureDisposition = Complete-PhaseReservationCleanup `
            $true $cimFailureLeasePath $cimFailureProfileRoot $cimFailurePhaseRoot $reservationFixtureIdentity $projectRoot `
            $reservationFixtureCommit $reservationFixtureTree $cimFailurePhaseName $cimFailureCompleted @() $cimFailureError
        Assert-Contract (
            -not [bool]$cimFailureDisposition.census_completed -and [string]$cimFailureDisposition.census_error -match 'INJECTED_CIM_ENUMERATION_FAILURE' `
            -and -not [bool]$cimFailureDisposition.cleanup_authorized -and [bool]$cimFailureDisposition.reservation_retained_until_launcher_finalization
        ) 'Injected CIM enumeration failure did not retain the reservation with structured census error.'
        Assert-ExpectedSha256 'CIM-failure retained lease bytes' $cimFailureLeaseSha (Get-Sha256 $cimFailureLeasePath)
        Assert-ExpectedSha256 'CIM-failure retained profile bytes' $cimFailureProfileSha (Get-Sha256 $cimFailureProfileMarker)
        Assert-OwnedLease $cimFailureLeasePath $reservationFixtureIdentity $projectRoot $reservationFixtureCommit $reservationFixtureTree $cimFailurePhaseName
        Remove-Item -LiteralPath $cimFailureLeasePath -Force
        Remove-OwnedDirectory $cimFailureProfileRoot $cimFailurePhaseRoot

        $identityFailureRoot = Join-Path $probeRoot 'reservation-identity-failure-retained'
        $identityFailurePhaseRoot = Join-Path $identityFailureRoot 'phase'
        $identityFailureProfileRoot = Join-Path $identityFailurePhaseRoot 'profile'
        $identityFailureLeasePath = Join-Path $identityFailureRoot ("focused-$PID.lease")
        $identityFailureProfileMarker = Join-Path $identityFailureProfileRoot 'marker.txt'
        $identityFailurePhaseName = 'validate-identity-failure'
        New-Item -ItemType Directory -Force -Path $identityFailureProfileRoot | Out-Null
        [IO.File]::WriteAllText($identityFailureProfileMarker, 'identity-failure-profile-must-remain')
        $identityFailureLeaseText = @(
            "pid=$PID"
            "owner_key=$($reservationFixtureIdentity.key)"
            "owner_path=$($reservationFixtureIdentity.path)"
            "worktree=$projectRoot"
            "candidate_commit=$reservationFixtureCommit"
            "candidate_tree=$reservationFixtureTree"
            "phase=$identityFailurePhaseName"
        ) -join "`n"
        New-OwnedLeaseFile $identityFailureLeasePath ($identityFailureLeaseText + "`n")
        $identityFailureLeaseSha = Get-Sha256 $identityFailureLeasePath
        $identityFailureProfileSha = Get-Sha256 $identityFailureProfileMarker
        $identityFailureRetained = [Collections.Generic.List[object]]::new()
        $identityFailureCompleted = $false
        $identityFailureError = ''
        $identityFailureHook = { param($Process, $CimEntry) throw 'INJECTED_PROCESS_IDENTITY_FAILURE' }
        try {
            [void](Get-AuthoritativeOwnedResidualIdentityRecords `
                -RootIdentity $reservationFixtureIdentity -BaselineIdentityKeys @() -RetainedRecords $identityFailureRetained `
                -AllowedPaths @([string]$reservationFixtureIdentity.path) -IdentityResolverForTest $identityFailureHook)
            $identityFailureCompleted = $true
        }
        catch { $identityFailureError = $_.Exception.Message }
        $identityFailureDisposition = Complete-PhaseReservationCleanup `
            $true $identityFailureLeasePath $identityFailureProfileRoot $identityFailurePhaseRoot $reservationFixtureIdentity $projectRoot `
            $reservationFixtureCommit $reservationFixtureTree $identityFailurePhaseName $identityFailureCompleted @() $identityFailureError
        Assert-Contract (
            -not [bool]$identityFailureDisposition.census_completed -and [string]$identityFailureDisposition.census_error -match 'INJECTED_PROCESS_IDENTITY_FAILURE' `
            -and -not [bool]$identityFailureDisposition.cleanup_authorized -and [bool]$identityFailureDisposition.reservation_retained_until_launcher_finalization
        ) 'Injected process-identity failure did not retain the reservation with structured census error.'
        Assert-ExpectedSha256 'Identity-failure retained lease bytes' $identityFailureLeaseSha (Get-Sha256 $identityFailureLeasePath)
        Assert-ExpectedSha256 'Identity-failure retained profile bytes' $identityFailureProfileSha (Get-Sha256 $identityFailureProfileMarker)
        Assert-OwnedLease $identityFailureLeasePath $reservationFixtureIdentity $projectRoot $reservationFixtureCommit $reservationFixtureTree $identityFailurePhaseName
        Remove-Item -LiteralPath $identityFailureLeasePath -Force
        Remove-OwnedDirectory $identityFailureProfileRoot $identityFailurePhaseRoot

        Assert-Contract ((Get-DiagnosticLines "SCRIPT ERROR: bad`nWARNING: bad`nObjectDB instances leaked").Count -eq 3) 'Diagnostic scanner missed script, warning, or leak evidence.'
        $unprefixedGodotDiagnostics = [ordered]@{
            leaked_instance = 'Leaked instance: Node:<Node#12345>'
            orphan_node = 'Orphan Node: TestNode (Type: Node)'
            orphan_string_name = 'Orphan StringName: test_symbol'
            unclaimed_string_names = 'StringName: 7 unclaimed string names at exit.'
            rid_allocation = "RID allocation of type 'RendererTextureStorage' survived cleanup."
            rid_allocations_leaked = "RID allocations of type 'RendererCanvasCull' were leaked at exit."
        }
        foreach ($diagnosticFixture in $unprefixedGodotDiagnostics.GetEnumerator()) {
            $detectedDiagnostic = @(Get-DiagnosticLines ([string]$diagnosticFixture.Value))
            Assert-Contract ($detectedDiagnostic.Count -eq 1 -and $detectedDiagnostic[0] -ceq [string]$diagnosticFixture.Value) "Diagnostic scanner missed unprefixed Godot signature: $($diagnosticFixture.Key)"
        }
        $combinedUnprefixedDiagnostics = @($unprefixedGodotDiagnostics.Values) -join "`n"
        Assert-Contract ((Get-DiagnosticLines $combinedUnprefixedDiagnostics).Count -eq $unprefixedGodotDiagnostics.Count) 'Diagnostic scanner did not retain every distinct unprefixed Godot leak signature.'
        Assert-Contract ((Get-DiagnosticLines 'clean output').Count -eq 0) 'Diagnostic scanner rejected clean output.'

        $launcherSource = [IO.File]::ReadAllText($PSCommandPath)
        Assert-Contract (-not [regex]::IsMatch($launcherSource, '(?im)^\s*Start-Process\b')) 'Launcher uses Start-Process.'
        Assert-Contract (-not [regex]::IsMatch($launcherSource, '\.WaitForExit\(\s*\)')) 'Launcher contains an unbounded WaitForExit.'
        $tokens = $null
        $parseErrors = $null
        $ast = [Management.Automation.Language.Parser]::ParseInput($launcherSource, [ref]$tokens, [ref]$parseErrors)
        Assert-Contract ($parseErrors.Count -eq 0) 'Launcher cannot parse its own source.'
        $diagnosticAsts = @($ast.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq 'Get-DiagnosticLines' }, $true))
        Assert-Contract ($diagnosticAsts.Count -eq 1) 'Launcher must define exactly one diagnostic scanner.'
        $diagnosticSource = $diagnosticAsts[0].Extent.Text
        foreach ($requiredDiagnosticSignature in @('Leaked instance:', 'Orphan Node:', 'Orphan StringName:', 'StringName:', 'unclaimed', 'at exit', 'RID allocation', 'RID allocations')) {
            Assert-Contract ($diagnosticSource.Contains($requiredDiagnosticSignature)) "Diagnostic source contract is missing unprefixed Godot signature: $requiredDiagnosticSignature"
        }
        $phaseAsts = @($ast.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq 'Invoke-WindowedCapturePhase' }, $true))
        Assert-Contract ($phaseAsts.Count -eq 1) 'Launcher must define exactly one windowed capture phase.'
        $phaseSource = $phaseAsts[0].Extent.Text
        $postCleanupCensusIndex = $phaseSource.LastIndexOf('Get-AuthoritativeOwnedResidualIdentityRecords', [StringComparison]::Ordinal)
        $reservationCleanupIndex = $phaseSource.IndexOf('$reservationDisposition = Complete-PhaseReservationCleanup', [StringComparison]::Ordinal)
        $phaseReturnIndex = $phaseSource.IndexOf('return $phaseRecord', [StringComparison]::Ordinal)
        Assert-Contract ($postCleanupCensusIndex -ge 0 -and $reservationCleanupIndex -gt $postCleanupCensusIndex -and $phaseReturnIndex -gt $reservationCleanupIndex) 'Phase reservation cleanup is not gated by a final exact owned-identity census.'
        Assert-Contract (-not [regex]::IsMatch($phaseSource, '(?im)^\s*Remove-Item\s+-LiteralPath\s+\$leasePath\b') -and -not [regex]::IsMatch($phaseSource, '(?im)^\s*Remove-OwnedDirectory\s+\$profileRoot\b')) 'Windowed phase directly removes its reservation/profile outside the residual-aware cleanup gate.'
        $authoritativeCensusAsts = @($ast.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq 'Get-AuthoritativeOwnedResidualIdentityRecords' }, $true))
        Assert-Contract ($authoritativeCensusAsts.Count -eq 1) 'Launcher must define exactly one authoritative owned-process residual census.'
        $authoritativeCensusSource = $authoritativeCensusAsts[0].Extent.Text
        Assert-Contract (-not $authoritativeCensusSource.Contains('SilentlyContinue') -and -not [regex]::IsMatch($authoritativeCensusSource, '(?s)catch\s*\{\s*\}')) 'Authoritative owned-process census can suppress enumeration or identity failures.'
        foreach ($requiredCensusText in @('Get-CimInstance Win32_Process -ErrorAction Stop', 'Get-StrictOptionalProcessById', 'Get-StrictCensusIdentityRecord', 'Authoritative CIM enumeration failed', 'parent identity/ancestry is unprovable', 'present relevant PID', 'present retained PID')) {
            Assert-Contract ($authoritativeCensusSource.Contains($requiredCensusText)) "Authoritative owned-process census source contract is missing: $requiredCensusText"
        }
        $leaseStateAsts = @($ast.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq 'Get-ExactLeaseOwnerState' }, $true))
        Assert-Contract ($leaseStateAsts.Count -eq 1) 'Launcher must define exactly one exact lease-owner state resolver.'
        $leaseStateSource = $leaseStateAsts[0].Extent.Text
        foreach ($requiredLeaseStateText in @('Get-ExactProcessIdentityByPid', "fields['owner_key']", "fields['owner_path']", 'owner_identity_mismatch', 'exact_owner_match', 'Test-SamePath')) {
            Assert-Contract ($leaseStateSource.Contains($requiredLeaseStateText)) "Exact lease-owner source contract is missing: $requiredLeaseStateText"
        }
        $staleLeaseAsts = @($ast.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq 'Clear-ProvablyStaleLeases' }, $true))
        Assert-Contract ($staleLeaseAsts.Count -eq 1) 'Launcher must define exactly one stale-lease cleanup gate.'
        $staleLeaseSource = $staleLeaseAsts[0].Extent.Text
        Assert-Contract (-not $staleLeaseSource.Contains('SilentlyContinue')) 'Stale-lease cleanup can suppress enumeration or ownership failures.'
        foreach ($requiredStaleLeaseText in @('$launchMutexName', 'WaitOne(5000)', 'Get-ChildItem', '-ErrorAction Stop', 'Get-ExactLeaseOwnerState', 'Remove-ExactProvablyStaleLease')) {
            Assert-Contract ($staleLeaseSource.Contains($requiredStaleLeaseText)) "Stale-lease cleanup source contract is missing: $requiredStaleLeaseText"
        }
        $leaseIdentityAsts = @($ast.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq 'Get-LiveLeaseOwnerIdentities' }, $true))
        Assert-Contract ($leaseIdentityAsts.Count -eq 1) 'Launcher must define exactly one full-identity live lease-owner census.'
        $leaseIdentitySource = $leaseIdentityAsts[0].Extent.Text
        Assert-Contract (-not $leaseIdentitySource.Contains('SilentlyContinue')) 'Live lease-owner identity census can suppress enumeration or ownership failures.'
        foreach ($requiredLeaseIdentityText in @('Get-ChildItem', '-ErrorAction Stop', 'Get-ExactLeaseOwnerState', 'Assert-NoReparseAncestors', 'Live lease-owner census stable bytes', '$state.identity')) {
            Assert-Contract ($leaseIdentitySource.Contains($requiredLeaseIdentityText)) "Live lease-owner identity source contract is missing: $requiredLeaseIdentityText"
        }
        $leasePidAsts = @($ast.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq 'Get-LiveLeaseOwnerPids' }, $true))
        Assert-Contract ($leasePidAsts.Count -eq 1) 'Launcher must define exactly one compatibility lease-owner PID projection.'
        $leasePidSource = $leasePidAsts[0].Extent.Text
        Assert-Contract ($leasePidSource.Contains('Get-LiveLeaseOwnerIdentities') -and -not $leasePidSource.Contains('SilentlyContinue')) 'Lease-owner PID projection bypasses exact owner identity validation.'
        $leaseAncestorAsts = @($ast.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq 'Test-ProcessHasLeaseAncestor' }, $true))
        Assert-Contract ($leaseAncestorAsts.Count -eq 1) 'Launcher must define exactly one lease-owner ancestry classifier.'
        $leaseAncestorSource = $leaseAncestorAsts[0].Extent.Text
        Assert-Contract (-not $leaseAncestorSource.Contains('SilentlyContinue')) 'Lease-owner ancestry can suppress census or identity failures.'
        foreach ($requiredLeaseAncestorText in @('LeaseOwnerIdentities', 'ProcessIdentity', 'Get-CimInstance Win32_Process -ErrorAction Stop', 'CreationDate', 'Test-CimCreationMatchesProcessStartTicks', '$parentIdentity.start_ticks -gt [long]$cursorIdentity.start_ticks', 'Get-ExactProcessIdentityByPid', '$actual.key', '$expected.key', '$actual.path', '$expected.path', 'Test-SamePath')) {
            Assert-Contract ($leaseAncestorSource.Contains($requiredLeaseAncestorText)) "Lease-owner ancestry source contract is missing: $requiredLeaseAncestorText"
        }
        $newUnownedAsts = @($ast.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq 'Get-NewUnownedGodotRecords' }, $true))
        Assert-Contract ($newUnownedAsts.Count -eq 1) 'Launcher must define exactly one unowned-Godot classifier.'
        $newUnownedSource = $newUnownedAsts[0].Extent.Text
        Assert-Contract ($newUnownedSource.Contains('Get-LiveLeaseOwnerIdentities') -and $newUnownedSource.Contains('-ProcessIdentity $_') -and -not $newUnownedSource.Contains('Get-LiveLeaseOwnerPids') -and -not $newUnownedSource.Contains('SilentlyContinue')) 'Unowned-Godot classifier reduces exact lease-owner identities to bare PIDs, drops the censused child identity, or suppresses failures.'
        $reservationCleanupAsts = @($ast.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq 'Complete-PhaseReservationCleanup' }, $true))
        Assert-Contract ($reservationCleanupAsts.Count -eq 1) 'Launcher must define exactly one phase reservation cleanup gate.'
        $reservationCleanupSource = $reservationCleanupAsts[0].Extent.Text
        foreach ($requiredReservationText in @('CensusCompleted', 'OwnedResidualIdentities', 'cleanup_authorized = $false', 'lease_retained', 'profile_retained', 'reservation_retained_until_launcher_finalization', 'Remove-OwnedDirectory $ProfileRoot $PhaseRoot', 'Remove-Item -LiteralPath $LeasePath -Force')) {
            Assert-Contract ($reservationCleanupSource.Contains($requiredReservationText)) "Phase reservation cleanup source contract is missing: $requiredReservationText"
        }
        $publishAsts = @($ast.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq 'Publish-OwnerReviewAfterSeal' }, $true))
        Assert-Contract ($publishAsts.Count -eq 1) 'Launcher must define exactly one owner-review publication transaction.'
        $publishSource = $publishAsts[0].Extent.Text
        Assert-Contract (-not [regex]::IsMatch($publishSource, '(?im)^\s*(?:Move-Item|Remove-Item)\b')) 'Owner-review publication uses path-based force overwrite/removal.'
        $publishQuarantineIndex = $publishSource.IndexOf('[IO.File]::Move($destination, $priorQuarantine)', [StringComparison]::Ordinal)
        $publishQuarantineHashIndex = $publishSource.IndexOf('$priorQuarantineSha = Get-Sha256 $priorQuarantine', [StringComparison]::Ordinal)
        Assert-Contract ($publishQuarantineIndex -ge 0 -and $publishQuarantineHashIndex -gt $publishQuarantineIndex) 'Owner-review publication does not atomically quarantine prior bytes before hashing.'
        foreach ($requiredPublishText in @('[IO.File]::Move($temporary, $destination)', 'publication_abort_retained_prior', 'publication_abort_restore_error', 'Move-OwnerReviewSidecarToPublicationRoot', 'Assert-NoOwnerReviewSidecars', 'Assert-DisjointRoots', 'EvidenceSeal.hash_path', 'expectedEvidenceSealReceipt', 'no-overwrite restore preserved concurrent destination state')) {
            Assert-Contract ($publishSource.Contains($requiredPublishText)) "Owner-review publication source contract is missing: $requiredPublishText"
        }
        $planAsts = @($ast.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq 'New-OwnerReviewPublicationPlan' }, $true))
        Assert-Contract ($planAsts.Count -eq 1) 'Launcher must define exactly one owner-review publication-plan builder.'
        $planSource = $planAsts[0].Extent.Text
        $planTopologyIndex = $planSource.IndexOf('Assert-DisjointRoots', [StringComparison]::Ordinal)
        $planMutationIndex = $planSource.IndexOf('New-Item', [StringComparison]::Ordinal)
        Assert-Contract ($planTopologyIndex -ge 0 -and $planMutationIndex -gt $planTopologyIndex -and $planSource.Contains('Assert-PathOutsideRoot')) 'Owner-review publication plan does not reject unsafe topology before filesystem mutation.'
        $retentionAsts = @($ast.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq 'Move-OwnerReviewSidecarToPublicationRoot' }, $true))
        Assert-Contract ($retentionAsts.Count -eq 1) 'Launcher must define exactly one owner-review retention helper.'
        $retentionSource = $retentionAsts[0].Extent.Text
        foreach ($requiredRetentionText in @('Assert-DisjointRoots', 'Assert-StrictChildPath $retainedPath $publicationRoot', 'Assert-StrictChildPath $retainedPath $planEvidenceRoot', 'Assert-PathOutsideRoot $retainedPath $destinationRoot')) {
            Assert-Contract ($retentionSource.Contains($requiredRetentionText)) "Owner-review retention source contract is missing: $requiredRetentionText"
        }
        $restoreAsts = @($ast.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq 'Restore-OwnerReviewPublication' }, $true))
        Assert-Contract ($restoreAsts.Count -eq 1) 'Launcher must define exactly one owner-review rollback transaction.'
        $restoreSource = $restoreAsts[0].Extent.Text
        Assert-Contract (-not [regex]::IsMatch($restoreSource, '(?im)^\s*(?:Move-Item|Remove-Item)\b')) 'Owner-review rollback uses path-based overwrite/removal instead of atomic quarantine.'
        $quarantineMoveIndex = $restoreSource.IndexOf('[IO.File]::Move($destination, $quarantinePath)', [StringComparison]::Ordinal)
        $quarantineHashIndex = $restoreSource.IndexOf('$quarantineSha = Get-Sha256 $quarantinePath', [StringComparison]::Ordinal)
        Assert-Contract ($quarantineMoveIndex -ge 0 -and $quarantineHashIndex -gt $quarantineMoveIndex) 'Owner-review rollback does not atomically quarantine before hashing.'
        foreach ($requiredRollbackText in @('external_deletion_preserved', 'external_non_file_preserved', 'quarantined_external', 'published_candidate_retained_path', 'Move-OwnerReviewSidecarToPublicationRoot', 'Assert-NoOwnerReviewSidecars', '[IO.File]::Move($restoreTemporary, $destination)')) {
            Assert-Contract ($restoreSource.Contains($requiredRollbackText)) "Owner-review rollback source contract is missing: $requiredRollbackText"
        }
        $sidecarCensusAsts = @($ast.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq 'Get-OwnerReviewSidecars' }, $true))
        Assert-Contract ($sidecarCensusAsts.Count -eq 1) 'Launcher must define exactly one owner-review sidecar census.'
        $sidecarCensusSource = $sidecarCensusAsts[0].Extent.Text
        Assert-Contract ($sidecarCensusSource.Contains('Get-ChildItem') -and -not [regex]::IsMatch($sidecarCensusSource, '(?im)\bGet-ChildItem\b[^\r\n]*\s-File\b')) 'Owner-review sidecar census excludes non-file or reparse sidecars.'
        Assert-Contract ($sidecarCensusSource.Contains('-ErrorAction Stop') -and -not $sidecarCensusSource.Contains('SilentlyContinue')) 'Owner-review sidecar census can suppress enumeration errors and report a false zero.'
        $validateAsts = @($ast.FindAll({ param($node) $node -is [Management.Automation.Language.IfStatementAst] -and $node.Clauses.Count -eq 1 -and $node.Clauses[0].Item1.Extent.Text.Trim() -ceq '$ValidateOnly' }, $true))
        Assert-Contract ($validateAsts.Count -eq 1) 'Launcher must have exactly one ValidateOnly dispatch.'
        $validateExtent = $validateAsts[0].Extent
        $runtimeLauncherSource = $launcherSource.Substring(0, $validateExtent.StartOffset) + $launcherSource.Substring($validateExtent.EndOffset)
        foreach ($requiredText in @(
            'Get-ExactCandidateIdentity', 'ExpectedLauncherSha256', 'ExpectedCaptureScriptSha256',
            'ExpectedStaticReportSha256', 'ExpectedGodotSha256', 'ExpectedGodotGuiSha256', 'ExpectedPythonSha256', 'refs/remotes/origin',
            'Diagnostics.ProcessStartInfo', 'BaseStream.CopyToAsync', 'Get-StrictNativeExitCode',
            'owner_key=', 'owner_path=', 'EXCLUSIVE.lease', 'Test-FocusedLaunchCapacity', 'Get-NewUnownedGodotRecords',
            'Invoke-StaticCheckerPhase', 'ENVIRONMENT_FIXED_SLOT_STATIC_CHECK PASS',
            'Invoke-SourceContractPhase', 'RW06_1_VISUAL_CAPTURE_SOURCE_CONTRACT PASS',
            "'--log-file'", 'APPDATA', 'Test-Q008Artifacts', 'Test-AllRoomArtifacts',
            'Write-VerifiedJsonSeal', 'New-OwnerReviewPublicationPlan', 'Publish-OwnerReviewAfterSeal',
            'Restore-OwnerReviewPublication', 'Get-ArtifactManifest', 'Remove-OwnedDirectory', 'Assert-NoReparseAncestors'
        )) { Assert-Contract ($runtimeLauncherSource.Contains($requiredText)) "Runtime launcher source contract is missing: $requiredText" }
        Assert-Contract (-not $runtimeLauncherSource.Contains('Copy-VerifiedOwnerReview')) 'Runtime launcher retains the obsolete pre-seal owner-review copy path.'
        Assert-Contract (-not $runtimeLauncherSource.Contains("'--user-data-dir'")) 'Runtime launcher contains unsupported --user-data-dir.'
        Assert-Contract ([regex]::Matches($runtimeLauncherSource, 'Get-NewUnownedGodotRecords\s+@\(\)').Count -ge 2) 'Runtime launcher lacks both pre-reservation and post-reservation unleased censuses.'
        $runtimeEntryIndex = $runtimeLauncherSource.IndexOf('$overallExit = 1', [StringComparison]::Ordinal)
        Assert-Contract ($runtimeEntryIndex -ge 0) 'Runtime launcher entry was not found.'
        $runtimeTransactionSource = $runtimeLauncherSource.Substring($runtimeEntryIndex)
        $completeSealIndex = $runtimeTransactionSource.IndexOf('$evidenceSealRecord = Write-VerifiedJsonSeal', [StringComparison]::Ordinal)
        $publishIndex = $runtimeTransactionSource.IndexOf('$ownerReviewCopy = Publish-OwnerReviewAfterSeal', [StringComparison]::Ordinal)
        $receiptIndex = $runtimeTransactionSource.IndexOf('$publicationReceiptRecord = Write-VerifiedJsonSeal', [StringComparison]::Ordinal)
        $finalSealIndex = $runtimeTransactionSource.IndexOf("'Final sealed manifest'", [StringComparison]::Ordinal)
        $rollbackIndex = $runtimeTransactionSource.IndexOf('$rollbackRecord = Restore-OwnerReviewPublication', [StringComparison]::Ordinal)
        Assert-Contract ($completeSealIndex -ge 0 -and $publishIndex -gt $completeSealIndex -and $receiptIndex -gt $publishIndex -and $finalSealIndex -gt $receiptIndex -and $rollbackIndex -gt $finalSealIndex) 'Owner-review publication is not ordered after a complete evidence seal with receipt/final linkage and post-publication rollback.'
        & $writeValidateProgress 'runtime_source_contract'
        & $finishValidateStage 'source'

        $powerShellExe = Join-Path $PSHOME 'powershell.exe'
        Assert-Contract (Test-Path -LiteralPath $powerShellExe -PathType Leaf) 'PowerShell process probe is unavailable.'
        $quoteEcho = 'space "quoted" value'
        $quoteTrailing = 'C:\path with space\'
        $zeroOut = Join-Path $probeRoot 'zero.stdout.log'
        $zeroErr = Join-Path $probeRoot 'zero.stderr.log'
        $zeroStarted = Start-RedirectedProcess -FilePath $powerShellExe -Arguments @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath, '-ProcessProbeChild', '-ProbeExitCode', '0', '-ProbeEcho', $quoteEcho, '-ProbeTrailing', $quoteTrailing, '-ProbeEmpty', '') -StdoutPath $zeroOut -StderrPath $zeroErr -ProcessKind Exact -TimeoutSec 10
        $zero = Complete-RedirectedProcess $zeroStarted Exact
        Assert-Contract (-not $zero.timed_out -and $zero.native_exit_observed -and $zero.native_exit_code -eq 0 -and $zero.native_exit_type -eq 'System.Int32' -and $zero.effective_exit_code -eq 0 -and [string]::IsNullOrWhiteSpace([string]$zero.error)) 'Direct zero/quoting probe failed.'
        $zeroText = [IO.File]::ReadAllText($zeroOut)
        Assert-Contract ($zeroText.Contains('space \"quoted\" value') -and $zeroText.Contains('C:\\path with space\\') -and $zeroText.Contains('"empty":""')) 'Windows native quoting changed quote/trailing slash/empty arguments.'

        $volume = 262144
        $volumeOut = Join-Path $probeRoot 'volume.stdout.log'
        $volumeErr = Join-Path $probeRoot 'volume.stderr.log'
        $volumeStarted = Start-RedirectedProcess -FilePath $powerShellExe -Arguments @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath, '-ProcessProbeChild', '-ProbeExitCode', '37', '-ProbeVolumeBytes', "$volume") -StdoutPath $volumeOut -StderrPath $volumeErr -ProcessKind Exact -TimeoutSec 15
        $volumeResult = Complete-RedirectedProcess $volumeStarted Exact
        Assert-Contract ($volumeResult.native_exit_observed -and $volumeResult.native_exit_code -eq 37 -and $volumeResult.native_exit_type -eq 'System.Int32' -and $volumeResult.effective_exit_code -eq 37) 'High-volume nonzero probe lost its integer exit.'
        Assert-Contract ((Get-Item $volumeOut).Length -ge $volume -and (Get-Item $volumeErr).Length -ge $volume) 'High-volume probe did not drain both pipes.'

        $timeoutOut = Join-Path $probeRoot 'timeout.stdout.log'
        $timeoutErr = Join-Path $probeRoot 'timeout.stderr.log'
        $timeoutStarted = Start-RedirectedProcess -FilePath $powerShellExe -Arguments @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath, '-ProcessProbeChild', '-ProbeSleepMsec', '10000') -StdoutPath $timeoutOut -StderrPath $timeoutErr -ProcessKind Exact -TimeoutSec 1
        $timeoutPid = [int]$timeoutStarted.process_id
        $timeoutResult = Complete-RedirectedProcess $timeoutStarted Exact
        Assert-Contract ($timeoutResult.timed_out -and $timeoutResult.effective_exit_code -eq 124) 'Timeout probe did not return bounded timeout 124.'
        Assert-Contract ($null -eq (Get-Process -Id $timeoutPid -ErrorAction SilentlyContinue)) 'Timeout probe left its exact child alive.'

        $pumpOut = Join-Path $probeRoot 'pump.stdout.log'
        $pumpErr = Join-Path $probeRoot 'pump.stderr.log'
        $pumpFailed = $false
        $pumpProof = $null
        try { [void](Start-RedirectedProcess -FilePath $powerShellExe -Arguments @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath, '-ProcessProbeChild', '-ProbeSleepMsec', '10000') -StdoutPath $pumpOut -StderrPath $pumpErr -ProcessKind Exact -TimeoutSec 10 -ForceSecondPumpFailureForTest) }
        catch { $pumpFailed = $true; $pumpProof = Get-OwnedProcessStartProofFromException $_.Exception }
        Assert-Contract ($pumpFailed -and [bool]$pumpProof.started -and -not (Test-LiveProcessMatchesIdentity $pumpProof.process_identity)) 'Redirect-pump setup failure did not retain proof and clean its exact child.'
        $identityFailed = $false
        $identityFailureProof = $null
        try { [void](Start-RedirectedProcess -FilePath $powerShellExe -Arguments @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath, '-ProcessProbeChild', '-ProbeSleepMsec', '10000') -StdoutPath $pumpOut -StderrPath $pumpErr -ProcessKind Exact -TimeoutSec 10 -ForceIdentityFailureForTest) }
        catch { $identityFailed = $true; $identityFailureProof = Get-OwnedProcessStartProofFromException $_.Exception }
        Assert-Contract ($identityFailed -and [bool]$identityFailureProof.started -and (Test-ProcessIdentityProofShape $identityFailureProof.process_identity) -and -not (Test-LiveProcessMatchesIdentity $identityFailureProof.process_identity)) 'Identity-acquisition failure did not retain fallback PID/start/name/path proof and clean its exact child.'
        & $writeValidateProgress 'bounded_process_probes'
    }
    finally {
        if (Test-Path -LiteralPath $probeRoot) { Remove-OwnedDirectory $probeRoot (Join-Path $projectRoot '.tmp\rw06_1\visual_launcher_selftest') }
    }
    Assert-Contract (@(Get-NewUnownedGodotRecords $godotBeforeKeys).Count -eq 0) 'ValidateOnly observed a new unowned Godot process.'
    & $writeValidateProgress 'final_census'
    $validateSummary = [ordered]@{
        contract = 'rw06_1_visual_capture_launcher'
        outcome = 'pass'
        q009_classification = 'normal_isolated_focused'
        expected_artifacts = [ordered]@{ q008 = 8; all18 = 39 }
        hostile = @('dirty_tree', 'commit_tree_hash_drift', 'interpreter_path_hash_drift', 'lease_race', 'lease_pid_binding', 'lease_disappearance', 'stale_reused_pid_lease_excluded', 'stale_reused_pid_lease_exact_cleanup', 'lease_ancestor_second_reuse_rejected', 'lease_ancestor_parent_pid_reuse_rejected', 'lease_ancestor_intermediate_parent_pid_reuse_rejected', 'lease_ancestor_identity_ambiguity_fail_closed', 'pid_reuse_lineage', 'quoting', 'dual_pipe_pressure', 'timeout', 'redirect_setup', 'identity_setup_cleanup', 'owned_residual_reservation_retained', 'zero_residual_reservation_cleaned', 'authoritative_cim_failure_reservation_retained', 'authoritative_identity_failure_reservation_retained', 'stale_partial_artifacts', 'malformed_report', 'malformed_blank_transparent_wrong_size_png', 'full_q008_8_artifact_validator', 'full_all18_39_artifact_validator', 'sheet_source_linkage', 'normal_expanded_identity', 'reparse_path', 'owner_review_plan_nested_roots_zero_creation', 'owner_review_nested_roots_rejected', 'owner_review_retention_outside_owner_root', 'owner_review_foreign_seal_rejected', 'owner_review_foreign_receipt_rejected', 'owner_review_mismatched_receipt_rejected', 'owner_review_census_error_fail_closed', 'owner_review_publish_prior_disappearance', 'owner_review_publish_prior_replacement', 'owner_review_publish_post_quarantine_abort', 'owner_review_publish_prior_replacement_race', 'owner_review_publish_new_replacement_race', 'owner_review_rollback_prior', 'owner_review_rollback_new', 'owner_review_external_replacement_preserved', 'owner_review_prior_disappearance_preserved', 'owner_review_new_disappearance_preserved', 'owner_review_prior_replacement_race_preserved', 'owner_review_new_replacement_race_preserved', 'owner_review_retained_bytes_confined', 'owner_review_non_file_sidecar_detected', 'owner_review_reparse_sidecar_detected', 'owner_review_zero_destination_sidecars', 'sealed_before_publish_source_order', 'diagnostics_leaks', 'unprefixed_godot_leak_signatures')
        godot_before = $godotBefore.Count
        godot_after = @(Get-LiveGodotIdentityRecords).Count
    }
    Write-Host ('RW06_1_VISUAL_LAUNCHER_VALIDATE_ONLY PASS ' + ($validateSummary | ConvertTo-Json -Compress -Depth 5))
    exit 0
}


$overallExit = 1
$outcome = 'invalid'
$launcherError = ''
$startedUtc = [DateTime]::UtcNow
$phaseRecords = [Collections.Generic.List[object]]::new()
$q008Validation = $null
$allRoomValidation = $null
$ownerReviewCopy = $null
$ownerReviewSource = ''
$publicationPlan = $null
$evidenceSealRecord = $null
$publicationReceiptRecord = $null
$rollbackRecord = [ordered]@{ required = $false; restored = $true }
$candidate = $null
$trackedFiles = [ordered]@{}
$staticContract = $null
$staticOriginal = ''
$staticSnapshot = ''
$cacheInitiallyAbsent = $false
$cacheCleanupSucceeded = $false
$script:visualOwnedProcessStarted = $false
$launcherIdentity = $null
$environmentSnapshot = [ordered]@{
    APPDATA = [Environment]::GetEnvironmentVariable('APPDATA', 'Process')
    LOCALAPPDATA = [Environment]::GetEnvironmentVariable('LOCALAPPDATA', 'Process')
    XDG_DATA_HOME = [Environment]::GetEnvironmentVariable('XDG_DATA_HOME', 'Process')
    XDG_CACHE_HOME = [Environment]::GetEnvironmentVariable('XDG_CACHE_HOME', 'Process')
    XDG_CONFIG_HOME = [Environment]::GetEnvironmentVariable('XDG_CONFIG_HOME', 'Process')
}
$baselineGlobalGodot = @()
$baselineGlobalKeys = @()
$evidenceBase = Join-Path $projectRoot '.tmp\rw06_1\visual_evidence'
$stamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')
$requestedEvidenceRoot = $EvidenceRoot
$evidenceSetupError = ''
$evidenceSetupFatal = ''
try {
    [void](Assert-NoReparseAncestors $evidenceBase $projectRoot)
    if (-not (Test-Path -LiteralPath $evidenceBase)) { New-Item -ItemType Directory -Force -Path $evidenceBase | Out-Null }
    [void](Assert-NoReparseAncestors $evidenceBase $projectRoot)
    $requestedTarget = if ([string]::IsNullOrWhiteSpace($requestedEvidenceRoot)) {
        Join-Path $evidenceBase ("capture-{0}-{1}-{2}" -f $stamp, $PID, [guid]::NewGuid().ToString('N'))
    }
    else { $requestedEvidenceRoot }
    $requestedTarget = Normalize-FullPath $requestedTarget
    [void](Assert-StrictChildPath $requestedTarget $evidenceBase)
    [void](Assert-NoReparseAncestors $requestedTarget $projectRoot)
    if (Test-Path -LiteralPath $requestedTarget) { throw "EvidenceRoot already exists; stale evidence is forbidden: $requestedTarget" }
    New-Item -ItemType Directory -Path $requestedTarget | Out-Null
    [void](Assert-NoReparseAncestors $requestedTarget $projectRoot)
    $EvidenceRoot = $requestedTarget
}
catch {
    $evidenceSetupError = 'Requested evidence-root setup failed: ' + $_.Exception.Message
    try {
        [void](Assert-NoReparseAncestors $evidenceBase $projectRoot)
        if (-not (Test-Path -LiteralPath $evidenceBase)) { New-Item -ItemType Directory -Force -Path $evidenceBase | Out-Null }
        [void](Assert-NoReparseAncestors $evidenceBase $projectRoot)
        $fallbackTarget = Normalize-FullPath (Join-Path $evidenceBase ("invalid-setup-{0}-{1}-{2}" -f $stamp, $PID, [guid]::NewGuid().ToString('N')))
        [void](Assert-StrictChildPath $fallbackTarget $evidenceBase)
        [void](Assert-NoReparseAncestors $fallbackTarget $projectRoot)
        New-Item -ItemType Directory -Path $fallbackTarget | Out-Null
        [void](Assert-NoReparseAncestors $fallbackTarget $projectRoot)
        $EvidenceRoot = $fallbackTarget
    }
    catch { $evidenceSetupFatal = $evidenceSetupError + ' | Safe fallback evidence-root setup failed: ' + $_.Exception.Message }
}
if (-not [string]::IsNullOrWhiteSpace($evidenceSetupFatal)) {
    $fatalSetupRecord = [ordered]@{
        schema = 'rw06_1_visual_capture_setup_failure/v1'
        outcome = 'invalid'
        exit_code = 1
        launcher_error = $evidenceSetupFatal
        requested_evidence_root = $requestedEvidenceRoot
        safe_manifest_possible = $false
        started_utc = $startedUtc.ToString('o')
        completed_utc = [DateTime]::UtcNow.ToString('o')
    }
    [Console]::Error.WriteLine('RW06_1_VISUAL_CAPTURE_SETUP_INVALID ' + ($fatalSetupRecord | ConvertTo-Json -Compress -Depth 6))
    exit 1
}
$manifestPath = Join-Path $EvidenceRoot 'manifest.json'
$manifestShaPath = Join-Path $EvidenceRoot 'manifest.sha256'
$evidenceSealPath = Join-Path $EvidenceRoot 'evidence_seal.json'
$evidenceSealShaPath = Join-Path $EvidenceRoot 'evidence_seal.sha256'
$publicationReceiptPath = Join-Path $EvidenceRoot 'publication_receipt.json'
$publicationReceiptShaPath = Join-Path $EvidenceRoot 'publication_receipt.sha256'

try {
    $launcherIdentity = Get-ProcessIdentityRecord (Get-Process -Id $PID)
    $baselineCensus = Get-LiveGodotCensus
    $baselineGlobalGodot = @($baselineCensus.records)
    $baselineGlobalKeys = @($baselineGlobalGodot | ForEach-Object { [string]$_.key })
    if (-not [string]::IsNullOrWhiteSpace($evidenceSetupError)) { throw $evidenceSetupError }
    if (-not $AuthorizeCapture) { throw 'Windowed visual evidence requires explicit -AuthorizeCapture.' }
    if ($LeaseWaitTimeoutSec -lt 1 -or $ProcessTimeoutSec -lt 1) { throw 'Lease/process timeouts must be positive.' }
    if (-not (Test-SamePath $GodotPath $canonicalGodotPath)) { throw 'Only the canonical Godot 4.6 console executable is accepted.' }
    if (-not (Test-SamePath $PythonPath $canonicalPythonPath)) { throw 'Only the release-pinned canonical Python executable is accepted.' }
    if ($ExpectedPythonSha256 -ine $canonicalPythonSha256) { throw 'ExpectedPythonSha256 must equal the release-pinned Python SHA-256.' }
    if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) { throw "Canonical Godot executable is missing: $GodotPath" }
    if (-not (Test-Path -LiteralPath $canonicalGodotGuiPath -PathType Leaf)) { throw "Canonical Godot GUI child is missing: $canonicalGodotGuiPath" }
    if (-not (Test-Path -LiteralPath $canonicalPythonPath -PathType Leaf)) { throw "Release-pinned Python executable is missing: $canonicalPythonPath" }
    $PythonPath = Normalize-FullPath $PythonPath
    $cacheInitiallyAbsent = -not (Test-Path -LiteralPath $projectCacheRoot)
    if (-not $cacheInitiallyAbsent) { throw 'Visual evidence requires an initially absent project .godot cache.' }

    if (-not [IO.Path]::IsPathRooted($StaticReportPath)) { $StaticReportPath = Join-Path $projectRoot $StaticReportPath }
    $staticOriginal = Normalize-FullPath $StaticReportPath
    $candidate = Get-ExactCandidateIdentity $projectRoot $ExpectedCommit $ExpectedTree
    Assert-ExpectedSha256 'Canonical Godot binary' $ExpectedGodotSha256 (Get-Sha256 $GodotPath)
    Assert-ExpectedSha256 'Canonical Godot GUI binary' $ExpectedGodotGuiSha256 (Get-Sha256 $canonicalGodotGuiPath)
    Assert-ExpectedSha256 'Release-pinned canonical Python binary' $canonicalPythonSha256 (Get-Sha256 $PythonPath)
    Assert-ExpectedSha256 'Launcher' $ExpectedLauncherSha256 (Get-Sha256 $PSCommandPath)
    Assert-ExpectedSha256 'Capture script' $ExpectedCaptureScriptSha256 (Get-Sha256 (Join-Path $projectRoot ($captureRelativePath.Replace('/', '\'))))
    Assert-ExpectedSha256 'Static report' $ExpectedStaticReportSha256 (Get-Sha256 $staticOriginal)
    $trackedFiles.launcher = Get-TrackedFileIdentity $projectRoot $ExpectedCommit $launcherRelativePath
    $trackedFiles.capture_script = Get-TrackedFileIdentity $projectRoot $ExpectedCommit $captureRelativePath
    $trackedFiles.source_contract = Get-TrackedFileIdentity $projectRoot $ExpectedCommit $sourceContractRelativePath
    $trackedFiles.static_checker = Get-TrackedFileIdentity $projectRoot $ExpectedCommit $staticCheckerRelativePath
    $trackedFiles.archetypes = Get-TrackedFileIdentity $projectRoot $ExpectedCommit $archetypesRelativePath
    $trackedFiles.project_settings = Get-TrackedFileIdentity $projectRoot $ExpectedCommit $projectSettingsRelativePath
    Assert-ExpectedSha256 'Tracked launcher' $ExpectedLauncherSha256 ([string]$trackedFiles.launcher.sha256)
    Assert-ExpectedSha256 'Tracked capture script' $ExpectedCaptureScriptSha256 ([string]$trackedFiles.capture_script.sha256)

    $staticRoot = Join-Path $EvidenceRoot '00-static-check'
    $staticSnapshot = Join-Path $staticRoot 'slot_report.json'
    $staticPhase = Invoke-StaticCheckerPhase $staticRoot $trackedFiles.static_checker $staticSnapshot
    [void]$phaseRecords.Add($staticPhase)
    if (-not [bool]$staticPhase.passed) { throw 'Fresh exact-candidate static checker failed provenance/output acceptance.' }
    Assert-ExpectedSha256 'Fresh static report' $ExpectedStaticReportSha256 (Get-Sha256 $staticSnapshot)
    $staticReport = Read-JsonObject $staticSnapshot
    $authoredRoomIds = @(Get-AuthoredArchetypeIds (Join-Path $projectRoot ($archetypesRelativePath.Replace('/', '\'))))
    $staticContract = Test-StaticReportContract $staticReport $authoredRoomIds

    $sourceContractPhase = Invoke-SourceContractPhase (Join-Path $EvidenceRoot '01-source-contract') $trackedFiles.source_contract
    [void]$phaseRecords.Add($sourceContractPhase)
    if (-not [bool]$sourceContractPhase.passed) { throw 'Engine-free visual capture source contract failed.' }

    [void](Assert-RunInputs $staticOriginal $staticSnapshot $false)
    $q008 = Invoke-WindowedCapturePhase 'q008' '--rw06-1-q008' (Join-Path $EvidenceRoot '02-q008') $staticOriginal $staticSnapshot $script:visualOwnedProcessStarted $launcherIdentity
    [void]$phaseRecords.Add($q008)
    if ([bool]$q008.process_started) { $script:visualOwnedProcessStarted = $true }
    if (-not [bool]$q008.passed) { throw 'Q008 windowed phase failed process/marker/diagnostic acceptance.' }
    $q008Validation = Test-Q008Artifacts ([string]$q008.capture_root) $staticSnapshot $ExpectedStaticReportSha256

    [void](Assert-RunInputs $staticOriginal $staticSnapshot $script:visualOwnedProcessStarted)
    $allRooms = Invoke-WindowedCapturePhase 'all18' '--rw06-1-contact-sheet' (Join-Path $EvidenceRoot '03-all18') $staticOriginal $staticSnapshot $script:visualOwnedProcessStarted $launcherIdentity
    [void]$phaseRecords.Add($allRooms)
    if ([bool]$allRooms.process_started) { $script:visualOwnedProcessStarted = $true }
    if (-not [bool]$allRooms.passed) { throw 'All-18 windowed phase failed process/marker/diagnostic acceptance.' }
    $allRoomValidation = Test-AllRoomArtifacts ([string]$allRooms.capture_root) $staticSnapshot $ExpectedStaticReportSha256 @($staticContract.room_ids)

    Assert-ExpectedSha256 'Static report after both phases' $ExpectedStaticReportSha256 (Get-Sha256 $staticOriginal)
    Assert-ExpectedSha256 'Static snapshot after both phases' $ExpectedStaticReportSha256 (Get-Sha256 $staticSnapshot)
    Assert-ExpectedSha256 'Canonical Godot GUI binary after both phases' $ExpectedGodotGuiSha256 (Get-Sha256 $canonicalGodotGuiPath)
    $ownerReviewSource = Join-Path ([string]$q008.capture_root) 'q008_rooms.png'
    $outcome = 'pass'
    $overallExit = 0
}
catch {
    $launcherError = $_.Exception.Message
    $outcome = 'invalid'
    $overallExit = 1
}
finally {
    try {
        if (Test-Path -LiteralPath $projectCacheRoot) {
            if (-not $cacheInitiallyAbsent -or -not $script:visualOwnedProcessStarted) { throw 'Project cache appeared without exact owned-process start proof; refusing cleanup.' }
            Remove-OwnedDirectory $projectCacheRoot $projectRoot
        }
        $cacheCleanupSucceeded = -not (Test-Path -LiteralPath $projectCacheRoot)
    }
    catch {
        $cacheCleanupSucceeded = $false
        $launcherError = ([string]$launcherError + ' | Cache cleanup: ' + $_.Exception.Message).Trim(' ', '|')
        $outcome = 'invalid'
        $overallExit = 1
    }
}

$postEnvironment = [ordered]@{
    APPDATA = [Environment]::GetEnvironmentVariable('APPDATA', 'Process')
    LOCALAPPDATA = [Environment]::GetEnvironmentVariable('LOCALAPPDATA', 'Process')
    XDG_DATA_HOME = [Environment]::GetEnvironmentVariable('XDG_DATA_HOME', 'Process')
    XDG_CACHE_HOME = [Environment]::GetEnvironmentVariable('XDG_CACHE_HOME', 'Process')
    XDG_CONFIG_HOME = [Environment]::GetEnvironmentVariable('XDG_CONFIG_HOME', 'Process')
}
$environmentRestored = (($environmentSnapshot | ConvertTo-Json -Compress) -ceq ($postEnvironment | ConvertTo-Json -Compress))
$postCandidate = $null
try { $postCandidate = Get-ExactCandidateIdentity $projectRoot $ExpectedCommit $ExpectedTree }
catch {
    $launcherError = ([string]$launcherError + ' | Final candidate: ' + $_.Exception.Message).Trim(' ', '|')
    $outcome = 'invalid'
    $overallExit = 1
}
$newUnownedGodot = @()
$allUnleasedGodot = @()
$finalLiveGodot = @()
$finalCensusError = ''
try {
    $finalCensus = Get-LiveGodotCensus
    $finalLiveGodot = @($finalCensus.records)
    $newUnownedGodot = @(Get-NewUnownedGodotRecords $baselineGlobalKeys)
    $allUnleasedGodot = @(Get-NewUnownedGodotRecords @())
}
catch {
    $finalCensusError = $_.Exception.Message
    $launcherError = ([string]$launcherError + ' | Final Godot census: ' + $finalCensusError).Trim(' ', '|')
    $outcome = 'invalid'
    $overallExit = 1
}
$ownedLeaseResiduals = @()
if (Test-Path -LiteralPath $leaseRoot) { $ownedLeaseResiduals = @(Get-ChildItem -LiteralPath $leaseRoot -Filter ("rw06_1-visual-*-{0}.lease" -f $PID) -File -ErrorAction SilentlyContinue) }
$profileResiduals = @(Get-ChildItem -LiteralPath $EvidenceRoot -Directory -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -ceq 'profile' })
$binaryIntegrity = $false
try {
    Assert-Contract (Test-SamePath $PythonPath $canonicalPythonPath) 'Final Python path is not release-pinned.'
    Assert-Contract ($ExpectedPythonSha256 -ieq $canonicalPythonSha256) 'Final Python expected SHA-256 is not release-pinned.'
    Assert-ExpectedSha256 'Canonical Godot final binary' $ExpectedGodotSha256 (Get-Sha256 $GodotPath)
    Assert-ExpectedSha256 'Canonical Godot final GUI binary' $ExpectedGodotGuiSha256 (Get-Sha256 $canonicalGodotGuiPath)
    Assert-ExpectedSha256 'Canonical Python final binary' $canonicalPythonSha256 (Get-Sha256 $canonicalPythonPath)
    $binaryIntegrity = $true
}
catch {
    $launcherError = ([string]$launcherError + ' | Final binary integrity: ' + $_.Exception.Message).Trim(' ', '|')
}
if (-not $environmentRestored -or -not $cacheCleanupSucceeded -or -not $binaryIntegrity -or -not [string]::IsNullOrWhiteSpace($finalCensusError) -or $newUnownedGodot.Count -gt 0 -or $allUnleasedGodot.Count -gt 0 -or $ownedLeaseResiduals.Count -gt 0 -or $profileResiduals.Count -gt 0 -or $null -eq $postCandidate) {
    $outcome = 'invalid'
    $overallExit = 1
    if ([string]::IsNullOrWhiteSpace($launcherError)) { $launcherError = 'Final environment/cache/process/lease/candidate restoration gate failed.' }
}
$artifactManifest = @()
$artifactManifestError = ''
$manifestSha = ''
$finalGateRecord = [ordered]@{
    environment_restored = $environmentRestored
    cache_initially_absent = $cacheInitiallyAbsent
    cache_absent_after = -not (Test-Path -LiteralPath $projectCacheRoot)
    cache_cleanup_succeeded = $cacheCleanupSucceeded
    baseline_godot = @($baselineGlobalGodot)
    live_godot = @($finalLiveGodot)
    new_unowned_godot = @($newUnownedGodot)
    all_unleased_godot = @($allUnleasedGodot)
    census_error = $finalCensusError
    owned_lease_residual_count = $ownedLeaseResiduals.Count
    profile_residual_count = $profileResiduals.Count
    canonical_binaries_intact = $binaryIntegrity
}
$identityRecord = [ordered]@{
    launcher_process = $launcherIdentity
    godot = [ordered]@{ path = $GodotPath; sha256 = Get-OptionalSha256 $GodotPath; expected_sha256 = $ExpectedGodotSha256 }
    godot_gui = [ordered]@{ path = $canonicalGodotGuiPath; sha256 = Get-OptionalSha256 $canonicalGodotGuiPath; expected_sha256 = $ExpectedGodotGuiSha256 }
    python = [ordered]@{ path = $PythonPath; canonical_path = $canonicalPythonPath; sha256 = Get-OptionalSha256 $canonicalPythonPath; expected_sha256 = $ExpectedPythonSha256; release_pinned_sha256 = $canonicalPythonSha256 }
    static_original = [ordered]@{ path = $staticOriginal; expected_sha256 = $ExpectedStaticReportSha256; final_sha256 = Get-OptionalSha256 $staticOriginal }
    static_snapshot = [ordered]@{ path = $staticSnapshot; sha256 = Get-OptionalSha256 $staticSnapshot }
}

if ($overallExit -eq 0 -and $outcome -eq 'pass') {
    try {
        $publicationPlan = New-OwnerReviewPublicationPlan $ownerReviewSource (Join-Path $EvidenceRoot '04-publication')
        $artifactManifest = @(Get-ArtifactManifest $EvidenceRoot)
        $publicationPlanForSeal = [ordered]@{
            source = [string]$publicationPlan.source
            source_sha256 = [string]$publicationPlan.source_sha256
            candidate_path = [string]$publicationPlan.candidate_path
            candidate_sha256 = [string]$publicationPlan.candidate_sha256
            destination = [string]$publicationPlan.destination
            destination_root = [string]$publicationPlan.destination_root
            evidence_root = [string]$publicationPlan.evidence_root
            publication_root = [string]$publicationPlan.publication_root
            previous_exists = [bool]$publicationPlan.previous_exists
            previous_sha256 = [string]$publicationPlan.previous_sha256
            backup_path = [string]$publicationPlan.backup_path
            publication_deferred_until_complete_evidence_seal = $true
        }
        $evidenceSealValue = [ordered]@{
            schema = 'rw06_1_visual_capture_complete_evidence_seal/v2'
            sealed = $true
            outcome = 'evidence_complete_ready_to_publish'
            exit_code_if_publication_succeeds = 0
            launcher_error = ''
            started_utc = $startedUtc.ToString('o')
            evidence_completed_utc = [DateTime]::UtcNow.ToString('o')
            evidence_root = $EvidenceRoot
            q009_policy = [ordered]@{ classification = 'normal_isolated_focused'; exclusive = $false; two_separate_windowed_phases = $true; maximum_machine_godot_processes = 4; maximum_focused_pairs = 2 }
            candidate = [ordered]@{ expected_commit = $ExpectedCommit; expected_tree = $ExpectedTree; preflight = $candidate; final = $postCandidate }
            files = $trackedFiles
            identities = $identityRecord
            static_contract = $staticContract
            phases = @($phaseRecords)
            validations = [ordered]@{ q008 = $q008Validation; all18 = $allRoomValidation }
            artifact_manifest = $artifactManifest
            artifact_counts = [ordered]@{ q008 = [int]$q008Validation.artifact_count; all18 = [int]$allRoomValidation.artifact_count }
            owner_review_publication_plan = $publicationPlanForSeal
            final_prepublication_gates = $finalGateRecord
        }
        $evidenceSealRecord = Write-VerifiedJsonSeal $evidenceSealValue $evidenceSealPath $evidenceSealShaPath 'Complete pre-publication evidence seal' 18
        $postSealArtifactManifest = @(Get-ArtifactManifest $EvidenceRoot)
        Assert-Contract (
            (($artifactManifest | ConvertTo-Json -Compress -Depth 10) -ceq ($postSealArtifactManifest | ConvertTo-Json -Compress -Depth 10))
        ) 'Evidence artifacts changed after the complete evidence seal was written.'
        $ownerReviewCopy = Publish-OwnerReviewAfterSeal $publicationPlan $evidenceSealRecord
        $ownerReviewSidecars = @(Get-OwnerReviewSidecars ([string]$publicationPlan.destination))
        Assert-Contract ($ownerReviewSidecars.Count -eq 0) 'Successful owner-review publication left an owned sidecar.'
        $finalGateRecord['owner_review_sidecar_count'] = 0
        $publicationReceiptValue = [ordered]@{
            schema = 'rw06_1_visual_capture_publication_receipt/v2'
            sealed = $true
            outcome = 'published'
            evidence_seal = $evidenceSealRecord
            owner_review_copy = $ownerReviewCopy
            owner_review_sidecar_count = 0
            published_utc = [DateTime]::UtcNow.ToString('o')
            rollback = [ordered]@{ required = $false; restored = $true }
        }
        $publicationReceiptRecord = Write-VerifiedJsonSeal $publicationReceiptValue $publicationReceiptPath $publicationReceiptShaPath 'Owner-review publication receipt' 10
        Assert-ExpectedSha256 'Final evidence seal linkage' ([string]$evidenceSealRecord.sha256) (Get-Sha256 $evidenceSealPath)
        Assert-ExpectedSha256 'Final publication receipt linkage' ([string]$publicationReceiptRecord.sha256) (Get-Sha256 $publicationReceiptPath)
        Assert-ExpectedSha256 'Final published owner-review image' ([string]$publicationPlan.candidate_sha256) (Get-Sha256 ([string]$publicationPlan.destination))
        $manifest = [ordered]@{
            schema = 'rw06_1_visual_capture_final_manifest/v2'
            sealed = $true
            outcome = 'pass'
            exit_code = 0
            launcher_error = ''
            started_utc = $startedUtc.ToString('o')
            completed_utc = [DateTime]::UtcNow.ToString('o')
            evidence_root = $EvidenceRoot
            candidate = [ordered]@{ expected_commit = $ExpectedCommit; expected_tree = $ExpectedTree; final = $postCandidate }
            evidence_seal = $evidenceSealRecord
            publication_receipt = $publicationReceiptRecord
            owner_review_copy = $ownerReviewCopy
            artifact_counts = [ordered]@{ q008 = [int]$q008Validation.artifact_count; all18 = [int]$allRoomValidation.artifact_count }
            final_gates = $finalGateRecord
        }
        $manifestRecord = Write-VerifiedJsonSeal $manifest $manifestPath $manifestShaPath 'Final sealed manifest' 12
        $manifestSha = [string]$manifestRecord.sha256
    }
    catch {
        $launcherError = ([string]$launcherError + ' | Evidence-seal/publication transaction: ' + $_.Exception.Message).Trim(' ', '|')
        $outcome = 'invalid'
        $overallExit = 1
        try { $rollbackRecord = Restore-OwnerReviewPublication $publicationPlan }
        catch {
            $rollbackRecord = [ordered]@{ required = ($null -ne $publicationPlan -and [bool]$publicationPlan.published); restored = $false; error = $_.Exception.Message }
            $launcherError = ($launcherError + ' | Owner-review rollback: ' + $_.Exception.Message).Trim(' ', '|')
        }
        $ownerReviewSidecars = if ($null -ne $publicationPlan) { @(Get-OwnerReviewSidecars ([string]$publicationPlan.destination)) } else { @() }
        $finalGateRecord['owner_review_sidecar_count'] = $ownerReviewSidecars.Count
        $finalGateRecord['owner_review_sidecars'] = @($ownerReviewSidecars | ForEach-Object { $_.FullName })
        if ($ownerReviewSidecars.Count -gt 0) { $launcherError = ($launcherError + ' | Owner-review sidecar residue survived transaction cleanup.').Trim(' ', '|') }
        if ($null -ne $evidenceSealRecord) {
            try {
                $failedReceipt = [ordered]@{
                    schema = 'rw06_1_visual_capture_publication_receipt/v2'
                    sealed = $true
                    outcome = 'invalid_rolled_back'
                    evidence_seal = $evidenceSealRecord
                    publication_plan = $publicationPlan
                    owner_review_copy = $ownerReviewCopy
                    owner_review_sidecars = @($ownerReviewSidecars | ForEach-Object { $_.FullName })
                    transaction_error = $launcherError
                    completed_utc = [DateTime]::UtcNow.ToString('o')
                    rollback = $rollbackRecord
                }
                $publicationReceiptRecord = Write-VerifiedJsonSeal $failedReceipt $publicationReceiptPath $publicationReceiptShaPath 'Invalid publication transaction receipt' 10
            }
            catch { $launcherError = ($launcherError + ' | Invalid publication receipt: ' + $_.Exception.Message).Trim(' ', '|') }
        }
    }
}

if (-not $finalGateRecord.Contains('owner_review_sidecar_count')) {
    $ownerReviewSidecars = @(Get-OwnerReviewSidecars $primaryOwnerReviewPath)
    $finalGateRecord['owner_review_sidecar_count'] = $ownerReviewSidecars.Count
    $finalGateRecord['owner_review_sidecars'] = @($ownerReviewSidecars | ForEach-Object { $_.FullName })
    if ($ownerReviewSidecars.Count -gt 0) {
        $outcome = 'invalid'
        $overallExit = 1
        $launcherError = ($launcherError + ' | Pre-existing or unconfined owner-review sidecar residue detected.').Trim(' ', '|')
    }
}

if ($overallExit -ne 0 -or $outcome -ne 'pass') {
try {
    $artifactManifest = @(Get-ArtifactManifest $EvidenceRoot)
    $manifest = [ordered]@{
    schema = 'rw06_1_visual_capture_final_manifest/v2'
    sealed = $true
    outcome = 'invalid'
    exit_code = 1
    launcher_error = $launcherError
    started_utc = $startedUtc.ToString('o')
    completed_utc = [DateTime]::UtcNow.ToString('o')
    evidence_root = $EvidenceRoot
    setup = [ordered]@{ requested_evidence_root = $requestedEvidenceRoot; setup_error = $evidenceSetupError; safe_failure_root_created = $true }
    q009_policy = [ordered]@{ classification = 'normal_isolated_focused'; exclusive = $false; two_separate_windowed_phases = $true; maximum_machine_godot_processes = 4; maximum_focused_pairs = 2 }
    candidate = [ordered]@{ expected_commit = $ExpectedCommit; expected_tree = $ExpectedTree; preflight = $candidate; final = $postCandidate }
    files = $trackedFiles
    identities = $identityRecord
    static_contract = $staticContract
    phases = @($phaseRecords)
    validations = [ordered]@{ q008 = $q008Validation; all18 = $allRoomValidation }
    owner_review_copy = $ownerReviewCopy
    evidence_seal = [ordered]@{ path = $evidenceSealPath; sha256 = Get-OptionalSha256 $evidenceSealPath; hash_path = $evidenceSealShaPath }
        publication_receipt = [ordered]@{ path = $publicationReceiptPath; sha256 = Get-OptionalSha256 $publicationReceiptPath; hash_path = $publicationReceiptShaPath }
        publication_plan = $publicationPlan
        rollback = $rollbackRecord
    artifact_manifest = $artifactManifest
    artifact_manifest_error = $artifactManifestError
    final_gates = $finalGateRecord
    }
    $manifestRecord = Write-VerifiedJsonSeal $manifest $manifestPath $manifestShaPath 'Final invalid manifest' 18
    $manifestSha = [string]$manifestRecord.sha256
}
catch {
    $outcome = 'invalid'
    $overallExit = 1
    $launcherError = ([string]$launcherError + ' | Final manifest seal: ' + $_.Exception.Message).Trim(' ', '|')
    $fallbackManifest = [ordered]@{
        schema = 'rw06_1_visual_capture_emergency_invalid_manifest/v1'
        sealed = $false
        outcome = 'invalid'
        exit_code = 1
        launcher_error = $launcherError
        started_utc = $startedUtc.ToString('o')
        completed_utc = [DateTime]::UtcNow.ToString('o')
        evidence_root = $EvidenceRoot
        requested_evidence_root = $requestedEvidenceRoot
        candidate = [ordered]@{ expected_commit = $ExpectedCommit; expected_tree = $ExpectedTree }
        phases_completed = $phaseRecords.Count
        prior_structured_manifest = $manifest
    }
    [IO.File]::WriteAllText($manifestPath, (($fallbackManifest | ConvertTo-Json -Depth 6) + "`n"))
    $manifestSha = Get-Sha256 $manifestPath
    [IO.File]::WriteAllText($manifestShaPath, ($manifestSha + '  manifest.json' + "`n"))
}
}
Write-Host ("RW06_1_VISUAL_CAPTURE outcome={0} exit={1} phases={2} evidence={3} manifest_sha256={4}" -f $outcome, $overallExit, $phaseRecords.Count, $EvidenceRoot, $manifestSha)
if (-not [string]::IsNullOrWhiteSpace($launcherError)) { Write-Host ("RW06_1_VISUAL_CAPTURE error={0}" -f $launcherError) }
exit $overallExit
