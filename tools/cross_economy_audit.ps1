param(
    [ValidateRange(1, 512)]
    [int]$SeedsPerPlaystyle = 64,
    [ValidateRange(8, 512)]
    [int]$MaxActions = 208,
    [string]$SeedPrefix = "BALANCE06-1",
    [ValidateSet("", "control_crew_ignoring", "pure_gambler", "crew_maximizer", "numbers_specialist", "coin_pusher_grinder", "cheater", "heist_rusher", "mixed_opportunist")]
    [string]$Playstyle = "",
    [string]$BuildRef = "",
    [string]$Output = "res://.tmp/balance06_1/cross_economy_audit.json",
    [switch]$VerifyDeterminism
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot

function Find-ConsoleGodot {
    if ($env:GODOT_BIN -and (Test-Path -LiteralPath $env:GODOT_BIN)) {
        return $env:GODOT_BIN
    }
    $canonical = "D:\Projects\Beat-The-House\.tools\godot-4.6-stable\Godot_v4.6-stable_win64_console.exe"
    if (Test-Path -LiteralPath $canonical) {
        return $canonical
    }
    $command = Get-Command godot -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }
    throw "Godot was not found. Set GODOT_BIN to the canonical console executable."
}

function Invoke-Audit([string]$TargetOutput) {
    $godot = Find-ConsoleGodot
    $args = @(
        "--headless", "--path", $projectRoot,
        "--script", "res://tools/cross_economy_audit.gd", "--",
        "--seeds-per-style=$SeedsPerPlaystyle",
        "--max-actions=$MaxActions",
        "--seed-prefix=$SeedPrefix",
        "--build-ref=$BuildRef",
        "--output=$TargetOutput"
    )
    if (-not [string]::IsNullOrWhiteSpace($Playstyle)) {
        $args += "--playstyle=$Playstyle"
    }
    & $godot @args
    if ($LASTEXITCODE -ne 0) {
        throw "Cross-system economy audit failed with exit code $LASTEXITCODE."
    }
}

if ([string]::IsNullOrWhiteSpace($BuildRef)) {
    $BuildRef = (git -C $projectRoot rev-parse HEAD).Trim()
}

Invoke-Audit $Output

if ($VerifyDeterminism) {
    $firstAbsolute = if ($Output.StartsWith("res://")) { Join-Path $projectRoot $Output.Substring(6).Replace("/", "\") } else { $Output }
    $repeatOutput = "res://.tmp/balance06_1/cross_economy_audit_repeat.json"
    Invoke-Audit $repeatOutput
    $repeatAbsolute = Join-Path $projectRoot ".tmp\balance06_1\cross_economy_audit_repeat.json"
    $first = Get-Content -LiteralPath $firstAbsolute -Raw | ConvertFrom-Json
    $repeat = Get-Content -LiteralPath $repeatAbsolute -Raw | ConvertFrom-Json
    $firstComparable = [ordered]@{ aggregate = $first.aggregate; runs = $first.runs; failures = $first.failures; warnings = $first.warnings }
    $repeatComparable = [ordered]@{ aggregate = $repeat.aggregate; runs = $repeat.runs; failures = $repeat.failures; warnings = $repeat.warnings }
    $firstJson = $firstComparable | ConvertTo-Json -Depth 30 -Compress
    $repeatJson = $repeatComparable | ConvertTo-Json -Depth 30 -Compress
    if ($firstJson -cne $repeatJson) {
        throw "Determinism verification failed: aggregate/run payloads differ."
    }
    Write-Host "CROSS_ECONOMY_AUDIT_DETERMINISM_PASS"
}
