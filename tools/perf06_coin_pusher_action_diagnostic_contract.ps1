$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$gamePath = Join-Path $root "scripts/games/coin_pusher.gd"
$overlayPath = Join-Path $root "scripts/ui/perf_telemetry_overlay.gd"
$game = Get-Content -LiteralPath $gamePath -Raw
$overlay = Get-Content -LiteralPath $overlayPath -Raw
$failures = [System.Collections.Generic.List[string]]::new()

function Require-Text([string]$source, [string]$needle, [string]$message) {
    if (-not $source.Contains($needle)) {
        $failures.Add($message)
    }
}

Require-Text $game 'bool(_ui_state.get("coin_pusher_debug_profile_stages", false))' "Coin Pusher action timing is not gated by the explicit stage diagnostic flag."
Require-Text $game 'func action_timing_snapshot() -> Dictionary:' "Coin Pusher does not expose a read-only action timing snapshot to the harness."
foreach ($stage in @(
    'command_ensure_machine',
    'command_reconcile_tolerance',
    'resolve_enqueue_drops',
    'resolve_write_durable',
    'resolve_build_result',
    'collect_snapshot_tray',
    'collect_solver',
    'collect_apply_result',
    'collect_write_durable',
    'collect_build_patch',
    'command_total'
)) {
    Require-Text $game ('_last_action_timing_usec["' + $stage + '"]') ("Missing Coin Pusher diagnostic substage: {0}." -f $stage)
}

Require-Text $overlay 'current_tags["action_timing_usec"] = action_timing.duplicate(true)' "Web evidence does not retain the production action substage snapshot."
Require-Text $overlay 'if surface_action != "coin_pusher_drop" or str(accepted_result.get("action_id", "")) != "drop_quarter":' "Immediate controls can inherit stale host-resolve timing."

$collectRefresh = [regex]::Escape('app.call("_refresh")') + '\r?\n\t' + [regex]::Escape('_enable_coin_pusher_stage_diagnostic()') + '\r?\n\t' + [regex]::Escape('mark_event("coin_pusher_collect_seed"')
if (-not [regex]::IsMatch($overlay, $collectRefresh)) {
    $failures.Add("Collect fixture refresh does not restore the stage diagnostic flag before measurement.")
}
$reduceRefresh = [regex]::Escape('app.call("_refresh")') + '\r?\n\t' + [regex]::Escape('_enable_coin_pusher_stage_diagnostic()') + '\r?\n\t' + [regex]::Escape('await _wait_frames(4)') + '\r?\n\t' + [regex]::Escape('_enable_coin_pusher_stage_diagnostic()')
if (-not [regex]::IsMatch($overlay, $reduceRefresh)) {
    $failures.Add("Reduced-motion refresh does not restore the stage diagnostic flag across its settle window.")
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output "Coin Pusher action diagnostic contract PASS: fixture reinstalls retain stage capture and DROP/COLLECT expose scoped production-boundary substages."
