extends SceneTree

const Check := preload("res://scripts/tests/inactive_storage_projection_check.gd")
const Codec := preload("res://scripts/core/run_save_codec.gd")
const FIXTURE := "res://scripts/tests/fixtures/integ06_1/v0_5_1/v051_grand_casino_back_room_duel.json"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").is_empty():
		push_error("This check requires an isolated distribution root.")
		quit(2)
		return
	var service := SaveService.new()
	var path := service.run_save_path("inactive_storage_encoding")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(FileAccess.get_file_as_bytes(FIXTURE))
	file.close()
	var run: RunState = service.load_run("inactive_storage_encoding")
	if run == null:
		quit(3)
		return
	if run._grand_casino_run_facade == null:
		push_error("Grand Casino facade failed to initialize.")
		quit(4)
		return
	var result := Check.check(run)
	var snapshot := run.to_save_snapshot_for_encoding()
	var started := Time.get_ticks_usec()
	var cached := Codec.encode(snapshot)
	var cached_usec := Time.get_ticks_usec() - started
	var legacy_snapshot := run.to_save_snapshot(false)
	started = Time.get_ticks_usec()
	var legacy := Codec.encode(legacy_snapshot)
	var legacy_usec := Time.get_ticks_usec() - started
	var exact := JSON.stringify(cached) == JSON.stringify(legacy)
	print("INACTIVE_STORAGE_ENCODING ", JSON.stringify({"contract":result, "exact_json_bytes":exact,
		"native_encode_usec":{"compiled":cached_usec,"legacy":legacy_usec}}))
	quit(0 if bool(result.get("passed", false)) and exact else 1)
