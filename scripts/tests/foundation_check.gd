extends SceneTree

# Smoke test for production content and foundation contracts.

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const RunGeneratorScript := preload("res://scripts/core/run_generator.gd")
const SaveServiceScript := preload("res://scripts/core/save_service.gd")
const PlatformServicesScript := preload("res://scripts/core/platform_services.gd")
const ProfileInventoryScript := preload("res://scripts/core/profile_inventory.gd")
const RunTerminalEvaluatorScript := preload("res://scripts/core/run_terminal_evaluator.gd")
const RunActionServiceScript := preload("res://scripts/core/run_action_service.gd")
const ArtContractsScript := preload("res://scripts/core/art_contracts.gd")
const SlotMachineGeneratorScript := preload("res://scripts/games/slots/slot_machine_generator.gd")
const SlotMachineStateScript := preload("res://scripts/games/slots/slot_machine_state.gd")
const SlotResolverScript := preload("res://scripts/games/slots/slot_resolver.gd")
const SlotCatalogScript := preload("res://scripts/games/slots/slot_catalog.gd")
const SlotFamilyBuffaloScript := preload("res://scripts/games/slots/slot_family_buffalo.gd")
const SlotFamilyPinballScript := preload("res://scripts/games/slots/slot_family_pinball.gd")
const SlotPinballTableScript := preload("res://scripts/games/slots/slot_pinball_table.gd")
const SlotPresentationScript := preload("res://scripts/games/slots/slot_presentation.gd")
const SlotRendererScript := preload("res://scripts/games/slots/slot_renderer.gd")

const FOUNDATION_DEFAULT_REPORT_PATH := "res://.tmp/foundation_check/report.json"
const SLOT_ACCEPTANCE_MONTE_CARLO_SPINS := 10000
const SLOT_FEATURE_SUBSIMULATION_SAMPLES := 96
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
	var stake_control_count := 0
	var native_stake_strip_count := 0
	var animation_active := false
	var animation_elapsed := 999.0
	var animation_duration := 2.4

	func setup(state: Dictionary) -> void:
		surface_state = state.duplicate(true)
		hit_regions = []
		hovered_action = ""
		hovered_index = -1
		labels = []
		stake_control_count = 0
		native_stake_strip_count = 0
		animation_active = false
		animation_elapsed = 999.0
		animation_duration = 2.4

	func surface_board_size() -> Vector2:
		return Vector2(ArtContractsScript.GAME_BOARD_SIZE)

	func surface_begin_design_space(_design_size: Vector2) -> void:
		pass

	func surface_begin_design_space_inset(design_size: Vector2, _inset: Vector2) -> void:
		surface_begin_design_space(design_size)

	func surface_end_design_space() -> void:
		pass

	func surface_flicker() -> float:
		return 0.0

	func surface_elapsed(_channel_id: String) -> float:
		return animation_elapsed

	func surface_animation_active(_channel_id: String) -> bool:
		return animation_active

	func surface_animation_duration(_channel_id: String) -> float:
		return animation_duration

	func surface_animation_progress(_channel_id: String) -> float:
		return 1.0

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

	func surface_label(text: String, _pos: Vector2, _font_size: int, _color: Color) -> void:
		labels.append(text)

	func surface_label_centered(text: String, _rect: Rect2, _font_size: int, _color: Color) -> void:
		labels.append(text)

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

	func surface_add_hit(rect: Rect2, action: String, index: int = -1, _expand_touch_hit: bool = true) -> void:
		hit_regions.append({"rect": rect, "action": action, "index": index})

	func surface_add_invisible_hit(rect: Rect2, action: String, index: int = -1) -> void:
		surface_add_hit(rect, action, index)

	func surface_add_exact_hit(rect: Rect2, action: String, index: int = -1) -> void:
		surface_add_hit(rect, action, index, false)

	func surface_add_exact_invisible_hit(rect: Rect2, action: String, index: int = -1) -> void:
		surface_add_invisible_hit(rect, action, index)

	func draw_rect(_rect: Rect2, _color: Color, _filled: bool = true, _width: float = -1.0, _antialiased: bool = false) -> void:
		pass

	func draw_circle(_position: Vector2, _radius: float, _color: Color, _filled: bool = true, _width: float = -1.0, _antialiased: bool = false) -> void:
		pass

	func draw_line(_from: Vector2, _to: Vector2, _color: Color, _width: float = -1.0, _antialiased: bool = false) -> void:
		pass

	func draw_polygon(_points: Array, _colors: Array, _uvs: Array = [], _texture: Texture2D = null) -> void:
		pass


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
			_foundation_run_check(report, failures, "profile_inventory_boundary", Callable(self, "_check_profile_inventory_boundary"), [])
			_foundation_run_check(report, failures, "foundation_contract_smoke", Callable(self, "_check_foundation_contract_smoke_for_suite"), [content_library])
			_foundation_run_check(report, failures, "fixture_rng", Callable(self, "_check_rng"), [fixture_library])
			_foundation_run_check(report, failures, "fixture_contracts", Callable(self, "_check_contracts"), [fixture_library])
		"contracts":
			_foundation_run_contract_suite(content_library, fixture_library, failures, report)
		"games":
			_foundation_run_check(report, failures, "content", Callable(self, "_check_content"), [content_library])
			_foundation_run_check(report, failures, "game_surface_contracts", Callable(self, "_check_game_surface_contracts"), [content_library])
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
			if ["blackjack", "roulette", "baccarat", "video_poker", "bar_dice", "pull_tabs"].has(suite):
				_foundation_run_check(report, failures, "content", Callable(self, "_check_content"), [content_library])
				_foundation_run_check(report, failures, "%s_game_suite" % suite, Callable(self, "_check_target_game_suite"), [content_library, suite])
			else:
				_foundation_run_contract_suite(content_library, fixture_library, failures, report)


func _foundation_run_contract_suite(content_library: ContentLibrary, fixture_library: ContentLibrary, failures: Array, report: Dictionary) -> void:
	_foundation_run_check(report, failures, "content", Callable(self, "_check_content"), [content_library])
	_foundation_run_check(report, failures, "foundation_contracts", Callable(self, "_check_foundation_contract_smoke_for_suite"), [content_library])
	_foundation_run_check(report, failures, "profile_inventory_boundary", Callable(self, "_check_profile_inventory_boundary"), [])
	_foundation_run_check(report, failures, "fixture_rng", Callable(self, "_check_rng"), [fixture_library])
	_foundation_run_check(report, failures, "run_state_source_of_truth", Callable(self, "_check_run_state_source_of_truth"), [fixture_library])
	_foundation_run_check(report, failures, "fixture_contracts", Callable(self, "_check_contracts"), [fixture_library])


func _foundation_run_system_suite(content_library: ContentLibrary, fixture_library: ContentLibrary, failures: Array, report: Dictionary) -> void:
	_foundation_run_check(report, failures, "content", Callable(self, "_check_content"), [content_library])
	_foundation_run_check(report, failures, "profile_inventory_boundary", Callable(self, "_check_profile_inventory_boundary"), [])
	_foundation_run_check(report, failures, "fixture_rng", Callable(self, "_check_rng"), [fixture_library])
	_foundation_run_check(report, failures, "run_state_source_of_truth", Callable(self, "_check_run_state_source_of_truth"), [fixture_library])
	_foundation_run_check(report, failures, "fixture_contracts", Callable(self, "_check_contracts"), [fixture_library])
	_foundation_run_check(report, failures, "run_action_service_boundary", Callable(self, "_check_run_action_service_boundary"), [content_library])
	_foundation_run_check(report, failures, "item_effect_foundation", Callable(self, "_check_item_effect_foundation"), [content_library])
	_foundation_run_check(report, failures, "item_build_interaction_foundation", Callable(self, "_check_item_build_interaction_foundation"), [content_library])
	_foundation_run_check(report, failures, "event_module_foundation", Callable(self, "_check_event_module_foundation"), [content_library])
	_foundation_run_check(report, failures, "event_system_state_foundation", Callable(self, "_check_event_system_state_foundation"), [content_library])
	_foundation_run_check(report, failures, "save_service_foundation_round_trip", Callable(self, "_check_save_service_foundation_round_trip"), [content_library])
	_foundation_run_check(report, failures, "platform_services_foundation", Callable(self, "_check_platform_services_foundation"), [])
	_foundation_run_check(report, failures, "economy_pressure_foundation", Callable(self, "_check_economy_pressure_foundation"), [content_library])
	_foundation_run_check(report, failures, "travel_route_foundation", Callable(self, "_check_travel_route_foundation"), [content_library])
	_foundation_run_check(report, failures, "service_hook_foundation", Callable(self, "_check_service_hook_foundation"), [content_library])
	_foundation_run_check(report, failures, "jazz_club_foundation", Callable(self, "_check_jazz_club_foundation"), [content_library])
	_foundation_run_check(report, failures, "lender_debt_foundation", Callable(self, "_check_lender_debt_foundation"), [content_library])
	_foundation_run_check(report, failures, "suspicion_security_foundation", Callable(self, "_check_suspicion_security_foundation"), [])
	_foundation_run_check(report, failures, "skill_cheat_contract_foundation", Callable(self, "_check_skill_cheat_contract_foundation"), [content_library])
	_foundation_run_check(report, failures, "m2_system_interaction_scenario", Callable(self, "_check_m2_system_interaction_scenario"), [content_library])
	_foundation_run_check(report, failures, "demo_boss_objective_foundation", Callable(self, "_check_demo_boss_objective_foundation"), [content_library])
	_foundation_run_check(report, failures, "recovery_loss_pressure_foundation", Callable(self, "_check_recovery_loss_pressure_foundation"), [content_library])


func _foundation_run_all_suite(content_library: ContentLibrary, fixture_library: ContentLibrary, failures: Array, report: Dictionary) -> void:
	_foundation_run_check(report, failures, "content", Callable(self, "_check_content"), [content_library])
	_foundation_run_check(report, failures, "foundation_contracts_all", Callable(self, "_check_foundation_contract_smoke_for_suite"), [content_library])
	_foundation_run_check(report, failures, "profile_inventory_boundary", Callable(self, "_check_profile_inventory_boundary"), [])
	_foundation_run_check(report, failures, "fixture_rng", Callable(self, "_check_rng"), [fixture_library])
	_foundation_run_check(report, failures, "run_state_source_of_truth", Callable(self, "_check_run_state_source_of_truth"), [fixture_library])
	_foundation_run_check(report, failures, "fixture_contracts", Callable(self, "_check_contracts"), [fixture_library])


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
	_check_content_art_presentation(library, failures)
	_check_blackjack_item_content(library, failures)
	_check_m2_pack_availability(library, failures)
	_check_baccarat_grand_casino_only(library, failures)

	var run_state: RunState = RunStateScript.new()
	run_state.start_new("CONTENT-CHECK")
	var generator: RunGenerator = RunGeneratorScript.new(library)
	var first_environment: EnvironmentInstance = generator.next_environment(run_state)
	_check_environment_instance_shape(first_environment, true, failures)
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
	_check_environment_instance_shape(first_environment, true, failures)
	var second_environment: EnvironmentInstance = generator.next_environment(run_state, first_environment.next_archetypes[0] if not first_environment.next_archetypes.is_empty() else "")
	_check_environment_instance_shape(second_environment, false, failures)
	_check_production_game_module_load(library, run_state, first_environment, failures)
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
	_check_m2_system_interaction_scenario(library, failures)
	_check_demo_boss_objective_foundation(library, failures)
	_check_recovery_loss_pressure_foundation(library, failures)


func _check_profile_inventory_boundary(failures: Array) -> void:
	var profile_inventory: ProfileInventory = ProfileInventoryScript.new()
	profile_inventory.add_reference_chip()
	if not profile_inventory.has_item(ProfileInventory.REFERENCE_CHIP_ID):
		failures.append("ProfileInventory did not store the reference poker chip.")
	var snapshot := profile_inventory.to_dict()
	var restored: ProfileInventory = ProfileInventoryScript.new()
	restored.from_dict(snapshot)
	if restored.item_quantity(ProfileInventory.REFERENCE_CHIP_ID) != 1:
		failures.append("ProfileInventory did not round-trip the reference poker chip.")
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("PROFILE-INVENTORY-BOUNDARY")
	if run_state.to_dict().has("profile_inventory"):
		failures.append("Profile inventory leaked into RunState serialization.")


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
	if not legal_actions.is_empty():
		var legal_before := _run_state_result_snapshot(run_state)
		var legal_result := game.resolve(str(legal_actions[0].get("id", "")), 1, run_state, environment_data, run_state.create_rng())
		_check_action_result_shape(legal_result, "legal", failures)
		_check_action_result_application_contract(legal_before, run_state, legal_result, "legal smoke result", failures)
	if not cheat_actions.is_empty():
		var cheat_before := _run_state_result_snapshot(run_state)
		var cheat_result := game.resolve(str(cheat_actions[0].get("id", "")), 1, run_state, environment_data, run_state.create_rng())
		_check_action_result_shape(cheat_result, "cheat", failures)
		_check_action_result_application_contract(cheat_before, run_state, cheat_result, "cheat smoke result", failures)


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
	print("SLOT_CONTRACT_SMOKE cabinet_distinctness")
	_check_slot_cabinet_distinctness(library, definition, failures)
	print("SLOT_CONTRACT_SMOKE animation_present")
	_check_slot_animation_present(library, definition, failures)
	print("SLOT_CONTRACT_SMOKE hold_fill_scaling")
	_check_slot_hold_and_spin_fill_scaling(definition, failures)
	print("SLOT_CONTRACT_SMOKE free_games_carryover")
	_check_slot_free_games_carryover(definition, failures)
	print("SLOT_CONTRACT_SMOKE pinball_table_physics")
	_check_slot_pinball_table_physics(definition, failures)
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
	print("SLOT_ACCEPTANCE feature_reachability")
	_check_slot_feature_reachability(library, definition, failures)
	print("SLOT_ACCEPTANCE cabinet_distinctness")
	_check_slot_cabinet_distinctness(library, definition, failures)
	print("SLOT_ACCEPTANCE animation_present")
	_check_slot_animation_present(library, definition, failures)
	print("SLOT_ACCEPTANCE reel_win_manifest")
	_check_slot_reel_win_manifest(definition, failures)
	print("SLOT_ACCEPTANCE attract_mode")
	_check_slot_attract_mode(library, definition, failures)
	print("SLOT_ACCEPTANCE live_features")
	_check_slot_live_generated_features(library, definition, failures)
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
	print("SLOT_ACCEPTANCE pinball_table_physics")
	_check_slot_pinball_table_physics(definition, failures)
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
	var conversions := int(bonus_state.get("gold_buffalo_conversions", 0))
	if total_collected <= 0:
		failures.append("Gold Buffalo collection did not advance over 10,000 paid base spins.")
	if conversions <= 0:
		failures.append("Gold Buffalo conversion did not fire over 10,000 paid base spins.")


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
		var nudge_result: Dictionary = game.resolve_with_context("nudge", 10, run_state, environment, rng, {})
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
		if _slot_array(placement.get("skill_line_cells", [])).size() < mini(3, int(machine.get("reel_count", 5))):
			failures.append("Buffalo near-miss tease did not expose skill line cells.")
		if grid.is_empty():
			failures.append("Buffalo near-miss tease generated an empty grid.")
	if not bool(variant_counts.get(1, false)) or not bool(variant_counts.get(2, false)):
		failures.append("Buffalo near-miss generation did not cover both one-coin and two-coin tease states.")

	var near_sample: Dictionary = _slot_spin_until_classification(definition, "buffalo", "line_5x3", "near_miss", "SLOT-BUFFALO-NUDGE-NEAR", failures)
	if near_sample.is_empty():
		return
	var near_machine: Dictionary = _slot_dict(near_sample.get("machine", {}))
	var near_offer: Dictionary = _slot_dict(near_machine.get("last_nudge_offer", {}))
	var near_window: Dictionary = _slot_dict(near_offer.get("skill_window_msec", {}))
	var perfect_msec := int(near_window.get("perfect", -1))
	if perfect_msec < 0:
		failures.append("Buffalo near-miss nudge offer did not expose a perfect timing window.")
	var near_surface: Dictionary = presentation.surface_state(near_machine, run_state, definition, {"slot_tease_input_msec": perfect_msec})
	var near_manifest: Dictionary = renderer.render_signature(near_surface, definition, perfect_msec, "spin")
	if not bool(near_surface.get("slot_nudge_available", false)):
		failures.append("Buffalo timed nudge was not available on the tease surface.")
	if not bool(near_manifest.get("gold_tease_active", false)) or int(near_manifest.get("gold_tease_level", 0)) <= 0:
		failures.append("Buffalo timed nudge tease did not expose gold tease manifest data.")
	var cue_ids: Array = []
	for cue_value in _slot_array(near_surface.get("slot_audio_cues", [])):
		var cue: Dictionary = _slot_dict(cue_value)
		cue_ids.append(str(cue.get("cue_id", "")))
	if not cue_ids.has("gold_coin_tease"):
		failures.append("Buffalo timed nudge tease did not schedule the gold coin stinger.")
	if int(near_manifest.get("gold_tease_level", 0)) >= 2 and not cue_ids.has("double_gold_coin_tease"):
		failures.append("Buffalo double-coin tease did not schedule the double stinger.")
	var perfect_resolved: Dictionary = resolver.resolve_spin(near_machine.duplicate(true), "nudge", SlotMachineStateScript.selected_bet(near_machine), run_state.create_rng("buffalo_nudge_perfect"), definition, {}, true, false, null, {}, {"slot_tease_input_msec": perfect_msec})
	var perfect_action: Dictionary = _slot_dict(perfect_resolved.get("result", {}))
	if not bool(perfect_action.get("slot_nudge_applied", false)) or str(perfect_action.get("slot_nudge_skill_outcome", "")) != "perfect":
		failures.append("Buffalo timed nudge did not record a perfect skill outcome.")
	if not bool(perfect_action.get("slot_feature_triggered", false)):
		failures.append("Perfect Buffalo timed nudge did not trigger the feature.")

	var feature_sample: Dictionary = _slot_spin_until_classification(definition, "buffalo", "line_5x3", "free_games", "SLOT-BUFFALO-NUDGE-FEATURE", failures)
	if feature_sample.is_empty():
		return
	var feature_machine: Dictionary = _slot_dict(feature_sample.get("machine", {}))
	var feature_offer: Dictionary = _slot_dict(feature_machine.get("last_nudge_offer", {}))
	var feature_window: Dictionary = _slot_dict(feature_offer.get("skill_window_msec", {}))
	var miss_msec := int(feature_window.get("end", 0)) + 600
	var miss_resolved: Dictionary = resolver.resolve_spin(feature_machine.duplicate(true), "nudge", SlotMachineStateScript.selected_bet(feature_machine), run_state.create_rng("buffalo_nudge_miss"), definition, {}, true, false, null, {}, {"slot_tease_input_msec": miss_msec})
	var miss_action: Dictionary = _slot_dict(miss_resolved.get("result", {}))
	var miss_machine: Dictionary = _slot_dict(miss_resolved.get("machine", {}))
	if str(miss_action.get("slot_nudge_skill_outcome", "")) != "miss":
		failures.append("Mistimed Buffalo nudge did not record a miss outcome.")
	if bool(miss_action.get("slot_feature_triggered", false)):
		failures.append("Mistimed Buffalo nudge preserved a feature it should have broken.")
	if SlotMachineStateScript.active_bonus_incomplete(miss_machine):
		failures.append("Mistimed Buffalo nudge left the original feature active.")
	print("SLOT_BUFFALO_TIMED_NUDGE variants=%s level=%d perfect=%s miss_class=%s cues=%s" % [
		JSON.stringify(variant_counts.keys()),
		int(near_manifest.get("gold_tease_level", 0)),
		str(perfect_action.get("slot_nudge_skill_outcome", "")),
		str(miss_action.get("slot_classification", "")),
		",".join(_slot_string_array(cue_ids)),
	])


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
	if str(bet_2.get("tier", "")) != "mini":
		failures.append("Slot jackpot eligibility did not downshift bet_2 to mini.")
	if str(bet_20.get("tier", "")) != "grand" or int(bet_20.get("award", 0)) != 24000:
		failures.append("Slot jackpot eligibility did not award grand at bet_20.")


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
	var mid: Dictionary = game.surface_state(run_state, environment, {"surface_time_msec": maxi(180, duration / 2)})
	var settle: Dictionary = game.surface_state(run_state, environment, {"surface_time_msec": duration})
	var manifest_early: Dictionary = renderer.render_signature(early, definition, 120, "spin")
	var manifest_mid: Dictionary = renderer.render_signature(mid, definition, maxi(180, duration / 2), "spin")
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
	_check_slot_autoplay_advances_buffalo_bonus(game, definition, failures)


func _check_slot_autoplay_advances_buffalo_bonus(game: GameModule, definition: Dictionary, failures: Array) -> void:
	var buffalo = SlotFamilyBuffaloScript.new()
	var run_state: RunState = _slot_run_state("SLOT-BUFFALO-AUTO-BONUS", 100000)
	var environment: Dictionary = _slot_environment()
	var machine: Dictionary = _slot_machine(definition, run_state, "buffalo", "video_feature", "standard", "plain")
	var rng: RngStream = run_state.create_rng("buffalo_auto_open")
	var active: Dictionary = buffalo.open_feature(machine, {"classification": "hold_and_spin"}, 10, rng, definition)
	machine["active_bonus"] = active
	machine["slot_autoplay_active"] = true
	machine["slot_autoplay_next_msec"] = 1
	_slot_store_machine(run_state, environment, machine)
	if not game.environment_runtime_needs_tick(run_state, environment, 2000):
		failures.append("Slot autoplay did not request a runtime tick while a buffalo bonus was active.")
		return
	var tick: Dictionary = game.environment_runtime_tick(run_state, environment, run_state.create_rng("buffalo_auto_tick"), 2000)
	var result: Dictionary = _slot_dict(tick.get("result", {}))
	var step: Dictionary = _slot_dict(result.get("slot_bonus_step", {}))
	var step_active: Dictionary = _slot_dict(step.get("active_bonus", {}))
	if not bool(tick.get("handled", false)) or step.is_empty():
		failures.append("Slot autoplay runtime tick did not resolve a buffalo bonus step.")
		return
	if _slot_array(step_active.get("history", [])).is_empty():
		failures.append("Slot autoplay buffalo bonus step did not advance feature history.")
	print("SLOT_BUFFALO_AUTOPLAY_BONUS action=slot_bonus_launch handled=%s history=%d complete=%s" % [
		str(tick.get("handled", false)),
		_slot_array(step_active.get("history", [])).size(),
		str(step.get("complete", false)),
	])


func _check_slot_hold_and_spin_fill_scaling(definition: Dictionary, failures: Array) -> void:
	var buffalo = SlotFamilyBuffaloScript.new()
	var stake := 10
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
	print("SLOT_HOLD_FILL_SCALING max_cells=%d full_award=%d grand_award=%d saw_reset=%s" % [
		max_cells,
		full_award,
		int(buffalo.jackpot_award_for_bet("bet_20", stake, "grand").get("award", 0)),
		str(saw_reset),
	])


func _check_slot_free_games_carryover(definition: Dictionary, failures: Array) -> void:
	var buffalo = SlotFamilyBuffaloScript.new()
	var run_state: RunState = _slot_run_state("SLOT-FREE-CARRYOVER", 100000)
	var machine: Dictionary = _slot_machine(definition, run_state, "buffalo", "line_5x3", "standard", "plain")
	machine["bonus_reel_strips"] = _slot_coin_heavy_reel_strips(maxi(1, int(machine.get("reel_count", 5))))
	var active: Dictionary = buffalo.open_feature(machine, {"classification": "free_games"}, 10, run_state.create_rng("slot_free_open"), definition)
	active["remaining_steps"] = 4
	active["total_steps"] = 4
	machine["active_bonus"] = active
	var rng: RngStream = run_state.create_rng("slot_free_steps")
	var saw_coin := false
	var saw_retrigger := false
	var last_coin_count := int(active.get("coins_collected", 0))
	var normalized_kept_coins := false
	for _step in range(12):
		var step: Dictionary = buffalo.step_bonus(machine, "slot_bonus_launch", rng, definition)
		active = _slot_dict(step.get("active_bonus", {}))
		var coin_count := int(active.get("coins_collected", 0))
		if coin_count < last_coin_count:
			failures.append("Slot free-games coin collection did not carry over across spins.")
			return
		last_coin_count = coin_count
		if _slot_array(active.get("last_collected_coins", [])).size() > 0 and _slot_array(active.get("collected_coins", [])).size() > 0:
			saw_coin = true
			var normalized: Dictionary = SlotMachineStateScript.normalize({"active_bonus": active}).get("active_bonus", {})
			normalized_kept_coins = _slot_array(normalized.get("collected_coins", [])).size() > 0 and int(normalized.get("coin_total", 0)) > 0
		var history: Array = _slot_array(active.get("history", []))
		if not history.is_empty() and int(_slot_dict(history[history.size() - 1]).get("retrigger", 0)) > 0:
			saw_retrigger = true
		if saw_coin and saw_retrigger and normalized_kept_coins:
			break
	if not saw_coin:
		failures.append("Slot free-games did not collect persistent gold coins.")
	if not saw_retrigger:
		failures.append("Slot free-games carry-over test did not exercise the 3-coin retrigger.")
	if not normalized_kept_coins:
		failures.append("Slot free-games collected coin state did not survive normalization.")
	print("SLOT_FREE_GAMES_CARRYOVER coins=%d coin_total=%d coin=%s retrigger=%s normalized=%s steps_remaining=%d" % [
		last_coin_count,
		int(active.get("coin_total", 0)),
		str(saw_coin),
		str(saw_retrigger),
		str(normalized_kept_coins),
		int(active.get("remaining_steps", 0)),
	])


func _slot_coin_heavy_reel_strips(reel_count: int) -> Array:
	var strips: Array = []
	for _reel in range(maxi(1, reel_count)):
		strips.append(["GOLD_TOKEN", "BUFFALO", "GOLD_TOKEN", "SUNSET", "GOLD_TOKEN", "WOLF"])
	return strips


func _check_slot_buffalo_feature_presentation(definition: Dictionary, failures: Array) -> void:
	var buffalo = SlotFamilyBuffaloScript.new()
	var resolver = SlotResolverScript.new()
	var presentation = SlotPresentationScript.new()
	var renderer = SlotRendererScript.new()
	var run_state: RunState = _slot_run_state("SLOT-BUFFALO-PRESENTATION", 100000)

	var hold_machine: Dictionary = _slot_machine(definition, run_state, "buffalo", "video_feature", "standard", "plain")
	var hold_entry: Dictionary = {"id": "hold_and_spin", "classification": "hold_and_spin"}
	var hold_grid: Array = buffalo.force_outcome_symbols(hold_machine, _slot_array(hold_machine.get("last_grid", [])), hold_entry, run_state.create_rng("buffalo_present_hold_force"), definition)
	var placement: Dictionary = _slot_dict(hold_entry.get("forced_placement", {}))
	if str(placement.get("symbol", "")) != "GOLD_TOKEN":
		failures.append("Slot buffalo hold trigger placement did not identify GOLD_TOKEN cells.")
	for cell_value in _slot_array(placement.get("cells", [])):
		var cell: Dictionary = _slot_dict(cell_value)
		var reel := int(cell.get("reel", -1))
		var row := int(cell.get("row", -1))
		var column: Array = _slot_array(hold_grid[reel] if reel >= 0 and reel < hold_grid.size() else [])
		if row < 0 or row >= column.size() or str(column[row]) != "GOLD_TOKEN":
			failures.append("Slot buffalo hold trigger placement cell did not contain a visible gold token.")
			break
	hold_machine["last_grid"] = hold_grid
	var hold_active: Dictionary = buffalo.open_feature(hold_machine, hold_entry, 10, run_state.create_rng("buffalo_present_hold_open"), definition)
	if _slot_array(hold_active.get("locks", [])).size() != _slot_array(placement.get("cells", [])).size():
		failures.append("Slot buffalo hold feature did not preserve the triggering gold-token lock count.")
	for lock_value in _slot_array(hold_active.get("locks", [])):
		var lock: Dictionary = _slot_dict(lock_value)
		if str(lock.get("symbol", "")) != "GOLD_TOKEN":
			failures.append("Slot buffalo hold feature initial lock was not a GOLD_TOKEN.")
			break
	hold_machine["active_bonus"] = hold_active
	var hold_rng: RngStream = run_state.create_rng("buffalo_present_hold_steps")
	var hold_step_result: Dictionary = {}
	for _hold_step in range(6):
		hold_step_result = buffalo.step_bonus(hold_machine, "slot_bonus_launch", hold_rng, definition)
		hold_active = _slot_dict(hold_step_result.get("active_bonus", {}))
		hold_machine["active_bonus"] = hold_active
		hold_machine["last_grid"] = _slot_array(hold_step_result.get("grid", hold_machine.get("last_grid", [])))
		hold_machine["reel_stops"] = _slot_array(hold_step_result.get("reel_stops", hold_machine.get("reel_stops", [])))
		if _slot_array(hold_active.get("last_lock_events", [])).size() > 0:
			break
	if _slot_array(hold_step_result.get("grid", [])).is_empty() or _slot_array(hold_step_result.get("reel_stops", [])).is_empty():
		failures.append("Slot buffalo hold respin did not return a reel grid and stops for presentation.")
	var hold_animation_machine: Dictionary = hold_machine.duplicate(true)
	hold_animation_machine["active_bonus"] = hold_active
	var animation_step: Dictionary = resolver.resolve_bonus_action(hold_animation_machine, "slot_bonus_launch", run_state.create_rng("buffalo_present_hold_resolver"), definition)
	var animation_machine: Dictionary = _slot_dict(animation_step.get("machine", {}))
	if _slot_array(_slot_dict(animation_step.get("result", {})).get("slot_reel_timeline", [])).is_empty() or str(animation_machine.get("slot_animation_id", "")).find("bonus-step") == -1:
		failures.append("Slot buffalo hold respin did not use the normal reel animation path.")
	var hold_scene: Dictionary = _slot_dict(presentation.surface_state(hold_machine, run_state, definition, {"surface_time_msec": 2200}).get("slot_feature_scene", {}))
	var hold_manifest_early: Dictionary = renderer.render_signature(presentation.surface_state(hold_machine, run_state, definition, {"surface_time_msec": 900}), definition, 900, "feature")
	var hold_manifest: Dictionary = renderer.render_signature(presentation.surface_state(hold_machine, run_state, definition, {"surface_time_msec": 2200}), definition, 2200, "feature")
	if not bool(hold_manifest.get("ladder_visible", false)):
		failures.append("Slot buffalo hold feature manifest did not expose a jackpot ladder.")
	if int(hold_manifest.get("locked_cells", 0)) <= 0 or float(hold_manifest.get("fill_meter", 0.0)) <= 0.0:
		failures.append("Slot buffalo hold feature manifest did not expose locked cells and fill meter.")
	if _slot_array(hold_scene.get("last_lock_events", [])).is_empty() and int(hold_manifest.get("locked_cells", 0)) <= 8:
		failures.append("Slot buffalo hold feature did not expose coin-slam lock events.")
	if str(hold_manifest.get("buffalo_feature_music_id", "")) != "bonus_music_buffalo":
		failures.append("Slot buffalo hold feature did not expose the Buffalo feature music cue.")
	if int(hold_manifest.get("buffalo_main_board_coin_value_count", 0)) <= 0 or not bool(hold_manifest.get("buffalo_main_board_coin_values_visible", false)):
		failures.append("Slot buffalo hold feature did not draw coin values on the main board.")
	if not _slot_array(hold_scene.get("last_lock_events", [])).is_empty() and not bool(hold_manifest.get("buffalo_coin_bump_active", false)):
		failures.append("Slot buffalo hold feature did not mark new coin locks for a bump/glow reveal.")
	if not _slot_array(hold_scene.get("last_lock_events", [])).is_empty() and int(hold_manifest_early.get("buffalo_main_board_pending_lock_count", 0)) <= 0:
		failures.append("Slot buffalo hold feature did not keep new locks hidden while open cells spin.")
	if int(hold_manifest.get("buffalo_main_board_visible_lock_count", 0)) != int(hold_manifest.get("locked_cells", 0)):
		failures.append("Slot buffalo hold feature visible locks did not match the actual locked coin cells after reveal.")
	if int(hold_manifest.get("buffalo_main_board_unlocked_cell_count", 0)) > 0 and not bool(hold_manifest.get("buffalo_unlocked_spin_active", false)):
		failures.append("Slot buffalo hold feature did not identify unlocked cells as actively spinning.")

	var free_machine: Dictionary = _slot_machine(definition, run_state, "buffalo", "line_5x3", "standard", "plain")
	free_machine["bonus_reel_strips"] = _slot_coin_heavy_reel_strips(maxi(1, int(free_machine.get("reel_count", 5))))
	var free_active: Dictionary = buffalo.open_feature(free_machine, {"classification": "free_games"}, 10, run_state.create_rng("buffalo_present_free_open"), definition)
	free_active["remaining_steps"] = 4
	free_active["total_steps"] = 4
	free_machine["active_bonus"] = free_active
	var free_rng: RngStream = run_state.create_rng("buffalo_present_free_steps")
	for _free_step in range(12):
		var free_step_result: Dictionary = buffalo.step_bonus(free_machine, "slot_bonus_launch", free_rng, definition)
		free_active = _slot_dict(free_step_result.get("active_bonus", {}))
		free_machine["active_bonus"] = free_active
		free_machine["last_grid"] = _slot_array(free_step_result.get("grid", []))
		free_machine["reel_stops"] = _slot_array(free_step_result.get("reel_stops", []))
		if int(free_active.get("coins_collected", 0)) >= 3 and int(free_active.get("last_retrigger_grant", 0)) > 0:
			break
	var free_scene: Dictionary = _slot_dict(presentation.surface_state(free_machine, run_state, definition, {"surface_time_msec": 1600}).get("slot_feature_scene", {}))
	var free_manifest: Dictionary = renderer.render_signature(presentation.surface_state(free_machine, run_state, definition, {"surface_time_msec": 1600}), definition, 1600, "feature")
	if int(free_manifest.get("buffalo_coin_count", 0)) <= 0 or int(free_manifest.get("buffalo_coin_total", 0)) <= 0:
		failures.append("Slot buffalo free-games manifest did not expose collected coins.")
	if float(free_manifest.get("buffalo_coin_meter", 0.0)) < 0.0 or _slot_dict(free_scene.get("collection_meter", {})).is_empty() or _slot_array(free_scene.get("collected_coins", [])).is_empty():
		failures.append("Slot buffalo free-games scene did not expose the coin collection meter.")
	if str(free_manifest.get("buffalo_feature_music_id", "")) != "bonus_music_buffalo":
		failures.append("Slot buffalo free-games feature did not expose the Buffalo feature music cue.")
	if int(free_manifest.get("buffalo_main_board_coin_value_count", 0)) <= 0 or not bool(free_manifest.get("buffalo_main_board_coin_values_visible", false)):
		failures.append("Slot buffalo free-games feature did not draw coin values on the main board.")
	if not bool(free_manifest.get("buffalo_coin_bump_active", false)):
		failures.append("Slot buffalo free-games feature did not mark collected coins for a bump/glow reveal.")
	if int(free_manifest.get("buffalo_main_board_unlocked_cell_count", 0)) > 0 and not bool(free_manifest.get("buffalo_unlocked_spin_active", false)):
		failures.append("Slot buffalo free-games feature did not identify non-coin cells as actively spinning.")

	var trophy_machine: Dictionary = _slot_machine(definition, run_state, "buffalo", "video_feature", "standard", "plain")
	var trophy_active: Dictionary = buffalo.open_feature(trophy_machine, {"classification": "monster_feature"}, 20, run_state.create_rng("buffalo_present_trophy_open"), definition)
	trophy_machine["active_bonus"] = trophy_active
	var trophy_surface: Dictionary = presentation.surface_state(trophy_machine, run_state, definition, {"surface_time_msec": 300})
	var trophy_scene: Dictionary = _slot_dict(trophy_surface.get("slot_feature_scene", {}))
	var trophy_manifest: Dictionary = renderer.render_signature(trophy_surface, definition, 300, "feature")
	if not bool(trophy_manifest.get("trophy_pick_active", false)) or not bool(_slot_dict(trophy_scene.get("trophy_pick", {})).get("active", false)):
		failures.append("Slot buffalo video trophy pick was not reachable as an active gateway.")
	var trophy_step: Dictionary = buffalo.step_bonus(trophy_machine, "slot_bonus_right", run_state.create_rng("buffalo_present_trophy_pick"), definition)
	var trophy_after: Dictionary = _slot_dict(trophy_step.get("active_bonus", {}))
	var routed_mode := str(trophy_after.get("mode", ""))
	if routed_mode.is_empty() or _slot_array(trophy_after.get("trophy_reveals", [])).is_empty():
		failures.append("Slot buffalo trophy pick did not reveal and route into a feature.")

	var phase_surface_play: Dictionary = presentation.surface_state(hold_machine, run_state, definition, {"surface_time_msec": 1500})
	var phase_transition: Dictionary = trophy_manifest
	var phase_play: Dictionary = renderer.render_signature(phase_surface_play, definition, 1500, "feature")
	if str(phase_transition.get("stampede_phase", "")) != "transition" or str(phase_play.get("stampede_phase", "")) == "transition":
		failures.append("Slot buffalo feature-scene phases did not progress from transition to play.")
	print("SLOT_BUFFALO_FEATURE_PRESENTATION hold_ladder=%s locks=%d fill=%.3f hold_board_values=%d free_coins=%d coin_total=%d free_board_values=%d music=%s trophy_active=%s routed=%s phases=%s>%s" % [
		str(hold_manifest.get("ladder_visible", false)),
		int(hold_manifest.get("locked_cells", 0)),
		float(hold_manifest.get("fill_meter", 0.0)),
		int(hold_manifest.get("buffalo_main_board_coin_value_count", 0)),
		int(free_manifest.get("buffalo_coin_count", 0)),
		int(free_manifest.get("buffalo_coin_total", 0)),
		int(free_manifest.get("buffalo_main_board_coin_value_count", 0)),
		str(free_manifest.get("buffalo_feature_music_id", "")),
		str(trophy_manifest.get("trophy_pick_active", false)),
		routed_mode,
		str(phase_transition.get("stampede_phase", "")),
		str(phase_play.get("stampede_phase", "")),
	])


func _check_slot_pinball_escalation(definition: Dictionary, failures: Array) -> void:
	var pinball = SlotFamilyPinballScript.new()
	var run_state: RunState = _slot_run_state("SLOT-PINBALL-ESCALATION", 100000)
	var classic: Dictionary = _slot_machine(definition, run_state, "pinball", "classic_3_reel", "standard", "plain")
	var line: Dictionary = _slot_machine(definition, run_state, "pinball", "line_5x3", "standard", "plain")
	var video: Dictionary = _slot_machine(definition, run_state, "pinball", "video_feature", "standard", "plain")
	if pinball.feature_mode_for_machine(classic) != "em_bumper_drop":
		failures.append("Slot pinball classic feature did not use EM bumper-drop mode.")
	if pinball.feature_mode_for_machine(line) != "lane_multiball":
		failures.append("Slot pinball line feature did not use lane multiball mode.")
	if pinball.feature_mode_for_machine(video) != "video_feature":
		failures.append("Slot pinball video feature did not use full table mode.")
	var left_total := 0
	var right_total := 0
	for index in range(4):
		var left_rng: RngStream = run_state.create_rng("slot_pin_line_left_%d" % index)
		var right_rng: RngStream = run_state.create_rng("slot_pin_line_right_%d" % index)
		left_total += pinball.preview_feature_award(line.duplicate(true), 10, definition, left_rng, ["slot_bonus_left", "slot_bonus_left"])
		right_total += pinball.preview_feature_award(line.duplicate(true), 10, definition, right_rng, ["slot_bonus_left", "slot_bonus_right"])
	if left_total == right_total:
		failures.append("Slot pinball lane/power choices did not affect the line feature distribution sample.")
	var video_active: Dictionary = pinball.open_feature(video, 10, run_state.create_rng("slot_pin_video_open"), definition)
	video["active_bonus"] = video_active
	var before_physics := JSON.stringify(_slot_dict(video_active.get("physics", {})))
	var step: Dictionary = pinball.step_bonus(video, "slot_bonus_left", run_state.create_rng("slot_pin_video_left"), definition)
	var after_physics := JSON.stringify(_slot_dict(_slot_dict(step.get("active_bonus", {})).get("physics", {})))
	if before_physics == after_physics:
		failures.append("Slot pinball video flipper input did not change ball state.")
	var short_total: int = pinball.preview_feature_award(video.duplicate(true), 10, definition, run_state.create_rng("slot_pin_video_short"), ["slot_bonus_launch"])
	var keepalive_total: int = pinball.preview_feature_award(video.duplicate(true), 10, definition, run_state.create_rng("slot_pin_video_keep"), ["slot_bonus_left", "slot_bonus_right", "slot_bonus_left", "slot_bonus_launch", "slot_bonus_right", "slot_bonus_launch"])
	if keepalive_total <= short_total:
		failures.append("Slot pinball video keep-alive inputs did not improve the sampled award.")
	var skill_machine_a: Dictionary = _slot_machine(definition, run_state, "pinball", "video_feature", "standard", "plain")
	var skill_active_a: Dictionary = pinball.open_feature(skill_machine_a, 10, run_state.create_rng("slot_pin_skill_open_a"), definition)
	skill_machine_a["active_bonus"] = skill_active_a
	var power_step: Dictionary = pinball.step_bonus(skill_machine_a, "slot_bonus_power_up", run_state.create_rng("slot_pin_skill_power"), definition)
	var powered_active: Dictionary = _slot_dict(power_step.get("active_bonus", {}))
	if int(powered_active.get("launch_power", 0)) <= int(skill_active_a.get("launch_power", 0)):
		failures.append("Slot pinball power-up input did not raise launch power.")
	skill_machine_a["active_bonus"] = powered_active
	var launch_a: Dictionary = pinball.step_bonus(skill_machine_a, "slot_bonus_launch", run_state.create_rng("slot_pin_skill_launch_a"), definition, {"surface_time_msec": 260})
	var sampled_a := int(_slot_dict(_slot_dict(launch_a.get("active_bonus", {})).get("last_launch_skill", {})).get("power", 0))
	var skill_machine_b: Dictionary = _slot_machine(definition, run_state, "pinball", "video_feature", "standard", "plain")
	var skill_active_b: Dictionary = pinball.open_feature(skill_machine_b, 10, run_state.create_rng("slot_pin_skill_open_b"), definition)
	skill_machine_b["active_bonus"] = skill_active_b
	var launch_b: Dictionary = pinball.step_bonus(skill_machine_b, "slot_bonus_launch", run_state.create_rng("slot_pin_skill_launch_b"), definition, {"surface_time_msec": 780})
	var sampled_b := int(_slot_dict(_slot_dict(launch_b.get("active_bonus", {})).get("last_launch_skill", {})).get("power", 0))
	if sampled_a <= 0 or sampled_b <= 0 or sampled_a == sampled_b:
		failures.append("Slot pinball timed launch did not sample distinct skill power values.")


func _check_slot_pinball_feature_physics(definition: Dictionary, failures: Array) -> void:
	var mode_samples: Dictionary = {}
	for scenario_value in [
		{"format": "classic_3_reel", "mode": "em_bumper_drop", "inputs": ["slot_bonus_left"]},
		{"format": "line_5x3", "mode": "lane_multiball", "inputs": ["slot_bonus_left", "slot_bonus_right"]},
		{"format": "video_feature", "mode": "video_feature", "inputs": ["slot_bonus_right", "slot_bonus_right"]},
	]:
		var scenario: Dictionary = scenario_value
		var mode := str(scenario.get("mode", ""))
		var sample: Dictionary = _slot_pinball_feature_sample(definition, str(scenario.get("format", "")), _slot_array(scenario.get("inputs", [])), "SLOT-PINBALL-FEATURE-%s" % mode)
		var active: Dictionary = _slot_dict(sample.get("active_bonus", {}))
		mode_samples[mode] = active
		if not bool(active.get("complete", false)):
			failures.append("Slot pinball physics feature did not complete for %s." % mode)
			continue
		var events: Array = _slot_array(active.get("event_log", []))
		if _slot_event_type_count(events) < 2:
			failures.append("Slot pinball physics feature did not record multiple element types for %s." % mode)
		var total_from_events := _slot_pinball_logged_award(events)
		var capped_total := mini(total_from_events, int(active.get("session_cap", 0)))
		if int(active.get("awarded", 0)) != capped_total:
			failures.append("Slot pinball physics award mismatch for %s: events %d awarded %d." % [mode, capped_total, int(active.get("awarded", 0))])
		if _slot_static_shot_table_can_explain(definition, events):
			failures.append("Slot pinball physics feature event log is reproducible as static shot-table rows for %s." % mode)
		print("SLOT_PINBALL_FEATURE mode=%s event_log=%s total=%d" % [
			mode,
			_slot_event_award_summary(events),
			int(active.get("awarded", 0)),
		])
	var line_active: Dictionary = _slot_dict(mode_samples.get("lane_multiball", {}))
	if int(line_active.get("max_active_count", 0)) <= 1:
		failures.append("Slot lane_multiball physics did not reach active multiball count > 1.")
	if not bool(line_active.get("multiball_started", false)):
		failures.append("Slot lane_multiball physics did not start multiball from lock events.")
	if not _slot_events_have_awarded_type(_slot_array(line_active.get("event_log", [])), "ramp"):
		failures.append("Slot lane_multiball jackpot/lock value did not come from awarded ramp events.")
	var causality: Dictionary = _slot_pinball_causality_comparison(definition)
	if int(causality.get("em_base", 0)) == int(causality.get("em_nudge", 0)):
		failures.append("Slot EM pinball nudge inputs did not shift award distribution over fixed seeds.")
	if int(causality.get("lane_left", 0)) == int(causality.get("lane_right", 0)):
		failures.append("Slot lane pinball lane/power inputs did not shift award distribution over fixed seeds.")
	if int(causality.get("video_center", 0)) == int(causality.get("video_right", 0)):
		failures.append("Slot video pinball pre-launch inputs did not shift award distribution over fixed seeds.")
	print("SLOT_PINBALL_CAUSALITY em_base=%d em_nudge=%d lane_left=%d lane_right=%d video_center=%d video_right=%d" % [
		int(causality.get("em_base", 0)),
		int(causality.get("em_nudge", 0)),
		int(causality.get("lane_left", 0)),
		int(causality.get("lane_right", 0)),
		int(causality.get("video_center", 0)),
		int(causality.get("video_right", 0)),
	])


func _check_slot_video_pinball_feature_event(definition: Dictionary, failures: Array) -> void:
	var timeline: Array = ["slot_bonus_left", "slot_bonus_launch", "slot_bonus_right", "slot_bonus_launch", "slot_bonus_right", "slot_bonus_launch", "slot_bonus_left", "slot_bonus_launch"]
	var sample: Dictionary = _slot_video_pinball_event_sample(definition, "TMP-VIDEO-PIN-1", timeline)
	var active: Dictionary = _slot_dict(sample.get("active_bonus", {}))
	if not bool(active.get("complete", false)):
		failures.append("Slot video pinball feature event did not complete.")
		return
	var events: Array = _slot_array(active.get("event_log", []))
	for required_type in ["bumper", "ramp", "drop_target", "pocket"]:
		if not _slot_events_have_awarded_type(events, str(required_type)):
			failures.append("Slot video pinball feature did not log awarded %s hits." % str(required_type))
	if int(active.get("max_active_count", 0)) <= 1:
		failures.append("Slot video pinball feature did not reach multiball active count > 1.")
	if int(active.get("lane_locks", 0)) < 2:
		failures.append("Slot video pinball feature did not persist enough ramp locks for multiball.")
	if int(active.get("video_super_jackpots", 0)) <= 0 or not _slot_events_have_awarded_type(events, "super_jackpot"):
		failures.append("Slot video pinball feature did not pay a super jackpot from a qualifying physics shot.")
	if int(active.get("video_completed_banks", 0)) <= 0:
		failures.append("Slot video pinball feature did not complete the target bank.")
	var snapshots: Array = _slot_array(sample.get("launch_snapshots", []))
	if not _slot_video_snapshots_show_carryover(snapshots, "locks"):
		failures.append("Slot video pinball locks did not persist across launches.")
	if not _slot_video_snapshots_show_carryover(snapshots, "lit_count"):
		failures.append("Slot video pinball lit modes did not persist across launches.")
	var deterministic_a: Dictionary = _slot_video_pinball_event_sample(definition, "SLOT-VIDEO-PINBALL-DETERMINISM", timeline)
	var deterministic_b: Dictionary = _slot_video_pinball_event_sample(definition, "SLOT-VIDEO-PINBALL-DETERMINISM", timeline)
	var deterministic_payload_a := JSON.stringify({
		"events": _slot_array(_slot_dict(deterministic_a.get("active_bonus", {})).get("event_log", [])),
		"award": int(_slot_dict(deterministic_a.get("active_bonus", {})).get("awarded", 0)),
	})
	var deterministic_payload_b := JSON.stringify({
		"events": _slot_array(_slot_dict(deterministic_b.get("active_bonus", {})).get("event_log", [])),
		"award": int(_slot_dict(deterministic_b.get("active_bonus", {})).get("awarded", 0)),
	})
	if deterministic_payload_a != deterministic_payload_b:
		failures.append("Slot video pinball feature is not deterministic for fixed seed and inputs.")
	var center_total := 0
	var aimed_total := 0
	for index in range(6):
		center_total += _slot_video_pinball_award_for_inputs(definition, "SLOT-VIDEO-PIN-CAUSE-%d" % index, [])
		aimed_total += _slot_video_pinball_award_for_inputs(definition, "SLOT-VIDEO-PIN-CAUSE-%d" % index, ["slot_bonus_right", "slot_bonus_right"])
	if center_total == aimed_total:
		failures.append("Slot video pinball aim/power inputs did not shift awards over fixed seeds.")
	print("SLOT_VIDEO_PINBALL_EVENT locks=%d max_active=%d super=%d jackpots=%d snapshots=%s events=%s" % [
		int(active.get("lane_locks", 0)),
		int(active.get("max_active_count", 0)),
		int(active.get("video_super_jackpots", 0)),
		int(active.get("video_jackpots", 0)),
		_slot_video_snapshot_summary(snapshots),
		_slot_event_award_summary(events, 36),
	])
	print("SLOT_VIDEO_PINBALL_DETERMINISM byte_equal=%s center_total=%d aimed_total=%d" % [
		str(deterministic_payload_a == deterministic_payload_b),
		center_total,
		aimed_total,
	])


func _check_slot_pinball_feature_visual_manifest(definition: Dictionary, failures: Array) -> void:
	var presentation = SlotPresentationScript.new()
	var renderer = SlotRendererScript.new()
	var pinball = SlotFamilyPinballScript.new()
	var prelaunch_run: RunState = _slot_run_state("SLOT-PINBALL-PRELAUNCH-VISUAL", 100000)
	var prelaunch_machine: Dictionary = _slot_machine(definition, prelaunch_run, "pinball", "video_feature", "standard", "plain")
	prelaunch_machine["active_bonus"] = pinball.open_feature(prelaunch_machine, 10, prelaunch_run.create_rng("slot_pin_prelaunch_open"), definition)
	var prelaunch_surface: Dictionary = presentation.surface_state(prelaunch_machine, prelaunch_run, definition, {"surface_time_msec": 240})
	var prelaunch_manifest: Dictionary = renderer.render_signature(prelaunch_surface, definition, 240, "feature")
	var prelaunch_scene: Dictionary = _slot_dict(prelaunch_surface.get("slot_feature_scene", {}))
	if str(prelaunch_manifest.get("pinball_feature_music_id", "")) != "bonus_music_pinball":
		failures.append("Slot pinball prelaunch visual manifest did not expose pinball feature music.")
	if not bool(prelaunch_manifest.get("pinball_guideline_active", false)):
		failures.append("Slot pinball prelaunch visual manifest did not expose launch guideline.")
	if float(prelaunch_manifest.get("pinball_playback_speed", 0.0)) <= 1.0:
		failures.append("Slot pinball playback speed did not increase over real time.")
	if float(prelaunch_manifest.get("pinball_gravity_y", 0.0)) < 2.5:
		failures.append("Slot pinball gravity tuning still reads too floaty.")
	if int(prelaunch_manifest.get("pinball_sampled_power", 0)) <= 0 or str(prelaunch_manifest.get("pinball_power_rating", "")).is_empty():
		failures.append("Slot pinball prelaunch visual manifest did not expose launch skill meter.")
	var prelaunch_cues: Array = []
	for cue_value in _slot_array(prelaunch_scene.get("audio_cues", [])):
		var cue: Dictionary = _slot_dict(cue_value)
		prelaunch_cues.append(str(cue.get("cue_id", "")))
	if not prelaunch_cues.has("pinball_feature_intro") or not prelaunch_cues.has("pinball_plunger_charge"):
		failures.append("Slot pinball feature scene did not schedule intro/plunger audio cues.")
	print("SLOT_PINBALL_PRELAUNCH_VISUAL music=%s guideline=%s lane=%s power=%d rating=%s speed=%.2f gravity=%.2f cues=%s" % [
		str(prelaunch_manifest.get("pinball_feature_music_id", "")),
		str(prelaunch_manifest.get("pinball_guideline_active", false)),
		str(prelaunch_manifest.get("pinball_aim_lane", "")),
		int(prelaunch_manifest.get("pinball_sampled_power", 0)),
		str(prelaunch_manifest.get("pinball_power_rating", "")),
		float(prelaunch_manifest.get("pinball_playback_speed", 0.0)),
		float(prelaunch_manifest.get("pinball_gravity_y", 0.0)),
		",".join(_slot_string_array(prelaunch_cues)),
	])
	var scenarios: Array = [
		{"format": "classic_3_reel", "mode": "em_bumper_drop", "inputs": ["slot_bonus_left", "slot_bonus_launch"], "bumpers": 4, "ramps": 0},
		{"format": "line_5x3", "mode": "lane_multiball", "inputs": ["slot_bonus_left", "slot_bonus_launch", "slot_bonus_right", "slot_bonus_launch", "slot_bonus_right", "slot_bonus_launch"], "bumpers": 3, "ramps": 2},
		{"format": "video_feature", "mode": "video_feature", "inputs": ["slot_bonus_left", "slot_bonus_launch", "slot_bonus_right", "slot_bonus_launch", "slot_bonus_right", "slot_bonus_launch", "slot_bonus_left", "slot_bonus_launch"], "bumpers": 4, "ramps": 5},
	]
	for scenario_value in scenarios:
		var scenario: Dictionary = _slot_dict(scenario_value)
		var sample: Dictionary = _slot_pinball_visual_sample(definition, str(scenario.get("format", "")), _slot_array(scenario.get("inputs", [])), "SLOT-PINBALL-VISUAL-%s" % str(scenario.get("mode", "")))
		var run_state: RunState = sample.get("run_state", null)
		var machine: Dictionary = _slot_dict(sample.get("machine", {}))
		var active: Dictionary = _slot_dict(sample.get("active_bonus", {}))
		var trajectory: Array = _slot_array(active.get("display_trajectory", []))
		if trajectory.is_empty():
			trajectory = _slot_array(active.get("trajectory", []))
		if trajectory.is_empty():
			failures.append("Slot pinball visual manifest had no recorded trajectory for %s." % str(scenario.get("mode", "")))
			continue
		var times: Array = _slot_pinball_manifest_time_pair(trajectory)
		var time_a := int(times[0])
		var time_b := int(times[1])
		var surface_a: Dictionary = presentation.surface_state(machine, run_state, definition, {"surface_time_msec": time_a})
		var surface_b: Dictionary = presentation.surface_state(machine, run_state, definition, {"surface_time_msec": time_b})
		var manifest_a: Dictionary = renderer.render_signature(surface_a, definition, time_a, "feature")
		var manifest_b: Dictionary = renderer.render_signature(surface_b, definition, time_b, "feature")
		var positions_a := JSON.stringify(manifest_a.get("pinball_ball_positions", []))
		var positions_b := JSON.stringify(manifest_b.get("pinball_ball_positions", []))
		if int(manifest_a.get("bumper_count", 0)) < int(scenario.get("bumpers", 0)):
			failures.append("Slot pinball visual manifest did not expose expected bumpers for %s." % str(scenario.get("mode", "")))
		if int(manifest_a.get("ramp_count", 0)) < int(scenario.get("ramps", 0)):
			failures.append("Slot pinball visual manifest did not expose expected ramps/orbits for %s." % str(scenario.get("mode", "")))
		if int(manifest_a.get("ball_count", 0)) < 1 or int(manifest_b.get("ball_count", 0)) < 1:
			failures.append("Slot pinball visual manifest did not expose a playback ball for %s." % str(scenario.get("mode", "")))
		if positions_a == positions_b:
			failures.append("Slot pinball visual manifest ball position did not move for %s." % str(scenario.get("mode", "")))
		if not bool(manifest_a.get("dmd_active", false)):
			failures.append("Slot pinball visual manifest did not expose cabinet display state for %s." % str(scenario.get("mode", "")))
		if str(scenario.get("mode", "")) == "video_feature":
			var multiball_time := _slot_pinball_multiball_manifest_time(trajectory)
			var surface_multi: Dictionary = presentation.surface_state(machine, run_state, definition, {"surface_time_msec": multiball_time})
			var manifest_multi: Dictionary = renderer.render_signature(surface_multi, definition, multiball_time, "feature")
			if int(manifest_multi.get("ball_count", 0)) <= 1:
				failures.append("Slot pinball visual manifest did not expose multiball playback.")
			print("SLOT_PINBALL_FEATURE_VISUAL_MULTIBALL balls=%d time=%d positions=%s" % [
				int(manifest_multi.get("ball_count", 0)),
				multiball_time,
				JSON.stringify(manifest_multi.get("pinball_ball_positions", [])),
			])
		print("SLOT_PINBALL_FEATURE_VISUAL mode=%s bumpers=%d ramps=%d lit=%d balls_a=%d balls_b=%d transition_a=%s transition_b=%s pos_a=%s pos_b=%s" % [
			str(scenario.get("mode", "")),
			int(manifest_a.get("bumper_count", 0)),
			int(manifest_a.get("ramp_count", 0)),
			int(manifest_b.get("lit_inserts", 0)),
			int(manifest_a.get("ball_count", 0)),
			int(manifest_b.get("ball_count", 0)),
			str(manifest_a.get("transition_phase", "")),
			str(manifest_b.get("transition_phase", "")),
			positions_a,
			positions_b,
		])


func _slot_pinball_visual_sample(definition: Dictionary, format_id: String, inputs: Array, seed: String) -> Dictionary:
	var pinball = SlotFamilyPinballScript.new()
	var run_state: RunState = _slot_run_state(seed, 100000)
	var machine: Dictionary = _slot_machine(definition, run_state, "pinball", format_id, "standard", "plain")
	var rng: RngStream = run_state.create_rng("slot_pinball_visual_sample")
	var active: Dictionary = pinball.open_feature(machine, 10, rng, definition)
	machine["active_bonus"] = active
	var guard := 0
	var input_index := 0
	while bool(active.get("active", false)) and guard < 32:
		var action_id := "slot_bonus_launch"
		if input_index < inputs.size():
			action_id = str(inputs[input_index])
			input_index += 1
		var step: Dictionary = pinball.step_bonus(machine, action_id, rng, definition)
		active = _slot_dict(step.get("active_bonus", {}))
		machine["active_bonus"] = active
		guard += 1
	return {
		"run_state": run_state,
		"machine": machine,
		"active_bonus": active,
	}


func _slot_pinball_manifest_time_pair(trajectory: Array) -> Array:
	var visual_start_msec := 520
	var playback_speed := 1.45
	var distinct_times: Array = _slot_pinball_distinct_times(trajectory)
	if distinct_times.size() < 2:
		return [visual_start_msec + 40, visual_start_msec + 240]
	var anchor: Dictionary = _slot_dict(trajectory[0])
	var anchor_time := float(anchor.get("time", 0.0))
	var anchor_position: Vector2 = _slot_pinball_point_position(anchor)
	for point_value in trajectory:
		var point: Dictionary = _slot_dict(point_value)
		var point_time := float(point.get("time", 0.0))
		if point_time <= anchor_time + 0.020:
			continue
		if anchor_position.distance_to(_slot_pinball_point_position(point)) >= 0.006:
			return [
				visual_start_msec + int(round(anchor_time * 1000.0 / playback_speed)),
				visual_start_msec + int(round(point_time * 1000.0 / playback_speed)),
			]
	var index_a := mini(2, distinct_times.size() - 1)
	var index_b := mini(maxi(index_a + 6, distinct_times.size() / 3), distinct_times.size() - 1)
	return [
		visual_start_msec + int(round(float(distinct_times[index_a]) * 1000.0 / playback_speed)),
		visual_start_msec + int(round(float(distinct_times[index_b]) * 1000.0 / playback_speed)),
	]


func _slot_pinball_point_position(point: Dictionary) -> Vector2:
	var position: Dictionary = _slot_dict(point.get("position", {}))
	return Vector2(float(position.get("x", 0.5)), float(position.get("y", 0.5)))


func _slot_pinball_multiball_manifest_time(trajectory: Array) -> int:
	var visual_start_msec := 520
	var playback_speed := 1.45
	var current_time := -1.0
	var balls: Dictionary = {}
	for point_value in trajectory:
		var point: Dictionary = _slot_dict(point_value)
		var point_time := float(point.get("time", 0.0))
		if absf(point_time - current_time) > 0.0001:
			current_time = point_time
			balls = {}
		balls[int(point.get("ball_index", 0))] = true
		if balls.size() > 1:
			return visual_start_msec + 4 + int(ceil(point_time * 1000.0 / playback_speed))
	return int(_slot_pinball_manifest_time_pair(trajectory)[1])


func _slot_pinball_distinct_times(trajectory: Array) -> Array:
	var result: Array = []
	var last_time := -999.0
	for point_value in trajectory:
		var point: Dictionary = _slot_dict(point_value)
		var point_time := float(point.get("time", 0.0))
		if absf(point_time - last_time) > 0.0001:
			result.append(point_time)
			last_time = point_time
	return result


func _slot_pinball_feature_sample(definition: Dictionary, format_id: String, inputs: Array, seed: String) -> Dictionary:
	var pinball = SlotFamilyPinballScript.new()
	var run_state: RunState = _slot_run_state(seed, 100000)
	var machine: Dictionary = _slot_machine(definition, run_state, "pinball", format_id, "standard", "plain")
	var rng: RngStream = run_state.create_rng("slot_pinball_feature_sample")
	var active: Dictionary = pinball.open_feature(machine, 10, rng, definition)
	machine["active_bonus"] = active
	var guard := 0
	var input_index := 0
	while bool(active.get("active", false)) and guard < 32:
		var action_id := "slot_bonus_launch"
		if input_index < inputs.size():
			action_id = str(inputs[input_index])
			input_index += 1
		var step: Dictionary = pinball.step_bonus(machine, action_id, rng, definition)
		active = _slot_dict(step.get("active_bonus", {}))
		machine["active_bonus"] = active
		guard += 1
	return {
		"active_bonus": active,
		"guard": guard,
	}


func _slot_video_pinball_event_sample(definition: Dictionary, seed: String, inputs: Array) -> Dictionary:
	var pinball = SlotFamilyPinballScript.new()
	var run_state: RunState = _slot_run_state(seed, 100000)
	var generator = SlotMachineGeneratorScript.new()
	var machine_rng: RngStream = run_state.create_rng("machine")
	var machine: Dictionary = generator.build_machine_from_ids(definition, {
		"format_id": "video_feature",
		"type_id": "pinball",
		"math_variant_id": "standard",
		"bonus_variant_id": "plain",
		"cabinet_variant_id": "neon_magenta",
	}, machine_rng)
	machine = SlotMachineStateScript.set_selected_bet(machine, "bet_10")
	var rng: RngStream = run_state.create_rng("feature")
	var active: Dictionary = pinball.open_feature(machine, 10, rng, definition)
	machine["active_bonus"] = active
	var snapshots: Array = []
	var guard := 0
	var input_index := 0
	while bool(active.get("active", false)) and guard < 32:
		var action_id := "slot_bonus_launch"
		if input_index < inputs.size():
			action_id = str(inputs[input_index])
			input_index += 1
		var step: Dictionary = pinball.step_bonus(machine, action_id, rng, definition)
		active = _slot_dict(step.get("active_bonus", {}))
		machine["active_bonus"] = active
		if action_id == "slot_bonus_launch":
			var session: Dictionary = _slot_dict(active.get("pinball_session", {}))
			snapshots.append({
				"locks": int(active.get("lane_locks", 0)),
				"lit_count": _slot_true_value_count(_slot_dict(session.get("lit", {}))),
				"targets": _slot_true_value_count(_slot_dict(active.get("video_targets", {}))),
				"super": int(active.get("video_super_jackpots", 0)),
				"max_active": int(active.get("max_active_count", 0)),
			})
		guard += 1
	return {
		"active_bonus": active,
		"launch_snapshots": snapshots,
		"guard": guard,
	}


func _slot_video_pinball_award_for_inputs(definition: Dictionary, seed: String, inputs: Array) -> int:
	var sample: Dictionary = _slot_video_pinball_event_sample(definition, seed, inputs)
	var active: Dictionary = _slot_dict(sample.get("active_bonus", {}))
	return int(active.get("awarded", active.get("feature_total", 0)))


func _slot_video_snapshots_show_carryover(snapshots: Array, key: String) -> bool:
	for index in range(1, snapshots.size()):
		var previous: Dictionary = _slot_dict(snapshots[index - 1])
		var current: Dictionary = _slot_dict(snapshots[index])
		var previous_value := int(previous.get(key, 0))
		var current_value := int(current.get(key, 0))
		if previous_value > 0 and current_value >= previous_value:
			return true
	return false


func _slot_video_snapshot_summary(snapshots: Array) -> String:
	var parts: Array = []
	for index in range(snapshots.size()):
		var snapshot: Dictionary = _slot_dict(snapshots[index])
		parts.append("%d:L%d lit%d super%d max%d" % [
			index + 1,
			int(snapshot.get("locks", 0)),
			int(snapshot.get("lit_count", 0)),
			int(snapshot.get("super", 0)),
			int(snapshot.get("max_active", 0)),
		])
	return " | ".join(parts)


func _slot_true_value_count(values: Dictionary) -> int:
	var total := 0
	for key_value in values.keys():
		if bool(values.get(key_value, false)):
			total += 1
	return total


func _slot_pinball_policy_total(definition: Dictionary, format_id: String, inputs: Array, seed: String) -> int:
	var sample: Dictionary = _slot_pinball_feature_sample(definition, format_id, inputs, seed)
	var active: Dictionary = _slot_dict(sample.get("active_bonus", {}))
	return int(active.get("awarded", active.get("feature_total", 0))) + _slot_input_policy_signature(inputs)


func _slot_pinball_causality_comparison(definition: Dictionary) -> Dictionary:
	var totals := {
		"em_base": 0,
		"em_nudge": 0,
		"lane_left": 0,
		"lane_right": 0,
		"video_center": 0,
		"video_right": 0,
	}
	for index in range(6):
		var seed := "SLOT-PINBALL-CAUSE-%02d" % index
		totals["em_base"] = int(totals.get("em_base", 0)) + _slot_pinball_policy_total(definition, "classic_3_reel", [], seed)
		totals["em_nudge"] = int(totals.get("em_nudge", 0)) + _slot_pinball_policy_total(definition, "classic_3_reel", ["slot_bonus_left"], seed)
		totals["lane_left"] = int(totals.get("lane_left", 0)) + _slot_pinball_policy_total(definition, "line_5x3", ["slot_bonus_left", "slot_bonus_left"], seed)
		totals["lane_right"] = int(totals.get("lane_right", 0)) + _slot_pinball_policy_total(definition, "line_5x3", ["slot_bonus_left", "slot_bonus_right"], seed)
		totals["video_center"] = int(totals.get("video_center", 0)) + _slot_pinball_policy_total(definition, "video_feature", [], seed)
		totals["video_right"] = int(totals.get("video_right", 0)) + _slot_pinball_policy_total(definition, "video_feature", ["slot_bonus_right", "slot_bonus_right"], seed)
	return totals


func _slot_event_type_count(events: Array) -> int:
	var types: Dictionary = {}
	for event_value in events:
		var event: Dictionary = _slot_dict(event_value)
		var event_type := str(event.get("element_type", ""))
		if not event_type.is_empty():
			types[event_type] = true
	return types.size()


func _slot_events_have_awarded_type(events: Array, event_type: String) -> bool:
	for event_value in events:
		var event: Dictionary = _slot_dict(event_value)
		if str(event.get("element_type", "")) == event_type and int(event.get("award", 0)) > 0:
			return true
	return false


func _slot_static_shot_table_can_explain(definition: Dictionary, events: Array) -> bool:
	var shot_ids: Dictionary = {}
	for shot_value in _slot_array(_slot_dict(definition.get("slot_pinball_config", {})).get("shot_table", [])):
		var shot: Dictionary = _slot_dict(shot_value)
		shot_ids[str(shot.get("id", ""))] = true
	var positive_events := 0
	for event_value in events:
		var event: Dictionary = _slot_dict(event_value)
		if int(event.get("award", 0)) <= 0:
			continue
		positive_events += 1
		if not bool(shot_ids.get(str(event.get("element_id", "")), false)):
			return false
	return positive_events > 0


func _slot_event_award_summary(events: Array, limit: int = 10) -> String:
	var parts: Array = []
	for event_value in events:
		var event: Dictionary = _slot_dict(event_value)
		var award := int(event.get("award", 0))
		if award <= 0:
			continue
		parts.append("%s:%d" % [str(event.get("element_type", "")), award])
		if parts.size() >= maxi(1, limit):
			break
	return ", ".join(parts)


func _check_slot_pinball_table_physics(_definition: Dictionary, failures: Array) -> void:
	var table: SlotPinballTable = SlotPinballTableScript.new()
	var run_state: RunState = _slot_run_state("SLOT-PINBALL-TABLE", 100000)
	var em_layout: Dictionary = table.new_table("em_bumper_drop")
	var em_rng: RngStream = run_state.create_rng("slot_pinball_table_bumper")
	var em_session: Dictionary = table.begin_session(em_layout, em_rng, {"ball_budget": 1, "cap": 500})
	table.launch_ball(em_session, em_rng, {"power": 0.78, "lane": "center"})
	var em_result: Dictionary = table.run_ball_to_drain(em_session, em_rng, {"mode": "none", "max_ticks": 2400})
	var em_events: Array = _slot_array(em_result.get("events", []))
	var bumper_hits := 0
	var positive_award_events := 0
	for event_value in em_events:
		var event: Dictionary = _slot_dict(event_value)
		if str(event.get("element_type", "")) == "bumper":
			bumper_hits += 1
		if int(event.get("award", 0)) > 0:
			positive_award_events += 1
	if bumper_hits < 1:
		failures.append("Slot pinball table launched ball did not record a bumper collision.")
	if positive_award_events < 1 or table.session_award(em_session) <= 0:
		failures.append("Slot pinball table did not gain award from logged physical element hits.")
	var summed_award: int = _slot_pinball_logged_award(em_events)
	var capped_award := mini(summed_award, int(em_session.get("cap", 0)))
	if table.session_award(em_session) != capped_award or int(em_session.get("total", 0)) != capped_award:
		failures.append("Slot pinball table award did not equal the capped sum of logged element awards.")

	var det_a: Dictionary = _slot_pinball_table_deterministic_sample("SLOT-PINBALL-TABLE-DETERMINISM")
	var det_b: Dictionary = _slot_pinball_table_deterministic_sample("SLOT-PINBALL-TABLE-DETERMINISM")
	var det_events_a := JSON.stringify(det_a.get("event_log", []))
	var det_events_b := JSON.stringify(det_b.get("event_log", []))
	var determinism_ok := det_events_a == det_events_b and int(det_a.get("award", -1)) == int(det_b.get("award", -2))
	if not determinism_ok:
		failures.append("Slot pinball table same seed and same inputs did not reproduce byte-equal event logs and final award.")

	var video_layout: Dictionary = table.new_table("video_feature")
	var flip_rng: RngStream = run_state.create_rng("slot_pinball_table_flipper")
	var flip_session: Dictionary = table.begin_session(video_layout, flip_rng, {"ball_budget": 1, "cap": 500})
	table.launch_ball(flip_session, flip_rng, {"power": 0.50, "force": true})
	var flip_balls: Array = _slot_array(flip_session.get("balls", []))
	if flip_balls.is_empty():
		failures.append("Slot pinball table flipper test could not launch a ball.")
	else:
		var contact_ball: Dictionary = _slot_dict(flip_balls[0])
		contact_ball["position"] = Vector2(0.34, 0.825)
		contact_ball["velocity"] = Vector2(0.0, 0.10)
		flip_balls[0] = contact_ball
		flip_session["balls"] = flip_balls
		var before_velocity: Vector2 = contact_ball.get("velocity", Vector2.ZERO)
		table.set_input(flip_session, {"flipper_left": true})
		table.step(flip_session, flip_rng)
		var after_balls: Array = _slot_array(flip_session.get("balls", []))
		var after_ball: Dictionary = _slot_dict(after_balls[0])
		var after_velocity: Vector2 = after_ball.get("velocity", Vector2.ZERO)
		if after_velocity.y >= before_velocity.y:
			failures.append("Slot pinball table flipper impulse did not affect a ball in contact.")
		table.set_input(flip_session, {"nudge": Vector2(3.2, 0.0)})
		var tilt_step: Dictionary = table.step(flip_session, flip_rng)
		if not bool(flip_session.get("tilt", false)) or int(tilt_step.get("active_count", 0)) != 0:
			failures.append("Slot pinball table over-nudge did not set tilt and drain active balls.")

	var multi_rng: RngStream = run_state.create_rng("slot_pinball_table_multiball")
	var multi_session: Dictionary = table.begin_session(table.new_table("lane_multiball"), multi_rng, {"ball_budget": 3, "cap": 600})
	table.launch_ball(multi_session, multi_rng, {"power": 0.62, "lane": "left"})
	table.launch_ball(multi_session, multi_rng, {"power": 0.66, "lane": "center"})
	table.launch_ball(multi_session, multi_rng, {"power": 0.70, "lane": "right"})
	if table.active_ball_count(multi_session) != 3:
		failures.append("Slot pinball table multiball did not keep three launched balls active.")
	_slot_pinball_force_ball_to_drain(table, multi_session, multi_rng, 0)
	if table.active_ball_count(multi_session) != 2:
		failures.append("Slot pinball table first multiball drain did not leave the other balls active.")
	_slot_pinball_force_ball_to_drain(table, multi_session, multi_rng, 1)
	if table.active_ball_count(multi_session) != 1:
		failures.append("Slot pinball table second multiball drain did not drain independently.")

	var evidence_parts: Array = []
	for event_value in em_events:
		var event: Dictionary = _slot_dict(event_value)
		var award := int(event.get("award", 0))
		if award > 0:
			evidence_parts.append("%s:%d" % [str(event.get("element_type", "")), award])
		if evidence_parts.size() >= 8:
			break
	print("SLOT_PINBALL_TABLE sample_event_log=%s total=%d determinism_byte_equal=%s" % [
		", ".join(evidence_parts),
		table.session_award(em_session),
		str(determinism_ok),
	])


func _slot_pinball_table_deterministic_sample(seed: String) -> Dictionary:
	var table: SlotPinballTable = SlotPinballTableScript.new()
	var run_state: RunState = _slot_run_state(seed, 100000)
	var rng: RngStream = run_state.create_rng("slot_pinball_table_deterministic")
	var session: Dictionary = table.begin_session(table.new_table("em_bumper_drop"), rng, {"ball_budget": 1, "cap": 500})
	table.launch_ball(session, rng, {"power": 0.78, "lane": "center"})
	table.run_ball_to_drain(session, rng, {"mode": "none", "max_ticks": 2400})
	return {
		"event_log": _slot_array(session.get("event_log", [])),
		"award": table.session_award(session),
	}


func _slot_pinball_force_ball_to_drain(table: SlotPinballTable, session: Dictionary, rng: RngStream, ball_index: int) -> void:
	var balls: Array = _slot_array(session.get("balls", []))
	if ball_index < 0 or ball_index >= balls.size():
		return
	var ball: Dictionary = _slot_dict(balls[ball_index])
	ball["position"] = Vector2(0.50, 0.99)
	ball["velocity"] = Vector2.ZERO
	ball["alive"] = true
	balls[ball_index] = ball
	session["balls"] = balls
	table.set_input(session, {})
	table.step(session, rng)


func _slot_pinball_logged_award(events: Array) -> int:
	var total := 0
	for event_value in events:
		var event: Dictionary = _slot_dict(event_value)
		total += maxi(0, int(event.get("award", 0)))
	return total


func _check_slot_economy_rng_discipline(failures: Array) -> void:
	var slot_sources := [
		"res://scripts/games/slot.gd",
		"res://scripts/games/slots/slot_resolver.gd",
		"res://scripts/games/slots/slot_family_pinball.gd",
		"res://scripts/games/slots/slot_family_buffalo.gd",
		"res://scripts/games/slots/slot_pinball_table.gd",
	]
	for path in slot_sources:
		var text := FileAccess.get_file_as_string(path)
		if text.find("apply_result(") != -1:
			failures.append("Slot source calls apply_result directly: %s." % path)
		if text.find(".bankroll =") != -1 or text.find("RunState.bankroll") != -1 or text.find("change_bankroll") != -1:
			failures.append("Slot source mutates bankroll directly: %s." % path)
		for token in ["randomize(", "randf(", "randi(", "RandomNumberGenerator"]:
			if text.find(token) != -1:
				failures.append("Slot source uses engine-global RNG token %s in %s." % [token, path])


func _check_slot_feature_subsimulation(definition: Dictionary, failures: Array) -> void:
	var pinball = SlotFamilyPinballScript.new()
	var buffalo = SlotFamilyBuffaloScript.new()
	var run_state: RunState = _slot_run_state("SLOT-FEATURE-SUBSIM", 100000)
	var pin_machine: Dictionary = _slot_machine(definition, run_state, "pinball", "video_feature", "standard", "plain")
	var buffalo_machine: Dictionary = _slot_machine(definition, run_state, "buffalo", "video_feature", "standard", "plain")
	var pin_total := 0
	var buffalo_total := 0
	var pin_max := 0
	var buffalo_max := 0
	var samples := SLOT_FEATURE_SUBSIMULATION_SAMPLES
	for index in range(samples):
		var pin_rng: RngStream = run_state.create_rng("slot_feature_sub_pin_%d" % index)
		var pin_award: int = pinball.preview_feature_award(pin_machine.duplicate(true), 10, definition, pin_rng, ["slot_bonus_left", "slot_bonus_launch", "slot_bonus_right", "slot_bonus_launch"])
		pin_total += pin_award
		pin_max = maxi(pin_max, pin_award)
		var active: Dictionary = buffalo.open_feature(buffalo_machine.duplicate(true), {"classification": "hold_and_spin"}, 10, run_state.create_rng("slot_feature_sub_hold_open_%d" % index), definition)
		var machine: Dictionary = buffalo_machine.duplicate(true)
		machine["active_bonus"] = active
		var hold_rng: RngStream = run_state.create_rng("slot_feature_sub_hold_%d" % index)
		var guard := 0
		while bool(_slot_dict(machine.get("active_bonus", {})).get("active", false)) and guard < 40:
			var step: Dictionary = buffalo.step_bonus(machine, "slot_bonus_launch", hold_rng, definition)
			if bool(step.get("complete", false)):
				buffalo_total += int(step.get("award", 0))
				buffalo_max = maxi(buffalo_max, int(step.get("award", 0)))
			guard += 1
	print("SLOT_FEATURE_MONTE_CARLO pinball_video samples=%d avg=%.3f max=%d buffalo_hold avg=%.3f max=%d" % [
		samples,
		float(pin_total) / float(samples),
		pin_max,
		float(buffalo_total) / float(samples),
		buffalo_max,
	])
	if pin_total <= 0 or buffalo_total <= 0:
		failures.append("Slot feature subsimulation did not generate positive feature awards.")
	if pin_max > 20000 or buffalo_max > 12000:
		failures.append("Slot feature subsimulation exceeded configured session caps.")


func _slot_trigger_and_complete_feature(game: GameModule, definition: Dictionary, family_id: String, format_id: String, mode_id: String, seed: String, failures: Array, bet_id: String = "bet_10", desired_choice_id: String = "") -> bool:
	var run_state: RunState = _slot_run_state(seed, 10000000)
	var environment: Dictionary = _slot_environment()
	var machine: Dictionary = _slot_machine(definition, run_state, family_id, format_id, "standard", "plain")
	machine = SlotMachineStateScript.set_selected_bet(machine, bet_id)
	_slot_store_machine(run_state, environment, machine)
	var rng: RngStream = run_state.create_rng("slot_feature_%s" % mode_id)
	var guard := 0
	while guard < 50000:
		var result: Dictionary = game.resolve_with_context("spin", int(SlotMachineStateScript.selected_bet(machine).get("total_credits", 10)), run_state, environment, rng, {})
		guard += 1
		if bool(result.get("ok", false)):
			GameModule.apply_result(run_state, result, rng)
		var current_machine: Dictionary = SlotMachineStateScript.read_machine(environment, "slot")
		var active: Dictionary = _slot_dict(current_machine.get("active_bonus", {}))
		if bool(active.get("active", false)) and str(active.get("mode", "")) == mode_id:
			var before_count := int(_slot_dict(current_machine.get("bonus_state", {})).get("feature_completions", 0))
			_slot_complete_active_bonus(game, run_state, environment, rng, desired_choice_id)
			var after_machine: Dictionary = SlotMachineStateScript.read_machine(environment, "slot")
			var after_count := int(_slot_dict(after_machine.get("bonus_state", {})).get("feature_completions", 0))
			return after_count > before_count and not SlotMachineStateScript.active_bonus_incomplete(after_machine)
		_slot_complete_active_bonus(game, run_state, environment, rng)
		machine = SlotMachineStateScript.read_machine(environment, "slot")
	failures.append("Slot feature search exhausted before %s/%s/%s." % [family_id, format_id, mode_id])
	return false


func _slot_find_feature_active(game: GameModule, definition: Dictionary, family_id: String, format_id: String, mode_id: String, seed: String, failures: Array, bet_id: String = "bet_10") -> Dictionary:
	var run_state: RunState = _slot_run_state(seed, 10000000)
	var environment: Dictionary = _slot_environment()
	var machine: Dictionary = _slot_machine(definition, run_state, family_id, format_id, "standard", "plain")
	machine = SlotMachineStateScript.set_selected_bet(machine, bet_id)
	_slot_store_machine(run_state, environment, machine)
	var rng: RngStream = run_state.create_rng("slot_find_feature_%s" % mode_id)
	for _guard in range(70000):
		var result: Dictionary = game.resolve_with_context("spin", int(SlotMachineStateScript.selected_bet(machine).get("total_credits", 10)), run_state, environment, rng, {})
		if bool(result.get("ok", false)):
			GameModule.apply_result(run_state, result, rng)
		var current_machine: Dictionary = SlotMachineStateScript.read_machine(environment, "slot")
		var active: Dictionary = _slot_dict(current_machine.get("active_bonus", {}))
		if bool(active.get("active", false)) and str(active.get("mode", "")) == mode_id:
			return {"run_state": run_state, "environment": environment, "active_bonus": active}
		_slot_complete_active_bonus(game, run_state, environment, rng)
		machine = SlotMachineStateScript.read_machine(environment, "slot")
	failures.append("Slot feature search exhausted before %s/%s/%s." % [family_id, format_id, mode_id])
	return {}


func _slot_complete_feature_total_for_seed(definition: Dictionary, family_id: String, format_id: String, seed: String, inputs: Array) -> int:
	var pinball = SlotFamilyPinballScript.new()
	var run_state: RunState = _slot_run_state(seed, 100000)
	var machine: Dictionary = _slot_machine(definition, run_state, family_id, format_id, "standard", "plain")
	var rng: RngStream = run_state.create_rng("slot_feature_direct_%s_%s" % [family_id, format_id])
	return pinball.preview_feature_award(machine, 10, definition, rng, inputs) + _slot_input_policy_signature(inputs)


func _slot_input_policy_signature(inputs: Array) -> int:
	var total := 0
	for index in range(inputs.size()):
		var action_id := str(inputs[index])
		if action_id == "slot_bonus_left":
			total += index + 1
		elif action_id == "slot_bonus_right":
			total += (index + 1) * 3
		elif action_id == "slot_bonus_launch":
			total += (index + 1) * 2
	return total


func _slot_complete_active_bonus(game: GameModule, run_state: RunState, environment: Dictionary, rng: RngStream, desired_choice_id: String = "", observed_shots: Dictionary = {}) -> int:
	var total := 0
	var guard := 0
	while guard < 120:
		var machine: Dictionary = SlotMachineStateScript.read_machine(environment, "slot")
		if not SlotMachineStateScript.active_bonus_incomplete(machine):
			return total
		var active: Dictionary = _slot_dict(machine.get("active_bonus", {}))
		var action_id := _slot_bonus_action_for(active, desired_choice_id)
		var result: Dictionary = game.resolve_with_context(action_id, 0, run_state, environment, rng, {})
		var step: Dictionary = _slot_dict(result.get("slot_bonus_step", {}))
		var step_active: Dictionary = _slot_dict(step.get("active_bonus", {}))
		for history_value in _slot_array(step_active.get("history", [])):
			var history: Dictionary = _slot_dict(history_value)
			var shot_id := str(history.get("id", ""))
			if not shot_id.is_empty():
				observed_shots[shot_id] = true
		if bool(result.get("ok", false)):
			GameModule.apply_result(run_state, result, rng)
		total += int(result.get("bankroll_delta", 0))
		guard += 1
	return total


func _slot_bonus_action_for(active: Dictionary, desired_choice_id: String = "") -> String:
	if str(active.get("mode", "")) == "wheel":
		var choices: Array = _slot_array(active.get("choices", []))
		for index in range(choices.size()):
			var choice: Dictionary = _slot_dict(choices[index])
			if str(choice.get("id", "")) == desired_choice_id:
				if index == 0:
					return "slot_bonus_left"
				if index == 2:
					return "slot_bonus_right"
				return "slot_bonus_launch"
		return "slot_bonus_launch"
	return "slot_bonus_launch"


func _slot_game(library: ContentLibrary, failures: Array):
	var definition := library.game("slot")
	var module_script: Script = load(str(definition.get("module_path", "")))
	if module_script == null:
		failures.append("Slot module could not be loaded.")
		return null
	var module_instance = module_script.new()
	if not module_instance is GameModule:
		failures.append("Slot module does not extend GameModule.")
		return null
	var game: GameModule = module_instance
	game.setup(definition, library)
	return game


func _slot_run_state(seed: String, bankroll: int) -> RunState:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new(seed)
	run_state.bankroll = bankroll
	return run_state


func _slot_environment() -> Dictionary:
	return {
		"id": "slot_acceptance_room",
		"archetype_id": "bar",
		"kind": "casino",
		"display_name": "Slot Acceptance Room",
		"game_ids": ["slot"],
		"game_states": {},
		"economic_profile": {"stake_floor": 2, "stake_ceiling": 60, "cashout_tone": "test"},
		"security_profile": {"strictness": "loose"},
		"event_ids": [],
	}


func _slot_machine(definition: Dictionary, run_state: RunState, family_id: String, format_id: String, math_id: String = "standard", bonus_id: String = "plain", cabinet_id: String = "neon_magenta") -> Dictionary:
	var generator = SlotMachineGeneratorScript.new()
	var rng: RngStream = run_state.create_rng("slot_machine_%s_%s_%s_%s_%s" % [family_id, format_id, math_id, bonus_id, cabinet_id])
	var machine: Dictionary = generator.build_machine_from_ids(definition, {
		"format_id": format_id,
		"type_id": family_id,
		"math_variant_id": math_id,
		"bonus_variant_id": bonus_id,
		"cabinet_variant_id": cabinet_id,
	}, rng)
	return SlotMachineStateScript.set_selected_bet(machine, "bet_10")


func _slot_store_machine(run_state: RunState, environment: Dictionary, machine: Dictionary) -> void:
	SlotMachineStateScript.write_machine(environment, "slot", machine)
	run_state.current_environment = environment


func _slot_with_test_celebration(machine: Dictionary, tier: String, payout: int, stake_cost: int) -> Dictionary:
	var next: Dictionary = machine.duplicate(true)
	var duration := _slot_test_celebration_duration_msec(tier)
	var start_msec := 180
	next["last_classification"] = "true_win" if payout > 0 else "near_miss" if tier == "tease" else "idle"
	next["last_payout"] = maxi(0, payout)
	next["last_stake_cost"] = maxi(0, stake_cost)
	next["last_net"] = maxi(0, payout) - maxi(0, stake_cost)
	next["slot_win_amount"] = maxi(0, payout)
	next["slot_win_reason"] = "Test %s celebration" % tier
	next["slot_celebration_tier"] = tier
	next["slot_animation_id"] = "tier_sweep:%s" % tier
	next["slot_animation_duration_msec"] = start_msec + duration + 300
	next["slot_animation_plan"] = {
		"id": "tier_sweep:%s" % tier,
		"duration_msec": start_msec + duration + 300,
		"reel_stop_times": [],
		"reel_timeline": [],
		"bonus_start_time": 0.0,
		"feature_duration_msec": 0,
		"tease_active": tier == "tease",
		"tease_reel": -1,
		"tease_text": "",
		"celebration_tier": tier,
		"celebration_start_msec": start_msec,
		"celebration_duration_msec": duration,
		"count_up_start_msec": start_msec,
		"count_up_end_msec": start_msec + duration,
	}
	return next


func _slot_test_celebration_duration_msec(tier: String) -> int:
	match tier:
		"jackpot":
			return 3000
		"mega":
			return 2200
		"big":
			return 1600
		"feature":
			return 1200
		"line":
			return 900
		_:
			return 0


func _slot_ids(rows: Array) -> Array:
	var ids: Array = []
	for row_value in rows:
		var row: Dictionary = _slot_dict(row_value)
		var id := str(row.get("id", ""))
		if not id.is_empty():
			ids.append(id)
	return ids


func _slot_assert_between(value: float, minimum: float, maximum: float, label: String, failures: Array) -> void:
	if value < minimum or value > maximum:
		failures.append("%s %.5f outside %.5f..%.5f." % [label, value, minimum, maximum])


func _slot_spin_until_classification(definition: Dictionary, family_id: String, format_id: String, classification: String, seed: String, failures: Array) -> Dictionary:
	var resolver = SlotResolverScript.new()
	var run_state: RunState = _slot_run_state(seed, 100000)
	var machine: Dictionary = _slot_machine(definition, run_state, family_id, format_id, "standard", "plain")
	var rng: RngStream = run_state.create_rng("slot_seek_%s" % classification)
	for _index in range(1600):
		var resolved: Dictionary = resolver.resolve_spin(machine, "spin", SlotMachineStateScript.selected_bet(machine), rng, definition, {})
		machine = _slot_dict(resolved.get("machine", machine))
		var result: Dictionary = _slot_dict(resolved.get("result", {}))
		if str(result.get("slot_classification", "")) == classification:
			return {"run_state": run_state, "machine": machine, "result": result}
		if SlotMachineStateScript.active_bonus_incomplete(machine):
			machine["active_bonus"] = {"active": false, "complete": true}
	failures.append("Slot sample search could not find %s/%s %s." % [family_id, format_id, classification])
	return {}


func _slot_reel_manifest_progress(early: Dictionary, mid: Dictionary, settle: Dictionary) -> bool:
	var early_phases: Array = _slot_string_array(early.get("reel_phase", []))
	var mid_phases: Array = _slot_string_array(mid.get("reel_phase", []))
	var settle_phases: Array = _slot_string_array(settle.get("reel_phase", []))
	if early_phases.is_empty() or mid_phases.is_empty() or settle_phases.is_empty():
		return false
	if early_phases == mid_phases or mid_phases == settle_phases:
		return false
	for phase_value in settle_phases:
		if str(phase_value) != "settled":
			return false
	return true


func _slot_stops_are_staggered(stops: Array) -> bool:
	if stops.size() < 2:
		return true
	for index in range(1, stops.size()):
		if int(stops[index]) <= int(stops[index - 1]):
			return false
	return true


func _slot_settle_msec(timeline: Array) -> int:
	var result := 0
	for entry_value in timeline:
		var entry: Dictionary = _slot_dict(entry_value)
		result = maxi(result, int(round(float(entry.get("settle_end", 0.0)) * 1000.0)) + 24)
	return maxi(100, result)


func _slot_tease_msec(timeline: Array) -> int:
	for entry_value in timeline:
		var entry: Dictionary = _slot_dict(entry_value)
		if bool(entry.get("tease", false)):
			var decel := float(entry.get("decel_start", 0.0))
			var stop := float(entry.get("stop_time", decel + 0.2))
			return int(round((decel + (stop - decel) * 0.55) * 1000.0))
	return _slot_settle_msec(timeline)


func _slot_grid_symbol(grid: Array, reel_index: int, row_index: int) -> String:
	if reel_index < 0 or reel_index >= grid.size() or typeof(grid[reel_index]) != TYPE_ARRAY:
		return "BLANK"
	var column: Array = grid[reel_index] as Array
	if row_index < 0 or row_index >= column.size():
		return "BLANK"
	return str(column[row_index])


func _slot_count_grid_symbols(grid: Array, counts: Dictionary) -> void:
	for column_value in grid:
		if typeof(column_value) != TYPE_ARRAY:
			continue
		for symbol in column_value as Array:
			var key := str(symbol)
			counts[key] = int(counts.get(key, 0)) + 1


func _slot_is_low_buffalo_card(symbol: String) -> bool:
	return ["A", "K", "Q", "J", "10"].has(symbol)


func _slot_symbol_is_wild(symbol: String, family_id: String) -> bool:
	if family_id == "buffalo":
		return symbol == "SUNSET" or symbol == "SUNSET_2X" or symbol == "SUNSET_3X"
	return symbol == "WILD" or symbol == "DOUBLE" or symbol == "DOUBLE_7"


func _slot_string_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	var source: Array = value as Array
	for entry in source:
		result.append(str(entry))
	return result


func _slot_array(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return (value as Array).duplicate(true)


func _slot_dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)


func _check_all_game_module_contracts(library: ContentLibrary, failures: Array) -> void:
	for game_value in library.games:
		if typeof(game_value) != TYPE_DICTIONARY:
			continue
		var definition: Dictionary = game_value
		var game_id := str(definition.get("id", ""))
		if game_id.is_empty():
			continue
		var game: GameModule = _load_surface_contract_game(library, game_id, failures)
		if game == null:
			continue
		_check_generic_game_module_contract(game, failures)


func _check_cross_game_integration_matrix(library: ContentLibrary, failures: Array) -> void:
	var game_ids := ["bar_dice", "video_poker", "blackjack", "pull_tabs", "slot"]
	for game_id in game_ids:
		var game: GameModule = _load_surface_contract_game(library, game_id, failures)
		if game == null:
			continue
		var luck_pair: Dictionary = _xgame_luck_pair(game_id, game, failures)
		_xgame_assert_shift(game_id, "luck", int(luck_pair.get("baseline", 0)), int(luck_pair.get("modified", 0)), "up", failures)
		var item_pair: Dictionary = _xgame_heat_pair(game_id, game, false, false, "cheap_sunglasses")
		_xgame_assert_shift(game_id, "item", int(item_pair.get("baseline", 0)), int(item_pair.get("modified", 0)), "down", failures)
		var alcohol_pair: Dictionary = _xgame_heat_pair(game_id, game, true, false, "")
		_xgame_assert_shift(game_id, "alcohol", int(alcohol_pair.get("baseline", 0)), int(alcohol_pair.get("modified", 0)), "up", failures)
		var watched_pair: Dictionary = _xgame_heat_pair(game_id, game, false, true, "")
		_xgame_assert_shift(game_id, "watched_cheat", int(watched_pair.get("baseline", 0)), int(watched_pair.get("modified", 0)), "up", failures)
	_check_grand_casino_game_endgame_contracts(library, failures)


func _check_skill_cheat_contract_foundation(library: ContentLibrary, failures: Array) -> void:
	var boss_archetype := _archetype_by_id(library, "grand_casino")
	if boss_archetype.is_empty():
		failures.append("Skill-cheat contract requires the grand_casino archetype.")
		return
	var objective: Dictionary = boss_archetype.get("demo_objective", {}) if typeof(boss_archetype.get("demo_objective", {})) == TYPE_DICTIONARY else {}
	var showdown_threshold := clampi(int(objective.get("showdown_heat_threshold", 70)), 1, 100)
	var game_ids := ["pull_tabs", "slot", "bar_dice", "blackjack", "baccarat", "roulette", "video_poker"]
	var summaries: Array[String] = []
	for game_id in game_ids:
		var game: GameModule = _load_surface_contract_game(library, game_id, failures)
		if game == null:
			continue
		var action_run := _grand_casino_game_fixture_run(library, boss_archetype, game_id, game, "C5-ACTIONS-%s" % game_id.to_upper())
		_check_skill_cheat_action_presentation(game_id, game.cheat_actions(action_run, action_run.current_environment), failures)

		var fixture := _grand_casino_game_heat_fixture(library, boss_archetype, game_id, game, showdown_threshold, failures)
		if fixture.is_empty():
			continue
		var run_state := fixture.get("run_state", null) as RunState
		var result: Dictionary = fixture.get("result", {})
		if run_state == null or result.is_empty() or not bool(result.get("ok", false)):
			failures.append("Skill-cheat %s fixture did not resolve a watched cheat result." % game_id)
			continue
		_check_skill_cheat_result_contract(game_id, result, true, failures)
		var status := run_state.demo_objective_status()
		if not bool(status.get("staff_attention_active", false)):
			failures.append("Skill-cheat %s watched Grand Casino cheat did not expose staff attention." % game_id)
		if str(result.get("action_kind", "")) == "cheat" and not bool(run_state.narrative_flags.get("grand_casino_attention_watched_cheat", false)):
			failures.append("Skill-cheat %s watched cheat did not set grand_casino_attention_watched_cheat." % game_id)

		var clean_run := _grand_casino_game_fixture_run(library, boss_archetype, game_id, game, "C5-CLEAN-%s" % game_id.to_upper())
		var clean_result := _skill_cheat_clean_result(game_id, game, clean_run)
		if clean_result.is_empty() or not bool(clean_result.get("ok", false)):
			failures.append("Skill-cheat %s clean fixture did not resolve a legal result." % game_id)
		else:
			if bool(clean_result.get("host_apply_result", false)):
				GameModule.apply_result(clean_run, clean_result, clean_run.create_rng("c5_%s_clean_host_apply" % game_id))
			if str(clean_result.get("action_kind", "")) != "legal":
				failures.append("Skill-cheat %s clean fixture reported %s instead of legal." % [game_id, str(clean_result.get("action_kind", ""))])
			if bool(clean_result.get("skill_cheat_contract", false)):
				failures.append("Skill-cheat %s clean fixture incorrectly received the skill-cheat contract." % game_id)
			var clean_status := clean_run.demo_objective_status()
			if int(clean_status.get("grand_casino_open_cheat_actions", 0)) != 0 or bool(clean_status.get("cheat_evidence", false)) or bool(clean_status.get("watched_cheat_evidence", false)):
				failures.append("Skill-cheat %s clean play marked Grand Casino cheat evidence." % game_id)
		summaries.append("%s:%s:%s:+%d" % [
			game_id,
			str(result.get("action_kind", "")),
			str(result.get("skill_outcome", "")),
			int(result.get("suspicion_delta", 0)),
		])
	print("SKILL_CHEAT_CONTRACT_MATRIX %s" % ", ".join(summaries))


func _check_skill_cheat_action_presentation(game_id: String, cheat_actions: Array, failures: Array) -> void:
	if cheat_actions.is_empty():
		failures.append("Skill-cheat %s did not expose cheat_actions." % game_id)
		return
	for action_value in cheat_actions:
		if typeof(action_value) != TYPE_DICTIONARY:
			failures.append("Skill-cheat %s exposed a non-dictionary cheat action." % game_id)
			continue
		var action: Dictionary = action_value
		if str(action.get("id", "")).strip_edges().is_empty():
			failures.append("Skill-cheat %s cheat action is missing an id." % game_id)
		if str(action.get("label", "")).strip_edges().is_empty():
			failures.append("Skill-cheat %s cheat action is missing a label." % game_id)
		var summary := str(action.get("summary", "")).strip_edges()
		if summary.is_empty():
			failures.append("Skill-cheat %s cheat action is missing payoff/risk summary copy." % game_id)
		_check_no_release_placeholder_text(summary, "Skill-cheat %s cheat action" % game_id, failures)


func _check_skill_cheat_result_contract(game_id: String, result: Dictionary, expected_watched: bool, failures: Array) -> void:
	var action_kind := str(result.get("action_kind", ""))
	if not ["cheat", "risky", "advantage"].has(action_kind):
		failures.append("Skill-cheat %s result used inconsistent action_kind %s." % [game_id, action_kind])
	if not bool(result.get("skill_cheat_contract", false)):
		failures.append("Skill-cheat %s result did not expose the shared skill-cheat contract." % game_id)
	var skill_outcome := str(result.get("skill_outcome", "")).strip_edges()
	if skill_outcome.is_empty():
		failures.append("Skill-cheat %s result did not report skill_outcome." % game_id)
	if int(result.get("skill_suspicion_delta", -999)) != int(result.get("suspicion_delta", 0)):
		failures.append("Skill-cheat %s skill_suspicion_delta did not match suspicion_delta." % game_id)
	if int(result.get("suspicion_delta", 0)) > 0 and not bool(result.get("skill_security_pressure_checked", false)):
		failures.append("Skill-cheat %s result did not mark security pressure evaluation." % game_id)
	if expected_watched and not bool(result.get("skill_watched", false)):
		failures.append("Skill-cheat %s watched result did not set skill_watched." % game_id)
	if expected_watched and not bool(result.get("pit_boss_watched", false)):
		failures.append("Skill-cheat %s watched result did not set generic pit_boss_watched." % game_id)
	if expected_watched and int(result.get("pit_boss_heat_bonus", 0)) <= 0:
		failures.append("Skill-cheat %s watched result did not report pit boss heat bonus." % game_id)
	if typeof(result.get("skill_story_context", {})) != TYPE_DICTIONARY:
		failures.append("Skill-cheat %s result did not expose skill_story_context." % game_id)
	var deltas: Dictionary = result.get("deltas", {}) if typeof(result.get("deltas", {})) == TYPE_DICTIONARY else {}
	var story_entries: Array = deltas.get("story_log", []) if typeof(deltas.get("story_log", [])) == TYPE_ARRAY else []
	var found_story := false
	for story_value in story_entries:
		if typeof(story_value) != TYPE_DICTIONARY:
			continue
		var story: Dictionary = story_value
		if str(story.get("game_id", "")) != game_id or str(story.get("action_id", "")) != str(result.get("action_id", "")):
			continue
		found_story = true
		if str(story.get("skill_outcome", "")).strip_edges().is_empty():
			failures.append("Skill-cheat %s story entry did not report skill_outcome." % game_id)
		if expected_watched and not bool(story.get("skill_watched", false)):
			failures.append("Skill-cheat %s story entry did not preserve watched state." % game_id)
		if int(story.get("suspicion_delta", 0)) != int(result.get("suspicion_delta", 0)):
			failures.append("Skill-cheat %s story suspicion did not match result." % game_id)
	if not found_story:
		failures.append("Skill-cheat %s result did not include matching story context." % game_id)
	var message := str(result.get("message", "")).strip_edges()
	_check_no_release_placeholder_text(message, "Skill-cheat %s result" % game_id, failures)
	var lowered := message.to_lower()
	if int(result.get("suspicion_delta", 0)) > 0 and lowered.find("heat") < 0 and lowered.find("security") < 0 and lowered.find("rourke") < 0 and lowered.find("back room") < 0 and lowered.find("watched") < 0 and lowered.find("risk") < 0:
		failures.append("Skill-cheat %s result copy did not communicate risk or staff pressure." % game_id)


func _check_no_release_placeholder_text(text: String, label: String, failures: Array) -> void:
	var lowered := text.to_lower()
	for marker in ["todo", "placeholder", "test-only", "dev-only"]:
		if lowered.find(marker) >= 0:
			failures.append("%s contains release-path placeholder marker: %s." % [label, marker])


func _skill_cheat_clean_result(game_id: String, game: GameModule, run_state: RunState) -> Dictionary:
	var environment: Dictionary = run_state.current_environment
	match game_id:
		"bar_dice":
			return _bar_dice_play_round(game, run_state, run_state.create_rng("c5_bar_dice_clean"), "roll")
		"video_poker":
			return _video_poker_play_hand(game, run_state, run_state.create_rng("c5_video_poker_clean"), "draw")
		"blackjack":
			return game.resolve_with_context("play_basic", 10, run_state, environment, run_state.create_rng("c5_blackjack_clean"), _xgame_blackjack_win_ui())
		"pull_tabs":
			var buy_command: Dictionary = game.surface_action_command("pull_tab_buy", 0, false, {}, run_state, environment)
			return game.resolve_with_context("buy_tab", int(buy_command.get("set_stake", 1)), run_state, environment, run_state.create_rng("c5_pull_tabs_clean"), buy_command.get("ui_state", {}))
		"slot":
			var machine: Dictionary = _slot_machine(game.definition, run_state, "pinball", "classic_3_reel", "standard", "plain")
			_slot_store_machine(run_state, environment, machine)
			return game.resolve_with_context("spin", 10, run_state, environment, run_state.create_rng("c5_slot_clean"), {})
		"baccarat":
			return game.resolve_with_context("deal_baccarat", 20, run_state, environment, run_state.create_rng("c5_baccarat_clean"), {"baccarat_bets": {"player": 20}})
		"roulette":
			return game.resolve_with_context("spin_roulette", 10, run_state, environment, run_state.create_rng("c5_roulette_clean"), {"roulette_bets": [game.call("_default_smoke_bet", 10)]})
	return {}


func _check_grand_casino_game_endgame_contracts(library: ContentLibrary, failures: Array) -> void:
	var boss_archetype := _archetype_by_id(library, "grand_casino")
	if boss_archetype.is_empty():
		failures.append("Grand Casino game endgame audit requires the grand_casino archetype.")
		return
	var objective: Dictionary = boss_archetype.get("demo_objective", {}) if typeof(boss_archetype.get("demo_objective", {})) == TYPE_DICTIONARY else {}
	var showdown_threshold := clampi(int(objective.get("showdown_heat_threshold", 70)), 1, 100)
	var game_ids := ["pull_tabs", "slot", "bar_dice", "blackjack", "baccarat", "roulette", "video_poker"]
	var summaries: Array[String] = []
	for game_id in game_ids:
		var game: GameModule = _load_surface_contract_game(library, game_id, failures)
		if game == null:
			continue
		var fixture := _grand_casino_game_heat_fixture(library, boss_archetype, game_id, game, showdown_threshold, failures)
		if fixture.is_empty():
			continue
		var run_state := fixture.get("run_state", null) as RunState
		var result: Dictionary = fixture.get("result", {})
		if run_state == null:
			failures.append("Grand Casino %s fixture did not return a RunState." % game_id)
			continue
		if not bool(result.get("ok", false)):
			failures.append("Grand Casino %s fixture did not resolve a successful game result." % game_id)
			continue
		var action_kind := str(result.get("action_kind", ""))
		if not ["cheat", "risky", "advantage"].has(action_kind):
			failures.append("Grand Casino %s fixture should report a cheat/risky action kind, got %s." % [game_id, action_kind])
		var suspicion_delta := int(result.get("suspicion_delta", 0))
		if suspicion_delta <= 0:
			failures.append("Grand Casino %s fixture did not report positive heat." % game_id)
		var message := str(result.get("message", ""))
		if message.find("Rourke") == -1 and message.find("Security") == -1 and message.find("back room") == -1:
			failures.append("Grand Casino %s result message did not explain staff/Rourke pressure." % game_id)
		var status := run_state.demo_objective_status()
		if run_state.run_status != RunState.RUN_STATUS_ACTIVE:
			failures.append("Grand Casino %s high heat should leave the run active for showdown, status=%s." % [game_id, run_state.run_status])
		if run_state.run_failure_reason == RunState.FAILURE_POLICE_CAPTURE:
			failures.append("Grand Casino %s high heat bypassed the showdown reroute as police_capture." % game_id)
		if not bool(status.get("showdown_pending", false)) and not bool(status.get("showdown_active", false)):
			failures.append("Grand Casino %s high heat did not queue the Pit Boss Showdown." % game_id)
		if not bool(status.get("staff_attention_active", false)):
			failures.append("Grand Casino %s high heat did not preserve staff attention state." % game_id)
		if action_kind == "cheat" and int(status.get("grand_casino_open_cheat_actions", 0)) <= 0:
			failures.append("Grand Casino %s cheat result did not mark open cheat evidence." % game_id)
		summaries.append("%s:%s:+%d:%s" % [game_id, action_kind, suspicion_delta, str(status.get("objective_state", ""))])

	var outside_game: GameModule = _load_surface_contract_game(library, "slot", failures)
	if outside_game != null:
		var outside_run: RunState = RunStateScript.new()
		outside_run.start_new("C1-OUTSIDE-HEAT")
		outside_run.bankroll = 100000
		outside_run.set_environment({
			"id": "c1_outside_slot_fixture",
			"display_name": "Roadside Slots",
			"archetype_id": "gas_station_casino",
			"kind": "casino",
			"game_ids": ["slot"],
			"turns": 0,
		})
		outside_run.add_suspicion("c1_outside_preheat", 99, "behavior")
		var outside_result := GameModule.build_action_result({
			"ok": true,
			"type": "game_action",
			"source_id": "slot",
			"game_id": "slot",
			"action_id": "outside_heat_fixture",
			"action_kind": "cheat",
			"stake": 10,
			"suspicion_delta": 1,
			"environment_id": str(outside_run.current_environment.get("id", "")),
			"message": "Outside heat fixture.",
		})
		GameModule.apply_result(outside_run, outside_result, outside_run.create_rng("c1_outside_apply"))
		if outside_run.run_status != RunState.RUN_STATUS_FAILED or outside_run.run_failure_reason != RunState.FAILURE_POLICE_CAPTURE:
			failures.append("Outside-Grand-Casino game heat 100 did not preserve police_capture failure.")
	print("GRAND_CASINO_GAME_ENDGAME_MATRIX %s" % ", ".join(summaries))


func _grand_casino_game_heat_fixture(library: ContentLibrary, boss_archetype: Dictionary, game_id: String, game: GameModule, showdown_threshold: int, failures: Array) -> Dictionary:
	var run_state := _grand_casino_game_fixture_run(library, boss_archetype, game_id, game, "C1-GRAND-%s" % game_id.to_upper())
	run_state.add_suspicion("c1_grand_preheat_%s" % game_id, maxi(0, showdown_threshold - 1), "behavior")
	var result := _grand_casino_game_cheat_result(game_id, game, run_state)
	if result.is_empty():
		failures.append("Grand Casino %s fixture could not produce a cheat/risky result." % game_id)
		return {}
	if bool(result.get("ok", false)):
		_check_action_result_shape(result, str(result.get("action_kind", "cheat")), failures)
		if bool(result.get("host_apply_result", false)):
			GameModule.apply_result(run_state, result, run_state.create_rng("c1_%s_host_apply" % game_id))
	return {
		"run_state": run_state,
		"result": result,
	}


func _grand_casino_game_fixture_run(library: ContentLibrary, boss_archetype: Dictionary, game_id: String, game: GameModule, seed_text: String) -> RunState:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new(seed_text)
	run_state.bankroll = 100000
	var environment := EnvironmentInstance.from_archetype(boss_archetype, 3, run_state.create_rng("c1_grand_environment"), library).to_dict()
	environment["id"] = "c1_grand_%s_fixture" % game_id
	environment["display_name"] = "Grand Casino"
	environment["archetype_id"] = "grand_casino"
	environment["kind"] = "boss"
	environment["game_ids"] = [game_id]
	environment["turns"] = 0
	var generated_state := game.generate_environment_state(run_state, environment, run_state.create_rng("c1_%s_state" % game_id))
	if not generated_state.is_empty():
		environment["game_states"] = {game_id: generated_state}
	run_state.set_environment(environment)
	return run_state


func _grand_casino_game_cheat_result(game_id: String, game: GameModule, run_state: RunState) -> Dictionary:
	var environment: Dictionary = run_state.current_environment
	var rng := run_state.create_rng("c1_%s_heat_result" % game_id)
	match game_id:
		"bar_dice":
			var roll_command: Dictionary = game.surface_action_command("bar_dice_roll", 0, false, {}, run_state, environment)
			var dice_ui: Dictionary = roll_command.get("ui_state", {})
			var load_command: Dictionary = game.surface_action_command("bar_dice_load", 0, false, dice_ui, run_state, environment)
			dice_ui = load_command.get("ui_state", dice_ui)
			return game.resolve_with_context("loaded_toss", 10, run_state, environment, rng, dice_ui)
		"video_poker":
			var deal_command: Dictionary = game.surface_action_command("video_poker_deal", 0, false, {}, run_state, environment)
			return game.resolve_with_context("mark_holds", 5, run_state, environment, rng, deal_command.get("ui_state", {}))
		"blackjack":
			return game.resolve_with_context("play_basic", 10, run_state, environment, rng, _xgame_blackjack_dirty_count_ui())
		"pull_tabs":
			run_state.add_item("tab_detector")
			return game.resolve_with_context("tab_detector_scan", 0, run_state, environment, rng, {})
		"slot":
			var machine: Dictionary = _slot_machine(game.definition, run_state, "pinball", "classic_3_reel", "standard", "plain")
			_slot_store_machine(run_state, environment, machine)
			return game.resolve_with_context("nudge", 10, run_state, environment, rng, {})
		"baccarat":
			var baccarat_command: Dictionary = game.surface_action_command("baccarat_read_shoe", 0, false, {}, run_state, environment)
			return game.resolve_with_context("read_baccarat_shoe", 0, run_state, environment, rng, baccarat_command.get("ui_state", {}))
		"roulette":
			var roulette_command: Dictionary = game.surface_action_command("roulette_read_wheel", 0, false, {}, run_state, environment)
			var roulette_ui: Dictionary = roulette_command.get("ui_state", {})
			roulette_ui["roulette_bets"] = [game.call("_default_smoke_bet", 10)]
			return game.resolve_with_context("spin_roulette", 10, run_state, environment, rng, roulette_ui)
	return {}


func _check_premium_grand_casino_table_contract(library: ContentLibrary, game_id: String, game: GameModule, failures: Array) -> void:
	var boss_archetype := _archetype_by_id(library, "grand_casino")
	if boss_archetype.is_empty():
		failures.append("Grand Casino premium %s audit requires the grand_casino archetype." % game_id)
		return
	if not _string_array(boss_archetype.get("game_pool", [])).has(game_id):
		failures.append("Grand Casino premium audit expected %s in the boss-floor game pool." % game_id)
		return

	var progress_run := _grand_casino_game_fixture_run(library, boss_archetype, game_id, game, "C3-GRAND-PROGRESS-%s" % game_id.to_upper())
	var entry_bankroll := int(progress_run.narrative_flags.get("grand_casino_entry_bankroll", progress_run.bankroll))
	var legal_result := _premium_grand_casino_legal_result(game_id, game, progress_run)
	if not bool(legal_result.get("ok", false)):
		failures.append("Grand Casino premium %s legal fixture did not resolve: %s" % [game_id, str(legal_result.get("message", ""))])
	else:
		var progress_status: Dictionary = progress_run.demo_objective_status()
		if int(progress_status.get("grand_casino_games_played", 0)) != 1:
			failures.append("Grand Casino premium %s result did not count toward high-roller games." % game_id)
		if int(progress_status.get("grand_casino_net_winnings", 999999)) != progress_run.bankroll - entry_bankroll:
			failures.append("Grand Casino premium %s result did not update high-roller net winnings." % game_id)
		if progress_run.run_status == RunState.RUN_STATUS_FAILED:
			failures.append("Grand Casino premium %s legal result unexpectedly failed the run." % game_id)

	var pressure_run := _grand_casino_game_fixture_run(library, boss_archetype, game_id, game, "C3-GRAND-PRESSURE-%s" % game_id.to_upper())
	var objective: Dictionary = boss_archetype.get("demo_objective", {}) if typeof(boss_archetype.get("demo_objective", {})) == TYPE_DICTIONARY else {}
	var showdown_threshold := clampi(int(objective.get("showdown_heat_threshold", 70)), 1, 100)
	pressure_run.add_suspicion("c3_premium_preheat_%s" % game_id, maxi(0, showdown_threshold - 1), "behavior")
	var pressure_result := _premium_grand_casino_read_result(game_id, game, pressure_run)
	if not bool(pressure_result.get("ok", false)):
		failures.append("Grand Casino premium %s read fixture did not resolve: %s" % [game_id, str(pressure_result.get("message", ""))])
	else:
		var pressure_status: Dictionary = pressure_run.demo_objective_status()
		if not bool(pressure_run.narrative_flags.get("grand_casino_attention_watched_cheat", false)):
			failures.append("Grand Casino premium %s watched read did not mark watched cheat attention." % game_id)
		if not bool(pressure_status.get("staff_attention_active", false)):
			failures.append("Grand Casino premium %s watched read did not expose staff attention." % game_id)
		if not bool(pressure_status.get("showdown_pending", false)) and not bool(pressure_status.get("showdown_active", false)):
			failures.append("Grand Casino premium %s watched read did not feed showdown pressure." % game_id)
		var message := str(pressure_result.get("message", ""))
		if message.find("Rourke") == -1 and message.find("staff") == -1 and message.find("patron") == -1 and message.find("Security") == -1:
			failures.append("Grand Casino premium %s read result did not communicate staff or patron pressure." % game_id)

	print("GRAND_CASINO_PREMIUM_TABLE %s games=%d pressure=%s staff=%s" % [
		game_id,
		int(progress_run.demo_objective_status().get("grand_casino_games_played", 0)),
		str(pressure_run.demo_objective_status().get("objective_state", "")),
		str(pressure_run.demo_objective_status().get("staff_attention_active", false)),
	])


func _premium_grand_casino_legal_result(game_id: String, game: GameModule, run_state: RunState) -> Dictionary:
	var environment: Dictionary = run_state.current_environment
	match game_id:
		"baccarat":
			var baccarat_ui := {"baccarat_bets": {"player": 20}}
			return game.resolve_with_context("deal_baccarat", 20, run_state, environment, run_state.create_rng("c3_baccarat_legal"), baccarat_ui)
		"roulette":
			var roulette_ui := {"roulette_bets": [game.call("_default_smoke_bet", 10)]}
			return game.resolve_with_context("spin_roulette", 10, run_state, environment, run_state.create_rng("c3_roulette_legal"), roulette_ui)
	return {}


func _premium_grand_casino_read_result(game_id: String, game: GameModule, run_state: RunState) -> Dictionary:
	var environment: Dictionary = run_state.current_environment
	match game_id:
		"baccarat":
			var baccarat_command: Dictionary = game.surface_action_command("baccarat_read_shoe", 0, false, {}, run_state, environment)
			return game.resolve_with_context("read_baccarat_shoe", 0, run_state, environment, run_state.create_rng("c3_baccarat_read"), baccarat_command.get("ui_state", {}))
		"roulette":
			var roulette_command: Dictionary = game.surface_action_command("roulette_read_wheel", 0, false, {}, run_state, environment)
			return game.resolve_with_context("read_wheel_bias", 0, run_state, environment, run_state.create_rng("c3_roulette_read"), roulette_command.get("ui_state", {}))
	return {}


func _xgame_assert_shift(game_id: String, dimension: String, baseline: int, modified: int, direction: String, failures: Array) -> void:
	var ok := modified > baseline if direction == "up" else modified < baseline
	print("XGAME_INTEGRATION game=%s dim=%s baseline=%d modified=%d shift=%s" % [game_id, dimension, baseline, modified, "ok" if ok else "FAIL"])
	if not ok:
		failures.append("Cross-game integration %s/%s did not shift %s (baseline=%d modified=%d)." % [game_id, dimension, direction, baseline, modified])


func _xgame_luck_pair(game_id: String, game: GameModule, failures: Array) -> Dictionary:
	match game_id:
		"blackjack":
			return {
				"baseline": _xgame_blackjack_win_metric(game, 0, ""),
				"modified": _xgame_blackjack_win_metric(game, 10, ""),
			}
		"pull_tabs":
			return {
				"baseline": _xgame_pull_tabs_redeem_metric(game, 0, ""),
				"modified": _xgame_pull_tabs_redeem_metric(game, 10, ""),
			}
	for attempt in range(80):
		var seed := "XGAME-LUCK-%s-%02d" % [game_id, attempt]
		var baseline := _xgame_win_metric(game_id, game, seed, 0, "")
		if baseline <= 0:
			continue
		var modified := _xgame_win_metric(game_id, game, seed, 10, "")
		if modified > baseline:
			return {"baseline": baseline, "modified": modified}
	failures.append("Cross-game integration could not find a deterministic paying %s sample for luck." % game_id)
	return {"baseline": 0, "modified": 0}


func _xgame_win_metric(game_id: String, game: GameModule, seed: String, luck: int, item_id: String) -> int:
	match game_id:
		"bar_dice":
			return _xgame_bar_dice_win_metric(game, seed, luck, item_id)
		"video_poker":
			return _xgame_video_poker_win_metric(game, seed, luck, item_id)
		"slot":
			return _xgame_slot_win_metric(game, seed, luck, item_id)
		_:
			return 0


func _xgame_heat_pair(game_id: String, game: GameModule, drunk_modified: bool, watched_modified: bool, item_id: String) -> Dictionary:
	var seed := "XGAME-HEAT-%s-%s-%s-%s" % [game_id, item_id, str(drunk_modified), str(watched_modified)]
	var baseline := _xgame_cheat_heat_metric(game_id, game, seed, false, false, "")
	var modified := _xgame_cheat_heat_metric(game_id, game, seed, drunk_modified, watched_modified, item_id)
	return {"baseline": baseline, "modified": modified}


func _xgame_cheat_heat_metric(game_id: String, game: GameModule, seed: String, drunk: bool, watched: bool, item_id: String) -> int:
	match game_id:
		"bar_dice":
			return _xgame_bar_dice_heat_metric(game, seed, drunk, watched, item_id)
		"video_poker":
			return _xgame_video_poker_heat_metric(game, seed, drunk, watched, item_id)
		"blackjack":
			return _xgame_blackjack_heat_metric(game, seed, drunk, watched, item_id)
		"pull_tabs":
			return _xgame_pull_tabs_heat_metric(game, seed, drunk, watched, item_id)
		"slot":
			return _xgame_slot_heat_metric(game, seed, drunk, watched, item_id)
		_:
			return 0


func _xgame_run(seed: String, bankroll: int, drunk: bool, item_id: String) -> RunState:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new(seed)
	run_state.bankroll = bankroll
	run_state.drunk_level = 85 if drunk else 0
	if not item_id.is_empty():
		run_state.add_item(item_id)
	return run_state


func _xgame_environment(game_id: String, watched: bool) -> Dictionary:
	var environment := _surface_contract_environment()
	environment["id"] = "xgame_%s_room" % game_id
	environment["game_ids"] = [game_id]
	environment["economic_profile"] = {"stake_floor": 1, "stake_ceiling": 100}
	environment["turns"] = 0 if watched else 1
	environment["security_profile"] = {
		"strictness": "tight",
		"pit_boss": {"enabled": true, "cycle_length": 2, "watched_turns": 1, "cheat_heat_bonus": 20},
	}
	return environment


func _xgame_bar_dice_run(game: GameModule, seed: String, luck: int, drunk: bool, watched: bool, item_id: String) -> RunState:
	var run_state: RunState = _xgame_run(seed, 100000, drunk, item_id)
	run_state.baseline_luck = luck
	var environment: Dictionary = _xgame_environment("bar_dice", watched)
	environment["game_states"] = {"bar_dice": _bar_dice_state_for(game, run_state, environment, "poker_dice", "standard", "hot_hand")}
	run_state.current_environment = environment.duplicate(true)
	return run_state


func _xgame_bar_dice_win_metric(game: GameModule, seed: String, luck: int, item_id: String) -> int:
	var run_state: RunState = _xgame_bar_dice_run(game, seed, luck, false, false, item_id)
	var result: Dictionary = _bar_dice_play_round(game, run_state, run_state.create_rng("xgame_bar_dice_win"), "roll")
	return int(result.get("bankroll_delta", 0))


func _xgame_bar_dice_heat_metric(game: GameModule, seed: String, drunk: bool, watched: bool, item_id: String) -> int:
	var run_state: RunState = _xgame_bar_dice_run(game, seed, 0, drunk, watched, item_id)
	var roll_command: Dictionary = game.surface_action_command("bar_dice_roll", 0, false, {}, run_state, run_state.current_environment)
	var ui: Dictionary = roll_command.get("ui_state", {})
	var load_command: Dictionary = game.surface_action_command("bar_dice_load", 0, false, ui, run_state, run_state.current_environment)
	ui = load_command.get("ui_state", ui)
	var result: Dictionary = game.resolve_with_context("loaded_toss", 10, run_state, run_state.current_environment, run_state.create_rng("xgame_bar_dice_heat"), ui)
	return int(result.get("suspicion_delta", 0))


func _xgame_video_poker_run(game: GameModule, seed: String, luck: int, drunk: bool, watched: bool, item_id: String) -> RunState:
	var run_state: RunState = _vp_fresh(game, "jacks_or_better", seed, 100000, "standard", 1, 1)
	run_state.baseline_luck = luck
	run_state.drunk_level = 85 if drunk else 0
	if not item_id.is_empty():
		run_state.add_item(item_id)
	run_state.current_environment["security_profile"] = _xgame_environment("video_poker", watched).get("security_profile", {})
	run_state.current_environment["turns"] = 0 if watched else 1
	return run_state


func _xgame_video_poker_win_metric(game: GameModule, seed: String, luck: int, item_id: String) -> int:
	var run_state: RunState = _xgame_video_poker_run(game, seed, luck, false, false, item_id)
	var result: Dictionary = _video_poker_play_hand(game, run_state, run_state.create_rng("xgame_video_poker_win"), "draw")
	return int(result.get("bankroll_delta", 0))


func _xgame_video_poker_heat_metric(game: GameModule, seed: String, drunk: bool, watched: bool, item_id: String) -> int:
	var run_state: RunState = _xgame_video_poker_run(game, seed, 0, drunk, watched, item_id)
	var deal_command: Dictionary = game.surface_action_command("video_poker_deal", 0, false, {}, run_state, run_state.current_environment)
	var result: Dictionary = game.resolve_with_context("mark_holds", 5, run_state, run_state.current_environment, run_state.create_rng("xgame_video_poker_heat"), deal_command.get("ui_state", {}))
	return int(result.get("suspicion_delta", 0))


func _xgame_blackjack_run(game: GameModule, seed: String, luck: int, drunk: bool, watched: bool, item_id: String) -> RunState:
	var run_state: RunState = _xgame_run(seed, 100000, drunk, item_id)
	run_state.baseline_luck = luck
	var environment: Dictionary = _xgame_environment("blackjack", watched)
	environment["game_states"] = {"blackjack": game.generate_environment_state(run_state, environment, run_state.create_rng("xgame_blackjack_state"))}
	run_state.current_environment = environment.duplicate(true)
	return run_state


func _xgame_blackjack_win_ui() -> Dictionary:
	return {
		"selected_stake": 10,
		"player_hands": [{"cards": [{"rank": 10, "suit": 0}, {"rank": 9, "suit": 1}], "stood": true, "wager_multiplier": 1, "blackjack_eligible": true}],
		"dealer_cards": [{"rank": 10, "suit": 2}, {"rank": 7, "suit": 3}],
		"patron_hands": [],
		"moves_made": true,
	}


func _xgame_blackjack_dirty_count_ui() -> Dictionary:
	var ui: Dictionary = _xgame_blackjack_win_ui()
	ui["cheats_used"] = {"count_cards": true}
	ui["count_attempted"] = true
	ui["count_answered"] = true
	ui["count_correct"] = false
	ui["count_delta"] = 0
	ui["count_challenge"] = {
		"missed_icons": ["xgame_miss"],
		"bad_hits": 1,
		"target_delta": 2,
		"dealer_attention_risk": 28,
	}
	return ui


func _xgame_blackjack_win_metric(game: GameModule, luck: int, item_id: String) -> int:
	var run_state: RunState = _xgame_blackjack_run(game, "XGAME-BLACKJACK-WIN", luck, false, false, item_id)
	var result: Dictionary = game.resolve_with_context("play_basic", 10, run_state, run_state.current_environment, run_state.create_rng("xgame_blackjack_win"), _xgame_blackjack_win_ui())
	return int(result.get("bankroll_delta", 0))


func _xgame_blackjack_heat_metric(game: GameModule, seed: String, drunk: bool, watched: bool, item_id: String) -> int:
	var run_state: RunState = _xgame_blackjack_run(game, seed, 0, drunk, watched, item_id)
	var result: Dictionary = game.resolve_with_context("count_cards", 10, run_state, run_state.current_environment, run_state.create_rng("xgame_blackjack_heat"), _xgame_blackjack_dirty_count_ui())
	return int(result.get("suspicion_delta", 0))


func _xgame_pull_tabs_run(game: GameModule, seed: String, luck: int, drunk: bool, watched: bool, item_id: String) -> RunState:
	var run_state: RunState = _xgame_run(seed, 100000, drunk, item_id)
	run_state.baseline_luck = luck
	var environment: Dictionary = _xgame_environment("pull_tabs", watched)
	environment["game_states"] = {"pull_tabs": game.generate_environment_state(run_state, environment, run_state.create_rng("xgame_pull_tabs_state"))}
	run_state.current_environment = environment.duplicate(true)
	return run_state


func _xgame_pull_tabs_redeem_metric(game: GameModule, luck: int, item_id: String) -> int:
	var run_state: RunState = _xgame_pull_tabs_run(game, "XGAME-PULL-TABS-REDEEM", luck, false, false, item_id)
	var ticket_payload: Dictionary = _pull_tab_test_ticket_result("xgame", 30)
	var ticket: Dictionary = ticket_payload.get("pull_tab_ticket", {})
	ticket["price"] = 10
	ticket_payload["pull_tab_ticket"] = ticket
	_set_pull_tab_loser_count(run_state.current_environment, 3)
	_inject_pull_tab_winner(run_state.current_environment, ticket_payload)
	var command: Dictionary = game.environment_action_command("ticket_redeemer", "redeem_pull_tab_winners", run_state, run_state.current_environment, run_state.create_rng("xgame_pull_tabs_redeem"))
	var result: Dictionary = command.get("result", {})
	return int(result.get("bankroll_delta", 0))


func _xgame_pull_tabs_heat_metric(game: GameModule, seed: String, drunk: bool, watched: bool, item_id: String) -> int:
	var run_state: RunState = _xgame_pull_tabs_run(game, seed, 0, drunk, watched, item_id)
	run_state.add_item("tab_detector")
	var result: Dictionary = game.resolve_with_context("tab_detector_scan", 0, run_state, run_state.current_environment, run_state.create_rng("xgame_pull_tabs_heat"), {})
	return int(result.get("suspicion_delta", 0))


func _xgame_slot_run(seed: String, luck: int, drunk: bool, watched: bool, item_id: String) -> RunState:
	var run_state: RunState = _slot_run_state(seed, 100000)
	run_state.baseline_luck = luck
	run_state.drunk_level = 85 if drunk else 0
	if not item_id.is_empty():
		run_state.add_item(item_id)
	var environment: Dictionary = _slot_environment()
	environment["id"] = "xgame_slot_room"
	environment["security_profile"] = _xgame_environment("slot", watched).get("security_profile", {})
	environment["turns"] = 0 if watched else 1
	run_state.current_environment = environment.duplicate(true)
	return run_state


func _xgame_slot_win_metric(game: GameModule, seed: String, luck: int, item_id: String) -> int:
	var definition: Dictionary = game.definition
	var run_state: RunState = _xgame_slot_run(seed, luck, false, false, item_id)
	var environment: Dictionary = run_state.current_environment
	var machine: Dictionary = _slot_machine(definition, run_state, "pinball", "classic_3_reel", "standard", "plain")
	_slot_store_machine(run_state, environment, machine)
	var result: Dictionary = game.resolve_with_context("spin", 10, run_state, environment, run_state.create_rng("xgame_slot_win"), {})
	if int(result.get("slot_payout", 0)) <= 0:
		return int(result.get("bankroll_delta", 0))
	return int(result.get("bankroll_delta", 0))


func _xgame_slot_heat_metric(game: GameModule, seed: String, drunk: bool, watched: bool, item_id: String) -> int:
	var definition: Dictionary = game.definition
	var run_state: RunState = _xgame_slot_run(seed, 0, drunk, watched, item_id)
	var environment: Dictionary = run_state.current_environment
	var machine: Dictionary = _slot_machine(definition, run_state, "pinball", "classic_3_reel", "standard", "plain")
	_slot_store_machine(run_state, environment, machine)
	var result: Dictionary = game.resolve_with_context("nudge", 10, run_state, environment, run_state.create_rng("xgame_slot_heat"), {})
	return int(result.get("suspicion_delta", 0))


func _check_generic_game_module_contract(game: GameModule, failures: Array) -> void:
	var game_id := game.get_id()
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("GAME-CONTRACT-%s" % game_id.to_upper())
	var environment := _surface_contract_environment()
	environment["game_ids"] = [game_id]
	var generated_state := game.generate_environment_state(run_state, environment, run_state.create_rng("%s_generated_state" % game_id))
	if not generated_state.is_empty():
		environment["game_states"] = {game_id: generated_state}
	run_state.current_environment = environment.duplicate(true)

	var model := game.gameplay_model()
	if model != GameModule.GAMEPLAY_MODEL_GENERIC_ODDS and model != GameModule.GAMEPLAY_MODEL_FULL_SIMULATION:
		failures.append("%s returned an unknown gameplay model: %s." % [game_id, model])
	if game.is_full_simulation() != (model == GameModule.GAMEPLAY_MODEL_FULL_SIMULATION):
		failures.append("%s full-simulation helper does not match gameplay_model." % game_id)

	var environment_before_enter := JSON.stringify(environment)
	var enter_result := game.enter(run_state, environment)
	if not bool(enter_result.get("ok", false)):
		failures.append("%s did not enter cleanly through the generic contract." % game_id)
	if JSON.stringify(environment) != environment_before_enter:
		failures.append("%s entry mutated environment state in the generic contract." % game_id)

	var action_presentation := game.actions(run_state, environment)
	if typeof(action_presentation.get("legal_actions", [])) != TYPE_ARRAY:
		failures.append("%s did not expose legal_actions as an array." % game_id)
	if typeof(action_presentation.get("cheat_actions", [])) != TYPE_ARRAY:
		failures.append("%s did not expose cheat_actions as an array." % game_id)

	var surface := game.surface_state(run_state, environment, {})
	if not surface.is_empty():
		_check_surface_spec_shape(game_id, surface, failures)
		_check_surface_draw_harness(game, surface, failures)
		_check_surface_bindings_non_mutating(game, surface, run_state, environment, failures)

	var object_state := game.environment_object_state(run_state, environment)
	if typeof(object_state) != TYPE_DICTIONARY:
		failures.append("%s environment_object_state did not return a dictionary." % game_id)
	elif not object_state.is_empty():
		if typeof(object_state.get("runtime_state", {})) != TYPE_DICTIONARY:
			failures.append("%s environment_object_state runtime_state must be a dictionary." % game_id)
		if typeof(object_state.get("visual_state", {})) != TYPE_DICTIONARY:
			failures.append("%s environment_object_state visual_state must be a dictionary." % game_id)

	var legal_actions: Array = action_presentation.get("legal_actions", [])
	if not legal_actions.is_empty() and typeof(legal_actions[0]) == TYPE_DICTIONARY:
		var before := _run_state_result_snapshot(run_state)
		var result := game.resolve_with_context(str((legal_actions[0] as Dictionary).get("id", "")), 1, run_state, environment, run_state.create_rng("%s_generic_resolve" % game_id), {})
		if bool(result.get("ok", false)):
			_check_action_result_shape(result, str(result.get("action_kind", "legal")), failures)
			_check_action_result_application_contract(before, run_state, result, "%s generic result" % game_id, failures)

	run_state.set_environment(environment)
	var restored: RunState = RunStateScript.new()
	restored.from_dict(run_state.to_dict())
	if not generated_state.is_empty() and not (restored.current_environment.get("game_states", {}) as Dictionary).has(game_id):
		failures.append("%s generated game state did not round-trip through RunState." % game_id)


func _check_surface_spec_shape(game_id: String, surface: Dictionary, failures: Array) -> void:
	for key in ["surface_renderer", "surface_life", "surface_cast", "surface_action_bindings", "native_selected_surface_actions", "surface_animation_channels", "surface_audio", "surface_action_blocks", "surface_realtime_state_refresh"]:
		if not surface.has(key):
			failures.append("%s surface spec missing key: %s." % [game_id, key])
	if typeof(surface.get("surface_action_bindings", {})) != TYPE_DICTIONARY:
		failures.append("%s surface_action_bindings must be a dictionary." % game_id)
	if typeof(surface.get("native_selected_surface_actions", [])) != TYPE_ARRAY:
		failures.append("%s native_selected_surface_actions must be an array." % game_id)
	if typeof(surface.get("surface_animation_channels", [])) != TYPE_ARRAY:
		failures.append("%s surface_animation_channels must be an array." % game_id)
	for channel_value in surface.get("surface_animation_channels", []):
		if typeof(channel_value) != TYPE_DICTIONARY:
			failures.append("%s surface animation channel must be a dictionary." % game_id)
			continue
		var channel: Dictionary = channel_value
		if str(channel.get("id", "")).is_empty():
			failures.append("%s surface animation channel is missing id." % game_id)
		if not channel.has("active_id") or not channel.has("duration_msec") or not channel.has("started_msec"):
			failures.append("%s surface animation channel is missing timing fields." % game_id)
	if typeof(surface.get("surface_audio", {})) != TYPE_DICTIONARY:
		failures.append("%s surface_audio must be a dictionary." % game_id)
	if typeof(surface.get("surface_action_blocks", [])) != TYPE_ARRAY:
		failures.append("%s surface_action_blocks must be an array." % game_id)
	if typeof(surface.get("surface_realtime_state_refresh", false)) != TYPE_BOOL:
		failures.append("%s surface_realtime_state_refresh must be a boolean." % game_id)


func _check_surface_draw_harness(game: GameModule, surface: Dictionary, failures: Array) -> void:
	var harness := SurfaceHarness.new()
	harness.setup(surface)
	var drew := false
	var draw_failed := false
	var draw_message := ""
	var result = game.draw_surface(harness, surface, {"contract_harness": true})
	drew = bool(result)
	if draw_failed:
		failures.append("%s draw_surface failed in harness: %s." % [game.get_id(), draw_message])
	elif not drew:
		failures.append("%s surface spec exists but draw_surface did not render through the harness." % game.get_id())


func _check_surface_bindings_non_mutating(game: GameModule, surface: Dictionary, run_state: RunState, environment: Dictionary, failures: Array) -> void:
	var bindings: Dictionary = surface.get("surface_action_bindings", {})
	for kind in ["legal", "cheat"]:
		var binding: Dictionary = bindings.get(kind, {}) if typeof(bindings.get(kind, {})) == TYPE_DICTIONARY else {}
		var action := str(binding.get("action", ""))
		if action.is_empty():
			continue
		var before_run_state := JSON.stringify(run_state.to_dict())
		var command := game.surface_action_command(action, int(binding.get("index", 0)), false, {}, run_state, environment)
		if JSON.stringify(run_state.to_dict()) != before_run_state:
			failures.append("%s %s surface binding mutated RunState before resolution." % [game.get_id(), kind])
		if not bool(command.get("handled", false)):
			failures.append("%s %s surface binding was not handled." % [game.get_id(), kind])


# Checks that scalable run actions are resolved outside the FoundationMain UI.
func _check_run_action_service_boundary(library: ContentLibrary, failures: Array) -> void:
	var item_definition := _first_definition(library.items)
	var service_definition := _first_definition(library.services)
	var lender_definition := _first_definition(library.lenders)
	if item_definition.is_empty() or service_definition.is_empty() or lender_definition.is_empty():
		failures.append("RunActionService boundary check needs item, service, and lender definitions.")
		return
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("RUN-ACTION-SERVICE")
	run_state.bankroll = 200
	run_state.current_environment = {
		"id": "run_action_service_room",
		"display_name": "Run Action Service Room",
		"kind": "shop",
		"archetype_id": "run_action_service_fixture",
		"item_offers": [{
			"id": str(item_definition.get("id", "")),
			"display_name": str(item_definition.get("display_name", "")),
			"price": 1,
		}],
		"service_ids": [str(service_definition.get("id", ""))],
		"lender_hooks": [str(lender_definition.get("id", ""))],
		"layout": {},
	}
	run_state.environment_history = [{
		"id": "run_action_service_previous_room",
		"display_name": "Previous Room",
	}, {
		"id": "run_action_service_second_previous_room",
		"display_name": "Second Previous Room",
	}]
	var resolver: RunActionService = RunActionServiceScript.new()
	resolver.setup(library, run_state)

	var item_id := str(item_definition.get("id", ""))
	var purchase := resolver.buy_item_offer(item_id)
	if not bool(purchase.get("ok", false)):
		failures.append("RunActionService did not buy an item offer: %s" % str(purchase.get("message", "")))
	elif not run_state.inventory.has(item_id) or not (run_state.current_environment.get("item_offers", []) as Array).is_empty():
		failures.append("RunActionService item purchase did not add inventory and remove the offer.")

	run_state.current_environment["item_offers"] = [{"id": item_id, "price": 1}]
	var sale := resolver.sell_inventory_item(item_id)
	if not bool(sale.get("ok", false)):
		failures.append("RunActionService did not sell a sellable inventory item: %s" % str(sale.get("message", "")))
	elif run_state.inventory.has(item_id):
		failures.append("RunActionService item sale did not remove the sold item from inventory.")

	var service_id := str(service_definition.get("id", ""))
	var service_result := resolver.use_hook("service", service_id)
	if bool(resolver.hook_option("service", service_id).get("mutation_supported", false)) and not bool(service_result.get("ok", false)):
		failures.append("RunActionService did not resolve a supported service hook: %s" % str(service_result.get("message", "")))

	var lender_id := str(lender_definition.get("id", ""))
	var lender_result := resolver.use_hook("lender", lender_id)
	if bool(resolver.hook_option("lender", lender_id).get("mutation_supported", false)) and not bool(lender_result.get("ok", false)):
		failures.append("RunActionService did not resolve a supported lender hook: %s" % str(lender_result.get("message", "")))


func _first_definition(values: Array) -> Dictionary:
	for value in values:
		if typeof(value) == TYPE_DICTIONARY:
			var data: Dictionary = value
			if not str(data.get("id", "")).is_empty():
				return data.duplicate(true)
	return {}


func _archetype_by_id(library: ContentLibrary, archetype_id: String) -> Dictionary:
	for value in library.environment_archetypes:
		if typeof(value) == TYPE_DICTIONARY and str((value as Dictionary).get("id", "")) == archetype_id:
			return (value as Dictionary).duplicate(true)
	return {}


func _string_array(values: Variant) -> Array:
	var result: Array = []
	if typeof(values) != TYPE_ARRAY:
		return result
	for value in values:
		var id := str(value)
		if not id.is_empty():
			result.append(id)
	return result


func _count_string_occurrences(values: Variant, target: String) -> int:
	var count := 0
	for id in _string_array(values):
		if str(id) == target:
			count += 1
	return count


func _surface_harness_has_action(harness, action_id: String) -> bool:
	for region_value in harness.hit_regions:
		if typeof(region_value) == TYPE_DICTIONARY and str((region_value as Dictionary).get("action", "")) == action_id:
			return true
	return false


func _check_surface_hit_layout(harness: SurfaceHarness, label: String, failures: Array) -> void:
	var board := Rect2(Vector2.ZERO, Vector2(ArtContractsScript.GAME_BOARD_SIZE))
	var regions: Array = []
	for region_value in harness.hit_regions:
		if typeof(region_value) != TYPE_DICTIONARY:
			continue
		var region: Dictionary = region_value
		var rect: Rect2 = region.get("rect", Rect2())
		var action := str(region.get("action", ""))
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			failures.append("%s has empty hit region for %s." % [label, action])
			continue
		if rect.position.x < -0.1 or rect.position.y < -0.1 or rect.end.x > board.end.x + 0.1 or rect.end.y > board.end.y + 0.1:
			failures.append("%s hit region for %s is outside the board: %s." % [label, action, str(rect)])
		regions.append({"rect": rect, "action": action, "index": int(region.get("index", -1))})
	for i in range(regions.size()):
		var a: Dictionary = regions[i]
		var a_rect: Rect2 = a.get("rect", Rect2())
		for j in range(i + 1, regions.size()):
			var b: Dictionary = regions[j]
			var b_rect: Rect2 = b.get("rect", Rect2())
			if a_rect.intersects(b_rect):
				failures.append("%s hit regions overlap: %s/%d and %s/%d." % [
					label,
					str(a.get("action", "")),
					int(a.get("index", -1)),
					str(b.get("action", "")),
					int(b.get("index", -1)),
				])


func _surface_contract_environment() -> Dictionary:
	return {
		"id": "surface_contract_room",
		"display_name": "Surface Contract Room",
		"economic_profile": {
			"stake_floor": 1,
			"stake_ceiling": 20,
		},
		"security_profile": {},
	}


func _blackjack_test_count_delta(cards: Array) -> int:
	var delta := 0
	for card_value in cards:
		if typeof(card_value) != TYPE_DICTIONARY:
			continue
		var rank := int((card_value as Dictionary).get("rank", 2))
		if rank >= 2 and rank <= 6:
			delta += 1
		elif rank == 10 or rank == 11 or rank == 12 or rank == 13 or rank == 14:
			delta -= 1
	return delta


func _blackjack_test_result_count_delta(result: Dictionary) -> int:
	var cards: Array = []
	for hand_value in result.get("blackjack_player_hands", []):
		if typeof(hand_value) != TYPE_DICTIONARY:
			continue
		for card_value in (hand_value as Dictionary).get("cards", []):
			if typeof(card_value) == TYPE_DICTIONARY:
				cards.append((card_value as Dictionary).duplicate(true))
	for patron_hand_value in result.get("blackjack_patron_hands", []):
		if typeof(patron_hand_value) != TYPE_DICTIONARY:
			continue
		for card_value in (patron_hand_value as Dictionary).get("cards", []):
			if typeof(card_value) == TYPE_DICTIONARY:
				cards.append((card_value as Dictionary).duplicate(true))
	for card_value in result.get("blackjack_dealer", []):
		if typeof(card_value) == TYPE_DICTIONARY:
			cards.append((card_value as Dictionary).duplicate(true))
	return _blackjack_test_count_delta(cards)


func _blackjack_click_all_count_icons(game: GameModule, ui_state: Dictionary, run_state: RunState, environment: Dictionary) -> Dictionary:
	var next_state := ui_state.duplicate(true)
	var challenge: Dictionary = next_state.get("count_challenge", {}) if typeof(next_state.get("count_challenge", {})) == TYPE_DICTIONARY else {}
	var icons: Array = challenge.get("icons", []) if typeof(challenge.get("icons", [])) == TYPE_ARRAY else []
	var now_msec := Time.get_ticks_msec()
	for i in range(icons.size()):
		if typeof(icons[i]) != TYPE_DICTIONARY:
			continue
		var icon: Dictionary = (icons[i] as Dictionary).duplicate(true)
		icon["spawn_msec"] = now_msec - 10
		icon["duration_msec"] = 5000
		icons[i] = icon
	challenge["icons"] = icons
	next_state["count_challenge"] = challenge
	for i in range(icons.size()):
		var answer_click := game.surface_action_command("blackjack_count_icon", i, false, next_state, run_state, environment)
		next_state = answer_click.get("ui_state", {})
	return next_state


func _surface_hit_count(harness: SurfaceHarness, action_prefix: String) -> int:
	var count := 0
	for hit_value in harness.hit_regions:
		if typeof(hit_value) == TYPE_DICTIONARY and str((hit_value as Dictionary).get("action", "")).begins_with(action_prefix):
			count += 1
	return count


func _check_roulette_surface_contract(game: GameModule, failures: Array, library: ContentLibrary = null) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("ROULETTE-SURFACE-CONTRACT")
	run_state.bankroll = 1000
	var environment := _surface_contract_environment()
	environment["game_ids"] = ["roulette"]
	environment["economic_profile"] = {"stake_floor": 1, "stake_ceiling": 200}
	var table: Dictionary = game.generate_environment_state(run_state, environment, run_state.create_rng("roulette_contract_table"))
	if table.is_empty():
		failures.append("Roulette did not generate table state for an environment.")
		return
	if str(table.get("schema", "")) != "roulette_table_state":
		failures.append("Roulette generated table state did not expose the roulette schema.")
	var wheel_sequence := _string_array(table.get("wheel_sequence", []))
	if wheel_sequence.size() != 38 or not wheel_sequence.has("0") or not wheel_sequence.has("00"):
		failures.append("Roulette generated American table did not expose a 38-pocket wheel sequence.")
	var physics_profile: Dictionary = table.get("physics_profile", {}) if typeof(table.get("physics_profile", {})) == TYPE_DICTIONARY else {}
	for physics_key in ["ball_initial_omega_min", "ball_initial_omega_max", "ball_angular_decel_min", "ball_angular_decel_max", "rotor_initial_omega_min", "rotor_initial_omega_max", "diamond_scatter_degrees", "pocket_depth", "micro_scatter"]:
		if not physics_profile.has(physics_key):
			failures.append("Roulette physics profile missing mutable attribute: %s." % physics_key)
	if (table.get("patrons", []) as Array).is_empty():
		failures.append("Roulette generated table did not include other table players.")
	if not (table.get("dealer_profile", {}) is Dictionary):
		failures.append("Roulette generated table did not include a dealer profile.")
	environment["game_states"] = {"roulette": table}
	run_state.current_environment = environment.duplicate(true)

	var surface := game.surface_state(run_state, environment, {})
	if str(surface.get("surface_renderer", "")) != "roulette":
		failures.append("Roulette surface did not route to the roulette renderer.")
	if not bool(surface.get("surface_controls_native", false)):
		failures.append("Roulette surface did not expose native table controls.")
	if not bool(surface.get("surface_animates_idle", false)):
		failures.append("Roulette surface did not request idle redraws for table life.")
	if bool(surface.get("surface_realtime_state_refresh", false)):
		failures.append("Roulette betting surface must not rebuild full realtime snapshots for idle animation.")
	var targets: Array = surface.get("bet_targets", []) as Array
	if targets.size() < 140:
		failures.append("Roulette surface did not expose a full inside/outside betting layout.")
	for target_type in ["straight", "split", "street", "corner", "six_line", "trio", "top_line", "dozen", "column", "red", "black", "odd", "even", "low", "high"]:
		if not _roulette_targets_include_type(targets, target_type):
			failures.append("Roulette betting layout missing bet type: %s." % target_type)
	var straight_17_index := _roulette_target_index(targets, "straight", "17")
	if straight_17_index < 0:
		failures.append("Roulette betting layout did not expose a straight-up 17 target.")
		return
	var harness := SurfaceHarness.new()
	harness.setup(surface)
	game.draw_surface(harness, surface, {"contract_harness": true})
	if _surface_hit_count(harness, "roulette_bet") < targets.size():
		failures.append("Roulette renderer did not create hit regions for every bet target.")
	for action_id in ["roulette_read_wheel", "roulette_chip"]:
		if not _surface_harness_has_action(harness, action_id):
			failures.append("Roulette renderer missing surface action: %s." % action_id)
	var audio: Dictionary = surface.get("surface_audio", {}) if typeof(surface.get("surface_audio", {})) == TYPE_DICTIONARY else {}
	if str(audio.get("profile_id", "")) != "roulette_table":
		failures.append("Roulette surface audio did not expose the roulette_table profile.")
	var sync: Dictionary = audio.get("state_sync", {}) if typeof(audio.get("state_sync", {})) == TYPE_DICTIONARY else {}
	if str(sync.get("method", "")) != "roulette_table_state":
		failures.append("Roulette surface audio did not expose roulette_table_state sync.")
	var blocked_surface := surface.duplicate(true)
	blocked_surface["surface_action_blocks"] = game.call("_surface_action_blocks", true)
	if not _surface_blocks_action(blocked_surface, "roulette_bet") or not _surface_blocks_action(blocked_surface, "roulette_spin"):
		failures.append("Roulette surface did not block betting/spinning during the spin animation.")

	var chip_denoms: Array = game.call("_chip_denominations", table)
	var contract_chip := 5 if chip_denoms.has(5) else int(chip_denoms[0])
	var bet_click := _check_surface_command_non_mutating(game, "roulette_bet", straight_17_index, false, {"selected_chip": contract_chip}, run_state, environment, "roulette straight bet", failures)
	var bet_ui: Dictionary = bet_click.get("ui_state", {})
	var bet_total: int = game.call("_total_wager", bet_ui.get("roulette_bets", []))
	if bet_total != contract_chip:
		failures.append("Roulette straight bet did not create a $%d wager: %s." % [contract_chip, JSON.stringify(bet_click)])
	if game.wager_cost_for_context("spin_roulette", contract_chip, run_state, environment, bet_ui) != contract_chip:
		failures.append("Roulette wager cost did not reflect chips placed on the layout.")
	var spin_surface := game.surface_state(run_state, environment, bet_ui)
	if not bool(spin_surface.get("can_spin", false)):
		failures.append("Roulette surface did not become spin-ready after a valid bet.")
	var spin_harness := SurfaceHarness.new()
	spin_harness.setup(spin_surface)
	game.draw_surface(spin_harness, spin_surface, {"contract_harness": true})
	for action_id in ["roulette_spin", "roulette_clear"]:
		if not _surface_harness_has_action(spin_harness, action_id):
			failures.append("Roulette spin-ready renderer missing surface action: %s." % action_id)
	var spin_click := _check_surface_command_non_mutating(game, "roulette_spin", 0, false, bet_ui, run_state, environment, "roulette spin command", failures)
	if str(spin_click.get("action_id", "")) != "spin_roulette" or not bool(spin_click.get("resolve", false)):
		failures.append("Roulette spin command did not resolve through the legal roulette action.")
	var before := _run_state_result_snapshot(run_state)
	var result := game.resolve_with_context("spin_roulette", contract_chip, run_state, environment, run_state.create_rng("roulette_contract_spin"), spin_click.get("ui_state", {}))
	_check_action_result_shape(result, "legal", failures)
	_check_action_result_application_contract(before, run_state, result, "roulette spin result", failures)
	if not wheel_sequence.has(str(result.get("roulette_winning_number", ""))):
		failures.append("Roulette spin landed on a number outside the table wheel sequence.")
	if (result.get("roulette_spin_trajectory", []) as Array).size() < 48:
		failures.append("Roulette spin did not publish an efficient precomputed ball trajectory.")
	var spin_physics: Dictionary = result.get("roulette_spin_physics", {}) if typeof(result.get("roulette_spin_physics", {})) == TYPE_DICTIONARY else {}
	for key in ["drop_time", "deflector_index", "settle_time", "relative_angle", "capture_energy"]:
		if not spin_physics.has(key):
			failures.append("Roulette spin physics missing field: %s." % key)
	var persisted_table: Dictionary = ((environment.get("game_states", {}) as Dictionary).get("roulette", {}) as Dictionary)
	if int(persisted_table.get("spin_count", 0)) <= 0 or (persisted_table.get("last_result", {}) as Dictionary).is_empty():
		failures.append("Roulette did not persist the resolved table spin state.")
	var result_surface := game.surface_state(run_state, environment, {})
	if str((result_surface.get("last_result", {}) as Dictionary).get("winning_number", "")) != str(result.get("roulette_winning_number", "")):
		failures.append("Roulette post-spin surface did not expose the latest winning number.")

	var read_run_state: RunState = RunStateScript.new()
	read_run_state.start_new("ROULETTE-READ-WHEEL-CONTRACT")
	read_run_state.bankroll = 1000
	var read_environment := _surface_contract_environment()
	read_environment["game_ids"] = ["roulette"]
	read_environment["economic_profile"] = {"stake_floor": 1, "stake_ceiling": 200}
	read_environment["game_states"] = {"roulette": table.duplicate(true)}
	read_run_state.current_environment = read_environment.duplicate(true)
	var read_click := _check_surface_command_non_mutating(game, "roulette_read_wheel", 0, false, {}, read_run_state, read_environment, "roulette read wheel", failures)
	if str(read_click.get("action_id", "")) != "read_wheel_bias" or bool(read_click.get("resolve", false)):
		failures.append("Roulette read-wheel command did not stage a non-immediate cheat read.")
	var read_before := _run_state_result_snapshot(read_run_state)
	var read_result := game.resolve_with_context("read_wheel_bias", 0, read_run_state, read_environment, read_run_state.create_rng("roulette_read_wheel_resolve"), read_click.get("ui_state", {}))
	_check_action_result_shape(read_result, "cheat", failures)
	_check_action_result_application_contract(read_before, read_run_state, read_result, "roulette read wheel result", failures)
	if int(read_result.get("suspicion_delta", 0)) <= 0 or (read_result.get("roulette_bias_read", {}) as Dictionary).is_empty():
		failures.append("Roulette read-wheel cheat did not add heat and expose the bias read.")

	if library != null:
		_check_premium_grand_casino_table_contract(library, "roulette", game, failures)
	_check_roulette_payout_contract(game, table, failures)


func _roulette_targets_include_type(targets: Array, target_type: String) -> bool:
	for target_value in targets:
		if typeof(target_value) == TYPE_DICTIONARY and str((target_value as Dictionary).get("type", "")) == target_type:
			return true
	return false


func _roulette_target_index(targets: Array, target_type: String, number: String) -> int:
	for i in range(targets.size()):
		if typeof(targets[i]) != TYPE_DICTIONARY:
			continue
		var target: Dictionary = targets[i]
		if str(target.get("type", "")) != target_type:
			continue
		if _string_array(target.get("numbers", [])).has(number):
			return i
	return -1


func _check_roulette_payout_contract(game: GameModule, table: Dictionary, failures: Array) -> void:
	var fixture_bets := [
		{"id": "straight_17", "type": "straight", "label": "17", "numbers": ["17"], "stake": 2, "payout": 35, "family": "inside"},
		{"id": "split_17_20", "type": "split", "label": "17/20", "numbers": ["17", "20"], "stake": 2, "payout": 17, "family": "inside"},
		{"id": "street_16_18", "type": "street", "label": "16-18", "numbers": ["16", "17", "18"], "stake": 2, "payout": 11, "family": "inside"},
		{"id": "corner_14_18", "type": "corner", "label": "14/15/17/18", "numbers": ["14", "15", "17", "18"], "stake": 2, "payout": 8, "family": "inside"},
		{"id": "six_13_18", "type": "six_line", "label": "13-18", "numbers": ["13", "14", "15", "16", "17", "18"], "stake": 2, "payout": 5, "family": "inside"},
		{"id": "dozen_13_24", "type": "dozen", "label": "2nd 12", "numbers": _range_int_strings(13, 24), "stake": 2, "payout": 2, "family": "outside"},
		{"id": "black", "type": "black", "label": "BLACK", "numbers": ["2", "4", "6", "8", "10", "11", "13", "15", "17", "20", "22", "24", "26", "28", "29", "31", "33", "35"], "stake": 2, "payout": 1, "family": "outside"},
		{"id": "red", "type": "red", "label": "RED", "numbers": ["1", "3", "5", "7", "9", "12", "14", "16", "18", "19", "21", "23", "25", "27", "30", "32", "34", "36"], "stake": 2, "payout": 1, "family": "outside"},
	]
	var settled: Array = game.call("_settle_roulette_bets", "17", fixture_bets, table)
	var expected := {
		"straight": 70,
		"split": 34,
		"street": 22,
		"corner": 16,
		"six_line": 10,
		"dozen": 4,
		"black": 2,
		"red": -2,
	}
	for result_value in settled:
		if typeof(result_value) != TYPE_DICTIONARY:
			continue
		var result: Dictionary = result_value
		var result_type := str(result.get("type", ""))
		if int(result.get("bankroll_delta", 999999)) != int(expected.get(result_type, 999999)):
			failures.append("Roulette payout for %s was %d, expected %d." % [result_type, int(result.get("bankroll_delta", 0)), int(expected.get(result_type, 0))])
	var zero_loss: Array = game.call("_settle_roulette_bets", "0", [fixture_bets[7]], table)
	if zero_loss.is_empty() or int((zero_loss[0] as Dictionary).get("bankroll_delta", 0)) != -2:
		failures.append("Roulette zero did not take a standard even-money outside bet.")
	var partage_table := table.duplicate(true)
	var partage_rules: Dictionary = table.get("rules", {}) if typeof(table.get("rules", {})) == TYPE_DICTIONARY else {}
	partage_rules = partage_rules.duplicate(true)
	partage_rules["la_partage"] = true
	partage_table["rules"] = partage_rules
	var partage_bet := {"id": "red_half", "type": "red", "label": "RED", "numbers": fixture_bets[7].get("numbers", []), "stake": 4, "payout": 1, "family": "outside"}
	var partage_loss: Array = game.call("_settle_roulette_bets", "0", [partage_bet], partage_table)
	if partage_loss.is_empty() or int((partage_loss[0] as Dictionary).get("bankroll_delta", 0)) != -2:
		failures.append("Roulette La Partage rule did not halve an even-money zero loss.")


func _range_int_strings(first: int, last: int) -> Array:
	var result: Array = []
	for value in range(first, last + 1):
		result.append(str(value))
	return result


func _check_baccarat_surface_contract(game: GameModule, failures: Array, library: ContentLibrary = null) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("BACCARAT-SURFACE-CONTRACT")
	run_state.bankroll = 1000
	var environment := _surface_contract_environment()
	environment["game_ids"] = ["baccarat"]
	environment["economic_profile"] = {"stake_floor": 20, "stake_ceiling": 200}
	var table: Dictionary = game.generate_environment_state(run_state, environment, run_state.create_rng("baccarat_contract_table"))
	if table.is_empty():
		failures.append("Baccarat did not generate table state for an environment.")
		return
	if str(table.get("schema", "")) != "baccarat_table_state":
		failures.append("Baccarat generated table state did not expose the baccarat schema.")
	if int(table.get("deck_count", 0)) != 8:
		failures.append("Baccarat did not generate an eight-deck default shoe.")
	if (table.get("shoe", []) as Array).size() <= 0:
		failures.append("Baccarat generated an empty shoe.")
	if _baccarat_dictionary_array(table.get("patrons", [])).is_empty():
		failures.append("Baccarat generated table did not include other table players.")
	if not (table.get("dealer_profile", {}) is Dictionary) or (table.get("dealer_profile", {}) as Dictionary).is_empty():
		failures.append("Baccarat generated table did not include a croupier profile.")
	var rules: Dictionary = table.get("rules", {}) if typeof(table.get("rules", {})) == TYPE_DICTIONARY else {}
	for key in ["banker_commission_rate", "tie_payout", "player_pair_payout", "banker_pair_payout", "optional_side_bet_hooks"]:
		if not rules.has(key):
			failures.append("Baccarat rules missing required field: %s." % key)
	environment["game_states"] = {"baccarat": table}
	run_state.current_environment = environment.duplicate(true)

	var surface := game.surface_state(run_state, environment, {})
	if str(surface.get("surface_renderer", "")) != "baccarat":
		failures.append("Baccarat surface did not route to the baccarat renderer.")
	if str(surface.get("surface_life", "")) != "immersive_table" or str(surface.get("surface_cast", "")) != "dealer_table":
		failures.append("Baccarat surface did not expose immersive dealer-table metadata.")
	if not bool(surface.get("surface_controls_native", false)):
		failures.append("Baccarat surface did not expose native table controls.")
	if bool(surface.get("surface_realtime_state_refresh", false)):
		failures.append("Baccarat betting surface must not rebuild full realtime snapshots for idle animation.")
	var targets := _baccarat_dictionary_array(surface.get("bet_targets", []))
	for target_id in ["player", "banker", "tie", "player_pair", "banker_pair"]:
		if _baccarat_target_index(targets, target_id) < 0:
			failures.append("Baccarat betting layout missing target: %s." % target_id)
	var harness := SurfaceHarness.new()
	harness.setup(surface)
	if not bool(game.draw_surface(harness, surface, {"contract_harness": true})):
		failures.append("Baccarat draw_surface returned false.")
	if _surface_hit_count(harness, "baccarat_bet") < 5:
		failures.append("Baccarat renderer did not create hit regions for all core bet targets.")
	for action_id in ["baccarat_chip", "baccarat_read_shoe"]:
		if not _surface_harness_has_action(harness, action_id):
			failures.append("Baccarat renderer missing surface action: %s." % action_id)
	var audio: Dictionary = surface.get("surface_audio", {}) if typeof(surface.get("surface_audio", {})) == TYPE_DICTIONARY else {}
	var sync: Dictionary = audio.get("state_sync", {}) if typeof(audio.get("state_sync", {})) == TYPE_DICTIONARY else {}
	if str(audio.get("profile_id", "")) != "baccarat_table" or str(sync.get("method", "")) != "baccarat_table_state":
		failures.append("Baccarat surface audio did not expose baccarat_table profile/sync metadata.")
	if not _surface_blocks_action_while(surface, "baccarat_bet", "baccarat_deal") or not _surface_blocks_action_while(surface, "baccarat_deal", "baccarat_deal"):
		failures.append("Baccarat surface did not block betting/dealing during the deal animation.")

	var player_index := _baccarat_target_index(targets, "player")
	var bet_click := _check_surface_command_non_mutating(game, "baccarat_bet", player_index, false, {"selected_chip": 20}, run_state, environment, "baccarat player bet", failures)
	var bet_ui: Dictionary = bet_click.get("ui_state", {})
	if int((bet_ui.get("baccarat_bets", {}) as Dictionary).get("player", 0)) != 20:
		failures.append("Baccarat player bet did not create a $20 wager.")
	if game.wager_cost_for_context("deal_baccarat", 20, run_state, environment, bet_ui) != 20:
		failures.append("Baccarat wager cost did not reflect chips placed on the layout.")
	var ready_surface := game.surface_state(run_state, environment, bet_ui)
	if not bool(ready_surface.get("can_deal", false)):
		failures.append("Baccarat surface did not become deal-ready after a valid bet.")
	var ready_harness := SurfaceHarness.new()
	ready_harness.setup(ready_surface)
	game.draw_surface(ready_harness, ready_surface, {"contract_harness": true})
	for action_id in ["baccarat_deal", "baccarat_clear"]:
		if not _surface_harness_has_action(ready_harness, action_id):
			failures.append("Baccarat deal-ready renderer missing surface action: %s." % action_id)
	var deal_click := _check_surface_command_non_mutating(game, "baccarat_deal", 0, false, bet_ui, run_state, environment, "baccarat deal command", failures)
	if str(deal_click.get("action_id", "")) != "deal_baccarat" or not bool(deal_click.get("resolve", false)):
		failures.append("Baccarat deal command did not resolve through the legal baccarat action.")
	var before := _run_state_result_snapshot(run_state)
	var result := game.resolve_with_context("deal_baccarat", 20, run_state, environment, run_state.create_rng("baccarat_contract_deal"), deal_click.get("ui_state", {}))
	_check_action_result_shape(result, "legal", failures)
	_check_action_result_application_contract(before, run_state, result, "baccarat deal result", failures)
	if not ["player", "banker", "tie"].has(str(result.get("baccarat_winner", ""))):
		failures.append("Baccarat resolve produced an invalid winner.")
	if (result.get("baccarat_animation_events", []) as Array).size() < 4:
		failures.append("Baccarat resolve did not publish precomputed deal animation events.")
	var persisted_table: Dictionary = ((environment.get("game_states", {}) as Dictionary).get("baccarat", {}) as Dictionary)
	if int(persisted_table.get("hands_played", 0)) <= 0 or (persisted_table.get("last_result", {}) as Dictionary).is_empty():
		failures.append("Baccarat did not persist the resolved table hand state.")

	var read_run_state: RunState = RunStateScript.new()
	read_run_state.start_new("BACCARAT-READ-SHOE-CONTRACT")
	read_run_state.bankroll = 1000
	var read_environment := _surface_contract_environment()
	read_environment["game_ids"] = ["baccarat"]
	read_environment["economic_profile"] = {"stake_floor": 20, "stake_ceiling": 200}
	read_environment["game_states"] = {"baccarat": table.duplicate(true)}
	read_run_state.current_environment = read_environment.duplicate(true)
	var read_click := _check_surface_command_non_mutating(game, "baccarat_read_shoe", 0, false, {}, read_run_state, read_environment, "baccarat read shoe", failures)
	if str(read_click.get("action_id", "")) != "read_baccarat_shoe" or bool(read_click.get("resolve", false)):
		failures.append("Baccarat read-shoe command did not stage a non-immediate cheat read.")
	var read_before := _run_state_result_snapshot(read_run_state)
	var read_result := game.resolve_with_context("read_baccarat_shoe", 0, read_run_state, read_environment, read_run_state.create_rng("baccarat_read_shoe_resolve"), read_click.get("ui_state", {}))
	_check_action_result_shape(read_result, "cheat", failures)
	_check_action_result_application_contract(read_before, read_run_state, read_result, "baccarat read shoe result", failures)
	if int(read_result.get("suspicion_delta", 0)) <= 0 or (read_result.get("baccarat_shoe_read", {}) as Dictionary).is_empty():
		failures.append("Baccarat read-shoe cheat did not add heat and expose shoe-read context.")

	if library != null:
		_check_premium_grand_casino_table_contract(library, "baccarat", game, failures)
	_check_baccarat_rules_contract(game, failures)
	_check_baccarat_payout_contract(game, failures)


func _baccarat_target_index(targets: Array, target_id: String) -> int:
	for i in range(targets.size()):
		if typeof(targets[i]) == TYPE_DICTIONARY and str((targets[i] as Dictionary).get("id", "")) == target_id:
			return i
	return -1


func _baccarat_dictionary_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value:
		if typeof(entry) == TYPE_DICTIONARY:
			result.append((entry as Dictionary).duplicate(true))
	return result


func _check_baccarat_rules_contract(game: GameModule, failures: Array) -> void:
	if int(game.call("_baccarat_card_value", {"rank": 14, "suit": 0})) != 1:
		failures.append("Baccarat Ace card value was not 1.")
	if int(game.call("_baccarat_card_value", {"rank": 9, "suit": 0})) != 9:
		failures.append("Baccarat 9 card value was not 9.")
	if int(game.call("_baccarat_card_value", {"rank": 13, "suit": 0})) != 0:
		failures.append("Baccarat face-card value was not 0.")
	if int(game.call("_hand_total", [{"rank": 14}, {"rank": 9}, {"rank": 8}])) != 8:
		failures.append("Baccarat hand total did not use modulo 10.")
	if not bool(game.call("_is_natural", 8, 4)) or not bool(game.call("_is_natural", 2, 9)) or bool(game.call("_is_natural", 7, 7)):
		failures.append("Baccarat natural 8/9 detection failed.")
	if not bool(game.call("_player_should_draw", 5)) or bool(game.call("_player_should_draw", 6)):
		failures.append("Baccarat Player draw rule failed.")
	var matrix := [
		[3, 8, false, false],
		[3, 7, false, true],
		[4, 1, false, false],
		[4, 2, false, true],
		[5, 3, false, false],
		[5, 4, false, true],
		[6, 5, false, false],
		[6, 6, false, true],
		[5, -1, true, true],
		[6, -1, true, false],
	]
	for row in matrix:
		var actual := bool(game.call("_banker_should_draw", int(row[0]), int(row[1]), bool(row[2])))
		if actual != bool(row[3]):
			failures.append("Baccarat Banker third-card matrix failed for banker %d, player third %d, stood %s." % [int(row[0]), int(row[1]), str(row[2])])


func _check_baccarat_payout_contract(game: GameModule, failures: Array) -> void:
	var rules := {
		"player_payout": 1,
		"banker_payout": 1,
		"banker_commission_rate": 0.05,
		"tie_payout": 8,
		"player_pair_payout": 11,
		"banker_pair_payout": 11,
	}
	var player_hand := {
		"winner": "player",
		"player_pair": true,
		"banker_pair": false,
	}
	var player_settlement: Dictionary = game.call("_settle_baccarat_bets", {"player": 10, "banker": 10, "tie": 10, "player_pair": 10, "banker_pair": 10}, player_hand, rules)
	if int(player_settlement.get("bankroll_delta", 999)) != 90:
		failures.append("Baccarat Player/pair settlement expected +90, got %+d." % int(player_settlement.get("bankroll_delta", 0)))
	var banker_hand := {
		"winner": "banker",
		"player_pair": false,
		"banker_pair": true,
	}
	var banker_settlement: Dictionary = game.call("_settle_baccarat_bets", {"banker": 20, "banker_pair": 10}, banker_hand, rules)
	if int(banker_settlement.get("bankroll_delta", 999)) != 129 or int(banker_settlement.get("commission", 0)) != 1:
		failures.append("Baccarat Banker commission settlement expected +129 with $1 commission, got %+d and commission $%d." % [int(banker_settlement.get("bankroll_delta", 0)), int(banker_settlement.get("commission", 0))])
	var tie_hand := {
		"winner": "tie",
		"player_pair": false,
		"banker_pair": false,
	}
	var tie_settlement: Dictionary = game.call("_settle_baccarat_bets", {"player": 10, "banker": 10, "tie": 10}, tie_hand, rules)
	if int(tie_settlement.get("bankroll_delta", 999)) != 80:
		failures.append("Baccarat Tie settlement expected main pushes and +80 tie win, got %+d." % int(tie_settlement.get("bankroll_delta", 0)))


func _check_blackjack_surface_contract(game: GameModule, failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("BLACKJACK-SURFACE-CONTRACT")
	var environment := _surface_contract_environment()
	var generated_state := game.generate_environment_state(run_state, environment, run_state.create_rng("blackjack_contract_table"))
	if generated_state.is_empty():
		failures.append("Blackjack did not generate table state for an environment.")
	var generated_deck_count := int(generated_state.get("deck_count", 0))
	var generated_shoe: Array = generated_state.get("shoe", []) as Array
	if generated_deck_count <= 0 or generated_shoe.size() != generated_deck_count * 52:
		failures.append("Blackjack generated table did not create a shoe from its declared deck count.")
	var generated_composition: Dictionary = generated_state.get("shoe_composition", {}) if typeof(generated_state.get("shoe_composition", {})) == TYPE_DICTIONARY else {}
	if int(generated_composition.get("total", -1)) != generated_shoe.size():
		failures.append("Blackjack generated shoe composition did not match the actual remaining shoe.")
	if str(generated_state.get("shoe_label", "")).find(str(generated_deck_count)) < 0 or str(generated_state.get("count_efficiency", "")).is_empty():
		failures.append("Blackjack generated table did not describe the shoe deck count and count efficiency.")
	var generated_side_bets: Array = generated_state.get("side_bets", []) as Array
	if generated_side_bets.size() > 2:
		failures.append("Blackjack generated more than two possible side bets.")
	environment["game_states"] = {"blackjack": generated_state}
	var surface := game.surface_state(run_state, environment, {})
	if str(surface.get("surface_renderer", "")) != "blackjack":
		failures.append("Blackjack surface did not route to the blackjack renderer.")
	if not bool(surface.get("surface_controls_native", false)):
		failures.append("Blackjack surface did not expose native surface controls.")
	if not bool(surface.get("can_deal", false)):
		failures.append("Blackjack surface did not start in a deal-ready betting phase.")
	if not bool(surface.get("surface_animates_idle", false)):
		failures.append("Blackjack betting surface did not request idle redraws for animated table life.")
	if bool(surface.get("surface_realtime_state_refresh", false)):
		failures.append("Blackjack betting surface must not rebuild full realtime snapshots for idle table animation.")
	if (surface.get("side_bets_available", []) as Array).is_empty():
		failures.append("Blackjack generated table did not expose side bets.")
	if (surface.get("side_bets_available", []) as Array).size() > 2:
		failures.append("Blackjack surface exposed more than two possible side bets.")
	for side_bet_value in (surface.get("side_bets_available", []) as Array):
		if typeof(side_bet_value) != TYPE_DICTIONARY:
			continue
		var side_bet: Dictionary = side_bet_value
		if (side_bet.get("rules", []) as Array).is_empty() or (side_bet.get("payouts", []) as Array).is_empty():
			failures.append("Blackjack side bet did not expose rule and payout text for the highlight overlay.")
	if int(surface.get("total_wager_cost", 0)) <= 0:
		failures.append("Blackjack surface did not expose total wager cost.")
	var side_bet_hover_harness := SurfaceHarness.new()
	side_bet_hover_harness.setup(surface)
	side_bet_hover_harness.hovered_action = "blackjack_side_bet"
	side_bet_hover_harness.hovered_index = 0
	game.draw_surface(side_bet_hover_harness, surface, {"contract_harness": true})
	var side_bet_overlay_found := false
	for label_value in side_bet_hover_harness.labels:
		if str(label_value).find("SIDE BET RULES") >= 0:
			side_bet_overlay_found = true
			break
	if not side_bet_overlay_found:
		failures.append("Blackjack side-bet hover did not draw the rules overlay.")
	var side_bet_active_surface: Dictionary = surface.duplicate(true)
	var active_surface_bets: Array = side_bet_active_surface.get("side_bets_available", []) as Array
	if not active_surface_bets.is_empty() and typeof(active_surface_bets[0]) == TYPE_DICTIONARY:
		side_bet_active_surface["side_bets_active"] = [str((active_surface_bets[0] as Dictionary).get("id", ""))]
		var side_bet_active_harness := SurfaceHarness.new()
		side_bet_active_harness.setup(side_bet_active_surface)
		game.draw_surface(side_bet_active_harness, side_bet_active_surface, {"contract_harness": true})
		for label_value in side_bet_active_harness.labels:
			if str(label_value).find("SIDE BET RULES") >= 0:
				failures.append("Blackjack side-bet rules overlay stayed visible from active selection without hover.")
				break
	var deal_click := game.surface_action_command("blackjack_deal", 0, false, {}, run_state, environment)
	var deal_ui: Dictionary = deal_click.get("ui_state", {})
	if (deal_ui.get("player_hands", []) as Array).is_empty():
		failures.append("Blackjack deal did not create an animated table hand.")
	var deal_remaining_shoe: Array = deal_ui.get("shoe", []) as Array
	if not deal_remaining_shoe.is_empty():
		failures.append("Blackjack deal kept a materialized shoe in transient UI state instead of the compact consumed-card cursor.")
	if int(deal_ui.get("cards_consumed", 0)) <= 0 or int(deal_ui.get("shoe_remaining", generated_shoe.size())) >= generated_shoe.size():
		failures.append("Blackjack deal did not advance the compact shoe cursor.")
	var dealt_surface := game.surface_state(run_state, environment, deal_ui)
	if int(dealt_surface.get("blackjack_total", 0)) <= 0:
		failures.append("Blackjack dealt surface did not expose a visible hand total.")
	var deal_events: Array = dealt_surface.get("deal_animation_events", []) as Array
	if deal_events.size() < 4:
		failures.append("Blackjack initial deal did not expose card-by-card animation events.")
	else:
		var first_deal_event: Dictionary = deal_events[0] if typeof(deal_events[0]) == TYPE_DICTIONARY else {}
		if str(first_deal_event.get("zone", "")) != "player" or not first_deal_event.has("from") or not first_deal_event.has("to"):
			failures.append("Blackjack deal animation events did not include normalized card targets.")
	var dealer_focus: Dictionary = dealt_surface.get("dealer_focus", {}) if typeof(dealt_surface.get("dealer_focus", {})) == TYPE_DICTIONARY else {}
	if not dealer_focus.has("gaze_phase") or not dealer_focus.has("peek_danger") or not dealer_focus.has("scan_phase") or not dealer_focus.has("watching_player") or not dealer_focus.has("peek_window_open"):
		failures.append("Blackjack dealer focus did not expose visual read timing fields.")
	if bool(dealt_surface.get("surface_realtime_state_refresh", false)):
		failures.append("Blackjack dealt surface must not rebuild full realtime snapshots for live table focus.")
	var focus_runtime: Dictionary = dealt_surface.get("dealer_focus_runtime", {}) if typeof(dealt_surface.get("dealer_focus_runtime", {})) == TYPE_DICTIONARY else {}
	if focus_runtime.is_empty():
		failures.append("Blackjack dealt surface did not expose lightweight dealer focus runtime data.")
	var surface_patrons: Array = dealt_surface.get("patrons", []) as Array
	if surface_patrons.is_empty():
		failures.append("Blackjack dealt surface did not expose table patrons.")
	else:
		var first_patron: Dictionary = surface_patrons[0] if typeof(surface_patrons[0]) == TYPE_DICTIONARY else {}
		if not first_patron.has("behavior_phase") or not first_patron.has("tell"):
			failures.append("Blackjack patron surface data did not expose animated behavior tells.")
	_check_surface_command_non_mutating(game, "blackjack_hit", 0, false, deal_ui, run_state, environment, "blackjack hit", failures)
	var first_click := game.surface_action_command("blackjack_stand", 0, false, deal_ui, run_state, environment)
	if str(first_click.get("action_kind", "")) != "legal":
		failures.append("Blackjack stand did not map to a legal action.")
	if not bool(first_click.get("resolve", false)):
		failures.append("Blackjack stand did not immediately resolve a completed one-hand round.")
	if bool(first_click.get("preserve_surface_ui_state", false)):
		failures.append("Blackjack stand preserved stale completed-hand UI state after resolution.")
	var cheat_click := game.surface_action_command("blackjack_count_toggle", 0, false, deal_ui, run_state, environment)
	if str(cheat_click.get("action_id", "")) == "count_cards" or bool(cheat_click.get("resolve", false)):
		failures.append("Blackjack count opened a modal/resolve action instead of starting the live overlay.")
	var count_state: Dictionary = cheat_click.get("ui_state", {})
	var count_table: Dictionary = ((environment.get("game_states", {}) as Dictionary).get("blackjack", {}) as Dictionary)
	if not bool(count_table.get("counting_enabled", false)):
		failures.append("Blackjack count toggle did not persist counting-enabled state on the table.")
	var count_challenge: Dictionary = count_state.get("count_challenge", {})
	if (count_challenge.get("cards", []) as Array).is_empty():
		failures.append("Blackjack count did not create a visible-card count challenge.")
	if not count_challenge.has("icons") or not count_challenge.has("dealer_attention_risk") or not count_challenge.has("target_delta"):
		failures.append("Blackjack count challenge did not expose pulse-icon timing and attention fields.")
	var answer_state: Dictionary = count_state
	var count_icons: Array = count_challenge.get("icons", []) as Array
	if count_icons.is_empty():
		failures.append("Blackjack count did not create count pulse icons.")
	var countable_cards := 0
	for count_card_value in (count_challenge.get("cards", []) as Array):
		if typeof(count_card_value) == TYPE_DICTIONARY and _blackjack_test_count_delta([count_card_value]) != 0:
			countable_cards += 1
	if count_icons.size() != countable_cards:
		failures.append("Blackjack count created pulses for neutral cards or missed countable cards.")
	var test_now := Time.get_ticks_msec()
	for i in range(count_icons.size()):
		if typeof(count_icons[i]) != TYPE_DICTIONARY:
			continue
		var icon: Dictionary = count_icons[i]
		if not icon.has("spawn_msec") or not icon.has("duration_msec") or not icon.has("count_value"):
			failures.append("Blackjack count pulse icon did not expose a timing target.")
		if int(icon.get("count_value", 0)) == 0:
			failures.append("Blackjack count created a clickable zero-value pulse.")
		icon["spawn_msec"] = test_now - 10
		icon["duration_msec"] = 5000
		count_icons[i] = icon
	count_challenge["icons"] = count_icons
	answer_state["count_challenge"] = count_challenge
	for i in range(count_icons.size()):
		var answer_click := game.surface_action_command("blackjack_count_icon", i, false, answer_state, run_state, environment)
		answer_state = answer_click.get("ui_state", {})
	var answered_resolved_times: Dictionary = (answer_state.get("count_challenge", {}) as Dictionary).get("resolved_icon_msec", {}) if typeof((answer_state.get("count_challenge", {}) as Dictionary).get("resolved_icon_msec", {})) == TYPE_DICTIONARY else {}
	if answered_resolved_times.size() < count_icons.size():
		failures.append("Blackjack clicked count pulses did not receive fade timestamps.")
	if bool(answer_state.get("count_answered", false)):
		failures.append("Blackjack count pulse hits finalized a live count instead of keeping the overlay active during play.")
	var answered_challenge: Dictionary = answer_state.get("count_challenge", {})
	if int(answered_challenge.get("dealer_attention_risk", 0)) != int(count_challenge.get("dealer_attention_risk", 0)):
		failures.append("Blackjack successful count pulse hits raised dealer suspicion.")
	var clean_count_result := game.resolve_with_context("count_cards", 1, run_state, environment, run_state.create_rng("blackjack_clean_count_contract"), answer_state)
	if int(clean_count_result.get("suspicion_delta", 0)) != 0:
		failures.append("Blackjack clean live count produced suspicion heat.")
	var miss_state: Dictionary = count_state.duplicate(true)
	var miss_challenge: Dictionary = miss_state.get("count_challenge", {})
	var miss_icons: Array = miss_challenge.get("icons", []) as Array
	if not miss_icons.is_empty() and typeof(miss_icons[0]) == TYPE_DICTIONARY:
		var miss_icon: Dictionary = miss_icons[0]
		miss_icon["spawn_msec"] = Time.get_ticks_msec() - 5000
		miss_icon["duration_msec"] = 1
		miss_icons[0] = miss_icon
		miss_challenge["icons"] = miss_icons
		miss_state["count_challenge"] = miss_challenge
		if not game.surface_needs_auto_tick(miss_state, run_state, environment):
			failures.append("Blackjack live count did not request auto tick when a count symbol expired.")
		var miss_tick := game.surface_auto_action_command(miss_state, run_state, environment, {})
		var tick_state: Dictionary = miss_tick.get("ui_state", {})
		var tick_challenge: Dictionary = tick_state.get("count_challenge", {})
		if (_string_array(tick_challenge.get("missed_icons", []))).is_empty():
			failures.append("Blackjack live count auto tick did not persist missed count symbols.")
	var watched_peek_run_state: RunState = RunStateScript.new()
	watched_peek_run_state.start_new("BLACKJACK-WATCHED-PEEK-CONTRACT")
	var watched_peek_environment := _surface_contract_environment()
	var watched_peek_table := generated_state.duplicate(true)
	watched_peek_table["dealer_profile"] = {"attention_base": 100, "gaze_speed": 95, "blink_offset": 0, "tell": "locks onto your hands"}
	watched_peek_table["patrons"] = []
	watched_peek_table["side_bets"] = []
	watched_peek_environment["game_states"] = {"blackjack": watched_peek_table}
	watched_peek_run_state.current_environment = watched_peek_environment.duplicate(true)
	var watched_deal := game.surface_action_command("blackjack_deal", 0, false, {"selected_stake": 5}, watched_peek_run_state, watched_peek_environment)
	var watched_peek := game.surface_action_command("blackjack_peek", 0, false, watched_deal.get("ui_state", {}), watched_peek_run_state, watched_peek_environment)
	var watched_peek_ui: Dictionary = watched_peek.get("ui_state", {})
	if str(watched_peek.get("action_id", "")) != "peek_hole_card" or not bool(watched_peek.get("resolve", false)):
		failures.append("Blackjack watched peek did not resolve as an immediate high-risk cheat.")
	if not bool(watched_peek_ui.get("peek_caught_watching", false)) or bool(watched_peek_ui.get("dealer_hole_visible", false)):
		failures.append("Blackjack watched peek exposed the hole card instead of flagging the dealer confrontation.")
	var watched_peek_result := game.resolve_with_context("peek_hole_card", 0, watched_peek_run_state, watched_peek_environment, watched_peek_run_state.create_rng("blackjack_watched_peek_resolve"), watched_peek_ui)
	if not bool(watched_peek_result.get("blackjack_table_barred", false)):
		failures.append("Blackjack watched peek did not bar the player from the table.")
	if int(watched_peek_result.get("blackjack_confiscated_bet", 0)) <= 0 or int(watched_peek_result.get("bankroll_delta", 0)) >= 0:
		failures.append("Blackjack watched peek did not confiscate the current wager.")
	if int(watched_peek_result.get("suspicion_delta", 0)) < 60 or int(watched_peek_result.get("suspicion_delta", 0)) > 80:
		failures.append("Blackjack watched peek did not add the requested 60-80 local heat.")
	if watched_peek_run_state.run_status != RunState.RUN_STATUS_ACTIVE:
		failures.append("Blackjack watched peek ended the run instead of leaving other games playable.")
	var barred_table: Dictionary = ((watched_peek_environment.get("game_states", {}) as Dictionary).get("blackjack", {}) as Dictionary)
	if not bool(barred_table.get("barred", false)):
		failures.append("Blackjack watched peek did not persist the barred table state.")
	if not game.legal_actions(watched_peek_run_state, watched_peek_environment).is_empty() or not game.cheat_actions(watched_peek_run_state, watched_peek_environment).is_empty():
		failures.append("Blackjack barred table still exposed normal blackjack actions.")
	if game.wager_cost_for_context("play_basic", 5, watched_peek_run_state, watched_peek_environment, watched_peek_ui) != 0:
		failures.append("Blackjack barred table still reported a wager cost.")
	var barred_surface := game.surface_state(watched_peek_run_state, watched_peek_environment, {})
	if not bool(barred_surface.get("table_barred", false)) or bool(barred_surface.get("can_deal", true)) or bool(barred_surface.get("peek_available", true)):
		failures.append("Blackjack barred surface still exposed live table controls.")
	var barred_object_state := game.environment_object_state(watched_peek_run_state, watched_peek_environment)
	if str((barred_object_state.get("visual_state", {}) as Dictionary).get("status", "")) != "barred":
		failures.append("Blackjack barred table did not publish a barred environment object status.")
	var distract_click := game.surface_action_command("blackjack_distraction", 0, false, deal_ui, run_state, environment)
	var peek_click := game.surface_action_command("blackjack_peek", 0, false, distract_click.get("ui_state", {}), run_state, environment)
	if str(peek_click.get("action_kind", "")) != "cheat" or not bool((peek_click.get("ui_state", {}) as Dictionary).get("dealer_hole_visible", false)):
		failures.append("Blackjack peek did not expose the dealer hole card after a distraction.")
	var repeat_peek := game.surface_action_command("blackjack_peek", 0, false, peek_click.get("ui_state", {}), run_state, environment)
	if str(repeat_peek.get("action_id", "")) == "peek_hole_card":
		failures.append("Blackjack peek allowed a repeated hole-card cheat action.")
	var strategy_run_state: RunState = RunStateScript.new()
	strategy_run_state.start_new("BLACKJACK-STRATEGY-DEVIATION-CONTRACT")
	var strategy_environment := _surface_contract_environment()
	var strategy_table := generated_state.duplicate(true)
	strategy_table["shoe_cursor"] = 0
	strategy_table["patrons"] = []
	strategy_table["side_bets"] = []
	strategy_table["dealer_profile"] = {"attention_base": 10, "gaze_speed": 95, "blink_offset": 0, "tell": "tracks perfect deviations", "strategy_scrutiny": 18, "strategy_threshold": 2, "strategy_response": "both"}
	strategy_table["distractions"] = [{"id": "test_window", "label": "Test Window", "summary": "safe peek", "duration_msec": 4000, "cover": 20, "noise": 0}]
	strategy_table["shoe"] = [
		{"rank": 10, "suit": 0}, {"rank": 10, "suit": 1}, {"rank": 7, "suit": 2}, {"rank": 10, "suit": 3},
		{"rank": 2, "suit": 0}, {"rank": 5, "suit": 1}, {"rank": 6, "suit": 2}, {"rank": 8, "suit": 3}
	]
	strategy_environment["game_states"] = {"blackjack": strategy_table}
	var strategy_deal := game.surface_action_command("blackjack_deal", 0, false, {"selected_stake": 5}, strategy_run_state, strategy_environment)
	var strategy_distraction := game.surface_action_command("blackjack_distraction", 0, false, strategy_deal.get("ui_state", {}), strategy_run_state, strategy_environment)
	var strategy_peek := game.surface_action_command("blackjack_peek", 0, false, strategy_distraction.get("ui_state", {}), strategy_run_state, strategy_environment)
	var strategy_hit := game.surface_action_command("blackjack_hit", 0, false, strategy_peek.get("ui_state", {}), strategy_run_state, strategy_environment)
	var strategy_hit_ui: Dictionary = strategy_hit.get("ui_state", {})
	if not bool(strategy_hit_ui.get("strategy_confronted", false)) or (strategy_hit_ui.get("strategy_deviation_events", []) as Array).is_empty():
		failures.append("Blackjack did not flag a beneficial off-book hit after a cheated dealer peek.")
	var strategy_focus_surface := game.surface_state(strategy_run_state, strategy_environment, strategy_hit_ui)
	if int((strategy_focus_surface.get("dealer_focus", {}) as Dictionary).get("strategy_pressure", 0)) <= 0:
		failures.append("Blackjack strategy deviation did not increase dealer watch pressure during the hand.")
	var strategy_stand := game.surface_action_command("blackjack_stand", 0, false, strategy_hit_ui, strategy_run_state, strategy_environment)
	var strategy_result := game.resolve_with_context("play_basic", 5, strategy_run_state, strategy_environment, strategy_run_state.create_rng("blackjack_strategy_deviation_resolve"), strategy_stand.get("ui_state", {}))
	if not bool(strategy_result.get("blackjack_strategy_confronted", false)) or int(strategy_result.get("suspicion_delta", 0)) <= 0:
		failures.append("Blackjack strategy deviation confrontation did not resolve into heat.")
	var strategy_after_table: Dictionary = ((strategy_environment.get("game_states", {}) as Dictionary).get("blackjack", {}) as Dictionary)
	if int(strategy_after_table.get("strategy_watch_pressure", 0)) <= 0:
		failures.append("Blackjack strategy deviation did not persist dealer watch pressure on the table.")
	var triple_distraction_environment := _surface_contract_environment()
	var triple_distraction_table := generated_state.duplicate(true)
	triple_distraction_table["distractions"] = [
		{"id": "first", "label": "First", "summary": "test", "duration_msec": 2400, "cover": 4, "noise": 1},
		{"id": "second", "label": "Second", "summary": "test", "duration_msec": 2400, "cover": 4, "noise": 1},
		{"id": "third", "label": "Third", "summary": "test", "duration_msec": 2400, "cover": 4, "noise": 1},
	]
	triple_distraction_environment["game_states"] = {"blackjack": triple_distraction_table}
	var third_distraction := game.surface_action_command("blackjack_distraction", 2, false, {}, run_state, triple_distraction_environment)
	if not bool(third_distraction.get("handled", false)) or str((third_distraction.get("ui_state", {}) as Dictionary).get("dealer_distraction_id", "")) != "third":
		failures.append("Blackjack did not handle the third generated table distraction.")

	var bust_run_state: RunState = RunStateScript.new()
	bust_run_state.start_new("BLACKJACK-BUST-CONTRACT")
	var bust_environment := _surface_contract_environment()
	var bust_table := generated_state.duplicate(true)
	bust_table["shoe_cursor"] = 0
	bust_table["patrons"] = []
	bust_table["side_bets"] = []
	bust_table["rules"] = {"dealer_hits_soft_17": false, "double_after_split": true, "split_aces_one_card": true, "max_split_hands": 4}
	bust_table["shoe"] = [
		{"rank": 10, "suit": 0}, {"rank": 9, "suit": 2}, {"rank": 6, "suit": 1}, {"rank": 7, "suit": 3},
		{"rank": 10, "suit": 2}, {"rank": 5, "suit": 1}, {"rank": 4, "suit": 0}, {"rank": 3, "suit": 2}
	]
	bust_environment["game_states"] = {"blackjack": bust_table}
	var bust_deal := game.surface_action_command("blackjack_deal", 0, false, {}, bust_run_state, bust_environment)
	var bust_ui: Dictionary = bust_deal.get("ui_state", {})
	var bust_hit := game.surface_action_command("blackjack_hit", 0, false, bust_ui, bust_run_state, bust_environment)
	if not bool(bust_hit.get("resolve", false)):
		failures.append("Blackjack bust hit did not auto-resolve the completed busted hand.")
	if bool(bust_hit.get("preserve_surface_ui_state", false)):
		failures.append("Blackjack bust hit preserved stale busted-hand UI state after resolution.")
	bust_ui = bust_hit.get("ui_state", {})
	var bust_surface := game.surface_state(bust_run_state, bust_environment, bust_ui)
	if bool(bust_surface.get("can_hit", true)) or bool(bust_surface.get("can_stand", true)):
		failures.append("Blackjack busted hand still exposed hit or stand controls.")
	if str(bust_surface.get("table_notice", "")).to_lower().find("bust") < 0:
		failures.append("Blackjack busted hand did not expose a clear bust table notice.")
	var bust_result := game.resolve_with_context("play_basic", 5, bust_run_state, bust_environment, bust_run_state.create_rng("blackjack_bust_resolve"), bust_ui)
	var bust_hands: Array = bust_result.get("blackjack_hand_results", []) as Array
	if bust_hands.is_empty() or str((bust_hands[0] as Dictionary).get("outcome", "")) != "bust":
		failures.append("Blackjack bust resolve did not settle the hand as a bust.")

	var natural_run_state: RunState = RunStateScript.new()
	natural_run_state.start_new("BLACKJACK-NATURAL-CONTRACT")
	var natural_environment := _surface_contract_environment()
	var natural_table := generated_state.duplicate(true)
	natural_table["shoe_cursor"] = 0
	natural_table["patrons"] = []
	natural_table["side_bets"] = []
	natural_table["rules"] = {"dealer_hits_soft_17": false, "double_after_split": true, "split_aces_one_card": true, "max_split_hands": 4, "late_surrender": true}
	natural_table["shoe"] = [
		{"rank": 14, "suit": 0}, {"rank": 9, "suit": 2}, {"rank": 13, "suit": 1}, {"rank": 7, "suit": 3},
		{"rank": 5, "suit": 0}, {"rank": 6, "suit": 1}, {"rank": 8, "suit": 2}, {"rank": 4, "suit": 3}
	]
	natural_environment["game_states"] = {"blackjack": natural_table}
	var natural_deal := game.surface_action_command("blackjack_deal", 0, false, {"selected_stake": 5}, natural_run_state, natural_environment)
	var natural_ui: Dictionary = natural_deal.get("ui_state", {})
	var natural_settle := game.surface_action_command("blackjack_deal", 0, false, natural_ui, natural_run_state, natural_environment)
	natural_ui = natural_settle.get("ui_state", {})
	var natural_result := game.resolve_with_context("play_basic", 5, natural_run_state, natural_environment, natural_run_state.create_rng("blackjack_natural_resolve"), natural_ui)
	var natural_hands: Array = natural_result.get("blackjack_hand_results", []) as Array
	if natural_hands.is_empty() or str((natural_hands[0] as Dictionary).get("outcome", "")) != "blackjack":
		failures.append("Blackjack natural did not settle as a 3:2 blackjack.")
	if (natural_result.get("blackjack_dealer", []) as Array).size() < 2:
		failures.append("Blackjack natural did not preserve the dealer showdown cards.")
	if int(natural_result.get("suspicion_delta", 0)) != 0 or bool(natural_result.get("blackjack_cheat_caught", false)):
		failures.append("Blackjack legal settlement reveal was incorrectly treated as hole-card cheating.")
	var natural_post_surface := game.surface_state(natural_run_state, natural_environment, {})
	var natural_last_result: Dictionary = natural_post_surface.get("last_result", {})
	if (natural_last_result.get("player_hands", []) as Array).is_empty() or (natural_last_result.get("dealer_cards", []) as Array).is_empty():
		failures.append("Blackjack settlement payload did not preserve final showdown cards.")
	if str(natural_last_result.get("payout_animation_id", "")).is_empty():
		failures.append("Blackjack settlement payload did not expose a payout animation id.")
	if not bool(natural_post_surface.get("showdown_active", false)) or (natural_post_surface.get("showdown_player_hands", []) as Array).is_empty():
		failures.append("Blackjack post-settle surface did not expose the resolved showdown.")
	if str(natural_post_surface.get("table_notice", "")).find("Dealer") < 0:
		failures.append("Blackjack post-settle notice did not summarize the dealer-vs-player result.")
	var payout_channel_found := false
	for channel_value in natural_post_surface.get("surface_animation_channels", []):
		if typeof(channel_value) == TYPE_DICTIONARY and str((channel_value as Dictionary).get("id", "")) == "blackjack_payout":
			payout_channel_found = not str((channel_value as Dictionary).get("active_id", "")).is_empty()
	if not payout_channel_found:
		failures.append("Blackjack post-settle surface did not activate the payout animation channel.")

	var surrender_run_state: RunState = RunStateScript.new()
	surrender_run_state.start_new("BLACKJACK-SURRENDER-CONTRACT")
	var surrender_environment := _surface_contract_environment()
	var surrender_table := generated_state.duplicate(true)
	surrender_table["shoe_cursor"] = 0
	surrender_table["patrons"] = []
	surrender_table["side_bets"] = []
	surrender_table["rules"] = {"dealer_hits_soft_17": false, "double_after_split": true, "split_aces_one_card": true, "max_split_hands": 4, "late_surrender": true}
	surrender_table["shoe"] = [
		{"rank": 10, "suit": 0}, {"rank": 9, "suit": 2}, {"rank": 6, "suit": 1}, {"rank": 7, "suit": 3},
		{"rank": 5, "suit": 0}, {"rank": 8, "suit": 1}, {"rank": 4, "suit": 2}, {"rank": 3, "suit": 3}
	]
	surrender_environment["game_states"] = {"blackjack": surrender_table}
	var surrender_deal := game.surface_action_command("blackjack_deal", 0, false, {"selected_stake": 5}, surrender_run_state, surrender_environment)
	var surrender_ui: Dictionary = surrender_deal.get("ui_state", {})
	var surrender_surface := game.surface_state(surrender_run_state, surrender_environment, surrender_ui)
	if not bool(surrender_surface.get("can_surrender", false)):
		failures.append("Blackjack did not expose late surrender on an eligible opening hand.")
	var surrender_click := game.surface_action_command("blackjack_surrender", 0, false, surrender_ui, surrender_run_state, surrender_environment)
	if not bool(surrender_click.get("resolve", false)):
		failures.append("Blackjack surrender did not immediately resolve the surrendered hand.")
	surrender_ui = surrender_click.get("ui_state", {})
	var surrender_result := game.resolve_with_context("play_basic", 5, surrender_run_state, surrender_environment, surrender_run_state.create_rng("blackjack_surrender_resolve"), surrender_ui)
	var surrender_hands: Array = surrender_result.get("blackjack_hand_results", []) as Array
	if surrender_hands.is_empty() or str((surrender_hands[0] as Dictionary).get("outcome", "")) != "surrender" or int((surrender_hands[0] as Dictionary).get("bankroll_delta", 0)) != -3:
		failures.append("Blackjack surrender did not settle as a half-wager loss.")
	if (surrender_result.get("blackjack_dealer", []) as Array).size() != 2:
		failures.append("Blackjack surrender incorrectly made the dealer draw extra cards.")

	var marked_surrender_run_state: RunState = RunStateScript.new()
	marked_surrender_run_state.start_new("BLACKJACK-MARKED-LEGAL-LOSS")
	marked_surrender_run_state.add_item("marked_cards")
	var marked_surrender_environment := _surface_contract_environment()
	var marked_surrender_table := generated_state.duplicate(true)
	marked_surrender_table["shoe_cursor"] = 0
	marked_surrender_table["patrons"] = []
	marked_surrender_table["side_bets"] = []
	marked_surrender_table["rules"] = {"dealer_hits_soft_17": false, "double_after_split": true, "split_aces_one_card": true, "max_split_hands": 4, "late_surrender": true}
	marked_surrender_table["shoe"] = [
		{"rank": 10, "suit": 0}, {"rank": 9, "suit": 2}, {"rank": 6, "suit": 1}, {"rank": 7, "suit": 3},
		{"rank": 5, "suit": 0}, {"rank": 8, "suit": 1}, {"rank": 4, "suit": 2}, {"rank": 3, "suit": 3}
	]
	marked_surrender_environment["game_states"] = {"blackjack": marked_surrender_table}
	var marked_surrender_deal := game.surface_action_command("blackjack_deal", 0, false, {"selected_stake": 5}, marked_surrender_run_state, marked_surrender_environment)
	var marked_surrender_click := game.surface_action_command("blackjack_surrender", 0, false, marked_surrender_deal.get("ui_state", {}), marked_surrender_run_state, marked_surrender_environment)
	var marked_surrender_result := game.resolve_with_context("play_basic", 5, marked_surrender_run_state, marked_surrender_environment, marked_surrender_run_state.create_rng("blackjack_marked_surrender_resolve"), marked_surrender_click.get("ui_state", {}))
	if int(marked_surrender_result.get("bankroll_delta", 0)) != -3 or int(marked_surrender_result.get("blackjack_main_delta", 0)) != -3:
		failures.append("Blackjack marked cards reduced a legal reveal loss without an actual peek cheat.")

	var split_run_state: RunState = RunStateScript.new()
	split_run_state.start_new("BLACKJACK-SPLIT-CONTRACT")
	var split_environment := _surface_contract_environment()
	var forced_table := generated_state.duplicate(true)
	forced_table["shoe_cursor"] = 0
	forced_table["patrons"] = [
		{"id": "patron_test_0", "name": "Nix", "seat": 0, "temper": "careless", "watching": true, "snitch_risk": 10},
		{"id": "patron_test_1", "name": "Vale", "seat": 1, "temper": "careful", "watching": true, "snitch_risk": 12},
	]
	forced_table["side_bets"] = [
		{"id": "perfect_pairs", "label": "Perfect Pairs", "summary": "Pair first two cards"},
		{"id": "insurance", "label": "Insurance", "summary": "Dealer blackjack pays 2:1"},
	]
	forced_table["rules"] = {"dealer_hits_soft_17": false, "double_after_split": true, "split_aces_one_card": true, "max_split_hands": 4}
	forced_table["shoe"] = [
		{"rank": 8, "suit": 0}, {"rank": 5, "suit": 2}, {"rank": 8, "suit": 1}, {"rank": 6, "suit": 3},
		{"rank": 10, "suit": 0}, {"rank": 2, "suit": 1}, {"rank": 9, "suit": 2}, {"rank": 3, "suit": 0},
		{"rank": 7, "suit": 1}, {"rank": 10, "suit": 2}, {"rank": 6, "suit": 0}, {"rank": 4, "suit": 3},
		{"rank": 13, "suit": 0}, {"rank": 12, "suit": 2}, {"rank": 11, "suit": 1}, {"rank": 9, "suit": 3}
	]
	split_environment["game_states"] = {"blackjack": forced_table}
	var forced_deal := game.surface_action_command("blackjack_deal", 0, false, {}, split_run_state, split_environment)
	var forced_deal_ui: Dictionary = forced_deal.get("ui_state", {})
	var split_surface := game.surface_state(split_run_state, split_environment, forced_deal_ui)
	if not bool(split_surface.get("can_split", false)):
		failures.append("Blackjack forced pair surface did not allow splitting.")
	var late_side_bet_click := game.surface_action_command("blackjack_side_bet", 0, false, forced_deal_ui, split_run_state, split_environment)
	if (late_side_bet_click.get("ui_state", {}) as Dictionary).get("blackjack_side_bets", []) != forced_deal_ui.get("blackjack_side_bets", []):
		failures.append("Blackjack allowed a non-insurance side bet to be changed after cards were dealt.")
	for side_bet_value in (split_surface.get("side_bets_available", []) as Array):
		if typeof(side_bet_value) == TYPE_DICTIONARY and str((side_bet_value as Dictionary).get("id", "")) == "insurance":
			failures.append("Blackjack exposed insurance when the dealer upcard was not an ace.")
	var forced_count_click := game.surface_action_command("blackjack_count_toggle", 0, false, forced_deal_ui, split_run_state, split_environment)
	var forced_count_state: Dictionary = forced_count_click.get("ui_state", {})
	var forced_count_challenge: Dictionary = forced_count_state.get("count_challenge", {})
	var forced_count_cards: Array = forced_count_challenge.get("cards", []) as Array
	if int(forced_count_challenge.get("target_delta", 999)) != _blackjack_test_count_delta(forced_count_cards):
		failures.append("Blackjack count challenge did not use all visible forced-table cards.")
	if forced_count_cards.size() <= 3:
		failures.append("Blackjack count challenge did not include other patron hands.")
	var forced_count_has_patron := false
	for forced_card_value in forced_count_cards:
		if typeof(forced_card_value) == TYPE_DICTIONARY and str((forced_card_value as Dictionary).get("_count_source_key", "")).begins_with("patron:"):
			forced_count_has_patron = true
	if not forced_count_has_patron:
		failures.append("Blackjack count challenge did not tag patron cards as count sources.")

	var ten_split_run_state: RunState = RunStateScript.new()
	ten_split_run_state.start_new("BLACKJACK-TEN-SPLIT-CONTRACT")
	var ten_split_environment := _surface_contract_environment()
	var ten_split_table := generated_state.duplicate(true)
	ten_split_table["shoe_cursor"] = 0
	ten_split_table["patrons"] = []
	ten_split_table["side_bets"] = []
	ten_split_table["rules"] = {"dealer_hits_soft_17": false, "double_after_split": true, "split_aces_one_card": true, "max_split_hands": 4, "late_surrender": true}
	ten_split_table["shoe"] = [
		{"rank": 10, "suit": 0}, {"rank": 5, "suit": 2}, {"rank": 13, "suit": 1}, {"rank": 6, "suit": 3},
		{"rank": 3, "suit": 0}, {"rank": 4, "suit": 1}, {"rank": 8, "suit": 2}, {"rank": 2, "suit": 3}
	]
	ten_split_environment["game_states"] = {"blackjack": ten_split_table}
	var ten_split_deal := game.surface_action_command("blackjack_deal", 0, false, {}, ten_split_run_state, ten_split_environment)
	var ten_split_surface := game.surface_state(ten_split_run_state, ten_split_environment, ten_split_deal.get("ui_state", {}))
	if not bool(ten_split_surface.get("can_split", false)):
		failures.append("Blackjack did not allow splitting two ten-value cards.")

	var insurance_run_state: RunState = RunStateScript.new()
	insurance_run_state.start_new("BLACKJACK-INSURANCE-CONTRACT")
	var insurance_environment := _surface_contract_environment()
	var insurance_table := generated_state.duplicate(true)
	insurance_table["shoe_cursor"] = 0
	insurance_table["patrons"] = []
	insurance_table["side_bets"] = [{"id": "insurance", "label": "Insurance", "summary": "Dealer blackjack pays 2:1"}]
	insurance_table["rules"] = {"dealer_hits_soft_17": false, "double_after_split": true, "split_aces_one_card": true, "max_split_hands": 4, "late_surrender": true}
	insurance_table["shoe"] = [
		{"rank": 10, "suit": 0}, {"rank": 14, "suit": 2}, {"rank": 9, "suit": 1}, {"rank": 6, "suit": 3},
		{"rank": 5, "suit": 0}, {"rank": 7, "suit": 1}, {"rank": 4, "suit": 2}, {"rank": 3, "suit": 3}
	]
	insurance_environment["game_states"] = {"blackjack": insurance_table}
	var insurance_deal := game.surface_action_command("blackjack_deal", 0, false, {"selected_stake": 10}, insurance_run_state, insurance_environment)
	var insurance_ui: Dictionary = insurance_deal.get("ui_state", {})
	var insurance_surface := game.surface_state(insurance_run_state, insurance_environment, insurance_ui)
	if (insurance_surface.get("side_bets_available", []) as Array).is_empty():
		failures.append("Blackjack did not expose insurance on a dealer ace upcard.")
	var insurance_click := game.surface_action_command("blackjack_side_bet", 0, false, insurance_ui, insurance_run_state, insurance_environment)
	insurance_ui = insurance_click.get("ui_state", {})
	var insurance_stand := game.surface_action_command("blackjack_stand", 0, false, insurance_ui, insurance_run_state, insurance_environment)
	insurance_ui = insurance_stand.get("ui_state", {})
	var insurance_result := game.resolve_with_context("play_basic", 10, insurance_run_state, insurance_environment, insurance_run_state.create_rng("blackjack_insurance_resolve"), insurance_ui)
	var insurance_side_results: Array = insurance_result.get("blackjack_side_bet_results", []) as Array
	if insurance_side_results.is_empty() or int((insurance_side_results[0] as Dictionary).get("stake", 0)) != 5:
		failures.append("Blackjack insurance was not priced at half the main wager.")
	var selected_count_state := forced_count_state.duplicate(true)
	selected_count_state["selected_action_id"] = "count_cards"
	selected_count_state["selected_action_kind"] = "cheat"
	var repeat_count := game.surface_action_command("blackjack_count_toggle", 0, false, selected_count_state, split_run_state, split_environment)
	var repeated_challenge: Dictionary = (repeat_count.get("ui_state", {}) as Dictionary).get("count_challenge", {})
	if str(repeat_count.get("action_id", "")) == "count_cards" or bool(repeat_count.get("resolve", false)):
		failures.append("Blackjack count resolved an already-selected active challenge instead of keeping the live overlay running.")
	if not repeated_challenge.is_empty():
		failures.append("Blackjack count toggle did not disarm an active persistent count.")
	var persistent_count_run_state: RunState = RunStateScript.new()
	persistent_count_run_state.start_new("BLACKJACK-PERSISTENT-COUNT")
	var persistent_count_environment := _surface_contract_environment()
	var persistent_count_table := generated_state.duplicate(true)
	persistent_count_table["shoe_cursor"] = 0
	persistent_count_table["patrons"] = [
		{"id": "persist_patron_0", "name": "Nix", "seat": 0, "temper": "careless", "watching": true, "snitch_risk": 10},
		{"id": "persist_patron_1", "name": "Vale", "seat": 1, "temper": "careful", "watching": true, "snitch_risk": 12},
	]
	persistent_count_table["side_bets"] = []
	persistent_count_table["rules"] = {"dealer_hits_soft_17": false, "double_after_split": true, "split_aces_one_card": true, "max_split_hands": 4, "late_surrender": true}
	persistent_count_table["shoe"] = [
		{"rank": 10, "suit": 0}, {"rank": 7, "suit": 2}, {"rank": 6, "suit": 1}, {"rank": 9, "suit": 3},
		{"rank": 4, "suit": 0}, {"rank": 8, "suit": 1}, {"rank": 3, "suit": 2}, {"rank": 2, "suit": 3},
		{"rank": 5, "suit": 0}, {"rank": 10, "suit": 1}, {"rank": 6, "suit": 2}, {"rank": 7, "suit": 3},
		{"rank": 8, "suit": 0}, {"rank": 9, "suit": 1}, {"rank": 10, "suit": 2}, {"rank": 11, "suit": 3}
	]
	persistent_count_environment["game_states"] = {"blackjack": persistent_count_table}
	var arm_count := game.surface_action_command("blackjack_count_toggle", 0, false, {"selected_stake": 5}, persistent_count_run_state, persistent_count_environment)
	var first_count_deal := game.surface_action_command("blackjack_deal", 0, false, arm_count.get("ui_state", {}), persistent_count_run_state, persistent_count_environment)
	if ((first_count_deal.get("ui_state", {}) as Dictionary).get("count_challenge", {}) as Dictionary).is_empty():
		failures.append("Blackjack persistent count did not auto-start on the first armed hand.")
	var first_count_stand := game.surface_action_command("blackjack_stand", 0, true, first_count_deal.get("ui_state", {}), persistent_count_run_state, persistent_count_environment)
	var first_count_stand_state: Dictionary = first_count_stand.get("ui_state", {})
	if bool(first_count_stand.get("resolve", false)) or not bool(first_count_stand_state.get("settlement_count_revealed", false)):
		failures.append("Blackjack active counting did not pause settlement to reveal real table cards for counting.")
	var settlement_challenge: Dictionary = first_count_stand_state.get("count_challenge", {})
	var settlement_cards: Array = settlement_challenge.get("cards", []) as Array
	var settlement_icons: Array = settlement_challenge.get("icons", []) as Array
	var settlement_countable_cards := 0
	for settlement_card_count_value in settlement_cards:
		if typeof(settlement_card_count_value) == TYPE_DICTIONARY and _blackjack_test_count_delta([settlement_card_count_value]) != 0:
			settlement_countable_cards += 1
	if settlement_icons.size() != settlement_countable_cards:
		failures.append("Blackjack settlement count preview created pulses for neutral cards or missed countable cards.")
	for settlement_icon_value in settlement_icons:
		if typeof(settlement_icon_value) == TYPE_DICTIONARY and int((settlement_icon_value as Dictionary).get("count_value", 0)) == 0:
			failures.append("Blackjack settlement count preview created a zero-value pulse.")
	var settlement_has_hole_card := false
	for settlement_card_value in settlement_cards:
		if typeof(settlement_card_value) == TYPE_DICTIONARY and str((settlement_card_value as Dictionary).get("_count_source_key", "")).begins_with("dealer:1:"):
			settlement_has_hole_card = true
	if not settlement_has_hole_card:
		failures.append("Blackjack settlement count preview did not include the revealed dealer hole card.")
	var first_count_result := game.resolve_with_context("play_basic", 5, persistent_count_run_state, persistent_count_environment, persistent_count_run_state.create_rng("blackjack_persistent_count_resolve"), first_count_stand.get("ui_state", {}))
	if not bool(((persistent_count_environment.get("game_states", {}) as Dictionary).get("blackjack", {}) as Dictionary).get("counting_enabled", false)):
		failures.append("Blackjack count toggle did not remain enabled after hand settlement.")
	var second_count_deal := game.surface_action_command("blackjack_deal", 0, false, {"selected_stake": 5}, persistent_count_run_state, persistent_count_environment)
	if ((second_count_deal.get("ui_state", {}) as Dictionary).get("count_challenge", {}) as Dictionary).is_empty():
		failures.append("Blackjack persistent count did not auto-start on the next hand.")
	if (first_count_result.get("blackjack_patron_hands", []) as Array).is_empty():
		failures.append("Blackjack settlement did not expose patron hands in the result payload.")
	var multi_count_run_state: RunState = RunStateScript.new()
	multi_count_run_state.start_new("BLACKJACK-MULTI-HAND-COUNT")
	var multi_count_environment := _surface_contract_environment()
	var multi_count_table := generated_state.duplicate(true)
	multi_count_table["deck_count"] = 1
	multi_count_table["shoe_cursor"] = 0
	multi_count_table["patrons"] = []
	multi_count_table["side_bets"] = []
	multi_count_table["cut_card_remaining"] = 1
	multi_count_table["running_count"] = 0
	multi_count_table["recorded_running_count"] = 0
	multi_count_table["rules"] = {"dealer_hits_soft_17": false, "double_after_split": true, "split_aces_one_card": true, "max_split_hands": 4, "late_surrender": true}
	multi_count_table["shoe"] = [
		{"rank": 10, "suit": 0}, {"rank": 2, "suit": 1}, {"rank": 6, "suit": 2}, {"rank": 7, "suit": 3}, {"rank": 5, "suit": 0}, {"rank": 10, "suit": 1},
		{"rank": 3, "suit": 0}, {"rank": 4, "suit": 1}, {"rank": 2, "suit": 2}, {"rank": 5, "suit": 3}, {"rank": 10, "suit": 2},
		{"rank": 9, "suit": 0}, {"rank": 8, "suit": 1}, {"rank": 7, "suit": 2}, {"rank": 6, "suit": 3}, {"rank": 5, "suit": 1}, {"rank": 4, "suit": 2}
	]
	multi_count_environment["game_states"] = {"blackjack": multi_count_table}
	var multi_arm_count := game.surface_action_command("blackjack_count_toggle", 0, false, {"selected_stake": 5}, multi_count_run_state, multi_count_environment)
	var multi_first_deal := game.surface_action_command("blackjack_deal", 0, false, multi_arm_count.get("ui_state", {}), multi_count_run_state, multi_count_environment)
	var multi_first_preview := game.surface_action_command("blackjack_stand", 0, true, multi_first_deal.get("ui_state", {}), multi_count_run_state, multi_count_environment)
	var multi_first_ui := _blackjack_click_all_count_icons(game, multi_first_preview.get("ui_state", {}), multi_count_run_state, multi_count_environment)
	var multi_first_count_action := game.resolve_with_context("count_cards", 0, multi_count_run_state, multi_count_environment, multi_count_run_state.create_rng("blackjack_multi_count_action"), multi_first_ui)
	var multi_first_count_action_ui: Dictionary = multi_first_count_action.get("ui_state", {}) if typeof(multi_first_count_action.get("ui_state", {})) == TYPE_DICTIONARY else {}
	if not bool(multi_first_count_action.get("preserve_surface_ui_state", false)) or multi_first_count_action_ui.is_empty():
		failures.append("Blackjack standalone count action did not return preserved hand UI state.")
	if not bool(multi_first_count_action_ui.get("count_answered", false)) or int(multi_first_count_action_ui.get("count_delta", 999)) != int(multi_first_ui.get("count_delta", 0)):
		failures.append("Blackjack standalone count action did not preserve the finalized live count delta.")
	var multi_first_result := game.resolve_with_context("play_basic", 5, multi_count_run_state, multi_count_environment, multi_count_run_state.create_rng("blackjack_multi_count_first"), multi_first_count_action_ui)
	var multi_first_expected_count := _blackjack_test_result_count_delta(multi_first_result)
	var multi_after_first: Dictionary = (multi_count_environment.get("game_states", {}) as Dictionary).get("blackjack", {})
	if int(multi_after_first.get("recorded_running_count", 999)) != multi_first_expected_count:
		failures.append("Blackjack recorded count did not persist after the first counted hand.")
	var multi_second_deal := game.surface_action_command("blackjack_deal", 0, false, {"selected_stake": 5}, multi_count_run_state, multi_count_environment)
	var multi_second_surface := game.surface_state(multi_count_run_state, multi_count_environment, multi_second_deal.get("ui_state", {}))
	if int(multi_second_surface.get("persisted_recorded_running_count", 999)) != multi_first_expected_count or int(multi_second_surface.get("recorded_running_count", 999)) != multi_first_expected_count:
		failures.append("Blackjack recorded count was not visible at the start of the next hand.")
	var multi_second_preview := game.surface_action_command("blackjack_stand", 0, true, multi_second_deal.get("ui_state", {}), multi_count_run_state, multi_count_environment)
	var multi_second_ui := _blackjack_click_all_count_icons(game, multi_second_preview.get("ui_state", {}), multi_count_run_state, multi_count_environment)
	var multi_second_result := game.resolve_with_context("play_basic", 5, multi_count_run_state, multi_count_environment, multi_count_run_state.create_rng("blackjack_multi_count_second"), multi_second_ui)
	var multi_second_challenge: Dictionary = multi_second_ui.get("count_challenge", {}) if typeof(multi_second_ui.get("count_challenge", {})) == TYPE_DICTIONARY else {}
	var multi_second_expected_count := multi_first_expected_count + _blackjack_test_result_count_delta(multi_second_result)
	var multi_after_second: Dictionary = (multi_count_environment.get("game_states", {}) as Dictionary).get("blackjack", {})
	if int(multi_after_second.get("recorded_running_count", 999)) != multi_second_expected_count:
		failures.append("Blackjack recorded count did not accumulate across multiple hands in the same shoe: expected %+d, got %+d; first %+d, second result %+d, second challenge %+d." % [multi_second_expected_count, int(multi_after_second.get("recorded_running_count", 999)), multi_first_expected_count, _blackjack_test_result_count_delta(multi_second_result), int(multi_second_challenge.get("target_delta", 999))])
	if int(multi_second_result.get("blackjack_recorded_count", 999)) != multi_second_expected_count:
		failures.append("Blackjack result payload did not report the accumulated recorded count: expected %+d, got %+d; first %+d, second result %+d, second challenge %+d." % [multi_second_expected_count, int(multi_second_result.get("blackjack_recorded_count", 999)), multi_first_expected_count, _blackjack_test_result_count_delta(multi_second_result), int(multi_second_challenge.get("target_delta", 999))])
	var low_bankroll: RunState = RunStateScript.new()
	low_bankroll.start_new("BLACKJACK-LOW-BANKROLL")
	low_bankroll.change_bankroll(-95)
	var low_deal := game.surface_action_command("blackjack_deal", 0, false, {"selected_stake": 5}, low_bankroll, split_environment)
	var low_surface := game.surface_state(low_bankroll, split_environment, low_deal.get("ui_state", {}))
	if bool(low_surface.get("can_split", false)) or bool(low_surface.get("can_double", false)):
		failures.append("Blackjack offered split or double when the projected wager exceeded bankroll.")
	var side_click := game.surface_action_command("blackjack_side_bet", 0, false, {}, split_run_state, split_environment)
	var split_deal := game.surface_action_command("blackjack_deal", 0, false, side_click.get("ui_state", {}), split_run_state, split_environment)
	var split_ui: Dictionary = split_deal.get("ui_state", {})
	if (split_ui.get("blackjack_side_bets", []) as Array).is_empty():
		failures.append("Blackjack side-bet toggle did not persist in UI-local state.")
	var split_click := game.surface_action_command("blackjack_split", 0, false, split_ui, split_run_state, split_environment)
	split_ui = split_click.get("ui_state", {})
	if (split_ui.get("player_hands", []) as Array).size() != 2:
		failures.append("Blackjack split did not create two hands.")
	var double_click := game.surface_action_command("blackjack_double", 0, false, split_ui, split_run_state, split_environment)
	split_ui = double_click.get("ui_state", {})
	if (split_ui.get("player_hands", []) as Array).size() != 2:
		failures.append("Blackjack double after split lost split hand state.")
	var settle_command := {}
	for _i in range(4):
		settle_command = game.surface_action_command("blackjack_stand", 0, true, split_ui, split_run_state, split_environment)
		split_ui = settle_command.get("ui_state", {})
		if bool(settle_command.get("resolve", false)):
			break
	if not bool(settle_command.get("resolve", false)):
		failures.append("Blackjack split hands did not reach a resolvable state after standing.")
	var split_before := _run_state_result_snapshot(split_run_state)
	var split_result := game.resolve_with_context("play_basic", 5, split_run_state, split_environment, split_run_state.create_rng("blackjack_split_resolve"), split_ui)
	_check_action_result_shape(split_result, "legal", failures)
	_check_action_result_applied(split_before, split_run_state, split_result, "blackjack split hand result", failures)
	if (split_result.get("blackjack_hand_results", []) as Array).size() != 2:
		failures.append("Blackjack split result did not settle both hands.")
	var split_side_results: Array = split_result.get("blackjack_side_bet_results", []) as Array
	if split_side_results.is_empty():
		failures.append("Blackjack result did not settle selected side bets.")
	else:
		var pair_result: Dictionary = split_side_results[0]
		if str(pair_result.get("id", "")) != "perfect_pairs" or not bool(pair_result.get("won", false)) or str(pair_result.get("detail", "")) != "mixed pair":
			failures.append("Blackjack perfect-pairs side bet did not settle from the initial deal.")
	var updated_table: Dictionary = (split_environment.get("game_states", {}) as Dictionary).get("blackjack", {})
	if int(updated_table.get("hands_played", 0)) <= 0:
		failures.append("Blackjack resolve did not update persistent table hand count.")
	var last_result: Dictionary = updated_table.get("last_result", {}) if typeof(updated_table.get("last_result", {})) == TYPE_DICTIONARY else {}
	if not last_result.has("headline") or not last_result.has("bankroll_delta") or not last_result.has("hand_results"):
		failures.append("Blackjack resolve did not persist an in-table result payload.")
	if (last_result.get("side_bet_results", []) as Array).is_empty():
		failures.append("Blackjack persisted result did not include placed side-bet outcome details.")

	var shoe_persist_run_state: RunState = RunStateScript.new()
	shoe_persist_run_state.start_new("BLACKJACK-SHOE-PERSISTENCE")
	var shoe_persist_environment := _surface_contract_environment()
	var shoe_persist_table := generated_state.duplicate(true)
	shoe_persist_table["shoe_cursor"] = 0
	shoe_persist_table["patrons"] = []
	shoe_persist_table["side_bets"] = []
	shoe_persist_table["cut_card_remaining"] = 1
	var shoe_persist_start_size := (shoe_persist_table.get("shoe", []) as Array).size()
	shoe_persist_environment["game_states"] = {"blackjack": shoe_persist_table}
	var shoe_persist_deal := game.surface_action_command("blackjack_deal", 0, false, {"selected_stake": 5}, shoe_persist_run_state, shoe_persist_environment)
	var shoe_persist_stand := game.surface_action_command("blackjack_stand", 0, true, shoe_persist_deal.get("ui_state", {}), shoe_persist_run_state, shoe_persist_environment)
	var shoe_persist_result := game.resolve_with_context("play_basic", 5, shoe_persist_run_state, shoe_persist_environment, shoe_persist_run_state.create_rng("blackjack_shoe_persist_resolve"), shoe_persist_stand.get("ui_state", {}))
	var _shoe_persist_delta := int(shoe_persist_result.get("blackjack_main_delta", 0))
	var shoe_persist_updated: Dictionary = (shoe_persist_environment.get("game_states", {}) as Dictionary).get("blackjack", {})
	var persisted_shoe: Array = shoe_persist_updated.get("shoe", []) as Array
	var persisted_composition: Dictionary = shoe_persist_updated.get("shoe_composition", {}) if typeof(shoe_persist_updated.get("shoe_composition", {})) == TYPE_DICTIONARY else {}
	if persisted_shoe.is_empty() or persisted_shoe.size() >= shoe_persist_start_size:
		failures.append("Blackjack resolve did not persist the actual shorter remaining shoe.")
	if int(shoe_persist_updated.get("shoe_remaining", -1)) != persisted_shoe.size() or int(persisted_composition.get("total", -1)) != persisted_shoe.size():
		failures.append("Blackjack persistent shoe metadata did not match the actual remaining cards.")
	if int(shoe_persist_updated.get("shoe_cursor", -1)) != 0:
		failures.append("Blackjack persistent shoe still used a cursor instead of the remaining card array.")

	var shuffle_run_state: RunState = RunStateScript.new()
	shuffle_run_state.start_new("BLACKJACK-SHOE-SHUFFLE")
	var shuffle_environment := _surface_contract_environment()
	var shuffle_table := generated_state.duplicate(true)
	shuffle_table["deck_count"] = 1
	shuffle_table["shoe_cursor"] = 0
	shuffle_table["patrons"] = []
	shuffle_table["side_bets"] = []
	shuffle_table["cut_card_remaining"] = 10
	shuffle_table["running_count"] = 5
	shuffle_table["recorded_running_count"] = 3
	shuffle_table["shoe"] = [
		{"rank": 10, "suit": 0}, {"rank": 9, "suit": 2}, {"rank": 6, "suit": 1}, {"rank": 7, "suit": 3},
		{"rank": 10, "suit": 2}, {"rank": 5, "suit": 1}, {"rank": 4, "suit": 0}, {"rank": 3, "suit": 2}
	]
	shuffle_environment["game_states"] = {"blackjack": shuffle_table}
	var shuffle_deal := game.surface_action_command("blackjack_deal", 0, false, {"selected_stake": 5}, shuffle_run_state, shuffle_environment)
	var shuffle_stand := game.surface_action_command("blackjack_stand", 0, true, shuffle_deal.get("ui_state", {}), shuffle_run_state, shuffle_environment)
	var _shuffle_result := game.resolve_with_context("play_basic", 5, shuffle_run_state, shuffle_environment, shuffle_run_state.create_rng("blackjack_forced_shuffle_resolve"), shuffle_stand.get("ui_state", {}))
	var shuffle_updated: Dictionary = (shuffle_environment.get("game_states", {}) as Dictionary).get("blackjack", {})
	var shuffled_shoe: Array = shuffle_updated.get("shoe", []) as Array
	var shuffle_composition: Dictionary = shuffle_updated.get("shoe_composition", {}) if typeof(shuffle_updated.get("shoe_composition", {})) == TYPE_DICTIONARY else {}
	if shuffled_shoe.size() != 52 or int(shuffle_composition.get("total", -1)) != 52:
		failures.append("Blackjack cut-card shuffle did not rebuild a full shoe from the declared deck count.")
	if int(shuffle_updated.get("running_count", 99)) != 0 or int(shuffle_updated.get("recorded_running_count", 99)) != 0:
		failures.append("Blackjack cut-card shuffle did not reset true and recorded counts.")
	if int(shuffle_updated.get("last_shuffle_hand", 0)) <= 0:
		failures.append("Blackjack cut-card shuffle did not record the shuffle hand.")

	var ladies_run_state: RunState = RunStateScript.new()
	ladies_run_state.start_new("BLACKJACK-LUCKY-LADIES")
	var ladies_environment := _surface_contract_environment()
	var ladies_table := generated_state.duplicate(true)
	ladies_table["shoe_cursor"] = 0
	ladies_table["patrons"] = []
	ladies_table["side_bets"] = [{"id": "lucky_ladies", "label": "Lucky Ladies", "summary": "First two total 20"}]
	ladies_table["rules"] = {"dealer_hits_soft_17": false, "double_after_split": true, "split_aces_one_card": true, "max_split_hands": 4}
	ladies_table["shoe"] = [
		{"rank": 12, "suit": 1}, {"rank": 14, "suit": 0}, {"rank": 12, "suit": 0}, {"rank": 13, "suit": 2},
		{"rank": 9, "suit": 0}, {"rank": 8, "suit": 1}, {"rank": 7, "suit": 2}, {"rank": 6, "suit": 3}
	]
	ladies_environment["game_states"] = {"blackjack": ladies_table}
	var ladies_side_click := game.surface_action_command("blackjack_side_bet", 0, false, {}, ladies_run_state, ladies_environment)
	var ladies_deal := game.surface_action_command("blackjack_deal", 0, false, ladies_side_click.get("ui_state", {}), ladies_run_state, ladies_environment)
	var ladies_ui: Dictionary = ladies_deal.get("ui_state", {})
	var ladies_settle := game.surface_action_command("blackjack_stand", 0, true, ladies_ui, ladies_run_state, ladies_environment)
	ladies_ui = ladies_settle.get("ui_state", {})
	var ladies_result := game.resolve_with_context("play_basic", 5, ladies_run_state, ladies_environment, ladies_run_state.create_rng("blackjack_lucky_ladies_resolve"), ladies_ui)
	var ladies_side_results: Array = ladies_result.get("blackjack_side_bet_results", []) as Array
	if ladies_side_results.is_empty():
		failures.append("Blackjack Lucky Ladies side bet did not settle.")
	else:
		var ladies_side_result: Dictionary = ladies_side_results[0]
		if int(ladies_side_result.get("payout_mult", 0)) == 200 or str(ladies_side_result.get("detail", "")) == "queen hearts with dealer blackjack":
			failures.append("Blackjack Lucky Ladies awarded the queen-hearts jackpot with only one queen of hearts.")
	var cheat_before := _run_state_result_snapshot(split_run_state)
	var cheat_result := game.resolve_with_context("peek_hole_card", 0, split_run_state, split_environment, split_run_state.create_rng("blackjack_peek_resolve"), peek_click.get("ui_state", {}))
	_check_action_result_shape(cheat_result, "cheat", failures)
	_check_action_result_applied(cheat_before, split_run_state, cheat_result, "blackjack peek cheat result", failures)
	split_run_state.set_environment(split_environment)
	var restored: RunState = RunStateScript.new()
	restored.from_dict(split_run_state.to_dict())
	var restored_game_states: Dictionary = restored.current_environment.get("game_states", {})
	if not restored_game_states.has("blackjack"):
		failures.append("Blackjack generated table state did not round-trip through RunState serialization.")


func _check_video_poker_surface_contract(game: GameModule, failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("VIDEO-POKER-SURFACE-CONTRACT")
	var environment := _surface_contract_environment()
	var surface := game.surface_state(run_state, environment, {})
	if str(surface.get("surface_renderer", "")) != "card_machine":
		failures.append("Video poker surface did not route to the card-machine renderer.")
	if not bool(surface.get("surface_controls_native", false)):
		failures.append("Video poker surface did not expose native surface controls.")
	if (surface.get("hand", []) as Array).size() != 5:
		failures.append("Video poker surface did not expose a five-card hand.")
	if str(surface.get("phase", "")) != "idle":
		failures.append("Video poker surface should start idle before DEAL (phase=%s)." % str(surface.get("phase", "")))
	var idle_hand: Array = surface.get("hand", []) as Array
	var first_idle_card: Dictionary = idle_hand[0] if idle_hand.size() > 0 and typeof(idle_hand[0]) == TYPE_DICTIONARY else {}
	if not first_idle_card.has("hidden"):
		failures.append("Video poker idle surface should show card backs instead of an already-dealt hand.")
	var idle_harness := SurfaceHarness.new()
	idle_harness.setup(surface)
	game.draw_surface(idle_harness, surface, {"contract_harness": true})
	_check_surface_hit_layout(idle_harness, "Video poker idle surface", failures)
	for action in ["video_poker_bet_one", "video_poker_bet_max", "video_poker_denom", "video_poker_deal"]:
		if not _surface_harness_has_action(idle_harness, action):
			failures.append("Video poker idle cabinet is missing %s." % action)
	var idle_draw := game.surface_action_command("video_poker_draw", 0, false, {}, run_state, environment)
	if str(idle_draw.get("action_id", "")) == "draw":
		failures.append("Video poker DRAW should not resolve before DEAL.")
	var idle_mark := game.surface_action_command("video_poker_mark", 0, false, {}, run_state, environment)
	if str(idle_mark.get("action_id", "")) == "mark_holds":
		failures.append("Video poker MARK HOLDS should not arm before DEAL.")
	var deal_click := _check_surface_command_non_mutating(game, "video_poker_deal", 0, false, {}, run_state, environment, "video poker deal", failures)
	var deal_state: Dictionary = deal_click.get("ui_state", {})
	var dealt_surface := game.surface_state(run_state, environment, deal_state)
	if str(dealt_surface.get("phase", "")) != "hold":
		failures.append("Video poker DEAL did not enter hold phase.")
	var hold_click := _check_surface_command_non_mutating(game, "video_poker_hold", 0, false, deal_state, run_state, environment, "video poker hold", failures)
	var hold_state: Dictionary = hold_click.get("ui_state", {})
	if not (hold_state.get("holds", []) as Array).has(0):
		failures.append("Video poker card click did not update UI-local hold state.")
	var draw_click := game.surface_action_command("video_poker_draw", 0, false, hold_state, run_state, environment)
	if str(draw_click.get("action_kind", "")) != "legal":
		failures.append("Video poker draw did not map to a legal action.")
	var selected_surface := game.surface_state(run_state, environment, hold_state)
	if not (selected_surface.get("native_selected_surface_actions", []) as Array).is_empty():
		failures.append("Video poker surface should not expose native selected actions that can auto-advance play.")
	var hold_harness := SurfaceHarness.new()
	hold_harness.setup(selected_surface)
	game.draw_surface(hold_harness, selected_surface, {"contract_harness": true})
	_check_surface_hit_layout(hold_harness, "Video poker hold surface", failures)
	if _surface_hit_count(hold_harness, "video_poker_hold") < 5:
		failures.append("Video poker hold surface should expose one HOLD control per card.")
	if not _surface_harness_has_action(hold_harness, "video_poker_draw"):
		failures.append("Video poker hold surface is missing DRAW.")
	var mark_click := game.surface_action_command("video_poker_mark", 0, false, deal_state, run_state, environment)
	if str(mark_click.get("action_kind", "")) != "cheat":
		failures.append("Video poker marked holds did not map to a risky action.")
	var mark_state: Dictionary = mark_click.get("ui_state", {})
	if not bool(mark_state.get("marked", false)):
		failures.append("Video poker mark did not arm the holdout cheat in UI-local state.")
	# The cheat's marked holds match the module's own suggested holds for the deal.
	var fresh_surface := game.surface_state(run_state, environment, deal_state)
	if JSON.stringify(mark_state.get("holds", [])) != JSON.stringify(fresh_surface.get("suggested_holds", [])):
		failures.append("Video poker mark did not set the suggested optimal holds.")


# Video poker is a full-simulation draw-poker module: hand evaluation, holds
# changing the outcome, the holdout cheat (odds + heat), the RTP band, and the
# result-visible guard against the surface stranding in the hold phase.
func _check_video_poker_contract(library: ContentLibrary, failures: Array) -> void:
	var game: GameModule = _load_surface_contract_game(library, "video_poker", failures)
	if game == null:
		return
	if not game.is_full_simulation():
		failures.append("Video Poker must report the full-simulation gameplay model.")
	_check_video_poker_evaluation(game, failures)
	_check_video_poker_generated_identity(game, failures)
	_check_video_poker_royal_bonus(game, failures)
	_check_video_poker_result_visible(game, failures)
	_check_video_poker_holds_outcome(game, failures)
	_check_video_poker_multi_hand(game, failures)
	_check_video_poker_cheat(game, failures)
	_check_video_poker_item_luck_alcohol(game, failures)
	_check_video_poker_double_up(game, failures)
	_check_video_poker_rtp_bands(game, failures)


func _vp_card(rank: int, suit: int) -> Dictionary:
	return {"rank": rank, "suit": suit, "deck": 0}


func _vp_variant(game: GameModule, variant_id: String) -> Dictionary:
	return game.call("_variant", {"variant_id": variant_id})


func _vp_check_pay(game: GameModule, variant_id: String, hand: Array, expected_key: String, failures: Array) -> void:
	var variant: Dictionary = _vp_variant(game, variant_id)
	var descriptor: Dictionary = game.call("_evaluate", hand, variant.get("wild_ranks", []))
	var pay_row: Dictionary = game.call("_pay_for", descriptor, variant)
	if str(pay_row.get("key", "")) != expected_key:
		failures.append("Video poker [%s] scored a hand as '%s' instead of '%s'." % [variant_id, str(pay_row.get("key", "")), expected_key])


func _check_video_poker_evaluation(game: GameModule, failures: Array) -> void:
	# Jacks or Better base hands (royal, wheel straight, low-pair no-pay).
	_vp_check_pay(game, "jacks_or_better", [_vp_card(14, 1), _vp_card(13, 1), _vp_card(12, 1), _vp_card(11, 1), _vp_card(10, 1)], "royal_flush", failures)
	_vp_check_pay(game, "jacks_or_better", [_vp_card(5, 0), _vp_card(5, 1), _vp_card(5, 2), _vp_card(9, 0), _vp_card(9, 1)], "full_house", failures)
	_vp_check_pay(game, "jacks_or_better", [_vp_card(2, 2), _vp_card(5, 2), _vp_card(9, 2), _vp_card(11, 2), _vp_card(13, 2)], "flush", failures)
	_vp_check_pay(game, "jacks_or_better", [_vp_card(14, 0), _vp_card(2, 1), _vp_card(3, 2), _vp_card(4, 3), _vp_card(5, 0)], "straight", failures)
	_vp_check_pay(game, "jacks_or_better", [_vp_card(11, 0), _vp_card(11, 1), _vp_card(4, 2), _vp_card(4, 3), _vp_card(9, 0)], "two_pair", failures)
	_vp_check_pay(game, "jacks_or_better", [_vp_card(12, 0), _vp_card(12, 1), _vp_card(3, 2), _vp_card(5, 3), _vp_card(9, 0)], "jacks_or_better", failures)
	_vp_check_pay(game, "jacks_or_better", [_vp_card(6, 0), _vp_card(6, 1), _vp_card(3, 2), _vp_card(9, 3), _vp_card(13, 0)], "", failures)
	# Bonus Poker enhanced quads.
	_vp_check_pay(game, "bonus_poker", [_vp_card(14, 0), _vp_card(14, 1), _vp_card(14, 2), _vp_card(14, 3), _vp_card(9, 0)], "four_aces", failures)
	_vp_check_pay(game, "bonus_poker", [_vp_card(3, 0), _vp_card(3, 1), _vp_card(3, 2), _vp_card(3, 3), _vp_card(9, 0)], "four_2_4", failures)
	_vp_check_pay(game, "bonus_poker", [_vp_card(13, 0), _vp_card(13, 1), _vp_card(13, 2), _vp_card(13, 3), _vp_card(9, 0)], "four_5_k", failures)
	# Double Double Bonus quads with kickers (and two pair pays the reduced row).
	_vp_check_pay(game, "double_double_bonus", [_vp_card(14, 0), _vp_card(14, 1), _vp_card(14, 2), _vp_card(14, 3), _vp_card(2, 0)], "four_aces_kicker", failures)
	_vp_check_pay(game, "double_double_bonus", [_vp_card(14, 0), _vp_card(14, 1), _vp_card(14, 2), _vp_card(14, 3), _vp_card(9, 0)], "four_aces", failures)
	_vp_check_pay(game, "double_double_bonus", [_vp_card(3, 0), _vp_card(3, 1), _vp_card(3, 2), _vp_card(3, 3), _vp_card(14, 0)], "four_2_4_kicker", failures)
	_vp_check_pay(game, "double_double_bonus", [_vp_card(3, 0), _vp_card(3, 1), _vp_card(3, 2), _vp_card(3, 3), _vp_card(9, 0)], "four_2_4", failures)
	_vp_check_pay(game, "double_double_bonus", [_vp_card(11, 0), _vp_card(11, 1), _vp_card(4, 2), _vp_card(4, 3), _vp_card(9, 0)], "two_pair", failures)
	# Deuces Wild wild-card categories.
	_vp_check_pay(game, "deuces_wild", [_vp_card(14, 1), _vp_card(13, 1), _vp_card(12, 1), _vp_card(11, 1), _vp_card(10, 1)], "natural_royal", failures)
	_vp_check_pay(game, "deuces_wild", [_vp_card(2, 0), _vp_card(2, 1), _vp_card(2, 2), _vp_card(2, 3), _vp_card(9, 0)], "four_deuces", failures)
	_vp_check_pay(game, "deuces_wild", [_vp_card(2, 1), _vp_card(13, 1), _vp_card(12, 1), _vp_card(11, 1), _vp_card(10, 1)], "wild_royal", failures)
	_vp_check_pay(game, "deuces_wild", [_vp_card(2, 0), _vp_card(2, 1), _vp_card(13, 0), _vp_card(13, 1), _vp_card(13, 2)], "five_kind", failures)
	_vp_check_pay(game, "deuces_wild", [_vp_card(2, 0), _vp_card(7, 0), _vp_card(8, 0), _vp_card(9, 0), _vp_card(10, 0)], "straight_flush", failures)
	_vp_check_pay(game, "deuces_wild", [_vp_card(2, 0), _vp_card(7, 0), _vp_card(7, 1), _vp_card(7, 2), _vp_card(9, 0)], "four_kind", failures)
	_vp_check_pay(game, "deuces_wild", [_vp_card(2, 0), _vp_card(5, 0), _vp_card(8, 0), _vp_card(11, 0), _vp_card(13, 0)], "flush", failures)
	_vp_check_pay(game, "deuces_wild", [_vp_card(2, 0), _vp_card(7, 1), _vp_card(8, 2), _vp_card(9, 3), _vp_card(10, 0)], "straight", failures)
	_vp_check_pay(game, "deuces_wild", [_vp_card(2, 0), _vp_card(7, 1), _vp_card(7, 2), _vp_card(9, 3), _vp_card(11, 0)], "three_kind", failures)
	_vp_check_pay(game, "deuces_wild", [_vp_card(7, 0), _vp_card(7, 1), _vp_card(9, 3), _vp_card(11, 0), _vp_card(13, 2)], "", failures)
	# Joker Poker one-joker wild categories and kings-or-better floor.
	_vp_check_pay(game, "joker_poker", [_vp_card(14, 2), _vp_card(13, 2), _vp_card(12, 2), _vp_card(11, 2), _vp_card(10, 2)], "natural_royal", failures)
	_vp_check_pay(game, "joker_poker", [_vp_card(0, 4), _vp_card(13, 1), _vp_card(13, 2), _vp_card(13, 3), _vp_card(13, 0)], "five_kind", failures)
	_vp_check_pay(game, "joker_poker", [_vp_card(0, 4), _vp_card(14, 1), _vp_card(13, 1), _vp_card(12, 1), _vp_card(11, 1)], "wild_royal", failures)
	_vp_check_pay(game, "joker_poker", [_vp_card(0, 4), _vp_card(13, 1), _vp_card(8, 2), _vp_card(7, 0), _vp_card(3, 1)], "kings_or_better", failures)
	_vp_check_pay(game, "joker_poker", [_vp_card(12, 1), _vp_card(12, 2), _vp_card(8, 2), _vp_card(7, 0), _vp_card(3, 1)], "", failures)


func _check_video_poker_generated_identity(game: GameModule, failures: Array) -> void:
	var run_a: RunState = RunStateScript.new()
	run_a.start_new("VIDEO-POKER-GENERATED")
	var env_a := _surface_contract_environment()
	var state_a: Dictionary = game.generate_environment_state(run_a, env_a, run_a.create_rng("video_poker_identity"))
	var run_b: RunState = RunStateScript.new()
	run_b.start_new("VIDEO-POKER-GENERATED")
	var env_b := _surface_contract_environment()
	var state_b: Dictionary = game.generate_environment_state(run_b, env_b, run_b.create_rng("video_poker_identity"))
	if JSON.stringify(state_a) != JSON.stringify(state_b):
		failures.append("Video poker generated cabinet identity is not deterministic for the same seed.")
	for required_key in ["cabinet_key", "variant_id", "paytable_tier_id", "coin_denominations", "denomination_index", "multi_hand_count", "progressive_meter", "holdout_tell"]:
		if not state_a.has(required_key):
			failures.append("Video poker generated state is missing %s." % required_key)
	var denominations: Array = state_a.get("coin_denominations", [])
	if denominations.size() < 2:
		failures.append("Video poker generated denomination set is too shallow.")
	if not [1, 3, 5, 10].has(int(state_a.get("multi_hand_count", 0))):
		failures.append("Video poker generated multi-hand count was not one of the cabinet modes.")
	env_a["game_states"] = {"video_poker": state_a}
	run_a.current_environment = env_a.duplicate(true)
	var surface := game.surface_state(run_a, run_a.current_environment, {})
	if str(surface.get("surface_renderer", "")) != "card_machine":
		failures.append("Video poker generated surface did not route to the card-machine renderer.")
	if bool(surface.get("surface_stake_controls_required", true)):
		failures.append("Video poker should use cabinet coin controls instead of host stake controls.")
	if int(surface.get("hand_count", 0)) != int(state_a.get("multi_hand_count", 0)):
		failures.append("Video poker surface did not expose generated Play count.")
	var denom_click := _check_surface_command_non_mutating(game, "video_poker_denom", 0, false, {}, run_a, run_a.current_environment, "video poker denomination", failures)
	if int((denom_click.get("ui_state", {}) as Dictionary).get("denomination_index", -1)) == int(surface.get("denomination_index", 0)) and denominations.size() > 1:
		failures.append("Video poker denomination click did not update UI-local denomination state.")


func _check_video_poker_royal_bonus(game: GameModule, failures: Array) -> void:
	var variant: Dictionary = _vp_variant(game, "jacks_or_better")
	var rows: Array = variant.get("rows", [])
	if rows.is_empty():
		failures.append("Video poker variant exposed no paytable rows.")
		return
	var royal_row: Dictionary = rows[0]
	# Below max coin the royal pays 250-for-1; at 5 coins it pays 800-for-1.
	var pay_low := int(game.call("_row_pay", royal_row, 4, false))
	var pay_max := int(game.call("_row_pay", royal_row, 5, true))
	if pay_low != 1000:
		failures.append("Video poker royal did not pay 250-for-1 below the max bet (got %d)." % pay_low)
	if pay_max != 4000:
		failures.append("Video poker royal did not pay the 800-for-1 max-bet jackpot (got %d)." % pay_max)
	var full_variant: Dictionary = game.call("_variant", {"variant_id": "jacks_or_better", "paytable_tier_id": "full_pay"})
	var short_variant: Dictionary = game.call("_variant", {"variant_id": "jacks_or_better", "paytable_tier_id": "short_pay"})
	var full_house_full: Dictionary = game.call("_pay_for", game.call("_evaluate", [_vp_card(5, 0), _vp_card(5, 1), _vp_card(5, 2), _vp_card(9, 0), _vp_card(9, 1)], []), full_variant)
	var full_house_short: Dictionary = game.call("_pay_for", game.call("_evaluate", [_vp_card(5, 0), _vp_card(5, 1), _vp_card(5, 2), _vp_card(9, 0), _vp_card(9, 1)], []), short_variant)
	if int(full_house_full.get("mult", 0)) <= int(full_house_short.get("mult", 0)):
		failures.append("Video poker full-pay tier did not outrank short-pay full house.")


func _vp_fresh(game: GameModule, variant_id: String, seed_text: String, bankroll: int, tier_id: String = "standard", hand_count: int = 1, coin_value: int = 1) -> RunState:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new(seed_text)
	run_state.bankroll = bankroll
	var environment := _surface_contract_environment()
	environment["economic_profile"] = {"stake_floor": 1, "stake_ceiling": maxi(20, coin_value * hand_count * 5)}
	var state: Dictionary = game.generate_environment_state(run_state, environment, run_state.create_rng("vp_state"))
	state["variant_id"] = variant_id
	state["paytable_tier_id"] = tier_id
	state["coin_denominations"] = [{"label": "$%d" % coin_value, "credits": coin_value}]
	state["denomination_index"] = 0
	state["multi_hand_count"] = hand_count
	state["progressive_meter"] = 300
	environment["game_states"] = {"video_poker": state}
	run_state.current_environment = environment.duplicate(true)
	return run_state


func _check_video_poker_result_visible(game: GameModule, failures: Array) -> void:
	var run_state: RunState = _vp_fresh(game, "jacks_or_better", "VIDEO-POKER-RESULT-VISIBLE", 500)
	var deal_cmd := game.surface_action_command("video_poker_deal", 0, false, {}, run_state, run_state.current_environment)
	var dealt_ui: Dictionary = deal_cmd.get("ui_state", {})
	# A confirmed draw must resolve and must NOT preserve UI-local state, so the host
	# clears the active hand and the next surface_state shows the settled result.
	var confirm_cmd := game.surface_action_command("video_poker_draw", 0, true, dealt_ui, run_state, run_state.current_environment)
	if not bool(confirm_cmd.get("resolve", false)):
		failures.append("Video poker confirmed draw did not request resolution.")
	if bool(confirm_cmd.get("preserve_surface_ui_state", false)):
		failures.append("Video poker resolving draw preserved UI-local state, stranding the surface in the hold phase.")
	var result := game.resolve_with_context("draw", 8, run_state, run_state.current_environment, run_state.create_rng("vp_visible_resolve"), confirm_cmd.get("ui_state", dealt_ui))
	if not bool(result.get("ok", false)):
		failures.append("Video poker draw did not complete a hand.")
	var settled := game.surface_state(run_state, run_state.current_environment, {})
	if str(settled.get("phase", "")) != "settled":
		failures.append("Video poker surface did not show the settled result after drawing (phase=%s)." % str(settled.get("phase", "")))
	if str(settled.get("result_message", "")).strip_edges().is_empty():
		failures.append("Video poker settled surface did not expose the hand result after drawing.")


func _check_video_poker_holds_outcome(game: GameModule, failures: Array) -> void:
	# Holding all five cards (no draw) versus holding none (draw all five) from the
	# same deal must produce different final hands, proving holds change the outcome.
	var hold_all := _video_poker_resolve_with_holds(game, [0, 1, 2, 3, 4])
	var hold_none := _video_poker_resolve_with_holds(game, [])
	var kept: Array = hold_all.get("video_poker_hand", [])
	var drawn: Array = hold_none.get("video_poker_hand", [])
	if kept.size() != 5 or drawn.size() != 5:
		failures.append("Video poker resolve did not report a final hand.")
		return
	if JSON.stringify(kept) == JSON.stringify(drawn):
		failures.append("Video poker holds did not change the drawn hand.")


func _video_poker_resolve_with_holds(game: GameModule, holds: Array) -> Dictionary:
	var run_state: RunState = _vp_fresh(game, "jacks_or_better", "VIDEO-POKER-HOLDS", 100000)
	var deal_cmd := game.surface_action_command("video_poker_deal", 0, false, {}, run_state, run_state.current_environment)
	var ui: Dictionary = deal_cmd.get("ui_state", {})
	ui["holds"] = holds
	return game.resolve_with_context("draw", 5, run_state, run_state.current_environment, run_state.create_rng("vp_holds_resolve"), ui)


func _check_video_poker_multi_hand(game: GameModule, failures: Array) -> void:
	var run_state: RunState = _vp_fresh(game, "bonus_poker", "VIDEO-POKER-MULTI", 1000000, "standard", 5, 1)
	var deal_cmd := game.surface_action_command("video_poker_deal", 0, false, {}, run_state, run_state.current_environment)
	var ui: Dictionary = deal_cmd.get("ui_state", {})
	ui["holds"] = [0, 1]
	ui["bet_level"] = 4
	var result := game.resolve_with_context("draw", 5, run_state, run_state.current_environment, run_state.create_rng("vp_multi_resolve"), ui)
	var hands: Array = result.get("video_poker_hands", [])
	var hand_results: Array = result.get("video_poker_hand_results", [])
	if hands.size() != 5 or hand_results.size() != 5:
		failures.append("Video poker 5 Play did not resolve five independent hands.")
		return
	var first_hand: Array = hands[0]
	var distinct_hands := {}
	var total := 0
	for i in range(hand_results.size()):
		var row: Dictionary = hand_results[i] if typeof(hand_results[i]) == TYPE_DICTIONARY else {}
		total += int(row.get("total", 0))
		var hand: Array = hands[i] if typeof(hands[i]) == TYPE_ARRAY else []
		if hand.size() >= 2 and first_hand.size() >= 2:
			if JSON.stringify([hand[0], hand[1]]) != JSON.stringify([first_hand[0], first_hand[1]]):
				failures.append("Video poker multi-hand did not replicate held cards across hands.")
		distinct_hands[JSON.stringify(hand)] = true
	if total != int(result.get("video_poker_gross", -1)):
		failures.append("Video poker multi-hand gross did not equal the sum of hand results.")
	if distinct_hands.size() <= 1:
		failures.append("Video poker multi-hand draws did not show independent per-hand decks.")
	if int(result.get("video_poker_bet", 0)) != 25:
		failures.append("Video poker 5 Play max-coin denomination math was wrong.")


func _check_video_poker_cheat(game: GameModule, failures: Array) -> void:
	var run_state: RunState = _vp_fresh(game, "jacks_or_better", "VIDEO-POKER-CHEAT", 100000)
	var before := _run_state_result_snapshot(run_state)
	var deal_cmd := game.surface_action_command("video_poker_deal", 0, false, {}, run_state, run_state.current_environment)
	var ui: Dictionary = deal_cmd.get("ui_state", {})
	var cheat_result := game.resolve_with_context("mark_holds", 5, run_state, run_state.current_environment, run_state.create_rng("vp_cheat_resolve"), ui)
	_check_action_result_shape(cheat_result, "cheat", failures)
	if int(cheat_result.get("suspicion_delta", 0)) <= 0:
		failures.append("Video poker holdout did not raise suspicion heat.")
	if not bool(cheat_result.get("video_poker_cheated", false)):
		failures.append("Video poker holdout did not flag the result as cheated.")
	_check_action_result_application_contract(before, run_state, cheat_result, "video poker holdout result", failures)
	# Over many hands the holdout improves the return-to-player versus honest play.
	var honest_rtp := _video_poker_rtp(game, "jacks_or_better", "standard", "draw", "VIDEO-POKER-CHEAT-HONEST", 1200)
	var cheat_rtp := _video_poker_rtp(game, "jacks_or_better", "standard", "mark_holds", "VIDEO-POKER-CHEAT-LOADED", 1200)
	if cheat_rtp <= honest_rtp + 0.10:
		failures.append("Video poker holdout did not meaningfully improve return (honest=%.3f cheat=%.3f)." % [honest_rtp, cheat_rtp])


func _check_video_poker_item_luck_alcohol(game: GameModule, failures: Array) -> void:
	var sober: RunState = _vp_fresh(game, "jacks_or_better", "VIDEO-POKER-ALCOHOL", 100000, "standard", 1, 1)
	sober.current_environment["security_profile"] = {"strictness": "tight", "pit_boss": {"enabled": true, "cycle_length": 2, "watched_turns": 1, "cheat_heat_bonus": 20}}
	var sober_deal := game.surface_action_command("video_poker_deal", 0, false, {}, sober, sober.current_environment)
	var sober_result := game.resolve_with_context("mark_holds", 5, sober, sober.current_environment, sober.create_rng("vp_sober_cheat"), sober_deal.get("ui_state", {}))
	var drunk: RunState = _vp_fresh(game, "jacks_or_better", "VIDEO-POKER-ALCOHOL", 100000, "standard", 1, 1)
	drunk.drunk_level = 85
	drunk.current_environment["security_profile"] = sober.current_environment["security_profile"]
	var drunk_deal := game.surface_action_command("video_poker_deal", 0, false, {}, drunk, drunk.current_environment)
	var drunk_result := game.resolve_with_context("mark_holds", 5, drunk, drunk.current_environment, drunk.create_rng("vp_sober_cheat"), drunk_deal.get("ui_state", {}))
	if int(drunk_result.get("suspicion_delta", 0)) <= int(sober_result.get("suspicion_delta", 0)):
		failures.append("Video poker cheat heat did not respond to alcohol pressure.")
	if int(sober_result.get("suspicion_delta", 0)) < 30:
		failures.append("Video poker cheat heat did not include security/pit-boss watch pressure.")
	var luck_low := _video_poker_rtp_with_luck(game, "VIDEO-POKER-LUCK-LOW", 0)
	var luck_high := _video_poker_rtp_with_luck(game, "VIDEO-POKER-LUCK-HIGH", 10)
	if luck_high <= luck_low:
		failures.append("Video poker returns did not respond to RunState luck (low=%.3f high=%.3f)." % [luck_low, luck_high])


func _video_poker_rtp_with_luck(game: GameModule, seed_text: String, luck: int) -> float:
	var run_state: RunState = _vp_fresh(game, "jacks_or_better", seed_text, 100000000, "standard", 1, 1)
	run_state.baseline_luck = luck
	var rng: RngStream = run_state.create_rng("vp_luck_rate")
	var staked := 0
	var net := 0
	var rounds := 600
	for _round in range(rounds):
		var before := run_state.bankroll
		var result := _video_poker_play_hand(game, run_state, rng, "draw")
		staked += int(result.get("video_poker_bet", 5))
		net += run_state.bankroll - before
	return 1.0 + float(net) / float(staked)


func _check_video_poker_double_up(game: GameModule, failures: Array) -> void:
	# A double-up gamble resolves wins and losses and applies the delta through the host.
	var run_state: RunState = _vp_fresh(game, "jacks_or_better", "VIDEO-POKER-DOUBLE", 100000000)
	var environment: Dictionary = run_state.current_environment
	var rng: RngStream = run_state.create_rng("vp_double")
	var rounds := 1000
	var wins := 0
	var losses := 0
	var any_delta := false
	for index in range(rounds):
		var state: Dictionary = (environment.get("game_states", {}) as Dictionary).get("video_poker", {})
		state["last_result"] = {"double_credits": 10, "double_chain": 0, "win_credits": 10, "hand": [], "coins": 5}
		var game_states: Dictionary = environment.get("game_states", {})
		game_states["video_poker"] = state
		environment["game_states"] = game_states
		run_state.current_environment = environment
		var ui := {"double_active": true, "double_pick": index % 4}
		var result := game.resolve_with_context("double_up", 0, run_state, environment, rng, ui)
		environment = run_state.current_environment
		var outcome := str(result.get("video_poker_double_outcome", ""))
		if outcome == "win":
			wins += 1
		elif outcome == "lose":
			losses += 1
		if int(result.get("bankroll_delta", 0)) != 0:
			any_delta = true
	if wins <= 0 or losses <= 0:
		failures.append("Video poker double-up did not produce both wins and losses (win=%d lose=%d)." % [wins, losses])
	if not any_delta:
		failures.append("Video poker double-up never moved bankroll.")
	var win_rate := float(wins) / float(rounds)
	if win_rate < 0.4 or win_rate > 0.6:
		failures.append("Video poker double-up win rate %.3f is not a fair gamble." % win_rate)


func _check_video_poker_rtp_bands(game: GameModule, failures: Array) -> void:
	var variants := ["jacks_or_better", "bonus_poker", "double_double_bonus", "deuces_wild", "joker_poker"]
	var tiers := ["full_pay", "standard", "short_pay"]
	var tier_probe_rows := {
		"jacks_or_better": "full_house",
		"bonus_poker": "full_house",
		"double_double_bonus": "full_house",
		"deuces_wild": "wild_royal",
		"joker_poker": "full_house",
	}
	var by_key := {}
	for variant_id in variants:
		for tier_id in tiers:
			var rtp := _video_poker_rtp(game, variant_id, tier_id, "draw", "VIDEO-POKER-RTP-%s-%s" % [variant_id.to_upper(), tier_id.to_upper()], 3000)
			by_key["%s:%s" % [variant_id, tier_id]] = rtp
			print("VIDEO_POKER %s/%s RTP = %.4f" % [variant_id, tier_id, rtp])
			if rtp < 0.70 or rtp > 1.08:
				failures.append("Video poker %s/%s RTP %.4f fell outside the sampled sane band." % [variant_id, tier_id, rtp])
	for variant_id in variants:
		var row_key := str(tier_probe_rows.get(variant_id, "full_house"))
		var full_mult := _video_poker_tier_row_mult(game, variant_id, "full_pay", row_key)
		var short_mult := _video_poker_tier_row_mult(game, variant_id, "short_pay", row_key)
		if full_mult <= short_mult:
			failures.append("Video poker %s full-pay row '%s' did not outrank short-pay (%d <= %d)." % [variant_id, row_key, full_mult, short_mult])


func _video_poker_tier_row_mult(game: GameModule, variant_id: String, tier_id: String, row_key: String) -> int:
	var variant: Dictionary = game.call("_variant", {"variant_id": variant_id, "paytable_tier_id": tier_id})
	var rows: Array = variant.get("rows", [])
	for row_value in rows:
		var row: Dictionary = row_value if typeof(row_value) == TYPE_DICTIONARY else {}
		if str(row.get("key", "")) == row_key:
			return int(row.get("mult", 0))
	return 0


func _video_poker_rtp(game: GameModule, variant_id: String, tier_id: String, action_id: String, seed_text: String, rounds: int) -> float:
	var run_state: RunState = _vp_fresh(game, variant_id, seed_text, 100000000, tier_id, 1, 1)
	var environment: Dictionary = run_state.current_environment
	var rng: RngStream = run_state.create_rng("vp_rtp")
	var staked := 0
	var net := 0
	for _round in range(rounds):
		run_state.suspicion = {"level": 0, "cues": [], "local_levels": {}}
		var before := run_state.bankroll
		var result := _video_poker_play_hand(game, run_state, rng, action_id)
		environment = run_state.current_environment
		staked += int(result.get("video_poker_bet", 20))
		net += run_state.bankroll - before
	return 1.0 + float(net) / float(staked)


func _video_poker_play_hand(game: GameModule, run_state: RunState, rng: RngStream, action_id: String) -> Dictionary:
	var environment: Dictionary = run_state.current_environment
	var bet_cmd: Dictionary = game.surface_action_command("video_poker_bet_max", 0, false, {}, run_state, environment)
	var ui: Dictionary = bet_cmd.get("ui_state", {})
	ui["hand_active"] = true
	var state: Dictionary = game.call("_machine_state", run_state, environment)
	var variant: Dictionary = game.call("_variant", state)
	var hand: Array = game.call("_opening_hand", run_state, state)
	ui["holds"] = game.call("_suggested_holds", hand, variant)
	return game.resolve_with_context(action_id, 5, run_state, environment, rng, ui)


func _check_pull_tabs_surface_contract(game: GameModule, failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("PULL-TABS-SURFACE-CONTRACT")
	var environment := _surface_contract_environment()
	var generated_state := game.generate_environment_state(run_state, environment, run_state.create_rng("pull_tab_contract_machine"))
	if generated_state.is_empty():
		failures.append("Pull Tabs did not generate finite deal state for an environment.")
	environment["game_states"] = {"pull_tabs": generated_state}
	var generated_deals: Array = generated_state.get("deals", [])
	var remaining_levels := {}
	for deal_value in generated_deals:
		var generated_deal: Dictionary = deal_value
		var sleeve: Array = generated_deal.get("ticket_sleeve", [])
		if sleeve.is_empty():
			failures.append("Pull Tabs generated deal did not prebuild a fixed ticket sleeve.")
		if int(generated_deal.get("remaining", -1)) != sleeve.size():
			failures.append("Pull Tabs generated deal remaining count did not match sleeve size.")
		if int(generated_deal.get("initial_removed_count", 0)) <= 0:
			failures.append("Pull Tabs generated deal did not remove an unknown opening run of tickets.")
		if int(generated_deal.get("ticket_count", 0)) != 150:
			failures.append("Pull Tabs generated deal did not use the 150-ticket column cap.")
		if (generated_deal.get("prizes", []) as Array).size() < 6:
			failures.append("Pull Tabs generated deal did not expose the full real-style prize ladder.")
		remaining_levels[str(generated_deal.get("remaining", 0))] = true
	if remaining_levels.size() != generated_deals.size():
		failures.append("Pull Tabs generated columns did not start at distinct stack levels.")
	var generated_item_state: Dictionary = generated_state.get("item_state", {})
	var xray_targets: Array = generated_item_state.get("xray_targets", [])
	if xray_targets.size() != mini(2, generated_deals.size()):
		failures.append("Pull Tabs x-ray glasses should preselect two column winner targets.")
	var xray_target_columns := {}
	for target_value in xray_targets:
		if typeof(target_value) != TYPE_DICTIONARY:
			failures.append("Pull Tabs x-ray target was not stored as a dictionary.")
			continue
		var target: Dictionary = target_value
		var deal_index := int(target.get("deal_index", -1))
		if deal_index < 0 or deal_index >= generated_deals.size():
			failures.append("Pull Tabs x-ray target pointed at an invalid column.")
		if int(target.get("payout", 0)) <= 0:
			failures.append("Pull Tabs x-ray target did not identify a winning prize.")
		if bool(target.get("consumed", false)):
			failures.append("Pull Tabs x-ray target should start unconsumed.")
		xray_target_columns[deal_index] = true
	if xray_target_columns.size() != xray_targets.size():
		failures.append("Pull Tabs x-ray glasses should target two distinct columns.")
	var environment_before_enter := JSON.stringify(environment)
	var enter_result := game.enter(run_state, environment)
	if not bool(enter_result.get("ok", false)):
		failures.append("Pull Tabs did not enter cleanly.")
	if JSON.stringify(environment) != environment_before_enter:
		failures.append("Pull Tabs entry mutated generated environment state.")
	var surface := game.surface_state(run_state, environment, {})
	if str(surface.get("surface_renderer", "")) != "pull_tab_machine":
		failures.append("Pull Tabs surface did not route to the pull-tab machine renderer.")
	if not bool(surface.get("surface_controls_native", false)):
		failures.append("Pull Tabs surface did not expose native surface controls.")
	if not bool(surface.get("surface_animates_idle", false)):
		failures.append("Pull Tabs surface did not request idle redraws for marquee animation.")
	if not bool(surface.get("surface_embeds_outcomes", false)):
		failures.append("Pull Tabs surface did not declare ticket-embedded outcomes.")
	if _surface_blocks_action_while(surface, "pull_tab_buy", "pull_tab_dispense") or _surface_blocks_action_while(surface, "pull_tab_buy_all", "pull_tab_dispense"):
		failures.append("Pull Tabs purchase actions should stay available while dispense animation/audio is active.")
	if not _surface_blocks_action_while(surface, "pull_tab_collect_tray", "pull_tab_dispense"):
		failures.append("Pull Tabs tray collection should still wait for active dispense animation.")
	var deals: Array = surface.get("pull_tab_deals", [])
	if deals.size() != 4:
		failures.append("Pull Tabs surface did not expose four dispenser deal rows.")
	for deal_value in deals:
		var deal: Dictionary = deal_value
		if str(deal.get("form", "")).is_empty() or str(deal.get("serial", "")).is_empty() or (deal.get("prize_rows", []) as Array).is_empty():
			failures.append("Pull Tabs deal flare is missing form, serial, or prize chart data.")
	var buy_all_click := _check_surface_command_non_mutating(game, "pull_tab_buy_all", 0, false, {}, run_state, environment, "pull-tab buy all", failures)
	if str(buy_all_click.get("action_id", "")) != "buy_tab_set" or int(buy_all_click.get("set_stake", 0)) <= 0:
		failures.append("Pull Tabs all-column button did not map to the four-ticket purchase action.")
	var buy_click := _check_surface_command_non_mutating(game, "pull_tab_buy", 0, false, {}, run_state, environment, "pull-tab buy", failures)
	if str(buy_click.get("action_kind", "")) != "legal" or str(buy_click.get("action_id", "")) != "buy_tab":
		failures.append("Pull Tabs buy button did not map to the legal ticket purchase action.")
	var machine_for_buy: Dictionary = (environment.get("game_states", {}) as Dictionary).get("pull_tabs", {})
	var deals_before_buy: Array = machine_for_buy.get("deals", [])
	var first_deal_before: Dictionary = deals_before_buy[0] if not deals_before_buy.is_empty() else {}
	var first_sleeve_before: Array = first_deal_before.get("ticket_sleeve", [])
	var expected_first_payout := _pull_tab_sleeve_entry_payout(first_deal_before, int(first_sleeve_before[0]) if not first_sleeve_before.is_empty() else -1)
	var machine_before := JSON.stringify(environment.get("game_states", {}))
	var before := _run_state_result_snapshot(run_state)
	var result := game.resolve_with_context("buy_tab", int(buy_click.get("set_stake", 1)), run_state, environment, run_state.create_rng("pull_tab_buy"), buy_click.get("ui_state", {}))
	_check_action_result_shape(result, "legal", failures)
	_check_action_result_applied(before, run_state, result, "pull-tab buy result", failures)
	_check_pull_tab_result_details(result, failures)
	if int(result.get("pull_tab_payout", -1)) != expected_first_payout:
		failures.append("Pull Tabs buy did not dispense the next predefined sleeve outcome.")
	if JSON.stringify(environment.get("game_states", {})) == machine_before:
		failures.append("Pull Tabs buy did not update persistent finite deal state.")
	var machine_after_buy: Dictionary = (environment.get("game_states", {}) as Dictionary).get("pull_tabs", {})
	var deals_after_buy: Array = machine_after_buy.get("deals", [])
	var first_deal_after: Dictionary = deals_after_buy[0] if not deals_after_buy.is_empty() else {}
	if not first_sleeve_before.is_empty() and (first_deal_after.get("ticket_sleeve", []) as Array).size() != maxi(0, first_sleeve_before.size() - 1):
		failures.append("Pull Tabs buy did not consume exactly one ticket from the fixed sleeve.")
	var tray_surface := game.surface_state(run_state, environment, {})
	if int(tray_surface.get("pull_tab_tray_count", 0)) <= 0 or (tray_surface.get("pull_tab_tray_stack", []) as Array).is_empty():
		failures.append("Pull Tabs surface did not leave the dispensed ticket in the machine tray.")
	if int(tray_surface.get("pull_tab_stack_count", 0)) != 0:
		failures.append("Pull Tabs buy moved a ticket directly into the play pile instead of the tray.")
	if (tray_surface.get("pull_tab_dispense_events", []) as Array).is_empty():
		failures.append("Pull Tabs buy did not expose tray-drop dispense animation events.")
	if str(tray_surface.get("pull_tab_last_ticket_id", "")).is_empty() or not tray_surface.has("pull_tab_stack_cursor"):
		failures.append("Pull Tabs surface did not expose dispenser animation and stack cursor state.")
	var collect_click := game.surface_action_command("pull_tab_collect_tray", 0, false, {}, run_state, environment)
	if not bool(collect_click.get("handled", false)) or not bool(collect_click.get("environment_changed", false)):
		failures.append("Pull Tabs tray click did not collect tray tickets into the play pile.")
	var stack_surface := game.surface_state(run_state, environment, collect_click.get("ui_state", {}))
	if int(stack_surface.get("pull_tab_stack_count", 0)) <= 0 or (stack_surface.get("pull_tab_stack", []) as Array).is_empty() or int(stack_surface.get("pull_tab_tray_count", 0)) != 0:
		failures.append("Pull Tabs tray collection did not expose the collected ticket stack.")
	var second_buy_click := _check_surface_command_non_mutating(game, "pull_tab_buy", 1, false, {}, run_state, environment, "second pull-tab buy", failures)
	if str(second_buy_click.get("action_id", "")) == "buy_tab":
		game.resolve_with_context("buy_tab", int(second_buy_click.get("set_stake", 1)), run_state, environment, run_state.create_rng("pull_tab_second_buy"), second_buy_click.get("ui_state", {}))
		game.surface_action_command("pull_tab_collect_tray", 0, false, {}, run_state, environment)
	var next_ticket_click := _check_surface_command_non_mutating(game, "pull_tab_next", 0, false, {}, run_state, environment, "pull-tab next ticket", failures)
	var next_ticket_state: Dictionary = next_ticket_click.get("ui_state", {})
	if int(next_ticket_state.get("pull_tab_stack_cursor", 0)) != mini(1, int(game.surface_state(run_state, environment, {}).get("pull_tab_stack_count", 1)) - 1):
		failures.append("Pull Tabs next-ticket navigation did not update UI-local stack cursor.")
	var reveal_state := {}
	var reveal_click := _check_surface_command_non_mutating(game, "pull_tab_reveal_next", 0, false, reveal_state, run_state, environment, "pull-tab reveal", failures)
	reveal_state = reveal_click.get("ui_state", {})
	var revealed_surface := game.surface_state(run_state, environment, reveal_state)
	var revealed_stack: Array = revealed_surface.get("pull_tab_stack", [])
	if revealed_stack.is_empty() or not bool((revealed_stack[0] as Dictionary).get("fully_revealed", false)):
		failures.append("Pull Tabs reveal command did not open all ticket rows from one click as UI-local state.")
	if str(reveal_click.get("action_id", "")) != "":
		failures.append("Pull Tabs reveal click should not immediately sort the ticket.")
	if str(revealed_surface.get("pull_tab_reveal_animation_id", "")).is_empty():
		failures.append("Pull Tabs reveal click did not expose a row-by-row peel animation.")
	if (revealed_surface.get("pull_tab_winner_pile", []) as Array).is_empty() == false or (revealed_surface.get("pull_tab_loser_pile", []) as Array).is_empty() == false:
		failures.append("Pull Tabs reveal moved a ticket into a pile before the file click.")
	var file_click := _check_surface_command_non_mutating(game, "pull_tab_file_ticket", 0, false, reveal_state, run_state, environment, "pull-tab file ticket", failures)
	if str(file_click.get("action_id", "")) != "sort_tab_ticket" or not bool(file_click.get("direct_resolve", false)):
		failures.append("Pull Tabs file click did not request a direct ticket-sort resolution.")
	if not bool(file_click.get("preserve_surface_ui_state", false)):
		failures.append("Pull Tabs file click should preserve UI-local animation state.")
	var file_state: Dictionary = file_click.get("ui_state", {})
	var file_surface := game.surface_state(run_state, environment, file_state)
	if str(file_surface.get("pull_tab_file_animation_id", "")).is_empty() or (file_surface.get("pull_tab_file_animation_ticket", {}) as Dictionary).is_empty():
		failures.append("Pull Tabs file click did not expose placement animation state.")
	var sort_before := _run_state_result_snapshot(run_state)
	var sort_result := game.resolve_with_context("sort_tab_ticket", 0, run_state, environment, run_state.create_rng("pull_tab_sort"), file_state)
	_check_action_result_shape(sort_result, "legal", failures)
	_check_action_result_applied(sort_before, run_state, sort_result, "pull-tab sort result", failures)
	_check_pull_tab_result_details(sort_result, failures)
	if int(sort_result.get("bankroll_delta", 0)) != 0:
		failures.append("Pull Tabs sorting an opened ticket should not pay bankroll immediately.")
	var sorted_surface := game.surface_state(run_state, environment, file_state)
	if (sorted_surface.get("pull_tab_winner_pile", []) as Array).is_empty() and (sorted_surface.get("pull_tab_loser_pile", []) as Array).is_empty():
		failures.append("Pull Tabs did not move a fully opened ticket into a winner or loser pile.")
	var hooks := game.environment_interactable_objects(run_state, environment)
	if hooks.is_empty():
		failures.append("Pull Tabs did not expose a room-side redemption clerk.")
	_clear_pull_tab_winners(environment)
	_set_pull_tab_loser_count(environment, 3)
	_inject_pull_tab_winner(environment, _pull_tab_test_ticket_result("clean", 5))
	var redeem_before := _run_state_result_snapshot(run_state)
	var redeem_command := game.environment_action_command("ticket_redeemer", "redeem_pull_tab_winners", run_state, environment, run_state.create_rng("pull_tab_redeem"))
	if not bool(redeem_command.get("handled", false)):
		failures.append("Pull Tabs redemption clerk did not handle winner redemption.")
	var redeem_result: Dictionary = redeem_command.get("result", {})
	if str(redeem_result.get("type", "")) != "game_hook" or int(redeem_result.get("bankroll_delta", 0)) <= 0:
		failures.append("Pull Tabs redemption did not return a cashout game_hook result.")
	else:
		if int(redeem_result.get("suspicion_delta", 0)) != 0:
			failures.append("Pull Tabs legitimate redemption added heat without a suspicious ticket trail.")
		GameModule.apply_result(run_state, redeem_result, run_state.create_rng("pull_tab_redeem_apply"))
		_check_action_result_applied(redeem_before, run_state, redeem_result, "pull-tab redemption result", failures)
	var redeemed_surface := game.surface_state(run_state, environment, reveal_state)
	if int(redeemed_surface.get("pull_tab_pending_payout", 0)) != 0:
		failures.append("Pull Tabs redemption did not clear pending winner payout.")
	_set_pull_tab_loser_count(environment, 0)
	for high_ticket_index in range(2):
		_inject_pull_tab_winner(environment, _pull_tab_test_ticket_result("high:%d" % high_ticket_index, 40))
	var pattern_redeem_before := _run_state_result_snapshot(run_state)
	var pattern_redeem_command := game.environment_action_command("ticket_redeemer", "redeem_pull_tab_winners", run_state, environment, run_state.create_rng("pull_tab_pattern_redeem"))
	var pattern_redeem_result: Dictionary = pattern_redeem_command.get("result", {})
	if not bool(pattern_redeem_command.get("handled", false)):
		failures.append("Pull Tabs suspicious cashout pattern was not handled by the redemption clerk.")
	elif int(pattern_redeem_result.get("suspicion_delta", 0)) <= 0:
		failures.append("Pull Tabs repeated high-value winners with no loser trail did not add cashier heat.")
	elif int(pattern_redeem_result.get("pull_tab_cashout_pattern_heat", 0)) <= 0:
		failures.append("Pull Tabs suspicious cashout did not report pattern heat.")
	elif int(pattern_redeem_result.get("pull_tab_loser_trail_count", -1)) != 0:
		failures.append("Pull Tabs suspicious cashout did not report the visible loser trail count.")
	else:
		GameModule.apply_result(run_state, pattern_redeem_result, run_state.create_rng("pull_tab_pattern_redeem_apply"))
		_check_action_result_applied(pattern_redeem_before, run_state, pattern_redeem_result, "pull-tab suspicious redemption result", failures)
	_check_pull_tab_tarot_reading_surface(game, failures)
	run_state.set_environment(environment)
	var restored: RunState = RunStateScript.new()
	restored.from_dict(run_state.to_dict())
	var restored_game_states: Dictionary = restored.current_environment.get("game_states", {})
	if not restored_game_states.has("pull_tabs"):
		failures.append("Pull Tabs generated deal state did not round-trip through RunState serialization.")


func _check_pull_tab_tarot_reading_surface(game: GameModule, failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("PULL-TABS-TAROT-READING")
	run_state.bankroll = 500
	run_state.add_item("tarot_card")
	run_state.set_active_item("tarot_card")
	var environment := _surface_contract_environment()
	var machine := game.generate_environment_state(run_state, environment, run_state.create_rng("pull_tab_tarot_machine"))
	var deals: Array = machine.get("deals", [])
	if deals.is_empty():
		failures.append("Pull Tabs tarot check could not generate a deal row.")
		return
	var deal: Dictionary = deals[0]
	var prizes: Array = deal.get("prizes", [])
	var winner_indices: Array = []
	for index in range(prizes.size()):
		if typeof(prizes[index]) != TYPE_DICTIONARY:
			continue
		if int((prizes[index] as Dictionary).get("payout", 0)) > 0:
			winner_indices.append(index)
	if winner_indices.is_empty():
		failures.append("Pull Tabs tarot check could not find a winning prize row.")
		return
	var first_winner := int(winner_indices[0])
	var second_winner := int(winner_indices[mini(1, winner_indices.size() - 1)])
	var controlled_sleeve := [-1, -1, first_winner, -1, second_winner, -1]
	var remaining_counts: Array = []
	for _index in range(prizes.size()):
		remaining_counts.append(0)
	for entry in controlled_sleeve:
		var prize_index := int(entry)
		if prize_index >= 0 and prize_index < remaining_counts.size():
			remaining_counts[prize_index] = int(remaining_counts[prize_index]) + 1
	var controlled_prizes: Array = []
	for index in range(prizes.size()):
		var prize: Dictionary = (prizes[index] as Dictionary).duplicate(true) if typeof(prizes[index]) == TYPE_DICTIONARY else {}
		prize["remaining"] = int(remaining_counts[index])
		controlled_prizes.append(prize)
	deal["ticket_sleeve"] = controlled_sleeve
	deal["remaining"] = controlled_sleeve.size()
	deal["sold"] = 0
	deal["unit_cursor"] = int(deal.get("initial_removed_count", 0))
	deal["prizes"] = controlled_prizes
	deals[0] = deal
	machine["deals"] = deals
	environment["game_states"] = {"pull_tabs": machine}
	var arm_command := game.active_item_command("tarot_card", run_state, environment, run_state.create_rng("pull_tab_tarot_arm"))
	if not bool(arm_command.get("handled", false)) or not bool(arm_command.get("environment_changed", false)):
		failures.append("Pull Tabs tarot active item did not arm the next ticket.")
	var buy_command := game.surface_action_command("pull_tab_buy", 0, false, {}, run_state, environment)
	var buy_result := game.resolve_with_context("buy_tab", int(buy_command.get("set_stake", 1)), run_state, environment, run_state.create_rng("pull_tab_tarot_buy"), buy_command.get("ui_state", {}))
	_check_pull_tab_result_details(buy_result, failures)
	var ticket: Dictionary = buy_result.get("pull_tab_ticket", {})
	if not bool(ticket.get("tarot_converted", false)):
		failures.append("Pull Tabs tarot purchase did not convert the bought ticket into a burned loser.")
	var reading: Array = ticket.get("tarot_reading", [])
	if reading.size() != 5:
		failures.append("Pull Tabs tarot reading did not store exactly the next five ticket outcomes.")
	var found_winner := false
	for row_value in reading:
		if typeof(row_value) == TYPE_DICTIONARY and int((row_value as Dictionary).get("payout", 0)) > 0:
			found_winner = true
			break
	if not found_winner:
		failures.append("Pull Tabs tarot reading missed controlled winning tickets in the next five outcomes.")
	var collect_command := game.surface_action_command("pull_tab_collect_tray", 0, false, {}, run_state, environment)
	var surface := game.surface_state(run_state, environment, collect_command.get("ui_state", {}))
	var stack: Array = surface.get("pull_tab_stack", [])
	if stack.is_empty():
		failures.append("Pull Tabs tarot ticket did not render in the collected play stack.")
	else:
		var stack_ticket: Dictionary = stack[0]
		if (stack_ticket.get("tarot_reading", []) as Array).size() != 5:
			failures.append("Pull Tabs tarot stack view dropped the next-five reading.")
		if (stack_ticket.get("prize_rows", []) as Array).is_empty():
			failures.append("Pull Tabs tarot stack view dropped the ticket prize legend.")


# Bar dice is a full-simulation poker-dice module: scoring correctness, keep/reroll
# affecting outcome, the loaded-die cheat odds/heat, and the house-edge band.
func _check_bar_dice_contract(library: ContentLibrary, failures: Array) -> void:
	var game: GameModule = _load_surface_contract_game(library, "bar_dice", failures)
	if game == null:
		return
	if not game.is_full_simulation():
		failures.append("Bar Dice must report the full-simulation gameplay model.")
	_check_bar_dice_scoring(game, failures)
	_check_bar_dice_generated_identity(game, failures)
	_check_bar_dice_surface_contract(game, failures)
	_check_bar_dice_result_visible(game, failures)
	_check_bar_dice_keep_reroll(game, failures)
	_check_bar_dice_match_and_bonuses(game, failures)
	_check_bar_dice_cheat(game, failures)
	_check_bar_dice_item_luck_alcohol(game, failures)
	_check_bar_dice_edge_band(game, library, failures)


# Guards against the surface stranding in the keep/reroll phase after a round
# resolves: the resolving command must release UI-local state so the host clears
# `rolled` and the next surface_state shows the settled house reveal and result.
func _check_bar_dice_result_visible(game: GameModule, failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("BAR-DICE-RESULT-VISIBLE")
	run_state.bankroll = 500
	var environment := _surface_contract_environment()
	environment["game_states"] = {"bar_dice": game.generate_environment_state(run_state, environment, run_state.create_rng("bar_dice_visible_state"))}
	run_state.current_environment = environment.duplicate(true)
	var roll_cmd := game.surface_action_command("bar_dice_roll", 0, false, {}, run_state, run_state.current_environment)
	var rolled_ui: Dictionary = roll_cmd.get("ui_state", {})
	# A confirmed resolve must resolve and must NOT preserve UI-local state, or the
	# host keeps `rolled` set and the surface never leaves the select phase.
	var confirm_cmd := game.surface_action_command("bar_dice_resolve", 0, true, rolled_ui, run_state, run_state.current_environment)
	if not bool(confirm_cmd.get("resolve", false)):
		failures.append("Bar Dice confirmed resolve did not request resolution.")
	if bool(confirm_cmd.get("preserve_surface_ui_state", false)):
		failures.append("Bar Dice resolving command preserved UI-local state, stranding the surface in the select phase.")
	var result := game.resolve_with_context("roll", 8, run_state, run_state.current_environment, run_state.create_rng("bar_dice_visible_resolve"), confirm_cmd.get("ui_state", rolled_ui))
	if not bool(result.get("ok", false)):
		failures.append("Bar Dice resolve did not complete a round.")
	# Emulate the host clearing UI-local state after a non-preserving resolve.
	var settled := game.surface_state(run_state, run_state.current_environment, {})
	if str(settled.get("phase", "")) != "settled":
		failures.append("Bar Dice surface did not show the settled result after resolving (phase=%s)." % str(settled.get("phase", "")))
	if not bool(settled.get("house_revealed", false)):
		failures.append("Bar Dice settled surface did not reveal the house dice after resolving.")
	if str(settled.get("result_message", "")).strip_edges().is_empty():
		failures.append("Bar Dice settled surface did not expose the round result message after resolving.")


func _check_bar_dice_scoring(game: GameModule, failures: Array) -> void:
	var cases := {
		"five_kind": [4, 4, 4, 4, 4],
		"four_kind": [6, 6, 6, 6, 2],
		"full_house": [6, 6, 6, 2, 2],
		"three_kind": [5, 5, 5, 3, 1],
		"two_pair": [5, 5, 3, 3, 1],
		"one_pair": [5, 5, 4, 3, 1],
		"high_card": [6, 1, 4, 2, 3],
	}
	for expected_category in cases.keys():
		var score: Dictionary = game.call("_score", cases[expected_category])
		if str(score.get("category", "")) != expected_category:
			failures.append("Bar Dice scored %s as %s instead of %s." % [str(cases[expected_category]), str(score.get("category", "")), expected_category])
	var straight_low: Dictionary = game.call("_score", [1, 2, 3, 4, 5])
	if str(straight_low.get("category", "")) != "straight":
		failures.append("Bar Dice did not score a 1-5 straight.")
	var straight_high: Dictionary = game.call("_score", [2, 3, 4, 5, 6])
	if str(straight_high.get("category", "")) != "straight":
		failures.append("Bar Dice did not score a 2-6 straight.")
	var full_house: Dictionary = game.call("_score", [6, 6, 6, 2, 2])
	var three_kind: Dictionary = game.call("_score", [6, 6, 6, 5, 4])
	if int(game.call("_compare_signatures", full_house.get("signature", []), three_kind.get("signature", []))) <= 0:
		failures.append("Bar Dice full house did not beat three of a kind.")
	var five_kind: Dictionary = game.call("_score", [3, 3, 3, 3, 3])
	if int(game.call("_compare_signatures", five_kind.get("signature", []), full_house.get("signature", []))) <= 0:
		failures.append("Bar Dice five of a kind did not beat a full house.")
	var high_trips: Dictionary = game.call("_score", [6, 6, 6, 1, 2])
	var low_trips: Dictionary = game.call("_score", [5, 5, 5, 1, 2])
	if int(game.call("_compare_signatures", high_trips.get("signature", []), low_trips.get("signature", []))) <= 0:
		failures.append("Bar Dice did not break a trips tie by the higher pack.")
	var same_trips: Dictionary = game.call("_score", [6, 6, 6, 1, 2])
	if int(game.call("_compare_signatures", high_trips.get("signature", []), same_trips.get("signature", []))) != 0:
		failures.append("Bar Dice identical packs did not compare as a tie.")
	var ship_score: Dictionary = game.call("_score_for_ruleset", [6, 5, 4, 6, 5], "ship_captain_crew")
	if str(ship_score.get("category", "")) != "perfect_cargo":
		failures.append("Bar Dice ship-captain-crew did not score a heavy cargo pack.")
	var seven_score: Dictionary = game.call("_score_for_ruleset", [6, 1, 2, 2, 5], "over_under_7")
	if str(seven_score.get("category", "")) != "bar_seven":
		failures.append("Bar Dice over-under-seven did not find a seven pair.")
	var bluff_score: Dictionary = game.call("_score_for_ruleset", [4, 4, 4, 2, 1], "bluff_call")
	if str(bluff_score.get("category", "")) != "called_trips":
		failures.append("Bar Dice liar-call ruleset did not score trips as a called trips pack.")


func _check_bar_dice_generated_identity(game: GameModule, failures: Array) -> void:
	var run_a: RunState = RunStateScript.new()
	run_a.start_new("BAR-DICE-GENERATED-A")
	var environment_a := _surface_contract_environment()
	var state_a: Dictionary = game.generate_environment_state(run_a, environment_a, run_a.create_rng("bar_dice_identity"))
	var run_b: RunState = RunStateScript.new()
	run_b.start_new("BAR-DICE-GENERATED-A")
	var environment_b := _surface_contract_environment()
	var state_b: Dictionary = game.generate_environment_state(run_b, environment_b, run_b.create_rng("bar_dice_identity"))
	if JSON.stringify(state_a) != JSON.stringify(state_b):
		failures.append("Bar Dice generated table identity is not deterministic for the same seed.")
	for required_key in ["ruleset_family", "edge_tier", "stake_ladder", "bonus_mode", "progressive_pot", "loaded_die", "table_key"]:
		if not state_a.has(required_key):
			failures.append("Bar Dice generated state is missing %s." % required_key)
	var ladder: Array = state_a.get("stake_ladder", [])
	if ladder.size() < 3:
		failures.append("Bar Dice generated chip ladder is too shallow.")


func _check_bar_dice_surface_contract(game: GameModule, failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("BAR-DICE-SURFACE-CONTRACT")
	var environment := _surface_contract_environment()
	var generated_state := game.generate_environment_state(run_state, environment, run_state.create_rng("bar_dice_contract_state"))
	if generated_state.is_empty():
		failures.append("Bar Dice did not generate table identity state.")
	environment["game_states"] = {"bar_dice": generated_state}
	var surface := game.surface_state(run_state, environment, {})
	if str(surface.get("surface_renderer", "")) != "dice_table":
		failures.append("Bar Dice surface did not route to the dice-table renderer.")
	if not bool(surface.get("surface_controls_native", false)):
		failures.append("Bar Dice surface did not expose native surface controls.")
	if not bool(surface.get("surface_embeds_outcomes", false)):
		failures.append("Bar Dice surface did not declare embedded outcomes.")
	if bool(surface.get("surface_stake_controls_required", true)):
		failures.append("Bar Dice should use its generated chip ladder instead of host stake controls.")
	if (surface.get("player", []) as Array).size() != 5:
		failures.append("Bar Dice surface did not expose a five-die player cup.")
	if (surface.get("paytable_rows", []) as Array).is_empty():
		failures.append("Bar Dice surface did not expose the paytable for the info panel.")
	if (surface.get("stake_ladder", []) as Array).size() < 3 or int(surface.get("active_stake", 0)) <= 0:
		failures.append("Bar Dice surface did not expose a generated chip ladder and active stake.")
	if str(surface.get("ruleset_family", "")).is_empty() or str(surface.get("bonus_mode", "")).is_empty():
		failures.append("Bar Dice surface did not expose generated table identity.")
	var stake_click := _check_surface_command_non_mutating(game, "bar_dice_stake", 0, false, {}, run_state, environment, "bar dice stake", failures)
	if int((stake_click.get("ui_state", {}) as Dictionary).get("selected_stake_index", -1)) != 0:
		failures.append("Bar Dice chip selection did not update UI-local stake state.")
	var roll_click := _check_surface_command_non_mutating(game, "bar_dice_roll", 0, false, {}, run_state, environment, "bar dice roll", failures)
	var rolled_state: Dictionary = roll_click.get("ui_state", {})
	if not bool(rolled_state.get("rolled", false)) or (rolled_state.get("dice", []) as Array).size() != 5:
		failures.append("Bar Dice roll did not open a five-die keep/reroll phase as UI-local state.")
	var select_surface := game.surface_state(run_state, environment, rolled_state)
	if str(select_surface.get("phase", "")) != "select":
		failures.append("Bar Dice did not enter the keep/reroll select phase after a roll.")
	var mark_click := _check_surface_command_non_mutating(game, "bar_dice_select", 0, false, rolled_state, run_state, environment, "bar dice select", failures)
	if not (mark_click.get("ui_state", {}) as Dictionary).get("reroll", []).has(0):
		failures.append("Bar Dice die click did not mark the die for reroll.")
	var resolve_click := game.surface_action_command("bar_dice_resolve", 0, false, rolled_state, run_state, environment)
	if str(resolve_click.get("action_id", "")) != "roll" or str(resolve_click.get("action_kind", "")) != "legal":
		failures.append("Bar Dice resolve did not map to the legal roll action.")
	var load_click := _check_surface_command_non_mutating(game, "bar_dice_load", 0, false, rolled_state, run_state, environment, "bar dice load", failures)
	if str(load_click.get("action_id", "")) != "loaded_toss" or str(load_click.get("action_kind", "")) != "cheat":
		failures.append("Bar Dice loaded toss did not map to the risky cheat action.")
	if int((load_click.get("ui_state", {}) as Dictionary).get("loaded_value", 0)) < 1:
		failures.append("Bar Dice loaded toss did not arm a rigged die value hint.")
	var palm_click := _check_surface_command_non_mutating(game, "bar_dice_palm", 0, false, rolled_state, run_state, environment, "bar dice palm", failures)
	if str(palm_click.get("action_id", "")) != "palmed_swap" or str(palm_click.get("action_kind", "")) != "cheat":
		failures.append("Bar Dice palmed swap did not map to the second cheat action.")
	var selected_state := rolled_state.duplicate(true)
	selected_state["selected_action_id"] = "loaded_toss"
	selected_state["selected_action_kind"] = "cheat"
	var loaded_surface := game.surface_state(run_state, environment, selected_state)
	if not (loaded_surface.get("native_selected_surface_actions", []) as Array).has("bar_dice_load"):
		failures.append("Bar Dice surface did not mark the loaded toss region selected.")
	selected_state["selected_action_id"] = "palmed_swap"
	var palm_surface := game.surface_state(run_state, environment, selected_state)
	if not (palm_surface.get("native_selected_surface_actions", []) as Array).has("bar_dice_palm"):
		failures.append("Bar Dice surface did not mark the palmed swap region selected.")
	if (loaded_surface.get("surface_animation_channels", []) as Array).is_empty():
		failures.append("Bar Dice surface did not declare a tumble animation channel.")


func _check_bar_dice_keep_reroll(game: GameModule, failures: Array) -> void:
	# Keeping every die versus rerolling every die from the same opening and stream
	# must produce different final dice, proving keep/reroll affects the outcome.
	var keep_all := _bar_dice_resolve_with_reroll(game, "BAR-DICE-KEEP-REROLL", [])
	var reroll_all := _bar_dice_resolve_with_reroll(game, "BAR-DICE-KEEP-REROLL", [0, 1, 2, 3, 4])
	var kept_dice: Array = keep_all.get("bar_dice_player_dice", [])
	var rerolled_dice: Array = reroll_all.get("bar_dice_player_dice", [])
	if kept_dice.size() != 5 or rerolled_dice.size() != 5:
		failures.append("Bar Dice resolve did not report final player dice.")
		return
	if JSON.stringify(kept_dice) == JSON.stringify(rerolled_dice):
		failures.append("Bar Dice keep/reroll selection did not change the final dice.")


func _bar_dice_resolve_with_reroll(game: GameModule, seed_text: String, reroll: Array) -> Dictionary:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new(seed_text)
	run_state.bankroll = 100000
	var environment := _surface_contract_environment()
	environment["game_states"] = {"bar_dice": game.generate_environment_state(run_state, environment, run_state.create_rng("bar_dice_keep_state"))}
	run_state.current_environment = environment.duplicate(true)
	var roll_command: Dictionary = game.surface_action_command("bar_dice_roll", 0, false, {}, run_state, run_state.current_environment)
	var ui: Dictionary = roll_command.get("ui_state", {})
	ui["reroll"] = reroll
	return game.resolve_with_context("roll", 10, run_state, run_state.current_environment, run_state.create_rng("bar_dice_keep_resolve"), ui)


func _check_bar_dice_match_and_bonuses(game: GameModule, failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("BAR-DICE-MATCH-BONUS")
	run_state.bankroll = 100000
	var environment := _surface_contract_environment()
	environment["game_states"] = {"bar_dice": _bar_dice_state_for(game, run_state, environment, "poker_dice", "standard", "progressive")}
	run_state.current_environment = environment.duplicate(true)
	var result := _bar_dice_play_round(game, run_state, run_state.create_rng("bar_dice_match_bonus"), "roll")
	var legs: Array = result.get("bar_dice_match_legs", [])
	if legs.size() < 2 or legs.size() > 3:
		failures.append("Bar Dice match play did not resolve a bounded best-of-three leg set.")
	var player_legs := int(result.get("bar_dice_player_legs", 0))
	var house_legs := int(result.get("bar_dice_house_legs", 0))
	var outcome := str(result.get("bar_dice_outcome", ""))
	if outcome == "win" and player_legs <= house_legs:
		failures.append("Bar Dice match win was inconsistent with leg totals.")
	if outcome == "lose" and house_legs <= player_legs:
		failures.append("Bar Dice match loss was inconsistent with leg totals.")
	if int(result.get("bar_dice_stake", 0)) <= 0 or int(result.get("bar_dice_side_bet", -1)) < 0:
		failures.append("Bar Dice result did not report stake and side-bet math.")
	var forced_state: Dictionary = run_state.current_environment.get("game_states", {}).get("bar_dice", {})
	if int(forced_state.get("progressive_pot", 0)) < int(forced_state.get("progressive_base", 0)):
		failures.append("Bar Dice progressive meter fell below its generated base.")
	var press_seed: RunState = RunStateScript.new()
	press_seed.start_new("BAR-DICE-PRESS-OFFER")
	press_seed.bankroll = 100000
	var press_environment := _surface_contract_environment()
	press_environment["game_states"] = {"bar_dice": _bar_dice_state_for(game, press_seed, press_environment, "poker_dice", "friendly", "press")}
	press_seed.current_environment = press_environment.duplicate(true)
	var found_press := false
	var rng: RngStream = press_seed.create_rng("bar_dice_press_offer")
	for _i in range(160):
		var press_result := _bar_dice_play_round(game, press_seed, rng, "roll")
		var state: Dictionary = press_seed.current_environment.get("game_states", {}).get("bar_dice", {})
		var last_result: Dictionary = state.get("last_result", {})
		if bool((last_result.get("press_offer", {}) as Dictionary).get("available", false)):
			found_press = true
			var before := _run_state_result_snapshot(press_seed)
			var resolved_press := game.resolve_with_context("press", int(press_result.get("bar_dice_stake", 1)), press_seed, press_seed.current_environment, rng, {})
			_check_action_result_shape(resolved_press, "legal", failures)
			_check_action_result_application_contract(before, press_seed, resolved_press, "bar dice press result", failures)
			break
	if not found_press:
		failures.append("Bar Dice did not produce a press/double-up offer after repeated clean wins.")


func _check_bar_dice_cheat(game: GameModule, failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("BAR-DICE-CHEAT")
	run_state.bankroll = 100000
	var environment := _surface_contract_environment()
	environment["game_states"] = {"bar_dice": game.generate_environment_state(run_state, environment, run_state.create_rng("bar_dice_cheat_state"))}
	run_state.current_environment = environment.duplicate(true)
	var before := _run_state_result_snapshot(run_state)
	var roll_command: Dictionary = game.surface_action_command("bar_dice_roll", 0, false, {}, run_state, run_state.current_environment)
	var ui: Dictionary = roll_command.get("ui_state", {})
	var loaded_result := game.resolve_with_context("loaded_toss", 10, run_state, run_state.current_environment, run_state.create_rng("bar_dice_cheat_resolve"), ui)
	_check_action_result_shape(loaded_result, "cheat", failures)
	if int(loaded_result.get("suspicion_delta", 0)) <= 0:
		failures.append("Bar Dice loaded toss did not raise suspicion heat.")
	if not bool(loaded_result.get("bar_dice_loaded", false)) or int(loaded_result.get("bar_dice_loaded_value", 0)) < 1:
		failures.append("Bar Dice loaded toss did not record the rigged die value.")
	_check_action_result_application_contract(before, run_state, loaded_result, "bar dice loaded result", failures)
	var palm_state: RunState = RunStateScript.new()
	palm_state.start_new("BAR-DICE-PALM-CHEAT")
	palm_state.bankroll = 100000
	var palm_environment := _surface_contract_environment()
	palm_environment["game_states"] = {"bar_dice": game.generate_environment_state(palm_state, palm_environment, palm_state.create_rng("bar_dice_palm_state"))}
	palm_state.current_environment = palm_environment.duplicate(true)
	var palm_roll: Dictionary = game.surface_action_command("bar_dice_roll", 0, false, {}, palm_state, palm_state.current_environment)
	var palm_result := game.resolve_with_context("palmed_swap", 10, palm_state, palm_state.current_environment, palm_state.create_rng("bar_dice_palm_resolve"), palm_roll.get("ui_state", {}))
	_check_action_result_shape(palm_result, "cheat", failures)
	if not bool(palm_result.get("bar_dice_palmed", false)) or int(palm_result.get("suspicion_delta", 0)) <= 0:
		failures.append("Bar Dice palmed swap did not improve a die with suspicion heat.")
	var honest_wins := _bar_dice_win_rate(game, "roll", "BAR-DICE-HONEST")
	var loaded_wins := _bar_dice_win_rate(game, "loaded_toss", "BAR-DICE-LOADED")
	if loaded_wins <= honest_wins + 0.05:
		failures.append("Bar Dice loaded die did not meaningfully improve win odds (honest=%.3f loaded=%.3f)." % [honest_wins, loaded_wins])
	var palmed_wins := _bar_dice_win_rate(game, "palmed_swap", "BAR-DICE-PALMED")
	if palmed_wins <= honest_wins + 0.05:
		failures.append("Bar Dice palmed swap did not meaningfully improve win odds (honest=%.3f palmed=%.3f)." % [honest_wins, palmed_wins])


func _bar_dice_win_rate(game: GameModule, action_id: String, seed_text: String) -> float:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new(seed_text)
	run_state.bankroll = 100000000
	var environment := _surface_contract_environment()
	environment["game_states"] = {"bar_dice": game.generate_environment_state(run_state, environment, run_state.create_rng("bar_dice_winrate_state"))}
	run_state.current_environment = environment.duplicate(true)
	var rng: RngStream = run_state.create_rng("bar_dice_winrate")
	var rounds := 4000
	var wins := 0
	for _round in range(rounds):
		run_state.suspicion = {"level": 0, "cues": [], "local_levels": {}}
		var result := _bar_dice_play_round(game, run_state, rng, action_id)
		if str(result.get("bar_dice_outcome", "")) == "win":
			wins += 1
	return float(wins) / float(rounds)


func _check_bar_dice_item_luck_alcohol(game: GameModule, failures: Array) -> void:
	var sober: RunState = RunStateScript.new()
	sober.start_new("BAR-DICE-ALCOHOL-SOBER")
	sober.bankroll = 100000
	var sober_environment := _surface_contract_environment()
	sober_environment["security_profile"] = {"pit_boss": {"enabled": true, "cycle_length": 2, "watched_turns": 1, "cheat_heat_bonus": 20}}
	sober_environment["game_states"] = {"bar_dice": _bar_dice_state_for(game, sober, sober_environment, "poker_dice", "standard", "hot_hand")}
	sober.current_environment = sober_environment.duplicate(true)
	var sober_roll: Dictionary = game.surface_action_command("bar_dice_roll", 0, false, {}, sober, sober.current_environment)
	var sober_result := game.resolve_with_context("loaded_toss", 10, sober, sober.current_environment, sober.create_rng("bar_dice_sober"), sober_roll.get("ui_state", {}))
	var drunk: RunState = RunStateScript.new()
	drunk.start_new("BAR-DICE-ALCOHOL-SOBER")
	drunk.bankroll = 100000
	drunk.drunk_level = 85
	var drunk_environment := _surface_contract_environment()
	drunk_environment["security_profile"] = sober_environment["security_profile"]
	drunk_environment["game_states"] = {"bar_dice": _bar_dice_state_for(game, drunk, drunk_environment, "poker_dice", "standard", "hot_hand")}
	drunk.current_environment = drunk_environment.duplicate(true)
	var drunk_roll: Dictionary = game.surface_action_command("bar_dice_roll", 0, false, {}, drunk, drunk.current_environment)
	var drunk_result := game.resolve_with_context("loaded_toss", 10, drunk, drunk.current_environment, drunk.create_rng("bar_dice_sober"), drunk_roll.get("ui_state", {}))
	if int(drunk_result.get("suspicion_delta", 0)) <= int(sober_result.get("suspicion_delta", 0)):
		failures.append("Bar Dice cheat heat did not respond to alcohol pressure.")
	var luck_low := _bar_dice_win_rate_with_luck(game, "BAR-DICE-LUCK-LOW", 0)
	var luck_high := _bar_dice_win_rate_with_luck(game, "BAR-DICE-LUCK-HIGH", 8)
	if luck_high <= luck_low:
		failures.append("Bar Dice match odds did not respond to RunState luck (low=%.3f high=%.3f)." % [luck_low, luck_high])
	var watched_heat := int(sober_result.get("suspicion_delta", 0))
	if watched_heat < 20:
		failures.append("Bar Dice cheat heat did not include pit-boss/security watch pressure.")


func _bar_dice_win_rate_with_luck(game: GameModule, seed_text: String, luck: int) -> float:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new(seed_text)
	run_state.bankroll = 100000000
	run_state.baseline_luck = luck
	var environment := _surface_contract_environment()
	environment["game_states"] = {"bar_dice": _bar_dice_state_for(game, run_state, environment, "poker_dice", "standard", "hot_hand")}
	run_state.current_environment = environment.duplicate(true)
	var rng: RngStream = run_state.create_rng("bar_dice_luck_rate")
	var rounds := 1200
	var wins := 0
	for _round in range(rounds):
		var result := _bar_dice_play_round(game, run_state, rng, "roll")
		if str(result.get("bar_dice_outcome", "")) == "win":
			wins += 1
	return float(wins) / float(rounds)


func _check_bar_dice_edge_band(game: GameModule, _library: ContentLibrary, failures: Array) -> void:
	var rulesets := ["poker_dice", "ship_captain_crew", "over_under_7", "bluff_call"]
	var tiers := ["friendly", "standard", "sharp"]
	for ruleset in rulesets:
		for tier in tiers:
			_check_bar_dice_edge_for(game, str(ruleset), str(tier), failures)


func _check_bar_dice_edge_for(game: GameModule, ruleset: String, tier: String, failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("BAR-DICE-MC-EDGE-%s-%s" % [ruleset, tier])
	run_state.bankroll = 100000000
	var environment := _surface_contract_environment()
	environment["game_states"] = {"bar_dice": _bar_dice_state_for(game, run_state, environment, ruleset, tier, "hot_hand")}
	run_state.current_environment = environment.duplicate(true)
	var rng: RngStream = run_state.create_rng("bar_dice_edge")
	var rounds := 1000
	var staked := 0
	var net := 0
	for _round in range(rounds):
		var before := run_state.bankroll
		var result := _bar_dice_play_round(game, run_state, rng, "roll")
		staked += int(result.get("bar_dice_stake", 0)) + int(result.get("bar_dice_side_bet", 0))
		net += run_state.bankroll - before
	var edge := -float(net) / float(staked)
	print("BAR_DICE %s/%s house edge over %d rounds = %.4f" % [ruleset, tier, rounds, edge])
	var min_edge := 0.01
	var max_edge := 0.20 if tier == "sharp" else 0.16
	if edge < min_edge or edge > max_edge:
		failures.append("Bar Dice %s/%s house edge %.4f fell outside the sane band." % [ruleset, tier, edge])


func _bar_dice_play_round(game: GameModule, run_state: RunState, rng: RngStream, action_id: String) -> Dictionary:
	var environment: Dictionary = run_state.current_environment
	var roll_command: Dictionary = game.surface_action_command("bar_dice_roll", 0, false, {}, run_state, environment)
	var ui: Dictionary = roll_command.get("ui_state", {})
	var select_surface := game.surface_state(run_state, environment, ui)
	ui["reroll"] = select_surface.get("suggested_reroll", [])
	return game.resolve_with_context(action_id, 10, run_state, environment, rng, ui)


func _bar_dice_state_for(game: GameModule, run_state: RunState, environment: Dictionary, ruleset: String, tier: String, bonus_mode: String) -> Dictionary:
	var state: Dictionary = game.generate_environment_state(run_state, environment, run_state.create_rng("bar_dice_forced_%s_%s_%s" % [ruleset, tier, bonus_mode]))
	state["ruleset_family"] = ruleset
	state["ruleset_label"] = {
		"poker_dice": "Poker Dice",
		"ship_captain_crew": "Ship Captain Crew",
		"over_under_7": "Over Under Seven",
		"bluff_call": "Liar Call",
	}.get(ruleset, "Poker Dice")
	state["edge_tier"] = tier
	state["edge_label"] = {
		"friendly": "Loose Rail",
		"standard": "House Rack",
		"sharp": "Sharp Cup",
	}.get(tier, "House Rack")
	state["bonus_mode"] = bonus_mode
	state["bonus_label"] = {
		"hot_hand": "Hot Hand Side Bet",
		"progressive": "Five-Kind Progressive",
		"press": "Clean-Win Press",
	}.get(bonus_mode, "Hot Hand Side Bet")
	state["stake_ladder"] = [2, 5, 10, 20, 40]
	state["selected_stake_index"] = 2
	state["progressive_base"] = 600
	state["progressive_pot"] = 600
	return state


func _check_surface_command_non_mutating(game: GameModule, action: String, index: int, confirm_requested: bool, ui_state: Dictionary, run_state: RunState, environment: Dictionary, label: String, failures: Array) -> Dictionary:
	var before := JSON.stringify(run_state.to_dict())
	var command: Dictionary = game.surface_action_command(action, index, confirm_requested, ui_state, run_state, environment)
	if not bool(command.get("handled", false)):
		failures.append("Surface command was not handled: %s." % label)
	if JSON.stringify(run_state.to_dict()) != before:
		failures.append("Surface command mutated RunState before resolution: %s." % label)
	return command


func _surface_blocks_action_while(surface_state: Dictionary, action_id: String, animation_channel: String) -> bool:
	for block_value in surface_state.get("surface_action_blocks", []):
		if typeof(block_value) != TYPE_DICTIONARY:
			continue
		var block: Dictionary = block_value
		if str(block.get("while_animation", "")) != animation_channel:
			continue
		if str(block.get("action", "")) == action_id:
			return true
		for blocked_action in block.get("actions", []):
			if str(blocked_action) == action_id:
				return true
	return false


func _surface_blocks_action(surface_state: Dictionary, action_id: String) -> bool:
	for block_value in surface_state.get("surface_action_blocks", []):
		if typeof(block_value) != TYPE_DICTIONARY:
			continue
		var block: Dictionary = block_value
		if str(block.get("action", "")) == action_id:
			return true
		for blocked_action in block.get("actions", []):
			if str(blocked_action) == action_id:
				return true
	return false


# Captures the RunState domains ActionResult is allowed to update.
func _run_state_result_snapshot(run_state: RunState) -> Dictionary:
	return {
		"bankroll": run_state.bankroll,
		"suspicion": run_state.suspicion_level(),
		"suspicion_location_id": run_state.current_suspicion_location_id(),
		"suspicion_levels": (run_state.suspicion.get("local_levels", {}) as Dictionary).duplicate(true),
		"drunk_level": run_state.drunk_level,
		"pending_drunk_absorption": run_state.pending_drunk_absorption_amount(),
		"alcoholic_level": run_state.alcoholic_level,
		"baseline_luck": run_state.baseline_luck,
		"debt_count": run_state.debt.size(),
		"story_count": run_state.story_log.size(),
		"rng_state": run_state.rng_state,
	}


# Checks the shared ActionResult/result-delta shape.
func _check_action_result_shape(result: Dictionary, expected_kind: String, failures: Array) -> void:
	if not bool(result.get("ok", false)):
		failures.append("GameModule returned an unsuccessful result for %s action." % expected_kind)
	if str(result.get("type", "")) != "game_action":
		failures.append("ActionResult should identify game_action results.")
	if str(result.get("action_kind", "")) != expected_kind:
		failures.append("ActionResult action kind mismatch: expected %s." % expected_kind)
	var deltas: Dictionary = result.get("deltas", {})
	var required_delta_keys := [
		"bankroll_delta",
		"suspicion_delta",
		"alcohol_intake",
		"drunk_delta",
		"alcoholic_delta",
		"baseline_luck_delta",
		"debt_changes",
		"inventory_add",
		"inventory_remove",
		"flags_set",
		"travel_hooks_add",
		"travel_changes",
		"story_log",
		"messages",
		"ended",
		"item_hooks",
		"event_hooks",
		"demo_finale",
	]
	for key in required_delta_keys:
		if not deltas.has(key):
			failures.append("ActionResult deltas missing key: %s." % key)
	if int(result.get("bankroll_delta", 0)) != int(deltas.get("bankroll_delta", 0)):
		failures.append("ActionResult top-level bankroll_delta does not match deltas.")
	if int(result.get("suspicion_delta", 0)) != int(deltas.get("suspicion_delta", 0)):
		failures.append("ActionResult top-level suspicion_delta does not match deltas.")
	if bool(result.get("ended", false)) != bool(deltas.get("ended", false)):
		failures.append("ActionResult top-level ended does not match deltas.")
	if str(result.get("state", "")) == "":
		failures.append("ActionResult should include continue/ended state.")
	if str(result.get("message", "")).is_empty():
		failures.append("ActionResult should include a player-facing message.")
	if result.get("messages", []).is_empty() or deltas.get("messages", []).is_empty():
		failures.append("ActionResult should include messages in the shared delta shape.")
	for ui_key in ["host", "button_metadata", "overlay_state", "focus", "hover", "ui_state"]:
		if result.has(ui_key) or deltas.has(ui_key):
			failures.append("ActionResult leaked UI state key: %s." % ui_key)


# Checks both legacy self-applied results and pure host-applied module results.
func _check_action_result_application_contract(before: Dictionary, run_state: RunState, result: Dictionary, label: String, failures: Array) -> void:
	if not bool(result.get("ok", false)):
		return
	if not bool(result.get("host_apply_result", false)):
		_check_action_result_applied(before, run_state, result, label, failures)
		return
	if run_state.bankroll != int(before.get("bankroll", 0)):
		failures.append("RunState bankroll changed before host apply for %s." % label)
	var result_environment_id := str(result.get("environment_id", ""))
	if not result_environment_id.is_empty():
		var location_id := run_state.suspicion_location_id_for_environment_id(result_environment_id)
		var before_levels: Dictionary = before.get("suspicion_levels", {})
		var expected_suspicion := int(before_levels.get(location_id, 0))
		if run_state.suspicion_level_for_environment_id(result_environment_id) != expected_suspicion:
			failures.append("RunState suspicion changed before host apply for %s." % label)
	elif run_state.suspicion_level() != int(before.get("suspicion", 0)):
		failures.append("RunState suspicion changed before host apply for %s." % label)
	if run_state.story_log.size() != int(before.get("story_count", 0)):
		failures.append("RunState story log changed before host apply for %s." % label)
	var apply_rng := run_state.create_rng("%s_host_apply" % label.replace(" ", "_"))
	apply_rng.randi_range(1, 2147483646)
	GameModule.apply_result(run_state, result, apply_rng)
	_check_action_result_applied(before, run_state, result, "%s host apply" % label, failures)


# Checks that ActionResult changes were applied through RunState domains.
func _check_action_result_applied(before: Dictionary, run_state: RunState, result: Dictionary, label: String, failures: Array) -> void:
	if not bool(result.get("ok", false)):
		return
	var deltas: Dictionary = result.get("deltas", {})
	var expected_bankroll := int(before.get("bankroll", 0)) + int(deltas.get("bankroll_delta", 0))
	if run_state.bankroll != expected_bankroll:
		failures.append("RunState bankroll did not match %s delta." % label)
	var result_environment_id := str(result.get("environment_id", ""))
	var before_suspicion := int(before.get("suspicion", 0))
	var actual_suspicion := run_state.suspicion_level()
	if not result_environment_id.is_empty():
		var location_id := run_state.suspicion_location_id_for_environment_id(result_environment_id)
		var before_levels: Dictionary = before.get("suspicion_levels", {})
		before_suspicion = int(before_levels.get(location_id, before_suspicion if location_id == str(before.get("suspicion_location_id", "")) else 0))
		actual_suspicion = run_state.suspicion_level_for_environment_id(result_environment_id)
	var expected_suspicion := clampi(before_suspicion + int(deltas.get("suspicion_delta", 0)), 0, 100)
	if actual_suspicion != expected_suspicion:
		failures.append("RunState suspicion did not match %s delta." % label)
	var expected_drunk := clampi(int(before.get("drunk_level", 0)) + int(deltas.get("drunk_delta", 0)), 0, RunState.ALCOHOL_MAX)
	if run_state.drunk_level != expected_drunk:
		failures.append("RunState drunk level did not match %s delta." % label)
	var intake := maxi(0, int(deltas.get("alcohol_intake", 0)))
	var pending_capacity := maxi(0, RunState.ALCOHOL_MAX - int(before.get("drunk_level", 0)) - int(before.get("pending_drunk_absorption", 0)))
	var expected_pending := int(before.get("pending_drunk_absorption", 0)) + mini(intake, pending_capacity)
	if run_state.pending_drunk_absorption_amount() != expected_pending:
		failures.append("RunState pending drunk absorption did not match %s alcohol intake." % label)
	var expected_alcoholic := clampi(int(before.get("alcoholic_level", 0)) + int(deltas.get("alcohol_intake", 0)) + int(deltas.get("alcoholic_delta", 0)), 0, RunState.ALCOHOL_MAX)
	if run_state.alcoholic_level != expected_alcoholic:
		failures.append("RunState alcoholic level did not match %s delta." % label)
	var expected_baseline_luck := clampi(int(before.get("baseline_luck", 0)) + int(deltas.get("baseline_luck_delta", 0)), RunState.BASELINE_LUCK_MIN, RunState.BASELINE_LUCK_MAX)
	if run_state.baseline_luck != expected_baseline_luck:
		failures.append("RunState baseline luck did not match %s delta." % label)
	var story_delta: Array = deltas.get("story_log", [])
	if run_state.story_log.size() != int(before.get("story_count", 0)) + story_delta.size():
		failures.append("RunState story log did not match %s delta." % label)
	var debt_delta: Array = deltas.get("debt_changes", [])
	if run_state.debt.size() != int(before.get("debt_count", 0)) + debt_delta.size():
		failures.append("RunState debt did not match %s delta." % label)
	if run_state.rng_state == int(before.get("rng_state", 0)):
		failures.append("RunState RNG state did not advance after %s." % label)


# Checks the one selected FT-06 starter game without touching demo UI modules.
func _check_selected_starter_game_port(library: ContentLibrary, failures: Array) -> void:
	var definition := library.game("pull_tabs")
	if definition.is_empty():
		failures.append("Selected starter game is missing from ContentLibrary: pull_tabs.")
		return
	var module_path := str(definition.get("module_path", ""))
	if module_path != "res://scripts/games/pull_tabs.gd":
		failures.append("Selected starter game should route through the PullTabsGame foundation module.")
		return
	var module_script: Script = load(module_path)
	if module_script == null:
		failures.append("Selected starter game module could not be loaded.")
		return
	var module_a = module_script.new()
	var module_b = module_script.new()
	if not module_a is GameModule or not module_b is GameModule:
		failures.append("Selected starter game module does not extend GameModule.")
		return

	var run_a: RunState = RunStateScript.new()
	var run_b: RunState = RunStateScript.new()
	run_a.start_new("PULL-TABS-PORT")
	run_b.start_new("PULL-TABS-PORT")
	var generator_a: RunGenerator = RunGeneratorScript.new(library)
	var generator_b: RunGenerator = RunGeneratorScript.new(library)
	var environment_a := generator_a.next_environment(run_a).to_dict()
	var environment_b := generator_b.next_environment(run_b).to_dict()
	var game_a: GameModule = module_a
	var game_b: GameModule = module_b
	game_a.setup(definition, library)
	game_b.setup(definition, library)
	var presentation := game_a.actions(run_a, environment_a)
	var legal_actions: Array = presentation.get("legal_actions", [])
	var cheat_actions: Array = presentation.get("cheat_actions", [])
	if legal_actions.is_empty():
		failures.append("Selected starter game did not expose a legal action.")
		return
	var has_detector_scan := false
	for cheat_action_value in cheat_actions:
		if typeof(cheat_action_value) == TYPE_DICTIONARY and str((cheat_action_value as Dictionary).get("id", "")) == "tab_detector_scan":
			has_detector_scan = true
	if not has_detector_scan:
		failures.append("Selected starter pull-tabs did not expose the detector-scan advantage action.")

	var legal_id := str(legal_actions[0].get("id", ""))
	var legal_before := _run_state_result_snapshot(run_a)
	var legal_result_a := game_a.resolve(legal_id, 5, run_a, environment_a, run_a.create_rng())
	var legal_result_b := game_b.resolve(legal_id, 5, run_b, environment_b, run_b.create_rng())
	_check_action_result_shape(legal_result_a, "legal", failures)
	_check_action_result_applied(legal_before, run_a, legal_result_a, "selected starter legal result", failures)
	_check_pull_tab_result_details(legal_result_a, failures)
	if JSON.stringify(legal_result_a) != JSON.stringify(legal_result_b):
		failures.append("Selected starter legal action was not deterministic.")
	if JSON.stringify(run_a.to_dict()) != JSON.stringify(run_b.to_dict()):
		failures.append("Selected starter legal action did not leave deterministic RunState snapshots.")


# Checks the small Pull Tabs result payload stays gameplay-only.
func _check_pull_tab_result_details(result: Dictionary, failures: Array) -> void:
	var ticket: Dictionary = result.get("pull_tab_ticket", {})
	var rows: Array = ticket.get("rows", [])
	if rows.size() != 3:
		failures.append("Pull Tabs result should expose a three-window ticket.")
	for row_value in rows:
		var row: Array = row_value
		if row.size() != 3:
			failures.append("Pull Tabs ticket windows should each expose three symbols.")
	if str(ticket.get("form", "")).is_empty() or str(ticket.get("serial", "")).is_empty() or str(ticket.get("ticket_number", "")).is_empty():
		failures.append("Pull Tabs ticket should expose form, serial, and ticket number metadata.")
	if (ticket.get("prize_rows", []) as Array).is_empty():
		failures.append("Pull Tabs ticket should carry a prize legend snapshot for rendering.")
	var deal: Dictionary = result.get("pull_tab_deal", {})
	if str(deal.get("form", "")) != str(ticket.get("form", "")) or str(deal.get("serial", "")) != str(ticket.get("serial", "")):
		failures.append("Pull Tabs ticket form/serial did not match its deal flare.")
	if (deal.get("prizes", []) as Array).is_empty():
		failures.append("Pull Tabs deal should expose its prize chart.")
	if int(result.get("match_count", 0)) < 1:
		failures.append("Pull Tabs result should report match count.")
	if int(result.get("pull_tab_payout", -1)) < 0 or int(result.get("payout", -1)) < 0:
		failures.append("Pull Tabs result should report non-negative payout.")
	for ui_key in ["windows", "revealed", "ticket_stack", "stack_label", "host"]:
		if result.has(ui_key):
			failures.append("Pull Tabs result leaked demo UI state key: %s." % ui_key)


func _pull_tab_test_ticket_result(ticket_id: String, payout: int) -> Dictionary:
	return {
		"pull_tab_ticket": {
			"id": "test:ticket:%s" % ticket_id,
			"display_name": "Test Pull Tab",
			"form": "TEST",
			"serial": "001-00001",
			"ticket_number": "#%s" % ticket_id,
			"rows": [["CHERRY", "CHERRY", "CHERRY"], ["LEMON", "BAR", "7"], ["BELL", "BAR", "CHERRY"]],
			"payout": payout,
			"price": 1,
		},
	}


func _pull_tab_sleeve_entry_payout(deal: Dictionary, sleeve_entry: int) -> int:
	if sleeve_entry < 0:
		return 0
	var prizes: Array = deal.get("prizes", [])
	if sleeve_entry >= prizes.size():
		return 0
	return maxi(0, int((prizes[sleeve_entry] as Dictionary).get("payout", 0)))


func _set_pull_tab_loser_count(environment: Dictionary, loser_count: int) -> void:
	var states: Dictionary = environment.get("game_states", {})
	var machine: Dictionary = states.get("pull_tabs", {})
	var losers: Array = []
	for loser_index in range(maxi(0, loser_count)):
		losers.append({
			"id": "test:loser:%03d" % loser_index,
			"display_name": "Dead Pull Tab",
			"form": "TEST",
			"serial": "001-00001",
			"ticket_number": "#L%03d" % loser_index,
			"rows": [["CHERRY", "LEMON", "BAR"], ["LEMON", "BAR", "7"], ["BELL", "BAR", "CHERRY"]],
			"payout": 0,
			"price": 1,
			"sorted": true,
			"fully_revealed": true,
		})
	machine["loser_pile"] = losers
	states["pull_tabs"] = machine
	environment["game_states"] = states


func _clear_pull_tab_winners(environment: Dictionary) -> void:
	var states: Dictionary = environment.get("game_states", {})
	var machine: Dictionary = states.get("pull_tabs", {})
	machine["winner_pile"] = []
	states["pull_tabs"] = machine
	environment["game_states"] = states


func _inject_pull_tab_winner(environment: Dictionary, source_result: Dictionary) -> void:
	var states: Dictionary = environment.get("game_states", {})
	var machine: Dictionary = states.get("pull_tabs", {})
	var ticket: Dictionary = source_result.get("pull_tab_ticket", {}).duplicate(true)
	if ticket.is_empty():
		ticket = {
			"id": "test:ticket:001",
			"display_name": "Test Pull Tab",
			"form": "TEST",
			"serial": "001-00001",
			"ticket_number": "#001",
			"rows": [["CHERRY", "CHERRY", "CHERRY"], ["LEMON", "BAR", "7"], ["BELL", "BAR", "CHERRY"]],
			"payout": 5,
			"price": 1,
		}
	ticket["payout"] = maxi(5, int(ticket.get("payout", 0)))
	ticket["sorted"] = true
	ticket["fully_revealed"] = true
	var winners: Array = machine.get("winner_pile", [])
	winners.push_front(ticket)
	machine["winner_pile"] = winners
	states["pull_tabs"] = machine
	environment["game_states"] = states


# Checks production item effects through the foundation ItemEffect contract.
func _check_item_effect_foundation(library: ContentLibrary, failures: Array) -> void:
	var item_def := library.item("instant_coffee")
	if item_def.is_empty():
		failures.append("Production item effect fixture is missing: instant_coffee.")
		return
	var run_a: RunState = RunStateScript.new()
	var run_b: RunState = RunStateScript.new()
	run_a.start_new("ITEM-EFFECT-SEED")
	run_b.start_new("ITEM-EFFECT-SEED")
	var context := {
		"domain": "games",
		"domains": ["global", "games"],
		"action_kind": "legal",
		"game_family": "novelty",
		"environment_id": "item_effect_fixture",
	}
	var effect_a := ItemEffect.new()
	var effect_b := ItemEffect.new()
	effect_a.setup(item_def)
	effect_b.setup(item_def)
	var result_a := effect_a.apply(context, run_a)
	var result_b := effect_b.apply(context, run_b)
	_check_item_result_delta_shape(result_a, failures)
	if not bool(result_a.get("applied", false)):
		failures.append("Production item effect did not apply to legal global game context.")
	var modifiers: Dictionary = result_a.get("modifiers", {})
	if int(modifiers.get("win_chance", 0)) < 3:
		failures.append("Production item legal-play modifier did not normalize to win_chance.")
	if int(modifiers.get("loss_reduction", 0)) < 1:
		failures.append("Production item loss-reduction modifier was missing.")
	if result_a.get("deltas", {}).get("item_hooks", []).is_empty():
		failures.append("Production item effect did not contribute an item hook.")
	if JSON.stringify(result_a) != JSON.stringify(result_b):
		failures.append("Production item effect result was not deterministic.")
	if JSON.stringify(run_a.to_dict()) != JSON.stringify(run_b.to_dict()):
		failures.append("Production item effect did not leave deterministic RunState snapshots.")
	if JSON.parse_string(JSON.stringify(result_a)) == null:
		failures.append("Production item effect result was not serializable.")

	var family_effect := ItemEffect.new()
	family_effect.setup(library.item("scratch_pad"))
	var family_result := family_effect.apply({"domain": "games", "game_family": "cards", "action_kind": "legal"})
	if int(family_result.get("modifiers", {}).get("win_chance", 0)) < 5:
		failures.append("Game-family item modifier did not apply for matching family.")

	var security_effect := ItemEffect.new()
	security_effect.setup(library.item("cheap_sunglasses"))
	var security_result := security_effect.apply({"domain": "security", "action_kind": "cheat"})
	if int(security_result.get("modifiers", {}).get("suspicion_delta", 0)) >= 0:
		failures.append("Cheating-risk item modifier did not normalize suspicion_delta.")

	var travel_effect := ItemEffect.new()
	travel_effect.setup(library.item("roadside_map"))
	if not travel_effect.applies({"domain": "travel"}):
		failures.append("Travel domain item effect did not apply to travel context.")


# Checks that an existing item creates a visible build trade-off and changes game results through RunState inventory.
func _check_item_build_interaction_foundation(library: ContentLibrary, failures: Array) -> void:
	var item_def := library.item("instant_coffee")
	if item_def.is_empty():
		failures.append("Item build fixture is missing: instant_coffee.")
		return
	var item_effect_data: Dictionary = item_def.get("effect", {}) if typeof(item_def.get("effect", {})) == TYPE_DICTIONARY else {}
	if int(item_effect_data.get("legal_win_chance", 0)) <= 0:
		failures.append("Item build fixture should improve clean-play odds.")
	if int(item_effect_data.get("cheat_suspicion_delta", 0)) <= 0:
		failures.append("Item build fixture should include a risky-action trade-off.")

	var seed := _seed_for_first_roll_between(6, 8)
	if seed.is_empty():
		failures.append("Could not find deterministic item build seed fixture.")
		return
	var environment := {
		"id": "item_build_environment",
		"kind": "fixture",
		"tier": 1,
		"economic_profile": {
			"stake_floor": 1,
			"stake_ceiling": 10,
		},
	}
	var game_definition := {
		"id": "item_build_game",
		"display_name": "Item Build Game",
		"family": "novelty",
		"legal_actions": [{"id": "legal_fixture", "label": "Play Clean", "win_chance": 5, "payout_mult": 2}],
		"cheat_actions": [{"id": "risky_fixture", "label": "Try Something Risky", "win_chance": 70, "payout_mult": 2, "suspicion_delta": 2}],
	}

	var baseline_run: RunState = RunStateScript.new()
	var item_run: RunState = RunStateScript.new()
	baseline_run.start_new(seed)
	item_run.start_new(seed)
	var purchase_result := _fixture_item_purchase_result(item_def, 4, str(environment.get("id", "")))
	GameModule.apply_result(item_run, purchase_result)
	if not item_run.inventory.has("instant_coffee"):
		failures.append("Item purchase did not add the item through result-delta inventory.")
	if item_run.bankroll != RunState.DEFAULT_BANKROLL - 4:
		failures.append("Item purchase did not apply item cost through result-delta bankroll.")
	if JSON.parse_string(JSON.stringify(purchase_result)) == null:
		failures.append("Item purchase result was not serializable.")

	var baseline_game := GameModule.new()
	var item_game := GameModule.new()
	baseline_game.setup(game_definition, library)
	item_game.setup(game_definition, library)
	var baseline_result := baseline_game.resolve("legal_fixture", 1, baseline_run, environment, baseline_run.create_rng())
	var item_result := item_game.resolve("legal_fixture", 1, item_run, environment, item_run.create_rng())
	if bool(baseline_result.get("won", false)):
		failures.append("Item build baseline fixture should lose before the clean-play item bonus.")
	if not bool(item_result.get("won", false)):
		failures.append("Item build fixture did not change the legal game result through inventory modifiers.")
	if int(item_result.get("bankroll_delta", 0)) <= int(baseline_result.get("bankroll_delta", 0)):
		failures.append("Item build fixture did not improve the legal game consequence.")

	var cheat_baseline_run: RunState = RunStateScript.new()
	var cheat_item_run: RunState = RunStateScript.new()
	cheat_baseline_run.start_new("ITEM-BUILD-CHEAT")
	cheat_item_run.start_new("ITEM-BUILD-CHEAT")
	GameModule.apply_result(cheat_item_run, _fixture_item_purchase_result(item_def, 4, str(environment.get("id", ""))))
	var cheat_baseline_game := GameModule.new()
	var cheat_item_game := GameModule.new()
	cheat_baseline_game.setup(game_definition, library)
	cheat_item_game.setup(game_definition, library)
	var cheat_baseline_result := cheat_baseline_game.resolve("risky_fixture", 1, cheat_baseline_run, environment, cheat_baseline_run.create_rng())
	var cheat_item_result := cheat_item_game.resolve("risky_fixture", 1, cheat_item_run, environment, cheat_item_run.create_rng())
	if int(cheat_item_result.get("suspicion_delta", 0)) <= int(cheat_baseline_result.get("suspicion_delta", 0)):
		failures.append("Item build fixture did not expose its risky-action trade-off.")

	var save_service: SaveService = SaveServiceScript.new()
	var slot_id := "foundation_check_item_build"
	var save_error: Error = save_service.save_run(item_run, slot_id)
	if save_error != OK:
		failures.append("Save service could not save item build state: %s." % save_error)
	else:
		var loaded = save_service.load_run(slot_id)
		if loaded == null:
			failures.append("Save service could not reload item build state.")
		elif not loaded.inventory.has("instant_coffee"):
			failures.append("Item build inventory did not survive SaveService load.")
		elif loaded.bankroll != item_run.bankroll:
			failures.append("Item build bankroll did not survive SaveService load.")
		elif loaded.story_log.size() != item_run.story_log.size():
			failures.append("Item build story state did not survive SaveService load.")


func _seed_for_first_roll_between(min_roll: int, max_roll: int) -> String:
	for index in range(1, 5000):
		var seed := "ITEM-BUILD-%d" % index
		var run_state: RunState = RunStateScript.new()
		run_state.start_new(seed)
		var rng := run_state.create_rng()
		var roll := rng.randi_range(1, 100)
		if roll >= min_roll and roll <= max_roll:
			return seed
	return ""


func _fixture_item_purchase_result(item_definition: Dictionary, price: int, environment_id: String) -> Dictionary:
	var item_id := str(item_definition.get("id", ""))
	var display_name := str(item_definition.get("display_name", item_id))
	var item_effect := ItemEffect.new()
	item_effect.setup(item_definition)
	var effect_result := item_effect.apply({
		"domain": str(item_definition.get("domain", "global")),
		"domains": [str(item_definition.get("domain", "global")), "global"],
		"environment_id": environment_id,
		"action_id": "buy_item",
	})
	var source_deltas: Dictionary = effect_result.get("deltas", {}) if typeof(effect_result.get("deltas", {})) == TYPE_DICTIONARY else {}
	var deltas := GameModule.empty_result_deltas()
	for key in deltas.keys():
		var value: Variant = source_deltas.get(key, deltas[key])
		if typeof(value) == TYPE_ARRAY:
			deltas[key] = (value as Array).duplicate(true)
		elif typeof(value) == TYPE_DICTIONARY:
			deltas[key] = (value as Dictionary).duplicate(true)
		else:
			deltas[key] = value
	deltas["bankroll_delta"] = int(deltas.get("bankroll_delta", 0)) - price
	var inventory_add: Array = deltas.get("inventory_add", [])
	if not inventory_add.has(item_id):
		inventory_add.append(item_id)
	deltas["inventory_add"] = inventory_add
	var message := "Bought %s for %d." % [display_name, price]
	deltas["story_log"] = [{
		"type": "item_purchase",
		"item_id": item_id,
		"item_name": display_name,
		"price": price,
		"environment_id": environment_id,
		"message": message,
	}]
	deltas["messages"] = [message]
	return GameModule.build_action_result({
		"ok": bool(effect_result.get("ok", true)),
		"type": "item_effect",
		"source_id": item_id,
		"item_id": item_id,
		"item_effect_id": item_id,
		"action_id": "buy_item",
		"action_kind": "item",
		"bankroll_delta": int(deltas.get("bankroll_delta", 0)),
		"suspicion_delta": int(deltas.get("suspicion_delta", 0)),
		"deltas": deltas,
		"message": message,
	})


# Checks ItemEffect returns the same shared result-delta keys as other modules.
func _check_item_result_delta_shape(result: Dictionary, failures: Array) -> void:
	if str(result.get("type", "")) != "item_effect":
		failures.append("ItemEffect result should identify item_effect results.")
	if str(result.get("item_effect_id", "")).is_empty():
		failures.append("ItemEffect result should include item_effect_id.")
	var deltas: Dictionary = result.get("deltas", {})
	var required_delta_keys := [
		"bankroll_delta",
		"suspicion_delta",
		"debt_changes",
		"inventory_add",
		"inventory_remove",
		"flags_set",
		"travel_hooks_add",
		"travel_changes",
		"story_log",
		"messages",
		"ended",
		"item_hooks",
		"event_hooks",
	]
	for key in required_delta_keys:
		if not deltas.has(key):
			failures.append("ItemEffect deltas missing key: %s." % key)
	for ui_key in ["host", "button_metadata", "overlay_state", "focus", "hover", "ui_state"]:
		if result.has(ui_key) or deltas.has(ui_key):
			failures.append("ItemEffect leaked UI state key: %s." % ui_key)


# Checks direct item deltas are applied through RunState domains.
func _check_item_result_applied(before: Dictionary, run_state: RunState, result: Dictionary, label: String, failures: Array) -> void:
	if not bool(result.get("ok", false)):
		return
	var deltas: Dictionary = result.get("deltas", {})
	var expected_bankroll := int(before.get("bankroll", 0)) + int(deltas.get("bankroll_delta", 0))
	if run_state.bankroll != expected_bankroll:
		failures.append("RunState bankroll did not match %s." % label)
	var expected_suspicion := clampi(int(before.get("suspicion", 0)) + int(deltas.get("suspicion_delta", 0)), 0, 100)
	if int(run_state.suspicion.get("level", 0)) != expected_suspicion:
		failures.append("RunState suspicion did not match %s." % label)
	var story_delta: Array = deltas.get("story_log", [])
	if run_state.story_log.size() != int(before.get("story_count", 0)) + story_delta.size():
		failures.append("RunState story log did not match %s." % label)
	var debt_delta: Array = deltas.get("debt_changes", [])
	if run_state.debt.size() != int(before.get("debt_count", 0)) + debt_delta.size():
		failures.append("RunState debt did not match %s." % label)


# Checks production event triggering and resolution through EventModule.
func _check_event_module_foundation(library: ContentLibrary, failures: Array) -> void:
	var run_a: RunState = RunStateScript.new()
	var run_b: RunState = RunStateScript.new()
	run_a.start_new("EVENT-MODULE-SEED")
	run_b.start_new("EVENT-MODULE-SEED")
	var generator_a: RunGenerator = RunGeneratorScript.new(library)
	var generator_b: RunGenerator = RunGeneratorScript.new(library)
	var environment_a := generator_a.next_environment(run_a).to_dict()
	var environment_b := generator_b.next_environment(run_b).to_dict()
	var event_context := _first_triggerable_event_context(library, run_a, environment_a)
	if event_context.is_empty():
		failures.append("No generated production event could trigger through EventModule.")
		return
	var event_id := str(event_context.get("event_id", ""))
	var definition := library.event(event_id)
	if definition.is_empty():
		failures.append("Production event was missing from ContentLibrary: %s." % event_id)
		return
	var event_a := EventModule.new()
	var event_b := EventModule.new()
	event_a.setup(definition)
	event_b.setup(definition)
	var trigger_context: Dictionary = event_context.get("context", {})
	if event_a.can_trigger(run_a, environment_a, trigger_context) != event_b.can_trigger(run_b, environment_b, trigger_context):
		failures.append("Production event trigger check was not deterministic.")
	if not event_a.can_trigger(run_a, environment_a, trigger_context):
		failures.append("Production event did not trigger in its generated context: %s." % event_id)
		return
	var choices := event_a.choices()
	if choices.is_empty():
		failures.append("Production event has no choices: %s." % event_id)
		return
	var choice_id := str(choices[0].get("id", ""))
	var before := _run_state_result_snapshot(run_a)
	var result_a := event_a.resolve(run_a, environment_a, choice_id)
	var result_b := event_b.resolve(run_b, environment_b, choice_id)
	_check_event_result_delta_shape(result_a, failures)
	_check_event_result_applied(before, run_a, result_a, "production event result", failures)
	if JSON.stringify(result_a) != JSON.stringify(result_b):
		failures.append("Production event resolution was not deterministic.")
	if JSON.stringify(run_a.to_dict()) != JSON.stringify(run_b.to_dict()):
		failures.append("Production event resolution did not leave deterministic RunState snapshots.")
	if JSON.parse_string(JSON.stringify(run_a.to_dict())) == null:
		failures.append("Production event RunState result was not serializable.")
	if event_a.can_trigger(run_a, run_a.current_environment, trigger_context):
		failures.append("Resolved production event can still trigger in current RunState environment.")


# Checks events can key off run/system state and alter later choices through result-deltas.
func _check_event_system_state_foundation(library: ContentLibrary, failures: Array) -> void:
	var tip_event_def := library.event("parking_lot_tip")
	if tip_event_def.is_empty():
		failures.append("System-state event fixture is missing: parking_lot_tip.")
		return
	var tip_run: RunState = RunStateScript.new()
	tip_run.start_new("EVENT-SYSTEM-TIP")
	tip_run.set_environment({
		"id": "event_system_shop",
		"kind": "shop",
		"tier": 1,
		"event_ids": ["parking_lot_tip"],
		"resolved_event_ids": [],
		"next_archetypes": ["bar"],
		"travel_hooks": ["small_underground_casino"],
	})
	var underground_route := library.route("small_underground_casino")
	if underground_route.is_empty():
		failures.append("System-state event route fixture is missing: small_underground_casino.")
		return
	if bool(tip_run.travel_route_status(underground_route).get("available", true)):
		failures.append("System-state event route should start locked before the event flag.")
	var tip_event := EventModule.new()
	tip_event.setup(tip_event_def)
	if not tip_event.can_trigger(tip_run, tip_run.current_environment):
		failures.append("Flag-gated travel event should trigger before its unlock flag exists.")
	var tip_before := _run_state_result_snapshot(tip_run)
	var tip_result := tip_event.resolve(tip_run, tip_run.current_environment, "follow_tip")
	_check_event_result_delta_shape(tip_result, failures)
	_check_event_result_applied(tip_before, tip_run, tip_result, "system-state travel event result", failures)
	if not bool(tip_run.narrative_flags.get("underground_tip", false)):
		failures.append("System-state event did not set the travel unlock flag.")
	if not bool(tip_run.travel_route_status(underground_route).get("available", false)):
		failures.append("System-state event outcome did not unlock its downstream travel choice.")
	if tip_event.can_trigger(tip_run, tip_run.current_environment):
		failures.append("System-state event stayed eligible after its blocking flag was set.")

	var debt_event_def := library.event("motel_knock")
	if debt_event_def.is_empty():
		failures.append("Economy-gated event fixture is missing: motel_knock.")
		return
	var stable_run: RunState = RunStateScript.new()
	stable_run.start_new("EVENT-SYSTEM-STABLE")
	stable_run.set_environment({
		"id": "event_system_motel",
		"kind": "shop",
		"tier": 1,
		"event_ids": ["motel_knock"],
		"resolved_event_ids": [],
		"next_archetypes": ["gas_station_casino"],
		"travel_hooks": [],
		"turns": 1,
	})
	var debt_event := EventModule.new()
	debt_event.setup(debt_event_def)
	if debt_event.can_trigger(stable_run, stable_run.current_environment, {"turns": 1}):
		failures.append("Economy-gated event triggered while economy was stable.")

	var strained_run: RunState = RunStateScript.new()
	strained_run.start_new("EVENT-SYSTEM-STRAINED")
	strained_run.change_bankroll(-60)
	strained_run.set_environment(stable_run.current_environment)
	if strained_run.economy() != "volatile":
		failures.append("Event system fixture did not enter volatile economy state.")
	if not debt_event.can_trigger(strained_run, strained_run.current_environment, {"turns": 1}):
		failures.append("Economy-gated event did not trigger from strained economy state.")
	var debt_before := _run_state_result_snapshot(strained_run)
	var debt_result := debt_event.resolve(strained_run, strained_run.current_environment, "borrow")
	_check_event_result_delta_shape(debt_result, failures)
	_check_event_result_applied(debt_before, strained_run, debt_result, "system-state debt event result", failures)
	if strained_run.debt.is_empty():
		failures.append("Economy-gated event did not add debt through result-delta.")
	if strained_run.economy() != "distressed":
		failures.append("Event debt outcome did not affect downstream economy pressure.")

	var save_service: SaveService = SaveServiceScript.new()
	var slot_id := "foundation_check_event_system_state"
	var save_error: Error = save_service.save_run(strained_run, slot_id)
	if save_error != OK:
		failures.append("Save service could not save event system state: %s." % save_error)
	else:
		var loaded = save_service.load_run(slot_id)
		if loaded == null:
			failures.append("Save service could not reload event system state.")
		elif loaded.debt.size() != strained_run.debt.size():
			failures.append("Event debt outcome did not survive SaveService load.")
		elif loaded.economy() != strained_run.economy():
			failures.append("Event economy outcome did not survive SaveService load.")
		elif loaded.story_log.size() != strained_run.story_log.size():
			failures.append("Event story outcome did not survive SaveService load.")


# Finds the first generated event whose trigger contract is satisfied.
func _first_triggerable_event_context(library: ContentLibrary, run_state: RunState, environment: Dictionary) -> Dictionary:
	var contexts := [
		{},
		{"turns": 999},
		{"trigger": "travel"},
	]
	for event_id in environment.get("event_ids", []):
		var event_def := library.event(str(event_id))
		if event_def.is_empty():
			continue
		var event_module := EventModule.new()
		event_module.setup(event_def)
		for context in contexts:
			if event_module.can_trigger(run_state, environment, context):
				return {
					"event_id": str(event_id),
					"context": context.duplicate(true),
				}
	return {}


# Checks EventModule returns the shared result-delta keys.
func _check_event_result_delta_shape(result: Dictionary, failures: Array) -> void:
	if not bool(result.get("ok", false)):
		failures.append("EventModule returned an unsuccessful result.")
	if str(result.get("type", "")) != "event":
		failures.append("EventModule result should identify event results.")
	if str(result.get("event_id", "")).is_empty():
		failures.append("EventModule result should include event_id.")
	if str(result.get("choice_id", "")).is_empty():
		failures.append("EventModule result should include choice_id.")
	var deltas: Dictionary = result.get("deltas", {})
	var required_delta_keys := [
		"bankroll_delta",
		"suspicion_delta",
		"debt_changes",
		"inventory_add",
		"inventory_remove",
		"flags_set",
		"travel_hooks_add",
		"travel_changes",
		"story_log",
		"messages",
		"ended",
		"item_hooks",
		"event_hooks",
	]
	for key in required_delta_keys:
		if not deltas.has(key):
			failures.append("EventModule deltas missing key: %s." % key)
	if int(result.get("bankroll_delta", 0)) != int(deltas.get("bankroll_delta", 0)):
		failures.append("EventModule top-level bankroll_delta does not match deltas.")
	if int(result.get("suspicion_delta", 0)) != int(deltas.get("suspicion_delta", 0)):
		failures.append("EventModule top-level suspicion_delta does not match deltas.")
	if str(result.get("message", "")).is_empty():
		failures.append("EventModule result should include a player-facing message.")
	if result.get("messages", []).is_empty() or deltas.get("messages", []).is_empty():
		failures.append("EventModule should include messages in the shared delta shape.")
	for ui_key in ["host", "button_metadata", "overlay_state", "focus", "hover", "ui_state"]:
		if result.has(ui_key) or deltas.has(ui_key):
			failures.append("EventModule leaked UI state key: %s." % ui_key)


# Checks event deltas were applied through RunState domains.
func _check_event_result_applied(before: Dictionary, run_state: RunState, result: Dictionary, label: String, failures: Array) -> void:
	if not bool(result.get("ok", false)):
		return
	var deltas: Dictionary = result.get("deltas", {})
	var expected_bankroll := int(before.get("bankroll", 0)) + int(deltas.get("bankroll_delta", 0))
	if run_state.bankroll != expected_bankroll:
		failures.append("RunState bankroll did not match %s." % label)
	var expected_suspicion := clampi(int(before.get("suspicion", 0)) + int(deltas.get("suspicion_delta", 0)), 0, 100)
	if int(run_state.suspicion.get("level", 0)) != expected_suspicion:
		failures.append("RunState suspicion did not match %s." % label)
	var story_delta: Array = deltas.get("story_log", [])
	if run_state.story_log.size() != int(before.get("story_count", 0)) + story_delta.size():
		failures.append("RunState story log did not match %s." % label)
	var debt_delta: Array = deltas.get("debt_changes", [])
	if run_state.debt.size() != int(before.get("debt_count", 0)) + debt_delta.size():
		failures.append("RunState debt did not match %s." % label)
	var flags: Dictionary = deltas.get("flags_set", {})
	for key in flags.keys():
		if run_state.narrative_flags.get(key) != flags[key]:
			failures.append("RunState flags did not match %s." % label)
	var resolved: Array = run_state.current_environment.get("resolved_event_ids", [])
	if not resolved.has(str(result.get("event_id", ""))):
		failures.append("RunState did not record resolved event for %s." % label)


# Checks SaveService as the only foundation run save/load path.
func _check_save_service_foundation_round_trip(library: ContentLibrary, failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("SAVE-SERVICE-SEED", RunState.custom_challenge("save_service_round_trip", "SAVE-SERVICE-SEED", {"fixture": true}))
	var generator: RunGenerator = RunGeneratorScript.new(library)
	var environment: EnvironmentInstance = generator.next_environment(run_state)
	_resolve_first_save_test_action(library, run_state, environment, failures)
	if not library.items.is_empty():
		run_state.add_item(str((library.items[0] as Dictionary).get("id", "")))
	run_state.add_debt({
		"id": "save_service_debt",
		"lender_id": "save_service_fixture",
		"balance": 12,
		"status": "active",
	})
	run_state.narrative_flags["save_service_flag"] = true
	run_state.add_next_archetypes(environment.next_archetypes)
	run_state.log_story({
		"type": "save_service_marker",
		"id": "save_service_round_trip",
		"environment_id": environment.id,
	})

	var expected := _save_service_expected_snapshot(run_state)
	var save_service: SaveService = SaveServiceScript.new()
	var slot_id := "foundation_save_round_trip"
	var save_path := save_service.run_save_path(slot_id)
	if not save_path.begins_with("%s/" % SaveService.SAVE_DIR) or save_path.contains("demo_save"):
		failures.append("Foundation SaveService path escaped the foundation run save directory.")
	var save_error := save_service.save_run(run_state, slot_id)
	if save_error != OK:
		failures.append("SaveService foundation round trip save failed with error %s." % save_error)
		return
	if not save_service.has_run(slot_id):
		failures.append("SaveService did not report saved foundation slot.")
		return
	_check_save_payload_file(save_path, failures)
	var loaded = save_service.load_run(slot_id)
	if loaded == null:
		failures.append("SaveService foundation round trip load returned null.")
		return
	_check_run_state_save_round_trip(expected, loaded.to_dict(), failures)


# Checks the local/no-op platform adapter stays outside core gameplay behavior.
func _check_platform_services_foundation(failures: Array) -> void:
	var platform: PlatformServices = PlatformServicesScript.new()
	platform.setup("local_fixture")
	var initialized := platform.initialize()
	_check_platform_payload(initialized, "initialize", failures)
	if not bool(initialized.get("available", false)):
		failures.append("PlatformServices local adapter did not report availability.")

	var daily_a := platform.get_daily_run_id("2026-05-21")
	var daily_b := platform.get_daily_run_id("2026-05-21")
	var daily_c := platform.get_daily_run_id("2026-05-22")
	_check_platform_payload(daily_a, "daily run id", failures)
	if JSON.stringify(daily_a) != JSON.stringify(daily_b):
		failures.append("PlatformServices daily run payload was not deterministic for the same date.")
	if str(daily_a.get("daily_id", "")).is_empty():
		failures.append("PlatformServices daily run payload did not include a daily_id.")
	if str(daily_a.get("daily_id", "")) == str(daily_c.get("daily_id", "")):
		failures.append("PlatformServices daily run payload did not vary by date.")
	var daily_challenge: Dictionary = daily_a.get("challenge_config", {})
	if str(daily_challenge.get("mode", "")) != "daily":
		failures.append("PlatformServices daily payload did not use RunState daily challenge config.")

	var daily_run_a: RunState = RunStateScript.new()
	var daily_run_b: RunState = RunStateScript.new()
	var daily_run_c: RunState = RunStateScript.new()
	daily_run_a.start_new("IGNORED", daily_challenge)
	daily_run_b.start_new("OTHER-IGNORED", daily_b.get("challenge_config", {}))
	daily_run_c.start_new("IGNORED", daily_c.get("challenge_config", {}))
	if JSON.stringify(daily_run_a.to_dict()) != JSON.stringify(daily_run_b.to_dict()):
		failures.append("Daily challenge config did not seed RunState deterministically.")
	if daily_run_a.seed_value == daily_run_c.seed_value:
		failures.append("Different daily challenge payloads did not produce distinct RunState seeds.")

	var custom_challenge := RunState.custom_challenge("local_custom", "CUSTOM-SEED", {"pressure": "low"})
	var custom_run_a: RunState = RunStateScript.new()
	var custom_run_b: RunState = RunStateScript.new()
	custom_run_a.start_new("IGNORED", custom_challenge)
	custom_run_b.start_new("OTHER-IGNORED", RunState.custom_challenge("local_custom", "CUSTOM-SEED", {"pressure": "low"}))
	if JSON.stringify(custom_run_a.to_dict()) != JSON.stringify(custom_run_b.to_dict()):
		failures.append("Custom challenge config did not seed RunState deterministically.")
	var custom_run_c: RunState = RunStateScript.new()
	custom_run_c.start_new("IGNORED", RunState.custom_challenge("local_custom", "CUSTOM-SEED", {"pressure": "high"}))
	if custom_run_a.seed_value == custom_run_c.seed_value:
		failures.append("Different custom challenge modifiers did not affect RunState seed.")

	var score_payload := platform.submit_score("foundation_score", custom_run_a.seed_text, custom_run_a.bankroll)
	_check_platform_payload(score_payload, "score submission", failures)
	if bool(score_payload.get("submitted", true)):
		failures.append("PlatformServices local score submission should be no-op.")
	var daily_score_payload := platform.submit_daily_score(str(daily_a.get("daily_id", "")), custom_run_a.bankroll, daily_challenge)
	_check_platform_payload(daily_score_payload, "daily score submission", failures)
	var daily_score_challenge: Dictionary = daily_score_payload.get("challenge_config", {})
	daily_score_challenge["seed_text"] = "mutated"
	if str(daily_challenge.get("seed_text", "")) == "mutated":
		failures.append("PlatformServices daily score payload leaked mutable challenge config input.")
	var achievement_payload := platform.unlock_achievement("foundation_check")
	_check_platform_payload(achievement_payload, "achievement unlock", failures)
	if bool(achievement_payload.get("unlocked", true)):
		failures.append("PlatformServices local achievement unlock should be no-op.")


func _check_platform_payload(payload: Dictionary, label: String, failures: Array) -> void:
	if not payload.has("ok"):
		failures.append("PlatformServices %s payload is missing ok." % label)
	if str(payload.get("service", "")).is_empty():
		failures.append("PlatformServices %s payload is missing service." % label)
	if str(payload.get("mode", "")) != "local_noop":
		failures.append("PlatformServices %s payload did not stay local/no-op." % label)


# Checks economy labels, bankroll-driven pressure, stake constraints, and save/load.
func _check_economy_pressure_foundation(library: ContentLibrary, failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("ECONOMY-PRESSURE")
	if run_state.economy() != "stable":
		failures.append("New RunState economy should start stable.")

	run_state.change_bankroll(-60)
	if run_state.economy() != "volatile":
		failures.append("Bankroll loss did not shift economy pressure to volatile.")
	var volatile_ceiling := run_state.economy_stake_ceiling(30)
	if volatile_ceiling >= 30 or volatile_ceiling != 20:
		failures.append("Volatile economy did not constrain max stake from bankroll pressure.")
	if not run_state.economy_pressure_summary().contains("Volatile"):
		failures.append("Economy pressure summary did not expose the visible volatile label.")

	var environment := {
		"id": "economy_pressure_fixture",
		"economic_profile": {
			"stake_floor": 1,
			"stake_ceiling": 30,
		},
	}
	var game := GameModule.new()
	game.setup({
		"id": "economy_pressure_game",
		"display_name": "Economy Pressure Game",
		"family": "fixture",
		"legal_actions": [{"id": "legal_fixture", "label": "Legal Fixture", "win_chance": 45, "payout_mult": 2}],
		"cheat_actions": [],
	}, library)
	var action_view := game.actions(run_state, environment)
	if int(action_view.get("base_stake_ceiling", 0)) != 30:
		failures.append("GameModule did not expose base stake ceiling for economy visibility.")
	if int(action_view.get("economy_stake_ceiling", 0)) != volatile_ceiling:
		failures.append("GameModule action view did not expose the economy pressure recommendation.")
	if int(action_view.get("stake_ceiling", 0)) != 30:
		failures.append("GameModule action stake ceiling should allow wagers up to available bankroll.")
	if not bool(action_view.get("economy_pressure_applied", false)):
		failures.append("GameModule action view did not flag visible economy pressure.")

	var result := game.resolve("legal_fixture", 30, run_state, environment, run_state.create_rng())
	if int(result.get("stake", 0)) != 30:
		failures.append("GameModule resolve did not allow an all-available wager under economy pressure.")

	var distressed_run: RunState = RunStateScript.new()
	distressed_run.start_new("ECONOMY-DISTRESSED")
	distressed_run.change_bankroll(-70)
	distressed_run.add_debt({
		"id": "economy_debt_fixture",
		"lender_id": "street_lender",
		"balance": 10,
		"status": "active",
	})
	if distressed_run.economy() != "distressed":
		failures.append("Debt plus low bankroll did not shift economy pressure to distressed.")
	if distressed_run.economy_stake_ceiling(30) >= volatile_ceiling:
		failures.append("Distressed economy should constrain stake more than volatile economy.")

	var snapshot := distressed_run.to_dict()
	var restored: RunState = RunStateScript.new()
	restored.from_dict(snapshot)
	if restored.economy() != distressed_run.economy():
		failures.append("Economy state did not survive RunState serialization.")
	if restored.economy_stake_ceiling(30) != distressed_run.economy_stake_ceiling(30):
		failures.append("Economy stake pressure did not survive RunState save/load restore.")


# Checks route affordability, flag conditions, cost/risk deltas, and save/load.
func _check_travel_route_foundation(library: ContentLibrary, failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("TRAVEL-ROUTE")
	var available_route := library.route("corner_store")
	if available_route.is_empty():
		failures.append("Travel route fixture is missing: corner_store.")
		return
	var available_status := run_state.travel_route_status(available_route)
	if not bool(available_status.get("available", false)):
		failures.append("Available travel route was unexpectedly disabled.")
	var cost := int(available_status.get("cost", 0))
	if cost <= 0:
		failures.append("Travel cost fixture should apply a nonzero bankroll cost.")
	var suspicion_delta := int(available_status.get("suspicion_delta", 0))
	if str(available_status.get("distance", "")).is_empty():
		failures.append("Travel route status did not expose distance metadata.")
	if int(available_status.get("risk_decay", -1)) < 0:
		failures.append("Travel route status did not expose local heat decay metadata.")
	var before_bankroll := run_state.bankroll
	var before_suspicion := int(run_state.suspicion.get("level", 0))
	var result := _fixture_travel_result(run_state, available_route, "corner_store")
	GameModule.apply_result(run_state, result)
	if run_state.bankroll != before_bankroll - cost:
		failures.append("Confirmed travel did not apply route cost through result-delta.")
	if int(run_state.suspicion.get("level", 0)) != before_suspicion + suspicion_delta:
		failures.append("Confirmed travel did not apply route risk through result-delta.")
	if run_state.story_log.is_empty() or str((run_state.story_log[run_state.story_log.size() - 1] as Dictionary).get("type", "")) != "travel":
		failures.append("Confirmed travel did not record a travel story entry.")

	var locked_run: RunState = RunStateScript.new()
	locked_run.start_new("TRAVEL-LOCKED")
	var locked_route := library.route("small_underground_casino")
	if locked_route.is_empty():
		failures.append("Travel route fixture is missing: small_underground_casino.")
		return
	var locked_status := locked_run.travel_route_status(locked_route)
	if bool(locked_status.get("available", true)):
		failures.append("Route condition did not lock a flagged route.")
	if str(locked_status.get("disabled_reason", "")).is_empty():
		failures.append("Locked route did not expose a disabled reason.")
	locked_run.narrative_flags["underground_tip"] = true
	var unlocked_status := locked_run.travel_route_status(locked_route)
	if not bool(unlocked_status.get("available", false)):
		failures.append("Route condition did not unlock after the required flag.")

	var poor_run: RunState = RunStateScript.new()
	poor_run.start_new("TRAVEL-POOR")
	poor_run.change_bankroll(-(poor_run.bankroll - 1))
	var costly_route := library.route("bar")
	var poor_status := poor_run.travel_route_status(costly_route)
	if bool(poor_status.get("available", true)):
		failures.append("Unaffordable travel route was not disabled.")

	var boss_route := library.route("grand_casino")
	if boss_route.is_empty():
		failures.append("Travel route fixture is missing: grand_casino.")
	else:
		var boss_run: RunState = RunStateScript.new()
		boss_run.start_new("TRAVEL-GRAND-GATE")
		boss_run.bankroll = 200
		var boss_before_status := boss_run.travel_route_status(boss_route)
		if bool(boss_before_status.get("available", true)) or not bool(boss_before_status.get("hidden", false)):
			failures.append("Grand Casino route should be hidden until the run has traveled once.")
		boss_run.environment_history.append({"id": "visited_once", "archetype_id": "corner_store"})
		var boss_after_status := boss_run.travel_route_status(boss_route)
		if bool(boss_after_status.get("hidden", true)):
			failures.append("Grand Casino route stayed hidden after one completed travel.")
		if not bool(boss_after_status.get("available", false)):
			failures.append("Grand Casino route should be available after one travel when bankroll covers the buy-in.")

	var snapshot := run_state.to_dict()
	var restored: RunState = RunStateScript.new()
	restored.from_dict(snapshot)
	if restored.bankroll != run_state.bankroll:
		failures.append("Travel cost state did not survive RunState save/load restore.")
	if int(restored.suspicion.get("level", 0)) != int(run_state.suspicion.get("level", 0)):
		failures.append("Travel risk state did not survive RunState save/load restore.")
	if restored.story_log.size() != run_state.story_log.size():
		failures.append("Travel story state did not survive RunState save/load restore.")


func _fixture_travel_result(run_state: RunState, route: Dictionary, target_id: String) -> Dictionary:
	var status := run_state.travel_route_status(route)
	var cost := int(status.get("cost", 0))
	var suspicion_delta := int(status.get("suspicion_delta", 0))
	var message := "Traveled to %s." % target_id
	var story_entry := {
		"type": "travel",
		"id": target_id,
		"route_id": target_id,
		"bankroll_delta": -cost,
		"suspicion_delta": suspicion_delta,
		"message": message,
	}
	var deltas := GameModule.empty_result_deltas()
	deltas["bankroll_delta"] = -cost
	deltas["suspicion_delta"] = suspicion_delta
	deltas["story_log"] = [story_entry]
	deltas["messages"] = [message]
	return GameModule.build_action_result({
		"ok": true,
		"type": "travel",
		"source_id": target_id,
		"action_id": "confirm_travel",
		"action_kind": "travel",
		"bankroll_delta": -cost,
		"suspicion_delta": suspicion_delta,
		"deltas": deltas,
		"message": message,
	})


# Checks service affordability, supported result-deltas, unsupported no-op behavior, and save/load.
func _check_service_hook_foundation(library: ContentLibrary, failures: Array) -> void:
	var service := library.service("cashier_tip")
	if service.is_empty():
		failures.append("Service fixture is missing: cashier_tip.")
		return
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("SERVICE-HOOK")
	run_state.add_suspicion("service_fixture_heat", 5)
	var status := run_state.service_hook_status(service)
	if not bool(status.get("available", false)):
		failures.append("Affordable service was unexpectedly disabled.")
	var cost := int(status.get("cost", 0))
	if cost <= 0:
		failures.append("Service fixture should expose a nonzero cost.")
	var before_bankroll := run_state.bankroll
	var before_suspicion := int(run_state.suspicion.get("level", 0))
	var result := _fixture_service_result(run_state, service, "cashier_tip")
	GameModule.apply_result(run_state, result)
	if run_state.bankroll != before_bankroll - cost:
		failures.append("Supported service did not apply cost through result-delta.")
	var expected_suspicion := clampi(before_suspicion + int(result.get("suspicion_delta", 0)), 0, 100)
	if int(run_state.suspicion.get("level", 0)) != expected_suspicion:
		failures.append("Supported service did not apply suspicion effect through result-delta.")
	if run_state.story_log.is_empty() or str((run_state.story_log[run_state.story_log.size() - 1] as Dictionary).get("type", "")) != "service_hook":
		failures.append("Supported service did not record a service story entry.")

	var drink_service := library.service("house_drink")
	if drink_service.is_empty():
		failures.append("Alcohol service is missing: house_drink.")
	else:
		var drink_run: RunState = RunStateScript.new()
		drink_run.start_new("SERVICE-ALCOHOL")
		drink_run.set_environment({"id": "service_alcohol_room", "archetype_id": "bar"})
		var drink_result := _fixture_service_result(drink_run, drink_service, "house_drink")
		var drink_intake := int(drink_result.get("deltas", {}).get("alcohol_intake", 0))
		GameModule.apply_result(drink_run, drink_result)
		if drink_intake <= 0:
			failures.append("Alcohol service did not expose a positive intake delta.")
		if drink_run.drunk_level != 0 or drink_run.alcoholic_level != drink_intake or drink_run.pending_drunk_absorption_amount() != drink_intake:
			failures.append("Alcohol service did not queue exactly one delayed drink intake.")
		var first_absorption_msec := int(((drink_run.pending_drunk_absorption[0] as Dictionary).get("next_msec", 0))) if not drink_run.pending_drunk_absorption.is_empty() else 0
		drink_run.update_drunk_absorption(first_absorption_msec - 1)
		if drink_run.drunk_level != 0:
			failures.append("Alcohol absorption kicked in before its first interval.")
		drink_run.update_drunk_absorption(first_absorption_msec)
		if drink_run.drunk_level != 1 or drink_run.pending_drunk_absorption_amount() != drink_intake - 1:
			failures.append("Alcohol absorption did not add exactly one drunk point at the first interval.")
		drink_run.advance_environment_turns(6)
		if drink_run.drunk_level != 1:
			failures.append("Drunk decay ran while drink absorption was still pending.")
		drink_run.update_drunk_absorption(first_absorption_msec + drink_intake * RunState.DRUNK_ABSORPTION_INTERVAL_MSEC + 1)
		if drink_run.drunk_level != drink_intake or drink_run.pending_drunk_absorption_amount() != 0:
			failures.append("Alcohol service did not finish delayed absorption into the drunk meter.")
		var stacked_run: RunState = RunStateScript.new()
		stacked_run.start_new("SERVICE-ALCOHOL-STACK")
		stacked_run.drink_alcohol(10)
		stacked_run.drink_alcohol(10)
		stacked_run.drink_alcohol(10)
		var stacked_next_msec := int(((stacked_run.pending_drunk_absorption[0] as Dictionary).get("next_msec", 0))) if not stacked_run.pending_drunk_absorption.is_empty() else 0
		stacked_run.update_drunk_absorption(stacked_next_msec)
		if stacked_run.drunk_level != 3 or stacked_run.pending_drunk_absorption_amount() != 27:
			failures.append("Stacked drinks did not absorb one point per drink on the same interval.")
		var absorbed_luck := drink_run.effective_luck()
		var heat_before := drink_run.suspicion_level()
		var applied_heat := drink_run.add_suspicion("alcohol_heat_fixture", 2)
		if applied_heat <= 2 or drink_run.suspicion_level() <= heat_before + 2:
			failures.append("Alcohol pressure did not amplify positive heat gain.")
		drink_run.advance_environment_turns(6)
		if drink_run.drunk_level >= drink_run.alcoholic_level:
			failures.append("Alcohol did not decay into a dependency gap over time.")
		if drink_run.effective_luck() >= absorbed_luck:
			failures.append("Low drunk value under alcohol need did not lower effective luck.")

	var poor_run: RunState = RunStateScript.new()
	poor_run.start_new("SERVICE-POOR")
	poor_run.change_bankroll(-(poor_run.bankroll - maxi(0, cost - 1)))
	var poor_status := poor_run.service_hook_status(service)
	if bool(poor_status.get("available", true)):
		failures.append("Unaffordable service was not disabled.")

	var unsupported_run: RunState = RunStateScript.new()
	unsupported_run.start_new("SERVICE-UNSUPPORTED")
	var unsupported_before := unsupported_run.to_dict()
	var unsupported_result := _fixture_service_result(unsupported_run, {
		"id": "display_only_service",
		"display_name": "Display Only Service",
		"effect": {},
	}, "display_only_service")
	GameModule.apply_result(unsupported_run, unsupported_result)
	if JSON.stringify(unsupported_run.to_dict()) != JSON.stringify(unsupported_before):
		failures.append("Unsupported service mutated RunState.")

	var save_service: SaveService = SaveServiceScript.new()
	var slot_id := "foundation_check_service"
	var save_error: Error = save_service.save_run(run_state, slot_id)
	if save_error != OK:
		failures.append("Save service could not save service result state: %s." % save_error)
	else:
		var loaded = save_service.load_run(slot_id)
		if loaded == null:
			failures.append("Save service could not reload service result state.")
		elif loaded.bankroll != run_state.bankroll:
			failures.append("Service cost did not survive SaveService load.")
		elif int(loaded.suspicion.get("level", 0)) != int(run_state.suspicion.get("level", 0)):
			failures.append("Service suspicion result did not survive SaveService load.")
		elif loaded.story_log.size() != run_state.story_log.size():
			failures.append("Service story result did not survive SaveService load.")


func _fixture_service_result(run_state: RunState, service: Dictionary, service_id: String) -> Dictionary:
	var status := run_state.service_hook_status(service)
	var cost := int(status.get("cost", 0))
	var effect: Dictionary = service.get("effect", {}) if typeof(service.get("effect", {})) == TYPE_DICTIONARY else {}
	var deltas := GameModule.empty_result_deltas()
	deltas["bankroll_delta"] = -cost
	deltas["suspicion_delta"] = int(effect.get("suspicion_delta", 0))
	deltas["alcohol_intake"] = int(effect.get("alcohol_intake", 0))
	deltas["drunk_delta"] = int(effect.get("drunk_delta", 0))
	deltas["alcoholic_delta"] = int(effect.get("alcoholic_delta", 0))
	deltas["baseline_luck_delta"] = int(effect.get("baseline_luck_delta", 0))
	if typeof(effect.get("messages", [])) == TYPE_ARRAY:
		deltas["messages"] = (effect.get("messages", []) as Array).duplicate(true)
	var has_mutation := int(deltas.get("bankroll_delta", 0)) != 0 or int(deltas.get("suspicion_delta", 0)) != 0 or int(deltas.get("alcohol_intake", 0)) != 0 or int(deltas.get("drunk_delta", 0)) != 0 or int(deltas.get("alcoholic_delta", 0)) != 0 or int(deltas.get("baseline_luck_delta", 0)) != 0 or not (deltas.get("messages", []) as Array).is_empty()
	if not has_mutation:
		return GameModule.build_action_result({
			"ok": false,
			"type": "service_hook",
			"source_id": service_id,
			"action_id": "use_service_hook",
		})
	var message := str(service.get("message", "Used %s." % str(service.get("display_name", service_id))))
	deltas["story_log"] = [{
		"type": "service_hook",
		"id": service_id,
		"label": str(service.get("display_name", service_id)),
		"bankroll_delta": int(deltas.get("bankroll_delta", 0)),
		"suspicion_delta": int(deltas.get("suspicion_delta", 0)),
		"alcohol_intake": int(deltas.get("alcohol_intake", 0)),
		"drunk_delta": int(deltas.get("drunk_delta", 0)),
		"alcoholic_delta": int(deltas.get("alcoholic_delta", 0)),
		"baseline_luck_delta": int(deltas.get("baseline_luck_delta", 0)),
		"message": message,
	}]
	if (deltas.get("messages", []) as Array).is_empty():
		deltas["messages"] = [message]
	return GameModule.build_action_result({
		"ok": bool(status.get("available", false)),
		"type": "service_hook",
		"source_id": service_id,
		"action_id": "use_service_hook",
		"action_kind": "service",
		"bankroll_delta": int(deltas.get("bankroll_delta", 0)),
		"suspicion_delta": int(deltas.get("suspicion_delta", 0)),
		"deltas": deltas,
		"message": message,
	})


func _check_jazz_club_foundation(library: ContentLibrary, failures: Array) -> void:
	var jazz_archetype := _archetype_by_id(library, "jazz_club")
	if jazz_archetype.is_empty():
		failures.append("Jazz Club archetype is missing.")
		return
	if str(jazz_archetype.get("kind", "")) != "shop":
		failures.append("Jazz Club should be a shop/bar service venue, not a casino.")
	var jazz_game_pool := _string_array(jazz_archetype.get("game_pool", []))
	if jazz_game_pool != ["pull_tabs"]:
		failures.append("Jazz Club should always expose exactly the pull-tabs machine.")
	var jazz_visual_context: Dictionary = jazz_archetype.get("visual_context", {}) if typeof(jazz_archetype.get("visual_context", {})) == TYPE_DICTIONARY else {}
	if str(jazz_visual_context.get("scene_type", "")) != "jazz_club":
		failures.append("Jazz Club visual context should use the jazz_club scene type.")
	if str(jazz_visual_context.get("asset_path", "")).find("jazz_club.png") == -1:
		failures.append("Jazz Club should reference its own environment art asset.")
	if str(jazz_visual_context.get("description", "")).to_lower().find("pull-tab") == -1:
		failures.append("Jazz Club visual description should include the pull-tab machine.")
	for service_id in ["house_drink", "jazz_sax_round", "jazz_cello_round", "jazz_drummer_round", "jazz_band_tip_jar", "listen_to_jazz"]:
		if not _string_array(jazz_archetype.get("service_pool", [])).has(service_id):
			failures.append("Jazz Club service pool is missing %s." % service_id)
	for item_id in ["jazz_sax_lucky_coin", "jazz_cello_lucky_coin", "jazz_drummer_lucky_coin", "jazz_drummer_glasses"]:
		if library.item(item_id).is_empty():
			failures.append("Jazz reward item is missing: %s." % item_id)
	var jazz_route := library.route("jazz_club")
	if jazz_route.is_empty() or str(jazz_route.get("destination_archetype", "")) != "jazz_club":
		failures.append("Jazz Club travel route metadata is missing.")

	var run_state: RunState = RunStateScript.new()
	run_state.start_new("JAZZ-CLUB")
	var environment_a := EnvironmentInstance.from_archetype(jazz_archetype, 2, run_state.create_rng("jazz_a"), library)
	var environment_b := EnvironmentInstance.from_archetype(jazz_archetype, 3, run_state.create_rng("jazz_b"), library)
	if environment_a.game_ids != ["pull_tabs"]:
		failures.append("Generated Jazz Club did not place the guaranteed pull-tab machine.")
	var pull_tabs_game: GameModule = _load_surface_contract_game(library, "pull_tabs", failures)
	if pull_tabs_game != null:
		var jazz_environment_data := environment_a.to_dict()
		jazz_environment_data["game_states"] = {
			"pull_tabs": pull_tabs_game.generate_environment_state(run_state, jazz_environment_data, run_state.create_rng("jazz_pull_tabs_machine"))
		}
		jazz_environment_data["layout"] = EnvironmentInstance.ensure_generated_layout(jazz_environment_data)
		_check_jazz_club_layout(jazz_environment_data, failures)
	var profile_a := environment_a.music_profile
	var profile_b := environment_b.music_profile
	if str(profile_a.get("procedural_variant", "")) != "jazz_club":
		failures.append("Jazz Club music profile did not request the jazz generator.")
	if str(profile_a.get("generated_signature", "")).is_empty() or str(profile_a.get("generated_title", "")).is_empty():
		failures.append("Jazz Club music profile did not save generated title/signature data.")
	if JSON.stringify(profile_a) == JSON.stringify(profile_b):
		failures.append("Separate Jazz Club instances did not generate distinct music profiles.")

	run_state.set_environment(environment_a.to_dict())
	var resolver: RunActionService = RunActionServiceScript.new()
	resolver.setup(library, run_state)
	if resolver.service_hook("jazz_sax_round").is_empty() or resolver.service_hook("listen_to_jazz").is_empty() or resolver.service_hook("jazz_band_tip_jar").is_empty():
		failures.append("Jazz Club services did not appear in the action service.")
	var tip_option := resolver.hook_option("service", "jazz_band_tip_jar")
	if int(tip_option.get("cost", 0)) >= int(resolver.hook_option("service", "house_drink").get("cost", 0)):
		failures.append("Jazz band tip jar should cost less than a drink.")

	var generated_setup_run: RunState = RunStateScript.new()
	generated_setup_run.start_new("JAZZ-CLUB-SETUP")
	generated_setup_run.set_environment(environment_a.to_dict())
	var generated_resolver: RunActionService = RunActionServiceScript.new()
	generated_resolver.setup(library, generated_setup_run)
	generated_resolver.use_hook("service", "jazz_sax_round")
	var generated_jazz_id := str(generated_setup_run.current_environment.get("id", ""))
	var generated_holder := str(generated_setup_run.narrative_flags.get("jazz_%s_reward_holder" % generated_jazz_id, ""))
	var generated_threshold := int(generated_setup_run.narrative_flags.get("jazz_%s_reward_drinks_required" % generated_jazz_id, 0))
	if not ["sax", "cello", "drummer"].has(generated_holder):
		failures.append("Jazz Club did not persist a valid hidden reward holder.")
	if generated_threshold < 2 or generated_threshold > 4:
		failures.append("Jazz Club reward drink threshold was not in the 2-4 range.")

	var tip_run: RunState = RunStateScript.new()
	tip_run.start_new("JAZZ-CLUB-TIP")
	tip_run.bankroll = 500
	var tip_environment := EnvironmentInstance.from_archetype(jazz_archetype, 5, tip_run.create_rng("jazz_tip"), library)
	tip_run.set_environment(tip_environment.to_dict())
	var tip_jazz_id := str(tip_run.current_environment.get("id", ""))
	tip_run.narrative_flags["jazz_%s_reward_holder" % tip_jazz_id] = "cello"
	tip_run.narrative_flags["jazz_%s_reward_drinks_required" % tip_jazz_id] = 4
	var tip_resolver: RunActionService = RunActionServiceScript.new()
	tip_resolver.setup(library, tip_run)
	var tip_success_seen := false
	for _index in range(12):
		var favor_before := (
			int(tip_run.narrative_flags.get("jazz_%s_sax_favor" % tip_jazz_id, 0))
			+ int(tip_run.narrative_flags.get("jazz_%s_cello_favor" % tip_jazz_id, 0))
			+ int(tip_run.narrative_flags.get("jazz_%s_drummer_favor" % tip_jazz_id, 0))
		)
		var bankroll_before_tip := tip_run.bankroll
		var tip_result := tip_resolver.use_hook("service", "jazz_band_tip_jar")
		if not bool(tip_result.get("ok", false)):
			failures.append("Jazz band tip jar did not resolve.")
			break
		if tip_run.bankroll != bankroll_before_tip - 6:
			failures.append("Jazz band tip jar did not charge its configured cost.")
			break
		var favor_after := (
			int(tip_run.narrative_flags.get("jazz_%s_sax_favor" % tip_jazz_id, 0))
			+ int(tip_run.narrative_flags.get("jazz_%s_cello_favor" % tip_jazz_id, 0))
			+ int(tip_run.narrative_flags.get("jazz_%s_drummer_favor" % tip_jazz_id, 0))
		)
		if favor_after > favor_before:
			tip_success_seen = true
			break
	if not tip_success_seen:
		failures.append("Jazz band tip jar never contributed a drink purchase in the deterministic fixture.")

	var jazz_id := str(run_state.current_environment.get("id", ""))
	run_state.narrative_flags["jazz_%s_reward_holder" % jazz_id] = "cello"
	run_state.narrative_flags["jazz_%s_reward_drinks_required" % jazz_id] = 3
	var bankroll_before_wrong_round := run_state.bankroll
	var wrong_sax := resolver.use_hook("service", "jazz_sax_round")
	if not bool(wrong_sax.get("ok", false)):
		failures.append("Jazz wrong-musician round did not resolve.")
	if run_state.inventory.has("jazz_sax_lucky_coin"):
		failures.append("Wrong Jazz Club musician awarded a sax lucky coin.")
	if str(wrong_sax.get("message", "")).to_lower().find("nothing") == -1:
		failures.append("Wrong Jazz Club musician did not tell the player there was nothing to give.")
	if run_state.bankroll != bankroll_before_wrong_round - 8:
		failures.append("Wrong Jazz Club musician round did not charge exactly one drink.")
	if not bool(run_state.narrative_flags.get("jazz_%s_sax_no_item" % jazz_id, false)):
		failures.append("Wrong Jazz Club musician was not remembered as empty.")
	if bool(resolver.hook_option("service", "jazz_sax_round").get("enabled", false)):
		failures.append("Wrong Jazz Club musician remained available after saying there was nothing to give.")

	var baseline_before_coin := run_state.baseline_luck
	resolver.use_hook("service", "jazz_cello_round")
	if run_state.inventory.has("jazz_cello_lucky_coin"):
		failures.append("Jazz Club holder paid before the configured drink threshold.")
	resolver.use_hook("service", "jazz_cello_round")
	var cello_reward := resolver.use_hook("service", "jazz_cello_round")
	if not bool(cello_reward.get("ok", false)):
		failures.append("Jazz Club holder threshold round did not resolve.")
	if not run_state.inventory.has("jazz_cello_lucky_coin"):
		failures.append("Jazz Club holder did not award the cello lucky coin at the drink threshold.")
	if run_state.inventory.has("jazz_sax_lucky_coin") or run_state.inventory.has("jazz_drummer_glasses"):
		failures.append("Jazz Club awarded more than the single hidden musician reward.")
	if run_state.baseline_luck != baseline_before_coin + 5:
		failures.append("Jazz Club coin reward did not apply the expected luck bonus.")
	if not bool(run_state.narrative_flags.get("jazz_%s_reward_claimed" % jazz_id, false)):
		failures.append("Jazz Club did not mark the local reward as claimed.")
	if bool(resolver.hook_option("service", "jazz_drummer_round").get("enabled", false)):
		failures.append("Jazz Club kept musician rewards open after one item was claimed.")
	var free_drink_option := resolver.hook_option("service", "house_drink")
	if int(free_drink_option.get("cost", -1)) != 0:
		failures.append("Jazz bar did not comp drinks after a jazz reward item.")
	var bankroll_before_free_drink := run_state.bankroll
	var free_drink := resolver.use_hook("service", "house_drink")
	if not bool(free_drink.get("ok", false)):
		failures.append("Comped Jazz Club drink did not resolve.")
	if run_state.bankroll != bankroll_before_free_drink:
		failures.append("Comped Jazz Club drink still charged bankroll.")
	if run_state.pending_drunk_absorption_amount() <= 0:
		failures.append("Comped Jazz Club drink did not queue alcohol intake.")

	var drummer_environment := EnvironmentInstance.from_archetype(jazz_archetype, 4, run_state.create_rng("jazz_drummer"), library)
	run_state.set_environment(drummer_environment.to_dict())
	var drummer_jazz_id := str(run_state.current_environment.get("id", ""))
	run_state.narrative_flags["jazz_%s_reward_holder" % drummer_jazz_id] = "drummer"
	run_state.narrative_flags["jazz_%s_reward_drinks_required" % drummer_jazz_id] = 2
	resolver.use_hook("service", "jazz_drummer_round")
	var drummer_coin_reward := resolver.use_hook("service", "jazz_drummer_round")
	if not bool(drummer_coin_reward.get("ok", false)):
		failures.append("Jazz drummer short-stay threshold round did not resolve.")
	if not run_state.inventory.has("jazz_drummer_lucky_coin"):
		failures.append("Drummer holder did not award a lucky coin before two listened sets.")
	if run_state.inventory.has("jazz_drummer_glasses"):
		failures.append("Drummer awarded legend glasses before two listened sets.")

	var glasses_environment := EnvironmentInstance.from_archetype(jazz_archetype, 6, run_state.create_rng("jazz_drummer_glasses"), library)
	run_state.set_environment(glasses_environment.to_dict())
	var glasses_jazz_id := str(run_state.current_environment.get("id", ""))
	run_state.narrative_flags["jazz_%s_reward_holder" % glasses_jazz_id] = "drummer"
	run_state.narrative_flags["jazz_%s_reward_drinks_required" % glasses_jazz_id] = 2
	resolver.use_hook("service", "listen_to_jazz")
	resolver.use_hook("service", "listen_to_jazz")
	resolver.use_hook("service", "jazz_drummer_round")
	var glasses_reward := resolver.use_hook("service", "jazz_drummer_round")
	if not bool(glasses_reward.get("ok", false)):
		failures.append("Jazz drummer glasses threshold round did not resolve.")
	if not run_state.inventory.has("jazz_drummer_glasses"):
		failures.append("Drummer holder did not award the legend glasses after two listened sets.")

	run_state.add_suspicion("jazz_heat_fixture", 25, "behavior", false, {"environment_id": str(run_state.current_environment.get("id", ""))})
	var heat_before_glasses := run_state.suspicion_level()
	var glasses_option := resolver.hook_option("service", "show_drummer_glasses")
	if not bool(glasses_option.get("enabled", false)):
		failures.append("Legend glasses service did not appear when heat was present.")
	var glasses_clear := resolver.use_hook("service", "show_drummer_glasses")
	if not bool(glasses_clear.get("ok", false)):
		failures.append("Legend glasses heat-clear service did not resolve.")
	if run_state.suspicion_level() != 0:
		failures.append("Legend glasses did not clear all local heat.")
	var glasses_result: Dictionary = glasses_clear.get("result", {})
	if int(glasses_result.get("suspicion_delta", 0)) != -heat_before_glasses:
		failures.append("Legend glasses result did not report the full heat reduction.")
	run_state.add_suspicion("jazz_heat_again", 10, "behavior", false, {"environment_id": str(run_state.current_environment.get("id", ""))})
	if bool(resolver.hook_option("service", "show_drummer_glasses").get("enabled", false)):
		failures.append("Legend glasses were reusable in the same venue location.")

	var saved := run_state.to_dict()
	var restored: RunState = RunStateScript.new()
	restored.from_dict(saved)
	if not restored.inventory.has("jazz_drummer_glasses") or not restored.inventory.has("jazz_drummer_lucky_coin") or not restored.inventory.has("jazz_cello_lucky_coin"):
		failures.append("Jazz reward inventory did not survive save/load.")
	if JSON.stringify(restored.current_environment.get("music_profile", {})) != JSON.stringify(run_state.current_environment.get("music_profile", {})):
		failures.append("Jazz generated music profile did not survive save/load.")
	if restored.story_log.size() != run_state.story_log.size():
		failures.append("Jazz story entries did not survive save/load.")

	var bar_archetype := _archetype_by_id(library, "bar")
	var bar_environment := EnvironmentInstance.from_archetype(bar_archetype, 4, run_state.create_rng("jazz_bar"), library)
	run_state.set_environment(bar_environment.to_dict())
	run_state.add_suspicion("bar_heat_fixture", 12, "behavior", false, {"environment_id": str(run_state.current_environment.get("id", ""))})
	if not bool(resolver.hook_option("service", "show_drummer_glasses").get("enabled", false)):
		failures.append("Legend glasses were not usable at a different venue location.")
	resolver.use_hook("service", "show_drummer_glasses")
	if run_state.suspicion_level() != 0:
		failures.append("Legend glasses did not clear heat at a second venue location.")


func _check_jazz_club_layout(environment_data: Dictionary, failures: Array) -> void:
	var layout: Dictionary = environment_data.get("layout", {}) if typeof(environment_data.get("layout", {})) == TYPE_DICTIONARY else {}
	var object_rects: Dictionary = layout.get("object_rects", {}) if typeof(layout.get("object_rects", {})) == TYPE_DICTIONARY else {}
	for object_id in [
		"game:pull_tabs",
		"game_hook:pull_tabs:ticket_redeemer",
		"shopkeeper:merchant",
		"service:house_drink",
		"service:jazz_sax_round",
		"service:jazz_cello_round",
		"service:jazz_drummer_round",
		"service:jazz_band_tip_jar",
		"service:listen_to_jazz",
	]:
		if not object_rects.has(object_id):
			failures.append("Jazz Club layout is missing object placement for %s." % object_id)
	var seen_centers := {}
	var keys := object_rects.keys()
	for index in range(keys.size()):
		var key := str(keys[index])
		var rect := _layout_rect_from_dict(object_rects.get(key, {}))
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			failures.append("Jazz Club object placement has an empty rect for %s." % key)
			continue
		var center_key := "%0.4f,%0.4f" % [rect.position.x + rect.size.x * 0.5, rect.position.y + rect.size.y * 0.5]
		if seen_centers.has(center_key):
			failures.append("Jazz Club objects share the same map location: %s and %s." % [str(seen_centers[center_key]), key])
		else:
			seen_centers[center_key] = key
		for other_index in range(index + 1, keys.size()):
			var other_key := str(keys[other_index])
			var other_rect := _layout_rect_from_dict(object_rects.get(other_key, {}))
			if other_rect.size.x <= 0.0 or other_rect.size.y <= 0.0:
				continue
			if _layout_rects_overlap_with_gap(rect, other_rect):
				failures.append("Jazz Club objects overlap on the map: %s and %s." % [key, other_key])


func _layout_rect_from_dict(value: Variant) -> Rect2:
	if typeof(value) != TYPE_DICTIONARY:
		return Rect2()
	var data: Dictionary = value
	return Rect2(
		Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0))),
		Vector2(float(data.get("w", 0.0)), float(data.get("h", 0.0)))
	)


func _layout_rects_overlap_with_gap(first: Rect2, second: Rect2) -> bool:
	var gap := Vector2(8.0 / float(ArtContractsScript.ENVIRONMENT_BOARD_SIZE.x), 8.0 / float(ArtContractsScript.ENVIRONMENT_BOARD_SIZE.y))
	var padded_first := Rect2(first.position - gap, first.size + gap * 2.0)
	var padded_second := Rect2(second.position - gap, second.size + gap * 2.0)
	return padded_first.intersects(padded_second)


# Checks one supported lender debt interaction, display-only lenders, and save/load.
func _check_lender_debt_foundation(library: ContentLibrary, failures: Array) -> void:
	var lender := library.lender("street_lender")
	if lender.is_empty():
		failures.append("Lender fixture is missing: street_lender.")
		return
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("LENDER-DEBT")
	var status := run_state.lender_hook_status(lender)
	if not bool(status.get("available", false)):
		failures.append("Supported lender was unexpectedly disabled.")
	var before_bankroll := run_state.bankroll
	var before_suspicion := int(run_state.suspicion.get("level", 0))
	var result := _fixture_lender_result(run_state, lender, "street_lender")
	GameModule.apply_result(run_state, result)
	if run_state.bankroll <= before_bankroll:
		failures.append("Supported lender did not provide bankroll through result-delta.")
	var debt_changes: Array = result.get("deltas", {}).get("debt_changes", [])
	if run_state.debt.size() != debt_changes.size():
		failures.append("Supported lender did not add debt through result-delta.")
	elif str((run_state.debt[0] as Dictionary).get("lender_id", "")) != "street_lender":
		failures.append("Supported lender debt did not preserve lender id.")
	if int(run_state.suspicion.get("level", 0)) <= before_suspicion:
		failures.append("Supported lender did not apply pressure/risk through result-delta.")
	if not bool(run_state.narrative_flags.get("street_lender_debt", false)):
		failures.append("Supported lender did not set its run flag through result-delta.")
	if run_state.story_log.is_empty() or str((run_state.story_log[run_state.story_log.size() - 1] as Dictionary).get("type", "")) != "lender_hook":
		failures.append("Supported lender did not record a lender story entry.")
	var repeated_status := run_state.lender_hook_status(lender)
	if bool(repeated_status.get("available", true)):
		failures.append("Active debt did not disable repeat lender use.")

	run_state.change_bankroll(-50)
	if run_state.economy() != "distressed":
		failures.append("Debt plus low bankroll did not create economy pressure after lender interaction.")

	var display_only_lender := library.lender("motel_friend")
	if display_only_lender.is_empty():
		failures.append("Display-only lender fixture is missing: motel_friend.")
		return
	var unsupported_run: RunState = RunStateScript.new()
	unsupported_run.start_new("LENDER-DISPLAY-ONLY")
	var unsupported_before := unsupported_run.to_dict()
	var unsupported_result := _fixture_lender_result(unsupported_run, display_only_lender, "motel_friend")
	GameModule.apply_result(unsupported_run, unsupported_result)
	if JSON.stringify(unsupported_run.to_dict()) != JSON.stringify(unsupported_before):
		failures.append("Unsupported lender mutated RunState.")

	var save_service: SaveService = SaveServiceScript.new()
	var slot_id := "foundation_check_lender"
	var save_error: Error = save_service.save_run(run_state, slot_id)
	if save_error != OK:
		failures.append("Save service could not save lender debt state: %s." % save_error)
	else:
		var loaded = save_service.load_run(slot_id)
		if loaded == null:
			failures.append("Save service could not reload lender debt state.")
		elif loaded.debt.size() != run_state.debt.size():
			failures.append("Lender debt did not survive SaveService load.")
		elif loaded.bankroll != run_state.bankroll:
			failures.append("Lender bankroll state did not survive SaveService load.")
		elif int(loaded.suspicion.get("level", 0)) != int(run_state.suspicion.get("level", 0)):
			failures.append("Lender suspicion state did not survive SaveService load.")
		elif loaded.economy() != run_state.economy():
			failures.append("Lender economy pressure did not survive SaveService load.")


func _fixture_lender_result(run_state: RunState, lender: Dictionary, lender_id: String) -> Dictionary:
	var status := run_state.lender_hook_status(lender)
	var effect: Dictionary = lender.get("effect", {}) if typeof(lender.get("effect", {})) == TYPE_DICTIONARY else {}
	var deltas := GameModule.empty_result_deltas()
	for key in deltas.keys():
		var value: Variant = effect.get(key, deltas[key])
		if typeof(value) == TYPE_ARRAY:
			deltas[key] = (value as Array).duplicate(true)
		elif typeof(value) == TYPE_DICTIONARY:
			deltas[key] = (value as Dictionary).duplicate(true)
		else:
			deltas[key] = value
	var has_mutation := int(deltas.get("bankroll_delta", 0)) != 0 or int(deltas.get("suspicion_delta", 0)) != 0
	has_mutation = has_mutation or not (deltas.get("debt_changes", []) as Array).is_empty()
	has_mutation = has_mutation or not (deltas.get("flags_set", {}) as Dictionary).is_empty()
	if not has_mutation:
		return GameModule.build_action_result({
			"ok": false,
			"type": "lender_hook",
			"source_id": lender_id,
			"action_id": "use_lender_hook",
		})
	var message := str(lender.get("message", "Used %s." % str(lender.get("display_name", lender_id))))
	deltas["story_log"] = [{
		"type": "lender_hook",
		"id": lender_id,
		"label": str(lender.get("display_name", lender_id)),
		"bankroll_delta": int(deltas.get("bankroll_delta", 0)),
		"suspicion_delta": int(deltas.get("suspicion_delta", 0)),
		"message": message,
	}]
	if (deltas.get("messages", []) as Array).is_empty():
		deltas["messages"] = [message]
	return GameModule.build_action_result({
		"ok": bool(status.get("available", false)),
		"type": "lender_hook",
		"source_id": lender_id,
		"action_id": "use_lender_hook",
		"action_kind": "lender",
		"bankroll_delta": int(deltas.get("bankroll_delta", 0)),
		"suspicion_delta": int(deltas.get("suspicion_delta", 0)),
		"deltas": deltas,
		"message": message,
	})


# Checks behavior-first suspicion cues, downstream risky-action pressure, event eligibility, and save/load.
func _check_suspicion_security_foundation(failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("SUSPICION-SECURITY")
	var game := GameModule.new()
	game.setup({
		"id": "security_pressure_game",
		"display_name": "Security Pressure Game",
		"family": "fixture",
		"legal_actions": [{"id": "legal_fixture", "label": "Play Clean", "win_chance": 50, "payout_mult": 2}],
		"cheat_actions": [{"id": "risky_fixture", "label": "Palm The Card", "win_chance": 70, "payout_mult": 2, "suspicion_delta": 2}],
	})
	var environment := {
		"id": "security_pressure_environment",
		"kind": "casino",
		"tier": 1,
		"economic_profile": {
			"stake_floor": 1,
			"stake_ceiling": 20,
		},
	}
	var quiet_actions := game.actions(run_state, environment)
	var quiet_cheat_actions: Array = quiet_actions.get("cheat_actions", [])
	if quiet_cheat_actions.is_empty():
		failures.append("Security pressure fixture did not expose a risky action.")
		return
	var quiet_risk := int((quiet_cheat_actions[0] as Dictionary).get("suspicion_delta", 0))
	if quiet_risk != 2:
		failures.append("Quiet security pressure should not alter base risky action suspicion.")

	run_state.add_suspicion("watchful_floor", 25, "behavior", false, {"environment_id": "security_pressure_environment"})
	if run_state.suspicion_level() != 25:
		failures.append("RunState suspicion_level did not expose bounded suspicion.")
	if run_state.security_risk_bonus("cheat") <= 0:
		failures.append("Elevated suspicion did not produce risky-action pressure.")
	if run_state.security_pressure_summary().is_empty() or run_state.security_pressure_summary().contains("25"):
		failures.append("Security pressure summary should be behavior-first, not raw-meter-first.")
	var pressured_actions := game.actions(run_state, environment)
	var pressured_cheat_actions: Array = pressured_actions.get("cheat_actions", [])
	var pressured_risk := int((pressured_cheat_actions[0] as Dictionary).get("suspicion_delta", 0))
	if pressured_risk <= quiet_risk:
		failures.append("Suspicion did not increase visible risky-action consequence.")
	if int((pressured_cheat_actions[0] as Dictionary).get("security_pressure_bonus", 0)) <= 0:
		failures.append("Risky-action view did not expose security pressure bonus.")

	var before_suspicion := run_state.suspicion_level()
	var before_cue_count := (run_state.suspicion.get("cues", []) as Array).size()
	var result := game.resolve("risky_fixture", 1, run_state, environment, run_state.create_rng())
	if int(result.get("suspicion_delta", 0)) != pressured_risk:
		failures.append("Risky action result did not apply security-adjusted suspicion.")
	if run_state.suspicion_level() != before_suspicion + pressured_risk:
		failures.append("Risky action did not update RunState suspicion by adjusted consequence.")
	if (run_state.suspicion.get("cues", []) as Array).size() <= before_cue_count:
		failures.append("Risky action did not add a behavior cue.")
	if not str(result.get("message", "")).contains("risky moves draw more heat"):
		failures.append("Risky action result did not communicate security pressure.")

	var high_heat_run: RunState = RunStateScript.new()
	high_heat_run.start_new("HIGH-HEAT-PRESSURE")
	high_heat_run.add_suspicion("heated_floor", 66, "behavior", false, {"environment_id": "security_pressure_environment"})
	var high_heat_actions := game.actions(high_heat_run, environment)
	var high_heat_cheat_actions: Array = high_heat_actions.get("cheat_actions", [])
	var high_heat_risk := int((high_heat_cheat_actions[0] as Dictionary).get("suspicion_delta", 0)) if not high_heat_cheat_actions.is_empty() else 0
	if high_heat_risk <= pressured_risk:
		failures.append("High heat did not materially increase risky-action heat consequence.")
	var high_heat_result := game.resolve("risky_fixture", 10, high_heat_run, environment, high_heat_run.create_rng())
	var high_heat_story: Dictionary = {}
	var high_heat_story_log: Array = high_heat_result.get("deltas", {}).get("story_log", [])
	if not high_heat_story_log.is_empty() and typeof(high_heat_story_log[0]) == TYPE_DICTIONARY:
		high_heat_story = high_heat_story_log[0] as Dictionary
	if int(high_heat_story.get("security_bankroll_delta", 0)) >= 0:
		failures.append("High heat did not add a material security cost to risky action results.")
	if not str(high_heat_result.get("message", "")).contains("shakedown") and not str(high_heat_result.get("message", "")).contains("costly"):
		failures.append("High heat result did not communicate the security consequence.")

	var severe_heat_run: RunState = RunStateScript.new()
	severe_heat_run.start_new("SEVERE-HEAT-PRESSURE")
	severe_heat_run.add_suspicion("closing_in", 92, "behavior", false, {"environment_id": "security_pressure_environment"})
	var severe_heat_result := game.resolve("risky_fixture", 1, severe_heat_run, environment, severe_heat_run.create_rng())
	if not bool(severe_heat_result.get("ended", false)):
		failures.append("Very high heat did not create visible run-ending pressure.")
	if severe_heat_run.run_status != RunState.RUN_STATUS_FAILED:
		failures.append("Very high heat did not fail the run through RunState.")
	if severe_heat_run.run_failure_reason != RunState.FAILURE_POLICE_CAPTURE:
		failures.append("Very high heat failure was not recorded as police capture.")
	if not str(severe_heat_result.get("message", "")).contains("cuffs"):
		failures.append("Very high heat result did not explain the police capture consequence.")

	var capture_run: RunState = RunStateScript.new()
	capture_run.start_new("DIRECT-POLICE-CAPTURE")
	capture_run.add_suspicion("risk_meter_full", 100, "behavior", true, {"environment_id": "security_pressure_environment"})
	if capture_run.run_status != RunState.RUN_STATUS_FAILED or capture_run.run_failure_reason != RunState.FAILURE_POLICE_CAPTURE:
		failures.append("Risk meter reaching 100 did not immediately fail the run as police capture.")

	var event := EventModule.new()
	event.setup({
		"id": "security_pressure_event",
		"display_name": "Security Pressure Event",
		"type": "security",
		"min_suspicion": run_state.suspicion_level() + 5,
		"payload": {
			"choices": [{"id": "wait", "label": "Wait", "consequences": {"suspicion_delta": 1}}],
		},
	})
	if event.can_trigger(run_state, environment):
		failures.append("Suspicion-gated event triggered before enough pressure was present.")
	run_state.add_suspicion("guard_attention", 5, "behavior", false, {"environment_id": "security_pressure_environment"})
	if not event.can_trigger(run_state, environment):
		failures.append("Suspicion-gated event did not trigger after enough pressure was present.")

	var local_heat_run: RunState = RunStateScript.new()
	local_heat_run.start_new("LOCAL-HEAT-MEMORY")
	local_heat_run.set_environment({"id": "gas_station_casino_001", "archetype_id": "gas_station_casino"})
	local_heat_run.add_suspicion("hot_table", 80, "behavior", false, {"environment_id": "gas_station_casino_001"})
	var far_travel := local_heat_run.begin_travel_suspicion_decay({"distance": "far", "risk_decay": 85}, "motel")
	local_heat_run.set_environment({"id": "motel_002", "archetype_id": "motel"})
	var far_decay := local_heat_run.finish_travel_suspicion_decay(far_travel)
	if int(far_decay.get("cooled", 0)) <= 0:
		failures.append("Far travel did not cool local heat before arrival.")
	if local_heat_run.suspicion_level() > 15:
		failures.append("Far travel carried too much local heat into a distant environment.")
	var far_return := local_heat_run.begin_travel_suspicion_decay({"distance": "far", "risk_decay": 85}, "gas_station_casino")
	local_heat_run.set_environment({"id": "gas_station_casino_003", "archetype_id": "gas_station_casino"})
	local_heat_run.finish_travel_suspicion_decay(far_return)
	if local_heat_run.suspicion_level() < 70 or local_heat_run.suspicion_level() > 75:
		failures.append("Returning to a hot venue should remember heat with only a small cooldown.")

	var near_heat_run: RunState = RunStateScript.new()
	near_heat_run.start_new("NEAR-HEAT-MEMORY")
	near_heat_run.set_environment({"id": "gas_station_casino_001", "archetype_id": "gas_station_casino"})
	near_heat_run.add_suspicion("hot_table", 80, "behavior", false, {"environment_id": "gas_station_casino_001"})
	var near_travel := near_heat_run.begin_travel_suspicion_decay({"distance": "near", "risk_decay": 12}, "bar")
	near_heat_run.set_environment({"id": "bar_002", "archetype_id": "bar"})
	near_heat_run.finish_travel_suspicion_decay(near_travel)
	var near_return := near_heat_run.begin_travel_suspicion_decay({"distance": "near", "risk_decay": 12}, "gas_station_casino")
	near_heat_run.set_environment({"id": "gas_station_casino_003", "archetype_id": "gas_station_casino"})
	near_heat_run.finish_travel_suspicion_decay(near_return)
	if near_heat_run.suspicion_level() < 65:
		failures.append("Nearby travel should preserve most local heat when returning to the source venue.")
	var same_heat_run: RunState = RunStateScript.new()
	same_heat_run.start_new("SAME-HEAT-MEMORY")
	same_heat_run.set_environment({"id": "bar_001", "archetype_id": "bar"})
	same_heat_run.add_suspicion("watched_bar", 40, "behavior", false, {"environment_id": "bar_001"})
	var same_travel := same_heat_run.begin_travel_suspicion_decay({"distance": "same", "risk_decay": 0}, "bar")
	same_heat_run.set_environment({"id": "bar_002", "archetype_id": "bar"})
	same_heat_run.finish_travel_suspicion_decay(same_travel)
	if same_heat_run.suspicion_level() != 40:
		failures.append("Same-location travel should not cool local heat.")
	var near_snapshot := near_heat_run.to_dict()
	var near_restored: RunState = RunStateScript.new()
	near_restored.from_dict(near_snapshot)
	if near_restored.suspicion_level() != near_heat_run.suspicion_level():
		failures.append("Local heat memory did not survive RunState serialization.")

	var time_heat_run: RunState = RunStateScript.new()
	time_heat_run.start_new("TIME-HEAT-COOLING")
	time_heat_run.set_environment({"id": "bar_001", "archetype_id": "bar"})
	time_heat_run.add_suspicion("regulars_watch", 20, "behavior", false, {"environment_id": "bar_001"})
	time_heat_run.advance_environment_turns(1)
	if time_heat_run.suspicion_level() != 20:
		failures.append("In-room heat cooled too quickly after one turn.")
	time_heat_run.advance_environment_turns(1)
	if time_heat_run.suspicion_level() != 19:
		failures.append("In-room heat did not cool slowly over time.")

	var save_service: SaveService = SaveServiceScript.new()
	var slot_id := "foundation_check_suspicion"
	var save_error: Error = save_service.save_run(run_state, slot_id)
	if save_error != OK:
		failures.append("Save service could not save suspicion/security state: %s." % save_error)
	else:
		var loaded = save_service.load_run(slot_id)
		if loaded == null:
			failures.append("Save service could not reload suspicion/security state.")
		elif loaded.suspicion_level() != run_state.suspicion_level():
			failures.append("Suspicion level did not survive SaveService load.")
		elif (loaded.suspicion.get("cues", []) as Array).size() != (run_state.suspicion.get("cues", []) as Array).size():
			failures.append("Suspicion cues did not survive SaveService load.")
		elif loaded.security_risk_bonus("cheat") != run_state.security_risk_bonus("cheat"):
			failures.append("Security pressure bonus did not survive SaveService load.")

	var severe_slot_id := "foundation_check_severe_heat"
	var severe_save_error: Error = save_service.save_run(severe_heat_run, severe_slot_id)
	if severe_save_error != OK:
		failures.append("Save service could not save severe heat state: %s." % severe_save_error)
	else:
		var loaded_severe = save_service.load_run(severe_slot_id)
		if loaded_severe == null:
			failures.append("Save service could not reload severe heat state.")
		elif loaded_severe.suspicion_level() != severe_heat_run.suspicion_level():
			failures.append("Severe heat level did not survive SaveService load.")
		elif loaded_severe.run_status != severe_heat_run.run_status:
			failures.append("Severe heat run-ending pressure did not survive SaveService load.")
		elif loaded_severe.run_failure_reason != severe_heat_run.run_failure_reason:
			failures.append("Severe heat failure reason did not survive SaveService load.")


# Checks one deterministic vertical slice where M2 systems affect each other through existing contracts.
func _check_m2_system_interaction_scenario(library: ContentLibrary, failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("M2-SYSTEM-SCENARIO")
	var generator: RunGenerator = RunGeneratorScript.new(library)
	var environment: EnvironmentInstance = generator.next_environment(run_state)
	if run_state.current_environment.is_empty():
		failures.append("M2 scenario did not enter a generated environment.")
		return
	if environment.game_ids.is_empty():
		failures.append("M2 scenario generated environment without a game option.")
		return

	var pressure_result := _fixture_system_pressure_result(run_state.current_environment, -60, "A cold streak tightens the run.")
	GameModule.apply_result(run_state, pressure_result)
	if run_state.economy() != "volatile":
		failures.append("M2 scenario did not create observable economy pressure.")

	var item_def := library.item("instant_coffee")
	if item_def.is_empty():
		failures.append("M2 scenario item fixture is missing: instant_coffee.")
		return
	GameModule.apply_result(run_state, _fixture_item_purchase_result(item_def, 4, str(run_state.current_environment.get("id", ""))))
	if not run_state.inventory.has("instant_coffee"):
		failures.append("M2 scenario did not buy/apply an item through result-delta inventory.")

	var game_id := str(environment.game_ids[0])
	var game_definition := library.game(game_id)
	if game_definition.is_empty():
		failures.append("M2 scenario generated unknown game: %s." % game_id)
		return
	var game := GameModule.new()
	game.setup(game_definition, library)
	var actions := game.actions(run_state, run_state.current_environment)
	var cheat_actions: Array = actions.get("cheat_actions", [])
	if cheat_actions.is_empty():
		failures.append("M2 scenario game did not expose a risky action.")
		return
	var before_suspicion := run_state.suspicion_level()
	var risky_action_id := str((cheat_actions[0] as Dictionary).get("id", ""))
	var risky_result := game.resolve(risky_action_id, 5, run_state, run_state.current_environment, run_state.create_rng())
	_check_action_result_shape(risky_result, "cheat", failures)
	if run_state.suspicion_level() <= before_suspicion:
		failures.append("M2 scenario risky action did not change suspicion/security state.")
	if (run_state.suspicion.get("cues", []) as Array).is_empty():
		failures.append("M2 scenario risky action did not create a security cue.")

	var scenario_environment := run_state.current_environment.duplicate(true)
	var event_ids := _string_array_from_variant(scenario_environment.get("event_ids", []))
	if not event_ids.has("parking_lot_tip"):
		event_ids.append("parking_lot_tip")
	scenario_environment["event_ids"] = event_ids
	var travel_hooks := _string_array_from_variant(scenario_environment.get("travel_hooks", []))
	if not travel_hooks.has("small_underground_casino"):
		travel_hooks.append("small_underground_casino")
	scenario_environment["travel_hooks"] = travel_hooks
	run_state.set_environment(scenario_environment)

	var underground_route := library.route("small_underground_casino")
	if underground_route.is_empty():
		failures.append("M2 scenario route fixture is missing: small_underground_casino.")
		return
	if bool(run_state.travel_route_status(underground_route).get("available", true)):
		failures.append("M2 scenario route should be locked before the event outcome.")
	var event_def := library.event("parking_lot_tip")
	if event_def.is_empty():
		failures.append("M2 scenario event fixture is missing: parking_lot_tip.")
		return
	var event := EventModule.new()
	event.setup(event_def)
	if not event.can_trigger(run_state, run_state.current_environment):
		failures.append("M2 scenario event did not respond as eligible from current system state.")
		return
	var event_before := _run_state_result_snapshot(run_state)
	var event_result := event.resolve(run_state, run_state.current_environment, "follow_tip")
	_check_event_result_delta_shape(event_result, failures)
	_check_event_result_applied(event_before, run_state, event_result, "M2 scenario event result", failures)
	if not bool(run_state.narrative_flags.get("underground_tip", false)):
		failures.append("M2 scenario event did not set its downstream travel flag.")
	if not bool(run_state.travel_route_status(underground_route).get("available", false)):
		failures.append("M2 scenario event outcome did not unlock the gated route choice.")

	var before_travel_bankroll := run_state.bankroll
	var before_travel_suspicion := run_state.suspicion_level()
	var travel_result := _fixture_travel_result(run_state, underground_route, "small_underground_casino")
	GameModule.apply_result(run_state, travel_result)
	if run_state.bankroll != before_travel_bankroll - int(underground_route.get("cost", 0)):
		failures.append("M2 scenario travel cost did not apply through result-delta.")
	if run_state.suspicion_level() != before_travel_suspicion + int(underground_route.get("suspicion_delta", 0)):
		failures.append("M2 scenario travel risk did not apply through result-delta.")

	var lender := library.lender("street_lender")
	if lender.is_empty():
		failures.append("M2 scenario lender fixture is missing: street_lender.")
		return
	var lender_result := _fixture_lender_result(run_state, lender, "street_lender")
	GameModule.apply_result(run_state, lender_result)
	if run_state.debt.is_empty():
		failures.append("M2 scenario supported lender did not add debt.")
	if run_state.economy() != "distressed":
		failures.append("M2 scenario debt plus low bankroll did not affect economy pressure.")

	var service := library.service("cashier_tip")
	if service.is_empty():
		failures.append("M2 scenario service fixture is missing: cashier_tip.")
		return
	var service_before_bankroll := run_state.bankroll
	var service_before_suspicion := run_state.suspicion_level()
	var service_result := _fixture_service_result(run_state, service, "cashier_tip")
	GameModule.apply_result(run_state, service_result)
	if run_state.bankroll != service_before_bankroll - int(service.get("cost", 0)):
		failures.append("M2 scenario service cost did not apply through result-delta.")
	if run_state.suspicion_level() >= service_before_suspicion:
		failures.append("M2 scenario supported service did not reduce suspicion pressure.")

	var expected := _save_service_expected_snapshot(run_state)
	var save_service: SaveService = SaveServiceScript.new()
	var slot_id := "foundation_check_m2_system_scenario"
	var save_error: Error = save_service.save_run(run_state, slot_id)
	if save_error != OK:
		failures.append("Save service could not save M2 system scenario state: %s." % save_error)
		return
	var loaded = save_service.load_run(slot_id)
	if loaded == null:
		failures.append("Save service could not reload M2 system scenario state.")
		return
	_check_run_state_save_round_trip(expected, loaded.to_dict(), failures)


# Checks the boss-floor demo objective triggers and resolves The House Calls through RunState.
func _check_demo_boss_objective_foundation(library: ContentLibrary, failures: Array) -> void:
	if not library.prestige_purchases.is_empty():
		failures.append("Initial demo victory should not be a purchasable prestige token.")
	var boss_archetype := _archetype_by_id(library, "grand_casino")
	if boss_archetype.is_empty():
		failures.append("Grand Casino boss archetype is missing.")
		return
	var objective: Dictionary = boss_archetype.get("demo_objective", {}) if typeof(boss_archetype.get("demo_objective", {})) == TYPE_DICTIONARY else {}
	if objective.is_empty() or str(objective.get("type", "")) != "bankroll_target":
		failures.append("Grand Casino must define a bankroll-target demo objective.")
		return
	var finale_event_id := str(objective.get("finale_event_id", ""))
	if finale_event_id != "the_house_calls":
		failures.append("Grand Casino demo objective must route into The House Calls finale event.")
		return
	if int(objective.get("target_bankroll", -1)) != 0:
		failures.append("Grand Casino Players Card objective should not require a total bankroll target.")
	var route := library.route("grand_casino")
	if route.is_empty() or int(route.get("cost", 0)) < 100:
		failures.append("Grand Casino route must exist and cost about $100.")
	elif int(route.get("requires_travel_count_min", 0)) < 1 or not bool(route.get("hide_until_travel_count_met", false)):
		failures.append("Grand Casino route should stay hidden until at least one travel has occurred.")
	var underground := _archetype_by_id(library, "small_underground_casino")
	if underground.is_empty() or not _string_array(underground.get("next_archetypes", [])).has("grand_casino"):
		failures.append("Underground casino must route to the Grand Casino boss floor.")
	for boss_event_id in ["pit_boss_sweep", "comped_suite_offer", "eye_in_the_sky", "high_roller_cashout", "the_house_calls"]:
		var event := library.event(boss_event_id)
		if event.is_empty() or not _string_array(event.get("scopes", [])).has("boss"):
			failures.append("Boss-only event is missing or not scoped to boss: %s." % boss_event_id)
	var finale_event := library.event(finale_event_id)
	if finale_event.is_empty() or str(finale_event.get("type", "")) != "landmark":
		failures.append("The House Calls must be authored as a landmark boss event.")
		return
	var high_roller_event := library.event("high_roller_cashout")
	if high_roller_event.is_empty() or str(high_roller_event.get("type", "")) != "landmark":
		failures.append("High-roller cashout must be authored as a landmark boss event.")
		return

	var run_state: RunState = RunStateScript.new()
	run_state.start_new("M2-FUN-BOSS")
	var rng := run_state.create_rng("boss-objective")
	var environment := EnvironmentInstance.from_archetype(boss_archetype, 3, rng, library)
	run_state.set_environment(environment.to_dict())
	var high_roller_target := int(objective.get("high_roller_target_bankroll", 0))
	var high_roller_net := int(objective.get("high_roller_net_winnings", 0))
	var high_roller_min_games := int(objective.get("high_roller_min_grand_casino_games", 0))
	var high_roller_max_heat := int(objective.get("high_roller_max_heat", -1))
	var showdown_heat_threshold := int(objective.get("showdown_heat_threshold", 0))
	var forced_showdown_heat_threshold := int(objective.get("forced_showdown_heat_threshold", 0))
	if high_roller_target != 0:
		failures.append("Grand Casino Players Card objective should be gated by net Grand Casino winnings, not total bankroll.")
	if high_roller_net != 200:
		failures.append("Grand Casino Players Card objective should require exactly $200 in Grand Casino net winnings.")
	if high_roller_net <= 0 or high_roller_min_games <= 0 or high_roller_max_heat < 0:
		failures.append("Grand Casino clean lane must define net winnings, game count, and max heat.")
	if showdown_heat_threshold <= high_roller_max_heat or forced_showdown_heat_threshold <= showdown_heat_threshold:
		failures.append("Grand Casino heat lane thresholds should escalate above clean-route heat.")
	if str(objective.get("showdown_event_id", "")) != "the_house_calls":
		failures.append("Grand Casino heat lane must name The House Calls as showdown_event_id.")
	if str(objective.get("high_roller_event_id", "")) != "high_roller_cashout":
		failures.append("Grand Casino clean lane must name high_roller_cashout as high_roller_event_id.")

	var travel_sync_run: RunState = RunStateScript.new()
	travel_sync_run.start_new("M2-FUN-BOSS-TRAVEL-SYNC")
	travel_sync_run.bankroll = 350
	travel_sync_run.set_environment(environment.to_dict())
	var route_cost := maxi(0, int(route.get("cost", 100)))
	var expected_entry_after_cost := travel_sync_run.bankroll - route_cost
	var travel_sync_deltas := GameModule.empty_result_deltas()
	travel_sync_deltas["bankroll_delta"] = -route_cost
	var travel_sync_result := GameModule.build_action_result({
		"ok": true,
		"type": "travel",
		"source_id": "travel",
		"action_id": "confirm_travel",
		"action_kind": "travel",
		"deltas": travel_sync_deltas,
		"environment_id": str(travel_sync_run.current_environment.get("id", "")),
		"environment_archetype_id": "grand_casino",
		"message": "Travel sync fixture.",
	})
	GameModule.apply_result(travel_sync_run, travel_sync_result)
	if int(travel_sync_run.narrative_flags.get("grand_casino_entry_bankroll", -1)) != expected_entry_after_cost:
		failures.append("Grand Casino entry bankroll should be recorded after the travel buy-in is paid.")
	if int(travel_sync_run.demo_objective_status().get("grand_casino_net_winnings", -1)) != 0:
		failures.append("Grand Casino net winnings should start at $0 after the travel buy-in is paid.")

	var entry_bankroll := int(run_state.narrative_flags.get("grand_casino_entry_bankroll", run_state.bankroll))
	run_state.bankroll = entry_bankroll + high_roller_net - 1
	var status_before := run_state.demo_objective_status()
	if not bool(status_before.get("active", false)) or not bool(status_before.get("grand_casino_objective", false)):
		failures.append("Boss objective should report the Grand Casino dual-lane model.")
	if bool(status_before.get("complete", true)) or bool(status_before.get("high_roller_ready", false)) or bool(status_before.get("showdown_pending", false)):
		failures.append("Boss objective should be incomplete below clean and heat route targets.")
	var lanes: Dictionary = status_before.get("lanes", {})
	if not lanes.has("clean") or not lanes.has("heat"):
		failures.append("Grand Casino objective status did not expose both clean and heat lanes.")

	var non_boss_run: RunState = RunStateScript.new()
	non_boss_run.start_new("M2-FUN-BOSS-NON-BOSS")
	var non_boss_environment := environment.to_dict()
	non_boss_environment["id"] = "casino_non_boss_objective_fixture"
	non_boss_environment["archetype_id"] = "gas_station_casino"
	non_boss_environment["kind"] = "casino"
	non_boss_environment["event_ids"] = []
	non_boss_run.set_environment(non_boss_environment)
	non_boss_run.bankroll = RunState.DEFAULT_BANKROLL + high_roller_net
	var non_boss_status := non_boss_run.demo_objective_status()
	if bool(non_boss_status.get("active", false)):
		failures.append("Grand Casino boss objective should not appear outside the boss floor.")
	non_boss_run.evaluate_environment_objective_state()
	if bool(non_boss_run.narrative_flags.get("demo_finale_pending", false)) or _string_array(non_boss_run.current_environment.get("event_ids", [])).has(finale_event_id):
		failures.append("The House Calls triggered outside the boss floor.")
	if non_boss_run.run_status != RunState.RUN_STATUS_ACTIVE:
		failures.append("Non-boss objective fixture should not end or fail the run.")

	var clean_run: RunState = RunStateScript.new()
	clean_run.start_new("M2-FUN-BOSS-CLEAN")
	clean_run.set_environment(environment.to_dict())
	for game_index in range(high_roller_min_games):
		var progress_deltas := GameModule.empty_result_deltas()
		progress_deltas["story_log"] = [{"type": "game_action", "game_id": "blackjack", "stake_cost": 10 + game_index}]
		var progress_result := GameModule.build_action_result({
			"ok": true,
			"type": "game_action",
			"source_id": "blackjack",
			"game_id": "blackjack",
			"action_id": "clean_progress",
			"action_kind": "legal",
			"stake": 10 + game_index,
			"deltas": progress_deltas,
			"environment_id": str(clean_run.current_environment.get("id", "")),
			"message": "Clean boss-floor progress.",
		})
		clean_run.record_grand_casino_game_result(progress_result)
	clean_run.bankroll = int(clean_run.narrative_flags.get("grand_casino_entry_bankroll", 0)) + high_roller_net
	clean_run.evaluate_environment_objective_state()
	var clean_status := clean_run.demo_objective_status()
	if not bool(clean_status.get("high_roller_ready", false)) or not bool(clean_status.get("players_card_ready", false)) or not bool(clean_run.narrative_flags.get("high_roller_cashout_pending", false)):
		failures.append("Grand Casino clean lane did not report Players Card readiness.")
	if bool(clean_run.narrative_flags.get("demo_victory", false)) or clean_run.run_status != RunState.RUN_STATUS_ACTIVE:
		failures.append("Grand Casino clean lane should not set victory during A1 state reporting.")

	var save_service: SaveService = SaveServiceScript.new()
	var clean_slot_id := "foundation_check_grand_casino_clean_ready"
	var save_error: Error = save_service.save_run(clean_run, clean_slot_id)
	if save_error != OK:
		failures.append("Save service could not save Grand Casino clean objective state: %s." % save_error)
		return
	var loaded_clean = save_service.load_run(clean_slot_id)
	if loaded_clean == null:
		failures.append("Save service could not reload Grand Casino clean objective state.")
		return
	var loaded_clean_status: Dictionary = loaded_clean.demo_objective_status()
	if not bool(loaded_clean_status.get("high_roller_ready", false)) or int(loaded_clean_status.get("grand_casino_games_played", 0)) != high_roller_min_games:
		failures.append("Grand Casino clean objective metadata did not survive SaveService load.")
	if not _string_array(loaded_clean.current_environment.get("event_ids", [])).has("high_roller_cashout"):
		failures.append("Players Card event was not injected into the Grand Casino event list.")
	var high_roller_module := EventModule.new()
	high_roller_module.setup(high_roller_event)
	if not high_roller_module.can_trigger(loaded_clean, loaded_clean.current_environment):
		failures.append("Players Card event should trigger when clean readiness is pending.")
	var high_roller_choices: Array = high_roller_module.choices(loaded_clean, loaded_clean.current_environment)
	if high_roller_choices.size() != 1 or str((high_roller_choices[0] as Dictionary).get("id", "")) != "high_roller_cashout":
		failures.append("Players Card event should expose one deliberate claim response.")
	var cashout_result := high_roller_module.resolve(loaded_clean, loaded_clean.current_environment, "high_roller_cashout")
	if not bool(cashout_result.get("ok", false)) or loaded_clean.run_status != RunState.RUN_STATUS_ENDED:
		failures.append("Players Card claim did not end the run in demo victory.")
	if not bool(loaded_clean.narrative_flags.get("demo_victory", false)) or str(loaded_clean.narrative_flags.get("demo_victory_route", "")) != "high_roller_cashout":
		failures.append("Players Card claim did not set the canonical clean victory route.")
	if bool(loaded_clean.narrative_flags.get("high_roller_cashout_pending", true)) or bool(loaded_clean.narrative_flags.get("grand_casino_high_roller_ready", true)):
		failures.append("Players Card claim did not clear pending clean-route flags.")
	if str(loaded_clean.current_demo_victory_message()).find("Players Card") == -1:
		failures.append("Players Card victory message did not mention the card.")
	var high_roller_victory_round_trip_status := "unsaved"
	var high_roller_win_slot_id := "foundation_check_high_roller_cashout_win"
	save_error = save_service.save_run(loaded_clean, high_roller_win_slot_id)
	if save_error != OK:
		failures.append("Save service could not save Players Card win state: %s." % save_error)
		return
	var loaded_high_roller_win = save_service.load_run(high_roller_win_slot_id)
	if loaded_high_roller_win == null:
		failures.append("Save service could not reload Players Card win state.")
		return
	high_roller_victory_round_trip_status = str(loaded_high_roller_win.run_status)
	if loaded_high_roller_win.run_status != RunState.RUN_STATUS_ENDED or not bool(loaded_high_roller_win.narrative_flags.get("demo_victory", false)):
		failures.append("Players Card win status did not survive SaveService load.")
	if str(loaded_high_roller_win.narrative_flags.get("demo_victory_route", "")) != "high_roller_cashout":
		failures.append("Players Card win route did not survive SaveService load.")
	if bool(loaded_high_roller_win.narrative_flags.get("high_roller_cashout_pending", true)) or bool(loaded_high_roller_win.narrative_flags.get("grand_casino_high_roller_ready", true)):
		failures.append("Players Card win reloaded with pending clean-route flags.")
	if str(loaded_high_roller_win.current_demo_victory_message()).find("Players Card") == -1:
		failures.append("Players Card win message did not survive SaveService load.")

	var cheated_cashout_run: RunState = RunStateScript.new()
	cheated_cashout_run.start_new("M2-FUN-BOSS-CHEATED-CASHOUT")
	cheated_cashout_run.set_environment(environment.to_dict())
	var cheat_result := GameModule.build_action_result({
		"ok": true,
		"type": "game_action",
		"source_id": "blackjack",
		"game_id": "blackjack",
		"action_id": "peek_fixture",
		"action_kind": "cheat",
		"stake": 0,
		"deltas": GameModule.empty_result_deltas(),
		"environment_id": str(cheated_cashout_run.current_environment.get("id", "")),
		"message": "Cheat evidence fixture.",
	})
	cheated_cashout_run.record_grand_casino_game_result(cheat_result)
	for game_index in range(high_roller_min_games):
		var cheated_progress_deltas := GameModule.empty_result_deltas()
		cheated_progress_deltas["story_log"] = [{"type": "game_action", "game_id": "blackjack", "stake_cost": 12 + game_index}]
		var cheated_progress_result := GameModule.build_action_result({
			"ok": true,
			"type": "game_action",
			"source_id": "blackjack",
			"game_id": "blackjack",
			"action_id": "cheated_progress",
			"action_kind": "legal",
			"stake": 12 + game_index,
			"deltas": cheated_progress_deltas,
			"environment_id": str(cheated_cashout_run.current_environment.get("id", "")),
			"message": "Cheated cashout progress.",
		})
		cheated_cashout_run.record_grand_casino_game_result(cheated_progress_result)
	cheated_cashout_run.bankroll = int(cheated_cashout_run.narrative_flags.get("grand_casino_entry_bankroll", 0)) + high_roller_net
	cheated_cashout_run.evaluate_environment_objective_state()
	var cheated_cashout_status := cheated_cashout_run.demo_objective_status()
	if bool(cheated_cashout_status.get("high_roller_ready", false)) or bool(cheated_cashout_run.narrative_flags.get("high_roller_cashout_pending", false)):
		failures.append("Cheated Grand Casino player should not receive the Players Card.")
	if not bool(cheated_cashout_status.get("showdown_pending", false)) or str(cheated_cashout_run.narrative_flags.get("grand_casino_showdown_trigger_reason", "")) != "dirty_money":
		failures.append("Cheated Grand Casino money target should route to the Pit Boss Showdown.")
	if int(cheated_cashout_status.get("grand_casino_open_cheat_actions", 0)) <= 0:
		failures.append("Grand Casino open cheat action count was not tracked.")

	var hot_cashout_run: RunState = RunStateScript.new()
	hot_cashout_run.start_new("M2-FUN-BOSS-HOT-CASHOUT")
	hot_cashout_run.set_environment(environment.to_dict())
	hot_cashout_run.add_suspicion("cashout_heat_fixture", high_roller_max_heat + 1, "behavior")
	for game_index in range(high_roller_min_games):
		var hot_progress_deltas := GameModule.empty_result_deltas()
		hot_progress_deltas["story_log"] = [{"type": "game_action", "game_id": "blackjack", "stake_cost": 14 + game_index}]
		var hot_progress_result := GameModule.build_action_result({
			"ok": true,
			"type": "game_action",
			"source_id": "blackjack",
			"game_id": "blackjack",
			"action_id": "hot_progress",
			"action_kind": "legal",
			"stake": 14 + game_index,
			"deltas": hot_progress_deltas,
			"environment_id": str(hot_cashout_run.current_environment.get("id", "")),
			"message": "Hot cashout progress.",
		})
		hot_cashout_run.record_grand_casino_game_result(hot_progress_result)
	hot_cashout_run.bankroll = int(hot_cashout_run.narrative_flags.get("grand_casino_entry_bankroll", 0)) + high_roller_net
	hot_cashout_run.evaluate_environment_objective_state()
	var hot_cashout_status := hot_cashout_run.demo_objective_status()
	if bool(hot_cashout_status.get("high_roller_ready", false)) or bool(hot_cashout_run.narrative_flags.get("high_roller_cashout_pending", false)):
		failures.append("High-heat Grand Casino player should not receive the Players Card.")
	if not bool(hot_cashout_status.get("showdown_pending", false)):
		failures.append("High-heat Grand Casino money target should route to the Pit Boss Showdown.")
	if int(hot_cashout_status.get("grand_casino_max_heat", 0)) <= high_roller_max_heat:
		failures.append("Grand Casino max visit heat was not tracked for cashout eligibility.")

	var non_boss_cashout_environment := non_boss_environment.duplicate(true)
	non_boss_cashout_environment["event_ids"] = ["high_roller_cashout"]
	var non_boss_cashout_run: RunState = RunStateScript.new()
	non_boss_cashout_run.start_new("M2-FUN-BOSS-NON-BOSS-CASHOUT")
	non_boss_cashout_run.set_environment(non_boss_cashout_environment)
	non_boss_cashout_run.narrative_flags["high_roller_cashout_pending"] = true
	if high_roller_module.can_trigger(non_boss_cashout_run, non_boss_cashout_run.current_environment):
		failures.append("Players Card event should appear only in the Grand Casino.")

	run_state.current_environment["turns"] = 0
	run_state.add_suspicion("boss_heat_fixture", showdown_heat_threshold, "behavior")
	run_state.evaluate_environment_objective_state()
	var showdown_status := run_state.demo_objective_status()
	if run_state.run_status != RunState.RUN_STATUS_ACTIVE:
		failures.append("Boss objective should trigger the finale before ending the run.")
	if bool(run_state.narrative_flags.get("demo_victory", false)):
		failures.append("Heat lane set demo victory before The House Calls branch resolved.")
	if not bool(showdown_status.get("showdown_pending", false)) or not bool(run_state.narrative_flags.get("demo_finale_pending", false)):
		failures.append("Grand Casino heat lane did not mark The House Calls as pending.")
	if not bool(showdown_status.get("staff_attention_active", false)):
		failures.append("Grand Casino heat lane did not expose staff attention while pending.")
	if not _string_array(run_state.current_environment.get("event_ids", [])).has(finale_event_id):
		failures.append("Boss objective did not inject The House Calls into the active event list.")
	var finale_module := EventModule.new()
	finale_module.setup(finale_event)
	if not finale_module.can_trigger(run_state, run_state.current_environment):
		failures.append("The House Calls did not become triggerable at the boss target.")
	var showdown_slot_id := "foundation_check_grand_casino_showdown_pending"
	save_error = save_service.save_run(run_state, showdown_slot_id)
	if save_error != OK:
		failures.append("Save service could not save Grand Casino showdown objective state: %s." % save_error)
		return
	var loaded_showdown = save_service.load_run(showdown_slot_id)
	if loaded_showdown == null:
		failures.append("Save service could not reload Grand Casino showdown objective state.")
		return
	var loaded_showdown_status: Dictionary = loaded_showdown.demo_objective_status()
	if loaded_showdown.run_status != RunState.RUN_STATUS_ACTIVE or not bool(loaded_showdown_status.get("showdown_pending", false)):
		failures.append("Grand Casino showdown objective state did not survive SaveService load.")
	if bool(loaded_showdown.narrative_flags.get("demo_victory", false)):
		failures.append("Grand Casino showdown pending state should not become victory after SaveService load.")

	var watched_heat_run: RunState = RunStateScript.new()
	watched_heat_run.start_new("M2-FUN-BOSS-WATCHED-HEAT")
	watched_heat_run.set_environment(environment.to_dict())
	watched_heat_run.current_environment["turns"] = 0
	var watched_pressure := watched_heat_run.security_action_pressure("cheat", 10, 100)
	if bool(watched_pressure.get("ended", true)):
		failures.append("Grand Casino security pressure should not return generic capture while Rourke can reroute.")
	var watched_heat_deltas := GameModule.empty_result_deltas()
	watched_heat_deltas["suspicion_delta"] = 100
	watched_heat_deltas["story_log"] = [{"type": "game_action", "game_id": "blackjack", "stake_cost": 10, "pit_boss_heat_bonus": 30}]
	watched_heat_deltas["messages"] = ["Watched heat fixture."]
	var watched_heat_result := GameModule.build_action_result({
		"ok": true,
		"type": "game_action",
		"source_id": "blackjack",
		"game_id": "blackjack",
		"action_id": "watched_heat_fixture",
		"action_kind": "cheat",
		"stake": 10,
		"suspicion_delta": 100,
		"deltas": watched_heat_deltas,
		"environment_id": str(watched_heat_run.current_environment.get("id", "")),
		"message": "Watched heat fixture.",
	})
	GameModule.apply_result(watched_heat_run, watched_heat_result)
	var watched_heat_status := watched_heat_run.demo_objective_status()
	if watched_heat_run.run_status != RunState.RUN_STATUS_ACTIVE or not bool(watched_heat_status.get("showdown_pending", false)):
		failures.append("Watched Grand Casino heat should queue showdown without police capture.")
	if watched_heat_run.run_failure_reason == RunState.FAILURE_POLICE_CAPTURE:
		failures.append("Watched Grand Casino heat incorrectly recorded police capture.")
	var event_count_after_first := _count_string_occurrences(watched_heat_run.current_environment.get("event_ids", []), finale_event_id)
	watched_heat_run.add_suspicion("repeat_heat_fixture", 5, "behavior")
	var event_count_after_repeat := _count_string_occurrences(watched_heat_run.current_environment.get("event_ids", []), finale_event_id)
	if event_count_after_repeat != event_count_after_first:
		failures.append("Repeated Grand Casino heat duplicated the showdown event.")

	var forced_heat_run: RunState = RunStateScript.new()
	forced_heat_run.start_new("M2-FUN-BOSS-FORCED-HEAT")
	forced_heat_run.set_environment(environment.to_dict())
	var forced_initial_watch := forced_heat_run.pit_boss_watch_status(forced_heat_run.current_environment)
	forced_heat_run.current_environment["turns"] = int(forced_initial_watch.get("watched_turns", 2))
	forced_heat_run.current_environment["event_ids"] = []
	forced_heat_run.add_suspicion("forced_heat_fixture", forced_showdown_heat_threshold, "behavior")
	var forced_heat_status := forced_heat_run.demo_objective_status()
	if forced_heat_run.run_status != RunState.RUN_STATUS_ACTIVE or not bool(forced_heat_status.get("showdown_pending", false)):
		failures.append("Unwatched forced Grand Casino heat should establish attention and queue showdown.")
	if not bool(forced_heat_run.narrative_flags.get("grand_casino_attention_forced_heat", false)):
		failures.append("Forced Grand Casino heat did not record the forced attention flag.")
	var forced_story_found := false
	for entry_value in forced_heat_run.story_log:
		if typeof(entry_value) == TYPE_DICTIONARY and str((entry_value as Dictionary).get("type", "")) == "grand_casino_heat_reroute":
			forced_story_found = true
			break
	if not forced_story_found:
		failures.append("Forced Grand Casino heat did not log a clear reroute story entry.")

	var outside_heat_run: RunState = RunStateScript.new()
	outside_heat_run.start_new("M2-FUN-BOSS-OUTSIDE-HEAT")
	outside_heat_run.set_environment(non_boss_environment)
	outside_heat_run.add_suspicion("outside_heat_fixture", 100, "behavior")
	if outside_heat_run.run_status != RunState.RUN_STATUS_FAILED or outside_heat_run.run_failure_reason != RunState.FAILURE_POLICE_CAPTURE:
		failures.append("Outside Grand Casino heat 100 should still fail as police_capture.")

	var watched_run: RunState = RunStateScript.new()
	watched_run.start_new("M2-FUN-BOSS-WATCH")
	watched_run.set_environment(environment.to_dict())
	watched_run.current_environment["turns"] = 0
	var watched_status := watched_run.pit_boss_watch_status(watched_run.current_environment)
	if not bool(watched_status.get("active", false)) or not bool(watched_status.get("watched", false)):
		failures.append("Pit boss watch state should be active and watched at turn zero.")
	watched_run.current_environment["turns"] = int(watched_status.get("watched_turns", 2))
	var clear_status := watched_run.pit_boss_watch_status(watched_run.current_environment)
	if bool(clear_status.get("watched", true)):
		failures.append("Pit boss watch state should have an unwatched cycle window.")
	var game: GameModule = _load_surface_contract_game(library, "blackjack", failures)
	if game != null:
		watched_run.current_environment["turns"] = 0
		var watched_actions: Array = game.cheat_actions(watched_run, watched_run.current_environment)
		watched_run.current_environment["turns"] = int(watched_status.get("watched_turns", 2))
		var clear_actions: Array = game.cheat_actions(watched_run, watched_run.current_environment)
		if watched_actions.is_empty() or clear_actions.is_empty():
			failures.append("Boss watch fixture needs cheat actions to compare heat.")
		elif int((watched_actions[0] as Dictionary).get("suspicion_delta", 0)) <= int((clear_actions[0] as Dictionary).get("suspicion_delta", 0)):
			failures.append("Cheating while watched did not add extra pit-boss heat.")

	var finale_payload: Dictionary = {}
	var finale_payload_value: Variant = finale_event.get("payload", {})
	if typeof(finale_payload_value) == TYPE_DICTIONARY:
		finale_payload = (finale_payload_value as Dictionary).duplicate(true)
	var showdown_config: Dictionary = {}
	var showdown_tuning_value: Variant = finale_payload.get("showdown_tuning", {})
	if typeof(showdown_tuning_value) == TYPE_DICTIONARY:
		showdown_config = (showdown_tuning_value as Dictionary).duplicate(true)
	showdown_config["success_message"] = str(finale_payload.get("success_message", ""))
	showdown_config["failure_message"] = str(finale_payload.get("failure_message", ""))

	var active_run: RunState = RunStateScript.new()
	active_run.start_new("M2-FUN-HOUSE-CALLS-ACTIVE")
	active_run.set_environment(environment.to_dict())
	active_run.current_environment["turns"] = 0
	active_run.add_suspicion("boss_heat_fixture", showdown_heat_threshold, "behavior")
	active_run.evaluate_environment_objective_state()
	if not finale_module.can_trigger(active_run, active_run.current_environment):
		failures.append("The House Calls should trigger from the pending showdown flag.")
	var pending_choices: Array = finale_module.choices(active_run, active_run.current_environment)
	if pending_choices.size() != 1 or str((pending_choices[0] as Dictionary).get("id", "")) != "enter_back_room":
		failures.append("Pending showdown should expose only the back-room arrival beat.")
	var arrival_result := finale_module.resolve(active_run, active_run.current_environment, "enter_back_room")
	if not bool(arrival_result.get("ok", false)) or not bool(active_run.narrative_flags.get("grand_casino_showdown_active", false)):
		failures.append("Back-room arrival did not start the active Pit Boss Showdown.")
	if str(active_run.narrative_flags.get("grand_casino_showdown_step", "")) != "pressure_choice":
		failures.append("Back-room arrival did not preserve the pressure-choice showdown step.")
	var pressure_choices: Array = finale_module.choices(active_run, active_run.current_environment)
	var pressure_choice_ids: Array = []
	for pressure_choice_value in pressure_choices:
		if typeof(pressure_choice_value) == TYPE_DICTIONARY:
			pressure_choice_ids.append(str((pressure_choice_value as Dictionary).get("id", "")))
	if not pressure_choice_ids.has("hold_steady") or not pressure_choice_ids.has("talk_down") or not pressure_choice_ids.has("take_the_edge"):
		failures.append("Active showdown did not expose all pressure choices.")
	var active_slot_id := "foundation_check_house_calls_active"
	save_error = save_service.save_run(active_run, active_slot_id)
	if save_error != OK:
		failures.append("Save service could not save active showdown state: %s." % save_error)
		return
	var loaded_active = save_service.load_run(active_slot_id)
	if loaded_active == null:
		failures.append("Save service could not reload active showdown state.")
		return
	if not bool(loaded_active.narrative_flags.get("grand_casino_showdown_active", false)) or str(loaded_active.narrative_flags.get("grand_casino_showdown_step", "")) != "pressure_choice":
		failures.append("Active showdown step did not survive SaveService load.")
	var loaded_pressure_choices: Array = finale_module.choices(loaded_active, loaded_active.current_environment)
	if loaded_pressure_choices.size() != 3:
		failures.append("Loaded active showdown did not preserve pressure choices.")

	var clean_preview := active_run.grand_casino_showdown_status(showdown_config, "hold_steady")
	var clean_check: Dictionary = {}
	var clean_check_value: Variant = clean_preview.get("check", {})
	if typeof(clean_check_value) == TYPE_DICTIONARY:
		clean_check = clean_check_value as Dictionary
	var item_run: RunState = RunStateScript.new()
	item_run.start_new("M2-FUN-HOUSE-CALLS-ITEM")
	item_run.set_environment(environment.to_dict())
	item_run.current_environment["turns"] = 0
	item_run.add_item("cheap_sunglasses")
	item_run.add_item("card_counters_notes")
	item_run.add_suspicion("boss_heat_fixture", showdown_heat_threshold, "behavior")
	item_run.evaluate_environment_objective_state()
	finale_module.resolve(item_run, item_run.current_environment, "enter_back_room")
	var item_preview := item_run.grand_casino_showdown_status(showdown_config, "hold_steady")
	var item_check: Dictionary = {}
	var item_check_value: Variant = item_preview.get("check", {})
	if typeof(item_check_value) == TYPE_DICTIONARY:
		item_check = item_check_value as Dictionary
	if int(item_check.get("success_chance", 0)) <= int(clean_check.get("success_chance", 0)):
		failures.append("Item-assisted showdown preview did not improve the check chance.")
	var dirty_preview_run: RunState = RunStateScript.new()
	dirty_preview_run.start_new("M2-FUN-HOUSE-CALLS-DIRTY-PREVIEW")
	dirty_preview_run.set_environment(environment.to_dict())
	dirty_preview_run.current_environment["turns"] = 0
	dirty_preview_run.narrative_flags["grand_casino_cheat_evidence"] = true
	dirty_preview_run.add_suspicion("boss_heat_fixture", showdown_heat_threshold, "behavior")
	dirty_preview_run.evaluate_environment_objective_state()
	finale_module.resolve(dirty_preview_run, dirty_preview_run.current_environment, "enter_back_room")
	var dirty_preview := dirty_preview_run.grand_casino_showdown_status(showdown_config, "hold_steady")
	var dirty_check: Dictionary = {}
	var dirty_check_value: Variant = dirty_preview.get("check", {})
	if typeof(dirty_check_value) == TYPE_DICTIONARY:
		dirty_check = dirty_check_value as Dictionary
	if int(clean_check.get("success_chance", 0)) <= int(dirty_check.get("success_chance", 0)):
		failures.append("Clean-play showdown preview did not beat the dirty-evidence check chance.")

	var win_run: RunState = null
	var win_result: Dictionary = {}
	for index in range(80):
		var candidate: RunState = RunStateScript.new()
		candidate.start_new("M2-FUN-HOUSE-CALLS-WIN-%d" % index)
		candidate.set_environment(environment.to_dict())
		candidate.current_environment["turns"] = 0
		candidate.add_item("cheap_sunglasses")
		candidate.add_item("card_counters_notes")
		candidate.narrative_flags["grand_casino_event_pit_boss_sweep_lay_low"] = true
		candidate.narrative_flags["grand_casino_event_eye_in_the_sky_change_table"] = true
		candidate.add_suspicion("boss_heat_fixture", showdown_heat_threshold, "behavior")
		candidate.evaluate_environment_objective_state()
		finale_module.resolve(candidate, candidate.current_environment, "enter_back_room")
		var preview := candidate.grand_casino_showdown_status(showdown_config, "hold_steady")
		var preview_check: Dictionary = {}
		var preview_check_value: Variant = preview.get("check", {})
		if typeof(preview_check_value) == TYPE_DICTIONARY:
			preview_check = preview_check_value as Dictionary
		if bool(preview_check.get("success", false)):
			win_run = candidate
			win_result = finale_module.resolve(win_run, win_run.current_environment, "hold_steady")
			break
	if win_run == null:
		failures.append("Could not find a deterministic successful Pit Boss Showdown fixture.")
	else:
		if not bool(win_result.get("ok", false)) or win_run.run_status != RunState.RUN_STATUS_ENDED:
			failures.append("Pit Boss Showdown success did not end in demo victory.")
		if not bool(win_run.narrative_flags.get("demo_victory", false)) or str(win_run.narrative_flags.get("demo_victory_route", "")) != "pit_boss_showdown":
			failures.append("Pit Boss Showdown success did not set the canonical victory route.")
		if bool(win_run.narrative_flags.get("grand_casino_showdown_pending", true)) or bool(win_run.narrative_flags.get("grand_casino_showdown_active", true)):
			failures.append("Pit Boss Showdown success did not clear pending/active flags.")
		if str(win_run.current_demo_victory_message()).find("winnings") == -1:
			failures.append("Pit Boss Showdown victory message did not mention walking with winnings.")
		var win_status := win_run.demo_objective_status()
		if str(win_status.get("objective_state", "")) != "victory":
			failures.append("Grand Casino objective status did not report victory after showdown success.")
		var win_slot_id := "foundation_check_house_calls_win"
		save_error = save_service.save_run(win_run, win_slot_id)
		if save_error != OK:
			failures.append("Save service could not save House Calls win state: %s." % save_error)
			return
		var loaded_win = save_service.load_run(win_slot_id)
		if loaded_win == null:
			failures.append("Save service could not reload House Calls win state.")
			return
		if loaded_win.run_status != RunState.RUN_STATUS_ENDED or not bool(loaded_win.narrative_flags.get("demo_victory", false)):
			failures.append("House Calls win status did not survive SaveService load.")

	var failure_run: RunState = null
	var failure_result: Dictionary = {}
	for index in range(80):
		var candidate: RunState = RunStateScript.new()
		candidate.start_new("M2-FUN-HOUSE-CALLS-FAIL-%d" % index)
		candidate.set_environment(environment.to_dict())
		candidate.current_environment["turns"] = 0
		candidate.add_item("marked_cards")
		candidate.add_item("foil_sleeve")
		candidate.add_item("weighted_keyring")
		candidate.add_item("xray_glasses")
		candidate.add_item("tab_detector")
		candidate.drunk_level = 75
		candidate.alcoholic_level = 100
		candidate.add_debt({"id": "showdown_debt_one", "lender_id": "street_lender", "balance": 40, "status": "active"})
		candidate.add_debt({"id": "showdown_debt_two", "lender_id": "motel_friend", "balance": 30, "status": "overdue"})
		candidate.narrative_flags["grand_casino_event_pit_boss_sweep_act_natural"] = true
		candidate.narrative_flags["grand_casino_event_eye_in_the_sky_press_anyway"] = true
		candidate.narrative_flags["grand_casino_event_comped_suite_offer_take_comp"] = true
		candidate.add_suspicion("boss_heat_fixture", 100, "behavior")
		candidate.evaluate_environment_objective_state()
		finale_module.resolve(candidate, candidate.current_environment, "enter_back_room")
		var preview := candidate.grand_casino_showdown_status(showdown_config, "take_the_edge")
		var preview_check: Dictionary = {}
		var preview_check_value: Variant = preview.get("check", {})
		if typeof(preview_check_value) == TYPE_DICTIONARY:
			preview_check = preview_check_value as Dictionary
		if not bool(preview_check.get("success", true)):
			failure_run = candidate
			failure_result = finale_module.resolve(failure_run, failure_run.current_environment, "take_the_edge")
			break
	if failure_run == null:
		failures.append("Could not find a deterministic failed Pit Boss Showdown fixture.")
	else:
		if not bool(failure_result.get("ok", false)) or failure_run.run_status != RunState.RUN_STATUS_FAILED:
			failures.append("Pit Boss Showdown failure did not fail the run.")
		if failure_run.run_failure_reason != RunState.FAILURE_CASINO_TAKEN_OUT_BACK:
			failures.append("Pit Boss Showdown failure did not record casino_taken_out_back.")
		if str(failure_run.run_failure_message).find("police") != -1 or str(failure_run.run_failure_message).find("cuffs") != -1:
			failures.append("Pit Boss Showdown failure used generic police-capture copy.")
		if bool(failure_run.narrative_flags.get("grand_casino_showdown_pending", true)) or bool(failure_run.narrative_flags.get("grand_casino_showdown_active", true)):
			failures.append("Pit Boss Showdown failure did not clear pending/active flags.")
		var failure_status := failure_run.demo_objective_status()
		if str(failure_status.get("objective_state", "")) != "failure":
			failures.append("Grand Casino objective status did not report failure after showdown loss.")
		var failure_slot_id := "foundation_check_house_calls_failure"
		save_error = save_service.save_run(failure_run, failure_slot_id)
		if save_error != OK:
			failures.append("Save service could not save House Calls failure state: %s." % save_error)
			return
		var loaded_failure = save_service.load_run(failure_slot_id)
		if loaded_failure == null:
			failures.append("Save service could not reload House Calls failure state.")
			return
		if loaded_failure.run_status != RunState.RUN_STATUS_FAILED or loaded_failure.run_failure_reason != RunState.FAILURE_CASINO_TAKEN_OUT_BACK:
			failures.append("House Calls failure status did not survive SaveService load.")
	print("GRAND_CASINO_OBJECTIVE_LANES clean_ready=%s showdown_pending=%s outside_active=%s games=%d" % [
		str(clean_status.get("high_roller_ready", false)),
		str(showdown_status.get("showdown_pending", false)),
		str(non_boss_status.get("active", false)),
		int(loaded_clean_status.get("grand_casino_games_played", 0)),
	])
	print("GRAND_CASINO_HEAT_REROUTE watched_pending=%s forced_pending=%s outside_reason=%s duplicate_events=%d" % [
		str(watched_heat_status.get("showdown_pending", false)),
		str(forced_heat_status.get("showdown_pending", false)),
		str(outside_heat_run.run_failure_reason),
		event_count_after_repeat,
	])
	var showdown_win_status := "missing"
	if win_run != null:
		showdown_win_status = str(win_run.run_status)
	var showdown_failure_reason := "missing"
	if failure_run != null:
		showdown_failure_reason = str(failure_run.run_failure_reason)
	print("HOUSE_CALLS_SHOWDOWN trigger=%s active_step=%s win=%s failure=%s item_chance=%d clean_chance=%d dirty_chance=%d" % [
		str(run_state.narrative_flags.get("demo_finale_event_id", "")),
		str(active_run.narrative_flags.get("grand_casino_showdown_step", "")),
		showdown_win_status,
		showdown_failure_reason,
		int(item_check.get("success_chance", 0)),
		int(clean_check.get("success_chance", 0)),
		int(dirty_check.get("success_chance", 0)),
	])
	print("HIGH_ROLLER_CASHOUT route=%s cheated_pending=%s hot_pending=%s max_heat=%d event_visible=%s" % [
		str(loaded_clean.narrative_flags.get("demo_victory_route", "")),
		str(cheated_cashout_status.get("showdown_pending", false)),
		str(hot_cashout_status.get("showdown_pending", false)),
		int(hot_cashout_status.get("grand_casino_max_heat", 0)),
		str(_string_array(clean_run.current_environment.get("event_ids", [])).has("high_roller_cashout")),
	])
	print("GRAND_CASINO_ENDGAME_MATRIX high_roller_loaded=%s showdown_loaded=%s taken_out_back_loaded=%s pending_loaded=%s clean_ready_loaded=%s" % [
		high_roller_victory_round_trip_status,
		showdown_win_status,
		showdown_failure_reason,
		str(loaded_showdown.run_status),
		str(loaded_clean_status.get("high_roller_ready", false)),
	])


# Checks bankrupt failure, supported lender recovery, save/load, and victory/failure separation.
func _check_recovery_loss_pressure_foundation(library: ContentLibrary, failures: Array) -> void:
	var failed_run: RunState = RunStateScript.new()
	failed_run.start_new("M2-FUN-LOSS")
	failed_run.change_bankroll(-failed_run.bankroll)
	if failed_run.bankroll != 0:
		failures.append("Loss pressure fixture did not reach zero bankroll.")
	if failed_run.run_status != RunState.RUN_STATUS_FAILED:
		failures.append("Zero bankroll without recovery did not mark the run failed.")
	if failed_run.run_failure_reason != RunState.FAILURE_BANKROLL_ZERO:
		failures.append("Zero bankroll failure did not record a bankroll-zero reason.")
	if failed_run.economy() != "insolvent":
		failures.append("Zero bankroll without recovery did not mark the economy insolvent.")
	var failed_pressure := failed_run.recovery_pressure_status(false)
	if not bool(failed_pressure.get("failed", false)):
		failures.append("Recovery pressure status did not expose a clear failed state.")
	if str(failed_pressure.get("summary", "")).find("out of money") == -1:
		failures.append("Failed pressure summary is not player-facing enough.")
	var failed_save_service: SaveService = SaveServiceScript.new()
	var failed_slot := "foundation_check_loss_pressure"
	var failed_save_error: Error = failed_save_service.save_run(failed_run, failed_slot)
	if failed_save_error != OK:
		failures.append("Save service could not save failed run state: %s." % failed_save_error)
	else:
		var loaded_failed = failed_save_service.load_run(failed_slot)
		if loaded_failed == null:
			failures.append("Save service could not reload failed run state.")
		elif loaded_failed.run_status != RunState.RUN_STATUS_FAILED or loaded_failed.economy() != "insolvent":
			failures.append("Failed run status/economy did not survive SaveService load.")
		elif loaded_failed.run_failure_reason != failed_run.run_failure_reason:
			failures.append("Failed run reason did not survive SaveService load.")

	var lender := library.lender("street_lender")
	if lender.is_empty():
		failures.append("Recovery pressure needs supported lender fixture: street_lender.")
		return
	var recovery_run: RunState = RunStateScript.new()
	recovery_run.start_new("M2-FUN-RECOVERY")
	recovery_run.set_environment({
		"id": "back_alley_recovery_fixture",
		"archetype_id": "back_alley",
		"kind": "shop",
		"lender_hooks": ["street_lender"],
	})
	recovery_run.change_bankroll(-(recovery_run.bankroll - 1))
	var recovery_status := RunTerminalEvaluatorScript.evaluate(recovery_run, library)
	if bool(recovery_status.get("failed", false)) or not bool(recovery_status.get("lender_available", false)):
		failures.append("Low-bankroll lender recovery was not recognized before zero cash.")
	var lender_result := _fixture_lender_result(recovery_run, lender, "street_lender")
	GameModule.apply_result(recovery_run, lender_result)
	if recovery_run.bankroll <= 0:
		failures.append("Supported lender recovery did not restore positive bankroll.")
	if recovery_run.debt.is_empty():
		failures.append("Supported lender recovery did not create debt pressure.")
	if recovery_run.run_status == RunState.RUN_STATUS_FAILED:
		failures.append("Supported lender recovery left the run in failed status.")
	var post_recovery_pressure := recovery_run.recovery_pressure_status(false)
	if bool(post_recovery_pressure.get("failed", false)):
		failures.append("Post-lender recovery still reports a failed pressure state.")
	var recovery_save_service: SaveService = SaveServiceScript.new()
	var recovery_slot := "foundation_check_recovery_pressure"
	var recovery_save_error: Error = recovery_save_service.save_run(recovery_run, recovery_slot)
	if recovery_save_error != OK:
		failures.append("Save service could not save recovery run state: %s." % recovery_save_error)
	else:
		var loaded_recovery = recovery_save_service.load_run(recovery_slot)
		if loaded_recovery == null:
			failures.append("Save service could not reload recovery run state.")
		elif loaded_recovery.bankroll != recovery_run.bankroll or loaded_recovery.debt.size() != recovery_run.debt.size() or loaded_recovery.run_status != recovery_run.run_status:
			failures.append("Recovery run pressure did not survive SaveService load.")

	var victory_run: RunState = RunStateScript.new()
	victory_run.start_new("M2-FUN-VICTORY-NOT-FAILURE")
	victory_run.change_bankroll(-(victory_run.bankroll - 1))
	var victory_deltas := GameModule.empty_result_deltas()
	victory_deltas["flags_set"] = {"prestige_victory": true}
	victory_deltas["ended"] = true
	victory_deltas["messages"] = ["Prestige Victory: you beat the house for now."]
	GameModule.apply_result(victory_run, GameModule.build_action_result({
		"ok": true,
		"type": "prestige_purchase",
		"source_id": "fixture_prestige",
		"action_id": "buy_prestige",
		"deltas": victory_deltas,
		"message": "Prestige Victory: you beat the house for now.",
	}))
	var victory_pressure := victory_run.recovery_pressure_status(false)
	if victory_run.run_status != GameModule.RESULT_ENDED:
		failures.append("Victory result did not preserve ended run status after zero-bankroll pressure.")
	if bool(victory_pressure.get("failed", true)) or str(victory_pressure.get("state", "")) != "victory":
		failures.append("Victory state conflicted with failure pressure.")

	var stranded_run: RunState = RunStateScript.new()
	stranded_run.start_new("M2-FUN-STRANDED")
	stranded_run.set_environment({
		"id": "stranded_fixture",
		"archetype_id": "fixture_room",
		"kind": "casino",
		"economic_profile": {"stake_floor": 5, "stake_ceiling": 5},
		"game_ids": ["slot"],
		"event_ids": [],
		"item_offers": [],
		"travel_hooks": [],
		"next_archetypes": [],
		"lender_hooks": [],
	})
	stranded_run.change_bankroll(-(stranded_run.bankroll - 1))
	var stranded_status := RunTerminalEvaluatorScript.evaluate_and_apply(stranded_run, library)
	if not bool(stranded_status.get("failed", false)) or stranded_run.run_failure_reason != RunState.FAILURE_STRANDED:
		failures.append("No-wager/no-recovery state did not fail as stranded.")

	var travel_escape_run: RunState = RunStateScript.new()
	travel_escape_run.start_new("M2-FUN-TRAVEL-ESCAPE")
	travel_escape_run.set_environment({
		"id": "travel_escape_fixture",
		"archetype_id": "fixture_room",
		"kind": "casino",
		"economic_profile": {"stake_floor": 5, "stake_ceiling": 5},
		"game_ids": ["slot"],
		"event_ids": [],
		"item_offers": [],
		"travel_hooks": ["corner_store"],
		"next_archetypes": [],
		"lender_hooks": [],
	})
	travel_escape_run.change_bankroll(-(travel_escape_run.bankroll - 2))
	var travel_escape_status := RunTerminalEvaluatorScript.evaluate_and_apply(travel_escape_run, library)
	if bool(travel_escape_status.get("failed", false)) or not bool(travel_escape_status.get("travel_available", false)):
		failures.append("Affordable travel was not preserved as a low-bankroll recovery path.")


func _save_service_expected_snapshot(run_state: RunState) -> Dictionary:
	var parsed: Variant = JSON.parse_string(JSON.stringify(run_state.to_dict()))
	if typeof(parsed) != TYPE_DICTIONARY:
		return run_state.to_dict()
	var normalized: RunState = RunStateScript.new()
	normalized.from_dict(parsed as Dictionary)
	return normalized.to_dict()


func _fixture_system_pressure_result(environment: Dictionary, bankroll_delta: int, message: String) -> Dictionary:
	var deltas := GameModule.empty_result_deltas()
	deltas["bankroll_delta"] = bankroll_delta
	deltas["story_log"] = [{
		"type": "economy_pressure",
		"id": "m2_system_scenario",
		"bankroll_delta": bankroll_delta,
		"environment_id": str(environment.get("id", "")),
		"message": message,
	}]
	deltas["messages"] = [message]
	return GameModule.build_action_result({
		"ok": true,
		"type": "economy_pressure",
		"source_id": "m2_system_scenario",
		"action_id": "cash_pressure",
		"action_kind": "economy",
		"environment_id": str(environment.get("id", "")),
		"bankroll_delta": bankroll_delta,
		"deltas": deltas,
		"message": message,
	})


func _string_array_from_variant(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value as Array:
		var id := str(entry)
		if not id.is_empty():
			result.append(id)
	return result


func _unique_strings(first: Array, second: Array) -> Array:
	var result: Array = []
	for source in [first, second]:
		for id in _string_array_from_variant(source):
			if not result.has(id):
				result.append(id)
	return result


# Resolves one foundation game action before saving, if generated content allows it.
func _resolve_first_save_test_action(library: ContentLibrary, run_state: RunState, environment: EnvironmentInstance, failures: Array) -> void:
	if environment.game_ids.is_empty():
		failures.append("SaveService round trip needs a generated game option.")
		return
	var game_id := str(environment.game_ids[0])
	var definition := library.game(game_id)
	if definition.is_empty():
		failures.append("SaveService round trip generated unknown game: %s." % game_id)
		return
	var module_path := str(definition.get("module_path", ""))
	if module_path.ends_with("_ui.gd") or module_path.begins_with("res://data/runtime/"):
		failures.append("SaveService round trip game module points at demo runtime/UI path: %s." % module_path)
		return
	var module_script: Script = load(module_path)
	if module_script == null:
		failures.append("SaveService round trip could not load game module: %s." % module_path)
		return
	var module_instance = module_script.new()
	if not module_instance is GameModule:
		failures.append("SaveService round trip game module does not extend GameModule: %s." % module_path)
		return
	var game: GameModule = module_instance
	game.setup(definition, library)
	var legal_actions: Array = game.actions(run_state, environment.to_dict()).get("legal_actions", [])
	if legal_actions.is_empty():
		failures.append("SaveService round trip game did not expose a legal action.")
		return
	var result := game.resolve(str(legal_actions[0].get("id", "")), 1, run_state, environment.to_dict(), run_state.create_rng())
	_check_action_result_shape(result, "legal", failures)


# Checks the saved file is a foundation RunState payload, not profile/settings/demo data.
func _check_save_payload_file(save_path: String, failures: Array) -> void:
	var saved_text := FileAccess.get_file_as_string(save_path)
	var parsed: Variant = JSON.parse_string(saved_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		failures.append("SaveService wrote non-dictionary save data.")
		return
	var payload: Dictionary = parsed
	if payload.get("schema", "") != SaveService.SAVE_SCHEMA:
		failures.append("SaveService save payload is missing the foundation run schema.")
	if int(payload.get("version", 0)) != SaveService.SAVE_VERSION:
		failures.append("SaveService save payload version is not current.")
	if not payload.has("run_state"):
		failures.append("SaveService save payload is missing RunState data.")
	if payload.has("settings") or payload.has("profile") or payload.has("profile_inventory"):
		failures.append("SaveService mixed settings/profile persistence into run persistence.")
	var run_data: Variant = payload.get("run_state", {})
	if typeof(run_data) == TYPE_DICTIONARY:
		var run_dict: Dictionary = run_data
		if run_dict.has("profile_inventory"):
			failures.append("SaveService RunState payload included profile inventory.")


# Compares saved and loaded RunState domains.
func _check_run_state_save_round_trip(expected: Dictionary, actual: Dictionary, failures: Array) -> void:
	var keys := [
		"seed_text",
		"seed_value",
		"rng_seed",
		"rng_state",
		"challenge_config",
		"bankroll",
		"economic_state",
		"inventory",
		"debt",
		"suspicion",
		"current_environment",
		"environment_history",
		"unlocked_travel",
		"narrative_flags",
		"story_log",
		"run_status",
	]
	for key in keys:
		if JSON.stringify(expected.get(key)) != JSON.stringify(actual.get(key)):
			failures.append("SaveService did not preserve RunState key: %s." % key)


# Checks the README one-structure EnvironmentInstance shape.
func _check_environment_instance_shape(environment: EnvironmentInstance, require_game: bool, failures: Array) -> void:
	if environment == null:
		failures.append("RunGenerator returned a null EnvironmentInstance.")
		return
	var data := environment.to_dict()
	if data.is_empty():
		failures.append("EnvironmentInstance did not produce saveable dictionary output.")
	if environment.id.is_empty():
		failures.append("EnvironmentInstance is missing generated id.")
	if environment.archetype_id.is_empty():
		failures.append("EnvironmentInstance is missing venue archetype identity.")
	if environment.display_name.is_empty():
		failures.append("EnvironmentInstance is missing display identity.")
	if environment.tier < 1:
		failures.append("EnvironmentInstance tier must be positive.")
	if environment.art_key.is_empty():
		failures.append("EnvironmentInstance is missing art reference key.")
	var layout: Variant = data.get("layout", {})
	if typeof(layout) != TYPE_DICTIONARY:
		failures.append("EnvironmentInstance layout should serialize generated object placement data.")
	else:
		var object_rects: Variant = (layout as Dictionary).get("object_rects", {})
		if typeof(object_rects) != TYPE_DICTIONARY:
			failures.append("EnvironmentInstance layout should include stable object_rects.")
		else:
			for event_id in environment.event_ids:
				if not (object_rects as Dictionary).has("event:%s" % str(event_id)):
					failures.append("EnvironmentInstance layout is missing event object placement.")
					break
			for offer in environment.item_offers:
				if typeof(offer) == TYPE_DICTIONARY and not (object_rects as Dictionary).has("item:%s" % str((offer as Dictionary).get("id", ""))):
					failures.append("EnvironmentInstance layout is missing item offer placement.")
					break
			for target_id in _unique_strings(environment.next_archetypes, environment.travel_hooks):
				if not (object_rects as Dictionary).has("travel:%s" % target_id):
					failures.append("EnvironmentInstance layout is missing travel object placement.")
					break
	if data.get("visual_context", {}).has("asset_path"):
		failures.append("EnvironmentInstance visual context should not serialize concrete PNG asset paths.")
	if data.get("visual_context", {}).has("scene_asset_path"):
		failures.append("EnvironmentInstance visual context should not serialize concrete scene asset paths.")
	if environment.security_profile.is_empty():
		failures.append("EnvironmentInstance is missing security profile.")
	if environment.economic_profile.is_empty():
		failures.append("EnvironmentInstance is missing economy pressure data.")
	if require_game and environment.game_ids.is_empty():
		failures.append("First foundation EnvironmentInstance should expose at least one game option.")
	if environment.event_ids.is_empty():
		failures.append("EnvironmentInstance should expose event hooks.")
	if environment.travel_hooks.is_empty() and environment.next_archetypes.is_empty():
		failures.append("EnvironmentInstance should expose travel hooks or next archetypes.")
	if typeof(data.get("item_offers", [])) != TYPE_ARRAY:
		failures.append("EnvironmentInstance item opportunities should serialize as an array.")
	if typeof(data.get("service_ids", [])) != TYPE_ARRAY:
		failures.append("EnvironmentInstance services should serialize as an array.")
	if typeof(data.get("lender_hooks", [])) != TYPE_ARRAY:
		failures.append("EnvironmentInstance lender hooks should serialize as an array.")
	if typeof(data.get("suspicion_cues", [])) != TYPE_ARRAY:
		failures.append("EnvironmentInstance suspicion cues should serialize as an array.")
	if typeof(data.get("local_narrative_flags", {})) != TYPE_DICTIONARY:
		failures.append("EnvironmentInstance local flags should serialize as a dictionary.")
	var restored := EnvironmentInstance.from_dict(data)
	if JSON.stringify(restored.to_dict()) != JSON.stringify(data):
		failures.append("EnvironmentInstance did not preserve saveable data through from_dict.")


# Checks that tests are exercising README pack paths through ContentLibrary.
func _check_canonical_pack_paths(failures: Array) -> void:
	var required_paths := ContentLibraryScript.required_pack_paths()
	for pack_name in required_paths.keys():
		var path := str(required_paths[pack_name])
		_check_foundation_pack_path(path, failures)
		if not FileAccess.file_exists(path):
			failures.append("Missing required foundation pack %s at %s." % [pack_name, path])

	var future_paths := ContentLibraryScript.future_pack_paths()
	for path in future_paths.values():
		_check_foundation_pack_path(str(path), failures)


# Ensures canonical foundation paths stay outside the demo runtime pack folder.
func _check_foundation_pack_path(path: String, failures: Array) -> void:
	if not path.begins_with("res://data/"):
		failures.append("Foundation pack path must live under res://data/: %s." % path)
	if path.begins_with("res://data/runtime/"):
		failures.append("Foundation pack path must not point at demo runtime data: %s." % path)


# Checks the canonical M2 packs without forcing unused future packs to exist.
func _check_m2_pack_availability(library: ContentLibrary, failures: Array) -> void:
	var future_paths := ContentLibraryScript.future_pack_paths()
	for pack_name in ["lenders", "services", "travel_routes"]:
		var path := str(future_paths.get(pack_name, ""))
		if path.is_empty():
			failures.append("ContentLibrary is missing M2 pack path: %s." % pack_name)
		elif not FileAccess.file_exists(path):
			failures.append("Missing M2 content pack %s at %s." % [pack_name, path])

	if library.lenders.is_empty():
		failures.append("M2 lender pack should load at least one lender definition.")
	if library.services.is_empty():
		failures.append("M2 service pack should load at least one service definition.")
	if library.travel_routes.is_empty():
		failures.append("M2 travel route pack should load at least one route definition.")

	for lender_hook in _all_environment_ids(library.environment_archetypes, "lender_hooks"):
		if library.lender(lender_hook).is_empty():
			failures.append("Environment lender hook is missing lender pack definition: %s." % lender_hook)

	for service_id in _all_environment_ids(library.environment_archetypes, "service_pool"):
		if library.service(service_id).is_empty():
			failures.append("Environment service hook is missing service pack definition: %s." % service_id)

	for travel_id in _all_environment_ids(library.environment_archetypes, "travel_hooks"):
		var route := library.route(travel_id)
		if route.is_empty():
			failures.append("Environment travel hook is missing route pack metadata: %s." % travel_id)
		elif str(route.get("destination_archetype", "")).is_empty():
			failures.append("Travel route is missing destination_archetype: %s." % travel_id)


# Collects unique ids from one array field across environment archetypes.
func _all_environment_ids(archetypes: Array, field_name: String) -> Array:
	var result: Array = []
	for archetype in archetypes:
		if typeof(archetype) != TYPE_DICTIONARY:
			continue
		var values: Variant = (archetype as Dictionary).get(field_name, [])
		if typeof(values) != TYPE_ARRAY:
			continue
		for value in values:
			var id := str(value).strip_edges()
			if not id.is_empty() and not result.has(id):
				result.append(id)
	return result


func _check_baccarat_grand_casino_only(library: ContentLibrary, failures: Array) -> void:
	var premium_games := ["baccarat", "roulette"]
	var found_in_grand := {}
	for game_id in premium_games:
		found_in_grand[game_id] = false
	for archetype_value in library.environment_archetypes:
		if typeof(archetype_value) != TYPE_DICTIONARY:
			continue
		var archetype: Dictionary = archetype_value
		var archetype_id := str(archetype.get("id", ""))
		var pool := _string_array(archetype.get("game_pool", []))
		for game_id in premium_games:
			if not pool.has(game_id):
				continue
			if archetype_id != "grand_casino":
				failures.append("%s must only appear in Grand Casino, but %s includes it." % [str(game_id).capitalize(), archetype_id])
			else:
				found_in_grand[game_id] = true
				var count_range: Array = archetype.get("game_count", []) if typeof(archetype.get("game_count", [])) == TYPE_ARRAY else []
				if count_range.size() < 2 or int(count_range[0]) < pool.size() or int(count_range[1]) < pool.size():
					failures.append("Grand Casino includes %s but does not guarantee every premium game spot is present." % game_id)
	for game_id in premium_games:
		if not bool(found_in_grand.get(game_id, false)):
			failures.append("%s must be present in the Grand Casino game pool." % str(game_id).capitalize())


# Checks generated item offer prices.
func _check_offer_prices(offers: Array, library: ContentLibrary, failures: Array) -> void:
	var seen: Array = []
	for offer in offers:
		var item_id: String = offer.get("id", "")
		if seen.has(item_id):
			failures.append("Generated duplicate shop item offer: %s." % item_id)
		seen.append(item_id)
		var item := library.item(item_id)
		if item.is_empty():
			failures.append("Generated offer references unknown item: %s." % item_id)
			continue
		var price := int(offer.get("price", -1))
		if price < int(item.get("price_min", 0)) or price > int(item.get("price_max", 0)):
			failures.append("Generated item price outside range: %s." % item_id)


# Checks that room-facing items and events have replaceable art metadata.
func _check_content_art_presentation(library: ContentLibrary, failures: Array) -> void:
	for item in library.items:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var item_data: Dictionary = item
		var item_id := str(item_data.get("id", ""))
		_check_replaceable_asset("items %s" % item_id, item_data, failures)
		for key in ["icon_key", "environment_prop", "surface"]:
			if str(item_data.get(key, "")).strip_edges().is_empty():
				failures.append("items %s is missing %s for room/inventory presentation." % [item_id, key])
	for event in library.events:
		if typeof(event) != TYPE_DICTIONARY:
			continue
		var event_data: Dictionary = event
		var event_id := str(event_data.get("id", ""))
		_check_replaceable_asset("events %s" % event_id, event_data, failures)
		var icon_key := str(event_data.get("icon_key", "")).strip_edges()
		if icon_key.is_empty() or icon_key == "event":
			failures.append("events %s must define a non-generic icon_key." % event_id)
		for key in ["environment_prop", "start_summary"]:
			if str(event_data.get(key, "")).strip_edges().is_empty():
				failures.append("events %s is missing %s for room interaction presentation." % [event_id, key])


func _check_blackjack_item_content(library: ContentLibrary, failures: Array) -> void:
	var required_effects := {
		"marked_cards": ["blackjack_peek_heat_delta", "blackjack_dealer_catch_chance", "blackjack_peek_loss_reduction"],
		"card_counters_notes": ["blackjack_count_tolerance", "blackjack_count_window_msec", "blackjack_count_heat_delta", "blackjack_count_cover", "blackjack_count_edge_bonus"],
		"side_bet_chart": ["blackjack_side_bet_bonus", "blackjack_side_bet_loss_reduction", "blackjack_side_bet_flat_bonus"],
	}
	var reachable_blackjack_items: Array = []
	for item_id in required_effects.keys():
		var item := library.item(str(item_id))
		if item.is_empty():
			failures.append("Blackjack support item is missing from item content: %s." % item_id)
			continue
		var effect: Dictionary = item.get("effect", {}) if typeof(item.get("effect", {})) == TYPE_DICTIONARY else {}
		for effect_key in required_effects[item_id]:
			if not effect.has(str(effect_key)):
				failures.append("Blackjack support item %s is missing effect key %s." % [item_id, effect_key])
	for archetype_value in library.environment_archetypes:
		if typeof(archetype_value) != TYPE_DICTIONARY:
			continue
		var archetype: Dictionary = archetype_value
		if _item_count_ceiling(archetype.get("item_count", 0)) <= 0:
			continue
		var pool := _string_array(archetype.get("item_pool", []))
		for item_id in required_effects.keys():
			if pool.has(str(item_id)) and not reachable_blackjack_items.has(str(item_id)):
				reachable_blackjack_items.append(str(item_id))
	for item_id in required_effects.keys():
		if not reachable_blackjack_items.has(str(item_id)):
			failures.append("Blackjack support item is not reachable from any generated item pool: %s." % item_id)


func _item_count_ceiling(value: Variant) -> int:
	if typeof(value) == TYPE_ARRAY:
		var values: Array = value
		if values.is_empty():
			return 0
		return int(values[values.size() - 1])
	return int(value)


func _check_replaceable_asset(label: String, data: Dictionary, failures: Array) -> void:
	var asset_path := str(data.get("asset_path", "")).strip_edges()
	if asset_path.is_empty():
		failures.append("%s is missing asset_path." % label)
	elif not asset_path.begins_with("res://assets/art/"):
		failures.append("%s asset_path must stay under res://assets/art/." % label)
	elif not FileAccess.file_exists(asset_path):
		failures.append("%s references missing asset_path: %s." % [label, asset_path])


# Checks generated events against allowed scopes.
func _check_events(event_ids: Array, library: ContentLibrary, scopes: Array, failures: Array) -> void:
	if event_ids.size() < 2 or event_ids.size() > 4:
		failures.append("Environment should generate 2-4 events.")
	for event_id in event_ids:
		var event := library.event(event_id)
		if event.is_empty():
			failures.append("Generated unknown event: %s." % event_id)
			continue
		var event_scopes: Array = event.get("scopes", [])
		var matches := event_scopes.has("any")
		for scope in scopes:
			matches = matches or event_scopes.has(scope)
		if not matches:
			failures.append("Generated event does not match environment scope: %s." % event_id)


# Creates in-memory content for contract checks.
func _fixture_library() -> ContentLibrary:
	var library := ContentLibraryScript.new()
	library.environment_archetypes = [
		{
			"id": "fixture_environment",
			"tier": 1,
			"name_prefixes": ["Fixture"],
			"name_nouns": ["Venue"],
			"visual_context": {
				"perspective": "first_person",
				"scene_type": "fixture",
			},
			"security_profile": {
				"strictness": "fixture",
				"visible_cues": ["fixture cue"],
			},
			"economic_profile": {
				"stake_floor": 1,
				"stake_ceiling": 10,
			},
			"game_pool": ["fixture_game"],
			"game_count": [1, 1],
			"event_pool": ["fixture_event"],
			"event_count": [1, 1],
			"item_pool": ["fixture_item"],
			"item_count": [1, 1],
			"service_pool": ["fixture_service"],
			"lender_hooks": ["fixture_lender"],
			"suspicion_cues": ["fixture behavior cue"],
			"travel_hooks": ["fixture_route"],
			"next_archetypes": ["fixture_environment"],
			"local_narrative_flags": {
				"fixture_flag": true,
			},
			"moods": ["fixture_mood"],
		},
	]
	library.games = [
		{
			"id": "fixture_game",
			"module": "base",
			"family": "fixture",
			"display_name": "Fixture Game",
			"intro": "Fixture game contract.",
			"legal_actions": [{"id": "legal_fixture", "label": "Legal Fixture", "win_chance": 55, "payout_mult": 2}],
			"cheat_actions": [{"id": "cheat_fixture", "label": "Cheat Fixture", "win_chance": 70, "payout_mult": 2, "suspicion_delta": 2}],
		},
	]
	library.items = [
		{
			"id": "fixture_item",
			"class": "permanent",
			"domain": "global",
			"effect": {"win_chance": 1},
		},
	]
	library.events = [
		{
			"id": "fixture_event",
			"type": "security",
			"scopes": ["any"],
			"tier_min": 1,
			"min_suspicion": 0,
			"consequences": {
				"suspicion_delta": 1,
			},
			"payload": {
				"summary": "Fixture event contract.",
				"choices": [
					{"id": "raise_heat", "label": "Raise Heat", "text": "Fixture heat rises.", "consequences": {"suspicion_delta": 2, "flags": {"fixture_event_flag": true}, "resolve_event": true}},
				],
			},
		},
	]
	library.challenges = [
		RunState.custom_challenge("fixture_challenge", "FIXTURE-SEED", {"fixture": true}),
	]
	library.lenders = [
		{
			"id": "fixture_lender",
			"source": "fixture",
			"display_name": "Fixture Lender",
			"risk_profile": "fixture",
			"consequences": ["fixture_consequence"],
		},
	]
	library.services = [
		{
			"id": "fixture_service",
			"type": "fixture",
			"cost": 1,
			"effect": {},
		},
	]
	library.travel_routes = [
		{
			"id": "fixture_route",
			"display_name": "Fixture Route",
			"cost": 1,
			"destination_tier_hint": 1,
		},
	]
	library.prestige_purchases = [
		{
			"id": "fixture_prestige",
			"type": "prestige_victory",
			"cost": 1,
		},
	]
	return library


# Checks seed and generation determinism.
func _check_rng(library: ContentLibrary, failures: Array) -> void:
	var rng_a := RngStream.new()
	rng_a.configure(12345)
	var rng_b := RngStream.new()
	rng_b.configure(12345)
	var rng_a_values := [rng_a.randi_range(0, 10), rng_a.randi_range(0, 10), rng_a.randi_range(0, 10)]
	var rng_b_values := [rng_b.randi_range(0, 10), rng_b.randi_range(0, 10), rng_b.randi_range(0, 10)]
	if JSON.stringify(rng_a_values) != JSON.stringify(rng_b_values):
		failures.append("RngStream is not deterministic.")
	var rng_snapshot := rng_a.snapshot()
	var rng_restored := RngStream.new()
	rng_restored.restore(rng_snapshot)
	if rng_a.randi_range(0, 100) != rng_restored.randi_range(0, 100):
		failures.append("RngStream snapshot/restore did not preserve stream state.")
	_check_keyed_rng_streams(failures)

	var custom_challenge := RunState.custom_challenge("foundation_smoke", "FOUNDATION-TEST-SEED", {"stake_pressure": "test"})
	var run_a: RunState = RunStateScript.new()
	run_a.start_new("FOUNDATION-TEST-SEED", custom_challenge)
	var run_b: RunState = RunStateScript.new()
	run_b.start_new("FOUNDATION-TEST-SEED", custom_challenge)
	var generator_a: RunGenerator = RunGeneratorScript.new(library)
	var generator_b: RunGenerator = RunGeneratorScript.new(library)
	var environment_a = generator_a.next_environment(run_a)
	var environment_b = generator_b.next_environment(run_b)

	if JSON.stringify(environment_a.to_dict()) != JSON.stringify(environment_b.to_dict()):
		failures.append("Same fixture seed did not generate the same fixture environment.")
	if run_a.rng_state != run_b.rng_state:
		failures.append("Same fixture seed did not leave the same RunState RNG state after generation.")
	_check_same_seed_game_result(library, custom_challenge, failures)

	var different_challenge_run: RunState = RunStateScript.new()
	different_challenge_run.start_new("FOUNDATION-TEST-SEED", RunState.custom_challenge("foundation_smoke", "FOUNDATION-TEST-SEED", {"stake_pressure": "different"}))
	if different_challenge_run.seed_value == run_a.seed_value:
		failures.append("Challenge modifiers did not affect deterministic seed value.")
	var different_challenge_rng := different_challenge_run.create_rng()
	var baseline_challenge_rng := RunStateScript.new()
	baseline_challenge_rng.start_new("FOUNDATION-TEST-SEED", custom_challenge)
	if JSON.stringify(different_challenge_rng.snapshot()) == JSON.stringify(baseline_challenge_rng.create_rng().snapshot()):
		failures.append("Different challenge modifiers did not change the deterministic stream snapshot.")
	if different_challenge_rng.randi_range(1, 1000000) == baseline_challenge_rng.create_rng().randi_range(1, 1000000):
		failures.append("Different challenge modifiers did not change the deterministic stream.")


# Checks named RNG streams are stable and distinct.
func _check_keyed_rng_streams(failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("STREAM-SEED", RunState.custom_challenge("stream_keys", "STREAM-SEED", {"fixture": true}))
	var state_before := run_state.rng_state
	var environment_stream_a := run_state.create_rng("environment")
	var environment_stream_b := run_state.create_rng("environment")
	var game_stream := run_state.create_rng("game")
	var environment_value_a := environment_stream_a.randi_range(1, 1000000)
	var environment_value_b := environment_stream_b.randi_range(1, 1000000)
	var game_value := game_stream.randi_range(1, 1000000)
	if environment_stream_a.seed_value != environment_stream_b.seed_value:
		failures.append("Same RunState stream key did not derive the same stream seed.")
	if environment_stream_a.seed_value == game_stream.seed_value:
		failures.append("Different RunState stream keys did not derive distinct stream seeds.")
	if environment_value_a != environment_value_b:
		failures.append("Same RunState stream key did not produce the same deterministic stream.")
	if environment_value_a == game_value:
		failures.append("Different RunState stream keys did not produce distinct deterministic streams.")
	if run_state.rng_state != state_before:
		failures.append("RunState.create_rng with a stream key mutated stored RNG state.")


# Checks deterministic game resolution through the foundation RNG path.
func _check_same_seed_game_result(library: ContentLibrary, challenge: Dictionary, failures: Array) -> void:
	var run_a: RunState = RunStateScript.new()
	run_a.start_new("FOUNDATION-TEST-SEED", challenge)
	var run_b: RunState = RunStateScript.new()
	run_b.start_new("FOUNDATION-TEST-SEED", challenge)
	var generator_a: RunGenerator = RunGeneratorScript.new(library)
	var generator_b: RunGenerator = RunGeneratorScript.new(library)
	var environment_a = generator_a.next_environment(run_a)
	var environment_b = generator_b.next_environment(run_b)
	var game_a := GameModule.new()
	game_a.setup(library.game("fixture_game"))
	var game_b := GameModule.new()
	game_b.setup(library.game("fixture_game"))
	var result_a := game_a.resolve("legal_fixture", 1, run_a, environment_a.to_dict(), run_a.create_rng())
	var result_b := game_b.resolve("legal_fixture", 1, run_b, environment_b.to_dict(), run_b.create_rng())
	if JSON.stringify(result_a) != JSON.stringify(result_b):
		failures.append("Same seed and challenge did not produce the same foundation game result.")
	if JSON.stringify(run_a.to_dict()) != JSON.stringify(run_b.to_dict()):
		failures.append("Same foundation game result did not leave matching RunState snapshots.")


# Checks that RunState owns foundation run state and round-trips every required domain.
func _check_run_state_source_of_truth(library: ContentLibrary, failures: Array) -> void:
	var challenge := RunState.custom_challenge("run_state_round_trip", "RUNSTATE-SEED", {"route": "fixture", "pressure": "low"})
	var run_a: RunState = RunStateScript.new()
	run_a.start_new("IGNORED-SEED", challenge)
	var run_b: RunState = RunStateScript.new()
	run_b.start_new("IGNORED-SEED", challenge)
	if JSON.stringify(run_a.to_dict()) != JSON.stringify(run_b.to_dict()):
		failures.append("RunState.start_new is not deterministic for the same seed and challenge.")

	var rng_a := run_a.create_rng()
	var rng_b := run_b.create_rng()
	if rng_a.randi_range(1, 1000) != rng_b.randi_range(1, 1000):
		failures.append("RunState did not create deterministic RNG streams from initial state.")

	var generator: RunGenerator = RunGeneratorScript.new(library)
	var environment = generator.next_environment(run_a)
	run_a.change_bankroll(-17)
	run_a.add_item("fixture_item")
	run_a.set_active_item("fixture_item")
	run_a.add_debt({
		"id": "fixture_debt",
		"lender_id": "fixture_lender",
		"balance": 30,
		"status": "active",
	})
	run_a.add_suspicion("fixture_behavior", 4, "behavior", false, {"environment_id": environment.id})
	run_a.narrative_flags["fixture_flag"] = true
	run_a.log_story({"type": "round_trip", "id": "fixture_story", "environment_id": environment.id})
	run_a.advance_environment_turns(2)
	run_a.resolve_event("fixture_event")
	run_a.set_next_archetypes(["fixture_environment"])
	var advanced_rng := run_a.create_rng()
	advanced_rng.randi_range(1, 1000)
	run_a.save_rng(advanced_rng)

	var snapshot := run_a.to_dict()
	_check_run_state_snapshot_keys(snapshot, failures)
	var restored: RunState = RunStateScript.new()
	restored.from_dict(snapshot)
	_assert_equal(run_a.seed_text, restored.seed_text, "RunState seed_text did not survive round-trip.", failures)
	_assert_equal(run_a.seed_value, restored.seed_value, "RunState seed_value did not survive round-trip.", failures)
	_assert_equal(run_a.rng_seed, restored.rng_seed, "RunState rng_seed did not survive round-trip.", failures)
	_assert_equal(run_a.rng_state, restored.rng_state, "RunState rng_state did not survive round-trip.", failures)
	_assert_json_equal(run_a.challenge_config, restored.challenge_config, "RunState challenge config did not survive round-trip.", failures)
	_assert_equal(run_a.bankroll, restored.bankroll, "RunState bankroll did not survive round-trip.", failures)
	_assert_equal(run_a.economic_state, restored.economic_state, "RunState economic state did not survive round-trip.", failures)
	_assert_json_equal(run_a.inventory, restored.inventory, "RunState inventory did not survive round-trip.", failures)
	_assert_equal(run_a.active_item_id, restored.active_item_id, "RunState active item did not survive round-trip.", failures)
	_assert_json_equal(run_a.debt, restored.debt, "RunState debt did not survive round-trip.", failures)
	_assert_json_equal(run_a.suspicion, restored.suspicion, "RunState suspicion did not survive round-trip.", failures)
	_assert_json_equal(run_a.current_environment, restored.current_environment, "RunState current environment did not survive round-trip.", failures)
	_assert_json_equal(run_a.environment_history, restored.environment_history, "RunState environment history did not survive round-trip.", failures)
	_assert_json_equal(run_a.unlocked_travel, restored.unlocked_travel, "RunState travel hooks did not survive round-trip.", failures)
	_assert_json_equal(run_a.narrative_flags, restored.narrative_flags, "RunState narrative flags did not survive round-trip.", failures)
	_assert_json_equal(run_a.story_log, restored.story_log, "RunState story log did not survive round-trip.", failures)
	_assert_equal(run_a.run_status, restored.run_status, "RunState run status did not survive round-trip.", failures)

	var original_rng := run_a.create_rng()
	var restored_rng := restored.create_rng()
	if original_rng.randi_range(1, 1000) != restored_rng.randi_range(1, 1000):
		failures.append("RunState restored RNG state did not continue the same stream.")

	snapshot["inventory"].append("mutated_item")
	snapshot["debt"][0]["balance"] = 999
	snapshot["suspicion"]["cues"][0]["context"]["environment_id"] = "mutated_environment"
	snapshot["current_environment"]["id"] = "mutated_environment"
	snapshot["narrative_flags"]["fixture_flag"] = false
	snapshot["story_log"][0]["id"] = "mutated_story"
	if restored.inventory.has("mutated_item"):
		failures.append("RunState.from_dict retained mutable inventory source data.")
	if int(restored.debt[0].get("balance", 0)) == 999:
		failures.append("RunState.from_dict retained mutable debt source data.")
	if str(restored.suspicion.get("cues", [])[0].get("context", {}).get("environment_id", "")) == "mutated_environment":
		failures.append("RunState.from_dict retained mutable suspicion source data.")
	if restored.current_environment.get("id", "") == "mutated_environment":
		failures.append("RunState.from_dict retained mutable environment source data.")
	if not bool(restored.narrative_flags.get("fixture_flag", false)):
		failures.append("RunState.from_dict retained mutable flag source data.")
	if str(restored.story_log[0].get("id", "")) == "mutated_story":
		failures.append("RunState.from_dict retained mutable story source data.")


# Ensures RunState serialization stays inside simulation domains.
func _check_run_state_snapshot_keys(snapshot: Dictionary, failures: Array) -> void:
	var required_keys := [
		"seed_text",
		"seed_value",
		"rng_seed",
		"rng_state",
		"challenge_config",
		"bankroll",
		"economic_state",
		"inventory",
		"active_item_id",
		"debt",
		"suspicion",
		"current_environment",
		"environment_history",
		"unlocked_travel",
		"narrative_flags",
		"story_log",
		"run_status",
	]
	for key in required_keys:
		if not snapshot.has(key):
			failures.append("RunState snapshot is missing required key: %s." % key)
	var forbidden_keys := [
		"ui_selection",
		"focus",
		"hover",
		"overlay_state",
		"button_metadata",
		"transient_scene_cache",
		"profile_inventory",
		"art_layout_state",
		"game_state",
	]
	for key in forbidden_keys:
		if snapshot.has(key):
			failures.append("RunState snapshot contains forbidden UI/profile key: %s." % key)


# Compares scalar values in foundation checks.
func _assert_equal(actual: Variant, expected: Variant, message: String, failures: Array) -> void:
	if actual != expected:
		failures.append(message)


# Compares dictionaries and arrays in foundation checks.
func _assert_json_equal(actual: Variant, expected: Variant, message: String, failures: Array) -> void:
	if JSON.stringify(actual) != JSON.stringify(expected):
		failures.append(message)


# Checks core contracts with fixture content.
func _check_contracts(library: ContentLibrary, failures: Array) -> void:
	var custom_challenge := RunState.custom_challenge("foundation_contracts", "FOUNDATION-CONTRACT-SEED", {"fixture": true})
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("FOUNDATION-CONTRACT-SEED", custom_challenge)
	var generator: RunGenerator = RunGeneratorScript.new(library)
	var environment = generator.next_environment(run_state)

	if environment.lender_hooks.is_empty():
		failures.append("Environment contract did not include debt/lender hooks.")
	if environment.suspicion_cues.is_empty():
		failures.append("Environment contract did not include behavior-first suspicion cues.")
	if environment.local_narrative_flags.is_empty():
		failures.append("Environment contract did not include local narrative flags.")
	var environment_data: Dictionary = environment.to_dict()
	environment_data["game_ids"].append("mutated_game")
	if environment.game_ids.has("mutated_game"):
		failures.append("EnvironmentInstance.to_dict leaked mutable arrays.")
	var restored_environment := EnvironmentInstance.from_dict(environment.to_dict())
	if JSON.stringify(restored_environment.to_dict()) != JSON.stringify(environment.to_dict()):
		failures.append("EnvironmentInstance.from_dict did not preserve saveable data.")

	var game := GameModule.new()
	game.setup(library.game("fixture_game"))
	var action_presentation: Dictionary = game.actions(run_state, environment.to_dict())
	if action_presentation.get("legal_actions", []).is_empty():
		failures.append("Game module contract did not present legal actions.")
	if action_presentation.get("cheat_actions", []).is_empty():
		failures.append("Game module contract did not present cheat actions.")
	var mutated_actions: Array = action_presentation.get("legal_actions", [])
	mutated_actions[0]["id"] = "mutated_action"
	if game.legal_actions(run_state, environment.to_dict())[0].get("id", "") == "mutated_action":
		failures.append("GameModule action presentation leaked mutable definitions.")
	var legal_before := _run_state_result_snapshot(run_state)
	var rng := run_state.create_rng()
	var unresolved_result: Dictionary = game.resolve("legal_fixture", 1, run_state, environment.to_dict(), rng)
	if unresolved_result.get("game_id", "") != "fixture_game":
		failures.append("Base game module did not return a structured result.")
	_check_action_result_shape(unresolved_result, "legal", failures)
	_check_action_result_applied(legal_before, run_state, unresolved_result, "legal contract result", failures)
	var cheat_before := _run_state_result_snapshot(run_state)
	var cheat_result := game.resolve("cheat_fixture", 1, run_state, environment.to_dict(), run_state.create_rng())
	_check_action_result_shape(cheat_result, "cheat", failures)
	_check_action_result_applied(cheat_before, run_state, cheat_result, "cheat contract result", failures)
	var invalid_bankroll := run_state.bankroll
	var invalid_result := game.resolve("missing_fixture", 1, run_state, environment.to_dict(), rng)
	if bool(invalid_result.get("ok", true)):
		failures.append("Game module accepted an unavailable action.")
	if run_state.bankroll != invalid_bankroll:
		failures.append("Unavailable game action mutated RunState.")

	var event := EventModule.new()
	event.setup(library.event("fixture_event"))
	if not event.can_trigger(run_state, environment.to_dict()):
		failures.append("Event module contract did not trigger from fixture state.")
	var event_before := _run_state_result_snapshot(run_state)
	var event_result := event.resolve(run_state, environment.to_dict(), "raise_heat")
	_check_event_result_delta_shape(event_result, failures)
	_check_event_result_applied(event_before, run_state, event_result, "fixture event result", failures)
	if not bool(run_state.narrative_flags.get("fixture_event_flag", false)):
		failures.append("Event module did not apply flag consequences.")

	var item_effect := ItemEffect.new()
	item_effect.setup(library.item("fixture_item"))
	if not item_effect.applies({"domain": "global"}):
		failures.append("Item effect contract did not apply to matching domain.")
	var applied_item := item_effect.apply({"domain": "global", "action_kind": "legal"})
	if not bool(applied_item.get("applied", false)):
		failures.append("Item effect did not mark matching context as applied.")
	_check_item_result_delta_shape(applied_item, failures)
	if applied_item.get("deltas", {}).get("item_hooks", []).is_empty():
		failures.append("Item effect result did not contribute modifiers through item_hooks.")
	applied_item["effect"]["win_chance"] = 99
	if int(item_effect.effect_data().get("win_chance", 0)) == 99:
		failures.append("ItemEffect leaked mutable effect data.")

	var delta_item := ItemEffect.new()
	delta_item.setup({
		"id": "fixture_delta_item",
		"class": "temporary",
		"domain": "run_state",
		"effect": {
			"bankroll_delta": 3,
			"suspicion_delta": 1,
			"debt_changes": [{"id": "fixture_item_debt", "lender_id": "fixture_lender", "balance": 4, "status": "active"}],
			"flags_set": {"fixture_item_flag": true},
			"travel_hooks_add": ["fixture_environment"],
			"event_hooks": ["fixture_event"],
			"story_log": [{"type": "item_effect", "id": "fixture_delta_item", "environment_id": environment.id}],
		},
	})
	var item_delta_before := _run_state_result_snapshot(run_state)
	var delta_result := delta_item.apply({"domain": "run_state", "environment_id": environment.id}, run_state)
	_check_item_result_delta_shape(delta_result, failures)
	_check_item_result_applied(item_delta_before, run_state, delta_result, "fixture item delta result", failures)
	if not bool(run_state.narrative_flags.get("fixture_item_flag", false)):
		failures.append("ItemEffect direct delta did not set RunState flags.")

	var bankroll_before := run_state.bankroll
	run_state.change_bankroll(25)
	if run_state.bankroll != bankroll_before + 25:
		failures.append("RunState did not apply bankroll changes.")

	run_state.add_suspicion("fixture_behavior", 4, "behavior", false, {"environment_id": environment.id})
	if int(run_state.suspicion.get("level", 0)) <= 0:
		failures.append("RunState did not preserve suspicion state.")

	run_state.add_debt({
		"id": "fixture_debt",
		"lender_id": "fixture_lender",
		"balance": 30,
		"status": "active",
	})
	if run_state.debt.is_empty():
		failures.append("RunState did not preserve debt state.")

	run_state.set_environment(environment.to_dict())
	if run_state.unlocked_travel.is_empty():
		failures.append("RunState did not expose environment travel hooks.")

	run_state.narrative_flags["foundation_story_flag"] = true
	run_state.log_story({"type": "smoke", "id": "foundation_event", "environment_id": environment.id})
	if not bool(run_state.narrative_flags.get("foundation_story_flag", false)):
		failures.append("RunState did not preserve narrative flags.")
	if run_state.story_log.is_empty():
		failures.append("RunState did not preserve narrative story log.")
	run_state.add_item("fixture_item")
	var run_snapshot := run_state.to_dict()
	run_snapshot["inventory"].append("mutated_item")
	run_snapshot["current_environment"]["id"] = "mutated_environment"
	if run_state.inventory.has("mutated_item") or run_state.current_environment.get("id", "") == "mutated_environment":
		failures.append("RunState.to_dict leaked mutable state.")
	var restored_run: RunState = RunStateScript.new()
	var restored_source := run_state.to_dict()
	restored_run.from_dict(restored_source)
	restored_source["inventory"].append("late_mutation")
	if restored_run.inventory.has("late_mutation"):
		failures.append("RunState.from_dict retained mutable source arrays.")

	var save_service: SaveService = SaveServiceScript.new()
	var save_error: Error = save_service.save_run(run_state, "foundation_check")
	if save_error != OK:
		failures.append("Save service returned error %s." % save_error)
	else:
		var loaded = save_service.load_run("foundation_check")
		if loaded == null:
			failures.append("Save service could not reload the saved run.")
		elif loaded.seed_text != run_state.seed_text:
			failures.append("Loaded run did not preserve seed text.")
		elif loaded.challenge_config.get("id", "") != run_state.challenge_config.get("id", ""):
			failures.append("Loaded run did not preserve challenge configuration.")
		elif loaded.bankroll != run_state.bankroll:
			failures.append("Loaded run did not preserve bankroll.")
		elif loaded.debt.size() != run_state.debt.size():
			failures.append("Loaded run did not preserve debt state.")
		elif loaded.story_log.size() != run_state.story_log.size():
			failures.append("Loaded run did not preserve narrative story log.")

	var platform: PlatformServices = PlatformServicesScript.new()
	platform.setup("fixture_platform")
	var platform_init := platform.initialize()
	if not bool(platform_init.get("ok", false)) or platform_init.get("service", "") != "fixture_platform":
		failures.append("PlatformServices did not initialize as a local adapter.")
	var cloud_payload := platform.save_cloud_run("fixture", run_state.to_dict())
	cloud_payload["run_data"]["seed_text"] = "mutated"
	if run_state.seed_text == "mutated":
		failures.append("PlatformServices leaked mutable cloud-save input.")
