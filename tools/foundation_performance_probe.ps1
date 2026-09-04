param(
    [int]$RunCount = 8,
    [int]$FramesPerSurface = 120,
    [int]$ResolveSampleCount = 48,
    [string]$SeedPrefix = "FOUNDATION-PERF",
    [string]$Out = "",
    [string]$CandidateCommit = "",
    [string]$ProfileManifestSha256 = "",
    [string]$EvidenceProfile = "",
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
    $godot = $env:GODOT_BIN
}
else {
    $localGodot = Get-ChildItem -LiteralPath (Join-Path $root ".tools") -Filter "Godot*_console.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $localGodot) {
        $localGodot = Get-ChildItem -LiteralPath (Join-Path $root ".tools") -Filter "Godot*.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    }
    if ($localGodot) {
        $godot = $localGodot.FullName
    }
    else {
        $command = Get-Command godot -ErrorAction SilentlyContinue
        if ($command) {
            $godot = $command.Source
        }
    }
}

if (-not $godot) {
    if ($RequireGodot) {
        throw "Godot was not found. Run tools/install_godot.ps1 or set GODOT_BIN."
    }
    Write-Warning "Godot was not found, so foundation performance probe could not run."
    exit 0
}

$oldRuns = $env:BTH_PERF_RUNS
$oldFrames = $env:BTH_PERF_FRAMES
$oldResolveSamples = $env:BTH_PERF_RESOLVE_SAMPLES
$oldSeedPrefix = $env:BTH_PERF_SEED_PREFIX
$oldReportPath = $env:BTH_PERF_REPORT_PATH
$oldCandidateCommit = $env:BTH_PERF_CANDIDATE_COMMIT
$oldProfileManifestSha256 = $env:BTH_PERF_PROFILE_MANIFEST_SHA256
$oldEvidenceProfile = $env:BTH_PERF_EVIDENCE_PROFILE
try {
    $env:BTH_PERF_RUNS = [string]$RunCount
    $env:BTH_PERF_FRAMES = [string]$FramesPerSurface
    $env:BTH_PERF_RESOLVE_SAMPLES = [string]$ResolveSampleCount
    $env:BTH_PERF_SEED_PREFIX = $SeedPrefix
    if ($Out) {
        $reportPath = if ([IO.Path]::IsPathRooted($Out)) { [IO.Path]::GetFullPath($Out) } else { [IO.Path]::GetFullPath((Join-Path $root $Out)) }
        $reportDirectory = Split-Path -Parent $reportPath
        if (-not (Test-Path -LiteralPath $reportDirectory -PathType Container)) { New-Item -ItemType Directory -Force -Path $reportDirectory | Out-Null }
        $env:BTH_PERF_REPORT_PATH = $reportPath
    }
    $env:BTH_PERF_CANDIDATE_COMMIT = $CandidateCommit
    $env:BTH_PERF_PROFILE_MANIFEST_SHA256 = $ProfileManifestSha256
    if ($EvidenceProfile) { $env:BTH_PERF_EVIDENCE_PROFILE = $EvidenceProfile }
    $consoleGodot = Use-ConsoleGodot $godot
    & $consoleGodot --headless --path $root --script "res://tools/foundation_performance_probe.gd"
    exit $LASTEXITCODE
}
finally {
    $env:BTH_PERF_RUNS = $oldRuns
    $env:BTH_PERF_FRAMES = $oldFrames
    $env:BTH_PERF_RESOLVE_SAMPLES = $oldResolveSamples
    $env:BTH_PERF_SEED_PREFIX = $oldSeedPrefix
    $env:BTH_PERF_REPORT_PATH = $oldReportPath
    $env:BTH_PERF_CANDIDATE_COMMIT = $oldCandidateCommit
    $env:BTH_PERF_PROFILE_MANIFEST_SHA256 = $oldProfileManifestSha256
    $env:BTH_PERF_EVIDENCE_PROFILE = $oldEvidenceProfile
}
