$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$renderer = Get-Content -LiteralPath (Join-Path $root "scripts/games/coin_pusher/coin_pusher_renderer.gd") -Raw
$surface = Get-Content -LiteralPath (Join-Path $root "scripts/ui/game_surface_canvas.gd") -Raw
$cacheCanvas = Get-Content -LiteralPath (Join-Path $root "scripts/games/coin_pusher/coin_pusher_static_cache_canvas.gd") -Raw
$runtimeContract = Get-Content -LiteralPath (Join-Path $root "tools/coin_pusher_static_cache_contract.gd") -Raw
$failures = [System.Collections.Generic.List[string]]::new()

function Require-Text([string]$source, [string]$needle, [string]$message) {
    if (-not $source.Contains($needle)) {
        $failures.Add($message)
    }
}

Require-Text $renderer '_register_static_cache_text_rects(surface, layer_index)' "Cached layer pixels are not paired with live readability registration."
Require-Text $renderer 'surface.surface_register_text_protected_rect(rect_value)' "Cached backglass readability is not registered on the production surface."
Require-Text $renderer 'func debug_static_cache_text_protected_rects_for_test(layer_index: int) -> Array:' "The retained readability metadata is not observable to its production contract."
Require-Text $surface 'func surface_register_text_protected_rect(rect: Rect2) -> void:' "GameSurfaceCanvas does not expose retained-layer readability registration."
Require-Text $surface '_register_surface_text_panel_rect(rect)' "Retained-layer readability bypasses the normal validation and cap."
Require-Text $cacheCanvas 'surface_text_protected_rects.clear()' "Static cache redraws can accumulate stale readability rectangles."
Require-Text $runtimeContract 'cached_backglass_registers_live_readability_rect_' "The production static-cache contract does not verify exact live backglass rectangles."
Require-Text $runtimeContract 'backglass_live_offset := mini(expected_shell_protected_rects.size(), protected_rect_cap)' "The production contract does not account for preceding cached shell text."
Require-Text $runtimeContract 'cached_surface_text_protection_respects_cap' "The production contract does not verify the shared text-protection cap."

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output "Coin Pusher cached backglass readability contract PASS: retained pixels replay exact text protection metadata on the live surface."
