extends SceneTree

# Deterministic, renderer-backed visual evidence for the Crew's five-card draw
# table. Run windowed so the viewport texture contains real rendered pixels.

const MainScene := preload("res://scenes/main.tscn")
const CrewPokerModelScript := preload("res://scripts/core/crew_poker_model.gd")
const CrewStateModelScript := preload("res://scripts/core/crew_state_model.gd")
const CrewPokerVisualSeedAuditScript := preload("res://tools/crew_poker_visual_seed_audit.gd")
const OUTPUT_DIR := "res://.tmp/crew_poker_visual_qa"
const MANIFEST_PATH := OUTPUT_DIR + "/manifest.json"
const CAPTURE_SIZE := Vector2i(1280, 720)
const FIXTURE_SEED := CrewPokerVisualSeedAuditScript.FIXTURE_SEED
const CAPTURE_FILE_NAMES: Array[String] = [
	"01_entry_idle_1280x720.png",
	"02_active_draw_1280x720.png",
	"03_authored_subtle_tell_1280x720.png",
	"04_reduced_motion_static_1280x720.png",
]
const PUNCHLINE_ARCHETYPE_ID := "small_underground_casino"
const PUNCHLINE_DISPLAY_NAME := "The Punchline"
const PUNCHLINE_BACK_ROOM_LAYER := "back_room"
const MIN_HIT_SIZE := 44.0
const CAPTURE_TIMEOUT_MSEC := 75000
const CAPTURE_OUTPUT_BUDGET_MSEC := 15000
const PRODUCTION_ACTION_BUDGET_MSEC := 5000
const PRODUCTION_ACTION_LIMIT := 4

var app: Control
var canvas: Control
var run_state: RunState
var captures: Array[Dictionary] = []
var queued_capture_outputs: Array[Dictionary] = []
var failed := false
var liveness_evidence: Dictionary = {}
var reduced_motion_evidence: Dictionary = {}
var acceptance_context: Dictionary = {}
var seed_audit_evidence: Dictionary = {}
var foundation_action_rng: Dictionary = {}
var foundation_rng_matches_audit := false
var authored_tell_channel: String = ""
var authored_tell_member_id: String = ""
var authored_tell_surface_phase: String = ""
var authored_tell_table_phase: String = ""
var authored_tell_hand_number: int = -1
var authored_tell_beat_present: bool = false
var authored_tell_render_state: Dictionary = {}
var authored_tell_capture_state: Dictionary = {}
var reduced_motion_render_state: Dictionary = {}
var reduced_motion_capture_state: Dictionary = {}
var authored_tell_hidden_leaks: Array[Dictionary] = []
var latest_action_surface_state: Dictionary = {}
var tell_expected_actions: Array[String] = []
var current_stage := "not_started"
var current_attempt: Dictionary = {}
var stage_history: Array[Dictionary] = []
var failure_messages: Array[String] = []
var removed_stale_capture_files: Array[String] = []
var started_msec := 0
var finishing := false


func _init() -> void:
	call_deferred("_run")
	call_deferred("_watchdog")


