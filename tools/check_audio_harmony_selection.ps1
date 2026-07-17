param([int]$TimeoutSec = 300)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

function Find-Godot {
    if ($env:GODOT_BIN) { return $env:GODOT_BIN }
    $local = Get-ChildItem -LiteralPath (Join-Path $root ".tools") -Filter "Godot*_console.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $local) { $local = Get-ChildItem -LiteralPath (Join-Path $root ".tools") -Filter "Godot*.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 }
    if ($local) { return $local.FullName }
    $command = Get-Command godot -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    throw "Godot executable not found."
}

function Assert-No-Godot {
    $running = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like "*Godot*" })
    if ($running.Count -gt 0) { throw "Refusing to overlap Godot processes: $($running.Id -join ', ')" }
}

function Stop-OwnedProcessTree([System.Diagnostics.Process]$Process) {
    if ($null -eq $Process -or $Process.HasExited) { return }
    # taskkill /T is scoped to the exact PID created below and its descendants;
    # it cannot match or terminate an unrelated Godot process by name.
    $taskkill = Join-Path $env:SystemRoot "System32\taskkill.exe"
    $previousErrorPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "SilentlyContinue"
        & $taskkill /PID $Process.Id /T /F 1>$null 2>$null
    } finally {
        $ErrorActionPreference = $previousErrorPreference
    }
    if (-not $Process.WaitForExit(5000) -and -not $Process.HasExited) {
        $Process.Kill()
        $Process.WaitForExit()
    }
}

function Invoke-Probe([string]$Godot) {
    Assert-No-Godot
    if ($TimeoutSec -le 0) { throw "TimeoutSec must be a positive number of seconds." }
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $Godot
    $logPath = Join-Path $root (".tmp\audio_harmony_selection_{0}.godot.log" -f [Guid]::NewGuid().ToString("N"))
    $startInfo.Arguments = '--headless --disable-crash-handler --log-file "{0}" --path "{1}" --script "res://tools/audio_harmony_selection_probe.gd"' -f ($logPath -replace '"', '\"'), ($root -replace '"', '\"')
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    if (-not $process.Start()) { throw "Failed to start harmony selection probe." }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $timeoutMs = [int][Math]::Min([int]::MaxValue, [long]$TimeoutSec * 1000L)
    $timedOut = -not $process.WaitForExit($timeoutMs)
    if ($timedOut) { Stop-OwnedProcessTree $process }
    # The parameterless wait flushes redirected asynchronous stream events.
    $process.WaitForExit()
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    $exitCode = $process.ExitCode
    $process.Dispose()
    $output = @($stdout, $stderr) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }
    if ($timedOut) {
        throw "Harmony probe exceeded TimeoutSec=$TimeoutSec and its owned process tree was terminated.`n$($output -join [Environment]::NewLine)"
    }
    if ($exitCode -ne 0) { throw ($output -join [Environment]::NewLine) }
    $lines = @($stdout -split "`r?`n")
    $line = @($lines | Where-Object { $_ -like "AUDIO_HARMONY_SELECTION_CANONICAL *" }) | Select-Object -Last 1
    if (-not $line) { throw "Harmony probe did not emit canonical output.`n$($output -join [Environment]::NewLine)" }
    return [string]$line
}

$godot = Find-Godot
$first = Invoke-Probe $godot
$second = Invoke-Probe $godot
if ($first -ne $second) { throw "Fresh-process harmony selection output differed.`nFIRST: $first`nSECOND: $second" }
$sha = [System.Security.Cryptography.SHA256]::Create()
try {
    $digest = ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($first)))).Replace("-", "").ToLowerInvariant()
} finally {
    $sha.Dispose()
}
Write-Host "Audio harmony selection probe passed twice with identical canonical output (sha256=$digest)."
