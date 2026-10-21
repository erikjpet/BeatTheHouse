extends SceneTree

# Two finite stages over fixed synthetic bundles, each in fresh private user://.
# The parent owns engine admission, OS limits and the external deadline.
const INPUT_SLOT := "punchline_cold_input_disposable"
const STAGES := ["punchline_cold_legacy", "punchline_cold_resaved"]
const EVENT_ID := "scenario_debt_court_office_hours"
const CHOICE_ID := "watch_the_next_name"

var failures: Array[String] = []
var observations: Dictionary = {"fixture": "Punchline synthetic only; no user save"}
var stage := ""
var fixture_root := ""
var bundle := ""
var input_hashes: Dictionary = {}
var metadata: Dictionary = {}
var raw_signature: Dictionary = {}
var watch_fact_id := ""
var app: Control
var run: RunState
var codec: Script
var controller: Script
var binder: Script
var manifest_script: Script
var finished := false


func _init() -> void:
	# FIRST operation, before loading scenes or constructing run/profile authority.
	var actual := ProjectSettings.globalize_path("user://")
	var expected := OS.get_environment("BTH_SCRATCH_REPRO_USER_DIR")
	observations["resolved_user_dir"] = actual
	if expected.is_empty() or _canonical(actual) != _canonical(expected):
		push_error("REFUSED: disposable user directory mismatch")
		quit(64)
		return
	stage = OS.get_environment("BTH_SCRATCH_REGRESSION_STAGE")
	fixture_root = OS.get_environment("BTH_SCRATCH_FIXTURE_ROOT").replace("\\", "/").simplify_path().trim_suffix("/")
	var allowed_root := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir().path_join("repro-fixtures")
	if not STAGES.has(stage) or not OS.get_cmdline_user_args().has("--punchline-repro-authorized") \
			or OS.get_environment("BTH_SCRATCH_REPRO_REPORT").is_empty() \
			or not (_canonical(fixture_root) == _canonical(allowed_root) or _canonical(fixture_root).begins_with(_canonical(allowed_root) + "/")):
		push_error("REFUSED: explicit Punchline stage, authorization, fixture root and report required")
		quit(64)
		return
	observations["stage"] = stage
	call_deferred("_run")


