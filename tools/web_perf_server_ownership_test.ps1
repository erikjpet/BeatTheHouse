param(
    [string]$OutDir = ".tmp/web_perf_server_ownership_test"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "web_perf_server_helpers.ps1")
$absoluteOutDir = Join-Path $root $OutDir
if (Test-Path -LiteralPath $absoluteOutDir) {
    throw "Refusing to overwrite Web performance server-ownership evidence: $absoluteOutDir"
}
New-Item -ItemType Directory -Path $absoluteOutDir | Out-Null

$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
$listener.Start()
$port = ([System.Net.IPEndPoint]$listener.LocalEndpoint).Port
$relativeReport = Join-Path $OutDir "report.json"
$stdoutPath = Join-Path $absoluteOutDir "wrapper_stdout.txt"
$stderrPath = Join-Path $absoluteOutDir "wrapper_stderr.txt"
try {
    $childArgs = @(
        "-ExecutionPolicy", "Bypass",
        "-File", (Join-Path $PSScriptRoot "web_perf_smoke.ps1"),
        "-Plan", "l02",
        "-SkipExport",
        "-Port", [string]$port,
        "-TimeoutMs", "1000",
        "-Out", $relativeReport
    )
    $child = Start-Process -FilePath (Get-Command powershell -ErrorAction Stop).Source -ArgumentList $childArgs -PassThru -Wait `
        -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -WindowStyle Hidden
    $exitCode = $child.ExitCode
}
finally {
    $listener.Stop()
}

$failurePath = Join-Path $absoluteOutDir "report.failure.json"
$reportPath = Join-Path $absoluteOutDir "report.json"
if ($exitCode -eq 0) {
    throw "Occupied-port wrapper probe unexpectedly succeeded."
}
if (Test-Path -LiteralPath $reportPath) {
    throw "Occupied-port wrapper probe produced a timing report."
}
if (-not (Test-Path -LiteralPath $failurePath)) {
    throw "Occupied-port wrapper probe did not retain its failure manifest."
}
$failure = Get-Content -LiteralPath $failurePath -Raw | ConvertFrom-Json
if ([string]$failure.status -ne "failed_before_report" -or [int]$failure.port -ne $port) {
    throw "Occupied-port failure manifest did not preserve the expected identity."
}
if ([string]$failure.error -notmatch "already in use") {
    throw "Occupied-port failure manifest did not explain the ownership collision."
}

function Invoke-OwnedLifecycleCase {
    param([string]$CaseName, [bool]$InjectFailure)
    $portProbe = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
    $portProbe.Start()
    $casePort = ([System.Net.IPEndPoint]$portProbe.LocalEndpoint).Port
    $portProbe.Stop()
    $serverToken = [guid]::NewGuid().ToString("N")
    $serverStdout = Join-Path $absoluteOutDir ("{0}_server_stdout.txt" -f $CaseName)
    $serverStderr = Join-Path $absoluteOutDir ("{0}_server_stderr.txt" -f $CaseName)
    $serverArgs = @(
        "-ExecutionPolicy", "Bypass",
        "-File", (Join-Path $PSScriptRoot "serve_web.ps1"),
        "-Port", [string]$casePort,
        "-ServerToken", $serverToken,
        "-NoBrowser"
    )
    $server = $null
    $injectedCaught = $false
    try {
        $server = Start-Process -FilePath (Get-Command powershell -ErrorAction Stop).Source -ArgumentList $serverArgs -PassThru `
            -RedirectStandardOutput $serverStdout -RedirectStandardError $serverStderr -WindowStyle Hidden
        Wait-ForOwnedWebServer -Url "http://127.0.0.1:$casePort/" -TimeoutSec 10 -ExpectedToken $serverToken -ServerProcess $server
        if ($InjectFailure) {
            throw "Injected owned-server lifecycle failure."
        }
    }
    catch {
        if (-not $InjectFailure -or $_.Exception.Message -ne "Injected owned-server lifecycle failure.") {
            throw
        }
        $injectedCaught = $true
    }
    finally {
        if ($server -ne $null) {
            Stop-OwnedWebServerProcessTree -RootProcessId $server.Id -ServerToken $serverToken
        }
    }
    if ($InjectFailure -and -not $injectedCaught) {
        throw "Failure lifecycle case did not execute its injected failure."
    }
    $escapedToken = [regex]::Escape($serverToken)
    $remaining = @(Get-CimInstance Win32_Process | Where-Object { [string]$_.CommandLine -match $escapedToken })
    if ($remaining.Count -ne 0) {
        throw "$CaseName left an owned token-bearing child process."
    }
    Assert-TcpPortAvailable -Port $casePort
}

Invoke-OwnedLifecycleCase -CaseName "success" -InjectFailure $false
Invoke-OwnedLifecycleCase -CaseName "failure" -InjectFailure $true

Write-Host "Web performance server ownership test passed."
Write-Host ("Failure manifest: {0}" -f $failurePath)
