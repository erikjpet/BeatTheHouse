extends SceneTree

# Each stage runs in a fresh supervisor-owned private user directory. Fixture
# bundles live outside res:// and contain only disposable synthetic data.
const INPUT_SLOT := "gas_scratch_cold_input_disposable"
const SCALPER := "dialogue:scratch_ticket_scalper"
const ALLOWED_STAGES := ["cold_late", "cold_legacy", "cold_resaved", "tamper"]

var failures: Array[String] = []
var observations: Dictionary = {}
var stage := ""
var fixture_root := ""
var bundle := ""
var input_hash := ""
var app: Control
var run: RunState
var codec: Script
var controller: Script
var binder: Script
var mask: Script
var manifest_script: Script
var fixture_metadata: Dictionary = {}
var raw_expected: Dictionary = {}
var raw_semantic_digest := ""
var raw_semantic_version := 0
var bad_binding: Dictionary = {}


func _init() -> void:
	# Do not preload a scene or invoke a run/profile/authority operation above it.
	var actual := ProjectSettings.globalize_path("user://")
	var expected := OS.get_environment("BTH_SCRATCH_REPRO_USER_DIR")
	observations["resolved_user_dir"] = actual
	if expected.is_empty() or _canonical(actual) != _canonical(expected):
		push_error("REFUSED: disposable user directory mismatch")
		quit(64)
		return
	stage = OS.get_environment("BTH_SCRATCH_REGRESSION_STAGE")
	fixture_root = OS.get_environment("BTH_SCRATCH_FIXTURE_ROOT").replace("\\", "/").simplify_path().trim_suffix("/")
	var task_root := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var allowed_root := task_root.path_join("repro-fixtures")
	if not ALLOWED_STAGES.has(stage) or OS.get_environment("BTH_SCRATCH_REPRO_REPORT").is_empty() \
			or not (_canonical(fixture_root) == _canonical(allowed_root) or _canonical(fixture_root).begins_with(_canonical(allowed_root) + "/")):
		push_error("REFUSED: explicit cold stage, task-owned fixture root and report required")
		quit(64)
		return
	observations["stage"] = stage
	call_deferred("_run")


func _run() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		failures.append("Finite cold-stage deadline expired")
		_finish(124)
	)
	codec = load("res://scripts/core/run_save_codec.gd")
	controller = load("res://scripts/ui/environment_interaction_controller.gd")
	binder = load("res://scripts/core/environment_slot_binder.gd")
	mask = load("res://scripts/games/scratch_ticket_mask.gd")
	manifest_script = load("res://scripts/core/environment_object_manifest.gd")
	var bundle_name := "legacy_initial" if stage == "cold_legacy" else "resaved_late" if stage == "cold_resaved" else "late_arrival"
	bundle = fixture_root.path_join(bundle_name)
	var payload := _install_private_bundle()
	if payload.is_empty():
		_finish()
		return
	# Decode only the codec envelope. Never call RunState.from_dict or a view
	# before recording the untouched save-shaped state and its raw first proof.
	var unpacked: Dictionary = codec.unpack_from_storage(payload.get("run_state", {}))
	var raw: Dictionary = codec.decode(unpacked)
	if not _check(not raw.is_empty(), "Fixture codec could not be decoded"):
		_finish()
		return
	var environment: Dictionary = raw.get("current_environment", {})
	raw_expected = _state_signature(raw)
	raw_semantic_digest = str(environment.get("scenario_semantic_digest", ""))
	raw_semantic_version = int(environment.get("scenario_semantic_inventory_version", 0))
	var first_proof: Dictionary = binder.validate_base_layout_authority(_raw_proof_environment(environment))
	observations["raw_first_authority_proof"] = {"ok": bool(first_proof.get("ok", false)), "errors": first_proof.get("errors", [])}
	observations["raw_signature"] = raw_expected
	_check(bool(first_proof.get("ok", false)), "Untampered fixture failed its first raw authority proof")
	if stage == "cold_late":
		_check(bool(raw_expected.get("scalper_present", false)), "Prepatch late-arrival fixture did not persist the scalper")
		_check(not str(raw_expected.get("active_id", "")).is_empty() and (raw_expected.get("queue_ids", []) as Array).size() == 1, "Prepatch fixture does not retain the failing active-plus-queued ticket state")
	if stage == "cold_legacy":
		_check(raw_semantic_digest == str(fixture_metadata.get("expected_semantic_digest", "")) and raw_semantic_version == int(fixture_metadata.get("expected_semantic_version", 0)), "Legacy fixture lost its preserved original seal reference")
		_check((environment.get("scenario_sequence_base_layout_object_rects", {}) as Dictionary).has(SCALPER), "Old fixture did not preserve the initial scalper baseline rectangle")
		var legacy_row := false
		for row in (environment.get("object_manifest", {}) as Dictionary).get("rows", []):
			if str((row as Dictionary).get("presentation_object_id", "")) == SCALPER and str((row as Dictionary).get("spot_field", "")) == "game_hook_spots":
				legacy_row = true
		_check(legacy_row, "Old fixture did not preserve the ordinary prepatch scalper manifest row")
	if stage == "tamper":
		if not _make_tampered_copy(raw, payload):
			_finish()
			return
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
	if stage == "tamper":
		_check_tamper_result(loaded)
		_finish()
		return
	if not _check(loaded and run != null, "Cold Continue rejected the preserved synthetic save"):
		_finish()
		return
	_check(_state_signature(run.to_dict()) == raw_expected, "Cold Continue changed cash, clock, RNG or ticket state")
	_check_room_authority("cold_continue")
	if not failures.is_empty():
		_finish()
		return
	if stage == "cold_late":
		await _exercise_filing_and_redemption()
	elif stage == "cold_resaved":
		var before_cash := run.bankroll
		var before_redeemed := int(_machine().get("redeemed_count", 0))
		app.call("use_game_environment_hook", "scratch_tickets", "scratch_ticket_clerk", "redeem_scratch_winners")
		await process_frame
		_check(run.bankroll == before_cash and int(_machine().get("redeemed_count", 0)) == before_redeemed, "Cold Continue allowed a second payout for already redeemed tickets")
		app.call("back_to_environment")
		await process_frame
		await _exercise_other_room_object()
	else:
		await _exercise_other_room_object()
	_finish()


