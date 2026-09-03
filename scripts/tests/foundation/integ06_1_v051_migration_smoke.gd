extends SceneTree

# Current-build admission check for every genuine historical fixture named by
# the capture plan. It verifies the provenance sidecar and source bytes before
# loading, then exercises FoundationMain's public load/save boundary and checks
# that the migrated state is stable after a round trip.

const MainScene := preload("res://scenes/main.tscn")
const FIXTURE_ROOT := "res://scripts/tests/fixtures/integ06_1/v0_5_1"
const PLAN_PATH := FIXTURE_ROOT + "/capture_plan.json"
const SLOT_ID := "integ06_1_v051_migration_matrix"
const HISTORICAL_COMMIT := "f1ce7ec814b5034c229f53dcc0db6e799aaaee0b"
const HISTORICAL_TREE := "19c5ed82c0d2d2390dab2b9b6662c70d8aed5d0d"
const HISTORICAL_MAIN_SCENE_BLOB := "4b0643365098308dadfaee909d35e51784905811"
const HISTORICAL_FOUNDATION_MAIN_BLOB := "3bc98efec993b8bfdd9252687a0ba041ebba7f23"
const HISTORICAL_SAVE_SERVICE_BLOB := "57a6526016123feb9bcf1ebeb50cc8f937f0b265"
const DRIVER_PATH := "res://scripts/tests/foundation/integ06_1_v051_fixture_driver.gd"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var app: Control = MainScene.instantiate()
	app.set("continuous_environment_clock_enabled", false)
	app.set("autosave_slot_id", SLOT_ID)
	root.add_child(app)
	await process_frame
	await process_frame
	var save_service: Variant = app.get("save_service")
	if save_service == null:
		_fail("current FoundationMain did not expose SaveService")
		return
	var cases := _load_capture_cases()
	if cases.is_empty():
		_fail("capture plan did not contain any fixtures")
		return
	var verified := 0
	for case_value in cases:
		if typeof(case_value) != TYPE_DICTIONARY:
			_fail("capture plan contained a non-dictionary case")
			return
		if not await _verify_fixture(app, save_service, case_value as Dictionary):
			return
		verified += 1
	print("integ06_1 v0.5.1 migration matrix passed fixtures=%d provenance=verified source=FoundationMain round_trip=stable" % verified)
	app.queue_free()
	await process_frame
	quit(0)


func _verify_fixture(app: Control, save_service: Variant, capture_case: Dictionary) -> bool:
	var fixture_id := str(capture_case.get("fixture_id", "")).strip_edges()
	var expected_seed := str(capture_case.get("seed", "")).strip_edges()
	var expected_archetype := str(capture_case.get("expected_archetype", "")).strip_edges()
	var expected_game := str(capture_case.get("enter_game", "")).strip_edges()
	if fixture_id.is_empty() or expected_seed.is_empty() or expected_archetype.is_empty():
		_fail("capture plan case omitted fixture_id, seed, or expected_archetype")
		return false
	var fixture_path := "%s/%s.json" % [FIXTURE_ROOT, fixture_id]
	var provenance_path := "%s/%s.provenance.json" % [FIXTURE_ROOT, fixture_id]
	var fixture_bytes := FileAccess.get_file_as_bytes(fixture_path)
	var provenance := _load_json_dictionary(provenance_path)
	var envelope := _parse_bytes_dictionary(fixture_bytes)
	if fixture_bytes.is_empty() or provenance.is_empty() or envelope.is_empty():
		_fail("%s fixture, provenance, or envelope was unreadable" % fixture_id)
		return false
	if not _valid_provenance(provenance, capture_case, fixture_id, expected_seed, expected_archetype, expected_game, fixture_bytes, envelope):
		return false

	app.set("autosave_slot_id", SLOT_ID)
	if int(save_service.call("clear_run", SLOT_ID)) != OK:
		_fail("%s could not clear isolated migration slot" % fixture_id)
		return false
	var absolute_destination := ProjectSettings.globalize_path(str(save_service.call("run_save_path", SLOT_ID)))
	if DirAccess.make_dir_recursive_absolute(absolute_destination.get_base_dir()) != OK:
		_fail("%s could not create isolated save directory" % fixture_id)
		return false
	var output := FileAccess.open(absolute_destination, FileAccess.WRITE)
	if output == null:
		_fail("%s could not stage historical fixture at SaveService path" % fixture_id)
		return false
	output.store_buffer(fixture_bytes)
	output.close()

	app.call("load_foundation_run")
	await process_frame
	await process_frame
	var run_state: Variant = app.get("run_state")
	if not _expected_playable_state(run_state, expected_seed, expected_archetype):
		_fail("%s current FoundationMain did not migrate the historical state intact" % fixture_id)
		return false
	app.call("save_foundation_run")
	if int(save_service.call("wait_for_async_save")) != OK:
		_fail("%s current FoundationMain could not round-trip the migrated save" % fixture_id)
		return false
	# The public save boundary legitimately checkpoints presentation-owned music
	# and surface state into RunState. Compare against that post-checkpoint state,
	# which is the exact state the SaveService serialized.
	var migrated_snapshot := JSON.stringify(_migration_contract(run_state))
	var reloaded: Variant = save_service.call("load_run", SLOT_ID)
	if not _expected_playable_state(reloaded, expected_seed, expected_archetype):
		_fail("%s round-tripped migration did not reload to the same playable state" % fixture_id)
		return false
	if JSON.stringify(_migration_contract(reloaded)) != migrated_snapshot:
		_fail("%s migrated gameplay contract changed across the current save/load boundary" % fixture_id)
		return false
	if int(save_service.call("clear_run", SLOT_ID)) != OK:
		_fail("%s could not clear isolated migration slot after PASS" % fixture_id)
		return false
	print("INTEG06_1_MIGRATION_PASS=%s archetype=%s game=%s" % [fixture_id, expected_archetype, expected_game if not expected_game.is_empty() else "none"])
	return true


