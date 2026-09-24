param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Za-z0-9_-]+$')]
    [string]$Session,
    [string]$Command,
    [switch]$Start,
    [int]$TimeoutSeconds = 90,
    [string]$SessionRoot = ''
)

$ErrorActionPreference = 'Stop'
$Worktree = Split-Path -Parent $PSScriptRoot
$AgentPlaytestRoot = Join-Path $Worktree '.tmp\agent_playtest'
if ([string]::IsNullOrWhiteSpace($SessionRoot)) {
    $existingRoots = @()
    if (Test-Path -LiteralPath $AgentPlaytestRoot -PathType Container) {
        $existingRoots = @(Get-ChildItem -LiteralPath $AgentPlaytestRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $candidate = Join-Path $_.FullName $Session
            if (Test-Path -LiteralPath $candidate -PathType Container) { $candidate }
        })
    }
    if ($existingRoots.Count -gt 1) {
        throw "Session '$Session' is ambiguous across dated roots; pass its exact absolute -SessionRoot."
    }
    $SessionRoot = if ($existingRoots.Count -eq 1) {
        [string]$existingRoots[0]
    }
    else {
        Join-Path $AgentPlaytestRoot "$(Get-Date -Format 'yyyy-MM-dd')\$Session"
    }
}
if (-not [IO.Path]::IsPathRooted($SessionRoot)) {
    throw '-SessionRoot must be an absolute path.'
}
$SessionRoot = [IO.Path]::GetFullPath($SessionRoot)
$allowedRootPrefix = ([IO.Path]::GetFullPath($AgentPlaytestRoot)).TrimEnd('\') + '\'
if (-not $SessionRoot.StartsWith($allowedRootPrefix, [StringComparison]::OrdinalIgnoreCase) -or
    (Split-Path -Leaf $SessionRoot) -cne $Session) {
    throw "Session root '$SessionRoot' is outside the owned agent-playtest root or does not end in '$Session'."
}
$GodotBin = if ($env:GODOT_BIN) { $env:GODOT_BIN } else { 'D:\Projects\Beat-The-House\.tools\godot-4.6-stable\Godot_v4.6-stable_win64_console.exe' }
$PidPath = Join-Path $SessionRoot 'process.pid'
$ProcessIdentityPath = Join-Path $SessionRoot 'process.identity.json'
$ReadyPath = Join-Path $SessionRoot 'ready.json'
$StdoutPath = Join-Path $SessionRoot 'godot.stdout.log'
$StderrPath = Join-Path $SessionRoot 'godot.stderr.log'
$EngineLogPath = Join-Path $SessionRoot 'godot.engine.log'
$LogCursorPath = Join-Path $SessionRoot 'log_cursor.json'


function Get-ProcessStartUtcTicks {
    param([Parameter(Mandatory = $true)][Diagnostics.Process]$Process)
    try {
        return [long]$Process.StartTime.ToUniversalTime().Ticks
    }
    catch {
        return 0L
    }
}

function Get-SessionProcess {
    if (-not (Test-Path -LiteralPath $PidPath) -or -not (Test-Path -LiteralPath $ProcessIdentityPath)) { return $null }
    try {
        $processId = [int](Get-Content -Raw -LiteralPath $PidPath)
        $identity = Get-Content -Raw -LiteralPath $ProcessIdentityPath -Encoding utf8 | ConvertFrom-Json
        if ([string]$identity.session -cne $Session -or [int]$identity.pid -ne $processId -or [long]$identity.start_utc_ticks -le 0) { return $null }
        if (-not ([IO.Path]::GetFullPath([string]$identity.session_root)).Equals($SessionRoot, [StringComparison]::OrdinalIgnoreCase)) { return $null }
        $process = Get-Process -Id $processId -ErrorAction SilentlyContinue
        if (-not $process) { return $null }
        if ((Get-ProcessStartUtcTicks -Process $process) -ne [long]$identity.start_utc_ticks) { return $null }
        $expectedPath = [IO.Path]::GetFullPath([string]$identity.executable_path)
        $actualPath = [IO.Path]::GetFullPath([string]$process.Path)
        if (-not $actualPath.Equals($expectedPath, [StringComparison]::OrdinalIgnoreCase)) { return $null }
        return $process
    }
    catch {
        return $null
    }
}


function Set-AtomicJsonFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]$Value
    )
    $token = "$PID-$([Guid]::NewGuid().ToString('N'))"
    $temporaryPath = "$Path.$token.tmp"
    try {
        $Value | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $temporaryPath -Encoding utf8
        Move-Item -LiteralPath $temporaryPath -Destination $Path -Force -ErrorAction Stop
    }
    finally {
        Remove-Item -LiteralPath $temporaryPath -ErrorAction SilentlyContinue
    }
}