func _install_private_bundle() -> Dictionary:
	var metadata_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(bundle.path_join("metadata.json")))
	if not _check(typeof(metadata_value) == TYPE_DICTIONARY, "Fixture metadata missing or malformed"):
		return {}
	var metadata: Dictionary = metadata_value
	fixture_metadata = metadata.duplicate(true)
	var source := bundle.path_join("save.json")
	input_hash = FileAccess.get_sha256(source)
	if not _check(not input_hash.is_empty() and input_hash == str(metadata.get("save_sha256", "")), "Preserved fixture save hash mismatch") \
			or not _check(FileAccess.get_sha256(bundle.path_join("crew-authority.bin")) == str(metadata.get("authority_sha256", "")), "Disposable fixture authority hash mismatch"):
		return {}
	var save_file := FileAccess.open(source, FileAccess.READ)
	if not _check(save_file != null and save_file.get_length() <= 32 * 1024 * 1024, "Fixture save exceeds bounded input size"):
		return {}
	var parsed: Variant = JSON.parse_string(save_file.get_as_text())
	save_file.close()
	if not _check(typeof(parsed) == TYPE_DICTIONARY, "Fixture payload JSON is invalid"):
		return {}
	var user_dir := ProjectSettings.globalize_path("user://")
	var distribution := OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").replace("\\", "/")
	var save_dir := distribution.path_join("saves")
	var destination := save_dir.path_join(INPUT_SLOT + ".json")
	if not _check(_canonical(distribution).begins_with(_canonical(user_dir) + "/"), "Distribution path escaped disposable user directory") \
			or not _check(not FileAccess.file_exists(destination) and not FileAccess.file_exists(user_dir.path_join(".crew_host_authority_v1")), "Cold stage requires fresh private save and authority paths"):
		return {}
	_check(DirAccess.make_dir_recursive_absolute(save_dir) == OK, "Could not create private save directory")
	_check(DirAccess.copy_absolute(source, destination) == OK, "Could not copy private save")
	_check(DirAccess.copy_absolute(bundle.path_join("crew-authority.bin"), user_dir.path_join(".crew_host_authority_v1")) == OK, "Could not install disposable authority")
	for name in ["profile_inventory.json", "profile_inventory.json.bak"]:
		if FileAccess.file_exists(bundle.path_join(name)):
			_check(DirAccess.copy_absolute(bundle.path_join(name), distribution.path_join(name)) == OK, "Could not copy disposable profile")
	_check(FileAccess.get_sha256(destination) == input_hash, "Private copy is not byte-identical")
	observations["input_sha256"] = input_hash
	return parsed as Dictionary if failures.is_empty() else {}