func _run() -> void:
	started_msec = Time.get_ticks_msec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	if not _clear_stale_capture_files():
		_fail("Crew poker capture could not remove stale PNG evidence before starting.")
		_finish()
		return
	_stage("boot", {"capture_timeout_msec": CAPTURE_TIMEOUT_MSEC})
	root.size = CAPTURE_SIZE
	RenderingServer.set_default_clear_color(Color("#08070d"))
	app = MainScene.instantiate()
	app.set("autosave_slot_id", "crew_poker_visual_capture")
	root.add_child(app)
	await _settle(8)
	var library := app.get("library") as ContentLibrary
	_stage("natural_tell_seed_audit_start", {"seed": FIXTURE_SEED})
	seed_audit_evidence = CrewPokerVisualSeedAuditScript.audit_pinned_seed(library)
	_stage("natural_tell_seed_audit_complete", {
		"passed": bool(seed_audit_evidence.get("passed", false)),
		"seed": str(seed_audit_evidence.get("seed", "")),
		"pinned_seed_assertion": bool(seed_audit_evidence.get("pinned_seed_assertion", false)),
	})
	if not bool(seed_audit_evidence.get("passed", false)) or str(seed_audit_evidence.get("seed", "")) != FIXTURE_SEED:
		_fail("Crew poker capture pinned seed no longer produces a first-hand authored tell through production actions.")
		_finish()
		return
	_stage("foundation_run_start", {"seed": FIXTURE_SEED})
	# Disable profile-derived home modifiers so the pure seed audit and runtime
	# traverse the same standard foundation generation path.
	app.call("start_foundation_run", FIXTURE_SEED, {}, false)
	await _settle(8)
	run_state = app.get("run_state") as RunState
	if run_state == null:
		_fail("Crew poker capture could not access the production run.")
		_finish()
		return
	foundation_action_rng = {"seed": run_state.rng_seed, "state": run_state.rng_state}
	var audited_action_rng: Dictionary = seed_audit_evidence.get("action_rng_after_foundation_generation", {}) if typeof(seed_audit_evidence.get("action_rng_after_foundation_generation", {})) == TYPE_DICTIONARY else {}
	foundation_rng_matches_audit = foundation_action_rng == audited_action_rng
	_stage("foundation_rng_audit_match", {
		"passed": foundation_rng_matches_audit,
		"actual": foundation_action_rng.duplicate(),
		"audited": audited_action_rng.duplicate(),
	})
	if not foundation_rng_matches_audit:
		_fail("Crew poker capture foundation action RNG did not match the production seed audit.")
		_finish()
		return
	for member_id in CrewStateModelScript.MEMBER_IDS:
		run_state.crew_add_trust(str(member_id), CrewStateModelScript.rank_threshold("made"), "visual_capture_l3_access")
	_stage("punchline_l3_navigation_start")
	if not await _enter_punchline_poker_from_l3():
		_finish()
		return
	canvas = app.get("game_surface_canvas") as Control
	if canvas == null:
		_fail("Crew poker capture could not access the production table canvas.")
		_finish()
		return
	_stage("production_renderer_validation", {"source": "realtime_surface_state"})
	if not canvas.visible or str((canvas.call("realtime_surface_state") as Dictionary).get("surface_renderer", "")) != "crew_draw_poker":
		_fail("Crew poker capture did not route through the production table renderer.")
		_finish()
		return

	_stage("capture_entry_idle")
	await _capture_surface(
		"01_entry_idle_1280x720.png",
		"entry_idle",
		["poker_deal", "poker_cash_out"],
		0
	)
	_capture_idle_liveness()

	_perform_production_action("poker_deal", 0, false, "before", 1)
	if not failed:
		await _settle(4)
		_perform_production_action("poker_call", 0, false, "draw", 2)
	if not failed:
		await _settle(4)
		_perform_production_action("poker_card", 0, false, "draw", 3)
	if not failed:
		_perform_production_action("poker_card", 2, false, "draw", 4)
	if not failed:
		await _settle(3)
		_stage("capture_active_draw")
		await _capture_surface(
			"02_active_draw_1280x720.png",
			"active_draw",
			["poker_draw", "poker_fold"],
			5
		)

	if not failed:
		_stage("natural_tell_first_hand_assertion", {"hand_limit": 1, "input_sequence": CrewPokerVisualSeedAuditScript.INPUT_SEQUENCE.duplicate()})
		if not _has_authored_observation():
			_fail("Crew poker audited deal/call sequence did not naturally surface an authored subtle presentation in its single hand.")
	if not failed:
		if not ["line", "portrait", "timing"].has(authored_tell_channel) \
				or authored_tell_member_id.is_empty():
			_fail("Crew poker capture did not retain the production-authored subtle presentation.")
		tell_expected_actions = ["poker_draw", "poker_fold"] if authored_tell_surface_phase == "draw" else ["poker_call", "poker_raise", "poker_fold"]
		_stage("capture_authored_subtle_tell", {"channel": authored_tell_channel, "member_id": authored_tell_member_id})
		await _capture_surface(
			"03_authored_subtle_tell_1280x720.png",
			"authored_subtle_tell",
			tell_expected_actions,
			5 if authored_tell_surface_phase == "draw" else 0,
			authored_tell_capture_state
		)

	if not failed:
		_stage("capture_reduced_motion", {"state_source": "precomputed_action_projection"})
		_stage("reduced_motion_render_snapshot", {"state_source": "precomputed_action_projection"})
		canvas.call("render_game_snapshot", reduced_motion_render_state)
		await _settle(3)
		_capture_reduced_motion_stability()
		await _capture_surface(
			"04_reduced_motion_static_1280x720.png",
			"reduced_motion_static",
			tell_expected_actions,
			5 if authored_tell_surface_phase == "draw" else 0,
			reduced_motion_capture_state
		)

	if not failed:
		_stage("session_exit_to_l3", {"kind": "l3_session_exit", "attempt": 1, "limit": 1})
		await _verify_session_exit_to_l3()
	if not failed:
		_stage("capture_output_flush_start", {
			"queued_capture_count": queued_capture_outputs.size(),
			"expected_capture_count": CAPTURE_FILE_NAMES.size(),
			"budget_msec": CAPTURE_OUTPUT_BUDGET_MSEC,
		})
		_flush_capture_outputs()
	_finish()


