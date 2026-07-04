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
const CONTEXT_MODE_PRESTIGE := "prestige"
const CONTEXT_MODE_SHOPKEEPER := "shopkeeper"
const CONTEXT_MODE_GAME_HOOK := "game_hook"
const RUN_INFO_BAND_RATIO := 0.15
const RUN_SURFACE_BAND_RATIO := 0.85
const RUN_INFO_MIN_HEIGHT := 144.0
const ENVIRONMENT_CANVAS_MIN_SIZE := Vector2.ZERO
const GAME_SURFACE_FOCUSED_MIN_SIZE := Vector2.ZERO
const GAME_SURFACE_PREVIEW_MIN_SIZE := Vector2.ZERO
const GAME_SURFACE_REALTIME_REFRESH_INTERVAL_MSEC := 16
const RESULT_FEEDBACK_WIDTH := 340.0
const RESULT_FEEDBACK_HEIGHT := 46.0
const RESULT_FEEDBACK_MAX_CHARS := 64
const MAIN_MENU_COLLAPSED_SIZE := Vector2(780, 520)
const MAIN_MENU_EXPANDED_SIZE := Vector2(940, 380)
const MAIN_MENU_VIEWPORT_MARGIN := Vector2(32, 24)
const ACCESSIBILITY_BASE_FONT_META := "accessibility_base_font_size"
const ACCESSIBILITY_BASE_MIN_SIZE_META := "accessibility_base_min_size"
const ACCESSIBILITY_BASE_COLOR_META := "accessibility_base_font_color"
const ACCESSIBILITY_STYLEBOX_META_PREFIX := "accessibility_base_stylebox_"
const DEFAULT_CONTROL_FONT_SIZE := 13
const MIN_NATIVE_TOUCH_TARGET_HEIGHT := 40.0
const UserSettingsScript := preload("res://scripts/core/user_settings.gd")
const ProfileInventoryScript := preload("res://scripts/core/profile_inventory.gd")
const SettingsMenuScript := preload("res://scripts/ui/settings_menu.gd")
const PixelSceneCanvasScript := preload("res://scripts/ui/pixel_scene_canvas.gd")
const GameSurfaceCanvasScript := preload("res://scripts/ui/game_surface_canvas.gd")
const WorldMapCanvasScript := preload("res://scripts/ui/world_map_canvas.gd")
const SfxPlayerScript := preload("res://scripts/ui/sfx_player.gd")
const ProceduralMusicPlayerScript := preload("res://scripts/ui/procedural_music_player.gd")
const RunTerminalEvaluatorScript := preload("res://scripts/core/run_terminal_evaluator.gd")
const RunActionServiceScript := preload("res://scripts/core/run_action_service.gd")
const ItemEffectScript := preload("res://scripts/core/item_effect.gd")
const WorldMapScript := preload("res://scripts/core/world_map.gd")

var user_settings: UserSettings
var profile_inventory: ProfileInventory
var library: ContentLibrary
var run_state: RunState
var generator: RunGenerator
var save_service: SaveService
var platform_services: PlatformServices
var run_action_service: RunActionService
var current_game: GameModule
var last_game_result: Dictionary = {}
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
var selected_prestige_purchase_id: String = ""
var selected_prestige_purchase_label: String = ""
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
var pending_active_item_id: String = ""
var run_inventory_popup_mode: String = ""
var travel_transition_active := false
var travel_transition_target_id: String = ""
var travel_transition_target_label: String = ""
var game_surface_auto_resolving := false
var last_game_surface_realtime_refresh_msec := 0
var surface_feature_music_active := false
var surface_feature_music_ducking := false
var drunk_time_anchor_real_msec := 0
var drunk_time_anchor_scaled_msec := 0
var drunk_time_last_scale := 1.0
var dev_game_test_mode := false
var show_game_library_launcher := true
var autosave_slot_id := AUTOSAVE_SLOT
var pending_autosave := false
var pending_autosave_status_text := "Autosaved."

var start_screen: Control
var run_screen: Control
var main_menu_panel: PanelContainer
var start_menu_controls: VBoxContainer
var start_menu_intro: VBoxContainer
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
var profile_chip_texture: Texture2D
var run_item_icon_texture_cache: Dictionary = {}
var seed_input: LineEdit
var main_menu_seed_counter: int = 0
var content_group_config_button: Button
var content_group_panel: PanelContainer
var content_group_status_label: Label
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
var new_run_button: Button
var daily_run_button: Button
var continue_button: Button
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
var settings_overlay: Control
var settings_menu: SettingsMenu
var procedural_music_player: ProceduralMusicPlayer
var environment_sfx_player: Node
var event_choice_popup_overlay: Control
var event_choice_popup_panel: PanelContainer
var event_choice_popup_title_label: Label
var event_choice_popup_summary_label: Label
var event_choice_popup_choices_list: VBoxContainer
var conclusion_animation_overlay: Control
var conclusion_animation_snapshot: Dictionary = {}
var run_inventory_overlay: Control
var run_inventory_panel: PanelContainer
var run_inventory_title_label: Label
var run_inventory_summary_label: Label
var run_inventory_list: VBoxContainer
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
var world_map_nodes_layer: Control
var world_map_title_label: Label
var world_map_detail_label: Label
var world_map_confirm_button: Button
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
var run_hud_panel: Panel
var visual_panel_container: PanelContainer
var title_label: Label
var summary_label: Label
var environment_result_panel: PanelContainer
var environment_result_title_label: Label
var environment_result_body_label: Label
var failure_summary_panel: PanelContainer
var failure_summary_title_label: Label
var failure_summary_body_label: Label
var failure_summary_list: VBoxContainer
var victory_summary_panel: PanelContainer
var victory_summary_title_label: Label
var victory_summary_body_label: Label
var victory_summary_list: VBoxContainer
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


func _ready() -> void:
	_initialize_user_settings()
	_initialize_procedural_music()
	_initialize_profile_inventory()
	_initialize_foundation()
	_build_ui()
	_refresh()


func _process(_delta: float) -> void:
	_apply_run_screen_layout()
	_advance_game_surface_automation()
	_advance_game_surface_realtime_state()
	_advance_environment_game_runtime()
	_advance_deferred_bankroll_failure()
	_flush_pending_autosave_if_ready()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_invalidate_run_screen_layout()
		_apply_run_screen_layout()


# Compile checks use this to verify the active scene is on the foundation path.
func uses_foundation_runtime() -> bool:
	return library != null and generator != null and save_service != null and platform_services != null


# Starts a deterministic foundation run.
func start_foundation_run(seed_text: String = DEFAULT_SEED, challenge_config: Dictionary = {}) -> void:
	if library == null:
		_initialize_foundation()
	pending_all_in_result_terminal_check = false
	pending_autosave = false
	pending_autosave_status_text = "Autosaved."
	last_environment_runtime_result = {}
	close_content_group_config()
	close_challenge_selection()
	_hide_run_menu()
	_hide_run_journal_popup()
	_hide_travel_transition()
	_reset_game_surface_runtime_state()
	var resolved_seed := seed_text.strip_edges()
	if resolved_seed.is_empty():
		resolved_seed = DEFAULT_SEED
	run_state = RunState.new()
	run_state.start_new(resolved_seed, challenge_config)
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
	_hide_travel_transition()
	_clear_selected_game_action()
	_clear_selected_stake()
	_clear_selected_travel()
	_clear_selected_event_choice()
	_clear_selected_item_offer()
	_clear_selected_service_hook()
	_clear_selected_lender_hook()
	_clear_selected_prestige_purchase()
	clear_interaction_focus()
	_show_message("The run begins.")
	_autosave_foundation_run("Autosaved.")
	_refresh()


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
func enter_game(game_id: String) -> void:
	var definition := library.game(game_id)
	if definition.is_empty():
		_show_message("Game definition is missing.")
		return
	var game_module := _game_module_for_id(game_id)
	if game_module == null:
		_show_message("This game is not ready here.")
		return
	current_game = game_module
	_reset_game_surface_runtime_state()
	selected_action_category = ACTION_CATEGORY_GAMES
	_set_current_screen(SCREEN_GAME)
	focus_interactable_object("game:%s" % game_id)
	_clear_selected_game_action()
	var result := current_game.enter(run_state, run_state.current_environment)
	last_game_result = result.duplicate(true)
	_reset_selected_stake()
	_show_message(str(result.get("message", "")))
	_refresh()
	_clear_selected_stake()
	_refresh_stake_input()


func back_to_environment() -> void:
	if _resolve_pending_all_in_terminal_result():
		return
	_reset_game_surface_runtime_state()
	current_game = null
	last_game_result = {}
	_set_current_screen(SCREEN_ENVIRONMENT)
	_hide_event_choice_popup()
	_hide_run_inventory_popup()
	_hide_run_journal_popup()
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
	if command.has("ui_state") and typeof(command.get("ui_state")) == TYPE_DICTIONARY:
		_store_current_game_surface_ui_state(command.get("ui_state", {}) as Dictionary)
	if command.has("selected_index") and game_surface_canvas != null:
		game_surface_canvas.set_selected_index(int(command.get("selected_index", index)))
	if command.has("stake_multiplier"):
		var multiplied_stake := _current_selected_stake() * int(command.get("stake_multiplier", 1))
		set_selected_stake(multiplied_stake)
	if command.has("set_stake"):
		set_selected_stake(int(command.get("set_stake", _current_selected_stake())))
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
			_resolve_game_action(action_id, false, bool(command.get("preserve_surface_ui_state", false)))
			return true
	elif command.has("message"):
		_show_message(str(command.get("message", "")))
	if environment_changed:
		_autosave_foundation_run("Autosaved.")
	_refresh()
	return true


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
	if _run_menu_is_visible():
		return
	if _blocking_decision_popup_is_visible():
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
	if _run_menu_is_visible():
		return
	if _blocking_decision_popup_is_visible():
		return
	if current_screen != SCREEN_GAME or not game_surface_canvas.visible or not game_surface_canvas.is_visible_in_tree():
		return
	if not game_surface_canvas.surface_realtime_state_refresh_enabled():
		return
	var now_msec := Time.get_ticks_msec()
	if last_game_surface_realtime_refresh_msec > 0 and now_msec - last_game_surface_realtime_refresh_msec < GAME_SURFACE_REALTIME_REFRESH_INTERVAL_MSEC:
		return
	last_game_surface_realtime_refresh_msec = now_msec
	game_surface_canvas.render_game_snapshot(_game_view_snapshot())


func _advance_environment_game_runtime() -> void:
	if game_surface_auto_resolving or run_state == null or library == null or run_state.is_terminal():
		return
	if _blocking_decision_popup_is_visible():
		return
	var now_msec := Time.get_ticks_msec()
	for game_id in _string_array(run_state.current_environment.get("game_ids", [])):
		if current_game != null and game_id == current_game.get_id():
			continue
		var game := _game_module_for_id(game_id)
		if game == null:
			continue
		if not game.environment_runtime_needs_tick(run_state, run_state.current_environment, now_msec):
			continue
		var runtime_wager_cost := maxi(0, game.wager_cost_for_context("spin", 0, run_state, run_state.current_environment, {}))
		if _wager_needs_final_bankroll_confirmation(runtime_wager_cost):
			_pause_environment_runtime_for_wager_confirmation(game, game_id)
			_show_wager_confirmation_popup("spin", runtime_wager_cost, runtime_wager_cost, true, false, game_id)
			_show_message("%s autoplay needs your approval before risking your last cash." % game.get_display_name())
			_refresh_runtime_environment_views()
			return
		var rng := run_state.create_rng()
		var command := game.environment_runtime_tick(run_state, run_state.current_environment, rng, now_msec)
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


func _advance_alcohol_absorption() -> void:
	if run_state == null or run_state.is_terminal():
		return
	var progress := run_state.update_drunk_absorption()
	if int(progress.get("applied", 0)) <= 0:
		return
	_refresh_runtime_environment_views()
	_render_foundation_snapshots()


func _advance_deferred_bankroll_failure() -> void:
	if run_state == null or library == null or run_state.is_terminal() or run_state.bankroll > 0:
		return
	if _all_in_result_terminal_check_is_pending():
		return
	var terminal_result := RunTerminalEvaluatorScript.evaluate(run_state, library)
	if bool(terminal_result.get("bankroll_zero_deferred", false)):
		return
	_evaluate_run_terminal_state()
	if run_state.run_status == RunState.RUN_STATUS_FAILED:
		_render_environment_screen()


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
	_render_victory_summary()
	_render_failure_summary()
	_render_result_panel()
	_render_foundation_snapshots()


func _current_game_surface_status() -> Dictionary:
	if game_surface_canvas == null:
		return {}
	return game_surface_canvas.surface_runtime_status()


func _reset_game_surface_runtime_state() -> void:
	if game_surface_canvas != null:
		game_surface_canvas.stop_surface_audio()
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
	_resolve_game_action(selected_action_id)


# Selects a stake as UI-local input without mutating simulation state.
func set_selected_stake(stake: int) -> bool:
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


func open_world_map() -> bool:
	if run_state == null:
		return false
	selected_action_category = ACTION_CATEGORY_TRAVEL
	_set_current_screen(SCREEN_TRAVEL)
	if selected_world_map_node_id.is_empty() or (run_state.has_world_map() and not WorldMapScript.is_node_visible(run_state.world_map, selected_world_map_node_id)):
		var first_choice := _first_enabled_travel_choice()
		if first_choice.is_empty():
			first_choice = _first_disabled_travel_choice()
		selected_world_map_node_id = str(first_choice.get("id", ""))
		if selected_world_map_node_id.is_empty() and run_state.has_world_map():
			selected_world_map_node_id = run_state.current_world_node_id()
	if world_map_overlay != null:
		world_map_overlay.visible = true
		world_map_overlay.move_to_front()
	_request_world_map_button_relayout()
	_refresh()
	return true


func close_world_map() -> void:
	if world_map_overlay != null:
		world_map_overlay.visible = false
	if current_screen == SCREEN_TRAVEL:
		_set_current_screen(SCREEN_ENVIRONMENT)
	_refresh()


func select_world_map_node(node_id: String) -> bool:
	var clean_id := node_id.strip_edges()
	if clean_id.is_empty():
		return false
	if run_state != null and run_state.has_world_map() and not WorldMapScript.is_node_visible(run_state.world_map, clean_id):
		_show_message("That stop is not on your map yet.")
		_refresh_world_map_overlay()
		return false
	selected_world_map_node_id = clean_id
	if run_state != null and clean_id == run_state.current_world_node_id():
		selected_travel_target_id = ""
		selected_travel_label = ""
		_show_message("You are here.")
		_refresh_world_map_overlay()
		return true
	var choice := _travel_choice(clean_id)
	if choice.is_empty():
		selected_travel_target_id = ""
		selected_travel_label = ""
		_show_message("That stop is not available from here right now.")
		_refresh_world_map_overlay()
		return true
	selected_travel_target_id = clean_id if bool(choice.get("enabled", true)) else ""
	selected_travel_label = str(choice.get("label", clean_id)) if bool(choice.get("enabled", true)) else ""
	if bool(choice.get("enabled", true)):
		_show_message("Selected travel: %s." % str(choice.get("label", clean_id)))
	else:
		_show_message(str(choice.get("disabled_reason", "That route is not available right now.")))
	_refresh_world_map_overlay()
	return bool(choice.get("enabled", true))


func confirm_world_map_travel() -> void:
	if _event_choice_popup_is_visible():
		_show_message("Choose a response before traveling.")
		return
	if selected_world_map_node_id.is_empty():
		_show_message("Select a map stop first.")
		return
	var choice := _travel_choice(selected_world_map_node_id)
	if choice.is_empty():
		_show_message("That stop is not available from here right now.")
		_refresh_world_map_overlay()
		return
	if not bool(choice.get("enabled", true)):
		_show_message(str(choice.get("disabled_reason", "That route is not available right now.")))
		_refresh_world_map_overlay()
		return
	selected_travel_target_id = str(choice.get("id", ""))
	selected_travel_label = str(choice.get("label", selected_travel_target_id))
	if world_map_overlay != null:
		world_map_overlay.visible = false
	confirm_selected_travel()


# Selects an event choice without mutating simulation state.
func select_event_choice(event_id: String, choice_id: String) -> bool:
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
	var event_definition := library.event(event_id)
	if event_definition.is_empty():
		_show_message("Event definition is missing.")
		return
	var event_module := EventModule.new()
	event_module.setup(event_definition, library)
	var event_context := _pending_event_trigger_context(event_id)
	var event_environment := _event_environment_for_context(event_context)
	if not event_module.can_trigger(run_state, event_environment, event_context):
		_show_message("Event cannot trigger right now.")
		return
	var popup_rect := event_choice_popup_panel.get_global_rect() if event_choice_popup_panel != null else Rect2()
	var had_event_popup := bool(pending_event_choice_popup_snapshot.get("visible", false))
	var was_triggered_popup := str(pending_event_choice_popup_snapshot.get("popup_type", "")) == "triggered_event"
	var result := event_module.resolve(run_state, event_environment, choice_id)
	_start_conclusion_animation(result, popup_rect)
	if was_triggered_popup and run_state != null:
		run_state.complete_triggered_event_resolution(event_id)
	if had_event_popup and run_state != null:
		run_state.event_cadence_note_modal_closed()
	_hide_event_choice_popup()
	_hide_run_inventory_popup()
	_hide_run_journal_popup()
	_clear_selected_event_choice()
	_set_current_screen(SCREEN_RESULT)
	_show_message(str(result.get("message", "")))
	_advance_alcohol_absorption()
	_autosave_foundation_run("Autosaved.")
	_refresh()


func _apply_post_action_environment_interrupt(source: String) -> bool:
	if run_state == null or library == null or run_state.is_terminal():
		return false
	if _apply_forced_environment_travel(source):
		return true
	return _maybe_trigger_unavoidable_event(source)


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
	var context := _event_action_trigger_context(source)
	if _enqueue_triggered_events_for_context(source, context, run_state.current_environment):
		_autosave_foundation_run("Autosaved.")
		return _show_next_pending_triggered_event()
	return false


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
			if run_state.enqueue_triggered_event(event_id, source, _event_context_with_environment(context, environment)):
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
			if run_state.enqueue_triggered_event(picked_id, source, _event_context_with_environment(context, environment)):
				run_state.event_cadence_note_event_enqueued(picked_id, not run_state.event_cadence_event_bypasses_budget(picked_id, "random", source, picked_event))
				enqueued = true
	run_state.save_event_cadence_rng(cadence_rng)
	return enqueued


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
			false
		)
	event_choice_popup_overlay.visible = true
	event_choice_popup_overlay.move_to_front()
	_position_event_choice_popup()
	call_deferred("_position_event_choice_popup")
	return true


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
	return {}


# Selects an item offer without mutating simulation state.
func select_item_offer(item_id: String) -> bool:
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
	_refresh_run_action_service()
	var resolved := run_action_service.buy_item_offer(item_id)
	if not bool(resolved.get("ok", false)):
		_show_message(str(resolved.get("message", "Item offer is not available.")))
		return false
	var result: Dictionary = resolved.get("result", {})
	last_item_result = result.duplicate(true)
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


func open_run_inventory() -> void:
	_reset_game_surface_runtime_state()
	_hide_run_journal_popup()
	_open_run_inventory_popup("inspect")


func close_run_inventory() -> void:
	_hide_run_inventory_popup()


func open_run_journal() -> void:
	if run_state == null:
		_show_message("No active run to review.")
		return
	_hide_run_inventory_popup()
	_open_run_journal_popup()


func close_run_journal() -> void:
	_hide_run_journal_popup()


func use_active_item_slot() -> bool:
	if run_state == null:
		_show_message("No active run.")
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
		GameModule.apply_result(run_state, result, run_state.create_rng("active_item_apply:%s" % item_id))
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
	var resolved := run_action_service.use_hook("service", service_id)
	if not bool(resolved.get("ok", false)):
		_show_message(str(resolved.get("message", "This service is only informational right now.")))
		_refresh()
		return false
	var result: Dictionary = resolved.get("result", {})
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
	return use_lender_hook(selected_lender_hook_id)


# Applies a supported lender hook through the shared result-delta path.
func use_lender_hook(lender_id: String) -> bool:
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


func use_game_environment_hook(game_id: String, hook_id: String, action_id: String = "") -> bool:
	if run_state == null or library == null:
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


# Selects a prestige target without mutating simulation state.
func select_prestige_purchase(purchase_id: String) -> bool:
	var option := _prestige_purchase_option(purchase_id)
	if option.is_empty():
		_show_message("Prestige target is not available.")
		return false
	selected_prestige_purchase_id = purchase_id
	selected_prestige_purchase_label = str(option.get("display_name", purchase_id))
	focus_interactable_object("prestige:%s" % purchase_id)
	_show_message("%s: %s" % [selected_prestige_purchase_label, str(option.get("status", ""))])
	_refresh()
	return true


# Confirms the selected prestige purchase through the result-delta path.
func confirm_selected_prestige_purchase() -> bool:
	if selected_prestige_purchase_id.is_empty():
		_show_message("Select a prestige target first.")
		return false
	return buy_prestige_purchase(selected_prestige_purchase_id)


# Buys one prestige target and lets RunState hold the resulting run status.
func buy_prestige_purchase(purchase_id: String) -> bool:
	var option := _prestige_purchase_option(purchase_id)
	if option.is_empty():
		_show_message("Prestige target is not available.")
		return false
	if not bool(option.get("enabled", false)):
		_show_message(str(option.get("disabled_reason", "This target is locked for now.")))
		_refresh()
		return false
	_refresh_run_action_service()
	var resolved := run_action_service.buy_prestige_purchase(purchase_id)
	if not bool(resolved.get("ok", false)):
		_show_message(str(resolved.get("message", "Prestige target is not available.")))
		_refresh()
		return false
	var result: Dictionary = resolved.get("result", {})
	_reset_game_surface_runtime_state()
	current_game = null
	last_game_result = {}
	last_item_result = {}
	last_hook_result = result.duplicate(true)
	_clear_selected_prestige_purchase()
	clear_interaction_focus()
	_set_current_screen(SCREEN_RESULT)
	_show_message(str(result.get("message", "")))
	_advance_alcohol_absorption()
	_autosave_foundation_run("Autosaved.")
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
	if dev_game_test_mode:
		save_status_message = "Practice sessions are not autosaved."
		return false
	if not force and _should_defer_autosave_for_game_surface():
		pending_autosave = true
		pending_autosave_status_text = status_text
		save_status_message = "Autosave pending."
		return true
	return _write_foundation_run_save(status_text)


func _write_foundation_run_save(status_text: String = "Autosaved.") -> bool:
	if run_state == null:
		return false
	_evaluate_run_terminal_state()
	if save_service == null:
		save_status_message = "Autosave unavailable."
		return false
	var error := save_service.save_run(run_state, autosave_slot_id)
	if error == OK:
		pending_autosave = false
		pending_autosave_status_text = "Autosaved."
		save_status_message = status_text
		_refresh_start_screen()
		return true
	save_status_message = "Autosave failed."
	return false


func _flush_pending_autosave_if_ready() -> void:
	if not pending_autosave:
		return
	if _game_surface_autosave_blocked():
		return
	_write_foundation_run_save(pending_autosave_status_text)


func _should_defer_autosave_for_game_surface() -> bool:
	return current_screen == SCREEN_GAME and current_game != null and not _run_menu_is_visible()


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
	if loaded == null:
		save_status_message = "No saved run is available."
		_show_message("No saved run found.")
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
	run_state = loaded
	dev_game_test_mode = false
	_refresh_run_action_service()
	current_game = null
	last_game_result = _game_result_from_story_log(run_state.story_log)
	last_item_result = {}
	last_hook_result = {}
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
	_clear_selected_prestige_purchase()
	clear_interaction_focus()
	save_status_message = "Loaded run."
	_set_current_screen(SCREEN_ENVIRONMENT)
	_show_message("Run loaded: %s." % str(run_state.current_environment.get("display_name", "Environment")))
	_hide_run_menu()
	_refresh()
	if _show_next_pending_triggered_event():
		_refresh()
	return true


func open_run_menu() -> void:
	if run_menu_overlay == null or current_screen == SCREEN_START:
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
	var previous_environment := run_state.current_environment.duplicate(true)
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
	var route_risk := run_state.travel_route_risk(route, target_id)
	var travel_heat := run_state.begin_travel_suspicion_decay(route, target_id)
	generator.next_environment(run_state, target_id)
	var travel_decay := run_state.finish_travel_suspicion_decay(travel_heat)
	_update_procedural_music()
	_reset_game_surface_runtime_state()
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
	_clear_selected_prestige_purchase()
	clear_interaction_focus()
	var destination_name := str(run_state.current_environment.get("display_name", target_label))
	var travel_result := _travel_result(target_id, destination_name, route, previous_environment, run_state.current_environment, travel_decay, route_risk)
	GameModule.apply_result(run_state, travel_result)
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
		"turns": int(previous_environment.get("turns", 0)),
	}
	if _enqueue_triggered_events_for_context("travel", travel_context, previous_environment):
		_autosave_foundation_run("Autosaved.")
		if _show_next_pending_triggered_event():
			_refresh()


func _travel_result(target_id: String, destination_name: String, route: Dictionary, previous_environment: Dictionary, destination_environment: Dictionary, travel_decay: Dictionary = {}, route_risk: Dictionary = {}) -> Dictionary:
	var route_status := run_state.travel_route_status(route)
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
		"to_archetype_id": target_id,
		"to_environment_id": str(destination_environment.get("id", "")),
		"to_environment_name": destination_name,
		"bankroll_delta": total_bankroll_delta,
		"route_cost": cost,
		"suspicion_delta": total_suspicion_delta,
		"route_suspicion_delta": suspicion_delta,
		"travel_distance": str(travel_decay.get("distance", route_status.get("distance", ""))),
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
	library = ContentLibrary.new()
	library.load()
	game_module_cache = {}
	generator = RunGenerator.new(library)
	save_service = SaveService.new()
	platform_services = PlatformServices.new()
	platform_services.setup("local")
	platform_services.initialize()
	run_action_service = RunActionServiceScript.new()
	_refresh_run_action_service()


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
	VisualStyle.set_high_contrast_enabled(user_settings.high_contrast)
	user_settings.apply()


func _initialize_profile_inventory() -> void:
	profile_inventory = ProfileInventoryScript.new()
	profile_inventory.load()


func _initialize_procedural_music() -> void:
	procedural_music_player = ProceduralMusicPlayerScript.new()
	procedural_music_player.audio_calm = user_settings != null and bool(user_settings.audio_calm)
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
	_build_run_menu_overlay()
	_build_settings_overlay()
	_build_event_choice_popup_overlay()
	_build_conclusion_animation_overlay()
	_build_run_inventory_overlay()
	_build_run_journal_overlay()
	_build_travel_transition_overlay()
	_build_world_map_overlay()
	_apply_accessibility_settings()


