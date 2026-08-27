param(
    [string]$OutDir = ".tmp/web_perf_server_ownership_test"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
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

$serverToken = [guid]::NewGuid().ToString("N")
$serverStdout = Join-Path $absoluteOutDir "owned_server_stdout.txt"
$serverStderr = Join-Path $absoluteOutDir "owned_server_stderr.txt"
$serverArgs = @(
    "-ExecutionPolicy", "Bypass",
    "-File", (Join-Path $PSScriptRoot "serve_web.ps1"),
    "-Port", [string]$port,
    "-ServerToken", $serverToken,
    "-NoBrowser"
)
$server = $null
try {
    $server = Start-Process -FilePath (Get-Command powershell -ErrorAction Stop).Source -ArgumentList $serverArgs -PassThru `
        -RedirectStandardOutput $serverStdout -RedirectStandardError $serverStderr -WindowStyle Hidden
    $deadline = (Get-Date).AddSeconds(10)
    $authenticated = $false
    while ((Get-Date) -lt $deadline) {
        if ($server.HasExited) {
            throw "Owned test server exited before authentication."
        }
        try {
            $response = Invoke-WebRequest -Uri "http://127.0.0.1:$port/" -UseBasicParsing -TimeoutSec 2
            $authenticated = [string]$response.Headers["X-BTH-Server-Token"] -eq $serverToken
            if ($authenticated) {
                break
            }
        }
        catch {
            Start-Sleep -Milliseconds 100
        }
    }
    if (-not $authenticated) {
        throw "Owned test server did not return its unique authentication token."
    }
}
finally {
    if ($server -ne $null) {
        Get-CimInstance Win32_Process | Where-Object { $_.ParentProcessId -eq $server.Id } | ForEach-Object {
            Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
        }
        if (-not $server.HasExited) {
            Stop-Process -Id $server.Id -Force -ErrorAction SilentlyContinue
        }
    }
}

Write-Host "Web performance server ownership test passed."
Write-Host ("Failure manifest: {0}" -f $failurePath)