func _enter_punchline_poker_from_l3() -> bool:
	var library := app.get("library") as ContentLibrary
	if library == null:
		_fail("Crew poker capture could not access production content.")
		return false
	var archetype := library.environment_archetype(PUNCHLINE_ARCHETYPE_ID)
	if archetype.is_empty():
		_fail("Crew poker capture could not load The Punchline archetype.")
		return false
	var fixture_rng := run_state.create_rng("crew_poker_visual_capture:punchline")
	var environment := EnvironmentInstance.from_archetype(
		archetype,
		0,
		fixture_rng,
		library,
		run_state.challenge_config
	).to_dict()
	if not _install_fixture_residents(environment):
		_fail("Crew poker capture could not author the audited Punchline resident input.")
		return false
	run_state.set_environment(environment)
	run_state.bankroll = 500
	run_state.drunk_level = 0
	run_state.pending_drunk_absorption = []
	app.call("back_to_environment")
	app.call("_refresh")
	await _settle(5)
	var initial_layer := str(run_state.current_environment.get("current_layer_id", ""))
	var navigation: Array[Dictionary] = []
	for target_layer in ["casino", PUNCHLINE_BACK_ROOM_LAYER]:
		current_attempt = {"kind": "layer_navigation", "target_layer": str(target_layer), "attempt": navigation.size() + 1, "limit": 2}
		_stage("layer_navigation_attempt", current_attempt)
		var layer_object := _environment_interactable("environment_layer", str(target_layer))
		var object_id := _interactable_id(layer_object)
		var activated := not object_id.is_empty() and bool(app.call("activate_interactable_object", object_id))
		await _settle(5)
		app.call("_refresh")
		await _settle(3)
		navigation.append({
			"from_layer": initial_layer if navigation.is_empty() else str((navigation[navigation.size() - 1] as Dictionary).get("arrived_layer", "")),
			"target_layer": str(target_layer),
			"object_id": object_id,
			"source_id": str(layer_object.get("source_id", "")),
			"enabled": not bool(layer_object.get("disabled", false)),
			"activated": activated,
			"arrived_layer": str(run_state.current_environment.get("current_layer_id", "")),
		})
		if not activated or str(run_state.current_environment.get("current_layer_id", "")) != str(target_layer):
			_fail("Crew poker capture could not navigate The Punchline layer door to %s." % str(target_layer))
			return false

	# Force one final production refresh so the visible title plate and layer blurb
	# are sourced from The Punchline back-room environment before table entry.
	app.call("_refresh")
	await _settle(5)
	var header := app.call("current_environment_header_snapshot") as Dictionary
	var game_object := _environment_interactable("game", "crew_draw_poker")
	var game_object_id := _interactable_id(game_object)
	var generated_table := _table()
	var table_members: Array = generated_table.get("members", []) if typeof(generated_table.get("members", [])) == TYPE_ARRAY else []
	var residents_passed := table_members.size() == CrewPokerVisualSeedAuditScript.RESIDENTS.size()
	for resident_id in CrewPokerVisualSeedAuditScript.RESIDENTS:
		residents_passed = residents_passed and table_members.has(resident_id)
	var rng_before_gameplay := {"seed": run_state.rng_seed, "state": run_state.rng_state}
	var fixture_rng_untouched := rng_before_gameplay == foundation_action_rng
	var environment_context := {
		"archetype_id": str(run_state.current_environment.get("archetype_id", "")),
		"display_name": str(run_state.current_environment.get("display_name", "")),
		"layer_id": str(run_state.current_environment.get("current_layer_id", "")),
		"layer_display_name": str(run_state.current_environment.get("layer_display_name", "")),
		"kind": str(run_state.current_environment.get("kind", "")),
		"game_ids": (run_state.current_environment.get("game_ids", []) as Array).duplicate(true) if typeof(run_state.current_environment.get("game_ids", [])) == TYPE_ARRAY else [],
	}
	var navigation_passed := initial_layer == "club" and navigation.size() == 2 \
		and str((navigation[0] as Dictionary).get("from_layer", "")) == "club" \
		and str((navigation[0] as Dictionary).get("object_id", "")) == "environment_layer:casino" \
		and str((navigation[0] as Dictionary).get("arrived_layer", "")) == "casino" \
		and str((navigation[1] as Dictionary).get("from_layer", "")) == "casino" \
		and str((navigation[1] as Dictionary).get("object_id", "")) == "environment_layer:back_room" \
		and str((navigation[1] as Dictionary).get("arrived_layer", "")) == PUNCHLINE_BACK_ROOM_LAYER
	var header_passed := str(header.get("archetype_id", "")) == PUNCHLINE_ARCHETYPE_ID \
		and str(header.get("accessible_title", "")) == PUNCHLINE_DISPLAY_NAME \
		and str(header.get("blurb", "")).findn("private table") >= 0 \
		and not JSON.stringify(header).to_lower().contains("grand casino")
	var environment_passed := str(environment_context.get("archetype_id", "")) == PUNCHLINE_ARCHETYPE_ID \
		and str(environment_context.get("display_name", "")) == PUNCHLINE_DISPLAY_NAME \
		and str(environment_context.get("layer_id", "")) == PUNCHLINE_BACK_ROOM_LAYER \
		and str(environment_context.get("layer_display_name", "")) == "Crew Back Room" \
		and (environment_context.get("game_ids", []) as Array).has("crew_draw_poker")
	var interactable_passed := not game_object_id.is_empty() \
		and game_object_id.begins_with("game:crew_draw_poker") \
		and str(game_object.get("source_id", "")) == "crew_draw_poker" \
		and not bool(game_object.get("disabled", false))
	acceptance_context = {
		"seed": FIXTURE_SEED,
		"natural_tell_seed_audit": seed_audit_evidence.duplicate(true),
		"fixture_resident_input": CrewPokerVisualSeedAuditScript.RESIDENTS.duplicate(),
		"generated_table_members": table_members.duplicate(),
		"fixture_residents_passed": residents_passed,
		"foundation_action_rng": foundation_action_rng.duplicate(),
		"rng_before_gameplay": rng_before_gameplay,
		"fixture_rng_untouched": fixture_rng_untouched,
		"foundation_rng_matches_audit": foundation_rng_matches_audit,
		"initial_layer": initial_layer,
		"layer_navigation": navigation,
		"environment": environment_context,
		"header": header,
		"header_refreshed_from_production_environment": header_passed,
		"layer_navigation_passed": navigation_passed,
		"l3_game_interactable": {
			"object_id": game_object_id,
			"source_id": str(game_object.get("source_id", "")),
			"label": str(game_object.get("label", "")),
			"enabled": not bool(game_object.get("disabled", false)),
		},
		"entry_method": "activate_interactable_object",
		"environment_passed": environment_passed,
		"interactable_passed": interactable_passed,
	}
	if not navigation_passed or not header_passed or not environment_passed or not interactable_passed or not residents_passed or not fixture_rng_untouched or not foundation_rng_matches_audit:
		_fail("Crew poker capture did not establish the real Punchline L3 environment/header/interactable context.")
		return false
	current_attempt = {"kind": "l3_game_entry", "attempt": 1, "limit": 1, "object_id": game_object_id}
	_stage("l3_game_entry_attempt", current_attempt)
	var entered := bool(app.call("activate_interactable_object", game_object_id))
	await _settle(6)
	var game_view := app.call("current_game_view_snapshot") as Dictionary
	var screen := app.call("current_screen_snapshot") as Dictionary
	var entry_passed := entered \
		and str(game_view.get("surface_renderer", "")) == "crew_draw_poker" \
		and str(screen.get("screen", "")) == "GAME"
	acceptance_context["entry"] = {
		"activated": entered,
		"screen": str(screen.get("screen", "")),
		"renderer": str(game_view.get("surface_renderer", "")),
		"passed": entry_passed,
	}
	acceptance_context["passed"] = navigation_passed and header_passed and environment_passed and interactable_passed and residents_passed and fixture_rng_untouched and foundation_rng_matches_audit \
		and bool(seed_audit_evidence.get("passed", false)) and entry_passed
	if not entry_passed:
		_fail("Crew poker capture could not enter the table through its L3 game interactable.")
	return entry_passed