func _build_start_screen() -> void:
	main_menu_background = PixelSceneCanvasScript.new()
	main_menu_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	start_screen.add_child(main_menu_background)
	var menu_environment_id := _main_menu_background_environment_id()
	if not menu_environment_id.is_empty():
		main_menu_background.set("environment_id", menu_environment_id)
	main_menu_background.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var menu_panel := _panel_container(Color("#050611", 0.96), VisualStyle.PURPLE_2)
	main_menu_panel = menu_panel
	menu_panel.anchor_left = 0.5
	menu_panel.anchor_top = 0.5
	menu_panel.anchor_right = 0.5
	menu_panel.anchor_bottom = 0.5
	_apply_main_menu_panel_size(MAIN_MENU_COLLAPSED_SIZE)
	start_screen.add_child(menu_panel)

	var menu_margin := MarginContainer.new()
	menu_margin.add_theme_constant_override("margin_left", 18)
	menu_margin.add_theme_constant_override("margin_top", 16)
	menu_margin.add_theme_constant_override("margin_right", 18)
	menu_margin.add_theme_constant_override("margin_bottom", 16)
	menu_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	menu_panel.add_child(menu_margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	menu_margin.add_child(stack)

	start_menu_intro = VBoxContainer.new()
	start_menu_intro.add_theme_constant_override("separation", 12)
	start_menu_intro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_child(start_menu_intro)

	var kicker := _label("Run-Based Casino Crime Spiral", 16)
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_set_control_font_color(kicker, VisualStyle.YELLOW)
	start_menu_intro.add_child(kicker)

	var heading := _label("BEAT THE HOUSE", 44)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_set_control_font_color(heading, VisualStyle.PINK)
	start_menu_intro.add_child(heading)

	release_version_label = _label(_release_version_text(), 12)
	release_version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_set_control_font_color(release_version_label, VisualStyle.CYAN_2)
	start_menu_intro.add_child(release_version_label)

	var copy := _label("Start in cheap rooms, borrow badly, read crooked tables, and climb toward the Grand Casino before the house learns your shape.", 16)
	copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_set_control_font_color(copy, VisualStyle.SOFT)
	start_menu_intro.add_child(copy)

	release_framing_label = _label(RELEASE_MENU_FRAMING, 12)
	release_framing_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	release_framing_label.max_lines_visible = 2
	release_framing_label.clip_text = true
	_set_control_font_color(release_framing_label, VisualStyle.CYAN_2)
	start_menu_intro.add_child(release_framing_label)

	start_status_label = _label("", 13)
	start_status_label.visible = true
	start_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_set_control_font_color(start_status_label, VisualStyle.YELLOW)
	start_menu_intro.add_child(start_status_label)

	start_menu_controls = VBoxContainer.new()
	start_menu_controls.add_theme_constant_override("separation", 12)
	start_menu_controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_menu_controls.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	stack.add_child(start_menu_controls)

	var seed_row := HBoxContainer.new()
	seed_row.add_theme_constant_override("separation", 8)
	seed_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_menu_controls.add_child(seed_row)

	seed_input = LineEdit.new()
	seed_input.text = _generate_menu_seed_text()
	seed_input.placeholder_text = "Enter run seed"
	seed_input.tooltip_text = "Edit the seed before New Run to replay a deterministic climb."
	seed_input.custom_minimum_size = Vector2(0, 54)
	seed_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_set_control_font_color(seed_input, VisualStyle.WHITE)
	seed_input.add_theme_stylebox_override("normal", VisualStyle.pixel_box(Color("#080817", 0.98), VisualStyle.TEAL, 2))
	seed_input.add_theme_stylebox_override("focus", VisualStyle.pixel_box(Color("#111024", 0.98), VisualStyle.CYAN, 2))
	seed_row.add_child(seed_input)

	content_group_config_button = Button.new()
	content_group_config_button.text = "⚙"
	content_group_config_button.tooltip_text = "Configure run content."
	content_group_config_button.custom_minimum_size = Vector2(54, 54)
	content_group_config_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_set_control_font_color(content_group_config_button, VisualStyle.WHITE)
	_set_control_font_size(content_group_config_button, 22)
	content_group_config_button.add_theme_stylebox_override("normal", VisualStyle.pixel_box(Color("#080817", 0.98), VisualStyle.CYAN_2, 2))
	content_group_config_button.add_theme_stylebox_override("hover", VisualStyle.pixel_box(Color("#13142c", 0.98), VisualStyle.CYAN, 2))
	content_group_config_button.add_theme_stylebox_override("pressed", VisualStyle.pixel_box(Color("#271538", 1.0), VisualStyle.YELLOW, 2))
	content_group_config_button.pressed.connect(toggle_content_group_config)
	seed_row.add_child(content_group_config_button)

	challenge_select_button = _main_menu_button("Challenges", "Pick an authored challenge run", Callable(self, "toggle_challenge_selection"))
	challenge_select_button.custom_minimum_size = Vector2(136, 54)
	challenge_select_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_set_control_font_size(challenge_select_button, 13)
	seed_row.add_child(challenge_select_button)

	_build_content_group_controls(start_menu_controls)
	_build_challenge_controls(start_menu_controls)

	var run_row := HBoxContainer.new()
	run_row.add_theme_constant_override("separation", 12)
	start_menu_controls.add_child(run_row)
	start_menu_action_controls.append(run_row)
	new_run_button = _main_menu_button("New Run", "Start a seeded climb", Callable(self, "_on_start_pressed"))
	run_row.add_child(new_run_button)
	daily_run_button = _main_menu_button("Daily Run", "Start today's hidden-seed challenge", Callable(self, "start_daily_challenge_run"))
	run_row.add_child(daily_run_button)
	continue_button = _main_menu_button("Continue", "Load the saved run", Callable(self, "load_foundation_run"))
	run_row.add_child(continue_button)

	var utility_row := HBoxContainer.new()
	utility_row.add_theme_constant_override("separation", 12)
	start_menu_controls.add_child(utility_row)
	start_menu_action_controls.append(utility_row)
	settings_button = _main_menu_button("Settings", "Resolution and sound", Callable(self, "open_settings_menu"))
	utility_row.add_child(settings_button)
	inventory_button = _main_menu_button("Inventory", "Profile stash", Callable(self, "open_inventory_page"))
	utility_row.add_child(inventory_button)
	if show_game_library_launcher:
		game_library_button = _main_menu_button("Games", "Practice any table", Callable(self, "open_game_test_menu"))
		utility_row.add_child(game_library_button)

	exit_game_button = _main_menu_button("Exit Game", "Close the game window", Callable(self, "exit_game"))
	start_menu_controls.add_child(exit_game_button)
	start_menu_action_controls.append(exit_game_button)

	_build_inventory_page(stack)
	if show_game_library_launcher:
		_build_game_test_menu(stack)


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
		maxf(320.0, viewport_size.x - MAIN_MENU_VIEWPORT_MARGIN.x * 2.0),
		maxf(420.0, viewport_size.y - MAIN_MENU_VIEWPORT_MARGIN.y * 2.0)
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
	if _challenge_pack_loaded() and not selected_challenge_id.is_empty():
		return library.challenge_config_for(selected_challenge_id, seed_text)
	return _content_group_challenge_for_seed(seed_text)


func _build_settings_overlay() -> void:
	settings_overlay = PanelContainer.new()
	settings_overlay.visible = false
	settings_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	settings_overlay.add_theme_stylebox_override("panel", VisualStyle.pixel_box(Color("#03030a", 0.92), VisualStyle.CYAN, 1))
	add_child(settings_overlay)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 220)
	margin.add_theme_constant_override("margin_right", 220)
	margin.add_theme_constant_override("margin_top", 48)
	margin.add_theme_constant_override("margin_bottom", 48)
	settings_overlay.add_child(margin)

	var panel := _panel_container(Color("#080817", 0.98), VisualStyle.PINK)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(panel)

	settings_menu = SettingsMenuScript.new()
	settings_menu.visible = false
	settings_menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_menu.size_flags_vertical = Control.SIZE_EXPAND_FILL
	settings_menu.setup(user_settings)
	settings_menu.back_requested.connect(close_settings_menu)
	settings_menu.settings_applied.connect(_on_settings_applied)
	panel.add_child(settings_menu)


func _build_event_choice_popup_overlay() -> void:
	event_choice_popup_overlay = Control.new()
	event_choice_popup_overlay.visible = false
	event_choice_popup_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	event_choice_popup_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(event_choice_popup_overlay)

	event_choice_popup_panel = _panel_container(Color("#080817", 0.98), VisualStyle.AMBER)
	event_choice_popup_panel.custom_minimum_size = Vector2(460, 260)
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


func _build_conclusion_animation_overlay() -> void:
	conclusion_animation_overlay = Control.new()
	conclusion_animation_overlay.visible = false
	conclusion_animation_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	conclusion_animation_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(conclusion_animation_overlay)


func _build_run_inventory_overlay() -> void:
	run_inventory_overlay = Control.new()
	run_inventory_overlay.visible = false
	run_inventory_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	run_inventory_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(run_inventory_overlay)

	run_inventory_panel = _panel_container(Color("#080817", 0.98), VisualStyle.AMBER)
	run_inventory_panel.custom_minimum_size = Vector2(460, 320)
	run_inventory_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	run_inventory_overlay.add_child(run_inventory_panel)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	run_inventory_panel.add_child(stack)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	stack.add_child(header)
	run_inventory_title_label = _label("Inventory", 18)
	_set_control_font_color(run_inventory_title_label, VisualStyle.YELLOW)
	run_inventory_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(run_inventory_title_label)
	var close_button := _button("Close", Callable(self, "close_run_inventory"))
	close_button.custom_minimum_size = Vector2(88, MIN_NATIVE_TOUCH_TARGET_HEIGHT)
	header.add_child(close_button)

	run_inventory_summary_label = _label("", 12)
	_set_control_font_color(run_inventory_summary_label, VisualStyle.CYAN)
	run_inventory_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(run_inventory_summary_label)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(scroll)

	run_inventory_list = VBoxContainer.new()
	run_inventory_list.add_theme_constant_override("separation", 8)
	run_inventory_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(run_inventory_list)


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
	world_map_panel.custom_minimum_size = Vector2(820, 540)
	world_map_panel.anchor_left = 0.5
	world_map_panel.anchor_top = 0.5
	world_map_panel.anchor_right = 0.5
	world_map_panel.anchor_bottom = 0.5
	world_map_panel.offset_left = -410
	world_map_panel.offset_top = -270
	world_map_panel.offset_right = 410
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

	world_map_title_label = _label("World Map", 22)
	world_map_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_set_control_font_color(world_map_title_label, VisualStyle.YELLOW)
	header.add_child(world_map_title_label)

	var close_button := _button("Close", Callable(self, "close_world_map"))
	close_button.custom_minimum_size = Vector2(96, MIN_NATIVE_TOUCH_TARGET_HEIGHT)
	header.add_child(close_button)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	var map_holder := Control.new()
	map_holder.custom_minimum_size = Vector2(540, 390)
	map_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(map_holder)

	world_map_nodes_layer = WorldMapCanvasScript.new()
	world_map_nodes_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	world_map_nodes_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if world_map_nodes_layer.has_signal("layout_changed"):
		world_map_nodes_layer.connect("layout_changed", Callable(self, "_on_world_map_canvas_layout_changed"))
	map_holder.add_child(world_map_nodes_layer)

	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 8)
	side.custom_minimum_size = Vector2(230, 390)
	side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(side)

	world_map_detail_label = _label("Select a revealed stop.", 13)
	world_map_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	world_map_detail_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	world_map_detail_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(world_map_detail_label)

	world_map_confirm_button = _button("Travel", Callable(self, "confirm_world_map_travel"))
	world_map_confirm_button.custom_minimum_size = Vector2(180, MIN_NATIVE_TOUCH_TARGET_HEIGHT)
	side.add_child(world_map_confirm_button)


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

	var description := _label("Items here live outside a single run. This is the long-term stash structure; it does not change RunState.", 13)
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
	run_hud_panel = _panel(VisualStyle.DARK_2, VisualStyle.CYAN_2)
	run_hud_panel.clip_contents = true
	run_hud_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	run_hud_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	run_screen.add_child(run_hud_panel)
	var hud_margin := MarginContainer.new()
	hud_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_margin.add_theme_constant_override("margin_left", 8)
	hud_margin.add_theme_constant_override("margin_right", 8)
	hud_margin.add_theme_constant_override("margin_top", 6)
	hud_margin.add_theme_constant_override("margin_bottom", 4)
	run_hud_panel.add_child(hud_margin)
	var hud_stack := VBoxContainer.new()
	hud_stack.add_theme_constant_override("separation", 2)
	hud_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hud_margin.add_child(hud_stack)
	var hud_row := HBoxContainer.new()
	hud_row.add_theme_constant_override("separation", 8)
	hud_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud_stack.add_child(hud_row)
	top_menu_button = _hud_nav_button("Menu", Callable(self, "open_run_menu"))
	hud_row.add_child(top_menu_button)
	top_settings_button = _hud_nav_button("Settings", Callable(self, "open_settings_menu"))
	hud_row.add_child(top_settings_button)
	top_inventory_button = _hud_nav_button("Inventory", Callable(self, "open_run_inventory"))
	top_inventory_button.custom_minimum_size = Vector2(118, MIN_NATIVE_TOUCH_TARGET_HEIGHT)
	top_inventory_button.tooltip_text = "Inspect current run items."
	hud_row.add_child(top_inventory_button)
	status_label = _label("", 14)
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	status_label.clip_text = true
	hud_row.add_child(status_label)
	save_status_label = _label("", 13)
	save_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	save_status_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	save_status_label.clip_text = true
	save_status_label.custom_minimum_size = Vector2(260, 0)
	hud_row.add_child(save_status_label)
	active_item_button = _hud_nav_button("Active: Empty", Callable(self, "use_active_item_slot"))
	active_item_button.custom_minimum_size = Vector2(148, MIN_NATIVE_TOUCH_TARGET_HEIGHT)
	active_item_button.tooltip_text = "Use the equipped active item."
	hud_row.add_child(active_item_button)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud_stack.add_child(title_row)
	title_label = _label("", 17)
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	title_label.clip_text = true
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(title_label)
	environment_result_panel = _panel_container(Color("#080817", 0.96), VisualStyle.CYAN_2)
	environment_result_panel.custom_minimum_size = Vector2(RESULT_FEEDBACK_WIDTH, RESULT_FEEDBACK_HEIGHT)
	environment_result_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	environment_result_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	environment_result_panel.visible = false
	title_row.add_child(environment_result_panel)
	var result_feedback_stack := VBoxContainer.new()
	result_feedback_stack.add_theme_constant_override("separation", 1)
	result_feedback_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	environment_result_panel.add_child(result_feedback_stack)
	environment_result_title_label = _label("Result", 10)
	environment_result_title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	environment_result_title_label.clip_text = true
	result_feedback_stack.add_child(environment_result_title_label)
	environment_result_body_label = _label("", 12)
	environment_result_body_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	environment_result_body_label.clip_text = true
	result_feedback_stack.add_child(environment_result_body_label)

	objective_label = _label("", 13)
	objective_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	objective_label.clip_text = true
	objective_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_set_control_font_color(objective_label, VisualStyle.YELLOW)
	hud_stack.add_child(objective_label)
	summary_label = _label("", 12)
	summary_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	summary_label.max_lines_visible = 1
	summary_label.clip_text = true
	summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud_stack.add_child(summary_label)

	visual_panel_container = _panel_container(VisualStyle.DARK_2, VisualStyle.CYAN_2)
	visual_panel_container.clip_contents = true
	visual_panel_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	visual_panel_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	visual_panel_container.add_theme_stylebox_override("panel", _surface_panel_style())
	run_screen.add_child(visual_panel_container)
	var visual_stack := VBoxContainer.new()
	visual_stack.add_theme_constant_override("separation", 0)
	visual_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	visual_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	visual_panel_container.add_child(visual_stack)
	_build_victory_summary_panel(visual_stack)
	_build_failure_summary_panel(visual_stack)
	environment_canvas = PixelSceneCanvasScript.new()
	environment_canvas.clip_contents = true
	environment_canvas.custom_minimum_size = ENVIRONMENT_CANVAS_MIN_SIZE
	environment_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	environment_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	environment_canvas.object_hovered.connect(_on_environment_object_hovered)
	environment_canvas.object_focused.connect(_on_environment_object_focused)
	environment_canvas.object_activated.connect(_on_environment_object_activated)
	visual_stack.add_child(environment_canvas)
	game_surface_canvas = GameSurfaceCanvasScript.new()
	game_surface_canvas.custom_minimum_size = GAME_SURFACE_PREVIEW_MIN_SIZE
	game_surface_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game_surface_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	game_surface_canvas.surface_action.connect(_on_game_surface_action)
	game_surface_canvas.surface_music_cue.connect(_on_game_surface_music_cue)
	visual_stack.add_child(game_surface_canvas)

	action_panel_container = _panel_container(VisualStyle.DARK_3, VisualStyle.PINK)
	action_panel_container.custom_minimum_size = Vector2.ZERO
	action_panel_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_panel_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	action_panel_container.visible = false
	visual_stack.add_child(action_panel_container)
	var action_stack := VBoxContainer.new()
	action_stack.add_theme_constant_override("separation", 6)
	action_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	action_panel_container.add_child(action_stack)
	action_heading_label = _label("Room objects", 18)
	_set_control_font_color(action_heading_label, VisualStyle.YELLOW)
	action_stack.add_child(action_heading_label)
	action_hint_label = _label("Choose a game, answer trouble, buy gear, or move on.", 13)
	action_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	action_hint_label.max_lines_visible = 2
	action_hint_label.clip_text = true
	action_stack.add_child(action_hint_label)
	actions_list = VBoxContainer.new()
	actions_list.add_theme_constant_override("separation", 5)
	actions_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	action_stack.add_child(actions_list)

	consequence_panel = _panel_container(VisualStyle.DARK_2, VisualStyle.AMBER)
	consequence_panel.custom_minimum_size = Vector2(0, 0)
	consequence_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	consequence_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	consequence_panel.visible = false
	hud_stack.add_child(consequence_panel)
	var result_stack := VBoxContainer.new()
	result_stack.add_theme_constant_override("separation", 3)
	consequence_panel.add_child(result_stack)
	consequence_heading_label = _label("Recent consequence", 15)
	_set_control_font_color(consequence_heading_label, VisualStyle.AMBER)
	result_stack.add_child(consequence_heading_label)
	message_label = _label("", 14)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.visible = false
	result_stack.add_child(message_label)
	consequence_result_label = _label("", 13)
	consequence_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	consequence_result_label.visible = false
	result_stack.add_child(consequence_result_label)
	consequence_state_label = _label("", 13)
	consequence_state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	consequence_state_label.visible = false
	result_stack.add_child(consequence_state_label)
	consequence_story_label = _label("", 13)
	consequence_story_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	consequence_story_label.visible = false
	result_stack.add_child(consequence_story_label)
	consequence_cards_scroll = ScrollContainer.new()
	consequence_cards_scroll.custom_minimum_size = Vector2(0, 42)
	consequence_cards_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	consequence_cards_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	consequence_cards_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result_stack.add_child(consequence_cards_scroll)
	consequence_cards_list = HBoxContainer.new()
	consequence_cards_list.add_theme_constant_override("separation", 6)
	consequence_cards_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	consequence_cards_scroll.add_child(consequence_cards_list)
	_apply_run_screen_layout()


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


func _build_failure_summary_panel(parent: BoxContainer) -> void:
	failure_summary_panel = _panel_container(Color("#12050d", 0.98), VisualStyle.PINK_2)
	failure_summary_panel.visible = false
	failure_summary_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	failure_summary_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(failure_summary_panel)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	failure_summary_panel.add_child(stack)

	failure_summary_title_label = _label("Run Failed", 26)
	_set_control_font_color(failure_summary_title_label, VisualStyle.PINK)
	stack.add_child(failure_summary_title_label)

	failure_summary_body_label = _label("", 14)
	_set_control_font_color(failure_summary_body_label, VisualStyle.SOFT)
	failure_summary_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(failure_summary_body_label)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(scroll)

	failure_summary_list = VBoxContainer.new()
	failure_summary_list.add_theme_constant_override("separation", 7)
	failure_summary_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(failure_summary_list)

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 10)
	stack.add_child(button_row)
	var menu_button := _button("Main Menu", Callable(self, "return_to_main_menu"))
	menu_button.custom_minimum_size = Vector2(160, MIN_NATIVE_TOUCH_TARGET_HEIGHT)
	button_row.add_child(menu_button)
	var fresh_button := _button("New Run", Callable(self, "start_generated_foundation_run"))
	fresh_button.custom_minimum_size = Vector2(160, MIN_NATIVE_TOUCH_TARGET_HEIGHT)
	button_row.add_child(fresh_button)


func _build_victory_summary_panel(parent: BoxContainer) -> void:
	victory_summary_panel = _panel_container(Color("#061410", 0.98), VisualStyle.TEAL)
	victory_summary_panel.visible = false
	victory_summary_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	victory_summary_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(victory_summary_panel)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	victory_summary_panel.add_child(stack)

	victory_summary_title_label = _label("Demo Victory", 26)
	_set_control_font_color(victory_summary_title_label, VisualStyle.TEAL)
	stack.add_child(victory_summary_title_label)

	victory_summary_body_label = _label("", 14)
	_set_control_font_color(victory_summary_body_label, VisualStyle.SOFT)
	victory_summary_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(victory_summary_body_label)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(scroll)

	victory_summary_list = VBoxContainer.new()
	victory_summary_list.add_theme_constant_override("separation", 7)
	victory_summary_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(victory_summary_list)

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 10)
	stack.add_child(button_row)
	var menu_button := _button("Main Menu", Callable(self, "return_to_main_menu"))
	menu_button.custom_minimum_size = Vector2(160, MIN_NATIVE_TOUCH_TARGET_HEIGHT)
	button_row.add_child(menu_button)
	var fresh_button := _button("New Run", Callable(self, "start_generated_foundation_run"))
	fresh_button.custom_minimum_size = Vector2(160, MIN_NATIVE_TOUCH_TARGET_HEIGHT)
	button_row.add_child(fresh_button)


func _refresh() -> void:
	_invalidate_run_screen_layout()
	_invalidate_travel_view_cache()
	var has_run := run_state != null
	if not has_run or current_screen == SCREEN_START:
		_hide_run_menu()
		_set_current_screen(SCREEN_START)
		_render_start_screen()
		return
	_evaluate_run_terminal_state()
	_render_environment_screen()
	_refresh_run_menu()


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
	status_label.text = _hud_status_text()
	if objective_label != null:
		objective_label.text = _objective_hud_text()
	_style_hud_for_recent_consequence()
	if save_status_label != null:
		save_status_label.text = _save_status_text()
	_refresh_active_item_slot()
	_apply_focus_layout()
	_refresh_environment_result_feedback()
	_render_victory_summary()
	_render_failure_summary()
	_render_result_panel()
	_render_foundation_snapshots()
	_render_action_panel()
	_refresh_world_map_overlay()
	_update_procedural_music()


func _refresh_world_header() -> void:
	if run_state == null or title_label == null or summary_label == null:
		return
	var environment := run_state.current_environment
	var game_focus_mode := _is_game_focus_mode()
	if _is_victory_screen():
		var victory_snapshot := _victory_summary_snapshot()
		title_label.text = str(victory_snapshot.get("title", "Demo Victory"))
		summary_label.text = str(victory_snapshot.get("message", "The run is complete."))
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
		var selected_world_object := _interactable_object(selected_object_id)
		if selected_world_object.is_empty():
			title_label.text = str(environment.get("display_name", environment.get("id", "Environment")))
			var room_description := str(environment.get("visual_context", {}).get("description", ""))
			summary_label.text = "%s Click objects to inspect; double-click glowing props to act." % room_description if not room_description.is_empty() else "Click objects to inspect; double-click glowing props to act."
		else:
			title_label.text = "%s / %s" % [str(environment.get("display_name", environment.get("id", "Environment"))), str(selected_world_object.get("label", "Object"))]
			summary_label.text = _world_object_summary_text(selected_world_object)
	summary_label.max_lines_visible = 1 if game_focus_mode else 2


func _render_action_panel() -> void:
	_rebuild_actions()


func _render_result_panel() -> void:
	_refresh_consequence_labels()


func _world_object_summary_text(object_data: Dictionary) -> String:
	var parts: Array[String] = []
	for key in ["short_description", "choice_summary", "cost_summary", "effect_summary", "impact_summary", "risk_summary", "action_summary", "disabled_reason"]:
		var text := str(object_data.get(key, "")).strip_edges()
		if text.is_empty():
			continue
		if key == "risk_summary" and not text.begins_with("Risk:"):
			text = "Risk: %s" % text
		elif key == "impact_summary" and not text.begins_with("Impact:"):
			text = "Impact: %s" % text
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
	procedural_music_player.play_for_environment_state(run_state.current_environment, run_state.suspicion_level(), music_fx_state_snapshot())


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
		"bankroll": run_state.bankroll,
		"economy": run_state.economy(),
		"bankroll_pressure": _music_bankroll_pressure_amount(),
		"debt": debt_status.get("debt", []),
		"debt_count": int(debt_status.get("debt_count", 0)),
		"overdue_debt_count": int(debt_status.get("overdue_debt_count", 0)),
		"overdue_debt": bool(debt_status.get("overdue_debt", false)),
		"win_streak": int(win_status.get("win_streak", 0)),
		"big_win": bool(win_status.get("big_win", false)),
		"big_win_bars_remaining": int(win_status.get("big_win_bars_remaining", 0)),
		"last_bankroll_delta": int(win_status.get("last_bankroll_delta", 0)),
}


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
			result["big_win_bars_remaining"] = 4 if delta >= 50 else 0
			captured_latest = true
		if delta > 0:
			streak += 1
			continue
		break
	result["win_streak"] = streak
	return result


func _stop_procedural_music() -> void:
	if procedural_music_player != null:
		procedural_music_player.stop()


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
	if was_ducking and not ducking:
		_update_procedural_music()


func _stop_surface_feature_music() -> void:
	var was_ducking := surface_feature_music_ducking
	surface_feature_music_active = false
	surface_feature_music_ducking = false
	if procedural_music_player != null:
		procedural_music_player.stop_feature_music()
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
	if failure_summary_panel != null:
		failure_summary_panel.visible = failure_mode
		failure_summary_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if victory_summary_panel != null:
		victory_summary_panel.visible = victory_mode
		victory_summary_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL


func _apply_run_screen_layout() -> void:
	if run_screen == null or run_hud_panel == null or visual_panel_container == null:
		return
	var screen_size := run_screen.size
	if screen_size.x <= 0.0 or screen_size.y <= 0.0:
		screen_size = get_viewport_rect().size
	if screen_size.x <= 0.0 or screen_size.y <= 0.0:
		return
	if not run_layout_dirty and run_layout_last_screen_size == screen_size:
		return
	var proportional_info_height: float = floor(screen_size.y * RUN_INFO_BAND_RATIO)
	var hud_content_height: float = ceil(run_hud_panel.get_combined_minimum_size().y)
	var max_info_height: float = floor(screen_size.y * 0.35)
	var info_height := minf(maxf(maxf(RUN_INFO_MIN_HEIGHT, proportional_info_height), hud_content_height), max_info_height)
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


func _render_failure_summary() -> void:
	if failure_summary_panel == null:
		return
	if not _is_failure_screen():
		failure_summary_panel.visible = false
		return
	failure_summary_panel.visible = true
	var snapshot := _failure_summary_snapshot()
	if failure_summary_title_label != null:
		failure_summary_title_label.text = str(snapshot.get("title", "Run Failed"))
	if failure_summary_body_label != null:
		failure_summary_body_label.text = str(snapshot.get("message", "The run is over."))
	if failure_summary_list == null:
		return
	_clear(failure_summary_list)
	_add_failure_summary_section("Failure", [
		"Reason: %s" % str(snapshot.get("reason_label", "Run failed")),
		"Status: %s" % str(snapshot.get("run_status", "")),
		"Seed: %s" % str(snapshot.get("seed", "")),
	])
	_add_failure_summary_section("Money And Heat", [
		"Bankroll: %d" % int(snapshot.get("bankroll", 0)),
		"Economy: %s" % str(snapshot.get("economy", "")),
		"Heat: %d / 100, %s" % [int(snapshot.get("heat", 0)), str(snapshot.get("heat_label", ""))],
	])
	_add_failure_summary_section("Score", _copy_array(snapshot.get("score_lines", [])))
	_add_failure_summary_section("Alcohol And Luck", _copy_array(snapshot.get("alcohol_lines", [])))
	_add_failure_summary_section("Where It Ended", [
		"Current room: %s" % str(snapshot.get("current_environment", "")),
		"Room type: %s" % str(snapshot.get("environment_kind", "")),
		"Visited: %s" % str(snapshot.get("visited_summary", "")),
	])
	_add_failure_summary_section("Travel", _copy_array(snapshot.get("travel_lines", [])))
	_add_failure_summary_section("Items", _copy_array(snapshot.get("item_lines", [])))
	_add_failure_summary_section("Debt", _copy_array(snapshot.get("debt_lines", [])))
	_add_failure_summary_section("Recent Result", _copy_array(snapshot.get("recent_result_lines", [])))
	_add_failure_summary_section("Story", _copy_array(snapshot.get("story_lines", [])))


func _render_victory_summary() -> void:
	if victory_summary_panel == null:
		return
	if not _is_victory_screen():
		victory_summary_panel.visible = false
		return
	victory_summary_panel.visible = true
	var snapshot := _victory_summary_snapshot()
	if victory_summary_title_label != null:
		victory_summary_title_label.text = str(snapshot.get("title", "Demo Victory"))
	if victory_summary_body_label != null:
		victory_summary_body_label.text = str(snapshot.get("message", "The run is complete."))
	if victory_summary_list == null:
		return
	_clear(victory_summary_list)
	_add_victory_summary_section("Victory", [
		"Route: %s" % str(snapshot.get("route_label", snapshot.get("route", ""))),
		"Status: %s" % str(snapshot.get("run_status", "")),
		"Seed: %s" % str(snapshot.get("seed", "")),
		str(snapshot.get("next_act_line", "")),
	])
	_add_victory_summary_section("Final Money And Heat", [
		"Bankroll: %d" % int(snapshot.get("bankroll", 0)),
		"Economy: %s" % str(snapshot.get("economy", "")),
		"Heat: %d / 100, %s" % [int(snapshot.get("heat", 0)), str(snapshot.get("heat_label", ""))],
	])
	_add_victory_summary_section("Score", _copy_array(snapshot.get("score_lines", [])))
	_add_victory_summary_section("Alcohol And Luck", _copy_array(snapshot.get("alcohol_lines", [])))
	_add_victory_summary_section("Venues", [
		"Current room: %s" % str(snapshot.get("current_environment", "")),
		"Room type: %s" % str(snapshot.get("environment_kind", "")),
		"Visited: %s" % str(snapshot.get("visited_summary", "")),
	])
	_add_victory_summary_section("Items", _copy_array(snapshot.get("item_lines", [])))
	_add_victory_summary_section("Debt", _copy_array(snapshot.get("debt_lines", [])))
	_add_victory_summary_section("Story", _copy_array(snapshot.get("story_lines", [])))


