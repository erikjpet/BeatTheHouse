param(
    [int]$Runs = 100,
    [int]$Visits = 6,
    [string]$Output = "res://.tmp/environment_generation_audit/report.json",
    [string]$Report = "res://.tmp/environment_generation_audit/report.md",
    [string]$SeedPrefix = "",
    [switch]$RequireGodot
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

function Use-ConsoleGodot {
    param([string]$Path)
    if (-not $Path) {
        return $null
    }
    if ($Path.EndsWith("_console.exe")) {
        return $Path
    }
    $candidate = $Path -replace "\.exe$", "_console.exe"
    if (Test-Path -LiteralPath $candidate) {
        return $candidate
    }
    return $Path
}

if ($env:GODOT_BIN) {
    $godot = Use-ConsoleGodot $env:GODOT_BIN
}
else {
    $localGodot = Get-ChildItem -LiteralPath (Join-Path $root ".tools") -Filter "Godot*_console.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $localGodot) {
        $localGodot = Get-ChildItem -LiteralPath (Join-Path $root ".tools") -Filter "Godot*.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    }
    if ($localGodot) {
        $godot = Use-ConsoleGodot $localGodot.FullName
    }
    else {
        $command = Get-Command godot -ErrorAction SilentlyContinue
        if ($command) {
            $godot = Use-ConsoleGodot $command.Source
        }
    }
}

if (-not $godot) {
    if ($RequireGodot) {
        throw "Godot was not found. Run tools/install_godot.ps1 or set GODOT_BIN."
    }
    Write-Warning "Godot was not found, so environment generation audit was skipped."
    exit 0
}

$argsList = @(
    "--runs=$Runs",
    "--visits=$Visits",
    "--output=$Output",
    "--report=$Report"
)
if ($SeedPrefix.Trim().Length -gt 0) {
    $argsList += "--seed-prefix=$SeedPrefix"
}

& $godot --headless --path $root --script "res://tools/environment_generation_audit.gd" -- $argsList
exit $LASTEXITCODE
