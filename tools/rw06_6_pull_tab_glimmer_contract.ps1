param(
    [string]$GodotPath = 'D:\Projects\Beat-The-House\.tools\godot-4.6-stable\Godot_v4.6-stable_win64_console.exe',
    [string]$EvidenceRoot = '',
    [string]$ExpectedCommit = '',
    [string]$ExpectedTree = '',
    [int]$LeaseWaitTimeoutSec = 900,
    [int]$ProcessTimeoutSec = 180,
    [switch]$ValidateOnly
)

$ErrorActionPreference = 'Stop'
$projectRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$worktreesRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $projectRoot))
$leaseRoot = Join-Path $worktreesRoot '.godot_leases'
$exclusiveLeasePath = Join-Path $leaseRoot 'EXCLUSIVE.lease'
$launchMutexName = 'Global\BeatTheHouse-Q009-GodotLaunch'

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

function Get-LiveGodotProcesses {
    return @(Get-Process -ErrorAction SilentlyContinue | Where-Object {
        $_.ProcessName -in @('Godot_v4.6-stable_win64_console', 'Godot_v4.6-stable_win64')
    })
}

function Clear-StaleGodotLeases {
    Get-ChildItem -LiteralPath $leaseRoot -Filter '*.lease' -File -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_.Name -eq 'EXCLUSIVE.lease') { return }
        $match = [regex]::Match($_.Name, '-(?<pid>\d+)\.lease$')
        if (-not $match.Success) { return }
        $leasePid = [int]$match.Groups['pid'].Value
        if (-not (Get-Process -Id $leasePid -ErrorAction SilentlyContinue)) {
            Remove-Item -LiteralPath $_.FullName -Force
        }
    }
}

function Get-VerifiedDescendantProcessIds {
    param([int]$RootPid, [int[]]$BaselinePids)
    $all = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue)
    $owned = [System.Collections.Generic.HashSet[int]]::new()
    [void]$owned.Add($RootPid)
    $changed = $true
    while ($changed) {
        $changed = $false
        foreach ($entry in $all) {
            $pidValue = [int]$entry.ProcessId
            if ($BaselinePids -contains $pidValue -or $owned.Contains($pidValue)) { continue }
            if ($owned.Contains([int]$entry.ParentProcessId)) {
                [void]$owned.Add($pidValue)
                $changed = $true
            }
        }
    }
    return @($owned | Where-Object { $_ -ne $RootPid })
}

function Stop-ExactStartedProcessTree {
    param(
        [System.Diagnostics.Process]$ConsoleProcess,
        [datetime]$ConsoleStartTime,
        [int[]]$BaselinePids
    )
    if ($null -eq $ConsoleProcess) { return }
    $descendantPids = @(Get-VerifiedDescendantProcessIds -RootPid $ConsoleProcess.Id -BaselinePids $BaselinePids)
    foreach ($childPid in ($descendantPids | Sort-Object -Descending)) {
        $child = Get-Process -Id $childPid -ErrorAction SilentlyContinue
        if ($child -and $child.ProcessName -in @('Godot_v4.6-stable_win64_console', 'Godot_v4.6-stable_win64')) {
            Stop-Process -Id $childPid -Force -ErrorAction SilentlyContinue
        }
    }
    $liveConsole = Get-Process -Id $ConsoleProcess.Id -ErrorAction SilentlyContinue
    if ($liveConsole -and $liveConsole.ProcessName -in @('Godot_v4.6-stable_win64_console', 'Godot_v4.6-stable_win64')) {
        try {
            if ($liveConsole.StartTime.ToUniversalTime() -eq $ConsoleStartTime.ToUniversalTime()) {
                Stop-Process -Id $liveConsole.Id -Force -ErrorAction SilentlyContinue
            }
        }
        catch {
            # A process exiting between identity verification and cleanup is already clean.
        }
    }
}

