function ConvertTo-WindowsProcessArgument {
    param([AllowEmptyString()][Parameter(Mandatory = $true)][string]$Argument)

    if ($Argument.Length -gt 0 -and $Argument -notmatch '[\s"]') {
        return $Argument
    }
    $quoted = [System.Text.StringBuilder]::new()
    [void]$quoted.Append('"')
    $backslashes = 0
    foreach ($character in $Argument.ToCharArray()) {
        if ($character -eq '\') {
            $backslashes += 1
            continue
        }
        if ($character -eq '"') {
            for ($index = 0; $index -lt (($backslashes * 2) + 1); $index += 1) {
                [void]$quoted.Append('\')
            }
            [void]$quoted.Append('"')
        }
        else {
            for ($index = 0; $index -lt $backslashes; $index += 1) {
                [void]$quoted.Append('\')
            }
            [void]$quoted.Append($character)
        }
        $backslashes = 0
    }
    for ($index = 0; $index -lt ($backslashes * 2); $index += 1) {
        [void]$quoted.Append('\')
    }
    [void]$quoted.Append('"')
    return $quoted.ToString()
}

function Get-ProcessStartUtcTicks {
    param([Parameter(Mandatory = $true)][int]$ProcessId)

    $process = Get-Process -Id $ProcessId -ErrorAction Stop
    return $process.StartTime.ToUniversalTime().Ticks
}

function Get-ExactServerChild {
    param(
        [Parameter(Mandatory = $true)][int]$WrapperProcessId,
        [Parameter(Mandatory = $true)][string]$ServerScript,
        [Parameter(Mandatory = $true)][int]$Port
    )

    $expectedScript = [System.IO.Path]::GetFullPath($ServerScript)
    $expectedScriptPattern = "*{0}*" -f [System.Management.Automation.WildcardPattern]::Escape($expectedScript)
    $matches = @(Get-CimInstance Win32_Process -ErrorAction Stop | Where-Object {
        [int]$_.ParentProcessId -eq $WrapperProcessId -and
        [string]$_.Name -like "python*" -and
        [string]$_.CommandLine -like $expectedScriptPattern -and
        [string]$_.CommandLine -like "*--port $Port*"
    })
    if ($matches.Count -ne 1) {
        throw "Expected exactly one owned Python server child of wrapper PID $WrapperProcessId; found $($matches.Count)."
    }
    return $matches[0]
}

function Read-OwnedWebServerRecord {
    param(
        [Parameter(Mandatory = $true)][string]$OwnershipFile,
        [Parameter(Mandatory = $true)][string]$OwnershipNonce,
        [Parameter(Mandatory = $true)][int]$WrapperProcessId,
        [Parameter(Mandatory = $true)][string]$ServerScript,
        [Parameter(Mandatory = $true)][int]$Port,
        [switch]$AllowExited
    )

    if (-not (Test-Path -LiteralPath $OwnershipFile)) {
        throw "Owned Web server did not publish its process record: $OwnershipFile"
    }
    $record = Get-Content -LiteralPath $OwnershipFile -Raw | ConvertFrom-Json
    if ([string]$record.nonce -ne $OwnershipNonce -or [int]$record.wrapper_pid -ne $WrapperProcessId -or [int]$record.port -ne $Port) {
        throw "Owned Web server process record did not match its launch identity."
    }
    $serverProcess = Get-Process -Id ([int]$record.server_pid) -ErrorAction SilentlyContinue
    if ($null -eq $serverProcess -and $AllowExited) {
        return $record
    }
    $child = Get-ExactServerChild -WrapperProcessId $WrapperProcessId -ServerScript $ServerScript -Port $Port
    if ([int]$record.server_pid -ne [int]$child.ProcessId) {
        throw "Owned Web server process record did not match the exact launched child."
    }
    $actualTicks = Get-ProcessStartUtcTicks -ProcessId ([int]$record.server_pid)
    if ([int64]$record.server_start_utc_ticks -ne [int64]$actualTicks) {
        throw "Owned Web server PID was reused or its start identity changed."
    }
    return $record
}

function Start-OwnedWebServer {
    param(
        [Parameter(Mandatory = $true)][string]$ServeScript,
        [Parameter(Mandatory = $true)][string]$ServerScript,
        [Parameter(Mandatory = $true)][string]$ServeRoot,
        [Parameter(Mandatory = $true)][int]$Port,
        [Parameter(Mandatory = $true)][string]$OwnershipFile,
        [Parameter(Mandatory = $true)][string]$StandardOutput,
        [Parameter(Mandatory = $true)][string]$StandardError
    )

    if (Test-Path -LiteralPath $OwnershipFile) {
        throw "Refusing to reuse an existing Web server ownership record: $OwnershipFile"
    }
    $shutdownFile = "$OwnershipFile.shutdown"
    if (Test-Path -LiteralPath $shutdownFile) {
        throw "Refusing to reuse an existing Web server shutdown record: $shutdownFile"
    }
    $nonce = [guid]::NewGuid().ToString("N")
    $arguments = @(
        "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $ServeScript,
        "-Port", [string]$Port, "-ServeRoot", $ServeRoot, "-NoBrowser",
        "-OwnershipFile", $OwnershipFile, "-OwnershipNonce", $nonce,
        "-ShutdownFile", $shutdownFile
    )
    $quotedArguments = @($arguments | ForEach-Object { ConvertTo-WindowsProcessArgument -Argument ([string]$_) })
    $wrapper = Start-Process -FilePath (Get-Command powershell -ErrorAction Stop).Source -ArgumentList $quotedArguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $StandardOutput -RedirectStandardError $StandardError
    $launch = [pscustomobject]@{
        Wrapper = $wrapper
        WrapperStartUtcTicks = $wrapper.StartTime.ToUniversalTime().Ticks
        OwnershipFile = $OwnershipFile
        OwnershipNonce = $nonce
        ShutdownFile = $shutdownFile
        ServerScript = $ServerScript
        Port = $Port
        StandardOutput = $StandardOutput
        StandardError = $StandardError
        Record = $null
    }
    try {
        $deadline = (Get-Date).AddSeconds(15)
        while ((Get-Date) -lt $deadline -and -not (Test-Path -LiteralPath $OwnershipFile)) {
            if ($wrapper.HasExited) {
                throw "Web server wrapper exited before publishing process ownership (exit $($wrapper.ExitCode))."
            }
            Start-Sleep -Milliseconds 50
        }
        $launch.Record = Read-OwnedWebServerRecord -OwnershipFile $OwnershipFile -OwnershipNonce $nonce -WrapperProcessId $wrapper.Id -ServerScript $ServerScript -Port $Port
        return $launch
    }
    catch {
        try { Stop-OwnedWebServer -Launch $launch } catch { }
        throw
    }
}

function Request-OwnedWebServerShutdown {
    param([Parameter(Mandatory = $true)]$Launch)

    $shutdownAlreadyRequested = Test-Path -LiteralPath $Launch.ShutdownFile
    $record = Read-OwnedWebServerRecord -OwnershipFile $Launch.OwnershipFile -OwnershipNonce $Launch.OwnershipNonce -WrapperProcessId $Launch.Wrapper.Id -ServerScript $Launch.ServerScript -Port $Launch.Port -AllowExited:$shutdownAlreadyRequested
    if ([string]$record.shutdown_file -ne [System.IO.Path]::GetFullPath($Launch.ShutdownFile)) {
        throw "Owned Web server shutdown record did not match its launch identity."
    }
    if ($shutdownAlreadyRequested) {
        if ([string](Get-Content -LiteralPath $Launch.ShutdownFile -Raw) -eq $Launch.OwnershipNonce) { return }
        throw "Owned Web server shutdown path already contained a different identity."
    }
    $temporaryShutdownPath = "$($Launch.ShutdownFile).$PID.tmp"
    Set-Content -LiteralPath $temporaryShutdownPath -Value $Launch.OwnershipNonce -NoNewline -Encoding ascii
    Move-Item -LiteralPath $temporaryShutdownPath -Destination $Launch.ShutdownFile
}

function Assert-OwnedWebServerListener {
    param([Parameter(Mandatory = $true)]$Launch)

    $record = Read-OwnedWebServerRecord -OwnershipFile $Launch.OwnershipFile -OwnershipNonce $Launch.OwnershipNonce -WrapperProcessId $Launch.Wrapper.Id -ServerScript $Launch.ServerScript -Port $Launch.Port
    $ownedListeners = @(Get-NetTCPConnection -State Listen -LocalAddress "127.0.0.1" -LocalPort $Launch.Port -ErrorAction SilentlyContinue | Where-Object { [int]$_.OwningProcess -eq [int]$record.server_pid })
    if ($ownedListeners.Count -ne 1) {
        throw "Exact launched Python PID $($record.server_pid) does not own the expected listener on 127.0.0.1:$($Launch.Port)."
    }
    $Launch.Record = $record
}

function Stop-OwnedWebServer {
    param([Parameter(Mandatory = $true)]$Launch)

    $failures = [System.Collections.Generic.List[string]]::new()
    $record = $null
    try {
        # Re-read the nonce-bound record for cleanup; never trust a caller-mutated
        # cached PID. An already-exited child is an accepted deterministic case.
        $record = Read-OwnedWebServerRecord -OwnershipFile $Launch.OwnershipFile -OwnershipNonce $Launch.OwnershipNonce -WrapperProcessId $Launch.Wrapper.Id -ServerScript $Launch.ServerScript -Port $Launch.Port -AllowExited
    }
    catch {
        # A host interruption can stop the wrapper before its record is read.
        # Recover only an unambiguous direct child with the exact script/port.
        try {
            $child = Get-ExactServerChild -WrapperProcessId $Launch.Wrapper.Id -ServerScript $Launch.ServerScript -Port $Launch.Port
            $record = [pscustomobject]@{
                server_pid = [int]$child.ProcessId
                server_start_utc_ticks = Get-ProcessStartUtcTicks -ProcessId ([int]$child.ProcessId)
            }
        }
        catch {
            $failures.Add("Could not establish exact launched Web server ownership during cleanup: $($_.Exception.Message)")
        }
    }

    if ($null -ne $record) {
        try {
            Request-OwnedWebServerShutdown -Launch $Launch
        }
        catch {
            $failures.Add("Could not publish exact owned Web server shutdown intent: $($_.Exception.Message)")
        }
        $serverProcess = Get-Process -Id ([int]$record.server_pid) -ErrorAction SilentlyContinue
        if ($null -ne $serverProcess) {
            $actualTicks = $serverProcess.StartTime.ToUniversalTime().Ticks
            if ([int64]$actualTicks -ne [int64]$record.server_start_utc_ticks) {
                $failures.Add("Refused to stop reused server PID $($record.server_pid).")
            }
            else {
                Stop-Process -Id ([int]$record.server_pid) -Force -ErrorAction SilentlyContinue
                try { Wait-Process -Id ([int]$record.server_pid) -Timeout 5 -ErrorAction Stop } catch { }
                if ($null -ne (Get-Process -Id ([int]$record.server_pid) -ErrorAction SilentlyContinue)) {
                    $failures.Add("Exact launched server PID $($record.server_pid) remained alive after cleanup.")
                }
            }
        }
        $ownedListener = @(Get-NetTCPConnection -State Listen -LocalPort $Launch.Port -ErrorAction SilentlyContinue | Where-Object { [int]$_.OwningProcess -eq [int]$record.server_pid })
        if ($ownedListener.Count -gt 0) {
            $failures.Add("Exact launched server PID $($record.server_pid) still owns listener port $($Launch.Port) after cleanup.")
        }
    }

    $wrapperProcess = Get-Process -Id $Launch.Wrapper.Id -ErrorAction SilentlyContinue
    if ($null -ne $wrapperProcess) {
        $actualWrapperTicks = $wrapperProcess.StartTime.ToUniversalTime().Ticks
        if ([int64]$actualWrapperTicks -ne [int64]$Launch.WrapperStartUtcTicks) {
            $failures.Add("Refused to stop reused wrapper PID $($Launch.Wrapper.Id).")
        }
        else {
            try { Wait-Process -Id $Launch.Wrapper.Id -Timeout 5 -ErrorAction Stop } catch { }
            $wrapperProcess = Get-Process -Id $Launch.Wrapper.Id -ErrorAction SilentlyContinue
            if ($null -ne $wrapperProcess) {
                Stop-Process -Id $Launch.Wrapper.Id -Force -ErrorAction SilentlyContinue
                try { Wait-Process -Id $Launch.Wrapper.Id -Timeout 5 -ErrorAction Stop } catch { }
                if ($null -ne (Get-Process -Id $Launch.Wrapper.Id -ErrorAction SilentlyContinue)) {
                    $failures.Add("Exact launched wrapper PID $($Launch.Wrapper.Id) remained alive after cleanup.")
                }
            }
        }
    }
    if ($failures.Count -gt 0) {
        throw ($failures -join " ")
    }
}
