extends SceneTree

const PixelSceneCanvasScript := preload("res://scripts/ui/pixel_scene_canvas.gd")


func _initialize() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _run() -> void:
	var canvas: Control = PixelSceneCanvasScript.new()
	root.add_child(canvas)
	var roles := ["staff", "watcher", "dealer", "bartender", "regular", "runner"]
	var visual_fingerprints := {}
	var gestures := {}
	for index in range(32):
		var member := {"id": "person_%02d" % index, "role": roles[index % roles.size()], "model": {}}
		var object_data := {
			"id": "character_object_%02d" % index,
			"character_actor": {"role": member["role"], "members": [member]},
		}
		var profile: Dictionary = canvas.call("debug_character_idle_profile", object_data, 0)
		var repeated_profile: Dictionary = canvas.call("debug_character_idle_profile", object_data, 0)
		if profile != repeated_profile:
			_fail("Character idle profile changed for the same object identity.")
			return
		var fingerprint := "%s|%s|%.3f|%.3f|%.3f|%.3f|%.3f" % [
			profile.get("primary_pose", ""),
			profile.get("secondary_pose", ""),
			float(profile.get("tempo", 0.0)),
			float(profile.get("phase", 0.0)),
			float(profile.get("cycle_duration", 0.0)),
			float(profile.get("blink_period", 0.0)),
			float(profile.get("sway_amount", 0.0)),
		]
		if visual_fingerprints.has(fingerprint):
			_fail("Two environment character objects received the same idle animation signature: %s" % fingerprint)
			return
		visual_fingerprints[fingerprint] = true
		gestures[str(profile.get("primary_pose", ""))] = true
		gestures[str(profile.get("secondary_pose", ""))] = true
		var observed_poses := {}
		for sample_index in range(241):
			var state: Dictionary = canvas.call("debug_character_idle_state", profile, float(sample_index) * 0.25)
			observed_poses[str(state.get("pose", "idle"))] = true
		if not observed_poses.has(str(profile.get("primary_pose", ""))) or not observed_poses.has(str(profile.get("secondary_pose", ""))):
			_fail("Character idle cycle did not expose both authored gestures for %s." % object_data["id"])
			return
	if gestures.size() < 7:
		_fail("Environment character idle system exposed too little gesture variety: %d" % gestures.size())
		return

	var named_ids := ["mara", "alley_merchant", "motel_clerk", "silas", "vince", "lena", "june", "marco", "rafi", "dot", "nell", "sable", "ox", "rourke", "iris", "sal"]
	var named_pairs := {}
	for character_id in named_ids:
		var named_profile: Dictionary = canvas.call("debug_named_character_idle_profile", character_id, "regular")
		var pair := "%s|%s" % [named_profile.get("primary_pose", ""), named_profile.get("secondary_pose", "")]
		named_pairs[pair] = true
	if named_pairs.size() < 10:
		_fail("Named environment characters do not have enough distinct authored idle routines.")
		return

	canvas.set("reduce_motion", true)
	var reduced_profile: Dictionary = canvas.call("debug_named_character_idle_profile", "mara", "staff")
	var reduced_state: Dictionary = canvas.call("debug_character_idle_state", reduced_profile, 19.0)
	if str(reduced_state.get("pose", "")) != "idle" or float(reduced_state.get("sway", 1.0)) != 0.0 or bool(reduced_state.get("blink", true)):
		_fail("Reduced-motion character rendering did not settle to a static idle.")
		return

	print("Environment character idle variety: PASS")
	quit(0)
