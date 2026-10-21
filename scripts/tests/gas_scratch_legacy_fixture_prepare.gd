extends SceneTree

# Private regression preparation only. The supervisor must provide an empty,
# disposable user directory and a task-owned repro-fixtures root. Never commit
# the generated fixture or its install authority to the repository.
const BASELINE_ENVIRONMENT_INSTANCE_SHA := "85267383c9027da5c3ff991569e7239c4049c17b26f39758de22f31e9ba76b9d"
const SLOT := "gas_scratch_legacy_initial_disposable"
const SCENARIO := "gas_station_graveyard_shift"
const SEED := "GAS-SCRATCH-LEGACY-INITIAL-EMPTY-SEAL"

var failures: Array[String] = []
var observations: Dictionary = {}
var app: Control
var fixture_root := ""


class EmptyInitialGenerator:
	extends RunGenerator

	var prepared := 0

	func _init(p_library: ContentLibrary) -> void:
		super(p_library)

	func _generated_game_states(run_state: RunState, environment: Dictionary, rng: RngStream) -> Dictionary:
		var states := super._generated_game_states(run_state, environment, rng)
		if str(environment.get("archetype_id", "")) != "gas_station_casino":
			return states
		var machine: Dictionary = (states.get("scratch_tickets", {}) as Dictionary).duplicate(true)
		var stock: Array = machine.get("stock", [])
		for index in range(stock.size()):
			var row: Dictionary = stock[index]
			row["remaining"] = 0
			stock[index] = row
		machine["stock"] = stock
		machine["scalper_present"] = true
		machine["scalper_knows_schedule"] = false
		machine["scalper_visit_token"] = "%s@%d" % [RunState.portable_ticket_origin_key(environment), run_state.game_clock_minutes]
		machine["restock_phase_minute"] = 179
		machine["restock_cursor_absolute_minute"] = run_state.game_clock_minutes
		machine["next_restock_absolute_minute"] = 899
		states["scratch_tickets"] = machine
		prepared += 1
		return states


func _init() -> void:
	# No scene, profile, RunState or authority work may precede this guard.
	var actual := ProjectSettings.globalize_path("user://")
	var expected := OS.get_environment("BTH_SCRATCH_REPRO_USER_DIR")
	observations["resolved_user_dir"] = actual
	if expected.is_empty() or _canonical(actual) != _canonical(expected):
		push_error("REFUSED: disposable user directory mismatch")
		quit(64)
		return
	fixture_root = OS.get_environment("BTH_SCRATCH_FIXTURE_ROOT").replace("\\", "/").simplify_path().trim_suffix("/")
	var task_root := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var allowed_root := task_root.path_join("repro-fixtures")
	if not _canonical(fixture_root).begins_with(_canonical(allowed_root) + "/") and _canonical(fixture_root) != _canonical(allowed_root):
		push_error("REFUSED: fixtures must stay in this task's repro-fixtures directory")
		quit(64)
		return
	if OS.get_environment("BTH_SCRATCH_REGRESSION_STAGE") != "legacy_prepare" or OS.get_environment("BTH_SCRATCH_REPRO_REPORT").is_empty():
		push_error("REFUSED: explicit legacy_prepare stage and report required")
		quit(64)
		return
	call_deferred("_run")