func _add_victory_summary_section(title: String, lines: Array) -> void:
	_add_terminal_summary_section(victory_summary_list, title, lines, VisualStyle.TEAL)


func _add_failure_summary_section(title: String, lines: Array) -> void:
	_add_terminal_summary_section(failure_summary_list, title, lines, VisualStyle.PINK if title == "Failure" else VisualStyle.CYAN)


func _add_terminal_summary_section(target_list: VBoxContainer, title: String, lines: Array, accent: Color) -> void:
	if target_list == null:
		return
	var clean_lines: Array[String] = []
	for line in lines:
		var text := _player_facing_text(str(line)).strip_edges()
		if not text.is_empty():
			clean_lines.append(text)
	if clean_lines.is_empty():
		return
	var panel := _panel_container(VisualStyle.DARK_3, accent)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target_list.add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 3)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(stack)
	var title_label := _section(title)
	_set_control_font_color(title_label, accent)
	stack.add_child(title_label)
	for line in clean_lines:
		var label := _label(line, 12)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stack.add_child(label)


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


func _rebuild_actions() -> void:
	stake_input = null
	_clear(actions_list)
	_render_focused_context_panel()


func _render_focused_context_panel() -> void:
	var object_data := _interactable_object(selected_object_id)
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
		var button := _button(label, Callable(self, "focus_interactable_object").bind(object_id))
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
	card.add_child(_label("Type: %s" % _context_type_label(object_type), 12))
	var description := str(object_data.get("short_description", ""))
	if not description.is_empty():
		card.add_child(_label(description, 13))
	var cost := str(object_data.get("cost_summary", ""))
	if not cost.is_empty():
		card.add_child(_label(cost, 13))
	var risk := str(object_data.get("risk_summary", ""))
	if not risk.is_empty():
		card.add_child(_label("Risk: %s" % risk, 13))
	if object_type == CONTEXT_MODE_TRAVEL:
		for preview_line in _copy_array(object_data.get("preview_lines", [])).slice(0, 4):
			var preview_text := str(preview_line).strip_edges()
			if not preview_text.is_empty():
				card.add_child(_muted_label(preview_text, 12))
		var unlock_lines := _copy_array(object_data.get("unlock_conditions", []))
		if not unlock_lines.is_empty():
			card.add_child(_muted_label("Unlock: %s" % "; ".join(unlock_lines.slice(0, 2)), 12))
	var effect := str(object_data.get("effect_summary", ""))
	if not effect.is_empty():
		card.add_child(_label("Effect: %s" % effect, 13))
	if object_type == CONTEXT_MODE_GAME:
		_add_game_object_context_details(card, str(object_data.get("source_id", "")))
	var action_summary := str(object_data.get("action_summary", ""))
	var disabled_reason := str(object_data.get("disabled_reason", "Not available right now.")) if not enabled else ""
	if not enabled and action_summary == disabled_reason:
		action_summary = ""
	if not action_summary.is_empty():
		if enabled:
			card.add_child(_label(action_summary, 13))
		else:
			card.add_child(_muted_label(action_summary, 13))
	if not enabled:
		if disabled_reason.strip_edges().is_empty():
			disabled_reason = "Not available right now."
		card.add_child(_muted_label(disabled_reason, 13))
	_add_context_object_actions(card, object_data)
	_add_card_button(card, "Back to room", Callable(self, "clear_interaction_focus"))


func _add_context_object_actions(card: VBoxContainer, object_data: Dictionary) -> void:
	if not bool(object_data.get("enabled", true)):
		return
	var object_type := str(object_data.get("object_type", "info"))
	var source_id := str(object_data.get("source_id", ""))
	match object_type:
		CONTEXT_MODE_GAME:
			card.add_child(_muted_label("Double-click the machine to enter.", 13))
		CONTEXT_MODE_EVENT:
			_add_context_event_actions(card, source_id)
		CONTEXT_MODE_ITEM:
			_add_context_item_actions(card, source_id)
		CONTEXT_MODE_SHOPKEEPER:
			_add_context_shopkeeper_actions(card)
		CONTEXT_MODE_GAME_HOOK:
			_add_context_game_hook_actions(card, object_data)
		CONTEXT_MODE_TRAVEL:
			_add_context_travel_actions(card, source_id)
		CONTEXT_MODE_SERVICE:
			_add_context_service_actions(card, source_id)
		CONTEXT_MODE_LENDER:
			_add_context_lender_actions(card, source_id)
		CONTEXT_MODE_PRESTIGE:
			_add_context_prestige_actions(card, source_id)


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
	for choice in event_option.get("choices", []):
		if typeof(choice) != TYPE_DICTIONARY:
			continue
		var choice_data: Dictionary = choice
		var choice_id := str(choice_data.get("id", ""))
		if choice_id.is_empty():
			continue
		_add_event_choice_action_option(card, event_id, choice_data)


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
		stack.add_child(detail_label)
	var consequence_summary := str(choice_data.get("consequence_summary", "")).strip_edges()
	if not consequence_summary.is_empty():
		stack.add_child(_muted_label("Effect: %s" % consequence_summary, 11))


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
			"selected": event_id == selected_event_id and choice_id == selected_event_choice_id,
		})
	return actions


func _add_context_item_actions(card: VBoxContainer, item_id: String) -> void:
	var offer := _item_offer(item_id)
	if offer.is_empty():
		card.add_child(_muted_label("That offer is no longer available.", 13))
		return
	if selected_item_offer_id == item_id:
		_add_card_button(card, "Buy", Callable(self, "confirm_selected_item_offer"), false, true)
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
			var line := "%s - %s, cost %d" % [
				str(choice.get("label", choice.get("id", "Route"))),
				str(choice.get("distance", "near")),
				int(choice.get("cost", 0)),
			]
			if not bool(choice.get("enabled", true)):
				line += " (locked)"
			card.add_child(_muted_label(line, 12))
		if not selected_travel_target_id.is_empty():
			_add_card_button(card, "Travel to %s" % selected_travel_label, Callable(self, "confirm_selected_travel"), false, true)
		_add_card_button(card, "Open Map", Callable(self, "open_world_map"), selected_travel_target_id.is_empty(), selected_travel_target_id.is_empty())
		return
	var choice := _travel_choice(target_id)
	if choice.is_empty():
		card.add_child(_muted_label("That route is no longer available.", 13))
		return
	for preview_line in _copy_array(choice.get("preview_lines", [])).slice(0, 4):
		var preview_text := str(preview_line).strip_edges()
		if not preview_text.is_empty():
			card.add_child(_muted_label(preview_text, 12))
	var risk_summary := _travel_risk_summary(choice)
	if not risk_summary.is_empty():
		card.add_child(_label("Risk: %s" % risk_summary, 13))
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
	if not bool(option.get("enabled", true)):
		card.add_child(_muted_label(str(option.get("disabled_reason", "Lender cannot be used right now.")), 13))
		return
	if selected_lender_hook_id == lender_id:
		_add_card_button(card, "Use %s" % selected_lender_hook_label, Callable(self, "confirm_selected_lender_hook"), false, true)
	else:
		_add_card_button(card, "Select lender", Callable(self, "select_lender_hook").bind(lender_id))


func _add_context_prestige_actions(card: VBoxContainer, purchase_id: String) -> void:
	var option := _prestige_purchase_option(purchase_id)
	if option.is_empty():
		card.add_child(_muted_label("No prestige target is available right now.", 13))
		return
	if not bool(option.get("enabled", false)):
		card.add_child(_muted_label(str(option.get("disabled_reason", "This target is locked for now.")), 13))
		return
	if selected_prestige_purchase_id == purchase_id:
		_add_card_button(card, "Claim victory: %s" % selected_prestige_purchase_label, Callable(self, "confirm_selected_prestige_purchase"), false, true)
	else:
		_add_card_button(card, "Select prestige target", Callable(self, "select_prestige_purchase").bind(purchase_id))


func _context_border_color(object_type: String, enabled: bool) -> Color:
	if not enabled:
		return VisualStyle.ORANGE
	match object_type:
		CONTEXT_MODE_GAME:
			return VisualStyle.CYAN
		CONTEXT_MODE_EVENT:
			return VisualStyle.AMBER
		CONTEXT_MODE_ITEM:
			return VisualStyle.TEAL
		CONTEXT_MODE_SHOPKEEPER:
			return VisualStyle.YELLOW
		CONTEXT_MODE_GAME_HOOK:
			return VisualStyle.YELLOW
		CONTEXT_MODE_TRAVEL:
			return VisualStyle.PURPLE_2
		CONTEXT_MODE_SERVICE, CONTEXT_MODE_LENDER:
			return VisualStyle.YELLOW
		CONTEXT_MODE_PRESTIGE:
			return VisualStyle.AMBER
		_:
			return VisualStyle.CYAN_2


func _context_type_label(object_type: String) -> String:
	match object_type:
		CONTEXT_MODE_GAME:
			return "Game"
		CONTEXT_MODE_EVENT:
			return "Event"
		CONTEXT_MODE_ITEM:
			return "Item"
		CONTEXT_MODE_SHOPKEEPER:
			return "Shopkeeper"
		CONTEXT_MODE_GAME_HOOK:
			return "Game Clerk"
		CONTEXT_MODE_TRAVEL:
			return "Travel"
		CONTEXT_MODE_SERVICE:
			return "Service"
		CONTEXT_MODE_LENDER:
			return "Lender"
		CONTEXT_MODE_PRESTIGE:
			return "Prestige"
		_:
			return "Info"


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
			for item_type in [CONTEXT_MODE_ITEM, CONTEXT_MODE_SHOPKEEPER, CONTEXT_MODE_GAME_HOOK, CONTEXT_MODE_SERVICE, CONTEXT_MODE_LENDER]:
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
	actions_list.add_child(_label("Current bankroll: %d" % run_state.bankroll, 12))
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
	var stake := selected_stake
	if stake <= 0:
		stake = _default_stake()
	if not skip_stake_validation and not _is_valid_stake(stake):
		var range := _stake_range()
		_show_message("Stake must be between %d and %d." % [int(range.get("min", 1)), int(range.get("max", 1))])
		_refresh_stake_input()
		return
	var wager_cost := _wager_cost_for_action(action_id, stake)
	if not wager_confirmed and _wager_needs_final_bankroll_confirmation(wager_cost):
		_pause_repeating_surface_action_for_wager_confirmation()
		_show_wager_confirmation_popup(action_id, stake, wager_cost, skip_stake_validation, preserve_surface_ui_state)
		return
	var confirmed_all_in_wager := wager_confirmed and _wager_needs_final_bankroll_confirmation(wager_cost)
	if confirmed_all_in_wager:
		run_state.begin_deferred_bankroll_zero_resolution()
	var rng := run_state.create_rng()
	var result := current_game.resolve_with_context(action_id, stake, run_state, run_state.current_environment, rng, _current_game_surface_ui_state())
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
	last_game_result = result.duplicate(true)
	pending_all_in_result_terminal_check = confirmed_all_in_wager and bool(result.get("ok", false)) and run_state != null and run_state.bankroll <= 0 and not bool(result.get("won", false))
	if runtime_tick_in_progress:
		if game_surface_canvas != null and current_screen == SCREEN_GAME:
			game_surface_canvas.render_game_snapshot(_game_view_snapshot())
		return
	if not preserve_surface_ui_state:
		game_surface_ui_state = {}
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
		_refresh()
		return
	_refresh()


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


func _wager_needs_final_bankroll_confirmation(wager_cost: int) -> bool:
	if run_state == null or wager_cost <= 0:
		return false
	return run_state.bankroll > 0 and run_state.bankroll - wager_cost <= 0


func _pause_environment_runtime_for_wager_confirmation(game: GameModule, _game_id: String) -> void:
	if game == null or run_state == null:
		return
	var command := game.surface_pause_repeating_action_for_confirmation({}, run_state, run_state.current_environment)
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
	var confirmed_all_in_wager := wager_confirmed and _wager_needs_final_bankroll_confirmation(wager_cost)
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
	pending_all_in_result_terminal_check = confirmed_all_in_wager and bool(result.get("ok", false)) and run_state != null and run_state.bankroll <= 0 and not bool(result.get("won", false))
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
		procedural_music_player.update_feature_music_state({
			"active": true,
			"feature_scene": feature_scene,
			"feature_music": feature_music,
			"cue_id": normalized_cue,
			"duck_background_music": should_duck,
		})
		_set_surface_feature_music_state(true, should_duck)
		return
	procedural_music_player.play_feature_stinger(normalized_cue, context)


func _slot_runtime_feature_audio_cue(runtime_state: Dictionary) -> String:
	var cue := str(runtime_state.get("slot_feature_audio_cue", ""))
	return cue if not cue.is_empty() else "bonus_start"


func _show_wager_confirmation_popup(action_id: String, stake: int, wager_cost: int, skip_stake_validation: bool, preserve_surface_ui_state: bool, source_game_id: String = "") -> void:
	if event_choice_popup_overlay == null or event_choice_popup_choices_list == null:
		_show_message("This bet risks your last cash. Click again to confirm.")
		return
	pending_wager_confirm_action_id = action_id
	pending_wager_confirm_skip_stake_validation = skip_stake_validation
	pending_wager_confirm_preserve_surface_ui_state = preserve_surface_ui_state
	pending_wager_confirm_stake = stake
	pending_wager_confirm_source_game_id = source_game_id
	var action_label := _wager_confirmation_action_label(action_id, source_game_id)
	var summary := "Betting $%d risks your last cash. If this play loses, the run ends after the result finishes resolving." % wager_cost
	pending_event_choice_popup_event_id = ""
	pending_event_choice_popup_focus_choice_id = ""
	pending_event_choice_popup_snapshot = {
		"visible": true,
		"blocking": true,
		"popup_type": "wager_confirmation",
		"interaction_kind": "blocking_decision",
		"dismissible": false,
		"summary": summary,
		"action_id": action_id,
		"action_label": action_label,
		"stake": stake,
		"wager_cost": wager_cost,
		"choices": [
			{"id": "confirm", "label": "Confirm Bet", "text": "Resolve %s at stake %d." % [action_label, stake], "consequence_summary": "Loss can end the run."},
			{"id": "cancel", "label": "Change Stake", "text": "Return to the game surface.", "consequence_summary": "No wager placed."},
		],
	}
	if event_choice_popup_title_label != null:
		event_choice_popup_title_label.text = "All-in wager"
	if event_choice_popup_summary_label != null:
		event_choice_popup_summary_label.text = summary
	_clear(event_choice_popup_choices_list)
	_add_wager_confirmation_card("Confirm Bet", "Resolve %s at stake %d." % [action_label, stake], "Loss can end the run.", Callable(self, "confirm_pending_wager_action"), true)
	_add_wager_confirmation_card("Change Stake", "Return to the game surface.", "No wager placed.", Callable(self, "cancel_pending_wager_confirmation"), false)
	event_choice_popup_overlay.visible = true
	event_choice_popup_overlay.move_to_front()
	_position_event_choice_popup()
	call_deferred("_position_event_choice_popup")


func _add_wager_confirmation_card(label: String, text: String, impact: String, callback: Callable, primary: bool) -> void:
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
	stack.add_child(heading)
	stack.add_child(_label(text, 13))
	stack.add_child(_muted_label("Impact: %s" % impact, 12))
	var button := _button(label, callback)
	if primary:
		_style_selected_button(button)
	stack.add_child(button)


func _clear_pending_wager_confirmation() -> void:
	pending_wager_confirm_action_id = ""
	pending_wager_confirm_skip_stake_validation = false
	pending_wager_confirm_preserve_surface_ui_state = false
	pending_wager_confirm_stake = 0
	pending_wager_confirm_source_game_id = ""


func serialized_run_state() -> Dictionary:
	if run_state == null:
		return {}
	return run_state.to_dict()


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


func current_failure_summary_snapshot() -> Dictionary:
	if run_state == null:
		return {}
	return _failure_summary_snapshot()


func current_victory_summary_snapshot() -> Dictionary:
	if run_state == null:
		return {}
	return _victory_summary_snapshot()


func current_action_category_snapshot() -> Dictionary:
	if run_state == null:
		return {}
	return {
		"selected_id": selected_action_category,
		"categories": _action_category_view_list(),
	}


func current_screen_snapshot() -> Dictionary:
	return {
		"screen": current_screen,
		"selected_category": selected_action_category,
		"has_run": run_state != null,
		"start_menu": current_start_menu_snapshot(),
		"has_game": current_game != null,
		"run_menu_visible": _run_menu_is_visible(),
		"run_menu": current_run_menu_snapshot(),
		"run_journal_visible": _run_journal_popup_is_visible(),
		"failure_summary": _failure_summary_snapshot() if run_state != null and run_state.run_status == RunState.RUN_STATUS_FAILED else {},
		"victory_summary": _victory_summary_snapshot() if run_state != null and run_state.run_status == RunState.RUN_STATUS_ENDED else {},
		"travel_transition_active": travel_transition_active,
		"travel_transition_target_id": travel_transition_target_id,
		"travel_transition_target_label": travel_transition_target_label,
		"world_map_overlay_visible": world_map_overlay != null and world_map_overlay.visible,
		"selected_world_map_node_id": selected_world_map_node_id,
		"world_map_detail_text": world_map_detail_label.text if world_map_detail_label != null else "",
		"world_map_confirm_enabled": world_map_confirm_button != null and not world_map_confirm_button.disabled,
		"world_map": _world_map_snapshot() if run_state != null else {},
		"conclusion_animation": current_conclusion_animation_snapshot(),
		"accessibility": current_accessibility_snapshot(),
	}


