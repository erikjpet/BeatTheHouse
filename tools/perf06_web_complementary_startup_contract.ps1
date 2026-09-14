$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$foundationSource = [System.IO.File]::ReadAllText((Join-Path $repoRoot "scripts/ui/foundation_main.gd"))
$generatorSource = [System.IO.File]::ReadAllText((Join-Path $repoRoot "scripts/core/run_generator.gd"))
$telemetrySource = [System.IO.File]::ReadAllText((Join-Path $repoRoot "scripts/ui/perf_telemetry_overlay.gd"))

function Get-FunctionBody([string]$Source, [string]$Name) {
    $match = [regex]::Match($Source, "(?ms)^func $([regex]::Escape($Name))\([^\r\n]*\).*?(?=^func |\z)")
    if (-not $match.Success) {
        throw "Missing function required by complementary startup contract: $Name"
    }
    return $match.Value
}

$generatorPreload = 'const CoinPusherGameScript := preload("res://scripts/games/coin_pusher.gd")'
if ($generatorSource.Contains($generatorPreload)) {
    throw "RunGenerator still eagerly parses the Coin Pusher module graph."
}
if (-not $generatorSource.Contains('var module_script: Script = load(module_path)')) {
    throw "RunGenerator no longer uses the ordinary dynamic module loader."
}

$foundationContracts = @(
    '"CoinPusherGameScript": "res://scripts/games/coin_pusher.gd"',
    '14: ["CoinPusherGameScript"]',
    'var CoinPusherGameScript: Script',
    "`t`t13:",
    "`t`t14:"
)
foreach ($contract in $foundationContracts) {
    if (-not $foundationSource.Contains($contract)) {
        throw "Missing retained post-READY Coin Pusher prewarm contract: $contract"
    }
}
if ($foundationSource.Contains('const CoinPusherGameScript := preload("res://scripts/games/coin_pusher.gd")')) {
    throw "Foundation's retained Coin Pusher resource is still an eager preload."
}