func _install_fixture_residents(environment: Dictionary) -> bool:
	var layer_states: Dictionary = environment.get("layer_states", {}) if typeof(environment.get("layer_states", {})) == TYPE_DICTIONARY else {}
	var back_room: Dictionary = layer_states.get(PUNCHLINE_BACK_ROOM_LAYER, {}) if typeof(layer_states.get(PUNCHLINE_BACK_ROOM_LAYER, {})) == TYPE_DICTIONARY else {}
	var existing_game_states: Dictionary = back_room.get("game_states", {}) if typeof(back_room.get("game_states", {})) == TYPE_DICTIONARY else {}
	if back_room.is_empty() or not existing_game_states.is_empty():
		return false
	layer_states = layer_states.duplicate(true)
	back_room = back_room.duplicate(true)
	back_room["resident_member_ids"] = CrewPokerVisualSeedAuditScript.RESIDENTS.duplicate()
	layer_states[PUNCHLINE_BACK_ROOM_LAYER] = back_room
	environment["layer_states"] = layer_states
	return true


func _clear_stale_capture_files() -> bool:
	for file_name in CAPTURE_FILE_NAMES:
		var capture_path := OUTPUT_DIR + "/" + file_name
		if not FileAccess.file_exists(capture_path):
			continue
		var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(capture_path))
		if error != OK:
			return false
		removed_stale_capture_files.append(file_name)
	return true


func _perform_production_action(action: String, index: int, confirm_requested: bool, expected_phase: String, ordinal: int) -> bool:
	var attempt := {
		"kind": "production_action",
		"action": action,
		"index": index,
		"attempt": ordinal,
		"limit": PRODUCTION_ACTION_LIMIT,
		"expected_phase": expected_phase,
		"budget_msec": PRODUCTION_ACTION_BUDGET_MSEC,
	}
	_stage("production_action_snapshot_before", attempt)
	var before := _production_action_snapshot()
	attempt["before"] = before
	_stage("production_action_before", attempt)
	var action_started_msec := Time.get_ticks_msec()
	var handled := bool(app.call("_handle_module_surface_action", action, index, confirm_requested))
	var action_elapsed_msec := Time.get_ticks_msec() - action_started_msec
	_stage("production_action_snapshot_after", attempt)
	var after := _production_action_snapshot()
	var phase_passed := expected_phase.is_empty() or str(after.get("table_phase", "")) == expected_phase
	var within_budget := action_elapsed_msec <= PRODUCTION_ACTION_BUDGET_MSEC
	var outcome_passed := handled and phase_passed and within_budget
	if outcome_passed:
		authored_tell_hand_number = int(after.get("hand_number", -1))
		authored_tell_table_phase = str(after.get("table_phase", ""))
		authored_tell_surface_phase = str(after.get("surface_phase", ""))
		authored_tell_beat_present = bool(after.get("beat_present", false))
		authored_tell_member_id = str(after.get("observation_member_id", ""))
		authored_tell_channel = str(after.get("observation_channel", ""))
		# Retain the renderer dictionary by reference and prepare every safe value
		# projection before viewport capture. Deep-copying it afterward can traverse
		# object-bearing/cyclic renderer values indefinitely.
		authored_tell_render_state = latest_action_surface_state
		authored_tell_capture_state = {
			"phase": str(after.get("surface_phase", "")),
			"surface_renderer": str(latest_action_surface_state.get("surface_renderer", "")),
			"observation": {
				"member_id": str(after.get("observation_member_id", "")),
				"channel": str(after.get("observation_channel", "")),
			},
			"reduce_motion": bool(latest_action_surface_state.get("reduce_motion", false)),
		}
		reduced_motion_render_state = authored_tell_render_state.duplicate(false)
		reduced_motion_render_state["reduce_motion"] = true
		reduced_motion_capture_state = authored_tell_capture_state.duplicate(false)
		reduced_motion_capture_state["reduce_motion"] = true
	var outcome := {
		"kind": "production_action",
		"action": action,
		"index": index,
		"attempt": ordinal,
		"limit": PRODUCTION_ACTION_LIMIT,
		"handled": handled,
		"expected_phase": expected_phase,
		"phase_passed": phase_passed,
		"elapsed_msec": action_elapsed_msec,
		"budget_msec": PRODUCTION_ACTION_BUDGET_MSEC,
		"within_budget": within_budget,
		"outcome_passed": outcome_passed,
		"after": after,
	}
	_stage("production_action_after", outcome)
	if not outcome_passed:
		_fail("Crew poker production action '%s' failed its bounded outcome: %s" % [action, JSON.stringify(outcome)])
	return outcome_passed


