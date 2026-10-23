extends SceneTree

const Codec := preload("res://scripts/core/run_save_codec.gd")
const Saves := preload("res://scripts/core/save_service.gd")
const Store := preload("res://scripts/core/durable_store.gd")
var failures: Array[String] = []
var checks := 0

func _init() -> void:
	call_deferred("_run")

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)

func _run() -> void:
	if OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").is_empty() or OS.get_environment("BTH_SAVE_CODEC_FIXTURE").is_empty():
		push_error("This check requires an isolated distribution root and a fixture.")
		quit(2)
		return
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("BTH_SAVE_CODEC_FIXTURE")))
	var snapshot := Codec.decode(Codec.unpack_from_storage(fixture.get("run_state", {})))
	_check(not snapshot.is_empty(), "genuine saved state decoded")
	snapshot["pipeline_owned_probe"] = {"array": [{"value": 7}], "bytes": PackedByteArray([1, 2, 3])}
	snapshot.get_or_add("seeded_scenario_definitions_by_node", {})["invalid_owned_probe"] = [{"value": 7}]
	var captured := snapshot.duplicate(true)
	captured["pipeline_owned_probe"]["bytes"] = snapshot["pipeline_owned_probe"]["bytes"].duplicate()
	var service := Saves.new()
	var slot := "frame_pipeline"
	var path := service.run_save_path(slot)
	_check(service.clear_run(slot) == OK, "owned test slot starts empty")
	var expected: Dictionary = Saves._save_payload_result(captured, slot).get("payload", {})
	_check(service._begin_web_save(snapshot, slot, path, "") == OK, "generation accepted")
	_check(service._begin_web_save(snapshot, slot, path, "") == ERR_BUSY, "second generation rejected while busy")
	_check(service.async_save_in_flight(), "in flight before pack")
	var encoded_before := JSON.stringify(service._web_save_job.get("encoded"))
	snapshot["pipeline_owned_probe"]["array"][0]["value"] = 999
	snapshot["pipeline_owned_probe"]["bytes"][0] = 255
	snapshot["bankroll"] = -999
	snapshot["seeded_scenario_definitions_by_node"]["invalid_owned_probe"][0]["value"] = 999
	_check(JSON.stringify(service._web_save_job.get("encoded")) == encoded_before, "encoded artifact owns nested containers and bytes")
	_check(not bool(service.poll_async_save().get("completed", true)), "capture-frame poll cannot pack")
	_check(service._web_save_job.get("phase") == "pack", "same frame retains pack")
	await _next_process_frame()
	var packed := service.poll_async_save()
	_check(not bool(packed.get("completed", true)) and service._web_save_job.get("phase") == "validate_bytes", "next frame packs without acknowledging install")
	_check(not FileAccess.file_exists(path), "no primary before validated install")
	service.poll_async_save()
	_check(service._web_save_job.get("phase") == "validate_bytes", "repeated poll cannot collapse bytes validation into pack frame")
	await _next_process_frame()
	service.poll_async_save()
	_check(service._web_save_job.get("phase") == "validate_json", "later frame verifies decompression/content hash")
	_check(not FileAccess.file_exists(path), "byte proof alone cannot install")
	service.poll_async_save()
	_check(service._web_save_job.get("phase") == "validate_json", "repeated poll cannot collapse JSON validation")
	await _next_process_frame()
	service.poll_async_save()
	_check(service._web_save_job.get("phase") == "install", "another frame validates JSON roots without acknowledging install")
	_check(not FileAccess.file_exists(path), "complete content proof still waits for durable install")
	service.poll_async_save()
	_check(service._web_save_job.get("phase") == "install", "repeated poll cannot collapse installation")
	await _next_process_frame()
	var installed := service.poll_async_save()
	_check(bool(installed.get("completed", false)) and bool(installed.get("ok", false)), "later frame installs and acknowledges")
	_check(not service.async_save_in_flight(), "completion clears generation")
	_check(FileAccess.get_file_as_string(path) == JSON.stringify(expected, "\t"), "installed bytes equal synchronous exact snapshot/RNG projection")
	var first_bytes := FileAccess.get_file_as_bytes(path)
	var second := captured.duplicate(true)
	second["bankroll"] = int(captured.get("bankroll", 0)) + 1
	_check(service._begin_web_save(second, slot, path, service._trusted_primary_digest(slot, path)) == OK, "next generation accepted")
	_check(service.wait_for_async_save() == OK, "explicit boundary drains all four remaining phases")
	_check(FileAccess.get_file_as_bytes(service.backup_save_path(slot)) == first_bytes, "backup is exact preceding generation")
	var second_bytes := FileAccess.get_file_as_bytes(path)
	_check(service.wait_for_async_save() == OK and FileAccess.get_file_as_bytes(path) == second_bytes, "extra drain is idempotent")
	var third := second.duplicate(true)
	third["bankroll"] = int(second["bankroll"]) + 1
	_check(service._begin_web_save(third, slot, path, service._trusted_primary_digest(slot, path)) == OK, "third accepted")
	await _next_process_frame()
	service.poll_async_save()
	await _next_process_frame()
	service.poll_async_save()
	await _next_process_frame()
	service.poll_async_save()
	_check(service.wait_for_async_save() == OK, "explicit boundary drains install-only remainder")
	var third_bytes := FileAccess.get_file_as_bytes(path)
	Codec.debug_force_compression_failure = true
	service._begin_web_save(captured, slot, path, service._trusted_primary_digest(slot, path))
	_check(service.wait_for_async_save() != OK and not service.async_save_in_flight(), "pack failure reported and clears busy state")
	Codec.debug_force_compression_failure = false
	_check(FileAccess.get_file_as_bytes(path) == third_bytes, "pack failure preserves primary bytes")
	Store.set_debug_fail_transition(Store.TRANSITION_INSTALL_PRIMARY)
	service._begin_web_save(captured, slot, path, service._trusted_primary_digest(slot, path))
	_check(service.wait_for_async_save() != OK, "atomic install failure reported")
	Store.reset_debug_faults()
	_check(FileAccess.get_file_as_bytes(path) == third_bytes, "failed install rolls back exact prior generation")
	service._begin_web_save(captured, slot, path, service._trusted_primary_digest(slot, path))
	_check(service.wait_for_async_save() == OK, "failed generation can retry once")
	_check(FileAccess.get_file_as_bytes(service.backup_save_path(slot)) == third_bytes, "successful retry retains immediately preceding generation")
	_check(FileAccess.get_file_as_string(path) == JSON.stringify(expected, "\t"), "retry writes captured generation once")
	var before_corruption := FileAccess.get_file_as_bytes(path)
	service._begin_web_save(second, slot, path, service._trusted_primary_digest(slot, path))
	await _next_process_frame()
	service.poll_async_save()
	await _next_process_frame()
	service.poll_async_save()
	_check(service._web_save_job.get("phase") == "validate_json", "corruption case starts after byte verification")
	var proven: Dictionary = service._web_save_job.get("verified_storage", {}).duplicate(true)
	var pending_storage: Dictionary = service._web_save_job["payload"]["run_state"]
	pending_storage[Codec.STORAGE_DATA_KEY] = "~" + str(pending_storage[Codec.STORAGE_DATA_KEY]).substr(1)
	_check(service.wait_for_async_save() != OK, "payload mutation after byte verification cannot acquire the old proof")
	_check(FileAccess.get_file_as_bytes(path) == before_corruption, "post-verification corruption preserves exact old primary")
	for field in [Codec.STORAGE_MARKER_KEY, Codec.STORAGE_DATA_KEY, Codec.STORAGE_HASH_KEY, Codec.STORAGE_SIZE_KEY, Codec.STORAGE_COMPRESSED_SIZE_KEY]:
		var changed := {"schema":Saves.SAVE_SCHEMA,"run_state":proven.duplicate(true)}
		if field in [Codec.STORAGE_SIZE_KEY, Codec.STORAGE_COMPRESSED_SIZE_KEY]: changed["run_state"][field] = int(proven[field]) + 1
		else: changed["run_state"][field] = "changed"
		_check(Saves._payload_with_verified_storage_loadable(changed, proven) == Saves._payload_dictionary_loadable(changed), "changed envelope field retains full validation: " + field)
	service._begin_web_save(second, slot, path, service._trusted_primary_digest(slot, path))
	await _next_process_frame()
	service.poll_async_save()
	var invalid_bytes := "not JSON".to_utf8_buffer()
	var compressed := invalid_bytes.compress(FileAccess.COMPRESSION_ZSTD)
	service._web_save_job["payload"]["run_state"] = {Codec.STORAGE_MARKER_KEY:Codec.STORAGE_FORMAT,Codec.STORAGE_DATA_KEY:Codec._z85_encode(compressed),Codec.STORAGE_HASH_KEY:Codec._sha256(invalid_bytes),Codec.STORAGE_SIZE_KEY:invalid_bytes.size(),Codec.STORAGE_COMPRESSED_SIZE_KEY:compressed.size()}
	_check(service.wait_for_async_save() != OK, "valid compressed hash cannot bypass JSON validation")
	_check(FileAccess.get_file_as_bytes(path) == before_corruption, "JSON failure preserves exact old primary")
	service.trusted_primary_fingerprints.erase(slot)
	service._begin_web_save(second, slot, path, "")
	_check(service.wait_for_async_save() == OK, "unknown different prior primary receives full validation during install")
	_check(FileAccess.get_file_as_bytes(service.backup_save_path(slot)) == before_corruption, "old primary remains exact backup with proof for a different new generation")
	_check(not service.async_save_in_flight() and service.wait_for_async_save() == OK, "final drains are idempotent and release the only job")
	if failures.is_empty():
		print("SAVE_WEB_FRAME_PIPELINE PASS checks=%d" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _next_process_frame() -> void:
	var frame := Engine.get_process_frames()
	while Engine.get_process_frames() == frame:
		await process_frame