func current_start_menu_snapshot() -> Dictionary:
	return {
		"seed_text": seed_input.text if seed_input != null else "",
		"content_groups": _content_group_option_snapshot(),
		"selected_content_groups": _selected_content_groups_for_new_run(),
		"content_group_status": content_group_status_label.text if content_group_status_label != null else "",
		"content_group_config_visible": content_group_panel.visible if content_group_panel != null else false,
		"challenges": _challenge_option_snapshot(),
		"selected_challenge_id": selected_challenge_id,
		"challenge_status": challenge_status_label.text if challenge_status_label != null else "",
		"challenge_config_visible": challenge_panel.visible if challenge_panel != null else false,
		"menu_panel_size": main_menu_panel.custom_minimum_size if main_menu_panel != null else Vector2.ZERO,
	}


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
	var snapshot := {
		"visible": _run_inventory_popup_is_visible(),
		"mode": run_inventory_popup_mode,
		"items": _inventory_item_view_list(),
		"merchant_available": _shopkeeper_available() if run_state != null else false,
		"shop_description": _shop_description() if run_state != null else "",
	}
	if _run_inventory_popup_is_visible():
		_position_run_inventory_popup()
		snapshot["anchor"] = "screen_center"
		snapshot["interaction_kind"] = "inventory" if run_inventory_popup_mode == "inspect" else "merchant_sale"
		if run_inventory_panel != null:
			snapshot["popup_rect"] = _rect_to_dict(run_inventory_panel.get_global_rect())
		if run_inventory_overlay != null:
			snapshot["screen_rect"] = _rect_to_dict(run_inventory_overlay.get_global_rect())
		if environment_canvas != null:
			snapshot["environment_rect"] = _rect_to_dict(environment_canvas.get_global_rect())
	return snapshot


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
	var pressure := _run_pressure_view()
	var prestige := _primary_prestige_option()
	var demo_objective := _demo_objective_status()
	var hud := _run_status_hud_model()
	var guidance: Dictionary = hud.get("objective_guidance", {})
	return {
		"text": _objective_hud_text(),
		"goal": _objective_goal_text(prestige, pressure, demo_objective),
		"objective_state": str(guidance.get("state", _objective_presentation_state(pressure, demo_objective))),
		"guidance": guidance,
		"bankroll": run_state.bankroll,
		"economy": _economy_cue_text(),
		"heat": run_state.security_pressure_label(),
		"alcohol": run_state.alcohol_pressure_summary(),
		"pressure": _pressure_status_text(pressure),
		"next_hint": _next_opportunity_hint(),
		"next_objective": hud.get("next_objective", {}),
		"prestige": prestige,
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
	selected_object_id = object_id
	focus_target_id = object_id
	current_context_mode = str(object_data.get("object_type", CONTEXT_MODE_ROOM))
	camera_focus_rect = _rect_from_dict(object_data.get("focus_rect", {}))
	camera_focus_point = _vector2_from_dict(object_data.get("focus_point", {}), Vector2(0.5, 0.5))
	if environment_canvas != null:
		environment_canvas.set_selected_object(object_id)
		if run_state != null:
			_render_foundation_snapshots()
			_refresh_world_header()
	if actions_list != null:
		_render_action_panel()
	return true


func activate_interactable_object(object_id: String) -> bool:
	if object_id == "travel:leave":
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
	if _event_choice_popup_is_visible():
		_show_message("Choose a response before doing anything else.")
		return false
	if object_id.begins_with("event_response:"):
		return _activate_event_response_action(object_id)
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
			enter_game(source_id)
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
		CONTEXT_MODE_TRAVEL:
			if source_id == "leave":
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
			if select_lender_hook(source_id):
				return confirm_selected_lender_hook()
			return false
		CONTEXT_MODE_PRESTIGE:
			if select_prestige_purchase(source_id):
				return confirm_selected_prestige_purchase()
			return false
	_show_message("Inspect this first.")
	_refresh()
	return false


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
	pending_event_choice_popup_snapshot = {
		"visible": true,
		"blocking": false,
		"popup_type": "interactable_event",
		"interaction_kind": "event",
		"dismissible": true,
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
	if not has_explicit_dismissal:
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
		var delay := float(index) * 0.045
		var duration := 0.62 + float(index % 3) * 0.06
		tween.tween_property(bill, "position", end + Vector2(float(index % 2) * 3.0, 0.0), duration).set_delay(delay)
		tween.parallel().tween_property(bill, "modulate:a", 0.0, duration * 0.45).set_delay(delay + duration * 0.55)
	var cleanup := create_tween()
	cleanup.tween_interval(0.94)
	cleanup.tween_callback(Callable(self, "_finish_conclusion_animation"))


func _finish_conclusion_animation() -> void:
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
		environment_canvas.set_selected_object("", not animate_camera_return)
		if run_state != null:
			_render_foundation_snapshots()
			_refresh_world_header()
	if actions_list != null:
		_render_action_panel()


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
		environment_canvas.render_environment_snapshot(_environment_view_snapshot())
	if game_surface_canvas != null:
		game_surface_canvas.set_game_module(current_game)
		if game_visible:
			game_surface_canvas.render_game_snapshot(_game_view_snapshot())


func _environment_view_snapshot() -> Dictionary:
	var snapshot := run_state.current_environment.duplicate(true)
	var recent_result := _recent_result_snapshot()
	var recent_deltas: Dictionary = recent_result.get("deltas", {})
	snapshot["suspicion_level"] = run_state.suspicion_level()
	snapshot["drunk_level"] = run_state.drunk_level
	snapshot["drunk_time_scale"] = run_state.drunk_time_scale()
	snapshot["drunk_time_scale_percent"] = run_state.drunk_time_scale_percent()
	snapshot["drunk_world_speed_percent"] = run_state.drunk_time_scale_percent()
	snapshot["pending_drunk_absorption"] = run_state.pending_drunk_absorption_amount()
	snapshot["drunk_distortion_suppression_turns"] = run_state.drunk_distortion_suppression_turns
	snapshot["drunk_effect_mode"] = _drunk_effect_mode()
	snapshot["reduce_motion"] = _reduce_motion_enabled()
	snapshot["high_contrast"] = _high_contrast_enabled()
	snapshot["accessibility"] = current_accessibility_snapshot()
	snapshot["alcoholic_level"] = run_state.alcoholic_level
	snapshot["baseline_luck"] = run_state.baseline_luck
	snapshot["luck_modifier"] = run_state.effective_luck()
	snapshot["alcohol_condition"] = run_state.alcohol_condition_label()
	snapshot["demo_objective"] = run_state.demo_objective_status()
	snapshot["pit_boss_watch"] = run_state.pit_boss_watch_status(run_state.current_environment)
	snapshot["travel_choices"] = _travel_choice_view_list()
	snapshot["selected_travel_target_id"] = selected_travel_target_id
	snapshot["selected_travel_label"] = selected_travel_label
	snapshot["event_cadence"] = run_state.event_cadence_summary()
	snapshot["world_map_overlay_visible"] = world_map_overlay != null and world_map_overlay.visible
	snapshot["world_map"] = _world_map_snapshot() if bool(snapshot["world_map_overlay_visible"]) else {}
	snapshot["event_options"] = _eligible_event_option_view_list()
	snapshot["selected_event_id"] = selected_event_id
	snapshot["selected_event_choice_id"] = selected_event_choice_id
	snapshot["selected_event_label"] = selected_event_label
	snapshot["selected_event_choice_label"] = selected_event_choice_label
	snapshot["item_offers"] = _item_offer_view_list()
	snapshot["inventory_items"] = _inventory_item_view_list()
	snapshot["shopkeeper_available"] = _shopkeeper_available()
	snapshot["selected_item_offer_id"] = selected_item_offer_id
	snapshot["selected_item_offer_label"] = selected_item_offer_label
	snapshot["selected_item_offer_price"] = selected_item_offer_price
	snapshot["last_item_result"] = last_item_result.duplicate(true)
	snapshot["service_options"] = _service_hook_view_list()
	snapshot["lender_options"] = _lender_hook_view_list()
	snapshot["selected_service_hook_id"] = selected_service_hook_id
	snapshot["selected_service_hook_label"] = selected_service_hook_label
	snapshot["selected_lender_hook_id"] = selected_lender_hook_id
	snapshot["selected_lender_hook_label"] = selected_lender_hook_label
	snapshot["last_hook_result"] = last_hook_result.duplicate(true)
	snapshot["interactable_objects"] = _interactable_object_view_list()
	snapshot["recent_result"] = recent_result
	snapshot["outcome_object_id"] = _outcome_object_id(recent_result)
	snapshot["outcome_message"] = _outcome_message(recent_result)
	snapshot["outcome_bankroll_delta"] = int(recent_result.get("bankroll_delta", recent_deltas.get("bankroll_delta", 0)))
	snapshot["outcome_suspicion_delta"] = int(recent_result.get("suspicion_delta", recent_deltas.get("suspicion_delta", 0)))
	return snapshot


func _interactable_object_view_list() -> Array:
	if run_state == null or library == null:
		return []
	var objects: Array = []
	var run_failed_without_recovery := _run_failed_without_recovery()
	var failed_reason := _pressure_status_text(_run_pressure_view())
	if failed_reason.strip_edges().is_empty():
		failed_reason = "Run failed."
	var game_ids := _string_array(run_state.current_environment.get("game_ids", []))
	for index in range(game_ids.size()):
		var game_id := str(game_ids[index])
		var game_object_id := "game:%s" % game_id
		var definition := library.game(game_id)
		var game_runtime_state := _environment_game_runtime_state(game_id)
		var game_object_state := _environment_game_object_state(game_id)
		var authored_runtime_state := _copy_dict(game_object_state.get("runtime_state", {}))
		var merged_runtime_state := game_runtime_state.duplicate(true)
		for runtime_key in authored_runtime_state.keys():
			merged_runtime_state[runtime_key] = authored_runtime_state[runtime_key]
		var label := str(definition.get("display_name", _label_from_id(game_id)))
		var description := str(definition.get("description", ""))
		if description.is_empty():
			description = str(definition.get("intro", "Choose a stake on the surface, then click an action."))
		var runtime_status := str(merged_runtime_state.get("status_label", "")).strip_edges()
		if not runtime_status.is_empty():
			description = "%s Status: %s." % [description, runtime_status]
		var enabled := not definition.is_empty() and not run_failed_without_recovery
		objects.append(_make_interactable_object({
			"object_id": game_object_id,
			"object_type": CONTEXT_MODE_GAME,
			"source_id": game_id,
			"label": label,
			"short_description": description,
			"presence": "fixture",
			"enabled": enabled,
			"disabled_reason": "" if enabled else failed_reason if run_failed_without_recovery else "Game definition is missing.",
			"action_summary": "Double-click this machine to enter." if enabled else "This game is unavailable.",
			"status_summary": str(game_object_state.get("status_summary", "")),
			"effect_summary": str(game_object_state.get("effect_summary", "")),
			"impact_summary": str(game_object_state.get("impact_summary", "")),
			"state_badge": str(game_object_state.get("state_badge", "")),
			"risk_summary": _risk_cue_text(),
			"runtime_state": merged_runtime_state,
			"visual_state": _copy_dict(game_object_state.get("visual_state", {})),
			"visual_key": str(definition.get("family", definition.get("type", "game"))),
			"prop": str(definition.get("environment_prop", definition.get("prop", "card_table"))),
			"icon_key": str(definition.get("icon_key", game_id)),
			"asset_path": str(definition.get("asset_path", "")),
			"available_actions": [{"id": "enter_game", "label": "Double-click to enter"}] if enabled else [],
			"confirm_action_id": "enter_game" if enabled else "",
			"focus_rect": _interaction_rect_for_object(game_object_id, CONTEXT_MODE_GAME, index),
		}))
	var event_options := _eligible_event_option_view_list()
	for index in range(event_options.size()):
		if typeof(event_options[index]) != TYPE_DICTIONARY:
			continue
		var event_data: Dictionary = event_options[index]
		var event_id := str(event_data.get("id", ""))
		if event_id.is_empty():
			continue
		var choices: Array = event_data.get("choices", [])
		var event_enabled := not choices.is_empty() and not run_failed_without_recovery
		var event_object_id := "event:%s" % event_id
		objects.append(_make_interactable_object({
			"object_id": event_object_id,
			"object_type": CONTEXT_MODE_EVENT,
			"source_id": event_id,
			"label": str(event_data.get("display_name", _label_from_id(event_id))),
			"short_description": str(event_data.get("summary", "Something is happening here.")),
			"presence": "dynamic",
			"enabled": event_enabled,
			"disabled_reason": "" if event_enabled else failed_reason if run_failed_without_recovery else "No event choice is currently available.",
			"action_summary": str(event_data.get("start_summary", "Choose a response.")) if event_enabled else "No response is available right now.",
			"risk_summary": str(event_data.get("type", "")),
			"choice_summary": _event_choice_list_summary(choices),
			"visual_key": str(event_data.get("visual_key", event_data.get("type", "event"))),
			"prop": str(event_data.get("environment_prop", event_data.get("prop", ""))),
			"icon_key": str(event_data.get("icon_key", event_id)),
			"asset_path": str(event_data.get("asset_path", "")),
			"available_actions": [{"id": "inspect_event_choices", "label": "Review responses"}] if event_enabled else [],
			"inline_actions": _event_inline_response_actions(event_id, choices) if event_enabled else [],
			"confirm_action_id": "inspect_event_choices" if event_enabled else "",
			"focus_rect": _interaction_rect_for_object(event_object_id, CONTEXT_MODE_EVENT, index),
		}))
	var item_offers := _item_offer_view_list()
	for index in range(item_offers.size()):
		if typeof(item_offers[index]) != TYPE_DICTIONARY:
			continue
		var offer: Dictionary = item_offers[index]
		var item_id := str(offer.get("id", ""))
		if item_id.is_empty():
			continue
		var item_object_id := "item:%s" % item_id
		var affordable := bool(offer.get("affordable", true)) and not run_failed_without_recovery
		objects.append(_make_interactable_object({
			"object_id": item_object_id,
			"object_type": CONTEXT_MODE_ITEM,
			"source_id": item_id,
			"label": str(offer.get("display_name", _label_from_id(item_id))),
			"short_description": str(offer.get("description", "")),
			"presence": "dynamic",
			"enabled": affordable,
			"disabled_reason": "" if affordable else failed_reason if run_failed_without_recovery else "Not enough bankroll.",
			"action_summary": "Buy this item." if affordable else "Needs more bankroll before it can be used.",
			"effect_summary": str(offer.get("effect_summary", "")),
			"risk_summary": "",
			"cost_summary": "Cost: %d" % int(offer.get("price", 0)),
			"visual_key": "item",
			"prop": str(offer.get("environment_prop", "")),
			"surface": str(offer.get("surface", "counter")),
			"icon_key": str(offer.get("icon_key", item_id)),
			"asset_path": str(offer.get("asset_path", "")),
			"available_actions": [{"id": "buy_item", "label": "Buy"}] if affordable else [],
			"confirm_action_id": "buy_item" if affordable else "",
			"focus_rect": _interaction_rect_for_object(item_object_id, CONTEXT_MODE_ITEM, index),
		}))
	if _shopkeeper_should_draw():
		var shopkeeper_enabled := _shopkeeper_available() and not run_failed_without_recovery
		var disabled_reason := "" if shopkeeper_enabled else failed_reason if run_failed_without_recovery else "The counter is quiet right now."
		var shopkeeper_object_id := "shopkeeper:merchant"
		objects.append(_make_interactable_object({
			"object_id": shopkeeper_object_id,
			"object_type": CONTEXT_MODE_SHOPKEEPER,
			"source_id": "merchant",
			"label": _shopkeeper_label(),
			"short_description": _shop_description(),
			"presence": "fixture",
			"interactive": shopkeeper_enabled,
			"enabled": shopkeeper_enabled,
			"disabled_reason": disabled_reason,
			"action_summary": "Double-click to sell gear." if shopkeeper_enabled else disabled_reason,
			"effect_summary": "Merchant sales.",
			"risk_summary": "",
			"cost_summary": "",
			"visual_key": "shopkeeper",
			"icon_key": "service",
			"available_actions": [{"id": "talk_shopkeeper", "label": "Talk"}] if shopkeeper_enabled else [],
			"confirm_action_id": "talk_shopkeeper" if shopkeeper_enabled else "",
			"focus_rect": _interaction_rect_for_object(shopkeeper_object_id, CONTEXT_MODE_SHOPKEEPER, 0),
		}))
	objects.append_array(_game_hook_interactable_objects())
	var travel_choices := _travel_choice_view_list()
	if not travel_choices.is_empty():
		var first_choice: Dictionary = travel_choices[0] if typeof(travel_choices[0]) == TYPE_DICTIONARY else {}
		var any_enabled := false
		for choice_value in travel_choices:
			if typeof(choice_value) == TYPE_DICTIONARY and bool((choice_value as Dictionary).get("enabled", true)):
				any_enabled = true
				break
		var travel_object_id := "travel:leave"
		var travel_enabled := not run_failed_without_recovery
		var travel_disabled_reason := ""
		if run_failed_without_recovery:
			travel_disabled_reason = failed_reason
		var preview_lines: Array = []
		for choice_value in travel_choices.slice(0, 3):
			if typeof(choice_value) != TYPE_DICTIONARY:
				continue
			var choice: Dictionary = choice_value
			preview_lines.append("%s: %s, cost %d" % [
				str(choice.get("label", choice.get("id", "Route"))),
				str(choice.get("distance", "near")),
				int(choice.get("cost", 0)),
			])
		objects.append(_make_interactable_object({
			"object_id": travel_object_id,
			"object_type": CONTEXT_MODE_TRAVEL,
			"source_id": "leave",
			"label": "Leave",
			"short_description": "Open the city map and choose a revealed stop.",
			"enabled": travel_enabled,
			"disabled_reason": travel_disabled_reason,
			"action_summary": "Double-click to open the map." if any_enabled else "Open the map to inspect locked routes.",
			"risk_summary": _travel_risk_summary(first_choice),
			"impact_summary": _travel_preview_summary(first_choice),
			"cost_summary": "%d route(s)" % travel_choices.size(),
			"preview_lines": preview_lines,
			"unlock_conditions": [],
			"visual_key": "travel",
			"prop": "door",
			"icon_key": "travel",
			"available_actions": [{"id": "open_map", "label": "Open Map"}] if travel_enabled else [],
			"confirm_action_id": "open_map" if travel_enabled else "",
			"focus_rect": _interaction_rect_for_object(travel_object_id, CONTEXT_MODE_TRAVEL, 0),
		}))
	objects.append_array(_hook_interactable_objects(CONTEXT_MODE_SERVICE, _service_hook_view_list()))
	objects.append_array(_hook_interactable_objects(CONTEXT_MODE_LENDER, _lender_hook_view_list()))
	var prestige_options := _prestige_purchase_view_list()
	for index in range(prestige_options.size()):
		if typeof(prestige_options[index]) != TYPE_DICTIONARY:
			continue
		var prestige: Dictionary = prestige_options[index]
		var purchase_id := str(prestige.get("id", ""))
		if purchase_id.is_empty():
			continue
		var prestige_object_id := "prestige:%s" % purchase_id
		var prestige_enabled := bool(prestige.get("enabled", false)) and not run_failed_without_recovery
		objects.append(_make_interactable_object({
			"object_id": prestige_object_id,
			"object_type": CONTEXT_MODE_PRESTIGE,
			"source_id": purchase_id,
			"label": str(prestige.get("display_name", _label_from_id(purchase_id))),
			"short_description": str(prestige.get("description", "")),
			"enabled": prestige_enabled,
			"disabled_reason": "" if prestige_enabled else failed_reason if run_failed_without_recovery else str(prestige.get("disabled_reason", "This target is locked for now.")),
			"action_summary": "Double-click to claim victory." if prestige_enabled else "Prestige target locked.",
			"effect_summary": str(prestige.get("effect_summary", "")),
			"risk_summary": str(prestige.get("risk_summary", "")),
			"cost_summary": "Cost: %d" % int(prestige.get("cost", 0)),
			"visual_key": "prestige",
			"icon_key": "prestige",
			"available_actions": [{"id": "buy_prestige", "label": "Claim victory"}] if prestige_enabled else [],
			"confirm_action_id": "buy_prestige" if prestige_enabled else "",
			"focus_rect": _interaction_rect_for_object(prestige_object_id, CONTEXT_MODE_PRESTIGE, index),
		}))
	return objects


func _game_hook_interactable_objects(apply_failure_lock: bool = true) -> Array:
	var objects: Array = []
	if run_state == null or library == null:
		return objects
	var run_failed_without_recovery := _run_failed_without_recovery() if apply_failure_lock else false
	var failed_reason := ""
	if apply_failure_lock:
		failed_reason = _pressure_status_text(_run_pressure_view())
		if failed_reason.strip_edges().is_empty():
			failed_reason = "Run failed."
	var hook_index := 0
	for game_id in _string_array(run_state.current_environment.get("game_ids", [])):
		var game := _game_module_for_id(game_id)
		if game == null:
			continue
		for hook_value in game.environment_interactable_objects(run_state, run_state.current_environment):
			if typeof(hook_value) != TYPE_DICTIONARY:
				continue
			var hook: Dictionary = hook_value
			var hook_id := str(hook.get("id", hook.get("source_id", "")))
			if hook_id.is_empty():
				continue
			var object_id := str(hook.get("object_id", ""))
			if object_id.is_empty():
				object_id = "game_hook:%s:%s" % [game_id, hook_id]
			var base_enabled := bool(hook.get("enabled", true))
			var enabled := base_enabled and not run_failed_without_recovery
			var disabled_reason := str(hook.get("disabled_reason", ""))
			if run_failed_without_recovery:
				disabled_reason = failed_reason
			objects.append(_make_interactable_object({
				"object_id": object_id,
				"object_type": CONTEXT_MODE_GAME_HOOK,
				"visual_type": str(hook.get("visual_type", "service")),
				"source_id": hook_id,
				"parent_id": game_id,
				"label": str(hook.get("label", _label_from_id(hook_id))),
				"short_description": str(hook.get("short_description", "")),
				"enabled": enabled,
				"disabled_reason": disabled_reason if not enabled else "",
				"action_summary": str(hook.get("action_summary", "")),
				"effect_summary": str(hook.get("effect_summary", "")),
				"risk_summary": str(hook.get("risk_summary", "")),
				"cost_summary": str(hook.get("cost_summary", "")),
				"visual_key": str(hook.get("visual_key", "")),
				"icon_key": str(hook.get("icon_key", "service")),
				"available_actions": _copy_array(hook.get("available_actions", [])) if enabled else [],
				"confirm_action_id": str(hook.get("confirm_action_id", "")) if enabled else "",
				"focus_rect": _interaction_rect_for_object(object_id, CONTEXT_MODE_GAME_HOOK, hook_index),
			}))
			hook_index += 1
	return objects


func _hook_interactable_objects(object_type: String, options: Array) -> Array:
	var objects: Array = []
	var run_failed_without_recovery := _run_failed_without_recovery()
	var failed_reason := _pressure_status_text(_run_pressure_view())
	if failed_reason.strip_edges().is_empty():
		failed_reason = "Run failed."
	for index in range(options.size()):
		if typeof(options[index]) != TYPE_DICTIONARY:
			continue
		var option: Dictionary = options[index]
		var hook_id := str(option.get("id", ""))
		if hook_id.is_empty():
			continue
		var object_id := "%s:%s" % [object_type, hook_id]
		var presence := "fixture" if _object_fixture_declared(object_id) else "dynamic"
		if bool(option.get("hidden", false)) and presence != "fixture":
			continue
		var supported := bool(option.get("mutation_supported", false))
		var enabled := bool(option.get("enabled", supported)) and not run_failed_without_recovery
		var disabled_reason := "" if enabled else failed_reason if run_failed_without_recovery else str(option.get("disabled_reason", option.get("status", "Display-only.")))
		var availability_class := str(option.get("availability_class", RunState.AVAILABILITY_AVAILABLE))
		var category := str(option.get("category", ""))
		var visual_type := "drink" if object_type == CONTEXT_MODE_SERVICE and category == "alcohol" else object_type
		objects.append(_make_interactable_object({
			"object_id": object_id,
			"object_type": object_type,
			"visual_type": visual_type,
			"source_id": hook_id,
			"label": str(option.get("display_name", _label_from_id(hook_id))),
			"short_description": str(option.get("summary", "")),
			"presence": presence,
			"interactive": enabled or availability_class == RunState.AVAILABILITY_TRANSIENT_BLOCKED,
			"enabled": enabled,
			"disabled_reason": disabled_reason,
			"action_summary": "Double-click to use." if enabled else "",
			"risk_summary": "",
			"cost_summary": _hook_cost_effect_summary(option),
			"visual_key": visual_type,
			"icon_key": visual_type,
			"available_actions": [{"id": "use_%s_hook" % object_type, "label": "Use"}] if enabled else [],
			"confirm_action_id": "use_%s_hook" % object_type if enabled else "",
			"focus_rect": _interaction_rect_for_object(object_id, object_type, index),
		}))
	return objects


func _interactable_object(object_id: String) -> Dictionary:
	for object_data in _interactable_object_view_list():
		if typeof(object_data) == TYPE_DICTIONARY and str((object_data as Dictionary).get("object_id", "")) == object_id:
			return (object_data as Dictionary).duplicate(true)
	if object_id == "travel:leave":
		return _travel_leave_interactable_object()
	return {}


func _travel_leave_interactable_object() -> Dictionary:
	if run_state == null:
		return {}
	var travel_choices := _travel_choice_view_list()
	if travel_choices.is_empty():
		return {}
	var first_choice: Dictionary = travel_choices[0] if typeof(travel_choices[0]) == TYPE_DICTIONARY else {}
	var any_enabled := false
	for choice_value in travel_choices:
		if typeof(choice_value) == TYPE_DICTIONARY and bool((choice_value as Dictionary).get("enabled", true)):
			any_enabled = true
			break
	var travel_enabled := not _run_failed_without_recovery()
	var preview_lines: Array = []
	for choice_value in travel_choices.slice(0, 3):
		if typeof(choice_value) != TYPE_DICTIONARY:
			continue
		var choice: Dictionary = choice_value
		preview_lines.append("%s: %s, cost %d" % [
			str(choice.get("label", choice.get("id", "Route"))),
			str(choice.get("distance", "near")),
			int(choice.get("cost", 0)),
		])
	return _make_interactable_object({
		"object_id": "travel:leave",
		"object_type": CONTEXT_MODE_TRAVEL,
		"source_id": "leave",
		"label": "Leave",
		"short_description": "Open the city map and choose a revealed stop.",
		"enabled": travel_enabled,
		"disabled_reason": _pressure_status_text(_run_pressure_view()) if not travel_enabled else "",
		"action_summary": "Double-click to open the map." if any_enabled else "Open the map to inspect locked routes.",
		"risk_summary": _travel_risk_summary(first_choice),
		"impact_summary": _travel_preview_summary(first_choice),
		"cost_summary": "%d route(s)" % travel_choices.size(),
		"preview_lines": preview_lines,
		"unlock_conditions": [],
		"visual_key": "travel",
		"prop": "door",
		"icon_key": "travel",
		"available_actions": [{"id": "open_map", "label": "Open Map"}] if travel_enabled else [],
		"confirm_action_id": "open_map" if travel_enabled else "",
		"focus_rect": _interaction_rect_for_object("travel:leave", CONTEXT_MODE_TRAVEL, 0),
	})


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


func _make_interactable_object(source: Dictionary) -> Dictionary:
	var focus_rect := _rect_from_dict(source.get("focus_rect", {}))
	var focus_point := focus_rect.position + focus_rect.size * 0.5
	var enabled := bool(source.get("enabled", true))
	var interactive := bool(source.get("interactive", true))
	return {
		"object_id": str(source.get("object_id", "")),
		"object_type": str(source.get("object_type", "info")),
		"visual_type": str(source.get("visual_type", source.get("object_type", "info"))),
		"presence": str(source.get("presence", "dynamic")),
		"interactive": interactive,
		"decorative": not interactive,
		"source_id": str(source.get("source_id", "")),
		"parent_id": str(source.get("parent_id", "")),
		"label": str(source.get("label", "")),
			"short_description": str(source.get("short_description", "")),
			"identity_summary": str(source.get("identity_summary", "")),
			"enabled": enabled,
			"disabled_reason": str(source.get("disabled_reason", "")) if not enabled else "",
			"normalized_rect": _rect_to_dict(focus_rect),
			"focus_rect": _rect_to_dict(focus_rect),
			"focus_point": _vector2_to_dict(focus_point),
			"action_summary": str(source.get("action_summary", "")),
			"status_summary": str(source.get("status_summary", "")),
			"effect_summary": str(source.get("effect_summary", "")),
			"impact_summary": str(source.get("impact_summary", "")),
			"choice_summary": str(source.get("choice_summary", "")),
			"risk_summary": str(source.get("risk_summary", "")),
			"cost_summary": str(source.get("cost_summary", "")),
			"runtime_state": (source.get("runtime_state", {}) as Dictionary).duplicate(true) if typeof(source.get("runtime_state", {})) == TYPE_DICTIONARY else {},
			"visual_state": (source.get("visual_state", {}) as Dictionary).duplicate(true) if typeof(source.get("visual_state", {})) == TYPE_DICTIONARY else {},
			"state_badge": str(source.get("state_badge", "")),
			"visual_key": str(source.get("visual_key", "")),
			"prop": str(source.get("prop", "")),
			"surface": str(source.get("surface", "")),
			"icon_key": str(source.get("icon_key", "")),
			"asset_path": str(source.get("asset_path", "")),
			"available_actions": _copy_array(source.get("available_actions", [])),
			"inline_actions": _copy_array(source.get("inline_actions", [])),
			"confirm_action_id": str(source.get("confirm_action_id", "")),
			"hovered": str(source.get("object_id", "")) == hover_target_id,
			"focused": str(source.get("object_id", "")) == focus_target_id,
			"selected": str(source.get("object_id", "")) == selected_object_id,
	}


func _interaction_rect_for_object(object_id: String, object_type: String, index: int) -> Rect2:
	var object_rect := _generated_object_interaction_rect(object_id)
	if object_rect.size.x > 0.0 and object_rect.size.y > 0.0:
		return object_rect
	return _interaction_rect(object_type, index)


func _generated_object_interaction_rect(object_id: String) -> Rect2:
	if object_id.is_empty():
		return Rect2()
	var layout := _current_environment_layout()
	var object_rects: Variant = layout.get("object_rects", {})
	if typeof(object_rects) != TYPE_DICTIONARY or not (object_rects as Dictionary).has(object_id):
		return Rect2()
	return _rect_from_dict((object_rects as Dictionary).get(object_id, {}))


func _interaction_rect(object_type: String, index: int) -> Rect2:
	var authored_rect := _authored_interaction_rect(object_type, index)
	if authored_rect.size.x > 0.0 and authored_rect.size.y > 0.0:
		return authored_rect
	return _normalized_interaction_rect(object_type, index)


func _authored_interaction_rect(object_type: String, index: int) -> Rect2:
	var spot := _layout_spot_for_object_type(object_type, index)
	if spot.x < 0.0 or spot.y < 0.0:
		return Rect2()
	var fallback_rect := _normalized_interaction_rect(object_type, index)
	var board_size := Vector2(VisualStyle.ENVIRONMENT_BOARD_SIZE)
	var normalized_center := Vector2(
		clampf(spot.x / board_size.x, 0.0, 1.0),
		clampf(spot.y / board_size.y, 0.0, 1.0)
	)
	return Rect2(normalized_center - fallback_rect.size * 0.5, fallback_rect.size)


func _layout_spot_for_object_type(object_type: String, index: int) -> Vector2:
	var field_name := _layout_spot_field_name(object_type)
	if field_name.is_empty():
		return Vector2(-1.0, -1.0)
	var layout := _current_environment_layout()
	var spots: Variant = layout.get(field_name, [])
	if typeof(spots) != TYPE_ARRAY or index < 0 or index >= (spots as Array).size():
		return Vector2(-1.0, -1.0)
	return _layout_spot_to_board_position((spots as Array)[index])


func _layout_spot_field_name(object_type: String) -> String:
	match object_type:
		CONTEXT_MODE_GAME:
			return "game_spots"
		CONTEXT_MODE_EVENT:
			return "event_spots"
		CONTEXT_MODE_ITEM:
			return "item_spots"
		CONTEXT_MODE_SHOPKEEPER:
			return "shopkeeper_spots"
		CONTEXT_MODE_GAME_HOOK:
			return "game_hook_spots"
		CONTEXT_MODE_TRAVEL:
			return "travel_spots"
		CONTEXT_MODE_SERVICE:
			return "service_spots"
		CONTEXT_MODE_LENDER:
			return "lender_spots"
		CONTEXT_MODE_PRESTIGE:
			return "prestige_spots"
	return ""


func _layout_spot_to_board_position(value: Variant) -> Vector2:
	if typeof(value) == TYPE_VECTOR2:
		return value as Vector2
	if typeof(value) == TYPE_VECTOR2I:
		var spot_i := value as Vector2i
		return Vector2(float(spot_i.x), float(spot_i.y))
	if typeof(value) == TYPE_ARRAY:
		var parts := value as Array
		if parts.size() >= 2:
			return Vector2(float(parts[0]), float(parts[1]))
	if typeof(value) == TYPE_DICTIONARY:
		var data := value as Dictionary
		return Vector2(float(data.get("x", -1.0)), float(data.get("y", -1.0)))
	return Vector2(-1.0, -1.0)


func _current_environment_layout() -> Dictionary:
	if run_state == null:
		return {}
	var serialized_layout: Variant = run_state.current_environment.get("layout", {})
	if typeof(serialized_layout) == TYPE_DICTIONARY and not (serialized_layout as Dictionary).is_empty():
		return (serialized_layout as Dictionary).duplicate(true)
	var archetype_id := str(run_state.current_environment.get("archetype_id", ""))
	var archetype := _environment_archetype(archetype_id)
	var archetype_layout: Variant = archetype.get("layout", {})
	if typeof(archetype_layout) != TYPE_DICTIONARY:
		return {}
	return (archetype_layout as Dictionary).duplicate(true)


func _normalized_interaction_rect(object_type: String, index: int) -> Rect2:
	var board_size := Vector2(VisualStyle.ENVIRONMENT_BOARD_SIZE)
	var center := Vector2(0.5, 0.5)
	var size := Vector2(0.12, 0.18)
	match object_type:
		CONTEXT_MODE_GAME:
			center = Vector2(0.28 + float(index % 3) * 0.18, 0.56 + float(index / 3) * 0.13)
			size = Vector2(118.0 / board_size.x, 72.0 / board_size.y)
		CONTEXT_MODE_EVENT:
			center = Vector2(0.68 + float(index % 2) * 0.12, 0.42 + float(index / 2) * 0.14)
			size = Vector2(100.0 / board_size.x, 64.0 / board_size.y)
		CONTEXT_MODE_ITEM:
			center = Vector2(0.30 + float(index % 4) * 0.12, 0.76)
			size = Vector2(90.0 / board_size.x, 54.0 / board_size.y)
		CONTEXT_MODE_SHOPKEEPER:
			center = Vector2(0.80, 0.34)
			size = Vector2(108.0 / board_size.x, 70.0 / board_size.y)
		CONTEXT_MODE_GAME_HOOK:
			center = Vector2(0.66 + float(index % 2) * 0.12, 0.76)
			size = Vector2(104.0 / board_size.x, 58.0 / board_size.y)
		CONTEXT_MODE_TRAVEL:
			center = Vector2(0.78, 0.64 + float(index) * 0.12)
			size = Vector2(118.0 / board_size.x, 64.0 / board_size.y)
		CONTEXT_MODE_SERVICE:
			center = Vector2(0.50 + float(index % 2) * 0.14, 0.76)
			size = Vector2(96.0 / board_size.x, 54.0 / board_size.y)
		CONTEXT_MODE_LENDER:
			center = Vector2(0.62 + float(index % 2) * 0.12, 0.72)
			size = Vector2(102.0 / board_size.x, 58.0 / board_size.y)
		CONTEXT_MODE_PRESTIGE:
			center = Vector2(0.16 + float(index % 2) * 0.14, 0.30)
			size = Vector2(112.0 / board_size.x, 58.0 / board_size.y)
	return Rect2(center - size * 0.5, size)


func _rect_to_dict(rect: Rect2) -> Dictionary:
	return {
		"x": rect.position.x,
		"y": rect.position.y,
		"w": rect.size.x,
		"h": rect.size.y,
	}


func _rect_from_dict(value: Variant) -> Rect2:
	if typeof(value) == TYPE_RECT2:
		return value as Rect2
	if typeof(value) != TYPE_DICTIONARY:
		return Rect2()
	var data: Dictionary = value
	return Rect2(
		Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0))),
		Vector2(float(data.get("w", 0.0)), float(data.get("h", 0.0)))
	)


func _active_play_surface_global_rect() -> Rect2:
	if game_surface_canvas != null and game_surface_canvas.visible:
		return game_surface_canvas.get_global_rect()
	if environment_canvas != null:
		return environment_canvas.get_global_rect()
	return Rect2()


func _vector2_to_dict(value: Vector2) -> Dictionary:
	return {
		"x": value.x,
		"y": value.y,
	}