func _make_tampered_copy(raw: Dictionary, payload: Dictionary) -> bool:
	var environment: Dictionary = raw.get("current_environment", {})
	var layout: Dictionary = environment.get("layout", {})
	var bindings: Dictionary = layout.get("slot_bindings", {})
	var binding: Dictionary = (bindings.get("game:scratch_tickets", {}) as Dictionary).duplicate(true)
	if not _check(not binding.is_empty(), "Tamper fixture lacks the scratch machine binding"):
		return false
	var slot: Dictionary = binding.get("slot", {})
	var hit: Array = slot.get("hit_rect", [])
	if not _check(hit.size() == 4, "Tamper fixture lacks authored slot geometry"):
		return false
	hit[0] = float(hit[0]) + 3.0
	slot["hit_rect"] = hit
	binding["slot"] = slot
	bindings["game:scratch_tickets"] = binding
	layout["slot_bindings"] = bindings
	layout["slot_binding_digest"] = binder.binding_digest(bindings)
	var rects: Dictionary = layout.get("object_rects", {})
	var rect: Dictionary = (rects.get("game:scratch_tickets", {}) as Dictionary).duplicate(true)
	rect["x"] = float(rect.get("x", 0.0)) + 0.02
	rects["game:scratch_tickets"] = rect
	layout["object_rects"] = rects
	environment["layout"] = layout
	raw["current_environment"] = environment
	bad_binding = binding.duplicate(true)
	var proof: Dictionary = binder.validate_base_layout_authority(_raw_proof_environment(environment))
	observations["tampered_raw_authority_proof"] = {"ok": bool(proof.get("ok", false)), "errors": proof.get("errors", [])}
	var geometry_error := false
	for error_value in proof.get("errors", []):
		var message := str(error_value)
		if message.contains("does not match its exact authored slot") or message.contains("object_rect does not match its exact authored slot"):
			geometry_error = true
	if not _check(not bool(proof.get("ok", false)) and geometry_error, "Re-digested altered geometry did not fail its exact authored-slot proof"):
		return false
	var packed: Dictionary = codec.pack_for_storage(codec.encode(raw))
	if not _check(bool(packed.get("ok", false)), "Could not encode bounded tamper copy"):
		return false
	var damaged := payload.duplicate(true)
	damaged["run_state"] = packed.get("packed", {})
	var path := OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").path_join("saves").path_join(INPUT_SLOT + ".json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not _check(file != null, "Could not write private tamper copy"):
		return false
	file.store_string(JSON.stringify(damaged))
	file.close()
	return true


func _check_tamper_result(loaded: bool) -> void:
	if not loaded or run == null or _enabled_objects().is_empty():
		observations["tamper_room_rejected"] = true
		return
	var current: Dictionary = ((run.current_environment.get("layout", {}) as Dictionary).get("slot_bindings", {}) as Dictionary).get("game:scratch_tickets", {})
	_check(JSON.stringify(current) != JSON.stringify(bad_binding), "Cold Continue published/resealed the altered binding")
	# Canonical reconstruction is distinct from rejecting the room. If used, it
	# must restore exact authored geometry and the original semantic reference.
	_check_room_authority("tamper_canonical_reconstruction")
	observations["tamper_room_rejected"] = false
	observations["tamper_canonical_reconstruction"] = failures.is_empty()
	_check(false, "Legacy raw-geometry rejection was lost during cold Continue")


