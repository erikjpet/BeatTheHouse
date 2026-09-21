param(
    [string]$Root = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = Split-Path -Parent $PSScriptRoot
}
$Root = [System.IO.Path]::GetFullPath($Root)
$uiRoot = Join-Path $Root "scripts\ui"

if (-not (Test-Path -LiteralPath $uiRoot -PathType Container)) {
    Write-Error "scripts/ui directory was not found under $Root"
    exit 1
}

$exemptions = [ordered]@{
    "scripts/ui/visual_style.gd" = "Token source of truth; palette and size tokens are deliberately declared here."
    "scripts/ui/pixel_scene_canvas.gd" = "Art canvas; raw colors are authored pixel/environment artwork, not reusable UI chrome."
    "scripts/ui/world_map_canvas.gd" = "Art canvas; raw colors and coordinates are the map painting layer."
    "scripts/ui/run_report_timeline_canvas.gd" = "Art canvas; raw colors are timeline illustration tones."
    "scripts/ui/game_surface_canvas.gd" = "Game-surface bridge; raw colors/sizes are passed through from game artwork contracts."
    "scripts/ui/attribute_badge_row.gd" = "Glyph micro-canvas; raw geometry is icon painting and badge hit-area math."
    "scripts/ui/environment_interaction_view_model.gd" = "View-model placement geometry; normalized object coordinates are content layout data."
    "scripts/ui/meta_session_controller.gd" = "Meta-map placement geometry; normalized object coordinates are content layout data."
    "scripts/ui/coach_view_model.gd" = "Viewport fallback data; numeric Rect2/Vector2 defaults are measurement inputs, not chrome."
    "scripts/ui/perf_telemetry_overlay.gd" = "Diagnostic-only overlay; colors/sizes are dev instrumentation."
    "scripts/ui/foundation_main.gd" = "Legacy host monolith; visible start/run chrome now lives in tokenized components, while remaining host literals are tracked for decomposition."
    "scripts/ui/bag_open_reel.gd" = "Animated reveal canvas; panel constants and rarity card painting are art-directed reel geometry."
    "scripts/ui/inventory_container_surface.gd" = "Inventory icon canvas; remaining raw sizes are item-grid and marker geometry."
    "scripts/ui/item_found_popup.gd" = "Modal overlay kept visually frozen for 0.5; follow-up should migrate exact popup geometry to shared tokens."
    "scripts/ui/meta_item_interaction_screen.gd" = "Meta item modal kept visually frozen for 0.5; follow-up should migrate exact popup geometry to shared tokens."
    "scripts/ui/run_inventory_screen.gd" = "Run inventory modal kept visually frozen for 0.5; follow-up should migrate exact popup geometry to shared tokens."
    "scripts/ui/run_report_screen.gd" = "Run report composition kept visually frozen for 0.5; timeline/results constants need a dedicated follow-up."
    "scripts/ui/settings_menu.gd" = "Settings control geometry predates widened gate; token migration is isolated as follow-up to avoid behavior drift."
    "scripts/ui/world_map_overlay_controller.gd" = "World-map popup grid geometry; raw sizes mirror map badge/icon measurements."
}

$patterns = @(
    @{ Name = "raw hex color"; Regex = 'Color\(\s*["'']#' },
    @{ Name = "raw theme spacing"; Regex = 'add_theme_constant_override\([^,]+,\s*[0-9]+' },
    @{ Name = "raw font size"; Regex = '(set_control_font_size|FoundationWidgets\.(label|muted_label)|_label)\([^`r`n,]+,\s*[0-9]+' },
    @{ Name = "raw control size"; Regex = '(custom_minimum_size|size)\s*=\s*Vector2\(\s*[0-9]+' }
)

$violations = [System.Collections.Generic.List[string]]::new()
$coveredCount = 0
$exemptCount = 0
$seen = [System.Collections.Generic.HashSet[string]]::new()
$files = Get-ChildItem -LiteralPath $uiRoot -Filter "*.gd" -File | Sort-Object FullName

foreach ($file in $files) {
    $relativePath = $file.FullName.Substring($Root.Length).TrimStart("\", "/").Replace("\", "/")
    [void]$seen.Add($relativePath)
    if ($exemptions.Contains($relativePath)) {
        $exemptCount += 1
        if ([string]::IsNullOrWhiteSpace([string]$exemptions[$relativePath])) {
            $violations.Add("${relativePath}: exemption is missing its one-line justification")
        }
        continue
    }
    $coveredCount += 1
    $lineNumber = 0
    foreach ($line in Get-Content -LiteralPath $file.FullName) {
        $lineNumber += 1
        foreach ($pattern in $patterns) {
            if ($line -match $pattern.Regex) {
                $violations.Add(("{0}:{1}: {2}: {3}" -f $relativePath, $lineNumber, $pattern.Name, $line.Trim()))
            }
        }
    }
}

foreach ($relativePath in $exemptions.Keys) {
    if (-not $seen.Contains($relativePath)) {
        $violations.Add("${relativePath}: exemption references a missing scripts/ui file")
    }
}

if ($coveredCount -le 0) {
    $violations.Add("No scripts/ui files were covered by token adoption check")
}

if ($violations.Count -gt 0) {
    $violations | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Host ("UI05_TOKEN_ADOPTION_CHECK PASS ({0} scripts/ui files covered, {1} deliberate exemptions)" -f $coveredCount, $exemptCount)
