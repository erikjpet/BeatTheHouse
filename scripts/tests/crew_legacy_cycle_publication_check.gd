extends "res://scripts/tests/scenario_venue_cycle_captured_check.gd"

const Cycle := preload("res://scripts/core/scenario_venue_cycle.gd")
const Proof := preload("res://scripts/core/room_presentation_publication.gd")

func _run() -> void:
	if not _check(OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").contains("native-private-crew-compat-"), "private Crew compatibility root required"): _finish(); return
	var mode := OS.get_environment("BTH_CREW_COMPAT_CASE")
	var cold := OS.get_environment("BTH_CREW_COMPAT_COLD") == "1"
	if not cold: _install(OS.get_environment("BTH_CAPTURED_FIXTURE"))
	var baseline: RunState = SaveService.new().load_run("foundation_ui_autosave")
	if not _check(baseline != null, "official baseline load"): _finish(); return
	var protected := _protected(baseline)
	root.size = Vector2i(1280, 720)
	var app := Host.new(); app.continuous_environment_clock_enabled = false; app.script_prewarm_stopping = true
	root.add_child(app); app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for frame in range(3): await process_frame
	if not _check(app.load_foundation_run(), "ordinary Continue"): app.queue_free(); _finish(); return
	for frame in range(5): await process_frame
	var run: RunState = app.run_state
	facts = {"case": mode, "cold": cold, "input_fidelity": "Genuine copied pre-action states; no funds/clock/outcome injection. Warm travel uses one normal confirmation, no package handoff/loan/job accepted."}
	_check(_different_paths(protected, _protected(run)).is_empty(), "Continue preserves protected gameplay")
	_check(bool(run.validate_room_action_authority().get("ok", false)), "strict current room proof accepted")
	_check(_enabled_canvas(app) > 0 and _enabled_catalog(app) > 0, "actual published Canvas and catalog have usable controls")
	if cold:
		var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("BTH_CREW_COMPAT_EXPECTED")))
		facts["cold_protected_diff"] = _different_paths(expected.get("facts", {}).get("protected_after", {}), _protected(run))
		_check(facts.cold_protected_diff.is_empty(), "independent-process full protected state retained")
		_check(_different_paths(expected.get("facts", {}).get("cycle_after", {}), run.environment_situation_cycle("small_underground_casino")).is_empty(), "cold Continue does not select or retire another cycle")
	else:
		_metadata_controls()
		_tamper_control(run, app.library)
		if mode == "room":
			_check(run.bankroll == 34 and str(run.current_environment.get("current_layer_id", "")) == "back_room", "genuine34cash Back Room stays current")
			var casino: Dictionary = run.current_environment.get("layer_states", {}).get("casino", {})
			_check(casino.get("semantic_anchors", {}).has("env06_8_greased_exit"), "None-to-new-cycle installs authored casino anchors")
			_check(str(casino.get("scenario_state", {}).get("layer_id", "")) == "casino" and str(casino.get("scenario_id", "")) == "punchline_greased_week", "same deterministic selected Greased cycle, correct layer")
			_world_history_control(run)
			var money := run.bankroll; var rng := run.rng_state
			_check(app._enter_environment_layer("casino"), "ordinary Casino door works after compatibility migration")
			facts["casino_entry_message"] = app.message_label.text
			facts["casino_entry_actual_layer"] = run.current_environment.get("current_layer_id")
			_check(bool(run.validate_room_action_authority().get("ok", false)) and _enabled_canvas(app) > 0, "Casino remains strictly published and usable")
			_check(app._enter_environment_layer("back_room"), "ordinary return to Back Room works")
			facts["back_room_entry_message"] = app.message_label.text
			_check(run.bankroll == money and run.rng_state == rng, "internal doors change no cash or root RNG")
		else:
			_check(run.bankroll == 95 and str(run.current_environment.get("archetype_id", "")) == "delta_queen", "genuine funded Riverboat branch")
			var clock := run.game_clock_minutes
			var story_before := _travel_rows(run).size()
			var package_before := run.active_delivery_run.duplicate(true)
			var inventory_before := run.inventory.duplicate(true)
			var rep_before: Variant = run.narrative_flags.get("crew_reputation")
			_check(app.open_world_map() and app.select_world_map_node("small_underground_casino"), "normal Punchline quote selection")
			var choice: Dictionary = app._travel_choice("small_underground_casino")
			_check(bool(choice.get("enabled", false)) and int(choice.get("cost", -1)) == 21 and int(choice.get("travel_minutes", 0)) == 60, "unchanged21cash60minute quote")
			var result := app.confirm_world_map_travel()
			_check(bool(result.get("ok", false)), "one ordinary confirmation commits visited Punchline")
			_check(run.bankroll == 74 and run.game_clock_minutes == clock + 60 and run.current_world_node_id() == "small_underground_casino", "exact one fare21/time60 destination commit")
			_check(_travel_rows(run).size() == story_before + 1, "one travel history record")
			_check(run.inventory == inventory_before, "package custody not paid/replayed by travel")
			# Existing arrival Heat in the Punchline reduces standing by the same
			# applied amount. Preserve that authored penalty, not a frozen total.
			_check(run.crew_reputation() == maxi(0, int(rep_before) - 3), "existing3Heat arrival retains matching Crew standing penalty")
			_check(run.active_delivery_run.get("job_id") == package_before.get("job_id") and str(run.active_delivery_run.get("status", "")) == "active", "same active package, no delivery reward")
			_check(bool(run.validate_room_action_authority().get("ok", false)) and _enabled_catalog(app) > 0 and _enabled_canvas(app) > 0, "arrival proof/catalog/Canvas usable")
			facts["quote"] = {"cost": 21, "minutes": 60}; facts["travel_result"] = result
		app.save_foundation_run(); app.save_service.wait_for_async_save()
		var restored: RunState = SaveService.new().load_run("foundation_ui_autosave")
		_check(restored != null and _different_paths(_protected(run), _protected(restored)).is_empty(), "normal Save/fresh-service protects exact settled state")
		_check(_different_paths(run.environment_situation_cycle("small_underground_casino"), restored.environment_situation_cycle("small_underground_casino")).is_empty(), "cycle selection/retirement journal persists once")
	facts["protected_after"] = _protected(run)
	facts["cycle_after"] = run.environment_situation_cycle("small_underground_casino").duplicate(true)
	facts["cash"] = run.bankroll; facts["clock"] = run.game_clock_minutes; facts["node"] = run.current_world_node_id()
	facts["enabled_catalog"] = _enabled_catalog(app); facts["enabled_canvas"] = _enabled_canvas(app)
	app.queue_free(); await process_frame; _finish()

