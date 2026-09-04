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
    EnvironmentInteractionViewModelScript = "res://scripts/ui/environment_interaction_view_model.gd"
    EnvironmentInteractionControllerScript = "res://scripts/ui/environment_interaction_controller.gd"
    FoundationActionViewModelScript = "res://scripts/ui/foundation_action_view_model.gd"
    TerminalConsequenceViewModelScript = "res://scripts/ui/terminal_consequence_view_model.gd"
    FoundationHudViewModelScript = "res://scripts/ui/foundation_hud_view_model.gd"
    CageCounterViewModelScript = "res://scripts/ui/cage_counter_view_model.gd"
    CageAtmViewModelScript = "res://scripts/ui/cage_atm_view_model.gd"
    WagerConfirmationControllerScript = "res://scripts/ui/wager_confirmation_controller.gd"
    RunInventoryViewModelScript = "res://scripts/ui/run_inventory_view_model.gd"
    MetaItemInteractionViewModelScript = "res://scripts/ui/meta_item_interaction_view_model.gd"
    BagOpenReelViewModelScript = "res://scripts/ui/bag_open_reel_view_model.gd"
    RunJournalViewModelScript = "res://scripts/ui/run_journal_view_model.gd"
    FoundationTravelViewModelScript = "res://scripts/ui/foundation_travel_view_model.gd"
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

$stageContracts = @(
    '0: ["GameSurfaceCanvasScript", "SfxPlayerScript", "FoundationHudBarScript", "EnvironmentHeaderScript", "CheatDockScript", "RunReportScreenScript", "RunReportViewModelScript", "HeatGainFeedbackOverlayScript", "EnvironmentInteractionViewModelScript", "EnvironmentInteractionControllerScript", "FoundationActionViewModelScript", "TerminalConsequenceViewModelScript", "FoundationHudViewModelScript", "CageCounterViewModelScript", "CageAtmViewModelScript"]',
    '4: ["WagerConfirmationControllerScript"]',
    '6: ["RunInventoryScreenScript", "RunInventoryViewModelScript"]',
    '7: ["MetaItemInteractionScreenScript", "BagOpenReelScript", "MetaItemInteractionViewModelScript", "BagOpenReelViewModelScript"]',
    '8: ["RunJournalViewModelScript"]',
    '10: ["WorldMapCanvasScript", "WorldMapOverlayControllerScript", "FoundationTravelViewModelScript"]'
)
foreach ($stageContract in $stageContracts) {
    if (-not $source.Contains($stageContract)) {
        throw "Deferred run-UI stage lost its atomic root group: $stageContract"
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
    "if WorldMapOverlayControllerScript != null:",
    "func _enter_meta_location(location_id: String, tutorial_handoff: bool = false) -> Dictionary:",
    "func start_game_test_session(game_id: String) -> Dictionary:"
)
foreach ($contract in $requiredContracts) {
    if (-not $source.Contains($contract)) {
        throw "Missing web run-UI deferral contract: $contract"
    }
}

$guardedEntryPatterns = [ordered]@{
    start_foundation_run = '(?m)^func start_foundation_run\([^\r\n]+\) -> bool:\r?\n\tif not _ensure_run_ui_built\(\):'
    load_slot = '(?m)^func _load_foundation_run_from_slot\([^\r\n]+\) -> bool:\r?\n\tif not _ensure_run_ui_built\(\):'
    start_button = '(?m)^func _on_start_pressed\(\) -> bool:\r?\n\tif not _ensure_run_ui_built\(\):'
    tutorial = '(?m)^func start_tutorial_run\(\) -> bool:\r?\n\tif not _ensure_run_ui_built\(\):'
    generated = '(?m)^func start_generated_foundation_run\(\) -> bool:\r?\n\tif not _ensure_run_ui_built\(\):'
    meta_quick = '(?m)^func start_meta_quick_run\(\) -> bool:\r?\n\tif not _ensure_run_ui_built\(\):'
    meta_location = '(?m)^func _enter_meta_location\([^\r\n]+\) -> Dictionary:\r?\n\tif not _ensure_run_ui_built\(\):'
    game_test = '(?ms)^func start_game_test_session\([^\r\n]+\) -> Dictionary:\r?\n\tif not show_game_library_launcher:[^\r\n]*\r?\n\t\treturn[^\r\n]*\r?\n\tif not _ensure_run_ui_built\(\):'
}
foreach ($entry in $guardedEntryPatterns.GetEnumerator()) {
    if ($source -notmatch $entry.Value) {
        throw "Run-UI loader guard no longer precedes mutation for entry point: $($entry.Key)"
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

Write-Output "PASS: 30 run-UI roots are deferred behind atomic staged loading with fail-closed start/load guards."
