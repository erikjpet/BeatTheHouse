param(
    [string]$GodotPath = "",
    [string]$OutDir = ".tmp\env06_6\visual_capture",
    [int]$TimeoutSec = 600,
    [switch]$RequireGodot
)

$ErrorActionPreference = "Stop"
$root = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
if (-not $GodotPath) { $GodotPath = $env:GODOT_BIN }
if (-not $GodotPath) {
    $common = (& git -C $root rev-parse --path-format=absolute --git-common-dir).Trim()
    $candidate = Join-Path (Split-Path -Parent $common) ".tools\godot-4.6-stable\Godot_v4.6-stable_win64_console.exe"
    if (Test-Path -LiteralPath $candidate -PathType Leaf) { $GodotPath = $candidate }
}
if (-not $GodotPath -or -not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    if ($RequireGodot) { throw "Godot console was not found; pass -GodotPath or set GODOT_BIN." }
    Write-Host "SCENARIO_SEQUENCE_VISUAL_CAPTURE NOT RUN (Godot unavailable)."
    exit 0
}
if ($TimeoutSec -lt 1) { throw "TimeoutSec must be positive." }

$out = [IO.Path]::GetFullPath((Join-Path $root $OutDir))
$allowedRoot = [IO.Path]::GetFullPath((Join-Path $root ".tmp"))
if (-not $out.StartsWith($allowedRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw "OutDir must resolve below the repository .tmp directory: $out"
}
if (Test-Path -LiteralPath $out) { Remove-Item -LiteralPath $out -Recurse -Force }
New-Item -ItemType Directory -Force -Path $out | Out-Null
$relativeOut = [IO.Path]::GetRelativePath($root, $out).Replace('\', '/')
$resourceOut = "res://$relativeOut"
$stdout = Join-Path $out "capture.stdout.txt"
$stderr = Join-Path $out "capture.stderr.txt"
$dataRoot = Join-Path $out "process_data"
New-Item -ItemType Directory -Force -Path $dataRoot | Out-Null
$arguments = @(
    "--path", $root,
    "--rendering-method", "gl_compatibility",
    "--resolution", "1280x720",
    "res://tools/scenario_sequence_probe_main.tscn",
    "--",
    "--mode=visual",
    "--out=$resourceOut"
)
$environmentNames = @("BTH_DISTRIBUTION_BUILD", "BTH_DISTRIBUTION_DATA_ROOT", "BTH_USER_SETTINGS_PATH")
$previousEnvironment = @{}
foreach ($name in $environmentNames) { $previousEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, "Process") }
try {
    $env:BTH_DISTRIBUTION_BUILD = "1"
    $env:BTH_DISTRIBUTION_DATA_ROOT = $dataRoot
    $env:BTH_USER_SETTINGS_PATH = Join-Path $dataRoot "settings.json"
    $process = Start-Process -FilePath $GodotPath -ArgumentList $arguments -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru -WindowStyle Hidden
    if (-not $process.WaitForExit($TimeoutSec * 1000)) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        throw "Scenario sequence visual capture timed out after $TimeoutSec seconds; see $stdout and $stderr."
    }
    if ($process.ExitCode -ne 0) {
        throw "Scenario sequence visual capture failed with exit $($process.ExitCode); see $stdout and $stderr."
    }
}
finally {
    foreach ($name in $environmentNames) { [Environment]::SetEnvironmentVariable($name, $previousEnvironment[$name], "Process") }
}
$manifestPath = Join-Path $out "manifest.json"
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw "Visual capture emitted no manifest: $manifestPath" }
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$expectedIds = @(
    "arrival_delivery_blocked", "sorting_aisle_rerouted", "verification_station_ready", "awaiting_stock_choice",
    "resolution_repaired", "resolution_broken", "resolution_refused", "resolution_interrupted",
    "partial_revisit_awaiting_stock", "terminal_revisit_repaired", "terminal_revisit_broken",
    "terminal_revisit_refused", "terminal_revisit_interrupted", "expired_revisit_night_end",
    "reduced_motion_arrival", "small_screen_104x76", "obstruction_overlay_zero_overlap",
    "hit_target_overlay_44_minimum", "base_event_pre_request_gated", "base_event_request_delivered",
    "base_event_terminal_gated"
)
$actualIds = @($manifest.capture_ids)
if (-not $manifest.passed -or @($manifest.failures).Count -ne 0) { throw "Visual capture manifest did not pass." }
if ($actualIds.Count -ne $expectedIds.Count -or (Compare-Object -ReferenceObject $expectedIds -DifferenceObject $actualIds -SyncWindow 0)) {
    throw "Visual capture manifest does not preserve the exact ordered 21-id contract."
}
if (@($manifest.captures).Count -ne 21) { throw "Visual capture manifest does not contain exactly 21 capture rows." }
$seen = @{}
$byId = @{}
foreach ($capture in @($manifest.captures)) {
    $id = [string]$capture.capture_id
    if (-not $seen.ContainsKey($id)) { $seen[$id] = 0 }
    $seen[$id]++
    $byId[$id] = $capture
    $png = Join-Path $out ([string]$capture.file)
    if (-not (Test-Path -LiteralPath $png -PathType Leaf)) { throw "Capture PNG is missing: $png" }
    $hash = (Get-FileHash -LiteralPath $png -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($hash -cne ([string]$capture.png_sha256).ToLowerInvariant()) { throw "Capture PNG hash mismatch: $id" }
    if (-not $capture.live_assertions_passed) { throw "Capture live assertions failed: $id" }
    if ([int]$capture.width -lt 1280 -or [int]$capture.height -lt 720 -or [string]$capture.image_format -cne "png") {
        throw "Capture does not prove a full 1280x720-or-larger PNG: $id"
    }
    if ([string]::IsNullOrWhiteSpace([string]$capture.status) -or ([string]$capture.visual_state_sha256).Length -ne 64) {
        throw "Capture does not include status and visual-state authority: $id"
    }
}
foreach ($id in $expectedIds) {
    if (-not $seen.ContainsKey($id) -or $seen[$id] -ne 1) { throw "Capture id was not produced exactly once: $id" }
}
$materialOutcomes = [ordered]@{
    resolution_repaired = "repaired"
    resolution_broken = "broken"
    resolution_refused = "refused"
    resolution_interrupted = "interrupted"
}
$materialPngHashes = @()
$materialStateHashes = @()
foreach ($entry in $materialOutcomes.GetEnumerator()) {
    $capture = $byId[$entry.Key]
    if (@($capture.outcomes).Count -ne 1 -or [string]$capture.outcomes[0] -cne [string]$entry.Value) {
        throw "Capture does not prove its exact material outcome: $($entry.Key)"
    }
    $materialPngHashes += [string]$capture.png_sha256
    $materialStateHashes += [string]$capture.visual_state_sha256
}
if (@($materialPngHashes | Sort-Object -Unique).Count -ne 4 -or @($materialStateHashes | Sort-Object -Unique).Count -ne 4) {
    throw "The four material outcomes are not visually and authoritatively distinct."
}
Write-Host "SCENARIO_SEQUENCE_VISUAL_CAPTURE PASS manifest=$manifestPath captures=21 renderer=$($manifest.renderer)"