func _production_action_snapshot() -> Dictionary:
	var table := _table()
	var surface: Dictionary = {}
	if canvas != null:
		surface = canvas.call("realtime_surface_state") as Dictionary
	latest_action_surface_state = surface
	var observation: Dictionary = surface.get("observation", {}) if typeof(surface.get("observation", {})) == TYPE_DICTIONARY else {}
	var beat: Dictionary = table.get("beat", {}) if typeof(table.get("beat", {})) == TYPE_DICTIONARY else {}
	return {
		"table_phase": str(table.get("phase", "")),
		"surface_phase": str(surface.get("phase", "")),
		"hand_number": int(table.get("hand_number", 0)),
		"beat_present": not beat.is_empty(),
		"held": (surface.get("held", []) as Array).duplicate() if typeof(surface.get("held", [])) == TYPE_ARRAY else [],
		"observation_member_id": str(observation.get("member_id", "")),
		"observation_channel": str(observation.get("channel", "")),
	}


func _has_authored_observation() -> bool:
	_stage("natural_tell_cached_state_assertion", {"source": "verified_production_action_after"})
	var passed := authored_tell_hand_number == 0 \
		and authored_tell_table_phase == "draw" \
		and authored_tell_surface_phase == "draw" \
		and authored_tell_beat_present \
		and ["line", "portrait", "timing"].has(authored_tell_channel) \
		and CrewPokerVisualSeedAuditScript.RESIDENTS.has(authored_tell_member_id)
	acceptance_context["natural_tell"] = {
		"passed": passed,
		"hand_number": authored_tell_hand_number,
		"hand_number_contract": "zero_based_active_first_hand",
		"phase": authored_tell_table_phase,
		"surface_phase": authored_tell_surface_phase,
		"beat_present": authored_tell_beat_present,
		"member_id": authored_tell_member_id,
		"channel": authored_tell_channel,
		"input_sequence": CrewPokerVisualSeedAuditScript.INPUT_SEQUENCE.duplicate(),
		"hand_limit": 1,
	}
	acceptance_context["passed"] = bool(acceptance_context.get("passed", false)) and passed
	return passed


func _verify_session_exit_to_l3() -> void:
	app.call("back_to_environment")
	app.call("_refresh")
	await _settle(6)
	var environment_canvas := app.get("environment_canvas") as Control
	var header := app.call("current_environment_header_snapshot") as Dictionary
	var screen := app.call("current_screen_snapshot") as Dictionary
	var poker_object := _environment_interactable("game", "crew_draw_poker")
	var exit_passed := environment_canvas != null and environment_canvas.visible \
		and str(screen.get("screen", "")) == "ENVIRONMENT" \
		and str(run_state.current_environment.get("archetype_id", "")) == PUNCHLINE_ARCHETYPE_ID \
		and str(run_state.current_environment.get("current_layer_id", "")) == PUNCHLINE_BACK_ROOM_LAYER \
		and str(header.get("accessible_title", "")) == PUNCHLINE_DISPLAY_NAME \
		and not _interactable_id(poker_object).is_empty()
	acceptance_context["exit"] = {
		"method": "back_to_environment",
		"screen": str(screen.get("screen", "")),
		"archetype_id": str(run_state.current_environment.get("archetype_id", "")),
		"layer_id": str(run_state.current_environment.get("current_layer_id", "")),
		"header_title": str(header.get("accessible_title", "")),
		"poker_interactable_restored": not _interactable_id(poker_object).is_empty(),
		"passed": exit_passed,
	}
	acceptance_context["passed"] = bool(acceptance_context.get("passed", false)) and exit_passed
	if not exit_passed:
		_fail("Crew poker session exit did not return to the Punchline L3 table interactable.")


func _environment_interactable(object_type: String, source_id: String) -> Dictionary:
	var environment_canvas := app.get("environment_canvas") as Control
	if environment_canvas == null or not environment_canvas.visible or not environment_canvas.has_method("current_view_snapshot"):
		return {}
	var snapshot := environment_canvas.call("current_view_snapshot") as Dictionary
	for object_value in snapshot.get("objects", []):
		if typeof(object_value) != TYPE_DICTIONARY:
			continue
		var object_data: Dictionary = object_value
		var resolved_type := str(object_data.get("interaction_type", object_data.get("type", object_data.get("object_type", ""))))
		if resolved_type == object_type and str(object_data.get("source_id", "")) == source_id:
			return object_data.duplicate(true)
	return {}


func _interactable_id(object_data: Dictionary) -> String:
	return str(object_data.get("id", object_data.get("object_id", ""))).strip_edges()


func _capture_idle_liveness() -> void:
	canvas.call("reset_performance_counters")
	var before: Dictionary = canvas.call("debug_surface_motion_sample")
	for _frame_index in range(12):
		canvas.call("debug_advance_idle_liveness", 1.0 / 60.0)
	var after: Dictionary = canvas.call("debug_surface_motion_sample")
	var runtime: Dictionary = canvas.call("surface_runtime_status")
	var passed := before != after and int(runtime.get("surface_animation_redraw_count", 0)) > 0
	liveness_evidence = {
		"passed": passed,
		"before": before,
		"after": after,
		"redraw_count": int(runtime.get("surface_animation_redraw_count", 0)),
	}
	if not passed:
		_fail("Crew poker idle lamp motion or redraw liveness did not advance.")


func _capture_reduced_motion_stability() -> void:
	canvas.call("reset_performance_counters")
	var before: Dictionary = canvas.call("debug_surface_motion_sample")
	for _frame_index in range(12):
		canvas.call("debug_advance_idle_liveness", 1.0 / 60.0)
	var after: Dictionary = canvas.call("debug_surface_motion_sample")
	var runtime: Dictionary = canvas.call("surface_runtime_status")
	var passed := before == after \
		and int(runtime.get("surface_animation_redraw_count", 0)) == 0 \
		and bool(runtime.get("reduce_motion", false))
	reduced_motion_evidence = {
		"passed": passed,
		"before": before,
		"after": after,
		"redraw_count": int(runtime.get("surface_animation_redraw_count", 0)),
		"reduce_motion": bool(runtime.get("reduce_motion", false)),
	}
	if not passed:
		_fail("Crew poker reduced-motion renderer did not remain static.")


