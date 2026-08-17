extends SceneTree


func _initialize() -> void:
	var failures: Array[String] = []
	if not ClassDB.class_exists("CoinPusherNativeCore"):
		failures.append("CoinPusherNativeCore was not registered")
	else:
		var core: Object = ClassDB.instantiate("CoinPusherNativeCore")
		if str(core.call("backend_id")) != "coin_pusher_native_integer_v1":
			failures.append("native backend identity drifted")
		for fixture in [[7, 3, 2], [-7, 3, -2], [7, -3, -2], [-7, -3, 2], [7, 0, 0]]:
			if int(core.call("divi", fixture[0], fixture[1])) != fixture[2]:
				failures.append("integer division drifted for %s" % [fixture])
		if int(core.call("pusher_face_y", 0, true)) != 92000 or int(core.call("pusher_face_y", 6000, true)) != 68000:
			failures.append("upper pusher phase geometry drifted")
		var columns := {
			"x": PackedInt32Array([10000, 50000, 90000]),
			"vx": PackedInt32Array([1, 2, 3]),
			"vy": PackedInt32Array([-1, -2, -3]),
			"masses": PackedInt32Array([1, 2, 4]),
			"sleeping": PackedByteArray([1, 1, 1]),
			"sleep_ticks": PackedInt32Array([9, 9, 9]),
			"rest_states": PackedStringArray(["resting", "resting", "resting"]),
		}
		var nudged: Dictionary = core.call("apply_nudge_columns", columns, {
			"nudge_x": 12000, "nudge_y": -8000, "aimed_x": 50000, "nudge_radius": 10000,
		}) as Dictionary
		if not bool(nudged.get("ok", false)) or int(nudged.get("woken_count", -1)) != 1:
			failures.append("packed nudge did not select exactly one body")
		elif (nudged.get("vx", PackedInt32Array()) as PackedInt32Array) != PackedInt32Array([1, 6002, 3]):
			failures.append("packed nudge x impulse drifted")
		elif (nudged.get("vy", PackedInt32Array()) as PackedInt32Array) != PackedInt32Array([-1, -4002, -3]):
			failures.append("packed nudge y impulse drifted")
		var malformed: Dictionary = core.call("apply_nudge_columns", {"x": PackedInt32Array([1])}, {}) as Dictionary
		if bool(malformed.get("ok", true)) or str(malformed.get("error", "")) != "column_size_mismatch":
			failures.append("malformed packed columns were accepted")
	if failures.is_empty():
		print("NATIVE_COIN_PUSHER_SMOKE PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
