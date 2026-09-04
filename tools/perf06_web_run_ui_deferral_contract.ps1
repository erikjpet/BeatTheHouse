$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$hostPath = Join-Path $repoRoot "scripts/ui/foundation_main.gd"
$source = [System.IO.File]::ReadAllText($hostPath)

$roots = [ordered]@{
    GameSurfaceCanvasScript = "res://scripts/ui/game_surface_canvas.gd"
    SfxPlayerScript = "res://scripts/ui/sfx_player.gd"
    FoundationHudBarScript = "res://scripts/ui/foundation_hud_bar.gd"
    EnvironmentHeaderScript = "res://scripts/ui/environment_header.gd"
    CheatDockScript = "res://scripts/ui/cheat_dock.gd"
    RunReportScreenScript = "res://scripts/ui/run_report_screen.gd"
    RunReportViewModelScript = "res://scripts/ui/run_report_view_model.gd"
    HeatGainFeedbackOverlayScript = "res://scripts/ui/heat_gain_feedback_overlay.gd"
    TalkDockScript = "res://scripts/ui/talk_dock.gd"
    RunInventoryScreenScript = "res://scripts/ui/run_inventory_screen.gd"
    MetaItemInteractionScreenScript = "res://scripts/ui/meta_item_interaction_screen.gd"
    BagOpenReelScript = "res://scripts/ui/bag_open_reel.gd"
    WorldMapCanvasScript = "res://scripts/ui/world_map_canvas.gd"
    WorldMapOverlayControllerScript = "res://scripts/ui/world_map_overlay_controller.gd"
    ItemFoundPopupScript = "res://scripts/ui/item_found_popup.gd"
    CoachOverlayScript = "res://scripts/ui/coach_overlay.gd"
    CoachViewModelScript = "res://scripts/ui/coach_view_model.gd"
}

foreach ($entry in $roots.GetEnumerator()) {
    $dynamicEntry = '"{0}": "{1}"' -f $entry.Key, $entry.Value
    if (-not $source.Contains($dynamicEntry)) {
        throw "Missing deferred run-UI mapping: $dynamicEntry"
    }
    if (-not $source.Contains("var $($entry.Key): Script")) {
        throw "Deferred run-UI script field is not a strong nullable Script reference: $($entry.Key)"
    }
    if ($source.Contains("const $($entry.Key) := preload(`"$($entry.Value)`")")) {
        throw "Run-UI root is still parsed through a direct preload: $($entry.Key)"
    }
}

$requiredContracts = @(
    "func _ensure_run_ui_stage_scripts(stage_index: int) -> bool:",
    "var staged_scripts: Dictionary = {}",
    "func _build_next_run_ui_stage() -> bool:",
    "if not _ensure_run_ui_stage_scripts(run_ui_build_stage):",
    "func _ensure_run_ui_built() -> bool:",
    "if not _ensure_run_ui_built():",
    "func _present_run_ui_unavailable() -> void:",
    "RUN_UI_UNAVAILABLE_MESSAGE",
    "func start_foundation_run(seed_text: String = DEFAULT_SEED, challenge_config: Dictionary = {}, include_meta_home_modifiers: bool = true) -> bool:",
    "func load_foundation_run() -> bool:",
    "if WorldMapOverlayControllerScript != null:"
)
foreach ($contract in $requiredContracts) {
    if (-not $source.Contains($contract)) {
        throw "Missing web run-UI deferral contract: $contract"
    }
}

$forbiddenTypeChecks = @(
    "restored_world_map_controller is WorldMapOverlayController",
    "restored_coach is CoachOverlay",
    "restored_dock is TalkDock"
)
foreach ($forbidden in $forbiddenTypeChecks) {
    if ($source.Contains($forbidden)) {
        throw "Deferred root still has a parse-time global-class dependency: $forbidden"
    }
}

Write-Output "PASS: 17 run-UI roots are deferred behind atomic staged loading with fail-closed start/load guards."