func _exercise_filing_and_redemption() -> void:
	if not _check(bool(app.call("enter_game", "scratch_tickets")), "Cold-restored scratch surface could not be entered"):
		return
	var pending_payout := 0
	var before_redeemed := int(_machine().get("redeemed_count", 0))
	var before_cash := run.bankroll
	var initial_filed := _filed_count()
	for ticket in [_machine().get("active_ticket", {})] + (_machine().get("pending_queue", []) as Array):
		pending_payout += maxi(0, int((ticket as Dictionary).get("payout", 0)))
	# Exactly two known delivered tickets; no seed search or repeated workload.
	for index in range(2):
		if not await _await_surface_gate():
			return
		var active_before := str((_machine().get("active_ticket", {}) as Dictionary).get("id", ""))
		var queue_before: Array = _machine().get("pending_queue", [])
		var expected_next := str((queue_before[0] as Dictionary).get("id", "")) if not queue_before.is_empty() else ""
		app.call("_on_game_surface_action", "scratch_all", 0)
		await process_frame
		if not _check(bool(mask.ticket_complete(_machine().get("active_ticket", {}))), "Scratch All was blocked after cold restore"):
			return
		app.call("_on_game_surface_action", "scratch_file_ticket", 0)
		await process_frame
		await process_frame
		if not await _await_surface_gate():
			return
		_check(not active_before.is_empty() and str((_machine().get("active_ticket", {}) as Dictionary).get("id", "")) == expected_next, "File did not advance exactly once")
		_check(_filed_count() == initial_filed + index + 1, "File did not create exactly one receipt")
		_check(run.bankroll == before_cash, "File changed cash before counter redemption")
		_check(str((app.get("last_game_result") as Dictionary).get("action_id", "")) == "settle_scratch_ticket", "File retained stale host feedback")
	app.call("back_to_environment")
	await process_frame
	await _exercise_other_room_object()
	var winners_before := (_machine().get("winner_pile", []) as Array).size()
	app.call("use_game_environment_hook", "scratch_tickets", "scratch_ticket_clerk", "redeem_scratch_winners")
	await process_frame
	_check(run.bankroll == before_cash + pending_payout, "Counter payout was lost or duplicated")
	_check(int(_machine().get("redeemed_count", 0)) == before_redeemed + winners_before, "Counter did not consume each winning ticket exactly once")
	_check((_machine().get("winner_pile", []) as Array).is_empty(), "Counter retained already redeemed winners")
	app.call("back_to_environment")
	await process_frame
	app.call("use_game_environment_hook", "scratch_tickets", "scratch_ticket_clerk", "redeem_scratch_winners")
	await process_frame
	_check(run.bankroll == before_cash + pending_payout and int(_machine().get("redeemed_count", 0)) == before_redeemed + winners_before, "Repeated counter action duplicated payout")
	observations["positive_payout_exercised"] = pending_payout > 0
	observations["expected_counter_payout"] = pending_payout
	app.call("back_to_environment")
	await process_frame
	_check_room_authority("after_filing_redemption")
	if _check(bool(app.call("_autosave_foundation_run", "Focused regression saved", true)), "Normal synchronous resave failed"):
		_export_resaved_bundle()


func _exercise_other_room_object() -> void:
	for object_value in _enabled_objects():
		var object_data: Dictionary = object_value
		var object_id := str(object_data.get("id", ""))
		if object_id.begins_with("game:") and object_id != "game:scratch_tickets":
			var accepted := bool(app.call("activate_interactable_object", object_id))
			_check(accepted and str(app.get("current_screen")) == "GAME", "Another real room object refused interaction")
			observations["other_room_object"] = object_id
			app.call("back_to_environment")
			await process_frame
			return
	_check(false, "No second physical game was available for interaction proof")


func _export_resaved_bundle() -> void:
	var output := fixture_root.path_join("resaved_late")
	if not _check(not DirAccess.dir_exists_absolute(output), "Refusing to overwrite the preserved resaved fixture"):
		return
	_check(DirAccess.make_dir_recursive_absolute(output) == OK, "Could not create resaved fixture bundle")
	var save_service: RefCounted = app.get("save_service")
	var path := str(save_service.call("run_save_path", INPUT_SLOT))
	_check(DirAccess.copy_absolute(path, output.path_join("save.json")) == OK, "Could not preserve resaved bytes")
	_check(DirAccess.copy_absolute(ProjectSettings.globalize_path("user://.crew_host_authority_v1"), output.path_join("crew-authority.bin")) == OK, "Could not preserve disposable resave authority")
	var profile := OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").path_join("profile_inventory.json")
	if FileAccess.file_exists(profile):
		_check(DirAccess.copy_absolute(profile, output.path_join("profile_inventory.json")) == OK, "Could not preserve resaved disposable profile")
	var metadata := {"kind": "synthetic_postfix_resaved_late", "slot_id": INPUT_SLOT,
		"save_sha256": FileAccess.get_sha256(output.path_join("save.json")),
		"authority_sha256": FileAccess.get_sha256(output.path_join("crew-authority.bin")),
		"expected_semantic_digest": raw_semantic_digest, "expected_semantic_version": raw_semantic_version}
	var file := FileAccess.open(output.path_join("metadata.json"), FileAccess.WRITE)
	if _check(file != null, "Could not write resaved fixture metadata"):
		file.store_string(JSON.stringify(metadata))
		file.close()
	observations["resaved_metadata"] = metadata


