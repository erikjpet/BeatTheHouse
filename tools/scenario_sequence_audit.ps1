param(
    [ValidateRange(1, 1000)]
    [int]$ExpectedCount = 1,
    [ValidateRange(0.0, 1.0)]
    [double]$SimilarityFailThreshold = 0.820,
    [string]$Output = "res://.tmp/env06_6/scenario_sequence_audit.json",
    [string]$Report = "res://.tmp/env06_6/scenario_sequence_audit.md",
    [switch]$RequireGodot
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$authoritativeThreshold = 0.820

if ([Math]::Abs($SimilarityFailThreshold - $authoritativeThreshold) -gt 0.000001) {
    throw "SimilarityFailThreshold must equal the ScenarioSequenceSchema authority threshold 0.820."
}
if ([string]::IsNullOrWhiteSpace($Output) -or [string]::IsNullOrWhiteSpace($Report) -or $Output -eq $Report) {
    throw "Output and Report must be distinct non-empty paths."
}

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
    Write-Warning "Godot was not found, so the scenario-sequence audit was skipped."
    exit 0
}

$arguments = @(
    "--expected-count=$ExpectedCount",
    "--similarity-fail-threshold=$($SimilarityFailThreshold.ToString('0.000', [System.Globalization.CultureInfo]::InvariantCulture))",
    "--out=$Output",
    "--report=$Report"
)

& $godot --headless --path $root --script "res://tools/scenario_sequence_audit.gd" -- $arguments
exit $LASTEXITCODE
