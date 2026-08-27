param()

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "web_server_lifecycle.ps1")

function Assert-Test {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-FreeLoopbackPort {
    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
    $listener.Start()
    try { return ([System.Net.IPEndPoint]$listener.LocalEndpoint).Port }
    finally { $listener.Stop() }
}

function Start-TestServer {
    param([string]$Name)
    $caseDirectory = Join-Path $testRoot $Name
    New-Item -ItemType Directory -Force -Path $caseDirectory | Out-Null
    $ownershipFile = Join-Path $caseDirectory "ownership.json"
    return Start-OwnedWebServer `
        -ServeScript (Join-Path $PSScriptRoot "serve_web.ps1") `
        -ServerScript (Join-Path $PSScriptRoot "serve_web_server.py") `
        -ServeRoot $serveRoot `
        -Port (Get-FreeLoopbackPort) `
        -OwnershipFile $ownershipFile `
        -StandardOutput (Join-Path $caseDirectory "stdout.txt") `
        -StandardError (Join-Path $caseDirectory "stderr.txt")
}

$testRoot = Join-Path $root (".tmp/fix06_16_lifecycle_test_{0}" -f [guid]::NewGuid().ToString("N"))
$serveRoot = Join-Path $testRoot "site"
New-Item -ItemType Directory -Force -Path $serveRoot | Out-Null
Set-Content -LiteralPath (Join-Path $serveRoot "index.html") -Value "fix06_16 lifecycle fixture" -Encoding utf8

$sleepCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes("Start-Sleep -Seconds 120"))
$unrelated = Start-Process -FilePath (Get-Command powershell -ErrorAction Stop).Source -ArgumentList @("-NoProfile", "-EncodedCommand", $sleepCommand) -PassThru -WindowStyle Hidden
$unrelatedTicks = $unrelated.StartTime.ToUniversalTime().Ticks
$ownedPids = [System.Collections.Generic.List[int]]::new()
try {
    # Success and assertion/probe unwind all use the same finally cleanup path.
    foreach ($caseName in @("success", "assertion_failure", "probe_failure")) {
        $launch = Start-TestServer -Name $caseName
        $ownedPids.Add([int]$launch.Record.server_pid)
        try {
            Start-Sleep -Milliseconds 150
            Assert-OwnedWebServerListener -Launch $launch
            if ($caseName -ne "success") { throw "intentional $caseName" }
        }
        catch {
            if ($caseName -eq "success") { throw }
            Assert-Test -Condition ($_.Exception.Message -eq "intentional $caseName") -Message "Unexpected $caseName exception."
        }
        finally {
            Stop-OwnedWebServer -Launch $launch
        }
        Assert-Test -Condition ($null -eq (Get-Process -Id ([int]$launch.Record.server_pid) -ErrorAction SilentlyContinue)) -Message "$caseName left its exact Python child alive."
        Assert-Test -Condition (@(Get-NetTCPConnection -State Listen -LocalPort $launch.Port -ErrorAction SilentlyContinue).Count -eq 0) -Message "$caseName left its listener alive."
    }

    # Host interruption: the wrapper can be gone before outer cleanup begins.
    $interrupted = Start-TestServer -Name "host_interruption"
    $ownedPids.Add([int]$interrupted.Record.server_pid)
    Stop-Process -Id $interrupted.Wrapper.Id -Force
    Wait-Process -Id $interrupted.Wrapper.Id -Timeout 5 -ErrorAction SilentlyContinue
    Assert-Test -Condition ($null -ne (Get-Process -Id ([int]$interrupted.Record.server_pid) -ErrorAction SilentlyContinue)) -Message "Host interruption fixture did not preserve the orphan reproduction."
    Stop-OwnedWebServer -Launch $interrupted
    Assert-Test -Condition ($null -eq (Get-Process -Id ([int]$interrupted.Record.server_pid) -ErrorAction SilentlyContinue)) -Message "Host interruption cleanup left its exact child alive."

    # Missing/already-exited child is deterministic and still closes the wrapper.
    $exited = Start-TestServer -Name "already_exited"
    $ownedPids.Add([int]$exited.Record.server_pid)
    Stop-Process -Id ([int]$exited.Record.server_pid) -Force
    Wait-Process -Id ([int]$exited.Record.server_pid) -Timeout 5 -ErrorAction SilentlyContinue
    Stop-OwnedWebServer -Launch $exited
    Assert-Test -Condition ($null -eq (Get-Process -Id $exited.Wrapper.Id -ErrorAction SilentlyContinue)) -Message "Already-exited child left its wrapper alive."

    # A hostile cached record cannot redirect cleanup to an unrelated process.
    $hostile = Start-TestServer -Name "hostile_record"
    $ownedPids.Add([int]$hostile.Record.server_pid)
    $hostile.Record.server_pid = $unrelated.Id
    $hostile.Record.server_start_utc_ticks = $unrelatedTicks
    Stop-OwnedWebServer -Launch $hostile
    $unrelatedAfter = Get-Process -Id $unrelated.Id -ErrorAction SilentlyContinue
    Assert-Test -Condition ($null -ne $unrelatedAfter -and $unrelatedAfter.StartTime.ToUniversalTime().Ticks -eq $unrelatedTicks) -Message "Hostile cached ownership redirected cleanup to an unrelated process."

    # Cleanup must report failure if its exact owned listener survives a stop.
    $sticky = Start-TestServer -Name "sticky_listener"
    $ownedPids.Add([int]$sticky.Record.server_pid)
    $stickyFailedClosed = $false
    & {
        function Stop-Process { param([int]$Id, [switch]$Force, $ErrorAction) }
        try { Stop-OwnedWebServer -Launch $sticky }
        catch { $script:stickyFailedClosed = $_.Exception.Message -like "*remained alive*" -and $_.Exception.Message -like "*still owns listener*" }
    }
    Assert-Test -Condition $stickyFailedClosed -Message "Cleanup silently succeeded while the exact owned listener remained."
    Microsoft.PowerShell.Management\Stop-Process -Id ([int]$sticky.Record.server_pid) -Force -ErrorAction SilentlyContinue
    Microsoft.PowerShell.Management\Stop-Process -Id $sticky.Wrapper.Id -Force -ErrorAction SilentlyContinue

    $unrelatedAfterAll = Get-Process -Id $unrelated.Id -ErrorAction SilentlyContinue
    Assert-Test -Condition ($null -ne $unrelatedAfterAll -and $unrelatedAfterAll.StartTime.ToUniversalTime().Ticks -eq $unrelatedTicks) -Message "An unrelated process did not survive the lifecycle suite."
    Write-Host "Web server lifecycle hostile tests passed."
}
finally {
    foreach ($ownedPid in $ownedPids) {
        Microsoft.PowerShell.Management\Stop-Process -Id $ownedPid -Force -ErrorAction SilentlyContinue
    }
    Microsoft.PowerShell.Management\Stop-Process -Id $unrelated.Id -Force -ErrorAction SilentlyContinue
}