func _run() -> void:
	create_timer(45.0).timeout.connect(func() -> void:
		if not finished:
			failures.append("In-engine 45s deadline expired; setup/timeout failure")
			_finish(124)
	)
	codec = load("res://scripts/core/run_save_codec.gd")
	controller = load("res://scripts/ui/environment_interaction_controller.gd")
	binder = load("res://scripts/core/environment_slot_binder.gd")
	manifest_script = load("res://scripts/core/environment_object_manifest.gd")
	bundle = fixture_root.path_join("punchline_old_pending" if stage == "punchline_cold_legacy" else "punchline_resaved")
	var payload := _install_private_bundle()
	if payload.is_empty():
		_finish()
		return
	# Inspect the untouched codec-shaped state before any RunState or view repair.
	var raw: Dictionary = codec.decode(codec.unpack_from_storage(payload.get("run_state", {})))
	if not _check(not raw.is_empty(), "Fixed synthetic fixture codec decode failed"):
		_finish()
		return
	var raw_environment: Dictionary = raw.get("current_environment", {})
	raw_signature = _state_signature(raw)
	observations["raw_signature"] = raw_signature
	var proof_environment := raw_environment.duplicate(false)
	proof_environment["object_manifest"] = manifest_script.normalize_persisted(raw_environment.get("object_manifest", {}))
	var raw_proof: Dictionary = binder.validate_base_layout_authority(proof_environment)
	observations["raw_first_base_authority"] = _result_summary(raw_proof)
	# A sealed scenario must retain its raw authority before restore. Ordinary
	# casino placement is a derived cache: normal from_dict/Continue validates
	# and rebuilds it, then _check_room requires the strict published join.
	var raw_authority_required := stage == "punchline_cold_legacy"
	observations["raw_base_authority_required"] = raw_authority_required
	if raw_authority_required:
		_check(bool(raw_proof.get("ok", false)), "Raw fixed fixture base authority rejected")
	else:
		_check(int(raw_signature.get("semantic_version", 0)) == 0 and str(raw_signature.get("semantic_digest", "")).is_empty(), "Resaved ordinary casino unexpectedly carries a current scenario seal")
		_check((raw_environment.get("scenario_sequence_state", {}) as Dictionary).is_empty() and str(raw_environment.get("scenario_sequence_pending_visit_id", "")).is_empty(), "Resaved casino unexpectedly contains a current scenario")
	_check(str(raw.get("run_status", "")) == RunState.RUN_STATUS_ACTIVE, "Fixed fixture was already terminal; this test must not revive failed runs")
	var queued := _queued_watch(_watch_holder(raw_environment))
	observations["raw_pending_watch"] = queued.duplicate(true)
	if stage == "punchline_cold_legacy":
		_check(queued.size() == 1, "Legacy fixture must contain exactly one pending ordinary Watch fact")
		if queued.size() == 1:
			watch_fact_id = str((queued[0] as Dictionary).get("fact_id", ""))
			_check(str(((queued[0] as Dictionary).get("payload", {}) as Dictionary).get("resolution_id", "")).is_empty(), "Legacy Watch fact unexpectedly has bridge correlation")
		_check(str(raw_signature.get("layer", "")) == "club" and str(raw_signature.get("phase", "")) == "arrival", "Legacy fixture is not the club arrival state")
		_check(str(raw_signature.get("semantic_digest", "")) == str(metadata.get("expected_semantic_digest", "")) and int(raw_signature.get("semantic_version", 0)) == int(metadata.get("expected_semantic_version", 0)), "Legacy metadata lost the exact original semantic seal")
	else:
		watch_fact_id = str(metadata.get("watch_fact_id", ""))
		_check(queued.is_empty() and str(raw_signature.get("layer", "")) == "casino", "Resaved fixture is not the completed casino entry")
		_check(not watch_fact_id.is_empty() and _watch_receipt_ids(_watch_holder(raw_environment)).count(watch_fact_id) == 1, "Resaved fixture lacks exactly one original Watch receipt")
	if not failures.is_empty():
		_finish()
		return
	var scene: PackedScene = load("res://scenes/main.tscn")
	app = scene.instantiate()
	app.set("continuous_environment_clock_enabled", false)
	app.set("autosave_slot_id", INPUT_SLOT)
	root.add_child(app)
	await process_frame
	await process_frame
	var loaded := bool(app.call("load_foundation_run"))
	for _frame in range(4):
		await process_frame
	run = app.get("run_state")
	observations["continue_loaded"] = loaded
	if not _check(loaded and run != null, "Normal Continue rejected fixed synthetic fixture"):
		_finish()
		return
	observations["continued_signature"] = _state_signature(run.to_dict())
	_check(_state_signature(run.to_dict()) == raw_signature, "Continue changed cash, clock, RNG, queued Watch, receipts or semantic seal")
	_check_room("cold_continue")
	if failures.is_empty():
		if stage == "punchline_cold_legacy":
			await _exercise_legacy_recovery()
		else:
			var before_ids := _watch_receipt_ids(_watch_holder(run.current_environment))
			await _exercise_real_game()
			_check(_queued_watch(_watch_holder(run.current_environment)).is_empty(), "Resaved Continue recreated a pending Watch fact")
			_check(_watch_receipt_ids(_watch_holder(run.current_environment)) == before_ids and before_ids.count(watch_fact_id) == 1, "Resaved Continue duplicated or lost the original Watch receipt")
			_check_room("resaved_after_game")
	_finish()


func _install_private_bundle() -> Dictionary:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(bundle.path_join("metadata.json")))
	if not _check(typeof(value) == TYPE_DICTIONARY, "Fixed fixture metadata missing or malformed"):
		return {}
	metadata = value
	var companions := {"save.json": "save_sha256", "save.json.bak": "backup_sha256", "crew-authority.bin": "authority_sha256", "profile_inventory.json": "profile_sha256", "profile_inventory.json.bak": "profile_backup_sha256"}
	for name in companions:
		var source := bundle.path_join(name)
		if not FileAccess.file_exists(source) and name not in ["save.json", "crew-authority.bin"]:
			continue
		var expected := str(metadata.get(companions[name], ""))
		var actual := FileAccess.get_sha256(source)
		_check(not expected.is_empty() and actual == expected, "Fixed fixture companion hash mismatch: " + name)
		input_hashes[name] = actual
	var input := FileAccess.open(bundle.path_join("save.json"), FileAccess.READ)
	if not _check(input != null and input.get_length() <= 32 * 1024 * 1024, "Fixed fixture save missing or above size bound"):
		return {}
	var parsed: Variant = JSON.parse_string(input.get_as_text())
	input.close()
	_check(typeof(parsed) == TYPE_DICTIONARY, "Fixed fixture JSON is invalid")
	var user_dir := ProjectSettings.globalize_path("user://")
	var distribution := OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").replace("\\", "/").simplify_path().trim_suffix("/")
	var saves := distribution.path_join("saves")
	if not _check(_canonical(distribution).begins_with(_canonical(user_dir) + "/"), "Distribution path escaped private user directory"):
		return {}
	for name in input_hashes:
		var target := user_dir.path_join(".crew_host_authority_v1") if name == "crew-authority.bin" else saves.path_join(INPUT_SLOT + (".json.bak" if name == "save.json.bak" else ".json")) if name.begins_with("save.json") else distribution.path_join(name)
		_check(not FileAccess.file_exists(target), "Cold stage requires fresh private companion paths: " + name)
	if not failures.is_empty():
		return {}
	if not _check(DirAccess.make_dir_recursive_absolute(saves) == OK, "Could not create private saves directory"):
		return {}
	for name in input_hashes:
		var target := user_dir.path_join(".crew_host_authority_v1") if name == "crew-authority.bin" else saves.path_join(INPUT_SLOT + (".json.bak" if name == "save.json.bak" else ".json")) if name.begins_with("save.json") else distribution.path_join(name)
		_check(DirAccess.copy_absolute(bundle.path_join(name), target) == OK and FileAccess.get_sha256(target) == str(input_hashes[name]), "Private companion copy failed or changed bytes: " + name)
	observations["input_hashes"] = input_hashes.duplicate(true)
	return parsed as Dictionary if failures.is_empty() else {}