function Get-DiagnosticLines {
    param([string]$Text)
    $patterns = @(
        '(?im)^.*SCRIPT ERROR.*$',
        '(?im)^\s*ERROR(?:\s|:).*$' ,
        '(?im)^\s*WARNING(?:\s|:).*$' ,
        '(?im)^.*ObjectDB.*(?:leak|still alive|instance).*$'
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

if ($ValidateOnly) {
    Assert-LauncherContract (Test-FocusedLaunchCapacity $false 0 0) 'Q-009 capacity rejected an empty machine.'
    Assert-LauncherContract (Test-FocusedLaunchCapacity $false 1 2) 'Q-009 capacity rejected the second focused console/child pair.'
    Assert-LauncherContract (-not (Test-FocusedLaunchCapacity $true 0 0)) 'Q-009 capacity ignored EXCLUSIVE.lease.'
    Assert-LauncherContract (-not (Test-FocusedLaunchCapacity $false 2 0)) 'Q-009 capacity allowed a third focused pair.'
    Assert-LauncherContract (-not (Test-FocusedLaunchCapacity $false 1 3)) 'Q-009 capacity allowed current processes plus two to exceed four.'
    Assert-LauncherContract (@(Get-DiagnosticLines -Text "SCRIPT ERROR: hostile`n").Count -gt 0) 'Diagnostics gate missed SCRIPT ERROR.'
    Assert-LauncherContract (@(Get-DiagnosticLines -Text "WARNING: hostile`n").Count -gt 0) 'Diagnostics gate missed WARNING.'
    Assert-LauncherContract (@(Get-DiagnosticLines -Text "ObjectDB instances still alive at exit`n").Count -gt 0) 'Diagnostics gate missed ObjectDB leakage.'
    Assert-LauncherContract (@(Get-DiagnosticLines -Text "RW06_6_PULL_TAB_GLIMMER PASS`n").Count -eq 0) 'Diagnostics gate rejected a clean pass marker.'
    $missingIdentityRejected = $false
    try { Assert-ExactCandidateIdentity '' '' 'actual-commit' 'actual-tree' } catch { $missingIdentityRejected = $true }
    Assert-LauncherContract $missingIdentityRejected 'Identity gate accepted omitted expected commit/tree.'
    $mismatchedIdentityRejected = $false
    try { Assert-ExactCandidateIdentity 'wrong-commit' 'wrong-tree' 'actual-commit' 'actual-tree' } catch { $mismatchedIdentityRejected = $true }
    Assert-LauncherContract $mismatchedIdentityRejected 'Identity gate accepted mismatched commit/tree.'
    Assert-ExactCandidateIdentity 'actual-commit' 'actual-tree' 'actual-commit' 'actual-tree'
    $source = [System.IO.File]::ReadAllText($PSCommandPath)
    foreach ($required in @(
        'Get-LiveGodotProcesses',
        'Assert-ExactCandidateIdentity',
        'Get-VerifiedDescendantProcessIds',
        'Stop-ExactStartedProcessTree',
        'WaitForExit($ProcessTimeoutSec * 1000)',
        'git status --porcelain',
        'ExpectedCommit',
        'ExpectedTree',
        "'--verbose'",
        'SCRIPT ERROR',
        'ObjectDB',
        'EXCLUSIVE.lease'
    )) {
        Assert-LauncherContract ($source.Contains($required)) "Launcher source contract is missing: $required"
    }
    Write-Host 'rw06_6 Q-009 launcher static/hostile contract passed.'
    exit 0
}

if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw "Canonical Godot 4.6 console not found: $GodotPath"
}
if ($ProcessTimeoutSec -lt 1) {
    throw 'ProcessTimeoutSec must be positive.'
}

$dirty = @(& git -C $projectRoot status --porcelain)
if ($LASTEXITCODE -ne 0 -or $dirty.Count -ne 0) {
    throw 'RW06_6 qualifying/red evidence requires a clean committed candidate tree.'
}
$candidateCommit = (& git -C $projectRoot rev-parse HEAD).Trim()
$candidateTree = (& git -C $projectRoot rev-parse 'HEAD^{tree}').Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($candidateCommit) -or [string]::IsNullOrWhiteSpace($candidateTree)) {
    throw 'Could not resolve the exact candidate commit/tree.'
}
Assert-ExactCandidateIdentity $ExpectedCommit $ExpectedTree $candidateCommit $candidateTree