function Add-NewLogAlerts {
    param([string]$ResultPath)
    $cursor = @{ stdout = 0; stderr = 0 }
    if (Test-Path -LiteralPath $LogCursorPath) {
        $saved = Get-Content -Raw -LiteralPath $LogCursorPath -Encoding utf8 | ConvertFrom-Json
        $cursor.stdout = [int]$saved.stdout
        $cursor.stderr = [int]$saved.stderr
    }
    $stdoutLines = if (Test-Path -LiteralPath $StdoutPath) { @(Get-Content -LiteralPath $StdoutPath -Encoding utf8) } else { @() }
    $stderrLines = if (Test-Path -LiteralPath $StderrPath) { @(Get-Content -LiteralPath $StderrPath -Encoding utf8) } else { @() }
    $newLines = @()
    if ($stdoutLines.Count -gt $cursor.stdout) { $newLines += $stdoutLines[$cursor.stdout..($stdoutLines.Count - 1)] }
    if ($stderrLines.Count -gt $cursor.stderr) { $newLines += $stderrLines[$cursor.stderr..($stderrLines.Count - 1)] }
    $alerts = @($newLines | Where-Object { $_ -match 'SCRIPT ERROR|(^|\s)ERROR[: ]|(^|\s)WARNING[: ]' })
    $result = Get-Content -Raw -LiteralPath $ResultPath -Encoding utf8 | ConvertFrom-Json
    $result | Add-Member -NotePropertyName log_alerts -NotePropertyValue $alerts -Force
    $result | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $ResultPath -Encoding utf8
    Set-AtomicJsonFile -Path $LogCursorPath -Value @{ stdout = $stdoutLines.Count; stderr = $stderrLines.Count }
}

if ($Start) {
    New-Item -ItemType Directory -Force -Path $SessionRoot | Out-Null
    $existing = Get-SessionProcess
    if ($existing) {
        Write-Output "Session '$Session' is already running as PID $($existing.Id)."
        Get-Content -Raw -LiteralPath $ReadyPath -Encoding utf8
        exit 0
    }
    Remove-Item -LiteralPath $ReadyPath -ErrorAction SilentlyContinue
    # Start-Process recreates/truncates the two redirected logs. Reset their
    # cursor at the same process boundary so a same-session relaunch cannot use
    # the prior process's larger line counts to skip early warnings/errors.
    Set-AtomicJsonFile -Path $LogCursorPath -Value @{ stdout = 0; stderr = 0 }
    $env:BTH_DISTRIBUTION_DATA_ROOT = "user://agent_playtest/$Session"
    $env:BTH_USER_SETTINGS_PATH = "user://agent_playtest/$Session/settings.json"
    $env:BTH_PROFILE_INVENTORY_PATH = "user://agent_playtest/$Session/profile_inventory.json"
    $env:BTH_META_COLLECTION_PATH = "user://agent_playtest/$Session/meta_collection.json"
    $arguments = @(
        '--log-file', $EngineLogPath,
        '--path', $Worktree,
        '--script', 'res://tools/agent_playtest_session.gd',
        '--', "--session=$Session", "--session-dir=$($SessionRoot.Replace('\', '/'))"
    )
    $process = Start-Process -FilePath $GodotBin -ArgumentList $arguments -RedirectStandardOutput $StdoutPath -RedirectStandardError $StderrPath -WindowStyle Hidden -PassThru
    try {
        Set-Content -LiteralPath $PidPath -Value $process.Id -Encoding ascii
        $processStartUtcTicks = Get-ProcessStartUtcTicks -Process $process
        if ($processStartUtcTicks -le 0) {
            throw "Could not capture the exact process identity for session '$Session'."
        }
        Set-AtomicJsonFile -Path $ProcessIdentityPath -Value @{
            pid = $process.Id
            start_utc_ticks = $processStartUtcTicks
            executable_path = [IO.Path]::GetFullPath($GodotBin)
            session = $Session
            session_root = $SessionRoot
        }
    }
    catch {
        # This process object was returned by the Start-Process call above, so it
        # is the only safe target if identity publication itself fails.
        if (-not $process.HasExited) {
            Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        }
        throw
    }
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline -and -not (Test-Path -LiteralPath $ReadyPath)) {
        if ($process.HasExited) {
            throw "Session '$Session' exited before ready. See $StdoutPath and $StderrPath."
        }
        Start-Sleep -Milliseconds 100
    }
    if (-not (Test-Path -LiteralPath $ReadyPath)) { throw "Session '$Session' did not become ready in $TimeoutSeconds seconds." }
    Write-Output "Session '$Session' started as PID $($process.Id)."
    Get-Content -Raw -LiteralPath $ReadyPath -Encoding utf8
    if (-not $PSBoundParameters.ContainsKey('Command')) {
        # The launcher is commonly called through a nested powershell.exe whose
        # output is captured. Exit explicitly so the long-lived Godot child
        # cannot keep that launcher host attached after ready.json is emitted.
        exit 0
    }
}

