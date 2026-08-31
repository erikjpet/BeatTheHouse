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

function Get-CopyablePythonExecutable {
    $command = Get-Command python -ErrorAction Stop
    $item = Get-Item -LiteralPath $command.Source -ErrorAction SilentlyContinue
    if ($null -ne $item -and $item.Length -gt 0) { return $item.FullName }
    $launcher = Get-Command py -ErrorAction SilentlyContinue
    if ($null -ne $launcher) {
        $priorErrorPreference = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        $launcherRows = @(& $launcher.Source -0p 2>$null)
        $ErrorActionPreference = $priorErrorPreference
        foreach ($row in $launcherRows) {
            if ([string]$row -notmatch '-(?<version>[0-9]+\.[0-9]+)') { continue }
            $ErrorActionPreference = "Continue"
            $candidate = (& $launcher.Source ("-{0}" -f $Matches.version) -c "import sys;print(sys.executable)" 2>$null | Select-Object -First 1)
            $ErrorActionPreference = $priorErrorPreference
            $candidateItem = Get-Item -LiteralPath ([string]$candidate).Trim() -ErrorAction SilentlyContinue
            if ($null -ne $candidateItem -and $candidateItem.Length -gt 0) { return $candidateItem.FullName }
        }
    }
    throw "Focused spaced-runtime coverage could not locate a copyable Python executable."
}