func _capture_surface(file_name: String, capture_id: String, expected_actions: Array, expected_card_targets: int, state_override: Dictionary = {}) -> void:
	_stage("capture_surface_redraw", {"capture_id": capture_id})
	canvas.queue_redraw()
	# `RenderingServer.frame_post_draw` can remain pending when a Windows capture
	# process is hidden. A fixed process-frame budget still gives the queued draw
	# time to land while keeping this state machine watchdog-visible and bounded.
	await _settle(3)
	if finishing:
		return
	var state: Dictionary
	if state_override.is_empty():
		_stage("capture_surface_state_read", {"capture_id": capture_id, "source": "realtime_surface_state"})
		state = canvas.call("realtime_surface_state") as Dictionary
	else:
		state = state_override
	_stage("capture_surface_view_read", {"capture_id": capture_id, "source": "current_view_snapshot"})
	var view := canvas.call("current_view_snapshot") as Dictionary
	var poker_hits := _poker_hit_regions(view.get("surface_hit_actions", []))
	_stage("capture_surface_hit_region_assertion", {"capture_id": capture_id, "source": "surface_board_size"})
	var target_evidence := _assert_hit_regions(poker_hits, expected_actions, expected_card_targets)
	var hidden_leaks: Array[Dictionary]
	if state_override.is_empty():
		hidden_leaks = _hidden_label_leaks(state)
		if capture_id == "active_draw":
			authored_tell_hidden_leaks = hidden_leaks.duplicate(true)
	else:
		hidden_leaks = authored_tell_hidden_leaks
	if not bool(target_evidence.get("passed", false)):
		_fail("Crew poker %s capture failed hit-target bounds/overlap assertions." % capture_id)
	if not hidden_leaks.is_empty():
		_fail("Crew poker %s capture exposed hidden authored labels." % capture_id)
	_stage("capture_surface_image_read", {"capture_id": capture_id, "source": "viewport_texture"})
	var image := root.get_viewport().get_texture().get_image()
	if image == null:
		_fail("Crew poker viewport capture is unavailable; run the helper windowed.")
		return
	if image.get_size() != CAPTURE_SIZE:
		image.resize(CAPTURE_SIZE.x, CAPTURE_SIZE.y, Image.INTERPOLATE_NEAREST)
	for queued_output_value in queued_capture_outputs:
		var queued_output: Dictionary = queued_output_value
		if queued_output.get("image") == image:
			_fail("Crew poker per-state capture reused a viewport Image instead of retaining a distinct render.")
			return
	# Each state owns the Image returned by its own viewport read. Keep the
	# renderer/state assertions synchronous, but defer every PNG encoder/file
	# boundary until all four states and the production exit have passed.
	queued_capture_outputs.append({
		"image": image,
		"record": {
			"id": capture_id,
			"file": file_name,
			"saved": false,
			"phase": str(state.get("phase", "")),
			"renderer": str(state.get("surface_renderer", "")),
			"hit_targets": target_evidence,
			"hidden_labels_absent": hidden_leaks.is_empty(),
			"hidden_label_offenders": hidden_leaks,
			"observation_channel": str((state.get("observation", {}) as Dictionary).get("channel", "")) if typeof(state.get("observation", {})) == TYPE_DICTIONARY else "",
			"reduce_motion": bool(state.get("reduce_motion", false)),
		},
	})


func _flush_capture_outputs() -> void:
	if queued_capture_outputs.size() != CAPTURE_FILE_NAMES.size():
		_fail("Crew poker output flush expected %d distinct queued images, found %d." % [CAPTURE_FILE_NAMES.size(), queued_capture_outputs.size()])
		return
	var flush_started_msec := Time.get_ticks_msec()
	for output_index in range(queued_capture_outputs.size()):
		if Time.get_ticks_msec() - flush_started_msec > CAPTURE_OUTPUT_BUDGET_MSEC:
			_fail("Crew poker PNG output exceeded its %d ms bounded phase before image %d." % [CAPTURE_OUTPUT_BUDGET_MSEC, output_index + 1])
			return
		var output: Dictionary = queued_capture_outputs[output_index]
		var image := output.get("image") as Image
		var record: Dictionary = output.get("record", {}) if typeof(output.get("record", {})) == TYPE_DICTIONARY else {}
		var file_name := str(record.get("file", ""))
		var capture_id := str(record.get("id", ""))
		_stage("capture_output_write", {
			"capture_id": capture_id,
			"file": file_name,
			"output_index": output_index + 1,
			"output_count": queued_capture_outputs.size(),
			"budget_msec": CAPTURE_OUTPUT_BUDGET_MSEC,
		})
		if image == null or file_name.is_empty():
			record["saved"] = false
			captures.append(record)
			_fail("Crew poker queued capture %d lost its distinct in-memory image or output name." % [output_index + 1])
			continue
		var write_started_msec := Time.get_ticks_msec()
		var error := image.save_png("%s/%s" % [OUTPUT_DIR, file_name])
		record["write_elapsed_msec"] = Time.get_ticks_msec() - write_started_msec
		record["saved"] = error == OK
		captures.append(record)
		if error != OK:
			_fail("Could not save Crew poker capture %s (error %d)." % [file_name, error])
	queued_capture_outputs.clear()
	var flush_elapsed_msec := Time.get_ticks_msec() - flush_started_msec
	if flush_elapsed_msec > CAPTURE_OUTPUT_BUDGET_MSEC:
		_fail("Crew poker PNG output exceeded its %d ms bounded phase (%d ms)." % [CAPTURE_OUTPUT_BUDGET_MSEC, flush_elapsed_msec])
		return
	_stage("capture_output_flush_complete", {
		"capture_count": captures.size(),
		"elapsed_msec": flush_elapsed_msec,
		"budget_msec": CAPTURE_OUTPUT_BUDGET_MSEC,
	})