func _exercise_legacy_recovery() -> void:
	var before_cash := run.bankroll
	var turn := run.advance_environment_turns(1)
	observations["one_normal_turn"] = _result_summary(turn)
	_check(bool(turn.get("ok", false)), "One normal turn could not flush the legacy pending Watch fact")
	var after_ids := _watch_receipt_ids(_watch_holder(run.current_environment))
	_check(_queued_watch(_watch_holder(run.current_environment)).is_empty() and after_ids.count(watch_fact_id) == 1, "Legacy Watch did not settle exactly once")
	_check(run.bankroll == before_cash, "Legacy Watch flush changed cash")
	var extra_flush := run.scenario_flush_facts()
	observations["one_extra_flush"] = _result_summary(extra_flush)
	_check(bool(extra_flush.get("ok", false)) and _watch_receipt_ids(_watch_holder(run.current_environment)) == after_ids and run.bankroll == before_cash, "Extra flush duplicated the Watch receipt or cash")
	app.call("_refresh")
	await process_frame
	_check_room("after_legacy_flush")
	if not failures.is_empty():
		return
	var canvas: Control = app.get("environment_canvas")
	var chair_id := "scenario::punchline_debt_court_hearing_chairs"
	canvas.call("set_selected_object", chair_id)
	var chair: Dictionary = canvas.call("_scene_object", chair_id)
	observations["rendered_chair_action"] = {"label": str(canvas.call("_selected_info_action_label", chair)), "confirm_action_id": str(chair.get("confirm_action_id", "")), "enabled": bool(canvas.call("_selected_info_single_action_enabled", chair))}
	if not _check(str(canvas.call("_selected_info_action_label", chair)).to_lower() == "form hearing aisle" and bool(canvas.call("_selected_info_single_action_enabled", chair)), "Real rendered chairs lack enabled Form Hearing Aisle action"):
		return
	if not _check(bool(canvas.call("_activate_selected_info_action_by_index")), "Real selected chair button refused activation"):
		return
	await process_frame
	await process_frame
	var deadline := Time.get_ticks_msec() + 5000
	while bool(app.get("scenario_sequence_action_pending")) and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(not bool(app.get("scenario_sequence_action_pending")), "Deferred chair action did not release within 5s")
	_check(str((run.current_environment.get("scenario_sequence_state", {}) as Dictionary).get("phase_id", "")) == "work_1", "Real chair action did not reach work_1")
	_check_room("after_chair")
	if not failures.is_empty():
		return
	if not _check(bool(app.call("activate_interactable_object", "event:side_door")), "Real Side Door event refused opening"):
		return
	var entered: Dictionary = app.call("resolve_event_choice", "side_door", "punchline_password")
	observations["side_door_host_result"] = _result_summary(entered)
	await process_frame
	await process_frame
	_check(bool(entered.get("ok", false)) and str(run.current_environment.get("current_layer_id", "")) == "casino", "Real free Side Door response did not enter casino")
	_check(run.bankroll == before_cash, "Free witness/chair/Side Door sequence changed cash")
	_check(_queued_watch(_watch_holder(run.current_environment)).is_empty() and _watch_receipt_ids(_watch_holder(run.current_environment)).count(watch_fact_id) == 1, "Casino entry lost or duplicated Watch settlement")
	_check_room("casino_entry")
	if not failures.is_empty():
		return
	await _exercise_real_game()
	if not failures.is_empty():
		return
	# Invoke the same normal Save handler as the UI, then verify its disk result.
	app.call("save_foundation_run")
	await process_frame
	await process_frame
	var save_service: RefCounted = app.get("save_service")
	var saved_path := str(save_service.call("run_save_path", INPUT_SLOT))
	var saved_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(saved_path))
	if not _check(typeof(saved_value) == TYPE_DICTIONARY, "Normal host Save produced no valid private checkpoint"):
		return
	var saved_raw: Dictionary = codec.decode(codec.unpack_from_storage((saved_value as Dictionary).get("run_state", {})))
	_check(_state_signature(saved_raw) == _state_signature(run.to_dict()), "Normal host Save did not persist the current exact public signature")
	if failures.is_empty():
		_export_resaved_bundle(saved_path, saved_raw)


