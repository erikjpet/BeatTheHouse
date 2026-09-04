$ErrorActionPreference = "Stop"
$root = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$tablePath = Join-Path $PSScriptRoot "perf06_budget_table.json"
$table = Get-Content -LiteralPath $tablePath -Raw | ConvertFrom-Json
$webText = Get-Content -LiteralPath (Join-Path $PSScriptRoot "web_perf_smoke.ps1") -Raw
$nativeText = Get-Content -LiteralPath (Join-Path $PSScriptRoot "foundation_performance_probe.gd") -Raw

if ([string]$table.schema -cne "beat_the_house.perf06_budget_table/v1" -or [int]$table.version -ne 1) {
    throw "Published performance budget table schema/version changed without a contract update."
}
if (-not [bool]$table.policy.idle_timing_requires_liveness -or [int]$table.policy.steady_state_deep_copies_max -ne 0) {
    throw "Published budget policy must pair idle timing with liveness and reject steady-state deep copies."
}
$protectedWeb = @{
    "l02.pull_tabs_idle" = 20.0
    "l02.slot_active" = 110.0
    "l02.roulette_active" = 160.0
    "l02.scripted_play_memory_10m" = 45.0
    "coin_pusher.coin_pusher_idle" = 16.0
    "coin_pusher.coin_pusher_active_drop" = 22.0
    "grand_casino.grand_casino_late_idle" = 50.0
}
foreach ($entry in $protectedWeb.GetEnumerator()) {
    $parts = $entry.Key.Split(".", 2)
    $actual = [double]$table.web_frame_p95_ms.PSObject.Properties[$parts[0]].Value.PSObject.Properties[$parts[1]].Value
    if ($actual -ne [double]$entry.Value) { throw "Protected Web budget '$($entry.Key)' changed from $($entry.Value) to $actual." }
}
$nativeTokens = @(
    'const MAX_SURFACE_DRAW_P95_MS := 5.0',
    'const MAX_IDLE_SURFACE_DRAW_P95_MS := 1.5',
    'const COIN_PUSHER_SOLVER_TICK_P95_BUDGET_MS := 12.0',
    'const COIN_PUSHER_ACTIVE_ACTION_BUDGET_MS := 16.0',
    'const COIN_PUSHER_ACTIVE_FRAME_P95_BUDGET_MS := 22.0',
    'const COIN_PUSHER_ACTIVE_DRAW_P95_BUDGET_MS := 7.0'
)
foreach ($token in $nativeTokens) {
    if (-not $nativeText.Contains($token)) { throw "Native maintained budget contract lost '$token'." }
}
foreach ($token in @("perf06_budget_table.json", "web_perf_idle_liveness_contract.ps1", "scenario_frame_p95_budgets_ms", "budget_table_sha256")) {
    if (-not $webText.Contains($token)) { throw "Web budget enforcement lost '$token'." }
}
foreach ($token in @("distribution_fresh_start", "distribution_fresh_start_contract", "fresh Web export", "cold browser profile")) {
    if (-not $webText.Contains($token)) { throw "Exported Web fresh-start contract lost '$token'." }
}
if ($webText -notmatch 'solver_backend -ceq "native_v3"') {
    throw "Exported Web performance gate no longer requires the locked native_v3 Coin Pusher solver."
}
foreach ($token in @("-Target template_debug", "BTH_PERF_NATIVE_PLUGIN_SHA256", "nativePluginHash")) {
    $probeWrapper = Get-Content -LiteralPath (Join-Path $PSScriptRoot "foundation_performance_probe.ps1") -Raw
    if (-not $probeWrapper.Contains($token)) { throw "Native source-run probe lost '$token'." }
}
if (-not $nativeText.Contains('str(stats.get("solver_backend", "")) == "native_v3"')) {
    throw "Native performance gate no longer requires the locked native_v3 solver."
}
Write-Host "PERF06 BUDGET CONTRACT PASS version=$($table.version) protected_web=$($protectedWeb.Count)"