func _assert_hit_regions(hits: Array, expected_actions: Array, expected_card_targets: int) -> Dictionary:
	var board := Rect2(Vector2.ZERO, canvas.call("surface_board_size") as Vector2)
	var actions: Array[String] = []
	var card_targets := 0
	var bounds_passed := true
	var size_passed := true
	var overlap_passed := true
	var snapshots: Array[Dictionary] = []
	for hit_value in hits:
		var hit: Dictionary = hit_value
		var rect: Rect2 = hit.get("rect", Rect2())
		var action := str(hit.get("action", ""))
		actions.append(action)
		if action == "poker_card":
			card_targets += 1
		bounds_passed = bounds_passed and rect.size.x > 0.0 and rect.size.y > 0.0 and board.encloses(rect)
		size_passed = size_passed and rect.size.x >= MIN_HIT_SIZE and rect.size.y >= MIN_HIT_SIZE
		snapshots.append({
			"action": action,
			"index": int(hit.get("index", -1)),
			"rect": {"x": rect.position.x, "y": rect.position.y, "w": rect.size.x, "h": rect.size.y},
		})
	for first_index in range(hits.size()):
		var first_rect: Rect2 = (hits[first_index] as Dictionary).get("rect", Rect2())
		for second_index in range(first_index + 1, hits.size()):
			var second_rect: Rect2 = (hits[second_index] as Dictionary).get("rect", Rect2())
			if first_rect.intersects(second_rect):
				overlap_passed = false
	var actions_passed := true
	for expected_value in expected_actions:
		actions_passed = actions_passed and actions.has(str(expected_value))
	var card_count_passed := card_targets == expected_card_targets
	return {
		"passed": bounds_passed and size_passed and overlap_passed and actions_passed and card_count_passed,
		"bounds_passed": bounds_passed,
		"minimum_size_passed": size_passed,
		"no_overlap_passed": overlap_passed,
		"expected_actions_passed": actions_passed,
		"card_target_count_passed": card_count_passed,
		"card_target_count": card_targets,
		"targets": snapshots,
	}