func _vector2_from_dict(value: Variant, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if typeof(value) != TYPE_DICTIONARY:
		return fallback
	var data: Dictionary = value
	return Vector2(float(data.get("x", fallback.x)), float(data.get("y", fallback.y)))


func _game_view_snapshot() -> Dictionary:
	var display_name := "Choose a game"
	var game_id := ""
	var family := ""
	var surface_renderer := "result"
	var surface_life := "result"
	var surface_cast := "none"
	var legal_actions := _game_action_view_list("legal")
	var cheat_actions := _game_action_view_list("cheat")
	var module_surface_state := {}
	if current_game != null:
		display_name = current_game.get_display_name()
		game_id = current_game.get_id()
		family = current_game.get_family()
		surface_renderer = _surface_renderer_for_game_definition(current_game.definition)
		surface_life = _surface_life_for_renderer(surface_renderer)
		surface_cast = _surface_cast_for_renderer(surface_renderer)
		module_surface_state = current_game.surface_state(run_state, run_state.current_environment, _current_game_surface_ui_state())
		if typeof(module_surface_state) != TYPE_DICTIONARY:
			module_surface_state = {}
		_sync_surface_feature_music_state(module_surface_state)
		if module_surface_state.has("surface_renderer"):
			surface_renderer = str(module_surface_state.get("surface_renderer", surface_renderer))
			surface_life = _surface_life_for_renderer(surface_renderer)
			surface_cast = _surface_cast_for_renderer(surface_renderer)
		if module_surface_state.has("surface_life"):
			surface_life = str(module_surface_state.get("surface_life", surface_life))
		if module_surface_state.has("surface_cast"):
			surface_cast = str(module_surface_state.get("surface_cast", surface_cast))
	var result := _current_game_result_snapshot()
	if current_game == null and not result.is_empty():
		display_name = str(result.get("display_name", "Saved game summary"))
		game_id = str(result.get("game_id", ""))
		family = str(result.get("family", ""))
	var deltas: Dictionary = result.get("deltas", {})
	var result_message := _player_facing_text(str(result.get("message", "")))
	if result_message.is_empty():
		if current_game == null and result.is_empty():
			result_message = "Pick a game from the choices to start playing."
		elif message_label != null:
			result_message = _player_facing_text(message_label.text)
	var drunk_time_scale := run_state.drunk_time_scale()
	var drunk_world_speed_percent := run_state.drunk_time_scale_percent()
	var stake_range := _stake_range()
	var snapshot_selected_stake := _selected_stake_for_range(stake_range)
	var snapshot := {
		"game_id": game_id,
		"display_name": display_name,
		"description": _current_game_description(),
		"family": family,
		"legal_actions": legal_actions,
		"cheat_actions": cheat_actions,
		"legal_action_count": legal_actions.size(),
		"cheat_action_count": cheat_actions.size(),
		"stake_min": int(stake_range.get("min", 1)),
		"stake_max": int(stake_range.get("max", 1)),
		"selected_stake": snapshot_selected_stake,
		"has_valid_stake": bool(stake_range.get("has_valid", false)),
		"selected_action_id": selected_action_id,
		"selected_action_kind": selected_action_kind,
		"selected_action_label": selected_action_label,
		"selected_action_summary": _selected_action_summary() if not selected_action_id.is_empty() else "",
		"risk_cue": _cheat_action_risk_cue(cheat_actions) if current_game != null else "",
		"surface_renderer": surface_renderer,
		"surface_life": surface_life,
		"surface_cast": surface_cast,
		"has_recent_outcome": not result.is_empty(),
		"outcome_message": result_message,
		"outcome_bankroll_delta": int(result.get("bankroll_delta", deltas.get("bankroll_delta", 0))),
		"outcome_suspicion_delta": int(result.get("suspicion_delta", deltas.get("suspicion_delta", 0))),
		"result_message": result_message,
		"bankroll": run_state.bankroll,
		"suspicion_level": run_state.suspicion_level(),
		"drunk_level": run_state.drunk_level,
		"drunk_time_scale": drunk_time_scale,
		"drunk_time_scale_percent": drunk_world_speed_percent,
		"drunk_world_speed_percent": drunk_world_speed_percent,
		"pending_drunk_absorption": run_state.pending_drunk_absorption_amount(),
		"drunk_distortion_suppression_turns": run_state.drunk_distortion_suppression_turns,
		"drunk_effect_mode": _drunk_effect_mode(),
		"reduce_motion": _reduce_motion_enabled(),
		"high_contrast": _high_contrast_enabled(),
		"accessibility": current_accessibility_snapshot(),
		"alcoholic_level": run_state.alcoholic_level,
		"baseline_luck": run_state.baseline_luck,
		"luck_modifier": run_state.effective_luck(),
		"alcohol_condition": run_state.alcohol_condition_label(),
		"bankroll_delta": int(result.get("bankroll_delta", deltas.get("bankroll_delta", 0))),
		"suspicion_delta": int(result.get("suspicion_delta", deltas.get("suspicion_delta", 0))),
		"result_stake": int(result.get("stake", 0)),
		"ticket_symbols": _copy_array(result.get("ticket_symbols", [])),
		"won": bool(result.get("won", false)),
		"state": str(result.get("state", GameModule.RESULT_CONTINUE)),
		"summary_source": str(result.get("summary_source", "active_game" if current_game != null else "")),
	}
	for key in module_surface_state.keys():
		snapshot[key] = module_surface_state[key]
	snapshot["stake_min"] = int(stake_range.get("min", 1))
	snapshot["stake_max"] = int(stake_range.get("max", 1))
	snapshot["selected_stake"] = snapshot_selected_stake
	snapshot["has_valid_stake"] = bool(stake_range.get("has_valid", false))
	for key in result.keys():
		var result_key := str(key)
		if not snapshot.has(result_key):
			snapshot[result_key] = result[key]
	return snapshot


func _current_game_surface_ui_state() -> Dictionary:
	var ui_state := game_surface_ui_state.duplicate(true)
	ui_state["selected_action_id"] = selected_action_id
	ui_state["selected_action_kind"] = selected_action_kind
	ui_state["selected_stake"] = _current_selected_stake()
	ui_state["surface_runtime_status"] = _current_game_surface_status()
	return _apply_game_surface_time_fields(ui_state)


func _current_game_result_snapshot() -> Dictionary:
	if last_game_result.is_empty():
		return {}
	if current_game == null:
		return last_game_result.duplicate(true)
	var result_game_id := str(last_game_result.get("game_id", last_game_result.get("source_id", "")))
	if result_game_id.is_empty() or result_game_id == current_game.get_id():
		return last_game_result.duplicate(true)
	return {}


func _current_game_embeds_result_feedback() -> bool:
	if current_game == null or run_state == null:
		return false
	var surface_state := current_game.surface_state(run_state, run_state.current_environment, _current_game_surface_ui_state())
	if typeof(surface_state) != TYPE_DICTIONARY:
		return false
	return bool(surface_state.get("surface_embeds_outcomes", false))


func _store_current_game_surface_ui_state(ui_state: Dictionary) -> void:
	game_surface_ui_state = ui_state.duplicate(true)


func _surface_renderer_for_game_definition(definition: Dictionary) -> String:
	var renderer := str(definition.get("surface_renderer", definition.get("presentation_mode", ""))).strip_edges()
	return renderer if not renderer.is_empty() else "result"


func _surface_life_for_renderer(renderer: String) -> String:
	match renderer:
		"reel_machine":
			return "machine"
		"card_machine":
			return "screen"
		"ticket_reveal":
			return "ticket_table"
		"card_table":
			return "cards"
		"dice_table":
			return "dice_bar"
		_:
			return "result"


func _surface_cast_for_renderer(renderer: String) -> String:
	match renderer:
		"reel_machine", "card_machine":
			return "machine"
		"card_table":
			return "dealer"
		_:
			return "none"


func _refresh_consequence_labels() -> void:
	var snapshot := _consequence_view_snapshot()
	var has_recent_consequence := false
	if consequence_panel != null:
		consequence_panel.visible = has_recent_consequence
		consequence_panel.custom_minimum_size = Vector2(0, 0)
	if consequence_heading_label != null:
		consequence_heading_label.visible = has_recent_consequence
	if message_label != null:
		message_label.visible = false
	if consequence_state_label != null:
		consequence_state_label.text = "%s | %s" % [str(snapshot.get("current_state_text", "")), str(snapshot.get("suspicion_text", ""))]
		consequence_state_label.visible = false
	if consequence_result_label != null:
		consequence_result_label.text = str(snapshot.get("recent_result_text", ""))
		consequence_result_label.visible = false
	if consequence_story_label != null:
		consequence_story_label.text = str(snapshot.get("story_text", ""))
		consequence_story_label.visible = false
	if consequence_cards_scroll != null:
		consequence_cards_scroll.visible = has_recent_consequence
	_refresh_consequence_cards(snapshot)


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


func _failure_summary_snapshot() -> Dictionary:
	if run_state == null:
		return {}
	var pressure := _run_pressure_view()
	var environment := run_state.current_environment
	var recent_result := _recent_result_snapshot()
	var recent_deltas: Dictionary = recent_result.get("deltas", {})
	var recent_message := _outcome_message(recent_result)
	if recent_message.is_empty() and message_label != null:
		recent_message = _player_facing_text(message_label.text)
	var reason := run_state.run_failure_reason
	if reason.strip_edges().is_empty():
		reason = str(pressure.get("reason", RunState.FAILURE_BANKROLL_ZERO))
	var title := str(pressure.get("title", "Run failed"))
	if title.strip_edges().is_empty():
		title = "Run failed"
	var message := run_state.run_failure_message
	if message.strip_edges().is_empty():
		message = str(pressure.get("summary", "The run is over."))
	var inventory_items := _inventory_view_list()
	var debt_items := _debt_view_list()
	var travel_choices := _travel_choice_view_list()
	var story_lines := _story_message_view_list()
	var item_lines: Array = []
	if inventory_items.is_empty():
		item_lines.append("Inventory: empty.")
	else:
		item_lines.append("Inventory: %s." % _inventory_summary(inventory_items))
		item_lines.append_array(inventory_items.slice(0, 5))
	var debt_lines: Array = []
	if debt_items.is_empty():
		debt_lines.append("Debt: none.")
	else:
		debt_lines.append("Debt: %s." % _debt_summary(debt_items))
		debt_lines.append_array(debt_items.slice(0, 5))
	var travel_lines: Array = []
	if travel_choices.is_empty():
		travel_lines.append("No routes were available at failure.")
	else:
		travel_lines.append("Routes at failure: %s." % _travel_summary(travel_choices))
		for choice in travel_choices.slice(0, 5):
			if typeof(choice) == TYPE_DICTIONARY:
				var choice_data := choice as Dictionary
				var line := str(choice_data.get("label", choice_data.get("id", "Route")))
				if choice_data.has("cost"):
					line += " cost %d" % int(choice_data.get("cost", 0))
				if not bool(choice_data.get("enabled", true)):
					line += " locked: %s" % str(choice_data.get("disabled_reason", "unavailable"))
				travel_lines.append(line)
	var recent_result_lines: Array = []
	if recent_message.strip_edges().is_empty():
		recent_result_lines.append("No recent action was recorded.")
	else:
		recent_result_lines.append(recent_message)
	recent_result_lines.append("Bankroll %+d, heat %+d." % [
		int(recent_result.get("bankroll_delta", recent_deltas.get("bankroll_delta", 0))),
		int(recent_result.get("suspicion_delta", recent_deltas.get("suspicion_delta", 0))),
	])
	var alcohol_lines := [
		"Alcohol: %s, drunk %d, need %d." % [
			run_state.alcohol_condition_label().capitalize(),
			run_state.drunk_level,
			run_state.alcoholic_level,
		],
		"Baseline luck %+d, effective luck %+d." % [run_state.baseline_luck, run_state.effective_luck()],
	]
	if story_lines.is_empty():
		story_lines.append("No story entries were recorded.")
	var visited_places := _visited_environment_summary_lines()
	var score_summary: Dictionary = run_state.terminal_score_summary()
	var score_lines: Array = _terminal_score_lines(score_summary)
	return {
		"title": title,
		"message": _player_facing_text(message),
		"reason": reason,
		"reason_label": _label_from_id(reason) if not reason.is_empty() else "Run failed",
		"run_status": run_state.run_status,
		"seed": run_state.player_facing_seed_text(),
		"seed_hidden": run_state.seed_is_hidden(),
		"score_spending": int(score_summary.get("base_spending", 0)),
		"score_multiplier": int(score_summary.get("multiplier", 1)),
		"score": int(score_summary.get("score", 0)),
		"score_lines": score_lines,
		"bankroll": run_state.bankroll,
		"economy": _economy_cue_text(),
		"heat": run_state.suspicion_level(),
		"heat_label": run_state.security_pressure_label(),
		"alcohol": run_state.alcohol_pressure_summary(),
		"drunk_level": run_state.drunk_level,
		"alcoholic_level": run_state.alcoholic_level,
		"baseline_luck": run_state.baseline_luck,
		"luck_modifier": run_state.effective_luck(),
		"current_environment": str(environment.get("display_name", environment.get("id", "Unknown room"))),
		"environment_id": str(environment.get("id", "")),
		"environment_kind": _label_from_id(str(environment.get("kind", environment.get("archetype_id", "room")))),
		"visited_count": visited_places.size(),
		"visited_summary": ", ".join(visited_places) if not visited_places.is_empty() else "current room only",
		"travel_lines": travel_lines,
		"alcohol_lines": alcohol_lines,
		"item_lines": item_lines,
		"debt_lines": debt_lines,
		"recent_result_lines": recent_result_lines,
		"story_lines": story_lines,
		"flag_lines": _flag_view_list(),
	}


func _victory_summary_snapshot() -> Dictionary:
	if run_state == null:
		return {}
	var pressure := _run_pressure_view()
	var environment := run_state.current_environment
	var route := str(run_state.narrative_flags.get("demo_victory_route", "")).strip_edges()
	if route.is_empty() and bool(run_state.narrative_flags.get("prestige_victory", false)):
		route = "prestige_victory"
	if route.is_empty():
		route = "run_complete"
	var title := str(pressure.get("title", "Demo Victory"))
	if bool(run_state.narrative_flags.get("demo_victory", false)):
		title = "Demo Victory"
	elif bool(run_state.narrative_flags.get("prestige_victory", false)):
		title = "Victory Claimed"
	elif title.strip_edges().is_empty():
		title = "Run Complete"
	var message := ""
	if bool(run_state.narrative_flags.get("demo_victory", false)):
		message = run_state.current_demo_victory_message()
	else:
		message = str(pressure.get("summary", "You beat the house for now."))
	message = _player_facing_text(message)
	if message.strip_edges().is_empty():
		message = "You beat the house for now."
	var next_act_line := "The next act is not implemented yet."
	var inventory_items := _inventory_view_list()
	var debt_items := _debt_view_list()
	var story_lines := _story_message_view_list()
	var item_lines: Array = []
	if inventory_items.is_empty():
		item_lines.append("Inventory: empty.")
	else:
		item_lines.append("Inventory: %s." % _inventory_summary(inventory_items))
		if not run_state.active_item_id.is_empty():
			item_lines.append("Active item: %s." % _label_from_id(run_state.active_item_id))
		item_lines.append_array(inventory_items.slice(0, 5))
	var debt_lines: Array = []
	if debt_items.is_empty():
		debt_lines.append("Debt: none.")
	else:
		debt_lines.append("Debt: %s." % _debt_summary(debt_items))
		debt_lines.append_array(debt_items.slice(0, 5))
	var alcohol_lines := [
		"Alcohol: %s, drunk %d, need %d." % [
			run_state.alcohol_condition_label().capitalize(),
			run_state.drunk_level,
			run_state.alcoholic_level,
		],
		"Baseline luck %+d, effective luck %+d." % [run_state.baseline_luck, run_state.effective_luck()],
	]
	if story_lines.is_empty():
		story_lines.append("No story entries were recorded.")
	var visited_places := _visited_environment_summary_lines()
	var score_summary: Dictionary = run_state.terminal_score_summary()
	var score_lines: Array = _terminal_score_lines(score_summary)
	return {
		"title": title,
		"message": message,
		"route": route,
		"route_label": _label_from_id(route),
		"run_status": run_state.run_status,
		"seed": run_state.player_facing_seed_text(),
		"seed_hidden": run_state.seed_is_hidden(),
		"score_spending": int(score_summary.get("base_spending", 0)),
		"score_multiplier": int(score_summary.get("multiplier", 1)),
		"score": int(score_summary.get("score", 0)),
		"score_lines": score_lines,
		"bankroll": run_state.bankroll,
		"economy": _economy_cue_text(),
		"heat": run_state.suspicion_level(),
		"heat_label": run_state.security_pressure_label(),
		"alcohol": run_state.alcohol_pressure_summary(),
		"drunk_level": run_state.drunk_level,
		"alcoholic_level": run_state.alcoholic_level,
		"baseline_luck": run_state.baseline_luck,
		"luck_modifier": run_state.effective_luck(),
		"current_environment": str(environment.get("display_name", environment.get("id", "Unknown room"))),
		"environment_id": str(environment.get("id", "")),
		"environment_kind": _label_from_id(str(environment.get("kind", environment.get("archetype_id", "room")))),
		"visited_count": visited_places.size(),
		"visited_summary": ", ".join(visited_places) if not visited_places.is_empty() else "current room only",
		"next_act_line": next_act_line,
		"alcohol_lines": alcohol_lines,
		"item_lines": item_lines,
		"debt_lines": debt_lines,
		"story_lines": story_lines,
		"flag_lines": _flag_view_list(),
	}


func _terminal_score_lines(score_summary: Dictionary) -> Array:
	var base_spending := int(score_summary.get("base_spending", 0))
	var multiplier := maxi(1, int(score_summary.get("multiplier", 1)))
	var score := int(score_summary.get("score", base_spending * multiplier))
	var lines: Array = [
		"Items and travel spent: %d" % base_spending,
		"Victory multiplier: x%d" % multiplier,
		"Run score: %d" % score,
	]
	return lines


func _visited_environment_summary_lines() -> Array:
	if run_state == null:
		return []
	var labels: Array = []
	for entry in run_state.environment_history:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var environment := entry as Dictionary
		var label := str(environment.get("display_name", environment.get("id", "")))
		if not label.is_empty() and not labels.has(label):
			labels.append(label)
	var current_label := str(run_state.current_environment.get("display_name", run_state.current_environment.get("id", "")))
	if not current_label.is_empty() and not labels.has(current_label):
		labels.append(current_label)
	return labels


func _consequence_view_snapshot() -> Dictionary:
	var recent_result := _recent_result_snapshot()
	var deltas: Dictionary = recent_result.get("deltas", {})
	var recent_bankroll_delta := int(recent_result.get("bankroll_delta", deltas.get("bankroll_delta", 0)))
	var recent_suspicion_delta := int(recent_result.get("suspicion_delta", deltas.get("suspicion_delta", 0)))
	var recent_alcohol_intake := int(deltas.get("alcohol_intake", 0))
	var recent_drunk_delta := int(deltas.get("drunk_delta", 0))
	var recent_alcoholic_delta := int(deltas.get("alcoholic_delta", 0))
	var recent_luck_delta := int(deltas.get("baseline_luck_delta", 0))
	var suspicion_cues := _suspicion_cue_view_list()
	var security_cues := _security_cue_view_list()
	var story_messages := _story_message_view_list()
	var inventory_items := _inventory_view_list()
	var debt_items := _debt_view_list()
	var flag_labels := _flag_view_list()
	var travel_choices := _travel_choice_view_list()
	var pressure := _run_pressure_view()
	var recent_message := _player_facing_text(str(recent_result.get("message", "")))
	if recent_message.is_empty() and message_label != null:
		recent_message = _player_facing_text(message_label.text)
	var has_recent_consequence := _result_is_visible_consequence(recent_result, recent_message)
	var current_state_text := "Bankroll %d | %s | Status %s | %s | Debt %s | Gear %s | Routes %s" % [
		run_state.bankroll,
		_economy_cue_text(),
		str(pressure.get("title", "")),
		run_state.alcohol_pressure_summary(),
		_debt_summary(debt_items),
		_inventory_summary(inventory_items),
		_travel_summary(travel_choices),
	]
	var suspicion_text := "Heat: %s" % run_state.security_pressure_label().capitalize()
	if not suspicion_cues.is_empty():
		suspicion_text += " | %s" % str(suspicion_cues[0])
	elif not security_cues.is_empty():
		suspicion_text += " | %s" % str(security_cues[0])
	var recent_result_text := "Recent result: %s | Bankroll %+d | Heat %+d" % [
		recent_message if not recent_message.is_empty() else "No result yet.",
		recent_bankroll_delta,
		recent_suspicion_delta,
	]
	var story_text := "Story: %s | Clues %s" % [
		" / ".join(story_messages) if not story_messages.is_empty() else "No story yet.",
		_flag_summary(flag_labels),
	]
	var cards := _consequence_card_view_list({
		"recent_result": recent_result,
		"has_recent_consequence": has_recent_consequence,
		"recent_bankroll_delta": recent_bankroll_delta,
		"recent_suspicion_delta": recent_suspicion_delta,
		"recent_alcohol_intake": recent_alcohol_intake,
		"recent_drunk_delta": recent_drunk_delta,
		"recent_alcoholic_delta": recent_alcoholic_delta,
		"recent_luck_delta": recent_luck_delta,
		"recent_result_message": recent_message,
		"suspicion_cues": suspicion_cues,
		"security_cues": security_cues,
		"debt_items": debt_items,
		"inventory_items": inventory_items,
		"story_messages": story_messages,
		"travel_choices": travel_choices,
		"pressure": pressure,
	})
	return {
		"bankroll": run_state.bankroll,
		"economy": run_state.economy(),
		"recent_bankroll_delta": recent_bankroll_delta,
		"recent_suspicion_delta": recent_suspicion_delta,
		"recent_result_message": recent_message,
		"suspicion_level": run_state.suspicion_level(),
		"drunk_level": run_state.drunk_level,
		"alcoholic_level": run_state.alcoholic_level,
		"baseline_luck": run_state.baseline_luck,
		"luck_modifier": run_state.effective_luck(),
		"alcohol_text": run_state.alcohol_pressure_summary(),
		"suspicion_cues": suspicion_cues,
		"security_cues": security_cues,
		"debt_items": debt_items,
		"debt_summary": _debt_summary(debt_items),
		"inventory_items": inventory_items,
		"inventory_summary": _inventory_summary(inventory_items),
		"flag_labels": flag_labels,
		"flag_summary": _flag_summary(flag_labels),
		"story_messages": story_messages,
		"travel_available": not travel_choices.is_empty(),
		"travel_count": travel_choices.size(),
		"travel_summary": _travel_summary(travel_choices),
		"run_status": run_state.run_status,
		"pressure": pressure,
		"pressure_text": _pressure_status_text(pressure),
		"has_recent_consequence": has_recent_consequence,
		"current_state_text": current_state_text,
		"suspicion_text": suspicion_text,
		"recent_result_text": recent_result_text,
		"story_text": story_text,
		"cards": cards,
	}


func _consequence_card_view_list(context: Dictionary) -> Array:
	var recent_result: Dictionary = context.get("recent_result", {})
	if not bool(context.get("has_recent_consequence", false)):
		return []
	var deltas: Dictionary = recent_result.get("deltas", {})
	var recent_message := str(context.get("recent_result_message", ""))
	var recent_bankroll_delta := int(context.get("recent_bankroll_delta", 0))
	var recent_suspicion_delta := int(context.get("recent_suspicion_delta", 0))
	var recent_alcohol_intake := int(context.get("recent_alcohol_intake", 0))
	var recent_drunk_delta := int(context.get("recent_drunk_delta", 0))
	var recent_alcoholic_delta := int(context.get("recent_alcoholic_delta", 0))
	var recent_luck_delta := int(context.get("recent_luck_delta", 0))
	var pressure: Dictionary = context.get("pressure", {})
	var cards: Array = []
	cards.append({
		"title": _outcome_card_title(recent_result),
		"tone": _outcome_card_tone(recent_result, recent_bankroll_delta, recent_suspicion_delta),
		"lines": [
			recent_message if not recent_message.is_empty() else "No result yet.",
			"Bankroll now %d." % run_state.bankroll,
		],
	})
	if not recent_result.is_empty() or recent_bankroll_delta != 0:
		cards.append({
			"title": "Bankroll",
			"tone": "positive" if recent_bankroll_delta >= 0 else "cost",
			"lines": [
				"Change %+d." % recent_bankroll_delta,
				"Current bankroll %d." % run_state.bankroll,
				_economy_cue_text() + ".",
			],
		})
	if recent_suspicion_delta != 0 or not (context.get("suspicion_cues", []) as Array).is_empty() or not (context.get("security_cues", []) as Array).is_empty():
		cards.append({
			"title": "Risk",
			"tone": "risk",
			"lines": _risk_card_lines(recent_suspicion_delta, context.get("suspicion_cues", []), context.get("security_cues", [])),
		})
	if recent_alcohol_intake != 0 or recent_drunk_delta != 0 or recent_alcoholic_delta != 0 or recent_luck_delta != 0 or run_state.drunk_level > 0 or run_state.alcoholic_level > 0 or run_state.baseline_luck != 0:
		cards.append({
			"title": "Alcohol",
			"tone": "risk" if run_state.alcoholic_level > run_state.drunk_level else "positive",
			"lines": _alcohol_card_lines(recent_alcohol_intake, recent_drunk_delta, recent_alcoholic_delta, recent_luck_delta),
		})
	var debt_changes := _copy_array(deltas.get("debt_changes", []))
	if not debt_changes.is_empty() or not (context.get("debt_items", []) as Array).is_empty():
		cards.append({
			"title": "Debt",
			"tone": "cost",
			"lines": _debt_card_lines(debt_changes, context.get("debt_items", [])),
		})
	var inventory_add := _copy_array(deltas.get("inventory_add", []))
	var inventory_remove := _copy_array(deltas.get("inventory_remove", []))
	if not inventory_add.is_empty() or not inventory_remove.is_empty() or not (context.get("inventory_items", []) as Array).is_empty():
		cards.append({
			"title": "Items",
			"tone": "positive",
			"lines": _inventory_card_lines(inventory_add, inventory_remove, context.get("inventory_items", [])),
		})
	var travel_hooks := _copy_array(deltas.get("travel_hooks_add", []))
	var travel_changes: Dictionary = deltas.get("travel_changes", {})
	if not travel_hooks.is_empty() or not travel_changes.is_empty() or not (context.get("travel_choices", []) as Array).is_empty():
		cards.append({
			"title": "Travel",
			"tone": "neutral",
			"lines": _travel_card_lines(travel_hooks, travel_changes, context.get("travel_choices", [])),
		})
	if _should_show_pressure_card(pressure):
		cards.append({
			"title": str(pressure.get("title", "Run pressure")),
			"tone": _pressure_card_tone(pressure),
			"lines": _pressure_card_lines(pressure),
		})
	var story_messages: Array = context.get("story_messages", [])
	if not recent_message.is_empty() or not story_messages.is_empty():
		cards.append({
			"title": "Story",
			"tone": "story",
			"lines": _story_card_lines(recent_message, story_messages),
		})
	cards.append({
		"title": "Next",
		"tone": "next",
		"lines": _next_action_lines(context.get("travel_choices", [])),
	})
	return cards


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
	return ["game_action", "game_action_summary", "item_effect", "item_sale", "event", "travel", "service_hook", "lender_hook", "game_hook", "prestige_purchase", "story_summary"].has(result_type)


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
		"prestige_purchase":
			return "Prestige Victory"
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
	var state := str(pressure.get("state", ""))
	return ["failed", "recovery", "distressed", "volatile", "victory"].has(state)


func _pressure_card_tone(pressure: Dictionary) -> String:
	match str(pressure.get("state", "")):
		"victory":
			return "positive"
		"failed":
			return "risk"
		"recovery", "distressed", "volatile":
			return "cost"
		_:
			return "neutral"


func _pressure_card_lines(pressure: Dictionary) -> Array:
	var lines: Array = []
	var summary := str(pressure.get("summary", ""))
	if not summary.is_empty():
		lines.append(summary)
	if bool(pressure.get("failed", false)):
		lines.append("Start over or load a saved run.")
	elif bool(pressure.get("recovery_available", false)):
		lines.append("Use recovery before pushing the run.")
	return lines


func _risk_card_lines(suspicion_delta: int, suspicion_cues: Variant, security_cues: Variant) -> Array:
	var lines: Array = []
	if suspicion_delta > 0:
		lines.append("Heat rises %+d: %s." % [suspicion_delta, run_state.security_pressure_label()])
	elif suspicion_delta < 0:
		lines.append("Heat cools %+d: %s." % [suspicion_delta, run_state.security_pressure_label()])
	else:
		lines.append("No new heat.")
	var cues := _copy_array(suspicion_cues)
	var security := _copy_array(security_cues)
	if not cues.is_empty():
		lines.append(str(cues[0]) + ".")
	elif not security.is_empty():
		lines.append("Room cue: %s" % str(security[0]))
	return lines


func _alcohol_card_lines(alcohol_intake: int, drunk_delta: int, alcoholic_delta: int, baseline_luck_delta: int) -> Array:
	var lines: Array = []
	if alcohol_intake > 0:
		lines.append("Drink +%d pending; need +%d." % [alcohol_intake, alcohol_intake])
	elif drunk_delta != 0 or alcoholic_delta != 0:
		var parts: Array = []
		if drunk_delta != 0:
			parts.append("drunk %+d" % drunk_delta)
		if alcoholic_delta != 0:
			parts.append("need %+d" % alcoholic_delta)
		lines.append(", ".join(parts).capitalize() + ".")
	if baseline_luck_delta != 0:
		lines.append("Baseline luck %+d." % baseline_luck_delta)
	lines.append(run_state.alcohol_pressure_summary())
	lines.append("Drunk %d, need %d, luck %+d." % [run_state.drunk_level, run_state.alcoholic_level, run_state.effective_luck()])
	return lines


func _debt_card_lines(debt_changes: Array, debt_items: Variant) -> Array:
	var lines: Array = []
	if not debt_changes.is_empty():
		lines.append("New pressure from %d lender%s." % [debt_changes.size(), "" if debt_changes.size() == 1 else "s"])
	var items := _copy_array(debt_items)
	if items.is_empty():
		lines.append("No active debt remains.")
	else:
		lines.append("Current debt: %s." % _debt_summary(items))
		lines.append(str(items[0]))
	return lines


func _inventory_card_lines(inventory_add: Array, inventory_remove: Array, inventory_items: Variant) -> Array:
	var lines: Array = []
	if not inventory_add.is_empty():
		lines.append("Gained: %s." % _item_id_list_label(inventory_add))
	if not inventory_remove.is_empty():
		lines.append("Used: %s." % _item_id_list_label(inventory_remove))
	var items := _copy_array(inventory_items)
	lines.append("Inventory: %s." % _inventory_summary(items))
	return lines


func _travel_card_lines(travel_hooks: Array, travel_changes: Dictionary, travel_choices: Variant) -> Array:
	var choices := _copy_array(travel_choices)
	var lines: Array = []
	if not travel_hooks.is_empty():
		lines.append("New routes: %s." % _travel_id_list_label(travel_hooks))
	if not travel_changes.is_empty():
		lines.append("Routes changed.")
	if choices.is_empty():
		lines.append("No route is available right now.")
	else:
		lines.append("Available: %s." % _travel_summary(choices))
	return lines


func _story_card_lines(recent_message: String, story_messages: Array) -> Array:
	var lines: Array = []
	if not recent_message.is_empty():
		lines.append(recent_message)
	for message in story_messages:
		var text := str(message)
		if not text.is_empty() and not lines.has(text):
			lines.append(text)
		if lines.size() >= 3:
			break
	return lines


func _next_action_lines(travel_choices: Variant) -> Array:
	var lines: Array = []
	if current_game != null:
		lines.append("Keep playing, change your stake, or go back to the environment.")
	else:
		lines.append("Choose a game, check events, review items, or save the run.")
	if not _copy_array(travel_choices).is_empty():
		lines.append("Travel is available when you are ready to move on.")
	return lines


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
		var summary := _effect_summary(item_definition.get("effect", {}) if typeof(item_definition.get("effect", {})) == TYPE_DICTIONARY else {})
		result.append("%s - %s" % [label, summary] if not summary.is_empty() else label)
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
		return "%s holds %s for %d, %s (%s)" % [label, item_name, balance, schedule, status]
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
	var display_text := _player_facing_text(text)
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
	start_foundation_run(seed_text, _new_run_challenge_for_seed(seed_text))


func start_generated_foundation_run() -> void:
	var seed_text := _generate_menu_seed_text()
	if seed_input != null:
		seed_input.text = seed_text
	start_foundation_run(seed_text, _new_run_challenge_for_seed(seed_text))


func return_to_main_menu() -> void:
	if _all_in_result_terminal_check_is_pending():
		_evaluate_run_terminal_state(true)
	if run_state != null and not dev_game_test_mode:
		_autosave_foundation_run("Autosaved before main menu.", true)
	pending_all_in_result_terminal_check = false
	_reset_game_surface_runtime_state()
	current_game = null
	game_surface_ui_state = {}
	last_environment_runtime_result = {}
	run_state = null
	dev_game_test_mode = false
	_refresh_run_action_service()
	close_content_group_config()
	close_challenge_selection()
	_hide_run_menu()
	_hide_event_choice_popup()
	_hide_run_inventory_popup()
	_hide_run_journal_popup()
	_hide_travel_transition()
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
	if procedural_music_player != null and user_settings != null:
		procedural_music_player.audio_calm = bool(user_settings.audio_calm)
		_update_procedural_music()
	if run_state != null:
		_render_foundation_snapshots()
		_refresh_world_header()


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
	_clear_selected_prestige_purchase()
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


func _refresh_start_screen() -> void:
	if release_version_label != null:
		release_version_label.text = _release_version_text()
	var has_save := _has_foundation_save()
	if start_status_label != null:
		if has_save:
			start_status_label.text = "Saved run available. Continue it, or enter a seed for a new run."
		elif start_status_label.text.is_empty() or start_status_label.text.begins_with("Saved run") or start_status_label.text.begins_with("No saved"):
			start_status_label.text = "No saved run yet. Enter a seed or use the generated one."
	if continue_button != null:
		continue_button.disabled = not has_save
		continue_button.text = "Continue"
		continue_button.tooltip_text = "Load the saved run." if has_save else "No saved run yet."
	_refresh_content_group_controls()
	_refresh_challenge_controls()


func _release_version_text() -> String:
	var release_version := str(ProjectSettings.get_setting("application/config/version", "0.3.0")).strip_edges()
	if release_version.is_empty():
		release_version = "0.3.0"
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
		"visible_bankroll": run_state.bankroll if run_state != null else 0,
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
				run_state.bankroll,
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
	var pressure := _run_pressure_view()
	var prestige := _primary_prestige_option()
	var demo_objective := _demo_objective_status()
	var pit_boss_watch := _pit_boss_watch_status()
	var guidance := _objective_guidance_view(prestige, pressure, demo_objective)
	var recent_result := _recent_result_snapshot()
	var deltas: Dictionary = recent_result.get("deltas", {})
	var bankroll_delta := int(recent_result.get("bankroll_delta", deltas.get("bankroll_delta", 0)))
	var heat_delta := int(recent_result.get("suspicion_delta", deltas.get("suspicion_delta", 0)))
	var debt_items := _debt_view_list()
	var inventory_items := _inventory_view_list()
	var environment := run_state.current_environment
	var bankroll_text := "[$] Bankroll %d" % run_state.bankroll
	if bankroll_delta != 0:
		bankroll_text += " (%+d)" % bankroll_delta
	var heat_meter := _hud_meter(run_state.suspicion_level(), 100, 10)
	var heat_text := "[HEAT] Risk: %s %s" % [heat_meter, run_state.security_pressure_label().capitalize()]
	if heat_delta != 0:
		heat_text += " (%+d)" % heat_delta
	var drunk_meter := _hud_meter(run_state.drunk_level, 100, 8)
	var drunk_time_scale := run_state.drunk_time_scale()
	var drunk_world_speed_percent := run_state.drunk_time_scale_percent()
	var alcohol_text := "[DRINK] %s %s Luck %+d" % [
		run_state.alcohol_condition_label().capitalize(),
		drunk_meter,
		run_state.effective_luck(),
	]
	if run_state.drunk_level > 0:
		alcohol_text += " Time %d%%" % drunk_world_speed_percent
	var pending_drink := run_state.pending_drunk_absorption_amount()
	if pending_drink > 0:
		alcohol_text += " (+%d pending)" % pending_drink
	var debt_text := "[DEBT] %s" % _hud_debt_text(debt_items)
	var run_text := "[RUN] %s" % _hud_run_status_text(pressure)
	var save_text := _hud_save_text()
	var goal_text := _hud_goal_text(prestige, pressure, demo_objective)
	var environment_text := "[ENV] %s / %s" % [
		_hud_short(str(environment.get("display_name", "Environment")), 28),
		_label_from_id(str(environment.get("kind", environment.get("archetype_id", "room")))),
	]
	var inventory_text := "[GEAR] %s" % _hud_inventory_text(inventory_items)
	var economy_text := "Cash: %s" % _economy_cue_text()
	var heat_summary_text := "Heat: %s" % run_state.security_pressure_label().capitalize()
	var pit_boss_text := _pit_boss_hud_text(pit_boss_watch)
	var alcohol_summary_text := "Alcohol: %s" % run_state.alcohol_pressure_summary()
	var next_objective := _next_objective_option()
	var next_hint := str(next_objective.get("hint", ""))
	var next_text := "Next: %s" % next_hint if not next_hint.is_empty() else "Next: inspect the room"
	var pressure_text := _objective_pressure_text(pressure)
	var objective_parts := [
		"[GOAL] Goal: %s" % goal_text,
		economy_text,
		heat_summary_text,
		alcohol_summary_text,
		environment_text,
		inventory_text,
		next_text,
	]
	if not pressure_text.is_empty():
		objective_parts.insert(3, "Status: %s" % _hud_short(pressure_text, 38))
	if not pit_boss_text.is_empty():
		objective_parts.insert(4, pit_boss_text)
	return {
		"status_text": "%s  %s  %s  %s  %s" % [bankroll_text, heat_text, alcohol_text, debt_text, run_text],
		"objective_text": " | ".join(objective_parts),
		"save_text": save_text,
		"bankroll_text": bankroll_text,
		"bankroll": run_state.bankroll,
		"bankroll_delta": bankroll_delta,
		"heat_text": heat_text,
		"heat_meter": heat_meter,
		"heat_level": run_state.suspicion_level(),
		"heat_delta": heat_delta,
		"alcohol_text": alcohol_text,
		"alcohol_summary_text": alcohol_summary_text,
		"drunk_level": run_state.drunk_level,
		"drunk_time_scale": drunk_time_scale,
		"drunk_time_scale_percent": drunk_world_speed_percent,
		"drunk_world_speed_percent": drunk_world_speed_percent,
		"pending_drunk_absorption": pending_drink,
		"alcoholic_level": run_state.alcoholic_level,
		"baseline_luck": run_state.baseline_luck,
		"luck_modifier": run_state.effective_luck(),
		"debt_text": debt_text,
		"environment_text": environment_text,
		"inventory_text": inventory_text,
		"run_text": run_text,
		"goal_text": goal_text,
		"objective_state": str(guidance.get("state", "")),
		"objective_guidance": guidance,
		"demo_objective": demo_objective,
		"pit_boss_watch": pit_boss_watch,
		"next_text": next_text,
		"next_objective": next_objective,
		"pressure": pressure,
		"run_status": run_state.run_status,
	}


func _hud_goal_text(prestige: Dictionary, pressure: Dictionary, demo_objective: Dictionary = {}) -> String:
	var text := _objective_goal_text(prestige, pressure, demo_objective)
	text = text.replace("Double-click it to win.", "double-click to win.")
	return _hud_short(text, 54)


func _hud_debt_text(debt_items: Array) -> String:
	if debt_items.is_empty():
		return "none"
	if debt_items.size() == 1:
		return _hud_short(str(debt_items[0]), 30)
	return "%d active debts" % debt_items.size()


func _hud_inventory_text(inventory_items: Array) -> String:
	if inventory_items.is_empty():
		return "empty"
	if inventory_items.size() == 1:
		var item_text := str(inventory_items[0])
		var effect_index := item_text.find(" - ")
		if effect_index != -1:
			item_text = item_text.substr(0, effect_index)
		return _hud_short(item_text, 24)
	return "%d items" % inventory_items.size()


func _hud_run_status_text(pressure: Dictionary) -> String:
	var pressure_state := str(pressure.get("state", ""))
	match pressure_state:
		"victory":
			return "Victory"
		"failed":
			return "Failure"
		"recovery":
			return "Recovery"
		"distressed":
			return "Pressure"
		_:
			return "Active" if run_state.run_status == "active" else run_state.run_status.capitalize()


func _hud_save_text() -> String:
	var availability := "on" if _has_foundation_save() else "pending"
	var status := save_status_message
	if status.is_empty():
		status = "current run"
	return "[AUTO] %s / %s" % [availability.capitalize(), _hud_short(status, 24)]


func _hud_meter(value: int, maximum: int, width: int) -> String:
	var filled := 0
	if maximum > 0 and width > 0:
		filled = clampi(roundi(float(clampi(value, 0, maximum)) / float(maximum) * float(width)), 0, width)
	return "[%s%s]" % [_repeat_char("#", filled), _repeat_char("-", maxi(0, width - filled))]


func _repeat_char(character: String, count: int) -> String:
	var result := ""
	for _index in range(maxi(0, count)):
		result += character
	return result


func _hud_short(text: String, max_length: int) -> String:
	var cleaned := _player_facing_text(text).strip_edges()
	if cleaned.length() <= max_length:
		return cleaned
	if max_length <= 3:
		return cleaned.left(max_length)
	return "%s..." % cleaned.left(max_length - 3)


func _objective_goal_text(prestige: Dictionary, pressure: Dictionary, demo_objective: Dictionary = {}) -> String:
	var pressure_state := str(pressure.get("state", ""))
	if pressure_state == "victory":
		return "Victory claimed. Return to the menu or start fresh."
	if pressure_state == "failed":
		return "Run failed. Return to the menu to continue or start over."
	if pressure_state == "recovery":
		return "Recover with available help before playing."
	if bool(demo_objective.get("active", false)):
		if _is_boss_floor_demo_objective(demo_objective):
			return _boss_floor_objective_goal_text(demo_objective)
		var title := str(demo_objective.get("title", "Beat the house"))
		var target := int(demo_objective.get("target_bankroll", 0))
		var remaining := int(demo_objective.get("remaining_bankroll", 0))
		if bool(demo_objective.get("complete", false)):
			return "%s complete. Cash out to move on." % title
		return "%s: reach $%d. Need $%d." % [title, target, remaining]
	if not prestige.is_empty():
		var label := str(prestige.get("display_name", "prestige target"))
		if bool(prestige.get("enabled", false)):
			return "%s is ready. Double-click it to win." % label
		var reason := str(prestige.get("disabled_reason", "Build bankroll and keep heat down."))
		return "Build toward %s. %s" % [label, reason]
	var hint := str(run_state.current_environment.get("objective_hint", "")).strip_edges()
	if not hint.is_empty():
		return "Build cash, find Grand Casino routes, keep heat low."
	return "Build cash, find Grand Casino routes, keep heat low."


func _boss_floor_objective_goal_text(demo_objective: Dictionary) -> String:
	var state := str(demo_objective.get("objective_state", "grand-incomplete"))
	if state == "showdown-active":
		return "Rourke has you in back. Keep your story straight."
	if state == "showdown-pending" or bool(demo_objective.get("showdown_pending", false)):
		return "Rourke is calling. Answer the back-room event."
	if state == "high-roller-ready" or bool(demo_objective.get("high_roller_ready", false)):
		return "Players Card is ready. Claim it before heat rises."
	if bool(demo_objective.get("dirty_money_showdown_ready", false)):
		return "The card review is checking your win. Expect Rourke."
	if _boss_floor_heat_pressure_close(demo_objective):
		return "Heat is loud. More pressure means Rourke's back room."
	if _boss_floor_high_roller_progress_close(demo_objective):
		return "Close to Players Card: keep play clean and finish the set."
	return "Win $200 here for a Players Card, or survive Rourke."


func _objective_presentation_state(pressure: Dictionary, demo_objective: Dictionary) -> String:
	var pressure_state := str(pressure.get("state", ""))
	if pressure_state == "victory":
		return "victory"
	if pressure_state == "failed":
		return "failure"
	if bool(demo_objective.get("active", false)) and _is_boss_floor_demo_objective(demo_objective):
		var state := str(demo_objective.get("objective_state", "")).strip_edges()
		if not state.is_empty():
			return state
		return "grand-incomplete"
	return "pre-grand"


func _objective_guidance_view(prestige: Dictionary, pressure: Dictionary, demo_objective: Dictionary) -> Dictionary:
	var state := _objective_presentation_state(pressure, demo_objective)
	var guidance_text := ""
	var route_name := ""
	match state:
		"victory":
			route_name = "summary"
			guidance_text = "Victory is claimed. Review the run summary or start fresh."
		"failure":
			route_name = "summary"
			guidance_text = "The run is over. Return to the menu or start a new climb."
		"high-roller-ready":
			route_name = "players_card"
			guidance_text = "The host will issue the Players Card if you take the review now."
		"showdown-pending":
			route_name = "pit_boss_showdown"
			guidance_text = "Rourke is calling. Take the back-room event before more play."
		"showdown-active":
			route_name = "pit_boss_showdown"
			guidance_text = "Rourke has you off the floor. Choose one answer and stand by it."
		"grand-incomplete":
			route_name = "boss_floor"
			guidance_text = _boss_floor_incomplete_guidance(demo_objective)
		_:
			route_name = "reach_boss_floor"
			guidance_text = "Build cash, scout a route to the Grand Casino, and keep heat low."
	return {
		"state": state,
		"route": route_name,
		"text": guidance_text,
		"clean_progress_close": _boss_floor_high_roller_progress_close(demo_objective),
		"heat_pressure_close": _boss_floor_heat_pressure_close(demo_objective),
		"staff_attention": bool(demo_objective.get("staff_attention_active", false)),
		"next": _next_objective_option_for_state(state, demo_objective, prestige),
	}


func _boss_floor_incomplete_guidance(demo_objective: Dictionary) -> String:
	if bool(demo_objective.get("dirty_money_showdown_ready", false)):
		return "The money is there, but the floor wants Rourke to review it."
	if _boss_floor_heat_pressure_close(demo_objective):
		return "Rourke is close enough to matter. Keep heat down or prepare for the back room."
	if _boss_floor_high_roller_progress_close(demo_objective):
		return "The host is nearly ready to issue the card. Finish clean play and avoid loud heat."
	return "Win clean toward the Players Card, or survive Rourke if attention turns."


func _boss_floor_high_roller_progress_close(demo_objective: Dictionary) -> bool:
	if not bool(demo_objective.get("active", false)) or not _is_boss_floor_demo_objective(demo_objective):
		return false
	if bool(demo_objective.get("showdown_pending", false)) or bool(demo_objective.get("showdown_active", false)):
		return false
	if bool(demo_objective.get("cheat_evidence", false)) or bool(demo_objective.get("watched_cheat_evidence", false)):
		return false
	if int(demo_objective.get(_boss_floor_status_key("max_heat"), 0)) > int(demo_objective.get("high_roller_max_heat", 100)):
		return false
	if bool(demo_objective.get("high_roller_ready", false)):
		return true
	var remaining_games := int(demo_objective.get("high_roller_remaining_games", 0))
	var remaining_bankroll := int(demo_objective.get("remaining_bankroll", 0))
	var remaining_net := int(demo_objective.get("high_roller_remaining_net_winnings", 0))
	var target_bankroll := int(demo_objective.get("high_roller_target_bankroll", demo_objective.get("target_bankroll", 0)))
	var bankroll_close := target_bankroll > 0 and remaining_bankroll <= 50
	return remaining_games <= 1 and (bankroll_close or remaining_net <= 25)


func _boss_floor_heat_pressure_close(demo_objective: Dictionary) -> bool:
	if not bool(demo_objective.get("active", false)) or not _is_boss_floor_demo_objective(demo_objective):
		return false
	if bool(demo_objective.get("showdown_pending", false)) or bool(demo_objective.get("showdown_active", false)):
		return true
	var current_heat := int(demo_objective.get("current_heat", 0))
	var threshold := int(demo_objective.get("showdown_heat_threshold", 70))
	var staff_attention := bool(demo_objective.get("staff_attention_active", false))
	var warning_band := 12 if staff_attention else 6
	return current_heat >= maxi(0, threshold - warning_band)


func _is_boss_floor_demo_objective(demo_objective: Dictionary) -> bool:
	return bool(demo_objective.get(_boss_floor_status_key("objective"), false))


func _boss_floor_status_key(suffix: String) -> String:
	return "%s_%s" % [RunState.GRAND_CASINO_ARCHETYPE_ID, suffix]


func _objective_pressure_text(pressure: Dictionary) -> String:
	var pressure_state := str(pressure.get("state", ""))
	if ["failed", "recovery", "distressed", "victory"].has(pressure_state):
		return _pressure_status_text(pressure)
	return ""


func _demo_objective_status() -> Dictionary:
	if run_state == null:
		return {}
	return run_state.demo_objective_status()


func _pit_boss_watch_status() -> Dictionary:
	if run_state == null:
		return {}
	return run_state.pit_boss_watch_status(run_state.current_environment)


func _pit_boss_hud_text(status: Dictionary) -> String:
	if not bool(status.get("active", false)):
		return ""
	if bool(status.get("watched", false)):
		return "Pit boss: watching"
	return "Pit boss: turned away"


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

	var prestige := _primary_prestige_option()
	var demo_objective := _demo_objective_status()
	var objective_state := _objective_presentation_state(pressure, demo_objective)
	var state_objective := _next_objective_option_for_state(objective_state, demo_objective, prestige)
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
		if not prestige.is_empty():
			var in_game_prestige_label := str(prestige.get("display_name", "victory target"))
			var in_game_prestige_id := str(prestige.get("id", ""))
			if bool(prestige.get("enabled", false)):
				return _objective_for_object(
					CONTEXT_MODE_PRESTIGE,
					"prestige:%s" % in_game_prestige_id,
					"return to room and claim %s" % in_game_prestige_label,
					true
				)
			if _prestige_needs_more_places(prestige):
				var in_game_travel := _first_enabled_travel_choice()
				if not in_game_travel.is_empty():
					return _objective_for_object(
						CONTEXT_MODE_TRAVEL,
						"travel:%s" % str(in_game_travel.get("id", "")),
						"return to room and visit another place",
						true
					)
		return {
			"hint": "choose stake and click a game-surface action",
			"object_type": "game_surface",
			"object_id": "",
			"enabled": true,
		}
	if not prestige.is_empty():
		var prestige_label := str(prestige.get("display_name", "victory target"))
		var prestige_id := str(prestige.get("id", ""))
		if bool(prestige.get("enabled", false)):
			return _objective_for_object(
				CONTEXT_MODE_PRESTIGE,
				"prestige:%s" % prestige_id,
				"claim %s" % prestige_label,
				true
			)
		if _prestige_needs_more_places(prestige):
			var travel := _first_enabled_travel_choice()
			if not travel.is_empty():
				return _objective_for_object(
					CONTEXT_MODE_TRAVEL,
					"travel:%s" % str(travel.get("id", "")),
					"visit another place",
					true
				)

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


func _next_objective_option_for_state(state: String, demo_objective: Dictionary, _prestige: Dictionary = {}) -> Dictionary:
	if not bool(demo_objective.get("active", false)) or not _is_boss_floor_demo_objective(demo_objective):
		return {}
	if state == "showdown-pending" or state == "showdown-active":
		var showdown_event_id := str(demo_objective.get("showdown_event_id", demo_objective.get("finale_event_id", ""))).strip_edges()
		if showdown_event_id.is_empty():
			showdown_event_id = RunState.GRAND_CASINO_SHOWDOWN_EVENT_ID
		return _objective_for_object(CONTEXT_MODE_EVENT, "event:%s" % showdown_event_id, "answer Rourke's back-room call", true)
	if state == "high-roller-ready":
		var high_roller_event_id := str(demo_objective.get("high_roller_event_id", "")).strip_edges()
		if high_roller_event_id.is_empty():
			high_roller_event_id = RunState.GRAND_CASINO_HIGH_ROLLER_EVENT_ID
		return _objective_for_object(CONTEXT_MODE_EVENT, "event:%s" % high_roller_event_id, "claim the Players Card", true)
	return {}


func _objective_for_object(object_type: String, object_id: String, hint: String, enabled: bool) -> Dictionary:
	return {
		"hint": _player_facing_text(hint),
		"object_type": object_type,
		"object_id": object_id,
		"enabled": enabled,
	}


func _prestige_needs_more_places(prestige: Dictionary) -> bool:
	var reason := str(prestige.get("disabled_reason", "")).to_lower()
	return reason.find("visit") != -1 and reason.find("place") != -1


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


func _primary_prestige_option() -> Dictionary:
	var options := _prestige_purchase_view_list()
	for option in options:
		if typeof(option) == TYPE_DICTIONARY:
			return (option as Dictionary).duplicate(true)
	return {}


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
	if run_state == null or library == null or run_state.bankroll > 0 or run_state.current_environment.is_empty():
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
	var result := RunTerminalEvaluatorScript.evaluate_and_apply(run_state, library)
	_route_ended_run_if_needed(result)
	_route_failed_run_if_needed(result)
	return result


func _all_in_result_terminal_check_is_pending() -> bool:
	return pending_all_in_result_terminal_check \
		and run_state != null \
		and run_state.run_status != RunState.RUN_STATUS_FAILED \
		and run_state.run_status != RunState.RUN_STATUS_ENDED \
		and run_state.bankroll <= 0


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
	_clear_selected_prestige_purchase()
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
	_clear_terminal_interaction_state()
	_set_current_screen(SCREEN_VICTORY)
	_record_challenge_completion_if_needed()
	var message := str(terminal_result.get("message", "")).strip_edges()
	if message.is_empty():
		message = str(_victory_summary_snapshot().get("message", "The run is complete."))
	_show_message(message)
	return true


func _route_failed_run_if_needed(terminal_result: Dictionary = {}) -> bool:
	if run_state == null or run_state.run_status != RunState.RUN_STATUS_FAILED:
		return false
	_clear_terminal_interaction_state()
	_set_current_screen(SCREEN_FAILURE)
	var message := run_state.run_failure_message
	if message.strip_edges().is_empty():
		message = str(terminal_result.get("message", "The run is over."))
	_show_message(message)
	return true


func _record_challenge_completion_if_needed() -> void:
	if run_state == null or run_state.run_status != RunState.RUN_STATUS_ENDED:
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
	if pressure.is_empty():
		return ""
	var title := str(pressure.get("title", ""))
	var summary := str(pressure.get("summary", ""))
	if title.is_empty():
		return summary
	if summary.is_empty() or summary == title:
		return title
	return "%s: %s" % [title, summary]


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
	if result.is_empty():
		return ""
	var type := str(result.get("type", ""))
	match type:
		"game_action", "game_action_summary", "game_enter":
			var game_id := str(result.get("game_id", result.get("source_id", "")))
			return "game:%s" % game_id if not game_id.is_empty() else ""
		"item_effect", "item_sale":
			var item_id := str(result.get("item_id", result.get("source_id", "")))
			return "item:%s" % item_id if not item_id.is_empty() else ""
		"event":
			var event_id := str(result.get("event_id", result.get("source_id", "")))
			return "event:%s" % event_id if not event_id.is_empty() else ""
		"service_hook":
			var service_id := str(result.get("source_id", ""))
			return "service:%s" % service_id if not service_id.is_empty() else ""
		"lender_hook":
			var lender_id := str(result.get("source_id", ""))
			return "lender:%s" % lender_id if not lender_id.is_empty() else ""
		"game_hook":
			var source_id := str(result.get("source_id", ""))
			if source_id.contains(":"):
				var parts := source_id.split(":")
				if parts.size() >= 2:
					return "game_hook:%s:%s" % [str(parts[0]), str(parts[1])]
			return "game:%s" % str(result.get("game_id", "")) if not str(result.get("game_id", "")).is_empty() else ""
		"prestige_purchase":
			var purchase_id := str(result.get("source_id", ""))
			return "prestige:%s" % purchase_id if not purchase_id.is_empty() else ""
		_:
			return ""


func _outcome_message(result: Dictionary) -> String:
	var message := _player_facing_text(str(result.get("message", "")))
	if not message.is_empty():
		return message
	var messages := _copy_array(result.get("messages", []))
	if not messages.is_empty():
		return _player_facing_text(str(messages[0]))
	return ""


func _run_summary_text(state: RunState) -> String:
	if state == null:
		return "No active run."
	var environment := state.current_environment
	var environment_name := str(environment.get("display_name", environment.get("id", "No environment")))
	var travel_count := _run_travel_target_count(state)
	var pressure: Dictionary = _run_pressure_view() if state == run_state else state.recovery_pressure_status()
	var pressure_text := _pressure_status_text(pressure)
	return "%s | Bankroll %d | %s | Heat %d | Story %d | Clues %d | Routes %d" % [
		environment_name,
		state.bankroll,
		pressure_text,
		state.suspicion_level(),
		state.story_log_entry_count(),
		state.narrative_flags.size(),
		travel_count,
	]


func _run_travel_target_count(state: RunState) -> int:
	if state == null:
		return 0
	var result: Array = []
	for source in [
		state.current_environment.get("next_archetypes", []),
		state.current_environment.get("travel_hooks", []),
	]:
		for target_id in _string_array(source):
			if not result.has(target_id):
				result.append(target_id)
	return result.size()


func _game_result_from_story_log(entries: Array) -> Dictionary:
	for index in range(entries.size() - 1, -1, -1):
		var entry: Variant = entries[index]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var story_entry := entry as Dictionary
		if str(story_entry.get("type", "")) != "game_action":
			continue
		var game_id := str(story_entry.get("game_id", ""))
		var game_name := _game_display_name(game_id)
		var action_label := _label_from_id(str(story_entry.get("action_id", "action")))
		var bankroll_delta := int(story_entry.get("bankroll_delta", 0))
		var suspicion_delta := int(story_entry.get("suspicion_delta", 0))
		var message := "Last saved play: %s, %s. Bankroll %+d, heat %+d." % [
			game_name,
			action_label,
			bankroll_delta,
			suspicion_delta,
		]
		var result := GameModule.build_action_result({
			"ok": true,
			"type": "game_action_summary",
			"source_id": game_id,
			"game_id": game_id,
			"action_id": str(story_entry.get("action_id", "")),
			"action_kind": "summary",
			"bankroll_delta": bankroll_delta,
			"suspicion_delta": suspicion_delta,
			"deltas": {
				"bankroll_delta": bankroll_delta,
				"suspicion_delta": suspicion_delta,
				"messages": [message],
			},
			"won": bool(story_entry.get("won", false)),
			"environment_id": str(story_entry.get("environment_id", "")),
			"message": message,
		})
		result["display_name"] = "%s Saved Result" % game_name
		result["summary_source"] = "saved_story_log"
		return result
	return {}


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
	var definition := library.game(game_id)
	var archetype := _game_test_archetype()
	var visual_context := _copy_dict(archetype.get("visual_context", {}))
	if visual_context.is_empty():
		visual_context = {"art_key": str(archetype.get("id", "test_lab"))}
	var archetype_id := str(archetype.get("id", "test_lab"))
	var security_profile := _copy_dict(archetype.get("security_profile", {}))
	security_profile["strictness"] = _game_test_security_strictness()
	var economic_profile := _copy_dict(archetype.get("economic_profile", {}))
	economic_profile["stake_floor"] = _game_test_stake_floor()
	economic_profile["stake_ceiling"] = _game_test_stake_ceiling()
	var environment := {
		"id": "practice_%s" % game_id,
		"archetype_id": archetype_id,
		"kind": str(archetype.get("kind", "casino")),
		"display_name": "Practice: %s" % str(definition.get("display_name", game_id.capitalize())),
		"tier": 4,
		"depth": 4,
		"art_key": str(visual_context.get("art_key", archetype_id)),
		"visual_context": visual_context,
		"layout": _copy_dict(archetype.get("layout", {})),
		"security_profile": security_profile,
		"music_profile": _copy_dict(archetype.get("music_profile", {})),
		"economic_profile": economic_profile,
		"objective_hint": "Practice the table.",
		"demo_objective": {},
		"game_ids": [game_id],
		"game_states": {},
		"event_ids": [],
		"item_offers": [],
		"service_ids": [],
		"lender_hooks": [],
		"suspicion_cues": _copy_array(archetype.get("suspicion_cues", [])),
		"travel_hooks": [],
		"next_archetypes": [],
		"local_narrative_flags": {"practice_session": true},
		"moods": _copy_array(archetype.get("moods", ["boss"])),
		"mood": "boss",
		"turns": 0,
		"resolved_event_ids": [],
	}
	var overrides := _game_test_generation_overrides()
	var environment_overrides := _copy_dict(overrides.get("environment", {}))
	if not environment_overrides.is_empty():
		_deep_merge_dict(environment, environment_overrides)
	var rng := run_state.create_rng("game_test_environment:%s" % game_id) if run_state != null else RngStream.new()
	if rng.seed_value == 0:
		rng.configure(1)
	var generated := game.generate_environment_state(run_state, environment, rng.fork("game_state:%s" % game_id))
	if not generated.is_empty():
		var state_overrides := _copy_dict(overrides.get("game_state", {}))
		if state_overrides.is_empty() and not overrides.has("environment"):
			state_overrides = overrides
		if not state_overrides.is_empty():
			_deep_merge_dict(generated, state_overrides)
		var states: Dictionary = environment.get("game_states", {})
		states[game_id] = generated.duplicate(true)
		environment["game_states"] = states
	environment["layout"] = EnvironmentInstance.ensure_generated_layout(environment)
	return environment


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
	if run_state == null or library == null or game_id.is_empty():
		return {}
	var definition := library.game(game_id)
	if definition.is_empty():
		return {}
	var game := _create_game_module(definition)
	if game == null:
		return {"ok": false}
	var action_view := game.actions(run_state, run_state.current_environment)
	var range := _stake_range_from_action_view(action_view)
	var legal_actions: Array = action_view.get("legal_actions", [])
	var cheat_actions: Array = action_view.get("cheat_actions", [])
	return {
		"ok": true,
		"display_name": game.get_display_name(),
		"stake_min": int(range.get("min", 1)),
		"stake_max": int(range.get("max", 1)),
		"has_valid_stake": bool(range.get("has_valid", false)),
		"legal_count": legal_actions.size(),
		"cheat_count": cheat_actions.size(),
		"risk_cue": _cheat_action_risk_cue(cheat_actions),
	}


func _current_game_description() -> String:
	if current_game == null:
		return ""
	var definition: Dictionary = current_game.definition
	var description := str(definition.get("description", ""))
	if description.is_empty():
		description = str(definition.get("intro", "Choose a stake on the surface, then click an action."))
	return description


func _cheat_action_risk_cue(actions: Variant) -> String:
	if typeof(actions) != TYPE_ARRAY or (actions as Array).is_empty():
		return "No risky action is available here."
	var largest_risk := 0
	var pressure_summary := ""
	for action in actions:
		if typeof(action) != TYPE_DICTIONARY:
			continue
		var action_data := action as Dictionary
		largest_risk = maxi(largest_risk, int(action_data.get("suspicion_delta", 0)))
		if int(action_data.get("security_pressure_bonus", 0)) > 0:
			pressure_summary = str(action_data.get("security_pressure_summary", "The room is watching."))
	if largest_risk <= 0:
		return "Risk cue: this option may draw attention."
	if not pressure_summary.is_empty():
		return "Risk cue: %s Risky actions can draw up to %d heat." % [pressure_summary, largest_risk]
	return "Risk cue: risky actions can draw up to %d heat." % largest_risk


func _selected_action_summary() -> String:
	if selected_action_id.is_empty():
		return "No action selected."
	var kind := "risky" if selected_action_kind == "cheat" else "legal"
	var action := _available_game_action(selected_action_id, selected_action_kind)
	var detail := _game_action_choice_summary(action, selected_action_kind)
	if detail.is_empty():
		detail = "Click the highlighted surface action again to resolve."
	else:
		detail = "%s Click the highlighted surface action again to resolve." % detail
	return "%s action: %s at stake %d. %s" % [
		kind.capitalize(),
		selected_action_label,
		_current_selected_stake(),
		detail,
	]


func _game_recent_outcome_text() -> String:
	var result := _current_game_result_snapshot()
	if result.is_empty():
		return "No game outcome yet."
	var message := _player_facing_text(str(result.get("message", "")))
	var deltas: Dictionary = result.get("deltas", {})
	var bankroll_delta := int(result.get("bankroll_delta", deltas.get("bankroll_delta", 0)))
	var suspicion_delta := int(result.get("suspicion_delta", deltas.get("suspicion_delta", 0)))
	return "%s Bankroll %+d, heat %+d." % [
		message if not message.is_empty() else "Recent play resolved.",
		bankroll_delta,
		suspicion_delta,
	]


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
	if run_state == null:
		return {"min": 1, "max": 1, "default": 1, "has_valid": false}
	if current_game != null:
		var view := action_view
		if view.is_empty():
			view = current_game.actions(run_state, run_state.current_environment)
		return _stake_range_from_action_view(view)
	return _stake_range_from_action_view(action_view)


func _stake_range_from_action_view(action_view: Dictionary = {}) -> Dictionary:
	if run_state == null:
		return {"min": 1, "max": 1, "default": 1, "has_valid": false}
	var floor := 1
	var ceiling := run_state.bankroll
	var economic_profile: Dictionary = run_state.current_environment.get("economic_profile", {})
	floor = int(economic_profile.get("stake_floor", floor))
	ceiling = int(economic_profile.get("stake_ceiling", ceiling))
	if not action_view.is_empty():
		floor = int(action_view.get("stake_floor", floor))
		ceiling = int(action_view.get("stake_ceiling", ceiling))
	var min_stake := maxi(1, floor)
	var max_stake := mini(ceiling, run_state.bankroll)
	var has_valid := max_stake >= min_stake
	return {
		"min": min_stake,
		"max": max_stake,
		"base_max": int(action_view.get("base_stake_ceiling", ceiling)) if not action_view.is_empty() else ceiling,
		"recommended_max": int(action_view.get("economy_stake_ceiling", max_stake)) if not action_view.is_empty() else run_state.economy_stake_ceiling(ceiling),
		"default": min_stake if has_valid else 0,
		"has_valid": has_valid,
		"economy_state": run_state.economy(),
		"economy_pressure_applied": bool(action_view.get("economy_pressure_applied", false)) if not action_view.is_empty() else max_stake < mini(ceiling, run_state.bankroll),
	}


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
	if current_game == null or run_state == null:
		return []
	var source := current_game.legal_actions(run_state, run_state.current_environment)
	if action_kind == "cheat":
		source = current_game.cheat_actions(run_state, run_state.current_environment)
	var actions: Array = []
	for action in source:
		if typeof(action) != TYPE_DICTIONARY:
			continue
		var action_data := action as Dictionary
		var action_id := str(action_data.get("id", ""))
		if action_id.is_empty():
			continue
		actions.append({
			"id": action_id,
			"kind": action_kind,
			"label": _action_label(action_data),
			"summary": _game_action_choice_summary(action_data, action_kind),
			"win_chance": int(action_data.get("win_chance", 0)),
			"payout_mult": int(action_data.get("payout_mult", 0)),
			"suspicion_delta": int(action_data.get("suspicion_delta", 0)),
			"selected": action_id == selected_action_id and action_kind == selected_action_kind,
		})
	return actions


func _available_game_action(action_id: String, action_kind: String) -> Dictionary:
	var source := current_game.legal_actions(run_state, run_state.current_environment)
	if action_kind == "cheat":
		source = current_game.cheat_actions(run_state, run_state.current_environment)
	for action in source:
		if typeof(action) == TYPE_DICTIONARY and str((action as Dictionary).get("id", "")) == action_id:
			return (action as Dictionary).duplicate(true)
	return {}


func _action_label(action: Dictionary) -> String:
	var label := str(action.get("label", ""))
	if not label.is_empty():
		return label
	var action_id := str(action.get("id", ""))
	if action_id.is_empty():
		return "Action"
	return action_id.replace("_", " ").capitalize()


func _action_kind_label(action_kind: String) -> String:
	return "cheat/advantage" if action_kind == "cheat" else "legal"


func _game_action_choice_summary(action: Dictionary, action_kind: String = "") -> String:
	if action.is_empty():
		return ""
	var parts: Array = []
	var win_chance := int(action.get("win_chance", 0))
	if win_chance > 0:
		parts.append("Win %d%%" % win_chance)
	var payout_mult := int(action.get("payout_mult", 0))
	if payout_mult > 0:
		parts.append("Pay %dx" % payout_mult)
	var suspicion_delta := int(action.get("suspicion_delta", 0))
	if suspicion_delta != 0:
		parts.append("Heat %s" % _signed_int_text(suspicion_delta))
	elif action_kind == "cheat":
		parts.append("Heat risk")
	return " / ".join(parts)


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
	if run_state == null or library == null:
		return []
	var options: Array = []
	for event_id in _string_array(run_state.current_environment.get("event_ids", [])):
		var option := _eligible_event_option(event_id)
		if option.is_empty():
			continue
		if str(option.get("interaction_mode", "interactable")) != "interactable":
			continue
		options.append(option)
	return options


func _eligible_event_option(event_id: String) -> Dictionary:
	return _eligible_event_option_with_context(event_id, {})


func _eligible_event_option_with_context(event_id: String, context: Dictionary = {}, environment_override: Dictionary = {}) -> Dictionary:
	var event_definition := library.event(event_id)
	if event_definition.is_empty():
		return {}
	var event_module := EventModule.new()
	event_module.setup(event_definition, library)
	var event_environment := environment_override if not environment_override.is_empty() else run_state.current_environment
	if not event_module.can_trigger(run_state, event_environment, context):
		return {}
	var choices: Array = event_module.choices(run_state, event_environment)
	if choices.is_empty():
		return {}
	var payload: Dictionary = event_definition.get("payload", {})
	var option_choices: Array = []
	for choice in choices:
		if typeof(choice) != TYPE_DICTIONARY:
			continue
		var choice_data := (choice as Dictionary).duplicate(true)
		var choice_id := str(choice_data.get("id", ""))
		if choice_id.is_empty():
			continue
		option_choices.append({
			"id": choice_id,
			"label": str(choice_data.get("label", choice_id)),
			"text": str(choice_data.get("text", "")),
			"consequence_summary": _event_choice_consequence_summary(choice_data),
			"identity_summary": "Choice ID: %s" % choice_id,
			"impact_summary": _event_choice_consequence_summary(choice_data),
			"selected": event_id == selected_event_id and choice_id == selected_event_choice_id,
		})
	return {
		"id": event_id,
		"display_name": event_module.get_display_name(),
		"type": event_module.get_event_type(),
		"interaction_mode": event_module.get_interaction_mode(),
		"summary": str(payload.get("summary", "")),
		"asset_path": str(event_definition.get("asset_path", "")),
		"visual_key": str(event_definition.get("visual_key", event_definition.get("type", "event"))),
		"icon_key": str(event_definition.get("icon_key", event_id)),
		"environment_prop": str(event_definition.get("environment_prop", event_definition.get("prop", ""))),
		"start_summary": str(event_definition.get("start_summary", "Choose a response.")),
		"choices": option_choices,
	}


func _event_choice(event_option: Dictionary, choice_id: String) -> Dictionary:
	for choice in event_option.get("choices", []):
		if typeof(choice) == TYPE_DICTIONARY and str((choice as Dictionary).get("id", "")) == choice_id:
			return (choice as Dictionary).duplicate(true)
	return {}


func _position_event_choice_popup() -> void:
	if event_choice_popup_overlay == null or event_choice_popup_panel == null:
		return
	var overlay_rect := event_choice_popup_overlay.get_global_rect()
	if overlay_rect.size.x <= 0.0 or overlay_rect.size.y <= 0.0:
		return
	var margin := 12.0
	var width := clampf(overlay_rect.size.x * 0.54, 460.0, 640.0)
	var height := clampf(overlay_rect.size.y * 0.56, 320.0, 500.0)
	if overlay_rect.size.x < 560.0:
		width = clampf(overlay_rect.size.x - margin * 2.0, 300.0, 460.0)
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
	var parts: Array = []
	for choice in choices:
		if typeof(choice) != TYPE_DICTIONARY:
			continue
		var choice_data := choice as Dictionary
		var label := str(choice_data.get("label", choice_data.get("id", ""))).strip_edges()
		if label.is_empty():
			continue
		var impact := str(choice_data.get("consequence_summary", "")).strip_edges()
		if impact.is_empty():
			impact = "No immediate cost"
		parts.append("%s -> %s" % [label, impact])
		if parts.size() >= 3:
			break
	if parts.is_empty():
		return ""
	return "Choices / impact: %s" % "; ".join(parts)


func _event_choice_consequence_summary(choice_data: Dictionary) -> String:
	var consequences: Dictionary = choice_data.get("consequences", {}) if typeof(choice_data.get("consequences", {})) == TYPE_DICTIONARY else {}
	var parts: Array = []
	var bankroll_delta := int(consequences.get("bankroll_delta", 0))
	if bankroll_delta != 0:
		parts.append("Bankroll %s" % _signed_int_text(bankroll_delta))
	var suspicion_delta := int(consequences.get("suspicion_delta", 0))
	if suspicion_delta != 0:
		parts.append("Heat %s" % _signed_int_text(suspicion_delta))
	if consequences.has("debt") or not _copy_array(consequences.get("debt_changes", [])).is_empty():
		parts.append("Debt changes")
	var flags_value: Variant = consequences.get("flags", consequences.get("flags_set", {}))
	if typeof(flags_value) == TYPE_DICTIONARY and not (flags_value as Dictionary).is_empty():
		parts.append("Story flag")
	if not _string_array(consequences.get("set_next_archetypes", [])).is_empty() or not _string_array(consequences.get("add_next_archetypes", [])).is_empty() or not _copy_array(consequences.get("travel_hooks_add", [])).is_empty():
		parts.append("Routes change")
	var travel_changes: Variant = consequences.get("travel_changes", {})
	if typeof(travel_changes) == TYPE_DICTIONARY and not (travel_changes as Dictionary).is_empty():
		parts.append("Routes change")
	if not _copy_array(consequences.get("inventory_add", [])).is_empty() or not _copy_array(consequences.get("inventory_remove", [])).is_empty():
		parts.append("Inventory changes")
	if parts.is_empty():
		parts.append("Event closes" if bool(consequences.get("resolve_event", false)) else "No immediate cost")
	return "; ".join(parts)


func _signed_int_text(value: int) -> String:
	return "+%d" % value if value > 0 else str(value)


func _open_run_inventory_popup(mode: String = "inspect") -> void:
	if run_inventory_overlay == null or run_inventory_list == null:
		return
	run_inventory_popup_mode = mode
	_render_run_inventory_popup_contents()
	run_inventory_overlay.visible = true
	run_inventory_overlay.move_to_front()
	_position_run_inventory_popup()
	call_deferred("_position_run_inventory_popup")


func _render_run_inventory_popup_contents() -> void:
	if run_inventory_list == null:
		return
	_clear(run_inventory_list)
	var merchant_mode := run_inventory_popup_mode == "merchant_sale"
	if run_inventory_title_label != null:
		if merchant_mode:
			run_inventory_title_label.text = "Sell Items"
		else:
			run_inventory_title_label.text = "Inventory"
	if run_inventory_summary_label != null:
		run_inventory_summary_label.text = _run_inventory_summary_text(run_inventory_popup_mode)
	var items := _inventory_item_view_list()
	if items.is_empty():
		run_inventory_list.add_child(_muted_label("No run items yet.", 13))
		return
	for item in items:
		if typeof(item) == TYPE_DICTIONARY:
			_add_inventory_item_card(item as Dictionary, merchant_mode)


func _add_inventory_item_card(item: Dictionary, merchant_mode: bool = false) -> void:
	if run_inventory_list == null:
		return
	var sellable := bool(item.get("sellable", false))
	var border := VisualStyle.TEAL if sellable else VisualStyle.CYAN_2
	var card := _panel_container(VisualStyle.DARK_2, border)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	run_inventory_list.add_child(card)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 5)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(stack)
	var title := _label(str(item.get("display_name", item.get("id", "Item"))), 15)
	_set_control_font_color(title, border)
	stack.add_child(title)
	stack.add_child(_label("Type: %s / %s" % [str(item.get("item_class", "unknown")).capitalize(), str(item.get("domain", "global")).capitalize()], 12))
	stack.add_child(_label("Sale price: %d" % int(item.get("sale_price", 0)), 12))
	var description := str(item.get("description", ""))
	if not description.is_empty():
		stack.add_child(_label(description, 12))
	var effect_summary := str(item.get("effect_summary", ""))
	if not effect_summary.is_empty():
		stack.add_child(_muted_label("Effect: %s" % effect_summary, 12))
	if merchant_mode:
		if bool(item.get("repairable", false)):
			_add_card_button(stack, "Repair for %d" % int(item.get("repair_cost", 0)), Callable(self, "repair_inventory_item").bind(str(item.get("id", ""))), false, true)
		if sellable:
			_add_card_button(stack, "Sell for %d" % int(item.get("sale_price", 0)), Callable(self, "sell_inventory_item").bind(str(item.get("id", ""))), false, true)
		elif not bool(item.get("repairable", false)):
			stack.add_child(_muted_label("This item cannot be sold.", 12))
	else:
		if bool(item.get("active_item", false)):
			var selected := bool(item.get("active_selected", false))
			_add_card_button(stack, "Active Item" if selected else "Set Active", Callable(self, "select_active_inventory_item").bind(str(item.get("id", ""))), selected, selected)
		if bool(item.get("repairable", false)):
			stack.add_child(_muted_label("Repairable with a shopkeeper.", 12))
		if sellable:
			stack.add_child(_muted_label("Sellable with a merchant.", 12))
		elif not bool(item.get("repairable", false)):
			stack.add_child(_muted_label("Not sellable.", 12))


