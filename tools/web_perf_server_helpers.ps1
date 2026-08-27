function Assert-TcpPortAvailable {
    param([int]$Port)
    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $Port)
    try {
        $listener.Start()
    }
    catch {
        throw "Refusing to start Web performance evidence: 127.0.0.1:$Port is already in use. Choose an unused port so the measured export is unambiguous."
    }
    finally {
        $listener.Stop()
    }
}

function Wait-ForOwnedWebServer {
    param([string]$Url, [int]$TimeoutSec, [string]$ExpectedToken, [System.Diagnostics.Process]$ServerProcess)
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        if ($ServerProcess.HasExited) {
            throw "Owned Web server exited before it became ready (exit code $($ServerProcess.ExitCode))."
        }
        try {
            $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 2
            $actualToken = [string]$response.Headers["X-BTH-Server-Token"]
            if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 500 -and $actualToken -eq $ExpectedToken) {
                return
            }
        }
        catch {
            Start-Sleep -Milliseconds 250
        }
    }
    throw "Timed out waiting for the owned web server at $Url."
}

function Stop-OwnedWebServerProcessTree {
    param([int]$RootProcessId, [string]$ServerToken, [int]$TimeoutSec = 10)
    if ($RootProcessId -le 0 -or [string]::IsNullOrWhiteSpace($ServerToken)) {
        return
    }
    $escapedToken = [regex]::Escape($ServerToken)
    $owned = @(Get-CimInstance Win32_Process | Where-Object { [string]$_.CommandLine -match $escapedToken })
    # The unguessable per-run token remains in every launched command line.
    # Stop token-bearing descendants before the recorded root; never inspect or
    # terminate unrelated listeners on the same port.
    foreach ($process in @($owned | Where-Object { $_.ProcessId -ne $RootProcessId })) {
        Stop-Process -Id $process.ProcessId -Force -ErrorAction SilentlyContinue
    }
    $root = @($owned | Where-Object { $_.ProcessId -eq $RootProcessId -and [string]$_.CommandLine -match $escapedToken })
    if ($root.Count -eq 1) {
        Stop-Process -Id $RootProcessId -Force -ErrorAction SilentlyContinue
    }
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    do {
        $remaining = @(Get-CimInstance Win32_Process | Where-Object { [string]$_.CommandLine -match $escapedToken })
        if ($remaining.Count -eq 0) {
            return
        }
        Start-Sleep -Milliseconds 100
    } while ((Get-Date) -lt $deadline)
    throw "Owned Web server process tree did not terminate for root PID $RootProcessId."
}