func _run() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		failures.append("Finite preparation deadline expired")
		_finish(124)
	)
	if not _check(FileAccess.get_sha256("res://scripts/core/environment_instance.gd") == BASELINE_ENVIRONMENT_INSTANCE_SHA, "Legacy fixture must be prepared before the projector patch"):
		_finish()
		return
	var scene: PackedScene = load("res://scenes/main.tscn")
	app = scene.instantiate()
	app.set("continuous_environment_clock_enabled", false)
	app.set("autosave_slot_id", SLOT)
	root.add_child(app)
	await process_frame
	await process_frame
	if not _check(bool(app.call("_ensure_run_ui_built")), "Run UI construction failed"):
		_finish()
		return
	app.call("_ensure_full_content_library_loaded")
	var library: ContentLibrary = app.get("library")
	var run := RunState.new()
	run.start_new(SEED, RunState.custom_challenge("gas_scratch_legacy_initial", SEED, {"scenario_pins": {"gas_station_casino": SCENARIO}}))
	run.bankroll = 1000
	run.begin_act(1)
	var generator := EmptyInitialGenerator.new(library)
	var installed := generator.travel_environment_result(run, "gas_station_casino", true)
	if not _check(bool(installed.get("ok", false)) and generator.prepared == 1, "Normal empty-machine factory install failed: %s" % str(installed.get("errors", []))):
		_finish()
		return
	var env := run.current_environment
	var inventory: Dictionary = env.get("scenario_semantic_inventory", {})
	var semantic: Dictionary = (env.get("scenario_sequence_state", {}) as Dictionary).get("semantic_state", {})
	var targets: Dictionary = semantic.get("target_inventory", {})
	_check((targets.get("scene_objects", []) as Array).has("base::dialogue:scratch_ticket_scalper"), "Legacy seal did not include the scalper scene identity")
	_check((env.get("scenario_sequence_base_layout_object_rects", {}) as Dictionary).has("dialogue:scratch_ticket_scalper"), "Legacy baseline did not retain the scalper rectangle")
	var controller: Script = load("res://scripts/ui/environment_interaction_controller.gd")
	var proof: Dictionary = controller._object_manifest_join_proof(env.duplicate(true))
	_check(bool(proof.get("ok", false)), "Legacy factory strict join failed: %s" % str(proof.get("errors", [])))
	observations["legacy_inventory_digest"] = str(inventory.get("digest", ""))
	observations["legacy_semantic_digest"] = str(env.get("scenario_semantic_digest", ""))
	observations["legacy_strict_join"] = proof
	if not failures.is_empty():
		_finish()
		return
	# Fixture preparation preserves the validated factory state before any host
	# publication. The separate cold stages exercise the actual Continue/UI path.
	# Calling the normal SaveService directly avoids making fixture creation
	# depend on a manually installed host's room-publication generation gate.
	var save_service: RefCounted = app.get("save_service")
	var save_error := int(save_service.call("save_run", run, SLOT))
	observations["fixture_save_service_error"] = save_error
	if not _check(save_error == OK, "Normal SaveService fixture serialization failed"):
		_finish()
		return
	var save_path := str(save_service.call("run_save_path", SLOT))
	var user_dir := ProjectSettings.globalize_path("user://")
	var distribution := OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").replace("\\", "/")
	if not _check(_canonical(distribution).begins_with(_canonical(user_dir) + "/"), "Distribution root escaped the private user directory"):
		_finish()
		return
	var bundle := fixture_root.path_join("legacy_initial")
	if not _check(not DirAccess.dir_exists_absolute(bundle), "Refusing to overwrite a preserved legacy fixture"):
		_finish()
		return
	_check(DirAccess.make_dir_recursive_absolute(bundle) == OK, "Could not create private fixture bundle")
	_check(DirAccess.copy_absolute(save_path, bundle.path_join("save.json")) == OK, "Could not preserve fixture save bytes")
	_check(DirAccess.copy_absolute(user_dir.path_join(".crew_host_authority_v1"), bundle.path_join("crew-authority.bin")) == OK, "Could not preserve disposable install authority")
	var profile_path := distribution.path_join("profile_inventory.json")
	if FileAccess.file_exists(profile_path):
		_check(DirAccess.copy_absolute(profile_path, bundle.path_join("profile_inventory.json")) == OK, "Could not preserve disposable profile")
	var metadata := {
		"kind": "synthetic_prepatch_initial_scalper", "slot_id": SLOT,
		"save_sha256": FileAccess.get_sha256(bundle.path_join("save.json")),
		"authority_sha256": FileAccess.get_sha256(bundle.path_join("crew-authority.bin")),
		"expected_semantic_digest": str(env.get("scenario_semantic_digest", "")),
		"expected_semantic_version": int(env.get("scenario_semantic_inventory_version", 0)),
		"baseline_scalper_present": true,
	}
	var file := FileAccess.open(bundle.path_join("metadata.json"), FileAccess.WRITE)
	if _check(file != null, "Could not write private fixture metadata"):
		file.store_string(JSON.stringify(metadata))
		file.close()
	observations["fixture_metadata"] = metadata
	_finish()


func _canonical(path: String) -> String:
	return path.replace("\\", "/").simplify_path().trim_suffix("/").to_lower()


func _check(condition: bool, message: String) -> bool:
	if not condition:
		failures.append(message)
	return condition


func _finish(forced: int = -1) -> void:
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
	print("GAS_SCRATCH_LEGACY_PREPARE status=%s failures=%d" % ["PASS" if exit_code == 0 else "FAIL", failures.size()])
	quit(exit_code)
