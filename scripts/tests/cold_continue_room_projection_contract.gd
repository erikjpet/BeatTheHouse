extends SceneTree

const MainScene := preload("res://scenes/main.tscn")
const CodecScript := preload("res://scripts/core/run_save_codec.gd")
const ControllerScript := preload("res://scripts/ui/environment_interaction_controller.gd")
const FIXTURE_PATH := "res://scripts/tests/fixtures/cold_continue_storm_save.json"
const REQUIRED_OBJECTS := [
	"game:video_poker", "game:pull_tabs", "game:scratch_tickets", "character:nell",
	"travel:leave", "scenario::gas_station_storm_shelter_rain_shutters",
	"scenario::gas_station_storm_shelter_driver_group",
	"scenario::gas_station_storm_shelter_family_group",
	"scenario::gas_station_storm_shelter_safe_exit",
]

var failures: Array[String] = []
var fixture_root := ""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	fixture_root = ProjectSettings.globalize_path("user://cold_continue_room_projection_contract")
	OS.set_environment("BTH_DISTRIBUTION_DATA_ROOT", fixture_root)
	OS.set_environment("BTH_DISTRIBUTION_BUILD", "1")
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_PATH))
	_write_payload(payload)
	# The first operation on this captured save is the real cold Continue path.
	# Do not warm RunState or decode its scenario definitions before loading it.
	var app: Control = await _open_app()
	var loaded: bool = app.call("load_foundation_run")
	for _frame in range(5):
		await process_frame
	_check(loaded, "Continue rejected the captured production save.")
	var state: RunState = app.get("run_state")
	if loaded and state != null:
		var view: Dictionary = app.call("current_environment_view_snapshot")
		var canvas: Control = app.get("environment_canvas")
		var ids: Array[String] = []
		for object_value in canvas.get("foundation_scene_objects"):
			if typeof(object_value) == TYPE_DICTIONARY:
				ids.append(str((object_value as Dictionary).get("id", "")))
		for identity in REQUIRED_OBJECTS:
			_check(ids.has(identity), "Cold Continue lost room object %s." % identity)
		_check(bool(ControllerScript._object_manifest_join_proof(state.current_environment).get("ok", false)), "Rebuilt room did not pass the complete strict authority check.")
		_check(not state.current_environment.has("scenario_restore_pending_trusted_rebuild"), "Continue left the room waiting for reconstruction.")
		_check(state._scenario_semantic_ready(), "Continue published base geometry without rebuilding scenario action authority.")
		_check(str(view.get("scenario_id", "")) == "gas_station_storm_shelter", "Continue changed the selected scenario.")
		var expected := CodecScript.decode(CodecScript.unpack_from_storage(payload.run_state))
		_check(state.bankroll == int(expected.bankroll), "Reconstruction changed cash.")
		_check(state.rng_state == int(expected.rng_state), "Reconstruction consumed RNG.")
		_check(state.game_clock_minutes == int(expected.game_clock_minutes), "Reconstruction advanced the clock.")
		_check(state.suspicion_level() == 1, "Reconstruction changed Heat.")
	await _close_app(app)

	# A pending reconstruction flag must not authorize damaged durable geometry.
	var damaged := CodecScript.decode(CodecScript.unpack_from_storage(payload.run_state))
	damaged.current_environment["scenario_layout_authority_digest"] = "0".repeat(64)
	var packed := CodecScript.pack_for_storage(CodecScript.encode(damaged))
	var damaged_payload := payload.duplicate(true)
	damaged_payload.run_state = packed.packed
	_write_payload(damaged_payload)
	app = await _open_app()
	loaded = app.call("load_foundation_run")
	for _frame in range(5):
		await process_frame
	if loaded:
		state = app.get("run_state")
		# Recovery may retain non-interactive fallback scenery. Publication and
		# authority, rather than the count of drawable props, own this contract.
		_check(state.room_presentation_snapshot().is_empty(), "Damaged sealed geometry was published as a room.")
		_check(not bool(ControllerScript._object_manifest_join_proof(state.current_environment).get("ok", false)), "Damaged sealed geometry passed strict authority validation.")
		_check(bool(app.call("_room_publication_save_blocked")), "Damaged sealed geometry did not preserve the previous save.")
		_check(str(state.current_environment.get("scenario_layout_authority_digest", "")) == "0".repeat(64), "Reconstruction re-signed damaged geometry.")
	await _close_app(app)
	if failures.is_empty():
		print("COLD_CONTINUE_ROOM_PROJECTION_CONTRACT PASS restored_objects=%d damaged_authority_rejected=true" % REQUIRED_OBJECTS.size())
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _write_payload(payload: Dictionary) -> void:
	var save_dir := fixture_root.path_join("saves")
	DirAccess.make_dir_recursive_absolute(save_dir)
	var path := save_dir.path_join("foundation_ui_autosave.json")
	if FileAccess.file_exists(path + ".bak"):
		DirAccess.remove_absolute(path + ".bak")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(payload))
	file.close()


func _open_app() -> Control:
	var app: Control = MainScene.instantiate()
	app.set("continuous_environment_clock_enabled", false)
	root.add_child(app)
	for _frame in range(3):
		await process_frame
	return app


func _close_app(app: Control) -> void:
	app.queue_free()
	for _frame in range(3):
		await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