func _position_run_inventory_popup() -> void:
	if run_inventory_overlay == null or run_inventory_panel == null:
		return
	var overlay_rect := run_inventory_overlay.get_global_rect()
	if overlay_rect.size.x <= 0.0 or overlay_rect.size.y <= 0.0:
		return
	var margin := 12.0
	var width := clampf(overlay_rect.size.x * 0.54, 460.0, 640.0)
	var height := clampf(overlay_rect.size.y * 0.56, 320.0, 500.0)
	if overlay_rect.size.x < 560.0:
		width = clampf(overlay_rect.size.x - margin * 2.0, 300.0, 460.0)
	if overlay_rect.size.y < 420.0:
		height = clampf(overlay_rect.size.y - margin * 2.0, 260.0, 380.0)
	var popup_size := Vector2(width, height)
	var global_position := Vector2(
		overlay_rect.position.x + (overlay_rect.size.x - popup_size.x) * 0.5,
		overlay_rect.position.y + (overlay_rect.size.y - popup_size.y) * 0.5
	)
	global_position.x = clampf(global_position.x, overlay_rect.position.x + margin, overlay_rect.position.x + overlay_rect.size.x - popup_size.x - margin)
	global_position.y = clampf(global_position.y, overlay_rect.position.y + margin, overlay_rect.position.y + overlay_rect.size.y - popup_size.y - margin)
	run_inventory_panel.position = global_position - overlay_rect.position
	run_inventory_panel.size = popup_size