function Start-TestServer {
    param(
        [string]$Name,
        [string]$ServeScript = (Join-Path $PSScriptRoot "serve_web.ps1"),
        [string]$ServerScript = (Join-Path $PSScriptRoot "serve_web_server.py"),
        [string]$Root = $serveRoot
    )
    $caseDirectory = Join-Path $testRoot $Name
    New-Item -ItemType Directory -Force -Path $caseDirectory | Out-Null
    $ownershipFile = Join-Path $caseDirectory "ownership.json"
    return Start-OwnedWebServer `
        -ServeScript $ServeScript `
        -ServerScript $ServerScript `
        -ServeRoot $Root `
        -Port (Get-FreeLoopbackPort) `
        -OwnershipFile $ownershipFile `
        -StandardOutput (Join-Path $caseDirectory "stdout.txt") `
        -StandardError (Join-Path $caseDirectory "stderr.txt")
}

function Assert-CleanLifecycleStderr {
    param($Launch, [string]$CaseName, [switch]$AllowHttpAccessLog)
    $stderr = if (Test-Path -LiteralPath $Launch.StandardError) { Get-Content -LiteralPath $Launch.StandardError -Raw } else { "" }
    $unexpectedLines = @([string]$stderr -split "`r?`n" | Where-Object {
        -not [string]::IsNullOrWhiteSpace($_) -and
        (-not $AllowHttpAccessLog -or [string]$_ -notmatch '^127\.0\.0\.1 - - \[.*\] "GET / HTTP/1\.1" 200 -$')
    })
    Assert-Test -Condition ($unexpectedLines.Count -eq 0) -Message "$CaseName emitted unexpected lifecycle stderr: $stderr"
}

$testRoot = Join-Path $root (".tmp/fix06_16_lifecycle_test_{0}" -f [guid]::NewGuid().ToString("N"))
$serveRoot = Join-Path $testRoot "site"
New-Item -ItemType Directory -Force -Path $serveRoot | Out-Null
Set-Content -LiteralPath (Join-Path $serveRoot "index.html") -Value "fix06_16 lifecycle fixture" -Encoding utf8

$python = (Get-Command python -ErrorAction Stop).Source
$copyablePython = Get-CopyablePythonExecutable
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
        Assert-CleanLifecycleStderr -Launch $launch -CaseName $caseName
    }

    # Host interruption: the wrapper can be gone before outer cleanup begins.
    $interrupted = Start-TestServer -Name "host_interruption"
    $ownedPids.Add([int]$interrupted.Record.server_pid)
    Stop-Process -Id $interrupted.Wrapper.Id -Force
    Wait-Process -Id $interrupted.Wrapper.Id -Timeout 5 -ErrorAction SilentlyContinue
    Assert-Test -Condition ($null -ne (Get-Process -Id ([int]$interrupted.Record.server_pid) -ErrorAction SilentlyContinue)) -Message "Host interruption fixture did not preserve the orphan reproduction."
    Stop-OwnedWebServer -Launch $interrupted
    Assert-Test -Condition ($null -eq (Get-Process -Id ([int]$interrupted.Record.server_pid) -ErrorAction SilentlyContinue)) -Message "Host interruption cleanup left its exact child alive."
    Assert-CleanLifecycleStderr -Launch $interrupted -CaseName "host interruption"

    # Missing/already-exited child is deterministic and still closes the wrapper.
    $exited = Start-TestServer -Name "already_exited"
    $ownedPids.Add([int]$exited.Record.server_pid)
    Request-OwnedWebServerShutdown -Launch $exited
    Stop-Process -Id ([int]$exited.Record.server_pid) -Force
    Wait-Process -Id ([int]$exited.Record.server_pid) -Timeout 5 -ErrorAction SilentlyContinue
    Stop-OwnedWebServer -Launch $exited
    Assert-Test -Condition ($null -eq (Get-Process -Id $exited.Wrapper.Id -ErrorAction SilentlyContinue)) -Message "Already-exited child left its wrapper alive."
    Assert-CleanLifecycleStderr -Launch $exited -CaseName "already-exited expected cleanup"

    # A hostile cached record cannot redirect cleanup to an unrelated process.
    $hostile = Start-TestServer -Name "hostile_record"
    $ownedPids.Add([int]$hostile.Record.server_pid)
    $hostile.Record.server_pid = $unrelated.Id
    $hostile.Record.server_start_utc_ticks = $unrelatedTicks
    Stop-OwnedWebServer -Launch $hostile
    $unrelatedAfter = Get-Process -Id $unrelated.Id -ErrorAction SilentlyContinue
    Assert-Test -Condition ($null -ne $unrelatedAfter -and $unrelatedAfter.StartTime.ToUniversalTime().Ticks -eq $unrelatedTicks) -Message "Hostile cached ownership redirected cleanup to an unrelated process."

    # A child exit without the nonce-bound shutdown request remains a failure.
    $unexpected = Start-TestServer -Name "unexpected_exit"
    $ownedPids.Add([int]$unexpected.Record.server_pid)
    Stop-Process -Id ([int]$unexpected.Record.server_pid) -Force
    Wait-Process -Id ([int]$unexpected.Record.server_pid) -Timeout 5 -ErrorAction SilentlyContinue
    Wait-Process -Id $unexpected.Wrapper.Id -Timeout 5 -ErrorAction SilentlyContinue
    $unexpectedStderr = Get-Content -LiteralPath $unexpected.StandardError -Raw
    Assert-Test -Condition ([string]$unexpectedStderr -match 'Local Web server exited unexpectedly with code (unknown|-?[0-9]+)\.') -Message "Unexpected child exit did not fail closed with a numeric or explicit unknown identity through serve_web stderr."
    $unexpectedCleanupFailed = $false
    try { Stop-OwnedWebServer -Launch $unexpected }
    catch { $unexpectedCleanupFailed = $_.Exception.Message -like "*Could not publish exact owned Web server shutdown intent*" }
    Assert-Test -Condition $unexpectedCleanupFailed -Message "Unexpected already-exited child was retroactively classified as requested shutdown."

    # Deterministically kill the child after identity check but before request
    # publication. No child acknowledgement means the wrapper must reject it.
    $requestRace = Start-TestServer -Name "request_publication_race"
    $ownedPids.Add([int]$requestRace.Record.server_pid)
    $requestRaceFailed = $false
    try {
        Request-OwnedWebServerShutdown -Launch $requestRace -BeforeShutdownPublication {
            param($raceLaunch)
            Stop-Process -Id ([int]$raceLaunch.Record.server_pid) -Force
            Wait-Process -Id ([int]$raceLaunch.Record.server_pid) -Timeout 5 -ErrorAction SilentlyContinue
        }
    }
    catch { $requestRaceFailed = $_.Exception.Message -like "*before acknowledging shutdown*" }
    Assert-Test -Condition $requestRaceFailed -Message "Check-to-publication race was accepted without a live-child acknowledgement."
    Wait-Process -Id $requestRace.Wrapper.Id -Timeout 5 -ErrorAction SilentlyContinue
    $requestRaceStderr = Get-Content -LiteralPath $requestRace.StandardError -Raw
    Assert-Test -Condition ([string]$requestRaceStderr -match 'Local Web server exited unexpectedly with code (unknown|-?[0-9]+)\.') -Message "Check-to-publication race did not remain an unexpected wrapper failure."
    Assert-Test -Condition (-not (Test-Path -LiteralPath $requestRace.ShutdownAckFile)) -Message "Exited child fabricated a shutdown acknowledgement."
    try { Stop-OwnedWebServer -Launch $requestRace } catch { }

    # Cleanup must report failure if its exact owned listener survives a stop.
    $sticky = Start-TestServer -Name "sticky_listener"
    $ownedPids.Add([int]$sticky.Record.server_pid)
    $stickyFailedClosed = $false
    $wrapperReuseProtected = $false
    $fallbackTerminationTargets = [System.Collections.Generic.List[int]]::new()
    $unrelatedTerminationTargets = [System.Collections.Generic.List[int]]::new()
    & {
        function Stop-Process { param([int]$Id, [switch]$Force, $ErrorAction) }
        try {
            Stop-OwnedWebServer -Launch $sticky -WrapperFallbackProcessResolver {
                param($ignoredProcessId)
                return [pscustomobject]@{
                    Id = $sticky.Wrapper.Id
                    StartTime = (Get-Process -Id $unrelated.Id -ErrorAction Stop).StartTime
                }
            } -WrapperFallbackTerminator {
                param($terminationTarget)
                $fallbackTerminationTargets.Add([int]$terminationTarget)
            }
        }
        catch {
            $script:stickyFailedClosed = $_.Exception.Message -like "*remained alive*" -and $_.Exception.Message -like "*still owns listener*"
            $script:wrapperReuseProtected = $_.Exception.Message -like "*changed identity*"
        }
        try {
            Stop-OwnedWebServer -Launch $sticky -WrapperFallbackProcessResolver {
                param($ignoredProcessId)
                return Get-Process -Id $unrelated.Id -ErrorAction Stop
            } -WrapperFallbackTerminator {
                param($terminationTarget)
                $unrelatedTerminationTargets.Add([int]$terminationTarget)
            }
        }
        catch { }
    }
    Assert-Test -Condition $stickyFailedClosed -Message "Cleanup silently succeeded while the exact owned listener remained."
    Assert-Test -Condition $wrapperReuseProtected -Message "Wrapper fallback did not reject the injected PID-reuse identity."
    Assert-Test -Condition ($fallbackTerminationTargets.Count -eq 0) -Message "StartTime-mismatched wrapper identity reached fallback termination."
    Assert-Test -Condition ($unrelatedTerminationTargets.Count -eq 0) -Message "Unrelated live process identity reached fallback termination."
    Assert-Test -Condition (-not $unrelatedTerminationTargets.Contains([int]$unrelated.Id)) -Message "Fallback termination targeted an unrelated live process."
    Assert-Test -Condition ($null -ne (Get-Process -Id $unrelated.Id -ErrorAction SilentlyContinue)) -Message "Injected wrapper PID-reuse boundary stopped the unrelated replacement."
    Microsoft.PowerShell.Management\Stop-Process -Id ([int]$sticky.Record.server_pid) -Force -ErrorAction SilentlyContinue
    Microsoft.PowerShell.Management\Stop-Process -Id $sticky.Wrapper.Id -Force -ErrorAction SilentlyContinue

    $unrelatedAfterAll = Get-Process -Id $unrelated.Id -ErrorAction SilentlyContinue
    Assert-Test -Condition ($null -ne $unrelatedAfterAll -and $unrelatedAfterAll.StartTime.ToUniversalTime().Ticks -eq $unrelatedTicks) -Message "An unrelated process did not survive the lifecycle suite."

    # Both native launch boundaries must preserve every spaced path as one arg.
    $spacedToolRoot = Join-Path $testRoot "tool scripts with spaces"
    $spacedServeRoot = Join-Path $testRoot "served root with spaces"
    $spacedPythonRoot = Join-Path $testRoot "python runtime with spaces"
    New-Item -ItemType Directory -Force -Path $spacedToolRoot, $spacedServeRoot, $spacedPythonRoot | Out-Null
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot "serve_web.ps1") -Destination $spacedToolRoot
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot "serve_web_server.py") -Destination $spacedToolRoot
    Copy-Item -LiteralPath $copyablePython -Destination (Join-Path $spacedPythonRoot "python.exe")
    Set-Content -LiteralPath (Join-Path $spacedServeRoot "index.html") -Value "spaced lifecycle fixture" -Encoding utf8
    $originalPath = $env:Path
    $originalPythonHome = $env:PYTHONHOME
    try {
        $copyablePythonRoot = Split-Path -Parent $copyablePython
        $env:Path = "$spacedPythonRoot;$copyablePythonRoot;$originalPath"
        $env:PYTHONHOME = $copyablePythonRoot
        $spaced = Start-TestServer -Name "ownership and logs with spaces" -ServeScript (Join-Path $spacedToolRoot "serve_web.ps1") -ServerScript (Join-Path $spacedToolRoot "serve_web_server.py") -Root $spacedServeRoot
        $ownedPids.Add([int]$spaced.Record.server_pid)
        try {
            $deadline = (Get-Date).AddSeconds(10)
            $response = $null
            while ((Get-Date) -lt $deadline -and $null -eq $response) {
                try { $response = Invoke-WebRequest -Uri ("http://127.0.0.1:{0}/" -f $spaced.Port) -UseBasicParsing -TimeoutSec 2 }
                catch { Start-Sleep -Milliseconds 100 }
            }
            Assert-Test -Condition ($null -ne $response -and [string]$response.Content -like "*spaced lifecycle fixture*") -Message "Spaced serve-root did not return the exact fixture."
            Assert-Test -Condition ([string]$response.Headers["Cross-Origin-Opener-Policy"] -eq "same-origin") -Message "Spaced server lost the opener isolation header."
            Assert-Test -Condition ([string]$response.Headers["Cross-Origin-Embedder-Policy"] -eq "require-corp") -Message "Spaced server lost the embedder isolation header."
            Assert-Test -Condition (Test-Path -LiteralPath $spaced.OwnershipFile) -Message "Spaced ownership path was not published."
            Assert-OwnedWebServerListener -Launch $spaced
        }
        finally { Stop-OwnedWebServer -Launch $spaced }
    }
    finally {
        $env:Path = $originalPath
        $env:PYTHONHOME = $originalPythonHome
    }
    Assert-Test -Condition ($null -eq (Get-Process -Id ([int]$spaced.Record.server_pid) -ErrorAction SilentlyContinue)) -Message "Spaced-path server child survived cleanup."
    Assert-Test -Condition (@(Get-NetTCPConnection -State Listen -LocalPort $spaced.Port -ErrorAction SilentlyContinue).Count -eq 0) -Message "Spaced-path listener survived cleanup."
    Assert-CleanLifecycleStderr -Launch $spaced -CaseName "spaced-path cleanup" -AllowHttpAccessLog
    $unrelatedAfterSpaces = Get-Process -Id $unrelated.Id -ErrorAction SilentlyContinue
    Assert-Test -Condition ($null -ne $unrelatedAfterSpaces -and $unrelatedAfterSpaces.StartTime.ToUniversalTime().Ticks -eq $unrelatedTicks) -Message "Spaced-path cleanup stopped the unrelated process."
    Write-Host "Web server lifecycle hostile tests passed."
}
finally {
    foreach ($ownedPid in $ownedPids) {
        Microsoft.PowerShell.Management\Stop-Process -Id $ownedPid -Force -ErrorAction SilentlyContinue
    }
    Microsoft.PowerShell.Management\Stop-Process -Id $unrelated.Id -Force -ErrorAction SilentlyContinue
}