func _exercise_real_game() -> void:
	var before_cash := run.bankroll
	var accepted := false
	for object_data in _enabled_objects():
		var object_id := str(object_data.get("id", ""))
		if object_id.begins_with("game:"):
			accepted = bool(app.call("activate_interactable_object", object_id))
			observations["other_real_room_game"] = object_id
			break
	_check(accepted and str(app.get("current_screen")) == "GAME", "Another actual rendered casino game refused entry")
	if accepted:
		app.call("back_to_environment")
		await process_frame
		await process_frame
	_check(run.bankroll == before_cash, "Opening/backing from another game changed cash")


func _export_resaved_bundle(saved_path: String, saved_raw: Dictionary) -> void:
	var output := fixture_root.path_join("punchline_resaved")
	if not _check(not DirAccess.dir_exists_absolute(output), "Refusing to overwrite existing resaved or original fixture bundle"):
		return
	if not _check(DirAccess.make_dir_recursive_absolute(output) == OK, "Could not create NEW synthetic resaved bundle"):
		return
	var distribution := OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT")
	var sources := {"save.json": saved_path, "crew-authority.bin": ProjectSettings.globalize_path("user://.crew_host_authority_v1"), "save.json.bak": saved_path + ".bak", "profile_inventory.json": distribution.path_join("profile_inventory.json"), "profile_inventory.json.bak": distribution.path_join("profile_inventory.json.bak")}
	var hash_keys := {"save.json": "save_sha256", "crew-authority.bin": "authority_sha256", "save.json.bak": "backup_sha256", "profile_inventory.json": "profile_sha256", "profile_inventory.json.bak": "profile_backup_sha256"}
	var out_metadata := {"kind": "synthetic_punchline_resaved", "slot_id": INPUT_SLOT, "watch_fact_id": watch_fact_id, "expected_semantic_digest": str(raw_signature.get("semantic_digest", "")), "expected_semantic_version": int(raw_signature.get("semantic_version", 0)), "public_signature": _state_signature(saved_raw)}
	for name in sources:
		var source := str(sources[name])
		if not FileAccess.file_exists(source) and name not in ["save.json", "crew-authority.bin"]:
			continue
		_check(DirAccess.copy_absolute(source, output.path_join(name)) == OK, "Could not preserve resaved companion: " + name)
		var digest := FileAccess.get_sha256(output.path_join(name))
		_check(not digest.is_empty() and digest == FileAccess.get_sha256(source), "Resaved companion copy was not byte-identical: " + name)
		out_metadata[hash_keys[name]] = digest
	var file := FileAccess.open(output.path_join("metadata.json"), FileAccess.WRITE)
	if _check(file != null, "Could not write NEW resaved fixture metadata"):
		file.store_string(JSON.stringify(out_metadata))
		file.close()
	observations["resaved_metadata"] = out_metadata


func _check_room(label: String) -> void:
	var proof: Dictionary = controller._object_manifest_join_proof(run.current_environment.duplicate(true))
	observations[label] = {"strict_join": _result_summary(proof), "run_status": run.run_status, "failure_reason": run.run_failure_reason, "current_screen": str(app.get("current_screen")), "enabled_objects": _enabled_objects().size(), "signature": _state_signature(run.to_dict())}
	_check(not run.is_terminal() and run.run_status == RunState.RUN_STATUS_ACTIVE, label + " became terminal")
	_check(bool(proof.get("ok", false)), label + " failed strict room authority")
	_check(not _enabled_objects().is_empty(), label + " published an empty room")
	if run.scenario_sequence_present():
		_check(bool(run.call("_scenario_semantic_ready")), label + " lost active scenario semantic authority")
	if str(run.current_environment.get("current_layer_id", "")) == "club":
		_check(str(run.current_environment.get("scenario_semantic_digest", "")) == str(raw_signature.get("semantic_digest", "")) and int(run.current_environment.get("scenario_semantic_inventory_version", 0)) == int(raw_signature.get("semantic_version", 0)), label + " changed original club semantic seal")