func _valid_provenance(provenance: Dictionary, capture_case: Dictionary, fixture_id: String, expected_seed: String, expected_archetype: String, expected_game: String, fixture_bytes: PackedByteArray, envelope: Dictionary) -> bool:
	var capture: Dictionary = provenance.get("capture", {}) if typeof(provenance.get("capture", {})) == TYPE_DICTIONARY else {}
	var expected_modifiers: Dictionary = capture_case.get("challenge_modifiers", {}).duplicate(true) if typeof(capture_case.get("challenge_modifiers", {})) == TYPE_DICTIONARY else {}
	var expected_challenge_id := str(capture_case.get("challenge_id", "integ06_1_historical_fixture")).strip_edges() if not expected_modifiers.is_empty() else ""
	var expected_methods: Array[String] = []
	if not expected_modifiers.is_empty():
		expected_methods.append("RunState.custom_challenge")
	expected_methods.append("FoundationMain.start_foundation_run")
	var expected_travel_path: Array[String] = []
	var steps: Array = capture_case.get("steps", []) if typeof(capture_case.get("steps", [])) == TYPE_ARRAY else []
	if steps.is_empty():
		for target_id in _string_array(capture_case.get("travel_path", [])):
			steps.append({"type": "travel", "target": target_id})
	for step_value in steps:
		if typeof(step_value) != TYPE_DICTIONARY:
			continue
		var step: Dictionary = step_value
		var step_type := str(step.get("type", ""))
		if step_type == "travel":
			var target_id := str(step.get("target", ""))
			expected_travel_path.append(target_id)
			expected_methods.append("FoundationMain.select_travel_option:%s" % target_id)
			expected_methods.append("FoundationMain.confirm_selected_travel")
		elif step_type == "event":
			expected_methods.append("FoundationMain.select_event_choice:%s:%s" % [str(step.get("event_id", "")), str(step.get("choice_id", ""))])
			expected_methods.append("FoundationMain.confirm_selected_event_choice")
		elif step_type == "lender":
			expected_methods.append("FoundationMain.use_lender_hook:%s" % str(step.get("lender_id", "")))
	if not expected_game.is_empty():
		expected_methods.append("FoundationMain.enter_game")
	expected_methods.append("FoundationMain.save_foundation_run")
	expected_methods.append("SaveService.wait_for_async_save")
	var actual_methods := _string_array(capture.get("methods", []))
	var expected_hash := str(provenance.get("save_sha256", "")).to_lower()
	var hash_context := HashingContext.new()
	hash_context.start(HashingContext.HASH_SHA256)
	hash_context.update(fixture_bytes)
	var actual_hash := hash_context.finish().hex_encode().to_lower()
	var failures: Array[String] = []
	if str(provenance.get("schema", "")) != "beat_the_house.integ06_1_historical_fixture_provenance" or int(provenance.get("version", 0)) != 1:
		failures.append("wrong provenance schema/version")
	if str(provenance.get("historical_release", "")) != "v0.5.1" or str(provenance.get("historical_commit", "")) != HISTORICAL_COMMIT or str(provenance.get("historical_tree", "")) != HISTORICAL_TREE:
		failures.append("wrong historical source identity")
	if str(provenance.get("historical_main_scene_blob", "")) != HISTORICAL_MAIN_SCENE_BLOB or str(provenance.get("historical_foundation_main_blob", "")) != HISTORICAL_FOUNDATION_MAIN_BLOB or str(provenance.get("historical_save_service_blob", "")) != HISTORICAL_SAVE_SERVICE_BLOB:
		failures.append("wrong historical runtime blob identity")
	if str(provenance.get("driver_path", "")) != DRIVER_PATH.trim_prefix("res://") or str(provenance.get("driver_sha256", "")).to_lower() != _file_sha256(DRIVER_PATH):
		failures.append("fixture driver identity mismatch")
	if str(provenance.get("fixture_id", "")) != fixture_id or str(provenance.get("save_file", "")) != "%s.json" % fixture_id:
		failures.append("fixture identity mismatch")
	if int(provenance.get("save_size_bytes", -1)) != fixture_bytes.size() or expected_hash != actual_hash:
		failures.append("fixture byte hash/size mismatch")
	if str(envelope.get("schema", "")) != "beat_the_house.foundation_run" or int(envelope.get("version", 0)) != 2 or str(envelope.get("slot_id", "")) != fixture_id:
		failures.append("historical save envelope mismatch")
	if str(capture.get("fixture_id", "")) != fixture_id or str(capture.get("seed", "")) != expected_seed or str(capture.get("archetype_id", "")) != expected_archetype:
		failures.append("capture identity mismatch")
	if JSON.stringify(capture.get("challenge_modifiers", {})) != JSON.stringify(expected_modifiers):
		failures.append("capture challenge modifiers mismatch")
	if str(capture.get("challenge_id", "")) != expected_challenge_id:
		failures.append("capture challenge identity mismatch")
	if str(capture.get("project_version", "")) != "0.5.1" or str(capture.get("save_schema", "")) != "beat_the_house.foundation_run" or int(capture.get("save_version", 0)) != 2:
		failures.append("capture release/save mismatch")
	if str(capture.get("game_id", "")) != expected_game or str(capture.get("game_state_key", "")) != expected_game:
		failures.append("capture game identity mismatch")
	if _string_array(capture.get("travel_path", [])) != expected_travel_path:
		failures.append("capture travel path mismatch")
	if actual_methods != expected_methods:
		failures.append("public-call transcript mismatch")
	if not failures.is_empty():
		_fail("%s provenance rejection: %s" % [fixture_id, ", ".join(failures)])
		return false
	return true