if ($PSBoundParameters.ContainsKey('Command')) {
    if (-not (Get-SessionProcess)) { throw "Session '$Session' is not running; start it with -Start first." }
    $numbers = @(Get-ChildItem -LiteralPath $SessionRoot -Filter '*.command.txt' -ErrorAction SilentlyContinue | ForEach-Object { [int]$_.BaseName.Split('.')[0] })
    $next = if ($numbers.Count -eq 0) { 1 } else { ($numbers | Measure-Object -Maximum).Maximum + 1 }
    $stem = '{0:D4}' -f ([int]$next)
    $commandPath = Join-Path $SessionRoot "$stem.command.txt"
    $resultPath = Join-Path $SessionRoot "$stem.result.json"
    $commandTempToken = "$PID-$([Guid]::NewGuid().ToString('N'))"
    if ($commandTempToken -notmatch '^[0-9]+-[a-f0-9]{32}$') {
        throw 'Could not create a safe unique command-publish token.'
    }
    $commandTempPath = Join-Path $SessionRoot "$stem.command.$commandTempToken.tmp"
    try {
        Set-Content -LiteralPath $commandTempPath -Value $Command -Encoding utf8
        # Same-directory rename is the publish boundary: Godot can never see a
        # ####.command.txt path until all command bytes have reached disk.
        Move-Item -LiteralPath $commandTempPath -Destination $commandPath -ErrorAction Stop
    }
    finally {
        Remove-Item -LiteralPath $commandTempPath -ErrorAction SilentlyContinue
    }
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $resultReady = $false
    while ((Get-Date) -lt $deadline -and -not $resultReady) {
        $process = Get-SessionProcess
        if (Test-Path -LiteralPath $resultPath) {
            try {
                $resultText = Get-Content -Raw -LiteralPath $resultPath -Encoding utf8
                if (-not [string]::IsNullOrWhiteSpace($resultText)) {
                    $null = $resultText | ConvertFrom-Json
                    $resultReady = $true
                    break
                }
            }
            catch {
                # Godot writes large observation payloads directly. File creation
                # can precede the final bytes, so keep waiting for valid JSON.
            }
        }
        if (-not $process -and -not $resultReady) { throw "Session '$Session' exited while processing command $stem." }
        Start-Sleep -Milliseconds 100
    }
    if (-not $resultReady) { throw "Command $stem did not produce complete JSON within $TimeoutSeconds seconds." }
    Add-NewLogAlerts -ResultPath $resultPath
    Get-Content -Raw -LiteralPath $resultPath -Encoding utf8
}

if (-not $Start -and -not $PSBoundParameters.ContainsKey('Command')) {
    $process = Get-SessionProcess
    [pscustomobject]@{
        session = $Session
        running = [bool]$process
        pid = if ($process) { $process.Id } else { $null }
        start_utc_ticks = if ($process) { Get-ProcessStartUtcTicks -Process $process } else { $null }
        executable_path = if ($process) { [string]$process.Path } else { '' }
        folder = $SessionRoot
    } | ConvertTo-Json
}