New-Item -ItemType Directory -Force -Path $leaseRoot | Out-Null
$leasePath = Join-Path $leaseRoot ("rw06_6-pull-tab-glimmer-{0}.lease" -f $PID)
$leaseDeadline = [DateTime]::UtcNow.AddSeconds($LeaseWaitTimeoutSec)
$leaseOwned = $false
while (-not $leaseOwned) {
    if ([DateTime]::UtcNow -ge $leaseDeadline) {
        throw 'Timed out waiting for a Q-009 focused Godot pair slot.'
    }
    $mutex = [System.Threading.Mutex]::new($false, $launchMutexName)
    $mutexOwned = $false
    try {
        $mutexOwned = $mutex.WaitOne(5000)
        if (-not $mutexOwned) { continue }
        Clear-StaleGodotLeases
        $exclusivePresent = Test-Path -LiteralPath $exclusiveLeasePath
        $focusedLeaseCount = @(Get-ChildItem -LiteralPath $leaseRoot -Filter '*.lease' -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'EXCLUSIVE.lease' }).Count
        $godotProcessCount = @(Get-LiveGodotProcesses).Count
        if (Test-FocusedLaunchCapacity $exclusivePresent $focusedLeaseCount $godotProcessCount) {
            $leaseText = "pid=$PID`nworktree=$projectRoot`ncandidate_commit=$candidateCommit`ncandidate_tree=$candidateTree`nstarted_utc=$([DateTime]::UtcNow.ToString('o'))`n"
            $stream = [System.IO.File]::Open($leasePath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
            try {
                $bytes = [System.Text.Encoding]::UTF8.GetBytes($leaseText)
                $stream.Write($bytes, 0, $bytes.Length)
            }
            finally {
                $stream.Dispose()
            }
            $leaseOwned = $true
        }
    }
    finally {
        if ($mutexOwned) { $mutex.ReleaseMutex() }
        $mutex.Dispose()
    }
    if (-not $leaseOwned) { Start-Sleep -Seconds 2 }
}

$stamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')
if ([string]::IsNullOrWhiteSpace($EvidenceRoot)) {
    $EvidenceRoot = Join-Path $projectRoot ".tmp\rw06_6\contract-$stamp-$PID"
}
$EvidenceRoot = [System.IO.Path]::GetFullPath($EvidenceRoot)
New-Item -ItemType Directory -Force -Path $EvidenceRoot | Out-Null

$profileRoot = Join-Path $EvidenceRoot 'profile'
$appData = Join-Path $profileRoot 'AppData\Roaming'
$localAppData = Join-Path $profileRoot 'AppData\Local'
$xdgData = Join-Path $profileRoot 'xdg\data'
$xdgCache = Join-Path $profileRoot 'xdg\cache'
$xdgConfig = Join-Path $profileRoot 'xdg\config'
@($appData, $localAppData, $xdgData, $xdgCache, $xdgConfig) | ForEach-Object {
    New-Item -ItemType Directory -Force -Path $_ | Out-Null
}
$env:APPDATA = $appData
$env:LOCALAPPDATA = $localAppData
$env:XDG_DATA_HOME = $xdgData
$env:XDG_CACHE_HOME = $xdgCache
$env:XDG_CONFIG_HOME = $xdgConfig

$stdoutPath = Join-Path $EvidenceRoot 'stdout.log'
$stderrPath = Join-Path $EvidenceRoot 'stderr.log'
$godotLogPath = Join-Path $EvidenceRoot 'godot.log'
$summaryPath = Join-Path $EvidenceRoot 'summary.json'
$arguments = @(
    '--headless',
    '--verbose',
    '--disable-crash-handler',
    '--audio-driver', 'Dummy',
    '--log-file', $godotLogPath,
    '--path', $projectRoot,
    '--script', 'res://scripts/tests/rw06_6_pull_tab_glimmer_contract.gd'
)