func _expected_playable_state(run_state: Variant, expected_seed: String, expected_archetype: String) -> bool:
	if run_state == null:
		return false
	var environment: Dictionary = run_state.get("current_environment")
	var world_map: Dictionary = run_state.get("world_map")
	return str(run_state.get("seed_text")) == expected_seed \
		and str(run_state.get("run_status")) == "active" \
		and str(environment.get("archetype_id", "")) == expected_archetype \
		and not world_map.is_empty()


func _migration_contract(run_state: Variant) -> Dictionary:
	var environment: Dictionary = run_state.get("current_environment")
	var world_map: Dictionary = run_state.get("world_map")
	return {
		"seed_text": str(run_state.get("seed_text")),
		"run_status": str(run_state.get("run_status")),
		"bankroll": run_state.get("bankroll"),
		"game_clock_minutes": run_state.get("game_clock_minutes"),
		"act": run_state.get("act"),
		"environment_id": str(environment.get("id", "")),
		"archetype_id": str(environment.get("archetype_id", "")),
		"game_ids": environment.get("game_ids", []).duplicate(true),
		"game_states": environment.get("game_states", {}).duplicate(true),
		"debt": run_state.get("debt").duplicate(true),
		"story_log": run_state.get("story_log").duplicate(true),
		"world_current_node_id": str(world_map.get("current_node_id", "")),
		"world_visited_path": world_map.get("visited_path", []).duplicate(true),
	}


func _load_capture_cases() -> Array:
	var plan := _load_json_dictionary(PLAN_PATH)
	var cases: Variant = plan.get("cases", [])
	if typeof(cases) != TYPE_ARRAY:
		return []
	var sequences: Dictionary = plan.get("step_sequences", {}) if typeof(plan.get("step_sequences", {})) == TYPE_DICTIONARY else {}
	var expanded: Array = []
	for case_value in cases as Array:
		if typeof(case_value) != TYPE_DICTIONARY:
			expanded.append(case_value)
			continue
		var capture_case: Dictionary = (case_value as Dictionary).duplicate(true)
		var sequence_id := str(capture_case.get("step_sequence", "")).strip_edges()
		if not sequence_id.is_empty() and typeof(sequences.get(sequence_id, [])) == TYPE_ARRAY:
			var resolved_steps: Array = (sequences.get(sequence_id, []) as Array).duplicate(true)
			if typeof(capture_case.get("append_steps", [])) == TYPE_ARRAY:
				resolved_steps.append_array((capture_case.get("append_steps", []) as Array).duplicate(true))
			capture_case["steps"] = resolved_steps
		expanded.append(capture_case)
	return expanded


func _load_json_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return (parsed as Dictionary).duplicate(true) if typeof(parsed) == TYPE_DICTIONARY else {}


func _parse_bytes_dictionary(bytes: PackedByteArray) -> Dictionary:
	if bytes.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	return (parsed as Dictionary).duplicate(true) if typeof(parsed) == TYPE_DICTIONARY else {}


func _file_sha256(path: String) -> String:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return ""
	var hash_context := HashingContext.new()
	hash_context.start(HashingContext.HASH_SHA256)
	hash_context.update(bytes)
	return hash_context.finish().hex_encode().to_lower()


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value as Array:
		var text := str(entry).strip_edges()
		if not text.is_empty():
			result.append(text)
	return result


func _fail(message: String) -> void:
	push_error("integ06_1 v0.5.1 migration smoke failed: %s" % message)
	quit(1)
