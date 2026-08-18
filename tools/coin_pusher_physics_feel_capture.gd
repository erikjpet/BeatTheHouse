extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RngStreamScript := preload("res://scripts/core/rng_stream.gd")
const Solver := preload("res://scripts/games/coin_pusher/coin_pusher_solver_api.gd")
const DEFAULT_OUTPUT := "res://.tmp/coin_pusher_v3_headless_feel.json"


func _init() -> void:
	var output := DEFAULT_OUTPUT
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			output = argument.trim_prefix("--out=").strip_edges()
	var library := ContentLibraryScript.new()
	library.load()
	var machine: Dictionary = library.game("coin_pusher").get("coin_pusher_machine", {})
	var report := _capture_contract(machine)
	var absolute := ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		push_error("Unable to write Coin Pusher V3 headless feel report: %s" % output)
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t", false))
	file.close()
	print("COIN_PUSHER_V3_HEADLESS_FEEL %s out=%s" % ["PASS" if bool(report.get("passed", false)) else "FAIL", absolute])
	quit(0 if bool(report.get("passed", false)) else 1)


func _capture_contract(machine: Dictionary) -> Dictionary:
	var state := Solver.create_machine(_rng("PUSHER-V3-FEEL"), machine, 40)
	var start_digest := JSON.stringify(Solver.canonical_digest(state), "", true)
	var start_tick := int(state.get("tick", 0))
	var trace := [
		{"tick": start_tick + 5, "kind": "drop", "x": 42000, "density": 1},
		{"tick": start_tick + 60, "kind": "skill_stop", "engaged": true},
		{"tick": start_tick + 96, "kind": "drop", "x": 58000, "density": 1},
		{"tick": start_tick + 130, "kind": "skill_stop", "engaged": false},
		{"tick": start_tick + 160, "kind": "nudge", "x": 700, "y": -900},
	]
	var result := Solver.replay_input_trace(state, _rng("PUSHER-V3-FEEL-TRACE"), trace, 260)
	var digest := Solver.canonical_digest(result)
	var changed := JSON.stringify(digest, "", true) != start_digest
	var invariants: Dictionary = result.get("last_invariants", {})
	return {
		"schema": "coin_pusher_v3_headless_feel",
		"passed": changed and int(result.get("tick", -1)) == start_tick + 260 and bool(invariants.get("energy_ok", false)) and bool(invariants.get("conservation_ok", false)),
		"backend": Solver.last_step_backend_for_test(),
		"opening_body_count": int(state.get("opening_body_count", 0)),
		"final_body_count": (result.get("bodies", []) as Array).size(),
		"tray_count": (result.get("tray_ledger", []) as Array).size(),
		"gutter_count": (result.get("gutter_ledger", []) as Array).size(),
		"final_digest": digest,
	}


func _rng(seed: String) -> RngStream:
	var rng := RngStreamScript.new()
	rng.configure(_stable_hash(seed))
	return rng


func _stable_hash(value: String) -> int:
	var hash_value := 2166136261
	for byte in value.to_utf8_buffer():
		hash_value = int((hash_value ^ int(byte)) * 16777619) & 0x7fffffff
	return hash_value