func _poker_hit_regions(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for hit_value in value as Array:
		if typeof(hit_value) != TYPE_DICTIONARY:
			continue
		var hit: Dictionary = hit_value
		if str(hit.get("action", "")).begins_with("poker_"):
			result.append(hit)
	return result


func _hidden_label_leaks(surface_state: Dictionary) -> Array[Dictionary]:
	# Hidden schema names must be exact dictionary keys. A substring scan would
	# incorrectly classify public fields such as `alcohol_condition` as the
	# private authored `condition` key.
	var forbidden_keys: Array[String] = ["state_key", "condition", "frequency_percent", "learned_exposures", "tell_learned"]
	var state_tokens: Array[String] = []
	var condition_tokens: Array[String] = []
	for member_id in CrewStateModelScript.MEMBER_IDS:
		for pattern_value in CrewPokerModelScript.patterns(member_id):
			if typeof(pattern_value) != TYPE_DICTIONARY:
				continue
			var pattern: Dictionary = pattern_value
			var state_token := str(pattern.get("state_key", ""))
			var condition_token := str(pattern.get("condition", ""))
			if not state_token.is_empty() and not state_tokens.has(state_token):
				state_tokens.append(state_token)
			if not condition_token.is_empty() and not condition_tokens.has(condition_token):
				condition_tokens.append(condition_token)
	var leaks: Array[Dictionary] = []
	_audit_hidden_labels(surface_state, "$", forbidden_keys, state_tokens, condition_tokens, leaks)
	return leaks


func _audit_hidden_labels(value: Variant, path: String, forbidden_keys: Array[String], state_tokens: Array[String], condition_tokens: Array[String], leaks: Array[Dictionary]) -> void:
	match typeof(value):
		TYPE_DICTIONARY:
			var source := value as Dictionary
			for raw_key in source.keys():
				var key := str(raw_key)
				var child_path := "%s.%s" % [path, key]
				if forbidden_keys.has(key):
					leaks.append({"kind": "hidden_field", "path": child_path, "token": key})
				_audit_hidden_labels(source.get(raw_key), child_path, forbidden_keys, state_tokens, condition_tokens, leaks)
		TYPE_ARRAY:
			var source := value as Array
			for index in range(source.size()):
				_audit_hidden_labels(source[index], "%s[%d]" % [path, index], forbidden_keys, state_tokens, condition_tokens, leaks)
		TYPE_STRING, TYPE_STRING_NAME:
			var text := str(value)
			# Opaque state ids are unique and remain forbidden even when accidentally
			# embedded in a longer public label. Generic authored conditions are only
			# failures when projected as their own structured/public string value.
			for token in state_tokens:
				if text.contains(token):
					leaks.append({"kind": "authored_state_token", "path": path, "token": token})
			for token in condition_tokens:
				if text == token:
					leaks.append({"kind": "authored_condition_value", "path": path, "token": token})


func _table() -> Dictionary:
	if run_state == null:
		return {}
	var states: Dictionary = run_state.current_environment.get("game_states", {}) if typeof(run_state.current_environment.get("game_states", {})) == TYPE_DICTIONARY else {}
	var value: Variant = states.get("crew_draw_poker", {})
	return value if typeof(value) == TYPE_DICTIONARY else {}


func _diagnostics_snapshot() -> Dictionary:
	return {
		"current_stage": current_stage,
		"current_attempt": current_attempt.duplicate(true),
		"stage_history": stage_history.duplicate(true),
		"failures": failure_messages.duplicate(),
		"removed_stale_capture_files": removed_stale_capture_files.duplicate(),
		"queued_capture_count": queued_capture_outputs.size(),
		"elapsed_msec": maxi(0, Time.get_ticks_msec() - started_msec) if started_msec > 0 else 0,
		"timeout_msec": CAPTURE_TIMEOUT_MSEC,
	}


func _stage(stage: String, detail: Dictionary = {}) -> void:
	if finishing:
		return
	current_stage = stage
	current_attempt = detail.duplicate(true) if detail.has("attempt") else {}
	var entry := {
		"stage": stage,
		"elapsed_msec": maxi(0, Time.get_ticks_msec() - started_msec) if started_msec > 0 else 0,
		"detail": detail.duplicate(true),
	}
	stage_history.append(entry)
	print("CREW_POKER_VISUAL_CAPTURE_STAGE stage=%s elapsed_msec=%d detail=%s" % [stage, int(entry.get("elapsed_msec", 0)), JSON.stringify(detail)])
	_write_checkpoint_manifest()


func _write_checkpoint_manifest() -> void:
	var checkpoint := {
		"tool": "crew_poker_visual_capture",
		"fixture": "The Punchline L3 Crew five-card draw production renderer",
		"capture_size": {"width": CAPTURE_SIZE.x, "height": CAPTURE_SIZE.y},
		"passed": false,
		"in_progress": not finishing,
		"captures": captures,
		"acceptance_context": acceptance_context,
		"diagnostics": _diagnostics_snapshot(),
	}
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write Crew poker visual capture diagnostic checkpoint.")
		return
	file.store_string(JSON.stringify(checkpoint, "\t") + "\n")
	file.close()


func _write_manifest() -> bool:
	var files_passed := captures.size() == 4
	var layout_and_targets_passed := captures.size() == 4
	var hidden_labels_passed := captures.size() == 4
	for capture in captures:
		files_passed = files_passed and bool(capture.get("saved", false))
		layout_and_targets_passed = layout_and_targets_passed and bool((capture.get("hit_targets", {}) as Dictionary).get("passed", false))
		hidden_labels_passed = hidden_labels_passed and bool(capture.get("hidden_labels_absent", false))
	var manifest_passed := not failed and files_passed and layout_and_targets_passed and hidden_labels_passed \
		and bool(liveness_evidence.get("passed", false)) \
		and bool(reduced_motion_evidence.get("passed", false)) \
		and bool(acceptance_context.get("passed", false))
	var manifest := {
		"tool": "crew_poker_visual_capture",
		"fixture": "The Punchline L3 Crew five-card draw production renderer",
		"capture_size": {"width": CAPTURE_SIZE.x, "height": CAPTURE_SIZE.y},
		"passed": manifest_passed,
		"in_progress": false,
		"captures": captures,
		"acceptance_context": acceptance_context,
		"diagnostics": _diagnostics_snapshot(),
		"assertions": {
			"all_pngs_saved": files_passed,
			"bounds_no_overlap_and_hit_targets": layout_and_targets_passed,
			"idle_liveness_advances": liveness_evidence,
			"reduced_motion_static": reduced_motion_evidence,
			"hidden_authored_labels_absent": hidden_labels_passed,
			"punchline_l3_header_entry_and_exit": acceptance_context,
		},
	}
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.WRITE)
	if file == null:
		failed = true
		var message := "Could not write Crew poker visual capture manifest."
		if not failure_messages.has(message):
			failure_messages.append(message)
		push_error(message)
		return false
	file.store_string(JSON.stringify(manifest, "\t") + "\n")
	file.close()
	return manifest_passed


func _watchdog() -> void:
	while not finishing:
		await create_timer(0.25).timeout
		if started_msec <= 0:
			continue
		var elapsed_msec := Time.get_ticks_msec() - started_msec
		if elapsed_msec < CAPTURE_TIMEOUT_MSEC:
			continue
		_fail("Crew poker visual capture exceeded its %d ms deadline at stage '%s' with attempt %s." % [CAPTURE_TIMEOUT_MSEC, current_stage, JSON.stringify(current_attempt)])
		_finish()
		return


func _settle(frame_count: int) -> void:
	for _index in range(frame_count):
		if finishing:
			return
		await process_frame


func _fail(message: String) -> void:
	if finishing:
		return
	failed = true
	if not failure_messages.has(message):
		failure_messages.append(message)
	print("CREW_POKER_VISUAL_CAPTURE_FAILURE stage=%s attempt=%s message=%s" % [current_stage, JSON.stringify(current_attempt), message])
	push_error(message)
	_write_checkpoint_manifest()


func _finish() -> void:
	if finishing:
		return
	finishing = true
	stage_history.append({
		"stage": "finalizing",
		"elapsed_msec": maxi(0, Time.get_ticks_msec() - started_msec) if started_msec > 0 else 0,
		"detail": {"failed": failed, "terminal_stage": current_stage},
	})
	var manifest_passed := _write_manifest()
	var exit_code := 0 if manifest_passed else 1
	print("CREW_POKER_VISUAL_CAPTURE_%s captures=%d dir=%s" % ["PASS" if exit_code == 0 else "FAIL", captures.size(), ProjectSettings.globalize_path(OUTPUT_DIR)])
	quit(exit_code)