$process = $null
$consoleStartTime = [datetime]::MinValue
$baselineGodotPids = @((Get-LiveGodotProcesses) | ForEach-Object { $_.Id })
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$nativeExitCode = 1
$timedOut = $false
try {
    # Re-census immediately before launch after reserving our focused-pair lease.
    if (Test-Path -LiteralPath $exclusiveLeasePath) {
        throw 'EXCLUSIVE.lease appeared after focused reservation; refusing launch.'
    }
    $preLaunchGodotCount = @(Get-LiveGodotProcesses).Count
    if (($preLaunchGodotCount + 2) -gt 4) {
        throw "Q-009 process ceiling changed before launch: $preLaunchGodotCount + 2 > 4."
    }
    $process = Start-Process -FilePath $GodotPath -ArgumentList $arguments -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -PassThru -WindowStyle Hidden
    $consoleStartTime = $process.StartTime
    if (-not $process.WaitForExit($ProcessTimeoutSec * 1000)) {
        $timedOut = $true
        $nativeExitCode = 124
    }
    else {
        $nativeExitCode = $process.ExitCode
    }
}
finally {
    $stopwatch.Stop()
    Stop-ExactStartedProcessTree -ConsoleProcess $process -ConsoleStartTime $consoleStartTime -BaselinePids $baselineGodotPids
    if ($leaseOwned -and (Test-Path -LiteralPath $leasePath)) {
        Remove-Item -LiteralPath $leasePath -Force
    }
}

$combinedText = ''
foreach ($path in @($stdoutPath, $stderrPath, $godotLogPath)) {
    if (Test-Path -LiteralPath $path) {
        $combinedText += "`n--- $([System.IO.Path]::GetFileName($path)) ---`n"
        $combinedText += [System.IO.File]::ReadAllText($path)
    }
}
$diagnostics = @(Get-DiagnosticLines -Text $combinedText)
$passMarkerSeen = $combinedText.Contains('RW06_6_PULL_TAB_GLIMMER PASS')
$productRedMarkerSeen = $combinedText.Contains('RW06_6_PRODUCT_RED')
$effectiveExitCode = $nativeExitCode
if ($timedOut -or $diagnostics.Count -gt 0 -or ($nativeExitCode -eq 0 -and -not $passMarkerSeen)) {
    if ($effectiveExitCode -eq 0) { $effectiveExitCode = 1 }
}
$hashes = [ordered]@{}
foreach ($path in @($stdoutPath, $stderrPath, $godotLogPath)) {
    if (Test-Path -LiteralPath $path) {
        $hashes[[System.IO.Path]::GetFileName($path)] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    }
}
$summary = [ordered]@{
    contract = 'rw06_6_pull_tab_glimmer'
    candidate_commit = $candidateCommit
    candidate_tree = $candidateTree
    command = ('"{0}" {1}' -f $GodotPath, ($arguments -join ' '))
    native_exit_code = $nativeExitCode
    exit_code = $effectiveExitCode
    timed_out = $timedOut
    pass_marker = $passMarkerSeen
    product_red_marker = $productRedMarkerSeen
    diagnostics_clean = ($diagnostics.Count -eq 0)
    diagnostics = $diagnostics
    elapsed_seconds = [Math]::Round($stopwatch.Elapsed.TotalSeconds, 3)
    evidence_root = $EvidenceRoot
    sha256 = $hashes
}
[System.IO.File]::WriteAllText($summaryPath, (($summary | ConvertTo-Json -Depth 6) + "`n"))
Write-Host ("RW06_6 contract exit={0} native={1} elapsed={2:n3}s evidence={3}" -f $effectiveExitCode, $nativeExitCode, $stopwatch.Elapsed.TotalSeconds, $EvidenceRoot)
if ($diagnostics.Count -gt 0) {
    Write-Error ("RW06_6 diagnostics were not clean:`n" + ($diagnostics -join "`n"))
}
exit $effectiveExitCode