func _watch_holder(environment: Dictionary) -> Dictionary:
	return environment if str(environment.get("current_layer_id", "")) == "club" else (environment.get("layer_states", {}) as Dictionary).get("club", {})


func _is_watch(fact: Dictionary) -> bool:
	var payload: Dictionary = fact.get("payload", {})
	return str(fact.get("fact_type", "")) == "event_result" and str(payload.get("event_id", "")) == EVENT_ID and str(payload.get("choice_id", "")) == CHOICE_ID


func _queued_watch(holder: Dictionary) -> Array:
	var result: Array = []
	for value in (holder.get("scenario_sequence_state", {}) as Dictionary).get("fact_queue", []):
		if typeof(value) == TYPE_DICTIONARY and _is_watch(value):
			result.append(value)
	return result


func _watch_receipt_ids(holder: Dictionary) -> Array:
	var result: Array = []
	for value in (holder.get("scenario_sequence_state", {}) as Dictionary).get("fact_receipt_records", []):
		var record: Dictionary = value
		if _is_watch(record.get("envelope", {})):
			result.append(str(record.get("receipt_key", "")))
	return result


func _state_signature(data: Dictionary) -> Dictionary:
	var environment: Dictionary = data.get("current_environment", {})
	var holder := _watch_holder(environment)
	var state: Dictionary = holder.get("scenario_sequence_state", {})
	var queue_ids: Array = []
	for fact in _queued_watch(holder):
		queue_ids.append(str(fact.get("fact_id", "")))
	return {"cash": int(data.get("bankroll", 0)), "clock": int(data.get("game_clock_minutes", 0)), "rng_seed": int(data.get("rng_seed", 0)), "rng": int(data.get("rng_state", 0)), "run_status": str(data.get("run_status", "")), "layer": str(environment.get("current_layer_id", "")), "phase": str(state.get("phase_id", "")), "semantic_digest": str(environment.get("scenario_semantic_digest", "")), "semantic_version": int(environment.get("scenario_semantic_inventory_version", 0)), "club_semantic_digest": str(holder.get("scenario_semantic_digest", "")), "watch_queue_ids": queue_ids, "watch_receipt_ids": _watch_receipt_ids(holder)}


func _enabled_objects() -> Array:
	var result: Array = []
	var canvas: Control = app.get("environment_canvas")
	if canvas != null:
		for value in canvas.get("foundation_scene_objects"):
			if typeof(value) == TYPE_DICTIONARY and bool(value.get("interactive", false)) and not bool(value.get("decorative", false)) and not bool(value.get("disabled", false)):
				result.append(value)
	return result


func _result_summary(result: Dictionary) -> Dictionary:
	return {"ok": bool(result.get("ok", false)), "errors": (result.get("errors", []) as Array).duplicate(true), "message": str(result.get("message", "")), "processed_count": (result.get("processed", []) as Array).size()}


func _canonical(path: String) -> String:
	return path.replace("\\", "/").simplify_path().trim_suffix("/").to_lower()


func _check(condition: bool, message: String) -> bool:
	if not condition:
		failures.append(message)
	return condition


func _finish(forced: int = -1) -> void:
	if finished:
		return
	finished = true
	for name in input_hashes:
		_check(FileAccess.get_sha256(bundle.path_join(name)) == str(input_hashes[name]), "Preserved fixed input companion changed: " + name)
	observations["failures"] = failures.duplicate()
	var text := JSON.stringify(observations)
	var report := FileAccess.open(OS.get_environment("BTH_SCRATCH_REPRO_REPORT"), FileAccess.WRITE) if text.to_utf8_buffer().size() <= 65536 else null
	var written := report != null
	if report != null:
		report.store_string(text)
		written = report.get_error() == OK
		report.close()
	if app != null:
		app.queue_free()
	var exit_code := forced if forced >= 0 else (0 if failures.is_empty() else 1)
	if not written:
		exit_code = 74
	print("PUNCHLINE_SYNTHETIC_COLD stage=%s status=%s failures=%d report_written=%s" % [stage, "PASS" if exit_code == 0 else "FAIL", failures.size(), str(written)])
	quit(exit_code)
