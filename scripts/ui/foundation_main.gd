class_name FoundationMain
extends Control

# Thin UI shell for the README foundation runtime.

const DEFAULT_SEED := "FOUNDATION-UI-SEED"
const AUTOSAVE_SLOT := "foundation_ui_autosave"
const RELEASE_MENU_FRAMING := "Fictional casino roguelike. Simulated gambling only; no real-money wagering or cash prizes."
const ACTION_CATEGORY_GAMES := "games"
const ACTION_CATEGORY_EVENTS := "events"
const ACTION_CATEGORY_ITEMS := "items"
const ACTION_CATEGORY_TRAVEL := "travel"
const SCREEN_START := "START"
const SCREEN_ENVIRONMENT := "ENVIRONMENT"
const SCREEN_GAME := "GAME"
const SCREEN_RESULT := "RESULT"
const SCREEN_FAILURE := "FAILURE"
const SCREEN_VICTORY := "VICTORY"
const SCREEN_EVENT := "EVENT"
const SCREEN_ITEMS := "ITEMS"
const SCREEN_TRAVEL := "TRAVEL"
const CONTEXT_MODE_ROOM := "room"
const CONTEXT_MODE_GAME := "game"
const CONTEXT_MODE_EVENT := "event"
const CONTEXT_MODE_ITEM := "item"
const CONTEXT_MODE_TRAVEL := "travel"
const CONTEXT_MODE_SERVICE := "service"
const CONTEXT_MODE_LENDER := "lender"
const CONTEXT_MODE_SHOPKEEPER := "shopkeeper"
const CONTEXT_MODE_GAME_HOOK := "game_hook"
const CONTEXT_MODE_DIALOGUE := "dialogue"
const CONTEXT_MODE_CASINO_FIXTURE := "casino_fixture"
const CONTEXT_MODE_HOME_TENURE := "home_tenure"
const CONTEXT_MODE_HOME_SLEEP := "home_sleep"
const CONTEXT_MODE_HOME_STORAGE := "home_storage"
const CONTEXT_MODE_HOME_CONTAINER := "home_container"
const CONTEXT_MODE_META_BAG := "meta_bag"
const CONTEXT_MODE_META_UPGRADE := "meta_upgrade"
const CONTEXT_MODE_META_TRADE_UP := "meta_trade_up"
const CONTEXT_MODE_META_PAWN_COUNTER := "meta_pawn_counter"
const CONTEXT_MODE_META_SAL_SHELF := "meta_sal_shelf"
const CONTEXT_MODE_META_SAL_TALK := "meta_sal_talk"
const META_LOCATION_HOME := "home"
const META_LOCATION_START_RUN := "start_run"
const RUN_INFO_BAND_RATIO := 0.15
const RUN_SURFACE_BAND_RATIO := 0.85
const RUN_INFO_MIN_HEIGHT := 144.0
const ENVIRONMENT_CANVAS_MIN_SIZE := Vector2.ZERO
const GAME_SURFACE_FOCUSED_MIN_SIZE := Vector2.ZERO
const GAME_SURFACE_PREVIEW_MIN_SIZE := Vector2.ZERO
const GAME_SURFACE_REALTIME_REFRESH_INTERVAL_MSEC := 16
const GAME_CLOCK_MINUTES_PER_REAL_SECOND := 4.0
const TRAVEL_CLOCK_MINUTES_PER_BLOCK := 6
const WALK_CLOCK_MINUTES_PER_BLOCK := 10
const TALK_IGNORE_HEAT_DELTA := 5
const CLOSING_TIME_DIALOGUE_ID := "venue_closing_notice"
const CLOSING_TIME_TALK_EVENT_ID := "dialogue:venue_closing_notice"
const CLOSING_TIME_TALK_CHOICE_ID := "head_out"
const RUN_ITEM_ICON_TEXTURE_CACHE_LIMIT := 64
const RESULT_FEEDBACK_WIDTH := 340.0
const RESULT_FEEDBACK_HEIGHT := 46.0
const RESULT_FEEDBACK_MAX_CHARS := 64
const MAIN_MENU_COLLAPSED_SIZE := Vector2(780, 560)
const MAIN_MENU_EXPANDED_SIZE := Vector2(940, 380)
const MAIN_MENU_VIEWPORT_MARGIN := Vector2(32, 24)
const ACCESSIBILITY_BASE_FONT_META := "accessibility_base_font_size"
const ACCESSIBILITY_BASE_MIN_SIZE_META := "accessibility_base_min_size"
const ACCESSIBILITY_BASE_COLOR_META := "accessibility_base_font_color"
const ACCESSIBILITY_STYLEBOX_META_PREFIX := "accessibility_base_stylebox_"
const DEFAULT_CONTROL_FONT_SIZE := 13
const MIN_NATIVE_TOUCH_TARGET_HEIGHT := 40.0
const EVENT_CHOICE_POPUP_BASE_SIZE := Vector2(460, 320)
const EVENT_CHOICE_POPUP_MAX_SIZE := Vector2(640, 500)
const EVENT_CHOICE_TEXT_MAX_LINES := 2
const EVENT_CHOICE_SUMMARY_MAX_LINES := 3
const RUN_INVENTORY_POPUP_SIZE := Vector2(1120, 620)
const RUN_INVENTORY_POPUP_MARGIN := 12.0
const RUN_INVENTORY_ITEM_CARD_SIZE := Vector2(118, 104)
const WORLD_MAP_NODE_BUTTON_POOL_SIZE := 12
const WORLD_MAP_DETAIL_BADGE_CELL_POOL_SIZE := 10
const GAME_SURFACE_UI_PREFERENCE_KEYS := [
	"selected_chip",
	"selected_stake",
	"selected_stake_index",
	"bet_level",
	"denomination_index",
]
const UserSettingsScript := preload("res://scripts/core/user_settings.gd")
const ProfileInventoryScript := preload("res://scripts/core/profile_inventory.gd")
const TutorialFlowScript := preload("res://scripts/core/tutorial_flow.gd")
const MetaCollectionServiceScript := preload("res://scripts/core/meta_collection_service.gd")
const CollectionDropServiceScript := preload("res://scripts/core/collection_drop_service.gd")
const CollectionItemResolverScript := preload("res://scripts/core/collection_item_resolver.gd")
const SettingsMenuScript := preload("res://scripts/ui/settings_menu.gd")
const PixelSceneCanvasScript := preload("res://scripts/ui/pixel_scene_canvas.gd")
const GameSurfaceCanvasScript := preload("res://scripts/ui/game_surface_canvas.gd")
const WorldMapCanvasScript := preload("res://scripts/ui/world_map_canvas.gd")
const FoundationWidgetsScript := preload("res://scripts/ui/foundation_widgets.gd")
const SmallScreenPolicyScript := preload("res://scripts/ui/small_screen_policy.gd")
const AttributeBadgeRowScript := preload("res://scripts/ui/attribute_badge_row.gd")
const RunInventoryScreenScript := preload("res://scripts/ui/run_inventory_screen.gd")
const RunInventoryViewModelScript := preload("res://scripts/ui/run_inventory_view_model.gd")
const MetaItemInteractionScreenScript := preload("res://scripts/ui/meta_item_interaction_screen.gd")
const MetaItemInteractionViewModelScript := preload("res://scripts/ui/meta_item_interaction_view_model.gd")
const BagOpenReelScript := preload("res://scripts/ui/bag_open_reel.gd")
const BagOpenReelViewModelScript := preload("res://scripts/ui/bag_open_reel_view_model.gd")
const CageCounterViewModelScript := preload("res://scripts/ui/cage_counter_view_model.gd")
const CageAtmViewModelScript := preload("res://scripts/ui/cage_atm_view_model.gd")
const MetaCollectionViewModelScript := preload("res://scripts/ui/meta_collection_view_model.gd")
const RunJournalViewModelScript := preload("res://scripts/ui/run_journal_view_model.gd")
const RunReportViewModelScript := preload("res://scripts/ui/run_report_view_model.gd")
const RunReportScreenScript := preload("res://scripts/ui/run_report_screen.gd")
const TerminalConsequenceViewModelScript := preload("res://scripts/ui/terminal_consequence_view_model.gd")
const EnvironmentInteractionViewModelScript := preload("res://scripts/ui/environment_interaction_view_model.gd")
const EnvironmentInteractionControllerScript := preload("res://scripts/ui/environment_interaction_controller.gd")
const FoundationHudViewModelScript := preload("res://scripts/ui/foundation_hud_view_model.gd")
const FoundationActionViewModelScript := preload("res://scripts/ui/foundation_action_view_model.gd")
const FoundationTravelViewModelScript := preload("res://scripts/ui/foundation_travel_view_model.gd")
const FoundationScreenBuilderScript := preload("res://scripts/ui/foundation_screen_builder.gd")
const MetaSessionControllerScript := preload("res://scripts/ui/meta_session_controller.gd")
const WorldMapOverlayControllerScript := preload("res://scripts/ui/world_map_overlay_controller.gd")
const WagerConfirmationControllerScript := preload("res://scripts/ui/wager_confirmation_controller.gd")
const TalkDockScript := preload("res://scripts/ui/talk_dock.gd")
const ItemFoundPopupScript := preload("res://scripts/ui/item_found_popup.gd")
const CoachOverlayScript := preload("res://scripts/ui/coach_overlay.gd")
const SfxPlayerScript := preload("res://scripts/ui/sfx_player.gd")
const ProceduralMusicPlayerScript := preload("res://scripts/ui/procedural_music_player.gd")
const PerfTelemetryOverlayScript := preload("res://scripts/ui/perf_telemetry_overlay.gd")
const RunTerminalEvaluatorScript := preload("res://scripts/core/run_terminal_evaluator.gd")
const RunActionServiceScript := preload("res://scripts/core/run_action_service.gd")
const AttributeBadgesScript := preload("res://scripts/core/attribute_badges.gd")
const ItemEffectScript := preload("res://scripts/core/item_effect.gd")
const WorldMapScript := preload("res://scripts/core/world_map.gd")

var user_settings: UserSettings
var profile_inventory: ProfileInventory
var meta_collection_service: MetaCollectionService
var meta_session_controller: MetaSessionController
var collection_drop_service: CollectionDropService
var library: ContentLibrary
var run_state: RunState
var generator: RunGenerator
var save_service: SaveService
var platform_services: PlatformServices
var run_action_service: RunActionService
var current_game: GameModule
var last_game_result: Dictionary = {}
var last_music_outcome_schedule: Dictionary = {}
var last_environment_runtime_result: Dictionary = {}
var selected_action_id: String = ""
var selected_action_kind: String = ""
var selected_action_label: String = ""
var selected_stake: int = 0
var selected_travel_target_id: String = ""
var selected_travel_label: String = ""
var selected_event_id: String = ""
var selected_event_choice_id: String = ""
var selected_event_label: String = ""
var selected_event_choice_label: String = ""
var selected_item_offer_id: String = ""
var selected_item_offer_label: String = ""
var selected_item_offer_price: int = 0
var last_item_result: Dictionary = {}
var selected_service_hook_id: String = ""
var selected_service_hook_label: String = ""
var selected_lender_hook_id: String = ""
var selected_lender_hook_label: String = ""
var last_hook_result: Dictionary = {}
var save_status_message: String = ""
var selected_action_category: String = ACTION_CATEGORY_GAMES
var current_screen: String = SCREEN_START
var hover_target_id: String = ""
var focus_target_id: String = ""
var selected_object_id: String = ""
var camera_focus_rect: Rect2 = Rect2()
var camera_focus_point: Vector2 = Vector2(0.5, 0.5)
var current_context_mode: String = CONTEXT_MODE_ROOM
var game_surface_ui_state: Dictionary = {}
var game_module_cache: Dictionary = {}
var pending_event_choice_popup_event_id: String = ""
var pending_event_choice_popup_focus_choice_id: String = ""
var pending_event_choice_popup_snapshot: Dictionary = {}
var pending_wager_confirm_action_id: String = ""
var pending_wager_confirm_skip_stake_validation := false
var pending_wager_confirm_preserve_surface_ui_state := false
var pending_wager_confirm_stake: int = 0
var pending_wager_confirm_source_game_id: String = ""
var pending_all_in_result_terminal_check := false
var terminal_evaluator_call_count := 0
var presented_bankroll_hold_active := false
var presented_bankroll_value := 0
var presented_bankroll_game_id := ""
var presented_bankroll_action_id := ""
var presented_bankroll_release_screen := ""
var presented_bankroll_started_msec := 0
var pending_active_item_id: String = ""
var run_inventory_popup_mode: String = ""
var run_inventory_context_container_id: String = ""
var selected_run_inventory_item_id: String = ""
var selected_run_inventory_item_source: String = ""
var travel_transition_active := false
var travel_transition_target_id: String = ""
var travel_transition_target_label: String = ""
var game_surface_auto_resolving := false
var environment_game_runtime_scan_count := 0
var last_game_surface_realtime_refresh_msec := 0
var surface_feature_music_active := false
var surface_feature_music_ducking := false
var drunk_time_anchor_real_msec := 0
var drunk_time_anchor_scaled_msec := 0
var drunk_time_last_scale := 1.0
var dev_game_test_mode := false
var meta_session_active := false
var meta_session_location_id: String = ""
var meta_last_panel_message: String = ""
var meta_interactable_object_view_cache: Array = []
var meta_interactable_object_view_cache_key := ""
var show_game_library_launcher := true
var autosave_slot_id := AUTOSAVE_SLOT
var pending_autosave := false
var pending_autosave_status_text := "Autosaved."
var pending_autosave_after_frame := -1

var start_screen: Control
var run_screen: Control
var main_menu_panel: PanelContainer
var start_menu_controls: VBoxContainer
var start_menu_intro: VBoxContainer
var start_menu_stack: VBoxContainer
var release_framing_label: Label
var release_version_label: Label
var main_menu_background: Control
var inventory_page: VBoxContainer
var inventory_status_label: Label
var inventory_items_list: VBoxContainer
var game_test_menu: VBoxContainer
var game_library_button: Button
var game_test_status_label: Label
var game_test_seed_input: LineEdit
var game_test_bankroll_input: SpinBox
var game_test_stake_floor_input: SpinBox
var game_test_stake_ceiling_input: SpinBox
var game_test_security_option: OptionButton
var game_test_generation_overrides_text: TextEdit
var acquire_chip_button: Button
var inventory_button: Button
var collections_button: Button
var profile_chip_texture: Texture2D
var run_item_icon_texture_cache: Dictionary = {}
var seed_input: LineEdit
var main_menu_seed_counter: int = 0
var content_group_config_button: Button
var content_group_panel: PanelContainer
var content_group_status_label: Label
var home_type_option: OptionButton
var selected_home_type_id: String = RunState.HOME_SELECTION_RANDOM
var content_group_list: GridContainer
var content_group_toggles: Dictionary = {}
var selected_content_group_ids: Array = []
var challenge_select_button: Button
var challenge_panel: PanelContainer
var challenge_status_label: Label
var challenge_list: VBoxContainer
var challenge_buttons: Dictionary = {}
var selected_challenge_id: String = ""
var start_menu_action_controls: Array[Control] = []
var start_status_label: Label
var content_validation_status_message: String = ""
var content_validation_error_count := 0
var new_run_button: Button
var daily_run_button: Button
var continue_button: Button
var replay_tutorial_button: Button
var settings_button: Button
var exit_game_button: Button
var top_menu_button: Button
var top_settings_button: Button
var top_inventory_button: Button
var active_item_button: Button
var run_menu_overlay: Control
var run_menu_panel: PanelContainer
var run_menu_status_label: Label
var run_menu_resume_button: Button
var run_menu_save_button: Button
var run_menu_load_button: Button
var run_menu_journal_button: Button
var run_menu_settings_button: Button
var run_menu_abandon_button: Button
var run_menu_main_menu_button: Button
var run_menu_skip_tutorial_button: Button
var tutorial_skip_dialog: ConfirmationDialog
var settings_overlay: Control
var settings_margin: MarginContainer
var settings_menu: SettingsMenu
var procedural_music_player: ProceduralMusicPlayer
var environment_sfx_player: Node
var perf_telemetry_overlay: PerfTelemetryOverlay
var boot_telemetry_events: Array = []
var boot_start_msec := 0
var event_choice_popup_overlay: Control
var event_choice_popup_panel: PanelContainer
var event_choice_popup_title_label: Label
var event_choice_popup_summary_label: Label
var event_choice_popup_choices_list: VBoxContainer
var talk_dock: TalkDock
var item_found_popup: ItemFoundPopup
var coach_overlay: CoachOverlay
var item_found_talk_dock_suspended := false
var conclusion_animation_overlay: Control
var conclusion_animation_snapshot: Dictionary = {}
var conclusion_animation_tweens: Array[Tween] = []
var run_inventory_screen: RunInventoryScreen
var run_inventory_overlay: Control
var meta_item_interaction_screen: MetaItemInteractionScreen
var bag_open_reel: BagOpenReel
var meta_item_interaction_mode := ""
var selected_meta_item_key := ""
var meta_trade_selected_instance_ids: Array = []
var run_inventory_panel: PanelContainer
var run_inventory_items_scroll: ScrollContainer
var run_inventory_detail_panel: PanelContainer
var run_inventory_title_label: Label
var run_inventory_summary_label: Label
var run_inventory_list: GridContainer
var run_inventory_detail_box: VBoxContainer
var run_journal_overlay: Control
var run_journal_panel: PanelContainer
var run_journal_summary_label: Label
var run_journal_list: VBoxContainer
var travel_transition_overlay: Control
var travel_transition_panel: PanelContainer
var travel_transition_title_label: Label
var travel_transition_body_label: Label
var world_map_overlay: Control
var world_map_panel: PanelContainer
var world_map_holder: Control
var world_map_nodes_layer: Control
var world_map_title_label: Label
var world_map_detail_popup: PanelContainer
var world_map_detail_label: Label
var world_map_badge_slot: VBoxContainer
var world_map_badge_row: HFlowContainer
var world_map_badge_cells: Array = []
var world_map_confirm_button: Button
var world_map_overlay_controller: WorldMapOverlayController
var wager_confirmation_controller: WagerConfirmationController
var selected_world_map_node_id: String = ""
var world_map_button_ids: Array = []
var world_map_button_layout_size := Vector2(-1.0, -1.0)
var world_map_button_relayout_deferred := false
var travel_target_ids_cache_key: String = ""
var travel_target_ids_cache: Array = []
var travel_choice_cache_key: String = ""
var travel_choice_cache: Array = []
var world_route_cache_key: String = ""
var world_route_cache: Dictionary = {}
var world_map_snapshot_cache_key: String = ""
var world_map_snapshot_cache: Dictionary = {}
var world_map_canvas_snapshot_key: String = ""
var world_map_detail_badges_key: String = "__unset__"
var rendered_environment_snapshot_signature: String = ""
var action_panel_refresh_scheduled := false
var pending_action_panel_object: Dictionary = {}
var interactable_object_view_cache: Array = []
var interactable_object_view_cache_valid := false
var interactable_object_view_cache_key := ""
var run_hud_panel: Panel
var visual_panel_container: PanelContainer
var title_label: Label
var summary_label: Label
var environment_result_panel: PanelContainer
var environment_result_title_label: Label
var environment_result_body_label: Label
var run_report_screen: RunReportScreen
var run_report_model: Dictionary = {}
var run_report_model_key := ""
var status_label: Label
var objective_label: Label
var message_label: Label
var save_status_label: Label
var consequence_panel: PanelContainer
var consequence_heading_label: Label
var consequence_state_label: Label
var consequence_result_label: Label
var consequence_story_label: Label
var consequence_cards_scroll: ScrollContainer
var consequence_cards_list: BoxContainer
var action_panel_container: PanelContainer
var action_heading_label: Label
var action_hint_label: Label
var stake_input: SpinBox
var actions_list: VBoxContainer
var environment_canvas: PixelSceneCanvas
var game_surface_canvas: GameSurfaceCanvas
var run_layout_dirty := true
var run_layout_last_screen_size := Vector2(-1.0, -1.0)
var web_audio_unlock_refresh_scheduled := false
var web_audio_unlock_refresh_count := 0

const WEB_AUDIO_UNLOCK_REFRESH_ATTEMPTS := 4
const WEB_AUDIO_UNLOCK_REFRESH_DELAY_SECONDS := 0.20

# UI overlay state machine contract:
# - Start-menu configuration panels are start-only and never coexist with run overlays.
# - In-run base screens are ENVIRONMENT, GAME, RESULT, EVENT, ITEMS, TRAVEL,
#   FAILURE, and VICTORY. These are screens, not modal overlays.
# - Blocking decision popups use event_choice_popup_overlay for triggered events,
#   unavoidable events, all-in wager confirmation, and active-item confirmation.
#   While visible, they are exclusive: no travel, map, inventory, journal, run menu,
#   background room activation, or game resolve may run. Their own confirm/cancel
#   handlers are the only mutating exits.
# - Interactable-event popups also use event_choice_popup_overlay. They are
#   dismissible but still exclusive until a response or dismissal closes them.
# - world_map_overlay, run_inventory_overlay, and run_journal_overlay are mutually
#   exclusive with decision popups and with each other. The run menu may remain
#   behind the read-only journal because it owns that button, but gameplay input
#   is still blocked while the journal is open.
# - travel_transition_overlay is transient and exclusive. It blocks all player
#   input until _hide_travel_transition clears travel_transition_active.
# - settings_overlay may stack over the run menu only; it must not stack over
#   travel, world map, inventory, journal, or decision popups.

func _ready() -> void:
	boot_start_msec = Time.get_ticks_msec()
	boot_telemetry_events = []
	_mark_boot_event("engine_ready_start", {"autoload_count": _project_autoload_count()})
	_initialize_user_settings()
	_mark_boot_event("user_settings_ready")
	_initialize_procedural_music()
	_mark_boot_event("music_ready")
	_initialize_profile_inventory()
	_mark_boot_event("profile_inventory_ready")
	collection_drop_service = CollectionDropServiceScript.new()
	_mark_boot_event("meta_collection_deferred")
	_initialize_foundation()
	_mark_boot_event("foundation_ready")
	_build_ui()
	_mark_boot_event("ui_built")
	_refresh()
	_mark_boot_event("main_menu_interactive", {
		"screen": current_screen,
		"continue_available": _has_foundation_save(),
		"challenge_count": library.challenges.size() if library != null else 0,
	})
	_initialize_perf_telemetry()


func _process(_delta: float) -> void:
	if perf_telemetry_overlay == null:
		if run_layout_dirty:
			_apply_run_screen_layout()
		if current_screen == SCREEN_GAME:
			_advance_game_surface_automation()
			_advance_game_surface_realtime_state()
		if presented_bankroll_hold_active:
			_advance_presented_bankroll()
		if (current_screen == SCREEN_ENVIRONMENT or current_screen == SCREEN_GAME) and not meta_session_active:
			_advance_environment_game_runtime()
		if pending_autosave:
			_flush_pending_autosave_if_ready()
		return
	perf_telemetry_overlay.begin_foundation_frame()
	if run_layout_dirty:
		var layout_started_usec := Time.get_ticks_usec()
		_apply_run_screen_layout()
		perf_telemetry_overlay.record_foundation_subsystem_usec("layout", Time.get_ticks_usec() - layout_started_usec)
	if current_screen == SCREEN_GAME:
		var snapshot_started_usec := Time.get_ticks_usec()
		_advance_game_surface_automation()
		_advance_game_surface_realtime_state()
		perf_telemetry_overlay.record_foundation_subsystem_usec("snapshot_builds", Time.get_ticks_usec() - snapshot_started_usec)
	if presented_bankroll_hold_active:
		var presented_started_usec := Time.get_ticks_usec()
		_advance_presented_bankroll()
		perf_telemetry_overlay.record_foundation_subsystem_usec("snapshot_builds", Time.get_ticks_usec() - presented_started_usec)
	if (current_screen == SCREEN_ENVIRONMENT or current_screen == SCREEN_GAME) and not meta_session_active:
		var environment_started_usec := Time.get_ticks_usec()
		_advance_environment_game_runtime()
		perf_telemetry_overlay.record_foundation_subsystem_usec("environment_runtime", Time.get_ticks_usec() - environment_started_usec)
	if pending_autosave:
		var autosave_started_usec := Time.get_ticks_usec()
		_flush_pending_autosave_if_ready()
		perf_telemetry_overlay.record_foundation_subsystem_usec("autosave_flush", Time.get_ticks_usec() - autosave_started_usec)


func _input(event: InputEvent) -> void:
	if _is_web_audio_unlock_gesture(event):
		if procedural_music_player != null and procedural_music_player.has_method("web_audio_user_gesture"):
			procedural_music_player.web_audio_user_gesture()
		_schedule_web_audio_unlock_refresh()
	if talk_dock != null and not _modal_contract_blocks_player_input() and talk_dock.handle_hotkey(event):
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_invalidate_run_screen_layout()
		_apply_run_screen_layout()


func _initialize_perf_telemetry() -> void:
	if perf_telemetry_overlay != null or not PerfTelemetryOverlayScript.runtime_enabled():
		return
	perf_telemetry_overlay = PerfTelemetryOverlayScript.new()
	add_child(perf_telemetry_overlay)
	perf_telemetry_overlay.configure(self)


# Compile checks use this to verify the active scene is on the foundation path.
func uses_foundation_runtime() -> bool:
	return library != null and generator != null and save_service != null and platform_services != null


# Starts a deterministic foundation run.
func start_foundation_run(seed_text: String = DEFAULT_SEED, challenge_config: Dictionary = {}, include_meta_home_modifiers: bool = true) -> void:
	if library == null:
		_initialize_foundation()
	_finish_conclusion_animation()
	meta_session_active = false
	meta_session_location_id = ""
	meta_last_panel_message = ""
	pending_all_in_result_terminal_check = false
	_sync_presented_bankroll_to_actual()
	pending_autosave = false
	pending_autosave_status_text = "Autosaved."
	pending_autosave_after_frame = -1
	last_environment_runtime_result = {}
	run_report_model = {}
	run_report_model_key = ""
	run_item_icon_texture_cache.clear()
	close_content_group_config()
	close_challenge_selection()
	_hide_run_menu()
	_hide_world_map_overlay()
	close_meta_item_interaction()
	_hide_run_journal_popup()
	_hide_travel_transition()
	_reset_game_surface_runtime_state()
	var resolved_seed := seed_text.strip_edges()
	if resolved_seed.is_empty():
		resolved_seed = DEFAULT_SEED
	var resolved_challenge_config := _challenge_with_meta_home_for_run(resolved_seed, challenge_config) if include_meta_home_modifiers else RunState.normalize_challenge(resolved_seed, challenge_config)
	run_state = RunState.new()
	run_state.start_new(resolved_seed, resolved_challenge_config)
	_configure_coach_for_run()
	_sync_scratch_ticket_discovery_to_run()
	_sync_presented_bankroll_to_actual()
	_apply_meta_collection_loadout_to_run()
	run_state.begin_act(1)
	dev_game_test_mode = false
	generator.next_environment(run_state)
	_refresh_run_action_service()
	current_game = null
	last_game_result = {}
	last_item_result = {}
	last_hook_result = {}
	save_status_message = "Run not saved yet."
	selected_action_category = ACTION_CATEGORY_GAMES
	_set_current_screen(SCREEN_ENVIRONMENT)
	_hide_event_choice_popup()
	_hide_run_inventory_popup()
	_hide_run_journal_popup()
	_hide_world_map_overlay()
	_hide_travel_transition()
	if talk_dock != null:
		talk_dock.clear_entry()
	if item_found_popup != null:
		item_found_popup.clear_all()
	_clear_selected_game_action()
	_clear_selected_stake()
	_clear_selected_travel()
	_clear_selected_event_choice()
	_clear_selected_item_offer()
	_clear_selected_service_hook()
	_clear_selected_lender_hook()
	clear_interaction_focus()
	_show_message("The run begins.")
	_autosave_foundation_run("Autosaved.")
	_refresh()
	_prewarm_world_map_overlay_for_run()


func start_daily_challenge_run() -> void:
	var today: Dictionary = Time.get_datetime_dict_from_system()
	var day := int(today.get("day", 1))
	var month := int(today.get("month", 1))
	var seed_text := _daily_challenge_seed_for_date(day, month)
	var daily_id := _daily_challenge_id_for_datetime(today)
	var challenge_config: Dictionary = RunState.daily_challenge(daily_id, seed_text, true)
	start_foundation_run(seed_text, challenge_config)
	_show_message("Daily challenge begins. The seed is hidden.")
	_refresh()


func _daily_challenge_seed_for_date(day: int, month: int) -> String:
	var safe_day := maxi(1, day)
	var safe_month := maxi(1, month)
	return "%d/%d" % [safe_day * 32, safe_month * 2]


func _daily_challenge_id_for_datetime(datetime: Dictionary) -> String:
	var year := int(datetime.get("year", 0))
	var month := maxi(1, int(datetime.get("month", 1)))
	var day := maxi(1, int(datetime.get("day", 1)))
	if year <= 0:
		return "daily-%02d-%02d" % [month, day]
	return "%04d-%02d-%02d" % [year, month, day]


# Selects which player-facing action category is expanded without changing simulation state.
func select_action_category(category_id: String) -> bool:
	if _guard_player_input_route():
		return false
	var category := _action_category(category_id)
	if category.is_empty():
		return false
	selected_action_category = category_id
	_set_current_screen(_screen_for_action_category(category_id))
	_focus_first_interactable_for_category(category_id)
	_refresh()
	return true


# Enters the first generated game option.
func enter_first_available_game() -> void:
	if run_state == null:
		return
	var game_ids := _string_array(run_state.current_environment.get("game_ids", []))
	if game_ids.is_empty():
		_show_message("No game is available in this environment.")
		return
	enter_game(game_ids[0])


# Enters a game through its data-routed GameModule.
func enter_game(game_id: String, state_key: String = "") -> void:
	var clean_game_id := game_id.strip_edges()
	var clean_state_key := state_key.strip_edges()
	if clean_state_key.is_empty():
		clean_state_key = clean_game_id
	var object_id := "game:%s" % clean_state_key
	if _guard_player_input_route(false, object_id):
		return
	var definition := library.game(clean_game_id)
	if definition.is_empty():
		_show_message("Game definition is missing.")
		return
	var game_module := _game_module_for_id(clean_game_id)
	if game_module == null:
		_show_message("This game is not ready here.")
		return
	if clean_state_key != clean_game_id:
		_set_active_game_state_key(clean_game_id, clean_state_key)
	_reset_game_surface_runtime_state()
	current_game = game_module
	_sync_presented_bankroll_to_actual()
	selected_action_category = ACTION_CATEGORY_GAMES
	_set_current_screen(SCREEN_GAME)
	focus_interactable_object(object_id)
	_clear_selected_game_action()
	var result := current_game.enter(run_state, run_state.current_environment)
	last_game_result = result.duplicate(true)
	_reset_selected_stake()
	_show_message(str(result.get("message", "")))
	_refresh()
	_clear_selected_stake()
	_refresh_stake_input()


func _enter_grand_casino_duel_surface() -> bool:
	if run_state == null or not run_state.grand_casino_duel_active(run_state.current_environment):
		return false
	_reset_game_surface_runtime_state()
	if str(run_state.current_environment.get("archetype_id", "")) != RunState.GRAND_CASINO_BACK_ROOM_ARCHETYPE_ID:
		if not generator.enter_grand_casino_room(run_state, RunState.GRAND_CASINO_BACK_ROOM_ARCHETYPE_ID):
			return false
	var duel_game_ids := _string_array(run_state.current_environment.get("game_ids", []))
	if duel_game_ids.is_empty():
		return false
	var duel_game_id := str(duel_game_ids[0])
	var game_module := _game_module_for_id(duel_game_id)
	if game_module == null:
		return false
	current_game = game_module
	_sync_presented_bankroll_to_actual()
	selected_action_category = ACTION_CATEGORY_GAMES
	_set_current_screen(SCREEN_GAME)
	focus_interactable_object("game:%s" % duel_game_id)
	_clear_selected_game_action()
	var result := current_game.enter(run_state, run_state.current_environment)
	last_game_result = result.duplicate(true)
	var duel := run_state.grand_casino_duel_status()
	selected_stake = maxi(1, int(duel.get("ante", 20)))
	_show_message(str(result.get("message", "Rourke cuts the cards.")))
	_autosave_foundation_run("Duel autosaved.")
	_refresh()
	_refresh_stake_input()
	return true


func back_to_environment() -> void:
	if _resolve_pending_all_in_terminal_result():
		return
	if run_state != null and current_game != null and run_state.grand_casino_duel_active(run_state.current_environment):
		_show_message("Rourke keeps the Back Room door shut until the duel ends.")
		_refresh()
		return
	if _guard_blocking_decision_or_transition():
		return
	_sync_presented_bankroll_to_actual()
	_reset_game_surface_runtime_state()
	current_game = null
	last_game_result = {}
	_set_current_screen(SCREEN_ENVIRONMENT)
	_hide_event_choice_popup()
	_hide_run_inventory_popup()
	_hide_run_journal_popup()
	_hide_world_map_overlay()
	_hide_travel_transition()
	_clear_selected_game_action()
	_clear_selected_stake()
	clear_interaction_focus()
	_show_message("Choose a game, answer trouble, buy gear, or move on.")
	_refresh()


# Selects a GameModule action without mutating simulation state.
func select_game_action(action_id: String, action_kind: String) -> void:
	if current_game == null:
		_show_message("Enter a game before choosing an action.")
		return
	if _guard_player_input_route(false, "game_action:%s" % action_id):
		return
	var action := _available_game_action(action_id, action_kind)
	if action.is_empty():
		_show_message("Action is not available.")
		return
	selected_action_id = str(action.get("id", ""))
	selected_action_kind = action_kind
	selected_action_label = _action_label(action)
	_set_current_screen(SCREEN_GAME)
	_show_message("Selected %s action: %s." % [_action_kind_label(action_kind), selected_action_label])
	_refresh()


func _on_game_surface_action(action: String, index: int, confirm_requested: bool = false) -> void:
	if current_game == null:
		_show_message("Choose a game first.")
		_refresh()
		return
	if _guard_player_input_route(false, action):
		return
	if _surface_action_uses_game_binding(action):
		var bound_action := _current_game_bound_surface_action(action, index)
		if str(bound_action.get("action", action)) != action or int(bound_action.get("index", index)) != index:
			if _handle_module_surface_action(str(bound_action.get("action", action)), int(bound_action.get("index", index)), confirm_requested):
				return
	match action:
		"surface_back":
			back_to_environment()
			return
		"surface_stake_down":
			_adjust_surface_stake(-1)
			return
		"surface_stake_up":
			_adjust_surface_stake(1)
			return
		"surface_stake_max":
			_set_surface_stake_to_bound("max")
			return
	if _handle_module_surface_action(action, index, confirm_requested):
		return
	match action:
		"surface_legal":
			if _select_or_resolve_surface_game_action("legal", index, confirm_requested):
				return
		"surface_cheat":
			if _select_or_resolve_surface_game_action("cheat", index, confirm_requested):
				return
	if game_surface_canvas != null:
		game_surface_canvas.set_selected_index(index)
	_show_message("That part of the game is only visual right now.")
	_refresh()


func _surface_action_uses_game_binding(action: String) -> bool:
	return action == "surface_legal" \
		or action == "surface_cheat" \
		or action == "surface_stake_down" \
		or action == "surface_stake_up" \
		or action == "surface_stake_max"


func _current_game_bound_surface_action(action: String, index: int) -> Dictionary:
	if current_game == null or run_state == null:
		return {"action": action, "index": index}
	var surface_state := current_game.surface_state(run_state, run_state.current_environment, _current_game_surface_ui_state())
	var bindings: Dictionary = surface_state.get("surface_action_bindings", {}) if typeof(surface_state.get("surface_action_bindings", {})) == TYPE_DICTIONARY else {}
	var binding_value: Variant = bindings.get(action, {})
	if typeof(binding_value) != TYPE_DICTIONARY or (binding_value as Dictionary).is_empty():
		return {"action": action, "index": index}
	var binding: Dictionary = binding_value
	var resolved_action := str(binding.get("action", action))
	if resolved_action.is_empty():
		resolved_action = action
	return {
		"action": resolved_action,
		"index": int(binding.get("index", index)),
	}


func _on_game_surface_action_blocked(_action: String, reason: String) -> void:
	var message := reason.strip_edges()
	if message.is_empty():
		message = "That action is not available right now."
	_show_message(message)
	_refresh()


func _on_game_surface_pointer_action(action: String, index: int, phase: String, board_position: Vector2) -> void:
	if current_game == null or _guard_player_input_route(false, action):
		return
	var lightweight_state := current_game.surface_pointer_uses_lightweight_ui_state(action)
	var ui_state := game_surface_ui_state.duplicate(false) if lightweight_state else _current_game_surface_ui_state()
	ui_state["selected_action_id"] = selected_action_id
	ui_state["selected_action_kind"] = selected_action_kind
	ui_state["selected_stake"] = _current_selected_stake()
	var command := current_game.surface_pointer_command(action, index, phase, board_position, ui_state, run_state, run_state.current_environment)
	_apply_game_surface_command(command, index, false)


func _handle_module_surface_action(action: String, index: int, confirm_requested: bool) -> bool:
	if current_game == null:
		return false
	var ui_state := _current_game_surface_ui_state()
	ui_state["selected_action_id"] = selected_action_id
	ui_state["selected_action_kind"] = selected_action_kind
	ui_state["selected_stake"] = _current_selected_stake()
	var command := current_game.surface_action_command(action, index, confirm_requested, ui_state, run_state, run_state.current_environment)
	return _apply_game_surface_command(command, index, confirm_requested)


func _apply_game_surface_command(command: Dictionary, index: int = -1, confirm_requested: bool = false) -> bool:
	if command.is_empty() or not bool(command.get("handled", false)):
		return false
	if not game_surface_auto_resolving and _guard_player_input_route():
		return true
	if command.has("ui_state") and typeof(command.get("ui_state")) == TYPE_DICTIONARY:
		_store_current_game_surface_ui_state(command.get("ui_state", {}) as Dictionary, not bool(command.get("surface_transient", false)))
	if command.has("selected_index") and game_surface_canvas != null:
		game_surface_canvas.set_selected_index(int(command.get("selected_index", index)))
	if command.has("stake_multiplier"):
		var multiplied_stake := _current_selected_stake() * int(command.get("stake_multiplier", 1))
		set_selected_stake(multiplied_stake)
	if command.has("set_stake"):
		set_selected_stake(int(command.get("set_stake", _current_selected_stake())))
	_play_surface_command_audio(command, index)
	var environment_changed := bool(command.get("environment_changed", false))
	var action_id := str(command.get("action_id", ""))
	var action_kind := str(command.get("action_kind", ""))
	if bool(command.get("direct_resolve", false)) and not action_id.is_empty():
		_resolve_game_action(action_id, bool(command.get("skip_stake_validation", false)), bool(command.get("preserve_surface_ui_state", false)))
		return true
	if not action_id.is_empty() and not action_kind.is_empty():
		var already_selected := selected_action_id == action_id and selected_action_kind == action_kind
		if not already_selected:
			select_game_action(action_id, action_kind)
		if bool(command.get("resolve", false)) or confirm_requested or already_selected:
			_resolve_game_action(action_id, bool(command.get("skip_stake_validation", false)), bool(command.get("preserve_surface_ui_state", false)))
			return true
	elif command.has("message"):
		_show_message(str(command.get("message", "")))
	var surface_patch_value: Variant = command.get("surface_state_patch", {})
	if typeof(surface_patch_value) == TYPE_DICTIONARY and not (surface_patch_value as Dictionary).is_empty() and game_surface_canvas != null:
		game_surface_canvas.apply_surface_state_patch(surface_patch_value as Dictionary)
		return true
	if environment_changed:
		_autosave_foundation_run("Autosaved.")
	_refresh()
	return true


func _play_surface_command_audio(command: Dictionary, fallback_index: int) -> void:
	if game_surface_canvas == null:
		return
	var loop_stop := str(command.get("surface_audio_loop_stop", "")).strip_edges()
	if not loop_stop.is_empty():
		game_surface_canvas.surface_stop_audio_loop(loop_stop)
	var loop_start := str(command.get("surface_audio_loop_start", "")).strip_edges()
	if not loop_start.is_empty():
		game_surface_canvas.surface_start_audio_loop(loop_start, float(command.get("surface_audio_loop_volume_db", -10.0)), float(command.get("surface_audio_loop_pitch", 1.0)))
	var cue_id := str(command.get("surface_audio_cue", "")).strip_edges()
	if cue_id.is_empty():
		return
	var context: Dictionary = command.get("surface_audio_context", {}) if typeof(command.get("surface_audio_context", {})) == TYPE_DICTIONARY else {}
	context = context.duplicate(true)
	if not context.has("index"):
		context["index"] = int(command.get("selected_index", fallback_index))
	if not context.has("action"):
		context["action"] = str(command.get("surface_audio_action", ""))
	game_surface_canvas.surface_play_audio_cue(cue_id, context)


func _select_or_resolve_surface_game_action(action_kind: String, index: int, confirm_requested: bool) -> bool:
	var actions := _game_action_view_list(action_kind)
	if index < 0 or index >= actions.size():
		_show_message("That action is not available.")
		_refresh()
		return false
	var action: Dictionary = actions[index]
	var action_id := str(action.get("id", ""))
	if action_id.is_empty():
		_show_message("That action is not available.")
		_refresh()
		return false
	if game_surface_canvas != null:
		game_surface_canvas.set_selected_index(index)
	var already_selected := selected_action_id == action_id and selected_action_kind == action_kind
	if already_selected or confirm_requested:
		if not already_selected:
			select_game_action(action_id, action_kind)
		_resolve_game_action(action_id)
		return true
	select_game_action(action_id, action_kind)
	return true


func _adjust_surface_stake(delta: int) -> bool:
	var current_stake := _current_selected_stake()
	var changed := set_selected_stake(current_stake + delta)
	_refresh()
	return changed


func _set_surface_stake_to_bound(bound_name: String) -> bool:
	var range := _stake_range()
	if not bool(range.get("has_valid", false)):
		_show_message("No valid stake is available.")
		_refresh()
		return false
	var stake := int(range.get(bound_name, range.get("default", 1)))
	var changed := set_selected_stake(stake)
	_refresh()
	return changed


func _advance_game_surface_automation() -> void:
	if game_surface_auto_resolving or run_state == null or current_game == null:
		return
	if _modal_contract_blocks_player_input():
		return
	var tick_state := _current_game_surface_auto_tick_state()
	if not current_game.surface_needs_auto_tick(tick_state, run_state, run_state.current_environment):
		return
	var ui_state := _current_game_surface_ui_state()
	if not current_game.surface_needs_auto_tick(ui_state, run_state, run_state.current_environment):
		return
	var command := current_game.surface_auto_action_command(ui_state, run_state, run_state.current_environment, _current_game_surface_status())
	if command.is_empty() or not bool(command.get("handled", false)):
		return
	game_surface_auto_resolving = true
	_apply_game_surface_command(command, -1, false)
	game_surface_auto_resolving = false


func _advance_game_surface_realtime_state() -> void:
	if game_surface_auto_resolving or run_state == null or current_game == null or game_surface_canvas == null:
		return
	if _modal_contract_blocks_player_input():
		return
	if current_screen != SCREEN_GAME or not game_surface_canvas.visible or not game_surface_canvas.is_visible_in_tree():
		return
	if not game_surface_canvas.surface_realtime_state_refresh_enabled():
		return
	var now_msec := Time.get_ticks_msec()
	if last_game_surface_realtime_refresh_msec > 0 and now_msec - last_game_surface_realtime_refresh_msec < GAME_SURFACE_REALTIME_REFRESH_INTERVAL_MSEC:
		return
	last_game_surface_realtime_refresh_msec = now_msec
	var patch := _game_surface_realtime_state_patch(now_msec)
	if patch.is_empty():
		return
	game_surface_canvas.apply_surface_state_patch(patch)


func _advance_presented_bankroll() -> void:
	if not presented_bankroll_hold_active:
		return
	if run_state == null:
		_clear_presented_bankroll_hold()
		return
	if current_screen != SCREEN_GAME or current_game == null:
		_sync_presented_bankroll_to_actual()
		_refresh_runtime_environment_views()
		return
	if not _game_surface_presentation_active():
		_sync_presented_bankroll_to_actual()
		_refresh_runtime_environment_views()


func _presented_bankroll() -> int:
	if run_state == null:
		return 0
	if presented_bankroll_hold_active:
		return presented_bankroll_value
	return run_state.bankroll


func _visible_recent_bankroll_delta(bankroll_delta: int) -> int:
	return 0 if presented_bankroll_hold_active else bankroll_delta


func _begin_presented_bankroll_hold(result: Dictionary, before_bankroll: int, wager_cost: int) -> void:
	_clear_presented_bankroll_hold()
	if run_state == null or current_game == null:
		return
	if not bool(result.get("ok", false)):
		return
	var deltas: Dictionary = result.get("deltas", {}) if typeof(result.get("deltas", {})) == TYPE_DICTIONARY else {}
	var bankroll_delta := int(result.get("bankroll_delta", deltas.get("bankroll_delta", 0)))
	if bankroll_delta == 0:
		return
	if not _result_uses_game_bankroll_presentation(result):
		return
	var stake_cost := maxi(wager_cost, int(result.get("stake", 0)))
	presented_bankroll_hold_active = true
	presented_bankroll_value = maxi(0, before_bankroll - maxi(0, stake_cost))
	presented_bankroll_game_id = current_game.get_id()
	presented_bankroll_action_id = str(result.get("action_id", ""))
	presented_bankroll_release_screen = SCREEN_GAME
	presented_bankroll_started_msec = Time.get_ticks_msec()


func _result_uses_game_bankroll_presentation(result: Dictionary) -> bool:
	if current_game == null:
		return false
	var result_game_id := str(result.get("game_id", result.get("source_id", "")))
	if not result_game_id.is_empty() and result_game_id != current_game.get_id():
		return false
	return bool(result.get("surface_embeds_outcomes", false)) or _current_game_embeds_result_feedback()


func _sync_presented_bankroll_to_actual() -> void:
	if run_state != null:
		presented_bankroll_value = run_state.bankroll
	_clear_presented_bankroll_hold()


func _clear_presented_bankroll_hold() -> void:
	presented_bankroll_hold_active = false
	presented_bankroll_game_id = ""
	presented_bankroll_action_id = ""
	presented_bankroll_release_screen = ""
	presented_bankroll_started_msec = 0


func _game_surface_presentation_active() -> bool:
	if game_surface_canvas == null:
		return false
	var status := game_surface_canvas.surface_runtime_status()
	var animations: Dictionary = status.get("surface_animations", {}) if typeof(status.get("surface_animations", {})) == TYPE_DICTIONARY else {}
	for animation_id in animations.keys():
		var animation_value: Variant = animations.get(animation_id)
		if typeof(animation_value) != TYPE_DICTIONARY:
			continue
		var animation: Dictionary = animation_value
		if bool(animation.get("active", false)):
			return true
	return bool(status.get("surface_animation_handoff_active", false))


func _advance_environment_game_runtime() -> void:
	if game_surface_auto_resolving or run_state == null or library == null or run_state.is_terminal():
		return
	if (current_screen != SCREEN_ENVIRONMENT and current_screen != SCREEN_GAME) or meta_session_active:
		return
	if _foreground_game_blocks_environment_runtime():
		return
	if _modal_contract_blocks_player_input():
		return
	var now_msec := Time.get_ticks_msec()
	var scanned := _advance_environment_game_runtime_for_environment(run_state.current_environment, now_msec)
	if run_state.is_terminal() or _modal_contract_blocks_player_input():
		return
	scanned = _advance_grand_casino_stored_main_floor_slot_runtime(now_msec) or scanned
	if scanned:
		environment_game_runtime_scan_count += 1


func _advance_environment_game_runtime_for_environment(environment_data: Dictionary, now_msec: int, game_ids_override: Array = []) -> bool:
	var game_ids_value: Variant = game_ids_override if not game_ids_override.is_empty() else environment_data.get("game_ids", [])
	if typeof(game_ids_value) != TYPE_ARRAY or (game_ids_value as Array).is_empty():
		return false
	var current_environment_id := str(run_state.current_environment.get("id", ""))
	var environment_id := str(environment_data.get("id", ""))
	var same_environment := current_environment_id == environment_id
	var current_game_id := current_game.get_id() if current_game != null else ""
	var has_runtime_candidate := false
	for candidate_value in game_ids_value as Array:
		var candidate_id := str(candidate_value)
		if candidate_id.is_empty() or (same_environment and candidate_id == current_game_id):
			continue
		has_runtime_candidate = true
		break
	if not has_runtime_candidate:
		return false
	var original_active_game_state_keys := _copy_dict(environment_data.get("active_game_state_keys", {}))
	for game_id_value in game_ids_value as Array:
		var game_id := str(game_id_value)
		if game_id.is_empty():
			continue
		if same_environment and current_game != null and game_id == current_game.get_id():
			continue
		var game := _game_module_for_id(game_id)
		if game == null:
			continue
		for state_key in _environment_runtime_state_keys(environment_data, game_id):
			_set_environment_active_game_state_key(environment_data, game_id, state_key)
			if not game.environment_runtime_needs_tick(run_state, environment_data, now_msec):
				continue
			var runtime_wager_cost := maxi(0, game.wager_cost_for_context("spin", 0, run_state, environment_data, {}))
			if _wager_needs_final_bankroll_confirmation(game, "spin", 0, runtime_wager_cost, {}, environment_data):
				_pause_environment_runtime_for_wager_confirmation(game, game_id, environment_data)
				_show_wager_confirmation_popup("spin", runtime_wager_cost, runtime_wager_cost, true, false, game_id)
				_show_message("%s autoplay needs your approval before risking your last cash." % game.get_display_name())
				_restore_environment_active_game_state_keys(environment_data, original_active_game_state_keys)
				_refresh_runtime_environment_views()
				return true
			var rng := run_state.create_rng()
			var command := game.environment_runtime_tick(run_state, environment_data, rng, now_msec)
			if command.is_empty() or not bool(command.get("handled", false)):
				continue
			var audio_cue := str(command.get("audio_cue", ""))
			if not audio_cue.is_empty():
				_play_environment_audio_cue(audio_cue, float(command.get("audio_cue_volume_db", -1.0)))
			var result: Dictionary = command.get("result", {})
			if not result.is_empty():
				if bool(result.get("ok", false)):
					run_state.advance_environment_turns(1)
					if bool(result.get("host_apply_result", false)):
						GameModule.apply_result(run_state, result, rng)
					_evaluate_run_terminal_state()
					if run_state.is_terminal():
						_restore_environment_active_game_state_keys(environment_data, original_active_game_state_keys)
						_render_environment_screen()
						return true
				last_environment_runtime_result = result.duplicate(true)
				if current_game == null:
					last_game_result = result.duplicate(true)
					last_item_result = {}
					last_hook_result = {}
					_show_message(str(result.get("message", "")))
				elif bool(command.get("attention", false)) or bool(result.get("slot_pending_feature", false)):
					_show_message(str(result.get("message", command.get("message", ""))))
				_advance_alcohol_absorption()
				_autosave_foundation_run("Autosaved.")
			elif command.has("message"):
				_show_message(str(command.get("message", "")))
				_refresh_runtime_environment_views()
	_restore_environment_active_game_state_keys(environment_data, original_active_game_state_keys)
	return true


func _advance_grand_casino_stored_main_floor_slot_runtime(now_msec: int) -> bool:
	var current_archetype_id := str(run_state.current_environment.get("archetype_id", "")).strip_edges()
	if current_archetype_id == RunState.GRAND_CASINO_ARCHETYPE_ID or not RunState.GRAND_CASINO_ARCHETYPE_IDS.has(current_archetype_id):
		return false
	var main_floor := run_state.grand_casino_room_environment(RunState.GRAND_CASINO_ARCHETYPE_ID)
	var main_floor_slot_id := _main_floor_slot_game_id()
	if main_floor_slot_id.is_empty() or main_floor.is_empty() or not _string_array(main_floor.get("game_ids", [])).has(main_floor_slot_id):
		return false
	var scanned := _advance_environment_game_runtime_for_environment(main_floor, now_msec, [main_floor_slot_id])
	if scanned:
		run_state.store_grand_casino_room_environment(main_floor)
	return scanned


func _main_floor_slot_game_id() -> String:
	if library == null:
		return ""
	for game_value in library.games:
		var game_def := _copy_dict(game_value)
		if str(game_def.get("module_path", "")).ends_with("scripts/games/slot.gd"):
			return str(game_def.get("id", "")).strip_edges()
	return ""


func _environment_runtime_state_keys(environment_data: Dictionary, game_id: String) -> Array:
	var result: Array = [game_id]
	var layout := _copy_dict(environment_data.get("layout", {}))
	var fixture_counts := _copy_dict(layout.get("game_fixture_counts", {}))
	var fixture_count := maxi(1, int(fixture_counts.get(game_id, 1)))
	for fixture_index in range(1, fixture_count):
		result.append("%s:%d" % [game_id, fixture_index + 1])
	var game_states := _copy_dict(environment_data.get("game_states", {}))
	for key_value in game_states.keys():
		var key := str(key_value)
		if key.begins_with("%s:" % game_id) and not result.has(key):
			result.append(key)
	return result


func _set_environment_active_game_state_key(environment_data: Dictionary, game_id: String, state_key: String) -> void:
	var active_keys := _copy_dict(environment_data.get("active_game_state_keys", {}))
	active_keys[game_id] = state_key
	environment_data["active_game_state_keys"] = active_keys


func _restore_environment_active_game_state_keys(environment_data: Dictionary, active_keys: Dictionary) -> void:
	if active_keys.is_empty():
		environment_data.erase("active_game_state_keys")
	else:
		environment_data["active_game_state_keys"] = active_keys.duplicate(true)


func _foreground_game_blocks_environment_runtime() -> bool:
	if current_game == null:
		return false
	if current_game.get_family() != "cards":
		return false
	var ui_state := _current_game_surface_ui_state()
	var hands: Array = ui_state.get("player_hands", []) if typeof(ui_state.get("player_hands", [])) == TYPE_ARRAY else []
	var dealer_cards: Array = ui_state.get("dealer_cards", []) if typeof(ui_state.get("dealer_cards", [])) == TYPE_ARRAY else []
	if hands.is_empty() or dealer_cards.is_empty():
		return false
	return not bool(ui_state.get("round_complete", false))


func _advance_alcohol_absorption() -> void:
	if run_state == null or run_state.is_terminal():
		return
	var progress := run_state.update_drunk_absorption()
	if int(progress.get("applied", 0)) <= 0:
		return
	_refresh_runtime_environment_views()
	_render_foundation_snapshots()


func _refresh_runtime_environment_views() -> void:
	_evaluate_run_terminal_state()
	_refresh_world_header()
	if status_label != null:
		status_label.text = _hud_status_text()
	if objective_label != null:
		objective_label.text = _objective_hud_text()
	if save_status_label != null:
		save_status_label.text = _save_status_text()
	_style_hud_for_recent_consequence()
	_refresh_environment_result_feedback()
	_render_run_report()
	_render_result_panel()
	_render_foundation_snapshots()


func _current_game_surface_status() -> Dictionary:
	if game_surface_canvas == null:
		return {}
	return game_surface_canvas.surface_runtime_status()


func _current_game_surface_auto_tick_state() -> Dictionary:
	var ui_state: Dictionary = {
		"selected_action_id": selected_action_id,
		"selected_action_kind": selected_action_kind,
		"selected_stake": _current_selected_stake(),
	}
	# Read-only live references avoid the per-frame deep copy; action paths still
	# rebuild the canonical ui_state before mutating or resolving anything.
	var auto_tick_keys: Array = current_game.surface_auto_tick_state_keys() if current_game != null else []
	for key_value in auto_tick_keys:
		var key := str(key_value)
		if not key.is_empty() and game_surface_ui_state.has(key):
			ui_state[key] = game_surface_ui_state[key]
	return _apply_game_surface_time_fields(ui_state)


func _current_game_surface_realtime_ui_state(now_msec: int) -> Dictionary:
	var ui_state := game_surface_ui_state.duplicate(false)
	ui_state["selected_action_id"] = selected_action_id
	ui_state["selected_action_kind"] = selected_action_kind
	ui_state["selected_stake"] = _current_selected_stake()
	ui_state["surface_runtime_status"] = game_surface_canvas.surface_realtime_ui_status() if game_surface_canvas != null else {}
	ui_state["focused_talk_speaker"] = _focused_talk_speaker_snapshot()
	return _apply_game_surface_time_fields(ui_state, now_msec)


func _game_surface_realtime_state_patch(now_msec: int) -> Dictionary:
	if current_game == null or run_state == null or game_surface_canvas == null:
		return {}
	var ui_state := _current_game_surface_realtime_ui_state(now_msec)
	if current_game.has_method("surface_realtime_state_patch"):
		var module_patch: Variant = current_game.surface_realtime_state_patch(run_state, run_state.current_environment, ui_state, game_surface_canvas.realtime_surface_state())
		if typeof(module_patch) == TYPE_DICTIONARY:
			var typed_patch: Dictionary = module_patch
			_augment_game_surface_realtime_patch(typed_patch, ui_state)
			return typed_patch
	var module_surface_state: Variant = current_game.surface_state(run_state, run_state.current_environment, ui_state)
	if typeof(module_surface_state) != TYPE_DICTIONARY:
		return {}
	var patch: Dictionary = module_surface_state
	_augment_game_surface_realtime_patch(patch, ui_state)
	return patch


func _augment_game_surface_realtime_patch(patch: Dictionary, ui_state: Dictionary) -> void:
	_sync_surface_feature_music_state(patch)
	if patch.has("surface_renderer"):
		var surface_renderer := str(patch.get("surface_renderer", ""))
		patch["surface_life"] = str(patch.get("surface_life", _surface_life_for_renderer(surface_renderer)))
		patch["surface_cast"] = str(patch.get("surface_cast", _surface_cast_for_renderer(surface_renderer)))
	patch["bankroll"] = _presented_bankroll()
	patch["suspicion_level"] = run_state.suspicion_level()
	patch["drunk_level"] = run_state.drunk_level
	patch["drunk_time_scale"] = float(ui_state.get("drunk_time_scale", _current_drunk_time_scale()))
	patch["drunk_time_scale_percent"] = int(ui_state.get("drunk_time_scale_percent", 100))
	patch["drunk_world_speed_percent"] = int(ui_state.get("drunk_world_speed_percent", 100))
	patch["pending_drunk_absorption"] = run_state.pending_drunk_absorption_amount()
	patch["drunk_distortion_suppression_turns"] = run_state.drunk_distortion_suppression_turns
	patch["drunk_effect_mode"] = _drunk_effect_mode()
	patch["reduce_motion"] = _reduce_motion_enabled()
	patch["selected_action_id"] = selected_action_id
	patch["selected_action_kind"] = selected_action_kind
	patch["selected_action_label"] = selected_action_label
	patch["selected_stake"] = int(ui_state.get("selected_stake", _current_selected_stake()))


func _checkpoint_current_game_surface_ui_state() -> void:
	if current_game != null and run_state != null and not run_state.current_environment.is_empty() and not game_surface_ui_state.is_empty():
		current_game.checkpoint_surface_ui_state(game_surface_ui_state, run_state, run_state.current_environment)


func _reset_game_surface_runtime_state() -> void:
	_checkpoint_current_game_surface_ui_state()
	if game_surface_canvas != null:
		game_surface_canvas.clear_runtime_state()
	_stop_surface_feature_music()
	game_surface_ui_state = {}
	game_surface_auto_resolving = false
	last_game_surface_realtime_refresh_msec = 0
	_reset_drunk_time_surface_clock()


func _reset_drunk_time_surface_clock() -> void:
	drunk_time_anchor_real_msec = 0
	drunk_time_anchor_scaled_msec = 0
	drunk_time_last_scale = 1.0


func _current_drunk_time_scale() -> float:
	if run_state == null:
		return 1.0
	return clampf(run_state.drunk_time_scale(), RunState.DRUNK_TIME_SCALE_MIN, 1.0)


func _apply_game_surface_time_fields(ui_state: Dictionary, real_time_msec: int = -1) -> Dictionary:
	var now_msec := Time.get_ticks_msec() if real_time_msec < 0 else real_time_msec
	var time_scale := _current_drunk_time_scale()
	var speed_percent := clampi(int(round(time_scale * 100.0)), int(round(RunState.DRUNK_TIME_SCALE_MIN * 100.0)), 100)
	ui_state["surface_time_msec"] = now_msec
	ui_state["drunk_time_scale"] = time_scale
	ui_state["drunk_time_scale_percent"] = speed_percent
	ui_state["drunk_world_speed_percent"] = speed_percent
	ui_state["drunk_scaled_surface_time_msec"] = _drunk_scaled_surface_time_msec(now_msec, time_scale)
	return ui_state


func _drunk_scaled_surface_time_msec(real_time_msec: int = -1, scale_value: float = -1.0) -> int:
	var now_msec := Time.get_ticks_msec() if real_time_msec < 0 else real_time_msec
	var time_scale := clampf(scale_value if scale_value > 0.0 else _current_drunk_time_scale(), RunState.DRUNK_TIME_SCALE_MIN, 1.0)
	if drunk_time_anchor_real_msec <= 0:
		drunk_time_anchor_real_msec = now_msec
		drunk_time_anchor_scaled_msec = now_msec
		drunk_time_last_scale = time_scale
	if absf(time_scale - drunk_time_last_scale) > 0.001:
		drunk_time_anchor_scaled_msec += int(round(float(maxi(0, now_msec - drunk_time_anchor_real_msec)) * drunk_time_last_scale))
		drunk_time_anchor_real_msec = now_msec
		drunk_time_last_scale = time_scale
	return drunk_time_anchor_scaled_msec + int(round(float(maxi(0, now_msec - drunk_time_anchor_real_msec)) * time_scale))


# Resolves the currently selected GameModule action.
func resolve_selected_game_action() -> void:
	if selected_action_id.is_empty():
		_show_message("Select a game action first.")
		return
	if _guard_player_input_route(false, "game_action:%s" % selected_action_id):
		return
	_resolve_game_action(selected_action_id)


# Selects a stake as UI-local input without mutating simulation state.
func set_selected_stake(stake: int) -> bool:
	if _guard_player_input_route():
		return false
	var range := _stake_range()
	if not bool(range.get("has_valid", false)):
		_show_message("No valid stake is available.")
		_refresh_stake_input()
		return false
	var min_stake := int(range.get("min", 1))
	var max_stake := int(range.get("max", min_stake))
	if stake < min_stake or stake > max_stake:
		_show_message("Stake must be between %d and %d." % [min_stake, max_stake])
		_refresh_stake_input()
		return false
	selected_stake = stake
	_show_message("Stake set to %d." % selected_stake)
	_refresh_stake_input()
	return true


# Selects a travel destination/hook without mutating simulation state.
func select_travel_option(target_id: String) -> bool:
	if _guard_player_input_route():
		return false
	var choice := _travel_choice(target_id)
	if choice.is_empty():
		_show_message("Travel option is not available.")
		return false
	selected_action_category = ACTION_CATEGORY_TRAVEL
	_set_current_screen(SCREEN_TRAVEL)
	var choice_target_id := str(choice.get("id", ""))
	focus_interactable_object("travel:leave")
	selected_world_map_node_id = choice_target_id
	if not bool(choice.get("enabled", true)):
		_show_message(str(choice.get("disabled_reason", "That route is not available right now.")))
		_refresh_world_map_overlay()
		_refresh()
		return false
	selected_travel_target_id = choice_target_id
	selected_travel_label = str(choice.get("label", selected_travel_target_id))
	_show_message("Selected travel: %s." % selected_travel_label)
	_refresh_world_map_overlay()
	_refresh()
	return true


# Confirms the selected travel destination through RunGenerator.
func confirm_selected_travel() -> void:
	if run_state == null:
		return
	if _guard_player_input_route(_closing_time_blocks_environment_actions()):
		return
	if selected_travel_target_id.is_empty():
		_show_message("Select a travel destination first.")
		return
	var choice := _travel_choice(selected_travel_target_id)
	if travel_transition_active:
		_show_message("Travel is already in progress.")
		return
	if choice.is_empty():
		_show_message("Travel option is not available.")
		_clear_selected_travel()
		_refresh()
		return
	if not bool(choice.get("enabled", true)):
		_show_message(str(choice.get("disabled_reason", "That route is not available right now.")))
		_refresh()
		return
	_travel_to(str(choice.get("id", "")), str(choice.get("label", choice.get("id", ""))), choice)


func open_world_map(force_closing_allowed: bool = false) -> bool:
	if run_state == null:
		return false
	if _guard_player_input_route(force_closing_allowed, "map"):
		return false
	selected_action_category = ACTION_CATEGORY_TRAVEL
	_set_current_screen(SCREEN_TRAVEL)
	_clear_world_map_selection(false)
	if world_map_overlay != null:
		world_map_overlay.visible = true
		world_map_overlay.move_to_front()
	_request_world_map_button_relayout()
	_refresh()
	return true


func _prewarm_world_map_overlay_for_run() -> void:
	if run_state == null or world_map_overlay == null:
		return
	if not run_state.has_world_map() and not _is_meta_session():
		return
	var was_visible := world_map_overlay.visible
	_clear_world_map_selection(false)
	world_map_overlay.visible = true
	_refresh_world_map_overlay()
	_set_world_map_detail_badges(_world_map_detail_badge_prewarm_sample())
	_set_world_map_detail_badges([])
	world_map_overlay.visible = was_visible


func close_world_map() -> void:
	_clear_world_map_selection(false)
	if world_map_overlay != null:
		world_map_overlay.visible = false
	if current_screen == SCREEN_TRAVEL:
		_set_current_screen(SCREEN_ENVIRONMENT)
		_refresh()


func _hide_world_map_overlay() -> void:
	_clear_world_map_selection(false)
	if world_map_overlay != null:
		world_map_overlay.visible = false


func _clear_world_map_selection(refresh_overlay: bool = true) -> void:
	_ensure_world_map_overlay_controller()
	world_map_overlay_controller.clear_selection()
	_sync_world_map_overlay_controller_to_host()
	if refresh_overlay:
		_refresh_world_map_overlay()


func select_world_map_node(node_id: String) -> bool:
	if _guard_blocking_decision_or_transition():
		return false
	var clean_id := node_id.strip_edges()
	if clean_id.is_empty():
		return false
	_sync_world_map_overlay_controller_from_host()
	if _is_meta_session():
		return _select_meta_world_map_node(clean_id)
	if run_state != null and run_state.has_world_map() and not WorldMapScript.is_node_visible(run_state.world_map, clean_id):
		_show_message("That stop is not on your map yet.")
		_refresh_world_map_overlay()
		return false
	var choice := _travel_choice(clean_id)
	var current_node_id := run_state.current_world_node_id() if run_state != null else ""
	var visible_node_ids := _world_map_node_ids(_world_map_snapshot())
	if not choice.is_empty() and not visible_node_ids.has(clean_id):
		visible_node_ids.append(clean_id)
	var result := world_map_overlay_controller.select_run_node(clean_id, current_node_id, visible_node_ids, choice)
	_sync_world_map_overlay_controller_to_host()
	var message := str(result.get("message", ""))
	if not message.is_empty():
		_show_message(message)
	if bool(result.get("refresh", false)):
		_refresh_world_map_overlay()
	return bool(result.get("ok", false))


func confirm_world_map_travel() -> void:
	if _guard_blocking_decision_or_transition():
		return
	_sync_world_map_overlay_controller_from_host()
	var confirmed_target_id := selected_world_map_node_id
	if confirmed_target_id.is_empty() and not selected_travel_target_id.is_empty():
		confirmed_target_id = selected_travel_target_id
	if confirmed_target_id.is_empty():
		_show_message("Select a map stop first.")
		return
	if _is_meta_session():
		_confirm_meta_world_map_travel()
		return
	var coach_travel_action := "travel:%s" % confirmed_target_id
	if coach_overlay != null and not coach_overlay.input_allowed(coach_travel_action):
		_show_message("Follow the highlighted advice first.")
		return
	var choice := _travel_choice(confirmed_target_id)
	var result := world_map_overlay_controller.confirm_run_selection(choice)
	_sync_world_map_overlay_controller_to_host()
	if str(result.get("action", "")) != "travel":
		var message := str(result.get("message", ""))
		if not message.is_empty():
			_show_message(message)
		if bool(result.get("refresh", false)):
			_refresh_world_map_overlay()
		return
	if world_map_overlay != null:
		world_map_overlay.visible = false
	if coach_overlay != null:
		coach_overlay.notify_action(coach_travel_action)
	_travel_to(str(result.get("target_id", "")), str(result.get("label", result.get("target_id", ""))), result.get("choice", {}) as Dictionary)


func _select_meta_world_map_node(node_id: String) -> bool:
	var choice := _meta_travel_choice(node_id)
	var result := world_map_overlay_controller.select_meta_node(node_id, meta_session_location_id, _meta_map_node_ids(), choice)
	_sync_world_map_overlay_controller_to_host()
	var message := str(result.get("message", ""))
	if not message.is_empty():
		_show_message(message)
	if bool(result.get("refresh", false)):
		_refresh_world_map_overlay()
	return bool(result.get("ok", false))


func _confirm_meta_world_map_travel() -> void:
	var choice := _meta_travel_choice(selected_world_map_node_id)
	var result := world_map_overlay_controller.confirm_meta_selection(meta_session_location_id, choice)
	_sync_world_map_overlay_controller_to_host()
	if str(result.get("action", "")) != "meta_travel":
		var message := str(result.get("message", ""))
		if not message.is_empty():
			_show_message(message)
		if bool(result.get("refresh", false)):
			_refresh_world_map_overlay()
		return
	if world_map_overlay != null:
		world_map_overlay.visible = false
	var target_id := str(result.get("target_id", META_LOCATION_HOME))
	if target_id == META_LOCATION_START_RUN:
		start_meta_quick_run()
		return
	_enter_meta_location(target_id)


# Selects an event choice without mutating simulation state.
func select_event_choice(event_id: String, choice_id: String) -> bool:
	if _guard_player_input_route():
		return false
	var event_option := _eligible_event_option(event_id)
	if event_option.is_empty():
		_show_message("Event is not available.")
		return false
	var choice := _event_choice(event_option, choice_id)
	if choice.is_empty():
		_show_message("Event choice is not available.")
		return false
	selected_event_id = event_id
	selected_event_choice_id = choice_id
	selected_event_label = str(event_option.get("display_name", event_id))
	selected_event_choice_label = str(choice.get("label", choice_id))
	selected_action_category = ACTION_CATEGORY_EVENTS
	_set_current_screen(SCREEN_EVENT)
	focus_interactable_object("event:%s" % selected_event_id)
	_show_message("Selected event choice: %s." % selected_event_choice_label)
	_refresh()
	return true


# Resolves the selected event choice through EventModule.
func confirm_selected_event_choice() -> void:
	if selected_event_id.is_empty() or selected_event_choice_id.is_empty():
		_show_message("Select an event choice first.")
		return
	resolve_event_choice(selected_event_id, selected_event_choice_id)


# Resolves one selected event choice through EventModule.
func resolve_event_choice(event_id: String, choice_id: String) -> void:
	if travel_transition_active:
		_show_message("Travel is already in progress.")
		_refresh_modal_contract_owner()
		return
	if _event_choice_popup_is_visible() and not _event_choice_popup_allows_event_resolution(event_id):
		_show_message("Finish the current prompt first.")
		_refresh_modal_contract_owner()
		return
	var talk_entry := _pending_talk_event_entry(event_id)
	if not _event_choice_popup_is_visible() and not talk_entry.is_empty() and not str(talk_entry.get("dialogue_id", "")).strip_edges().is_empty():
		_resolve_dialogue_choice(talk_entry, choice_id)
		return
	var resolving_talk := not _event_choice_popup_is_visible() and not talk_entry.is_empty()
	if not _event_choice_popup_is_visible() and not resolving_talk and _guard_player_input_route():
		return
	var event_definition := library.event(event_id)
	if event_definition.is_empty():
		_show_message("Event definition is missing.")
		return
	var event_module := EventModule.new()
	event_module.setup(event_definition, library)
	var event_context := _pending_event_trigger_context(event_id)
	if resolving_talk:
		event_context = _copy_dict(talk_entry.get("context", {}))
	var event_environment := _event_environment_for_context(event_context)
	if not event_module.can_trigger(run_state, event_environment, event_context):
		_show_message("Event cannot trigger right now.")
		if resolving_talk and run_state != null:
			run_state.complete_talk_event_resolution(event_id)
			_refresh_talk_dock()
		return
	var popup_rect := _talk_dock_panel_rect() if resolving_talk else event_choice_popup_panel.get_global_rect() if event_choice_popup_panel != null else Rect2()
	var had_event_popup := bool(pending_event_choice_popup_snapshot.get("visible", false))
	var popup_type := str(pending_event_choice_popup_snapshot.get("popup_type", ""))
	var was_triggered_popup := popup_type == "triggered_event"
	var return_to_game_after_event := _event_resolution_returns_to_active_game(popup_type, event_context)
	var inventory_before := _run_inventory_id_set()
	var result := event_module.resolve(run_state, event_environment, choice_id)
	var showdown_continues := (
		event_id == RunState.GRAND_CASINO_SHOWDOWN_EVENT_ID
		and run_state != null
		and bool(run_state.narrative_flags.get("grand_casino_showdown_active", false))
		and not run_state.is_terminal()
	)
	_show_item_found_popups(result, inventory_before)
	_start_conclusion_animation(result, popup_rect)
	_play_result_drink_audio_cue(result)
	if was_triggered_popup and run_state != null:
		run_state.complete_triggered_event_resolution(event_id)
	if resolving_talk and run_state != null:
		run_state.complete_talk_event_resolution(event_id)
	if had_event_popup and run_state != null:
		run_state.event_cadence_note_modal_closed()
	_hide_event_choice_popup()
	_clear_selected_event_choice()
	_show_message(str(result.get("message", "")))
	_advance_alcohol_absorption()
	_autosave_foundation_run("Autosaved.")
	_refresh_talk_dock()
	if bool(result.get("duel_ready", false)):
		if not _enter_grand_casino_duel_surface():
			_show_message("Rourke's Back Room table could not open.")
			_refresh()
		return
	if showdown_continues:
		_set_current_screen(SCREEN_EVENT)
		_refresh()
		if not _show_interactable_event_popup(event_id):
			_show_message("Rourke's next showdown beat could not open.")
		return
	if bool(result.get("ok", false)) and _apply_post_action_environment_interrupt("event"):
		_refresh()
		return
	if resolving_talk:
		_refresh()
		return
	_hide_run_inventory_popup()
	_hide_run_journal_popup()
	if return_to_game_after_event and run_state != null and not run_state.is_terminal():
		_set_current_screen(SCREEN_GAME)
	else:
		_set_current_screen(SCREEN_RESULT)
	_refresh()


func _event_resolution_returns_to_active_game(popup_type: String, event_context: Dictionary) -> bool:
	if current_game == null:
		return false
	if not ["triggered_event", "unavoidable_event"].has(popup_type):
		return false
	var source := str(event_context.get("source", "")).strip_edges().to_lower()
	return ["game_action", "game_hook"].has(source)


func _on_talk_dock_choice_requested(event_id: String, choice_id: String) -> void:
	if event_id == CLOSING_TIME_TALK_EVENT_ID:
		_acknowledge_closing_time_talk(choice_id)
		return
	if _talk_choice_is_ignore(choice_id) and _ignore_talk_event(event_id, "choice"):
		_refresh()
		return
	resolve_event_choice(event_id, choice_id)


func _apply_post_action_environment_interrupt(source: String) -> bool:
	if run_state == null or library == null or run_state.is_terminal():
		return false
	if _advance_talk_event_action_boundary(source):
		return true
	if _apply_closing_time_action_boundary(source):
		return true
	if _apply_forced_environment_travel(source):
		return true
	if _enqueue_talk_events_for_action_boundary(source):
		_autosave_foundation_run("Autosaved.")
		_refresh_talk_dock()
		return true
	return _maybe_trigger_unavoidable_event(source)


func _apply_closing_time_action_boundary(_source: String) -> bool:
	if run_state == null or library == null or run_state.current_environment.is_empty():
		return false
	var current_archetype := _current_environment_archetype()
	var open_status := _environment_open_status(current_archetype)
	var closing_matches_current := _closing_time_state_matches_current_environment()
	if bool(open_status.get("open", true)):
		if closing_matches_current:
			run_state.clear_closing_time_state()
		return false
	if _current_wager_activity_incomplete():
		if not run_state.closing_time_active() or not closing_matches_current:
			var deferred := run_state.begin_closing_time(run_state.current_environment, run_state.game_minute_of_day())
			run_state.log_story({
				"type": "closing_time",
				"environment_id": str(run_state.current_environment.get("id", "")),
				"environment_archetype_id": str(run_state.current_environment.get("archetype_id", "")),
				"game_clock_minutes": run_state.game_clock_minutes,
				"message": str(deferred.get("message", "The venue is closing.")),
			})
			_show_message("Closing time. Finish the wager already in progress.")
		_invalidate_travel_view_cache()
		return false
	if run_state.closing_time_forced_travel_required() and closing_matches_current:
		_ensure_closing_time_departure_talk()
		return true
	if run_state.closing_time_active() and closing_matches_current:
		var spent := run_state.spend_closing_time_grace_action()
		_show_message(str(spent.get("message", _closing_time_disabled_reason())))
		if run_state.closing_time_forced_travel_required():
			_ensure_closing_time_departure_talk()
			return true
		_invalidate_travel_view_cache()
		return false
	var started := run_state.begin_closing_time(run_state.current_environment, run_state.game_minute_of_day())
	run_state.log_story({
		"type": "closing_time",
		"environment_id": str(run_state.current_environment.get("id", "")),
		"environment_archetype_id": str(run_state.current_environment.get("archetype_id", "")),
		"game_clock_minutes": run_state.game_clock_minutes,
		"message": str(started.get("message", "The venue is closing.")),
	})
	_show_message(str(started.get("message", "The venue is closing.")))
	_invalidate_travel_view_cache()
	return false


func _current_wager_activity_incomplete() -> bool:
	if current_game == null or run_state == null or run_state.current_environment.is_empty():
		return false
	return current_game.wager_activity_incomplete(run_state, run_state.current_environment, _current_game_surface_ui_state())


func _ensure_closing_time_departure_talk() -> bool:
	if run_state == null or library == null:
		return false
	if not run_state.pending_talk_event(CLOSING_TIME_TALK_EVENT_ID).is_empty():
		_refresh_talk_dock()
		return true
	var dialogue := library.dialogue(CLOSING_TIME_DIALOGUE_ID)
	if dialogue.is_empty():
		return false
	var context := {
		"trigger": "closing_time",
		"type": "dialogue",
		"dialogue_id": CLOSING_TIME_DIALOGUE_ID,
		"source": "closing_time",
		"environment_snapshot": run_state.current_environment.duplicate(true),
	}
	var start_node := str(dialogue.get("start", "notice")).strip_edges()
	var speaker := _closing_time_talk_speaker(dialogue)
	if not run_state.enqueue_dialogue(CLOSING_TIME_DIALOGUE_ID, CLOSING_TIME_TALK_EVENT_ID, speaker, start_node, "closing_time", context):
		return false
	_refresh_talk_dock()
	_show_message("Someone from the room lets you know it is time to leave.")
	_autosave_foundation_run("Autosaved.")
	return true


func _closing_time_talk_speaker(dialogue: Dictionary) -> Dictionary:
	if current_game != null and run_state != null:
		var surface := current_game.surface_state(run_state, run_state.current_environment, _current_game_surface_ui_state())
		var patrons := _copy_array(surface.get("patrons", surface.get("rail_bettors", [])))
		for patron_index in range(patrons.size()):
			if typeof(patrons[patron_index]) == TYPE_DICTIONARY and not (patrons[patron_index] as Dictionary).is_empty():
				return _talk_speaker_from_patron(patrons[patron_index], patron_index, dialogue)
	var fallback: Dictionary = dialogue.get("speaker", {}).duplicate(true) if typeof(dialogue.get("speaker", {})) == TYPE_DICTIONARY else {}
	if run_state != null:
		var room_name := str(run_state.current_environment.get("display_name", "Room")).strip_edges()
		fallback["name"] = "%s Host" % room_name
		fallback["behavior"] = "closing the room"
	return _normalized_talk_speaker(fallback)


func _acknowledge_closing_time_talk(choice_id: String) -> void:
	if choice_id != CLOSING_TIME_TALK_CHOICE_ID or run_state == null:
		_show_message("Choose how to respond.")
		return
	run_state.complete_talk_event_resolution(CLOSING_TIME_TALK_EVENT_ID)
	_refresh_talk_dock()
	_show_message(_closing_time_disabled_reason())
	_autosave_foundation_run("Autosaved.")
	call_deferred("open_world_map", true)


func _advance_talk_event_action_boundary(_source: String) -> bool:
	if run_state == null:
		return false
	var expired := run_state.advance_focused_talk_event_actions(1)
	if expired.is_empty():
		_refresh_talk_dock()
		return false
	var timing: Dictionary = expired.get("timing", {}) if typeof(expired.get("timing", {})) == TYPE_DICTIONARY else {}
	var timeout_choice_id := str(timing.get("timeout_choice_id", "")).strip_edges()
	var event_id := str(expired.get("event_id", "")).strip_edges()
	if timeout_choice_id.is_empty() or event_id.is_empty():
		_refresh_talk_dock()
		return false
	_ignore_talk_event(event_id, "timeout")
	return true


func _enqueue_talk_events_for_action_boundary(source: String) -> bool:
	if run_state == null or library == null:
		return false
	var enqueued := false
	if _enqueue_heat_threshold_talk_events(source):
		enqueued = true
	if _enqueue_table_approach_talk_events(source):
		enqueued = true
	return enqueued


func _apply_forced_environment_travel(_source: String) -> bool:
	var closing_actions := int(run_state.narrative_flags.get("health_inspector_closing_actions", 0))
	if closing_actions <= 0:
		return false
	closing_actions -= 1
	run_state.narrative_flags["health_inspector_closing_actions"] = closing_actions
	if closing_actions > 0:
		return false
	var choices := _travel_choice_view_list()
	for choice_value in choices:
		if typeof(choice_value) != TYPE_DICTIONARY:
			continue
		var choice: Dictionary = choice_value
		if bool(choice.get("enabled", false)):
			run_state.narrative_flags["health_inspector_forced_travel"] = true
			_show_message("The Health Inspector shuts the room down. You have to move.")
			_travel_to(str(choice.get("id", "")), str(choice.get("label", choice.get("id", ""))), choice)
			return true
	run_state.narrative_flags["health_inspector_closing_actions"] = 1
	return false


func _maybe_trigger_unavoidable_event(source: String) -> bool:
	if _event_choice_popup_is_visible() or run_state == null or library == null:
		return false
	if _show_next_pending_triggered_event():
		return true
	if not _source_allows_action_triggered_events(source):
		return false
	var context := _event_action_trigger_context(source)
	if _enqueue_triggered_events_for_context(source, context, run_state.current_environment):
		_autosave_foundation_run("Autosaved.")
		return _show_next_pending_triggered_event()
	return false


func _source_allows_action_triggered_events(source: String) -> bool:
	var normalized := source.strip_edges().to_lower()
	return normalized != "lender"


func _enqueue_triggered_events_for_context(source: String, context: Dictionary, environment: Dictionary) -> bool:
	if run_state == null or library == null:
		return false
	var candidates: Array = []
	var enqueued := false
	var cadence_rng := run_state.create_event_cadence_rng()
	for event_definition_value in library.events:
		if typeof(event_definition_value) != TYPE_DICTIONARY:
			continue
		var event_definition: Dictionary = event_definition_value
		if str(event_definition.get("interaction_mode", "interactable")) != "triggered":
			continue
		var event_id := str(event_definition.get("id", ""))
		var trigger: Dictionary = event_definition.get("trigger", {}) if typeof(event_definition.get("trigger", {})) == TYPE_DICTIONARY else {}
		var trigger_type := str(trigger.get("type", "manual"))
		var event_module := EventModule.new()
		event_module.setup(event_definition, library)
		if not event_module.can_trigger(run_state, environment, context):
			continue
		if not run_state.event_cadence_allows_world_event(event_id, trigger_type, source, event_definition):
			continue
		if trigger_type == "random":
			candidates.append({"id": event_id, "trigger": trigger, "event": event_definition})
		elif ["timed", "travel"].has(trigger_type):
			if trigger_type == "travel":
				var travel_chance := clampi(int(trigger.get("chance_percent", 100)), 0, 100)
				if travel_chance <= 0:
					continue
				if travel_chance < 100 and cadence_rng.randi_range(1, 100) > travel_chance:
					continue
			if run_state.enqueue_triggered_event(event_id, source, _event_context_with_environment(context, environment), _triggered_entry_overrides(event_definition)):
				run_state.event_cadence_note_event_enqueued(event_id, not run_state.event_cadence_event_bypasses_budget(event_id, trigger_type, source, event_definition))
				enqueued = true
				break
	if enqueued:
		candidates.clear()
	if not candidates.is_empty():
		var rolled: Array = []
		for candidate_value in candidates:
			var candidate: Dictionary = candidate_value
			var trigger: Dictionary = candidate.get("trigger", {})
			var chance := clampi(int(trigger.get("chance_percent", 100)), 0, 100)
			var roll := cadence_rng.randi_range(1, 100)
			if roll <= chance:
				rolled.append(candidate)
		if not rolled.is_empty():
			var picked := _weighted_triggered_event_pick(rolled, cadence_rng)
			var picked_id := str(picked.get("id", ""))
			var picked_event: Dictionary = picked.get("event", {}) if typeof(picked.get("event", {})) == TYPE_DICTIONARY else {}
			if run_state.enqueue_triggered_event(picked_id, source, _event_context_with_environment(context, environment), _triggered_entry_overrides(picked_event)):
				run_state.event_cadence_note_event_enqueued(picked_id, not run_state.event_cadence_event_bypasses_budget(picked_id, "random", source, picked_event))
				enqueued = true
	run_state.save_event_cadence_rng(cadence_rng)
	return enqueued


func _enqueue_heat_threshold_talk_events(source: String) -> bool:
	var result := _recent_result_snapshot()
	var applied_delta := int(result.get("suspicion_delta", _copy_dict(result.get("deltas", {})).get("suspicion_delta", 0)))
	if applied_delta <= 0:
		return false
	var current_level := run_state.suspicion_level()
	var previous_level := clampi(current_level - applied_delta, 0, 100)
	var enqueued := false
	for event_definition_value in library.events:
		if typeof(event_definition_value) != TYPE_DICTIONARY:
			continue
		var event_definition: Dictionary = event_definition_value
		if str(event_definition.get("interaction_mode", "interactable")) != "triggered":
			continue
		if str(event_definition.get("presentation", "modal")) != "talk":
			continue
		var trigger: Dictionary = event_definition.get("trigger", {}) if typeof(event_definition.get("trigger", {})) == TYPE_DICTIONARY else {}
		if str(trigger.get("type", "manual")) != "heat_threshold":
			continue
		var threshold := int(trigger.get("level", 0))
		if threshold <= 0 or previous_level >= threshold or current_level < threshold:
			continue
		var seen_flag := "talk_heat_threshold_%d_seen" % threshold
		if bool(run_state.narrative_flags.get(seen_flag, false)):
			continue
		var event_id := str(event_definition.get("id", ""))
		var context := _event_context_with_environment({
			"trigger": "heat_threshold",
			"type": "heat_threshold",
			"source": source,
			"threshold": threshold,
			"previous_suspicion": previous_level,
			"current_suspicion": current_level,
		}, run_state.current_environment)
		var event_module := EventModule.new()
		event_module.setup(event_definition, library)
		if not event_module.can_trigger(run_state, run_state.current_environment, context):
			continue
		if run_state.enqueue_triggered_event(event_id, "heat_threshold", context, _triggered_entry_overrides(event_definition)):
			run_state.narrative_flags[seen_flag] = true
			enqueued = true
	return enqueued


func _enqueue_table_approach_talk_events(source: String) -> bool:
	if current_game == null or not ["game_action", "game_hook", "environment_game"].has(source):
		return false
	var game_id := current_game.get_id()
	if game_id.is_empty():
		return false
	var surface_state := current_game.surface_state(run_state, run_state.current_environment, _current_game_surface_ui_state())
	if typeof(surface_state) != TYPE_DICTIONARY:
		return false
	var state: Dictionary = surface_state
	var patrons := _copy_array(state.get("patrons", []))
	if patrons.is_empty():
		return false
	var hands_played := int(state.get("hands_played", state.get("rounds_played", 0)))
	var cadence_rng := run_state.create_event_cadence_rng()
	var enqueued := false
	for event_definition_value in library.events:
		if typeof(event_definition_value) != TYPE_DICTIONARY:
			continue
		var event_definition: Dictionary = event_definition_value
		if str(event_definition.get("interaction_mode", "interactable")) != "triggered":
			continue
		if str(event_definition.get("presentation", "modal")) != "talk":
			continue
		var trigger: Dictionary = event_definition.get("trigger", {}) if typeof(event_definition.get("trigger", {})) == TYPE_DICTIONARY else {}
		if str(trigger.get("type", "manual")) != "table_approach":
			continue
		var chance := clampf(float(trigger.get("chance", 1.0)), 0.0, 1.0)
		var roll := cadence_rng.randi_range(0, 9999)
		var context := _event_context_with_environment({
			"trigger": "table_approach",
			"type": "table_approach",
			"source": source,
			"game_id": game_id,
			"hands_played": hands_played,
			"roll": roll,
			"chance": chance,
		}, run_state.current_environment)
		var event_module := EventModule.new()
		event_module.setup(event_definition, library)
		if not event_module.can_trigger(run_state, run_state.current_environment, context):
			continue
		if roll >= int(round(chance * 10000.0)):
			continue
		var patron_index := cadence_rng.randi_range(0, patrons.size() - 1)
		var patron: Dictionary = patrons[patron_index] if typeof(patrons[patron_index]) == TYPE_DICTIONARY else {}
		if patron.is_empty():
			continue
		var overrides := _triggered_entry_overrides(event_definition, _talk_speaker_from_patron(patron, patron_index, event_definition))
		if run_state.enqueue_triggered_event(str(event_definition.get("id", "")), "table_approach", context, overrides):
			enqueued = true
			break
	run_state.save_event_cadence_rng(cadence_rng)
	return enqueued


func _triggered_entry_overrides(event_definition: Dictionary, speaker_override: Dictionary = {}) -> Dictionary:
	var payload: Dictionary = event_definition.get("payload", {}) if typeof(event_definition.get("payload", {})) == TYPE_DICTIONARY else {}
	var speaker := speaker_override.duplicate(true) if not speaker_override.is_empty() else _copy_dict(event_definition.get("speaker", {}))
	return {
		"presentation": str(event_definition.get("presentation", "modal")),
		"speaker": _normalized_talk_speaker(speaker),
		"timing": _triggered_entry_timing(payload),
	}


func _triggered_entry_timing(payload: Dictionary) -> Dictionary:
	var timing: Dictionary = payload.get("timing", {}) if typeof(payload.get("timing", {})) == TYPE_DICTIONARY else {}
	var expires := bool(timing.get("expires", false))
	var duration_actions := maxi(0, int(timing.get("duration_actions", 0)))
	var timeout_choice_id := str(timing.get("timeout_choice_id", "")).strip_edges()
	if not expires or duration_actions <= 0 or timeout_choice_id.is_empty():
		return {
			"expires": false,
			"duration_actions": 0,
			"remaining_actions": 0,
			"timeout_choice_id": "",
		}
	return {
		"expires": true,
		"duration_actions": duration_actions,
		"remaining_actions": duration_actions,
		"timeout_choice_id": timeout_choice_id,
	}


func _talk_speaker_from_patron(patron: Dictionary, patron_index: int, event_definition: Dictionary) -> Dictionary:
	var definition_speaker: Dictionary = event_definition.get("speaker", {}) if typeof(event_definition.get("speaker", {})) == TYPE_DICTIONARY else {}
	return {
		"role": "patron",
		"name": str(patron.get("name", definition_speaker.get("name", "Patron"))),
		"mood": str(patron.get("mood", "")),
		"behavior": str(patron.get("behavior", "")),
		"silhouette": str(patron.get("silhouette", definition_speaker.get("silhouette", "coat"))),
		"bind": "table_patron",
		"patron_index": patron_index,
		"hair_color": str(patron.get("hair_color", patron.get("hair", ""))),
		"jacket_color": str(patron.get("jacket_color", patron.get("jacket", ""))),
		"tell": str(patron.get("tell", "")),
	}


func _normalized_talk_speaker(speaker: Dictionary) -> Dictionary:
	var role := str(speaker.get("role", "stranger")).strip_edges().to_lower()
	if not ["patron", "staff", "stranger", "lender"].has(role):
		role = "stranger"
	var bind := str(speaker.get("bind", "none")).strip_edges().to_lower()
	if not ["table_patron", "none"].has(bind):
		bind = "none"
	return {
		"role": role,
		"name": str(speaker.get("name", "")).strip_edges(),
		"mood": str(speaker.get("mood", "")).strip_edges(),
		"behavior": str(speaker.get("behavior", "")).strip_edges(),
		"silhouette": str(speaker.get("silhouette", "")).strip_edges(),
		"bind": bind,
		"patron_index": maxi(-1, int(speaker.get("patron_index", -1))),
		"hair_color": str(speaker.get("hair_color", "")).strip_edges(),
		"jacket_color": str(speaker.get("jacket_color", "")).strip_edges(),
		"tell": str(speaker.get("tell", "")).strip_edges(),
	}


func _weighted_triggered_event_pick(candidates: Array, rng: RngStream) -> Dictionary:
	if candidates.is_empty():
		return {}
	var total_weight := 0
	for candidate_value in candidates:
		if typeof(candidate_value) != TYPE_DICTIONARY:
			continue
		var candidate: Dictionary = candidate_value
		total_weight += maxi(1, run_state.event_cadence_weight_for_event(str(candidate.get("id", ""))))
	if total_weight <= 0:
		return (candidates[0] as Dictionary).duplicate(true)
	var roll := rng.randi_range(1, total_weight)
	var cursor := 0
	for candidate_value in candidates:
		if typeof(candidate_value) != TYPE_DICTIONARY:
			continue
		var candidate: Dictionary = candidate_value
		cursor += maxi(1, run_state.event_cadence_weight_for_event(str(candidate.get("id", ""))))
		if roll <= cursor:
			return candidate
	return (candidates[candidates.size() - 1] as Dictionary).duplicate(true)


func _event_context_with_environment(context: Dictionary, environment: Dictionary) -> Dictionary:
	var queued_context := context.duplicate(true)
	queued_context["environment_snapshot"] = environment.duplicate(true)
	return queued_context


func _event_environment_for_context(context: Dictionary) -> Dictionary:
	if typeof(context.get("environment_snapshot", {})) == TYPE_DICTIONARY:
		var environment: Dictionary = context.get("environment_snapshot", {}) as Dictionary
		if not environment.is_empty():
			return environment.duplicate(true)
	return run_state.current_environment if run_state != null else {}


func _show_next_pending_triggered_event() -> bool:
	if _event_choice_popup_is_visible() or run_state == null or library == null:
		return false
	if not run_state.event_cadence_can_open_modal():
		return false
	var entry := run_state.active_triggered_event.duplicate(true)
	if entry.is_empty():
		entry = run_state.next_pending_triggered_event()
		if entry.is_empty():
			return false
		entry = run_state.begin_triggered_event_resolution(entry)
	if entry.is_empty():
		return false
	return _show_triggered_event_popup(entry)


func _show_triggered_event_popup(entry: Dictionary) -> bool:
	var event_id := str(entry.get("event_id", ""))
	var event_definition := library.event(event_id)
	if event_definition.is_empty() or event_choice_popup_overlay == null or event_choice_popup_choices_list == null:
		return false
	var event_module := EventModule.new()
	event_module.setup(event_definition, library)
	var context: Dictionary = entry.get("context", {}) if typeof(entry.get("context", {})) == TYPE_DICTIONARY else {}
	var event_environment := _event_environment_for_context(context)
	if not event_module.can_trigger(run_state, event_environment, context):
		run_state.complete_triggered_event_resolution(event_id)
		return false
	var event_option := _eligible_event_option_with_context(event_id, context, event_environment)
	if event_option.is_empty():
		run_state.complete_triggered_event_resolution(event_id)
		return false
	pending_event_choice_popup_event_id = event_id
	pending_event_choice_popup_focus_choice_id = ""
	pending_event_choice_popup_snapshot = {
		"visible": true,
		"blocking": true,
		"popup_type": "triggered_event",
		"interaction_kind": "event",
		"dismissible": false,
		"event_id": event_id,
		"trigger_context": context,
		"summary": str(event_option.get("summary", "")),
		"choices": _copy_array(event_option.get("choices", [])),
	}
	if event_choice_popup_title_label != null:
		event_choice_popup_title_label.text = str(event_option.get("display_name", event_id))
	if event_choice_popup_summary_label != null:
		event_choice_popup_summary_label.text = str(event_option.get("summary", "Something interrupts the room."))
	_clear(event_choice_popup_choices_list)
	for choice_value in _copy_array(event_option.get("choices", [])):
		if typeof(choice_value) != TYPE_DICTIONARY:
			continue
		var choice: Dictionary = choice_value
		_add_wager_confirmation_card(
			str(choice.get("label", choice.get("id", ""))),
			str(choice.get("text", "")),
			str(choice.get("consequence_summary", "")),
			Callable(self, "resolve_event_choice").bind(event_id, str(choice.get("id", ""))),
			false,
			choice.get("attribute_badges", [])
		)
	event_choice_popup_overlay.visible = true
	event_choice_popup_overlay.move_to_front()
	_position_event_choice_popup()
	call_deferred("_position_event_choice_popup")
	return true


func _refresh_talk_dock() -> void:
	if talk_dock == null:
		return
	if run_state == null or library == null:
		talk_dock.clear_entry()
		return
	var entry := run_state.next_pending_talk_event()
	if entry.is_empty():
		talk_dock.clear_entry()
		return
	var event_id := str(entry.get("event_id", ""))
	var dialogue_id := str(entry.get("dialogue_id", "")).strip_edges()
	var option := _dialogue_option_for_entry(entry) if not dialogue_id.is_empty() else {}
	if option.is_empty():
		var context: Dictionary = entry.get("context", {}) if typeof(entry.get("context", {})) == TYPE_DICTIONARY else {}
		var event_environment := _event_environment_for_context(context)
		option = _eligible_event_option_with_context(event_id, context, event_environment)
	if option.is_empty():
		run_state.complete_talk_event_resolution(event_id)
		talk_dock.clear_entry()
		return
	talk_dock.set_entry(entry, option, run_state.pending_talk_event_count())
	if item_found_popup != null and item_found_popup.is_open():
		item_found_talk_dock_suspended = true
		talk_dock.visible = false


func _pending_talk_event_entry(event_id: String) -> Dictionary:
	if run_state == null:
		return {}
	return run_state.pending_talk_event(event_id)


func start_dialogue(dialogue_id: String, source_data: Dictionary = {}) -> bool:
	if run_state == null or library == null:
		return false
	var clean_id := dialogue_id.strip_edges()
	var dialogue := library.dialogue(clean_id)
	if dialogue.is_empty():
		_show_message("Dialogue is not available.")
		_refresh()
		return false
	var event_id := str(source_data.get("event_id", "")).strip_edges()
	if event_id.is_empty():
		event_id = "dialogue:%s" % clean_id
	if not run_state.pending_talk_event(event_id).is_empty():
		_refresh_talk_dock()
		_show_message("Conversation is already open.")
		_refresh()
		return true
	var context := {
		"trigger": "dialogue",
		"type": "dialogue",
		"dialogue_id": clean_id,
		"source": str(source_data.get("source", "dialogue")),
		"source_object_id": str(source_data.get("object_id", source_data.get("source_object_id", ""))),
		"environment_snapshot": run_state.current_environment.duplicate(true),
	}
	var source_event_id := str(source_data.get("source_event_id", source_data.get("event_id", ""))).strip_edges()
	if not source_event_id.is_empty():
		context["source_event_id"] = source_event_id
	var speaker: Dictionary = dialogue.get("speaker", {}) if typeof(dialogue.get("speaker", {})) == TYPE_DICTIONARY else {}
	var start_node := str(dialogue.get("start", "")).strip_edges()
	if not run_state.enqueue_dialogue(clean_id, event_id, speaker, start_node, "dialogue", context):
		_show_message("Conversation is already queued.")
		_refresh()
		return false
	_refresh_talk_dock()
	_show_message("Talking to %s." % str(speaker.get("name", dialogue.get("display_name", "the room"))))
	_autosave_foundation_run("Autosaved.")
	_refresh()
	return true


func _start_event_dialogue(event_id: String) -> bool:
	if library == null:
		return false
	var event_definition := library.event(event_id)
	var dialogue_id := str(event_definition.get("dialogue_id", "")).strip_edges()
	if dialogue_id.is_empty():
		return false
	var event_option := _eligible_event_option(event_id)
	if event_option.is_empty():
		_show_message("Nothing is happening here right now.")
		_refresh()
		return false
	return start_dialogue(dialogue_id, {
		"event_id": event_id,
		"source_event_id": event_id,
		"source": "event_object",
		"source_object_id": "event:%s" % event_id,
	})


func _dialogue_option_for_entry(entry: Dictionary) -> Dictionary:
	if library == null:
		return {}
	var dialogue_id := str(entry.get("dialogue_id", "")).strip_edges()
	if dialogue_id.is_empty():
		return {}
	var dialogue := library.dialogue(dialogue_id)
	if dialogue.is_empty():
		return {}
	var node_id := str(entry.get("current_node", "")).strip_edges()
	if node_id.is_empty():
		node_id = str(dialogue.get("start", "")).strip_edges()
	var node := _dialogue_node(dialogue, node_id)
	if node.is_empty():
		return {}
	var choices := _dialogue_choice_views(dialogue_id, node)
	if choices.is_empty():
		choices.append({
			"id": "continue",
			"label": "...",
			"text": "Continue.",
			"consequences": {},
			"event_type": "social",
			"consequence_summary": "No immediate cost",
			"requires_confirm": false,
			"enabled": true,
			"attribute_badges": [],
		})
	var summary := str(node.get("text", ""))
	if dialogue_id == "linda_cage_services":
		summary = CageCounterViewModelScript.service_summary(run_state, node_id)
	elif dialogue_id == "sal_starter_offer":
		summary = _sal_starter_offer_summary()
	elif dialogue_id == "sal_starter_mocking_relist" and meta_collection_service != null:
		for row_value in meta_collection_service.sal_shelf_rows():
			var row := _copy_dict(row_value)
			if str(row.get("listing_mode", "")) != MetaCollectionServiceScript.LISTING_MODE_MOCKING_RELIST:
				continue
			var relist_quote := _copy_dict(row.get("quote_basis", {}))
			summary = "Same exact item. Pawn quote %d gold; asking price ceil(%d × 10) = %d gold." % [int(relist_quote.get("pawn_quote", 0)), int(relist_quote.get("pawn_quote", 0)), int(row.get("asking_price", 0))]
			break
	return {
		"id": str(entry.get("event_id", "dialogue:%s" % dialogue_id)),
		"dialogue_id": dialogue_id,
		"display_name": str(dialogue.get("display_name", dialogue_id.replace("_", " ").capitalize())),
		"type": "dialogue",
		"interaction_mode": "triggered",
		"summary": summary,
		"choices": choices,
	}


func _dialogue_node(dialogue: Dictionary, node_id: String) -> Dictionary:
	var nodes := _dialogue_nodes_map(dialogue.get("nodes", {}))
	if nodes.has(node_id):
		var node_value: Variant = nodes.get(node_id, {})
		if typeof(node_value) == TYPE_DICTIONARY:
			return (node_value as Dictionary).duplicate(true)
	return {}


func _dialogue_nodes_map(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return (value as Dictionary).duplicate(true)
	if typeof(value) != TYPE_ARRAY:
		return {}
	var result := {}
	for node_value in value as Array:
		if typeof(node_value) != TYPE_DICTIONARY:
			continue
		var node: Dictionary = node_value
		var node_id := str(node.get("id", "")).strip_edges()
		if not node_id.is_empty():
			result[node_id] = node.duplicate(true)
	return result


func _dialogue_choice_views(dialogue_id: String, node: Dictionary) -> Array:
	var result: Array = []
	var choices: Array = node.get("choices", []) if typeof(node.get("choices", [])) == TYPE_ARRAY else []
	for choice_value in choices:
		if typeof(choice_value) != TYPE_DICTIONARY:
			continue
		var choice: Dictionary = choice_value
		var choice_id := str(choice.get("id", "")).strip_edges()
		if choice_id.is_empty():
			continue
		var requirement := _dialogue_choice_requirement(choice)
		if not bool(requirement.get("enabled", true)) and bool(choice.get("hide_when_unmet", false)):
			continue
		var effects := _dialogue_choice_effects(choice)
		var option_choice := {
			"id": choice_id,
			"label": str(choice.get("label", choice_id)),
			"text": str(choice.get("text", "")),
			"event_type": "social",
			"dialogue_id": dialogue_id,
			"consequences": effects,
			"check": _copy_dict(effects.get("check", {})),
			"consequence_summary": "Hidden" if bool(choice.get("effects_hidden", false)) else _event_choice_consequence_summary({"consequences": effects}),
			"requires_confirm": _event_choice_requires_confirmation({"consequences": effects}),
			"enabled": bool(requirement.get("enabled", true)),
			"disabled_reason": str(requirement.get("reason", "")),
		}
		if dialogue_id == "linda_cage_services":
			var service_status := _linda_cage_choice_status(choice_id)
			if not service_status.is_empty():
				option_choice["enabled"] = bool(service_status.get("enabled", true))
				option_choice["disabled_reason"] = str(service_status.get("reason", ""))
		elif dialogue_id == "sal_starter_offer" and choice_id == "sal_starter_sell_back":
			var pending_offer := meta_collection_service.pending_starter_buyback() if meta_collection_service != null else {}
			option_choice["label"] = "Sell it back · %d gold" % int(pending_offer.get("offer_price", 0))
			option_choice["consequence_summary"] = "Exact one-time buyback"
		elif dialogue_id == "sal_starter_offer" and choice_id == "sal_starter_keep":
			option_choice["consequence_summary"] = "Keep the exact item"
		option_choice["attribute_badges"] = [] if bool(choice.get("effects_hidden", false)) else AttributeBadgesScript.for_event_choice(option_choice)
		result.append(option_choice)
	return result


func _dialogue_choice_requirement(choice: Dictionary) -> Dictionary:
	if run_state == null:
		return {"enabled": false, "reason": "No active run."}
	var requires: Dictionary = choice.get("requires", choice.get("conditions", {})) if typeof(choice.get("requires", choice.get("conditions", {}))) == TYPE_DICTIONARY else {}
	if requires.is_empty():
		return {"enabled": true, "reason": ""}
	var story_flags: Dictionary = requires.get("story_flags", requires.get("requires_story_flags", {})) if typeof(requires.get("story_flags", requires.get("requires_story_flags", {}))) == TYPE_DICTIONARY else {}
	for key in story_flags.keys():
		if _dialogue_story_flag_value(str(key)) != story_flags[key]:
			return {"enabled": false, "reason": "Requires story lead."}
	if requires.has("min_bankroll") and run_state.bankroll < int(requires.get("min_bankroll", 0)):
		return {"enabled": false, "reason": "Needs $%d." % int(requires.get("min_bankroll", 0))}
	if requires.has("max_bankroll") and run_state.bankroll > int(requires.get("max_bankroll", 0)):
		return {"enabled": false, "reason": "Too much cash showing."}
	var heat := run_state.suspicion_level()
	if requires.has("min_heat") and heat < int(requires.get("min_heat", 0)):
		return {"enabled": false, "reason": "Heat is too low."}
	if requires.has("max_heat") and heat > int(requires.get("max_heat", 0)):
		return {"enabled": false, "reason": "Heat is too high."}
	return {"enabled": true, "reason": ""}


func _dialogue_story_flag_value(flag_id: String) -> Variant:
	if run_state == null:
		return null
	if run_state.story_flags.has(flag_id):
		return run_state.story_flags.get(flag_id)
	return run_state.narrative_flags.get(flag_id, null)


func _dialogue_choice_effects(choice: Dictionary) -> Dictionary:
	var effects_value: Variant = choice.get("effects", choice.get("consequences", {}))
	if typeof(effects_value) != TYPE_DICTIONARY:
		return {}
	return (effects_value as Dictionary).duplicate(true)


func _resolve_dialogue_choice(entry: Dictionary, choice_id: String) -> void:
	if travel_transition_active:
		_show_message("Travel is already in progress.")
		_refresh_modal_contract_owner()
		return
	if str(entry.get("dialogue_id", "")) == "linda_cage_services" and choice_id.begins_with("cage_"):
		_resolve_linda_cage_service_choice(entry, choice_id)
		return
	if str(entry.get("dialogue_id", "")) == "sal_starter_offer" and choice_id in ["sal_starter_sell_back", "sal_starter_keep"]:
		_resolve_sal_starter_dialogue_choice(entry, choice_id)
		return
	var option := _dialogue_option_for_entry(entry)
	var option_choice := _event_choice(option, choice_id)
	if option_choice.is_empty():
		_show_message("Dialogue choice is not available.")
		return
	if not bool(option_choice.get("enabled", true)):
		_show_message(str(option_choice.get("disabled_reason", "Dialogue choice is locked.")))
		return
	var dialogue_id := str(entry.get("dialogue_id", "")).strip_edges()
	var dialogue := library.dialogue(dialogue_id)
	var node_id := str(entry.get("current_node", dialogue.get("start", ""))).strip_edges()
	var node := _dialogue_node(dialogue, node_id)
	var choice_definition := _dialogue_choice_definition(node, choice_id)
	if choice_definition.is_empty() and choice_id == "continue":
		choice_definition = {"id": "continue", "label": "...", "effects": {}, "end": true}
	if choice_definition.is_empty():
		_show_message("Dialogue choice is not available.")
		return
	var effects := _dialogue_choice_effects(choice_definition)
	var context: Dictionary = entry.get("context", {}) if typeof(entry.get("context", {})) == TYPE_DICTIONARY else {}
	var event_environment := _event_environment_for_context(context)
	var event_module := EventModule.new()
	event_module.setup(_dialogue_choice_event_definition(entry, option, choice_definition, effects), library)
	var inventory_before := _run_inventory_id_set()
	var result := event_module.resolve(run_state, event_environment, choice_id)
	_show_item_found_popups(result, inventory_before)
	_start_conclusion_animation(result, _talk_dock_panel_rect())
	_play_result_drink_audio_cue(result)
	if bool(result.get("ok", false)):
		var goto_id := str(choice_definition.get("goto", "")).strip_edges()
		if not goto_id.is_empty():
			run_state.update_pending_talk_dialogue_node(str(entry.get("event_id", "")), goto_id)
		else:
			var source_event_id := str(context.get("source_event_id", "")).strip_edges()
			if not source_event_id.is_empty():
				run_state.resolve_event(source_event_id)
			run_state.complete_talk_event_resolution(str(entry.get("event_id", "")))
	_show_message(str(result.get("message", "")))
	_advance_alcohol_absorption()
	_autosave_foundation_run("Autosaved.")
	_refresh_talk_dock()
	if bool(result.get("ok", false)) and _apply_post_action_environment_interrupt("dialogue"):
		_refresh()
		return
	_refresh()


func _sal_starter_offer_summary() -> String:
	if meta_collection_service == null:
		return "Sal's offer is unavailable."
	var pending := meta_collection_service.pending_starter_buyback()
	if pending.is_empty():
		return "Sal has already closed the offer."
	var channel := str(pending.get("rare_channel", "edge")).replace("_", " ").capitalize()
	return "Sal taps the %s reading: %.2f%%. ‘Edge sample. I'll pay %d gold right now. Sell it back?’" % [
		channel,
		float(pending.get("rare_value", 0.0)) * 100.0,
		int(pending.get("offer_price", 0)),
	]


func _sal_starter_offer_is_pending() -> bool:
	return meta_collection_service != null and not meta_collection_service.pending_starter_buyback().is_empty()


func _resume_sal_starter_offer() -> bool:
	if not _sal_starter_offer_is_pending():
		return false
	_hide_event_choice_popup()
	return start_dialogue("sal_starter_offer", {
		"event_id": "dialogue:sal_starter_offer",
		"source": "sal_resale_tutorial",
		"source_object_id": "meta_sal:talk",
	})


func _talk_to_sal() -> bool:
	if _sal_starter_offer_is_pending():
		return _resume_sal_starter_offer()
	return start_dialogue("sal_shop_talk", {
		"source": "sal_pawn_shop",
		"source_object_id": "meta_sal:talk",
	})


func _start_sal_routine_dialogue(kind: String) -> bool:
	if meta_collection_service == null:
		return false
	var snapshot := meta_collection_service.snapshot()
	var pool: Array[String] = ["sal_purchase_1", "sal_purchase_2"]
	var count := _copy_array(_copy_dict(snapshot.get("sal_resale", {})).get("purchase_history", [])).size()
	if kind == "sale":
		pool = ["sal_sale_1", "sal_sale_2"]
		count = _copy_array(snapshot.get("sale_history", [])).size()
	var index := posmod(maxi(0, count - 1), pool.size())
	return start_dialogue(pool[index], {
		"source": "sal_%s" % kind,
		"source_object_id": "meta_sal:talk",
	})


func _resolve_sal_starter_dialogue_choice(entry: Dictionary, choice_id: String) -> void:
	var choice := "sell_back" if choice_id == "sal_starter_sell_back" else "keep"
	var result: Dictionary = meta_collection_service.resolve_starter_buyback(choice)
	if not bool(result.get("ok", false)):
		_show_message(str(result.get("message", "Sal's offer could not be resolved.")))
		_refresh_talk_dock()
		_refresh()
		return
	var save_error := meta_collection_service.save()
	if save_error != OK:
		meta_collection_service.load()
		_show_message("Sal's offer could not be saved, so nothing changed.")
		_refresh_talk_dock()
		_refresh()
		return
	run_state.complete_talk_event_resolution(str(entry.get("event_id", "dialogue:sal_starter_offer")))
	_apply_meta_environment(meta_session_location_id)
	_refresh_meta_item_interaction()
	_refresh_talk_dock()
	_show_message(str(result.get("message", "Sal's offer is closed.")))
	var continuation := "sal_starter_mocking_relist" if choice == "sell_back" else "sal_starter_kept"
	start_dialogue(continuation, {
		"source": "sal_resale_tutorial",
		"source_object_id": "meta_sal:talk",
	})
	_refresh()


func _dialogue_choice_definition(node: Dictionary, choice_id: String) -> Dictionary:
	var choices: Array = node.get("choices", []) if typeof(node.get("choices", [])) == TYPE_ARRAY else []
	for choice_value in choices:
		if typeof(choice_value) == TYPE_DICTIONARY and str((choice_value as Dictionary).get("id", "")) == choice_id:
			return (choice_value as Dictionary).duplicate(true)
	return {}


func _dialogue_choice_event_definition(entry: Dictionary, option: Dictionary, choice: Dictionary, effects: Dictionary) -> Dictionary:
	var choice_id := str(choice.get("id", "")).strip_edges()
	return {
		"id": str(entry.get("event_id", "dialogue")),
		"display_name": str(option.get("display_name", "Talk")),
		"type": "social",
		"interaction_mode": "triggered",
		"scopes": ["any"],
		"trigger": {"type": "manual"},
		"payload": {
			"summary": str(option.get("summary", "")),
			"choices": [{
				"id": choice_id,
				"label": str(choice.get("label", choice_id)),
				"text": str(choice.get("text", choice.get("label", choice_id))),
				"consequences": effects,
			}],
		},
	}


func _talk_dock_panel_rect() -> Rect2:
	if talk_dock == null:
		return Rect2()
	var snapshot := talk_dock.current_snapshot()
	var rect_value: Variant = snapshot.get("panel_rect", Rect2())
	if typeof(rect_value) == TYPE_RECT2:
		return rect_value
	return Rect2()


func _talk_choice_is_ignore(choice_id: String) -> bool:
	var clean_id := choice_id.strip_edges().to_lower()
	return clean_id.begins_with("ignore")


func _pending_talk_entries() -> Array:
	var entries: Array = []
	if run_state == null:
		return entries
	while true:
		var entry := run_state.next_pending_talk_event()
		if entry.is_empty():
			break
		entries.append(entry.duplicate(true))
		run_state.complete_talk_event_resolution(str(entry.get("event_id", "")))
	return entries


func _ignore_talk_event(event_id: String, reason: String) -> bool:
	if run_state == null:
		return false
	var entry := run_state.pending_talk_event(event_id)
	if entry.is_empty():
		return false
	run_state.complete_talk_event_resolution(event_id)
	_apply_talk_ignore_penalty([entry], reason)
	_refresh_talk_dock()
	_show_message(_talk_ignore_message([entry], reason))
	_autosave_foundation_run("Autosaved.")
	return true


func _apply_talk_ignore_penalty(entries: Array, reason: String) -> int:
	if run_state == null or entries.is_empty():
		return 0
	var story_entries: Array = []
	for entry_value in entries:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value
		var speaker: Dictionary = entry.get("speaker", {}) if typeof(entry.get("speaker", {})) == TYPE_DICTIONARY else {}
		story_entries.append({
			"type": "talk_ignored",
			"event_id": str(entry.get("event_id", "")),
			"dialogue_id": str(entry.get("dialogue_id", "")),
			"speaker": str(speaker.get("name", speaker.get("role", "Someone"))),
			"reason": reason,
			"environment_id": str(entry.get("environment_id", run_state.current_environment.get("id", ""))),
			"suspicion_delta": TALK_IGNORE_HEAT_DELTA,
			"message": _talk_ignore_story_message(entry, reason),
		})
	if story_entries.is_empty():
		return 0
	var total_heat := TALK_IGNORE_HEAT_DELTA * story_entries.size()
	var deltas := GameModule.empty_result_deltas()
	deltas["suspicion_delta"] = total_heat
	deltas["story_log"] = story_entries
	deltas["messages"] = [_talk_ignore_message(entries, reason)]
	var result := GameModule.build_action_result({
		"ok": true,
		"type": "talk_ignore",
		"source_id": "talk",
		"action_id": "ignore_%s" % reason,
		"action_kind": "risky",
		"environment_id": str(run_state.current_environment.get("id", "")),
		"environment_archetype_id": str(run_state.current_environment.get("archetype_id", "")),
		"suspicion_delta": total_heat,
		"deltas": deltas,
		"message": str(deltas["messages"][0]),
	})
	GameModule.apply_result(run_state, result)
	return total_heat


func _talk_ignore_message(entries: Array, reason: String) -> String:
	var count := entries.size()
	var total_heat := TALK_IGNORE_HEAT_DELTA * count
	if count <= 1:
		var entry: Dictionary = entries[0] if count == 1 and typeof(entries[0]) == TYPE_DICTIONARY else {}
		var speaker: Dictionary = entry.get("speaker", {}) if typeof(entry.get("speaker", {})) == TYPE_DICTIONARY else {}
		var speaker_name := str(speaker.get("name", speaker.get("role", "Someone"))).strip_edges()
		if speaker_name.is_empty():
			speaker_name = "Someone"
		return "%s notices you ignored them. Heat +%d." % [speaker_name, total_heat]
	var verb := "left hanging" if reason == "travel" else "ignored"
	return "%d conversations %s. Heat +%d." % [count, verb, total_heat]


func _talk_ignore_story_message(entry: Dictionary, reason: String) -> String:
	var speaker: Dictionary = entry.get("speaker", {}) if typeof(entry.get("speaker", {})) == TYPE_DICTIONARY else {}
	var speaker_name := str(speaker.get("name", speaker.get("role", "Someone"))).strip_edges()
	if speaker_name.is_empty():
		speaker_name = "Someone"
	if reason == "travel":
		return "You left %s mid-conversation." % speaker_name
	if reason == "timeout":
		return "%s gives up waiting for your answer." % speaker_name
	return "You ignored %s." % speaker_name


func _event_action_trigger_context(source: String) -> Dictionary:
	return {
		"trigger": "action",
		"type": "action",
		"source": source,
		"turns": int(run_state.current_environment.get("turns", 0)) if run_state != null else 0,
	}


func _pending_event_trigger_context(event_id: String) -> Dictionary:
	var popup_type := str(pending_event_choice_popup_snapshot.get("popup_type", ""))
	if ["triggered_event", "unavoidable_event"].has(popup_type) and str(pending_event_choice_popup_snapshot.get("event_id", "")) == event_id:
		var context: Dictionary = pending_event_choice_popup_snapshot.get("trigger_context", {}) if typeof(pending_event_choice_popup_snapshot.get("trigger_context", {})) == TYPE_DICTIONARY else {}
		return context.duplicate(true)
	var talk_entry := _pending_talk_event_entry(event_id)
	if not talk_entry.is_empty():
		return _copy_dict(talk_entry.get("context", {}))
	return {}


# Selects an item offer without mutating simulation state.
func select_item_offer(item_id: String) -> bool:
	if _guard_player_input_route():
		return false
	var offer := _item_offer(item_id)
	if offer.is_empty():
		_show_message("Item offer is not available.")
		return false
	selected_item_offer_id = item_id
	selected_item_offer_label = str(offer.get("display_name", item_id))
	selected_item_offer_price = int(offer.get("price", 0))
	selected_action_category = ACTION_CATEGORY_ITEMS
	_set_current_screen(SCREEN_ITEMS)
	focus_interactable_object("item:%s" % selected_item_offer_id)
	_show_message("Selected item: %s." % selected_item_offer_label)
	_refresh()
	return true


# Confirms the selected item purchase and immediate run item application.
func confirm_selected_item_offer() -> bool:
	if selected_item_offer_id.is_empty():
		_show_message("Select an item offer first.")
		return false
	return apply_item_offer(selected_item_offer_id)


# Buys one item offer and applies it through ItemEffect.
func apply_item_offer(item_id: String) -> bool:
	if _guard_player_input_route(false, "item:%s" % item_id):
		return false
	_refresh_run_action_service()
	var resolved := run_action_service.buy_item_offer(item_id)
	if not bool(resolved.get("ok", false)):
		_show_message(str(resolved.get("message", "Item offer is not available.")))
		return false
	var result: Dictionary = resolved.get("result", {})
	last_item_result = result.duplicate(true)
	_play_result_drink_audio_cue(result)
	last_game_result = {}
	last_hook_result = {}
	_clear_selected_item_offer()
	_set_current_screen(SCREEN_RESULT)
	_show_message(str(result.get("message", "")))
	_advance_alcohol_absorption()
	_autosave_foundation_run("Autosaved.")
	if _apply_post_action_environment_interrupt("item_purchase"):
		_refresh()
		return true
	_refresh()
	return true


func confirm_home_tenure_action() -> bool:
	if _guard_player_input_route():
		return false
	if run_state == null:
		_show_message("No active home.")
		return false
	var result := run_state.pay_home_tenure()
	if not bool(result.get("ok", false)):
		_show_message(str(result.get("message", "Home payment is not available.")))
		_refresh()
		return false
	last_item_result = {
		"ok": true,
		"type": "home_tenure",
		"message": str(result.get("message", "")),
		"bankroll_delta": int(result.get("bankroll_delta", 0)),
	}
	_show_message(str(result.get("message", "Home payment complete.")))
	_autosave_foundation_run("Autosaved.")
	_refresh()
	return true


func confirm_home_sleep_action() -> bool:
	if _guard_player_input_route():
		return false
	if run_state == null:
		_show_message("No active home.")
		return false
	var result := run_state.sleep_at_home()
	if not bool(result.get("ok", false)):
		_show_message(str(result.get("message", "Sleep is not available.")))
		_refresh()
		return false
	last_item_result = result.duplicate(true)
	last_game_result = {}
	last_hook_result = {}
	_show_message(str(result.get("message", "You wake up rested.")))
	_autosave_foundation_run("Autosaved.")
	if _apply_post_action_environment_interrupt("home_sleep"):
		_refresh()
		return true
	_refresh()
	return true


func _show_place_container_popup() -> bool:
	if run_state == null:
		return false
	var options := _held_container_item_options()
	if options.is_empty():
		_show_message("Carry a container before placing home storage.")
		_refresh()
		return false
	_hide_event_choice_popup()
	_hide_run_journal_popup()
	_open_run_inventory_popup("place_container")
	return true


func _place_home_container_from_popup(item_id: String) -> void:
	var option := _container_item_option(item_id)
	var result: Dictionary = run_state.place_home_container(item_id, str(option.get("display_name", item_id.replace("_", " ").capitalize())), int(option.get("capacity", 0))) if run_state != null else {"ok": false, "message": "No active home."}
	_show_message(str(result.get("message", "Container placement failed.")))
	_autosave_foundation_run("Autosaved.")
	if bool(result.get("ok", false)):
		_open_run_inventory_popup("home_container", str(result.get("container_id", "")))
		return
	if _run_inventory_popup_is_visible():
		_open_run_inventory_popup("place_container")
	_refresh()


func _show_home_container_popup(container_id: String) -> bool:
	if run_state == null:
		return false
	var container := _home_container_by_id(container_id)
	if container.is_empty():
		_show_message("Container is no longer available.")
		_refresh()
		return false
	_hide_event_choice_popup()
	_hide_run_journal_popup()
	_open_run_inventory_popup("home_container", container_id)
	return true


func _store_home_container_item_from_popup(container_id: String, item_id: String) -> void:
	var result: Dictionary = run_state.transfer_item_to_home_container(container_id, item_id) if run_state != null else {"ok": false, "message": "No active home."}
	_show_message(str(result.get("message", "Transfer failed.")))
	_autosave_foundation_run("Autosaved.")
	if _run_inventory_popup_is_visible():
		_open_run_inventory_popup("home_container", container_id)
		return
	_refresh()


func _take_home_container_item_from_popup(container_id: String, item_id: String) -> void:
	var result: Dictionary = run_state.transfer_item_from_home_container(container_id, item_id) if run_state != null else {"ok": false, "message": "No active home."}
	_show_message(str(result.get("message", "Transfer failed.")))
	_autosave_foundation_run("Autosaved.")
	if _run_inventory_popup_is_visible():
		_open_run_inventory_popup("home_container", container_id)
		return
	_refresh()


func _transfer_home_container_item_from_popup(from_container_id: String, to_container_id: String, item_id: String) -> void:
	var result: Dictionary = run_state.transfer_item_between_home_containers(from_container_id, to_container_id, item_id) if run_state != null else {"ok": false, "message": "No active home."}
	_show_message(str(result.get("message", "Transfer failed.")))
	_autosave_foundation_run("Autosaved.")
	if _run_inventory_popup_is_visible():
		_open_run_inventory_popup("home_container", str(result.get("to_container_id", to_container_id)) if bool(result.get("ok", false)) else from_container_id)
		return
	_refresh()


func _close_home_storage_popup() -> void:
	_hide_event_choice_popup()
	_hide_run_inventory_popup()
	_refresh()


func open_run_inventory() -> void:
	if run_state == null:
		_show_message("No active run to inspect.")
		return
	if _guard_player_input_route(false, "inventory"):
		return
	_reset_game_surface_runtime_state()
	_hide_run_journal_popup()
	_open_run_inventory_popup("inspect")


func close_run_inventory() -> void:
	_hide_run_inventory_popup()
	_refresh()


func open_run_journal() -> void:
	if run_state == null:
		_show_message("No active run to review.")
		return
	if _guard_blocking_decision_or_transition():
		return
	if _world_map_overlay_is_visible() or _run_inventory_popup_is_visible():
		_show_message(_blocking_modal_message())
		_refresh_modal_contract_owner()
		return
	_hide_run_inventory_popup()
	_open_run_journal_popup()


func close_run_journal() -> void:
	_hide_run_journal_popup()


func use_active_item_slot() -> bool:
	if run_state == null:
		_show_message("No active run.")
		return false
	if _guard_player_input_route():
		return false
	_refresh_run_action_service()
	var item := run_action_service.active_item_detail()
	if item.is_empty():
		_show_message("No active item equipped. Open inventory to choose one.")
		_open_run_inventory_popup("inspect")
		return false
	_show_active_item_confirmation_popup(item)
	return true


func select_active_inventory_item(item_id: String) -> bool:
	_refresh_run_action_service()
	var resolved := run_action_service.set_active_item(item_id)
	if not bool(resolved.get("ok", false)):
		_show_message(str(resolved.get("message", "That item cannot be equipped.")))
		_refresh()
		return false
	_show_message(str(resolved.get("message", "Active item equipped.")))
	_autosave_foundation_run("Autosaved.")
	_refresh_active_item_slot()
	if _run_inventory_popup_is_visible():
		_render_run_inventory_popup_contents()
	return true


func confirm_pending_active_item_use() -> void:
	if pending_active_item_id.is_empty():
		_hide_event_choice_popup()
		return
	var item_id := pending_active_item_id
	pending_active_item_id = ""
	_hide_event_choice_popup()
	_use_active_item(item_id)


func cancel_pending_active_item_use() -> void:
	pending_active_item_id = ""
	_hide_event_choice_popup()
	_show_message("Active item canceled.")
	_refresh()


func _use_active_item(item_id: String) -> bool:
	if run_state == null:
		_show_message("No active run.")
		return false
	_refresh_run_action_service()
	var detail := run_action_service.inventory_item_detail(item_id)
	if detail.is_empty() or not bool(detail.get("active_item", false)):
		_show_message("That active item is no longer available.")
		_refresh()
		return false
	var active_target := str(detail.get("active_target", ""))
	if active_target == "global" or active_target == "run":
		return _use_global_active_item(item_id, detail)
	if current_game == null:
		_show_message("That active item needs a game surface.")
		return false
	var command: Dictionary = current_game.active_item_command(item_id, run_state, run_state.current_environment, run_state.create_rng("active_item:%s" % item_id))
	if not bool(command.get("handled", false)):
		_show_message("%s has no use here." % str(detail.get("display_name", item_id)))
		_refresh()
		return false
	var result: Dictionary = command.get("result", {})
	if not result.is_empty():
		if bool(result.get("ok", false)):
			run_state.advance_environment_turns(1)
		GameModule.apply_result(run_state, result, run_state.create_rng("active_item_apply:%s" % item_id))
		_play_result_drink_audio_cue(result)
		last_item_result = result.duplicate(true)
		last_game_result = {}
		last_hook_result = {}
	if bool(command.get("environment_changed", false)) or not result.is_empty():
		_advance_alcohol_absorption()
		_autosave_foundation_run("Autosaved.")
	var message := str(command.get("message", result.get("message", "Active item used.")))
	if not message.is_empty():
		_show_message(message)
	_set_current_screen(SCREEN_GAME)
	_apply_post_action_environment_interrupt("active_item")
	_refresh()
	return true


func _use_global_active_item(item_id: String, detail: Dictionary) -> bool:
	var definition := library.item(item_id) if library != null else {}
	if definition.is_empty():
		_show_message("Item definition is missing.")
		_refresh()
		return false
	run_state.advance_environment_turns(1)
	var item_effect := ItemEffectScript.new()
	item_effect.setup(definition)
	var result := item_effect.apply({
		"domain": str(definition.get("domain", "global")),
		"domains": [str(definition.get("domain", "global")), "global"],
		"environment_id": str(run_state.current_environment.get("id", "")),
		"action_id": "use_active_item",
		"action_kind": "item",
	}, run_state)
	_play_result_drink_audio_cue(result)
	last_item_result = result.duplicate(true)
	last_game_result = {}
	last_hook_result = {}
	_select_first_active_item_from_result(result)
	var display_name := str(detail.get("display_name", item_id))
	var message := str(result.get("message", ""))
	if message.is_empty():
		var messages := _copy_array(result.get("messages", result.get("deltas", {}).get("messages", [])))
		message = str(messages[0]) if not messages.is_empty() else "%s used." % display_name
	_show_message(message)
	_set_current_screen(SCREEN_RESULT)
	_advance_alcohol_absorption()
	_autosave_foundation_run("Autosaved.")
	_apply_post_action_environment_interrupt("active_item")
	_refresh()
	return true


func _select_first_active_item_from_result(result: Dictionary) -> void:
	if run_state == null or run_action_service == null:
		return
	var deltas: Dictionary = result.get("deltas", {}) if typeof(result.get("deltas", {})) == TYPE_DICTIONARY else {}
	for item_id in _string_array(deltas.get("inventory_add", [])):
		var detail := run_action_service.inventory_item_detail(item_id)
		if not detail.is_empty() and bool(detail.get("active_item", false)):
			run_state.set_active_item(item_id)
			return


func _show_active_item_confirmation_popup(item: Dictionary) -> void:
	if event_choice_popup_overlay == null or event_choice_popup_choices_list == null:
		_use_active_item(str(item.get("id", "")))
		return
	var item_id := str(item.get("id", ""))
	pending_active_item_id = item_id
	pending_wager_confirm_action_id = ""
	var display_name := str(item.get("display_name", item_id))
	var mode := str(item.get("active_mode", ""))
	var target := str(item.get("active_target", ""))
	var description := str(item.get("description", ""))
	var summary := description
	if not target.is_empty():
		summary = "%s Target: %s." % [summary, target.replace("_", " ").capitalize()] if not summary.is_empty() else "Target: %s." % target.replace("_", " ").capitalize()
	pending_event_choice_popup_event_id = ""
	pending_event_choice_popup_focus_choice_id = ""
	pending_event_choice_popup_snapshot = {
		"visible": true,
		"blocking": true,
		"popup_type": "active_item_confirmation",
		"interaction_kind": "blocking_decision",
		"dismissible": false,
		"item_id": item_id,
		"item_label": display_name,
		"summary": summary,
	}
	if event_choice_popup_title_label != null:
		event_choice_popup_title_label.text = "Use %s" % display_name
	if event_choice_popup_summary_label != null:
		event_choice_popup_summary_label.text = summary
	_clear(event_choice_popup_choices_list)
	var impact := "Toggles this item." if mode == "toggle" else "Consumes this item." if mode == "consumable" else "Uses this item."
	_add_wager_confirmation_card("Use Item", "Activate %s now." % display_name, impact, Callable(self, "confirm_pending_active_item_use"), true)
	_add_wager_confirmation_card("Cancel", "Keep the item ready.", "No change.", Callable(self, "cancel_pending_active_item_use"), false)
	event_choice_popup_overlay.visible = true
	event_choice_popup_overlay.move_to_front()
	_position_event_choice_popup()
	call_deferred("_position_event_choice_popup")


func talk_to_shopkeeper() -> bool:
	if not _shopkeeper_available():
		_show_message("No merchant is working here.")
		_refresh()
		return false
	return open_shopkeeper_sale_page()


func open_shopkeeper_sale_page() -> bool:
	if not _shopkeeper_available():
		_show_message("You need a merchant to sell items.")
		_refresh()
		return false
	_open_run_inventory_popup("merchant_sale")
	return true


func sell_inventory_item(item_id: String) -> bool:
	if run_state == null or library == null:
		return false
	_refresh_run_action_service()
	var resolved := run_action_service.sell_inventory_item(item_id)
	if not bool(resolved.get("ok", false)):
		_show_message(str(resolved.get("message", "You need a merchant to sell items.")))
		_refresh()
		return false
	var result: Dictionary = resolved.get("result", {})
	last_item_result = result.duplicate(true)
	last_game_result = {}
	last_hook_result = {}
	_set_current_screen(SCREEN_RESULT)
	_show_message(str(result.get("message", "")))
	_advance_alcohol_absorption()
	_autosave_foundation_run("Autosaved.")
	_refresh()
	if _run_inventory_popup_is_visible():
		_open_run_inventory_popup("merchant_sale")
	return true


func repair_inventory_item(item_id: String) -> bool:
	if run_state == null or library == null:
		return false
	_refresh_run_action_service()
	var resolved := run_action_service.repair_inventory_item(item_id)
	if not bool(resolved.get("ok", false)):
		_show_message(str(resolved.get("message", "That item cannot be repaired.")))
		_refresh()
		return false
	var result: Dictionary = resolved.get("result", {})
	last_item_result = result.duplicate(true)
	last_game_result = {}
	last_hook_result = {}
	_set_current_screen(SCREEN_RESULT)
	_show_message(str(result.get("message", "")))
	_advance_alcohol_absorption()
	_autosave_foundation_run("Autosaved.")
	_refresh()
	if _run_inventory_popup_is_visible():
		_open_run_inventory_popup("merchant_sale")
	return true


# Selects a service hook without mutating simulation state.
func select_service_hook(service_id: String) -> bool:
	if _guard_player_input_route():
		return false
	var option := _service_hook(service_id)
	if option.is_empty():
		_show_message("That service is not available.")
		return false
	selected_service_hook_id = service_id
	selected_service_hook_label = str(option.get("display_name", service_id))
	selected_action_category = ACTION_CATEGORY_ITEMS
	_set_current_screen(SCREEN_ITEMS)
	focus_interactable_object("service:%s" % selected_service_hook_id)
	_show_message("%s: %s" % [selected_service_hook_label, str(option.get("status", ""))])
	_refresh()
	return true


# Confirms a selected service hook only when it has result-delta data.
func confirm_selected_service_hook() -> bool:
	if selected_service_hook_id.is_empty():
		_show_message("Select a service first.")
		return false
	return use_service_hook(selected_service_hook_id)


# Applies a supported service hook through the shared result-delta path.
func use_service_hook(service_id: String) -> bool:
	if _guard_player_input_route():
		return false
	var option := _service_hook(service_id)
	if option.is_empty():
		_show_message("That service is not available.")
		return false
	if not bool(option.get("mutation_supported", false)):
		_show_message(str(option.get("status", "This service is not usable yet.")))
		_refresh()
		return false
	if not bool(option.get("enabled", true)):
		_show_message(str(option.get("disabled_reason", "Service cannot be used right now.")))
		_refresh()
		return false
	_refresh_run_action_service()
	var inventory_before := _run_inventory_id_set()
	var resolved := run_action_service.use_hook("service", service_id)
	if not bool(resolved.get("ok", false)):
		_show_message(str(resolved.get("message", "This service is only informational right now.")))
		_refresh()
		return false
	var result: Dictionary = resolved.get("result", {})
	_show_item_found_popups(result, inventory_before)
	_play_result_drink_audio_cue(result)
	last_hook_result = result.duplicate(true)
	_clear_selected_service_hook()
	_set_current_screen(SCREEN_RESULT)
	_show_message(str(result.get("message", "")))
	_advance_alcohol_absorption()
	_autosave_foundation_run("Autosaved.")
	if _apply_post_action_environment_interrupt("service"):
		_refresh()
		return true
	_refresh()
	return true


# Selects a lender hook without mutating simulation state.
func select_lender_hook(lender_id: String) -> bool:
	if _guard_player_input_route():
		return false
	var option := _lender_hook(lender_id)
	if option.is_empty():
		_show_message("That lender is not available.")
		return false
	selected_lender_hook_id = lender_id
	selected_lender_hook_label = str(option.get("display_name", lender_id))
	selected_action_category = ACTION_CATEGORY_ITEMS
	_set_current_screen(SCREEN_ITEMS)
	focus_interactable_object("lender:%s" % selected_lender_hook_id)
	_show_message("%s: %s" % [selected_lender_hook_label, str(option.get("status", ""))])
	_refresh()
	return true


# Confirms a selected lender hook only when it has result-delta data.
func confirm_selected_lender_hook() -> bool:
	if selected_lender_hook_id.is_empty():
		_show_message("Select a lender first.")
		return false
	if _lender_is_pawn_counter(selected_lender_hook_id):
		return open_pawn_counter(selected_lender_hook_id)
	return use_lender_hook(selected_lender_hook_id)


# Applies a supported lender hook through the shared result-delta path.
func use_lender_hook(lender_id: String) -> bool:
	if _guard_player_input_route():
		return false
	var option := _lender_hook(lender_id)
	if option.is_empty():
		_show_message("That lender is not available.")
		return false
	if not bool(option.get("mutation_supported", false)):
		_show_message(str(option.get("status", "This lender is not usable yet.")))
		_refresh()
		return false
	if not bool(option.get("enabled", true)):
		_show_message(str(option.get("disabled_reason", "Lender cannot be used right now.")))
		_refresh()
		return false
	_refresh_run_action_service()
	var resolved := run_action_service.use_hook("lender", lender_id)
	if not bool(resolved.get("ok", false)):
		_show_message(str(resolved.get("message", "This lender is only informational right now.")))
		_refresh()
		return false
	var result: Dictionary = resolved.get("result", {})
	last_hook_result = result.duplicate(true)
	_start_conclusion_animation(result, _conclusion_animation_source_rect("lender:%s" % lender_id))
	_clear_selected_lender_hook()
	_set_current_screen(SCREEN_RESULT)
	_show_message(str(result.get("message", "")))
	_advance_alcohol_absorption()
	_autosave_foundation_run("Autosaved.")
	if _apply_post_action_environment_interrupt("lender"):
		_refresh()
		return true
	_refresh()
	return true


func repay_lender_debt(lender_id: String) -> bool:
	if run_state == null:
		return false
	if _guard_player_input_route():
		return false
	var status := run_state.lender_repayment_status(lender_id)
	if not bool(status.get("available", false)):
		_show_message(str(status.get("disabled_reason", "No active loan to repay.")))
		_refresh()
		return false
	if not bool(status.get("enabled", false)):
		_show_message(str(status.get("disabled_reason", "Not enough bankroll to repay this loan.")))
		_refresh()
		return false
	var result := run_state.repay_debt(str(status.get("debt_id", "")))
	if not bool(result.get("ok", false)):
		_show_message(str(result.get("message", "Could not settle this loan.")))
		_refresh()
		return false
	_clear_selected_lender_hook()
	_show_message(str(result.get("message", "Loan settled.")))
	_autosave_foundation_run("Autosaved.")
	_refresh()
	return true


func open_pawn_counter(lender_id: String = "") -> bool:
	if run_state == null:
		return false
	if _guard_player_input_route(false, "lender:%s" % lender_id):
		return false
	_refresh_run_action_service()
	if lender_id.strip_edges().is_empty():
		lender_id = _first_current_pawn_lender_id()
	var option := _lender_hook(lender_id)
	if option.is_empty() or not _lender_is_pawn_counter(lender_id):
		_show_message("Pawn counter is not available.")
		_refresh()
		return false
	_open_run_inventory_popup("pawn_counter", lender_id)
	_refresh()
	return true


func _pawn_counter_pawn_item(lender_id: String, item_id: String) -> void:
	_refresh_run_action_service()
	var resolved := run_action_service.pawn_inventory_item(item_id, lender_id)
	if not bool(resolved.get("ok", false)):
		_show_message(str(resolved.get("message", "Could not pawn that item.")))
		open_pawn_counter(lender_id)
		return
	var result: Dictionary = resolved.get("result", {}) if typeof(resolved.get("result", {})) == TYPE_DICTIONARY else {}
	# Pawn transactions happen outside a game result surface. Clear any stale
	# game-presentation hold before rebuilding Sal's popup so the credited cash
	# is visible and available immediately, without waiting for travel.
	_sync_presented_bankroll_to_actual()
	last_hook_result = result.duplicate(true)
	_start_conclusion_animation(result, _conclusion_animation_source_rect("lender:%s" % lender_id))
	_show_message(str(result.get("message", "Pawn ticket opened.")))
	_advance_alcohol_absorption()
	_autosave_foundation_run("Autosaved.")
	if _apply_post_action_environment_interrupt("lender"):
		_refresh()
		return
	open_pawn_counter(lender_id)


func _pawn_counter_redeem_ticket(lender_id: String, debt_id: String) -> void:
	if run_state == null:
		return
	if _guard_player_input_route():
		return
	var result := run_state.repay_debt(debt_id)
	if not bool(result.get("ok", false)):
		_show_message(str(result.get("message", "Could not redeem that ticket.")))
		open_pawn_counter(lender_id)
		return
	_sync_presented_bankroll_to_actual()
	_show_message(str(result.get("message", "Ticket redeemed.")))
	_autosave_foundation_run("Autosaved.")
	open_pawn_counter(lender_id)


func use_game_environment_hook(game_id: String, hook_id: String, action_id: String = "") -> bool:
	if run_state == null or library == null:
		return false
	if _guard_player_input_route():
		return false
	var game := _game_module_for_id(game_id)
	if game == null:
		_show_message("That game contact is not available.")
		_refresh()
		return false
	var resolved_action_id := action_id
	if resolved_action_id.is_empty():
		resolved_action_id = _game_environment_hook_action_id(game, hook_id)
	if resolved_action_id.is_empty():
		_show_message("That contact has nothing to do right now.")
		_refresh()
		return false
	var rng := run_state.create_rng()
	var command := game.environment_action_command(hook_id, resolved_action_id, run_state, run_state.current_environment, rng)
	if command.is_empty() or not bool(command.get("handled", false)):
		_show_message("That contact is not usable right now.")
		_refresh()
		return false
	var result: Dictionary = command.get("result", {})
	if result.is_empty():
		_show_message(str(command.get("message", "Nothing happens.")))
		_refresh()
		return true
	if bool(result.get("ok", false)):
		run_state.advance_environment_turns(1)
		GameModule.apply_result(run_state, result, rng)
		_play_result_drink_audio_cue(result)
		_advance_alcohol_absorption()
	last_hook_result = result.duplicate(true)
	last_game_result = {}
	last_item_result = {}
	_set_current_screen(SCREEN_RESULT)
	_show_message(str(result.get("message", "")))
	_autosave_foundation_run("Autosaved.")
	if bool(result.get("ok", false)) and _apply_post_action_environment_interrupt("game_hook"):
		_refresh()
		return true
	_refresh()
	return true


# Saves the current foundation run.
func save_foundation_run() -> void:
	_autosave_foundation_run("Saved run.", true)
	_refresh_run_menu()
	_refresh_start_screen()
	_refresh()


func _autosave_foundation_run(status_text: String = "Autosaved.", force: bool = false) -> bool:
	if run_state == null:
		return false
	if _is_meta_session():
		return false
	if dev_game_test_mode:
		save_status_message = "Practice sessions are not autosaved."
		return false
	# Never make a player action wait for disk I/O. The pending slot coalesces
	# rapid/repeating actions and the game-surface guard waits out animations.
	if not force:
		_queue_pending_autosave(status_text, 1 if _should_defer_autosave_for_web() else 0)
		return true
	return _write_foundation_run_save(status_text)


func _write_foundation_run_save(status_text: String = "Autosaved.") -> bool:
	if run_state == null:
		return false
	_checkpoint_current_game_surface_ui_state()
	_evaluate_run_terminal_state()
	if save_service == null:
		save_status_message = "Autosave unavailable."
		return false
	if procedural_music_player != null:
		run_state.remember_music_tempo_state(procedural_music_player.adaptive_tempo_save_state())
		run_state.remember_music_choreography_state(procedural_music_player.music_choreography_save_state())
	var error := save_service.save_run(run_state, autosave_slot_id)
	if error == OK:
		pending_autosave = false
		pending_autosave_status_text = "Autosaved."
		pending_autosave_after_frame = -1
		save_status_message = status_text
		if save_status_label != null:
			save_status_label.text = _save_status_text()
		_refresh_start_screen()
		return true
	save_status_message = "Autosave failed."
	return false


func _flush_pending_autosave_if_ready() -> void:
	if not pending_autosave:
		return
	if pending_autosave_after_frame >= 0 and Engine.get_process_frames() < pending_autosave_after_frame:
		return
	if _game_surface_autosave_blocked():
		return
	_write_foundation_run_save(pending_autosave_status_text)


func _queue_pending_autosave(status_text: String, defer_frames: int) -> void:
	pending_autosave = true
	pending_autosave_status_text = status_text
	pending_autosave_after_frame = maxi(pending_autosave_after_frame, Engine.get_process_frames() + maxi(0, defer_frames))
	save_status_message = "Autosave pending."


func _should_defer_autosave_for_game_surface() -> bool:
	return current_screen == SCREEN_GAME and current_game != null and not _run_menu_is_visible()


func _should_defer_autosave_for_web() -> bool:
	return OS.has_feature("web")


func _game_surface_autosave_blocked() -> bool:
	if not _should_defer_autosave_for_game_surface():
		return false
	if game_surface_canvas == null:
		return false
	var runtime_status := game_surface_canvas.surface_runtime_status()
	var animations: Dictionary = runtime_status.get("surface_animations", {}) if typeof(runtime_status.get("surface_animations", {})) == TYPE_DICTIONARY else {}
	for channel_value in animations.values():
		if typeof(channel_value) != TYPE_DICTIONARY:
			continue
		var channel: Dictionary = channel_value
		if bool(channel.get("active", false)):
			return true
	return false


# Loads the current foundation run.
func load_foundation_run() -> void:
	_load_foundation_run_from_slot(true)


func _load_foundation_run_from_slot(return_to_start_on_missing: bool) -> bool:
	if save_service == null:
		save_status_message = "Save service unavailable."
		_show_message("Save service unavailable.")
		_refresh_run_menu()
		return false
	var loaded: Variant = save_service.load_run(autosave_slot_id)
	var load_result := save_service.last_load_result()
	if loaded == null:
		var found_corrupt_save := bool(load_result.get("primary_exists", false)) or bool(load_result.get("backup_exists", false))
		save_status_message = "Saved run is corrupt." if found_corrupt_save else "No saved run is available."
		_show_message("Saved run is corrupt and no backup could be loaded." if found_corrupt_save else "No saved run found.")
		if return_to_start_on_missing:
			_set_current_screen(SCREEN_START)
			_refresh_start_screen()
			if run_state != null:
				_refresh()
		else:
			_refresh_run_menu()
		return false
	_reset_game_surface_runtime_state()
	pending_all_in_result_terminal_check = false
	pending_autosave = false
	pending_autosave_status_text = "Autosaved."
	pending_autosave_after_frame = -1
	run_item_icon_texture_cache.clear()
	run_state = loaded
	_configure_coach_for_run()
	_sync_presented_bankroll_to_actual()
	dev_game_test_mode = false
	_refresh_run_action_service()
	current_game = null
	last_game_result = _game_result_from_story_log(run_state.story_log)
	last_item_result = {}
	last_hook_result = {}
	if item_found_popup != null:
		item_found_popup.clear_all()
	_hide_event_choice_popup()
	_hide_run_inventory_popup()
	_hide_run_journal_popup()
	_hide_world_map_overlay()
	_hide_travel_transition()
	_clear_selected_game_action()
	_clear_selected_stake()
	_clear_selected_travel()
	_clear_selected_event_choice()
	_clear_selected_item_offer()
	_clear_selected_service_hook()
	_clear_selected_lender_hook()
	clear_interaction_focus()
	var loaded_from_backup := str(load_result.get("outcome", "")) == SaveService.LOAD_OUTCOME_BACKUP
	save_status_message = "Loaded backup save." if loaded_from_backup else "Loaded run."
	_set_current_screen(SCREEN_ENVIRONMENT)
	if procedural_music_player != null:
		procedural_music_player.sync_authored_arrangement_state(run_state.music_arrangement_state)
		procedural_music_player.sync_adaptive_tempo_state(run_state.music_tempo_state)
		procedural_music_player.sync_music_choreography_state(run_state.music_choreography_state)
	_show_message("%s: %s." % ["Recovered run from backup" if loaded_from_backup else "Run loaded", str(run_state.current_environment.get("display_name", "Environment"))])
	_hide_run_menu()
	_refresh()
	if run_state.grand_casino_duel_active(run_state.current_environment):
		if _enter_grand_casino_duel_surface():
			return true
	if _show_next_pending_triggered_event():
		_refresh()
	return true


func open_run_menu() -> void:
	if run_menu_overlay == null or current_screen == SCREEN_START:
		return
	if _guard_blocking_decision_or_transition():
		return
	if _world_map_overlay_is_visible() or _run_inventory_popup_is_visible() or _run_journal_popup_is_visible():
		_show_message(_blocking_modal_message())
		_refresh_modal_contract_owner()
		return
	_stop_surface_feature_music()
	_refresh_run_menu()
	run_menu_overlay.visible = true
	run_menu_overlay.move_to_front()


func close_run_menu() -> void:
	_hide_run_menu()
	_refresh()


func save_run_from_menu() -> void:
	if run_state == null:
		save_status_message = "No active run to save."
		_show_message("No active run to save.")
		_refresh_run_menu()
		return
	_autosave_foundation_run("Saved to Resume Slot.", true)
	_refresh_run_menu()
	_refresh()


func load_run_from_menu() -> void:
	_load_foundation_run_from_slot(false)


func abandon_run_from_menu() -> void:
	if run_state == null:
		_show_message("No active run to abandon.")
		_refresh_run_menu()
		return
	if run_state.run_status != RunState.RUN_STATUS_ACTIVE:
		_hide_run_menu()
		_refresh()
		return
	run_state.log_story({
		"type": "run_abandoned",
		"environment_id": str(run_state.current_environment.get("id", "")),
		"message": RunState.ABANDONED_FAILURE_MESSAGE,
	})
	run_state.fail_run(RunState.FAILURE_ABANDONED, RunState.ABANDONED_FAILURE_MESSAGE)
	save_status_message = "Run abandoned."
	_hide_run_menu()
	_route_failed_run_if_needed({"message": RunState.ABANDONED_FAILURE_MESSAGE})
	_refresh()


func _travel_to(target_id: String, target_label: String, choice_data: Dictionary = {}) -> void:
	if run_state == null:
		return
	if travel_transition_active:
		return
	var ignored_talk_entries: Array = []
	if choice_data.is_empty():
		choice_data = _travel_choice(target_id)
	var route := _copy_dict(choice_data.get("route", {}))
	if route.is_empty():
		route = _world_route_for_target(target_id)
	if route.is_empty():
		route = library.route(target_id) if library != null else {}
	if not bool(choice_data.get("enabled", true)):
		_show_message(str(choice_data.get("disabled_reason", "That route is not available right now.")))
		_refresh()
		return
	if _is_meta_session():
		var meta_target_id := target_id.strip_edges()
		if meta_target_id == META_LOCATION_START_RUN:
			start_meta_quick_run()
			return
		_enter_meta_location(meta_target_id)
		return
	var local_casino_room_move := bool(choice_data.get("local_casino_room", false))
	if local_casino_room_move and (not run_state.is_grand_casino_environment() or _environment_archetype(target_id).is_empty()):
		_show_message("That interior casino door is not available.")
		_refresh()
		return
	# Persist UI-local ticket reveals while the module still points at the
	# environment where the tickets were purchased.
	_reset_game_surface_runtime_state()
	var previous_environment := run_state.current_environment.duplicate(true)
	ignored_talk_entries = _pending_talk_entries()
	if world_map_overlay != null:
		world_map_overlay.visible = false
	_show_travel_transition(target_id, target_label, "Leaving %s..." % str(previous_environment.get("display_name", "this room")))
	_hide_event_choice_popup()
	_hide_run_inventory_popup()
	_hide_run_journal_popup()
	_show_message("Traveling to %s..." % target_label)
	_refresh()
	if _should_yield_for_travel_transition():
		await get_tree().process_frame
	var route_risk := {} if local_casino_room_move else run_state.travel_route_risk(route, target_id)
	var travel_heat := run_state.begin_travel_suspicion_decay(route, target_id)
	var force_walk := bool(choice_data.get("force_walk_fallback", false))
	var travel_method_kind := WorldMapScript.TRAVEL_METHOD_WALK if force_walk else WorldMapScript.travel_method_kind(route, str(choice_data.get("distance", route.get("distance", ""))))
	route["travel_method_kind"] = travel_method_kind
	route["travel_method"] = WorldMapScript.travel_method_label(travel_method_kind)
	if str(route.get("method", "")).strip_edges().is_empty() or force_walk:
		route["method"] = str(route.get("travel_method", ""))
	var travel_minutes := maxi(1, int(choice_data.get("travel_minutes", _travel_clock_minutes_for_route(route, force_walk))))
	var departed_game_clock_minutes := maxi(0, run_state.game_clock_minutes)
	route["travel_minutes"] = travel_minutes
	route["force_walk_fallback"] = force_walk
	route["departed_game_clock_minutes"] = departed_game_clock_minutes
	previous_environment["departed_game_clock_minutes"] = departed_game_clock_minutes
	run_state.current_environment["departed_game_clock_minutes"] = departed_game_clock_minutes
	run_state.advance_game_clock_minutes(travel_minutes)
	route["arrived_game_clock_minutes"] = maxi(departed_game_clock_minutes, run_state.game_clock_minutes)
	if local_casino_room_move:
		if not generator.enter_grand_casino_room(run_state, target_id):
			run_state.game_clock_minutes = departed_game_clock_minutes
			_hide_travel_transition()
			_show_message("The interior casino room could not be prepared.")
			_refresh()
			return
		if bool(choice_data.get("high_limit_buy_in", false)):
			run_state.narrative_flags["grand_casino_high_limit_access"] = true
			run_state.narrative_flags["grand_casino_high_limit_access_method"] = "cash_buy_in"
	else:
		generator.next_environment(run_state, target_id, true)
	run_state.clear_closing_time_state()
	var travel_decay := run_state.finish_travel_suspicion_decay(travel_heat)
	_update_procedural_music()
	current_game = null
	last_game_result = {}
	last_item_result = {}
	last_hook_result = {}
	_clear_selected_game_action()
	_clear_selected_stake()
	_clear_selected_travel()
	_clear_selected_event_choice()
	_clear_selected_item_offer()
	_clear_selected_service_hook()
	_clear_selected_lender_hook()
	clear_interaction_focus()
	var destination_name := str(run_state.current_environment.get("display_name", target_label))
	var travel_result := _travel_result(target_id, destination_name, route, previous_environment, run_state.current_environment, travel_decay, route_risk)
	var grand_casino_entry_cue := run_state.consume_grand_casino_entry_cue()
	if not grand_casino_entry_cue.is_empty():
		var cue_message := str(grand_casino_entry_cue.get("message", "")).strip_edges()
		if not cue_message.is_empty():
			travel_result["message"] = "%s %s" % [str(travel_result.get("message", "")), cue_message]
			var cue_deltas: Dictionary = travel_result.get("deltas", {}) if typeof(travel_result.get("deltas", {})) == TYPE_DICTIONARY else {}
			cue_deltas["messages"] = [str(travel_result.get("message", ""))]
			travel_result["deltas"] = cue_deltas
	if not ignored_talk_entries.is_empty():
		var ignore_message := _talk_ignore_message(ignored_talk_entries, "travel")
		travel_result["message"] = "%s %s" % [str(travel_result.get("message", "")), ignore_message]
		var travel_deltas: Dictionary = travel_result.get("deltas", {}) if typeof(travel_result.get("deltas", {})) == TYPE_DICTIONARY else {}
		travel_deltas["messages"] = [str(travel_result.get("message", ""))]
		travel_result["deltas"] = travel_deltas
	GameModule.apply_result(run_state, travel_result)
	if not ignored_talk_entries.is_empty():
		_apply_talk_ignore_penalty(ignored_talk_entries, "travel")
	last_hook_result = travel_result.duplicate(true)
	_set_current_screen(SCREEN_RESULT)
	_show_message(str(travel_result.get("message", "Travel complete: %s." % destination_name)))
	_advance_alcohol_absorption()
	_autosave_foundation_run("Autosaved.")
	_refresh()
	if travel_transition_active:
		_update_travel_transition("Arrived at %s" % destination_name, "The room is ready.")
		if _should_yield_for_travel_transition():
			await get_tree().process_frame
	_hide_travel_transition()
	var travel_context := {
		"trigger": "travel",
		"type": "travel",
		"source": "travel",
		"target_id": target_id,
		"travel_method_kind": travel_method_kind,
		"travel_method": WorldMapScript.travel_method_label(travel_method_kind),
		"turns": int(previous_environment.get("turns", 0)),
	}
	if _enqueue_triggered_events_for_context("travel", travel_context, previous_environment):
		_autosave_foundation_run("Autosaved.")
		if _show_next_pending_triggered_event():
			_refresh()
		else:
			_refresh_talk_dock()
			_refresh()


func _linda_cage_choice_status(choice_id: String) -> Dictionary:
	if run_state == null:
		return {"enabled": false, "reason": "No active run."}
	var model := CageCounterViewModelScript.build(run_state)
	var balance: Dictionary = model.get("balance", {}) if typeof(model.get("balance", {})) == TYPE_DICTIONARY else {}
	var card: Dictionary = model.get("card", {}) if typeof(model.get("card", {})) == TYPE_DICTIONARY else {}
	match choice_id:
		"cage_buy_25":
			var cost_25 := 25 * maxi(1, int(balance.get("rate", 1)))
			return {"enabled": run_state.bankroll >= cost_25, "reason": "Needs $%d cash." % cost_25}
		"cage_buy_50":
			var cost_50 := 50 * maxi(1, int(balance.get("rate", 1)))
			return {"enabled": run_state.bankroll >= cost_50, "reason": "Needs $%d cash." % cost_50}
		"cage_cashout_all":
			return {"enabled": run_state.grand_casino_chips > 0, "reason": "No chips to redeem."}
		"cage_claim_card":
			return {"enabled": bool(card.get("can_claim", false)), "reason": str(card.get("review_detail", "No tier is ready."))}
		"cage_comp_drink":
			var drink_status := run_state.grand_casino_players_card_comp_result("drink")
			return {"enabled": bool(drink_status.get("ok", false)), "reason": str(drink_status.get("message", "No drink comp is ready."))}
		"cage_comp_suite":
			var suite_status := run_state.grand_casino_players_card_comp_result("suite_rest")
			return {"enabled": bool(suite_status.get("ok", false)), "reason": str(suite_status.get("message", "No suite rest is ready."))}
		"cage_comp_look_away":
			return {"enabled": bool(run_state.narrative_flags.get("grand_casino_linda_look_away_available", false)), "reason": "Linda has no look-away ready."}
	return {}


func _resolve_linda_cage_service_choice(entry: Dictionary, choice_id: String) -> void:
	var status := _linda_cage_choice_status(choice_id)
	if not bool(status.get("enabled", true)):
		_show_message(str(status.get("reason", "That counter action is unavailable.")))
		_refresh_talk_dock()
		_refresh()
		return
	match choice_id:
		"cage_buy_25":
			_buy_cage_chips(25)
		"cage_buy_50":
			_buy_cage_chips(50)
		"cage_cashout_all":
			_cash_out_cage_chips()
		"cage_claim_card":
			run_state.complete_talk_event_resolution(str(entry.get("event_id", "")))
			_refresh_talk_dock()
			_complete_cage_players_card_review()
		"cage_comp_drink":
			_use_cage_players_card_comp("drink")
		"cage_comp_suite":
			_use_cage_players_card_comp("suite_rest")
		"cage_comp_look_away":
			_show_message("Linda will look away automatically from the next small heat gain. It is ready now.")
		"cage_ambient":
			run_state.complete_talk_event_resolution(str(entry.get("event_id", "")))
			_refresh_talk_dock()
			_start_linda_ambient_dialogue({"object_id": "casino_fixture:cage_counter"})
	_refresh_talk_dock()
	_refresh()


func _travel_result(target_id: String, destination_name: String, route: Dictionary, previous_environment: Dictionary, destination_environment: Dictionary, travel_decay: Dictionary = {}, route_risk: Dictionary = {}) -> Dictionary:
	var route_status := run_state.travel_route_status(route)
	var travel_method_kind := WorldMapScript.travel_method_kind(route, str(route_status.get("distance", route.get("distance", ""))))
	var travel_method := WorldMapScript.travel_method_label(travel_method_kind)
	var cost := int(route_status.get("cost", 0))
	var suspicion_delta := int(route_status.get("suspicion_delta", 0))
	var risk_bankroll_delta := int(route_risk.get("bankroll_delta", 0)) if bool(route_risk.get("triggered", false)) else 0
	var risk_suspicion_delta := int(route_risk.get("suspicion_delta", 0)) if bool(route_risk.get("triggered", false)) else 0
	var cooled := int(travel_decay.get("cooled", 0))
	var risk_decay := int(travel_decay.get("risk_decay", route_status.get("risk_decay", 0)))
	var message := "Traveled to %s." % destination_name
	var detail_parts: Array = []
	if cost > 0:
		detail_parts.append("Route cost %d" % cost)
	var travel_minutes := maxi(0, int(route.get("travel_minutes", 0)))
	if travel_minutes > 0:
		detail_parts.append("%d min" % travel_minutes)
	if bool(route.get("force_walk_fallback", false)):
		detail_parts.append("walked out")
	if cooled > 0:
		detail_parts.append("distance shakes most heat" if risk_decay >= 70 else "distance shakes some heat")
	var drunk_delta := int(travel_decay.get("drunk_delta", 0))
	if drunk_delta < 0:
		detail_parts.append("travel sobers you %+d" % drunk_delta)
	if suspicion_delta > 0:
		detail_parts.append("risk +%d" % suspicion_delta)
	if risk_bankroll_delta != 0 or risk_suspicion_delta != 0:
		var risk_label := str(route_risk.get("label", "route risk"))
		var risk_detail := "%s" % risk_label
		if risk_bankroll_delta != 0:
			risk_detail += " %+d" % risk_bankroll_delta
		if risk_suspicion_delta > 0:
			risk_detail += ", heat +%d" % risk_suspicion_delta
		detail_parts.append(risk_detail)
	if not detail_parts.is_empty():
		message = "%s %s." % [message, ", ".join(detail_parts)]
	var total_bankroll_delta := -cost + risk_bankroll_delta
	var total_suspicion_delta := suspicion_delta + risk_suspicion_delta
	var story_entry := {
		"type": "travel",
		"id": target_id,
		"route_id": target_id,
		"from_environment_id": str(previous_environment.get("id", "")),
		"from_environment_name": str(previous_environment.get("display_name", "")),
		"from_world_node_id": str(previous_environment.get("world_node_id", previous_environment.get("archetype_id", ""))),
		"to_archetype_id": target_id,
		"to_environment_id": str(destination_environment.get("id", "")),
		"to_environment_name": destination_name,
		"to_world_node_id": str(destination_environment.get("world_node_id", destination_environment.get("archetype_id", target_id))),
		"departed_game_clock_minutes": maxi(0, int(route.get("departed_game_clock_minutes", run_state.game_clock_minutes - travel_minutes))),
		"arrived_game_clock_minutes": maxi(0, int(route.get("arrived_game_clock_minutes", run_state.game_clock_minutes))),
		"bankroll_delta": total_bankroll_delta,
		"route_cost": cost,
		"travel_minutes": travel_minutes,
		"force_walk_fallback": bool(route.get("force_walk_fallback", false)),
		"suspicion_delta": total_suspicion_delta,
		"route_suspicion_delta": suspicion_delta,
		"travel_distance": str(travel_decay.get("distance", route_status.get("distance", ""))),
		"travel_method_kind": travel_method_kind,
		"travel_method": travel_method,
		"risk_decay": risk_decay,
		"risk_cooled": cooled,
		"route_risk": route_risk.duplicate(true),
		"drunk_delta": drunk_delta,
		"drunk_after": int(travel_decay.get("drunk_after", run_state.drunk_level)),
		"message": message,
	}
	var story_entries: Array = [story_entry]
	if bool(route_risk.get("triggered", false)):
		var risk_message := str(route_risk.get("message", "The route risk catches you."))
		story_entries.append({
			"type": "travel_risk_event",
			"id": str(route_risk.get("id", "travel_risk")),
			"route_id": target_id,
			"label": str(route_risk.get("label", "Route risk")),
			"roll": int(route_risk.get("roll", 0)),
			"chance_percent": int(route_risk.get("chance_percent", 0)),
			"bankroll_delta": risk_bankroll_delta,
			"suspicion_delta": risk_suspicion_delta,
			"message": risk_message,
		})
	var deltas := GameModule.empty_result_deltas()
	deltas["bankroll_delta"] = total_bankroll_delta
	deltas["suspicion_delta"] = total_suspicion_delta
	deltas["story_log"] = story_entries
	deltas["messages"] = [message]
	return GameModule.build_action_result({
		"ok": true,
		"type": "travel",
		"source_id": target_id,
		"action_id": "confirm_travel",
		"action_kind": "travel",
		"environment_id": str(destination_environment.get("id", "")),
		"environment_archetype_id": target_id,
		"bankroll_delta": total_bankroll_delta,
		"suspicion_delta": total_suspicion_delta,
		"route_cost": cost,
		"travel_method_kind": travel_method_kind,
		"travel_method": travel_method,
		"route_risk": route_risk.duplicate(true),
		"deltas": deltas,
		"message": message,
	})


func _show_travel_transition(target_id: String, target_label: String, detail: String = "") -> void:
	travel_transition_active = true
	travel_transition_target_id = target_id
	travel_transition_target_label = target_label
	_update_travel_transition("Traveling to %s" % target_label, detail)
	if travel_transition_overlay != null:
		travel_transition_overlay.visible = true
		travel_transition_overlay.move_to_front()


func _update_travel_transition(title: String, detail: String = "") -> void:
	if travel_transition_title_label != null:
		travel_transition_title_label.text = title
	if travel_transition_body_label != null:
		travel_transition_body_label.text = detail if not detail.strip_edges().is_empty() else "Building the next room..."


func _hide_travel_transition() -> void:
	travel_transition_active = false
	travel_transition_target_id = ""
	travel_transition_target_label = ""
	if travel_transition_overlay != null:
		travel_transition_overlay.visible = false


func _should_yield_for_travel_transition() -> bool:
	return DisplayServer.get_name().to_lower() != "headless" and is_inside_tree()


func _initialize_foundation() -> void:
	_mark_boot_event("foundation_init_start")
	library = ContentLibrary.new()
	_mark_boot_event("content_library_load_start")
	library.load()
	_surface_content_validation_errors(library, true)
	AttributeBadgeRowScript.warm_all_glyphs(12)
	AttributeBadgeRowScript.warm_all_glyphs(14)
	AttributeBadgeRowScript.warm_all_glyphs(16)
	_mark_boot_event("content_library_load_complete", library.load_timing_snapshot())
	game_module_cache = {}
	generator = RunGenerator.new(library)
	save_service = SaveService.new()
	platform_services = PlatformServices.new()
	platform_services.setup("local")
	platform_services.initialize()
	run_action_service = RunActionServiceScript.new()
	_refresh_run_action_service()
	_mark_boot_event("foundation_init_complete")


func boot_telemetry_snapshot() -> Dictionary:
	return {
		"start_msec": boot_start_msec,
		"uptime_msec": maxi(0, Time.get_ticks_msec() - boot_start_msec),
		"events": boot_telemetry_events.duplicate(true),
		"content_library": library.load_timing_snapshot() if library != null else {},
		"content_library_stats": library.debug_soak_snapshot() if library != null else {},
	}


func debug_surface_content_validation_errors(source_library: ContentLibrary, emit_console: bool = false) -> Dictionary:
	return _surface_content_validation_errors(source_library, emit_console)


func _surface_content_validation_errors(source_library: ContentLibrary, emit_console: bool) -> Dictionary:
	content_validation_status_message = ""
	content_validation_error_count = 0
	if source_library == null:
		return {"error_count": 0, "message": ""}
	var errors := source_library.validation_errors.duplicate()
	content_validation_error_count = errors.size()
	if content_validation_error_count <= 0:
		return {"error_count": 0, "message": ""}
	if OS.is_debug_build():
		content_validation_status_message = "Content validation: %d errors - see console." % content_validation_error_count
	if emit_console:
		for error_value in errors:
			var message := "Content validation: %s" % str(error_value)
			if OS.is_debug_build():
				push_error(message)
			else:
				push_warning(message)
	return {
		"error_count": content_validation_error_count,
		"message": content_validation_status_message,
	}


func _mark_boot_event(event_id: String, data: Dictionary = {}) -> void:
	var now := Time.get_ticks_msec()
	if boot_start_msec <= 0:
		boot_start_msec = now
	boot_telemetry_events.append({
		"id": event_id,
		"msec": now,
		"relative_msec": maxi(0, now - boot_start_msec),
		"data": data.duplicate(true),
	})


func _project_autoload_count() -> int:
	var count := 0
	for property_info in ProjectSettings.get_property_list():
		if typeof(property_info) != TYPE_DICTIONARY:
			continue
		var property_name := str((property_info as Dictionary).get("name", ""))
		if property_name.begins_with("autoload/"):
			count += 1
	return count


func _refresh_run_action_service() -> void:
	if run_action_service == null:
		run_action_service = RunActionServiceScript.new()
	run_action_service.setup(library, run_state)


func _main_menu_background_environment_id() -> String:
	if library == null:
		return ""
	for archetype in library.environment_archetypes:
		if typeof(archetype) != TYPE_DICTIONARY:
			continue
		var data: Dictionary = archetype
		if bool(data.get("is_start", false)) and _string_array(data.get("moods", [])).has("wet"):
			return str(data.get("id", ""))
	for archetype in library.environment_archetypes:
		if typeof(archetype) != TYPE_DICTIONARY:
			continue
		var data: Dictionary = archetype
		if bool(data.get("is_start", false)):
			return str(data.get("id", ""))
	if not library.environment_archetypes.is_empty() and typeof(library.environment_archetypes[0]) == TYPE_DICTIONARY:
		return str((library.environment_archetypes[0] as Dictionary).get("id", ""))
	return ""


func _initialize_user_settings() -> void:
	user_settings = UserSettingsScript.new()
	user_settings.load()
	selected_home_type_id = user_settings.selected_home_type_id
	VisualStyle.set_high_contrast_enabled(user_settings.high_contrast)
	user_settings.apply()


func _initialize_profile_inventory() -> void:
	profile_inventory = ProfileInventoryScript.new()
	profile_inventory.load()


func _sync_scratch_ticket_discovery_to_run() -> void:
	if run_state == null or profile_inventory == null:
		return
	run_state.narrative_flags["scratch_ticket_types_discovered"] = profile_inventory.scratch_ticket_types_discovered.duplicate()


func _record_scratch_ticket_discovery(type_id: String) -> void:
	var normalized := type_id.strip_edges()
	if normalized.is_empty() or profile_inventory == null:
		return
	if profile_inventory.discover_scratch_ticket_type(normalized):
		profile_inventory.save()
	_sync_scratch_ticket_discovery_to_run()


func _initialize_meta_collection() -> void:
	meta_collection_service = MetaCollectionServiceScript.new()
	meta_collection_service.load()
	meta_session_controller = MetaSessionControllerScript.new()
	meta_session_controller.configure(library, meta_collection_service)
	collection_drop_service = CollectionDropServiceScript.new()


func _initialize_procedural_music() -> void:
	procedural_music_player = ProceduralMusicPlayerScript.new()
	procedural_music_player.audio_calm = user_settings != null and bool(user_settings.audio_calm)
	procedural_music_player.authored_phrase_event.connect(_on_authored_music_phrase_event)
	procedural_music_player.authored_arrangement_selected.connect(_on_authored_music_arrangement_selected)
	procedural_music_player.music_outcome_scheduled.connect(_on_music_outcome_scheduled)
	add_child(procedural_music_player)


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = VisualStyle.DARK
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 0)
	root.add_theme_constant_override("margin_right", 0)
	root.add_theme_constant_override("margin_top", 0)
	root.add_theme_constant_override("margin_bottom", 0)
	add_child(root)

	var screen_stack := Control.new()
	screen_stack.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	screen_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(screen_stack)

	start_screen = Control.new()
	start_screen.clip_contents = true
	start_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	start_screen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	screen_stack.add_child(start_screen)
	_build_start_screen()

	run_screen = Control.new()
	run_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	run_screen.clip_contents = true
	run_screen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	run_screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	screen_stack.add_child(run_screen)
	_build_run_screen()
	_build_talk_dock()
	_build_run_menu_overlay()
	_build_settings_overlay()
	_build_event_choice_popup_overlay()
	_build_conclusion_animation_overlay()
	_build_run_inventory_overlay()
	_build_meta_item_interaction_overlay()
	_build_run_journal_overlay()
	_build_travel_transition_overlay()
	_build_world_map_overlay()
	_build_item_found_popup()
	_build_coach_overlay()
	_apply_accessibility_settings()


func _build_start_screen() -> void:
	FoundationScreenBuilderScript.build_start_screen(self)


func _build_content_group_controls(parent: VBoxContainer) -> void:
	_ensure_menu_content_groups_initialized()
	var panel := _panel_container(Color("#070916", 0.92), VisualStyle.CYAN_2)
	panel.visible = false
	panel.custom_minimum_size = Vector2(0, 230)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	parent.add_child(panel)
	content_group_panel = panel
	var panel_margin := MarginContainer.new()
	panel_margin.add_theme_constant_override("margin_left", 12)
	panel_margin.add_theme_constant_override("margin_top", 10)
	panel_margin.add_theme_constant_override("margin_right", 12)
	panel_margin.add_theme_constant_override("margin_bottom", 10)
	panel_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(panel_margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel_margin.add_child(stack)
	var heading_row := HBoxContainer.new()
	heading_row.add_theme_constant_override("separation", 8)
	heading_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	heading_row.custom_minimum_size = Vector2(0, 34)
	stack.add_child(heading_row)
	var heading := _label("Run Content", 14)
	heading.custom_minimum_size = Vector2(132, 28)
	heading.autowrap_mode = TextServer.AUTOWRAP_OFF
	heading.clip_text = true
	_set_control_font_color(heading, VisualStyle.YELLOW)
	heading_row.add_child(heading)
	content_group_status_label = _label("", 11)
	content_group_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_group_status_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content_group_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	content_group_status_label.clip_text = true
	_set_control_font_color(content_group_status_label, VisualStyle.CYAN_2)
	heading_row.add_child(content_group_status_label)
	var done_button := _button("Done", Callable(self, "close_content_group_config"))
	done_button.custom_minimum_size = Vector2(88, MIN_NATIVE_TOUCH_TARGET_HEIGHT)
	done_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	done_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_set_control_font_size(done_button, 12)
	heading_row.add_child(done_button)
	var home_row := HBoxContainer.new()
	home_row.add_theme_constant_override("separation", 8)
	home_row.custom_minimum_size = Vector2(0, 34)
	home_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_child(home_row)
	var home_label := _label("Home", 12)
	home_label.custom_minimum_size = Vector2(92, 30)
	_set_control_font_color(home_label, VisualStyle.YELLOW)
	home_row.add_child(home_label)
	home_type_option = OptionButton.new()
	home_type_option.custom_minimum_size = Vector2(0, MIN_NATIVE_TOUCH_TARGET_HEIGHT)
	home_type_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_set_control_font_color(home_type_option, VisualStyle.WHITE)
	_set_control_font_size(home_type_option, 12)
	home_type_option.item_selected.connect(_on_home_type_selected)
	home_row.add_child(home_type_option)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 164)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	stack.add_child(scroll)
	content_group_list = GridContainer.new()
	content_group_list.columns = 3
	content_group_list.add_theme_constant_override("h_separation", 10)
	content_group_list.add_theme_constant_override("v_separation", 6)
	content_group_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content_group_list)
	_rebuild_content_group_toggles()
	_refresh_content_group_controls()


func _build_challenge_controls(parent: VBoxContainer) -> void:
	var panel := _panel_container(Color("#070916", 0.92), VisualStyle.PINK_2)
	panel.visible = false
	panel.custom_minimum_size = Vector2(0, 230)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	parent.add_child(panel)
	challenge_panel = panel
	var panel_margin := MarginContainer.new()
	panel_margin.add_theme_constant_override("margin_left", 12)
	panel_margin.add_theme_constant_override("margin_top", 10)
	panel_margin.add_theme_constant_override("margin_right", 12)
	panel_margin.add_theme_constant_override("margin_bottom", 10)
	panel_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(panel_margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel_margin.add_child(stack)
	var heading_row := HBoxContainer.new()
	heading_row.add_theme_constant_override("separation", 8)
	heading_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	heading_row.custom_minimum_size = Vector2(0, 34)
	stack.add_child(heading_row)
	var heading := _label("Challenges", 14)
	heading.custom_minimum_size = Vector2(132, 28)
	heading.autowrap_mode = TextServer.AUTOWRAP_OFF
	heading.clip_text = true
	_set_control_font_color(heading, VisualStyle.YELLOW)
	heading_row.add_child(heading)
	challenge_status_label = _label("", 11)
	challenge_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	challenge_status_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	challenge_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	challenge_status_label.clip_text = true
	_set_control_font_color(challenge_status_label, VisualStyle.CYAN_2)
	heading_row.add_child(challenge_status_label)
	var done_button := _button("Done", Callable(self, "close_challenge_selection"))
	done_button.custom_minimum_size = Vector2(88, MIN_NATIVE_TOUCH_TARGET_HEIGHT)
	done_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	done_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_set_control_font_size(done_button, 12)
	heading_row.add_child(done_button)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 164)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	stack.add_child(scroll)
	challenge_list = VBoxContainer.new()
	challenge_list.add_theme_constant_override("separation", 6)
	challenge_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(challenge_list)
	_rebuild_challenge_options()
	_refresh_challenge_controls()


func _apply_main_menu_panel_size(size: Vector2) -> void:
	if main_menu_panel == null:
		return
	var viewport_size := get_viewport_rect().size
	var max_size := Vector2(
		maxf(1.0, viewport_size.x - MAIN_MENU_VIEWPORT_MARGIN.x * 2.0),
		maxf(1.0, viewport_size.y - MAIN_MENU_VIEWPORT_MARGIN.y * 2.0)
	)
	var applied_size := Vector2(minf(size.x, max_size.x), minf(size.y, max_size.y))
	var centered_top := -applied_size.y * 0.5
	var min_top := -viewport_size.y * 0.5 + MAIN_MENU_VIEWPORT_MARGIN.y
	var max_top := viewport_size.y * 0.5 - MAIN_MENU_VIEWPORT_MARGIN.y - applied_size.y
	var top_offset := centered_top
	if max_top >= min_top:
		top_offset = clampf(centered_top, min_top, max_top)
	else:
		top_offset = min_top
	main_menu_panel.custom_minimum_size = applied_size
	main_menu_panel.offset_left = -applied_size.x * 0.5
	main_menu_panel.offset_top = top_offset
	main_menu_panel.offset_right = applied_size.x * 0.5
	main_menu_panel.offset_bottom = top_offset + applied_size.y


func toggle_content_group_config() -> void:
	if content_group_panel == null:
		return
	if content_group_panel.visible:
		close_content_group_config()
	else:
		open_content_group_config()


func open_content_group_config() -> void:
	if content_group_panel == null:
		return
	if challenge_panel != null:
		challenge_panel.visible = false
	_ensure_menu_content_groups_initialized()
	_refresh_content_group_controls()
	if start_menu_intro != null:
		start_menu_intro.visible = false
	_set_start_menu_action_controls_visible(false)
	content_group_panel.visible = true
	_apply_main_menu_panel_size(MAIN_MENU_EXPANDED_SIZE)


func close_content_group_config() -> void:
	if content_group_panel != null:
		content_group_panel.visible = false
	if challenge_panel != null and challenge_panel.visible:
		return
	if start_menu_intro != null:
		start_menu_intro.visible = true
	_set_start_menu_action_controls_visible(true)
	_apply_main_menu_panel_size(MAIN_MENU_COLLAPSED_SIZE)


func toggle_challenge_selection() -> void:
	if challenge_panel == null or not _challenge_pack_loaded():
		return
	if challenge_panel.visible:
		close_challenge_selection()
	else:
		open_challenge_selection()


func open_challenge_selection() -> void:
	if challenge_panel == null or not _challenge_pack_loaded():
		return
	if content_group_panel != null:
		content_group_panel.visible = false
	_rebuild_challenge_options()
	_refresh_challenge_controls()
	if start_menu_intro != null:
		start_menu_intro.visible = false
	_set_start_menu_action_controls_visible(false)
	challenge_panel.visible = true
	_apply_main_menu_panel_size(MAIN_MENU_EXPANDED_SIZE)


func close_challenge_selection() -> void:
	if challenge_panel != null:
		challenge_panel.visible = false
	if content_group_panel != null and content_group_panel.visible:
		return
	if start_menu_intro != null:
		start_menu_intro.visible = true
	_set_start_menu_action_controls_visible(true)
	_apply_main_menu_panel_size(MAIN_MENU_COLLAPSED_SIZE)


func _set_start_menu_action_controls_visible(is_visible: bool) -> void:
	for control in start_menu_action_controls:
		if is_instance_valid(control):
			control.visible = is_visible


func _rebuild_content_group_toggles() -> void:
	if content_group_list == null:
		return
	for child in content_group_list.get_children():
		child.queue_free()
	content_group_toggles = {}
	if library == null:
		return
	for option_value in library.content_group_options(selected_content_group_ids):
		if typeof(option_value) != TYPE_DICTIONARY:
			continue
		var option: Dictionary = option_value
		var group_id := str(option.get("id", ""))
		if group_id.is_empty():
			continue
		var check := CheckBox.new()
		check.text = str(option.get("display_name", group_id.capitalize()))
		check.tooltip_text = str(option.get("description", ""))
		check.button_pressed = bool(option.get("selected", false))
		check.custom_minimum_size = Vector2(0, 30)
		check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_set_control_font_color(check, VisualStyle.WHITE)
		_set_control_font_size(check, 11)
		check.toggled.connect(Callable(self, "_on_content_group_toggled").bind(group_id))
		content_group_list.add_child(check)
		content_group_toggles[group_id] = check


func _ensure_menu_content_groups_initialized() -> void:
	if library == null:
		return
	if selected_content_group_ids.is_empty():
		selected_content_group_ids = library.default_content_group_ids()


func _on_content_group_toggled(pressed: bool, group_id: String) -> void:
	if library == null or group_id.is_empty():
		return
	var selected := _selected_content_group_set()
	if pressed:
		selected[group_id] = true
	else:
		selected.erase(group_id)
	selected_content_group_ids = library.normalize_content_group_ids(selected.keys())
	_refresh_content_group_controls()


func _refresh_content_group_controls() -> void:
	if library == null:
		return
	selected_content_group_ids = library.normalize_content_group_ids(selected_content_group_ids)
	selected_home_type_id = _normalize_home_type_id(selected_home_type_id)
	_refresh_home_type_controls()
	var selected := _selected_content_group_set()
	for group_id in content_group_toggles.keys():
		var check := content_group_toggles[group_id] as CheckBox
		if check == null:
			continue
		var should_press := bool(selected.get(str(group_id), false))
		if check.button_pressed != should_press:
			check.set_pressed_no_signal(should_press)
	if content_group_status_label != null:
		var selected_count := selected_content_group_ids.size()
		var total_count := library.content_groups.size()
		content_group_status_label.text = "%d of %d groups enabled" % [selected_count, total_count]


func _refresh_home_type_controls() -> void:
	if home_type_option == null:
		return
	home_type_option.clear()
	var options := _home_type_options()
	var selected_index := 0
	for index in range(options.size()):
		var option: Dictionary = options[index]
		var option_id := str(option.get("id", RunState.HOME_SELECTION_RANDOM))
		home_type_option.add_item(str(option.get("label", option_id.capitalize())))
		home_type_option.set_item_metadata(index, option_id)
		if option_id == selected_home_type_id:
			selected_index = index
	home_type_option.select(selected_index)
	home_type_option.tooltip_text = "Choose the home this run starts in."


func _home_type_options() -> Array:
	var options: Array = [{"id": RunState.HOME_SELECTION_RANDOM, "label": "Random"}]
	if library == null:
		return options
	for archetype_value in library.environment_archetypes:
		if typeof(archetype_value) != TYPE_DICTIONARY:
			continue
		var archetype: Dictionary = archetype_value
		if str(archetype.get("kind", "")) != "home":
			continue
		var home_id := str(archetype.get("id", "")).strip_edges()
		if home_id.is_empty():
			continue
		options.append({
			"id": home_id,
			"label": _home_type_label(archetype),
		})
	return options


func _home_type_label(archetype: Dictionary) -> String:
	var display_name := str(archetype.get("display_name", "")).strip_edges()
	if not display_name.is_empty():
		return display_name
	var nouns := _string_array(archetype.get("name_nouns", []))
	if not nouns.is_empty():
		return str(nouns[0])
	return str(archetype.get("id", "Home")).replace("_", " ").capitalize()


func _normalize_home_type_id(home_id: String) -> String:
	var clean_id := home_id.strip_edges()
	if clean_id.is_empty():
		return RunState.HOME_SELECTION_RANDOM
	if clean_id == RunState.HOME_SELECTION_RANDOM:
		return clean_id
	if library == null:
		return clean_id
	for option in _home_type_options():
		if typeof(option) == TYPE_DICTIONARY and str((option as Dictionary).get("id", "")) == clean_id:
			return clean_id
	return RunState.HOME_SELECTION_RANDOM


func _on_home_type_selected(index: int) -> void:
	if home_type_option == null:
		return
	var selected_id := RunState.HOME_SELECTION_RANDOM
	var metadata: Variant = home_type_option.get_item_metadata(index)
	if metadata != null:
		selected_id = str(metadata)
	selected_home_type_id = _normalize_home_type_id(selected_id)
	if user_settings != null:
		user_settings.selected_home_type_id = selected_home_type_id
		user_settings.save()
	_refresh_home_type_controls()


func _challenge_pack_loaded() -> bool:
	return library != null and not library.challenges.is_empty()


func _rebuild_challenge_options() -> void:
	if challenge_list == null:
		return
	for child in challenge_list.get_children():
		child.queue_free()
	challenge_buttons = {}
	if not _challenge_pack_loaded():
		return
	var standard_button := _challenge_option_button("Standard Run", "Use the seed and run content settings.", "")
	challenge_list.add_child(standard_button)
	challenge_buttons[""] = standard_button
	for option_value in library.challenge_options(selected_challenge_id):
		if typeof(option_value) != TYPE_DICTIONARY:
			continue
		var option: Dictionary = option_value
		var challenge_id := str(option.get("id", "")).strip_edges()
		if challenge_id.is_empty():
			continue
		var title := str(option.get("title", challenge_id.capitalize()))
		var description := str(option.get("description", ""))
		var completion_flag := str(option.get("completion_flag", ""))
		var completed := profile_inventory != null and profile_inventory.has_challenge_completion(completion_flag)
		var button_title := "%s (Complete)" % title if completed else title
		var button := _challenge_option_button(button_title, description, challenge_id)
		challenge_list.add_child(button)
		challenge_buttons[challenge_id] = button
	_refresh_challenge_controls()


func _challenge_option_button(title: String, description: String, challenge_id: String) -> Button:
	var button := _button(title, Callable(self, "_on_challenge_selected").bind(challenge_id))
	button.tooltip_text = description
	button.custom_minimum_size = Vector2(0, MIN_NATIVE_TOUCH_TARGET_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_set_control_font_size(button, 12)
	return button


func _on_challenge_selected(challenge_id: String) -> void:
	selected_challenge_id = challenge_id.strip_edges()
	if not selected_challenge_id.is_empty() and library.challenge(selected_challenge_id).is_empty():
		selected_challenge_id = ""
	_refresh_challenge_controls()
	close_challenge_selection()


func _refresh_challenge_controls() -> void:
	var has_challenges := _challenge_pack_loaded()
	if challenge_select_button != null:
		challenge_select_button.visible = has_challenges
		challenge_select_button.disabled = not has_challenges
	if not has_challenges:
		selected_challenge_id = ""
		if challenge_panel != null:
			challenge_panel.visible = false
		if challenge_status_label != null:
			challenge_status_label.text = ""
		return
	if not selected_challenge_id.is_empty() and library.challenge(selected_challenge_id).is_empty():
		selected_challenge_id = ""
	for challenge_id in challenge_buttons.keys():
		var button := challenge_buttons[challenge_id] as Button
		if button == null:
			continue
		if str(challenge_id) == selected_challenge_id:
			_style_selected_button(button)
		else:
			button.add_theme_stylebox_override("normal", VisualStyle.pixel_box(VisualStyle.DARK_2, VisualStyle.CYAN_2, 1))
			button.add_theme_stylebox_override("hover", VisualStyle.pixel_box(VisualStyle.DARK_3, VisualStyle.CYAN, 1))
			button.add_theme_stylebox_override("pressed", VisualStyle.pixel_box(VisualStyle.BLUE, VisualStyle.YELLOW, 1))
	if challenge_status_label != null:
		challenge_status_label.text = _selected_challenge_status_text()
	if challenge_select_button != null:
		challenge_select_button.text = "Challenges" if selected_challenge_id.is_empty() else "Challenge: %s" % str(library.challenge(selected_challenge_id).get("title", selected_challenge_id))
		challenge_select_button.tooltip_text = _selected_challenge_status_text()


func _selected_challenge_status_text() -> String:
	if not _challenge_pack_loaded():
		return ""
	if selected_challenge_id.is_empty():
		return "%d challenges loaded; standard run selected" % library.challenges.size()
	var challenge_def := library.challenge(selected_challenge_id)
	var title := str(challenge_def.get("title", selected_challenge_id.capitalize()))
	var completion_flag := str(challenge_def.get("completion_flag", ""))
	var completed := profile_inventory != null and profile_inventory.has_challenge_completion(completion_flag)
	var suffix := "complete" if completed else "not complete"
	return "%s selected; %s" % [title, suffix]


func _selected_content_group_set() -> Dictionary:
	var result: Dictionary = {}
	for group_id in _selected_content_groups_for_new_run():
		result[str(group_id)] = true
	return result


func _selected_content_groups_for_new_run() -> Array:
	if library == null:
		return []
	return library.normalize_content_group_ids(selected_content_group_ids)


func _content_group_option_snapshot() -> Array:
	if library == null:
		return []
	return library.content_group_options(_selected_content_groups_for_new_run())


func _challenge_option_snapshot() -> Array:
	if not _challenge_pack_loaded():
		return []
	return library.challenge_options(selected_challenge_id)


func _content_group_challenge_for_seed(seed_text: String) -> Dictionary:
	if library == null:
		return RunState.standard_challenge(seed_text)
	var selected := _selected_content_groups_for_new_run()
	var defaults := library.default_content_group_ids()
	if JSON.stringify(selected) == JSON.stringify(defaults):
		return RunState.standard_challenge(seed_text)
	return RunState.custom_challenge("content_groups", seed_text, {"content_groups": selected})


func _new_run_challenge_for_seed(seed_text: String) -> Dictionary:
	var config: Dictionary
	if _challenge_pack_loaded() and not selected_challenge_id.is_empty():
		config = library.challenge_config_for(selected_challenge_id, seed_text)
	else:
		config = _content_group_challenge_for_seed(seed_text)
	return _challenge_with_home_selection(seed_text, config)


func _challenge_with_home_selection(seed_text: String, config: Dictionary) -> Dictionary:
	var normalized := RunState.normalize_challenge(seed_text, config)
	var modifiers := _copy_dict(normalized.get("modifiers", {}))
	var home_id := _normalize_home_type_id(selected_home_type_id)
	if home_id == RunState.HOME_SELECTION_RANDOM:
		modifiers.erase("home_archetype_id")
	else:
		modifiers["home_archetype_id"] = home_id
	normalized["modifiers"] = modifiers
	return normalized


func _build_settings_overlay() -> void:
	settings_overlay = PanelContainer.new()
	settings_overlay.visible = false
	settings_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	settings_overlay.add_theme_stylebox_override("panel", VisualStyle.pixel_box(Color("#03030a", 0.92), VisualStyle.CYAN, 1))
	add_child(settings_overlay)

	settings_margin = MarginContainer.new()
	settings_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings_margin.add_theme_constant_override("margin_left", 220)
	settings_margin.add_theme_constant_override("margin_right", 220)
	settings_margin.add_theme_constant_override("margin_top", 48)
	settings_margin.add_theme_constant_override("margin_bottom", 48)
	settings_overlay.add_child(settings_margin)

	var panel := _panel_container(Color("#080817", 0.98), VisualStyle.PINK)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	settings_margin.add_child(panel)

	settings_menu = SettingsMenuScript.new()
	settings_menu.visible = false
	settings_menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_menu.size_flags_vertical = Control.SIZE_EXPAND_FILL
	settings_menu.setup(user_settings)
	settings_menu.back_requested.connect(close_settings_menu)
	settings_menu.settings_applied.connect(_on_settings_applied)
	settings_menu.reset_tips_requested.connect(_on_reset_coach_tips_requested)
	panel.add_child(settings_menu)


func _build_event_choice_popup_overlay() -> void:
	event_choice_popup_overlay = Control.new()
	event_choice_popup_overlay.visible = false
	event_choice_popup_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	event_choice_popup_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(event_choice_popup_overlay)

	event_choice_popup_panel = _panel_container(Color("#080817", 0.98), VisualStyle.AMBER)
	event_choice_popup_panel.custom_minimum_size = EVENT_CHOICE_POPUP_BASE_SIZE
	event_choice_popup_panel.clip_contents = true
	event_choice_popup_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	event_choice_popup_overlay.add_child(event_choice_popup_panel)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 7)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	event_choice_popup_panel.add_child(stack)

	event_choice_popup_title_label = _label("Offer", 18)
	_set_control_font_color(event_choice_popup_title_label, VisualStyle.YELLOW)
	stack.add_child(event_choice_popup_title_label)

	event_choice_popup_summary_label = _label("", 12)
	_set_control_font_color(event_choice_popup_summary_label, VisualStyle.CYAN)
	event_choice_popup_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	event_choice_popup_summary_label.max_lines_visible = EVENT_CHOICE_SUMMARY_MAX_LINES
	event_choice_popup_summary_label.clip_text = true
	stack.add_child(event_choice_popup_summary_label)

	var separator := HSeparator.new()
	stack.add_child(separator)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.custom_minimum_size = Vector2(0, 130)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(scroll)

	event_choice_popup_choices_list = VBoxContainer.new()
	event_choice_popup_choices_list.add_theme_constant_override("separation", 8)
	event_choice_popup_choices_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(event_choice_popup_choices_list)


func _build_talk_dock() -> void:
	talk_dock = TalkDockScript.new()
	talk_dock.choice_requested.connect(Callable(self, "_on_talk_dock_choice_requested"))
	add_child(talk_dock)


func _build_item_found_popup() -> void:
	item_found_popup = ItemFoundPopupScript.new()
	item_found_popup.display_started.connect(Callable(self, "_on_item_found_display_started"))
	item_found_popup.display_finished.connect(Callable(self, "_on_item_found_display_finished"))
	add_child(item_found_popup)


func _build_coach_overlay() -> void:
	coach_overlay = CoachOverlayScript.new()
	coach_overlay.lesson_seen.connect(Callable(self, "_on_coach_lesson_seen"))
	add_child(coach_overlay)
	coach_overlay.set_lessons(library.tutorial_lessons if library != null else [])
	coach_overlay.restore_seen(profile_inventory.tips_seen if profile_inventory != null else {})
	coach_overlay.set_tips_enabled(user_settings == null or user_settings.coach_tips_enabled)


func _on_item_found_display_started(_item_id: String) -> void:
	if talk_dock != null and talk_dock.visible:
		item_found_talk_dock_suspended = true
		talk_dock.visible = false
	if item_found_popup != null:
		item_found_popup.move_to_front()


func _on_item_found_display_finished() -> void:
	if not item_found_talk_dock_suspended:
		return
	item_found_talk_dock_suspended = false
	_refresh_talk_dock()


func _build_conclusion_animation_overlay() -> void:
	conclusion_animation_overlay = Control.new()
	conclusion_animation_overlay.visible = false
	conclusion_animation_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	conclusion_animation_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(conclusion_animation_overlay)


func _build_run_inventory_overlay() -> void:
	run_inventory_screen = RunInventoryScreenScript.new()
	run_inventory_screen.configure(Callable(self, "_run_item_texture_for_asset_path"))
	run_inventory_screen.close_requested.connect(Callable(self, "close_run_inventory"))
	run_inventory_screen.item_selected.connect(Callable(self, "_on_run_inventory_screen_item_selected"))
	run_inventory_screen.set_active_requested.connect(Callable(self, "select_active_inventory_item"))
	run_inventory_screen.sell_requested.connect(Callable(self, "sell_inventory_item"))
	run_inventory_screen.repair_requested.connect(Callable(self, "repair_inventory_item"))
	run_inventory_screen.pawn_requested.connect(Callable(self, "_pawn_counter_pawn_item"))
	run_inventory_screen.redeem_pawn_requested.connect(Callable(self, "_pawn_counter_redeem_ticket"))
	run_inventory_screen.place_container_requested.connect(Callable(self, "_place_home_container_from_popup"))
	run_inventory_screen.store_item_requested.connect(Callable(self, "_store_home_container_item_from_popup"))
	run_inventory_screen.take_item_requested.connect(Callable(self, "_take_home_container_item_from_popup"))
	run_inventory_screen.transfer_item_requested.connect(Callable(self, "_transfer_home_container_item_from_popup"))
	add_child(run_inventory_screen)
	run_inventory_overlay = run_inventory_screen


func _build_meta_item_interaction_overlay() -> void:
	meta_item_interaction_screen = MetaItemInteractionScreenScript.new()
	meta_item_interaction_screen.configure(Callable(self, "_run_item_texture_for_asset_path"))
	meta_item_interaction_screen.close_requested.connect(Callable(self, "close_meta_item_interaction"))
	meta_item_interaction_screen.selection_changed.connect(Callable(self, "_on_meta_item_selection_changed"))
	meta_item_interaction_screen.action_requested.connect(Callable(self, "_on_meta_item_action_requested"))
	add_child(meta_item_interaction_screen)
	bag_open_reel = BagOpenReelScript.new()
	bag_open_reel.configure(Callable(self, "_run_item_texture_for_asset_path"))
	bag_open_reel.close_requested.connect(Callable(self, "_close_bag_open_reel"))
	add_child(bag_open_reel)


func _build_run_journal_overlay() -> void:
	run_journal_overlay = Control.new()
	run_journal_overlay.visible = false
	run_journal_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	run_journal_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(run_journal_overlay)

	var shade := Panel.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.add_theme_stylebox_override("panel", VisualStyle.pixel_box(Color("#03030a", 0.78), VisualStyle.CYAN_2, 1))
	run_journal_overlay.add_child(shade)

	run_journal_panel = _panel_container(Color("#080817", 0.98), VisualStyle.TEAL)
	run_journal_panel.custom_minimum_size = Vector2(600, 440)
	run_journal_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	run_journal_overlay.add_child(run_journal_panel)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	run_journal_panel.add_child(stack)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	stack.add_child(header)
	var title := _label("Run Journal", 20)
	_set_control_font_color(title, VisualStyle.YELLOW)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := _button("Close", Callable(self, "close_run_journal"))
	close_button.custom_minimum_size = Vector2(96, MIN_NATIVE_TOUCH_TARGET_HEIGHT)
	header.add_child(close_button)

	run_journal_summary_label = _label("", 12)
	_set_control_font_color(run_journal_summary_label, VisualStyle.CYAN)
	run_journal_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(run_journal_summary_label)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(scroll)

	run_journal_list = VBoxContainer.new()
	run_journal_list.add_theme_constant_override("separation", 8)
	run_journal_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(run_journal_list)


func _build_travel_transition_overlay() -> void:
	travel_transition_overlay = Control.new()
	travel_transition_overlay.visible = false
	travel_transition_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	travel_transition_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(travel_transition_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.52)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	travel_transition_overlay.add_child(dim)

	travel_transition_panel = _panel_container(Color("#050611", 0.96), VisualStyle.CYAN)
	travel_transition_panel.custom_minimum_size = Vector2(420, 118)
	travel_transition_panel.anchor_left = 0.5
	travel_transition_panel.anchor_top = 0.5
	travel_transition_panel.anchor_right = 0.5
	travel_transition_panel.anchor_bottom = 0.5
	travel_transition_panel.offset_left = -210
	travel_transition_panel.offset_top = -59
	travel_transition_panel.offset_right = 210
	travel_transition_panel.offset_bottom = 59
	travel_transition_overlay.add_child(travel_transition_panel)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	travel_transition_panel.add_child(stack)

	travel_transition_title_label = _label("Traveling", 20)
	travel_transition_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_set_control_font_color(travel_transition_title_label, VisualStyle.YELLOW)
	stack.add_child(travel_transition_title_label)

	travel_transition_body_label = _label("", 14)
	travel_transition_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	travel_transition_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_set_control_font_color(travel_transition_body_label, VisualStyle.CYAN)
	stack.add_child(travel_transition_body_label)

	var pulse := _label("Preparing the next room...", 12)
	pulse.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_set_control_font_color(pulse, VisualStyle.SOFT)
	stack.add_child(pulse)


func _build_world_map_overlay() -> void:
	_ensure_world_map_overlay_controller()
	world_map_overlay = Control.new()
	world_map_overlay.name = "WorldMapOverlay"
	world_map_overlay.visible = false
	world_map_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	world_map_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(world_map_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.58)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	world_map_overlay.add_child(dim)

	world_map_panel = _panel_container(Color("#050611", 0.98), VisualStyle.PURPLE_2)
	world_map_panel.custom_minimum_size = Vector2(860, 540)
	world_map_panel.anchor_left = 0.5
	world_map_panel.anchor_top = 0.5
	world_map_panel.anchor_right = 0.5
	world_map_panel.anchor_bottom = 0.5
	world_map_panel.offset_left = -430
	world_map_panel.offset_top = -270
	world_map_panel.offset_right = 430
	world_map_panel.offset_bottom = 270
	world_map_overlay.add_child(world_map_panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	world_map_panel.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	root.add_child(header)

	world_map_title_label = _label("World Map", 16)
	world_map_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	world_map_title_label.max_lines_visible = 1
	world_map_title_label.clip_text = true
	world_map_title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_set_control_font_color(world_map_title_label, VisualStyle.YELLOW)
	header.add_child(world_map_title_label)

	var close_button := _button("Close", Callable(self, "close_world_map"))
	close_button.custom_minimum_size = Vector2(96, MIN_NATIVE_TOUCH_TARGET_HEIGHT)
	header.add_child(close_button)

	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	world_map_holder = Control.new()
	world_map_holder.name = "WorldMapHolder"
	world_map_holder.custom_minimum_size = Vector2(800, 430)
	world_map_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	world_map_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	world_map_holder.clip_contents = true
	world_map_holder.mouse_filter = Control.MOUSE_FILTER_STOP
	world_map_holder.gui_input.connect(_on_world_map_holder_gui_input)
	body.add_child(world_map_holder)

	world_map_nodes_layer = WorldMapCanvasScript.new()
	world_map_nodes_layer.custom_minimum_size = Vector2(800, 430)
	world_map_nodes_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	world_map_nodes_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if world_map_nodes_layer.has_signal("layout_changed"):
		world_map_nodes_layer.connect("layout_changed", Callable(self, "_on_world_map_canvas_layout_changed"))
	world_map_holder.add_child(world_map_nodes_layer)

	world_map_detail_popup = _panel_container(Color("#070915", 0.97), VisualStyle.CYAN_2)
	world_map_detail_popup.name = "WorldMapDetailPopup"
	world_map_detail_popup.custom_minimum_size = Vector2(276, 150)
	world_map_detail_popup.size = Vector2(276, 150)
	world_map_detail_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	world_map_detail_popup.visible = false
	world_map_holder.add_child(world_map_detail_popup)

	var popup_stack := VBoxContainer.new()
	popup_stack.add_theme_constant_override("separation", 6)
	world_map_detail_popup.add_child(popup_stack)

	world_map_badge_slot = VBoxContainer.new()
	world_map_badge_slot.add_theme_constant_override("separation", 4)
	world_map_badge_slot.custom_minimum_size = Vector2(248, 0)
	world_map_badge_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	world_map_badge_slot.visible = false
	popup_stack.add_child(world_map_badge_slot)

	world_map_detail_label = _label("Select a revealed stop.", 13)
	world_map_detail_label.custom_minimum_size = Vector2(248, 78)
	world_map_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	world_map_detail_label.max_lines_visible = 6
	world_map_detail_label.clip_text = true
	world_map_detail_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	popup_stack.add_child(world_map_detail_label)

	world_map_confirm_button = _button("Travel", Callable(self, "confirm_world_map_travel"))
	world_map_confirm_button.custom_minimum_size = Vector2(132, MIN_NATIVE_TOUCH_TARGET_HEIGHT)
	popup_stack.add_child(world_map_confirm_button)
	world_map_overlay_controller.configure_nodes(world_map_overlay, world_map_holder, world_map_nodes_layer, world_map_title_label, world_map_detail_popup, world_map_detail_label, world_map_badge_slot, world_map_confirm_button)


func _ensure_world_map_overlay_controller() -> void:
	if world_map_overlay_controller == null:
		world_map_overlay_controller = WorldMapOverlayControllerScript.new()
		world_map_overlay_controller.node_pressed.connect(Callable(self, "select_world_map_node"))
	world_map_overlay_controller.set_small_screen_mode(_small_screen_enabled())


func _sync_world_map_overlay_controller_from_host() -> void:
	_ensure_world_map_overlay_controller()
	world_map_overlay_controller.sync_from_host(selected_world_map_node_id, selected_travel_target_id, selected_travel_label, world_map_snapshot_cache_key, world_map_canvas_snapshot_key)


func _sync_world_map_overlay_controller_to_host() -> void:
	if world_map_overlay_controller == null:
		return
	var state := world_map_overlay_controller.export_state()
	selected_world_map_node_id = str(state.get("selected_node_id", ""))
	selected_travel_target_id = str(state.get("selected_travel_target_id", ""))
	selected_travel_label = str(state.get("selected_travel_label", ""))
	world_map_snapshot_cache_key = str(state.get("snapshot_cache_key", world_map_snapshot_cache_key))
	world_map_canvas_snapshot_key = str(state.get("canvas_snapshot_key", world_map_canvas_snapshot_key))


func _build_inventory_page(parent: Node) -> void:
	inventory_page = VBoxContainer.new()
	inventory_page.visible = false
	inventory_page.add_theme_constant_override("separation", 10)
	inventory_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(inventory_page)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 10)
	inventory_page.add_child(header_row)
	var heading := _label("Profile Inventory", 22)
	_set_control_font_color(heading, VisualStyle.YELLOW)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(heading)
	var back_button := _button("Back", Callable(self, "close_inventory_page"))
	back_button.custom_minimum_size = Vector2(110, MIN_NATIVE_TOUCH_TARGET_HEIGHT)
	header_row.add_child(back_button)

	var description := _label("Profile progress lives outside a single run. Collection storage is handled through the walkable Home room.", 13)
	_set_control_font_color(description, VisualStyle.CYAN)
	description.max_lines_visible = 2
	inventory_page.add_child(description)

	var chip_panel := _panel_container(VisualStyle.DARK_2, VisualStyle.AMBER)
	inventory_page.add_child(chip_panel)
	var chip_row := HBoxContainer.new()
	chip_row.add_theme_constant_override("separation", 12)
	chip_panel.add_child(chip_row)
	var chip_icon := TextureRect.new()
	chip_icon.texture = _profile_chip_texture()
	chip_icon.custom_minimum_size = Vector2(68, 68)
	chip_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	chip_row.add_child(chip_icon)
	var chip_copy := VBoxContainer.new()
	chip_copy.add_theme_constant_override("separation", 4)
	chip_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip_row.add_child(chip_copy)
	var chip_name := _label("Rain City Poker Chip", 17)
	_set_control_font_color(chip_name, VisualStyle.AMBER)
	chip_copy.add_child(chip_name)
	chip_copy.add_child(_label("Reference profile item for the permanent stash.", 13))
	acquire_chip_button = _button("Acquire Chip", Callable(self, "acquire_profile_chip"))
	acquire_chip_button.custom_minimum_size = Vector2(150, 52)
	chip_row.add_child(acquire_chip_button)

	inventory_status_label = _label("", 13)
	_set_control_font_color(inventory_status_label, VisualStyle.CYAN)
	inventory_page.add_child(inventory_status_label)
	inventory_items_list = VBoxContainer.new()
	inventory_items_list.add_theme_constant_override("separation", 6)
	inventory_items_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_page.add_child(inventory_items_list)

	_refresh_profile_inventory_page()


func _build_game_test_menu(parent: Node) -> void:
	game_test_menu = VBoxContainer.new()
	game_test_menu.visible = false
	game_test_menu.add_theme_constant_override("separation", 6)
	game_test_menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game_test_menu.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(game_test_menu)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 8)
	game_test_menu.add_child(header_row)
	var heading := _label("Game Library", 20)
	_set_control_font_color(heading, VisualStyle.YELLOW)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(heading)
	var back_button := _button("Back", Callable(self, "close_game_test_menu"))
	back_button.custom_minimum_size = Vector2(96, MIN_NATIVE_TOUCH_TARGET_HEIGHT)
	header_row.add_child(back_button)

	var description := _label("Practice any available table with its real interface. Practice sessions do not autosave.", 12)
	_set_control_font_color(description, VisualStyle.CYAN)
	description.max_lines_visible = 1
	description.clip_text = true
	game_test_menu.add_child(description)

	var settings_panel := _panel_container(Color("#050611", 0.78), VisualStyle.CYAN_2)
	settings_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game_test_menu.add_child(settings_panel)
	var settings_stack := VBoxContainer.new()
	settings_stack.add_theme_constant_override("separation", 4)
	settings_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_panel.add_child(settings_stack)
	var generation_heading := _label("Generation Inputs", 12)
	_set_control_font_color(generation_heading, VisualStyle.YELLOW)
	settings_stack.add_child(generation_heading)

	var seed_row := HBoxContainer.new()
	seed_row.add_theme_constant_override("separation", 6)
	seed_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_stack.add_child(seed_row)
	var seed_label := _label("Seed", 11)
	seed_label.custom_minimum_size = Vector2(52, 26)
	seed_row.add_child(seed_label)
	game_test_seed_input = LineEdit.new()
	game_test_seed_input.text = "PRACTICE"
	game_test_seed_input.custom_minimum_size = Vector2(0, 26)
	game_test_seed_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_set_control_font_color(game_test_seed_input, VisualStyle.WHITE)
	game_test_seed_input.add_theme_stylebox_override("normal", VisualStyle.pixel_box(Color("#080817", 0.98), VisualStyle.CYAN_2, 1))
	game_test_seed_input.add_theme_stylebox_override("focus", VisualStyle.pixel_box(Color("#111024", 0.98), VisualStyle.CYAN, 1))
	seed_row.add_child(game_test_seed_input)

	var numeric_row := HBoxContainer.new()
	numeric_row.add_theme_constant_override("separation", 6)
	numeric_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_stack.add_child(numeric_row)
	numeric_row.add_child(_game_test_spin_group("Bankroll", "_game_test_bankroll"))
	numeric_row.add_child(_game_test_spin_group("Min", "_game_test_stake_floor"))
	numeric_row.add_child(_game_test_spin_group("Max", "_game_test_stake_ceiling"))
	var security_group := VBoxContainer.new()
	security_group.add_theme_constant_override("separation", 3)
	security_group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	numeric_row.add_child(security_group)
	var security_label := _label("Security", 11)
	_set_control_font_color(security_label, VisualStyle.CYAN_2)
	security_group.add_child(security_label)
	game_test_security_option = OptionButton.new()
	game_test_security_option.custom_minimum_size = Vector2(0, 26)
	game_test_security_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game_test_security_option.add_item("Low")
	game_test_security_option.set_item_metadata(0, "low")
	game_test_security_option.add_item("High")
	game_test_security_option.set_item_metadata(1, "high")
	game_test_security_option.add_item("Boss")
	game_test_security_option.set_item_metadata(2, "boss")
	game_test_security_option.select(2)
	security_group.add_child(game_test_security_option)

	game_test_generation_overrides_text = TextEdit.new()
	game_test_generation_overrides_text.text = "{}"
	game_test_generation_overrides_text.custom_minimum_size = Vector2(0, 48)
	game_test_generation_overrides_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_set_control_font_color(game_test_generation_overrides_text, VisualStyle.WHITE)
	game_test_generation_overrides_text.add_theme_stylebox_override("normal", VisualStyle.pixel_box(Color("#080817", 0.98), VisualStyle.PURPLE_2, 1))
	settings_stack.add_child(game_test_generation_overrides_text)

	game_test_status_label = _label("Choose a game to enter its real interface.", 12)
	_set_control_font_color(game_test_status_label, VisualStyle.CYAN_2)
	game_test_status_label.max_lines_visible = 1
	game_test_status_label.clip_text = true
	game_test_menu.add_child(game_test_status_label)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.custom_minimum_size = Vector2(0, 130)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	game_test_menu.add_child(scroll)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	for game_id in _implemented_game_ids():
		var definition := library.game(game_id)
		var display_name := str(definition.get("display_name", game_id.capitalize()))
		var description_text := str(definition.get("description", ""))
		var button := _button(display_name, Callable(self, "start_game_test_session").bind(game_id))
		button.tooltip_text = description_text
		button.custom_minimum_size = Vector2(0, MIN_NATIVE_TOUCH_TARGET_HEIGHT)
		list.add_child(button)


func _game_test_spin_group(label_text: String, target_id: String) -> VBoxContainer:
	var group := VBoxContainer.new()
	group.add_theme_constant_override("separation", 2)
	group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var label := _label(label_text, 10)
	_set_control_font_color(label, VisualStyle.CYAN_2)
	group.add_child(label)
	var spin := SpinBox.new()
	spin.custom_minimum_size = Vector2(0, 26)
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.rounded = true
	match target_id:
		"_game_test_bankroll":
			spin.min_value = 1
			spin.max_value = 999999
			spin.step = 1
			spin.value = 100000
			game_test_bankroll_input = spin
		"_game_test_stake_floor":
			spin.min_value = 0
			spin.max_value = 10000
			spin.step = 1
			spin.value = 1
			game_test_stake_floor_input = spin
		"_game_test_stake_ceiling":
			spin.min_value = 1
			spin.max_value = 100000
			spin.step = 1
			spin.value = 200
			game_test_stake_ceiling_input = spin
	group.add_child(spin)
	return group


func _build_run_screen() -> void:
	FoundationScreenBuilderScript.build_run_screen(self)


func _build_run_menu_overlay() -> void:
	run_menu_overlay = Control.new()
	run_menu_overlay.visible = false
	run_menu_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	run_menu_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(run_menu_overlay)

	var shade := Panel.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.add_theme_stylebox_override("panel", VisualStyle.pixel_box(Color("#03030a", 0.84), VisualStyle.CYAN_2, 1))
	run_menu_overlay.add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	run_menu_overlay.add_child(center)

	run_menu_panel = _panel_container(Color("#080817", 0.98), VisualStyle.CYAN)
	run_menu_panel.custom_minimum_size = Vector2(540, 430)
	run_menu_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(run_menu_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	run_menu_panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(stack)

	var title := _label("Run Menu", 24)
	_set_control_font_color(title, VisualStyle.YELLOW)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(title)

	run_menu_status_label = _label("", 13)
	_set_control_font_color(run_menu_status_label, VisualStyle.CYAN_2)
	run_menu_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	run_menu_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	run_menu_status_label.custom_minimum_size = Vector2(0, 50)
	stack.add_child(run_menu_status_label)

	var slot_note := _label("Resume Slot: one local save. Save overwrites it; Load replaces this run from it.", 12)
	_set_control_font_color(slot_note, VisualStyle.SOFT)
	slot_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(slot_note)
	stack.add_child(_attribute_glyph_legend_panel())

	var button_grid := GridContainer.new()
	button_grid.columns = 2
	button_grid.add_theme_constant_override("h_separation", 10)
	button_grid.add_theme_constant_override("v_separation", 10)
	button_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_child(button_grid)

	run_menu_resume_button = _button("Resume", Callable(self, "close_run_menu"))
	run_menu_resume_button.custom_minimum_size = Vector2(0, 42)
	button_grid.add_child(run_menu_resume_button)
	run_menu_save_button = _button("Save", Callable(self, "save_run_from_menu"))
	run_menu_save_button.custom_minimum_size = Vector2(0, 42)
	button_grid.add_child(run_menu_save_button)
	run_menu_load_button = _button("Load", Callable(self, "load_run_from_menu"))
	run_menu_load_button.custom_minimum_size = Vector2(0, 42)
	button_grid.add_child(run_menu_load_button)
	run_menu_journal_button = _button("Journal", Callable(self, "open_run_journal"))
	run_menu_journal_button.custom_minimum_size = Vector2(0, 42)
	button_grid.add_child(run_menu_journal_button)
	run_menu_settings_button = _button("Settings", Callable(self, "open_settings_menu"))
	run_menu_settings_button.custom_minimum_size = Vector2(0, 42)
	button_grid.add_child(run_menu_settings_button)
	run_menu_abandon_button = _button("Abandon Run", Callable(self, "abandon_run_from_menu"))
	run_menu_abandon_button.custom_minimum_size = Vector2(0, 42)
	button_grid.add_child(run_menu_abandon_button)
	run_menu_main_menu_button = _button("Main Menu", Callable(self, "return_to_main_menu"))
	run_menu_main_menu_button.custom_minimum_size = Vector2(0, 42)
	button_grid.add_child(run_menu_main_menu_button)
	run_menu_skip_tutorial_button = _button("Skip Lessons", Callable(self, "request_skip_tutorial"))
	run_menu_skip_tutorial_button.custom_minimum_size = Vector2(0, 42)
	button_grid.add_child(run_menu_skip_tutorial_button)

	tutorial_skip_dialog = ConfirmationDialog.new()
	tutorial_skip_dialog.title = "Skip the lessons?"
	tutorial_skip_dialog.dialog_text = "End this guided run? You can replay Lessons from the main menu."
	tutorial_skip_dialog.confirmed.connect(_confirm_skip_tutorial)
	add_child(tutorial_skip_dialog)


func _attribute_glyph_legend_panel() -> Control:
	var panel := _panel_container(VisualStyle.DARK_2, VisualStyle.CYAN_2)
	panel.custom_minimum_size = Vector2(0, 72)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 3)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(stack)
	var title := _label("Glyph Legend", 11)
	_set_control_font_color(title, VisualStyle.CYAN)
	stack.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 36)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_child(scroll)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	scroll.add_child(row)
	for entry_value in AttributeBadgesScript.legend_entries():
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 3)
		cell.tooltip_text = str(entry.get("description", entry.get("label", "")))
		var badge: Dictionary = entry.get("badge", {}) if typeof(entry.get("badge", {})) == TYPE_DICTIONARY else {}
		AttributeBadgeRowScript.warm_cache([badge], 16)
		cell.add_child(AttributeBadgeRowScript.control_row([badge], 16))
		row.add_child(cell)
	return panel


func _build_run_report_screen(parent: BoxContainer) -> void:
	run_report_screen = RunReportScreenScript.new()
	run_report_screen.visible = false
	run_report_screen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	run_report_screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	run_report_screen.new_run_requested.connect(_on_run_report_new_run_requested)
	run_report_screen.home_requested.connect(_on_run_report_home_requested)
	run_report_screen.copy_seed_requested.connect(_on_run_report_copy_seed_requested)
	run_report_screen.bag_claim_requested.connect(claim_victory_collection_bag)
	run_report_screen.take_home_item_claim_requested.connect(claim_victory_container_item)
	parent.add_child(run_report_screen)


func _refresh() -> void:
	_invalidate_run_screen_layout()
	_invalidate_travel_view_cache()
	interactable_object_view_cache_valid = false
	var has_run := run_state != null
	if not has_run or current_screen == SCREEN_START:
		if coach_overlay != null:
			coach_overlay.suspend()
		_hide_run_menu()
		_set_current_screen(SCREEN_START)
		_render_start_screen()
		return
	_evaluate_run_terminal_state()
	_render_environment_screen()
	if _run_menu_is_visible():
		_refresh_run_menu()
	_refresh_coach_at_boundary()


func _render_start_screen() -> void:
	_stop_procedural_music()
	start_screen.visible = true
	run_screen.visible = false
	_refresh_start_screen()


func _render_environment_screen() -> void:
	if current_screen == SCREEN_START:
		_set_current_screen(SCREEN_ENVIRONMENT)
	start_screen.visible = false
	run_screen.visible = true
	var game_focus_mode := _is_game_focus_mode()
	_refresh_world_header()
	if action_panel_container != null:
		action_panel_container.visible = false
	if action_heading_label != null:
		action_heading_label.text = "Game surface" if game_focus_mode else "Room objects"
	if action_hint_label != null:
		action_hint_label.text = "Use the visible surface controls. Click the selected action again to resolve." if game_focus_mode else "Click room objects to inspect. Double-click glowing objects to act."
	var hud_model := _run_status_hud_model()
	status_label.text = str(hud_model.get("status_text", ""))
	if objective_label != null:
		objective_label.text = str(hud_model.get("objective_text", ""))
	_style_hud_for_recent_consequence()
	if save_status_label != null:
		save_status_label.text = str(hud_model.get("save_text", ""))
	_apply_hud_mode_visibility()
	_refresh_active_item_slot()
	_apply_focus_layout()
	_refresh_environment_result_feedback()
	_render_run_report()
	_render_result_panel()
	_render_foundation_snapshots()
	_refresh_talk_dock()
	_schedule_action_panel_refresh()
	_refresh_world_map_overlay()
	_update_procedural_music()


func _refresh_world_header(selected_world_object_override: Dictionary = {}) -> void:
	if run_state == null or title_label == null or summary_label == null:
		return
	var environment := run_state.current_environment
	var game_focus_mode := _is_game_focus_mode()
	if _is_victory_screen():
		var outcome := _run_report_outcome_snapshot()
		title_label.text = str(outcome.get("title", "Demo Victory"))
		summary_label.text = str(outcome.get("how", "The run is complete."))
		summary_label.max_lines_visible = 2
		return
	if _is_failure_screen():
		title_label.text = "Run Failed"
		var pressure := _run_pressure_view()
		summary_label.text = _pressure_status_text(pressure)
		summary_label.max_lines_visible = 2
		return
	if game_focus_mode:
		title_label.text = current_game.get_display_name()
		var game_description := _current_game_description()
		summary_label.text = game_description if not game_description.is_empty() else str(environment.get("display_name", "Game"))
	else:
		var selected_world_object := selected_world_object_override
		if selected_world_object.is_empty() or str(selected_world_object.get("object_id", "")) != selected_object_id:
			selected_world_object = _interactable_object(selected_object_id)
		if selected_world_object.is_empty():
			title_label.text = str(environment.get("display_name", environment.get("id", "Environment")))
			var room_description := str(environment.get("visual_context", {}).get("description", ""))
			summary_label.text = "%s Click objects to inspect; double-click glowing props to act." % room_description if not room_description.is_empty() else "Click objects to inspect; double-click glowing props to act."
		else:
			title_label.text = "%s / %s" % [str(environment.get("display_name", environment.get("id", "Environment"))), str(selected_world_object.get("label", "Object"))]
			summary_label.text = _world_object_summary_text(selected_world_object)
	summary_label.max_lines_visible = 1 if game_focus_mode else 2


func _render_action_panel(focused_object_override: Dictionary = {}) -> void:
	_rebuild_actions(focused_object_override)


func _schedule_action_panel_refresh(focused_object_override: Dictionary = {}) -> void:
	if not focused_object_override.is_empty():
		pending_action_panel_object = focused_object_override.duplicate(true)
	else:
		pending_action_panel_object = {}
	if action_panel_refresh_scheduled:
		return
	action_panel_refresh_scheduled = true
	call_deferred("_flush_action_panel_refresh")


func _flush_action_panel_refresh() -> void:
	action_panel_refresh_scheduled = false
	var focused_object := pending_action_panel_object
	pending_action_panel_object = {}
	_render_action_panel(focused_object)


func _render_result_panel() -> void:
	_refresh_consequence_labels()


func _world_object_summary_text(object_data: Dictionary) -> String:
	var parts: Array[String] = []
	for key in ["short_description", "cost_summary", "risk_summary", "action_summary", "disabled_reason"]:
		var text := str(object_data.get(key, "")).strip_edges()
		if text.is_empty():
			continue
		if key == "risk_summary" and not text.begins_with("Risk:"):
			text = "Risk: %s" % text
		parts.append(text)
	if parts.is_empty():
		return "Click another object to inspect, or double-click this one to act."
	return " ".join(parts).left(180)


func _set_current_screen(screen_id: String) -> void:
	var previous_screen := current_screen
	current_screen = screen_id
	if screen_id == SCREEN_START and previous_screen != SCREEN_START:
		_refresh_menu_seed_text()


func _update_procedural_music() -> void:
	if procedural_music_player == null:
		return
	if run_state == null or current_screen == SCREEN_START:
		procedural_music_player.stop()
		return
	_ensure_run_music_arrangement_state()
	procedural_music_player.play_for_environment_state(run_state.current_environment, run_state.suspicion_level(), music_fx_state_snapshot())


func _is_web_audio_unlock_gesture(event: InputEvent) -> bool:
	if not OS.has_feature("web"):
		return false
	var mouse_event := event as InputEventMouseButton
	if mouse_event != null:
		return mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT
	var touch_event := event as InputEventScreenTouch
	if touch_event != null:
		return touch_event.pressed
	var key_event := event as InputEventKey
	if key_event != null:
		return key_event.pressed and not key_event.echo
	return false


func _schedule_web_audio_unlock_refresh() -> void:
	if web_audio_unlock_refresh_scheduled:
		return
	web_audio_unlock_refresh_scheduled = true
	web_audio_unlock_refresh_count = 0
	call_deferred("_run_web_audio_unlock_refresh")


func _run_web_audio_unlock_refresh() -> void:
	if not OS.has_feature("web"):
		web_audio_unlock_refresh_scheduled = false
		return
	if procedural_music_player != null and run_state != null and current_screen != SCREEN_START:
		procedural_music_player.refresh_after_web_audio_unlock(run_state.current_environment, run_state.suspicion_level(), music_fx_state_snapshot())
	web_audio_unlock_refresh_count += 1
	if web_audio_unlock_refresh_count >= WEB_AUDIO_UNLOCK_REFRESH_ATTEMPTS:
		web_audio_unlock_refresh_scheduled = false
		return
	var tree := get_tree()
	if tree == null:
		web_audio_unlock_refresh_scheduled = false
		return
	var timer := tree.create_timer(WEB_AUDIO_UNLOCK_REFRESH_DELAY_SECONDS)
	timer.timeout.connect(Callable(self, "_run_web_audio_unlock_refresh"), CONNECT_ONE_SHOT)


func music_fx_state_snapshot() -> Dictionary:
	if run_state == null:
		return {}
	var environment := run_state.current_environment
	var visual_context: Dictionary = _copy_dict(environment.get("visual_context", {}))
	var watch_status: Dictionary = run_state.pit_boss_watch_status(environment)
	var objective_status: Dictionary = run_state.demo_objective_status(environment)
	var forced_threshold := clampi(int(objective_status.get("forced_showdown_heat_threshold", 95)), 0, 100)
	var staff_attention: Dictionary = run_state.grand_casino_staff_attention_status(environment, forced_threshold)
	var scene_type := str(visual_context.get("scene_type", environment.get("kind", ""))).strip_edges()
	var boss_floor := str(environment.get("kind", "")).strip_edges() == "boss" or scene_type == "boss"
	var debt_status := _music_debt_pressure_snapshot()
	var win_status := _music_win_momentum_snapshot()
	return {
		"heat": run_state.suspicion_level(),
		"suspicion_level": run_state.suspicion_level(),
		"drunk_level": run_state.drunk_level,
		"alcoholic_level": run_state.alcoholic_level,
		"alcohol_tier": _music_alcohol_tier(run_state.drunk_level),
		"pit_boss_watch": watch_status,
		"watch_active": bool(watch_status.get("active", false)),
		"watched": bool(watch_status.get("watched", false)),
		"staff_attention": staff_attention,
		"staff_attention_active": bool(staff_attention.get("active", false)),
		"showdown_pending": bool(objective_status.get("showdown_pending", false)),
		"showdown_active": bool(objective_status.get("showdown_active", false)),
		"boss_floor": boss_floor,
		"environment": _music_environment_payload(environment),
		"visual_context": visual_context,
		"scene_type": scene_type,
		"room_scale": _music_room_scale_for_visual_context(visual_context, environment),
		"bankroll": _presented_bankroll(),
		"economy": run_state.economy(),
		"bankroll_pressure": _music_bankroll_pressure_amount(),
		"debt": debt_status.get("debt", []),
		"debt_count": int(debt_status.get("debt_count", 0)),
		"overdue_debt_count": int(debt_status.get("overdue_debt_count", 0)),
		"overdue_debt": bool(debt_status.get("overdue_debt", false)),
		"win_streak": int(win_status.get("win_streak", 0)),
		"big_win": bool(win_status.get("big_win", false)),
		"big_win_bars_remaining": int(win_status.get("big_win_bars_remaining", 0)),
		"big_win_event_token": str(win_status.get("big_win_event_token", "")),
		"last_bankroll_delta": int(win_status.get("last_bankroll_delta", 0)),
		"run_seed": run_state.seed_value,
		"music_visit_id": str(run_state.music_arrangement_state.get("visit_id", "")),
		"music_arrangement_state": run_state.music_arrangement_state.duplicate(true),
	}


func _ensure_run_music_arrangement_state() -> void:
	if run_state == null or library == null:
		return
	var profile := _copy_dict(run_state.current_environment.get("music_profile", {}))
	var track_id := str(profile.get("authored_track_id", "")).strip_edges()
	if track_id.is_empty():
		return
	var entry := library.music_track(track_id)
	var recipes_value: Variant = entry.get("arrangement_recipes", [])
	if typeof(recipes_value) != TYPE_ARRAY or (recipes_value as Array).is_empty() or typeof((recipes_value as Array)[0]) != TYPE_DICTIONARY:
		return
	var recipe: Dictionary = (recipes_value as Array)[0]
	var sections := _string_array(recipe.get("sections", []))
	if sections.is_empty():
		return
	run_state.ensure_music_arrangement_state(track_id, str(recipe.get("id", "")), str(sections[0]))


func _on_authored_music_phrase_event(event: Dictionary) -> void:
	if run_state == null or library == null:
		return
	var track_id := str(event.get("track_id", "")).strip_edges()
	var recipe_id := str(event.get("recipe_id", "")).strip_edges()
	var entry := library.music_track(track_id)
	var recipes_value: Variant = entry.get("arrangement_recipes", [])
	if typeof(recipes_value) != TYPE_ARRAY:
		return
	for recipe_value in recipes_value as Array:
		if typeof(recipe_value) != TYPE_DICTIONARY:
			continue
		var recipe: Dictionary = recipe_value
		if str(recipe.get("id", "")) != recipe_id:
			continue
		var phrase_event := event.duplicate(true)
		phrase_event["event_token"] = "%s:%s" % [str(run_state.music_arrangement_state.get("visit_id", "")), str(event.get("event_token", ""))]
		var state := run_state.advance_music_arrangement_phrase(track_id, recipe_id, _copy_array(recipe.get("sections", [])), phrase_event, _copy_dict(recipe.get("role_policies", {})))
		if bool(state.get("event_accepted", false)):
			_update_procedural_music()
		return


func _on_authored_music_arrangement_selected(selection: Dictionary) -> void:
	if run_state == null:
		return
	run_state.remember_music_arrangement_selection(str(selection.get("track_id", "")), _copy_dict(selection.get("selected_variant_ids", {})), _copy_dict(selection.get("selected_role_epochs", {})))


func _music_environment_payload(environment: Dictionary) -> Dictionary:
	return {
		"id": str(environment.get("id", "")),
		"name": str(environment.get("name", "")),
		"display_name": str(environment.get("display_name", environment.get("name", ""))),
		"archetype_id": str(environment.get("archetype_id", "")),
		"kind": str(environment.get("kind", "")),
		"tier": str(environment.get("tier", "")),
		"mood": str(environment.get("mood", "")),
		"visual_context": _copy_dict(environment.get("visual_context", {})),
		"music_profile": _copy_dict(environment.get("music_profile", {})),
		"security_profile": _copy_dict(environment.get("security_profile", {})),
	}


func _music_alcohol_tier(drunk_level: int) -> int:
	if drunk_level >= 71:
		return 3
	if drunk_level >= 46:
		return 2
	if drunk_level >= 12:
		return 1
	return 0


func _music_room_scale_for_visual_context(visual_context: Dictionary, environment: Dictionary) -> float:
	if visual_context.has("room_scale"):
		return clampf(float(visual_context.get("room_scale", 0.35)), 0.0, 1.0)
	if visual_context.has("scale"):
		return clampf(float(visual_context.get("scale", 0.35)), 0.0, 1.0)
	var tier := clampi(int(environment.get("tier", 1)), 0, 3)
	var kind := str(environment.get("kind", "")).strip_edges().to_lower()
	var room_scale := 0.26 + (float(tier) * 0.14)
	if kind.find("casino") != -1:
		room_scale += 0.08
	if kind.find("club") != -1:
		room_scale += 0.06
	if kind.find("shop") != -1:
		room_scale -= 0.08
	if kind.find("boss") != -1:
		room_scale = maxf(room_scale, 0.82)
	return clampf(room_scale, 0.18, 0.90)


func _music_bankroll_pressure_amount() -> float:
	if run_state == null:
		return 0.0
	var bankroll := maxi(0, run_state.bankroll)
	var cash_pressure := clampf(float(70 - bankroll) / 70.0, 0.0, 1.0)
	var economy := run_state.economy()
	if economy == "insolvent":
		return 1.0
	if economy == "distressed":
		return maxf(cash_pressure, 0.78)
	if economy == "volatile":
		return maxf(cash_pressure, 0.55)
	return cash_pressure


func _music_debt_pressure_snapshot() -> Dictionary:
	var active_count := 0
	var overdue_count := 0
	var debt_entries: Array = []
	if run_state == null:
		return {"debt": debt_entries, "debt_count": active_count, "overdue_debt_count": overdue_count, "overdue_debt": false}
	for debt_value in _copy_array(run_state.debt):
		if typeof(debt_value) != TYPE_DICTIONARY:
			continue
		var debt_data: Dictionary = debt_value
		var status := str(debt_data.get("status", "active")).strip_edges().to_lower()
		if status == "paid":
			continue
		active_count += 1
		if status == "overdue" or status == "favor_due":
			overdue_count += 1
		debt_entries.append({
			"id": str(debt_data.get("id", "")),
			"lender_id": str(debt_data.get("lender_id", "")),
			"status": status,
			"balance": int(debt_data.get("balance", 0)),
		})
	return {
		"debt": debt_entries,
		"debt_count": active_count,
		"overdue_debt_count": overdue_count,
		"overdue_debt": overdue_count > 0,
	}


func _music_win_momentum_snapshot() -> Dictionary:
	var result := {
		"win_streak": 0,
		"big_win": false,
		"big_win_bars_remaining": 0,
		"big_win_event_token": "",
		"last_bankroll_delta": 0,
	}
	if run_state == null:
		return result
	var streak := 0
	var captured_latest := false
	for index in range(run_state.story_log.size() - 1, -1, -1):
		var entry_value: Variant = run_state.story_log[index]
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value
		if str(entry.get("type", "")) != "game_action":
			continue
		var delta := int(entry.get("bankroll_delta", 0))
		if not captured_latest:
			result["last_bankroll_delta"] = delta
			result["big_win"] = delta >= 50
			result["big_win_event_token"] = "%d:%s:%s:%d" % [index, str(entry.get("game_id", entry.get("source_id", "game"))), str(entry.get("action_id", "action")), delta]
			captured_latest = true
		if delta > 0:
			streak += 1
			continue
		break
	var scheduled_outcome: Dictionary = last_game_result.get("music_outcome_schedule", {}) as Dictionary if typeof(last_game_result.get("music_outcome_schedule", {})) == TYPE_DICTIONARY else {}
	if str(scheduled_outcome.get("outcome_class", "")) == "big_win" and not str(scheduled_outcome.get("event_token", "")).is_empty():
		result["big_win"] = true
		result["big_win_event_token"] = str(scheduled_outcome.get("event_token", ""))
	result["win_streak"] = streak
	return result


func _schedule_game_result_music_outcome(result: Dictionary, action_id: String) -> Dictionary:
	if procedural_music_player == null or run_state == null or result.is_empty():
		return {}
	var delta := _music_result_bankroll_delta(result)
	var outcome_class := "neutral"
	var result_outcome := str(result.get("outcome", result.get("slot_classification", ""))).strip_edges().to_lower()
	if delta >= 50 or result_outcome.find("jackpot") >= 0 or result_outcome.find("grand") >= 0:
		outcome_class = "big_win"
	elif delta > 0 or bool(result.get("won", false)):
		outcome_class = "small_win"
	elif delta < 0 or result_outcome in ["lose", "loss"]:
		outcome_class = "loss"
	elif result_outcome in ["push", "carry", "tie"]:
		outcome_class = "push"
	var game_id := str(result.get("game_id", result.get("source_id", current_game.get_id() if current_game != null else "game")))
	var resolved_action_id := str(result.get("action_id", action_id))
	var action_index := int(run_state.event_cadence.get("action_index", 0))
	var explicit_token := str(result.get("music_event_token", result.get("outcome_event_token", ""))).strip_edges()
	var token := explicit_token if not explicit_token.is_empty() else "%s:%d:%s:%s:%d" % [str(run_state.seed_value), action_index, game_id, resolved_action_id, run_state.story_log.size()]
	var tier := str(result.get("tier", "")).strip_edges().to_lower()
	var attribution_value: Variant = result.get("win_attribution", {})
	if tier.is_empty() and typeof(attribution_value) == TYPE_DICTIONARY:
		tier = str((attribution_value as Dictionary).get("tier", "")).strip_edges().to_lower()
	if tier.is_empty():
		tier = "jackpot" if outcome_class == "big_win" else "standard"
	return procedural_music_player.schedule_music_outcome_event({
		"event_token": token,
		"outcome_class": outcome_class,
		"magnitude": absi(delta),
		"tier": tier,
		"source_game": game_id,
		"result_time": run_state.game_clock_minutes,
		"requested_quantization": str(result.get("music_quantization", "")),
	})


func _music_result_bankroll_delta(result: Dictionary) -> int:
	var deltas: Dictionary = result.get("deltas", {}) as Dictionary if typeof(result.get("deltas", {})) == TYPE_DICTIONARY else {}
	return int(result.get("bankroll_delta", deltas.get("bankroll_delta", result.get("slot_net", 0))))


func _on_music_outcome_scheduled(schedule: Dictionary) -> void:
	last_music_outcome_schedule = schedule.duplicate(true)


func _schedule_surface_music_event(outcome_class: String, cue_id: String, context: Dictionary) -> Dictionary:
	if procedural_music_player == null:
		return {}
	var action_index := int(run_state.event_cadence.get("action_index", 0)) if run_state != null else 0
	var scene: Dictionary = _copy_dict(context.get("feature_scene", {}))
	var marker := str(context.get("marker", context.get("normalized_event_id", cue_id))).strip_edges()
	var scene_id := str(scene.get("scene_id", scene.get("mode", "feature"))).strip_edges()
	var token := "%d:%s:%s:%s" % [action_index, scene_id, cue_id, marker]
	return procedural_music_player.schedule_music_outcome_event({
		"event_token": token,
		"outcome_class": outcome_class,
		"magnitude": maxf(0.0, float(context.get("award", context.get("magnitude", 0.0)))),
		"tier": str(context.get("tier", "feature")),
		"source_game": current_game.get_id() if current_game != null else str(context.get("source_game", "feature")),
		"result_time": run_state.game_clock_minutes if run_state != null else 0,
		"cue_id": cue_id,
	})


func _stop_procedural_music() -> void:
	if procedural_music_player != null:
		procedural_music_player.stop()
	last_music_outcome_schedule = {}


func _sync_surface_feature_music_state(surface_state: Dictionary) -> void:
	var feature_scene: Dictionary = _copy_dict(surface_state.get("slot_feature_scene", {}))
	var music: Dictionary = _copy_dict(feature_scene.get("feature_music", {}))
	var feature_music_active := bool(feature_scene.get("active", false)) and not music.is_empty() and bool(music.get("loop", false))
	var should_duck := feature_music_active and bool(music.get("duck_background_music", false))
	if procedural_music_player != null:
		procedural_music_player.update_feature_music_state({
			"active": feature_music_active,
			"feature_scene": feature_scene,
			"feature_music": music,
			"duck_background_music": should_duck,
		})
	_set_surface_feature_music_state(feature_music_active, should_duck)


func _set_surface_feature_music_state(active: bool, ducking: bool) -> void:
	var was_active := surface_feature_music_active
	var was_ducking := surface_feature_music_ducking
	if was_active == active and was_ducking == ducking:
		return
	surface_feature_music_active = active
	surface_feature_music_ducking = ducking
	if procedural_music_player != null and was_active and not active:
		procedural_music_player.stop_feature_music()
		_schedule_surface_music_event("feature_end", "feature_end", {"marker": "feature_end"})
	if was_ducking and not ducking:
		_update_procedural_music()


func _stop_surface_feature_music() -> void:
	var was_active := surface_feature_music_active
	var was_ducking := surface_feature_music_ducking
	surface_feature_music_active = false
	surface_feature_music_ducking = false
	if procedural_music_player != null:
		procedural_music_player.stop_feature_music()
		if was_active:
			_schedule_surface_music_event("feature_end", "feature_end", {"marker": "feature_stop"})
	if was_ducking:
		_update_procedural_music()


func _is_game_focus_mode() -> bool:
	return current_game != null


func _is_failure_screen() -> bool:
	return run_state != null and run_state.run_status == RunState.RUN_STATUS_FAILED and current_screen == SCREEN_FAILURE


func _is_victory_screen() -> bool:
	return run_state != null and run_state.run_status == RunState.RUN_STATUS_ENDED and current_screen == SCREEN_VICTORY


func _apply_focus_layout() -> void:
	_apply_run_screen_layout()
	var game_mode := _is_game_focus_mode()
	var failure_mode := _is_failure_screen()
	var victory_mode := _is_victory_screen()
	if environment_canvas != null:
		environment_canvas.visible = not game_mode and not failure_mode and not victory_mode
		environment_canvas.custom_minimum_size = ENVIRONMENT_CANVAS_MIN_SIZE
		environment_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if game_surface_canvas != null:
		game_surface_canvas.visible = game_mode and not failure_mode and not victory_mode
		game_surface_canvas.custom_minimum_size = GAME_SURFACE_FOCUSED_MIN_SIZE if game_mode else GAME_SURFACE_PREVIEW_MIN_SIZE
		game_surface_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if run_report_screen != null:
		run_report_screen.visible = failure_mode or victory_mode
		run_report_screen.size_flags_vertical = Control.SIZE_EXPAND_FILL


func _apply_run_screen_layout() -> void:
	if run_screen == null or run_hud_panel == null or visual_panel_container == null:
		return
	var screen_size := run_screen.size
	if screen_size.x <= 0.0 or screen_size.y <= 0.0:
		if not is_inside_tree():
			return
		screen_size = get_viewport_rect().size
	if screen_size.x <= 0.0 or screen_size.y <= 0.0:
		return
	if not run_layout_dirty and run_layout_last_screen_size == screen_size:
		return
	var terminal_report := _is_failure_screen() or _is_victory_screen()
	run_hud_panel.visible = not terminal_report
	var proportional_info_height: float = floor(screen_size.y * RUN_INFO_BAND_RATIO)
	var hud_content_height: float = ceil(run_hud_panel.get_combined_minimum_size().y)
	var max_info_height: float = floor(screen_size.y * 0.35)
	var info_height := 0.0 if terminal_report else minf(maxf(maxf(RUN_INFO_MIN_HEIGHT, proportional_info_height), hud_content_height), max_info_height)
	run_hud_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	run_hud_panel.offset_left = 0.0
	run_hud_panel.offset_top = 0.0
	run_hud_panel.offset_right = 0.0
	run_hud_panel.offset_bottom = -(screen_size.y - info_height)
	run_hud_panel.custom_minimum_size = Vector2.ZERO
	run_hud_panel.size_flags_vertical = Control.SIZE_FILL
	visual_panel_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	visual_panel_container.offset_left = 0.0
	visual_panel_container.offset_top = info_height
	visual_panel_container.offset_right = 0.0
	visual_panel_container.offset_bottom = 0.0
	visual_panel_container.custom_minimum_size = Vector2.ZERO
	visual_panel_container.size_flags_vertical = Control.SIZE_FILL
	if environment_canvas != null:
		environment_canvas.custom_minimum_size = ENVIRONMENT_CANVAS_MIN_SIZE
	if game_surface_canvas != null:
		game_surface_canvas.custom_minimum_size = GAME_SURFACE_FOCUSED_MIN_SIZE
	run_layout_last_screen_size = screen_size
	run_layout_dirty = false


func _invalidate_run_screen_layout() -> void:
	run_layout_dirty = true


func _render_run_report() -> void:
	if run_report_screen == null:
		return
	var terminal := _is_failure_screen() or _is_victory_screen()
	run_report_screen.visible = terminal
	if not terminal or run_state == null:
		return
	var bag_reward_key := JSON.stringify({
		"pending": run_state.pending_bag_markers(),
		"grants": run_state.narrative_flags.get(CollectionDropServiceScript.GRANTS_FLAG, []),
		"selected": run_state.narrative_flags.get(CollectionDropServiceScript.SELECTED_FLAG, ""),
		"flushed": run_state.narrative_flags.get(CollectionDropServiceScript.FLUSHED_FLAG, false),
		"take_home_item_extracted": run_state.narrative_flags.get(RunReportViewModelScript.TAKE_HOME_ITEM_EXTRACTED_FLAG, false),
		"take_home_item_id": run_state.narrative_flags.get(RunReportViewModelScript.TAKE_HOME_ITEM_ID_FLAG, ""),
		"inventory": run_state.inventory,
	})
	var key := "%s|%s|%s|%s|%d|%d|%d|%d|%d" % [run_state.seed_text, run_state.run_status, run_state.run_failure_reason, str(run_state.narrative_flags.get("demo_victory_route", "")), run_state.story_log_entry_count(), run_state.heat_history.size(), run_state.rng_state, run_state.bankroll, hash(bag_reward_key)]
	if key == run_report_model_key:
		return
	run_report_model_key = key
	var run_data := run_state.to_dict()
	run_data["terminal_score"] = run_state.terminal_score_summary()
	run_report_model = RunReportViewModelScript.build(run_data, {
		"outcomes": RunReportViewModelScript.load_outcome_registry(),
		"items": RunReportViewModelScript.catalog_by_id(library.items if library != null else []),
		"games": RunReportViewModelScript.catalog_by_id(library.games if library != null else []),
	})
	run_report_screen.set_reduce_motion(_reduce_motion_enabled())
	run_report_screen.set_small_screen_mode(_small_screen_enabled())
	run_report_screen.set_report(run_report_model)


func _screen_for_action_category(category_id: String) -> String:
	match category_id:
		ACTION_CATEGORY_EVENTS:
			return SCREEN_EVENT
		ACTION_CATEGORY_ITEMS:
			return SCREEN_ITEMS
		ACTION_CATEGORY_TRAVEL:
			return SCREEN_TRAVEL
		_:
			return SCREEN_GAME if current_game != null else SCREEN_ENVIRONMENT


func _rebuild_actions(focused_object_override: Dictionary = {}) -> void:
	stake_input = null
	_clear(actions_list)
	_render_focused_context_panel(focused_object_override)


func _render_focused_context_panel(focused_object_override: Dictionary = {}) -> void:
	var object_data := focused_object_override
	if object_data.is_empty() or str(object_data.get("object_id", "")) != selected_object_id:
		object_data = _interactable_object(selected_object_id)
	if current_game != null and (object_data.is_empty() or str(object_data.get("object_type", "")) == CONTEXT_MODE_GAME):
		_add_current_game_panel(run_state.current_environment)
		return
	if object_data.is_empty():
		_render_empty_context_panel()
		return
	_render_selected_object_context(object_data)


func _render_empty_context_panel() -> void:
	var card := _begin_action_card("Look around", VisualStyle.CYAN_2)
	card.add_child(_label("Click something to inspect. Double-click to act.", 14))
	card.add_child(_muted_label("Bright props can act. Dim or locked props explain what is missing.", 12))
	var objects := _interactable_object_view_list()
	if objects.is_empty():
		card.add_child(_muted_label("Nothing is available here yet.", 12))
		return
	card.add_child(_label("Visible things nearby", 13))
	var shown := 0
	for object_data in objects:
		if typeof(object_data) != TYPE_DICTIONARY:
			continue
		var data: Dictionary = object_data
		var label := str(data.get("label", "Something"))
		var object_id := str(data.get("object_id", ""))
		if object_id.is_empty():
			continue
		if shown >= 5:
			continue
		var button := _button(label, Callable(self, "focus_interactable_object_from_view").bind(data.duplicate(true)))
		var enabled := bool(data.get("enabled", true))
		if not enabled:
			button.text = "%s - locked" % label
			button.modulate = Color(1.0, 0.80, 0.55, 0.86)
		card.add_child(button)
		if not enabled:
			var disabled_reason := str(data.get("disabled_reason", "Not available right now."))
			if not disabled_reason.strip_edges().is_empty():
				var reason_label := _muted_label(disabled_reason, 11)
				reason_label.max_lines_visible = 1
				card.add_child(reason_label)
		shown += 1


func _render_selected_object_context(object_data: Dictionary) -> void:
	var object_type := str(object_data.get("object_type", "info"))
	var title := str(object_data.get("label", "Something here"))
	var enabled := bool(object_data.get("enabled", true))
	var card := _begin_action_card(title, _context_border_color(object_type, enabled))
	_add_detail_row(card, "Type", _context_type_label(object_type))
	var description := str(object_data.get("short_description", ""))
	if not description.is_empty():
		_add_detail_row(card, "Does", description)
	_add_attribute_badge_row(card, object_data.get("attribute_badges", []), 16)
	var cost := str(object_data.get("cost_summary", ""))
	if not cost.is_empty() and object_type != CONTEXT_MODE_TRAVEL:
		_add_detail_row(card, "Cost", cost.replace("Cost:", "").strip_edges())
	var risk := str(object_data.get("risk_summary", ""))
	if not risk.is_empty() and object_type != CONTEXT_MODE_TRAVEL:
		_add_detail_row(card, "Risk", risk)
	if object_type == CONTEXT_MODE_TRAVEL:
		for preview_line in _copy_array(object_data.get("preview_lines", [])).slice(0, 4):
			var preview_text := str(preview_line).strip_edges()
			if not preview_text.is_empty():
				_add_detail_row(card, "Route", preview_text, true)
		var unlock_lines := _copy_array(object_data.get("unlock_conditions", []))
		if not unlock_lines.is_empty():
			_add_detail_row(card, "Unlock", "; ".join(unlock_lines.slice(0, 2)), true)
	var status := str(object_data.get("status_summary", ""))
	if not status.is_empty():
		_add_detail_row(card, "Status", status, true)
	if object_type == CONTEXT_MODE_GAME:
		_add_game_object_context_details(card, str(object_data.get("source_id", "")))
	var action_summary := str(object_data.get("action_summary", ""))
	var disabled_reason := str(object_data.get("disabled_reason", "Not available right now.")) if not enabled else ""
	if not enabled and action_summary == disabled_reason:
		action_summary = ""
	if not action_summary.is_empty():
		_add_detail_row(card, "Action", action_summary, not enabled)
	if not enabled:
		if disabled_reason.strip_edges().is_empty():
			disabled_reason = "Not available right now."
		_add_detail_row(card, "Locked", disabled_reason, true)
	_add_context_object_actions(card, object_data)
	_add_card_button(card, "Back to room", Callable(self, "clear_interaction_focus"))


func _add_attribute_badge_row(parent: BoxContainer, badges_value: Variant, glyph_size: int = 16) -> void:
	var badges := _copy_array(badges_value)
	if badges.is_empty():
		return
	var safe_glyph_size := clampi(glyph_size, 12, 18)
	AttributeBadgeRowScript.warm_cache(badges, safe_glyph_size)
	var row := AttributeBadgeRowScript.control_row(badges, safe_glyph_size)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)


func _add_context_object_actions(card: VBoxContainer, object_data: Dictionary) -> void:
	if not bool(object_data.get("enabled", true)):
		return
	var object_type := str(object_data.get("object_type", "info"))
	var source_id := str(object_data.get("source_id", ""))
	match object_type:
		CONTEXT_MODE_GAME:
			card.add_child(_muted_label("Double-click the machine to enter.", 13))
		CONTEXT_MODE_EVENT:
			if not _add_context_event_inline_actions(card, source_id, object_data.get("inline_actions", [])):
				_add_context_event_actions(card, source_id)
		CONTEXT_MODE_ITEM:
			_add_context_item_actions(card, source_id)
		CONTEXT_MODE_SHOPKEEPER:
			_add_context_shopkeeper_actions(card)
		CONTEXT_MODE_GAME_HOOK:
			_add_context_game_hook_actions(card, object_data)
		CONTEXT_MODE_DIALOGUE:
			_add_card_button(card, "Talk", Callable(self, "start_dialogue").bind(source_id, object_data), false, true)
		CONTEXT_MODE_CASINO_FIXTURE:
			_add_card_button(card, "Inspect", Callable(self, "_inspect_casino_fixture").bind(object_data), false, true)
		CONTEXT_MODE_HOME_TENURE:
			_add_card_button(card, str(object_data.get("label", "Pay")), Callable(self, "confirm_home_tenure_action"), false, true)
		CONTEXT_MODE_HOME_SLEEP:
			_add_card_button(card, "Sleep", Callable(self, "confirm_home_sleep_action"), false, true)
		CONTEXT_MODE_HOME_STORAGE:
			_add_card_button(card, "Place container", Callable(self, "_show_place_container_popup"), false, true)
		CONTEXT_MODE_HOME_CONTAINER:
			if _is_meta_session():
				_add_card_button(card, "Open contents", Callable(self, "open_meta_container").bind(source_id), false, true)
			else:
				_add_card_button(card, "Open storage", Callable(self, "activate_interactable_object").bind(str(object_data.get("object_id", ""))), false, true)
		CONTEXT_MODE_META_BAG:
			_add_card_button(card, "Open bag", Callable(self, "open_meta_bag").bind(int(source_id)), false, true)
		CONTEXT_MODE_META_UPGRADE:
			_add_card_button(card, "Buy upgrade", Callable(self, "buy_meta_home_upgrade"), false, true)
		CONTEXT_MODE_META_TRADE_UP:
			_add_card_button(card, "Review trades", Callable(self, "open_meta_trade_up"), false, true)
		CONTEXT_MODE_META_PAWN_COUNTER:
			_add_card_button(card, "Sell", Callable(self, "open_meta_sell_counter"), false, true)
		CONTEXT_MODE_META_SAL_SHELF:
			_add_card_button(card, "Inspect", Callable(self, "open_meta_sal_shelf").bind(int(source_id)), false, true)
		CONTEXT_MODE_META_SAL_TALK:
			_add_card_button(card, "Talk", Callable(self, "_talk_to_sal"), false, true)
		CONTEXT_MODE_TRAVEL:
			_add_context_travel_actions(card, source_id)
		CONTEXT_MODE_SERVICE:
			_add_context_service_actions(card, source_id)
		CONTEXT_MODE_LENDER:
			_add_context_lender_actions(card, source_id)


func _add_game_object_context_details(card: VBoxContainer, game_id: String) -> void:
	var preview := _game_entry_preview(game_id)
	if preview.is_empty() or not bool(preview.get("ok", false)):
		card.add_child(_muted_label("This game is not ready to play here.", 13))
		return
	if bool(preview.get("has_valid_stake", false)):
		card.add_child(_label("Stake: %d-%d" % [int(preview.get("stake_min", 1)), int(preview.get("stake_max", 1))], 13))
	else:
		card.add_child(_muted_label("No valid stake is available right now.", 13))
	card.add_child(_label("Legal plays: %d" % int(preview.get("legal_count", 0)), 13))
	card.add_child(_label("Risky plays: %d" % int(preview.get("cheat_count", 0)), 13))
	var risk_cue := str(preview.get("risk_cue", ""))
	if not risk_cue.is_empty():
		card.add_child(_label(risk_cue, 13))


func _add_context_event_actions(card: VBoxContainer, event_id: String) -> void:
	var event_option := _eligible_event_option(event_id)
	if event_option.is_empty():
		card.add_child(_muted_label("Nothing is happening here right now.", 13))
		return
	var event_definition := library.event(event_id) if library != null else {}
	if not str(event_definition.get("dialogue_id", "")).strip_edges().is_empty():
		_add_card_button(card, "Talk", Callable(self, "_start_event_dialogue").bind(event_id), false, true)
		return
	for choice in event_option.get("choices", []):
		if typeof(choice) != TYPE_DICTIONARY:
			continue
		var choice_data: Dictionary = choice
		var choice_id := str(choice_data.get("id", ""))
		if choice_id.is_empty():
			continue
		_add_event_choice_action_option(card, event_id, choice_data)


func _add_context_event_inline_actions(card: VBoxContainer, event_id: String, inline_actions_value: Variant) -> bool:
	if typeof(inline_actions_value) != TYPE_ARRAY:
		return false
	var inline_actions := inline_actions_value as Array
	var rendered := false
	for action_value in inline_actions:
		if typeof(action_value) != TYPE_DICTIONARY:
			continue
		var action_data: Dictionary = action_value
		var emit_id := str(action_data.get("emit_object_id", action_data.get("id", ""))).strip_edges()
		var separator := emit_id.rfind(":")
		var choice_id := emit_id.substr(separator + 1) if separator > 0 and separator < emit_id.length() - 1 else ""
		if choice_id.is_empty():
			continue
		var label := str(action_data.get("label", choice_id))
		var selected := bool(action_data.get("selected", false))
		var button := _add_card_button(card, label, Callable(self, "resolve_event_choice").bind(event_id, choice_id), false, selected)
		button.custom_minimum_size = Vector2(0, MIN_NATIVE_TOUCH_TARGET_HEIGHT)
		_set_control_font_size(button, 16)
		var detail := str(action_data.get("text", "")).strip_edges()
		if not detail.is_empty():
			var detail_label := _muted_label(detail, 11)
			_set_control_font_color(detail_label, VisualStyle.SOFT)
			detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			detail_label.max_lines_visible = EVENT_CHOICE_TEXT_MAX_LINES
			detail_label.clip_text = true
			card.add_child(detail_label)
		_add_attribute_badge_row(card, action_data.get("attribute_badges", []), 16)
		rendered = true
	return rendered


func _add_event_choice_action_option(stack: VBoxContainer, event_id: String, choice_data: Dictionary) -> void:
	var choice_id := str(choice_data.get("id", ""))
	if choice_id.is_empty():
		return
	var selected := event_id == selected_event_id and choice_id == selected_event_choice_id
	var label := str(choice_data.get("label", choice_id))
	var button := _add_card_button(stack, label, Callable(self, "resolve_event_choice").bind(event_id, choice_id), false, selected)
	button.custom_minimum_size = Vector2(0, MIN_NATIVE_TOUCH_TARGET_HEIGHT)
	_set_control_font_size(button, 16)
	var detail := _event_choice_action_detail(choice_data)
	if not detail.is_empty():
		var detail_label := _muted_label(detail, 11)
		_set_control_font_color(detail_label, VisualStyle.SOFT)
		detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail_label.max_lines_visible = EVENT_CHOICE_TEXT_MAX_LINES
		detail_label.clip_text = true
		stack.add_child(detail_label)
	_add_attribute_badge_row(stack, choice_data.get("attribute_badges", []), 16)


func _event_choice_action_detail(choice_data: Dictionary) -> String:
	var choice_text := str(choice_data.get("text", "")).strip_edges()
	if choice_text.is_empty():
		return "Resolve this response."
	return choice_text


func _event_inline_response_actions(event_id: String, choices: Array) -> Array:
	var actions: Array = []
	for choice in choices:
		if typeof(choice) != TYPE_DICTIONARY:
			continue
		var choice_data: Dictionary = choice
		var choice_id := str(choice_data.get("id", "")).strip_edges()
		if choice_id.is_empty():
			continue
		var label := str(choice_data.get("label", choice_id)).strip_edges()
		if label.is_empty():
			label = choice_id
		var impact := str(choice_data.get("impact_summary", choice_data.get("consequence_summary", ""))).strip_edges()
		var emit_object_id := "event_response:%s:%s" % [event_id, choice_id]
		actions.append({
			"id": emit_object_id,
			"emit_object_id": emit_object_id,
			"label": label,
			"text": _event_choice_action_detail(choice_data),
			"impact_summary": impact,
			"attribute_badges": _copy_array(choice_data.get("attribute_badges", [])),
			"selected": event_id == selected_event_id and choice_id == selected_event_choice_id,
		})
	return actions


func _add_context_item_actions(card: VBoxContainer, item_id: String) -> void:
	var offer := _item_offer(item_id)
	if offer.is_empty():
		card.add_child(_muted_label("That offer is no longer available.", 13))
		return
	var action_label := str(offer.get("action_label", "Buy"))
	if selected_item_offer_id == item_id:
		_add_card_button(card, action_label, Callable(self, "confirm_selected_item_offer"), false, true)
	else:
		_add_card_button(card, "Select item", Callable(self, "select_item_offer").bind(item_id))


func _add_context_shopkeeper_actions(card: VBoxContainer) -> void:
	card.add_child(_label(_shop_description(), 13))
	_add_card_button(card, "Sell items", Callable(self, "open_shopkeeper_sale_page"), false, true)


func _add_context_game_hook_actions(card: VBoxContainer, object_data: Dictionary) -> void:
	var game_id := str(object_data.get("parent_id", ""))
	var hook_id := str(object_data.get("source_id", ""))
	var action_id := str(object_data.get("confirm_action_id", ""))
	var label := "Use"
	var actions := _copy_array(object_data.get("available_actions", []))
	if not actions.is_empty() and typeof(actions[0]) == TYPE_DICTIONARY:
		label = str((actions[0] as Dictionary).get("label", label))
		if action_id.is_empty():
			action_id = str((actions[0] as Dictionary).get("id", ""))
	_add_card_button(card, label, Callable(self, "use_game_environment_hook").bind(game_id, hook_id, action_id), false, true)


func _add_context_travel_actions(card: VBoxContainer, target_id: String) -> void:
	if target_id == "leave":
		var choices := _travel_choice_view_list()
		for choice_value in choices.slice(0, 4):
			if typeof(choice_value) != TYPE_DICTIONARY:
				continue
			var choice: Dictionary = choice_value
			var line := str(choice.get("label", choice.get("id", "Route")))
			if not bool(choice.get("enabled", true)):
				line += " (locked)"
			card.add_child(_muted_label(line, 12))
			_add_attribute_badge_row(card, choice.get("attribute_badges", []), 16)
		if not selected_travel_target_id.is_empty():
			_add_card_button(card, "Travel to %s" % selected_travel_label, Callable(self, "confirm_selected_travel"), false, true)
			_add_card_button(card, "Open Map", Callable(self, "open_world_map"))
			return
		var direct_room_exit := _local_parent_home_door_travel_choice(_parent_home_parent_target_id())
		if not direct_room_exit.is_empty():
			for preview_line in _copy_array(direct_room_exit.get("preview_lines", [])):
				var preview_text := str(preview_line).strip_edges()
				if not preview_text.is_empty():
					card.add_child(_muted_label(preview_text, 12))
			_add_attribute_badge_row(card, direct_room_exit.get("attribute_badges", []), 16)
			if not bool(direct_room_exit.get("enabled", true)):
				card.add_child(_muted_label(str(direct_room_exit.get("disabled_reason", "That door is not available right now.")), 13))
				return
			_add_card_button(card, "Enter Lobby", Callable(self, "_travel_to").bind(str(direct_room_exit.get("id", "")), str(direct_room_exit.get("label", "Lobby")), direct_room_exit), false, true)
			return
		_add_card_button(card, "Open Map", Callable(self, "open_world_map"), selected_travel_target_id.is_empty(), selected_travel_target_id.is_empty())
		return
	var local_door_choice := _local_parent_home_door_travel_choice(target_id)
	if not local_door_choice.is_empty():
		for preview_line in _copy_array(local_door_choice.get("preview_lines", [])):
			var preview_text := str(preview_line).strip_edges()
			if not preview_text.is_empty():
				card.add_child(_muted_label(preview_text, 12))
		_add_attribute_badge_row(card, local_door_choice.get("attribute_badges", []), 16)
		if not bool(local_door_choice.get("enabled", true)):
			card.add_child(_muted_label(str(local_door_choice.get("disabled_reason", "That door is not available right now.")), 13))
			return
		_add_card_button(card, "Enter Room", Callable(self, "_travel_to").bind(str(local_door_choice.get("id", "")), str(local_door_choice.get("label", "Room")), local_door_choice), false, true)
		return
	var choice := _travel_choice(target_id)
	if choice.is_empty():
		card.add_child(_muted_label("That route is no longer available.", 13))
		return
	for preview_line in _copy_array(choice.get("preview_lines", [])).slice(0, 4):
		var preview_text := str(preview_line).strip_edges()
		if not preview_text.is_empty():
			card.add_child(_muted_label(preview_text, 12))
	_add_attribute_badge_row(card, choice.get("attribute_badges", []), 16)
	var unlock_lines := _copy_array(choice.get("unlock_conditions", []))
	if not unlock_lines.is_empty():
		card.add_child(_muted_label("Unlock: %s" % "; ".join(unlock_lines.slice(0, 2)), 12))
	if not bool(choice.get("enabled", true)):
		card.add_child(_muted_label(str(choice.get("disabled_reason", "That route is not available right now.")), 13))
		return
	if selected_travel_target_id == target_id:
		_add_card_button(card, "Travel to %s" % selected_travel_label, Callable(self, "confirm_selected_travel"), false, true)
	else:
		_add_card_button(card, "Choose route", Callable(self, "select_travel_option").bind(target_id))


func _add_context_service_actions(card: VBoxContainer, service_id: String) -> void:
	var option := _service_hook(service_id)
	if option.is_empty() or not bool(option.get("mutation_supported", false)):
		card.add_child(_muted_label(str(option.get("status", "Not usable yet.")), 13))
		return
	if not bool(option.get("enabled", true)):
		card.add_child(_muted_label(str(option.get("disabled_reason", "Service cannot be used right now.")), 13))
		return
	if selected_service_hook_id == service_id:
		_add_card_button(card, "Use %s" % selected_service_hook_label, Callable(self, "confirm_selected_service_hook"), false, true)
	else:
		_add_card_button(card, "Select service", Callable(self, "select_service_hook").bind(service_id))


func _add_context_lender_actions(card: VBoxContainer, lender_id: String) -> void:
	var option := _lender_hook(lender_id)
	if option.is_empty() or not bool(option.get("mutation_supported", false)):
		card.add_child(_muted_label(str(option.get("status", "Not usable yet.")), 13))
		return
	if _lender_is_pawn_counter(lender_id):
		var quotes := run_action_service.pawn_quote_options(lender_id)
		var tickets := run_state.pawn_tickets_for_lender(lender_id) if run_state != null else []
		if quotes.is_empty() and tickets.is_empty():
			card.add_child(_muted_label(str(option.get("disabled_reason", "Sal needs a sellable item as collateral.")), 13))
		else:
			card.add_child(_muted_label("%d item%s to pawn, %d ticket%s open." % [quotes.size(), "" if quotes.size() == 1 else "s", tickets.size(), "" if tickets.size() == 1 else "s"], 13))
		_add_card_button(card, "Open Pawn Counter", Callable(self, "open_pawn_counter").bind(lender_id), false, true)
		return
	if not bool(option.get("enabled", true)):
		if run_state != null:
			var repayment := run_state.lender_repayment_status(lender_id)
			if bool(repayment.get("available", false)):
				card.add_child(_muted_label(str(option.get("disabled_reason", "Lender cannot be used right now.")), 13))
				var payoff := maxi(0, int(repayment.get("payoff_amount", 0)))
				var disabled := not bool(repayment.get("enabled", false))
				_add_card_button(card, "Pay $%d" % payoff, Callable(self, "repay_lender_debt").bind(lender_id), disabled, not disabled)
				if disabled:
					card.add_child(_muted_label(str(repayment.get("disabled_reason", "Not enough bankroll to repay this loan.")), 13))
				return
		card.add_child(_muted_label(str(option.get("disabled_reason", "Lender cannot be used right now.")), 13))
		return
	if selected_lender_hook_id == lender_id:
		_add_card_button(card, "Use %s" % selected_lender_hook_label, Callable(self, "confirm_selected_lender_hook"), false, true)
	else:
		_add_card_button(card, "Select lender", Callable(self, "select_lender_hook").bind(lender_id))


func _context_border_color(object_type: String, enabled: bool) -> Color:
	return EnvironmentInteractionViewModelScript.context_border_color(object_type, enabled)


func _context_type_label(object_type: String) -> String:
	return EnvironmentInteractionViewModelScript.context_type_label(object_type)


func _action_category_view_list() -> Array:
	var environment := run_state.current_environment
	var game_count := _string_array(environment.get("game_ids", [])).size()
	var event_count := _eligible_event_option_view_list().size()
	var item_count := _item_offer_view_list().size()
	var inventory_count := _inventory_item_view_list().size()
	var shopkeeper_count := 1 if _shopkeeper_available() else 0
	var game_hook_count := _game_hook_interactable_objects().size()
	var service_count := _service_hook_view_list().size()
	var lender_count := _lender_hook_view_list().size()
	var travel_count := _travel_choice_view_list().size()
	return [
		{
			"id": ACTION_CATEGORY_GAMES,
			"title": "Games",
			"description": "Click a machine to inspect it. Double-click to enter.",
			"count": game_count,
			"enabled": game_count > 0 or current_game != null,
			"empty_text": "No games are open here. Try an event, item, or travel option.",
		},
		{
			"id": ACTION_CATEGORY_EVENTS,
			"title": "Events",
			"description": "Respond to anything currently happening in this place.",
			"count": event_count,
			"enabled": event_count > 0,
			"empty_text": "Nothing unusual is happening here right now.",
		},
		{
			"id": ACTION_CATEGORY_ITEMS,
			"title": "Items",
			"description": "Inspect gear, talk to merchants, buy useful items, or review nearby help.",
			"count": item_count + inventory_count + shopkeeper_count + game_hook_count + service_count + lender_count,
			"enabled": item_count + inventory_count + shopkeeper_count + game_hook_count + service_count + lender_count > 0,
			"empty_text": "Nothing useful is being offered here and your pockets are empty.",
		},
		{
			"id": ACTION_CATEGORY_TRAVEL,
			"title": "Travel",
			"description": "Choose where to go next when a route is available.",
			"count": travel_count,
			"enabled": travel_count > 0,
			"empty_text": "No route is available from here yet.",
		},
	]


func _action_category(category_id: String) -> Dictionary:
	for category in _action_category_view_list():
		if typeof(category) == TYPE_DICTIONARY and str((category as Dictionary).get("id", "")) == category_id:
			return (category as Dictionary).duplicate(true)
	return {}


func _focus_first_interactable_for_category(category_id: String) -> void:
	if current_game != null and category_id == ACTION_CATEGORY_GAMES:
		return
	var wanted_type := ""
	match category_id:
		ACTION_CATEGORY_GAMES:
			wanted_type = CONTEXT_MODE_GAME
		ACTION_CATEGORY_EVENTS:
			wanted_type = CONTEXT_MODE_EVENT
		ACTION_CATEGORY_TRAVEL:
			wanted_type = CONTEXT_MODE_TRAVEL
		ACTION_CATEGORY_ITEMS:
			for item_type in [CONTEXT_MODE_ITEM, CONTEXT_MODE_SHOPKEEPER, CONTEXT_MODE_GAME_HOOK, CONTEXT_MODE_DIALOGUE, CONTEXT_MODE_SERVICE, CONTEXT_MODE_LENDER]:
				for object_data in _interactable_object_view_list():
					if typeof(object_data) == TYPE_DICTIONARY and str((object_data as Dictionary).get("object_type", "")) == item_type:
						focus_interactable_object(str((object_data as Dictionary).get("object_id", "")))
						return
	if wanted_type.is_empty():
		clear_interaction_focus()
		return
	for object_data in _interactable_object_view_list():
		if typeof(object_data) == TYPE_DICTIONARY and str((object_data as Dictionary).get("object_type", "")) == wanted_type:
			focus_interactable_object(str((object_data as Dictionary).get("object_id", "")))
			return
	clear_interaction_focus()


func _add_current_game_panel(environment: Dictionary) -> void:
	var action_view := current_game.actions(run_state, environment)
	var panel := _panel_container(VisualStyle.DARK_2, VisualStyle.YELLOW)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions_list.add_child(panel)
	var previous_actions_list := actions_list
	var panel_stack := VBoxContainer.new()
	panel_stack.add_theme_constant_override("separation", 3)
	panel_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(panel_stack)
	actions_list = panel_stack
	actions_list.add_child(_section("Game"))
	actions_list.add_child(_label(current_game.get_display_name(), 15))
	var description := _current_game_description()
	if not description.is_empty():
		var description_label := _label(description, 11)
		description_label.max_lines_visible = 1
		description_label.clip_text = true
		actions_list.add_child(description_label)
	var balance_text := "Current bankroll: %d" % _presented_bankroll()
	if run_state.grand_casino_game_uses_chips(current_game.get_id(), environment):
		balance_text = "Current chips: %d  |  Cash: %d" % [run_state.grand_casino_chips, run_state.bankroll]
	actions_list.add_child(_label(balance_text, 12))
	actions_list.add_child(_button("Back to environment", Callable(self, "back_to_environment")))
	actions_list.add_child(_section("Stake"))
	_add_stake_controls(action_view)
	actions_list.add_child(_section("Selected action"))
	if selected_action_id.is_empty():
		actions_list.add_child(_label("Click a glowing action region on the game surface.", 12))
	else:
		var selected_label := _label(_selected_action_summary(), 11)
		selected_label.max_lines_visible = 1
		selected_label.clip_text = true
		actions_list.add_child(selected_label)
		var resolve_text := "Accessibility confirm risky action" if selected_action_kind == "cheat" else "Accessibility confirm safe action"
		actions_list.add_child(_button("%s: %s" % [resolve_text, selected_action_label], Callable(self, "resolve_selected_game_action")))
	actions_list.add_child(_section("Legal actions"))
	_add_game_action_buttons(action_view.get("legal_actions", []), "legal")
	actions_list.add_child(_section("Cheat / advantage actions"))
	var risk_label := _label(_cheat_action_risk_cue(action_view.get("cheat_actions", [])), 11)
	risk_label.max_lines_visible = 1
	risk_label.clip_text = true
	actions_list.add_child(risk_label)
	_add_game_action_buttons(action_view.get("cheat_actions", []), "cheat")
	actions_list.add_child(_section("Recent outcome"))
	var outcome_label := _label(_game_recent_outcome_text(), 11)
	outcome_label.max_lines_visible = 1
	outcome_label.clip_text = true
	actions_list.add_child(outcome_label)
	actions_list = previous_actions_list


func _resolve_game_action(action_id: String, skip_stake_validation: bool = false, preserve_surface_ui_state: bool = false, wager_confirmed: bool = false) -> void:
	if action_id.is_empty() or current_game == null:
		return
	if not wager_confirmed and _guard_player_input_route():
		return
	var stake := selected_stake
	if stake <= 0:
		stake = _default_stake()
	if not skip_stake_validation and not _is_valid_stake(stake):
		var range := _stake_range()
		_show_message("Stake must be between %d and %d." % [int(range.get("min", 1)), int(range.get("max", 1))])
		_refresh_stake_input()
		return
	var wager_cost := _wager_cost_for_action(action_id, stake)
	if not wager_confirmed and _wager_needs_final_bankroll_confirmation(current_game, action_id, stake, wager_cost, _current_game_surface_ui_state()):
		_pause_repeating_surface_action_for_wager_confirmation()
		_show_wager_confirmation_popup(action_id, stake, wager_cost, skip_stake_validation, preserve_surface_ui_state)
		return
	var confirmed_all_in_wager := wager_confirmed and _wager_needs_final_bankroll_confirmation(current_game, action_id, stake, wager_cost, _current_game_surface_ui_state())
	if confirmed_all_in_wager:
		run_state.begin_deferred_bankroll_zero_resolution()
	var wager_funding := run_state.fund_grand_casino_wager(current_game.get_id(), wager_cost, run_state.current_environment)
	if not bool(wager_funding.get("ok", false)):
		if confirmed_all_in_wager:
			run_state.clear_deferred_bankroll_zero_resolution()
		_show_message(str(wager_funding.get("message", "You do not have enough cash or chips for that wager.")))
		_refresh()
		return
	var bankroll_before_result := run_state.bankroll
	var rng := run_state.create_rng()
	var result := current_game.resolve_with_context(action_id, stake, run_state, run_state.current_environment, rng, _current_game_surface_ui_state())
	if bool(result.get("ok", false)):
		_record_scratch_ticket_discovery(str(result.get("scratch_discovered_type_id", "")))
	if confirmed_all_in_wager:
		result["defer_bankroll_zero_failure"] = true
	var result_updates_surface_ui := result.has("ui_state") and typeof(result.get("ui_state")) == TYPE_DICTIONARY
	if result_updates_surface_ui:
		_store_current_game_surface_ui_state(result.get("ui_state", {}) as Dictionary)
		preserve_surface_ui_state = bool(result.get("preserve_surface_ui_state", true))
	var runtime_tick := bool(result.get("slot_runtime_tick", false))
	var runtime_tick_in_progress := runtime_tick and not bool(result.get("slot_bonus_complete", false))
	if bool(result.get("ok", false)):
		if not runtime_tick_in_progress:
			run_state.advance_environment_turns(1)
		if bool(result.get("host_apply_result", false)) and not runtime_tick_in_progress:
			GameModule.apply_result(run_state, result, rng)
		elif runtime_tick_in_progress:
			run_state.save_rng(rng)
	elif confirmed_all_in_wager:
		run_state.clear_deferred_bankroll_zero_resolution()
	if confirmed_all_in_wager and run_state.defer_next_bankroll_zero_failure:
		run_state.clear_deferred_bankroll_zero_resolution()
	var embeds_result_feedback := _current_game_embeds_result_feedback()
	if bool(result.get("ok", false)) and embeds_result_feedback and not runtime_tick_in_progress:
		_begin_presented_bankroll_hold(result, bankroll_before_result, wager_cost)
	last_game_result = result.duplicate(true)
	if bool(result.get("ok", false)) and (not runtime_tick_in_progress or _music_result_bankroll_delta(result) != 0):
		var outcome_schedule := _schedule_game_result_music_outcome(result, action_id)
		if not outcome_schedule.is_empty():
			last_game_result["music_outcome_schedule"] = outcome_schedule
	_play_result_surface_audio_cue(result)
	_play_result_drink_audio_cue(result)
	pending_all_in_result_terminal_check = confirmed_all_in_wager and bool(result.get("ok", false)) and run_state != null and not run_state.has_liquid_run_funds() and not bool(result.get("won", false))
	if runtime_tick_in_progress:
		if game_surface_canvas != null and current_screen == SCREEN_GAME:
			game_surface_canvas.render_game_snapshot(_game_view_snapshot())
		return
	if not preserve_surface_ui_state:
		game_surface_ui_state = _preserved_game_surface_preference_state(game_surface_ui_state)
	_clear_selected_game_action()
	if embeds_result_feedback:
		_set_current_screen(SCREEN_GAME)
	else:
		_set_current_screen(SCREEN_RESULT)
	_show_message(str(result.get("message", "")))
	if bool(result.get("ok", false)):
		_advance_alcohol_absorption()
	_autosave_foundation_run("Autosaved.")
	if bool(result.get("ok", false)) and _apply_post_action_environment_interrupt("game_action"):
		if current_screen != SCREEN_GAME:
			_sync_presented_bankroll_to_actual()
		_refresh()
		return
	_refresh()


func _play_result_surface_audio_cue(result: Dictionary) -> void:
	if game_surface_canvas == null or result.is_empty() or not bool(result.get("ok", false)):
		return
	var cue_id := str(result.get("surface_audio_cue", "")).strip_edges()
	if cue_id.is_empty():
		return
	var context: Dictionary = {}
	var context_value: Variant = result.get("surface_audio_context", {})
	if typeof(context_value) == TYPE_DICTIONARY:
		context = (context_value as Dictionary).duplicate(true)
	if not context.has("action"):
		context["action"] = cue_id
	game_surface_canvas.surface_play_audio_cue(cue_id, context)


func _play_result_drink_audio_cue(result: Dictionary) -> void:
	if not _result_consumed_alcohol(result) or game_surface_canvas == null:
		return
	game_surface_canvas.surface_play_audio_cue("drink_consumed", {
		"action": "drink_consumed",
		"volume_db": -2.0,
	})


func _result_consumed_alcohol(result: Dictionary) -> bool:
	if result.is_empty() or not bool(result.get("ok", false)):
		return false
	var deltas: Dictionary = result.get("deltas", {}) if typeof(result.get("deltas", {})) == TYPE_DICTIONARY else {}
	return int(deltas.get("alcohol_intake", result.get("alcohol_intake", 0))) > 0


func confirm_pending_wager_action() -> void:
	if pending_wager_confirm_action_id.is_empty():
		_hide_event_choice_popup()
		return
	var action_id := pending_wager_confirm_action_id
	var skip_stake_validation := pending_wager_confirm_skip_stake_validation
	var preserve_surface_ui_state := pending_wager_confirm_preserve_surface_ui_state
	var source_game_id := pending_wager_confirm_source_game_id
	_clear_pending_wager_confirmation()
	_hide_event_choice_popup()
	if not source_game_id.is_empty() and (current_game == null or source_game_id != current_game.get_id()):
		_resolve_environment_runtime_wager_action(source_game_id, action_id, true)
	else:
		_resolve_game_action(action_id, skip_stake_validation, preserve_surface_ui_state, true)


func cancel_pending_wager_confirmation() -> void:
	_clear_pending_wager_confirmation()
	_hide_event_choice_popup()
	_show_message("All-in wager canceled. Choose a smaller stake or another action.")
	_refresh()


func _wager_cost_for_action(action_id: String, stake: int) -> int:
	if current_game == null or run_state == null:
		return 0
	return maxi(0, current_game.wager_cost_for_context(action_id, stake, run_state, run_state.current_environment, _current_game_surface_ui_state()))


func _wager_needs_final_bankroll_confirmation(game: GameModule, action_id: String, stake: int, wager_cost: int, ui_state: Dictionary = {}, environment_data: Dictionary = {}) -> bool:
	if run_state == null or game == null or wager_cost <= 0:
		return false
	var wager_environment := environment_data if not environment_data.is_empty() else run_state.current_environment
	var guaranteed_return := maxi(0, game.minimum_wager_return_for_context(
		action_id,
		stake,
		wager_cost,
		run_state,
		wager_environment,
		ui_state
	))
	var wager_balance := run_state.wager_capacity_for_game(game.get_id(), wager_environment)
	return wager_balance > 0 and wager_balance - wager_cost + guaranteed_return <= 0


func _pause_environment_runtime_for_wager_confirmation(game: GameModule, _game_id: String, environment_data: Dictionary = {}) -> void:
	if game == null or run_state == null:
		return
	var wager_environment := environment_data if not environment_data.is_empty() else run_state.current_environment
	var command := game.surface_pause_repeating_action_for_confirmation({}, run_state, wager_environment)
	if not command.is_empty() and bool(command.get("handled", false)):
		_show_message(str(command.get("message", "Autoplay paused for confirmation.")))


func _resolve_environment_runtime_wager_action(game_id: String, action_id: String, wager_confirmed: bool = false) -> void:
	if run_state == null or library == null or game_id.is_empty():
		return
	var game := _game_module_for_id(game_id)
	if game == null:
		_show_message("That background game is no longer available.")
		_refresh()
		return
	var wager_cost := maxi(0, game.wager_cost_for_context(action_id, 0, run_state, run_state.current_environment, {}))
	var confirmed_all_in_wager := wager_confirmed and _wager_needs_final_bankroll_confirmation(game, action_id, 0, wager_cost, {})
	if confirmed_all_in_wager:
		run_state.begin_deferred_bankroll_zero_resolution()
	var rng := run_state.create_rng()
	var result := game.resolve_with_context(action_id, 0, run_state, run_state.current_environment, rng, {})
	if confirmed_all_in_wager:
		result["defer_bankroll_zero_failure"] = true
	if bool(result.get("ok", false)):
		run_state.advance_environment_turns(1)
		if bool(result.get("host_apply_result", false)):
			GameModule.apply_result(run_state, result, rng)
	elif confirmed_all_in_wager:
		run_state.clear_deferred_bankroll_zero_resolution()
	if confirmed_all_in_wager and run_state.defer_next_bankroll_zero_failure:
		run_state.clear_deferred_bankroll_zero_resolution()
	last_environment_runtime_result = result.duplicate(true)
	if current_game == null:
		last_game_result = result.duplicate(true)
	pending_all_in_result_terminal_check = confirmed_all_in_wager and bool(result.get("ok", false)) and run_state != null and not run_state.has_liquid_run_funds() and not bool(result.get("won", false))
	var runtime_state := game.environment_runtime_state(run_state, run_state.current_environment)
	if bool(runtime_state.get("slot_pending_feature", false)):
		_play_environment_audio_cue(_slot_runtime_feature_audio_cue(runtime_state), float(runtime_state.get("slot_feature_audio_volume_db", -1.0)))
		_show_message("%s feature is ready. Open the machine to play it." % game.get_display_name())
	else:
		_show_message(str(result.get("message", "")))
	if bool(result.get("ok", false)):
		_advance_alcohol_absorption()
	_autosave_foundation_run("Autosaved.")
	if bool(result.get("ok", false)) and _apply_post_action_environment_interrupt("environment_game"):
		_refresh_runtime_environment_views()
		return
	_refresh_runtime_environment_views()


func _blocking_decision_popup_is_visible() -> bool:
	if not _event_choice_popup_is_visible():
		return false
	return bool(pending_event_choice_popup_snapshot.get("blocking", true))


func _modal_contract_blocks_player_input() -> bool:
	return travel_transition_active or _event_choice_popup_is_visible() or _meta_item_interaction_is_visible() or _run_inventory_popup_is_visible() or _run_journal_popup_is_visible() or _world_map_overlay_is_visible() or _run_menu_is_visible()


func _blocking_modal_message() -> String:
	if travel_transition_active:
		return "Travel is already in progress."
	if _event_choice_popup_is_visible():
		return "Choose a response before doing anything else."
	if _world_map_overlay_is_visible():
		return "Close the map before doing anything else."
	if _meta_item_interaction_is_visible():
		return "Close the item view before doing anything else."
	if _run_inventory_popup_is_visible():
		return "Close inventory before doing anything else."
	if _run_journal_popup_is_visible():
		return "Close the journal before doing anything else."
	if _run_menu_is_visible():
		return "Close the menu before doing anything else."
	return ""


func _guard_player_input_route(force_closing_allowed: bool = false, coach_action_id: String = "ui:any") -> bool:
	var message := _blocking_modal_message()
	if message.is_empty():
		if not force_closing_allowed and _closing_time_blocks_environment_actions():
			if not _ensure_closing_time_departure_talk():
				_show_message(_closing_time_disabled_reason())
			return true
		if coach_overlay != null:
			if not coach_overlay.input_allowed(coach_action_id):
				_show_message("Follow the highlighted advice first.")
				return true
			coach_overlay.notify_action(coach_action_id)
		return false
	_show_message(message)
	_refresh_modal_contract_owner()
	return true


func _guard_blocking_decision_or_transition() -> bool:
	if travel_transition_active:
		_show_message("Travel is already in progress.")
		_refresh_modal_contract_owner()
		return true
	if _event_choice_popup_is_visible():
		_show_message("Choose a response before doing anything else.")
		_refresh_modal_contract_owner()
		return true
	return false


func _closing_time_blocks_environment_actions() -> bool:
	if run_state == null or not run_state.closing_time_forced_travel_required():
		return false
	return _closing_time_state_matches_current_environment() and not _current_wager_activity_incomplete()


func _closing_time_state_matches_current_environment() -> bool:
	if run_state == null or run_state.current_environment.is_empty():
		return false
	var state := run_state.closing_time_status()
	if state.is_empty():
		return false
	var state_environment_id := str(state.get("environment_id", "")).strip_edges()
	var state_world_node_id := str(state.get("world_node_id", "")).strip_edges()
	var environment_id := str(run_state.current_environment.get("id", "")).strip_edges()
	var world_node_id := str(run_state.current_environment.get("world_node_id", run_state.current_environment.get("archetype_id", ""))).strip_edges()
	return (not state_environment_id.is_empty() and state_environment_id == environment_id) or (not state_world_node_id.is_empty() and state_world_node_id == world_node_id)


func _closing_time_disabled_reason() -> String:
	if run_state == null:
		return "This venue is closed. Open the map."
	var state := run_state.closing_time_status()
	var message := str(state.get("message", "")).strip_edges()
	if message.is_empty():
		message = "%s is closed. Open the map." % str(run_state.current_environment.get("display_name", "This venue"))
	return message


func _refresh_modal_contract_owner() -> void:
	if run_state != null and current_screen != SCREEN_START:
		_refresh_world_header()
		_render_foundation_snapshots()
	if _world_map_overlay_is_visible():
		_refresh_world_map_overlay()
	if _run_inventory_popup_is_visible():
		_render_run_inventory_popup_contents()
	if _meta_item_interaction_is_visible():
		_refresh_meta_item_interaction()
	if _run_journal_popup_is_visible():
		_render_run_journal_contents()
	if _run_menu_is_visible():
		_refresh_run_menu()


func _event_choice_popup_allows_event_resolution(event_id: String) -> bool:
	if not _event_choice_popup_is_visible():
		return true
	var popup_type := str(pending_event_choice_popup_snapshot.get("popup_type", ""))
	if not ["triggered_event", "unavoidable_event", "interactable_event"].has(popup_type):
		return false
	var popup_event_id := str(pending_event_choice_popup_snapshot.get("event_id", ""))
	return popup_event_id.is_empty() or popup_event_id == event_id


func _world_map_overlay_is_visible() -> bool:
	return world_map_overlay != null and world_map_overlay.visible


func current_overlay_state_snapshot() -> Dictionary:
	var snapshot := {
		"screen": current_screen,
		"event_choice_popup_visible": _event_choice_popup_is_visible(),
		"event_choice_popup_type": str(pending_event_choice_popup_snapshot.get("popup_type", "")),
		"event_choice_popup_blocking": _blocking_decision_popup_is_visible(),
		"talk_dock_visible": talk_dock != null and talk_dock.visible,
		"world_map_visible": _world_map_overlay_is_visible(),
		"meta_item_interaction_visible": _meta_item_interaction_is_visible(),
		"run_inventory_visible": _run_inventory_popup_is_visible(),
		"run_inventory_mode": run_inventory_popup_mode,
		"run_journal_visible": _run_journal_popup_is_visible(),
		"run_menu_visible": _run_menu_is_visible(),
		"settings_visible": settings_overlay != null and settings_overlay.visible,
		"travel_transition_active": travel_transition_active,
		"travel_transition_target_id": travel_transition_target_id,
	}
	var violations := _overlay_state_contract_violations(snapshot)
	snapshot["violations"] = violations
	snapshot["contract_valid"] = violations.is_empty()
	return snapshot


func _overlay_state_contract_violations(snapshot: Dictionary = {}) -> Array:
	if snapshot.is_empty():
		snapshot = {
			"screen": current_screen,
			"event_choice_popup_visible": _event_choice_popup_is_visible(),
			"event_choice_popup_type": str(pending_event_choice_popup_snapshot.get("popup_type", "")),
			"world_map_visible": _world_map_overlay_is_visible(),
			"run_inventory_visible": _run_inventory_popup_is_visible(),
			"run_journal_visible": _run_journal_popup_is_visible(),
			"run_menu_visible": _run_menu_is_visible(),
			"settings_visible": settings_overlay != null and settings_overlay.visible,
			"travel_transition_active": travel_transition_active,
		}
	var violations: Array = []
	var event_visible := bool(snapshot.get("event_choice_popup_visible", false))
	var world_map_visible := bool(snapshot.get("world_map_visible", false))
	var inventory_visible := bool(snapshot.get("run_inventory_visible", false))
	var journal_visible := bool(snapshot.get("run_journal_visible", false))
	var settings_visible := bool(snapshot.get("settings_visible", false))
	var run_menu_visible := bool(snapshot.get("run_menu_visible", false))
	var travel_visible := bool(snapshot.get("travel_transition_active", false))
	if travel_visible:
		for label in ["event_choice_popup_visible", "world_map_visible", "run_inventory_visible", "run_journal_visible", "run_menu_visible", "settings_visible"]:
			if bool(snapshot.get(label, false)):
				violations.append("travel_transition overlaps %s" % label)
	if event_visible:
		for label in ["world_map_visible", "run_inventory_visible", "run_journal_visible", "run_menu_visible", "settings_visible"]:
			if bool(snapshot.get(label, false)):
				violations.append("decision_popup overlaps %s" % label)
	if world_map_visible:
		for label in ["run_inventory_visible", "run_journal_visible", "run_menu_visible", "settings_visible"]:
			if bool(snapshot.get(label, false)):
				violations.append("world_map overlaps %s" % label)
	if inventory_visible and journal_visible:
		violations.append("inventory overlaps journal")
	if inventory_visible and settings_visible:
		violations.append("inventory overlaps settings")
	if journal_visible and settings_visible:
		violations.append("journal overlaps settings")
	if settings_visible and not run_menu_visible and current_screen != SCREEN_START:
		violations.append("in-run settings opened without run menu")
	return violations


func _pause_repeating_surface_action_for_wager_confirmation() -> void:
	if current_game == null or run_state == null:
		return
	var command := current_game.surface_pause_repeating_action_for_confirmation(_current_game_surface_ui_state(), run_state, run_state.current_environment)
	if not command.is_empty() and bool(command.get("handled", false)):
		_show_message(str(command.get("message", "Repeating play paused for confirmation.")))


func _wager_confirmation_action_label(action_id: String, source_game_id: String = "") -> String:
	if not source_game_id.is_empty():
		var source_game := _game_module_for_id(source_game_id)
		if source_game != null:
			return "%s autoplay spin" % source_game.get_display_name()
	var action := _available_game_action(action_id, selected_action_kind)
	if action.is_empty():
		action = _available_game_action(action_id, "legal")
	if action.is_empty():
		action = _available_game_action(action_id, "cheat")
	return _action_label(action) if not action.is_empty() else action_id


func _play_environment_audio_cue(cue_id: String, volume_db: float = -1.0) -> void:
	var normalized_cue := cue_id.strip_edges()
	if normalized_cue.is_empty():
		return
	if environment_sfx_player == null:
		environment_sfx_player = SfxPlayerScript.new()
		add_child(environment_sfx_player)
	if normalized_cue.begins_with("bonus_start") and environment_sfx_player.has_method("play_slot_event"):
		environment_sfx_player.call("play_slot_event", normalized_cue, volume_db, 1.0)
	elif environment_sfx_player.has_method("play_surface_cue"):
		environment_sfx_player.call("play_surface_cue", normalized_cue, {"route": "slot_button", "action": normalized_cue, "volume_db": volume_db}, {})


func _on_game_surface_music_cue(cue_id: String, context: Dictionary) -> void:
	if procedural_music_player == null:
		return
	var normalized_cue := cue_id.strip_edges()
	if normalized_cue.is_empty():
		return
	if normalized_cue.begins_with("bonus_music"):
		var feature_scene: Dictionary = _copy_dict(context.get("feature_scene", {}))
		var feature_music: Dictionary = _copy_dict(context.get("feature_music", feature_scene.get("feature_music", {})))
		var should_duck := bool(feature_music.get("duck_background_music", false))
		_schedule_surface_music_event("feature_start", normalized_cue, context)
		procedural_music_player.update_feature_music_state({
			"active": true,
			"feature_scene": feature_scene,
			"feature_music": feature_music,
			"cue_id": normalized_cue,
			"duck_background_music": should_duck,
		})
		_set_surface_feature_music_state(true, should_duck)
		return
	var outcome_class := "big_win" if normalized_cue.to_lower().find("jackpot") >= 0 or normalized_cue.to_lower().find("grand") >= 0 else "feature_end" if normalized_cue.to_lower().find("feature_end") >= 0 or normalized_cue.to_lower().find("bonus_end") >= 0 else "small_win"
	_schedule_surface_music_event(outcome_class, normalized_cue, context)


func _slot_runtime_feature_audio_cue(runtime_state: Dictionary) -> String:
	var cue := str(runtime_state.get("slot_feature_audio_cue", ""))
	return cue if not cue.is_empty() else "bonus_start"


func _ensure_wager_confirmation_controller() -> void:
	if wager_confirmation_controller == null:
		wager_confirmation_controller = WagerConfirmationControllerScript.new()


func _sync_wager_confirmation_controller_to_host() -> void:
	if wager_confirmation_controller == null:
		return
	var state := wager_confirmation_controller.pending_state()
	pending_wager_confirm_action_id = str(state.get("action_id", ""))
	pending_wager_confirm_skip_stake_validation = bool(state.get("skip_stake_validation", false))
	pending_wager_confirm_preserve_surface_ui_state = bool(state.get("preserve_surface_ui_state", false))
	pending_wager_confirm_stake = int(state.get("stake", 0))
	pending_wager_confirm_source_game_id = str(state.get("source_game_id", ""))


func _show_wager_confirmation_popup(action_id: String, stake: int, wager_cost: int, skip_stake_validation: bool, preserve_surface_ui_state: bool, source_game_id: String = "") -> void:
	if event_choice_popup_overlay == null or event_choice_popup_choices_list == null:
		_show_message("This bet risks your last cash. Click again to confirm.")
		return
	_ensure_wager_confirmation_controller()
	var action_label := _wager_confirmation_action_label(action_id, source_game_id)
	var view := wager_confirmation_controller.configure_confirmation(action_id, stake, wager_cost, skip_stake_validation, preserve_surface_ui_state, source_game_id, action_label)
	_sync_wager_confirmation_controller_to_host()
	pending_event_choice_popup_event_id = ""
	pending_event_choice_popup_focus_choice_id = ""
	pending_event_choice_popup_snapshot = (view.get("snapshot", {}) as Dictionary).duplicate(true) if typeof(view.get("snapshot", {})) == TYPE_DICTIONARY else {}
	if event_choice_popup_title_label != null:
		event_choice_popup_title_label.text = str(view.get("title", "All-in wager"))
	if event_choice_popup_summary_label != null:
		event_choice_popup_summary_label.text = str(view.get("summary", ""))
	_clear(event_choice_popup_choices_list)
	for card_value in _copy_array(view.get("cards", [])):
		if typeof(card_value) != TYPE_DICTIONARY:
			continue
		var card: Dictionary = card_value
		var callback := Callable(self, "confirm_pending_wager_action") if str(card.get("action", "")) == "confirm" else Callable(self, "cancel_pending_wager_confirmation")
		_add_wager_confirmation_card(str(card.get("label", "")), str(card.get("text", "")), str(card.get("impact", "")), callback, bool(card.get("primary", false)))
	event_choice_popup_overlay.visible = true
	event_choice_popup_overlay.move_to_front()
	_position_event_choice_popup()
	call_deferred("_position_event_choice_popup")


func _add_wager_confirmation_card(label: String, text: String, _impact: String, callback: Callable, primary: bool, badges_value: Variant = []) -> void:
	if event_choice_popup_choices_list == null:
		return
	var border := VisualStyle.YELLOW if primary else VisualStyle.CYAN_2
	var card := _panel_container(VisualStyle.DARK_2, border)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	event_choice_popup_choices_list.add_child(card)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 5)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(stack)
	var heading := _label(label, 16)
	_set_control_font_color(heading, border)
	heading.max_lines_visible = 1
	heading.clip_text = true
	stack.add_child(heading)
	var body := _label(text, 13)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.max_lines_visible = EVENT_CHOICE_TEXT_MAX_LINES
	body.clip_text = true
	stack.add_child(body)
	_add_attribute_badge_row(stack, badges_value, 16)
	var button := _button(label, callback)
	if primary:
		_style_selected_button(button)
	stack.add_child(button)


func _clear_pending_wager_confirmation() -> void:
	_ensure_wager_confirmation_controller()
	wager_confirmation_controller.clear()
	_sync_wager_confirmation_controller_to_host()


func serialized_run_state() -> Dictionary:
	if run_state == null:
		return {}
	return run_state.to_dict()


func debug_soak_snapshot() -> Dictionary:
	var environment_debug: Dictionary = {}
	if environment_canvas != null and environment_canvas.has_method("debug_soak_snapshot"):
		environment_debug = environment_canvas.call("debug_soak_snapshot") as Dictionary
	var game_surface_debug: Dictionary = {}
	if game_surface_canvas != null and game_surface_canvas.has_method("debug_soak_snapshot"):
		game_surface_debug = game_surface_canvas.call("debug_soak_snapshot") as Dictionary
	var music_debug: Dictionary = {}
	if procedural_music_player != null and procedural_music_player.has_method("debug_soak_snapshot"):
		music_debug = procedural_music_player.call("debug_soak_snapshot") as Dictionary
	var sfx_debug: Dictionary = {}
	if environment_sfx_player != null and environment_sfx_player.has_method("debug_soak_snapshot"):
		sfx_debug = environment_sfx_player.call("debug_soak_snapshot") as Dictionary
	var library_debug: Dictionary = {}
	if library != null and library.has_method("debug_soak_snapshot"):
		library_debug = library.call("debug_soak_snapshot") as Dictionary
	return {
		"screen": current_screen,
		"game_module_cache_size": game_module_cache.size(),
		"run_item_icon_texture_cache_size": run_item_icon_texture_cache.size(),
		"travel_target_ids_cache_size": travel_target_ids_cache.size(),
		"travel_choice_cache_size": travel_choice_cache.size(),
		"world_route_cache_size": world_route_cache.size(),
		"world_map_snapshot_cache_size": world_map_snapshot_cache.size(),
		"world_map_button_count": world_map_button_ids.size(),
		"world_map_badge_slot_child_count": world_map_badge_slot.get_child_count() if world_map_badge_slot != null else 0,
		"world_map_badge_slot_visible": world_map_badge_slot.visible if world_map_badge_slot != null else false,
		"world_map_detail_badges_key": world_map_detail_badges_key,
		"event_choice_popup_child_count": event_choice_popup_choices_list.get_child_count() if event_choice_popup_choices_list != null else 0,
		"conclusion_animation_child_count": conclusion_animation_overlay.get_child_count() if conclusion_animation_overlay != null else 0,
		"conclusion_animation_tween_count": conclusion_animation_tweens.size(),
		"inventory_child_count": run_inventory_screen.rendered_item_child_count() if run_inventory_screen != null else 0,
		"journal_child_count": run_journal_list.get_child_count() if run_journal_list != null else 0,
		"environment_canvas": environment_debug,
		"game_surface_canvas": game_surface_debug,
		"procedural_music": music_debug,
		"environment_sfx": sfx_debug,
		"content_library": library_debug,
		"signal_connection_counts": {
			"foundation_main": _debug_signal_connection_count(self),
			"environment_canvas": _debug_signal_connection_count(environment_canvas),
			"game_surface_canvas": _debug_signal_connection_count(game_surface_canvas),
			"procedural_music_player": _debug_signal_connection_count(procedural_music_player),
			"environment_sfx_player": _debug_signal_connection_count(environment_sfx_player),
			"world_map_nodes_layer": _debug_signal_connection_count(world_map_nodes_layer),
		},
	}


func _debug_signal_connection_count(object: Object) -> int:
	if object == null:
		return 0
	var total := 0
	for signal_value in object.get_signal_list():
		if typeof(signal_value) != TYPE_DICTIONARY:
			continue
		var signal_data: Dictionary = signal_value
		var signal_name := StringName(str(signal_data.get("name", "")))
		if String(signal_name).is_empty():
			continue
		total += object.get_signal_connection_list(signal_name).size()
	return total


func current_environment_view_snapshot() -> Dictionary:
	if run_state == null:
		return {}
	return _environment_view_snapshot()


func current_game_view_snapshot() -> Dictionary:
	if run_state == null:
		return {}
	return _game_view_snapshot()


func current_consequence_view_snapshot() -> Dictionary:
	if run_state == null:
		return {}
	return _consequence_view_snapshot()


func current_run_report_snapshot() -> Dictionary:
	if run_state == null:
		return {}
	_render_run_report()
	return run_report_model


func current_action_category_snapshot() -> Dictionary:
	if run_state == null:
		return {}
	return {
		"selected_id": selected_action_category,
		"categories": _action_category_view_list(),
	}


func current_screen_snapshot() -> Dictionary:
	var map_detail_badges: Array = world_map_overlay_controller.detail_badges() if world_map_overlay_controller != null else []
	return {
		"screen": current_screen,
		"selected_category": selected_action_category,
		"has_run": run_state != null,
		"start_menu": current_start_menu_snapshot(),
		"has_game": current_game != null,
		"run_menu_visible": _run_menu_is_visible(),
		"run_menu": current_run_menu_snapshot(),
		"run_journal_visible": _run_journal_popup_is_visible(),
		"talk_dock": current_talk_dock_snapshot(),
		"item_found_popup": current_item_found_popup_snapshot(),
		"coach": current_coach_snapshot(),
		"overlay_state": current_overlay_state_snapshot(),
		"run_report": current_run_report_snapshot() if run_state != null and run_state.is_terminal() else {},
		"travel_transition_active": travel_transition_active,
		"travel_transition_target_id": travel_transition_target_id,
		"travel_transition_target_label": travel_transition_target_label,
		"world_map_overlay_visible": world_map_overlay != null and world_map_overlay.visible,
		"world_map_title_text": world_map_title_label.text if world_map_title_label != null else "",
		"selected_world_map_node_id": selected_world_map_node_id,
		"world_map_detail_text": world_map_detail_label.text if world_map_detail_label != null else "",
		"world_map_detail_popup_visible": world_map_detail_popup != null and world_map_detail_popup.visible,
		"world_map_detail_popup_rect": _rect_to_dict(world_map_detail_popup.get_global_rect()) if world_map_detail_popup != null and world_map_detail_popup.visible else {},
		"world_map_holder_rect": _rect_to_dict(world_map_holder.get_global_rect()) if world_map_holder != null else {},
		"world_map_detail_badge_count": map_detail_badges.size() if world_map_badge_slot != null and world_map_badge_slot.visible else 0,
		"world_map_detail_badges": map_detail_badges,
		"world_map_confirm_enabled": world_map_confirm_button != null and not world_map_confirm_button.disabled,
		"world_map": _world_map_snapshot() if run_state != null else {},
		"conclusion_animation": current_conclusion_animation_snapshot(),
		"accessibility": current_accessibility_snapshot(),
	}


func current_coach_snapshot() -> Dictionary:
	return coach_overlay.current_snapshot() if coach_overlay != null else {"visible": false}


func current_start_menu_snapshot() -> Dictionary:
	var snapshot := {
		"seed_text": seed_input.text if seed_input != null else "",
		"content_groups": _content_group_option_snapshot(),
		"selected_content_groups": _selected_content_groups_for_new_run(),
		"content_group_status": content_group_status_label.text if content_group_status_label != null else "",
		"home_types": _home_type_options(),
		"selected_home_type_id": _normalize_home_type_id(selected_home_type_id),
		"content_group_config_visible": content_group_panel.visible if content_group_panel != null else false,
		"challenges": _challenge_option_snapshot(),
		"selected_challenge_id": selected_challenge_id,
		"challenge_status": challenge_status_label.text if challenge_status_label != null else "",
		"challenge_config_visible": challenge_panel.visible if challenge_panel != null else false,
		"menu_panel_size": main_menu_panel.custom_minimum_size if main_menu_panel != null else Vector2.ZERO,
	}
	if main_menu_panel != null:
		snapshot["menu_panel_rect"] = _rect_to_dict(main_menu_panel.get_global_rect())
	if start_menu_stack != null and start_menu_stack.visible:
		snapshot["start_menu_stack_rect"] = _rect_to_dict(start_menu_stack.get_global_rect())
	if start_menu_intro != null and start_menu_intro.visible:
		snapshot["start_menu_intro_rect"] = _rect_to_dict(start_menu_intro.get_global_rect())
	if start_menu_controls != null and start_menu_controls.visible:
		snapshot["start_menu_controls_rect"] = _rect_to_dict(start_menu_controls.get_global_rect())
	return snapshot


func current_accessibility_snapshot() -> Dictionary:
	if user_settings == null:
		return {
			"high_contrast": false,
			"reduce_motion": false,
			"audio_calm": false,
			"visual_style": VisualStyle.accessibility_snapshot(),
			"haptics_supported": false,
			"haptics_cut_reason": UserSettingsScript.HAPTICS_CUT_REASON,
		}
	var settings_snapshot := user_settings.accessibility_snapshot()
	settings_snapshot["small_screen"] = SmallScreenPolicyScript.snapshot(_small_screen_enabled())
	settings_snapshot["effective_font_scale"] = _accessibility_font_scale()
	settings_snapshot["control_scale"] = _accessibility_control_scale()
	settings_snapshot["showdown_motion_enabled"] = not user_settings.reduce_motion
	settings_snapshot["terminal_motion_enabled"] = not user_settings.reduce_motion
	settings_snapshot["visual_style"] = VisualStyle.accessibility_snapshot()
	if settings_menu != null:
		settings_snapshot["settings_menu"] = settings_menu.current_settings_snapshot()
	return settings_snapshot


func current_event_choice_popup_snapshot() -> Dictionary:
	var snapshot := pending_event_choice_popup_snapshot.duplicate(true)
	snapshot["visible"] = _event_choice_popup_is_visible()
	if not snapshot.has("blocking"):
		snapshot["blocking"] = _event_choice_popup_is_visible()
	if _event_choice_popup_is_visible():
		_position_event_choice_popup()
		snapshot["anchor"] = "screen_center"
		snapshot["interaction_kind"] = str(snapshot.get("interaction_kind", "blocking_decision"))
		snapshot["dismissible"] = bool(snapshot.get("dismissible", false))
		if event_choice_popup_panel != null:
			snapshot["popup_rect"] = _rect_to_dict(event_choice_popup_panel.get_global_rect())
		if event_choice_popup_overlay != null:
			snapshot["screen_rect"] = _rect_to_dict(event_choice_popup_overlay.get_global_rect())
		if environment_canvas != null:
			snapshot["environment_rect"] = _rect_to_dict(environment_canvas.get_global_rect())
	return snapshot


func current_talk_dock_snapshot() -> Dictionary:
	if talk_dock == null:
		return {"visible": false}
	_refresh_talk_dock()
	var snapshot := talk_dock.current_snapshot()
	if snapshot.has("panel_rect") and typeof(snapshot.get("panel_rect")) == TYPE_RECT2:
		snapshot["panel_rect"] = _rect_to_dict(snapshot.get("panel_rect"))
	if snapshot.has("portrait_rect") and typeof(snapshot.get("portrait_rect")) == TYPE_RECT2:
		snapshot["portrait_rect"] = _rect_to_dict(snapshot.get("portrait_rect"))
	if snapshot.has("screen_rect") and typeof(snapshot.get("screen_rect")) == TYPE_RECT2:
		snapshot["screen_rect"] = _rect_to_dict(snapshot.get("screen_rect"))
	if environment_canvas != null:
		snapshot["environment_rect"] = _rect_to_dict(environment_canvas.get_global_rect())
	if game_surface_canvas != null:
		snapshot["game_surface_rect"] = _rect_to_dict(game_surface_canvas.get_global_rect())
	return snapshot


func current_item_found_popup_snapshot() -> Dictionary:
	if item_found_popup == null:
		return {"visible": false}
	var snapshot := item_found_popup.current_snapshot()
	snapshot["replaces_talk_portrait"] = item_found_talk_dock_suspended
	if snapshot.has("panel_rect") and typeof(snapshot.get("panel_rect")) == TYPE_RECT2:
		snapshot["panel_rect"] = _rect_to_dict(snapshot.get("panel_rect"))
	if snapshot.has("screen_rect") and typeof(snapshot.get("screen_rect")) == TYPE_RECT2:
		snapshot["screen_rect"] = _rect_to_dict(snapshot.get("screen_rect"))
	return snapshot


func current_conclusion_animation_snapshot() -> Dictionary:
	var snapshot := conclusion_animation_snapshot.duplicate(true)
	if not snapshot.has("active"):
		snapshot["active"] = false
	snapshot["reduce_motion"] = _reduce_motion_enabled()
	return snapshot


func current_environment_result_feedback_snapshot() -> Dictionary:
	_refresh_environment_result_feedback()
	var snapshot := _environment_result_feedback_view()
	if environment_result_panel != null:
		snapshot["visible"] = environment_result_panel.visible
		if environment_result_panel.visible:
			snapshot["popup_rect"] = _rect_to_dict(environment_result_panel.get_global_rect())
	if visual_panel_container != null:
		snapshot["panel_rect"] = _rect_to_dict(visual_panel_container.get_global_rect())
	var surface_rect := _active_play_surface_global_rect()
	if surface_rect.size != Vector2.ZERO:
		snapshot["surface_rect"] = _rect_to_dict(surface_rect)
		snapshot["environment_rect"] = _rect_to_dict(surface_rect)
	return snapshot


func current_run_inventory_snapshot() -> Dictionary:
	var popup_model := _run_inventory_popup_model(run_inventory_popup_mode, run_inventory_context_container_id)
	var popup_items: Array = popup_model.get("items", []) if typeof(popup_model.get("items", [])) == TYPE_ARRAY else []
	var selected_item := _selected_inventory_popup_item(popup_items)
	var snapshot := {
		"visible": _run_inventory_popup_is_visible(),
		"mode": run_inventory_popup_mode,
		"items": popup_items,
		"grid": true,
		"selected_item_id": selected_run_inventory_item_id,
		"selected_item_source": selected_run_inventory_item_source,
		"selected_item": selected_item,
		"container_id": run_inventory_context_container_id,
		"containers": _copy_array(popup_model.get("containers", [])),
		"selected_key": str(popup_model.get("selected_key", "")),
		"active_container_key": str(popup_model.get("active_container_key", "")),
		"merchant_available": _shopkeeper_available() if run_state != null else false,
		"shop_description": _shop_description() if run_state != null else "",
	}
	if _run_inventory_popup_is_visible():
		_position_run_inventory_popup()
		snapshot["anchor"] = "screen_center"
		snapshot["interaction_kind"] = _run_inventory_interaction_kind(run_inventory_popup_mode)
		if run_inventory_screen != null:
			var layout_rects: Dictionary = run_inventory_screen.layout_rects()
			snapshot["spatial"] = _copy_dict(layout_rects.get("spatial", {}))
			snapshot["popup_rect"] = _rect_to_dict(_rect_from_dict(layout_rects.get("popup_rect", Rect2())))
			snapshot["grid_rect"] = _rect_to_dict(_rect_from_dict(layout_rects.get("grid_rect", Rect2())))
			snapshot["detail_rect"] = _rect_to_dict(_rect_from_dict(layout_rects.get("detail_rect", Rect2())))
			snapshot["screen_rect"] = _rect_to_dict(_rect_from_dict(layout_rects.get("screen_rect", Rect2())))
		if environment_canvas != null:
			snapshot["environment_rect"] = _rect_to_dict(environment_canvas.get_global_rect())
	return snapshot


func current_meta_item_interaction_snapshot() -> Dictionary:
	if meta_item_interaction_screen == null:
		return {"visible": false, "mode": "", "selected_key": "", "item_count": 0}
	var snapshot := meta_item_interaction_screen.layout_snapshot()
	snapshot["mode"] = meta_item_interaction_mode
	snapshot["selected_key"] = selected_meta_item_key
	snapshot["trade_selected_instance_ids"] = meta_trade_selected_instance_ids.duplicate()
	snapshot["bag_reel"] = current_bag_open_reel_snapshot()
	return snapshot


func current_bag_open_reel_snapshot() -> Dictionary:
	return bag_open_reel.layout_snapshot() if bag_open_reel != null else {"visible": false}


func current_run_journal_snapshot() -> Dictionary:
	var entries := _run_journal_entry_view_list()
	var snapshot := {
		"visible": _run_journal_popup_is_visible(),
		"entries": entries,
		"entry_count": entries.size(),
		"summary": _run_journal_summary_text(entries),
		"chronological": true,
	}
	if _run_journal_popup_is_visible():
		_position_run_journal_popup()
		snapshot["anchor"] = "screen_center"
		snapshot["interaction_kind"] = "journal"
		snapshot["read_only"] = true
		if run_journal_panel != null:
			snapshot["popup_rect"] = _rect_to_dict(run_journal_panel.get_global_rect())
		if run_journal_overlay != null:
			snapshot["screen_rect"] = _rect_to_dict(run_journal_overlay.get_global_rect())
	return snapshot


func current_objective_hud_snapshot() -> Dictionary:
	if run_state == null:
		return {}
	if _is_meta_session():
		var meta_hud := _meta_status_hud_model()
		return {
			"mode": "meta",
			"text": str(meta_hud.get("objective_text", "")),
			"status_text": str(meta_hud.get("status_text", "")),
			"save_text": "",
			"fields": _copy_array(meta_hud.get("fields", [])),
			"gold": int(meta_hud.get("gold", 0)),
			"next_home_label": str(meta_hud.get("next_home_label", "")),
			"next_home_price": int(meta_hud.get("next_home_price", 0)),
			"housing_tier": str(meta_hud.get("housing_tier", "")),
			"status_hud": meta_hud,
		}
	var pressure := _run_pressure_view()
	var demo_objective := _demo_objective_status()
	var hud := _run_status_hud_model()
	var guidance: Dictionary = hud.get("objective_guidance", {})
	return {
		"text": _objective_hud_text(),
		"goal": _objective_goal_text(pressure, demo_objective),
		"objective_state": str(guidance.get("state", _objective_presentation_state(pressure, demo_objective))),
		"guidance": guidance,
		"bankroll": _presented_bankroll(),
		"economy": _economy_cue_text(),
		"heat": run_state.security_pressure_label(),
		"alcohol": run_state.alcohol_pressure_summary(),
		"pressure": _pressure_status_text(pressure),
		"next_hint": _next_opportunity_hint(),
		"next_objective": hud.get("next_objective", {}),
		"demo_objective": demo_objective,
		"pit_boss_watch": _pit_boss_watch_status(),
		"run_status": run_state.run_status,
		"status_hud": hud,
	}


func current_run_status_hud_snapshot() -> Dictionary:
	if run_state == null:
		return {}
	return _run_status_hud_model()


func current_spatial_interaction_snapshot() -> Dictionary:
	return {
		"hover_target_id": hover_target_id,
		"focus_target_id": focus_target_id,
		"selected_object_id": selected_object_id,
		"camera_focus_rect": _rect_to_dict(camera_focus_rect),
		"camera_focus_point": _vector2_to_dict(camera_focus_point),
		"current_context_mode": current_context_mode,
		"selected_stake": _current_selected_stake() if run_state != null else selected_stake,
		"selected_action_id": selected_action_id,
		"objects": _interactable_object_view_list(),
		"grand_casino_staffing": run_state.grand_casino_staffing_snapshot(run_state.current_environment) if run_state != null else {},
	}


func hover_interactable_object(object_id: String) -> bool:
	if object_id.is_empty():
		hover_target_id = ""
		return true
	if _interactable_object(object_id).is_empty():
		return false
	hover_target_id = object_id
	return true


func focus_interactable_object(object_id: String) -> bool:
	if object_id.is_empty():
		clear_interaction_focus(true)
		return true
	var object_data := _interactable_object(object_id)
	if object_data.is_empty():
		return false
	return _focus_interactable_object_with_data(object_id, object_data)


func focus_interactable_object_from_view(object_data: Dictionary) -> bool:
	var object_id := str(object_data.get("object_id", ""))
	if object_id.is_empty():
		return false
	return _focus_interactable_object_with_data(object_id, object_data)


func _focus_interactable_object_with_data(object_id: String, object_data: Dictionary) -> bool:
	if object_data.is_empty() or str(object_data.get("object_id", "")) != object_id:
		return false
	selected_object_id = object_id
	focus_target_id = object_id
	current_context_mode = str(object_data.get("object_type", CONTEXT_MODE_ROOM))
	camera_focus_rect = _rect_from_dict(object_data.get("focus_rect", {}))
	camera_focus_point = _vector2_from_dict(object_data.get("focus_point", {}), Vector2(0.5, 0.5))
	if environment_canvas != null:
		environment_canvas.set_selected_object(object_id)
		if run_state != null:
			_refresh_world_header(object_data)
	if actions_list != null:
		_schedule_action_panel_refresh(object_data)
	return true


func activate_interactable_object(object_id: String) -> bool:
	if _guard_player_input_route(false, object_id):
		return false
	if _is_meta_session():
		return _activate_meta_interactable_object(object_id)
	if object_id == "travel:leave":
		var direct_room_exit := _local_parent_home_door_travel_choice(_parent_home_parent_target_id())
		if not direct_room_exit.is_empty():
			if not bool(direct_room_exit.get("enabled", true)):
				_show_message(str(direct_room_exit.get("disabled_reason", "That door is not available right now.")))
				_refresh()
				return false
			focus_interactable_object(object_id)
			_travel_to(str(direct_room_exit.get("id", "")), str(direct_room_exit.get("label", "Lobby")), direct_room_exit)
			return true
		var leave_object := _interactable_object(object_id)
		if leave_object.is_empty():
			if not _travel_choice_view_list().is_empty() and not _run_failed_without_recovery():
				selected_object_id = object_id
				focus_target_id = object_id
				current_context_mode = CONTEXT_MODE_TRAVEL
				return open_world_map()
			return false
		if not bool(leave_object.get("enabled", true)):
			var leave_disabled_reason := str(leave_object.get("disabled_reason", "Not available right now."))
			_show_message(leave_disabled_reason)
			_refresh()
			return false
		focus_interactable_object(object_id)
		return open_world_map()
	if object_id.begins_with("event_response:"):
		return _activate_event_response_action(object_id)
	if object_id.begins_with("cage_atm_action:"):
		return _activate_cage_atm_action(object_id)
	if object_id.begins_with("cage_gift_action:"):
		return _activate_cage_gift_shop_action(object_id)
	if not focus_interactable_object(object_id):
		return false
	var object_data := _interactable_object(object_id)
	if object_data.is_empty():
		return false
	if not bool(object_data.get("interactive", bool(object_data.get("enabled", true)))):
		var fixture_reason := str(object_data.get("disabled_reason", "Nothing to do here right now."))
		if fixture_reason.strip_edges().is_empty():
			fixture_reason = "Nothing to do here right now."
		_show_message(fixture_reason)
		_refresh()
		return false
	if not bool(object_data.get("enabled", true)):
		var disabled_reason := str(object_data.get("disabled_reason", "Not available right now."))
		if disabled_reason.strip_edges().is_empty():
			disabled_reason = "Not available right now."
		_show_message(disabled_reason)
		_refresh()
		return false
	var object_type := str(object_data.get("object_type", CONTEXT_MODE_ROOM))
	var source_id := str(object_data.get("source_id", ""))
	match object_type:
		CONTEXT_MODE_GAME:
			enter_game(source_id, _game_state_key_from_object_id(object_id, source_id))
			return true
		CONTEXT_MODE_EVENT:
			return _activate_event_object(source_id)
		CONTEXT_MODE_ITEM:
			if select_item_offer(source_id):
				return confirm_selected_item_offer()
			return false
		CONTEXT_MODE_SHOPKEEPER:
			return talk_to_shopkeeper()
		CONTEXT_MODE_GAME_HOOK:
			return use_game_environment_hook(str(object_data.get("parent_id", "")), source_id, str(object_data.get("confirm_action_id", "")))
		CONTEXT_MODE_DIALOGUE:
			return start_dialogue(source_id, object_data)
		CONTEXT_MODE_CASINO_FIXTURE:
			return _inspect_casino_fixture(object_data)
		CONTEXT_MODE_HOME_TENURE:
			return confirm_home_tenure_action()
		CONTEXT_MODE_HOME_SLEEP:
			return confirm_home_sleep_action()
		CONTEXT_MODE_HOME_STORAGE:
			return _show_place_container_popup()
		CONTEXT_MODE_HOME_CONTAINER:
			return _show_home_container_popup(source_id)
		CONTEXT_MODE_TRAVEL:
			if source_id == "leave":
				var direct_room_exit := _local_parent_home_door_travel_choice(_parent_home_parent_target_id())
				if not direct_room_exit.is_empty():
					if not bool(direct_room_exit.get("enabled", true)):
						_show_message(str(direct_room_exit.get("disabled_reason", "That door is not available right now.")))
						_refresh()
						return false
					_travel_to(str(direct_room_exit.get("id", "")), str(direct_room_exit.get("label", "Lobby")), direct_room_exit)
					return true
				return open_world_map()
			if select_travel_option(source_id):
				confirm_selected_travel()
				return true
			return false
		CONTEXT_MODE_SERVICE:
			if select_service_hook(source_id):
				return confirm_selected_service_hook()
			return false
		CONTEXT_MODE_LENDER:
			if _lender_is_pawn_counter(source_id):
				select_lender_hook(source_id)
				return open_pawn_counter(source_id)
			if select_lender_hook(source_id):
				return confirm_selected_lender_hook()
			return false
	_show_message("Inspect this first.")
	_refresh()
	return false


func _inspect_casino_fixture(object_data: Dictionary) -> bool:
	var fixture_id := str(object_data.get("source_id", "")).strip_edges()
	if fixture_id == "cage":
		# Compatibility alias for old tutorial/save anchors. It routes to the new
		# room and never constructs the retired modal.
		if run_state != null and str(run_state.current_environment.get("archetype_id", "")) == RunState.GRAND_CASINO_ARCHETYPE_ID:
			if select_travel_option(RunState.GRAND_CASINO_CAGE_ARCHETYPE_ID):
				confirm_selected_travel()
				return true
		return _start_linda_cage_services(object_data)
	if fixture_id == "cage_counter":
		return _start_linda_cage_services(object_data)
	if fixture_id == "cage_atm":
		var atm := CageAtmViewModelScript.build(run_state)
		_show_message(str(atm.get("summary", "The ATM shows the house marker account.")))
		_refresh()
		return true
	if fixture_id == "cage_gift_shop":
		var offers := _cage_gift_shop_offer_view_list()
		var available_count := 0
		for offer_value in offers:
			if typeof(offer_value) == TYPE_DICTIONARY and not bool((offer_value as Dictionary).get("sold", false)):
				available_count += 1
		_show_message("The gift case has %d chip-priced item%s available." % [available_count, "" if available_count == 1 else "s"])
		_refresh()
		return true
	if fixture_id == "host_desk":
		_show_message("The host desk points you toward Linda's barred counter in the Cage.")
		_refresh()
		return true
	var message := str(object_data.get("interaction_message", object_data.get("short_description", "The casino staff acknowledge you."))).strip_edges()
	if message.is_empty():
		message = "The casino staff acknowledge you."
	_show_message(message)
	_refresh()
	return true


func _cage_atm_inline_actions() -> Array:
	return CageAtmViewModelScript.inline_actions(run_state) if run_state != null else []


func _activate_cage_atm_action(object_id: String) -> bool:
	if run_state == null or str(run_state.current_environment.get("archetype_id", "")) != RunState.GRAND_CASINO_CAGE_ARCHETYPE_ID:
		return false
	var parts := object_id.split(":")
	if parts.size() < 3:
		return false
	var result: Dictionary = {}
	if str(parts[1]) == "borrow":
		result = run_state.borrow_from_grand_casino_atm(int(parts[2]))
	elif str(parts[1]) == "repay":
		result = run_state.repay_grand_casino_atm_debt(-1 if str(parts[2]) == "full" else int(parts[2]))
	else:
		return false
	if bool(result.get("ok", false)):
		run_state.advance_environment_turns(1)
		_autosave_foundation_run("Autosaved.")
	_show_message(str(result.get("message", "The ATM declines the transaction.")))
	_refresh_talk_dock()
	_refresh_runtime_environment_views()
	return bool(result.get("ok", false))


func _cage_gift_shop_offer_view_list() -> Array:
	_refresh_run_action_service()
	return run_action_service.cage_gift_shop_offer_view_list() if run_action_service != null else []


func _cage_gift_shop_inline_actions() -> Array:
	var actions: Array = []
	for offer_value in _cage_gift_shop_offer_view_list():
		if typeof(offer_value) != TYPE_DICTIONARY:
			continue
		var offer: Dictionary = offer_value
		actions.append({
			"id": "buy_%s" % str(offer.get("item_id", "")),
			"emit_object_id": "cage_gift_action:buy:%s" % str(offer.get("item_id", "")),
			"label": "%s · %d chips" % [str(offer.get("display_name", "Gift")), int(offer.get("chip_price", 0))],
			"detail": str(offer.get("purpose_summary", "A useful run item.")),
			"enabled": bool(offer.get("enabled", false)),
			"disabled_reason": str(offer.get("disabled_reason", "")),
		})
	return actions


func _activate_cage_gift_shop_action(object_id: String) -> bool:
	if run_state == null or str(run_state.current_environment.get("archetype_id", "")) != RunState.GRAND_CASINO_CAGE_ARCHETYPE_ID:
		return false
	var parts := object_id.split(":", false, 3)
	if parts.size() < 3 or str(parts[1]) != "buy":
		return false
	_refresh_run_action_service()
	var result := run_action_service.buy_cage_gift_shop_offer(str(parts[2]))
	if bool(result.get("ok", false)):
		_autosave_foundation_run("Autosaved.")
	_show_message(str(result.get("message", "The gift case declines the purchase.")))
	_refresh_runtime_environment_views()
	return bool(result.get("ok", false))


func _start_linda_cage_services(object_data: Dictionary) -> bool:
	if run_state == null or str(run_state.current_environment.get("archetype_id", "")) != RunState.GRAND_CASINO_CAGE_ARCHETYPE_ID:
		_show_message("Linda serves the account from the walkable Cage room.")
		_refresh()
		return false
	return start_dialogue("linda_cage_services", {
		"source": "casino_cage_counter",
		"source_object_id": str(object_data.get("object_id", "casino_fixture:cage_counter")),
	})


func _buy_cage_chips(amount: int) -> void:
	if run_state == null:
		return
	if coach_overlay != null and not coach_overlay.input_allowed("cage:buy_chips"):
		_show_message("Follow the highlighted advice first.")
		return
	var result := run_state.buy_grand_casino_chips(amount, run_state.grand_casino_chip_exchange_rate())
	if bool(result.get("ok", false)):
		if coach_overlay != null:
			coach_overlay.notify_action("cage:buy_chips")
		run_state.advance_environment_turns(1)
		_autosave_foundation_run("Autosaved.")
	_show_message(str(result.get("message", "The Cage could not complete that buy-in.")))
	_refresh_talk_dock()
	_refresh_runtime_environment_views()


func _cash_out_cage_chips() -> void:
	if run_state == null:
		return
	if coach_overlay != null and not coach_overlay.input_allowed("cage:cash_out"):
		_show_message("Follow the highlighted advice first.")
		return
	var result := run_state.cash_out_grand_casino_chips(-1, run_state.grand_casino_chip_exchange_rate())
	if bool(result.get("ok", false)):
		if coach_overlay != null:
			coach_overlay.notify_action("cage:cash_out")
		run_state.advance_environment_turns(1)
		_autosave_foundation_run("Autosaved.")
	_show_message(str(result.get("message", "The Cage could not complete that cash-out.")))
	_refresh_talk_dock()
	_refresh_runtime_environment_views()


func _complete_cage_players_card_review() -> void:
	if run_state == null or library == null:
		return
	if coach_overlay != null and not coach_overlay.input_allowed("cage:review"):
		_show_message("Follow the highlighted advice first.")
		return
	var claim_result := run_state.claim_grand_casino_players_card_tier()
	if not bool(claim_result.get("ok", false)):
		_show_message(str(claim_result.get("message", "The Players Card tier is not ready.")))
		_refresh_talk_dock()
		return
	if coach_overlay != null:
		coach_overlay.notify_action("cage:review")
	if not bool(claim_result.get("review_required", false)):
		run_state.advance_environment_turns(1)
		_autosave_foundation_run("Autosaved.")
		_show_message(str(claim_result.get("message", "Linda issues the next Players Card tier.")))
		_refresh_talk_dock()
		_refresh_runtime_environment_views()
		return
	var dialogue_id := "tutorial_linda_gold_review" if run_state.is_tutorial_run() else "linda_gold_review"
	if not start_dialogue(dialogue_id, {"source": "cage_gold_review", "source_object_id": "casino_fixture:cage_counter"}):
		_show_message("Linda's Gold review is unavailable.")


func _use_cage_players_card_comp(comp_id: String) -> void:
	if run_state == null:
		return
	var result := run_state.grand_casino_players_card_comp_result(comp_id)
	if bool(result.get("ok", false)):
		GameModule.apply_result(run_state, result)
		_play_result_drink_audio_cue(result)
		var duration_minutes := maxi(0, int(result.get("duration_minutes", 0)))
		if duration_minutes > 0:
			run_state.advance_game_clock_minutes(duration_minutes)
		else:
			run_state.advance_environment_turns(1)
		last_hook_result = result.duplicate(true)
		_advance_alcohol_absorption()
		_autosave_foundation_run("Autosaved.")
	_show_message(str(result.get("message", "Linda cannot use that comp right now.")))
	_refresh_talk_dock()
	_refresh_runtime_environment_views()


func _start_linda_ambient_dialogue(object_data: Dictionary) -> bool:
	if run_state == null:
		return false
	var status := run_state.demo_objective_status()
	var tier_id := str(status.get("players_card_tier", RunState.GRAND_CASINO_PLAYERS_CARD_TIER_NONE))
	if not bool(status.get("players_card_eligible", false)) or RunState.GRAND_CASINO_PLAYERS_CARD_TIERS.find(tier_id) < RunState.GRAND_CASINO_PLAYERS_CARD_TIERS.find(RunState.GRAND_CASINO_PLAYERS_CARD_TIER_BRONZE):
		_show_message("Linda keeps the account formal until Bronze recognition.")
		_refresh()
		return true
	var ambient_ids := ["linda_main_floor_ambient_1", "linda_main_floor_ambient_2", "linda_main_floor_ambient_3"]
	var encounter_index := maxi(0, int(run_state.narrative_flags.get("grand_casino_linda_ambient_count", 0)))
	var dialogue_id := str(ambient_ids[encounter_index % ambient_ids.size()])
	run_state.narrative_flags["grand_casino_linda_ambient_count"] = encounter_index + 1
	return start_dialogue(dialogue_id, {
		"source": "casino_host_desk",
		"source_object_id": str(object_data.get("object_id", "casino_fixture:host_desk")),
	})


func _activate_event_response_action(action_object_id: String) -> bool:
	var payload := action_object_id.trim_prefix("event_response:")
	var separator := payload.find(":")
	if separator <= 0 or separator >= payload.length() - 1:
		_show_message("Event choice is not available.")
		_refresh()
		return false
	var event_id := payload.substr(0, separator)
	var choice_id := payload.substr(separator + 1)
	if not select_event_choice(event_id, choice_id):
		return false
	confirm_selected_event_choice()
	return true


func _activate_meta_interactable_object(object_id: String) -> bool:
	if _sal_starter_offer_is_pending():
		_resume_sal_starter_offer()
		return true
	if object_id == "travel:leave":
		focus_interactable_object(object_id)
		return open_world_map()
	if not focus_interactable_object(object_id):
		return false
	var object_data := _interactable_object(object_id)
	if object_data.is_empty():
		return false
	if not bool(object_data.get("interactive", bool(object_data.get("enabled", true)))):
		_show_message(str(object_data.get("disabled_reason", "Nothing to do here right now.")))
		_refresh()
		return false
	if not bool(object_data.get("enabled", true)):
		_show_message(str(object_data.get("disabled_reason", "Not available right now.")))
		_refresh()
		return false
	var object_type := str(object_data.get("object_type", ""))
	var source_id := str(object_data.get("source_id", ""))
	match object_type:
		CONTEXT_MODE_HOME_CONTAINER:
			open_meta_container(source_id)
			return true
		CONTEXT_MODE_META_BAG:
			open_meta_bag(int(source_id))
			return true
		CONTEXT_MODE_META_UPGRADE:
			buy_meta_home_upgrade()
			return true
		CONTEXT_MODE_META_TRADE_UP:
			open_meta_trade_up()
			return true
		CONTEXT_MODE_META_PAWN_COUNTER:
			open_meta_sell_counter()
			return true
		CONTEXT_MODE_META_SAL_SHELF:
			open_meta_sal_shelf(int(source_id))
			return true
		CONTEXT_MODE_META_SAL_TALK:
			return _talk_to_sal()
		CONTEXT_MODE_TRAVEL:
			return open_world_map()
	_show_message("Inspect this first.")
	_refresh()
	return false


func _activate_event_object(event_id: String) -> bool:
	var event_option := _eligible_event_option(event_id)
	if event_option.is_empty():
		_show_message("Nothing is happening here right now.")
		_refresh()
		return false
	var choices: Array = event_option.get("choices", [])
	if choices.is_empty():
		_show_message("Choose a response.")
		_refresh()
		return false
	selected_event_id = event_id
	selected_event_choice_id = ""
	selected_event_label = str(event_option.get("display_name", event_id))
	selected_event_choice_label = ""
	selected_action_category = ACTION_CATEGORY_EVENTS
	_set_current_screen(SCREEN_EVENT)
	if not _show_interactable_event_popup(event_id):
		_show_message("Choose a response for %s in the event panel." % selected_event_label)
	_refresh()
	return true


func _show_interactable_event_popup(event_id: String) -> bool:
	var event_option := _eligible_event_option(event_id)
	if event_option.is_empty() or event_choice_popup_overlay == null or event_choice_popup_choices_list == null:
		return false
	pending_event_choice_popup_event_id = event_id
	pending_event_choice_popup_focus_choice_id = ""
	var showdown_sequence := event_id == RunState.GRAND_CASINO_SHOWDOWN_EVENT_ID and run_state != null and bool(run_state.narrative_flags.get("grand_casino_showdown_active", false))
	pending_event_choice_popup_snapshot = {
		"visible": true,
		"blocking": showdown_sequence,
		"popup_type": "interactable_event",
		"interaction_kind": "event",
		"dismissible": not showdown_sequence,
		"event_id": event_id,
		"trigger_context": {},
		"summary": str(event_option.get("summary", "")),
		"choices": _copy_array(event_option.get("choices", [])),
	}
	if event_choice_popup_title_label != null:
		event_choice_popup_title_label.text = str(event_option.get("display_name", event_id))
	if event_choice_popup_summary_label != null:
		event_choice_popup_summary_label.text = str(event_option.get("summary", "Something is available here."))
	_clear(event_choice_popup_choices_list)
	var has_explicit_dismissal := false
	for choice_value in _copy_array(event_option.get("choices", [])):
		if typeof(choice_value) != TYPE_DICTIONARY:
			continue
		var choice: Dictionary = choice_value
		has_explicit_dismissal = has_explicit_dismissal or bool(choice.get("dismissal", false))
		_add_wager_confirmation_card(
			str(choice.get("label", choice.get("id", ""))),
			str(choice.get("text", "")),
			str(choice.get("consequence_summary", "")),
			Callable(self, "resolve_event_choice").bind(event_id, str(choice.get("id", ""))),
			false
		)
	if not has_explicit_dismissal and not showdown_sequence:
		_add_wager_confirmation_card(
			"Leave It",
			"Walk away without changing the run.",
			"No consequence.",
			Callable(self, "_dismiss_interactable_event_popup"),
			false
		)
	event_choice_popup_overlay.visible = true
	event_choice_popup_overlay.move_to_front()
	_position_event_choice_popup()
	call_deferred("_position_event_choice_popup")
	return true


func _dismiss_interactable_event_popup() -> void:
	if str(pending_event_choice_popup_snapshot.get("popup_type", "")) != "interactable_event":
		return
	_hide_event_choice_popup()
	_clear_selected_event_choice()
	_show_message("You leave it alone.")
	_refresh()


func _start_conclusion_animation(result: Dictionary, popup_rect: Rect2) -> void:
	var animation_id := str(result.get("conclusion_animation", "")).strip_edges()
	if animation_id != "bankroll_transfer" or not bool(result.get("ok", false)):
		return
	var deltas: Dictionary = result.get("deltas", {}) if typeof(result.get("deltas", {})) == TYPE_DICTIONARY else {}
	var bankroll_delta := int(result.get("bankroll_delta", deltas.get("bankroll_delta", 0)))
	if bankroll_delta <= 0:
		return
	_finish_conclusion_animation()
	var reduce_motion := _reduce_motion_enabled()
	var bill_count := clampi(5 + (bankroll_delta % 4), 5, 8)
	conclusion_animation_snapshot = {
		"kind": animation_id,
		"active": not reduce_motion,
		"reduce_motion": reduce_motion,
		"pulse": reduce_motion,
		"bill_count": 0 if reduce_motion else bill_count,
		"bankroll_delta": bankroll_delta,
		"duration_msec": 0 if reduce_motion else 900,
	}
	if reduce_motion or conclusion_animation_overlay == null:
		if conclusion_animation_overlay != null:
			conclusion_animation_overlay.visible = false
		return
	_clear(conclusion_animation_overlay)
	conclusion_animation_overlay.visible = true
	conclusion_animation_overlay.move_to_front()
	var overlay_rect := conclusion_animation_overlay.get_global_rect()
	var start := popup_rect.get_center()
	if popup_rect.size == Vector2.ZERO:
		start = overlay_rect.get_center()
	var end := Vector2(96, 24)
	if status_label != null:
		end = status_label.get_global_rect().get_center()
	start -= overlay_rect.position
	end -= overlay_rect.position
	for index in range(bill_count):
		var bill := Label.new()
		bill.text = "$"
		bill.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bill.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		bill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bill.custom_minimum_size = Vector2(18, 18)
		bill.position = start + Vector2(float(index % 3) * 5.0, float(index / 3) * 4.0)
		_set_control_font_color(bill, Color("#69f0ae"))
		conclusion_animation_overlay.add_child(bill)
		var tween := create_tween()
		conclusion_animation_tweens.append(tween)
		var delay := float(index) * 0.045
		var duration := 0.62 + float(index % 3) * 0.06
		tween.tween_property(bill, "position", end + Vector2(float(index % 2) * 3.0, 0.0), duration).set_delay(delay)
		tween.parallel().tween_property(bill, "modulate:a", 0.0, duration * 0.45).set_delay(delay + duration * 0.55)
	var cleanup := create_tween()
	conclusion_animation_tweens.append(cleanup)
	cleanup.tween_interval(0.94)
	cleanup.tween_callback(Callable(self, "_finish_conclusion_animation"))


func _conclusion_animation_source_rect(object_id: String = "") -> Rect2:
	if not object_id.strip_edges().is_empty():
		var normalized_object_rect := _generated_object_interaction_rect(object_id)
		if normalized_object_rect.size.x > 0.0 and normalized_object_rect.size.y > 0.0 and environment_canvas != null:
			var canvas_rect := environment_canvas.get_global_rect()
			return Rect2(
				canvas_rect.position + normalized_object_rect.position * canvas_rect.size,
				normalized_object_rect.size * canvas_rect.size
			)
	if environment_result_panel != null and environment_result_panel.visible:
		return environment_result_panel.get_global_rect()
	return Rect2()


func _finish_conclusion_animation() -> void:
	var active_tweens := conclusion_animation_tweens
	conclusion_animation_tweens = []
	for tween in active_tweens:
		if is_instance_valid(tween) and tween.is_valid():
			tween.kill()
	if conclusion_animation_overlay != null:
		_clear(conclusion_animation_overlay)
		conclusion_animation_overlay.visible = false
	conclusion_animation_snapshot["active"] = false


func clear_interaction_focus(animate_camera_return: bool = false) -> void:
	hover_target_id = ""
	focus_target_id = ""
	selected_object_id = ""
	camera_focus_rect = Rect2()
	camera_focus_point = Vector2(0.5, 0.5)
	current_context_mode = CONTEXT_MODE_ROOM
	if environment_canvas != null:
		if _environment_canvas_snapshot_is_stale():
			_render_environment_canvas_snapshot()
		environment_canvas.set_selected_object("", not animate_camera_return)
		if run_state != null:
			_refresh_world_header()
	if actions_list != null:
		_schedule_action_panel_refresh()


func _on_environment_object_hovered(object_id: String) -> void:
	hover_interactable_object(object_id)


func _on_environment_object_focused(object_id: String) -> void:
	focus_interactable_object(object_id)


func _on_environment_object_activated(object_id: String) -> void:
	activate_interactable_object(object_id)


func select_environment_view_object(index: int = 0) -> void:
	if environment_canvas != null:
		environment_canvas.select_object_at(index)


func _render_foundation_snapshots() -> void:
	var environment_visible := current_screen != SCREEN_GAME or current_game == null
	var game_visible := current_screen == SCREEN_GAME and current_game != null
	if environment_canvas != null and environment_visible:
		_render_environment_canvas_snapshot()
	if game_surface_canvas != null:
		game_surface_canvas.set_game_module(current_game)
		if game_visible:
			game_surface_canvas.render_game_snapshot(_game_view_snapshot())


func _render_environment_canvas_snapshot() -> void:
	if environment_canvas == null:
		return
	environment_canvas.render_environment_snapshot(_environment_view_snapshot())
	rendered_environment_snapshot_signature = _environment_snapshot_signature()


func _environment_canvas_snapshot_is_stale() -> bool:
	if environment_canvas == null or run_state == null:
		return false
	return rendered_environment_snapshot_signature != _environment_snapshot_signature()


func _environment_snapshot_signature() -> String:
	return EnvironmentInteractionViewModelScript.snapshot_signature(run_state)


func _environment_view_snapshot() -> Dictionary:
	if run_state == null:
		return {}
	var recent_result := _recent_result_snapshot()
	var archetype := _current_environment_archetype()
	var world_map_visible := world_map_overlay != null and world_map_overlay.visible
	return EnvironmentInteractionViewModelScript.environment_snapshot(run_state, {
		"recent_result": recent_result,
		"drunk_effect_mode": _drunk_effect_mode(),
		"reduce_motion": _reduce_motion_enabled(),
		"high_contrast": _high_contrast_enabled(),
		"accessibility": current_accessibility_snapshot(),
		"travel_choices": _travel_choice_view_list(),
		"selected_travel_target_id": selected_travel_target_id,
		"selected_travel_label": selected_travel_label,
		"venue_open_status": _environment_open_status(archetype),
		"venue_open_status_text": EnvironmentHours.travel_status_text(archetype, run_state.game_minute_of_day()),
		"world_map_overlay_visible": world_map_visible,
		"world_map": _world_map_snapshot() if world_map_visible else {},
		"event_options": _eligible_event_option_view_list(),
		"selected_event_id": selected_event_id,
		"selected_event_choice_id": selected_event_choice_id,
		"selected_event_label": selected_event_label,
		"selected_event_choice_label": selected_event_choice_label,
		"item_offers": _item_offer_view_list(),
		"inventory_items": _inventory_item_view_list(),
		"shopkeeper_available": _shopkeeper_available(),
		"selected_item_offer_id": selected_item_offer_id,
		"selected_item_offer_label": selected_item_offer_label,
		"selected_item_offer_price": selected_item_offer_price,
		"last_item_result": last_item_result,
		"service_options": _service_hook_view_list(),
		"lender_options": _lender_hook_view_list(),
		"selected_service_hook_id": selected_service_hook_id,
		"selected_service_hook_label": selected_service_hook_label,
		"selected_lender_hook_id": selected_lender_hook_id,
		"selected_lender_hook_label": selected_lender_hook_label,
		"last_hook_result": last_hook_result,
		"interactable_objects": _interactable_object_view_list(),
		"outcome_object_id": _outcome_object_id(recent_result),
		"outcome_message": _outcome_message(recent_result),
	})


func _interactable_object_view_list() -> Array:
	var cache_key := _interactable_object_cache_key()
	if interactable_object_view_cache_valid and interactable_object_view_cache_key == cache_key:
		return interactable_object_view_cache
	interactable_object_view_cache = EnvironmentInteractionControllerScript.interactable_object_view_list(self)
	interactable_object_view_cache_valid = true
	interactable_object_view_cache_key = cache_key
	return interactable_object_view_cache


func _interactable_object_cache_key() -> String:
	if run_state == null:
		return "no-run"
	return "%d|%d|%s|%s|%s|%s|%s|%s|%s|%s" % [
		run_state.get_instance_id(),
		hash(run_state.current_environment),
		current_screen,
		hover_target_id,
		focus_target_id,
		selected_object_id,
		selected_event_id,
		selected_event_choice_id,
		selected_item_offer_id,
		selected_travel_target_id,
	]


func _filter_unique_interactable_objects(objects: Array) -> Array:
	return EnvironmentInteractionViewModelScript.filter_unique_objects(objects)


func _objects_with_closing_time_lock(objects: Array) -> Array:
	return EnvironmentInteractionViewModelScript.objects_with_closing_time_lock(objects, _closing_time_disabled_reason())


func _game_hook_interactable_objects(apply_failure_lock: bool = true) -> Array:
	return EnvironmentInteractionControllerScript.game_hook_interactable_objects(self, apply_failure_lock)


func _home_interactable_objects() -> Array:
	return EnvironmentInteractionControllerScript.home_interactable_objects(self)


func _hook_interactable_objects(object_type: String, options: Array) -> Array:
	return EnvironmentInteractionControllerScript.hook_interactable_objects(self, object_type, options)


func _interactable_object(object_id: String) -> Dictionary:
	return EnvironmentInteractionControllerScript.interactable_object(self, object_id)


func _parent_home_return_interactable_object() -> Dictionary:
	return EnvironmentInteractionControllerScript.parent_home_return_interactable_object(self)


func _travel_leave_interactable_object() -> Dictionary:
	return EnvironmentInteractionControllerScript.travel_leave_interactable_object(self)


func _travel_leave_preview_lines(travel_choices: Array, direct_room_exit: Dictionary) -> Array:
	return EnvironmentInteractionViewModelScript.travel_leave_preview_lines(travel_choices, direct_room_exit)


func _local_parent_home_door_travel_choice(target_id: String) -> Dictionary:
	return EnvironmentInteractionControllerScript.local_parent_home_door_travel_choice(self, target_id)


func _local_parent_home_door_kind(target_id: String) -> String:
	return EnvironmentInteractionControllerScript.local_parent_home_door_kind(self, target_id)


func _current_environment_archetype_id() -> String:
	return EnvironmentInteractionControllerScript.current_environment_archetype_id(self)


func _parent_home_node_id() -> String:
	return EnvironmentInteractionControllerScript.parent_home_node_id(self)


func _parent_home_parent_target_id() -> String:
	return EnvironmentInteractionControllerScript.parent_home_parent_target_id(self)


func _environment_game_runtime_state(game_id: String) -> Dictionary:
	var game := _game_module_for_id(game_id)
	if game == null or run_state == null:
		return {}
	var state := game.environment_runtime_state(run_state, run_state.current_environment)
	return state.duplicate(true) if typeof(state) == TYPE_DICTIONARY else {}


func _environment_game_object_state(game_id: String) -> Dictionary:
	var game := _game_module_for_id(game_id)
	if game == null or run_state == null:
		return {}
	var state := game.environment_object_state(run_state, run_state.current_environment)
	return state.duplicate(true) if typeof(state) == TYPE_DICTIONARY else {}


func _environment_game_fixture_object_states(game_id: String) -> Dictionary:
	var result: Dictionary = {}
	var game := _game_module_for_id(game_id)
	if game == null or run_state == null:
		return result
	if not game.has_method("environment_object_state_for_state_key"):
		return result
	var layout := _current_environment_layout()
	var fixture_counts := _copy_dict(layout.get("game_fixture_counts", {}))
	var fixture_count := maxi(1, int(fixture_counts.get(game_id, 1)))
	for fixture_index in range(fixture_count):
		var state_key := game_id if fixture_index == 0 else "%s:%d" % [game_id, fixture_index + 1]
		var object_id := "game:%s" % state_key
		var state_value: Variant = game.call("environment_object_state_for_state_key", run_state, run_state.current_environment, state_key)
		if typeof(state_value) == TYPE_DICTIONARY:
			result[object_id] = (state_value as Dictionary).duplicate(true)
	return result


func _set_active_game_state_key(game_id: String, state_key: String) -> void:
	if run_state == null:
		return
	var clean_game_id := game_id.strip_edges()
	if clean_game_id.is_empty():
		return
	var clean_state_key := state_key.strip_edges()
	if clean_state_key.is_empty():
		clean_state_key = clean_game_id
	var active_keys := _copy_dict(run_state.current_environment.get("active_game_state_keys", {}))
	active_keys[clean_game_id] = clean_state_key
	run_state.current_environment["active_game_state_keys"] = active_keys


func _game_state_key_from_object_id(object_id: String, game_id: String) -> String:
	if object_id.begins_with("game:"):
		var key := object_id.substr("game:".length()).strip_edges()
		if not key.is_empty():
			return key
	return game_id


func _make_interactable_object(source: Dictionary) -> Dictionary:
	return EnvironmentInteractionViewModelScript.make_interactable_object(source, {
		"hover_target_id": hover_target_id,
		"focus_target_id": focus_target_id,
		"selected_object_id": selected_object_id,
	})


func _interaction_rect_for_object(object_id: String, object_type: String, index: int) -> Rect2:
	return EnvironmentInteractionViewModelScript.interaction_rect_for_object(object_id, object_type, index, _current_environment_layout())


func _generated_object_interaction_rect(object_id: String) -> Rect2:
	var layout := _current_environment_layout()
	var object_rects: Variant = layout.get("object_rects", {})
	return EnvironmentInteractionViewModelScript.rect_from_dict((object_rects as Dictionary).get(object_id, {})) if typeof(object_rects) == TYPE_DICTIONARY and (object_rects as Dictionary).has(object_id) else Rect2()


func _interaction_rect(object_type: String, index: int) -> Rect2:
	return EnvironmentInteractionViewModelScript.interaction_rect_for_object("", object_type, index, _current_environment_layout())


func _authored_interaction_rect(object_type: String, index: int) -> Rect2:
	return EnvironmentInteractionViewModelScript.authored_interaction_rect(object_type, index, _current_environment_layout())


func _layout_spot_for_object_type(object_type: String, index: int) -> Vector2:
	var field_name := EnvironmentInteractionViewModelScript.layout_spot_field_name(object_type)
	var spots: Variant = _current_environment_layout().get(field_name, [])
	return EnvironmentInteractionViewModelScript.layout_spot_to_board_position((spots as Array)[index]) if not field_name.is_empty() and typeof(spots) == TYPE_ARRAY and index >= 0 and index < (spots as Array).size() else Vector2(-1.0, -1.0)


func _layout_spot_field_name(object_type: String) -> String:
	return EnvironmentInteractionViewModelScript.layout_spot_field_name(object_type)


func _layout_spot_to_board_position(value: Variant) -> Vector2:
	return EnvironmentInteractionViewModelScript.layout_spot_to_board_position(value)


func _current_environment_layout() -> Dictionary:
	if run_state == null:
		return {}
	var serialized_layout: Variant = run_state.current_environment.get("layout", {})
	if typeof(serialized_layout) == TYPE_DICTIONARY and not (serialized_layout as Dictionary).is_empty():
		return serialized_layout as Dictionary
	var archetype_id := str(run_state.current_environment.get("archetype_id", ""))
	var archetype := _environment_archetype(archetype_id)
	var archetype_layout: Variant = archetype.get("layout", {})
	if typeof(archetype_layout) != TYPE_DICTIONARY:
		return {}
	return archetype_layout as Dictionary


func _normalized_interaction_rect(object_type: String, index: int) -> Rect2:
	return EnvironmentInteractionViewModelScript.normalized_interaction_rect(object_type, index)


func _rect_to_dict(rect: Rect2) -> Dictionary:
	return EnvironmentInteractionViewModelScript.rect_to_dict(rect)


func _rect_from_dict(value: Variant) -> Rect2:
	return EnvironmentInteractionViewModelScript.rect_from_dict(value)


func _active_play_surface_global_rect() -> Rect2:
	if game_surface_canvas != null and game_surface_canvas.visible:
		return game_surface_canvas.get_global_rect()
	if environment_canvas != null:
		return environment_canvas.get_global_rect()
	return Rect2()


func _vector2_to_dict(value: Vector2) -> Dictionary:
	return EnvironmentInteractionViewModelScript.vector2_to_dict(value)


func _vector2_from_dict(value: Variant, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	return EnvironmentInteractionViewModelScript.vector2_from_dict(value, fallback)


func _game_view_snapshot() -> Dictionary:
	return FoundationActionViewModelScript.game_view_snapshot(self)


func _current_game_surface_ui_state() -> Dictionary:
	return FoundationActionViewModelScript.current_game_surface_ui_state(self)


func _focused_talk_speaker_snapshot() -> Dictionary:
	return FoundationActionViewModelScript.focused_talk_speaker_snapshot(self)


func _current_game_result_snapshot() -> Dictionary:
	return FoundationActionViewModelScript.current_game_result_snapshot(self)


func _current_game_embeds_result_feedback() -> bool:
	return FoundationActionViewModelScript.current_game_embeds_result_feedback(self)


func _store_current_game_surface_ui_state(ui_state: Dictionary, deep_copy: bool = true) -> void:
	game_surface_ui_state = ui_state.duplicate(deep_copy)


func _preserved_game_surface_preference_state(ui_state: Dictionary) -> Dictionary:
	return FoundationActionViewModelScript.preserved_game_surface_preference_state(self, ui_state)


func _surface_renderer_for_game_definition(definition: Dictionary) -> String:
	return FoundationActionViewModelScript.surface_renderer_for_game_definition(self, definition)


func _surface_life_for_renderer(renderer: String) -> String:
	return FoundationActionViewModelScript.surface_life_for_renderer(self, renderer)


func _surface_cast_for_renderer(renderer: String) -> String:
	return FoundationActionViewModelScript.surface_cast_for_renderer(self, renderer)


func _refresh_consequence_labels() -> void:
	var has_recent_consequence := false
	if consequence_panel != null:
		consequence_panel.visible = has_recent_consequence
		consequence_panel.custom_minimum_size = Vector2(0, 0)
	if consequence_heading_label != null:
		consequence_heading_label.visible = has_recent_consequence
	if message_label != null:
		message_label.visible = false
	if consequence_state_label != null:
		consequence_state_label.visible = false
	if consequence_result_label != null:
		consequence_result_label.visible = false
	if consequence_story_label != null:
		consequence_story_label.visible = false
	if consequence_cards_scroll != null:
		consequence_cards_scroll.visible = has_recent_consequence
	if consequence_cards_list != null and consequence_cards_list.get_child_count() > 0:
		_clear(consequence_cards_list)


func _refresh_consequence_cards(snapshot: Dictionary) -> void:
	if consequence_cards_list == null:
		return
	_clear(consequence_cards_list)
	var shown := 0
	for card in snapshot.get("cards", []):
		if typeof(card) == TYPE_DICTIONARY:
			_add_consequence_card(card as Dictionary)
			shown += 1
		if shown >= 3:
			break


func _add_consequence_card(card: Dictionary) -> void:
	var tone := str(card.get("tone", "neutral"))
	var border := VisualStyle.CYAN_2
	match tone:
		"positive":
			border = VisualStyle.TEAL
		"risk":
			border = VisualStyle.PINK
		"cost":
			border = VisualStyle.ORANGE
		"story":
			border = VisualStyle.AMBER
		"next":
			border = VisualStyle.PURPLE_2
	var panel := _panel_container(VisualStyle.DARK_3, border)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 54)
	consequence_cards_list.add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 2)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(stack)
	var title := _label(str(card.get("title", "Outcome")), 12)
	_set_control_font_color(title, border)
	stack.add_child(title)
	var line_count := 0
	for line in card.get("lines", []):
		var text := str(line)
		if not text.strip_edges().is_empty():
			var line_label := _label(text, 10)
			line_label.max_lines_visible = 1
			line_label.clip_text = true
			stack.add_child(line_label)
			line_count += 1
		if line_count >= 2:
			break


func _run_report_outcome_snapshot() -> Dictionary:
	if run_state == null:
		return {}
	_render_run_report()
	return _copy_dict(run_report_model.get("outcome", {}))
func _victory_container_item_choices() -> Array:
	var result: Array = []
	if run_state == null or library == null:
		return result
	var seen := {}
	for inventory_value in run_state.inventory:
		var item_id := _inventory_value_id(inventory_value)
		if item_id.is_empty() or seen.has(item_id):
			continue
		seen[item_id] = true
		var definition := library.item(item_id)
		if definition.is_empty():
			continue
		var effect := _copy_dict(definition.get("effect", {}))
		var capacity := maxi(0, int(definition.get("container_capacity", 0)))
		capacity = maxi(capacity, int(effect.get("container_capacity", 0)))
		if str(definition.get("class", "")) != "container" and capacity <= 0:
			continue
		if capacity <= 0:
			continue
		result.append({
			"id": item_id,
			"display_name": str(definition.get("display_name", _label_from_id(item_id))),
			"capacity": capacity,
			"asset_path": str(definition.get("asset_path", "")),
			"icon_key": str(definition.get("icon_key", item_id)),
		})
	return result


func _consequence_view_snapshot() -> Dictionary:
	if run_state == null:
		return {}
	var recent_result := _recent_result_snapshot()
	var deltas: Dictionary = recent_result.get("deltas", {})
	var recent_message := _player_facing_text(str(recent_result.get("message", "")))
	if recent_message.is_empty() and message_label != null:
		recent_message = _player_facing_text(message_label.text)
	if presented_bankroll_hold_active:
		recent_message = "Result resolving."
	return TerminalConsequenceViewModelScript.consequence_snapshot(run_state, {
		"recent_result": recent_result,
		"recent_bankroll_delta": _visible_recent_bankroll_delta(int(recent_result.get("bankroll_delta", deltas.get("bankroll_delta", 0)))),
		"recent_message": recent_message,
		"suspicion_cues": _suspicion_cue_view_list(),
		"security_cues": _security_cue_view_list(),
		"story_messages": _story_message_view_list(),
		"inventory_items": _inventory_view_list(),
		"debt_items": _debt_view_list(),
		"flag_labels": _flag_view_list(),
		"travel_choices": _travel_choice_view_list(),
		"pressure": _run_pressure_view(),
		"presented_bankroll": _presented_bankroll(),
		"economy": _economy_cue_text(),
		"current_game_active": current_game != null,
		"item_labeler": Callable(self, "_item_id_list_label"),
		"travel_labeler": Callable(self, "_travel_id_list_label"),
	})
func _result_is_visible_consequence(result: Dictionary, recent_message: String = "") -> bool:
	if result.is_empty():
		return false
	var result_type := str(result.get("type", ""))
	if ["game_enter", "game_actions"].has(result_type):
		return false
	var deltas: Dictionary = result.get("deltas", {})
	if int(result.get("bankroll_delta", deltas.get("bankroll_delta", 0))) != 0:
		return true
	if int(result.get("suspicion_delta", deltas.get("suspicion_delta", 0))) != 0:
		return true
	for key in ["alcohol_intake", "drunk_delta", "alcoholic_delta", "baseline_luck_delta"]:
		if int(deltas.get(key, 0)) != 0:
			return true
	if bool(result.get("ended", deltas.get("ended", false))):
		return true
	for key in ["debt_changes", "inventory_add", "inventory_remove", "travel_hooks_add", "story_log", "messages", "item_hooks", "event_hooks"]:
		if not _copy_array(deltas.get(key, [])).is_empty():
			return true
	for key in ["flags_set", "travel_changes"]:
		var value: Variant = deltas.get(key, {})
		if typeof(value) == TYPE_DICTIONARY and not (value as Dictionary).is_empty():
			return true
	if not recent_message.strip_edges().is_empty():
		return true
	return ["game_action", "game_action_summary", "item_effect", "item_sale", "event", "travel", "service_hook", "lender_hook", "game_hook", "story_summary"].has(result_type)


func _refresh_environment_result_feedback() -> void:
	if environment_result_panel == null:
		return
	if _is_failure_screen() or _is_victory_screen():
		environment_result_panel.visible = false
		return
	var view := _environment_result_feedback_view()
	var visible := bool(view.get("visible", false))
	environment_result_panel.visible = visible
	if not visible:
		return
	var bankroll_delta := int(view.get("bankroll_delta", 0))
	var suspicion_delta := int(view.get("suspicion_delta", 0))
	var result: Dictionary = view.get("result", {})
	var accent := _environment_result_feedback_accent(result, bankroll_delta, suspicion_delta)
	environment_result_panel.add_theme_stylebox_override("panel", VisualStyle.pixel_box(Color("#080817", 0.96), accent, 1))
	if environment_result_title_label != null:
		environment_result_title_label.text = str(view.get("title", "Result")).left(28)
		_set_control_font_color(environment_result_title_label, accent)
	if environment_result_body_label != null:
		environment_result_body_label.text = str(view.get("text", "")).left(RESULT_FEEDBACK_MAX_CHARS)
		_set_control_font_color(environment_result_body_label, VisualStyle.SOFT)


func _environment_result_feedback_view() -> Dictionary:
	if run_state == null:
		return {"visible": false}
	if _current_game_embeds_result_feedback():
		return {"visible": false}
	var result := _recent_result_snapshot()
	var deltas: Dictionary = result.get("deltas", {})
	var bankroll_delta := int(result.get("bankroll_delta", deltas.get("bankroll_delta", 0)))
	var suspicion_delta := int(result.get("suspicion_delta", deltas.get("suspicion_delta", 0)))
	var message := _outcome_message(result)
	if message.is_empty() and message_label != null:
		message = _player_facing_text(message_label.text)
	if message.strip_edges().is_empty() and bankroll_delta == 0 and suspicion_delta == 0:
		return {"visible": false}
	return {
		"visible": true,
		"anchor": "environment_panel_top_right",
		"interaction_kind": "informational_result",
		"dismissible": true,
		"title": "Result",
		"text": _environment_result_feedback_text(message, bankroll_delta, suspicion_delta),
		"message": message,
		"bankroll_delta": bankroll_delta,
		"suspicion_delta": suspicion_delta,
		"object_id": _outcome_object_id(result),
		"music_outcome_schedule": _copy_dict(result.get("music_outcome_schedule", last_music_outcome_schedule)),
		"result": result.duplicate(true),
	}


func _environment_result_feedback_text(message: String, bankroll_delta: int, suspicion_delta: int) -> String:
	var base := _player_facing_text(message).strip_edges()
	if base.is_empty():
		base = "Outcome recorded."
	var delta_parts: Array[String] = []
	if bankroll_delta != 0:
		delta_parts.append("$%+d" % bankroll_delta)
	if suspicion_delta != 0:
		delta_parts.append("Heat %+d" % suspicion_delta)
	if delta_parts.is_empty():
		return base.left(RESULT_FEEDBACK_MAX_CHARS)
	var suffix := "  %s" % " / ".join(delta_parts)
	var base_limit: int = maxi(12, RESULT_FEEDBACK_MAX_CHARS - suffix.length())
	return ("%s%s" % [base.left(base_limit), suffix]).left(RESULT_FEEDBACK_MAX_CHARS)


func _environment_result_feedback_accent(result: Dictionary, bankroll_delta: int, suspicion_delta: int) -> Color:
	var tone := _outcome_card_tone(result, bankroll_delta, suspicion_delta)
	match tone:
		"risk":
			return VisualStyle.PINK_2
		"cost":
			return VisualStyle.ORANGE
		"positive":
			return VisualStyle.TEAL
		_:
			return VisualStyle.CYAN_2


func _outcome_card_title(result: Dictionary) -> String:
	if result.is_empty():
		return "Ready"
	var type := str(result.get("type", ""))
	var action_kind := str(result.get("action_kind", ""))
	match type:
		"game_action", "game_action_summary":
			return "Risky play resolved" if action_kind == "cheat" else "Play resolved"
		"item_effect":
			return "Item gained"
		"item_sale":
			return "Item sold"
		"event":
			return "Event resolved"
		"travel":
			return "Travel complete"
		"service_hook":
			return "Service resolved"
		"lender_hook":
			return "Debt changed"
		"game_hook":
			return "Cashout resolved"
		_:
			return "Outcome"


func _outcome_card_tone(_result: Dictionary, bankroll_delta: int, suspicion_delta: int) -> String:
	if suspicion_delta > 0:
		return "risk"
	if bankroll_delta < 0:
		return "cost"
	if bankroll_delta > 0:
		return "positive"
	return "neutral"


func _should_show_pressure_card(pressure: Dictionary) -> bool:
	return TerminalConsequenceViewModelScript.should_show_pressure_card(pressure)


func _pressure_card_tone(pressure: Dictionary) -> String:
	return TerminalConsequenceViewModelScript.pressure_card_tone(pressure)


func _pressure_card_lines(pressure: Dictionary) -> Array:
	return TerminalConsequenceViewModelScript.pressure_card_lines(pressure)


func _risk_card_lines(suspicion_delta: int, suspicion_cues: Variant, security_cues: Variant) -> Array:
	return TerminalConsequenceViewModelScript.risk_card_lines(run_state, suspicion_delta, _copy_array(suspicion_cues), _copy_array(security_cues))


func _alcohol_card_lines(alcohol_intake: int, drunk_delta: int, alcoholic_delta: int, baseline_luck_delta: int) -> Array:
	return TerminalConsequenceViewModelScript.alcohol_card_lines(run_state, alcohol_intake, drunk_delta, alcoholic_delta, baseline_luck_delta)


func _debt_card_lines(debt_changes: Array, debt_items: Variant) -> Array:
	return TerminalConsequenceViewModelScript.debt_card_lines(debt_changes, _copy_array(debt_items))


func _inventory_card_lines(inventory_add: Array, inventory_remove: Array, inventory_items: Variant) -> Array:
	return TerminalConsequenceViewModelScript.inventory_card_lines(inventory_add, inventory_remove, _copy_array(inventory_items), Callable(self, "_item_id_list_label"))


func _travel_card_lines(travel_hooks: Array, travel_changes: Dictionary, travel_choices: Variant) -> Array:
	return TerminalConsequenceViewModelScript.travel_card_lines(travel_hooks, travel_changes, _copy_array(travel_choices), Callable(self, "_travel_id_list_label"))


func _story_card_lines(recent_message: String, story_messages: Array) -> Array:
	return TerminalConsequenceViewModelScript.story_card_lines(recent_message, story_messages)


func _next_action_lines(travel_choices: Variant) -> Array:
	return TerminalConsequenceViewModelScript.next_action_lines(current_game != null, _copy_array(travel_choices))


func _item_id_list_label(items: Array) -> String:
	var labels: Array = []
	for item in items:
		var item_id := str(item)
		var item_definition := library.item(item_id) if library != null else {}
		labels.append(str(item_definition.get("display_name", _label_from_id(item_id))) if not item_definition.is_empty() else _label_from_id(item_id))
	return ", ".join(labels)


func _travel_id_list_label(items: Array) -> String:
	var labels: Array = []
	for item in items:
		var target_id := str(item)
		if target_id.is_empty():
			continue
		var route := library.route(target_id) if library != null else {}
		var archetype := _environment_archetype(target_id)
		var label := str(route.get("label", archetype.get("display_name", "")))
		if label.is_empty():
			label = _travel_label_from_archetype(archetype, target_id)
		labels.append(label)
	return ", ".join(labels)


func _recent_result_snapshot() -> Dictionary:
	if not last_hook_result.is_empty():
		return last_hook_result.duplicate(true)
	if not last_item_result.is_empty():
		return last_item_result.duplicate(true)
	if not last_game_result.is_empty():
		return last_game_result.duplicate(true)
	if current_game == null and not last_environment_runtime_result.is_empty():
		return last_environment_runtime_result.duplicate(true)
	return _result_from_story_log(run_state.story_log)


func _result_from_story_log(entries: Array) -> Dictionary:
	for index in range(entries.size() - 1, -1, -1):
		var entry: Variant = entries[index]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var story_entry := entry as Dictionary
		var message := str(story_entry.get("message", ""))
		if message.is_empty():
			message = _story_entry_label(story_entry)
		return GameModule.build_action_result({
			"ok": true,
			"type": str(story_entry.get("type", "story_summary")),
			"source_id": str(story_entry.get("id", story_entry.get("game_id", story_entry.get("item_id", "")))),
			"action_id": str(story_entry.get("action_id", "")),
			"bankroll_delta": int(story_entry.get("bankroll_delta", 0)),
			"suspicion_delta": int(story_entry.get("suspicion_delta", 0)),
			"deltas": {
				"bankroll_delta": int(story_entry.get("bankroll_delta", 0)),
				"suspicion_delta": int(story_entry.get("suspicion_delta", 0)),
				"messages": [message],
				"ended": bool(story_entry.get("ended", false)),
			},
			"message": message,
			"environment_id": str(story_entry.get("environment_id", "")),
		})
	return {}


func _suspicion_cue_view_list() -> Array:
	var cues: Array = run_state.suspicion.get("cues", [])
	var result: Array = []
	for index in range(cues.size() - 1, -1, -1):
		var cue: Variant = cues[index]
		if typeof(cue) != TYPE_DICTIONARY:
			continue
		var cue_data := cue as Dictionary
		var amount := int(cue_data.get("amount", 0))
		var label := _label_from_id(str(cue_data.get("id", "cue")).replace(":", " "))
		if amount > 0:
			result.append("%s notices you (%+d heat)" % [label.left(36), amount])
		elif amount < 0:
			result.append("%s eases pressure (%+d heat)" % [label.left(36), amount])
		else:
			result.append(label.left(44))
		if result.size() >= 2:
			break
	return result


func _security_cue_view_list() -> Array:
	var result: Array = []
	for cue in _copy_array(run_state.current_environment.get("suspicion_cues", [])):
		var label := str(cue)
		if not label.is_empty():
			result.append(label)
	return result


func _inventory_view_list() -> Array:
	var result: Array = []
	for item_id in _string_array(run_state.inventory):
		var item_definition := library.item(item_id) if library != null else {}
		if item_definition.is_empty():
			result.append(_label_from_id(item_id))
			continue
		var label := str(item_definition.get("display_name", _label_from_id(item_id)))
		result.append(label)
	return result


func _debt_view_list() -> Array:
	var result: Array = []
	for debt_entry in _copy_array(run_state.debt):
		if typeof(debt_entry) != TYPE_DICTIONARY:
			continue
		var debt_data := debt_entry as Dictionary
		result.append(_debt_entry_view_line(debt_data))
	return result


func _debt_entry_view_line(debt_data: Dictionary) -> String:
	var label := _label_from_id(str(debt_data.get("lender_id", debt_data.get("id", "debt"))))
	var balance := int(debt_data.get("balance", 0))
	var status := _label_from_id(str(debt_data.get("status", "active")))
	var schedule := _debt_schedule_text(debt_data)
	var kind := str(debt_data.get("debt_kind", "cash"))
	if kind == "favor":
		return "%s wants %d favor%s, %s (%s)" % [label, balance, "" if balance == 1 else "s", schedule, status]
	if kind == "pawn":
		var item_name := str(debt_data.get("collateral_item_name", debt_data.get("collateral_item_id", "collateral")))
		var principal := maxi(0, int(debt_data.get("principal", balance)))
		return "%s holds %s; borrowed %d, buy-back %d, %s (%s)" % [label, item_name, principal, balance, schedule, status]
	return "%s balance %d, %s (%s)" % [label, balance, schedule, status]


func _debt_schedule_text(debt_data: Dictionary) -> String:
	var status := str(debt_data.get("status", "active"))
	if status == "favor_due":
		return "favor due now"
	if status == "overdue":
		var pressure := int(debt_data.get("next_pressure_turns", 0))
		return "next pressure in %d turn%s" % [pressure, "" if pressure == 1 else "s"] if pressure > 0 else "overdue now"
	var turns := int(debt_data.get("turns_remaining", debt_data.get("deadline_turns", 0)))
	if turns <= 0:
		return "due now"
	return "due in %d turn%s" % [turns, "" if turns == 1 else "s"]


func _flag_view_list() -> Array:
	var result: Array = []
	for key in run_state.narrative_flags.keys():
		if _flag_value_is_visible(run_state.narrative_flags[key]):
			result.append(_label_from_id(str(key)))
	result.sort()
	return result


func _flag_value_is_visible(value: Variant) -> bool:
	match typeof(value):
		TYPE_BOOL:
			return value
		TYPE_INT:
			return int(value) != 0
		TYPE_FLOAT:
			return not is_zero_approx(float(value))
		TYPE_STRING:
			return not str(value).strip_edges().is_empty()
		TYPE_ARRAY:
			return not (value as Array).is_empty()
		TYPE_DICTIONARY:
			return not (value as Dictionary).is_empty()
		_:
			return value != null


func _story_message_view_list() -> Array:
	var result: Array = []
	for index in range(run_state.story_log.size() - 1, -1, -1):
		var entry: Variant = run_state.story_log[index]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		result.append(_story_entry_label(entry as Dictionary))
		if result.size() >= 3:
			break
	return result


func _story_entry_label(entry: Dictionary) -> String:
	var message := _player_facing_text(str(entry.get("message", "")))
	if not message.is_empty():
		return message
	var type := str(entry.get("type", "story"))
	match type:
		"game_action":
			return "%s %+d" % [_game_display_name(str(entry.get("game_id", ""))), int(entry.get("bankroll_delta", 0))]
		"item_purchase":
			return "Bought %s" % str(entry.get("item_name", entry.get("item_id", "item")))
		"item_sale":
			return "Sold %s" % str(entry.get("item_name", entry.get("item_id", "item")))
		"travel":
			return "Traveled to %s" % str(entry.get("to_environment_name", entry.get("to_archetype_id", "destination")))
		"event":
			return "Event: %s" % str(entry.get("event_id", entry.get("id", "event")))
		_:
			return _label_from_id(type)


func _debt_summary(items: Array) -> String:
	if items.is_empty():
		return "none"
	if items.size() == 1:
		return str(items[0])
	return "%d active debts" % items.size()


func _inventory_summary(items: Array) -> String:
	if items.is_empty():
		return "empty"
	if items.size() <= 3:
		return ", ".join(items)
	return "%s +%d" % [", ".join(items.slice(0, 3)), items.size() - 3]


func _flag_summary(labels: Array) -> String:
	if labels.is_empty():
		return "none"
	if labels.size() <= 3:
		return ", ".join(labels)
	return "%s +%d" % [", ".join(labels.slice(0, 3)), labels.size() - 3]


func _travel_summary(choices: Array) -> String:
	if choices.is_empty():
		return "none"
	var labels: Array = []
	for choice in choices:
		if typeof(choice) == TYPE_DICTIONARY:
			labels.append(str((choice as Dictionary).get("label", (choice as Dictionary).get("id", ""))))
	if labels.is_empty():
		return "%d available" % choices.size()
	if labels.size() <= 2:
		return ", ".join(labels)
	return "%s +%d" % [", ".join(labels.slice(0, 2)), labels.size() - 2]


func _default_stake() -> int:
	var range := _stake_range()
	return int(range.get("default", 1))


func _show_message(text: String) -> void:
	var notice_lines: Array = []
	if run_state != null and run_state.has_method("grand_casino_atm_pending_interest_notifications"):
		var pending_notices: Array = run_state.grand_casino_atm_pending_interest_notifications()
		if not pending_notices.is_empty() and not _event_choice_popup_is_visible():
			for notice_value in run_state.consume_grand_casino_atm_interest_notifications():
				if typeof(notice_value) == TYPE_DICTIONARY:
					notice_lines.append(str((notice_value as Dictionary).get("message", "")))
	var combined_text := text
	if not notice_lines.is_empty():
		combined_text = "%s %s" % [" ".join(notice_lines), text]
	var display_text := _player_facing_text(combined_text.strip_edges())
	if message_label != null:
		message_label.text = display_text
	if start_status_label != null and run_state == null:
		start_status_label.text = display_text


func _player_facing_text(text: String) -> String:
	var result := text
	result = result.replace("Suspicion", "Heat")
	result = result.replace("suspicion", "heat")
	return result


func _style_hud_for_recent_consequence() -> void:
	if status_label == null:
		return
	var result := _recent_result_snapshot()
	var deltas: Dictionary = result.get("deltas", {})
	var bankroll_delta := int(result.get("bankroll_delta", deltas.get("bankroll_delta", 0)))
	var suspicion_delta := int(result.get("suspicion_delta", deltas.get("suspicion_delta", 0)))
	var color := VisualStyle.SOFT
	var pressure_state := str(_run_pressure_view().get("state", ""))
	if pressure_state == "victory":
		color = VisualStyle.TEAL
	elif pressure_state == "failed":
		color = VisualStyle.PINK_2
	elif pressure_state == "recovery":
		color = VisualStyle.ORANGE
	elif suspicion_delta > 0:
		color = VisualStyle.PINK_2
	elif bankroll_delta < 0:
		color = VisualStyle.ORANGE
	elif bankroll_delta > 0:
		color = VisualStyle.TEAL
	_set_control_font_color(status_label, color)


func _on_start_pressed() -> void:
	var seed_text := seed_input.text.strip_edges()
	if seed_text.is_empty():
		seed_text = _generate_menu_seed_text()
		seed_input.text = seed_text
	if selected_challenge_id.is_empty() and _fresh_profile_needs_tutorial():
		start_tutorial_run()
		return
	start_foundation_run(seed_text, _new_run_challenge_for_seed(seed_text))


func start_tutorial_run() -> void:
	var config := TutorialFlowScript.challenge_config(library)
	if config.is_empty():
		_show_message("The First Night lesson is unavailable.")
		return
	selected_challenge_id = ""
	start_foundation_run(str(config.get("seed_text", "FIRST-NIGHT-ACE-17")), config)


func _fresh_profile_needs_tutorial() -> bool:
	if profile_inventory == null:
		_initialize_profile_inventory()
	if meta_collection_service == null:
		_initialize_meta_collection()
	return TutorialFlowScript.should_auto_start(profile_inventory, meta_collection_service.snapshot())


func request_skip_tutorial() -> void:
	if run_state == null or not run_state.is_tutorial_run() or tutorial_skip_dialog == null:
		return
	tutorial_skip_dialog.popup_centered(Vector2i(520, 190))


func _confirm_skip_tutorial() -> void:
	if run_state == null or not run_state.is_tutorial_run():
		return
	if profile_inventory == null:
		_initialize_profile_inventory()
	profile_inventory.tutorial_completed = true
	var profile_save_error := profile_inventory.save()
	if profile_save_error != OK:
		profile_inventory.tutorial_completed = false
		_show_message("Could not save lesson completion.")
		return
	if save_service != null:
		var clear_error := save_service.clear_run(autosave_slot_id)
		if clear_error != OK:
			_show_message("Could not clear the tutorial Resume Slot.")
			return
	if coach_overlay != null:
		coach_overlay.suspend()
	run_state = null
	return_to_main_menu()


func start_generated_foundation_run() -> void:
	var seed_text := _generate_menu_seed_text()
	if seed_input != null:
		seed_input.text = seed_text
	start_foundation_run(seed_text, _new_run_challenge_for_seed(seed_text))


func start_meta_quick_run() -> void:
	var seed_text := _generate_menu_seed_text()
	if seed_input != null:
		seed_input.text = seed_text
	start_foundation_run(seed_text, {}, false)


func _on_run_report_new_run_requested() -> void:
	if _terminal_reward_selection_pending():
		_show_message("Choose and store each earned reward before leaving the run report.")
		return
	if run_state != null and run_state.is_tutorial_run() and run_state.run_status == RunState.RUN_STATUS_FAILED:
		start_tutorial_run()
		return
	start_generated_foundation_run()


func _on_run_report_home_requested() -> void:
	if _terminal_reward_selection_pending():
		_show_message("Choose and store each earned reward before leaving the run report.")
		return
	if run_state != null and run_state.is_tutorial_run() and run_state.run_status == RunState.RUN_STATUS_FAILED:
		if not _complete_tutorial_profile():
			return
		start_generated_foundation_run()
		return
	return_to_main_menu()
	open_collection_browser()


func _complete_tutorial_profile() -> bool:
	if profile_inventory == null:
		_initialize_profile_inventory()
	if profile_inventory.tutorial_completed:
		return true
	profile_inventory.tutorial_completed = true
	var error := profile_inventory.save()
	if error == OK:
		return true
	profile_inventory.tutorial_completed = false
	_show_message("Could not save lesson completion.")
	return false


func _on_run_report_copy_seed_requested(seed: String) -> void:
	if seed.strip_edges().is_empty() or seed == "Hidden daily challenge":
		_show_message("This run's seed is hidden.")
		return
	DisplayServer.clipboard_set(seed)
	_show_message("Seed copied.")


func _challenge_with_meta_home_for_run(seed_text: String, config: Dictionary) -> Dictionary:
	var normalized := RunState.normalize_challenge(seed_text, config)
	var mode := str(normalized.get("mode", "standard")).strip_edges().to_lower()
	if mode != "standard" or not str(normalized.get("completion_flag", "")).strip_edges().is_empty():
		return normalized
	if meta_collection_service == null:
		_initialize_meta_collection()
	var modifiers := _copy_dict(normalized.get("modifiers", {}))
	var meta_modifiers: Dictionary = meta_collection_service.normal_run_start_modifiers()
	for key in meta_modifiers.keys():
		modifiers[str(key)] = meta_modifiers[key]
	normalized["modifiers"] = modifiers
	return normalized


func _apply_meta_collection_loadout_to_run() -> void:
	if run_state == null or not run_state.meta_collection_enabled_for_run():
		return
	var modifiers := run_state.challenge_modifiers()
	for item_value in _copy_array(modifiers.get("meta_collection_loadout", [])):
		if typeof(item_value) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = item_value
		var item_id := str(item.get("id", "")).strip_edges()
		if item_id.is_empty():
			continue
		if not run_state.inventory.has(item):
			run_state.inventory.append(item.duplicate(true))


func return_to_main_menu() -> void:
	if _is_meta_session():
		_exit_meta_session()
		return
	if _all_in_result_terminal_check_is_pending():
		_evaluate_run_terminal_state(true)
	if run_state != null and not dev_game_test_mode:
		_autosave_foundation_run("Autosaved before main menu.", true)
	pending_all_in_result_terminal_check = false
	_finish_conclusion_animation()
	_reset_game_surface_runtime_state()
	current_game = null
	game_surface_ui_state = {}
	last_environment_runtime_result = {}
	run_item_icon_texture_cache.clear()
	run_state = null
	meta_session_active = false
	meta_session_location_id = ""
	meta_last_panel_message = ""
	dev_game_test_mode = false
	_refresh_run_action_service()
	close_content_group_config()
	close_challenge_selection()
	_hide_run_menu()
	_hide_event_choice_popup()
	_hide_run_inventory_popup()
	_hide_run_journal_popup()
	_hide_world_map_overlay()
	_hide_travel_transition()
	if item_found_popup != null:
		item_found_popup.clear_all()
	_clear_selected_game_action()
	_clear_selected_stake()
	clear_interaction_focus()
	_set_current_screen(SCREEN_START)
	_stop_procedural_music()
	if run_screen != null:
		run_screen.visible = false
	if start_screen != null:
		start_screen.visible = true
	if start_menu_controls != null:
		start_menu_controls.visible = true
	if start_menu_intro != null:
		start_menu_intro.visible = true
	if inventory_page != null:
		inventory_page.visible = false
	if game_test_menu != null:
		game_test_menu.visible = false
	close_settings_menu()
	_refresh_start_screen()


func exit_game() -> void:
	_reset_game_surface_runtime_state()
	if run_state != null:
		_autosave_foundation_run("Autosaved before exit.", true)
	get_tree().quit()


func open_settings_menu() -> void:
	if settings_menu == null or settings_overlay == null:
		return
	close_content_group_config()
	close_challenge_selection()
	if start_menu_controls != null:
		start_menu_controls.visible = false
	if inventory_page != null:
		inventory_page.visible = false
	if game_test_menu != null:
		game_test_menu.visible = false
	if start_menu_intro != null:
		start_menu_intro.visible = true
	settings_overlay.visible = true
	settings_overlay.move_to_front()
	settings_menu.open()


func close_settings_menu() -> void:
	if settings_menu != null:
		settings_menu.visible = false
	if settings_overlay != null:
		settings_overlay.visible = false
	if current_screen == SCREEN_START:
		if start_menu_intro != null:
			start_menu_intro.visible = true
		if start_menu_controls != null:
			start_menu_controls.visible = true
		_refresh_start_screen()
	else:
		_refresh_run_menu()


func _on_settings_applied() -> void:
	_apply_accessibility_settings()
	if coach_overlay != null and user_settings != null:
		coach_overlay.set_tips_enabled(user_settings.coach_tips_enabled)
	if procedural_music_player != null and user_settings != null:
		procedural_music_player.audio_calm = bool(user_settings.audio_calm)
		_update_procedural_music()
	if run_state != null:
		_render_foundation_snapshots()
		_refresh_world_header()


func _on_reset_coach_tips_requested() -> void:
	if profile_inventory == null:
		return
	profile_inventory.reset_tips()
	profile_inventory.save()
	if coach_overlay != null:
		coach_overlay.reset_seen()


func _on_coach_lesson_seen(lesson_id: String) -> void:
	if library != null and TutorialFlowScript.lesson_is_tutorial(lesson_id, library.tutorial_lessons):
		return
	if profile_inventory == null or not profile_inventory.mark_tip_seen(lesson_id):
		return
	profile_inventory.save()


func _drunk_effect_mode() -> String:
	if run_state != null and run_state.drunk_distortion_suppressed():
		return "classic"
	if user_settings == null:
		return "distortion"
	if user_settings.reduce_motion:
		return "classic"
	return str(user_settings.drunk_effect_mode)


func _reduce_motion_enabled() -> bool:
	return user_settings != null and user_settings.reduce_motion


func _high_contrast_enabled() -> bool:
	return user_settings != null and user_settings.high_contrast


func open_inventory_page() -> void:
	if inventory_page == null:
		return
	close_content_group_config()
	close_challenge_selection()
	if settings_menu != null:
		settings_menu.visible = false
	if start_menu_intro != null:
		start_menu_intro.visible = true
	if start_menu_controls != null:
		start_menu_controls.visible = false
	if game_test_menu != null:
		game_test_menu.visible = false
	_refresh_profile_inventory_page()
	inventory_page.visible = true


func open_collection_browser() -> void:
	open_meta_home()


func open_meta_home() -> void:
	_enter_meta_location(META_LOCATION_HOME)


func _enter_meta_location(location_id: String) -> void:
	var clean_location := location_id.strip_edges()
	if clean_location == META_LOCATION_START_RUN:
		start_meta_quick_run()
		return
	var pawn_location := _meta_pawn_location_id()
	if clean_location != pawn_location:
		clean_location = META_LOCATION_HOME
	if library == null:
		_initialize_foundation()
	if meta_collection_service == null:
		_initialize_meta_collection()
	_hide_event_choice_popup()
	_hide_run_inventory_popup()
	_hide_run_journal_popup()
	_hide_world_map_overlay()
	_hide_travel_transition()
	_reset_game_surface_runtime_state()
	if run_state == null or not _is_meta_session():
		run_state = RunState.new()
		run_state.start_new("META-HOME")
		run_state.begin_act(1)
		run_state.narrative_flags["_meta_home_session"] = true
	meta_session_active = true
	meta_session_location_id = clean_location
	run_state.narrative_flags["_meta_home_session"] = true
	run_state.run_status = RunState.RUN_STATUS_ACTIVE
	current_game = null
	last_game_result = {}
	last_item_result = {}
	last_hook_result = {}
	game_surface_ui_state = {}
	selected_action_category = ACTION_CATEGORY_TRAVEL if clean_location == pawn_location else ACTION_CATEGORY_ITEMS
	_set_current_screen(SCREEN_ENVIRONMENT)
	close_content_group_config()
	close_challenge_selection()
	close_settings_menu()
	if start_menu_controls != null:
		start_menu_controls.visible = false
	if start_menu_intro != null:
		start_menu_intro.visible = false
	if inventory_page != null:
		inventory_page.visible = false
	if game_test_menu != null:
		game_test_menu.visible = false
	_apply_meta_environment(clean_location)
	if coach_overlay != null:
		coach_overlay.suspend()
	_configure_coach_for_run()
	_clear_selected_game_action()
	_clear_selected_stake()
	_clear_selected_travel()
	_clear_selected_event_choice()
	_clear_selected_item_offer()
	_clear_selected_service_hook()
	_clear_selected_lender_hook()
	clear_interaction_focus()
	_show_message("Home is ready." if clean_location == META_LOCATION_HOME else "Sal's Pawn Shop is open.")
	_refresh()
	if clean_location == pawn_location and _sal_starter_offer_is_pending():
		_resume_sal_starter_offer()


func _exit_meta_session() -> void:
	_hide_run_menu()
	_hide_event_choice_popup()
	close_meta_item_interaction()
	_hide_run_inventory_popup()
	_hide_run_journal_popup()
	_hide_world_map_overlay()
	_hide_travel_transition()
	_finish_conclusion_animation()
	_reset_game_surface_runtime_state()
	current_game = null
	run_state = null
	meta_session_active = false
	meta_session_location_id = ""
	meta_last_panel_message = ""
	_set_current_screen(SCREEN_START)
	if run_screen != null:
		run_screen.visible = false
	if start_screen != null:
		start_screen.visible = true
	if start_menu_controls != null:
		start_menu_controls.visible = true
	if start_menu_intro != null:
		start_menu_intro.visible = true
	if inventory_page != null:
		inventory_page.visible = false
	if game_test_menu != null:
		game_test_menu.visible = false
	_stop_procedural_music()
	_refresh_start_screen()


func _is_meta_session() -> bool:
	return meta_session_active and run_state != null and bool(run_state.narrative_flags.get("_meta_home_session", false))


func _meta_pawn_location_id() -> String:
	_ensure_meta_session_controller()
	return meta_session_controller.pawn_location_id()


func _apply_meta_environment(location_id: String) -> void:
	if run_state == null:
		return
	var environment := _build_meta_environment(location_id)
	if environment.is_empty():
		return
	run_state.set_environment(environment)
	_invalidate_travel_view_cache()
	_refresh_run_action_service()


func _ensure_meta_session_controller() -> void:
	if meta_session_controller == null:
		meta_session_controller = MetaSessionControllerScript.new()
	meta_session_controller.configure(library, meta_collection_service)


func _build_meta_environment(location_id: String) -> Dictionary:
	_ensure_meta_session_controller()
	var result := meta_session_controller.build_environment_result(location_id, run_state)
	if result.is_empty():
		return {}
	if typeof(result.get("home_state", {})) == TYPE_DICTIONARY and not (result.get("home_state", {}) as Dictionary).is_empty():
		run_state.home_state = (result.get("home_state", {}) as Dictionary).duplicate(true)
	return (result.get("environment", {}) as Dictionary).duplicate(true) if typeof(result.get("environment", {})) == TYPE_DICTIONARY else {}


func _build_meta_home_environment() -> Dictionary:
	return _build_meta_environment(META_LOCATION_HOME)


func _build_meta_pawn_environment() -> Dictionary:
	return _build_meta_environment(_meta_pawn_location_id())


func _meta_container_rows() -> Array:
	_ensure_meta_session_controller()
	var result := meta_session_controller.build_environment_result(META_LOCATION_HOME, run_state)
	var environment: Dictionary = result.get("environment", {}) if typeof(result.get("environment", {})) == TYPE_DICTIONARY else {}
	return _copy_array(environment.get("home_containers", []))


func _meta_container_item_ids_for_index(container_index: int) -> Array:
	_ensure_meta_session_controller()
	var rows := _meta_container_rows()
	if container_index < 0 or container_index >= rows.size() or typeof(rows[container_index]) != TYPE_DICTIONARY:
		return []
	return _copy_array((rows[container_index] as Dictionary).get("items", []))


func _meta_container_label(item_id: String) -> String:
	_ensure_meta_session_controller()
	var rows := _meta_container_rows()
	for row_value in rows:
		if typeof(row_value) == TYPE_DICTIONARY and str((row_value as Dictionary).get("item_id", "")) == item_id:
			return str((row_value as Dictionary).get("display_name", item_id.replace("_", " ").capitalize()))
	return item_id.strip_edges().replace("_", " ").capitalize()


func _meta_interactable_object_view_list() -> Array:
	_ensure_meta_session_controller()
	return meta_session_controller.interactable_object_view_list(meta_session_location_id, run_state, hover_target_id, focus_target_id, selected_object_id)


func _meta_interactable_object_view_cache_key() -> String:
	_ensure_meta_session_controller()
	return meta_session_controller.interactable_object_view_cache_key


func _meta_home_interactable_objects() -> Array:
	_ensure_meta_session_controller()
	return meta_session_controller.interactable_object_view_list(META_LOCATION_HOME, run_state, hover_target_id, focus_target_id, selected_object_id)


func _meta_home_summary_view() -> Dictionary:
	_ensure_meta_session_controller()
	return meta_session_controller.home_summary_view()


func _meta_snapshot_carried_instance_ids(owned_instances: Array, loadout: Array, housing_tier: String) -> Array:
	var owned_ids: Array = []
	for instance_value in owned_instances:
		var instance := _copy_dict(instance_value)
		var instance_id := int(instance.get("instance_id", 0))
		if instance_id > 0 and not owned_ids.has(instance_id):
			owned_ids.append(instance_id)
	if housing_tier == MetaCollectionServiceScript.HOUSING_BACK_ALLEY:
		return owned_ids
	var carried: Array = []
	for id_value in loadout:
		var instance_id := int(id_value)
		if instance_id > 0 and owned_ids.has(instance_id) and not carried.has(instance_id):
			carried.append(instance_id)
	return carried


func _meta_snapshot_container_capacity(containers: Array) -> int:
	var total := 0
	for container_value in containers:
		var container := _copy_dict(container_value)
		total += maxi(0, int(container.get("capacity", 0)))
	return total


func _meta_unopened_bag_rows() -> Array:
	_ensure_meta_session_controller()
	return meta_session_controller.unopened_bag_rows()


func _meta_pawn_interactable_objects() -> Array:
	_ensure_meta_session_controller()
	return meta_session_controller.interactable_object_view_list(_meta_pawn_location_id(), run_state, hover_target_id, focus_target_id, selected_object_id)


func open_meta_container(container_id: String = "") -> void:
	_open_meta_item_interaction(MetaItemInteractionViewModelScript.MODE_CONTAINER, selected_meta_item_key, container_id)


func open_meta_bag(instance_id: int) -> void:
	if instance_id <= 0:
		_show_message("Bag is not available.")
		return
	_open_meta_item_interaction(MetaItemInteractionViewModelScript.MODE_BAGS, "meta:bag:%d" % instance_id)


func buy_meta_home_upgrade() -> void:
	var result: Dictionary = meta_collection_service.purchase_housing_upgrade()
	if bool(result.get("ok", false)):
		meta_collection_service.save()
		meta_last_panel_message = str(result.get("message", "Home upgraded."))
		_apply_meta_environment(META_LOCATION_HOME)
	_show_meta_popup("Upgrade Home", str(result.get("message", "Upgrade unavailable.")), "meta_upgrade")
	_add_meta_close_card()
	_refresh()


func open_meta_trade_up() -> void:
	meta_trade_selected_instance_ids.clear()
	_open_meta_item_interaction(MetaItemInteractionViewModelScript.MODE_TRADE)


func open_meta_sal_shelf(slot_index: int) -> void:
	if _sal_starter_offer_is_pending():
		_resume_sal_starter_offer()
		return
	_ensure_meta_session_controller()
	var rows := meta_session_controller.sal_shelf_rows()
	if slot_index < 0 or slot_index >= rows.size():
		_show_meta_popup("Sal's Shelf", "That shelf spot does not exist.", "meta_sal_shelf")
		_add_meta_close_card()
		return
	var row := _copy_dict(rows[slot_index])
	if not bool(row.get("occupied", false)):
		_show_meta_popup("Empty Shelf", "This locked shelf spot is empty. A later victory may restock it.", "meta_sal_shelf")
		_add_meta_close_card()
		return
	var item := _copy_dict(row.get("item", {}))
	var quote := _copy_dict(row.get("quote_basis", {}))
	var floats := _copy_dict(quote.get("clamped_floats", {}))
	var contributions := _copy_dict(quote.get("rarity_contributions", {}))
	var mode := str(row.get("listing_mode", "normal"))
	var policy := "Normal shelf: ceil(max(quote + 1, quote × 1.5))."
	if mode == MetaCollectionServiceScript.LISTING_MODE_STARTER_DISCOUNT:
		policy = "Starter discount: max(1, round(quote × 0.75))."
	elif mode == MetaCollectionServiceScript.LISTING_MODE_MOCKING_RELIST:
		policy = "Sal's relist: ceil(quote × 10)."
	var summary := "%s · %s · %s\nPotency %.2f%% · Condition %.2f%% · Resonance %.2f%% · Usage %.2f%%\nRarity contributions P %.4f · C %.4f · R %.4f · U %.4f\nRarity multiplier %.6fx · Pawn quote %d gold\n%s\nAsking price %d gold · You have %d gold" % [
		str(row.get("display_name", "Collection Item")),
		str(row.get("collection_display_name", "Collection")),
		str(row.get("tier", "")).capitalize(),
		float(floats.get("potency", item.get("potency", 0.0))) * 100.0,
		float(floats.get("condition", item.get("condition", 0.0))) * 100.0,
		float(floats.get("resonance", item.get("resonance", 0.0))) * 100.0,
		float(floats.get("usage", item.get("usage", 0.0))) * 100.0,
		float(contributions.get("potency", 0.0)),
		float(contributions.get("condition", 0.0)),
		float(contributions.get("resonance", 0.0)),
		float(contributions.get("usage", 0.0)),
		float(quote.get("rarity_multiplier", 1.0)),
		int(quote.get("pawn_quote", 0)),
		policy,
		int(row.get("asking_price", 0)),
		int(row.get("gold_balance", 0)),
	]
	_show_meta_popup("Sal's Shelf · Slot %d" % (slot_index + 1), summary, "meta_sal_shelf")
	_add_meta_action_card(
		"Buy exact item",
		"Transfer instance %d with all four displayed values unchanged." % int(item.get("instance_id", 0)),
		"Costs %d gold." % int(row.get("asking_price", 0)),
		Callable(self, "_show_meta_sal_purchase_confirm").bind(slot_index),
		"Buy",
		true
	)
	_add_meta_close_card()


func _show_meta_sal_purchase_confirm(slot_index: int) -> void:
	var quote: Dictionary = meta_collection_service.arm_sal_shelf_purchase(slot_index)
	if not bool(quote.get("ok", false)):
		_show_meta_popup("Sal's Shelf", str(quote.get("message", "Purchase unavailable.")), "meta_sal_shelf")
		_add_meta_close_card()
		return
	_show_meta_popup(
		"Confirm Purchase",
		"Buy %s for %d gold? The exact saved instance moves to your collection." % [str(quote.get("display_name", "collection item")), int(quote.get("asking_price", 0))],
		"meta_sal_shelf"
	)
	_add_meta_action_card("Confirm Purchase", "The listing leaves Sal's shelf.", "Permanent", Callable(self, "_confirm_meta_sal_purchase").bind(str(quote.get("token", ""))), "Confirm", true)
	_add_meta_close_card()


func _confirm_meta_sal_purchase(token: String) -> void:
	var result: Dictionary = meta_collection_service.confirm_sal_shelf_purchase(token)
	if not bool(result.get("ok", false)):
		_show_meta_popup("Sal's Shelf", str(result.get("message", "Purchase unavailable.")), "meta_sal_shelf")
		_add_meta_close_card()
		_refresh()
		return
	var save_error := meta_collection_service.save()
	if save_error != OK:
		meta_collection_service.load()
		_show_meta_popup("Sal's Shelf", "The purchase could not be saved, so nothing changed.", "meta_sal_shelf")
		_add_meta_close_card()
		_refresh()
		return
	meta_last_panel_message = str(result.get("message", "Purchase complete."))
	_apply_meta_environment(meta_session_location_id)
	_hide_event_choice_popup()
	var purchased_item := _copy_dict(result.get("item", {}))
	selected_meta_item_key = "meta:item:%d" % int(purchased_item.get("instance_id", 0))
	_open_meta_item_interaction(MetaItemInteractionViewModelScript.MODE_CONTAINER, selected_meta_item_key)
	if not _copy_dict(result.get("starter_offer", {})).is_empty():
		_resume_sal_starter_offer()
	else:
		_start_sal_routine_dialogue("purchase")
	_refresh()


func open_meta_sell_counter() -> void:
	if _sal_starter_offer_is_pending():
		_resume_sal_starter_offer()
		return
	_open_meta_item_interaction(MetaItemInteractionViewModelScript.MODE_SALE)


func _toggle_meta_item_pack(instance_id: int, should_pack: bool) -> void:
	var result: Dictionary = meta_collection_service.pack_instance(instance_id) if should_pack else meta_collection_service.unpack_instance(instance_id)
	if bool(result.get("ok", false)):
		meta_collection_service.save()
		_apply_meta_environment(meta_session_location_id)
	meta_last_panel_message = str(result.get("message", "Packing unchanged."))
	selected_meta_item_key = "meta:item:%d" % instance_id
	_refresh_meta_item_interaction()
	_refresh()


func _open_meta_item_interaction(mode: String, focus_key: String = "", container_id: String = "") -> void:
	if meta_item_interaction_screen == null or meta_collection_service == null:
		return
	_hide_event_choice_popup()
	close_meta_item_interaction()
	_hide_run_inventory_popup()
	_hide_run_journal_popup()
	_hide_world_map_overlay()
	meta_item_interaction_mode = mode
	if not focus_key.strip_edges().is_empty():
		selected_meta_item_key = focus_key.strip_edges()
	var model := MetaItemInteractionViewModelScript.build(meta_collection_service, mode, selected_meta_item_key, meta_trade_selected_instance_ids)
	model["focus_explicit"] = not focus_key.strip_edges().is_empty()
	if not container_id.strip_edges().is_empty():
		var container_focus := _first_meta_selection_in_container(model, container_id)
		if not container_focus.is_empty():
			selected_meta_item_key = container_focus
			model = MetaItemInteractionViewModelScript.build(meta_collection_service, mode, selected_meta_item_key, meta_trade_selected_instance_ids)
			model["focus_explicit"] = true
	selected_meta_item_key = str(model.get("selected_key", ""))
	meta_trade_selected_instance_ids = _copy_array(model.get("trade_selected_ids", []))
	meta_item_interaction_screen.open(model)


func _refresh_meta_item_interaction() -> void:
	if meta_item_interaction_screen == null or not meta_item_interaction_screen.is_open() or meta_item_interaction_mode.is_empty():
		return
	var model := MetaItemInteractionViewModelScript.build(meta_collection_service, meta_item_interaction_mode, selected_meta_item_key, meta_trade_selected_instance_ids)
	selected_meta_item_key = str(model.get("selected_key", ""))
	meta_trade_selected_instance_ids = _copy_array(model.get("trade_selected_ids", []))
	meta_item_interaction_screen.update_model(model)


func close_meta_item_interaction() -> void:
	_close_bag_open_reel()
	if meta_item_interaction_screen != null:
		meta_item_interaction_screen.close()
	meta_item_interaction_mode = ""
	selected_meta_item_key = ""
	meta_trade_selected_instance_ids.clear()


func _meta_item_interaction_is_visible() -> bool:
	return meta_item_interaction_screen != null and meta_item_interaction_screen.is_open()


func _on_meta_item_selection_changed(selection_key: String) -> void:
	selected_meta_item_key = selection_key.strip_edges()


func _on_meta_item_action_requested(action_id: String, payload: Dictionary) -> void:
	match action_id:
		"pack":
			_toggle_meta_item_pack(int(payload.get("instance_id", 0)), true)
		"unpack":
			_toggle_meta_item_pack(int(payload.get("instance_id", 0)), false)
		"open_bag":
			_open_selected_meta_bag(int(payload.get("instance_id", 0)))
		"arm_sale":
			_show_meta_sale_confirm(str(payload.get("kind", "")), int(payload.get("instance_id", 0)))
		"toggle_trade":
			_toggle_meta_trade_selection(int(payload.get("instance_id", 0)))
		"arm_trade":
			_arm_meta_trade_up(_copy_array(payload.get("instance_ids", [])))


func _toggle_meta_trade_selection(instance_id: int) -> void:
	if instance_id <= 0:
		return
	var existing_index := meta_trade_selected_instance_ids.find(instance_id)
	if existing_index >= 0:
		meta_trade_selected_instance_ids.remove_at(existing_index)
	elif meta_trade_selected_instance_ids.size() < 5:
		meta_trade_selected_instance_ids.append(instance_id)
	selected_meta_item_key = "meta:item:%d" % instance_id
	_refresh_meta_item_interaction()


func _open_selected_meta_bag(instance_id: int) -> void:
	if instance_id <= 0:
		_show_message("Bag is not available.")
		return
	var result: Dictionary = meta_collection_service.open_bag(instance_id)
	if not bool(result.get("ok", false)):
		meta_last_panel_message = str(result.get("message", "Bag could not be opened."))
		_show_message(meta_last_panel_message)
		_refresh_meta_item_interaction()
		return
	var save_error := meta_collection_service.save()
	if save_error != OK:
		meta_collection_service.load()
		meta_last_panel_message = "The bag could not be saved, so nothing changed."
		_show_message(meta_last_panel_message)
		_refresh_meta_item_interaction()
		return
	var revealed_item := _copy_dict(result.get("item", {}))
	selected_meta_item_key = "meta:item:%d" % int(revealed_item.get("instance_id", 0))
	meta_trade_selected_instance_ids.clear()
	meta_last_panel_message = _collection_reveal_text(result)
	_apply_meta_environment(meta_session_location_id)
	_open_meta_item_interaction(MetaItemInteractionViewModelScript.MODE_CONTAINER, selected_meta_item_key)
	_open_bag_reel(result)
	_show_message(meta_last_panel_message)
	_refresh()


func _open_bag_reel(open_result: Dictionary) -> void:
	if bag_open_reel == null:
		return
	var resolver: Variant = CollectionItemResolverScript.new()
	var bag := _copy_dict(open_result.get(BagOpenReelViewModelScript.RESULT_BAG_KEY, {}))
	var possible_contents: Array = resolver.bag_item_options_for_bag(int(bag.get("bagdef_id", -1)))
	var model := BagOpenReelViewModelScript.build(open_result, possible_contents, _reduce_motion_enabled())
	bag_open_reel.open(model)


func _close_bag_open_reel() -> void:
	if bag_open_reel != null:
		bag_open_reel.close()


func _first_meta_selection_in_container(model: Dictionary, container_id: String) -> String:
	var clean_id := container_id.strip_edges()
	for container_value in _copy_array(model.get("containers", [])):
		var container := _copy_dict(container_value)
		if str(container.get("container_type", "")) != clean_id and str(container.get("key", "")) != clean_id:
			continue
		for slot_value in _copy_array(container.get("slots", [])):
			var key := str(_copy_dict(slot_value).get("selection_key", ""))
			if not key.is_empty():
				return key
	return ""


func _arm_meta_trade_up(instance_ids: Array) -> void:
	var result: Dictionary = meta_collection_service.arm_trade_up(instance_ids)
	if not bool(result.get("ok", false)):
		_show_meta_popup("Trade-Up Station", str(result.get("message", "Trade-up unavailable.")), "meta_trade_up")
		_add_meta_close_card()
		return
	_show_meta_popup("Confirm Trade-Up", str(result.get("message", "Confirm trade-up.")), "meta_trade_up")
	_add_meta_action_card("Confirm", "This consumes the five listed items.", "Permanent", Callable(self, "_confirm_meta_trade_up").bind(str(result.get("token", ""))), "Confirm", true)
	_add_meta_close_card()


func _confirm_meta_trade_up(token: String) -> void:
	var result: Dictionary = meta_collection_service.confirm_trade_up(token)
	if not bool(result.get("ok", false)):
		_show_meta_popup("Trade-Up Station", str(result.get("message", "Trade-up unavailable.")), "meta_trade_up")
		_add_meta_close_card()
		_refresh()
		return
	var save_error := meta_collection_service.save()
	if save_error != OK:
		meta_collection_service.load()
		_show_meta_popup("Trade-Up Station", "The trade-up could not be saved, so nothing changed.", "meta_trade_up")
		_add_meta_close_card()
		_refresh()
		return
	var granted := _copy_dict(result.get("item", {}))
	selected_meta_item_key = "meta:item:%d" % int(granted.get("instance_id", 0))
	meta_trade_selected_instance_ids.clear()
	meta_last_panel_message = str(result.get("message", "Trade-up complete."))
	_apply_meta_environment(meta_session_location_id)
	_hide_event_choice_popup()
	_open_meta_item_interaction(MetaItemInteractionViewModelScript.MODE_TRADE, selected_meta_item_key)
	_show_message(meta_last_panel_message)
	_refresh()


func _show_meta_sale_confirm(kind: String, instance_id: int) -> void:
	var quote: Dictionary = meta_collection_service.arm_sale(kind, instance_id)
	if not bool(quote.get("ok", false)):
		_show_meta_popup("Sell Counter", str(quote.get("message", "Sale unavailable.")), "meta_pawn_counter")
		_add_meta_close_card()
		return
	var label := str(quote.get("display_name", "Item"))
	_show_meta_popup("Confirm Sale", "Sell %s for %d gold?" % [label, int(quote.get("price", 0))], "meta_pawn_counter")
	_add_meta_action_card("Confirm Sale", "The sold item leaves your collection.", "Permanent", Callable(self, "_confirm_meta_sale").bind(str(quote.get("token", ""))), "Confirm", true)
	_add_meta_close_card()


func _confirm_meta_sale(token: String) -> void:
	var result: Dictionary = meta_collection_service.confirm_sale(token)
	if not bool(result.get("ok", false)):
		_show_meta_popup("Sell Counter", str(result.get("message", "Sale unavailable.")), "meta_pawn_counter")
		_add_meta_close_card()
		_refresh()
		return
	var save_error := meta_collection_service.save()
	if save_error != OK:
		meta_collection_service.load()
		_show_meta_popup("Sell Counter", "The sale could not be saved, so nothing changed.", "meta_pawn_counter")
		_add_meta_close_card()
		_refresh()
		return
	_apply_meta_environment(meta_session_location_id)
	meta_last_panel_message = str(result.get("message", "Sale complete."))
	_refresh()
	_hide_event_choice_popup()
	_refresh_meta_item_interaction()
	_start_sal_routine_dialogue("sale")


func _show_meta_popup(title: String, summary: String, popup_type: String) -> void:
	if event_choice_popup_overlay == null or event_choice_popup_choices_list == null:
		return
	pending_event_choice_popup_event_id = ""
	pending_event_choice_popup_focus_choice_id = ""
	pending_event_choice_popup_snapshot = {
		"visible": true,
		"blocking": false,
		"popup_type": popup_type,
		"interaction_kind": popup_type,
		"dismissible": true,
		"summary": summary,
		"choices": [],
	}
	if event_choice_popup_title_label != null:
		event_choice_popup_title_label.text = title
	if event_choice_popup_summary_label != null:
		event_choice_popup_summary_label.text = summary
	_clear(event_choice_popup_choices_list)
	event_choice_popup_overlay.visible = true
	event_choice_popup_overlay.move_to_front()
	_position_event_choice_popup()
	call_deferred("_position_event_choice_popup")


func _add_meta_action_card(title: String, text: String, impact: String, callback: Callable, button_text: String, primary: bool) -> void:
	_add_wager_confirmation_card(title, text, impact, callback, primary)
	if event_choice_popup_choices_list == null or event_choice_popup_choices_list.get_child_count() <= 0:
		return
	var card := event_choice_popup_choices_list.get_child(event_choice_popup_choices_list.get_child_count() - 1)
	var stack := card.get_child(0) as VBoxContainer if card.get_child_count() > 0 else null
	if stack == null or stack.get_child_count() <= 0:
		return
	var button := stack.get_child(stack.get_child_count() - 1) as Button
	if button != null:
		button.text = button_text


func _add_meta_popup_line(text: String) -> void:
	if event_choice_popup_choices_list == null:
		return
	var label := _label(text, 13)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_set_control_font_color(label, VisualStyle.SOFT)
	event_choice_popup_choices_list.add_child(label)


func _add_meta_close_card() -> void:
	_add_meta_action_card("Back", "Return to the room.", "No change.", Callable(self, "_hide_event_choice_popup"), "Back", false)


func _meta_owned_item_rows() -> Array:
	_ensure_meta_session_controller()
	return meta_session_controller.owned_item_rows()


func _meta_sale_rows() -> Array:
	_ensure_meta_session_controller()
	return meta_session_controller.sale_rows()


func _meta_trade_up_candidates() -> Array:
	_ensure_meta_session_controller()
	return meta_session_controller.trade_up_candidates()


func _meta_next_tier(tier: String) -> String:
	_ensure_meta_session_controller()
	return meta_session_controller.next_tier(tier)


func close_inventory_page() -> void:
	if inventory_page != null:
		inventory_page.visible = false
	if start_menu_intro != null:
		start_menu_intro.visible = true
	if start_menu_controls != null:
		start_menu_controls.visible = true
	_refresh_start_screen()


func open_game_test_menu() -> void:
	if not show_game_library_launcher:
		return
	if game_test_menu == null:
		return
	close_content_group_config()
	close_challenge_selection()
	if settings_menu != null:
		settings_menu.visible = false
	if inventory_page != null:
		inventory_page.visible = false
	if start_menu_controls != null:
		start_menu_controls.visible = false
	if start_menu_intro != null:
		start_menu_intro.visible = false
	game_test_menu.visible = true
	if game_test_status_label != null:
		game_test_status_label.text = "Choose a game to enter its real interface."


func close_game_test_menu() -> void:
	if game_test_menu != null:
		game_test_menu.visible = false
	if start_menu_intro != null:
		start_menu_intro.visible = true
	if start_menu_controls != null:
		start_menu_controls.visible = true
	_refresh_start_screen()


func start_game_test_session(game_id: String) -> void:
	if not show_game_library_launcher:
		return
	if library == null:
		_initialize_foundation()
	var game := _game_module_for_id(game_id)
	if game == null:
		if game_test_status_label != null:
			game_test_status_label.text = "Could not load %s." % game_id
		return
	_hide_travel_transition()
	_reset_game_surface_runtime_state()
	run_state = RunState.new()
	run_state.start_new(_game_test_seed(game_id))
	run_state.bankroll = _game_test_bankroll()
	dev_game_test_mode = true
	_refresh_run_action_service()
	var environment := _game_test_environment(game_id, game)
	run_state.set_environment(environment)
	current_game = null
	last_game_result = {}
	last_environment_runtime_result = {}
	last_item_result = {}
	last_hook_result = {}
	selected_action_category = ACTION_CATEGORY_GAMES
	_hide_event_choice_popup()
	_hide_run_inventory_popup()
	_hide_run_journal_popup()
	_hide_travel_transition()
	_clear_selected_game_action()
	_clear_selected_stake()
	_clear_selected_travel()
	_clear_selected_event_choice()
	_clear_selected_item_offer()
	_clear_selected_service_hook()
	_clear_selected_lender_hook()
	clear_interaction_focus()
	if game_test_menu != null:
		game_test_menu.visible = false
	if start_menu_controls != null:
		start_menu_controls.visible = true
	if start_menu_intro != null:
		start_menu_intro.visible = true
	enter_game(game_id)


func acquire_profile_chip() -> void:
	if profile_inventory == null:
		_initialize_profile_inventory()
	profile_inventory.add_reference_chip()
	var error := profile_inventory.save()
	if inventory_status_label != null:
		inventory_status_label.text = "Chip stored in profile inventory." if error == OK else "Chip added, but profile save failed."
	_refresh_profile_inventory_page()


func _refresh_profile_inventory_page() -> void:
	if profile_inventory == null:
		return
	if inventory_status_label != null and inventory_status_label.text.is_empty():
		inventory_status_label.text = "Profile stash ready."
	if inventory_items_list == null:
		return
	_clear(inventory_items_list)
	_add_profile_summary_sections()
	var stash_heading := _section("Profile Stash")
	_set_control_font_color(stash_heading, VisualStyle.YELLOW)
	inventory_items_list.add_child(stash_heading)
	if profile_inventory.items.is_empty():
		var empty := _label("No profile items yet. Acquire the reference chip to test permanent storage.", 13)
		_set_control_font_color(empty, VisualStyle.CYAN_2)
		inventory_items_list.add_child(empty)
		return
	for item in profile_inventory.items:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var item_data := item as Dictionary
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		inventory_items_list.add_child(row)
		var icon := TextureRect.new()
		icon.texture = _profile_chip_texture()
		icon.custom_minimum_size = Vector2(42, 42)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var text_stack := VBoxContainer.new()
		text_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text_stack)
		var title := _label("%s x%d" % [str(item_data.get("display_name", "Profile Item")), int(item_data.get("quantity", 1))], 14)
		_set_control_font_color(title, VisualStyle.WHITE)
		text_stack.add_child(title)
		var description := _label(str(item_data.get("description", "")), 12)
		_set_control_font_color(description, VisualStyle.CYAN_2)
		text_stack.add_child(description)


func _add_profile_summary_sections() -> void:
	if inventory_items_list == null or profile_inventory == null:
		return
	var daily := _copy_dict(profile_inventory.daily_runs)
	var lifetime := _copy_dict(profile_inventory.lifetime_stats)
	var summary_panel := _panel_container(Color("#05070d", 0.86), VisualStyle.CYAN_2)
	summary_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_items_list.add_child(summary_panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 5)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_panel.add_child(stack)
	var summary_heading := _label("Profile Summary", 15)
	_set_control_font_color(summary_heading, VisualStyle.CYAN)
	stack.add_child(summary_heading)
	stack.add_child(_profile_line("Runs: %d  Daily streak: %d / best %d" % [
		int(lifetime.get("total_runs", 0)),
		int(daily.get("current_streak", 0)),
		int(daily.get("best_streak", 0)),
	]))
	var victories := _copy_dict(lifetime.get("victories_per_route", {}))
	stack.add_child(_profile_line("Victories: card %d, showdown %d" % [
		int(victories.get("players_card_cashout", 0)),
		int(victories.get("showdown", 0)),
	]))
	stack.add_child(_profile_line("Bankroll won/lost: $%d / $%d  Biggest win: $%d" % [
		int(lifetime.get("total_bankroll_won", 0)),
		int(lifetime.get("total_bankroll_lost", 0)),
		int(lifetime.get("biggest_single_win", 0)),
	]))
	var challenge_rows := profile_inventory.completed_challenge_rows()
	var challenge_heading := _section("Completed Challenges")
	_set_control_font_color(challenge_heading, VisualStyle.YELLOW)
	inventory_items_list.add_child(challenge_heading)
	if challenge_rows.is_empty():
		inventory_items_list.add_child(_profile_line("No completed challenges yet."))
	else:
		for challenge_value in challenge_rows:
			var challenge := _copy_dict(challenge_value)
			var title := str(challenge.get("title", challenge.get("flag", "Challenge"))).strip_edges()
			inventory_items_list.add_child(_profile_line(title))
	var history_heading := _section("Recent Runs")
	_set_control_font_color(history_heading, VisualStyle.YELLOW)
	inventory_items_list.add_child(history_heading)
	var history := _copy_array(profile_inventory.run_history)
	if history.is_empty():
		inventory_items_list.add_child(_profile_line("No completed runs recorded yet."))
	else:
		var count := mini(history.size(), 8)
		for index in range(count):
			var entry := _copy_dict(history[index])
			inventory_items_list.add_child(_profile_line("%s - %s - $%d - Day %d - %d actions" % [
				str(entry.get("completed_date", "")),
				_profile_history_outcome_text(entry),
				int(entry.get("final_bankroll", 0)),
				int(entry.get("day_count", 1)),
				int(entry.get("duration_actions", 0)),
			]))


func _profile_line(text: String) -> Label:
	var label := _label(text, 12)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_set_control_font_color(label, VisualStyle.SOFT)
	return label


func _profile_history_outcome_text(entry: Dictionary) -> String:
	var outcome := str(entry.get("outcome", "")).capitalize()
	var route := str(entry.get("route", "")).replace("_", " ").capitalize()
	if route.is_empty() or route == outcome:
		return outcome
	return "%s: %s" % [outcome, route]


func _collection_reveal_text(result: Dictionary) -> String:
	_ensure_meta_session_controller()
	return meta_session_controller.collection_reveal_text(result)


func _refresh_start_screen() -> void:
	if release_version_label != null:
		release_version_label.text = _release_version_text()
	var has_save := _has_foundation_save()
	if start_status_label != null:
		var save_slot_status := save_service.slot_status(autosave_slot_id) if save_service != null else {}
		if not content_validation_status_message.is_empty():
			start_status_label.text = content_validation_status_message
		elif has_save:
			if bool(save_slot_status.get("primary_corrupt", false)) and bool(save_slot_status.get("backup_loadable", false)):
				start_status_label.text = "Backup save available. Continue will recover the last good run."
			else:
				start_status_label.text = "Saved run available. Continue it, or enter a seed for a new run."
		elif bool(save_slot_status.get("primary_corrupt", false)) or bool(save_slot_status.get("backup_corrupt", false)):
			start_status_label.text = "Saved run is corrupt and no backup can be loaded."
		elif start_status_label.text.is_empty() or start_status_label.text.begins_with("Saved run") or start_status_label.text.begins_with("No saved"):
			start_status_label.text = "No saved run yet. Enter a seed or use the generated one."
	if continue_button != null:
		continue_button.disabled = not has_save
		continue_button.text = "Continue"
		continue_button.tooltip_text = "Load the saved run." if has_save else "No saved run yet."
	_refresh_content_group_controls()
	_refresh_challenge_controls()


func _release_version_text() -> String:
	var release_version := str(ProjectSettings.get_setting("application/config/version", "0.4.0")).strip_edges()
	if release_version.is_empty():
		release_version = "0.4.0"
	return "Version %s" % release_version


func _generate_menu_seed_text() -> String:
	main_menu_seed_counter = posmod(main_menu_seed_counter + 1, 1000000)
	var now: Dictionary = Time.get_datetime_dict_from_system()
	var year := int(now.get("year", 0))
	var month := maxi(1, int(now.get("month", 1)))
	var day := maxi(1, int(now.get("day", 1)))
	var tick_fragment := posmod(Time.get_ticks_usec(), 1000000)
	return "RUN-%04d%02d%02d-%06d-%03d" % [year, month, day, tick_fragment, main_menu_seed_counter]


func _refresh_menu_seed_text() -> void:
	if seed_input != null:
		seed_input.text = _generate_menu_seed_text()


func save_status_snapshot() -> Dictionary:
	var consequence := _consequence_view_snapshot() if run_state != null else {}
	var pressure: Dictionary = consequence.get("pressure", {})
	return {
		"slot_id": autosave_slot_id,
		"has_save": _has_foundation_save(),
		"load_available": _has_foundation_save(),
		"save_path": save_service.run_save_path(autosave_slot_id) if save_service != null else "",
		"status_text": _save_status_text(),
		"pending_autosave": pending_autosave,
		"active_summary": _run_summary_text(run_state) if run_state != null else "",
		"visible_objective": _objective_hud_text() if run_state != null else "",
		"visible_bankroll": _presented_bankroll() if run_state != null else 0,
		"visible_run_status": run_state.run_status if run_state != null else "",
		"visible_pressure": _pressure_status_text(pressure),
		"visible_environment": str(run_state.current_environment.get("display_name", "")) if run_state != null else "",
		"visible_suspicion": run_state.suspicion_level() if run_state != null else 0,
		"visible_risk": _risk_cue_text() if run_state != null else "",
		"visible_inventory": str(consequence.get("inventory_summary", "")),
		"visible_debt": str(consequence.get("debt_summary", "")),
		"visible_story": str(consequence.get("story_text", "")),
		"visible_travel": str(consequence.get("travel_summary", "")),
		"story_count": run_state.story_log_entry_count() if run_state != null else 0,
		"flag_count": run_state.narrative_flags.size() if run_state != null else 0,
		"travel_count": _travel_target_ids().size() if run_state != null else 0,
	}


func _has_foundation_save() -> bool:
	return save_service != null and save_service.has_run(autosave_slot_id)


func _run_menu_is_visible() -> bool:
	return run_menu_overlay != null and run_menu_overlay.visible


func _hide_run_menu() -> void:
	if run_menu_overlay != null:
		run_menu_overlay.visible = false


func _refresh_run_menu() -> void:
	if run_menu_overlay == null:
		return
	var has_save := _has_foundation_save()
	var can_save := run_state != null and not dev_game_test_mode
	var can_abandon := run_state != null and run_state.run_status == RunState.RUN_STATUS_ACTIVE
	if run_menu_status_label != null:
		var venue := "No active venue"
		var status := "No active run"
		if run_state != null:
			venue = str(run_state.current_environment.get("display_name", "Current venue"))
			status = "Seed %s | %s | Bankroll %d | Heat %d" % [
				run_state.player_facing_seed_text(),
				venue,
				_presented_bankroll(),
				run_state.suspicion_level(),
			]
		var save_note := "Resume Slot ready." if has_save else "Resume Slot empty."
		run_menu_status_label.text = "%s\n%s Save overwrites this slot; Load replaces this run." % [status, save_note]
	if run_menu_resume_button != null:
		run_menu_resume_button.disabled = false
	if run_menu_save_button != null:
		run_menu_save_button.disabled = not can_save
		run_menu_save_button.tooltip_text = "Overwrite the Resume Slot with this run." if can_save else "No active savable run."
	if run_menu_load_button != null:
		run_menu_load_button.disabled = not has_save
		run_menu_load_button.tooltip_text = "Load the Resume Slot and replace this run." if has_save else "No saved run in the Resume Slot."
	if run_menu_journal_button != null:
		run_menu_journal_button.disabled = run_state == null
		run_menu_journal_button.tooltip_text = "Review the saved story beats for this run." if run_state != null else "No active run."
	if run_menu_settings_button != null:
		run_menu_settings_button.disabled = false
	if run_menu_abandon_button != null:
		run_menu_abandon_button.disabled = not can_abandon
		run_menu_abandon_button.tooltip_text = "End this run immediately." if can_abandon else "This run is already over."
	if run_menu_main_menu_button != null:
		run_menu_main_menu_button.disabled = false
	if run_menu_skip_tutorial_button != null:
		run_menu_skip_tutorial_button.visible = run_state != null and run_state.is_tutorial_run()
		run_menu_skip_tutorial_button.disabled = not run_menu_skip_tutorial_button.visible


func _configure_coach_for_run() -> void:
	if coach_overlay == null:
		return
	coach_overlay.restore_seen(profile_inventory.tips_seen if profile_inventory != null else {})
	coach_overlay.set_tips_enabled(user_settings == null or user_settings.coach_tips_enabled)
	if run_state != null and run_state.is_tutorial_run():
		coach_overlay.begin_tutorial_run()


func current_run_menu_snapshot() -> Dictionary:
	_refresh_run_menu()
	return {
		"visible": _run_menu_is_visible(),
		"screen": current_screen,
		"slot_id": autosave_slot_id,
		"has_save": _has_foundation_save(),
		"status_text": run_menu_status_label.text if run_menu_status_label != null else "",
		"resume_disabled": run_menu_resume_button.disabled if run_menu_resume_button != null else true,
		"save_disabled": run_menu_save_button.disabled if run_menu_save_button != null else true,
		"load_disabled": run_menu_load_button.disabled if run_menu_load_button != null else true,
		"journal_disabled": run_menu_journal_button.disabled if run_menu_journal_button != null else true,
		"settings_disabled": run_menu_settings_button.disabled if run_menu_settings_button != null else true,
		"abandon_disabled": run_menu_abandon_button.disabled if run_menu_abandon_button != null else true,
		"main_menu_disabled": run_menu_main_menu_button.disabled if run_menu_main_menu_button != null else true,
	}


func _save_status_text() -> String:
	if _is_meta_session():
		return ""
	if run_state != null:
		return str(_run_status_hud_model().get("save_text", ""))
	var availability := "Saved run available" if _has_foundation_save() else "No saved run"
	if run_state == null:
		return availability
	var prefix := save_status_message
	if prefix.is_empty():
		prefix = "Current run"
	return "%s | %s" % [availability, prefix]


func _hud_status_text() -> String:
	return str(_run_status_hud_model().get("status_text", ""))


func _objective_hud_text() -> String:
	if run_state == null:
		return ""
	return str(_run_status_hud_model().get("objective_text", ""))


func _run_status_hud_model() -> Dictionary:
	if _is_meta_session():
		return _meta_status_hud_model()
	if run_state == null:
		return {}
	var pressure := _run_pressure_view()
	var objective := _demo_objective_status()
	var recent_result := _recent_result_snapshot()
	var deltas: Dictionary = recent_result.get("deltas", {})
	var state := FoundationHudViewModelScript.objective_presentation_state(pressure, objective)
	return FoundationHudViewModelScript.run_status_model(run_state, {
		"pressure": pressure,
		"demo_objective": objective,
		"pit_boss_watch": _pit_boss_watch_status(),
		"next_for_state": _next_objective_option_for_state(state, objective),
		"recent_result": recent_result,
		"bankroll_delta": _visible_recent_bankroll_delta(int(recent_result.get("bankroll_delta", deltas.get("bankroll_delta", 0)))),
		"debt_items": _debt_view_list(),
		"inventory_items": _inventory_view_list(),
		"presented_bankroll": _presented_bankroll(),
		"has_save": _has_foundation_save(),
		"save_status_message": save_status_message,
		"economy_text": _economy_cue_text(),
		"next_objective": _next_objective_option(),
		"label_from_id": Callable(self, "_label_from_id"),
		"player_facing_text": Callable(self, "_player_facing_text"),
	})


func _meta_status_hud_model() -> Dictionary:
	return FoundationHudViewModelScript.meta_status_model(_meta_home_summary_view())


func _apply_hud_mode_visibility() -> void:
	var meta_mode := _is_meta_session()
	if top_inventory_button != null:
		top_inventory_button.visible = not meta_mode
	if active_item_button != null:
		active_item_button.visible = not meta_mode


func _hud_goal_text(pressure: Dictionary, demo_objective: Dictionary = {}) -> String:
	return FoundationHudViewModelScript.hud_goal_text(run_state, pressure, demo_objective, Callable(self, "_player_facing_text"))


func _hud_debt_text(debt_items: Array) -> String:
	return FoundationHudViewModelScript.hud_debt_text(debt_items, Callable(self, "_player_facing_text"))


func _hud_inventory_text(inventory_items: Array) -> String:
	return FoundationHudViewModelScript.hud_inventory_text(inventory_items, Callable(self, "_player_facing_text"))


func _hud_home_text() -> String:
	return FoundationHudViewModelScript.hud_home_text(run_state, Callable(self, "_player_facing_text"))


func _hud_run_status_text(pressure: Dictionary) -> String:
	return FoundationHudViewModelScript.hud_run_status_text(run_state, pressure)


func _hud_save_text() -> String:
	return FoundationHudViewModelScript.hud_save_text(_has_foundation_save(), save_status_message, Callable(self, "_player_facing_text"))


func _hud_meter(value: int, maximum: int, width: int) -> String:
	return FoundationHudViewModelScript.hud_meter(value, maximum, width)


func _repeat_char(character: String, count: int) -> String:
	return character.repeat(maxi(0, count))


func _hud_short(text: String, max_length: int) -> String:
	return FoundationHudViewModelScript.hud_short(text, max_length, Callable(self, "_player_facing_text"))


func _objective_goal_text(pressure: Dictionary, demo_objective: Dictionary = {}) -> String:
	return FoundationHudViewModelScript.objective_goal_text(run_state, pressure, demo_objective)


func _boss_floor_objective_goal_text(demo_objective: Dictionary) -> String:
	return FoundationHudViewModelScript.boss_floor_objective_goal_text(demo_objective)


func _objective_presentation_state(pressure: Dictionary, demo_objective: Dictionary) -> String:
	return FoundationHudViewModelScript.objective_presentation_state(pressure, demo_objective)


func _objective_guidance_view(pressure: Dictionary, demo_objective: Dictionary) -> Dictionary:
	var state := FoundationHudViewModelScript.objective_presentation_state(pressure, demo_objective)
	return FoundationHudViewModelScript.objective_guidance_view(pressure, demo_objective, _next_objective_option_for_state(state, demo_objective))


func _boss_floor_incomplete_guidance(demo_objective: Dictionary) -> String:
	return FoundationHudViewModelScript.boss_floor_incomplete_guidance(demo_objective)


func _boss_floor_high_roller_progress_close(demo_objective: Dictionary) -> bool:
	return FoundationHudViewModelScript.boss_floor_progress_close(demo_objective)


func _boss_floor_heat_pressure_close(demo_objective: Dictionary) -> bool:
	return FoundationHudViewModelScript.boss_floor_heat_pressure_close(demo_objective)


func _is_boss_floor_demo_objective(demo_objective: Dictionary) -> bool:
	return FoundationHudViewModelScript.is_boss_floor_objective(demo_objective)


func _boss_floor_status_key(suffix: String) -> String:
	return FoundationHudViewModelScript.boss_floor_status_key(suffix)


func _objective_pressure_text(pressure: Dictionary) -> String:
	return FoundationHudViewModelScript.objective_pressure_text(pressure)


func _demo_objective_status() -> Dictionary:
	if run_state == null:
		return {}
	return run_state.demo_objective_status()


func _pit_boss_watch_status() -> Dictionary:
	if run_state == null:
		return {}
	return run_state.pit_boss_watch_status(run_state.current_environment)


func _pit_boss_hud_text(status: Dictionary) -> String:
	return FoundationHudViewModelScript.pit_boss_hud_text(status)


func _active_demo_objective_needs_play() -> bool:
	var objective := _demo_objective_status()
	return bool(objective.get("active", false)) and not bool(objective.get("complete", false))


func _next_opportunity_hint() -> String:
	return str(_next_objective_option().get("hint", ""))


func _next_objective_option() -> Dictionary:
	if run_state == null:
		return {}
	var pressure := _run_pressure_view()
	var pressure_state := str(pressure.get("state", ""))
	if pressure_state == "victory":
		return _objective_for_object("menu", "main_menu", "return to the menu or start fresh", true)
	if pressure_state == "failed":
		return _objective_for_object("menu", "main_menu", "return to the menu to continue or start over", true)

	var demo_objective := _demo_objective_status()
	var objective_state := _objective_presentation_state(pressure, demo_objective)
	var state_objective := _next_objective_option_for_state(objective_state, demo_objective)
	if not state_objective.is_empty():
		return state_objective
	if current_game != null:
		if _active_demo_objective_needs_play():
			return {
				"hint": "choose stake and press for the objective",
				"object_type": "game_surface",
				"object_id": "",
				"enabled": true,
			}
		return {
			"hint": "choose stake and click a game-surface action",
			"object_type": "game_surface",
			"object_id": "",
			"enabled": true,
		}
	if _active_demo_objective_needs_play() and _has_enabled_game_object():
		return _objective_for_object(CONTEXT_MODE_GAME, "", "play for the boss-floor target", true)

	var event_option := _first_event_option()
	if not event_option.is_empty():
		return _objective_for_object(CONTEXT_MODE_EVENT, "event:%s" % str(event_option.get("id", "")), "answer the local event", true)

	var item_offer := _first_enabled_item_offer()
	if not item_offer.is_empty():
		return _objective_for_object(CONTEXT_MODE_ITEM, "item:%s" % str(item_offer.get("id", "")), "inspect useful gear", true)

	var service_option := _first_enabled_hook_option(_service_hook_view_list())
	if not service_option.is_empty():
		return _objective_for_object(CONTEXT_MODE_SERVICE, "service:%s" % str(service_option.get("id", "")), "use a local service", true)

	var lender_option := _first_enabled_hook_option(_lender_hook_view_list())
	if not lender_option.is_empty():
		return _objective_for_object(CONTEXT_MODE_LENDER, "lender:%s" % str(lender_option.get("id", "")), "consider lender help", true)

	var travel_choice := _first_enabled_travel_choice()
	if not travel_choice.is_empty():
		return _objective_for_object(CONTEXT_MODE_TRAVEL, "travel:%s" % str(travel_choice.get("id", "")), "choose where to go next", true)

	if _has_enabled_game_object():
		return _objective_for_object(CONTEXT_MODE_GAME, "", "play a visible game", true)

	var locked_travel := _first_disabled_travel_choice()
	if not locked_travel.is_empty():
		var locked_reason := str(locked_travel.get("disabled_reason", "routes are locked for now"))
		return _objective_for_object(CONTEXT_MODE_TRAVEL, "travel:%s" % str(locked_travel.get("id", "")), locked_reason, false)

	return _objective_for_object("menu", "main_menu", "return to the menu or inspect the room", true)


func _next_objective_option_for_state(state: String, demo_objective: Dictionary) -> Dictionary:
	if run_state != null and bool(demo_objective.get("players_card_ready_to_claim", false)):
		if str(run_state.current_environment.get("archetype_id", "")) == RunState.GRAND_CASINO_CAGE_ARCHETYPE_ID:
			return _objective_for_object(CONTEXT_MODE_CASINO_FIXTURE, "casino_fixture:cage_counter", "settle any marker and claim the next tier from Linda", true)
		return _objective_for_object(CONTEXT_MODE_TRAVEL, "travel:grand_casino_cage", "enter the Cage to settle or claim the next tier", true)
	return FoundationHudViewModelScript.next_objective_option_for_state(state, demo_objective, Callable(self, "_player_facing_text"))


func _objective_for_object(object_type: String, object_id: String, hint: String, enabled: bool) -> Dictionary:
	return FoundationHudViewModelScript.objective_for_object(object_type, object_id, hint, enabled, Callable(self, "_player_facing_text"))


func _first_enabled_travel_choice() -> Dictionary:
	for choice in _travel_choice_view_list():
		if typeof(choice) == TYPE_DICTIONARY and bool((choice as Dictionary).get("enabled", true)):
			return (choice as Dictionary).duplicate(true)
	return {}


func _first_disabled_travel_choice() -> Dictionary:
	for choice in _travel_choice_view_list():
		if typeof(choice) == TYPE_DICTIONARY and not bool((choice as Dictionary).get("enabled", true)):
			return (choice as Dictionary).duplicate(true)
	return {}


func _first_event_option() -> Dictionary:
	for option in _eligible_event_option_view_list():
		if typeof(option) == TYPE_DICTIONARY:
			return (option as Dictionary).duplicate(true)
	return {}


func _first_enabled_item_offer() -> Dictionary:
	for offer in _item_offer_view_list():
		if typeof(offer) == TYPE_DICTIONARY and bool((offer as Dictionary).get("affordable", true)):
			return (offer as Dictionary).duplicate(true)
	return {}


func _first_enabled_hook_option(options: Array) -> Dictionary:
	for option in options:
		if typeof(option) == TYPE_DICTIONARY and bool((option as Dictionary).get("enabled", false)):
			return (option as Dictionary).duplicate(true)
	return {}


func _has_enabled_game_object() -> bool:
	for game_id in _string_array(run_state.current_environment.get("game_ids", [])):
		if not library.game(game_id).is_empty():
			return true
	return false


func _economy_cue_text() -> String:
	match run_state.economy():
		"insolvent":
			return "Broke: get help fast"
		"distressed":
			return "Cash distressed: all-ins are dangerous"
		"volatile":
			return "Cash volatile: confirm all-ins"
		"growing":
			return "Bankroll growing: room to press"
		_:
			return "Cash stable: normal stakes"


func _run_pressure_view() -> Dictionary:
	if run_state == null:
		return {}
	return run_state.recovery_pressure_status(_supported_recovery_available(), _has_deferred_bankroll_zero_failure())


func _has_deferred_bankroll_zero_failure() -> bool:
	if _all_in_result_terminal_check_is_pending():
		return true
	if run_state == null or library == null or run_state.has_liquid_run_funds() or run_state.current_environment.is_empty():
		return false
	for game_id in _string_array(run_state.current_environment.get("game_ids", [])):
		var game := current_game if current_game != null and current_game.get_id() == game_id else _game_module_for_id(game_id)
		if game == null:
			continue
		var runtime_state := game.environment_runtime_state(run_state, run_state.current_environment)
		if bool(runtime_state.get("bankroll_zero_failure_deferred", false)):
			return true
	return false


func _evaluate_run_terminal_state(force: bool = false) -> Dictionary:
	if run_state == null:
		return {}
	if _all_in_result_terminal_check_is_pending() and not force:
		return {
			"failed": false,
			"terminal": false,
			"reason": RunState.FAILURE_NONE,
			"message": "Your all-in wager result is still on the table.",
			"recovery_available": true,
			"bankroll_zero_deferred": true,
		}
	if force:
		pending_all_in_result_terminal_check = false
	var result := _run_terminal_evaluator_evaluate_and_apply()
	_route_ended_run_if_needed(result)
	_route_failed_run_if_needed(result)
	return result


func _run_terminal_evaluator_evaluate_and_apply() -> Dictionary:
	terminal_evaluator_call_count += 1
	return RunTerminalEvaluatorScript.evaluate_and_apply(run_state, library)


func _all_in_result_terminal_check_is_pending() -> bool:
	return pending_all_in_result_terminal_check \
		and run_state != null \
		and run_state.run_status != RunState.RUN_STATUS_FAILED \
		and run_state.run_status != RunState.RUN_STATUS_ENDED \
		and not run_state.has_liquid_run_funds()


func _resolve_pending_all_in_terminal_result() -> bool:
	if not pending_all_in_result_terminal_check:
		return false
	if not _all_in_result_terminal_check_is_pending():
		pending_all_in_result_terminal_check = false
		return false
	_evaluate_run_terminal_state(true)
	_refresh()
	return true


func _clear_terminal_interaction_state() -> void:
	pending_all_in_result_terminal_check = false
	_reset_game_surface_runtime_state()
	current_game = null
	game_surface_ui_state = {}
	_hide_run_menu()
	_hide_event_choice_popup()
	_hide_run_inventory_popup()
	_hide_run_journal_popup()
	_hide_travel_transition()
	_clear_selected_game_action()
	_clear_selected_stake()
	_clear_selected_travel()
	_clear_selected_event_choice()
	_clear_selected_item_offer()
	_clear_selected_service_hook()
	_clear_selected_lender_hook()
	hover_target_id = ""
	focus_target_id = ""
	selected_object_id = ""
	camera_focus_rect = Rect2()
	camera_focus_point = Vector2(0.5, 0.5)
	current_context_mode = CONTEXT_MODE_ROOM
	selected_action_category = ACTION_CATEGORY_GAMES
	if environment_canvas != null:
		environment_canvas.set_selected_object("")


func _route_ended_run_if_needed(terminal_result: Dictionary = {}) -> bool:
	if run_state == null or run_state.run_status != RunState.RUN_STATUS_ENDED:
		return false
	_process_terminal_meta_bag_drops()
	_record_profile_run_result_once(terminal_result)
	_clear_terminal_interaction_state()
	_set_current_screen(SCREEN_VICTORY)
	_record_challenge_completion_if_needed()
	var message := str(terminal_result.get("message", "")).strip_edges()
	if message.is_empty():
		message = str(_run_report_outcome_snapshot().get("how", "The run is complete."))
	_show_message(message)
	return true


func _route_failed_run_if_needed(terminal_result: Dictionary = {}) -> bool:
	if run_state == null or run_state.run_status != RunState.RUN_STATUS_FAILED:
		return false
	_process_terminal_meta_bag_drops()
	_record_profile_run_result_once(terminal_result)
	_clear_terminal_interaction_state()
	_set_current_screen(SCREEN_FAILURE)
	var message := run_state.run_failure_message
	if message.strip_edges().is_empty():
		message = str(terminal_result.get("message", "The run is over."))
	_show_message(message)
	return true


func _process_terminal_meta_bag_drops() -> void:
	if run_state == null or not run_state.is_terminal():
		return
	if meta_collection_service == null or collection_drop_service == null:
		_initialize_meta_collection()
	var sal_stock: Dictionary = collection_drop_service.stock_sal_after_success(run_state, meta_collection_service)
	if bool(sal_stock.get("stocked", false)) or bool(sal_stock.get("recovered", false)):
		run_report_model_key = ""
		save_status_message = "Sal's shelf updated."
		if save_service != null:
			var receipt_save_error := save_service.save_run(run_state, autosave_slot_id)
			if receipt_save_error != OK:
				save_status_message = "Sal stocked; terminal receipt save failed."
	var tutorial_card_victory := run_state.is_tutorial_run() \
		and run_state.run_status == RunState.RUN_STATUS_ENDED \
		and str(run_state.narrative_flags.get("demo_victory_route", "")) == RunState.GRAND_CASINO_HIGH_ROLLER_EVENT_ID
	if not run_state.meta_collection_enabled_for_run() and not tutorial_card_victory:
		return
	var special_outcome: Dictionary = collection_drop_service.apply_terminal_special_outcome(run_state, meta_collection_service)
	if bool(special_outcome.get("mutated", false)):
		var special_save_error := meta_collection_service.save()
		if special_save_error == OK:
			save_status_message = "Meta collection updated."
			if tutorial_card_victory and not _copy_dict(special_outcome.get("card_reward", {})).is_empty():
				_complete_tutorial_profile()
	if not run_state.meta_collection_enabled_for_run():
		return
	if run_state.run_status == RunState.RUN_STATUS_FAILED:
		return
	if run_state.run_status == RunState.RUN_STATUS_ENDED:
		collection_drop_service.ensure_run_end_pending_bags(run_state, profile_inventory)


func claim_victory_collection_bag(marker_id: String) -> void:
	if run_state == null or run_state.run_status != RunState.RUN_STATUS_ENDED:
		return
	if meta_collection_service == null or collection_drop_service == null:
		_initialize_meta_collection()
	var result: Dictionary = collection_drop_service.flush_selected_pending_bag(run_state, meta_collection_service, marker_id)
	if bool(result.get("ok", false)):
		var save_error := meta_collection_service.save()
		if save_error == OK and not _copy_array(result.get("summary_lines", [])).is_empty():
			save_status_message = "Collection bag stored."
	_show_message(str(result.get("message", "Collection choice updated.")))
	run_report_model_key = ""
	_render_run_report()


func claim_victory_container_item(item_id: String) -> void:
	if run_state == null or run_state.run_status != RunState.RUN_STATUS_ENDED:
		return
	if not run_state.meta_collection_enabled_for_run():
		_show_message("Items cannot be brought home from this run type.")
		return
	if bool(run_state.narrative_flags.get(RunReportViewModelScript.TAKE_HOME_ITEM_EXTRACTED_FLAG, false)):
		_show_message("A container was already brought home.")
		return
	var clean_id := item_id.strip_edges()
	var choices := _victory_container_item_choices()
	var selected := {}
	for choice_value in choices:
		var choice := _copy_dict(choice_value)
		if str(choice.get("id", "")) == clean_id:
			selected = choice
			break
	if selected.is_empty():
		_show_message("That container is no longer available.")
		return
	if meta_collection_service == null:
		_initialize_meta_collection()
	var grant: Dictionary = meta_collection_service.grant_container(clean_id)
	if grant.is_empty():
		_show_message("That container cannot be brought home.")
		return
	var display_name := str(selected.get("display_name", _label_from_id(clean_id)))
	run_state.narrative_flags[RunReportViewModelScript.TAKE_HOME_ITEM_EXTRACTED_FLAG] = true
	run_state.narrative_flags[RunReportViewModelScript.TAKE_HOME_ITEM_ID_FLAG] = clean_id
	run_state.narrative_flags[RunReportViewModelScript.TAKE_HOME_ITEM_LINE_FLAG] = "Brought home %s." % display_name
	var save_error := meta_collection_service.save()
	if save_error == OK:
		save_status_message = "Container stored at home."
		if save_service != null:
			save_service.save_run(run_state, autosave_slot_id)
	_show_message("Brought home %s." % display_name)
	run_report_model_key = ""
	_render_run_report()


func _terminal_reward_selection_pending() -> bool:
	if run_state == null or run_state.run_status != RunState.RUN_STATUS_ENDED or not run_state.meta_collection_enabled_for_run():
		return false
	var bag_pending := not bool(run_state.narrative_flags.get(CollectionDropServiceScript.FLUSHED_FLAG, false)) and not run_state.pending_bag_markers().is_empty()
	var item_pending := not bool(run_state.narrative_flags.get(RunReportViewModelScript.TAKE_HOME_ITEM_EXTRACTED_FLAG, false)) and not _victory_container_item_choices().is_empty()
	return bag_pending or item_pending


func _record_profile_run_result_once(terminal_result: Dictionary = {}) -> void:
	if run_state == null or not run_state.is_terminal():
		return
	if run_state.excludes_profile_stats():
		return
	if bool(run_state.narrative_flags.get("profile_run_result_recorded", false)):
		return
	if profile_inventory == null:
		_initialize_profile_inventory()
	if run_state.run_status == RunState.RUN_STATUS_ENDED:
		var seam_payload: Dictionary = run_state.act_two_seam_payload()
		if not seam_payload.is_empty():
			profile_inventory.record_act_seam(seam_payload)
	var record_result: Dictionary = profile_inventory.record_run_result(_profile_run_result_snapshot(terminal_result))
	if not bool(record_result.get("ok", false)):
		return
	var save_error := profile_inventory.save()
	if save_error == OK:
		run_state.narrative_flags["profile_run_result_recorded"] = true
		if save_status_message.strip_edges().is_empty() or save_status_message == "Run not saved yet.":
			save_status_message = "Profile updated."


func _profile_run_result_snapshot(terminal_result: Dictionary = {}) -> Dictionary:
	if run_state == null:
		return {}
	var outcome := "victory" if run_state.run_status == RunState.RUN_STATUS_ENDED else "failure"
	var failure_reason := run_state.run_failure_reason if outcome == "failure" else ""
	var route := _profile_victory_route() if outcome == "victory" else failure_reason
	if route.strip_edges().is_empty():
		route = outcome
	var challenge_config := run_state.challenge_config.duplicate(true)
	var completion_now := Time.get_datetime_dict_from_system()
	var completion_date := "%04d-%02d-%02d" % [int(completion_now.get("year", 1970)), int(completion_now.get("month", 1)), int(completion_now.get("day", 1))]
	return {
		"seed": run_state.player_facing_seed_text(),
		"route": route,
		"outcome": outcome,
		"failure_reason": failure_reason,
		"final_bankroll": run_state.bankroll,
		"day_count": run_state.game_day(),
		"duration_actions": maxi(0, int(_copy_dict(run_state.event_cadence).get("action_index", 0))),
		"completed_date": completion_date,
		"completed_unix": int(Time.get_unix_time_from_system()),
		"challenge_mode": str(challenge_config.get("mode", "")),
		"challenge_id": str(challenge_config.get("id", "")),
		"daily_id": str(challenge_config.get("daily_id", "")),
		"score": run_state.terminal_score(),
		"bankroll_delta": run_state.bankroll - RunState.DEFAULT_BANKROLL,
		"bankroll_won": maxi(0, int(run_state.narrative_flags.get("profile_bankroll_won", maxi(0, run_state.bankroll - RunState.DEFAULT_BANKROLL)))),
		"bankroll_lost": maxi(0, int(run_state.narrative_flags.get("profile_bankroll_lost", maxi(0, RunState.DEFAULT_BANKROLL - run_state.bankroll)))),
		"biggest_single_win": maxi(0, int(run_state.narrative_flags.get("profile_biggest_single_win", 0))),
		"games_played": _copy_dict(run_state.narrative_flags.get("profile_games_played", {})),
		"terminal_message": str(terminal_result.get("message", "")),
	}


func _profile_victory_route() -> String:
	if run_state == null:
		return "victory"
	var route := str(run_state.narrative_flags.get("demo_victory_route", "")).strip_edges()
	if route == RunState.GRAND_CASINO_HIGH_ROLLER_EVENT_ID:
		return "players_card_cashout"
	if route == RunState.GRAND_CASINO_SHOWDOWN_ROUTE:
		return "showdown"
	if route.is_empty():
		return "victory"
	return route


func _record_challenge_completion_if_needed() -> void:
	if run_state == null or run_state.run_status != RunState.RUN_STATUS_ENDED:
		return
	if run_state.excludes_profile_stats():
		return
	var completion_flag := run_state.challenge_completion_flag()
	if completion_flag.is_empty():
		return
	if profile_inventory == null:
		_initialize_profile_inventory()
	if profile_inventory.has_challenge_completion(completion_flag):
		return
	var challenge_id := str(run_state.challenge_config.get("id", "")).strip_edges()
	var challenge_title := str(run_state.challenge_config.get("title", challenge_id.capitalize())).strip_edges()
	profile_inventory.mark_challenge_completed(completion_flag, challenge_id, challenge_title)
	var error := profile_inventory.save()
	if error == OK:
		save_status_message = "Challenge complete."


func _pressure_status_text(pressure: Dictionary) -> String:
	return TerminalConsequenceViewModelScript.pressure_status_text(pressure)


func _supported_recovery_available() -> bool:
	if run_state == null or library == null:
		return false
	for option in _lender_hook_view_list():
		if typeof(option) != TYPE_DICTIONARY:
			continue
		var lender_option := option as Dictionary
		if bool(lender_option.get("mutation_supported", false)) and bool(lender_option.get("enabled", false)):
			return true
	for object_data in _game_hook_interactable_objects(false):
		if typeof(object_data) == TYPE_DICTIONARY and bool((object_data as Dictionary).get("enabled", false)):
			return true
	return false


func _run_failed_without_recovery() -> bool:
	if run_state == null:
		return false
	var pressure := _run_pressure_view()
	return bool(pressure.get("failed", false)) and not bool(pressure.get("recovery_available", false))


func _risk_cue_text() -> String:
	var pit_boss := _pit_boss_watch_status()
	if bool(pit_boss.get("active", false)):
		var summary := str(pit_boss.get("summary", ""))
		var bonus := int(pit_boss.get("cheat_heat_bonus", 0))
		if bonus > 0:
			return "%s Cheating heat +%d." % [summary, bonus]
		if not summary.is_empty():
			return summary
	var suspicion_cues := _suspicion_cue_view_list()
	if not suspicion_cues.is_empty():
		return str(suspicion_cues[0])
	var security_cues := _security_cue_view_list()
	if not security_cues.is_empty():
		return str(security_cues[0])
	if run_state.suspicion_level() > 0:
		return run_state.security_pressure_summary()
	return "Quiet"


func _outcome_object_id(result: Dictionary) -> String:
	return TerminalConsequenceViewModelScript.outcome_object_id(result)


func _outcome_message(result: Dictionary) -> String:
	return TerminalConsequenceViewModelScript.outcome_message(result, Callable(self, "_player_facing_text"))


func _run_summary_text(state: RunState) -> String:
	var pressure: Dictionary = _run_pressure_view() if state == run_state else state.recovery_pressure_status()
	return TerminalConsequenceViewModelScript.run_summary_text(state, pressure)


func _run_travel_target_count(state: RunState) -> int:
	return TerminalConsequenceViewModelScript.run_travel_target_count(state)


func _game_result_from_story_log(entries: Array) -> Dictionary:
	return TerminalConsequenceViewModelScript.game_result_from_story_log(entries, Callable(self, "_game_display_name"), Callable(self, "_label_from_id"))


func _game_display_name(game_id: String) -> String:
	if library == null or game_id.is_empty():
		return "Game"
	var definition := library.game(game_id)
	return str(definition.get("display_name", _label_from_id(game_id))) if not definition.is_empty() else _label_from_id(game_id)


func _create_game_module(definition: Dictionary) -> GameModule:
	var module_path := str(definition.get("module_path", ""))
	if module_path.is_empty() or module_path.ends_with("_ui.gd") or module_path.begins_with("res://data/runtime/"):
		return null
	var module_script: Script = load(module_path)
	if module_script == null:
		return null
	var module_instance: Variant = module_script.new()
	if not module_instance is GameModule:
		return null
	var game: GameModule = module_instance
	game.setup(definition, library)
	return game


func _game_module_for_id(game_id: String) -> GameModule:
	if library == null or game_id.is_empty():
		return null
	if game_module_cache.has(game_id) and game_module_cache[game_id] is GameModule:
		return game_module_cache[game_id]
	var definition := library.game(game_id)
	if definition.is_empty():
		return null
	var game := _create_game_module(definition)
	if game != null:
		game_module_cache[game_id] = game
	return game


func _game_test_seed(game_id: String) -> String:
	var seed_text := game_test_seed_input.text.strip_edges() if game_test_seed_input != null else ""
	if seed_text.is_empty():
		seed_text = "PRACTICE"
	return "%s-%s" % [seed_text, game_id.to_upper()]


func _game_test_bankroll() -> int:
	return maxi(1, int(game_test_bankroll_input.value) if game_test_bankroll_input != null else 100000)


func _game_test_stake_floor() -> int:
	return maxi(0, int(game_test_stake_floor_input.value) if game_test_stake_floor_input != null else 1)


func _game_test_stake_ceiling() -> int:
	return maxi(1, int(game_test_stake_ceiling_input.value) if game_test_stake_ceiling_input != null else 200)


func _game_test_security_strictness() -> String:
	if game_test_security_option == null:
		return "boss"
	var selected := game_test_security_option.selected
	if selected < 0:
		return "boss"
	return str(game_test_security_option.get_item_metadata(selected))


func _game_test_generation_overrides() -> Dictionary:
	if game_test_generation_overrides_text == null:
		return {}
	var text := game_test_generation_overrides_text.text.strip_edges()
	if text.is_empty() or text == "{}":
		return {}
	var json := JSON.new()
	var error := json.parse(text)
	if error != OK:
		if game_test_status_label != null:
			game_test_status_label.text = "Generation override JSON is invalid."
		return {}
	var data: Variant = json.data
	if typeof(data) != TYPE_DICTIONARY:
		if game_test_status_label != null:
			game_test_status_label.text = "Generation override must be a JSON object."
		return {}
	return (data as Dictionary).duplicate(true)


func _deep_merge_dict(target: Dictionary, overrides: Dictionary) -> void:
	for key in overrides.keys():
		var override_value: Variant = overrides.get(key)
		if target.has(key) and typeof(target.get(key)) == TYPE_DICTIONARY and typeof(override_value) == TYPE_DICTIONARY:
			var nested: Dictionary = target.get(key)
			_deep_merge_dict(nested, override_value)
			target[key] = nested
		else:
			target[key] = override_value


func _implemented_game_ids() -> Array:
	var result: Array = []
	if library == null:
		return result
	for game_value in library.games:
		if typeof(game_value) != TYPE_DICTIONARY:
			continue
		var definition: Dictionary = game_value
		var game_id := str(definition.get("id", ""))
		var module_path := str(definition.get("module_path", ""))
		if game_id.is_empty() or module_path.is_empty():
			continue
		if module_path.ends_with("_ui.gd") or module_path.begins_with("res://data/runtime/"):
			continue
		if not ResourceLoader.exists(module_path):
			continue
		result.append(game_id)
	return result


func _game_test_environment(game_id: String, game: GameModule) -> Dictionary:
	return FoundationActionViewModelScript.game_test_environment(self, game_id, game)


func _game_test_archetype() -> Dictionary:
	var best: Dictionary = {}
	var best_score := -1
	if library == null:
		return best
	for archetype_value in library.environment_archetypes:
		if typeof(archetype_value) != TYPE_DICTIONARY:
			continue
		var archetype: Dictionary = archetype_value
		var pool_size := _string_array(archetype.get("game_pool", [])).size()
		var tier := int(archetype.get("tier", 0))
		var strictness_score := 1 if not _copy_dict(archetype.get("security_profile", {})).is_empty() else 0
		var score := pool_size * 100 + tier * 10 + strictness_score
		if score > best_score:
			best_score = score
			best = archetype.duplicate(true)
	return best


func _game_environment_hook_action_id(game: GameModule, hook_id: String) -> String:
	if game == null:
		return ""
	for hook in game.environment_interactable_objects(run_state, run_state.current_environment):
		if typeof(hook) != TYPE_DICTIONARY:
			continue
		var hook_data: Dictionary = hook
		if str(hook_data.get("id", hook_data.get("source_id", ""))) != hook_id:
			continue
		var confirm_action_id := str(hook_data.get("confirm_action_id", ""))
		if not confirm_action_id.is_empty():
			return confirm_action_id
		var actions := _copy_array(hook_data.get("available_actions", []))
		if not actions.is_empty() and typeof(actions[0]) == TYPE_DICTIONARY:
			return str((actions[0] as Dictionary).get("id", ""))
	return ""


func _game_entry_preview(game_id: String) -> Dictionary:
	return FoundationActionViewModelScript.game_entry_preview(self, game_id)


func _current_game_description() -> String:
	return FoundationActionViewModelScript.current_game_description(self)


func _cheat_action_risk_cue(actions: Variant) -> String:
	return FoundationActionViewModelScript.cheat_action_risk_cue(self, actions)


func _selected_action_summary() -> String:
	return FoundationActionViewModelScript.selected_action_summary(self)


func _game_recent_outcome_text() -> String:
	return FoundationActionViewModelScript.game_recent_outcome_text(self)


func _add_stake_controls(action_view: Dictionary) -> void:
	var surface_state := current_game.surface_state(run_state, run_state.current_environment, _current_game_surface_ui_state()) if current_game != null and run_state != null else {}
	if typeof(surface_state) == TYPE_DICTIONARY and bool((surface_state as Dictionary).get("slot_fixed_bet_ladder", false)):
		var bet_options: Array = (surface_state as Dictionary).get("bet_options", []) if typeof((surface_state as Dictionary).get("bet_options", [])) == TYPE_ARRAY else []
		actions_list.add_child(_label("Fixed slot bet", 12))
		var selected_total := int((surface_state as Dictionary).get("selected_bet_total_credits", 0))
		var locked_reason := str((surface_state as Dictionary).get("bet_locked_reason", ""))
		if not locked_reason.is_empty():
			actions_list.add_child(_muted_label("Locked: %s" % locked_reason, 11))
		else:
			actions_list.add_child(_muted_label("Spin cost is the selected cabinet bet: %d credits." % selected_total, 11))
		for option_value in bet_options:
			if typeof(option_value) != TYPE_DICTIONARY:
				continue
			var option: Dictionary = option_value
			var id := str(option.get("id", ""))
			var label := "%s  %s credits" % [str(option.get("display_tier", "")).capitalize(), str(option.get("total_credits", 0))]
			if bool(option.get("selected", false)):
				label = "Selected: %s" % label
			var button := _button(label, Callable(self, "_handle_module_surface_action").bind("select_bet_option:%s" % id, 0, true))
			button.disabled = not bool(option.get("enabled", true))
			actions_list.add_child(button)
		stake_input = null
		return
	var range := _stake_range(action_view)
	var min_stake := int(range.get("min", 1))
	var max_stake := int(range.get("max", min_stake))
	if not bool(range.get("has_valid", false)):
		actions_list.add_child(_label("No valid stake available.", 13))
		actions_list.add_child(_muted_label(run_state.economy_pressure_summary(), 12))
		return
	actions_list.add_child(_label("Stake range: %d-%d" % [min_stake, max_stake], 12))
	var recommended_max := int(range.get("recommended_max", max_stake))
	if bool(range.get("economy_pressure_applied", false)) and recommended_max < max_stake:
		actions_list.add_child(_muted_label("Economy pressure recommends stakes up to %d; all-in wagers require confirmation." % recommended_max, 12))
	else:
		actions_list.add_child(_muted_label(run_state.economy_pressure_summary(), 12))
	stake_input = SpinBox.new()
	stake_input.min_value = min_stake
	stake_input.max_value = max_stake
	stake_input.step = 1.0
	stake_input.rounded = true
	stake_input.value = _current_selected_stake(action_view)
	stake_input.custom_minimum_size = Vector2(0, MIN_NATIVE_TOUCH_TARGET_HEIGHT)
	stake_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stake_input.value_changed.connect(_on_stake_value_changed)
	actions_list.add_child(stake_input)


func _on_stake_value_changed(value: float) -> void:
	set_selected_stake(int(value))


func _refresh_stake_input() -> void:
	if stake_input == null:
		return
	var stake := _current_selected_stake()
	if int(stake_input.value) != stake:
		stake_input.set_value_no_signal(stake)


func _reset_selected_stake() -> void:
	selected_stake = _default_stake()


func _current_selected_stake(action_view: Dictionary = {}) -> int:
	var range := _stake_range(action_view)
	return _selected_stake_for_range(range)


func _selected_stake_for_range(range: Dictionary) -> int:
	if not bool(range.get("has_valid", false)):
		return 0
	if selected_stake <= 0:
		return int(range.get("default", 1))
	return clampi(selected_stake, int(range.get("min", 1)), int(range.get("max", 1)))


func _is_valid_stake(stake: int) -> bool:
	var range := _stake_range()
	return bool(range.get("has_valid", false)) and stake >= int(range.get("min", 1)) and stake <= int(range.get("max", 1))


func _stake_range(action_view: Dictionary = {}) -> Dictionary:
	return FoundationActionViewModelScript.stake_range(self, action_view)


func _stake_range_from_action_view(action_view: Dictionary = {}) -> Dictionary:
	return FoundationActionViewModelScript.stake_range_from_action_view(self, action_view)


func _add_game_action_buttons(actions: Variant, action_kind: String) -> void:
	if typeof(actions) != TYPE_ARRAY or (actions as Array).is_empty():
		actions_list.add_child(_label("None available.", 13))
		return
	for action in actions:
		if typeof(action) != TYPE_DICTIONARY:
			continue
		var action_data := action as Dictionary
		var action_id := str(action_data.get("id", ""))
		if action_id.is_empty():
			continue
		var label := _action_label(action_data)
		if action_id == selected_action_id and action_kind == selected_action_kind:
			label = "Selected: %s" % label
		actions_list.add_child(_button(label, Callable(self, "select_game_action").bind(action_id, action_kind)))
		var summary := _game_action_choice_summary(action_data, action_kind)
		if not summary.is_empty():
			var summary_label := _muted_label("Choice info: %s" % summary, 11)
			summary_label.max_lines_visible = 1
			summary_label.clip_text = true
			actions_list.add_child(summary_label)


func _game_action_view_list(action_kind: String) -> Array:
	return FoundationActionViewModelScript.game_action_view_list(self, action_kind)


func _available_game_action(action_id: String, action_kind: String) -> Dictionary:
	return FoundationActionViewModelScript.available_game_action(self, action_id, action_kind)


func _action_label(action: Dictionary) -> String:
	return FoundationActionViewModelScript.action_label(self, action)


func _action_kind_label(action_kind: String) -> String:
	return FoundationActionViewModelScript.action_kind_label(self, action_kind)


func _game_action_choice_summary(action: Dictionary, action_kind: String = "") -> String:
	return FoundationActionViewModelScript.game_action_choice_summary(self, action, action_kind)


func _clear_selected_game_action() -> void:
	selected_action_id = ""
	selected_action_kind = ""
	selected_action_label = ""
	if game_surface_canvas != null:
		game_surface_canvas.set_selected_index(-1)


func _clear_selected_stake() -> void:
	selected_stake = 0
	stake_input = null


func _eligible_event_option_view_list() -> Array:
	return FoundationActionViewModelScript.eligible_event_option_view_list(self)


func _eligible_event_option(event_id: String) -> Dictionary:
	return FoundationActionViewModelScript.eligible_event_option(self, event_id)


func _eligible_event_option_with_context(event_id: String, context: Dictionary = {}, environment_override: Dictionary = {}) -> Dictionary:
	return FoundationActionViewModelScript.eligible_event_option_with_context(self, event_id, context, environment_override)


func _event_choice(event_option: Dictionary, choice_id: String) -> Dictionary:
	return FoundationActionViewModelScript.event_choice(self, event_option, choice_id)


func _position_event_choice_popup() -> void:
	if event_choice_popup_overlay == null or event_choice_popup_panel == null:
		return
	var overlay_rect := event_choice_popup_overlay.get_global_rect()
	if overlay_rect.size.x <= 0.0 or overlay_rect.size.y <= 0.0:
		return
	var margin := 12.0
	var width := clampf(overlay_rect.size.x * 0.54, EVENT_CHOICE_POPUP_BASE_SIZE.x, EVENT_CHOICE_POPUP_MAX_SIZE.x)
	var height := clampf(overlay_rect.size.y * 0.56, EVENT_CHOICE_POPUP_BASE_SIZE.y, EVENT_CHOICE_POPUP_MAX_SIZE.y)
	if overlay_rect.size.x < 560.0:
		width = clampf(overlay_rect.size.x - margin * 2.0, 300.0, EVENT_CHOICE_POPUP_BASE_SIZE.x)
	if overlay_rect.size.y < 420.0:
		height = clampf(overlay_rect.size.y - margin * 2.0, 260.0, 380.0)
	var popup_size := Vector2(width, height)
	var global_position := Vector2(
		overlay_rect.position.x + (overlay_rect.size.x - popup_size.x) * 0.5,
		overlay_rect.position.y + (overlay_rect.size.y - popup_size.y) * 0.5
	)
	global_position.x = clampf(global_position.x, overlay_rect.position.x + margin, overlay_rect.position.x + overlay_rect.size.x - popup_size.x - margin)
	global_position.y = clampf(global_position.y, overlay_rect.position.y + margin, overlay_rect.position.y + overlay_rect.size.y - popup_size.y - margin)
	event_choice_popup_panel.position = global_position - overlay_rect.position
	event_choice_popup_panel.custom_minimum_size = popup_size
	event_choice_popup_panel.size = popup_size


func _hide_event_choice_popup(clear_snapshot: bool = true) -> void:
	if event_choice_popup_overlay != null:
		event_choice_popup_overlay.visible = false
	if event_choice_popup_choices_list != null:
		_clear(event_choice_popup_choices_list)
	if event_choice_popup_panel != null:
		event_choice_popup_panel.position = Vector2.ZERO
		event_choice_popup_panel.size = event_choice_popup_panel.custom_minimum_size
	pending_event_choice_popup_event_id = ""
	pending_event_choice_popup_focus_choice_id = ""
	pending_active_item_id = ""
	if clear_snapshot:
		pending_event_choice_popup_snapshot = {}
	_clear_pending_wager_confirmation()


func _event_choice_popup_is_visible() -> bool:
	return event_choice_popup_overlay != null and event_choice_popup_overlay.visible


func _event_choice_list_summary(choices: Array) -> String:
	return FoundationActionViewModelScript.event_choice_list_summary(self, choices)


func _event_choice_consequence_summary(choice_data: Dictionary) -> String:
	return FoundationActionViewModelScript.event_choice_consequence_summary(self, choice_data)


func _event_choice_requires_confirmation(choice_data: Dictionary) -> bool:
	return FoundationActionViewModelScript.event_choice_requires_confirmation(self, choice_data)


func _signed_int_text(value: int) -> String:
	return FoundationActionViewModelScript.signed_int_text(self, value)


func _open_run_inventory_popup(mode: String = "inspect", container_id: String = "") -> void:
	if run_inventory_screen == null:
		return
	if mode != run_inventory_popup_mode or container_id != run_inventory_context_container_id:
		selected_run_inventory_item_id = ""
		selected_run_inventory_item_source = ""
	run_inventory_popup_mode = mode
	run_inventory_context_container_id = container_id
	run_inventory_screen.open(_run_inventory_popup_model(mode, container_id))
	_sync_run_inventory_selection_from_screen()


func _render_run_inventory_popup_contents() -> void:
	if run_inventory_screen == null:
		return
	run_inventory_screen.update_model(_run_inventory_popup_model(run_inventory_popup_mode, run_inventory_context_container_id))
	_sync_run_inventory_selection_from_screen()


func select_run_inventory_item(item_id: String, source: String = "carried") -> void:
	selected_run_inventory_item_id = item_id.strip_edges()
	selected_run_inventory_item_source = source.strip_edges()
	if selected_run_inventory_item_source.is_empty():
		selected_run_inventory_item_source = "carried"
	if run_inventory_screen != null:
		run_inventory_screen.select_item(selected_run_inventory_item_id, selected_run_inventory_item_source, false)


func _on_run_inventory_screen_item_selected(item_id: String, source: String) -> void:
	selected_run_inventory_item_id = item_id.strip_edges()
	selected_run_inventory_item_source = source.strip_edges()
	if selected_run_inventory_item_source.is_empty():
		selected_run_inventory_item_source = "carried"


func _sync_run_inventory_selection_from_screen() -> void:
	if run_inventory_screen == null:
		return
	var selected: Dictionary = run_inventory_screen.selected_item_key()
	selected_run_inventory_item_id = str(selected.get("id", "")).strip_edges()
	selected_run_inventory_item_source = str(selected.get("source", "carried")).strip_edges()
	if selected_run_inventory_item_source.is_empty():
		selected_run_inventory_item_source = "carried"


func _run_inventory_popup_model(mode: String, container_id: String) -> Dictionary:
	_refresh_run_action_service()
	return RunInventoryViewModelScript.build(run_state, run_action_service, mode, container_id, {
		"id": selected_run_inventory_item_id,
		"source": selected_run_inventory_item_source,
	})


func _selected_inventory_popup_item(items: Array) -> Dictionary:
	for item_value in items:
		if typeof(item_value) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = item_value
		if str(item.get("id", "")) == selected_run_inventory_item_id and str(item.get("storage_source", "carried")) == selected_run_inventory_item_source:
			return item.duplicate(true)
	return {}


func _position_run_inventory_popup() -> void:
	if run_inventory_screen != null:
		run_inventory_screen.refresh_layout()


func _hide_run_inventory_popup() -> void:
	if run_inventory_screen != null:
		run_inventory_screen.close()
	run_inventory_popup_mode = ""
	run_inventory_context_container_id = ""
	selected_run_inventory_item_id = ""
	selected_run_inventory_item_source = ""


func _run_inventory_popup_is_visible() -> bool:
	return run_inventory_screen != null and run_inventory_screen.is_open()


func _open_run_journal_popup() -> void:
	if run_journal_overlay == null or run_journal_list == null:
		return
	_render_run_journal_contents()
	run_journal_overlay.visible = true
	run_journal_overlay.move_to_front()
	_position_run_journal_popup()
	call_deferred("_position_run_journal_popup")


func _render_run_journal_contents() -> void:
	if run_journal_list == null:
		return
	_clear(run_journal_list)
	var entries := _run_journal_entry_view_list()
	if run_journal_summary_label != null:
		run_journal_summary_label.text = _run_journal_summary_text(entries)
	if entries.is_empty():
		run_journal_list.add_child(_muted_label("No journal entries yet.", 13))
		return
	for entry_value in entries:
		if typeof(entry_value) == TYPE_DICTIONARY:
			_add_run_journal_card(entry_value as Dictionary)


func _add_run_journal_card(entry: Dictionary) -> void:
	if run_journal_list == null:
		return
	var category := str(entry.get("category", "story"))
	var border := _run_journal_category_color(category)
	var card := _panel_container(VisualStyle.DARK_2, border)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	run_journal_list.add_child(card)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(stack)

	var heading := _label("#%d %s" % [int(entry.get("index", 0)), str(entry.get("title", "Story"))], 14)
	_set_control_font_color(heading, border)
	heading.clip_text = true
	heading.max_lines_visible = 1
	stack.add_child(heading)

	var body := _label(str(entry.get("body", "")), 12)
	_set_control_font_color(body, VisualStyle.SOFT)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.max_lines_visible = 3
	stack.add_child(body)

	var detail_lines := _copy_array(entry.get("detail_lines", []))
	if detail_lines.is_empty():
		return
	var details := _label(" | ".join(detail_lines), 10)
	_set_control_font_color(details, VisualStyle.CYAN_2)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.max_lines_visible = 2
	stack.add_child(details)


func _position_run_journal_popup() -> void:
	if run_journal_overlay == null or run_journal_panel == null:
		return
	var overlay_rect := run_journal_overlay.get_global_rect()
	if overlay_rect.size.x <= 0.0 or overlay_rect.size.y <= 0.0:
		return
	var margin := 12.0
	var width := clampf(overlay_rect.size.x * 0.62, 520.0, 720.0)
	var height := clampf(overlay_rect.size.y * 0.68, 360.0, 560.0)
	if overlay_rect.size.x < 620.0:
		width = clampf(overlay_rect.size.x - margin * 2.0, 300.0, 540.0)
	if overlay_rect.size.y < 480.0:
		height = clampf(overlay_rect.size.y - margin * 2.0, 300.0, 420.0)
	var popup_size := Vector2(width, height)
	var global_position := Vector2(
		overlay_rect.position.x + (overlay_rect.size.x - popup_size.x) * 0.5,
		overlay_rect.position.y + (overlay_rect.size.y - popup_size.y) * 0.5
	)
	global_position.x = clampf(global_position.x, overlay_rect.position.x + margin, overlay_rect.position.x + overlay_rect.size.x - popup_size.x - margin)
	global_position.y = clampf(global_position.y, overlay_rect.position.y + margin, overlay_rect.position.y + overlay_rect.size.y - popup_size.y - margin)
	run_journal_panel.position = global_position - overlay_rect.position
	run_journal_panel.size = popup_size


func _hide_run_journal_popup() -> void:
	if run_journal_overlay != null:
		run_journal_overlay.visible = false
	if run_journal_list != null:
		_clear(run_journal_list)
	if run_journal_panel != null:
		run_journal_panel.position = Vector2.ZERO
		run_journal_panel.size = run_journal_panel.custom_minimum_size


func _run_journal_popup_is_visible() -> bool:
	return run_journal_overlay != null and run_journal_overlay.visible


func _run_journal_entry_view_list() -> Array:
	return RunJournalViewModelScript.entry_view_list(run_state, _run_journal_callbacks())


func _run_journal_summary_text(entries: Array) -> String:
	return RunJournalViewModelScript.summary_text(entries)


func _run_journal_category_color(category: String) -> Color:
	return RunJournalViewModelScript.category_color(category)


func _run_journal_callbacks() -> Dictionary:
	return {
		"label_from_id": Callable(self, "_label_from_id"),
		"story_entry_label": Callable(self, "_story_entry_label"),
		"player_facing_text": Callable(self, "_player_facing_text"),
		"game_display_name": Callable(self, "_game_display_name"),
		"failure_summary_snapshot": Callable(self, "_run_report_outcome_snapshot"),
	}


func _show_item_found_popups(result: Dictionary, inventory_before: Dictionary) -> void:
	if item_found_popup == null or library == null or run_state == null or not bool(result.get("ok", false)):
		return
	var deltas: Dictionary = result.get("deltas", {}) if typeof(result.get("deltas", {})) == TYPE_DICTIONARY else {}
	var inventory_add: Array = deltas.get("inventory_add", []) if typeof(deltas.get("inventory_add", [])) == TYPE_ARRAY else []
	if inventory_add.is_empty():
		return
	var inventory_after := _run_inventory_id_set()
	var shown := {}
	for item_value in inventory_add:
		var item_id := _inventory_value_id(item_value)
		if item_id.is_empty() or shown.has(item_id) or inventory_before.has(item_id) or not inventory_after.has(item_id):
			continue
		shown[item_id] = true
		var definition := library.item(item_id)
		if definition.is_empty():
			definition = {
				"id": item_id,
				"display_name": item_id.replace("_", " ").capitalize(),
			}
		var asset_path := str(definition.get("asset_path", "")).strip_edges()
		item_found_popup.show_item(definition, _texture_for_image_asset_path(asset_path))


func _run_inventory_id_set() -> Dictionary:
	var result := {}
	if run_state == null:
		return result
	for item_value in run_state.inventory:
		var item_id := _inventory_value_id(item_value)
		if not item_id.is_empty():
			result[item_id] = true
	return result


func _inventory_value_id(value: Variant) -> String:
	if typeof(value) == TYPE_DICTIONARY:
		return str((value as Dictionary).get("id", "")).strip_edges()
	return str(value).strip_edges()


func _inventory_item_view_list() -> Array:
	_refresh_run_action_service()
	return run_action_service.inventory_item_view_list()


func _held_container_item_options() -> Array:
	var result: Array = []
	if run_state == null or library == null:
		return result
	for item_id in _string_array(run_state.inventory):
		var option := _container_item_option(item_id)
		if not option.is_empty():
			result.append(option)
	return result


func _container_item_option(item_id: String) -> Dictionary:
	var clean_id := item_id.strip_edges()
	if clean_id.is_empty() or library == null:
		return {}
	var definition := library.item(clean_id)
	if definition.is_empty():
		return {}
	var effect: Dictionary = definition.get("effect", {}) if typeof(definition.get("effect", {})) == TYPE_DICTIONARY else {}
	var capacity := maxi(0, int(definition.get("container_capacity", 0)))
	capacity = maxi(capacity, int(effect.get("container_capacity", 0)))
	var item_class := str(definition.get("class", "")).strip_edges().to_lower()
	if item_class != "container" and capacity <= 0:
		return {}
	return {
		"id": clean_id,
		"display_name": str(definition.get("display_name", clean_id.replace("_", " ").capitalize())),
		"capacity": capacity,
		"description": str(definition.get("description", "")),
	}


func _storable_inventory_item_ids() -> Array:
	var result: Array = []
	if run_state == null:
		return result
	for item_id in _string_array(run_state.inventory):
		if _container_item_option(item_id).is_empty():
			result.append(item_id)
	return result


func _home_container_by_id(container_id: String) -> Dictionary:
	if run_state == null:
		return {}
	for container_value in run_state.current_home_containers():
		if typeof(container_value) != TYPE_DICTIONARY:
			continue
		var container: Dictionary = container_value
		if str(container.get("id", "")) == container_id:
			return container.duplicate(true)
	return {}


func _home_container_contents_summary(container: Dictionary) -> String:
	var items := _string_array(container.get("items", []))
	if items.is_empty():
		return "Empty."
	var labels: Array = []
	for item_id in items.slice(0, 3):
		labels.append(_inventory_item_label(str(item_id)))
	if items.size() > labels.size():
		labels.append("+%d more" % (items.size() - labels.size()))
	return "Contains: %s" % ", ".join(labels)


func _inventory_item_label(item_id: String) -> String:
	if library == null:
		return item_id.replace("_", " ").capitalize()
	var definition := library.item(item_id)
	if definition.is_empty():
		_refresh_run_action_service()
		var runtime_detail := run_action_service.inventory_item_detail(item_id) if run_action_service != null else {}
		if not runtime_detail.is_empty():
			return str(runtime_detail.get("display_name", item_id.replace("_", " ").capitalize()))
	if definition.is_empty():
		return item_id.replace("_", " ").capitalize()
	return str(definition.get("display_name", item_id.replace("_", " ").capitalize()))


func _refresh_active_item_slot() -> void:
	if active_item_button == null:
		return
	if run_state == null:
		active_item_button.text = "Active: Empty"
		active_item_button.icon = null
		active_item_button.tooltip_text = "No active run."
		return
	_refresh_run_action_service()
	var item := run_action_service.active_item_detail()
	if item.is_empty():
		active_item_button.text = "Active: Empty"
		active_item_button.icon = null
		active_item_button.tooltip_text = "Open inventory to choose an active item."
		return
	var display_name := str(item.get("display_name", item.get("id", "Item")))
	active_item_button.text = display_name.left(18)
	active_item_button.tooltip_text = str(item.get("description", "Use active item."))
	active_item_button.icon = _run_item_texture_for_asset_path(str(item.get("asset_path", "")))


func _item_sale_price(item_definition: Dictionary) -> int:
	_refresh_run_action_service()
	return run_action_service.item_sale_price(item_definition)


func _shopkeeper_available() -> bool:
	_refresh_run_action_service()
	return run_action_service.shopkeeper_available()


func _shopkeeper_should_draw() -> bool:
	if run_state == null:
		return false
	if _shopkeeper_available():
		return true
	if str(run_state.current_environment.get("kind", "")) == "shop":
		return true
	return _object_fixture_declared("shopkeeper:merchant")


func _object_fixture_declared(object_id: String) -> bool:
	if run_state == null or object_id.is_empty():
		return false
	for fixture_id in _string_array(run_state.current_environment.get("object_fixtures", [])):
		if fixture_id == object_id:
			return true
	return false


func _shopkeeper_label() -> String:
	_refresh_run_action_service()
	return run_action_service.shopkeeper_label()


func _shop_description() -> String:
	_refresh_run_action_service()
	return run_action_service.shop_description()


func _run_inventory_interaction_kind(mode: String) -> String:
	match mode:
		"merchant_sale":
			return "merchant_sale"
		"pawn_counter":
			return "pawn_counter"
		"place_container":
			return "home_storage"
		"home_container":
			return "home_container"
		_:
			return "inventory"


func _clear_selected_event_choice() -> void:
	selected_event_id = ""
	selected_event_choice_id = ""
	selected_event_label = ""
	selected_event_choice_label = ""


func _item_offer_view_list() -> Array:
	_refresh_run_action_service()
	return run_action_service.item_offer_view_list(selected_item_offer_id)


func _item_offer(item_id: String) -> Dictionary:
	_refresh_run_action_service()
	return run_action_service.item_offer(item_id, selected_item_offer_id)


func _effect_summary(effect: Dictionary) -> String:
	_refresh_run_action_service()
	return run_action_service.effect_summary(effect)


func _label_from_id(id: String) -> String:
	_refresh_run_action_service()
	if run_action_service != null:
		return run_action_service.label_from_id(id)
	return id.replace("_", " ").capitalize()


func _clear_selected_item_offer() -> void:
	selected_item_offer_id = ""
	selected_item_offer_label = ""
	selected_item_offer_price = 0


func _service_hook_view_list() -> Array:
	_refresh_run_action_service()
	return run_action_service.service_hook_view_list(selected_service_hook_id)


func _lender_hook_view_list() -> Array:
	_refresh_run_action_service()
	return run_action_service.lender_hook_view_list(selected_lender_hook_id)


func _service_hook(service_id: String) -> Dictionary:
	_refresh_run_action_service()
	return run_action_service.service_hook(service_id, selected_service_hook_id)


func _lender_hook(lender_id: String) -> Dictionary:
	_refresh_run_action_service()
	return run_action_service.lender_hook(lender_id, selected_lender_hook_id)


func _lender_is_pawn_counter(lender_id: String) -> bool:
	_refresh_run_action_service()
	var definition := run_action_service.hook_definition("lender", lender_id)
	return not definition.is_empty() and str(definition.get("lender_type", "")) == "pawn"


func _first_current_pawn_lender_id() -> String:
	if not selected_lender_hook_id.is_empty() and _lender_is_pawn_counter(selected_lender_hook_id):
		return selected_lender_hook_id
	var lender_values: Array = []
	if run_state != null:
		lender_values = _copy_array(run_state.current_environment.get("lender_hooks", []))
	for lender_value in lender_values:
		var lender_id := str(lender_value)
		if _lender_is_pawn_counter(lender_id):
			return lender_id
	return ""


func _clear_selected_service_hook() -> void:
	selected_service_hook_id = ""
	selected_service_hook_label = ""


func _clear_selected_lender_hook() -> void:
	selected_lender_hook_id = ""
	selected_lender_hook_label = ""


func _refresh_world_map_overlay() -> void:
	if world_map_overlay == null or not world_map_overlay.visible:
		return
	_ensure_world_map_overlay_controller()
	var snapshot := _world_map_snapshot()
	if run_state != null and run_state.has_world_map() and not selected_world_map_node_id.is_empty() and not _world_map_node_ids(snapshot).has(selected_world_map_node_id):
		selected_world_map_node_id = ""
		selected_travel_target_id = ""
		selected_travel_label = ""
		world_map_snapshot_cache_key = ""
		snapshot = _world_map_snapshot()
	world_map_overlay_controller.sync_canvas_snapshot(snapshot, world_map_snapshot_cache_key)
	_sync_world_map_overlay_controller_to_host()
	world_map_overlay_controller.sync_node_buttons(snapshot)
	var current_label := str(run_state.current_environment.get("display_name", "Current room")) if run_state != null else "Current room"
	world_map_overlay_controller.apply_title(_world_map_title_text(current_label))
	_refresh_world_map_detail()
	_position_world_map_detail_popup(snapshot)


func _on_world_map_canvas_layout_changed() -> void:
	if world_map_overlay == null or not world_map_overlay.visible:
		return
	_request_world_map_button_relayout()


func _request_world_map_button_relayout() -> void:
	_ensure_world_map_overlay_controller()
	world_map_overlay_controller.reset_button_layout()
	if world_map_button_relayout_deferred:
		return
	world_map_button_relayout_deferred = true
	call_deferred("_refresh_world_map_overlay_after_layout")


func _refresh_world_map_overlay_after_layout() -> void:
	world_map_button_relayout_deferred = false
	if world_map_overlay == null or not world_map_overlay.visible:
		return
	_ensure_world_map_overlay_controller()
	world_map_overlay_controller.reset_button_layout()
	_refresh_world_map_overlay()


func _world_map_node_ids(snapshot: Dictionary) -> Array:
	_ensure_world_map_overlay_controller()
	return world_map_overlay_controller.node_ids(snapshot)


func _world_map_title_text(current_label: String) -> String:
	if run_state == null:
		return "World Map"
	return "World Map | Day %d %s | Here: %s" % [
		run_state.game_day(),
		run_state.clock_display_text(),
		current_label,
	]


func _position_world_map_detail_popup(snapshot: Dictionary) -> void:
	_ensure_world_map_overlay_controller()
	world_map_overlay_controller.position_detail_popup(snapshot)


func _refresh_world_map_detail() -> void:
	if world_map_detail_label == null or run_state == null:
		return
	if _is_meta_session():
		_refresh_meta_world_map_detail()
		return
	var lock_remaining := run_state.current_travel_lock_remaining()
	var lines: Array = []
	if lock_remaining > 0:
		lines.append("Locked: %s" % str(run_state.travel_route_status({}).get("disabled_reason", "Travel is locked for now.")))
	if selected_world_map_node_id.is_empty():
		lines.append("Select a revealed stop.")
		_set_world_map_confirm_enabled(false)
		_set_world_map_detail_badges([])
		world_map_detail_label.text = "\n".join(lines)
		return
	var current_id := run_state.current_world_node_id()
	var node: Dictionary = WorldMapScript.node_by_id(run_state.world_map, selected_world_map_node_id)
	if node.is_empty() or not WorldMapScript.is_node_visible(run_state.world_map, selected_world_map_node_id):
		lines.append("That stop is not visible from here.")
		_set_world_map_confirm_enabled(false)
		_set_world_map_detail_badges([])
		world_map_detail_label.text = "\n".join(lines)
		return
	var choice := _travel_choice(selected_world_map_node_id)
	lines.append("Stop: %s" % str(node.get("label", selected_world_map_node_id)))
	var node_archetype := _environment_archetype(str(node.get("archetype_id", selected_world_map_node_id)))
	var destination_kind := str(node_archetype.get("kind", node.get("kind", "")))
	var status_text := EnvironmentHours.travel_status_text(node_archetype, run_state.game_minute_of_day())
	if bool(choice.get("locked", false)):
		lines.append("Hours: %s" % str(choice.get("open_status_text", status_text)))
		lines.append(_world_map_travel_cost_line(choice))
		var locked_blocks := int(choice.get("distance_blocks", 0))
		var locked_distance := str(choice.get("distance", "near")).capitalize()
		if locked_blocks > 0:
			locked_distance = "%s / %d block%s" % [locked_distance, locked_blocks, "" if locked_blocks == 1 else "s"]
		lines.append("Distance: %s" % locked_distance)
		lines.append("Locked: %s" % str(choice.get("disabled_reason", "That route is not available right now.")))
		_set_world_map_confirm_enabled(false)
		_set_world_map_detail_badges(AttributeBadgesScript.for_world_map_detail(destination_kind, choice))
		world_map_detail_label.text = "\n".join(lines)
		return
	if selected_world_map_node_id == current_id:
		lines.append("Status: You are here.")
		lines.append("Hours: %s" % status_text)
		_set_world_map_confirm_enabled(false)
		_set_world_map_detail_badges(AttributeBadgesScript.for_world_map_detail(destination_kind))
		world_map_detail_label.text = "\n".join(lines)
		return
	if choice.is_empty():
		var path := WorldMapScript.path_between(run_state.world_map, current_id, selected_world_map_node_id, true)
		lines.append("Hours: %s" % status_text)
		lines.append("Travel: Unavailable from here · Cost: Not available")
		lines.append("Distance: Not available")
		if path.size() >= 2:
			lines.append("Status: Not on the current route list.")
		else:
			lines.append("Status: No known path from here.")
		_set_world_map_confirm_enabled(false)
		_set_world_map_detail_badges(AttributeBadgesScript.for_world_map_detail(destination_kind))
		world_map_detail_label.text = "\n".join(lines)
		return
	status_text = str(choice.get("open_status_text", status_text))
	lines.append("Hours: %s" % status_text)
	lines.append(_world_map_travel_cost_line(choice))
	var distance_blocks := int(choice.get("distance_blocks", 0))
	var distance_text := str(choice.get("distance", "near")).capitalize()
	if distance_blocks > 0:
		distance_text = "%s / %d block%s" % [distance_text, distance_blocks, "" if distance_blocks == 1 else "s"]
	lines.append("Distance: %s" % distance_text)
	var unlock_summary := str(choice.get("unlock_summary", "")).strip_edges()
	if not bool(choice.get("enabled", true)) and not unlock_summary.is_empty():
		lines.append("Status: %s" % unlock_summary)
	elif bool(choice.get("enabled", true)):
		lines.append("Status: Route open.")
	else:
		lines.append("Status: %s" % str(choice.get("disabled_reason", "That route is not available right now.")))
	_set_world_map_detail_badges(AttributeBadgesScript.for_world_map_detail(destination_kind, choice))
	_set_world_map_confirm_enabled(bool(choice.get("enabled", true)))
	world_map_detail_label.text = "\n".join(lines)


func _set_world_map_detail_badges(badges_value: Variant) -> void:
	_ensure_world_map_overlay_controller()
	world_map_overlay_controller.set_detail_badges(badges_value)


func _ensure_world_map_detail_badge_pool() -> void:
	_ensure_world_map_overlay_controller()
	world_map_overlay_controller.set_detail_badges([])


func _update_world_map_detail_badge_cells(badges: Array) -> void:
	_set_world_map_detail_badges(badges)


func _world_map_detail_badge_prewarm_sample() -> Array:
	_ensure_world_map_overlay_controller()
	return world_map_overlay_controller.detail_badge_prewarm_sample()


func _on_world_map_holder_gui_input(event: InputEvent) -> void:
	_ensure_world_map_overlay_controller()
	_sync_world_map_overlay_controller_from_host()
	if world_map_overlay_controller.handle_holder_gui_input(event):
		_sync_world_map_overlay_controller_to_host()
		_refresh_world_map_overlay()
		accept_event()


func _world_map_node_flavor(node: Dictionary) -> String:
	var flavor := str(node.get("flavor", "")).strip_edges()
	if not flavor.is_empty():
		return flavor
	var archetype := _environment_archetype(str(node.get("archetype_id", node.get("id", ""))))
	var visual_context: Dictionary = archetype.get("visual_context", {}) if typeof(archetype.get("visual_context", {})) == TYPE_DICTIONARY else {}
	flavor = str(visual_context.get("description", "")).strip_edges()
	if not flavor.is_empty():
		return flavor
	var kind := str(node.get("kind", archetype.get("kind", ""))).strip_edges()
	return "A %s stop on the city map." % kind if not kind.is_empty() else ""


func _world_map_travel_method(choice: Dictionary) -> String:
	return WorldMapScript.travel_method_label(_world_map_travel_method_kind(choice))


func _world_map_travel_method_kind(choice: Dictionary) -> String:
	if bool(choice.get("force_walk_fallback", false)):
		return WorldMapScript.TRAVEL_METHOD_WALK
	var authored_kind: Variant = choice.get("travel_method_kind")
	if typeof(authored_kind) == TYPE_STRING and not (authored_kind as String).is_empty():
		return authored_kind as String
	var route_value: Variant = choice.get("route")
	var route: Dictionary = route_value if typeof(route_value) == TYPE_DICTIONARY else {}
	if not route.is_empty():
		return WorldMapScript.travel_method_kind(route, str(choice.get("distance", route.get("distance", "near"))))
	return WorldMapScript.travel_method_kind(choice, str(choice.get("distance", "near")))


func _world_map_travel_cost_line(choice: Dictionary) -> String:
	return "Travel: %s · Cost: $%d" % [_world_map_travel_method(choice), maxi(0, int(choice.get("cost", 0)))]


func _meta_map_node_ids() -> Array:
	_ensure_meta_session_controller()
	return meta_session_controller.map_node_ids()


func _meta_travel_target_ids() -> Array:
	_ensure_meta_session_controller()
	return meta_session_controller.travel_target_ids(meta_session_location_id)


func _meta_travel_choice(target_id: String) -> Dictionary:
	_ensure_meta_session_controller()
	return meta_session_controller.travel_choice(target_id, meta_session_location_id)


func _meta_world_map_snapshot() -> Dictionary:
	_ensure_meta_session_controller()
	return meta_session_controller.world_map_snapshot(meta_session_location_id, selected_world_map_node_id)


func _meta_world_map_node(node_id: String, position: Vector2, selected_id: String) -> Dictionary:
	_ensure_meta_session_controller()
	var snapshot := meta_session_controller.world_map_snapshot(meta_session_location_id, selected_id)
	for node_value in _copy_array(snapshot.get("nodes", [])):
		if typeof(node_value) == TYPE_DICTIONARY and str((node_value as Dictionary).get("id", "")) == node_id:
			return (node_value as Dictionary).duplicate(true)
	return {}


func _meta_archetype_id_for_location(node_id: String) -> String:
	_ensure_meta_session_controller()
	return meta_session_controller.archetype_id_for_location(node_id)


func _meta_map_icon_archetype_id(node_id: String) -> String:
	_ensure_meta_session_controller()
	return meta_session_controller.map_icon_archetype_id(node_id)


func _refresh_meta_world_map_detail() -> void:
	_ensure_meta_session_controller()
	var detail := meta_session_controller.world_map_detail_view(meta_session_location_id, selected_world_map_node_id)
	_set_world_map_confirm_enabled(bool(detail.get("confirm_enabled", false)))
	_set_world_map_detail_badges(_copy_array(detail.get("badges", [])))
	world_map_detail_label.text = str(detail.get("text", ""))


func _set_world_map_confirm_enabled(enabled: bool) -> void:
	if world_map_confirm_button == null:
		return
	world_map_confirm_button.disabled = not enabled


func _world_map_snapshot() -> Dictionary:
	return FoundationTravelViewModelScript.world_map_snapshot(self)


func _enriched_world_map_snapshot(snapshot: Dictionary) -> Dictionary:
	return FoundationTravelViewModelScript.enriched_world_map_snapshot(self, snapshot)


func _world_map_node_should_render(node: Dictionary, is_current: bool, is_available_target: bool) -> bool:
	return FoundationTravelViewModelScript.world_map_node_should_render(self, node, is_current, is_available_target)


func _world_route_for_target(target_id: String) -> Dictionary:
	return FoundationTravelViewModelScript.world_route_for_target(self, target_id)


func _travel_choice_view_list() -> Array:
	return FoundationTravelViewModelScript.travel_choice_view_list(self)


func _travel_choice(target_id: String, known_target_ids: Array = []) -> Dictionary:
	var choice: Dictionary = FoundationTravelViewModelScript.travel_choice(self, target_id, known_target_ids)
	if choice.is_empty():
		return choice
	var method_kind := _world_map_travel_method_kind(choice)
	# FoundationTravelViewModel already gives this choice its own route duplicate.
	var route_value: Variant = choice.get("route")
	var route: Dictionary = route_value if typeof(route_value) == TYPE_DICTIONARY else {}
	var method_label := WorldMapScript.travel_method_label(method_kind)
	route["travel_method_kind"] = method_kind
	route["travel_method"] = method_label
	if str(route.get("method", "")).strip_edges().is_empty() or bool(choice.get("force_walk_fallback", false)):
		route["method"] = method_label
	choice["route"] = route
	choice["travel_method_kind"] = method_kind
	choice["travel_method"] = method_label
	return choice


func _travel_target_ids() -> Array:
	return FoundationTravelViewModelScript.travel_target_ids(self)


func _travel_base_cache_key() -> String:
	return FoundationTravelViewModelScript.travel_base_cache_key(self)


func _invalidate_travel_view_cache() -> void:
	FoundationTravelViewModelScript.invalidate_travel_view_cache(self)


func _enabled_world_route_ids(source_id: String) -> Array:
	return FoundationTravelViewModelScript.enabled_world_route_ids(self, source_id)


func _current_environment_archetype() -> Dictionary:
	return FoundationTravelViewModelScript.current_environment_archetype(self)


func _environment_open_status(archetype: Dictionary) -> Dictionary:
	return FoundationTravelViewModelScript.environment_open_status(self, archetype)


func _environment_open_status_at(archetype: Dictionary, minute_of_day: int) -> Dictionary:
	return FoundationTravelViewModelScript.environment_open_status_at(self, archetype, minute_of_day)


func _travel_clock_minutes_for_route(route: Dictionary, force_walk: bool = false) -> int:
	return FoundationTravelViewModelScript.travel_clock_minutes_for_route(self, route, force_walk)


func _arrival_minute_for_route(route: Dictionary, force_walk: bool = false) -> int:
	return FoundationTravelViewModelScript.arrival_minute_for_route(self, route, force_walk)


func _environment_archetype(archetype_id: String) -> Dictionary:
	return FoundationTravelViewModelScript.environment_archetype(self, archetype_id)


func _travel_label_from_archetype(archetype: Dictionary, fallback_id: String) -> String:
	return FoundationTravelViewModelScript.travel_label_from_archetype(self, archetype, fallback_id)


func _travel_full_preview_enabled() -> bool:
	return FoundationTravelViewModelScript.travel_full_preview_enabled(self)


func _travel_full_preview_enabled_for(target_id: String) -> bool:
	return FoundationTravelViewModelScript.travel_full_preview_enabled_for(self, target_id)


func _travel_preview_summary(choice: Dictionary) -> String:
	return FoundationTravelViewModelScript.travel_preview_summary(self, choice)


func _travel_risk_summary(choice: Dictionary) -> String:
	return FoundationTravelViewModelScript.travel_risk_summary(self, choice)


func _closing_time_walk_fallback_target_id() -> String:
	return FoundationTravelViewModelScript.closing_time_walk_fallback_target_id(self)


func _clear_selected_travel() -> void:
	selected_travel_target_id = ""
	selected_travel_label = ""
	selected_world_map_node_id = ""


func _panel_container(fill: Color, border: Color) -> PanelContainer:
	return FoundationWidgetsScript.panel_container(fill, border)


func _panel(fill: Color, border: Color) -> Panel:
	return FoundationWidgetsScript.panel(fill, border)


func _surface_panel_style() -> StyleBoxFlat:
	var style := VisualStyle.pixel_box(VisualStyle.DARK_2, VisualStyle.CYAN_2, 1)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style


func _begin_action_card(title: String, border: Color = VisualStyle.CYAN_2) -> VBoxContainer:
	var panel := _panel_container(VisualStyle.DARK_2, border)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions_list.add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 5)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(stack)
	var title_label := _label(title, 14)
	_set_control_font_color(title_label, border)
	stack.add_child(title_label)
	return stack


func _add_detail_row(stack: VBoxContainer, label_text: String, value_text: String, muted: bool = false) -> void:
	FoundationWidgetsScript.add_detail_row(stack, label_text, value_text, muted)


func _add_card_button(stack: VBoxContainer, text: String, callback: Callable, disabled: bool = false, primary: bool = false) -> Button:
	return FoundationWidgetsScript.add_card_button(stack, text, callback, disabled, primary)


func _accessible_font_size(base_size: int) -> int:
	return maxi(8, int(round(float(base_size) * _accessibility_font_scale())))


func _set_control_font_size(control: Control, base_size: int) -> void:
	FoundationWidgetsScript.set_control_font_size(control, _accessible_font_size(base_size))
	control.set_meta(ACCESSIBILITY_BASE_FONT_META, base_size)


func _set_control_font_color(control: Control, color: Color) -> void:
	FoundationWidgetsScript.set_control_font_color(control, color)


func _accessibility_font_scale() -> float:
	if user_settings == null:
		return 1.0
	var scale := clampf(user_settings.text_scale() * user_settings.ui_scale, 0.86, 1.35)
	if user_settings.play_on_small_screen:
		scale = minf(1.5, scale * SmallScreenPolicyScript.FONT_SCALE)
	return scale


func _accessibility_control_scale() -> float:
	if user_settings == null:
		return 1.0
	var scale := clampf(user_settings.ui_scale, 0.90, 1.18)
	if user_settings.play_on_small_screen:
		scale = maxf(scale, SmallScreenPolicyScript.CONTROL_SCALE)
	return scale


func _small_screen_enabled() -> bool:
	return user_settings != null and user_settings.play_on_small_screen


func _refresh_coach_at_boundary() -> void:
	if coach_overlay == null or run_state == null or current_screen == SCREEN_START:
		return
	coach_overlay.evaluate_at_boundary(_coach_context_snapshot())


func _coach_context_snapshot() -> Dictionary:
	var environment := run_state.current_environment if run_state != null else {}
	var archetype_id := str(environment.get("archetype_id", ""))
	var archetype := library.environment_archetype(archetype_id) if library != null else {}
	var objective := run_state.demo_objective_status() if run_state != null else {}
	var starter_card_count := _starter_card_count()
	var result_type := str(last_item_result.get("type", ""))
	if result_type.is_empty():
		result_type = str(last_hook_result.get("type", last_game_result.get("type", "")))
	return {
		"screen": current_screen,
		"environment_kind": str(environment.get("kind", archetype.get("kind", ""))),
		"environment_archetype": archetype_id,
		"game_id": current_game.get_id() if current_game != null else "",
		"run": {
			"challenge_id": str(run_state.challenge_config.get("id", "")) if run_state != null else "",
			"tutorial": run_state.is_tutorial_run() if run_state != null else false,
			"heat": run_state.suspicion_level() if run_state != null else 0,
			"inventory_count": run_state.inventory.size() if run_state != null else 0,
			"tutorial_friendly_choice_done": bool(run_state.narrative_flags.get("tutorial_friendly_choice_done", false)) if run_state != null else false,
			"tutorial_invited": TutorialFlowScript.invitation_received(run_state),
			"heat_gain_count": _coach_heat_gain_count(),
			"debt_count": run_state.debt.size() if run_state != null else 0,
			"closing_time_active": run_state.closing_time_active() if run_state != null else false,
			"grand_casino_chips": run_state.grand_casino_chips if run_state != null else 0,
			"players_card_tier": str(objective.get("players_card_tier", "none")),
			"high_roller_ready": bool(objective.get("high_roller_ready", false)),
		},
		"ui": {
			"pawn_counter_open": _run_inventory_popup_is_visible() and run_inventory_popup_mode == "pawn_counter",
			"world_map_open": _world_map_overlay_is_visible(),
			"cage_counter_talking": not run_state.pending_talk_event("dialogue:linda_cage_services").is_empty() if run_state != null else false,
		},
		"meta": {
			"home": _is_meta_session() and meta_session_location_id == META_LOCATION_HOME,
			"starter_card_count": starter_card_count,
		},
		"action": {"last_result_type": result_type},
		"viewport_rect": Rect2(Vector2.ZERO, size),
		"anchor_rects": _coach_anchor_rects(),
		"reduce_motion": _reduce_motion_enabled(),
		"small_screen": _small_screen_enabled(),
	}


func _starter_card_count() -> int:
	if meta_collection_service == null:
		return 0
	var count := 0
	for instance_value in _copy_array(meta_collection_service.snapshot().get("owned_instances", [])):
		var instance := _copy_dict(instance_value)
		var stamp := _copy_dict(instance.get("instance_data", {}))
		if bool(stamp.get("starter_card", false)):
			count += 1
	return count


func _coach_anchor_rects() -> Dictionary:
	var hud: Dictionary = {}
	_coach_store_control_rect(hud, "heat", status_label)
	_coach_store_control_rect(hud, "debt", status_label)
	_coach_store_control_rect(hud, "clock", status_label)
	_coach_store_control_rect(hud, "chips", status_label)
	_coach_store_control_rect(hud, "objective", objective_label)
	_coach_store_control_rect(hud, "inventory", top_inventory_button)
	_coach_store_control_rect(hud, "map", world_map_title_label if _world_map_overlay_is_visible() else title_label)
	var objects: Dictionary = {}
	if environment_canvas != null:
		var canvas_rect := environment_canvas.get_global_rect()
		for object_value in _interactable_object_view_list():
			if typeof(object_value) != TYPE_DICTIONARY:
				continue
			var object_data: Dictionary = object_value
			var normalized_rect := _rect_from_dict(object_data.get("focus_rect", {}))
			if normalized_rect.size.x <= 0.0 or normalized_rect.size.y <= 0.0:
				continue
			objects[str(object_data.get("object_id", ""))] = Rect2(canvas_rect.position + normalized_rect.position * canvas_rect.size, normalized_rect.size * canvas_rect.size)
	var surface_actions: Dictionary = {}
	if game_surface_canvas != null:
		var surface_origin := game_surface_canvas.get_global_rect().position
		for region_value in game_surface_canvas.hit_regions:
			if typeof(region_value) != TYPE_DICTIONARY:
				continue
			var region: Dictionary = region_value
			var action_id := str(region.get("action", "")).strip_edges()
			var local_rect: Rect2 = region.get("rect", Rect2()) if typeof(region.get("rect", Rect2())) == TYPE_RECT2 else Rect2()
			if not action_id.is_empty() and local_rect.has_area() and not surface_actions.has(action_id):
				surface_actions[action_id] = Rect2(surface_origin + local_rect.position, local_rect.size)
	return {"hud_elements": hud, "interactable_objects": objects, "surface_actions": surface_actions}


func _coach_store_control_rect(target: Dictionary, key: String, control: Control) -> void:
	if control != null and control.is_visible_in_tree():
		target[key] = control.get_global_rect()


func _coach_heat_gain_count() -> int:
	if run_state == null:
		return 0
	var gains := 0
	var previous := 0
	var has_previous := false
	for entry_value in run_state.heat_history:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var heat := int((entry_value as Dictionary).get("heat_value", 0))
		if has_previous and heat > previous:
			gains += 1
		previous = heat
		has_previous = true
	return gains


func _apply_accessibility_settings() -> void:
	if user_settings != null:
		VisualStyle.set_high_contrast_enabled(user_settings.high_contrast)
	var small_screen_enabled := _small_screen_enabled()
	if settings_margin != null:
		var side_margin := SmallScreenPolicyScript.SETTINGS_SIDE_MARGIN if small_screen_enabled else 220
		settings_margin.add_theme_constant_override("margin_left", side_margin)
		settings_margin.add_theme_constant_override("margin_right", side_margin)
	if talk_dock != null:
		talk_dock.set_reduce_motion(bool(user_settings.reduce_motion) if user_settings != null else false)
		talk_dock.set_small_screen_mode(small_screen_enabled)
	if coach_overlay != null:
		coach_overlay.set_reduce_motion(bool(user_settings.reduce_motion) if user_settings != null else false)
		coach_overlay.set_small_screen_mode(small_screen_enabled)
	if environment_canvas != null:
		environment_canvas.set_small_screen_mode(small_screen_enabled)
	if game_surface_canvas != null:
		game_surface_canvas.set_small_screen_mode(small_screen_enabled)
	if run_inventory_screen != null:
		run_inventory_screen.set_reduced_motion(bool(user_settings.reduce_motion) if user_settings != null else false)
		run_inventory_screen.set_small_screen_mode(small_screen_enabled)
	if meta_item_interaction_screen != null:
		meta_item_interaction_screen.set_reduced_motion(bool(user_settings.reduce_motion) if user_settings != null else false)
		meta_item_interaction_screen.set_small_screen_mode(small_screen_enabled)
	if bag_open_reel != null:
		bag_open_reel.set_reduced_motion(bool(user_settings.reduce_motion) if user_settings != null else false)
		bag_open_reel.set_small_screen_mode(small_screen_enabled)
	if run_report_screen != null:
		run_report_screen.set_reduce_motion(bool(user_settings.reduce_motion) if user_settings != null else false)
		run_report_screen.set_small_screen_mode(small_screen_enabled)
	_ensure_world_map_overlay_controller()
	world_map_overlay_controller.set_small_screen_mode(small_screen_enabled)
	_apply_accessibility_to_node(self, _accessibility_font_scale(), _accessibility_control_scale())
	_invalidate_run_screen_layout()


func _apply_accessibility_to_node(node: Node, font_scale: float, control_scale: float) -> void:
	var control := node as Control
	if control != null:
		_apply_accessibility_font(control, font_scale)
		_apply_accessibility_minimum_size(control, control_scale)
		_apply_accessibility_color(control)
		_apply_accessibility_styleboxes(control)
	for child in node.get_children():
		_apply_accessibility_to_node(child, font_scale, control_scale)


func _apply_accessibility_font(control: Control, font_scale: float) -> void:
	if not _control_uses_text(control):
		return
	if not control.has_meta(ACCESSIBILITY_BASE_FONT_META):
		var base_size := DEFAULT_CONTROL_FONT_SIZE
		if control.has_theme_font_size_override("font_size"):
			base_size = control.get_theme_font_size("font_size")
		control.set_meta(ACCESSIBILITY_BASE_FONT_META, base_size)
	var stored: Variant = control.get_meta(ACCESSIBILITY_BASE_FONT_META)
	var base_font_size := DEFAULT_CONTROL_FONT_SIZE
	if typeof(stored) == TYPE_INT or typeof(stored) == TYPE_FLOAT:
		base_font_size = int(stored)
	control.add_theme_font_size_override("font_size", maxi(8, int(round(float(base_font_size) * font_scale))))


func _apply_accessibility_minimum_size(control: Control, control_scale: float) -> void:
	if not _control_uses_text(control) and not (control is HSlider):
		return
	if not control.has_meta(ACCESSIBILITY_BASE_MIN_SIZE_META):
		control.set_meta(ACCESSIBILITY_BASE_MIN_SIZE_META, control.custom_minimum_size)
	var stored: Variant = control.get_meta(ACCESSIBILITY_BASE_MIN_SIZE_META)
	if typeof(stored) != TYPE_VECTOR2:
		return
	var base_size: Vector2 = stored
	var next_size := Vector2(base_size.x, base_size.y * control_scale)
	if _small_screen_enabled() and (control is BaseButton or control is LineEdit or control is SpinBox or control is HSlider):
		next_size.y = maxf(next_size.y, SmallScreenPolicyScript.CONTROL_TOUCH_TARGET_HEIGHT)
	control.custom_minimum_size = next_size


func _apply_accessibility_color(control: Control) -> void:
	if not _control_uses_text(control):
		return
	if not control.has_meta(ACCESSIBILITY_BASE_COLOR_META):
		var base_color := VisualStyle.SOFT
		if control.has_theme_color_override("font_color"):
			base_color = control.get_theme_color("font_color")
		elif control is Button or control is LineEdit or control is OptionButton or control is CheckBox:
			base_color = VisualStyle.WHITE
		control.set_meta(ACCESSIBILITY_BASE_COLOR_META, base_color)
	var stored: Variant = control.get_meta(ACCESSIBILITY_BASE_COLOR_META)
	var color := VisualStyle.SOFT
	if typeof(stored) == TYPE_COLOR:
		color = stored
	control.add_theme_color_override("font_color", VisualStyle.accessible_color(color))


func _apply_accessibility_styleboxes(control: Control) -> void:
	for style_name in ["panel", "normal", "hover", "pressed", "disabled", "focus", "read_only"]:
		var key := "%s%s" % [ACCESSIBILITY_STYLEBOX_META_PREFIX, style_name]
		if not control.has_theme_stylebox_override(style_name):
			continue
		if not control.has_meta(key):
			var style_box := control.get_theme_stylebox(style_name)
			var flat_style := style_box as StyleBoxFlat
			if flat_style == null:
				continue
			control.set_meta(key, flat_style.duplicate(true))
		var stored: Variant = control.get_meta(key)
		var base_style := stored as StyleBoxFlat
		if base_style == null:
			continue
		var next_style := base_style.duplicate(true) as StyleBoxFlat
		next_style.bg_color = VisualStyle.accessible_color(base_style.bg_color)
		next_style.border_color = VisualStyle.accessible_color(base_style.border_color)
		control.add_theme_stylebox_override(style_name, next_style)


func _control_uses_text(control: Control) -> bool:
	return (
		control is Label
		or control is Button
		or control is LineEdit
		or control is OptionButton
		or control is CheckBox
		or control is SpinBox
		or control is TextEdit
	)


func _label(text: String, size: int) -> Label:
	var label_node := FoundationWidgetsScript.label(text, size)
	_set_control_font_size(label_node, size)
	return label_node


func _muted_label(text: String, size: int) -> Label:
	var label_node := _label(text, size)
	_set_control_font_color(label_node, VisualStyle.CYAN_2)
	return label_node


func _section(text: String) -> Label:
	var label := _label(text, 13)
	_set_control_font_color(label, VisualStyle.CYAN)
	return label


func _button(text: String, callback: Callable) -> Button:
	var button_node := FoundationWidgetsScript.button(text, callback)
	button_node.custom_minimum_size.y = SmallScreenPolicyScript.control_height(button_node.custom_minimum_size.y, _small_screen_enabled())
	_set_control_font_size(button_node, DEFAULT_CONTROL_FONT_SIZE)
	return button_node


func _hud_nav_button(text: String, callback: Callable) -> Button:
	var button := _button(text, callback)
	button.custom_minimum_size = Vector2(92, MIN_NATIVE_TOUCH_TARGET_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_set_control_font_size(button, 12)
	button.tooltip_text = "Open the run menu." if text == "Menu" else "Open settings."
	return button


func _main_menu_button(title: String, subtitle: String, callback: Callable) -> Button:
	var button := _button(title, callback)
	button.tooltip_text = subtitle
	button.custom_minimum_size = Vector2(148, 46)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_set_control_font_size(button, 14)
	_set_control_font_color(button, VisualStyle.WHITE)
	button.add_theme_stylebox_override("normal", VisualStyle.pixel_box(Color("#091025", 0.96), VisualStyle.CYAN, 2))
	button.add_theme_stylebox_override("hover", VisualStyle.pixel_box(Color("#13142c", 0.98), VisualStyle.CYAN, 2))
	button.add_theme_stylebox_override("pressed", VisualStyle.pixel_box(Color("#271538", 1.0), VisualStyle.YELLOW, 2))
	button.add_theme_stylebox_override("disabled", VisualStyle.pixel_box(Color("#080814", 0.82), VisualStyle.SHADOW, 2))
	return button


func _profile_chip_texture() -> Texture2D:
	if profile_chip_texture != null:
		return profile_chip_texture
	var size := 72
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(float(size - 1) * 0.5, float(size - 1) * 0.5)
	for y in range(size):
		for x in range(size):
			var point := Vector2(float(x), float(y))
			var distance := point.distance_to(center)
			var color := Color(0, 0, 0, 0)
			if distance <= 32.0:
				var angle := atan2(point.y - center.y, point.x - center.x)
				var notch := int(floor((angle + PI) / (PI / 4.0))) % 2 == 0
				if distance > 27.0:
					color = VisualStyle.CYAN if notch else VisualStyle.PINK
				elif distance > 21.0:
					color = Color("#15152d")
				elif distance > 12.0:
					color = VisualStyle.AMBER
				else:
					color = VisualStyle.YELLOW
				if distance > 30.0:
					color = color.darkened(0.18)
			image.set_pixel(x, y, color)
	profile_chip_texture = ImageTexture.create_from_image(image)
	return profile_chip_texture


func _run_item_texture_for_asset_path(asset_path: String) -> Texture2D:
	return _texture_for_image_asset_path(asset_path)


func _texture_for_image_asset_path(asset_path: String) -> Texture2D:
	var path := asset_path.strip_edges()
	if path.is_empty():
		return null
	if run_item_icon_texture_cache.has(path):
		return run_item_icon_texture_cache[path] as Texture2D
	if not ResourceLoader.exists(path):
		return _load_uncached_run_item_texture(path)
	var texture := ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
	_remember_run_item_texture(path, texture)
	return texture


func _load_uncached_run_item_texture(path: String) -> Texture2D:
	var image := Image.new()
	if image.load(path) != OK:
		_remember_run_item_texture(path, null)
		return null
	var image_texture := ImageTexture.create_from_image(image)
	_remember_run_item_texture(path, image_texture)
	return image_texture


func _remember_run_item_texture(path: String, texture: Texture2D) -> void:
	if run_item_icon_texture_cache.size() >= RUN_ITEM_ICON_TEXTURE_CACHE_LIMIT and not run_item_icon_texture_cache.has(path):
		run_item_icon_texture_cache.clear()
	run_item_icon_texture_cache[path] = texture


func _style_selected_button(button: Button) -> void:
	FoundationWidgetsScript.style_selected_button(button)


func _clear(container: Node) -> void:
	FoundationWidgetsScript.clear(container)


func _string_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value:
		var id := str(entry)
		if not id.is_empty():
			result.append(id)
	return result


func _copy_array(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return (value as Array).duplicate(true)


func _copy_dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)


func _snapshot_copy_value(value: Variant) -> Variant:
	if typeof(value) == TYPE_DICTIONARY:
		return (value as Dictionary).duplicate(true)
	if typeof(value) == TYPE_ARRAY:
		return (value as Array).duplicate(true)
	return value