$planRoots = [ordered]@{
    SlotStateScript = "scripts/games/slots/slot_machine_state.gd"
    SlotPinballScript = "scripts/games/slots/slot_family_pinball.gd"
    PerformanceFixtureSetupScript = "scripts/ui/performance_fixture_setup.gd"
    CoinPusherSolverScript = "scripts/games/coin_pusher/coin_pusher_solver_api.gd"
    CoinPusherLiveSessionScript = "scripts/games/coin_pusher/coin_pusher_live_session.gd"
}
foreach ($entry in $planRoots.GetEnumerator()) {
    $resourcePath = "res://$($entry.Value)"
    if (-not $telemetrySource.Contains(('"{0}": "{1}"' -f $entry.Key, $resourcePath))) {
        throw "Missing lazy performance-plan mapping: $($entry.Key)"
    }
    if (-not $telemetrySource.Contains("var $($entry.Key): Script")) {
        throw "Performance-plan helper is not retained as a nullable Script: $($entry.Key)"
    }
    if ($telemetrySource.Contains("const $($entry.Key) := preload(`"$resourcePath`")")) {
        throw "Performance-plan helper remains in the eager READY closure: $($entry.Key)"
    }
}

$loaderBody = Get-FunctionBody $telemetrySource "_ensure_perf_plan_scripts"
if ($loaderBody.IndexOf('await get_tree().process_frame') -lt 0 -or
        $loaderBody.IndexOf('await get_tree().process_frame') -gt $loaderBody.IndexOf('ResourceLoader.load(script_path)')) {
    throw "Optional plan helpers are no longer staged on separate post-READY frames."
}
foreach ($contract in @('plan_script_failure_reason', 'perf_plan_script_load_failed', 'return false', 'set(field_name, loaded_script)')) {
    if (-not $loaderBody.Contains($contract)) {
        throw "Plan helper loader lost deterministic failure/retention behavior: $contract"
    }
}

$configureBody = Get-FunctionBody $telemetrySource "configure"
if ($configureBody.IndexOf('_emit_console(READY_PREFIX') -lt 0 -or
        $configureBody.IndexOf('_emit_console(READY_PREFIX') -gt $configureBody.IndexOf('call_deferred("_run_l02_plan")')) {
    throw "BTH_PERF_READY no longer precedes all optional plan loading."
}

$selectedPlans = [ordered]@{
    _run_l02_plan = 'L02_PLAN_SCRIPT_FIELDS'
    _run_coin_pusher_plan = 'COIN_PUSHER_PLAN_SCRIPT_FIELDS'
}
foreach ($entry in $selectedPlans.GetEnumerator()) {
    $body = Get-FunctionBody $telemetrySource $entry.Key
    $guard = "if not await _ensure_perf_plan_scripts($($entry.Value)):"
    if (-not $body.Contains($guard) -or -not $body.Contains('await _abort_perf_plan_setup()')) {
        throw "Selected plan lacks explicit optional-helper failure handling: $($entry.Key)"
    }
    if ($body.IndexOf($guard) -gt $body.IndexOf('await _wait_frames(8)')) {
        throw "Selected plan mutates/waits before its required helper set is available: $($entry.Key)"
    }
}
$abortBody = Get-FunctionBody $telemetrySource "_abort_perf_plan_setup"
foreach ($contract in @('_end_scenario()', 'l02_driver_complete = true', 'dump_report()', 'await _quit_after_report_flush()')) {
    if (-not $abortBody.Contains($contract)) {
        throw "Plan setup failure no longer produces a complete diagnostic report: $contract"
    }
}

# These are the exact Git-blob byte counts from the measured eager dependency
# graph. Keeping the manifest explicit makes any future closure growth a reviewed
# startup-budget decision instead of a silent regression.
$expectedClosureBytes = [ordered]@{
    "scripts/games/coin_pusher.gd" = 165047
    "scripts/games/coin_pusher/coin_pusher_solver.gd" = 105683
    "scripts/games/slots/pinball/pinball_feature.gd" = 52285
    "scripts/games/coin_pusher/coin_pusher_live_session.gd" = 44828
    "scripts/games/slots/pinball/pinball_sim.gd" = 33907
    "scripts/games/slots/slot_machine_state.gd" = 26104
    "scripts/games/slots/slot_family_pinball.gd" = 25827
    "scripts/games/coin_pusher/jackpot_ridge.gd" = 13641
    "scripts/games/slots/pinball/pinball_boards.gd" = 12155
    "scripts/games/coin_pusher/vault_drop.gd" = 11486
    "scripts/games/slots/pinball/pinball_board.gd" = 10432
    "scripts/games/slots/pinball/pinball_sequencer.gd" = 9227
    "scripts/games/slots/slot_rng_math.gd" = 8093
    "scripts/games/slots/pinball/pinball_items.gd" = 7271
    "scripts/games/coin_pusher/coin_pusher_solver_api.gd" = 6500
    "scripts/ui/performance_fixture_setup.gd" = 3087
}
if (($expectedClosureBytes.Values | Measure-Object -Sum).Sum -ne 535573) {
    throw "Complementary startup closure manifest no longer totals 535,573 bytes."
}

$closureRoots = @("scripts/games/coin_pusher.gd") + @($planRoots.Values)
$pending = [System.Collections.Generic.Queue[string]]::new()
foreach ($path in $closureRoots) { $pending.Enqueue($path) }
$actualClosure = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
while ($pending.Count -gt 0) {
    $path = $pending.Dequeue()
    if (-not $actualClosure.Add($path)) { continue }
    $fullPath = Join-Path $repoRoot $path
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        throw "Complementary startup closure path is missing: $path"
    }
    $source = [System.IO.File]::ReadAllText($fullPath)
    foreach ($match in [regex]::Matches($source, 'preload\("res://([^"\r\n]+\.gd)"\)')) {
        $pending.Enqueue($match.Groups[1].Value)
    }
}
# Remove anything still reachable through the generator/telemetry preloads that
# remain intentionally eager for menu operation and the READY signal.
$retainedPending = [System.Collections.Generic.Queue[string]]::new()
foreach ($match in [regex]::Matches(($generatorSource + "`n" + $telemetrySource), 'preload\("res://([^"\r\n]+\.gd)"\)')) {
    $retainedPending.Enqueue($match.Groups[1].Value)
}
$retainedClosure = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
while ($retainedPending.Count -gt 0) {
    $path = $retainedPending.Dequeue()
    if (-not $retainedClosure.Add($path)) { continue }
    $fullPath = Join-Path $repoRoot $path
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) { continue }
    $source = [System.IO.File]::ReadAllText($fullPath)
    foreach ($match in [regex]::Matches($source, 'preload\("res://([^"\r\n]+\.gd)"\)')) {
        $retainedPending.Enqueue($match.Groups[1].Value)
    }
}
$actualClosure.ExceptWith($retainedClosure)
$expectedPaths = @($expectedClosureBytes.Keys | Sort-Object)
$actualPaths = @($actualClosure | Sort-Object)
$difference = @(Compare-Object -ReferenceObject $expectedPaths -DifferenceObject $actualPaths)
if ($difference.Count -gt 0) {
    throw "Complementary startup closure changed: $($difference | Out-String)"
}

Write-Output "PASS: 535,573-byte Coin Pusher and plan-only helper closure is post-READY, retained, separately staged, and fail-closed."