func _hide_run_inventory_popup() -> void:
	if run_inventory_overlay != null:
		run_inventory_overlay.visible = false
	if run_inventory_list != null:
		_clear(run_inventory_list)
	if run_inventory_panel != null:
		run_inventory_panel.position = Vector2.ZERO
		run_inventory_panel.size = run_inventory_panel.custom_minimum_size
	run_inventory_popup_mode = ""


func _run_inventory_popup_is_visible() -> bool:
	return run_inventory_overlay != null and run_inventory_overlay.visible


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
	var result: Array = []
	if run_state == null:
		return result
	var entry_index := 1
	for entry_value in run_state.story_log:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry_data := entry_value as Dictionary
		var view := _run_journal_entry_view(entry_data, entry_index)
		if view.is_empty():
			continue
		result.append(view)
		entry_index += 1
	if run_state.is_terminal() and not _run_journal_has_terminal_entry(result):
		var terminal_entry := _run_journal_terminal_entry(entry_index)
		if not terminal_entry.is_empty():
			result.append(terminal_entry)
	return result


func _run_journal_entry_view(entry: Dictionary, entry_index: int) -> Dictionary:
	var category := _run_journal_category_for_entry(entry)
	var title := _run_journal_title_for_entry(entry, category)
	var body := _story_entry_label(entry)
	if body.strip_edges().is_empty():
		body = title
	var detail_lines := _run_journal_detail_lines(entry)
	return {
		"index": entry_index,
		"type": str(entry.get("type", "story")),
		"category": category,
		"title": title,
		"body": _player_facing_text(body),
		"detail_lines": detail_lines,
		"terminal": _run_journal_story_entry_is_terminal(entry),
	}


func _run_journal_category_for_entry(entry: Dictionary) -> String:
	var entry_type := str(entry.get("type", "story"))
	var heat_delta := int(entry.get("suspicion_delta", entry.get("heat_delta", 0)))
	if entry_type == "grand_casino_high_roller_ready":
		return "objective"
	if entry_type == "grand_casino_heat_reroute" or entry_type == "demo_finale_triggered":
		return "boss"
	if entry_type == "grand_casino_showdown_arrival":
		return "showdown"
	if entry_type == "demo_victory" or entry_type == "demo_finale_result" or entry_type == "run_abandoned":
		return "terminal"
	if heat_delta > 0 or entry_type.find("heat") != -1:
		return "heat"
	if entry_type == "travel":
		return "travel"
	if entry_type.begins_with("item_") or not _copy_array(entry.get("inventory_add", [])).is_empty() or not _copy_array(entry.get("inventory_remove", [])).is_empty():
		return "item"
	if entry_type.find("debt") != -1 or entry_type.find("lender") != -1 or not _copy_array(entry.get("debt_changes", [])).is_empty():
		return "debt"
	if entry_type == "event" or not str(entry.get("event_id", "")).is_empty():
		return "event"
	if entry_type == "game_action" or not str(entry.get("game_id", "")).is_empty():
		return "game"
	return "story"


func _run_journal_title_for_entry(entry: Dictionary, category: String) -> String:
	var entry_type := str(entry.get("type", "story"))
	if category == "heat":
		return "Heat Spike"
	match entry_type:
		"grand_casino_high_roller_ready":
			return "High-Roller Review"
		"grand_casino_heat_reroute":
			return "Rourke's Attention"
		"grand_casino_showdown_arrival":
			return "Back Room"
		"demo_finale_triggered":
			return "The House Calls"
		"demo_finale_result":
			return "Showdown Outcome" if str(entry.get("event_id", "")) == RunState.GRAND_CASINO_SHOWDOWN_EVENT_ID else "Terminal Result"
		"demo_victory":
			return "Demo Victory"
		"run_abandoned":
			return "Run Abandoned"
		"travel":
			return "Travel"
		"item_purchase":
			return "Item Bought"
		"item_sale":
			return "Item Sold"
		"item_use", "active_item":
			return "Item Used"
		"event":
			return "Event"
		"game_action":
			var bankroll_delta := int(entry.get("bankroll_delta", 0))
			if bankroll_delta > 0:
				return "Notable Win"
			if bankroll_delta < 0:
				return "Notable Loss"
			return "Game Result"
		_:
			if category == "debt":
				return "Debt"
			if category == "boss":
				return "Boss Floor Attention"
			return _label_from_id(entry_type)


func _run_journal_detail_lines(entry: Dictionary) -> Array:
	var lines: Array = []
	var venue := _run_journal_environment_label(entry)
	if not venue.is_empty():
		lines.append("Venue: %s" % venue)
	var bankroll_delta := int(entry.get("bankroll_delta", 0))
	if bankroll_delta != 0:
		lines.append("Bankroll %+d" % bankroll_delta)
	var heat_delta := int(entry.get("suspicion_delta", entry.get("heat_delta", 0)))
	if heat_delta != 0:
		lines.append("Heat %+d" % heat_delta)
	elif entry.has("heat"):
		lines.append("Heat %d" % int(entry.get("heat", 0)))
	var branch := str(entry.get("branch", entry.get("finale_branch", ""))).strip_edges()
	if not branch.is_empty():
		lines.append("Branch: %s" % _label_from_id(branch))
	var event_id := str(entry.get("event_id", "")).strip_edges()
	if not event_id.is_empty():
		lines.append("Event: %s" % _label_from_id(event_id))
	var item_id := str(entry.get("item_name", entry.get("item_id", ""))).strip_edges()
	if not item_id.is_empty():
		lines.append("Item: %s" % _label_from_id(item_id))
	var game_id := str(entry.get("game_id", "")).strip_edges()
	if not game_id.is_empty():
		lines.append("Game: %s" % _game_display_name(game_id))
	var attention_sources := _copy_array(entry.get("attention_sources", []))
	if not attention_sources.is_empty():
		lines.append("Attention: %s" % _run_journal_label_list(attention_sources))
	var debt_changes := _copy_array(entry.get("debt_changes", []))
	if not debt_changes.is_empty():
		lines.append("Debt changed")
	var inventory_add := _copy_array(entry.get("inventory_add", []))
	if not inventory_add.is_empty():
		lines.append("Gained: %s" % _run_journal_label_list(inventory_add))
	var inventory_remove := _copy_array(entry.get("inventory_remove", []))
	if not inventory_remove.is_empty():
		lines.append("Used: %s" % _run_journal_label_list(inventory_remove))
	return lines


func _run_journal_environment_label(entry: Dictionary) -> String:
	var display_name := str(entry.get("environment_name", entry.get("to_environment_name", ""))).strip_edges()
	if not display_name.is_empty():
		return display_name
	var environment_id := str(entry.get("environment_id", entry.get("to_environment_id", ""))).strip_edges()
	if not environment_id.is_empty():
		return _label_from_id(environment_id)
	var archetype_id := str(entry.get("environment_archetype_id", entry.get("to_archetype_id", ""))).strip_edges()
	if not archetype_id.is_empty():
		return _label_from_id(archetype_id)
	return ""


func _run_journal_label_list(values: Array) -> String:
	var labels: Array = []
	for value in values:
		labels.append(_label_from_id(str(value)))
	return ", ".join(labels)


func _run_journal_has_terminal_entry(entries: Array) -> bool:
	for entry_value in entries:
		if typeof(entry_value) == TYPE_DICTIONARY and bool((entry_value as Dictionary).get("terminal", false)):
			return true
	return false


func _run_journal_story_entry_is_terminal(entry: Dictionary) -> bool:
	var entry_type := str(entry.get("type", ""))
	return bool(entry.get("ended", false)) or entry_type == "demo_victory" or entry_type == "demo_finale_result" or entry_type == "run_abandoned"


func _run_journal_terminal_entry(entry_index: int) -> Dictionary:
	if run_state == null or not run_state.is_terminal():
		return {}
	var title := "Run Ended"
	var body := "This run is over."
	if run_state.run_status == RunState.RUN_STATUS_ENDED:
		title = "Demo Victory" if bool(run_state.narrative_flags.get("demo_victory", false)) else "Run Ended"
		body = run_state.current_demo_victory_message() if bool(run_state.narrative_flags.get("demo_victory", false)) else "This run is over."
	elif run_state.run_status == RunState.RUN_STATUS_FAILED:
		var failure := _failure_summary_snapshot()
		title = str(failure.get("title", "Run Failed"))
		body = str(failure.get("message", run_state.run_failure_message))
	return {
		"index": entry_index,
		"type": "terminal_result",
		"category": "terminal",
		"title": title,
		"body": _player_facing_text(body),
		"detail_lines": [
			"Final bankroll %d" % run_state.bankroll,
			"Heat %d" % run_state.suspicion_level(),
		],
		"terminal": true,
	}


func _run_journal_summary_text(entries: Array) -> String:
	if entries.is_empty():
		return "Read-only record. Story beats appear here as the run develops."
	return "Read-only record: %d beat%s, oldest first." % [entries.size(), "" if entries.size() == 1 else "s"]


func _run_journal_category_color(category: String) -> Color:
	match category:
		"travel":
			return VisualStyle.TEAL
		"item":
			return VisualStyle.AMBER
		"debt", "heat":
			return VisualStyle.PINK_2
		"boss", "showdown", "terminal":
			return VisualStyle.YELLOW
		"objective":
			return VisualStyle.CYAN
		"event":
			return VisualStyle.ORANGE
		"game":
			return VisualStyle.CYAN_2
		_:
			return VisualStyle.SOFT


func _inventory_item_view_list() -> Array:
	_refresh_run_action_service()
	return run_action_service.inventory_item_view_list()


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


