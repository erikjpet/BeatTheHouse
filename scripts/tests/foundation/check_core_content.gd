extends SceneTree

# Smoke test for production content and foundation contracts.

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const RunGeneratorScript := preload("res://scripts/core/run_generator.gd")
const SaveServiceScript := preload("res://scripts/core/save_service.gd")
const PlatformServicesScript := preload("res://scripts/core/platform_services.gd")
const WorldMapScript := preload("res://scripts/core/world_map.gd")
const CardShoeScript := preload("res://scripts/core/card_shoe.gd")
const ProfileInventoryScript := preload("res://scripts/core/profile_inventory.gd")
const TutorialFlowScript := preload("res://scripts/core/tutorial_flow.gd")
const MetaCollectionServiceScript := preload("res://scripts/core/meta_collection_service.gd")
const CollectionDropServiceScript := preload("res://scripts/core/collection_drop_service.gd")
const RunTerminalEvaluatorScript := preload("res://scripts/core/run_terminal_evaluator.gd")
const RunActionServiceScript := preload("res://scripts/core/run_action_service.gd")
const EventModuleScript := preload("res://scripts/core/event_module.gd")
const AttributeBadgesScript := preload("res://scripts/core/attribute_badges.gd")
const ArtContractsScript := preload("res://scripts/core/art_contracts.gd")
const EnvironmentHoursScript := preload("res://scripts/core/environment_hours.gd")
const UserSettingsScript := preload("res://scripts/core/user_settings.gd")
const ProceduralMusicPlayerScript := preload("res://scripts/ui/procedural_music_player.gd")
const MusicArrangementSelectorScript := preload("res://scripts/ui/music_arrangement_selector.gd")
const SfxPlayerScript := preload("res://scripts/ui/sfx_player.gd")
const WebAudioBridgeScript := preload("res://scripts/ui/web_audio_bridge.gd")
const GameSurfaceCanvasScript := preload("res://scripts/ui/game_surface_canvas.gd")
const RunInventoryViewModelScript := preload("res://scripts/ui/run_inventory_view_model.gd")
const CoachViewModelScript := preload("res://scripts/ui/coach_view_model.gd")
const SlotGameScript := preload("res://scripts/games/slot.gd")
const SlotMachineGeneratorScript := preload("res://scripts/games/slots/slot_machine_generator.gd")
const SlotMachineStateScript := preload("res://scripts/games/slots/slot_machine_state.gd")
const SlotResolverScript := preload("res://scripts/games/slots/slot_resolver.gd")
const SlotCatalogScript := preload("res://scripts/games/slots/slot_catalog.gd")
const SlotFamilyBuffaloScript := preload("res://scripts/games/slots/slot_family_buffalo.gd")
const SlotFamilyPinballScript := preload("res://scripts/games/slots/slot_family_pinball.gd")
const PinballBoardsScript := preload("res://scripts/games/slots/pinball/pinball_boards.gd")
const PinballBoardScript := preload("res://scripts/games/slots/pinball/pinball_board.gd")
const PinballFeatureScript := preload("res://scripts/games/slots/pinball/pinball_feature.gd")
const PinballSimScript := preload("res://scripts/games/slots/pinball/pinball_sim.gd")
const SlotPresentationScript := preload("res://scripts/games/slots/slot_presentation.gd")
const SlotRendererScript := preload("res://scripts/games/slots/slot_renderer.gd")
const MainScene := preload("res://scenes/main.tscn")

const FOUNDATION_DEFAULT_REPORT_PATH := "res://.tmp/foundation_check/report.json"
const TUTORIAL_META_STORE_PATH := "user://foundation_tutorial_meta_store.json"
const SAVE_COMPAT_030_FIXTURE_PATH := "res://scripts/tests/fixtures/run_state_0_3_0_save.json"
const SAVE_COMPAT_033_FIXTURE_PATH := "res://scripts/tests/fixtures/run_state_0_3_3_save.json"
const SLOT_ACCEPTANCE_MONTE_CARLO_SPINS := 10000
const SLOT_FEATURE_SUBSIMULATION_SAMPLES := 96
const SAVE_LOAD_FUZZ_SEEDS := 4
const SAVE_LOAD_FUZZ_ACTIONS_PER_SEED := 5
const SAVE_LOAD_FUZZ_CONTINUATION_STEPS := 5
const SAVE_LOAD_CANONICAL_FLOAT_STEP := 0.000000001
const SAVE_LOAD_CANONICAL_INTEGER_EPSILON := 0.000000001
const UI_STATE_FUZZ_SEEDS := 3
const UI_STATE_FUZZ_STEPS_PER_SEED := 12
const RELEASE_COPY_BLOCKER_MARKERS := ["todo", "placeholder", "debug-only", "dev-only", "test-only", "coming soon", "not implemented"]
const RELEASE_COPY_SOURCE_MARKERS := ["debug-only", "dev-only", "test-only", "coming soon", "not implemented"]
const FOUNDATION_SUITE_ALIASES := {
	"contract": "contracts",
	"full": "all",
}
const FOUNDATION_SUITES := [
	"smoke",
	"contracts",
	"games",
	"systems",
	"slot",
	"slots",
	"slot_acceptance",
	"blackjack",
	"roulette",
	"baccarat",
	"video_poker",
	"bar_dice",
	"pull_tabs",
	"scratch_tickets",
	"audit",
	"all",
]

var _foundation_active_suite := "contracts"


class SurfaceHarness:
	extends RefCounted

	var surface_state: Dictionary = {}
	var hit_regions: Array = []
	var hovered_action: String = ""
	var hovered_index: int = -1
	var labels: Array = []
	var label_records: Array = []
	var stake_control_count := 0
	var native_stake_strip_count := 0
	var animation_active := false
	var animation_elapsed := 999.0
	var animation_duration := 2.4
	var animation_progress := 1.0
	var flicker_value := 0.0

	func setup(state: Dictionary) -> void:
		surface_state = state.duplicate(true)
		hit_regions = []
		hovered_action = ""
		hovered_index = -1
		labels = []
		label_records = []
		stake_control_count = 0
		native_stake_strip_count = 0
		animation_active = false
		animation_elapsed = 999.0
		animation_duration = 2.4
		animation_progress = 1.0
		flicker_value = 0.0

	func surface_board_size() -> Vector2:
		return Vector2(ArtContractsScript.GAME_BOARD_SIZE)

	func surface_begin_design_space(_design_size: Vector2) -> void:
		pass

	func surface_begin_design_space_inset(design_size: Vector2, _inset: Vector2) -> void:
		surface_begin_design_space(design_size)

	func surface_end_design_space() -> void:
		pass

	func surface_flicker() -> float:
		return flicker_value

	func surface_elapsed(_channel_id: String) -> float:
		return animation_elapsed

	func surface_animation_active(_channel_id: String) -> bool:
		return animation_active

	func surface_animation_duration(_channel_id: String) -> float:
		return animation_duration

	func surface_animation_progress(_channel_id: String) -> float:
		return clampf(animation_progress, 0.0, 1.0)

	func surface_animation_active_id(channel_id: String) -> String:
		for channel_value in surface_state.get("surface_animation_channels", []):
			if typeof(channel_value) == TYPE_DICTIONARY and str((channel_value as Dictionary).get("id", "")) == channel_id:
				return str((channel_value as Dictionary).get("active_id", ""))
		return ""

	func surface_animation_metadata(_channel_id: String) -> Dictionary:
		return {}

	func surface_region_hovered(action: String, index: int = -1) -> bool:
		return hovered_action == action and (index < 0 or hovered_index == index)

	func surface_native_action_selected(action: String) -> bool:
		return (surface_state.get("native_selected_surface_actions", []) as Array).has(action)

	func surface_label(text: String, pos: Vector2, font_size: int, _color: Color) -> void:
		labels.append(text)
		label_records.append({"text": text, "rect": Rect2(pos, Vector2.ZERO), "font_size": font_size})

	func surface_label_plain(text: String, pos: Vector2, font_size: int, _color: Color) -> void:
		labels.append(text)
		label_records.append({"text": text, "rect": Rect2(pos, Vector2.ZERO), "font_size": font_size})

	func surface_label_centered(text: String, rect: Rect2, font_size: int, _color: Color) -> void:
		labels.append(text)
		label_records.append({"text": text, "rect": rect, "font_size": font_size})

	func surface_label_centered_plain(text: String, rect: Rect2, font_size: int, _color: Color) -> void:
		labels.append(text)
		label_records.append({"text": text, "rect": rect, "font_size": font_size})

	func surface_title(text: String, _pos: Vector2, _color: Color) -> void:
		labels.append(text)

	func surface_draw_ready_badge(_rect: Rect2, _label: String) -> void:
		pass

	func surface_draw_stake_control(rect: Rect2, _label: String, enabled: bool, action: String) -> void:
		stake_control_count += 1
		if enabled:
			surface_add_hit(rect, action)

	func surface_draw_native_stake_strip(_pos: Vector2) -> void:
		native_stake_strip_count += 1

	func surface_draw_action_button(rect: Rect2, _label: String, action: String, index: int, _accent: Color) -> void:
		surface_add_hit(rect, action, index)

	func surface_add_hit(rect: Rect2, action: String, index: int = -1, expand_touch_hit: bool = true) -> void:
		hit_regions.append({"rect": rect, "action": action, "index": index, "exact": not expand_touch_hit})

	func surface_add_invisible_hit(rect: Rect2, action: String, index: int = -1) -> void:
		surface_add_hit(rect, action, index)

	func surface_add_exact_hit(rect: Rect2, action: String, index: int = -1) -> void:
		surface_add_hit(rect, action, index, false)

	func surface_add_cached_exact_hits(_cache_key: String, rect_sources: Array, action: String) -> void:
		for index in range(rect_sources.size()):
			var source_value: Variant = rect_sources[index]
			var rect_value: Variant = source_value
			if typeof(source_value) == TYPE_DICTIONARY:
				rect_value = (source_value as Dictionary).get("rect", Rect2())
			var rect := Rect2()
			if typeof(rect_value) == TYPE_RECT2:
				rect = rect_value as Rect2
			elif typeof(rect_value) == TYPE_DICTIONARY:
				var data: Dictionary = rect_value
				rect = Rect2(Vector2(float(data.get("x", data.get("left", 0.0))), float(data.get("y", data.get("top", 0.0)))), Vector2(float(data.get("w", data.get("width", 0.0))), float(data.get("h", data.get("height", 0.0)))))
			if rect.size.x > 0.0 and rect.size.y > 0.0:
				surface_add_exact_hit(rect, action, index)

	func surface_add_exact_invisible_hit(rect: Rect2, action: String, index: int = -1) -> void:
		surface_add_invisible_hit(rect, action, index)

	func surface_add_drag_hit(rect: Rect2, action: String, index: int = -1) -> void:
		hit_regions.append({"rect": rect, "action": action, "index": index, "drag": true, "exact": true})

	func draw_rect(_rect: Rect2, _color: Color, _filled: bool = true, _width: float = -1.0, _antialiased: bool = false) -> void:
		pass

	func draw_texture_rect(_texture: Texture2D, _rect: Rect2, _tile: bool, _modulate: Color = Color(1, 1, 1, 1), _transpose: bool = false) -> void:
		pass

	func draw_circle(_position: Vector2, _radius: float, _color: Color, _filled: bool = true, _width: float = -1.0, _antialiased: bool = false) -> void:
		pass

	func draw_line(_from: Vector2, _to: Vector2, _color: Color, _width: float = -1.0, _antialiased: bool = false) -> void:
		pass

	func draw_polygon(_points: Array, _colors: Array, _uvs: Array = [], _texture: Texture2D = null) -> void:
		pass


class HostileInputAllInFixtureGame:
	extends GameModule

	func _init() -> void:
		setup({
			"id": "sb4_all_in_fixture",
			"display_name": "SB4 All-In Fixture",
			"family": "fixture",
			"legal_actions": [{
				"id": "all_in_loss",
				"label": "All-in loss",
				"summary": "Loses exactly the selected stake.",
			}],
			"cheat_actions": [],
		})

	func actions(run_state: RunState, environment: Dictionary) -> Dictionary:
		return {
			"ok": true,
			"type": "game_actions",
			"game_id": get_id(),
			"legal_actions": legal_actions(run_state, environment),
			"cheat_actions": [],
			"stake_floor": 1,
			"stake_ceiling": 2,
		}

	func wager_cost_for_context(_action_id: String, stake: int, _run_state: RunState, _environment: Dictionary, _ui_state: Dictionary = {}) -> int:
		return maxi(0, stake)

	func resolve(_action_id: String, stake: int, _run_state: RunState, _environment: Dictionary, _rng: RngStream) -> Dictionary:
		return {
			"ok": true,
			"type": "game_result",
			"game_id": get_id(),
			"stake": stake,
			"won": false,
			"host_apply_result": true,
			"deltas": {
				"bankroll_delta": -stake,
			},
			"message": "Fixture all-in loss.",
		}


# Runs fixture checks and exits with a process code.
func _init() -> void:
	var options := _foundation_options()
	if bool(options.get("list", false)):
		_foundation_print_suite_list()
		quit(0)
		return
	_foundation_active_suite = str(options.get("suite", "contracts"))
	var failures: Array = []
	var report := _foundation_report(_foundation_active_suite)
	var content_library: ContentLibrary = ContentLibraryScript.new()
	content_library.load()
	var fixture_library := _fixture_library()
	_foundation_run_suite(_foundation_active_suite, content_library, fixture_library, failures, report)
	report["duration_msec"] = Time.get_ticks_msec() - int(report.get("started_msec", 0))
	report["failure_count"] = failures.size()
	report["failures"] = failures.duplicate()
	report["passed"] = failures.is_empty()
	_foundation_write_report(str(options.get("report", FOUNDATION_DEFAULT_REPORT_PATH)), report)

	if failures.is_empty():
		print("Foundation Godot checks passed. suite=%s checks=%d report=%s" % [
			_foundation_active_suite,
			(report.get("checks", []) as Array).size(),
			str(options.get("report", FOUNDATION_DEFAULT_REPORT_PATH)),
		])
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _foundation_options() -> Dictionary:
	var options := {
		"suite": "contracts",
		"report": FOUNDATION_DEFAULT_REPORT_PATH,
		"list": false,
	}
	for raw_arg in OS.get_cmdline_user_args():
		var arg := str(raw_arg).strip_edges()
		if arg == "--list":
			options["list"] = true
		elif arg.begins_with("--suite="):
			options["suite"] = _foundation_normalized_suite(arg.get_slice("=", 1))
		elif arg.begins_with("--report="):
			options["report"] = arg.get_slice("=", 1)
	return options


func _foundation_normalized_suite(raw_suite: String) -> String:
	var suite := raw_suite.strip_edges().to_lower()
	if FOUNDATION_SUITE_ALIASES.has(suite):
		suite = str(FOUNDATION_SUITE_ALIASES.get(suite, suite))
	if not FOUNDATION_SUITES.has(suite):
		push_warning("Unknown foundation_check suite '%s'; using contracts." % raw_suite)
		return "contracts"
	return suite


func _foundation_print_suite_list() -> void:
	print(JSON.stringify({
		"tool": "foundation_check",
		"suites": FOUNDATION_SUITES,
		"default_suite": "contracts",
		"reports": true,
	}))


func _foundation_report(suite: String) -> Dictionary:
	return {
		"tool": "foundation_check",
		"suite": suite,
		"started_msec": Time.get_ticks_msec(),
		"duration_msec": 0,
		"passed": false,
		"failure_count": 0,
		"failures": [],
		"checks": [],
		"skipped": [],
		"last_started_check": "",
	}


func _foundation_run_suite(suite: String, content_library: ContentLibrary, fixture_library: ContentLibrary, failures: Array, report: Dictionary) -> void:
	match suite:
		"smoke":
			_foundation_run_check(report, failures, "content", Callable(self, "_check_content"), [content_library])
			_foundation_run_check(report, failures, "coach_engine_foundation", Callable(self, "_check_coach_engine_foundation"), [content_library])
			_foundation_run_check(report, failures, "onboarding_tutorial_arc", Callable(self, "_check_onboarding_tutorial_arc"), [content_library])
			_foundation_run_check(report, failures, "profile_inventory_boundary", Callable(self, "_check_profile_inventory_boundary"), [])
			_foundation_run_check(report, failures, "foundation_contract_smoke", Callable(self, "_check_foundation_contract_smoke_for_suite"), [content_library])
			_foundation_run_check(report, failures, "fixture_rng", Callable(self, "_check_rng"), [fixture_library])
			_foundation_run_check(report, failures, "fixture_contracts", Callable(self, "_check_contracts"), [fixture_library])
		"contracts":
			_foundation_run_contract_suite(content_library, fixture_library, failures, report)
		"games":
			_foundation_run_check(report, failures, "content", Callable(self, "_check_content"), [content_library])
			_foundation_run_check(report, failures, "game_surface_contracts", Callable(self, "_check_game_surface_contracts"), [content_library])
			_foundation_run_check(report, failures, "table_environment_entry_contracts", Callable(self, "_check_table_environment_entry_contracts"), [content_library])
			_foundation_run_check(report, failures, "bar_dice_contract", Callable(self, "_check_bar_dice_contract"), [content_library])
			_foundation_run_check(report, failures, "video_poker_contract", Callable(self, "_check_video_poker_contract"), [content_library])
			_foundation_run_check(report, failures, "all_game_module_contracts", Callable(self, "_check_all_game_module_contracts"), [content_library])
			_foundation_run_check(report, failures, "cross_game_integration_matrix", Callable(self, "_check_cross_game_integration_matrix"), [content_library])
			_foundation_run_check(report, failures, "slot_contract_smoke", Callable(self, "_check_slot_contract_smoke"), [content_library])
		"systems":
			_foundation_run_system_suite(content_library, fixture_library, failures, report)
		"slot", "slots":
			_foundation_run_check(report, failures, "content", Callable(self, "_check_content"), [content_library])
			_foundation_run_check(report, failures, "slot_contract_smoke", Callable(self, "_check_slot_contract_smoke"), [content_library])
		"slot_acceptance":
			_foundation_run_check(report, failures, "content", Callable(self, "_check_content"), [content_library])
			_foundation_run_check(report, failures, "slot_acceptance_deep", Callable(self, "_check_slot_acceptance"), [content_library])
		"audit":
			_foundation_run_check(report, failures, "content", Callable(self, "_check_content"), [content_library])
			_foundation_run_check(report, failures, "slot_acceptance_deep", Callable(self, "_check_slot_acceptance"), [content_library])
		"all":
			_foundation_run_all_suite(content_library, fixture_library, failures, report)
		_:
			if ["blackjack", "roulette", "baccarat", "video_poker", "bar_dice", "pull_tabs", "scratch_tickets"].has(suite):
				_foundation_run_check(report, failures, "content", Callable(self, "_check_content"), [content_library])
				_foundation_run_check(report, failures, "%s_game_suite" % suite, Callable(self, "_check_target_game_suite"), [content_library, suite])
			else:
				_foundation_run_contract_suite(content_library, fixture_library, failures, report)


func _foundation_run_contract_suite(content_library: ContentLibrary, fixture_library: ContentLibrary, failures: Array, report: Dictionary) -> void:
	_foundation_run_check(report, failures, "content", Callable(self, "_check_content"), [content_library])
	_foundation_run_check(report, failures, "coach_engine_foundation", Callable(self, "_check_coach_engine_foundation"), [content_library])
	_foundation_run_check(report, failures, "foundation_contracts", Callable(self, "_check_foundation_contract_smoke_for_suite"), [content_library])
	_foundation_run_check(report, failures, "profile_inventory_boundary", Callable(self, "_check_profile_inventory_boundary"), [])
	_foundation_run_check(report, failures, "fixture_rng", Callable(self, "_check_rng"), [fixture_library])
	_foundation_run_check(report, failures, "card_shoe_core_primitives", Callable(self, "_check_card_shoe_core_primitives"), [])
	_foundation_run_check(report, failures, "run_state_source_of_truth", Callable(self, "_check_run_state_source_of_truth"), [fixture_library])
	_foundation_run_check(report, failures, "locked_logic_rate_foundation", Callable(self, "_check_locked_logic_rate_foundation"), [content_library])
	_foundation_run_check(report, failures, "fixture_contracts", Callable(self, "_check_contracts"), [fixture_library])


func _foundation_run_system_suite(content_library: ContentLibrary, fixture_library: ContentLibrary, failures: Array, report: Dictionary) -> void:
	_foundation_run_check(report, failures, "content", Callable(self, "_check_content"), [content_library])
	_foundation_run_check(report, failures, "coach_engine_foundation", Callable(self, "_check_coach_engine_foundation"), [content_library])
	_foundation_run_check(report, failures, "onboarding_tutorial_arc", Callable(self, "_check_onboarding_tutorial_arc"), [content_library])
	_foundation_run_check(report, failures, "attribute_glyph_foundation", Callable(self, "_check_attribute_glyph_foundation"), [content_library])
	_foundation_run_check(report, failures, "profile_inventory_boundary", Callable(self, "_check_profile_inventory_boundary"), [])
	_foundation_run_check(report, failures, "fixture_rng", Callable(self, "_check_rng"), [fixture_library])
	_foundation_run_check(report, failures, "run_state_source_of_truth", Callable(self, "_check_run_state_source_of_truth"), [fixture_library])
	_foundation_run_check(report, failures, "locked_logic_rate_foundation", Callable(self, "_check_locked_logic_rate_foundation"), [content_library])
	_foundation_run_check(report, failures, "fixture_contracts", Callable(self, "_check_contracts"), [fixture_library])
	_foundation_run_check(report, failures, "run_action_service_boundary", Callable(self, "_check_run_action_service_boundary"), [content_library])
	_foundation_run_check(report, failures, "mutation_firewall_foundation", Callable(self, "_check_mutation_firewall_foundation"), [content_library])
	_foundation_run_check(report, failures, "ui_state_machine_input_fuzz_foundation", Callable(self, "_check_ui_state_machine_input_fuzz_foundation"), [content_library])
	_foundation_run_check(report, failures, "challenge_pack_foundation", Callable(self, "_check_challenge_pack_foundation"), [content_library])
	_foundation_run_check(report, failures, "item_effect_foundation", Callable(self, "_check_item_effect_foundation"), [content_library])
	_foundation_run_check(report, failures, "item_build_interaction_foundation", Callable(self, "_check_item_build_interaction_foundation"), [content_library])
	_foundation_run_check(report, failures, "event_module_foundation", Callable(self, "_check_event_module_foundation"), [content_library])
	_foundation_run_check(report, failures, "event_system_state_foundation", Callable(self, "_check_event_system_state_foundation"), [content_library])
	_foundation_run_check(report, failures, "talk_decision_system_foundation", Callable(self, "_check_talk_decision_system_foundation"), [content_library])
	_foundation_run_check(report, failures, "dialogue_system_foundation", Callable(self, "_check_dialogue_system_foundation"), [content_library])
	_foundation_run_check(report, failures, "t4_7_event_interaction_model", Callable(self, "_check_t4_7_event_interaction_model"), [content_library])
	_foundation_run_check(report, failures, "t6_7_visibility_event_cadence", Callable(self, "_check_t6_7_visibility_event_cadence"), [content_library])
	_foundation_run_check(report, failures, "save_service_foundation_round_trip", Callable(self, "_check_save_service_foundation_round_trip"), [content_library])
	_foundation_run_check(report, failures, "save_load_interrupt_fuzz_foundation", Callable(self, "_check_save_load_interrupt_fuzz_foundation"), [content_library])
	_foundation_run_check(report, failures, "platform_services_foundation", Callable(self, "_check_platform_services_foundation"), [])
	_foundation_run_check(report, failures, "economy_pressure_foundation", Callable(self, "_check_economy_pressure_foundation"), [content_library])
	_foundation_run_check(report, failures, "travel_route_foundation", Callable(self, "_check_travel_route_foundation"), [content_library])
	_foundation_run_check(report, failures, "world_map_foundation", Callable(self, "_check_world_map_foundation"), [content_library])
	_foundation_run_check(report, failures, "meta_home_run_boundary", Callable(self, "_check_meta_home_run_boundary"), [content_library])
	_foundation_run_check(report, failures, "meta_home_fresh_store_defaults", Callable(self, "_check_meta_home_fresh_store_defaults"), [])
	_foundation_run_check(report, failures, "meta_home_fixture_pollution_migration", Callable(self, "_check_meta_home_fixture_pollution_migration"), [])
	_foundation_run_check(report, failures, "time_open_hours_foundation", Callable(self, "_check_time_open_hours_foundation"), [content_library])
	_foundation_run_check(report, failures, "service_hook_foundation", Callable(self, "_check_service_hook_foundation"), [content_library])
	_foundation_run_check(report, failures, "jazz_club_foundation", Callable(self, "_check_jazz_club_foundation"), [content_library])
	_foundation_run_check(report, failures, "lender_debt_foundation", Callable(self, "_check_lender_debt_foundation"), [content_library])
	_foundation_run_check(report, failures, "suspicion_security_foundation", Callable(self, "_check_suspicion_security_foundation"), [])
	_foundation_run_check(report, failures, "run_report_foundation", Callable(self, "_check_run_report_foundation"), [])
	_foundation_run_check(report, failures, "music_fx_foundation", Callable(self, "_check_music_fx_foundation"), [content_library])
	_foundation_run_check(report, failures, "music_stem_director_foundation", Callable(self, "_check_music_stem_director_foundation"), [content_library])
	_foundation_run_check(report, failures, "skill_cheat_contract_foundation", Callable(self, "_check_skill_cheat_contract_foundation"), [content_library])
	_foundation_run_check(report, failures, "skill_timing_helper_foundation", Callable(self, "_check_skill_timing_helper_foundation"), [content_library])
	_foundation_run_check(report, failures, "skill_cheat_item_modifier_foundation", Callable(self, "_check_skill_cheat_item_modifier_foundation"), [content_library])
	_foundation_run_check(report, failures, "m2_system_interaction_scenario", Callable(self, "_check_m2_system_interaction_scenario"), [content_library])
	_foundation_run_check(report, failures, "demo_boss_objective_foundation", Callable(self, "_check_demo_boss_objective_foundation"), [content_library])
	_foundation_run_check(report, failures, "recovery_loss_pressure_foundation", Callable(self, "_check_recovery_loss_pressure_foundation"), [content_library])


func _foundation_run_all_suite(content_library: ContentLibrary, fixture_library: ContentLibrary, failures: Array, report: Dictionary) -> void:
	_foundation_run_check(report, failures, "content", Callable(self, "_check_content"), [content_library])
	_foundation_run_check(report, failures, "coach_engine_foundation", Callable(self, "_check_coach_engine_foundation"), [content_library])
	_foundation_run_check(report, failures, "onboarding_tutorial_arc", Callable(self, "_check_onboarding_tutorial_arc"), [content_library])
	_foundation_run_check(report, failures, "attribute_glyph_foundation", Callable(self, "_check_attribute_glyph_foundation"), [content_library])
	_foundation_run_check(report, failures, "foundation_contracts_all", Callable(self, "_check_foundation_contract_smoke_for_suite"), [content_library])
	_foundation_run_check(report, failures, "profile_inventory_boundary", Callable(self, "_check_profile_inventory_boundary"), [])
	_foundation_run_check(report, failures, "fixture_rng", Callable(self, "_check_rng"), [fixture_library])
	_foundation_run_check(report, failures, "run_state_source_of_truth", Callable(self, "_check_run_state_source_of_truth"), [fixture_library])
	_foundation_run_check(report, failures, "table_environment_entry_contracts", Callable(self, "_check_table_environment_entry_contracts"), [content_library])
	_foundation_run_check(report, failures, "locked_logic_rate_foundation", Callable(self, "_check_locked_logic_rate_foundation"), [content_library])
	_foundation_run_check(report, failures, "fixture_contracts", Callable(self, "_check_contracts"), [fixture_library])
	_foundation_run_check(report, failures, "ui_state_machine_input_fuzz_foundation", Callable(self, "_check_ui_state_machine_input_fuzz_foundation"), [content_library])
	_foundation_run_check(report, failures, "talk_decision_system_foundation", Callable(self, "_check_talk_decision_system_foundation"), [content_library])
	_foundation_run_check(report, failures, "dialogue_system_foundation", Callable(self, "_check_dialogue_system_foundation"), [content_library])


func _foundation_run_check(report: Dictionary, failures: Array, check_id: String, callable: Callable, args: Array) -> void:
	var start_msec := Time.get_ticks_msec()
	var before_failures := failures.size()
	report["last_started_check"] = check_id
	print("FOUNDATION_CHECK_START id=%s suite=%s" % [check_id, _foundation_active_suite])
	var call_args := args.duplicate()
	call_args.append(failures)
	callable.callv(call_args)
	var duration := Time.get_ticks_msec() - start_msec
	var failure_delta := failures.size() - before_failures
	(report["checks"] as Array).append({
		"id": check_id,
		"duration_msec": duration,
		"failure_count": failure_delta,
		"passed": failure_delta == 0,
	})
	print("FOUNDATION_CHECK_DONE id=%s duration_msec=%d failures=%d" % [check_id, duration, failure_delta])


func _foundation_write_report(report_path: String, report: Dictionary) -> void:
	var global_path := ProjectSettings.globalize_path(report_path)
	DirAccess.make_dir_recursive_absolute(global_path.get_base_dir())
	var file := FileAccess.open(global_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))


func _check_foundation_contract_smoke_for_suite(library: ContentLibrary, failures: Array) -> void:
	_check_foundation_contract_smoke(library, failures, _foundation_active_suite)


# Checks the first production content path.
func _check_content(library: ContentLibrary, failures: Array) -> void:
	_check_canonical_pack_paths(failures)
	for error in library.validation_errors:
		failures.append("ContentLibrary validation failed: %s" % error)

	if library.environment_archetypes.size() < 6:
		failures.append("Expected at least six vertical-slice environment archetypes.")
	if library.items.size() < 8:
		failures.append("Expected at least eight starter items.")
	if library.games.size() < 5:
		failures.append("Expected at least five starter activities.")
	_check_player_facing_description_copy(library, failures)
	_check_release_copy_style_blockers(library, failures)
	_check_content_art_presentation(library, failures)
	_check_blackjack_item_content(library, failures)
	_check_m2_pack_availability(library, failures)
	_check_tier_two_venue_progression(library, failures)
	_check_baccarat_grand_casino_only(library, failures)
	_check_environment_game_pool_distribution(library, failures)
	_check_environment_encounter_freshness(library, failures)
	_check_high_risk_table_limit_overrides(library, failures)
	_check_environment_open_hours(library, failures)
	_check_dialogue_system_content(library, failures)
	_check_talk_content_pass_content(library, failures)
	_check_content_validation_boot_surfacing(library, failures)
	_check_t4_3_event_pack(library, failures)
	_check_t4_4_item_pack(library, failures)
	_check_content_group_modularity(library, failures)
	_check_challenge_pack_content(library, failures)
	_check_s0_2_baseline_regression_fixtures(library, failures)
	_check_sa_2_per_frame_contracts(failures)

	var run_state: RunState = RunStateScript.new()
	run_state.start_new("CONTENT-CHECK")
	var generator: RunGenerator = RunGeneratorScript.new(library)
	var first_environment: EnvironmentInstance = generator.next_environment(run_state)
	_check_environment_instance_shape(first_environment, false, failures)
	_check_start_home_environment(run_state, first_environment, failures)
	if first_environment.kind != "home":
		_check_offer_prices(first_environment.item_offers, library, failures)
		_check_events(first_environment.event_ids, library, [first_environment.kind], failures)
	for game_id in first_environment.game_ids:
		if library.game(game_id).is_empty():
			failures.append("Generated environment references unknown activity: %s." % game_id)

	var target: String = str(first_environment.next_archetypes[0]) if not first_environment.next_archetypes.is_empty() else ""
	var second_environment: EnvironmentInstance = generator.next_environment(run_state, target)
	_check_environment_instance_shape(second_environment, false, failures)
	if second_environment.id == first_environment.id:
		failures.append("Travel did not generate a distinct second environment.")


func _check_attribute_glyph_foundation(library: ContentLibrary, failures: Array) -> void:
	for error_value in AttributeBadgesScript.validation_errors():
		failures.append("Attribute glyph registry validation failed: %s" % str(error_value))
	var glyph_ids := AttributeBadgesScript.glyph_ids()
	if glyph_ids.is_empty():
		failures.append("Attribute glyph registry did not expose any glyph ids.")
	var legend_entries := AttributeBadgesScript.legend_entries()
	if legend_entries.size() != glyph_ids.size():
		failures.append("Attribute glyph legend must enumerate every registry glyph.")
	_check_attribute_class_coverage("item", library.items, "class", failures)
	_check_attribute_class_coverage("event", library.events, "type", failures)
	_check_attribute_class_coverage("route", library.travel_routes, "risk", failures)
	_check_attribute_class_coverage("service", library.services, "category", failures)
	_check_attribute_class_coverage("lender", library.lenders, "lender_type", failures)
	var route := _first_dictionary(library.travel_routes)
	if route.is_empty():
		failures.append("Attribute glyph route fixture is missing.")
	else:
		var route_before := JSON.stringify(route)
		var route_badges := AttributeBadgesScript.for_route(route, {})
		if route_badges.is_empty():
			failures.append("Attribute glyph route builder returned no badges.")
		if JSON.stringify(route) != route_before:
			failures.append("Attribute glyph route builder mutated its input.")
	var item := _first_dictionary(library.items)
	if item.is_empty():
		failures.append("Attribute glyph item fixture is missing.")
	else:
		var item_before := JSON.stringify(item)
		var item_badges := AttributeBadgesScript.for_item(item)
		if item_badges.is_empty():
			failures.append("Attribute glyph item builder returned no badges.")
		if JSON.stringify(item) != item_before:
			failures.append("Attribute glyph item builder mutated its input.")
	var event_choice := _first_event_choice_fixture(library)
	if event_choice.is_empty():
		failures.append("Attribute glyph event choice fixture is missing.")
	else:
		var event_before := JSON.stringify(event_choice)
		var event_badges := AttributeBadgesScript.for_event_choice(event_choice)
		if event_badges.is_empty():
			failures.append("Attribute glyph event choice builder returned no badges.")
		if JSON.stringify(event_choice) != event_before:
			failures.append("Attribute glyph event choice builder mutated its input.")


func _check_attribute_class_coverage(kind: String, values: Array, field: String, failures: Array) -> void:
	var class_map := AttributeBadgesScript.class_badge_map(kind)
	var seen: Dictionary = {}
	for value in values:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var definition: Dictionary = value
		var class_id := str(definition.get(field, "")).strip_edges().to_lower()
		if class_id.is_empty() or seen.has(class_id):
			continue
		seen[class_id] = true
		if not class_map.has(class_id):
			failures.append("Attribute glyph class map %s is missing explicit badge for %s." % [kind, class_id])
			continue
		if AttributeBadgesScript.class_badge(kind, class_id).is_empty():
			failures.append("Attribute glyph class badge %s/%s did not build." % [kind, class_id])


func _first_event_choice_fixture(library: ContentLibrary) -> Dictionary:
	for event_value in library.events:
		if typeof(event_value) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = event_value
		var payload: Dictionary = event.get("payload", {}) if typeof(event.get("payload", {})) == TYPE_DICTIONARY else {}
		for choice_value in _copy_array(payload.get("choices", [])):
			if typeof(choice_value) != TYPE_DICTIONARY:
				continue
			var choice: Dictionary = (choice_value as Dictionary).duplicate(true)
			choice["event_type"] = str(event.get("type", ""))
			return choice
	return {}


func _first_dictionary(values: Array) -> Dictionary:
	for value in values:
		if typeof(value) == TYPE_DICTIONARY:
			return (value as Dictionary).duplicate(true)
	return {}


func _check_s0_2_baseline_regression_fixtures(library: ContentLibrary, failures: Array) -> void:
	_check_s0_2_tool_harness_contracts(failures)
	_check_s0_2_kitty_lounge_mixed_hook_layout(library, failures)


func _check_player_facing_description_copy(library: ContentLibrary, failures: Array) -> void:
	_check_description_list("item", library.items, "description", 8, failures)
	_check_description_list("game", library.games, "description", 8, failures)
	_check_description_list("travel route", library.travel_routes, "description", 8, failures)
	_check_description_list("service", library.services, "description", 8, failures)
	_check_description_list("lender", library.lenders, "description", 8, failures)
	for event_value in library.events:
		if typeof(event_value) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = event_value
		var payload: Dictionary = event.get("payload", {}) if typeof(event.get("payload", {})) == TYPE_DICTIONARY else {}
		_check_copy_word_limit("event %s summary" % str(event.get("id", "")), str(payload.get("summary", "")), 8, failures)
		var start_summary := str(event.get("start_summary", "")).strip_edges()
		if not start_summary.is_empty():
			_check_copy_word_limit("event %s start_summary" % str(event.get("id", "")), start_summary, 10, failures)
	for archetype_value in library.environment_archetypes:
		if typeof(archetype_value) != TYPE_DICTIONARY:
			continue
		var archetype: Dictionary = archetype_value
		var visual_context: Dictionary = archetype.get("visual_context", {}) if typeof(archetype.get("visual_context", {})) == TYPE_DICTIONARY else {}
		_check_copy_word_limit("environment %s description" % str(archetype.get("id", "")), str(visual_context.get("description", "")), 8, failures)


func _check_description_list(label: String, values: Array, field: String, max_words: int, failures: Array) -> void:
	for value in values:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = value
		_check_copy_word_limit("%s %s %s" % [label, str(entry.get("id", "")), field], str(entry.get(field, "")), max_words, failures)


func _check_copy_word_limit(label: String, text: String, max_words: int, failures: Array) -> void:
	var clean := text.strip_edges()
	if clean.is_empty():
		failures.append("%s should be brief but non-empty." % label)
		return
	var words := clean.split(" ", false)
	if words.size() > max_words:
		failures.append("%s should be %d words or fewer: %s" % [label, max_words, clean])
	if clean.length() > 72:
		failures.append("%s should fit compact description boxes: %s" % [label, clean])


func _check_release_copy_style_blockers(_library: ContentLibrary, failures: Array) -> void:
	var json_paths := _release_copy_json_paths("res://data")
	for path_value in json_paths:
		var json_path := str(path_value)
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(json_path))
		if parsed == null:
			failures.append("Release copy source scan could not parse %s." % json_path)
			continue
		_scan_release_copy_value(parsed, json_path, failures)
	for source_path in ["res://scripts/core/run_state.gd", "res://scripts/ui/foundation_main.gd"]:
		_scan_release_copy_source(str(source_path), failures)


func _release_copy_json_paths(root_path: String) -> Array:
	var paths: Array = []
	_release_copy_collect_json_paths(root_path, paths)
	paths.sort()
	return paths


func _release_copy_collect_json_paths(dir_path: String, paths: Array) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		var child_path := "%s/%s" % [dir_path, entry]
		if dir.current_is_dir():
			_release_copy_collect_json_paths(child_path, paths)
		elif entry.ends_with(".json"):
			paths.append(child_path)
		entry = dir.get_next()
	dir.list_dir_end()


func _scan_release_copy_value(value: Variant, path: String, failures: Array) -> void:
	var value_type := typeof(value)
	if value_type == TYPE_STRING:
		_check_release_copy_text(str(value), path, RELEASE_COPY_BLOCKER_MARKERS, failures)
		return
	if value_type == TYPE_DICTIONARY:
		var dict_value: Dictionary = value
		var keys := dict_value.keys()
		keys.sort()
		for key_value in keys:
			var key := str(key_value)
			_scan_release_copy_value(dict_value.get(key), "%s.%s" % [path, key], failures)
		return
	if value_type == TYPE_ARRAY:
		var array_value: Array = value
		for index in range(array_value.size()):
			var child_value: Variant = array_value[index]
			var child_path := "%s[%d]" % [path, index]
			if typeof(child_value) == TYPE_DICTIONARY:
				var child_dict: Dictionary = child_value
				var child_id := str(child_dict.get("id", "")).strip_edges()
				if not child_id.is_empty():
					child_path = "%s:%s" % [path, child_id]
			_scan_release_copy_value(child_value, child_path, failures)


func _scan_release_copy_source(path: String, failures: Array) -> void:
	var source := FileAccess.get_file_as_string(path)
	if source.is_empty():
		failures.append("Release copy source scan could not read %s." % path)
		return
	var lines := source.split("\n")
	for index in range(lines.size()):
		var line := str(lines[index])
		_check_release_copy_text(line, "%s:%d" % [path, index + 1], RELEASE_COPY_SOURCE_MARKERS, failures)


func _check_release_copy_text(text: String, path: String, markers: Array, failures: Array) -> void:
	var clean := text.strip_edges()
	if clean.is_empty():
		return
	var lowered := clean.to_lower()
	for marker_value in markers:
		var marker := str(marker_value)
		if lowered.find(marker) == -1:
			continue
		if _release_copy_expected_followup(path, marker, clean):
			continue
		failures.append("Release copy blocker marker '%s' found at %s: %s" % [marker, path, clean])


func _release_copy_expected_followup(_path: String, _marker: String, _text: String) -> bool:
	return false


func _check_s0_2_tool_harness_contracts(failures: Array) -> void:
	var roulette_audit_text := FileAccess.get_file_as_string("res://tools/roulette_seed_audit.gd")
	for method_name in ["surface_label_plain", "surface_label_centered_plain"]:
		if roulette_audit_text.find("func %s" % method_name) == -1:
			failures.append("S0.2 roulette seed audit harness is missing %s." % method_name)
	var visual_qa_text := FileAccess.get_file_as_string("res://tools/foundation_visual_qa.gd")
	for helper_name in ["_visible_risky_heat_delta", "_canvas_selected_info_contains", "_first_nonterminal_item_object"]:
		if visual_qa_text.find("func %s" % helper_name) == -1:
			failures.append("S0.2 visual QA harness is missing %s." % helper_name)


func _check_s0_2_kitty_lounge_mixed_hook_layout(library: ContentLibrary, failures: Array) -> void:
	var archetype := _archetype_by_id(library, "kitty_cat_lounge")
	if archetype.is_empty():
		failures.append("S0.2 Kitty Cat Lounge layout fixture could not find the archetype.")
		return
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("S02-KITTY-LAYOUT")
	var environment: Dictionary = EnvironmentInstance.from_archetype(archetype, 3, run_state.create_rng("s02_kitty_layout"), library).to_dict()
	environment["service_ids"] = ["kitty_champagne", "kitty_burlesque_show", "house_drink"]
	environment["lender_hooks"] = ["the_crew", "sals_pawn_counter"]
	environment["travel_hooks"] = ["bar", "jazz_club", "corner_store"]
	environment["next_archetypes"] = ["bar", "jazz_club", "corner_store"]
	environment["world_map_travel"] = true
	environment["layout"] = EnvironmentInstance.ensure_generated_layout(environment)
	var layout: Dictionary = environment.get("layout", {}) if typeof(environment.get("layout", {})) == TYPE_DICTIONARY else {}
	var object_rects: Dictionary = layout.get("object_rects", {}) if typeof(layout.get("object_rects", {})) == TYPE_DICTIONARY else {}
	for object_id in ["service:kitty_champagne", "lender:sals_pawn_counter"]:
		if not object_rects.has(object_id):
			failures.append("S0.2 Kitty Cat Lounge layout fixture is missing %s." % object_id)
	var keys: Array = object_rects.keys()
	for index in range(keys.size()):
		var key := str(keys[index])
		var rect := _layout_rect_from_dict(object_rects.get(key, {}))
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		for other_index in range(index + 1, keys.size()):
			var other_key := str(keys[other_index])
			var other_rect := _layout_rect_from_dict(object_rects.get(other_key, {}))
			if other_rect.size.x <= 0.0 or other_rect.size.y <= 0.0:
				continue
			if _layout_rects_overlap_with_gap(rect, other_rect):
				failures.append("S0.2 Kitty Cat Lounge generated layout overlaps: %s and %s." % [key, other_key])


func _check_sa_2_per_frame_contracts(failures: Array) -> void:
	var script_paths := _sa_2_runtime_script_paths("res://scripts")
	for path_value in script_paths:
		var path := str(path_value)
		var source := FileAccess.get_file_as_string(path)
		if source.is_empty():
			continue
		_sa_2_scan_per_frame_allocations(path, source, failures)
		_sa_2_scan_peek_contract(path, source, failures)


func _sa_2_runtime_script_paths(root_path: String) -> Array:
	var paths: Array = []
	_sa_2_collect_runtime_scripts(root_path, paths)
	paths.sort()
	return paths


func _sa_2_collect_runtime_scripts(dir_path: String, paths: Array) -> void:
	if dir_path == "res://scripts/tests":
		return
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		var child_path := "%s/%s" % [dir_path, entry]
		if dir.current_is_dir():
			if child_path != "res://scripts/tests":
				_sa_2_collect_runtime_scripts(child_path, paths)
		elif entry.ends_with(".gd"):
			paths.append(child_path)
		entry = dir.get_next()
	dir.list_dir_end()


func _sa_2_scan_per_frame_allocations(path: String, source: String, failures: Array) -> void:
	var current_function := ""
	var current_per_frame := false
	var lines := source.split("\n")
	for index in range(lines.size()):
		var line := str(lines[index])
		var stripped := line.strip_edges()
		var function_name := _sa_2_function_name_from_line(stripped)
		if not function_name.is_empty():
			current_function = function_name
			current_per_frame = _sa_2_is_per_frame_function(function_name)
		if not current_per_frame:
			continue
		if not _sa_2_line_has_banned_allocation(line):
			continue
		if _sa_2_line_has_valid_waiver(line):
			continue
		failures.append("SA.2/LB.2 per-frame cost tripwire: %s:%d %s contains duplicate()/JSON.stringify/OS.delay_*/Callable/PackedArray/Vector2-array/draw_string %% formatting without SA2_PER_FRAME_OK reason." % [path, index + 1, current_function])


func _sa_2_scan_peek_contract(path: String, source: String, failures: Array) -> void:
	var current_function := ""
	var peek_vars: Array = []
	var lines := source.split("\n")
	for index in range(lines.size()):
		var line := str(lines[index])
		var stripped := line.strip_edges()
		var function_name := _sa_2_function_name_from_line(stripped)
		if not function_name.is_empty():
			current_function = function_name
			peek_vars = []
		var peek_var := _sa_2_peek_assignment_name(stripped)
		if not peek_var.is_empty() and not peek_vars.has(peek_var):
			peek_vars.append(peek_var)
		if peek_vars.is_empty() or stripped.begins_with("#"):
			continue
		if stripped.find("table_round_timer_status(") != -1 and stripped.find("table_round_timer_status_peek(") == -1:
			failures.append("SA.2 peek contract tripwire: %s:%d %s passes a live peek into mutating table_round_timer_status()." % [path, index + 1, current_function])
		if stripped.find("StateScript.write_machine(") != -1:
			failures.append("SA.2 peek contract tripwire: %s:%d %s writes slot state after live peek; use read_machine() for mutation paths." % [path, index + 1, current_function])
		for var_name_value in peek_vars:
			var var_name := str(var_name_value)
			if _sa_2_line_mutates_peek_var(stripped, var_name):
				failures.append("SA.2 peek contract tripwire: %s:%d %s mutates live peek variable '%s'." % [path, index + 1, current_function, var_name])


func _sa_2_function_name_from_line(stripped_line: String) -> String:
	var line := stripped_line
	if line.begins_with("static func "):
		line = line.substr("static ".length())
	if not line.begins_with("func "):
		return ""
	var after_func := line.substr("func ".length())
	var paren_index := after_func.find("(")
	if paren_index == -1:
		return ""
	return after_func.substr(0, paren_index).strip_edges()


func _sa_2_is_per_frame_function(function_name: String) -> bool:
	return function_name == "_process" \
		or function_name == "_physics_process" \
		or function_name == "_draw" \
		or function_name == "draw_surface" \
		or function_name.begins_with("_draw_") \
		or function_name.ends_with("_per_frame") \
		or function_name.ends_with("_needs_auto_tick") \
		or function_name.ends_with("_runtime_needs_tick")


func _sa_2_line_has_banned_allocation(line: String) -> bool:
	return line.find("duplicate(") != -1 \
		or line.find("JSON.stringify") != -1 \
		or line.find("OS.delay_msec(") != -1 \
		or line.find("OS.delay_usec(") != -1 \
		or line.find("Callable(") != -1 \
		or _sa_2_line_has_packed_array_construct(line) \
		or _sa_2_line_has_vector2_array_literal(line) \
		or _sa_2_line_has_draw_string_percent_format(line)


func _sa_2_line_has_packed_array_construct(line: String) -> bool:
	return line.find("PackedByteArray(") != -1 \
		or line.find("PackedColorArray(") != -1 \
		or line.find("PackedFloat32Array(") != -1 \
		or line.find("PackedFloat64Array(") != -1 \
		or line.find("PackedInt32Array(") != -1 \
		or line.find("PackedInt64Array(") != -1 \
		or line.find("PackedStringArray(") != -1 \
		or line.find("PackedVector2Array(") != -1 \
		or line.find("PackedVector3Array(") != -1


func _sa_2_line_has_vector2_array_literal(line: String) -> bool:
	return line.find("[Vector2(") != -1 or line.find("[ Vector2(") != -1


func _sa_2_line_has_draw_string_percent_format(line: String) -> bool:
	if line.find("draw_string(") == -1:
		return false
	return line.find("\" %") != -1 \
		or line.find("\") %") != -1 \
		or line.find("\"] %") != -1 \
		or line.find("\"%") != -1 and line.find("% [") != -1


func _sa_2_line_has_valid_waiver(line: String) -> bool:
	var marker := "SA2_PER_FRAME_OK:"
	var marker_index := line.find(marker)
	if marker_index == -1:
		return false
	return line.substr(marker_index + marker.length()).strip_edges().length() >= 8


func _sa_2_peek_assignment_name(stripped_line: String) -> String:
	if stripped_line.find("_peek_table_state(") == -1 and stripped_line.find("StateScript.peek_machine(") == -1:
		return ""
	var assignment_index := stripped_line.find("=")
	if assignment_index == -1:
		return ""
	var left_side := stripped_line.substr(0, assignment_index).strip_edges()
	if left_side.begins_with("var "):
		left_side = left_side.substr("var ".length()).strip_edges()
	var colon_index := left_side.find(":")
	if colon_index != -1:
		left_side = left_side.substr(0, colon_index).strip_edges()
	return left_side


func _sa_2_line_mutates_peek_var(stripped_line: String, var_name: String) -> bool:
	if var_name.is_empty():
		return false
	if stripped_line.begins_with("%s[" % var_name) and stripped_line.find("=") != -1:
		return true
	for method_name in [".set(", ".erase(", ".clear(", ".merge(", ".assign("]:
		if stripped_line.begins_with("%s%s" % [var_name, method_name]):
			return true
	return false


func _check_start_home_environment(run_state: RunState, environment: EnvironmentInstance, failures: Array) -> void:
	if environment == null:
		return
	if environment.depth != 0:
		failures.append("The first generated EnvironmentInstance should be depth 0.")
	if environment.kind != "home":
		failures.append("The first generated EnvironmentInstance should be the selected home.")
	if not environment.game_ids.is_empty():
		failures.append("The first generated home should not expose gambling games before travel.")
	if not run_state.inventory.is_empty():
		failures.append("The first generated home should leave starter items in the room instead of auto-adding inventory.")
	if environment.item_offers.is_empty():
		failures.append("The first generated home should expose starter items as pickup objects.")
	for offer_value in environment.item_offers:
		if typeof(offer_value) != TYPE_DICTIONARY:
			continue
		var offer: Dictionary = offer_value
		if int(offer.get("price", -1)) != 0 or not bool(offer.get("pickup", false)):
			failures.append("Starter home item offers should be zero-cost pickup objects.")
			break
	var layout_rects_value: Variant = environment.layout.get("object_rects", {})
	var layout_rects: Dictionary = {}
	if typeof(layout_rects_value) == TYPE_DICTIONARY:
		layout_rects = layout_rects_value
	for offer_value in environment.item_offers:
		if typeof(offer_value) != TYPE_DICTIONARY:
			continue
		var offer: Dictionary = offer_value
		var item_id := str(offer.get("id", ""))
		if not item_id.is_empty() and not layout_rects.has("item:%s" % item_id):
			failures.append("The first generated home should place starter item %s in the room layout." % item_id)
			break
	if not layout_rects.has("home_tenure:status"):
		failures.append("The first generated home should expose the tenure object.")
	if not layout_rects.has("home_sleep:bed"):
		failures.append("The first generated home should expose the sleep object on its bed.")
	if not layout_rects.has("home_storage:place"):
		failures.append("The first generated home should expose the storage placement object.")
	if environment.next_archetypes.is_empty() and environment.travel_hooks.is_empty():
		failures.append("The first generated home should offer a route onward into the world.")
	if not run_state.home_is_active():
		failures.append("The first generated home should initialize RunState home_state.")
	if run_state.clock_display_text(true) != "Day 1 12 PM":
		failures.append("The first generated home should start at the fixed day 1, 12 PM clock.")
	var sleep_run: RunState = RunStateScript.new()
	sleep_run.from_dict(run_state.to_dict())
	sleep_run.add_suspicion("home_sleep_fixture", 30)
	sleep_run.change_drunk(70)
	sleep_run.drink_alcohol(12)
	var deterministic_sleep_run: RunState = RunStateScript.new()
	deterministic_sleep_run.from_dict(sleep_run.to_dict())
	var sleep_clock_before := sleep_run.game_clock_minutes
	var sleep_heat_before := sleep_run.suspicion_level()
	var sleep_drunk_before := sleep_run.drunk_level
	var sleep_result := sleep_run.sleep_at_home()
	var deterministic_sleep_result := deterministic_sleep_run.sleep_at_home()
	var sleep_hours := int(sleep_result.get("hours", 0))
	if not bool(sleep_result.get("ok", false)) or sleep_hours < RunState.HOME_SLEEP_MIN_HOURS or sleep_hours > RunState.HOME_SLEEP_MAX_HOURS:
		failures.append("Home sleep did not resolve within the authored four-to-eight-hour range.")
	if sleep_run.game_clock_minutes - sleep_clock_before != sleep_hours * 60:
		failures.append("Home sleep did not advance the clock by its resolved whole-hour duration.")
	if sleep_run.suspicion_level() >= sleep_heat_before or sleep_run.drunk_level >= sleep_drunk_before:
		failures.append("Home sleep did not lower both heat and drunk level.")
	if sleep_run.pending_drunk_absorption_amount() != 0:
		failures.append("Home sleep left queued alcohol absorption active after several hours.")
	if int(deterministic_sleep_result.get("hours", 0)) != sleep_hours:
		failures.append("Home sleep duration was not deterministic from saved run RNG state.")


func _check_environment_encounter_freshness(library: ContentLibrary, failures: Array) -> void:
	var back_alley := _archetype_by_id(library, "back_alley")
	if back_alley.is_empty():
		failures.append("Encounter freshness fixture is missing the back_alley archetype.")
		return
	var lender_pool := _string_array(back_alley.get("lender_hooks", []))
	if lender_pool.size() < 2:
		failures.append("Encounter freshness fixture expects Back Alley to expose at least two non-pawn-shop lender hooks.")
		return
	var composition_keys := {}
	var staging_keys := {}
	var all_lenders_count := 0
	for sample_index in range(18):
		var run_state: RunState = RunStateScript.new()
		run_state.start_new("ENCOUNTER-FRESH-%02d" % sample_index)
		var environment := EnvironmentInstance.from_archetype(back_alley, sample_index, run_state.create_rng("encounter_freshness"), library)
		if environment.lender_hooks.is_empty():
			failures.append("Encounter freshness generated Back Alley without any lender hook.")
			continue
		if environment.lender_hooks.size() >= lender_pool.size():
			all_lenders_count += 1
		composition_keys[JSON.stringify({
			"events": environment.event_ids,
			"lenders": environment.lender_hooks,
		})] = true
		staging_keys[_environment_encounter_staging_key(environment.to_dict())] = true
		var repeat_state: RunState = RunStateScript.new()
		repeat_state.start_new("ENCOUNTER-FRESH-%02d" % sample_index)
		var repeated := EnvironmentInstance.from_archetype(back_alley, sample_index, repeat_state.create_rng("encounter_freshness"), library)
		if JSON.stringify(repeated.to_dict()) != JSON.stringify(environment.to_dict()):
			failures.append("Encounter freshness generation is not deterministic for sample %d." % sample_index)
	if all_lenders_count > 0:
		failures.append("Back Alley should not spawn every lender hook in a fresh generated visit.")
	if composition_keys.size() < 3:
		failures.append("Back Alley encounter composition did not vary across deterministic samples.")
	if staging_keys.size() < 3:
		failures.append("Back Alley encounter staging did not vary across deterministic samples.")


func _environment_encounter_staging_key(environment_data: Dictionary) -> String:
	var layout: Dictionary = environment_data.get("layout", {}) if typeof(environment_data.get("layout", {})) == TYPE_DICTIONARY else {}
	var object_rects: Dictionary = layout.get("object_rects", {}) if typeof(layout.get("object_rects", {})) == TYPE_DICTIONARY else {}
	var parts: Array = []
	for object_id_value in object_rects.keys():
		var object_id := str(object_id_value)
		if not object_id.begins_with("event:") and not object_id.begins_with("lender:"):
			continue
		var rect := _layout_rect_from_dict(object_rects.get(object_id, {}))
		var center := _layout_rect_center_board(rect)
		parts.append("%s@%d,%d" % [object_id, roundi(center.x), roundi(center.y)])
	parts.sort()
	return "|".join(parts)


func _check_environment_game_pool_distribution(library: ContentLibrary, failures: Array) -> void:
	var placed_by_game := {}
	var non_rare_placed_by_game := {}
	for archetype_value in library.environment_archetypes:
		if typeof(archetype_value) != TYPE_DICTIONARY:
			continue
		var archetype: Dictionary = archetype_value
		var archetype_id := str(archetype.get("id", ""))
		var game_pool := _string_array(archetype.get("game_pool", []))
		var required_games := _string_array(archetype.get("required_game_ids", []))
		var is_rare := str(archetype.get("rarity", "")).to_lower() == "rare"
		var game_count_ceiling := _item_count_ceiling(archetype.get("game_count", 0))
		if game_pool.is_empty():
			if game_count_ceiling > 0:
				failures.append("Environment %s has no game_pool but requests game_count %d." % [archetype_id, game_count_ceiling])
			continue
		if game_count_ceiling <= 0:
			failures.append("Environment %s has game_pool options but never requests games." % archetype_id)
		for game_id in game_pool:
			placed_by_game[game_id] = true
			if not is_rare:
				non_rare_placed_by_game[game_id] = true
		for required_id in required_games:
			if not game_pool.has(required_id):
				failures.append("Environment %s requires %s but does not include it in game_pool." % [archetype_id, required_id])
			if game_count_ceiling < required_games.size():
				failures.append("Environment %s game_count cannot fit all required games." % archetype_id)
		var seen_generated := {}
		for sample_index in range(12):
			var sample_run: RunState = RunStateScript.new()
			sample_run.start_new("POOL-%s-%02d" % [archetype_id.to_upper(), sample_index])
			var sample_environment := EnvironmentInstance.from_archetype(archetype, sample_index, sample_run.create_rng("game_pool_distribution"), library)
			var generated_games := _string_array(sample_environment.game_ids)
			for required_id in required_games:
				if not generated_games.has(required_id):
					failures.append("Environment %s failed to generate required game %s." % [archetype_id, required_id])
			for generated_game_id in generated_games:
				seen_generated[generated_game_id] = true
		if game_count_ceiling >= game_pool.size():
			for game_id in game_pool:
				if not bool(seen_generated.get(game_id, false)):
					failures.append("Environment %s did not generate declared game option %s." % [archetype_id, game_id])

	for game_value in library.games:
		if typeof(game_value) != TYPE_DICTIONARY:
			continue
		var game_id := str((game_value as Dictionary).get("id", ""))
		if game_id.is_empty():
			continue
		if not bool(placed_by_game.get(game_id, false)):
			failures.append("Game %s is defined but absent from every environment game_pool." % game_id)
		elif not bool(non_rare_placed_by_game.get(game_id, false)):
			failures.append("Game %s only appears in rare environment game pools." % game_id)


func _check_high_risk_table_limit_overrides(library: ContentLibrary, failures: Array) -> void:
	var expected := {
		"small_underground_casino": {"blackjack": 60},
		"delta_queen": {"blackjack": 80, "roulette": 100},
		"kitty_cat_lounge": {"roulette": 90},
		"grand_casino": {"roulette": 150},
	}
	var blackjack: GameModule = _load_surface_contract_game(library, "blackjack", failures)
	var roulette: GameModule = _load_surface_contract_game(library, "roulette", failures)
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("TABLE-LIMITS")
	run_state.bankroll = 1000
	for venue_id in expected.keys():
		var archetype := _archetype_by_id(library, str(venue_id))
		if archetype.is_empty():
			failures.append("High-risk table limit fixture is missing venue: %s." % str(venue_id))
			continue
		var profile: Dictionary = archetype.get("economic_profile", {}) if typeof(archetype.get("economic_profile", {})) == TYPE_DICTIONARY else {}
		var base_limit := int(profile.get("stake_ceiling", 0))
		var overrides: Dictionary = profile.get("game_stake_ceiling_overrides", {}) if typeof(profile.get("game_stake_ceiling_overrides", {})) == TYPE_DICTIONARY else {}
		var venue_expected: Dictionary = expected.get(venue_id, {})
		for game_id in venue_expected.keys():
			var expected_limit := int(venue_expected.get(game_id, 0))
			if int(overrides.get(game_id, 0)) != expected_limit:
				failures.append("%s should set %s table limit to %d." % [str(venue_id), str(game_id), expected_limit])
			if GameModule.stake_ceiling_for_game({"economic_profile": profile}, str(game_id), run_state.bankroll) != expected_limit:
				failures.append("%s %s override did not resolve through GameModule.stake_ceiling_for_game." % [str(venue_id), str(game_id)])
			if expected_limit <= base_limit:
				failures.append("%s %s override should raise the base venue limit." % [str(venue_id), str(game_id)])
		if blackjack != null and venue_expected.has("blackjack"):
			var blackjack_actions := blackjack.actions(run_state, {"economic_profile": profile})
			if int(blackjack_actions.get("base_stake_ceiling", 0)) != int(venue_expected.get("blackjack", 0)):
				failures.append("%s blackjack action view did not expose the raised table limit." % str(venue_id))
		if roulette != null and venue_expected.has("roulette"):
			var roulette_environment := {
				"economic_profile": profile,
				"security_profile": {},
				"depth": int(archetype.get("tier", 0)),
			}
			var roulette_table := roulette.generate_environment_state(run_state, roulette_environment, run_state.create_rng("roulette_limits:%s" % str(venue_id)))
			var rules: Dictionary = roulette_table.get("rules", {}) if typeof(roulette_table.get("rules", {})) == TYPE_DICTIONARY else {}
			if int(rules.get("table_max", 0)) != int(venue_expected.get("roulette", 0)):
				failures.append("%s roulette table did not generate the raised table max." % str(venue_id))
			var chips := _copy_array(roulette_table.get("chip_denominations", []))
			if int(venue_expected.get("roulette", 0)) >= 100 and not chips.has(50):
				failures.append("%s roulette high-limit table should expose a $50 chip." % str(venue_id))
			if int(venue_expected.get("roulette", 0)) >= 150 and not chips.has(100):
				failures.append("%s roulette top-limit table should expose a $100 chip." % str(venue_id))
	var grand_main := _archetype_by_id(library, "grand_casino")
	var grand_high := _archetype_by_id(library, "grand_casino_high_limit")
	var main_profile: Dictionary = grand_main.get("economic_profile", {}) if typeof(grand_main.get("economic_profile", {})) == TYPE_DICTIONARY else {}
	var main_overrides: Dictionary = main_profile.get("game_stake_ceiling_overrides", {}) if typeof(main_profile.get("game_stake_ceiling_overrides", {})) == TYPE_DICTIONARY else {}
	var high_profile: Dictionary = grand_high.get("economic_profile", {}) if typeof(grand_high.get("economic_profile", {})) == TYPE_DICTIONARY else {}
	if int(main_profile.get("stake_floor", 0)) != 5 or int(main_profile.get("stake_ceiling", 0)) != 35 or main_overrides.has("blackjack"):
		failures.append("Grand Casino Main Floor blackjack should use the public $5-$35 limits without a high-limit override.")
	if GameModule.stake_ceiling_for_game({"economic_profile": main_profile}, "blackjack", run_state.bankroll) != 35:
		failures.append("Grand Casino Main Floor blackjack did not resolve its $35 public table ceiling.")
	if blackjack != null:
		var main_blackjack_actions := blackjack.actions(run_state, {"economic_profile": main_profile})
		if int(main_blackjack_actions.get("base_stake_ceiling", 0)) != 35:
			failures.append("Grand Casino Main Floor blackjack action view did not expose its $35 public table ceiling.")
	if GameModule.stake_ceiling_for_game({"economic_profile": high_profile}, "blackjack", run_state.bankroll) != 150:
		failures.append("Grand Casino High-Limit Room blackjack did not preserve its $150 table ceiling.")


func _check_environment_open_hours(library: ContentLibrary, failures: Array) -> void:
	var expected_hours := {
		"corner_store": {"open_minute": 360, "close_minute": 60},
		"bar": {"open_minute": 660, "close_minute": 180},
		"kitty_cat_lounge": {"open_minute": 780, "close_minute": 300},
		"jazz_club": {"open_minute": 1020, "close_minute": 180},
		"delta_queen": {"open_minute": 540, "close_minute": 180},
	}
	for archetype_value in library.environment_archetypes:
		if typeof(archetype_value) != TYPE_DICTIONARY:
			continue
		var archetype: Dictionary = archetype_value
		var archetype_id := str(archetype.get("id", "")).strip_edges()
		if not archetype_id.is_empty() and not archetype.has("open_hours"):
			failures.append("Environment %s must declare open_hours or explicit null." % archetype_id)
	for archetype_id in expected_hours.keys():
		var archetype := _archetype_by_id(library, str(archetype_id))
		var hours: Dictionary = archetype.get("open_hours", {}) if typeof(archetype.get("open_hours", {})) == TYPE_DICTIONARY else {}
		var expected: Dictionary = expected_hours.get(archetype_id, {})
		if int(hours.get("open_minute", -1)) != int(expected.get("open_minute", -2)) or int(hours.get("close_minute", -1)) != int(expected.get("close_minute", -2)):
			failures.append("Environment %s open_hours do not match the authored schedule." % str(archetype_id))
	var corner_store := _archetype_by_id(library, "corner_store")
	if not EnvironmentHoursScript.environment_open_at(corner_store, 360):
		failures.append("corner_store should be open at 6 AM.")
	if not EnvironmentHoursScript.environment_open_at(corner_store, 0):
		failures.append("corner_store should remain open at midnight before its 1 AM close.")
	if EnvironmentHoursScript.environment_open_at(corner_store, 60):
		failures.append("corner_store should close exactly at 1 AM.")
	if EnvironmentHoursScript.environment_open_at(corner_store, 300):
		failures.append("corner_store should stay closed before 6 AM.")
	var motel := _archetype_by_id(library, "motel")
	if not EnvironmentHoursScript.environment_open_at(motel, 0) or not EnvironmentHoursScript.environment_open_at(motel, 720):
		failures.append("motel should be open 24h.")
	var jazz := _archetype_by_id(library, "jazz_club")
	if not EnvironmentHoursScript.environment_open_at(jazz, 17 * 60) or not EnvironmentHoursScript.environment_open_at(jazz, 2 * 60):
		failures.append("jazz_club should use wrap-around evening hours.")
	if EnvironmentHoursScript.environment_open_at(jazz, 12 * 60):
		failures.append("jazz_club should be closed at noon.")


func _check_dialogue_system_content(library: ContentLibrary, failures: Array) -> void:
	for dialogue_id in ["pull_tab_clerk", "late_shift_discount", "chatty_clerk"]:
		var dialogue := library.dialogue(dialogue_id)
		if dialogue.is_empty():
			failures.append("Dialogue pack is missing %s." % dialogue_id)
			continue
		if str(dialogue.get("start", "")).strip_edges().is_empty():
			failures.append("Dialogue %s is missing a start node." % dialogue_id)
	var late_event := library.event("late_shift_discount")
	if str(late_event.get("dialogue_id", "")) != "late_shift_discount":
		failures.append("late_shift_discount event did not migrate to a dialogue_id.")
	var chatty_event := library.event("chatty_clerk")
	if str(chatty_event.get("dialogue_id", "")) != "chatty_clerk":
		failures.append("chatty_clerk event did not migrate to a dialogue_id.")
	var bad_library: ContentLibrary = ContentLibraryScript.new()
	bad_library.dialogues = [{
		"id": "bad_goto_fixture",
		"speaker": {"role": "staff", "name": "Fixture"},
		"start": "start",
		"nodes": {
			"start": {
				"text": "Bad edge.",
				"choices": [{"id": "bad", "label": "Bad", "goto": "missing", "effects": {}}],
			},
		},
	}]
	bad_library.travel_routes = library.travel_routes.duplicate(true)
	bad_library.validation_errors = []
	bad_library._validate_dialogue_definitions()
	var saw_bad_goto := false
	for error_value in bad_library.validation_errors:
		if str(error_value).find("missing goto") >= 0:
			saw_bad_goto = true
			break
	if not saw_bad_goto:
		failures.append("Dialogue validation did not reject a bad goto target.")


func _check_content_validation_boot_surfacing(library: ContentLibrary, failures: Array) -> void:
	var debug_snapshot := library.debug_soak_snapshot()
	if int(debug_snapshot.get("validation_errors", -1)) != library.validation_errors.size():
		failures.append("ContentLibrary debug stats did not expose validation error count.")
	var bad_library: ContentLibrary = ContentLibraryScript.new()
	bad_library.games = [{"id": "bad_boot_surface_game"}]
	bad_library.validate()
	if bad_library.validation_errors.is_empty():
		failures.append("Bad injected content pack did not produce validation errors.")
		return
	var app_value: Variant = MainScene.instantiate()
	if not app_value is Control:
		failures.append("Content validation surfacing fixture could not instantiate FoundationMain.")
		return
	var app: Control = app_value
	root.add_child(app)
	if not bool(app.call("uses_foundation_runtime")):
		app.call("_ready")
	var surface_state: Dictionary = app.call("debug_surface_content_validation_errors", bad_library, false)
	if int(surface_state.get("error_count", 0)) != bad_library.validation_errors.size():
		failures.append("Content validation surfacing did not report the injected error count.")
	app.call("_refresh_start_screen")
	var label: Label = app.get("start_status_label")
	if OS.is_debug_build() and (label == null or label.text.find("Content validation:") == -1 or label.text.find("see console") == -1):
		failures.append("Content validation surfacing did not paint the debug start-screen banner.")
	_sb4_dispose_app(app)


func _check_talk_content_pass_content(library: ContentLibrary, failures: Array) -> void:
	var table_events := {
		"blackjack_counter_probe": "blackjack",
		"roulette_lucky_regular": "roulette",
		"baccarat_off_duty_dealer": "baccarat",
		"video_poker_neighbor": "video_poker",
		"bar_dice_tipsy_braggart": "bar_dice",
		"pull_tabs_friendly_local": "pull_tabs",
	}
	for event_id_value in table_events.keys():
		var event_id := str(event_id_value)
		var game_id := str(table_events[event_id_value])
		var event := library.event(event_id)
		if event.is_empty():
			failures.append("Talk content pass is missing table approach event: %s." % event_id)
			continue
		_check_talk_content_event_shape(event, event_id, "table_approach", failures)
		var trigger: Dictionary = event.get("trigger", {}) if typeof(event.get("trigger", {})) == TYPE_DICTIONARY else {}
		var games := _string_array(trigger.get("games", []))
		if games != [game_id]:
			failures.append("Talk content table approach %s must target only %s." % [event_id, game_id])
		var run_state: RunState = RunStateScript.new()
		run_state.start_new("TALK-CONTENT-%s" % event_id)
		run_state.set_environment(_t4_3_fixture_environment("talk_%s" % game_id, "casino", 2, [game_id], [], ["bar"]))
		var event_module := EventModule.new()
		event_module.setup(event, library)
		var context := {
			"trigger": "table_approach",
			"type": "table_approach",
			"game_id": game_id,
			"hands_played": int(trigger.get("min_hands", 0)),
		}
		if not event_module.can_trigger(run_state, run_state.current_environment, context):
			failures.append("Talk content table approach %s did not trigger for %s." % [event_id, game_id])
		context["game_id"] = "roulette" if game_id != "roulette" else "blackjack"
		if event_module.can_trigger(run_state, run_state.current_environment, context):
			failures.append("Talk content table approach %s triggered for the wrong game." % event_id)

	var heat_events := {
		"floor_staff_heat_warning": 65,
		"pit_boss_heat_warning": 85,
	}
	for event_id_value in heat_events.keys():
		var heat_event_id := str(event_id_value)
		var threshold := int(heat_events[event_id_value])
		var event := library.event(heat_event_id)
		if event.is_empty():
			failures.append("Talk content pass is missing heat threshold event: %s." % heat_event_id)
			continue
		_check_talk_content_event_shape(event, heat_event_id, "heat_threshold", failures)
		var trigger: Dictionary = event.get("trigger", {}) if typeof(event.get("trigger", {})) == TYPE_DICTIONARY else {}
		if int(trigger.get("level", 0)) != threshold:
			failures.append("Talk content heat event %s must trigger at %d." % [heat_event_id, threshold])
		var run_state: RunState = RunStateScript.new()
		run_state.start_new("TALK-HEAT-%s" % heat_event_id)
		run_state.set_environment(_t4_3_fixture_environment("talk_heat", "casino", 2, ["blackjack"], [], ["bar"]))
		run_state.add_suspicion("talk_content_fixture", threshold, "behavior")
		var event_module := EventModule.new()
		event_module.setup(event, library)
		var context := {
			"trigger": "heat_threshold",
			"type": "heat_threshold",
			"threshold": threshold,
			"previous_suspicion": threshold - 3,
			"current_suspicion": threshold,
		}
		if not event_module.can_trigger(run_state, run_state.current_environment, context):
			failures.append("Talk content heat threshold event %s did not trigger at %d." % [heat_event_id, threshold])

	for migrated_event_id in [
		"suspicious_patron",
		"motel_knock",
		"rival_counter",
		"counter_payoff",
		"snitch_reputation",
		"on_the_house",
		"the_collector",
		"shift_change",
		"whale_sighting",
		"staff_shift_tip",
	]:
		var event := library.event(migrated_event_id)
		if event.is_empty():
			failures.append("Talk content migrated event is missing: %s." % migrated_event_id)
			continue
		if str(event.get("presentation", "")) != "talk":
			failures.append("Talk content migrated event %s is not presentation=talk." % migrated_event_id)
		var speaker: Dictionary = event.get("speaker", {}) if typeof(event.get("speaker", {})) == TYPE_DICTIONARY else {}
		if str(speaker.get("name", "")).strip_edges().is_empty():
			failures.append("Talk content migrated event %s is missing a speaker name." % migrated_event_id)

	_check_talk_content_resolve_delta(library, "suspicious_patron", "talk_down", 0, -3, failures)
	_check_talk_content_resolve_delta(library, "motel_knock", "borrow", 35, 0, failures)
	_check_talk_content_resolve_delta(library, "the_collector", "pay_now", -20, -2, failures)


func _check_talk_content_event_shape(event: Dictionary, event_id: String, trigger_type: String, failures: Array) -> void:
	if str(event.get("interaction_mode", "")) != "triggered":
		failures.append("Talk content event %s must be triggered." % event_id)
	if str(event.get("presentation", "")) != "talk":
		failures.append("Talk content event %s must use talk presentation." % event_id)
	var speaker: Dictionary = event.get("speaker", {}) if typeof(event.get("speaker", {})) == TYPE_DICTIONARY else {}
	if str(speaker.get("role", "")).strip_edges().is_empty() or str(speaker.get("silhouette", "")).strip_edges().is_empty():
		failures.append("Talk content event %s is missing a usable speaker snapshot." % event_id)
	var trigger: Dictionary = event.get("trigger", {}) if typeof(event.get("trigger", {})) == TYPE_DICTIONARY else {}
	if str(trigger.get("type", "")) != trigger_type:
		failures.append("Talk content event %s must use %s trigger." % [event_id, trigger_type])
	var payload: Dictionary = event.get("payload", {}) if typeof(event.get("payload", {})) == TYPE_DICTIONARY else {}
	var choices: Array = payload.get("choices", []) if typeof(payload.get("choices", [])) == TYPE_ARRAY else []
	if choices.size() < 2 or choices.size() > 3:
		failures.append("Talk content event %s must expose 2-3 choices." % event_id)


func _check_talk_content_resolve_delta(library: ContentLibrary, event_id: String, choice_id: String, expected_bankroll_delta: int, expected_suspicion_delta: int, failures: Array) -> void:
	var event := library.event(event_id)
	if event.is_empty():
		return
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("TALK-PARITY-%s" % event_id)
	run_state.set_environment(_t4_3_fixture_environment("talk_parity", "casino", 2, ["blackjack"], [], ["bar"]))
	if expected_suspicion_delta < 0:
		run_state.add_suspicion("talk_parity_start", 20, "behavior")
	var event_module := EventModule.new()
	event_module.setup(event, library)
	var result: Dictionary = event_module.resolve(run_state, run_state.current_environment, choice_id)
	var deltas: Dictionary = result.get("deltas", {}) if typeof(result.get("deltas", {})) == TYPE_DICTIONARY else {}
	if int(result.get("bankroll_delta", deltas.get("bankroll_delta", 0))) != expected_bankroll_delta:
		failures.append("Talk content migrated event %s/%s changed bankroll consequence." % [event_id, choice_id])
	if int(result.get("suspicion_delta", deltas.get("suspicion_delta", 0))) != expected_suspicion_delta:
		failures.append("Talk content migrated event %s/%s changed heat consequence." % [event_id, choice_id])


func _check_t4_3_event_pack(library: ContentLibrary, failures: Array) -> void:
	var required_event_ids := [
		"health_inspector",
		"inspector_return",
		"rival_counter",
		"counter_payoff",
		"snitch_reputation",
		"on_the_house",
		"the_collector",
		"shift_change",
		"lights_out",
		"lights_out_return",
		"whale_sighting",
		"staff_shift_tip",
		"lay_low_booth",
		"door_bribe",
		"lucky_streak_temptation",
		"crew_favor_delivery",
	]
	var seen_event_ids := {}
	for event_value in library.events:
		if typeof(event_value) != TYPE_DICTIONARY:
			continue
		var event_data: Dictionary = event_value
		var event_id := str(event_data.get("id", ""))
		if bool(seen_event_ids.get(event_id, false)):
			failures.append("Duplicate event id found in T4.3 event audit: %s." % event_id)
		seen_event_ids[event_id] = true
	for event_id in required_event_ids:
		var event_def := library.event(event_id)
		if event_def.is_empty():
			failures.append("T4.3 event is missing: %s." % event_id)
			continue
		var trigger: Dictionary = event_def.get("trigger", {}) if typeof(event_def.get("trigger", {})) == TYPE_DICTIONARY else {}
		if str(trigger.get("type", "")) != "random" or not bool(trigger.get("unavoidable", false)):
			failures.append("T4.3 event %s should be a random unavoidable room interruption." % event_id)

	var thermos := library.item("thermos_black_coffee")
	var half_thermos := library.item("thermos_black_coffee_half")
	if thermos.is_empty() or half_thermos.is_empty():
		failures.append("Thermos of Black Coffee item or second-use state is missing.")
	else:
		_check_t4_3_thermos_item(library, thermos, failures)

	_check_t4_3_event_conditions(library, failures)
	_check_t4_3_event_chains_and_checks(library, failures)
	_check_t4_3_watch_modifiers(failures)
	_check_t4_3_event_pool_reachability(library, required_event_ids, failures)


func _check_t4_3_thermos_item(library: ContentLibrary, thermos: Dictionary, failures: Array) -> void:
	if not library.item_enabled_for_challenge("thermos_black_coffee", {}):
		failures.append("Thermos of Black Coffee is not enabled by default content groups.")
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("T43-THERMOS")
	run_state.set_environment(_t4_3_fixture_environment("corner_store", "shop", 1, [], [], ["bar"]))
	run_state.add_item("thermos_black_coffee")
	run_state.set_active_item("thermos_black_coffee")
	run_state.change_drunk(48)
	run_state.change_pending_drunk_absorption(24)
	var before_drunk := run_state.drunk_level
	var before_pending := run_state.pending_drunk_absorption_amount()
	var item_effect := ItemEffect.new()
	item_effect.setup(thermos)
	var result := item_effect.apply({
		"domain": "global",
		"domains": ["global"],
		"action_id": "use_active_item",
		"action_kind": "item",
	})
	GameModule.apply_result(run_state, result)
	if run_state.drunk_level >= before_drunk:
		failures.append("Thermos did not reduce current drunk level.")
	if run_state.pending_drunk_absorption_amount() >= before_pending:
		failures.append("Thermos did not reduce pending drink absorption.")
	if not run_state.drunk_distortion_suppressed():
		failures.append("Thermos did not suppress drunk distortion.")
	if run_state.inventory.has("thermos_black_coffee") or not run_state.inventory.has("thermos_black_coffee_half"):
		failures.append("Thermos did not convert to its half-use inventory state.")
	var saved := run_state.to_dict()
	var loaded: RunState = RunStateScript.new()
	loaded.from_dict(saved)
	if not loaded.inventory.has("thermos_black_coffee_half") or not loaded.drunk_distortion_suppressed():
		failures.append("Thermos state did not survive RunState round-trip.")
	var suppression_before_decay := loaded.drunk_distortion_suppression_turns
	loaded.advance_environment_turns(1)
	if loaded.drunk_distortion_suppression_turns >= suppression_before_decay:
		failures.append("Thermos distortion suppression timer did not decay by environment action.")


func _check_t4_3_event_conditions(library: ContentLibrary, failures: Array) -> void:
	var action_context := {"trigger": "action", "turns": 2}
	var bar_run: RunState = RunStateScript.new()
	bar_run.start_new("T43-HEALTH")
	bar_run.set_environment(_t4_3_fixture_environment("bar", "casino", 1, ["pull_tabs"], ["health_inspector"], ["corner_store"]))
	var health_event := EventModule.new()
	health_event.setup(library.event("health_inspector"))
	if not health_event.can_trigger(bar_run, bar_run.current_environment, action_context):
		failures.append("Health Inspector did not trigger in the bar action context.")
	var motel_run: RunState = RunStateScript.new()
	motel_run.start_new("T43-HEALTH-MOTEL")
	motel_run.set_environment(_t4_3_fixture_environment("motel", "shop", 1, [], ["health_inspector"], ["bar"]))
	if health_event.can_trigger(motel_run, motel_run.current_environment, action_context):
		failures.append("Health Inspector triggered outside the bar archetype.")

	var blackjack_run: RunState = RunStateScript.new()
	blackjack_run.start_new("T43-RIVAL")
	blackjack_run.set_environment(_t4_3_fixture_environment("delta_queen", "casino", 2, ["blackjack", "roulette"], ["rival_counter"], ["grand_casino"]))
	var rival_event := EventModule.new()
	rival_event.setup(library.event("rival_counter"))
	if not rival_event.can_trigger(blackjack_run, blackjack_run.current_environment, action_context):
		failures.append("Rival Counter did not trigger at a blackjack venue.")
	var no_blackjack_run: RunState = RunStateScript.new()
	no_blackjack_run.start_new("T43-RIVAL-NO-BJ")
	no_blackjack_run.set_environment(_t4_3_fixture_environment("kitty_cat_lounge", "casino", 2, ["bar_dice"], ["rival_counter"], ["bar"]))
	if rival_event.can_trigger(no_blackjack_run, no_blackjack_run.current_environment, action_context):
		failures.append("Rival Counter triggered without blackjack in the room.")

	var host_run: RunState = RunStateScript.new()
	host_run.start_new("T43-HOST")
	host_run.set_environment(_t4_3_fixture_environment("kitty_cat_lounge", "casino", 2, ["roulette"], ["on_the_house"], ["grand_casino"]))
	var host_event := EventModule.new()
	host_event.setup(library.event("on_the_house"))
	if not host_event.can_trigger(host_run, host_run.current_environment, action_context):
		failures.append("On the House did not trigger in tier-2 casino context.")
	if _event_choice_id_exists(host_event.choices(host_run, host_run.current_environment), "coffee_swap"):
		failures.append("On the House exposed the Thermos choice without the Thermos item.")
	host_run.add_item("thermos_black_coffee")
	if not _event_choice_id_exists(host_event.choices(host_run, host_run.current_environment), "coffee_swap"):
		failures.append("On the House did not expose the Thermos item-conditioned choice.")

	var collector_run: RunState = RunStateScript.new()
	collector_run.start_new("T43-COLLECTOR-CLEAN")
	collector_run.set_environment(_t4_3_fixture_environment("motel", "shop", 1, [], ["the_collector"], ["bar"]))
	var collector_event := EventModule.new()
	collector_event.setup(library.event("the_collector"))
	if collector_event.can_trigger(collector_run, collector_run.current_environment, action_context):
		failures.append("The Collector triggered without overdue debt.")
	collector_run.add_debt({"id": "overdue_fixture", "lender_id": "street_lender", "balance": 30, "status": "overdue"})
	if not collector_event.can_trigger(collector_run, collector_run.current_environment, action_context):
		failures.append("The Collector did not trigger with overdue debt.")


func _check_t4_3_event_chains_and_checks(library: ContentLibrary, failures: Array) -> void:
	var action_context := {"trigger": "action", "turns": 2}
	var rival_run: RunState = RunStateScript.new()
	rival_run.start_new("T43-RIVAL-CHAIN")
	rival_run.set_environment(_t4_3_fixture_environment("delta_queen", "casino", 2, ["blackjack"], ["rival_counter", "counter_payoff"], ["grand_casino"]))
	var rival_event := EventModule.new()
	rival_event.setup(library.event("rival_counter"))
	var rival_result := rival_event.resolve(rival_run, rival_run.current_environment, "tip_off")
	_check_event_result_delta_shape(rival_result, failures)
	if not bool(rival_run.narrative_flags.get("rival_counter_owes_you", false)):
		failures.append("Rival Counter tip-off did not plant its payoff flag.")
	var loaded: RunState = RunStateScript.new()
	loaded.from_dict(rival_run.to_dict())
	var payoff_event := EventModule.new()
	payoff_event.setup(library.event("counter_payoff"))
	if not payoff_event.can_trigger(loaded, loaded.current_environment, action_context):
		failures.append("Counter Payoff did not trigger from the saved rival-counter flag.")

	var collector_run_a: RunState = RunStateScript.new()
	var collector_run_b: RunState = RunStateScript.new()
	collector_run_a.start_new("T43-COLLECTOR-CHECK")
	collector_run_b.start_new("T43-COLLECTOR-CHECK")
	var collector_environment := _t4_3_fixture_environment("motel", "shop", 1, [], ["the_collector"], ["bar"])
	collector_run_a.set_environment(collector_environment)
	collector_run_b.set_environment(collector_environment)
	collector_run_a.add_debt({"id": "overdue_fixture", "lender_id": "street_lender", "balance": 30, "status": "overdue"})
	collector_run_b.add_debt({"id": "overdue_fixture", "lender_id": "street_lender", "balance": 30, "status": "overdue"})
	var collector_a := EventModule.new()
	var collector_b := EventModule.new()
	collector_a.setup(library.event("the_collector"))
	collector_b.setup(library.event("the_collector"))
	var result_a := collector_a.resolve(collector_run_a, collector_run_a.current_environment, "stand_ground")
	var result_b := collector_b.resolve(collector_run_b, collector_run_b.current_environment, "stand_ground")
	_check_event_result_delta_shape(result_a, failures)
	if JSON.stringify(result_a) != JSON.stringify(result_b):
		failures.append("The Collector checked consequence was not deterministic.")
	if not _story_log_has_type(collector_run_a.story_log, "event_check"):
		failures.append("The Collector checked consequence did not record event_check story context.")


func _check_t4_3_watch_modifiers(failures: Array) -> void:
	var watch_run: RunState = RunStateScript.new()
	watch_run.start_new("T43-WATCH-MODIFIERS")
	watch_run.set_environment(_t4_3_fixture_environment("grand_casino", "boss", 3, ["roulette"], ["shift_change", "lights_out"], ["motel"]))
	watch_run.current_environment["security_profile"] = {
		"pit_boss": {"enabled": true, "cycle_length": 2, "watched_turns": 1, "cheat_heat_bonus": 24, "label": "Rourke"},
	}
	watch_run.current_environment["turns"] = 0
	var base_status := watch_run.pit_boss_watch_status(watch_run.current_environment)
	watch_run.narrative_flags["shift_change_rookie_actions"] = 3
	var shifted_status := watch_run.pit_boss_watch_status(watch_run.current_environment)
	if int(shifted_status.get("cheat_heat_bonus", 0)) >= int(base_status.get("cheat_heat_bonus", 0)):
		failures.append("Shift Change did not visibly reduce watched cheat heat.")
	watch_run.narrative_flags["lights_out_unwatched_actions"] = 1
	var dark_status := watch_run.pit_boss_watch_status(watch_run.current_environment)
	if bool(dark_status.get("watched", true)) or int(dark_status.get("cheat_heat_bonus", 1)) != 0:
		failures.append("Lights Out did not create one unwatched action.")
	watch_run.advance_environment_turns(1)
	if int(watch_run.narrative_flags.get("lights_out_unwatched_actions", 0)) != 0 or int(watch_run.narrative_flags.get("shift_change_rookie_actions", 0)) != 2:
		failures.append("T4.3 watch modifier timers did not decay after an environment action.")


func _check_t4_3_event_pool_reachability(library: ContentLibrary, required_event_ids: Array, failures: Array) -> void:
	var placed_events := {}
	for archetype_value in library.environment_archetypes:
		if typeof(archetype_value) != TYPE_DICTIONARY:
			continue
		var archetype: Dictionary = archetype_value
		for event_id in _string_array(archetype.get("event_pool", [])):
			if required_event_ids.has(event_id):
				placed_events[event_id] = true
	for event_id in required_event_ids:
		if not bool(placed_events.get(event_id, false)):
			failures.append("T4.3 event is not reachable from any environment pool: %s." % event_id)

	var required_interactable_ids: Array = []
	for event_id in required_event_ids:
		if str(library.event(event_id).get("interaction_mode", "")) == "interactable":
			required_interactable_ids.append(event_id)
	var generated_hits := {}
	var generated_counts := {}
	var total_t4_events := 0
	for archetype_id in ["bar", "small_underground_casino", "kitty_cat_lounge", "delta_queen", "grand_casino"]:
		var archetype := _archetype_by_id(library, archetype_id)
		if archetype.is_empty():
			failures.append("T4.3 generation fixture missing archetype: %s." % archetype_id)
			continue
		for sample_index in range(16):
			var sample_run: RunState = RunStateScript.new()
			sample_run.start_new("T43-EVENT-SPREAD-%s-%02d" % [archetype_id.to_upper(), sample_index])
			var sample_environment := EnvironmentInstance.from_archetype(archetype, sample_index, sample_run.create_rng("t43_event_spread"), library)
			for event_id in _string_array(sample_environment.event_ids):
				if required_interactable_ids.has(event_id):
					generated_hits[event_id] = true
					generated_counts[event_id] = int(generated_counts.get(event_id, 0)) + 1
					total_t4_events += 1
	if not required_interactable_ids.is_empty() and generated_hits.size() < mini(8, required_interactable_ids.size()):
		failures.append("Multi-seed generation did not sample enough T4.3 event variety; saw %d unique." % generated_hits.size())
	var max_repeat := 0
	for count_value in generated_counts.values():
		max_repeat = maxi(max_repeat, int(count_value))
	if total_t4_events >= 12 and max_repeat > int(ceil(float(total_t4_events) * 0.55)):
		failures.append("Multi-seed T4.3 event generation was dominated by one repeat.")


func _t4_3_fixture_environment(archetype_id: String, kind: String, tier: int, game_ids: Array, event_ids: Array, next_archetypes: Array) -> Dictionary:
	return {
		"id": "t43_%s_fixture" % archetype_id,
		"archetype_id": archetype_id,
		"display_name": archetype_id.capitalize(),
		"kind": kind,
		"tier": tier,
		"game_ids": game_ids.duplicate(true),
		"event_ids": event_ids.duplicate(true),
		"resolved_event_ids": [],
		"next_archetypes": next_archetypes.duplicate(true),
		"travel_hooks": next_archetypes.duplicate(true),
		"turns": 2,
		"security_profile": {
			"pit_boss": {"enabled": true, "cycle_length": 2, "watched_turns": 1, "cheat_heat_bonus": 20},
		},
		"economic_profile": {"stake_floor": 1, "stake_ceiling": 50},
	}


func _event_choice_id_exists(choices: Array, choice_id: String) -> bool:
	for choice_value in choices:
		if typeof(choice_value) == TYPE_DICTIONARY and str((choice_value as Dictionary).get("id", "")) == choice_id:
			return true
	return false


func _story_log_has_type(story_log: Array, entry_type: String) -> bool:
	for story_value in story_log:
		if typeof(story_value) == TYPE_DICTIONARY and str((story_value as Dictionary).get("type", "")) == entry_type:
			return true
	return false


func _check_t4_4_item_pack(library: ContentLibrary, failures: Array) -> void:
	var required_build_items := {
		"clean_grinder": ["ledger_pencil", "cashout_envelope"],
		"advantage_player": ["odds_notebook", "shoe_cut_marker"],
		"cheat_specialist": ["sleeve_rig", "false_bottom_cup"],
		"drunk_gambler": ["pickled_olive_jar", "lucky_bar_napkin"],
		"debt_surfer": ["payment_calendar", "pawn_receipt_sleeve"],
	}
	if library.items.size() < 59:
		failures.append("T4.4 should expand production item content to at least 59 items.")
	for build_id in required_build_items.keys():
		for item_id_value in required_build_items[build_id]:
			var item_id := str(item_id_value)
			var item := library.item(item_id)
			if item.is_empty():
				failures.append("T4.4 build item is missing: %s." % item_id)
				continue
			if not _string_array(item.get("build_tags", [])).has(str(build_id)):
				failures.append("T4.4 item %s does not declare build tag %s." % [item_id, str(build_id)])
			var effect: Dictionary = item.get("effect", {}) if typeof(item.get("effect", {})) == TYPE_DICTIONARY else {}
			if _copy_array(effect.get("synergies", [])).is_empty():
				failures.append("T4.4 item %s should declare a data-driven synergy." % item_id)
	_check_t4_4_item_effect_key_consumption(library, failures)
	_check_t4_4_item_shop_distribution(library, failures)
	_check_t4_4_item_synergy_math(failures)
	_check_t4_4_item_debt_modifiers(failures)
	_check_t4_4_item_action_round_trips(library, failures)


func _check_t4_4_item_effect_key_consumption(library: ContentLibrary, failures: Array) -> void:
	var consumed_keys := _t4_4_consumed_item_effect_keys()
	var item_ids := {}
	for item_value in library.items:
		if typeof(item_value) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = item_value
		var item_id := str(item.get("id", "")).strip_edges()
		if not item_id.is_empty():
			item_ids[item_id] = true
	for item_value in library.items:
		if typeof(item_value) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = item_value
		var item_id := str(item.get("id", "")).strip_edges()
		var effect: Dictionary = item.get("effect", {}) if typeof(item.get("effect", {})) == TYPE_DICTIONARY else {}
		_check_t4_4_item_effect_dictionary_keys("items %s effect" % item_id, effect, consumed_keys, item_ids, failures)


func _check_t4_4_item_effect_dictionary_keys(label: String, effect: Dictionary, consumed_keys: Dictionary, item_ids: Dictionary, failures: Array) -> void:
	for key_value in effect.keys():
		var key := str(key_value)
		var value: Variant = effect.get(key)
		if key == "families":
			if typeof(value) != TYPE_DICTIONARY:
				failures.append("%s families effect must be a dictionary." % label)
				continue
			for family_key in (value as Dictionary).keys():
				var family_effect: Variant = (value as Dictionary).get(family_key)
				if typeof(family_effect) != TYPE_DICTIONARY:
					failures.append("%s families.%s effect must be a dictionary." % [label, str(family_key)])
					continue
				_check_t4_4_item_effect_dictionary_keys("%s families.%s" % [label, str(family_key)], family_effect as Dictionary, consumed_keys, item_ids, failures)
		elif key == "synergies":
			_check_t4_4_item_synergy_schema(label, value, consumed_keys, item_ids, failures)
		elif not consumed_keys.has(key):
			failures.append("%s uses unconsumed effect key: %s." % [label, key])


func _check_t4_4_item_synergy_schema(label: String, value: Variant, consumed_keys: Dictionary, item_ids: Dictionary, failures: Array) -> void:
	if typeof(value) != TYPE_ARRAY:
		failures.append("%s synergies must be an array." % label)
		return
	var allowed_schema_keys := _lookup_from_array(["requires_all", "requires_any", "effects", "families"])
	var index := 0
	for synergy_value in value as Array:
		if typeof(synergy_value) != TYPE_DICTIONARY:
			failures.append("%s synergies[%d] must be a dictionary." % [label, index])
			index += 1
			continue
		var synergy: Dictionary = synergy_value
		for schema_key_value in synergy.keys():
			var schema_key := str(schema_key_value)
			if not allowed_schema_keys.has(schema_key):
				failures.append("%s synergies[%d] uses unknown schema key: %s." % [label, index, schema_key])
		for requirement_key in ["requires_all", "requires_any"]:
			for required_item_value in _string_array(synergy.get(requirement_key, [])):
				var required_item := str(required_item_value)
				if not item_ids.has(required_item):
					failures.append("%s synergies[%d] references missing item: %s." % [label, index, required_item])
		var effects: Dictionary = synergy.get("effects", {}) if typeof(synergy.get("effects", {})) == TYPE_DICTIONARY else {}
		if not effects.is_empty():
			_check_t4_4_item_effect_dictionary_keys("%s synergies[%d].effects" % [label, index], effects, consumed_keys, item_ids, failures)
		var families: Dictionary = synergy.get("families", {}) if typeof(synergy.get("families", {})) == TYPE_DICTIONARY else {}
		for family_key in families.keys():
			var family_effect: Variant = families.get(family_key)
			if typeof(family_effect) != TYPE_DICTIONARY:
				failures.append("%s synergies[%d].families.%s must be a dictionary." % [label, index, str(family_key)])
				continue
			_check_t4_4_item_effect_dictionary_keys("%s synergies[%d].families.%s" % [label, index, str(family_key)], family_effect as Dictionary, consumed_keys, item_ids, failures)
		index += 1


func _check_t4_4_item_shop_distribution(library: ContentLibrary, failures: Array) -> void:
	var expectations := [
		{"group": "universal_passive_items", "items": ["ledger_pencil", "cashout_envelope", "lucky_bar_napkin", "payment_calendar", "pawn_receipt_sleeve"]},
		{"group": "universal_active_items", "items": ["pickled_olive_jar"]},
		{"group": "blackjack_pack", "items": ["odds_notebook", "shoe_cut_marker"]},
		{"group": "baccarat_pack", "items": ["odds_notebook", "shoe_cut_marker"]},
		{"group": "roulette_pack", "items": ["sleeve_rig"]},
		{"group": "video_poker_pack", "items": ["sleeve_rig"]},
		{"group": "bar_dice_pack", "items": ["false_bottom_cup"]},
	]
	var default_pool := library.shop_item_pool_for_challenge([], {})
	for expectation_value in expectations:
		var expectation: Dictionary = expectation_value
		var group_id := str(expectation.get("group", ""))
		var group_items := _string_array(library.content_group(group_id).get("item_ids", []))
		var shop_pool := library.shop_item_pool_for_challenge([], {"modifiers": {"content_groups": [group_id]}})
		for item_id_value in _string_array(expectation.get("items", [])):
			var item_id := str(item_id_value)
			if not group_items.has(item_id):
				failures.append("T4.4 item %s is not listed in %s." % [item_id, group_id])
			if not shop_pool.has(item_id):
				failures.append("T4.4 item %s is not reachable in %s shop pools." % [item_id, group_id])
			if not default_pool.has(item_id):
				failures.append("T4.4 item %s is not reachable in default shop pools." % item_id)


func _check_t4_4_item_synergy_math(failures: Array) -> void:
	_check_t4_4_synergy_increases(["ledger_pencil"], ["ledger_pencil", "instant_coffee"], "win_chance", "", "legal", "Clean grinder Ledger/Coffee synergy", failures)
	_check_t4_4_synergy_increases(["cashout_envelope"], ["cashout_envelope", "creased_luck_card"], "win_bonus", "", "legal", "Clean grinder Envelope/Luck Card synergy", failures)
	_check_t4_4_synergy_increases(["odds_notebook"], ["odds_notebook", "card_counters_notes"], "blackjack_count_window_msec", "cards", "", "Advantage Notebook/Counter Notes synergy", failures)
	_check_t4_4_synergy_decreases(["shoe_cut_marker"], ["shoe_cut_marker", "edge_sort_loupe"], "baccarat_edge_sort_cue_count", "cards", "", "Advantage Marker/Loupe synergy", failures)
	_check_t4_4_synergy_increases(["sleeve_rig"], ["sleeve_rig", "holdout_wax"], "video_poker_holdout_perfect_msec", "cards", "cheat", "Cheat Sleeve/Holdout synergy", failures)
	_check_t4_4_synergy_increases(["false_bottom_cup"], ["false_bottom_cup", "weighted_keyring"], "bar_dice_controlled_roll_perfect_msec", "dice", "", "Cheat Cup/Keyring synergy", failures)
	_check_t4_4_synergy_increases(["lucky_bar_napkin"], ["lucky_bar_napkin", "pickled_olive_jar"], "win_bonus", "", "legal", "Drunk Napkin/Olives synergy", failures)
	_check_t4_4_synergy_increases(["lucky_bar_napkin"], ["lucky_bar_napkin", "thermos_black_coffee"], "loss_reduction", "", "legal", "Drunk Napkin/Coffee synergy", failures)
	_check_t4_4_synergy_increases(["payment_calendar"], ["payment_calendar", "pawn_receipt_sleeve"], "debt_grace_turns", "", "", "Debt Calendar/Pawn Sleeve synergy", failures)
	_check_t4_4_synergy_decreases(["pawn_receipt_sleeve"], ["pawn_receipt_sleeve", "payment_calendar"], "debt_default_heat_delta", "", "", "Debt Pawn Sleeve/Calendar synergy", failures)


func _check_t4_4_synergy_increases(base_items: Array, combo_items: Array, key: String, family: String, action_kind: String, label: String, failures: Array) -> void:
	var base_total := _t4_4_item_total(base_items, key, family, action_kind)
	var combo_total := _t4_4_item_total(combo_items, key, family, action_kind)
	if combo_total <= base_total:
		failures.append("%s did not increase %s (%d -> %d)." % [label, key, base_total, combo_total])


func _check_t4_4_synergy_decreases(base_items: Array, combo_items: Array, key: String, family: String, action_kind: String, label: String, failures: Array) -> void:
	var base_total := _t4_4_item_total(base_items, key, family, action_kind)
	var combo_total := _t4_4_item_total(combo_items, key, family, action_kind)
	if combo_total >= base_total:
		failures.append("%s did not decrease %s (%d -> %d)." % [label, key, base_total, combo_total])


func _t4_4_item_total(items: Array, key: String, family: String, action_kind: String) -> int:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("T44-ITEM-TOTAL-%s" % key)
	for item_id_value in items:
		run_state.add_item(str(item_id_value))
	return run_state.item_effect_total(key, family, action_kind)


func _check_t4_4_item_debt_modifiers(failures: Array) -> void:
	var grace_run: RunState = RunStateScript.new()
	grace_run.start_new("T44-DEBT-GRACE")
	grace_run.add_item("payment_calendar")
	grace_run.add_debt({"id": "grace_note", "lender_id": "street_lender", "balance": 30, "deadline_turns": 2, "turns_remaining": 2, "default_consequence": "forced_repayment"})
	if grace_run.debt.is_empty() or int((grace_run.debt[0] as Dictionary).get("turns_remaining", 0)) != 3:
		failures.append("Payment Calendar did not extend a new timed debt by one action.")
	var combo_grace_run: RunState = RunStateScript.new()
	combo_grace_run.start_new("T44-DEBT-GRACE-COMBO")
	combo_grace_run.add_item("payment_calendar")
	combo_grace_run.add_item("pawn_receipt_sleeve")
	combo_grace_run.add_debt({"id": "combo_grace_note", "lender_id": "street_lender", "balance": 30, "deadline_turns": 2, "turns_remaining": 2, "default_consequence": "forced_repayment"})
	if combo_grace_run.debt.is_empty() or int((combo_grace_run.debt[0] as Dictionary).get("turns_remaining", 0)) != 4:
		failures.append("Payment Calendar and Pawn Receipt Sleeve did not stack debt grace turns.")
	var no_item_heat := _t4_4_forced_default_heat([])
	var protected_heat := _t4_4_forced_default_heat(["pawn_receipt_sleeve", "payment_calendar"])
	if protected_heat >= no_item_heat:
		failures.append("Pawn Receipt Sleeve debt-default protection did not reduce default heat (%d -> %d)." % [no_item_heat, protected_heat])


func _check_t4_4_item_action_round_trips(library: ContentLibrary, failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("T44-ITEM-ACTIONS")
	run_state.change_bankroll(100)
	run_state.set_environment({
		"id": "t44_item_shop",
		"kind": "shop",
		"archetype_id": "corner_store",
		"display_name": "T4.4 Shop",
		"item_offers": [
			{"id": "ledger_pencil", "display_name": "Ledger Pencil", "price": 12},
			{"id": "pickled_olive_jar", "display_name": "Pickled Olive Jar", "price": 9},
		],
	})
	var resolver: RunActionService = RunActionServiceScript.new()
	resolver.setup(library, run_state)
	var buy_ledger := resolver.buy_item_offer("ledger_pencil")
	if not bool(buy_ledger.get("ok", false)) or not run_state.inventory.has("ledger_pencil"):
		failures.append("T4.4 Ledger Pencil could not be bought through RunActionService.")
	var sell_ledger := resolver.sell_inventory_item("ledger_pencil")
	if not bool(sell_ledger.get("ok", false)) or run_state.inventory.has("ledger_pencil"):
		failures.append("T4.4 Ledger Pencil could not be sold through RunActionService.")
	var buy_olives := resolver.buy_item_offer("pickled_olive_jar")
	if not bool(buy_olives.get("ok", false)) or not run_state.inventory.has("pickled_olive_jar"):
		failures.append("T4.4 Pickled Olive Jar could not be bought through RunActionService.")
	if str(run_state.active_item_id) != "pickled_olive_jar":
		failures.append("T4.4 active item purchase did not auto-select Pickled Olive Jar.")
	var item_def := library.item("pickled_olive_jar")
	var item_effect := ItemEffect.new()
	item_effect.setup(item_def)
	var before_pending := run_state.pending_drunk_absorption_amount()
	var before_luck := run_state.baseline_luck
	var use_result := item_effect.apply({
		"domain": "global",
		"domains": ["global"],
		"action_id": "use_active_item",
		"action_kind": "item",
	})
	GameModule.apply_result(run_state, use_result)
	if run_state.inventory.has("pickled_olive_jar") or str(run_state.active_item_id) == "pickled_olive_jar":
		failures.append("T4.4 Pickled Olive Jar was not consumed and cleared from the active slot.")
	if run_state.pending_drunk_absorption_amount() <= before_pending:
		failures.append("T4.4 Pickled Olive Jar did not apply alcohol intake on use.")
	if run_state.baseline_luck <= before_luck:
		failures.append("T4.4 Pickled Olive Jar did not apply its luck bump on use.")
	var restored: RunState = RunStateScript.new()
	restored.from_dict(run_state.to_dict())
	if restored.inventory.has("pickled_olive_jar") or restored.pending_drunk_absorption_amount() != run_state.pending_drunk_absorption_amount():
		failures.append("T4.4 item buy/use/sell state did not survive RunState round-trip.")


func _t4_4_forced_default_heat(items: Array) -> int:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("T44-DEBT-DEFAULT")
	run_state.set_environment({"id": "t44_debt_fixture", "kind": "shop", "display_name": "Debt Fixture", "item_offers": []})
	run_state.change_bankroll(200)
	for item_id_value in items:
		run_state.add_item(str(item_id_value))
	run_state.add_debt({"id": "default_note", "lender_id": "street_lender", "balance": 90, "status": "overdue", "default_consequence": "forced_repayment"})
	run_state.default_debt("default_note")
	return run_state.suspicion_level()


func _t4_4_consumed_item_effect_keys() -> Dictionary:
	return _lookup_from_array([
		"active_item",
		"active_mode",
		"active_target",
		"alcohol_intake",
		"baccarat_edge_sort_cue_count",
		"baccarat_edge_sort_heat_delta",
		"baccarat_edge_sort_memory_tolerance",
		"bar_dice_controlled_roll_base_heat",
		"bar_dice_controlled_roll_close_msec",
		"bar_dice_controlled_roll_good_msec",
		"bar_dice_controlled_roll_meter_period_msec",
		"bar_dice_controlled_roll_perfect_msec",
		"baseline_luck_delta",
		"blackjack_basic_strategy_card",
		"blackjack_count_cover",
		"blackjack_count_edge_bonus",
		"blackjack_count_heat_delta",
		"blackjack_count_tolerance",
		"blackjack_count_window_msec",
		"blackjack_dealer_catch_chance",
		"blackjack_failed_peek_heat_absorb",
		"blackjack_lucky_ladies_payout_multiplier",
		"blackjack_lucky_ladies_stake_multiplier",
		"blackjack_peek_heat_delta",
		"blackjack_peek_loss_reduction",
		"blackjack_peek_window_percent",
		"blackjack_side_bet_bonus",
		"blackjack_side_bet_flat_bonus",
		"blackjack_side_bet_loss_reduction",
		"blackjack_table_limit_multiplier",
		"blackjack_table_minimum_to_previous_max",
		"cheat_suspicion_delta",
		"debt_default_heat_delta",
		"debt_grace_turns",
		"drunk_delta",
		"drunk_distortion_suppression_turns",
		"inventory_add",
		"inventory_remove",
		"legal_win_chance",
		"loss_reduction",
		"messages",
		"pending_drunk_absorption_delta",
		"repair_cost",
		"repair_to_item",
		"roulette_past_post_base_heat",
		"roulette_past_post_good_msec",
		"roulette_past_post_perfect_msec",
		"roulette_past_post_window_msec",
		"scratch_fortune_hint",
		"scratch_peek_cells",
		"scratch_peek_heat",
		"scratch_penalty_shields",
		"skill_cheat_drunk_memory_offset",
		"skill_cheat_drunk_window_offset_msec",
		"slot_cold_quarter_heat_reduction",
		"slot_feature_weight_bonus_percent",
		"slot_first_bonus_bonus_cap",
		"slot_first_bonus_bonus_percent",
		"slot_gold_tooth_coin_multiplier",
		"slot_gold_tooth_coin_upgrade_chance",
		"slot_nudge_close_msec_bonus",
		"slot_nudge_perfect_msec_bonus",
		"slot_pinball_bumper_battery_award_percent",
		"slot_pinball_bumper_battery_hits",
		"slot_pinball_bumper_battery_kick_percent",
		"slot_pinball_bumper_battery_up_impulse",
		"slot_pinball_drain_cleaner_award_percent",
		"slot_pinball_drain_cleaner_floor_percent",
		"slot_pinball_drain_cleaner_uses",
		"slot_pinball_extra_ball_token",
		"slot_pinball_jackpot_magnet_award_percent",
		"slot_pinball_jackpot_magnet_progress_bonus",
		"slot_pinball_jackpot_magnet_uses",
		"slot_pinball_lock_jammer_uses",
		"slot_pinball_magnet_cup_radius_percent",
		"slot_pinball_plunger_tuner_width_percent",
		"slot_pinball_return_spring_impulse",
		"slot_pinball_return_spring_uses",
		"slot_pinball_rubber_pegs",
		"slot_pinball_splitter_token_extra_balls",
		"slot_pinball_splitter_token_uses",
		"slot_pinball_tilt_dampener_percent",
		"slot_reel_win_weight_percent",
		"slot_split_reel_note_close_msec_bonus",
		"slot_split_reel_note_perfect_msec_bonus",
		"slot_three_reel_loss_refund_percent",
		"travel_scouting_level",
		"video_poker_holdout_close_msec",
		"video_poker_holdout_good_msec",
		"video_poker_holdout_heat_delta",
		"video_poker_holdout_perfect_msec",
		"win_bonus",
		"win_chance",
	])


func _lookup_from_array(values: Array) -> Dictionary:
	var result := {}
	for value in values:
		result[str(value)] = true
	return result


func _check_content_group_modularity(library: ContentLibrary, failures: Array) -> void:
	var default_groups := library.default_content_group_ids()
	if default_groups.is_empty():
		failures.append("Content groups should expose default-enabled run packs.")
	for required_group in ["universal_passive_items", "universal_active_items", "pull_tabs_pack", "scratch_tickets_pack", "slot_pack", "bar_dice_pack", "blackjack_pack", "baccarat_pack", "roulette_pack", "video_poker_pack"]:
		if library.content_group(required_group).is_empty():
			failures.append("Content group is missing: %s." % required_group)
	if not library.game_enabled_for_challenge("pull_tabs", {}):
		failures.append("Default content groups should enable pull tabs.")
	if not library.item_enabled_for_challenge("xray_glasses", {}):
		failures.append("Default content groups should enable pull-tab items.")
	var shop_archetype_for_groups := _first_shop_archetype(library)
	if shop_archetype_for_groups.is_empty():
		failures.append("No shop archetype exists for content-group item reachability.")
	else:
		var default_shop_pool := library.shop_item_pool_for_challenge(shop_archetype_for_groups.get("item_pool", []), {})
		for item_value in library.items:
			if typeof(item_value) != TYPE_DICTIONARY:
				continue
			var item_def: Dictionary = item_value
			var item_id := str(item_def.get("id", "")).strip_edges()
			if item_id.is_empty() or not bool(item_def.get("sellable", true)):
				continue
			if library.item_enabled_for_challenge(item_id, {}) and not default_shop_pool.has(item_id):
				failures.append("Default-enabled buyable item is not reachable from generated shop pools: %s." % item_id)
	var no_pull_tabs_groups := _groups_without(default_groups, ["pull_tabs_pack"])
	var no_pull_tabs_challenge := RunState.custom_challenge("no_pull_tabs", "CONTENT-GROUPS", {"content_groups": no_pull_tabs_groups})
	if library.game_enabled_for_challenge("pull_tabs", no_pull_tabs_challenge):
		failures.append("Disabled pull-tabs content group still enabled the pull-tabs game.")
	if not library.item_enabled_for_challenge("xray_glasses", no_pull_tabs_challenge):
		failures.append("Shared X-Ray Glasses disappeared while the scratch-tickets group remained enabled.")
	if library.item_enabled_for_challenge("tab_detector", no_pull_tabs_challenge):
		failures.append("Disabled pull-tabs content group still enabled pull-tab-only items.")
	if not library.game_enabled_for_challenge("slot", no_pull_tabs_challenge):
		failures.append("Disabling pull tabs should not disable unrelated slot games.")
	var only_pull_tabs_challenge := RunState.custom_challenge("only_pull_tabs", "CONTENT-GROUPS", {"content_groups": ["pull_tabs_pack"]})
	if not library.game_enabled_for_challenge("pull_tabs", only_pull_tabs_challenge):
		failures.append("Explicit pull-tabs group should enable pull tabs.")
	if library.game_enabled_for_challenge("slot", only_pull_tabs_challenge):
		failures.append("Omitted slot group should disable slot games.")
	if library.item_enabled_for_challenge("foil_sleeve", only_pull_tabs_challenge):
		failures.append("Omitted slot group should disable slot-only items.")
	if library.item_enabled_for_challenge("creased_luck_card", only_pull_tabs_challenge):
		failures.append("Omitted universal passive group should disable universal passive items.")
	if not shop_archetype_for_groups.is_empty():
		var only_pull_tabs_shop_pool := library.shop_item_pool_for_challenge(shop_archetype_for_groups.get("item_pool", []), only_pull_tabs_challenge)
		if only_pull_tabs_shop_pool.has("feature_magnet"):
			failures.append("Pull-tab-only challenge still exposed a slot item in generated shop pools.")
	var pull_tab_archetype := _first_archetype_with_game(library, "pull_tabs")
	if pull_tab_archetype.is_empty():
		failures.append("No archetype exposes pull tabs for content-group filtering.")
	else:
		var run_state := RunStateScript.new()
		run_state.start_new("NO-PULL-TABS", no_pull_tabs_challenge)
		var environment := EnvironmentInstance.from_archetype(pull_tab_archetype, 1, run_state.create_rng("no_pull_tabs"), library, run_state.challenge_config)
		if _string_array(environment.game_ids).has("pull_tabs"):
			failures.append("Generated environment still spawned pull tabs after its content group was disabled.")
	var shop_archetype := _first_archetype_with_item(library, "tab_detector")
	if shop_archetype.is_empty():
		failures.append("No archetype exposes xray_glasses for content-group filtering.")
	else:
		var run_state_items := RunStateScript.new()
		run_state_items.start_new("NO-PULL-TAB-ITEMS", no_pull_tabs_challenge)
		var item_environment := EnvironmentInstance.from_archetype(shop_archetype, 0, run_state_items.create_rng("no_pull_tab_items"), library, run_state_items.challenge_config)
		for offer_value in item_environment.item_offers:
			if typeof(offer_value) == TYPE_DICTIONARY and str((offer_value as Dictionary).get("id", "")) == "tab_detector":
				failures.append("Generated shop still offered a pull-tab-only item after its group was disabled.")
	var saved := RunStateScript.new()
	saved.start_new("CONTENT-GROUP-SAVE", only_pull_tabs_challenge)
	var restored := RunStateScript.new()
	restored.from_dict(saved.to_dict())
	_assert_json_equal(saved.challenge_config, restored.challenge_config, "Content group challenge config did not survive RunState round-trip.", failures)


func _check_challenge_pack_content(library: ContentLibrary, failures: Array) -> void:
	if library.challenges.size() < 6 or library.challenges.size() > 10:
		failures.append("Act 1 challenge pack should contain 6-10 authored challenges.")
	for required_id in ["dry_run", "debt_spiral", "pacifist", "one_machine", "heat_wave"]:
		if library.challenge(required_id).is_empty():
			failures.append("Challenge pack is missing required challenge: %s." % required_id)
	for challenge_value in library.challenges:
		if typeof(challenge_value) != TYPE_DICTIONARY:
			continue
		var challenge_def: Dictionary = challenge_value
		var challenge_id := str(challenge_def.get("id", "")).strip_edges()
		var option_matches := false
		for option_value in library.challenge_options(challenge_id):
			if typeof(option_value) == TYPE_DICTIONARY and str((option_value as Dictionary).get("id", "")) == challenge_id:
				option_matches = true
				break
		if bool(challenge_def.get("menu_visible", true)) and not option_matches:
			failures.append("Challenge %s did not appear in ContentLibrary.challenge_options()." % challenge_id)
		if not bool(challenge_def.get("menu_visible", true)) and option_matches:
			failures.append("Hidden challenge %s appeared in ContentLibrary.challenge_options()." % challenge_id)
		var completion_flag := str(challenge_def.get("completion_flag", "")).strip_edges()
		if not completion_flag.begins_with("challenge_") or not completion_flag.ends_with("_complete"):
			failures.append("Challenge %s completion_flag should use the challenge_*_complete profile convention." % challenge_id)
		var config := library.challenge_config_for(challenge_id, "CHALLENGE-CONTENT-SEED")
		if str(config.get("id", "")) != challenge_id or str(config.get("completion_flag", "")) != completion_flag:
			failures.append("Challenge %s did not build a RunState-ready config with its completion flag." % challenge_id)


func _groups_without(groups: Array, disabled_groups: Array) -> Array:
	var disabled := {}
	for group_id in disabled_groups:
		disabled[str(group_id)] = true
	var result: Array = []
	for group_id in groups:
		if not bool(disabled.get(str(group_id), false)):
			result.append(str(group_id))
	return result


func _first_archetype_with_game(library: ContentLibrary, game_id: String) -> Dictionary:
	for archetype_value in library.environment_archetypes:
		if typeof(archetype_value) != TYPE_DICTIONARY:
			continue
		var archetype: Dictionary = archetype_value
		if _string_array(archetype.get("game_pool", [])).has(game_id):
			return archetype
	return {}


func _first_archetype_with_item(library: ContentLibrary, item_id: String) -> Dictionary:
	for archetype_value in library.environment_archetypes:
		if typeof(archetype_value) != TYPE_DICTIONARY:
			continue
		var archetype: Dictionary = archetype_value
		if library.shop_item_pool_for_challenge(archetype.get("item_pool", []), {}).has(item_id):
			return archetype
	return {}


func _first_shop_archetype(library: ContentLibrary) -> Dictionary:
	for archetype_value in library.environment_archetypes:
		if typeof(archetype_value) != TYPE_DICTIONARY:
			continue
		var archetype: Dictionary = archetype_value
		if str(archetype.get("kind", "")) == "shop":
			return archetype
	return {}


func _check_foundation_contract_smoke(library: ContentLibrary, failures: Array, suite: String = "all") -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("FOUNDATION-SMOKE")
	var snapshot := run_state.to_dict()
	if snapshot.is_empty():
		failures.append("RunState did not serialize after start_new.")
	var restored: RunState = RunStateScript.new()
	restored.from_dict(snapshot)
	if JSON.stringify(snapshot) != JSON.stringify(restored.to_dict()):
		failures.append("RunState did not round-trip its initial smoke snapshot.")

	var rng_a := run_state.create_rng("smoke")
	var rng_b := run_state.create_rng("smoke")
	if rng_a.randi_range(1, 100000) != rng_b.randi_range(1, 100000):
		failures.append("RngStream did not produce deterministic smoke output.")

	var generator: RunGenerator = RunGeneratorScript.new(library)
	var first_environment: EnvironmentInstance = generator.next_environment(run_state)
	_check_environment_instance_shape(first_environment, false, failures)
	_check_start_home_environment(run_state, first_environment, failures)
	var second_environment: EnvironmentInstance = generator.next_environment(run_state, first_environment.next_archetypes[0] if not first_environment.next_archetypes.is_empty() else "")
	_check_environment_instance_shape(second_environment, false, failures)
	if second_environment.kind == "home":
		failures.append("Second foundation EnvironmentInstance should leave home into the world.")
	if second_environment.game_ids.is_empty() and second_environment.item_offers.is_empty() and second_environment.service_ids.is_empty() and second_environment.lender_hooks.is_empty() and second_environment.event_ids.is_empty() and second_environment.next_archetypes.is_empty():
		failures.append("Second foundation EnvironmentInstance should expose world interactions after leaving home.")
	if not second_environment.game_ids.is_empty():
		_check_production_game_module_load(library, run_state, second_environment, failures)
	_check_foundation_shell_no_game_specific_code(failures)
	_check_selected_starter_game_port(library, failures)
	_check_game_surface_contracts(library, failures)
	if suite == "smoke":
		_check_slot_contract_smoke(library, failures)
		_check_all_game_module_contracts(library, failures)
		return
	_check_bar_dice_contract(library, failures)
	_check_video_poker_contract(library, failures)
	if suite == "audit":
		_check_slot_acceptance(library, failures)
	else:
		_check_slot_contract_smoke(library, failures)
	_check_all_game_module_contracts(library, failures)
	_check_cross_game_integration_matrix(library, failures)
	_check_run_action_service_boundary(library, failures)
	_check_item_effect_foundation(library, failures)
	_check_item_build_interaction_foundation(library, failures)
	_check_event_module_foundation(library, failures)
	_check_event_system_state_foundation(library, failures)
	_check_save_service_foundation_round_trip(library, failures)
	_check_platform_services_foundation(failures)
	_check_economy_pressure_foundation(library, failures)
	_check_travel_route_foundation(library, failures)
	_check_service_hook_foundation(library, failures)
	_check_lender_debt_foundation(library, failures)
	_check_suspicion_security_foundation(failures)
	_check_run_report_foundation(failures)
	_check_m2_system_interaction_scenario(library, failures)
	_check_demo_boss_objective_foundation(library, failures)
	_check_recovery_loss_pressure_foundation(library, failures)


func _check_coach_engine_foundation(library: ContentLibrary, failures: Array) -> void:
	var normal_lessons: Array = []
	for lesson_value in library.tutorial_lessons:
		if typeof(lesson_value) == TYPE_DICTIONARY and str((lesson_value as Dictionary).get("scope", "")).strip_edges() != "tutorial_run":
			normal_lessons.append(lesson_value)
	if normal_lessons.size() != 9:
		failures.append("Coach lesson pack must ship exactly nine first-time tips after the starter-card handoff.")
	for expected_id in ["tip_first_heat_gain", "tip_first_debt_taken", "tip_first_closing_warning", "tip_first_pawn_interaction", "tip_first_item_purchase", "tip_first_map_open", "tip_first_chips_gained", "tip_first_card_tier", "tip_starter_card_home"]:
		if library.tutorial_lesson(expected_id).is_empty():
			failures.append("Coach lesson pack is missing %s." % expected_id)
	var duplicate_library := ContentLibraryScript.new()
	duplicate_library.tutorial_lessons = [_coach_lesson_fixture("duplicate"), _coach_lesson_fixture("duplicate")]
	if not _coach_errors_contain(duplicate_library.validate(), "duplicate id"):
		failures.append("Coach lesson validation accepted duplicate ids.")
	var anchor_library := ContentLibraryScript.new()
	var bad_anchor := _coach_lesson_fixture("bad_anchor")
	bad_anchor["anchor"] = {"kind": "corner_box", "id": "heat"}
	anchor_library.tutorial_lessons = [bad_anchor]
	if not _coach_errors_contain(anchor_library.validate(), "unknown kind"):
		failures.append("Coach lesson validation accepted an unknown anchor kind.")
	var cycle_library := ContentLibraryScript.new()
	var cycle_a := _coach_lesson_fixture("cycle_a")
	var cycle_b := _coach_lesson_fixture("cycle_b")
	cycle_a["trigger"] = {"depends_on": ["cycle_b"], "state_predicates": []}
	cycle_b["trigger"] = {"depends_on": ["cycle_a"], "state_predicates": []}
	cycle_library.tutorial_lessons = [cycle_a, cycle_b]
	if not _coach_errors_contain(cycle_library.validate(), "dependency cycle"):
		failures.append("Coach lesson validation accepted a dependency cycle.")
	var contexts := {
		"tip_first_heat_gain": {"run": {"heat_gain_count": 1}},
		"tip_first_debt_taken": {"run": {"debt_count": 1}},
		"tip_first_closing_warning": {"run": {"closing_time_active": true}},
		"tip_first_pawn_interaction": {"ui": {"pawn_counter_open": true}},
		"tip_first_item_purchase": {"screen": "RESULT", "action": {"last_result_type": "item_purchase"}},
		"tip_first_map_open": {"screen": "TRAVEL", "ui": {"world_map_open": true}},
		"tip_first_chips_gained": {"environment_archetype": "grand_casino", "run": {"grand_casino_chips": 1}},
		"tip_first_card_tier": {"run": {"players_card_tier": "bronze"}},
		"tip_starter_card_home": {"meta": {"home": true, "starter_card_count": 1}},
	}
	for lesson_value in normal_lessons:
		var lesson: Dictionary = lesson_value
		var lesson_id := str(lesson.get("id", ""))
		var context: Dictionary = contexts.get(lesson_id, {})
		if not CoachViewModelScript.trigger_matches(lesson, context, {}, true):
			failures.append("Coach tip %s did not fire for its truthful state fixture." % lesson_id)
		var seen_fixture: Dictionary = {}
		seen_fixture[lesson_id] = true
		if CoachViewModelScript.trigger_matches(lesson, context, seen_fixture, true):
			failures.append("Coach tip %s fired more than once after seen-state." % lesson_id)
		if CoachViewModelScript.trigger_matches(lesson, context, {}, false):
			failures.append("Coach tip %s fired while normal tips were disabled." % lesson_id)
	var hud_lesson := _coach_lesson_fixture("hud_anchor")
	hud_lesson["anchor"] = {"kind": "hud_element", "id": "heat"}
	var hud_context := {
		"viewport_rect": Rect2(Vector2.ZERO, Vector2(360, 640)),
		"anchor_rects": {"hud_elements": {"heat": Rect2(12, 12, 160, 48)}},
		"small_screen": true,
	}
	var hud_lesson_before := hud_lesson.duplicate(true)
	var hud_context_before := hud_context.duplicate(true)
	var hud_model := CoachViewModelScript.build(hud_lesson, hud_context)
	var hud_bubble := CoachViewModelScript._rect(hud_model.get("bubble_rect", {}))
	if not bool(hud_model.get("anchor_found", false)) or not Rect2(Vector2.ZERO, Vector2(360, 640)).encloses(hud_bubble):
		failures.append("Coach HUD anchor or small-screen bubble did not fit the viewport.")
	if hud_lesson != hud_lesson_before or hud_context != hud_context_before:
		failures.append("Coach pure view-model builder mutated its lesson or context input.")
	var object_lesson := _coach_lesson_fixture("object_anchor")
	object_lesson["anchor"] = {"kind": "interactable_object", "id": "fixture:door"}
	var object_model := CoachViewModelScript.build(object_lesson, {
		"viewport_rect": Rect2(Vector2.ZERO, Vector2(1280, 720)),
		"anchor_rects": {"interactable_objects": {"fixture:door": Rect2(100, 200, 90, 100)}},
	})
	if not bool(object_model.get("anchor_found", false)):
		failures.append("Coach room-object anchor did not resolve through focus rects.")
	var gating_lesson := _coach_lesson_fixture("gating")
	gating_lesson["gating"] = {"allowed_action_ids": ["fixture:door"]}
	var gating_model := CoachViewModelScript.build(gating_lesson, {"viewport_rect": Rect2(Vector2.ZERO, Vector2(1280, 720))})
	if CoachViewModelScript.input_allowed(gating_model, "wrong:door") or not CoachViewModelScript.input_allowed(gating_model, "fixture:door"):
		failures.append("Coach gating did not restrict only undeclared input routes.")
	if not CoachViewModelScript.input_allowed(object_model, "wrong:door"):
		failures.append("Non-gating coach tip blocked player input.")
	var settings := UserSettingsScript.new()
	settings.coach_tips_enabled = false
	var restored_settings := UserSettingsScript.new()
	restored_settings.from_dict(settings.to_dict())
	if restored_settings.coach_tips_enabled:
		failures.append("Coach tips setting did not round-trip disabled state.")


func _check_onboarding_tutorial_arc(library: ContentLibrary, failures: Array) -> void:
	var challenge := library.challenge("tutorial_first_card")
	if challenge.is_empty() or bool(challenge.get("menu_visible", true)):
		failures.append("Tutorial challenge was missing or visible in the generic challenge picker.")
	var visible_ids: Array = []
	for option_value in library.challenge_options():
		if typeof(option_value) == TYPE_DICTIONARY:
			visible_ids.append(str((option_value as Dictionary).get("id", "")))
	if visible_ids.has("tutorial_first_card"):
		failures.append("Tutorial challenge leaked into challenge_options.")
	var config_a := library.challenge_config_for("tutorial_first_card", "FIRST-REQUEST")
	var config_b := library.challenge_config_for("tutorial_first_card", "SECOND-REQUEST")
	if str(config_a.get("seed_text", "")) != "FIRST-NIGHT-ACE-17" or config_a != config_b:
		failures.append("Tutorial challenge did not enforce one deterministic fixed seed.")
	var run_a := RunStateScript.new()
	run_a.start_new("IGNORED", config_a)
	run_a.begin_act(1)
	var generator_a := RunGeneratorScript.new(library)
	generator_a.next_environment(run_a)
	var run_b := RunStateScript.new()
	run_b.start_new("ALSO-IGNORED", config_b)
	run_b.begin_act(1)
	var generator_b := RunGeneratorScript.new(library)
	generator_b.next_environment(run_b)
	if JSON.stringify(run_a.to_dict()) != JSON.stringify(run_b.to_dict()):
		failures.append("Tutorial fixed seed generated divergent initial runs.")
	if not run_a.is_tutorial_run() or not run_a.excludes_profile_stats():
		failures.append("Tutorial run did not exclude profile and challenge statistics.")
	if str(run_a.current_environment.get("archetype_id", "")) != "motel_room" or run_a.bankroll != 80 or not run_a.inventory.is_empty():
		failures.append("Tutorial initial home, bankroll, or carried loadout contract drifted.")
	var containers: Array = run_a.current_environment.get("home_containers", []) if typeof(run_a.current_environment.get("home_containers", [])) == TYPE_ARRAY else []
	if containers.size() != 1 or not (containers[0] as Dictionary).get("item_ids", []).is_empty():
		failures.append("Tutorial did not start with one empty backpack.")
	generator_a.next_environment(run_a, "motel", true)
	generator_a.next_environment(run_a, "corner_store", true)
	var item_service := RunActionServiceScript.new()
	item_service.setup(library, run_a)
	var purchase: Dictionary = item_service.buy_item_offer("instant_coffee")
	if not bool(purchase.get("ok", false)) or run_a.inventory.is_empty():
		failures.append("Tutorial end-to-end arc could not buy its cheap store item through RunActionService.")
	generator_a.next_environment(run_a, "bar", true)
	if run_a.current_environment.get("game_ids", []) != ["blackjack"]:
		failures.append("Tutorial end-to-end arc did not reach its real blackjack table.")
	var friendly_event := EventModuleScript.new()
	friendly_event.setup(library.event("tutorial_friendly_choice"), library)
	if not friendly_event.can_trigger(run_a, run_a.current_environment, {"type": "manual"}):
		failures.append("Tutorial friendly conversation was not eligible at the bar.")
	else:
		var friendly_result: Dictionary = friendly_event.resolve(run_a, run_a.current_environment, "keep_it_light")
		if not bool(friendly_result.get("ok", false)) or not bool(run_a.narrative_flags.get("tutorial_friendly_choice_done", false)):
			failures.append("Tutorial friendly conversation did not resolve its authored flag.")
	var invite_event := EventModuleScript.new()
	invite_event.setup(library.event("tutorial_grand_casino_invitation"), library)
	var invite_result: Dictionary = invite_event.resolve(run_a, run_a.current_environment, "accept_first_invitation")
	if not bool(invite_result.get("ok", false)) or not bool(run_a.narrative_flags.get("grand_casino_invite", false)):
		failures.append("Tutorial end-to-end arc did not accept the Grand Casino invitation.")
	elif not WorldMapScript.is_node_visible(run_a.world_map, "grand_casino"):
		failures.append("Tutorial invitation did not reveal the Grand Casino on the real world map.")
	generator_a.next_environment(run_a, "grand_casino", true)
	if str(run_a.current_environment.get("archetype_id", "")) != RunState.GRAND_CASINO_ARCHETYPE_ID or run_a.current_environment.get("game_ids", []) != ["slot"]:
		failures.append("Tutorial finale did not generate exactly one Main Floor slot.")
	var tutorial_status := run_a.demo_objective_status()
	if int(tutorial_status.get("high_roller_net_winnings", -1)) != 1 or int(tutorial_status.get("high_roller_min_grand_casino_games", -1)) != 1 or int(tutorial_status.get("high_roller_max_heat", -1)) != 90:
		failures.append("Tutorial Grand Casino objective did not preserve the 1 game / $1 net / 90 heat contract.")
	var normal_grand := library.environment_archetype(RunState.GRAND_CASINO_ARCHETYPE_ID)
	var normal_objective: Dictionary = normal_grand.get("demo_objective", {}) if typeof(normal_grand.get("demo_objective", {})) == TYPE_DICTIONARY else {}
	if int(normal_objective.get("high_roller_net_winnings", -1)) != 30 or int(normal_objective.get("high_roller_min_grand_casino_games", -1)) != 5 or int(normal_objective.get("high_roller_max_heat", -1)) != 30:
		failures.append("Tutorial tier compression changed normal Grand Casino objective balance.")
	var normal_slot_run := RunStateScript.new()
	normal_slot_run.start_new("TUTORIAL-NORMAL-SLOT-CONTROL")
	var normal_slot_environment := run_a.current_environment.duplicate(true)
	normal_slot_environment["game_states"] = {}
	normal_slot_run.set_environment(normal_slot_environment)
	var normal_slot: GameModule = SlotGameScript.new()
	normal_slot.setup(library.game("slot"), library)
	normal_slot.enter(normal_slot_run, normal_slot_run.current_environment)
	var normal_spin: Dictionary = normal_slot.resolve_with_context("spin", 2, normal_slot_run, normal_slot_run.current_environment, normal_slot_run.create_rng(), {})
	if bool(normal_spin.get("tutorial_first_night_match", false)):
		failures.append("Tutorial first-night match leaked into a normal run.")
	var high_limit_access := run_a.grand_casino_room_access_status(RunState.GRAND_CASINO_HIGH_LIMIT_ARCHETYPE_ID, 60)
	var back_room_access := run_a.grand_casino_room_access_status(RunState.GRAND_CASINO_BACK_ROOM_ARCHETYPE_ID, 60)
	if bool(high_limit_access.get("available", true)) or not str(high_limit_access.get("reason", "")).contains("Main Floor") or bool(back_room_access.get("available", true)):
		failures.append("Tutorial did not keep both deeper Grand Casino rooms behind teaching locks.")
	run_a.suspicion["level"] = 100
	run_a.narrative_flags["grand_casino_showdown_pending"] = true
	run_a.narrative_flags["the_house_calls_pending"] = true
	if run_a.grand_casino_heat_reroute_available() or run_a.handle_grand_casino_heat_reroute("foundation_tutorial") or bool(run_a.start_grand_casino_showdown().get("ok", false)):
		failures.append("Tutorial Grand Casino accepted a showdown route at forced heat.")
	run_a.narrative_flags.erase("grand_casino_showdown_pending")
	run_a.narrative_flags.erase("the_house_calls_pending")
	run_a.suspicion["level"] = 0
	var tutorial_slot: GameModule = SlotGameScript.new()
	tutorial_slot.setup(library.game("slot"), library)
	tutorial_slot.enter(run_a, run_a.current_environment)
	var tutorial_spin_rng := run_a.create_rng()
	var tutorial_spin: Dictionary = tutorial_slot.resolve_with_context("spin", 2, run_a, run_a.current_environment, tutorial_spin_rng, {})
	GameModule.apply_result(run_a, tutorial_spin, tutorial_spin_rng)
	var ready_status := run_a.demo_objective_status()
	if not bool(tutorial_spin.get("tutorial_first_night_match", false)) or int(ready_status.get("grand_casino_games_played", 0)) != 1 or int(ready_status.get("grand_casino_net_winnings", 0)) < 1 or str(ready_status.get("players_card_tier", "")) != RunState.GRAND_CASINO_PLAYERS_CARD_TIER_SILVER or str(ready_status.get("players_card_next_tier", "")) != RunState.GRAND_CASINO_PLAYERS_CARD_TIER_GOLD or not bool(ready_status.get("high_roller_ready", false)):
		failures.append("Tutorial fixed-seed Main Floor spin did not reach the compressed Gold review: %s" % JSON.stringify(ready_status))
	if not generator_a.enter_grand_casino_room(run_a, RunState.GRAND_CASINO_CAGE_ARCHETYPE_ID):
		failures.append("Tutorial did not permit the required return to Linda in the Cage.")
	var tutorial_cashout := run_a.complete_grand_casino_high_roller_cashout({"success_message": "Tutorial card issued."})
	if not bool(tutorial_cashout.get("ok", false)) or run_a.run_status != RunState.RUN_STATUS_ENDED:
		failures.append("Tutorial Linda review did not complete the real clean-victory route.")
	var tutorial_linda := library.dialogue("tutorial_linda_gold_review")
	var linda_speaker: Dictionary = tutorial_linda.get("speaker", {}) if typeof(tutorial_linda.get("speaker", {})) == TYPE_DICTIONARY else {}
	var linda_nodes: Dictionary = tutorial_linda.get("nodes", {}) if typeof(tutorial_linda.get("nodes", {})) == TYPE_DICTIONARY else {}
	var linda_review: Dictionary = linda_nodes.get("review", {}) if typeof(linda_nodes.get("review", {})) == TYPE_DICTIONARY else {}
	if str(linda_speaker.get("name", "")) != "Linda" or not str(linda_review.get("text", "")).contains("card goes with it"):
		failures.append("Tutorial Linda review is missing its warmer card meaning and fragility explanation.")
	OS.set_environment(MetaCollectionServiceScript.STORE_PATH_ENV, TUTORIAL_META_STORE_PATH)
	_remove_tutorial_meta_store()
	var tutorial_meta := MetaCollectionServiceScript.new()
	tutorial_meta.load()
	var tutorial_drop := CollectionDropServiceScript.new()
	var tutorial_reward: Dictionary = tutorial_drop.apply_terminal_special_outcome(run_a, tutorial_meta)
	var tutorial_owned: Array = tutorial_meta.owned_instances()
	var tutorial_card := (tutorial_owned[0] as Dictionary).duplicate(true) if not tutorial_owned.is_empty() and typeof(tutorial_owned[0]) == TYPE_DICTIONARY else {}
	var tutorial_stamp: Dictionary = tutorial_card.get("instance_data", {}) if typeof(tutorial_card.get("instance_data", {})) == TYPE_DICTIONARY else {}
	if not bool(tutorial_reward.get("mutated", false)) or tutorial_owned.size() != 1 or not bool(tutorial_stamp.get("starter_card", false)) or not bool(tutorial_stamp.get("tutorial", false)) or str(tutorial_stamp.get("tutorial_challenge_id", "")) != "tutorial_first_card":
		failures.append("Tutorial victory did not mint exactly one correctly stamped starter card through the meta service.")
	var tutorial_report := RunReportViewModel.build(run_a.to_dict())
	if str((tutorial_report.get("meta_reward", {}) as Dictionary).get("kind", "")) != "players_card_minted":
		failures.append("Tutorial run report did not show the Players Card reward.")
	_remove_tutorial_meta_store()
	OS.set_environment(MetaCollectionServiceScript.STORE_PATH_ENV, "")
	var fresh_profile := ProfileInventoryScript.new()
	fresh_profile.from_dict({})
	var fresh_meta := {"owned_instances": [], "unopened_bags": [], "loadout": [], "gold_balance": 0, "housing_tier": "back_alley"}
	if not TutorialFlowScript.should_auto_start(fresh_profile, fresh_meta):
		failures.append("Fresh profile did not qualify for automatic tutorial start.")
	fresh_profile.tutorial_completed = true
	if TutorialFlowScript.should_auto_start(fresh_profile, fresh_meta):
		failures.append("Completed tutorial profile qualified for automatic replay.")
	var legacy_profile := ProfileInventoryScript.new()
	legacy_profile.from_dict({"schema_version": 4})
	legacy_profile.loaded_from_disk = true
	if TutorialFlowScript.should_auto_start(legacy_profile, fresh_meta):
		failures.append("Legacy profile without onboarding state was forced into the tutorial.")
	var legacy_heat_tip := library.tutorial_lesson("tip_first_heat_gain")
	if not CoachViewModelScript.trigger_matches(legacy_heat_tip, {"run": {"heat_gain_count": 1}}, legacy_profile.tips_seen, true):
		failures.append("Legacy profile did not retain normal first-time coach tips.")
	var tutorial_lessons: Array = []
	for lesson_value in library.tutorial_lessons:
		if typeof(lesson_value) == TYPE_DICTIONARY and str((lesson_value as Dictionary).get("scope", "")) == "tutorial_run":
			tutorial_lessons.append(lesson_value)
	if tutorial_lessons.size() < 16:
		failures.append("Tutorial arc did not cover the full Home-to-invitation beat sequence.")
	for lesson_value in tutorial_lessons:
		var lesson: Dictionary = lesson_value
		if CoachViewModelScript.trigger_matches(lesson, {"run": {"tutorial": true}}, {}, false):
			failures.append("Tutorial coach lesson fired with tips disabled: %s" % str(lesson.get("id", "")))
	if tutorial_lessons.size() < 28:
		failures.append("Tutorial coach data did not cover the full seven-beat arc through Linda's review.")
	var tutorial_copy_words := 0
	var small_viewport := Rect2(Vector2.ZERO, Vector2(360, 640))
	for lesson_index in range(tutorial_lessons.size()):
		var lesson: Dictionary = tutorial_lessons[lesson_index]
		var lesson_copy := str(lesson.get("copy", "")).strip_edges()
		tutorial_copy_words += lesson_copy.split(" ", false).size()
		if lesson_copy.length() > 80:
			failures.append("Tutorial coach copy exceeded the compact bubble limit: %s." % str(lesson.get("id", "")))
		var anchor: Dictionary = lesson.get("anchor", {}) if typeof(lesson.get("anchor", {})) == TYPE_DICTIONARY else {}
		var anchor_kind := str(anchor.get("kind", "none"))
		var anchor_id := str(anchor.get("id", ""))
		var anchor_group := str({
			"interactable_object": "interactable_objects",
			"hud_element": "hud_elements",
			"surface_action": "surface_actions",
		}.get(anchor_kind, ""))
		var anchor_rects := {"interactable_objects": {}, "hud_elements": {}, "surface_actions": {}}
		if not anchor_group.is_empty():
			var anchor_y := 12.0 if lesson_index % 3 == 0 else (292.0 if lesson_index % 3 == 1 else 576.0)
			var group_rects: Dictionary = anchor_rects[anchor_group]
			group_rects[anchor_id] = Rect2(24.0, anchor_y, 88.0, 52.0)
		var small_model := CoachViewModelScript.build(lesson, {
			"viewport_rect": small_viewport,
			"anchor_rects": anchor_rects,
			"small_screen": true,
			"reduce_motion": true,
		})
		var small_bubble := CoachViewModelScript._rect(small_model.get("bubble_rect", {}))
		if not small_viewport.encloses(small_bubble):
			failures.append("Tutorial coach bubble escaped small-screen bounds: %s." % str(lesson.get("id", "")))
		if not anchor_group.is_empty() and not bool(small_model.get("anchor_found", false)):
			failures.append("Tutorial coach anchor failed in small-screen mode: %s." % str(lesson.get("id", "")))
		if not bool(small_model.get("small_screen", false)) or not bool(small_model.get("reduce_motion", false)) or float(small_model.get("minimum_control_height", 0.0)) < 52.0:
			failures.append("Tutorial coach accessibility state drifted: %s." % str(lesson.get("id", "")))
	if tutorial_copy_words > 280:
		failures.append("Tutorial coach copy exceeded the paced 280-word budget: %d words." % tutorial_copy_words)
	var narrow_model := CoachViewModelScript.build(_coach_lesson_fixture("narrow_phone"), {
		"viewport_rect": Rect2(Vector2.ZERO, Vector2(240, 320)),
		"small_screen": true,
		"reduce_motion": true,
	})
	if not Rect2(Vector2.ZERO, Vector2(240, 320)).encloses(CoachViewModelScript._rect(narrow_model.get("bubble_rect", {}))):
		failures.append("Coach bubble did not clamp to a narrow phone viewport.")


func _remove_tutorial_meta_store() -> void:
	var absolute := ProjectSettings.globalize_path(TUTORIAL_META_STORE_PATH)
	if FileAccess.file_exists(TUTORIAL_META_STORE_PATH):
		DirAccess.remove_absolute(absolute)


func _coach_lesson_fixture(lesson_id: String) -> Dictionary:
	return {
		"id": lesson_id,
		"trigger": {"state_predicates": []},
		"anchor": {"kind": "none"},
		"copy": "Fixture advice.",
		"completion": {"type": "any_action"},
	}


func _coach_errors_contain(errors: Array, fragment: String) -> bool:
	for error_value in errors:
		if str(error_value).to_lower().contains(fragment.to_lower()):
			return true
	return false


func _check_profile_inventory_boundary(failures: Array) -> void:
	OS.set_environment(ProfileInventoryScript.INVENTORY_PATH_ENV, "user://foundation_profile_inventory_check.json")
	_remove_profile_inventory_test_file()
	var profile_inventory: ProfileInventory = ProfileInventoryScript.new()
	profile_inventory.load()
	profile_inventory.add_reference_chip()
	profile_inventory.mark_tip_seen("tip_first_heat_gain")
	profile_inventory.tutorial_completed = true
	if not profile_inventory.has_item(ProfileInventory.REFERENCE_CHIP_ID):
		failures.append("ProfileInventory did not store the reference poker chip.")
	profile_inventory.mark_challenge_completed("challenge_fixture_complete", "fixture_challenge", "Fixture Challenge")
	profile_inventory.record_run_result(_profile_result_fixture("victory", "players_card_cashout", "2026-07-01", 210, {"bar_dice": 2}, "standard"))
	profile_inventory.record_run_result(_profile_result_fixture("failure", RunStateScript.FAILURE_BANKROLL_ZERO, "2026-07-02", 0, {"blackjack": 1}, "standard"))
	profile_inventory.record_run_result(_profile_result_fixture("failure", RunStateScript.FAILURE_POLICE_CAPTURE, "2026-07-03", 55, {}, "standard"))
	profile_inventory.record_run_result(_profile_result_fixture("failure", RunStateScript.FAILURE_STRANDED, "2026-07-04", 5, {}, "standard"))
	profile_inventory.record_run_result(_profile_result_fixture("failure", RunStateScript.FAILURE_ABANDONED, "2026-07-05", 100, {}, "standard"))
	var snapshot := profile_inventory.to_dict()
	snapshot["future_profile_field"] = {"kept": true}
	var restored: ProfileInventory = ProfileInventoryScript.new()
	restored.from_dict(snapshot)
	if restored.item_quantity(ProfileInventory.REFERENCE_CHIP_ID) != 1:
		failures.append("ProfileInventory did not round-trip the reference poker chip.")
	if not restored.has_challenge_completion("challenge_fixture_complete"):
		failures.append("ProfileInventory did not round-trip challenge completion flags.")
	if not restored.has_seen_tip("tip_first_heat_gain") or not restored.tutorial_completed:
		failures.append("ProfileInventory did not round-trip coach seen-state and tutorial completion.")
	if restored.completed_challenge_rows().is_empty():
		failures.append("ProfileInventory did not surface completed challenge rows.")
	if restored.run_history.size() != 5:
		failures.append("ProfileInventory did not append one history entry for each terminal fixture.")
	if int(restored.lifetime_stats.get("total_runs", 0)) != 5:
		failures.append("ProfileInventory lifetime total_runs did not match terminal fixtures.")
	var victories := _copy_dict(restored.lifetime_stats.get("victories_per_route", {}))
	if int(victories.get("players_card_cashout", 0)) != 1:
		failures.append("ProfileInventory did not count players-card victories by route.")
	var games_played := _copy_dict(restored.lifetime_stats.get("games_played", {}))
	if int(games_played.get("bar_dice", 0)) != 2 or int(games_played.get("blackjack", 0)) != 1:
		failures.append("ProfileInventory did not merge lifetime game tallies.")
	if not restored.to_dict().has("future_profile_field"):
		failures.append("ProfileInventory did not preserve unknown profile keys.")
	if int(restored.to_dict().get("act", 0)) != 1:
		failures.append("ProfileInventory did not write the Act 1 profile marker.")
	if not _copy_dict(restored.to_dict().get("act_seam", {})).is_empty():
		failures.append("ProfileInventory old profile normalization should leave act_seam empty.")
	var seam_result: Dictionary = restored.record_act_seam({
		"source_act": 1,
		"target_act": 2,
		"victory_route": "players_card_cashout",
		"demo_victory_route": RunStateScript.GRAND_CASINO_HIGH_ROLLER_EVENT_ID,
		"final_bankroll_band": "heavy_envelope",
		"story_flags": {"met_host": true},
		"route_payload": {"hook": "players_card_open_rooms"},
	})
	if not bool(seam_result.get("ok", false)) or str(restored.act_seam.get("victory_route", "")) != "players_card_cashout":
		failures.append("ProfileInventory did not record the Act 2 seam payload.")
	var save_error := restored.save()
	if save_error != OK:
		failures.append("ProfileInventory atomic save failed with error %d." % int(save_error))
	var loaded: ProfileInventory = ProfileInventoryScript.new()
	loaded.load()
	if JSON.stringify(loaded.to_dict()) != JSON.stringify(restored.to_dict()):
		failures.append("ProfileInventory did not round-trip through disk save/load.")
	var corrupt_file := FileAccess.open(ProfileInventoryScript.store_path(), FileAccess.WRITE)
	if corrupt_file != null:
		corrupt_file.store_string("{bad")
		corrupt_file.close()
	var corrupt: ProfileInventory = ProfileInventoryScript.new()
	corrupt.load()
	if int(corrupt.to_dict().get("schema_version", 0)) != ProfileInventoryScript.SCHEMA_VERSION or not corrupt.run_history.is_empty() or int(corrupt.lifetime_stats.get("total_runs", -1)) != 0:
		failures.append("ProfileInventory corrupt file did not load normalized defaults.")
	var streak_profile: ProfileInventory = ProfileInventoryScript.new()
	streak_profile.record_run_result(_profile_result_fixture("victory", "showdown", "2026-07-01", 180, {}, "daily", "daily:one"))
	streak_profile.record_run_result(_profile_result_fixture("failure", RunStateScript.FAILURE_ABANDONED, "2026-07-01", 20, {}, "daily", "daily:repeat"))
	if int(streak_profile.daily_runs.get("current_streak", 0)) != 1:
		failures.append("ProfileInventory same-day daily repeat double-counted the streak.")
	streak_profile.record_run_result(_profile_result_fixture("victory", "showdown", "2026-07-02", 220, {}, "daily", "daily:two"))
	if int(streak_profile.daily_runs.get("current_streak", 0)) != 2 or int(streak_profile.daily_runs.get("best_streak", 0)) != 2:
		failures.append("ProfileInventory consecutive daily completion did not extend streak.")
	streak_profile.record_run_result(_profile_result_fixture("victory", "showdown", "2026-07-04", 240, {}, "daily", "daily:gap"))
	if int(streak_profile.daily_runs.get("current_streak", 0)) != 1:
		failures.append("ProfileInventory daily gap did not break current streak.")
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("PROFILE-INVENTORY-BOUNDARY")
	if run_state.to_dict().has("profile_inventory"):
		failures.append("Profile inventory leaked into RunState serialization.")
	var old_profile: ProfileInventory = ProfileInventoryScript.new()
	old_profile.from_dict({"schema_version": 2, "items": []})
	if int(old_profile.to_dict().get("act", 0)) != 1 or not _copy_dict(old_profile.to_dict().get("act_seam", {})).is_empty():
		failures.append("ProfileInventory markerless profile did not normalize Act 1 with empty act_seam.")
	if not old_profile.tips_seen.is_empty() or old_profile.tutorial_completed:
		failures.append("ProfileInventory legacy profile did not default coach fields compatibly.")
	_check_act_two_seam_payloads(failures)
	_remove_profile_inventory_test_file()
	OS.set_environment(ProfileInventoryScript.INVENTORY_PATH_ENV, "")


func _check_act_two_seam_payloads(failures: Array) -> void:
	var clean_run: RunState = RunStateScript.new()
	clean_run.start_new("ACT-TWO-SEAM-CLEAN")
	clean_run.begin_act(1)
	clean_run.bankroll = 575
	clean_run.story_flags["host_saw_clean_play"] = true
	clean_run.narrative_flags["demo_victory"] = true
	clean_run.narrative_flags["demo_victory_route"] = RunStateScript.GRAND_CASINO_HIGH_ROLLER_EVENT_ID
	clean_run.run_status = RunStateScript.RUN_STATUS_ENDED
	var clean_payload := clean_run.act_two_seam_payload()
	if str(clean_payload.get("victory_route", "")) != "players_card_cashout" or str(clean_payload.get("final_bankroll_band", "")) != "heavy_envelope":
		failures.append("Act 2 seam clean victory payload did not record route and bankroll band.")
	if not bool(_copy_dict(clean_payload.get("story_flags", {})).get("host_saw_clean_play", false)):
		failures.append("Act 2 seam clean victory payload did not carry story flags.")
	var showdown_run: RunState = RunStateScript.new()
	showdown_run.start_new("ACT-TWO-SEAM-SHOWDOWN")
	showdown_run.begin_act(1)
	showdown_run.bankroll = 45
	showdown_run.narrative_flags["demo_victory"] = true
	showdown_run.narrative_flags["demo_victory_route"] = RunStateScript.GRAND_CASINO_SHOWDOWN_ROUTE
	showdown_run.run_status = RunStateScript.RUN_STATUS_ENDED
	var showdown_payload := showdown_run.act_two_seam_payload()
	if str(showdown_payload.get("victory_route", "")) != "showdown" or str(showdown_payload.get("final_bankroll_band", "")) != "empty_pockets":
		failures.append("Act 2 seam showdown victory payload did not record route and bankroll band.")
	if JSON.stringify(_copy_dict(clean_payload.get("route_payload", {}))) == JSON.stringify(_copy_dict(showdown_payload.get("route_payload", {}))):
		failures.append("Act 2 seam route payloads were not distinct.")
	var failure_run: RunState = RunStateScript.new()
	failure_run.start_new("ACT-TWO-SEAM-FAILURE")
	failure_run.fail_run(RunStateScript.FAILURE_BANKROLL_ZERO)
	if not failure_run.act_two_seam_payload().is_empty():
		failures.append("Act 2 seam failure route wrote a cross-act payload.")


func _profile_result_fixture(outcome: String, route: String, completed_date: String, final_bankroll: int, games_played: Dictionary, mode: String = "standard", daily_id: String = "") -> Dictionary:
	return {
		"seed": "PROFILE-%s-%s" % [outcome, route],
		"route": route,
		"outcome": outcome,
		"failure_reason": route if outcome == "failure" else "",
		"final_bankroll": final_bankroll,
		"day_count": 2,
		"duration_actions": 12,
		"completed_date": completed_date,
		"completed_unix": 1780000000,
		"challenge_mode": mode,
		"daily_id": daily_id,
		"score": final_bankroll,
		"bankroll_delta": final_bankroll - RunStateScript.DEFAULT_BANKROLL,
		"bankroll_won": maxi(0, final_bankroll - RunStateScript.DEFAULT_BANKROLL),
		"bankroll_lost": maxi(0, RunStateScript.DEFAULT_BANKROLL - final_bankroll),
		"biggest_single_win": maxi(0, final_bankroll - RunStateScript.DEFAULT_BANKROLL),
		"games_played": games_played.duplicate(true),
	}


func _remove_profile_inventory_test_file() -> void:
	var path := ProfileInventoryScript.store_path()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _check_foundation_shell_no_game_specific_code(failures: Array) -> void:
	var shell_text := FileAccess.get_file_as_string("res://scripts/ui/foundation_main.gd")
	for token in [
		"slot_autoplay",
		"slot_spin",
		"slot_nudge",
		"slot_auto_toggle",
		"pull_tab",
		"claim_tab_ticket",
		"blackjack_",
		"video_poker_",
		"bar_dice_",
		"pinball",
	]:
		if shell_text.find(token) != -1:
			failures.append("Foundation UI shell contains game-specific token '%s'; route this through the GameModule contract instead." % token)
	var environment_canvas_text := FileAccess.get_file_as_string("res://scripts/ui/pixel_scene_canvas.gd")
	if environment_canvas_text.find("visual_key in [") != -1:
		failures.append("Environment canvas infers game prop layout from hardcoded visual keys; use game definition metadata instead.")
	var surface_canvas_text := FileAccess.get_file_as_string("res://scripts/ui/game_surface_canvas.gd")
	for token in [
		"pinball_slot",
		"pull_tab_machine",
		"slot_spin",
		"slot_nudge",
		"slot_auto_toggle",
		"pull_tab_buy",
		"pull_tab_peek",
		"pull_tab_reveal_next",
	]:
		if surface_canvas_text.find(token) != -1:
			failures.append("GameSurfaceCanvas contains game-specific token '%s'; route this through surface specs instead." % token)


func _check_production_game_module_load(library: ContentLibrary, run_state: RunState, environment: EnvironmentInstance, failures: Array) -> void:
	var game_id := str(environment.game_ids[0])
	if environment.game_ids.has("slot"):
		game_id = "slot"
	var definition := library.game(game_id)
	if definition.is_empty():
		failures.append("Smoke game id is not present in ContentLibrary: %s." % game_id)
		return
	var module_path := str(definition.get("module_path", ""))
	if module_path.is_empty():
		failures.append("Smoke game definition is missing module_path: %s." % game_id)
		return
	if module_path.begins_with("res://data/runtime/") or module_path.ends_with("_ui.gd"):
		failures.append("Smoke game module points at demo runtime/UI path: %s." % module_path)
		return
	var module_script: Script = load(module_path)
	if module_script == null:
		failures.append("Smoke game module could not be loaded: %s." % module_path)
		return
	var module_instance = module_script.new()
	if not module_instance is GameModule:
		failures.append("Smoke game module does not extend GameModule: %s." % module_path)
		return
	var game: GameModule = module_instance
	game.setup(definition, library)
	var environment_data := environment.to_dict()
	var enter_result := game.enter(run_state, environment_data)
	if not bool(enter_result.get("ok", false)):
		failures.append("Smoke game module did not enter cleanly: %s." % game_id)
	var action_presentation := game.actions(run_state, environment_data)
	var legal_actions: Array = action_presentation.get("legal_actions", [])
	var cheat_actions: Array = action_presentation.get("cheat_actions", [])
	if legal_actions.is_empty():
		failures.append("Smoke game module did not present a legal action: %s." % game_id)
	if cheat_actions.is_empty():
		failures.append("Smoke game module did not present a cheat action: %s." % game_id)
	var initial_run_snapshot := run_state.to_dict()
	var initial_environment_snapshot := environment_data.duplicate(true)
	if not legal_actions.is_empty():
		var legal_before := _run_state_result_snapshot(run_state)
		var legal_result := game.resolve(str(legal_actions[0].get("id", "")), 1, run_state, environment_data, run_state.create_rng())
		_check_action_result_shape(legal_result, "legal", failures)
		_check_action_result_application_contract(legal_before, run_state, legal_result, "legal smoke result", failures)
	if not cheat_actions.is_empty():
		var cheat_run_state: RunState = RunStateScript.new()
		cheat_run_state.from_dict(initial_run_snapshot)
		var cheat_environment := initial_environment_snapshot.duplicate(true)
		var cheat_before := _run_state_result_snapshot(cheat_run_state)
		var cheat_action_id := str(cheat_actions[0].get("id", ""))
		var cheat_result := game.resolve(cheat_action_id, 1, cheat_run_state, cheat_environment, cheat_run_state.create_rng())
		_check_action_result_shape(cheat_result, "cheat", failures, "smoke game %s action %s" % [game_id, cheat_action_id])
		_check_action_result_application_contract(cheat_before, cheat_run_state, cheat_result, "cheat smoke result", failures)


# Checks that specific game surfaces can expose interactive UI-local state without
# bypassing the shared GameModule/RunState result path.
func _check_game_surface_contracts(library: ContentLibrary, failures: Array) -> void:
	var blackjack: GameModule = _load_surface_contract_game(library, "blackjack", failures)
	if blackjack != null:
		_check_blackjack_surface_contract(blackjack, failures)
	var video_poker: GameModule = _load_surface_contract_game(library, "video_poker", failures)
	if video_poker != null:
		_check_video_poker_surface_contract(video_poker, failures)
	var roulette: GameModule = _load_surface_contract_game(library, "roulette", failures)
	if roulette != null:
		_check_roulette_surface_contract(roulette, failures, library)
	var baccarat: GameModule = _load_surface_contract_game(library, "baccarat", failures)
	if baccarat != null:
		_check_baccarat_surface_contract(baccarat, failures, library)
	var pull_tabs: GameModule = _load_surface_contract_game(library, "pull_tabs", failures)
	if pull_tabs != null:
		_check_pull_tabs_surface_contract(pull_tabs, failures)
	var scratch_tickets: GameModule = _load_surface_contract_game(library, "scratch_tickets", failures)
	if scratch_tickets != null:
		_check_scratch_tickets_surface_contract(scratch_tickets, failures)
	var bar_dice: GameModule = _load_surface_contract_game(library, "bar_dice", failures)
	if bar_dice != null:
		_check_bar_dice_surface_contract(bar_dice, failures)
	_check_process_fanout_guards(library, failures)


func _surface_requires_idle_animation_liveness(surface: Dictionary) -> bool:
	var renderer := str(surface.get("surface_renderer", ""))
	return ["blackjack", "roulette", "baccarat", "dice_table", "pull_tab_machine"].has(renderer) or bool(surface.get("surface_animates_idle", false))


func _check_process_fanout_guards(library: ContentLibrary, failures: Array) -> void:
	var app_value: Variant = MainScene.instantiate()
	if not app_value is Control:
		failures.append("Process fan-out guard fixture could not instantiate FoundationMain.")
		return
	var app: Control = app_value
	root.add_child(app)
	if not bool(app.call("uses_foundation_runtime")):
		app.call("_ready")
	if not bool(app.call("uses_foundation_runtime")):
		failures.append("Process fan-out guard fixture requires FoundationMain runtime nodes.")
		_sb4_dispose_app(app)
		return
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("PROCESS-FANOUT-GUARD")
	run_state.set_environment({
		"id": "process_fanout_fixture",
		"archetype_id": "fixture_room",
		"kind": "casino",
		"game_ids": ["slot"],
		"game_states": {},
	})
	app.set("run_state", run_state)
	app.set("current_game", null)
	app.set("environment_game_runtime_scan_count", 0)
	app.call("_set_current_screen", "START")
	app.call("_process", 1.0 / 60.0)
	if int(app.get("environment_game_runtime_scan_count")) != 0:
		failures.append("Process fan-out scanned environment games on the start/menu screen.")
	app.set("meta_session_active", true)
	app.call("_set_current_screen", "ENVIRONMENT")
	app.call("_process", 1.0 / 60.0)
	if int(app.get("environment_game_runtime_scan_count")) != 0:
		failures.append("Process fan-out scanned environment games during a meta session.")
	app.set("meta_session_active", false)
	run_state.current_environment["game_ids"] = []
	app.call("_process", 1.0 / 60.0)
	if int(app.get("environment_game_runtime_scan_count")) != 0:
		failures.append("Process fan-out scanned an environment with no runtime-capable game ids.")
	_sb4_dispose_app(app)


func _idle_animation_sample_from_canvas(canvas: Control) -> int:
	var flicker := float(canvas.call("surface_flicker")) if canvas.has_method("surface_flicker") else 0.0
	return int(round((sin(flicker * 2.1) + sin(flicker * 3.7)) * 100000.0))


func _check_idle_animation_liveness_contract(surface: Dictionary, label: String, failures: Array) -> void:
	if not _surface_requires_idle_animation_liveness(surface):
		return
	if not bool(surface.get("surface_animates_idle", false)):
		failures.append("%s uses time-based idle motion but does not declare surface_animates_idle." % label)
	var canvas: Control = GameSurfaceCanvasScript.new()
	canvas.size = Vector2(ArtContractsScript.GAME_BOARD_SIZE)
	root.add_child(canvas)
	canvas.call("render_game_snapshot", surface)
	if canvas.has_method("reset_performance_counters"):
		canvas.call("reset_performance_counters")
	var before_snapshot: Dictionary = canvas.call("surface_runtime_status")
	var before_redraw_count := int(before_snapshot.get("surface_animation_redraw_count", 0))
	var first_sample := _idle_animation_sample_from_canvas(canvas)
	for _frame_index in range(12):
		canvas.call("debug_advance_idle_liveness", 1.0 / 60.0)
	var after_snapshot: Dictionary = canvas.call("surface_runtime_status")
	var after_redraw_count := int(after_snapshot.get("surface_animation_redraw_count", 0))
	var second_sample := _idle_animation_sample_from_canvas(canvas)
	if after_redraw_count <= before_redraw_count:
		failures.append("%s idle animation did not schedule redraws with zero input." % label)
	if first_sample == second_sample:
		failures.append("%s idle animation sample did not advance over simulated time." % label)
	root.remove_child(canvas)
	canvas.free()


func _check_surface_visual_motion_advances(game: GameModule, surface: Dictionary, label: String, failures: Array) -> void:
	var canvas: Control = GameSurfaceCanvasScript.new()
	canvas.size = Vector2(ArtContractsScript.GAME_BOARD_SIZE)
	root.add_child(canvas)
	canvas.call("set_game_module", game)
	canvas.call("render_game_snapshot", surface)
	if canvas.has_method("reset_performance_counters"):
		canvas.call("reset_performance_counters")
	var before_status: Dictionary = canvas.call("surface_runtime_status")
	var before_sample: Dictionary = canvas.call("debug_surface_motion_sample")
	for _frame_index in range(18):
		canvas.call("debug_advance_idle_liveness", 1.0 / 60.0)
	var after_status: Dictionary = canvas.call("surface_runtime_status")
	var after_sample: Dictionary = canvas.call("debug_surface_motion_sample")
	var allows_state_time_fallback := str(surface.get("surface_renderer", "")) != "roulette"
	if JSON.stringify(before_sample) == JSON.stringify(after_sample) and allows_state_time_fallback and surface.has("surface_time_msec"):
		var advanced_surface := surface.duplicate(true)
		advanced_surface["surface_time_msec"] = int(advanced_surface.get("surface_time_msec", 0)) + 300
		canvas.call("render_game_snapshot", advanced_surface)
		after_sample = canvas.call("debug_surface_motion_sample")
	if int(after_status.get("surface_animation_redraw_count", 0)) <= int(before_status.get("surface_animation_redraw_count", 0)):
		failures.append("%s did not schedule redraws across the table surface lifecycle." % label)
	if JSON.stringify(before_sample) == JSON.stringify(after_sample):
		failures.append("%s visual motion sample did not advance across the table surface lifecycle." % label)
	root.remove_child(canvas)
	canvas.free()


func _check_table_environment_entry_contracts(library: ContentLibrary, failures: Array) -> void:
	var app_value: Variant = MainScene.instantiate()
	if not app_value is Control:
		failures.append("Table environment entry contract could not instantiate FoundationMain.")
		return
	var app: Control = app_value
	root.add_child(app)
	if not bool(app.call("uses_foundation_runtime")):
		app.call("_ready")
	if not bool(app.call("uses_foundation_runtime")):
		failures.append("Table environment entry contract requires FoundationMain runtime nodes.")
		_sb4_dispose_app(app)
		return

	for game_id in ["roulette", "blackjack", "baccarat", "bar_dice"]:
		_check_single_table_environment_entry_contract(library, app, str(game_id), failures)

	_sb4_dispose_app(app)


func _check_single_table_environment_entry_contract(library: ContentLibrary, app: Control, game_id: String, failures: Array) -> void:
	var game: GameModule = _load_surface_contract_game(library, game_id, failures)
	if game == null:
		return
	var archetype := _first_archetype_with_game(library, game_id)
	if archetype.is_empty():
		failures.append("Table environment entry contract could not find an environment archetype for %s." % game_id)
		return

	var run_state: RunState = RunStateScript.new()
	run_state.start_new("TABLE-ENV-ENTRY-%s" % game_id.to_upper())
	run_state.bankroll = 500
	var environment_instance := EnvironmentInstance.from_archetype(archetype, 1, run_state.create_rng("table_env:%s" % game_id), library)
	var environment := environment_instance.to_dict()
	environment["game_ids"] = [game_id]
	environment["game_states"] = {}
	var generated_state := game.generate_environment_state(run_state, environment, run_state.create_rng("table_state:%s" % game_id))
	if typeof(generated_state) == TYPE_DICTIONARY and not generated_state.is_empty():
		var game_states: Dictionary = {}
		game_states[game_id] = (generated_state as Dictionary).duplicate(true)
		environment["game_states"] = game_states
	environment["layout"] = EnvironmentInstance.ensure_generated_layout(environment)

	var object_id := "game:%s" % game_id
	var layout_value: Variant = environment.get("layout", {})
	var layout: Dictionary = layout_value if typeof(layout_value) == TYPE_DICTIONARY else {}
	var object_rects_value: Variant = layout.get("object_rects", {})
	var object_rects: Dictionary = object_rects_value if typeof(object_rects_value) == TYPE_DICTIONARY else {}
	var object_rect := _layout_rect_from_dict(object_rects.get(object_id, {}))
	if object_rect.size.x <= 0.0 or object_rect.size.y <= 0.0:
		failures.append("Table environment entry contract missing clickable room object for %s." % game_id)
		return

	run_state.set_environment(environment)
	if run_state.grand_casino_table_uses_chips(game_id, environment):
		run_state.buy_grand_casino_chips(250, run_state.grand_casino_chip_exchange_rate())
	app.set("run_state", run_state)
	app.set("current_game", null)
	app.set("last_game_result", {})
	app.call("_set_current_screen", "ENVIRONMENT")
	app.call("_refresh")
	var before_enter := JSON.stringify(run_state.to_dict())
	app.call("enter_game", game_id)
	var after_enter := JSON.stringify(run_state.to_dict())
	if before_enter != after_enter:
		failures.append("Table environment entry mutated RunState before player action for %s." % game_id)

	var screen_value: Variant = app.get("current_screen")
	if str(screen_value) != "GAME":
		failures.append("Table environment entry did not switch to game screen for %s." % game_id)
	var active_game_value: Variant = app.get("current_game")
	if not active_game_value is GameModule:
		failures.append("Table environment entry did not keep an active GameModule for %s." % game_id)
	else:
		var active_game: GameModule = active_game_value
		if active_game.get_id() != game_id:
			failures.append("Table environment entry opened %s instead of %s." % [active_game.get_id(), game_id])

	var snapshot_value: Variant = app.call("current_game_view_snapshot")
	var snapshot: Dictionary = snapshot_value if typeof(snapshot_value) == TYPE_DICTIONARY else {}
	if str(snapshot.get("game_id", "")) != game_id:
		failures.append("Table environment entry snapshot did not expose %s." % game_id)
	if str(snapshot.get("surface_renderer", "")).is_empty() or str(snapshot.get("surface_life", "")).is_empty():
		failures.append("Table environment entry snapshot missing table surface metadata for %s." % game_id)
	var legal_actions_value: Variant = snapshot.get("legal_actions", [])
	var legal_actions: Array = legal_actions_value if typeof(legal_actions_value) == TYPE_ARRAY else []
	if legal_actions.is_empty():
		failures.append("Table environment entry has no visible legal action for %s." % game_id)
	_check_idle_surface_automation_snapshot_contract(app, game_id, failures)

	var actions := game.actions(run_state, run_state.current_environment)
	var module_legal_value: Variant = actions.get("legal_actions", [])
	var module_legal_actions: Array = module_legal_value if typeof(module_legal_value) == TYPE_ARRAY else []
	var action_id := _first_action_id(module_legal_actions)
	if action_id.is_empty():
		failures.append("Table environment entry could not find a resolvable action for %s." % game_id)
		return
	var wager_balance := run_state.wager_balance_for_game(game_id, run_state.current_environment)
	var stake := clampi(int(snapshot.get("stake_min", actions.get("stake_floor", 1))), 1, maxi(1, wager_balance))
	var result := game.resolve_with_context(action_id, stake, run_state, run_state.current_environment, run_state.create_rng("table_resolve:%s" % game_id), {})
	if not bool(result.get("ok", false)):
		failures.append("Table environment explicit action did not resolve for %s action %s: %s" % [game_id, action_id, str(result.get("message", "no result message"))])
	if str(app.get("current_screen")) != "GAME":
		failures.append("Table environment explicit module resolve should not auto-close the UI for %s." % game_id)


func _check_idle_surface_automation_snapshot_contract(app: Control, game_id: String, failures: Array) -> void:
	var canvas_value: Variant = app.get("game_surface_canvas")
	if not canvas_value is Control:
		failures.append("Idle automation snapshot contract could not inspect the game canvas for %s." % game_id)
		return
	var canvas: Control = canvas_value
	if not canvas.has_method("reset_performance_counters") or not canvas.has_method("performance_counters"):
		failures.append("Idle automation snapshot contract missing canvas performance counters for %s." % game_id)
		return
	canvas.call("reset_performance_counters")
	for _frame_index in range(8):
		app.call("_advance_game_surface_automation")
	var counters_value: Variant = canvas.call("performance_counters")
	var counters: Dictionary = counters_value if typeof(counters_value) == TYPE_DICTIONARY else {}
	if int(counters.get("full_snapshot_calls", 0)) != 0:
		failures.append("Idle automation rebuilt full game snapshots for %s." % game_id)
	if int(counters.get("runtime_status_calls", 0)) != 0:
		failures.append("Idle automation queried canvas runtime status for %s instead of using the zero-copy tick state." % game_id)


func _first_action_id(actions: Array) -> String:
	for action_value in actions:
		if typeof(action_value) != TYPE_DICTIONARY:
			continue
		var action: Dictionary = action_value
		var action_id := str(action.get("id", "")).strip_edges()
		if not action_id.is_empty():
			return action_id
	return ""


func _load_surface_contract_game(library: ContentLibrary, game_id: String, failures: Array):
	var definition := library.game(game_id)
	if definition.is_empty():
		failures.append("Surface contract game is missing from ContentLibrary: %s." % game_id)
		return null
	var module_path := str(definition.get("module_path", ""))
	if module_path.is_empty():
		failures.append("Surface contract game is missing module_path: %s." % game_id)
		return null
	var module_script: Script = load(module_path)
	if module_script == null:
		failures.append("Surface contract game module could not be loaded: %s." % module_path)
		return null
	var module_instance = module_script.new()
	if not module_instance is GameModule:
		failures.append("Surface contract game module does not extend GameModule: %s." % module_path)
		return null
	var game: GameModule = module_instance
	game.setup(definition, library)
	return game


func _check_target_game_suite(library: ContentLibrary, game_id: String, failures: Array) -> void:
	match game_id:
		"blackjack":
			var blackjack: GameModule = _load_surface_contract_game(library, "blackjack", failures)
			if blackjack != null:
				_check_blackjack_surface_contract(blackjack, failures)
		"roulette":
			var roulette: GameModule = _load_surface_contract_game(library, "roulette", failures)
			if roulette != null:
				_check_roulette_surface_contract(roulette, failures, library)
		"baccarat":
			var baccarat: GameModule = _load_surface_contract_game(library, "baccarat", failures)
			if baccarat != null:
				_check_baccarat_surface_contract(baccarat, failures, library)
		"video_poker":
			var video_poker: GameModule = _load_surface_contract_game(library, "video_poker", failures)
			if video_poker != null:
				_check_video_poker_surface_contract(video_poker, failures)
			_check_video_poker_contract(library, failures)
		"bar_dice":
			_check_bar_dice_contract(library, failures)
		"pull_tabs":
			var pull_tabs: GameModule = _load_surface_contract_game(library, "pull_tabs", failures)
			if pull_tabs != null:
				_check_pull_tabs_surface_contract(pull_tabs, failures)
		"scratch_tickets":
			var scratch_tickets: GameModule = _load_surface_contract_game(library, "scratch_tickets", failures)
			if scratch_tickets != null:
				_check_scratch_tickets_surface_contract(scratch_tickets, failures)
		_:
			failures.append("Unknown target game suite: %s." % game_id)


func _check_slot_contract_smoke(library: ContentLibrary, failures: Array) -> void:
	var definition := library.game("slot")
	if definition.is_empty():
		failures.append("Slot contract smoke requires the production slot definition.")
		return
	print("SLOT_CONTRACT_SMOKE single_apply")
	_check_slot_single_apply_economy(library, definition, failures)
	print("SLOT_CONTRACT_SMOKE schema")
	_check_slot_outcome_schema(definition, failures)
	print("SLOT_CONTRACT_SMOKE skin_geometry")
	_check_slot_skin_geometry(definition, failures)
	print("SLOT_CONTRACT_SMOKE counts")
	_check_slot_generation_counts(definition, failures)
	print("SLOT_CONTRACT_SMOKE determinism")
	_check_slot_determinism(library, definition, failures)
	print("SLOT_CONTRACT_SMOKE buffalo_symbol_variety")
	_check_slot_buffalo_symbol_variety(definition, failures)
	print("SLOT_CONTRACT_SMOKE payout_variety")
	_check_slot_payout_variety(definition, failures)
	print("SLOT_CONTRACT_SMOKE reel_display_consistency")
	_check_slot_reel_display_consistency(definition, failures)
	print("SLOT_CONTRACT_SMOKE buffalo_full_span_lines")
	_check_slot_buffalo_full_span_lines(definition, failures)
	print("SLOT_CONTRACT_SMOKE buffalo_timed_nudge")
	_check_slot_buffalo_timed_nudge(definition, failures)
	print("SLOT_CONTRACT_SMOKE nudge_chain_determinism")
	call("_check_slot_nudge_chain_determinism", definition, failures)
	print("SLOT_CONTRACT_SMOKE item_pack_effects")
	_check_slot_item_pack_effects(library, definition, failures)
	print("SLOT_CONTRACT_SMOKE cabinet_distinctness")
	_check_slot_cabinet_distinctness(library, definition, failures)
	print("SLOT_CONTRACT_SMOKE environment_preview")
	_check_slot_environment_preview(library, definition, failures)
	print("SLOT_CONTRACT_SMOKE autoplay_toggle")
	_check_slot_autoplay_toggle(library, definition, failures)
	print("SLOT_CONTRACT_SMOKE animation_present")
	_check_slot_animation_present(library, definition, failures)
	print("SLOT_CONTRACT_SMOKE hold_fill_scaling")
	_check_slot_hold_and_spin_fill_scaling(definition, failures)
	print("SLOT_CONTRACT_SMOKE free_games_carryover")
	_check_slot_free_games_carryover(definition, failures)
	print("SLOT_CONTRACT_SMOKE buffalo_feature_presentation")
	_check_slot_buffalo_feature_presentation(definition, failures)
	print("SLOT_CONTRACT_SMOKE bonus_completion_recovery")
	_check_slot_bonus_completion_recovery(library, definition, failures)
	print("SLOT_CONTRACT_SMOKE pinball_sim_physics")
	_check_slot_pinball_sim_physics(definition, failures)
	print("SLOT_CONTRACT_SMOKE economy_rng_discipline")
	_check_slot_economy_rng_discipline(failures)


func _check_slot_acceptance(library: ContentLibrary, failures: Array) -> void:
	var definition := library.game("slot")
	if definition.is_empty():
		failures.append("Slot acceptance requires the production slot definition.")
		return
	print("SLOT_ACCEPTANCE single_apply")
	_check_slot_single_apply_economy(library, definition, failures)
	print("SLOT_ACCEPTANCE gold_buffalo")
	_check_slot_gold_buffalo_collection(library, definition, failures)
	print("SLOT_ACCEPTANCE nudge_ev")
	_check_slot_nudge_ev(library, definition, failures)
	print("SLOT_ACCEPTANCE reachability")
	_check_slot_reachability(library, definition, failures)
	print("SLOT_ACCEPTANCE skin_geometry")
	_check_slot_skin_geometry(definition, failures)
	print("SLOT_ACCEPTANCE counts")
	_check_slot_generation_counts(definition, failures)
	print("SLOT_ACCEPTANCE monte_carlo")
	_check_slot_monte_carlo(definition, failures)
	print("SLOT_ACCEPTANCE payout_variety")
	_check_slot_payout_variety(definition, failures)
	print("SLOT_ACCEPTANCE determinism")
	_check_slot_determinism(library, definition, failures)
	print("SLOT_ACCEPTANCE reel_display_consistency")
	_check_slot_reel_display_consistency(definition, failures)
	print("SLOT_ACCEPTANCE buffalo_full_span_lines")
	_check_slot_buffalo_full_span_lines(definition, failures)
	print("SLOT_ACCEPTANCE buffalo_timed_nudge")
	_check_slot_buffalo_timed_nudge(definition, failures)
	print("SLOT_ACCEPTANCE nudge_chain_determinism")
	call("_check_slot_nudge_chain_determinism", definition, failures)
	print("SLOT_ACCEPTANCE item_pack_effects")
	_check_slot_item_pack_effects(library, definition, failures)
	print("SLOT_ACCEPTANCE feature_reachability")
	_check_slot_feature_reachability(library, definition, failures)
	print("SLOT_ACCEPTANCE bonus_trigger_reveal_order")
	_check_slot_bonus_trigger_reveal_order(definition, failures)
	print("SLOT_ACCEPTANCE cabinet_distinctness")
	_check_slot_cabinet_distinctness(library, definition, failures)
	print("SLOT_ACCEPTANCE environment_preview")
	_check_slot_environment_preview(library, definition, failures)
	print("SLOT_ACCEPTANCE animation_present")
	_check_slot_animation_present(library, definition, failures)
	print("SLOT_ACCEPTANCE reel_win_manifest")
	_check_slot_reel_win_manifest(definition, failures)
	print("SLOT_ACCEPTANCE attract_mode")
	_check_slot_attract_mode(library, definition, failures)
	print("SLOT_ACCEPTANCE live_features")
	_check_slot_live_generated_features(library, definition, failures)
	print("SLOT_ACCEPTANCE bonus_completion_recovery")
	_check_slot_bonus_completion_recovery(library, definition, failures)
	print("SLOT_ACCEPTANCE hold_fill_scaling")
	_check_slot_hold_and_spin_fill_scaling(definition, failures)
	print("SLOT_ACCEPTANCE free_games_carryover")
	_check_slot_free_games_carryover(definition, failures)
	print("SLOT_ACCEPTANCE buffalo_feature_presentation")
	_check_slot_buffalo_feature_presentation(definition, failures)
	print("SLOT_ACCEPTANCE pinball_escalation")
	_check_slot_pinball_escalation(definition, failures)
	print("SLOT_ACCEPTANCE pinball_feature_physics")
	_check_slot_pinball_feature_physics(definition, failures)
	print("SLOT_ACCEPTANCE video_pinball_feature_event")
	_check_slot_video_pinball_feature_event(definition, failures)
	print("SLOT_ACCEPTANCE pinball_feature_visual_manifest")
	_check_slot_pinball_feature_visual_manifest(definition, failures)
	print("SLOT_ACCEPTANCE pinball_launch_hit_regions")
	_check_slot_pinball_launch_hit_regions(failures)
	print("SLOT_ACCEPTANCE pinball_sim_physics")
	_check_slot_pinball_sim_physics(definition, failures)
	print("SLOT_ACCEPTANCE economy_rng_discipline")
	_check_slot_economy_rng_discipline(failures)
	print("SLOT_ACCEPTANCE feature_subsimulation")
	_check_slot_feature_subsimulation(definition, failures)


func _check_slot_single_apply_economy(library: ContentLibrary, definition: Dictionary, failures: Array) -> void:
	var game: GameModule = _slot_game(library, failures)
	if game == null:
		return
	var run_state: RunState = _slot_run_state("SLOT-SINGLE-APPLY", 100000)
	var environment: Dictionary = _slot_environment()
	var machine: Dictionary = _slot_machine(definition, run_state, "pinball", "classic_3_reel", "standard", "plain")
	_slot_store_machine(run_state, environment, machine)
	var before_bankroll := run_state.bankroll
	var rng: RngStream = run_state.create_rng("slot_single_apply")
	var result: Dictionary = game.resolve_with_context("spin", 10, run_state, environment, rng, {})
	_check_action_result_shape(result, "legal", failures)
	var expected_delta := int(result.get("slot_payout", 0)) - int(result.get("slot_stake_cost", 0))
	if int(result.get("bankroll_delta", 0)) != expected_delta:
		failures.append("Slot single-apply result delta did not equal payout minus stake cost.")
	if run_state.bankroll != before_bankroll:
		failures.append("Slot resolve mutated bankroll before host apply.")
	GameModule.apply_result(run_state, result, rng)
	if run_state.bankroll != before_bankroll + expected_delta:
		failures.append("Slot host apply did not change bankroll exactly once.")


func _check_slot_gold_buffalo_collection(library: ContentLibrary, definition: Dictionary, failures: Array) -> void:
	var game: GameModule = _slot_game(library, failures)
	if game == null:
		return
	var run_state: RunState = _slot_run_state("SLOT-GOLD-BUFFALO", 10000000)
	var environment: Dictionary = _slot_environment()
	var machine: Dictionary = _slot_machine(definition, run_state, "buffalo", "line_5x3", "standard", "plain")
	_slot_store_machine(run_state, environment, machine)
	var rng: RngStream = run_state.create_rng("slot_gold_buffalo_collection")
	for _spin_index in range(10000):
		var result: Dictionary = game.resolve_with_context("spin", 10, run_state, environment, rng, {})
		if bool(result.get("ok", false)):
			GameModule.apply_result(run_state, result, rng)
		_slot_complete_active_bonus(game, run_state, environment, rng)
	var final_machine: Dictionary = SlotMachineStateScript.read_machine(environment, "slot")
	var bonus_state: Dictionary = _slot_dict(final_machine.get("bonus_state", {}))
	var total_collected := int(bonus_state.get("gold_buffalo_total_collected", 0))
	if total_collected <= 0:
		failures.append("Gold Buffalo collection did not advance over 10,000 paid base spins.")
	if not _slot_gold_buffalo_conversion_fixture(definition):
		failures.append("Gold Buffalo conversion fixture did not convert a ready collection meter.")


func _slot_gold_buffalo_conversion_fixture(definition: Dictionary) -> bool:
	var buffalo = SlotFamilyBuffaloScript.new()
	var machine := {
		"type_id": "buffalo",
		"format_id": "line_5x3",
		"row_count": 3,
		"reel_count": 5,
		"bet_ladder": {"selected_id": "bet_10", "selected_total": 10},
		"bonus_state": {
			"per_bet": {
				"bet_10": {
					"gold_buffalo_heads": 14,
					"gold_buffalo_max_seen": 14,
					"must_hit_meter": 100,
					"must_hit_ready": false,
					"feature_completion_count": 0,
				},
			},
			"gold_buffalo_total_collected": 14,
			"gold_buffalo_conversions": 0,
		},
	}
	var grid: Array = [
		["ELK", "A", "Q"],
		["ELK", "K", "J"],
		["ELK", "Q", "10"],
		["ELK", "J", "A"],
		["ELK", "10", "K"],
	]
	var cells: Array = []
	for reel_index in range(5):
		cells.append({"reel": reel_index, "row": 0})
	var entry := {
		"id": "true_win",
		"classification": "true_win",
		"forced_placement": {"kind": "line", "symbol": "ELK", "cells": cells, "line_index": 0},
	}
	var side_effects: Dictionary = buffalo.apply_grid_side_effects(machine, grid, 10, entry, definition)
	var converted_grid: Array = _slot_array(side_effects.get("grid", []))
	var converted_count := 0
	for cell_value in cells:
		var cell: Dictionary = _slot_dict(cell_value)
		if _slot_grid_symbol(converted_grid, int(cell.get("reel", -1)), int(cell.get("row", -1))) == "BUFFALO":
			converted_count += 1
	var converted_state: Dictionary = _slot_dict(_slot_dict(machine.get("bonus_state", {})).get("per_bet", {}))
	var converted_bucket: Dictionary = _slot_dict(converted_state.get("bet_10", {}))
	return bool(side_effects.get("conversion", false)) and converted_count == cells.size() and int(converted_bucket.get("gold_buffalo_heads", -1)) == 0


func _check_slot_nudge_ev(library: ContentLibrary, definition: Dictionary, failures: Array) -> void:
	var game: GameModule = _slot_game(library, failures)
	if game == null:
		return
	var run_state: RunState = _slot_run_state("SLOT-NUDGE-EV", 1000000)
	var environment: Dictionary = _slot_environment()
	var machine: Dictionary = _slot_machine(definition, run_state, "pinball", "classic_3_reel", "standard", "plain")
	_slot_store_machine(run_state, environment, machine)
	var rng: RngStream = run_state.create_rng("slot_nudge_ev")
	var samples := 0
	var attempts := 0
	var total_nudge_delta := 0
	while samples < 20 and attempts < 50000:
		var spin_result: Dictionary = game.resolve_with_context("spin", 10, run_state, environment, rng, {})
		attempts += 1
		if bool(spin_result.get("ok", false)):
			GameModule.apply_result(run_state, spin_result, rng)
		_slot_complete_active_bonus(game, run_state, environment, rng)
		if str(spin_result.get("slot_classification", "")) != "near_miss":
			continue
		var before_bankroll := run_state.bankroll
		var nudge_machine: Dictionary = _slot_dict(SlotMachineStateScript.read_machine(environment, "slot"))
		var nudge_offer: Dictionary = _slot_dict(nudge_machine.get("last_nudge_offer", {}))
		var nudge_window: Dictionary = _slot_dict(nudge_offer.get("skill_window_msec", {}))
		var perfect_msec := int(nudge_window.get("perfect", -1))
		if perfect_msec < 0:
			failures.append("Slot nudge EV near miss did not expose a coin-chain perfect window.")
			continue
		var nudge_result: Dictionary = game.resolve_with_context("nudge", 10, run_state, environment, rng, {"slot_nudge_chain_input_msec": perfect_msec})
		if int(nudge_result.get("suspicion_delta", 0)) < 12:
			failures.append("Slot nudge did not emit at least its base suspicion heat.")
		if bool(nudge_result.get("ok", false)):
			GameModule.apply_result(run_state, nudge_result, rng)
		_slot_complete_active_bonus(game, run_state, environment, rng)
		total_nudge_delta += run_state.bankroll - before_bankroll
		samples += 1
	if samples <= 0:
		failures.append("Slot nudge EV test did not encounter a near miss.")
	elif float(total_nudge_delta) / float(samples) <= 0.0:
		failures.append("Slot nudge EV was not positive versus declining near misses.")


func _check_slot_reachability(library: ContentLibrary, definition: Dictionary, failures: Array) -> void:
	_check_slot_outcome_schema(definition, failures)
	var game: GameModule = _slot_game(library, failures)
	if game == null:
		return
	var coverage: Dictionary = {}
	for family_id in ["pinball", "buffalo"]:
		for format_id in ["classic_3_reel", "line_5x3", "video_feature"]:
			var run_state: RunState = _slot_run_state("SLOT-BRANCH-%s-%s" % [family_id, format_id], 100000)
			var environment: Dictionary = _slot_environment()
			var machine: Dictionary = _slot_machine(definition, run_state, family_id, format_id, "standard", "plain")
			_slot_store_machine(run_state, environment, machine)
			var rng: RngStream = run_state.create_rng("slot_branch_%s_%s" % [family_id, format_id])
			var result: Dictionary = game.resolve_with_context("spin", 10, run_state, environment, rng, {})
			if bool(result.get("ok", false)):
				coverage["%s:%s" % [family_id, format_id]] = true
				GameModule.apply_result(run_state, result, rng)
				_slot_complete_active_bonus(game, run_state, environment, rng)
	for expected_key in ["pinball:classic_3_reel", "pinball:line_5x3", "pinball:video_feature", "buffalo:classic_3_reel", "buffalo:line_5x3", "buffalo:video_feature"]:
		if not bool(coverage.get(expected_key, false)):
			failures.append("Slot family/format branch was not reachable: %s." % expected_key)
	_check_slot_outcome_rows_reachable(game, definition, failures)
	_check_slot_shot_rows_reachable(game, definition, failures)


func _check_slot_outcome_schema(definition: Dictionary, failures: Array) -> void:
	for table_value in [_slot_array(_slot_dict(definition.get("slot_pinball_config", {})).get("outcome_table", []))]:
		var table: Array = table_value
		for entry_value in table:
			var entry: Dictionary = _slot_dict(entry_value)
			var payout_fields := 0
			if entry.has("payout"):
				payout_fields += 1
			if entry.has("payout_multiplier"):
				payout_fields += 1
			if payout_fields != 1:
				failures.append("Slot outcome row must carry exactly one payout field: %s." % str(entry.get("id", "")))
			if entry.has("literal_payout") or entry.has("overridden_payout") or entry.has("payout_rule"):
				failures.append("Slot outcome row carries an overridden literal payout: %s." % str(entry.get("id", "")))
	var buffalo_tables: Dictionary = _slot_dict(_slot_dict(definition.get("slot_buffalo_config", {})).get("outcome_tables", {}))
	for table_id in buffalo_tables.keys():
		for entry_value in _slot_array(buffalo_tables.get(table_id, [])):
			var entry: Dictionary = _slot_dict(entry_value)
			var payout_fields := 0
			if entry.has("payout"):
				payout_fields += 1
			if entry.has("payout_multiplier"):
				payout_fields += 1
			if payout_fields != 1:
				failures.append("Slot outcome row must carry exactly one payout field: %s/%s." % [str(table_id), str(entry.get("id", ""))])
			if entry.has("literal_payout") or entry.has("overridden_payout") or entry.has("payout_rule"):
				failures.append("Slot outcome row carries an overridden literal payout: %s/%s." % [str(table_id), str(entry.get("id", ""))])


func _check_slot_outcome_rows_reachable(game: GameModule, definition: Dictionary, failures: Array) -> void:
	var scenarios := [
		{"family": "pinball", "format": "classic_3_reel", "ids": _slot_ids(_slot_array(_slot_dict(definition.get("slot_pinball_config", {})).get("outcome_table", [])))},
		{"family": "buffalo", "format": "line_5x3", "ids": _slot_ids(_slot_array(_slot_dict(_slot_dict(definition.get("slot_buffalo_config", {})).get("outcome_tables", {})).get("base", [])))},
		{"family": "buffalo", "format": "video_feature", "ids": _slot_ids(_slot_array(_slot_dict(_slot_dict(definition.get("slot_buffalo_config", {})).get("outcome_tables", {})).get("video_feature", [])))},
	]
	for scenario_value in scenarios:
		var scenario: Dictionary = scenario_value
		var family_id := str(scenario.get("family", "pinball"))
		var format_id := str(scenario.get("format", "classic_3_reel"))
		var required: Array = _slot_array(scenario.get("ids", []))
		var seen: Dictionary = {}
		var run_state: RunState = _slot_run_state("SLOT-OUTCOMES-%s-%s" % [family_id, format_id], 10000000)
		var environment: Dictionary = _slot_environment()
		var machine: Dictionary = _slot_machine(definition, run_state, family_id, format_id, "standard", "plain")
		_slot_store_machine(run_state, environment, machine)
		var rng: RngStream = run_state.create_rng("slot_outcomes_%s_%s" % [family_id, format_id])
		var guard := 0
		while seen.size() < required.size() and guard < 90000:
			var result: Dictionary = game.resolve_with_context("spin", 10, run_state, environment, rng, {})
			guard += 1
			if bool(result.get("ok", false)):
				seen[str(result.get("slot_outcome_id", ""))] = true
				GameModule.apply_result(run_state, result, rng)
			_slot_complete_active_bonus(game, run_state, environment, rng)
		for outcome_id in required:
			if not bool(seen.get(str(outcome_id), false)):
				failures.append("Slot outcome row was not reached by real spins: %s %s %s." % [family_id, format_id, str(outcome_id)])


func _check_slot_shot_rows_reachable(_game: GameModule, definition: Dictionary, failures: Array) -> void:
	var source := FileAccess.get_file_as_string("res://scripts/games/slots/slot_family_pinball.gd")
	if source.find("_biased_shot_table") != -1 or source.find("MathScript.weighted_pick(table") != -1:
		failures.append("Slot pinball feature resolver still contains the old weighted shot-table path.")
	for scenario_value in [
		{"format": "classic_3_reel", "mode": "em_bumper_drop", "inputs": ["slot_bonus_left"]},
		{"format": "line_5x3", "mode": "lane_multiball", "inputs": ["slot_bonus_left", "slot_bonus_right"]},
		{"format": "video_feature", "mode": "video_feature", "inputs": ["slot_bonus_right", "slot_bonus_right"]},
	]:
		var scenario: Dictionary = scenario_value
		var sample: Dictionary = _slot_pinball_feature_sample(definition, str(scenario.get("format", "")), _slot_array(scenario.get("inputs", [])), "SLOT-PHYSICS-REACH-%s" % str(scenario.get("mode", "")))
		var active: Dictionary = _slot_dict(sample.get("active_bonus", {}))
		var events: Array = _slot_array(active.get("event_log", []))
		if events.is_empty():
			failures.append("Slot pinball physics feature did not log element events for %s." % str(scenario.get("mode", "")))
			continue
		if _slot_event_type_count(events) < 2:
			failures.append("Slot pinball physics feature did not hit multiple element types for %s." % str(scenario.get("mode", "")))
		var total_from_events := _slot_pinball_logged_award(events)
		var capped_total := mini(total_from_events, int(active.get("session_cap", 0)))
		if int(active.get("awarded", active.get("feature_total", 0))) != capped_total:
			failures.append("Slot pinball physics feature award did not equal logged event awards for %s." % str(scenario.get("mode", "")))


func _check_slot_skin_geometry(definition: Dictionary, failures: Array) -> void:
	var catalog = SlotCatalogScript.new()
	for skin_value in catalog.all_skins(definition):
		var skin: Dictionary = _slot_dict(skin_value)
		var family_id := str(skin.get("family", ""))
		var format_id := str(skin.get("format_id", ""))
		var geometry: Dictionary = SlotMachineStateScript.canonical_geometry(definition, family_id, format_id)
		if int(skin.get("reel_count", 0)) != int(geometry.get("reel_count", 0)) or int(skin.get("row_count", 0)) != int(geometry.get("row_count", 0)):
			failures.append("Slot skin geometry does not match canonical geometry: %s/%s." % [family_id, format_id])


func _check_slot_generation_counts(definition: Dictionary, failures: Array) -> void:
	var generation: Dictionary = _slot_dict(definition.get("slot_generation", {}))
	var behavior_count := SlotMachineStateScript.behavior_combo_count(definition)
	var visual_count := SlotMachineStateScript.visual_machine_count(definition)
	if behavior_count != 72 or int(generation.get("behavior_combo_count", 0)) != behavior_count:
		failures.append("Slot behavior_combo_count mismatch: config %d computed %d." % [int(generation.get("behavior_combo_count", 0)), behavior_count])
	if visual_count != 360 or int(generation.get("visual_machine_count", 0)) != visual_count:
		failures.append("Slot visual_machine_count mismatch: config %d computed %d." % [int(generation.get("visual_machine_count", 0)), visual_count])


func _check_slot_monte_carlo(definition: Dictionary, failures: Array) -> void:
	var resolver = SlotResolverScript.new()
	var scenarios := [
		{"key": "pinball_classic_standard_plain", "family": "pinball", "format": "classic_3_reel", "math": "standard", "bonus": "plain"},
		{"key": "pinball_video_standard_plain", "family": "pinball", "format": "video_feature", "math": "standard", "bonus": "plain"},
		{"key": "buffalo_line_standard_plain", "family": "buffalo", "format": "line_5x3", "math": "standard", "bonus": "plain"},
		{"key": "buffalo_video_standard_plain", "family": "buffalo", "format": "video_feature", "math": "standard", "bonus": "plain"},
	]
	for scenario_value in scenarios:
		var scenario: Dictionary = scenario_value
		var run_state: RunState = _slot_run_state("SLOT-MC-%s" % str(scenario.get("key", "")), 10000000)
		var machine: Dictionary = _slot_machine(definition, run_state, str(scenario.get("family", "")), str(scenario.get("format", "")), str(scenario.get("math", "standard")), str(scenario.get("bonus", "plain")))
		var rng: RngStream = run_state.create_rng("slot_mc_%s" % str(scenario.get("key", "")))
		print("SLOT_MONTE_CARLO_START key=%s spins=%d" % [str(scenario.get("key", "")), SLOT_ACCEPTANCE_MONTE_CARLO_SPINS])
		var metrics: Dictionary = resolver.monte_carlo_metrics(machine, definition, SLOT_ACCEPTANCE_MONTE_CARLO_SPINS, 10, rng)
		_slot_check_metrics(definition, str(scenario.get("family", "")), str(scenario.get("key", "")), metrics, failures)


func _slot_check_metrics(definition: Dictionary, family_id: String, key: String, metrics: Dictionary, failures: Array) -> void:
	var config_key := "slot_%s_config" % family_id
	var targets: Dictionary = _slot_dict(_slot_dict(definition.get(config_key, {})).get("targets", {}))
	var rtp := float(metrics.get("rtp", 0.0))
	var hit := float(metrics.get("hit_frequency", 0.0))
	var true_win := float(metrics.get("true_win_frequency", 0.0))
	var ldw := float(metrics.get("ldw_frequency", 0.0))
	var near_miss := float(metrics.get("near_miss_frequency", 0.0))
	var feature := float(metrics.get("feature_frequency", 0.0))
	print("SLOT_MONTE_CARLO key=%s spins=%d rtp=%.5f hit=%.5f true=%.5f ldw=%.5f near=%.5f feature=%.5f conversions=%d tolerance_rtp=%.5f" % [
		key,
		int(metrics.get("spins", 0)),
		rtp,
		hit,
		true_win,
		ldw,
		near_miss,
		feature,
		int(metrics.get("conversion_count", 0)),
		float(targets.get("rtp_tolerance", 0.0)),
	])
	_slot_assert_between(rtp, float(targets.get("rtp", 0.0)) - float(targets.get("rtp_tolerance", 0.0)), float(targets.get("rtp", 0.0)) + float(targets.get("rtp_tolerance", 0.0)), "%s RTP" % key, failures)
	_slot_assert_between(hit, float(targets.get("hit_frequency_min", 0.0)), float(targets.get("hit_frequency_max", 1.0)), "%s hit frequency" % key, failures)
	_slot_assert_between(true_win, float(targets.get("true_win_min", 0.0)), float(targets.get("true_win_max", 1.0)), "%s true-win frequency" % key, failures)
	_slot_assert_between(ldw, float(targets.get("ldw_min", 0.0)), float(targets.get("ldw_max", 1.0)), "%s LDW frequency" % key, failures)
	var near_target := float(targets.get("near_miss", 0.0))
	var near_tolerance := float(targets.get("near_miss_tolerance", 0.0))
	_slot_assert_between(near_miss, near_target - near_tolerance, near_target + near_tolerance, "%s near-miss frequency" % key, failures)
	var feature_target := float(targets.get("feature_frequency", 0.0))
	var feature_tolerance := float(targets.get("feature_tolerance", 0.0))
	_slot_assert_between(feature, feature_target - feature_tolerance, feature_target + feature_tolerance, "%s feature frequency" % key, failures)


func _check_slot_determinism(library: ContentLibrary, definition: Dictionary, failures: Array) -> void:
	var sequence_a: Dictionary = _slot_deterministic_sequence(library, definition, "SLOT-DETERMINISM")
	var sequence_b: Dictionary = _slot_deterministic_sequence(library, definition, "SLOT-DETERMINISM")
	if JSON.stringify(sequence_a) != JSON.stringify(sequence_b):
		failures.append("Slot generation or spin sequence was not deterministic for identical seed and inputs.")


func _check_slot_buffalo_symbol_variety(definition: Dictionary, failures: Array) -> void:
	var resolver = SlotResolverScript.new()
	var required_landed := ["BUFFALO", "GOLD_TOKEN", "CASH", "BLANK"]
	var non_card_win_seen := {}
	for format_id in ["classic_3_reel", "line_5x3", "video_feature"]:
		var run_state: RunState = _slot_run_state("SLOT-BUFFALO-SYMBOL-VARIETY-%s" % format_id, 100000)
		var machine: Dictionary = _slot_machine(definition, run_state, "buffalo", format_id, "standard", "plain")
		var rng: RngStream = run_state.create_rng("slot_buffalo_symbol_variety")
		var landed := {}
		var true_win_count := 0
		for _index in range(420):
			if SlotMachineStateScript.active_bonus_incomplete(machine):
				machine["active_bonus"] = {"active": false, "complete": true}
			var resolved: Dictionary = resolver.resolve_spin(machine, "spin", SlotMachineStateScript.selected_bet(machine), rng, definition, {})
			machine = _slot_dict(resolved.get("machine", machine))
			var result: Dictionary = _slot_dict(resolved.get("result", {}))
			var grid: Array = _slot_array(result.get("slot_grid", []))
			_slot_count_grid_symbols(grid, landed)
			if str(result.get("slot_classification", "")) == "true_win":
				true_win_count += 1
				for cell_value in _slot_array(result.get("slot_win_cells", [])):
					var cell: Dictionary = _slot_dict(cell_value)
					var symbol := _slot_grid_symbol(grid, int(cell.get("reel", -1)), int(cell.get("row", -1)))
					if not _slot_is_low_buffalo_card(symbol):
						non_card_win_seen[symbol] = true
			machine["active_bonus"] = {"active": false, "complete": true}
			machine["free_spins"] = 0
		for symbol in required_landed:
			if int(landed.get(symbol, 0)) <= 0:
				failures.append("Buffalo %s settled reels never landed %s in the symbol-variety sample." % [format_id, symbol])
		if true_win_count <= 0:
			failures.append("Buffalo %s symbol-variety sample did not hit a true win." % format_id)
	if non_card_win_seen.size() < 4:
		failures.append("Buffalo true wins did not land enough non-card win symbols: %s." % JSON.stringify(non_card_win_seen.keys()))


func _check_slot_payout_variety(definition: Dictionary, failures: Array) -> void:
	var pinball = SlotFamilyPinballScript.new()
	var buffalo = SlotFamilyBuffaloScript.new()
	var scenarios := [
		{"family": "pinball", "format": "classic_3_reel", "min_payouts": 4, "min_symbols": 5, "min_counts": 1},
		{"family": "pinball", "format": "line_5x3", "min_payouts": 5, "min_symbols": 5, "min_counts": 2},
		{"family": "pinball", "format": "video_feature", "min_payouts": 5, "min_symbols": 5, "min_counts": 3},
		{"family": "buffalo", "format": "classic_3_reel", "min_payouts": 3, "min_symbols": 6, "min_counts": 1},
		{"family": "buffalo", "format": "line_5x3", "min_payouts": 5, "min_symbols": 6, "min_counts": 1},
		{"family": "buffalo", "format": "video_feature", "min_payouts": 5, "min_symbols": 6, "min_counts": 1},
	]
	for scenario_value in scenarios:
		var scenario: Dictionary = scenario_value
		var family_id := str(scenario.get("family", "pinball"))
		var format_id := str(scenario.get("format", "classic_3_reel"))
		var run_state: RunState = _slot_run_state("SLOT-PAYOUT-VARIETY-%s-%s" % [family_id, format_id], 100000)
		var machine: Dictionary = _slot_machine(definition, run_state, family_id, format_id, "standard", "plain")
		var rng: RngStream = run_state.create_rng("slot_payout_variety")
		var payouts := {}
		var symbols := {}
		var counts := {}
		for _index in range(640):
			var entry: Dictionary = {"id": "true_win", "classification": "true_win", "payout_multiplier": 3.0}
			var grid: Array = []
			var payout := 0
			if family_id == "buffalo":
				grid = buffalo.force_outcome_symbols(machine, _slot_array(machine.get("last_grid", [])), entry, rng, definition)
				payout = int(buffalo.grid_payout_for_entry(grid, 10, 10, machine, definition, entry))
			else:
				grid = pinball.force_outcome_symbols(machine, _slot_array(machine.get("last_grid", [])), entry, rng, definition)
				payout = int(pinball.grid_payout_for_entry(grid, 10, 10, machine, definition, entry))
			var placement: Dictionary = _slot_dict(entry.get("forced_placement", {}))
			var cells: Array = _slot_array(placement.get("cells", []))
			if payout <= 10:
				failures.append("Slot %s/%s true-win profile produced a non-winning payout: %d grid=%s." % [family_id, format_id, payout, JSON.stringify(grid)])
				return
			payouts[payout] = true
			symbols[str(placement.get("symbol", ""))] = true
			counts[cells.size()] = true
		if payouts.size() < int(scenario.get("min_payouts", 1)):
			failures.append("Slot %s/%s true wins produced only %d payout amounts: %s." % [family_id, format_id, payouts.size(), JSON.stringify(payouts.keys())])
		if symbols.size() < int(scenario.get("min_symbols", 1)):
			failures.append("Slot %s/%s true wins produced only %d win symbols: %s." % [family_id, format_id, symbols.size(), JSON.stringify(symbols.keys())])
		if counts.size() < int(scenario.get("min_counts", 1)):
			failures.append("Slot %s/%s true wins produced only %d win-count bands: %s." % [family_id, format_id, counts.size(), JSON.stringify(counts.keys())])
		print("SLOT_PAYOUT_VARIETY family=%s format=%s payouts=%s symbols=%s counts=%s" % [
			family_id,
			format_id,
			JSON.stringify(payouts.keys()),
			JSON.stringify(symbols.keys()),
			JSON.stringify(counts.keys()),
		])


func _check_slot_reel_display_consistency(definition: Dictionary, failures: Array) -> void:
	var resolver = SlotResolverScript.new()
	var pinball = SlotFamilyPinballScript.new()
	var buffalo = SlotFamilyBuffaloScript.new()
	var scenarios := [
		{"family": "pinball", "format": "classic_3_reel"},
		{"family": "pinball", "format": "line_5x3"},
		{"family": "pinball", "format": "video_feature"},
		{"family": "buffalo", "format": "classic_3_reel"},
		{"family": "buffalo", "format": "line_5x3"},
		{"family": "buffalo", "format": "video_feature"},
	]
	for scenario_value in scenarios:
		var scenario: Dictionary = scenario_value
		var family_id := str(scenario.get("family", "pinball"))
		var format_id := str(scenario.get("format", "classic_3_reel"))
		var run_state: RunState = _slot_run_state("SLOT-DISPLAY-CONSISTENCY-%s-%s" % [family_id, format_id], 100000)
		var machine: Dictionary = _slot_machine(definition, run_state, family_id, format_id, "standard", "plain")
		var rng: RngStream = run_state.create_rng("slot_display_consistency")
		var settled_signatures := {}
		var saw_extended_win := false
		var true_win_count := 0
		for _index in range(720):
			if SlotMachineStateScript.active_bonus_incomplete(machine):
				machine["active_bonus"] = {"active": false, "complete": true}
			var selected_bet: Dictionary = SlotMachineStateScript.selected_bet(machine)
			var resolved: Dictionary = resolver.resolve_spin(machine, "spin", selected_bet, rng, definition, {})
			machine = _slot_dict(resolved.get("machine", machine))
			var result: Dictionary = _slot_dict(resolved.get("result", {}))
			var grid: Array = _slot_array(result.get("slot_grid", []))
			var classification := str(result.get("slot_classification", ""))
			var stake := maxi(1, int(result.get("slot_stake", selected_bet.get("total_credits", 10))))
			var stake_cost := maxi(0, int(result.get("slot_stake_cost", stake)))
			var payout := maxi(0, int(result.get("slot_payout", 0)))
			if not bool(result.get("slot_feature_triggered", false)):
				var visual_payout := buffalo.grid_payout(grid, stake, stake_cost, machine, definition) if family_id == "buffalo" else pinball.grid_payout(grid, stake, stake_cost, machine, definition)
				if (classification == "zero_loss" or classification == "near_miss") and visual_payout > 0:
					failures.append("Slot %s/%s displayed an unpaid winning grid on %s/%s: visual=%d paid=%d win_kind=%s win_symbol=%s grid=%s." % [family_id, format_id, classification, str(result.get("slot_outcome_id", "")), visual_payout, payout, str(result.get("slot_win_kind", "")), str(result.get("slot_win_symbol", "")), JSON.stringify(grid)])
					return
				if (classification == "true_win" or classification == "ldw") and visual_payout != payout:
					failures.append("Slot %s/%s paid %d but displayed a %d-credit grid on %s: grid=%s." % [family_id, format_id, payout, visual_payout, classification, JSON.stringify(grid)])
					return
			if classification == "true_win":
				true_win_count += 1
				var win_cells: Array = _slot_array(result.get("slot_win_cells", []))
				if win_cells.is_empty():
					failures.append("Slot %s/%s true win did not expose win cells." % [family_id, format_id])
					return
				if int(machine.get("reel_count", 3)) > 3 and win_cells.size() > 3:
					saw_extended_win = true
			if classification == "zero_loss" or classification == "near_miss":
				settled_signatures[JSON.stringify(grid)] = true
			machine["active_bonus"] = {"active": false, "complete": true}
			machine["free_spins"] = 0
			var sample_has_true_win := true_win_count > 0
			var sample_has_extended_win := format_id == "classic_3_reel" or saw_extended_win
			if sample_has_true_win and sample_has_extended_win and settled_signatures.size() >= 8:
				break
		if true_win_count <= 0:
			failures.append("Slot %s/%s display consistency sample did not hit a true win." % [family_id, format_id])
		if format_id != "classic_3_reel" and not saw_extended_win:
			failures.append("Slot %s/%s did not showcase any extended >3-cell true wins across the full board." % [family_id, format_id])
		if settled_signatures.size() < 8:
			failures.append("Slot %s/%s non-winning filler repeated too often: %d distinct settled layouts." % [family_id, format_id, settled_signatures.size()])


func _check_slot_buffalo_full_span_lines(definition: Dictionary, failures: Array) -> void:
	var buffalo = SlotFamilyBuffaloScript.new()
	var partial_grid := [
		["BUFFALO", "A", "K"],
		["BUFFALO", "Q", "J"],
		["BUFFALO", "A", "K"],
		["A", "Q", "J"],
		["K", "Q", "J"],
	]
	var partial_payout: int = buffalo.grid_payout(partial_grid, 10, 10, {"reel_count": 5, "row_count": 3}, definition)
	if partial_payout != 0:
		failures.append("Buffalo paid %d for a partial three-reel cluster instead of requiring a full payline." % partial_payout)
	var full_line_grid := [
		["A", "BUFFALO", "K"],
		["Q", "BUFFALO", "J"],
		["A", "SUNSET_2X", "K"],
		["Q", "BUFFALO", "J"],
		["A", "BUFFALO", "K"],
	]
	var full_line_payout: int = buffalo.grid_payout(full_line_grid, 10, 10, {"reel_count": 5, "row_count": 3}, definition)
	if full_line_payout <= 0:
		failures.append("Buffalo full-width payline did not produce a payout.")
	var renderer = SlotRendererScript.new()
	var presentation = SlotPresentationScript.new()
	var true_sample: Dictionary = _slot_spin_until_classification(definition, "buffalo", "line_5x3", "true_win", "SLOT-BUFFALO-FULL-LINE", failures)
	if true_sample.is_empty():
		return
	var run_state_value: Variant = true_sample.get("run_state", null)
	if not run_state_value is RunState:
		failures.append("Buffalo full-line sample did not return a RunState.")
		return
	var sample_run_state: RunState = run_state_value
	var machine: Dictionary = _slot_dict(true_sample.get("machine", {}))
	var result: Dictionary = _slot_dict(true_sample.get("result", {}))
	var reel_count := maxi(1, int(machine.get("reel_count", 5)))
	var win_cells: Array = _slot_array(result.get("slot_win_cells", []))
	var grid: Array = _slot_array(result.get("slot_grid", []))
	var win_symbol := str(result.get("slot_win_symbol", ""))
	if str(result.get("slot_win_kind", "")) != "line":
		failures.append("Buffalo true win did not report line attribution.")
	if win_cells.size() != reel_count:
		failures.append("Buffalo true win highlighted %d cells instead of spanning all %d reels." % [win_cells.size(), reel_count])
	if int(result.get("slot_win_line_index", -1)) < 0:
		failures.append("Buffalo true win did not expose a payline index.")
	for cell_value in win_cells:
		var cell: Dictionary = _slot_dict(cell_value)
		var symbol := _slot_grid_symbol(grid, int(cell.get("reel", 0)), int(cell.get("row", 0)))
		if symbol != win_symbol and not _slot_symbol_is_wild(symbol, "buffalo"):
			failures.append("Buffalo line attribution cell did not match the winning symbol or wild.")
			break
	var settle_msec := _slot_settle_msec(_slot_array(result.get("slot_reel_timeline", [])))
	var settle_surface: Dictionary = presentation.surface_state(machine, sample_run_state, definition, {"surface_time_msec": settle_msec})
	var settle_manifest: Dictionary = renderer.render_signature(settle_surface, definition, settle_msec, "spin")
	if not bool(settle_manifest.get("win_line_drawn", false)):
		failures.append("Buffalo true win manifest did not draw the connecting payline.")


func _check_slot_buffalo_timed_nudge(definition: Dictionary, failures: Array) -> void:
	var buffalo = SlotFamilyBuffaloScript.new()
	var resolver = SlotResolverScript.new()
	var presentation = SlotPresentationScript.new()
	var renderer = SlotRendererScript.new()
	var run_state: RunState = _slot_run_state("SLOT-BUFFALO-TIMED-NUDGE", 100000)
	var machine: Dictionary = _slot_machine(definition, run_state, "buffalo", "line_5x3", "standard", "plain")
	var variant_counts: Dictionary = {}
	var variant_rng: RngStream = run_state.create_rng("buffalo_tease_variants")
	for _variant_index in range(28):
		var entry: Dictionary = {"id": "near_miss", "classification": "near_miss", "payout": 0}
		var grid: Array = buffalo.force_outcome_symbols(machine, _slot_array(machine.get("last_grid", [])), entry, variant_rng, definition)
		var placement: Dictionary = _slot_dict(entry.get("forced_placement", {}))
		var count := _slot_array(placement.get("cells", [])).size()
		variant_counts[count] = true
		var gold_lookup: Dictionary = _slot_grid_symbol_lookup(grid, "GOLD_TOKEN")
		var placed_lookup: Dictionary = _slot_cell_lookup(_slot_array(placement.get("cells", [])))
		for gold_key in gold_lookup.keys():
			if not bool(placed_lookup.get(str(gold_key), false)):
				failures.append("Buffalo near-miss generated an unplaced gold token: %s." % str(gold_key))
				break
		if _slot_array(placement.get("skill_line_cells", [])).size() < mini(3, int(machine.get("reel_count", 5))):
			failures.append("Buffalo near-miss tease did not expose skill line cells.")
		if grid.is_empty():
			failures.append("Buffalo near-miss tease generated an empty grid.")
	if not bool(variant_counts.get(1, false)) or not bool(variant_counts.get(2, false)):
		failures.append("Buffalo near-miss generation did not cover both one-coin and two-coin tease states.")

	var near_sample: Dictionary = _slot_spin_until_classification(definition, "buffalo", "line_5x3", "near_miss", "SLOT-BUFFALO-NUDGE-NEAR", failures)
	if near_sample.is_empty():
		return
	var near_run_state: RunState = near_sample.get("run_state", run_state)
	var near_machine: Dictionary = _slot_dict(near_sample.get("machine", {}))
	var near_offer: Dictionary = _slot_dict(near_machine.get("last_nudge_offer", {}))
	if str(near_offer.get("type", "")) != "coin_chain":
		failures.append("Buffalo near-miss nudge offer was not a coin-chain offer.")
		return
	var near_coins: Array = _slot_array(near_offer.get("coins", []))
	var expected_coin_count := mini(maxi(1, int(near_machine.get("row_count", 1))), 5)
	if near_coins.size() != expected_coin_count:
		failures.append("Buffalo coin-chain offer exposed %d coins instead of one per visible row (%d)." % [near_coins.size(), expected_coin_count])
	var near_window: Dictionary = _slot_dict(near_offer.get("skill_window_msec", {}))
	var perfect_msec := int(near_window.get("perfect", -1))
	if perfect_msec < 0:
		failures.append("Buffalo near-miss coin-chain offer did not expose a perfect timing window.")
	var near_surface: Dictionary = presentation.surface_state(near_machine, near_run_state, definition, {"slot_nudge_chain_input_msec": perfect_msec})
	var near_manifest: Dictionary = renderer.render_signature(near_surface, definition, perfect_msec, "nudge_chain")
	if not bool(near_surface.get("slot_nudge_available", false)):
		failures.append("Buffalo coin-chain nudge was not available on the tease surface.")
	if not bool(near_surface.get("slot_nudge_chain_active", false)):
		failures.append("Buffalo coin-chain surface did not expose the active chain state.")
	if _slot_surface_channel_duration(near_surface, "slot_nudge_chain") <= 0:
		failures.append("Buffalo coin-chain surface did not expose its own animation channel.")
	if not bool(near_manifest.get("nudge_chain_active", false)) or not bool(near_manifest.get("nudge_chain_zone_visible", false)):
		failures.append("Buffalo coin-chain manifest did not expose the side coin and timing zone.")
	if not bool(near_manifest.get("nudge_chain_window_active", false)):
		failures.append("Buffalo coin-chain manifest did not mark the perfect press as inside the zone.")
	if float(near_manifest.get("nudge_chain_peek_amount", 0.0)) <= 0.0:
		failures.append("Buffalo coin-chain manifest did not render a peeking coin.")
	var tease_visual_machine: Dictionary = near_machine.duplicate(true)
	tease_visual_machine["reel_strips"] = _slot_coin_heavy_reel_strips(maxi(1, int(tease_visual_machine.get("reel_count", 5))))
	var tease_flash_surface: Dictionary = presentation.surface_state(tease_visual_machine, run_state, definition, {"surface_time_msec": 100})
	var tease_flash_manifest: Dictionary = renderer.render_signature(tease_flash_surface, definition, 100, "spin")
	if bool(tease_flash_manifest.get("buffalo_unintentional_gold_visible", false)):
		failures.append("Buffalo coin-chain tease rendered unintentional strip gold before a real coin landed.")
	var cue_ids: Array = []
	for cue_value in _slot_array(near_surface.get("slot_audio_cues", [])):
		var cue: Dictionary = _slot_dict(cue_value)
		cue_ids.append(str(cue.get("cue_id", "")))
	if not cue_ids.has("gold_coin_tease"):
		failures.append("Buffalo coin-chain tease did not schedule the gold coin stinger.")
	var perfect_resolved: Dictionary = resolver.resolve_spin(near_machine.duplicate(true), "nudge", SlotMachineStateScript.selected_bet(near_machine), run_state.create_rng("buffalo_nudge_perfect"), definition, {}, true, false, run_state, {}, {"slot_nudge_chain_input_msec": perfect_msec})
	var perfect_action: Dictionary = _slot_dict(perfect_resolved.get("result", {}))
	var perfect_machine: Dictionary = _slot_dict(perfect_resolved.get("machine", {}))
	if not bool(perfect_action.get("slot_nudge_applied", false)) or str(perfect_action.get("slot_nudge_skill_outcome", "")) != "perfect":
		failures.append("Buffalo coin-chain nudge did not record a perfect skill outcome.")
	var near_target: Dictionary = _slot_dict(near_offer.get("nudge_target", {}))
	if near_target.is_empty() or _slot_dict(near_target.get("perfect", {})).is_empty():
		failures.append("Buffalo coin-chain nudge offer did not publish a reel-stop target.")
	else:
		_slot_assert_nudge_target_landed(near_machine, perfect_action, near_target, failures, "Perfect Buffalo coin-chain nudge")
	if int(perfect_action.get("slot_payout", 0)) <= 0 and not bool(perfect_action.get("slot_feature_triggered", false)):
		failures.append("Perfect Buffalo coin-chain nudge did not resolve through a normal payout or feature trigger.")
	if not _slot_dict(perfect_machine.get("last_nudge_offer", {})).is_empty():
		failures.append("Perfect Buffalo coin-chain nudge did not clear the post-spin offer after the real reel shift.")

	var miss_sample: Dictionary = _slot_spin_until_classification(definition, "buffalo", "line_5x3", "near_miss", "SLOT-BUFFALO-NUDGE-MISS", failures)
	if miss_sample.is_empty():
		return
	var miss_machine_seed: Dictionary = _slot_dict(miss_sample.get("machine", {}))
	var miss_offer: Dictionary = _slot_dict(miss_machine_seed.get("last_nudge_offer", {}))
	var miss_window: Dictionary = _slot_dict(miss_offer.get("skill_window_msec", {}))
	var soft_miss_msec := int(miss_window.get("end", 0)) + 1
	var soft_miss_resolved: Dictionary = resolver.resolve_spin(miss_machine_seed.duplicate(true), "nudge", SlotMachineStateScript.selected_bet(miss_machine_seed), run_state.create_rng("buffalo_nudge_soft_miss"), definition, {}, true, false, run_state, {}, {"slot_nudge_chain_input_msec": soft_miss_msec})
	var soft_miss_action: Dictionary = _slot_dict(soft_miss_resolved.get("result", {}))
	var soft_miss_machine: Dictionary = _slot_dict(soft_miss_resolved.get("machine", {}))
	if str(soft_miss_action.get("slot_nudge_skill_outcome", "")) != "miss":
		failures.append("Slightly mistimed Buffalo coin-chain nudge did not record a miss outcome.")
	if JSON.stringify(_slot_array(soft_miss_action.get("slot_grid", []))) != JSON.stringify(_slot_array(miss_offer.get("grid", []))) or JSON.stringify(_slot_array(soft_miss_action.get("slot_reel_stops", []))) != JSON.stringify(_slot_array(miss_offer.get("stops", []))):
		failures.append("Slightly mistimed Buffalo coin-chain nudge changed the reel grid or stops.")
	if int(soft_miss_action.get("slot_payout", 0)) != 0 or bool(soft_miss_action.get("slot_feature_triggered", false)) or not _slot_dict(soft_miss_machine.get("last_nudge_offer", {})).is_empty():
		failures.append("Slightly mistimed Buffalo coin-chain nudge did not end without payout, feature, or a lingering offer.")
	var miss_msec := int(miss_window.get("end", 0)) + 300
	var miss_resolved: Dictionary = resolver.resolve_spin(miss_machine_seed.duplicate(true), "nudge", SlotMachineStateScript.selected_bet(miss_machine_seed), run_state.create_rng("buffalo_nudge_miss"), definition, {}, true, false, run_state, {}, {"slot_nudge_chain_input_msec": miss_msec})
	var miss_action: Dictionary = _slot_dict(miss_resolved.get("result", {}))
	var miss_machine: Dictionary = _slot_dict(miss_resolved.get("machine", {}))
	if str(miss_action.get("slot_nudge_skill_outcome", "")) != "blown":
		failures.append("Mistimed Buffalo coin-chain nudge did not record a blown outcome.")
	if JSON.stringify(_slot_array(miss_action.get("slot_grid", []))) != JSON.stringify(_slot_array(miss_offer.get("grid", []))) or JSON.stringify(_slot_array(miss_action.get("slot_reel_stops", []))) != JSON.stringify(_slot_array(miss_offer.get("stops", []))):
		failures.append("Mistimed Buffalo coin-chain nudge changed the reel grid or stops.")
	if int(miss_action.get("slot_payout", 0)) != 0 or bool(miss_action.get("slot_feature_triggered", false)) or not _slot_dict(miss_machine.get("last_nudge_offer", {})).is_empty():
		failures.append("Mistimed Buffalo coin-chain nudge did not end without payout, feature, or a lingering offer.")
	print("SLOT_BUFFALO_COIN_CHAIN variants=%s coins=%d active=%s perfect=%s miss_class=%s cues=%s" % [
		JSON.stringify(variant_counts.keys()),
		int(near_manifest.get("nudge_chain_coin_count", 0)),
		str(near_manifest.get("nudge_chain_active", false)),
		str(perfect_action.get("slot_nudge_skill_outcome", "")),
		str(miss_action.get("slot_classification", "")),
		",".join(_slot_string_array(cue_ids)),
	])


func _check_slot_nudge_chain_determinism(definition: Dictionary, failures: Array) -> void:
	var resolver = SlotResolverScript.new()
	var presentation = SlotPresentationScript.new()
	var renderer = SlotRendererScript.new()
	var variant_seen: Dictionary = {}
	var deterministic_sample: Dictionary = {}
	var saw_line_perfect := false
	var saw_feature_perfect := false
	for family_id in ["pinball", "buffalo"]:
		for format_id in ["classic_3_reel", "line_5x3", "video_feature"]:
			var variant_key := "%s:%s" % [family_id, format_id]
			var sample: Dictionary = _slot_spin_until_classification(definition, family_id, format_id, "near_miss", "SLOT-NUDGE-CHAIN-%s-%s" % [family_id, format_id], failures)
			if sample.is_empty():
				continue
			var sample_run_state: RunState = sample.get("run_state", null)
			var machine: Dictionary = _slot_dict(sample.get("machine", {}))
			var offer: Dictionary = _slot_dict(machine.get("last_nudge_offer", {}))
			if str(offer.get("type", "")) != "coin_chain":
				failures.append("Slot near miss for %s did not create a coin-chain nudge offer." % variant_key)
				continue
			var coins: Array = _slot_array(offer.get("coins", []))
			var expected_coin_count := mini(maxi(1, int(machine.get("row_count", 1))), 5)
			if coins.size() != expected_coin_count:
				failures.append("Slot coin chain for %s had %d coins instead of %d visible rows." % [variant_key, coins.size(), expected_coin_count])
			var window: Dictionary = _slot_dict(offer.get("skill_window_msec", {}))
			var perfect_msec := int(window.get("perfect", -1))
			var surface: Dictionary = presentation.surface_state(machine, sample_run_state, definition, {"slot_nudge_chain_input_msec": perfect_msec})
			var manifest: Dictionary = renderer.render_signature(surface, definition, perfect_msec, "nudge_chain")
			if not bool(surface.get("slot_nudge_chain_active", false)) or not bool(manifest.get("nudge_chain_zone_visible", false)):
				failures.append("Slot coin chain for %s did not publish a visible zone in surface state/manifest." % variant_key)
			var target: Dictionary = _slot_dict(offer.get("nudge_target", {}))
			if target.is_empty() or _slot_dict(target.get("perfect", {})).is_empty():
				failures.append("Slot coin chain for %s did not publish a perfect reel-stop target." % variant_key)
			else:
				var perfect_resolved: Dictionary = resolver.resolve_spin(machine.duplicate(true), "nudge", SlotMachineStateScript.selected_bet(machine), sample_run_state.create_rng("slot_nudge_chain_perfect_%s_%s" % [family_id, format_id]), definition, {}, true, false, sample_run_state, {}, {"slot_nudge_chain_input_msec": perfect_msec})
				var perfect_result: Dictionary = _slot_dict(perfect_resolved.get("result", {}))
				var perfect_machine: Dictionary = _slot_dict(perfect_resolved.get("machine", {}))
				if str(perfect_result.get("slot_nudge_skill_outcome", "")) != "perfect":
					failures.append("Slot coin chain for %s did not resolve the perfect input as perfect." % variant_key)
				_slot_assert_nudge_target_landed(machine, perfect_result, target, failures, "Slot coin chain %s" % variant_key)
				if int(perfect_result.get("slot_payout", 0)) > 0:
					saw_line_perfect = true
				if bool(perfect_result.get("slot_feature_triggered", false)):
					saw_feature_perfect = true
				if int(perfect_result.get("slot_payout", 0)) <= 0 and not bool(perfect_result.get("slot_feature_triggered", false)):
					failures.append("Slot coin chain for %s did not resolve the perfect nudge through a normal payout or feature." % variant_key)
				if not _slot_dict(perfect_machine.get("last_nudge_offer", {})).is_empty():
					failures.append("Slot coin chain for %s left a nudge offer active after perfect resolution." % variant_key)
			variant_seen[variant_key] = true
			if deterministic_sample.is_empty():
				deterministic_sample = sample
	for expected_key in ["pinball:classic_3_reel", "pinball:line_5x3", "pinball:video_feature", "buffalo:classic_3_reel", "buffalo:line_5x3", "buffalo:video_feature"]:
		if not bool(variant_seen.get(expected_key, false)):
			failures.append("Slot coin-chain nudge variant was not verified: %s." % expected_key)
	if _slot_nudge_line_pay_fixture(definition, failures):
		saw_line_perfect = true
	if not saw_line_perfect:
		failures.append("Slot coin-chain nudge did not verify a perfect line-payout fixture.")
	if not saw_feature_perfect:
		failures.append("Slot coin-chain nudge did not verify a perfect feature-trigger fixture.")
	if deterministic_sample.is_empty():
		return
	var base_machine: Dictionary = _slot_dict(deterministic_sample.get("machine", {}))
	var first_transcript: Array = _slot_nudge_chain_script(definition, base_machine, "deterministic_chain")
	var second_transcript: Array = _slot_nudge_chain_script(definition, base_machine, "deterministic_chain")
	if JSON.stringify(first_transcript) != JSON.stringify(second_transcript):
		failures.append("Slot coin-chain nudge was not deterministic for matching input and RNG seed.")
	if first_transcript.is_empty():
		failures.append("Slot coin-chain deterministic script did not collect or break any coins.")
	else:
		var first_step: Dictionary = _slot_dict(first_transcript[0])
		if str(first_step.get("grade", "")) != "perfect" or (int(first_step.get("payout", 0)) <= 0 and not bool(first_step.get("feature", false))):
			failures.append("Slot coin-chain deterministic script did not resolve the first perfect nudge through normal evaluation.")
	print("SLOT_NUDGE_CHAIN_DETERMINISM variants=%s transcript=%s" % [
		JSON.stringify(variant_seen.keys()),
		JSON.stringify(first_transcript),
	])


func _slot_nudge_chain_script(definition: Dictionary, base_machine: Dictionary, seed: String) -> Array:
	var resolver = SlotResolverScript.new()
	var run_state: RunState = _slot_run_state("SLOT-NUDGE-CHAIN-SCRIPT-%s" % seed, 100000)
	var machine: Dictionary = base_machine.duplicate(true)
	var rng: RngStream = run_state.create_rng("slot_nudge_chain_%s" % seed)
	var transcript: Array = []
	for _step in range(6):
		var offer: Dictionary = _slot_dict(machine.get("last_nudge_offer", {}))
		if offer.is_empty():
			break
		var window: Dictionary = _slot_dict(offer.get("skill_window_msec", {}))
		var input_msec := int(window.get("perfect", -1))
		if input_msec < 0:
			break
		var resolved: Dictionary = resolver.resolve_spin(machine.duplicate(true), "nudge", SlotMachineStateScript.selected_bet(machine), rng, definition, {}, true, false, run_state, {}, {"slot_nudge_chain_input_msec": input_msec})
		machine = _slot_dict(resolved.get("machine", machine))
		var result: Dictionary = _slot_dict(resolved.get("result", {}))
		var next_offer: Dictionary = _slot_dict(machine.get("last_nudge_offer", {}))
		transcript.append({
			"grade": str(result.get("slot_nudge_skill_outcome", "")),
			"payout": int(result.get("slot_payout", 0)),
			"feature": bool(result.get("slot_feature_triggered", false)),
			"banked": int(result.get("slot_nudge_chain_banked_payout", 0)),
			"collected": int(result.get("slot_nudge_chain_collected", 0)),
			"active": bool(result.get("slot_nudge_chain_active", false)),
			"next_active_index": int(next_offer.get("active_index", -1)),
			"next_attempts": int(next_offer.get("attempts_used", -1)),
			"next_spawned": bool(next_offer.get("last_spawned", false)),
		})
	var terminal_offer: Dictionary = _slot_dict(machine.get("last_nudge_offer", {}))
	if not terminal_offer.is_empty():
		var terminal_window: Dictionary = _slot_dict(terminal_offer.get("skill_window_msec", {}))
		var miss_msec := int(terminal_window.get("end", 0)) + 300
		var miss_resolved: Dictionary = resolver.resolve_spin(machine.duplicate(true), "nudge", SlotMachineStateScript.selected_bet(machine), rng, definition, {}, true, false, run_state, {}, {"slot_nudge_chain_input_msec": miss_msec})
		machine = _slot_dict(miss_resolved.get("machine", machine))
		var miss_result: Dictionary = _slot_dict(miss_resolved.get("result", {}))
		transcript.append({
			"grade": str(miss_result.get("slot_nudge_skill_outcome", "")),
			"payout": int(miss_result.get("slot_payout", 0)),
			"feature": bool(miss_result.get("slot_feature_triggered", false)),
			"banked": int(miss_result.get("slot_nudge_chain_banked_payout", 0)),
			"collected": int(miss_result.get("slot_nudge_chain_collected", 0)),
			"active": bool(miss_result.get("slot_nudge_chain_active", false)),
			"next_active_index": -1,
			"next_attempts": -1,
			"next_spawned": false,
		})
	return transcript


func _slot_nudge_line_pay_fixture(definition: Dictionary, failures: Array) -> bool:
	var resolver = SlotResolverScript.new()
	var run_state: RunState = _slot_run_state("SLOT-NUDGE-LINE-PAY", 100000)
	var machine: Dictionary = _slot_machine(definition, run_state, "pinball", "classic_3_reel", "standard", "plain")
	machine["reel_strips"] = [
		["CHERRY", "BAR", "BALL"],
		["CHERRY", "BAR", "BALL"],
		["BAR", "CHERRY", "BALL"],
	]
	machine["reel_stops"] = [0, 0, 0]
	machine["last_reels"] = [0, 0, 0]
	machine["last_grid"] = [["CHERRY"], ["CHERRY"], ["BAR"]]
	var line_cells: Array = [{"reel": 0, "row": 0}, {"reel": 1, "row": 0}, {"reel": 2, "row": 0}]
	var shifted_grid: Array = [["CHERRY"], ["CHERRY"], ["CHERRY"]]
	var shifted_stops: Array = [0, 0, 1]
	var entry: Dictionary = {
		"id": "true_win",
		"classification": "true_win",
		"forced_placement": {"kind": "line", "symbol": "CHERRY", "cells": line_cells, "line_index": 0},
	}
	var perfect_msec := 1000
	machine["last_nudge_offer"] = {
		"type": "coin_chain",
		"family": "pinball",
		"format_id": "classic_3_reel",
		"classification": "near_miss",
		"original_classification": "near_miss",
		"grid": [["CHERRY"], ["CHERRY"], ["BAR"]],
		"stops": [0, 0, 0],
		"coins": [{"index": 0, "row": 0, "ready_msec": 500, "collected": false, "spawned": true}],
		"active_index": 0,
		"peek_cycle_msec": 1000,
		"skill_perfect_msec": 80,
		"skill_good_msec": 220,
		"skill_window_msec": {"start": 780, "perfect": perfect_msec, "end": 1220},
		"nudge_target": {
			"reel": 2,
			"row": 0,
			"symbol": "CHERRY",
			"direction": 1,
			"current_stop": 0,
			"strip_size": 3,
			"perfect": {
				"entry": entry,
				"grid": shifted_grid,
				"stops": shifted_stops,
				"classification": "true_win",
				"feature_triggered": false,
				"payout": 0,
				"reel": 2,
				"old_stop": 0,
				"new_stop": 1,
				"shift": 1,
			},
			"good": {
				"entry": {"id": "near_miss", "classification": "near_miss", "payout": 0},
				"grid": [["CHERRY"], ["CHERRY"], ["BALL"]],
				"stops": [0, 0, 2],
				"classification": "near_miss",
				"feature_triggered": false,
				"payout": 0,
				"reel": 2,
				"old_stop": 0,
				"new_stop": 2,
				"shift": -1,
			},
		},
		"post_spin_available": true,
	}
	var resolved: Dictionary = resolver.resolve_spin(machine.duplicate(true), "nudge", SlotMachineStateScript.selected_bet(machine), run_state.create_rng("slot_nudge_line_pay"), definition, {}, true, false, run_state, {}, {"slot_nudge_chain_input_msec": perfect_msec})
	var result: Dictionary = _slot_dict(resolved.get("result", {}))
	var resolved_machine: Dictionary = _slot_dict(resolved.get("machine", {}))
	if str(result.get("slot_nudge_skill_outcome", "")) != "perfect":
		failures.append("Slot nudge line-pay fixture did not grade the input as perfect.")
		return false
	_slot_assert_nudge_target_landed(machine, result, _slot_dict(_slot_dict(machine.get("last_nudge_offer", {})).get("nudge_target", {})), failures, "Slot nudge line-pay fixture")
	if bool(result.get("slot_feature_triggered", false)) or int(result.get("slot_payout", 0)) <= 0:
		failures.append("Slot nudge line-pay fixture did not resolve through a normal line payout.")
		return false
	if not _slot_dict(resolved_machine.get("last_nudge_offer", {})).is_empty():
		failures.append("Slot nudge line-pay fixture left a nudge offer active.")
		return false
	return true


func _check_slot_item_pack_effects(library: ContentLibrary, definition: Dictionary, failures: Array) -> void:
	var slot_item_ids := [
		"coin_return_shim",
		"lucky_reel_grease",
		"timing_bracelet",
		"gold_tooth_token",
		"payout_pamphlet",
		"cold_quarters",
		"neon_players_charm",
		"split_reel_note",
		"feature_magnet",
		"cumquat_sandwich",
		"drain_cleaner",
		"jackpot_magnet",
		"splitter_token",
		"return_spring",
		"tilt_dampener",
		"bumper_battery",
		"rubber_pegs",
		"magnet_cup",
		"extra_ball_token",
		"plunger_tuner",
		"lock_jammer",
	]
	var pinball_item_ids := [
		"drain_cleaner",
		"jackpot_magnet",
		"splitter_token",
		"return_spring",
		"tilt_dampener",
		"bumper_battery",
		"rubber_pegs",
		"magnet_cup",
		"extra_ball_token",
		"plunger_tuner",
		"lock_jammer",
	]
	var only_pull_tabs_challenge := RunState.custom_challenge("only_pull_tabs", "SLOT-ITEMS", {"content_groups": ["pull_tabs_pack"]})
	var seen_icon_keys: Dictionary = {}
	var seen_asset_paths: Dictionary = {}
	for item_id_value in slot_item_ids:
		var item_id := str(item_id_value)
		var item: Dictionary = library.item(item_id)
		if item.is_empty():
			failures.append("Slot item pack is missing item: %s." % item_id)
			continue
		if not _slot_string_array(item.get("content_groups", [])).has("slot_pack"):
			failures.append("Slot item %s is not assigned to slot_pack." % item_id)
		if not library.item_enabled_for_challenge(item_id, {}):
			failures.append("Default content groups did not enable slot item %s." % item_id)
		if library.item_enabled_for_challenge(item_id, only_pull_tabs_challenge):
			failures.append("Pull-tab-only challenge still enabled slot item %s." % item_id)
		var icon_key := str(item.get("icon_key", "")).strip_edges()
		if icon_key.is_empty():
			failures.append("Slot item %s is missing an icon key." % item_id)
		elif seen_icon_keys.has(icon_key):
			failures.append("Slot items %s and %s share icon key %s." % [str(seen_icon_keys.get(icon_key, "")), item_id, icon_key])
		else:
			seen_icon_keys[icon_key] = item_id
		var asset_path := str(item.get("asset_path", "")).strip_edges()
		if asset_path.is_empty():
			failures.append("Slot item %s is missing an asset path." % item_id)
		elif seen_asset_paths.has(asset_path):
			failures.append("Slot items %s and %s share asset path %s." % [str(seen_asset_paths.get(asset_path, "")), item_id, asset_path])
		else:
			seen_asset_paths[asset_path] = item_id

	var shop_archetype := _first_shop_archetype(library)
	if shop_archetype.is_empty():
		failures.append("No shop archetype exists for slot item shop-spawn validation.")
	else:
		var slot_only_challenge := RunState.custom_challenge("only_slot_items", "SLOT-ITEMS", {"content_groups": ["slot_pack"]})
		var slot_shop_pool := library.shop_item_pool_for_challenge(shop_archetype.get("item_pool", []), slot_only_challenge)
		if slot_shop_pool.has("cumquat_sandwich"):
			failures.append("Cumquat Sandwich should stay a hidden beach reward, not a shop-spawn item.")
		for item_id_value in pinball_item_ids:
			var item_id := str(item_id_value)
			if not slot_shop_pool.has(item_id):
				failures.append("Slot-only shop pool did not include pinball item %s." % item_id)
		var exhaustive_shop := shop_archetype.duplicate(true)
		exhaustive_shop["item_count"] = [slot_shop_pool.size(), slot_shop_pool.size()]
		var shop_run_state: RunState = RunStateScript.new()
		shop_run_state.start_new("SLOT-PINBALL-SHOP-SPAWN", slot_only_challenge)
		var shop_environment := EnvironmentInstance.from_archetype(exhaustive_shop, 0, shop_run_state.create_rng("pinball_item_shop"), library, shop_run_state.challenge_config)
		var offered_item_ids: Array = []
		for offer_value in shop_environment.item_offers:
			if typeof(offer_value) != TYPE_DICTIONARY:
				continue
			var offer: Dictionary = offer_value
			offered_item_ids.append(str(offer.get("id", "")))
		for item_id_value in pinball_item_ids:
			var item_id := str(item_id_value)
			if not offered_item_ids.has(item_id):
				failures.append("Generated slot-only shop did not offer pinball item %s when the full pool was available." % item_id)

	var game: GameModule = _slot_game(library, failures)
	if game == null:
		return

	var cumquat_item: Dictionary = library.item("cumquat_sandwich")
	if str(cumquat_item.get("rarity", "")) != "legendary" or bool(cumquat_item.get("sellable", true)):
		failures.append("Cumquat Sandwich should be a legendary non-shop item.")
	var cumquat_run: RunState = _slot_run_state("SLOT-ITEM-CUMQUAT", 100000)
	var cumquat_environment: Dictionary = _slot_environment()
	var cumquat_machine: Dictionary = _slot_machine(definition, cumquat_run, "pinball", "classic_3_reel", "standard", "plain")
	_slot_store_machine(cumquat_run, cumquat_environment, cumquat_machine)
	cumquat_run.add_item("cumquat_sandwich")
	var cumquat_command: Dictionary = game.active_item_command("cumquat_sandwich", cumquat_run, cumquat_environment, cumquat_run.create_rng("slot_item_cumquat_arm"))
	var cumquat_result: Dictionary = _slot_dict(cumquat_command.get("result", {}))
	if not bool(cumquat_command.get("handled", false)) or not bool(cumquat_result.get("ok", false)):
		failures.append("Cumquat Sandwich active item did not arm the slot cabinet.")
	else:
		GameModule.apply_result(cumquat_run, cumquat_result, cumquat_run.create_rng("slot_item_cumquat_apply"))
		if cumquat_run.inventory.has("cumquat_sandwich"):
			failures.append("Cumquat Sandwich was not consumed on use.")
		var armed_cumquat_state: Dictionary = _slot_dict(SlotMachineStateScript.read_machine(cumquat_environment, "slot").get("slot_item_state", {}))
		if not bool(armed_cumquat_state.get("cumquat_force_bonus_pending", false)):
			failures.append("Cumquat Sandwich did not persist its forced-bonus state.")
		var loaded_cumquat_run: RunState = RunStateScript.new()
		loaded_cumquat_run.from_dict(cumquat_run.to_dict())
		var loaded_cumquat_environment: Dictionary = _slot_dict(loaded_cumquat_run.current_environment)
		var loaded_cumquat_state: Dictionary = _slot_dict(SlotMachineStateScript.read_machine(loaded_cumquat_environment, "slot").get("slot_item_state", {}))
		if not bool(loaded_cumquat_state.get("cumquat_force_bonus_pending", false)):
			failures.append("Cumquat Sandwich forced-bonus state did not survive RunState round-trip.")
		var cumquat_rng: RngStream = loaded_cumquat_run.create_rng("slot_item_cumquat_spin")
		var cumquat_spin: Dictionary = game.resolve_with_context("spin", 10, loaded_cumquat_run, loaded_cumquat_environment, cumquat_rng, {})
		if not bool(cumquat_spin.get("slot_feature_triggered", false)) or not bool(cumquat_spin.get("slot_forced_bonus_item", false)):
			failures.append("Cumquat Sandwich did not force a slot bonus on the next paid spin.")
		if bool(cumquat_spin.get("ok", false)):
			GameModule.apply_result(loaded_cumquat_run, cumquat_spin, cumquat_rng)
		var consumed_cumquat_state: Dictionary = _slot_dict(SlotMachineStateScript.read_machine(loaded_cumquat_environment, "slot").get("slot_item_state", {}))
		if bool(consumed_cumquat_state.get("cumquat_force_bonus_pending", false)):
			failures.append("Cumquat Sandwich forced-bonus state was not cleared after the paid spin.")

	var grease_run: RunState = _slot_run_state("SLOT-ITEM-GREASE", 100000)
	var grease_environment: Dictionary = _slot_environment()
	var grease_machine: Dictionary = _slot_machine(definition, grease_run, "buffalo", "line_5x3", "standard", "plain")
	_slot_store_machine(grease_run, grease_environment, grease_machine)
	grease_run.add_item("lucky_reel_grease")
	var grease_command: Dictionary = game.active_item_command("lucky_reel_grease", grease_run, grease_environment, grease_run.create_rng("slot_item_grease_arm"))
	var grease_result: Dictionary = _slot_dict(grease_command.get("result", {}))
	if not bool(grease_command.get("handled", false)) or not bool(grease_result.get("ok", false)):
		failures.append("Lucky Reel Grease active item did not arm the slot cabinet.")
	else:
		GameModule.apply_result(grease_run, grease_result, grease_run.create_rng("slot_item_grease_apply"))
		if grease_run.inventory.has("lucky_reel_grease"):
			failures.append("Lucky Reel Grease was not consumed on use.")
		var loaded_grease_run: RunState = RunStateScript.new()
		loaded_grease_run.from_dict(grease_run.to_dict())
		var loaded_grease_state: Dictionary = _slot_dict(SlotMachineStateScript.read_machine(loaded_grease_run.current_environment, "slot").get("slot_item_state", {}))
		if int(loaded_grease_state.get("lucky_reel_grease_spins", 0)) != 10:
			failures.append("Armed Lucky Reel Grease state did not survive RunState round-trip.")
	var grease_rng: RngStream = grease_run.create_rng("slot_item_grease_spins")
	var grease_near_misses := 0
	var grease_features := 0
	for _spin_index in range(10):
		var spin_result: Dictionary = game.resolve_with_context("spin", 10, grease_run, grease_environment, grease_rng, {})
		if bool(spin_result.get("slot_feature_triggered", false)):
			grease_features += 1
		if str(spin_result.get("slot_classification", "")) == "near_miss":
			grease_near_misses += 1
			var offer: Dictionary = _slot_dict(SlotMachineStateScript.read_machine(grease_environment, "slot").get("last_nudge_offer", {}))
			if not bool(offer.get("lucky_reel_grease_active", false)):
				failures.append("Greased near-miss did not mark its nudge offer.")
		if bool(spin_result.get("ok", false)):
			GameModule.apply_result(grease_run, spin_result, grease_rng)
	if grease_near_misses != 3:
		failures.append("Lucky Reel Grease should produce three near-miss chances over ten spins; got %d." % grease_near_misses)
	if grease_features != 0:
		failures.append("Lucky Reel Grease produced a raw bonus without a successful nudge.")
	var grease_final_state: Dictionary = _slot_dict(SlotMachineStateScript.read_machine(grease_environment, "slot").get("slot_item_state", {}))
	if int(grease_final_state.get("lucky_reel_grease_spins", 0)) != 0:
		failures.append("Lucky Reel Grease did not expire after ten spins.")

	var nudge_run: RunState = _slot_run_state("SLOT-ITEM-NUDGE-HEAT", 100000)
	var nudge_environment: Dictionary = _slot_environment()
	var nudge_machine: Dictionary = _slot_machine(definition, nudge_run, "buffalo", "line_5x3", "standard", "plain")
	nudge_machine["slot_item_state"] = {
		"lucky_reel_grease_spins": 1,
		"lucky_reel_grease_target": 1,
		"lucky_reel_grease_near_misses": 0,
		"lucky_reel_grease_failed_nudge_heat_bonus": 14,
		"cold_quarters_charges": 6,
		"cold_quarter_heat_reduction": 6,
	}
	_slot_store_machine(nudge_run, nudge_environment, nudge_machine)
	var nudge_rng: RngStream = nudge_run.create_rng("slot_item_nudge_heat")
	var nudge_spin: Dictionary = game.resolve_with_context("spin", 10, nudge_run, nudge_environment, nudge_rng, {})
	if str(nudge_spin.get("slot_classification", "")) != "near_miss":
		failures.append("Greased nudge heat fixture did not create a near miss.")
	else:
		GameModule.apply_result(nudge_run, nudge_spin, nudge_rng)
		var nudge_offer: Dictionary = _slot_dict(SlotMachineStateScript.read_machine(nudge_environment, "slot").get("last_nudge_offer", {}))
		var nudge_window: Dictionary = _slot_dict(nudge_offer.get("skill_window_msec", {}))
		var miss_msec := int(nudge_window.get("end", 0)) + 300
		var miss_result: Dictionary = game.resolve_with_context("nudge", 0, nudge_run, nudge_environment, nudge_rng, {"slot_tease_input_msec": miss_msec})
		if str(miss_result.get("slot_nudge_skill_outcome", "")) != "blown":
			failures.append("Slot nudge heat fixture did not record a miss.")
		if int(miss_result.get("slot_grease_failed_nudge_heat_bonus", 0)) < 14:
			failures.append("Failed greased nudge did not add the extra heat penalty.")
		if not bool(miss_result.get("slot_cold_quarter_used", false)) or int(miss_result.get("slot_cold_quarters_remaining", -1)) != 5:
			failures.append("Cold Quarters did not consume exactly one charge on nudge.")
		if int(miss_result.get("suspicion_delta", 0)) < 20:
			failures.append("Failed greased nudge did not produce the expected high heat.")

	var timing_run: RunState = _slot_run_state("SLOT-ITEM-TIMING", 100000)
	timing_run.add_item("timing_bracelet")
	var timing_environment: Dictionary = _slot_environment()
	var timing_machine: Dictionary = _slot_machine(definition, timing_run, "buffalo", "line_5x3", "standard", "plain")
	timing_machine["slot_item_state"] = {
		"lucky_reel_grease_spins": 1,
		"lucky_reel_grease_target": 1,
		"lucky_reel_grease_near_misses": 0,
		"split_reel_note_armed": true,
		"split_reel_note_perfect_msec_bonus": 55,
		"split_reel_note_close_msec_bonus": 90,
	}
	_slot_store_machine(timing_run, timing_environment, timing_machine)
	var timing_spin: Dictionary = game.resolve_with_context("spin", 10, timing_run, timing_environment, timing_run.create_rng("slot_item_timing_spin"), {})
	if str(timing_spin.get("slot_classification", "")) != "near_miss":
		failures.append("Timing item fixture did not create a Buffalo near miss.")
	var timing_offer: Dictionary = _slot_dict(SlotMachineStateScript.read_machine(timing_environment, "slot").get("last_nudge_offer", {}))
	var timing_good_msec := int(timing_offer.get("skill_good_msec", timing_offer.get("skill_close_msec", 0)))
	if int(timing_offer.get("skill_perfect_msec", 0)) < 145 or timing_good_msec < 325:
		failures.append("Timing Bracelet and Split-Reel Note did not widen the Buffalo timing cue.")
	if not bool(timing_offer.get("split_reel_note", false)):
		failures.append("Split-Reel Note did not mark the next Buffalo nudge offer.")

	var refund_run: RunState = _slot_run_state("SLOT-ITEM-REFUND", 100000)
	refund_run.add_item("coin_return_shim")
	var refund_environment: Dictionary = _slot_environment()
	var refund_machine: Dictionary = _slot_machine(definition, refund_run, "pinball", "classic_3_reel", "standard", "plain")
	_slot_store_machine(refund_run, refund_environment, refund_machine)
	var refund_rng: RngStream = refund_run.create_rng("slot_item_refund")
	var refund_found := false
	for _refund_index in range(120):
		var refund_result: Dictionary = game.resolve_with_context("spin", 10, refund_run, refund_environment, refund_rng, {})
		if int(refund_result.get("slot_loss_refund", 0)) > 0:
			refund_found = true
			break
	if not refund_found:
		failures.append("Coin-Return Shim did not refund any losing classic three-reel spin.")
	var wide_run: RunState = _slot_run_state("SLOT-ITEM-WIDE-REFUND", 100000)
	wide_run.add_item("coin_return_shim")
	var wide_environment: Dictionary = _slot_environment()
	var wide_machine: Dictionary = _slot_machine(definition, wide_run, "pinball", "line_5x3", "standard", "plain")
	_slot_store_machine(wide_run, wide_environment, wide_machine)
	var wide_rng: RngStream = wide_run.create_rng("slot_item_wide_refund")
	for _wide_index in range(120):
		var wide_result: Dictionary = game.resolve_with_context("spin", 10, wide_run, wide_environment, wide_rng, {})
		if int(wide_result.get("slot_stake_cost", 0)) > int(wide_result.get("slot_payout", 0)):
			if int(wide_result.get("slot_loss_refund", 0)) > 0:
				failures.append("Coin-Return Shim refunded a non-three-reel slot spin.")
			break

	var charm_run: RunState = _slot_run_state("SLOT-ITEM-CHARM", 100000)
	charm_run.add_item("neon_players_charm")
	var charm_environment: Dictionary = _slot_environment()
	var charm_machine: Dictionary = _slot_machine(definition, charm_run, "buffalo", "line_5x3", "standard", "plain")
	charm_machine["active_bonus"] = {
		"active": true,
		"complete": false,
		"family": "buffalo",
		"mode": "hold_and_spin",
		"display_mode": "gold_stampede_lock",
		"bet_id": "bet_10",
		"stake": 10,
		"pending_award": 30,
		"feature_total": 30,
		"remaining_steps": 1,
		"total_steps": 1,
		"step_index": 0,
		"respins_remaining": 1,
		"max_cells": 3,
		"reel_count": 3,
		"row_count": 1,
		"locks": [
			{"cell": 0, "reel": 0, "row": 0, "symbol": "CASH", "value": 10, "multiplier": 1},
			{"cell": 1, "reel": 1, "row": 0, "symbol": "CASH", "value": 10, "multiplier": 1},
			{"cell": 2, "reel": 2, "row": 0, "symbol": "CASH", "value": 10, "multiplier": 1},
		],
		"history": [],
		"feature_scale": 1.0,
		"session_cap": 10000,
	}
	_slot_store_machine(charm_run, charm_environment, charm_machine)
	var charm_result: Dictionary = game.resolve_with_context("slot_bonus_launch", 0, charm_run, charm_environment, charm_run.create_rng("slot_item_charm"), {})
	if int(charm_result.get("slot_first_bonus_item_award", 0)) <= 0:
		failures.append("Neon Player's Charm did not add a first-feature slot bonus.")

	var buffalo = SlotFamilyBuffaloScript.new()
	var tooth_value: Dictionary = _slot_dict(buffalo.call("_free_game_coin_value", 10, 1.0, _slot_run_state("SLOT-ITEM-TOOTH", 1000).create_rng("slot_item_tooth"), {"slot_gold_tooth_coin_upgrade_chance": 100, "slot_gold_tooth_coin_multiplier": 2}))
	if int(tooth_value.get("value", 0)) < 20:
		failures.append("Gold-Tooth Token upgrade hook did not raise Buffalo coin values.")

	var magnet_run: RunState = _slot_run_state("SLOT-ITEM-MAGNET", 100000)
	magnet_run.add_item("feature_magnet")
	if magnet_run.item_effect_total("slot_feature_weight_bonus_percent", "slots") < 100:
		failures.append("Feature Magnet did not expose its slot feature-weight item effect.")
	var resolver = SlotResolverScript.new()
	var magnet_effects := {"slot_feature_weight_bonus_percent": 125, "slot_reel_win_weight_percent": 35}
	var pinball = SlotFamilyPinballScript.new()
	var pinball_machine: Dictionary = _slot_machine(definition, magnet_run, "pinball", "classic_3_reel", "standard", "plain")
	var pinball_base: Dictionary = _slot_outcome_weight_summary(pinball.outcome_table(pinball_machine, definition, false), pinball)
	var pinball_adjusted_value: Variant = resolver.call("_slot_item_adjusted_outcome_table", pinball_machine, pinball, definition, false, magnet_effects)
	var pinball_adjusted: Array = pinball_adjusted_value as Array if typeof(pinball_adjusted_value) == TYPE_ARRAY else []
	var pinball_magnet: Dictionary = _slot_outcome_weight_summary(pinball_adjusted, pinball)
	if int(pinball_magnet.get("feature", 0)) <= int(pinball_base.get("feature", 0)):
		failures.append("Feature Magnet did not increase pinball feature weight.")
	if int(pinball_magnet.get("reel_win", 0)) >= int(pinball_base.get("reel_win", 0)):
		failures.append("Feature Magnet did not decrease pinball reel-win weight.")
	var buffalo_machine: Dictionary = _slot_machine(definition, magnet_run, "buffalo", "line_5x3", "standard", "plain")
	var buffalo_base: Dictionary = _slot_outcome_weight_summary(buffalo.outcome_table(buffalo_machine, definition, false), buffalo)
	var buffalo_adjusted_value: Variant = resolver.call("_slot_item_adjusted_outcome_table", buffalo_machine, buffalo, definition, false, magnet_effects)
	var buffalo_adjusted: Array = buffalo_adjusted_value as Array if typeof(buffalo_adjusted_value) == TYPE_ARRAY else []
	var buffalo_magnet: Dictionary = _slot_outcome_weight_summary(buffalo_adjusted, buffalo)
	if int(buffalo_magnet.get("feature", 0)) <= int(buffalo_base.get("feature", 0)):
		failures.append("Feature Magnet did not increase Buffalo feature weight.")
	if int(buffalo_magnet.get("reel_win", 0)) >= int(buffalo_base.get("reel_win", 0)):
		failures.append("Feature Magnet did not decrease Buffalo reel-win weight.")
	print("SLOT_ITEM_PACK_EFFECTS items=%d grease_near=%d grease_features=%d refund=%s charm_bonus=%d tooth_value=%d magnet_pinball=%d/%d magnet_buffalo=%d/%d" % [
		slot_item_ids.size(),
		grease_near_misses,
		grease_features,
		str(refund_found),
		int(charm_result.get("slot_first_bonus_item_award", 0)),
		int(tooth_value.get("value", 0)),
		int(pinball_magnet.get("feature", 0)),
		int(pinball_magnet.get("reel_win", 0)),
		int(buffalo_magnet.get("feature", 0)),
		int(buffalo_magnet.get("reel_win", 0)),
	])


func _slot_outcome_weight_summary(table: Array, family) -> Dictionary:
	var summary := {"feature": 0, "reel_win": 0, "other": 0}
	for entry_value in table:
		var entry: Dictionary = _slot_dict(entry_value)
		var weight := maxi(0, int(entry.get("weight", 0)))
		var classification := str(entry.get("classification", ""))
		if family != null and bool(family.opens_feature(classification)):
			summary["feature"] = int(summary.get("feature", 0)) + weight
		elif classification == "ldw" or classification == "true_win":
			summary["reel_win"] = int(summary.get("reel_win", 0)) + weight
		else:
			summary["other"] = int(summary.get("other", 0)) + weight
	return summary


func _slot_deterministic_sequence(library: ContentLibrary, definition: Dictionary, seed: String) -> Dictionary:
	var game: GameModule = _slot_game(library, [])
	var run_state: RunState = _slot_run_state(seed, 100000)
	var environment: Dictionary = _slot_environment()
	var machine: Dictionary = _slot_machine(definition, run_state, "buffalo", "video_feature", "standard", "plain")
	_slot_store_machine(run_state, environment, machine)
	var rng: RngStream = run_state.create_rng("slot_determinism")
	var results: Array = []
	for _index in range(50):
		var result: Dictionary = game.resolve_with_context("spin", 10, run_state, environment, rng, {})
		results.append({
			"outcome": str(result.get("slot_outcome_id", "")),
			"classification": str(result.get("slot_classification", "")),
			"delta": int(result.get("bankroll_delta", 0)),
			"grid": JSON.stringify(result.get("slot_grid", [])),
		})
		if bool(result.get("ok", false)):
			GameModule.apply_result(run_state, result, rng)
		_slot_complete_active_bonus(game, run_state, environment, rng)
	return {
		"machine": SlotMachineStateScript.read_machine(environment, "slot").get("machine_key", ""),
		"results": results,
	}


func _check_slot_feature_reachability(library: ContentLibrary, definition: Dictionary, failures: Array) -> void:
	var game: GameModule = _slot_game(library, failures)
	if game == null:
		return
	if not _slot_trigger_and_complete_feature(game, definition, "pinball", "classic_3_reel", "em_bumper_drop", "SLOT-FEATURE-PINBALL", failures):
		failures.append("Slot pinball shot bonus did not trigger and complete.")
	if not _slot_trigger_and_complete_feature(game, definition, "buffalo", "line_5x3", "free_games", "SLOT-FEATURE-FREE", failures):
		failures.append("Slot buffalo free games did not trigger and complete.")
	if not _slot_trigger_and_complete_feature(game, definition, "buffalo", "video_feature", "hold_and_spin", "SLOT-FEATURE-HOLD", failures):
		failures.append("Slot buffalo hold-and-spin did not trigger and complete.")
	if not _slot_trigger_and_complete_feature(game, definition, "buffalo", "video_feature", "wheel", "SLOT-FEATURE-WHEEL", failures, "bet_20", "jackpot_boost"):
		failures.append("Slot buffalo wheel gateway jackpot path did not trigger and complete.")
	var buffalo = SlotFamilyBuffaloScript.new()
	var bet_2: Dictionary = buffalo.jackpot_award_for_bet("bet_2", 2, "grand")
	var bet_20: Dictionary = buffalo.jackpot_award_for_bet("bet_20", 20, "grand")
	if str(bet_2.get("tier", "")) != "grand" or int(bet_2.get("award", 0)) != 100:
		failures.append("Slot jackpot eligibility did not scale the bet_2 grand to 50x.")
	if str(bet_20.get("tier", "")) != "grand" or int(bet_20.get("award", 0)) != 1000:
		failures.append("Slot jackpot eligibility did not scale the bet_20 grand to 50x.")


func _check_slot_bonus_trigger_reveal_order(definition: Dictionary, failures: Array) -> void:
	var presentation = SlotPresentationScript.new()
	var renderer = SlotRendererScript.new()
	var fixtures: Array[Dictionary] = [
		{
			"label": "Pinball trigger",
			"family": "pinball",
			"format": "classic_3_reel",
			"classification": "bonus",
			"seed": "SLOT-PINBALL-TRIGGER-REVEAL",
			"trigger_symbol": "PINBALL",
		},
		{
			"label": "Buffalo trigger",
			"family": "buffalo",
			"format": "line_5x3",
			"classification": "free_games",
			"seed": "SLOT-BUFFALO-TRIGGER-REVEAL",
			"trigger_symbol": "GOLD_TOKEN",
		},
	]
	for fixture_value in fixtures:
		var fixture: Dictionary = fixture_value
		var sample: Dictionary = _slot_spin_until_classification(
			definition,
			str(fixture.get("family", "")),
			str(fixture.get("format", "")),
			str(fixture.get("classification", "")),
			str(fixture.get("seed", "")),
			failures
		)
		if sample.is_empty():
			continue
		var run_state_value: Variant = sample.get("run_state", null)
		if not run_state_value is RunState:
			failures.append("%s did not return a RunState." % str(fixture.get("label", "Slot trigger")))
			continue
		var run_state: RunState = run_state_value
		var machine: Dictionary = _slot_dict(sample.get("machine", {}))
		var result: Dictionary = _slot_dict(sample.get("result", {}))
		var timeline: Array = _slot_array(result.get("slot_reel_timeline", []))
		var reveal_msec := _slot_reveal_msec(timeline)
		var before_reveal_msec := maxi(0, reveal_msec - 120)
		var after_reveal_msec := reveal_msec + 80
		var trigger_grid: Array = _slot_array(result.get("slot_grid", []))
		if _slot_symbol_count(trigger_grid, str(fixture.get("trigger_symbol", ""))) < 3:
			failures.append("%s did not produce a visible three-symbol trigger grid." % str(fixture.get("label", "Slot trigger")))
		var before_surface: Dictionary = presentation.surface_state(machine, run_state, definition, _slot_surface_ui_at_spin_msec(before_reveal_msec))
		var before_scene: Dictionary = _slot_dict(before_surface.get("slot_feature_scene", {}))
		var before_manifest: Dictionary = renderer.render_signature(before_surface, definition, before_reveal_msec, "")
		if not bool(before_surface.get("slot_bonus_trigger_reveal_pending", false)):
			failures.append("%s did not mark the bonus trigger reveal as pending before the reels settled." % str(fixture.get("label", "Slot trigger")))
		if bool(before_surface.get("slot_active_bonus_active", false)) or bool(before_scene.get("active", false)):
			failures.append("%s showed the bonus feature before the triggering spin was revealed." % str(fixture.get("label", "Slot trigger")))
		if str(before_manifest.get("mode", "")) != "spin":
			failures.append("%s render signature left spin mode before reveal." % str(fixture.get("label", "Slot trigger")))
		if JSON.stringify(_slot_array(before_surface.get("slot_grid", []))) != JSON.stringify(trigger_grid):
			failures.append("%s did not keep the trigger grid visible during the pre-feature reveal." % str(fixture.get("label", "Slot trigger")))
		var after_surface: Dictionary = presentation.surface_state(machine, run_state, definition, _slot_surface_ui_at_spin_msec(after_reveal_msec))
		var after_scene: Dictionary = _slot_dict(after_surface.get("slot_feature_scene", {}))
		var after_manifest: Dictionary = renderer.render_signature(after_surface, definition, after_reveal_msec, "")
		if bool(after_surface.get("slot_bonus_trigger_reveal_pending", true)):
			failures.append("%s kept the bonus trigger reveal gate active after the reveal beat." % str(fixture.get("label", "Slot trigger")))
		if not bool(after_surface.get("slot_active_bonus_active", false)) or not bool(after_scene.get("active", false)):
			failures.append("%s did not enter the bonus feature after the triggering spin reveal." % str(fixture.get("label", "Slot trigger")))
		if str(after_manifest.get("mode", "")) != "feature":
			failures.append("%s render signature did not enter feature mode after reveal." % str(fixture.get("label", "Slot trigger")))


func _check_slot_cabinet_distinctness(_library: ContentLibrary, definition: Dictionary, failures: Array) -> void:
	var catalog = SlotCatalogScript.new()
	var renderer = SlotRendererScript.new()
	var identities: Dictionary = {}
	var toppers: Dictionary = {}
	var geometries: Dictionary = {}
	var signatures: Dictionary = {}
	for family_id in ["pinball", "buffalo"]:
		for format_id in ["classic_3_reel", "line_5x3", "video_feature"]:
			var machine := {
				"type_id": family_id,
				"format_id": format_id,
				"cabinet_variant_id": "neon_magenta",
			}
			var skin: Dictionary = catalog.skin_for_machine(machine, definition)
			identities[str(skin.get("cabinet_identity", ""))] = true
			toppers[str(skin.get("topper_style", ""))] = true
			geometries[JSON.stringify(skin.get("reel_window", {})) + JSON.stringify(skin.get("playfield_rect", {}))] = true
			var surface := {
				"surface_renderer": "slot_machine",
				"slot_skin": skin,
				"slot_cabinet_signature": "%s:%s:%s:%s" % [str(skin.get("cabinet_identity", "")), str(skin.get("topper_style", "")), str(skin.get("material", "")), str(skin.get("motion_style", ""))],
				"slot_type_id": family_id,
				"slot_format_id": format_id,
				"slot_animation_id": "",
				"slot_reel_timeline": [],
				"slot_active_bonus": {},
				"slot_active_bonus_active": false,
			}
			signatures[JSON.stringify(renderer.render_signature(surface, definition, 0, "attract"))] = true
	if identities.size() != 6:
		failures.append("Slot cabinet identities are not unique across the six machines.")
	if toppers.size() < 6:
		failures.append("Slot cabinet toppers are not structurally distinct across the six machines.")
	if geometries.size() < 6:
		failures.append("Slot cabinet reel/playfield geometry is not distinct across the six machines.")
	if signatures.size() != 6:
		failures.append("Slot renderer signatures are not distinct across the six machines.")


func _check_slot_environment_preview(library: ContentLibrary, definition: Dictionary, failures: Array) -> void:
	var game: GameModule = _slot_game(library, failures)
	if game == null:
		return
	var run_state: RunState = _slot_run_state("SLOT-ENV-PREVIEW", 100000)
	var environment: Dictionary = _slot_environment()
	var machine: Dictionary = _slot_machine(definition, run_state, "buffalo", "line_5x3", "standard", "plain")
	_slot_store_machine(run_state, environment, machine)
	var rng: RngStream = run_state.create_rng("slot_environment_preview")
	var spin_result: Dictionary = game.resolve_with_context("spin", 10, run_state, environment, rng, {})
	if bool(spin_result.get("ok", false)):
		GameModule.apply_result(run_state, spin_result, rng)
	var running_machine: Dictionary = SlotMachineStateScript.read_machine(environment, "slot")
	running_machine["slot_autoplay_active"] = true
	running_machine["slot_autoplay_next_msec"] = Time.get_ticks_msec() + 8000
	SlotMachineStateScript.write_machine(environment, "slot", running_machine)
	var object_state: Dictionary = game.environment_object_state(run_state, environment)
	var runtime: Dictionary = _slot_dict(object_state.get("runtime_state", {}))
	var visual: Dictionary = _slot_dict(object_state.get("visual_state", {}))
	var preview: Dictionary = _slot_dict(visual.get("slot_preview", {}))
	if preview.is_empty():
		failures.append("Slot environment object did not package a slot_preview payload.")
	else:
		if str(preview.get("phase", "")).is_empty() or str(preview.get("caption", "")).is_empty():
			failures.append("Slot environment preview did not identify its current phase/caption.")
		if not bool(preview.get("autoplay_active", false)) or not bool(runtime.get("active", false)):
			failures.append("Slot environment preview did not expose active autoplay runtime state.")
		if _slot_array(preview.get("grid", [])).size() != int(preview.get("reel_count", 0)):
			failures.append("Slot environment preview grid was not trimmed to reel_count.")
		if _slot_array(_slot_dict(preview.get("spin", {})).get("timeline", [])).is_empty():
			failures.append("Slot environment preview did not include compact reel timing.")

	var near_sample: Dictionary = _slot_spin_until_classification(definition, "pinball", "line_5x3", "near_miss", "SLOT-ENV-PREVIEW-NUDGE", failures)
	if near_sample.is_empty():
		return
	var nudge_run: RunState = near_sample.get("run_state", run_state)
	var nudge_environment: Dictionary = _slot_environment()
	_slot_store_machine(nudge_run, nudge_environment, _slot_dict(near_sample.get("machine", {})))
	var nudge_state: Dictionary = game.environment_object_state(nudge_run, nudge_environment)
	var nudge_visual: Dictionary = _slot_dict(nudge_state.get("visual_state", {}))
	var nudge_preview: Dictionary = _slot_dict(nudge_visual.get("slot_preview", {}))
	var nudge_chain: Dictionary = _slot_dict(nudge_preview.get("nudge_chain", {}))
	if str(nudge_preview.get("phase", "")) != "nudge_chain" or not bool(nudge_chain.get("active", false)):
		failures.append("Slot environment preview did not identify a pending coin-chain nudge.")
	if int(nudge_chain.get("coin_count", 0)) <= 0 or _slot_array(nudge_chain.get("coins", [])).is_empty():
		failures.append("Slot environment preview did not include compact coin-chain row data.")
	print("SLOT_ENVIRONMENT_PREVIEW phase=%s caption=%s nudge=%s coins=%d" % [
		str(preview.get("phase", "")),
		str(preview.get("caption", "")),
		str(nudge_preview.get("phase", "")),
		int(nudge_chain.get("coin_count", 0)),
	])


func _check_slot_autoplay_toggle(library: ContentLibrary, definition: Dictionary, failures: Array) -> void:
	var game: GameModule = _slot_game(library, failures)
	if game == null:
		return
	var run_state: RunState = _slot_run_state("SLOT-AUTOPLAY-TOGGLE", 100000)
	var environment: Dictionary = _slot_environment()
	var machine: Dictionary = _slot_machine(definition, run_state, "buffalo", "video_feature", "standard", "plain")
	_slot_store_machine(run_state, environment, machine)
	var start_msec := 12000
	var command: Dictionary = game.surface_action_command("slot_auto_toggle", 0, false, {"surface_time_msec": start_msec, "drunk_scaled_surface_time_msec": start_msec}, run_state, environment)
	if not bool(command.get("handled", false)) or not bool(command.get("environment_changed", false)):
		failures.append("Slot autoplay toggle did not handle the one-click surface action.")
	var enabled_machine: Dictionary = SlotMachineStateScript.read_machine(environment, "slot")
	if not bool(enabled_machine.get("slot_autoplay_active", false)):
		failures.append("Slot autoplay toggle did not activate autoplay on one click.")
	if int(enabled_machine.get("slot_autoplay_next_msec", 0)) <= start_msec:
		failures.append("Slot autoplay toggle did not schedule a future first spin.")
	if game.surface_needs_auto_tick({"surface_time_msec": start_msec, "drunk_scaled_surface_time_msec": start_msec}, run_state, environment):
		failures.append("Slot autoplay requested an immediate spin on the same frame it was toggled on.")
	var surface: Dictionary = game.surface_state(run_state, environment, {"surface_time_msec": start_msec, "drunk_scaled_surface_time_msec": start_msec})
	if not bool(surface.get("slot_autoplay_active", false)):
		failures.append("Slot surface did not show AUTO ON after one click.")
	var off_command: Dictionary = game.surface_action_command("slot_auto_toggle", 0, false, {"surface_time_msec": start_msec + 1, "drunk_scaled_surface_time_msec": start_msec + 1}, run_state, environment)
	if not bool(off_command.get("handled", false)):
		failures.append("Slot autoplay off toggle was not handled.")
	var disabled_machine: Dictionary = SlotMachineStateScript.read_machine(environment, "slot")
	if bool(disabled_machine.get("slot_autoplay_active", false)) or int(disabled_machine.get("slot_autoplay_next_msec", -1)) != 0:
		failures.append("Slot autoplay off toggle did not clear active state and timer.")


func _check_slot_animation_present(library: ContentLibrary, definition: Dictionary, failures: Array) -> void:
	var game: GameModule = _slot_game(library, failures)
	if game == null:
		return
	var renderer = SlotRendererScript.new()
	var run_state: RunState = _slot_run_state("SLOT-ANIMATION-PRESENT", 100000)
	var environment: Dictionary = _slot_environment()
	var machine: Dictionary = _slot_machine(definition, run_state, "pinball", "line_5x3", "standard", "plain")
	_slot_store_machine(run_state, environment, machine)
	var rng: RngStream = run_state.create_rng("slot_animation_present")
	var result: Dictionary = game.resolve_with_context("spin", 10, run_state, environment, rng, {})
	var duration := int(result.get("slot_animation_duration_msec", 0))
	var timeline: Array = _slot_array(result.get("slot_reel_timeline", []))
	if duration <= 0:
		failures.append("Slot spin did not produce a positive animation duration.")
	if timeline.is_empty():
		failures.append("Slot spin did not produce a reel timeline.")
	else:
		var first: Dictionary = _slot_dict(timeline[0])
		for key in ["spin_up_end", "decel_start", "settle_end"]:
			if not first.has(key):
				failures.append("Slot reel timeline missing phase key: %s." % key)
	var early: Dictionary = game.surface_state(run_state, environment, {"surface_time_msec": 120})
	var mid_msec := _slot_spin_mid_msec(timeline)
	var mid: Dictionary = game.surface_state(run_state, environment, {"surface_time_msec": mid_msec})
	var settle: Dictionary = game.surface_state(run_state, environment, {"surface_time_msec": duration})
	var manifest_early: Dictionary = renderer.render_signature(early, definition, 120, "spin")
	var manifest_mid: Dictionary = renderer.render_signature(mid, definition, mid_msec, "spin")
	var manifest_settle: Dictionary = renderer.render_signature(settle, definition, duration, "spin")
	var sig_early := JSON.stringify(manifest_early)
	var sig_mid := JSON.stringify(manifest_mid)
	var sig_settle := JSON.stringify(manifest_settle)
	if sig_early == sig_mid or sig_mid == sig_settle or sig_early == sig_settle:
		failures.append("Slot renderer signature did not change across spin animation phases.")
	if not _slot_reel_manifest_progress(manifest_early, manifest_mid, manifest_settle):
		failures.append("Slot reel manifest did not progress through spin-up/decel/settle phases.")
	if not _slot_stops_are_staggered(_slot_array(manifest_mid.get("reel_stop_msec", []))):
		failures.append("Slot reel manifest did not report staggered reel stops.")


func _check_slot_reel_win_manifest(definition: Dictionary, failures: Array) -> void:
	var renderer = SlotRendererScript.new()
	var presentation = SlotPresentationScript.new()
	var true_sample: Dictionary = _slot_spin_until_classification(definition, "pinball", "line_5x3", "true_win", "SLOT-REEL-MANIFEST-TRUE", failures)
	if not true_sample.is_empty():
		var run_state_value: Variant = true_sample.get("run_state", null)
		if not run_state_value is RunState:
			failures.append("Slot reel manifest true_win sample did not return a RunState.")
		else:
			var sample_run_state: RunState = run_state_value
			var machine: Dictionary = _slot_dict(true_sample.get("machine", {}))
			var result: Dictionary = _slot_dict(true_sample.get("result", {}))
			var win_cells: Array = _slot_array(result.get("slot_win_cells", []))
			var grid: Array = _slot_array(result.get("slot_grid", []))
			var win_symbol := str(result.get("slot_win_symbol", ""))
			for cell_value in win_cells:
				var cell: Dictionary = _slot_dict(cell_value)
				var symbol := _slot_grid_symbol(grid, int(cell.get("reel", 0)), int(cell.get("row", 0)))
				if symbol != win_symbol and not _slot_symbol_is_wild(symbol, "pinball"):
					failures.append("Slot win attribution cell did not match the winning symbol or wild overlay.")
			var settle_msec := _slot_settle_msec(_slot_array(result.get("slot_reel_timeline", [])))
			var settle_surface: Dictionary = presentation.surface_state(machine, sample_run_state, definition, {"surface_time_msec": settle_msec})
			var settle_manifest: Dictionary = renderer.render_signature(settle_surface, definition, settle_msec, "spin")
			var plan: Dictionary = _slot_dict(result.get("slot_animation_plan", {}))
			var celebration_msec := (int(plan.get("count_up_start_msec", 0)) + int(plan.get("count_up_end_msec", 0))) / 2
			var celebration_surface: Dictionary = presentation.surface_state(machine, sample_run_state, definition, {"surface_time_msec": celebration_msec})
			var celebration_manifest: Dictionary = renderer.render_signature(celebration_surface, definition, celebration_msec, "spin")
			var reason := str(settle_manifest.get("win_reason_text", ""))
			if win_cells.is_empty() or int(settle_manifest.get("win_cells_highlighted", 0)) != win_cells.size():
				failures.append("Slot true_win manifest did not highlight exactly the attributed cells.")
			if not bool(settle_manifest.get("win_line_drawn", false)):
				failures.append("Slot true_win manifest did not report a drawn win line.")
			if reason.is_empty() or reason.find(win_symbol) == -1 or reason.find(str(win_cells.size())) == -1:
				failures.append("Slot true_win reason did not match the grid symbol/count.")
			if not bool(celebration_manifest.get("count_up_active", false)) or int(celebration_manifest.get("particle_count", 0)) <= 0:
				failures.append("Slot true_win celebration manifest did not expose count-up and particles.")
			var stake_cost := maxi(1, int(result.get("slot_stake_cost", SlotMachineStateScript.selected_bet(machine).get("total_credits", 10))))
			var big_true_machine: Dictionary = _slot_with_test_celebration(machine, "big", stake_cost * 20, stake_cost)
			var big_plan: Dictionary = _slot_dict(big_true_machine.get("slot_animation_plan", {}))
			var big_msec := (int(big_plan.get("count_up_start_msec", 0)) + int(big_plan.get("count_up_end_msec", 0))) / 2
			var big_surface: Dictionary = presentation.surface_state(big_true_machine, sample_run_state, definition, {"surface_time_msec": big_msec})
			var big_manifest: Dictionary = renderer.render_signature(big_surface, definition, big_msec, "spin")
			if not bool(big_manifest.get("shake_active", false)):
				failures.append("Slot true_win big-tier manifest did not expose sustained screen shake at the count-up midpoint.")
			if not bool(big_manifest.get("color_cycle_active", false)):
				failures.append("Slot true_win big-tier manifest did not expose color-cycle at the count-up midpoint.")
			print("SLOT_REEL_MANIFEST_TRUE_WIN early=%s mid=%s settle=%s highlighted=%d line=%s tier=%s count_up=%s particles=%d shake=%s color_cycle=%s reason=%s" % [
				",".join(_slot_string_array(renderer.render_signature(presentation.surface_state(machine, sample_run_state, definition, {"surface_time_msec": 120}), definition, 120, "spin").get("reel_phase", []))),
				",".join(_slot_string_array(renderer.render_signature(presentation.surface_state(machine, sample_run_state, definition, {"surface_time_msec": maxi(240, int(result.get("slot_animation_duration_msec", 0)) / 2)}), definition, maxi(240, int(result.get("slot_animation_duration_msec", 0)) / 2), "spin").get("reel_phase", []))),
				",".join(_slot_string_array(settle_manifest.get("reel_phase", []))),
				int(settle_manifest.get("win_cells_highlighted", 0)),
				str(settle_manifest.get("win_line_drawn", false)),
				str(big_manifest.get("celebration_tier", "")),
				str(big_manifest.get("count_up_active", false)),
				int(big_manifest.get("particle_count", 0)),
				str(big_manifest.get("shake_active", false)),
				str(big_manifest.get("color_cycle_active", false)),
				reason,
			])
	var near_sample: Dictionary = _slot_spin_until_classification(definition, "pinball", "line_5x3", "near_miss", "SLOT-REEL-MANIFEST-NEAR", failures)
	if not near_sample.is_empty():
		var near_run_value: Variant = near_sample.get("run_state", null)
		if not near_run_value is RunState:
			failures.append("Slot reel manifest near_miss sample did not return a RunState.")
		else:
			var near_run_state: RunState = near_run_value
			var near_machine: Dictionary = _slot_dict(near_sample.get("machine", {}))
			var near_result: Dictionary = _slot_dict(near_sample.get("result", {}))
			var near_timeline: Array = _slot_array(near_result.get("slot_reel_timeline", []))
			var tease_msec := _slot_tease_msec(near_timeline)
			var tease_surface: Dictionary = presentation.surface_state(near_machine, near_run_state, definition, {"surface_time_msec": tease_msec})
			var tease_manifest: Dictionary = renderer.render_signature(tease_surface, definition, tease_msec, "spin")
			var phases: Array = _slot_string_array(tease_manifest.get("reel_phase", []))
			var stops: Array = _slot_array(tease_manifest.get("reel_stop_msec", []))
			if not bool(tease_manifest.get("tease_active", false)):
				failures.append("Slot near_miss manifest did not expose tease_active.")
			if not phases.has("tease_slow_roll"):
				failures.append("Slot near_miss manifest did not enter tease_slow_roll.")
			if stops.size() >= 2 and int(stops[stops.size() - 1]) - int(stops[stops.size() - 2]) < 400:
				failures.append("Slot near_miss teasing reel stop was not dramatically extended.")
			if str(tease_manifest.get("win_reason_text", "")).find("SO CLOSE") == -1:
				failures.append("Slot near_miss manifest did not expose SO CLOSE reason text.")
			print("SLOT_REEL_MANIFEST_NEAR_MISS tease_active=%s phases=%s stops=%s reason=%s" % [
				str(tease_manifest.get("tease_active", false)),
				",".join(phases),
				",".join(_slot_string_array(stops)),
				str(tease_manifest.get("win_reason_text", "")),
			])
	_check_slot_tier_manifest(definition, presentation, renderer, failures)


func _check_slot_tier_manifest(definition: Dictionary, presentation, renderer, failures: Array) -> void:
	var resolver = SlotResolverScript.new()
	var buffalo = SlotFamilyBuffaloScript.new()
	var run_state: RunState = _slot_run_state("SLOT-TIER-MANIFEST", 100000)
	var machine: Dictionary = _slot_machine(definition, run_state, "buffalo", "video_feature", "standard", "plain")
	machine = SlotMachineStateScript.set_selected_bet(machine, "bet_20")
	var active: Dictionary = buffalo.open_feature(machine, {"classification": "monster_feature"}, 20, run_state.create_rng("slot_tier_open"), definition)
	active["choices"] = [
		{"id": "free_games", "label": "Free Games", "route": "free_games"},
		{"id": "hold_and_spin", "label": "Coin Link", "route": "hold_and_spin"},
		{"id": "jackpot_boost", "label": "Jackpot Boost", "route": "jackpot_boost"},
	]
	machine["active_bonus"] = active
	var resolved: Dictionary = resolver.resolve_bonus_action(machine, "slot_bonus_right", run_state.create_rng("slot_tier_step"), definition, {})
	var result: Dictionary = _slot_dict(resolved.get("result", {}))
	var completed: Dictionary = _slot_dict(resolved.get("machine", machine))
	var plan: Dictionary = _slot_dict(completed.get("slot_animation_plan", {}))
	var celebration_msec := (int(plan.get("count_up_start_msec", 80)) + int(plan.get("count_up_end_msec", 80))) / 2
	var surface: Dictionary = presentation.surface_state(completed, run_state, definition, {"surface_time_msec": celebration_msec})
	var manifest: Dictionary = renderer.render_signature(surface, definition, celebration_msec, "spin")
	var tier := str(manifest.get("celebration_tier", ""))
	if int(result.get("slot_bonus_award", 0)) <= 0:
		failures.append("Slot tier manifest sample did not produce a positive jackpot feature award.")
	if tier != "jackpot" and tier != "mega" and tier != "big":
		failures.append("Slot tier manifest did not report a big/mega/jackpot tier.")
	if not bool(manifest.get("count_up_active", false)) or int(manifest.get("particle_count", 0)) <= 0:
		failures.append("Slot tier manifest did not expose count-up and celebration particles.")
	if not bool(manifest.get("shake_active", false)):
		failures.append("Slot tier manifest did not expose screen shake for a big/mega/jackpot tier.")
	if not bool(manifest.get("color_cycle_active", false)):
		failures.append("Slot tier manifest did not expose a color-cycling celebration border for a big/mega/jackpot tier.")
	print("SLOT_WIN_TIER_MANIFEST tier=%s count_up=%s particles=%d shake=%s color_cycle=%s phase=%s reason=%s award=%d" % [
		tier,
		str(manifest.get("count_up_active", false)),
		int(manifest.get("particle_count", 0)),
		str(manifest.get("shake_active", false)),
		str(manifest.get("color_cycle_active", false)),
		str(manifest.get("border_color_phase", -1.0)),
		str(manifest.get("win_reason_text", "")),
		int(result.get("slot_bonus_award", 0)),
	])
	_check_slot_tier_manifest_sweep(definition, presentation, renderer, failures)


func _check_slot_tier_manifest_sweep(definition: Dictionary, presentation, renderer, failures: Array) -> void:
	var run_state: RunState = _slot_run_state("SLOT-TIER-SWEEP", 100000)
	var base_machine: Dictionary = _slot_machine(definition, run_state, "pinball", "line_5x3", "standard", "plain")
	for tier_value in ["none", "tease", "line", "feature", "big", "mega", "jackpot"]:
		var tier := str(tier_value)
		var paying := tier == "line" or tier == "feature" or tier == "big" or tier == "mega" or tier == "jackpot"
		var high := tier == "big" or tier == "mega" or tier == "jackpot"
		var payout := 100 if paying else 0
		var machine: Dictionary = _slot_with_test_celebration(base_machine, tier, payout, 10)
		var plan: Dictionary = _slot_dict(machine.get("slot_animation_plan", {}))
		var start_msec := int(plan.get("count_up_start_msec", 120))
		var end_msec := int(plan.get("count_up_end_msec", start_msec))
		var sample_msec := (start_msec + end_msec) / 2 if paying else start_msec
		var surface: Dictionary = presentation.surface_state(machine, run_state, definition, {"surface_time_msec": sample_msec})
		var manifest: Dictionary = renderer.render_signature(surface, definition, sample_msec, "spin")
		var count_up := bool(manifest.get("count_up_active", false))
		var particles := int(manifest.get("particle_count", 0))
		var shake := bool(manifest.get("shake_active", false))
		var color_cycle := bool(manifest.get("color_cycle_active", false))
		if paying and (not count_up or particles <= 0):
			failures.append("Slot tier sweep %s did not expose count-up and particles." % tier)
		if not paying and (count_up or particles != 0):
			failures.append("Slot tier sweep %s unexpectedly exposed paying-tier count-up/particles." % tier)
		if high and (not shake or not color_cycle):
			failures.append("Slot tier sweep %s did not expose shake and color-cycle." % tier)
		if not high and (shake or color_cycle):
			failures.append("Slot tier sweep %s unexpectedly exposed high-tier shake/color-cycle." % tier)
		print("SLOT_WIN_TIER_MANIFEST_SWEEP tier=%s count_up=%s particles=%d shake=%s color_cycle=%s phase=%s" % [
			tier,
			str(count_up),
			particles,
			str(shake),
			str(color_cycle),
			str(manifest.get("color_cycle_phase", -1.0)),
		])


func _check_slot_attract_mode(library: ContentLibrary, definition: Dictionary, failures: Array) -> void:
	var game: GameModule = _slot_game(library, failures)
	if game == null:
		return
	var renderer = SlotRendererScript.new()
	var run_state: RunState = _slot_run_state("SLOT-ATTRACT-MODE", 100000)
	var environment: Dictionary = _slot_environment()
	var machine: Dictionary = _slot_machine(definition, run_state, "buffalo", "classic_3_reel", "standard", "plain")
	_slot_store_machine(run_state, environment, machine)
	var idle_a: Dictionary = game.surface_state(run_state, environment, {"surface_time_msec": 0})
	var idle_b: Dictionary = game.surface_state(run_state, environment, {"surface_time_msec": 1260})
	var sig_a := JSON.stringify(renderer.render_signature(idle_a, definition, 0, "attract"))
	var sig_b := JSON.stringify(renderer.render_signature(idle_b, definition, 1260, "attract"))
	if sig_a == sig_b:
		failures.append("Slot attract-mode signature did not change over time.")
	var rng: RngStream = run_state.create_rng("slot_attract_spin")
	var result: Dictionary = game.resolve_with_context("spin", 10, run_state, environment, rng, {})
	var spin_surface: Dictionary = game.surface_state(run_state, environment, {"surface_time_msec": 240})
	var spin_sig := JSON.stringify(renderer.render_signature(spin_surface, definition, 240, "spin"))
	if spin_sig == sig_a or int(result.get("slot_animation_duration_msec", 0)) <= 0:
		failures.append("Slot attract signature was not distinct from spin presentation.")


func _check_slot_live_generated_features(library: ContentLibrary, definition: Dictionary, failures: Array) -> void:
	var game: GameModule = _slot_game(library, failures)
	if game == null:
		return
	var active_snapshot: Dictionary = _slot_find_feature_active(game, definition, "pinball", "classic_3_reel", "em_bumper_drop", "SLOT-LIVE-FEATURE-A", failures)
	if active_snapshot.is_empty():
		failures.append("Slot live feature test could not trigger pinball feature.")
		return
	var active: Dictionary = _slot_dict(active_snapshot.get("active_bonus", {}))
	if int(active.get("pending_award", 0)) != 0 or int(active.get("feature_total", 0)) != 0:
		failures.append("Slot feature had a pre-set award at trigger instead of live accumulation.")
	var run_state_value: Variant = active_snapshot.get("run_state", null)
	if not run_state_value is RunState:
		failures.append("Slot live feature helper did not return a RunState.")
		return
	var run_state: RunState = run_state_value
	var environment: Dictionary = _slot_dict(active_snapshot.get("environment", {}))
	var rng: RngStream = run_state.create_rng("slot_live_feature_steps")
	var first_step: Dictionary = game.resolve_with_context("slot_bonus_launch", 0, run_state, environment, rng, {})
	var after_first: Dictionary = _slot_dict(_slot_dict(first_step.get("slot_bonus_step", {})).get("active_bonus", {}))
	if _slot_array(after_first.get("history", [])).is_empty():
		failures.append("Slot live feature did not append per-step history.")
	var total_a := _slot_complete_feature_total_for_seed(definition, "pinball", "video_feature", "SLOT-LIVE-SEED-A", ["slot_bonus_left", "slot_bonus_launch", "slot_bonus_right", "slot_bonus_launch"])
	var total_b := _slot_complete_feature_total_for_seed(definition, "pinball", "video_feature", "SLOT-LIVE-SEED-B", ["slot_bonus_left", "slot_bonus_launch", "slot_bonus_right", "slot_bonus_launch"])
	var total_a_repeat := _slot_complete_feature_total_for_seed(definition, "pinball", "video_feature", "SLOT-LIVE-SEED-A", ["slot_bonus_left", "slot_bonus_launch", "slot_bonus_right", "slot_bonus_launch"])
	if total_a != total_a_repeat:
		failures.append("Slot live feature was not deterministic for same seed and inputs.")
	if total_a == total_b:
		failures.append("Slot live feature total did not vary across different seeds.")
	var total_input_alt := _slot_complete_feature_total_for_seed(definition, "pinball", "video_feature", "SLOT-LIVE-SEED-A", ["slot_bonus_right", "slot_bonus_launch", "slot_bonus_right", "slot_bonus_launch"])
	if total_input_alt == total_a:
		failures.append("Slot live feature total did not respond to different player inputs.")
	_check_slot_buffalo_feature_pauses_autoplay(game, definition, failures)


func _check_slot_bonus_completion_recovery(library: ContentLibrary, definition: Dictionary, failures: Array) -> void:
	var game: GameModule = _slot_game(library, failures)
	if game == null:
		return
	_check_slot_pinball_cap_completion(game, definition, failures)
	_check_slot_pinball_pending_animation_watchdog(game, definition, failures)
	_check_slot_pinball_save_load_watchdog(game, definition, failures)
	_check_slot_buffalo_zero_respin_completion(game, definition, failures)
	_check_slot_buffalo_save_load_completion(game, definition, failures)


func _check_slot_pinball_cap_completion(game: GameModule, definition: Dictionary, failures: Array) -> void:
	var pinball = SlotFamilyPinballScript.new()
	var run_state: RunState = _slot_run_state("SLOT-R8-PINBALL-CAP", 100000)
	var environment: Dictionary = _slot_environment()
	var machine: Dictionary = _slot_machine(definition, run_state, "pinball", "classic_3_reel", "standard", "plain")
	var active: Dictionary = pinball.open_feature(machine, 10, run_state.create_rng("r8_pinball_cap_open"), definition)
	active["headless"] = true
	active["total_steps"] = 1
	active["balls_remaining"] = 1
	active["remaining_steps"] = 1
	active["session_cap"] = 1
	machine["active_bonus"] = active
	_slot_store_machine(run_state, environment, machine)
	PinballFeatureScript.clear_runtime_session_cache()
	var rng: RngStream = run_state.create_rng("r8_pinball_cap_launch")
	var result: Dictionary = game.resolve_with_context("slot_bonus_launch", 0, run_state, environment, rng, {})
	if bool(result.get("ok", false)):
		GameModule.apply_result(run_state, result, rng)
	if not bool(result.get("slot_bonus_complete", false)):
		failures.append("Slot pinball session-cap fixture did not complete on the final headless ball.")
	if int(result.get("slot_bonus_award", 0)) > 1:
		failures.append("Slot pinball session-cap fixture paid above the exact cap.")
	_assert_slot_bonus_base_state(game, run_state, environment, "Pinball cap completion", failures)


func _check_slot_pinball_pending_animation_watchdog(game: GameModule, definition: Dictionary, failures: Array) -> void:
	var pinball = SlotFamilyPinballScript.new()
	var run_state: RunState = _slot_run_state("SLOT-R8-PINBALL-PENDING-ANIM", 100000)
	var environment: Dictionary = _slot_environment()
	var machine: Dictionary = _slot_machine(definition, run_state, "pinball", "line_5x3", "standard", "plain")
	var active: Dictionary = pinball.open_feature(machine, 10, run_state.create_rng("r8_pinball_pending_open"), definition)
	active["total_steps"] = 1
	active["balls_remaining"] = 0
	active["remaining_steps"] = 0
	active["active_ball_count"] = 0
	active["feature_total"] = 37
	active["pending_award"] = 37
	machine["active_bonus"] = active
	machine["slot_animation_id"] = "bonus:r8_pending"
	machine["slot_animation_duration_msec"] = 3000
	machine["slot_animation_plan"] = {"id": "bonus:r8_pending", "duration_msec": 3000, "feature_duration_msec": 3000}
	_slot_store_machine(run_state, environment, machine)
	PinballFeatureScript.clear_runtime_session_cache()
	if game.surface_needs_auto_tick({"surface_time_msec": 1200, "drunk_scaled_surface_time_msec": 1200}, run_state, environment):
		failures.append("Slot pinball watchdog fired while a bonus award animation was still pending.")
	var seeded: Dictionary = game.surface_auto_action_command({"surface_time_msec": 3200, "drunk_scaled_surface_time_msec": 3200}, run_state, environment, {})
	if not bool(seeded.get("environment_changed", false)):
		failures.append("Slot pinball watchdog did not arm after the pending award animation ended.")
	var due_time := 5600
	var command: Dictionary = game.surface_auto_action_command({"surface_time_msec": due_time, "drunk_scaled_surface_time_msec": due_time}, run_state, environment, {})
	if str(command.get("action_id", "")) != "slot_bonus_watchdog":
		failures.append("Slot pinball watchdog did not route through the watchdog bonus action after the grace window.")
	else:
		var rng: RngStream = run_state.create_rng("r8_pinball_pending_watchdog")
		var result: Dictionary = game.resolve_with_context(str(command.get("action_id", "")), 0, run_state, environment, rng, _slot_dict(command.get("ui_state", {})))
		if bool(result.get("ok", false)):
			GameModule.apply_result(run_state, result, rng)
		if int(result.get("slot_bonus_award", 0)) < 37:
			failures.append("Slot pinball watchdog did not preserve the pending feature award.")
		if str(result.get("slot_bonus_family", "")) != "pinball":
			failures.append("Slot pinball award result did not identify the pinball bonus family.")
		if str(result.get("surface_audio_cue", "")) != "pinball_money_ding":
			failures.append("Slot pinball award result did not request the money ding SFX cue.")
		var cue_context: Dictionary = _slot_dict(result.get("surface_audio_context", {}))
		if str(cue_context.get("action", "")) != "pinball_money_ding":
			failures.append("Slot pinball award SFX cue did not include a stable action id.")
	_assert_slot_bonus_base_state(game, run_state, environment, "Pinball pending-animation watchdog", failures)


func _check_slot_pinball_save_load_watchdog(game: GameModule, definition: Dictionary, failures: Array) -> void:
	var pinball = SlotFamilyPinballScript.new()
	var run_state: RunState = _slot_run_state("SLOT-R8-PINBALL-SAVELOAD", 100000)
	var environment: Dictionary = _slot_environment()
	var machine: Dictionary = _slot_machine(definition, run_state, "pinball", "classic_3_reel", "standard", "plain")
	var active: Dictionary = pinball.open_feature(machine, 10, run_state.create_rng("r8_pinball_save_open"), definition)
	active["total_steps"] = 1
	active["balls_remaining"] = 1
	active["remaining_steps"] = 1
	machine["active_bonus"] = active
	_slot_store_machine(run_state, environment, machine)
	var launch_rng: RngStream = run_state.create_rng("r8_pinball_save_launch")
	var launch_result: Dictionary = game.resolve_with_context("slot_bonus_launch", 0, run_state, environment, launch_rng, {"surface_time_msec": 100, "drunk_scaled_surface_time_msec": 100})
	if bool(launch_result.get("ok", false)):
		GameModule.apply_result(run_state, launch_result, launch_rng)
	var launched_machine: Dictionary = SlotMachineStateScript.read_machine(environment, "slot")
	var launched_active: Dictionary = _slot_dict(launched_machine.get("active_bonus", {}))
	launched_active["feature_total"] = maxi(29, int(launched_active.get("feature_total", 0)))
	launched_active["pending_award"] = maxi(29, int(launched_active.get("pending_award", 0)))
	launched_machine["active_bonus"] = launched_active
	SlotMachineStateScript.write_machine(environment, "slot", launched_machine)
	PinballFeatureScript.clear_runtime_session_cache()
	var restored: RunState = RunStateScript.new()
	restored.from_dict(run_state.to_dict())
	var restored_environment: Dictionary = _slot_dict(restored.current_environment)
	restored.current_environment = restored_environment
	var seed_time := 5000
	if not game.surface_needs_auto_tick({"surface_time_msec": seed_time, "drunk_scaled_surface_time_msec": seed_time}, restored, restored_environment):
		failures.append("Slot pinball save/load fixture did not request a watchdog seed after losing its runtime session.")
	var seed_command: Dictionary = game.surface_auto_action_command({"surface_time_msec": seed_time, "drunk_scaled_surface_time_msec": seed_time}, restored, restored_environment, {})
	if not bool(seed_command.get("environment_changed", false)):
		failures.append("Slot pinball save/load watchdog seed did not update the restored machine.")
	var due_time := 7600
	var command: Dictionary = game.surface_auto_action_command({"surface_time_msec": due_time, "drunk_scaled_surface_time_msec": due_time}, restored, restored_environment, {})
	if str(command.get("action_id", "")) != "slot_bonus_watchdog":
		failures.append("Slot pinball save/load fixture did not route the stale feature through the watchdog.")
	else:
		var rng: RngStream = restored.create_rng("r8_pinball_save_watchdog")
		var result: Dictionary = game.resolve_with_context(str(command.get("action_id", "")), 0, restored, restored_environment, rng, _slot_dict(command.get("ui_state", {})))
		if bool(result.get("ok", false)):
			GameModule.apply_result(restored, result, rng)
		if int(result.get("slot_bonus_award", 0)) < 29:
			failures.append("Slot pinball save/load watchdog lost the saved feature award.")
	_assert_slot_bonus_base_state(game, restored, restored_environment, "Pinball save/load watchdog", failures)


func _check_slot_buffalo_zero_respin_completion(game: GameModule, definition: Dictionary, failures: Array) -> void:
	var buffalo = SlotFamilyBuffaloScript.new()
	var run_state: RunState = _slot_run_state("SLOT-R8-BUFFALO-ZERO", 100000)
	var environment: Dictionary = _slot_environment()
	var machine: Dictionary = _slot_machine(definition, run_state, "buffalo", "video_feature", "standard", "plain")
	var active: Dictionary = buffalo.open_feature(machine, {"classification": "hold_and_spin"}, 10, run_state.create_rng("r8_buffalo_zero_open"), definition)
	active["remaining_steps"] = 0
	active["respins_remaining"] = 0
	active["feature_total"] = maxi(25, int(active.get("feature_total", 0)))
	active["pending_award"] = maxi(25, int(active.get("pending_award", 0)))
	machine["active_bonus"] = active
	_slot_store_machine(run_state, environment, machine)
	var rng: RngStream = run_state.create_rng("r8_buffalo_zero_launch")
	var result: Dictionary = game.resolve_with_context("slot_bonus_launch", 0, run_state, environment, rng, {})
	if bool(result.get("ok", false)):
		GameModule.apply_result(run_state, result, rng)
	if not bool(result.get("slot_bonus_complete", false)):
		failures.append("Slot buffalo hold-and-spin zero-respin fixture did not complete immediately.")
	if int(result.get("slot_bonus_award", 0)) < 25:
		failures.append("Slot buffalo hold-and-spin zero-respin fixture did not preserve the pending award.")
	_assert_slot_bonus_base_state(game, run_state, environment, "Buffalo zero-respin completion", failures)


func _check_slot_buffalo_save_load_completion(game: GameModule, definition: Dictionary, failures: Array) -> void:
	var buffalo = SlotFamilyBuffaloScript.new()
	var run_state: RunState = _slot_run_state("SLOT-R8-BUFFALO-SAVELOAD", 100000)
	var environment: Dictionary = _slot_environment()
	var machine: Dictionary = _slot_machine(definition, run_state, "buffalo", "line_5x3", "standard", "retrigger")
	machine["bonus_reel_strips"] = _slot_coin_heavy_reel_strips(maxi(1, int(machine.get("reel_count", 5))))
	var active: Dictionary = buffalo.open_feature(machine, {"classification": "free_games"}, 10, run_state.create_rng("r8_buffalo_save_open"), definition)
	active["remaining_steps"] = 1
	active["total_steps"] = 1
	active["coins_since_retrigger"] = 2
	machine["active_bonus"] = active
	_slot_store_machine(run_state, environment, machine)
	var restored: RunState = RunStateScript.new()
	restored.from_dict(run_state.to_dict())
	var restored_environment: Dictionary = _slot_dict(restored.current_environment)
	restored.current_environment = restored_environment
	var rng: RngStream = restored.create_rng("r8_buffalo_save_steps")
	_slot_complete_active_bonus(game, restored, restored_environment, rng)
	_assert_slot_bonus_base_state(game, restored, restored_environment, "Buffalo save/load completion", failures)
	var completed_machine: Dictionary = SlotMachineStateScript.read_machine(restored_environment, "slot")
	var replay: Dictionary = _slot_dict(completed_machine.get("last_bonus_replay", {}))
	if int(replay.get("retrigger_count", 0)) <= 0 and int(replay.get("last_retrigger_grant", 0)) <= 0:
		failures.append("Slot buffalo save/load fixture did not exercise the free-games retrigger edge.")


func _assert_slot_bonus_base_state(game: GameModule, run_state: RunState, environment: Dictionary, label: String, failures: Array) -> void:
	var machine: Dictionary = SlotMachineStateScript.read_machine(environment, "slot")
	var active: Dictionary = _slot_dict(machine.get("active_bonus", {}))
	if SlotMachineStateScript.active_bonus_incomplete(machine):
		failures.append("%s left active_bonus_incomplete true." % label)
	if bool(active.get("active", false)) or not bool(active.get("complete", true)):
		failures.append("%s did not clear active_bonus to the completed sentinel." % label)
	var elapsed_msec := maxi(0, int(machine.get("slot_animation_duration_msec", 0))) + 600
	var surface: Dictionary = game.surface_state(run_state, environment, {"surface_time_msec": elapsed_msec, "drunk_scaled_surface_time_msec": elapsed_msec})
	var scene: Dictionary = _slot_dict(surface.get("slot_feature_scene", {}))
	if bool(surface.get("slot_active_bonus_active", false)) or bool(scene.get("active", false)):
		failures.append("%s did not return the surface to the base slot state after the bonus replay elapsed." % label)


func _check_slot_buffalo_feature_pauses_autoplay(game: GameModule, definition: Dictionary, failures: Array) -> void:
	var buffalo = SlotFamilyBuffaloScript.new()
	var renderer = SlotRendererScript.new()
	var run_state: RunState = _slot_run_state("SLOT-BUFFALO-AUTO-BONUS", 100000)
	var environment: Dictionary = _slot_environment()
	var machine: Dictionary = _slot_machine(definition, run_state, "buffalo", "video_feature", "standard", "plain")
	var rng: RngStream = run_state.create_rng("buffalo_auto_open")
	var active: Dictionary = buffalo.open_feature(machine, {"classification": "hold_and_spin"}, 10, rng, definition)
	machine["active_bonus"] = active
	_slot_store_machine(run_state, environment, machine)
	var feature_surface: Dictionary = game.surface_state(run_state, environment, {"surface_time_msec": 2200})
	var feature_manifest: Dictionary = renderer.render_signature(feature_surface, definition, 2200, "feature")
	if bool(feature_manifest.get("pinball_takeover_active", false)) or bool(feature_manifest.get("default_controls_suppressed", false)):
		failures.append("Buffalo feature surface entered Pinball takeover/control mode.")
	var harness := SurfaceHarness.new()
	harness.setup(feature_surface)
	renderer.draw(harness, feature_surface, definition)
	var labels: Array = harness.labels.duplicate(true)
	if not labels.has("RESPIN"):
		failures.append("Buffalo hold-and-spin feature did not draw the RESPIN control.")
	if labels.has("LAUNCH") or labels.has("TILT") or _slot_labels_include_prefix(labels, "BALLS "):
		failures.append("Buffalo hold-and-spin feature drew Pinball launch controls.")
	if not game.surface_needs_auto_tick({"surface_time_msec": 2000}, run_state, environment):
		failures.append("Buffalo feature did not request its automatic reel wind-up tick.")
	var windup_command: Dictionary = game.surface_auto_action_command({"surface_time_msec": 2000}, run_state, environment, {})
	if not bool(windup_command.get("handled", false)) or not bool(windup_command.get("environment_changed", false)):
		failures.append("Buffalo feature automatic wind-up tick did not update the machine timer.")
	var wound_machine: Dictionary = SlotMachineStateScript.read_machine(environment, "slot")
	var auto_due_msec := int(wound_machine.get("slot_bonus_auto_next_msec", 0))
	if auto_due_msec <= 2000:
		failures.append("Buffalo feature automatic wind-up did not schedule a future spin.")
	if auto_due_msec > 0 and not game.surface_needs_auto_tick({"surface_time_msec": auto_due_msec}, run_state, environment):
		failures.append("Buffalo feature automatic spin tick was not requested when the timer matured.")
	var spin_command: Dictionary = game.surface_auto_action_command({"surface_time_msec": auto_due_msec}, run_state, environment, {})
	if not bool(spin_command.get("handled", false)) or str(spin_command.get("action_id", "")) != "slot_bonus_launch" or not bool(spin_command.get("direct_resolve", false)):
		failures.append("Buffalo feature automatic spin did not resolve through the bonus launch action.")

	machine = SlotMachineStateScript.read_machine(environment, "slot")
	machine["slot_autoplay_active"] = true
	machine["slot_autoplay_next_msec"] = 1
	_slot_store_machine(run_state, environment, machine)
	if not game.environment_runtime_needs_tick(run_state, environment, 2000):
		failures.append("Slot autoplay did not request a pause tick while a buffalo bonus was active.")
		return
	var tick: Dictionary = game.environment_runtime_tick(run_state, environment, run_state.create_rng("buffalo_auto_tick"), 2000)
	var paused_machine: Dictionary = SlotMachineStateScript.read_machine(environment, "slot")
	var paused_active: Dictionary = _slot_dict(paused_machine.get("active_bonus", {}))
	if not bool(tick.get("handled", false)) or bool(paused_machine.get("slot_autoplay_active", true)):
		failures.append("Slot autoplay did not pause on an active buffalo bonus.")
	if not bool(tick.get("attention", false)) or str(tick.get("audio_cue", "")) != "bonus_start_buffalo":
		failures.append("Slot autoplay pause did not report a buffalo feature alert cue.")
	if float(tick.get("audio_cue_volume_db", 0.0)) < -1.5:
		failures.append("Slot buffalo autoplay pause used the reduced pinball alert volume.")
	if not bool(paused_machine.get("slot_pending_feature_alert", false)):
		failures.append("Slot autoplay pause did not mark the machine as a pending feature.")
	var paused_runtime: Dictionary = game.environment_runtime_state(run_state, environment)
	if not bool(paused_runtime.get("slot_pending_feature", false)) or str(paused_runtime.get("slot_bonus_family", "")) != "buffalo":
		failures.append("Slot environment runtime state did not expose the pending buffalo feature.")
	if not _slot_array(paused_active.get("history", [])).is_empty() or int(paused_active.get("step_index", 0)) != int(active.get("step_index", 0)):
		failures.append("Slot autoplay pause advanced the buffalo feature.")
	var capped_machine: Dictionary = machine.duplicate(true)
	capped_machine["slot_animation_duration_msec"] = 24000
	capped_machine["slot_animation_plan"] = {
		"duration_msec": 24000,
		"feature_duration_msec": 24000,
		"count_up_end_msec": 24000,
		"celebration_start_msec": 12000,
		"celebration_duration_msec": 12000,
	}
	var capped_delay := int(game.call("_slot_autoplay_delay_msec", capped_machine))
	if capped_delay > 10000:
		failures.append("Slot buffalo autoplay delay exceeded the 10 second cap after a large bonus.")

	var pinball = SlotFamilyPinballScript.new()
	var pinball_run: RunState = _slot_run_state("SLOT-PINBALL-AUTO-BONUS", 100000)
	var pinball_environment: Dictionary = _slot_environment()
	var pinball_machine: Dictionary = _slot_machine(definition, pinball_run, "pinball", "video_feature", "standard", "plain")
	pinball_machine["active_bonus"] = pinball.open_feature(pinball_machine, 10, pinball_run.create_rng("pinball_auto_open"), definition)
	pinball_machine["slot_autoplay_active"] = true
	pinball_machine["slot_autoplay_next_msec"] = 1
	_slot_store_machine(pinball_run, pinball_environment, pinball_machine)
	var pinball_tick: Dictionary = game.environment_runtime_tick(pinball_run, pinball_environment, pinball_run.create_rng("pinball_auto_tick"), 2000)
	if str(pinball_tick.get("audio_cue", "")) != "bonus_start_pinball":
		failures.append("Slot pinball autoplay pause did not report the pinball feature alert cue.")
	if float(pinball_tick.get("audio_cue_volume_db", 0.0)) > -6.5:
		failures.append("Slot pinball autoplay pause did not use the reduced feature alert volume.")
	var pinball_runtime: Dictionary = game.environment_runtime_state(pinball_run, pinball_environment)
	if float(pinball_runtime.get("slot_feature_audio_volume_db", 0.0)) > -6.5:
		failures.append("Slot pinball runtime state did not expose the reduced feature alert volume.")
	print("SLOT_BUFFALO_FEATURE_AUTO_SEQUENCE handled=%s autoplay=%s history=%d respin_control=%s auto_due=%d" % [
		str(tick.get("handled", false)),
		str(paused_machine.get("slot_autoplay_active", false)),
		_slot_array(paused_active.get("history", [])).size(),
		str(labels.has("RESPIN")),
		auto_due_msec,
	])


func _slot_labels_include_prefix(labels: Array, prefix: String) -> bool:
	for label_value in labels:
		if str(label_value).begins_with(prefix):
			return true
	return false


func _check_slot_hold_and_spin_fill_scaling(definition: Dictionary, failures: Array) -> void:
	var buffalo = SlotFamilyBuffaloScript.new()
	var stake := 20
	var max_cells := 30
	var previous := -1
	for count in range(max_cells + 1):
		var award: int = buffalo.hold_award_for_lock_count(stake, count, max_cells, "bet_20")
		if award < previous:
			failures.append("Slot hold-and-spin award decreased as locked coin count increased.")
			break
		previous = award
	var full_award: int = buffalo.hold_award_for_lock_count(stake, max_cells, max_cells, "bet_20")
	if full_award < int(buffalo.jackpot_award_for_bet("bet_20", stake, "grand").get("award", 0)):
		failures.append("Slot hold-and-spin full grid did not award the grand.")
	var run_state: RunState = _slot_run_state("SLOT-HOLD-RESET", 100000)
	var machine: Dictionary = _slot_machine(definition, run_state, "buffalo", "video_feature", "standard", "plain")
	machine = SlotMachineStateScript.set_selected_bet(machine, "bet_20")
	var initial_grands: Dictionary = {}
	var saw_randomized_initial := false
	for option_value in SlotMachineStateScript.BET_OPTIONS:
		var option: Dictionary = option_value
		var bet_id := str(option.get("id", ""))
		var bet_stake := maxi(1, int(option.get("total_credits", 1)))
		var current_grand: int = buffalo.current_grand_prize(machine, bet_stake, bet_id)
		if current_grand < bet_stake * 50 or current_grand > bet_stake * 70:
			failures.append("Slot buffalo %s Grand did not start within the 50x-70x bet range." % bet_id)
		if current_grand > bet_stake * 50:
			saw_randomized_initial = true
		initial_grands[bet_id] = current_grand
	if not saw_randomized_initial:
		failures.append("Slot buffalo generated Grand prizes all started at the minimum instead of a seeded random value.")
	var bet_2_grand_before := int(initial_grands.get("bet_2", 0))
	var base_grand := int(initial_grands.get("bet_20", 0))
	var grown_grand: int = buffalo.advance_grand_prize(machine, stake, stake, "bet_20")
	if grown_grand != base_grand + int(ceil(float(stake) * 0.5)):
		failures.append("Slot buffalo bet_20 Grand did not grow by one-half the bet after a paid spin.")
	if buffalo.current_grand_prize(machine, 2, "bet_2") != bet_2_grand_before:
		failures.append("Slot buffalo bet_20 Grand growth leaked into the bet_2 Grand bucket.")
	var grown_bet_2: int = buffalo.advance_grand_prize(machine, 2, 2, "bet_2")
	if grown_bet_2 != bet_2_grand_before + 1:
		failures.append("Slot buffalo bet_2 Grand did not grow independently by one-half the bet.")
	var progressive_full_award: int = buffalo.hold_award_for_lock_count(stake, max_cells, max_cells, "bet_20", grown_grand)
	if progressive_full_award < grown_grand:
		failures.append("Slot hold-and-spin full grid did not include the progressive Grand amount.")
	machine["active_bonus"] = buffalo.open_feature(machine, {"classification": "hold_and_spin"}, stake, run_state.create_rng("slot_hold_open"), definition)
	var rng: RngStream = run_state.create_rng("slot_hold_reset")
	var saw_reset := false
	for _step in range(40):
		var before: Dictionary = _slot_dict(machine.get("active_bonus", {}))
		var before_locks := _slot_array(before.get("locks", [])).size()
		var step: Dictionary = buffalo.step_bonus(machine, "slot_bonus_launch", rng, definition)
		var after: Dictionary = _slot_dict(step.get("active_bonus", {}))
		if _slot_array(after.get("locks", [])).size() > before_locks and int(after.get("respins_remaining", 0)) == 3:
			saw_reset = true
			break
		if bool(after.get("complete", false)):
			machine["active_bonus"] = buffalo.open_feature(machine, {"classification": "hold_and_spin"}, stake, rng, definition)
	if not saw_reset:
		failures.append("Slot hold-and-spin did not reset respins when a new coin locked.")
	print("SLOT_HOLD_FILL_SCALING max_cells=%d full_award=%d grand_award=%d progressive_grand=%d saw_reset=%s" % [
		max_cells,
		full_award,
		int(buffalo.jackpot_award_for_bet("bet_20", stake, "grand").get("award", 0)),
		grown_grand,
		str(saw_reset),
	])