func _enabled_catalog(app: Host) -> int:
	var count := 0
	for row in app._interactable_object_view_list():
		if bool(row.get("enabled", false)) and str(row.get("presentation_mode", "room")) == "room" and not bool(row.get("room_geometry_rejected", false)): count += 1
	return count

func _enabled_canvas(app: Host) -> int:
	var count := 0
	for row in app.environment_canvas.foundation_scene_objects:
		if bool(row.get("interactive", false)) and not bool(row.get("disabled", false)) and not bool(row.get("decorative", false)): count += 1
	return count

func _travel_rows(run: RunState) -> Array:
	var rows: Array = []
	for value in run.story_log:
		if typeof(value) == TYPE_DICTIONARY and str(value.get("type", "")) == "travel": rows.append(value)
	return rows

func _metadata_controls() -> void:
	var definition := {"id": "synthetic_cycle", "archetype_id": "synthetic", "layer_id": "casino", "mutations": {}}
	var catalog := {"semantic_anchors": {"test_anchor": {"position": [40, 40]}}, "semantic_actors": [{"id": "test_actor"}], "semantic_zones": {"center": {"bounds": [0, 0, 100, 100]}}}
	var room := {"current_layer_id": "casino"}
	Cycle.attach(room, definition, catalog)
	_check(room.get("semantic_anchors") == catalog.semantic_anchors and room.get("semantic_actors") == catalog.semantic_actors, "new target cycle owns fresh authored anchor/actor context")
	room.semantic_anchors.test_anchor.position[0] = 99
	_check(catalog.semantic_anchors.test_anchor.position[0] == 40, "new room context never aliases content catalog")
	var elsewhere := {"current_layer_id": "back_room"}
	Cycle.attach(elsewhere, definition, catalog)
	_check(not elsewhere.has("semantic_anchors") and int(elsewhere.get("scenario_applied_phase_index", 0)) == -1, "wrong floor carries cursor without spawning target geometry")
	var none := {"current_layer_id": "casino"}; Cycle.attach(none, {}, catalog)
	_check(not none.has("scenario_id") and not none.has("semantic_anchors"), "None remains no scenario without expanded metadata")

func _world_history_control(run: RunState) -> void:
	var control := RunState.new(); control.from_dict(run.to_dict())
	control.current_environment = run.current_environment.duplicate(true)
	var ids: Array = control.current_environment.get("resolved_event_ids", []).duplicate(true)
	if not ids.has("side_door"): ids.append("side_door")
	control.current_environment["resolved_event_ids"] = ids
	var snapshot := control.current_environment.duplicate(true)
	var base := control._scenario_authoritative_environment_for_finalization({})
	_check(not base.get("event_ids", []).has("side_door"), "synthetic shared Club resolution cannot invent a Back Room door")
	_check(base.get("event_ids", []).has("crew_job_board"), "current physical Crew host remains in world-only baseline")
	_check(control.current_environment == snapshot, "detached baseline reader does not mutate actual room/journal")
	var primary := control._scenario_authoritative_environment_for_finalization({"id": "synthetic_new_primary"})
	_check(not primary.get("event_ids", []).has("side_door"), "new primary seal also excludes foreign resolved history")
	var owned: Array = control.current_environment.get("event_ids", []).duplicate(true)
	owned.erase("crew_job_board")
	control.current_environment["event_ids"] = owned
	control.current_environment["resolved_event_ids"] = ["crew_job_board", "side_door"]
	var restored_owned := control._scenario_authoritative_environment_for_finalization({})
	_check(restored_owned.get("event_ids", []).has("crew_job_board") and not restored_owned.get("event_ids", []).has("side_door"), "manifest-owned consumed member can reconstruct without inventing foreign event")

func _tamper_control(run: RunState, library: ContentLibrary) -> void:
	var env := run.current_environment.duplicate(true)
	env["layout"]["slot_binding_digest"] = "untrusted-test-digest"
	_check(not bool(Proof.validate(env).get("ok", true)), "strict slot-digest tamper still rejected")
	var control := RunState.new(); control.from_dict(run.to_dict())
	control.current_environment = env
	var rejected := control.scenario_finalize_installed_environment(library)
	_check(not bool(rejected.get("ok", true)), "finalization cannot repair an edited incoming binding proof")