func _run_inventory_summary_text(mode: String) -> String:
	if mode == "merchant_sale":
		return "Sellable run items can be sold here."
	var count := _inventory_item_view_list().size()
	return "Current run items: %d. Sell items through a merchant." % count


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


func _prestige_purchase_view_list() -> Array:
	_refresh_run_action_service()
	return run_action_service.prestige_purchase_view_list(selected_prestige_purchase_id)


func _prestige_purchase_option(purchase_id: String) -> Dictionary:
	_refresh_run_action_service()
	return run_action_service.prestige_purchase_option(purchase_id, selected_prestige_purchase_id)


func _hook_cost_effect_summary(option: Dictionary) -> String:
	var parts: Array = []
	if option.has("cost"):
		parts.append("Cost: %d" % int(option.get("cost", 0)))
	var delta_summary := str(option.get("delta_summary", ""))
	if not delta_summary.is_empty():
		parts.append("Effect: %s" % delta_summary)
	return " | ".join(parts)


func _clear_selected_service_hook() -> void:
	selected_service_hook_id = ""
	selected_service_hook_label = ""


func _clear_selected_lender_hook() -> void:
	selected_lender_hook_id = ""
	selected_lender_hook_label = ""


func _clear_selected_prestige_purchase() -> void:
	selected_prestige_purchase_id = ""
	selected_prestige_purchase_label = ""


func _refresh_world_map_overlay() -> void:
	if world_map_overlay == null or not world_map_overlay.visible:
		return
	var snapshot := _world_map_snapshot()
	if world_map_nodes_layer != null and world_map_nodes_layer.has_method("set_map_snapshot"):
		world_map_nodes_layer.call("set_map_snapshot", snapshot)
		_sync_world_map_node_buttons(snapshot)
	var current_label := str(run_state.current_environment.get("display_name", "Current room")) if run_state != null else "Current room"
	if world_map_title_label != null:
		world_map_title_label.text = "%s / World Map" % current_label
	_refresh_world_map_detail()


func _on_world_map_canvas_layout_changed() -> void:
	if world_map_overlay == null or not world_map_overlay.visible:
		return
	_request_world_map_button_relayout()


func _request_world_map_button_relayout() -> void:
	world_map_button_layout_size = Vector2(-1.0, -1.0)
	if world_map_button_relayout_deferred:
		return
	world_map_button_relayout_deferred = true
	call_deferred("_refresh_world_map_overlay_after_layout")


func _refresh_world_map_overlay_after_layout() -> void:
	world_map_button_relayout_deferred = false
	if world_map_overlay == null or not world_map_overlay.visible:
		return
	world_map_button_layout_size = Vector2(-1.0, -1.0)
	_refresh_world_map_overlay()


func _clear_world_map_node_buttons() -> void:
	if world_map_nodes_layer == null:
		return
	for child in world_map_nodes_layer.get_children():
		if child is Button:
			world_map_nodes_layer.remove_child(child)
			child.queue_free()
	world_map_button_ids = []
	world_map_button_layout_size = Vector2(-1.0, -1.0)


func _sync_world_map_node_buttons(snapshot: Dictionary) -> void:
	if world_map_nodes_layer == null:
		return
	var node_ids := _world_map_node_ids(snapshot)
	var layer_size := _world_map_layer_size()
	if node_ids != world_map_button_ids or layer_size != world_map_button_layout_size:
		_clear_world_map_node_buttons()
		_add_world_map_node_buttons(snapshot)
		world_map_button_ids = node_ids.duplicate()
		world_map_button_layout_size = layer_size
	else:
		_position_world_map_node_buttons(snapshot)


func _world_map_node_ids(snapshot: Dictionary) -> Array:
	var ids: Array = []
	for node_value in _copy_array(snapshot.get("nodes", [])):
		if typeof(node_value) != TYPE_DICTIONARY:
			continue
		var node: Dictionary = node_value
		var node_id := str(node.get("id", ""))
		if not node_id.is_empty():
			ids.append(node_id)
	return ids


func _world_map_layer_size() -> Vector2:
	if world_map_nodes_layer == null:
		return Vector2(540, 390)
	var layer_size := world_map_nodes_layer.size
	if layer_size.x <= 0.0 or layer_size.y <= 0.0:
		return Vector2(540, 390)
	return layer_size


func _add_world_map_node_buttons(snapshot: Dictionary) -> void:
	if world_map_nodes_layer == null:
		return
	for node_value in _copy_array(snapshot.get("nodes", [])):
		if typeof(node_value) != TYPE_DICTIONARY:
			continue
		var node: Dictionary = node_value
		var node_id := str(node.get("id", ""))
		if node_id.is_empty():
			continue
		var button := _world_map_hit_button(Callable(self, "select_world_map_node").bind(node_id))
		button.custom_minimum_size = Vector2(46, 46)
		button.size = Vector2(46, 46)
		button.position = _world_map_node_button_position(node_id, node) - button.size * 0.5
		button.tooltip_text = str(node.get("label", node_id))
		button.name = "WorldMapNode_%s" % node_id
		world_map_nodes_layer.add_child(button)


func _position_world_map_node_buttons(snapshot: Dictionary) -> void:
	if world_map_nodes_layer == null:
		return
	for node_value in _copy_array(snapshot.get("nodes", [])):
		if typeof(node_value) != TYPE_DICTIONARY:
			continue
		var node: Dictionary = node_value
		var node_id := str(node.get("id", ""))
		if node_id.is_empty():
			continue
		var button := world_map_nodes_layer.get_node_or_null("WorldMapNode_%s" % node_id) as Button
		if button == null:
			continue
		button.position = _world_map_node_button_position(node_id, node) - button.size * 0.5
		button.tooltip_text = str(node.get("label", node_id))


func _world_map_node_button_position(node_id: String, node: Dictionary) -> Vector2:
	var layer_size := _world_map_layer_size()
	var inset := Vector2(32.0, 28.0)
	var drawable := Vector2(maxf(1.0, layer_size.x - inset.x * 2.0), maxf(1.0, layer_size.y - inset.y * 2.0))
	var position: Dictionary = node.get("position", {}) if typeof(node.get("position", {})) == TYPE_DICTIONARY else {}
	var center := inset + Vector2(clampf(float(position.get("x", 0.5)), 0.0, 1.0), clampf(float(position.get("y", 0.5)), 0.0, 1.0)) * drawable
	if world_map_nodes_layer != null and world_map_nodes_layer.size.x > 0.0 and world_map_nodes_layer.size.y > 0.0 and world_map_nodes_layer.has_method("local_position_for_node"):
		center = world_map_nodes_layer.call("local_position_for_node", node_id) as Vector2
	return center


func _refresh_world_map_detail() -> void:
	if world_map_detail_label == null or run_state == null:
		return
	var lock_remaining := run_state.current_travel_lock_remaining()
	var lines: Array = []
	if lock_remaining > 0:
		lines.append(str(run_state.travel_route_status({}).get("disabled_reason", "Travel is locked for now.")))
	if selected_world_map_node_id.is_empty():
		lines.append("Select a revealed stop.")
		_set_world_map_confirm_enabled(false)
		world_map_detail_label.text = "\n".join(lines)
		return
	var current_id := run_state.current_world_node_id()
	var node: Dictionary = WorldMapScript.node_by_id(run_state.world_map, selected_world_map_node_id)
	if node.is_empty() or not WorldMapScript.is_node_visible(run_state.world_map, selected_world_map_node_id):
		lines.append("That stop is not visible from here.")
		_set_world_map_confirm_enabled(false)
		world_map_detail_label.text = "\n".join(lines)
		return
	var choice := _travel_choice(selected_world_map_node_id)
	lines.append(str(node.get("label", selected_world_map_node_id)))
	var flavor := _world_map_node_flavor(node)
	if not flavor.is_empty():
		lines.append(flavor)
	if selected_world_map_node_id == current_id:
		lines.append("You are here.")
		_set_world_map_confirm_enabled(false)
		world_map_detail_label.text = "\n".join(lines)
		return
	if choice.is_empty():
		var path := WorldMapScript.path_between(run_state.world_map, current_id, selected_world_map_node_id, true)
		if path.size() >= 2:
			lines.append("Not on the route list from here right now.")
		else:
			lines.append("No known path from here.")
		_set_world_map_confirm_enabled(false)
		world_map_detail_label.text = "\n".join(lines)
		return
	lines.append("Travel: %s." % _world_map_travel_method(choice))
	var distance_blocks := int(choice.get("distance_blocks", 0))
	var distance_text := str(choice.get("distance", "near")).capitalize()
	if distance_blocks > 0:
		distance_text = "%s, %d block(s)" % [distance_text, distance_blocks]
	lines.append("Distance: %s." % distance_text)
	lines.append("Cost: %d." % int(choice.get("cost", 0)))
	var risk := _travel_risk_summary(choice)
	if not risk.is_empty():
		lines.append("Risk: %s" % risk)
	var unlock_summary := str(choice.get("unlock_summary", "")).strip_edges()
	if not bool(choice.get("enabled", true)) and not unlock_summary.is_empty():
		lines.append("Lock: %s" % unlock_summary)
	elif bool(choice.get("enabled", true)):
		lines.append("Route open.")
	for preview_line in _copy_array(choice.get("preview_lines", [])).slice(0, 3):
		var preview_text := str(preview_line).strip_edges()
		if not preview_text.is_empty():
			lines.append(preview_text)
	if not bool(choice.get("enabled", true)):
		lines.append(str(choice.get("disabled_reason", "That route is not available right now.")))
	_set_world_map_confirm_enabled(bool(choice.get("enabled", true)))
	world_map_detail_label.text = "\n".join(lines)


func _world_map_hit_button(callback: Callable) -> Button:
	var button := Button.new()
	button.text = ""
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var empty := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty)
	button.add_theme_stylebox_override("hover", empty)
	button.add_theme_stylebox_override("pressed", empty)
	button.add_theme_stylebox_override("disabled", empty)
	button.pressed.connect(callback)
	return button


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
	var route: Dictionary = choice.get("route", {}) if typeof(choice.get("route", {})) == TYPE_DICTIONARY else {}
	var travel_method := str(route.get("travel_method", choice.get("travel_method", ""))).strip_edges()
	if not travel_method.is_empty():
		return travel_method
	var method := str(route.get("method", "")).strip_edges()
	if not method.is_empty():
		return method
	match str(choice.get("distance", "near")).strip_edges().to_lower():
		"near":
			return "Walk"
		"local":
			return "Bus ticket"
		"far":
			return "Taxi ride"
		_:
			return "Night cab"


func _set_world_map_confirm_enabled(enabled: bool) -> void:
	if world_map_confirm_button == null:
		return
	world_map_confirm_button.disabled = not enabled


func _world_map_snapshot() -> Dictionary:
	if run_state == null:
		return {}
	var cache_key := "%s|map:%s" % [_travel_base_cache_key(), selected_world_map_node_id]
	if world_map_snapshot_cache_key == cache_key:
		return world_map_snapshot_cache.duplicate(true)
	var snapshot := {}
	if generator != null:
		snapshot = generator.world_map_snapshot(run_state, selected_world_map_node_id)
	else:
		snapshot = WorldMapScript.snapshot(run_state.world_map, selected_world_map_node_id)
	var enriched := _enriched_world_map_snapshot(snapshot)
	world_map_snapshot_cache_key = cache_key
	world_map_snapshot_cache = enriched.duplicate(true)
	return enriched


func _enriched_world_map_snapshot(snapshot: Dictionary) -> Dictionary:
	if run_state == null or not run_state.has_world_map():
		return snapshot
	var enriched := snapshot.duplicate(true)
	var current_id := run_state.current_world_node_id()
	var target_ids := _travel_target_ids()
	var travel_enabled_ids: Array = []
	var travel_disabled_ids: Array = []
	var travel_paths: Array = []
	var nodes: Array = []
	for node_value in _copy_array(enriched.get("nodes", [])):
		if typeof(node_value) != TYPE_DICTIONARY:
			continue
		var node: Dictionary = (node_value as Dictionary).duplicate(true)
		var node_id := str(node.get("id", "")).strip_edges()
		var is_current := node_id == current_id
		var is_target := target_ids.has(node_id)
		var route := _world_route_for_target(node_id) if is_target and not is_current else {}
		var status := run_state.travel_route_status(route) if not route.is_empty() else {}
		var route_hidden := bool(status.get("hidden", false))
		var enabled := is_target and not is_current and not route.is_empty() and not route_hidden and bool(status.get("available", true))
		node["current"] = is_current
		node["travel_target"] = is_target and not is_current and not route_hidden
		node["travel_enabled"] = enabled
		node["travel_disabled_reason"] = ""
		if bool(node.get("travel_target", false)):
			node["travel_method"] = _world_map_travel_method({"route": route, "distance": str(status.get("distance", route.get("distance", "near")))})
			node["distance"] = str(status.get("distance", route.get("distance", "")))
			node["distance_blocks"] = int(route.get("distance_blocks", 0))
			node["cost"] = int(status.get("cost", route.get("cost", 0)))
			node["risk_decay"] = int(status.get("risk_decay", route.get("risk_decay", 0)))
			if enabled:
				travel_enabled_ids.append(node_id)
			else:
				var disabled_reason := str(status.get("disabled_reason", "That route is not available right now."))
				node["travel_disabled_reason"] = disabled_reason
				travel_disabled_ids.append(node_id)
			var route_path := _string_array(route.get("world_path", []))
			if route_path.size() >= 2:
				travel_paths.append({
					"target_id": node_id,
					"path": route_path,
					"enabled": enabled,
				})
		elif not is_current:
			node["travel_disabled_reason"] = "Not on the route list from here right now."
		nodes.append(node)
	enriched["nodes"] = nodes
	enriched["travel_target_ids"] = target_ids
	enriched["travel_enabled_node_ids"] = travel_enabled_ids
	enriched["travel_disabled_node_ids"] = travel_disabled_ids
	enriched["travel_paths"] = travel_paths
	if str(enriched.get("background_path", "")).strip_edges().is_empty():
		enriched["background_path"] = WorldMapScript.MAP_BACKGROUND_PATH
	return enriched


func _world_route_for_target(target_id: String) -> Dictionary:
	var cache_key := _travel_base_cache_key()
	if world_route_cache_key != cache_key:
		world_route_cache_key = cache_key
		world_route_cache = {}
	if world_route_cache.has(target_id):
		var cached_route: Dictionary = world_route_cache.get(target_id, {})
		return cached_route.duplicate(true)
	var route := {}
	if run_state != null and generator != null and run_state.has_world_map():
		route = generator.world_route_for_target(run_state, target_id)
	else:
		route = library.route(target_id) if library != null else {}
	world_route_cache[target_id] = route.duplicate(true)
	return route


func _travel_choice_view_list() -> Array:
	if run_state == null:
		return []
	var cache_key := "%s|selected:%s" % [_travel_base_cache_key(), selected_travel_target_id]
	if travel_choice_cache_key == cache_key:
		return travel_choice_cache.duplicate(true)
	var ids := _travel_target_ids()
	var choices: Array = []
	for target_id in ids:
		var choice := _travel_choice(target_id, ids)
		if choice.is_empty():
			continue
		choice["selected"] = target_id == selected_travel_target_id
		choices.append(choice)
	travel_choice_cache_key = cache_key
	travel_choice_cache = choices.duplicate(true)
	return choices


func _travel_choice(target_id: String, known_target_ids: Array = []) -> Dictionary:
	var target_ids := known_target_ids if not known_target_ids.is_empty() else _travel_target_ids()
	if target_id.is_empty() or not target_ids.has(target_id):
		return {}
	var route := _world_route_for_target(target_id)
	var archetype := _environment_archetype(target_id)
	var label := str(route.get("label", archetype.get("display_name", "")))
	if label.is_empty():
		label = _travel_label_from_archetype(archetype, target_id)
	var choice := {
		"id": target_id,
		"label": label,
		"kind": str(archetype.get("kind", "")),
		"tier": int(archetype.get("tier", 1)),
		"description": str(route.get("description", "")),
		"route": route.duplicate(true),
	}
	if route.has("cost"):
		choice["cost"] = int(route.get("cost", 0))
	if route.has("risk"):
		choice["risk"] = str(route.get("risk", ""))
	if route.has("suspicion_delta"):
		choice["suspicion_delta"] = int(route.get("suspicion_delta", 0))
	if route.has("distance"):
		choice["distance"] = str(route.get("distance", ""))
	if route.has("distance_blocks"):
		choice["distance_blocks"] = int(route.get("distance_blocks", 0))
	if route.has("world_edge_id"):
		choice["world_edge_id"] = str(route.get("world_edge_id", ""))
	if route.has("risk_decay"):
		choice["risk_decay"] = int(route.get("risk_decay", 0))
	if route.has("condition_text"):
		choice["condition_text"] = str(route.get("condition_text", ""))
	var status := run_state.travel_route_status(route)
	if bool(status.get("hidden", false)):
		return {}
	choice["distance"] = str(status.get("distance", choice.get("distance", "")))
	choice["risk_decay"] = int(status.get("risk_decay", choice.get("risk_decay", 0)))
	choice["risk_text"] = str(status.get("risk_text", ""))
	choice["risk_event"] = _copy_dict(status.get("risk_event", {}))
	choice["unlock_conditions"] = _copy_array(status.get("unlock_conditions", []))
	choice["unlock_summary"] = str(status.get("unlock_summary", ""))
	if status.has("availability_turn"):
		choice["availability_turn"] = int(status.get("availability_turn", 0))
	if status.has("travel_lock_remaining"):
		choice["travel_lock_remaining"] = int(status.get("travel_lock_remaining", 0))
	var full_preview := _travel_full_preview_enabled_for(target_id)
	var preview_environment := {}
	if full_preview and generator != null:
		preview_environment = generator.preview_environment(run_state, target_id)
	var preview := run_state.travel_route_preview(route, archetype, preview_environment, full_preview)
	choice["preview"] = preview
	choice["preview_level"] = str(preview.get("level", "partial"))
	choice["preview_lines"] = _copy_array(preview.get("lines", []))
	var enabled := bool(status.get("available", true))
	var disabled_reason := str(status.get("disabled_reason", ""))
	if not enabled and disabled_reason.strip_edges().is_empty():
		disabled_reason = str(choice.get("condition_text", ""))
	if not enabled and disabled_reason.strip_edges().is_empty():
		disabled_reason = "This route is locked for now."
	choice["enabled"] = enabled
	choice["disabled_reason"] = disabled_reason
	return choice


func _travel_target_ids() -> Array:
	if run_state == null:
		return []
	var cache_key := _travel_base_cache_key()
	if travel_target_ids_cache_key == cache_key:
		return travel_target_ids_cache.duplicate()
	var result: Array = []
	if run_state.has_world_map():
		var source_id := run_state.current_world_node_id()
		result = WorldMapScript.travel_target_ids(run_state.world_map, source_id, WorldMapScript.TRAVEL_NEW_TARGET_LIMIT, WorldMapScript.TRAVEL_TOTAL_TARGET_LIMIT, _enabled_world_route_ids(source_id))
	else:
		for source in [
			run_state.current_environment.get("next_archetypes", []),
			run_state.current_environment.get("travel_hooks", []),
		]:
			for target_id in _string_array(source):
				if not result.has(target_id):
					result.append(target_id)
	travel_target_ids_cache_key = cache_key
	travel_target_ids_cache = result.duplicate()
	return result


func _travel_base_cache_key() -> String:
	if run_state == null:
		return "no-run"
	var map_current_id := run_state.current_world_node_id() if run_state.has_world_map() else ""
	var map_visited_count := 0
	var map_node_count := 0
	if run_state.has_world_map():
		map_visited_count = _copy_array(run_state.world_map.get("visited_path", [])).size()
		map_node_count = _copy_array(run_state.world_map.get("nodes", [])).size()
	return "%s|%s|%s|%d|%d|%d|%d|%d|%d|%d|%d|%d|%s" % [
		current_screen,
		str(run_state.current_environment.get("id", "")),
		map_current_id,
		run_state.environment_travel_count(),
		map_visited_count,
		map_node_count,
		run_state.bankroll,
		run_state.suspicion_level(),
		run_state.current_travel_lock_remaining(),
		run_state.unlocked_travel.size(),
		run_state.narrative_flags.size(),
		run_state.inventory.size(),
		str(run_state.current_environment.get("travel_lock_remaining", "")),
	]


func _invalidate_travel_view_cache() -> void:
	travel_target_ids_cache_key = ""
	travel_target_ids_cache = []
	travel_choice_cache_key = ""
	travel_choice_cache = []
	world_route_cache_key = ""
	world_route_cache = {}
	world_map_snapshot_cache_key = ""
	world_map_snapshot_cache = {}


func _enabled_world_route_ids(source_id: String) -> Array:
	var result: Array = []
	if run_state == null or not run_state.has_world_map():
		return result
	var clean_source_id := source_id.strip_edges()
	if clean_source_id.is_empty():
		clean_source_id = run_state.current_world_node_id()
	for target_id_value in WorldMapScript.visible_node_ids(run_state.world_map):
		var target_id := str(target_id_value)
		if target_id == clean_source_id or not WorldMapScript.has_path(run_state.world_map, clean_source_id, target_id, true):
			continue
		var route := _world_route_for_target(target_id)
		if route.is_empty():
			continue
		var status := run_state.travel_route_status(route)
		if not bool(status.get("hidden", false)) and bool(status.get("available", true)):
			result.append(target_id)
	return result


func _environment_archetype(archetype_id: String) -> Dictionary:
	if library == null:
		return {}
	for archetype in library.environment_archetypes:
		if typeof(archetype) == TYPE_DICTIONARY and str((archetype as Dictionary).get("id", "")) == archetype_id:
			return (archetype as Dictionary).duplicate(true)
	return {}


func _travel_label_from_archetype(archetype: Dictionary, fallback_id: String) -> String:
	var nouns: Array = archetype.get("name_nouns", [])
	if not nouns.is_empty():
		return str(nouns[0])
	return fallback_id.replace("_", " ").capitalize()


func _travel_full_preview_enabled() -> bool:
	if run_state == null:
		return false
	return run_state.travel_scouting_level() > 0


func _travel_full_preview_enabled_for(target_id: String) -> bool:
	if _travel_full_preview_enabled():
		return true
	if run_state == null or not run_state.has_world_map():
		return false
	var node: Dictionary = WorldMapScript.node_by_id(run_state.world_map, target_id)
	return bool(node.get("scouted", false))


func _travel_preview_summary(choice: Dictionary) -> String:
	var preview_lines := _copy_array(choice.get("preview_lines", []))
	if preview_lines.is_empty():
		return ""
	var level := str(choice.get("preview_level", "partial"))
	var prefix := "Scout" if level == "full" else "Preview"
	var first_line := str(preview_lines[0]).strip_edges()
	if first_line.begins_with("Preview:"):
		first_line = first_line.substr("Preview:".length()).strip_edges()
	return "%s: %s" % [prefix, first_line]


func _travel_risk_summary(choice: Dictionary) -> String:
	var parts: Array = []
	var risk := str(choice.get("risk", ""))
	if not risk.is_empty():
		parts.append(risk)
	var distance := str(choice.get("distance", ""))
	if not distance.is_empty():
		parts.append("%s distance" % distance)
	var risk_decay := int(choice.get("risk_decay", 0))
	if risk_decay >= 70:
		parts.append("heat cools sharply")
	elif risk_decay > 0:
		parts.append("heat cools")
	var suspicion_delta := int(choice.get("suspicion_delta", 0))
	if suspicion_delta > 0:
		parts.append("heat +%d" % suspicion_delta)
	var risk_text := str(choice.get("risk_text", "")).strip_edges()
	if not risk_text.is_empty():
		parts.append(risk_text)
	var risk_event := _copy_dict(choice.get("risk_event", {}))
	if not risk_event.is_empty():
		var chance := int(risk_event.get("chance_percent", 0))
		var event_bits: Array = []
		var bankroll_delta := int(risk_event.get("bankroll_delta", 0))
		var event_heat := int(risk_event.get("suspicion_delta", 0))
		if bankroll_delta != 0:
			event_bits.append("%+d cash" % bankroll_delta)
		if event_heat > 0:
			event_bits.append("heat +%d" % event_heat)
		var consequence := ", ".join(event_bits)
		if consequence.is_empty():
			consequence = str(risk_event.get("label", "route event"))
		parts.append("%d%% %s" % [chance, consequence])
	return ", ".join(parts)


func _clear_selected_travel() -> void:
	selected_travel_target_id = ""
	selected_travel_label = ""
	selected_world_map_node_id = ""


func _panel_container(fill: Color, border: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", VisualStyle.pixel_box(fill, border, 1))
	return panel


func _panel(fill: Color, border: Color) -> Panel:
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", VisualStyle.pixel_box(fill, border, 1))
	return panel


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


func _add_card_button(stack: VBoxContainer, text: String, callback: Callable, disabled: bool = false, primary: bool = false) -> Button:
	var button := _button(text, callback)
	button.disabled = disabled
	if primary:
		_style_selected_button(button)
	stack.add_child(button)
	return button


func _accessible_font_size(base_size: int) -> int:
	return maxi(8, int(round(float(base_size) * _accessibility_font_scale())))


func _set_control_font_size(control: Control, base_size: int) -> void:
	control.set_meta(ACCESSIBILITY_BASE_FONT_META, base_size)
	control.add_theme_font_size_override("font_size", _accessible_font_size(base_size))


func _set_control_font_color(control: Control, color: Color) -> void:
	control.set_meta(ACCESSIBILITY_BASE_COLOR_META, color)
	control.add_theme_color_override("font_color", VisualStyle.accessible_color(color))


func _accessibility_font_scale() -> float:
	if user_settings == null:
		return 1.0
	return clampf(user_settings.text_scale() * user_settings.ui_scale, 0.86, 1.35)


func _accessibility_control_scale() -> float:
	if user_settings == null:
		return 1.0
	return clampf(user_settings.ui_scale, 0.90, 1.18)


func _apply_accessibility_settings() -> void:
	if user_settings != null:
		VisualStyle.set_high_contrast_enabled(user_settings.high_contrast)
	_apply_accessibility_to_node(self, _accessibility_font_scale(), _accessibility_control_scale())


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
	if not _control_uses_text(control):
		return
	if not control.has_meta(ACCESSIBILITY_BASE_MIN_SIZE_META):
		control.set_meta(ACCESSIBILITY_BASE_MIN_SIZE_META, control.custom_minimum_size)
	var stored: Variant = control.get_meta(ACCESSIBILITY_BASE_MIN_SIZE_META)
	if typeof(stored) != TYPE_VECTOR2:
		return
	var base_size: Vector2 = stored
	if base_size == Vector2.ZERO:
		return
	control.custom_minimum_size = Vector2(base_size.x, base_size.y * control_scale)


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
	var label := Label.new()
	label.text = text
	_set_control_font_color(label, VisualStyle.SOFT)
	_set_control_font_size(label, size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _muted_label(text: String, size: int) -> Label:
	var label := _label(text, size)
	_set_control_font_color(label, VisualStyle.CYAN_2)
	return label


func _section(text: String) -> Label:
	var label := _label(text, 13)
	_set_control_font_color(label, VisualStyle.CYAN)
	return label


func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, MIN_NATIVE_TOUCH_TARGET_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_set_control_font_color(button, VisualStyle.WHITE)
	_set_control_font_size(button, DEFAULT_CONTROL_FONT_SIZE)
	button.add_theme_stylebox_override("normal", VisualStyle.pixel_box(VisualStyle.DARK_2, VisualStyle.CYAN_2, 1))
	button.add_theme_stylebox_override("hover", VisualStyle.pixel_box(VisualStyle.DARK_3, VisualStyle.CYAN, 1))
	button.add_theme_stylebox_override("pressed", VisualStyle.pixel_box(VisualStyle.BLUE, VisualStyle.YELLOW, 1))
	button.add_theme_stylebox_override("disabled", VisualStyle.pixel_box(VisualStyle.DARK_2, VisualStyle.SHADOW, 1))
	button.pressed.connect(callback)
	return button


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
	button.custom_minimum_size = Vector2(176, 52)
	_set_control_font_size(button, 16)
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
		var image := Image.new()
		if image.load(path) != OK:
			run_item_icon_texture_cache[path] = null
			return null
		var image_texture := ImageTexture.create_from_image(image)
		run_item_icon_texture_cache[path] = image_texture
		return image_texture
	var texture := load(path) as Texture2D
	run_item_icon_texture_cache[path] = texture
	return texture


func _style_selected_button(button: Button) -> void:
	button.add_theme_stylebox_override("normal", VisualStyle.pixel_box(VisualStyle.BLUE, VisualStyle.YELLOW, 1))
	button.add_theme_stylebox_override("hover", VisualStyle.pixel_box(VisualStyle.BLUE, VisualStyle.AMBER, 1))
	button.add_theme_stylebox_override("pressed", VisualStyle.pixel_box(VisualStyle.BLUE, VisualStyle.WHITE, 1))


func _clear(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()


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
