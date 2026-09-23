param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Za-z0-9_-]+$')]
    [string]$Session,
    [string]$Command,
    [switch]$Start,
    [int]$TimeoutSeconds = 90
)

$ErrorActionPreference = 'Stop'
$Worktree = Split-Path -Parent $PSScriptRoot
$Date = Get-Date -Format 'yyyy-MM-dd'
$SessionRoot = Join-Path $Worktree ".tmp\agent_playtest\$Date\$Session"
$GodotBin = if ($env:GODOT_BIN) { $env:GODOT_BIN } else { 'D:\Projects\Beat-The-House\.tools\godot-4.6-stable\Godot_v4.6-stable_win64_console.exe' }
$PidPath = Join-Path $SessionRoot 'process.pid'
$ReadyPath = Join-Path $SessionRoot 'ready.json'
$StdoutPath = Join-Path $SessionRoot 'godot.stdout.log'
$StderrPath = Join-Path $SessionRoot 'godot.stderr.log'

function Get-SessionProcess {
    if (-not (Test-Path -LiteralPath $PidPath)) { return $null }
    $processId = [int](Get-Content -Raw -LiteralPath $PidPath)
    return Get-Process -Id $processId -ErrorAction SilentlyContinue
}

function Add-NewLogAlerts {
    param([string]$ResultPath)
    $cursorPath = Join-Path $SessionRoot 'log_cursor.json'
    $cursor = @{ stdout = 0; stderr = 0 }
    if (Test-Path -LiteralPath $cursorPath) {
        $saved = Get-Content -Raw -LiteralPath $cursorPath | ConvertFrom-Json
        $cursor.stdout = [int]$saved.stdout
        $cursor.stderr = [int]$saved.stderr
    }
    $stdoutLines = if (Test-Path -LiteralPath $StdoutPath) { @(Get-Content -LiteralPath $StdoutPath) } else { @() }
    $stderrLines = if (Test-Path -LiteralPath $StderrPath) { @(Get-Content -LiteralPath $StderrPath) } else { @() }
    $newLines = @()
    if ($stdoutLines.Count -gt $cursor.stdout) { $newLines += $stdoutLines[$cursor.stdout..($stdoutLines.Count - 1)] }
    if ($stderrLines.Count -gt $cursor.stderr) { $newLines += $stderrLines[$cursor.stderr..($stderrLines.Count - 1)] }
    $alerts = @($newLines | Where-Object { $_ -match 'SCRIPT ERROR|(^|\s)ERROR[: ]|(^|\s)WARNING[: ]' })
    $result = Get-Content -Raw -LiteralPath $ResultPath | ConvertFrom-Json
    $result | Add-Member -NotePropertyName log_alerts -NotePropertyValue $alerts -Force
    $result | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $ResultPath -Encoding utf8
    @{ stdout = $stdoutLines.Count; stderr = $stderrLines.Count } | ConvertTo-Json | Set-Content -LiteralPath $cursorPath -Encoding utf8
}

if ($Start) {
    New-Item -ItemType Directory -Force -Path $SessionRoot | Out-Null
    $existing = Get-SessionProcess
    if ($existing) {
        Write-Output "Session '$Session' is already running as PID $($existing.Id)."
        Get-Content -Raw -LiteralPath $ReadyPath
        exit 0
    }
    Remove-Item -LiteralPath $ReadyPath -ErrorAction SilentlyContinue
    $env:BTH_DISTRIBUTION_DATA_ROOT = "user://agent_playtest/$Session"
    $env:BTH_USER_SETTINGS_PATH = "user://agent_playtest/$Session/settings.json"
    $env:BTH_PROFILE_INVENTORY_PATH = "user://agent_playtest/$Session/profile_inventory.json"
    $env:BTH_META_COLLECTION_PATH = "user://agent_playtest/$Session/meta_collection.json"
    $arguments = @(
        '--path', $Worktree,
        '--script', 'res://tools/agent_playtest_session.gd',
        '--', "--session=$Session", "--session-dir=$($SessionRoot.Replace('\', '/'))"
    )
    $process = Start-Process -FilePath $GodotBin -ArgumentList $arguments -RedirectStandardOutput $StdoutPath -RedirectStandardError $StderrPath -WindowStyle Hidden -PassThru
    Set-Content -LiteralPath $PidPath -Value $process.Id -Encoding ascii
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline -and -not (Test-Path -LiteralPath $ReadyPath)) {
        if ($process.HasExited) {
            throw "Session '$Session' exited before ready. See $StdoutPath and $StderrPath."
        }
        Start-Sleep -Milliseconds 100
    }
    if (-not (Test-Path -LiteralPath $ReadyPath)) { throw "Session '$Session' did not become ready in $TimeoutSeconds seconds." }
    Write-Output "Session '$Session' started as PID $($process.Id)."
    Get-Content -Raw -LiteralPath $ReadyPath
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
                $resultText = Get-Content -Raw -LiteralPath $resultPath
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
    Get-Content -Raw -LiteralPath $resultPath
}

if (-not $Start -and -not $PSBoundParameters.ContainsKey('Command')) {
    $process = Get-SessionProcess
    [pscustomobject]@{
        session = $Session
        running = [bool]$process
        pid = if ($process) { $process.Id } else { $null }
        folder = $SessionRoot
    } | ConvertTo-Json
}
