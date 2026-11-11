extends SceneTree
const Model = preload("res://scripts/core/crew_turn_model.gd")
var checks := 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _init() -> void:
	var absolute := ProjectSettings.globalize_path(Model.PRIVATE_KEY_PATH).replace("\\", "/")
	var admitted := OS.get_environment("BTH_QA_RUN_DIR").replace("\\", "/")
	if admitted.is_empty() or not absolute.begins_with(admitted + "/") or not absolute.begins_with("E:/CodexQA/BTH/"):
		push_error("Refusing key fixture outside admitted fresh E profile: " + absolute)
		quit(2)
		return
	var payload := {"x": Model.empty_state(), "g": [], "q": 0}
	var binding := "AUD061-15-current-format"
	var parent := absolute.get_base_dir()
	DirAccess.make_dir_recursive_absolute(parent)
	for size in [0, 1, 31, 33, 64]:
		Model._private_key_cache = PackedByteArray()
		var damaged := PackedByteArray()
		damaged.resize(size)
		damaged.fill(7)
		var file := FileAccess.open(absolute, FileAccess.WRITE)
		file.store_buffer(damaged)
		file.close()
		var capsule := Model.pack_private_save(payload, [], [], binding)
		check(not capsule.is_empty(), "pack succeeds after size %d" % size)
		var fresh := FileAccess.get_file_as_bytes(absolute)
		check(fresh.size() == 32, "replacement is 32 bytes for size %d" % size)
		var retained := false
		for name in DirAccess.get_files_at(parent):
			if name.begins_with(absolute.get_file() + ".corrupt.") and FileAccess.get_file_as_bytes(parent.path_join(name)) == damaged:
				retained = true
		check(retained, "damaged bytes retained for size %d" % size)
		check(Model.unpack_private_save(capsule, [], [], binding) == payload, "round-trip after size %d" % size)
		Model._private_key_cache = PackedByteArray()
		check(Model.unpack_private_save(capsule, [], [], binding) == payload, "cold-cache round-trip size %d" % size)
		check(FileAccess.get_file_as_bytes(absolute) == fresh, "valid key unchanged size %d" % size)
		var next := Model.pack_private_save(payload, [], [], binding)
		check(not next.is_empty() and Model.unpack_private_save(next, [], [], binding) == payload, "subsequent save succeeds size %d" % size)
		# Corrupt only this fresh test profile. Existing-key capsules still fail authentication.
		file = FileAccess.open(absolute, FileAccess.WRITE)
		file.store_8(8)
		file.close()
		Model._private_key_cache = PackedByteArray()
		check(Model.unpack_private_save(capsule, [], [], binding).is_empty(), "old-key capsule rejected size %d" % size)
		var recovered := Model.pack_private_save(payload, [], [], binding)
		check(not recovered.is_empty() and Model.unpack_private_save(recovered, [], [], binding) == payload, "save recovers after rejected old-key capsule size %d" % size)
	print(JSON.stringify({"checks": checks, "failures": failures, "failure_count": failures.size(), "key_path_admitted": true}))
	quit(0 if failures.is_empty() else 1)
