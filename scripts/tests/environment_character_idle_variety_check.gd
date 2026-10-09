extends SceneTree

const PixelSceneCanvasScript := preload("res://scripts/ui/pixel_scene_canvas.gd")


func _initialize() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _timing_bucket(value: float) -> String:
	return str(roundi(value * 10.0))


func _routine_signature(profile: Dictionary) -> String:
	var parts := PackedStringArray()
	var events: Array = profile.get("gesture_events", []) if typeof(profile.get("gesture_events", [])) == TYPE_ARRAY else []
	for event_value in events:
		var event: Dictionary = event_value if typeof(event_value) == TYPE_DICTIONARY else {}
		parts.append("%s:%.2f:%.2f:%d" % [
			str(event.get("pose", "")),
			float(event.get("start", 0.0)),
			float(event.get("duration", 0.0)),
			int(event.get("side", 1)),
		])
	return "|".join(parts)


func _run() -> void:
	var canvas: Control = PixelSceneCanvasScript.new()
	root.add_child(canvas)
	var crew_members := [
		{"id": "crew_a", "role": "lender", "model": {}},
		{"id": "crew_b", "role": "lender", "model": {}},
		{"id": "crew_c", "role": "lender", "model": {}},
	]
	var crew_scales: Array = canvas.call("debug_character_actor_scales", {
		"id": "lender:the_crew",
		"source_id": "the_crew",
		"character_actor": {
			"portrait_count": 3,
			"character_pool_id": "crew_regulars",
			"members": crew_members,
		},
	})
	var typical_scale: float = float((canvas.call("debug_character_actor_scales", {
		"id": "typical_person",
		"character_actor": {"portrait_count": 1, "members": [crew_members[0]]},
	}) as Array)[0])
	if crew_scales.size() != 3 or float(crew_scales[0]) < typical_scale or float(crew_scales[1]) < typical_scale or float(crew_scales[2]) < typical_scale:
		_fail("The Crew's three environment figures render smaller than a typical person: crew=%s typical=%.3f" % [str(crew_scales), typical_scale])
		return
	var roles := ["staff", "watcher", "dealer", "bartender", "regular", "runner"]
	var visual_fingerprints := {}
	var routine_fingerprints := {}
	var expected_profiles := {}
	var fixtures: Array = []
	var gestures := {}
	var saw_double_blink := false
	for index in range(32):
		var member := {"id": "person_%02d" % index, "role": roles[index % roles.size()], "model": {}}
		var object_data := {
			"id": "character_object_%02d" % index,
			"character_actor": {"role": member["role"], "members": [member]},
		}
		fixtures.append(object_data.duplicate(true))
		var profile: Dictionary = canvas.call("debug_character_idle_profile", object_data, 0)
		var repeated_profile: Dictionary = canvas.call("debug_character_idle_profile", object_data, 0)
		if profile != repeated_profile:
			_fail("Character idle profile changed for the same object identity.")
			return
		expected_profiles[object_data["id"]] = profile.duplicate(true)
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
		var routine_fingerprint := _routine_signature(profile)
		routine_fingerprints[routine_fingerprint] = true
		var pose_choices: Array = profile.get("gesture_poses", []) if typeof(profile.get("gesture_poses", [])) == TYPE_ARRAY else []
		if pose_choices.size() < 6:
			_fail("Character idle profile exposed too few role-appropriate gestures for %s: %d" % [object_data["id"], pose_choices.size()])
			return
		for pose_value in pose_choices:
			gestures[str(pose_value)] = true
		var events: Array = profile.get("gesture_events", []) if typeof(profile.get("gesture_events", [])) == TYPE_ARRAY else []
		if events.size() < 10:
			_fail("Character idle routine is too short for %s: %d events" % [object_data["id"], events.size()])
			return
		var segment_duration := float(profile.get("gesture_segment_duration", 0.0))
		var event_poses := {}
		var start_buckets := {}
		var duration_buckets := {}
		var gap_buckets := {}
		var previous_pose := ""
		var previous_end := -1.0
		for event_index in range(events.size()):
			var event: Dictionary = events[event_index] if typeof(events[event_index]) == TYPE_DICTIONARY else {}
			var event_pose := str(event.get("pose", "")).strip_edges()
			if event_pose.is_empty():
				continue
			if event_pose == previous_pose:
				_fail("Character idle routine repeated adjacent pose %s for %s." % [event_pose, object_data["id"]])
				return
			previous_pose = event_pose
			event_poses[event_pose] = true
			var event_start := float(event.get("start", 0.0))
			var event_duration := float(event.get("duration", 0.0))
			if event_duration < 0.60 or event_duration > 1.75:
				_fail("Character idle gesture duration escaped its readable range for %s: %.3f" % [object_data["id"], event_duration])
				return
			start_buckets[_timing_bucket(event_start)] = true
			duration_buckets[_timing_bucket(event_duration)] = true
			var absolute_start := float(event_index) * segment_duration + event_start
			if previous_end >= 0.0:
				var rest_gap := absolute_start - previous_end
				if rest_gap < 0.70 or rest_gap > 15.0:
					_fail("Character idle rest escaped its natural range for %s: %.3f" % [object_data["id"], rest_gap])
					return
				gap_buckets[_timing_bucket(rest_gap)] = true
			previous_end = absolute_start + event_duration
		if event_poses.size() < 5 or start_buckets.size() < 3 or duration_buckets.size() < 3 or gap_buckets.size() < 3:
			_fail("Character idle routine lacks within-character pose/timing variance for %s." % object_data["id"])
			return
		var blink_events: Array = profile.get("blink_events", []) if typeof(profile.get("blink_events", [])) == TYPE_ARRAY else []
		var blink_start_buckets := {}
		for blink_value in blink_events:
			var blink_event: Dictionary = blink_value if typeof(blink_value) == TYPE_DICTIONARY else {}
			blink_start_buckets[_timing_bucket(float(blink_event.get("start", 0.0)))] = true
			saw_double_blink = saw_double_blink or bool(blink_event.get("double", false))
		if blink_events.size() < 8 or blink_start_buckets.size() < 3:
			_fail("Character blink routine lacks irregular timing for %s." % object_data["id"])
			return
		var observed_poses := {}
		var transition_count := 0
		var sampled_pose := "idle"
		for sample_index in range(901):
			var state: Dictionary = canvas.call("debug_character_idle_state", profile, float(sample_index) * 0.20)
			var state_pose := str(state.get("pose", "idle"))
			if state_pose != "idle":
				observed_poses[state_pose] = true
			if state_pose != sampled_pose and state_pose != "idle":
				transition_count += 1
			sampled_pose = state_pose
		if not observed_poses.has(str(profile.get("primary_pose", ""))) or not observed_poses.has(str(profile.get("secondary_pose", ""))):
			_fail("Character idle cycle did not expose both authored gestures for %s." % object_data["id"])
			return
		if observed_poses.size() < 5 or transition_count < 10:
			_fail("Character idle timeline exposed too little long-form variety for %s." % object_data["id"])
			return
		var ordered_state: Dictionary = canvas.call("debug_character_idle_state", profile, 37.25)
		canvas.call("debug_character_idle_state", profile, 4.75)
		var repeated_state: Dictionary = canvas.call("debug_character_idle_state", profile, 37.25)
		if ordered_state != repeated_state:
			_fail("Character idle state depends on sampling order for %s." % object_data["id"])
			return
	if gestures.size() < 12:
		_fail("Environment character idle system exposed too little gesture variety: %d" % gestures.size())
		return
	if routine_fingerprints.size() < 28:
		_fail("Environment characters received too few distinct idle timelines: %d" % routine_fingerprints.size())
		return
	if not saw_double_blink:
		_fail("Environment character idle system exposed no occasional double blink.")
		return

	var reverse_canvas: Control = PixelSceneCanvasScript.new()
	root.add_child(reverse_canvas)
	for fixture_index in range(fixtures.size() - 1, -1, -1):
		var fixture: Dictionary = fixtures[fixture_index]
		var reverse_profile: Dictionary = reverse_canvas.call("debug_character_idle_profile", fixture, 0)
		if reverse_profile != expected_profiles.get(str(fixture.get("id", "")), {}):
			_fail("Character idle profile depends on generation order for %s." % fixture.get("id", ""))
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

	var passive_scenario_characters := [
		{
			"id": "scenario::beach_storm_coming_late_swimmer",
			"interaction_type": "scenario_actor",
			"character_actor": {
				"role": "idle",
				"pose": "waiting",
				"members": [{"role": "idle", "pose": "waiting", "model": {}}],
			},
		},
		{
			"id": "scenario::beach_storm_coming_lifeguard",
			"interaction_type": "scenario_actor",
			"character_actor": {
				"role": "guard",
				"pose": "working",
				"members": [{"role": "guard", "pose": "working", "model": {}}],
			},
		},
	]
	var scenario_routine_signatures := {}
	for object_data in passive_scenario_characters:
		var profile: Dictionary = canvas.call("debug_character_idle_profile", object_data, 0)
		scenario_routine_signatures[_routine_signature(profile)] = true
		var observed_poses := {}
		var saw_body_motion := false
		for sample_index in range(901):
			var idle_state: Dictionary = canvas.call("debug_character_actor_idle_state", object_data, 0, float(sample_index) * 0.20)
			var pose := str(idle_state.get("pose", "idle"))
			if pose != "idle":
				observed_poses[pose] = true
			saw_body_motion = saw_body_motion or absf(float(idle_state.get("sway", 0.0))) > 0.1 or absf(float(idle_state.get("bob", 0.0))) > 0.1
		if observed_poses.size() < 5 or not saw_body_motion:
			_fail("Passive scenario character lost its idle routine: %s poses=%s" % [object_data["id"], str(observed_poses.keys())])
			return
	if scenario_routine_signatures.size() != passive_scenario_characters.size():
		_fail("Late Swimmer and Lifeguard received the same scenario idle routine.")
		return
	var active_lifeguard: Dictionary = (passive_scenario_characters[1] as Dictionary).duplicate(true)
	var active_lifeguard_actor := active_lifeguard["character_actor"] as Dictionary
	active_lifeguard_actor["pose"] = "signaling"
	var active_lifeguard_members := active_lifeguard_actor["members"] as Array
	var active_lifeguard_member := active_lifeguard_members[0] as Dictionary
	active_lifeguard_member["pose"] = "signaling"
	var active_lifeguard_state: Dictionary = canvas.call("debug_character_actor_idle_state", active_lifeguard, 0, 19.0)
	if str(active_lifeguard_state.get("pose", "")) != "signaling" or not is_equal_approx(float(active_lifeguard_state.get("gesture_amount", 0.0)), 1.0):
		_fail("An active Lifeguard signaling pose was incorrectly replaced by an idle gesture.")
		return

	canvas.set("reduce_motion", true)
	var reduced_profile: Dictionary = canvas.call("debug_named_character_idle_profile", "mara", "staff")
	var reduced_state: Dictionary = canvas.call("debug_character_idle_state", reduced_profile, 19.0)
	if str(reduced_state.get("pose", "")) != "idle" or bool(reduced_state.get("blink", true)):
		_fail("Reduced-motion character rendering did not settle to a static idle.")
		return
	for field in ["gesture_amount", "sway", "bob", "head_x", "head_y", "eye_offset"]:
		if not is_zero_approx(float(reduced_state.get(field, 1.0))):
			_fail("Reduced-motion character rendering left %s active." % field)
			return

	print("Environment character idle variety: PASS")
	quit(0)
