# Serves the local Web build with production-compatible isolation headers.
#
# The Web preset is single-threaded, but its GDExtension side module still
# requires cross-origin isolation. These headers match the required itch.io
# SharedArrayBuffer hosting mode:
#   Cross-Origin-Opener-Policy: same-origin
#   Cross-Origin-Embedder-Policy: require-corp
# This script serves builds/web with those required headers.
#
# Examples:
#   .\tools\serve_web.ps1               # serve at http://127.0.0.1:8060 and open a browser
#   .\tools\serve_web.ps1 -Port 9000
#   .\tools\serve_web.ps1 -NoBrowser
#
# Requires Python 3 on PATH. Press Ctrl+C to stop.

param(
    [int]$Port = 8060,
    [Alias("Root")]
    [string]$ServeRoot = "",
    [switch]$NoBrowser,
    [string]$OwnershipFile = "",
    [string]$OwnershipNonce = "",
    [string]$ShutdownFile = ""
)

$ErrorActionPreference = "Stop"
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
            for ($index = 0; $index -lt (($backslashes * 2) + 1); $index += 1) { [void]$quoted.Append('\') }
            [void]$quoted.Append('"')
        }
        else {
            for ($index = 0; $index -lt $backslashes; $index += 1) { [void]$quoted.Append('\') }
            [void]$quoted.Append($character)
        }
        $backslashes = 0
    }
    for ($index = 0; $index -lt ($backslashes * 2); $index += 1) { [void]$quoted.Append('\') }
    [void]$quoted.Append('"')
    return $quoted.ToString()
}

$root = Split-Path -Parent $PSScriptRoot
$webDir = if ([string]::IsNullOrWhiteSpace($ServeRoot)) { Join-Path $root "builds/web" } else { [System.IO.Path]::GetFullPath($ServeRoot) }
$workspaceRoot = [System.IO.Path]::GetFullPath($root)
if (-not $webDir.StartsWith($workspaceRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to serve a directory outside the workspace: $webDir"
}

if (-not (Test-Path (Join-Path $webDir "index.html"))) {
    throw "No web build found at $webDir. Run .\tools\export_itch.ps1 first."
}
if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    throw "Python 3 was not found on PATH (needed for the local headers server)."
}

if (-not $NoBrowser) {
    Start-Process "http://127.0.0.1:$Port"
}

$python = (Get-Command python -ErrorAction Stop).Source
$serverScript = Join-Path $PSScriptRoot "serve_web_server.py"
$serverProcess = $null
try {
    $serverArguments = @($serverScript, "--port", [string]$Port, "--root", $webDir)
    $shutdownAckFile = ""
    if (-not [string]::IsNullOrWhiteSpace($OwnershipFile)) {
        $shutdownAckFile = "$ShutdownFile.ack"
        $serverArguments += @("--shutdown-file", $ShutdownFile, "--shutdown-ack-file", $shutdownAckFile, "--shutdown-nonce", $OwnershipNonce)
    }
    $quotedServerArguments = @($serverArguments | ForEach-Object { ConvertTo-WindowsProcessArgument -Argument ([string]$_) })
    $serverProcess = Start-Process -FilePath $python -ArgumentList $quotedServerArguments -PassThru -NoNewWindow
    if (-not [string]::IsNullOrWhiteSpace($OwnershipFile)) {
        if ([string]::IsNullOrWhiteSpace($OwnershipNonce) -or [string]::IsNullOrWhiteSpace($ShutdownFile)) {
            throw "An ownership file requires a nonempty ownership nonce and shutdown path."
        }
        $ownershipPath = [System.IO.Path]::GetFullPath($OwnershipFile)
        $ownership = [ordered]@{
            nonce = $OwnershipNonce
            wrapper_pid = $PID
            wrapper_start_utc_ticks = (Get-Process -Id $PID).StartTime.ToUniversalTime().Ticks
            server_pid = $serverProcess.Id
            server_start_utc_ticks = $serverProcess.StartTime.ToUniversalTime().Ticks
            port = $Port
            serve_root = $webDir
            server_script = $serverScript
            shutdown_file = [System.IO.Path]::GetFullPath($ShutdownFile)
            shutdown_ack_file = [System.IO.Path]::GetFullPath($shutdownAckFile)
        }
        $temporaryOwnershipPath = "$ownershipPath.$PID.tmp"
        $ownership | ConvertTo-Json | Set-Content -LiteralPath $temporaryOwnershipPath -Encoding utf8
        Move-Item -LiteralPath $temporaryOwnershipPath -Destination $ownershipPath
    }
    Wait-Process -Id $serverProcess.Id
    $serverProcess.Refresh()
    $expectedShutdown = $false
    if (-not [string]::IsNullOrWhiteSpace($OwnershipFile) -and (Test-Path -LiteralPath $ShutdownFile) -and (Test-Path -LiteralPath $shutdownAckFile)) {
        $expectedAcknowledgement = "{0}:{1}" -f $OwnershipNonce, $serverProcess.Id
        $expectedShutdown = (
            [string](Get-Content -LiteralPath $ShutdownFile -Raw) -eq $OwnershipNonce -and
            [string](Get-Content -LiteralPath $shutdownAckFile -Raw) -eq $expectedAcknowledgement
        )
    }
    if (-not $expectedShutdown) {
        $exitIdentity = "unknown"
        if ($serverProcess.HasExited) {
            try {
                if ($null -ne $serverProcess.ExitCode) { $exitIdentity = [string]$serverProcess.ExitCode }
            }
            catch { $exitIdentity = "unknown" }
        }
        throw "Local Web server exited unexpectedly with code $exitIdentity."
    }
}
finally {
    if ($null -ne $serverProcess -and -not $serverProcess.HasExited) {
        Stop-Process -Id $serverProcess.Id -Force -ErrorAction SilentlyContinue
    }
}