func _check_room_authority(label: String) -> void:
	var proof: Dictionary = controller._object_manifest_join_proof(run.current_environment.duplicate(true))
	observations[label + "_strict_join"] = {"ok": bool(proof.get("ok", false)), "errors": proof.get("errors", [])}
	_check(bool(proof.get("ok", false)), label + " failed complete strict room authority")
	_check(str(run.current_environment.get("scenario_semantic_digest", "")) == raw_semantic_digest and int(run.current_environment.get("scenario_semantic_inventory_version", 0)) == raw_semantic_version, label + " changed the original semantic reference")
	_check(bool(run.call("_scenario_semantic_ready")), label + " did not restore semantic readiness")
	_check(not run.current_environment.has("scenario_restore_pending_trusted_rebuild"), label + " left restore pending")
	_check(not _enabled_objects().is_empty(), label + " published an empty room")


func _state_signature(data: Dictionary) -> Dictionary:
	var environment: Dictionary = data.get("current_environment", {})
	var machine: Dictionary = ((environment.get("game_states", {}) as Dictionary).get("scratch_tickets", {}) as Dictionary).duplicate(false)
	# Saves serialize player-owned tickets once, separately from room machines.
	# Overlay only the closed portable player fields, using a pure origin lookup;
	# this does not construct RunState, touch authority, or warm a projection.
	var origins: Dictionary = (data.get("portable_ticket_piles", {}) as Dictionary).get("scratch_tickets", {})
	var portable: Dictionary = origins.get(RunState.portable_ticket_origin_key(environment), {})
	for field_value in RunState.PORTABLE_TICKET_PLAYER_FIELDS.get("scratch_tickets", []):
		var field := str(field_value)
		if portable.has(field):
			machine[field] = portable[field]
	var result := {"cash": int(data.get("bankroll", 0)), "clock": int(data.get("game_clock_minutes", 0)), "rng": int(data.get("rng_state", 0)),
		"scalper_present": bool(machine.get("scalper_present", false)), "active_id": str((machine.get("active_ticket", {}) as Dictionary).get("id", "")),
		"redeemed_count": int(machine.get("redeemed_count", 0)), "loser_archive_count": int(machine.get("loser_archive_count", 0))}
	for field in ["pending_queue", "tray_stack", "winner_pile", "loser_pile"]:
		var ids: Array = []
		for ticket in machine.get(field, []):
			ids.append(str((ticket as Dictionary).get("id", "")))
		result["queue_ids" if field == "pending_queue" else field + "_ids"] = ids
	return result


func _raw_proof_environment(environment: Dictionary) -> Dictionary:
	var proof_environment := environment.duplicate(false)
	# Match the existing lossless JSON integer boundary only. No source digest,
	# row body, binding, rectangle or layout signature is regenerated here.
	proof_environment["object_manifest"] = manifest_script.normalize_persisted(environment.get("object_manifest", {}))
	return proof_environment


func _machine() -> Dictionary:
	return (run.current_environment.get("game_states", {}) as Dictionary).get("scratch_tickets", {})


func _filed_count() -> int:
	return (_machine().get("winner_pile", []) as Array).size() + (_machine().get("loser_pile", []) as Array).size() + int(_machine().get("loser_archive_count", 0))


func _enabled_objects() -> Array:
	var canvas: Control = app.get("environment_canvas")
	var result: Array = []
	if canvas != null:
		for value in canvas.get("foundation_scene_objects"):
			if typeof(value) == TYPE_DICTIONARY and bool(value.get("interactive", false)) and not bool(value.get("decorative", false)) and not bool(value.get("disabled", false)):
				result.append(value)
	return result


func _await_surface_gate() -> bool:
	var deadline := Time.get_ticks_msec() + 5000
	while bool(app.call("_deferred_embedded_refresh_blocks_current_surface_input")):
		if Time.get_ticks_msec() >= deadline:
			return _check(false, "Deferred surface input gate did not release")
		await process_frame
	return true


func _canonical(path: String) -> String:
	return path.replace("\\", "/").simplify_path().trim_suffix("/").to_lower()


func _check(condition: bool, message: String) -> bool:
	if not condition:
		failures.append(message)
	return condition


func _finish(forced: int = -1) -> void:
	if not input_hash.is_empty():
		_check(FileAccess.get_sha256(bundle.path_join("save.json")) == input_hash, "Preserved source fixture bytes changed")
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
	print("GAS_SCRATCH_COLD_STAGE stage=%s status=%s failures=%d" % [stage, "PASS" if exit_code == 0 else "FAIL", failures.size()])
	quit(exit_code)
